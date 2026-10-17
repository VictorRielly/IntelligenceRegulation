//! **THE D24 REVIEW'S FINDINGS AS PERMANENT TESTS** (independent adversarial
//! review of the trained profile, 2026-10-17; evidence
//! `results/zk60_d24_review_20261017/`). TEST CODE ONLY. Ported from the
//! reviewer's scratch module (`ops/zkp-mvp/trained-1b-review-r1-scratch/
//! hashline/src/private_block/review_d24_tests.rs`) and turned around: each
//! test now asserts the FIXED behaviour.
//!
//! * A (F-1): the trained door admits `f_e` in `9..=16` and nothing else.
//! * H (F-5): `Layout::for_shape` re-checks the whole class of a trained shape.
//! * B (F-2): an unbound run at a trained-calibration shape is refused.
//! * C (F-3): `new_bound` refuses a frozen profile; the trained TinyLlama
//!   profile takes the pinned checkpoint only.
//! * D (F-4): the statement identity does not depend on the export's
//!   directory name.
//! * E (F-1): the reviewer's `f_e = 50` export is refused AT THE DOOR by both
//!   CLI sides, and the field-wrapping softmax forgery cannot reach a
//!   transcript even through a shape edited after the door.
//! * F (control): a naive softmax quotient forgery (`p + 1`) is rejected at
//!   slot 17, at the rung (fast) and at the TinyLlama profile (heavy).
//! * G (control): the norm class corner proves and its neighbours refuse.
//!
//! The forge hook is THREAD-LOCAL, so a forging test cannot touch another
//! test's witness running in parallel (the reviewer's was a global).

use super::layout::*;
use super::shape::{NormCalibration, Shape, TRAINED_F_E_RANGE};
use super::trained_calib_tests::{prove_one_bound, rung_tc_calibration, verify_one_bound};
use super::witness;
use super::*;
use std::cell::Cell;

const P: i128 = 0xffff_ffff_0000_0001;

/// `(head, token, source token, delta, k)`: replace the quotient `p` at that
/// softmax position by `p + delta` and the remainder by `rho - delta*Sum + k*P`
/// (with `naive`, the remainder and complement are left as they are)
#[derive(Clone, Copy, Debug)]
pub(super) struct Forge {
    pub h: usize,
    pub t: usize,
    pub j: usize,
    pub delta: i64,
    pub k: i128,
    pub naive: bool,
}

thread_local! {
    static FORGE: Cell<Option<Forge>> = const { Cell::new(None) };
    static FORGED: Cell<usize> = const { Cell::new(0) };
}

pub(super) fn set_forge(v: Option<Forge>) {
    FORGE.with(|f| f.set(v));
    FORGED.with(|n| n.set(0));
}

pub(super) fn forged_count() -> usize {
    FORGED.with(|n| n.get())
}

/// the hook `witness::build_shaped` calls (test builds only); identity when
/// no forgery is set on this thread. A wrapping forgery whose remainder would
/// leave `[0, Sum)` is NOT applied (and not counted): at an admitted `f_e`
/// none exists.
pub(super) fn forge_softmax(h: usize, t: usize, j: usize, total: i64, q: i64, rho: i64, sigma: i64) -> (i64, i64, i64) {
    match FORGE.with(|f| f.get()) {
        Some(f) if f.h == h && f.t == t && f.j == j => {
            if f.naive {
                FORGED.with(|n| n.set(n.get() + 1));
                return (q + f.delta, rho, sigma);
            }
            let q2 = q as i128 + f.delta as i128;
            let r2 = rho as i128 - f.delta as i128 * total as i128 + f.k * P;
            if !(0..total as i128).contains(&r2) {
                return (q, rho, sigma);
            }
            let s2 = total as i128 - 1 - r2;
            let c2 = (q as i128 * total as i128 + rho as i128) - q2 * total as i128 - r2;
            assert_eq!(c2 % P, 0);
            FORGED.with(|n| n.set(n.get() + 1));
            (q2 as i64, r2 as i64, s2 as i64)
        }
        _ => (q, rho, sigma),
    }
}

fn pg() -> NormCalibration {
    super::trained_calib_tests::pg_calibration()
}

// ------------------------------------------------------------------ A

