//! **[A25] THE W16R2 DEVELOPMENT CLASSIFIER PROFILE.** TEST CODE ONLY. A child of
//! `classify_w16r2.rs` (one `#[cfg(test)] #[path]` line at its end).
//!
//! * The development run profile is on no registered list, names exactly its W16R2 block
//!   shape (CS-7 refuses the R13 shape under it and the W16R2 shape under the R13 profile),
//!   has the R13 classifier's tied source, chunk plan and D27 floor, clears 95 bits at L = 26
//!   with its blocks priced at the unique-decoding radius, has no D55 profile, and a blocks-only
//!   run statement refuses it.
//! * The switch's seed map takes the registered R13 Shieldstral T128 seed (and, in test builds,
//!   the R13 rung) to its W16R2 twin, every geometry field equal, and refuses every other seed.
//! * On the public R13 loader fixture: the W16R2 digest pass loads the SAME blocks (the same
//!   digests) as the R13 one, under its own trained statement identity.
//! * At the W16R2 rung (two stages, two gate denominators): the run proves, a fresh statement
//!   verifies it, the owner's check passes, and the verdict and every boundary plane equal the
//!   R13 rung run's on the same content. Negative controls: a changed byte, the R13 statement
//!   over the W16R2 segments, the W16R2 statement over the R13 segments, the other verdict.
//! * The switch on an export with no W16R2 twin (the legacy development rung) refuses the
//!   servers' startup and the CLI's commands; without the switch the same fixture proves and
//!   verifies as before.

use super::*;
use crate::private_block::run::{self as prun, RunShape, RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, RUN_PROFILE_CLASSIFY_W16R2_RUNG_H24_TEST, RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV};
use crate::private_block::shape::{self as pshape, ColumnRegime};
use crate::private_block::token_io::classify_tied::{BoundClassifierTables, TiedSource};
use crate::private_block::token_io::run::VerifierPolicy;
use crate::private_block::trained_block::{Constants, TrainedExport};
use crate::private_block::trained_statement::{IntegerCalibration, LayerRecord, Provenance, TrainedModelStatement};
use crate::private_block::BlockPublic;
use std::path::PathBuf;

const MIN_BITS: VerifierPolicy = VerifierPolicy { min_whole_run_bits: 95 };

fn s(v: &[&str]) -> Vec<String> {
    v.iter().map(|x| x.to_string()).collect()
}

