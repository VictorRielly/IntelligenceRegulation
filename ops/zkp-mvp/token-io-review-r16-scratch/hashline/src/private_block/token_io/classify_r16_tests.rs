//! **TOKEN I/O ROUND 16: the Shieldstral classifier on native R13** (REVIEW_R13
//! §10). TEST CODE ONLY.
//!
//! * the R13 classifier run profiles (Shieldstral T128 / T256 LOW + h24, non-DD)
//!   are registered at their block shapes, with the D37 category list
//!   (moderate wording, pending Victor) and their whole-run figure at R13
//!   [COUNTED];
//! * at the test-only R13 h24 development rung (public synthetic: Sol's R13
//!   loader fixture `r13-h24-wide`, `HL_R13_LOADER_FIXTURES` or the native
//!   tree's sibling `loader-fixtures/`), a TWO-stage classifier run whose
//!   layers carry DIFFERENT gate denominators proves, verifies, passes the
//!   input owner's check and refuses a changed byte; a doctored per-layer gate
//!   shift, a block handed at another stage's shape, and the run seed's
//!   shape are refused; a T256 statement under a T128 profile is refused;
//! * the export loader's tied derivation is reused only with the bound
//!   profile's own margin parameters (token review N-r13-5: one checkpoint
//!   stream per prove / verify).
//!
//! The `#[ignore]`d `r16_write_item_activations` is the round's tool that
//! writes a REAL item's prover-private activations (`--seq-dir`) with the
//! native builder (run guarded; it streams the pinned checkpoint once).

use super::classify::*;
use super::classify_run::*;
use super::classify_tied::{BoundClassifierTables, TiedSource};
use super::run::{r13_block_logup_numerator, VerifierPolicy};
use super::*;
use super::super::run::{RunShape, RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256};
use super::super::shape::{R13_RUNG_H24, R13_SHIELD_T128_H24, R13_SHIELD_T256_H24};
use super::super::trained_block::{Constants, TrainedExport};
use super::super::trained_statement::{IntegerCalibration, LayerRecord, Provenance, TrainedModelStatement};
use super::super::BlockPublic;
use std::path::PathBuf;

const MIN_BITS: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 95 };

