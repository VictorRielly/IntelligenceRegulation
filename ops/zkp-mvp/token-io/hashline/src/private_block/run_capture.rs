//! **STAGE 14: THE RUN CAPTURE — the verifier's view of a private RUN.**
//!
//! A capture bundle is the INPUT to the privacy gate of ruling M-8 (three
//! blocks at the development rung, all three roles of each boundary plane
//! ranked jointly). It is not a gate, it is not a result, and **nothing here
//! establishes a privacy property**: the joint-view tools that would read a
//! bundle live on the Python side and have never seen a run.
//!
//! **WHAT IS IN A BUNDLE: THE VERIFIER'S VIEW AND NOTHING ELSE.** A retained
//! capture counts as publishing (the security owner's ruling), so the writer
//! emits only quantities a verifier holds — the public statement, every
//! committed root, every challenge, every claim, the opened columns with
//! their published salts and paths, the masked sumcheck transcripts — and
//! `every_key_of_a_bundle_is_on_the_allow_list` fails if a field outside the
//! declared allow-list ever appears. There is no witness value, no pad, no
//! mask coefficient, no unopened column, no unpublished salt and no unmasked
//! round in any file this module writes.
//!
//! **HOW IT IS TAKEN.** By OBSERVING THE VERIFIER, never the prover. The
//! hooks in `run.rs`, `protocol.rs` and `argument.rs` are compiled only under
//! `cfg(test)` and return on their first line unless a recorder is attached;
//! they hand the recorder what the verifier already holds and take nothing
//! back, so no branch of the protocol can depend on whether a recorder is
//! there (`a_run_verifies_the_same_with_and_without_a_recorder`).
//!
//! **THE RECORDER REPLAYS INDEPENDENTLY.** It keeps its OWN transcript,
//! seeded from the run statement's public words (profile, shape, endpoint
//! policy, public statement, parameter line, calibration, schedule digest) —
//! never adopted from the verifier — and re-derives every challenge from the
//! recorded roots, claims and openings in transcript order, comparing its own
//! state against the verifier's at every site. The first mismatch aborts the
//! capture, and **no bundle is written for a run the verifier did not
//! accept**: `finish` refuses unless `L` stages closed and the run's closing
//! check passed.
//!
//! **It is a NEW module, never an edit of `native_capture.rs`** (ruling M-8),
//! and it is a strict superset of that writer's schema: the same per-slot,
//! per-mask and per-commitment objects with the same field names, plus a run
//! header, the per-boundary objects a run adds, and every size the toy writer
//! left implicit written out as data so the Python side ports no layout.

use super::argument::{Acc, Coord, Side, SlotDef, SlotProof, Tab};
use super::layout::{Layout, N_SLOTS, SLOT_KINDS, SLOT_NAMES};
use super::plane_index::{self, PlaneIndex, Ref};
use super::shape::Shape;
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

/// The schema this module writes. A run bundle is a NEW schema beside the
/// single-block `{"schema":3,"kind":"zk60-verifier-observations"}`, never a
/// silent extension of it: a loader that does not know runs must refuse it by
/// version rather than mis-read a stage as a proof.
pub(super) const SCHEMA: &str = "hashline-native-capture/4-run";

/// **STAGE 27: the schema a bundle carries when its large homogeneous field
/// arrays live in a binary side file.** `/5-run` differs from [`SCHEMA`] in
/// exactly one way and in no other: a field-element array of at least
/// [`ARRAY_MIN`] entries is written as the OBJECT
/// `{"array":"<sha256>","elem":"fp"|"fp2","len":N,"offset":O,"bytes":B}`
/// instead of a JSON list, and the `B` bytes at offset `O` of the bundle's
/// one `arrays.bin` are that array little-endian — eight bytes per `Fp`,
/// sixteen per `Fp2` (`c0` then `c1`). Every other field, every key, every
/// order and every small array is byte for byte what `/4-run` writes, so a
/// reader of `/4-run` needs only the array resolver to read `/5-run`.
/// Written only when the writer is asked for it (`HL_RUN_CAPTURE_ARRAYS=store`
/// or the explicit argument of [`begin_run_with`]); the default stays
/// `/4-run` and every bundle committed before this stage stays readable.
pub(super) const SCHEMA_V5: &str = "hashline-native-capture/5-run";

/// An array of at least this many field elements goes to `arrays.bin` when
/// the store is on. Below it the classic inline list is written, so the small
/// per-slot vectors (`rho`, `terminals`, the sumcheck rounds, an endpoint's
/// nine-row column) read exactly as they always have.
pub(super) const ARRAY_MIN: usize = 256;

/// Does the environment ask for the binary array store? The default is NO:
/// every existing test, gate bundle and Python loader keeps the `/4-run`
/// encoding unless a caller says otherwise.
pub(super) fn array_store_wanted() -> bool {
    std::env::var("HL_RUN_CAPTURE_ARRAYS").map(|v| v == "store").unwrap_or(false)
}

/// **What a capture is asked for, decided ONCE at `begin_run` and never
/// re-read from the environment inside a run.** Both choices change what a
/// bundle contains, so a caller that wants a particular bundle says so
/// outright and a test can capture one run two ways in one process.
#[derive(Clone, Copy)]
pub(super) struct CaptureOpts {
    /// large homogeneous arrays go to `arrays.bin` (schema `/5-run`)
    pub arrays: bool,
    /// a public table carries its VALUES, not only its length and digest
    pub public_tables: bool,
}

impl CaptureOpts {
    pub(super) fn from_env() -> CaptureOpts {
        CaptureOpts { arrays: array_store_wanted(), public_tables: public_tables_wanted() }
    }
}

/// Which schema string a bundle declares, decided once by whether its arrays
/// are in `arrays.bin`.
pub(super) fn schema_of(arrays: bool) -> &'static str {
    if arrays {
        SCHEMA_V5
    } else {
        SCHEMA
    }
}

/// Every Rust file whose bytes decide what a bundle contains. Their SHA-256 at
/// capture time is the bundle's source pin, so a bundle can be tied to the
/// code that produced it without trusting a commit id.
///
/// **STAGE 24, round 6 of the native run gate (`ZK60_NATIVE_RUN_GATE.md`
/// §10.2, §10.8), 2026-09-21.** That round's mechanism is bundle-side: a
/// gate can pin a file only if the WRITER pins it. Four files on the run's
/// path were not here — `wire.rs`, `run_sink.rs`, `endpoint_g.rs` and
/// `hash_domain.rs` — so no bundle could be tied to them however a port grew,
/// and the round recorded that as a Rust-lane ask. This list is now the whole
/// of the run's own path, enumerated from the modules the run prover and the
/// run verifier reach (see [`NOT_ON_THE_RUNS_PATH`] for the production
/// modules that are deliberately NOT here, each with its reason, and
/// `s24_tests::the_capture_writer_pins_every_run_layer_source_it_depends_on`
/// for the test that the two lists partition the module list).
///
/// **PURE ADDITION.** The schema name does not move: a bundle's
/// `source_pins` is a list of `(file, sha256)` objects, and adding entries
/// changes no field, no order of anything a loader reads by name, and no
/// existing entry. The bundles already committed are NOT re-taken; they carry
/// the eight-entry list they were written with, which is what their own
/// manifests pin.
/// **STAGE 27, the Python gate's open item: the SHARED files are pinned too.**
/// Until this stage the list was `private_block`'s own path and nothing else,
/// so a bundle said nothing about the code that actually builds its
/// transcript, its commitments and its openings — `hashline/src/zk.rs`, the
/// six thin re-export adapters, and the `zkp-core` modules behind them. A
/// gate could therefore not tell two bundles apart that were written by the
/// same `private_block` over a changed `zkp-core`.
///
/// The list below is the `use` graph of the run's prover and verifier, read
/// off the sources: `private_block.rs` and its modules reach
/// `crate::{field, merkle, mle, ntt, pcs, sumcheck, transcript}` (each a
/// one-line `pub use zkp_core::<m>::*` adapter), `crate::zk` (the masking
/// commitment, `ZkRng`, `CfsMask`), `crate::tables_attn`,
/// `crate::causal_oracle`, `crate::private_seam` (reached by `endpoint_g.rs`),
/// `crate::export_v3` (the SHA-256 helper this writer itself uses) and
/// `zkp_core::hashtag`; and `zkp-core` itself carries the canonical
/// `field / merkle / mle / ntt / pcs (+ pcs/backend) / rng / sumcheck /
/// transcript / hashtag` and its `lib.rs`.
///
/// **LISTING A FILE IS NOT EDITING IT.** A pin reads the file at capture time
/// and records its SHA-256; nothing here writes to a shared or frozen file,
/// and no byte of any profile moves.
///
/// **PURE ADDITION, so the schema name does not move for this.** `source_pins`
/// is a list of `(file, sha256)` objects; adding entries renames nothing,
/// reorders nothing a loader reads by name and removes nothing. Bundles
/// already committed keep the shorter list their own manifests pin.
pub(super) const SHARED_SOURCE_FILES: [&str; 29] = [
    // hashline's own shared modules on the run's path
    "src/zk.rs",
    "src/tables_attn.rs",
    "src/causal_oracle.rs",
    "src/private_seam.rs",
    "src/export_v3.rs",
    // the thin adapters: one line each today, and the line says which
    // zkp-core module a name resolves to
    "src/field.rs",
    "src/merkle.rs",
    "src/mle.rs",
    "src/ntt.rs",
    "src/pcs.rs",
    "src/sumcheck.rs",
    "src/transcript.rs",
    // and the canonical implementations behind them
    "../zkp-core/src/lib.rs",
    "../zkp-core/src/field.rs",
    "../zkp-core/src/hashtag.rs",
    "../zkp-core/src/merkle.rs",
    "../zkp-core/src/mle.rs",
    "../zkp-core/src/ntt.rs",
    "../zkp-core/src/pcs.rs",
    "../zkp-core/src/pcs/backend.rs",
    "../zkp-core/src/rng.rs",
    "../zkp-core/src/sumcheck.rs",
    "../zkp-core/src/transcript.rs",
    // NATIVE LANE, round 5 (the privacy-gate lane's finding G-2): three
    // `zkp-core` submodules on the prover's path that no capture pinned —
    // the commitment's encode buffer (`pcs.rs: mod encode_buffer`) and the
    // sumcheck's round and grouped bodies (`sumcheck.rs: mod rounds; mod
    // grouped`). Pure addition, as stage 27's list was.
    "../zkp-core/src/pcs/encode_buffer.rs",
    "../zkp-core/src/sumcheck/rounds.rs",
    "../zkp-core/src/sumcheck/grouped.rs",
    // NATIVE LANE R5b (review r4 note N-r4-d; the privacy-gate lane's draft
    // section 5a): `gpu/mod.rs` sits on the CPU path too (the decline
    // routing, `gpu::label()` recorded in a trained statement, the backend
    // switch every commitment goes through); `tables_v3.rs` and zkp-core's
    // `tables.rs` are the SiLU / activation table registry the trained
    // loader checks every exported `act` table against. Deliberately NOT
    // pinned: `gpu/cuda.rs` and `gpu/kernels.cu` (compiled only with the
    // `gpu-cuda` feature, which a CPU-only deployment binary does not carry),
    // and `layer.rs` / `wcache.rs` (the older FFN provers; the private block
    // and the run do not reach them).
    "src/gpu/mod.rs",
    "src/tables_v3.rs",
    "../zkp-core/src/tables.rs",
];

pub(super) const OWN_SOURCE_FILES: [&str; 23] = [
    "src/private_block/run_capture.rs",
    "src/private_block/run.rs",
    "src/private_block/boundary.rs",
    "src/private_block/protocol.rs",
    "src/private_block/argument.rs",
    "src/private_block/layout.rs",
    // STAGE 15: the plane index table's own independent derivation
    "src/private_block/plane_index.rs",
    // STAGE 17: `Shape::hash_tag` decides which hash rule made every byte of
    // the run, and the `hash_tag` member of the run file names it.
    "src/private_block/shape.rs",
    // STAGE 24 (round 6's ask), the four the round named:
    // the segment frame — its lengths, its two position tags, and the header
    // a stage file's `segment_bytes` / `segment_sha256` are taken over
    "src/private_block/wire.rs",
    // where a finished segment goes and what a run directory may hold: the
    // bytes a stage file pins are the bytes this module wrote
    "src/private_block/run_sink.rs",
    // the generalised endpoint's mask rows and commitment construction, which
    // fix the external endpoints' row roles in every bundle
    "src/private_block/endpoint_g.rs",
    // the T-3 / T-4 hash-input-length and path-depth guards a run must pass
    // before any of it is captured
    "src/private_block/hash_domain.rs",
    // STAGE 24, found by the enumeration: the PARENT module. `ExpectedIo`,
    // `IoSpec` and `calibration_identity` live here, and `expected.to_bytes()`
    // is absorbed by the run header — the very bytes ruling H-1 rests on, and
    // a leaf of every `run.json`.
    "src/private_block.rs",
    // and the witness type and builder, which decide every value a verifier
    // then observes
    "src/private_block/witness.rs",
    // the pad rule's support indicators and pad-zero plane groups, which
    // `argument.rs` reads into the slot definitions a bundle records
    "src/private_block/pad.rs",
    // NATIVE LANE (2026-10-17): the trained-model statement, whose identity a
    // bound run absorbs as its `"calibration"` word (`RunStatement::new_bound`)
    "src/private_block/trained_statement.rs",
    // TOKEN I/O R1 LANE (2026-10-17): the token-I/O run — its module root
    // (the stage slot runner, the token profile door, the stage wire, the
    // owner check) and the three production submodules (stage IN, stage OUT,
    // the run statement / prover / verifier). PURE ADDITION to the list.
    "src/private_block/token_io.rs",
    "src/private_block/token_io/stage_in.rs",
    "src/private_block/token_io/stage_out.rs",
    "src/private_block/token_io/run.rs",
    // TOKEN I/O LANE (2026-10-19, review TR3-2): the production loaders (the
    // token tables, the export's public side, the streaming block source)
    // decide the public statement a token run binds; the CLI bridge renders
    // and publishes it. Both pinned.
    "src/private_block/token_io/load.rs",
    "src/private_block/token_io/cli.rs",
    // NATIVE LANE R5b (review r4 note N-r4-d; the privacy-gate lane): the
    // trained export reader and CLI bridge. It adds no protocol code, but it
    // decides the public statement a trained run binds (the padded words,
    // the SiLU-registry and exp / RoPE table checks, the sealing pass, the
    // context label and the statement files), so a trained capture pins it.
    // It was excused in `NOT_ON_THE_RUNS_PATH` until R5b.
    "src/private_block/trained_block.rs",
];

/// **The production modules of `private_block` that are NOT source pins, with
/// the reason** (stage 24). [`OWN_SOURCE_FILES`] plus this list is the whole module
/// list, and a test asserts that partition, so a new production module cannot
/// be added without a decision about it being recorded here.
pub(super) const NOT_ON_THE_RUNS_PATH: [(&str, &str); 2] = [
    // (NATIVE LANE R5b: `trained_block.rs`, excused here until R5b, is now a
    // source pin in `OWN_SOURCE_FILES` — review r4 note N-r4-d.)
    (
        "src/private_block/timing.rs",
        "the phase clock: WRITE-ONLY on the run's path (`protocol.rs:13-16` says so of `ph`), every call returns on its first line unless HL_PB_TIMING is set, and it decides no byte of a receipt or of a bundle",
    ),
    // NATIVE LANE: the driver overlay's CLI bridge is a CALLER of the run
    // (`run::prove_run` / `run::verify_run_from_dir`), not part of it
    (
        "src/private_block/mvp_driver.rs",
        "the production CLI bridge over `run::prove_run` / `run::verify_run_from_dir`: it builds a statement through the public constructors and adds no protocol code, so no byte of a receipt or of a bundle is decided here",
    ),
];

// ---------------------------------------------------------------- the public words of a run

/// One internal boundary's PUBLIC facts, as the run statement derives them.
/// The row count here is the DERIVED one (ruling M-1) — `data + 2*sites + 2` —
/// and the row indices are stated outright so that the Python side never
/// recomputes a layout.
#[derive(Clone)]
pub(super) struct BoundaryFacts {
    pub index: usize,
    pub scale: i32,
    pub sites: usize,
    pub data_rows: usize,
    pub rows: usize,
    pub site_rows: Vec<usize>,
    pub prox_row: usize,
    pub log_n: usize,
    pub inv_rate: usize,
    pub checks: usize,
    pub digest: Digest,
    /// the padded plane this boundary commits, `(t_pad, d_pad)`
    pub plane: (usize, usize),
}

