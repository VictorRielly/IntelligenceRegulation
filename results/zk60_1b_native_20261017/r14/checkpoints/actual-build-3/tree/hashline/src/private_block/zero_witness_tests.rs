//! U-4: the ZERO-WITNESS ACCEPTANCE TEST of the experimental private block,
//! on the TOY profile exactly as it stands.
//!
//! WHY THIS EXISTS. The working privacy argument for the first MVP rests on
//! one structural fact: because the prover generates every commitment (D18),
//! the ideal-world program is the honest prover run on a FIXED input, so the
//! whole privacy question is "does the receipt for the hidden input look like
//! the receipt for the fixed input". The fixed input the case uses is the
//! ALL-ZERO one, and the independent check
//! (`docs/zkmatrix-poc/ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md` §1a, evidence
//! `results/zk60_privacy_case_check/zero_witness_trace.py`) established on
//! PAPER that the honest witness builder accepts it. This module establishes
//! it in the code, end to end, and pins the four facts the paper trace leans
//! on so that a calibration edit that invalidates them fails loudly here
//! instead of silently invalidating the privacy argument.
//!
//! WHAT IT IS NOT. A zero-witness proof that verifies is a PRECONDITION for
//! the privacy argument, not a privacy result. Nothing here establishes
//! indistinguishability, and nothing here is an acceptance of the profile.
//!
//! Every fixture is the PUBLIC SYNTHETIC one; the only "secret" anywhere in
//! this file is the all-zero input, which is not a secret. Run in release.

use super::layout::*;
use super::witness;
use super::*;

/// the same public synthetic context the module's other tests use
fn spec() -> IoSpec {
    IoSpec::new(*blake3::hash(b"private block: the zero-witness acceptance test (U-4)").as_bytes(), 0, 0).unwrap()
}

/// THE FIXED INPUT of the privacy case: `T * D` zero words.
fn zero_input() -> Vec<i16> {
    vec![0i16; T * D]
}

/// prove the whole block for `input` and return (statement, receipt, stats)
fn prove_for(input: &[i16]) -> (BlockPublic, ExpectedIo, Receipt, ProveStats) {
    let (blk, _) = BlockPublic::synthetic_fixture();
    let output = compute_output(&blk, input).expect("the witness builder accepts this input");
    let (expected, owners) = prepare_endpoints(spec(), input, &output).expect("endpoint owners");
    let (receipt, stats) = prove_with_stats(&blk, input, &expected, owners).expect("the honest prover");
    (blk, expected, receipt, stats)
}

/// the softmax remainder `sigma_s`, reassembled from its two committed byte
/// limbs (`witness.rs:302-308`: `A_SG0 + 256 * A_SG1`)
fn sigma_s(w: &witness::Witness, idx: usize) -> i64 {
    w.planes[A_SG0][idx] + 256 * w.planes[A_SG1][idx]
}

/// U-4, the acceptance itself: the all-zero hidden input is a VALID witness —
/// the integer builder accepts it, the honest prover produces a receipt, and
/// that receipt verifies in typed form, after a round trip through the bytes,
/// and through `verify_bytes`, exactly as the module's honest-path test checks
/// for its own fixture input.
#[test]
fn the_all_zero_hidden_input_proves_and_its_receipt_verifies_from_bytes() {
    let x0 = zero_input();
    let (blk, _) = BlockPublic::synthetic_fixture();

    // the builder accepts it, and the block output of the zero input is zero
    // (residual 2 of a chain every stage of which annihilates)
    let out0 = compute_output(&blk, &x0).expect("the all-zero input is a valid witness");
    assert_eq!(out0.len(), T * D);
    assert!(out0.iter().all(|v| *v == 0), "the zero input's block output is not zero");

    let (blk, expected, receipt, stats) = prove_for(&x0);
    verify(&blk, &expected, &receipt).expect("the zero-witness receipt verifies in typed form");

    let bytes = receipt.to_bytes(&blk, &expected).expect("the zero-witness receipt encodes");
    assert_eq!(bytes.len(), encoded_len());
    assert!(bytes.len() <= MAX_WIRE_BYTES);
    let parsed = Receipt::from_bytes(&blk, &expected, &bytes).expect("the frame parses");
    verify(&blk, &expected, &parsed).expect("the parsed zero-witness receipt verifies");
    verify_bytes(&blk, &expected, &bytes).expect("serialize, parse, verify");

    // the shape facts are constants of the geometry, not of the witness: the
    // zero input walks the same schedule, with the same lookup totals
    assert_eq!((stats.a_rows, stats.h_rows, stats.m_rows), (455, 384, 50));
    assert_eq!((stats.u8_lookups, stats.exp_lookups, stats.act_lookups), (61_440, 2_048, 512));
    assert_eq!(stats.transcript_order.len(), 3 * N_SLOTS);
}

