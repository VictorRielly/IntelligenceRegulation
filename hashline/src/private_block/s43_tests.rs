//! **STAGE 43 (test-only): ruling CS-8 of the shaped refusal census
//! disposition** (`docs/zkmatrix-poc/ZK60_SHAPED_REFUSAL_CENSUS_DISPOSITION.md`
//! §7, security owner) — ONE sweep of the constructor-established invariants
//! of every type a block statement, a shape, a run shape, a run statement, an
//! endpoint policy, a boundary spec or a receipt is assembled from.
//!
//! Stages 38–42 met the same class five times: an invariant a constructor
//! establishes, assumed downstream, and skippable by a struct literal or a
//! field write (the feed-forward half, the attention half, the endpoint
//! policy, the run's block digests, and S42-N1 — `RunShape`). The census memo
//! §12 has the whole table; each type either has PRIVATE FIELDS (the
//! constructor is the only way in) or is RE-CHECKED at every entry where it
//! meets what it is proved against (the CS-1 pattern).
//!
//! FAILING FIRST. The tests below were written and run at the lane tip
//! `e16b6f8` (stage 43's skeleton over `6b68561`) before any production line
//! moved (`results/zk60_block125m_lane/s43-before-*.log`). The literals of
//! the ruling's refusal texts are held here so that the tests could be run,
//! and fail, before the production text existed.
//!
//! Nothing here is a privacy result. Everything proved is PUBLIC SYNTHETIC
//! test data.

use super::layout::*;
use super::protocol::{self, prove_inner_at, CoreView};
use super::run::{RunShape, RunStatement};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use crate::zk::ZkRng;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;

// ---------------------------------------------------------------- the names

/// **RULING CS-8's names**, held as literals so that the tests could be
/// written, and run failing, before the production text existed.
const CS8_SHAPE: &str = "private block shape: ruling CS-8 — ";
const CS8_LAYOUT: &str = "private block: ruling CS-8 — the layout is not the one Layout::for_shape derives for the shape it is proved at";

/// a shape `Shape::new` refuses outright, reached by a field write
fn cs8_shape_refused_prefix(s: &Shape) -> String {
    format!("{CS8_SHAPE}{:?} is not a shape Shape::new builds: Shape::new refuses its own parameters (", s.name)
}

/// a shape whose derived or pinned fields were written
fn cs8_shape_differs(s: &Shape, fields: &str) -> String {
    format!("{CS8_SHAPE}{:?} is not a shape Shape::new builds: its {fields} differ from what Shape::new derives from its parameters", s.name)
}

/// a layout whose public fields were written
fn cs8_layout_differs(fields: &str) -> String {
    format!("{CS8_LAYOUT}: its {fields} differ from what Layout::for_shape derives")
}

/// a layout built for another shape
fn cs8_layout_other_shape(built: &Shape, handed: &Shape) -> String {
    format!("{CS8_LAYOUT}: it was built for the shape {:?} ({}), the shape handed is {:?} ({})", built.name, built.profile, handed.name, handed.profile)
}

/// an endpoint policy whose pinned scales were written
fn cs8_scales(i: i32, o: i32) -> String {
    format!("private block: ruling CS-8 — the endpoint policy's scales ({i}, {o}) are not the approved calibration's (0, 0), which IoSpec::new pins (D12 item 5)")
}

/// the refusals of the EXISTING re-checks (rulings CS-1 and CS-4), which the
/// confirmation test reaches by field writes
const CS1: &str = "private block: ruling CS-1 — the feed-forward statement does not fit the shape it is proved at";
const CS4_ATTENTION: &str = "private block: ruling CS-4 — the attention statement does not fit the shape it is proved at";
const CS4_POLICY: &str = "private block: ruling CS-4 — the endpoint policy does not fit the shape it is proved at";

fn ctx() -> Digest {
    *blake3::hash(b"stage 43: ruling CS-8").as_bytes()
}

// ---------------------------------------------------------------- helpers

fn honest_witness(sh: &Shape, b: &BlockPublic, x: &[i16]) -> Witness {
    witness::build_shaped(sh, b.attention(), b.feed_forward(), x).expect("an honest witness")
}

/// the padded endpoint planes of a witness at `sh`, committed by fresh owners
fn endpoints_with(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the plane map");
    let plane = |p: usize| -> Vec<i16> { w.planes[ids.at(p)].iter().map(|v| i16::try_from(*v).expect("an int16 endpoint word")).collect() };
    let spec = IoSpec::new_shaped(sh, ctx(), 0, 0).expect("the endpoint spec");
    prepare_endpoints(spec, &plane(A_X), &plane(A_X2)).expect("the endpoint owner commits")
}

/// the dense public block at `sh` and its hidden input
fn dense_block(sh: &Shape) -> (BlockPublic, Vec<i16>) {
    let (att, ff, x) = super::dense_tests::dense_case(sh);
    (BlockPublic::new(att, ff), x)
}

