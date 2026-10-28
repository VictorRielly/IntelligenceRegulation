//! **The two hash-domain guards of the private block path** — rulings
//! **T-3** and **T-4** of `docs/zkmatrix-poc/ZK60_D19_HASH_TAG_DISPOSITION.md`
//! (the security owner, 2026-09-20), which dispose of the scoping memo
//! `ZK60_D19_HASH_TAG_SCOPING.md`.
//!
//! Every hash in this system is an UNTAGGED BLAKE3 call, so two hash inputs
//! that mean different things are separated only by their LENGTH. Two
//! consequences are guarded here. Everything in this file is a pure function
//! of PUBLIC facts — a shape, a layout, a set of PCS parameters, the number
//! of entries in a published Merkle path. No witness, no field element and no
//! committed value is read anywhere in it, and no refusal string carries
//! anything but fixed text and public numbers.
//!
//! **T-3 — the length guard.** A committed column is hashed as `8 · rows`
//! bytes (`zkp-core/src/pcs.rs`, `hash_column`). [`at_shape`] rebuilds, for
//! one shape, every hash input on that profile's path that is NOT a column
//! digest — the transcript constructor's input, every absorb the block, the
//! endpoint, the boundary and the run perform, the 47-byte squeeze, the
//! generator's 40-byte refill block and the 64-byte Merkle node / salted leaf
//! — and [`HashInputs::refuse`] rejects BY NAME any commitment whose column
//! lands on one of those lengths, saying which commitment, how many rows it
//! has, how many bytes its column hashes to and WHICH hash input that is the
//! length of. This replaces the hard-coded `{5, 8}` of code condition C-H4,
//! which was incomplete: with today's labels 11, 12, 13, 15, 17 and 19 rows
//! are dangerous too, plus 6 at the 125M profile and 7 at the development
//! rung (their transcript constructors).
//!
//! **T-4 — the Merkle path length.** `zkp_core::pcs::verify_zk` hands the
//! published path straight to `MerkleTree::verify_path`
//! (`zkp-core/src/pcs.rs:1019` -> `zkp-core/src/merkle.rs:56-63`), which folds
//! HOWEVER MANY siblings it is given; it never checks the length. A Merkle
//! inner node is `blake3(left ‖ right)` (`merkle.rs:14-19`) and a salted leaf
//! is `blake3(column digest ‖ salt)` (`pcs.rs:640-645`) — the same function on
//! the same 64 bytes — so a prover free to choose the path LENGTH can present
//! an inner node as a leaf and open a planted column. The private block was
//! protected only IMPLICITLY, because `wire.rs` reads a fixed number of path
//! entries out of the layout and never out of the frame.
//! [`paths_are_the_tree_depth`] makes that protection an explicit, named check
//! that the lane's own verifiers run BEFORE the core verifier is called, on
//! the structure they actually hold, whether or not it came off a wire.
//!
//! Neither guard hashes anything, absorbs anything or changes any published
//! byte: both are refusals on geometries no accepted profile has.

use super::shape::Shape;
use zkp_core::hashtag::HashTag;
use crate::pcs::{OpeningZk, PcsParams};
use crate::zk::MaskOpening;
use std::collections::BTreeMap;

// ---------------------------------------------------------------- the fixed
// lengths of the hash calls that are not transcript absorbs. Each is read off
// the cited source, which this lane does not edit.

/// `Transcript::absorb` hashes `state(32) ‖ (label len as u64)(8) ‖ label ‖
/// (data len as u64)(8) ‖ data` — `zkp-core/src/transcript.rs:44-52`. So an
/// absorb's input is `48 + |label| + |data|` bytes.
const ABSORB_FIXED: usize = 32 + 8 + 8;

/// `Transcript::new` hashes `b"hashline-v1/" ‖ domain` —
/// `zkp-core/src/transcript.rs:25-30`. So the constructor's input is
/// `12 + |profile string|` bytes, and it is the ONE transcript length that
/// differs between profiles of the same geometry.
const NEW_FIXED: usize = 12;

/// `Transcript::squeeze_bytes` hashes `state(32) ‖ b"squeeze"(7) ‖
/// counter(8)` — `zkp-core/src/transcript.rs:85-90`.
const SQUEEZE_LEN: usize = 32 + 7 + 8;

/// `ZkRng::refill` hashes `key(32) ‖ counter(8)` — `zkp-core/src/rng.rs:52-56`.
/// This is the 40 the original C-H4 was guarding.
const REFILL_LEN: usize = 32 + 8;

/// A Merkle inner node, `blake3(left ‖ right)` (`zkp-core/src/merkle.rs:14-19`),
/// and a salted leaf, `blake3(column digest ‖ salt)`
/// (`zkp-core/src/pcs.rs:640-645`): the SAME function on the SAME 64 bytes.
/// This is the 64 the original C-H4 was guarding, and the ambiguity T-4
/// addresses from the other side.
const NODE_LEN: usize = 64;

/// `ExpectedIo::to_bytes` — `private_block.rs:165` (`EXPECTED_BYTES`).
const EXPECTED_IO_BYTES: usize = super::EXPECTED_BYTES;

/// A digest is 32 bytes everywhere in this module.
const DIGEST: usize = 32;

/// `run.rs:246-249`: seven `u64`s — `L` and the six geometry axes.
const RUN_SHAPE_BYTES: usize = 7 * 8;

