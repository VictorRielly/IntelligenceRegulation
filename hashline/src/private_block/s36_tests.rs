//! **STAGE 36: THE DRAW-ACCOUNTING TEST OF RULING R-3**, all seven
//! assertions of `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md` §3.1 live.
//!
//! **What was blocked, and what unblocked it.** Stage 25 wrote assertions 5
//! and 7 — the two that need no hook — and left a test whose whole content
//! was that the other five could not be written: `ZkRng`'s four fields are
//! private and the type published no consumption accessor, so "this proof
//! consumed exactly these stream bytes, in these segments" was not a
//! statement any test could make. On 2026-09-22 at 07:25 the integrator
//! authorised the three read-only observers this module uses:
//! `ZkRng::consumed_bytes` / `ZkRng::refills`, `Transcript::squeezes`, and
//! the test observer inside `protocol::check_opening_challenges`.
//!
//! **WHY THE TEST EXISTS (ruling J-5, the check's B-4).** Assertions 1-5
//! are all statements about WHICH SYMBOL each site uses — offsets, ranges,
//! "no clone". Two defects keep every position disjoint and correctly
//! offset and still correlate the realised values: a deterministically
//! seeded generator, and an undeclared relation imposed on drawn values
//! after they are drawn. Assertions 6 and 7 are the two about VALUES, and
//! they are what makes the set worth asserting.
//!
//! **WHAT THIS MODULE MEASURES, AND HOW.** A block proof has THREE
//! generators — the block prover's and one per endpoint — and this module
//! measures each of them:
//!
//! * **the block's, directly.** [`measure_block`] is `prove_inner_at`'s own
//!   body with the generator and the transcript OURS instead of the
//!   function's: the same `Layout`, the same `check_endpoints`, the same
//!   `ZkRng::from_os` on the same seed domain, the same `NttTables`, the
//!   same `transcript`, the same `prove_core`, the same two endpoint
//!   openings, and the receipt it assembles is VERIFIED before any number
//!   is read off. So the stream measured is the stream of a proof that
//!   verifies, and not of a fragment.
//! * **the endpoints', by a replica whose fidelity is a source fact.** The
//!   two endpoint generators are built inside `private_seam::prepare` and
//!   `endpoint_g::prepare`, which take no generator from their caller and
//!   live in files this lane may not edit, so they cannot be handed an
//!   observable one. [`measure_endpoint`] performs the same two draw steps
//!   on a generator of its own, and
//!   [`the_endpoint_replica_is_the_endpoint_preparers_own_draw_sequence`]
//!   reads both production bodies and asserts that those two steps are all
//!   the generator is used for. It is a replica, and the test says so.
//!
//! **THE CAPTURE RULE.** Everything printed here is a COUNT: stream bytes,
//! draws, refills, squeezes, segment offsets. No key, no seed, no stream
//! byte, no challenge and no drawn value is printed, returned or compared.
//! The observer inside `check_opening_challenges` records how many
//! challenges each call drew and which exit it took, and nothing else.
//!
//! **WHAT A GREEN RUN HERE IS, AND IS NOT.** It is the machine assertion
//! ruling R-3 asks for: the prover's randomness accounting is what the
//! privacy argument says it is, at six shapes. It is NOT a privacy result
//! and NOT an acceptance of anything; nothing here says the blinding is
//! sufficient, only that it is drawn where the schedule says, in the
//! quantity the schedule says, from a key nobody chose.

use super::layout::*;
use super::protocol::{self, verify_inner_at};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use crate::field::Fp;
use crate::ntt::NttTables;
use crate::pcs::{self, ZkOpts};
use crate::sumcheck::CfsMask;
use crate::zk::{ZkRng, MASK_LOG_DOM, MASK_LOG_MSG, MASK_Q};

/// 16 stream bytes per field element: `ZkRng::fp` is two `next_u64`s
/// (`zkp-core/src/rng.rs`), and `RNG_BLOCK` is a multiple of 8, so no draw
/// loses a byte to a refill. This is the factor decision D9's 327,052 is
/// multiplied by.
const BYTES_PER_FP: u64 = 16;

/// 32 stream bytes per Merkle salt: `ZkRng::bytes32` is four `next_u64`s.
const BYTES_PER_SALT: u64 = 32;

/// **THE ACCEPTED TOY STATEMENT'S OWN FIGURE.** `fp()` draws per toy proof,
/// over all three generators: `ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` §4
/// (the 2^-77.7 row) and §9 clarification 2, which prints the arithmetic
/// exactly: 327,052 x 2^-96 = 2^-77.68. Reproducing it from the accessor,
/// and not from the memo's table, is the point of this module.
const TOY_FP_DRAWS: u64 = 327_052;

/// **The BLOCK BODY's own share of it** — claim A-5 of
/// `ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md` §1.2, whose table gives
/// 320,908 `fp()` draws, 8,192 salts and 5,396,672 stream bytes at the toy.
const TOY_BLOCK_FP_DRAWS: u64 = 320_908;
const TOY_BLOCK_SALTS: u64 = 8_192;
const TOY_BLOCK_BYTES: u64 = 5_396_672;

/// **The live transcript's squeeze count per toy proof**, row T4a of
/// `ZK60_TOY_ROUTE_A_REEXAMINATION.md` §1.4 [COUNTED there].
const TOY_LIVE_SQUEEZES: u64 = 1_863;

/// **The refusal replay's re-issued points per toy proof**, row T4c of the
/// same table and clarification 9 of the accepted statement: *"the prover's
/// refusal replay re-issues 1,027 of those points per proof with no absorb
/// in between"*.
const TOY_REPLAY_POINTS: u64 = 1_027;

// ---------------------------------------------------------------- the closed form

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum Kind {
    Fp,
    Salt,
}

/// one of the eleven segments of the BLOCK generator's stream
#[derive(Clone, Debug)]
struct Seg {
    what: &'static str,
    kind: Kind,
    count: u64,
    site: &'static str,
}

impl Seg {
    fn bytes(&self) -> u64 {
        self.count
            * match self.kind {
                Kind::Fp => BYTES_PER_FP,
                Kind::Salt => BYTES_PER_SALT,
            }
    }
}

/// **THE ELEVEN SEGMENTS OF A BLOCK BODY, from shape and layout constants
/// only** — claim A-5's table, rebuilt here in Rust rather than imported as
/// a number. Order is the order the prover draws in, which is the order the
/// offsets below are the running sums of:
///
/// `A` mask rows, `A` pads, `A` salts (`commit_zk_owned_tagged`), then `M`'s
/// CFS coefficients, per-row pads, `b`/`u` and salts (`zk::mask_commit_tagged`),
/// then `H`'s mask rows, zero-sum rows, pads and salts.
fn block_segments(sh: &Shape) -> Vec<Seg> {
    let lay = Layout::for_shape(sh).expect("the shape has a layout");
    let params = protocol::pcs_params_at(sh);
    let zko = ZkOpts::standard(&params);
    let n = params.cols() as u64;
    let q = zko.q_pad as u64;
    let nn = params.enc_cols() as u64;
    let m = 1u64 << MASK_LOG_MSG;
    let dom = 1u64 << MASK_LOG_DOM;
    let specs = lay.mask_specs();
    // `CfsMask::random` draws `fp2_vec(len)`, and an `Fp2` is two `fp()`s
    let cfs: u64 = specs.iter().map(|&(nv, d)| 2 * CfsMask::len(nv, d) as u64).sum();
    let rows = specs.len() as u64;
    vec![
        Seg { what: "A mask + proximity rows", kind: Kind::Fp, count: (lay.a_rows - lay.a_mask_base) as u64 * n, site: "protocol.rs: `for x in &mut a_data[lay.a_mask_base * n..]`" },
        Seg { what: "A pads", kind: Kind::Fp, count: lay.a_rows as u64 * q, site: "zkp-core/pcs.rs: `rng.fp_vec(rows * q)`" },
        Seg { what: "A salts", kind: Kind::Salt, count: nn, site: "zkp-core/pcs.rs: `(0..nn).map(|_| rng.bytes32())`" },
        Seg { what: "M CFS mask coefficients", kind: Kind::Fp, count: cfs, site: "zk.rs -> sumcheck.rs: `CfsMask::random`" },
        Seg { what: "M per-row pads", kind: Kind::Fp, count: 2 * rows * MASK_Q as u64, site: "zk.rs: `rng.fp_vec(MASK_Q)` per a-row" },
        Seg { what: "M b_re, b_im, u_re, u_im", kind: Kind::Fp, count: 4 * 2 * m, site: "zk.rs: four `rng.fp_vec(2 * m)`" },
        Seg { what: "M salts", kind: Kind::Salt, count: dom, site: "zk.rs: `(0..dom).map(|_| rng.bytes32())`" },
        Seg { what: "H mask + proximity rows", kind: Kind::Fp, count: (lay.h_rows - lay.h_mask_base) as u64 * n, site: "protocol.rs: `for x in &mut h_data[lay.h_mask_base * n..]`" },
        Seg { what: "H zero-sum rows", kind: Kind::Fp, count: lay.h_u_rows().len() as u64 * (n - 1), site: "protocol.rs: the `lay.h_u_rows()` loop over `0..n - 1`" },
        Seg { what: "H pads", kind: Kind::Fp, count: lay.h_rows as u64 * q, site: "zkp-core/pcs.rs: `rng.fp_vec(rows * q)`" },
        Seg { what: "H salts", kind: Kind::Salt, count: nn, site: "zkp-core/pcs.rs: `(0..nn).map(|_| rng.bytes32())`" },
    ]
}

/// the running offsets of the segments, and the total — assertion 2's
/// "begins at the offset the schedule predicts, pairwise disjoint, covering
/// the consumption with no hole", as arithmetic anyone can redo
fn offsets(segs: &[Seg]) -> (Vec<(u64, u64)>, u64) {
    let mut at = 0u64;
    let mut out = Vec::with_capacity(segs.len());
    for s in segs {
        out.push((at, at + s.bytes()));
        at += s.bytes();
    }
    (out, at)
}

fn total_fp(segs: &[Seg]) -> u64 {
    segs.iter().filter(|s| s.kind == Kind::Fp).map(|s| s.count).sum()
}

fn total_salts(segs: &[Seg]) -> u64 {
    segs.iter().filter(|s| s.kind == Kind::Salt).map(|s| s.count).sum()
}

// ---------------------------------------------------------------- the measurement

/// what one measured proof consumed and squeezed
struct Measured {
    /// the BLOCK generator's stream bytes, from `ZkRng::consumed_bytes`
    consumed: u64,
    /// its refills, from `ZkRng::refills`
    refills: u64,
    /// the LIVE transcript's squeezes, from `Transcript::squeezes`
    squeezes: u64,
    /// every `check_opening_challenges` call of the proof, as counts
    replay: Vec<super::draw_observer::Call>,
    /// the receipt's encoded length, so that the measured proof is pinned
    /// to be the profile's real one
    frame: usize,
    /// **STAGE 46.** What the two REAL endpoint owners of this statement
    /// hold, read off their commitments before they are opened: `(mask
    /// words, pads, salts)` each — the objects their own generators filled,
    /// counted where they live (see [`endpoint_object_counts`]).
    endpoint_objects: [(u64, u64, u64); 2],
}

/// **STAGE 46.** `(mask words, pads, salts)` held by one REAL endpoint owner
/// — the `pcs::CommittedZk` that `endpoint_g::prepare` (or the frozen seam)
/// built with its own `ZkRng::from_os`. The generator itself is dropped
/// inside the preparer and its byte counter cannot be read (finding
/// S36-F2); what CAN be read in situ is what it filled: every word of the
/// rows above the shape's data rows (one `fp()` each, by
/// [`the_endpoint_replica_is_the_endpoint_preparers_own_draw_sequence`]),
/// the commitment's `pads` (one `fp()` each) and its `salts` (one
/// `bytes32()` each). The data rows come from the SHAPE
/// (`protocol::endpoint_geometry`), not from the owner's own `mask_rows`.
fn endpoint_object_counts(sh: &Shape, e: &pcs::CommittedZk) -> (u64, u64, u64) {
    let (rows, data, _) = protocol::endpoint_geometry(sh).expect("the endpoint geometry");
    assert_eq!(e.cm.rows, rows, "{}: the endpoint owner's commitment has another row count than the shape's", sh.name);
    let n = e.data.len() / rows;
    assert_eq!(n * rows, e.data.len(), "{}: the endpoint owner's matrix is not rows x n", sh.name);
    (((rows - data) * n) as u64, e.pads.len() as u64, e.salts.len() as u64)
}

