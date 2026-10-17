//! Compare the diagnostic against the independent, unchanged byte writers.
//! Fabricated ragged objects exercise serialization; they are not valid proofs.
use hashline::field::{Fp, Fp2};
use hashline::pcs::{Commitment, Opening, OpeningZk};
use hashline::sumcheck::SumcheckProof;
use hashline::zk::{LayerProofZk, MaskOpening, PredProofV3};

fn base() -> LayerProofZk {
    let cm = Some(Commitment {
        root: [0x12; 32],
        rows: 3,
        log_cols: 5,
    });
    LayerProofZk {
        w_com: cm.clone(),
        a_com: cm.clone(),
        h_com: cm,
        ..Default::default()
    }
}

fn ragged_plain() -> Opening {
    Opening {
        group_vecs: vec![vec![], vec![Fp2::ONE; 3], vec![Fp2::ONE]],
        prox_vec: vec![Fp2::ONE; 2],
        columns: vec![
            (7, vec![Fp::ONE; 2], vec![[1; 32]; 3]),
            (7, vec![Fp::ONE; 5], vec![]),
        ],
    }
}

fn ragged_hiding() -> OpeningZk {
    OpeningZk {
        group_vecs: vec![vec![Fp2::ONE; 2], vec![]],
        prox_vec: vec![Fp2::ONE; 3],
        columns: vec![
            (5, vec![Fp::ONE; 3], [2; 32], vec![[3; 32]]),
            (5, vec![], [4; 32], vec![[5; 32]; 2]),
        ],
    }
}

#[test]
fn complete_empty_fields_count_fixed_headers_and_scalar_arguments() {
    let proof = base();
    let sizes = proof.size_breakdown().unwrap();
    assert_eq!(sizes.commitment_headers, 132);
    assert_eq!(sizes.mask_root, 32);
    assert_eq!(sizes.total_bytes(), 276);
    assert_eq!(sizes.total_bytes(), proof.to_bytes().len());
    assert_eq!(
        sizes.arguments.map(|a| a.name()),
        ["gu", "d", "zc20", "zc17", "zs", "table"]
    );
    assert!(sizes.predicate.is_none());
    assert_eq!(sizes.w_plain.total_bytes(), 0);
    assert_eq!(sizes.w_hiding.total_bytes(), 0);
}

#[test]
fn every_missing_mandatory_commitment_refuses_a_complete_size_report() {
    for which in 0..3 {
        let mut proof = base();
        match which {
            0 => proof.w_com = None,
            1 => proof.a_com = None,
            _ => proof.h_com = None,
        }
        assert!(proof.size_breakdown().is_err());
    }
}

#[test]
fn ragged_openings_count_actual_columns_and_preserve_plain_vs_salted_framing() {
    let mut proof = base();
    proof.w_open = ragged_plain();
    proof.w_open_zk = ragged_hiding(); // Count both physical fields, never infer mode.
    proof.a_open = ragged_hiding();
    proof.h_open = OpeningZk {
        prox_vec: vec![Fp2::ONE; 5],
        ..Default::default()
    };
    proof.mask_open = MaskOpening {
        q: vec![Fp2::ONE; 7],
        prox: vec![Fp2::ONE; 2],
        columns: ragged_hiding().columns,
    };
    let before = proof.to_bytes();
    let sizes = proof.size_breakdown().unwrap();
    assert_eq!(sizes.w_plain.group_vectors, 64);
    assert_eq!(sizes.w_plain.columns.indices, 16); // Repeated indices are still serialized twice.
    assert_eq!(sizes.w_plain.columns.values, 56);
    assert_eq!(sizes.w_plain.columns.authentication_paths, 96);
    assert_eq!(sizes.w_plain.columns.salts, 0);
    assert_eq!(sizes.w_hiding.columns.salts, 64);
    assert_eq!(sizes.mask_opening.functional_vector, 112);
    assert_eq!(sizes.mask_opening.columns.salts, 64);
    let mut bytes = Vec::new();
    proof.w_open.write_bytes(&mut bytes);
    assert_eq!(sizes.w_plain.total_bytes(), bytes.len());
    bytes.clear();
    proof.w_open_zk.write_bytes(&mut bytes);
    assert_eq!(sizes.w_hiding.total_bytes(), bytes.len());
    bytes.clear();
    proof.a_open.write_bytes(&mut bytes);
    assert_eq!(sizes.a.total_bytes(), bytes.len());
    bytes.clear();
    proof.h_open.write_bytes(&mut bytes);
    assert_eq!(sizes.h.total_bytes(), bytes.len());
    bytes.clear();
    proof.mask_open.write_bytes(&mut bytes);
    assert_eq!(sizes.mask_opening.total_bytes(), bytes.len());
    assert_eq!(sizes.total_bytes(), before.len());
    assert_eq!(proof.to_bytes(), before, "counting modified the proof");
}