/// prove at `sh` and verify the bytes at `sh`, as one outcome line
fn prove_and_verify_at(sh: &Shape, blk: &BlockPublic, x: &[i16], what: &str) -> String {
    let w = honest_witness(sh, blk, x);
    let (expected, owners) = endpoints_with(sh, &w);
    match prove_inner_at(sh, blk, w, &expected, owners) {
        Err(e) => format!("the prover refuses: {e}"),
        Ok((receipt, _)) => match receipt.to_bytes_at(sh, blk, &expected) {
            Err(e) => format!("the prover proved; the encoder refuses the receipt: {e}"),
            Ok(bytes) => match verify_bytes_at(sh, blk, &expected, &bytes) {
                Ok(()) => format!("ACCEPTED: {what}; the block proved ({} B receipt) and the verifier accepted it", bytes.len()),
                Err(e) => format!("proved; the verifier rejects: {e}"),
            },
        },
    }
}

/// Drive `protocol::prove_core` directly — the body the single-block prover
/// and every stage of a run share — with a deterministic public fixture
/// stream, on real endpoint data, with the layout the CALLER hands it.
/// Returns the result, the bytes drawn, the squeezes, whether the transcript
/// moved, and the policy (for the matching verifier header).
fn direct_prove_core(sh: &Shape, lay: &Layout, blk: &BlockPublic, w: Witness) -> (Result<protocol::CoreProof, String>, u64, u64, bool, ExpectedIo) {
    let (expected, owners) = endpoints_with(sh, &w);
    let [ein, eout] = protocol::check_endpoints(sh, &expected, owners).expect("the endpoint owners");
    let ntt = crate::ntt::NttTables::new(protocol::ntt_log_at(sh));
    let mut rng = ZkRng::new(43, b"stage 43: a public fixture stream for the direct prove_core call");
    let mut tr = protocol::transcript(blk, &expected, lay);
    let (before, sq) = (tr.state(), tr.squeezes());
    let mut ph = timing::Phases::start();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let mut tick = std::time::Instant::now();
    let res = protocol::prove_core(sh, lay, blk, w, [ein.data.as_slice(), eout.data.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick);
    (res, rng.consumed_bytes(), tr.squeezes() - sq, tr.state() != before, expected)
}

/// Drive `protocol::verify_core` directly on a view, after the header of
/// `blk` / `expected` / `lay`. Returns the result, the squeezes and whether
/// the transcript moved inside the call.
fn direct_verify_core(sh: &Shape, lay: &Layout, blk: &BlockPublic, expected: &ExpectedIo, v: CoreView) -> (Result<(), String>, u64, bool) {
    let ntt = crate::ntt::NttTables::new(protocol::ntt_log_at(sh));
    let mut tr = protocol::transcript(blk, expected, lay);
    let (before, sq) = (tr.state(), tr.squeezes());
    let mut ph = timing::Phases::start();
    let res = protocol::verify_core(sh, lay, blk, v, &ntt, &mut tr, &mut ph).map(|_| ());
    (res, tr.squeezes() - sq, tr.state() != before)
}

fn view_of_core(c: &protocol::CoreProof) -> CoreView<'_> {
    CoreView { a_root: c.a_root, h_root: c.h_root, mask_root: c.mask_root, slots: &c.slots, mask_open: &c.mask_open, a_open: &c.a_open, h_open: &c.h_open }
}

fn view_of_receipt(r: &Receipt) -> CoreView<'_> {
    CoreView { a_root: r.a_root, h_root: r.h_root, mask_root: r.mask_root, slots: &r.slots, mask_open: &r.mask_open, a_open: &r.a_open, h_open: &r.h_open }
}

fn source(rel: &str) -> String {
    let p = Path::new(env!("CARGO_MANIFEST_DIR")).join(rel);
    std::fs::read_to_string(&p).unwrap_or_else(|e| panic!("{}: {e}", p.display()))
}

/// the text from `sig` up to the first `close` after it
fn fn_body<'a>(text: &'a str, sig: &str, close: &str) -> &'a str {
    let at = text.find(sig).unwrap_or_else(|| panic!("{sig} is not in the source"));
    let end = text[at..].find(close).unwrap_or_else(|| panic!("{sig}'s body does not close")) + at;
    &text[at..end]
}

// ------------------------------------------------ Shape: re-check at entry (failing first)

