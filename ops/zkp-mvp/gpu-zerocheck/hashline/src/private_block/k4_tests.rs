//! **STAGE 22: THE FOUR-KEY-VALUE-HEAD DEVELOPMENT SHAPE, PROVED.**
//!
//! **The gap this closes.** Stage 20 made the key-value GROUP a set of
//! sumcheck variables: `lkv = log2(kv_heads)` of them, summed under a public
//! `eq(r_g, .)`. Everything this lane has PROVED or CAPTURED since is at
//! `lkv = 1` — the two development rungs, six query heads over two key-value
//! heads — or at `lkv = 0`, the frozen toy, where the repair is a no-op and
//! costs not one byte. The only `lkv = 2` shape is 125M, whose runs are 484
//! MB of receipt and which the Python privacy gate cannot ingest at all. So
//! the case where **the group is more than one bit** has been exercised by
//! algebra (`dense_tests`' Boolean-cube check on random planes, and the
//! independent review's `kv4` probe through `argument::define`) and by
//! nothing that produces a receipt a tool can read.
//!
//! [`Shape::rung_k4`] is the smallest honest place to close that: rung-G's
//! geometry with the heads recut as **12 query heads of 8 over 4 key-value
//! heads**, padded head slots `{3, 7, 11, 15}` — 125M's own head geometry —
//! and therefore `lkv = 2`, three true query heads per group and a padded
//! slot inside every group's block.
//!
//! **WHAT A GREEN RUN HERE IS, AND IS NOT.** A CORRECTNESS result at a new
//! development-grade profile (ruling P-7): the honest prover and the honest
//! verifier agree, the witness equals an independent reference kernel, the
//! two bilinear identities hold when evaluated outside the argument, and
//! every tamper in the third and fourth key-value group is rejected by the
//! VERIFIER. It is NOT a privacy result and NOT an acceptance: no gate has
//! read the bundles this shape produces, and ruling M-8 is not met by
//! writing a bundle.
//!
//! **THE CAPTURE RULE.** Everything here is public synthetic test data from
//! fixed-seed integer streams; the counts the census prints are fractions
//! and live-slot totals, never a value or a position, and the retained logs
//! are taken without `--nocapture`.

use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::review_tests::{clone_witness, outcome, Outcome};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;

// ---------------------------------------------------------------- the shape's own facts

/// **THE COUNTED RECEIPT LENGTH OF ONE rung-K4 BLOCK.**
///
/// This is the INDEPENDENT Python model's own output at this shape
/// (`scripts/zk60_private_block_layout_model.py`, `SHAPES["rung_k4"]`),
/// transcribed, with nothing in between: rung-K4's endpoint takes the
/// block's own PCS parameters, exactly as rung-G's does, so there is no
/// Rust-side correction term of the kind the frozen-seam rung (+45,056 B)
/// and 125M (+32,768 B) USED to carry — **both of those went away in lane
/// stage 23**, when the model learnt to derive every endpoint's geometry
/// instead of declaring it (the shaped check's finding B-12), so all five
/// shapes now agree with the model to the byte. `grow_tests::MODEL_RUNG_K4`
/// compares every other figure of the layout the same way.
pub(super) const K4_FRAME_BYTES: usize = 4_743_128;

/// **THE DOWN-PROJECTION BAND A rung-K4 CHAIN CARRIES**, which
/// `dense_tests::band_down_run` pins for this shape and
/// [`the_pinned_rung_k4_chain_band_is_the_first_admissible_one`] MEASURES.
fn k4_run_band() -> i64 {
    super::dense_tests::band_down_run(&Shape::rung_k4())
}

fn k4_context() -> Digest {
    *blake3::hash(b"private block: stage 22, the four-key-value-head development shape").as_bytes()
}

/// the padded plane of a witness, as `int16`
fn padded(w: &Witness, plane: usize) -> Vec<i16> {
    w.planes[plane].iter().map(|v| i16::try_from(*v).expect("a plane word outside int16")).collect()
}

