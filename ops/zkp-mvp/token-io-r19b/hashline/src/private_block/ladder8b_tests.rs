//! **NATIVE LANE, speed plan task 3 (2026-10-17 evening): the Llama-3-8B
//! phase ladder at T = 64 and T = 128.** TEST CODE ONLY. Public synthetic
//! data only; NOT the trained model.
//!
//! * the counted layouts of the 8B geometry at T64 and T128 at every
//!   admissible row width, the registered one the smallest receipt, and the
//!   counts equal to the speed plan's replica (`results/zk60_speed_plan_20261017/layout.py`);
//! * the no-wrap premises the T-dependent clauses rest on, re-derived at the
//!   8B T64 / T128 shapes (the softmax quotient clause and the window rule);
//! * (heavy, release, guarded) ONE generic dense block at the true 8B
//!   geometry and the T named by `ZK60_NATIVE_LADDER_T` (64 or 128) proves as
//!   a bound one-block run, verifies, and (unless `ZK60_NATIVE_LADDER_NO_CONTROLS`
//!   is set, for the GPU arm) every coefficient / shift / receipt /
//!   inconsistent-witness control refuses; with `ZK60_NATIVE_LADDER_DIR` set
//!   the segment is saved and a FRESH process verifies it.

use super::layout::*;
use super::shape::{NormCalibration, Shape};
use super::trained_calib_tests::{coefficient_and_receipt_controls, generic_witness_with, inconsistent_witness_controls, llama3_8b_calibration, prove_one_bound, verify_one_bound, Bands, TRAINED_BANDS};
use super::*;

/// the speed plan's replica (`layout.py`): (T, row width, A rows, H rows,
/// counted receipt bytes) at the receipt-minimising width
const REPLICA: [(usize, usize, usize, usize, usize); 2] = [(64, 13, 3229, 3534, 21_697_512), (128, 14, 3405, 3790, 29_300_856)];

#[test]
fn the_llama3_8b_t64_and_t128_counted_layouts() {
    let c = llama3_8b_calibration();
    for (t, lc_reg, a_rows, h_rows, receipt) in REPLICA {
        let mut best: Option<(usize, usize)> = None;
        for lc in 11..=17 {
            match Shape::llama3_8b_at(t, lc, &c, 9) {
                Ok(sh) => match Layout::for_shape(&sh) {
                    Ok(lay) => {
                        let tt = sh.totals();
                        assert_eq!((lay.a_rows, lay.h_rows), (tt.a_rows, tt.h_rows));
                        let n = tt.receipt_bytes.total;
                        eprintln!("8B T{t} log_cols {lc}: A {} rows, H {} rows, endpoint rows {}, receipt {n} B, u8 lookups {}, wrho_s {} ({} limbs)", tt.a_rows, tt.h_rows, sh.endpoint_rows, tt.u8_lookups, sh.wrho_s, sh.limbs_sigma_s());
                        assert!(n <= super::wire::wire_ceiling(&sh));
                        if best.map(|(_, b)| n < b).unwrap_or(true) {
                            best = Some((lc, n));
                        }
                    }
                    Err(e) => eprintln!("8B T{t} log_cols {lc}: layout refused: {e}"),
                },
                Err(e) => eprintln!("8B T{t} log_cols {lc}: shape refused: {}", e.chars().take(140).collect::<String>()),
            }
        }
        assert_eq!(best.unwrap(), (lc_reg, receipt), "T{t}: the registered width is the smallest counted receipt");
        let sh = Shape::llama3_8b_trained(t, &c, 9).unwrap();
        let tt = sh.totals();
        assert_eq!((sh.log_cols, tt.a_rows, tt.h_rows, tt.receipt_bytes.total), (lc_reg, a_rows, h_rows, receipt), "T{t}: the registered shape is the replica's");
        assert_eq!((sh.tokens, sh.f_pad, sh.h_pad, sh.d_pad, sh.slots_per_kv_group()), (t, 16384, 32, 4096, 4));
        assert_eq!(sh.endpoint_rows, ((t * 4096) >> lc_reg) + super::endpoint_g::MASK_ROWS);
    }
}

