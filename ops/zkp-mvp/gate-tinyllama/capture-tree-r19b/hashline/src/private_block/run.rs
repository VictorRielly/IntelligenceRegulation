//! **STAGE 12: a private RUN of `L` blocks under ONE transcript.**
//!
//! Block `k`'s hidden output is block `k + 1`'s hidden input, and neither is
//! published. The chaining is carried by an INTERNAL BOUNDARY (`boundary.rs`):
//! one hiding commitment to the padded hidden plane, claimed by block `k`'s
//! output-equality slot and by block `k + 1`'s input-equality slot, opened
//! exactly ONCE — in stage `k + 1`, because its second claim does not exist
//! until then. Transitively `A_k`'s output plane equals `A_{k+1}`'s input
//! plane word for word.
//!
//! **The stage order** (the design's §2.2, checked line by line against
//! `prove_inner_at`): absorb the stage index and the block's public digest;
//! commit `B_k` and absorb its root; then the measured block unchanged — `A`,
//! `M`, the LogUp challenges, `H`, the twenty-three slots, open `M`, `A`,
//! `H` — and then open `B_{k-1}`, whose claim list is now complete. The last
//! stage commits no boundary and closes the run's external output endpoint
//! instead. A stage is the measured block plus two lines, which is the whole
//! value of this construction.
//!
//! **What a run that verifies IS.** A correctness statement: `L` blocks were
//! composed under one Fiat-Shamir chain, each one's hidden output being the
//! next one's hidden input. **What it is NOT**: a privacy result. The
//! obligations a run adds over one block — the joint rank of the boundary
//! plane over ALL THREE commitments that hold it (`A_k`'s output rows, `B_k`,
//! `A_{k+1}`'s input rows) restricted to the reserved mask rows, blinding
//! independence across blocks, the run-wide joint law — have no tools yet and
//! no gate has been run. The run's soundness is about `2^-97.5` for twelve
//! blocks at the 125M geometry (ruling M-2).

use super::boundary::{self, BoundarySpec, PreparedBoundary};
use super::endpoint_g;
use super::layout::Layout;
use super::protocol::{self, CoreView};
use super::run_sink;
use super::shape::Shape;
use super::timing;
use super::wire::{self, SegGeom, Segment};
use super::witness::Witness;
use super::{BlockPublic, Endpoints, ExpectedIo};
use crate::field::Fp;
use crate::merkle::Digest;
use crate::ntt::NttTables;
use crate::pcs::{self, PcsParams, ZClaim, ZkOpts};
use crate::transcript::Transcript;
use crate::zk::ZkRng;
use zkp_core::hashtag::HashTag;

/// An internal boundary is claimed by exactly two slots: block `k`'s slot 22
/// (site 0) and block `k + 1`'s slot 21 (site 1).
pub(crate) const BOUNDARY_SITES: usize = 2;

pub(crate) const RUN_PROFILE_RUNG_G: &str = "hashline-zk-mr1/private-run-rung-g-t24-dev/1";
/// **STAGE 22.** The run profile of the four-key-value-head development
/// shape. One profile per shape (D17), so a run over `Shape::rung_k4` gets
/// its own transcript and its own hash-tag key set and no existing run
/// profile moves.
pub(crate) const RUN_PROFILE_RUNG_K4: &str = "hashline-zk-mr1/private-run-rung-k4-t24-dev/1";
/// **STAGE 30.** The run profile of the both-pad-branches development shape
/// (`Shape::rung_p2`), by the same rule: one profile per shape (D17).
pub(crate) const RUN_PROFILE_RUNG_P2: &str = "hashline-zk-mr1/private-run-rung-p2-t32-dev/1";
/// **STAGE 31.** The run profile of the full-top-byte development shape
/// (`Shape::rung_c6`), by the same rule: one profile per shape (D17).
pub(crate) const RUN_PROFILE_RUNG_C6: &str = "hashline-zk-mr1/private-run-rung-c6-t32-dev/1";
/// **STAGE 32.** The run profile of the 125M-row-width development shape
/// (`Shape::rung_w14`), by the same rule: one profile per shape (D17).
pub(crate) const RUN_PROFILE_RUNG_W14: &str = "hashline-zk-mr1/private-run-rung-w14-t64-dev/1";
/// **STAGE 33.** The run profile of the 32-data-row-endpoint development
/// shape (`Shape::rung_e32`), by the same rule: one profile per shape (D17).
pub(crate) const RUN_PROFILE_RUNG_E32: &str = "hashline-zk-mr1/private-run-rung-e32-t32-dev/1";
pub(crate) const RUN_PROFILE_M125: &str = "hashline-zk-mr1/private-run-m125/1";
/// LANE C SCRATCH (not in the main tree): the run profile of the TinyLlama
/// geometry's development shape, by the same rule: one profile per shape (D17).
/// NATIVE LANE: unregistered, like its block profile (outside the registry).
#[cfg(test)]
pub(crate) const RUN_PROFILE_TINYLLAMA_T32_DEV: &str = "unregistered-dev-twin/private-run-tinyllama-1.1b-t32-w32-dev/1";
/// NATIVE LANE: the run profile of the TRAINED-calibration TinyLlama shape. A
/// run at it is constructible only bound to a trained-model statement
/// (`RunStatement::new` refuses it by name).
///
/// Its length is chosen: the shorter `...-t32-trained/1` (56 bytes) put the
/// transcript constructor at 68 bytes, the same length as the `pb-run-stage`
/// absorb in the same keyed function (`s25_tests`' census refused it). At 66
/// bytes the constructor is 78, with no hash input kind at 77, 78 or 79.
pub(crate) const RUN_PROFILE_TINYLLAMA_T32_TRAINED: &str = "hashline-zk-mr1/private-run-tinyllama-1.1b-t32-trained-statement/1";
/// ROUND 3 (R3-2): the run profiles of the trained TinyLlama shapes at T64
/// and T128 (one per shape, D17), named like T32's.
pub(crate) const RUN_PROFILE_TINYLLAMA_T64_TRAINED: &str = "hashline-zk-mr1/private-run-tinyllama-1.1b-t64-trained-statement/1";
pub(crate) const RUN_PROFILE_TINYLLAMA_T128_TRAINED: &str = "hashline-zk-mr1/private-run-tinyllama-1.1b-t128-trained-statement/1";
/// ROUND 4 (R4-1): the run profile of the trained Llama-3-8B shape at T32.
pub(crate) const RUN_PROFILE_LLAMA3_8B_T32_TRAINED: &str = "hashline-zk-mr1/private-run-llama-3-8b-t32-trained-statement/1";
/// task 3 (2026-10-17 evening): the run profiles of the trained Llama-3-8B
/// shapes at T64 and T128 (one per shape, D17). PENDING REVIEW.
pub(crate) const RUN_PROFILE_LLAMA3_8B_T64_TRAINED: &str = "hashline-zk-mr1/private-run-llama-3-8b-t64-trained-statement/1";
pub(crate) const RUN_PROFILE_LLAMA3_8B_T128_TRAINED: &str = "hashline-zk-mr1/private-run-llama-3-8b-t128-trained-statement/1";
/// NATIVE LANE: the run profile of the trained-calibration development rung.
pub(crate) const RUN_PROFILE_RUNG_TC: &str = "hashline-zk-mr1/private-run-rung-tc-t32-dev/1";
/// TOKEN I/O R1 LANE (2026-10-17): the token-I/O run over the trained-
/// calibration development rung (DESIGN v3 rung R1: public-row variant, mode
/// (i), stage IN + L blocks + stage OUT). A NEW profile string under D17 — its
/// own transcript; a run under it is built by `token_io::run` only.
pub(crate) const RUN_PROFILE_TOKEN_IO_RUNG_TC: &str = "hashline-zk-mr1/private-token-io-run-rung-tc-t32-public-row-dev/1";
/// TOKEN I/O R2 (2026-10-17): the token-I/O run over the trained TinyLlama-
/// 1.1B T32 blocks (DESIGN v3 rung R2: public-row variant, mode (i), V =
/// 32,000 padded to 2^15, multi-row stage planes). A NEW profile string under
/// D17; built by `token_io::run` only.
/// (The string is chosen so that its transcript-constructor input, 98 bytes,
/// equals the length of no other hash-input kind of the run and is not one
/// byte from any: stage 25's W-2 census; the first choice, 76 characters,
/// gave an 88-byte constructor equal to the `schedule` absorb.)
pub(crate) const RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32: &str = "hashline-zk-mr1/private-token-io-run-tinyllama-1.1b-t32-trained-statement-public-row/1";
/// TOKEN I/O R3 (2026-10-18): the token-I/O run over the trained Llama-3-8B
/// T32 blocks (DESIGN v3 rung R3: public-row variant, mode (i), V = 128,256
/// padded to 2^17, d = 4,096, BOS 128,000). A NEW profile string under D17;
/// its transcript-constructor input (94 bytes) equals the length of no other
/// hash-input kind and is one byte from none (stage 25's W-2 census).
pub(crate) const RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32: &str = "hashline-zk-mr1/private-token-io-run-llama-3-8b-t32-trained-statement-public-row/1";
/// TOKEN I/O ROUND 8 (2026-10-19): the token-I/O run over the trained
/// TinyLlama-1.1B T128 blocks (DESIGN v3's first geometry: T <= 128, the
/// input endpoint ONE 256-word row; public-row variant, mode (i)). A NEW
/// profile string under D17; built by `token_io::run` only. (Not
/// "...-tinyllama-1.1b-t128-...": that 87-character string gives a 99-byte
/// transcript constructor, the length of another hash-input kind of the
/// TinyLlama run (stage 25's W-2 census); this one's is 94 bytes.)
pub(crate) const RUN_PROFILE_TOKEN_IO_TINYLLAMA_T128: &str = "hashline-zk-mr1/private-token-io-run-tinyllama-t128-trained-statement-public-row/1";
/// TOKEN I/O ROUND 8 (2026-10-19): the token-I/O run over the trained
/// Llama-3-8B T128 blocks (DESIGN v3's first geometry, as above; V =
/// 128,256 padded to 2^17, d = 4,096, BOS 128,000). A NEW profile string under
/// D17; its transcript constructor is 95 bytes (stage 25's W-2 census).
pub(crate) const RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T128: &str = "hashline-zk-mr1/private-token-io-run-llama-3-8b-t128-trained-statement-public-row/1";
/// every token-I/O run profile this build registers (a blocks-only run may
/// carry none of them)
pub(crate) const TOKEN_IO_RUN_PROFILES: [&str; 5] = [RUN_PROFILE_TOKEN_IO_RUNG_TC, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T128, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T128];
/// TOKEN I/O ROUND 12 (2026-10-21): the CLASSIFIER run over the trained-
/// calibration development rung (DESIGN_CLASSIFIER v2, rung R-C1: stage IN-C
/// with the public template and the control-id column, the L blocks, stage
/// OUT-C with the margin slot and the PUBLIC verdict bit; one external
/// endpoint). A NEW profile string under D17 — its own transcript; a run
/// under it is built by `token_io::classify_run` only. Same length as the
/// token rung's string (65 characters), whose transcript constructor the W-2
/// census already admits.
pub(crate) const RUN_PROFILE_CLASSIFY_RUNG_TC: &str = "hashline-zk-mr1/private-classify-run-rung-tc-t32-public-row-dev/1";
/// **TOKEN I/O ROUND 16 (2026-10-29): the CLASSIFIER run over the native R13
/// Shieldstral-1.0-3B LOW + h24 blocks** (REVIEW_R13 §10: block profiles
/// `R13_SHIELD_T128_H24` / `R13_SHIELD_T256_H24`, export schema v2, each
/// stage at its layer's bound gate denominator). NEW profile strings under
/// D17 (their own transcripts; D17's one-run-profile-per-block-shape rule),
/// built by `token_io::classify_run` only (73 characters: an 85-byte transcript
/// constructor, the length of no other hash-input kind of these runs and one
/// byte from none; s25's W-2 census refused the first 76-character choice, whose
/// 88 bytes equal the `schedule` absorb). Non-DD only (the classifier CLI
/// carries no `--dd` switch); T256 is registered for larger hosts and is not
/// proved on the 8 GB laptop (its modelled peak exceeds the budget).
pub(crate) const RUN_PROFILE_CLASSIFY_R13_SHIELD_T128: &str = "hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/1";
pub(crate) const RUN_PROFILE_CLASSIFY_R13_SHIELD_T256: &str = "hashline-zk-mr1/private-classify-run-shieldstral-3b-t256-r13-public-row/1";
/// TOKEN I/O ROUND 16: each R13 classifier run profile and the ONE R13 block
/// profile it names (CS-7), as native R13's `ACCURACY_RUN_PROFILES`
pub(crate) const ACCURACY_CLASSIFY_RUN_PROFILES: [(&str, &str); 2] = [
    (RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, super::shape::R13_SHIELD_T128_H24),
    (RUN_PROFILE_CLASSIFY_R13_SHIELD_T256, super::shape::R13_SHIELD_T256_H24),
];
/// every classifier run profile this build registers
pub(crate) const CLASSIFY_RUN_PROFILES: [&str; 3] = [RUN_PROFILE_CLASSIFY_RUNG_TC, RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, RUN_PROFILE_CLASSIFY_R13_SHIELD_T256];
/// TOKEN I/O ROUND 16: the classifier run profile of an R13 block profile
pub(crate) fn accuracy_classify_run_profile(block: &str) -> Option<&'static str> {
    ACCURACY_CLASSIFY_RUN_PROFILES.iter().find(|(_, b)| *b == block).map(|(r, _)| *r)
}
/// **TOKEN I/O ROUND 16, TEST BUILDS ONLY:** a classifier run over native
/// R13's LOW + h24 development rung (`R13_RUNG_H24`, T32, width 384), so the
/// R13 classifier path (per-layer gate denominators, the pre-header stage
/// check) proves and verifies in seconds on public synthetic fixtures. No
/// production build has it.
#[cfg(test)]
pub(crate) const RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST: &str = "hashline-zk-mr1/private-classify-run-rung-lh-t32-public-row-tst/1";
/// whether `p` is a classifier run profile of this build (test builds also
/// admit [`RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST`])
pub(crate) fn is_classify_run_profile(p: &str) -> bool {
    #[cfg(test)]
    if p == RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST {
        return true;
    }
    CLASSIFY_RUN_PROFILES.contains(&p)
}
/// whether `p` is an R13 classifier run profile (the blocks-only refusal)
fn is_r13_classify_run_profile(p: &str) -> bool {
    #[cfg(test)]
    if p == RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST {
        return true;
    }
    ACCURACY_CLASSIFY_RUN_PROFILES.iter().any(|(r, _)| *r == p)
}
/// **NATIVE R9 (D30): the run profiles of the three DD block profiles** (one
/// per shape, D17), at the lengths of their non-DD twins' (67 / 63 / 45)
pub(crate) const RUN_PROFILE_TINYLLAMA_T128_DD: &str = "hashline-zk-mr1/private-run-tinyllama-1.1b-t128-ddict32-statement/1";
pub(crate) const RUN_PROFILE_LLAMA3_8B_T128_DD: &str = "hashline-zk-mr1/private-run-llama-3-8b-t128-ddict32-statement/1";
pub(crate) const RUN_PROFILE_RUNG_DD: &str = "hashline-zk-mr1/private-run-rung-dd-t32-dev/1";
/// **NATIVE R12 (D38): the run profiles of the Shieldstral block profiles**
/// (one per shape, D17), each 67 bytes as the TinyLlama T128 run profiles,
/// and the decoupled-head development rung's (45 bytes, as the other rungs')
pub(crate) const RUN_PROFILE_SHIELDSTRAL_T128_TRAINED: &str = "hashline-zk-mr1/private-run-shieldstral-3b-t128-trained-statement/1";
pub(crate) const RUN_PROFILE_SHIELDSTRAL_T256_TRAINED: &str = "hashline-zk-mr1/private-run-shieldstral-3b-t256-trained-statement/1";
pub(crate) const RUN_PROFILE_SHIELDSTRAL_T128_DD: &str = "hashline-zk-mr1/private-run-shieldstral-3b-t128-ddict32-statement/1";
pub(crate) const RUN_PROFILE_SHIELDSTRAL_T256_DD: &str = "hashline-zk-mr1/private-run-shieldstral-3b-t256-ddict32-statement/1";
pub(crate) const RUN_PROFILE_RUNG_HD: &str = "hashline-zk-mr1/private-run-rung-hd-t32-dev/1";


