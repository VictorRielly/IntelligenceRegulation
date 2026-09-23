//! **STAGE 45: THE STANDALONE SHAPED BLOCK CAPTURE — the verifier's view of
//! ONE private block receipt at a shaped profile.**
//!
//! Obligation 3 of `ZK60_SHAPED_PRIVACY_PATH_STATUS.md` (2026-09-23): every
//! privacy-gate measurement at the 125M shape so far is of a TWO-BLOCK RUN,
//! captured by `run_capture.rs`. A standalone block receipt at a shaped
//! profile has never been captured, and its transcript is not a run stage's:
//! it opens with the BLOCK's own header (`parameters` is the block profile's
//! line, `public-statement` is the block's digest, no `run-shape` word), it
//! has no stage words and no boundary, and it opens BOTH external endpoints
//! in one proof. The integrator's writer (`native_capture.rs`, schema 3) is
//! toy-only and is not touched.
//!
//! **A capture is not a gate and not a result.** Nothing here establishes a
//! privacy property; a bundle is the INPUT to the Python joint-view gate.
//!
//! **WHAT IS IN A BUNDLE: THE VERIFIER'S VIEW AND NOTHING ELSE.** The same
//! rule as the run capture (a retained capture counts as publishing): the
//! public statement, every committed root, every challenge, every claim, the
//! opened columns with their published salts and paths, the masked sumcheck
//! transcripts — and a field outside [`allowed_keys`] fails the allow-list
//! test. No witness value, pad, mask coefficient, unopened column,
//! unpublished salt or unmasked round is in any file this module writes.
//!
//! **HOW IT IS TAKEN: by OBSERVING THE VERIFIER, hooked exactly as
//! `run_capture` is.** The hooks in `protocol.rs` (`verify_inner_at`,
//! `verify_core`) and `argument.rs` are compiled only under `cfg(test)`,
//! return on their first line unless a recorder is attached (`checkpoint`
//! hands back `None`, every other hook finds no recorder), are handed only
//! what the verifier already holds, and return nothing — so no branch of the
//! protocol can depend on whether a recorder is attached, and a build without
//! `cfg(test)` compiles none of them.
//!
//! **THE RECORDER REPLAYS INDEPENDENTLY.** It keeps its OWN transcript,
//! rebuilt from the block's public words in the order `protocol::transcript`
//! absorbs them — never adopted from the verifier — and re-derives every
//! challenge from the recorded roots, claims and openings, comparing its
//! state with the verifier's at every site. It re-runs `zk::mask_verify` and
//! `pcs::verify_zk` on its own transcript. The first mismatch refuses the
//! capture, and **no bundle is taken for a block the verifier did not
//! accept** (`take` refuses unless `block_accepted` ran).
//!
//! **THE FIELD SET IS THE RUN CAPTURE'S.** The per-proof file carries a run
//! stage file's field names for the same objects (the twenty-three slot
//! objects, the `M` opening, the four role objects, the transcript sites),
//! written by the same encoders — the schema `/5-run`'s array store
//! (`{"array":…}` into `arrays.bin`, eight bytes an `Fp`, sixteen an `Fp2`)
//! and its public-table rule — so the Python gate's stage readers apply as
//! they are. The encoders are COPIED from `run_capture.rs` rather than
//! shared, so that no byte of that file (a source pin of every run bundle)
//! moves; `block_capture_shaped_tests` asserts the key sequences agree with
//! a real run capture's, object by object.

use super::argument::{Acc, Coord, Side, SlotDef, SlotProof, Tab};
use super::layout::{Layout, N_SLOTS, SC_IO_IN, SC_IO_OUT, SLOT_KINDS, SLOT_NAMES};
use super::plane_index::{self, PlaneIndex, Ref};
use super::shape::Shape;
use super::{BlockPublic, ExpectedIo, Receipt};
use crate::field::{Fp, Fp2};
use crate::merkle::Digest;
use crate::mle::eq_table_msb;
use crate::ntt::NttTables;
use crate::pcs::{self, Commitment, OpeningZk, PcsParams, ZClaim, ZPart, ZkOpts};
use crate::sumcheck;
use crate::transcript::Transcript;
use crate::zk::{MaskFunctional, MaskOpening};
use std::cell::RefCell;
use std::io::Write;

/// The schema this module writes: a standalone block at a SHAPED profile, in
/// the `/5-run` array encoding. A loader that knows only `3`, `/4-run` or
/// `/5-run` refuses it by version, which is the intent: a block is not a
/// stage and must not be read as one.
pub(super) const SCHEMA: &str = "hashline-native-capture/5-block-shaped";

/// The array-store threshold, the run capture's own (`run_capture::ARRAY_MIN`).
pub(super) const ARRAY_MIN: usize = super::run_capture::ARRAY_MIN;

/// The files of a bundle, in the order the manifest lists them.
pub(super) const BLOCK_FILE: &str = "block.json";
pub(super) const OBSERVATIONS_FILE: &str = "observations.json";
pub(super) const ARRAYS_FILE: &str = "arrays.bin";
pub(super) const RECEIPT_FILE: &str = "receipt.bin";
pub(super) const EXPECTED_FILE: &str = "expected.bin";

/// The four roles a standalone block opens after `M`, in transcript order.
pub(super) const ROLE_ORDER: [&str; 4] = ["A", "H", "Input", "Output"];

/// **Every `private_block` file on the STANDALONE BLOCK's path**, whose bytes
/// decide what a bundle contains: this writer, the block prover and verifier
/// (`protocol.rs`, `argument.rs`), the layout and its plane index, the shape,
/// the frame, the generalised endpoint, the T-3 / T-4 guards, the parent
/// module (`ExpectedIo`, `IoSpec`, `Receipt`, `verify_bytes_at`), and the
/// witness builder and pad rule behind every value a verifier observes.
/// The run-only files are in [`NOT_ON_THE_BLOCKS_PATH`], each with its reason.
pub(super) const OWN_SOURCE_FILES: [&str; 12] = [
    "src/private_block/block_capture_shaped.rs",
    "src/private_block/protocol.rs",
    "src/private_block/argument.rs",
    "src/private_block/layout.rs",
    "src/private_block/plane_index.rs",
    "src/private_block/shape.rs",
    "src/private_block/wire.rs",
    "src/private_block/endpoint_g.rs",
    "src/private_block/hash_domain.rs",
    "src/private_block.rs",
    "src/private_block/witness.rs",
    "src/private_block/pad.rs",
];

/// **The production modules of `private_block` that a standalone block's
/// verifier never reaches**, with the reason. [`OWN_SOURCE_FILES`]'
/// production entries plus this list is the whole production module list,
/// and a test asserts that partition.
pub(super) const NOT_ON_THE_BLOCKS_PATH: [(&str, &str); 4] = [
    ("src/private_block/run.rs", "the run prover and verifier: `protocol::verify_inner_at` never reaches it, and a standalone block has no run header, no stage words and no segment"),
    ("src/private_block/boundary.rs", "an internal boundary exists only between two blocks of a run"),
    ("src/private_block/run_sink.rs", "segment files exist only in a run"),
    ("src/private_block/timing.rs", "the phase clock: WRITE-ONLY on the block's path (`protocol.rs:13-16`), every call returns on its first line unless HL_PB_TIMING is set, and it decides no byte of a receipt or of a bundle"),
];

/// Every file a bundle pins: the block's own path, then the shared files the
/// run capture pins (`run_capture::SHARED_SOURCE_FILES`, the `use` graph of
/// the transcript, the commitments and the openings down into `zkp-core`),
/// which the block reaches through exactly the same modules.
pub(super) fn source_files() -> Vec<&'static str> {
    OWN_SOURCE_FILES.iter().copied().chain(super::run_capture::SHARED_SOURCE_FILES.iter().copied()).collect()
}

/// SHA-256 of every source file that decides what a bundle contains.
pub(super) fn source_pins() -> Result<Vec<(String, String)>, String> {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    let mut out = Vec::new();
    for name in source_files() {
        let path = root.join(name);
        let bytes = std::fs::read(&path).map_err(|e| format!("block capture: source pin {}: {e}", path.display()))?;
        out.push((name.to_string(), crate::export_v3::sha256_hex(&bytes)));
    }
    Ok(out)
}

// ---------------------------------------------------------------- the array side store