/// **`Shape` (re-check at entry).** `Shape`'s fields are `pub` on a
/// `pub(crate)` struct, read in hundreds of places, so a field write
/// anywhere in the crate skips every refusal of `Shape::new` (stage 40's own
/// test and `grow_tests::window_shape` make such writes on purpose, to
/// measure the WITNESS BUILDER). Two writes at rung-G's geometry: the norm
/// window below the one the shape derives (ruling CS-2's refusal, reached
/// around), and the PCS's opened columns halved (a pinned field). Before
/// stage 43 the single-block prover proved at them and the verifier was
/// asked; since ruling CS-8 every single-block entry — the prover's, both of
/// the verifier's, and the two shared bodies — refuses a shape that is not
/// one `Shape::new` builds, by name, first, with nothing drawn or absorbed.
#[test]
fn s43_cs8_a_shape_written_past_shape_new_is_refused_by_name_at_every_single_block_entry() {
    let g = Shape::rung_g();
    let mut narrow = g.clone();
    narrow.norm_wrho = 30;
    let mut halved = g.clone();
    halved.opened_cols = 128;
    let (blk, x) = dense_block(&g);
    let measured = |s: &Shape, what: &str| -> String {
        catch_unwind(AssertUnwindSafe(|| prove_and_verify_at(s, &blk, &x, what))).unwrap_or_else(|p| {
            let m = p.downcast_ref::<String>().cloned().or_else(|| p.downcast_ref::<&str>().map(|s| s.to_string())).unwrap_or_default();
            format!("PANICKED: {m}")
        })
    };
    let out_narrow = measured(&narrow, "norm_wrho 30 written at rung-G's geometry (Shape::new derives 31 and refuses 30 by ruling CS-2)");
    eprintln!("S43 CS-8 shape, the norm window written: {out_narrow}");
    let out_halved = measured(&halved, "opened_cols 128 written at rung-G's geometry (Shape::new pins 256)");
    eprintln!("S43 CS-8 shape, the opened columns written: {out_halved}");
    let want_narrow = cs8_shape_refused_prefix(&narrow);
    assert!(out_narrow.starts_with(&format!("the prover refuses: {want_narrow}private block shape: ruling CS-2 — the norm window override norm_wrho = 30 ")), "1. the prover's entry did not refuse the written norm window by ruling CS-8's name: {out_narrow}");
    assert_eq!(out_halved, format!("the prover refuses: {}", cs8_shape_differs(&halved, "opened_cols")), "1. the prover's entry did not refuse the written column count by ruling CS-8's name");
    // 2. the verifier's two entries: the bytes entry on any bytes at all (so
    //    nothing is decoded first), the in-memory entry on an honest rung-G
    //    receipt (the control proves and verifies at rung-G itself)
    let wg = honest_witness(&g, &blk, &x);
    let (expected, owners) = endpoints_with(&g, &wg);
    let (receipt, _) = prove_inner_at(&g, &blk, wg, &expected, owners).expect("the control proves at rung-G");
    let bytes = receipt.to_bytes_at(&g, &blk, &expected).expect("the control encodes");
    verify_bytes_at(&g, &blk, &expected, &bytes).expect("the control verifies at rung-G");
    for (s, want) in [(&narrow, want_narrow.clone()), (&halved, cs8_shape_differs(&halved, "opened_cols"))] {
        let vb = verify_bytes_at(s, &blk, &expected, &[0u8; 64]).err().unwrap_or_else(|| "ACCEPTED".into());
        assert!(vb.starts_with(&want), "2. verify_bytes_at did not refuse the written shape by ruling CS-8's name before decoding: {vb}");
        let vi = protocol::verify_inner_at(s, &blk, &expected, &receipt).map(|_| ()).err().unwrap_or_else(|| "ACCEPTED".into());
        assert!(vi.starts_with(&want), "2. verify_inner_at did not refuse the written shape by ruling CS-8's name: {vi}");
    }
    // 3. the two shared bodies, handed the written shape and ITS OWN layout:
    //    refused first, nothing drawn, nothing squeezed, the transcript unmoved
    for (s, want) in [(&narrow, want_narrow), (&halved, cs8_shape_differs(&halved, "opened_cols"))] {
        let lay = Layout::for_shape(s).expect("Layout::for_shape builds a layout for the written shape");
        let (pc, drawn, squeezes, moved, _) = direct_prove_core(s, &lay, &blk, honest_witness(s, &blk, &x));
        let e = pc.err().unwrap_or_else(|| "PROVED".into());
        assert!(e.starts_with(&want), "3. prove_core did not refuse the written shape by ruling CS-8's name: {e}");
        assert_eq!((drawn, squeezes, moved), (0, 0, false), "3. prove_core drew, squeezed or absorbed before the CS-8 refusal");
        let (vc, squeezes, moved) = direct_verify_core(s, &lay, &blk, &expected, view_of_receipt(&receipt));
        let e = vc.err().unwrap_or_else(|| "ACCEPTED".into());
        assert!(e.starts_with(&want), "3. verify_core did not refuse the written shape by ruling CS-8's name: {e}");
        assert_eq!((squeezes, moved), (0, false), "3. verify_core squeezed or absorbed before the CS-8 refusal");
    }
    eprintln!("S43 CS-8 shape: both written shapes refused by name at prove_inner_at, verify_bytes_at (on 64 zero bytes), verify_inner_at, prove_core (0 bytes drawn, 0 squeezes, transcript unmoved) and verify_core (0 squeezes, transcript unmoved); the rung-G control proves and verifies");
}

// ------------------------------------------------ Layout: re-check at the two bodies (failing first)