// R13: one new run identity for each new arithmetic/geometry profile.
pub(crate) const RUN_PROFILE_R13_TINY_T128_LOW: &str = "hashline-zk-mr1/private-run-tinyllama-1.1b-t128-low-stack-v01-run/1";
pub(crate) const RUN_PROFILE_R13_TINY_T128_LOW_DD: &str = "hashline-zk-mr1/private-run-tinyllama-1.1b-t128-low-ddict-v01-run/1";
pub(crate) const RUN_PROFILE_R13_8B_T128_H24: &str = "hashline-zk-mr1/private-run-llama-3-8b-t128-lh24-v1-statement/1";
pub(crate) const RUN_PROFILE_R13_8B_T128_H24_DD: &str = "hashline-zk-mr1/private-run-llama-3-8b-t128-lh24-dd-statement/1";
pub(crate) const RUN_PROFILE_R13_SHIELD_T128_H24: &str = "hashline-zk-mr1/private-run-shieldstral-3b-t128-lowh24-blocks-run/1";
pub(crate) const RUN_PROFILE_R13_SHIELD_T128_H24_DD: &str = "hashline-zk-mr1/private-run-shieldstral-3b-t128-lowh24-ddict1-run/1";
pub(crate) const RUN_PROFILE_R13_SHIELD_T256_H24: &str = "hashline-zk-mr1/private-run-shieldstral-3b-t256-lowh24-blocks-run/1";
pub(crate) const RUN_PROFILE_R13_SHIELD_T256_H24_DD: &str = "hashline-zk-mr1/private-run-shieldstral-3b-t256-lowh24-ddict1-run/1";
pub(crate) const RUN_PROFILE_R13_RUNG_LOW: &str = "hashline-zk-mr1/private-run-rung-lo-t32-dev/1";
pub(crate) const RUN_PROFILE_R13_RUNG_H24: &str = "hashline-zk-mr1/private-run-rung-lh-t32-dev/1";
pub(crate) const RUN_PROFILE_R13_RUNG_LOW_DD: &str = "hashline-zk-mr1/private-run-rung-ld-t32-dev/1";
pub(crate) const RUN_PROFILE_R13_RUNG_H24_DD: &str = "hashline-zk-mr1/private-run-rung-hh-t32-dev/1";
pub(crate) const ACCURACY_RUN_PROFILES:[(&str,&str);12]=[
    (RUN_PROFILE_R13_TINY_T128_LOW,super::shape::R13_TINY_T128_LOW),
    (RUN_PROFILE_R13_TINY_T128_LOW_DD,super::shape::R13_TINY_T128_LOW_DD),
    (RUN_PROFILE_R13_8B_T128_H24,super::shape::R13_8B_T128_H24),
    (RUN_PROFILE_R13_8B_T128_H24_DD,super::shape::R13_8B_T128_H24_DD),
    (RUN_PROFILE_R13_SHIELD_T128_H24,super::shape::R13_SHIELD_T128_H24),
    (RUN_PROFILE_R13_SHIELD_T128_H24_DD,super::shape::R13_SHIELD_T128_H24_DD),
    (RUN_PROFILE_R13_SHIELD_T256_H24,super::shape::R13_SHIELD_T256_H24),
    (RUN_PROFILE_R13_SHIELD_T256_H24_DD,super::shape::R13_SHIELD_T256_H24_DD),
    (RUN_PROFILE_R13_RUNG_LOW,super::shape::R13_RUNG_LOW),
    (RUN_PROFILE_R13_RUNG_H24,super::shape::R13_RUNG_H24),
    (RUN_PROFILE_R13_RUNG_LOW_DD,super::shape::R13_RUNG_LOW_DD),
    (RUN_PROFILE_R13_RUNG_H24_DD,super::shape::R13_RUNG_H24_DD),
];
pub(crate) fn accuracy_run_profile(block:&str)->Option<&'static str> {
    ACCURACY_RUN_PROFILES.iter().find(|(_,b)|*b==block).map(|(r,_)|*r)
}

/// One run's geometry: the per-block shape, how many blocks, and the run's own
/// profile id. A run is a NEW profile under D17 — its own transcript, its own
/// digests — so no byte of any single-block profile moves.
///
/// **RULING CS-8 (ported from the 125M lane's stage 43): the three fields
/// are PRIVATE**; [`RunShape::new`] (ruling CS-7) is the only way in, and
/// [`RunShape::sh`], [`RunShape::l`], [`RunShape::profile`] read them.
#[derive(Clone, Debug)]
pub(crate) struct RunShape {
    sh: Shape,
    l: usize,
    profile: &'static str,
}

/// **RULING CS-7 (ported from the 125M lane's stage 42): THE RUN PROFILE
/// REGISTRY** — the one block shape each registered run profile names. The
/// frozen profiles name one shape VALUE; NATIVE LANE: a trained-calibration
/// run profile names its geometry under ANY admitted calibration, so its
/// registered shape is rebuilt through the trained door at the handed
/// shape's own calibration and `f_e` (and must then be equal, every field).
/// `None` for a run profile this build does not register.
fn registered_block_shape(profile: &str, sh: &Shape) -> Option<Result<Shape, String>> {
    let cal = sh.norm_calibration();
    if let Some((_,block))=ACCURACY_RUN_PROFILES.iter().find(|(run,_)|*run==profile) {
        return Some(Shape::accuracy_trained(block,&cal,sh.f_e,sh.accuracy_gate_shift));
    }
    // TOKEN I/O ROUND 16: the R13 classifier run profiles, rebuilt through the
    // same R13 door as native's (the handed shape's calibration, f_e and gate)
    if let Some((_, block)) = ACCURACY_CLASSIFY_RUN_PROFILES.iter().find(|(run, _)| *run == profile) {
        return Some(Shape::accuracy_trained(block, &cal, sh.f_e, sh.accuracy_gate_shift));
    }
    #[cfg(test)]
    if profile == RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST {
        return Some(Shape::accuracy_trained(super::shape::R13_RUNG_H24, &cal, sh.f_e, sh.accuracy_gate_shift));
    }
    Some(match profile {
        RUN_PROFILE_RUNG_G => Ok(Shape::rung_g()),
        RUN_PROFILE_RUNG_K4 => Ok(Shape::rung_k4()),
        RUN_PROFILE_RUNG_P2 => Ok(Shape::rung_p2()),
        RUN_PROFILE_RUNG_C6 => Ok(Shape::rung_c6()),
        RUN_PROFILE_RUNG_W14 => Ok(Shape::rung_w14()),
        RUN_PROFILE_RUNG_E32 => Ok(Shape::rung_e32()),
        RUN_PROFILE_M125 => Ok(Shape::m125()),
        RUN_PROFILE_RUNG_TC => Shape::rung_tc(&cal),
        RUN_PROFILE_TOKEN_IO_RUNG_TC => Shape::rung_tc(&cal),
        RUN_PROFILE_CLASSIFY_RUNG_TC => Shape::rung_tc(&cal),
        RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32 => Shape::tinyllama_trained(32, &cal, sh.f_e),
        RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32 => Shape::llama3_8b_t32_trained(&cal, sh.f_e),
        RUN_PROFILE_TOKEN_IO_TINYLLAMA_T128 => Shape::tinyllama_trained(128, &cal, sh.f_e),
        RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T128 => Shape::llama3_8b_trained(128, &cal, sh.f_e),
        RUN_PROFILE_TINYLLAMA_T32_TRAINED => Shape::tinyllama_trained(32, &cal, sh.f_e),
        RUN_PROFILE_TINYLLAMA_T64_TRAINED => Shape::tinyllama_trained(64, &cal, sh.f_e),
        RUN_PROFILE_TINYLLAMA_T128_TRAINED => Shape::tinyllama_trained(128, &cal, sh.f_e),
        RUN_PROFILE_LLAMA3_8B_T32_TRAINED => Shape::llama3_8b_t32_trained(&cal, sh.f_e),
        RUN_PROFILE_LLAMA3_8B_T64_TRAINED => Shape::llama3_8b_trained(64, &cal, sh.f_e),
        RUN_PROFILE_LLAMA3_8B_T128_TRAINED => Shape::llama3_8b_trained(128, &cal, sh.f_e),
        RUN_PROFILE_TINYLLAMA_T128_DD => Shape::tinyllama_t128_trained_dd(&cal, sh.f_e),
        RUN_PROFILE_LLAMA3_8B_T128_DD => Shape::llama3_8b_t128_trained_dd(&cal, sh.f_e),
        RUN_PROFILE_RUNG_DD => Shape::rung_dd(&cal),
        // NATIVE R12 (D38, F2)
        RUN_PROFILE_SHIELDSTRAL_T128_TRAINED => Shape::shieldstral_trained(128, &cal, sh.f_e),
        RUN_PROFILE_SHIELDSTRAL_T256_TRAINED => Shape::shieldstral_trained(256, &cal, sh.f_e),
        RUN_PROFILE_SHIELDSTRAL_T128_DD => Shape::shieldstral_trained_dd(128, &cal, sh.f_e),
        RUN_PROFILE_SHIELDSTRAL_T256_DD => Shape::shieldstral_trained_dd(256, &cal, sh.f_e),
        RUN_PROFILE_RUNG_HD => Shape::rung_hd(&cal),
        #[cfg(test)]
        RUN_PROFILE_TINYLLAMA_T32_DEV => Ok(Shape::tinyllama_t32_dev()),
        _ => return None,
    })
}

