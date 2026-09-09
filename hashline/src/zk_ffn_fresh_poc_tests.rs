use super::*;
use crate::zk::fresh_poc::{self, WeightStatement};

fn weight_statement(privacy: ZkPrivacy, root: Digest) -> WeightStatement {
    match privacy {
        ZkPrivacy::P1 => WeightStatement::Public(root),
        ZkPrivacy::P3 => WeightStatement::FreshPrivate,
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
        let mut point = vec![Fp2::U; zl.log_s];
        fresh_poc::check_table_point(&zl, &point).unwrap();
        if zl.log_s > zl.log_n {
            point[0] = Fp2::ONE;
            assert!(fresh_poc::check_table_point(&zl, &point).is_err());
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
}