/// **`Layout` (re-check at the two shared bodies).** `Layout`'s ten row
/// fields are `pub`; every production caller builds the layout from its own
/// shape on the line before, but `protocol::prove_core` and
/// `protocol::verify_core` take it from their CALLER and never asked whether
/// it is the shape's. Two writes, handed to both bodies alike: (a) two `A`
/// planes of one domain with their row offsets swapped — before stage 43 the
/// core prover proved and the core verifier ACCEPTED a commitment whose plane
/// order is not the one the schedule declares; (b) two more `A` rows before
/// the proximity pair — before stage 43 the core prover drew its mask rows,
/// committed `A` and ran the slots before the opening audit refused. Since
/// ruling CS-8 both bodies refuse, by name, a layout whose fields are not
/// `Layout::for_shape`'s for the shape handed, and a layout built for
/// another shape, first, with nothing drawn or absorbed.
#[test]
fn s43_cs8_a_layout_written_past_layout_for_shape_is_refused_by_name_at_the_two_bodies() {
    let toy = Shape::toy();
    let (blk, x) = BlockPublic::synthetic_fixture();
    let honest = Layout::for_shape(&toy).expect("the toy layout");
    // (a) the first two committed A planes that share a domain, their offsets swapped
    let ids = honest.ids();
    let committed: Vec<usize> = honest.a_planes().into_iter().filter(|p| !ids.is_multiplicity(*p)).collect();
    let (p, q) = committed.iter().enumerate().find_map(|(i, p)| committed[i + 1..].iter().find(|q| ids.dom(**q) == ids.dom(*p)).map(|q| (*p, *q))).expect("two committed A planes on one domain");
    let mut swapped = Layout::for_shape(&toy).expect("the toy layout");
    swapped.a_off.swap(p, q);
    // (b) two A rows before the proximity pair
    let mut grown = Layout::for_shape(&toy).expect("the toy layout");
    grown.a_rows += 2;
    grown.a_prox += 2;
    let mut outcomes: Vec<(String, u64, u64, bool)> = Vec::new();
    for (lay, what) in [(&swapped, format!("A planes {p} and {q} ({:?}) with their row offsets swapped", ids.dom(p))), (&grown, "two A rows written before the proximity pair".to_string())] {
        let (pc, drawn, squeezes, moved, expected) = direct_prove_core(&toy, lay, &blk, honest_witness(&toy, &blk, &x));
        let outcome = match pc {
            Err(e) => format!("the core prover refuses: {e}"),
            Ok(core) => match direct_verify_core(&toy, lay, &blk, &expected, view_of_core(&core)).0 {
                Ok(()) => "ACCEPTED: the core prover and the core verifier, handed the same written layout, proved and accepted".to_string(),
                Err(e) => format!("proved; the core verifier rejects: {e}"),
            },
        };
        eprintln!("S43 CS-8 layout, {what}, at the toy: {outcome} (the core prover drew {drawn} bytes and squeezed {squeezes} times before returning)");
        outcomes.push((outcome, drawn, squeezes, moved));
    }
    for ((outcome, drawn, squeezes, moved), fields) in outcomes.into_iter().zip(["a_off", "a_prox, a_rows"]) {
        assert_eq!(outcome, format!("the core prover refuses: {}", cs8_layout_differs(fields)), "1. prove_core did not refuse the written layout by ruling CS-8's name");
        assert_eq!((drawn, squeezes, moved), (0, 0, false), "1. prove_core drew, squeezed or absorbed before the CS-8 refusal");
    }
    // 2. the core verifier on an honest toy core, handed each written layout
    let (pc, _, _, _, expected) = direct_prove_core(&toy, &honest, &blk, honest_witness(&toy, &blk, &x));
    let core = pc.expect("the honest toy core proves");
    assert!(direct_verify_core(&toy, &honest, &blk, &expected, view_of_core(&core)).0.is_ok(), "2. the honest toy core does not verify");
    for (lay, fields) in [(&swapped, "a_off"), (&grown, "a_prox, a_rows")] {
        let (vc, squeezes, moved) = direct_verify_core(&toy, lay, &blk, &expected, view_of_core(&core));
        assert_eq!(vc.err(), Some(cs8_layout_differs(fields)), "2. verify_core did not refuse the written layout by ruling CS-8's name");
        assert_eq!((squeezes, moved), (0, false), "2. verify_core squeezed or absorbed before the CS-8 refusal");
    }
    // 3. a layout built for ANOTHER shape (rung-G's), handed with the toy
    let g = Shape::rung_g();
    let lay_g = Layout::for_shape(&g).expect("the rung-G layout");
    let want_g = cs8_layout_other_shape(&g, &toy);
    let (pc, drawn, squeezes, moved, _) = direct_prove_core(&toy, &lay_g, &blk, honest_witness(&toy, &blk, &x));
    assert_eq!(pc.err(), Some(want_g.clone()), "3. prove_core did not refuse rung-G's layout at the toy by ruling CS-8's name");
    assert_eq!((drawn, squeezes, moved), (0, 0, false), "3. prove_core drew, squeezed or absorbed before the CS-8 refusal");
    let (vc, squeezes, moved) = direct_verify_core(&toy, &lay_g, &blk, &expected, view_of_core(&core));
    assert_eq!(vc.err(), Some(want_g), "3. verify_core did not refuse rung-G's layout at the toy by ruling CS-8's name");
    assert_eq!((squeezes, moved), (0, false), "3. verify_core squeezed or absorbed before the CS-8 refusal");
    eprintln!("S43 CS-8 layout: the written layout and rung-G's layout at the toy refused by name at prove_core (0 bytes drawn, 0 squeezes, transcript unmoved) and verify_core (0 squeezes, transcript unmoved); the honest toy core proves and verifies");
}

// ------------------------------------------------ IoSpec: re-check at entry (failing first)

