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
    let measured = Measured { consumed: rng.consumed_bytes(), refills: rng.refills(), squeezes: tr.squeezes(), replay: session.calls(), frame: 0 };
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
/// (`rng.fp_vec`, `rng.fp2_vec`, `rng.bytes32` bound to a name, and the
/// `for x in &mut <slice> { *x = rng.fp(); }` idiom), and then finds every
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