fn fixtures() -> PathBuf {
    std::env::var_os("HL_R13_LOADER_FIXTURES").map(PathBuf::from).unwrap_or_else(|| std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../loader-fixtures"))
}

fn shieldstral(block: &str) -> Shape {
    Shape::accuracy_trained(block, &r13_census_calibration(), 9, 20).unwrap()
}

// ------------------------------------------------------------------ the registry

#[test]
fn a25_the_w16r2_dev_profile_is_unregistered_and_names_only_its_w16r2_block_shape() {
    let (w, r) = (shieldstral(pshape::W16R2_SHIELD_T128_H24), shieldstral(pshape::R13_SHIELD_T128_H24));
    assert!(pshape::is_w16r2_profile(w.profile) && (w.inv_rate, w.opened_cols, w.endpoint_inv_rate) == (2, 280, 2));
    // on no registered list; a classifier run profile of this build all the same
    assert!(!prun::CLASSIFY_RUN_PROFILES.contains(&RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV));
    assert!(!prun::ACCURACY_CLASSIFY_RUN_PROFILES.iter().any(|(a, b)| *a == RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV || *b == w.profile));
    assert!(!prun::ACCURACY_RUN_PROFILES.iter().any(|(a, b)| *a == RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV || *b == w.profile));
    assert!(prun::is_classify_run_profile(RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV) && is_dev(RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV));
    assert!(!is_dev(RUN_PROFILE_CLASSIFY_R13_SHIELD_T128));
    assert!(prun::d55_run_profile(RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV).is_none(), "a D55 profile over the development classifier");
    assert_eq!(RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV.len(), RUN_PROFILE_CLASSIFY_R13_SHIELD_T128.len());
    // CS-7: the W16R2 shape under its profile only
    RunShape::new(w.clone(), 26, RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV).expect("the W16R2 shape under the development profile");
    let e = RunShape::new(r.clone(), 26, RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV).err().expect("THE R13 SHAPE WAS ADMITTED UNDER THE W16R2 DEVELOPMENT PROFILE");
    assert!(e.contains("CS-7"), "{e}");
    let e = RunShape::new(w.clone(), 26, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128).err().expect("THE W16R2 SHAPE WAS ADMITTED UNDER THE R13 PROFILE");
    assert!(e.contains("CS-7"), "{e}");
    // the R13 classifier's tied source, chunk plan and D27 floor
    assert_eq!(TiedSource::of_run_profile(RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV).unwrap(), TiedSource::Shieldstral);
    assert_eq!(TiedSource::of(w.profile).unwrap(), TiedSource::Shieldstral);
    assert_eq!(chunk_overlap_of(RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV).unwrap(), chunk_overlap_of(RUN_PROFILE_CLASSIFY_R13_SHIELD_T128).unwrap());
    assert_eq!(crate::private_block::token_io::classify_tied::min_bits_floor(RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV), 95);
    assert_eq!(w16r2_dev_run_profile_of(&w).unwrap(), RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV);
    assert!(w16r2_dev_run_profile_of(&r).is_err());
    // the whole-run figure at L = 26, the blocks and boundaries priced at the unique-decoding radius
    let (st, _, _) = census_classify_statement(RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV, 26);
    let (r13, _, _) = census_classify_statement(RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, 26);
    let (wr, rr) = (st.whole_run(), r13.whole_run());
    assert!(wr.floor_bits >= 95, "the W16R2 development profile's whole-run floor {} is below D27's 95", wr.floor_bits);
    assert_eq!((wr.block_regime, wr.block_regime_openings), (ColumnRegime::UniqueDecoding, 3 * 26 + 1));
    assert_eq!(rr.block_regime, ColumnRegime::GeneralCode);
    let line = st.parameter_line().unwrap();
    assert!(line.contains("at-the-unique-decoding-radius-d59") && line.contains(&format!("whole-run-floor-{}-bits", wr.floor_bits)), "{line}");
    assert_ne!(st.transcript().unwrap().state(), r13.transcript().unwrap().state(), "the two profiles' run headers are one transcript");
    // a blocks-only run statement may not carry it
    let model = r13_synthetic_model(&w, RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV, &[20; 2], [9; 32], 1.0 / 512.0);
    let spec = crate::private_block::IoSpec::new_shaped(&w, [5; 32], 0, 0).unwrap();
    let e = prun::RunStatement::new_bound_from_digests(
        RunShape::new(w.clone(), 2, RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV).unwrap(),
        [5; 32],
        crate::private_block::ExpectedIo::from_roots(spec, [1; 32], [2; 32]),
        model.layers.iter().map(|r| r.block_digest).collect(),
        &[crate::private_block::ENDPOINT_SCALES; 2],
        &model,
    )
    .err()
    .expect("A BLOCKS-ONLY RUN CARRIED THE W16R2 DEVELOPMENT CLASSIFIER PROFILE");
    assert!(e.contains("classifier run profile"), "{e}");
    eprintln!(
        "A25 | registry | {RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV}: unregistered, CS-7 at W16R2_SHIELD_T128_H24 only; L26 whole-run 2^{:.2} floor {} bits (R13: 2^{:.2}, floor {}), {} openings, {} at the unique-decoding radius",
        wr.total_log2, wr.floor_bits, rr.total_log2, rr.floor_bits, wr.openings, wr.block_regime_openings
    );
}

#[test]
fn a25_the_switch_maps_only_an_admitted_r13_seed_to_its_w16r2_twin() {
    let seed = Shape::accuracy_trained(pshape::R13_SHIELD_T128_H24, &r13_census_calibration(), 9, 17).unwrap();
    let twin = w16r2_dev_seed_of(&seed).expect("the R13 Shieldstral T128 seed's W16R2 twin");
    assert_eq!(twin.profile, pshape::W16R2_SHIELD_T128_H24);
    assert_eq!((twin.norm_calibration(), twin.f_e, twin.accuracy_gate_shift, twin.tokens, twin.width, twin.hidden), (seed.norm_calibration(), seed.f_e, seed.accuracy_gate_shift, seed.tokens, seed.width, seed.hidden));
    assert_eq!((twin.inv_rate, twin.opened_cols, seed.inv_rate, seed.opened_cols), (2, 280, 4, 256));
    // the run shape the twin is registered at is exactly the twin (CS-7 compares every field)
    RunShape::new(twin.clone(), 26, w16r2_dev_run_profile_of(&twin).unwrap()).unwrap();
    // every other seed is refused by name
    let others = [
        Shape::accuracy_trained(pshape::R13_SHIELD_T256_H24, &r13_census_calibration(), 9, 17).unwrap(),
        Shape::accuracy_trained(pshape::W16_SHIELD_T128_H24, &r13_census_calibration(), 9, 17).unwrap(),
        twin.clone(),
        Shape::rung_tc(&crate::private_block::trained_calib_tests::rung_tc_calibration()).unwrap(),
    ];
    for o in others {
        let e = w16r2_dev_seed_of(&o).err().unwrap_or_else(|| panic!("{} WAS MAPPED TO A W16R2 TWIN", o.profile));
        assert!(e.contains(DEV_W16R2_SWITCH) && e.contains("no W16R2 development twin"), "{e}");
    }
    eprintln!("A25 | seed map | R13_SHIELD_T128_H24 -> W16R2_SHIELD_T128_H24 (rate 1/4 Q 256 -> 1/2 Q 280, every geometry field equal); T256, W16, W16R2 itself and the legacy rung refused");
}

// ------------------------------------------------------------------ the export load

/// a fixture export's digest pass under the R13 rung test profile (the R13 side of the pair)
fn r13_rung_profile_of(sh: &Shape) -> Result<&'static str, String> {
    assert_eq!(sh.profile, pshape::R13_RUNG_H24);
    Ok(RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST)
}

