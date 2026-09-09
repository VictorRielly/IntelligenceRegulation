use super::*;
use crate::zk::fresh_poc::{self, WeightStatement};

fn weight_statement(privacy: ZkPrivacy, root: Digest) -> WeightStatement {
    match privacy {
        ZkPrivacy::P1 => WeightStatement::Public(root),
        ZkPrivacy::P3 => WeightStatement::FreshPrivate,
    }
}

#[test]
fn repaired_wire_roundtrip_and_adversarial_frames() {
    let w = fixture(32, 29);
    let st = statement(&w);
    for privacy in [ZkPrivacy::P1, ZkPrivacy::P3] {
        let mut proof = fresh_poc::prove(&w, privacy, b"wire-request").unwrap();
        let weights = weight_statement(privacy, proof.weight_root());
        let bytes = proof.to_bytes(&st, weights, b"wire-request").unwrap();
        assert_eq!(bytes.len(), proof.payload_size() + 41);
        assert_eq!(bytes.len(), fresh_poc::encoded_len(&st, weights).unwrap());
        let decoded = fresh_poc::Proof::from_bytes(&st, weights, &bytes, b"wire-request").unwrap();
        assert_eq!(decoded.inner.to_bytes(), proof.inner.to_bytes());
        assert_eq!(
            decoded.to_bytes(&st, weights, b"wire-request").unwrap(),
            bytes
        );
        fresh_poc::verify_bytes(&st, weights, &bytes, b"wire-request").unwrap();

        let decode = |b: &[u8]| fresh_poc::Proof::from_bytes(&st, weights, b, b"wire-request");
        let reject =
            |b: &[u8]| assert!(fresh_poc::verify_bytes(&st, weights, b, b"wire-request").is_err());
        // Fixed frame lengths reject incomplete, extended and legacy payloads.
        for end in [0, 1, 8, 9, 40, 41, 205, bytes.len() / 2, bytes.len() - 1] {
            assert!(decode(&bytes[..end]).is_err());
        }
        let mut bad = bytes.clone();
        bad.push(0);
        assert!(decode(&bad).is_err());
        assert!(decode(&proof.inner.to_bytes()).is_err());
        for offset in [0, 7, 8, 9, 40] {
            let mut bad = bytes.clone();
            bad[offset] ^= 1;
            assert!(decode(&bad).is_err());
        }
        // Hostile commitment counts never become allocation sizes.
        for offset in [41 + 32, 41 + 44 + 32, 41 + 120 + 32] {
            let mut bad = bytes.clone();
            bad[offset..offset + 8].fill(255);
            assert!(decode(&bad).unwrap_err().contains("shape"));
        }
        // Both limbs are canonical; reducing modulo p would admit aliases.
        for offset in [41 + 164, 41 + 164 + 8] {
            let mut bad = bytes.clone();
            bad[offset..offset + 8].copy_from_slice(&crate::field::P.to_le_bytes());
            assert!(decode(&bad).unwrap_err().contains("noncanonical"));
        }
        let mask_at = bytes.len()
            - proof.inner.mask_open.size_bytes()
            - proof.inner.w_open.size_bytes()
            - proof.inner.w_open_zk.size_bytes()
            - proof.inner.a_open.size_bytes()
            - proof.inner.h_open.size_bytes();
        let mask_col = mask_at + 2 * 1024 * 16;
        let mut bad = bytes.clone();
        bad[mask_col..mask_col + 8].copy_from_slice(&4096u64.to_le_bytes());
        assert!(decode(&bad).unwrap_err().contains("index"));
        let mut bad = bytes.clone();
        bad[mask_col + 8..mask_col + 16].fill(255);
        assert!(decode(&bad).unwrap_err().contains("noncanonical"));
        // Same-sized corruption across commitments, arguments, vectors, leaves
        // and paths must be rejected cryptographically, not just by framing.
        for offset in [
            41,
            41 + 44,
            41 + 88,
            41 + 120,
            205,
            mask_at,
            mask_col + 8,
            mask_col + 8 + 16 * 8,
            bytes.len() - 1,
            bytes.len() - 352,
            bytes.len() / 2,
        ] {
            let mut bad = bytes.clone();
            bad[offset] ^= 1;
            reject(&bad);
        }
        let mut altered = st.clone();
        altered.l += 1;
        assert!(fresh_poc::Proof::from_bytes(&altered, weights, &bytes, b"wire-request").is_err());
        altered = st.clone();
        altered.table[255] ^= 1;
        assert!(fresh_poc::Proof::from_bytes(&altered, weights, &bytes, b"wire-request").is_err());
        assert!(fresh_poc::Proof::from_bytes(&st, weights, &bytes, b"other-request").is_err());
        let other_mode = match privacy {
            ZkPrivacy::P1 => WeightStatement::FreshPrivate,
            ZkPrivacy::P3 => WeightStatement::Public(proof.weight_root()),
        };
        assert!(fresh_poc::verify_bytes(&st, other_mode, &bytes, b"wire-request").is_err());
        // The header hash is not an authentication mechanism. Recomputing it
        // for a different expected context/root still fails the actual proof.
        let relabelled = proof.to_bytes(&st, weights, b"other-request").unwrap();
        assert!(fresh_poc::verify_bytes(&st, weights, &relabelled, b"other-request").is_err());
        if privacy == ZkPrivacy::P1 {
            let wrong_root = WeightStatement::Public([0; 32]);
            let relabelled = proof.to_bytes(&st, wrong_root, b"wire-request").unwrap();
            assert!(
                fresh_poc::verify_bytes(&st, wrong_root, &relabelled, b"wire-request").is_err()
            );
        }
        // The encoder must reject invalid typed shapes even when flattening
        // would preserve the byte count (moved rounds/group coordinates).
        let last = proof.inner.gu_sc.rounds[0].pop().unwrap();
        proof.inner.gu_sc.rounds[1].push(last);
        assert!(proof.to_bytes(&st, weights, b"wire-request").is_err());
        proof.inner.gu_sc.rounds[1].pop();
        proof.inner.gu_sc.rounds[0].push(last);
        let last = proof.inner.a_open.group_vecs[0].pop().unwrap();
        proof.inner.a_open.group_vecs[1].push(last);
        assert!(proof.to_bytes(&st, weights, b"wire-request").is_err());
        proof.inner.a_open.group_vecs[1].pop();
        proof.inner.a_open.group_vecs[0].push(last);
        proof.inner.gu_term[0].c0 = Fp(crate::field::P);
        assert!(proof
            .to_bytes(&st, weights, b"wire-request")
            .unwrap_err()
            .contains("noncanonical"));
    }
}