impl RunShape {
    pub(crate) fn accuracy(sh:Shape,l:usize)->Result<RunShape,String> {
        let profile=accuracy_run_profile(sh.profile).ok_or("private run: no R13 run profile for this block")?;
        Self::new(sh,l,profile)
    }

    /// **RULING CS-7 (finding S41-N1 of the 125M lane).** A run profile names
    /// exactly one block shape: it is admitted only over the shape it is
    /// registered for, compared field by field, and a profile this build does
    /// not register is refused. `L = 0` keeps its own refusal, first.
    pub(crate) fn new(sh: Shape, l: usize, profile: &'static str) -> Result<RunShape, String> {
        if l == 0 {
            return Err("private run: a run has at least one block".into());
        }
        match registered_block_shape(profile, &sh) {
            None => return Err(format!("private run: ruling CS-7 — {profile:?} is not a run profile this build registers, so it names no block shape ({:?} was given)", sh.name)),
            Some(Err(e)) => return Err(format!("private run: ruling CS-7 — the run profile {profile:?} names a block shape the given {:?} ({}) is not: {e}", sh.name, sh.profile)),
            Some(Ok(reg)) if reg != sh => {
                return Err(format!("private run: ruling CS-7 — the run profile {profile:?} is registered for the block shape {:?} ({}), not for {:?} ({})", reg.name, reg.profile, sh.name, sh.profile));
            }
            Some(Ok(_)) => {}
        }
        Ok(RunShape { sh, l, profile })
    }
    /// the per-block shape (ruling CS-8: read-only outside this module)
    pub(crate) fn sh(&self) -> &Shape {
        &self.sh
    }
    /// how many blocks (ruling CS-8: read-only outside this module)
    pub(crate) fn l(&self) -> usize {
        self.l
    }
    /// the run's own profile id (ruling CS-8: read-only outside this module)
    pub(crate) fn profile(&self) -> &'static str {
        self.profile
    }
    pub(crate) fn rung_g(l: usize) -> Result<RunShape, String> {
        RunShape::new(Shape::rung_g(), l, RUN_PROFILE_RUNG_G)
    }
    /// **STAGE 22.** A run at the four-key-value-head development shape.
    pub(crate) fn rung_k4(l: usize) -> Result<RunShape, String> {
        RunShape::new(Shape::rung_k4(), l, RUN_PROFILE_RUNG_K4)
    }
    /// **STAGE 30.** A run at the both-pad-branches development shape.
    pub(crate) fn rung_p2(l: usize) -> Result<RunShape, String> {
        RunShape::new(Shape::rung_p2(), l, RUN_PROFILE_RUNG_P2)
    }
    /// **STAGE 31.** A run at the full-top-byte development shape.
    pub(crate) fn rung_c6(l: usize) -> Result<RunShape, String> {
        RunShape::new(Shape::rung_c6(), l, RUN_PROFILE_RUNG_C6)
    }
    /// **STAGE 32.** A run at the 125M-row-width development shape.
    pub(crate) fn rung_w14(l: usize) -> Result<RunShape, String> {
        RunShape::new(Shape::rung_w14(), l, RUN_PROFILE_RUNG_W14)
    }
    /// **STAGE 33.** A run at the 32-data-row-endpoint development shape.
    pub(crate) fn rung_e32(l: usize) -> Result<RunShape, String> {
        RunShape::new(Shape::rung_e32(), l, RUN_PROFILE_RUNG_E32)
    }
    pub(crate) fn m125(l: usize) -> Result<RunShape, String> {
        RunShape::new(Shape::m125(), l, RUN_PROFILE_M125)
    }
    /// LANE C SCRATCH: a run at the TinyLlama geometry's development shape
    /// (review finding F-6: test builds only).
    #[cfg(test)]
    #[allow(dead_code)]
    pub(crate) fn tinyllama_t32_dev(l: usize) -> Result<RunShape, String> {
        RunShape::new(Shape::tinyllama_t32_dev(), l, RUN_PROFILE_TINYLLAMA_T32_DEV)
    }
    /// NATIVE LANE: a run at the TRAINED-calibration TinyLlama shape. The
    /// calibration is the shape's (validated by its constructor), so the
    /// caller passes the shape; any other profile is refused.
    pub(crate) fn tinyllama_t32_trained(sh: Shape, l: usize) -> Result<RunShape, String> {
        if sh.profile != super::shape::TINYLLAMA_T32_TRAINED_PROFILE || !sh.trained_calibration {
            return Err("private run: the trained TinyLlama run profile needs the trained TinyLlama shape".into());
        }
        RunShape::new(sh, l, RUN_PROFILE_TINYLLAMA_T32_TRAINED)
    }
    /// ROUND 3 (R3-2): a run at a trained TinyLlama shape of any registered
    /// context length; its run profile is the shape's own (one per shape)
    pub(crate) fn tinyllama_trained(sh: Shape, l: usize) -> Result<RunShape, String> {
        use super::shape::{TINYLLAMA_T128_TRAINED_PROFILE, TINYLLAMA_T32_TRAINED_PROFILE, TINYLLAMA_T64_TRAINED_PROFILE};
        let rp = match sh.profile {
            p if p == TINYLLAMA_T32_TRAINED_PROFILE => RUN_PROFILE_TINYLLAMA_T32_TRAINED,
            p if p == TINYLLAMA_T64_TRAINED_PROFILE => RUN_PROFILE_TINYLLAMA_T64_TRAINED,
            p if p == TINYLLAMA_T128_TRAINED_PROFILE => RUN_PROFILE_TINYLLAMA_T128_TRAINED,
            p if p == super::shape::LLAMA3_8B_T32_TRAINED_PROFILE => RUN_PROFILE_LLAMA3_8B_T32_TRAINED,
            p if p == super::shape::LLAMA3_8B_T64_TRAINED_PROFILE => RUN_PROFILE_LLAMA3_8B_T64_TRAINED,
            p if p == super::shape::LLAMA3_8B_T128_TRAINED_PROFILE => RUN_PROFILE_LLAMA3_8B_T128_TRAINED,
            // NATIVE R9: the DD profiles (D30)
            p if p == super::shape::TINYLLAMA_T128_DD_TRAINED_PROFILE => RUN_PROFILE_TINYLLAMA_T128_DD,
            p if p == super::shape::LLAMA3_8B_T128_DD_TRAINED_PROFILE => RUN_PROFILE_LLAMA3_8B_T128_DD,
            // NATIVE R12 (D38): the Shieldstral profiles
            p if p == super::shape::SHIELDSTRAL_T128_TRAINED_PROFILE => RUN_PROFILE_SHIELDSTRAL_T128_TRAINED,
            p if p == super::shape::SHIELDSTRAL_T256_TRAINED_PROFILE => RUN_PROFILE_SHIELDSTRAL_T256_TRAINED,
            p if p == super::shape::SHIELDSTRAL_T128_DD_TRAINED_PROFILE => RUN_PROFILE_SHIELDSTRAL_T128_DD,
            p if p == super::shape::SHIELDSTRAL_T256_DD_TRAINED_PROFILE => RUN_PROFILE_SHIELDSTRAL_T256_DD,
            _ => return Err("private run: a trained-model run profile needs a trained TinyLlama, Llama-3-8B or Shieldstral shape".into()),
        };
        if !sh.trained_calibration {
            return Err("private run: a trained TinyLlama run profile needs a trained TinyLlama shape".into());
        }
        RunShape::new(sh, l, rp)
    }
    /// NATIVE R9: a run at the DD development rung (D30).
    pub(crate) fn rung_dd(sh: Shape, l: usize) -> Result<RunShape, String> {
        if sh.profile != super::shape::TRAINED_DD_RUNG_PROFILE || !sh.trained_calibration {
            return Err("private run: the DD rung run profile needs its shape".into());
        }
        RunShape::new(sh, l, RUN_PROFILE_RUNG_DD)
    }
    /// NATIVE R12 (F2): a run at the decoupled-head development rung.
    pub(crate) fn rung_hd(sh: Shape, l: usize) -> Result<RunShape, String> {
        if sh.profile != super::shape::TRAINED_HD_RUNG_PROFILE || !sh.trained_calibration {
            return Err("private run: the decoupled-head rung run profile needs its shape".into());
        }
        RunShape::new(sh, l, RUN_PROFILE_RUNG_HD)
    }
    /// NATIVE LANE: a run at the trained-calibration development rung.
    pub(crate) fn rung_tc(sh: Shape, l: usize) -> Result<RunShape, String> {
        if sh.profile != super::shape::TRAINED_CALIB_RUNG_PROFILE || !sh.trained_calibration {
            return Err("private run: the trained-calibration rung run profile needs its shape".into());
        }
        RunShape::new(sh, l, RUN_PROFILE_RUNG_TC)
    }
    /// how many rows of an IO commitment carry plane words — the same at an
    /// external endpoint and at an internal boundary, because both commit the
    /// same padded `Dom::D` cube at the same row width
    pub(crate) fn data_rows(&self) -> usize {
        self.sh.endpoint_rows.saturating_sub(endpoint_g::MASK_ROWS)
    }
    /// the NTT domain one run needs: the block's, and the IO commitments'
    fn ntt_log(&self) -> u32 {
        protocol::ntt_log_at(&self.sh).max((self.sh.endpoint_log_n + self.sh.endpoint_inv_rate.trailing_zeros() as usize) as u32)
    }
}

/// The run's public statement. Everything a verifier needs and nothing a
/// prover chooses: the geometry, the two EXTERNAL endpoint roots (D18 seals
/// them before the run), one public digest per block, one scale per boundary
/// and the calibration identity. The `L - 1` boundary ROOTS are deliberately
/// NOT here — an internal boundary is a hidden intermediate, not an endpoint.
pub(crate) struct RunStatement {
    /// RULING CS-8: private; [`RunStatement::rs`] reads it
    rs: RunShape,
    expected: ExpectedIo,
    block_digests: Vec<Digest>,
    context: Digest,
    /// **RULING M-4.** One field per internal boundary, shared by
    /// construction between block `k`'s declared output scale and block
    /// `k + 1`'s declared input scale. There is no second place to declare it.
    boundary_scales: Vec<i32>,
    calibration: Digest,
    /// **NATIVE R8 (R6 for `sh_s`): each stage's calibration** — the run
    /// shape's for every stage of a run-wide calibration, and a trained
    /// layer's own constants applied where its record carries any
    /// (`LayerRecord::own`, bound by the trained identity the header
    /// absorbs). Stage `k` is proved and verified at
    /// [`RunStatement::stage_shape`]`(k)`.
    stage_cal: Vec<super::shape::NormCalibration>,
    stage_accuracy_gate:Vec<u32>,
}

