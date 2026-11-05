//! **D65(1), finding F12: the receipt-level version checks.** `M`'s theta powers start at theta^1
//! (`zk::combined_weights`), and every profile whose receipts carry an `M` opening was given its version one
//! higher (`…/1` → `…/2`; `results/zk60_f12_fix_20261104/`). These tests check, on real private-block receipts:
//!
//! * a receipt made under the NEW version verifies, and does not verify under the OLD one — neither under the
//!   old string (refused by name: the string is retired) nor under the old `M` (theta^0, through the test build's
//!   hook), which refuses it at `M`'s sum check;
//! * the reverse: the old string cannot be proved under at all, and a receipt whose `M` was opened the pre-F12
//!   way is refused by this build's verifier at `M` (while the pre-F12 verifier accepts it, so the refusal is the
//!   version's and not a broken receipt's);
//! * every pre-F12 string of the registered block and run profiles reached here is refused at CS-9 / CS-7 in
//!   this (test) build, and its successor is admitted.
//!
//! Test code only. Public synthetic data only.

use super::layout::*;
use super::protocol::prove_inner_at;
use super::run::RunShape;
use super::shape::{self, NormCalibration, Shape};
use super::witness::{self, Witness};
use super::*;

fn context() -> Digest {
    *blake3::hash(b"private block: D65(1) F12 cross-version receipts").as_bytes()
}

/// the frozen-seam development rung, honest (the review's harness)
fn honest_rung() -> (Shape, BlockPublic, Witness) {
    let sh = Shape::rung();
    let (public, ff, input) = super::grow_tests::tame_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung's honest witness");
    (sh, BlockPublic::new(public, ff), w)
}

fn prove_rung(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<(ExpectedIo, Vec<u8>), String> {
    let ids = Ids::new(sh)?;
    let plane = |p: usize| -> Result<Vec<i16>, String> { w.planes[p].iter().map(|v| i16::try_from(*v).map_err(|_| "an endpoint word outside int16".to_string())).collect() };
    let (pin, pout) = (plane(ids.at(A_X))?, plane(ids.at(A_X2))?);
    let spec = IoSpec::new_shaped(sh, context(), 0, 0)?;
    let (expected, owners) = prepare_endpoints(spec, &pin, &pout)?;
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners)?;
    let bytes = receipt.to_bytes_at(sh, blk, &expected)?;
    Ok((expected, bytes))
}

/// Run `f` with this thread's `M` on the pre-F12 theta^0 start; the hook is reset afterwards, also on a panic.
fn pre_f12<T>(f: impl FnOnce() -> T) -> T {
    struct Reset;
    impl Drop for Reset {
        fn drop(&mut self) {
            crate::zk::set_pre_f12_theta_start_for_tests(false);
        }
    }
    let _reset = Reset;
    crate::zk::set_pre_f12_theta_start_for_tests(true);
    f()
}

/// The pre-F12 version of a current profile string (`…/2` → `…/1`), as a `'static` string a `Shape` can carry.
fn pre_f12_of(profile: &str) -> &'static str {
    let stem = profile.strip_suffix("/2").unwrap_or_else(|| panic!("{profile}: not a version-2 profile string"));
    Box::leak(format!("{stem}/1").into_boxed_str())
}

#[test]
fn f12_a_receipt_under_the_new_version_does_not_verify_under_the_old_one() {
    let (sh, blk, w) = honest_rung();
    assert!(sh.profile.ends_with("/2"), "the rung is not at the post-F12 version: {}", sh.profile);
    let (expected, bytes) = prove_rung(&sh, &blk, w).expect("the honest rung receipt under the new version");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the new receipt verifies under the new version");
    // the old STRING: refused by name before anything is read from the frame
    let old = Shape { profile: pre_f12_of(sh.profile), ..sh.clone() };
    let e = verify_bytes_at(&old, &blk, &expected, &bytes).expect_err("the new receipt verified under the retired /1 string");
    assert!(e.contains("D65(1)") && e.contains("retired"), "refused, but not as a retired version: {e}");
    eprintln!("F12 receipt: new receipt under the old string -> {e}");
    // the old M (theta^0) under the same string: refused at M's sum check, after every slot has passed
    let e = pre_f12(|| verify_bytes_at(&sh, &blk, &expected, &bytes)).expect_err("the new receipt verified under the pre-F12 M");
    assert!(e.contains("M: mask: the product polynomial's sum"), "refused, but not at M's sum check: {e}");
    eprintln!("F12 receipt: new receipt under the pre-F12 M -> {e}");
    // and nothing leaked: this thread is back on theta^1
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the new receipt still verifies after the hook");
}

