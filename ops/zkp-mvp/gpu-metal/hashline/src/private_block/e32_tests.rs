//! **LANE STAGE 33 — THE 125M ENDPOINT's ROW COUNT (32 DATA ROWS, 37
//! COMMITMENT ROWS) IN THE ORDINARY TEST FILTER.**
//!
//! **The gap.** Stage 32's closing list left the 125M endpoint's SIZE as item
//! 4: the external endpoint commits the padded `Dom::D` cube, which at 125M
//! is `512 · 1,024 = 2^19` words and at an endpoint log of 14 is **32 data
//! rows and 37 commitment rows**. Every shape the ordinary filter proves at
//! has 2, 4 or 16 data rows — the toy's two, the four of the three 10-log
//! rungs and rung-W14, the frozen-seam rung's sixteen — so the row INDEX 16
//! and up, the 37-row column digest, and a boundary of 38 rows were reached
//! only by an `#[ignore]`d 10 GiB test. Item 4a (32 data rows AT an endpoint
//! log of 14) needs 512 tokens and is 125M itself; **item 4b, the row COUNT
//! at a smaller endpoint log, is cheap**, and this module is it.
//!
//! **What this shape is.** `Shape::rung_e32` is rung-W14's head axis, width
//! and hidden size — 125M's — at **32 tokens and a row width of 2^10**. The
//! endpoint cube is then `32 · 1,024 = 2^15` words, which at an endpoint log
//! of 10 is **32 data rows and 37 commitment rows: 125M's own row count**,
//! reached at a twentieth of 125M's receipt.
//!
//! **What it does NOT reach**, and the module says so in its census: the
//! endpoint LOG (10 here, 14 at 125M), so the endpoint's row WIDTH and its
//! encoded domain are the 10-log rungs', not 125M's. Row count and row width
//! are different properties and rung-W14 already holds the second.
//!
//! **What it is NOT.** Not a privacy result, not an acceptance, and not a
//! claim about 125M: no 125M proof runs anywhere in this module. It is
//! development grade (ruling P-7), on its own profile (D17).
//!
//! **THE CAPTURE RULE** (stages 31–32's, kept): everything here is public
//! synthetic test data from fixed-seed integer streams, and what the census
//! prints is counts, fractions and live-slot counts — **never a witness
//! value**. The only indices printed are the PUBLIC, test-chosen positions of
//! the tampers, which are properties of the shape.

use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::review_tests::{clone_witness, outcome, Outcome};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;

// ---------------------------------------------------------------- the shape's own facts

/// **THE COUNTED RECEIPT LENGTH OF ONE rung-E32 BLOCK**, the INDEPENDENT
/// Python model's own output at this shape
/// (`scripts/zk60_private_block_layout_model.py`, `SHAPES["rung_e32"]`),
/// transcribed with nothing in between.
pub(super) const E32_FRAME_BYTES: usize = 11_368_824;

/// every shape this module builds — the registry the gap census runs over
fn every_shape() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::rung_e32(), Shape::m125()]
}

fn e32_context() -> Digest {
    *blake3::hash(b"private block: stage 33, the 125M endpoint row count").as_bytes()
}

/// the padded plane of a witness, as `int16`
fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

/// the TRUE `(tokens, width)` input inside a padded `Dom::D` plane
fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

// ---------------------------------------------------------------- the gap

