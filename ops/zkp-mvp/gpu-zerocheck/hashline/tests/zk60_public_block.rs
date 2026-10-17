//! Public tiny arithmetic proofs, not privacy, generation or transport tests.
use hashline::attention as at;
use hashline::causal_oracle::{
    cpu_weight_commitments, public_synthetic_fixture, FixedCausalOracle, OracleBlock,
};
use hashline::field::Fp2;
use hashline::layer::{prove_layer_v3, v3_zcd_point};
use hashline::mle::eval_mle_base;
use hashline::ntt::NttTables;
use hashline::pcs::{Claim, Slice};
use hashline::private_block_contract::ApprovedP1BlockContract;
use hashline::public_block_oracle::{
    lift_public_weight_claims, public_block_transcript, verify_public_block, PublicBlockError,
    PublicBlockOracle, PublicBlockProof,
};
use hashline::transcript::Transcript;
use std::time::Instant;

#[test]
fn honest_fixed_block_proves_and_verifies_with_approved_roots() {
    let (approved, weights, input) = public_synthetic_fixture();
    let original = approved.public_digest();
    let oracle = PublicBlockOracle::new(&approved, weights).unwrap();
    let tick = Instant::now();
    let proof = oracle.prove(&input).unwrap();
    let prove = tick.elapsed();
    let tick = Instant::now();
    verify_public_block(&approved, &proof).unwrap();
    let verify = tick.elapsed();
    assert_eq!(approved.public_digest(), original);
    let a = proof.attention.to_bytes();
    let f = proof.ffn.to_bytes();
    assert_eq!(proof.payload_size_bytes(), a.len() + f.len());
    println!("B3 PUBLIC P0 T32 d16 f16 one block: prove={prove:?} verify={verify:?} attention={} FFN={} payload={} B; NO privacy/generation claim", a.len(), f.len(), proof.payload_size_bytes());

    // Wrong roots are refused against INDEPENDENT trusted state, even though
    // the legacy argument verifier alone accepts its own supplied W root.
    for which in 0..6 {
        let mut bad = proof.clone();
        let root = if which < 3 {
            &mut bad.attention.w_com
        } else {
            &mut bad.ffn.w_com
        };
        match which % 3 {
            0 => root.as_mut().unwrap().root[0] ^= 1,
            1 => root.as_mut().unwrap().rows += 1,
            _ => root.as_mut().unwrap().log_cols -= 1,
        }
        let expected = if which < 3 {
            PublicBlockError::AttentionWeights
        } else {
            PublicBlockError::FfnWeights
        };
        assert_eq!(verify_public_block(&approved, &bad), Err(expected));
    }
    let mut bad = proof.clone();
    bad.attention.vals[0] = bad.attention.vals[0].add(Fp2::ONE);
    assert_eq!(
        verify_public_block(&approved, &bad),
        Err(PublicBlockError::Verification("attention argument"))
    );
    let mut bad = proof.clone();
    bad.ffn.zcd_term[0] = bad.ffn.zcd_term[0].add(Fp2::ONE);
    assert_eq!(
        verify_public_block(&approved, &bad),
        Err(PublicBlockError::Verification("FFN argument/openings"))
    );

    // A different otherwise supported public residual scale is not the same
    // statement. Replacing only the proof's digest cannot rebind its transcript.
    let mut changed = approved.registration();
    changed.residual.sh_r2 = 1;
    changed.residual.e_r2 = 1;
    let other = ApprovedP1BlockContract::from_trusted_registration(changed).unwrap();
    assert_eq!(
        verify_public_block(&other, &proof),
        Err(PublicBlockError::ContractDigest)
    );
    let mut relabeled = proof.clone();
    relabeled.contract_digest = other.public_digest();
    assert_eq!(
        verify_public_block(&other, &relabeled),
        Err(PublicBlockError::Verification("attention argument"))
    );
    assert_eq!(approved.public_digest(), original);
}

