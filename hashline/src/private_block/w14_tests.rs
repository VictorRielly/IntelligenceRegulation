//! **LANE STAGE 32 — THE 125M ROW WIDTH, HEAD SIZE AND ENDPOINT LOG, IN THE
//! ORDINARY TEST FILTER.**
//!
//! **The gap.** Stage 31 closed the last of stage 30's cheap heavy-only
//! branches and left three that are all properties of the ROW GEOMETRY and
//! the HEAD SIZE:
//!
//! * the row width **`log_cols = 14`** — a 2^14-word message encoded to 2^16
//!   at inverse rate 4, a 16-deep Merkle tree, `rows_of` for every domain,
//!   the `Dom::Tab` P-3 lift distance (8 → 14, a factor of 64), the NTT
//!   table's log and the `pcs-vec` hash length;
//! * the head size **`head_dim = 64`** — the S-3 / C-2 margin, and the RoPE
//!   partner bit at `log − 6`;
//! * the **endpoint log `endpoint_log_n = 14`**.
//!
//! Every development shape the ordinary filter proves at is at `log_cols` 8
//! or 10 and at a head dimension of 8, 16 or 32. The only shape with 14 and
//! 64 is 125M, whose proofs are `#[ignore]`d 10 GiB tests — and it is
//! exactly the shape the integrator is about to optimise the shared
//! commitment and sumcheck code at. Under the security owner's standing rule
//! after finding S19-F1, a branch only an ignored heavy test reaches is a
//! branch nobody tests.
//!
//! **What this module is.** `Shape::rung_w14` is 125M's head axis — 12 query
//! heads of 64 over 4 key-value heads, width 768 — at the SMALLEST token
//! count the row width admits (64, forced by refusal F-2 through
//! `Dom::Kv`), with the hidden axis at the smallest power of two above the
//! width. It proves, verifies, is censused by name against 125M figure by
//! figure, and is tampered with at the places only this width and this head
//! size reach.
//!
//! **What it is NOT.** Not a privacy result, not an acceptance, and not a
//! claim about 125M: no 125M proof runs anywhere in this module. It is
//! development grade (ruling P-7), on its own profile (D17).
//!
//! **THE CAPTURE RULE** (stage 31's, kept). Everything here is public
//! synthetic test data from fixed-seed integer streams; what the census
//! prints is counts, fractions and live-slot counts, and **never a witness
//! value**. The only indices printed are the PUBLIC, test-chosen positions
//! of the tampers — the last index of a domain, a named head slot — which
//! are properties of the shape and not of any witness.

use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::review_tests::{clone_witness, outcome, Outcome};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;

// ---------------------------------------------------------------- the shape's own facts

/// **THE COUNTED RECEIPT LENGTH OF ONE rung-W14 BLOCK.**
///
/// The INDEPENDENT Python model's own output at this shape
/// (`scripts/zk60_private_block_layout_model.py`, `SHAPES["rung_w14"]`,
/// `results/zk60_block125m_lane/model_rung_w14.json`), transcribed, with
/// nothing in between.
pub(super) const W14_FRAME_BYTES: usize = 16_421_048;

/// every shape this module builds — the registry the gap census runs over,
/// kept in the same order as `s24_tests::every_shape`
fn every_shape() -> Vec<Shape> {
    vec![Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::rung_w14(), Shape::m125()]
}