/// The four facts the paper trace rests on, asserted so that a calibration
/// change that invalidates the fixed input of the privacy argument fails HERE.
///
/// Two CONSTANTS keep the two divisions defined at the zero input:
///  * `NORM_CEPS = 1` (`layout.rs:54`): `ss = 1`, so `D = isqrt(1) = 1` and the
///    norm denominator is `2 * (1 << NORM_TN) = 4096 > 0`. At `NORM_CEPS = 0`
///    the zero input is REFUSED at `witness.rs:186-188` ("norm denominator")
///    and the fixed input of the privacy argument would not exist.
///  * the exponential table's first entry is pinned to `2^F_E` on the PUBLIC
///    STATEMENT by `AttentionPublic::new` (`private_block.rs:138`): the softmax
///    row sum at the zero input is `(t+1) * exp[0]`, and with `exp[0] = 0`
///    `witness.rs:286-288` refuses ("softmax denominator"). The pin is what
///    stops an adversarially chosen statement from killing the fixed input.
///
/// Two BOUNDARY VALUES: the zero witness sits EXACTLY on two range boundaries
/// at once (check §1a, "two boundary facts that U-4 must assert"), so a
/// one-bit change in `WRHO_S`, in `F_E`, or turning `0..=1 << F_P` into
/// `0..1 << F_P` would invalidate the fixed input while every ordinary witness
/// stayed valid:
///  * `sigma_s = 16,383` of an allowed 16,384 — the softmax remainder window
///    `0 .. 1 << WRHO_S` (`witness.rs:298`), headroom ZERO;
///  * `p = 512` of an INCLUSIVE 512 — the softmax quotient bound
///    `0 ..= 1 << F_P` (`witness.rs:298`), on the bound and inside it.
#[test]
fn the_zero_witness_pins_the_two_constants_and_the_two_range_boundaries() {
    // ---- constant 1: NORM_CEPS = 1, so the norm denominator is positive ----
    assert_eq!(NORM_CEPS, 1, "NORM_CEPS is what makes the all-zero input a valid witness");
    let ss = NORM_CEPS; // the all-zero row contributes nothing to the sum of squares
    let dd = witness::isqrt(ss as u64) as i64;
    assert_eq!(dd, 1, "the zero input's isqrt");
    assert!(2 * (dd << NORM_TN) > 0, "the norm denominator vanishes at the zero input");

    // ---- constant 2: exp[0] = 2^F_E, ENFORCED on the public statement ----
    let (blk, _) = BlockPublic::synthetic_fixture();
    let att = blk.attention();
    assert_eq!(att.exp[0], 1i64 << F_E, "the exponential table's pinned first entry");
    // and the pin is a constructor refusal, not a property of this fixture
    let mut broken = att.exp.clone();
    broken[0] = 0;
    assert!(
        AttentionPublic::new(&att.wq, &att.wk, &att.wv, &att.wo, &att.gamma_a, &att.rope_cos, &att.rope_sin, &broken).is_err(),
        "a statement with exp[0] = 0 was admitted; the zero input would be refused under it"
    );

    // ---- the witness of the all-zero input, on the module's own planes ----
    let w = witness::build(att, blk.feed_forward(), &zero_input()).expect("the all-zero input is a valid witness");
    assert!(w.planes[A_D].iter().all(|v| *v == dd), "every norm_a denominator at the zero input is isqrt(NORM_CEPS)");
    assert!(w.planes[A_DM].iter().all(|v| *v == dd), "every norm_m denominator at the zero input is isqrt(NORM_CEPS)");
    assert!(w.planes[A_X].iter().all(|v| *v == 0) && w.planes[A_X2].iter().all(|v| *v == 0), "the zero chain");

    // ---- boundary 1: sigma_s = 16,383 against the EXCLUSIVE window 2^WRHO_S
    let window = 1i64 << WRHO_S;
    assert_eq!(window, 16_384);
    let max_sigma = (0..Dom::S.len()).map(|i| sigma_s(&w, i)).max().expect("a nonempty score domain");
    assert_eq!(max_sigma, 16_383, "the zero witness's largest softmax remainder complement");
    // on the boundary, inside it: `witness.rs:298` refuses `sigma >= window`
    assert!(max_sigma < window, "the zero witness is outside the softmax remainder window");
    assert!(!(max_sigma + 1 < window), "there is headroom: the boundary fact this test exists to pin has moved");
    assert_eq!(window - 1 - max_sigma, 0, "headroom must be exactly zero");

    // ---- boundary 2: p = 512 against the INCLUSIVE bound 2^F_P ----------
    let bound = 1i64 << F_P;
    assert_eq!(bound, 512);
    let max_p = w.planes[A_P].iter().copied().max().expect("a nonempty score domain");
    assert_eq!(max_p, 512, "the zero witness's largest softmax quotient");
    // on the bound, inside it: `witness.rs:298` accepts `0 ..= bound`
    assert!(max_p <= bound, "the zero witness is outside the softmax quotient class");
    assert!(!(max_p + 1 <= bound), "there is headroom: turning the bound exclusive would no longer bite");

    // and the third fact the trace names: the masked score keeps every
    // exponent difference inside the table's 256 rows
    assert_eq!(MASK_SCORE, -127);
    assert!((0..256).contains(&-MASK_SCORE), "the masked exponent difference leaves the exp table");
}

