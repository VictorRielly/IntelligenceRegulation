//! **NATIVE LANE, ROUND 8: EVERY EXPORT-CHOSEN CALIBRATION CONSTANT PER
//! LAYER** (Victor's ruling D32, fidelity). TEST CODE ONLY. Public synthetic
//! data only.
//!
//! * `Shape::with_layer_calibration`: trained shapes only; each of the eleven
//!   constants admitted over its declared class (unchanged from R6) and
//!   refused outside it; the plane list and lookup counts never move, the
//!   schedule moves only in the lines that print the constants;
//! * the trained statement records a layer's own constants canonically (one
//!   label per constant, only where it differs; never equal to the run's)
//!   and binds each; a run-wide statement encodes as before R6 and an
//!   `sh_s`-only one as in R6;
//! * the no-wrap clauses that involve a per-layer constant, over its whole
//!   class, at all six trained profiles (TinyLlama and Llama-3-8B, T 32 / 64
//!   / 128): every relation is block-local, so a class-wide bound holds for
//!   every member a layer may choose;
//! * a two-block bound run whose block 1 has its own constants in all eleven
//!   fields: proves, verifies, and a run-wide verifier refuses.

use super::layout::*;
use super::shape::{NormCalibration, Shape, ONE_LIMB_SHIFT, TRAINED_CEPS_MAX, TRAINED_CN_MAX, TRAINED_SH_AO_MAX, TWO_LIMB_SHIFT};
use super::trained_statement::*;
use super::witness::{self, Witness};
use super::*;

fn rung() -> Shape {
    Shape::rung_tc(&super::trained_calib_tests::rung_tc_calibration()).expect("the trained-calibration rung")
}

/// the calibration with field `i` of [`OWN_FIELDS`] set to `v`
fn with_field(c: &NormCalibration, i: usize, v: i64) -> NormCalibration {
    let mut own = [None; 11];
    own[i] = Some(v);
    apply_own(c, &own).expect("in range")
}

/// one admissible other value per field at the rung (base tn 10 / cn 1336,
/// 2158 / ceps 33,554,467 / ao 6 / qkv 8 / score 5 / o 10 / gate 8 /
/// product 13 / down 5), and values outside each class
fn admissible_and_refused(i: usize) -> (Vec<i64>, Vec<i64>) {
    match OWN_FIELDS[i].0 {
        "sh_s" => (vec![1, 4, 8], vec![0, 9]),
        // tn: the norm window tn + 1 + bits(D_max) must stay four limbs
        // (25..=32 bits; bits(D_max) is 20 at width 384) AND on the base's
        // side of 32: a window of exactly 32 bits needs no scaled top-limb
        // pin, so the H plane list moves (52 -> 50 at the rung) and the
        // door refuses tn 11 here by name
        "norm_tn" => (vec![4, 9], vec![0, 3, 11, 12, 17]),
        "norm_cn_a" | "norm_cn_m" => (vec![1, 700, TRAINED_CN_MAX], vec![0, -5, TRAINED_CN_MAX + 1]),
        // ceps moves bits(D_max): 2^40 makes it 21 bits, the window 32, and
        // the plane list moves (refused by name), as above
        "norm_ceps" => (vec![1, 16_777_259], vec![0, TRAINED_CEPS_MAX, TRAINED_CEPS_MAX + 1]),
        "sh_ao" => (vec![0, 5, i64::from(TRAINED_SH_AO_MAX)], vec![i64::from(TRAINED_SH_AO_MAX) + 1]),
        "sh_qkv" | "sh_g" | "sh_z" => (vec![1, 7], vec![0, 9]),
        "sh_o" | "sh_h" => (vec![9, 11, 16], vec![8, 17]),
        other => panic!("an unlisted field {other}"),
    }
}

