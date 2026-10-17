//! EXPERIMENTAL: the private BLOCK at ONE fixed geometry (T32 / d16 / 2 heads
//! / 1 KV head / head_dim 8 / F16), profile
//! `hashline-zk-mr1/private-block-t32-poc/1`.
//!
//! STATE (read this first). This module is a copy of the accepted private
//! attention component (`crate::private_attention`, untouched) grown into a
//! complete private transformer block — attention, `norm_m`, the SiLU
//! feed-forward and residual 2 in ONE proof with no seam — per
//! `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md`. The
//! whole-block argument is present: twenty-three slots, six host groups, and
//! the chain `x_in -> ... -> nm -> (g8, u16) -> a16 -> h16 -> z16 -> xres2`
//! closed link by link, with the block's two external endpoints `x_in` and
//! `xres2`. Condition 1 of that disposition (erratum E-1) is met: the profile
//! string, `BlockPublic`, the output endpoint on `xres2`, the calibration
//! binding and the `block_output_cannot_be_chosen` tripwire all land in one
//! commit, with the feed-forward relations already proved. **The profile is
//! not registered, not accepted and not for use**, and nothing here
//! establishes a privacy property. The security owner's implementation
//! disposition accepts it only as an experimental component.
//!
//! WHAT IT IS. A custom prover and verifier for the fixed ZK60 block with the
//! exact integer semantics of `private-block-kernel`
//! (`causal_oracle::FixedCausalOracle`): RMSNorm (isqrt, rounded division),
//! Q/K/V projections, half-split RoPE, causal scores, the integer softmax
//! (masked max, exp table, masked row sum, quotient), PV, the output
//! projection, residual 1, the second RMSNorm, the SiLU feed-forward (gate,
//! activation table lookup, up, product, down) and residual 2. The private
//! input `x_in` and the private output are bound to two CALLER-FIXED hiding
//! endpoint commitments by masked equality sumchecks; weights and tables are
//! public (P1).
//!
//! WHAT IT IS NOT. Not an accepted whole-proof privacy result, not an MVP
//! claim, not a registered block format and not a speed claim. Open, and NOT
//! addressed by anything in this module:
//!  * D8 / D11: simulation against caller-fixed endpoint roots with prior
//!    public history (an earlier authentication path or root-child hash query)
//!    is NOT established. One-use consumption of the endpoint owners is
//!    necessary for this opening design; it does not erase prior history and
//!    is not claimed to. The general privacy game is unchanged.
//!  * the forced-challenge counterexample of
//!    ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md: the refusals here are
//!    per-opening (zero coefficients, dependent proximity pair); no joint-rank
//!    refusal across DIFFERENT uses of one commitment exists, because this
//!    profile never opens any commitment twice. It does not repair a two-use
//!    scheme.
//!  * a written simulator / the captured-receipt joint-view gate of the
//!    construction (section 7), the `fp()` reduction bias (D9), and the
//!    composition across multiple blocks. The norm_m, FFN and residual-2
//!    relations are included in this block's argument.
//!  * refusals of the integer witness builder depend on the private input,
//!    exactly as the kernel's do.
//!
//! The public receipt carries: three roots, per slot ONE mask-bearing scalar,
//! CFS-masked round messages and pair-masked terminals, the M opening and one
//! opening per hiding commitment. No plaintext input, output, activation,
//! histogram, helper sum or claimed scalar sum is in it.
//!
//! Layout and schedule: `layout.rs`. The shared argument: `argument.rs`.
//! Transcript, ownership and openings: `protocol.rs`. Bounded codec: `wire.rs`.

mod argument;
// STAGE 12: the INTERNAL BOUNDARY of a private run — one hiding commitment to
// a hidden plane with TWO claim sites, opened once, whose row count is DERIVED
// from the plane and the site count (ruling M-1) and never accepted from a
// caller. Built additively beside `endpoint_g.rs`, which the run's two
// EXTERNAL endpoints keep unchanged (ruling M-7).
mod boundary;
// STEP S11b: the GENERALISED hidden endpoint, built ADDITIVELY beside the
// FROZEN `private_seam.rs` (which this lane does not edit). The frozen seam
// carries the toy and the rung profiles at exactly its 4,096-word ceiling;
// every wider shape — the rung-G profile and 125M — takes its endpoint
// parameters from the `Shape` through this module.
mod endpoint_g;
// STAGE 16: the two HASH-DOMAIN guards, rulings T-3 and T-4 of the D19
// disposition. Every hash here is an untagged blake3, so hash domains are
// separated only by input LENGTH: this module rebuilds, from the shape alone,
// the whole set of hash-input lengths on a profile's path and refuses any
// commitment whose column digest lands on one (T-3, which completes the
// hard-coded C-H4 of `layout.rs`), and it checks explicitly that every opened
// column's Merkle path has exactly its commitment's tree depth (T-4, which
// makes a protection that was an accident of the wire format into a named
// check of the verifier). It reads no witness and moves no proof byte.
mod hash_domain;
mod layout;
// STEP S9: the pad rule of ruling P-1 — the support indicators, the per-plane
// ZERO / EXEMPT table and the slot map. Part 4 built the term itself in
// `argument::define`, so this module is no longer `cfg(test)`: it is now
// library code beside `layout` and `witness`, and its two acceptance tests
// PZ-1 and PZ-2 live in its own `mod tests`.
mod pad;
mod protocol;
// STAGE 12: the private RUN of `L` blocks under ONE transcript — the run
// statement, the stage order, the segmented receipt, and the prover and
// verifier that drive them. A run is a NEW profile (D17) beside the
// single-block ones, which it leaves byte for byte where they were.
mod run;
// STAGE 13: WHERE a run's segments go — the sink the prover hands each
// finished segment to (in memory, or a directory of one atomically written
// file per segment) and the `L` file names a streaming verifier reads back
// one at a time. The wire format of a segment does not move here.
mod run_sink;
mod shape;
// STAGE 11: the phase clock. A write-only recorder, inert unless
// `HL_PB_TIMING=1`, that answers WHERE the seconds of one block go (the P5
// question: is the feed-forward half worth moving to a second prover?). It
// touches no transcript, no randomness and no committed buffer, and no branch
// of the protocol reads it back.
mod timing;
// LANE C SCRATCH PROTOTYPE (2026-09-30, not in the main tree): the separately
// versioned trained-model / profile / calibration statement a trained run
// binds as its calibration identity. Additive; no existing profile reads it.
mod trained_statement;
// NATIVE LANE (2026-10-17): the trained-block export reader and its CLI
// bridge (`examples/zk60_trained_block.rs`). A CALLER of the run, like the
// MVP driver: it builds the public statement and the trained-model statement
// from a calibration export and adds no protocol code.
mod trained_block;
pub use trained_block::{trained_prove_command, trained_stack_prove_command, trained_stack_verify_command, trained_verify_command};
mod wire;
mod witness;
// The production CLI bridge for a real multi-block run (prove / verify), over
// `run::prove_run` and `run::verify_run_from_dir`. Only its two command entry
// points are public; it adds no protocol code.
mod mvp_driver;
pub use mvp_driver::{prove_command, verify_command};