/// The run's public statement, copied out of `RunStatement` by
/// `RunStatement::capture_header` (its fields are private to `run.rs`). Every
/// word the run header absorbs is here, in the order it is absorbed, so the
/// recorder can rebuild the header transcript from scratch and compare.
pub(super) struct RunHeader {
    pub profile: &'static str,
    pub l: usize,
    pub sh: Shape,
    /// the seven `u64` of the `"run-shape"` word, little-endian, in order
    pub run_shape_words: Vec<u64>,
    pub expected_bytes: Vec<u8>,
    pub public_statement: Digest,
    pub parameter_line: String,
    pub calibration: Digest,
    pub schedule_digest: Digest,
    pub context: Digest,
    pub block_digests: Vec<Digest>,
    pub boundary_scales: Vec<i32>,
    pub external_input_root: Digest,
    pub external_output_root: Digest,
    pub external_rows: usize,
    pub external_data_rows: usize,
    pub external_log_n: usize,
    pub external_inv_rate: usize,
    pub stage_lines: Vec<String>,
    pub layout_description: Vec<String>,
    pub boundaries: Vec<BoundaryFacts>,
    /// the `input_scale, output_scale` of the run's endpoint policy
    pub external_scales: (i32, i32),
    /// **TOKEN I/O (round 7; the gate lane's capture request 2.1(a)).**
    /// `None` for a block run (its bundle is byte for byte what it was);
    /// `Some` for a token-I/O run, whose header the recorder rebuilds from
    /// the words above exactly as for a block run (the token run absorbs
    /// the same six header words, with `run-shape` eight u64 long).
    pub token: Option<TokenFacts>,
    /// **ROUND 12 (gate round 16, capture request 2.1(a)).** `None` for a
    /// block run and a token run (their bundles are byte for byte what they
    /// were); `Some` for a classifier run, whose header absorbs the same six
    /// words and then `classify-verdict` and `classify-chunk`.
    pub classify: Option<ClassifyFacts>,
}

/// **TOKEN I/O (round 7): one token endpoint's PUBLIC facts** (its spec:
/// row count, data rows, the one claim site, the proximity pair, the PCS
/// levers, the padded plane geometry and the spec digest).
#[derive(Clone)]
pub(super) struct TokenEndpointFacts {
    pub rows: usize,
    pub data_rows: usize,
    pub sites: usize,
    pub site_rows: Vec<usize>,
    pub prox_row: usize,
    pub log_n: usize,
    pub inv_rate: usize,
    pub checks: usize,
    /// the padded plane the endpoint commits, `(rows, cols)` of its words
    pub plane: (usize, usize),
    pub digest: Digest,
    pub scale: i32,
}