fn w14_context() -> Digest {
    *blake3::hash(b"private block: stage 32, the 125M row width").as_bytes()
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

/// **THE GAP, STATED AS A CENSUS AND ASSERTED.**
///
/// For every shape the module builds, the three quantities this stage is
/// about — the row width, the head dimension and the endpoint log — and the
/// assertion that makes it a gap: with the new shape removed from the
/// registry, the only shape at any of the three 125M values is 125M itself,
/// whose every proving test is `#[ignore]`d.
///
/// | shape | `log_cols` | `head_dim` | `endpoint_log_n` |
/// |---|---:|---:|---:|
/// | `toy` | 8 | 8 | 8 |
/// | `rung` | 10 | 16 | 8 |
/// | `rung_g`, `rung_k4`, `rung_p2` | 10 | 16 / 8 / 8 | 10 |
/// | `rung_c6` | 10 | 32 | 10 |
/// | `m125` | **14** | **64** | **14** — every proof `#[ignore]`d |
/// | `rung_w14` (new) | **14** | **64** | **14**, in this filter |
#[test]
fn only_the_125m_shape_and_the_new_one_reach_the_125m_row_width() {
    let m = Shape::m125();
    let mut at_width: Vec<&str> = Vec::new();
    let mut at_head: Vec<&str> = Vec::new();
    let mut at_endpoint: Vec<&str> = Vec::new();
    eprintln!("S32 GAP CENSUS (log_cols / head_dim / endpoint_log_n / endpoint rows / encoded row):");
    for sh in every_shape() {
        eprintln!(
            "    {:<52} {:>2} / {:>2} / {:>2} / {:>2} / 2^{}",
            sh.name,
            sh.log_cols,
            sh.head_dim,
            sh.endpoint_log_n,
            sh.endpoint_rows,
            sh.log_cols + sh.inv_rate.trailing_zeros() as usize
        );
        if sh.log_cols == m.log_cols {
            at_width.push(sh.name);
        }
        if sh.head_dim == m.head_dim {
            at_head.push(sh.name);
        }
        if sh.endpoint_log_n == m.endpoint_log_n {
            at_endpoint.push(sh.name);
        }
    }
    for (what, at) in [("the row width 2^14", &at_width), ("the head dimension 64", &at_head), ("the endpoint log 14", &at_endpoint)] {
        assert_eq!(at.len(), 2, "{what} is reached by {} shapes, not by 125M and the new one alone: {at:?}", at.len());
        assert!(at.contains(&Shape::m125().name), "{what}: 125M is not in the list");
        assert!(at.contains(&Shape::rung_w14().name), "{what}: the new shape is not in the list");
    }
    // THE NON-VACUITY: with the new shape removed, each of the three is
    // 125M's alone — and 125M's proofs are all `#[ignore]`d.
    for sh in every_shape().into_iter().filter(|s| s.name != Shape::rung_w14().name && s.name != m.name) {
        assert!(sh.log_cols < 14, "{}: a shape other than 125M already reaches the row width", sh.name);
        assert!(sh.head_dim < 64, "{}: a shape other than 125M already reaches the head dimension", sh.name);
        assert!(sh.endpoint_log_n < 14, "{}: a shape other than 125M already reaches the endpoint log", sh.name);
    }
    eprintln!("S32 GAP: the row width 2^14, the head dimension 64 and the endpoint log 14 are reached by 125M and rung-W14 and by nothing else; without rung-W14 each is 125M's alone");
}

/// **THE NEW SHAPE IS 125M's HEAD AXIS AT THE SMALLEST ADMISSIBLE TOKEN
/// COUNT**, and every named shape refusal is satisfied unweakened. This is
/// the test that makes every later measurement a measurement of the row
/// width, the head size and the endpoint log and of nothing else.
#[test]
fn the_new_shape_is_the_125m_head_axis_at_the_smallest_admissible_token_count() {
    let (w, c6, m) = (Shape::rung_w14(), Shape::rung_c6(), Shape::m125());
    assert_eq!((w.tokens, w.width, w.hidden), (64, 768, 1024), "rung-W14's block dimensions");
    assert_eq!((w.q_heads, w.head_dim, w.kv_heads), (12, 64, 4), "rung-W14's head axis");
    assert_eq!((w.t_pad, w.d_pad, w.h_pad, w.f_pad), (64, 1024, 16, 1024), "rung-W14's padded axes");
    // ---- WHAT IS 125M's, EXACTLY
    assert_eq!((w.q_heads, w.head_dim, w.kv_heads), (m.q_heads, m.head_dim, m.kv_heads), "rung-W14's head axis is not 125M's");
    assert_eq!(w.width, m.width, "rung-W14's width is not 125M's");
    assert_eq!((w.d_pad, w.h_pad), (m.d_pad, m.h_pad), "rung-W14's padded head geometry is not 125M's");
    assert_eq!((w.log_cols, w.inv_rate, w.opened_cols), (m.log_cols, m.inv_rate, m.opened_cols), "rung-W14's PCS parameters are not 125M's");
    assert_eq!(w.endpoint_log_n, m.endpoint_log_n, "rung-W14's endpoint log is not 125M's");
    assert_eq!(w.endpoint_inv_rate, m.endpoint_inv_rate, "rung-W14's endpoint rate is not 125M's");
    assert_eq!(w.d_max, m.d_max, "rung-W14's D_max is not 125M's, so the norm window is a different one");
    assert_eq!(w.d_max, 908_065, "rung-W14's D_max");
    assert_eq!((w.norm_wrho, w.limbs_norm()), (m.norm_wrho, m.limbs_norm()), "rung-W14's norm window is not 125M's");
    assert!(w.norm_top_is_full_byte(), "rung-W14 must be on the C-6 arm, as 125M is");
    // the softmax window is 125M's, by a different route: clog2(64) + 12
    // here, clog2(512) + 9 there
    assert_eq!(w.wrho_s, 18, "rung-W14's softmax window");
    assert_eq!(w.wrho_s, m.wrho_s, "rung-W14's softmax window is not 125M's, so a lookup family would differ");
    assert_eq!((w.limbs_sigma_s(), w.limbs_p()), (m.limbs_sigma_s(), m.limbs_p()), "rung-W14's softmax limb counts are not 125M's");
    // ---- WHAT IS FORCED, AND BY WHICH REFUSAL
    // F-2 is the binding one: Dom::Kv = tokens * kv_heads * head_dim must
    // reach the row width, so tokens >= 2^14 / 256 = 64.
    assert_eq!(w.size(Dom::Kv), 1usize << w.log_cols, "Dom::Kv does not sit exactly at the row width");
    assert_eq!(w.tokens * w.kv_heads * w.head_dim, 1usize << w.log_cols, "the token count is not the one F-2 forces");
    for t in [16usize, 32] {
        let smaller = Shape::new("a smaller rung-W14", "hashline-zk-mr1/private-block-w14-probe/1", t, 768, 1024, 12, 64, 4, 14, 4, 12, 9, None, None, None, None);
        let e = smaller.expect_err("a shape with fewer tokens was accepted at this row width");
        assert!(e.contains("P-3") && e.contains("Kv"), "the smaller shape was refused for another reason: {e}");
    }
    // and the width cannot grow: the four-norm-limb ceiling is at 1,024
    assert!(w.width <= 1024, "the width is above the four-norm-limb ceiling");
    // ---- EVERY NAMED SHAPE REFUSAL, CHECKED WHERE IT BINDS
    assert!(w.head_dim.is_power_of_two() && w.head_dim >= 2, "T-8");
    assert!(w.t_pad.is_power_of_two() && w.d_pad.is_power_of_two() && w.f_pad.is_power_of_two(), "T-2");
    assert_eq!(w.d_pad, w.h_pad * w.head_dim, "d_pad == h_pad * head_dim");
    assert_eq!(w.width, w.q_heads * w.head_dim, "the reference kernel refuses a width that is not q_heads * head_dim");
    assert_eq!((w.q_heads % w.kv_heads, w.h_pad % w.kv_heads), (0, 0), "the grouping refusals");
    for dom in [Dom::Q, Dom::Kv, Dom::S] {
        assert_eq!(w.log(dom), w.natural_log(dom), "F-2: {dom:?} is lifted by P-3, so the bilinear slots cannot serve this shape");
    }
    assert_eq!(w.log(Dom::Tab), w.log_cols, "S-1: the table domain must sit exactly at the row width");
    assert!(w.head_dim < 1usize << w.log_cols, "S-3 / C-2: the head dimension reaches the row width");
    let worst = *w.slot_lengths().iter().max().expect("slots");
    assert!(worst + 256 <= 512, "C-4: the mask budget");
    assert_eq!(worst, 87, "the worst slot's mask length");
    // ---- THE HEAD PERMUTATION AND THE PAD ARMS ARE 125M's
    assert_eq!(w.kv_heads.trailing_zeros() as usize, 2, "rung-W14 must carry TWO group bits");
    let pad_slots: Vec<usize> = (0..w.h_pad).filter(|s| !w.slot_is_true_head(*s)).collect();
    assert_eq!(pad_slots, vec![3, 7, 11, 15], "the padded head slots are not 125M's {{3, 7, 11, 15}}");
    assert_eq!(pad_slots, (0..m.h_pad).filter(|s| !m.slot_is_true_head(*s)).collect::<Vec<usize>>(), "the padded head slots are not 125M's");
    let unpadded: Vec<Dom> = ALL_DOMS.into_iter().filter(|d| !w.pads(*d)).collect();
    assert_eq!(unpadded, vec![Dom::T, Dom::Kv, Dom::F], "rung-W14's unpadded domains are not T, Kv, F");
    assert_eq!(unpadded, ALL_DOMS.into_iter().filter(|d| !m.pads(*d)).collect::<Vec<Dom>>(), "rung-W14's unpadded set is not 125M's");
    assert!(w.carries_pad_rule(), "rung-W14 must carry the pad rule");
    // ---- THE ENDPOINT: 125M's LOG, NOT 125M's ROW COUNT
    assert!(w.endpoint_general, "rung-W14 must ride the generalised endpoint");
    assert_eq!((w.endpoint_rows, w.endpoint_log_n, w.endpoint_inv_rate), (9, 14, 4), "rung-W14's endpoint");
    assert_eq!(w.t_pad * w.d_pad >> w.endpoint_log_n, 4, "the endpoint's data rows");
    assert_eq!(m.t_pad * m.d_pad >> m.endpoint_log_n, 32, "125M's endpoint data rows");
    // ---- D17: its own profile, its own key set
    assert_eq!(w.profile, "hashline-zk-mr1/private-block-rung-w14-t64-dev/1");
    assert!(!w.hashes_under_the_legacy_rule(), "rung-W14 must be TAGGED");
    for other in [Shape::toy(), Shape::rung(), Shape::rung_g(), Shape::rung_k4(), Shape::rung_p2(), Shape::rung_c6(), Shape::m125()] {
        assert_ne!(w.profile, other.profile, "rung-W14 shares a profile with {}", other.name);
        if !other.hashes_under_the_legacy_rule() {
            assert_ne!(w.hash_tag(), other.hash_tag(), "rung-W14 shares a hash-tag key set with {}", other.name);
        }
    }
    assert_eq!(run::RUN_PROFILE_RUNG_W14, "hashline-zk-mr1/private-run-rung-w14-t64-dev/1");
    // ---- AND THE COUNTED RECEIPT, FROM THE INDEPENDENT MODEL, WITH EVERY
    // OLDER PROFILE'S STILL IN PLACE
    assert_eq!(w.receipt_bytes().total, W14_FRAME_BYTES, "the counted rung-W14 receipt is not the model's");
    assert_eq!(c6.receipt_bytes().total, super::c6_tests::C6_FRAME_BYTES, "rung-C6's counted receipt moved");
    assert_eq!(Shape::rung_p2().receipt_bytes().total, super::p2_tests::P2_FRAME_BYTES, "rung-P2's counted receipt moved");
    assert_eq!(Shape::rung_k4().receipt_bytes().total, super::k4_tests::K4_FRAME_BYTES, "rung-K4's counted receipt moved");
    eprintln!(
        "S32 rung-W14: T{}/d{}/f{}, {} heads of {} over {} KV heads, pads ({}, {}, {}, {}), lkv 2, log_cols {} (encoded 2^{}), endpoint log {} over {} rows, largest L {}, receipt {} B",
        w.tokens,
        w.width,
        w.hidden,
        w.q_heads,
        w.head_dim,
        w.kv_heads,
        w.t_pad,
        w.d_pad,
        w.h_pad,
        w.f_pad,
        w.log_cols,
        w.log_cols + 2,
        w.endpoint_log_n,
        w.endpoint_rows,
        worst,
        w.receipt_bytes().total
    );
}

// ---------------------------------------------------------------- one honest block

fn endpoints_of(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the rung-W14 plane map");
    let spec = IoSpec::new_shaped(sh, w14_context(), 0, 0).expect("the rung-W14 endpoint spec");
    prepare_endpoints(spec, &padded(w, ids.at(A_X)), &padded(w, ids.at(A_X2))).expect("the rung-W14 endpoint owners")
}

fn prove_w14(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<(ExpectedIo, Receipt, Vec<u8>), String> {
    let (expected, owners) = endpoints_of(sh, &w);
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners)?;
    let bytes = receipt.to_bytes_at(sh, blk, &expected)?;
    Ok((expected, receipt, bytes))
}

/// how non-trivial a rung-W14 witness is, as FRACTIONS and LIVE-SLOT COUNTS
/// only (the capture rule): the upper hidden half live, all twelve true head
/// slots live and the four padded ones dead, four key-value groups live and
/// pairwise different.
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
    for sl in (0..sh.h_pad).filter(|s| !sh.slot_is_true_head(*s)) {
        assert!(!(0..sh.tokens).flat_map(|t| (0..dh).map(move |c| t * dp + sl * dh + c)).any(|i| o8[i] != 0), "{what}: padded head slot {sl} carries an attention output");
    }
    let (kr, v8) = (&w.planes[ids.at(A_KR8)], &w.planes[ids.at(A_V8)]);
    let group_live = |p: &Vec<i64>, g: usize| (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| j * kvw + g * dh + c)).any(|i| p[i] != 0);
    let live_groups = (0..sh.kv_heads).filter(|g| group_live(kr, *g) && group_live(v8, *g)).count();
    assert_eq!(live_groups, 4, "{what}: only {live_groups} of the four key-value groups carry nonzero keys AND values");
    for a in 0..sh.kv_heads {
        for b in a + 1..sh.kv_heads {
            let differs = (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| (j, c))).any(|(j, c)| kr[j * kvw + a * dh + c] != kr[j * kvw + b * dh + c]);
            assert!(differs, "{what}: key-value groups {a} and {b} carry IDENTICAL rotated keys, so the two group bits are not exercised");
        }
    }
    // the RoPE partner bit at `log - 6` is what a head dimension of 64
    // addresses: the rotated halves must differ from the unrotated ones
    let (q8, qr) = (&w.planes[ids.at(A_Q8)], &w.planes[ids.at(A_QR8)]);
    let rotated = (0..sh.tokens * sh.d_pad).filter(|i| q8[*i] != qr[*i]).count();
    assert!(rotated * 4 >= sh.tokens * sh.width, "{what}: the rotation moved only {rotated} of the query words, so the RoPE partner bit at log - 6 is not exercised");
    eprintln!("S32 CENSUS [{what}]: 12/12 head slots live, 4/4 key-value groups live and pairwise different, the upper hidden half live, the rotation live on the 64-wide head");
}