#[cfg(test)]
mod grow_tests;
// LANE C SCRATCH PROTOTYPE (test-only): the TinyLlama-1.1B geometry — its
// layout counts, the witness-builder blocker at width 2048, a dense synthetic
// one-block proof at that geometry, and the statement binding tests.
#[cfg(test)]
mod lane_c_tinyllama_tests;
// NATIVE LANE (2026-10-17, test-only): the trained norm calibration — the
// validator, the frozen profiles' lines, the binding of every constant, the
// generic honest witness at the trained rung and (heavy) at the TinyLlama
// geometry, and the coefficient / receipt / inconsistent-witness controls.
#[cfg(test)]
mod trained_calib_tests;
// NATIVE LANE (test-only): the export reader on a tiny export this test
// writes itself (rung-TC geometry), its refusals, the parity check and the
// CLI bridge end to end with every control.
#[cfg(test)]
mod trained_block_tests;
// the D24 review's findings (2026-10-17) as permanent tests, with the
// reviewer's softmax forge hook (`witness.rs`, test builds only)
#[cfg(test)]
mod review_d24_tests;
// R2-3: the stack CLI on a small chained multi-layer export (test only)
#[cfg(test)]
mod trained_stack_tests;
// R3-1: the parallel witness products against the sequential ones (test only)
#[cfg(test)]
mod witness_speed_tests;
// R4: the trained Llama-3-8B profile and its generic block (test only)
#[cfg(test)]
mod r4_tests;
// R5-1: the 125M lane's rulings CS-1, CS-3, CS-4, CS-6, CS-7, CS-8, CS-9 and
// S38-F1(a), ported (finding G-1 of the privacy-gate lane; test only)
#[cfg(test)]
mod cs_port_tests;
// STAGE 19 (test-only): DENSE public weights and a numerically non-trivial
// witness at the shaped geometries, where the diagonal fixture leaves every
// hidden unit above `d` with no input and no output weight.
#[cfg(test)]
mod dense_tests;
// STAGE 22: the FOUR-key-value-head development shape `Shape::rung_k4`, the
// only small geometry at which the repaired bilinear slots carry more than
// ONE group bit — proved, tampered with and captured, so that the Python
// privacy gate's ports can finally read a bundle with `lkv = 2`.
#[cfg(test)]
mod k4_tests;
#[cfg(test)]
mod norm_alias;
#[cfg(test)]
mod parity;
#[cfg(test)]
mod refusals;
// STEP S12a: the development rung end to end — the first step of this lane
// that proves at the rung shape and hands the bytes to a fresh verifier.
#[cfg(test)]
mod rung_tests;
// INDEPENDENT ADVERSARIAL CODE REVIEW (delegated reviewer, 2026-09-20): the
// soundness attacks on the lane's shaped block at the development rung. Report:
// `docs/zkmatrix-poc/ZK60_BLOCK125M_RUNG_CODE_REVIEW.md`.
#[cfg(test)]
mod review_tests;
// STAGE 9: the SECURITY OWNER'S RULINGS on that review's findings F-1 … F-9,
// one test per ruling, and the grouped-attention acceptance tamper tests the
// layout memo's section 9a asks for.
#[cfg(test)]
mod rulings_tests;
// STAGE 12: the private RUN of several blocks under ONE transcript, block k's
// hidden output being block k+1's hidden input. Section R1 of this module pins
// the claim audit on a hand-built two-claim boundary schedule BEFORE the
// boundary module exists; the rest drives the run at the development rung.
#[cfg(test)]
mod run_tests;
// STAGE 14: the RUN CAPTURE — the verifier's view of a private run, written
// for the privacy gate of ruling M-8. A NEW module beside the integrator's
// `native_capture.rs`, which it never edits; `cfg(test)` like that one, so no
// production build carries an export surface.
#[cfg(test)]
mod run_capture;
#[cfg(test)]
mod run_capture_tests;
// STAGE 15: the PLANE INDEX TABLE a run capture carries — for every committed
// A and H plane its id, name, domain and row range, and per slot the ordered
// list of planes its terminal vector evaluates. Public layout data derived
// from the shape, written independently of `argument.rs` and checked against
// every captured stage. A recorder's module, `cfg(test)` like `run_capture`.
#[cfg(test)]
mod plane_index;
// STAGE 17: the D19 SEPARATING HASH TAG (ruling T-6 as amended) — which
// profiles are tagged, their eight pinned keys, and the cross-rule rejection
// in both directions at rung-G. The isolated per-layer controls are in
// `zkp-core`; this is the profile-level half.
#[cfg(test)]
mod hash_tag_tests;
// STAGE 18: the PUBLIC RUN STATEMENT retained beside a run's segments, so
// that a process that did not prove the run can rebuild the verifier's
// statement from the files on disk plus the public shape and weights recipe,
// and check the run. Only public values, and ruling D21's rule structurally:
// the only writer verifies the whole run first. `cfg(test)` like
// `run_capture`, and the tests are in `run_tests.rs` beside the runs.
#[cfg(test)]
mod run_statement_file;
// STAGE 20, INDEPENDENT ADVERSARIAL REVIEW (delegated reviewer, 2026-09-20):
// the S19-F1 repair driven through the REAL `argument::define`, plus the
// completeness battery and the padded-head-slot / cross-group cheating
// witnesses. Report:
// `docs/zkmatrix-poc/ZK60_BLOCK125M_S20_FIX_REVIEW.md`.
#[cfg(test)]
mod s20_review_tests;
// STAGE 23: the two shape refusals of the security owner's disposition on the
// generic-rank lemma at the shaped layouts (rulings S-1 and S-3). Both name a
// shape condition the privacy argument depends on that nothing checked.
#[cfg(test)]
mod s23_tests;
// STAGE 24: the ENFORCEMENT BATCH of the security owner's dispositions of
// 2026-09-21 on the run's hash layer (rulings H-1, H-4, H-5, H-8) and on the
// slot closures at the shaped layouts (rulings C-2, C-3, C-4, C-7), plus
// round 6 of the native run gate. Each item turns something that was true
// into something that is CHECKED.
#[cfg(test)]
mod s24_tests;
// STAGE 25: the lane's share of the QUERY-CLASS work list of
// `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md` §8 (W-2, W-3, W-4, W-6, W-7,
// W-8's assertions 5 and 7, W-11). Every hash input kind of every registered
// profile with its length, the refusal replay's two properties on real
// openings, the statement digests in the legacy length guard, and the source
// scan extended from absorb LABELS to hash CALL SITES.
#[cfg(test)]
mod s25_tests;
// STAGE 26: the STRUCTURAL SEPARATION of the generators' seed derivations at
// every UNFROZEN profile — the ruling on finding B-1 of
// `ZK60_TOY_ROUTE_A_REEXAMINATION.md` and item 6 of the toy statement's §9.
// A domain says what its generator is for; the two frozen legacy-rule
// profiles keep theirs byte for byte.
#[cfg(test)]
mod s26_tests;
// STAGE 28: the PERFORMANCE stage's equality gates. Every arithmetic change
// it makes to the prover is compared, in the same test, against the
// computation it replaces — on ordinary inputs, on the inputs a dishonest
// witness carries, and on the inputs that must be refused.
#[cfg(test)]
mod s28_tests;
// STAGE 28, THE INDEPENDENT ADVERSARIAL REVIEW (test-only, written by a
// reviewer who did not write stage 28): the same equalities re-derived on
// randomised descriptors, the refusal branch the stage's own gates never
// take, every parallel path under one, two and eight threads, and a census of
// which shape crosses which of the stage's five parallel thresholds.
// Report: `docs/zkmatrix-poc/ZK60_BLOCK125M_S28_REVIEW.md`.
#[cfg(test)]
mod s28_review_tests;
// STAGE 29 (ruling V-4 of the security owner's disposition): both branches of
// every size threshold stage 28 introduced, crossed in the ORDINARY filter
// and each compared against the text at `79f0726`; and `eq_cube`'s
// precondition, now a hard assertion, agreeing with the old gather on every
// admitted triple and panicking by name on a violated one.
#[cfg(test)]
mod s29_tests;
// STAGE 30: the UNPADDED arm of ruling P-1's pad rule. `Shape::rung_p2` is
// 125M's own padded-domain set — `Dom::T`, `Dom::Kv` and `Dom::F` unpadded,
// the other six padded — at a size the ordinary filter runs in seconds, so
// the arm that only an `#[ignore]`d 125M test used to reach is tested here.
#[cfg(test)]
mod p2_tests;
// STAGE 31: correction C-6. `Shape::rung_c6` is the first development shape
// whose norm window fills its top byte limb exactly, so the four `scaled`
// norm lookups are dropped, `Dom::D` carries 17 helpers instead of 19 and
// the `H` plane list is two planes shorter — the last branch of stage 30's
// heavy-only list that a small shape could reach.
#[cfg(test)]
mod c6_tests;
// STAGE 32: the 125M ROW GEOMETRY. `Shape::rung_w14` is the first
// development shape at the 125M row width (`log_cols = 14`, encoded 2^16),
// the 125M head size (`head_dim = 64`) and the 125M endpoint log
// (`endpoint_log_n = 14`) — the three branches stage 31 left that one small
// shape could reach, at the smallest token count refusal F-2 admits.
#[cfg(test)]
mod w14_tests;
// STAGE 33, item 4b of stage 32's heavy-only list: the 125M ENDPOINT's ROW
// COUNT. `Shape::rung_e32` is rung-W14's head axis at 32 tokens and a row
// width of 2^10, so the endpoint cube is 2^15 and the endpoint has 32 data
// rows and 37 commitment rows — 125M's own counts — at a twentieth of 125M's
// receipt. It does not reach the endpoint LOG, which is rung-W14's half.
#[cfg(test)]
mod e32_tests;
// STAGE 33: the two closures the security owner ruled after reading stage 32.
// Ruling J-7a — the premise under stage 32's DECLARED 60-byte transcript
// coincidence ("a profile string is ASCII and has no NUL") becomes a check
// over the whole registry, and the separation becomes a lemma over every
// registered profile length and every absorb layout of that length. Ruling
// S-6 — the family of shapes that reaches `Shape::a_groups`'s first arm,
// which no registered shape does, becomes a NAMED construction refusal.
#[cfg(test)]
mod s33_tests;
// STAGE 34 (ruling I-8 of the slot expression IR disposition): the twenty-three
// slot polynomials written down as DATA beside the closures, with the closures
// as the oracle. `cfg(test)` on purpose and not merely for tidiness — the
// stage's whole claim is that no execution path changes and no byte moves, and
// a module no production build compiles is the strongest form of it. The
// base-field classification is DERIVED from each table's provenance and never
// declared (ruling I-2, the check's finding IR-C1).
#[cfg(test)]
mod slot_ir;
#[cfg(test)]
mod slot_ir_tests;
// STAGE 35 (stage 2 of ruling I-4 of the same disposition): lever (b) inside
// the closures of slots 17 and 14. The module holds the two closure bodies as
// they stood at `89e393f`, VERBATIM, and the two arms hand it their real
// definition-time captures under `cfg(test)` so that the old form and the new
// one are compared on the same table vector at every definition.
#[cfg(test)]
mod s35_tests;
#[cfg(test)]
mod tamper;
#[cfg(test)]
mod tests;
#[cfg(test)]
mod zero_witness_tests;
// PRIVACY GATE LANE, P-12 (2026-10-17, test-only): the stage-47 G-R4
// root-rebuild check ported to the trained TinyLlama T32 tree.
#[cfg(test)]
mod gr4_trained_tests;