/// **F-1: the declared `f_e` class at the trained TinyLlama profile is
/// `9..=16`, and nothing else constructs** (the reviewer measured 4..=62
/// admitted, 63/64 panicking in the exp generator). Every admitted value has
/// a layout, an exp table and a softmax window of at most three limbs; the
/// T-dependence of the three-limb rule is checked on the class function.
#[test]
fn review_a_the_trained_door_admits_f_e_9_to_16_and_nothing_else() {
    let cal = pg();
    let mut admitted = Vec::new();
    for f_e in 0..=64u32 {
        let r = std::panic::catch_unwind(|| Shape::tinyllama_t32_trained(&cal, f_e));
        match r {
            Ok(Ok(sh)) => {
                Layout::for_shape(&sh).expect("an admitted f_e has a layout");
                assert!(sh.wrho_s <= 24 && sh.limbs_sigma_s() <= 3, "f_e {f_e}: softmax window {}", sh.wrho_s);
                let (exp, _) = crate::tables_attn::exp_member(0, sh.head_dim, f_e);
                assert_eq!(exp[0], 1i64 << f_e);
                admitted.push(f_e);
            }
            Ok(Err(e)) => {
                assert!(e.contains("f_e") && e.contains("declared class"), "f_e {f_e}: refused for another reason: {e}");
            }
            Err(_) => panic!("f_e {f_e}: the door PANICKED instead of refusing"),
        }
    }
    assert_eq!(admitted, TRAINED_F_E_RANGE.collect::<Vec<u32>>(), "the admitted f_e set is not the declared class");
    eprintln!("REVIEW-A (fixed) admitted f_e at the trained TinyLlama profile: {admitted:?}");
    // the three-limb rule at other token counts (only T = 32 is registered)
    assert!(Shape::check_f_e_class(512, 15).is_ok());
    assert!(Shape::check_f_e_class(512, 16).unwrap_err().contains("three sigma_s limbs"));
    // the trained-model statement cannot even be asked for at f_e 50: there
    // is no shape to build it from
    assert!(Shape::tinyllama_t32_trained(&cal, 50).is_err());
}

// ------------------------------------------------------------------ H

/// **F-5: the class is re-checked by `Layout::for_shape`, not only at the
/// door.** A trained shape whose public fields are edited after the door is
/// refused before any transcript exists.
#[test]
fn review_h_layout_re_checks_the_whole_class_of_a_trained_shape() {
    let good = Shape::rung_tc(&rung_tc_calibration()).unwrap();
    Layout::for_shape(&good).expect("the honest trained rung has a layout");
    let edits: Vec<(&str, Box<dyn Fn(&mut Shape)>)> = vec![
        ("cn_a 2^40", Box::new(|s: &mut Shape| s.norm_cn_a = 1 << 40)),
        ("ceps 2^50", Box::new(|s: &mut Shape| s.norm_ceps = 1 << 50)),
        ("tn 11 (window 32 at width 384, but not the shape's derived window)", Box::new(|s: &mut Shape| s.norm_tn = 11)),
        ("norm_wrho 33", Box::new(|s: &mut Shape| s.norm_wrho = 33)),
        ("d_max + 1", Box::new(|s: &mut Shape| s.d_max += 1)),
        ("sh_qkv 9", Box::new(|s: &mut Shape| s.sh_qkv = 9)),
        ("sh_h 17", Box::new(|s: &mut Shape| s.sh_h = 17)),
        ("sh_ao 9", Box::new(|s: &mut Shape| s.sh_ao = 9)),
        ("f_e 50 with its window", Box::new(|s: &mut Shape| {
            s.f_e = 50;
            s.wrho_s = 55;
        })),
        ("f_e 8 with its window", Box::new(|s: &mut Shape| {
            s.f_e = 8;
            s.wrho_s = 13;
        })),
        ("f_e 13 without its window", Box::new(|s: &mut Shape| s.f_e = 13)),
        ("wrho_s 24 at f_e 12", Box::new(|s: &mut Shape| s.wrho_s = 24)),
    ];
    for (name, edit) in edits {
        let mut sh = good.clone();
        edit(&mut sh);
        let e = Layout::for_shape(&sh).err().unwrap_or_else(|| panic!("Layout::for_shape ACCEPTED a trained shape edited to {name}"));
        eprintln!("REVIEW-H (fixed) edited to {name}: refused: {}", e.chars().take(120).collect::<String>());
    }
}