/// The `/5-run` side store, copied: a field-element array of at least
/// [`ARRAY_MIN`] entries goes to `arrays.bin` little-endian and is written in
/// the JSON as `{"array":"<sha256>","elem":"fp"|"fp2","len":N,"offset":O,"bytes":B}`;
/// identical arrays are stored once. Held in memory until the block is
/// accepted, so nothing reaches the disk before `take` has succeeded.
pub(super) struct Store {
    blob: Vec<u8>,
    index: std::collections::HashMap<String, (usize, usize)>,
    stored: usize,
    deduped: usize,
    inline: usize,
}

impl Store {
    fn new() -> Store {
        Store { blob: Vec::new(), index: std::collections::HashMap::new(), stored: 0, deduped: 0, inline: 0 }
    }
    pub(super) fn blob(&self) -> &[u8] {
        &self.blob
    }
    /// `(distinct arrays, arrays written, arrays deduplicated, arrays left inline, blob bytes)`
    pub(super) fn stats(&self) -> (usize, usize, usize, usize, usize) {
        (self.index.len(), self.stored, self.deduped, self.inline, self.blob.len())
    }
    fn put(&mut self, out: &mut Vec<u8>, elem: &str, len: usize, bytes: &[u8]) {
        let sha = crate::export_v3::sha256_hex(bytes);
        self.stored += 1;
        let (offset, n) = match self.index.get(&sha) {
            Some(&at) => {
                self.deduped += 1;
                at
            }
            None => {
                let at = (self.blob.len(), bytes.len());
                self.blob.extend_from_slice(bytes);
                self.index.insert(sha.clone(), at);
                at
            }
        };
        write!(out, "{{\"array\":{sha:?},\"elem\":{elem:?},\"len\":{len},\"offset\":{offset},\"bytes\":{n}}}").expect("write to a Vec");
    }
}

fn fp_array(out: &mut Vec<u8>, st: &mut Store, v: &[Fp]) {
    if v.len() >= ARRAY_MIN {
        let mut bytes = Vec::with_capacity(v.len() * 8);
        for x in v {
            bytes.extend_from_slice(&x.to_bytes());
        }
        st.put(out, "fp", v.len(), &bytes);
    } else {
        st.inline += 1;
        write!(out, "{:?}", v.iter().map(|x| x.0).collect::<Vec<_>>()).expect("write to a Vec");
    }
}

fn fp2_array(out: &mut Vec<u8>, st: &mut Store, v: &[Fp2]) {
    if v.len() >= ARRAY_MIN {
        let mut bytes = Vec::with_capacity(v.len() * 16);
        for x in v {
            bytes.extend_from_slice(&x.to_bytes());
        }
        st.put(out, "fp2", v.len(), &bytes);
    } else {
        st.inline += 1;
        write!(out, "{:?}", fp2s(v)).expect("write to a Vec");
    }
}

// ---------------------------------------------------------------- the recorder

/// The block's public words and the prefix every later site is read against,
/// recorded by [`begin_block`] from what the verifier holds.
struct Head {
    sh: Shape,
    binding: Digest,
    expected_bytes: Vec<u8>,
    public_statement: Digest,
    parameter_line: String,
    calibration: Digest,
    schedule_digest: Digest,
    layout_description: Vec<String>,
    context: Digest,
    input_root: Digest,
    output_root: Digest,
    scales: (i32, i32),
    /// the external endpoints' `(rows, data rows, proximity row)`
    endpoint: (usize, usize, usize),
    a_root: Digest,
    a_rows: usize,
    h_root: Digest,
    h_rows: usize,
    mask_root: Digest,
    logup: Vec<Fp2>,
    /// the verifier's transcript right after the header (`block_binding`)
    header: Transcript,
}

struct Rec {
    public_tables: bool,
    head: Option<Head>,
    /// the recorder's OWN transcript, rebuilt from the header's public words
    /// and advanced only by replaying the verifier's steps on recorded data
    /// (a placeholder until [`begin_block`] rebuilds it)
    own: Transcript,
    definition: Option<Transcript>,
    arguments: Vec<Vec<u8>>,
    mask: Option<Vec<u8>>,
    roles: Vec<Vec<u8>>,
    role_names: Vec<&'static str>,
    sites: Vec<Vec<u8>>,
    index: Option<PlaneIndex>,
    index_json: Vec<u8>,
    store: Store,
    /// the canonical frame's `(length, SHA-256)`, set only by an accepted block
    accepted: Option<(usize, String)>,
    failure: Option<String>,
}

thread_local! {
    static REC: RefCell<Option<Rec>> = const { RefCell::new(None) };
}

/// The attached recorder: ONE block verification. Dropping it detaches, on
/// every path, so a rejected verification never leaves a partial capture.
pub(super) struct Recorder;

impl Recorder {
    /// Attach a recorder for ONE standalone block verification. `public_tables`
    /// says whether a slot's public table carries its VALUES (always its
    /// length and SHA-256). Panics if one is already attached.
    pub(super) fn attach(public_tables: bool) -> Recorder {
        REC.with(|s| {
            let mut cell = s.borrow_mut();
            assert!(cell.is_none(), "a block recorder is already attached");
            *cell = Some(Rec {
                public_tables,
                head: None,
                own: Transcript::new(b"stage 45: no block has begun under this recorder"),
                definition: None,
                arguments: Vec::new(),
                mask: None,
                roles: Vec::new(),
                role_names: Vec::new(),
                sites: Vec::new(),
                index: None,
                index_json: Vec::new(),
                store: Store::new(),
                accepted: None,
                failure: None,
            });
        });
        Recorder
    }
}

impl Drop for Recorder {
    fn drop(&mut self) {
        REC.with(|s| *s.borrow_mut() = None);
    }
}

fn with<R>(f: impl FnOnce(&mut Rec) -> R) -> Option<R> {
    REC.with(|s| s.borrow_mut().as_mut().map(f))
}

fn fail(r: &mut Rec, what: String) {
    if r.failure.is_none() {
        r.failure = Some(what);
    }
}

fn same_transcript(a: &Transcript, b: &Transcript) -> bool {
    a.state() == b.state() && Transcript::clone_state(a).challenge_fp2() == Transcript::clone_state(b).challenge_fp2()
}

/// The recorder's own transcript must be exactly where the verifier's is.
fn at(r: &mut Rec, site: &str, tr: &Transcript) {
    if r.failure.is_none() && !same_transcript(&r.own, tr) {
        fail(r, format!("replay: the recorder's transcript is not the verifier's at {site}"));
    }
}

/// Every hook after the header needs one; a site offered before it is a
/// capture that never started.
fn begun(r: &mut Rec, site: &str) -> bool {
    if r.failure.is_some() {
        return false;
    }
    if r.head.is_none() {
        fail(r, format!("replay: {site} was offered before the block header"));
        return false;
    }
    true
}

// ---------------------------------------------------------------- hooks

pub(super) fn active() -> bool {
    REC.with(|s| s.borrow().is_some())
}

/// A checkpoint of the verifier's transcript, taken only when a recorder is
/// attached. Handing back `None` is what makes every hook a no-op.
pub(super) fn checkpoint(tr: &Transcript) -> Option<Transcript> {
    REC.with(|s| s.borrow().is_some().then(|| Transcript::clone_state(tr)))
}