/// **`IoSpec`'s pinned scales (re-check at entry).** `IoSpec::new` pins the
/// two endpoint scales to the approved calibration's `(0, 0)` (D12 item 5);
/// ruling CS-4's re-check covers the spec's SHAPE-derived fields and not the
/// scales, and the fields are private only to `private_block`, whose every
/// submodule can write them. A policy with both scales written to 3: before
/// stage 43 the endpoint owner committed under it, the toy block proved and
/// the verifier accepted. Since ruling CS-8 the scales are re-checked, by
/// name, wherever a policy is re-checked (every prover, verifier and run
/// statement entry) and in `IoSpec::validate` (the endpoint owner's step).
#[test]
fn s43_cs8_an_endpoint_policy_whose_scales_were_written_is_refused_by_name_at_every_entry() {
    let (blk, input) = BlockPublic::synthetic_fixture();
    let output = compute_output(&blk, &input).expect("the fixture computes");
    let mut bad = IoSpec::new(ctx(), 0, 0).expect("the approved scales");
    bad.input_scale = 3;
    bad.output_scale = 3;
    let want = cs8_scales(3, 3);
    // 1. the endpoint owner's step, then the whole toy block
    let outcome = match prepare_endpoints(bad.clone(), &input, &output) {
        Err(e) => format!("the endpoint owner refuses: {e}"),
        Ok((expected, owners)) => match prove_with_stats(&blk, &input, &expected, owners) {
            Err(e) => format!("committed; the prover refuses: {e}"),
            Ok((receipt, _)) => {
                let bytes = receipt.to_bytes(&blk, &expected).expect("the receipt encodes");
                match verify_bytes(&blk, &expected, &bytes) {
                    Ok(()) => format!("ACCEPTED: the endpoint owner committed under scales (3, 3), the toy block proved ({} B) and the verifier accepted it", bytes.len()),
                    Err(e) => format!("proved; the verifier rejects: {e}"),
                }
            }
        },
    };
    eprintln!("S43 CS-8 endpoint policy, scales written to (3, 3): {outcome}");
    assert_eq!(outcome, format!("the endpoint owner refuses: {want}"), "1. the endpoint owner's step did not refuse the written scales by ruling CS-8's name");
    // 2. the prover's entry: honest owners, a policy whose scales were written
    let (expected, owners) = prepare_endpoints(IoSpec::new(ctx(), 0, 0).expect("the approved scales"), &input, &output).expect("the honest endpoints");
    let (receipt, _) = prove_with_stats(&blk, &input, &expected, owners).expect("the control proves");
    let bytes = receipt.to_bytes(&blk, &expected).expect("the control encodes");
    verify_bytes(&blk, &expected, &bytes).expect("the control verifies");
    let mut written = expected.clone();
    written.spec.input_scale = 3;
    written.spec.output_scale = 3;
    let (_, owners) = prepare_endpoints(IoSpec::new(ctx(), 0, 0).expect("the approved scales"), &input, &output).expect("fresh owners");
    assert_eq!(prove_with_stats(&blk, &input, &written, owners).err(), Some(want.clone()), "2. the prover's entry did not refuse the written scales by ruling CS-8's name");
    // 3. the verifier's entries (the bytes entry on any bytes at all)
    assert_eq!(verify_bytes(&blk, &written, &bytes).err(), Some(want.clone()), "3. verify_bytes did not refuse the written scales by ruling CS-8's name");
    assert_eq!(verify_bytes(&blk, &written, &[0u8; 64]).err(), Some(want.clone()), "3. verify_bytes decoded before the CS-8 refusal");
    assert_eq!(verify(&blk, &written, &receipt).err(), Some(want.clone()), "3. verify did not refuse the written scales by ruling CS-8's name");
    // 4. the run statement (rung-G), before its own scale comparisons
    let g = Shape::rung_g();
    let (blk_g, _) = dense_block(&g);
    let mut spec_g = IoSpec::new_shaped(&g, ctx(), 0, 0).expect("the rung-G spec");
    spec_g.input_scale = 3;
    spec_g.output_scale = 3;
    let pol = ExpectedIo::from_roots(spec_g, [1; 32], [2; 32]);
    let r = RunStatement::new(RunShape::rung_g(1).expect("run shape"), ctx(), pol, &[blk_g], &[(0, 0)]);
    assert_eq!(r.err(), Some(format!("private run: {want}")), "4. RunStatement::new did not refuse the written scales by ruling CS-8's name");
    eprintln!("S43 CS-8 endpoint policy: the written scales refused by name at prepare_endpoints, the prover's entry, verify_bytes (also on 64 zero bytes), verify and RunStatement::new; the control proves and verifies");
}

// ------------------------------------------------ RunShape / RunStatement: the bypasses as they stood (measured before; deleted after)