/// the TRUE `(tokens, width)` input inside a padded `Dom::D` plane
fn true_input(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

fn endpoints_of(sh: &Shape, w: &Witness) -> (ExpectedIo, Endpoints) {
    let ids = Ids::new(sh).expect("the rung-K4 plane map");
    let spec = IoSpec::new_shaped(sh, k4_context(), 0, 0).expect("the rung-K4 endpoint spec");
    prepare_endpoints(spec, &padded(w, ids.at(A_X)), &padded(w, ids.at(A_X2))).expect("the rung-K4 endpoint owners")
}

fn prove_k4(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<(ExpectedIo, Receipt, Vec<u8>), String> {
    let (expected, owners) = endpoints_of(sh, &w);
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners)?;
    let bytes = receipt.to_bytes_at(sh, blk, &expected)?;
    Ok((expected, receipt, bytes))
}

// ---------------------------------------------------------------- the geometry itself

/// **THE SHAPE IS WHAT IT SAYS IT IS**, before anything is proved at it:
/// every dimension, the head permutation, the padded slots, the two group
/// bits, the fact that no domain is lifted by P-3 (which the bilinear slots
/// require, ruling F-2 of stage 21), and that it is a NEW profile with its
/// own hash-tag key set (D17) that shares nothing with rung-G's.
#[test]
fn the_rung_k4_shape_is_the_four_key_value_head_geometry_it_claims() {
    let sh = Shape::rung_k4();
    let g = Shape::rung_g();
    assert_eq!((sh.tokens, sh.width, sh.hidden), (24, 96, 192), "rung-K4's block dimensions");
    assert_eq!((sh.q_heads, sh.head_dim, sh.kv_heads), (12, 8, 4), "rung-K4's head axis");
    assert_eq!((sh.t_pad, sh.d_pad, sh.h_pad, sh.f_pad), (32, 128, 16, 256), "rung-K4's padded axes");
    assert_eq!(sh.d_pad, sh.h_pad * sh.head_dim, "the padded head slots do not tile the padded width");
    assert_eq!(sh.width, sh.q_heads * sh.head_dim, "the true heads do not tile the width");
    assert_eq!(sh.kv_heads.trailing_zeros() as usize, 2, "rung-K4 must carry TWO group bits, which is the whole point of it");
    assert_eq!(sh.slots_per_kv_group(), 4, "slots per key-value group");
    assert_eq!(sh.q_heads / sh.kv_heads, 3, "true query heads per key-value group");
    // THE HEAD PERMUTATION: three true heads then one pad, four times over
    let slots: Vec<usize> = (0..sh.q_heads).map(|h| sh.head_slot(h)).collect();
    assert_eq!(slots, vec![0, 1, 2, 4, 5, 6, 8, 9, 10, 12, 13, 14], "the head permutation");
    let padded_slots: Vec<usize> = (0..sh.h_pad).filter(|s| !sh.slot_is_true_head(*s)).collect();
    assert_eq!(padded_slots, vec![3, 7, 11, 15], "the padded head slots are not 125M's {{3, 7, 11, 15}}");
    for sl in 0..sh.h_pad {
        assert_eq!(sh.kv_of_slot(sl), sl / 4, "slot {sl}'s key-value group is not its high bits");
    }
    // NO DOMAIN IS LIFTED where the bilinear arms write their coordinate
    // lists (stage 21's F-2 refusal): `Dom::Kv` sits EXACTLY at the row
    // width, which is the toy's case and not a lift, and the other two are
    // above it.
    for dom in [Dom::Q, Dom::Kv, Dom::S] {
        assert_eq!(sh.log(dom), sh.natural_log(dom), "{dom:?} is lifted by P-3, so the bilinear slots cannot serve this shape");
    }
    assert_eq!((sh.log(Dom::Q), sh.log(Dom::Kv), sh.log(Dom::S)), (12, 10, 14), "the three bilinear domains' logs");
    assert_eq!(sh.log(Dom::Kv), sh.log_cols, "Dom::Kv is meant to sit exactly at the row width");
    // rung-G's geometry in every other respect, so the difference this shape
    // makes is the HEAD AXIS and nothing else
    for (what, a, b) in [
        ("tokens", sh.tokens, g.tokens),
        ("width", sh.width, g.width),
        ("hidden", sh.hidden, g.hidden),
        ("log_cols", sh.log_cols, g.log_cols),
        ("inv_rate", sh.inv_rate, g.inv_rate),
        ("endpoint_rows", sh.endpoint_rows, g.endpoint_rows),
        ("endpoint_log_n", sh.endpoint_log_n, g.endpoint_log_n),
        ("endpoint_inv_rate", sh.endpoint_inv_rate, g.endpoint_inv_rate),
    ] {
        assert_eq!(a, b, "rung-K4's {what} differs from rung-G's; only the head axis was meant to move");
    }
    assert_eq!((sh.f_e, sh.norm_wrho, sh.wrho_s), (g.f_e, g.norm_wrho, g.wrho_s), "rung-K4's calibration differs from rung-G's");
    assert!(sh.endpoint_general, "rung-K4 must ride the GENERALISED endpoint");
    assert!(sh.carries_pad_rule(), "rung-K4 must carry the pad rule");
    // D17: its own profile, its own key set, and the toy untouched
    assert_eq!(sh.profile, "hashline-zk-mr1/private-block-rung-k4-t24-dev/1");
    assert_ne!(sh.profile, g.profile, "two shapes share a profile");
    assert!(!sh.hashes_under_the_legacy_rule(), "rung-K4 must be TAGGED");
    assert_ne!(sh.hash_tag(), g.hash_tag(), "rung-K4 and rung-G share a hash-tag key set");
    assert_eq!(run::RUN_PROFILE_RUNG_K4, "hashline-zk-mr1/private-run-rung-k4-t24-dev/1");
    assert_ne!(run::RUN_PROFILE_RUNG_K4, run::RUN_PROFILE_RUNG_G, "two runs share a profile");
    // the counted receipt, and the two bilinear slots that carry the repair
    assert_eq!(sh.receipt_bytes().total, K4_FRAME_BYTES, "the counted rung-K4 receipt is not the model's");
    assert_eq!(sh.slots()[SC_SCORE], (5, 2, 3), "SC_SCORE at rung-K4: lkv(2) + log2(head_dim)(3) main rounds, degree 3");
    assert_eq!(sh.slots()[SC_PV], (7, 2, 3), "SC_PV at rung-K4: lkv(2) + log2(t_pad)(5) main rounds, degree 3");
    assert_eq!((sh.slot_lengths()[SC_SCORE], sh.slot_lengths()[SC_PV]), (23, 29), "the two bilinear mask lengths");
    assert!(sh.slot_lengths().iter().all(|l| l + 256 <= 512), "a mask row leaves the M budget");
    eprintln!(
        "S22 rung-K4: T{}/d{}/f{}, {} heads of {} over {} KV heads, pads ({}, {}, {}, {}), lkv 2, padded slots {padded_slots:?}, largest L {}, receipt {} B",
        sh.tokens,
        sh.width,
        sh.hidden,
        sh.q_heads,
        sh.head_dim,
        sh.kv_heads,
        sh.t_pad,
        sh.d_pad,
        sh.h_pad,
        sh.f_pad,
        sh.slot_lengths().iter().max().expect("slots"),
        sh.receipt_bytes().total
    );
}

// ---------------------------------------------------------------- one honest block

/// how non-trivial a rung-K4 witness is, as FRACTIONS and LIVE-SLOT COUNTS
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
    for sl in (0..sh.h_pad).filter(|s| !sh.slot_is_true_head(*s)) {
        assert!(!(0..sh.tokens).flat_map(|t| (0..dh).map(move |c| t * dp + sl * dh + c)).any(|i| o8[i] != 0), "{what}: padded head slot {sl} carries an attention output");
    }
    let (kr, v8) = (&w.planes[ids.at(A_KR8)], &w.planes[ids.at(A_V8)]);
    let group_live = |p: &Vec<i64>, g: usize| (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| j * kvw + g * dh + c)).any(|i| p[i] != 0);
    let live_groups = (0..sh.kv_heads).filter(|g| group_live(kr, *g) && group_live(v8, *g)).count();
    assert_eq!(live_groups, 4, "{what}: only {live_groups} of the four key-value groups carry nonzero keys AND values");
    // ALL FOUR groups pairwise different, not merely "some two differ": with
    // two group bits, a witness in which three groups coincide would leave
    // most of the repaired `eq(r_g, .)` unexercised
    for a in 0..sh.kv_heads {
        for b in a + 1..sh.kv_heads {
            let differs = (0..sh.tokens).flat_map(|j| (0..dh).map(move |c| (j, c))).any(|(j, c)| kr[j * kvw + a * dh + c] != kr[j * kvw + b * dh + c]);
            assert!(differs, "{what}: key-value groups {a} and {b} carry IDENTICAL rotated keys, so the two group bits are not exercised");
        }
    }
    eprintln!("S22 CENSUS [{what}]: 12/12 head slots live, 4/4 key-value groups live and pairwise different, the upper hidden half live");
}