#[test]
fn typed_attention_and_block_reject_unused_proof_messages() {
    let (approved, weights, input) = public_synthetic_fixture();
    let proof = PublicBlockOracle::new(&approved, weights)
        .unwrap()
        .prove(&input)
        .unwrap();
    verify_public_block(&approved, &proof).unwrap();
    let r = approved.registration();
    for which in 0..4 {
        let mut bad = proof.clone();
        let expected = if which < 2 {
            let mut extra = bad.attention.sc[0].clone();
            if which == 1 {
                extra.rounds.clear();
            }
            bad.attention.sc.push(extra);
            "unused attention sumchecks"
        } else {
            bad.attention
                .helper_sums
                .push(if which == 2 { Fp2::ZERO } else { Fp2::ONE });
            "unused attention helper_sums"
        };
        // Exercise the ordinary typed attention entry point, including the
        // empty/zero payloads a value-only check could accidentally permit.
        let mut tr = public_block_transcript(&approved);
        let error = at::verify_attn(
            &bad.attention,
            &r.attention,
            &r.residual,
            &r.params,
            &mut tr,
        )
        .err()
        .expect("unused proof messages must not be silently accepted");
        assert!(error.starts_with(expected), "{error}");
        assert_eq!(
            verify_public_block(&approved, &bad),
            Err(PublicBlockError::Verification("attention argument"))
        );
    }
    // Refusals do not mutate the original proof or approved context.
    verify_public_block(&approved, &proof).unwrap();
}

#[test]
fn short_weight_lifting_preserves_both_halves_and_rejects_unsupported_claims() {
    let (approved, weights, input) = public_synthetic_fixture();
    let b = FixedCausalOracle::new(&approved, weights)
        .unwrap()
        .build(&input)
        .unwrap();
    let r = approved.registration();
    let lay = at::attn_layout_of(&r.attention, &r.residual, 8);
    assert_eq!((lay.wk, lay.wv, lay.w_len), (256, 384, 1024));
    let w = at::pack(&b.attention, &b.residual, &lay).w;
    let point: Vec<_> = (2..9).map(Fp2::from_i64).collect();
    let mut cc = at::Cc::new(true, vec![]);
    for offset in [lay.wk, lay.wv] {
        let value = eval_mle_base(&w[offset..offset + 128], &point);
        cc.ww.push(Claim {
            parts: vec![(
                Slice {
                    offset,
                    log_size: 7,
                },
                Fp2::ONE,
            )],
            point: point.clone(),
            sum: false,
            value,
        });
    }
    let original = cc.ww.clone();
    assert_eq!(lift_public_weight_claims(&lay, &mut cc), Ok(2));
    for (i, claim) in cc.ww.iter().enumerate() {
        assert_eq!(claim.parts[0].0.offset, 256);
        assert_eq!(claim.parts[0].0.log_size, 8);
        assert_eq!(claim.point[0], if i == 0 { Fp2::ZERO } else { Fp2::ONE });
        assert_eq!(eval_mle_base(&w[256..512], &claim.point), original[i].value);
        assert_eq!(claim.value, original[i].value);
    }
    assert_eq!(lift_public_weight_claims(&lay, &mut cc), Ok(0));
    for which in 0..7 {
        let mut bad = at::Cc::new(true, vec![]);
        bad.ww = vec![original[0].clone()];
        let claim = &mut bad.ww[0];
        match which {
            0 => claim.sum = true,
            1 => claim.parts[0].1 = Fp2::from_i64(2),
            2 => claim.parts[0].0.offset = 1024,
            3 => claim.parts.push(original[1].parts[0].clone()),
            4 => claim.point.pop().map(|_| ()).unwrap(),
            5 => claim.parts[0].0.log_size = 6,
            _ => claim.parts.clear(),
        }
        assert!(lift_public_weight_claims(&lay, &mut bad).is_err());
    }
}