/// **THE GAP, STATED AS A CENSUS AND ASSERTED.** The endpoint's DATA row
/// count and COMMITMENT row count at every shape, and the assertion that
/// makes it a gap: with the new shape removed, 32 and 37 are 125M's alone,
/// and 125M's proving tests are all `#[ignore]`d.
#[test]
fn only_the_125m_shape_and_the_new_one_reach_the_thirty_two_row_endpoint() {
    let m = Shape::m125();
    let (mut at_rows, mut at_log) = (Vec::new(), Vec::new());
    eprintln!("S33 ENDPOINT CENSUS (cube words / endpoint log / DATA rows / COMMITMENT rows / column digest B):");
    for sh in every_shape() {
        let data = std::cmp::max(1, (sh.t_pad * sh.d_pad) >> sh.endpoint_log_n);
        eprintln!("    {:<52} 2^{:<2} / {:>2} / {:>2} / {:>2} / {:>4}", sh.name, (sh.t_pad * sh.d_pad).trailing_zeros(), sh.endpoint_log_n, data, sh.endpoint_rows, 8 * sh.endpoint_rows);
        if sh.endpoint_rows == m.endpoint_rows {
            at_rows.push(sh.name);
        }
        if sh.endpoint_log_n == m.endpoint_log_n {
            at_log.push(sh.name);
        }
    }
    assert_eq!(at_rows.len(), 2, "the 37-row endpoint is reached by {} shapes, not by 125M and the new one alone: {at_rows:?}", at_rows.len());
    assert!(at_rows.contains(&m.name) && at_rows.contains(&Shape::rung_e32().name), "the 37-row endpoint list is not 125M and the new shape: {at_rows:?}");
    // NON-VACUITY: without the new shape the row count is 125M's alone
    for sh in every_shape().into_iter().filter(|s| s.name != Shape::rung_e32().name && s.name != m.name) {
        assert!(sh.endpoint_rows < 37, "{}: a shape other than 125M already reaches the 37-row endpoint", sh.name);
        assert!(std::cmp::max(1, (sh.t_pad * sh.d_pad) >> sh.endpoint_log_n) <= 16, "{}: a shape other than 125M already has more than 16 endpoint data rows", sh.name);
    }
    // and what this shape does NOT reach: the endpoint LOG stays rung-W14's
    // and 125M's business
    assert_eq!(at_log.len(), 2, "the endpoint log 14 is reached by {} shapes: {at_log:?}", at_log.len());
    assert!(!at_log.contains(&Shape::rung_e32().name), "the new shape reaches the endpoint LOG, which is not what it is for");
    eprintln!("S33 GAP: 32 endpoint data rows and 37 commitment rows are reached by 125M and rung-E32 and by nothing else; the endpoint LOG 14 is still 125M's and rung-W14's");
}