#[test]
fn a25_the_w16r2_digest_pass_loads_the_same_blocks_under_its_own_identity() {
    let path = fixtures().join("r13-h24-wide");
    assert!(path.join("profile.json").exists(), "the R13 loader fixture {} is missing: set HL_R13_LOADER_FIXTURES", path.display());
    let (r13, rb) = ExportPublic::load_keeping(&path, r13_rung_profile_of, true).unwrap();
    let (w16, wb) = load_export_w16r2(&path, true).unwrap();
    // the R13 path is load_keeping_at with the seed itself: the same statement as the earlier loader
    let r13_again = ExportPublic::load_with(&path, r13_rung_profile_of).unwrap();
    assert_eq!(r13.model.identity(), r13_again.model.identity());
    assert_eq!((r13.sh.profile, w16.sh.profile), (pshape::R13_RUNG_H24, pshape::W16R2_RUNG_H24));
    assert_eq!((r13.profile, w16.profile), (RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST, RUN_PROFILE_CLASSIFY_W16R2_RUNG_H24_TEST));
    assert_eq!(r13.digests, w16.digests, "the W16R2 pass loaded other blocks");
    assert_eq!(rb.len(), wb.len());
    for (a, b) in rb.iter().zip(wb.iter()) {
        assert_eq!(a.digest(), b.digest());
    }
    assert_eq!(r13.layers, w16.layers);
    assert_ne!(r13.model.identity(), w16.model.identity(), "the two profiles share a trained statement identity");
    assert_eq!((w16.model.block_profile.as_str(), w16.model.run_profile.as_str()), (pshape::W16R2_RUNG_H24, RUN_PROFILE_CLASSIFY_W16R2_RUNG_H24_TEST));
    assert_eq!(r13.model.layers, w16.model.layers, "the layer records moved");
    eprintln!("A25 | digest pass | r13-h24-wide: the W16R2 pass keeps the R13 pass's {} blocks (equal digests); identities R13 {} / W16R2 {}", wb.len(), hex(&r13.model.identity()), hex(&w16.model.identity()));
}