/// A malicious prover can commit two individually correct halves and decline
/// to enforce their equality. Supply the attention side's TRUE values to its
/// local assertion; the real verifier still compares against the FFN values.
/// This test does not toggle any global tamper mode, forge a claimed opening,
/// or skip any verifier arithmetic/PCS stage before seam refusal.
fn independently_recommitted_halves(
    approved: &ApprovedP1BlockContract,
    b: &OracleBlock,
) -> (PublicBlockProof, [Fp2; 2], [Fp2; 2]) {
    assert!(!at::tamper_mode());
    let r = approved.registration();
    let ntt = NttTables::new(11);
    let mut tr = public_block_transcript(approved);
    let (mut attention, mut pending, _) =
        at::prove_attn(&b.attention, &b.residual, &r.params, &ntt, &mut tr);
    let before = Transcript::clone_state(&tr);
    let ffn = prove_layer_v3(&b.ffn, 32, &r.params, &ntt, &mut tr).proof;
    let rho = v3_zcd_point(&r.ffn, &ffn, &before);
    assert_eq!(rho.len(), 9);
    assert_eq!(pending.lay.log_d, 9);
    let own = [pending.lay.xm8, pending.lay.z16c]
        .map(|offset| eval_mle_base(&pending.a_data[offset..offset + 512], &rho));
    let ffn_values = [ffn.zcd_term[0], ffn.zcd_term[1]];
    at::attn_seam(
        &mut pending.cc,
        &mut tr,
        &pending.lay,
        Some(&pending.a_data),
        &[rho],
        &own[..1],
        &own[1..],
    )
    .unwrap();
    assert_eq!(
        lift_public_weight_claims(&pending.lay, &mut pending.cc),
        Ok(2)
    );
    at::attn_open(pending, &mut attention, &mut tr);
    (
        PublicBlockProof {
            contract_digest: approved.public_digest(),
            attention,
            ffn,
        },
        own,
        ffn_values,
    )
}

#[test]
fn recommitted_correct_ffn_on_different_x_reaches_seam_refusal() {
    let (approved, weights, input) = public_synthetic_fixture();
    let oracle = FixedCausalOracle::new(&approved, weights).unwrap();
    let mut b = oracle.build(&input).unwrap();
    let mut changed = input.clone();
    changed[2] += 1;
    b.ffn = oracle.build(&changed).unwrap().ffn;
    let (proof, own, ffn) = independently_recommitted_halves(&approved, &b);
    assert_ne!(own[0], ffn[0]);
    assert_eq!(
        verify_public_block(&approved, &proof),
        Err(PublicBlockError::Verification("internal seam"))
    );
}

#[test]
fn recommitted_residual_with_wrong_z_copy_reaches_second_seam_refusal() {
    let (approved, weights, input) = public_synthetic_fixture();
    let mut b = FixedCausalOracle::new(&approved, weights)
        .unwrap()
        .build(&input)
        .unwrap();
    at::break_seam(&mut b.residual, &b.attention, 7);
    let (proof, own, ffn) = independently_recommitted_halves(&approved, &b);
    assert_eq!(own[0], ffn[0]);
    assert_ne!(own[1], ffn[1]);
    assert_eq!(
        verify_public_block(&approved, &proof),
        Err(PublicBlockError::Verification("internal seam"))
    );
}

#[test]
fn changed_public_weights_and_hostile_input_refuse_before_legacy_prover() {
    let (approved, weights, input) = public_synthetic_fixture();
    let mut changed = weights.clone();
    changed.gamma_a[0] += 1;
    assert!(matches!(
        PublicBlockOracle::new(&approved, changed),
        Err(PublicBlockError::Oracle(_))
    ));
    let oracle = PublicBlockOracle::new(&approved, weights).unwrap();
    assert!(matches!(
        oracle.prove(&input[..511]),
        Err(PublicBlockError::Oracle(_))
    ));
    assert!(matches!(
        oracle.prove(&vec![32767; 512]),
        Err(PublicBlockError::Oracle(_))
    ));
}

#[test]
fn freshly_proven_other_weights_cannot_be_relabelled_as_approved_model() {
    let (approved, weights, input) = public_synthetic_fixture();
    for change_attention in [true, false] {
        let mut other_weights = weights.clone();
        if change_attention {
            other_weights.gamma_a[0] += 1;
        } else {
            other_weights.wu_t[3] += 1;
        }
        // Separate, explicitly test-trusted context for the other weights.
        // The ORIGINAL approval is never derived from this candidate proof.
        let mut other_registration = approved.registration();
        let (aw, fw) = cpu_weight_commitments(&other_weights).unwrap();
        other_registration.attention_weights = aw;
        other_registration.ffn_weights = fw;
        let other = ApprovedP1BlockContract::from_trusted_registration(other_registration).unwrap();
        let mut proof = PublicBlockOracle::new(&other, other_weights)
            .unwrap()
            .prove(&input)
            .unwrap();
        verify_public_block(&other, &proof).unwrap();
        proof.contract_digest = approved.public_digest();
        let expected = if change_attention {
            PublicBlockError::AttentionWeights
        } else {
            PublicBlockError::FfnWeights
        };
        assert_eq!(verify_public_block(&approved, &proof), Err(expected));
    }
}