/// **THE HONEST rung-W14 BLOCK PROVES AND VERIFIES FROM BYTES** on the FULLY
/// DENSE recipe with a GENERIC hidden input — every entry of all nine public
/// words nonzero, four genuinely different key-value groups, the upper
/// hidden half live — at the first development shape with 125M's row width,
/// head size and endpoint log. The frame is the COUNTED length and a
/// one-byte truncation is refused.
#[test]
fn an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_w14() {
    let sh = Shape::rung_w14();
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-W14 dense honest witness");
    let ids = Ids::new(&sh).expect("the rung-W14 plane map");
    assert!(super::pad::every_checkable_relation_holds(&sh, &ids, &w), "the honest rung-W14 witness is internally inconsistent");
    assert_non_trivial(&sh, &ids, &w, "one dense block");
    let blk = BlockPublic::new(public, ff);
    let t0 = std::time::Instant::now();
    let (expected, receipt, bytes) = prove_w14(&sh, &blk, w).expect("the rung-W14 dense prover");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(bytes.len(), W14_FRAME_BYTES, "the rung-W14 frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the rung-W14 receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the rung-W14 receipt verifies from bytes");
    eprintln!("rung-W14 DENSE one block: prove {prove_s:.2} s, verify from bytes {:.2} s, frame {} B", t1.elapsed().as_secs_f64(), bytes.len());
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short rung-W14 frame was accepted");
}

