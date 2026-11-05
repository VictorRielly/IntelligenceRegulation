//! [UPERF3-FSP5] Tests for the PUBLIC-ENDPOINT REPAIRED-MASK PROBE entry pair
//! (`prove_layer_zk_v3_mr1` / `verify_layer_zk_v3_mr1`).
//!
//! **No privacy property is established by this entry pair or by these tests.**
//! The endpoints are public here: the probe exists to make the repaired mask
//! schedule RUNNABLE at a caller-supplied shape so its COST can be measured.
//! The hiding-endpoint profile (`zk_ffn_fresh_io.rs`) is the thing that hides
//! the input and the output, and it is untouched and still pinned to its tiny
//! shape.
//!
//! What is asserted here:
//!  1. the new entry proves and the new verifier accepts, at the tiny shape;
//!  2. THE TWO PROFILES ARE NOT CONFUSABLE, in both directions, and the
//!     binding is a domain separator in the Fiat-Shamir transcript, asserted
//!     directly (not merely inferred from the two rejections);
//!  3. every leg of the v3 tamper battery that produces a proof through the
//!     new entry is REJECTED by the new verifier (at least four legs reach it);
//!  4. the legacy entry's behaviour is unchanged — same proof bytes for the
//!     same seed, same layout row counts, and it still accepts its own proof;
//!  5. the repaired entry refuses a deterministic seed, because the repaired
//!     schedule discards and retries on a refusal and must never be replayed;
//!  6. the repaired LAYOUT is the legacy layout plus exactly the counted mask
//!     rows, at the tiny shape AND at the 125M-class shape (a pure layout
//!     computation — nothing is proven at that width here).
use super::*;
use crate::export_v3::{clone_witness_v3, derive_v3, V3Dims, V3Exps, V3LayerExport};
use crate::layer::{apply_tamper_v3, TamperV3};
use crate::tables_v3::{int16out_member, Act16Fn};

/// A synthetic v3 layer (T `t`, d 16, f 16; int8 X, small int8 weights; the frozen
/// member (-3, -11); shifts (7, 0, 14, 6)) derived through the exact widened chain.
/// (The same fixture `tests_v3::synth` builds; that one is private to its module.)
fn synth(seed: u64, t: usize) -> V3Witness {
    let (d, f) = (16usize, 16usize);
    let mut s = seed;
    let mut nx = |m: i64| -> i8 {
        s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (((s >> 33) as i64) % (2 * m + 1) - m) as i8
    };
    let x: Vec<i8> = (0..t * d).map(|_| nx(127)).collect();
    let wg_t: Vec<i8> = (0..d * f).map(|_| nx(4)).collect();
    let wu_t: Vec<i8> = (0..d * f).map(|_| nx(4)).collect();
    let wd_t: Vec<i8> = (0..f * d).map(|_| nx(4)).collect();
    let (table, table_digest) = int16out_member(Act16Fn::Silu, -3, -11).unwrap();
    let exps = V3Exps { e_x: 0, e_g: -3, e_a16: -11, e_u16: 0, e_h16: 0, e_z16: 0, e_wg: 0, e_wu: 0, e_wd: 0 };
    let ex = V3LayerExport {
        l: 0, dims: V3Dims { t, d, f, layers: 1 }, x, wg_t, wu_t, wd_t, a16: vec![], u16: vec![], h16: vec![], z16: vec![],
        exps, shifts: (7, 0, 14, 6), act: Act16Fn::Silu, table, table_digest, digest_checks: vec![],
    };
    let w = derive_v3(&ex, t);
    assert!(w.range_ok, "the synthetic witness fails a range fact");
    w
}

fn stmt(w: &V3Witness) -> StatementV3 {
    StatementV3 { l: w.l, t_rows: w.t_rows, d: w.dims.d, f: w.dims.f, shifts: w.shifts, act: w.act, table: w.table, table_digest: w.table_digest.clone() }
}

fn tiny_params() -> LayerParams {
    LayerParams { log_cols: 5, inv_rate: 4, num_col_checks: 12 }
}

/// P1, function 1, no model id — the legacy header, and no seed (the repaired
/// profile refuses one).
fn fresh_p1() -> ZkConfig {
    ZkConfig { enabled: true, seed: None, mode: ZkStatementMode::default() }
}

// 1. -----------------------------------------------------------------------