impl RunStatement {
    /// the run's geometry (ruling CS-8: read-only outside this module)
    pub(crate) fn rs(&self) -> &RunShape {
        &self.rs
    }
    /// `block_scales[k]` is block `k`'s declared `(input, output)` scale pair.
    /// A run in which block `k + 1` declares a different input scale than
    /// block `k`'s output scale DOES NOT CONSTRUCT: the two are collapsed into
    /// the one field a boundary has, and a disagreement is refused by name
    /// here rather than being carried into a proof (ruling M-4).
    pub(crate) fn new(rs: RunShape, context: Digest, expected: ExpectedIo, blocks: &[BlockPublic], block_scales: &[(i32, i32)]) -> Result<RunStatement, String> {
        // A trained-calibration shape binds its model statement and may not
        // fall back to the synthetic literal. Review finding F-2: keyed on
        // the SHAPE's own flag (it was a substring test on the run profile,
        // which let an unbound run at the trained-calibration rung absorb
        // `calibration_identity()`), and on the trained run profile by name.
        if rs.sh.trained_calibration
            || [RUN_PROFILE_TINYLLAMA_T32_TRAINED, RUN_PROFILE_TINYLLAMA_T64_TRAINED, RUN_PROFILE_TINYLLAMA_T128_TRAINED, RUN_PROFILE_LLAMA3_8B_T32_TRAINED, RUN_PROFILE_LLAMA3_8B_T64_TRAINED, RUN_PROFILE_LLAMA3_8B_T128_TRAINED, RUN_PROFILE_RUNG_TC].contains(&rs.profile)
            || [RUN_PROFILE_SHIELDSTRAL_T128_TRAINED, RUN_PROFILE_SHIELDSTRAL_T256_TRAINED, RUN_PROFILE_SHIELDSTRAL_T128_DD, RUN_PROFILE_SHIELDSTRAL_T256_DD, RUN_PROFILE_RUNG_HD].contains(&rs.profile)
        {
            return Err(format!("private run: {} is a trained-calibration run; it needs its trained-model statement (RunStatement::new_bound)", rs.profile));
        }
        if blocks.len() != rs.l || block_scales.len() != rs.l {
            return Err(format!("private run: the statement is for {} blocks, {} public statements and {} scale pairs were given", rs.l, blocks.len(), block_scales.len()));
        }
        // RULINGS CS-1 and CS-4: every block's statement (both halves) and
        // the endpoint policy against the run's shape, before any digest of
        // either is taken
        blocks_fit_the_shape(blocks, &rs.sh)?;
        policy_fits_the_shape(&expected, &rs.sh)?;
        let digests: Vec<Digest> = blocks.iter().map(|b| b.digest()).collect();
        Self::new_with_calibration(rs, context, expected, digests, blocks.len(), block_scales, super::calibration_identity(), super::ENDPOINT_SCALES)
    }

    /// **LANE C SCRATCH PROTOTYPE: a run BOUND to a trained-model statement.**
    /// Every check `new` makes, with two substitutions: the approved scale
    /// pair is the statement's calibration's (not the literal), and the
    /// `"calibration"` absorb is the statement's identity (not the literal).
    /// The statement is checked against the run's OWN block digests, profile,
    /// geometry and scales before anything is built. At a trained profile
    /// this is the only constructor; at the toy, the rungs and 125M it is
    /// never called, so none of their bytes moves.
    pub(crate) fn new_bound(rs: RunShape, context: Digest, expected: ExpectedIo, blocks: &[BlockPublic], block_scales: &[(i32, i32)], model: &super::trained_statement::TrainedModelStatement) -> Result<RunStatement, String> {
        // RULINGS CS-1 and CS-4 on the blocks handed, before they are digested
        if blocks.len()==rs.l && rs.sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {
            blocks_fit_the_shape(blocks,&rs.sh)?;
        }
        let digests:Vec<Digest>=blocks.iter().map(|b|b.digest()).collect();
        let st=Self::new_bound_from_digests(rs,context,expected,digests,block_scales,model)?;
        if st.rs.sh.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
            for (k,block) in blocks.iter().enumerate() {block.check_for_shape(&st.stage_shape(k)?).map_err(|e|format!("private run: block{k}: {e}"))?;}
        }
        Ok(st)
    }

    /// **ROUND 4: the same statement from the blocks' DIGESTS** (what the
    /// statement holds of them), so a run whose public blocks do not fit in
    /// memory together (32 Llama-3-8B blocks are 7.4 GB of padded int8) is
    /// constructed without holding them; the prover and verifier then take
    /// each block from a [`BlockSource`] that checks it against these digests.
    pub(crate) fn new_bound_from_digests(rs: RunShape, context: Digest, expected: ExpectedIo, digests: Vec<Digest>, block_scales: &[(i32, i32)], model: &super::trained_statement::TrainedModelStatement) -> Result<RunStatement, String> {
        if !rs.sh.trained_calibration {
            return Err(format!("private run: {} is not a trained-calibration shape; a trained-model statement binds trained-calibration runs only", rs.sh.profile));
        }
        if digests.len() != rs.l {
            return Err(format!("private run: the statement is for {} blocks, {} block digests and {} scale pairs were given", rs.l, digests.len(), block_scales.len()));
        }
        // TOKEN I/O R1 LANE: a token-I/O run profile is built by
        // `token_io::run` only; a blocks-only run may not carry its string
        if TOKEN_IO_RUN_PROFILES.contains(&rs.profile) {
            return Err(format!("private run: {} is a token-I/O run profile; a blocks-only run statement may not carry it", rs.profile));
        }
        // TOKEN I/O ROUND 16: nor an R13 classifier run profile (built by
        // `token_io::classify_run` only; the rung's profile keeps its old rule)
        if is_r13_classify_run_profile(rs.profile) {
            return Err(format!("private run: {} is a classifier run profile; a blocks-only run statement may not carry it", rs.profile));
        }
        // RULING CS-4: the endpoint policy against the run's shape
        policy_fits_the_shape(&expected, &rs.sh)?;
        model.check_against(&rs.sh, rs.profile, &digests, block_scales)?;
        let approved = model.calibration.block_scales;
        let n = digests.len();
        let mut st = Self::new_with_calibration(rs, context, expected, digests, n, block_scales, model.identity(), approved)?;
        // NATIVE R8 (R6 for sh_s): a layer's own constants, its whole
        // calibration validated at the trained door
        // (`Shape::with_layer_calibration`: every class, the plane list
        // unmoved, CS-8's rebuild, the trained class)
        let base = st.rs.sh.norm_calibration();
        for (k, r) in model.layers.iter().enumerate() {
            r.check_accuracy_gate(&st.rs.sh)?;
            if let Some(g)=r.accuracy_gate_shift {st.stage_accuracy_gate[k]=g;}
            if super::trained_statement::has_own(&r.own) {
                let cal = super::trained_statement::apply_own(&base, &r.own).map_err(|e| format!("private run: layer {}: {e}", r.index))?;
                st.rs.sh.with_layer_calibration(&cal).map_err(|e| format!("private run: layer {}'s own calibration: {e}", r.index))?;
                st.stage_cal[k] = cal;
            }
        }
        Ok(st)
    }

    #[allow(clippy::too_many_arguments)]
    fn new_with_calibration(rs: RunShape, context: Digest, expected: ExpectedIo, block_digests: Vec<Digest>, n_blocks: usize, block_scales: &[(i32, i32)], calibration: Digest, approved: (i32, i32)) -> Result<RunStatement, String> {
        if n_blocks != rs.l || block_scales.len() != rs.l {
            return Err(format!("private run: the statement is for {} blocks, {} public statements and {} scale pairs were given", rs.l, n_blocks, block_scales.len()));
        }
        if context == [0; 32] {
            return Err("private run: a nonempty context is required".into());
        }
        for k in 0..rs.l - 1 {
            if block_scales[k].1 != block_scales[k + 1].0 {
                return Err(format!(
                    "private run: at boundary {k} block {k} declares output scale {} and block {} declares input scale {}; a boundary has ONE scale",
                    block_scales[k].1,
                    k + 1,
                    block_scales[k + 1].0
                ));
            }
        }
        let (first, last) = (block_scales[0].0, block_scales[rs.l - 1].1);
        if (first, last) != (expected.spec.input_scale(), expected.spec.output_scale()) {
            return Err(format!("private run: the run's external scales ({first}, {last}) are not the endpoint policy's ({}, {})", expected.spec.input_scale(), expected.spec.output_scale()));
        }
        // **RULING R-5 (register D12b item 3), STAGE 21.** The two EXTERNAL
        // scales are bound to the statement through the absorbed
        // expected-IO bytes; the INTERIOR ones were bound by nothing — they
        // are in no absorbed word, and `BoundarySpec::digest()` is never
        // absorbed. They have no arithmetic effect, so no equation was at
        // risk, but a receipt did not attest to them and a scale chosen from
        // the hidden input would publish a hidden intermediate's dynamic
        // range. So a run refuses any block scale pair but the approved
        // calibration's, exactly as `IoSpec::new` already does for the
        // endpoints, and the scales are then carried by the calibration
        // identity the header already absorbs.
        //
        // **NO ABSORB IS ADDED AND NO PROOF BYTE MOVES**: this is a refusal
        // and nothing else. `run_tests::the_run_header_the_approved_scales_
        // bind_is_byte_identical_under_ruling_r5` pins the rung-G `L = 3`
        // binding, both boundary digests and the parameter line as literals
        // captured before this refusal existed.
        //
        // This check is AFTER M-4's boundary-agreement check on purpose: a
        // boundary whose two sides disagree is a different fault and keeps
        // its own message. A future calibration with per-layer scales must
        // put them under its own identity; until then there is one pair.
        for (k, pair) in block_scales.iter().enumerate() {
            if *pair != approved {
                return Err(format!("private run: block scales are pinned to the approved calibration {:?}; block {k} declares {pair:?}", approved));
            }
        }
        let boundary_scales: Vec<i32> = (0..rs.l - 1).map(|k| block_scales[k].1).collect();
        let stage_cal = vec![rs.sh.norm_calibration(); rs.l];
        let stage_accuracy_gate=vec![rs.sh.accuracy_gate_shift;rs.l];
        let st = RunStatement { rs, expected, block_digests, context, boundary_scales, calibration, stage_cal,stage_accuracy_gate };
        // **STAGE 16, ruling T-3.** `Layout::for_shape` has already checked
        // `A`, `H`, `M` and the external endpoint against the BLOCK's set of
        // hash-input lengths. A run absorbs one word no block does — its own
        // `parameters` line, whose length moves with `L` — and it commits one
        // thing no block does, an internal boundary. Both are checked here,
        // against the run's OWN set, before the statement can prove anything.
        // At 125M with twelve blocks the run's line is about 247 bytes, which
        // puts its absorb within a few bytes of the boundary's 304-byte
        // column; that is why this check is at the run and not at the shape.
        let line = st.parameter_line()?;
        // STAGE 17, T-3 AS AMENDED: imposed on legacy-rule profiles only.
        // STAGE 25 (W-4): the set the run checks against now carries the
        // STATEMENT class as well — its own public-statement digest, the
        // boundary spec digest, the calibration identity and the seed
        // derivation its generator is made with — so the run's facts, and
        // not only its parameter line, go into it.
        let facts = super::hash_domain::RunFacts { profile: st.rs.profile, l: st.rs.l, parameter_line: line.as_str() };
        let set = super::hash_domain::imposed_at_shape_with(&st.rs.sh, Some(&facts));
        let lay = Layout::for_shape(&st.rs.sh)?;
        let mut commitments = vec![("A", lay.a_rows), ("H", lay.h_rows), ("M", lay.m_rows()), ("external endpoint", st.rs.sh.endpoint_rows)];
        if st.rs.l > 1 {
            commitments.push(("internal boundary", st.boundary_spec(0)?.commitment_rows()));
        }
        set.refuse(&commitments)?;
        Ok(st)
    }

    /// TEST ONLY. The run header absorbs ONE calibration identity covering
    /// every block and every boundary (ruling M-4); this is how a test shows
    /// that a receipt made under one calibration is rejected under another.
    #[cfg(test)]
    pub(crate) fn with_calibration(mut self, d: Digest) -> RunStatement {
        self.calibration = d;
        self
    }

    /// The statement of internal boundary `k` (between blocks `k` and
    /// `k + 1`). The declared row count is the SHAPE's own endpoint row count
    /// plus one — an independent path to the same number — and
    /// `BoundarySpec::new` checks it against `data + 2*sites + 2` (ruling
    /// M-1). A shape whose declared `endpoint_rows` disagreed with its own
    /// endpoint parameters would be refused here as well as by `IoSpec`.
    pub(crate) fn boundary_spec(&self, k: usize) -> Result<BoundarySpec, String> {
        let sh = &self.rs.sh;
        let scale = *self.boundary_scales.get(k).ok_or_else(|| format!("private run: boundary {k} is not one of this run's {}", self.rs.l.saturating_sub(1)))?;
        // STAGE 18 (ruling T-3 as amended): built under the run's BLOCK shape's
        // hash tag, which is the rule every hash of this run is made under.
        BoundarySpec::new_with_tag(self.context, sh.t_pad, sh.d_pad, scale, (k + 1) as u64, BOUNDARY_SITES, sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols, sh.endpoint_rows + 1, &sh.hash_tag())
    }

    /// `H(block 1's digest || ... || block L's digest)`
    fn public_statement(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-run-blocks/1");
        for d in &self.block_digests {
            h.update(d);
        }
        *h.finalize().as_bytes()
    }

    /// The run parameter line: the block's, plus `L`, the boundary geometry in
    /// the clear and the run's one-transcript claim. Ruling S11b-F4 — a
    /// verifier's geometry inputs must appear in a form a human can read, not
    /// only inside a digest — applies to the boundary exactly as it did to the
    /// endpoint.
    fn parameter_line(&self) -> Result<String, String> {
        let sh = &self.rs.sh;
        let rows = if self.rs.l > 1 { self.boundary_spec(0)?.commitment_rows() } else { 0 };
        Ok(format!(
            "{}/L{}/boundary-log_n{}-rate{}-pad{}-rows{rows}-sites{BOUNDARY_SITES}/external-rows{}/one-run-one-transcript",
            protocol::parameter_line(sh),
            self.rs.l,
            sh.endpoint_log_n,
            sh.endpoint_inv_rate,
            sh.opened_cols,
            sh.endpoint_rows
        ))
    }

    /// What stage `k` commits, which reserved pair each of its two IO tabs
    /// uses, and what it opens. This is the part of the schedule a run adds
    /// over a block, and it is in the run's schedule digest so that a verifier
    /// reads the geometry from its own statement and never from a segment.
    fn stage_line(&self, k: usize) -> Result<String, String> {
        let d = self.rs.data_rows();
        let (l, ins, outs) = (self.rs.l, self.in_site(k)?, self.out_site(k)?);
        Ok(format!(
            "stage {k:02}: commits {}; slot 21 claims {} at pair row {}; slot 22 claims {} at pair row {}; opens M A H then {}{}",
            if k + 1 < l { format!("boundary {k}") } else { "nothing".into() },
            if k == 0 { "the external input endpoint".to_string() } else { format!("boundary {}", k - 1) },
            ins,
            if k + 1 == l { "the external output endpoint".to_string() } else { format!("boundary {k}") },
            outs,
            if k == 0 { "the external input endpoint".to_string() } else { format!("boundary {}", k - 1) },
            if k + 1 == l { ", then the external output endpoint" } else { "" },
        ))
        .map(|s: String| format!("{s}; data rows {d}"))
        // NATIVE R8 (R6 for sh_s): a stage whose layer has its own constants
        // says so in its schedule line, one clause per constant in the
        // canonical order (and so in the schedule digest the header absorbs);
        // a run-wide run's lines are what they were, and an sh_s-only clause
        // is R6's text
        .map(|s| {
            let base = self.rs.sh.norm_calibration();
            let mut s = s;
            for (i, (_, _, label)) in super::trained_statement::OWN_FIELDS.iter().enumerate() {
                let (v, b) = (super::trained_statement::cal_field(&self.stage_cal[k], i), super::trained_statement::cal_field(&base, i));
                if v != b {
                    s.push_str(&format!("; {label} {v} (the layer's own; the run's is {b})"));
                }
            }
            s
        })
    }

    /// **NATIVE R8 (R6 for sh_s): the shape stage `k` is proved and verified
    /// at** — the run shape, or (a layer with its own constants) the same
    /// shape with that layer's calibration, rebuilt through the trained door
    pub(crate) fn stage_shape(&self, k: usize) -> Result<Shape, String> {
        let cal = *self.stage_cal.get(k).ok_or_else(|| format!("private run: no stage {k}"))?;
        let sh=if cal==self.rs.sh.norm_calibration() {self.rs.sh.clone()} else {self.rs.sh.with_layer_calibration(&cal)?};
        if sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {Ok(sh)}
        else {sh.with_accuracy_gate_shift(*self.stage_accuracy_gate.get(k).ok_or("private run: missing R13 stage denominator")?)}
    }

    /// the reserved pair slot 21 (the INCOMING claim) uses in stage `k`
    fn in_site(&self, k: usize) -> Result<usize, String> {
        if k == 0 {
            Ok(self.rs.data_rows())
        } else {
            self.boundary_spec(k - 1)?.mask_row(1)
        }
    }
    /// the reserved pair slot 22 (the OUTGOING claim) uses in stage `k`
    fn out_site(&self, k: usize) -> Result<usize, String> {
        if k + 1 == self.rs.l {
            Ok(self.rs.data_rows())
        } else {
            self.boundary_spec(k)?.mask_row(0)
        }
    }

    fn schedule_digest(&self) -> Result<Digest, String> {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-run-schedule/1");
        let mut line = |s: &str| {
            h.update(&(s.len() as u64).to_le_bytes());
            h.update(s.as_bytes());
        };
        line(&self.parameter_line()?);
        for s in Layout::for_shape(&self.rs.sh)?.describe() {
            line(&s);
        }
        for k in 0..self.rs.l {
            line(&self.stage_line(k)?);
        }
        Ok(*h.finalize().as_bytes())
    }

    /// The run header, absorbed before any commitment exists. Same shape as a
    /// block's (`protocol::transcript`), with the run's quantities.
    fn transcript(&self) -> Result<Transcript, String> {
        let sh = &self.rs.sh;
        // STAGE 17 (ruling T-1): the RUN's transcript carries the profile's
        // Fiat-Shamir key, exactly as a block's does. Every challenge of
        // every stage, and both position tags of every segment (squeezed
        // from a discarded CLONE, which carries the key), are drawn from it.
        let mut tr = protocol::tagged_transcript(sh, self.rs.profile.as_bytes());
        let mut shape_bytes = Vec::with_capacity(7 * 8);
        for v in [self.rs.l, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim] {
            shape_bytes.extend_from_slice(&(v as u64).to_le_bytes());
        }
        tr.absorb(b"run-shape", &shape_bytes);
        tr.absorb(b"expected-IO", &self.expected.to_bytes());
        tr.absorb(b"public-statement", &self.public_statement());
        tr.absorb(b"parameters", self.parameter_line()?.as_bytes());
        tr.absorb(b"calibration", &self.calibration);
        tr.absorb(b"schedule", &self.schedule_digest()?);
        Ok(tr)
    }

    /// **STAGE 14.** The run binding — the transcript state after the header
    /// and before any commitment — which is what the run capture compares its
    /// independently rebuilt header against. Test-only.
    #[cfg(test)]
    pub(crate) fn binding(&self) -> Result<Digest, String> {
        Ok(self.transcript()?.state())
    }

    /// **STAGE 14.** The run's public words, copied out for the run capture
    /// (`run_capture.rs` is a sibling module and cannot read these private
    /// fields). Every word the header absorbs is here in absorb order, so the
    /// recorder rebuilds the header transcript from this alone and compares it
    /// with the binding. Test-only, like the capture itself.
    #[cfg(test)]
    pub(crate) fn capture_header(&self) -> Result<super::run_capture::RunHeader, String> {
        let sh = &self.rs.sh;
        let mut boundaries = Vec::new();
        for k in 0..self.rs.l.saturating_sub(1) {
            let spec = self.boundary_spec(k)?;
            boundaries.push(super::run_capture::BoundaryFacts {
                index: (k + 1) as usize,
                scale: spec.scale(),
                sites: spec.sites(),
                data_rows: spec.data_rows(),
                rows: spec.commitment_rows(),
                site_rows: spec.site_rows(),
                prox_row: spec.prox_row(),
                log_n: spec.log_n(),
                inv_rate: sh.endpoint_inv_rate,
                checks: sh.opened_cols,
                digest: spec.digest(),
                plane: (sh.t_pad, sh.d_pad),
            });
        }
        Ok(super::run_capture::RunHeader {
            profile: self.rs.profile,
            l: self.rs.l,
            sh: sh.clone(),
            run_shape_words: [self.rs.l, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim].iter().map(|v| *v as u64).collect(),
            expected_bytes: self.expected.to_bytes(),
            public_statement: self.public_statement(),
            parameter_line: self.parameter_line()?,
            calibration: self.calibration,
            schedule_digest: self.schedule_digest()?,
            context: self.context,
            block_digests: self.block_digests.clone(),
            boundary_scales: self.boundary_scales.clone(),
            external_input_root: self.expected.input,
            external_output_root: self.expected.output,
            external_rows: sh.endpoint_rows,
            external_data_rows: self.rs.data_rows(),
            external_log_n: sh.endpoint_log_n,
            external_inv_rate: sh.endpoint_inv_rate,
            stage_lines: (0..self.rs.l).map(|k| self.stage_line(k)).collect::<Result<Vec<String>, String>>()?,
            layout_description: Layout::for_shape(sh)?.describe(),
            boundaries,
            external_scales: (self.expected.spec.input_scale(), self.expected.spec.output_scale()),
            // TOKEN I/O (round 7): a block run carries no token facts
            token: None,
            // ROUND 12 (gate round 16): nor classifier facts
            classify: None,
        })
    }

    fn seg_geom(&self, k: usize) -> Result<SegGeom, String> {
        let boundary_rows = if self.rs.l > 1 { self.boundary_spec(0)?.commitment_rows() } else { 0 };
        Ok(SegGeom { l: self.rs.l, k, boundary_rows, sites: BOUNDARY_SITES })
    }

    /// the stage layout: the block's, with the two IO tabs pointed at the
    /// reserved pairs this stage's schedule gives them
    fn stage_layout(&self, k: usize) -> Result<Layout, String> {
        Ok(Layout::for_shape(&self.stage_shape(k)?)?.with_io_mask_rows([self.in_site(k)?, self.out_site(k)?]))
    }
}