use crate::field::Fp;
use crate::merkle::Digest;
use crate::ntt::NttTables;
use crate::pcs::{self, OpeningZk};
use crate::private_seam::{self, PreparedPlane, SeamSpec, Side};
use endpoint_g::{EndpointSpecG, PreparedPlaneG};
use crate::zk::MaskOpening;
use zkp_core::hashtag::HashTag;
// `D` left this list at S11a: `IoSpec` now takes the endpoint plane's extent
// from its shape (`t_pad`, `d_pad`) instead of the toy's two literals.
use layout::{DH, F_E, F_RO, T};

pub const PROFILE: &[u8] = b"hashline-zk-mr1/private-block-t32-poc/1";
pub use wire::MAX_WIRE_BYTES;
pub const EXPECTED_BYTES: usize = 8 + 32 + 4 + 4 + 2 * 32;

/// The approved calibration this profile is PINNED to, exactly as the kernel
/// is ("a different calibration is a different kernel"): the identity digest
/// of `causal_oracle::public_synthetic_registration`, absorbed with the
/// statement so a receipt cannot be replayed under another approved
/// calibration (T1 section F.1 item 2, D12 item 5). The literal is pinned to
/// its source by `the_endpoint_scales_and_calibration_are_the_approved_ones`.
pub fn calibration_identity() -> Digest {
    *blake3::hash(b"B3 public fixed calibration v1").as_bytes()
}

/// The approved calibration's two endpoint exponents, `e_r` for `x_in` and
/// `e_r2` for `xres2`. `IoSpec::new` accepts no others.
pub const ENDPOINT_SCALES: (i32, i32) = (0, 0);

/// One axis of a public weight matrix, named by the DOMAIN whose support it
/// carries (ruling P-2, memo §3.7a condition 3).
#[derive(Clone, Copy, Debug)]
enum Axis {
    /// the `Dom::D` model-width axis: supported on `[0, width)`
    D,
    /// the head-permuted `Dom::Q` axis: supported on the true head SLOTS,
    /// which interleave one padded slot per key-value group (correction C-1)
    Q,
    /// the feed-forward `Dom::F` axis: supported on `[0, hidden)`
    F,
    /// an axis that does not pad, of this length (`Dom::Kv`'s width; or 1 for
    /// a one-dimensional gain vector)
    Full(usize),
}

impl Axis {
    fn len(self, sh: &shape::Shape) -> usize {
        match self {
            Axis::D | Axis::Q => sh.d_pad,
            Axis::F => sh.f_pad,
            Axis::Full(n) => n,
        }
    }
    /// `Ok(())` if index `i` of this axis is supported; the refusal names
    /// WHICH KIND of padded index it is, so the two B-2 cases of §9a — a
    /// weight nonzero at a padded width index, and a `Wo` whose input columns
    /// are in true-head rather than slot order — are told apart by name.
    fn supported(self, sh: &shape::Shape, i: usize) -> Result<(), String> {
        let ok = match self {
            Axis::D => i < sh.width,
            Axis::Q => sh.slot_is_true_head(i / sh.head_dim),
            Axis::F => i < sh.hidden,
            Axis::Full(_) => true,
        };
        if ok {
            Ok(())
        } else if matches!(self, Axis::Q) {
            Err("private block: a public weight is nonzero at a padded head slot".into())
        } else {
            Err("private block: a public weight is nonzero at a padded width index".into())
        }
    }
}

/// **RULING P-2's construction-time check.** `w` is `(outer, inner)`
/// row-major over the two padded axes; every entry whose outer OR inner index
/// is off its axis's support must be zero.
///
/// This is entrywise, which is strictly stronger than the memo's wording
/// ("the folded weight vector vanishes off the support"): folding is a linear
/// combination over the other axis, so an entrywise-zero block folds to zero
/// at every challenge, while a folded vector could vanish at one point and
/// not at another. `pad::tests::the_folded_weight_vectors_vanish_off_support`
/// ties the two together.
fn weights_vanish_off_support(sh: &shape::Shape, w: &[i8], outer: Axis, inner: Axis) -> Result<(), String> {
    let (no, ni) = (outer.len(sh), inner.len(sh));
    debug_assert_eq!(w.len(), no * ni, "the length check runs before this one");
    // NATIVE LANE, round 5: rulings CS-1 / CS-4 re-run this check at every
    // entry, over every word of a block (232 MB at Llama-3-8B), so the scan
    // is first made in PARALLEL over the off-support entries only — a row off
    // its outer support entirely, a supported row at its off-support inner
    // indices — which is exactly the set of entries the sequential loop below
    // can refuse on. The verdict is the same; on a violation the sequential
    // loop runs and names the FIRST one in row-major order, as before.
    {
        use rayon::prelude::*;
        let inner_off: Vec<usize> = (0..ni).filter(|&i| inner.supported(sh, i).is_err()).collect();
        let violation = (0..no).into_par_iter().any(|o| {
            let row = &w[o * ni..(o + 1) * ni];
            if outer.supported(sh, o).is_err() {
                row.iter().any(|v| *v != 0)
            } else {
                inner_off.iter().any(|&i| row[i] != 0)
            }
        });
        if !violation {
            return Ok(());
        }
    }
    for o in 0..no {
        let o_ok = outer.supported(sh, o).is_ok();
        for i in 0..ni {
            if w[o * ni + i] == 0 {
                continue;
            }
            if !o_ok {
                outer.supported(sh, o)?;
            }
            inner.supported(sh, i)?;
        }
    }
    Ok(())
}

