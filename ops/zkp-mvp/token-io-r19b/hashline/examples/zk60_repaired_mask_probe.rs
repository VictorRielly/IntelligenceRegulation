//! [UPERF3-FSP5] THE PUBLIC-ENDPOINT REPAIRED-MASK COST PROBE.
//!
//! **THIS ESTABLISHES NO PRIVACY PROPERTY.** All three arms below have PUBLIC
//! endpoints: the feed-forward's input and output planes are not hidden by
//! anything here. The hiding-endpoint profile — the half that actually hides
//! them — is `hashline/src/zk_ffn_fresh_io.rs`, it is untouched, and it is
//! still pinned to its tiny T32/d16/f16 shape. What this example measures is
//! what the REPAIRED MASK SCHEDULE (`mr1`: paired mask rows, refusal instead
//! of resampling, a rank check before every opening) COSTS in seconds, proof
//! bytes and committed rows, against the legacy private profile and against
//! the public one, on the same witness and the same shape. It is a cost
//! probe, nothing more.
//!
//! Three arms, one shape, one export, one process per arm:
//!
//! * `public`   — `prove_layer_v3` / `verify_layer_v3` (no privacy at all)
//! * `legacy`   — `prove_layer_zk_v3` / `verify_layer_zk_v3` (`mr1 = false`;
//!                the profile the 2026-09-08 finding showed DISCLOSES private
//!                values — it is the cost baseline, not a privacy claim)
//! * `repaired` — `prove_layer_zk_v3_mr1` / `verify_layer_zk_v3_mr1`
//!
//! Usage:
//!
//! ```text
//! zk60_repaired_mask_probe <layers> <tokens> <public|legacy|repaired|all> \
//!     [--export DIR] [--threads N] [--log-cols N] [--inv-rate N] [--col-checks N]
//! ```
//!
//! The witness is loaded exactly as `hashline pass --profile v3` loads it
//! (`export_dir_v3` / `V3Sidecar::load` / `load_layer_v3` / `derive_v3`, with
//! the same plane comparison), and the defaults are the CLI's:
//! `log_cols 14, inv_rate 4, col-checks 256`.
//!
//! The device is controlled exactly as the CLI controls it — the `HL_GPU`
//! environment variable, read by `hashline::gpu` — and the run header says
//! `gpu: ON` or `gpu: OFF`.
//!
//! Both private arms draw fresh OS randomness (no seed), so the ONLY
//! difference between them is the mask schedule.

use hashline::export_v3::{compare_planes, derive_v3, export_dir_v3, load_layer_v3, V3Sidecar, V3Witness};
use hashline::layer::{prove_layer_v3, verify_layer_v3, LayerParams, StatementV3};
use hashline::ntt::NttTables;
use hashline::transcript::Transcript;
use hashline::zk::{
    prove_layer_zk_v3, prove_layer_zk_v3_mr1, verify_layer_zk_v3, verify_layer_zk_v3_mr1,
    zk_v3_committed_rows, ZkConfig, ZkStatementMode,
};
use std::time::Instant;

fn peak_rss_mb() -> f64 {
    std::fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| {
            s.lines()
                .find(|l| l.starts_with("VmHWM:"))
                .and_then(|l| l.split_whitespace().nth(1).map(|v| v.to_string()))
        })
        .and_then(|kb| kb.parse::<f64>().ok())
        .map(|kb| kb / 1024.0)
        .unwrap_or(0.0)
}

fn stmt_v3(w: &V3Witness, t: usize) -> StatementV3 {
    StatementV3 { l: w.l, t_rows: t, d: w.dims.d, f: w.dims.f, shifts: w.shifts, act: w.act, table: w.table, table_digest: w.table_digest.clone() }
}

/// The CLI's own witness load: the export's planes are re-derived and compared
/// element-wise on the proven rows.
fn load_witness_v3(dir: &std::path::Path, side: &V3Sidecar, l: usize, t_rows: usize) -> V3Witness {
    let ex = load_layer_v3(dir, side, l, true, false);
    let w = derive_v3(&ex, t_rows);
    for (name, mism) in compare_planes(&w, &ex) {
        assert_eq!(mism, 0, "layer {l}: derived {name} != the export's plane on the first {t_rows} rows ({mism} elements)");
    }
    assert!(w.range_ok, "layer {l}: a range fact fails on the honest witness");
    w
}

struct Acc {
    timings: Vec<(String, f64)>,
}
impl Acc {
    fn new() -> Self { Acc { timings: Vec::new() } }
    fn add(&mut self, t: &[(String, f64)]) {
        for (name, s) in t {
            if let Some(e) = self.timings.iter_mut().find(|e| &e.0 == name) { e.1 += s; } else { self.timings.push((name.clone(), *s)); }
        }
    }
}