/// **THE TRANSCRIPT POSITION TAG.** A challenge squeezed from a CLONE of the
/// transcript: a function of the 32-byte state AND the squeeze counter, which
/// together are the whole state (`transcript.rs`'s `clone_state` copies
/// exactly those two). `zkp-core` publishes no counter accessor and is a file
/// this lane does not edit, so this is how a segment's header and trailer
/// compare both in 32 bytes (finding U-3). The clone is discarded, so nothing
/// the caller's transcript will later produce is disturbed — the same device
/// `check_opening` has always used for its challenge replay.
fn position_tag(tr: &Transcript) -> [u8; 32] {
    let mut c = Transcript::clone_state(tr);
    let v = c.challenge_fp2_vec(2);
    let mut out = [0u8; 32];
    out[..16].copy_from_slice(&v[0].to_bytes());
    out[16..].copy_from_slice(&v[1].to_bytes());
    out
}

/// Process resident high-water mark in MiB, from Linux `/proc/self/status`.
/// A whole-process figure on a shared box: it BOUNDS a stage's cost from
/// above and is not a measurement of it. A mark that RISES across stages of a
/// run is the sign of allocator fragmentation (the check's OMITTED CONDITION
/// 3); it is reported, never repaired here.
pub(crate) fn peak_rss_mib() -> f64 {
    std::fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("VmHWM:")).and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<f64>().ok())))
        .map(|kb| kb / 1024.0)
        .unwrap_or(f64::NAN)
}