/// The attention half of the public statement: attention weights ((output,
/// input) row-major, as `causal_oracle::PublicBlockWeights`), the first norm
/// gain and the three public attention tables. Shape and structure are
/// checked; structure is NOT provenance: the caller must authenticate these
/// words (approved model, registered table digests) before trusting a
/// verdict. It carries no digest of its own: the whole statement is digested
/// once, by `BlockPublic`.
#[derive(Clone)]
pub struct AttentionPublic {
    wq: Vec<i8>,
    wk: Vec<i8>,
    wv: Vec<i8>,
    wo: Vec<i8>,
    gamma_a: Vec<i8>,
    rope_cos: Vec<i64>,
    rope_sin: Vec<i64>,
    exp: Vec<i64>,
}

impl AttentionPublic {
    #[allow(clippy::too_many_arguments)]
    pub fn new(wq: &[i8], wk: &[i8], wv: &[i8], wo: &[i8], gamma_a: &[i8], rope_cos: &[i64], rope_sin: &[i64], exp: &[i64]) -> Result<Self, String> {
        Self::new_shaped(&shape::Shape::toy(), wq, wk, wv, wo, gamma_a, rope_cos, rope_sin, exp)
    }

    /// The same statement at any [`shape::Shape`] (step S6): the weight and
    /// table LENGTHS and the exponential table's scale come from the shape,
    /// the structural rules do not move. `new` is this at `Shape::toy()`.
    ///
    /// **STEP S9, ruling P-2 (memo §3.7a, "the prover side", condition 3).**
    /// The matrices are the **zero-padded, head-permuted** ones: every axis
    /// is the PADDED extent, and every entry off the destination axis's
    /// support must be zero. That is checked here, by name, at construction —
    /// it is the one condition of B-2 that no later relation can recover,
    /// because the matmul slots fold the weight over the padded inner index
    /// and a nonzero padded weight would read a padded activation.
    ///
    /// At the toy every padded extent equals its true extent and the head
    /// permutation is the identity, so the accepted set of statements does
    /// not move by one word.
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new_shaped(
        sh: &shape::Shape,
        wq: &[i8],
        wk: &[i8],
        wv: &[i8],
        wo: &[i8],
        gamma_a: &[i8],
        rope_cos: &[i64],
        rope_sin: &[i64],
        exp: &[i64],
    ) -> Result<Self, String> {
        Self::check_words(sh, wq, wk, wv, wo, gamma_a, rope_cos, rope_sin, exp)?;
        Ok(Self {
            wq: wq.to_vec(),
            wk: wk.to_vec(),
            wv: wv.to_vec(),
            wo: wo.to_vec(),
            gamma_a: gamma_a.to_vec(),
            rope_cos: rope_cos.to_vec(),
            rope_sin: rope_sin.to_vec(),
            exp: exp.to_vec(),
        })
    }

    /// **RULING CS-4 (ported from the 125M lane's stage 41, round 5 of this
    /// lane; finding G-1 of the privacy-gate lane): THE ONE CHECK of an
    /// attention statement against a shape** — every rule of this half that
    /// depends on the shape, in the constructor's own order and with its own
    /// messages. The statement carries no shape, so this runs in
    /// [`AttentionPublic::new_shaped`] and AGAIN, through
    /// [`AttentionPublic::check_for_shape`], wherever a statement meets the
    /// shape it is proved at, before anything is absorbed, committed or drawn.
    #[allow(clippy::too_many_arguments)]
    fn check_words(sh: &shape::Shape, wq: &[i8], wk: &[i8], wv: &[i8], wo: &[i8], gamma_a: &[i8], rope_cos: &[i64], rope_sin: &[i64], exp: &[i64]) -> Result<(), String> {
        let (d, kv, half) = (sh.d_pad, sh.kv_heads * sh.head_dim, sh.head_dim / 2);
        if [wq.len(), wo.len()] != [d * d; 2] || [wk.len(), wv.len()] != [kv * d; 2] || gamma_a.len() != d {
            return Err("private block: public weight shape".into());
        }
        // P-2: the destination axis's support, axis by axis. `Wq` writes the
        // head-permuted `Dom::Q` axis and reads `Dom::D`; `Wk` / `Wv` write
        // `Dom::Kv` (which does not pad on its width axis) and read `Dom::D`;
        // `Wo` reads `Dom::Q` and writes `Dom::D`.
        weights_vanish_off_support(sh, wq, Axis::Q, Axis::D)?;
        weights_vanish_off_support(sh, wk, Axis::Full(kv), Axis::D)?;
        weights_vanish_off_support(sh, wv, Axis::Full(kv), Axis::D)?;
        weights_vanish_off_support(sh, wo, Axis::D, Axis::Q)?;
        weights_vanish_off_support(sh, gamma_a, Axis::Full(1), Axis::D)?;
        if [rope_cos.len(), rope_sin.len()] != [sh.tokens * half; 2] || exp.len() != 256 {
            return Err("private block: public table shape".into());
        }
        let one_ro = 1i64 << F_RO;
        let one_e = 1i64 << sh.f_e;
        if rope_cos.iter().chain(rope_sin.iter()).any(|v| !(-one_ro..=one_ro).contains(v))
            || rope_cos[..half].iter().any(|c| *c != one_ro)
            || rope_sin[..half].iter().any(|s| *s != 0)
        {
            return Err("private block: rope table structure".into());
        }
        if exp[0] != one_e || exp.iter().any(|e| !(0..=one_e).contains(e)) || exp.windows(2).any(|w| w[0] < w[1]) {
            return Err("private block: exp table structure".into());
        }
        Ok(())
    }

    /// **RULING CS-4: the re-check**, by name, of an attention statement that
    /// already exists against the shape it is about to be proved or verified
    /// at, its refusal prefixed with [`CS4_ATTENTION_REFUSAL`].
    pub(crate) fn check_for_shape(&self, sh: &shape::Shape) -> Result<(), String> {
        Self::check_words(sh, &self.wq, &self.wk, &self.wv, &self.wo, &self.gamma_a, &self.rope_cos, &self.rope_sin, &self.exp).map_err(|e| format!("{CS4_ATTENTION_REFUSAL}: {e}"))
    }

    fn absorb_into(&self, h: &mut blake3::Hasher) {
        for w in [&self.wq, &self.wk, &self.wv, &self.wo, &self.gamma_a] {
            h.update(&(w.len() as u64).to_le_bytes());
            h.update(&w.iter().map(|v| *v as u8).collect::<Vec<u8>>());
        }
        for t in [&self.rope_cos, &self.rope_sin, &self.exp] {
            h.update(&(t.len() as u64).to_le_bytes());
            for v in t.iter() {
                h.update(&v.to_le_bytes());
            }
        }
    }

    /// The PUBLIC SYNTHETIC fixture of `causal_oracle::public_synthetic_fixture`
    /// (weights, tables, input). Deliberately public test data: NOT an approved
    /// model, NOT a real input, and no privacy is at stake for these values.
    pub fn synthetic_fixture() -> (Self, Vec<i16>) {
        let (_, w, input) = crate::causal_oracle::public_synthetic_fixture();
        let (cos, sin) = crate::tables_attn::rope_tables_generate(T, DH, 10000.0, F_RO);
        let (exp, _) = crate::tables_attn::exp_member(0, DH, F_E);
        let public = Self::new(&w.wq, &w.wk, &w.wv, &w.wo, &w.gamma_a, &cos, &sin, &exp).expect("public synthetic fixture");
        (public, input)
    }
}