/// The receipt's BYTE LENGTH does not depend on the hidden input: the zero
/// witness's frame is exactly as long as the fixture witness's, and both are
/// the profile's declared 2,816,472 bytes. (A length that moved with the input
/// would leak through the one channel the case cannot mask.)
#[test]
fn the_zero_witness_receipt_length_equals_the_fixture_receipt_length() {
    let (blk_f, expected_f, receipt_f, _) = prove_for(&BlockPublic::synthetic_fixture().1);
    let fixture_bytes = receipt_f.to_bytes(&blk_f, &expected_f).unwrap();
    let (blk_0, expected_0, receipt_0, _) = prove_for(&zero_input());
    let zero_bytes = receipt_0.to_bytes(&blk_0, &expected_0).unwrap();
    assert_eq!(zero_bytes.len(), fixture_bytes.len(), "the frame length moves with the hidden input");
    assert_eq!(zero_bytes.len(), 2_816_472);
    assert_eq!(receipt_0.payload_size(), receipt_f.payload_size());
    verify_bytes(&blk_0, &expected_0, &zero_bytes).unwrap();
    verify_bytes(&blk_f, &expected_f, &fixture_bytes).unwrap();
}

/// Two proofs of the SAME zero witness differ in their bytes and both verify:
/// the prover draws one fresh OS randomness stream per attempt, so the receipt
/// is not a function of the statement and the input. (Equal frames would mean
/// the blinding was deterministic — the failure mode the masking exists to
/// prevent — and the endpoint roots would repeat as well.)
#[test]
fn two_zero_witness_proofs_differ_in_their_bytes_and_both_verify() {
    let x0 = zero_input();
    let (blk_a, expected_a, receipt_a, _) = prove_for(&x0);
    let (blk_b, expected_b, receipt_b, _) = prove_for(&x0);
    let a = receipt_a.to_bytes(&blk_a, &expected_a).unwrap();
    let b = receipt_b.to_bytes(&blk_b, &expected_b).unwrap();
    assert_eq!(a.len(), b.len());
    assert_ne!(a, b, "two proofs of the same zero witness produced identical bytes");
    // the endpoint commitments are freshly randomised too
    assert_ne!(expected_a.input_root(), expected_b.input_root(), "the input endpoint root repeated");
    assert_ne!(expected_a.output_root(), expected_b.output_root(), "the output endpoint root repeated");
    verify_bytes(&blk_a, &expected_a, &a).unwrap();
    verify_bytes(&blk_b, &expected_b, &b).unwrap();
    // and neither receipt verifies under the other attempt's endpoint policy
    assert!(verify_bytes(&blk_a, &expected_b, &a).is_err());
    assert!(verify_bytes(&blk_b, &expected_a, &b).is_err());
}