/// The private inputs of a run, asked for ONE STAGE AT A TIME so that a
/// twelve-block run never holds twelve witnesses. The honest source builds
/// block `k`'s witness from block `k - 1`'s output; a test source may lie
/// about either, which is what the headline negative test needs.
///
/// **RULING H-1 (the security owner's disposition on the run's hash layer and
/// Fiat–Shamir lift, 2026-09-21): WHAT A PRODUCTION CALLER OWES, and why this
/// trait cannot be the thing that owes it.**
///
/// A run asks for block `k`'s witness inside stage `k`, so the trait PERMITS
/// an adaptive source — one that chooses a witness after seeing the
/// transcript. That looked like an operating condition a caller had to
/// promise. It is not: `RunStatement::transcript` absorbs `expected-IO`
/// before any challenge exists, and those bytes carry BOTH external endpoint
/// commitment roots, which `protocol::check_endpoints` refuses unless the
/// prover's own owners produce exactly them. **So the whole forward pass has
/// already been run before the header** — there is no other way to seal the
/// output root — and the hidden input and the final output are committed
/// before the first message. A run is longer than a block, not harder.
///
/// Two consequences, and they are rules for the caller and not for this file:
///
/// 1. **The pass that seals the endpoints is the WITNESS BUILDER'S OWN, with
///    its refusals.** A production caller runs `witness::build_shaped` (or
///    whatever builds its witnesses) block by block to reach the output plane
///    it seals, so an inadmissible chain is refused BEFORE the header and no
///    partial run directory can arise from that cause. Ruling R-1.3's costing
///    of a separate admissibility pre-pass is withdrawn: the pass is not an
///    addition, it is the one the caller must already have run.
/// 2. **A source must be a PURE FUNCTION of the committed input** — the same
///    witnesses the sealing pass produced, in the same order, whatever the
///    transcript says. Nothing here enforces that; the binding of the two
///    endpoint commitments and the proved chain is what makes a source that
///    departs from it unable to produce an accepted run. Tightening the
///    interface is an item for when the production caller is written.
///
/// Rule M-9 — publish only after the whole run verifies — stays as the second
/// line. `s24_tests::an_inadmissible_chain_is_refused_before_the_run_directory_exists`
/// exercises rule 1 on a three-block rung-G chain.
pub(crate) trait RunWitnessSource {
    /// block `k`'s integer witness, built just in time and consumed by the stage
    fn witness(&mut self, k: usize) -> Result<Witness, String>;
    /// the PADDED plane the prover commits at internal boundary `k`
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String>;
}

#[derive(Clone, Debug, Default)]
pub(crate) struct RunStats {
    /// wall seconds of each stage (witness build excluded)
    pub prove_s: Vec<f64>,
    /// the process high-water mark after each stage
    pub hwm_mib: Vec<f64>,
    pub segment_bytes: Vec<usize>,
}

fn words(v: &[i16]) -> Vec<Fp> {
    v.iter().map(|x| Fp::from_i64(i64::from(*x))).collect()
}

/// **THE RUN PROVER.** One transcript, `L` stages, one OS randomness stream,
/// one NTT table, one masking commitment and one LogUp challenge triple PER
/// BLOCK. Each segment is handed to `sink` and DROPPED before the next stage
/// commits anything (ruling M-3: segments are flushed, not held — eleven
/// unflushed segments are 423 MiB at the 125M shape).
///
/// `sink` is called EXACTLY ONCE per finished segment, in order, with the
/// bytes OWNED: after it returns the prover holds nothing of that segment but
/// its length, in `stats`. Where the bytes then go is `run_sink.rs` —
/// `MemorySink` keeps them (the development-rung tests) and `DirSink` writes
/// each to its own file and keeps only a length and a SHA-256 (what a
/// twelve-block 125M run, 484 MB of receipt, must use).
/// **ROUND 4 (R4-3): where a run's public blocks come from.** A slice of
/// resident blocks (every run before round 4, every one-block run), or a
/// source that holds ONE block at a time and reloads the next on demand (the
/// 32-block Llama-3-8B stack: 7.4 GB of padded public words do not fit
/// beside the prover). A streaming source checks each block it hands out
/// against the statement's digest of it. The proving and verifying paths are
/// otherwise unchanged: block k is the same `&BlockPublic` they always read.
pub(crate) trait BlockSource {
    fn block(&mut self, k: usize) -> Result<BlockRef<'_>, String>;
    /// how many blocks the source holds
    fn count(&self) -> usize;
    /// **RULINGS CS-1 and CS-4** before anything is absorbed: a resident
    /// slice re-checks every block against the run's shape here; a streaming
    /// source builds each block through the constructor's own check at the
    /// shape when it loads it, and `prove_core` / `verify_core` re-run the
    /// check on it before its stage commits or absorbs anything of it.
    fn fit_the_shape(&mut self, sh: &Shape) -> Result<(), String>;
    /// R13 checks the actual stage context before the run header. A
    /// streaming source may reload public blocks here; it still retains at
    /// most one. Legacy sources keep their original preflight path.
    fn fit_the_stages(&mut self,st:&RunStatement)->Result<(),String> {
        if st.rs.sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {return self.fit_the_shape(&st.rs.sh);}
        if self.count()!=st.rs.l {return Err("private run: public block count differs from the stage count".into());}
        for k in 0..st.rs.l {
            let sh=st.stage_shape(k)?;
            self.block(k)?.check_for_shape(&sh).map_err(|e|format!("private run: block{k}: {e}"))?;
        }
        Ok(())
    }

    /// **RULING CS-6** before anything is absorbed: the blocks are the ones
    /// the statement names. A resident slice compares every block's digest;
    /// a streaming source compares the digest list it enforces on every load.
    fn are_the_statements(&mut self, st: &RunStatement) -> Result<(), String>;
}

/// one block, borrowed from a slice or shared out of a streaming cache
pub(crate) enum BlockRef<'a> {
    Borrowed(&'a BlockPublic),
    Shared(std::sync::Arc<BlockPublic>),
}

impl std::ops::Deref for BlockRef<'_> {
    type Target = BlockPublic;
    fn deref(&self) -> &BlockPublic {
        match self {
            BlockRef::Borrowed(b) => b,
            BlockRef::Shared(a) => a,
        }
    }
}

/// the resident blocks of every run before round 4
pub(crate) struct SliceBlocks<'a>(pub &'a [BlockPublic]);

impl BlockSource for SliceBlocks<'_> {
    fn block(&mut self, k: usize) -> Result<BlockRef<'_>, String> {
        self.0.get(k).map(BlockRef::Borrowed).ok_or_else(|| format!("private run: no public statement for block {k}"))
    }
    fn count(&self) -> usize {
        self.0.len()
    }
    fn fit_the_shape(&mut self, sh: &Shape) -> Result<(), String> {
        blocks_fit_the_shape(self.0, sh)
    }
    fn are_the_statements(&mut self, st: &RunStatement) -> Result<(), String> {
        blocks_are_the_statements(st, self.0)
    }
}

/// **RULINGS CS-1 and CS-4** at the run layer (ported from the 125M lane):
/// every block's statement re-checked against the run's shape, refused by
/// name with the block index.
fn blocks_fit_the_shape(blocks: &[BlockPublic], sh: &Shape) -> Result<(), String> {
    for (k, b) in blocks.iter().enumerate() {
        b.check_for_shape(sh).map_err(|e| format!("private run: block {k}: {e}"))?;
    }
    Ok(())
}

/// **RULING CS-4** at the run layer: the run's external endpoint policy
/// re-checked against the run's shape.
fn policy_fits_the_shape(expected: &ExpectedIo, sh: &Shape) -> Result<(), String> {
    expected.spec.check_for_shape(sh).map_err(|e| format!("private run: {e}"))
}

/// the first eight bytes of a digest, as lower-case hex, for a refusal text
pub(crate) fn hex8(d: &Digest) -> String {
    d[..8].iter().map(|b| format!("{b:02x}")).collect()
}

/// **RULING CS-6, the count** (ported from the 125M lane's stage 42).
/// Exactly `L` blocks handed, and a statement holding exactly `L` digests.
fn as_many_blocks_as_the_statement(st: &RunStatement, handed: usize) -> Result<(), String> {
    let l = st.rs.l;
    if handed != l {
        return Err(format!("private run: ruling CS-6 — the run statement names {l} blocks and {handed} public statements were handed"));
    }
    if st.block_digests.len() != l {
        return Err(format!("private run: ruling CS-6 — the run statement holds {} block digests and its run shape is for {l} blocks", st.block_digests.len()));
    }
    Ok(())
}

/// **RULING CS-6 (finding S41-N2 of the 125M lane, statement binding): a
/// run is about the blocks its statement NAMES.** The run absorbs the
/// statement's `block_digests[k]` while every slot of stage `k` is proved and
/// checked against the block the caller HANDS in; so the run prover and the
/// run verifier refuse, by name and before anything is absorbed, unless block
/// `k`'s public digest is the statement's `block_digests[k]`.
fn blocks_are_the_statements(st: &RunStatement, blocks: &[BlockPublic]) -> Result<(), String> {
    as_many_blocks_as_the_statement(st, blocks.len())?;
    for (k, (b, want)) in blocks.iter().zip(&st.block_digests).enumerate() {
        digest_is_the_statements(k, &b.digest(), want)?;
    }
    Ok(())
}

/// block `k`'s digest against the statement's, by CS-6's name
pub(crate) fn digest_is_the_statements(k: usize, got: &Digest, want: &Digest) -> Result<(), String> {
    if got != want {
        return Err(format!(
            "private run: ruling CS-6 — block {k} handed to the run is not the block the run statement names (its public digest begins {}, the statement's {}); refused before anything is absorbed",
            hex8(got),
            hex8(want)
        ));
    }
    Ok(())
}

/// the statement's block digests (a streaming source compares its own list)
impl RunStatement {
    pub(crate) fn block_digests(&self) -> &[Digest] {
        &self.block_digests
    }
}

pub(crate) fn prove_run(st: &RunStatement, blocks: &[BlockPublic], src: &mut dyn RunWitnessSource, externals: Endpoints, sink: &mut dyn FnMut(usize, Vec<u8>) -> Result<(), String>) -> Result<RunStats, String> {
    prove_run_with(st, &mut SliceBlocks(blocks), src, externals, sink)
}