/// **RULING CS-1's name**, the prefix of every re-check's refusal (the
/// constructor's own message follows it). Ported from the 125M lane (stage 40).
const CS1_REFUSAL: &str = "private block: ruling CS-1 — the feed-forward statement does not fit the shape it is proved at";

/// **RULING CS-4's names** (the 125M lane's stage 41): ruling CS-1 extended
/// to every shape-keyed part of a block or run statement.
const CS4_ATTENTION_REFUSAL: &str = "private block: ruling CS-4 — the attention statement does not fit the shape it is proved at";
const CS4_POLICY_REFUSAL: &str = "private block: ruling CS-4 — the endpoint policy does not fit the shape it is proved at";

/// The feed-forward half's PUBLIC words: the second norm gain `gamma_m`, the
/// three `(input, output)` row-major matrices `Wg`, `Wu`, `Wd` exactly as the
/// kernel stores them, and the 256-entry int16-output activation table.
///
/// Every relation of the feed-forward half reads these words, and every one
/// of them enters the public-statement digest through `BlockPublic`.
///
/// The activation table is held as `[i16; 256]`, which is erratum E-2's
/// requirement ("refuses an activation table with any value outside
/// [-32768, 32767], or holds it as `[i16; 256]`") discharged by the TYPE: a
/// type cannot be forgotten by a second constructor, a runtime check can.
/// `new` is the only way in and refuses any other length; there is no byte
/// parser for these words, so there is nothing that could truncate one.
#[derive(Clone)]
pub struct FeedForwardPublic {
    gamma_m: Vec<i8>,
    wg_t: Vec<i8>,
    wu_t: Vec<i8>,
    wd_t: Vec<i8>,
    act: [i16; 256],
}

impl FeedForwardPublic {
    pub fn new(gamma_m: &[i8], wg_t: &[i8], wu_t: &[i8], wd_t: &[i8], act: &[i16]) -> Result<Self, String> {
        Self::new_shaped(&shape::Shape::toy(), gamma_m, wg_t, wu_t, wd_t, act)
    }

    /// The same feed-forward statement at any [`shape::Shape`] (step S6),
    /// with ruling P-2's construction-time support check (step S9): the three
    /// matrices are the zero-padded ones and every entry off the destination
    /// axis's support must be zero. The feed-forward axis carries no head
    /// permutation — only `Dom::Q` does — so its support is a prefix.
    pub(crate) fn new_shaped(sh: &shape::Shape, gamma_m: &[i8], wg_t: &[i8], wu_t: &[i8], wd_t: &[i8], act: &[i16]) -> Result<Self, String> {
        Self::check_words(sh, gamma_m, wg_t, wu_t, wd_t, act)?;
        let act: [i16; 256] = act.try_into().map_err(|_| "private block: activation table shape".to_string())?;
        Ok(Self { gamma_m: gamma_m.to_vec(), wg_t: wg_t.to_vec(), wu_t: wu_t.to_vec(), wd_t: wd_t.to_vec(), act })
    }

    /// **RULING CS-1 (ported from the 125M lane's stage 40): THE ONE CHECK of
    /// a feed-forward statement against a shape** — the padded lengths, ruling
    /// P-2's entrywise support check on the four matrices, the table length,
    /// and ruling S38-F1(a), in the constructor's order with its messages.
    /// Re-run through [`FeedForwardPublic::check_for_shape`] wherever a
    /// statement meets the shape it is proved at.
    fn check_words(sh: &shape::Shape, gamma_m: &[i8], wg_t: &[i8], wu_t: &[i8], wd_t: &[i8], act: &[i16]) -> Result<(), String> {
        let (d, f) = (sh.d_pad, sh.f_pad);
        if gamma_m.len() != d || [wg_t.len(), wu_t.len()] != [d * f; 2] || wd_t.len() != f * d {
            return Err("private block: feed-forward weight shape".into());
        }
        weights_vanish_off_support(sh, gamma_m, Axis::Full(1), Axis::D)?;
        weights_vanish_off_support(sh, wg_t, Axis::D, Axis::F)?;
        weights_vanish_off_support(sh, wu_t, Axis::D, Axis::F)?;
        weights_vanish_off_support(sh, wd_t, Axis::F, Axis::D)?;
        if act.len() != 256 {
            return Err("private block: activation table shape".into());
        }
        // RULING S38-F1(a) (the 125M lane's stage 39): where `Dom::F` pads,
        // every padded position carries `(g8, a16) = (0, 0)` and the
        // never-gated activation LogUp arm looks up the pair `(128, 0)`, a
        // table row only when `act[128] == 0` — any other value makes every
        // honest proof fail at the verifier. Refused by name; where `Dom::F`
        // does not pad nothing changes, and nothing new is absorbed.
        if sh.pads(layout::Dom::F) && act[128] != 0 {
            return Err("private block: activation table act[128] must be 0 at a shape whose feed-forward domain pads (ruling S38-F1(a))".into());
        }
        Ok(())
    }

    /// **RULING CS-1: the re-check**, by name, of a statement that already
    /// exists against the shape it is about to be proved or verified at.
    pub(crate) fn check_for_shape(&self, sh: &shape::Shape) -> Result<(), String> {
        Self::check_words(sh, &self.gamma_m, &self.wg_t, &self.wu_t, &self.wd_t, &self.act).map_err(|e| format!("{CS1_REFUSAL}: {e}"))
    }

    /// The feed-forward half of the PUBLIC SYNTHETIC fixture
    /// (`causal_oracle::public_synthetic_fixture` plus the frozen int16-out
    /// SiLU member `(-3, -11)`). Deliberately public test data: NOT an
    /// approved model and no privacy is at stake for these values.
    pub fn synthetic_fixture() -> Self {
        let (_, w, _) = crate::causal_oracle::public_synthetic_fixture();
        let (act, _) = crate::tables_v3::int16out_member(crate::tables_v3::Act16Fn::Silu, -3, -11).expect("frozen SiLU int16-out member (-3, -11)");
        Self::new(&w.gamma_m, &w.wg_t, &w.wu_t, &w.wd_t, &act).expect("feed-forward synthetic fixture")
    }

    fn absorb_into(&self, h: &mut blake3::Hasher) {
        for w in [&self.gamma_m, &self.wg_t, &self.wu_t, &self.wd_t] {
            h.update(&(w.len() as u64).to_le_bytes());
            h.update(&w.iter().map(|v| *v as u8).collect::<Vec<u8>>());
        }
        // the 256 activation words, little-endian i16, in the digest (E-2)
        h.update(&(self.act.len() as u64).to_le_bytes());
        for v in self.act.iter() {
            h.update(&v.to_le_bytes());
        }
    }
}

/// THE PUBLIC STATEMENT of the block profile: the attention words and the
/// feed-forward words under ONE digest and ONE digest domain, absorbed once
/// as `"public-statement"`. There is no second absorb of any of these words:
/// a second absorb of the same words is a second thing to keep in sync
/// (T2 section F).
///
/// Structure is checked by the two constructors; structure is NOT provenance.
/// The caller must authenticate the words (approved model, registered table
/// digests) against the approved commitments before trusting a verdict.
#[derive(Clone)]
pub struct BlockPublic {
    attention: AttentionPublic,
    feed_forward: FeedForwardPublic,
}

impl BlockPublic {
    pub fn new(attention: AttentionPublic, feed_forward: FeedForwardPublic) -> Self {
        Self { attention, feed_forward }
    }
    pub(crate) fn attention(&self) -> &AttentionPublic {
        &self.attention
    }
    pub(crate) fn feed_forward(&self) -> &FeedForwardPublic {
        &self.feed_forward
    }

