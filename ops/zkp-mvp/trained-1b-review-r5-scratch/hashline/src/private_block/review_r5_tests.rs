//! **REVIEWER SCRATCH, D24 review ROUND 5 (2026-10-18), of the native R5b
//! tree.** Test code only.
//!
//! * `r5_5` (fast): the Llama-3-8B T64 / T128 profiles — every f_e of the
//!   class builds through the door with the derived softmax window, the
//!   registered row width, 37 endpoint rows, a layout, a constructed shape;
//!   f_e 17 and unregistered T refused; the counted rows / receipt; CS-7 and
//!   CS-9 cross pairs refused by name; D17 (all six 8B / TinyLlama trained
//!   profile strings, block and run, pairwise distinct).

use super::layout::*;
use super::run::{self, RunShape};
use super::shape::{self, Shape};
use super::trained_calib_tests::llama3_8b_calibration;

#[test]
fn r5_5_the_llama3_8b_t64_and_t128_profiles() {
    let c = llama3_8b_calibration();
    // the R5b export's constants (calibration lane, pg_rot1_b6_T128)
    let export = shape::NormCalibration { tn: 9, cn_a: 2092, cn_m: 1424, ceps: 78617, sh_qkv: 8, sh_s: 6, sh_ao: 3, sh_g: 8, sh_h: 14, sh_z: 4, ..c };
    for (t, lc, a_rows, h_rows, receipt, bp, rp) in [
        (64usize, 13usize, 3229usize, 3534usize, 21_697_512usize, shape::LLAMA3_8B_T64_TRAINED_PROFILE, run::RUN_PROFILE_LLAMA3_8B_T64_TRAINED),
        (128, 14, 3405, 3790, 29_300_856, shape::LLAMA3_8B_T128_TRAINED_PROFILE, run::RUN_PROFILE_LLAMA3_8B_T128_TRAINED),
    ] {
        for cal in [c, export] {
            for f_e in shape::TRAINED_F_E_RANGE {
                let sh = Shape::llama3_8b_trained(t, &cal, f_e).unwrap_or_else(|e| panic!("T{t} f_e {f_e}: {e}"));
                assert_eq!((sh.profile, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.head_dim, sh.kv_heads), (bp, t, 4096, 14336, 32, 128, 8));
                assert_eq!((sh.log_cols, sh.endpoint_rows, sh.t_pad, sh.d_pad, sh.f_pad, sh.h_pad), (lc, 37, t, 4096, 16384, 32));
                assert_eq!(sh.wrho_s, t.trailing_zeros() + f_e, "T{t} f_e {f_e}: the softmax window");
                assert_eq!(sh.limbs_sigma_s(), sh.wrho_s.div_ceil(8) as usize);
                assert!(sh.trained_calibration && sh.norm_wrho == 32 && sh.norm_tn == 9);
                sh.check_constructed().unwrap_or_else(|e| panic!("T{t} f_e {f_e}: {e}"));
                let lay = Layout::for_shape(&sh).unwrap_or_else(|e| panic!("T{t} f_e {f_e}: {e}"));
                let tt = sh.totals();
                assert_eq!((lay.a_rows, lay.h_rows), (tt.a_rows, tt.h_rows));
                if f_e == 9 {
                    assert_eq!((tt.a_rows, tt.h_rows, tt.receipt_bytes.total), (a_rows, h_rows, receipt), "T{t}: the counted layout");
                }
                assert!(tt.receipt_bytes.total <= super::wire::wire_ceiling(&sh));
                // its run profile is registered for it, and only for it
                RunShape::new(sh.clone(), 2, rp).unwrap_or_else(|e| panic!("T{t}: {e}"));
                for other in [run::RUN_PROFILE_LLAMA3_8B_T32_TRAINED, run::RUN_PROFILE_LLAMA3_8B_T64_TRAINED, run::RUN_PROFILE_LLAMA3_8B_T128_TRAINED, run::RUN_PROFILE_TINYLLAMA_T64_TRAINED, run::RUN_PROFILE_TINYLLAMA_T128_TRAINED, run::RUN_PROFILE_RUNG_TC] {
                    if other != rp {
                        let e = RunShape::new(sh.clone(), 2, other).err().unwrap_or_else(|| panic!("T{t}: {other} accepted the 8B T{t} shape"));
                        assert!(e.contains("ruling CS-7"), "{e}");
                    }
                }
            }
            assert!(Shape::llama3_8b_trained(t, &cal, 17).is_err() && Shape::llama3_8b_trained(t, &cal, 8).is_err());
        }
        // the block profile string at the other T's geometry: CS-9 (as a release build)
        let other_t = if t == 64 { 128 } else { 64 };
        let mut w = Shape::llama3_8b_trained(other_t, &c, 9).unwrap();
        w.profile = bp;
        assert!(w.check_block_profile_as_a_release_build().unwrap_err().contains("ruling CS-9"));
        assert!(w.check_constructed().is_err(), "CS-8 at the entries");
        assert!(Layout::for_shape(&w).is_err() || w.check_constructed().is_err());
        // a TinyLlama geometry under the 8B string: refused
        let mut tl = super::trained_calib_tests::tinyllama_at(t);
        tl.profile = bp;
        assert!(tl.check_constructed().is_err(), "a TinyLlama geometry under the 8B T{t} string passed CS-8");
        eprintln!("REVIEW-R5-5 8B T{t}: every f_e 9..=16 at two calibrations builds (wrho_s = log2 T + f_e, log_cols {lc}, 37 endpoint rows, layout, CS-8), counted A {a_rows} / H {h_rows} / {receipt} B at f_e 9; f_e 8/17 refused; every other trained run profile refuses it (CS-7); its string at T{other_t}'s geometry refused (CS-9)");
    }
    for t in [16usize, 32 + 1, 96, 256] {
        assert!(Shape::llama3_8b_trained(t, &c, 9).is_err(), "T{t}");
    }
    // D17: one profile per shape, every string distinct
    let blocks = [shape::TINYLLAMA_T32_TRAINED_PROFILE, shape::TINYLLAMA_T64_TRAINED_PROFILE, shape::TINYLLAMA_T128_TRAINED_PROFILE, shape::LLAMA3_8B_T32_TRAINED_PROFILE, shape::LLAMA3_8B_T64_TRAINED_PROFILE, shape::LLAMA3_8B_T128_TRAINED_PROFILE, shape::TRAINED_CALIB_RUNG_PROFILE];
    let runs = [run::RUN_PROFILE_TINYLLAMA_T32_TRAINED, run::RUN_PROFILE_TINYLLAMA_T64_TRAINED, run::RUN_PROFILE_TINYLLAMA_T128_TRAINED, run::RUN_PROFILE_LLAMA3_8B_T32_TRAINED, run::RUN_PROFILE_LLAMA3_8B_T64_TRAINED, run::RUN_PROFILE_LLAMA3_8B_T128_TRAINED, run::RUN_PROFILE_RUNG_TC];
    let all: Vec<&str> = blocks.iter().chain(runs.iter()).copied().collect();
    for i in 0..all.len() {
        for j in i + 1..all.len() {
            assert_ne!(all[i], all[j]);
        }
    }
    for p in [shape::LLAMA3_8B_T64_TRAINED_PROFILE, shape::LLAMA3_8B_T128_TRAINED_PROFILE] {
        assert!(shape::TRAINED_CALIBRATION_PROFILES.contains(&p));
        assert_eq!(shape::trained_rope_theta(p), Some(shape::LLAMA3_8B_ROPE_THETA));
        assert!(super::trained_statement::ModelSource::pinned_for_profile(p).is_some());
    }
    eprintln!("REVIEW-R5-5 D17: 14 trained block / run profile strings pairwise distinct; T64 / T128 in the door's list, RoPE 500000, pinned checkpoint");
}