fn fixtures() -> PathBuf {
    std::env::var_os("HL_R13_LOADER_FIXTURES").map(PathBuf::from).unwrap_or_else(|| std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures"))
}

// ------------------------------------------------------------------ registry and bits

#[test]
fn r16_the_r13_shieldstral_classifier_profiles_are_registered_at_their_block_shapes() {
    let cal = r13_census_calibration();
    let t128 = super::super::shape::Shape::accuracy_trained(R13_SHIELD_T128_H24, &cal, 9, 20).unwrap();
    let t256 = super::super::shape::Shape::accuracy_trained(R13_SHIELD_T256_H24, &cal, 9, 20).unwrap();
    RunShape::new(t128.clone(), 26, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128).expect("T128 profile at the T128 shape");
    RunShape::new(t256.clone(), 26, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256).expect("T256 profile at the T256 shape");
    // CS-7: a T256 shape under the T128 profile (and the reverse) is refused
    let e = RunShape::new(t256.clone(), 26, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128).err().expect("A T256 SHAPE WAS ADMITTED UNDER THE T128 CLASSIFIER PROFILE");
    assert!(e.contains("CS-7"), "{e}");
    assert!(RunShape::new(t128.clone(), 26, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256).is_err());
    // the CLI's mapping, the tied source, the overlap, the D27 floor
    assert_eq!(super::classify_cli::classify_run_profile_of(&t128).unwrap(), RUN_PROFILE_CLASSIFY_R13_SHIELD_T128);
    assert_eq!(super::classify_cli::classify_run_profile_of(&t256).unwrap(), RUN_PROFILE_CLASSIFY_R13_SHIELD_T256);
    for p in [RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256] {
        assert_eq!(TiedSource::of_run_profile(p).unwrap(), TiedSource::Shieldstral);
        assert_eq!(chunk_overlap_of(p).unwrap(), 8);
        assert_eq!(super::classify_tied::min_bits_floor(p), 95);
    }
    assert_eq!(TiedSource::of(t128.profile).unwrap(), TiedSource::Shieldstral);
    // the D37 category list: three policies, Astra's moderate templates byte for
    // byte (SHA-256 of the prefix ids as u64 LE, computed from
    // category_policy_candidates.json b1cfcda9…: mod_sexual / mod_violence / mod_hate)
    let want = [
        ("shieldstral-1.0-3b-moderate-sexual/1", 72usize, "eed4d4c58661672ee6ee9b2f30fe2bbc99282f875f8246dec0d9d2d26d8ab3fd"),
        ("shieldstral-1.0-3b-moderate-violence/1", 72, "96225c387d6c3d6ccf29827d5ea6889e0be13e68fa0788c9cc7a5edd3aedfba1"),
        ("shieldstral-1.0-3b-moderate-hate/1", 78, "83ac93e6a103a270205398d4c9bc341ac64b5f48021a963504ac270277329fee"),
    ];
    let cats = shieldstral_category_policies();
    assert_eq!(cats.len(), 3);
    for (p, (id, p0, sha)) in cats.iter().zip(want) {
        let bytes: Vec<u8> = p.prefix.iter().flat_map(|x| x.to_le_bytes()).collect();
        assert_eq!((p.id.as_str(), p.prefix.len(), super::super::trained_block::hex(&super::super::trained_block::sha256(&bytes)).as_str()), (id, p0, sha));
        assert_eq!((p.suffix.as_slice(), p.yes, p.no, p.c, p.pad, p.num_special, p.v), ([4u64].as_slice(), 13059, 2649, 0, 11, 1000, 131_072));
        assert_eq!(p.margin_scale_bits, 0x3ed1_1ff5_97db_2fb6);
        assert_eq!(policy_by_id(id).unwrap(), *p, "the category policy is pre-registered (B-6)");
        // chunk sizes at T128 / T256 (Astra's content_tokens_by_T)
        assert_eq!((128 - p0 - 1, 256 - p0 - 1), if p0 == 72 { (55, 183) } else { (49, 177) });
    }
    // a blocks-only run statement may not carry an R13 classifier profile
    let model = r13_synthetic_model(&t128, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, &[20; 2], [9; 32], 1.0 / 512.0);
    let spec = super::super::IoSpec::new_shaped(&t128, [5; 32], 0, 0).unwrap();
    let e = super::super::run::RunStatement::new_bound_from_digests(
        RunShape::new(t128, 2, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128).unwrap(),
        [5; 32],
        super::super::ExpectedIo::from_roots(spec, [1; 32], [2; 32]),
        model.layers.iter().map(|r| r.block_digest).collect(),
        &[super::super::ENDPOINT_SCALES; 2],
        &model,
    )
    .err()
    .expect("A BLOCKS-ONLY RUN CARRIED THE CLASSIFIER PROFILE");
    assert!(e.contains("classifier run profile"), "{e}");
    eprintln!("TOKEN-IO R16 | registry | the two R13 Shieldstral classifier run profiles at their block shapes; the moderate D37 list; CS-7 refuses the swapped T");
}

/// **[COUNTED] the whole-run figure at R13** (REVIEW_R13 §10 item 6): the block
/// term is `(N + 4 T_d - 1) / p^2` with REVIEW_R13 §6's N per block, and every
/// registered Shieldstral classifier profile's floor clears D27's 95.
#[test]
fn r16_the_r13_whole_run_figure_charges_the_degree_two_tables_and_clears_95() {
    let cal = r13_census_calibration();
    let p2 = 2.0 * (P as f64).log2();
    // REVIEW_R13 §6: N per block 66,879,488 (T128) / 154,730,496 (T256), non-DD
    for (block, n_review, t_dd, per_block_bits) in [(R13_SHIELD_T128_H24, 66_879_488u128, 512 + 4 * 4096u128, 102.00f64), (R13_SHIELD_T256_H24, 154_730_496, 512 + 4 * 4096, 100.79)] {
        let sh = super::super::shape::Shape::accuracy_trained(block, &cal, 9, 20).unwrap();
        let num = r13_block_logup_numerator(&sh).expect("an R13 shape has an R13 term");
        assert_eq!(num, n_review + 4 * t_dd - 1, "{block}: the R13 numerator is not REVIEW_R13's N + 4 T_d - 1");
        let bits = p2 - (num as f64).log2();
        assert!((bits - per_block_bits).abs() < 0.01, "{block}: per-block {bits:.3} bits, REVIEW_R13 {per_block_bits}");
        // the legacy convention at this shape (N + 3 * 768 - 1) is another number
        let (n, r) = super::run::block_logup_size(&sh);
        assert_ne!(n + 3 * r - 1, num, "{block}: the legacy term equals the R13 one; the port would be invisible");
        eprintln!("TOKEN-IO R16 | bits [COUNTED] | {block}: N {n_review} (legacy count {n}), T_d {t_dd}, per block 2^-{bits:.2}");
    }
    // a legacy shape has no R13 term (its figures do not move)
    assert!(r13_block_logup_numerator(&super::super::shape::Shape::rung_tc(&super::super::trained_calib_tests::rung_tc_calibration()).unwrap()).is_none());
    // the classifier statements at L = 26, every term included
    for profile in [RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256] {
        let (st, _, _) = census_classify_statement(profile, 26);
        let w = st.whole_run();
        eprintln!("TOKEN-IO R16 | bits [COUNTED] | {profile} L26: whole-run 2^{:.2} (column 2^{:.2}, LogUp 2^{:.2}, PCS+sumcheck 2^{:.2}), floor {} bits, {} openings", w.total_log2, w.column_log2, w.logup_log2, w.omitted_log2, w.floor_bits, w.openings);
        assert!(w.floor_bits >= 95, "{profile}: the whole-run floor {} is below D27's 95", w.floor_bits);
        assert!(st.parameter_line().unwrap().contains(&format!("whole-run-floor-{}-bits", w.floor_bits)));
    }
}

// ------------------------------------------------------------------ the R13 rung run

/// the R13 h24 rung fixture as TWO layers with DIFFERENT gate denominators
/// (Sol's two-stage construction: layer 1 is layer 0 with another SiLU
/// member), the export's constants, the seed shape, the blocks and records
fn two_stage_fixture() -> (TrainedExport, Constants, super::super::shape::Shape, Vec<BlockPublic>, Vec<LayerRecord>) {
    use super::super::accuracy_public::AccuracyPublic;
    let path = fixtures().join("r13-h24-wide");
    assert!(path.join("profile.json").exists(), "the R13 loader fixture {} is missing: set HL_R13_LOADER_FIXTURES (results/zk60_1b_native_20261017/r13/loader-fixtures)", path.display());
    let mut ex = TrainedExport::load(&path).unwrap();
    ex.source.checkpoint_layers = 2;
    let c = ex.run_constants(&[0]).unwrap();
    let seed = ex.shape_for(&c).unwrap();
    assert_eq!(seed.profile, R13_RUNG_H24);
    let first = ex.load_layer(&seed, &c, 0, false).unwrap();
    let a = first.blk.accuracy().unwrap();
    let changed = AccuracyPublic::new(a.stack(), a.geometry(), a.base(), (-4, -13), a.multipliers().clone(), a.groups().to_vec(), a.group_ids().to_vec(), a.raw_tables().to_vec()).unwrap();
    let second = first.blk.clone().with_accuracy(changed);
    let mut r2 = LayerRecord::of_block(1, &second, vec![]);
    r2.manifest_sha256 = [53; 32];
    let r1 = first.record.clone();
    assert_ne!(r1.accuracy_gate_shift, r2.accuracy_gate_shift, "the fixture's two layers must carry different gate denominators");
    (ex, c, seed, vec![first.blk, second], vec![r1, r2])
}

fn model_under(ex: &TrainedExport, c: &Constants, seed: &super::super::shape::Shape, records: Vec<LayerRecord>) -> TrainedModelStatement {
    let prov = Provenance {
        label: format!("export:{}", ex.variant),
        residual_unit: ex.residual_unit,
        quantizer_sha256: ex.tool_sha256,
        calibration_set_sha256: ex.calibration_set_sha256,
        export_profile_sha256: ex.profile_sha256,
        calibration_tool_sha256: ex.tool_sha256,
        rope_theta: c.rope_theta,
        rope_scaling: ex.rope_scaling,
    };
    TrainedModelStatement::new_with_tied(seed, RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST, ex.source.clone(), IntegerCalibration::as_the_code_proves(seed, &prov), records, None).expect("the R13 rung's trained statement under the test classifier profile")
}

fn bound_for(seed: &super::super::shape::Shape, model: &TrainedModelStatement) -> BoundClassifierTables {
    let tt = super::tests::generic_tables(seed.width, 0x7231_3672);
    let mut s = 0x6d61_7267_696eu64;
    let w: Vec<i16> = (0..seed.width).map(|_| (super::tests::lcg(&mut s) % 20_001) as i16 - 10_000).collect();
    let tables = ClassifierTables::new(tt.v, tt.d, tt.emb, w).unwrap();
    BoundClassifierTables::synthetic_for_relation_tests(tables, 1, super::tests::norm(), seed, RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST, model, &policy_rung_dev()).unwrap()
}

/// a generic short content (20 ids, none a control id) of the dev policy
fn content() -> Vec<u64> {
    let mut s = 0x7231_3663u64;
    (0..20).map(|_| 5 + super::tests::lcg(&mut s) % 295).collect()
}

struct Proved {
    st: ClassifyRunStatement,
    segments: Vec<Vec<u8>>,
    dec: Decommitment,
}

fn statement(seed: &super::super::shape::Shape, model: &TrainedModelStatement, bound: &BoundClassifierTables, n: usize, root: Digest, verdict: u8) -> Result<ClassifyRunStatement, String> {
    let digests: Vec<Digest> = model.layers.iter().map(|r| r.block_digest).collect();
    ClassifyRunStatement::new(RunShape::new(seed.clone(), model.layers.len(), RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST)?, super::tests::ctx(), digests, model, bound, &policy_rung_dev(), n, Tier::R1_MVP, root, verdict)
}

/// the honest pipeline and proof at the records' own stage shapes
fn prove_honest(seed: &super::super::shape::Shape, model: &TrainedModelStatement, bound: &BoundClassifierTables, blocks: &[BlockPublic], c: &[u64]) -> Proved {
    let cp = ClassifierProfile::new(seed, bound.tables(), bound.bos(), bound.norm(), &policy_rung_dev(), c.len(), Tier::R1_MVP).unwrap();
    let tokens = cp.tokens_of(c).unwrap();
    let shapes: Vec<super::super::shape::Shape> = model.layers.iter().map(|r| r.shape_at(seed).unwrap()).collect();
    let mut honest = honest_classify(&shapes, &cp, bound.tables(), blocks, &tokens).unwrap();
    let spec = input_endpoint_spec(seed, super::tests::ctx(), &cp).unwrap();
    let (root, owner) = seal_input(&spec, &honest.in_plane, &seed.hash_tag()).unwrap();
    let st = statement(seed, model, bound, c.len(), root, honest.out_values.verdict).unwrap();
    let mut segments = Vec::new();
    let (_, dec) = prove_classify_run(&st, blocks, bound, &mut ClassifySource(&mut honest), owner, &mut |k, b| {
        assert_eq!(k, segments.len());
        segments.push(b);
        Ok(())
    })
    .unwrap();
    Proved { st, segments, dec }
}

/// **REVIEW_R13 §10 items 3 and 4 at the R13 rung**: two stages, two different
/// bound gate denominators; each block at its OWN stage shape; prove, a fresh
/// statement's verify, the owner's check, a changed byte refused.
#[test]
fn r16_an_r13_classifier_run_with_two_gate_denominators_proves_and_verifies() {
    let (ex, c, seed, blocks, records) = two_stage_fixture();
    let (g0, g1) = (records[0].accuracy_gate_shift.unwrap(), records[1].accuracy_gate_shift.unwrap());
    let model = model_under(&ex, &c, &seed, records);
    let bound = bound_for(&seed, &model);
    let item = content();
    let pr = prove_honest(&seed, &model, &bound, &blocks, &item);
    assert_eq!((pr.st.stage_gate(0), pr.st.stage_gate(1)), (Some(g0), Some(g1)));
    assert_eq!((pr.st.stage_shape(0).unwrap().accuracy_gate_shift, pr.st.stage_shape(1).unwrap().accuracy_gate_shift), (g0, g1));
    assert!(pr.st.stage_lines().unwrap()[2].contains(&format!("R13 gate denominator {g1}")), "the stage line names its gate");
    assert_eq!(pr.segments.len(), 4);
    // the verifier's own statement, rebuilt from the public inputs alone
    let fresh_model = model_under(&ex, &c, &seed, model.layers.clone());
    let fresh_bound = bound_for(&seed, &fresh_model);
    let fresh = statement(&seed, &fresh_model, &fresh_bound, item.len(), pr.st.in_root(), pr.st.verdict()).unwrap();
    assert!(fresh.whole_run().floor_bits >= 95, "the R13 rung's whole-run floor is {}", fresh.whole_run().floor_bits);
    verify_classify_run(&fresh, &blocks, &fresh_bound, &pr.segments, MIN_BITS).expect("the honest R13 classifier run verifies");
    owner_check_input(&fresh, &pr.dec, &item).expect("the input owner's check");
    let mut bad = pr.segments.clone();
    let mid = bad[2].len() / 2;
    bad[2][mid] ^= 1;
    assert!(verify_classify_run(&fresh, &blocks, &fresh_bound, &bad, MIN_BITS).is_err(), "A CHANGED BLOCK SEGMENT VERIFIED");
    eprintln!(
        "TOKEN-IO R16 | R13 rung | two stages at G {g0} and G {g1}: prove {} segments ({} B), fresh verify, owner check, changed byte refused; floor {} bits",
        pr.segments.len(),
        pr.segments.iter().map(Vec::len).sum::<usize>(),
        fresh.whole_run().floor_bits
    );
}

/// **A doctored per-layer gate shift is refused**, at both doors: the prover's
/// sealing pass (before any header) and the verifier (before its header).
/// The doctored record is self-consistent (a class-valid G, its own trained
/// statement and tables bound to it); only the block's own G disagrees.
#[test]
fn r16_a_doctored_per_layer_gate_shift_is_refused_before_any_header() {
    let (ex, c, seed, blocks, records) = two_stage_fixture();
    let model = model_under(&ex, &c, &seed, records.clone());
    let bound = bound_for(&seed, &model);
    let item = content();
    let pr = prove_honest(&seed, &model, &bound, &blocks, &item);
    let g1 = records[1].accuracy_gate_shift.unwrap();
    let doctored_g = if g1 < 24 { g1 + 1 } else { g1 - 1 };
    let mut recs = records;
    recs[1].accuracy_gate_shift = Some(doctored_g);
    let doctored = model_under(&ex, &c, &seed, recs.clone());
    assert_ne!(doctored.identity(), model.identity(), "the gate denominator is bound by the trained statement's identity");
    let dbound = bound_for(&seed, &doctored);
    let st = statement(&seed, &doctored, &dbound, item.len(), pr.st.in_root(), pr.st.verdict()).expect("the doctored statement itself constructs (its G is in class)");
    assert_eq!(st.stage_shape(1).unwrap().accuracy_gate_shift, doctored_g);
    // the verifier: refused before its run header, at the stage-shape check
    let e = verify_classify_run(&st, &blocks, &dbound, &pr.segments, MIN_BITS).err().expect("A RECEIPT VERIFIED UNDER A DOCTORED GATE DENOMINATOR");
    assert!(e.contains("block 1"), "{e}");
    // the prover: refused in the sealing pass, no header built
    let cp = ClassifierProfile::new(&seed, dbound.tables(), dbound.bos(), dbound.norm(), &policy_rung_dev(), item.len(), Tier::R1_MVP).unwrap();
    let tokens = cp.tokens_of(&item).unwrap();
    let shapes: Vec<super::super::shape::Shape> = model.layers.iter().map(|r| r.shape_at(&seed).unwrap()).collect();
    let mut honest = honest_classify(&shapes, &cp, dbound.tables(), &blocks, &tokens).unwrap();
    let spec = input_endpoint_spec(&seed, super::tests::ctx(), &cp).unwrap();
    let (root, owner) = seal_input(&spec, &honest.in_plane, &seed.hash_tag()).unwrap();
    let st = statement(&seed, &doctored, &dbound, item.len(), root, honest.out_values.verdict).unwrap();
    let before = classify_headers();
    let e = prove_classify_run(&st, &blocks, &dbound, &mut ClassifySource(&mut honest), owner, &mut |_, _| Ok(())).err().expect("A DOCTORED GATE DENOMINATOR WAS PROVED");
    assert!(e.contains("block 1"), "{e}");
    assert_eq!(classify_headers(), before, "the doctored run built a header before its refusal");
    // a record without its gate, and a gate outside 17..=24, do not construct
    for g in [None, Some(16), Some(25)] {
        let mut r = recs.clone();
        r[1].accuracy_gate_shift = g;
        let m = TrainedModelStatement { layers: r, ..doctored.clone() };
        let b = bound_for(&seed, &m);
        assert!(statement(&seed, &m, &b, item.len(), pr.st.in_root(), pr.st.verdict()).is_err(), "gate {g:?} constructed");
    }
    eprintln!("TOKEN-IO R16 | R13 rung | a doctored gate denominator (G {g1} -> {doctored_g}) refused by the verifier before its header and by the prover's sealing pass (no header); G None / 16 / 25 do not construct");
}

/// **Each block against ITS OWN stage shape** (REVIEW_R13 §10 item 4): a block
/// handed at another stage is refused before the verifier's header; the run
/// seed's shape (G 17, what the token lane's pre-R13 `stage_shape` gave every
/// stage) does not fit a block whose layer has another G.
#[test]
fn r16_a_block_at_another_stage_shape_and_the_run_seed_shape_are_refused() {
    let (ex, c, seed, blocks, records) = two_stage_fixture();
    let model = model_under(&ex, &c, &seed, records.clone());
    let bound = bound_for(&seed, &model);
    let item = content();
    let pr = prove_honest(&seed, &model, &bound, &blocks, &item);
    let swapped = vec![blocks[1].clone(), blocks[0].clone()];
    let e = verify_classify_run(&pr.st, &swapped, &bound, &pr.segments, MIN_BITS).err().expect("SWAPPED BLOCKS VERIFIED");
    assert!(e.contains("block 0"), "{e}");
    // the run seed's shape: at least one block does not fit it; each fits its own stage
    let misfit = (0..2).filter(|&k| blocks[k].check_for_shape(&seed).is_err()).count();
    assert!(misfit >= 1, "every block fits the run seed (G {}); the stage-shape port would be invisible", seed.accuracy_gate_shift);
    for k in 0..2 {
        blocks[k].check_for_shape(&pr.st.stage_shape(k).unwrap()).unwrap();
    }
    // garbage segments: the stage check fires first (before any segment is decoded)
    let junk = vec![vec![0u8; 8]; 4];
    let e = verify_classify_run(&pr.st, &swapped, &bound, &junk, MIN_BITS).err().unwrap();
    assert!(e.contains("block 0"), "the stage-shape check did not run before the segments were read: {e}");
    eprintln!("TOKEN-IO R16 | R13 rung | swapped blocks refused before the header; {misfit} of 2 blocks do not fit the run seed (G {})", seed.accuracy_gate_shift);
}

/// **A T256 statement under a T128 classifier profile is refused** (and the
/// reverse): the run shape (CS-7) and the trained statement's geometry.
#[test]
fn r16_a_t256_export_statement_with_a_t128_profile_is_refused() {
    let cal = r13_census_calibration();
    let t256 = super::super::shape::Shape::accuracy_trained(R13_SHIELD_T256_H24, &cal, 9, 20).unwrap();
    let t128 = super::super::shape::Shape::accuracy_trained(R13_SHIELD_T128_H24, &cal, 9, 20).unwrap();
    // the statement a T256 export gives (its own profile), handed to a T128 run
    let m256 = r13_synthetic_model(&t256, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256, &[20; 3], [9; 32], 1.0 / 512.0);
    let policy = policy_shieldstral_moderate_hate();
    let tiny = ClassifierTables::new(300, 3072, vec![0; 300 * 3072], vec![1; 3072]).unwrap();
    let b = BoundClassifierTables::synthetic_for_relation_tests(tiny, 1, FinalNorm { g0: 127, cn: 1024, tn: 10, ceps: 2439 }, &t256, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256, &m256, &policy).unwrap();
    let digests: Vec<Digest> = m256.layers.iter().map(|r| r.block_digest).collect();
    let rs128 = RunShape::new(t128.clone(), 3, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128).unwrap();
    let e = ClassifyRunStatement::new(rs128, super::tests::ctx(), digests.clone(), &m256, &b, &policy, 30, Tier::R1_MVP, [7; 32], 0).err().expect("A T256 STATEMENT WAS ADMITTED UNDER THE T128 PROFILE");
    eprintln!("TOKEN-IO R16 | T mismatch | {e}");
    assert!(RunShape::new(t256, 3, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128).is_err());
    // and a T128 statement under the T256 profile
    let m128 = r13_synthetic_model(&t128, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, &[20; 3], [9; 32], 1.0 / 512.0);
    let rs256 = RunShape::new(super::super::shape::Shape::accuracy_trained(R13_SHIELD_T256_H24, &cal, 9, 20).unwrap(), 3, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256).unwrap();
    assert!(ClassifyRunStatement::new(rs256, super::tests::ctx(), m128.layers.iter().map(|r| r.block_digest).collect(), &m128, &b, &policy, 30, Tier::R1_MVP, [7; 32], 0).is_err());
}

// ------------------------------------------------------------------ N-r13-5

/// **The export loader's tied derivation is reused only with the bound
/// profile's own margin parameters** (token review N-r13-5: one checkpoint
/// stream per classifier prove / verify): a derivation carrying them is used
/// and native R12b's recompute is NOT called (the stub panics if it is); one
/// made with other parameters, or none, is not used (the recompute runs). The
/// post-derivation profile-digest check applies to a reused derivation too.
#[test]
fn r16_the_loaders_tied_derivation_is_reused_only_with_the_bound_margin_parameters() {
    use super::super::tied_tables::{RecomputedTiedTables, TiedFinalNorm, TiedTokenCalibration};
    use super::super::trained_block::{sha256, TiedDerivation};
    use super::classify_tied::{recompute_tied_classifier_pre, stub_shieldstral_recompute};
    let root = super::classify_cli_tests::fixture_root().join(format!("r16-reuse-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    let (export, tables) = (root.join("export"), root.join("tables"));
    std::fs::create_dir_all(&export).unwrap();
    std::fs::create_dir_all(&tables).unwrap();
    let policy = policy_shieldstral_moderate_violence();
    let profile = format!("{{\"kind\": \"r16-reuse-stub-profile\", \"classifier_margin_parameters\": {{\"yes_id\": {}, \"no_id\": {}, \"public_scale\": {:?}, \"threshold_c\": {}}}}}\n", policy.yes, policy.no, policy.margin_scale(), policy.c);
    std::fs::write(export.join("profile.json"), &profile).unwrap();
    let bound = sha256(profile.as_bytes());
    let tables_of = |profile_sha256: [u8; 32], fill: i16| {
        let fnm = TiedFinalNorm { g0: 127, cn: 1024, tn: 10, ceps: 2439 };
        RecomputedTiedTables { embedding_sha256: [3; 32], head_sha256: [4; 32], multipliers_sha256: [5; 32], margin: Some(vec![fill; 3072]), calibration: TiedTokenCalibration { bos: 1, classifier_final_norm: fnm.clone(), head_final_norm: fnm, profile_sha256 } }
    };
    let want = (13059u32, 2649u32, policy.margin_scale_bits);
    // (1) the bound parameters: reused, the recompute is not called
    {
        let _g = stub_shieldstral_recompute(Box::new(|_: &std::path::Path, _: (u32, u32, f64)| panic!("THE CHECKPOINT WAS STREAMED A SECOND TIME (N-r13-5)")));
        let pre = TiedDerivation { margin: Some(want), tables: tables_of(bound, 9) };
        let t = recompute_tied_classifier_pre(TiedSource::Shieldstral, &export, &tables, &policy, 0.0, 3072, &bound, Some(&pre)).expect("the reused derivation");
        assert_eq!((t.w[0], t.w.len(), t.profile_sha256), (9, 3072, bound));
        // a reused derivation that read another profile is refused all the same
        let mut other = bound;
        other[0] ^= 1;
        let pre = TiedDerivation { margin: Some(want), tables: tables_of(other, 9) };
        let e = recompute_tied_classifier_pre(TiedSource::Shieldstral, &export, &tables, &policy, 0.0, 3072, &bound, Some(&pre)).err().expect("A REUSED DERIVATION OF ANOTHER profile.json WAS ACCEPTED");
        assert!(e.contains("the derivation read a profile.json other than the one the trained statement binds"), "{e}");
    }
    // (2) other parameters or none: not used; the recompute runs (and is the source)
    for margin in [None, Some((2649u32, 13059u32, want.2)), Some((want.0, want.1, want.2 ^ 1))] {
        let _g = stub_shieldstral_recompute(Box::new(move |_: &std::path::Path, m: (u32, u32, f64)| {
            assert_eq!(m, (13059, 2649, 4.08288030735373e-6));
            Ok(tables_of(sha256(profile_bytes_for_stub().as_bytes()), 5))
        }));
        let pre = TiedDerivation { margin, tables: tables_of(bound, 9) };
        let r = recompute_tied_classifier_pre(TiedSource::Shieldstral, &export, &tables, &policy, 0.0, 3072, &bound, Some(&pre));
        // the stub's digest is of another text: refused by the post check, which
        // shows the recompute (not the handed derivation) was the source
        let e = r.err().expect("the recompute's derivation of another profile was accepted");
        assert!(e.contains("the derivation read a profile.json other than"), "{margin:?}: {e}");
    }
    let _ = std::fs::remove_dir_all(&root);
    eprintln!("TOKEN-IO R16 | N-r13-5 | the loader's derivation is reused with the bound margin parameters (no second stream) and only then; the post-derivation digest check still applies");
}

fn profile_bytes_for_stub() -> String {
    "not the bound profile".into()
}

// ------------------------------------------------------------------ the real item's activations

/// **THE ROUND'S ACTIVATION WRITER (`#[ignore]`d; run guarded)**: a REAL
/// item's prover-private `--seq-dir` (x_in_LXX / x_out_LXX, int16 `[T, d]` LE)
/// through the NATIVE builder at each layer's bound stage shape, for the
/// classifier CLI's sealing pass. Environment: `HL_R16_EXPORT` (the T128
/// export), `HL_R16_ITEMS` (lines `policy_id<TAB>content_file<TAB>seq_dir`;
/// each seq_dir new, made 0700). The export is loaded ONCE (one checkpoint
/// stream: the loader's pass also derives the margin row, which the tied
/// loader reuses); each block once for all items. Prints lengths and times
/// only (no value of the hidden activations, no margin).
///
/// The CLI's parity check against these files is then SELF-consistency (the
/// prover's own builder), not an independent reference; REVIEW_R13 §2 is the
/// independent parity of record (layers 0 and 25 on real rows).
#[test]
#[ignore = "real Shieldstral export via HL_R16_EXPORT / HL_R16_ITEMS; streams the checkpoint once; guarded"]
fn r16_write_item_activations() {
    use std::io::Write;
    use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
    let t0 = std::time::Instant::now();
    let export = PathBuf::from(std::env::var("HL_R16_EXPORT").expect("HL_R16_EXPORT"));
    let items_file = std::env::var("HL_R16_ITEMS").expect("HL_R16_ITEMS");
    let p = super::classify_cli::load_export(&export).expect("the export (one checkpoint stream)");
    eprintln!("R16-ACT | loaded {} layers, profile {}, {:.1} s", p.layers.len(), p.profile, t0.elapsed().as_secs_f64());
    let mut items = Vec::new();
    for line in std::fs::read_to_string(&items_file).unwrap().lines().filter(|l| !l.trim().is_empty()) {
        let f: Vec<&str> = line.split('\t').collect();
        assert_eq!(f.len(), 3, "policy<TAB>content_file<TAB>seq_dir");
        let policy = policy_by_id(f[0]).unwrap();
        let ids: Vec<u64> = std::fs::read_to_string(f[1]).unwrap().split(|c: char| c == ',' || c.is_whitespace()).filter(|s| !s.is_empty()).map(|s| s.parse().unwrap()).collect();
        let bound = super::classify_tied::load_tied_classifier_tables(&p, &export, &export.join("token_io"), &policy).expect("the tied tables (the loader's derivation reused)");
        let cp = ClassifierProfile::new(&p.sh, bound.tables(), bound.bos(), bound.norm(), &policy, ids.len(), Tier::R1_MVP).unwrap();
        let tokens = cp.tokens_of(&ids).unwrap();
        let (_, b_in, _) = super::stage_in_c::honest_inputs(&cp, bound.tables(), &tokens).unwrap();
        let x: Vec<i16> = (0..p.sh.tokens).flat_map(|t| (0..p.sh.width).map(move |i| (t, i))).map(|(t, i)| b_in[t * p.sh.d_pad + i]).collect();
        std::fs::DirBuilder::new().mode(0o700).create(f[2]).expect("a NEW seq dir");
        items.push((PathBuf::from(f[2]), x, ids.len()));
        drop(bound);
        eprintln!("R16-ACT | item {}: n {}, {:.1} s", items.len() - 1, cp.n, t0.elapsed().as_secs_f64());
    }
    let write = |dir: &std::path::Path, name: String, v: &[i16]| {
        let mut f = std::fs::OpenOptions::new().write(true).create_new(true).mode(0o600).open(dir.join(name)).unwrap();
        f.write_all(&v.iter().flat_map(|w| w.to_le_bytes()).collect::<Vec<u8>>()).unwrap();
    };
    let mut blocks = super::load::ExportTokenBlocks::new(&p);
    let ids = super::super::layout::Ids::new(&p.sh).unwrap();
    for (k, r) in p.model.layers.iter().enumerate() {
        let ssh = r.shape_at(&p.sh).unwrap();
        let blk = super::run::TokenBlocks::block(&mut blocks, k).unwrap();
        blk.check_for_shape(&ssh).unwrap();
        for (dir, x, _) in items.iter_mut() {
            let w = super::super::witness::build_for_block(&ssh, &blk, &x[..]).unwrap();
            let out: Vec<i16> = w.planes[ids.at(super::super::layout::A_X2)].iter().map(|v| i16::try_from(*v).unwrap()).collect();
            drop(w);
            let next: Vec<i16> = (0..p.sh.tokens).flat_map(|t| (0..p.sh.width).map(move |i| (t, i))).map(|(t, i)| out[t * p.sh.d_pad + i]).collect();
            write(dir, format!("x_in_L{:02}.bin", p.layers[k]), &x[..]);
            write(dir, format!("x_out_L{:02}.bin", p.layers[k]), &next);
            *x = next;
        }
        eprintln!("R16-ACT | layer {} (G {:?}) done for {} items, {:.1} s", p.layers[k], r.accuracy_gate_shift, items.len(), t0.elapsed().as_secs_f64());
    }
    eprintln!("R16-ACT | {} items x {} layers written in {:.1} s", items.len(), p.layers.len(), t0.elapsed().as_secs_f64());
}