// ------------------------------------------------------------------ the W16R2 rung run

/// the R13 h24 rung fixture as TWO layers with DIFFERENT gate denominators (`classify_r16_tests`'
/// construction), the export's constants, the R13 seed, the blocks and records
fn two_stage_fixture() -> (TrainedExport, Constants, Shape, Vec<BlockPublic>, Vec<LayerRecord>) {
    use crate::private_block::accuracy_public::AccuracyPublic;
    let path = fixtures().join("r13-h24-wide");
    assert!(path.join("profile.json").exists(), "the R13 loader fixture {} is missing: set HL_R13_LOADER_FIXTURES", path.display());
    let mut ex = TrainedExport::load(&path).unwrap();
    ex.source.checkpoint_layers = 2;
    let c = ex.run_constants(&[0]).unwrap();
    let seed = ex.shape_for(&c).unwrap();
    assert_eq!(seed.profile, pshape::R13_RUNG_H24);
    let first = ex.load_layer(&seed, &c, 0, false).unwrap();
    let a = first.blk.accuracy().unwrap();
    let changed = AccuracyPublic::new(a.stack(), a.geometry(), a.base(), (-4, -13), a.multipliers().clone(), a.groups().to_vec(), a.group_ids().to_vec(), a.raw_tables().to_vec()).unwrap();
    let second = first.blk.clone().with_accuracy(changed);
    let mut r2 = LayerRecord::of_block(1, &second, vec![]);
    r2.manifest_sha256 = [53; 32];
    let r1 = first.record.clone();
    assert_ne!(r1.accuracy_gate_shift, r2.accuracy_gate_shift);
    (ex, c, seed, vec![first.blk, second], vec![r1, r2])
}

fn model_under(ex: &TrainedExport, c: &Constants, seed: &Shape, profile: &str, records: Vec<LayerRecord>) -> TrainedModelStatement {
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
    TrainedModelStatement::new_with_tied(seed, profile, ex.source.clone(), IntegerCalibration::as_the_code_proves(seed, &prov), records, None).expect("the rung's trained statement")
}

fn bound_for(seed: &Shape, profile: &str, model: &TrainedModelStatement) -> BoundClassifierTables {
    use crate::private_block::token_io::tests::{generic_tables, lcg, norm};
    let tt = generic_tables(seed.width, 0x7231_3672);
    let mut s = 0x6d61_7267_696eu64;
    let w: Vec<i16> = (0..seed.width).map(|_| (lcg(&mut s) % 20_001) as i16 - 10_000).collect();
    let tables = ClassifierTables::new(tt.v, tt.d, tt.emb, w).unwrap();
    BoundClassifierTables::synthetic_for_relation_tests(tables, 1, norm(), seed, profile, model, &policy_rung_dev()).unwrap()
}

fn content() -> Vec<u64> {
    let mut s = 0x7231_3663u64;
    (0..20).map(|_| 5 + crate::private_block::token_io::tests::lcg(&mut s) % 295).collect()
}

/// one profile's side of the pair: its seed, run profile, trained statement and tables
struct Side {
    seed: Shape,
    profile: &'static str,
    model: TrainedModelStatement,
    bound: BoundClassifierTables,
}