/// **THE HONEST rung-K4 BLOCK PROVES AND VERIFIES FROM BYTES**, on the FULLY
/// DENSE recipe with a generic hidden input — every entry of all nine public
/// words nonzero, the two group bits carrying four genuinely different
/// key-value groups, the upper hidden half of the feed-forward planes live.
/// The frame is the counted length, and a one-byte truncation is refused.
#[test]
fn an_honest_dense_block_proves_and_verifies_from_bytes_at_the_rung_k4() {
    let sh = Shape::rung_k4();
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-K4 dense honest witness");
    let ids = Ids::new(&sh).expect("the rung-K4 plane map");
    assert!(super::pad::every_checkable_relation_holds(&sh, &ids, &w), "the honest rung-K4 witness is internally inconsistent");
    assert_non_trivial(&sh, &ids, &w, "one dense block");
    let blk = BlockPublic::new(public, ff);
    let t0 = std::time::Instant::now();
    let (expected, receipt, bytes) = prove_k4(&sh, &blk, w).expect("the rung-K4 dense prover");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(bytes.len(), K4_FRAME_BYTES, "the rung-K4 frame is not the counted length");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the rung-K4 receipt verifies in typed form");
    let t1 = std::time::Instant::now();
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the rung-K4 receipt verifies from bytes");
    eprintln!("rung-K4 DENSE one block: prove {prove_s:.2} s, verify from bytes {:.2} s, frame {} B", t1.elapsed().as_secs_f64(), bytes.len());
    assert!(verify_bytes_at(&sh, &blk, &expected, &bytes[..bytes.len() - 1]).is_err(), "a short rung-K4 frame was accepted");
}