// ------------------------------------------------------------------ B

/// **F-2: an UNBOUND run at a trained-calibration shape does not construct**
/// (it would absorb the synthetic calibration literal); the guard is the
/// shape's own flag, not a substring of the run profile.
#[test]
fn review_b_an_unbound_run_at_a_trained_shape_is_refused() {
    let sh = Shape::rung_tc(&rung_tc_calibration()).unwrap();
    let (blk, _) = super::trained_calib_tests::trained_dense_block(&sh);
    let ctx = *blake3::hash(b"review b").as_bytes();
    let expected = ExpectedIo::from_roots(IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap(), [1; 32], [2; 32]);
    let e = super::run::RunStatement::new(super::run::RunShape::rung_tc(sh.clone(), 1).unwrap(), ctx, expected.clone(), &[blk.clone()], &[(0, 0)]).err().expect("an unbound run at the trained rung CONSTRUCTED");
    assert!(e.contains("new_bound"), "{e}");
    // and under any run profile string at all: the shape's flag decides
    let e = super::run::RunStatement::new(super::run::RunShape::new(sh, 1, super::run::RUN_PROFILE_RUNG_C6).unwrap(), ctx, expected, &[blk], &[(0, 0)]).err().expect("a trained shape under a frozen run profile string CONSTRUCTED");
    assert!(e.contains("new_bound"), "{e}");
    eprintln!("REVIEW-B (fixed): {e}");
}

// ------------------------------------------------------------------ C

/// **F-3: a trained-model statement binds trained-calibration runs only, and
/// the trained TinyLlama profile is the pinned checkpoint's.**
#[test]
fn review_c_new_bound_refuses_a_frozen_profile_and_the_trained_profile_takes_the_pin_only() {
    use super::trained_statement::*;
    let sh = Shape::rung_g();
    let (public, ff, _) = super::dense_tests::dense_case(&sh);
    let blk = BlockPublic::new(public, ff);
    let prov = Provenance::recipe("review/c", 1.0, [1; 32], [2; 32]);
    let ctx = *blake3::hash(b"review c").as_bytes();
    let expected = ExpectedIo::from_roots(IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap(), [1; 32], [2; 32]);
    let refused = match TrainedModelStatement::new(&sh, super::run::RUN_PROFILE_RUNG_G, ModelSource::tinyllama_chat_v1_0(), IntegerCalibration::as_the_code_proves(&sh, &prov), vec![LayerRecord::of_block(0, &blk, vec![])]) {
        Err(e) => e,
        Ok(st) => super::run::RunStatement::new_bound(super::run::RunShape::rung_g(1).unwrap(), ctx, expected, &[blk], &[(0, 0)], &st).err().expect("new_bound CONSTRUCTED at the frozen rung-G profile"),
    };
    assert!(refused.contains("trained-calibration"), "{refused}");
    eprintln!("REVIEW-C (fixed) frozen profile: {refused}");
    // at the trained TinyLlama profile, a checkpoint source other than the pin
    let tsh = Shape::tinyllama_t32_trained(&pg(), 9).unwrap();
    let cal = IntegerCalibration::as_the_code_proves(&tsh, &prov);
    // a hand-made record (the statement's own checks never open a block)
    let rec = vec![LayerRecord { index: 0, block_digest: [1; 32], word_sha256: [[2; 32]; 9], table_sha256: [[3; 32]; 3], source_tensors: vec![], manifest_sha256: [4; 32], silu_member: (-3, -11), exp_e_s: 1 }];
    let rp = super::run::RUN_PROFILE_TINYLLAMA_T32_TRAINED;
    TrainedModelStatement::new(&tsh, rp, ModelSource::tinyllama_chat_v1_0(), cal.clone(), rec.clone()).expect("the pinned checkpoint at the trained TinyLlama profile");
    let mut other = ModelSource::tinyllama_chat_v1_0();
    other.repo = "someone/TinyLlama-lookalike".into();
    let e = TrainedModelStatement::new(&tsh, rp, other, cal.clone(), rec.clone()).err().expect("another checkpoint at the trained TinyLlama profile CONSTRUCTED");
    assert!(e.contains("pinned"), "{e}");
    let synth = ModelSource { kind: SourceKind::PublicSyntheticRecipe, repo: "synthetic/x".into(), revision: "r".into(), weights_sha256: [0; 32], config_sha256: [0; 32], checkpoint_parameters: 0, checkpoint_layers: 1 };
    assert!(TrainedModelStatement::new(&tsh, rp, synth, cal.clone(), rec.clone()).is_err(), "a synthetic recipe at the trained TinyLlama profile CONSTRUCTED");
    // the general rule on the per-block table keys and the RoPE base
    let mut r2 = rec.clone();
    r2[0].exp_e_s = 9;
    assert!(TrainedModelStatement::new(&tsh, rp, ModelSource::tinyllama_chat_v1_0(), cal.clone(), r2).unwrap_err().contains("declared class"));
    let mut r3 = rec.clone();
    r3[0].silu_member = (-7, -20);
    assert!(TrainedModelStatement::new(&tsh, rp, ModelSource::tinyllama_chat_v1_0(), cal.clone(), r3).unwrap_err().contains("frozen registry"));
    let mut c4 = cal;
    c4.rope_theta_f64_bits = 500_000.0f64.to_bits();
    assert!(TrainedModelStatement::new(&tsh, rp, ModelSource::tinyllama_chat_v1_0(), c4, rec).unwrap_err().contains("RoPE base"));
}