fn side(ex: &TrainedExport, c: &Constants, seed: &Shape, profile: &'static str, records: &[LayerRecord]) -> Side {
    let model = model_under(ex, c, seed, profile, records.to_vec());
    let bound = bound_for(seed, profile, &model);
    Side { seed: seed.clone(), profile, model, bound }
}

struct Proved {
    st: ClassifyRunStatement,
    segments: Vec<Vec<u8>>,
    dec: Decommitment,
    planes: Vec<Vec<i16>>,
    verdict: u8,
    prove_s: f64,
}

fn statement(sd: &Side, n: usize, root: Digest, verdict: u8) -> Result<ClassifyRunStatement, String> {
    let digests: Vec<Digest> = sd.model.layers.iter().map(|r| r.block_digest).collect();
    ClassifyRunStatement::new(RunShape::new(sd.seed.clone(), sd.model.layers.len(), sd.profile)?, crate::private_block::token_io::tests::ctx(), digests, &sd.model, &sd.bound, &policy_rung_dev(), n, Tier::R1_MVP, root, verdict)
}

fn prove_honest(sd: &Side, blocks: &[BlockPublic], c: &[u64]) -> Proved {
    let cp = ClassifierProfile::new(&sd.seed, sd.bound.tables(), sd.bound.bos(), sd.bound.norm(), &policy_rung_dev(), c.len(), Tier::R1_MVP).unwrap();
    let tokens = cp.tokens_of(c).unwrap();
    let shapes: Vec<Shape> = sd.model.layers.iter().map(|r| r.shape_at(&sd.seed).unwrap()).collect();
    let mut honest = honest_classify(&shapes, &cp, sd.bound.tables(), blocks, &tokens).unwrap();
    let planes = honest.planes.clone();
    let verdict = honest.out_values.verdict;
    let spec = input_endpoint_spec(&sd.seed, crate::private_block::token_io::tests::ctx(), &cp).unwrap();
    let (root, owner) = seal_input(&spec, &honest.in_plane, &sd.seed.hash_tag()).unwrap();
    let st = statement(sd, c.len(), root, verdict).unwrap();
    let mut segments = Vec::new();
    let t = std::time::Instant::now();
    let (_, dec) = prove_classify_run(&st, blocks, &sd.bound, &mut ClassifySource(&mut honest), owner, &mut |k, b| {
        assert_eq!(k, segments.len());
        segments.push(b);
        Ok(())
    })
    .unwrap();
    Proved { st, segments, dec, planes, verdict, prove_s: t.elapsed().as_secs_f64() }
}