fn main() {
    let argv: Vec<String> = std::env::args().collect();
    let mut positional: Vec<String> = Vec::new();
    let mut export: Option<String> = None;
    let mut threads = 0usize;
    let mut log_cols = 14u32;
    let mut inv_rate = 4usize;
    let mut col_checks = 256usize;
    let mut i = 1usize;
    while i < argv.len() {
        match argv[i].as_str() {
            "--export" => { i += 1; export = Some(argv[i].clone()); }
            "--threads" => { i += 1; threads = argv[i].parse().expect("--threads"); }
            "--log-cols" => { i += 1; log_cols = argv[i].parse().expect("--log-cols"); }
            "--inv-rate" => { i += 1; inv_rate = argv[i].parse().expect("--inv-rate"); }
            "--col-checks" => { i += 1; col_checks = argv[i].parse().expect("--col-checks"); }
            other => positional.push(other.to_string()),
        }
        i += 1;
    }
    if positional.len() < 3 {
        eprintln!("usage: zk60_repaired_mask_probe <layers> <tokens> <public|legacy|repaired|all> [--export DIR] [--threads N] [--log-cols N] [--inv-rate N] [--col-checks N]");
        std::process::exit(2);
    }
    let n_req: usize = positional[0].parse().expect("layers");
    let t: usize = positional[1].parse().expect("tokens");
    let arms: Vec<&str> = match positional[2].as_str() {
        "all" => vec!["public", "legacy", "repaired"],
        "public" => vec!["public"],
        "legacy" => vec!["legacy"],
        "repaired" => vec!["repaired"],
        other => { eprintln!("unknown arm {other}"); std::process::exit(2); }
    };
    if arms.len() > 1 {
        println!("NOTE: several arms in ONE process. `peak RSS` is the process high-water mark, so every arm after the first inherits the previous arms' peak, and the device counters accumulate. For a fair measurement run ONE arm per invocation.");
    }
    if threads > 0 {
        rayon::ThreadPoolBuilder::new().num_threads(threads).build_global().unwrap();
    }

    let dir = export_dir_v3(export.as_deref());
    let side = V3Sidecar::load(&dir);
    let dm = side.dims;
    let n = n_req.min(dm.layers);
    let p = LayerParams { log_cols, inv_rate, num_col_checks: col_checks };
    let ntt = NttTables::new(log_cols + inv_rate.trailing_zeros());

    println!("=== [UPERF3-FSP5] repaired-mask COST PROBE — NO PRIVACY PROPERTY IS ESTABLISHED HERE ===");
    println!("    all three arms have PUBLIC endpoints; the hiding-endpoint profile is untouched and still pinned to T32/d16/f16.");
    println!("    export {} — model {} (T {} d {} f {} layers {})", dir.display(), side.model, dm.t, dm.d, dm.f, dm.layers);
    println!("    shape {n} layers x {t} tokens | log_cols {log_cols}, inv_rate {inv_rate}, col checks {col_checks} | threads {}", rayon::current_num_threads());
    println!("    gpu: {} | {}", if hashline::gpu::enabled() { "ON" } else { "OFF" }, hashline::gpu::label());
    println!("    both private arms draw fresh OS randomness (no seed), so the only difference between them is the mask schedule.");

    for arm in arms {
        let t_all = Instant::now();
        let mut acc = Acc::new();
        let mut bytes = 0usize;
        let mut rows = (0usize, 0usize, 0usize, 0usize); // A, H, W, M
        let mut t_load = 0.0f64;
        let mut t_prove = 0.0f64;
        let mut t_verify = 0.0f64;
        let mut ok = true;
        let mode = ZkStatementMode::default();
        let cfg = ZkConfig { enabled: true, seed: None, mode: mode.clone() };

        match arm {
            "public" => {
                let mut tr = Transcript::new(b"hashline-pass-v3");
                let mut proofs = Vec::with_capacity(n);
                let mut stmts = Vec::with_capacity(n);
                for l in 0..n {
                    let t0 = Instant::now();
                    let w = load_witness_v3(&dir, &side, l, t);
                    t_load += t0.elapsed().as_secs_f64();
                    let t1 = Instant::now();
                    let out = prove_layer_v3(&w, t, &p, &ntt, &mut tr);
                    t_prove += t1.elapsed().as_secs_f64();
                    acc.add(&out.timings);
                    bytes += out.proof.size_bytes();
                    if l == 0 {
                        rows = (
                            out.proof.a_com.as_ref().unwrap().rows,
                            out.proof.h_com.as_ref().unwrap().rows,
                            out.proof.w_com.as_ref().unwrap().rows,
                            0,
                        );
                    }
                    stmts.push(stmt_v3(&w, t));
                    proofs.push(out.proof);
                }
                let mut tv = Transcript::new(b"hashline-pass-v3");
                let t0 = Instant::now();
                for (st, pr) in stmts.iter().zip(proofs.iter()) {
                    if let Err(e) = verify_layer_v3(st, pr, &p, &ntt, &mut tv) { println!("  layer {}: REJECT: {e}", st.l); ok = false; break; }
                }
                t_verify = t0.elapsed().as_secs_f64();
            }
            "legacy" | "repaired" => {
                let repaired = arm == "repaired";
                let mut tr = Transcript::new(b"hashline-pass-zk-v3");
                let mut proofs = Vec::with_capacity(n);
                let mut stmts = Vec::with_capacity(n);
                for l in 0..n {
                    let t0 = Instant::now();
                    let w = load_witness_v3(&dir, &side, l, t);
                    t_load += t0.elapsed().as_secs_f64();
                    let t1 = Instant::now();
                    let out = if repaired {
                        prove_layer_zk_v3_mr1(&w, t, &p, &ntt, &cfg, &mut tr).unwrap_or_else(|e| panic!("layer {l}: the repaired prover REFUSED: {e}"))
                    } else {
                        prove_layer_zk_v3(&w, t, &p, &ntt, &cfg, &mut tr)
                    };
                    t_prove += t1.elapsed().as_secs_f64();
                    acc.add(&out.timings);
                    bytes += out.proof.size_bytes();
                    let st = stmt_v3(&w, t);
                    if l == 0 {
                        let r = zk_v3_committed_rows(&st, &p, false, repaired);
                        rows = (r[0], r[1], r[2], r[3]);
                        assert_eq!(rows.0, out.proof.a_com.as_ref().unwrap().rows, "counted A rows disagree with the commitment");
                        assert_eq!(rows.1, out.proof.h_com.as_ref().unwrap().rows, "counted H rows disagree with the commitment");
                        assert_eq!(rows.2, out.proof.w_com.as_ref().unwrap().rows, "counted W rows disagree with the commitment");
                    }
                    stmts.push(st);
                    proofs.push(out.proof);
                }
                let mut tv = Transcript::new(b"hashline-pass-zk-v3");
                let t0 = Instant::now();
                for (st, pr) in stmts.iter().zip(proofs.iter()) {
                    let r = if repaired {
                        verify_layer_zk_v3_mr1(st, pr, &p, &ntt, &mut tv, &mode)
                    } else {
                        verify_layer_zk_v3(st, pr, &p, &ntt, &mut tv, &mode)
                    };
                    if let Err(e) = r { println!("  layer {}: REJECT: {e}", st.l); ok = false; break; }
                }
                t_verify = t0.elapsed().as_secs_f64();
            }
            _ => unreachable!(),
        }

        let wall = t_all.elapsed().as_secs_f64();
        let rss = peak_rss_mb();
        println!("--- ARM {arm} ---");
        println!("  prover phases (summed over {n} layers):");
        for (name, s) in &acc.timings { println!("      {name:<26} {s:8.3} s"); }
        if hashline::gpu::enabled() {
            let g = hashline::gpu::dev_stats();
            println!(
                "  gpu device-side (summed): h2d {:.3} s ({:.0} MB) | ntt {:.3} s | hash {:.3} s | sumcheck {:.3} s | fold {:.3} s | helpers {:.3} s | d2h {:.3} s ({:.0} MB) | vram peak {:.0} MB",
                g.secs_h2d, g.bytes_h2d as f64 / 1e6, g.secs_ntt, g.secs_hash, g.secs_sumcheck, g.secs_fold, g.secs_helpers, g.secs_d2h, g.bytes_d2h as f64 / 1e6, g.vram_peak as f64 / 1e6
            );
        }
        println!(
            "  ARM {arm} {}: {n} x {t} | witness load {t_load:.2} s | PROVE {t_prove:.3} s | VERIFY {t_verify:.3} s | proof {bytes} B | rows A {} H {} W {} M {} | peak RSS {rss:.0} MB | wall {wall:.2} s",
            if ok { "ACCEPT" } else { "REJECT" }, rows.0, rows.1, rows.2, rows.3
        );
        let phases: Vec<String> = acc.timings.iter().map(|(k, v)| format!("\"{k}\":{v:.6}")).collect();
        println!(
            "PROBE_JSON {{\"arm\":\"{arm}\",\"layers\":{n},\"tokens\":{t},\"d\":{},\"f\":{},\"gpu\":{},\"accept\":{ok},\"prove_s\":{t_prove:.6},\"verify_s\":{t_verify:.6},\"load_s\":{t_load:.6},\"bytes\":{bytes},\"rows_a\":{},\"rows_h\":{},\"rows_w\":{},\"rows_m\":{},\"rss_mb\":{rss:.1},\"phases\":{{{}}}}}",
            dm.d, dm.f, hashline::gpu::enabled(), rows.0, rows.1, rows.2, rows.3, phases.join(",")
        );
        if !ok { std::process::exit(1); }
    }
}