/// **THE DEGENERATE CASE, NAMED AS ONE.** The all-zero hidden input on the
/// lane's synthetic tame fixture proves and verifies at rung-K4. It says
/// nothing about the group bits — every key-value group is identically zero
/// — and it exists because it is the fixed input the privacy case is stated
/// at, and because it is the witness the second capture bundle carries.
#[test]
fn the_all_zero_input_is_a_degenerate_case_that_proves_and_verifies_at_the_rung_k4() {
    let sh = Shape::rung_k4();
    let (public, ff, _) = super::grow_tests::tame_case(&sh);
    let input = vec![0i16; sh.tokens * sh.width];
    let w = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-K4 all-zero witness");
    let blk = BlockPublic::new(public, ff);
    let (expected, receipt, bytes) = prove_k4(&sh, &blk, w).expect("the rung-K4 all-zero prover");
    assert_eq!(bytes.len(), K4_FRAME_BYTES, "a receipt's length is a function of the shape alone");
    verify_inner_at(&sh, &blk, &expected, &receipt).expect("the all-zero receipt verifies in typed form");
    verify_bytes_at(&sh, &blk, &expected, &bytes).expect("the all-zero receipt verifies from bytes");
    eprintln!("rung-K4 ALL-ZERO (degenerate) one block: frame {} B, verified", bytes.len());
}

// ---------------------------------------------------------------- the negative controls

