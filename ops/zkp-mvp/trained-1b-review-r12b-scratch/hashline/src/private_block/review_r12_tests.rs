//! **D24 REVIEW ROUND 10 (independent review lane, 2026-10-26): the native
//! R12 tree — Shieldstral-1.0-3B's decoupled head_dim (F2), YaRN RoPE (F1)
//! and tied embedding (F3) on top of R9.** TEST CODE ONLY, in the reviewer's
//! scratch copy; public synthetic data only. Not a privacy review.
//!
//! * A: every existing registered profile keeps `q_pad == d_pad`,
//!   `q_width == width`, the frozen RoPE generator, no transform, no tie;
//! * B: the Rust YaRN tables equal the reviewer's own binary64 transcription
//!   of transformers main (r12/r12_yarn_check.json) at T128 / T256 / T512 /
//!   T2048, and every near-miss transform differs; the export door refuses a
//!   declared transform other than the pin;
//! * C: `--rope-from-export` proves the export's tables while the statement
//!   still records the pinned base and transform (finding R12-F2);
//! * D: the tied record binds the DECLARED source tensor and the digests of
//!   whatever table files the export carries — arbitrary bytes, any size, a
//!   swapped head — not their derivation from the tensor (finding R12-F1);
//! * E: pad lanes at the decoupled rung (model axis 192 -> 256, hidden 384 ->
//!   512): a nonzero padded lane of norm_a's output, of the FFN product and of
//!   the block output, each otherwise invisible (zero padded weights, gated
//!   clauses, every lookup hits), is rejected;
//! * F: the LogUp term per block and per 26-block run at Shieldstral T128 /
//!   T256 and T512 (counted), DD and non-DD, from the built lookup lists;
//! * G: a Shieldstral shape with any geometry field edited is refused by the
//!   run-profile registry (CS-7), and the shapes carry their pins.

use super::layout::*;
use super::shape::*;
use super::trained_block::*;
use super::*;

const P_GOLDILOCKS: f64 = 18_446_744_069_414_584_321.0;

fn table_sha(c: &[i64], s: &[i64]) -> String {
    use sha2::{Digest as _, Sha256};
    let mut h = Sha256::new();
    for v in c.iter().chain(s.iter()) {
        h.update(v.to_le_bytes());
    }
    h.finalize().iter().map(|b| format!("{b:02x}")).collect()
}

fn shield_cal() -> NormCalibration {
    super::r12_tests::shieldstral_calibration(11_000, 11_500)
}

// ------------------------------------------------------------------ A

/// **A: the existing profiles are untouched by F1–F3.**
#[test]
fn review_r12_a_existing_profiles_keep_their_axes_tables_and_records() {
    let tl = super::trained_calib_tests::pg_calibration();
    let l8 = super::trained_calib_tests::llama3_8b_calibration();
    let rc = super::trained_calib_tests::rung_tc_calibration();
    let mut shapes = vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::m125()];
    shapes.extend([
        Shape::rung_tc(&rc).unwrap(),
        Shape::rung_dd(&rc).unwrap(),
        Shape::tinyllama_trained(32, &tl, 9).unwrap(),
        Shape::tinyllama_trained(64, &tl, 9).unwrap(),
        Shape::tinyllama_trained(128, &tl, 9).unwrap(),
        Shape::llama3_8b_trained(32, &l8, 9).unwrap(),
        Shape::llama3_8b_trained(64, &l8, 9).unwrap(),
        Shape::llama3_8b_trained(128, &l8, 9).unwrap(),
        Shape::tinyllama_t128_trained_dd(&tl, 9).unwrap(),
        Shape::llama3_8b_t128_trained_dd(&l8, 9).unwrap(),
    ]);
    for s in &shapes {
        assert_eq!((s.q_pad(), s.q_width()), (s.d_pad, s.width), "{}: the query axis moved", s.profile);
        assert_eq!(s.size(Dom::Q), s.size(Dom::D), "{}", s.profile);
        assert!(super::trained_statement::tied_tensor_for_profile(s.profile).is_none());
        if s.trained_calibration {
            assert_eq!(trained_rope_scaling(s.profile), Some(super::rope::RopeScaling::None), "{}", s.profile);
            let th = trained_rope_theta(s.profile).unwrap();
            assert_eq!(rope_tables_for(s, th).unwrap(), crate::tables_attn::rope_tables_generate(s.tokens, s.head_dim, th, F_RO), "{}: the RoPE generator moved", s.profile);
        }
    }
    eprintln!("REVIEW-R12 A: {} existing shapes keep q_pad == d_pad, q_width == width, the frozen RoPE generator, no transform, no tie", shapes.len());
}