#[test]
fn a25_a_w16r2_rung_classify_run_proves_verifies_equals_the_r13_verdict_and_refuses_the_controls() {
    let (ex, c, r13_seed, blocks, records) = two_stage_fixture();
    let w16_seed = w16r2_dev_seed_of(&r13_seed).expect("the R13 rung seed's W16R2 twin");
    assert_eq!(w16_seed.profile, pshape::W16R2_RUNG_H24);
    let r13 = side(&ex, &c, &r13_seed, RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST, &records);
    let w16 = side(&ex, &c, &w16_seed, RUN_PROFILE_CLASSIFY_W16R2_RUNG_H24_TEST, &records);
    assert_ne!(r13.model.identity(), w16.model.identity());
    let item = content();
    let pr = prove_honest(&r13, &blocks, &item);
    let pw = prove_honest(&w16, &blocks, &item);
    // the same model arithmetic: the same boundary planes and the same public verdict
    assert_eq!(pr.planes, pw.planes, "a W16R2 block computed another plane than its R13 twin");
    assert_eq!(pr.verdict, pw.verdict);
    assert_eq!(pw.segments.len(), 4);
    for k in 0..2 {
        let ssh = pw.st.stage_shape(k).unwrap();
        assert!(pshape::is_w16r2_profile(ssh.profile) && ssh.accuracy_gate_shift == pr.st.stage_shape(k).unwrap().accuracy_gate_shift);
    }
    // a fresh verifier's statement from the public inputs alone accepts the W16R2 run
    let fresh = side(&ex, &c, &w16_seed, RUN_PROFILE_CLASSIFY_W16R2_RUNG_H24_TEST, &records);
    let fst = statement(&fresh, item.len(), pw.st.in_root(), pw.st.verdict()).unwrap();
    assert!(fst.whole_run().floor_bits >= 95, "the W16R2 rung's whole-run floor is {}", fst.whole_run().floor_bits);
    let t = std::time::Instant::now();
    verify_classify_run(&fst, &blocks, &fresh.bound, &pw.segments, MIN_BITS).expect("the honest W16R2 classifier run verifies");
    let verify_s = t.elapsed().as_secs_f64();
    owner_check_input(&fst, &pw.dec, &item).expect("the input owner's check");
    // and the R13 run verifies under its own (unchanged path)
    let rst = statement(&side(&ex, &c, &r13_seed, RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST, &records), item.len(), pr.st.in_root(), pr.st.verdict()).unwrap();
    verify_classify_run(&rst, &blocks, &r13.bound, &pr.segments, MIN_BITS).expect("the R13 run verifies");
    // ---- negative controls
    // (1) a changed byte of a block segment
    let mut bad = pw.segments.clone();
    let mid = bad[2].len() / 2;
    bad[2][mid] ^= 1;
    assert!(verify_classify_run(&fst, &blocks, &fresh.bound, &bad, MIN_BITS).is_err(), "A CHANGED W16R2 BLOCK SEGMENT VERIFIED");
    // (2) the R13 statement over the W16R2 segments, and (3) the reverse
    let x = statement(&r13, item.len(), pw.st.in_root(), pw.st.verdict()).unwrap();
    assert!(verify_classify_run(&x, &blocks, &r13.bound, &pw.segments, MIN_BITS).is_err(), "AN R13 VERIFIER ACCEPTED A W16R2 RECEIPT");
    let y = statement(&w16, item.len(), pr.st.in_root(), pr.st.verdict()).unwrap();
    assert!(verify_classify_run(&y, &blocks, &w16.bound, &pr.segments, MIN_BITS).is_err(), "A W16R2 VERIFIER ACCEPTED AN R13 RECEIPT");
    // (4) the other verdict (the header absorbs it)
    let z = statement(&fresh, item.len(), pw.st.in_root(), 1 - pw.st.verdict()).unwrap();
    assert!(verify_classify_run(&z, &blocks, &fresh.bound, &pw.segments, MIN_BITS).is_err(), "THE OTHER VERDICT VERIFIED");
    // (5) the W16R2 tables handed to the R13 statement (bound to another trained statement)
    assert!(verify_classify_run(&rst, &blocks, &w16.bound, &pr.segments, MIN_BITS).is_err(), "TABLES BOUND TO THE W16R2 STATEMENT WERE ACCEPTED BY THE R13 ONE");
    let (rb, wb): (usize, usize) = (pr.segments.iter().map(Vec::len).sum(), pw.segments.iter().map(Vec::len).sum());
    let (rblk, wblk) = (pr.segments[1].len() + pr.segments[2].len(), pw.segments[1].len() + pw.segments[2].len());
    eprintln!(
        "A25 | W16R2 rung | two stages: prove {:.2} s (R13 {:.2} s), fresh verify {verify_s:.2} s; receipt {wb} B (R13 {rb} B), block segments {wblk} B (R13 {rblk} B); the same planes and verdict as R13; changed byte, R13-over-W16R2, W16R2-over-R13, other verdict, crossed tables: refused",
        pw.prove_s, pr.prove_s
    );
}

// ------------------------------------------------------------------ the switch on another export

