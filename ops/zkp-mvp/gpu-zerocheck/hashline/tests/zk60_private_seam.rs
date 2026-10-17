//! Experimental gadget gates, not a whole-transformer security certification.
use hashline::field::{Fp, Fp2, P};
use hashline::ntt::NttTables;
use hashline::pcs::Commitment;
use hashline::private_seam::{self as seam, ExperimentalSeamProof, SeamSpec, Side};

fn spec(rows: usize, cols: usize) -> SeamSpec {
    SeamSpec::new([37; 32], rows, cols, -8, 10, 11).unwrap()
}
fn values(s: &SeamSpec) -> Vec<Fp> {
    (0..s.len())
        .map(|i| Fp::from_i64((i % 257) as i64 - 128))
        .collect()
}
fn attempt(s: &SeamSpec, a: &[Fp], b: &[Fp]) -> (Commitment, Commitment, ExperimentalSeamProof) {
    let ntt = NttTables::new(12);
    let left = seam::prepare(s, Side::Left, a, &ntt).unwrap();
    let right = seam::prepare(s, Side::Right, b, &ntt).unwrap();
    let lc = left.commitment();
    let rc = right.commitment();
    let proof = seam::prove(s, left, right, &ntt).unwrap();
    (lc, rc, proof)
}

#[test]
fn honest_independent_commitments_roundtrip_at_subrow_row_and_multirow_shapes() {
    let ntt = NttTables::new(12);
    for (rows, cols) in [(1, 2), (4, 16), (16, 16), (32, 16), (64, 64)] {
        let s = spec(rows, cols);
        let v = values(&s);
        let (l, r, p) = attempt(&s, &v, &v);
        assert_ne!(
            l.root, r.root,
            "identical values must use independent randomness"
        );
        seam::verify(&s, &l, &r, &p, &ntt).unwrap();
        let bytes = p.to_bytes(&s).unwrap();
        assert_eq!(bytes.len(), ExperimentalSeamProof::encoded_len(&s));
        assert!(bytes.len() < 1024 * 1024);
        let decoded = ExperimentalSeamProof::from_bytes(&s, &bytes).unwrap();
        assert_eq!(decoded.to_bytes(&s).unwrap(), bytes);
        seam::verify(&s, &l, &r, &decoded, &ntt).unwrap();
    }
}

#[test]
fn unequal_recommitted_witnesses_fail_at_verifier_not_prover() {
    let ntt = NttTables::new(12);
    let s = spec(32, 16);
    let v = values(&s);
    for at in [0, 255, 256, s.len() - 1] {
        let mut bad = v.clone();
        bad[at] = bad[at].add(Fp::ONE);
        // The attempted proof is actually constructed from the changed witness.
        let (l, r, p) = attempt(&s, &v, &bad);
        assert!(seam::verify(&s, &l, &r, &p, &ntt).is_err());
    }
}

#[test]
fn equal_unweighted_sums_do_not_substitute_for_pointwise_equality() {
    let ntt = NttTables::new(12);
    let s = spec(32, 16);
    let v = values(&s);
    for (a, b) in [(0, 1), (255, 256), (0, s.len() - 1)] {
        let mut bad = v.clone();
        bad[a] = bad[a].add(Fp::ONE);
        bad[b] = bad[b].sub(Fp::ONE);
        assert_eq!(
            v.iter().fold(Fp::ZERO, |s, x| s.add(*x)),
            bad.iter().fold(Fp::ZERO, |s, x| s.add(*x))
        );
        let (l, r, p) = attempt(&s, &v, &bad);
        assert!(seam::verify(&s, &l, &r, &p, &ntt).is_err());
    }
}

