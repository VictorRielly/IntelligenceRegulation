use super::*;

fn fixture() -> (V3Witness, WeightStatement) {
    use crate::causal_oracle::{public_synthetic_fixture, FixedCausalOracle};
    let (approved, weights, input) = public_synthetic_fixture();
    // This policy comes from the approved fixture, before any FFN proof.
    let policy = WeightStatement::Public(approved.registration().ffn_weights.root);
    let w = FixedCausalOracle::new(&approved, weights)
        .unwrap()
        .build(&input)
        .unwrap()
        .ffn;
    (w, policy)
}
fn spec() -> IoSpec {
    IoSpec::new([7; 32], -3, 0).unwrap()
}
fn planes(w: &V3Witness) -> (Vec<Fp>, Vec<Fp>) {
    (
        w.x.iter().map(|&x| Fp::from_i64(x as i64)).collect(),
        w.z16.iter().map(|&x| Fp::from_i64(x as i64)).collect(),
    )
}

#[test]
fn bound_ffn_honest_p1_p3_and_fresh_owners() {
    let (w, public) = fixture();
    let st = statement(&w);
    let (x, z) = planes(&w);
    for (privacy, weights) in [
        (ZkPrivacy::P1, public),
        (ZkPrivacy::P3, WeightStatement::FreshPrivate),
    ] {
        let mut previous = None;
        let mut previous_masks: Option<Vec<Vec<Fp>>> = None;
        for attempt in 0..2 {
            let (expected, endpoints) = prepare_endpoints(spec(), &x, &z).unwrap();
            let policy_bytes = expected.to_bytes();
            let pending = prepare(&w, privacy, &expected).unwrap();
            let rows = pending.pending.zl.a_io.unwrap();
            assert_eq!(rows, [698, 700]);
            assert!(rows.into_iter().flat_map(|r| r..r + 2).all(|r| pending
                .pending
                .zl
                .a_mask_rows()
                .contains(&r)));
            assert_eq!(pending.pending.ac.len(), 18);
            // Reservation precedes all openings: exactly one M holds all eight slots.
            let held = &pending.pending;
            assert_eq!(held.mc.specs.len(), 8);
            assert_eq!(&held.mc.specs[6..], &[(10, 2); 2]);
            assert_eq!(held.mc.encoded.len(), 20 * 4096);
            assert_eq!(held.mc.tree.root(), held.proof.mask_root);
            assert!(held.proof.mask_open.q.is_empty());
            assert!(held.proof.w_open.columns.is_empty());
            assert!(held.proof.w_open_zk.columns.is_empty());
            assert!(held.proof.a_open.columns.is_empty());
            assert!(held.proof.h_open.columns.is_empty());
            // O6: compare actual reserved row values across attempts, not just roots.
            let masks: Vec<Vec<Fp>> = (698..702)
                .map(|row| held.a.data[row * 256..(row + 1) * 256].to_vec())
                .chain(held.mc.a_coefs[12..16].iter().cloned())
                .collect();
            if let Some(prior) = previous_masks {
                for (old, new) in prior.iter().zip(&masks) {
                    assert_ne!(old, new);
                }
            }
            previous_masks = Some(masks);
            let receipt = pending.finish(endpoints).unwrap();
            assert!(receipt
                .ffn
                .mask_open
                .columns
                .iter()
                .all(|(_, c, _, _)| c.len() == 20));
            assert_eq!(receipt.ffn.a_com.as_ref().unwrap().rows, 702);
            assert_eq!(receipt.ffn.h_com.as_ref().unwrap().rows, 1326);
            assert_eq!(
                receipt.ffn.w_com.as_ref().unwrap().rows,
                if privacy == ZkPrivacy::P1 { 3 } else { 11 }
            );
            assert_eq!(receipt.ffn.a_open.group_vecs.len(), 7);
            let bytes = receipt.to_bytes(&st, weights, &expected).unwrap();
            assert_eq!(bytes.len(), encoded_len(&st, weights).unwrap());
            let restored = ExpectedIo::from_bytes(&policy_bytes).unwrap();
            let capture = mask_diagnostic::io::CaptureGuard::new();
            verify_bytes(&st, weights, &restored, &bytes).unwrap();
            assert!(capture.is_published());
            if attempt == 0 { capture.check_tamper_controls(); }
            capture.check_and_export();
            let decoded = Receipt::from_bytes(&st, weights, &restored, &bytes).unwrap();
            assert_eq!(decoded.to_bytes(&st, weights, &restored).unwrap(), bytes);
            let roots = (
                expected.input_root(),
                expected.output_root(),
                receipt.ffn.a_com.as_ref().unwrap().root,
            );
            if let Some(prev) = previous {
                assert_ne!(roots, prev);
            }
            previous = Some(roots);
            eprintln!("BOUND_FFN privacy={privacy:?} attempt={attempt} bytes={} A_rows=702 A_groups=7 M_rows=20 independently_expected_endpoints=true", bytes.len());
        }
    }
}

