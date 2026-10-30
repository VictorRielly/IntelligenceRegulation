//! Export ONE PUBLIC synthetic ZK60 T32 fixture plus the canonical
//! `FixedCausalOracle` trace, for cross-implementation parity with the
//! standalone `private-block-kernel` crate. Everything written is PUBLIC
//! synthetic test data (fixture weights, calibration tables and a synthetic
//! input). Never point this tool at a real or private activation: the trace
//! it writes would expose every intermediate. This proves nothing.
//!
//! Tables are taken from the canonical generators the oracle itself uses
//! (`rope_tables_generate`, `exp_member`, the registered SiLU table), checked
//! against the registered digests and against the oracle's own witness.
//!
//! Usage (all flags optional):
//!   cargo run --release --example zk60_kernel_fixture -- \
//!     [--variant N]      0 = the canonical fixture input; N > 0 = LCG(N) input
//!     [--amp A]          LCG input amplitude, 1..=32767 (default 3000)
//!     [--fill V]         constant input V (overrides --variant; e.g. 32767)
//!     [--weight-seed S]  0 = canonical fixture weights; S > 0 = perturbed,
//!                        re-committed PUBLIC synthetic weights
//!     [--out PATH]       write to PATH instead of stdout
//!
//! Format `zk60-kernel-fixture v1` (text, whitespace separated):
//!   zk60-kernel-fixture v1
//!   meta <key> <value...>
//!   status ok | status refused <Range|Relation> <oracle site...>
//!   tensor <name> <len> <values...>        (decimal integers)
//!   end
//! Always: input wq wk wv wo gamma_a gamma_m wg_t wu_t wd_t rope_cos
//! rope_sin exp act. On `ok` also the oracle trace: na_dd na_y q8 k8 v8 qr8
//! kr8 s8 m_row arg sum p o8 ao8 xres1 nm_dd nm_y g8 a16 u16 h16 z16 xres2
//! (layouts as `private_block_kernel::Trace`; `arg` = index of the one-hot
//! `zsel` per (h, t) row). Records concatenate (`cat a b > c`).
use hashline::causal_oracle::{
    cpu_weight_commitments, public_synthetic_fixture, public_synthetic_registration,
    FixedCausalOracle, OracleError, PublicBlockWeights,
};
use hashline::private_block_contract::ApprovedP1BlockContract;
use hashline::tables_attn::{exp_member, rope_digest, rope_tables_generate};
use std::fmt::Write as _;

const USAGE: &str = "zk60_kernel_fixture [--variant N] [--amp A] [--fill V] [--weight-seed S] [--out PATH]";

struct Args {
    variant: u64,
    amp: i64,
    fill: Option<i16>,
    weight_seed: u64,
    out: Option<String>,
}

fn parse_args() -> Result<Args, String> {
    let mut a = Args {
        variant: 0,
        amp: 3000,
        fill: None,
        weight_seed: 0,
        out: None,
    };
    let mut it = std::env::args().skip(1);
    while let Some(flag) = it.next() {
        if flag == "--help" || flag == "-h" {
            println!("{USAGE}");
            std::process::exit(0);
        }
        let val = it.next().ok_or_else(|| format!("{flag} needs a value; {USAGE}"))?;
        let bad = |_| format!("bad value for {flag}");
        match flag.as_str() {
            "--variant" => a.variant = val.parse().map_err(bad)?,
            "--amp" => a.amp = val.parse().map_err(bad)?,
            "--fill" => a.fill = Some(val.parse().map_err(bad)?),
            "--weight-seed" => a.weight_seed = val.parse().map_err(bad)?,
            "--out" => a.out = Some(val),
            _ => return Err(format!("unknown flag {flag}; {USAGE}")),
        }
    }
    if !(1..=32767).contains(&a.amp) {
        return Err("--amp must be in 1..=32767".into());
    }
    Ok(a)
}

struct Lcg(u64);
impl Lcg {
    fn next(&mut self) -> u64 {
        self.0 = self
            .0
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        self.0 >> 33
    }
    fn range(&mut self, amp: i64) -> i64 {
        (self.next() % (2 * amp as u64 + 1)) as i64 - amp
    }
}

/// Deterministic PUBLIC perturbation: signed words at random positions.
fn perturb(w: &mut PublicBlockWeights, seed: u64) {
    let mut rng = Lcg(seed ^ 0x5eed_2060_0000_0001);
    for m in [
        &mut w.wq, &mut w.wk, &mut w.wv, &mut w.wo, &mut w.wg_t, &mut w.wu_t, &mut w.wd_t,
    ] {
        for _ in 0..12 {
            let at = rng.next() as usize % m.len();
            m[at] = rng.range(40) as i8;
        }
    }
    for g in [&mut w.gamma_a, &mut w.gamma_m] {
        for _ in 0..4 {
            let at = rng.next() as usize % g.len();
            g[at] = rng.range(100) as i8;
        }
    }
}

fn tensor<I, V>(out: &mut String, name: &str, vals: I)
where
    I: IntoIterator<Item = V>,
    V: Into<i64>,
{
    let vals: Vec<i64> = vals.into_iter().map(Into::into).collect();
    let _ = write!(out, "tensor {name} {}", vals.len());
    for v in vals {
        let _ = write!(out, " {v}");
    }
    out.push('\n');
}