#[test]
fn proof_cannot_choose_its_endpoint_roots_or_replay_connection() {
    let ntt = NttTables::new(12);
    let s = spec(4, 16);
    let v = values(&s);
    let (l, r, p) = attempt(&s, &v, &v);
    let other = seam::prepare(&s, Side::Left, &v, &ntt)
        .unwrap()
        .commitment();
    assert!(seam::verify(&s, &other, &r, &p, &ntt).is_err());
    assert!(seam::verify(&s, &r, &l, &p, &ntt).is_err());
    for changed in [
        SeamSpec::new([38; 32], 4, 16, -8, 10, 11).unwrap(),
        SeamSpec::new([37; 32], 4, 16, -7, 10, 11).unwrap(),
        SeamSpec::new([37; 32], 4, 16, -8, 11, 10).unwrap(),
        SeamSpec::new([37; 32], 8, 8, -8, 10, 11).unwrap(),
    ] {
        assert!(seam::verify(&changed, &l, &r, &p, &ntt).is_err());
    }
    let mut changed = p.clone();
    changed.left = other.clone();
    // Even rewriting the header to the newly expected root cannot preserve its
    // challenge sequence and authenticated opening.
    assert!(seam::verify(&s, &other, &r, &changed, &ntt).is_err());
}

#[test]
fn every_message_family_is_authenticated() {
    let ntt = NttTables::new(12);
    let s = spec(4, 16);
    let v = values(&s);
    let (l, r, p) = attempt(&s, &v, &v);
    let changes: Vec<Box<dyn Fn(&mut ExperimentalSeamProof)>> = vec![
        Box::new(|p| p.mask_root[0] ^= 1),
        Box::new(|p| p.gamma = p.gamma.add(Fp2::ONE)),
        Box::new(|p| p.sc.rounds[0][0] = p.sc.rounds[0][0].add(Fp2::ONE)),
        Box::new(|p| p.sc.rounds.last_mut().unwrap()[2] = Fp2::ZERO),
        Box::new(|p| p.terminals[0] = p.terminals[0].add(Fp2::ONE)),
        Box::new(|p| p.terminals[1] = p.terminals[1].add(Fp2::ONE)),
        Box::new(|p| p.mask_eval = p.mask_eval.add(Fp2::ONE)),
        Box::new(|p| p.mask_opening.q[0] = p.mask_opening.q[0].add(Fp2::ONE)),
        Box::new(|p| p.mask_opening.prox[0] = p.mask_opening.prox[0].add(Fp2::ONE)),
        Box::new(|p| p.mask_opening.columns[0].2[0] ^= 1),
        Box::new(|p| {
            p.left_opening.group_vecs[0][0] = p.left_opening.group_vecs[0][0].add(Fp2::ONE)
        }),
        Box::new(|p| p.left_opening.prox_vec[0] = p.left_opening.prox_vec[0].add(Fp2::ONE)),
        Box::new(|p| p.left_opening.columns[0].1[0] = p.left_opening.columns[0].1[0].add(Fp::ONE)),
        Box::new(|p| p.right_opening.columns[0].3[0][0] ^= 1),
    ];
    for (i, change) in changes.into_iter().enumerate() {
        let mut bad = p.clone();
        change(&mut bad);
        assert!(
            seam::verify(&s, &l, &r, &bad, &ntt).is_err(),
            "mutation {i}"
        );
    }
}

#[test]
fn exact_counts_and_canonical_fields_reject_before_low_level_verifier() {
    let ntt = NttTables::new(12);
    let s = spec(4, 16);
    let v = values(&s);
    let (l, r, p) = attempt(&s, &v, &v);
    let changes: Vec<Box<dyn Fn(&mut ExperimentalSeamProof)>> = vec![
        Box::new(|p| p.left.rows = usize::MAX),
        Box::new(|p| p.right.log_cols = 63),
        Box::new(|p| {
            p.sc.rounds.pop();
        }),
        Box::new(|p| p.sc.rounds[0].push(Fp2::ZERO)),
        Box::new(|p| p.gamma.c0 = Fp(P)),
        Box::new(|p| p.left_opening.group_vecs.clear()),
        Box::new(|p| p.right_opening.columns[0].0 = usize::MAX),
        Box::new(|p| p.left_opening.columns[0].3.push([0; 32])),
        Box::new(|p| p.mask_opening.columns[0].1.push(Fp::ZERO)),
        Box::new(|p| {
            p.mask_opening.columns.pop();
        }),
    ];
    for change in changes {
        let mut bad = p.clone();
        change(&mut bad);
        assert!(seam::verify(&s, &l, &r, &bad, &ntt).is_err());
        assert!(bad.to_bytes(&s).is_err());
    }
}