/// **THE NEW SHAPE IS 125M's ENDPOINT ROW COUNT AT A TEN-LOG ENDPOINT**, and
/// every named shape refusal is satisfied unweakened — including ruling S-6,
/// which this stage added.
#[test]
fn the_new_shape_is_125ms_endpoint_row_count_at_a_ten_log_endpoint() {
    let (e, m, w) = (Shape::rung_e32(), Shape::m125(), Shape::rung_w14());
    // ---- the geometry, and what is forced
    assert_eq!((e.tokens, e.width, e.hidden), (32, 768, 1024), "the rung-E32 axes");
    assert_eq!((e.q_heads, e.head_dim, e.kv_heads), (m.q_heads, m.head_dim, m.kv_heads), "the head axis is not 125M's");
    assert_eq!((e.t_pad, e.d_pad, e.h_pad, e.f_pad), (32, 1024, 16, 1024), "the padded axes");
    assert_eq!(e.d_pad, m.d_pad, "the padded width is not 125M's");
    assert_eq!(e.width, e.q_heads * e.head_dim, "the width is not the head axis's");
    assert_eq!(e.d_pad, e.h_pad * e.head_dim, "d_pad == h_pad * head_dim");
    // ---- THE POINT OF THE SHAPE: the endpoint's cube and row counts
    assert_eq!(e.t_pad * e.d_pad, 1usize << 15, "the rung-E32 endpoint cube");
    assert_eq!((e.endpoint_log_n, e.endpoint_inv_rate), (10, 4), "the endpoint log and rate");
    assert_eq!(std::cmp::max(1, (e.t_pad * e.d_pad) >> e.endpoint_log_n), 32, "the endpoint DATA row count is not 32");
    assert_eq!(e.endpoint_rows, m.endpoint_rows, "the endpoint COMMITMENT row count is not 125M's 37");
    assert_eq!(e.endpoint_rows, 37, "the endpoint commitment row count");
    assert_eq!(8 * e.endpoint_rows, 8 * m.endpoint_rows, "the endpoint column digest length is not 125M's");
    assert!(e.endpoint_general, "the 32-row endpoint is the generalised one, not the frozen seam");
    // ---- what still DIFFERS from 125M, and it is the endpoint's row WIDTH
    assert_ne!(e.endpoint_log_n, m.endpoint_log_n, "the endpoint log must differ: rung-W14 already holds 125M's");
    assert_eq!((e.endpoint_log_n, m.endpoint_log_n, w.endpoint_log_n), (10, 14, 14), "the three endpoint logs");
    assert_eq!((e.t_pad * e.d_pad, m.t_pad * m.d_pad), (1 << 15, 1 << 19), "the two endpoint cubes");
    // ---- the calibration windows, which are 125M's because the WIDTH is
    assert_eq!((e.d_max, e.norm_wrho, e.limbs_norm()), (m.d_max, m.norm_wrho, m.limbs_norm()), "the norm window is not 125M's");
    assert!(e.norm_top_is_full_byte(), "correction C-6 must apply at width 768");
    assert_eq!(e.limbs_sigma_s(), m.limbs_sigma_s(), "the softmax limb count is not 125M's");
    assert_eq!(e.wrho_s, 17, "the softmax window at 32 tokens and F_E 12");
    // ---- EVERY NAMED SHAPE REFUSAL, CHECKED WHERE IT BINDS
    assert!(e.head_dim.is_power_of_two() && e.head_dim >= 2, "T-8");
    assert!(e.t_pad.is_power_of_two() && e.d_pad.is_power_of_two() && e.f_pad.is_power_of_two(), "T-2");
    assert_eq!(e.q_heads % e.kv_heads, 0, "the grouping refusal");
    assert_eq!(e.h_pad % e.kv_heads, 0, "the padded grouping refusal");
    for dom in [Dom::Q, Dom::Kv, Dom::S] {
        assert_eq!(e.log(dom), e.natural_log(dom), "F-2: {dom:?} is P-3 lifted at rung-E32");
    }
    assert_eq!(e.log(Dom::Tab), e.log_cols, "S-1");
    assert!(e.head_dim < 1usize << e.log_cols, "S-3");
    assert!(e.natural_log(Dom::T) < e.log_cols, "S-6: the padded token count must stay below the row width");
    assert!(*e.slot_lengths().iter().max().expect("slots") + 256 <= 512, "C-4");
    // F-2 is what forbids a smaller row width here: at `log_cols = 13`,
    // `Dom::S = h_pad · t_pad² = 2^14` is still above it, but `Dom::T` at 2^5
    // and the endpoint would no longer give 32 data rows. What the test
    // reproduces is the pair of refusals that bracket the token count.
    let fewer = Shape::new("a smaller rung-E32", "hashline-zk-mr1/private-block-e32-probe/2", 16, 768, 1024, 12, 64, 4, 10, 4, 12, 37, None, None, None, None);
    match fewer {
        Ok(s) => assert_ne!(std::cmp::max(1, (s.t_pad * s.d_pad) >> s.endpoint_log_n), 32, "16 tokens cannot give 32 endpoint data rows"),
        Err(m) => eprintln!("S33: 16 tokens at this geometry is refused outright: {m}"),
    }
    // ---- the profile is new and distinct from every older one (D17)
    let mut profiles: Vec<&str> = every_shape().iter().map(|s| s.profile).collect();
    profiles.sort_unstable();
    let n = profiles.len();
    profiles.dedup();
    assert_eq!(profiles.len(), n, "two shapes share a profile string");
    // ---- and no older development receipt moved
    assert_eq!(super::k4_tests::K4_FRAME_BYTES, 4_743_128, "rung-K4's counted receipt moved");
    assert_eq!(super::p2_tests::P2_FRAME_BYTES, 4_742_728, "rung-P2's counted receipt moved");
    assert_eq!(super::c6_tests::C6_FRAME_BYTES, 7_452_040, "rung-C6's counted receipt moved");
    assert_eq!(super::w14_tests::W14_FRAME_BYTES, 16_421_048, "rung-W14's counted receipt moved");
    eprintln!(
        "S33 SHAPE: rung-E32 is 32 tokens of width 768 over 12 heads of 64 in 4 groups at a row width of 2^10 — endpoint cube 2^15, 32 data rows, 37 commitment rows (125M's own), column digest {} B, endpoint log {} against 125M's {}",
        8 * e.endpoint_rows,
        e.endpoint_log_n,
        m.endpoint_log_n
    );
}