/// **EVERY TAMPER IN THE THIRD AND FOURTH KEY-VALUE GROUP IS REJECTED BY THE
/// VERIFIER.**
///
/// With `lkv = 1` the "other" group is the only other group; with `lkv = 2`
/// there are four, and a construction that got the HIGH group bit right and
/// the low one wrong — or that summed only one of the two — would still pass
/// every rung-G control. These move mass in groups 2 and 3, which exist only
/// at this shape:
///
/// * `A_KR8` and `A_V8` in the THIRD group and in the FOURTH;
/// * `A_QR8` and `A_P` at a NON-FIRST true query head of the FOURTH group
///   (head slot 13), so neither the head nor the group is index 0;
/// * `A_P` at a PADDED head slot of the fourth group (slot 15), which `r_hj`
///   being a random field point makes enforceable.
///
/// The honest control is asserted ACCEPTED first, or none of it is a
/// statement. A refusal by the PROVER would not be one either — a cheating
/// prover does not run the honest prover's checks — so the count of
/// verifier rejections is reported and asserted separately.
#[test]
fn a_perturbation_in_the_third_or_fourth_key_value_group_is_rejected_at_the_rung_k4() {
    let sh = Shape::rung_k4();
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-K4 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let ids = Ids::new(&sh).expect("the rung-K4 plane map");
    let (tp, dp, dh) = (sh.t_pad, sh.d_pad, sh.head_dim);
    let kvw = sh.kv_heads * dh;
    let honest = outcome(&sh, &blk, clone_witness(&base));
    assert!(honest.is_accepted(), "the honest rung-K4 witness is not accepted: {}", honest.short());
    // query head 11 is the THIRD head of key-value group 3: neither the
    // first head of its group nor a first group
    let (h, kv) = (11usize, 3usize);
    assert_eq!(h / (sh.q_heads / sh.kv_heads), kv, "query head 11 must sit in key-value group 3");
    let slot = sh.head_slot(h);
    assert_eq!(slot, 14, "query head 11's padded slot moved");
    let pad_slot = 15usize;
    assert!(!sh.slot_is_true_head(pad_slot) && sh.kv_of_slot(pad_slot) == 3, "slot 15 must be the fourth group's padded slot");
    let cases: [(&str, usize, usize); 6] = [
        ("A_KR8, the rotated key of the THIRD key-value group", ids.at(A_KR8), 3 * kvw + 2 * dh + 5),
        ("A_V8, the value of the THIRD key-value group", ids.at(A_V8), 6 * kvw + 2 * dh + 1),
        ("A_KR8, the rotated key of the FOURTH key-value group", ids.at(A_KR8), 4 * kvw + 3 * dh + 2),
        ("A_V8, the value of the FOURTH key-value group", ids.at(A_V8), 7 * kvw + 3 * dh + 6),
        ("A_QR8, the rotated query of a non-first head of the FOURTH group", ids.at(A_QR8), 3 * dp + slot * dh + 5),
        ("A_P, a causally live softmax weight of a non-first head of the FOURTH group", ids.at(A_P), (slot * tp + 5) * tp + 2),
    ];
    let (mut prover, mut verifier) = (0usize, 0usize);
    for (what, plane, at) in cases {
        let mut w = clone_witness(&base);
        w.planes[plane][at] += 1;
        let o = outcome(&sh, &blk, w);
        eprintln!("K4 GROUP TAMPER {what}: {}", o.short());
        match o {
            Outcome::Accepted => panic!("{what} was ACCEPTED at rung-K4"),
            Outcome::ProverRefused(_) => prover += 1,
            Outcome::VerifierRejected(_) => verifier += 1,
        }
    }
    // and the PADDED head slot of the fourth group is not free parking
    let mut w = clone_witness(&base);
    w.planes[ids.at(A_P)][(pad_slot * tp + 5) * tp + 2] += 1;
    let o = outcome(&sh, &blk, w);
    eprintln!("K4 GROUP TAMPER A_P at the FOURTH group's PADDED head slot 15: {}", o.short());
    match o {
        Outcome::Accepted => panic!("mass in the fourth group's padded head slot was ACCEPTED"),
        Outcome::ProverRefused(_) => prover += 1,
        Outcome::VerifierRejected(_) => verifier += 1,
    }
    eprintln!("K4 THIRD/FOURTH-GROUP SWEEP: {prover} refused by the prover, {verifier} rejected by the VERIFIER, 0 accepted");
    assert_eq!(prover + verifier, 7, "not every case was exercised");
    assert_eq!(verifier, 7, "a tamper was caught by the prover rather than the verifier, which is not a soundness statement");
}

