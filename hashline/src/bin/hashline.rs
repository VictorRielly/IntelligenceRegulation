//! hashline CLI.
//!   hashline check-export                       rung 0: the export's sidecar digests reproduce (all layers)
//!   hashline chain [layers]                     rung 1: the exact integer chain reproduces every z digest
//!   hashline matmul <layers> <t_rows>           rung 2: the g/u matmul sumcheck differential + tamper legs
//!   hashline layer <l> <t_rows> [opts]          rungs 3-4: prove + verify one layer (+ tamper legs)
//!   hashline pass <layers> <t_rows> [opts]      rung 5: the multi-layer pass, one transcript, measured
//! opts: --threads N  --log-cols N (default 14)  --col-checks Q (default 256)  --inv-rate R (default 4)
//!       --tamper none|flipx|flipw|rem|table|requant|z  --tamper-idx I  --no-verify  --all-tampers

use hashline::chain::{derive, LayerWitness};
use hashline::export::{export_dir, load_layer, Sidecar, D, F, LAYERS};
use hashline::layer::{apply_tamper, matmul_differential, prove_layer, verify_layer, LayerParams, Statement, Tamper};
use hashline::ntt::NttTables;
use hashline::transcript::Transcript;
use std::time::Instant;

struct Opts {
    threads: usize,
    log_cols: u32,
    col_checks: usize,
    inv_rate: usize,
    tamper: Tamper,
    verify: bool,
    all_tampers: bool,
}

fn parse_opts(args: &[String]) -> Opts {
    let mut o = Opts { threads: 0, log_cols: 14, col_checks: 256, inv_rate: 4, tamper: Tamper::None, verify: true, all_tampers: false };
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
            other => { eprintln!("unknown option {other}"); std::process::exit(2); }
        }
        i += 1;
    }
    o.tamper = tamper_from(&tkind, tidx);
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
        "check-export" => check_export(),
        "chain" => {
            let n: usize = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(LAYERS);
            chain(n)
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
            layer(l, t, &o)
        }
        "pass" => {
            let n: usize = args[2].parse().unwrap();
            let t: usize = args[3].parse().unwrap();
            let o = parse_opts(&args[4..]);
            pass(n, t, &o)
        }
        _ => {
            eprintln!("usage: hashline check-export | chain [layers] | matmul <layers> <t> | layer <l> <t> | pass <layers> <t>  [opts]");
            std::process::exit(2);
        }
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