    /// **RULINGS CS-1 and CS-4: the whole block statement against the shape
    /// it is proved at** — the attention half's one check, then the
    /// feed-forward half's, in block order, each refusing by its own name.
    pub(crate) fn check_for_shape(&self, sh: &shape::Shape) -> Result<(), String> {
        self.attention.check_for_shape(sh)?;
        self.feed_forward.check_for_shape(sh)
    }

    pub fn digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-block-public/1");
        self.attention.absorb_into(&mut h);
        self.feed_forward.absorb_into(&mut h);
        *h.finalize().as_bytes()
    }

    /// The whole PUBLIC SYNTHETIC fixture (`causal_oracle::
    /// public_synthetic_fixture` plus the frozen int16-out SiLU member
    /// `(-3, -11)`) and its input. Deliberately public test data: NOT an
    /// approved model, NOT a real input, and no privacy is at stake for
    /// these values.
    pub fn synthetic_fixture() -> (Self, Vec<i16>) {
        let (attention, input) = AttentionPublic::synthetic_fixture();
        (Self::new(attention, FeedForwardPublic::synthetic_fixture()), input)
    }
}

/// Trusted request/connection metadata (context must authenticate model,
/// calibration and request). Scales describe the integer words only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct IoSpec {
    context: Digest,
    input_scale: i32,
    output_scale: i32,
    /// **S11a.** The endpoint plane's PADDED extent, `(t_pad, d_pad)` of the
    /// shape this spec is for. `SeamSpec::new` requires both axes to be
    /// powers of two, so the TRUE `(24, 96)` rung endpoint is refused by name
    /// and the padded `(32, 128)` is what the block commits — which is
    /// exactly the `Dom::D` slice `SC_IO_IN` / `SC_IO_OUT` already claim.
    /// The toy's `(T, D)` are unchanged, so [`IoSpec::new`] is byte for byte
    /// what it was.
    t_pad: usize,
    d_pad: usize,
    /// **S11b.** The shape's endpoint PCS parameters and which of the two
    /// endpoint constructions carries them: the FROZEN `private_seam.rs`
    /// (`general == false`, the toy and the rung profiles) or the
    /// GENERALISED `endpoint_g.rs` (`general == true`, the rung-G profile
    /// and 125M). All three are derived by [`shape::Shape::new`]; nothing
    /// here chooses them.
    general: bool,
    endpoint_log_n: usize,
    endpoint_inv_rate: usize,
    endpoint_rows: usize,
    opened_cols: usize,
    /// **STAGE 17, ruling T-1.** The hash tag of the SHAPE this spec is for,
    /// taken once from [`shape::Shape::hash_tag`] in [`IoSpec::new_shaped`].
    /// The endpoint owner commits under it and the block's verifier verifies
    /// under its own shape's, so an endpoint is never the one commitment of a
    /// profile hashed under another rule. It is a derived, public function of
    /// the profile string and no caller supplies it (ruling T-7: the key set
    /// is never an input).
    hash_tag: HashTag,
}

impl IoSpec {
    /// The two declared exponents are PINNED to the approved calibration's
    /// `(e_r, e_r2) = (0, 0)` by this refusal (T1 section F.1 item 1, D12
    /// item 5): the profile is tied to one calibration exactly as the kernel
    /// is, and a tag-equality check that passed on a factor-of-8 mismatch is
    /// what item 5 exists to prevent. The attention component's fixtures
    /// declare `(-3, -3)`; that is Codex's fix on that component and is not
    /// touched from here.
    pub fn new(context: Digest, input_scale: i32, output_scale: i32) -> Result<Self, String> {
        Self::new_shaped(&shape::Shape::toy(), context, input_scale, output_scale)
    }
    /// The same spec at any [`shape::Shape`] (S11a). `new` is this at `Shape::toy()`.
    pub(crate) fn new_shaped(sh: &shape::Shape, context: Digest, input_scale: i32, output_scale: i32) -> Result<Self, String> {
        if (input_scale, output_scale) != ENDPOINT_SCALES {
            return Err("private block: endpoint scales are pinned to the approved calibration (0, 0)".into());
        }
        let spec = Self {
            context,
            input_scale,
            output_scale,
            t_pad: sh.t_pad,
            d_pad: sh.d_pad,
            general: sh.endpoint_general,
            endpoint_log_n: sh.endpoint_log_n,
            endpoint_inv_rate: sh.endpoint_inv_rate,
            endpoint_rows: sh.endpoint_rows,
            opened_cols: sh.opened_cols,
            hash_tag: sh.hash_tag(),
        };
        // RULING CS-4: the constructor's own call of the one check
        spec.check_for_shape(sh)?;
        spec.validate()?;
        Ok(spec)
    }

    /// **RULING CS-4 (ported from the 125M lane's stage 41): THE ONE CHECK
    /// of an endpoint spec against a shape** — the padded endpoint plane, the
    /// endpoint construction, its commitment parameters and the hash tag, all
    /// DERIVED from the shape and none absorbed. Re-run, by name, wherever a
    /// spec meets the shape it is proved at, before the endpoint owners are
    /// opened, anything is absorbed or anything is drawn.
    pub(crate) fn check_for_shape(&self, sh: &shape::Shape) -> Result<(), String> {
        // RULING CS-8 first: the one invariant of a spec that no shape keys
        self.scales_are_the_approved_ones()?;
        let refuse = |what: String| -> Result<(), String> { Err(format!("{CS4_POLICY_REFUSAL}: {what}")) };
        if (self.t_pad, self.d_pad) != (sh.t_pad, sh.d_pad) {
            return refuse(format!("its padded endpoint plane is ({}, {}), this shape's is ({}, {})", self.t_pad, self.d_pad, sh.t_pad, sh.d_pad));
        }
        if self.general != sh.endpoint_general {
            let kind = |g: bool| if g { "the generalised endpoint" } else { "the frozen seam" };
            return refuse(format!("its endpoint construction is {}, this shape's is {}", kind(self.general), kind(sh.endpoint_general)));
        }
        let (mine, theirs) = ((self.endpoint_log_n, self.endpoint_inv_rate, self.endpoint_rows, self.opened_cols), (sh.endpoint_log_n, sh.endpoint_inv_rate, sh.endpoint_rows, sh.opened_cols));
        if mine != theirs {
            return refuse(format!("its endpoint commitment parameters (log_n, rate, rows, opened columns) are {mine:?}, this shape's are {theirs:?}"));
        }
        if self.hash_tag != sh.hash_tag() {
            return refuse("its hash tag is not this shape's (the endpoints were committed under another profile's hashing rule)".into());
        }
        Ok(())
    }

    /// **RULING CS-8 (the 125M lane's stage 43): the pinned scales,
    /// re-checked** in [`IoSpec::check_for_shape`] and [`IoSpec::validate`]
    /// (the fields are writable from every lane file).
    fn scales_are_the_approved_ones(&self) -> Result<(), String> {
        if (self.input_scale, self.output_scale) != ENDPOINT_SCALES {
            return Err(format!(
                "private block: ruling CS-8 — the endpoint policy's scales ({}, {}) are not the approved calibration's {ENDPOINT_SCALES:?}, which IoSpec::new pins (D12 item 5)",
                self.input_scale, self.output_scale
            ));
        }
        Ok(())
    }

