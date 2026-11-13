//! **[A25] THE W16R2 DEVELOPMENT CLASSIFIER PROFILE** (lane A25, 2026-11-07, the media app's
//! speed lane; `results/zk60_a25_app_20261107/README.md`). A `#[path]` child of
//! `classify_cli.rs`.
//!
//! The classifier run (stage IN-C, the 26 Shieldstral blocks, stage OUT-C on one transcript,
//! the verdict public) with its BLOCKS at the opt-in, unregistered W16R2 block profile
//! (`shape::W16R2_SHIELD_T128_H24`: D59, W16 at code rate 1/2, `Q = 280`) instead of the
//! registered R13 one (`R13_SHIELD_T128_H24`). The run profile is its own string
//! ([`super::super::super::run::RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV`]), so its own
//! transcript domain, run seed domain and trained statement identity; the stages IN-C and
//! OUT-C, the input endpoint, the policies, the tied tables and the chunk plan are the R13
//! classifier's, unchanged.
//!
//! **How a run gets it.** Only through the explicit switch [`DEV_W16R2_SWITCH`] on `prove`,
//! `verify`, `input-owner`, `label`, `serve` and `check-serve`. With the switch the export's
//! own seed shape (the registered R13 Shieldstral T128 shape) is mapped to its W16R2 twin
//! ([`w16r2_dev_seed_of`]: the same geometry, calibration, `f_e` and gate seed, every field
//! compared) and the digest pass loads every layer through the same checked `load_layer` at
//! that shape (`ExportPublic::load_keeping_at`): the same block objects, the same digests.
//! Without it every command is byte for byte what it was. A verifier must be given the switch
//! to load the export under this profile, and it pins the W16R2 trained statement identity
//! (`--expect-statement`), which names both profiles; an R13 verifier refuses a W16R2 receipt
//! and the reverse (the statement's re-render, then the transcript).
//!
//! **Scope (the rulings this respects).** A DEVELOPMENT profile for PUBLIC development posts
//! of the media app only. It is NOT registered for real content: efficiency plan A10
//! ("register W16R2 for real content") waits for the W16R2 privacy gate on GPU-made bundles,
//! D60's conditions and Victor's ruling. D58's privacy statement covers the named r16b CPU
//! binary only; nothing here is a privacy acceptance, and nothing here is production (D63).
//! The statement says so in its `scope`.

use super::*;
use super::super::super::shape::{W16R2_SHIELD_T128_H24, R13_SHIELD_T128_H24};

/// **the switch** that opts one command into the W16R2 development classifier profile
pub(crate) const DEV_W16R2_SWITCH: &str = "--dev-w16r2-public-content-only";

/// the statement's `scope` under a W16R2 development profile (every other profile keeps the
/// scope it had, byte for byte)
pub(crate) const DEV_SCOPE: &str = "a DEVELOPMENT classifier proof (lane A25) under the UNREGISTERED W16R2 development run profile (blocks at W16R2_SHIELD_T128_H24: D59 rate 1/2, Q 280): for PUBLIC development content only; not registered for real content (efficiency plan A10 awaits the W16R2 privacy gate on GPU-made bundles, D60's conditions and Victor's ruling); the approved integer model's verdict on the content under a pre-registered policy; the margin row and the embedding re-derived from the pinned tied tensor; one external endpoint; the verdict bit and the content length are public (D45); NOT a privacy acceptance; not production (D63)";

/// the W16R2 twin of each R13 seed this switch admits (the export's own block profile, then
/// the block profile the development run is proved at)
fn twins() -> Vec<(&'static str, &'static str)> {
    #[allow(unused_mut)]
    let mut v = vec![(R13_SHIELD_T128_H24, W16R2_SHIELD_T128_H24)];
    // test builds: the R13 h24 development rung's W16R2 twin (the public R13 loader fixture)
    #[cfg(test)]
    v.push((super::super::super::shape::R13_RUNG_H24, super::super::super::shape::W16R2_RUNG_H24));
    v
}