// ---------------------------------------------------------------- one honest block

fn endpoints_of(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the rung-E32 plane map");
    let spec = IoSpec::new_shaped(sh, e32_context(), 0, 0).expect("the rung-E32 endpoint spec");
    prepare_endpoints(spec, &padded(w, ids.at(A_X)), &padded(w, ids.at(A_X2))).expect("the rung-E32 endpoint owners")
}

fn prove_e32(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<(ExpectedIo, Receipt, Vec<u8>), String> {
    let (expected, owners) = endpoints_of(sh, &w);
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners)?;
    let bytes = receipt.to_bytes_at(sh, blk, &expected)?;
    Ok((expected, receipt, bytes))
}

/// how non-trivial a rung-E32 witness is, as FRACTIONS and LIVE-SLOT COUNTS
/// only (the capture rule)
fn assert_non_trivial(sh: &Shape, ids: &Ids, w: &Witness, what: &str) {
    let (d, f, fp, dh, dp) = (sh.width, sh.hidden, sh.f_pad, sh.head_dim, sh.d_pad);
    let kvw = sh.kv_heads * dh;
    for (plane, name, floor) in [(A_G8, "gate", 50u64), (A_A16, "activation", 20)] {
        let p = &w.planes[ids.at(plane)];
        let live = (0..sh.tokens).flat_map(|t| (d..f).map(move |j| t * fp + j)).filter(|i| p[*i] != 0).count();
        let pct = (100 * live as u64) / (sh.tokens * (f - d)) as u64;
        assert!(pct >= floor, "{what}: the {name} plane is nonzero at only {pct}% of the upper hidden half [{d}, {f})");
    }
    let o8 = &w.planes[ids.at(A_O8)];
    let live_slots = (0..sh.h_pad)
        .filter(|sl| sh.slot_is_true_head(*sl))
        .filter(|sl| (0..sh.tokens).flat_map(|t| (0..dh).map(move |c| t * dp + sl * dh + c)).any(|i| o8[i] != 0))
        .count();
    assert_eq!(live_slots, sh.q_heads, "{what}: only {live_slots} of the {} true head slots carry an attention output", sh.q_heads);
    let (kr, v8) = (&w.planes[ids.at(A_KR8)], &w.planes[ids.at(A_V8)]);
    let group_live = |p: &Vec<i64>, g: usize| (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| j * kvw + g * dh + c)).any(|i| p[i] != 0);
    let live_groups = (0..sh.kv_heads).filter(|g| group_live(kr, *g) && group_live(v8, *g)).count();
    assert_eq!(live_groups, 4, "{what}: only {live_groups} of the four key-value groups carry nonzero keys AND values");
    for a in 0..sh.kv_heads {
        for b in a + 1..sh.kv_heads {
            let differs = (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| (j, c))).any(|(j, c)| kr[j * kvw + a * dh + c] != kr[j * kvw + b * dh + c]);
            assert!(differs, "{what}: key-value groups {a} and {b} carry IDENTICAL rotated keys");
        }
    }
    // the endpoint's HIGH DATA ROWS carry real words: each endpoint data row
    // is one token's padded hidden vector here, so rows 16..32 are tokens
    // 16..32, and a witness that left them zero would make every tamper
    // below vacuous
    let x2 = &w.planes[ids.at(A_X2)];
    let high_live = (16..sh.tokens).filter(|t| (0..sh.width).any(|c| x2[t * dp + c] != 0)).count();
    assert_eq!(high_live, sh.tokens - 16, "{what}: only {high_live} of the endpoint's upper 16 data rows carry a nonzero word");
    eprintln!("S33 CENSUS [{what}]: 12/12 head slots live, 4/4 key-value groups live and pairwise different, the upper hidden half live, all 16 upper endpoint data rows live");
}