// ------------------------------------------------------------------ D

/// **F-4: the identity names the export by its PROFILE, not by its local
/// directory**: the same bytes under two directory names prove under one
/// identity; another `variant` in profile.json is another identity.
#[test]
fn review_d_the_statement_identity_does_not_depend_on_the_directory_name() {
    use super::trained_block_tests::{base_dir, write_export, Fault};
    let root = base_dir("review-d");
    let f = Fault { variant_name: Some("tiny-v1"), ..Default::default() };
    let (v1, _) = write_export(&root, "dir-name-a", &f);
    let (v2, _) = write_export(&root, "dir-name-b", &f);
    let (v3, _) = write_export(&root, "dir-name-c", &Fault { variant_name: Some("tiny-v2"), ..Default::default() });
    assert_eq!(std::fs::read(v1.join("profile.json")).unwrap(), std::fs::read(v2.join("profile.json")).unwrap());
    let id = |v: &std::path::Path| {
        let ex = super::trained_block::TrainedExport::load(v).unwrap();
        let c = ex.run_constants(&[0]).unwrap();
        let sh = ex.shape_for(&c).unwrap();
        let l = ex.load_layer(&sh, &c, 0, false).unwrap();
        (ex.variant.clone(), ex.statement(&sh, &c, &[&l]).unwrap().identity())
    };
    let (a, b, c) = (id(&v1), id(&v2), id(&v3));
    assert_eq!(a, b, "two directory names gave two identities");
    assert_eq!(a.0, "tiny-v1");
    assert_ne!(a.1, c.1, "another variant name gave the same identity");
    let _ = std::fs::remove_dir_all(&root);
}

// ------------------------------------------------------------------ E