    /// **S11b.** Build whichever endpoint statements this spec carries, and
    /// check that their derived commitment geometry is the one the shape
    /// DECLARES. A shape whose `endpoint_rows` disagrees with what its own
    /// parameters give is refused here, at construction, instead of at the
    /// first proof.
    pub(crate) fn validate(&self) -> Result<(), String> {
        // RULING CS-8: every caller re-checks the pinned scales first
        self.scales_are_the_approved_ones()?;
        let rows = if self.general { self.endpoints_g()?[0].commitment_rows() } else { self.seams()?[0].len().div_ceil(1usize << self.endpoint_log_n) + endpoint_g::MASK_ROWS };
        if rows != self.endpoint_rows {
            return Err(format!("private block: this shape declares {} endpoint rows, its endpoint parameters give {rows}", self.endpoint_rows));
        }
        Ok(())
    }
    /// the padded endpoint plane's word count, `t_pad * d_pad`
    pub(crate) fn plane_len(&self) -> usize {
        self.t_pad * self.d_pad
    }
    pub fn input_scale(&self) -> i32 {
        self.input_scale
    }
    pub fn output_scale(&self) -> i32 {
        self.output_scale
    }
    // Endpoint slots 41..44 are the BLOCK profile's (T1 section F.2); an
    // attention-half endpoint (21..24) or an FFN-IO endpoint (1..4) does not
    // fit, and the separation is structural rather than by the scale field.
    fn seams(&self) -> Result<[SeamSpec; 2], String> {
        let (t, d) = (self.t_pad, self.d_pad);
        Ok([SeamSpec::new(self.context, t, d, self.input_scale, 41, 42)?, SeamSpec::new(self.context, t, d, self.output_scale, 43, 44)?])
    }

    /// **S11b.** The same two statements on the GENERALISED endpoint: the
    /// same context, the same padded plane and the same slot pairs, with the
    /// PCS parameters taken from the shape instead of from
    /// `private_seam.rs`'s four constants.
    fn endpoints_g(&self) -> Result<[EndpointSpecG; 2], String> {
        let (t, d, l, r) = (self.t_pad, self.d_pad, self.endpoint_log_n, self.endpoint_inv_rate);
        let q = self.opened_cols;
        // STAGE 18 (ruling T-3 as amended): the endpoint statement is built
        // under THIS SPEC'S OWN hash tag, which `new_shaped` took once from
        // the shape. The tag decides one refusal — the C-H4 length guard,
        // imposed under the legacy rule and not under a tag — and nothing
        // else about the statement.
        Ok([
            EndpointSpecG::new_with_tag(self.context, t, d, self.input_scale, 41, 42, l, r, q, &self.hash_tag)?,
            EndpointSpecG::new_with_tag(self.context, t, d, self.output_scale, 43, 44, l, r, q, &self.hash_tag)?,
        ])
    }

    /// **S11b.** The two committed endpoint planes, whichever construction
    /// carries them, in (input, output) order. The owners are consumed.
    pub(crate) fn into_committed(&self, owners: Endpoints) -> Result<[pcs::CommittedZk; 2], String> {
        match (owners.input, owners.output) {
            (EndpointOwner::Frozen(i), EndpointOwner::Frozen(o)) if !self.general => {
                let [si, so] = self.seams()?;
                Ok([i.into_ffn_endpoint(&si)?, o.into_ffn_endpoint(&so)?])
            }
            (EndpointOwner::General(i), EndpointOwner::General(o)) if self.general => {
                let [si, so] = self.endpoints_g()?;
                Ok([i.into_endpoint(&si)?, o.into_endpoint(&so)?])
            }
            _ => Err("private block: the endpoint owners are not this profile's".into()),
        }
    }
}

/// Public endpoint policy, fixed by the endpoint owner BEFORE proving and
/// obtained by the verifier independently of any candidate receipt. Reading it
/// from an untrusted producer does NOT authorize those endpoints.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ExpectedIo {
    spec: IoSpec,
    input: Digest,
    output: Digest,
}

impl ExpectedIo {
    pub fn from_roots(spec: IoSpec, input: Digest, output: Digest) -> Self {
        Self { spec, input, output }
    }
    pub fn input_root(&self) -> Digest {
        self.input
    }
    pub fn output_root(&self) -> Digest {
        self.output
    }
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut b = Vec::with_capacity(EXPECTED_BYTES);
        b.extend_from_slice(b"HBLKEXP1");
        b.extend_from_slice(&self.spec.context);
        b.extend_from_slice(&self.spec.input_scale.to_le_bytes());
        b.extend_from_slice(&self.spec.output_scale.to_le_bytes());
        b.extend_from_slice(&self.input);
        b.extend_from_slice(&self.output);
        b
    }
    pub fn from_bytes(b: &[u8]) -> Result<Self, String> {
        if b.len() != EXPECTED_BYTES || &b[..8] != b"HBLKEXP1" {
            return Err("private block: expected-policy frame".into());
        }
        let d = |at: usize| -> Digest { b[at..at + 32].try_into().expect("32 bytes") };
        let i = |at: usize| i32::from_le_bytes(b[at..at + 4].try_into().expect("4 bytes"));
        Ok(Self::from_roots(IoSpec::new(d(8), i(40), i(44))?, d(48), d(80)))
    }
    /// NATIVE LANE: the same frame at any [`shape::Shape`] — the endpoint
    /// spec is rebuilt from the VERIFIER's own shape, never from the bytes
    /// (the frame carries only the context, the two scales and the two
    /// roots). `from_bytes` is this at the toy.
    pub(crate) fn from_bytes_at(sh: &shape::Shape, b: &[u8]) -> Result<Self, String> {
        if b.len() != EXPECTED_BYTES || &b[..8] != b"HBLKEXP1" {
            return Err("private block: expected-policy frame".into());
        }
        let d = |at: usize| -> Digest { b[at..at + 32].try_into().expect("32 bytes") };
        let i = |at: usize| i32::from_le_bytes(b[at..at + 4].try_into().expect("4 bytes"));
        Ok(Self::from_roots(IoSpec::new_shaped(sh, d(8), i(40), i(44))?, d(48), d(80)))
    }
}

/// Private endpoint owners: no Clone, no serialization, no value getter.
/// `prove` takes them BY VALUE, so a second proof against the same hiding
/// commitments does not type-check:
///
/// ```compile_fail
/// use hashline::private_block::{prove, BlockPublic, Endpoints, ExpectedIo};
/// fn twice(p: &BlockPublic, x: &[i16], e: &ExpectedIo, owners: Endpoints) {
///     let _ = prove(p, x, e, owners);
///     let _ = prove(p, x, e, owners); // the first attempt consumed the owners
/// }
/// ```
pub struct Endpoints {
    input: EndpointOwner,
    output: EndpointOwner,
}

/// **S11b.** One committed endpoint plane, on whichever of the two
/// constructions its profile selects. Neither variant has a `Clone`, a data
/// getter or a repeated-opening method, and both are consumed by value.
enum EndpointOwner {
    /// the FROZEN `private_seam.rs` (the toy and the rung profiles)
    Frozen(PreparedPlane),
    /// the GENERALISED `endpoint_g.rs` (the rung-G profile and 125M)
    General(PreparedPlaneG),
}

impl EndpointOwner {
    fn root(&self) -> Digest {
        match self {
            EndpointOwner::Frozen(p) => p.commitment().root,
            EndpointOwner::General(p) => p.commitment().root,
        }
    }
}

/// The endpoint owner's step: commit the private input and output planes with
/// fresh OS randomness. `output` is whatever the owner fixes; a value other
/// than the block output makes every later proof fail verification.
pub fn prepare_endpoints(spec: IoSpec, input: &[i16], output: &[i16]) -> Result<(ExpectedIo, Endpoints), String> {
    spec.validate()?;
    if input.len() != spec.plane_len() || output.len() != spec.plane_len() {
        return Err("private block: endpoint shape".into());
    }
    let words = |v: &[i16]| -> Vec<Fp> { v.iter().map(|x| Fp::from_i64(i64::from(*x))).collect() };
    // **S11b.** The frozen seam pins EXACTLY `NttTables::new(12)`
    // (`private_seam.rs:167-174`), so the toy and rung profiles keep building
    // that table and no toy byte moves; the generalised endpoint builds the
    // table its own encoding domain needs.
    let (input, output) = if spec.general {
        let [si, so] = spec.endpoints_g()?;
        let ntt = NttTables::new(si.enc_log().max(so.enc_log()));
        // **STAGE 26 (finding B-1).** The two endpoint generators are told
        // WHICH endpoint they are seeding. The role byte is the only thing
        // that separates their two key-derivation inputs when the two spec
        // digests agree; before this stage the two inputs were byte-identical
        // and the two `/dev/urandom` reads were the whole separation.
        (
            EndpointOwner::General(endpoint_g::prepare(&si, &words(input), &ntt, &spec.hash_tag, endpoint_g::EndpointRole::Input)?),
            EndpointOwner::General(endpoint_g::prepare(&so, &words(output), &ntt, &spec.hash_tag, endpoint_g::EndpointRole::Output)?),
        )
    } else {
        let [si, so] = spec.seams()?;
        let ntt = NttTables::new(12);
        (EndpointOwner::Frozen(private_seam::prepare(&si, Side::Right, &words(input), &ntt)?), EndpointOwner::Frozen(private_seam::prepare(&so, Side::Right, &words(output), &ntt)?))
    };
    let expected = ExpectedIo::from_roots(spec, input.root(), output.root());
    Ok((expected, Endpoints { input, output }))
}