/// **THE DEGENERATE CASE, NAMED AS ONE.** The all-zero hidden input on the
/// lane's synthetic tame fixture proves and verifies at rung-W14. It says
/// nothing about the group bits — every key-value group is identically zero
/// — and it exists because it is the fixed input the privacy case is stated
/// at and the witness the second capture bundle carries.
#[test]
fn the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_w14() {
    let sh = Shape::rung_w14();
    let (public, ff, _) = super::grow_tests::tame_case(&sh);
    let input = vec![0i16; sh.tokens * sh.width];
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-W14 all-zero witness");
    let blk = BlockPublic::new(public, ff);
    let (expected, receipt, bytes) = prove_w14(&sh, &blk, w).expect("the rung-W14 all-zero prover");
    assert_eq!(bytes.len(), W14_FRAME_BYTES, "a receipt's length is a function of the shape alone");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the all-zero receipt verifies in typed form");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the all-zero receipt verifies from bytes");
    eprintln!("rung-W14 ALL-ZERO (degenerate) one block: frame {} B, verified", bytes.len());
}

// ---------------------------------------------------------------- what the ROW WIDTH fixes

/// **EVERYTHING KEYED TO THE ROW WIDTH, ASSERTED AGAINST THE MODEL AND
/// AGAINST 125M.** This is the census the stage exists for: at
/// `log_cols = 14` the message is 2^14 words, the encoding 2^16, the Merkle
/// tree 16 deep, the NTT table `2^16`, every domain's row count is its size
/// shifted by 14, the lookup-table domain is lifted from 2^8 by a factor of
/// SIXTY-FOUR, and the `pcs-vec` hash input is 266,295 bytes. Every one of
/// those is 125M's own value and no other shape in the filter has any of
/// them.
#[test]
fn the_row_geometry_is_125ms_and_every_derived_quantity_follows_it() {
    use super::hash_domain;
    use super::protocol::{endpoint_pcs_params, pcs_params_at};
    let (w, m, c6) = (Shape::rung_w14(), Shape::m125(), Shape::rung_c6());
    let lay = Layout::for_shape(&w).expect("the rung-W14 layout");
    // ---- the PCS parameters, and the pads that move with them
    let (pw, pm) = (pcs_params_at(&w), pcs_params_at(&m));
    assert_eq!((pw.log_cols, pw.inv_rate, pw.num_col_checks), (14, 4, 256), "the rung-W14 PCS parameters");
    assert_eq!((pw.log_cols, pw.inv_rate, pw.num_col_checks), (pm.log_cols, pm.inv_rate, pm.num_col_checks), "the PCS parameters are not 125M's");
    assert_eq!(1usize << pw.log_cols, 16_384, "the message is not 2^14 words");
    assert_eq!((1usize << pw.log_cols) * pw.inv_rate, 65_536, "the encoded row is not 2^16 words");
    // the pad count and the opened-column count move together (`ZkOpts::standard`)
    assert_eq!(w.opened_cols, pw.num_col_checks, "the pad count and the opened-column count parted company");
    // ---- the Merkle depth and the NTT log
    assert_eq!(hash_domain::tree_depth(&pw), 16, "the rung-W14 Merkle tree depth");
    assert_eq!(hash_domain::tree_depth(&pw), hash_domain::tree_depth(&pm), "the Merkle depth is not 125M's");
    assert_eq!(hash_domain::tree_depth(&pcs_params_at(&c6)), 12, "rung-C6's Merkle depth moved");
    assert_eq!(super::protocol::ntt_log_at(&w), 16, "the rung-W14 NTT table log");
    assert_eq!(super::protocol::ntt_log_at(&w), super::protocol::ntt_log_at(&m), "the NTT table log is not 125M's");
    super::protocol::fits_the_ntt_tables(&w).expect("the rung-W14 evaluation domain is inside the module's ceiling");
    // ---- `rows_of` for every domain is the size shifted by the row width
    for dom in ALL_DOMS {
        assert_eq!(w.rows_of(dom), (w.size(dom) >> w.log_cols).max(1), "{dom:?}: rows_of is not the size shifted by the row width");
    }
    assert_eq!(ALL_DOMS.map(|d| w.rows_of(d)), [1, 1, 1, 4, 4, 1, 4, 4, 1], "the per-domain row counts");
    // ---- ruling S-1 at fourteen, and the P-3 lift distance
    assert_eq!(w.log(Dom::Tab), w.log_cols, "S-1: Dom::Tab must sit exactly at the row width");
    assert_eq!(w.natural_log(Dom::Tab), 8, "the table's natural log is the fixed clog2(U8_LEN)");
    assert_eq!(w.size(Dom::Tab) / U8_LEN, 64, "the P-3 table lift factor");
    assert_eq!(w.size(Dom::Tab) / U8_LEN, m.size(Dom::Tab) / U8_LEN, "the table lift factor is not 125M's");
    assert_eq!(c6.size(Dom::Tab) / U8_LEN, 4, "rung-C6's table lift factor moved");
    // Dom::L is the other lifted domain, and it is lifted further here than
    // at 125M (2^10 -> 2^14 against 2^13 -> 2^14)
    assert_eq!((w.natural_log(Dom::L), w.log(Dom::L)), (10, 14), "Dom::L's lift");
    assert_eq!((m.natural_log(Dom::L), m.log(Dom::L)), (13, 14), "125M's Dom::L lift");
    for dom in ALL_DOMS.into_iter().filter(|d| ![Dom::L, Dom::Tab].contains(d)) {
        assert_eq!(w.log(dom), w.natural_log(dom), "{dom:?} is P-3 lifted at rung-W14, which only L and Tab are");
    }
    // ---- the OPENED-COLUMN byte length: `8 * rows`, and the rows are what a
    // wide row makes small
    assert_eq!((8 * lay.a_rows, 8 * lay.h_rows), (4_216, 3_488), "the rung-W14 opened-column digest lengths");
    let mlay = Layout::for_shape(&m).expect("the 125M layout");
    assert_eq!((8 * mlay.a_rows, 8 * mlay.h_rows), (45_448, 56_960), "125M's opened-column digest lengths");
    assert_eq!((lay.a_rows, lay.h_rows), (527, 436), "the rung-W14 row totals are not the model's");
    // ---- the tagged hash inputs of this profile
    assert_eq!(hash_domain::single_block_seed_input_len(&w), 118, "the rung-W14 block prover's seed derivation");
    assert_eq!(48 + "pcs-vec".len() + 16 * ((1usize << w.log_cols) + w.opened_cols), 266_295, "the pcs-vec absorb at this row width");
    assert_eq!(
        48 + "pcs-vec".len() + 16 * ((1usize << w.log_cols) + w.opened_cols),
        48 + "pcs-vec".len() + 16 * ((1usize << m.log_cols) + m.opened_cols),
        "the pcs-vec absorb is not 125M's"
    );
    hash_domain::imposed_at_shape(&w)
        .refuse(&[("A", lay.a_rows), ("H", lay.h_rows), ("M", M_ROWS), ("endpoint", w.endpoint_rows)])
        .expect("no rung-W14 commitment's column collides with a non-column hash input (C-H4)");
    // ---- the ENDPOINT commitment's geometry: 125M's log and rate over a
    // quarter of 125M's cube
    let (ew, em) = (endpoint_pcs_params(&w), endpoint_pcs_params(&m));
    assert_eq!((ew.log_cols, ew.inv_rate, ew.num_col_checks), (14, 4, 256), "the rung-W14 endpoint PCS parameters");
    assert_eq!((ew.log_cols, ew.inv_rate, ew.num_col_checks), (em.log_cols, em.inv_rate, em.num_col_checks), "the endpoint parameters are not 125M's");
    assert_eq!(hash_domain::tree_depth(&ew), 16, "the endpoint's Merkle depth");
    assert_eq!((w.t_pad * w.d_pad, w.endpoint_rows), (65_536, 9), "the rung-W14 endpoint cube and row count");
    assert_eq!((m.t_pad * m.d_pad, m.endpoint_rows), (524_288, 37), "125M's endpoint cube and row count");
    assert_eq!(8 * w.endpoint_rows, 72, "the endpoint's opened-column digest length");
    eprintln!(
        "S32 ROW GEOMETRY: message 2^{} (encoded 2^{}, rate 1/{}), {} opened columns and {} pads, Merkle depth {}, NTT log {}, Dom::Tab lifted 2^8 -> 2^{} (x{}), rows_of {:?}, columns {} / {} B, endpoint log {} over {} rows (cube 2^16) — every one of them 125M's but the endpoint ROW COUNT (9 against 37)",
        w.log_cols,
        w.log_cols + 2,
        w.inv_rate,
        w.opened_cols,
        w.opened_cols,
        hash_domain::tree_depth(&pw),
        super::protocol::ntt_log_at(&w),
        w.log(Dom::Tab),
        w.size(Dom::Tab) / U8_LEN,
        ALL_DOMS.map(|d| w.rows_of(d)),
        8 * lay.a_rows,
        8 * lay.h_rows,
        w.endpoint_log_n,
        w.endpoint_rows
    );
}