/// **THE HONEST rung-E32 BLOCK PROVES AND VERIFIES FROM BYTES** on the FULLY
/// DENSE recipe with a GENERIC hidden input, at the first development shape
/// with 125M's endpoint row count. The frame is the COUNTED length and a
/// one-byte truncation is refused.
#[test]
fn an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_e32() {
    let sh = Shape::rung_e32();
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-E32 dense honest witness");
    let ids = Ids::new(&sh).expect("the rung-E32 plane map");
    assert!(super::pad::every_checkable_relation_holds(&sh, &ids, &w), "the honest rung-E32 witness is internally inconsistent");
    assert_non_trivial(&sh, &ids, &w, "one dense block");
    let blk = BlockPublic::new(public, ff);
    let t0 = std::time::Instant::now();
    let (expected, receipt, bytes) = prove_e32(&sh, &blk, w).expect("the rung-E32 dense prover");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(bytes.len(), E32_FRAME_BYTES, "the rung-E32 frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the rung-E32 receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the rung-E32 receipt verifies from bytes");
    eprintln!("rung-E32 DENSE one block: prove {prove_s:.2} s, verify from bytes {:.2} s, frame {} B", t1.elapsed().as_secs_f64(), bytes.len());
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short rung-E32 frame was accepted");
}

/// **THE DEGENERATE CASE, NAMED AS ONE.** The all-zero hidden input on the
/// lane's synthetic tame fixture proves and verifies at rung-E32. It says
/// nothing about the group bits — every key-value group is identically zero.
#[test]
fn the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_e32() {
    let sh = Shape::rung_e32();
    let (public, ff, _) = super::grow_tests::tame_case(&sh);
    let input = vec![0i16; sh.tokens * sh.width];
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-E32 all-zero witness");
    let blk = BlockPublic::new(public, ff);
    let (expected, receipt, bytes) = prove_e32(&sh, &blk, w).expect("the rung-E32 all-zero prover");
    assert_eq!(bytes.len(), E32_FRAME_BYTES, "a receipt's length is a function of the shape alone");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the all-zero receipt verifies in typed form");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the all-zero receipt verifies from bytes");
    eprintln!("rung-E32 ALL-ZERO (degenerate) one block: frame {} B, verified", bytes.len());
}

// ---------------------------------------------------------------- what the ROW COUNT fixes

/// **THE ENDPOINT COMMITMENT's GEOMETRY, ASSERTED AGAINST THE MODEL AND
/// AGAINST 125M.** Which figures are now identical to 125M's — the data row
/// count, the commitment row count, the column digest length, the mask row
/// count — and which still differ, which is the endpoint's row WIDTH and
/// everything that follows it.
#[test]
fn the_endpoint_geometry_is_125ms_row_count_over_a_narrower_row() {
    use super::hash_domain;
    use super::protocol::endpoint_pcs_params;
    let (e, m, w) = (Shape::rung_e32(), Shape::m125(), Shape::rung_w14());
    let lay = Layout::for_shape(&e).expect("the rung-E32 layout");
    let (ee, em) = (endpoint_pcs_params(&e), endpoint_pcs_params(&m));
    // ---- IDENTICAL to 125M
    assert_eq!(e.endpoint_rows, m.endpoint_rows, "commitment rows");
    let (de, dm) = (std::cmp::max(1, (e.t_pad * e.d_pad) >> e.endpoint_log_n), std::cmp::max(1, (m.t_pad * m.d_pad) >> m.endpoint_log_n));
    assert_eq!((de, dm), (32, 32), "data rows");
    assert_eq!(e.endpoint_rows - de, m.endpoint_rows - dm, "the endpoint's mask row count");
    assert_eq!(8 * e.endpoint_rows, 296, "the endpoint's opened-column digest length");
    assert_eq!(8 * e.endpoint_rows, 8 * m.endpoint_rows, "the endpoint column digest is not 125M's");
    assert_eq!((ee.inv_rate, ee.num_col_checks), (em.inv_rate, em.num_col_checks), "the endpoint rate and opened-column count are not 125M's");
    // ---- DIFFERENT from 125M, and this is the axis that stays open
    assert_eq!((ee.log_cols, em.log_cols), (10, 14), "the endpoint row widths");
    assert_eq!((hash_domain::tree_depth(&ee), hash_domain::tree_depth(&em)), (12, 16), "the endpoint Merkle depths");
    assert_eq!((e.t_pad * e.d_pad, m.t_pad * m.d_pad), (1 << 15, 1 << 19), "the endpoint cubes");
    // rung-W14 holds the LOG and not the row count; this shape is the mirror
    assert_eq!((w.endpoint_log_n, w.endpoint_rows), (14, 9), "rung-W14's endpoint moved");
    // ---- the block's own commitments, and the C-H4 no-collision refusal at
    // a 37-row endpoint
    hash_domain::imposed_at_shape(&e)
        .refuse(&[("A", lay.a_rows), ("H", lay.h_rows), ("M", M_ROWS), ("endpoint", e.endpoint_rows)])
        .expect("no rung-E32 commitment's column collides with a non-column hash input (C-H4)");
    assert_eq!((8 * lay.a_rows, 8 * lay.h_rows), (17_672, 19_328), "the rung-E32 opened-column digest lengths are not the model's");
    assert_eq!((lay.a_rows, lay.h_rows), (2_209, 2_416), "the rung-E32 row totals are not the model's");
    assert_eq!(hash_domain::single_block_seed_input_len(&e), 118, "the rung-E32 block prover's seed derivation");
    eprintln!(
        "S33 ENDPOINT: cube 2^15 at log {} — {} data rows and {} commitment rows, column digest {} B (125M's own row count and digest length), Merkle depth {} against 125M's {}; A / H columns {} / {} B",
        e.endpoint_log_n,
        de,
        e.endpoint_rows,
        8 * e.endpoint_rows,
        hash_domain::tree_depth(&ee),
        hash_domain::tree_depth(&em),
        8 * lay.a_rows,
        8 * lay.h_rows
    );
}

