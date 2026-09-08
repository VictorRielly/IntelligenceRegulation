//! CL20 round 12 (Fable): the maintained core's typed v3 pieces against a
//! REAL tiny proof produced by hashline's legacy prover. Explicit seeds are
//! PUBLIC test fixtures; T=2, d=f=16, deliberately tiny parameters, no
//! security claim. This is D2/D4/D5 of zkp-core/DESIGN.md section 5.1 and
//! the tamper legs of D3 as far as the moved pieces allow: the prover and
//! verifier still live in hashline, so old/new PROVER parity (D1) is not
//! tested here; what is tested is that the legacy proof bytes are exactly
//! the core's frozen encoding, that the core's bounded decoder reproduces
//! them and the legacy verifier accepts the decoded object, and that
//! malformed bytes and tampered witnesses are refused without a panic.
use hashline::export_v3::{derive_v3, V3Dims, V3Exps, V3LayerExport, V3Witness};
use hashline::layer::{apply_tamper_v3, prove_layer_v3, verify_layer_v3, LayerParams, LayerProofV3, StatementV3, TamperV3};
use hashline::ntt::NttTables;
use hashline::tables_v3::{int16out_member, Act16Fn};
use hashline::transcript::Transcript;
use zkp_core::ffn_v3::{DecodeError, Proof, Shape, DOMAIN_LAYER};

fn params() -> LayerParams {
    LayerParams { log_cols: 5, inv_rate: 4, num_col_checks: 12 }
}

fn ntt(p: &LayerParams) -> NttTables {
    NttTables::new(p.log_cols + p.inv_rate.trailing_zeros())
}

/// The T2/d16/f16 synthetic witness of the identity-gap and mask
/// diagnostics (seed 1; the same generator), derived through the exact
/// chain; `changed_weights` is that test's one-entry weight change.
fn synth(changed_weights: bool) -> V3Witness {
    let (t, d, f) = (2usize, 16usize, 16usize);
    let mut seed = 1u64;
    let mut next = |m: i64| -> i8 {
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (((seed >> 33) as i64) % (2 * m + 1) - m) as i8
    };
    let x = (0..t * d).map(|_| next(127)).collect();
    let mut wg_t: Vec<i8> = (0..d * f).map(|_| next(4)).collect();
    let wu_t = (0..d * f).map(|_| next(4)).collect();
    let wd_t = (0..f * d).map(|_| next(4)).collect();
    if changed_weights {
        wg_t[0] += 1;
    }
    let (table, table_digest) = int16out_member(Act16Fn::Silu, -3, -11).unwrap();
    let export = V3LayerExport {
        l: 0,
        dims: V3Dims { t, d, f, layers: 1 },
        x,
        wg_t,
        wu_t,
        wd_t,
        a16: vec![],
        u16: vec![],
        h16: vec![],
        z16: vec![],
        exps: V3Exps { e_x: 0, e_g: -3, e_a16: -11, e_u16: 0, e_h16: 3, e_z16: 0, e_wg: -10, e_wu: 0, e_wd: -9 },
        shifts: (7, 0, 14, 6),
        act: Act16Fn::Silu,
        table,
        table_digest,
        digest_checks: vec![],
    };
    let w = derive_v3(&export, t);
    assert!(w.range_ok);
    w
}

fn statement(w: &V3Witness) -> StatementV3 {
    StatementV3 { l: w.l, t_rows: w.t_rows, d: w.dims.d, f: w.dims.f, shifts: w.shifts, act: w.act, table: w.table, table_digest: w.table_digest.clone() }
}

fn prove(w: &V3Witness, p: &LayerParams, ntt: &NttTables) -> LayerProofV3 {
    prove_layer_v3(w, w.t_rows, p, ntt, &mut Transcript::new(DOMAIN_LAYER)).proof
}

fn verify(st: &StatementV3, proof: &LayerProofV3, p: &LayerParams, ntt: &NttTables) -> Result<(), String> {
    verify_layer_v3(st, proof, p, ntt, &mut Transcript::new(DOMAIN_LAYER))
}