/// **The T-dependent no-wrap clauses at the 8B T64 / T128 shapes**, the
/// formulas of `nowrap_check.py` (its softmax section and its PV host
/// relation) re-done from the Rust shapes' own fields, at every `f_e` of the
/// class. Adversarial facts: `e` in `[0, 2^f_e]`, `Sum` in `[0, T 2^f_e]`,
/// `p` in `[0, 2^(F_P+1))`, `sigma`/`rho` in `[0, 2^wrho_s)`, `v8` int8:
///
/// * c2 = `2^f_e 2^F_P + (2^(F_P+1) - 1) Sum_max + 2^wrho_s` (the quotient),
/// * c3 = `2 2^wrho_s + 1 + Sum_max` (the complement),
/// * pv = `T (2^(F_P+1) - 1) 127` (the PV accumulator) and the PV host
///   relation at the top of its two-limb window (`sh_o <= 16`),
///
/// each below `p / 2`, and `Sum_max <= 2^wrho_s` (the floor quotient fits
/// the window). The norm window does not depend on T (width 4096 derives
/// `tn <= 9` and a 32-bit window at every T).
#[test]
fn the_t_dependent_nowrap_clauses_hold_at_the_8b_t64_and_t128_shapes() {
    const F_P: u32 = 9;
    let half_p: i128 = (zkp_core::field::P / 2) as i128;
    let c = llama3_8b_calibration();
    for t in [64usize, 128] {
        let lt = t.next_power_of_two().trailing_zeros();
        let tt = t as i128;
        for f_e in super::shape::TRAINED_F_E_RANGE {
            let sh = Shape::llama3_8b_trained(t, &c, f_e).unwrap_or_else(|e| panic!("T{t} f_e {f_e}: {e}"));
            assert_eq!(sh.wrho_s, lt + f_e, "T{t} f_e {f_e}: the derived window");
            assert!(sh.wrho_s <= super::shape::TRAINED_WRHO_S_MAX);
            let sum_max = tt << f_e;
            let c2 = (1i128 << (f_e + F_P)) + ((1i128 << (F_P + 1)) - 1) * sum_max + (1i128 << sh.wrho_s);
            let c3 = 2 * (1i128 << sh.wrho_s) + 1 + sum_max;
            let pv = tt * ((1i128 << (F_P + 1)) - 1) * 127;
            let host_pv = (1i128 << 16) * 127 + ((1i128 << 16) - 1) + (1i128 << 15) + tt * ((1i128 << 10) - 1) * 127;
            for (name, v) in [("c2", c2), ("c3", c3), ("pv", pv), ("host PV", host_pv)] {
                assert!(v < half_p, "T{t} f_e {f_e}: {name} = {v} reaches p/2");
            }
            assert!(sum_max <= 1i128 << sh.wrho_s, "T{t} f_e {f_e}: Sum leaves the window");
            assert!(c2 < 1i128 << 36, "T{t} f_e {f_e}: c2 = {c2}");
            // the norm window at width 4096 is T-independent
            assert_eq!((sh.norm_wrho, sh.d_max), (32, 2_097_152));
        }
        // f_e 17 is outside the class at every T
        assert!(Shape::llama3_8b_trained(t, &c, 17).is_err());
        eprintln!("8B T{t}: c2 / c3 / pv / host-PV below p/2 at every f_e in 9..=16 (worst wrho_s {})", lt + 16);
    }
    // no other T is registered for the 8B geometry
    for t in [16usize, 48, 256, 512] {
        assert!(Shape::llama3_8b_trained(t, &c, 9).unwrap_err().contains("no trained Llama-3-8B profile"), "T{t}");
    }
}

// ------------------------------------------------------------- heavy

/// the R4-2 generic block's calibration (Cn_a 6380 / Cn_m 6672 inside the
/// class, so a SYNTHETIC block's norm outputs use the int8 class)
fn generic_8b_calibration() -> NormCalibration {
    NormCalibration { cn_a: 6380, cn_m: 6672, ..llama3_8b_calibration() }
}

