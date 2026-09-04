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
//!       --wcache DIR  [UPERF3-AC] the per-model weight-commitment cache (src/wcache.rs): each layer's W Merkle tree
//!   committed once and reused (verified on load); the proof bytes do not change. HL_WCACHE_VERBOSE=1 per layer.
//!       --zk --profile v3  [UPERF3-AD] the ZK form of the widened-stack statement (mode P1 composed with v3; the [UPERF3-AD] section of src/zk.rs)

use hashline::chain::{derive, LayerWitness};
use hashline::export::{export_dir, load_layer, Sidecar, D, F, LAYERS};
use hashline::layer::{apply_tamper, matmul_differential, prove_layer, verify_layer, LayerParams, Statement, Tamper};
use hashline::ntt::NttTables;
use hashline::transcript::Transcript;
use std::time::Instant;
use hashline::export_v3::{clone_witness_v3, compare_planes, derive_v3, derive_v3_with_table, export_dir_v3, load_layer_v3, V3Sidecar, V3Witness};
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
    /// [UPERF3-AC] `--wcache DIR`: the per-model weight-commitment cache (default off).
    wcache: Option<String>,
    /// [UPERF3-AF] `--pcs ligero|compact` (default ligero: the byte-identical path) + its `--pcs-*` knobs.
    pcs: String,
    cpcs: hashline::pcs_compact::CompactCfg,
}

fn parse_opts(args: &[String]) -> Opts {
    let mut o = Opts { threads: 0, log_cols: 14, col_checks: 256, inv_rate: 4, tamper: Tamper::None, verify: true, all_tampers: false, proof_out: None,
        profile: "v2".to_string(), export: None, t_rows: None, tamper_kind: "none".to_string(), tamper_idx: 12345, zk: hashline::zk::ZkConfig::default(),
        wcache: None, pcs: "ligero".to_string(), cpcs: hashline::pcs_compact::CompactCfg::DEFAULT };
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
            "--wcache" => { o.wcache = Some(args[i + 1].clone()); i += 1; } // [UPERF3-AC]
            // [UPERF3-AF] the compact-PCS selection (default `ligero`: the byte-identical path)
            "--pcs" => { o.pcs = args[i + 1].clone(); i += 1; }
            "--pcs-inv-rate" => { o.cpcs.inv_rate = args[i + 1].parse().unwrap(); i += 1; }
            "--pcs-queries" => { o.cpcs.queries = args[i + 1].parse().unwrap(); i += 1; }
            "--pcs-bits" => { o.cpcs.target_bits = args[i + 1].parse().unwrap(); i += 1; }
            "--pcs-log-final" => { o.cpcs.log_final = args[i + 1].parse().unwrap(); i += 1; }
            "--pcs-pieces" => { o.cpcs.max_pieces = args[i + 1].parse().unwrap(); i += 1; }
            "--pcs-reencode" => { o.cpcs.reencode = true; }
            other => { eprintln!("unknown option {other}"); std::process::exit(2); }
        }
        i += 1;
    }
    hashline::wcache::configure(o.wcache.as_deref()); // [UPERF3-AC]
    o.tamper_kind = tkind.clone();
    o.tamper_idx = tidx;
    if o.profile == "v3" {
        // v3 tamper names are resolved by the v3 driver (a superset)
    } else {
        o.tamper = tamper_from(&tkind, tidx);
    }
    if o.profile != "v2" && o.profile != "v3" { eprintln!("unknown profile {} (v2|v3)", o.profile); std::process::exit(2); }
    // [UPERF3-AF] the PCS selection is process-global (prover and verifier read it); `ligero` leaves it off.
    match o.pcs.as_str() {
        "ligero" => {}
        "compact" => {
            if o.zk.enabled { eprintln!("--pcs compact with --zk is not built yet (the compact form is not hiding; see the ZK-interaction statement in PROGRESS_UPERF3.md)"); std::process::exit(2); }
            o.cpcs.enabled = true;
            hashline::pcs_compact::configure(o.cpcs);
        }
        other => { eprintln!("unknown pcs {other} (ligero|compact)"); std::process::exit(2); }
    }
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

// [UPERF3-AF] ---- rung 1: the PCS alone, the Ligero form vs the compact form ----
// Random multilinears at 2^lo .. 2^hi coefficients, the same claim set answered by
// both commitments, plus the three tamper legs on the compact opening.