// The two mask coefficients in an ACTUAL fully verified singleton group span
// Fp2. For every possible change of its private data, solve compensating mask
// changes that leave the public group vector (and hence its terminal) unchanged.
// This directly checks why the old elimination attack fails; it does not claim
// a simulator for the full nonlinear transcript or a joint-observation audit.
fn check_pair_ambiguity(o: &Observation, mask_row: usize, ntt: &NttTables) {
    let r = replay(o, ntt).unwrap();
    let (ci, claim) = o
        .claims
        .iter()
        .enumerate()
        .find(|(_, c)| c.parts.len() == 3 && c.parts[1].slice.offset == mask_row * o.params.cols())
        .unwrap();
    let (gi, group) = r
        .groups
        .iter()
        .enumerate()
        .find(|(_, g)| g.members == [ci])
        .unwrap();
    let lambda = group.lambdas[0];
    assert!(
        eliminate_one_mask(claim, lambda, &o.opening.group_vecs[gi], o.params.log_cols).is_err()
    );
    let a = lambda.mul(claim.parts[1].coef);
    let b = lambda.mul(claim.parts[2].coef);
    let det = determinant(a, b);
    assert!(!det.is_zero());
    let row_bits = claim.parts[0].slice.log_size as usize - o.params.log_cols as usize;
    for row_weight in eq_table_msb(&claim.parts[0].point[..row_bits]) {
        let delta = lambda.mul(claim.parts[0].coef).mul(row_weight).neg();
        let re = determinant(delta, b).mul(det.inv());
        let im = determinant(a, delta).mul(det.inv());
        assert_eq!(a.mul_base(re).add(b.mul_base(im)), delta);
    }
}

