//! hashline CLI.
//!   hashline check-export                       rung 0: the export's sidecar digests reproduce (all layers)
//!   hashline chain [layers]                     rung 1: the exact integer chain reproduces every z digest
//!   hashline matmul <layers> <t_rows>           rung 2: the g/u matmul sumcheck differential + tamper legs
//!   hashline layer <l> <t_rows> [opts]          rungs 3-4: prove + verify one layer (+ tamper legs)
//!   hashline pass <layers> <t_rows> [opts]      rung 5: the multi-layer pass, one transcript, measured
//!   hashline gpu-probe                          [UPERF3-XX] rung 0: the device field probe vs field.rs
//! opts: --threads N  --log-cols N (default 14)  --col-checks Q (default 256)  --inv-rate R (default 4)
//!       --tamper none|flipx|flipw|rem|table|requant|z  --tamper-idx I  --no-verify  --all-tampers
//!       --proof-out PATH  [UPERF3-XX] write the concatenated layer proofs (flat LE encoding) and print their sha256
//! [UPERF3-XX] `HL_GPU=1` runs the prover's device path (feature gpu-cuda); the proof bytes must not change.
//! [UPERF3-ZB] `--profile v3 --export DIR` (or HL_EXPORT_DIR) selects the WIDENED-STACK statement over an m8b
//!   v3 export (int16-out activation table, round-nearest requant, int16 u/h/z classes, signed shifts):
//!   check-export | chain [layers] [--t T] | layer <l> <t> | pass <layers> <t> as above; `tables-v3` prints the
//!   frozen int16-out registry (15 members, digests = the exports' `NN table` rows / `uperf-v3 tables`).
//!   v3 tampers: --tamper flipx|flipw|rem|table|requant|z|round|i16. The v2 path is untouched.
//!       --zk  [UPERF3-ZA] the zero-knowledge form for the activations (mode P1; see src/zk.rs); --seed N seeds its randomness
//!       --zk --profile v3  [UPERF3-AD] the ZK form of the widened-stack statement (mode P1 composed with v3; the [UPERF3-AD] section of src/zk.rs)

use hashline::chain::{derive, LayerWitness};
use hashline::export::{export_dir, load_layer, Sidecar, D, F, LAYERS};
use hashline::layer::{apply_tamper, matmul_differential, prove_layer, verify_layer, LayerParams, Statement, Tamper};
use hashline::ntt::NttTables;
use hashline::transcript::Transcript;
use std::time::Instant;
use hashline::export_v3::{clone_witness_v3, compare_planes, derive_v3, export_dir_v3, load_layer_v3, V3Sidecar, V3Witness};
use hashline::layer::{apply_tamper_v3, prove_layer_v3, verify_layer_v3, StatementV3, TamperV3};

struct Opts {
    threads: usize,
    log_cols: u32,
    col_checks: usize,
    inv_rate: usize,
    tamper: Tamper,
    verify: bool,
    all_tampers: bool,
    proof_out: Option<String>,
    // [UPERF3-ZB]
    profile: String,
    export: Option<String>,
    t_rows: Option<usize>,
    tamper_kind: String,
    tamper_idx: usize,
    /// [UPERF3-ZA] `--zk` + `--seed`: the zero-knowledge form (default off: the byte-identical path).
    zk: hashline::zk::ZkConfig,
}

fn parse_opts(args: &[String]) -> Opts {
    let mut o = Opts { threads: 0, log_cols: 14, col_checks: 256, inv_rate: 4, tamper: Tamper::None, verify: true, all_tampers: false, proof_out: None,
        profile: "v2".to_string(), export: None, t_rows: None, tamper_kind: "none".to_string(), tamper_idx: 12345, zk: hashline::zk::ZkConfig::default() };
    let mut i = 0;
    let mut tkind = "none".to_string();
    let mut tidx = 12345usize;
    while i < args.len() {
        match args[i].as_str() {
            "--threads" => { o.threads = args[i + 1].parse().unwrap(); i += 1; }
            "--log-cols" => { o.log_cols = args[i + 1].parse().unwrap(); i += 1; }
            "--col-checks" => { o.col_checks = args[i + 1].parse().unwrap(); i += 1; }
            "--inv-rate" => { o.inv_rate = args[i + 1].parse().unwrap(); i += 1; }
            "--tamper" => { tkind = args[i + 1].clone(); i += 1; }
            "--tamper-idx" => { tidx = args[i + 1].parse().unwrap(); i += 1; }
            "--no-verify" => { o.verify = false; }
            "--all-tampers" => { o.all_tampers = true; }
            "--proof-out" => { o.proof_out = Some(args[i + 1].clone()); i += 1; }
            // [UPERF3-ZB]
            "--profile" => { o.profile = args[i + 1].clone(); i += 1; }
            "--export" => { o.export = Some(args[i + 1].clone()); i += 1; }
            "--t" => { o.t_rows = Some(args[i + 1].parse().unwrap()); i += 1; }
            "--zk" => { o.zk.enabled = true; }
            "--seed" => { o.zk.seed = args[i + 1].parse().unwrap(); i += 1; }
            other => { eprintln!("unknown option {other}"); std::process::exit(2); }
        }
        i += 1;
    }
    o.tamper_kind = tkind.clone();
    o.tamper_idx = tidx;
    if o.profile == "v3" {
        // v3 tamper names are resolved by the v3 driver (a superset)
    } else {
        o.tamper = tamper_from(&tkind, tidx);
    }
    if o.profile != "v2" && o.profile != "v3" { eprintln!("unknown profile {} (v2|v3)", o.profile); std::process::exit(2); }
    if o.threads == 0 {
        if let Ok(s) = std::env::var("ZK_THREADS") { o.threads = s.parse().unwrap_or(0); }
    }
    if o.threads > 0 {
        rayon::ThreadPoolBuilder::new().num_threads(o.threads).build_global().unwrap();
    }
    o
}