#[test]
fn framed_decoder_rejects_truncation_extension_wrong_version_and_field_aliases() {
    let s = spec(4, 16);
    let v = values(&s);
    let (_, _, p) = attempt(&s, &v, &v);
    let bytes = p.to_bytes(&s).unwrap();
    for cut in [0, 7, 8, 40, 168, bytes.len() - 1] {
        assert!(ExperimentalSeamProof::from_bytes(&s, &bytes[..cut]).is_err());
    }
    let mut extra = bytes.clone();
    extra.push(0);
    assert!(ExperimentalSeamProof::from_bytes(&s, &extra).is_err());
    let mut version = bytes.clone();
    version[7] ^= 1;
    assert!(ExperimentalSeamProof::from_bytes(&s, &version).is_err());
    let mut shape = bytes.clone();
    shape[72..80].copy_from_slice(&u64::MAX.to_le_bytes());
    assert!(ExperimentalSeamProof::from_bytes(&s, &shape).is_err());
    let mut alias = bytes.clone();
    alias[168..176].copy_from_slice(&P.to_le_bytes());
    assert!(ExperimentalSeamProof::from_bytes(&s, &alias).is_err());
}

#[test]
fn invalid_shapes_inputs_and_prepared_contexts_fail_closed() {
    assert!(SeamSpec::new([0; 32], 4, 16, 0, 1, 2).is_err());
    for (r, c) in [
        (0, 16),
        (1, 1),
        (3, 16),
        (4, 17),
        (128, 64),
        (usize::MAX, 2),
    ] {
        assert!(SeamSpec::new([1; 32], r, c, 0, 1, 2).is_err());
    }
    assert!(SeamSpec::new([1; 32], 4, 16, 32, 1, 2).is_err());
    assert!(SeamSpec::new([1; 32], 4, 16, 0, 1, 1).is_err());
    let s = spec(4, 16);
    let v = values(&s);
    let ntt = NttTables::new(12);
    assert!(seam::prepare(&s, Side::Left, &v[..v.len() - 1], &ntt).is_err());
    let mut bad = v.clone();
    bad[0] = Fp(P);
    assert!(seam::prepare(&s, Side::Left, &bad, &ntt).is_err());
    assert!(seam::prepare(&s, Side::Left, &v, &NttTables::new(11)).is_err());
    let a = seam::prepare(&s, Side::Right, &v, &ntt).unwrap();
    let b = seam::prepare(&s, Side::Left, &v, &ntt).unwrap();
    assert!(seam::prove(&s, a, b, &ntt).is_err());
    let a = seam::prepare(&s, Side::Left, &v, &ntt).unwrap();
    let b = seam::prepare(&s, Side::Right, &v, &ntt).unwrap();
    let changed = SeamSpec::new([1; 32], 4, 16, -8, 10, 11).unwrap();
    assert!(seam::prove(&changed, a, b, &ntt).is_err());
}

#[test]
fn normal_calls_use_fresh_masks_and_changed_ntt_metadata_is_rejected() {
    let s = spec(4, 16);
    let v = values(&s);
    let ntt = NttTables::new(12);
    let (l, r, p) = attempt(&s, &v, &v);
    let (l2, r2, p2) = attempt(&s, &v, &v);
    assert_ne!(l.root, l2.root);
    assert_ne!(r.root, r2.root);
    assert_ne!(p.mask_root, p2.mask_root);
    assert_ne!(p.to_bytes(&s).unwrap(), p2.to_bytes(&s).unwrap());
    seam::verify(&s, &l, &r, &p, &ntt).unwrap();
    seam::verify(&s, &l2, &r2, &p2, &ntt).unwrap();
    let mut bad = NttTables::new(12);
    bad.roots[10] = Fp::ONE;
    assert!(seam::verify(&s, &l, &r, &p, &bad).is_err());
    bad.roots.clear();
    assert!(seam::verify(&s, &l, &r, &p, &bad).is_err());
}