/// **`prove_inner_at`'s body, with the generator and the transcript ours.**
///
/// Every step is the production function's, in its order: the NTT-table
/// fit, the layout, `check_endpoints`, the generator on
/// `hash_domain::single_block_seed_domain(sh)` (the same domain the prover
/// passes), the tables, the header transcript, `prove_core`, then the two
/// endpoint openings — each preceded by its refusal replay, exactly as
/// `prove_inner_at` orders them. The receipt is assembled from the same
/// parts and VERIFIED, in typed form and from its bytes, before any counter
/// is read: a measurement of a stream that did not produce a valid proof
/// would be a measurement of nothing.
///
/// The two endpoint replays are the only two of the proof's four that this
/// function can stand beside, so it checks the live invariant there: a
/// replay moves neither the generator nor the live transcript.
fn measure_block(sh: &Shape, blk: &BlockPublic, wit: Witness, expected: &ExpectedIo, owners: Endpoints) -> Measured {
    let session = super::draw_observer::Session::open();
    protocol::fits_the_ntt_tables(sh).expect("the shape fits the NTT tables");
    let lay = Layout::for_shape(sh).expect("the shape has a layout");
    let [ein, eout] = protocol::check_endpoints(sh, expected, owners).expect("the endpoint owners match the statement");
    let endpoint_objects = [endpoint_object_counts(sh, &ein), endpoint_object_counts(sh, &eout)];
    let mut rng = ZkRng::from_os(&super::hash_domain::single_block_seed_domain(sh)).expect("OS randomness");
    assert_eq!(rng.consumed_bytes(), 0, "a fresh generator has already consumed");
    let ntt = NttTables::new(protocol::ntt_log_at(sh));
    let mut tr = protocol::transcript(blk, expected, &lay);
    assert_eq!(tr.squeezes(), 0, "the header transcript squeezed before a challenge was asked for");
    let mut ph = super::timing::Phases::start();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let mut tick = std::time::Instant::now();
    let core = protocol::prove_core(sh, &lay, blk, wit, [ein.data.as_slice(), eout.data.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the core prover");
    let [ic, oc] = core.io_claims;

    // THE TWO ENDPOINT REFUSAL REPLAYS, watched from the outside
    for (which, claims) in [("incoming", &ic), ("outgoing", &oc)] {
        let before = (rng.consumed_bytes(), rng.refills(), tr.squeezes());
        protocol::check_endpoint_opening(claims, sh, &tr).expect("the endpoint opening passes its own refusal checks");
        let after = (rng.consumed_bytes(), rng.refills(), tr.squeezes());
        assert_eq!(before, after, "{}: the {which} endpoint's refusal replay moved the generator or the LIVE transcript; it is supposed to draw from a discarded clone", sh.name);
    }
    let in_open = pcs::open_zk(&ein, &ic, &mut tr);
    drop(ein);
    let out_open = pcs::open_zk(&eout, &oc, &mut tr);
    drop(eout);

    let receipt = Receipt { a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: core.slots, mask_open: core.mask_open, a_open: core.a_open, h_open: core.h_open, io_open: [in_open, out_open] };
    let measured = Measured { consumed: rng.consumed_bytes(), refills: rng.refills(), squeezes: tr.squeezes(), replay: session.calls(), frame: 0, endpoint_objects };
    drop(rng);
    drop(tr);

    // the proof this stream produced is a real one, or the numbers mean nothing
    verify_inner_at(sh, blk, expected, &receipt).expect("the measured receipt verifies in typed form");
    let bytes = receipt.to_bytes_at(sh, blk, expected).expect("the measured receipt encodes");
    super::verify_bytes_at(sh, blk, expected, &bytes).expect("the measured receipt verifies from bytes");
    Measured { frame: bytes.len(), ..measured }
}

/// **The endpoint preparer's draw sequence, on a generator we can observe.**
/// Two steps, in this order, and nothing else: `commitment_rows - data_rows`
/// rows of `fp()` mask words, then the commitment, which draws
/// `commitment_rows * q_pad` pads and `enc_cols` salts. Returns
/// `(stream bytes, fp draws, salts)`.
fn measure_endpoint(rows: usize, data_rows: usize, params: &crate::pcs::PcsParams, tagged: Option<&zkp_core::hashtag::HashTag>, ntt: &NttTables, fill: Fp) -> (u64, u64, u64) {
    let n = params.cols();
    let zko = ZkOpts::standard(params);
    let mut rng = ZkRng::from_os(b"stage 36: the endpoint replica's own stream").expect("OS randomness");
    let mut values = vec![fill; rows * n];
    for x in &mut values[data_rows * n..] {
        *x = rng.fp();
    }
    let committed = match tagged {
        None => pcs::commit_zk_owned(params, values, ntt, &zko, &mut rng),
        Some(tag) => pcs::commit_zk_owned_tagged(params, values, ntt, &zko, &mut rng, tag),
    };
    let salts = committed.salts.len() as u64;
    let pads = committed.pads.len() as u64;
    let masks = ((rows - data_rows) * n) as u64;
    assert_eq!(salts, params.enc_cols() as u64, "the commitment salted a different number of leaves than it has encoded columns");
    assert_eq!(pads, rows as u64 * zko.q_pad as u64, "the commitment padded a different number of words than rows x q");
    (rng.consumed_bytes(), masks + pads, salts)
}

// ---------------------------------------------------------------- the fixtures

fn s36_context() -> Digest {
    *blake3::hash(b"private block: stage 36, the draw-accounting test").as_bytes()
}

/// the padded plane of a witness, as `int16`
fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

/// one shape this module measures, with the two figures pinned for it
struct Target {
    label: &'static str,
    sh: Shape,
    /// the live transcript's squeeze count per proof
    squeezes: u64,
    /// the points the four refusal replays re-issue per proof
    replay: u64,
}

/// **THE SIX SHAPES THIS MODULE MEASURES**, with their pins.
///
/// The toy is the one with an accepted privacy statement and published
/// figures: its two numbers are **reproductions** of rows T4a and T4c of
/// `ZK60_TOY_ROUTE_A_REEXAMINATION.md` §1.4. The five development rungs
/// have no published figure, so theirs are **pins measured by this stage**
/// — a change in either is a change in how many challenges a proof of that
/// shape takes, which has to be explained and not re-pinned quietly. The
/// five differ in every axis the segment model has a term for (row width,
/// head count, head dimension, endpoint rows, endpoint log), so a
/// compensating error in two terms of the closed form would have to
/// survive all six geometries.
fn targets() -> Vec<Target> {
    vec![
        Target { label: "toy", sh: Shape::toy(), squeezes: TOY_LIVE_SQUEEZES, replay: TOY_REPLAY_POINTS },
        Target { label: "rung-K4", sh: Shape::rung_k4(), squeezes: 2_610, replay: 1_642 },
        Target { label: "rung-P2", sh: Shape::rung_p2(), squeezes: 2_604, replay: 1_642 },
        Target { label: "rung-C6", sh: Shape::rung_c6(), squeezes: 3_977, replay: 2_962 },
        Target { label: "rung-W14", sh: Shape::rung_w14(), squeezes: 2_254, replay: 1_156 },
        Target { label: "rung-E32", sh: Shape::rung_e32(), squeezes: 5_919, replay: 4_874 },
    ]
}

/// the whole statement of one shape: the public block, an admissible
/// witness, the sealed endpoints and the expected IO
fn parts_at(sh: &Shape, ctx: Digest) -> (BlockPublic, Witness, ExpectedIo, Endpoints, IoSpec) {
    if sh.is_frozen_toy() {
        let (blk, input) = BlockPublic::synthetic_fixture();
        let output = compute_output(&blk, &input).expect("the toy fixture's own output");
        let spec = IoSpec::new(ctx, 0, 0).expect("the toy endpoint spec");
        let (expected, owners) = prepare_endpoints(spec.clone(), &input, &output).expect("the toy endpoint owners");
        let wit = witness::build(blk.attention(), blk.feed_forward(), &input).expect("the toy witness");
        (blk, wit, expected, owners, spec)
    } else {
        let (public, ff, input) = super::dense_tests::dense_case(sh);
        let wit = witness::build_shaped(sh, &public, &ff, &input).expect("the shaped dense witness");
        let ids = Ids::new(sh).expect("the shape's plane map");
        let spec = IoSpec::new_shaped(sh, ctx, 0, 0).expect("the shaped endpoint spec");
        let (expected, owners) = prepare_endpoints(spec.clone(), &padded(&wit, ids.at(A_X)), &padded(&wit, ids.at(A_X2))).expect("the shaped endpoint owners");
        (BlockPublic::new(public, ff), wit, expected, owners, spec)
    }
}

/// the two endpoint generators of a statement, measured on the replica
fn endpoints_measured(sh: &Shape, spec: &IoSpec) -> (u64, u64, u64) {
    if spec.general {
        let [si, so] = spec.endpoints_g().expect("the generalised endpoint specs");
        let ntt = NttTables::new(si.enc_log().max(so.enc_log()));
        let tag = spec.hash_tag;
        let mut acc = (0u64, 0u64, 0u64);
        for s in [&si, &so] {
            let (b, f, sa) = measure_endpoint(s.commitment_rows(), s.data_rows(), &s.params(), Some(&tag), &ntt, Fp::ZERO);
            acc = (acc.0 + b, acc.1 + f, acc.2 + sa);
        }
        acc
    } else {
        let [si, so] = spec.seams().expect("the frozen seam specs");
        let ntt = NttTables::new(12);
        let (rows, data, _) = protocol::endpoint_geometry(sh).expect("the endpoint geometry");
        let mut acc = (0u64, 0u64, 0u64);
        for s in [&si, &so] {
            let params = s.params();
            assert_eq!(s.len().div_ceil(params.cols()), data, "the frozen seam's data rows are not the shape's");
            let (b, f, sa) = measure_endpoint(rows, data, &params, None, &ntt, Fp::ZERO);
            acc = (acc.0 + b, acc.1 + f, acc.2 + sa);
        }
        acc
    }
}

// =========================================================================
// ASSERTION 1, 2 and 4 — total consumption, per-role offsets, injectivity
// =========================================================================

/// **ASSERTIONS 1, 2 and 4 of §3.1, plus the transcript's squeezes and the
/// refusal replay — at six shapes, one proof each.**
///
/// * **1, total consumption.** A block proof at shape `S` consumes exactly
///   `bytes(S)` stream bytes, and `bytes(S)` is built here from shape and
///   layout constants alone — never imported as a number. At the toy it is
///   claim A-5's **5,396,672**, and the block body's **320,908** `fp()`
///   draws and **8,192** salts are each asserted separately, so the total
///   cannot be right for compensating reasons in the two kinds.
/// * **2, per-role offsets.** The eleven segments' start offsets are the
///   running sums of their lengths in the order the prover draws them; the
///   test asserts they are pairwise disjoint, contiguous (no hole), and
///   that the last one ends at the measured consumption. **What is
///   measured is the total and what is derived is the partition**: a
///   snapshot INSIDE `prove_core` would need a hook in a function this
///   stage may not touch, and this module does not pretend to have one.
///   What makes the partition more than a declaration is that the same
///   eleven terms have to produce the right total at six geometries that
///   differ in every axis the terms depend on.
/// * **4, injectivity across roles.** Each of the three commitments' pads,
///   mask rows and salts occupies its own half-open byte range on one
///   stream, and the ranges are pairwise disjoint by construction above;
///   the two endpoint generators cannot overlap them at all, because they
///   are different streams under different keys (asserted by
///   [`the_three_generators_of_one_proof_are_three_separate_streams`]).
/// * **The refill count cross-checks the byte count** — the same state
///   read the other way round, so a bug in one would have to be mirrored
///   exactly in the other.
/// * **The live transcript's squeeze count**, which at the toy is row T4a
///   of the complete query table: **1,863** live squeeze points per proof.
///   The five rungs have no published figure and carry this stage's pins.
/// * **The refusal replay**: four calls per proof (`A`, `H`, and one per
///   endpoint), each drawing `Σ group members` then the commitment's own
///   `rows` proximity coefficients, all four accepted on an honest proof,
///   and **1,027** re-issued points at the toy — clarification 9 of the
///   accepted statement, reproduced. The replay draws from a DISCARDED
///   transcript clone and consumes no generator byte: asserted live around
///   the two endpoint calls inside [`measure_block`], where this module
///   stands beside the production code and can read both counters before
///   and after.
///
/// One proof per shape serves all of it: proving six shapes three times
/// over would put minutes into the lane's filter for numbers that come off
/// the same run.
#[test]
fn a_block_proof_consumes_exactly_the_counted_stream_at_every_shape() {
    use super::draw_observer::Verdict;
    // MEASURE FIRST, ASSERT AFTER: every shape's numbers are printed before
    // any of them is compared, so one failure does not hide the other five.
    let mut measured: Vec<(Target, Vec<Seg>, Measured)> = Vec::new();
    for t in targets() {
        let (blk, wit, expected, owners, _spec) = parts_at(&t.sh, s36_context());
        let segs = block_segments(&t.sh);
        let m = measure_block(&t.sh, &blk, wit, &expected, owners);
        let (ranges, _) = offsets(&segs);
        eprintln!(
            "S36 [{}]: {} stream bytes = {} fp x 16 + {} salts x 32, {} refills, {} live squeezes, {} replayed points in {} calls, frame {} B",
            t.label,
            m.consumed,
            total_fp(&segs),
            total_salts(&segs),
            m.refills,
            m.squeezes,
            m.replay.iter().map(|c| c.draws).sum::<u64>(),
            m.replay.len(),
            m.frame
        );
        for (sg, r) in segs.iter().zip(ranges.iter()) {
            eprintln!("    {:<28} {:>5?} {:>10} [{:>12} .. {:>12})   {}", sg.what, sg.kind, sg.count, r.0, r.1, sg.site);
        }
        measured.push((t, segs, m));
    }
    for (t, segs, m) in &measured {
        let sh = &t.sh;
        let (ranges, want) = offsets(segs);

        // the partition: contiguous, pairwise disjoint, covering
        assert_eq!(ranges[0].0, 0, "{}: the first segment does not start at offset zero", sh.name);
        for k in 1..ranges.len() {
            assert_eq!(ranges[k].0, ranges[k - 1].1, "{}: segment {k} does not begin where segment {} ends", sh.name, k - 1);
        }
        for a in 0..ranges.len() {
            for b in a + 1..ranges.len() {
                assert!(ranges[a].1 <= ranges[b].0 || ranges[b].1 <= ranges[a].0, "{}: segments {a} and {b} overlap", sh.name);
            }
            assert!(ranges[a].1 > ranges[a].0, "{}: segment {a} ({}) is empty", sh.name, segs[a].what);
        }
        assert_eq!(ranges.last().expect("eleven segments").1, want, "{}: the segments do not cover the predicted total", sh.name);
        assert_eq!(segs.len(), 11, "{}: the block body no longer has eleven segments", sh.name);

        // assertion 1 itself
        assert_eq!(m.consumed, want, "{}: the block generator consumed {} stream bytes, the eleven segments predict {want}", sh.name, m.consumed);
        assert_eq!(m.consumed, total_fp(&segs) * BYTES_PER_FP + total_salts(&segs) * BYTES_PER_SALT, "{}: the total is not 16 per field draw plus 32 per salt", sh.name);
        assert_eq!(m.refills, m.consumed.div_ceil(ZkRng::OBSERVED_BLOCK_BYTES), "{}: the refill count and the byte count disagree", sh.name);

        if sh.is_frozen_toy() {
            assert_eq!(total_fp(segs), TOY_BLOCK_FP_DRAWS, "the toy block body's fp() draws are not claim A-5's 320,908");
            assert_eq!(total_salts(segs), TOY_BLOCK_SALTS, "the toy block body's salts are not claim A-5's 8,192");
            assert_eq!(m.consumed, TOY_BLOCK_BYTES, "the toy block body's stream is not claim A-5's 5,396,672 bytes");
        }
        // **THE SECOND ROW OF CLAIM A-5'S TABLE THAT THIS LANE CAN REACH.**
        // `stream_positions.py` prints 750,540 / 12,288 / 12,401,856 for
        // rung-K4, computed there from the same geometry by a different
        // program in a different language. Measured here on the real
        // stream, it is the same three numbers.
        if t.label == "rung-K4" {
            assert_eq!((total_fp(segs), total_salts(segs), m.consumed), (750_540, 12_288, 12_401_856), "the rung-K4 row of claim A-5's table no longer reproduces");
        }

        // THE LIVE TRANSCRIPT'S SQUEEZES (the toy's is row T4a's 1,863; the
        // rungs' are this stage's pins)
        assert_eq!(m.squeezes, t.squeezes, "{}: the live transcript squeezed {} times, the pin says {}", t.label, m.squeezes, t.squeezes);
        if sh.is_frozen_toy() {
            assert_eq!(m.squeezes, TOY_LIVE_SQUEEZES, "the toy's live squeeze count is not the query table's 1,863");
        }

        // THE REFUSAL REPLAY: four calls, the partition each drew, all
        // accepted, and the counted total (the toy's is clarification 9's
        // 1,027). That it consumed NO generator byte is asserted live for
        // the two endpoint calls inside `measure_block`, and for the proof
        // as a whole by the consumption assertion above, whose closed form
        // has no term for a replay.
        let lay = Layout::for_shape(sh).expect("the shape has a layout");
        assert_eq!(m.replay.len(), 4, "{}: a single-block proof no longer makes exactly four refusal replays", t.label);
        let rows = [lay.a_rows as u64, lay.h_rows as u64, sh.endpoint_rows as u64, sh.endpoint_rows as u64];
        let names = ["A", "H", "endpoint in", "endpoint out"];
        let mut points = 0u64;
        for (k, call) in m.replay.iter().enumerate() {
            assert_eq!(call.verdict, Verdict::Accepted, "{}: the {} opening's refusal replay did not accept", t.label, names[k]);
            assert_eq!(call.rho_draws(), rows[k], "{}: the {} opening drew {} proximity coefficients, its commitment has {} rows", t.label, names[k], call.rho_draws(), rows[k]);
            assert!(call.group_draws > 0, "{}: the {} opening tested no group member", t.label, names[k]);
            points += call.draws;
        }
        assert_eq!(m.replay[2].group_draws, 1, "{}: the incoming endpoint's opening is no longer a single one-member group", t.label);
        assert_eq!(m.replay[3].group_draws, 1, "{}: the outgoing endpoint's opening is no longer a single one-member group", t.label);
        if sh.is_frozen_toy() {
            assert_eq!(points, TOY_REPLAY_POINTS, "the toy's refusal replay no longer re-issues clarification 9's 1,027 points");
        }
        assert_eq!(points, t.replay, "{}: the refusal replay re-issued {points} points, the pin says {}", t.label, t.replay);
    }
}

/// **THE ACCEPTED TOY STATEMENT'S 327,052 DRAWS, REPRODUCED FROM THE
/// ACCESSOR** — the figure decision D9's residual is computed from
/// (327,052 x 2^-96 = 2^-77.68), summed over the three generators of one
/// toy proof: the block's 320,908 and 3,072 per endpoint.
///
/// The three are measured separately and added here, because they are three
/// streams and the statement's figure is about all of them.
#[test]
fn the_three_generators_of_a_toy_proof_draw_the_statements_327052_field_elements() {
    let sh = Shape::toy();
    let (blk, wit, expected, owners, spec) = parts_at(&sh, s36_context());
    let segs = block_segments(&sh);
    let m = measure_block(&sh, &blk, wit, &expected, owners);
    let (ends_bytes, ends_fp, ends_salts) = endpoints_measured(&sh, &spec);

    let block_fp = total_fp(&segs);
    let block_salts = total_salts(&segs);
    assert_eq!(m.consumed, TOY_BLOCK_BYTES);
    // the endpoints' bytes are 16 per draw and 32 per salt, like everything else
    assert_eq!(ends_bytes, ends_fp * BYTES_PER_FP + ends_salts * BYTES_PER_SALT, "the endpoints' stream is not 16 per draw plus 32 per salt");
    assert_eq!(ends_fp, 6_144, "the two frozen-seam endpoints no longer draw 3,072 field elements each");
    assert_eq!(ends_salts, 4_096, "the two frozen-seam endpoints no longer salt 2,048 leaves each");

    let fp_draws = block_fp + ends_fp;
    let salts = block_salts + ends_salts;
    let bytes = m.consumed + ends_bytes;
    assert_eq!(fp_draws, TOY_FP_DRAWS, "the toy proof's field draws are not the accepted statement's 327,052");
    assert_eq!(bytes, fp_draws * BYTES_PER_FP + salts * BYTES_PER_SALT);
    assert_eq!(bytes, 5_626_048, "the toy proof's three streams no longer total 5,626,048 bytes");
    // the memo's leaf count, from the other side: 4 x 2,048 + 4,096
    assert_eq!(salts, 12_288, "the toy proof's salted leaves are not the hash-layer table's 12,288");
    eprintln!("S36 D9's figure: {fp_draws} fp() draws per toy proof = {block_fp} (block) + {ends_fp} (two endpoints) — the accepted statement's 327,052; {salts} salts; {bytes} stream bytes over the three generators");
}

/// **THE TWO ENDPOINT GENERATORS, AT EVERY SHAPE.** The block generator's
/// side of assertion 1 is measured on a real proof above; this is the other
/// two streams of the same proof, at all six shapes, and it needs no proof
/// to measure because an endpoint's draws are a function of its spec alone.
///
/// For each: the stream is `16 x (mask words + pads) + 32 x salts` exactly,
/// the mask words are the rows above `data_rows`, the pads are `rows x
/// q_pad` and the salts are the encoded column count — each checked against
/// the commitment's own `pads` and `salts` vectors inside
/// [`measure_endpoint`], so the closed form is compared with what the
/// commitment actually holds and not only with itself.
#[test]
fn the_two_endpoint_generators_consume_the_counted_stream_at_every_shape() {
    for t in targets() {
        let spec = if t.sh.is_frozen_toy() { IoSpec::new(s36_context(), 0, 0) } else { IoSpec::new_shaped(&t.sh, s36_context(), 0, 0) }.expect("the endpoint spec");
        let (bytes, fp, salts) = endpoints_measured(&t.sh, &spec);
        assert_eq!(bytes, fp * BYTES_PER_FP + salts * BYTES_PER_SALT, "{}: the endpoints' stream is not 16 per field draw plus 32 per salt", t.label);
        assert!(fp > 0 && salts > 0, "{}: an endpoint drew nothing", t.label);
        assert_eq!(bytes % 2, 0);
        eprintln!("S36 endpoints [{}]: {bytes} stream bytes over the two endpoint generators = {fp} fp x 16 + {salts} salts x 32 ({} and {} each)", t.label, fp / 2, salts / 2);
        if t.sh.is_frozen_toy() {
            assert_eq!((bytes, fp, salts), (229_376, 6_144, 4_096), "the toy's two frozen-seam endpoints no longer draw 3,072 field elements and salt 2,048 leaves each");
        }
    }
}

/// **THE THREE GENERATORS ARE THREE SEPARATE STREAMS** (assertion 4's
/// premise, and clarification 5 of the accepted statement: *"Three fresh
/// reads of the operating system's entropy per proof, not one: the block's
/// and one per endpoint"*).
///
/// Two halves, both source facts, because the count of entropy READS is not
/// a thing any accessor can report:
///
/// 1. the single-block path constructs exactly three generators — one in
///    `protocol.rs` (the block prover's) and one in each endpoint
///    preparer, which `prepare_endpoints` calls exactly twice;
/// 2. every one of them is `ZkRng::from_os`, which reads its own 32 bytes
///    of `/dev/urandom` and derives its key from them under a KEYED hash —
///    so three generators is three reads, and no fourth site exists on the
///    path (stage 25's `no_profile_on_this_path_can_obtain_a_generator_
///    other_than_from_the_operating_system`, cited here and required to
///    still exist).
#[test]
fn the_three_generators_of_one_proof_are_three_separate_streams() {
    let protocol_src = source("src/private_block/protocol.rs");
    let body = fn_body(&protocol_src, "pub(crate) fn prove_inner_at(");
    assert_eq!(body.matches("ZkRng::from_os").count(), 1, "the block prover no longer constructs exactly one generator");
    assert_eq!(body.matches("ZkRng::new").count(), 0, "the block prover constructs a seeded generator");
    let parent = source("src/private_block.rs");
    let prep = fn_body(&parent, "pub fn prepare_endpoints(");
    let calls = prep.matches("endpoint_g::prepare(").count() + prep.matches("private_seam::prepare(").count();
    assert_eq!(calls, 4, "`prepare_endpoints` no longer makes exactly two endpoint owners on each of its two branches");
    assert_eq!(prep.matches("ZkRng").count(), 0, "`prepare_endpoints` itself now touches a generator");
    for (path, sig) in [("src/private_seam.rs", "pub fn prepare("), ("src/private_block/endpoint_g.rs", "pub(crate) fn prepare(")] {
        let b = fn_body(&source(path), sig);
        assert_eq!(b.matches("ZkRng::from_os").count(), 1, "{path}: the endpoint preparer no longer makes exactly one generator");
        assert_eq!(b.matches("ZkRng::new").count(), 0, "{path}: the endpoint preparer makes a seeded generator");
    }
    // the stage-25 scan this rests on must still be there
    let s25 = source("src/private_block/s25_tests.rs");
    assert!(s25.contains("fn no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system()"), "stage 25's generator-provenance scan has been deleted; assertion 7 is no longer asserted anywhere");
    eprintln!("S36 clarification 5: three generators per single-block proof — one in `prove_inner_at`, one in each of `prepare_endpoints`' two owners — every one of them `ZkRng::from_os`, so three entropy reads and no more");
}

// =========================================================================
// ASSERTION 3 — witness-independence and statement-independence
// =========================================================================

/// **ASSERTION 3.** Two different admissible witnesses at the same shape
/// produce IDENTICAL consumption, identical refill counts and identical
/// squeeze counts; and so does the same witness under a different public
/// statement. Consumption is a function of the geometry and of nothing
/// else — which is what lets the privacy argument talk about "the stream"
/// without conditioning on the input.
///
/// The two witnesses are the toy's public synthetic fixture and its
/// ALL-ZERO hidden input, which is the fixture the privacy case is stated
/// on (the zero-witness acceptance test, step 1 of the statement's §3).
#[test]
fn consumption_does_not_depend_on_the_witness_or_on_the_public_statement() {
    let sh = Shape::toy();
    let (blk, wit, expected, owners, _) = parts_at(&sh, s36_context());
    let a = measure_block(&sh, &blk, wit, &expected, owners);

    // the same statement, the ALL-ZERO hidden input
    let (zblk, zinput) = BlockPublic::synthetic_fixture();
    let zero = vec![0i16; zinput.len()];
    let zout = compute_output(&zblk, &zero).expect("the all-zero input has an output");
    let zspec = IoSpec::new(s36_context(), 0, 0).expect("the toy endpoint spec");
    let (zexp, zowners) = prepare_endpoints(zspec, &zero, &zout).expect("the all-zero endpoint owners");
    let zwit = witness::build(zblk.attention(), zblk.feed_forward(), &zero).expect("the all-zero witness");
    let b = measure_block(&sh, &zblk, zwit, &zexp, zowners);

    // a DIFFERENT public statement: another endpoint context digest
    let other = *blake3::hash(b"private block: stage 36, another context entirely").as_bytes();
    let (oblk, owit, oexp, oowners, _) = parts_at(&sh, other);
    let c = measure_block(&sh, &oblk, owit, &oexp, oowners);

    for (what, m) in [("the all-zero hidden input", &b), ("another public statement", &c)] {
        assert_eq!(m.consumed, a.consumed, "{what} changed the stream consumption");
        assert_eq!(m.refills, a.refills, "{what} changed the refill count");
        assert_eq!(m.squeezes, a.squeezes, "{what} changed the squeeze count");
        assert_eq!(m.frame, a.frame, "{what} changed the receipt length");
        assert_eq!(m.replay.len(), a.replay.len(), "{what} changed the number of refusal replays");
    }
    // and the endpoints: the replica's consumption is the same whatever it seals
    let spec = IoSpec::new(s36_context(), 0, 0).expect("the toy endpoint spec");
    let [si, _] = spec.seams().expect("the frozen seam specs");
    let (rows, data, _) = protocol::endpoint_geometry(&sh).expect("the endpoint geometry");
    let ntt = NttTables::new(12);
    let zeros = measure_endpoint(rows, data, &si.params(), None, &ntt, Fp::ZERO);
    let ones = measure_endpoint(rows, data, &si.params(), None, &ntt, Fp::new(7));
    assert_eq!(zeros, ones, "an endpoint's consumption depends on the words it seals");
    eprintln!("S36 assertion 3: {} bytes, {} refills, {} squeezes and a {} B frame under three different (witness, statement) pairs; the endpoint's {} bytes under two different sealed planes", a.consumed, a.refills, a.squeezes, a.frame, zeros.0);
}

// =========================================================================
// ASSERTION 6 — the realised value map
// =========================================================================

// -------------------------------------------------------------------------
// STAGE 47, RULING LW-2 (`ZK60_BLINDING_LAW_GR4_DISPOSITION.md`): THIS SCAN
// IS BLIND TO TWO KINDS OF DRAWN VALUE. It is kept as a source-text tripwire
// for `let`-bound draws only. The VALUE-LEVEL check of every drawn word of A,
// M and H is `gr4_check_tests.rs` (the seeded replay: A, M and H rebuilt
// from the witness and the eleven predicted stream segments without the
// commit functions, the three roots and the byte count required equal).
//
//  1. The fill idiom `for x in &mut <slice> { *x = rng.fp(); }`. After
//     trimming, the line `*x = rng.fp();` starts with `*`, so the
//     comment filter below (`t.starts_with('*')`) skips it, and
//     `binding_name` binds `let` names only. So `a_data` and `h_data`
//     (A's and H's reserved pairs and proximity rows, `protocol.rs`), the
//     boundary's and both endpoints' mask rows (`boundary.rs`,
//     `endpoint_g.rs`, `private_seam.rs`) never enter `drawn`, and no later
//     write into them is looked at. The doc comment's parenthesis below
//     used to say the idiom is found; it is not.
//  2. `α`, the CFS coefficients: drawn inside `CfsMask::random` as a struct
//     field (`coeffs: rng.fp2_vec(..)`, not a `let`), and bound in `zk.rs`
//     as `let masks = .. CfsMask::random(rng, n, d)`, which contains no
//     draw pattern; no write into `masks[..].coeffs` is looked at.
//
// Demonstrated on the Rust (review branch `mut-m*.log`; again in the lane,
// `results/zk60_block125m_lane/s47-mut-*.log`): m1
// (`a_data[lay.a_prox * n] = Fp::ZERO;` after the A fill), m2
// (`h_data[lay.h_mask_base * n] = a.data[lay.a_mask_base * n];` after the H
// fill) and m4 (`masks[1].coeffs[0] = masks[0].coeffs[0];` in
// `zk::mask_commit_tagged`) each leave THIS test green; `gr4_check_tests`
// fails on each, naming the A, H and M root respectively.
// -------------------------------------------------------------------------
/// **ASSERTION 6 — values at distinct positions are not functions of one
/// another EXCEPT where the schedule says so BY NAME.**
///
/// §3.1's declared set, in full, is three relations imposed on drawn values
/// AFTER they are drawn:
///
/// | relation | site | kind |
/// |---|---|---|
/// | `b_re[m] := -b_re[0]` | `zk.rs`, in `mask_commit` and `mask_commit_tagged` | an OVERWRITE: the word drawn at position `m` is consumed and discarded |
/// | `b_im[m] := -b_im[0]` | the same | the same |
/// | the last entry of each `H` zero-sum row, `h_data[r·n + n-1] := -Σ_{j<n-1}` | `protocol.rs` | NOT an overwrite: that position is never drawn, because the loop runs `j` over `0..n-1` |
///
/// The test asserts the set is **exactly** that: it reads the production
/// text of every module on the path, finds every buffer a generator filled
/// (`rng.fp_vec`, `rng.fp2_vec`, `rng.bytes32` bound to a `let` name — NOT
/// the `for x in &mut <slice> { *x = rng.fp(); }` idiom and NOT `α`: see the
/// stage-47 LW-2 block above), and then finds every
/// later assignment INTO one of those buffers. **Four sites are found and
/// all four are declared** — the two overwrite relations, at each of the
/// two mask-commit entry points (`mask_commit` keeps its own body beside
/// `mask_commit_tagged`, so each relation is written twice). The third
/// declared relation is not an overwrite and cannot show up in that scan,
/// because the position it writes is never drawn; it is checked directly,
/// together with the loop bound that makes it true and the segment term
/// that counts `n - 1` draws for that row rather than `n`.
///
/// A FIFTH site would fail here, which is the whole point — a reused
/// buffer, a repeated slice or a re-entered commit path must be a failure
/// and not a silence.
#[test]
fn the_only_relations_imposed_on_drawn_values_are_the_three_the_schedule_declares() {
    // every production file a block proof's randomness passes through
    let files = ["src/zk.rs", "src/pcs.rs", "src/private_seam.rs", "src/private_block/protocol.rs", "src/private_block/endpoint_g.rs", "src/private_block/boundary.rs", "../zkp-core/src/pcs.rs", "../zkp-core/src/sumcheck.rs", "../zkp-core/src/rng.rs"];
    let mut found: Vec<String> = Vec::new();
    for path in files {
        let src = source(path);
        let text = production_text(&src);
        // the names bound to a generator draw in this file
        let mut drawn: Vec<String> = Vec::new();
        for line in text.lines() {
            let t = line.trim();
            if t.starts_with("//") || t.starts_with('*') {
                continue;
            }
            for pat in ["rng.fp_vec(", "rng.fp2_vec(", "rng.bytes32(", "rng.fp()"] {
                if !t.contains(pat) {
                    continue;
                }
                if let Some(name) = binding_name(t) {
                    drawn.push(name);
                }
            }
        }
        drawn.sort();
        drawn.dedup();
        // every assignment INTO one of them, after the draw
        for (i, line) in text.lines().enumerate() {
            let t = line.trim();
            if t.starts_with("//") || t.starts_with('*') || !t.contains(" = ") {
                continue;
            }
            let lhs = t.split(" = ").next().unwrap_or("").trim_start_matches("let ").trim();
            for name in &drawn {
                let indexed = format!("{name}[");
                if lhs.starts_with(&indexed) && !t.contains("rng.") {
                    found.push(format!("{path}:{}: {t}", i + 1));
                }
            }
        }
    }
    found.sort();
    let want = ["b_im[m] = b_im[0].neg();", "b_re[m] = b_re[0].neg();"];
    assert_eq!(found.len(), 4, "the set of relations imposed on drawn values is no longer the declared one: {found:#?}");
    for f in &found {
        assert!(want.iter().any(|w| f.ends_with(w)), "an UNDECLARED relation is imposed on drawn values: {f}");
        assert!(f.starts_with("src/zk.rs:"), "a declared relation moved out of zk.rs: {f}");
    }
    // the two are in BOTH entry points, the legacy and the tagged one, and
    // nowhere else — four sites, two relations
    assert_eq!(found.iter().filter(|f| f.ends_with(want[0])).count(), 2, "`b_im[m] := -b_im[0]` is no longer in exactly the two mask-commit entry points");
    assert_eq!(found.iter().filter(|f| f.ends_with(want[1])).count(), 2, "`b_re[m] := -b_re[0]` is no longer in exactly the two mask-commit entry points");

    // THE THIRD DECLARED RELATION, which is NOT an overwrite: the H
    // zero-sum row's last entry is a position the loop never draws
    let proto_src = source("src/private_block/protocol.rs");
    let proto = production_text(&proto_src);
    assert!(proto.contains("for j in 0..n - 1 {"), "the H zero-sum loop's range moved; it may now draw the position it overwrites");
    assert!(proto.contains("h_data[r * n + n - 1] = sum.neg();"), "the H zero-sum row's closing entry moved");
    // and the closed form counts that row as n-1 draws, not n
    let sh = Shape::toy();
    let segs = block_segments(&sh);
    let lay = Layout::for_shape(&sh).expect("the toy layout");
    let zs = segs.iter().find(|s| s.what == "H zero-sum rows").expect("the zero-sum segment");
    assert_eq!(zs.count, 2 * (lay.n() as u64 - 1), "the zero-sum segment does not count n-1 draws per row");

    // NON-VACUITY: the scan sees a synthetic undeclared relation
    assert!(binding_name("let mut b_re = rng.fp_vec(2 * m);").as_deref() == Some("b_re"), "the scan cannot find the name a draw is bound to");
    assert!(binding_name("let pads = rng.fp_vec(rows * q);").as_deref() == Some("pads"), "the scan cannot find a let-bound draw");
    eprintln!("S36 assertion 6: exactly the declared relations are imposed on drawn values — `b_re[m] := -b_re[0]` and `b_im[m] := -b_im[0]` at both mask-commit entry points, and the H zero-sum closing entry at a position the loop never draws; nine production files scanned");
}

// =========================================================================
// ASSERTION 5 and 7 — where they live now
// =========================================================================

/// **ASSERTION 5 — the generator is never cloned or forked**, re-asserted
/// here at the type level so that this module's seven are seven, and cited
/// to the two halves stage 25 wrote (the source count of one construction
/// per prover) and to zkp-core's own copy of the probe.
///
/// **ASSERTION 7 — the key is fresh** — is a source scan and a
/// reachability argument, and stage 25's
/// `no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_
/// operating_system` is that assertion in full. It is cited here by name
/// and required to exist, so that deleting it fails this module too.
#[test]
fn assertions_five_and_seven_are_asserted_and_are_where_this_module_says_they_are() {
    use std::marker::PhantomData;
    struct Probe<T>(PhantomData<T>);
    trait NotCloneFallback {
        fn is_clone(&self) -> bool {
            false
        }
    }
    impl<T> NotCloneFallback for Probe<T> {}
    impl<T: Clone> Probe<T> {
        fn is_clone(&self) -> bool {
            true
        }
    }
    struct NeverClone;
    assert!(Probe::<u64>(PhantomData).is_clone(), "the Clone probe cannot see Clone");
    assert!(!Probe::<NeverClone>(PhantomData).is_clone(), "the Clone probe answers yes for a non-Clone type");
    assert!(!Probe::<ZkRng>(PhantomData).is_clone(), "ZkRng became Clone: assertion 5 is false and stage 36's own observers must be re-read for why");

    let s25 = source("src/private_block/s25_tests.rs");
    for cited in ["fn the_generator_is_never_cloned_and_each_prover_constructs_exactly_one()", "fn no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system()"] {
        assert!(s25.contains(cited), "stage 25's `{cited}` is gone; assertion 5 or 7 is no longer asserted anywhere");
    }
    // and the observers themselves did not weaken the type
    let rng_src = source("../zkp-core/src/rng.rs");
    for forbidden in ["impl Clone for ZkRng", "derive(Clone", "derive(Copy", "Serialize", "Deserialize"] {
        assert!(!rng_src.contains(forbidden), "zkp-core/src/rng.rs carries `{forbidden}`");
    }
    eprintln!("S36 assertions 5 and 7: the non-Clone probe passes with its two controls here and in zkp-core's own tests; stage 25's two scans are cited by name and still exist");
}

/// **THE ENDPOINT REPLICA IS THE ENDPOINT PREPARER'S OWN DRAW SEQUENCE.**
///
/// [`measure_endpoint`] is not the production function — it cannot be, as
/// `private_seam::prepare` and `endpoint_g::prepare` build their own
/// generators and live outside this stage's write set. What makes its
/// numbers the endpoint's numbers is this: both production bodies use their
/// generator in exactly two places, the mask-row fill and the commitment,
/// in that order, and the replica does the same two in the same order with
/// the same parameters.
///
/// This is the one measurement in the module that is a replica rather than
/// the thing itself, and the ledger says so in those words.
#[test]
fn the_endpoint_replica_is_the_endpoint_preparers_own_draw_sequence() {
    for (path, sig, commit) in [
        ("src/private_seam.rs", "fn prepare_with_rng(", "pcs::commit_zk_owned(&params, data, ntt, &ZkOpts::standard(&params), rng)"),
        ("src/private_block/endpoint_g.rs", "pub(crate) fn prepare(", "pcs::commit_zk_owned_tagged(&params, data, ntt, &ZkOpts::standard(&params), &mut rng, tag)"),
    ] {
        let body = fn_body(&source(path), sig);
        assert_eq!(body.matches("rng.").count(), 1, "{path}: the endpoint preparer uses its generator somewhere new");
        assert!(body.contains("*x = rng.fp();"), "{path}: the mask-row fill moved");
        assert!(body.contains("for x in &mut data[first_mask * n..]"), "{path}: the mask rows are no longer the rows above `first_mask`");
        assert!(body.contains(commit), "{path}: the commitment call moved; the replica's parameters may no longer be the production ones");
        assert!(body.contains("let first_mask = spec.data_rows();"), "{path}: `first_mask` is no longer the spec's data rows");
    }
    eprintln!("S36 replica fidelity: both endpoint preparers use their generator in exactly two places — the mask-row fill above `data_rows`, then the commitment — which is what `measure_endpoint` does");
}

// ---------------------------------------------------------------- pins and helpers

/// a source file of this crate, read at test time
fn source(rel: &str) -> String {
    let p = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(rel);
    std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("cannot read {}: {e}", p.display()))
}

/// the part of a source file above its own `#[cfg(test)] mod tests {` — the
/// production text, which is what every scan here is over
fn production_text(src: &str) -> &str {
    let cut = src.find("\n#[cfg(test)]\nmod tests {").map(|k| k + 1).unwrap_or(src.len());
    &src[..cut]
}

/// the body of a function, from its signature to the next item at column
/// zero (the same cut stage 25's scans use)
fn fn_body(src: &str, signature: &str) -> String {
    let start = src.find(signature).unwrap_or_else(|| panic!("`{signature}` is gone"));
    let body = &src[start..];
    let end = body[1..].find("\n}\n").map(|i| i + 2).unwrap_or(body.len());
    body[..end].to_string()
}

/// the name a `let` binds, for a line that draws from the generator
fn binding_name(line: &str) -> Option<String> {
    let t = line.trim().strip_prefix("let ")?;
    let t = t.strip_prefix("mut ").unwrap_or(t);
    let name: String = t.chars().take_while(|c| c.is_ascii_alphanumeric() || *c == '_').collect();
    if name.is_empty() {
        None
    } else {
        Some(name)
    }
}

// =========================================================================
// STAGE 46 — THE GENERATORS' DRAWS MEASURED AT RUNG-G AND 125M, for a
// STANDALONE block and for a TWO-BLOCK rung-G RUN (obligation 6a of
// `ZK60_SHAPED_PRIVACY_PATH_STATUS.md`, §3 of
// `ZK60_HASH_LAYER_STANDALONE_TAGGED_BLOCK_DISPOSITION.md`)
// =========================================================================
//
// Until this stage the draw counts were MEASURED only at the toy (327,052
// per proof) and at the five development rungs of stage 36; the
// standalone-block hash-layer argument uses COUNTED figures at rung-G
// (701,876 per proof) and 125M (9,212,588 per proof), and the run's
// argument a COUNTED per-run total. This section measures them with the
// same observers and the same honesty rules as stage 36:
//
// * the BLOCK generator in situ — `measure_block`, `prove_inner_at`'s body
//   with the generator and the transcript OURS, the receipt verified before
//   a counter is read;
// * the two ENDPOINT generators on the REPLICA (finding S36-F2 stands: the
//   generator is built and dropped inside `endpoint_g::prepare`, and the
//   one-line `prepare_with_rng` that would expose it is a production change
//   this stage may not make) — and, new here, the objects those real
//   generators filled, READ in situ off the real owners' commitments
//   (`endpoint_object_counts`);
// * the RUN's one generator in situ — `s46_measure_run`, `prove_run`'s body
//   with the generator and the transcript ours, every draw made by the
//   production `boundary::prepare` and `protocol::prove_core`, the segments
//   verified by the production `run::verify_run` before a counter is read.
//   A run's two stage boundaries ARE points where the caller holds the
//   generator, so the per-boundary and per-stage consumption is measured,
//   not derived (the run-level half of S36-F3 closes here; the split INSIDE
//   `prove_core` stays derived).
//
// What the accessor reports is STREAM BYTES: `16 x fp() + 32 x bytes32()`.
// Where a table below says "field draws" it is the measured bytes less 32
// per salt, over 16, with the salt count taken from the geometry (every
// salt is one leaf of a commitment whose leaf count is its encoded column
// count) — the same reading stage 36's figures of record were made under.
//
// COUNTS ONLY, as everywhere in this module: no key, stream byte, challenge
// or drawn value is printed, returned or compared. Not a privacy result.

/// **THE COUNTED FIGURES A STANDALONE BLOCK IS MEASURED AGAINST**, copied as
/// literals from the independent check of the standalone tagged block's hash
/// layer: `results/zk60_hash_layer_standalone_block_check/
/// check_standalone_block.json` (main tree, commit `cb83a97`), object
/// `targets.<shape>` — `draws.{A, H, M, block_fp, block_salts, E_each,
/// E_salts_each, proof_fp, proof_salts}`, `transcript.squeezes` (the GATE's
/// measured `counter`, round 9j, `against_the_gate.pairs.counter`),
/// `transcript.replay_points` and `frame_bytes`. Never recomputed in this
/// crate: two routes to one number is the point.
struct Counted {
    label: &'static str,
    /// `A`'s field draws: its mask and proximity rows plus its pads
    a_fp: u64,
    /// `H`'s: mask and proximity rows, the two zero-sum rows, pads
    h_fp: u64,
    /// `M`'s: CFS coefficients, per-row pads, `b` / `u`
    m_fp: u64,
    block_fp: u64,
    block_salts: u64,
    /// ONE external endpoint's field draws and salts
    e_fp: u64,
    e_salts: u64,
    /// per proof, over the three generators
    proof_fp: u64,
    proof_salts: u64,
    squeezes: u64,
    replay: u64,
    frame: usize,
}

const S46_RUNG_G: Counted = Counted {
    label: "rung-G",
    a_fp: 411_392,
    h_fp: 258_046,
    m_fp: 17_590,
    block_fp: 687_028,
    block_salts: 12_288,
    e_fp: 7_424,
    e_salts: 4_096,
    proof_fp: 701_876,
    proof_salts: 20_480,
    squeezes: 2_356,
    replay: 1_394,
    frame: 4_234_984,
};

const S46_M125: Counted = Counted {
    label: "125M",
    a_fp: 5_484_800,
    h_fp: 3_526_654,
    m_fp: 18_350,
    block_fp: 9_029_804,
    block_salts: 135_168,
    e_fp: 91_392,
    e_salts: 65_536,
    proof_fp: 9_212_588,
    proof_salts: 266_240,
    squeezes: 14_252,
    replay: 13_050,
    frame: 40_783_352,
};

/// **THE RUN'S COUNTED PARTS**, `ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md` §6.2 as
/// ruling H-6 lists them (after the S19-F1 repair, `8c5922b`): per internal
/// boundary 8,704 field draws at rung-G and 108,032 at 125M; per run
/// 2,093,340 (rung-G, `L = 3`) and 109,728,784 (125M, `L = 12`). The
/// boundary's SALTS are that memo's per-run salted-leaf totals (53,248 at
/// rung-G `L = 3`, 2,473,984 at 125M `L = 12`, its F_L row) less the blocks'
/// and the two external endpoints', over the `L - 1` boundaries.
const S46_RUNG_G_BOUNDARY_FP: u64 = 8_704;
const S46_RUNG_G_BOUNDARY_SALTS: u64 = 4_096;
const S46_M125_BOUNDARY_FP: u64 = 108_032;
const S46_M125_BOUNDARY_SALTS: u64 = 65_536;
const S46_RUNG_G_RUN3_FP: u64 = 2_093_340;
const S46_RUNG_G_RUN3_SALTS: u64 = 53_248;
const S46_M125_RUN12_FP: u64 = 109_728_784;
const S46_M125_RUN12_SALTS: u64 = 2_473_984;
/// The 125M `L = 12` figure BEFORE the S19-F1 repair (62 draws per block
/// fewer), which the run-composition memo counted and which is still quoted
/// in places. Printed beside the measurement, never asserted.
const S46_M125_RUN12_FP_PRE_REPAIR: u64 = 109_728_040;

/// **THE RUN GATE'S MEASURED squeeze count** of a dense rung-G `L = 3` run
/// (`zk60_native_run_gate_s20/run-g-dense-s20.json`, `final_counter`, quoted
/// in `ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md` §1.3's table). Used only to check
/// the squeeze MODEL below before that model predicts `L = 2`.
const S46_RUNG_G_RUN3_SQUEEZES: u64 = 6_924;

/// Control C7's rule (`ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md` §1.3): every PCS
/// opening squeezes 64 times for its column indices.
const S46_SQUEEZES_PER_OPENING: u64 = 64;

fn s46_context() -> Digest {
    *blake3::hash(b"private block: stage 46, the draws at rung-G and 125M").as_bytes()
}

/// **A RUN'S LIVE SQUEEZES AND REPLAYED POINTS, as a MODEL built from one
/// standalone block's figures** — DERIVED here, stated by no document for
/// `L = 2`. A standalone block is `core + two endpoint openings`; a run is
/// `L cores + two endpoint openings + L - 1 boundary openings`. An opening's
/// live challenges (and its replay's points) are its group members plus its
/// rows — `1 + endpoint_rows` for an external endpoint, `sites +
/// boundary_rows` for a boundary — and, for squeezes only, C7's 64 index
/// squeezes per PCS opening, of which a block has five (`M`, `A`, `H`, two
/// endpoints) and a run `4L + 1`. Returns `(squeezes, replay points)`.
fn s46_run_model(c: &Counted, sh: &Shape, l: u64, boundary_rows: u64) -> (u64, u64) {
    let e_open = 1 + sh.endpoint_rows as u64;
    let b_open = super::run::BOUNDARY_SITES as u64 + boundary_rows;
    let core_squeezes = c.squeezes - 5 * S46_SQUEEZES_PER_OPENING - 2 * e_open;
    let core_replay = c.replay - 2 * e_open;
    let squeezes = l * core_squeezes + 2 * e_open + (l - 1) * b_open + (4 * l + 1) * S46_SQUEEZES_PER_OPENING;
    let replay = l * core_replay + 2 * e_open + (l - 1) * b_open;
    (squeezes, replay)
}

/// one line of the stage-46 table: shape, scope, generator, quantity,
/// MEASURED (or read / derived — `how` says which), COUNTED
struct Row {
    shape: &'static str,
    scope: &'static str,
    generator: &'static str,
    quantity: &'static str,
    got: u64,
    want: u64,
    how: &'static str,
}

/// Print EVERY row first, then fail once with the full list of mismatches —
/// so that one run reports the whole table even when a figure disagrees.
fn s46_report(rows: &[Row]) {
    for r in rows {
        eprintln!(
            "S46 | {:<6} | {:<26} | {:<30} | {:<26} | measured {:>11} | counted {:>11} | {} | {}",
            r.shape,
            r.scope,
            r.generator,
            r.quantity,
            r.got,
            r.want,
            if r.got == r.want { "EQUAL" } else { "MISMATCH" },
            r.how
        );
    }
    let bad: Vec<String> = rows.iter().filter(|r| r.got != r.want).map(|r| format!("{} {} {} {}: measured {} counted {} ({})", r.shape, r.scope, r.generator, r.quantity, r.got, r.want, r.how)).collect();
    assert!(bad.is_empty(), "stage 46: {} measured figure(s) differ from the counted ones: {bad:#?}", bad.len());
}

/// field draws carried by `bytes` stream bytes, given the salt count
fn s46_fp_of(bytes: u64, salts: u64, what: &str) -> u64 {
    assert!(bytes >= BYTES_PER_SALT * salts, "{what}: fewer stream bytes than its salts alone");
    let rest = bytes - BYTES_PER_SALT * salts;
    assert_eq!(rest % BYTES_PER_FP, 0, "{what}: the stream is not 32 per salt plus 16 per field draw");
    rest / BYTES_PER_FP
}

/// the field draws of the closed-form segments whose name starts with `role`
fn s46_role_fp(segs: &[Seg], role: &str) -> u64 {
    segs.iter().filter(|s| s.kind == Kind::Fp && s.what.starts_with(role)).map(|s| s.count).sum()
}

/// each generalised endpoint's REPLICA: `(stream bytes, fp draws, salts)`
fn s46_endpoint_replicas(spec: &IoSpec) -> [(u64, u64, u64); 2] {
    assert!(spec.general, "a shaped statement rides the generalised endpoint");
    let [si, so] = spec.endpoints_g().expect("the generalised endpoint specs");
    let ntt = NttTables::new(si.enc_log().max(so.enc_log()));
    let tag = spec.hash_tag;
    let mut out = [(0u64, 0u64, 0u64); 2];
    for (k, s) in [&si, &so].into_iter().enumerate() {
        out[k] = measure_endpoint(s.commitment_rows(), s.data_rows(), &s.params(), Some(&tag), &ntt, Fp::ZERO);
    }
    out
}

/// what one standalone block proof's three generators and live transcript did
struct Standalone {
    segs: Vec<Seg>,
    block: Measured,
    /// each endpoint's REPLICA: `(stream bytes, fp draws, salts)`
    replica: [(u64, u64, u64); 2],
    /// the witness build + endpoint owners, then the measured proof with its
    /// two verifications, in seconds
    secs: (f64, f64),
    blk: BlockPublic,
    expected: ExpectedIo,
}

/// **ONE STANDALONE BLOCK AT `sh`**, on the fully dense run recipe (the
/// GENERIC witness stage 45's bundles were proved on: every public word
/// nonzero, a non-constant hidden input). Consumption does not depend on the
/// witness (assertion 3), so the choice only makes the proof a real one.
fn s46_measure_standalone(sh: &Shape) -> Standalone {
    let t0 = std::time::Instant::now();
    let (p, f, x) = super::dense_tests::dense_run_case(sh);
    let blk = BlockPublic::new(p, f);
    let wit = witness::build_shaped(sh, blk.attention(), blk.feed_forward(), &x).expect("the dense generic witness");
    drop(x);
    let ids = Ids::new(sh).expect("the shape's plane map");
    let spec = IoSpec::new_shaped(sh, s46_context(), 0, 0).expect("the shaped endpoint spec");
    let (expected, owners) = prepare_endpoints(spec.clone(), &padded(&wit, ids.at(A_X)), &padded(&wit, ids.at(A_X2))).expect("the two endpoint owners");
    let built = t0.elapsed().as_secs_f64();
    let t1 = std::time::Instant::now();
    let block = measure_block(sh, &blk, wit, &expected, owners);
    let proved = t1.elapsed().as_secs_f64();
    let replica = s46_endpoint_replicas(&spec);
    Standalone { segs: block_segments(sh), block, replica, secs: (built, proved), blk, expected }
}

/// the stage-46 table rows of one standalone block, against `c`
fn s46_standalone_rows(c: &Counted, sh: &Shape, r: &Standalone) -> Vec<Row> {
    let (segs, m) = (&r.segs, &r.block);
    let salts = total_salts(segs);
    let fp = s46_fp_of(m.consumed, salts, "the block stream");
    let lay = Layout::for_shape(sh).expect("the shape has a layout");
    let s = c.label;
    let mut rows = vec![
        Row { shape: s, scope: "standalone block", generator: "block (in situ)", quantity: "stream bytes", got: m.consumed, want: BYTES_PER_FP * c.block_fp + BYTES_PER_SALT * c.block_salts, how: "MEASURED, ZkRng::consumed_bytes" },
        Row { shape: s, scope: "standalone block", generator: "block (in situ)", quantity: "field draws", got: fp, want: c.block_fp, how: "MEASURED bytes at the geometry's salts" },
        Row { shape: s, scope: "standalone block", generator: "block (in situ)", quantity: "salts", got: salts, want: c.block_salts, how: "GEOMETRY (A, H columns; M domain)" },
        Row { shape: s, scope: "standalone block", generator: "block (in situ)", quantity: "refills", got: m.refills, want: m.consumed.div_ceil(ZkRng::OBSERVED_BLOCK_BYTES), how: "MEASURED vs its own bytes" },
        Row { shape: s, scope: "standalone block", generator: "block: A", quantity: "field draws", got: s46_role_fp(segs, "A "), want: c.a_fp, how: "DERIVED closed form (S36-F3)" },
        Row { shape: s, scope: "standalone block", generator: "block: H", quantity: "field draws", got: s46_role_fp(segs, "H "), want: c.h_fp, how: "DERIVED closed form (S36-F3)" },
        Row { shape: s, scope: "standalone block", generator: "block: M", quantity: "field draws", got: s46_role_fp(segs, "M "), want: c.m_fp, how: "DERIVED closed form (S36-F3)" },
        Row { shape: s, scope: "standalone block", generator: "block: A+H+M", quantity: "field draws", got: total_fp(segs), want: fp, how: "DERIVED = MEASURED" },
    ];
    for k in 0..2 {
        let (b, f, sa) = r.replica[k];
        let (masks, pads, osalts) = m.endpoint_objects[k];
        let (g_rep, g_obj) = if k == 0 { ("endpoint in: REPLICA", "endpoint in: real owner") } else { ("endpoint out: REPLICA", "endpoint out: real owner") };
        rows.push(Row { shape: s, scope: "standalone block", generator: g_rep, quantity: "stream bytes", got: b, want: BYTES_PER_FP * c.e_fp + BYTES_PER_SALT * c.e_salts, how: "MEASURED on the replica (S36-F2)" });
        rows.push(Row { shape: s, scope: "standalone block", generator: g_rep, quantity: "field draws", got: f, want: c.e_fp, how: "MEASURED on the replica (S36-F2)" });
        rows.push(Row { shape: s, scope: "standalone block", generator: g_rep, quantity: "salts", got: sa, want: c.e_salts, how: "MEASURED on the replica (S36-F2)" });
        rows.push(Row { shape: s, scope: "standalone block", generator: g_obj, quantity: "mask words + pads", got: masks + pads, want: c.e_fp, how: "READ in situ off the real commitment" });
        rows.push(Row { shape: s, scope: "standalone block", generator: g_obj, quantity: "salts", got: osalts, want: c.e_salts, how: "READ in situ off the real commitment" });
    }
    let proof_fp = fp + r.replica[0].1 + r.replica[1].1;
    let proof_salts = salts + r.replica[0].2 + r.replica[1].2;
    let points: u64 = m.replay.iter().map(|call| call.draws).sum();
    rows.push(Row { shape: s, scope: "standalone block", generator: "all three", quantity: "field draws per proof", got: proof_fp, want: c.proof_fp, how: "sum of the three above" });
    rows.push(Row { shape: s, scope: "standalone block", generator: "all three", quantity: "salts per proof", got: proof_salts, want: c.proof_salts, how: "sum of the three above" });
    rows.push(Row { shape: s, scope: "standalone block", generator: "live transcript", quantity: "squeezes", got: m.squeezes, want: c.squeezes, how: "MEASURED, Transcript::squeezes; counted = the GATE's" });
    rows.push(Row { shape: s, scope: "standalone block", generator: "refusal replay", quantity: "points", got: points, want: c.replay, how: "MEASURED, the stage-36 observer" });
    rows.push(Row { shape: s, scope: "standalone block", generator: "receipt", quantity: "frame bytes", got: m.frame as u64, want: c.frame as u64, how: "MEASURED, the verified frame" });
    // the refusal replay's shape: four calls, all accepted, each drawing its
    // commitment's own row count of proximity coefficients
    assert_eq!(m.replay.len(), 4, "{s}: a standalone block no longer makes exactly four refusal replays");
    let want_rows = [lay.a_rows as u64, lay.h_rows as u64, sh.endpoint_rows as u64, sh.endpoint_rows as u64];
    for (k, call) in m.replay.iter().enumerate() {
        assert_eq!(call.verdict, super::draw_observer::Verdict::Accepted, "{s}: replay {k} did not accept");
        assert_eq!(call.rho_draws(), want_rows[k], "{s}: replay {k} drew {} proximity coefficients, its commitment has {} rows", call.rho_draws(), want_rows[k]);
    }
    // the replica and the real owners hold the same counts, whatever the
    // counted figures say
    for k in 0..2 {
        let (masks, pads, osalts) = m.endpoint_objects[k];
        assert_eq!((masks + pads, osalts), (r.replica[k].1, r.replica[k].2), "{s}: endpoint {k}'s replica and its real owner disagree");
    }
    rows
}

/// **THE STANDALONE BLOCK AT RUNG-G, ALL THREE GENERATORS**, against the
/// check's 687,028 + 2 x 7,424 = 701,876 field draws and 20,480 salts per
/// proof, and the gate's 2,356 squeezes.
#[test]
fn s46_a_standalone_rung_g_block_draws_the_counted_figures_on_each_of_its_three_generators() {
    let sh = Shape::rung_g();
    let r = s46_measure_standalone(&sh);
    eprintln!("S46 rung-G standalone: witness + owners {:.2} s, proof + two verifications {:.2} s, peak RSS {:.0} MiB (shared box)", r.secs.0, r.secs.1, super::run::peak_rss_mib());
    let rows = s46_standalone_rows(&S46_RUNG_G, &sh, &r);
    s46_report(&rows);
}

/// the private side of a run, handed out one stage at a time —
/// `run_tests::Chain::from_parts` restated, because that one is private to
/// its module: `inputs[k]` is block `k`'s true hidden input, `planes` the
/// `L + 1` padded planes the run's IO commitments carry
struct S46Chain {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
}

impl S46Chain {
    /// the honest chain of `l` blocks on the fully dense RUN recipe
    fn dense(sh: &Shape, l: usize) -> S46Chain {
        let (public, ff, x0) = super::dense_tests::dense_run_case(sh);
        let ids = Ids::new(sh).expect("the shape has a plane map");
        let (mut inputs, mut planes) = (Vec::with_capacity(l), Vec::with_capacity(l + 1));
        let mut x = x0;
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).expect("an honest dense witness of the chain");
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            let out = w.output().expect("the block's hidden output");
            x = (0..sh.tokens).flat_map(|t| out[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect();
        }
        S46Chain { sh: sh.clone(), public, ff, inputs, planes }
    }
}

impl super::run::RunWitnessSource for S46Chain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        witness::build_shaped(&self.sh, &self.public, &self.ff, &self.inputs[k])
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(self.planes[k + 1].clone())
    }
}

