//! Public-API tests of the EXPERIMENTAL private attention profile
//! (`hashline::private_attention`). PUBLIC SYNTHETIC fixture only: no real
//! input, model or secret; nothing is written to disk. Each leg is a real
//! proof and a real verification, so run in release:
//!
//!   cargo test --release --offline --manifest-path hashline/Cargo.toml --test zk60_private_attention
//!
//! These tests establish engineering behaviour (acceptance of the honest
//! receipt, refusal of malformed / inconsistent ones). They are NOT a
//! whole-proof privacy acceptance; D8 / D11 stay open.

use hashline::private_attention::{
    compute_output, encoded_len, prepare_endpoints, prove, schedule, verify, verify_bytes, AttentionPublic, ExpectedIo, IoSpec, Receipt, EXPECTED_BYTES, MAX_WIRE_BYTES,
};

fn spec() -> IoSpec {
    IoSpec::new(*blake3::hash(b"zk60 private attention: public synthetic integration context").as_bytes(), 0, 0).unwrap()
}

/// (frame, expected-policy bytes) of one honest proving attempt
fn honest_frame() -> (Vec<u8>, Vec<u8>) {
    let (public, input) = AttentionPublic::synthetic_fixture();
    let output = compute_output(&public, &input).unwrap();
    let (expected, owners) = prepare_endpoints(spec(), &input, &output).unwrap();
    let receipt = prove(&public, &input, &expected, owners).unwrap();
    (receipt.to_bytes(&public, &expected).unwrap(), expected.to_bytes())
}

#[test]
fn honest_frame_verifies_against_independently_rebuilt_expected_state() {
    let (frame, policy) = honest_frame();
    assert_eq!(frame.len(), encoded_len());
    assert!(frame.len() <= MAX_WIRE_BYTES);
    assert_eq!(policy.len(), EXPECTED_BYTES);
    // the verifier's statement is rebuilt from scratch: nothing is shared with the prover but bytes
    let (public, _) = AttentionPublic::synthetic_fixture();
    let expected = ExpectedIo::from_bytes(&policy).unwrap();
    verify_bytes(&public, &expected, &frame).unwrap();
    let typed = Receipt::from_bytes(&public, &expected, &frame).unwrap();
    verify(&public, &expected, &typed).unwrap();
    assert_eq!(typed.to_bytes(&public, &expected).unwrap(), frame, "the frame is canonical");
    assert_eq!(typed.payload_size() + 40, frame.len());
}

#[test]
fn every_region_of_the_frame_is_load_bearing() {
    let (frame, policy) = honest_frame();
    let (public, _) = AttentionPublic::synthetic_fixture();
    let expected = ExpectedIo::from_bytes(&policy).unwrap();
    // 61 positions spread over the envelope, roots, arguments, M, A, H and endpoint openings
    let step = frame.len() / 61;
    for k in 0..61 {
        let at = k * step + (k % 7);
        let mut bad = frame.clone();
        bad[at] ^= 0x04;
        assert!(verify_bytes(&public, &expected, &bad).is_err(), "byte {at} of {} is not checked", frame.len());
    }
    let mut last = frame.clone();
    let end = last.len() - 1;
    last[end] ^= 1;
    assert!(verify_bytes(&public, &expected, &last).is_err(), "last path byte");
    assert!(verify_bytes(&public, &expected, &frame[..frame.len() - 8]).is_err());
    verify_bytes(&public, &expected, &frame).unwrap();
}

#[test]
fn endpoints_fixed_to_other_values_or_other_policies_are_refused() {
    let (public, input) = AttentionPublic::synthetic_fixture();
    let output = compute_output(&public, &input).unwrap();
    // the endpoint owner fixed an output that is not the attention output
    let mut wrong = output.clone();
    wrong[100] -= 1;
    let (expected, owners) = prepare_endpoints(spec(), &input, &wrong).unwrap();
    let receipt = prove(&public, &input, &expected, owners).unwrap();
    assert!(verify(&public, &expected, &receipt).is_err());
    // an honest receipt does not verify under another caller's endpoint policy
    let (e1, o1) = prepare_endpoints(spec(), &input, &output).unwrap();
    let (e2, o2) = prepare_endpoints(spec(), &input, &output).unwrap();
    assert_ne!(e1.input_root(), e2.input_root(), "endpoint commitments are freshly randomized");
    let r1 = prove(&public, &input, &e1, o1).unwrap();
    verify(&public, &e1, &r1).unwrap();
    assert!(verify(&public, &e2, &r1).is_err());
    assert!(prepare_endpoints(spec(), &input[1..], &output).is_err());
    assert!(prove(&public, &input[1..], &e2, o2).is_err(), "input shape");
}

#[test]
fn two_honest_receipts_share_no_root_and_the_schedule_is_declared() {
    let (a, _) = honest_frame();
    let (b, _) = honest_frame();
    // envelope (8 + 32) then the A, H and M roots
    for k in 0..3 {
        assert_ne!(a[40 + 32 * k..72 + 32 * k], b[40 + 32 * k..72 + 32 * k], "root {k} repeats across attempts");
    }
    let lines = schedule();
    assert!(lines.iter().any(|l| l.contains("M rows=40 functionals=28")));
    assert_eq!(lines.iter().filter(|l| l.starts_with("slot ")).count(), 18);
    assert_eq!(lines.iter().filter(|l| l.starts_with("host ")).count(), 5);
}