#[test]
fn repaired_fresh_poc_verifies_twice_and_blocks_single_mask_recovery() {
    let w = fixture(32, 17);
    let st = statement(&w);
    let ntt = NttTables::new(16);
    let zl = ZkLayoutV3::with_masks(32, 16, 16, &fresh_poc::parameters(), w.shifts, false, true);
    for privacy in [ZkPrivacy::P1, ZkPrivacy::P3] {
        let mut previous: Option<fresh_poc::Proof> = None;
        for attempt in 0..2 {
            let proof = fresh_poc::prove(&w, privacy, b"repaired-ffn-demo").unwrap();
            let guard = CaptureGuard::new();
            fresh_poc::verify(
                &st,
                weight_statement(privacy, proof.weight_root()),
                &proof,
                b"repaired-ffn-demo",
            )
            .unwrap();
            let observed = guard.take().unwrap();
            observation_json::export_repaired_if_requested(
                &observed,
                &ntt,
                &zl,
                privacy,
                &crate::export_v3::sha256_hex(&proof.inner.to_bytes()),
            );
            check_pair_ambiguity(&observed.a, zl.a_mgu[0], &ntt);
            check_pair_ambiguity(&observed.a, zl.a_mdd[0], &ntt);
            // Actual H helper/table claims, including their full row mapping.
            // Removing both reserved mask components must fail the rank guard.
            let masks = zl.h_mask_rows();
            for ci in (0..4).chain(5..11) {
                let mut claim = observed.h.claims[ci].clone();
                fresh_poc::check_masks(
                    std::slice::from_ref(&claim),
                    observed.h.commitment.rows,
                    zl.log_n,
                    &masks,
                    zl.h_prox,
                    &observed.h.before,
                )
                .unwrap();
                for part in &mut claim.parts {
                    if masks.contains(&(part.slice.offset / zl.a_n)) {
                        part.coef = Fp2::ZERO;
                    }
                }
                assert!(fresh_poc::check_masks(
                    &[claim],
                    observed.h.commitment.rows,
                    zl.log_n,
                    &masks,
                    zl.h_prox,
                    &observed.h.before
                )
                .is_err());
            }
            if let Some(o) = &observed.w {
                check_pair_ambiguity(o, zl.w_mdd[0], &ntt);
            }
            if let Some(prev) = previous {
                assert_ne!(prev.activation_root(), proof.activation_root());
                assert_ne!(prev.helper_root(), proof.helper_root());
                assert_ne!(prev.inner.mask_root, proof.inner.mask_root);
                if privacy == ZkPrivacy::P3 {
                    assert_ne!(prev.weight_root(), proof.weight_root());
                } else {
                    assert_eq!(prev.weight_root(), proof.weight_root());
                }
            }
            eprintln!("FRESH_FFN_POC privacy={privacy:?} attempt={attempt} verified=true A_rows={} H_rows={} W_rows={} payload_bytes={} singleton_mask_rank=2 recovery=underdetermined",
                proof.inner.a_com.as_ref().unwrap().rows, proof.inner.h_com.as_ref().unwrap().rows,
                proof.inner.w_com.as_ref().unwrap().rows, proof.payload_size());
            previous = Some(proof);
        }
    }
}