// ---------------------------------------------------------------- the negative controls

/// **THE TAMPERS ONLY THIS ROW WIDTH REACHES.** Every earlier development
/// shape has rows of 2^8 or 2^10 words, so no test in the filter has ever
/// put a wrong value in a column index at or above 2^13 — the LAST COLUMN
/// BLOCK of a 2^14-wide row, the half of every row that only this width and
/// 125M have. Each case is placed so that the first slot whose relation it
/// breaks is the one named, the message is asserted to name that slot (so a
/// rejection by an earlier check cannot pass for one), and the column index
/// is asserted to be in the last block. The honest control is asserted
/// accepted first.
#[test]
fn a_tamper_in_the_last_column_block_of_a_row_is_rejected_at_its_own_slot_at_the_rung_w14() {
    let sh = Shape::rung_w14();
    let ids = Ids::new(&sh).expect("plane map");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-W14 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    assert!(outcome(&sh, &blk, clone_witness(&base)).is_accepted(), "the honest rung-W14 witness is not accepted");
    let cols = 1usize << sh.log_cols;
    let sup_d = witness::Geom::new(&sh).support(Dom::D);
    // the last supported `Dom::D` position whose column is in the upper half
    // of its row — a residual-2 word no narrower shape can place
    let deep_d = *sup_d.iter().rev().find(|i| *i % cols >= cols / 2).expect("a Dom::D support position in the last column block");
    let cases: [(&str, usize, usize, usize); 5] = [
        ("the gate A_G8 at the LAST index of the unpadded Dom::F (row 3, column 2^14 - 1)", ids.at(A_G8), sh.size(Dom::F) - 1, SC_FZC),
        ("the key A_K8 at the LAST index of the unpadded Dom::Kv, which is one whole row", ids.at(A_K8), sh.size(Dom::Kv) - 1, SC_KVZC),
        ("residual 2, A_X2, on the true Dom::D support in the LAST column block", ids.at(A_X2), deep_d, SC_DZC),
        ("the query A_Q8 in the last column block of a Dom::Q row", ids.at(A_Q8), 3 * cols + cols - 7, SC_QZC),
        ("the norm square A_DSQ at the last Dom::T position (a one-row domain)", ids.at(A_DSQ), sh.size(Dom::T) - 1, SC_TZC),
    ];
    let mut deep = 0usize;
    for (what, plane, at, slot) in cases {
        if at % cols >= cols / 2 {
            deep += 1;
        }
        let mut w = clone_witness(&base);
        w.planes[plane][at] += 1;
        let o = outcome(&sh, &blk, w);
        eprintln!("W14 TAMPER {what} (column {} of row {}): {}", at % cols, at / cols, o.short());
        match o {
            Outcome::Accepted => panic!("{what} was ACCEPTED at rung-W14"),
            Outcome::ProverRefused(e) => panic!("{what} was refused by the PROVER, which is not a soundness statement: {e}"),
            Outcome::VerifierRejected(e) => assert!(e.contains(&format!("slot {slot} [{}]", SLOT_NAMES[slot])), "{what} was rejected, but not by slot {slot} [{}]: {e}", SLOT_NAMES[slot]),
        }
    }
    assert!(deep >= 4, "only {deep} of the five tampers are in the last column block, so the case this shape adds is barely exercised");
    eprintln!("W14 TAMPER SWEEP: 5 of 5 rejected by the VERIFIER at the slot under test, {deep} of them at a column index >= 2^13 — a position no shape below this row width has");
}