/// **THE BLOCK HEADER, REBUILT INDEPENDENTLY**, at `verify_inner_at`'s header.
/// The recorder's own transcript is built from the block's public words in
/// the order `protocol::transcript` absorbs them and compared with the
/// verifier's; then the prefix `verify_core` absorbs before the first slot —
/// the `A` root, the `M` root, the three LogUp challenges, the `H` root — is
/// replayed from the receipt's roots, so the first slot's checkpoint is the
/// first comparison of the replay proper.
pub(super) fn begin_block(sh: &Shape, lay: &Layout, blk: &BlockPublic, expected: &ExpectedIo, receipt: &Receipt, tr: &Transcript) {
    with(|r| {
        if r.head.is_some() {
            fail(r, "replay: a second block verification under one recorder".into());
            return;
        }
        let expected_bytes = expected.to_bytes();
        let public_statement = blk.digest();
        let parameter_line = super::protocol::parameter_line(sh);
        let calibration = super::calibration_identity();
        let schedule_digest = lay.schedule_digest();
        let mut own = super::protocol::tagged_transcript(sh, sh.profile.as_bytes());
        own.absorb(b"expected-IO", &expected_bytes);
        own.absorb(b"public-statement", &public_statement);
        own.absorb(b"parameters", parameter_line.as_bytes());
        own.absorb(b"calibration", &calibration);
        own.absorb(b"schedule", &schedule_digest);
        let binding = own.state();
        r.own = own;
        at(r, "the block header", tr);
        let endpoint = match super::protocol::endpoint_geometry(sh) {
            Ok(g) => g,
            Err(e) => {
                fail(r, format!("replay: the endpoint geometry: {e}"));
                return;
            }
        };
        // **The plane index table**, built from the verifier's own layout;
        // every slot's private tables are checked against it as they arrive.
        match plane_index::build(lay) {
            Ok(idx) => {
                r.index_json = idx.render();
                r.index = Some(idx);
            }
            Err(e) => {
                fail(r, format!("replay: the plane index does not build: {e}"));
                return;
            }
        }
        // the prefix, replayed: A, M, the three LogUp challenges, H
        r.own.absorb(b"A", &receipt.a_root);
        r.own.absorb_u64(b"rows", lay.a_rows as u64);
        r.own.absorb_u64(b"log-cols", sh.log_cols as u64);
        r.own.absorb(b"M", &receipt.mask_root);
        let logup = r.own.challenge_fp2_vec(3);
        r.own.absorb(b"H", &receipt.h_root);
        r.own.absorb_u64(b"rows", lay.h_rows as u64);
        r.own.absorb_u64(b"log-cols", sh.log_cols as u64);
        r.head = Some(Head {
            sh: sh.clone(),
            binding,
            expected_bytes,
            public_statement,
            parameter_line,
            calibration,
            schedule_digest,
            layout_description: lay.describe(),
            context: expected.spec.context,
            input_root: expected.input,
            output_root: expected.output,
            scales: (expected.spec.input_scale(), expected.spec.output_scale()),
            endpoint,
            a_root: receipt.a_root,
            a_rows: lay.a_rows,
            h_root: receipt.h_root,
            h_rows: lay.h_rows,
            mask_root: receipt.mask_root,
            logup,
            header: Transcript::clone_state(tr),
        });
    });
}

/// The transcript before a slot's DEFINITION draws its challenges.
pub(super) fn start_slot(side: &Side, tr: &Transcript) {
    if !matches!(side, Side::Verify { .. }) {
        return;
    }
    with(|r| {
        if r.head.is_some() {
            r.definition = Some(Transcript::clone_state(tr));
        }
    });
}

/// One slot's masked sumcheck, exactly as the run capture records it, at
/// this block's shape.
#[allow(clippy::too_many_arguments)]
pub(super) fn slot(def: &SlotDef, acc: &Acc, proof: &SlotProof, rho: &[Fp2], c: Fp2, mask_eval: Fp2, before: Option<Transcript>, after: &Transcript) {
    let Some(before) = before else { return };
    with(|r| {
        let s = def.slot;
        if !begun(r, &format!("slot {s}")) {
            return;
        }
        if s != r.arguments.len() {
            fail(r, format!("replay: slot {s} arrived out of order"));
            return;
        }
        let Some(definition) = r.definition.take() else {
            fail(r, format!("replay: slot {s} has no definition checkpoint"));
            return;
        };
        at(r, &format!("slot {s}'s definition"), &definition);
        if r.failure.is_some() {
            return;
        }
        // The definition code only DRAWS Fp2 challenges; replay to its exact
        // endpoint. A definition that ever absorbed would run away and be
        // refused here rather than mis-recorded.
        let mut draws = Vec::new();
        while !same_transcript(&r.own, &before) {
            if draws.len() >= 256 {
                fail(r, format!("replay: slot {s}'s definition changed its transcript operations"));
                return;
            }
            draws.push(r.own.challenge_fp2());
        }
        let (n, ext, degree) = def.sh.slots()[s];
        r.own.absorb_u64(b"pb-slot", s as u64);
        let c_own = r.own.challenge_fp2();
        if c_own != c {
            fail(r, format!("replay: slot {s}'s CFS challenge is not the verifier's"));
            return;
        }
        r.own.absorb_fp2(b"pb-scalar", &[proof.scalar]);
        let claimed = def.hosted.iter().fold(proof.scalar, |v, (hs, coef)| v.add(coef.mul(acc.scalars[*hs])));
        let (fin, replay_rho) = match sumcheck::verify(claimed, degree, n + ext, &proof.sc, &mut r.own) {
            Ok(v) => v,
            Err(e) => {
                fail(r, format!("replay: slot {s}'s sumcheck does not replay: {e}"));
                return;
            }
        };
        if replay_rho != rho {
            fail(r, format!("replay: slot {s}'s sumcheck challenges are not the verifier's"));
            return;
        }
        r.own.absorb_fp2(b"pb-term", &proof.terms);
        at(r, &format!("the end of slot {s}"), after);
        if r.failure.is_some() {
            return;
        }
        // THE PLANE INDEX TABLE, TIED TO THIS SLOT (the run capture's stage-15
        // check): the slot's private tables in push order, located by role
        // and slice offset, against the table's independent derivation.
        let order_error = match r.index.as_ref() {
            None => Some(format!("replay: slot {s} arrived before the plane index was built")),
            Some(idx) => {
                let mut observed: Vec<Ref> = Vec::new();
                let mut bad: Option<String> = None;
                for t in &def.tabs {
                    if let Tab::Priv(p) = t {
                        let off = p.slices.first().map(|(o, _)| *o).unwrap_or(usize::MAX);
                        match idx.locate(p.cm as usize, off) {
                            Some(pr) => observed.push(pr),
                            None => {
                                bad.get_or_insert(format!("replay: slot {s} reads role {} at offset {off}, which is on no plane of the index", p.cm as usize));
                            }
                        }
                    }
                }
                let declared = idx.slots.get(s);
                bad.or_else(|| (declared != Some(&observed)).then(|| format!("replay: slot {s}'s private tables are not the plane index's push order")))
            }
        };
        if let Some(e) = order_error {
            fail(r, e);
            return;
        }
        let mut out = Vec::new();
        write!(
            out,
            "{{\"slot\":{s},\"name\":{:?},\"kind\":\"{:?}\",\"main\":{n},\"extension\":{ext},\"degree\":{degree},\"definition_challenges\":{:?},\"c\":{:?},\"scalar\":{:?},\"claimed_sum\":{:?},\"rho\":{:?},\"sumcheck_final\":{:?},\"mask_eval\":{:?},\"terminal_polynomial\":{:?},\"terminals\":{:?},\"rounds\":{:?},\"hosted\":[",
            SLOT_NAMES[s],
            SLOT_KINDS[s],
            fp2s(&draws),
            fp2(c),
            fp2(proof.scalar),
            fp2(claimed),
            fp2s(rho),
            fp2(fin),
            fp2(mask_eval),
            fp2(fin.sub(c.mul(mask_eval))),
            fp2s(&proof.terms),
            proof.sc.rounds.iter().map(|x| fp2s(x)).collect::<Vec<_>>()
        )
        .expect("write to a Vec");
        for (i, (hs, coefficient)) in def.hosted.iter().enumerate() {
            if i > 0 {
                write!(out, ",").expect("write to a Vec");
            }
            write!(out, "{{\"slot\":{hs},\"coefficient\":{:?}}}", fp2(*coefficient)).expect("write to a Vec");
        }
        write!(out, "],\"tables\":[").expect("write to a Vec");
        let public_tables = r.public_tables;
        let mut counts = [0usize; 4];
        for t in &def.tabs {
            if let Tab::Priv(v) = t {
                counts[v.cm as usize] += 1;
            }
        }
        let mut indices = std::array::from_fn::<_, 4, _>(|i| acc.claims[i].len() - counts[i]);
        for (i, table) in def.tabs.iter().enumerate() {
            if i > 0 {
                write!(out, ",").expect("write to a Vec");
            }
            match table {
                Tab::Eq { point, start } => write!(out, "{{\"kind\":\"eq\",\"start\":{start},\"point\":{:?}}}", fp2s(point)).expect("write to a Vec"),
                Tab::Pub(v) => write_public_table(&mut out, &mut r.store, v, public_tables),
                Tab::Priv(v) => {
                    let role = ROLE_ORDER[v.cm as usize];
                    let ci = &mut indices[v.cm as usize];
                    write!(out, "{{\"kind\":\"private\",\"role\":{role:?},\"claim\":{ci},\"log_size\":{},\"mask_row\":{},\"extension_round\":{},\"slices\":[", v.log, v.mask_row, v.ext_round).expect("write to a Vec");
                    *ci += 1;
                    for (j, (offset, coefficient)) in v.slices.iter().enumerate() {
                        if j > 0 {
                            write!(out, ",").expect("write to a Vec");
                        }
                        write!(out, "{{\"offset\":{offset},\"coefficient\":{:?}}}", fp2(*coefficient)).expect("write to a Vec");
                    }
                    write!(out, "],\"coordinates\":[").expect("write to a Vec");
                    for (j, coord) in v.coords.iter().enumerate() {
                        if j > 0 {
                            write!(out, ",").expect("write to a Vec");
                        }
                        match coord {
                            Coord::Rho(k) => write!(out, "{{\"rho\":{k}}}").expect("write to a Vec"),
                            Coord::Flip(k) => write!(out, "{{\"flip\":{k}}}").expect("write to a Vec"),
                            Coord::Fixed(x) => write!(out, "{{\"fixed\":{:?}}}", fp2(*x)).expect("write to a Vec"),
                        }
                    }
                    write!(out, "]}}").expect("write to a Vec");
                }
            }
        }
        write!(out, "],").expect("write to a Vec");
        state(&mut out, "before_definition", &definition);
        write!(out, ",").expect("write to a Vec");
        state(&mut out, "before", &before);
        write!(out, ",").expect("write to a Vec");
        state(&mut out, "after", after);
        write!(out, "}}").expect("write to a Vec");
        site(r, &format!("slot {s:02}"), &definition, after);
        r.arguments.push(out);
    });
}