/// **EXCHANGING THE KEY FAMILY OF GROUPS 2 AND 3 IS REJECTED BY THE
/// VERIFIER.** Not groups 0 and 1 — those differ only in the LOW group bit
/// at a shape with four groups, and the rung-G control already covers one
/// bit. Groups 2 and 3 share the high bit and differ in the low one WITHIN
/// the upper half, which is the substitution a construction that summed only
/// the leading group bit would be blind to. The values are untouched, so
/// this is a statement about the group map and nothing else.
#[test]
fn exchanging_the_keys_of_key_value_groups_two_and_three_is_rejected_at_the_rung_k4() {
    let sh = Shape::rung_k4();
    assert_eq!(sh.kv_heads, 4, "this case is written for four key-value groups");
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the rung-K4 dense honest witness");
    let blk = BlockPublic::new(public, ff);
    let ids = Ids::new(&sh).expect("the rung-K4 plane map");
    let (dh, kvw) = (sh.head_dim, sh.kv_heads * sh.head_dim);
    assert!(outcome(&sh, &blk, clone_witness(&base)).is_accepted(), "the honest rung-K4 witness is not accepted");
    let key_planes = [ids.at(A_K8), ids.at(A_RKL), ids.at(A_KR8), ids.at(A_RKRL)];
    let mut w = clone_witness(&base);
    let mut moved = 0usize;
    for p in key_planes {
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
    eprintln!("K4 GQA: the key family of groups 2 and 3 exchanged ({moved} positions differ): {}", o.short());
    assert!(matches!(o, Outcome::VerifierRejected(_)), "the rung-K4 key swap was not rejected by the VERIFIER: {}", o.short());
}

// ---------------------------------------------------------------- a three-block run

/// The honest chain of `l` rung-K4 blocks: each block's hidden output is the
/// next one's hidden input, and none of it is published.
pub(super) struct K4Chain {
    sh: Shape,
    public: AttentionPublic,
    ff: FeedForwardPublic,
    inputs: Vec<Vec<i16>>,
    planes: Vec<Vec<i16>>,
}

impl K4Chain {
    pub(super) fn build(sh: &Shape, l: usize, public: AttentionPublic, ff: FeedForwardPublic, x0: Vec<i16>) -> K4Chain {
        let ids = Ids::new(sh).expect("the rung-K4 plane map");
        let (mut inputs, mut planes) = (Vec::with_capacity(l), Vec::with_capacity(l + 1));
        let mut x = x0;
        for k in 0..l {
            let w = witness::build_shaped(sh, &public, &ff, &x).expect("an honest witness of the rung-K4 chain");
            if k == 0 {
                planes.push(padded(&w, ids.at(A_X)));
            }
            planes.push(padded(&w, ids.at(A_X2)));
            inputs.push(x);
            x = true_input(sh, &w.output().expect("the block's hidden output"));
        }
        K4Chain { sh: sh.clone(), public, ff, inputs, planes }
    }
}

impl RunWitnessSource for K4Chain {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        witness::build_shaped(&self.sh, &self.public, &self.ff, &self.inputs[k])
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        Ok(self.planes[k + 1].clone())
    }
}

/// the run statement and the two EXTERNAL endpoint owners of a rung-K4 chain
pub(super) fn k4_statement_of(c: &K4Chain, l: usize, blocks: &[BlockPublic]) -> (RunStatement, Endpoints) {
    let rs = RunShape::rung_k4(l).expect("the rung-K4 run shape");
    let spec = IoSpec::new_shaped(&c.sh, k4_context(), 0, 0).expect("the run's endpoint spec");
    let (expected, owners) = prepare_endpoints(spec, &c.planes[0], &c.planes[l]).expect("the run's external endpoint owners");
    let st = RunStatement::new(rs, k4_context(), expected, blocks, &vec![(0, 0); l]).expect("the rung-K4 run statement");
    (st, owners)
}

/// the fully dense rung-K4 chain of `l` blocks and its `l` public statements
pub(super) fn k4_dense_chain(l: usize) -> (K4Chain, Vec<BlockPublic>) {
    let sh = Shape::rung_k4();
    let (public, ff, x0) = super::dense_tests::dense_run_case(&sh);
    let blocks = (0..l).map(|_| BlockPublic::new(public.clone(), ff.clone())).collect();
    (K4Chain::build(&sh, l, public, ff, x0), blocks)
}