/// One `Fp2` on the wire and in a transcript is 16 bytes.
const FP2: usize = 16;

// ------------------------------------------- STAGE 25 (W-4): the STATEMENT
// class and the GENERATOR's seed derivation. Every length below is a hash
// input on this path that is NOT a transcript operation and NOT a column
// digest — the statement digests D1 … D8 of
// `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md` §5 and the generator's seed
// derivation R1 — and none of them was in the set stage 16 computed. Ruling
// **J-7** keeps work-list item W-4 although the check's B-9.3 narrows the
// hazard to a frozen legacy geometry: *cheap and right*.
//
// The literals are RETYPED here, because two of the three modules that spell
// them (`private_seam.rs` in particular) are outside this lane's write set
// and a sibling module cannot see a private `const`. Each one is pinned to
// its source TEXT by `s25_tests::the_statement_class_lengths_are_the_ones_
// the_code_hashes`, exactly as the three `zkp-core` hasher bodies are.

/// `ZkRng::from_entropy_reader` hashes `b"hashline-zk-os-rng/v1/" ‖ domain`
/// under a key of 32 raw `/dev/urandom` bytes — `zkp-core/src/rng.rs:47-49`.
/// So a seed derivation's input is `22 + |domain|` bytes.
const SEED_FIXED: usize = 22;

/// `calibration_identity()` hashes the 30-byte literal
/// `b"B3 public fixed calibration v1"` — `private_block.rs:229` (D1).
const CALIBRATION_INPUT: usize = 30;

/// `EndpointSpecG::digest` — `endpoint_g.rs:157-165` (D6): a 42-byte `DOMAIN`,
/// a 32-byte context, eight `u64` and one `i32`.
const ENDPOINT_G_DOMAIN: usize = 42;
const ENDPOINT_SPEC_INPUT: usize = ENDPOINT_G_DOMAIN + DIGEST + 8 * 8 + 4;

/// `BoundarySpec::digest` — `boundary.rs:210-222` (D7): a 43-byte `DOMAIN`, a
/// 32-byte context, NINE `u64` and one `i32`.
const BOUNDARY_DOMAIN: usize = 43;
const BOUNDARY_SPEC_INPUT: usize = BOUNDARY_DOMAIN + DIGEST + 9 * 8 + 4;

/// `SeamSpec::digest` — `private_seam.rs:115-132` (D8): a 28-byte `DOMAIN`, a
/// 32-byte context, eight `u64` and one `i32`. **This is the 128 that makes a
/// 16-row commitment dangerous under the legacy rule** (the check's B-9, as
/// narrowed by J-7).
const SEAM_DOMAIN: usize = 28;
const SEAM_SPEC_INPUT: usize = SEAM_DOMAIN + DIGEST + 8 * 8 + 4;

/// `RunStatement::public_statement` hashes `b"hashline/private-run-blocks/1"`
/// and then one 32-byte block digest per block — `run.rs:220-228` (D4).
const RUN_PUBLIC_FIXED: usize = 29;

// ------------------------------------------- STAGE 26: the GENERATORS' seed
// derivation DOMAINS, one per use.
//
// **THE RULING** (`ZK60_TOY_ROUTE_A_REEXAMINATION.md` finding **B-1**,
// `ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` §9 item 6). A generator is
// `ZkRng::from_os(domain)`, whose seed is `blake3_keyed(entropy32,
// b"hashline-zk-os-rng/v1/" ‖ domain)` (`zkp-core/src/rng.rs:44-51`, which
// this lane does not edit and only CALLS). At the frozen toy the two
// ENDPOINT generators are handed a BYTE-IDENTICAL domain, so the two
// `/dev/urandom` reads are the only thing separating them: if the two reads
// ever agreed, the two endpoint commitments would share every pad, salt and
// mask row. The ruling is that **at every UNFROZEN profile the domain
// carries what the generator is for** —
//
// ```text
// domain = <versioned use literal> ‖ <role byte or index, fixed width>
//          ‖ <a PUBLIC spec digest, or the profile string>
// ```
//
// so that the independence assumption has a structural backstop, and (a side
// benefit) the generalised endpoint's derivation input stops being exactly
// **64** bytes — the length of a Merkle node and of a salted leaf.
//
// **THE CAPTURE RULE, stated where the bytes are built.** Every field of
// every domain below is PUBLIC: a fixed literal, a role byte or a boundary
// index, a profile string, or a STATEMENT digest (`EndpointSpecG::digest`,
// `BoundarySpec::digest`) which is a function of the context, the shape
// numbers and the scale and of nothing else. **No witness value, no
// committed plane and no commitment ROOT enters a domain** — a root is a
// function of hidden data, and a domain is not a place to put one.
//
// **WHAT IS FROZEN AND STAYS SO.** The frozen toy and the frozen-seam
// development rung ([`Shape::hashes_under_the_legacy_rule`]) keep the bare
// profile string they pass today, and `private_seam.rs`'s own 28-byte
// `DOMAIN` is in a file this lane may not edit. The split is therefore
// exactly legacy-rule (frozen) against tagged (unfrozen), which is also why
// the legacy length guard's seed rows below cannot move.