/// The SECRET block output `xres2` of `private-block-kernel::run_block`,
/// recomputed by this module's own integer witness: the value this profile's
/// OUTPUT ENDPOINT carries and what an honest endpoint owner commits. Do not
/// publish, log or hash it as a proof artifact.
pub fn compute_output(public: &BlockPublic, input: &[i16]) -> Result<Vec<i16>, String> {
    witness::build(public.attention(), public.feed_forward(), input)?.output()
}

/// A candidate receipt. Parsing or holding one establishes nothing; acceptance
/// requires `verify` / `verify_bytes` against the caller's own statement.
#[derive(Debug)]
pub struct Receipt {
    a_root: Digest,
    h_root: Digest,
    mask_root: Digest,
    slots: Vec<argument::SlotProof>,
    mask_open: MaskOpening,
    a_open: OpeningZk,
    h_open: OpeningZk,
    io_open: [OpeningZk; 2],
}

/// Shape facts and wall-clock phases of one proving attempt. Contains no
/// witness-dependent value (the lookup totals are fixed by the geometry).
/// Shared-box timings are diagnostic only.
#[derive(Clone, Debug)]
pub struct ProveStats {
    pub phases: Vec<(String, f64)>,
    pub a_rows: usize,
    pub h_rows: usize,
    pub m_rows: usize,
    pub u8_lookups: usize,
    pub exp_lookups: usize,
    pub act_lookups: usize,
    pub transcript_order: Vec<String>,
}

/// Prove the whole block for the private `input`, bound to the caller-fixed
/// endpoints `x_in` and `xres2`. Consumes the endpoint owners on success and on failure; draws
/// one fresh OS randomness stream; publishes nothing on failure.
pub fn prove(public: &BlockPublic, input: &[i16], expected: &ExpectedIo, endpoints: Endpoints) -> Result<Receipt, String> {
    prove_with_stats(public, input, expected, endpoints).map(|(r, _)| r)
}

pub fn prove_with_stats(public: &BlockPublic, input: &[i16], expected: &ExpectedIo, endpoints: Endpoints) -> Result<(Receipt, ProveStats), String> {
    // `endpoints` is dropped on the refusal path too: the owners never outlive the attempt
    let wit = witness::build(public.attention(), public.feed_forward(), input)?;
    protocol::prove_inner(public, wit, expected, endpoints)
}

/// Verify against the caller's public statement and endpoint policy only.
pub fn verify(public: &BlockPublic, expected: &ExpectedIo, receipt: &Receipt) -> Result<(), String> {
    protocol::verify_inner(public, expected, receipt).map(|_| ())
}

/// The exact frame length of this profile (a constant of the geometry).
pub fn encoded_len() -> usize {
    wire::encoded_len(&layout::Layout::new())
}

impl Receipt {
    /// Canonical bounded frame. Encoding checks representation, not validity.
    pub fn to_bytes(&self, public: &BlockPublic, expected: &ExpectedIo) -> Result<Vec<u8>, String> {
        let lay = layout::Layout::new();
        wire::encode(self, &protocol::transcript(public, expected, &lay).state(), &lay)
    }
    /// Decode only: no count or length in the bytes controls allocation or loops.
    pub fn from_bytes(public: &BlockPublic, expected: &ExpectedIo, bytes: &[u8]) -> Result<Self, String> {
        let lay = layout::Layout::new();
        wire::decode(bytes, &protocol::transcript(public, expected, &lay).state(), &lay)
    }
    /// Logical payload bytes (frame minus the 40-byte envelope).
    pub fn payload_size(&self) -> usize {
        encoded_len() - wire::HEADER
    }
    /// **S12a.** The same codec at any [`shape::Shape`]; `to_bytes` is this at
    /// the toy, whose path is left exactly where it was.
    pub(crate) fn to_bytes_at(&self, sh: &shape::Shape, public: &BlockPublic, expected: &ExpectedIo) -> Result<Vec<u8>, String> {
        protocol::single_block_profile_allowed(sh)?;
        let lay = layout::Layout::for_shape(sh)?;
        // STAGE 11: the encode is outside `prove_inner_at`'s recorder, so it
        // gets its own line. `timing::timed` calls the closure and nothing
        // else when the switch is off.
        let n = wire::encoded_len(&lay) as u64;
        timing::timed("prove", "encode to bytes (wire::encode)", n, "B", || wire::encode(self, &protocol::transcript(public, expected, &lay).state(), &lay))
    }
    pub(crate) fn from_bytes_at(sh: &shape::Shape, public: &BlockPublic, expected: &ExpectedIo, bytes: &[u8]) -> Result<Self, String> {
        protocol::single_block_profile_allowed(sh)?;
        let lay = layout::Layout::for_shape(sh)?;
        let n = bytes.len() as u64;
        timing::timed("verify", "decode from bytes (wire::decode)", n, "B", || wire::decode(bytes, &protocol::transcript(public, expected, &lay).state(), &lay))
    }
}

/// **S12a.** `verify_bytes` at any [`shape::Shape`]: decode from bytes with a
/// FRESH layout and verify, which is the only form in which a rung run counts
/// for anything.
pub(crate) fn verify_bytes_at(sh: &shape::Shape, public: &BlockPublic, expected: &ExpectedIo, bytes: &[u8]) -> Result<(), String> {
    #[cfg(test)]
    capture::begin();
    // RULING CS-8: the shape the caller trusts is one `Shape::new` builds
    sh.check_constructed()?;
    // RULINGS CS-1 and CS-4: the block statement and the endpoint policy,
    // before the frame is decoded against the statement's transcript header
    public.check_for_shape(sh)?;
    expected.spec.check_for_shape(sh)?;
    let receipt = Receipt::from_bytes_at(sh, public, expected, bytes)?;
    protocol::verify_inner_at(sh, public, expected, &receipt).map(|_| ())
}

pub fn verify_bytes(public: &BlockPublic, expected: &ExpectedIo, bytes: &[u8]) -> Result<(), String> {
    #[cfg(test)]
    capture::begin();
    // RULINGS CS-1 and CS-4, at the toy's own bytes entry
    let toy = shape::Shape::toy();
    public.check_for_shape(&toy)?;
    expected.spec.check_for_shape(&toy)?;
    verify(public, expected, &Receipt::from_bytes(public, expected, bytes)?)
}

/// The declared mask/CFS schedule of the whole block, line by line: 455 `A`
/// rows, 384 `H` rows, 23 slots, 50 `M` rows (its digest is transcript-bound).
pub fn schedule() -> Vec<String> {
    layout::Layout::new().describe()
}

// Public synthetic receipt diagnostics; compiled out of production builds.
#[cfg(test)]
mod capture {
    type Public = super::BlockPublic;
    const SLOT_LABEL: &[u8] = b"pb-slot";
    const SCALAR_LABEL: &[u8] = b"pb-scalar";
    const TERM_LABEL: &[u8] = b"pb-term";
    include!("native_capture.rs");
}