// ---------------------------------------------------------------- the negative controls

/// **A VERIFIER STATEMENT WHOSE ENDPOINT DIFFERS IN A ROW NO SMALLER SHAPE
/// HAS.** Each endpoint data row here is one token's padded hidden vector, so
/// data row `r` is token `r`, and rows 16..32 exist at no other shape in the
/// filter. The proof is honest; what moves is one word of the VERIFIER's own
/// input endpoint, at row 16, at the last data row 31, and (as the control
/// any shape would catch) at row 0. The endpoint equality must refuse all
/// three, and the honest control must verify first.
#[test]
fn a_verifier_statement_with_a_moved_word_in_a_high_endpoint_row_is_refused_at_the_rung_e32() {
    let sh = Shape::rung_e32();
    let ids = Ids::new(&sh).expect("plane map");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-E32 dense honest witness");
    let (pin, pout) = (padded(&w, ids.at(A_X)), padded(&w, ids.at(A_X2)));
    let blk = BlockPublic::new(public, ff);
    let (expected, _receipt, bytes) = prove_e32(&sh, &blk, w).expect("the rung-E32 dense prover");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest control verifies");
    let cols = 1usize << sh.endpoint_log_n;
    assert_eq!(cols, sh.d_pad, "an endpoint data row is one token's padded hidden vector at this shape");
    for (what, at) in [
        ("data row 0, the row every shape has (the control)", 0usize),
        ("data row 16, a row only a 32-row endpoint has", 16 * cols),
        ("the LAST data row 31, last column", 32 * cols - 1),
    ] {
        let mut moved = pin.clone();
        moved[at] = moved[at].wrapping_add(1);
        let spec = IoSpec::new_shaped(&sh, e32_context(), 0, 0).expect("the endpoint spec");
        let (other, _owners) = prepare_endpoints(spec, &moved, &pout).expect("the moved endpoint owners");
        let e = verify_bytes_at(&sh, &blk, &other, &bytes).expect_err("a receipt was accepted against a statement whose input endpoint differs by one word");
        eprintln!("S33 ENDPOINT TAMPER [{what}] (index {at} = row {} column {}): {e}", at / cols, at % cols);
        assert!(!e.is_empty(), "the refusal carries no message");
    }
}