/// role `0x00` — the EXTERNAL INPUT endpoint's generator.
pub(crate) const ROLE_ENDPOINT_IN: u8 = 0x00;
/// role `0x01` — the EXTERNAL OUTPUT endpoint's generator. The ONE byte that
/// separates the two endpoints of a geometry whose two spec digests agree.
pub(crate) const ROLE_ENDPOINT_OUT: u8 = 0x01;
/// role `0x02` — the single-block prover's one stream (`protocol.rs`).
pub(crate) const ROLE_SINGLE_BLOCK_PROVER: u8 = 0x02;
/// role `0x03` — the multi-block run prover's one stream (`run.rs`), which
/// every stage and every internal boundary of the run draws from.
pub(crate) const ROLE_RUN_PROVER: u8 = 0x03;

/// 44 bytes. `‖ role(1) ‖ EndpointSpecG::digest()(32)` = a 77-byte domain and
/// a **99**-byte derivation input.
const SEED_USE_ENDPOINT_G: &[u8] = b"hashline-zk-rng/private-block/endpoint-g/v1/";
/// 46 bytes. `‖ index(8, u64 LE) ‖ BoundarySpec::digest()(32)` = an 86-byte
/// domain and a **108**-byte derivation input.
const SEED_USE_BOUNDARY: &[u8] = b"hashline-zk-rng/private-block/run-boundary/v1/";
/// 47 bytes. `‖ role(1) ‖ the block profile string` — 116 / 117 / 106 bytes
/// of derivation input at the rung-G, rung-K4 and 125M profiles.
const SEED_USE_SINGLE_BLOCK: &[u8] = b"hashline-zk-rng/private-block/single-prover/v1/";
/// 58 bytes, and it says what the stream is: ONE stream for the whole run,
/// handed to every stage and every boundary. `‖ role(1) ‖ the run profile
/// string` — 125 / 126 / 115 bytes of derivation input.
const SEED_USE_RUN: &[u8] = b"hashline-zk-rng/private-block/one-stream-per-whole-run/v1/";

/// **The generalised endpoint's generator domain** (`endpoint_g::prepare`).
/// `role` is [`ROLE_ENDPOINT_IN`] or [`ROLE_ENDPOINT_OUT`]; `spec_digest` is
/// [`super::endpoint_g::EndpointSpecG::digest`], a public function of the
/// context, the plane's two axes, the two slot indices, the PCS parameters
/// and the scale. The role byte is what separates the two endpoints of a
/// geometry whose digests agree — which is finding B-1's whole point.
pub(crate) fn endpoint_seed_domain(role: u8, spec_digest: &[u8; 32]) -> Vec<u8> {
    let mut d = Vec::with_capacity(SEED_USE_ENDPOINT_G.len() + 1 + DIGEST);
    d.extend_from_slice(SEED_USE_ENDPOINT_G);
    d.push(role);
    d.extend_from_slice(spec_digest);
    d
}

/// **An internal boundary's generator domain.** `index` is the boundary's own
/// `1 ..= L - 1` (`BoundarySpec::index`) and `spec_digest` is
/// [`super::boundary::BoundarySpec::digest`].
///
/// **There is NO production generator behind this today, deliberately.**
/// `boundary::prepare` takes `&mut ZkRng` from the caller so that a run draws
/// its `L - 1` boundaries from the ONE stream `prove_run` makes (the memo's
/// A-20 item 2, pinned by `s25_tests::no_profile_on_this_path_can_obtain_a_
/// generator_other_than_from_the_operating_system`). This builder is what a
/// boundary that ever seeds its own generator must use, and it is what the
/// module's own tests use in place of reusing the spec-digest domain label.
pub(crate) fn boundary_seed_domain(index: u64, spec_digest: &[u8; 32]) -> Vec<u8> {
    let mut d = Vec::with_capacity(SEED_USE_BOUNDARY.len() + 8 + DIGEST);
    d.extend_from_slice(SEED_USE_BOUNDARY);
    d.extend_from_slice(&index.to_le_bytes());
    d.extend_from_slice(spec_digest);
    d
}

/// **The single-block prover's generator domain** (`protocol::prove_inner_at`).
///
/// **FROZEN PROFILES ARE RETURNED UNCHANGED**: the byte-frozen toy and the
/// frozen-seam development rung get the bare profile string they have always
/// been given, so not one byte of their derivation input moves. Every tagged
/// profile gets the use literal, the role byte and the same profile string.
pub(crate) fn single_block_seed_domain(sh: &Shape) -> Vec<u8> {
    if sh.hashes_under_the_legacy_rule() {
        return sh.profile.as_bytes().to_vec();
    }
    let mut d = Vec::with_capacity(SEED_USE_SINGLE_BLOCK.len() + 1 + sh.profile.len());
    d.extend_from_slice(SEED_USE_SINGLE_BLOCK);
    d.push(ROLE_SINGLE_BLOCK_PROVER);
    d.extend_from_slice(sh.profile.as_bytes());
    d
}

/// **The run prover's generator domain** (`run::prove_run`): the ONE stream a
/// run makes, under the RUN profile string and never the block's. Every
/// registered run profile is tagged — there is no legacy-rule run — and
/// `s26_tests::the_two_frozen_profiles_keep_the_domains_they_have` asserts it,
/// so this needs no frozen branch.
pub(crate) fn run_seed_domain(run_profile: &str) -> Vec<u8> {
    let mut d = Vec::with_capacity(SEED_USE_RUN.len() + 1 + run_profile.len());
    d.extend_from_slice(SEED_USE_RUN);
    d.push(ROLE_RUN_PROVER);
    d.extend_from_slice(run_profile.as_bytes());
    d
}