fn run() -> Result<(), String> {
    let args = parse_args()?;
    let (approved, mut weights, fixture_input) = public_synthetic_fixture();
    let approved = if args.weight_seed == 0 {
        approved
    } else {
        perturb(&mut weights, args.weight_seed);
        let (aw, fw) = cpu_weight_commitments(&weights).map_err(|e| e.to_string())?;
        ApprovedP1BlockContract::from_trusted_public_weights(
            public_synthetic_registration(aw, fw),
            &weights,
        )
        .map_err(|e| e.to_string())?
    };
    let input: Vec<i16> = match (args.fill, args.variant) {
        (Some(v), _) => vec![v; fixture_input.len()],
        (None, 0) => fixture_input,
        (None, seed) => {
            let mut rng = Lcg(seed);
            (0..fixture_input.len())
                .map(|_| rng.range(args.amp) as i16)
                .collect()
        }
    };

    // Canonical tables, exactly the calls the oracle makes.
    let reg = approved.registration();
    let c = &reg.attention;
    let (t, hd) = (c.shape.t, c.shape.head_dim);
    let (ctab, stab) = rope_tables_generate(t, hd, c.rope_base, c.f_ro);
    let (exp_tab, exp_digest) = exp_member(c.e_s_raw, hd, c.f_e);
    let rope_dg = rope_digest(t, hd, c.rope_base, c.f_ro, &ctab, &stab);
    if rope_dg != c.rope_digest || exp_digest != c.exp_digest {
        return Err("canonical tables differ from the registered digests".into());
    }
    let act = reg.ffn.table;

    let oracle = FixedCausalOracle::new(&approved, weights.clone()).map_err(|e| e.to_string())?;
    let built = oracle.build(&input);

    let mut out = String::new();
    out.push_str("zk60-kernel-fixture v1\n");
    out.push_str("meta visibility PUBLIC-SYNTHETIC\n");
    let _ = writeln!(out, "meta variant {}", args.variant);
    let _ = writeln!(out, "meta amp {}", args.amp);
    match args.fill {
        Some(v) => {
            let _ = writeln!(out, "meta fill {v}");
        }
        None => out.push_str("meta fill none\n"),
    }
    let _ = writeln!(out, "meta weight_seed {}", args.weight_seed);
    let _ = writeln!(out, "meta rope_digest {rope_dg}");
    let _ = writeln!(out, "meta exp_digest {exp_digest}");
    let _ = writeln!(out, "meta act_digest {}", reg.ffn.table_digest);
    let status = match &built {
        Ok(_) => "ok".to_string(),
        Err(OracleError::Range(site)) => format!("refused Range {site}"),
        Err(OracleError::Relation(site)) => format!("refused Relation {site}"),
        Err(e) => return Err(format!("unexpected oracle error: {e}")),
    };
    let _ = writeln!(out, "status {status}");
    tensor(&mut out, "input", input.iter().copied());
    for (name, w) in [
        ("wq", &weights.wq),
        ("wk", &weights.wk),
        ("wv", &weights.wv),
        ("wo", &weights.wo),
        ("gamma_a", &weights.gamma_a),
        ("gamma_m", &weights.gamma_m),
        ("wg_t", &weights.wg_t),
        ("wu_t", &weights.wu_t),
        ("wd_t", &weights.wd_t),
    ] {
        tensor(&mut out, name, w.iter().copied());
    }
    tensor(&mut out, "rope_cos", ctab.iter().copied());
    tensor(&mut out, "rope_sin", stab.iter().copied());
    tensor(&mut out, "exp", exp_tab.iter().copied());
    tensor(&mut out, "act", act.iter().copied());

    if let Ok(block) = &built {
        let a = &block.attention;
        if a.exp_tab != exp_tab || a.ctab != ctab || a.stab != stab || block.ffn.table != act {
            return Err("exported tables differ from the oracle witness tables".into());
        }
        let rows = c.shape.heads * t;
        let mut arg = Vec::with_capacity(rows);
        for row in a.zsel.chunks_exact(t) {
            let hits: Vec<usize> = (0..t).filter(|j| row[*j] != 0).collect();
            if hits.len() != 1 || row[hits[0]] != 1 || arg.len() >= rows {
                return Err("oracle zsel is not one-hot per row".into());
            }
            arg.push(hits[0] as i64);
        }
        let f = &block.ffn;
        let i64s: [(&str, &Vec<i64>); 17] = [
            ("na_dd", &a.na.dd),
            ("na_y", &a.na.y),
            ("q8", &a.q8),
            ("k8", &a.k8),
            ("v8", &a.v8),
            ("qr8", &a.qr8),
            ("kr8", &a.kr8),
            ("s8", &a.s8),
            ("m_row", &a.m_row),
            ("arg", &arg),
            ("sum", &a.sum),
            ("p", &a.p),
            ("o8", &a.o8),
            ("ao8", &a.ao8),
            ("xres1", &a.xres1),
            ("nm_dd", &a.nm.dd),
            ("nm_y", &a.nm.y),
        ];
        for (name, v) in i64s {
            tensor(&mut out, name, v.iter().copied());
        }
        for (name, v) in [
            ("g8", &f.g8),
            ("a16", &f.a16),
            ("u16", &f.u16v),
            ("h16", &f.h16),
            ("z16", &f.z16),
        ] {
            tensor(&mut out, name, v.iter().copied());
        }
        tensor(&mut out, "xres2", block.residual.xres2.iter().copied());
    }
    out.push_str("end\n");

    match &args.out {
        Some(path) => std::fs::write(path, &out).map_err(|e| format!("write {path}: {e}"))?,
        None => print!("{out}"),
    }
    eprintln!(
        "zk60_kernel_fixture: PUBLIC synthetic fixture variant={} weight_seed={} status={status}",
        args.variant, args.weight_seed
    );
    Ok(())
}

fn main() {
    if let Err(e) = run() {
        eprintln!("zk60_kernel_fixture: {e}");
        std::process::exit(1);
    }
}