#[test]
fn legacy_tiny_proof_is_the_core_encoding_and_round_trips_through_the_bounded_decoder() {
    let p = params();
    let ntt = ntt(&p);
    let w = synth(false);
    let st = statement(&w);
    let proof = prove(&w, &p, &ntt);
    verify(&st, &proof, &p, &ntt).unwrap();
    let bytes = proof.to_bytes();
    // the shape the core derives from (statement, params) is exactly the legacy size
    let shape = Shape::of(&st, &p).unwrap();
    assert_eq!(bytes.len(), shape.total_bytes());
    assert_eq!(bytes.len(), proof.size_bytes());
    // decode -> re-encode is the identity, and the decoded object verifies
    let back = LayerProofV3::from_bytes(&bytes, &st, &p).unwrap();
    assert_eq!(back.to_bytes(), bytes);
    assert!(back.cpcs_open.is_none());
    verify(&st, &back, &p, &ntt).unwrap();
    // determinism: the same witness proves to the same bytes (no randomness in this profile)
    assert_eq!(prove(&w, &p, &ntt).to_bytes(), bytes);
    // a witness with one changed weight has the same shape and different bytes
    let w2 = synth(true);
    let bytes2 = prove(&w2, &p, &ntt).to_bytes();
    assert_eq!(bytes2.len(), bytes.len());
    assert_ne!(bytes2, bytes);
    // a statement with permuted shifts has the same shape (same distinct-shift set), so the
    // decoder accepts the bytes and only the verifier refuses them
    let other = StatementV3 { shifts: (6, 0, 14, 7), ..st.clone() };
    let as_other = LayerProofV3::from_bytes(&bytes, &other, &p).unwrap();
    assert!(verify(&other, &as_other, &p, &ntt).is_err());
    // a statement with another distinct-shift set changes the shape: the decoder refuses
    let other2 = StatementV3 { shifts: (7, 0, 14, 5), ..st.clone() };
    assert!(LayerProofV3::from_bytes(&bytes, &other2, &p).is_err());
}

#[test]
fn malformed_tiny_proof_bytes_are_refused_by_the_decoder_or_the_verifier_never_panic() {
    let p = params();
    let ntt = ntt(&p);
    let w = synth(false);
    let st = statement(&w);
    let bytes = prove(&w, &p, &ntt).to_bytes();
    let shape = Shape::of(&st, &p).unwrap();
    let dec = |b: &[u8]| Proof::<zkp_core::ffn_v3::NoExtra>::from_bytes(b, &st, &p);
    // truncation at every field boundary
    for (name, at) in shape.field_offsets() {
        if at == bytes.len() { continue; }
        assert!(matches!(dec(&bytes[..at]), Err(DecodeError::Truncated { .. })), "{name}");
    }
    assert!(matches!(dec(&bytes[..bytes.len() - 1]), Err(DecodeError::Truncated { .. })));
    // one trailing byte
    let mut t = bytes.clone();
    t.push(0);
    assert!(matches!(dec(&t), Err(DecodeError::Trailing { .. })));
    // a non-canonical field element in the first claim
    let gu: usize = shape.field_offsets().into_iter().find(|(n, _)| n == "gu_claims").unwrap().1;
    let mut nc = bytes.clone();
    nc[gu..gu + 8].copy_from_slice(&u64::MAX.to_le_bytes());
    assert!(matches!(dec(&nc), Err(DecodeError::NonCanonical { .. })));
    // single-bit flips at sampled offsets: the decoder refuses, or the decoded object fails to verify
    let mut refused_by_decoder = 0usize;
    let mut refused_by_verifier = 0usize;
    for k in (0..bytes.len()).step_by(4099) {
        let mut fl = bytes.clone();
        fl[k] ^= 0x01;
        match LayerProofV3::from_bytes(&fl, &st, &p) {
            Err(_) => refused_by_decoder += 1,
            Ok(pr) => {
                assert!(verify(&st, &pr, &p, &ntt).is_err(), "flipped byte {k} verified");
                refused_by_verifier += 1;
            }
        }
    }
    assert!(refused_by_decoder + refused_by_verifier > 0);
    assert!(refused_by_verifier > 0, "every flip landed in a decoder-checked field");
}

#[test]
fn the_eight_tamper_legs_are_refused_by_the_verifier_after_decoding() {
    let p = params();
    let ntt = ntt(&p);
    let legs = [
        TamperV3::FlipX(7),
        TamperV3::FlipW(42),
        TamperV3::RemainderOutOfRange(9),
        TamperV3::WrongTableEntry(10),
        TamperV3::WrongRequant(5),
        TamperV3::WrongZ(3),
        TamperV3::WrongRounding(20),
        TamperV3::OutOfRangeInt16(12),
    ];
    for (i, leg) in legs.into_iter().enumerate() {
        let mut w = synth(false);
        let st = statement(&w);
        let name = format!("tamper leg {i}");
        apply_tamper_v3(&mut w, leg);
        let proof = prove(&w, &p, &ntt);
        let bytes = proof.to_bytes();
        // the tampered proof still has the shape (the decoder is not a verifier) ...
        let back = LayerProofV3::from_bytes(&bytes, &st, &p).unwrap_or_else(|e| panic!("{name}: {e}"));
        assert_eq!(back.to_bytes(), bytes);
        // ... and both the legacy object and the decoded object are refused with the same message
        let e1 = verify(&st, &proof, &p, &ntt).expect_err(&name);
        let e2 = verify(&st, &back, &p, &ntt).expect_err(&name);
        assert_eq!(e1, e2, "{name}");
    }
}
