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
    let mut terms: Vec<usize> = (0..super::layout::N_SLOTS)
        .map(|s| FP2 * (a_sites[s] + h_sites[s] + usize::from(s >= super::layout::SC_IO_IN)))
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