/// The generalised endpoint's seed-derivation INPUT length, taken from the
/// domain builder itself so that the two can never drift apart.
pub(crate) fn endpoint_seed_input_len() -> usize {
    SEED_FIXED + endpoint_seed_domain(ROLE_ENDPOINT_IN, &[0u8; 32]).len()
}
/// An internal boundary's seed-derivation input length, ditto.
pub(crate) fn boundary_seed_input_len() -> usize {
    SEED_FIXED + boundary_seed_domain(0, &[0u8; 32]).len()
}
/// The single-block prover's seed-derivation input length at this shape.
pub(crate) fn single_block_seed_input_len(sh: &Shape) -> usize {
    SEED_FIXED + single_block_seed_domain(sh).len()
}
/// The run prover's seed-derivation input length at this run profile.
pub(crate) fn run_seed_input_len(run_profile: &str) -> usize {
    SEED_FIXED + run_seed_domain(run_profile).len()
}

/// The run facts a RUN's hash-input set needs and a block's does not: the
/// transcript domain its generator is seeded from, how many blocks its public
/// statement digests, and its own `parameters` line.
pub(crate) struct RunFacts<'a> {
    pub profile: &'a str,
    pub l: usize,
    pub parameter_line: &'a str,
}

/// **STAGE 25, W-4.** The statement-class and generator-class hash inputs of
/// one profile's path, each with a plain-words description. Everything here
/// is a PUBLIC length: a digest's input layout and a profile string's length.
///
/// **What is in it**: D1 the calibration identity; D6/D7/D8 the three spec
/// digests (which one is live depends on the endpoint the shape carries and
/// on whether this is a run); D4 the run's public statement; R1 the seed
/// derivation at every `ZkRng::from_os` domain on the path — the block
/// prover's (`protocol.rs:486`), the run's (`run.rs:510`), the generalised
/// endpoint's (`endpoint_g.rs:224`, the **64** the memo's B-2(a) is about)
/// and the frozen seam's (`private_seam.rs:196`).
///
/// **What is deliberately NOT in it, with the reason.** Three statement
/// digests have a VARIABLE input whose length is not knowable where the guard
/// is imposed: **D2** the block's public/weights digest (`31 + w`, about 9 MB
/// at 125M — the weights do not exist at `Layout::for_shape`), **D3** the
/// block schedule digest and **D5** the run schedule digest (`33 + Σ` and
/// `31 + Σ` over the layout's own description lines, which would need the
/// Layout this guard is called from the middle of). They are computed and
/// checked instead by `s25_tests::every_hash_input_kind_on_every_registered_
/// profiles_path_is_printed_with_its_length`, which asserts at EVERY
/// registered profile that no real commitment's column has their length.
fn statement_class(sh: &Shape, run: Option<&RunFacts<'_>>) -> Vec<(usize, String)> {
    let mut out = vec![(CALIBRATION_INPUT, "the calibration identity digest (D1, private_block.rs:229)".to_string())];
    // **WHICH GENERATOR EXISTS HERE.** A single block's prover makes one
    // (`protocol.rs:486`, under the BLOCK profile). In a run the block prover
    // makes NONE — `prove_run` makes one for the whole run under the RUN
    // profile (`run.rs:510`) and hands `prove_core` a `&mut ZkRng` — which is
    // the check's B-9.2 as ruling J-7 records it, re-derived here from the
    // two call sites.
    if run.is_none() {
        // STAGE 26: the length is taken from the DOMAIN BUILDER, so the guard
        // cannot drift from the bytes `protocol.rs` passes.
        out.push((single_block_seed_input_len(sh), format!("the generator's seed derivation at profile `{}` (R1, protocol.rs)", sh.profile)));
    }
    if sh.endpoint_general {
        out.push((ENDPOINT_SPEC_INPUT, "the generalised endpoint's spec digest (D6, endpoint_g.rs:157)".to_string()));
        out.push((endpoint_seed_input_len(), "the generator's seed derivation at the generalised endpoint (R1, endpoint_g.rs)".to_string()));
    } else {
        out.push((SEAM_SPEC_INPUT, "the frozen seam's spec digest (D8, private_seam.rs:115)".to_string()));
        out.push((SEED_FIXED + SEAM_DOMAIN, "the generator's seed derivation at the frozen seam (R1, private_seam.rs:196)".to_string()));
    }
    if let Some(r) = run {
        out.push((run_seed_input_len(r.profile), format!("the generator's seed derivation at run profile `{}` (R1, run.rs)", r.profile)));
        out.push((RUN_PUBLIC_FIXED + DIGEST * r.l, format!("the run's public statement digest over {} blocks (D4, run.rs:220)", r.l)));
        if r.l > 1 {
            out.push((BOUNDARY_SPEC_INPUT, "an internal boundary's spec digest (D7, boundary.rs:210)".to_string()));
        }
    }
    out
}

// ------------------------------------------------------------- the label table

/// One transcript label on this profile's path, with every `data` length its
/// absorb takes.
///
/// **THIS TABLE IS THE SOURCE OF TRUTH OF T-3.** The length set is built from
/// it and from nothing else, and the test
/// `every_absorb_label_on_the_path_is_in_the_table` fails if a label is
/// absorbed on the path that the table does not carry.
pub(crate) struct LabelUse {
    /// the label, exactly as the call site spells it
    pub label: &'static str,
    /// where it is absorbed. Sites outside `hashline/src/private_block/`
    /// cannot be reached by the source scan and are named here instead.
    pub site: &'static str,
    /// every `data` length in bytes this label's absorb takes on this path
    pub data: Vec<usize>,
}