fn wrong_plane(side: usize) {
    let (w, weights) = fixture();
    let (mut x, mut z) = planes(&w);
    if side == 0 {
        x[271] = x[271].add(Fp::ONE);
    } else {
        z[271] = z[271].add(Fp::ONE);
    }
    // Fully recommit the wrong plane and use its REAL root as expected policy.
    // No stale hash, wrong header or malformed opening explains the refusal.
    let (expected, endpoints) = prepare_endpoints(spec(), &x, &z).unwrap();
    let receipt = prepare(&w, ZkPrivacy::P1, &expected)
        .unwrap()
        .finish(endpoints)
        .unwrap();
    let st = statement(&w);
    let bytes = receipt.to_bytes(&st, weights, &expected).unwrap();
    Receipt::from_bytes(&st, weights, &expected, &bytes).unwrap();
    let capture = mask_diagnostic::io::CaptureGuard::new();
    let err = verify_bytes(&st, weights, &expected, &bytes).unwrap_err();
    assert!(err.starts_with(&format!("IO {side} sumcheck:")), "{err}");
    assert!(!capture.is_published());
}
#[test]
fn bound_ffn_refuses_recommitted_wrong_input() {
    wrong_plane(0);
}
#[test]
fn bound_ffn_refuses_recommitted_wrong_output() {
    wrong_plane(1);
}

#[test]
fn bound_ffn_policy_and_endpoint_preflight() {
    assert!(IoSpec::new([0; 32], -3, 0).is_err());
    assert!(IoSpec::new([1; 32], -32, 0).is_err());
    assert!(IoSpec::new([1; 32], 0, 32).is_err());
    let expected = ExpectedIo::from_roots(spec(), [2; 32], [3; 32]);
    let bytes = expected.to_bytes();
    assert_eq!(bytes.len(), EXPECTED_BYTES);
    for end in [0, 8, 39, 40, 47, EXPECTED_BYTES - 1] {
        assert!(ExpectedIo::from_bytes(&bytes[..end]).is_err());
    }
    let mut b = bytes.clone();
    b.push(0);
    assert!(ExpectedIo::from_bytes(&b).is_err());
    let mut b = bytes.clone();
    b[0] ^= 1;
    assert!(ExpectedIo::from_bytes(&b).is_err());
    let mut b = bytes;
    b[40..44].copy_from_slice(&i32::MAX.to_le_bytes());
    assert!(ExpectedIo::from_bytes(&b).is_err());
    assert!(prepare_endpoints(spec(), &[Fp::ZERO; 511], &[Fp::ZERO; 512]).is_err());
    assert!(prepare_endpoints(spec(), &[Fp(crate::field::P); 512], &[Fp::ZERO; 512]).is_err());
    let (w, _) = fixture();
    let mut st = statement(&w);
    st.shifts = (16, 16, 16, 16);
    assert!(encoded_len(&st, WeightStatement::FreshPrivate).unwrap() < MAX_WIRE_BYTES);
    st.shifts.0 = 17;
    assert!(encoded_len(&st, WeightStatement::FreshPrivate).is_err());
}

#[test]
fn bound_ffn_consumes_mismatched_owner_and_checks_slot() {
    let (w, _) = fixture();
    let (x, z) = planes(&w);
    let (expected, _) = prepare_endpoints(spec(), &x, &z).unwrap();
    let (_, different) = prepare_endpoints(spec(), &x, &z).unwrap();
    assert!(prepare(&w, ZkPrivacy::P1, &expected)
        .unwrap()
        .finish(different)
        .unwrap_err()
        .contains("root mismatch"));
    let (expected, mut swapped) = prepare_endpoints(spec(), &x, &z).unwrap();
    std::mem::swap(&mut swapped.input, &mut swapped.output);
    assert!(check_endpoints(&expected, swapped).is_err());
}

