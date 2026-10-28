//! **NATIVE R12 (D38): Shieldstral-1.0-3B's three prover features and its
//! registered profiles.** TEST CODE ONLY. Public synthetic data only.
//!
//! * F1 — RoPE frequency transforms (YaRN, llama3) as public tables only,
//!   checked against the transformers reference (`results/zk60_1b_native_
//!   20261017/r12/rope_reference.py` / `.json`: the main-branch formulas
//!   transcribed in binary64, agreeing with torch float32 and the installed
//!   transformers 4.48 to float32 precision);
//! * F2 — head_dim decoupled from d / heads: the decoupled-head rung (query
//!   axis 512 against a padded model axis 256) proves and verifies and its
//!   witness equals the independent kernel; the Shieldstral shapes (query
//!   4096, model 3072) build, lay out and (heavy, ignored) prove;
//! * F3 — tied embeddings: the statement binds both integer tables to the one
//!   tensor digest; the loader reads a tied export's manifests;
//! * the profiles: row widths, pins, n_col against the DD cap, counted
//!   soundness floors and counts.

use super::layout::*;
use super::rope::{inv_freq, rope_tables, RopeScaling};
use super::shape::*;
use super::trained_statement::*;
use super::*;

// ------------------------------------------------------------------- helpers

fn table_sha(c: &[i64], s: &[i64]) -> String {
    use sha2::{Digest as _, Sha256};
    let mut h = Sha256::new();
    for v in c.iter().chain(s.iter()) {
        h.update(v.to_le_bytes());
    }
    h.finalize().iter().map(|b| format!("{b:02x}")).collect()
}

/// a Shieldstral calibration for the generic witness (tn 10: the derived
/// window at width 3072 is 32 bits, four limbs)
pub(super) fn shieldstral_calibration(cn_a: i64, cn_m: i64) -> NormCalibration {
    NormCalibration { tn: 10, cn_a, cn_m, ceps: 129_746, sh_ao: 6, sh_qkv: 8, sh_s: 7, sh_o: 9, sh_g: 8, sh_h: 16, sh_z: 5 }
}

pub(super) fn shieldstral(t: usize, dd: bool) -> Shape {
    let cal = shieldstral_calibration(11_000, 11_500);
    if dd { Shape::shieldstral_trained_dd(t, &cal, 9) } else { Shape::shieldstral_trained(t, &cal, 9) }.unwrap_or_else(|e| panic!("the Shieldstral T{t} shape (dd {dd}): {e}"))
}

pub(super) fn rung_hd() -> Shape {
    Shape::rung_hd(&super::trained_calib_tests::rung_tc_calibration()).expect("the decoupled-head rung")
}

/// the public statement of nine TRUE-size words at `sh` (the profile's RoPE
/// tables, an exp table of score exponent `e_s`, the frozen SiLU member)
fn block_of(sh: &Shape, w: &[Vec<i8>; 9], e_s: i32) -> (BlockPublic, Vec<i64>, Vec<i16>, Vec<i64>, Vec<i64>) {
    let (cos, sin) = rope_tables_for(sh, trained_rope_theta(sh.profile).unwrap_or(10000.0)).expect("the profile's RoPE tables");
    let (exp, _) = crate::tables_attn::exp_member(e_s, sh.head_dim, sh.f_e);
    let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("a frozen SiLU member");
    let aw = super::grow_tests::pad_attention_weights(sh, &w[0], &w[1], &w[2], &w[3], &w[4]);
    let fw = super::grow_tests::pad_ff_weights(sh, &w[5], &w[6], &w[7], &w[8]);
    let public = AttentionPublic::new_shaped(sh, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp).expect("the attention statement");
    let ff = FeedForwardPublic::new_shaped(sh, &fw[0], &fw[1], &fw[2], &fw[3], &act).expect("the feed-forward statement");
    (BlockPublic::new(public, ff), exp.to_vec(), act.to_vec(), cos, sin)
}

/// the INDEPENDENT shape-driven reference kernel's block output (true size)
fn kernel_out(sh: &Shape, w: &[Vec<i8>; 9], x: &[i16], exp: &[i64], act: &[i16], cos: &[i64], sin: &[i64]) -> Vec<i16> {
    use private_block_kernel_shaped as k;
    let ksh = super::parity::kernel_shape(sh);
    let mut scratch = vec![0i64; ksh.scratch_len()];
    let mut out = vec![0i16; ksh.x_len()];
    let wr = k::WeightsRef { wq: &w[0], wk: &w[1], wv: &w[2], wo: &w[3], gamma_a: &w[4], gamma_m: &w[5], wg_t: &w[6], wu_t: &w[7], wd_t: &w[8] };
    let tr = k::TablesRef { rope_cos: cos, rope_sin: sin, exp, act };
    k::run_shaped(&ksh, x, &wr, &tr, &mut scratch, None, &mut out).unwrap_or_else(|e| panic!("the reference kernel refuses: {e:?}"));
    out
}

fn true_words(sh: &Shape, w: &super::witness::Witness, plane: usize) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| (0..sh.width).map(move |i| (t, i))).map(|(t, i)| w.planes[plane][t * sh.d_pad + i] as i16).collect()
}