/// **The shape-free half of the table**: every absorb whose length is the same
/// at every profile this module can build.
///
/// The one deliberate over-approximation is `sc-round`: its data length is
/// `16 (d + 1)` for the degrees the shape declares, and here the WHOLE degree
/// range the module can produce ([`Shape::degree_range`]) is taken instead of
/// the degrees one shape happens to use. The frozen toy carries no support
/// indicator, so its own degrees stop at 4 and 19 rows would be safe there
/// today; the guard refuses 19 at the toy as well, because a guard that
/// changes its answer with a calibration flag is a guard nobody can reason
/// about, and because refusing a geometry no profile has costs nothing.
fn fixed_labels() -> Vec<LabelUse> {
    let (lo, hi) = Shape::degree_range();
    vec![
        LabelUse { label: "run-shape", site: "run.rs:250, run_capture.rs:262", data: vec![RUN_SHAPE_BYTES] },
        LabelUse { label: "expected-IO", site: "protocol.rs:94, run.rs:251", data: vec![EXPECTED_IO_BYTES] },
        LabelUse { label: "public-statement", site: "protocol.rs:95, run.rs:252", data: vec![DIGEST] },
        LabelUse { label: "calibration", site: "protocol.rs:98, run.rs:254", data: vec![DIGEST] },
        LabelUse { label: "schedule", site: "protocol.rs:99, run.rs:255", data: vec![DIGEST] },
        // the four commitment roots, all absorbed through `protocol::absorb_root`
        // (protocol.rs:128-132) except `M`, which is absorbed bare
        LabelUse { label: "A", site: "protocol.rs:641, 820", data: vec![DIGEST] },
        LabelUse { label: "H", site: "protocol.rs:749, 828", data: vec![DIGEST] },
        LabelUse { label: "B", site: "run.rs:438, 567", data: vec![DIGEST] },
        LabelUse { label: "M", site: "protocol.rs:651, 821", data: vec![DIGEST] },
        LabelUse { label: "rows", site: "protocol.rs:130", data: vec![8] },
        LabelUse { label: "log-cols", site: "protocol.rs:131", data: vec![8] },
        LabelUse { label: "pb-run-stage", site: "run.rs:427, 562", data: vec![8] },
        LabelUse { label: "pb-run-block", site: "run.rs:428, 563", data: vec![DIGEST] },
        LabelUse { label: "pb-slot", site: "argument.rs:311", data: vec![8] },
        LabelUse { label: "pb-scalar", site: "argument.rs:331, 362", data: vec![FP2] },
        // ABSORBED INSIDE `zkp-core` AND `zk.rs` — invisible to the source
        // scan, listed here with `file:line`:
        //   `sc-round`  zkp-core/src/sumcheck.rs:109 (prove), :154 (verify),
        //               hashline/src/zk.rs:994 (the masked extension round)
        LabelUse {
            label: "sc-round",
            site: "zkp-core/src/sumcheck.rs:109, :154; hashline/src/zk.rs:994",
            data: (lo..=hi).map(|d| FP2 * (d + 1)).collect(),
        },
        //   `mask-q`    hashline/src/zk.rs:533 (mask_open), :562 (mask_verify)
        //   `mask-prox` hashline/src/zk.rs:542, :565
        // Both carry `2 * 2^MASK_LOG_MSG` extension words (zk.rs:499-509).
        LabelUse { label: "mask-q", site: "hashline/src/zk.rs:533, :562", data: vec![FP2 * (2 << crate::zk::MASK_LOG_MSG)] },
        LabelUse { label: "mask-prox", site: "hashline/src/zk.rs:542, :565", data: vec![FP2 * (2 << crate::zk::MASK_LOG_MSG)] },
    ]
}

/// **The shape-dependent half of the table.** `run_parameter_line` is the
/// run's own `parameters` word (`run.rs:173-185`), which exists only in a
/// multi-block run and whose length moves with `L`; a single block passes
/// `None`.
fn shape_labels(sh: &Shape, run_parameter_line: Option<&str>) -> Vec<LabelUse> {
    let mut out = Vec::new();
    // `parameters`: the block's line always, the run's line as well in a run
    let mut lines = vec![super::protocol::parameter_line(sh).len()];
    if let Some(l) = run_parameter_line {
        lines.push(l.len());
    }
    out.push(LabelUse { label: "parameters", site: "protocol.rs:96, run.rs:253", data: lines });
    // `pb-term`: one absorb per slot, of that slot's private terminals
    // (argument.rs:391). The count is the layout's `slot_terms`, rebuilt here
    // from the SHAPE so that this function can be called from
    // `Layout::for_shape` without building a second layout.
    let (a_sites, h_sites) = sh.claim_sites();
    // NATIVE R9: over THIS profile's slots (a DD profile's dictionary slot
    // included)
    let mut terms: Vec<usize> = (0..sh.n_slots())
        .map(|s| FP2 * (a_sites[s] + h_sites[s] + usize::from(s == super::layout::SC_IO_IN || s == super::layout::SC_IO_OUT)))
        .collect();
    terms.sort_unstable();
    terms.dedup();
    out.push(LabelUse { label: "pb-term", site: "argument.rs:391", data: terms });
    // `pcs-vec` / `pcs-prox`: one clear vector of `n + Q` extension words, at
    // the BLOCK geometry (`A`, `H`) and at the ENDPOINT geometry (the two
    // external endpoints and every internal boundary, which share
    // `endpoint_log_n` / `endpoint_inv_rate` / `opened_cols`).
    // Absorbed in zkp-core/src/pcs.rs:925, :982 (`pcs-vec`) and :927, :987
    // (`pcs-prox`) — invisible to the source scan.
    let block_vec = FP2 * ((1usize << sh.log_cols) + sh.opened_cols);
    let endpoint_vec = FP2 * ((1usize << sh.endpoint_log_n) + sh.opened_cols);
    let mut vecs = vec![block_vec, endpoint_vec];
    vecs.sort_unstable();
    vecs.dedup();
    out.push(LabelUse { label: "pcs-vec", site: "zkp-core/src/pcs.rs:925, :982", data: vecs.clone() });
    out.push(LabelUse { label: "pcs-prox", site: "zkp-core/src/pcs.rs:927, :987", data: vecs });
    out
}