/// a TinyLlama-geometry export at `f_e` with the pinned model strings and
/// SYNTHETIC placeholders for the arrays (the door refuses before any array is
/// read; the refusal text is asserted, so a door that moved later would fail
/// this test rather than refuse for another reason)
fn write_tinyllama_profile(vdir: &std::path::Path, cal: &NormCalibration, f_e: u32) {
    use super::trained_block::{hex, sha256};
    let ldir = vdir.join("layer_00");
    std::fs::create_dir_all(&ldir).unwrap();
    std::fs::create_dir_all(vdir.join("seq_s0")).unwrap();
    let consts = format!(
        "{{\"norm_tn\": {}, \"norm_cn_a\": {}, \"norm_cn_m\": {}, \"norm_ceps\": {}, \"sh_qkv\": {}, \"sh_rope\": 7, \"sh_s\": {}, \"sh_o\": {}, \"sh_ao\": {}, \"sh_g\": {}, \"sh_u\": 0, \"sh_h\": {}, \"sh_z\": {}, \"f_e\": {f_e}, \"f_p\": 9, \"f_ro\": 7, \"sh_r2\": 0, \"silu_member\": [-3, -11], \"exp_e_s\": 0, \"rope_theta\": 10000.0}}",
        cal.tn, cal.cn_a, cal.cn_m, cal.ceps, cal.sh_qkv, cal.sh_s, cal.sh_o, cal.sh_ao, cal.sh_g, cal.sh_h, cal.sh_z
    );
    let manifest = format!("{{\"layer\": 0, \"constants\": {consts}, \"arrays\": {{}}}}\n");
    std::fs::write(ldir.join("manifest.json"), &manifest).unwrap();
    let pin = super::trained_statement::ModelSource::tinyllama_chat_v1_0();
    let profile = format!(
        "{{\"schema\": \"zk60-trained-profile-export/1\", \"kind\": \"profile\", \"variant\": \"review-fe{f_e}\", \"geometry\": \"tinyllama-1.1b-t32\", \"model\": {{\"repo\": \"{}\", \"revision\": \"{}\", \"sha256\": \"{}\"}}, \"calibration_tool\": {{\"path\": \"review\", \"sha256\": \"{}\"}}, \"T\": 32, \"profile_constants\": {consts}, \"layers\": [{{\"layer\": 0, \"dir\": \"layer_00\", \"manifest_sha256\": \"{}\"}}], \"sequences\": [\"seq_s0\"]}}\n",
        pin.repo,
        pin.revision,
        hex(&pin.weights_sha256),
        hex(&sha256(b"review: a synthetic export, not a calibration")),
        hex(&sha256(manifest.as_bytes()))
    );
    std::fs::write(vdir.join("profile.json"), profile).unwrap();
}

/// **F-1 END TO END, TURNED AROUND.** The reviewer's export (`f_e = 50`, the
/// pinned TinyLlama model strings) is refused AT THE DOOR by the production
/// CLI bridge on BOTH sides — the prover before any witness, the verifier
/// before reading a byte of the artifact — and every admitted `f_e` loads.
/// Then the forgery itself: at a trained shape EDITED after the door to
/// `f_e = 50` (the rung, so this runs in the ordinary filter), the reviewer's
/// wrapping quotient forgery builds a witness, and neither the prover nor the
/// verifier of a bound run reaches a transcript.
#[test]
fn review_e_the_f_e_50_forgery_is_refused_at_the_door_on_both_sides() {
    use super::trained_block_tests::base_dir;
    let root = base_dir("review-e");
    let s = |v: &[&str]| -> Vec<String> { v.iter().map(|x| x.to_string()).collect() };
    for f_e in [50u32, 8, 17] {
        let vdir = root.join(format!("review-fe{f_e}"));
        write_tinyllama_profile(&vdir, &pg(), f_e);
        let e = super::trained_block::TrainedExport::load(&vdir).err().unwrap_or_else(|| panic!("the f_e {f_e} export LOADED"));
        assert!(e.contains(&format!("f_e {f_e}")) && e.contains("F-1"), "{e}");
        let vd = vdir.display().to_string();
        let art = root.join(format!("artifact-fe{f_e}"));
        let ad = art.display().to_string();
        assert_eq!(super::trained_block::trained_prove_command(&s(&["--export", &vd, "--layer", "0", "--seq", "s0", "--out", &ad])), 1, "the CLI prover did not refuse f_e {f_e}");
        assert!(!art.exists(), "the refused prover wrote an artifact");
        std::fs::create_dir_all(&art).unwrap();
        assert_eq!(super::trained_block::trained_verify_command(&s(&["--export", &vd, "--layer", "0", "--artifact", &ad, "--expect-statement", &"00".repeat(32)])), 1, "the CLI verifier did not refuse f_e {f_e}");
        assert_eq!(super::trained_block::trained_stack_verify_command(&s(&["--export", &vd, "--artifact", &ad, "--expect-statement", &"00".repeat(32)])), 1, "the stack verifier did not refuse f_e {f_e}");
        eprintln!("REVIEW-E (fixed) the f_e {f_e} export is refused at the door: {}", e.chars().take(160).collect::<String>());
    }
    for f_e in TRAINED_F_E_RANGE {
        let vdir = root.join(format!("ok-fe{f_e}"));
        write_tinyllama_profile(&vdir, &pg(), f_e);
        let ex = super::trained_block::TrainedExport::load(&vdir).unwrap_or_else(|e| panic!("f_e {f_e}: {e}"));
        let c = ex.run_constants(&[0]).unwrap();
        ex.shape_for(&c).unwrap_or_else(|e| panic!("f_e {f_e}: {e}"));
    }
    let _ = std::fs::remove_dir_all(&root);

    // the forgery against a shape edited after the door
    let honest = Shape::rung_tc(&rung_tc_calibration()).unwrap();
    let mut sh = honest.clone();
    sh.f_e = 50;
    sh.wrho_s = 55;
    let (mut w, input) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    for v in w[1].iter_mut() {
        *v = 0; // Wk = 0: every causal e is 2^50, the last row's Sum is 2^55
    }
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    assert_eq!(public.exp[0], 1i64 << 50);
    let blk = BlockPublic::new(public.clone(), ff.clone());
    set_forge(Some(Forge { h: 0, t: 31, j: 0, delta: 511, k: 1, naive: false }));
    let fw = witness::build_shaped(&sh, &public, &ff, &input);
    let n = forged_count();
    set_forge(None);
    let fw = fw.expect("the forged witness builds at the edited shape");
    assert_eq!(n, 1, "the wrapping forgery was not applied at f_e 50");
    let e = prove_one_bound(&sh, &blk, fw).err().expect("a bound run PROVED at a shape edited to f_e 50");
    assert!(e.contains("f_e 50") && e.contains("F-1"), "{e}");
    let ex = ExpectedIo::from_roots(IoSpec::new_shaped(&honest, *blake3::hash(b"r").as_bytes(), 0, 0).unwrap(), [1; 32], [2; 32]);
    let e2 = verify_one_bound(&sh, &blk, &ex.to_bytes(), &[0u8; 64]).err().expect("a verifier at a shape edited to f_e 50 got past its statement");
    eprintln!("REVIEW-E (fixed) the wrapping forgery at an edited f_e-50 shape: prover refused: {}; verifier refused: {}", e.chars().take(120).collect::<String>(), e2.chars().take(120).collect::<String>());
    // and at every ADMITTED f_e the wrapping forgery does not exist: the
    // remainder `rho - 511 Sum + k P` is never inside [0, Sum) for k != 0
    for f_e in TRAINED_F_E_RANGE {
        let sum_max = 32i128 << f_e;
        for k in [-2i128, -1, 1, 2] {
            for delta in [-1023i128, -511, -1, 1, 511, 1023] {
                // the smallest |rho - delta Sum + k P| over rho, Sum in class
                let lo = k * P - delta.abs() * sum_max - sum_max;
                let hi = k * P + delta.abs() * sum_max + sum_max;
                assert!(lo > sum_max || hi < 0, "f_e {f_e}: a wrapping remainder exists for k {k}, delta {delta}");
            }
        }
    }
}