#[test]
fn all_argument_families_and_optional_predicate_match_their_writers() {
    let mut proof = base();
    let sc = |n| SumcheckProof {
        rounds: vec![vec![], vec![Fp2::ONE; n], vec![Fp2::ONE]],
    };
    proof.gu_sc = sc(1);
    proof.gu_term = vec![Fp2::ONE; 2];
    proof.d_sc = sc(2);
    proof.d_term = vec![Fp2::ONE; 3];
    proof.zc20_sc = sc(3);
    proof.zc20_term = vec![Fp2::ONE; 4];
    proof.zc17_sc = sc(4);
    proof.zc17_term = vec![Fp2::ONE; 5];
    proof.zs_sc = sc(5);
    proof.tab_sc = sc(6);
    proof.tab_term = vec![Fp2::ONE; 7];
    let sizes = proof.size_breakdown().unwrap();
    for (count, (sc, terms)) in sizes.arguments.iter().zip([
        (&proof.gu_sc, 2),
        (&proof.d_sc, 3),
        (&proof.zc20_sc, 4),
        (&proof.zc17_sc, 5),
        (&proof.zs_sc, 1),
        (&proof.tab_sc, 7),
    ]) {
        let mut bytes = vec![0; 16]; // One actual Fp2 claim or challenge.
        sc.write_bytes(&mut bytes);
        bytes.extend(vec![0; terms * 16]);
        assert_eq!(count.total_bytes(), bytes.len(), "{}", count.name());
    }
    assert_eq!(sizes.total_bytes(), proof.to_bytes().len());
    let old_len = proof.to_bytes().len();
    proof.pred = Some(PredProofV3 {
        gamma: Fp2::ONE,
        sc: sc(8),
        term: vec![Fp2::ONE; 3],
    });
    let with_predicate = proof.size_breakdown().unwrap();
    let mut extra = Vec::new();
    proof.pred.as_ref().unwrap().write_bytes(&mut extra);
    assert_eq!(with_predicate.predicate.unwrap().total_bytes(), extra.len());
    assert_eq!(with_predicate.total_bytes(), old_len + extra.len());
    assert_eq!(with_predicate.total_bytes(), proof.to_bytes().len());
}

#[test]
fn independent_section_mutations_cannot_hide_in_a_residual() {
    let mut proof = base();
    proof.w_open = ragged_plain();
    proof.a_open = ragged_hiding();
    let baseline = proof.size_breakdown().unwrap();
    let old_bytes = proof.to_bytes().len();
    proof.w_open.columns[0].1.push(Fp::ONE);
    let mut expected = baseline.clone();
    expected.w_plain.columns.values += 8;
    assert_eq!(proof.size_breakdown().unwrap(), expected);
    assert_eq!(proof.to_bytes().len(), old_bytes + 8);
    proof.w_open.columns[0].1.pop();
    proof.a_open.columns[0].3.push([9; 32]);
    let mut expected = baseline;
    expected.a.columns.authentication_paths += 32;
    assert_eq!(proof.size_breakdown().unwrap(), expected);
    assert_eq!(proof.to_bytes().len(), old_bytes + 32);
}