/// Every label on the path, at this shape — the two halves joined. It exists
/// for the source-scan test that keeps the table honest.
#[cfg(test)]
pub(crate) fn path_labels(sh: &Shape, run_parameter_line: Option<&str>) -> Vec<LabelUse> {
    let mut v = fixed_labels();
    v.extend(shape_labels(sh, run_parameter_line));
    v
}

// ------------------------------------------------------------- the length set

/// Every NON-column hash input on one profile's path, keyed by its length in
/// bytes, each with a plain-words description of what it is. A COLUMN DIGEST
/// is `blake3` over `8 · rows` bytes, so a commitment whose row count puts its
/// column on one of these lengths is ambiguous with that input.
pub(crate) struct HashInputs {
    by_len: BTreeMap<usize, Vec<String>>,
}

impl HashInputs {
    fn add(&mut self, len: usize, what: String) {
        let e = self.by_len.entry(len).or_default();
        if !e.contains(&what) {
            e.push(what);
        }
    }

    /// What, if anything, hashes exactly `len` bytes on this path.
    pub(crate) fn describe(&self, len: usize) -> Option<String> {
        self.by_len.get(&len).map(|v| v.join(" / "))
    }

    /// Every row count whose column digest would land on one of these
    /// lengths, with what it would be confused with. A column is `8 · rows`
    /// bytes, so only lengths divisible by eight are reachable at all.
    #[cfg(test)]
    pub(crate) fn dangerous_rows(&self) -> BTreeMap<usize, String> {
        self.by_len.iter().filter(|(l, _)| **l % 8 == 0).map(|(l, v)| (l / 8, v.join(" / "))).collect()
    }

    /// **CODE CONDITION C-H4, completed (T-3).** Refuse, by name, any
    /// commitment whose committed column hashes to the same number of bytes
    /// as some other hash input of this profile's path. Checked at
    /// construction, before a byte is committed, and it changes no proof byte
    /// of any accepted profile: no commitment of the toy, the development
    /// rung, the generalised rung or the 125M shape is anywhere near the set.
    pub(crate) fn refuse(&self, rows: &[(&str, usize)]) -> Result<(), String> {
        for (what, r) in rows {
            let bytes = 8 * r;
            if let Some(collides) = self.describe(bytes) {
                return Err(format!(
                    "private block: the {what} commitment has {r} rows, whose column hashes to {bytes} bytes — the same length as {collides} (C-H4)"
                ));
            }
        }
        Ok(())
    }
}

/// The hash inputs that are the same length at EVERY profile of this module.
///
/// This is what the two statement constructors that hold no profile string —
/// `endpoint_g::EndpointSpecG::new` and `boundary::BoundarySpec::new` — can
/// check for themselves. It is a strict subset of [`at_shape`]: the only
/// shape-dependent length that is ever a multiple of eight is the transcript
/// CONSTRUCTOR's (`12 + |profile|`), which is why 6 rows is dangerous at the
/// 125M profile and 7 at the development rung and neither is in this set.
pub(crate) fn shape_free() -> HashInputs {
    let mut h = HashInputs { by_len: BTreeMap::new() };
    h.add(NODE_LEN, "a Merkle inner node or a salted leaf".to_string());
    h.add(REFILL_LEN, "the generator's refill block".to_string());
    h.add(SQUEEZE_LEN, "a transcript squeeze".to_string());
    for u in fixed_labels() {
        for d in &u.data {
            h.add(ABSORB_FIXED + u.label.len() + d, format!("the transcript absorb of `{}` with {d} bytes of data ({})", u.label, u.site));
        }
    }
    h
}

/// **The whole set, for one shape** (T-3): [`shape_free`] plus the transcript
/// constructor at this profile and every absorb whose length moves with the
/// geometry. `run_parameter_line` is the run's own `parameters` word when this
/// is a run and `None` for a single block.
pub(crate) fn at_shape_with(sh: &Shape, run_parameter_line: Option<&str>) -> HashInputs {
    let mut h = shape_free();
    h.add(NEW_FIXED + sh.profile.len(), format!("the transcript constructor at profile `{}`", sh.profile));
    for u in shape_labels(sh, run_parameter_line) {
        for d in &u.data {
            h.add(ABSORB_FIXED + u.label.len() + d, format!("the transcript absorb of `{}` with {d} bytes of data ({})", u.label, u.site));
        }
    }
    h
}