/// a generic dense block at `sh` that the honest witness admits: the first
/// admissible of a few band candidates (dense weights, heads that differ)
fn dense_bands() -> [super::trained_calib_tests::Bands; 5] {
    use super::trained_calib_tests::{Bands, TRAINED_BANDS};
    [TRAINED_BANDS, Bands { attn: 6, gate: 8, ..TRAINED_BANDS }, Bands { attn: 4, gate: 8, down: 1, ..TRAINED_BANDS }, Bands { attn: 4, gate: 6, down: 1, xmag: 4_000, ..TRAINED_BANDS }, Bands { attn: 3, gate: 4, down: 1, xmag: 3_000, ..TRAINED_BANDS }]
}

fn dense_admissible(sh: &Shape, e_s: i32) -> ([Vec<i8>; 9], Vec<i16>, BlockPublic, Vec<i64>, Vec<i16>, Vec<i64>, Vec<i64>, super::witness::Witness) {
    for b in dense_bands() {
        let (w, input) = super::trained_calib_tests::trained_dense_words(sh, b);
        let (blk, exp, act, cos, sin) = block_of(sh, &w, e_s);
        match super::witness::build_shaped(sh, blk.attention(), blk.feed_forward(), &input) {
            Ok(wit) => {
                eprintln!("R12 {}: bands {b:?} admissible", sh.profile);
                return (w, input, blk, exp, act, cos, sin, wit);
            }
            Err(e) => eprintln!("R12 {}: bands {b:?} refused: {e}", sh.profile),
        }
    }
    panic!("no candidate band is admissible at {}", sh.profile);
}

/// a generic dense block proves and verifies at `sh`, and its witness output
/// equals the independent kernel's; returns the segment length
fn proves_and_matches_the_kernel(sh: &Shape, e_s: i32) -> usize {
    let (w, input, blk, exp, act, cos, sin, wit) = dense_admissible(sh, e_s);
    let ids = Ids::new(sh).unwrap();
    assert_eq!(true_words(sh, &wit, ids.at(A_X2)), kernel_out(sh, &w, &input, &exp, &act, &cos, &sin), "{}: the witness and the independent reference kernel disagree", sh.profile);
    // heads that differ: the score plane is not one head repeated
    let s8 = &wit.planes[ids.at(A_S8)];
    let blk_len = sh.t_pad * sh.t_pad;
    assert!((1..sh.q_heads).any(|h| s8[h * blk_len..(h + 1) * blk_len] != s8[..blk_len]), "{}: every head carries the same scores", sh.profile);
    let one = super::trained_calib_tests::prove_one_bound(sh, &blk, wit).unwrap_or_else(|e| panic!("{}: the honest block does not prove: {e}", sh.profile));
    if let Some(root) = std::env::var_os("ZK60_R12_EVIDENCE_DIR") {
        let dir = std::path::PathBuf::from(root).join(format!("t{}-dd{}", sh.tokens, sh.dd_cap));
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("segment.bin"), &one.seg).unwrap();
        std::fs::write(dir.join("expected.bin"), one.expected.to_bytes()).unwrap();
        std::fs::write(dir.join("block-digest.bin"), blk.digest()).unwrap();
        std::fs::write(dir.join("profile.txt"), sh.profile).unwrap();
    }
    super::trained_calib_tests::verify_one_bound(sh, &blk, &one.expected.to_bytes(), &one.seg).unwrap_or_else(|e| panic!("{}: the honest block does not verify: {e}", sh.profile));
    // a one-byte flip of the segment is refused
    let mut bad = one.seg.clone();
    let at = bad.len() / 2;
    bad[at] ^= 1;
    assert!(super::trained_calib_tests::verify_one_bound(sh, &blk, &one.expected.to_bytes(), &bad).is_err(), "{}: a flipped segment verified", sh.profile);
    one.seg.len()
}

// ------------------------------------------------------------- F1: RoPE

/// `rope_reference.json` (r12/rope_reference.py, 2026-10-21): the SHA-256 of
/// the T512 tables (little-endian int64 cos words, then sin words) built from
/// the transformers main-branch formulas in binary64
const REF_YARN_SHIELDSTRAL_HD128: &str = "261b32b8e461fa3866ee98455b3a4b39db51d846833115f525809c8375e12a5f";
const REF_LLAMA3_1_HD128: &str = "9475db388fb1b6a3f4c918f09e71f6c9465a8d3e286eb80cc99d9618dfcfa307";
const REF_LLAMA3_1_HD64: &str = "be90a500049a4ad9748d692324e8093a98083f322421830fd2fb9acff05912f4";
const REF_UNSCALED_1E6_HD128: &str = "fd6f2e08b2ceec4bdb8d12cc680e9988cab99d57e0feb6ece116240c98f992bc";

#[test]
fn f1_yarn_tables_equal_the_transformers_reference() {
    let s = RopeScaling::shieldstral();
    assert_eq!(s.attention_factor(), 1.0, "Shieldstral's YaRN attention factor (mscale = mscale_all_dim) is exactly 1");
    s.check().expect("Shieldstral's transform passes its class");
    let (c, sn) = rope_tables(512, 128, SHIELDSTRAL_ROPE_THETA, &s, F_RO).expect("the YaRN tables");
    assert_eq!(table_sha(&c, &sn), REF_YARN_SHIELDSTRAL_HD128, "the YaRN tables differ from the transformers reference");
    // and they are NOT the unscaled tables (YaRN moves 22,650 of 65,536 entries at T512)
    let (cu, su) = crate::tables_attn::rope_tables_generate(512, 128, SHIELDSTRAL_ROPE_THETA, F_RO);
    let moved = c.iter().zip(&cu).chain(sn.iter().zip(&su)).filter(|(a, b)| a != b).count();
    assert_eq!(moved, 22_650, "the YaRN transform moves the reference's count of entries");
    // the transform interpolates the low frequencies by the factor and keeps the high ones
    let inv = inv_freq(128, SHIELDSTRAL_ROPE_THETA, &s);
    let un = inv_freq(128, SHIELDSTRAL_ROPE_THETA, &RopeScaling::None);
    assert!((inv[0] / un[0] - 1.0).abs() < 1e-12 && (inv[63] * 16.0 / un[63] - 1.0).abs() < 1e-12, "YaRN keeps the fastest and divides the slowest frequency by 16");
}