/// The masking commitment's ONE opening.
pub(super) fn mask(specs: &[(usize, usize)], root: &Digest, fs: &[MaskFunctional], op: &MaskOpening, ntt: &NttTables, before: Option<Transcript>, after: &Transcript) {
    let Some(before) = before else { return };
    with(|r| {
        if !begun(r, "the M opening") {
            return;
        }
        at(r, "the M opening", &before);
        if r.failure.is_some() {
            return;
        }
        let theta = Transcript::clone_state(&r.own).challenge_fp2();
        let rhos = {
            let mut t = Transcript::clone_state(&r.own);
            let _ = t.challenge_fp2();
            t.absorb_fp2(b"mask-q", &op.q);
            t.challenge_fp2_vec(2 * specs.len() + 2)
        };
        let tag = r.head.as_ref().expect("begun").sh.hash_tag();
        if let Err(e) = crate::zk::mask_verify_tagged(root, specs, fs, op, ntt, &mut r.own, &tag) {
            fail(r, format!("replay: the M opening does not replay: {e}"));
            return;
        }
        at(r, "the end of the M opening", after);
        if r.failure.is_some() {
            return;
        }
        let mut out = Vec::new();
        write!(out, "{{\"root\":{root:?},\"specs\":{:?},\"rows\":{},\"theta\":{:?},\"proximity_rhos\":{:?},", specs.iter().map(|&(n, d)| [n, d]).collect::<Vec<_>>(), 2 * specs.len() + 4, fp2(theta), fp2s(&rhos)).expect("write to a Vec");
        state(&mut out, "before", &before);
        write!(out, ",").expect("write to a Vec");
        state(&mut out, "after", after);
        write!(out, ",\"functionals\":[").expect("write to a Vec");
        for (i, f) in fs.iter().enumerate() {
            if i > 0 {
                write!(out, ",").expect("write to a Vec");
            }
            write!(out, "{{\"value\":{:?},\"terms\":[", fp2(f.value)).expect("write to a Vec");
            for (j, (s, weights)) in f.terms.iter().enumerate() {
                if j > 0 {
                    write!(out, ",").expect("write to a Vec");
                }
                write!(out, "{{\"slot\":{s},\"weights\":{:?}}}", fp2s(weights)).expect("write to a Vec");
            }
            write!(out, "]}}").expect("write to a Vec");
        }
        write!(out, "],\"q\":").expect("write to a Vec");
        fp2_array(&mut out, &mut r.store, &op.q);
        write!(out, ",\"prox\":").expect("write to a Vec");
        fp2_array(&mut out, &mut r.store, &op.prox);
        write!(out, ",\"columns\":").expect("write to a Vec");
        columns(&mut out, &mut r.store, &op.columns);
        write!(out, "}}").expect("write to a Vec");
        site(r, "M opening", &before, after);
        if r.mask.replace(out).is_some() {
            fail(r, "replay: two M openings in one block".into());
        }
    });
}

/// What an opening's row geometry is: the run capture's `Geom`, with the
/// fields a standalone block needs. Nothing here is read from a frame.
struct Geom {
    role: &'static str,
    commitment_kind: &'static str,
    params: PcsParams,
    root: Digest,
    rows: usize,
    data_rows: usize,
    site_rows: Vec<usize>,
    sum_rows: Option<[usize; 2]>,
    prox_row: usize,
    /// `(slot, how many claims)`, in claim order
    claim_sources: Vec<(usize, usize)>,
}

/// The `A` or `H` opening of `verify_core`. The geometry is the verifier's
/// OWN layout's; `role` is `"A"` or `"H"` and nothing else.
#[allow(clippy::too_many_arguments)]
pub(super) fn block_pcs(role: &'static str, lay: &Layout, root: Digest, claims: &[ZClaim], opening: &OpeningZk, ntt: &NttTables, before: Option<Transcript>, after: &Transcript) {
    let Some(before) = before else { return };
    let params = super::protocol::pcs_params_at(lay.shape());
    let g = match role {
        "A" => Geom { role, commitment_kind: "block", params, root, rows: lay.a_rows, data_rows: lay.a_data_rows, site_rows: lay.a_site_rows(), sum_rows: None, prox_row: lay.a_prox, claim_sources: vec![] },
        "H" => Geom { role, commitment_kind: "block", params, root, rows: lay.h_rows, data_rows: lay.h_data_rows, site_rows: lay.h_site_rows(), sum_rows: Some(lay.h_u_rows()), prox_row: lay.h_prox, claim_sources: vec![] },
        other => {
            with(|r| fail(r, format!("replay: a block opening was offered under the role {other:?}")));
            return;
        }
    };
    record_pcs(g, claims, opening, ntt, before, after);
}

/// One of the block's two EXTERNAL endpoint openings (`i` = 0 the input,
/// 1 the output), at the shape's endpoint geometry. In a standalone block
/// the input endpoint's claims come from slot 21 alone and the output
/// endpoint's from slot 22 alone.
#[allow(clippy::too_many_arguments)]
pub(super) fn endpoint_pcs(i: usize, sh: &Shape, root: Digest, claims: &[ZClaim], opening: &OpeningZk, ntt: &NttTables, before: Option<Transcript>, after: &Transcript) {
    let Some(before) = before else { return };
    let geometry = with(|r| r.head.as_ref().map(|h| h.endpoint)).flatten();
    let Some((rows, data, prox)) = geometry else {
        with(|r| fail(r, "replay: an endpoint opening was offered before the block header".into()));
        return;
    };
    let (role, slot) = match i {
        0 => ("Input", SC_IO_IN),
        1 => ("Output", SC_IO_OUT),
        _ => {
            with(|r| fail(r, format!("replay: endpoint {i} does not exist")));
            return;
        }
    };
    let g = Geom {
        role,
        commitment_kind: "external-endpoint",
        params: super::protocol::endpoint_pcs_params(sh),
        root,
        rows,
        data_rows: data,
        site_rows: vec![data, data + 1],
        sum_rows: None,
        prox_row: prox,
        claim_sources: vec![(slot, claims.len())],
    };
    record_pcs(g, claims, opening, ntt, before, after);
}