/// the switch on an export with no W16R2 twin (the legacy development rung) refuses the servers'
/// startup and the CLI's prove and verify; the same fixture without the switch proves and
/// verifies as before
#[test]
fn a25_the_switch_on_an_export_without_a_w16r2_twin_is_refused_and_nothing_else_moves() {
    use super::super::super::classify_cli_tests::{Cc, POLICY_RUNG_DEV};
    let cc = Cc::new("a25-switch");
    let serve = s(&["--export", cc.export.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policies", POLICY_RUNG_DEV, "--lanes", "1", "--lane-threads", "2", DEV_W16R2_SWITCH]);
    let e = super::super::serve::serve_for_tests(&serve, vec![]).err().expect("A SERVER STARTED WITH THE W16R2 SWITCH ON THE LEGACY RUNG");
    assert!(e.contains("no W16R2 development twin"), "{e}");
    let check = s(&["--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policies", POLICY_RUNG_DEV, "--expect-statement", &cc.identity, "--min-bits", "93", DEV_W16R2_SWITCH]);
    let e = super::super::serve::check_serve_for_tests(&check, vec![]).err().expect("A VERIFIER STARTED WITH THE W16R2 SWITCH ON THE LEGACY RUNG");
    assert!(e.contains("no W16R2 development twin"), "{e}");
    // the CLI: prove with the switch is refused and creates nothing
    let out = cc.root.join("a25-switch-run");
    let cf = cc.content_file(&cc.content);
    let od = cc.owner_dir(&out);
    let code = classify_prove_command(&s(&["--export", cc.export.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--content-file", cf.to_str().unwrap(), "--seq", "s0", "--out", out.to_str().unwrap(), "--owner-dir", od.to_str().unwrap(), DEV_W16R2_SWITCH]));
    assert_ne!(code, 0, "a prove with the W16R2 switch on the legacy rung succeeded");
    assert!(!out.exists() && !od.exists(), "a refused W16R2 prove left directories behind");
    // without the switch: the same fixture proves; verify with the switch refuses the R13 run, without accepts it
    assert_eq!(cc.prove(&out, &cc.tables), 0);
    let with = classify_verify_command(&s(&["--export", cc.verifier_copy.to_str().unwrap(), "--tables", cc.tables.to_str().unwrap(), "--policy", POLICY_RUNG_DEV, "--artifact", out.to_str().unwrap(), "--expect-statement", &cc.identity, "--min-bits", "93", DEV_W16R2_SWITCH]));
    assert_ne!(with, 0, "verify with the W16R2 switch accepted a legacy rung run");
    assert_eq!(cc.verify(&out, &cc.tables), 0, "the unchanged verify");
    eprintln!("A25 | switch | on the legacy rung: serve and check-serve refuse to start, prove refuses and creates nothing, verify refuses; without it the fixture proves and verifies");
}


// [A30] parallel BLAKE3 tree-digest tests for Words16Le, Words64Le, TokenTables, ClassifierTables, and BlockPublic
#[test]
fn a30_words16_and_words64_unaligned_subtrees_match_blake3_hash_byte_for_byte() {
    use crate::private_block::{a21_tree_digest, A21Piece, A21_LEAF};
    let w16: Vec<i16> = (0..1_200_003i64).map(|i| ((i * 31337 - 99991) & 0xffff) as u16 as i16).collect();
    let w64: Vec<i64> = (0..300_005i64).map(|i| i.wrapping_mul(-0x517cc1b727220a95).wrapping_add(0x1234_5678_9abc_def0)).collect();
    let w8: Vec<i8> = (0..50_021i64).map(|i| ((i * 73 + 19) & 0xff) as u8 as i8).collect();
    for pad_len in 0..17usize {
        let prefix: Vec<u8> = (0..pad_len).map(|k| (k as u8).wrapping_mul(37).wrapping_add(5)).collect();
        let mut ref_bytes = Vec::with_capacity(prefix.len() + w16.len() * 2 + 3 + w64.len() * 8 + w8.len());
        ref_bytes.extend_from_slice(&prefix);
        for v in &w16 {
            ref_bytes.extend_from_slice(&v.to_le_bytes());
        }
        ref_bytes.extend_from_slice(b"xyz");
        for v in &w64 {
            ref_bytes.extend_from_slice(&v.to_le_bytes());
        }
        for v in &w8 {
            ref_bytes.push(*v as u8);
        }
        let expected = *blake3::hash(&ref_bytes).as_bytes();
        for leaf in [1024u64, 4096, A21_LEAF] {
            let got = a21_tree_digest(
                vec![
                    A21Piece::Bytes(prefix.clone()),
                    A21Piece::Words16Le(&w16),
                    A21Piece::Borrowed(b"xyz"),
                    A21Piece::Words64Le(&w64),
                    A21Piece::Words(&w8),
                ],
                leaf,
            );
            assert_eq!(got, expected, "a30 tree digest mismatch at pad_len={pad_len}, leaf={leaf}");
        }
    }
}

#[test]
fn a30_table_and_block_digests_are_identical_with_switch_on_and_off() {
    use crate::private_block::token_io::classify::ClassifierTables;
    use crate::private_block::token_io::TokenTables;
    use crate::private_block::{set_a21_b3par_for_test, set_a30_b3par_for_test, BlockPublic};

    let (v, d) = (1024usize, 768usize); // emb = 1.5 MiB > A21_LEAF (1 MiB), exercises multi-subtree rayon merge
    let emb: Vec<i16> = (0..(v * d)).map(|i| ((i as i64 * 17 - 5000) & 0xffff) as u16 as i16).collect();
    let head: Vec<i8> = (0..(v * d)).map(|i| ((i as i64 * 29 + 3) & 0xff) as u8 as i8).collect();
    let mult: Vec<i64> = (0..v).map(|i| (i as i64 + 1) * -123456789).collect();
    let w_delta: Vec<i16> = (0..d).map(|i| (i as i16).wrapping_mul(-13)).collect();

    let tt = TokenTables::new(v, d, emb.clone(), head, mult).expect("valid token tables");
    let ct = ClassifierTables::new(v, d, emb, w_delta).expect("valid classifier tables");
    let (blk, _) = BlockPublic::synthetic_fixture();

    set_a30_b3par_for_test(Some(false));
    set_a21_b3par_for_test(Some(false));
    let tt_emb_seq = tt.emb_digest();
    let tt_head_seq = tt.head_digest();
    let ct_emb_seq = ct.emb_digest();
    let ct_w_seq = ct.w_digest();
    let blk_seq = blk.digest();

    set_a30_b3par_for_test(Some(true));
    set_a21_b3par_for_test(Some(true));
    let tt_emb_par = tt.emb_digest();
    let tt_head_par = tt.head_digest();
    let ct_emb_par = ct.emb_digest();
    let ct_w_par = ct.w_digest();
    let blk_par = blk.digest();
    let blk_1k = blk.a21_digest_tree(1024);

    set_a30_b3par_for_test(None);
    set_a21_b3par_for_test(None);

    assert_eq!(tt_emb_par, tt_emb_seq, "TokenTables::emb_digest moved under HL_A30_B3PAR");
    assert_eq!(tt_head_par, tt_head_seq, "TokenTables::head_digest moved under HL_A30_B3PAR");
    assert_eq!(ct_emb_par, ct_emb_seq, "ClassifierTables::emb_digest moved under HL_A30_B3PAR");
    assert_eq!(ct_w_par, ct_w_seq, "ClassifierTables::w_digest moved under HL_A30_B3PAR");
    assert_eq!(blk_par, blk_seq, "BlockPublic::digest moved under Words16Le/Words64Le");
    assert_eq!(blk_1k, blk_seq, "BlockPublic::a21_digest_tree(1024) moved under Words16Le/Words64Le");
}