/// a segment's transcript position tag: `run.rs`'s private `position_tag`,
/// restated (a discarded clone squeezes two `Fp2`). The run VERIFIER compares
/// every segment's header and trailer with its own, so a replica that got
/// this wrong would not produce a run that verifies.
fn s46_position_tag(tr: &crate::transcript::Transcript) -> [u8; 32] {
    let mut c = crate::transcript::Transcript::clone_state(tr);
    let v = c.challenge_fp2_vec(2);
    let mut out = [0u8; 32];
    out[..16].copy_from_slice(&v[0].to_bytes());
    out[16..].copy_from_slice(&v[1].to_bytes());
    out
}

/// what the run's ONE generator and its live transcript did
struct RunMeasured {
    /// the run generator's stream bytes, from `ZkRng::consumed_bytes`
    consumed: u64,
    refills: u64,
    /// what `boundary::prepare` took from the run's generator, per boundary
    boundary_bytes: Vec<u64>,
    /// what `protocol::prove_core` took from it, per stage
    stage_bytes: Vec<u64>,
    squeezes: u64,
    replay: Vec<super::draw_observer::Call>,
    segments: Vec<usize>,
    /// the two REAL external endpoint owners' `(mask words, pads, salts)`
    endpoint_objects: [(u64, u64, u64); 2],
}