/// **A MULTIPLICITY MOVED INTO A FAR LIFTED COPY OF ITS TABLE ROW.** The
/// `Dom::Tab` pad term is finding F-4's family: one count of the byte
/// histogram moves from a true table row to a PADDED copy of that same row,
/// the table helper that position needs is written too, and every LogUp
/// denominator and the total multiplicity are unchanged — so the value-0
/// identity and all three `SC_TAB` product relations still hold and only the
/// pad-zero term can object.
///
/// **What this shape adds.** At the rung the table is lifted from 256 to
/// 1,024, so the only copies are at `row + 256`, `+ 512` and `+ 768`. Here
/// the lift factor is **64** — 125M's own — so the same tamper can be placed
/// at `row + 8,192`, which is a different ROW of the commitment and a column
/// in the last block. Both are exercised, and the far one is the case no
/// smaller shape can write.
#[test]
fn a_multiplicity_moved_into_a_far_lifted_table_row_is_rejected_at_the_rung_w14() {
    let sh = Shape::rung_w14();
    assert_eq!(sh.size(Dom::Tab), 1usize << 14, "the rung-W14 table domain is not the lifted 2^14");
    assert_eq!(sh.size(Dom::Tab) / U8_LEN, 64, "the lift factor this test is about");
    let (public, ff, input) = super::grow_tests::tame_case(&sh);
    let blk = BlockPublic::new(public, ff);
    for (to, what) in [(256usize, "the first padded copy"), (8_192, "a copy 8,192 rows away, in the last column block")] {
        let w = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the rung-W14 honest witness");
        super::protocol::set_moved_multiplicity(Some((0, 0, to)));
        let o = outcome(&sh, &blk, w);
        super::protocol::set_moved_multiplicity(None);
        eprintln!("W14 F-4: one count of the byte histogram moved from table row 0 to {what} (index {to}): {}", o.short());
        assert!(!o.is_accepted(), "a multiplicity moved into a padded table row was ACCEPTED at rung-W14");
        assert!(matches!(o, Outcome::VerifierRejected(_)), "the moved multiplicity was caught only by the prover: {}", o.short());
    }
    // and the hook, left clear, changes nothing
    let w = witness::build_shaped(&sh, blk.attention(), blk.feed_forward(), &input).expect("the rung-W14 honest witness");
    assert!(outcome(&sh, &blk, w).is_accepted(), "the F-4 hook left a trace behind it at rung-W14");
}

/// **A WRONG GROUP BIT AT A HEAD DIMENSION OF 64.** The key family of
/// key-value groups 2 and 3 is exchanged: they share the HIGH group bit and
/// differ in the low one, which is the substitution a construction that
/// summed only the leading bit would be blind to. The values are untouched,
/// so this is a statement about the group map alone — and it is made here at
/// `head_dim = 64`, where each group block is 64 columns wide and the two
/// bilinear slots' coordinate lists are six entries longer than at
/// `head_dim = 8`.
#[test]
fn exchanging_the_keys_of_key_value_groups_two_and_three_is_rejected_at_the_rung_w14() {
    let sh = Shape::rung_w14();
    let ids = Ids::new(&sh).expect("plane map");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-W14 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let (dh, kvw) = (sh.head_dim, sh.kv_heads * sh.head_dim);
    assert_eq!(dh, 64, "this case is about the 64-wide head");
    let mut w = clone_witness(&base);
    let mut moved = 0usize;
    for p in [ids.at(A_K8), ids.at(A_RKL), ids.at(A_KR8), ids.at(A_RKRL)] {
        for t in 0..sh.t_pad {
            for i in 0..dh {
                let (a, b) = (t * kvw + 2 * dh + i, t * kvw + 3 * dh + i);
                if w.planes[p][a] != w.planes[p][b] {
                    moved += 1;
                }
                w.planes[p].swap(a, b);
            }
        }
    }
    assert!(moved > 0, "key-value groups 2 and 3 carry identical keys: the swap is a no-op");
    let o = outcome(&sh, &blk, w);
    eprintln!("W14 GQA: the key family of groups 2 and 3 exchanged ({moved} positions differ): {}", o.short());
    // MEASURED, and it is worth stating which slot: the four swapped planes
    // all live on `Dom::Kv`, whose host is slot 16, and 16 comes BEFORE the
    // two bilinear slots in nothing — it comes after them (8 and 9) in the
    // slot order — yet it is slot 16 that reports. The reason is that the
    // swap breaks the key-value zero-check's own relation (the rotation and
    // limb identities of the swapped columns) as well as the score, and the
    // verifier reports the first relation that fails in ITS order. The
    // bilinear slots' own group bits are reached by the next test, which
    // moves a SCORE word and leaves every `Dom::Kv` plane honest.
    match o {
        Outcome::VerifierRejected(e) => assert!(e.contains(&format!("slot {SC_KVZC} [{}]", SLOT_NAMES[SC_KVZC])), "the group swap was rejected, but not by the key-value zero-check: {e}"),
        o => panic!("the rung-W14 key swap was not rejected by the VERIFIER: {}", o.short()),
    }
}