// **MEASURED BEFORE STAGE 43, AND DELETED BY IT.** `RunShape`'s three fields
// and `RunStatement`'s `rs` were `pub` on `pub(crate)` structs, so four
// routes around `RunShape::new` (ruling CS-7) compiled anywhere in the crate,
// and the test `s43_before_the_run_shape_is_reachable_around_its_constructor_four_ways`
// that stood here measured each at rung-K4 / rung-G, one block
// (`results/zk60_block125m_lane/s43-before-bypasses.log`, `.done` = 0):
//   (i)   a struct literal, rung-G's run profile over the rung-K4 shape (S42-N1)
//   (ii)  a statement's `rs` replaced by that literal
//   (iii) `st.rs.profile` written to rung-G's run profile
//   (iv)  `st.rs.sh.norm_wrho` written to 30 (`Shape::new` derives 31 and refuses 30)
// — each run PROVED and the run verifier ACCEPTED it. Ruling CS-8 made the
// fields private (`RunShape::sh` / `l` / `profile` and `RunStatement::rs`
// read them), so none of the four compiles outside `run.rs` and the test
// cannot exist. A `compile_fail` doctest cannot stand in for it (the
// module is private and the types `pub(crate)`, so a doctest fails to
// compile for that reason alone and passes vacuously); the declarations are
// pinned instead, below. The test-only `RunStatement::with_run_shape` swaps
// in another run shape `RunShape::new` made, so it does not reopen (i)-(iv).

// ------------------------------------------------ the sealed types: the declarations (failing first)

/// **THE PRIVATE-FIELD CHOICE, PINNED ON THE DECLARATIONS.** A struct
/// literal of a sealed type does not compile outside its module, and a
/// `compile_fail` doctest cannot show it (the modules are private and the
/// types `pub(crate)`, so a doctest would fail to compile for that reason
/// alone and pass vacuously). What would reopen the hole is a field becoming
/// visible again, so the declarations are read: no field of `RunShape`,
/// `RunStatement`, `BoundarySpec`, `PreparedBoundary`, `EndpointSpecG` or
/// `PreparedPlaneG` carries a visibility modifier.
#[test]
fn s43_cs8_no_field_of_a_sealed_type_is_visible_outside_its_module() {
    let mut visible: Vec<String> = Vec::new();
    for (file, decl) in [
        ("src/private_block/run.rs", "pub(crate) struct RunShape {"),
        ("src/private_block/run.rs", "pub(crate) struct RunStatement {"),
        ("src/private_block/boundary.rs", "pub(crate) struct BoundarySpec {"),
        ("src/private_block/boundary.rs", "pub(crate) struct PreparedBoundary {"),
        ("src/private_block/endpoint_g.rs", "pub(crate) struct EndpointSpecG {"),
        ("src/private_block/endpoint_g.rs", "pub(crate) struct PreparedPlaneG {"),
    ] {
        let src = source(file);
        let body = fn_body(&src, decl, "\n}\n");
        let fields: Vec<&str> = body.lines().skip(1).map(str::trim).filter(|l| !l.is_empty() && !l.starts_with("//") && !l.starts_with("#[")).collect();
        assert!(!fields.is_empty(), "{decl} in {file} declares no field");
        for f in fields {
            if f.starts_with("pub") {
                visible.push(format!("{file}: {decl} {f}"));
            }
        }
    }
    eprintln!("S43 CS-8 sealed declarations: {} visible field(s){}", visible.len(), if visible.is_empty() { String::new() } else { format!(":\n{}", visible.join("\n")) });
    assert!(visible.is_empty(), "a field of a sealed type is visible outside its module:\n{}", visible.join("\n"));
}

// ------------------------------------------------ where the checks sit (failing first)

/// **WHERE THE CS-8 CHECKS SIT, READ OUT OF THE SOURCE.** In each
/// single-block entry the shape's own check precedes everything else the
/// entry derives from the shape; in the two shared bodies the shape's and
/// the layout's checks precede the statement's re-check, every draw, absorb
/// and commitment.
#[test]
fn s43_cs8_each_single_block_entry_checks_its_shape_first() {
    let prot = source("src/private_block/protocol.rs");
    let lib = source("src/private_block.rs");
    let first = |body: &str, entry: &str, check: &str, later: &[&str]| {
        let at = body.find(check).unwrap_or_else(|| panic!("{entry} does not call {check}"));
        for l in later {
            let lat = body.find(l).unwrap_or_else(|| panic!("{entry} no longer contains {l}"));
            assert!(at < lat, "{entry}: {check} comes after {l}");
        }
    };
    let b = fn_body(&prot, "pub(crate) fn prove_inner_at(", "\n}\n");
    first(b, "prove_inner_at", "sh.check_constructed()?", &["fits_the_ntt_tables(sh)", "Layout::for_shape(sh)", "check_endpoints(", "ZkRng::from_os(", "transcript(blk"]);
    let b = fn_body(&prot, "pub(crate) fn verify_inner_at(", "\n}\n");
    first(b, "verify_inner_at", "sh.check_constructed()?", &["fits_the_ntt_tables(sh)", "Layout::for_shape(sh)", "receipt_paths_are_the_tree_depth(", "transcript(blk"]);
    let b = fn_body(&lib, "pub(crate) fn verify_bytes_at(", "\n}\n");
    first(b, "verify_bytes_at", "sh.check_constructed()?", &["public.check_for_shape(sh)", "Receipt::from_bytes_at("]);
    let b = fn_body(&prot, "pub(crate) fn prove_core(", "\n}\n");
    for check in ["sh.check_constructed()?", "lay.check_is_for_shape(sh)?"] {
        first(b, "prove_core", check, &["blk.check_for_shape(sh)", "rng.fp()", "commit_zk_owned_tagged(", "absorb_root(tr"]);
    }
    let b = fn_body(&prot, "pub(crate) fn verify_core(", "\n}\n");
    for check in ["sh.check_constructed()?", "lay.check_is_for_shape(sh)?"] {
        first(b, "verify_core", check, &["blk.check_for_shape(sh)", "paths_are_the_tree_depth(", "absorb_root(tr", "challenge_fp2()"]);
    }
    eprintln!("S43 CS-8 placement: the shape's check first in prove_inner_at, verify_inner_at and verify_bytes_at; the shape's and the layout's checks before the statement re-check, every draw, commitment and absorb in prove_core and verify_core");
}