fn tamper_from(kind: &str, idx: usize) -> Tamper {
    match kind {
        "none" => Tamper::None,
        "flipx" => Tamper::FlipX(idx),
        "flipw" => Tamper::FlipW(idx),
        "rem" => Tamper::RemainderOutOfRange(idx),
        "table" => Tamper::WrongTableEntry(idx),
        "requant" => Tamper::WrongRequant(idx),
        "z" => Tamper::WrongZ(idx),
        other => { eprintln!("unknown tamper {other}"); std::process::exit(2); }
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let cmd = args.get(1).map(|s| s.as_str()).unwrap_or("help");
    match cmd {
        "tables-v3" => tables_v3(),
        "check-export" => {
            let o = parse_opts(&args[2..]);
            if o.profile == "v3" { check_export_v3(&o) } else { check_export() }
        }
        "chain" => {
            let (n, rest): (Option<usize>, &[String]) = match args.get(2).and_then(|s| s.parse().ok()) {
                Some(n) => (Some(n), &args[3..]),
                None => (None, &args[2.min(args.len())..]),
            };
            let o = parse_opts(rest);
            if o.profile == "v3" { chain_v3(n, &o) } else { chain(n.unwrap_or(LAYERS)) }
        }
        "matmul" => {
            let n: usize = args[2].parse().unwrap();
            let t: usize = args[3].parse().unwrap();
            let o = parse_opts(&args[4..]);
            matmul(n, t, &o)
        }
        "layer" => {
            let l: usize = args[2].parse().unwrap();
            let t: usize = args[3].parse().unwrap();
            let o = parse_opts(&args[4..]);
            if o.zk.enabled && o.profile == "v3" { layer_zk_v3(l, t, &o) /* [UPERF3-AD] */ } else if o.zk.enabled { layer_zk(l, t, &o) } else if o.profile == "v3" { layer_v3(l, t, &o) } else { layer(l, t, &o) }
        }
        "pass" => {
            let n: usize = args[2].parse().unwrap();
            let t: usize = args[3].parse().unwrap();
            let o = parse_opts(&args[4..]);
            if o.zk.enabled && o.profile == "v3" { pass_zk_v3(n, t, &o) /* [UPERF3-AD] */ } else if o.zk.enabled { pass_zk(n, t, &o) } else if o.profile == "v3" { pass_v3(n, t, &o) } else { pass(n, t, &o) }
        }
        "gpu-probe" => gpu_probe(),
        _ => {
            eprintln!("usage: hashline check-export | chain [layers] | matmul <layers> <t> | layer <l> <t> | pass <layers> <t>  [opts] | gpu-probe | tables-v3   (opts incl. --profile v2|v3 --export DIR)");
            std::process::exit(2);
        }
    }
}

/// [UPERF3-XX] rung 0: the device field probe.
fn gpu_probe() {
    println!("{}", hashline::gpu::label());
    match hashline::gpu::probe() {
        Ok(r) => {
            println!(
                "gpu-probe: {} — {} pairs (incl. edge values): mul/add/sub mismatches {} ; {:.1} G mul/s (the 3-op kernel, 50 launches)",
                r.device, r.n, r.mismatches, r.gmul_per_s
            );
            if r.mismatches > 0 { std::process::exit(1); }
        }
        Err(e) => {
            eprintln!("gpu-probe: {e}");
            std::process::exit(1);
        }
    }
    // [UPERF3-XX] rung 2: device blake3 column hashes == blake3::hash (every tree shape up to 2^13 rows)
    #[cfg(feature = "gpu-cuda")]
    {
        let mut fails = 0;
        let mut checked = 0;
        let mut rows_list: Vec<usize> = (1..=300).collect();
        rows_list.extend([432, 520, 511, 512, 513, 640, 767, 768, 769, 1023, 1024, 1025, 1500, 2047, 2048, 2049, 3000, 4095, 4096, 4097, 8191, 8192]);
        for rows in rows_list {
            match hashline::gpu::dev_hash_check(rows) {
                Ok(bad) => { checked += 1; if bad > 0 { println!("  hash check rows {rows}: {bad}/64 columns mismatch"); fails += 1; } }
                Err(e) => { println!("  hash check rows {rows}: ERROR {e}"); fails += 1; }
            }
        }
        println!("gpu-probe: blake3 checks {} ({checked} row counts x 64 columns; {} failing)", if fails == 0 { "GREEN" } else { "RED" }, fails);
        if fails > 0 { std::process::exit(1); }
    }
    // [UPERF3-XX] rung 1: the device RS encoding == the CPU encoding element for element
    #[cfg(feature = "gpu-cuda")]
    {
        let mut fails = 0;
        for (log_cols, inv_rate, rows) in [(4u32, 4usize, 3usize), (10, 4, 5), (12, 4, 7), (14, 4, 5), (14, 4, 64), (13, 2, 4), (12, 8, 3)] {
            match hashline::gpu::dev_commit_check(log_cols, inv_rate, rows) {
                Ok((bad, t_cpu, t_gpu)) => {
                    println!("  ntt check log_cols {log_cols} inv_rate {inv_rate} rows {rows}: {bad} mismatches (cpu encode {t_cpu:.3} s, device commit incl. upload+hash {t_gpu:.3} s)");
                    if bad > 0 { fails += 1; }
                }
                Err(e) => { println!("  ntt check log_cols {log_cols} inv_rate {inv_rate} rows {rows}: ERROR {e}"); fails += 1; }
            }
        }
        println!("gpu-probe: ntt checks {}", if fails == 0 { "GREEN" } else { "RED" });
        if fails > 0 { std::process::exit(1); }
    }
}

fn check_export() {
    let dir = export_dir();
    let side = Sidecar::load(&dir);
    println!("export dir {}", dir.display());
    let t0 = Instant::now();
    for l in 0..LAYERS {
        let ex = load_layer(&dir, &side, l);
        println!(
            "  layer {l:2}: X/WgT/WuT/WdT digests == sidecar; shifts g/u/h/z = {}/{}/{}/{}; table member ({},{})",
            ex.shifts.0, ex.shifts.1, ex.shifts.2, ex.shifts.3, ex.e_gate, ex.e_act
        );
    }
    println!("check-export OK: 48/48 tensor digests reproduce ({:.2} s)", t0.elapsed().as_secs_f64());
}

fn chain(n: usize) {
    let dir = export_dir();
    let side = Sidecar::load(&dir);
    let t0 = Instant::now();
    let mut bad = 0;
    for l in 0..n {
        let ex = load_layer(&dir, &side, l);
        let t1 = Instant::now();
        let w = derive(&ex);
        let want = side.digest(l, "z");
        let ok = w.z_digest == want && w.range_ok;
        if !ok { bad += 1; }
        println!(
            "  layer {l:2}: z digest {} {} sidecar ({}..); range facts {}; table {}..; {:.2} s",
            &w.z_digest[..16],
            if w.z_digest == want { "==" } else { "!=" },
            &want[..16],
            if w.range_ok { "HOLD" } else { "FAIL" },
            &w.table_digest[..16],
            t1.elapsed().as_secs_f64()
        );
    }
    println!("chain: {}/{} layers reproduce the sidecar z digest ({:.2} s total)", n - bad, n, t0.elapsed().as_secs_f64());
    if bad > 0 { std::process::exit(1); }
}

fn load_witness(l: usize) -> LayerWitness {
    let dir = export_dir();
    let side = Sidecar::load(&dir);
    let ex = load_layer(&dir, &side, l);
    let w = derive(&ex);
    assert_eq!(w.z_digest, side.digest(l, "z"), "layer {l}: chain z digest != sidecar");
    w
}

fn matmul(n: usize, t: usize, _o: &Opts) {
    println!("rung 2: g/u matmul sumcheck differential at {n} layers x {t} tokens (no PCS; verifier evaluates its own plain matrices)");
    let mut fails = 0;
    for l in 0..n {
        let w = load_witness(l);
        let t0 = Instant::now();
        let r = matmul_differential(&w, &w, t);
        println!("  layer {l:2} honest: {:?} ({:.3} s)", r.as_ref().map(|_| "ACCEPT"), t0.elapsed().as_secs_f64());
        if r.is_err() { fails += 1; }
        for (name, tm) in [("flipped X entry", Tamper::FlipX(777)), ("flipped Wg entry", Tamper::FlipW(4242)), ("wrong gacc (g8 += 1)", Tamper::RemainderOutOfRange(99))] {
            let mut w2 = LayerWitness { ..clone_witness(&w) };
            apply_tamper(&mut w2, tm);
            if let Tamper::RemainderOutOfRange(i) = tm { w2.rg[i] -= 1 << w2.shifts.0; } // keep only g8 -= 1: a wrong claimed gacc
            let r = matmul_differential(&w, &w2, t);
            let ok = r.is_err();
            println!("  layer {l:2} tamper [{name}]: {}", if ok { format!("REJECT ({})", r.err().unwrap()) } else { "ACCEPTED (BUG)".into() });
            if !ok { fails += 1; }
        }
    }
    println!("rung 2: {}", if fails == 0 { "GREEN" } else { "RED" });
    if fails > 0 { std::process::exit(1); }
}

fn clone_witness(w: &LayerWitness) -> LayerWitness {
    LayerWitness {
        l: w.l, shifts: w.shifts, table: w.table, table_digest: w.table_digest.clone(), e_gate: w.e_gate, e_act: w.e_act,
        x: w.x.clone(), wg_t: w.wg_t.clone(), wu_t: w.wu_t.clone(), wd_t: w.wd_t.clone(),
        g8: w.g8.clone(), rg: w.rg.clone(), a8: w.a8.clone(), u8v: w.u8v.clone(), ru: w.ru.clone(),
        h8: w.h8.clone(), rh: w.rh.clone(), z: w.z.clone(), rd: w.rd.clone(), range_ok: w.range_ok, z_digest: w.z_digest.clone(),
    }
}

fn params(o: &Opts) -> LayerParams {
    LayerParams { log_cols: o.log_cols, inv_rate: o.inv_rate, num_col_checks: o.col_checks }
}

fn run_layer(w: &LayerWitness, t: usize, o: &Opts, tamper: Tamper, ntt: &NttTables) -> (bool, f64, f64, usize) {
    let mut w2 = clone_witness(w);
    apply_tamper(&mut w2, tamper);
    let p = params(o);
    let st = Statement { l: w.l, t_rows: t, shifts: w.shifts, table: w.table, table_digest: w.table_digest.clone() };
    let mut tr = Transcript::new(b"hashline-layer");
    let t0 = Instant::now();
    let out = prove_layer(&w2, t, &p, ntt, &mut tr);
    let tp = t0.elapsed().as_secs_f64();
    let bytes = out.proof.size_bytes();
    if !o.verify {
        return (true, tp, 0.0, bytes);
    }
    let mut tv = Transcript::new(b"hashline-layer");
    let t1 = Instant::now();
    let r = verify_layer(&st, &out.proof, &p, ntt, &mut tv);
    let tvv = t1.elapsed().as_secs_f64();
    if matches!(tamper, Tamper::None) {
        for (name, s) in &out.timings {
            println!("      {name:<22} {s:8.3} s");
        }
    }
    match &r {
        Ok(()) => (true, tp, tvv, bytes),
        Err(e) => { println!("      reject: {e}"); (false, tp, tvv, bytes) }
    }
}

fn layer(l: usize, t: usize, o: &Opts) {
    let ntt = NttTables::new(o.log_cols + o.inv_rate.trailing_zeros());
    let w = load_witness(l);
    println!("layer {l} at T = {t} (log_cols {}, inv_rate {}, col checks {}, threads {})", o.log_cols, o.inv_rate, o.col_checks, rayon::current_num_threads());
    let (ok, tp, tv, bytes) = run_layer(&w, t, o, o.tamper, &ntt);
    println!("  tamper {:?}: {} prove {tp:.3} s verify {tv:.3} s proof {bytes} B", o.tamper, if ok { "ACCEPT" } else { "REJECT" });
    let mut fails = 0;
    if matches!(o.tamper, Tamper::None) && !ok { fails += 1; }
    if !matches!(o.tamper, Tamper::None) && ok { fails += 1; }
    if o.all_tampers {
        let legs = [
            ("flipped X entry", Tamper::FlipX(777)),
            ("flipped Wg entry", Tamper::FlipW(4242)),
            ("out-of-range remainder", Tamper::RemainderOutOfRange(99)),
            ("wrong table entry", Tamper::WrongTableEntry(1000)),
            ("wrong requant (h8)", Tamper::WrongRequant(555)),
            ("wrong z", Tamper::WrongZ(321)),
        ];
        for (name, tm) in legs {
            let (ok, tp, tv, _) = run_layer(&w, t, o, tm, &ntt);
            println!("  tamper [{name}]: {} (prove {tp:.2} s, verify {tv:.2} s)", if ok { "ACCEPTED (BUG)" } else { "REJECT" });
            if ok { fails += 1; }
        }
    }
    println!("layer {l}: {}", if fails == 0 { "GREEN" } else { "RED" });
    if fails > 0 { std::process::exit(1); }
}

fn pass(n: usize, t: usize, o: &Opts) {
    let ntt = NttTables::new(o.log_cols + o.inv_rate.trailing_zeros());
    let p = params(o);
    println!("pass: {n} layers x {t} tokens (log_cols {}, inv_rate {}, col checks {}, threads {})", o.log_cols, o.inv_rate, o.col_checks, rayon::current_num_threads());
    println!("  {}", hashline::gpu::label());
    let t_all = Instant::now();
    // load + derive every layer's witness first (the chain is not part of the prover clock; the lattice
    // line's 21.0 s also excludes its export read but INCLUDES its chain derivation — reported separately)
    let t0 = Instant::now();
    let mut ws: Vec<LayerWitness> = (0..n).map(load_witness).collect();
    let t_load = t0.elapsed().as_secs_f64();
    if !matches!(o.tamper, Tamper::None) {
        let victim = n / 2;
        println!("  (tamper {:?} applied to layer {victim}'s witness)", o.tamper);
        apply_tamper(&mut ws[victim], o.tamper);
    }
    let mut tr = Transcript::new(b"hashline-pass");
    let mut proofs = Vec::with_capacity(n);
    let mut stmts = Vec::with_capacity(n);
    let mut agg: Vec<(String, f64)> = Vec::new();
    let t0 = Instant::now();
    for w in &ws {
        let t1 = Instant::now();
        let out = prove_layer(w, t, &p, &ntt, &mut tr);
        for (name, s) in &out.timings {
            if let Some(e) = agg.iter_mut().find(|e| &e.0 == name) { e.1 += s; } else { agg.push((name.clone(), *s)); }
        }
        println!("  layer {:2}: prove {:.3} s, {} B", w.l, t1.elapsed().as_secs_f64(), out.proof.size_bytes());
        stmts.push(Statement { l: w.l, t_rows: t, shifts: w.shifts, table: w.table, table_digest: w.table_digest.clone() });
        proofs.push(out.proof);
    }
    let t_prove = t0.elapsed().as_secs_f64();
    let bytes: usize = proofs.iter().map(|p| p.size_bytes()).sum();
    println!("prover phases (summed over layers):");
    for (name, s) in &agg { println!("      {name:<22} {s:8.3} s"); }
    if hashline::gpu::enabled() {
        let g = hashline::gpu::dev_stats();
        println!(
            "  gpu device-side (summed): h2d {:.3} s ({:.0} MB) | ntt {:.3} s | hash {:.3} s | sumcheck {:.3} s | fold {:.3} s | helpers {:.3} s | d2h {:.3} s ({:.0} MB) | vram peak {:.0} MB",
            g.secs_h2d, g.bytes_h2d as f64 / 1e6, g.secs_ntt, g.secs_hash, g.secs_sumcheck, g.secs_fold, g.secs_helpers, g.secs_d2h, g.bytes_d2h as f64 / 1e6, g.vram_peak as f64 / 1e6
        );
    }
    // [UPERF3-XX] the byte-identity gate: the flat encoding of every layer proof, concatenated, sha256'd
    {
        let mut all: Vec<u8> = Vec::with_capacity(bytes);
        for p in &proofs { all.extend_from_slice(&p.to_bytes()); }
        assert_eq!(all.len(), bytes, "serializer/size_bytes disagree");
        let digest = hashline::export::sha256_hex(&all);
        println!("PROOF sha256 {digest} ({} B)", all.len());
        if let Some(path) = &o.proof_out {
            std::fs::write(path, &all).unwrap_or_else(|e| panic!("cannot write {path}: {e}"));
            println!("  proof written to {path}");
        }
    }
    let mut ok = true;
    let mut t_verify = 0.0;
    if o.verify {
        let mut tv = Transcript::new(b"hashline-pass");
        let t0 = Instant::now();
        for (st, pr) in stmts.iter().zip(proofs.iter()) {
            if let Err(e) = verify_layer(st, pr, &p, &ntt, &mut tv) {
                println!("  layer {}: REJECT: {e}", st.l);
                ok = false;
                break;
            }
        }
        t_verify = t0.elapsed().as_secs_f64();
    }
    let macs = (n as f64) * (t as f64) * ((2.0 * D as f64 * F as f64) + (F as f64 * D as f64));
    println!("PASS {}: {n} x {t}: witness load+chain {t_load:.2} s | PROVE {t_prove:.2} s | VERIFY {t_verify:.2} s | proof {bytes} B ({:.1} MB) | {:.3e} MACs | {:.3e} proven MAC/s (prove wall) | wall {:.2} s",
        if ok { "ACCEPT" } else { "REJECT" }, bytes as f64 / 1e6, macs, macs / t_prove, t_all.elapsed().as_secs_f64());
    if !ok { std::process::exit(1); }
}

// ===========================================================================
// [UPERF3-ZB] the widened-stack (v3) profile
// ===========================================================================

/// The frozen int16-out registry, regenerated and pin-checked (the third
/// leg next to scripts/m8b_margins.py and `ring_matmul uperf-v3 tables`).
fn tables_v3() {
    println!("[UPERF3-ZB] the frozen int16-out table registry (regenerated from the frozen formula; digest == pin on every row):");
    for (name, ei, eo, d, mn, mx, sat) in hashline::tables_v3::registry_report() {
        println!("  {name} (eGate {ei:2}, eOut {eo:3}): out [{mn:6}, {mx:6}] sat rows {sat:3}  digest {d}");
    }
}

fn v3_dir_side(o: &Opts) -> (std::path::PathBuf, V3Sidecar) {
    let dir = export_dir_v3(o.export.as_deref());
    let side = V3Sidecar::load(&dir);
    (dir, side)
}

/// Rung 1: every per-tensor sha256 of the v3 export reproduces (X/WgT/WuT/WdT/a16/u16/h16/z16 per layer),
/// the sidecar's signed shifts equal the exponent-derived ones, every table row names a frozen member.
fn check_export_v3(o: &Opts) {
    let (dir, side) = v3_dir_side(o);
    let dm = side.dims;
    println!("export dir {} — model {} profile v3-widened/round, dims T {} d {} f {} layers {}{}", dir.display(), side.model, dm.t, dm.d, dm.f, dm.layers,
        side.zpolicy.as_ref().map(|z| format!(", zpolicy {z}")).unwrap_or_default());
    let t0 = Instant::now();
    let (mut ok_n, mut all_n) = (0usize, 0usize);
    for l in 0..dm.layers {
        let ex = load_layer_v3(&dir, &side, l, true, true);
        let bad: Vec<&str> = ex.digest_checks.iter().filter(|(_, ok)| !ok).map(|(n, _)| *n).collect();
        ok_n += ex.digest_checks.iter().filter(|(_, ok)| *ok).count();
        all_n += ex.digest_checks.len();
        let (sg, su, sh, sz) = ex.shifts;
        println!(
            "  layer {l:2}: {} digests {}; shifts g/u/h/z = {sg}/{su}/{sh}/{sz}; table {} ({},{}) {}..",
            ex.digest_checks.len(), if bad.is_empty() { "== sidecar".to_string() } else { format!("MISMATCH at {bad:?}") },
            ex.act.spec_name(), ex.exps.e_g, ex.exps.e_a16, &ex.table_digest[..16]
        );
    }
    println!("check-export v3: {ok_n}/{all_n} tensor digests reproduce ({:.2} s)", t0.elapsed().as_secs_f64());
    if ok_n != all_n { std::process::exit(1); }
}

/// Rung 2: re-execute the exact widened chain from X and the weights and reproduce the export's
/// a16/u16/h16/z16 planes — full-plane sha256 at t_rows == T, element-wise on the first t_rows rows otherwise.
fn chain_v3(n: Option<usize>, o: &Opts) {
    let (dir, side) = v3_dir_side(o);
    let dm = side.dims;
    let n = n.unwrap_or(dm.layers).min(dm.layers);
    let t_rows = o.t_rows.unwrap_or(dm.t);
    println!("chain v3: {} — {n} layers, T {t_rows} of {} (d {} f {}), {} threads", dir.display(), dm.t, dm.d, dm.f, rayon::current_num_threads());
    let t0 = Instant::now();
    let mut bad = 0usize;
    for l in 0..n {
        let ex = load_layer_v3(&dir, &side, l, true, false);
        let t1 = Instant::now();
        let w = derive_v3(&ex, t_rows);
        let mut line = String::new();
        let mut ok = w.range_ok;
        if t_rows == dm.t {
            for (i, name) in ["a16", "u16", "h16", "z16"].iter().enumerate() {
                let same = w.digests[i] == side.digest(l, name);
                ok &= same;
                line.push_str(&format!(" {name} {}{}", &w.digests[i][..8], if same { "==" } else { "!=" }));
            }
        } else {
            for (name, mism) in compare_planes(&w, &ex) {
                ok &= mism == 0;
                line.push_str(&format!(" {name} {}", if mism == 0 { "==".to_string() } else { format!("{mism} DIFF") }));
            }
        }
        if !ok { bad += 1; }
        let (sg, su, sh, sz) = w.shifts;
        println!("  layer {l:2}:{line}; range facts {}; shifts {sg}/{su}/{sh}/{sz}; table ({},{}); {:.2} s",
            if w.range_ok { "HOLD" } else { "FAIL" }, w.exps.e_g, w.exps.e_a16, t1.elapsed().as_secs_f64());
    }
    println!("chain v3: {}/{n} layers reproduce the export's a16/u16/h16/z16 ({:.2} s total)", n - bad, t0.elapsed().as_secs_f64());
    if bad > 0 { std::process::exit(1); }
}

fn tamper_v3_from(kind: &str, idx: usize) -> TamperV3 {
    match kind {
        "none" => TamperV3::None,
        "flipx" => TamperV3::FlipX(idx),
        "flipw" => TamperV3::FlipW(idx),
        "rem" => TamperV3::RemainderOutOfRange(idx),
        "table" => TamperV3::WrongTableEntry(idx),
        "requant" => TamperV3::WrongRequant(idx),
        "z" => TamperV3::WrongZ(idx),
        "round" => TamperV3::WrongRounding(idx),
        "i16" => TamperV3::OutOfRangeInt16(idx),
        other => { eprintln!("unknown v3 tamper {other}"); std::process::exit(2); }
    }
}

/// Load + derive layer `l`'s v3 witness over `t_rows` rows, gated by the export's planes (element-wise on
/// the first t_rows rows; the full-plane sha256s at t_rows == T).
fn load_witness_v3(dir: &std::path::Path, side: &V3Sidecar, l: usize, t_rows: usize) -> V3Witness {
    let ex = load_layer_v3(dir, side, l, true, false);
    let w = derive_v3(&ex, t_rows);
    for (name, mism) in compare_planes(&w, &ex) {
        assert_eq!(mism, 0, "layer {l}: derived {name} != the export's plane on the first {t_rows} rows ({mism} elements)");
    }
    if t_rows == side.dims.t {
        for (i, name) in ["a16", "u16", "h16", "z16"].iter().enumerate() {
            assert_eq!(w.digests[i], side.digest(l, name), "layer {l}: derived {name} sha256 != sidecar");
        }
    }
    assert!(w.range_ok, "layer {l}: a range fact fails on the honest witness");
    w
}

fn stmt_v3(w: &V3Witness, t: usize) -> StatementV3 {
    StatementV3 { l: w.l, t_rows: t, d: w.dims.d, f: w.dims.f, shifts: w.shifts, act: w.act, table: w.table, table_digest: w.table_digest.clone() }
}

fn run_layer_v3(w: &V3Witness, t: usize, o: &Opts, tamper: TamperV3, ntt: &NttTables) -> (bool, f64, f64, usize) {
    let mut w2 = clone_witness_v3(w);
    apply_tamper_v3(&mut w2, tamper);
    let p = params(o);
    let st = stmt_v3(w, t);
    let mut tr = Transcript::new(b"hashline-layer-v3");
    let t0 = Instant::now();
    let out = prove_layer_v3(&w2, t, &p, ntt, &mut tr);
    let tp = t0.elapsed().as_secs_f64();
    let bytes = out.proof.size_bytes();
    if !o.verify {
        return (true, tp, 0.0, bytes);
    }
    let mut tv = Transcript::new(b"hashline-layer-v3");
    let t1 = Instant::now();
    let r = verify_layer_v3(&st, &out.proof, &p, ntt, &mut tv);
    let tvv = t1.elapsed().as_secs_f64();
    if matches!(tamper, TamperV3::None) {
        for (name, s) in &out.timings {
            println!("      {name:<22} {s:8.3} s");
        }
    }
    match &r {
        Ok(()) => (true, tp, tvv, bytes),
        Err(e) => { println!("      reject: {e}"); (false, tp, tvv, bytes) }
    }
}

/// Rung 3: prove + verify one v3 layer (+ the eight tamper legs with --all-tampers).
fn layer_v3(l: usize, t: usize, o: &Opts) {
    let ntt = NttTables::new(o.log_cols + o.inv_rate.trailing_zeros());
    let (dir, side) = v3_dir_side(o);
    let dm = side.dims;
    let w = load_witness_v3(&dir, &side, l, t);
    let tamper = tamper_v3_from(&o.tamper_kind, o.tamper_idx);
    println!("layer {l} (v3) at T = {t} of {} (d {} f {}; log_cols {}, inv_rate {}, col checks {}, threads {}); {}", dm.t, dm.d, dm.f, o.log_cols, o.inv_rate, o.col_checks, rayon::current_num_threads(), hashline::gpu::label());
    let (sg, su, sh, sz) = w.shifts;
    println!("  statement: shifts g/u/h/z {sg}/{su}/{sh}/{sz}, {} ({},{}) {}..", w.act.spec_name(), w.exps.e_g, w.exps.e_a16, &w.table_digest[..16]);
    let (ok, tp, tv, bytes) = run_layer_v3(&w, t, o, tamper, &ntt);
    println!("  tamper {:?}: {} prove {tp:.3} s verify {tv:.3} s proof {bytes} B", tamper, if ok { "ACCEPT" } else { "REJECT" });
    let mut fails = 0;
    if matches!(tamper, TamperV3::None) && !ok { fails += 1; }
    if !matches!(tamper, TamperV3::None) && ok { fails += 1; }
    if o.all_tampers {
        let legs = [
            ("flipped X entry", TamperV3::FlipX(777)),
            ("flipped Wg entry", TamperV3::FlipW(4242)),
            ("out-of-range remainder", TamperV3::RemainderOutOfRange(99)),
            ("wrong int16 table entry", TamperV3::WrongTableEntry(1000)),
            ("wrong requant (h16)", TamperV3::WrongRequant(555)),
            ("wrong z", TamperV3::WrongZ(321)),
            ("wrong rounding (floor)", TamperV3::WrongRounding(2000)),
            ("out-of-range int16 (z16)", TamperV3::OutOfRangeInt16(123)),
        ];
        for (name, tm) in legs {
            let (ok, tp, tv, _) = run_layer_v3(&w, t, o, tm, &ntt);
            println!("  tamper [{name}]: {} (prove {tp:.2} s, verify {tv:.2} s)", if ok { "ACCEPTED (BUG)" } else { "REJECT" });
            if ok { fails += 1; }
        }
    }
    println!("layer {l} (v3): {}", if fails == 0 { "GREEN" } else { "RED" });
    if fails > 0 { std::process::exit(1); }
}

/// Rung 3/5: the chained multi-layer v3 pass, one transcript, measured.
fn pass_v3(n: usize, t: usize, o: &Opts) {
    let ntt = NttTables::new(o.log_cols + o.inv_rate.trailing_zeros());
    let p = params(o);
    let (dir, side) = v3_dir_side(o);
    let dm = side.dims;
    let n = n.min(dm.layers);
    println!("pass (v3): {n} layers x {t} tokens of {} — {} (d {} f {}; log_cols {}, inv_rate {}, col checks {}, threads {})", dm.t, dir.display(), dm.d, dm.f, o.log_cols, o.inv_rate, o.col_checks, rayon::current_num_threads());
    println!("  {}", hashline::gpu::label());
    let t_all = Instant::now();
    let tamper = tamper_v3_from(&o.tamper_kind, o.tamper_idx);
    let victim = n / 2;
    if !matches!(tamper, TamperV3::None) {
        println!("  (tamper {:?} applied to layer {victim}'s witness)", tamper);
    }
    let mut tr = Transcript::new(b"hashline-pass-v3");
    let mut proofs = Vec::with_capacity(n);
    let mut stmts = Vec::with_capacity(n);
    let mut agg: Vec<(String, f64)> = Vec::new();
    let mut t_load = 0.0f64;
    let mut t_prove = 0.0f64;
    // ONE witness resident at a time (a 7B layer's int8 weights + planes are ~0.35 GB; 32 of them
    // would be 11 GB before the first commitment). Load, prove, drop; the statement stays for the
    // verifier. The proof bytes do not depend on when the witness was loaded.
    for l in 0..n {
        let t0 = Instant::now();
        let mut w: V3Witness = load_witness_v3(&dir, &side, l, t);
        if l == victim && !matches!(tamper, TamperV3::None) {
            apply_tamper_v3(&mut w, tamper);
        }
        t_load += t0.elapsed().as_secs_f64();
        let t1 = Instant::now();
        let out = prove_layer_v3(&w, t, &p, &ntt, &mut tr);
        let dt = t1.elapsed().as_secs_f64();
        t_prove += dt;
        for (name, s) in &out.timings {
            if let Some(e) = agg.iter_mut().find(|e| &e.0 == name) { e.1 += s; } else { agg.push((name.clone(), *s)); }
        }
        println!("  layer {:2}: prove {:.3} s, {} B", w.l, dt, out.proof.size_bytes());
        stmts.push(stmt_v3(&w, t));
        proofs.push(out.proof);
    }
    let bytes: usize = proofs.iter().map(|p| p.size_bytes()).sum();
    println!("prover phases (summed over layers):");
    for (name, s) in &agg { println!("      {name:<22} {s:8.3} s"); }
    if hashline::gpu::enabled() {
        let g = hashline::gpu::dev_stats();
        println!(
            "  gpu device-side (summed): h2d {:.3} s ({:.0} MB) | ntt {:.3} s | hash {:.3} s | sumcheck {:.3} s | fold {:.3} s | helpers {:.3} s | d2h {:.3} s ({:.0} MB) | vram peak {:.0} MB",
            g.secs_h2d, g.bytes_h2d as f64 / 1e6, g.secs_ntt, g.secs_hash, g.secs_sumcheck, g.secs_fold, g.secs_helpers, g.secs_d2h, g.bytes_d2h as f64 / 1e6, g.vram_peak as f64 / 1e6
        );
    }
    {
        let mut all: Vec<u8> = Vec::with_capacity(bytes);
        for p in &proofs { all.extend_from_slice(&p.to_bytes()); }
        assert_eq!(all.len(), bytes, "serializer/size_bytes disagree");
        let digest = hashline::export::sha256_hex(&all);
        println!("PROOF sha256 {digest} ({} B)", all.len());
        if let Some(path) = &o.proof_out {
            std::fs::write(path, &all).unwrap_or_else(|e| panic!("cannot write {path}: {e}"));
            println!("  proof written to {path}");
        }
    }
    let mut ok = true;
    let mut t_verify = 0.0;
    if o.verify {
        let mut tv = Transcript::new(b"hashline-pass-v3");
        let t0 = Instant::now();
        for (st, pr) in stmts.iter().zip(proofs.iter()) {
            if let Err(e) = verify_layer_v3(st, pr, &p, &ntt, &mut tv) {
                println!("  layer {}: REJECT: {e}", st.l);
                ok = false;
                break;
            }
        }
        t_verify = t0.elapsed().as_secs_f64();
    }
    let macs = (n as f64) * (t as f64) * ((2.0 * dm.d as f64 * dm.f as f64) + (dm.f as f64 * dm.d as f64));
    println!("PASS-V3 {}: {n} x {t} (d {} f {}): witness load+chain {t_load:.2} s | PROVE {t_prove:.2} s | VERIFY {t_verify:.2} s | proof {bytes} B ({:.1} MB) | {:.3e} MACs | {:.3e} proven MAC/s (prove wall) | wall {:.2} s",
        if ok { "ACCEPT" } else { "REJECT" }, dm.d, dm.f, bytes as f64 / 1e6, macs, macs / t_prove, t_all.elapsed().as_secs_f64());
    if !ok { std::process::exit(1); }
}


// ===========================================================================
// [UPERF3-ZA] The `--zk` forms of `layer` and `pass` (mode P1: activations
// private, weights public; see src/zk.rs). Same shapes, same tamper legs,
// the PROOF sha256 line is the CPU/GPU parity gate under `--seed`.
// ===========================================================================

fn run_layer_zk(w: &LayerWitness, t: usize, o: &Opts, tamper: Tamper, ntt: &NttTables) -> (bool, f64, f64, usize) {
    use hashline::zk::{prove_layer_zk, verify_layer_zk};
    let mut w2 = clone_witness(w);
    apply_tamper(&mut w2, tamper);
    let p = params(o);
    let st = Statement { l: w.l, t_rows: t, shifts: w.shifts, table: w.table, table_digest: w.table_digest.clone() };
    let mut tr = Transcript::new(b"hashline-layer-zk");
    let t0 = Instant::now();
    let out = prove_layer_zk(&w2, t, &p, ntt, &o.zk, &mut tr);
    let tp = t0.elapsed().as_secs_f64();
    let bytes = out.proof.size_bytes();
    if !o.verify {
        return (true, tp, 0.0, bytes);
    }
    let mut tv = Transcript::new(b"hashline-layer-zk");
    let t1 = Instant::now();
    let r = verify_layer_zk(&st, &out.proof, &p, ntt, &mut tv);
    let tvv = t1.elapsed().as_secs_f64();
    if matches!(tamper, Tamper::None) {
        for (name, s) in &out.timings {
            println!("      {name:<26} {s:8.3} s");
        }
        println!("      mask sites:");
        for s in &out.sites { println!("        {s}"); }
    }
    match &r {
        Ok(()) => (true, tp, tvv, bytes),
        Err(e) => { println!("      reject: {e}"); (false, tp, tvv, bytes) }
    }
}

fn layer_zk(l: usize, t: usize, o: &Opts) {
    let ntt = NttTables::new(o.log_cols + o.inv_rate.trailing_zeros());
    let w = load_witness(l);
    println!("layer {l} at T = {t} [ZK, mode P1, seed {}] (log_cols {}, inv_rate {}, col checks {}, threads {})", o.zk.seed, o.log_cols, o.inv_rate, o.col_checks, rayon::current_num_threads());
    let (ok, tp, tv, bytes) = run_layer_zk(&w, t, o, o.tamper, &ntt);
    println!("  tamper {:?}: {} prove {tp:.3} s verify {tv:.3} s proof {bytes} B", o.tamper, if ok { "ACCEPT" } else { "REJECT" });
    let mut fails = 0;
    if matches!(o.tamper, Tamper::None) && !ok { fails += 1; }
    if !matches!(o.tamper, Tamper::None) && ok { fails += 1; }
    if o.all_tampers {
        let legs = [
            ("flipped X entry", Tamper::FlipX(777)),
            ("flipped Wg entry", Tamper::FlipW(4242)),
            ("out-of-range remainder", Tamper::RemainderOutOfRange(99)),
            ("wrong table entry", Tamper::WrongTableEntry(1000)),
            ("wrong requant (h8)", Tamper::WrongRequant(555)),
            ("wrong z", Tamper::WrongZ(321)),
        ];
        for (name, tm) in legs {
            let (ok, tp, tv, _) = run_layer_zk(&w, t, o, tm, &ntt);
            println!("  tamper [{name}]: {} (prove {tp:.2} s, verify {tv:.2} s)", if ok { "ACCEPTED (BUG)" } else { "REJECT" });
            if ok { fails += 1; }
        }
    }
    println!("layer {l} [ZK]: {}", if fails == 0 { "GREEN" } else { "RED" });
    if fails > 0 { std::process::exit(1); }
}

fn pass_zk(n: usize, t: usize, o: &Opts) {
    use hashline::zk::{prove_layer_zk, verify_layer_zk};
    let ntt = NttTables::new(o.log_cols + o.inv_rate.trailing_zeros());
    let p = params(o);
    println!("pass [ZK, mode P1, seed {}]: {n} layers x {t} tokens (log_cols {}, inv_rate {}, col checks {}, threads {})", o.zk.seed, o.log_cols, o.inv_rate, o.col_checks, rayon::current_num_threads());
    println!("  {}", hashline::gpu::label());
    let t_all = Instant::now();
    let t0 = Instant::now();
    let mut ws: Vec<LayerWitness> = (0..n).map(load_witness).collect();
    let t_load = t0.elapsed().as_secs_f64();
    if !matches!(o.tamper, Tamper::None) {
        let victim = n / 2;
        println!("  (tamper {:?} applied to layer {victim}'s witness)", o.tamper);
        apply_tamper(&mut ws[victim], o.tamper);
    }
    let mut tr = Transcript::new(b"hashline-pass-zk");
    let mut proofs = Vec::with_capacity(n);
    let mut stmts = Vec::with_capacity(n);
    let mut agg: Vec<(String, f64)> = Vec::new();
    let mut sites: Vec<String> = Vec::new();
    let t0 = Instant::now();
    for w in &ws {
        let t1 = Instant::now();
        let out = prove_layer_zk(w, t, &p, &ntt, &o.zk, &mut tr);
        for (name, s) in &out.timings {
            if let Some(e) = agg.iter_mut().find(|e| &e.0 == name) { e.1 += s; } else { agg.push((name.clone(), *s)); }
        }
        if sites.is_empty() { sites = out.sites.clone(); }
        println!("  layer {:2}: prove {:.3} s, {} B", w.l, t1.elapsed().as_secs_f64(), out.proof.size_bytes());
        stmts.push(Statement { l: w.l, t_rows: t, shifts: w.shifts, table: w.table, table_digest: w.table_digest.clone() });
        proofs.push(out.proof);
    }
    let t_prove = t0.elapsed().as_secs_f64();
    let bytes: usize = proofs.iter().map(|p| p.size_bytes()).sum();
    println!("prover phases (summed over layers):");
    for (name, s) in &agg { println!("      {name:<26} {s:8.3} s"); }
    println!("mask sites (layer 0; every layer identical in structure):");
    for s in &sites { println!("      {s}"); }
    if hashline::gpu::enabled() {
        let g = hashline::gpu::dev_stats();
        println!(
            "  gpu device-side (summed): h2d {:.3} s ({:.0} MB) | ntt {:.3} s | hash {:.3} s | sumcheck {:.3} s | fold {:.3} s | helpers {:.3} s | d2h {:.3} s ({:.0} MB) | vram peak {:.0} MB",
            g.secs_h2d, g.bytes_h2d as f64 / 1e6, g.secs_ntt, g.secs_hash, g.secs_sumcheck, g.secs_fold, g.secs_helpers, g.secs_d2h, g.bytes_d2h as f64 / 1e6, g.vram_peak as f64 / 1e6
        );
    }
    {
        let mut all: Vec<u8> = Vec::with_capacity(bytes);
        for p in &proofs { all.extend_from_slice(&p.to_bytes()); }
        assert_eq!(all.len(), bytes, "serializer/size_bytes disagree");
        let digest = hashline::export::sha256_hex(&all);
        println!("PROOF sha256 {digest} ({} B) [ZK seed {}]", all.len(), o.zk.seed);
        if let Some(path) = &o.proof_out {
            std::fs::write(path, &all).unwrap_or_else(|e| panic!("cannot write {path}: {e}"));
            println!("  proof written to {path}");
        }
    }
    let mut ok = true;
    let mut t_verify = 0.0;
    if o.verify {
        let mut tv = Transcript::new(b"hashline-pass-zk");
        let t0 = Instant::now();
        for (st, pr) in stmts.iter().zip(proofs.iter()) {
            if let Err(e) = verify_layer_zk(st, pr, &p, &ntt, &mut tv) {
                println!("  layer {}: REJECT: {e}", st.l);
                ok = false;
                break;
            }
        }
        t_verify = t0.elapsed().as_secs_f64();
    }
    let macs = (n as f64) * (t as f64) * ((2.0 * D as f64 * F as f64) + (F as f64 * D as f64));
    println!("PASS {} [ZK]: {n} x {t}: witness load+chain {t_load:.2} s | PROVE {t_prove:.2} s | VERIFY {t_verify:.2} s | proof {bytes} B ({:.1} MB) | {:.3e} MACs | {:.3e} proven MAC/s (prove wall) | wall {:.2} s",
        if ok { "ACCEPT" } else { "REJECT" }, bytes as f64 / 1e6, macs, macs / t_prove, t_all.elapsed().as_secs_f64());
    if !ok { std::process::exit(1); }
}

// ===========================================================================
// [UPERF3-AD] `--zk --profile v3`: the ZK form of the widened-stack statement
// (mode P1 composed with lane ZB's semantics; the [UPERF3-AD] section of
// src/zk.rs). Same shapes, ZB's eight tamper legs, the PROOF sha256 line is
// the CPU/GPU parity gate under `--seed`.
// ===========================================================================

fn run_layer_zk_v3(w: &V3Witness, t: usize, o: &Opts, tamper: TamperV3, ntt: &NttTables) -> (bool, f64, f64, usize) {
    use hashline::zk::{prove_layer_zk_v3, verify_layer_zk_v3};
    let mut w2 = clone_witness_v3(w);
    apply_tamper_v3(&mut w2, tamper);
    let p = params(o);
    let st = stmt_v3(w, t);
    let mut tr = Transcript::new(b"hashline-layer-zk-v3");
    let t0 = Instant::now();
    let out = prove_layer_zk_v3(&w2, t, &p, ntt, &o.zk, &mut tr);
    let tp = t0.elapsed().as_secs_f64();
    let bytes = out.proof.size_bytes();
    if !o.verify {
        return (true, tp, 0.0, bytes);
    }
    let mut tv = Transcript::new(b"hashline-layer-zk-v3");
    let t1 = Instant::now();
    let r = verify_layer_zk_v3(&st, &out.proof, &p, ntt, &mut tv);
    let tvv = t1.elapsed().as_secs_f64();
    if matches!(tamper, TamperV3::None) {
        for (name, s) in &out.timings {
            println!("      {name:<26} {s:8.3} s");
        }
        println!("      mask sites (v3):");
        for s in &out.sites { println!("        {s}"); }
    }
    match &r {
        Ok(()) => (true, tp, tvv, bytes),
        Err(e) => { println!("      reject: {e}"); (false, tp, tvv, bytes) }
    }
}

fn layer_zk_v3(l: usize, t: usize, o: &Opts) {
    let ntt = NttTables::new(o.log_cols + o.inv_rate.trailing_zeros());
    let (dir, side) = v3_dir_side(o);
    let dm = side.dims;
    let w = load_witness_v3(&dir, &side, l, t);
    let tamper = tamper_v3_from(&o.tamper_kind, o.tamper_idx);
    println!("layer {l} (v3) at T = {t} of {} [ZK, mode P1, seed {}] (d {} f {}; log_cols {}, inv_rate {}, col checks {}, threads {}); {}", dm.t, o.zk.seed, dm.d, dm.f, o.log_cols, o.inv_rate, o.col_checks, rayon::current_num_threads(), hashline::gpu::label());
    let (sg, su, sh, sz) = w.shifts;
    println!("  statement: shifts g/u/h/z {sg}/{su}/{sh}/{sz}, {} ({},{}) {}..", w.act.spec_name(), w.exps.e_g, w.exps.e_a16, &w.table_digest[..16]);
    let (ok, tp, tv, bytes) = run_layer_zk_v3(&w, t, o, tamper, &ntt);
    println!("  tamper {:?}: {} prove {tp:.3} s verify {tv:.3} s proof {bytes} B", tamper, if ok { "ACCEPT" } else { "REJECT" });
    let mut fails = 0;
    if matches!(tamper, TamperV3::None) && !ok { fails += 1; }
    if !matches!(tamper, TamperV3::None) && ok { fails += 1; }
    if o.all_tampers {
        let legs = [
            ("flipped X entry", TamperV3::FlipX(777)),
            ("flipped Wg entry", TamperV3::FlipW(4242)),
            ("out-of-range remainder", TamperV3::RemainderOutOfRange(99)),
            ("wrong int16 table entry", TamperV3::WrongTableEntry(1000)),
            ("wrong requant (h16)", TamperV3::WrongRequant(555)),
            ("wrong z", TamperV3::WrongZ(321)),
            ("wrong rounding (floor)", TamperV3::WrongRounding(2000)),
            ("out-of-range int16 (z16)", TamperV3::OutOfRangeInt16(123)),
        ];
        for (name, tm) in legs {
            let (ok, tp, tv, _) = run_layer_zk_v3(&w, t, o, tm, &ntt);
            println!("  tamper [{name}]: {} (prove {tp:.2} s, verify {tv:.2} s)", if ok { "ACCEPTED (BUG)" } else { "REJECT" });
            if ok { fails += 1; }
        }
    }
    println!("layer {l} (v3) [ZK]: {}", if fails == 0 { "GREEN" } else { "RED" });
    if fails > 0 { std::process::exit(1); }
}

fn pass_zk_v3(n: usize, t: usize, o: &Opts) {
    use hashline::zk::{prove_layer_zk_v3, verify_layer_zk_v3};
    let ntt = NttTables::new(o.log_cols + o.inv_rate.trailing_zeros());
    let p = params(o);
    let (dir, side) = v3_dir_side(o);
    let dm = side.dims;
    let n = n.min(dm.layers);
    println!("pass (v3) [ZK, mode P1, seed {}]: {n} layers x {t} tokens of {} — {} (d {} f {}; log_cols {}, inv_rate {}, col checks {}, threads {})", o.zk.seed, dm.t, dir.display(), dm.d, dm.f, o.log_cols, o.inv_rate, o.col_checks, rayon::current_num_threads());
    println!("  {}", hashline::gpu::label());
    let t_all = Instant::now();
    let tamper = tamper_v3_from(&o.tamper_kind, o.tamper_idx);
    let victim = n / 2;
    if !matches!(tamper, TamperV3::None) {
        println!("  (tamper {:?} applied to layer {victim}'s witness)", tamper);
    }
    let mut tr = Transcript::new(b"hashline-pass-zk-v3");
    let mut proofs = Vec::with_capacity(n);
    let mut stmts = Vec::with_capacity(n);
    let mut agg: Vec<(String, f64)> = Vec::new();
    let mut sites: Vec<String> = Vec::new();
    let mut t_load = 0.0f64;
    let mut t_prove = 0.0f64;
    // ONE witness resident at a time (ZB's pass_v3 discipline; the 7B layer's planes are ~0.4 GB)
    for l in 0..n {
        let t0 = Instant::now();
        let mut w: V3Witness = load_witness_v3(&dir, &side, l, t);
        if l == victim && !matches!(tamper, TamperV3::None) {
            apply_tamper_v3(&mut w, tamper);
        }
        t_load += t0.elapsed().as_secs_f64();
        let t1 = Instant::now();
        let out = prove_layer_zk_v3(&w, t, &p, &ntt, &o.zk, &mut tr);
        let dt = t1.elapsed().as_secs_f64();
        t_prove += dt;
        for (name, s) in &out.timings {
            if let Some(e) = agg.iter_mut().find(|e| &e.0 == name) { e.1 += s; } else { agg.push((name.clone(), *s)); }
        }
        if sites.is_empty() { sites = out.sites.clone(); }
        println!("  layer {:2}: prove {:.3} s, {} B", w.l, dt, out.proof.size_bytes());
        stmts.push(stmt_v3(&w, t));
        proofs.push(out.proof);
    }
    let bytes: usize = proofs.iter().map(|p| p.size_bytes()).sum();
    println!("prover phases (summed over layers):");
    for (name, s) in &agg { println!("      {name:<26} {s:8.3} s"); }
    println!("mask sites (v3; layer 0 — every layer identical in structure up to its window sizes):");
    for s in &sites { println!("      {s}"); }
    if hashline::gpu::enabled() {
        let g = hashline::gpu::dev_stats();
        println!(
            "  gpu device-side (summed): h2d {:.3} s ({:.0} MB) | ntt {:.3} s | hash {:.3} s | sumcheck {:.3} s | fold {:.3} s | helpers {:.3} s | d2h {:.3} s ({:.0} MB) | vram peak {:.0} MB",
            g.secs_h2d, g.bytes_h2d as f64 / 1e6, g.secs_ntt, g.secs_hash, g.secs_sumcheck, g.secs_fold, g.secs_helpers, g.secs_d2h, g.bytes_d2h as f64 / 1e6, g.vram_peak as f64 / 1e6
        );
    }
    {
        let mut all: Vec<u8> = Vec::with_capacity(bytes);
        for p in &proofs { all.extend_from_slice(&p.to_bytes()); }
        assert_eq!(all.len(), bytes, "serializer/size_bytes disagree");
        let digest = hashline::export::sha256_hex(&all);
        println!("PROOF sha256 {digest} ({} B) [ZK v3 seed {}]", all.len(), o.zk.seed);
        if let Some(path) = &o.proof_out {
            std::fs::write(path, &all).unwrap_or_else(|e| panic!("cannot write {path}: {e}"));
            println!("  proof written to {path}");
        }
    }
    let mut ok = true;
    let mut t_verify = 0.0;
    if o.verify {
        let mut tv = Transcript::new(b"hashline-pass-zk-v3");
        let t0 = Instant::now();
        for (st, pr) in stmts.iter().zip(proofs.iter()) {
            if let Err(e) = verify_layer_zk_v3(st, pr, &p, &ntt, &mut tv) {
                println!("  layer {}: REJECT: {e}", st.l);
                ok = false;
                break;
            }
        }
        t_verify = t0.elapsed().as_secs_f64();
    }
    let macs = (n as f64) * (t as f64) * ((2.0 * dm.d as f64 * dm.f as f64) + (dm.f as f64 * dm.d as f64));
    println!("PASS-V3 {} [ZK]: {n} x {t} (d {} f {}): witness load+chain {t_load:.2} s | PROVE {t_prove:.2} s | VERIFY {t_verify:.2} s | proof {bytes} B ({:.1} MB) | {:.3e} MACs | {:.3e} proven MAC/s (prove wall) | wall {:.2} s",
        if ok { "ACCEPT" } else { "REJECT" }, dm.d, dm.f, bytes as f64 / 1e6, macs, macs / t_prove, t_all.elapsed().as_secs_f64());
    if !ok { std::process::exit(1); }
}