fn record_pcs(g: Geom, claims: &[ZClaim], opening: &OpeningZk, ntt: &NttTables, before: Transcript, after: &Transcript) {
    with(|r| {
        if !begun(r, &format!("the {} opening", g.role)) {
            return;
        }
        let want = ROLE_ORDER.get(r.roles.len()).copied();
        if want != Some(g.role) {
            fail(r, format!("replay: the {} opening arrived where {want:?} was due", g.role));
            return;
        }
        at(r, &format!("the {} opening", g.role), &before);
        if r.failure.is_some() {
            return;
        }
        let cm = Commitment { root: g.root, rows: g.rows, log_cols: g.params.log_cols };
        let replayed = match replay(&g.params, &cm, claims, opening, &before) {
            Ok(v) => v,
            Err(e) => {
                fail(r, format!("replay: the {} opening does not replay: {e}", g.role));
                return;
            }
        };
        let tag = r.head.as_ref().expect("begun").sh.hash_tag();
        if let Err(e) = pcs::verify_zk_tagged(&g.params, &ZkOpts::standard(&g.params), &cm, claims, opening, ntt, &mut r.own, &tag) {
            fail(r, format!("replay: the {} opening does not verify on the recorder's transcript: {e}", g.role));
            return;
        }
        at(r, &format!("the end of the {} opening", g.role), after);
        if r.failure.is_some() {
            return;
        }
        let mut out = Vec::new();
        write_pcs(&mut out, &mut r.store, &g, claims, opening, &replayed, &before, after);
        site(r, &format!("{} opening", g.role), &before, after);
        r.roles.push(out);
        r.role_names.push(g.role);
    });
}

/// The verifier ACCEPTED: `verify_inner_at` reached its last line. The
/// recorder's transcript must be the verifier's final one, every slot, the
/// `M` opening and the four roles must be there, and the receipt is
/// re-encoded to its canonical frame for `proof_bytes` / `proof_sha256`
/// (as the toy capture's `publish` does). Only after this can a bundle be
/// taken.
pub(super) fn block_accepted(sh: &Shape, blk: &BlockPublic, expected: &ExpectedIo, receipt: &Receipt, tr: &Transcript) {
    with(|r| {
        if !begun(r, "the block's acceptance") {
            return;
        }
        at(r, "the end of the block", tr);
        if r.failure.is_some() {
            return;
        }
        if r.arguments.len() != N_SLOTS || r.mask.is_none() || r.role_names != ROLE_ORDER {
            fail(r, format!("replay: the block closed with {} slots, {} M openings and the roles {:?}", r.arguments.len(), usize::from(r.mask.is_some()), r.role_names));
            return;
        }
        match receipt.to_bytes_at(sh, blk, expected) {
            Ok(bytes) => r.accepted = Some((bytes.len(), crate::export_v3::sha256_hex(&bytes))),
            Err(e) => fail(r, format!("replay: the accepted receipt does not re-encode: {e}")),
        }
    });
}

// ---------------------------------------------------------------- taking a bundle

/// A finished capture: the two JSON files and the array store. Taking one
/// REQUIRES an accepted block and no replay failure.
pub(super) struct Bundle {
    pub block_json: Vec<u8>,
    pub observations: Vec<u8>,
    pub arrays: Store,
    pub profile: String,
    pub proof_bytes: usize,
    pub proof_sha256: String,
    pub binding: Digest,
}

/// Take the bundle, labelled with the commit it was taken at. The label is
/// an argument, never read from the environment here, so that a fresh
/// process re-verifying a saved receipt re-renders it byte for byte under
/// the label the bundle already carries.
pub(super) fn take(source_commit: &str) -> Result<Bundle, String> {
    let r = REC.with(|s| s.borrow_mut().take());
    let mut r = r.ok_or("block capture: no recorder is attached")?;
    if let Some(e) = r.failure.take() {
        return Err(e);
    }
    let Some((proof_bytes, proof_sha256)) = r.accepted.clone() else {
        return Err("block capture: the verifier did not accept the block; no bundle is taken for a block the verifier did not accept".into());
    };
    if r.index.is_none() || r.index_json.is_empty() {
        return Err("block capture: no plane index table was built; no bundle is taken without one".into());
    }
    if !source_commit.bytes().all(|b| b.is_ascii_graphic()) || source_commit.is_empty() {
        return Err(format!("block capture: the source label {source_commit:?} is not printable ASCII"));
    }
    let head = r.head.as_ref().expect("an accepted block has a header");
    let block_json = write_block(&r, head, source_commit, proof_bytes, &proof_sha256);
    let observations = write_observations(&r, head, proof_bytes, &proof_sha256);
    let profile = head.sh.profile.to_string();
    let binding = head.binding;
    Ok(Bundle { block_json, observations, arrays: r.store, profile, proof_bytes, proof_sha256, binding })
}

// ---------------------------------------------------------------- JSON writers

fn fp2(v: Fp2) -> [u64; 2] {
    [v.c0.0, v.c1.0]
}

fn fp2s(v: &[Fp2]) -> Vec<[u64; 2]> {
    v.iter().copied().map(fp2).collect()
}

fn state(out: &mut Vec<u8>, name: &str, tr: &Transcript) {
    write!(out, "{name:?}:{{\"state\":{:?},\"next\":{:?}}}", tr.state(), fp2(Transcript::clone_state(tr).challenge_fp2())).expect("write to a Vec");
}

/// One entry of the block's transcript order: where the verifier was, what
/// it was doing, and the transcript position before and after. A run's site
/// carries its `stage` as well; a standalone block has none.
fn site(r: &mut Rec, name: &str, before: &Transcript, after: &Transcript) {
    let mut out = Vec::new();
    write!(out, "{{\"site\":{name:?},").expect("write to a Vec");
    state(&mut out, "before", before);
    write!(out, ",").expect("write to a Vec");
    state(&mut out, "after", after);
    write!(out, "}}").expect("write to a Vec");
    r.sites.push(out);
}

fn columns(out: &mut Vec<u8>, st: &mut Store, cols: &[(usize, Vec<Fp>, [u8; 32], Vec<[u8; 32]>)]) {
    write!(out, "[").expect("write to a Vec");
    for (i, (index, values, salt, path)) in cols.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{{\"index\":{index},\"values\":").expect("write to a Vec");
        fp_array(out, st, values);
        write!(out, ",\"salt\":{salt:?},\"path\":{path:?}}}").expect("write to a Vec");
    }
    write!(out, "]").expect("write to a Vec");
}

fn array(out: &mut Vec<u8>, records: &[Vec<u8>]) {
    write!(out, "[").expect("write to a Vec");
    for (i, record) in records.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        out.write_all(record).expect("write to a Vec");
    }
    write!(out, "]").expect("write to a Vec");
}

fn strings(out: &mut Vec<u8>, records: &[String]) {
    write!(out, "[").expect("write to a Vec");
    for (i, record) in records.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{record:?}").expect("write to a Vec");
    }
    write!(out, "]").expect("write to a Vec");
}

/// A PUBLIC table of a slot, the run capture's rule: its length and SHA-256
/// always, its values when the recorder was attached with `public_tables`.
fn write_public_table(out: &mut Vec<u8>, st: &mut Store, v: &[Fp2], values: bool) {
    let mut bytes = Vec::with_capacity(v.len() * 16);
    for x in v {
        bytes.extend_from_slice(&x.to_bytes());
    }
    write!(out, "{{\"kind\":\"public\",\"len\":{},\"sha256\":{:?}", v.len(), crate::export_v3::sha256_hex(&bytes)).expect("write to a Vec");
    if values {
        write!(out, ",\"values\":").expect("write to a Vec");
        if v.len() >= ARRAY_MIN {
            st.put(out, "fp2", v.len(), &bytes);
        } else {
            st.inline += 1;
            write!(out, "{:?}", fp2s(v)).expect("write to a Vec");
        }
    }
    write!(out, "}}").expect("write to a Vec");
}