#[test]
fn with_layer_calibration_admits_each_class_and_refuses_outside_it() {
    let sh = rung();
    let base = sh.norm_calibration();
    let lay = Layout::for_shape(&sh).unwrap();
    for i in 0..OWN_FIELDS.len() {
        let (ok, bad) = admissible_and_refused(i);
        for v in ok {
            if v == cal_field(&base, i) {
                continue;
            }
            let c = with_field(&base, i, v);
            let s = sh.with_layer_calibration(&c).unwrap_or_else(|e| panic!("{} {v}: {e}", OWN_FIELDS[i].0));
            assert_eq!(s.norm_calibration(), c);
            s.check_constructed().expect("CS-8 rebuild");
            let l = Layout::for_shape(&s).unwrap();
            assert_eq!((lay.a_rows, lay.h_rows), (l.a_rows, l.h_rows), "{} {v} moved the layout's counts", OWN_FIELDS[i].0);
            let (da, db) = (lay.describe(), l.describe());
            let differ: Vec<usize> = (0..da.len()).filter(|j| da[*j] != db[*j]).collect();
            // only the lines that print the constants: the calibration line
            // (norm, qkv, score, o, ao) and the feed-forward line (gate,
            // product, down); never the A / H / M counts, a slot or a host
            assert!(!differ.is_empty() && differ.iter().all(|j| da[*j].starts_with("calibration:") || da[*j].starts_with("feed-forward:")), "{} {v} moved a schedule line other than the constants' lines: {differ:?}", OWN_FIELDS[i].0);
        }
        for v in bad {
            let r = apply_own(&base, &{
                let mut o = [None; 11];
                o[i] = Some(v);
                o
            });
            match r {
                Err(_) => {}
                Ok(c) => {
                    let e = sh.with_layer_calibration(&c).expect_err(&format!("{} {v} was admitted", OWN_FIELDS[i].0));
                    assert!(e.contains("class") || e.contains("window") || e.contains("limb") || e.contains("moves the plane list"), "{} {v}: {e}", OWN_FIELDS[i].0);
                }
            }
        }
    }
    // all eleven at once (the fully per-layer test's layer 1)
    let all = NormCalibration { tn: 9, cn_a: 700, cn_m: 1100, ceps: 16_777_259, sh_ao: 7, sh_qkv: 7, sh_s: 6, sh_o: 11, sh_g: 7, sh_h: 14, sh_z: 6 };
    assert!(own_of(&base, &all).iter().all(|v| v.is_some()), "the all-own calibration does not differ in every field");
    sh.with_layer_calibration(&all).expect("all eleven own constants");
    // a frozen shape takes none
    assert!(Shape::rung_c6().with_layer_calibration(&NormCalibration::FROZEN).unwrap_err().contains("frozen"));
}

fn source(l: usize) -> ModelSource {
    ModelSource {
        kind: SourceKind::PublicSyntheticRecipe,
        repo: "hashline/private-block/r8-per-layer".into(),
        revision: "native-round-8".into(),
        weights_sha256: [0; 32],
        config_sha256: [0; 32],
        checkpoint_parameters: 0,
        checkpoint_layers: l as u32,
    }
}

fn statement(sh: &Shape, blocks: &[BlockPublic], own: &[[Option<i64>; 11]]) -> Result<TrainedModelStatement, String> {
    let mut prov = Provenance::recipe("native/r8", 1.0 / 512.0, [5; 32], [6; 32]);
    prov.rope_theta = super::shape::trained_rope_theta(sh.profile).unwrap_or(prov.rope_theta);
    let cal = IntegerCalibration::as_the_code_proves(sh, &prov);
    let recs = blocks.iter().enumerate().map(|(k, b)| LayerRecord { own: own[k], ..LayerRecord::of_block(k as u32, b, vec![]) }).collect();
    let rp = super::trained_calib_tests::run_shape_for(sh, blocks.len()).profile();
    TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(sh, rp, source(blocks.len()), cal, recs)
}

#[test]
fn the_statement_records_each_own_constant_canonically_and_binds_it() {
    let sh = rung();
    let base = sh.norm_calibration();
    let (blk, _) = super::trained_calib_tests::trained_dense_block(&sh);
    let blocks = vec![blk.clone(), blk];
    let none = statement(&sh, &blocks, &[[None; 11], [None; 11]]).unwrap();
    let enc = String::from_utf8_lossy(&none.encode()).to_string();
    assert!(OWN_FIELDS.iter().all(|(_, label, _)| !enc.contains(label)), "a run-wide statement carries a per-layer label");
    let mut ids = vec![none.identity()];
    for i in 0..OWN_FIELDS.len() {
        let (ok, _) = admissible_and_refused(i);
        let v = ok.into_iter().find(|v| *v != cal_field(&base, i)).unwrap();
        let mut own = [None; 11];
        own[i] = Some(v);
        let st = statement(&sh, &blocks, &[[None; 11], own]).unwrap_or_else(|e| panic!("{} {v}: {e}", OWN_FIELDS[i].0));
        let enc = String::from_utf8_lossy(&st.encode()).to_string();
        for (j, (_, label, _)) in OWN_FIELDS.iter().enumerate() {
            assert_eq!(enc.contains(label), i == j, "field {} put label {label} in the encoding", OWN_FIELDS[i].0);
        }
        assert!(!ids.contains(&st.identity()), "{}'s own value does not move the identity", OWN_FIELDS[i].0);
        ids.push(st.identity());
        // canonical: the run's own value is refused
        let mut same = [None; 11];
        same[i] = Some(cal_field(&base, i));
        assert!(statement(&sh, &blocks, &[[None; 11], same]).unwrap_err().contains("equals the run's"), "{}", OWN_FIELDS[i].0);
    }
    // outside a class: refused at the statement
    let mut bad = [None; 11];
    bad[1] = Some(12); // tn 12: a five-limb norm window at width 384
    assert!(statement(&sh, &blocks, &[[None; 11], bad]).is_err(), "an out-of-class tn was recorded");
}