fn af_rng(s: &mut u64) -> u64 {
    let mut x = *s;
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    *s = x;
    x.wrapping_mul(0x2545F4914F6CDD1D)
}

fn pcs_bench(lo: u32, hi: u32, o: &Opts) {
    use hashline::field::{Fp, Fp2};
    use hashline::mle::eval_mle_base;
    use hashline::pcs::{self, Claim, PcsParams, Slice};
    use hashline::pcs_compact as cp;

    let mut cfg = o.cpcs;
    cfg.enabled = true;
    cp::configure(cfg);
    let qn = cfg.effective_queries();
    let n_claims: usize = std::env::var("HL_BENCH_CLAIMS").ok().and_then(|v| v.parse().ok()).unwrap_or(1);
    println!(
        "pcs-bench [UPERF3-AF]: Ligero (log_cols {} inv_rate {} col-checks {}) vs compact (inv_rate {} Q {} log_final {} max_pieces {}), {} claim(s), threads {}",
        o.log_cols, o.inv_rate, o.col_checks, cfg.inv_rate, qn, cfg.log_final, cfg.max_pieces, n_claims, rayon::current_num_threads()
    );
    println!("{:>5} {:>6} {:>13} {:>13} {:>7} {:>9} {:>9} {:>7} {:>9} {:>9} {:>7}  tampers",
        "log N", "pieces", "Ligero B", "compact B", "x", "Lig P s", "cmp P s", "x", "Lig V s", "cmp V s", "x");
    for log_n in lo..=hi {
        let n = 1usize << log_n;
        let mut s = 0xC0FFEEu64 + log_n as u64;
        let data: Vec<Fp> = (0..n).map(|_| Fp::from_i64((af_rng(&mut s) % 256) as i64 - 128)).collect();
        let log_cols = o.log_cols.min(log_n);
        let params = PcsParams { log_cols, inv_rate: o.inv_rate, num_col_checks: o.col_checks };
        let ntt = NttTables::new(log_cols + o.inv_rate.trailing_zeros());
        // the claim set: an evaluation of the whole vector, then halves/quarters, then a sum
        let mut claims: Vec<Claim> = Vec::new();
        for c in 0..n_claims {
            let ls = if c == 0 { log_n } else { log_n.saturating_sub(1).max(log_cols) };
            let nslice = 1usize << ls;
            let off = if c == 0 { 0 } else { ((c - 1) % (n / nslice)) * nslice };
            if c + 1 == n_claims && n_claims > 1 {
                let v = data[off..off + nslice].iter().fold(Fp2::ZERO, |a, x| a.add_base(*x));
                claims.push(Claim { parts: vec![(Slice { offset: off, log_size: ls }, Fp2::ONE)], point: vec![], sum: true, value: v });
            } else {
                let pt: Vec<Fp2> = (0..ls).map(|_| Fp2::new(Fp::new(af_rng(&mut s) % hashline::field::P), Fp::new(af_rng(&mut s) % hashline::field::P))).collect();
                let v = eval_mle_base(&data[off..off + nslice], &pt);
                claims.push(Claim { parts: vec![(Slice { offset: off, log_size: ls }, Fp2::ONE)], point: pt, sum: false, value: v });
            }
        }
        // ---- the Ligero form (pcs.rs, untouched) ----
        let t0 = Instant::now();
        let lcm = pcs::commit(&params, &data, &ntt);
        let lcom = lcm.commitment();
        let mut tr = Transcript::new(b"af-bench");
        let lop = pcs::open(&lcm, &claims, &mut tr);
        let lp = t0.elapsed().as_secs_f64();
        let lbytes = lop.size_bytes() + 44;
        let t1 = Instant::now();
        let mut tv = Transcript::new(b"af-bench");
        pcs::verify(&params, &lcom, &claims, &lop, &ntt, &mut tv).expect("ligero accept");
        let lv = t1.elapsed().as_secs_f64();
        drop(lcm);
        // ---- the compact form ----
        let t2 = Instant::now();
        let ccm = cp::commit_compact(&params, &data);
        let ccom = ccm.commitment();
        let npieces = ccm.pieces.len();
        let mut tr = Transcript::new(b"af-bench");
        let cop = cp::open_batch(&[(&ccm, &claims)], &mut tr);
        let cp_s = t2.elapsed().as_secs_f64();
        let cbytes = cop.size_bytes() + 44;
        let t3 = Instant::now();
        let mut tv = Transcript::new(b"af-bench");
        cp::verify_batch(&[(&params, &ccom, &claims)], &cop, &mut tv).expect("compact accept");
        let cv = t3.elapsed().as_secs_f64();
        // ---- the three tamper legs on the compact opening ----
        let mut legs = String::new();
        // 1. a wrong claimed evaluation
        let mut bad = claims.clone();
        bad[0].value = bad[0].value.add(Fp2::ONE);
        let mut tv = Transcript::new(b"af-bench");
        legs.push_str(if cp::verify_batch(&[(&params, &ccom, &bad)], &cop, &mut tv).is_err() { "eval:REJECT " } else { "eval:ACCEPT(BAD) " });
        // 2. a corrupted opening value
        let mut p = cop.clone();
        p.queries[0].groups[0].0[0] = p.queries[0].groups[0].0[0].add(Fp::ONE);
        let mut tv = Transcript::new(b"af-bench");
        legs.push_str(if cp::verify_batch(&[(&params, &ccom, &claims)], &p, &mut tv).is_err() { "open:REJECT " } else { "open:ACCEPT(BAD) " });
        // 3. a wrong Merkle path
        let mut p = cop.clone();
        let plen = p.queries[0].groups[0].1.len();
        if plen >= 2 { p.queries[0].groups[0].1.swap(0, plen - 1); } else { p.queries[0].groups[0].1[0][0] ^= 1; }
        let mut tv = Transcript::new(b"af-bench");
        legs.push_str(if cp::verify_batch(&[(&params, &ccom, &claims)], &p, &mut tv).is_err() { "path:REJECT" } else { "path:ACCEPT(BAD)" });
        println!("{:>5} {:>6} {:>13} {:>13} {:>6.2}x {:>9.3} {:>9.3} {:>6.2}x {:>9.4} {:>9.4} {:>6.2}x  {legs}",
            log_n, npieces, lbytes, cbytes, lbytes as f64 / cbytes as f64, lp, cp_s, cp_s / lp, lv, cv, cv / lv);
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
        // [UPERF3-AE] rung 3: the attention value chain from an oracle
        // export (scripts/attention_hash_ref.py --export DIR); diffs every
        // per-tensor digest and the CHAIN against the oracle's manifest.
        "attn-chain" => {
            let dir = args.get(2).map(|s| s.as_str()).unwrap_or_else(|| {
                eprintln!("usage: hashline attn-chain <export-dir> [--attn-verbose]");
                std::process::exit(2)
            });
            let verbose = args.iter().any(|a| a == "--attn-verbose");
            let t0 = std::time::Instant::now();
            let (ok, n) = hashline::attention::verify_export(dir, verbose);
            println!(
                "attn-chain {dir}: {ok}/{n} tensor digests match the oracle ({:.2} s)",
                t0.elapsed().as_secs_f64()
            );
            if ok != n {
                std::process::exit(1);
            }
        }
        // [UPERF3-AG] rung 4: the attention half-layer proof alone (no FFN):
        // prove + verify one layer's attention + norms + residual over an
        // oracle export, with --t to truncate the token axis.
        "attn-layer" => {
            let dir = args.get(2).cloned().unwrap_or_else(|| {
                eprintln!("usage: hashline attn-layer <export-dir> [--t T] [--all-tampers]");
                std::process::exit(2)
            });
            let o = parse_opts(&args[3..]);
            attn_layer(&dir, &o)
        }
        // [UPERF3-AG] rung 4: THE FULL LAYER — attention + norms + residual
        // + the v3 FFN half on the same transcript, bound by the seam.
        "attn-full" => {
            let dir = args.get(2).cloned().unwrap_or_else(|| {
                eprintln!("usage: hashline attn-full <attn-export-dir> --export <v3-export> [--t T] [--all-tampers]");
                std::process::exit(2)
            });
            let o = parse_opts(&args[3..]);
            attn_full(&dir, &o)
        }
        "gpu-probe" => gpu_probe(),
        // [UPERF3-AF] rung 1: the PCS alone, Ligero vs compact, on random multilinears
        "pcs-bench" => {
            let lo: u32 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(14);
            let hi: u32 = args.get(3).and_then(|s| s.parse().ok()).unwrap_or(20);
            let rest = if args.len() > 4 { &args[4..] } else { &args[args.len()..] };
            let o = parse_opts(rest);
            pcs_bench(lo, hi, &o);
        }
        _ => {
            eprintln!("usage: hashline check-export | chain [layers] | matmul <layers> <t> | layer <l> <t> | pass <layers> <t>  [opts] | gpu-probe | tables-v3 | pcs-bench <log_lo> <log_hi>   (opts incl. --profile v2|v3 --export DIR, --pcs ligero|compact)");
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
    // [UPERF3-AC] rung 2: the CHUNKED commit — streaming blake3 leaves + the re-encoded opening columns == the CPU's,
    // at row counts on both sides of every 128-row (one blake3 chunk) boundary and at several chunk sizes
    #[cfg(feature = "gpu-cuda")]
    {
        let mut fails = 0;
        for (log_cols, inv_rate, rows, chunk) in [(10u32, 4usize, 300usize, 128usize), (10, 4, 127, 128), (10, 4, 128, 128), (10, 4, 129, 128), (10, 4, 255, 128), (10, 4, 256, 128), (10, 4, 257, 128), (10, 4, 1024, 128), (10, 4, 1025, 256), (12, 4, 1000, 256), (14, 4, 64, 128), (14, 4, 700, 384), (13, 2, 4, 128), (12, 8, 3, 128), (14, 4, 2200, 1024)] {
            match hashline::gpu::dev_commit_check_chunked(log_cols, inv_rate, rows, chunk) {
                Ok((bl, bc)) => {
                    println!("  chunked check log_cols {log_cols} inv_rate {inv_rate} rows {rows} chunk {chunk}: {bl} leaf mismatches, {bc} column mismatches");
                    if bl > 0 || bc > 0 { fails += 1; }
                }
                Err(e) => { println!("  chunked check log_cols {log_cols} inv_rate {inv_rate} rows {rows} chunk {chunk}: ERROR {e}"); fails += 1; }
            }
        }
        println!("gpu-probe: chunked-commit checks {}", if fails == 0 { "GREEN" } else { "RED" });
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
        println!("  gpu chunked [UPERF3-AC]: chunked commits {} | opening re-encode {:.3} s", g.n_chunked, g.secs_reenc);
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
    if let Some(r) = hashline::wcache::report() { println!("  {r}"); } // [UPERF3-AC]
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
        println!("  gpu chunked [UPERF3-AC]: chunked commits {} | opening re-encode {:.3} s", g.n_chunked, g.secs_reenc);
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
    if let Some(r) = hashline::wcache::report() { println!("  {r}"); } // [UPERF3-AC]
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

// ===========================================================================
// [UPERF3-AG] the full-layer path
// ===========================================================================

fn attn_layer(dir: &str, o: &Opts) {
    use hashline::attention as at;
    let ntt = NttTables::new(o.log_cols + o.inv_rate.trailing_zeros());
    let p = params(o);
    let t0 = Instant::now();
    let wit = at::build_attn_witness_t(dir, o.t_rows);
    let s = wit.c.shape;
    println!("attn-layer {dir}: T {} d {} H {}/{} d_h {} (witness {:.2} s, {} threads)",
             s.t, s.d, s.heads, s.kv_heads, s.head_dim, t0.elapsed().as_secs_f64(),
             rayon::current_num_threads());
    let z16 = vec![0i64; s.t * s.d];
    let r2 = at::residual2(&wit, z16, wit.c.e_r1, wit.c.e_r1, wit.c.r1_cls);
    println!("  residual2 (no FFN half in this mode): sh_x2 {} sh_z2 {} sh_r2 {} e_r2 {}",
             r2.c.sh_x2, r2.c.sh_z2, r2.c.sh_r2, r2.c.e_r2);
    let legs: Vec<(&str, at::AttnTamper)> = vec![
        ("flipped x_in", at::AttnTamper::FlipX(777)),
        ("flipped score s8", at::AttnTamper::FlipScore(4242)),
        ("wrong exp-table entry", at::AttnTamper::WrongExp(1000)),
        ("wrong softmax quotient", at::AttnTamper::WrongQuot(555)),
        ("wrong norm output", at::AttnTamper::WrongNorm(321)),
        ("wrong isqrt D", at::AttnTamper::WrongIsqrt(11)),
        ("wrong RoPE rotation", at::AttnTamper::WrongRope(999)),
        ("wrong row maximum", at::AttnTamper::WrongMax(17)),
        ("attainment selector moved", at::AttnTamper::WrongZsel(2048)),
        ("broken residual/seam plane", at::AttnTamper::BreakSeam(123)),
    ];
    let mut tr = Transcript::new(b"hashline-attn-layer");
    let t1 = Instant::now();
    let (mut proof, pend, timings) = at::prove_attn(&wit, &r2, &p, &ntt, &mut tr);
    let lay = pend.lay.clone();
    at::attn_open(pend, &mut proof, &mut tr);
    let tp = t1.elapsed().as_secs_f64();
    for (n, x) in &timings { println!("      {n:<24} {x:8.3} s"); }
    println!("  PROVE {tp:.3} s, proof {} B ({:.1} MB); a_len {} h_len {} w_len {} cols 2^{}",
             proof.size_bytes(), proof.size_bytes() as f64 / 1e6, lay.a_len, lay.h_len, lay.w_len, lay.cols_log);
    let t2 = Instant::now();
    let mut tv = Transcript::new(b"hashline-attn-layer");
    let r = (|| -> Result<(), String> {
        let (lay2, cc) = at::verify_attn(&proof, &wit.c, &r2.c, &p, &mut tv)?;
        at::verify_attn_open(&proof, &lay2, &cc, &p, &ntt, &mut tv)
    })();
    let tvv = t2.elapsed().as_secs_f64();
    let mut fails = 0;
    match &r {
        Ok(()) => println!("  VERIFY {tvv:.3} s: ACCEPT"),
        Err(e) => { println!("  VERIFY {tvv:.3} s: REJECT: {e}"); fails += 1; }
    }
    if o.all_tampers {
        at::set_tamper_mode(true);
        for (name, tm) in legs {
            let mut w2 = at::clone_attn_witness(&wit);
            let mut r22 = at::clone_resid2(&r2);
            at::apply_attn_tamper(&mut w2, &mut r22, tm);
            let mut trp = Transcript::new(b"hashline-attn-layer");
            let (mut pf, pend, _) = at::prove_attn(&w2, &r22, &p, &ntt, &mut trp);
            at::attn_open(pend, &mut pf, &mut trp);
            let mut trv = Transcript::new(b"hashline-attn-layer");
            let rr = (|| -> Result<(), String> {
                let (l2, cc) = at::verify_attn(&pf, &w2.c, &r22.c, &p, &mut trv)?;
                at::verify_attn_open(&pf, &l2, &cc, &p, &ntt, &mut trv)
            })();
            match rr {
                Ok(()) => { println!("  tamper [{name}]: ACCEPTED (BUG)"); fails += 1; }
                Err(e) => println!("  tamper [{name}]: REJECT ({})", first_line(&e)),
            }
        }
        at::set_tamper_mode(false);
    }
    println!("attn-layer: {}", if fails == 0 { "GREEN" } else { "RED" });
    if fails > 0 { std::process::exit(1); }
}

fn first_line(e: &str) -> String {
    e.chars().take(72).collect()
}

/// [UPERF3-AG] one FULL layer: the attention half (its own W/A/H
/// commitments) and the v3 FFN half on ONE transcript, bound by the SEAM
/// (the FFN's X IS the attention's xm8; the residual pin's z16 copy IS the
/// FFN's z16), both checked at the point the FFN's zero-check D drew after
/// both A commitments.
fn attn_full(dir: &str, o: &Opts) {
    use hashline::attention as at;
    use hashline::field::Fp2;
    use hashline::layer::{v3_zcd_point, LayoutV3};
    let ntt = NttTables::new(o.log_cols + o.inv_rate.trailing_zeros());
    let p = params(o);
    let (v3dir, side) = v3_dir_side(o);
    let t0 = Instant::now();
    let l0 = at::layer_of(dir);
    let ex_e_x = {
        let (dir2, side2) = v3_dir_side(o);
        let _ = &dir2;
        side2.exps(l0).e_x
    };
    let wit = at::build_attn_witness_full(dir, o.t_rows, None, Some(ex_e_x));
    let sh = wit.c.shape;
    let (t, d) = (sh.t, sh.d);
    let l = wit.c.layer;
    assert_eq!(d, side.dims.d, "the two exports disagree on d");
    // the FFN half runs on THIS layer's xm8 (not the export's X plane)
    let mut ex = load_layer_v3(&v3dir, &side, l, false, true);
    let same = (0..t * d).filter(|&i| ex.x[i] as i64 == wit.nm.y[i]).count();
    for i in 0..t * d { ex.x[i] = wit.nm.y[i] as i8; }
    // the FFN's own X exponent vs the attention half's xm8 exponent: the
    // gate/up shifts absorb the difference so the frozen table member (keyed
    // by the gate exponent) is unchanged.
    let dx = wit.c.e_xm - ex.exps.e_x;
    if dx != 0 {
        println!("  the attention half's xm8 sits {dx} bit(s) from the FFN export's X exponent: g/u shifts adjusted, the frozen table member unchanged");
        ex.shifts.0 -= dx;
        ex.shifts.1 -= dx;
        ex.exps.e_x += dx;
    }
    let (w3, bumps, e_z16) = derive_ffn_on(&ex, t);
    let z16: Vec<i64> = w3.z16[..t * d].iter().map(|&v| v as i64).collect();
    let r2 = at::residual2(&wit, z16, wit.c.e_r1, e_z16, wit.c.r1_cls);
    if bumps.iter().any(|&b| b != 0) {
        println!("  the FFN half's shifts fitted to this X plane: g/u/h/z bumped by {bumps:?} (public constants; the frozen table member re-selected for the new gate exponent)");
    }
    println!("attn-full {dir} + {}: layer {l}, T {t} d {d} f {} H {}/{} d_h {} ({:.2} s, {} threads)",
             v3dir.display(), side.dims.f, sh.heads, sh.kv_heads, sh.head_dim,
             t0.elapsed().as_secs_f64(), rayon::current_num_threads());
    println!("  {}", at::consts_line(&wit.c));
    println!("  the attention half's xm8 vs the FFN export's own X plane: {}/{} equal ({:.4}) — the FFN half is proven on xm8 either way",
             same, t * d, same as f64 / (t * d) as f64);
    println!("  residual2: xres1 << {} + z16 << {} >> {} -> e_r2 {} ({:?})",
             r2.c.sh_x2, r2.c.sh_z2, r2.c.sh_r2, r2.c.e_r2, r2.c.r2_cls);
    let st3 = stmt_v3(&w3, t);
    let lay3 = LayoutV3::new(t, d, side.dims.f);

    let run = |tamper_a: at::AttnTamper, tamper_f: TamperV3, z_break: bool|
        -> (Result<(), String>, f64, f64, usize, usize) {
        let mut w = at::clone_attn_witness(&wit);
        let mut r22 = at::clone_resid2(&r2);
        at::apply_attn_tamper(&mut w, &mut r22, tamper_a);
        if z_break { at::break_seam(&mut r22, &w, 7); }
        let mut w32 = clone_witness_v3(&w3);
        apply_tamper_v3(&mut w32, tamper_f);
        // ---- prove ----
        let t1 = Instant::now();
        let mut tr = Transcript::new(b"hashline-full-layer");
        let (mut pa, pend, _tm) = at::prove_attn(&w, &r22, &p, &ntt, &mut tr);
        let lay = pend.lay.clone();
        let a_data = pend.a_data.clone();
        let before = Transcript::clone_state(&tr);
        let out3 = prove_layer_v3(&w32, t, &p, &ntt, &mut tr);
        let rho_d = v3_zcd_point(&st3, &out3.proof, &before);
        let pts = seam_points(&rho_d, lay.log_t, lay.log_dp, lay3.log_db, lay3.nb_d);
        let wx: Vec<Fp2> = (0..lay3.nb_d).map(|c| out3.proof.zcd_term[c]).collect();
        let wz: Vec<Fp2> = (0..lay3.nb_d).map(|c| out3.proof.zcd_term[lay3.nb_d + c]).collect();
        let mut pend = pend;
        at::attn_seam(&mut pend.cc, &mut tr, &lay, Some(&a_data), &pts, &wx, &wz).ok();
        at::attn_open(pend, &mut pa, &mut tr);
        let tp = t1.elapsed().as_secs_f64();
        let bytes = pa.size_bytes() + out3.proof.size_bytes();
        let abytes = pa.size_bytes();
        // ---- verify ----
        let t2 = Instant::now();
        let mut tv = Transcript::new(b"hashline-full-layer");
        let r = (|| -> Result<(), String> {
            let (lay2, mut cc) = at::verify_attn(&pa, &w.c, &r22.c, &p, &mut tv)?;
            let before = Transcript::clone_state(&tv);
            verify_layer_v3(&st3, &out3.proof, &p, &ntt, &mut tv).map_err(|e| format!("FFN half: {e}"))?;
            let rho_d = v3_zcd_point(&st3, &out3.proof, &before);
            let pts = seam_points(&rho_d, lay2.log_t, lay2.log_dp, lay3.log_db, lay3.nb_d);
            let wx: Vec<Fp2> = (0..lay3.nb_d).map(|c| out3.proof.zcd_term[c]).collect();
            let wz: Vec<Fp2> = (0..lay3.nb_d).map(|c| out3.proof.zcd_term[lay3.nb_d + c]).collect();
            at::attn_seam(&mut cc, &mut tv, &lay2, None, &pts, &wx, &wz)?;
            at::verify_attn_open(&pa, &lay2, &cc, &p, &ntt, &mut tv)
        })();
        (r, tp, t2.elapsed().as_secs_f64(), bytes, abytes)
    };

    let (r, tp, tv, bytes, ab) = run(at::AttnTamper::None, TamperV3::None, false);
    println!("  FULL LAYER: PROVE {tp:.3} s | VERIFY {tv:.3} s | proof {bytes} B ({:.1} MB; attention half {:.1} MB) | {}",
             bytes as f64 / 1e6, ab as f64 / 1e6, match &r { Ok(()) => "ACCEPT".to_string(), Err(e) => format!("REJECT: {e}") });
    let mut fails = usize::from(r.is_err());
    if o.all_tampers {
        at::set_tamper_mode(true);
        let legs: Vec<(&str, at::AttnTamper, TamperV3, bool)> = vec![
            ("flipped score s8", at::AttnTamper::FlipScore(4242), TamperV3::None, false),
            ("wrong exp-table entry", at::AttnTamper::WrongExp(1000), TamperV3::None, false),
            ("wrong softmax quotient", at::AttnTamper::WrongQuot(555), TamperV3::None, false),
            ("wrong norm output", at::AttnTamper::WrongNorm(321), TamperV3::None, false),
            ("wrong RoPE rotation", at::AttnTamper::WrongRope(999), TamperV3::None, false),
            ("wrong row maximum", at::AttnTamper::WrongMax(17), TamperV3::None, false),
            ("flipped x_in", at::AttnTamper::FlipX(777), TamperV3::None, false),
            ("BROKEN SEAM (z16 copy != the FFN's z16)", at::AttnTamper::None, TamperV3::None, true),
            ("FFN half: wrong int16 table entry", at::AttnTamper::None, TamperV3::WrongTableEntry(1000), false),
            ("FFN half: wrong requant h16", at::AttnTamper::None, TamperV3::WrongRequant(555), false),
        ];
        for (name, ta, tf, zb) in legs {
            let (r, tp, _tv, _b, _a) = run(ta, tf, zb);
            match r {
                Ok(()) => { println!("  tamper [{name}]: ACCEPTED (BUG)"); fails += 1; }
                Err(e) => println!("  tamper [{name}]: REJECT ({}) [{tp:.1} s]", first_line(&e)),
            }
        }
        at::set_tamper_mode(false);
    }
    println!("attn-full: {}", if fails == 0 { "GREEN" } else { "RED" });
    if fails > 0 { std::process::exit(1); }
}

/// [UPERF3-AG] Derive the v3 FFN witness on a REPLACED X plane (the
/// attention half's xm8), FITTING the four requant shifts: the export was
/// calibrated on its own X, and the composed layer's X is a different
/// integer plane, so a shift may have to rise. Every shift is a public
/// statement constant (never a silent clamp), and the gate shift's rise is
/// matched by the FROZEN table member for the new gate exponent, so the
/// activation table stays a registry member.
fn derive_ffn_on(ex: &hashline::export_v3::V3LayerExport, t: usize) -> (V3Witness, [i32; 4], i32) {
    use hashline::export_v3::{matmul_i32_i8_i64, requant_round};
    let (d, f) = (ex.dims.d, ex.dims.f);
    let xi: Vec<i32> = ex.x[..t * d].iter().map(|&v| v as i32).collect();
    let fit = |accmax: i64, lim: i64, sh0: i32| -> i32 {
        let mut sh = sh0;
        loop {
            let (y, _) = requant_round(&[accmax], sh);
            if y[0].abs() <= lim { return sh; }
            sh += 1;
            assert!(sh - sh0 < 24, "runaway FFN shift fit");
        }
    };
    let amax = |v: &[i64]| v.iter().map(|x| x.abs()).max().unwrap_or(0);
    let gacc = matmul_i32_i8_i64(&xi, &ex.wg_t, t, d, f);
    let uacc = matmul_i32_i8_i64(&xi, &ex.wu_t, t, d, f);
    let sh_g = fit(amax(&gacc), 127, ex.shifts.0);
    let sh_u = fit(amax(&uacc), 32767, ex.shifts.1);
    let e_g = ex.exps.e_x + ex.exps.e_wg + sh_g;
    let (table, tdig) = hashline::tables_v3::int16out_member(ex.act, e_g, ex.exps.e_a16)
        .unwrap_or_else(|| panic!("no frozen {} member at (e_gate {e_g}, e_out {})", ex.act.spec_name(), ex.exps.e_a16));
    let (g8, _) = requant_round(&gacc, sh_g);
    let (u16v, _) = requant_round(&uacc, sh_u);
    let hh: Vec<i64> = g8.iter().zip(u16v.iter())
        .map(|(&g, &u)| table[((g + 128).clamp(0, 255)) as usize] as i64 * u).collect();
    let sh_h = fit(amax(&hh), 32767, ex.shifts.2);
    let (h16, _) = requant_round(&hh, sh_h);
    let h32: Vec<i32> = h16.iter().map(|&v| v as i32).collect();
    let dacc = matmul_i32_i8_i64(&h32, &ex.wd_t, t, f, d);
    let sh_z = fit(amax(&dacc), 32767, ex.shifts.3);
    let mut ex2 = clone_export_shifts(ex);
    ex2.shifts = (sh_g, sh_u, sh_h, sh_z);
    let w = derive_v3_with_table(&ex2, t, table, tdig);
    assert!(w.range_ok, "the FFN half still does not fit its classes after the shift fit");
    let e_u16 = ex.exps.e_x + ex.exps.e_wu + sh_u;
    let e_h16 = ex.exps.e_a16 + e_u16 + sh_h;
    let e_z16 = e_h16 + ex.exps.e_wd + sh_z;
    (w, [sh_g - ex.shifts.0, sh_u - ex.shifts.1, sh_h - ex.shifts.2, sh_z - ex.shifts.3], e_z16)
}

fn clone_export_shifts(ex: &hashline::export_v3::V3LayerExport) -> hashline::export_v3::V3LayerExport {
    hashline::export_v3::V3LayerExport {
        l: ex.l, dims: ex.dims, x: ex.x.clone(), wg_t: ex.wg_t.clone(), wu_t: ex.wu_t.clone(),
        wd_t: ex.wd_t.clone(), a16: ex.a16.clone(), u16: ex.u16.clone(), h16: ex.h16.clone(),
        z16: ex.z16.clone(), exps: ex.exps, shifts: ex.shifts, act: ex.act, table: ex.table,
        table_digest: ex.table_digest.clone(), digest_checks: ex.digest_checks.clone(),
    }
}

/// The seam points: the FFN's zero-check-D point, lifted onto the padded
/// d axis one block at a time (the block index is the high bits of i).
fn seam_points(rho_d: &[hashline::field::Fp2], log_t: u32, log_dp: u32, log_db: u32, nb_d: usize)
    -> Vec<Vec<hashline::field::Fp2>> {
    use hashline::field::Fp2;
    let extra = log_dp - log_db;
    (0..nb_d).map(|c| {
        let mut pt: Vec<Fp2> = rho_d[..log_t as usize].to_vec();
        for b in (0..extra).rev() {
            pt.push(if (c >> b) & 1 == 1 { Fp2::ONE } else { Fp2::ZERO });
        }
        pt.extend_from_slice(&rho_d[log_t as usize..]);
        pt
    }).collect()
}