fn tokens() -> usize {
    let t: usize = std::env::var("ZK60_NATIVE_LADDER_T").ok().and_then(|v| v.parse().ok()).expect("ZK60_NATIVE_LADDER_T is 64 or 128");
    assert!(t == 64 || t == 128, "ZK60_NATIVE_LADDER_T is 64 or 128, not {t}");
    t
}

fn generic_8b_at(t: usize) -> Shape {
    Shape::llama3_8b_trained(t, &generic_8b_calibration(), 9).expect("the generic 8B shape at T")
}

fn evidence_dir() -> Option<std::path::PathBuf> {
    std::env::var_os("ZK60_NATIVE_LADDER_DIR").map(std::path::PathBuf::from)
}

/// the R4-2 bands at the 8B geometry, the FIRST admissible
fn bands_8b(sh: &Shape) -> Bands {
    let cands = [TRAINED_BANDS, Bands { attn: 6, gate: 8, ..TRAINED_BANDS }, Bands { attn: 4, gate: 8, down: 1, ..TRAINED_BANDS }, Bands { attn: 4, gate: 6, down: 1, xmag: 4_000, ..TRAINED_BANDS }];
    for b in cands {
        let (blk, input) = super::trained_calib_tests::trained_dense_block_with(sh, b);
        match witness::build_shaped(sh, blk.attention(), blk.feed_forward(), &input) {
            Ok(_) => {
                eprintln!("LADDER8B bands at {}: {b:?} admissible", sh.profile);
                return b;
            }
            Err(e) => eprintln!("LADDER8B bands {b:?}: refused ({e})"),
        }
    }
    panic!("no candidate band is admissible at the 8B geometry");
}

/// **Speed plan task 3: ONE GENERIC BLOCK AT THE TRUE Llama-3-8B GEOMETRY
/// AT T64 OR T128** (dense synthetic weights, every query head and all 8
/// key-value groups live and different, the upper hidden half live, the
/// witness equal to the independent shape-driven kernel), proved as a bound
/// one-block run (timed alone), verified from bytes (timed alone), then the
/// controls. One machine-readable `LADDER8B {json}` line carries the numbers.
#[test]
#[ignore = "native lane heavy: one width-4096 Llama-3-8B-geometry block proof at T64/T128 (release, guarded)"]
fn native_ladder8b_generic_block_proves_verifies_and_every_control_refuses() {
    let t = tokens();
    let sh = generic_8b_at(t);
    if crate::gpu::required() {
        crate::gpu::require_live().expect("HL_GPU_REQUIRED=1 but the GPU path is not live");
    }
    let b = bands_8b(&sh);
    let (w, input) = super::trained_calib_tests::trained_dense_words(&sh, b);
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    // the witness, timed alone (the generic checks and the kernel parity
    // follow in `generic_witness_with`, which rebuilds it)
    let t0 = std::time::Instant::now();
    let w_only = witness::build_shaped(&sh, &public, &ff, &input).expect("the generic witness");
    let witness_s = t0.elapsed().as_secs_f64();
    drop(w_only);
    let (blk, input2, wit) = generic_witness_with(&sh, b);
    assert_eq!(input, input2);
    let hwm_w = super::run::peak_rss_mib();
    let t1 = std::time::Instant::now();
    let one = prove_one_bound(&sh, &blk, wit).expect("the honest block proves as a bound one-block run");
    let prove_s = t1.elapsed().as_secs_f64();
    let hwm_p = super::run::peak_rss_mib();
    let eb = one.expected.to_bytes();
    let t2 = std::time::Instant::now();
    verify_one_bound(&sh, &blk, &eb, &one.seg).expect("verifies from bytes");
    let verify_s = t2.elapsed().as_secs_f64();
    let digest = super::trained_block::hex(&blk.digest());
    if let Some(dir) = evidence_dir() {
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("ladder8b-segment.bin"), &one.seg).unwrap();
        std::fs::write(dir.join("ladder8b-expected.bin"), &eb).unwrap();
        std::fs::write(dir.join("ladder8b-block-digest.hex"), &digest).unwrap();
        std::fs::write(dir.join("ladder8b-bands.txt"), format!("{} {} {} {} {} {}\n", b.attn, b.gate, b.down, b.gains.0, b.gains.1, b.xmag)).unwrap();
    }
    let tt = sh.totals();
    println!(
        "LADDER8B {{\"T\":{t},\"log_cols\":{},\"gpu\":{:?},\"gpu_declines\":{},\"witness_seconds\":{witness_s:.3},\"prove_seconds\":{prove_s:.3},\"verify_seconds\":{verify_s:.3},\"segment_bytes\":{},\"counted_receipt_bytes\":{},\"a_rows\":{},\"h_rows\":{},\"peak_rss_after_witness_mib\":{hwm_w:.0},\"peak_rss_after_prove_mib\":{hwm_p:.0},\"rayon_threads\":{},\"block_digest\":{:?}}}",
        sh.log_cols,
        crate::gpu::label(),
        crate::gpu::declines(),
        one.seg.len(),
        tt.receipt_bytes.total,
        tt.a_rows,
        tt.h_rows,
        rayon::current_num_threads(),
        digest
    );
    if std::env::var_os("ZK60_NATIVE_LADDER_NO_CONTROLS").is_none() {
        let mk = move |c: &NormCalibration| Shape::llama3_8b_trained(t, c, 9);
        coefficient_and_receipt_controls(&sh, &mk, &blk, &one.expected, &one.seg);
        inconsistent_witness_controls(&sh, &mk, &blk, &input);
        println!("LADDER8B controls: every coefficient / shift / receipt / inconsistent-witness control refused at T{t}");
    }
    if crate::gpu::required() {
        assert_eq!(crate::gpu::declines(), 0, "a GPU decline under HL_GPU_REQUIRED=1");
    }
}