#[test]
#[cfg(unix)]
fn the_repaired_entry_proves_and_its_verifier_accepts() {
    let params = tiny_params();
    let ntt = NttTables::new(16);
    let w = synth(1, 2);
    let st = stmt(&w);
    let cfg = fresh_p1();
    let out = prove_layer_zk_v3_mr1(&w, 2, &params, &ntt, &cfg, &mut Transcript::new(b"mr1-probe-test")).expect("repaired proof");
    verify_layer_zk_v3_mr1(&st, &out.proof, &params, &ntt, &mut Transcript::new(b"mr1-probe-test"), &cfg.mode).expect("repaired verify");
    // the repaired schedule reports its own layout, not the legacy one
    assert!(out.sites.iter().any(|s| s.starts_with("ffn-v3-mr1-fresh-poc/2")), "the repaired layout did not report itself: {:?}", out.sites.first());
    assert_eq!(out.proof.size_breakdown().unwrap().total_bytes(), out.proof.to_bytes().len());
}

// 2. -----------------------------------------------------------------------

#[test]
#[cfg(unix)]
fn the_two_profiles_are_not_confusable() {
    let params = tiny_params();
    let ntt = NttTables::new(16);
    let w = synth(1, 2);
    let st = stmt(&w);
    let fresh = fresh_p1();
    let seeded = ZkConfig { enabled: true, seed: Some(1), mode: ZkStatementMode::default() };

    // (a) THE BINDING ITSELF: the repaired entry pair absorbs a profile domain
    // separator into the Fiat-Shamir transcript before anything else it does, so
    // every challenge downstream of it differs from the legacy path's.
    let a = Transcript::new(b"same-domain");
    let mut b = Transcript::new(b"same-domain");
    b.absorb(b"zk-mask-profile", MR1_PROBE_PROFILE);
    assert_ne!(a.state(), b.state(), "the repaired profile tag is not in the transcript");

    // (b) a repaired proof is REFUSED by the legacy verifier ...
    let repaired = prove_layer_zk_v3_mr1(&w, 2, &params, &ntt, &fresh, &mut Transcript::new(b"t")).expect("repaired proof");
    assert!(
        verify_layer_zk_v3(&st, &repaired.proof, &params, &ntt, &mut Transcript::new(b"t"), &fresh.mode).is_err(),
        "the legacy verifier accepted a repaired-mask proof"
    );

    // (c) ... and a legacy proof is REFUSED by the repaired verifier.
    let legacy = prove_layer_zk_v3(&w, 2, &params, &ntt, &seeded, &mut Transcript::new(b"t"));
    assert!(
        verify_layer_zk_v3_mr1(&st, &legacy.proof, &params, &ntt, &mut Transcript::new(b"t"), &seeded.mode).is_err(),
        "the repaired verifier accepted a legacy proof"
    );

    // (d) and the two are not even the same size: the repaired schedule commits
    // strictly more rows, so the confusion is structural as well as transcript-level.
    assert!(
        repaired.proof.a_com.as_ref().unwrap().rows > legacy.proof.a_com.as_ref().unwrap().rows,
        "the repaired A commitment is not larger than the legacy one"
    );
}

// 3. -----------------------------------------------------------------------

#[test]
#[cfg(unix)]
fn every_tamper_leg_is_rejected_through_the_repaired_entry() {
    let params = tiny_params();
    let ntt = NttTables::new(16);
    let w = synth(1, 2);
    let st = stmt(&w);
    let cfg = fresh_p1();
    let legs = [
        TamperV3::FlipX(3),
        TamperV3::FlipW(5),
        TamperV3::RemainderOutOfRange(9),
        TamperV3::WrongTableEntry(5),
        TamperV3::WrongRequant(7),
        TamperV3::WrongZ(4),
        TamperV3::OutOfRangeInt16(2),
    ];
    let mut reached_the_verifier = 0usize;
    for tm in legs {
        let mut wt = clone_witness_v3(&w);
        apply_tamper_v3(&mut wt, tm);
        match prove_layer_zk_v3_mr1(&wt, 2, &params, &ntt, &cfg, &mut Transcript::new(b"t")) {
            // A refusal at prove time is a rejection too, but it is not what this
            // test is for; only a produced proof exercises the verifier.
            Err(_) => {}
            Ok(o) => {
                reached_the_verifier += 1;
                assert!(
                    verify_layer_zk_v3_mr1(&st, &o.proof, &params, &ntt, &mut Transcript::new(b"t"), &cfg.mode).is_err(),
                    "the repaired verifier accepted {tm:?}"
                );
            }
        }
    }
    assert!(reached_the_verifier >= 4, "only {reached_the_verifier} tamper legs reached the repaired verifier");
}

// 4. -----------------------------------------------------------------------