// ------------------------------------------------------------------ B

/// my Python digests (r12/r12_yarn_check.json, binary64 transcription of
/// transformers main `_compute_yarn_parameters`, rounded half up at 2^7)
const MY_YARN: [(usize, &str); 4] = [
    (128, "544dd35e4a11e9ee0ca053befe8b72ed521bce67a9c074eeeb1f3e62ef66683a"),
    (256, "bb5397c67f0997fe1732d2af4189c110ca025fb6a2d37894fb7274118ec75b4f"),
    (512, "261b32b8e461fa3866ee98455b3a4b39db51d846833115f525809c8375e12a5f"),
    (2048, "5e370a8c31a6b59c515171aa2293ed19c5115371daac7eda8e94faf44e94c255"),
];

/// **B: the YaRN tables, and the door on the declared transform.**
#[test]
fn review_r12_b_yarn_tables_equal_my_reference_and_the_door_refuses_other_transforms() {
    use super::rope::{rope_tables, RopeScaling};
    let pin = RopeScaling::shieldstral();
    for (t, want) in MY_YARN {
        let (c, s) = rope_tables(t, 128, SHIELDSTRAL_ROPE_THETA, &pin, F_RO).unwrap();
        assert_eq!(table_sha(&c, &s), want, "T{t}: the Rust YaRN table is not my reference");
    }
    for (t, dd) in [(128usize, false), (128, true), (256, false), (256, true)] {
        let sh = super::r12_tests::shieldstral(t, dd);
        let (c, s) = rope_tables_for(&sh, trained_rope_theta(sh.profile).unwrap()).unwrap();
        let want = MY_YARN.iter().find(|(tt, _)| *tt == t).unwrap().1;
        assert_eq!(table_sha(&c, &s), want, "{}: the profile's generator is not my reference", sh.profile);
        assert_eq!(trained_rope_scaling(sh.profile), Some(pin));
        assert_eq!(trained_rope_theta(sh.profile), Some(1_000_000.0));
    }
    // near misses: each gives another table (the pin matters)
    let RopeScaling::Yarn { factor, original_max, beta_fast, beta_slow, mscale, mscale_all_dim, .. } = pin else { panic!() };
    let misses = [
        ("no truncation", RopeScaling::Yarn { factor, original_max, beta_fast, beta_slow, mscale, mscale_all_dim, truncate: false }),
        ("4.48.1's correction range (max_pos 262144)", RopeScaling::Yarn { factor, original_max: 262_144, beta_fast, beta_slow, mscale, mscale_all_dim, truncate: true }),
        ("factor 8", RopeScaling::Yarn { factor: 8.0, original_max, beta_fast, beta_slow, mscale, mscale_all_dim, truncate: true }),
        ("unscaled", RopeScaling::None),
    ];
    let (c0, s0) = rope_tables(512, 128, 1e6, &pin, F_RO).unwrap();
    for (name, m) in misses {
        let (c, s) = rope_tables(512, 128, 1e6, &m, F_RO).unwrap();
        let moved = c.iter().zip(&c0).chain(s.iter().zip(&s0)).filter(|(a, b)| a != b).count();
        assert!(moved > 0, "{name}: the same table as the pin");
        eprintln!("REVIEW-R12 B near miss {name}: {moved} of {} T512 entries differ", 2 * c0.len());
    }
    // 4.48.1's default attention factor (0.1 ln 16 + 1 = 1.277) is refused
    let m448 = RopeScaling::Yarn { factor, original_max, beta_fast, beta_slow, mscale: 1.0, mscale_all_dim: 0.0, truncate: true };
    assert!(m448.check().unwrap_err().contains("attention factor"), "a 1.277 attention factor was admitted");
    // the export door: Shieldstral's config.json keys parse to the pin; every
    // other declaration differs from the pin (TrainedExport::load refuses it)
    let cfg = super::trained_block::parse_json(br#"{"beta_fast": 32.0, "beta_slow": 1.0, "factor": 16.0, "llama_4_scaling_beta": 0.1, "mscale": 1.0, "mscale_all_dim": 1.0, "original_max_position_embeddings": 16384, "rope_theta": 1000000.0, "rope_type": "yarn", "type": "yarn"}"#).unwrap();
    assert_eq!(rope_scaling_of(Some(&cfg)).unwrap(), pin, "Shieldstral's own config does not parse to the pin");
    for (name, json) in [
        ("truncate false", r#"{"rope_type": "yarn", "factor": 16.0, "original_max_position_embeddings": 16384, "beta_fast": 32.0, "beta_slow": 1.0, "mscale": 1.0, "mscale_all_dim": 1.0, "truncate": false}"#),
        ("original 262144", r#"{"rope_type": "yarn", "factor": 16.0, "original_max_position_embeddings": 262144, "beta_fast": 32.0, "beta_slow": 1.0, "mscale": 1.0, "mscale_all_dim": 1.0}"#),
        ("default", r#"{"rope_type": "default"}"#),
    ] {
        let j = super::trained_block::parse_json(json.as_bytes()).unwrap();
        let r = rope_scaling_of(Some(&j)).unwrap();
        assert_ne!(r, Geometry::Shieldstral(128).rope_scaling(), "{name}: equals the pin");
    }
    assert_eq!(rope_scaling_of(None).unwrap(), super::rope::RopeScaling::None);
    assert_ne!(super::rope::RopeScaling::None, Geometry::ShieldstralDd(256).rope_scaling(), "an absent declaration would pass at Shieldstral");
    let bad = super::trained_block::parse_json(br#"{"rope_type": "yarn", "factor": 16.0, "original_max_position_embeddings": 16384, "beta_fast": 32.0, "beta_slow": 1.0, "mscale": 1.0, "mscale_all_dim": 0.0}"#).unwrap();
    assert!(rope_scaling_of(Some(&bad)).is_err(), "a 1.277 attention factor was parsed");
    eprintln!("REVIEW-R12 B: Rust YaRN tables = my reference at T128/256/512/2048 and at the four profiles; near misses differ; the door refuses other declarations");
}

// ------------------------------------------------------------------ C

/// **C: `--rope-from-export`.** With the opt-in, the loader proves the
/// EXPORT's RoPE tables when they differ from the profile's generator, and
/// the trained statement still records the pinned base and transform (the
/// tables enter only through the block digest).
#[test]
fn review_r12_c_rope_from_export_proves_other_tables_under_the_pinned_record() {
    use super::trained_block_tests::{base_dir, write_export, Fault};
    let dir = base_dir("review-r12-rope");
    let (vdir, _) = write_export(&dir, "rope-off", &Fault { rope_offset: true, ..Default::default() });
    let ex = TrainedExport::load(&vdir).expect("the export loads");
    let c = ex.run_constants(&[0]).unwrap();
    let sh = ex.shape_for(&c).unwrap();
    let e = ex.load_layer(&sh, &c, 0, false).err().expect("tables off the generator loaded without the opt-in");
    assert!(e.contains("--rope-from-export"), "{e}");
    let layer = ex.load_layer(&sh, &c, 0, true).expect("the opt-in loads the export's tables");
    assert!(layer.rope_note.contains("EXPORT's tables"), "{}", layer.rope_note);
    let (gc, _) = rope_tables_for(&sh, c.rope_theta).unwrap();
    assert_ne!(layer.blk.attention().rope_cos, gc, "the proven tables are the generator's");
    let st = ex.statement(&sh, &c, &[&layer]).expect("the statement builds");
    assert_eq!(st.calibration.rope_theta_f64_bits, 10_000f64.to_bits());
    assert_eq!(st.calibration.rope_scaling, super::rope::RopeScaling::None.encode());
    eprintln!("REVIEW-R12 C: --rope-from-export proves tables off the generator ({}); the statement records base {} and transform none", layer.rope_note, f64::from_bits(st.calibration.rope_theta_f64_bits));
}

// ------------------------------------------------------------------ D

/// **D: the tied record binds declarations, not derivation.** Arbitrary
/// bytes of any length serve as the embedding and head tables, and a head
/// table swapped for different bytes (its manifest digest updated) loads
/// too: the record's tensor digest is the pin either way.
#[test]
fn review_r12_d_the_tied_record_binds_declared_sources_not_derived_tables() {
    use super::trained_block::{hex, parse_json, sha256, tied_of};
    use super::trained_statement::{tied_tensor_for_profile, ModelSource};
    let (name, digest) = tied_tensor_for_profile(SHIELDSTRAL_T128_TRAINED_PROFILE).unwrap();
    let root = super::trained_block_tests::base_dir("review-r12-tied");
    let td = root.join("token_io");
    std::fs::create_dir_all(&td).unwrap();
    let dg = hex(&digest);
    let write = |emb: &[u8], head: &[u8], mult: &[u8]| {
        std::fs::write(td.join("embedding_int16.bin"), emb).unwrap();
        std::fs::write(td.join("head_int8_perrow.bin"), head).unwrap();
        std::fs::write(td.join("head_mult12.bin"), mult).unwrap();
        std::fs::write(td.join("token_io.json"), format!(r#"{{"embedding_table": {{"file": "embedding_int16.bin", "sha256": "{}", "source_tensor": {{"name": "{name}", "sha256": "{dg}"}}}}}}"#, hex(&sha256(emb)))).unwrap();
        std::fs::write(td.join("head_manifest.json"), format!(r#"{{"head_int8_perrow.bin": {{"sha256": "{}"}}, "head_mult12.bin": {{"sha256": "{}"}}, "source_tensor": {{"name": "{name}", "sha256": "{dg}"}}}}"#, hex(&sha256(head)), hex(&sha256(mult)))).unwrap();
    };
    let profile = parse_json(format!(r#"{{"tied_embeddings": {{"tensor": "{name}", "sha256": "{dg}"}}}}"#).as_bytes()).unwrap();
    let src = ModelSource::shieldstral_1_0_3b();
    // 131072 x 3072 int16 would be 805,306,368 B; these are 7, 5 and 3 bytes
    write(b"not emb", b"head1", b"mlt");
    let a = tied_of(&root, &profile, Geometry::Shieldstral(128), &src).expect("arbitrary tables").expect("a record");
    // the head swapped for other bytes, its manifest updated
    write(b"not emb", b"HEAD2", b"mlt");
    let b = tied_of(&root, &profile, Geometry::ShieldstralDd(128), &src).expect("a swapped head").expect("a record");
    assert_eq!((a.tensor_sha256, b.tensor_sha256), (digest, digest));
    assert_eq!(a.embedding_table_sha256, b.embedding_table_sha256);
    assert_ne!(a.head_table_sha256, b.head_table_sha256);
    let _ = std::fs::remove_dir_all(&root);
    eprintln!("REVIEW-R12 D: tied_of accepted 7/5/3-byte tables and a swapped head under the pinned tensor {name} ({dg}); only the record's table digests change");
}

// ------------------------------------------------------------------ E

fn hd_block() -> (Shape, BlockPublic, super::witness::Witness) {
    let sh = super::r12_tests::rung_hd();
    use super::trained_calib_tests::{Bands, TRAINED_BANDS};
    for b in [TRAINED_BANDS, Bands { attn: 6, gate: 8, ..TRAINED_BANDS }, Bands { attn: 4, gate: 8, down: 1, ..TRAINED_BANDS }, Bands { attn: 3, gate: 4, down: 1, xmag: 3_000, ..TRAINED_BANDS }] {
        let (w, input) = super::trained_calib_tests::trained_dense_words(&sh, b);
        let (cos, sin) = rope_tables_for(&sh, trained_rope_theta(sh.profile).unwrap_or(10000.0)).unwrap();
        let (exp, _) = crate::tables_attn::exp_member(2, sh.head_dim, sh.f_e);
        let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).unwrap();
        let aw = super::grow_tests::pad_attention_weights(&sh, &w[0], &w[1], &w[2], &w[3], &w[4]);
        let fw = super::grow_tests::pad_ff_weights(&sh, &w[5], &w[6], &w[7], &w[8]);
        let public = AttentionPublic::new_shaped(&sh, &aw[0], &aw[1], &aw[2], &aw[3], &aw[4], &cos, &sin, &exp).unwrap();
        let ff = FeedForwardPublic::new_shaped(&sh, &fw[0], &fw[1], &fw[2], &fw[3], &act).unwrap();
        let blk = BlockPublic::new(public, ff);
        if let Ok(wit) = super::witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input) {
            return (sh, blk, wit);
        }
    }
    panic!("no admissible dense block at the decoupled rung");
}

/// **E: no unconstrained pad lane.** Each attack sets ONE padded lane that
/// nothing downstream reads (the padded weight rows / columns are zero, the
/// value clauses are gated off the pad) and keeps every lookup hitting; the
/// verifier must reject.
#[test]
fn review_r12_e_a_nonzero_pad_lane_is_rejected_at_the_decoupled_rung() {
    let (sh, blk, honest) = hd_block();
    assert!(sh.pads(Dom::D) && sh.pads(Dom::F) && sh.q_pad() != sh.d_pad, "the rung pads the model and hidden axes and decouples the query axis");
    let ids = Ids::new(&sh).unwrap();
    let lay = Layout::for_shape(&sh).unwrap();
    let one = super::trained_calib_tests::prove_one_bound(&sh, &blk, super::witness::Witness { planes: honest.planes.clone() }).expect("the honest block proves");
    super::trained_calib_tests::verify_one_bound(&sh, &blk, &one.expected.to_bytes(), &one.seg).expect("the honest block verifies");
    let (t, i_d, i_f) = (sh.tokens / 2, sh.width + 7, sh.hidden + 11);
    let cases: [(&str, usize, usize, i64); 3] = [
        ("norm_a output Y at a padded model lane", ids.at(A_Y), t * sh.d_pad + i_d, 5),
        ("FFN product H16 at a padded hidden lane", ids.at(A_H16), t * sh.f_pad + i_f, 1),
        ("block output X2 at a padded model lane", ids.at(A_X2), t * sh.d_pad + i_d, 3),
    ];
    for (name, plane, ix, v) in cases {
        let mut w = super::witness::Witness { planes: honest.planes.clone() };
        assert_eq!(w.planes[plane][ix], 0, "{name}: the honest pad is not zero");
        w.planes[plane][ix] = v;
        super::protocol::check_lookup_misses(&sh, &lay, &blk, &w).unwrap_or_else(|e| panic!("{name}: a lookup misses, so the attack is not pad-only: {e}"));
        let _cheat = super::protocol::CheatingProver::on();
        let p = super::trained_calib_tests::prove_one_bound(&sh, &blk, w).unwrap_or_else(|e| panic!("{name}: the prover produced no receipt: {e}"));
        let e = super::trained_calib_tests::verify_one_bound(&sh, &blk, &p.expected.to_bytes(), &p.seg).expect_err(&format!("{name}: a nonzero pad lane VERIFIED"));
        eprintln!("REVIEW-R12 E {name}: rejected: {}", e.chars().take(160).collect::<String>());
    }
}

// ------------------------------------------------------------------ F

fn logup_n(sh: &Shape) -> (u64, u64, u64) {
    let lay = Layout::for_shape(sh).unwrap();
    let u8: u64 = lay.lookup_doms().iter().map(|d| (lay.lookups(*d).len() * sh.size(*d)) as u64).sum();
    assert_eq!(u8 as usize, sh.totals().u8_lookups, "{}: the built lookup list and the counter disagree", sh.profile);
    let pairs = (sh.size(Dom::S) + sh.size(Dom::F)) as u64;
    let tuples = if sh.dd_cap > 0 { sh.size(Dom::S) as u64 } else { 0 };
    let t_dd = if sh.dd_cap > 0 { sh.size(Dom::Dd) as u64 } else { 0 };
    (u8 + pairs + tuples, t_dd, u8)
}

/// **F: the LogUp term at Shieldstral** — per block (N + 2303 + 4 T_DD)/p^2,
/// per 26-block run the union; and the counted refusal distances of D30 (4)
/// and D34 for a 26-block run.
#[test]
fn review_r12_f_the_logup_term_and_refusal_distances_at_shieldstral() {
    let cal = shield_cal();
    let f = P_GOLDILOCKS * P_GOLDILOCKS;
    let l = 26f64;
    for (t, lc) in [(128usize, 14usize), (256, 15), (512, 15)] {
        for dd in [false, true] {
            let sh = if t == 512 { Shape::shieldstral_at(512, lc, dd, &cal, 9).unwrap() } else { super::r12_tests::shieldstral(t, dd) };
            assert_eq!(sh.log_cols, lc);
            let (n, t_dd, u8) = logup_n(&sh);
            let per = (n as f64 + 2303.0 + 4.0 * t_dd as f64) / f;
            let rows_cap = if dd { (sh.q_heads * t * DD_CAP) as f64 } else { 0.0 };
            // D34 (token stages): 2 (768 L + T + 256) / p^2, T the prompt's
            // own rows; D30 (4) (DD): + 2 L rows cap / p^2
            let refusal = 2.0 * (768.0 * l + t as f64 + 256.0 + l * rows_cap) / f;
            eprintln!(
                "REVIEW-R12 F Shieldstral T{t}{} (2^{lc}{}): U8 {u8} N {n} T_DD {t_dd}: per block 2^{:.2}, per 26-block run 2^{:.2} ({:.2} bits); refusal distance (D34 + D30(4)) 2^{:.2}",
                if dd { " DD" } else { "" },
                if t == 512 { ", counted only" } else { "" },
                per.log2(),
                (per * l).log2(),
                -(per * l).log2(),
                refusal.log2()
            );
            assert!((per * l).log2() < -95.0, "T{t} dd {dd}: the 26-block run's lookup term is above 2^-95");
        }
    }
}

// ------------------------------------------------------------------ G

/// **G: the Shieldstral geometry is the profile's, not the prover's.**
#[test]
fn review_r12_g_an_edited_shieldstral_shape_is_refused_by_the_registry() {
    let mut n = 0;
    for (t, dd) in [(128usize, false), (128, true), (256, false), (256, true)] {
        let sh = super::r12_tests::shieldstral(t, dd);
        assert_eq!((sh.width, sh.hidden, sh.q_heads, sh.head_dim, sh.kv_heads, sh.h_pad), (3072, 9216, 32, 128, 8, 32), "{}", sh.profile);
        assert_eq!((sh.q_width(), sh.q_pad(), sh.d_pad, sh.f_pad, sh.t_pad), (4096, 4096, 4096, 16384, t), "{}", sh.profile);
        super::trained_calib_tests::run_shape_for_checked(&sh, 26).unwrap_or_else(|e| panic!("{}: {e}", sh.profile));
        assert!(super::trained_statement::tied_tensor_for_profile(sh.profile).is_some());
        assert_eq!(super::trained_statement::ModelSource::pinned_for_profile(sh.profile).unwrap().repo, "mistralai/Shieldstral-1.0-3B");
        let edits: Vec<(&str, Box<dyn Fn(&mut Shape)>)> = vec![
            ("head_dim 64", Box::new(|s: &mut Shape| s.head_dim = 64)),
            ("q_heads 24", Box::new(|s: &mut Shape| s.q_heads = 24)),
            ("h_pad 16", Box::new(|s: &mut Shape| s.h_pad = 16)),
            ("kv_heads 4", Box::new(|s: &mut Shape| s.kv_heads = 4)),
            ("width 4096", Box::new(|s: &mut Shape| s.width = 4096)),
            ("hidden 14336", Box::new(|s: &mut Shape| s.hidden = 14336)),
            ("d_pad 8192", Box::new(|s: &mut Shape| s.d_pad = 8192)),
        ];
        for (name, edit) in &edits {
            let mut s = sh.clone();
            edit(&mut s);
            let e = super::trained_calib_tests::run_shape_for_checked(&s, 26).err().unwrap_or_else(|| panic!("{}: {name} was taken by the run registry", sh.profile));
            assert!(e.contains("CS-7"), "{}: {name}: {e}", sh.profile);
            n += 1;
        }
    }
    eprintln!("REVIEW-R12 G: {n} edited Shieldstral shapes refused by CS-7");
}

// ------------------------------------------------------------------ H

/// **H: the pad indicators the argument uses are exactly the true lanes** —
/// at Shieldstral (model 3072 of 4096: the closed form `1 - b10 b11`; hidden
/// 9216 of 16384: the explicit table) and at the decoupled rung, built here
/// from the shape's widths alone, never from the builder.
#[test]
fn review_r12_h_the_pad_indicators_are_the_true_lanes() {
    let mut shapes = vec![super::r12_tests::rung_hd()];
    for (t, dd) in [(128usize, false), (128, true), (256, false)] {
        shapes.push(super::r12_tests::shieldstral(t, dd));
    }
    for sh in &shapes {
        let mine_d: Vec<i64> = (0..sh.size(Dom::D)).map(|x| i64::from(x / sh.d_pad < sh.tokens && x % sh.d_pad < sh.width)).collect();
        let mine_f: Vec<i64> = (0..sh.size(Dom::F)).map(|x| i64::from(x / sh.f_pad < sh.tokens && x % sh.f_pad < sh.hidden)).collect();
        assert_eq!(super::pad::indicator_table(sh, Dom::D), mine_d, "{}: supp_D is not the true model lanes", sh.profile);
        assert_eq!(super::pad::indicator_table(sh, Dom::F), mine_f, "{}: supp_F is not the true hidden lanes", sh.profile);
        let q = super::pad::indicator_table(sh, Dom::Q);
        assert_eq!(q.iter().sum::<i64>() as usize, sh.tokens * sh.q_heads * sh.head_dim, "{}: supp_Q counts the wrong lanes", sh.profile);
        let cf = super::pad::closed_form_indicator(sh, Dom::D).map(|(_, f)| format!("{f:?}")).unwrap_or_else(|| "table".into());
        eprintln!(
            "REVIEW-R12 H {}: supp_D = {} of {} lanes per token ({cf}), supp_F = {} of {}, supp_Q = {} lanes",
            sh.profile,
            sh.width,
            sh.d_pad,
            sh.hidden,
            sh.f_pad,
            q.iter().sum::<i64>()
        );
    }
}

// ------------------------------------------------------------------ D2

/// **D2: the token-table hash reads are unbounded and follow links**
/// (`trained_block.rs` `sha256_file`): a table that is a symbolic link to a
/// file elsewhere is hashed through the link, and a table that is a FIFO
/// blocks the loader until some writer opens it (here the test opens and
/// closes one after 2 s; a link to /dev/zero would never return). The block
/// arrays have bounded reads since R5b (review r4_A); these do not.
#[test]
fn review_r12_d2_the_token_table_reads_follow_links_and_block_on_a_fifo() {
    use super::trained_block::{hex, parse_json, sha256, tied_of};
    use super::trained_statement::{tied_tensor_for_profile, ModelSource};
    let (name, digest) = tied_tensor_for_profile(SHIELDSTRAL_T128_TRAINED_PROFILE).unwrap();
    let root = super::trained_block_tests::base_dir("review-r12-tied-io");
    let td = root.join("token_io");
    std::fs::create_dir_all(&td).unwrap();
    let elsewhere = root.join("elsewhere.bin");
    std::fs::write(&elsewhere, b"outside token_io").unwrap();
    let dg = hex(&digest);
    let (emb, head, mult): (&[u8], &[u8], &[u8]) = (b"e", b"h", b"outside token_io");
    std::fs::write(td.join("embedding_int16.bin"), emb).unwrap();
    std::fs::write(td.join("head_int8_perrow.bin"), head).unwrap();
    std::os::unix::fs::symlink(&elsewhere, td.join("head_mult12.bin")).unwrap();
    std::fs::write(td.join("token_io.json"), format!(r#"{{"embedding_table": {{"file": "embedding_int16.bin", "sha256": "{}", "source_tensor": {{"name": "{name}", "sha256": "{dg}"}}}}}}"#, hex(&sha256(emb)))).unwrap();
    std::fs::write(td.join("head_manifest.json"), format!(r#"{{"head_int8_perrow.bin": {{"sha256": "{}"}}, "head_mult12.bin": {{"sha256": "{}"}}, "source_tensor": {{"name": "{name}", "sha256": "{dg}"}}}}"#, hex(&sha256(head)), hex(&sha256(mult)))).unwrap();
    let pj = format!(r#"{{"tied_embeddings": {{"tensor": "{name}", "sha256": "{dg}"}}}}"#);
    let profile = parse_json(pj.as_bytes()).unwrap();
    tied_of(&root, &profile, Geometry::Shieldstral(128), &ModelSource::shieldstral_1_0_3b()).expect("a table that is a link to a file outside token_io/ was refused");
    // a FIFO in place of the multiplier table
    std::fs::remove_file(td.join("head_mult12.bin")).unwrap();
    let fifo = td.join("head_mult12.bin");
    assert!(std::process::Command::new("mkfifo").arg(&fifo).status().map(|s| s.success()).unwrap_or(false), "mkfifo");
    let (r2, pj2) = (root.clone(), pj.clone());
    let h = std::thread::spawn(move || {
        let p = parse_json(pj2.as_bytes()).unwrap();
        tied_of(&r2, &p, Geometry::Shieldstral(128), &ModelSource::shieldstral_1_0_3b()).map(|_| ())
    });
    std::thread::sleep(std::time::Duration::from_secs(2));
    let blocked = !h.is_finished();
    // release it: a writer opens and closes the FIFO (EOF), the digest misses
    // (only while the loader is blocked in it: with no reader the open would wait)
    if blocked {
        drop(std::fs::OpenOptions::new().write(true).open(&fifo).unwrap());
    }
    let r = h.join().unwrap();
    assert!(blocked, "the loader did not block on a FIFO");
    assert!(r.is_err(), "an empty FIFO matched the manifest");
    let _ = std::fs::remove_dir_all(&root);
    eprintln!("REVIEW-R12 D2: a linked table outside token_io/ is hashed through the link; a FIFO table blocked the loader for 2 s until released ({})", r.unwrap_err().chars().take(120).collect::<String>());
}