#[test]
fn repaired_fresh_poc_rejects_tampering_and_legacy_profiles() {
    let w = fixture(32, 19);
    let st = statement(&w);
    let ntt = NttTables::new(16);
    for privacy in [ZkPrivacy::P1, ZkPrivacy::P3] {
        let mut proof = fresh_poc::prove(&w, privacy, b"context-a").unwrap();
        let root = proof.weight_root();
        let verify = |p: &fresh_poc::Proof| {
            fresh_poc::verify(&st, weight_statement(privacy, root), p, b"context-a")
        };
        verify(&proof).unwrap();
        assert!(
            fresh_poc::verify(&st, weight_statement(privacy, root), &proof, b"context-b").is_err()
        );
        assert!(
            fresh_poc::verify(&st, WeightStatement::Public([0; 32]), &proof, b"context-a").is_err()
        );
        for delta in [-1isize, 1] {
            let rows = proof.inner.a_com.as_ref().unwrap().rows;
            proof.inner.a_com.as_mut().unwrap().rows = (rows as isize + delta) as usize;
            assert!(verify(&proof).unwrap_err().contains("rows"));
            proof.inner.a_com.as_mut().unwrap().rows = rows;
        }
        let extra = proof.inner.a_open.group_vecs[0].clone();
        proof.inner.a_open.group_vecs.push(extra);
        assert!(verify(&proof).is_err());
        proof.inner.a_open.group_vecs.pop();
        proof.inner.gu_term[0] = proof.inner.gu_term[0].add(Fp2::ONE);
        assert!(verify(&proof).is_err());
        proof.inner.gu_term[0] = proof.inner.gu_term[0].sub(Fp2::ONE);
        proof.inner.h_open.columns[0].1[0] = proof.inner.h_open.columns[0].1[0].add(Fp::ONE);
        let guard = CaptureGuard::new();
        assert!(verify(&proof).is_err());
        assert!(
            guard.take().is_none(),
            "failed proof published observations"
        );
        drop(guard);
        proof.inner.h_open.columns[0].1[0] = proof.inner.h_open.columns[0].1[0].sub(Fp::ONE);
        let cfg = ZkConfig {
            enabled: true,
            seed: Some(5),
            mode: ZkStatementMode {
                privacy,
                ..Default::default()
            },
        };
        assert!(verify_layer_zk_v3(
            &st,
            &proof.inner,
            &fresh_poc::parameters(),
            &ntt,
            &mut Transcript::new(b"context-a"),
            &cfg.mode
        )
        .is_err());
        let legacy = prove_layer_zk_v3(
            &w,
            32,
            &fresh_poc::parameters(),
            &ntt,
            &cfg,
            &mut Transcript::new(b"context-a"),
        );
        let wrapped_legacy = fresh_poc::Proof {
            inner: legacy.proof,
        };
        assert!(fresh_poc::verify(
            &st,
            weight_statement(privacy, wrapped_legacy.weight_root()),
            &wrapped_legacy,
            b"context-a"
        )
        .is_err());
        verify(&proof).unwrap();
    }
    // IO extends the observation contract. Even a fully accepted IO receipt
    // must not appear in the archived FFN-only capture/linear-analysis lane.
    let spec = fresh_poc::io::IoSpec::new([9; 32], -3, 0).unwrap();
    let x: Vec<_> = w.x.iter().map(|&x| Fp::from_i64(x as i64)).collect();
    let z: Vec<_> = w.z16.iter().map(|&x| Fp::from_i64(x as i64)).collect();
    let (expected, endpoints) = fresh_poc::io::prepare_endpoints(spec, &x, &z).unwrap();
    let receipt = fresh_poc::io::prepare(&w, ZkPrivacy::P3, &expected)
        .unwrap()
        .finish(endpoints)
        .unwrap();
    let mut bytes = receipt
        .to_bytes(&st, WeightStatement::FreshPrivate, &expected)
        .unwrap();
    let guard = CaptureGuard::new();
    fresh_poc::io::verify_bytes(&st, WeightStatement::FreshPrivate, &expected, &bytes).unwrap();
    assert!(guard.take().is_none());
    *bytes.last_mut().unwrap() ^= 1;
    assert!(
        fresh_poc::io::verify_bytes(&st, WeightStatement::FreshPrivate, &expected, &bytes).is_err()
    );
    assert!(
        guard.take().is_none(),
        "partial IO acceptance published an old capture"
    );
}