// ------------------------------------------------------------------ F

/// the naive forgery `p + 1` (remainder untouched, so the quotient clause is
/// nonzero in the field) at `(head 0, token 31, source 0)`, proved as a bound
/// one-block run at `sh`: must be rejected at slot 17
fn naive_forgery_is_rejected_at_slot_17(sh: &Shape, wk_zero: bool) {
    let (mut w, input) = super::trained_calib_tests::trained_dense_words(sh, super::trained_calib_tests::TRAINED_BANDS);
    if wk_zero {
        for v in w[1].iter_mut() {
            *v = 0;
        }
    }
    let (public, ff) = super::dense_tests::statement_of_words(sh, &w);
    let blk = BlockPublic::new(public.clone(), ff.clone());
    set_forge(Some(Forge { h: 0, t: 31, j: 0, delta: 1, k: 0, naive: true }));
    let fw = witness::build_shaped(sh, &public, &ff, &input);
    let n = forged_count();
    set_forge(None);
    let fw = fw.expect("the naive forged witness builds");
    assert_eq!(n, 1, "the naive forgery was not applied");
    let verdict = prove_one_bound(sh, &blk, fw).and_then(|b| verify_one_bound(sh, &blk, &b.expected.to_bytes(), &b.seg));
    let e = verdict.err().expect("the naive softmax forgery VERIFIED");
    eprintln!("REVIEW-F naive forgery (p + 1) at {} f_e {}: rejected: {}", sh.profile, sh.f_e, e.chars().take(160).collect::<String>());
    assert!(e.contains("slot 17"), "rejected, but not at slot 17: {e}");
}