/// The whole set for a SINGLE BLOCK at this shape.
pub(crate) fn at_shape(sh: &Shape) -> HashInputs {
    at_shape_with(sh, None)
}

/// **STAGE 25 (W-4): the whole set, TRANSCRIPT class plus STATEMENT class.**
/// [`at_shape_with`] is the transcript half stage 16 computed — the
/// constructor, every absorb, the squeeze, the refill and the node — and
/// [`statement_class`] is the half it never had: the statement digests and
/// the generator's seed derivation. This is the set the legacy rule now
/// imposes, and the one every stage-25 test pins.
pub(crate) fn full_at_shape_with(sh: &Shape, run: Option<&RunFacts<'_>>) -> HashInputs {
    let mut h = at_shape_with(sh, run.map(|r| r.parameter_line));
    for (len, what) in statement_class(sh, run) {
        h.add(len, what);
    }
    h
}

/// [`full_at_shape_with`] for a SINGLE BLOCK.
pub(crate) fn full_at_shape(sh: &Shape) -> HashInputs {
    full_at_shape_with(sh, None)
}

/// **The shape-free half of the whole set** — what the two bare statement
/// constructors, which hold no profile string, can check for themselves.
/// [`shape_free`] plus the statement-class lengths that are the same at every
/// profile: the calibration identity's 30, the three spec digests' 128 / 142 /
/// 151, and the two constant seed-derivation domains' 50 and 64. The only new
/// DANGEROUS row count it contributes is **16** (the frozen seam's 128-byte
/// spec digest); 64 was already the node's and the other four are not
/// multiples of eight.
pub(crate) fn full_shape_free() -> HashInputs {
    let mut h = shape_free();
    h.add(CALIBRATION_INPUT, "the calibration identity digest (D1, private_block.rs:229)".to_string());
    h.add(SEAM_SPEC_INPUT, "the frozen seam's spec digest (D8, private_seam.rs:115)".to_string());
    h.add(ENDPOINT_SPEC_INPUT, "the generalised endpoint's spec digest (D6, endpoint_g.rs:157)".to_string());
    h.add(BOUNDARY_SPEC_INPUT, "an internal boundary's spec digest (D7, boundary.rs:210)".to_string());
    h.add(SEED_FIXED + SEAM_DOMAIN, "the generator's seed derivation at the frozen seam (R1, private_seam.rs:196)".to_string());
    h.add(endpoint_seed_input_len(), "the generator's seed derivation at the generalised endpoint (R1, endpoint_g.rs)".to_string());
    h
}

/// **T-3 AS AMENDED (2026-09-20, 15:01): the completed guard is IMPOSED on
/// legacy-rule profiles only.** [`at_shape_with`] above stays the honest
/// DESCRIPTION of a profile's non-column hash lengths at every shape, and the
/// tests go on pinning it at all four; this is the function the prover's and
/// the verifier's construction paths call, and it hands back an EMPTY set at a
/// tagged profile.
///
/// Why. Length is the whole of the domain separation only while every hash is
/// the same unkeyed function. On a TAGGED profile a transcript absorb, a
/// column digest, a salted leaf and a Merkle node are four different members
/// of the BLAKE3 family, so a coincidence of input lengths between two of them
/// means nothing at all. Stage 16's own finding S16-F1 is what forces the
/// point: the completed set refuses geometries the constructions really reach
/// — a generalised endpoint of 13 rows, an internal boundary of 12 — and at
/// the 125M shape a twelve-block run's `parameters` absorb lands two bytes
/// from a boundary column. Imposing it on a tagged profile would cost real
/// geometry for no separation.
///
/// It stays ON, whole, for the two profiles that hash under the legacy rule:
/// the byte-frozen toy, where it is the only separation there is, and the
/// frozen-seam development rung. Both pass it at their accepted geometries.
///
/// **STAGE 25 (W-4).** What is imposed is now [`full_at_shape_with`] — the
/// transcript class AND the statement class — so a 16-row commitment, whose
/// column is the frozen seam's 128-byte spec digest, is refused at a legacy
/// profile by name. The imposition is still legacy-only (ruling T-3 as
/// amended, which J-7 does not reopen): at a tagged profile a transcript
/// absorb, a column digest and a statement digest are `F_T`, `F_C` and `F_U`,
/// three different functions, and a coincidence of their input LENGTHS
/// separates nothing.
pub(crate) fn imposed_at_shape_with(sh: &Shape, run: Option<&RunFacts<'_>>) -> HashInputs {
    if sh.hashes_under_the_legacy_rule() {
        full_at_shape_with(sh, run)
    } else {
        HashInputs { by_len: BTreeMap::new() }
    }
}

/// [`imposed_at_shape_with`] for a SINGLE BLOCK.
pub(crate) fn imposed_at_shape(sh: &Shape) -> HashInputs {
    imposed_at_shape_with(sh, None)
}