#[test]
fn f12_a_receipt_under_the_old_version_does_not_verify_under_the_new_one() {
    let (sh, blk, w) = honest_rung();
    // the old STRING cannot be proved under at all
    let old = Shape { profile: pre_f12_of(sh.profile), ..sh.clone() };
    let e = prove_rung(&old, &blk, w.clone()).expect_err("a receipt was proved under the retired /1 string");
    assert!(e.contains("D65(1)") && e.contains("retired"), "refused, but not as a retired version: {e}");
    eprintln!("F12 receipt: proving under the old string -> {e}");
    // a receipt whose M was opened the pre-F12 way (theta^0): coherent under the pre-F12 verifier, refused by this one
    let (expected, bytes) = pre_f12(|| prove_rung(&sh, &blk, w)).expect("a receipt with a pre-F12 M opening");
    pre_f12(|| verify_bytes_at(&sh, &blk, &expected, &bytes)).expect("the pre-F12 M receipt verifies under the pre-F12 M (the hook reproduces the old build)");
    let e = verify_bytes_at(&sh, &blk, &expected, &bytes).expect_err("a receipt with a pre-F12 M opening verified under theta^1");
    assert!(e.contains("M: mask: the product polynomial's sum"), "refused, but not at M's sum check: {e}");
    eprintln!("F12 receipt: pre-F12 M receipt under the new verifier -> {e}");
}

/// the W16 / W16R2 block shapes at the M4 gate's calibration rule (`slot_ir::accuracy::tests`)
fn w16_family_shapes() -> Vec<Shape> {
    shape::W16_PROFILES
        .iter()
        .chain(shape::W16R2_PROFILES.iter())
        .map(|spec| {
            let cal = NormCalibration { tn: if spec.width >= 3072 { 9 } else { 10 }, cn_a: 100, cn_m: 100, ceps: 1, sh_ao: 7, sh_qkv: 8, sh_s: 6, sh_o: 9, sh_g: 8, sh_h: 14, sh_z: 6 };
            Shape::accuracy_trained(spec.profile, &cal, if spec.tokens == 32 { 12 } else { 9 }, 20).unwrap_or_else(|e| panic!("{}: {e}", spec.name))
        })
        .collect()
}

#[test]
fn f12_every_pre_f12_block_and_run_string_is_refused_and_its_successor_admitted() {
    // blocks: the nine frozen constructors, the twelve R13 accuracy bases, W16 (6) and W16R2 (3)
    let mut blocks = vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()];
    blocks.extend(super::accuracy_profile_tests::registered_shapes());
    blocks.extend(w16_family_shapes());
    for sh in &blocks {
        sh.check_constructed().unwrap_or_else(|e| panic!("{}: the current version is refused: {e}", sh.profile));
        // (a trained shape's CS-9 entry is its GEOMETRY, before the trained door's calibration, so only the frozen
        // shapes are compared whole by the release-build check; the retired strings below are refused before it)
        if !sh.trained_calibration {
            sh.check_block_profile_as_a_release_build().unwrap_or_else(|e| panic!("{}: the current version is refused by a release build: {e}", sh.profile));
        }
        let old = Shape { profile: pre_f12_of(sh.profile), ..sh.clone() };
        for (door, r) in [("CS-8/CS-9 (test build)", old.check_constructed()), ("CS-9 (release build)", old.check_block_profile_as_a_release_build())] {
            let e = r.err().unwrap_or_else(|| panic!("{}: the retired string passed {door}", old.profile));
            assert!(e.contains("D65(1)") && e.contains(sh.profile), "{}: {door} refused it, but not as a retired version naming its successor: {e}", old.profile);
        }
    }
    // runs: the seven frozen-shape run profiles and the twelve R13 runs
    let mut runs: Vec<(&'static str, Shape)> = vec![
        (super::run::RUN_PROFILE_RUNG_G, Shape::rung_g()),
        (super::run::RUN_PROFILE_RUNG_K4, Shape::rung_k4()),
        (super::run::RUN_PROFILE_RUNG_P2, Shape::rung_p2()),
        (super::run::RUN_PROFILE_RUNG_C6, Shape::rung_c6()),
        (super::run::RUN_PROFILE_RUNG_W14, Shape::rung_w14()),
        (super::run::RUN_PROFILE_RUNG_E32, Shape::rung_e32()),
        (super::run::RUN_PROFILE_M125, Shape::m125()),
    ];
    runs.extend(super::accuracy_profile_tests::registered_runs());
    for (run, sh) in &runs {
        let run: &'static str = *run;
        RunShape::new(sh.clone(), 1, run).unwrap_or_else(|e| panic!("{run}: the current version is refused: {e}"));
        let old = pre_f12_of(run);
        let e = RunShape::new(sh.clone(), 1, old).err().unwrap_or_else(|| panic!("{old}: the retired run string passed CS-7"));
        assert!(e.contains("ruling CS-7") && e.contains("D65(1)") && e.contains(run), "{old}: CS-7 refused it, but not as a retired version naming its successor: {e}");
    }
    eprintln!("F12 versions: {} block and {} run pre-F12 strings refused by name; every successor admitted", blocks.len(), runs.len());
    // the twelve registered D55 strings are their base's tail under the marker, so they moved with their bases
    for (d55, base) in super::run::D55_RUN_PROFILES {
        assert!(d55.ends_with("/2") && base.ends_with("/2"), "{d55} / {base}: a registered D55 profile not at version 2");
        assert_eq!(super::run::d55_run_profile(pre_f12_of(base)), None, "{base}: its retired /1 base still names a D55 profile");
    }
}