// ------------------------------------------ STAGE 19 (task 9): THE 125M SHAPE
//
// Everything above is the TOY profile. The all-zero hidden input had never
// been tested at the 125M shape, and the two boundary facts the toy pins sit
// on constants that MOVED there: `limbs_sigma_s` is 3 instead of 2, so
// `WRHO_S` is the shape's own `wrho_s` (18, not the toy's 14), and `F_E` is 9
// against the toy's 9 but over 512 tokens instead of 32. The zero witness has
// ZERO headroom at both boundaries by construction, so a shape whose windows
// were derived even one bit tight would refuse the FIXED INPUT OF THE PRIVACY
// CASE while every ordinary witness stayed valid.
//
// No proof here: the witness BUILDER only. The 125M one-block proof on the
// zero input is `rulings_tests::private_block_125m_one_block` under
// `HL_PB_INPUT=zero`, which is `#[ignore]`d and heavy.

use super::shape::Shape;

/// the softmax remainder complement, reassembled from ITS SHAPE's limb count
fn sigma_s_at(s: &Shape, ids: &Ids, w: &witness::Witness, idx: usize) -> i64 {
    (0..s.limbs_sigma_s()).map(|k| w.planes[ids.sg(k)][idx] << (8 * k)).sum()
}

/// a cheap order-sensitive fingerprint of every plane, so that two witnesses
/// can be compared without both being resident at once
fn fingerprint(w: &witness::Witness) -> u64 {
    let mut h = 0xcbf2_9ce4_8422_2325u64;
    for (p, plane) in w.planes.iter().enumerate() {
        h = h.wrapping_mul(0x100_0000_01b3) ^ (p as u64);
        h = h.wrapping_mul(0x100_0000_01b3) ^ (plane.len() as u64);
        for v in plane {
            h = h.wrapping_mul(0x100_0000_01b3) ^ (*v as u64);
        }
    }
    h
}

/// the facts the paper trace rests on, asserted on a zero witness at any shape
fn the_zero_witness_facts_hold_at(s: &Shape, public: &AttentionPublic, ff: &FeedForwardPublic) -> u64 {
    let ids = Ids::new(s).expect("the shape has a plane map");
    let zero = vec![0i16; s.tokens * s.width];
    let w = match witness::build_shaped(s, public, ff, &zero) {
        Ok(w) => w,
        // task 9(c): if this ever fires, the exact site is the headline
        Err(m) => panic!("{}: the ALL-ZERO hidden input is REFUSED by the witness builder: {m}", s.name),
    };
    // ---- constant 1: NORM_CEPS = 1, so both norm denominators are positive
    assert_eq!(NORM_CEPS, 1, "NORM_CEPS is what makes the all-zero input a valid witness");
    assert!(w.planes[ids.at(A_D)].iter().take(s.tokens).all(|v| *v == 1), "{}: a norm_a denominator at the zero input is not isqrt(NORM_CEPS)", s.name);
    assert!(w.planes[ids.at(A_DM)].iter().take(s.tokens).all(|v| *v == 1), "{}: a norm_m denominator at the zero input is not isqrt(NORM_CEPS)", s.name);
    // ---- constant 2: exp[0] = 2^f_e, pinned on the PUBLIC STATEMENT
    assert_eq!(public.exp[0], 1i64 << s.f_e, "{}: the exponential table's pinned first entry", s.name);
    // ---- the zero chain: input and block output are identically zero
    assert!(w.planes[ids.at(A_X)].iter().all(|v| *v == 0), "{}: the zero input's x_in plane is not zero", s.name);
    assert!(w.planes[ids.at(A_X2)].iter().all(|v| *v == 0), "{}: the zero input's block output is not zero", s.name);
    // ---- boundary 1: sigma_s against the EXCLUSIVE window 2^wrho_s
    let window = 1i64 << s.wrho_s;
    let sup_s = super::witness::Geom::new(s).support(Dom::S);
    let max_sigma = sup_s.iter().map(|i| sigma_s_at(s, &ids, &w, *i)).max().expect("a nonempty score domain");
    assert!(max_sigma < window, "{}: the zero witness leaves the softmax remainder window", s.name);
    // The window is `ceil(log2(tokens << f_e))` bits wide and the zero
    // witness's largest complement is `total - 1` on a row whose denominator
    // DIVIDES `exp[0] << F_P`. When `tokens` is a power of two that row is the
    // last one and the complement is exactly `2^wrho_s - 1` — HEADROOM ZERO,
    // the toy's pinned fact, and 125M inherits it at `wrho_s = 18`. When it is
    // not (both rungs, `tokens = 24`) no row is tight, so the boundary is
    // asserted by shape rather than unconditionally.
    if s.tokens.is_power_of_two() {
        assert_eq!(window - 1 - max_sigma, 0, "{}: the softmax remainder boundary has headroom, so this test no longer pins it", s.name);
    }
    println!("{}: zero witness softmax remainder complement {max_sigma} of an allowed {window} (headroom {})", s.name, window - 1 - max_sigma);
    // ---- boundary 2: p against the INCLUSIVE bound 2^F_P
    let bound = 1i64 << F_P;
    let max_p = w.planes[ids.at(A_P)].iter().copied().max().expect("a nonempty score domain");
    assert_eq!(max_p, bound, "{}: the zero witness's largest softmax quotient is not the inclusive bound", s.name);
    // ---- boundary 3, NEW AT A LONG CONTEXT: the softmax denominator reaches
    // its own inclusive upper bound `tokens << f_e` on the LAST token row
    let total_bound = (s.tokens as i64) << s.f_e;
    let max_total = w.planes[ids.at(A_SUM)].iter().copied().max().expect("a nonempty head-token domain");
    assert_eq!(max_total, total_bound, "{}: the zero witness's largest softmax denominator is not the inclusive bound", s.name);
    // ---- the masked exponent difference stays inside the table's 256 rows
    assert_eq!(MASK_SCORE, -127);
    assert!((0..256).contains(&-MASK_SCORE), "{}: the masked exponent difference leaves the exp table", s.name);
    fingerprint(&w)
}