/// The requantization host `2^sh out + r - half(sh) - acc`, at its largest
/// magnitude over the shift window, with `out` in its class, `r` in
/// `[0, 2^sh)` and `|acc| <= acc_max`.
fn host(window: std::ops::RangeInclusive<u32>, out_max: i128, acc_max: i128) -> i128 {
    window.map(|sh| (1i128 << sh) * out_max + ((1i128 << sh) - 1) + (if sh == 0 { 0 } else { 1i128 << (sh - 1) }) + acc_max).max().unwrap()
}

/// **The no-wrap clauses of every relation a per-layer constant enters, over
/// its whole class, at all six trained profiles.** Conservative bounds from
/// the shape's padded extents (int8 entries at magnitude 128, int16 at
/// 32768): QKV over `d_pad` (sh_qkv 1..=8), score over `head_dim` (sh_s
/// 1..=8), PV over `t_pad` keys with `p < 2^10` (sh_o 9..=16), AO over
/// `d_pad` (sh_ao 0..=8, int16 out), gate over `d_pad` (sh_g 1..=8),
/// product int16 x int16 (sh_h 9..=16, int16 out), down over `f_pad` (sh_z
/// 1..=8, int16 out); the norm quotient relation `2 x g Cn + D 2^tn -
/// 2 q D 2^tn - rho` with `Cn <= 2^20`, `D 2^tn < 2^31` (the four-limb window
/// `tn + 1 + bits(D_max) <= 32`), `rho < 2^32`; the isqrt relation with
/// `Ceps <= 2^40`. All must stay below p/2 (the relations then hold over the
/// integers); printed as log2.
#[test]
fn the_no_wrap_clauses_hold_over_each_class_at_all_six_trained_profiles() {
    let half_p = (zkp_core::field::P / 2) as i128;
    let tl = super::trained_calib_tests::pg_calibration();
    let l8 = super::trained_calib_tests::llama3_8b_calibration();
    let shapes = [
        Shape::tinyllama_trained(32, &tl, 9).unwrap(),
        Shape::tinyllama_trained(64, &tl, 9).unwrap(),
        Shape::tinyllama_trained(128, &tl, 9).unwrap(),
        Shape::llama3_8b_trained(32, &l8, 9).unwrap(),
        Shape::llama3_8b_trained(64, &l8, 9).unwrap(),
        Shape::llama3_8b_trained(128, &l8, 9).unwrap(),
    ];
    let (i8m, i16m) = (128i128, 32_768i128);
    let mut worst = 0i128;
    for s in &shapes {
        let rows = [
            ("qkv (sh_qkv)", host(ONE_LIMB_SHIFT, i8m, s.d_pad as i128 * i8m * i8m)),
            ("score (sh_s)", host(ONE_LIMB_SHIFT, i8m, s.head_dim as i128 * i8m * i8m)),
            ("pv (sh_o)", host(TWO_LIMB_SHIFT, i8m, s.t_pad as i128 * 1024 * i8m)),
            ("ao (sh_ao)", host(0..=TRAINED_SH_AO_MAX, i16m, s.d_pad as i128 * i8m * i8m)),
            ("gate (sh_g)", host(ONE_LIMB_SHIFT, i8m, s.d_pad as i128 * i8m * i8m)),
            ("product (sh_h)", host(TWO_LIMB_SHIFT, i16m, i16m * i16m)),
            ("down (sh_z)", host(ONE_LIMB_SHIFT, i16m, s.f_pad as i128 * i16m * i8m)),
            ("norm quotient (tn, cn, ceps)", 2 * i16m * i8m * i128::from(TRAINED_CN_MAX) + (1i128 << 31) + 2 * 127 * (1i128 << 31) + (1i128 << 32)),
            ("norm isqrt (ceps)", i128::from(TRAINED_CEPS_MAX) + s.width as i128 * i16m * i16m + 3 * (1i128 << 24)),
        ];
        let mut line = format!("R8 no-wrap {}:", s.profile);
        for (name, v) in rows {
            assert!(v < half_p, "{}: {name} reaches p/2 ({v})", s.profile);
            worst = worst.max(v);
            line.push_str(&format!(" {name} 2^{:.2};", (v as f64).log2()));
        }
        eprintln!("{line}");
    }
    assert!(worst < 1i128 << 46, "worst clause 2^{:.2}", (worst as f64).log2());
}

