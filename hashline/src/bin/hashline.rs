//! hashline CLI.
//!   hashline check-export            rung 0: the export's sidecar digests reproduce (all layers)
//!   hashline chain [layers]          rung 1: the exact integer chain reproduces every z digest

use hashline::export::{export_dir, load_layer, Sidecar, LAYERS};
use std::time::Instant;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let cmd = args.get(1).map(|s| s.as_str()).unwrap_or("help");
    match cmd {
        "check-export" => check_export(),
        "chain" => {
            let n: usize = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(LAYERS);
            chain(n)
        }
        _ => {
            eprintln!("usage: hashline check-export | chain [layers]");
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
        let w = hashline::chain::derive(&ex);
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
    println!(
        "chain: {}/{} layers reproduce the sidecar z digest ({:.2} s total)",
        n - bad, n, t0.elapsed().as_secs_f64()
    );
    if bad > 0 { std::process::exit(1); }
}