/// **`prove_run`'s body, with the run's generator and transcript ours.**
///
/// Every step is the production function's, in its order: the endpoint
/// owners checked against the statement, the ONE generator on
/// `hash_domain::run_seed_domain(profile)`, the run's NTT table, the run
/// header — rebuilt from the statement's public words exactly as the run
/// capture rebuilds it, and required to BE the statement's binding — then per
/// stage: the start tag, the two locality absorbs, the boundary committed by
/// the production `boundary::prepare` on the run's generator and its root
/// absorbed, the stage layout, the production `protocol::prove_core` on the
/// same generator, the incoming opening (the previous boundary with the
/// pending claim, or the external input endpoint), the outgoing one (the
/// external output endpoint, last stage only), the end tag, the segment.
/// The generator is read between those steps — which is what a run offers
/// and a single block does not — and the segments are VERIFIED by the
/// production `run::verify_run` before any number is returned.
/// [`s46_the_replicas_draw_where_the_production_provers_draw`] holds the
/// production body to the two draw sites this replica calls.
fn s46_measure_run(st: &super::run::RunStatement, blocks: &[BlockPublic], src: &mut dyn super::run::RunWitnessSource, expected: &ExpectedIo, externals: Endpoints) -> RunMeasured {
    use super::boundary::{self, BoundarySpec, PreparedBoundary};
    use super::wire::{self, SegGeom, Segment};
    use crate::pcs::ZClaim;
    let session = super::draw_observer::Session::open();
    let rs = st.rs();
    let (sh, l) = (rs.sh(), rs.l());
    // THE RUN HEADER, rebuilt from the public words, as `run_capture` does
    let hdr = st.capture_header().expect("the run's public words");
    assert_eq!(hdr.expected_bytes, expected.to_bytes(), "the endpoint policy handed in is not the statement's");
    let mut tr = protocol::tagged_transcript(sh, hdr.profile.as_bytes());
    let mut shape_bytes = Vec::with_capacity(hdr.run_shape_words.len() * 8);
    for v in &hdr.run_shape_words {
        shape_bytes.extend_from_slice(&v.to_le_bytes());
    }
    tr.absorb(b"run-shape", &shape_bytes);
    tr.absorb(b"expected-IO", &hdr.expected_bytes);
    tr.absorb(b"public-statement", &hdr.public_statement);
    tr.absorb(b"parameters", hdr.parameter_line.as_bytes());
    tr.absorb(b"calibration", &hdr.calibration);
    tr.absorb(b"schedule", &hdr.schedule_digest);
    let binding = tr.state();
    assert_eq!(binding, st.binding().expect("the run binding"), "the rebuilt run header is not the statement's binding");
    assert_eq!(tr.squeezes(), 0, "the run header squeezed");
    let [ein, eout] = protocol::check_endpoints(sh, expected, externals).expect("the external endpoint owners match the statement");
    let endpoint_objects = [endpoint_object_counts(sh, &ein), endpoint_object_counts(sh, &eout)];
    let (mut ein, mut eout) = (Some(ein), Some(eout));
    let mut rng = ZkRng::from_os(&super::hash_domain::run_seed_domain(rs.profile())).expect("OS randomness");
    assert_eq!(rng.consumed_bytes(), 0, "a fresh generator has already consumed");
    let tag = sh.hash_tag();
    let ntt = NttTables::new(protocol::ntt_log_at(sh).max((sh.endpoint_log_n + sh.endpoint_inv_rate.trailing_zeros() as usize) as u32));
    let boundary_rows = if l > 1 { st.boundary_spec(0).expect("the first boundary").commitment_rows() } else { 0 };
    let in_site = |k: usize| -> usize { if k == 0 { rs.data_rows() } else { st.boundary_spec(k - 1).expect("the incoming boundary").mask_row(1).expect("its second site") } };
    let out_site = |k: usize| -> usize { if k + 1 == l { rs.data_rows() } else { st.boundary_spec(k).expect("the outgoing boundary").mask_row(0).expect("its first site") } };
    let mut pending: Vec<ZClaim> = Vec::new();
    let mut prev: Option<(BoundarySpec, PreparedBoundary)> = None;
    let (mut boundary_bytes, mut stage_bytes, mut encoded) = (Vec::new(), Vec::new(), Vec::<Vec<u8>>::new());
    for k in 0..l {
        let mut ph = super::timing::Phases::start();
        let mut phases: Vec<(&'static str, f64)> = Vec::new();
        let mut tick = std::time::Instant::now();
        let start_tag = s46_position_tag(&tr);
        tr.absorb_u64(b"pb-run-stage", k as u64);
        tr.absorb(b"pb-run-block", &hdr.block_digests[k]);
        let at_stage = rng.consumed_bytes();
        let cur = if k + 1 < l {
            let spec = st.boundary_spec(k).expect("boundary k");
            let plane = src.boundary_plane(k).expect("boundary k's plane");
            assert_eq!(plane.len(), spec.len(), "boundary {k}'s plane is not the padded plane");
            let words: Vec<Fp> = plane.iter().map(|x| Fp::from_i64(i64::from(*x))).collect();
            let p = boundary::prepare(&spec, &words, &ntt, &mut rng, &tag).expect("the boundary commits");
            protocol::absorb_root(&mut tr, b"B", &p.root(), spec.commitment_rows(), spec.log_n());
            boundary_bytes.push(rng.consumed_bytes() - at_stage);
            Some((spec, p))
        } else {
            None
        };
        let at_core = rng.consumed_bytes();
        let lay = Layout::for_shape(sh).expect("the shape has a layout").with_io_mask_rows([in_site(k), out_site(k)]);
        let wit = src.witness(k).expect("block k's witness");
        let core = {
            let in_data: &[Fp] = match &prev {
                Some((_, p)) => p.data(),
                None => &ein.as_ref().expect("the input endpoint").data,
            };
            let out_data: &[Fp] = match &cur {
                Some((_, p)) => p.data(),
                None => &eout.as_ref().expect("the output endpoint").data,
            };
            protocol::prove_core(sh, &lay, &blocks[k], wit, [in_data, out_data], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).expect("the stage's core prover")
        };
        let after_core = rng.consumed_bytes();
        stage_bytes.push(after_core - at_core);
        let [ic, oc] = core.io_claims;
        let in_open = match prev.take() {
            Some((spec, owner)) => {
                let mut claims = std::mem::take(&mut pending);
                claims.extend(ic);
                owner.into_opening(&spec, &claims, &mut tr).expect("the boundary opens")
            }
            None => {
                let e = ein.take().expect("the input endpoint");
                protocol::check_endpoint_opening(&ic, sh, &tr).expect("the input endpoint's refusal checks");
                pcs::open_zk(&e, &ic, &mut tr)
            }
        };
        let out_open = if k + 1 == l {
            let e = eout.take().expect("the output endpoint");
            protocol::check_endpoint_opening(&oc, sh, &tr).expect("the output endpoint's refusal checks");
            Some(pcs::open_zk(&e, &oc, &mut tr))
        } else {
            pending = oc;
            None
        };
        assert_eq!(rng.consumed_bytes(), after_core, "stage {k}: an opening drew from the run's generator");
        let end_tag = s46_position_tag(&tr);
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
        let bytes = wire::encode_segment(&seg, &lay, SegGeom { l, k, boundary_rows, sites: super::run::BOUNDARY_SITES }, &binding, &start_tag, &end_tag).expect("the segment encodes");
        encoded.push(bytes);
        prev = cur;
    }
    let replay = session.calls();
    let measured = RunMeasured {
        consumed: rng.consumed_bytes(),
        refills: rng.refills(),
        boundary_bytes,
        stage_bytes,
        squeezes: tr.squeezes(),
        replay,
        segments: encoded.iter().map(|s| s.len()).collect(),
        endpoint_objects,
    };
    drop(rng);
    drop(tr);
    // the run this stream produced is a real one, or the numbers mean nothing
    super::run::verify_run(st, blocks, &encoded).expect("the measured run verifies from its segments");
    measured
}

/// **ONE INTERNAL BOUNDARY, OUTSIDE A RUN**: the production
/// `boundary::prepare` of the statement's boundary `k`, handed a generator we
/// can read — exactly as `prove_run` hands it the run's. The boundary takes
/// its generator from its caller by design, so this is the preparer itself
/// and not a replica; what it is NOT is a boundary inside a run that
/// verifies (the rung-G run test measures that, and checks the two agree).
/// Returns the stream bytes.
fn s46_measure_boundary(st: &super::run::RunStatement, k: usize) -> u64 {
    let spec = st.boundary_spec(k).expect("the boundary");
    let ntt = NttTables::new(spec.enc_log());
    let mut rng = ZkRng::from_os(&super::hash_domain::run_seed_domain(st.rs().profile())).expect("OS randomness");
    let zeros = vec![Fp::ZERO; spec.len()];
    let p = super::boundary::prepare(&spec, &zeros, &ntt, &mut rng, &st.rs().sh().hash_tag()).expect("the boundary commits");
    drop(p);
    rng.consumed_bytes()
}

/// **A TWO-BLOCK RUNG-G RUN, THE RUN'S ONE GENERATOR IN SITU**, against the
/// run memo's counted parts (per block 687,028 + 12,288 salts, per boundary
/// 8,704 + 4,096, per external endpoint 7,424 + 4,096) — so, for `L = 2`,
/// 1,382,760 field draws and 28,672 salts on the run's stream and 1,397,608
/// over the run's three generators (arithmetic on the counted parts; no
/// document states an `L = 2` total). The measured parts are then summed at
/// `L = 3` against the memo's own 2,093,340 / 53,248.
#[test]
fn s46_a_two_block_rung_g_run_draws_the_counted_figures_on_its_one_generator() {
    let sh = Shape::rung_g();
    let c = &S46_RUNG_G;
    let l = 2usize;
    let t0 = std::time::Instant::now();
    let mut chain = S46Chain::dense(&sh, l);
    let blocks: Vec<BlockPublic> = (0..l).map(|_| BlockPublic::new(chain.public.clone(), chain.ff.clone())).collect();
    let spec = IoSpec::new_shaped(&sh, s46_context(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec.clone(), &chain.planes[0], &chain.planes[l]).expect("the run's external endpoint owners");
    let st = super::run::RunStatement::new(super::run::RunShape::rung_g(l).expect("the rung-G run shape"), s46_context(), expected.clone(), &blocks, &vec![(0, 0); l]).expect("the run statement");
    let bspec = st.boundary_spec(0).expect("the run's one boundary");
    let (b_rows, b_salts) = (bspec.commitment_rows() as u64, bspec.params().enc_cols() as u64);
    let m = s46_measure_run(&st, &blocks, &mut chain, &expected, owners);
    let secs = t0.elapsed().as_secs_f64();
    let replica = s46_endpoint_replicas(&spec);
    let outside = s46_measure_boundary(&st, 0);
    let segs = block_segments(&sh);
    let block_salts = total_salts(&segs);
    let s = c.label;
    let lu = l as u64;
    eprintln!("S46 rung-G run L=2: chain + statement + measured run + verify {secs:.2} s, segments {:?} B, peak RSS {:.0} MiB (shared box)", m.segments, super::run::peak_rss_mib());

    let run_salts = lu * block_salts + (lu - 1) * b_salts;
    let run_fp = s46_fp_of(m.consumed, run_salts, "the run stream");
    let b_fp = s46_fp_of(m.boundary_bytes[0], b_salts, "boundary 0");
    let mut rows = vec![
        Row { shape: s, scope: "run L=2", generator: "run (in situ)", quantity: "stream bytes", got: m.consumed, want: BYTES_PER_FP * (lu * c.block_fp + (lu - 1) * S46_RUNG_G_BOUNDARY_FP) + BYTES_PER_SALT * (lu * c.block_salts + (lu - 1) * S46_RUNG_G_BOUNDARY_SALTS), how: "MEASURED; counted = L x block + (L-1) x boundary" },
        Row { shape: s, scope: "run L=2", generator: "run (in situ)", quantity: "field draws", got: run_fp, want: lu * c.block_fp + (lu - 1) * S46_RUNG_G_BOUNDARY_FP, how: "MEASURED bytes at the geometry's salts" },
        Row { shape: s, scope: "run L=2", generator: "run (in situ)", quantity: "salts", got: run_salts, want: lu * c.block_salts + (lu - 1) * S46_RUNG_G_BOUNDARY_SALTS, how: "GEOMETRY" },
        Row { shape: s, scope: "run L=2", generator: "run (in situ)", quantity: "refills", got: m.refills, want: m.consumed.div_ceil(ZkRng::OBSERVED_BLOCK_BYTES), how: "MEASURED vs its own bytes" },
        Row { shape: s, scope: "run L=2", generator: "run: boundary 0", quantity: "stream bytes", got: m.boundary_bytes[0], want: BYTES_PER_FP * S46_RUNG_G_BOUNDARY_FP + BYTES_PER_SALT * S46_RUNG_G_BOUNDARY_SALTS, how: "MEASURED between two steps" },
        Row { shape: s, scope: "run L=2", generator: "run: boundary 0", quantity: "field draws", got: b_fp, want: S46_RUNG_G_BOUNDARY_FP, how: "MEASURED bytes at the geometry's salts" },
        Row { shape: s, scope: "run L=2", generator: "boundary 0 outside a run", quantity: "stream bytes", got: outside, want: m.boundary_bytes[0], how: "MEASURED; = the in-run boundary" },
    ];
    for (k, name) in [(0usize, "run: stage 0 prove_core"), (1, "run: stage 1 prove_core")] {
        rows.push(Row { shape: s, scope: "run L=2", generator: name, quantity: "stream bytes", got: m.stage_bytes[k], want: BYTES_PER_FP * c.block_fp + BYTES_PER_SALT * c.block_salts, how: "MEASURED between two steps" });
        rows.push(Row { shape: s, scope: "run L=2", generator: name, quantity: "field draws", got: s46_fp_of(m.stage_bytes[k], block_salts, name), want: c.block_fp, how: "MEASURED bytes at the geometry's salts" });
    }
    for k in 0..2 {
        let (masks, pads, osalts) = m.endpoint_objects[k];
        let (g_obj, g_rep) = if k == 0 { ("endpoint in: real owner", "endpoint in: REPLICA") } else { ("endpoint out: real owner", "endpoint out: REPLICA") };
        rows.push(Row { shape: s, scope: "run L=2", generator: g_obj, quantity: "mask words + pads", got: masks + pads, want: c.e_fp, how: "READ in situ off the real commitment" });
        rows.push(Row { shape: s, scope: "run L=2", generator: g_obj, quantity: "salts", got: osalts, want: c.e_salts, how: "READ in situ off the real commitment" });
        rows.push(Row { shape: s, scope: "run L=2", generator: g_rep, quantity: "field draws", got: replica[k].1, want: c.e_fp, how: "MEASURED on the replica (S36-F2)" });
    }
    let e_fp = replica[0].1 + replica[1].1;
    let e_salts = replica[0].2 + replica[1].2;
    rows.push(Row { shape: s, scope: "run L=2", generator: "all three", quantity: "field draws per run", got: run_fp + e_fp, want: lu * c.block_fp + (lu - 1) * S46_RUNG_G_BOUNDARY_FP + 2 * c.e_fp, how: "sum; counted = arithmetic on counted parts" });
    rows.push(Row { shape: s, scope: "run L=2", generator: "all three", quantity: "salts per run", got: run_salts + e_salts, want: lu * c.block_salts + (lu - 1) * S46_RUNG_G_BOUNDARY_SALTS + 2 * c.e_salts, how: "sum; counted = arithmetic on counted parts" });
    // the memo's own L = 3 figure, from the parts measured here
    let stage_fp = s46_fp_of(m.stage_bytes[0], block_salts, "stage 0");
    rows.push(Row { shape: s, scope: "run L=3 (sum of parts)", generator: "all three", quantity: "field draws per run", got: 3 * stage_fp + 2 * b_fp + e_fp, want: S46_RUNG_G_RUN3_FP, how: "sum of MEASURED parts vs COUNTED (H-6)" });
    rows.push(Row { shape: s, scope: "run L=3 (sum of parts)", generator: "all three", quantity: "salts per run", got: 3 * block_salts + 2 * b_salts + e_salts, want: S46_RUNG_G_RUN3_SALTS, how: "GEOMETRY vs COUNTED (F_L row)" });
    // the transcript, against the model built from the standalone block's
    // figures — checked first at L = 3 against the run gate's measurement
    let (sq3, _) = s46_run_model(c, &sh, 3, b_rows);
    let (sq2, rp2) = s46_run_model(c, &sh, lu, b_rows);
    let points: u64 = m.replay.iter().map(|call| call.draws).sum();
    rows.push(Row { shape: s, scope: "run L=3 (model)", generator: "live transcript", quantity: "squeezes", got: sq3, want: S46_RUNG_G_RUN3_SQUEEZES, how: "MODEL vs the run gate's MEASURED" });
    rows.push(Row { shape: s, scope: "run L=2", generator: "live transcript", quantity: "squeezes", got: m.squeezes, want: sq2, how: "MEASURED vs MODEL (DERIVED here)" });
    rows.push(Row { shape: s, scope: "run L=2", generator: "refusal replay", quantity: "points", got: points, want: rp2, how: "MEASURED vs MODEL (DERIVED here)" });
    let counted_segs = super::run_tests::counted_segment_bytes(&sh, l, b_rows as usize);
    for k in 0..l {
        rows.push(Row { shape: s, scope: "run L=2", generator: if k == 0 { "segment 0" } else { "segment 1" }, quantity: "bytes", got: m.segments[k] as u64, want: counted_segs[k] as u64, how: "MEASURED vs run_tests' counted length" });
    }
    // the replay's shape: A and H per stage, the input endpoint, the
    // boundary (two groups), the output endpoint — every one accepted
    let lay = Layout::for_shape(&sh).expect("the layout");
    let want_rows = [lay.a_rows as u64, lay.h_rows as u64, sh.endpoint_rows as u64, lay.a_rows as u64, lay.h_rows as u64, b_rows, sh.endpoint_rows as u64];
    assert_eq!(m.replay.len(), want_rows.len(), "a two-block run no longer makes seven refusal replays");
    for (k, call) in m.replay.iter().enumerate() {
        assert_eq!(call.verdict, super::draw_observer::Verdict::Accepted, "run replay {k} did not accept");
        assert_eq!(call.rho_draws(), want_rows[k], "run replay {k} drew {} proximity coefficients, its commitment has {} rows", call.rho_draws(), want_rows[k]);
    }
    assert_eq!(m.replay[5].group_draws, super::run::BOUNDARY_SITES as u64, "the boundary's opening is no longer one group per site");
    s46_report(&rows);
}

/// **THE STANDALONE BLOCK AT 125M, ALL THREE GENERATORS — HEAVY** (one 125M
/// proof, ~30 s and ~10 GiB; run DETACHED under the heavy lock with
/// `MALLOC_MMAP_THRESHOLD_` pinned). Against the check's 9,029,804 + 2 x
/// 91,392 = 9,212,588 field draws and 266,240 salts per proof and the gate's
/// 14,252 squeezes; then the production `boundary::prepare` at the 125M run's
/// boundary geometry on a generator we hand it (108,032 + 65,536), and the
/// twelve-block run total as a SUM OF MEASURED PARTS against the run memo's
/// 109,728,784 / 2,473,984 (the pre-repair 109,728,040 is printed beside it).
#[test]
#[ignore = "HEAVY: one 125M standalone block proof (~30 s, ~10 GiB peak); run detached under /tmp/zk-heavy.lock with MALLOC_MMAP_THRESHOLD_=131072"]
fn s46_a_standalone_125m_block_draws_the_counted_figures_on_each_of_its_three_generators() {
    let sh = Shape::m125();
    let c = &S46_M125;
    let t0 = std::time::Instant::now();
    let r = s46_measure_standalone(&sh);
    let hwm_block = super::run::peak_rss_mib();
    eprintln!(
        "S46 125M standalone: witness + owners {:.2} s, proof + typed verify + encode + verify from bytes {:.2} s, peak RSS after the proof {hwm_block:.0} MiB (shared box, one run)",
        r.secs.0, r.secs.1
    );
    let mut rows = s46_standalone_rows(c, &sh, &r);
    // the 125M run's boundary: the statement is built at L = 2 only to name
    // the boundary spec — its geometry does not depend on L, only its index
    let blocks = vec![r.blk.clone(), r.blk.clone()];
    let st = super::run::RunStatement::new(super::run::RunShape::m125(2).expect("the 125M run shape"), s46_context(), r.expected.clone(), &blocks, &[(0, 0), (0, 0)]).expect("a 125M run statement");
    drop(blocks);
    let bspec = st.boundary_spec(0).expect("the 125M boundary");
    let b_salts = bspec.params().enc_cols() as u64;
    let b_bytes = s46_measure_boundary(&st, 0);
    let b_fp = s46_fp_of(b_bytes, b_salts, "the 125M boundary");
    let s = c.label;
    rows.push(Row { shape: s, scope: "run boundary (alone)", generator: "boundary::prepare", quantity: "stream bytes", got: b_bytes, want: BYTES_PER_FP * S46_M125_BOUNDARY_FP + BYTES_PER_SALT * S46_M125_BOUNDARY_SALTS, how: "MEASURED, production preparer, our generator" });
    rows.push(Row { shape: s, scope: "run boundary (alone)", generator: "boundary::prepare", quantity: "field draws", got: b_fp, want: S46_M125_BOUNDARY_FP, how: "MEASURED bytes at the geometry's salts" });
    rows.push(Row { shape: s, scope: "run boundary (alone)", generator: "boundary::prepare", quantity: "salts", got: b_salts, want: S46_M125_BOUNDARY_SALTS, how: "GEOMETRY" });
    let block_fp = s46_fp_of(r.block.consumed, total_salts(&r.segs), "the 125M block stream");
    let e_fp = r.replica[0].1 + r.replica[1].1;
    let e_salts = r.replica[0].2 + r.replica[1].2;
    let run12 = 12 * block_fp + 11 * b_fp + e_fp;
    rows.push(Row { shape: s, scope: "run L=12 (sum of parts)", generator: "all three", quantity: "field draws per run", got: run12, want: S46_M125_RUN12_FP, how: "sum of MEASURED parts vs COUNTED (H-6)" });
    rows.push(Row { shape: s, scope: "run L=12 (sum of parts)", generator: "all three", quantity: "salts per run", got: 12 * total_salts(&r.segs) + 11 * b_salts + e_salts, want: S46_M125_RUN12_SALTS, how: "GEOMETRY vs COUNTED (F_L row)" });
    eprintln!(
        "S46 125M: the twelve-block sum of measured parts is {run12} field draws; the post-repair count (H-6) is {S46_M125_RUN12_FP}; the PRE-repair figure {S46_M125_RUN12_FP_PRE_REPAIR} is {} below it (= 12 x {})",
        run12 as i64 - S46_M125_RUN12_FP_PRE_REPAIR as i64,
        (run12 as i64 - S46_M125_RUN12_FP_PRE_REPAIR as i64) / 12
    );
    eprintln!("S46 125M: total {:.2} s, peak RSS {:.0} MiB (VmHWM, whole process)", t0.elapsed().as_secs_f64(), super::run::peak_rss_mib());
    s46_report(&rows);
}

/// **THE TWO REPLICAS DRAW WHERE THE PRODUCTION PROVERS DRAW.** The run
/// replica ([`s46_measure_run`]) and the block replica ([`measure_block`])
/// call the production draw sites themselves — `boundary::prepare` and
/// `protocol::prove_core` — on a generator they hold. What makes their
/// counts the provers' counts is that the production bodies use their
/// generator in exactly those places and no other; this reads the bodies and
/// says so, the way stage 36's endpoint-replica test does for the endpoint
/// preparers. Everything ELSE the replicas restate (the run header, the
/// stage layout, the position tags, the segment encoding) is checked by the
/// production verifier accepting what they produce.
#[test]
fn s46_the_replicas_draw_where_the_production_provers_draw() {
    let run_src = source("src/private_block/run.rs");
    let body = fn_body(&run_src, "pub(crate) fn prove_run(");
    assert_eq!(body.matches("rng").count(), 3, "`prove_run` uses its generator somewhere new; `s46_measure_run` may no longer draw what it draws");
    for site in [
        "let mut rng = ZkRng::from_os(&super::hash_domain::run_seed_domain(st.rs.profile))",
        "boundary::prepare(&spec, &words(&plane), &ntt, &mut rng, &tag)",
        "protocol::prove_core(sh, &lay, &blocks[k], wit, [in_data, out_data], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick)",
    ] {
        assert!(body.contains(site), "`prove_run` no longer contains `{site}`");
    }
    assert_eq!(body.matches("pcs::open_zk(").count(), 2, "`prove_run` opens the external endpoints somewhere new");
    assert_eq!(body.matches(".into_opening(").count(), 1, "`prove_run` opens its boundaries somewhere new");
    assert_eq!(body.matches("ZkRng::").count(), 1, "`prove_run` makes a second generator");
    let proto = source("src/private_block/protocol.rs");
    let b = fn_body(&proto, "pub(crate) fn prove_inner_at(");
    assert_eq!(b.matches("rng").count(), 2, "`prove_inner_at` uses its generator somewhere new; `measure_block` may no longer draw what it draws");
    assert!(b.contains("let mut rng = ZkRng::from_os(&super::hash_domain::single_block_seed_domain(sh))"), "the block prover's generator moved");
    assert!(b.contains("prove_core(sh, &lay, blk, wit, [ein.data.as_slice(), eout.data.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick)"), "the block prover's one draw site moved");
    let bsrc = source("src/private_block/boundary.rs");
    let bb = fn_body(&bsrc, "pub(crate) fn prepare(");
    assert_eq!(bb.matches("rng.").count(), 1, "`boundary::prepare` draws somewhere new");
    assert!(bb.contains("*x = rng.fp();"), "the boundary's mask-row fill moved");
    assert!(bb.contains("pcs::commit_zk_owned_tagged(&params, data, ntt, &ZkOpts::standard(&params), rng, tag)"), "the boundary's commitment moved");
    assert_eq!(bb.matches("ZkRng::").count(), 0, "`boundary::prepare` makes a generator of its own");
    eprintln!("S46 replica fidelity: `prove_run` draws only in `boundary::prepare` and `prove_core` on its one generator; `prove_inner_at` only in `prove_core`; `boundary::prepare` fills its mask rows then commits, on the caller's generator");
}