#[allow(clippy::too_many_arguments)]
fn write_pcs(out: &mut Vec<u8>, st: &mut Store, g: &Geom, claims: &[ZClaim], opening: &OpeningZk, r: &Replayed, before: &Transcript, after: &Transcript) {
    write!(
        out,
        "{{\"role\":{:?},\"commitment_kind\":{:?},\"params\":{{\"log_cols\":{},\"inv_rate\":{},\"num_col_checks\":{}}},\"commitment\":{{\"root\":{:?},\"rows\":{}}},\"data_rows\":{},\"site_rows\":{:?},\"prox_row\":{},\"sum_rows\":{},\"boundary\":null,\"claim_sources\":[",
        g.role,
        g.commitment_kind,
        g.params.log_cols,
        g.params.inv_rate,
        g.params.num_col_checks,
        g.root,
        g.rows,
        g.data_rows,
        g.site_rows,
        g.prox_row,
        match g.sum_rows {
            Some([a, b]) => format!("[{a},{b}]"),
            None => "null".into(),
        },
    )
    .expect("write to a Vec");
    // a run's claim source names its stage; a standalone block is stage 0 of
    // nothing, and the field is written as 0 so a run reader indexes it
    for (i, (slot, count)) in g.claim_sources.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{{\"stage\":0,\"slot\":{slot},\"claims\":{count}}}").expect("write to a Vec");
    }
    write!(out, "],").expect("write to a Vec");
    state(out, "before", before);
    write!(out, ",").expect("write to a Vec");
    state(out, "after", after);
    write!(out, ",\"claims\":[").expect("write to a Vec");
    for (i, c) in claims.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{{\"value\":{:?},\"parts\":[", fp2(c.value)).expect("write to a Vec");
        for (j, p) in c.parts.iter().enumerate() {
            if j > 0 {
                write!(out, ",").expect("write to a Vec");
            }
            write!(out, "{{\"offset\":{},\"log_size\":{},\"coefficient\":{:?},\"point\":{:?}}}", p.slice.offset, p.slice.log_size, fp2(p.coef), fp2s(&p.point)).expect("write to a Vec");
        }
        write!(out, "]}}").expect("write to a Vec");
    }
    write!(out, "],\"groups\":[").expect("write to a Vec");
    for (i, group) in r.groups.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{{\"members\":{:?},\"lambdas\":{:?},\"key\":{{\"tail\":{:?},\"offset\":{},\"len\":{}}},\"vector\":", group.members, fp2s(&group.lambdas), fp2s(&group.key.tail), group.key.offset, group.key.len).expect("write to a Vec");
        fp2_array(out, st, &opening.group_vecs[i]);
        write!(out, "}}").expect("write to a Vec");
    }
    write!(out, "],\"proximity_rhos\":").expect("write to a Vec");
    fp2_array(out, st, &r.proximity_rhos);
    write!(out, ",\"proximity_vector\":").expect("write to a Vec");
    fp2_array(out, st, &opening.prox_vec);
    write!(out, ",\"columns\":").expect("write to a Vec");
    columns(out, st, &opening.columns);
    write!(out, ",\"q_pad\":{},\"row_roles\":[", g.params.num_col_checks).expect("write to a Vec");
    for row in 0..g.rows {
        if row > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        let kind = row_kind(g, row);
        let site = format!("{}.{kind}[{row}]", g.role);
        write!(out, "{{\"row\":{row},\"kind\":{kind:?},\"site\":{site:?}}}").expect("write to a Vec");
    }
    write!(out, "],\"public_linear_constraints\":[").expect("write to a Vec");
    if let Some([a, b]) = g.sum_rows {
        write!(out, "{{\"rows\":[{a},{b}],\"relation\":\"sum over the n message columns = 0\",\"source\":\"zsum sumcheck\"}}").expect("write to a Vec");
    }
    write!(out, "]}}").expect("write to a Vec");
}

/// The run capture's row vocabulary: `"data"`, `"mask"` (the reserved claim
/// pairs, `H`'s two zero-sum rows and any spare mask row), `"prox"`.
fn row_kind(g: &Geom, row: usize) -> &'static str {
    if g.sum_rows.map(|[a, b]| row == a || row == b).unwrap_or(false) {
        "mask"
    } else if row < g.data_rows {
        "data"
    } else if row == g.prox_row || row == g.prox_row + 1 {
        "prox"
    } else {
        "mask"
    }
}

/// **The per-proof file**: a run stage file's field names for the same
/// objects, minus the run's framing (`stage`, `blocks`, `segment_*`,
/// `start_tag` / `end_tag`, `boundary_committed`), plus the receipt pin.
fn write_observations(r: &Rec, h: &Head, proof_bytes: usize, proof_sha256: &str) -> Vec<u8> {
    let mut out = Vec::new();
    write!(
        out,
        "{{\"schema\":{SCHEMA:?},\"kind\":\"zk60-block-observations\",\"profile\":{:?},\"proof_bytes\":{proof_bytes},\"proof_sha256\":{proof_sha256:?},\"block_digest\":{:?},\"a_root\":{:?},\"a_rows\":{},\"h_root\":{:?},\"h_rows\":{},\"mask_root\":{:?},\"log_cols\":{},\"logup_challenges\":{:?},\"layout_digest\":{:?},\"opening_order\":{},",
        h.sh.profile,
        h.public_statement,
        h.a_root,
        h.a_rows,
        h.h_root,
        h.h_rows,
        h.mask_root,
        h.sh.log_cols,
        fp2s(&h.logup),
        h.schedule_digest,
        {
            let mut order: Vec<String> = vec!["M".into()];
            order.extend(r.role_names.iter().map(|s| s.to_string()));
            format!("{order:?}")
        }
    )
    .expect("write to a Vec");
    state(&mut out, "header", &h.header);
    write!(out, ",\"arguments\":").expect("write to a Vec");
    array(&mut out, &r.arguments);
    write!(out, ",\"mask\":").expect("write to a Vec");
    out.write_all(r.mask.as_ref().expect("an accepted block has an M opening")).expect("write to a Vec");
    write!(out, ",\"roles\":").expect("write to a Vec");
    array(&mut out, &r.roles);
    write!(out, ",\"transcript_sites\":").expect("write to a Vec");
    array(&mut out, &r.sites);
    writeln!(out, "}}").expect("write to a Vec");
    out
}

/// The `hash_tag` member, as the run capture writes it (ruling T-1).
fn write_hash_tag(out: &mut Vec<u8>, sh: &Shape) {
    let tag = sh.hash_tag();
    let hex = |d: &[u8; 32]| -> String { d.iter().map(|b| format!("{b:02x}")).collect() };
    write!(out, "\"hash_tag\":{{\"rule\":{:?}", tag.rule_name()).expect("write to a Vec");
    if let (Some(t), Some(c), Some(l), Some(nd)) = (tag.transcript_key(), tag.column_key(), tag.leaf_key(), tag.node_key()) {
        write!(
            out,
            ",\"profile\":{:?},\"contexts\":{{\"transcript\":{:?},\"column\":{:?},\"leaf\":{:?},\"node\":{:?}}},\"keys_hex\":{{\"transcript\":{:?},\"column\":{:?},\"leaf\":{:?},\"node\":{:?}}}",
            sh.profile,
            zkp_core::hashtag::CTX_TRANSCRIPT,
            zkp_core::hashtag::CTX_COLUMN,
            zkp_core::hashtag::CTX_LEAF,
            zkp_core::hashtag::CTX_NODE,
            hex(t),
            hex(c),
            hex(l),
            hex(nd)
        )
        .expect("write to a Vec");
    }
    write!(out, "}}").expect("write to a Vec");
}