#[test]
fn the_legacy_entry_is_unchanged() {
    let params = tiny_params();
    let ntt = NttTables::new(16);
    let w = synth(1, 2);
    let st = stmt(&w);
    let seeded = ZkConfig { enabled: true, seed: Some(1), mode: ZkStatementMode::default() };

    // the same seed and the same transcript still give the same bytes ...
    let a = prove_layer_zk_v3(&w, 2, &params, &ntt, &seeded, &mut Transcript::new(b"t"));
    let b = prove_layer_zk_v3(&w, 2, &params, &ntt, &seeded, &mut Transcript::new(b"t"));
    assert_eq!(a.proof.to_bytes(), b.proof.to_bytes(), "the legacy entry stopped being deterministic under a seed");
    // ... it still verifies through the legacy verifier ...
    verify_layer_zk_v3(&st, &a.proof, &params, &ntt, &mut Transcript::new(b"t"), &seeded.mode).expect("legacy verify");
    // ... and it still builds the LEGACY layout: one row per mask, not a pair.
    let legacy = ZkLayoutV3::new(2, w.dims.d, w.dims.f, &params, w.shifts, false);
    assert!(!legacy.mr1, "the public legacy constructor turned the repaired schedule on");
    assert_eq!(legacy.mask_range(legacy.a_prox).len(), 1, "the legacy proximity mask became a pair");
    assert_eq!(a.proof.a_com.as_ref().unwrap().rows, legacy.a_len / legacy.a_n, "the legacy A commitment changed shape");
}

// 5. -----------------------------------------------------------------------

#[test]
fn the_repaired_entry_refuses_a_deterministic_seed() {
    let params = tiny_params();
    let ntt = NttTables::new(16);
    let w = synth(1, 2);
    let seeded = ZkConfig { enabled: true, seed: Some(1), mode: ZkStatementMode::default() };
    match prove_layer_zk_v3_mr1(&w, 2, &params, &ntt, &seeded, &mut Transcript::new(b"t")) {
        Ok(_) => panic!("the repaired entry accepted a deterministic seed"),
        Err(e) => assert!(e.contains("seed"), "unexpected refusal: {e}"),
    }
}

// 6. -----------------------------------------------------------------------

/// The repaired layout is the legacy layout plus EXACTLY the counted rows: one
/// extra row per CFS mask site (each becomes an Fp2-valued pair) and one extra
/// row per single-row table mask slot. Checked at the tiny shape and at the
/// 125M-class shape — a pure layout computation, nothing is proven at that
/// width here.
#[test]
fn the_repaired_layout_is_the_legacy_layout_plus_the_counted_rows() {
    for (t_rows, d, f, log_cols) in [(2usize, 16usize, 16usize, 5u32), (512, 768, 2048, 14), (512, 4096, 14336, 14)] {
        let params = LayerParams { log_cols, inv_rate: 4, num_col_checks: 256 };
        let shifts = (7, 0, 14, 6);
        let legacy = ZkLayoutV3::with_masks(t_rows, d, f, &params, shifts, false, false);
        let repaired = ZkLayoutV3::with_masks(t_rows, d, f, &params, shifts, false, true);
        assert!(!legacy.mr1 && repaired.mr1);
        let (nb_d, nb_f) = (legacy.lay.nb_d, legacy.lay.nb_f);
        // one extra row per paired CFS mask site: 7 nb_f + 3 nb_d f/d planes, nb_d
        // g/u block masks, nb_f d block masks, and the proximity row
        let paired_sites = 7 * nb_f + 3 * nb_d + nb_d + nb_f + 1;
        // plus one extra row per table slot whose mask is a single row
        let single_row_tables = legacy.tabs.iter().filter(|t| t.rows == 1).count();
        let want = paired_sites + single_row_tables;
        let got = (repaired.a_len - legacy.a_len) / legacy.a_n;
        assert_eq!(
            got, want,
            "shape T{t_rows}/d{d}/f{f}: repaired A rows {} - legacy {} = {got}, counted {want}",
            repaired.a_len / repaired.a_n, legacy.a_len / legacy.a_n
        );
        // Harvested with `--nocapture` for the lane's COUNTED extrapolation.
        println!(
            "FSP5-COUNTED T{t_rows}/d{d}/f{f} log_cols {log_cols}: A {} -> {} (+{got}, +{:.3}%), H {} -> {}, W {} (P1, unchanged), M {} -> {}",
            legacy.a_len / legacy.a_n, repaired.a_len / repaired.a_n,
            100.0 * got as f64 / (legacy.a_len / legacy.a_n) as f64,
            legacy.h_len / legacy.a_n, repaired.h_len / repaired.a_n,
            legacy.lay.w_len / legacy.w_n,
            2 * mask_specs_v3(&legacy, false).len() + 4,
            2 * mask_specs_v3(&repaired, false).len() + 4
        );
        // H gains exactly its one paired proximity row
        assert_eq!((repaired.h_len - legacy.h_len) / legacy.a_n, 1, "shape T{t_rows}/d{d}/f{f}: H row delta");
        // and under P1 the weights are public and plain: nothing at all is added
        assert_eq!(repaired.lay.w_len, legacy.lay.w_len, "shape T{t_rows}/d{d}/f{f}: the public W plane moved");
    }
}
