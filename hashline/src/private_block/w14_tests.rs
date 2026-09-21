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
//! **THE CAPTURE RULE.** Everything here is public synthetic test data from
//! fixed-seed integer streams; what the census prints is counts, fractions
//! and live-slot counts, never a witness value or a position.

use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::review_tests::{clone_witness, outcome, Outcome};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use crate::field::Fp2;

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