/// **A TAMPERED WORD IN A HIGH ENDPOINT ROW OF THE WITNESS.** The same rows,
/// reached the other way: the prover's own residual-2 plane — which IS the
/// endpoint's output cube — is changed at a word in data row 16 and at the
/// last data row, and each must be rejected by the VERIFIER at the slot whose
/// relation it breaks first, not by the prover and not by an earlier check.
#[test]
fn a_tamper_in_a_high_endpoint_row_is_rejected_at_its_own_slot_at_the_rung_e32() {
    let sh = Shape::rung_e32();
    let ids = Ids::new(&sh).expect("plane map");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-E32 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    assert!(outcome(&sh, &blk, clone_witness(&base)).is_accepted(), "the honest rung-E32 witness is not accepted");
    let cols = 1usize << sh.log_cols;
    for (what, at, slot) in [
        ("residual 2 at the first word of endpoint data row 16", 16 * sh.d_pad, SC_DZC),
        ("residual 2 at the last TRUE word of the last endpoint data row", 31 * sh.d_pad + sh.width - 1, SC_DZC),
    ] {
        let mut w = clone_witness(&base);
        w.planes[ids.at(A_X2)][at] += 1;
        let o = outcome(&sh, &blk, w);
        eprintln!("S33 TAMPER {what} (index {at} = commitment row {} column {}): {}", at / cols, at % cols, o.short());
        match o {
            Outcome::Accepted => panic!("{what} was ACCEPTED at rung-E32"),
            Outcome::ProverRefused(e) => panic!("{what} was refused by the PROVER, which is not a soundness statement: {e}"),
            Outcome::VerifierRejected(e) => assert!(e.contains(&format!("slot {slot} [{}]", SLOT_NAMES[slot])), "{what} was rejected, but not by slot {slot} [{}]: {e}", SLOT_NAMES[slot]),
        }
    }
}

// ---------------------------------------------------------------- a two-block run

/// how many blocks this stage's run proves. Two is the least that has an
/// INTERNAL BOUNDARY, which is the part a run adds over a block.
pub(super) const E32_RUN_BLOCKS: usize = 2;

/// The honest chain of `l` rung-E32 blocks: each block's hidden output is the
/// next one's hidden input, and none of it is published.
pub(super) struct E32Chain {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
}

impl E32Chain {
    pub(super) fn build(sh: &Shape, l: usize, public: AttentionPublic, ff: FeedForwardPublic, x0: Vec<i16>) -> E32Chain {
        let ids = Ids::new(sh).expect("the rung-E32 plane map");
        let (mut inputs, mut planes) = (Vec::with_capacity(l), Vec::with_capacity(l + 1));
        let mut x = x0;
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).expect("an honest witness of the rung-E32 chain");
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            x = true_input(sh, &w.output().expect("the block's hidden output"));
        }
        E32Chain { sh: sh.clone(), public, ff, inputs, planes }
    }
}

impl RunWitnessSource for E32Chain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        witness::build_shaped(&self.sh, &self.public, &self.ff, &self.inputs[k])
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(self.planes[k + 1].clone())
    }
}