/// [`prove_run`] with the blocks from a [`BlockSource`] (ROUND 4)
pub(crate) fn prove_run_with(st: &RunStatement, blocks: &mut dyn BlockSource, src: &mut dyn RunWitnessSource, externals: Endpoints, sink: &mut dyn FnMut(usize, Vec<u8>) -> Result<(), String>) -> Result<RunStats, String> {
    use std::time::Instant;
    let (sh, l) = (&st.rs.sh, st.rs.l);
    as_many_blocks_as_the_statement(st, blocks.count())?;
    protocol::fits_the_ntt_tables(sh)?;
    // RULINGS CS-1 and CS-4: the blocks and the endpoint policy, before the
    // endpoint owners are opened, the run's randomness is seeded or its
    // header is absorbed
    blocks.fit_the_stages(st)?;
    policy_fits_the_shape(&st.expected, sh)?;
    // RULING CS-6: the blocks handed are the ones the statement names, at
    // the same point. A CHEATING prover runs none of the honest prover's own
    // checks, and the soundness tests play one (ruling CS-3's `#[cfg(test)]`
    // switch); the verifier's check never consults it.
    #[cfg(test)]
    let cheating = protocol::cheating_prover_is_on();
    #[cfg(not(test))]
    let cheating = false;
    if !cheating {
        blocks.are_the_statements(st)?;
    }
    st.expected.spec.validate()?;
    let [ein, eout] = protocol::check_endpoints(sh, &st.expected, externals)?;
    let mut ein = Some(ein);
    let mut eout = Some(eout);
    // ONE OS stream per run; an entropy failure aborts the run, at any stage,
    // before anything of that stage is public.
    //
    // **STAGE 26 (the ruling on finding B-1).** The domain is
    // `hash_domain::run_seed_domain(profile)`: a versioned use literal that
    // says what the stream is (ONE stream for the whole run, handed to every
    // stage and every internal boundary), the run prover's role byte and the
    // RUN profile string — all public, and separated by their bytes from the
    // two endpoint generators' domains and from a single block's.
    let mut rng = ZkRng::from_os(&super::hash_domain::run_seed_domain(st.rs.profile)).map_err(|e| format!("private run randomness: {e}"))?;
    // STAGE 17 (ruling T-1): this run's hash tag, from its own shape.
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st.rs.ntt_log());
    let mut tr = st.transcript()?;
    let binding = tr.state();
    let mut stats = RunStats::default();
    // the claim block k-1's slot 22 raised on B_{k-1}, waiting for block k's
    // slot 21 to raise the other one
    let mut pending: Vec<ZClaim> = Vec::new();
    let mut prev: Option<(BoundarySpec, PreparedBoundary)> = None;

    for k in 0..l {
        let t0 = Instant::now();
        let mut ph = timing::Phases::start();
        let mut phases: Vec<(&'static str, f64)> = Vec::new();
        let mut tick = Instant::now();
        let start_tag = position_tag(&tr);
        // step 1: locality — these slots are block k's weights
        tr.absorb_u64(b"pb-run-stage", k as u64);
        tr.absorb(b"pb-run-block", &st.block_digests[k]);
        // step 2: commit the boundary to the NEXT block, before any challenge
        // of either adjacent equality slot
        let cur = if k + 1 < l {
            let spec = st.boundary_spec(k)?;
            let plane = src.boundary_plane(k)?;
            // ROUND 5: the source's work (block load, witness build) is its
            // own phase, not the first phase of the block's body
            ph.mark(timing::Half::Run, "run: block load + witness (the source)", 1, "block");
            if plane.len() != spec.len() {
                return Err(format!("private run: boundary {k}'s plane is {} words, the padded plane is {}", plane.len(), spec.len()));
            }
            let p = boundary::prepare(&spec, &words(&plane), &ntt, &mut rng, &tag)?;
            ph.mark_bytes(timing::Half::Run, "run: boundary B_k commitment", spec.len() as u64, "words", 8 * spec.len() as u64);
            protocol::absorb_root(&mut tr, b"B", &p.root(), spec.commitment_rows(), spec.log_n());
            Some((spec, p))
        } else {
            None
        };
        // steps 3-8: the measured block, unchanged
        let lay = st.stage_layout(k)?;
        let wit = src.witness(k)?;
        ph.mark(timing::Half::Run, "run: witness hand-over (the last block builds it here)", 1, "block");
        let core = {
            let in_data: &[Fp] = match &prev {
                Some((_, p)) => p.data(),
                None => &ein.as_ref().ok_or("private run: the input endpoint was already consumed")?.data,
            };
            let out_data: &[Fp] = match &cur {
                Some((_, p)) => p.data(),
                None => &eout.as_ref().ok_or("private run: the output endpoint was already consumed")?.data,
            };
            let blk = blocks.block(k)?;
            // NATIVE R6: the stage's own shape (its layer's score shift)
            let ssh = st.stage_shape(k)?;
            protocol::prove_core(&ssh, &lay, &blk, wit, [in_data, out_data], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick)?
        };
        let [ic, oc] = core.io_claims;
        // the incoming commitment's claim list is complete NOW, and not before
        let in_open = match prev.take() {
            Some((spec, owner)) => {
                let mut claims = std::mem::take(&mut pending);
                claims.extend(ic);
                owner.into_opening(&spec, &claims, &mut tr)?
            }
            None => {
                let e = ein.take().ok_or("private run: the input endpoint was already consumed")?;
                protocol::check_endpoint_opening(&ic, sh, &tr)?;
                let o = pcs::open_zk(&e, &ic, &mut tr);
                drop(e);
                o
            }
        };
        let out_open = if k + 1 == l {
            let e = eout.take().ok_or("private run: the output endpoint was already consumed")?;
            protocol::check_endpoint_opening(&oc, sh, &tr)?;
            let o = pcs::open_zk(&e, &oc, &mut tr);
            drop(e);
            Some(o)
        } else {
            pending = oc;
            None
        };
        ph.report("prove", st.rs.profile);
        let end_tag = position_tag(&tr);
        let seg = Segment {
            b_root: cur.as_ref().map(|(_, p)| p.root()),
            a_root: core.a_root,
            h_root: core.h_root,
            mask_root: core.mask_root,
            slots: core.slots,
            mask_open: core.mask_open,
            a_open: core.a_open,
            h_open: core.h_open,
            in_open,
            out_open,
        };
        let bytes = wire::encode_segment(&seg, &lay, st.seg_geom(k)?, &binding, &start_tag, &end_tag)?;
        drop(seg);
        stats.segment_bytes.push(bytes.len());
        // RULING M-3: the segment leaves here and is not held
        sink(k, bytes)?;
        prev = cur;
        stats.prove_s.push(t0.elapsed().as_secs_f64());
        stats.hwm_mib.push(peak_rss_mib());
    }
    Ok(stats)
}

/// **THE RUN VERIFIER, one segment at a time.** Everything it carries between
/// segments and nothing else: the transcript, the run binding, the claim the
/// previous stage raised and the boundary that is waiting to be opened. It
/// never holds a segment — [`RunVerifier::step`] is handed one segment's
/// bytes, which the caller is free to drop the moment it returns. That is
/// what lets a twelve-block 125M run (484 MB of receipt) be verified inside a
/// memory ceiling: see [`verify_run_from_dir`].
struct RunVerifier<'a> {
    st: &'a RunStatement,
    blocks: &'a mut dyn BlockSource,
    ntt: NttTables,
    e_params: PcsParams,
    e_zko: ZkOpts,
    tr: Transcript,
    /// STAGE 17 (ruling T-7): the tag of the profile the VERIFIER trusts,
    /// derived from its own statement's shape and never from a segment.
    tag: HashTag,
    binding: Digest,
    pending: Vec<ZClaim>,
    prev: Option<(BoundarySpec, Digest)>,
}

impl<'a> RunVerifier<'a> {
    /// The run header, absorbed before any segment is looked at. `L` is the
    /// statement's — never a frame's.
    fn start(st: &'a RunStatement, blocks: &'a mut dyn BlockSource) -> Result<RunVerifier<'a>, String> {
        let sh = &st.rs.sh;
        as_many_blocks_as_the_statement(st, blocks.count())?;
        protocol::fits_the_ntt_tables(sh)?;
        // RULINGS CS-1 and CS-4: the blocks and the endpoint policy, before
        // the run header is absorbed
        blocks.fit_the_stages(st)?;
        policy_fits_the_shape(&st.expected, sh)?;
        // RULING CS-6: every block is the one the statement names, before the
        // header that absorbs the statement's digests exists. Never consults
        // the cheating-prover switch.
        blocks.are_the_statements(st)?;
        st.expected.spec.validate()?;
        let ntt = NttTables::new(st.rs.ntt_log());
        let e_params = protocol::endpoint_pcs_params(sh);
        let e_zko = ZkOpts::standard(&e_params);
        let mut tr = st.transcript()?;
        let binding = tr.state();
        Ok(RunVerifier { st, blocks, ntt, e_params, e_zko, tr, tag: sh.hash_tag(), binding, pending: Vec::new(), prev: None })
    }

    /// One stage: it re-derives every geometry from its own statement, and it
    /// COMPUTES each pending boundary claim itself from the slot terminals
    /// rather than reading one from a segment. A segment header's transcript
    /// position is compared and never adopted (ruling M-6), and the header
    /// and trailer are outside the Fiat-Shamir chain.
    fn step(&mut self, k: usize, bytes: &[u8]) -> Result<(), String> {
        let (st, sh, l) = (self.st, &self.st.rs.sh, self.st.rs.l);
        let mut ph = timing::Phases::start();
        let lay = st.stage_layout(k)?;
        let start_tag = position_tag(&self.tr);
        let (seg, end_tag) = wire::decode_segment(bytes, &lay, st.seg_geom(k)?, &self.binding, &start_tag)?;
        // **STAGE 16, ruling T-4.** Every opened column's Merkle path has
        // exactly its commitment's tree depth, checked HERE — before a byte
        // of this stage is hashed — and not left to be an accident of the
        // frame format. `pcs::verify_zk` folds however many siblings it is
        // handed, and a Merkle inner node is the same 64-byte hash as a
        // salted leaf, so a path one entry short is a way to present a node
        // as a leaf. `wire::path_len` is the one source of both numbers.
        super::hash_domain::segment_paths_are_the_tree_depth(&seg, sh)?;
        // STAGE 14: the run capture opens this stage. A no-op unless a
        // recorder is attached; it is handed what the verifier already holds
        // and returns nothing, so no branch below can depend on it.
        #[cfg(test)]
        super::run_capture::stage_begin(k, bytes, start_tag, seg.b_root, seg.a_root, seg.h_root, seg.mask_root, &lay, &self.tr);
        self.tr.absorb_u64(b"pb-run-stage", k as u64);
        self.tr.absorb(b"pb-run-block", &st.block_digests[k]);
        let cur = match (k + 1 < l, seg.b_root) {
            (true, Some(root)) => {
                let spec = st.boundary_spec(k)?;
                protocol::absorb_root(&mut self.tr, b"B", &root, spec.commitment_rows(), spec.log_n());
                Some((spec, root))
            }
            (false, None) => None,
            _ => return Err(format!("private run: segment {k}'s boundary root is not what the run schedule declares")),
        };
        let view = CoreView {
            a_root: seg.a_root,
            h_root: seg.h_root,
            mask_root: seg.mask_root,
            slots: &seg.slots,
            mask_open: &seg.mask_open,
            a_open: &seg.a_open,
            h_open: &seg.h_open,
        };
        let blk = self.blocks.block(k)?;
        // NATIVE R6: the stage's own shape (its layer's score shift)
        let ssh = st.stage_shape(k)?;
        let ([ic, oc], _) = protocol::verify_core(&ssh, &lay, &blk, view, &self.ntt, &mut self.tr, &mut ph)?;
        drop(blk);
        match self.prev.take() {
            Some((spec, root)) => {
                // the verifier's OWN pending claim, computed in stage k-1
                #[cfg(test)]
                let pending = self.pending.len();
                let mut claims = std::mem::take(&mut self.pending);
                #[cfg(test)]
                let incoming = ic.len();
                claims.extend(ic);
                boundary::check_opening(&spec, &claims, &self.tr)?;
                let params = spec.params();
                let cm = protocol::commitment(root, spec.commitment_rows(), spec.log_n());
                #[cfg(test)]
                let rc_before = super::run_capture::checkpoint(&self.tr);
                pcs::verify_zk_tagged(&params, &ZkOpts::standard(&params), &cm, &claims, &seg.in_open, &self.ntt, &mut self.tr, &self.tag).map_err(|e| format!("boundary {}: {e}", k - 1))?;
                #[cfg(test)]
                super::run_capture::pcs(
                    super::run_capture::Geom {
                        role: "Input",
                        commitment_kind: "internal-boundary",
                        params,
                        root,
                        rows: spec.commitment_rows(),
                        data_rows: spec.data_rows(),
                        site_rows: spec.site_rows(),
                        sum_rows: None,
                        prox_row: spec.prox_row(),
                        boundary: Some(k - 1),
                        claim_sources: vec![(k - 1, super::layout::SC_IO_OUT, pending), (k, super::layout::SC_IO_IN, incoming)],
                    },
                    &claims,
                    &seg.in_open,
                    &self.ntt,
                    rc_before,
                    &self.tr,
                );
            }
            None => {
                protocol::check_endpoint_opening(&ic, sh, &self.tr)?;
                let cm = protocol::commitment(st.expected.input, sh.endpoint_rows, sh.endpoint_log_n);
                #[cfg(test)]
                let rc_before = super::run_capture::checkpoint(&self.tr);
                #[cfg(test)]
                let incoming = ic.len();
                pcs::verify_zk_tagged(&self.e_params, &self.e_zko, &cm, &ic, &seg.in_open, &self.ntt, &mut self.tr, &self.tag).map_err(|e| format!("run input endpoint: {e}"))?;
                #[cfg(test)]
                super::run_capture::pcs(
                    super::run_capture::Geom {
                        role: "Input",
                        commitment_kind: "external-endpoint",
                        params: self.e_params,
                        root: st.expected.input,
                        rows: sh.endpoint_rows,
                        data_rows: st.rs.data_rows(),
                        site_rows: vec![st.rs.data_rows(), st.rs.data_rows() + 1],
                        sum_rows: None,
                        prox_row: st.rs.data_rows() + 2,
                        boundary: None,
                        claim_sources: vec![(k, super::layout::SC_IO_IN, incoming)],
                    },
                    &ic,
                    &seg.in_open,
                    &self.ntt,
                    rc_before,
                    &self.tr,
                );
            }
        }
        if k + 1 == l {
            let o = seg.out_open.as_ref().ok_or("private run: the last segment carries no output-endpoint opening")?;
            protocol::check_endpoint_opening(&oc, sh, &self.tr)?;
            let cm = protocol::commitment(st.expected.output, sh.endpoint_rows, sh.endpoint_log_n);
            #[cfg(test)]
            let rc_before = super::run_capture::checkpoint(&self.tr);
            #[cfg(test)]
            let outgoing = oc.len();
            pcs::verify_zk_tagged(&self.e_params, &self.e_zko, &cm, &oc, o, &self.ntt, &mut self.tr, &self.tag).map_err(|e| format!("run output endpoint: {e}"))?;
            #[cfg(test)]
            super::run_capture::pcs(
                super::run_capture::Geom {
                    role: "Output",
                    commitment_kind: "external-endpoint",
                    params: self.e_params,
                    root: st.expected.output,
                    rows: sh.endpoint_rows,
                    data_rows: st.rs.data_rows(),
                    site_rows: vec![st.rs.data_rows(), st.rs.data_rows() + 1],
                    sum_rows: None,
                    prox_row: st.rs.data_rows() + 2,
                    boundary: None,
                    claim_sources: vec![(k, super::layout::SC_IO_OUT, outgoing)],
                },
                &oc,
                o,
                &self.ntt,
                rc_before,
                &self.tr,
            );
        } else {
            self.pending = oc;
            self.prev = cur;
        }
        // the trailer localises a corruption to its own segment; it is
        // COMPARED, never adopted
        if position_tag(&self.tr) != end_tag {
            return Err(format!("private run: segment {k}'s trailer is not the verifier's own transcript position"));
        }
        #[cfg(test)]
        super::run_capture::stage_end(k, end_tag, &self.tr);
        Ok(())
    }

    /// **THE RUN CLOSING CHECK** (the design's §4.3 check 4, in the half that
    /// is real). Every claim the verifier accumulated has been discharged by
    /// an opening, and no commitment it absorbed is still waiting for one. The
    /// check's CORRECTION 8 is right that this is a REGRESSION GUARD ON THE
    /// VERIFIER'S OWN PATH and not a soundness upgrade — the run layout is a
    /// function of the verifier's own statement, so a prover cannot present a
    /// different set of openings without changing a segment length or the
    /// chain — but it is two lines and it fires if this code ever forgets one.
    fn finish(self) -> Result<(), String> {
        if !self.pending.is_empty() || self.prev.is_some() {
            return Err("private run: a boundary claim was left undischarged at the end of the run".into());
        }
        #[cfg(test)]
        super::run_capture::run_accepted();
        Ok(())
    }
}