/// **THE PINNED CHAIN BAND IS THE FIRST ADMISSIBLE ONE — MEASURED.** Exactly
/// as stage 21 does at rung-G: the down-projection band is walked DOWN from
/// the recipe's own single-block band and the first one at which the witness
/// builder accepts all three blocks is taken, with every other band — the
/// attention words included — left at the recipe's, so the two group bits
/// carry genuinely different data at every candidate.
#[test]
fn the_pinned_rung_k4_chain_band_is_the_first_admissible_one() {
    use super::dense_tests::{band_down, dense_words_with, statement_of_words, BAND_ATTN, BAND_GATE, GAIN, INPUT_MAG};
    let sh = Shape::rung_k4();
    let ids = Ids::new(&sh).expect("plane map");
    let mut found: Option<i64> = None;
    for down in (1..=band_down(&sh)).rev() {
        let (words, input) = dense_words_with(&sh, BAND_ATTN, BAND_GATE, down, GAIN, INPUT_MAG);
        let (public, ff) = statement_of_words(&sh, &words);
        let mut x = input;
        let mut ok = true;
        for _ in 0..3 {
            match witness::build_shaped(&sh, &public, &ff, &x) {
                Ok(w) => x = true_input(&sh, &padded(&w, ids.at(A_X2))),
                Err(m) => {
                    eprintln!("K4 DENSE RUN band {down}: the witness builder refused a block of the chain: {m}");
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
    let band = found.expect("no fully dense band makes a three-block chain admissible at rung-K4");
    eprintln!("K4 DENSE RUN: the first admissible three-block down band is {band} (the recipe's single-block band is {})", band_down(&sh));
    assert_eq!(band, k4_run_band(), "the band `dense_tests::band_down_run` pins for rung-K4 is not the first admissible one");
}

/// **AN HONEST THREE-BLOCK FULLY DENSE rung-K4 RUN VERIFIES FROM ITS
/// SEGMENTS.** Three blocks under one transcript, each block's hidden output
/// the next one's hidden input and neither published, at a shape with two
/// group bits — and the segment lengths are the counted ones, byte for byte.
/// Every block's census is asserted, so the four key-value groups carry
/// different data in all three blocks and not only the first.
///
/// A CORRECTNESS milestone at a development profile, not a privacy one.
#[test]
fn an_honest_three_block_fully_dense_run_verifies_from_its_segments_at_the_rung_k4() {
    let sh = Shape::rung_k4();
    let ids = Ids::new(&sh).expect("plane map");
    let (mut c, blocks) = k4_dense_chain(3);
    for k in 0..3 {
        let w = witness::build_shaped(&sh, &c.public, &c.ff, &c.inputs[k]).expect("a fully dense witness of the chain");
        assert_non_trivial(&sh, &ids, &w, &format!("run block {k}"));
    }
    let (st, owners) = k4_statement_of(&c, 3, &blocks);
    let rows = st.boundary_spec(0).expect("the run's first boundary").commitment_rows();
    let mut segs: Vec<Vec<u8>> = Vec::new();
    let t0 = std::time::Instant::now();
    let stats = run::prove_run(&st, &blocks, &mut c, owners, &mut |k, b| {
        assert_eq!(k, segs.len(), "the sink was handed the segments out of order");
        segs.push(b);
        Ok(())
    })
    .expect("the honest three-block fully dense rung-K4 run proves");
    let prove_s = t0.elapsed().as_secs_f64();
    assert_eq!(stats.segment_bytes, super::run_tests::counted_segment_bytes(&sh, 3, rows), "a rung-K4 segment is not the counted length");
    let t1 = std::time::Instant::now();
    run::verify_run(&st, &blocks, &segs).expect("the honest three-block fully dense rung-K4 run verifies from its segments");
    eprintln!(
        "K4 FULLY DENSE RUN L=3 (down band {}): prove {prove_s:.2} s, verify from segments {:.2} s, segments {:?} B (total {} B), boundary {rows} rows",
        k4_run_band(),
        t1.elapsed().as_secs_f64(),
        stats.segment_bytes,
        stats.segment_bytes.iter().sum::<usize>()
    );
}
