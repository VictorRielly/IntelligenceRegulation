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