/// **A WRONG SCORE IN THE FOURTH KEY-VALUE GROUP, AT A HEAD DIMENSION OF
/// 64.** One word of the score plane `A_S8` moves, at a NON-FIRST true
/// query head of the FOURTH key-value group — so neither the head index nor
/// the group index is zero, and the relation under test is the bilinear
/// score slot's, whose two private factors end in a shared
/// `rho(lkv .. lkv + log2(head_dim))` segment that is SIX entries long here
/// against three at `head_dim = 8`. Every `Dom::Kv` plane is left honest,
/// so the key-value zero-check has nothing to object to.
///
/// **Where it is rejected, and why that is the right place.** The score
/// matmul (slot 08) is a HOSTED slot: its claims ride the `Dom::S`
/// zero-check, slot 17 `06 softmax zero-check (hosts 07, 10)`, which is
/// where the verifier reports. MEASURED, and asserted as such — the
/// bilinear slot's own group bits are what the broken relation is about,
/// and the host is the slot that carries them.
#[test]
fn a_moved_score_word_in_the_fourth_group_is_rejected_at_its_host_slot_at_the_rung_w14() {
    let sh = Shape::rung_w14();
    let ids = Ids::new(&sh).expect("plane map");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-W14 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    assert!(outcome(&sh, &blk, clone_witness(&base)).is_accepted(), "the honest rung-W14 witness is not accepted");
    // query head 11 is the third head of key-value group 3; its padded head
    // slot is 14, inside the fourth group's own block
    let h = sh.q_heads - 1;
    let slot = sh.head_slot(h);
    assert_eq!(sh.kv_of_slot(slot), 3, "query head {h} must sit in key-value group 3");
    assert!(slot % sh.slots_per_kv_group() > 0, "query head {h} must not be the first head of its group");
    let tp = sh.t_pad;
    let at = (slot * tp + 5) * tp + 2; // head slot, token 5, source token 2 (causally live)
    let mut w = clone_witness(&base);
    w.planes[ids.at(A_S8)][at] += 1;
    let o = outcome(&sh, &blk, w);
    eprintln!("W14 GROUP BIT: one score word at head slot {slot} (key-value group 3), token 5, source 2: {}", o.short());
    match o {
        Outcome::VerifierRejected(e) => {
            assert!(e.contains(&format!("slot {SC_SZC} [{}]", SLOT_NAMES[SC_SZC])), "the moved score word was rejected, but not by the score slot's host: {e}");
            assert!(SLOT_NAMES[SC_SZC].contains("hosts 07, 10"), "slot {SC_SZC} no longer hosts the score matmul, so this test is asserting the wrong slot");
        }
        o => panic!("the moved score word was not rejected by the VERIFIER: {}", o.short()),
    }
}

/// **AN ENDPOINT WORD IN A COLUMN NO OLDER SHAPE HAS.** The endpoint
/// commits the padded `Dom::D` cube at its own row width, and at this shape
/// that width is `2^14` — 125M's, sixteen times the three 10-log rungs' and
/// sixty-four times the toy's. The proof is honest; what moves is the
/// VERIFIER's own statement, by one word of the input endpoint plane at a
/// column in the last block. The endpoint equality must refuse it.
#[test]
fn a_verifier_statement_with_one_moved_endpoint_word_is_refused_at_the_rung_w14() {
    let sh = Shape::rung_w14();
    let ids = Ids::new(&sh).expect("plane map");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-W14 dense honest witness");
    let (pin, pout) = (padded(&w, ids.at(A_X)), padded(&w, ids.at(A_X2)));
    let blk = BlockPublic::new(public, ff);
    let (expected, _receipt, bytes) = prove_w14(&sh, &blk, w).expect("the rung-W14 dense prover");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the honest control verifies");
    let cols = 1usize << sh.endpoint_log_n;
    let at = cols - 1; // the last column of the endpoint's first row
    assert!(at >= 1 << 13, "the moved word is not in the last column block");
    let mut moved = pin.clone();
    moved[at] = moved[at].wrapping_add(1);
    let spec = IoSpec::new_shaped(&sh, w14_context(), 0, 0).expect("the endpoint spec");
    let (other, _owners) = prepare_endpoints(spec, &moved, &pout).expect("the moved endpoint owners");
    let e = verify_bytes_at(&sh, &blk, &other, &bytes).expect_err("a receipt was accepted against a statement whose input endpoint differs by one word");
    eprintln!("W14 ENDPOINT: the verifier's input endpoint moved by one word at column {at} of a 2^{}-wide endpoint row: {e}", sh.endpoint_log_n);
    assert!(!e.is_empty(), "the refusal carries no message");
}

// ---------------------------------------------------------------- the chain band probe