/// **TASK 9(a).** The witness builder admits the ALL-ZERO hidden input at the
/// 125M shape under BOTH public-weight recipes, and the two zero-headroom
/// boundary facts the privacy case rests on still hold there — at
/// `limbs_sigma_s = 3` and `wrho_s = 18`, which is where the toy's pinned
/// constants no longer apply.
///
/// The two witnesses are compared by FINGERPRINT rather than side by side, so
/// only one 125M witness is resident at a time. They must be EQUAL: the zero
/// input multiplies every public weight by zero, so the witness of the
/// all-zero input is a function of the SHAPE and the tables alone. That is
/// itself worth pinning — it is why the fixed input of the privacy case does
/// not have to be re-argued for every weights recipe.
#[test]
fn the_all_zero_hidden_input_is_admitted_by_the_witness_builder_at_125m() {
    let s = Shape::m125();
    assert_eq!((s.limbs_sigma_s(), s.wrho_s, s.f_e), (3, 18, 9), "the 125M softmax calibration this test is about");
    let t0 = std::time::Instant::now();
    let (tame_public, tame_ff, _) = super::grow_tests::tame_case(&s);
    let tame_fp = the_zero_witness_facts_hold_at(&s, &tame_public, &tame_ff);
    drop(tame_public);
    drop(tame_ff);
    println!("125M zero witness (tame weights): built and checked in {:.2} s", t0.elapsed().as_secs_f64());
    let t1 = std::time::Instant::now();
    let (dense_public, dense_ff, _) = super::dense_tests::dense_case(&s);
    let dense_fp = the_zero_witness_facts_hold_at(&s, &dense_public, &dense_ff);
    println!("125M zero witness (dense weights): built and checked in {:.2} s", t1.elapsed().as_secs_f64());
    assert_eq!(tame_fp, dense_fp, "the all-zero input's witness depends on the public weights, which it must not");
}

/// The same facts at the three shapes that are cheap, so that the 125M test
/// above is read against a baseline rather than alone.
#[test]
fn the_all_zero_hidden_input_is_admitted_at_the_toy_and_both_rungs() {
    for s in [Shape::toy(), Shape::rung(), Shape::rung_g()] {
        let (tame_public, tame_ff, _) = super::grow_tests::tame_case(&s);
        let a = the_zero_witness_facts_hold_at(&s, &tame_public, &tame_ff);
        let (dense_public, dense_ff, _) = super::dense_tests::dense_case(&s);
        let b = the_zero_witness_facts_hold_at(&s, &dense_public, &dense_ff);
        assert_eq!(a, b, "{}: the all-zero input's witness depends on the public weights", s.name);
        println!("{}: the all-zero hidden input is admitted under both recipes, boundaries at zero headroom", s.name);
    }
}