// ------------------------------------------------ the re-check types, reached by field writes (a confirmation)

/// **THE TYPES WHOSE RE-CHECK ALREADY EXISTED, reached by FIELD WRITES**
/// (every submodule of `private_block` can write their fields). Each write
/// is refused at the entry, by the existing name: the attention half's gain
/// nonzero at a padded width index (ruling CS-4), the feed-forward half's
/// `act[128]` where `Dom::F` pads (ruling CS-1 over S38-F1(a)), the policy's
/// hash tag written to another profile's (ruling CS-4), the two endpoint
/// owners swapped in an `Endpoints` literal (their spec digests), a receipt
/// with one slot proof removed (the frame check) and a witness with a plane
/// one word short (the core prover's witness-shape check).
#[test]
fn s43_cs8_field_writes_on_the_types_already_rechecked_are_refused_at_the_entries() {
    let g = Shape::rung_g();
    let (blk, x) = dense_block(&g);
    let fresh = || {
        let w = honest_witness(&g, &blk, &x);
        let (e, o) = endpoints_with(&g, &w);
        (w, e, o)
    };
    // the attention half's gain, at a padded width index (width 96, d_pad 128)
    let mut att = blk.attention().clone();
    att.gamma_a[100] = 1;
    let bad = BlockPublic::new(att, blk.feed_forward().clone());
    let want = format!("{CS4_ATTENTION}: private block: a public weight is nonzero at a padded width index");
    let (w, e, o) = fresh();
    assert_eq!(prove_inner_at(&g, &bad, w, &e, o).err(), Some(want.clone()), "the written attention half was not refused at the prover's entry by ruling CS-4's name");
    assert_eq!(verify_bytes_at(&g, &bad, &e, &[0u8; 64]).err(), Some(want), "the written attention half was not refused at the verifier's entry by ruling CS-4's name");
    // the feed-forward half's act[128], where Dom::F pads (hidden 192, f_pad 256)
    assert!(g.pads(Dom::F), "rung-G's feed-forward domain does not pad");
    let mut ff = blk.feed_forward().clone();
    ff.act[128] = 1;
    let bad = BlockPublic::new(blk.attention().clone(), ff);
    let want = format!("{CS1}: private block: activation table act[128] must be 0 at a shape whose feed-forward domain pads (ruling S38-F1(a))");
    let (w, e, o) = fresh();
    assert_eq!(prove_inner_at(&g, &bad, w, &e, o).err(), Some(want.clone()), "the written feed-forward half was not refused at the prover's entry by ruling CS-1's name");
    assert_eq!(verify_bytes_at(&g, &bad, &e, &[0u8; 64]).err(), Some(want), "the written feed-forward half was not refused at the verifier's entry by ruling CS-1's name");
    // the policy's hash tag, written to rung-K4's
    let (w, e, o) = fresh();
    let mut written = e.clone();
    written.spec.hash_tag = Shape::rung_k4().hash_tag();
    let want = format!("{CS4_POLICY}: its hash tag is not this shape's (the endpoints were committed under another profile's hashing rule)");
    assert_eq!(prove_inner_at(&g, &blk, w, &written, o).err(), Some(want.clone()), "the written policy was not refused at the prover's entry by ruling CS-4's name");
    assert_eq!(verify_bytes_at(&g, &blk, &written, &[0u8; 64]).err(), Some(want), "the written policy was not refused at the verifier's entry by ruling CS-4's name");
    // the two endpoint owners, swapped in a struct literal
    let (w, e, o) = fresh();
    let swapped = Endpoints { input: o.output, output: o.input };
    assert_eq!(prove_inner_at(&g, &blk, w, &e, swapped).err().as_deref(), Some("general endpoint: prepared context mismatch"), "swapped endpoint owners were not refused by their spec digests");
    // a receipt with one slot proof removed (the toy), and a witness one word short
    let toy = Shape::toy();
    let (tb, tx) = BlockPublic::synthetic_fixture();
    let out = compute_output(&tb, &tx).expect("the fixture computes");
    let (te, to) = prepare_endpoints(IoSpec::new(ctx(), 0, 0).expect("the approved scales"), &tx, &out).expect("the toy endpoints");
    let (mut receipt, _) = prove_with_stats(&tb, &tx, &te, to).expect("the toy proves");
    verify(&tb, &te, &receipt).expect("the toy receipt verifies");
    receipt.slots.pop();
    assert_eq!(verify(&tb, &te, &receipt).err().as_deref(), Some("private block wire: slot count"), "a receipt with a slot proof removed was not refused by the frame check");
    let mut w = honest_witness(&toy, &tb, &tx);
    let p = w.planes.iter().position(|v| !v.is_empty()).expect("a committed plane");
    w.planes[p].pop();
    let (te, to) = prepare_endpoints(IoSpec::new(ctx(), 0, 0).expect("the approved scales"), &tx, &out).expect("the toy endpoints");
    assert_eq!(prove_inner_at(&toy, &tb, w, &te, to).err().as_deref(), Some("private block: witness shape"), "a witness one word short was not refused by the core prover's witness-shape check");
    eprintln!("S43 CS-8 confirmation: field writes on the attention half (CS-4), the feed-forward half (CS-1), the policy's hash tag (CS-4), swapped endpoint owners (spec digests), a receipt one slot short (frame check) and a witness one word short (witness shape) are each refused at the entry");
}