/// the run statement and the two EXTERNAL endpoint owners of a rung-E32 chain
fn e32_statement_of(c: &E32Chain, l: usize, blocks: &[BlockPublic]) -> (RunStatement, Endpoints) {
    let rs = RunShape::rung_e32(l).expect("the rung-E32 run shape");
    let spec = IoSpec::new_shaped(&c.sh, e32_context(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &c.planes[0], &c.planes[l]).expect("the run's external endpoint owners");
    let st = RunStatement::new(rs, e32_context(), expected, blocks, &vec![(0, 0); l]).expect("the rung-E32 run statement");
    (st, owners)
}

/// the fully dense rung-E32 chain of `l` blocks and its `l` public statements
fn e32_dense_chain(l: usize) -> (E32Chain, Vec<BlockPublic>) {
    let sh = Shape::rung_e32();
    let (public, ff, x0) = super::dense_tests::dense_run_case(&sh);
    let blocks = (0..l).map(|_| BlockPublic::new(public.clone(), ff.clone())).collect();
    (E32Chain::build(&sh, l, public, ff, x0), blocks)
}

/// **AN HONEST TWO-BLOCK FULLY DENSE rung-E32 RUN VERIFIES FROM ITS
/// SEGMENTS**, and its INTERNAL BOUNDARY is asserted to be one row more than
/// the 37-row external endpoint — **38 rows**, a boundary commitment no
/// smaller shape has. The segment lengths are the counted ones.
#[test]
fn an_honest_two_block_fully_dense_run_verifies_from_its_segments_at_the_rung_e32() {
    let sh = Shape::rung_e32();
    let ids = Ids::new(&sh).expect("plane map");
    let l = E32_RUN_BLOCKS;
    let (mut c, blocks) = e32_dense_chain(l);
    for k in 0..l {
        let w = witness::build_shaped(&sh, &c.public, &c.ff, &c.inputs[k]).expect("a fully dense witness of the chain");
        assert_non_trivial(&sh, &ids, &w, &format!("run block {k}"));
    }
    let (st, owners) = e32_statement_of(&c, l, &blocks);
    let rows = st.boundary_spec(0).expect("the run's first boundary").commitment_rows();
    // MEASURED: 38, one more than the external endpoint's 37. The boundary
    // commits the same padded `Dom::D` cube at the same endpoint row width —
    // 32 data rows — but carries `BOUNDARY_SITES = 2` reserved IO tab rows
    // where an external endpoint carries one.
    assert_eq!(rows, 38, "the internal boundary's commitment row count");
    assert_eq!(rows, sh.endpoint_rows + 1, "the boundary is not one row more than an external endpoint at this shape");
    let mut segs: Vec<Vec<u8>> = Vec::new();
    let t0 = std::time::Instant::now();
    let stats = run::prove_run(&st, &blocks, &mut c, owners, &mut |k, b| {
        assert_eq!(k, segs.len(), "the sink was handed the segments out of order");
        segs.push(b);
        Ok(())
    })
    .expect("the honest two-block fully dense rung-E32 run proves");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(stats.segment_bytes, super::run_tests::counted_segment_bytes(&sh, l, rows), "a rung-E32 segment is not the counted length");
    let t1 = std::time::Instant::now();
    run::verify_run(&st, &blocks, &segs).expect("the honest two-block fully dense rung-E32 run verifies from its segments");
    eprintln!(
        "S33 FULLY DENSE RUN L={l} (down band {}): prove {prove_s:.2} s, verify from segments {:.2} s, segments {:?} B (total {} B), boundary {rows} rows",
        super::dense_tests::band_down_run(&sh),
        t1.elapsed().as_secs_f64(),
        stats.segment_bytes,
        stats.segment_bytes.iter().sum::<usize>()
    );
}

/// **THE BOUNDARY's OWN ROWS, TAMPERED.** The internal boundary commits the
/// same cube as an external endpoint, at 38 rows here. A run whose boundary
/// plane differs from the block's true output in a HIGH data row — row 16 and
/// the last data row — must be refused; the honest run above is the control.
#[test]
fn a_moved_word_in_a_high_boundary_row_is_refused_in_a_two_block_run_at_the_rung_e32() {
    let sh = Shape::rung_e32();
    let l = E32_RUN_BLOCKS;
    let cols = 1usize << sh.endpoint_log_n;
    for (what, at) in [("boundary data row 16", 16 * cols), ("the last boundary data row 31, last column", 32 * cols - 1)] {
        let (mut c, blocks) = e32_dense_chain(l);
        c.planes[1][at] = c.planes[1][at].wrapping_add(1);
        let (st, owners) = e32_statement_of(&c, l, &blocks);
        let mut segs: Vec<Vec<u8>> = Vec::new();
        let r = run::prove_run(&st, &blocks, &mut c, owners, &mut |_, b| {
            segs.push(b);
            Ok(())
        });
        match r {
            Err(e) => eprintln!("S33 BOUNDARY TAMPER [{what}] (index {at} = row {}): the PROVER refused: {e}", at / cols),
            Ok(_) => {
                let e = run::verify_run(&st, &blocks, &segs).expect_err("a run whose boundary plane is wrong in a high row was accepted");
                eprintln!("S33 BOUNDARY TAMPER [{what}] (index {at} = row {}): the VERIFIER rejected: {e}", at / cols);
            }
        }
    }
}