/// **F (control), in the ordinary filter**: at the trained rung (`f_e = 12`).
#[test]
fn review_f_the_naive_quotient_forgery_is_rejected_at_slot_17_at_the_rung() {
    naive_forgery_is_rejected_at_slot_17(&Shape::rung_tc(&rung_tc_calibration()).unwrap(), true);
}

/// **F (control) at the trained TinyLlama profile** with the approved
/// `f_e = 9` and the pg calibration (the reviewer ran it at `f_e = 50`, which
/// no longer constructs).
#[test]
#[ignore = "heavy: one TinyLlama-geometry witness and one bound one-block proof (release)"]
fn review_f_the_naive_quotient_forgery_is_rejected_at_slot_17_at_the_trained_tinyllama_profile() {
    naive_forgery_is_rejected_at_slot_17(&Shape::tinyllama_t32_trained(&pg(), 9).unwrap(), true);
}

// ------------------------------------------------------------------ G

/// **G (control): the norm class CORNER end to end at the trained rung**:
/// `tn 10, Cn_a = Cn_m = 2^20, Ceps = 2^40, sh_ao = 8` (window 32 = C-6 at
/// width 384), gains +-1 so the int8 output class holds. The honest block
/// proves and verifies as a bound run; a verifier one unit off each constant
/// refuses; a witness honest under a neighbouring constant is rejected.
#[test]
fn review_g_the_class_corner_proves_and_its_neighbours_refuse() {
    let corner = NormCalibration { tn: 10, cn_a: 1 << 20, cn_m: 1 << 20, ceps: 1 << 40, sh_ao: 8, ..rung_tc_calibration() };
    let sh = Shape::rung_tc(&corner).expect("the class corner is admitted at width 384");
    let (mut w, input) = super::trained_calib_tests::trained_dense_words(&sh, super::trained_calib_tests::TRAINED_BANDS);
    for (k, g) in w[4].iter_mut().enumerate() {
        *g = if k % 3 == 0 { -1 } else { 1 };
    }
    for (k, g) in w[5].iter_mut().enumerate() {
        *g = if k % 5 == 0 { -1 } else { 1 };
    }
    let (public, ff) = super::dense_tests::statement_of_words(&sh, &w);
    let blk = BlockPublic::new(public.clone(), ff.clone());
    let wit = witness::build_shaped(&sh, &public, &ff, &input).expect("the corner witness");
    let b = prove_one_bound(&sh, &blk, wit).expect("the corner proves");
    let eb = b.expected.to_bytes();
    verify_one_bound(&sh, &blk, &eb, &b.seg).expect("the corner verifies");
    eprintln!("REVIEW-G corner: honest segment {} B verifies", b.seg.len());
    let mut rejected = 0usize;
    for (name, v) in [
        ("cn_a - 1", NormCalibration { cn_a: corner.cn_a - 1, ..corner }),
        ("cn_m - 1", NormCalibration { cn_m: corner.cn_m - 1, ..corner }),
        ("ceps - 1", NormCalibration { ceps: corner.ceps - 1, ..corner }),
        ("tn - 1", NormCalibration { tn: corner.tn - 1, ..corner }),
        ("sh_ao - 1", NormCalibration { sh_ao: corner.sh_ao - 1, ..corner }),
    ] {
        let other = Shape::rung_tc(&v).unwrap();
        assert!(verify_one_bound(&other, &blk, &eb, &b.seg).is_err(), "a verifier with {name} ACCEPTED the corner segment");
        let ow = match witness::build_shaped(&other, &public, &ff, &input) {
            Ok(x) => x,
            Err(e) => {
                eprintln!("REVIEW-G corner: the {name} witness itself refuses ({e}); skipped");
                continue;
            }
        };
        let verdict = prove_one_bound(&sh, &blk, ow).and_then(|b2| verify_one_bound(&sh, &blk, &b2.expected.to_bytes(), &b2.seg));
        let e = verdict.err().unwrap_or_else(|| panic!("a witness honest under {name} VERIFIED at the corner"));
        eprintln!("REVIEW-G corner: witness honest under {name} rejected: {}", e.chars().take(100).collect::<String>());
        rejected += 1;
    }
    assert!(rejected >= 3, "only {rejected} neighbouring witnesses ran");
}