// ------------------------------------------------ Shape::check_constructed itself (written after the ruling was built)

/// **`Shape::check_constructed` admits every shape `Shape::new` builds and
/// names every derived or pinned field a write moves.** Every registered
/// shape, the test-only rung-K8, and shapes built with window overrides at
/// or above the derived windows (`grow_tests`' five-limb norm window) pass;
/// each derived or pinned field written alone is refused and named, and a
/// written parameter that `Shape::new` refuses is refused with
/// `Shape::new`'s own refusal inside CS-8's. No registered shape moves.
#[test]
fn s43_cs8_check_constructed_admits_every_shape_new_builds_and_names_each_written_field() {
    let mut admitted: Vec<Shape> = vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125(), super::k8_tests::rung_k8()];
    admitted.push(Shape::new("stage 43: a five-limb norm window override", "hashline-zk-mr1/s43-ln5/1", 24, 96, 192, 6, 16, 2, 10, 4, 9, 14, Some(8), Some(4), Some(33), None).expect("an override above the derived window"));
    admitted.push(Shape::new("stage 43: a softmax window override above the derived one", "hashline-zk-mr1/s43-ws/1", 24, 96, 192, 6, 16, 2, 10, 4, 12, 14, Some(8), Some(4), None, Some(20)).expect("an override above the derived window"));
    for s in &admitted {
        s.check_constructed().unwrap_or_else(|e| panic!("CS-8 refused {}: {e}", s.name));
    }
    let g = Shape::rung_g();
    let mut cases: Vec<(Shape, &str)> = Vec::new();
    let mut s = g.clone();
    s.opened_cols = 128;
    cases.push((s, "opened_cols"));
    let mut s = g.clone();
    s.endpoint_general = !s.endpoint_general;
    cases.push((s, "endpoint_general"));
    let mut s = g.clone();
    s.t_pad *= 2;
    cases.push((s, "t_pad"));
    let mut s = g.clone();
    s.d_pad *= 2;
    cases.push((s, "d_pad"));
    let mut s = g.clone();
    s.h_pad *= 2;
    cases.push((s, "h_pad"));
    let mut s = g.clone();
    s.f_pad *= 2;
    cases.push((s, "f_pad"));
    let mut s = g.clone();
    s.d_max += 1;
    cases.push((s, "d_max"));
    let mut s = g.clone();
    s.t_pad *= 2;
    s.d_max += 1;
    cases.push((s, "t_pad, d_max"));
    for (s, fields) in &cases {
        assert_eq!(s.check_constructed().err(), Some(cs8_shape_differs(s, fields)), "CS-8 did not name the written {fields}");
    }
    // a written PARAMETER that moves a derived field: width 96 -> 100 keeps
    // every padded axis and moves the norm bound d_max
    let mut wider = g.clone();
    wider.width = 100;
    assert_eq!(wider.check_constructed().err(), Some(cs8_shape_differs(&wider, "d_max")), "CS-8 did not name the derived field a written width moves");
    // a written PARAMETER that Shape::new refuses: Shape::new's own refusal, inside CS-8's
    let written = |f: &dyn Fn(&mut Shape)| -> Shape {
        let mut s = g.clone();
        f(&mut s);
        s
    };
    for (s, inner) in [
        (written(&|s| s.f_e = 64), "private block shape: note C-6 — f_e = 64 "),
        (written(&|s| s.wrho_s = 8), "private block shape: ruling CS-2 — the softmax window override wrho_s = 8 "),
        (written(&|s| s.head_dim = 12), "private block shape: the head dimension is not an even power of two"),
    ] {
        let e = s.check_constructed().err().unwrap_or_default();
        assert!(e.starts_with(&format!("{}{inner}", cs8_shape_refused_prefix(&s))), "CS-8 did not carry Shape::new's own refusal ({inner}): {e}");
    }
    eprintln!("S43 CS-8 check_constructed: {} shapes Shape::new builds admitted (every registered one, rung-K8, two above-derived overrides); {} derived/pinned-field writes named; a written width names d_max; f_e 64, wrho_s 8 and head_dim 12 refused with Shape::new's own refusal inside CS-8's", admitted.len(), cases.len());
}