/// **STAGE 18: T-3 AS AMENDED AT THE TWO BARE STATEMENT CONSTRUCTORS.**
///
/// [`shape_free`] stays the honest DESCRIPTION of the shape-independent half
/// of the set and every stage-16 test goes on pinning it. This is what
/// `endpoint_g::EndpointSpecG::new_with_tag` and
/// `boundary::BoundarySpec::new_with_tag` IMPOSE: the same half under the
/// legacy rule, and an EMPTY set under a tag.
///
/// Stage 17 could not do this. Those two constructors hold no profile string,
/// so they went on refusing the shape-free eight at every profile, which
/// stage 17 recorded as a deviation from the letter of the amended ruling.
/// They now take the rule from the caller that knows it — the shape's own
/// [`Shape::hash_tag`], through `IoSpec` for an endpoint and through
/// `RunStatement` for a boundary — so the amended rule holds at all four
/// sites that impose the set and at none that does not.
///
/// The reason is [`imposed_at_shape_with`]'s: on a tagged profile a
/// transcript absorb, a column digest, a salted leaf and a Merkle node are
/// four different members of the BLAKE3 family, so a coincidence of their
/// input LENGTHS separates nothing and costs real geometry.
///
/// **STAGE 25 (W-4)**: the shape-free half now carries the statement class
/// too ([`full_shape_free`]), so these two constructors refuse a 16-row
/// commitment under the legacy rule. No accepted geometry moves: the
/// generalised endpoint's reachable counts are 6, 7, 9, 13, 21, 37 … and an
/// internal boundary's are `data + 2·sites + 2`; 16 is neither of the two
/// profiles' own.
pub(crate) fn imposed_shape_free(tag: &HashTag) -> HashInputs {
    if tag.is_legacy() {
        full_shape_free()
    } else {
        HashInputs { by_len: BTreeMap::new() }
    }
}

// ---------------------------------------------------------------- T-4: paths

/// The Merkle tree depth of a commitment with these PCS parameters. It is
/// read from [`super::wire::path_len`], which is the SAME expression the frame
/// format uses to fix how many path entries a receipt carries — one source,
/// not two.
pub(crate) fn tree_depth(params: &PcsParams) -> usize {
    super::wire::path_len(params)
}

/// **T-4.** Every opened column of `o` carries exactly `tree_depth(params)`
/// sibling digests. Called by the lane's verifiers BEFORE the core verifier,
/// which folds whatever length it is handed and so would accept a Merkle
/// inner node in place of a salted leaf under a path one entry short.
///
/// The refusal is fixed text plus public numbers: which commitment, the
/// position of the opening in the frame, how many entries it carries and how
/// many the commitment's tree has.
pub(crate) fn paths_are_the_tree_depth(what: &str, params: &PcsParams, o: &OpeningZk) -> Result<(), String> {
    let depth = tree_depth(params);
    for (i, (_, _, _, path)) in o.columns.iter().enumerate() {
        if path.len() != depth {
            return Err(format!(
                "private block: opened column {i} of the {what} commitment carries a Merkle path of {} entries; this commitment's tree is {depth} deep (T-4)",
                path.len()
            ));
        }
    }
    Ok(())
}

/// **T-4 for the masking commitment.** Its tree is built over the
/// `2^MASK_LOG_DOM` columns of the masking encoding (`hashline/src/zk.rs:463`),
/// which is the same number `wire.rs` reads its path entries from.
pub(crate) fn mask_paths_are_the_tree_depth(o: &MaskOpening) -> Result<(), String> {
    let depth = super::wire::MASK_PATH_LEN;
    for (i, (_, _, _, path)) in o.columns.iter().enumerate() {
        if path.len() != depth {
            return Err(format!(
                "private block: opened column {i} of the M commitment carries a Merkle path of {} entries; this commitment's tree is {depth} deep (T-4)",
                path.len()
            ));
        }
    }
    Ok(())
}

/// **T-4 for one single-block receipt**: the three block commitments and the
/// two external endpoints, checked before the frame shape check and before
/// any of the block's hashing.
pub(crate) fn receipt_paths_are_the_tree_depth(r: &super::Receipt, sh: &Shape) -> Result<(), String> {
    let bp = super::protocol::pcs_params_at(sh);
    let ep = super::protocol::endpoint_pcs_params(sh);
    paths_are_the_tree_depth("A", &bp, &r.a_open)?;
    paths_are_the_tree_depth("H", &bp, &r.h_open)?;
    mask_paths_are_the_tree_depth(&r.mask_open)?;
    for (i, o) in r.io_open.iter().enumerate() {
        paths_are_the_tree_depth(&format!("endpoint {i}"), &ep, o)?;
    }
    Ok(())
}

/// **T-4 for one run segment**, checked the moment the segment is decoded and
/// before a byte of the stage is hashed: the three block commitments, the
/// opening this stage closes (an internal boundary, or the run's external
/// input endpoint) and the external output endpoint on the last stage.
pub(crate) fn segment_paths_are_the_tree_depth(seg: &super::wire::Segment, sh: &Shape) -> Result<(), String> {
    let bp = super::protocol::pcs_params_at(sh);
    let ep = super::protocol::endpoint_pcs_params(sh);
    paths_are_the_tree_depth("A", &bp, &seg.a_open)?;
    paths_are_the_tree_depth("H", &bp, &seg.h_open)?;
    mask_paths_are_the_tree_depth(&seg.mask_open)?;
    paths_are_the_tree_depth("incoming boundary or endpoint", &ep, &seg.in_open)?;
    if let Some(o) = &seg.out_open {
        paths_are_the_tree_depth("run output endpoint", &ep, o)?;
    }
    Ok(())
}

#[cfg(test)]
#[path = "hash_domain_tests.rs"]
mod tests;