#[test]
fn repaired_layout_and_degenerate_mask_controls() {
    let mut draws = 0;
    assert!(fresh_poc::draw_mask_challenge(
        || {
            draws += 1;
            Fp2::ZERO
        },
        true
    )
    .is_err());
    assert_eq!(draws, 1, "a failed challenge must never resample");
    for log_cols in [5, 8, 16] {
        // At log_cols=16, T4096 makes the INT16 table itself a singleton.
        let t = if log_cols == 16 { 4096 } else { 32 };
        let p = LayerParams {
            log_cols,
            inv_rate: 8,
            num_col_checks: 256,
        };
        let zl = ZkLayoutV3::with_masks(t, 16, 16, &p, (7, 0, 14, 6), true, true);
        for (rows, total) in [
            (zl.a_mask_rows(), zl.a_len / zl.a_n),
            (zl.h_mask_rows(), zl.h_len / zl.a_n),
            (zl.w_mask_rows(), zl.w_len_p3 / zl.w_n),
        ] {
            let unique: std::collections::BTreeSet<_> = rows.iter().copied().collect();
            assert_eq!(unique.len(), rows.len());
            assert!(rows.iter().all(|&r| r < total));
        }
        for slot in &zl.tabs {
            let count = if slot.rows == 1 { 2 } else { slot.rows };
            assert!((slot.a_mask..slot.a_mask + count).all(|r| zl.a_mask_rows().contains(&r)));
        }
        let point = vec![Fp2::U; zl.log_s];
        fresh_poc::check_table_point(&zl, &point).unwrap();
        for slot in zl.tabs.iter().filter(|s| s.rows > 1) {
            for coordinate in zl.log_s - slot.log_size as usize..zl.log_s - zl.log_n {
                let mut bad = point.clone();
                bad[coordinate] = Fp2::ONE;
                assert!(fresh_poc::check_table_point(&zl, &bad).is_err());
            }
        }
    }
    let part = |row: usize, coef| ZPart {
        slice: Slice {
            offset: row * 4,
            log_size: 2,
        },
        coef,
        point: vec![Fp2::U; 2],
    };
    let mut claim = ZClaim {
        parts: vec![
            part(0, Fp2::ONE),
            part(1, Fp2::U),
            part(2, Fp2::U.mul(Fp2::U)),
        ],
        value: Fp2::ZERO,
    };
    let tr = Transcript::new(b"degeneracy-test");
    fresh_poc::check_masks(&[claim.clone()], 5, 2, &[1, 2], 3, &tr).unwrap();
    claim.parts[2].coef = claim.parts[1].coef;
    assert!(fresh_poc::check_masks(&[claim.clone()], 5, 2, &[1, 2], 3, &tr).is_err());
    claim.parts[1].coef = Fp2::ZERO;
    claim.parts[2].coef = Fp2::ZERO;
    assert!(fresh_poc::check_masks(&[claim], 5, 2, &[1, 2], 3, &tr).is_err());
    let mut draws = 0;
    assert!(fresh_poc::check_opening_challenges([1], 2, 0, || {
        draws += 1;
        Fp2::ZERO
    })
    .unwrap_err()
    .contains("group member"));
    assert_eq!(draws, 1);
    for pair in [
        [Fp2::ZERO, Fp2::ZERO],
        [Fp2::ONE, Fp2::ONE],
        [Fp2::U, Fp2::U],
    ] {
        let mut samples = [Fp2::ONE, pair[0], pair[1]].into_iter();
        assert!(
            fresh_poc::check_opening_challenges([1], 2, 0, || samples.next().unwrap())
                .unwrap_err()
                .contains("proximity")
        );
        assert!(samples.next().is_none());
    }
    let mut samples = [Fp2::ONE, Fp2::ONE, Fp2::U].into_iter();
    fresh_poc::check_opening_challenges([1], 2, 0, || samples.next().unwrap()).unwrap();
}