/// **The prep lane's independent reference** (`results/zk60_shieldstral_
/// prep_20261021/crosscheck/rope_tables_reference.npz`, sha256 ffcb1b29...:
/// float64 cos / sin at positions 0..2047, the correct YaRN — correction
/// range at original_max_position_embeddings 16384, attention factor 1 —
/// equal to transformers 5.13.1, which has Ministral3, NOT 4.48.1's default
/// path): rounded half up at 2^7 it is THE table, entry for entry. Its T512
/// digest is [`REF_YARN_SHIELDSTRAL_HD128`] (computed independently), and at
/// T2048 this. The frequency split is 21 original / 27 interpolated / 16 ramp,
/// so 43 of the 64 pairs move.
const REF_PREP_LANE_YARN_T2048: &str = "5e370a8c31a6b59c515171aa2293ed19c5115371daac7eda8e94faf44e94c255";

#[test]
fn f1_yarn_tables_equal_the_prep_lanes_reference_to_2048_positions() {
    let s = RopeScaling::shieldstral();
    let (c, sn) = rope_tables(2048, 128, SHIELDSTRAL_ROPE_THETA, &s, F_RO).expect("the YaRN tables");
    assert_eq!(table_sha(&c, &sn), REF_PREP_LANE_YARN_T2048, "the YaRN tables differ from the prep lane's reference");
    let inv = inv_freq(128, SHIELDSTRAL_ROPE_THETA, &s);
    let un = inv_freq(128, SHIELDSTRAL_ROPE_THETA, &RopeScaling::None);
    let original = inv.iter().zip(&un).filter(|(a, b)| (*a / *b - 1.0).abs() < 1e-12).count();
    let interpolated = inv.iter().zip(&un).filter(|(a, b)| (*a * 16.0 / *b - 1.0).abs() < 1e-12).count();
    assert_eq!((original, interpolated, 64 - original - interpolated), (21, 27, 16), "the YaRN frequency split");
}

#[test]
fn f1_llama3_tables_equal_the_transformers_reference() {
    let s = RopeScaling::llama3_1();
    s.check().expect("llama3's transform passes its class");
    for (hd, want) in [(128usize, REF_LLAMA3_1_HD128), (64, REF_LLAMA3_1_HD64)] {
        let (c, sn) = rope_tables(512, hd, 500_000.0, &s, F_RO).expect("the llama3 tables");
        assert_eq!(table_sha(&c, &sn), want, "head_dim {hd}: the llama3 tables differ from the transformers reference");
    }
}

/// The unscaled case IS the frozen generator, entry for entry, at every
/// registered base and head size; and the frozen generator agrees with the
/// independent Python generator at Shieldstral's base.
#[test]
fn f1_the_unscaled_case_is_the_frozen_generator() {
    for (t, hd, base) in [(32usize, 8usize, 10_000.0), (128, 64, 10_000.0), (128, 128, 500_000.0), (512, 128, 1_000_000.0)] {
        assert_eq!(rope_tables(t, hd, base, &RopeScaling::None, F_RO).unwrap(), crate::tables_attn::rope_tables_generate(t, hd, base, F_RO), "T{t} hd{hd} base {base}");
    }
    let (c, s) = crate::tables_attn::rope_tables_generate(512, 128, 1_000_000.0, F_RO);
    assert_eq!(table_sha(&c, &s), REF_UNSCALED_1E6_HD128, "the frozen generator and the reference script disagree on the unscaled table");
}

#[test]
fn f1_an_attention_factor_other_than_one_is_refused_by_name() {
    // mscale absent (0): transformers infers 0.1 ln(16) + 1 = 1.277
    let s = RopeScaling::Yarn { factor: 16.0, original_max: 16384, beta_fast: 32.0, beta_slow: 1.0, mscale: 0.0, mscale_all_dim: 0.0, truncate: true };
    let e = rope_tables(128, 128, 1e6, &s, F_RO).expect_err("an attention factor of 1.277 was accepted");
    assert!(e.contains("attention factor") && e.contains("refused by name"), "{e}");
    let e = RopeScaling::Yarn { factor: 16.0, original_max: 16384, beta_fast: 32.0, beta_slow: 1.0, mscale: 1.0, mscale_all_dim: 0.5, truncate: true }.check().expect_err("mscale / mscale_all_dim != 1 accepted");
    assert!(e.contains("attention factor"), "{e}");
}