#[test]
fn bound_ffn_adversarial_receipt_and_relabelled_policy() {
    let (w, _) = fixture();
    let st = statement(&w);
    let (x, z) = planes(&w);
    let (expected, endpoints) = prepare_endpoints(spec(), &x, &z).unwrap();
    let receipt = prepare(&w, ZkPrivacy::P3, &expected)
        .unwrap()
        .finish(endpoints)
        .unwrap();
    let weights = WeightStatement::FreshPrivate;
    let bytes = receipt.to_bytes(&st, weights, &expected).unwrap();
    let capture = mask_diagnostic::io::CaptureGuard::new();
    let decode = |b: &[u8]| Receipt::from_bytes(&st, weights, &expected, b);
    let reject = |b: &[u8]| {
        assert!(verify_bytes(&st, weights, &expected, b).is_err());
        assert!(!capture.is_published(), "failed receipt published IO observations");
    };
    // Successful publication must be cleared even when the next attempt fails
    // before typed verification, or only at the last endpoint's Merkle path.
    verify_bytes(&st, weights, &expected, &bytes).unwrap();
    assert!(capture.is_published());
    reject(&bytes[..7]);
    verify_bytes(&st, weights, &expected, &bytes).unwrap();
    let mut late = bytes.clone();
    *late.last_mut().unwrap() ^= 1;
    let err = verify_bytes(&st, weights, &expected, &late).unwrap_err();
    assert!(err.starts_with("IO endpoint 1:"), "{err}");
    assert!(!capture.is_published());
    // O7 P3: role-swapped and duplicated real endpoint openings parse but fail.
    for duplicate in [false, true] {
        let mut typed = decode(&bytes).unwrap();
        if duplicate {
            typed.endpoint_open[1] = typed.endpoint_open[0].clone();
        } else {
            typed.endpoint_open.swap(0, 1);
        }
        let b = typed.to_bytes(&st, weights, &expected).unwrap();
        Receipt::from_bytes(&st, weights, &expected, &b).unwrap();
        let err = verify_bytes(&st, weights, &expected, &b).unwrap_err();
        assert!(err.starts_with("IO endpoint "), "{err}");
        assert!(!capture.is_published());
    }
    for end in [0, 8, 39, 40, bytes.len() / 2, bytes.len() - 1] {
        assert!(decode(&bytes[..end]).is_err());
    }
    let mut b = bytes.clone();
    b.push(0);
    assert!(decode(&b).is_err());
    for off in [0, 7, 8, 39] {
        let mut b = bytes.clone();
        b[off] ^= 1;
        assert!(decode(&b).is_err());
    }
    for off in [40 + 32, 40 + 44 + 32, 40 + 120 + 32] {
        let mut b = bytes.clone();
        b[off..off + 8].fill(255);
        assert!(decode(&b).unwrap_err().contains("shape"));
    }
    let args_at = 40 + wire::io_payload_len(&st, weights).unwrap();
    for off in [40 + 164, args_at, args_at + 8] {
        let mut b = bytes.clone();
        b[off..off + 8].copy_from_slice(&crate::field::P.to_le_bytes());
        assert!(decode(&b).unwrap_err().contains("noncanonical"));
    }
    let ffn = &receipt.ffn;
    let mask_at = 40 + ffn.size_bytes()
        - ffn.mask_open.size_bytes()
        - ffn.w_open.size_bytes()
        - ffn.w_open_zk.size_bytes()
        - ffn.a_open.size_bytes()
        - ffn.h_open.size_bytes();
    let endpoint_at = args_at + 2 * ARGUMENT_BYTES;
    for (off, bound) in [(mask_at + 32768, 4096u64), (endpoint_at + 16384, 2048)] {
        let mut b = bytes.clone();
        b[off..off + 8].copy_from_slice(&bound.to_le_bytes());
        assert!(decode(&b).unwrap_err().contains("index"));
    }
    for off in [
        40,
        84,
        160,
        args_at - 1,
        args_at,
        args_at + 16,
        args_at + 496,
        args_at + 528,
        args_at + ARGUMENT_BYTES,
        mask_at,
        mask_at + 32768 + 8,
        endpoint_at,
        endpoint_at + 16384 + 8,
        bytes.len() - 1,
    ] {
        let mut b = bytes.clone();
        b[off] ^= 1;
        reject(&b);
    }
    // Recompute the envelope binding: a digest is framing, not authorization.
    let mut policies = vec![expected.clone(); 5];
    policies[0].input.root[0] ^= 1;
    policies[1].output.root[0] ^= 1;
    policies[2].spec.context[0] ^= 1;
    policies[3].spec.output_scale += 1;
    policies[4].spec.input_scale += 1;
    policies.push(ExpectedIo::from_roots(
        expected.spec.clone(),
        expected.output.root,
        expected.input.root,
    ));
    for policy in policies {
        assert!(Receipt::from_bytes(&st, weights, &policy, &bytes).is_err());
        let b = receipt.to_bytes(&st, weights, &policy).unwrap();
        assert!(verify_bytes(&st, weights, &policy, &b).is_err());
    }
    assert!(super::super::Proof::from_bytes(&st, weights, &bytes, b"io").is_err());
    let old = super::super::prove(&w, ZkPrivacy::P3, b"io").unwrap();
    assert!(decode(&old.to_bytes(&st, weights, b"io").unwrap()).is_err());
    let mut typed = decode(&bytes).unwrap();
    let v = typed.ffn.a_open.group_vecs[0].pop().unwrap();
    typed.ffn.a_open.group_vecs[1].push(v);
    assert!(typed.to_bytes(&st, weights, &expected).is_err());
    let mut typed = decode(&bytes).unwrap();
    typed.arguments[0].terminals[0].c1 = Fp(crate::field::P);
    assert!(typed
        .to_bytes(&st, weights, &expected)
        .unwrap_err()
        .contains("noncanonical"));
}