/// **The header file**: the analogue of a run bundle's `run.json` for ONE
/// block — the public statement, the shape as data, the external endpoints,
/// the hash rule, the transcript in words and the plane index table.
fn write_block(r: &Rec, h: &Head, source_commit: &str, proof_bytes: usize, proof_sha256: &str) -> Vec<u8> {
    let sh = &h.sh;
    let mut out = Vec::new();
    write!(
        out,
        "{{\"schema\":{SCHEMA:?},\"kind\":\"zk60-block-verifier-observations\",\"coverage\":\"native-block-shaped-all-slots-v1\",\"profile\":{:?},\"transcript_domain\":{:?},\"block_profile\":{:?},\"blocks\":1,\"fully_verified\":true,\"privacy\":\"P1\",\"privacy_review_complete\":false,\"weight_policy\":\"public-statement\",\"field_modulus\":{},\"extension_nonresidue\":{},\"public_tables_included\":{},\"source_commit\":{source_commit:?},\"block_binding\":{:?},\"context\":{:?},\"calibration\":{:?},\"public_statement_digest\":{:?},\"parameter_line\":{:?},\"schedule_digest\":{:?},\"expected_policy\":{:?},\"expected_policy_sha256\":{:?},\"proof_bytes\":{proof_bytes},\"proof_sha256\":{proof_sha256:?},\"proof_digest_encoding\":\"complete canonical native receipt (receipt.bin)\",\"shape\":{{\"name\":{:?},\"profile\":{:?},\"tokens\":{},\"width\":{},\"hidden\":{},\"q_heads\":{},\"kv_heads\":{},\"head_dim\":{},\"t_pad\":{},\"d_pad\":{},\"h_pad\":{},\"f_pad\":{},\"log_cols\":{},\"cols\":{},\"inv_rate\":{},\"opened_cols\":{},\"f_e\":{},\"endpoint_rows\":{},\"endpoint_log_n\":{},\"endpoint_inv_rate\":{},\"endpoint_general\":{},\"norm_wrho\":{},\"wrho_s\":{},\"slots\":{:?},\"a_groups\":{},\"h_groups\":{},\"n_slots\":{N_SLOTS}}},",
        sh.profile,
        sh.profile,
        sh.profile,
        crate::field::P,
        crate::field::NONRESIDUE,
        r.public_tables,
        h.binding,
        h.context,
        h.calibration,
        h.public_statement,
        h.parameter_line,
        h.schedule_digest,
        h.expected_bytes,
        crate::export_v3::sha256_hex(&h.expected_bytes),
        sh.name,
        sh.profile,
        sh.tokens,
        sh.width,
        sh.hidden,
        sh.q_heads,
        sh.kv_heads,
        sh.head_dim,
        sh.t_pad,
        sh.d_pad,
        sh.h_pad,
        sh.f_pad,
        sh.log_cols,
        1usize << sh.log_cols,
        sh.inv_rate,
        sh.opened_cols,
        sh.f_e,
        sh.endpoint_rows,
        sh.endpoint_log_n,
        sh.endpoint_inv_rate,
        sh.endpoint_general,
        sh.norm_wrho,
        sh.wrho_s,
        sh.slots().iter().map(|&(n, e, d)| [n, e, d]).collect::<Vec<_>>(),
        sh.a_groups(),
        sh.h_groups()
    )
    .expect("write to a Vec");
    let (rows, data, prox) = h.endpoint;
    write!(
        out,
        "\"external_endpoints\":{{\"input_root\":{:?},\"output_root\":{:?},\"rows\":{rows},\"data_rows\":{data},\"site_rows\":[{data},{}],\"prox_row\":{prox},\"log_n\":{},\"inv_rate\":{},\"input_scale\":{},\"output_scale\":{},\"claim_sites\":[{{\"site\":0,\"role\":\"Input\",\"slot\":{SC_IO_IN}}},{{\"site\":1,\"role\":\"Output\",\"slot\":{SC_IO_OUT}}}]}},",
        h.input_root,
        h.output_root,
        data + 1,
        sh.endpoint_log_n,
        sh.endpoint_inv_rate,
        h.scales.0,
        h.scales.1
    )
    .expect("write to a Vec");
    write!(out, "\"layout_description\":").expect("write to a Vec");
    strings(&mut out, &h.layout_description);
    write!(out, ",\"observation_files\":[{OBSERVATIONS_FILE:?}],\"transcript_domain_bytes\":{:?},", sh.profile.as_bytes()).expect("write to a Vec");
    write_hash_tag(&mut out, sh);
    write!(out, ",\"transcript_labels\":[").expect("write to a Vec");
    for (i, (label, what)) in TRANSCRIPT_LABELS.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{{\"label\":{label:?},\"what\":{what:?}}}").expect("write to a Vec");
    }
    write!(out, "],\"transcript_program\":").expect("write to a Vec");
    strings(&mut out, &TRANSCRIPT_PROGRAM.iter().map(|s| s.to_string()).collect::<Vec<_>>());
    write!(out, ",\"mask_domain\":{{\"log_dom\":{},\"columns\":{}}},", crate::zk::MASK_LOG_DOM, sh.opened_cols).expect("write to a Vec");
    out.write_all(&r.index_json).expect("write to a Vec");
    write!(out, ",\"not_in_a_capture\":[\"witness values\",\"pad values\",\"mask coefficients\",\"unopened columns\",\"unpublished salts\",\"unmasked sumcheck rounds\",\"hidden inputs, outputs and intermediate planes\",\"prover randomness\"]").expect("write to a Vec");
    writeln!(out, "}}").expect("write to a Vec");
    out
}

/// **EVERY FIAT-SHAMIR LABEL OF A STANDALONE BLOCK, as data.** The run's four
/// run-only labels (`run-shape`, `pb-run-stage`, `pb-run-block`, `B`) are
/// ABSENT: a standalone block absorbs none of them.
pub(super) const TRANSCRIPT_LABELS: [(&str, &str); 15] = [
    ("expected-IO", "block header: the endpoint policy bytes (ExpectedIo::to_bytes)"),
    ("public-statement", "block header: THIS BLOCK's public digest, one digest over the attention and feed-forward words (a run absorbs H(all block digests) here instead)"),
    ("parameters", "block header: this block profile's parameter line, as bytes (a run absorbs the run's line)"),
    ("calibration", "block header: the calibration identity"),
    ("schedule", "block header: the block layout's schedule digest (a run absorbs the run schedule digest)"),
    ("A", "the A root, then rows and log-cols"),
    ("M", "the masking commitment root; the three LogUp challenges follow"),
    ("H", "the H root, then rows and log-cols"),
    ("rows", "absorb_u64 after every commitment root"),
    ("log-cols", "absorb_u64 after every commitment root's row count"),
    ("pb-slot", "slot s: the slot index, absorb_u64; the CFS challenge c follows"),
    ("pb-scalar", "slot s: the one published masked scalar"),
    ("pb-term", "slot s: the masked terminals, after the sumcheck"),
    ("mask-q", "the M opening: theta is drawn first, then q is absorbed, then 2*slots+2 proximity challenges"),
    ("mask-prox", "the M opening: the proximity vector; the column indices follow"),
];

/// The transcript of a standalone block, in words, first byte to last.
pub(super) const TRANSCRIPT_PROGRAM: [&str; 9] = [
    "STAGE 17 (D19): every hash below is BLAKE3 under the rule named in hash_tag. Legacy = the unkeyed blake3::Hasher::new(); blake3-keyed/1 = keyed mode under the four keys derived from THIS BLOCK PROFILE's string, the transcript one here and the column / leaf / node ones inside every commitment.",
    "Transcript::new(block profile bytes) — Transcript::new_tagged under the keyed rule — then absorb expected-IO, public-statement (the block's own digest), parameters (this block profile's parameter line), calibration, schedule (the block layout's schedule digest). The state here is block_binding. There is NO run-shape word, NO pb-run-stage / pb-run-block and NO boundary root B: those are a run's.",
    "absorb A(root), rows, log-cols; absorb M(mask root); draw 3 Fp2 (beta, gamma, alpha: the LogUp challenges); absorb H(root), rows, log-cols.",
    "For each slot s = 0 .. 22: draw the definition challenges; absorb pb-slot(s); draw c; absorb pb-scalar; per sumcheck round absorb sc-round then draw one Fp2; absorb pb-term(terminals).",
    "The M opening: draw theta; absorb mask-q(q); draw 2*slots+2 Fp2; absorb mask-prox(prox); draw the column indices over 2^log_dom.",
    "Then the A and H openings, in that order: per group draw |members| lambdas, then draw `rows` proximity coefficients, then absorb pcs-vec per group, absorb pcs-prox, then draw num_col_checks column indices over cols*inv_rate.",
    "Then BOTH external endpoints in this one proof: Input (its one claim comes from slot 21 alone) then Output (its one claim from slot 22 alone), each the same opening program at the endpoint geometry (endpoint_log_n, endpoint_inv_rate, endpoint_rows). In a run the Input role is opened in stage 0 and the Output role in stage L-1, and every other IO role is an internal boundary.",
    "The slot 21 / 22 IO tables' mask_row is the STANDALONE layout's (Layout::for_shape): the external endpoint's reserved pair, at its data_rows. A run stage's layout gives the same row to an EXTERNAL endpoint (stage 0's Input, stage L-1's Output) and moves an INTERNAL boundary's claim to that boundary's own reserved pair (Layout::with_io_mask_rows).",
    "The receipt frame's 40-byte envelope (the magic and the header state block_binding) is COMPARED when the frame is decoded and is outside the Fiat-Shamir chain. There are no segment position tags.",
];

// ---------------------------------------------------------------- the PCS grouping replay

/// Copied from the run capture (itself adapted from `native_capture.rs`),
/// generalised over the PCS parameters, independent of the private PCS
/// grouping helpers, refusing a malformed mapping before ordinary PCS
/// verification.
#[derive(Clone, Debug, PartialEq)]
struct ColumnKey {
    tail: Vec<Fp2>,
    offset: usize,
    len: usize,
}

#[derive(Debug)]
struct Group {
    key: ColumnKey,
    members: Vec<usize>,
    lambdas: Vec<Fp2>,
}

#[derive(Debug)]
struct Replayed {
    groups: Vec<Group>,
    proximity_rhos: Vec<Fp2>,
}