/// two witnesses in order, with block 0's output as the one boundary
struct Two(Vec<Option<Witness>>, Vec<i16>);

impl super::run::RunWitnessSource for Two {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        self.0[k].take().ok_or_else(|| "consumed".to_string())
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        if k == 0 {
            Ok(self.1.clone())
        } else {
            Err("one boundary".into())
        }
    }
}

fn plane(w: &Witness, p: usize) -> Vec<i16> {
    w.planes[p].iter().map(|v| i16::try_from(*v).unwrap()).collect()
}

fn true_words(sh: &Shape, padded: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| padded[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// **A two-block bound run with block 1 at its own constants in all eleven
/// fields** (library level): proves and verifies; a verifier whose statement
/// drops block 1's own constants refuses.
#[test]
fn a_two_block_run_with_block_1_fully_its_own_proves_verifies_and_is_bound() {
    let sh = rung();
    let base = sh.norm_calibration();
    let all = NormCalibration { tn: 9, cn_a: 700, cn_m: 1100, ceps: 16_777_259, sh_ao: 7, sh_qkv: 7, sh_s: 6, sh_o: 11, sh_g: 7, sh_h: 14, sh_z: 6 };
    let own1 = own_of(&base, &all);
    let s1 = sh.with_layer_calibration(&all).unwrap();
    let (w, input) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    let mut w1 = w.clone();
    for (i, m) in w1.iter_mut().enumerate() {
        let len = m.len();
        m.rotate_left((7 + i) % len);
    }
    let blocks: Vec<BlockPublic> = [w, w1]
        .iter()
        .map(|ws| {
            let (p, f) = super::dense_tests::statement_of_words(&sh, ws);
            BlockPublic::new(p, f)
        })
        .collect();
    let ids = Ids::new(&sh).unwrap();
    let w0 = witness::build_shaped(&sh, blocks[0].attention(), blocks[0].feed_forward(), &input).unwrap();
    let x1 = true_words(&sh, &plane(&w0, ids.at(A_X2)));
    let wit1 = witness::build_shaped(&s1, blocks[1].attention(), blocks[1].feed_forward(), &x1).expect("block 1's witness at its own constants");
    let ctx = *blake3::hash(b"native r8: per-layer calibration").as_bytes();
    let spec = IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap();
    let (expected, owners) = prepare_endpoints(spec, &plane(&w0, ids.at(A_X)), &plane(&wit1, ids.at(A_X2))).unwrap();
    let st = super::run::RunStatement::new_bound(super::trained_calib_tests::run_shape_for(&sh, 2), ctx, expected.clone(), &blocks, &[(0, 0), (0, 0)], &statement(&sh, &blocks, &[[None; 11], own1]).unwrap()).unwrap();
    assert_eq!(st.stage_shape(1).unwrap().norm_calibration(), all);
    assert_eq!(st.stage_shape(0).unwrap().norm_calibration(), base);
    let boundary = plane(&w0, ids.at(A_X2));
    let mut segs = Vec::new();
    super::run::prove_run(&st, &blocks, &mut Two(vec![Some(w0), Some(wit1)], boundary), owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    })
    .expect("the fully per-layer run proves");
    let verify = |own: [Option<i64>; 11]| -> Result<(), String> {
        let e = ExpectedIo::from_bytes_at(&sh, &expected.to_bytes())?;
        let st = super::run::RunStatement::new_bound(super::trained_calib_tests::run_shape_for(&sh, 2), ctx, e, &blocks, &[(0, 0), (0, 0)], &statement(&sh, &blocks, &[[None; 11], own])?)?;
        super::run::verify_run(&st, &blocks, &segs)
    };
    verify(own1).expect("the fully per-layer run verifies");
    assert!(verify([None; 11]).is_err(), "a run proved with block 1 at its own constants VERIFIED under a run-wide statement");
    // and with only the shifts, or only the norm constants, of block 1
    let mut shifts_only = own1;
    for i in 1..=4 {
        shifts_only[i] = None;
    }
    assert!(verify(shifts_only).is_err(), "VERIFIED with block 1's norm constants dropped");
    let mut norm_only = [None; 11];
    norm_only[1..=4].copy_from_slice(&own1[1..=4]);
    assert!(verify(norm_only).is_err(), "VERIFIED with block 1's shifts dropped");
}