/// **THE FIRST ADMISSIBLE TWO-BLOCK DOWN BAND AT rung-W14 — MEASURED**,
/// exactly as stage 21 measures it at rung-G, stage 22 at rung-K4, stage 30
/// at rung-P2 and stage 31 at rung-C6.
#[test]
fn the_pinned_rung_w14_chain_band_is_the_first_admissible_one() {
    use super::dense_tests::{band_down, band_down_run, dense_words_with, statement_of_words, BAND_ATTN, BAND_GATE, GAIN, INPUT_MAG};
    let sh = Shape::rung_w14();
    let ids = Ids::new(&sh).expect("plane map");
    let mut found: Option<i64> = None;
    for down in (1..=band_down(&sh)).rev() {
        let (words, input) = dense_words_with(&sh, BAND_ATTN, BAND_GATE, down, GAIN, INPUT_MAG);
        let (public, ff) = statement_of_words(&sh, &words);
        let mut x = input;
        let mut ok = true;
        for _ in 0..W14_RUN_BLOCKS {
            match witness::build_shaped(&sh, &public, &ff, &x) {
                Ok(w) => x = true_input(&sh, &padded(&w, ids.at(A_X2))),
                Err(m) => {
                    eprintln!("W14 DENSE RUN band {down}: the witness builder refused a block of the chain: {m}");
                    ok = false;
                    break;
                }
            }
        }
        if ok {
            found = Some(down);
            break;
        }
    }
    let band = found.expect("no fully dense band makes a chain admissible at rung-W14");
    eprintln!("W14 DENSE RUN: the first admissible {W14_RUN_BLOCKS}-block down band is {band} (the recipe's single-block band is {})", band_down(&sh));
    assert_eq!(band, band_down_run(&sh), "the band `dense_tests::band_down_run` pins for rung-W14 is not the first admissible one");
}

// ---------------------------------------------------------------- a two-block run

/// how many blocks this stage's run proves. Two is the least that has an
/// INTERNAL BOUNDARY, which is the part a run adds over a block, and at
/// about four seconds a block it is what the ordinary filter can carry at
/// this shape.
pub(super) const W14_RUN_BLOCKS: usize = 2;

/// The honest chain of `l` rung-W14 blocks: each block's hidden output is
/// the next one's hidden input, and none of it is published.
pub(super) struct W14Chain {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
}

impl W14Chain {
    pub(super) fn build(sh: &Shape, l: usize, public: AttentionPublic, ff: FeedForwardPublic, x0: Vec<i16>) -> W14Chain {
        let ids = Ids::new(sh).expect("the rung-W14 plane map");
        let (mut inputs, mut planes) = (Vec::with_capacity(l), Vec::with_capacity(l + 1));
        let mut x = x0;
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).expect("an honest witness of the rung-W14 chain");
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            x = true_input(sh, &w.output().expect("the block's hidden output"));
        }
        W14Chain { sh: sh.clone(), public, ff, inputs, planes }
    }
}

impl RunWitnessSource for W14Chain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        witness::build_shaped(&self.sh, &self.public, &self.ff, &self.inputs[k])
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(self.planes[k + 1].clone())
    }
}

/// the run statement and the two EXTERNAL endpoint owners of a rung-W14 chain
pub(super) fn w14_statement_of(c: &W14Chain, l: usize, blocks: &[BlockPublic]) -> (RunStatement, Endpoints) {
    let rs = RunShape::rung_w14(l).expect("the rung-W14 run shape");
    let spec = IoSpec::new_shaped(&c.sh, w14_context(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &c.planes[0], &c.planes[l]).expect("the run's external endpoint owners");
    let st = RunStatement::new(rs, w14_context(), expected, blocks, &vec![(0, 0); l]).expect("the rung-W14 run statement");
    (st, owners)
}

/// the fully dense rung-W14 chain of `l` blocks and its `l` public statements
pub(super) fn w14_dense_chain(l: usize) -> (W14Chain, Vec<BlockPublic>) {
    let sh = Shape::rung_w14();
    let (public, ff, x0) = super::dense_tests::dense_run_case(&sh);
    let blocks = (0..l).map(|_| BlockPublic::new(public.clone(), ff.clone())).collect();
    (W14Chain::build(&sh, l, public, ff, x0), blocks)
}

/// **AN HONEST TWO-BLOCK FULLY DENSE rung-W14 RUN VERIFIES FROM ITS
/// SEGMENTS.** Two blocks under one transcript, each block's hidden output
/// the next one's hidden input and neither published, at the 125M row width
/// — so the run layer's internal boundary is exercised at a 2^14-wide
/// endpoint geometry, which only an `#[ignore]`d 125M run reached before.
/// The segment lengths are the counted ones, byte for byte, and every
/// block's census is asserted.
#[test]
fn an_honest_two_block_fully_dense_run_verifies_from_its_segments_at_the_rung_w14() {
    let sh = Shape::rung_w14();
    let ids = Ids::new(&sh).expect("plane map");
    let l = W14_RUN_BLOCKS;
    let (mut c, blocks) = w14_dense_chain(l);
    for k in 0..l {
        let w = witness::build_shaped(&sh, &c.public, &c.ff, &c.inputs[k]).expect("a fully dense witness of the chain");
        assert_non_trivial(&sh, &ids, &w, &format!("run block {k}"));
    }
    let (st, owners) = w14_statement_of(&c, l, &blocks);
    let rows = st.boundary_spec(0).expect("the run's first boundary").commitment_rows();
    // MEASURED: ten, one more than an external endpoint's nine. The boundary
    // commits the same padded `Dom::D` cube at the same endpoint row width —
    // four data rows — but carries `BOUNDARY_SITES = 2` reserved IO tab rows
    // where an external endpoint carries one, which is the same +1 the
    // rung-G boundary has over its own nine-row endpoint.
    assert_eq!(rows, 10, "the internal boundary's commitment row count");
    assert_eq!(rows, sh.endpoint_rows + 1, "the boundary is not one row more than an external endpoint at this shape");
    let mut segs: Vec<Vec<u8>> = Vec::new();
    let t0 = std::time::Instant::now();
    let stats = run::prove_run(&st, &blocks, &mut c, owners, &mut |k, b| {
        assert_eq!(k, segs.len(), "the sink was handed the segments out of order");
        segs.push(b);
        Ok(())
    })
    .expect("the honest two-block fully dense rung-W14 run proves");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(stats.segment_bytes, super::run_tests::counted_segment_bytes(&sh, l, rows), "a rung-W14 segment is not the counted length");
    let t1 = std::time::Instant::now();
    run::verify_run(&st, &blocks, &segs).expect("the honest two-block fully dense rung-W14 run verifies from its segments");
    eprintln!(
        "W14 FULLY DENSE RUN L={l} (down band {}): prove {prove_s:.2} s, verify from segments {:.2} s, segments {:?} B (total {} B), boundary {rows} rows",
        super::dense_tests::band_down_run(&sh),
        t1.elapsed().as_secs_f64(),
        stats.segment_bytes,
        stats.segment_bytes.iter().sum::<usize>()
    );
}