/// Each profile pins its transform, the encoding round-trips, and the
/// tables a Shieldstral shape proves with are the YaRN ones.
#[test]
fn f1_the_profiles_pin_their_transforms() {
    for p in SHIELDSTRAL_PROFILES {
        assert_eq!(trained_rope_scaling(p), Some(RopeScaling::shieldstral()), "{p}");
        assert_eq!(trained_rope_theta(p), Some(1_000_000.0), "{p}");
    }
    for p in [TINYLLAMA_T128_TRAINED_PROFILE, LLAMA3_8B_T128_TRAINED_PROFILE, TINYLLAMA_T128_DD_TRAINED_PROFILE, LLAMA3_8B_T128_DD_TRAINED_PROFILE, TRAINED_HD_RUNG_PROFILE] {
        assert_eq!(trained_rope_scaling(p), Some(RopeScaling::None), "{p}");
    }
    assert_eq!(trained_rope_scaling(TOY_PROFILE), None);
    for s in [RopeScaling::None, RopeScaling::shieldstral(), RopeScaling::llama3_1()] {
        assert_eq!(RopeScaling::decode(&s.encode()), Ok(s), "{s:?}");
    }
    assert!(RopeScaling::decode(b"yarn-short").is_err());
    let sh = shieldstral(128, false);
    let (c, s) = rope_tables_for(&sh, SHIELDSTRAL_ROPE_THETA).unwrap();
    assert_eq!((c, s), rope_tables(128, 128, SHIELDSTRAL_ROPE_THETA, &RopeScaling::shieldstral(), F_RO).unwrap());
    // the loader's parser: transformers' own keys
    let j = super::trained_block::parse_json(br#"{"rope_type": "yarn", "factor": 16.0, "original_max_position_embeddings": 16384, "beta_fast": 32.0, "beta_slow": 1.0, "mscale": 1.0, "mscale_all_dim": 1.0}"#).unwrap();
    assert_eq!(super::trained_block::rope_scaling_of(Some(&j)), Ok(RopeScaling::shieldstral()));
    let j = super::trained_block::parse_json(br#"{"rope_type": "default"}"#).unwrap();
    assert_eq!(super::trained_block::rope_scaling_of(Some(&j)), Ok(RopeScaling::None));
    assert_eq!(super::trained_block::rope_scaling_of(None), Ok(RopeScaling::None));
    let j = super::trained_block::parse_json(br#"{"rope_type": "yarn", "factor": 16.0, "original_max_position_embeddings": 16384, "beta_fast": 32.0, "beta_slow": 1.0}"#).unwrap();
    assert!(super::trained_block::rope_scaling_of(Some(&j)).is_err(), "a YaRN object without mscale was accepted");
}

/// A statement's calibration binds the transform: the profile's pin, and
/// encoded only when it is not `none` (every statement before R12 keeps
/// its bytes).
#[test]
fn f1_the_statement_binds_the_transform() {
    let sh = shieldstral(128, false);
    let mut prov = Provenance::recipe("native/synthetic", 1.0 / 512.0, [5; 32], [6; 32]);
    prov.rope_theta = SHIELDSTRAL_ROPE_THETA;
    prov.rope_scaling = RopeScaling::shieldstral();
    let cal = IntegerCalibration::as_the_code_proves(&sh, &prov);
    cal.check_honoured_by_code(&sh).expect("the pinned transform is honoured");
    let mut wrong = prov.clone();
    wrong.rope_scaling = RopeScaling::None;
    let e = IntegerCalibration::as_the_code_proves(&sh, &wrong).check_honoured_by_code(&sh).expect_err("an unscaled RoPE at a YaRN profile");
    assert!(e.contains("RoPE transform"), "{e}");
    let ts = super::trained_calib_tests::tinyllama_at(128);
    let mut p2 = Provenance::recipe("native/synthetic", 1.0 / 512.0, [5; 32], [6; 32]);
    p2.rope_scaling = RopeScaling::shieldstral();
    let e = IntegerCalibration::as_the_code_proves(&ts, &p2).check_honoured_by_code(&ts).expect_err("a YaRN transform at TinyLlama");
    assert!(e.contains("RoPE transform"), "{e}");
}

// ------------------------------------------------------------- F2: head_dim

/// **F2 at seconds' scale.** The decoupled-head rung's query axis (8 x 64 =
/// 512, padded 512) is wider than its padded model axis (256): `Wq` writes
/// it, `Wo` reads it, `Dom::Q` is laid out on it. A generic dense block
/// proves and verifies, its witness equals the independent kernel, and a
/// flipped segment is refused.
#[test]
fn f2_the_decoupled_rung_proves_and_matches_the_kernel() {
    let sh = rung_hd();
    assert_eq!((sh.width, sh.d_pad, sh.q_width(), sh.q_pad()), (192, 256, 512, 512), "the rung decouples the query axis");
    assert_eq!(sh.size(Dom::Q), sh.t_pad * sh.q_pad(), "Dom::Q is laid out on the query axis");
    assert_eq!(sh.slots()[SC_WO].0, 9, "Wo folds over the query axis (2^9)");
    assert_eq!(sh.slots()[SC_QMM].0, 8, "Wq folds over the model axis (2^8)");
    let n = proves_and_matches_the_kernel(&sh, 2);
    eprintln!("R12 F2 rung-HD: one-block segment {n} B");
}

/// The Shieldstral shapes: the query axis 4096 against the model axis 3072
/// (the padded widths coincide at 4096; the TRUE widths differ), the model
/// axis pads, nothing on the head or token axis pads, so DD's geometry
/// holds.
#[test]
fn f2_the_shieldstral_shapes_build_and_lay_out() {
    for t in [128usize, 256] {
        for dd in [false, true] {
            let sh = shieldstral(t, dd);
            assert_eq!((sh.width, sh.d_pad, sh.q_width(), sh.q_pad(), sh.hidden, sh.f_pad), (3072, 4096, 4096, 4096, 9216, 16384), "{}", sh.profile);
            assert!(sh.pads(Dom::D) && !sh.pads(Dom::Q) && sh.pads(Dom::F), "{}: the model and hidden axes pad, the query axis does not", sh.profile);
            assert_eq!(sh.dd_cap, if dd { DD_CAP } else { 0 }, "{}", sh.profile);
            if dd {
                sh.check_dd_geometry().unwrap_or_else(|e| panic!("{}: {e}", sh.profile));
            }
            let lay = Layout::for_shape(&sh).unwrap_or_else(|e| panic!("{}: {e}", sh.profile));
            let tot = sh.totals();
            eprintln!(
                "R12 SHIELDSTRAL {} | log_cols {} | A rows {} H rows {} | committed {} | U8 {} | slots {} | receipt (counted, per block) {} B | norm window {} limbs {}",
                sh.profile,
                sh.log_cols,
                tot.a_rows,
                tot.h_rows,
                (tot.a_rows + tot.h_rows) << sh.log_cols,
                tot.u8_lookups,
                sh.n_slots(),
                tot.receipt_bytes.total,
                sh.norm_wrho,
                sh.limbs_norm()
            );
            assert_eq!(lay.slots().len(), sh.n_slots());
            assert_eq!(sh.norm_wrho, 32, "{}: tn 10 at width 3072 is the four-limb window", sh.profile);
        }
    }
    // only 128 and 256 are registered
    assert!(Shape::shieldstral_trained(512, &shieldstral_calibration(11_000, 11_500), 9).unwrap_err().contains("no trained Shieldstral profile"));
}

/// **F2 at Shieldstral's shapes, the generic dense witness (heavy).**
#[test]
#[ignore = "native lane heavy: a Shieldstral T128 block (width 3072, query 4096) proves and verifies, witness == kernel"]
fn f2_a_generic_dense_shieldstral_t128_block_proves_and_matches_the_kernel() {
    let n = proves_and_matches_the_kernel(&shieldstral(128, false), 2);
    eprintln!("R12 F2 Shieldstral T128: one-block segment {n} B");
}

#[test]
#[ignore = "native lane heavy: a Shieldstral T128 DD block proves and verifies, witness == kernel"]
fn f2_a_generic_dense_shieldstral_t128_dd_block_proves_and_matches_the_kernel() {
    let n = proves_and_matches_the_kernel(&shieldstral(128, true), 2);
    eprintln!("R12 F2 Shieldstral T128 DD: one-block segment {n} B");
}

/// Rebuild only the public fixture and verify retained bytes in a new process.
/// This does not construct a witness or generate a proof.
fn verify_saved_shieldstral(dd: bool) {
    let sh = shieldstral(128, dd);
    let root = std::env::var_os("ZK60_R12_EVIDENCE_DIR").expect("ZK60_R12_EVIDENCE_DIR is set");
    let dir = std::path::PathBuf::from(root).join(format!("t{}-dd{}", sh.tokens, sh.dd_cap));
    assert_eq!(std::fs::read_to_string(dir.join("profile.txt")).unwrap(), sh.profile);
    let digest = std::fs::read(dir.join("block-digest.bin")).unwrap();
    let mut public = None;
    for bands in dense_bands() {
        let (words, _) = super::trained_calib_tests::trained_dense_words(&sh, bands);
        let (blk, _, _, _, _) = block_of(&sh, &words, 2);
        if blk.digest().as_slice() == digest.as_slice() {
            public = Some(blk);
            break;
        }
    }
    let blk = public.expect("the retained block digest matches a public dense fixture");
    let expected = std::fs::read(dir.join("expected.bin")).unwrap();
    let mut segment = std::fs::read(dir.join("segment.bin")).unwrap();
    super::trained_calib_tests::verify_one_bound(&sh, &blk, &expected, &segment).expect("the saved Shieldstral segment verifies in a fresh process");
    let at = segment.len() / 2;
    segment[at] ^= 1;
    assert!(super::trained_calib_tests::verify_one_bound(&sh, &blk, &expected, &segment).is_err(), "a modified saved segment must be rejected");
    eprintln!("R12 fresh-process Shieldstral T128 DD={dd}: {} bytes verified; modified segment rejected", segment.len());
}

#[test]
#[ignore = "native lane: fresh-process verification of the saved Shieldstral T128 dense receipt"]
fn f2_saved_shieldstral_t128_receipt_verifies_in_a_fresh_process() {
    verify_saved_shieldstral(false);
}

#[test]
#[ignore = "native lane: fresh-process verification of the saved Shieldstral T128 DD dense receipt"]
fn f2_saved_shieldstral_t128_dd_receipt_verifies_in_a_fresh_process() {
    verify_saved_shieldstral(true);
}

/// The trained loader expects the TRUE decoupled shapes: `wq` is
/// `[q_heads * head_dim, d]`, `wo` `[d, q_heads * head_dim]`; at every
/// profile before R12 these are `[d, d]`.
#[test]
fn f2_the_true_weight_shapes() {
    let sh = shieldstral(128, false);
    assert_eq!((sh.q_width(), sh.width), (4096, 3072));
    for p in [super::trained_calib_tests::tinyllama_at(128), super::trained_calib_tests::llama3_8b_at(128)] {
        assert_eq!((p.q_width(), p.q_pad()), (p.width, p.d_pad), "{}: an existing profile's query axis is its model axis", p.profile);
    }
    // a statement whose Wq is (model x model) at the decoupled rung is refused
    let r = rung_hd();
    let (w, _) = super::trained_calib_tests::trained_dense_words(&r, super::trained_calib_tests::TRAINED_BANDS);
    let aw = super::grow_tests::pad_attention_weights(&r, &w[0], &w[1], &w[2], &w[3], &w[4]);
    let (cos, sin) = rope_tables_for(&r, 10_000.0).unwrap();
    let (exp, _) = crate::tables_attn::exp_member(2, r.head_dim, r.f_e);
    let short = vec![0i8; r.d_pad * r.d_pad];
    let e = AttentionPublic::new_shaped(&r, &short, &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp).err().expect("a (d x d) Wq at a decoupled shape was accepted");
    assert!(e.contains("public weight shape"), "{e}");
}

// ------------------------------------------------------------- F3: tied

fn tied_record() -> TiedEmbedding {
    let (name, digest) = tied_tensor_for_profile(SHIELDSTRAL_T128_TRAINED_PROFILE).expect("Shieldstral is tied");
    TiedEmbedding { tensor: name.into(), tensor_sha256: digest, embedding_table_sha256: [0x11; 32], head_table_sha256: [0x22; 32], head_mult_sha256: [0x33; 32] }
}

/// the statement of one synthetic Shieldstral block under the PINNED source
fn pinned_statement(tied: Option<TiedEmbedding>) -> Result<TrainedModelStatement, String> {
    let sh = shieldstral(128, false);
    let (public, ff, _) = super::grow_tests::tame_case(&sh);
    let blk = BlockPublic::new(public, ff);
    let mut prov = Provenance::recipe("export:shieldstral-synthetic", 1.0 / 512.0, [5; 32], [6; 32]);
    prov.rope_theta = SHIELDSTRAL_ROPE_THETA;
    prov.rope_scaling = RopeScaling::shieldstral();
    let cal = IntegerCalibration::as_the_code_proves(&sh, &prov);
    TrainedModelStatement::new_with_tied(&sh, super::run::RUN_PROFILE_SHIELDSTRAL_T128_TRAINED, ModelSource::shieldstral_1_0_3b(), cal, vec![LayerRecord::of_block(0, &blk, vec![])], tied)
}

#[test]
fn f3_a_tied_statement_binds_both_tables_to_the_one_tensor() {
    let st = pinned_statement(Some(tied_record())).expect("the tied statement");
    let id = st.identity();
    // every digest of the record is bound
    for k in 0..4 {
        let mut t = tied_record();
        match k {
            0 => t.embedding_table_sha256[0] ^= 1,
            1 => t.head_table_sha256[0] ^= 1,
            2 => t.head_mult_sha256[0] ^= 1,
            _ => t.tensor_sha256[0] ^= 1,
        }
        match pinned_statement(Some(t)) {
            Ok(s2) => assert_ne!(s2.identity(), id, "digest {k} of the tied record is not bound"),
            Err(e) => {
                assert_eq!(k, 3, "only the tensor digest is checked against the pin: {e}");
                assert!(e.contains("not the pinned checkpoint's"), "{e}");
            }
        }
    }
    // the record is required, named, and nonzero
    let e = pinned_statement(None).expect_err("a tied profile without its record");
    assert!(e.contains("ties its embedding and head"), "{e}");
    let e = pinned_statement(Some(TiedEmbedding { tensor: "lm_head.weight".into(), ..tied_record() })).expect_err("a record naming another tensor");
    assert!(e.contains("names tensor"), "{e}");
    let e = pinned_statement(Some(TiedEmbedding { head_mult_sha256: [0; 32], ..tied_record() })).expect_err("a zero digest");
    assert!(e.contains("zero digest"), "{e}");
    // an untied profile refuses a record
    let ts = super::trained_calib_tests::tinyllama_at(128);
    let (public, ff, _) = super::grow_tests::tame_case(&ts);
    let blk = BlockPublic::new(public, ff);
    let cal = IntegerCalibration::as_the_code_proves(&ts, &Provenance::recipe("x", 1.0 / 512.0, [5; 32], [6; 32]));
    let e = TrainedModelStatement::new_with_tied(&ts, super::run::RUN_PROFILE_TINYLLAMA_T128_TRAINED, ModelSource::tinyllama_chat_v1_0(), cal, vec![LayerRecord::of_block(0, &blk, vec![])], Some(tied_record())).expect_err("a tied record at TinyLlama");
    assert!(e.contains("untied model"), "{e}");
}

/// The loader's tied-record reader on a synthetic `token_io/` directory: the
/// three declarations agree and the files hash to their manifests -> the
/// record; any disagreement is refused by name.
#[test]
fn f3_the_loader_reads_a_tied_export() {
    use super::trained_block::{hex, parse_json, sha256, tied_of, Geometry};
    let (name, digest) = tied_tensor_for_profile(SHIELDSTRAL_T128_TRAINED_PROFILE).unwrap();
    let root = std::env::temp_dir().join(format!("r12-tied-{}", std::process::id()));
    let td = root.join("token_io");
    std::fs::create_dir_all(&td).unwrap();
    let files = [("embedding_int16.bin", vec![1u8; 4096]), ("head_int8_perrow.bin", vec![2u8; 2048]), ("head_mult12.bin", vec![3u8; 64])];
    for (f, b) in &files {
        std::fs::write(td.join(f), b).unwrap();
    }
    let h = |i: usize| hex(&sha256(&files[i].1));
    let write = |tensor: &str, dg: &str, head_src: &str| {
        std::fs::write(td.join("token_io.json"), format!(r#"{{"embedding_table": {{"file": "embedding_int16.bin", "sha256": "{}", "source_tensor": {{"name": "{tensor}", "sha256": "{dg}"}}}}}}"#, h(0))).unwrap();
        std::fs::write(td.join("head_manifest.json"), format!(r#"{{"head_int8_perrow.bin": {{"sha256": "{}"}}, "head_mult12.bin": {{"sha256": "{}"}}, "source_tensor": {{"name": "{name}", "sha256": "{head_src}"}}}}"#, h(1), h(2))).unwrap();
    };
    let dg = hex(&digest);
    let profile = parse_json(format!(r#"{{"tied_embeddings": {{"tensor": "{name}", "sha256": "{dg}"}}}}"#).as_bytes()).unwrap();
    let src = ModelSource::shieldstral_1_0_3b();
    write(name, &dg, &dg);
    let t = tied_of(&root, &profile, Geometry::Shieldstral(128), &src).expect("a consistent tied export").expect("a record");
    assert_eq!((t.tensor.as_str(), t.tensor_sha256), (name, digest));
    assert_eq!((t.embedding_table_sha256, t.head_table_sha256, t.head_mult_sha256), (sha256(&files[0].1), sha256(&files[1].1), sha256(&files[2].1)));
    // the head names another digest
    write(name, &dg, &"ab".repeat(32));
    let e = tied_of(&root, &profile, Geometry::Shieldstral(128), &src).expect_err("the head's source differs");
    assert!(e.contains("is not the tied tensor"), "{e}");
    // a table file that is not its manifest's
    write(name, &dg, &dg);
    std::fs::write(td.join("head_mult12.bin"), [9u8; 64]).unwrap();
    let e = tied_of(&root, &profile, Geometry::Shieldstral(128), &src).expect_err("a modified multiplier file");
    assert!(e.contains("is not its manifest's"), "{e}");
    std::fs::write(td.join("head_mult12.bin"), &files[2].1).unwrap();
    // a declared digest that is not the pinned checkpoint's
    let p2 = parse_json(format!(r#"{{"tied_embeddings": {{"tensor": "{name}", "sha256": "{}"}}}}"#, "cd".repeat(32)).as_bytes()).unwrap();
    let e = tied_of(&root, &p2, Geometry::Shieldstral(128), &src).expect_err("an unpinned tensor digest");
    assert!(e.contains("not the pinned checkpoint's"), "{e}");
    // no declaration at a tied geometry; a declaration at an untied one
    let empty = parse_json(b"{}").unwrap();
    assert!(tied_of(&root, &empty, Geometry::Shieldstral(128), &src).unwrap_err().contains("must name the tied tensor"));
    assert!(tied_of(&root, &profile, Geometry::TinyLlama(128), &ModelSource::tinyllama_chat_v1_0()).unwrap_err().contains("untied"));
    assert_eq!(tied_of(&root, &empty, Geometry::TinyLlama(128), &ModelSource::tinyllama_chat_v1_0()), Ok(None));
    let _ = std::fs::remove_dir_all(&root);
}

// ------------------------------------------------------------- the profiles

/// The registered row widths are the smallest counted receipts (task 3's
/// rule), at T128 and T256, without and with DD.
#[test]
fn the_shieldstral_row_widths_are_the_smallest_counted_receipts() {
    let cal = shieldstral_calibration(11_000, 11_500);
    for t in [128usize, 256] {
        for dd in [false, true] {
            let mut rows = Vec::new();
            for lc in [12usize, 13, 14, 15, 16] {
                if let Ok(s) = Shape::shieldstral_at(t, lc, dd, &cal, 9) {
                    rows.push((lc, s.receipt_bytes().total, (s.totals().a_rows + s.totals().h_rows) << lc));
                }
            }
            let best = rows.iter().min_by_key(|r| r.1).unwrap().0;
            eprintln!("R12 ROW WIDTH Shieldstral T{t} dd {dd}: {rows:?} -> 2^{best}");
            assert_eq!(Some(best), shieldstral_log_cols(t), "T{t} dd {dd}: the registered row width is not the smallest counted receipt");
        }
    }
}

#[test]
fn the_shieldstral_profiles_carry_their_pins() {
    for p in SHIELDSTRAL_PROFILES {
        assert_eq!(p.len(), TINYLLAMA_T128_TRAINED_PROFILE.len(), "{p}: a new block profile length");
        assert_eq!(ModelSource::pinned_for_profile(p), Some(ModelSource::shieldstral_1_0_3b()), "{p}");
        assert_eq!(tied_tensor_for_profile(p).map(|t| t.0), Some("language_model.model.embed_tokens.weight"), "{p}");
    }
    for rp in [super::run::RUN_PROFILE_SHIELDSTRAL_T128_TRAINED, super::run::RUN_PROFILE_SHIELDSTRAL_T256_TRAINED, super::run::RUN_PROFILE_SHIELDSTRAL_T128_DD, super::run::RUN_PROFILE_SHIELDSTRAL_T256_DD] {
        assert_eq!(rp.len(), super::run::RUN_PROFILE_TINYLLAMA_T128_TRAINED.len(), "{rp}: a new run profile length");
    }
    assert_eq!(TRAINED_HD_RUNG_PROFILE.len(), TRAINED_DD_RUNG_PROFILE.len());
    assert_eq!(super::run::RUN_PROFILE_RUNG_HD.len(), super::run::RUN_PROFILE_RUNG_DD.len());
    assert_eq!(tied_tensor_for_profile(TINYLLAMA_T128_TRAINED_PROFILE), None);
    assert_eq!(tied_tensor_for_profile(LLAMA3_8B_T128_TRAINED_PROFILE), None);
    let src = ModelSource::shieldstral_1_0_3b();
    assert_eq!((src.checkpoint_layers, src.revision.len()), (26, 40));
}

/// **n_col against the DD cap at head_dim 128** (the exp table depends on
/// `e_s`, `head_dim` and `f_e` only, so Shieldstral's equal Llama-3-8B's):
/// every `e_s` of the declared class at the f_e class's lower values.
#[test]
fn n_col_against_the_dd_cap_at_head_dim_128() {
    let mut rows = Vec::new();
    for f_e in [9u32, 10, 11, 12] {
        let mut row = Vec::new();
        for e_s in TRAINED_EXP_E_S_RANGE {
            let (exp, _) = crate::tables_attn::exp_member(e_s, 128, f_e);
            let mut col: Vec<i64> = std::iter::once(0).chain(exp.iter().copied()).collect();
            col.sort_unstable();
            col.dedup();
            row.push((e_s, col.len()));
            assert_eq!(dd_e_column_of(&exp, DD_CAP).is_ok(), col.len() <= DD_CAP, "f_e {f_e} e_s {e_s}");
        }
        rows.push((f_e, row));
    }
    for (f_e, row) in &rows {
        eprintln!("R12 N_COL hd128 f_e {f_e}: {}", row.iter().map(|(e, n)| format!("e_s {e}: {n}{}", if *n > DD_CAP { " (over cap)" } else { "" })).collect::<Vec<_>>().join(", "));
    }
    // the current exports' e_s (1..4 at f_e 9) fit cap 32
    for (e_s, n) in &rows[0].1 {
        if (1..=4).contains(e_s) {
            assert!(*n <= DD_CAP, "e_s {e_s}: {n}");
        }
    }
}

/// **The counted soundness floor of a blocks-only run** (the token lane's
/// MEMO_G02 accounting, `token_io/run.rs::whole_run_of`, restricted to the
/// `L` blocks and `L + 1` boundaries, plus D30 condition (5)'s dictionary
/// term at a DD profile): column test per opening `(1 - delta/3)^Q`, the
/// LogUp term `(N + 3 r - 1) / |F_p^2|` per block, and the explicit PCS-field
/// and sumcheck bound. [COUNTED; the D24 review re-derives it.]
fn blocks_whole_run_floor(sh: &Shape, l: usize) -> (f64, u32) {
    let col = |msg: usize, enc: usize, q: usize| -> f64 { q as f64 * (1.0 - (1.0 - msg as f64 / enc as f64) / 3.0).log2() };
    let hiding = |log_n: usize, rate: usize, q: usize| col((1usize << log_n) + q, (1usize << log_n) * rate, q);
    let mask = col(1024, 4096, crate::zk::MASK_Q);
    let mut opens: Vec<f64> = Vec::new();
    for _ in 0..l {
        opens.push(hiding(sh.log_cols, sh.inv_rate, sh.opened_cols));
        opens.push(hiding(sh.log_cols, sh.inv_rate, sh.opened_cols));
        opens.push(mask);
    }
    for _ in 0..=l {
        opens.push(hiding(sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols));
    }
    let u8: f64 = sh.lookup_doms().iter().map(|d| (sh.lookups_per_position(*d) * sh.size(*d)) as f64).sum();
    let mut n = u8 + sh.size(Dom::S) as f64 + sh.size(Dom::F) as f64 + 3.0 * 768.0 - 1.0;
    if sh.dd_cap > 0 {
        // the tuple lookups of every score entry, and D30 (5)'s 4 rows cap
        n += sh.size(Dom::S) as f64 + 4.0 * (sh.q_heads * sh.tokens * sh.dd_cap) as f64;
    }
    let field = 2.0 * ((u64::MAX - (1u64 << 32) + 2) as f64).log2();
    let column: f64 = opens.iter().map(|x| x.exp2()).sum();
    let logup = l as f64 * n * (-field).exp2();
    let omitted = opens.len() as f64 * (-113.0f64).exp2() + l as f64 * (-117.2f64).exp2();
    let total = (column + logup + omitted).log2();
    (total, (-total).floor() as u32)
}

#[test]
fn counted_soundness_floors() {
    let mut out = Vec::new();
    for (name, sh, l) in [
        ("Shieldstral T128", shieldstral(128, false), 26usize),
        ("Shieldstral T256", shieldstral(256, false), 26),
        ("Shieldstral T128 DD", shieldstral(128, true), 26),
        ("Shieldstral T256 DD", shieldstral(256, true), 26),
        ("Llama-3-8B T128 (reference)", super::trained_calib_tests::llama3_8b_at(128), 32),
    ] {
        let (t, f) = blocks_whole_run_floor(&sh, l);
        out.push(format!("{name} (L = {l}): whole run 2^{t:.2} -> floor {f} bits"));
        assert!(f >= 95, "{name}: the blocks-only floor {f} is below D27's 95 bits");
    }
    for r in &out {
        eprintln!("R12 FLOOR {r}");
    }
}