/// **The FRESH-PROCESS verifier**: rebuilds the shape and the public
/// statement from the public recipe alone (the saved bands), checks the
/// block digest, verifies the saved segment, and the wrong-constant
/// verifiers refuse it.
#[test]
#[ignore = "native lane heavy: verifies a saved width-4096 T64/T128 segment in a fresh process"]
fn native_ladder8b_verify_the_saved_segment_in_a_fresh_process() {
    let t = tokens();
    let dir = evidence_dir().expect("ZK60_NATIVE_LADDER_DIR is set");
    let sh = generic_8b_at(t);
    let v: Vec<i64> = std::fs::read_to_string(dir.join("ladder8b-bands.txt")).unwrap().split_whitespace().map(|x| x.parse().unwrap()).collect();
    let b = Bands { attn: v[0], gate: v[1], down: v[2], gains: (v[3], v[4]), xmag: v[5] };
    let (w, _) = super::dense_tests::dense_public_words_with(&sh, b.attn, b.gate, b.down, b.gains);
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let blk = BlockPublic::new(public, ff);
    let want = std::fs::read_to_string(dir.join("ladder8b-block-digest.hex")).unwrap();
    assert_eq!(super::trained_block::hex(&blk.digest()), want.trim(), "the rebuilt public statement is not the prover's");
    let eb = std::fs::read(dir.join("ladder8b-expected.bin")).unwrap();
    let expected = ExpectedIo::from_bytes_at(&sh, &eb).expect("the expected policy");
    let bytes = std::fs::read(dir.join("ladder8b-segment.bin")).unwrap();
    let t1 = std::time::Instant::now();
    verify_one_bound(&sh, &blk, &eb, &bytes).expect("the saved 8B segment verifies in a fresh process");
    println!("LADDER8B fresh-process verify at T{t}: {:.3} s, {} B, peak RSS {:.0} MiB", t1.elapsed().as_secs_f64(), bytes.len(), super::run::peak_rss_mib());
    let mk = move |c: &NormCalibration| Shape::llama3_8b_trained(t, c, 9);
    coefficient_and_receipt_controls(&sh, &mk, &blk, &expected, &bytes);
    println!("LADDER8B fresh-process controls: every coefficient / shift / receipt control refused at T{t}");
}