/// **TOKEN I/O (round 7; capture request 2.1(a)): every public word of a
/// token-I/O run that a block run's statement does not carry**, copied out
/// of `TokenRunStatement::capture_header`. Its parameter line and schedule
/// (both absorbed by the header) already bind all of them; this states them
/// as data so the gate ports no layout. Nothing here is private: no token,
/// no activation, no owner decommitment.
#[derive(Clone)]
pub(super) struct TokenFacts {
    pub run_profile: &'static str,
    pub v: usize,
    pub v_pad: usize,
    pub tokens: usize,
    pub t_pad: usize,
    pub d: usize,
    pub d_pad: usize,
    /// the selector variant's tag (only the public row is built)
    pub variant: &'static str,
    /// the length mode: `"i"` (public length T); `"ii"` is not built
    pub mode: &'static str,
    /// the keyed difference's byte limbs `L` (derived, never exported)
    pub limbs: usize,
    pub window_bits: u32,
    pub mult_bits: u32,
    pub emb_digest: Digest,
    pub head_digest: Digest,
    pub bos: u64,
    /// `(g0, Cn_f, tn_f, Ceps_f)`
    pub final_norm: (i64, i64, u32, i64),
    /// `s_in` and `s_out`: the run's ONE boundary scale (M-4), twice
    pub scales: (i32, i32),
    /// the tier: name, opened columns, stage `log_n` and inverse rate,
    /// endpoint `log_n` and inverse rate
    pub tier: (&'static str, usize, usize, usize, usize, usize),
    /// `[input, output]`
    pub endpoints: [TokenEndpointFacts; 2],
    pub input_root: Digest,
    pub output_root: Digest,
    /// every boundary of the token run in its own numbering: `0` = `B_in`
    /// (committed in stage IN, opened in block 0's stage), `1 .. L-1` the
    /// internal ones, `L` = `B_out` (committed in block `L - 1`'s stage,
    /// opened in stage OUT)
    pub boundaries: Vec<BoundaryFacts>,
    /// how many `r_emb` coordinates stage IN draws after its three LogUp
    /// challenges (`clog2(d_pad)`)
    pub r_emb_len: usize,
    /// the two new stages' layout descriptions (`StageLayout::describe`)
    pub stage_layouts: [Vec<String>; 2],
}

/// **ROUND 12 (rung R-C1; the gate's round-16 capture request 2.1(a)):
/// every public word of a CLASSIFIER run that a block run's statement does
/// not carry**, copied out of `ClassifyRunStatement::capture_header`, in the
/// header's absorb order. The parameter line and schedule already bind all
/// of them; this states them as data. Nothing here is private: no content
/// id, no activation, no margin, no limb, no owner decommitment. The verdict
/// is the one data-dependent public value.
#[derive(Clone)]
pub(super) struct ClassifyFacts {
    pub run_profile: &'static str,
    pub v: usize,
    pub v_pad: usize,
    pub tokens: usize,
    pub t_pad: usize,
    pub d: usize,
    pub d_pad: usize,
    /// the template prefix length, the content length (public: B-5), the suffix length
    pub p0: usize,
    pub n: usize,
    pub s: usize,
    /// the classifier profile's canonical text (`describe_under`) and its digest
    pub profile_text: String,
    pub profile_digest: Digest,
    pub policy_id: String,
    pub prefix: Vec<u64>,
    pub suffix: Vec<u64>,
    pub num_special: u64,
    pub yes: u64,
    pub no: u64,
    pub c: i64,
    pub tokenizer: String,
    pub template_digest: Digest,
    /// the margin vector's digest (the vector itself is a public table of
    /// slot OUTC-03, recorded with its values under public tables)
    pub w_digest: Digest,
    pub emb_digest: Digest,
    pub bos: u64,
    /// `(g0, Cn, tn, Ceps)`
    pub final_norm: (i64, i64, u32, i64),
    pub wrho: u32,
    pub d_max: i128,
    pub window_bits: u32,
    pub limbs: usize,
    /// the limbs' first entry of the `Lo` plane
    pub lam_base: usize,
    /// the tier: name, opened columns, stage `log_n` and inverse rate,
    /// endpoint `log_n` and inverse rate
    pub tier: (&'static str, usize, usize, usize, usize, usize),
    pub scale: i32,
    /// the ONE external endpoint (the input token plane)
    pub input_endpoint: TokenEndpointFacts,
    pub input_root: Digest,
    /// every boundary in token numbering: `0` = `B_in`, `L` = `B_out`
    pub boundaries: Vec<BoundaryFacts>,
    /// how many `r_emb` coordinates stage IN-C draws after its three LogUp challenges
    pub r_emb_len: usize,
    /// stage IN-C's and OUT-C's layout descriptions
    pub stage_layouts: [Vec<String>; 2],
    /// **THE PUBLIC VERDICT** (absorbed as `classify-verdict`)
    pub verdict: u8,
    /// **D41's chunk** `[index, count, a, b, total, size, overlap]`
    /// (absorbed as `classify-chunk`, seven u64 little-endian)
    pub chunk: [usize; 7],
}

impl ClassifyFacts {
    /// the `classify-chunk` word, as `ChunkRef::bytes` writes it
    pub(super) fn chunk_bytes(&self) -> Vec<u8> {
        self.chunk.iter().flat_map(|v| (*v as u64).to_le_bytes()).collect()
    }
}

/// **TOKEN I/O (round 7): which plane table a stage of a token run reads.**
/// A block stage's is the block `Layout`'s (the run's one `plane_index`);
/// stage IN's and OUT's are built from their `StageLayout` with the plane
/// names the stage modules declare.
pub(super) enum StagePlanes<'a> {
    Block(&'a Layout),
    Stage { lay: &'a super::token_io::StageLayout, a_names: Vec<String>, h_names: Vec<String>, roles: [&'static str; 4] },
}

/// **TOKEN I/O (round 7): a new stage's plane table** (capture request
/// 2.1(b)): every `A` and `H` plane with its name, log size and rows, the
/// row bookkeeping, the schedule, and per slot the planes its terminal
/// vector evaluates, in the order the verifier's own slot definitions push
/// them (OBSERVED during the capture, not independently declared: the
/// definitions are `stage_in.rs` / `stage_out.rs`).
struct TokenPlanes {
    a: Vec<(String, usize, usize, usize, usize)>,
    h: Vec<(String, usize, usize, usize, usize, usize, usize)>,
    n: usize,
    roles: [&'static str; 4],
    slots: Vec<Vec<(usize, Option<usize>)>>,
    json_head: Vec<u8>,
}

impl TokenPlanes {
    fn build(lay: &super::token_io::StageLayout, a_names: &[String], h_names: &[String], roles: [&'static str; 4]) -> Result<TokenPlanes, String> {
        if a_names.len() != lay.a_log.len() || h_names.len() != lay.h_log.len() {
            return Err(format!("{}: the plane name lists ({} A, {} H) are not the layout's ({} A, {} H)", lay.sched.label, a_names.len(), h_names.len(), lay.a_log.len(), lay.h_log.len()));
        }
        let n = lay.n;
        let rows_of = |log: usize| std::cmp::max(1, (1usize << log) >> lay.log_n);
        let mut a = Vec::with_capacity(lay.a_log.len());
        let mut next = 0usize;
        for (i, (&log, &off)) in lay.a_log.iter().zip(lay.a_off.iter()).enumerate() {
            if off != next * n {
                return Err(format!("{}: A plane {i} does not start where plane {} ended", lay.sched.label, i.saturating_sub(1)));
            }
            let rows = rows_of(log);
            a.push((a_names[i].clone(), log, off / n, rows, off));
            next += rows;
        }
        if next != lay.a_data_rows {
            return Err(format!("{}: the A planes do not tile [0, {})", lay.sched.label, lay.a_data_rows));
        }
        let mut h = Vec::with_capacity(lay.h_log.len());
        let mut next = 0usize;
        for (i, (&log, &(re, im))) in lay.h_log.iter().zip(lay.h_off.iter()).enumerate() {
            let rows = rows_of(log);
            if re != next * n || im != (next + rows) * n {
                return Err(format!("{}: H plane {i}'s halves do not tile the rows", lay.sched.label));
            }
            h.push((h_names[i].clone(), log, rows, re / n, im / n, re, im));
            next += 2 * rows;
        }
        if next != lay.h_data_rows {
            return Err(format!("{}: the H planes do not tile [0, {})", lay.sched.label, lay.h_data_rows));
        }
        let mut j = Vec::new();
        write!(j, "\"stage_plane_index\":{{\"label\":{:?},\"log_n\":{},\"cols\":{n},\"roles\":{:?},\"a_rows\":{},\"a_data_rows\":{},\"a_mask_base\":{},\"a_prox\":{},\"h_rows\":{},\"h_data_rows\":{},\"h_mask_base\":{},\"h_prox\":{},\"h_u\":{},\"h_u_rows\":{:?},\"h_sign\":{:?},\"a_planes\":[", lay.sched.label, lay.log_n, roles, lay.a_rows, lay.a_data_rows, lay.a_mask_base, lay.a_prox, lay.h_rows, lay.h_data_rows, lay.h_mask_base, lay.h_prox, lay.h_u, lay.h_u_rows(), lay.h_sign).expect("write to a Vec");
        for (i, (name, log, first, rows, off)) in a.iter().enumerate() {
            if i > 0 {
                write!(j, ",").expect("write to a Vec");
            }
            write!(j, "{{\"id\":{i},\"name\":{name:?},\"domain\":{:?},\"first_row\":{first},\"rows\":{rows},\"offset\":{off},\"log_size\":{log}}}", format!("2^{log}")).expect("write to a Vec");
        }
        write!(j, "],\"h_planes\":[").expect("write to a Vec");
        for (i, (name, log, rows, ref_, imf, reo, imo)) in h.iter().enumerate() {
            if i > 0 {
                write!(j, ",").expect("write to a Vec");
            }
            write!(j, "{{\"id\":{i},\"name\":{name:?},\"domain\":{:?},\"rows\":{rows},\"re_first_row\":{ref_},\"im_first_row\":{imf},\"re_offset\":{reo},\"im_offset\":{imo},\"log_size\":{log}}}", format!("2^{log}")).expect("write to a Vec");
        }
        write!(j, "],\"sched\":{{\"slots\":[").expect("write to a Vec");
        for (i, sp) in lay.sched.slots.iter().enumerate() {
            if i > 0 {
                write!(j, ",").expect("write to a Vec");
            }
            write!(j, "{{\"slot\":{i},\"name\":{:?},\"main\":{},\"extension\":{},\"degree\":{},\"kind\":{:?},\"a_sites\":{},\"h_sites\":{},\"io_sites\":{}}}", sp.name, sp.main, sp.ext, sp.degree, format!("{:?}", sp.kind), sp.a_sites, sp.h_sites, sp.io_sites).expect("write to a Vec");
        }
        write!(j, "],\"hosts\":[").expect("write to a Vec");
        for (i, (host, hosted)) in lay.sched.hosts.iter().enumerate() {
            if i > 0 {
                write!(j, ",").expect("write to a Vec");
            }
            write!(j, "{{\"slot\":{host},\"hosted\":{hosted:?}}}").expect("write to a Vec");
        }
        write!(j, "],\"row_log\":{:?}}}", lay.sched.row_log).expect("write to a Vec");
        Ok(TokenPlanes { a: a.into_iter().map(|(n_, l, f, r, o)| (n_, l, f, r, o)).collect(), h, n, roles, slots: Vec::new(), json_head: j })
    }

    /// the plane a private table of role `cm` and first slice offset `off`
    /// evaluates: `(cm, Some(plane id))` for `A` / `H`, `(cm, None)` for the
    /// two IO roles; `None` if it is on no plane
    fn locate(&self, cm: usize, off: usize) -> Option<(usize, Option<usize>)> {
        match cm {
            0 => self.a.iter().position(|(_, _, _, rows, o)| off >= *o && off < *o + rows * self.n).map(|p| (0, Some(p))),
            1 => self.h.iter().position(|(_, _, _, _, _, re, _)| *re == off).map(|p| (1, Some(p))),
            2 | 3 => Some((cm, None)),
            _ => None,
        }
    }

    fn render(&self) -> Vec<u8> {
        let mut j = self.json_head.clone();
        write!(j, ",\"slot_planes\":[").expect("write to a Vec");
        for (s, refs) in self.slots.iter().enumerate() {
            if s > 0 {
                write!(j, ",").expect("write to a Vec");
            }
            write!(j, "{{\"slot\":{s},\"planes\":[").expect("write to a Vec");
            for (i, (cm, id)) in refs.iter().enumerate() {
                if i > 0 {
                    write!(j, ",").expect("write to a Vec");
                }
                let name = match (cm, id) {
                    (0, Some(p)) => self.a[*p].0.clone(),
                    (1, Some(p)) => self.h[*p].0.clone(),
                    _ => self.roles[*cm].to_string(),
                };
                match id {
                    Some(p) => write!(j, "{{\"role\":{:?},\"id\":{p},\"name\":{name:?}}}", self.roles[*cm]),
                    None => write!(j, "{{\"role\":{:?},\"id\":null,\"name\":{name:?}}}", self.roles[*cm]),
                }
                .expect("write to a Vec");
            }
            write!(j, "]}}").expect("write to a Vec");
        }
        write!(j, "],\"slot_planes_source\":\"observed from the verifier's slot definitions during the capture\"}}").expect("write to a Vec");
        j
    }
}

/// What an opening's row geometry is, handed to [`pcs`] by the call site that
/// knows it. Nothing here is read from a frame.
pub(super) struct Geom {
    /// `"A"`, `"H"`, `"Input"` or `"Output"` — the FOUR role names the
    /// single-block schema already has, kept even when the commitment behind
    /// an IO role is an internal boundary rather than an external endpoint.
    /// The role names the CLAIM SITE (block `k`'s incoming or outgoing
    /// equality slot); `commitment_kind` and `boundary` name the COMMITMENT.
    pub role: &'static str,
    /// `"external-endpoint"`, `"internal-boundary"` or `"block"`
    pub commitment_kind: &'static str,
    pub params: PcsParams,
    pub root: Digest,
    pub rows: usize,
    pub data_rows: usize,
    /// the reserved claim-pair rows, first row of each pair first
    pub site_rows: Vec<usize>,
    /// `H`'s two zero-sum rows, which sit inside the data range
    pub sum_rows: Option<[usize; 2]>,
    pub prox_row: usize,
    /// which internal boundary this opening discharges, if it is one
    pub boundary: Option<usize>,
    /// `(stage, slot, how many claims)`, in claim order
    pub claim_sources: Vec<(usize, usize, usize)>,
}

// ---------------------------------------------------------------- the array side store

/// **STAGE 27: the binary side store for the large homogeneous arrays.**
///
/// **Why it exists.** Rendered as decimal JSON a uniformly random `Fp` costs
/// 21.4 bytes and an `Fp2` 44.8 (MEASURED on the committed rung bundles), so
/// at the 125M shape one stage's opened columns and opening vectors alone
/// are 112 MB of text and the twenty-three slots' public tables are another
/// 213 MB. The same values little-endian are 8 and 16 bytes, and — this is
/// the larger saving — the shape-only public tables (the causal mask and the
/// pad indicators) are BYTE-IDENTICAL between slots and between stages, so
/// content addressing writes each of them once for the whole bundle.
///
/// **It keeps every value.** Nothing is dropped, summarised or rounded: the
/// store holds exactly the numbers the classic encoding would have printed,
/// and `the_array_store_and_the_classic_encoding_carry_the_same_values`
/// decodes a bundle written both ways and compares them entry by entry.
///
/// **It is IN MEMORY until the run is accepted.** Ruling D21 / M-9 says no
/// bundle is written for a run the verifier did not accept, so the blob is
/// held and handed to [`write_bundle`] with the rest; nothing reaches the
/// disk before `take` has refused or succeeded. At the 125M shape the blob
/// is about 258 MB with the public tables and 82 MB without — two orders of
/// magnitude under the run's own working set, which is why this writer needs
/// no streaming and none was built.
pub(super) struct ArrayStore {
    on: bool,
    blob: Vec<u8>,
    /// content digest -> (offset, bytes) inside `blob`
    index: std::collections::HashMap<String, (usize, usize)>,
    /// how many arrays were stored, and how many of those were already there
    stored: usize,
    deduped: usize,
    inline: usize,
}

impl ArrayStore {
    fn new(on: bool) -> ArrayStore {
        ArrayStore { on, blob: Vec::new(), index: std::collections::HashMap::new(), stored: 0, deduped: 0, inline: 0 }
    }
    pub(super) fn is_on(&self) -> bool {
        self.on
    }
    pub(super) fn blob(&self) -> &[u8] {
        &self.blob
    }
    /// `(distinct arrays, arrays written, arrays deduplicated, arrays left inline, blob bytes)`
    pub(super) fn stats(&self) -> (usize, usize, usize, usize, usize) {
        (self.index.len(), self.stored, self.deduped, self.inline, self.blob.len())
    }
    /// Append one array's bytes, or reuse an identical array already stored,
    /// and write the JSON reference that names it.
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

/// A base-field array: the store when it is on and the array is large, the
/// classic decimal list otherwise.
fn fp_array(out: &mut Vec<u8>, st: &mut ArrayStore, v: &[Fp]) {
    if st.on && v.len() >= ARRAY_MIN {
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

/// An extension-field array, the same rule. Sixteen bytes an entry, `c0`
/// then `c1`, each a little-endian `u64`.
fn fp2_array(out: &mut Vec<u8>, st: &mut ArrayStore, v: &[Fp2]) {
    if st.on && v.len() >= ARRAY_MIN {
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

struct StageRec {
    k: usize,
    segment_bytes: usize,
    segment_sha256: String,
    start_tag: [u8; 32],
    end_tag: Option<[u8; 32]>,
    b_root: Option<Digest>,
    a_root: Digest,
    h_root: Digest,
    mask_root: Digest,
    logup: Vec<Fp2>,
    begin: Transcript,
    definition: Option<Transcript>,
    arguments: Vec<Vec<u8>>,
    mask: Option<Vec<u8>>,
    roles: Vec<Vec<u8>>,
    /// the roles this stage actually opened, in transcript order: `A`, `H`,
    /// `Input`, and `Output` only in the last stage
    role_names: Vec<&'static str>,
    sites: Vec<Vec<u8>>,
    layout_digest: Digest,
    a_rows: usize,
    h_rows: usize,
    /// TOKEN I/O (round 7): `"BLOCK"` (every stage of a block run), or
    /// `"IN"` / `"BLOCK"` / `"OUT"` in a token run
    kind: &'static str,
    /// how many slot transcripts close this stage (23 for a block stage, the
    /// stage schedule's count for IN / OUT)
    want_slots: usize,
    /// TOKEN I/O: a new stage's plane table (IN / OUT only)
    planes: Option<TokenPlanes>,
    /// TOKEN I/O: the stage's own public word (`pb-run-block`) and the
    /// boundary it commits (token numbering), for the token stage writer
    public_digest: Digest,
    b_facts: Option<BoundaryFacts>,
    log_cols: usize,
}

struct Rec {
    header: RunHeader,
    binding: Digest,
    /// the recorder's OWN transcript, seeded from the header and advanced only
    /// by replaying the verifier's steps on the recorded public data
    own: Transcript,
    stages: Vec<Vec<u8>>,
    boundaries: Vec<Vec<u8>>,
    cur: Option<StageRec>,
    closed: usize,
    failure: Option<String>,
    /// **STAGE 15.** The plane index table, built from the FIRST stage's
    /// layout and re-built and compared at every later stage, so that
    /// `run.json`'s one copy is a statement about every stage of the run.
    index: Option<PlaneIndex>,
    index_json: Vec<u8>,
    /// **STAGE 27.** The binary side store for the large homogeneous arrays,
    /// held in memory until the run is accepted.
    store: ArrayStore,
    /// **STAGE 27.** Whether a public table carries its values, taken once.
    public_tables: bool,
}

thread_local! {
    static REC: RefCell<Option<Rec>> = const { RefCell::new(None) };
}

/// The attached recorder. Dropping it detaches, on every path.
pub(super) struct Recorder;

impl Recorder {
    /// Attach a recorder for ONE run. Panics if one is already attached: a
    /// nested capture would interleave two runs' transcripts.
    pub(super) fn attach() -> Recorder {
        REC.with(|s| {
            assert!(s.borrow().is_none(), "a run recorder is already attached");
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

// ---------------------------------------------------------------- hooks

/// **THE RUN HEADER, REBUILT INDEPENDENTLY.** The recorder's own transcript is
/// seeded from the statement's public words — in the order `RunStatement`
/// absorbs them — and its state is compared with the verifier's binding. A
/// header the recorder cannot rebuild is a capture that never starts.
pub(super) fn begin_run(header: RunHeader, binding: Digest) {
    begin_run_with(header, binding, CaptureOpts::from_env())
}

/// The same, with both capture choices stated outright instead of read from
/// the environment — so a test can capture one run BOTH ways in one process
/// without touching a process-global.
pub(super) fn begin_run_with(header: RunHeader, binding: Digest, opts: CaptureOpts) {
    REC.with(|s| {
        let mut cell = s.borrow_mut();
        assert!(cell.is_none(), "a run recorder is already seeded");
        // STAGE 17 (ruling T-1): the recorder rebuilds the header under the
        // SAME hash tag the run used, derived from the statement's own shape.
        // A recorder on the legacy rule would fail the binding comparison
        // below at every tagged profile, which is exactly the check that
        // proves the rebuild is the verifier's.
        let mut tr = super::protocol::tagged_transcript(&header.sh, header.profile.as_bytes());
        let mut shape_bytes = Vec::with_capacity(header.run_shape_words.len() * 8);
        for v in &header.run_shape_words {
            shape_bytes.extend_from_slice(&v.to_le_bytes());
        }
        tr.absorb(b"run-shape", &shape_bytes);
        tr.absorb(b"expected-IO", &header.expected_bytes);
        tr.absorb(b"public-statement", &header.public_statement);
        tr.absorb(b"parameters", header.parameter_line.as_bytes());
        tr.absorb(b"calibration", &header.calibration);
        tr.absorb(b"schedule", &header.schedule_digest);
        // ROUND 12: a classifier run's header absorbs its public verdict and
        // its chunk last (`ClassifyRunStatement::transcript`); the binding
        // comparison below then re-checks the whole classifier header
        if let Some(cf) = &header.classify {
            tr.absorb(b"classify-verdict", &[cf.verdict]);
            tr.absorb(b"classify-chunk", &cf.chunk_bytes());
        }
        let mut r = Rec { header, binding, own: tr, stages: Vec::new(), boundaries: Vec::new(), cur: None, closed: 0, failure: None, index: None, index_json: Vec::new(), store: ArrayStore::new(opts.arrays), public_tables: opts.public_tables };
        if r.own.state() != r.binding {
            fail(&mut r, "replay: the rebuilt run header is not the verifier's binding".into());
        }
        *cell = Some(r);
    });
}

pub(super) fn active() -> bool {
    REC.with(|s| s.borrow().is_some())
}

/// TOKEN I/O (round 7): what the attached recorder holds — `(closed stages,
/// a stage open, the first failure)` — so a test can show that a path
/// recorded nothing; `None` without a recorder
pub(super) fn recorded() -> Option<(usize, bool, Option<String>)> {
    REC.with(|s| s.borrow().as_ref().map(|r| (r.closed, r.cur.is_some(), r.failure.clone())))
}

/// A stage opens: the decoded segment's roots and framing, and the verifier's
/// transcript BEFORE the stage's two locality words are absorbed.
#[allow(clippy::too_many_arguments)]
pub(super) fn stage_begin(k: usize, bytes: &[u8], start_tag: [u8; 32], b_root: Option<Digest>, a_root: Digest, h_root: Digest, mask_root: Digest, lay: &Layout, tr: &Transcript) {
    with(|r| {
        if r.cur.is_some() {
            fail(r, format!("replay: stage {k} opened while another stage is open"));
            return;
        }
        if k != r.closed {
            fail(r, format!("replay: stage {k} was offered after {} closed stages", r.closed));
            return;
        }
        at(r, &format!("the start of stage {k}"), tr);
        // **STAGE 15: the plane index table.** Built from THIS stage's layout
        // and compared, byte for byte as it will be written, with the one
        // `run.json` carries. A stage whose plane numbering differed would be
        // refused here rather than mis-described by a single copy.
        match plane_index::build(lay) {
            Ok(idx) => {
                let json = idx.render();
                if r.index.is_none() {
                    r.index = Some(idx);
                    r.index_json = json;
                } else if json != r.index_json {
                    fail(r, format!("replay: stage {k}'s plane index is not the run's"));
                    return;
                }
            }
            Err(e) => {
                fail(r, format!("replay: the plane index does not build at stage {k}: {e}"));
                return;
            }
        }
        r.cur = Some(StageRec {
            k,
            segment_bytes: bytes.len(),
            segment_sha256: crate::export_v3::sha256_hex(bytes),
            start_tag,
            end_tag: None,
            b_root,
            a_root,
            h_root,
            mask_root,
            logup: Vec::new(),
            begin: Transcript::clone_state(tr),
            definition: None,
            arguments: Vec::new(),
            mask: None,
            roles: Vec::new(),
            role_names: Vec::new(),
            sites: Vec::new(),
            layout_digest: lay.schedule_digest(),
            a_rows: lay.a_rows,
            h_rows: lay.h_rows,
            kind: "BLOCK",
            want_slots: N_SLOTS,
            planes: None,
            public_digest: [0; 32],
            b_facts: None,
            log_cols: 0,
        });
        // The stage prefix, replayed from the recorder's own transcript: the
        // two locality words, the boundary root if this stage commits one, the
        // A and M roots, the three LogUp challenges and the H root.
        let sh = r.header.sh.clone();
        let (a_rows, h_rows) = (lay.a_rows, lay.h_rows);
        let boundary = r.cur.as_ref().and_then(|c| c.b_root);
        let digest = r.header.block_digests[k];
        r.own.absorb_u64(b"pb-run-stage", k as u64);
        r.own.absorb(b"pb-run-block", &digest);
        if let Some(root) = boundary {
            let facts = r.header.boundaries[k].clone();
            r.own.absorb(b"B", &root);
            r.own.absorb_u64(b"rows", facts.rows as u64);
            r.own.absorb_u64(b"log-cols", facts.log_n as u64);
        }
        r.own.absorb(b"A", &a_root);
        r.own.absorb_u64(b"rows", a_rows as u64);
        r.own.absorb_u64(b"log-cols", sh.log_cols as u64);
        r.own.absorb(b"M", &mask_root);
        let logup = r.own.challenge_fp2_vec(3);
        r.own.absorb(b"H", &h_root);
        r.own.absorb_u64(b"rows", h_rows as u64);
        r.own.absorb_u64(b"log-cols", sh.log_cols as u64);
        if let Some(c) = r.cur.as_mut() {
            c.logup = logup;
        }
    });
}

/// **TOKEN I/O (round 7): how many stages a run's bundle closes** — `L` for a
/// block run, `L + 2` (stage IN, the blocks, stage OUT) for a token-I/O run.
fn stages_total(h: &RunHeader) -> usize {
    // ROUND 12: a classifier run closes IN-C, the blocks and OUT-C
    if h.classify.is_some() {
        return h.l + 2;
    }
    if h.token.is_some() {
        h.l + 2
    } else {
        h.l
    }
}

/// **TOKEN I/O (round 7; capture request 2.1(b)): a stage of a TOKEN-I/O run
/// opens** — stage IN (`k = 0`), block `k - 1`'s stage (`k = 1 ..= L`) or
/// stage OUT (`k = L + 1`). The hook fires where `RunVerifier::step` fires
/// [`stage_begin`]: after the segment is decoded and before the stage's two
/// locality words are absorbed. The recorder replays the stage prefix from
/// its OWN transcript, from the token statement's public facts and the
/// stage's layout (the three orders are `stage_in::verify`,
/// `verify_token_run_with`'s block loop and `stage_out::verify`):
///
/// * IN: `pb-run-stage 0`, `pb-run-block` = the embedding digest, `B_in`
///   (root, rows, log-cols), `A` (root, rows, log-cols at the stage row
///   width), `M`, three LogUp challenges and `clog2(d_pad)` `r_emb`
///   coordinates, `H`;
/// * BLOCK: `pb-run-stage k`, `pb-run-block` = block `k - 1`'s digest, the
///   boundary it commits (`B_k` in token numbering; `B_out` for the last
///   block), then exactly a block run's `A`, `M`, three challenges, `H`;
/// * OUT: `pb-run-stage L + 1`, `pb-run-block` = the head digest, `A`, `M`,
///   two LogUp challenges, `H` (no boundary commitment: `B_out` was
///   committed by the last block).
#[allow(clippy::too_many_arguments)]
pub(super) fn stage_begin_stage(k: usize, kind: &'static str, bytes: &[u8], start_tag: [u8; 32], b_root: Option<Digest>, a_root: Digest, h_root: Digest, mask_root: Digest, planes: StagePlanes<'_>, tr: &Transcript) {
    with(|r| {
        if r.failure.is_some() {
            return;
        }
        // ROUND 12: a classifier run's stages (IN-C, the blocks, OUT-C)
        if r.header.classify.is_some() {
            classify_stage_begin(r, k, kind, bytes, start_tag, b_root, a_root, h_root, mask_root, &planes, tr);
            return;
        }
        let Some(tf) = r.header.token.clone() else {
            fail(r, format!("replay: stage {k} ({kind}) was offered as a token-run stage, but the header is a block run's"));
            return;
        };
        if r.cur.is_some() {
            fail(r, format!("replay: stage {k} opened while another stage is open"));
            return;
        }
        if k != r.closed {
            fail(r, format!("replay: stage {k} was offered after {} closed stages", r.closed));
            return;
        }
        let l = r.header.l;
        let want_kind = if k == 0 {
            "IN"
        } else if k == l + 1 {
            "OUT"
        } else {
            "BLOCK"
        };
        if kind != want_kind || k > l + 1 {
            fail(r, format!("replay: stage {k} was offered as {kind}; a token run's stage {k} is {want_kind}"));
            return;
        }
        at(r, &format!("the start of stage {k} ({kind})"), tr);
        if r.failure.is_some() {
            return;
        }
        let (digest, b_facts) = match kind {
            "IN" => (tf.emb_digest, Some(tf.boundaries[0].clone())),
            "OUT" => (tf.head_digest, None),
            _ => (r.header.block_digests[k - 1], Some(tf.boundaries[k].clone())),
        };
        if b_facts.is_some() != b_root.is_some() {
            fail(r, format!("replay: stage {k} ({kind})'s boundary root is not what the token run schedule declares"));
            return;
        }
        let (a_rows, h_rows, log_cols, want_slots, layout_digest, token_planes) = match &planes {
            StagePlanes::Block(lay) => {
                match plane_index::build(lay) {
                    Ok(idx) => {
                        let json = idx.render();
                        if r.index.is_none() {
                            r.index = Some(idx);
                            r.index_json = json;
                        } else if json != r.index_json {
                            fail(r, format!("replay: stage {k}'s plane index is not the run's"));
                            return;
                        }
                    }
                    Err(e) => {
                        fail(r, format!("replay: the plane index does not build at stage {k}: {e}"));
                        return;
                    }
                }
                (lay.a_rows, lay.h_rows, r.header.sh.log_cols, N_SLOTS, lay.schedule_digest(), None)
            }
            StagePlanes::Stage { lay, a_names, h_names, roles } => {
                let tp = match TokenPlanes::build(lay, a_names, h_names, *roles) {
                    Ok(t) => t,
                    Err(e) => {
                        fail(r, format!("replay: stage {k}'s plane table does not build: {e}"));
                        return;
                    }
                };
                let digest: Digest = {
                    use sha2::Digest as _;
                    sha2::Sha256::digest(lay.describe().join("\n").as_bytes()).into()
                };
                (lay.a_rows, lay.h_rows, lay.log_n, lay.sched.slots.len(), digest, Some(tp))
            }
        };
        r.cur = Some(StageRec {
            k,
            segment_bytes: bytes.len(),
            segment_sha256: crate::export_v3::sha256_hex(bytes),
            start_tag,
            end_tag: None,
            b_root,
            a_root,
            h_root,
            mask_root,
            logup: Vec::new(),
            begin: Transcript::clone_state(tr),
            definition: None,
            arguments: Vec::new(),
            mask: None,
            roles: Vec::new(),
            role_names: Vec::new(),
            sites: Vec::new(),
            layout_digest,
            a_rows,
            h_rows,
            kind,
            want_slots,
            planes: token_planes,
            public_digest: digest,
            b_facts: b_facts.clone(),
            log_cols,
        });
        r.own.absorb_u64(b"pb-run-stage", k as u64);
        r.own.absorb(b"pb-run-block", &digest);
        if let (Some(root), Some(facts)) = (b_root, b_facts.as_ref()) {
            r.own.absorb(b"B", &root);
            r.own.absorb_u64(b"rows", facts.rows as u64);
            r.own.absorb_u64(b"log-cols", facts.log_n as u64);
        }
        r.own.absorb(b"A", &a_root);
        r.own.absorb_u64(b"rows", a_rows as u64);
        r.own.absorb_u64(b"log-cols", log_cols as u64);
        r.own.absorb(b"M", &mask_root);
        let draws = match kind {
            "IN" => 3 + tf.r_emb_len,
            "OUT" => 2,
            _ => 3,
        };
        let logup = r.own.challenge_fp2_vec(draws);
        r.own.absorb(b"H", &h_root);
        r.own.absorb_u64(b"rows", h_rows as u64);
        r.own.absorb_u64(b"log-cols", log_cols as u64);
        if let Some(c) = r.cur.as_mut() {
            c.logup = logup;
        }
    });
}

/// **ROUND 12 (gate round 16, capture request 2.1(b)): a stage of a
/// CLASSIFIER run opens** — stage IN-C (`k = 0`), block `k - 1`'s stage or
/// stage OUT-C (`k = L + 1`), where the token run opens its stages. The
/// recorder replays the stage prefix from its OWN transcript (the orders are
/// `stage_in_c::verify`, `verify_classify_run_with`'s block loop and
/// `stage_out_c::verify`):
///
/// * IN-C: `pb-run-stage 0`, `pb-run-block` = the embedding digest, `B_in`,
///   `A`, `M`, three LogUp challenges and `clog2(d_pad)` `r_emb`, `H`;
/// * BLOCK: as in a token run;
/// * OUT-C: `pb-run-stage L + 1`, `pb-run-block` = the MARGIN VECTOR's
///   digest, `A`, `M`, two challenges, `H` (no boundary commitment).
#[allow(clippy::too_many_arguments)]
fn classify_stage_begin(r: &mut Rec, k: usize, kind: &'static str, bytes: &[u8], start_tag: [u8; 32], b_root: Option<Digest>, a_root: Digest, h_root: Digest, mask_root: Digest, planes: &StagePlanes<'_>, tr: &Transcript) {
    let Some(cf) = r.header.classify.clone() else {
        fail(r, format!("replay: stage {k} ({kind}) was offered as a classifier-run stage, but the header is not a classifier run's"));
        return;
    };
    if r.cur.is_some() {
        fail(r, format!("replay: stage {k} opened while another stage is open"));
        return;
    }
    if k != r.closed {
        fail(r, format!("replay: stage {k} was offered after {} closed stages", r.closed));
        return;
    }
    let l = r.header.l;
    let want_kind = if k == 0 {
        "IN-C"
    } else if k == l + 1 {
        "OUT-C"
    } else {
        "BLOCK"
    };
    if kind != want_kind || k > l + 1 {
        fail(r, format!("replay: stage {k} was offered as {kind}; a classifier run's stage {k} is {want_kind}"));
        return;
    }
    at(r, &format!("the start of stage {k} ({kind})"), tr);
    if r.failure.is_some() {
        return;
    }
    let (digest, b_facts) = match kind {
        "IN-C" => (cf.emb_digest, Some(cf.boundaries[0].clone())),
        "OUT-C" => (cf.w_digest, None),
        _ => (r.header.block_digests[k - 1], Some(cf.boundaries[k].clone())),
    };
    if b_facts.is_some() != b_root.is_some() {
        fail(r, format!("replay: stage {k} ({kind})'s boundary root is not what the classifier run schedule declares"));
        return;
    }
    let (a_rows, h_rows, log_cols, want_slots, layout_digest, token_planes) = match planes {
        StagePlanes::Block(lay) => {
            match plane_index::build(lay) {
                Ok(idx) => {
                    let json = idx.render();
                    if r.index.is_none() {
                        r.index = Some(idx);
                        r.index_json = json;
                    } else if json != r.index_json {
                        fail(r, format!("replay: stage {k}'s plane index is not the run's"));
                        return;
                    }
                }
                Err(e) => {
                    fail(r, format!("replay: the plane index does not build at stage {k}: {e}"));
                    return;
                }
            }
            (lay.a_rows, lay.h_rows, r.header.sh.log_cols, N_SLOTS, lay.schedule_digest(), None)
        }
        StagePlanes::Stage { lay, a_names, h_names, roles } => {
            let tp = match TokenPlanes::build(lay, a_names, h_names, *roles) {
                Ok(t) => t,
                Err(e) => {
                    fail(r, format!("replay: stage {k}'s plane table does not build: {e}"));
                    return;
                }
            };
            let digest: Digest = {
                use sha2::Digest as _;
                sha2::Sha256::digest(lay.describe().join("\n").as_bytes()).into()
            };
            (lay.a_rows, lay.h_rows, lay.log_n, lay.sched.slots.len(), digest, Some(tp))
        }
    };
    r.cur = Some(StageRec {
        k,
        segment_bytes: bytes.len(),
        segment_sha256: crate::export_v3::sha256_hex(bytes),
        start_tag,
        end_tag: None,
        b_root,
        a_root,
        h_root,
        mask_root,
        logup: Vec::new(),
        begin: Transcript::clone_state(tr),
        definition: None,
        arguments: Vec::new(),
        mask: None,
        roles: Vec::new(),
        role_names: Vec::new(),
        sites: Vec::new(),
        layout_digest,
        a_rows,
        h_rows,
        kind,
        want_slots,
        planes: token_planes,
        public_digest: digest,
        b_facts: b_facts.clone(),
        log_cols,
    });
    r.own.absorb_u64(b"pb-run-stage", k as u64);
    r.own.absorb(b"pb-run-block", &digest);
    if let (Some(root), Some(facts)) = (b_root, b_facts.as_ref()) {
        r.own.absorb(b"B", &root);
        r.own.absorb_u64(b"rows", facts.rows as u64);
        r.own.absorb_u64(b"log-cols", facts.log_n as u64);
    }
    r.own.absorb(b"A", &a_root);
    r.own.absorb_u64(b"rows", a_rows as u64);
    r.own.absorb_u64(b"log-cols", log_cols as u64);
    r.own.absorb(b"M", &mask_root);
    let draws = match kind {
        "IN-C" => 3 + cf.r_emb_len,
        "OUT-C" => 2,
        _ => 3,
    };
    let logup = r.own.challenge_fp2_vec(draws);
    r.own.absorb(b"H", &h_root);
    r.own.absorb_u64(b"rows", h_rows as u64);
    r.own.absorb_u64(b"log-cols", log_cols as u64);
    if let Some(c) = r.cur.as_mut() {
        c.logup = logup;
    }
}

/// **TOKEN I/O (round 7): one slot of stage IN or OUT** (capture request
/// 2.1(c)), replayed and recorded exactly as [`slot`] does a block slot —
/// the definition's draws to the verifier's position, `pb-slot`, the CFS
/// challenge, the published scalar (plus the hosted scalars), the masked
/// sumcheck, the terminals — at the slot's DECLARED `(main, extension,
/// degree)` from the stage schedule. Its record has the block slot's keys:
/// every table with its kind; a private table's role (the stage's own role
/// names), claim index, slices and coordinates, a FIXED coordinate written
/// as `{"fixed": value}` (stage IN's challenge-fixed `r_emb` column
/// coordinate on `B_in`, stage OUT's public row bits `T - 1` on `B_out`);
/// every public table's kind, length and SHA-256, and its values when the
/// capture asks for them (`HL_RUN_CAPTURE_PUBLIC_TABLES=1`). Each private
/// table must lie on a plane of the stage's table; the slot's plane list is
/// recorded in that table.
#[allow(clippy::too_many_arguments)]
pub(super) fn stage_slot(def: &super::token_io::StageSlotDef, spec: &super::token_io::SlotSpec, acc: &Acc, proof: &SlotProof, rho: &[Fp2], c: Fp2, mask_eval: Fp2, before: Option<Transcript>, after: &Transcript) {
    let Some(before) = before else { return };
    with(|r| {
        if r.failure.is_some() || r.cur.is_none() {
            return;
        }
        let s = def.slot;
        {
            let cur = r.cur.as_ref().expect("an open stage");
            if cur.planes.is_none() {
                fail(r, format!("replay: a stage slot {s} arrived in a block stage"));
                return;
            }
            if s != cur.arguments.len() {
                fail(r, format!("replay: slot {s} arrived out of order"));
                return;
            }
        }
        let definition = match r.cur.as_mut().expect("an open stage").definition.take() {
            Some(d) => d,
            None => {
                fail(r, format!("replay: slot {s} has no definition checkpoint"));
                return;
            }
        };
        at(r, &format!("slot {s}'s definition"), &definition);
        if r.failure.is_some() {
            return;
        }
        let mut draws = Vec::new();
        while !same_transcript(&r.own, &before) {
            if draws.len() >= 256 {
                fail(r, format!("replay: slot {s}'s definition changed its transcript operations"));
                return;
            }
            draws.push(r.own.challenge_fp2());
        }
        let (n, ext, degree) = (spec.main, spec.ext, spec.degree);
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
        // every private table on a plane of the stage's table, in push order
        let observed: Result<Vec<(usize, Option<usize>)>, String> = {
            let planes = r.cur.as_ref().and_then(|c| c.planes.as_ref()).expect("a stage table");
            def.tabs
                .iter()
                .filter_map(|t| match t {
                    Tab::Priv(p) => Some((p.cm as usize, p.slices.first().map(|(o, _)| *o).unwrap_or(usize::MAX))),
                    _ => None,
                })
                .map(|(cm, off)| planes.locate(cm, off).ok_or_else(|| format!("replay: slot {s} reads role {cm} at offset {off}, which is on no plane of the stage's table")))
                .collect()
        };
        let observed = match observed {
            Ok(v) => v,
            Err(e) => {
                fail(r, e);
                return;
            }
        };
        let roles = r.cur.as_ref().and_then(|c| c.planes.as_ref()).map(|p| p.roles).expect("a stage table");
        let mut out = Vec::new();
        write!(
            out,
            "{{\"slot\":{s},\"name\":{:?},\"kind\":\"{:?}\",\"main\":{n},\"extension\":{ext},\"degree\":{degree},\"definition_challenges\":{:?},\"c\":{:?},\"scalar\":{:?},\"claimed_sum\":{:?},\"rho\":{:?},\"sumcheck_final\":{:?},\"mask_eval\":{:?},\"terminal_polynomial\":{:?},\"terminals\":{:?},\"rounds\":{:?},\"hosted\":[",
            spec.name,
            spec.kind,
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
                    let role = roles[v.cm as usize];
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
        let cur = r.cur.as_mut().expect("an open stage");
        if let Some(p) = cur.planes.as_mut() {
            p.slots.push(observed);
        }
        cur.arguments.push(out);
    });
}

/// A checkpoint of the verifier's transcript, taken only when a recorder is
/// attached. Handing back `None` is what makes every hook a no-op.
pub(super) fn checkpoint(tr: &Transcript) -> Option<Transcript> {
    REC.with(|s| s.borrow().is_some().then(|| Transcript::clone_state(tr)))
}

/// The transcript before a slot's DEFINITION draws its challenges.
pub(super) fn start_slot(side: &Side, tr: &Transcript) {
    if !matches!(side, Side::Verify { .. }) {
        return;
    }
    with(|r| {
        if let Some(c) = r.cur.as_mut() {
            c.definition = Some(Transcript::clone_state(tr));
        }
    });
}

/// One slot's masked sumcheck, exactly as `native_capture.rs` records it, at
/// THIS stage's shape (the slot's `(main, extension, degree)` comes from the
/// definition's own shape, never from the toy's `SLOTS` literal).
#[allow(clippy::too_many_arguments)]
pub(super) fn slot(def: &SlotDef, acc: &Acc, proof: &SlotProof, rho: &[Fp2], c: Fp2, mask_eval: Fp2, before: Option<Transcript>, after: &Transcript) {
    let Some(before) = before else { return };
    with(|r| {
        if r.failure.is_some() || r.cur.is_none() {
            return;
        }
        let s = def.slot;
        {
            let cur = r.cur.as_ref().expect("an open stage");
            if s != cur.arguments.len() {
                fail(r, format!("replay: slot {s} arrived out of order"));
                return;
            }
        }
        let definition = match r.cur.as_mut().expect("an open stage").definition.take() {
            Some(d) => d,
            None => {
                fail(r, format!("replay: slot {s} has no definition checkpoint"));
                return;
            }
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
        // **STAGE 15: THE PLANE INDEX TABLE, TIED TO THIS SLOT.** The slot's
        // private tables, in the order the prover pushed them, located in the
        // table by role and slice offset and compared with the table's own
        // independent derivation of the same order. `run.json` states the
        // order once; this is what makes that one statement true of every
        // slot of every stage. A mismatch refuses the capture.
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
                    let role = ["A", "H", "Input", "Output"][v.cm as usize];
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
        let k = r.cur.as_ref().expect("an open stage").k;
        site(r, &format!("slot {s:02}"), &definition, after);
        let _ = k;
        r.cur.as_mut().expect("an open stage").arguments.push(out);
    });
}

/// The masking commitment's ONE opening.
pub(super) fn mask(specs: &[(usize, usize)], root: &Digest, fs: &[MaskFunctional], op: &MaskOpening, ntt: &NttTables, before: Option<Transcript>, after: &Transcript) {
    let Some(before) = before else { return };
    with(|r| {
        if r.failure.is_some() || r.cur.is_none() {
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
        let tag = r.header.sh.hash_tag();
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
        let cur = r.cur.as_mut().expect("an open stage");
        if cur.mask.replace(out).is_some() {
            fail(r, "replay: two M openings in one stage".into());
        }
    });
}

/// ONE hiding commitment's ONE opening: `A`, `H`, an external endpoint or an
/// internal boundary. The geometry is the caller's, from its own statement.
pub(super) fn pcs(g: Geom, claims: &[ZClaim], opening: &OpeningZk, ntt: &NttTables, before: Option<Transcript>, after: &Transcript) {
    let Some(before) = before else { return };
    with(|r| {
        if r.failure.is_some() || r.cur.is_none() {
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
        let tag = r.header.sh.hash_tag();
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
        let cur = r.cur.as_mut().expect("an open stage");
        cur.roles.push(out);
        cur.role_names.push(g.role);
    });
}

/// A stage closes: the segment trailer the verifier compared.
pub(super) fn stage_end(k: usize, end_tag: [u8; 32], tr: &Transcript) {
    with(|r| {
        if r.failure.is_some() {
            return;
        }
        at(r, &format!("the end of stage {k}"), tr);
        let Some(mut cur) = r.cur.take() else {
            fail(r, format!("replay: stage {k} closed with no stage open"));
            return;
        };
        if cur.k != k {
            fail(r, format!("replay: stage {} closed as stage {k}", cur.k));
            return;
        }
        if cur.arguments.len() != cur.want_slots || cur.mask.is_none() {
            fail(r, format!("replay: stage {k} closed with {} slots and {} mask openings", cur.arguments.len(), usize::from(cur.mask.is_some())));
            return;
        }
        cur.end_tag = Some(end_tag);
        // ROUND 12: a classifier run's stage file
        if r.header.classify.is_some() {
            let blob = write_stage_classify(r, &cur);
            r.stages.push(blob);
            r.closed += 1;
            return;
        }
        let blob = if r.header.token.is_some() { write_stage_token(r, &cur) } else { write_stage(r, &cur) };
        r.stages.push(blob);
        r.closed += 1;
    });
}

/// The run's closing check passed. Only after this can a bundle be taken.
pub(super) fn run_accepted() {
    with(|r| {
        let want = stages_total(&r.header);
        if r.closed != want {
            fail(r, format!("replay: the run closed after {} of {} stages", r.closed, want));
        }
    });
}

/// A finished bundle: the run file, the per-stage files and the pins. Taking
/// one REQUIRES an accepted run with `L` closed stages and no replay failure.
pub(super) struct Bundle {
    pub run_json: Vec<u8>,
    pub stages: Vec<Vec<u8>>,
    pub profile: String,
    pub l: usize,
    /// **STAGE 27.** The bundle's `arrays.bin`, empty under the `/4-run`
    /// encoding.
    pub arrays: ArrayStore,
    /// TOKEN I/O (round 7): a token-I/O run's bundle (`L + 2` stage files)
    pub token: bool,
}

pub(super) fn take() -> Result<Bundle, String> {
    let r = REC.with(|s| s.borrow_mut().take());
    let mut r = r.ok_or("run capture: no recorder is attached")?;
    if let Some(e) = r.failure.take() {
        return Err(e);
    }
    if r.closed != stages_total(&r.header) {
        return Err(format!("run capture: {} of {} stages closed; no bundle is written for a run the verifier did not accept", r.closed, stages_total(&r.header)));
    }
    if r.cur.is_some() {
        return Err("run capture: a stage is still open".into());
    }
    if r.index.is_none() || r.index_json.is_empty() {
        return Err("run capture: no plane index table was built; no bundle is written without one".into());
    }
    // ROUND 12: a classifier run's bundle (`L + 2` stage files like a token
    // run's, its own run file and schema)
    if r.header.classify.is_some() {
        let run_json = write_run_classify(&r);
        return Ok(Bundle { run_json, stages: r.stages, profile: r.header.profile.to_string(), l: r.header.l, arrays: r.store, token: true });
    }
    let run_json = if r.header.token.is_some() { write_run_token(&r) } else { write_run(&r) };
    let token = r.header.token.is_some();
    Ok(Bundle { run_json, stages: r.stages, profile: r.header.profile.to_string(), l: r.header.l, arrays: r.store, token })
}

/// Detach and discard, whatever state the recorder is in. A rejected run must
/// never leave a partial capture behind.
pub(super) fn discard() {
    REC.with(|s| *s.borrow_mut() = None);
}

// ---------------------------------------------------------------- the ordered site index

/// One entry of the run-wide transcript order: where the verifier was, what it
/// was doing, and the transcript position before and after. The fine-grained
/// challenges live inside the object the site names.
fn site(r: &mut Rec, name: &str, before: &Transcript, after: &Transcript) {
    let Some(cur) = r.cur.as_mut() else { return };
    let mut out = Vec::new();
    write!(out, "{{\"stage\":{},\"site\":{name:?},", cur.k).expect("write to a Vec");
    state(&mut out, "before", before);
    write!(out, ",").expect("write to a Vec");
    state(&mut out, "after", after);
    write!(out, "}}").expect("write to a Vec");
    cur.sites.push(out);
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

fn columns(out: &mut Vec<u8>, st: &mut ArrayStore, cols: &[(usize, Vec<Fp>, [u8; 32], Vec<[u8; 32]>)]) {
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

/// A PUBLIC table of a slot. It is a function of the public statement and the
/// stage's challenges, so a bundle carries its LENGTH and its SHA-256 always
/// and its values only when `HL_RUN_CAPTURE_PUBLIC_TABLES=1` — at the
/// development rung the values of the twenty-three slots' public cubes are the
/// largest thing in a bundle by a wide margin, and the Python side can rebuild
/// any of them from the statement it already has.
fn write_public_table(out: &mut Vec<u8>, st: &mut ArrayStore, v: &[Fp2], values: bool) {
    let mut bytes = Vec::with_capacity(v.len() * 16);
    for x in v {
        bytes.extend_from_slice(&x.to_bytes());
    }
    write!(out, "{{\"kind\":\"public\",\"len\":{},\"sha256\":{:?}", v.len(), crate::export_v3::sha256_hex(&bytes)).expect("write to a Vec");
    if values {
        write!(out, ",\"values\":").expect("write to a Vec");
        // **STAGE 27.** The bytes are already here and they are exactly the
        // ones the `sha256` above is taken over, so a stored public table's
        // `array` digest and its `sha256` are the SAME string — the one place
        // in a bundle where a reader can check the store against a field the
        // classic encoding already carried.
        if st.on && v.len() >= ARRAY_MIN {
            st.put(out, "fp2", v.len(), &bytes);
        } else {
            st.inline += 1;
            write!(out, "{:?}", fp2s(v)).expect("write to a Vec");
        }
    }
    write!(out, "}}").expect("write to a Vec");
}

pub(super) fn public_tables_wanted() -> bool {
    std::env::var("HL_RUN_CAPTURE_PUBLIC_TABLES").map(|v| v == "1").unwrap_or(false)
}

pub(super) fn segments_wanted() -> bool {
    std::env::var("HL_RUN_CAPTURE_SEGMENTS").map(|v| v == "1").unwrap_or(false)
}

#[allow(clippy::too_many_arguments)]
fn write_pcs(out: &mut Vec<u8>, st: &mut ArrayStore, g: &Geom, claims: &[ZClaim], opening: &OpeningZk, r: &Replayed, before: &Transcript, after: &Transcript) {
    write!(
        out,
        "{{\"role\":{:?},\"commitment_kind\":{:?},\"params\":{{\"log_cols\":{},\"inv_rate\":{},\"num_col_checks\":{}}},\"commitment\":{{\"root\":{:?},\"rows\":{}}},\"data_rows\":{},\"site_rows\":{:?},\"prox_row\":{},\"sum_rows\":{},\"boundary\":{},\"claim_sources\":[",
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
        match g.boundary {
            Some(b) => b.to_string(),
            None => "null".into(),
        }
    )
    .expect("write to a Vec");
    for (i, (stage, slot, count)) in g.claim_sources.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{{\"stage\":{stage},\"slot\":{slot},\"claims\":{count}}}").expect("write to a Vec");
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

/// The row vocabulary, stated once. `"data"` carries plane or witness words,
/// `"mask"` a uniformly random row (the reserved claim pairs, `H`'s two
/// zero-sum rows and any spare mask row), `"prox"` the proximity pair.
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

fn write_stage(r: &Rec, cur: &StageRec) -> Vec<u8> {
    let mut out = Vec::new();
    let sh = &r.header.sh;
    let schema = schema_of(r.store.is_on());
    write!(
        out,
        "{{\"schema\":{schema:?},\"kind\":\"zk60-run-stage-observations\",\"stage\":{},\"blocks\":{},\"block_digest\":{:?},\"segment_bytes\":{},\"segment_sha256\":{:?},\"start_tag\":{:?},\"end_tag\":{:?},\"boundary_committed\":{},\"a_root\":{:?},\"a_rows\":{},\"h_root\":{:?},\"h_rows\":{},\"mask_root\":{:?},\"log_cols\":{},\"logup_challenges\":{:?},\"layout_digest\":{:?},\"opening_order\":{},",
        cur.k,
        r.header.l,
        r.header.block_digests[cur.k],
        cur.segment_bytes,
        cur.segment_sha256,
        cur.start_tag,
        cur.end_tag.expect("a closed stage has a trailer"),
        match (cur.k + 1 < r.header.l, cur.b_root) {
            (true, Some(root)) => format!("{{\"boundary\":{},\"root\":{root:?},\"rows\":{},\"log_cols\":{}}}", cur.k, r.header.boundaries[cur.k].rows, r.header.boundaries[cur.k].log_n),
            _ => "null".into(),
        },
        cur.a_root,
        cur.a_rows,
        cur.h_root,
        cur.h_rows,
        cur.mask_root,
        sh.log_cols,
        fp2s(&cur.logup),
        cur.layout_digest,
        {
            let mut order: Vec<String> = vec!["M".into()];
            order.extend(cur.role_names.iter().map(|s| s.to_string()));
            format!("{order:?}")
        }
    )
    .expect("write to a Vec");
    state(&mut out, "header", &cur.begin);
    write!(out, ",\"arguments\":").expect("write to a Vec");
    array(&mut out, &cur.arguments);
    write!(out, ",\"mask\":").expect("write to a Vec");
    out.write_all(cur.mask.as_ref().expect("a closed stage has an M opening")).expect("write to a Vec");
    write!(out, ",\"roles\":").expect("write to a Vec");
    array(&mut out, &cur.roles);
    write!(out, ",\"transcript_sites\":").expect("write to a Vec");
    array(&mut out, &cur.sites);
    writeln!(out, "}}").expect("write to a Vec");
    out
}

/// **STAGE 17.** The run file's `hash_tag` member (ruling T-1): the NAME of
/// the rule, and, for a tagged profile, the profile string, the four context
/// strings and the four derived keys as hex. Every one of those is a public
/// function of public strings; no secret and no witness quantity is in it,
/// and a reader that does not know the key re-derives it.
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

fn write_run(r: &Rec) -> Vec<u8> {
    let h = &r.header;
    let sh = &h.sh;
    let mut out = Vec::new();
    let schema = schema_of(r.store.is_on());
    write!(
        out,
        "{{\"schema\":{schema:?},\"kind\":\"zk60-run-verifier-observations\",\"coverage\":\"native-run-all-stages-v1\",\"profile\":{:?},\"transcript_domain\":{:?},\"block_profile\":{:?},\"blocks\":{},\"boundaries\":{},\"fully_verified\":true,\"privacy\":\"P1\",\"privacy_review_complete\":false,\"weight_policy\":\"public-statement\",\"field_modulus\":{},\"extension_nonresidue\":{},\"public_tables_included\":{},\"source_commit\":{:?},\"run_binding\":{:?},\"context\":{:?},\"calibration\":{:?},\"public_statement_digest\":{:?},\"parameter_line\":{:?},\"schedule_digest\":{:?},\"expected_policy\":{:?},\"expected_policy_sha256\":{:?},\"run_shape_words\":{:?},\"shape\":{{\"name\":{:?},\"profile\":{:?},\"tokens\":{},\"width\":{},\"hidden\":{},\"q_heads\":{},\"kv_heads\":{},\"head_dim\":{},\"t_pad\":{},\"d_pad\":{},\"h_pad\":{},\"f_pad\":{},\"log_cols\":{},\"cols\":{},\"inv_rate\":{},\"opened_cols\":{},\"f_e\":{},\"endpoint_rows\":{},\"endpoint_log_n\":{},\"endpoint_inv_rate\":{},\"endpoint_general\":{},\"norm_wrho\":{},\"wrho_s\":{},\"slots\":{:?},\"a_groups\":{},\"h_groups\":{},\"n_slots\":{N_SLOTS}}},",
        h.profile,
        h.profile,
        sh.profile,
        h.l,
        h.boundaries.len(),
        crate::field::P,
        crate::field::NONRESIDUE,
        r.public_tables,
        std::env::var("HL_TEST_SOURCE_COMMIT").unwrap_or_else(|_| "uncommitted-test".into()),
        r.binding,
        h.context,
        h.calibration,
        h.public_statement,
        h.parameter_line,
        h.schedule_digest,
        h.expected_bytes,
        crate::export_v3::sha256_hex(&h.expected_bytes),
        h.run_shape_words,
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
    write!(
        out,
        "\"external_endpoints\":{{\"input_root\":{:?},\"output_root\":{:?},\"rows\":{},\"data_rows\":{},\"log_n\":{},\"inv_rate\":{},\"input_scale\":{},\"output_scale\":{},\"opened_at_stage\":[0,{}]}},\"block_digests\":[",
        h.external_input_root,
        h.external_output_root,
        h.external_rows,
        h.external_data_rows,
        h.external_log_n,
        h.external_inv_rate,
        h.external_scales.0,
        h.external_scales.1,
        h.l - 1
    )
    .expect("write to a Vec");
    for (i, d) in h.block_digests.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{d:?}").expect("write to a Vec");
    }
    write!(out, "],\"internal_boundaries\":[").expect("write to a Vec");
    for (i, b) in h.boundaries.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(
            out,
            "{{\"boundary\":{},\"index\":{},\"scale\":{},\"sites\":{},\"plane\":[{},{}],\"data_rows\":{},\"rows\":{},\"site_rows\":{:?},\"prox_row\":{},\"log_n\":{},\"inv_rate\":{},\"checks\":{},\"statement_digest\":{:?},\"row_rule\":\"data + 2*sites + 2\",\"committed_at_stage\":{},\"opened_at_stage\":{},\"claim_sites\":[{{\"site\":0,\"stage\":{},\"slot\":22,\"first_row\":{}}},{{\"site\":1,\"stage\":{},\"slot\":21,\"first_row\":{}}}],\"opening_in_stage_file\":{}}}",
            i,
            b.index,
            b.scale,
            b.sites,
            b.plane.0,
            b.plane.1,
            b.data_rows,
            b.rows,
            b.site_rows,
            b.prox_row,
            b.log_n,
            b.inv_rate,
            b.checks,
            b.digest,
            i,
            i + 1,
            i,
            b.site_rows.first().copied().unwrap_or(0),
            i + 1,
            b.site_rows.get(2).copied().unwrap_or(0),
            i + 1
        )
        .expect("write to a Vec");
    }
    write!(out, "],\"boundary_scales\":{:?},\"stage_lines\":", h.boundary_scales).expect("write to a Vec");
    strings(&mut out, &h.stage_lines);
    write!(out, ",\"layout_description\":").expect("write to a Vec");
    strings(&mut out, &h.layout_description);
    write!(out, ",\"stage_files\":[").expect("write to a Vec");
    for k in 0..h.l {
        if k > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{:?}", stage_file(k)).expect("write to a Vec");
    }
    write!(out, "],\"transcript_domain_bytes\":{:?},", h.profile.as_bytes()).expect("write to a Vec");
    // **STAGE 17, ruling T-1 / T-7.** WHICH HASH RULE MADE THIS BUNDLE. The
    // four keys are public functions of public strings, so the hex is here
    // for cross-checking — but the Python tools re-derive them from the
    // contexts and the profile and compare, and nothing in a capture ever
    // SELECTS a rule or hands a key to a verifier. A legacy-rule bundle
    // carries `{"rule":"legacy"}` and nothing else.
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
    // **STAGE 15.** The plane index table: a property of the SHAPE, so it
    // lives in the run file and not in a stage. `take` refuses a bundle
    // without one, and `stage_begin` has compared it with every stage's.
    out.write_all(&r.index_json).expect("write to a Vec");
    write!(out, ",\"not_in_a_capture\":[\"witness values\",\"pad values\",\"mask coefficients\",\"unopened columns\",\"unpublished salts\",\"unmasked sumcheck rounds\",\"hidden inputs, outputs and boundary planes\",\"prover randomness\"]").expect("write to a Vec");
    writeln!(out, "}}").expect("write to a Vec");
    out
}

/// **EVERY FIAT-SHAMIR LABEL OF A RUN, as data.** The Python side hard-codes
/// these byte strings today; a bundle carries them so that a run's four NEW
/// labels (`run-shape`, `pb-run-stage`, `pb-run-block`, `B`) do not have to be
/// read out of Rust source.
const TRANSCRIPT_LABELS: [(&str, &str); 19] = [
    ("run-shape", "run header: L and the six shape axes, seven u64 little-endian (NEW in a run)"),
    ("expected-IO", "run header: the endpoint policy bytes"),
    ("public-statement", "run header: H(block 1's digest || ... || block L's digest) (a RUN digest, not a block's)"),
    ("parameters", "run header: the parameter line, as bytes"),
    ("calibration", "run header: the one calibration identity of the whole run"),
    ("schedule", "run header: the run schedule digest (parameter line, layout lines, one stage line per stage)"),
    ("pb-run-stage", "stage k: the stage index, absorb_u64 (NEW in a run)"),
    ("pb-run-block", "stage k: block k's public digest (NEW in a run)"),
    ("B", "stage k: the boundary commitment root this stage commits, then rows and log-cols (NEW in a run)"),
    ("A", "stage k: the A root, then rows and log-cols"),
    ("M", "stage k: the masking commitment root; the three LogUp challenges follow"),
    ("H", "stage k: the H root, then rows and log-cols"),
    ("rows", "absorb_u64 after every commitment root"),
    ("log-cols", "absorb_u64 after every commitment root's row count"),
    ("pb-slot", "slot s: the slot index, absorb_u64; the CFS challenge c follows"),
    ("pb-scalar", "slot s: the one published masked scalar"),
    ("pb-term", "slot s: the masked terminals, after the sumcheck"),
    ("mask-q", "the M opening: theta is drawn first, then q is absorbed, then 2*slots+2 proximity challenges"),
    ("mask-prox", "the M opening: the proximity vector; the 256 column indices follow"),
];

/// The transcript, in words, from the first byte of a run to the last.
const TRANSCRIPT_PROGRAM: [&str; 10] = [
    "STAGE 17 (D19): every hash below is BLAKE3 under the rule named in hash_tag. Legacy = the unkeyed blake3::Hasher::new(); blake3-keyed/1 = keyed mode under the four derived keys, the transcript one here and the column / leaf / node ones inside every commitment.",
    "Transcript::new(profile bytes) — Transcript::new_tagged under the keyed rule — then absorb run-shape, expected-IO, public-statement, parameters, calibration, schedule. The state here is run_binding.",
    "For each stage k = 0 .. L-1, in order:",
    "  absorb pb-run-stage(k), pb-run-block(block_digests[k]); if k+1 < L absorb B(root), rows, log-cols of boundary k.",
    "  absorb A(root), rows, log-cols; absorb M(mask root); draw 3 Fp2 (the LogUp challenges); absorb H(root), rows, log-cols.",
    "  For each slot s = 0 .. 22: draw the definition challenges; absorb pb-slot(s); draw c; absorb pb-scalar; per sumcheck round absorb sc-round then draw one Fp2; absorb pb-term(terminals).",
    "  The M opening: draw theta; absorb mask-q(q); draw 2*slots+2 Fp2; absorb mask-prox(prox); draw 256 column indices over 2^log_dom.",
    "  Then one PCS opening per role in opening_order after M: per group draw |members| lambdas, then draw `rows` proximity coefficients, then absorb pcs-vec per group, absorb pcs-prox, then draw num_col_checks column indices over cols*inv_rate.",
    "  Stage k's IO openings are: the Input role (the external input endpoint at k = 0, otherwise boundary k-1, whose claim list is complete only now) and, only at k = L-1, the Output role (the external output endpoint).",
    "  The segment header and trailer tags are COMPARED against the verifier's own transcript position and are outside the Fiat-Shamir chain.",
];

/// **TOKEN I/O (round 7; capture request 2.1(e)): the schema a token-I/O run's
/// bundle declares.** A NEW schema beside `/4-run` and `/5-run`: a loader that
/// knows only block runs refuses it by version rather than mis-read stage IN
/// as block 0. Every member a block bundle has keeps its name and meaning;
/// the token members are new keys on [`ALLOWED_KEYS`]. Large arrays may live
/// in `arrays.bin` exactly as under `/5-run` (`"array_store"` says which).
pub(super) const SCHEMA_TOKEN: &str = "hashline-native-capture/6-token-run";

fn write_boundary_facts(out: &mut Vec<u8>, b: &BoundaryFacts) {
    write!(
        out,
        "{{\"index\":{},\"scale\":{},\"sites\":{},\"plane\":[{},{}],\"data_rows\":{},\"rows\":{},\"site_rows\":{:?},\"prox_row\":{},\"log_n\":{},\"inv_rate\":{},\"checks\":{},\"statement_digest\":{:?}}}",
        b.index, b.scale, b.sites, b.plane.0, b.plane.1, b.data_rows, b.rows, b.site_rows, b.prox_row, b.log_n, b.inv_rate, b.checks, b.digest
    )
    .expect("write to a Vec");
}

fn write_endpoint_facts(out: &mut Vec<u8>, e: &TokenEndpointFacts) {
    write!(
        out,
        "{{\"rows\":{},\"data_rows\":{},\"sites\":{},\"site_rows\":{:?},\"prox_row\":{},\"log_n\":{},\"inv_rate\":{},\"checks\":{},\"plane\":[{},{}],\"scale\":{},\"statement_digest\":{:?}}}",
        e.rows, e.data_rows, e.sites, e.site_rows, e.prox_row, e.log_n, e.inv_rate, e.checks, e.plane.0, e.plane.1, e.scale, e.digest
    )
    .expect("write to a Vec");
}

/// TOKEN I/O (round 7): a stage file of a token-I/O run. The block stage
/// file's members, with the stage's kind, its own public word, the
/// boundary it commits in TOKEN numbering, its row width, and for IN / OUT
/// the stage's plane table.
fn write_stage_token(r: &Rec, cur: &StageRec) -> Vec<u8> {
    let mut out = Vec::new();
    let (named, extra): (usize, &str) = match cur.kind {
        "IN" => (3, "r_emb"),
        "OUT" => (2, ""),
        _ => (3, ""),
    };
    write!(
        out,
        "{{\"schema\":{SCHEMA_TOKEN:?},\"kind\":\"zk60-run-stage-observations\",\"stage\":{},\"stage_kind\":{:?},\"blocks\":{},\"stages\":{},\"block_digest\":{:?},\"segment_bytes\":{},\"segment_sha256\":{:?},\"start_tag\":{:?},\"end_tag\":{:?},\"boundary_committed\":{},\"a_root\":{:?},\"a_rows\":{},\"h_root\":{:?},\"h_rows\":{},\"mask_root\":{:?},\"log_cols\":{},\"logup_challenges\":{:?},\"r_emb\":{:?},\"layout_digest\":{:?},\"opening_order\":{},",
        cur.k,
        cur.kind,
        r.header.l,
        stages_total(&r.header),
        cur.public_digest,
        cur.segment_bytes,
        cur.segment_sha256,
        cur.start_tag,
        cur.end_tag.expect("a closed stage has a trailer"),
        match (&cur.b_facts, cur.b_root) {
            (Some(f), Some(root)) => format!("{{\"boundary\":{},\"root\":{root:?},\"rows\":{},\"log_cols\":{}}}", f.index, f.rows, f.log_n),
            _ => "null".into(),
        },
        cur.a_root,
        cur.a_rows,
        cur.h_root,
        cur.h_rows,
        cur.mask_root,
        cur.log_cols,
        fp2s(&cur.logup[..named.min(cur.logup.len())]),
        if extra.is_empty() { Vec::new() } else { fp2s(&cur.logup[named.min(cur.logup.len())..]) },
        cur.layout_digest,
        {
            let mut order: Vec<String> = vec!["M".into()];
            order.extend(cur.role_names.iter().map(|s| s.to_string()));
            format!("{order:?}")
        }
    )
    .expect("write to a Vec");
    state(&mut out, "header", &cur.begin);
    write!(out, ",\"arguments\":").expect("write to a Vec");
    array(&mut out, &cur.arguments);
    write!(out, ",\"mask\":").expect("write to a Vec");
    out.write_all(cur.mask.as_ref().expect("a closed stage has an M opening")).expect("write to a Vec");
    write!(out, ",\"roles\":").expect("write to a Vec");
    array(&mut out, &cur.roles);
    write!(out, ",\"transcript_sites\":").expect("write to a Vec");
    array(&mut out, &cur.sites);
    if let Some(p) = &cur.planes {
        write!(out, ",").expect("write to a Vec");
        out.write_all(&p.render()).expect("write to a Vec");
    }
    writeln!(out, "}}").expect("write to a Vec");
    out
}

/// TOKEN I/O (round 7): the transcript of a token-I/O run, in words (the
/// block run's program with the two new stages around the blocks).
const TRANSCRIPT_PROGRAM_TOKEN: [&str; 12] = [
    "STAGE 17 (D19): every hash below is BLAKE3 under the rule named in hash_tag (the token profiles are tagged).",
    "Transcript::new_tagged(token run profile bytes), then absorb run-shape (EIGHT u64: L, T, width, hidden, q_heads, kv_heads, head_dim, V), expected-IO (the two token endpoint specs and roots), public-statement, parameters (the token profile line), calibration (the trained-model identity), schedule. The state here is run_binding.",
    "Stage 0 (IN): absorb pb-run-stage(0), pb-run-block(the embedding digest), B(B_in root), rows, log-cols; A(root), rows, log-cols at the stage row width; M(mask root); draw 3 Fp2 (beta, gamma, alpha) and clog2(d_pad) Fp2 (r_emb); absorb H(root), rows, log-cols.",
    "  Its slots IN-00 .. IN-03 as a block slot (definition draws; pb-slot; c; pb-scalar; masked rounds; pb-term); then the M opening, the A-in and H-in openings, and the input token endpoint (E-token-in).",
    "Stage k = 1 .. L (block k-1): absorb pb-run-stage(k), pb-run-block(block_digests[k-1]), B(root of boundary k: B_k, or B_out at k = L), rows, log-cols; then exactly a block run's stage (A, M, 3 challenges, H, 23 slots, M, A, H).",
    "  Then the Input role: boundary k-1 in token numbering (B_in at k = 1), whose claim list is complete only now (the previous stage's outgoing claims, then this block's incoming).",
    "Stage L+1 (OUT): absorb pb-run-stage(L+1), pb-run-block(the head digest); A, rows, log-cols; M; draw 2 Fp2 (gamma, alpha); H, rows, log-cols.",
    "  Its slots OUT-00 .. OUT-10; then the M opening, A-out, H-out, B-out (the last block's outgoing claims, then OUT-00's), and the output token endpoint (E-token-out).",
    "The M opening and every PCS opening are a block run's (mask-q, mask-prox; per group lambdas, proximity coefficients, pcs-vec, pcs-prox, column indices).",
    "The segment header and trailer tags are COMPARED against the verifier's own transcript position and are outside the Fiat-Shamir chain.",
    "Owner decommitments (the input / output token planes, their pads and salts) are never read by a verifier and are never in a capture.",
    "Mode (ii) (hidden length) and the P / F selector variants are not built.",
];

/// TOKEN I/O (round 7; capture request 2.1(a)): the run file of a token-I/O
/// run. The block run file's header members, the shape and the block
/// digests, plus `"token_io"` (the token facts), the boundaries in token
/// numbering, `L + 2` stage files and the token transcript program.
fn write_run_token(r: &Rec) -> Vec<u8> {
    let h = &r.header;
    let sh = &h.sh;
    let tf = h.token.as_ref().expect("a token header");
    let mut out = Vec::new();
    write!(
        out,
        "{{\"schema\":{SCHEMA_TOKEN:?},\"kind\":\"zk60-run-verifier-observations\",\"coverage\":\"token-run-all-stages-v1\",\"array_store\":{},\"profile\":{:?},\"transcript_domain\":{:?},\"block_profile\":{:?},\"blocks\":{},\"stages\":{},\"boundaries\":{},\"fully_verified\":true,\"privacy\":\"P1\",\"privacy_review_complete\":false,\"weight_policy\":\"public-statement\",\"field_modulus\":{},\"extension_nonresidue\":{},\"public_tables_included\":{},\"source_commit\":{:?},\"run_binding\":{:?},\"context\":{:?},\"calibration\":{:?},\"public_statement_digest\":{:?},\"parameter_line\":{:?},\"schedule_digest\":{:?},\"expected_policy\":{:?},\"expected_policy_sha256\":{:?},\"run_shape_words\":{:?},\"shape\":{{\"name\":{:?},\"profile\":{:?},\"tokens\":{},\"width\":{},\"hidden\":{},\"q_heads\":{},\"kv_heads\":{},\"head_dim\":{},\"t_pad\":{},\"d_pad\":{},\"h_pad\":{},\"f_pad\":{},\"log_cols\":{},\"cols\":{},\"inv_rate\":{},\"opened_cols\":{},\"f_e\":{},\"endpoint_rows\":{},\"endpoint_log_n\":{},\"endpoint_inv_rate\":{},\"endpoint_general\":{},\"norm_wrho\":{},\"wrho_s\":{},\"slots\":{:?},\"a_groups\":{},\"h_groups\":{},\"n_slots\":{N_SLOTS}}},",
        r.store.is_on(),
        h.profile,
        h.profile,
        sh.profile,
        h.l,
        stages_total(h),
        tf.boundaries.len(),
        crate::field::P,
        crate::field::NONRESIDUE,
        r.public_tables,
        std::env::var("HL_TEST_SOURCE_COMMIT").unwrap_or_else(|_| "uncommitted-test".into()),
        r.binding,
        h.context,
        h.calibration,
        h.public_statement,
        h.parameter_line,
        h.schedule_digest,
        h.expected_bytes,
        crate::export_v3::sha256_hex(&h.expected_bytes),
        h.run_shape_words,
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
    let (g0, cn, tn, ceps) = tf.final_norm;
    let (tname, tq, tsl, tsr, tel, ter) = tf.tier;
    write!(
        out,
        "\"token_io\":{{\"run_profile\":{:?},\"V\":{},\"V_pad\":{},\"T\":{},\"t_pad\":{},\"d\":{},\"d_pad\":{},\"variant\":{:?},\"mode\":{:?},\"limbs\":{},\"window_bits\":{},\"mult_bits\":{},\"embedding_digest\":{:?},\"head_digest\":{:?},\"bos\":{},\"final_norm\":{{\"g0\":{g0},\"cn\":{cn},\"tn\":{tn},\"ceps\":{ceps}}},\"s_in\":{},\"s_out\":{},\"tier\":{{\"name\":{tname:?},\"opened_cols\":{tq},\"stage_log_n\":{tsl},\"stage_inv_rate\":{tsr},\"ep_log_n\":{tel},\"ep_inv_rate\":{ter}}},\"r_emb_len\":{},\"input_endpoint\":",
        tf.run_profile, tf.v, tf.v_pad, tf.tokens, tf.t_pad, tf.d, tf.d_pad, tf.variant, tf.mode, tf.limbs, tf.window_bits, tf.mult_bits, tf.emb_digest, tf.head_digest, tf.bos, tf.scales.0, tf.scales.1, tf.r_emb_len
    )
    .expect("write to a Vec");
    write_endpoint_facts(&mut out, &tf.endpoints[0]);
    write!(out, ",\"output_endpoint\":").expect("write to a Vec");
    write_endpoint_facts(&mut out, &tf.endpoints[1]);
    write!(out, ",\"input_root\":{:?},\"output_root\":{:?},\"b_in\":", tf.input_root, tf.output_root).expect("write to a Vec");
    write_boundary_facts(&mut out, &tf.boundaries[0]);
    write!(out, ",\"b_out\":").expect("write to a Vec");
    write_boundary_facts(&mut out, &tf.boundaries[tf.boundaries.len() - 1]);
    write!(out, ",\"input_endpoint_opened_at_stage\":0,\"output_endpoint_opened_at_stage\":{},\"stage_in_layout\":", h.l + 1).expect("write to a Vec");
    strings(&mut out, &tf.stage_layouts[0]);
    write!(out, ",\"stage_out_layout\":").expect("write to a Vec");
    strings(&mut out, &tf.stage_layouts[1]);
    write!(out, "}},\"block_digests\":[").expect("write to a Vec");
    for (i, d) in h.block_digests.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{d:?}").expect("write to a Vec");
    }
    write!(out, "],\"token_boundaries\":[").expect("write to a Vec");
    for (i, b) in tf.boundaries.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        let name = if i == 0 {
            "B_in".to_string()
        } else if i + 1 == tf.boundaries.len() {
            "B_out".to_string()
        } else {
            format!("B_{i}")
        };
        write!(out, "{{\"boundary\":{i},\"name\":{name:?},\"committed_at_stage\":{i},\"opened_at_stage\":{},\"facts\":", i + 1).expect("write to a Vec");
        write_boundary_facts(&mut out, b);
        write!(out, "}}").expect("write to a Vec");
    }
    write!(out, "],\"boundary_scales\":{:?},\"stage_lines\":", h.boundary_scales).expect("write to a Vec");
    strings(&mut out, &h.stage_lines);
    write!(out, ",\"layout_description\":").expect("write to a Vec");
    strings(&mut out, &h.layout_description);
    write!(out, ",\"stage_files\":[").expect("write to a Vec");
    for k in 0..stages_total(h) {
        if k > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{:?}", stage_file(k)).expect("write to a Vec");
    }
    write!(out, "],\"transcript_domain_bytes\":{:?},", h.profile.as_bytes()).expect("write to a Vec");
    write_hash_tag(&mut out, sh);
    write!(out, ",\"transcript_labels\":[").expect("write to a Vec");
    for (i, (label, what)) in TRANSCRIPT_LABELS.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{{\"label\":{label:?},\"what\":{what:?}}}").expect("write to a Vec");
    }
    write!(out, "],\"transcript_program\":").expect("write to a Vec");
    strings(&mut out, &TRANSCRIPT_PROGRAM_TOKEN.iter().map(|s| s.to_string()).collect::<Vec<_>>());
    write!(out, ",\"mask_domain\":{{\"log_dom\":{},\"columns\":{}}},", crate::zk::MASK_LOG_DOM, sh.opened_cols).expect("write to a Vec");
    out.write_all(&r.index_json).expect("write to a Vec");
    write!(out, ",\"not_in_a_capture\":[\"witness values\",\"pad values\",\"mask coefficients\",\"unopened columns\",\"unpublished salts\",\"unmasked sumcheck rounds\",\"hidden inputs, outputs and boundary planes\",\"prover randomness\",\"the prompt's token ids and the next token\",\"owner decommitments\"]").expect("write to a Vec");
    writeln!(out, "}}").expect("write to a Vec");
    out
}

// ---------------------------------------------------------------- ROUND 12: classifier runs

/// **ROUND 12 (gate round 16, capture request 2.1(e)): the schema a
/// classifier run's bundle declares**, beside `/6-token-run`: a loader that
/// knows only token runs refuses it by version. Every member a token bundle
/// has keeps its name and meaning; `"classify"` replaces `"token_io"`, there
/// is no output endpoint, and the new keys are on [`ALLOWED_KEYS`].
pub(super) const SCHEMA_CLASSIFY: &str = "hashline-native-capture/7-classify-run";

/// the classifier sources a classifier bundle pins in addition to the
/// shared list (appended to `source_pins`, for classifier bundles only)
const CLASSIFY_SOURCE_FILES: [&str; 4] = ["src/private_block/token_io/classify.rs", "src/private_block/token_io/classify_run.rs", "src/private_block/token_io/stage_in_c.rs", "src/private_block/token_io/stage_out_c.rs"];

/// a bundle of a classifier run (its run profile is a classifier run profile)
pub(super) fn bundle_is_classify(b: &Bundle) -> bool {
    super::run::CLASSIFY_RUN_PROFILES.contains(&b.profile.as_str())
}

fn classify_source_pins(mut pins: Vec<(String, String)>) -> Result<Vec<(String, String)>, String> {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    for name in CLASSIFY_SOURCE_FILES {
        let path = root.join(name);
        let bytes = std::fs::read(&path).map_err(|e| format!("run capture: source pin {}: {e}", path.display()))?;
        pins.push((name.to_string(), crate::export_v3::sha256_hex(&bytes)));
    }
    Ok(pins)
}

/// a stage file of a classifier run: the token stage file's members, the
/// stage kinds IN-C / BLOCK / OUT-C, its own schema
fn write_stage_classify(r: &Rec, cur: &StageRec) -> Vec<u8> {
    let mut out = Vec::new();
    let (named, extra): (usize, &str) = match cur.kind {
        "IN-C" => (3, "r_emb"),
        "OUT-C" => (2, ""),
        _ => (3, ""),
    };
    write!(
        out,
        "{{\"schema\":{SCHEMA_CLASSIFY:?},\"kind\":\"zk60-run-stage-observations\",\"stage\":{},\"stage_kind\":{:?},\"blocks\":{},\"stages\":{},\"block_digest\":{:?},\"segment_bytes\":{},\"segment_sha256\":{:?},\"start_tag\":{:?},\"end_tag\":{:?},\"boundary_committed\":{},\"a_root\":{:?},\"a_rows\":{},\"h_root\":{:?},\"h_rows\":{},\"mask_root\":{:?},\"log_cols\":{},\"logup_challenges\":{:?},\"r_emb\":{:?},\"layout_digest\":{:?},\"opening_order\":{},",
        cur.k,
        cur.kind,
        r.header.l,
        stages_total(&r.header),
        cur.public_digest,
        cur.segment_bytes,
        cur.segment_sha256,
        cur.start_tag,
        cur.end_tag.expect("a closed stage has a trailer"),
        match (&cur.b_facts, cur.b_root) {
            (Some(f), Some(root)) => format!("{{\"boundary\":{},\"root\":{root:?},\"rows\":{},\"log_cols\":{}}}", f.index, f.rows, f.log_n),
            _ => "null".into(),
        },
        cur.a_root,
        cur.a_rows,
        cur.h_root,
        cur.h_rows,
        cur.mask_root,
        cur.log_cols,
        fp2s(&cur.logup[..named.min(cur.logup.len())]),
        if extra.is_empty() { Vec::new() } else { fp2s(&cur.logup[named.min(cur.logup.len())..]) },
        cur.layout_digest,
        {
            let mut order: Vec<String> = vec!["M".into()];
            order.extend(cur.role_names.iter().map(|s| s.to_string()));
            format!("{order:?}")
        }
    )
    .expect("write to a Vec");
    state(&mut out, "header", &cur.begin);
    write!(out, ",\"arguments\":").expect("write to a Vec");
    array(&mut out, &cur.arguments);
    write!(out, ",\"mask\":").expect("write to a Vec");
    out.write_all(cur.mask.as_ref().expect("a closed stage has an M opening")).expect("write to a Vec");
    write!(out, ",\"roles\":").expect("write to a Vec");
    array(&mut out, &cur.roles);
    write!(out, ",\"transcript_sites\":").expect("write to a Vec");
    array(&mut out, &cur.sites);
    if let Some(p) = &cur.planes {
        write!(out, ",").expect("write to a Vec");
        out.write_all(&p.render()).expect("write to a Vec");
    }
    writeln!(out, "}}").expect("write to a Vec");
    out
}

/// the classifier header's two labels after `schedule` (its last absorbs)
const TRANSCRIPT_LABELS_CLASSIFY: [(&str, &str); 2] = [
    ("classify-verdict", "run header: the PUBLIC verdict bit b (1 = flagged: margin > c), one byte; absorbed after schedule"),
    ("classify-chunk", "run header: D41's chunk, seven u64 little-endian (index, count, a, b, total, size, overlap); the header's last absorb"),
];

/// the transcript of a classifier run, in words
const TRANSCRIPT_PROGRAM_CLASSIFY: [&str; 12] = [
    "STAGE 17 (D19): every hash below is BLAKE3 under the rule named in hash_tag (the classifier profiles are tagged).",
    "Transcript::new_tagged(classifier run profile bytes), then absorb run-shape (ELEVEN u64: L, T, width, hidden, q_heads, kv_heads, head_dim, V, P0, n, S), expected-IO (the ONE input token endpoint spec and root), public-statement, parameters (the classifier profile line), calibration, schedule, classify-verdict (the public verdict bit), classify-chunk (D41's chunk). The state here is run_binding.",
    "Stage 0 (IN-C): absorb pb-run-stage(0), pb-run-block(the embedding digest), B(B_in root), rows, log-cols; A(root), rows, log-cols at the stage row width; M(mask root); draw 3 Fp2 (beta, gamma, alpha) and clog2(d_pad) Fp2 (r_emb); absorb H(root), rows, log-cols.",
    "  Its slots INC-00 .. INC-03 (the query zero-check batches the LogUp, BOS, TEMPLATE and pad clauses, each with a fresh mu); then the M opening, the A-in and H-in openings, and the input token endpoint (E-token-in).",
    "Stage k = 1 .. L (block k-1): absorb pb-run-stage(k), pb-run-block(block_digests[k-1]), B(root of boundary k), rows, log-cols; then exactly a block run's stage (A, M, 3 challenges, H, 23 slots, M, A, H).",
    "  Then the Input role: boundary k-1 in token numbering (B_in at k = 1), whose claim list is complete only now.",
    "Stage L+1 (OUT-C): absorb pb-run-stage(L+1), pb-run-block(the margin vector's digest); A, rows, log-cols; M; draw 2 Fp2 (gamma, alpha); H, rows, log-cols.",
    "  Its slots OUTC-00 .. OUTC-07 (the margin slot PD hosted by LZC with the host term sigma g limb + u0 (sigma b + c)); then the M opening, A-out, H-out and B-out (the last block's outgoing claims, then OUTC-00's). NO output endpoint.",
    "The M opening and every PCS opening are a block run's (mask-q, mask-prox; per group lambdas, proximity coefficients, pcs-vec, pcs-prox, column indices).",
    "The segment header and trailer tags are COMPARED against the verifier's own transcript position and are outside the Fiat-Shamir chain.",
    "The owner's decommitment (the input token plane, its pads and salts) is never read by a verifier and is never in a capture.",
    "The hidden-length variant and the P / F selector variants are not built.",
];

/// **ROUND 12 (gate round 16, capture request 2.1(a)): the run file of a
/// classifier run.** The token run file's header members, `"classify"` (the
/// classifier facts), the boundaries in token numbering, `L + 2` stage files,
/// the labels with the classifier's two and its transcript program.
fn write_run_classify(r: &Rec) -> Vec<u8> {
    let h = &r.header;
    let sh = &h.sh;
    let cf = h.classify.as_ref().expect("a classifier header");
    let mut out = Vec::new();
    write!(
        out,
        "{{\"schema\":{SCHEMA_CLASSIFY:?},\"kind\":\"zk60-run-verifier-observations\",\"coverage\":\"classify-run-all-stages-v1\",\"array_store\":{},\"profile\":{:?},\"transcript_domain\":{:?},\"block_profile\":{:?},\"blocks\":{},\"stages\":{},\"boundaries\":{},\"fully_verified\":true,\"privacy\":\"P1\",\"privacy_review_complete\":false,\"weight_policy\":\"public-statement\",\"field_modulus\":{},\"extension_nonresidue\":{},\"public_tables_included\":{},\"source_commit\":{:?},\"run_binding\":{:?},\"context\":{:?},\"calibration\":{:?},\"public_statement_digest\":{:?},\"parameter_line\":{:?},\"schedule_digest\":{:?},\"expected_policy\":{:?},\"expected_policy_sha256\":{:?},\"run_shape_words\":{:?},\"shape\":{{\"name\":{:?},\"profile\":{:?},\"tokens\":{},\"width\":{},\"hidden\":{},\"q_heads\":{},\"kv_heads\":{},\"head_dim\":{},\"t_pad\":{},\"d_pad\":{},\"h_pad\":{},\"f_pad\":{},\"log_cols\":{},\"cols\":{},\"inv_rate\":{},\"opened_cols\":{},\"f_e\":{},\"endpoint_rows\":{},\"endpoint_log_n\":{},\"endpoint_inv_rate\":{},\"endpoint_general\":{},\"norm_wrho\":{},\"wrho_s\":{},\"slots\":{:?},\"a_groups\":{},\"h_groups\":{},\"n_slots\":{N_SLOTS}}},",
        r.store.is_on(),
        h.profile,
        h.profile,
        sh.profile,
        h.l,
        stages_total(h),
        cf.boundaries.len(),
        crate::field::P,
        crate::field::NONRESIDUE,
        r.public_tables,
        std::env::var("HL_TEST_SOURCE_COMMIT").unwrap_or_else(|_| "uncommitted-test".into()),
        r.binding,
        h.context,
        h.calibration,
        h.public_statement,
        h.parameter_line,
        h.schedule_digest,
        h.expected_bytes,
        crate::export_v3::sha256_hex(&h.expected_bytes),
        h.run_shape_words,
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
    let (g0, cn, tn, ceps) = cf.final_norm;
    let (tname, tq, tsl, tsr, tel, ter) = cf.tier;
    let [ci, cc, ca, cb, ct, cs, co] = cf.chunk;
    write!(
        out,
        "\"classify\":{{\"run_profile\":{:?},\"V\":{},\"V_pad\":{},\"T\":{},\"t_pad\":{},\"d\":{},\"d_pad\":{},\"P0\":{},\"n\":{},\"S\":{},\"profile_text\":{:?},\"profile_digest\":{:?},\"policy\":{{\"id\":{:?},\"prefix_ids\":{:?},\"suffix_ids\":{:?},\"num_special\":{},\"yes\":{},\"no\":{},\"c\":{},\"tokenizer\":{:?},\"template_digest\":{:?}}},\"margin_vector\":{{\"digest\":{:?},\"d\":{}}},\"embedding_digest\":{:?},\"bos\":{},\"final_norm\":{{\"g0\":{g0},\"cn\":{cn},\"tn\":{tn},\"ceps\":{ceps}}},\"wrho\":{},\"d_max\":{},\"margin_window_bits\":{},\"limbs\":{},\"limbs_at_lo_entry\":{},\"s_in\":{},\"tier\":{{\"name\":{tname:?},\"opened_cols\":{tq},\"stage_log_n\":{tsl},\"stage_inv_rate\":{tsr},\"ep_log_n\":{tel},\"ep_inv_rate\":{ter}}},\"r_emb_len\":{},\"verdict\":{},\"chunk\":{{\"index\":{ci},\"count\":{cc},\"a\":{ca},\"b\":{cb},\"total\":{ct},\"size\":{cs},\"overlap\":{co}}},\"input_endpoint\":",
        cf.run_profile,
        cf.v,
        cf.v_pad,
        cf.tokens,
        cf.t_pad,
        cf.d,
        cf.d_pad,
        cf.p0,
        cf.n,
        cf.s,
        cf.profile_text,
        cf.profile_digest,
        cf.policy_id,
        cf.prefix,
        cf.suffix,
        cf.num_special,
        cf.yes,
        cf.no,
        cf.c,
        cf.tokenizer,
        cf.template_digest,
        cf.w_digest,
        cf.d,
        cf.emb_digest,
        cf.bos,
        cf.wrho,
        cf.d_max,
        cf.window_bits,
        cf.limbs,
        cf.lam_base,
        cf.scale,
        cf.r_emb_len,
        cf.verdict
    )
    .expect("write to a Vec");
    write_endpoint_facts(&mut out, &cf.input_endpoint);
    write!(out, ",\"output_endpoint\":null,\"input_root\":{:?},\"b_in\":", cf.input_root).expect("write to a Vec");
    write_boundary_facts(&mut out, &cf.boundaries[0]);
    write!(out, ",\"b_out\":").expect("write to a Vec");
    write_boundary_facts(&mut out, &cf.boundaries[cf.boundaries.len() - 1]);
    write!(out, ",\"input_endpoint_opened_at_stage\":0,\"stage_in_c_layout\":").expect("write to a Vec");
    strings(&mut out, &cf.stage_layouts[0]);
    write!(out, ",\"stage_out_c_layout\":").expect("write to a Vec");
    strings(&mut out, &cf.stage_layouts[1]);
    write!(out, "}},\"block_digests\":[").expect("write to a Vec");
    for (i, d) in h.block_digests.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{d:?}").expect("write to a Vec");
    }
    write!(out, "],\"token_boundaries\":[").expect("write to a Vec");
    for (i, b) in cf.boundaries.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        let name = if i == 0 {
            "B_in".to_string()
        } else if i + 1 == cf.boundaries.len() {
            "B_out".to_string()
        } else {
            format!("B_{i}")
        };
        write!(out, "{{\"boundary\":{i},\"name\":{name:?},\"committed_at_stage\":{i},\"opened_at_stage\":{},\"facts\":", i + 1).expect("write to a Vec");
        write_boundary_facts(&mut out, b);
        write!(out, "}}").expect("write to a Vec");
    }
    write!(out, "],\"boundary_scales\":{:?},\"stage_lines\":", h.boundary_scales).expect("write to a Vec");
    strings(&mut out, &h.stage_lines);
    write!(out, ",\"layout_description\":").expect("write to a Vec");
    strings(&mut out, &h.layout_description);
    write!(out, ",\"stage_files\":[").expect("write to a Vec");
    for k in 0..stages_total(h) {
        if k > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{:?}", stage_file(k)).expect("write to a Vec");
    }
    write!(out, "],\"transcript_domain_bytes\":{:?},", h.profile.as_bytes()).expect("write to a Vec");
    write_hash_tag(&mut out, sh);
    write!(out, ",\"transcript_labels\":[").expect("write to a Vec");
    // the six header labels, the classifier's two (the header's last
    // absorbs), then the stage labels
    let labels: Vec<(&str, &str)> = TRANSCRIPT_LABELS[..6].iter().chain(TRANSCRIPT_LABELS_CLASSIFY.iter()).chain(TRANSCRIPT_LABELS[6..].iter()).copied().collect();
    for (i, (label, what)) in labels.iter().enumerate() {
        if i > 0 {
            write!(out, ",").expect("write to a Vec");
        }
        write!(out, "{{\"label\":{label:?},\"what\":{what:?}}}").expect("write to a Vec");
    }
    write!(out, "],\"transcript_program\":").expect("write to a Vec");
    strings(&mut out, &TRANSCRIPT_PROGRAM_CLASSIFY.iter().map(|s| s.to_string()).collect::<Vec<_>>());
    write!(out, ",\"mask_domain\":{{\"log_dom\":{},\"columns\":{}}},", crate::zk::MASK_LOG_DOM, sh.opened_cols).expect("write to a Vec");
    out.write_all(&r.index_json).expect("write to a Vec");
    write!(out, ",\"not_in_a_capture\":[\"witness values\",\"pad values\",\"mask coefficients\",\"unopened columns\",\"unpublished salts\",\"unmasked sumcheck rounds\",\"hidden inputs, outputs and boundary planes\",\"prover randomness\",\"the content's token ids\",\"the margin, its limbs and the final-norm values\",\"owner decommitments\"]").expect("write to a Vec");
    writeln!(out, "}}").expect("write to a Vec");
    out
}

/// a classifier bundle's README
fn classify_readme(b: &Bundle, note: &str, command: &str, arrays_note: &str, payload: usize) -> String {
    format!(
        "# ZK60 classifier run capture bundle\n\n{note}\n\nWhat this is: the VERIFIER'S VIEW of one private CLASSIFIER run (stage IN-C, {} blocks,\nstage OUT-C) under one transcript, profile `{}`, written by\n`hashline/src/private_block/run_capture.rs` (schema `{SCHEMA_CLASSIFY}`). It is the INPUT to the\nprivacy gate's classifier items (gate round 16) and it is NOT a privacy result: no gate has read it.\n\nWhat made it:\n\n    {command}\n\nFiles: `run.json` (the run header, the shape, `classify` with the classifier facts: the policy,\nc, the margin vector's digest, the PUBLIC verdict and D41's chunk; the boundaries in token\nnumbering: 0 = B_in, L = B_out) and `stage-NN.json` for the {} stages: stage-00 is stage IN-C\n(its slots, M, A-in, H-in and the input token endpoint, and its plane table), stage-01 ..\nstage-{:02} the blocks (each with the Input opening of the boundary before it, B_in at stage-01),\nand the last is stage OUT-C (its slots, M, A-out, H-out and B-out, and its plane table; NO output\nendpoint). Each stage file carries its segment's length and SHA-256. `manifest.json` lists every\nfile with its SHA-256 and pins the source files (the classifier's four included).\n\n{arrays_note}\n\nNOT in this bundle: any prover-side value, the content's token ids, the margin and its limbs,\nand the owner's decommitment (`not_in_a_capture` in `run.json`); every key is on the allow-list.\n\n{payload} bytes of run file, stage files and segments.\n",
        b.l,
        b.profile,
        b.stages.len(),
        b.l
    )
}

pub(super) fn stage_file(k: usize) -> String {
    format!("stage-{k:02}.json")
}

/// **STAGE 27.** The bundle's one binary side file, present only under
/// `/5-run`.
pub(super) const ARRAYS_FILE: &str = "arrays.bin";

// ---------------------------------------------------------------- the PCS grouping replay

/// Adapted from `native_capture.rs`'s replay, generalised over the PCS
/// parameters. Deliberately independent of the private PCS grouping helpers,
/// and it refuses a malformed mapping before ordinary PCS verification.
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

/// **EVERY KEY A BUNDLE MAY CONTAIN.** A retained capture counts as
/// publishing, so the set of fields is declared here and
/// `every_key_of_a_bundle_is_on_the_allow_list` fails if the writer ever emits
/// one that is not on it. Adding a key to this list is the moment to ask
/// whether the quantity behind it is in the verifier's view.
pub(super) const ALLOWED_KEYS: &[&str] = &[
    // run file
    "schema",
    "kind",
    "coverage",
    "profile",
    "transcript_domain",
    "block_profile",
    "blocks",
    "boundaries",
    "fully_verified",
    "privacy",
    "privacy_review_complete",
    "weight_policy",
    "field_modulus",
    "extension_nonresidue",
    "public_tables_included",
    "source_commit",
    "run_binding",
    "context",
    "calibration",
    "public_statement_digest",
    "parameter_line",
    "schedule_digest",
    "expected_policy",
    "expected_policy_sha256",
    "run_shape_words",
    "shape",
    "external_endpoints",
    "block_digests",
    "internal_boundaries",
    "boundary_scales",
    "stage_lines",
    "layout_description",
    "stage_files",
    "transcript_domain_bytes",
    // STAGE 17: which hash rule made this bundle (ruling T-1). Public
    // functions of public strings; no key is ever an input.
    "hash_tag",
    "rule",
    "contexts",
    "keys_hex",
    // the four roles, inside `contexts` and `keys_hex`
    "transcript",
    "column",
    "leaf",
    "node",
    "transcript_labels",
    "transcript_program",
    "mask_domain",
    "label",
    "what",
    "log_dom",
    "not_in_a_capture",
    // STAGE 15: the plane index table. PUBLIC LAYOUT ONLY — a plane's id, its
    // name, its domain and its row range, and the per-slot push order. No
    // plane CONTENT is behind any of these keys.
    "plane_index",
    "a_data_rows",
    "h_data_rows",
    "a_planes",
    "h_planes",
    "id",
    "domain",
    "re_first_row",
    "im_first_row",
    "re_offset",
    "im_offset",
    "slot_planes",
    "planes",
    // shape
    "name",
    "tokens",
    "width",
    "hidden",
    "q_heads",
    "kv_heads",
    "head_dim",
    "t_pad",
    "d_pad",
    "h_pad",
    "f_pad",
    "log_cols",
    "cols",
    "inv_rate",
    "opened_cols",
    "f_e",
    "endpoint_rows",
    "endpoint_log_n",
    "endpoint_inv_rate",
    "endpoint_general",
    "norm_wrho",
    "wrho_s",
    "slots",
    "a_groups",
    "h_groups",
    "n_slots",
    // external endpoints and boundaries
    "input_root",
    "output_root",
    "rows",
    "data_rows",
    "log_n",
    "input_scale",
    "output_scale",
    "opened_at_stage",
    "boundary",
    "index",
    "scale",
    "sites",
    "plane",
    "site_rows",
    "prox_row",
    "checks",
    "statement_digest",
    "row_rule",
    "committed_at_stage",
    "claim_sites",
    "site",
    "stage",
    "slot",
    "first_row",
    "opening_in_stage_file",
    // stage file
    "block_digest",
    "segment_bytes",
    "segment_sha256",
    "start_tag",
    "end_tag",
    "boundary_committed",
    "root",
    "a_root",
    "a_rows",
    "h_root",
    "h_rows",
    "mask_root",
    "logup_challenges",
    "layout_digest",
    "opening_order",
    "header",
    "arguments",
    "mask",
    "roles",
    "transcript_sites",
    // transcript positions
    "before",
    "after",
    "before_definition",
    "state",
    "next",
    // a slot
    "main",
    "extension",
    "degree",
    "definition_challenges",
    "c",
    "scalar",
    "claimed_sum",
    "rho",
    "sumcheck_final",
    "mask_eval",
    "terminal_polynomial",
    "terminals",
    "rounds",
    "hosted",
    "tables",
    "coefficient",
    "start",
    "point",
    "len",
    "sha256",
    "values",
    "role",
    "claim",
    "log_size",
    "mask_row",
    "extension_round",
    "slices",
    "offset",
    "coordinates",
    "flip",
    "fixed",
    // the M opening
    "specs",
    "theta",
    "proximity_rhos",
    "functionals",
    "value",
    "terms",
    "weights",
    "q",
    "prox",
    "columns",
    // a PCS opening
    "commitment_kind",
    "params",
    "num_col_checks",
    "commitment",
    "sum_rows",
    "claim_sources",
    "claims",
    "parts",
    "groups",
    "members",
    "lambdas",
    "key",
    "tail",
    "vector",
    "proximity_vector",
    "q_pad",
    "row_roles",
    "row",
    "public_linear_constraints",
    "relation",
    "source",
    // opened columns
    "salt",
    "path",
    // STAGE 27: an array that lives in `arrays.bin`. PUBLIC BOOK-KEEPING
    // ONLY — the content digest, the element type, the entry count and where
    // the bytes are. The VALUES behind it are the same verifier-view values
    // the classic encoding printed inline; nothing new is published by moving
    // them, and nothing that was not already in a bundle can be referenced.
    // (`offset`, `len`, `bytes` and `sha256` are already on the list above,
    // from the private-table slices, the public tables and the manifest.)
    "array",
    "elem",
    // the manifest
    "file",
    "bytes",
    "source_pins",
    "files",
    "total_bytes",
    // TOKEN I/O (round 7; the gate lane's capture request): the token run
    // file's `token_io` facts, the token boundaries, a token stage file's
    // kind / r_emb / plane table. Every one is a public statement word, a
    // public layout fact or a transcript challenge: no token id, no next
    // token, no activation and no owner decommitment.
    "array_store",
    "stages",
    "token_io",
    "run_profile",
    "V",
    "V_pad",
    "T",
    "d",
    "variant",
    "mode",
    "limbs",
    "window_bits",
    "mult_bits",
    "embedding_digest",
    "head_digest",
    "bos",
    "final_norm",
    "g0",
    "cn",
    "tn",
    "ceps",
    "s_in",
    "s_out",
    "tier",
    "stage_log_n",
    "stage_inv_rate",
    "ep_log_n",
    "ep_inv_rate",
    "r_emb_len",
    "input_endpoint",
    "output_endpoint",
    "b_in",
    "b_out",
    "input_endpoint_opened_at_stage",
    "output_endpoint_opened_at_stage",
    "stage_in_layout",
    "stage_out_layout",
    "token_boundaries",
    "facts",
    "stage_kind",
    "r_emb",
    "stage_plane_index",
    "a_mask_base",
    "a_prox",
    "h_mask_base",
    "h_prox",
    "h_u",
    "h_u_rows",
    "h_sign",
    "sched",
    "hosts",
    "row_log",
    "a_sites",
    "h_sites",
    "io_sites",
    "slot_planes_source",
    // ROUND 12 (gate round 16, capture request 2.1(e)): the classifier run file's new keys
    "classify",
    "P0",
    "n",
    "S",
    "profile_text",
    "profile_digest",
    "policy",
    "prefix_ids",
    "suffix_ids",
    "num_special",
    "yes",
    "no",
    "tokenizer",
    "template_digest",
    "margin_vector",
    "digest",
    "wrho",
    "d_max",
    "margin_window_bits",
    "limbs_at_lo_entry",
    "verdict",
    "chunk",
    "count",
    "a",
    "b",
    "total",
    "size",
    "overlap",
    "stage_in_c_layout",
    "stage_out_c_layout",
];

/// Every JSON object key in `bytes`, in order of appearance. The writer emits
/// no whitespace and escapes every string with Rust's `Debug`, so a key is
/// exactly a quoted string immediately followed by a colon.
pub(super) fn keys_of(bytes: &[u8]) -> Vec<String> {
    let mut out = Vec::new();
    let mut i = 0usize;
    while i < bytes.len() {
        if bytes[i] != b'"' {
            i += 1;
            continue;
        }
        let start = i + 1;
        let mut j = start;
        while j < bytes.len() {
            match bytes[j] {
                b'\\' => j += 2,
                b'"' => break,
                _ => j += 1,
            }
        }
        if j < bytes.len() && j + 1 < bytes.len() && bytes[j + 1] == b':' {
            out.push(String::from_utf8_lossy(&bytes[start..j]).into_owned());
        }
        i = j + 1;
    }
    out
}

// ---------------------------------------------------------------- writing a bundle out

/// Write a bundle to `dir`: the run file, one file per stage, the segments
/// that were verified, a manifest with every file's SHA-256 and the source
/// pins, and a README. The manifest is written LAST, so a directory without
/// one is an incomplete bundle and not an accepted capture.
pub(super) fn write_bundle(dir: &std::path::Path, b: &Bundle, segments: &[Vec<u8>], note: &str, command: &str) -> Result<(), String> {
    std::fs::create_dir_all(dir).map_err(|e| format!("run capture: {}: {e}", dir.display()))?;
    if segments.len() != b.stages.len() {
        return Err(format!("run capture: {} segments for a run of {} stages", segments.len(), b.stages.len()));
    }
    let mut files: Vec<(String, usize, String)> = Vec::new();
    let put = |name: String, bytes: &[u8], files: &mut Vec<(String, usize, String)>| -> Result<(), String> {
        let path = dir.join(&name);
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| format!("run capture: {}: {e}", parent.display()))?;
        }
        let mut f = std::fs::OpenOptions::new().create_new(true).write(true).open(&path).map_err(|e| format!("run capture: {}: {e}", path.display()))?;
        f.write_all(bytes).map_err(|e| format!("run capture: {}: {e}", path.display()))?;
        files.push((name, bytes.len(), crate::export_v3::sha256_hex(bytes)));
        Ok(())
    };
    let schema = if b.token { SCHEMA_TOKEN } else { schema_of(b.arrays.is_on()) };
    // ROUND 12: a classifier run's bundle declares its own schema
    let schema = if bundle_is_classify(b) { SCHEMA_CLASSIFY } else { schema };
    put("run.json".into(), &b.run_json, &mut files)?;
    for (k, s) in b.stages.iter().enumerate() {
        put(stage_file(k), s, &mut files)?;
    }
    // **STAGE 27: the one binary side file.** Every `{"array":...}` reference
    // in the JSON names an offset and a length in it, and the manifest pins
    // the whole file by length and SHA-256 like any other. Under the `/4-run`
    // encoding the store is empty and no such file exists.
    if b.arrays.is_on() {
        put(ARRAYS_FILE.into(), b.arrays.blob(), &mut files)?;
    }
    // **THE SEGMENTS ARE OPT-IN.** They are the receipt, and every stage file
    // already carries its own segment's length and SHA-256, so a bundle
    // without them is still pinned to the exact bytes that were verified. At
    // the development rung they are a third of a bundle, and the privacy
    // gate's loader reads only the JSON (it never opens a receipt), so they
    // are written only when `HL_RUN_CAPTURE_SEGMENTS=1` asks for them.
    if segments_wanted() {
        for (k, s) in segments.iter().enumerate() {
            put(format!("segments/segment-{k:02}.bin"), s, &mut files)?;
        }
    }
    let payload: usize = files.iter().map(|(_, n, _)| n).sum();
    let (distinct, stored, deduped, inline, blob) = b.arrays.stats();
    let arrays_note = if b.arrays.is_on() {
        format!(
            "THE ARRAYS ARE IN `{ARRAYS_FILE}` (schema `{SCHEMA_V5}`). A field-element\narray of at least {ARRAY_MIN} entries is written in the JSON as\n`{{\"array\":\"<sha256>\",\"elem\":\"fp\"|\"fp2\",\"len\":N,\"offset\":O,\"bytes\":B}}` and its\nvalues are the B bytes at offset O of that file, little-endian: eight bytes\nper `fp`, sixteen per `fp2` (`c0` then `c1`). Identical arrays are stored\nONCE and every reference to them names the same offset, which is why the\nshape-only public tables cost one copy for the whole bundle rather than one\nper slot per stage. Here: {stored} references over {distinct} distinct arrays\n({deduped} resolved to an array already stored), {inline} small arrays left\ninline as plain JSON lists, {blob} bytes of `{ARRAYS_FILE}`. Everything else\nis byte for byte what schema `{SCHEMA}` writes."
        )
    } else {
        format!("Every array is an inline JSON list (schema `{SCHEMA}`); this bundle has no `{ARRAYS_FILE}`.")
    };
    let readme = format!(
        "# ZK60 run capture bundle\n\n{note}\n\nWhat this is: the VERIFIER'S VIEW of one private run of {} blocks under one\ntranscript, profile `{}`, written by `hashline/src/private_block/run_capture.rs`\n(schema `{schema}`). It is the INPUT to the privacy gate of ruling M-8 and it\nis NOT a privacy result: no gate has read it.\n\nWhat made it:\n\n    {command}\n\nFiles: `run.json` (the run header, the shape, the external endpoints and the\n{} internal boundaries) and `stage-NN.json` (per stage: the roots, the\ntwenty-three slot transcripts, the M opening, and the A, H and IO openings).\nEach stage file carries its segment's length and SHA-256, so the bundle is\npinned to the exact receipt bytes that were verified; the segments themselves\nare written into `segments/` only when `HL_RUN_CAPTURE_SEGMENTS=1` asks for\nthem, because they are a third of a bundle and the gate reads only the JSON.\n`manifest.json` lists every file with its SHA-256 and pins the source files.\n\n{arrays_note}\n\nNOT in this bundle: any prover-side value. The list is in `run.json` under\n`not_in_a_capture`, and `every_key_of_a_bundle_is_on_the_allow_list` fails if\nthe writer ever emits a field outside its declared allow-list. The weights are\nsynthetic and public; the hidden input came from the lane's fixture generator\nand is not here.\n\n{payload} bytes of run file, stage files and segments.\n",
        b.l,
        b.profile,
        b.l.saturating_sub(1)
    );
    // TOKEN I/O (round 7): a token run's README says what its files are
    let readme = if b.token {
        format!(
            "# ZK60 token-I/O run capture bundle\n\n{note}\n\nWhat this is: the VERIFIER'S VIEW of one private TOKEN-I/O run (stage IN, {} blocks,\nstage OUT) under one transcript, profile `{}`, written by\n`hashline/src/private_block/run_capture.rs` (schema `{SCHEMA_TOKEN}`). It is the INPUT to the\nprivacy gate's token items (DESIGN 4.2, G-1 .. G-7) and it is NOT a privacy result: no gate\nhas read it.\n\nWhat made it:\n\n    {command}\n\nFiles: `run.json` (the run header, the shape, `token_io` with the token facts, the boundaries\nin token numbering: 0 = B_in, L = B_out) and `stage-NN.json` for the {} stages: stage-00 is\nstage IN (its slots, M, A-in, H-in and the input token endpoint, and its plane table),\nstage-01 .. stage-{:02} the blocks (each with the Input opening of the boundary before it,\nB_in at stage-01), and the last is stage OUT (its slots, M, A-out, H-out, B-out and the output\ntoken endpoint, and its plane table). Each stage file carries its segment's length and SHA-256.\n`manifest.json` lists every file with its SHA-256 and pins the source files.\n\n{arrays_note}\n\nNOT in this bundle: any prover-side value, the prompt's token ids, the next token, and the\nowners' decommitments (`not_in_a_capture` in `run.json`); every key is on the allow-list.\n\n{payload} bytes of run file, stage files and segments.\n",
            b.l,
            b.profile,
            b.stages.len(),
            b.l
        )
    } else {
        readme
    };
    let readme = if bundle_is_classify(b) { classify_readme(b, note, command, &arrays_note, payload) } else { readme };
    put("README.md".into(), readme.as_bytes(), &mut files)?;
    let pins = source_pins()?;
    let pins = if bundle_is_classify(b) { classify_source_pins(pins)? } else { pins };
    let mut manifest = Vec::new();
    write!(manifest, "{{\"schema\":{schema:?},\"kind\":\"zk60-run-capture-manifest\",\"profile\":{:?},\"blocks\":{},\"source_commit\":{:?},\"source_pins\":[", b.profile, b.l, std::env::var("HL_TEST_SOURCE_COMMIT").unwrap_or_else(|_| "uncommitted-test".into())).expect("write to a Vec");
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
    let mut f = std::fs::OpenOptions::new().create_new(true).write(true).open(&path).map_err(|e| format!("run capture: {}: {e}", path.display()))?;
    f.write_all(&manifest).map_err(|e| format!("run capture: {}: {e}", path.display()))?;
    Ok(())
}

/// **Every file a bundle pins**: `private_block`'s own path first, in the
/// order stage 24 fixed, then the shared files stage 27 added. The order is
/// part of the format — a reader may index into `source_pins` — so new
/// entries are appended and nothing is re-sorted.
pub(super) fn source_files() -> Vec<&'static str> {
    OWN_SOURCE_FILES.iter().copied().chain(SHARED_SOURCE_FILES.iter().copied()).collect()
}

/// SHA-256 of every source file that decides what a bundle contains.
pub(super) fn source_pins() -> Result<Vec<(String, String)>, String> {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    let mut out = Vec::new();
    for name in source_files() {
        let path = root.join(name);
        let bytes = std::fs::read(&path).map_err(|e| format!("run capture: source pin {}: {e}", path.display()))?;
        out.push((name.to_string(), crate::export_v3::sha256_hex(&bytes)));
    }
    Ok(out)
}