fn column_key(p: &ZPart, params: &PcsParams, rows: usize) -> Result<ColumnKey, String> {
    let n = params.cols();
    let len = 1usize.checked_shl(p.slice.log_size).ok_or("slice overflow")?;
    let end = p.slice.offset.checked_add(len).ok_or("slice overflow")?;
    let capacity = rows.checked_mul(n).ok_or("capacity overflow")?;
    if end > capacity || (!p.point.is_empty() && p.point.len() != p.slice.log_size as usize) {
        return Err("slice bounds/point arity".into());
    }
    if len >= n {
        if p.slice.offset % n != 0 {
            return Err("unaligned row slice".into());
        }
        let tail = if p.point.is_empty() { vec![] } else { p.point[p.slice.log_size as usize - params.log_cols as usize..].to_vec() };
        Ok(ColumnKey { tail, offset: 0, len: n })
    } else {
        let offset = p.slice.offset % n;
        if offset + len > n {
            return Err("slice crosses row".into());
        }
        Ok(ColumnKey { tail: p.point.clone(), offset, len })
    }
}

fn replay(params: &PcsParams, cm: &Commitment, claims: &[ZClaim], opening: &OpeningZk, before: &Transcript) -> Result<Replayed, String> {
    let n = params.cols();
    let q = params.num_col_checks;
    let mut groups: Vec<Group> = Vec::new();
    for (ci, c) in claims.iter().enumerate() {
        let first = c.parts.first().ok_or("empty claim")?;
        let key = column_key(first, params, cm.rows)?;
        for p in &c.parts[1..] {
            if column_key(p, params, cm.rows)? != key {
                return Err("different column keys".into());
            }
        }
        if let Some(g) = groups.iter_mut().find(|g| g.key == key) {
            g.members.push(ci);
        } else {
            groups.push(Group { key, members: vec![ci], lambdas: vec![] });
        }
    }
    if groups.len() != opening.group_vecs.len() {
        return Err("group count".into());
    }
    let mut tr = Transcript::clone_state(before);
    for g in &mut groups {
        g.lambdas = tr.challenge_fp2_vec(g.members.len());
    }
    // Actual source order: proximity coefficients BEFORE vector absorption.
    let proximity_rhos = tr.challenge_fp2_vec(cm.rows);
    for (g, v) in groups.iter().zip(&opening.group_vecs) {
        if v.len() != n + q {
            return Err("vector length".into());
        }
        let cw = if g.key.tail.is_empty() { vec![Fp2::ONE; g.key.len] } else { eq_table_msb(&g.key.tail) };
        let got = v[g.key.offset..g.key.offset + g.key.len].iter().zip(cw).fold(Fp2::ZERO, |a, (v, c)| a.add(v.mul(c)));
        let want = g.members.iter().zip(&g.lambdas).fold(Fp2::ZERO, |a, (&ci, l)| a.add(l.mul(claims[ci].value)));
        if got != want {
            return Err("combined public claim".into());
        }
        tr.absorb_fp2(b"pcs-vec", v);
    }
    if opening.prox_vec.len() != n + q {
        return Err("proximity length".into());
    }
    tr.absorb_fp2(b"pcs-prox", &opening.prox_vec);
    let indices = tr.challenge_indices(q, params.enc_cols());
    if indices != opening.columns.iter().map(|c| c.0).collect::<Vec<_>>() {
        return Err("sampled column indices".into());
    }
    Ok(Replayed { groups, proximity_rhos })
}

// ---------------------------------------------------------------- the allow-list

/// The keys a block bundle adds to the run capture's allow-list
/// (`run_capture::ALLOWED_KEYS`). Each names public book-keeping: the header
/// transcript state, the receipt pin, the name of the per-proof file, and in
/// the manifest the public-weight recipe and which of the two witnesses
/// (the dense generic one or the all-zero control) the bundle was proved on.
pub(super) const BLOCK_ONLY_KEYS: [&str; 7] = ["block_binding", "proof_bytes", "proof_sha256", "proof_digest_encoding", "observation_files", "recipe", "witness"];

/// **EVERY KEY A BLOCK BUNDLE MAY CONTAIN**: the run capture's list plus
/// [`BLOCK_ONLY_KEYS`].
pub(super) fn allowed_keys() -> Vec<&'static str> {
    super::run_capture::ALLOWED_KEYS.iter().copied().chain(BLOCK_ONLY_KEYS.iter().copied()).collect()
}

// ---------------------------------------------------------------- writing a bundle out

/// Write a bundle to `dir`, which must not exist: `block.json`,
/// `observations.json`, `arrays.bin`, the receipt that was verified
/// (`receipt.bin`, pinned against the recorder's own re-encoding), the
/// endpoint policy (`expected.bin`), a README, and `manifest.json` LAST —
/// so a directory without a manifest is an incomplete bundle, not a capture.
#[allow(clippy::too_many_arguments)]
pub(super) fn write_bundle(dir: &std::path::Path, b: &Bundle, receipt: &[u8], expected: &[u8], recipe: &str, witness: &str, source_commit: &str, readme: &str) -> Result<usize, String> {
    if dir.exists() {
        return Err(format!("block capture: {} already exists; a bundle is written into a fresh directory and never over another", dir.display()));
    }
    if receipt.len() != b.proof_bytes || crate::export_v3::sha256_hex(receipt) != b.proof_sha256 {
        return Err("block capture: the receipt handed to the writer is not the one the recorder saw accepted".into());
    }
    if !contains(&b.block_json, &format!("\"expected_policy\":{expected:?}")) {
        return Err("block capture: the endpoint policy handed to the writer is not the one the verifier absorbed".into());
    }
    std::fs::create_dir_all(dir).map_err(|e| format!("block capture: {}: {e}", dir.display()))?;
    let mut files: Vec<(String, usize, String)> = Vec::new();
    let put = |name: &str, bytes: &[u8], files: &mut Vec<(String, usize, String)>| -> Result<(), String> {
        let path = dir.join(name);
        let mut f = std::fs::OpenOptions::new().create_new(true).write(true).open(&path).map_err(|e| format!("block capture: {}: {e}", path.display()))?;
        f.write_all(bytes).map_err(|e| format!("block capture: {}: {e}", path.display()))?;
        files.push((name.to_string(), bytes.len(), crate::export_v3::sha256_hex(bytes)));
        Ok(())
    };
    put(BLOCK_FILE, &b.block_json, &mut files)?;
    put(OBSERVATIONS_FILE, &b.observations, &mut files)?;
    put(ARRAYS_FILE, b.arrays.blob(), &mut files)?;
    put(RECEIPT_FILE, receipt, &mut files)?;
    put(EXPECTED_FILE, expected, &mut files)?;
    put("README.md", readme.as_bytes(), &mut files)?;
    let pins = source_pins()?;
    let mut manifest = Vec::new();
    write!(manifest, "{{\"schema\":{SCHEMA:?},\"kind\":\"zk60-block-capture-manifest\",\"profile\":{:?},\"blocks\":1,\"source_commit\":{source_commit:?},\"recipe\":{recipe:?},\"witness\":{witness:?},\"source_pins\":[", b.profile).expect("write to a Vec");
    for (i, (name, sha)) in pins.iter().enumerate() {
        if i > 0 {
            write!(manifest, ",").expect("write to a Vec");
        }
        write!(manifest, "{{\"file\":{name:?},\"sha256\":{sha:?}}}").expect("write to a Vec");
    }
    write!(manifest, "],\"files\":[").expect("write to a Vec");
    for (i, (name, bytes, sha)) in files.iter().enumerate() {
        if i > 0 {
            write!(manifest, ",").expect("write to a Vec");
        }
        write!(manifest, "{{\"file\":{name:?},\"bytes\":{bytes},\"sha256\":{sha:?}}}").expect("write to a Vec");
    }
    let total: usize = files.iter().map(|(_, n, _)| n).sum();
    writeln!(manifest, "],\"total_bytes\":{total}}}").expect("write to a Vec");
    let path = dir.join("manifest.json");
    let mut f = std::fs::OpenOptions::new().create_new(true).write(true).open(&path).map_err(|e| format!("block capture: {}: {e}", path.display()))?;
    f.write_all(&manifest).map_err(|e| format!("block capture: {}: {e}", path.display()))?;
    Ok(total + manifest.len())
}

pub(super) fn contains(haystack: &[u8], needle: &str) -> bool {
    let n = needle.as_bytes();
    !n.is_empty() && haystack.len() >= n.len() && haystack.windows(n.len()).any(|w| w == n)
}