/// **the export's seed mapped to its W16R2 twin**: the export's own seed must be an R13 shape
/// this switch admits; the twin is built through the same R13 door (`Shape::accuracy_trained`)
/// at the seed's calibration, `f_e` and gate seed, passes the trained class, and must equal
/// the seed in every field but the profile, the name and the PCS's rate and `Q` (refused by
/// name otherwise, before any layer is read)
pub(crate) fn w16r2_dev_seed_of(seed: &Shape) -> Result<Shape, String> {
    let block = twins().into_iter().find(|(r13, _)| *r13 == seed.profile).map(|(_, w)| w).ok_or_else(|| {
        format!("{DEV_W16R2_SWITCH}: the export's block profile {} has no W16R2 development twin (this build admits the R13 Shieldstral T128 export only)", seed.profile)
    })?;
    let sh = Shape::accuracy_trained(block, &seed.norm_calibration(), seed.f_e, seed.accuracy_gate_shift).map_err(|e| format!("{DEV_W16R2_SWITCH}: the W16R2 twin of {}: {e}", seed.profile))?;
    sh.check_trained_class()?;
    let geo = |s: &Shape| ((s.tokens, s.width, s.hidden, s.q_heads, s.head_dim, s.kv_heads, s.log_cols), (s.f_e, s.accuracy_gate_shift, s.t_pad, s.d_pad, s.f_pad, s.trained_calibration));
    if geo(&sh) != geo(seed) || sh.norm_calibration() != seed.norm_calibration() || sh.accuracy_stack() != seed.accuracy_stack() || sh.accuracy_registry() != seed.accuracy_registry() || sh.q_pad() != seed.q_pad() {
        return Err(format!("{DEV_W16R2_SWITCH}: the W16R2 twin {} differs from the export's seed {} outside the profile and the PCS geometry", sh.profile, seed.profile));
    }
    if !super::super::super::shape::is_w16r2_profile(sh.profile) {
        return Err(format!("{DEV_W16R2_SWITCH}: {} is not a W16R2 profile", sh.profile));
    }
    Ok(sh)
}

/// the W16R2 development classifier run profile of a W16R2 twin block shape
pub(crate) fn w16r2_dev_run_profile_of(sh: &Shape) -> Result<&'static str, String> {
    #[cfg(test)]
    if sh.profile == super::super::super::shape::W16R2_RUNG_H24 {
        return Ok(super::super::super::run::RUN_PROFILE_CLASSIFY_W16R2_RUNG_H24_TEST);
    }
    super::super::super::run::W16R2_DEV_CLASSIFY_RUN_PROFILES
        .iter()
        .find(|(_, b)| *b == sh.profile)
        .map(|(r, _)| *r)
        .ok_or_else(|| format!("{DEV_W16R2_SWITCH}: no W16R2 development classifier run profile names the block profile {}", sh.profile))
}

/// **the digest pass under the W16R2 development profile** (`keep`: every block kept, the
/// servers' form): `ExportPublic::load_keeping_at` with the twin of the export's seed
pub(crate) fn load_export_w16r2(path: &Path, keep: bool) -> Result<(ExportPublic, Vec<BlockPublic>), String> {
    ExportPublic::load_keeping_at(path, w16r2_dev_seed_of, w16r2_dev_run_profile_of, keep)
}

/// whether a command's flags carry the switch
pub(crate) fn wants_w16r2(f: &[(String, String)]) -> bool {
    flag(f, DEV_W16R2_SWITCH).is_some()
}

/// whether `run_profile` is a W16R2 development classifier run profile
pub(crate) fn is_dev(run_profile: &str) -> bool {
    super::super::super::run::is_w16r2_dev_classify_run_profile(run_profile)
}

// [A25] the W16R2 development profile's tests (test code only)
#[cfg(test)]
#[path = "classify_w16r2_tests.rs"]
mod tests;