/// **THE RUN VERIFIER.** It checks exactly `L` segments, `L` being its OWN
/// (from the statement, never from a frame). The segments are the caller's,
/// all of them resident; for a run whose receipt does not fit in memory use
/// [`verify_run_from_dir`], which is the same verifier fed one segment at a
/// time.
pub(crate) fn verify_run(st: &RunStatement, blocks: &[BlockPublic], segments: &[Vec<u8>]) -> Result<(), String> {
    // RULING CS-6: the count, by name, before the segment count
    as_many_blocks_as_the_statement(st, blocks.len())?;
    verify_run_with(st, &mut SliceBlocks(blocks), segments)
}

/// [`verify_run`] with the blocks from a [`BlockSource`] (ROUND 4)
pub(crate) fn verify_run_with(st: &RunStatement, blocks: &mut dyn BlockSource, segments: &[Vec<u8>]) -> Result<(), String> {
    let l = st.rs.l;
    as_many_blocks_as_the_statement(st, blocks.count())?;
    if segments.len() != l {
        return Err(format!("private run: {} segments were offered, this run has {l}", segments.len()));
    }
    let mut v = RunVerifier::start(st, blocks)?;
    for (k, bytes) in segments.iter().enumerate() {
        v.step(k, bytes)?;
    }
    v.finish()
}

/// **THE STREAMING RUN VERIFIER: `L` files, read ONE AT A TIME.** Its memory
/// is the verifier's own state plus ONE segment's bytes — 41 MB at the 125M
/// shape, against a receipt of 484 MB — because each segment is read, stepped
/// and dropped before the next is opened.
///
/// The directory must hold exactly the `L` files [`run_sink::segment_paths`]
/// names and NOTHING ELSE, `L` being the verifier's own: a missing file, an
/// extra segment beyond `L`, a leftover temporary or any foreign file is
/// refused before a byte of any segment is read. Everything past that is the
/// ordinary verifier, so a swapped, duplicated, truncated, foreign or altered
/// FILE is caught exactly as the same bytes in memory would be.
pub(crate) fn verify_run_from_dir(st: &RunStatement, blocks: &[BlockPublic], dir: &std::path::Path) -> Result<(), String> {
    // RULING CS-6: the count, by name, before the directory is listed
    as_many_blocks_as_the_statement(st, blocks.len())?;
    verify_run_from_dir_with(st, &mut SliceBlocks(blocks), dir)
}

/// [`verify_run_from_dir`] with the blocks from a [`BlockSource`] (ROUND 4):
/// ONE segment and ONE block resident
pub(crate) fn verify_run_from_dir_with(st: &RunStatement, blocks: &mut dyn BlockSource, dir: &std::path::Path) -> Result<(), String> {
    verify_run_from_dir_hashed_with(st, blocks, dir).map(|_| ())
}

/// **NATIVE R6 (review r5 finding r5_A).** [`verify_run_from_dir_with`],
/// returning the length and SHA-256 (lower-case hex) of EXACTLY the bytes
/// each segment's verification step consumed, hashed from the same buffer in
/// the same iteration. A statement published after the verification binds
/// these, never a later re-read of the files (which a writer of the run
/// directory could have swapped in between).
pub(crate) fn verify_run_from_dir_hashed_with(st: &RunStatement, blocks: &mut dyn BlockSource, dir: &std::path::Path) -> Result<Vec<(u64, String)>, String> {
    let l = st.rs.l;
    // RULING CS-6: the count and the digests (in `start`) before the
    // directory is listed or any segment file is read
    let mut v = RunVerifier::start(st, blocks)?;
    let paths = run_sink::segment_paths(dir, l)?;
    let mut seen = Vec::with_capacity(l);
    for (k, p) in paths.iter().enumerate() {
        // ONE segment's bytes are resident: read here, dropped at the end of
        // this iteration, before the next file is opened. REVIEW r3_6: read
        // through the bounded reader (the verifier's own counted length,
        // checked from metadata before the file is opened)
        let bytes = read_segment_bounded(st, k, p)?;
        v.step(k, &bytes)?;
        seen.push((bytes.len() as u64, run_sink::digest_hex(&bytes)));
    }
    v.finish()?;
    Ok(seen)
}

/// `O_NOFOLLOW | O_NONBLOCK` on x86-64 Linux (the open flags differ by
/// architecture and this crate takes no `libc` dependency): a path swapped
/// to a symbolic link after the `lstat` fails to open, and one swapped to a
/// FIFO does not block the open. Elsewhere the `fstat` re-check below holds.
#[cfg(all(target_os = "linux", target_arch = "x86_64"))]
const SEGMENT_OPEN_FLAGS: i32 = 0o400000 | 0o4000;

/// **REVIEW r3 FINDING r3_6 (verifier DoS, not soundness; fixed in native
/// round 5): THE BOUNDED SEGMENT READER.** The stack verifier read each
/// segment file with an unbounded `std::fs::read` and compared its length
/// with the counted length only in `wire::decode_segment`, after the whole
/// file was resident: a symbolic link to `/dev/zero` ran into the memory
/// cap, a 512 MiB sparse file was read whole, a FIFO hung forever. Now, in
/// this order and before ONE byte of the segment is read:
///
/// 1. the verifier's OWN counted length `want` of segment `k` (from its run
///    statement, never from a prover-written file), refused above the wire
///    ceiling;
/// 2. `symlink_metadata`: anything that is not a regular file (a symbolic
///    link, FIFO, device, directory) is refused by name, unopened;
/// 3. the metadata length must be exactly `want`;
/// 4. the open does not follow a link nor block on a FIFO (x86-64 Linux),
///    the OPENED file is re-checked (`fstat`: regular, length `want`), and
///    the read is capped at `want + 1` bytes, so a file that grows or is
///    swapped after the check is still refused (`decode_segment` re-checks
///    the length too).
pub(crate) fn read_segment_bounded(st: &RunStatement, k: usize, p: &std::path::Path) -> Result<Vec<u8>, String> {
    use std::io::Read;
    let want = wire::segment_len(&st.stage_layout(k)?, st.seg_geom(k)?);
    let ceiling = wire::wire_ceiling(&st.rs.sh);
    if want > ceiling {
        return Err(format!("private run wire: segment {k}'s counted length {want} B exceeds the wire ceiling {ceiling} B"));
    }
    let meta = std::fs::symlink_metadata(p).map_err(|e| format!("private run: segment {k} ({}) cannot be read: {e}", p.display()))?;
    if !meta.file_type().is_file() {
        return Err(format!("private run: segment {k} ({}) is not a regular file (a symbolic link, FIFO, device or directory is refused before it is opened; review r3_6)", p.display()));
    }
    if meta.len() != want as u64 {
        return Err(format!("private run wire: segment {k} is {} B, the counted length is {want}; refused before it is read (review r3_6)", meta.len()));
    }
    let mut opts = std::fs::OpenOptions::new();
    opts.read(true);
    #[cfg(all(target_os = "linux", target_arch = "x86_64"))]
    {
        use std::os::unix::fs::OpenOptionsExt;
        opts.custom_flags(SEGMENT_OPEN_FLAGS);
    }
    let f = opts.open(p).map_err(|e| format!("private run: segment {k} ({}) cannot be opened as a regular file: {e}", p.display()))?;
    let fm = f.metadata().map_err(|e| format!("private run: segment {k} ({}): {e}", p.display()))?;
    if !fm.file_type().is_file() || fm.len() != want as u64 {
        return Err(format!("private run wire: segment {k} ({}) changed after its check (now {} B, regular file {}); the counted length is {want}", p.display(), fm.len(), fm.file_type().is_file()));
    }
    let mut bytes = Vec::with_capacity(want);
    f.take(want as u64 + 1).read_to_end(&mut bytes).map_err(|e| format!("private run: segment {k} ({}) cannot be read: {e}", p.display()))?;
    if bytes.len() != want {
        return Err(format!("private run wire: segment {k} read {} B, the counted length is {want}", bytes.len()));
    }
    Ok(bytes)
}

/// **REVIEW r4 FINDING r4_B (verifier DoS, not soundness; native R5b): THE
/// BOUNDED READER OF A REGULAR FILE**, with [`read_segment_bounded`]'s open
/// discipline, for every other file the trained CLI and the MVP driver read
/// by path (an export's `profile.json`, manifests, arrays and sequence files;
/// an artifact's policy and single segment): `symlink_metadata` refuses
/// anything that is not a regular file and any length above `max` (or other
/// than `max` when `exact`) BEFORE the open; the open follows no link and
/// does not block on a FIFO (x86-64 Linux); the OPENED file is re-checked
/// (`fstat`: regular, the same length); the read is capped at `max + 1`
/// bytes and its length re-checked — so a path swapped between the check and
/// the read is refused, never followed, blocked on or read without bound.
pub(crate) fn read_regular_file_bounded(path: &std::path::Path, max: u64, exact: bool) -> Result<Vec<u8>, String> {
    use std::io::Read;
    let meta = std::fs::symlink_metadata(path).map_err(|e| format!("{}: {e}", path.display()))?;
    if !meta.file_type().is_file() {
        return Err(format!("{}: not a regular file (a symbolic link, FIFO, device or directory is refused before it is opened)", path.display()));
    }
    let len = meta.len();
    if exact && len != max {
        return Err(format!("{}: {len} bytes on disk, the expected length is {max}; refused before it is read", path.display()));
    }
    if len > max {
        return Err(format!("{}: {len} bytes exceeds the bound {max}; refused before it is read", path.display()));
    }
    let mut opts = std::fs::OpenOptions::new();
    opts.read(true);
    #[cfg(all(target_os = "linux", target_arch = "x86_64"))]
    {
        use std::os::unix::fs::OpenOptionsExt;
        opts.custom_flags(SEGMENT_OPEN_FLAGS);
    }
    let f = opts.open(path).map_err(|e| format!("{}: cannot be opened as a regular file: {e}", path.display()))?;
    let fm = f.metadata().map_err(|e| format!("{}: {e}", path.display()))?;
    if !fm.file_type().is_file() || fm.len() != len {
        return Err(format!("{}: changed after its check; refused", path.display()));
    }
    let mut bytes = Vec::with_capacity(len as usize);
    f.take(max + 1).read_to_end(&mut bytes).map_err(|e| format!("{}: {e}", path.display()))?;
    if bytes.len() as u64 != len {
        return Err(format!("{}: changed while it was read ({} bytes, {len} at the check); refused", path.display(), bytes.len()));
    }
    Ok(bytes)
}
