//! Public synthetic boundary/transport tests, not private LLM proof tests.
#![cfg(not(feature = "gpu-cuda"))]
use hashline::attention as at;
use hashline::causal_oracle::{
    public_synthetic_fixture, public_synthetic_registration, FixedCausalOracle, OracleBlock,
};
use hashline::field::Fp2;
use hashline::layer::{prove_layer_v3, v3_zcd_point};
use hashline::ntt::NttTables;
use hashline::private_block_contract::ApprovedP1BlockContract;
use hashline::public_block_oracle::{lift_public_weight_claims, PublicBlockProof};
use hashline::public_block_receipt::{
    public_receipt_transcript, verify_public_receipt, verify_public_receipt_bytes,
    ExpectedPublicBlock, PublicBlockReceipt, PublicReceiptOracle, EXPECTED_BYTES,
    MAX_RECEIPT_BYTES,
};
use hashline::transcript::Transcript;

fn fixture() -> (
    ApprovedP1BlockContract,
    hashline::causal_oracle::PublicBlockWeights,
    ExpectedPublicBlock,
) {
    let (approved, weights, input) = public_synthetic_fixture();
    let block = FixedCausalOracle::new(&approved, weights.clone())
        .unwrap()
        .build(&input)
        .unwrap();
    let output: Vec<i16> = block
        .residual
        .xres2
        .iter()
        .map(|x| i16::try_from(*x).unwrap())
        .collect();
    let expected = ExpectedPublicBlock::new(&approved, [47; 32], &input, &output).unwrap();
    (approved, weights, expected)
}

#[test]
fn public_bound_receipt_roundtrips_and_preserves_legacy_fixture_metadata() {
    let (approved, weights, expected) = fixture();
    let r = approved.registration();
    // Independently recorded before metadata extraction from the unchanged B3
    // worker source, via zk60_metadata_reference (CPU release/offline).
    assert_eq!(
        hashline::silu::hex(&r.attention_weights.root),
        "f20dc692c421abae9bfcb15ac4c15d8cdce64ef6f49e256c635dcc4bf2354d36"
    );
    assert_eq!(
        hashline::silu::hex(&r.ffn_weights.root),
        "7578e15ca90d83ca31ce14df62f39fd0ede70089b34dd4580b86eb9e424ddbad"
    );
    assert_eq!(
        hashline::silu::hex(&approved.public_digest()),
        "22f5a8b67400e42accd55834c5fde334ca15f6be9661a5c4e7af614ebca9f7e2"
    );
    let metadata = ApprovedP1BlockContract::from_trusted_registration(
        public_synthetic_registration(r.attention_weights.clone(), r.ffn_weights.clone()),
    )
    .unwrap();
    assert_eq!(metadata.public_digest(), approved.public_digest());
    println!(
        "B4 public fixture attention_root={} FFN_root={} contract={}",
        hashline::silu::hex(&r.attention_weights.root),
        hashline::silu::hex(&r.ffn_weights.root),
        hashline::silu::hex(&approved.public_digest())
    );
    let oracle = PublicReceiptOracle::new(&approved, weights).unwrap();
    let receipt = oracle.prove(&expected).unwrap();
    verify_public_receipt(&approved, &expected, &receipt).unwrap();
    assert_eq!(receipt.block.attention.vals.len(), 135);
    let bytes = receipt.to_bytes().unwrap();
    let decoded = PublicBlockReceipt::from_bytes(&bytes).unwrap();
    assert_eq!(decoded.to_bytes().unwrap(), bytes);
    verify_public_receipt_bytes(&approved, &expected, &bytes).unwrap();
    // Repeated acceptance is intentional; replay consumption is application state.
    verify_public_receipt_bytes(&approved, &expected, &bytes).unwrap();
    let public_state = expected.to_bytes();
    assert_eq!(public_state.len(), EXPECTED_BYTES);
    let expected2 = ExpectedPublicBlock::from_bytes(&approved, &public_state).unwrap();
    assert_eq!(expected2.digest(), expected.digest());
    assert_eq!(expected2.input(), expected.input());
    assert_eq!(expected2.output(), expected.output());
    verify_public_receipt_bytes(&approved, &expected2, &bytes).unwrap();
    println!(
        "B4 public bound receipt bytes={} sha256={} expected_bytes={}",
        bytes.len(),
        {
            use sha2::Digest;
            hashline::silu::hex(&sha2::Sha256::digest(&bytes))
        },
        public_state.len()
    );
}

#[test]
fn independent_context_input_output_and_approval_cannot_be_relabelled() {
    let (approved, weights, expected) = fixture();
    let oracle = PublicReceiptOracle::new(&approved, weights).unwrap();
    let receipt = oracle.prove(&expected).unwrap();
    for which in 0..3 {
        let mut input = expected.input().to_vec();
        let mut output = expected.output().to_vec();
        let mut context = expected.context();
        match which {
            0 => context[0] ^= 1,
            1 => input[3] += 1,
            _ => output[5] += 1,
        }
        let other = ExpectedPublicBlock::new(&approved, context, &input, &output).unwrap();
        assert!(verify_public_receipt(&approved, &other, &receipt).is_err());
        let mut relabelled = receipt.clone();
        relabelled.request_digest = other.digest();
        assert!(verify_public_receipt(&approved, &other, &relabelled).is_err());
    }
    let mut bad = receipt.clone();
    bad.block.attention.w_com.as_mut().unwrap().root[0] ^= 1;
    assert_eq!(
        verify_public_receipt(&approved, &expected, &bad).unwrap_err(),
        "public receipt unapproved W root/shape"
    );
    let mut r = approved.registration();
    r.model_identity[0] ^= 1;
    r.mode.model_id = Some(hashline::silu::hex(&r.model_identity));
    let other = ApprovedP1BlockContract::from_trusted_registration(r).unwrap();
    assert!(verify_public_receipt(&other, &expected, &receipt).is_err());
}

// A prover may honestly commit/prove another computation under an arbitrary
// public request digest, so hashing expectations is insufficient. Build true
// arithmetic and true endpoint openings WITHOUT checking equality locally.
// The real verifier must reject the endpoint relation after both core proofs.
fn independently_committed_actual_block(
    approved: &ApprovedP1BlockContract,
    expected: &ExpectedPublicBlock,
    b: &OracleBlock,
) -> PublicBlockReceipt {
    assert!(!at::tamper_mode());
    let r = approved.registration();
    let ntt = NttTables::new(11);
    let mut tr = public_receipt_transcript(expected);
    let (mut attention, mut pending, _) =
        at::prove_attn(&b.attention, &b.residual, &r.params, &ntt, &mut tr);
    let before = Transcript::clone_state(&tr);
    let ffn = prove_layer_v3(&b.ffn, 32, &r.params, &ntt, &mut tr).proof;
    let rho = v3_zcd_point(&r.ffn, &ffn, &before);
    at::attn_seam(
        &mut pending.cc,
        &mut tr,
        &pending.lay,
        Some(&pending.a_data),
        &[rho],
        &ffn.zcd_term[..1],
        &ffn.zcd_term[1..2],
    )
    .unwrap();
    for (role, plane) in [
        (b"external-input".as_slice(), &pending.lay.x_in),
        (b"external-output".as_slice(), &pending.lay.xres2),
    ] {
        tr.absorb(b"public-boundary-role", role);
        let point = tr.challenge_fp2_vec(pending.lay.log_d as usize);
        at::cls_claim(
            &mut pending.cc,
            &mut tr,
            Some(&pending.a_data),
            plane,
            pending.lay.log_d,
            &point,
        );
    }
    lift_public_weight_claims(&pending.lay, &mut pending.cc).unwrap();
    at::attn_open(pending, &mut attention, &mut tr);
    PublicBlockReceipt {
        request_digest: expected.digest(),
        block: PublicBlockProof {
            contract_digest: approved.public_digest(),
            attention,
            ffn,
        },
    }
}

#[test]
fn freshly_committed_wrong_input_or_output_reaches_boundary_refusal_from_bytes() {
    let (approved, weights, expected) = fixture();
    let b = FixedCausalOracle::new(&approved, weights)
        .unwrap()
        .build(expected.input())
        .unwrap();
    for input_side in [true, false] {
        let mut input = expected.input().to_vec();
        let mut output = expected.output().to_vec();
        if input_side {
            input[17] += 1;
        } else {
            output[29] += 1;
        }
        let wrong =
            ExpectedPublicBlock::new(&approved, expected.context(), &input, &output).unwrap();
        let proof = independently_committed_actual_block(&approved, &wrong, &b);
        let bytes = proof.to_bytes().unwrap();
        assert_eq!(
            verify_public_receipt_bytes(&approved, &wrong, &bytes).unwrap_err(),
            "external public boundary"
        );
    }
}

#[test]
fn bounded_frames_and_unused_or_invalid_typed_messages_refuse() {
    let (approved, weights, expected) = fixture();
    let proof = PublicReceiptOracle::new(&approved, weights)
        .unwrap()
        .prove(&expected)
        .unwrap();
    let bytes = proof.to_bytes().unwrap();
    for n in [0, 1, 7, 8, 39, 43, 44, 73, bytes.len() / 2, bytes.len() - 1] {
        assert!(PublicBlockReceipt::from_bytes(&bytes[..n]).is_err());
    }
    let mut extra = bytes.clone();
    extra.push(0);
    assert!(PublicBlockReceipt::from_bytes(&extra).is_err());
    for pos in [0, 7, 40, 43, 44] {
        let mut wrong = bytes.clone();
        wrong[pos] ^= 0xff;
        assert!(PublicBlockReceipt::from_bytes(&wrong).is_err());
    }
    assert!(PublicBlockReceipt::from_bytes(&vec![0; MAX_RECEIPT_BYTES + 1]).is_err());
    let mut wrong = proof.clone();
    wrong.block.attention.helper_sums.push(Fp2::ZERO);
    assert!(wrong.to_bytes().is_err());
    assert!(verify_public_receipt(&approved, &expected, &wrong).is_err());
    let mut wrong = proof.clone();
    wrong.block.attention.vals.pop();
    assert!(verify_public_receipt(&approved, &expected, &wrong).is_err());
    let mut wrong = proof.clone();
    wrong.block.ffn.zcd_term.clear();
    assert!(verify_public_receipt(&approved, &expected, &wrong).is_err());
    let mut wrong = proof.clone();
    wrong.block.attention.sc.push(Default::default());
    assert!(verify_public_receipt(&approved, &expected, &wrong).is_err());
}

#[test]
fn expected_state_has_exact_owned_tensors_and_fixed_profile() {
    let (approved, weights, expected) = fixture();
    let mut supplied = expected.input().to_vec();
    let owned =
        ExpectedPublicBlock::new(&approved, expected.context(), &supplied, expected.output())
            .unwrap();
    supplied[0] += 1;
    assert_ne!(owned.input(), supplied);
    assert!(
        ExpectedPublicBlock::new(&approved, [0; 32], expected.input(), expected.output()).is_err()
    );
    assert!(
        ExpectedPublicBlock::new(&approved, [1; 32], &supplied[..511], expected.output()).is_err()
    );
    let bytes = expected.to_bytes();
    for n in [0, 7, 71, bytes.len() - 1] {
        assert!(ExpectedPublicBlock::from_bytes(&approved, &bytes[..n]).is_err());
    }
    let mut extra = bytes.clone();
    extra.push(0);
    assert!(ExpectedPublicBlock::from_bytes(&approved, &extra).is_err());
    let mut wrong = bytes.clone();
    wrong[8] ^= 1;
    assert!(ExpectedPublicBlock::from_bytes(&approved, &wrong).is_err());
    let mut r = approved.registration();
    r.residual.sh_r2 = 1;
    r.residual.e_r2 = 1;
    let other = ApprovedP1BlockContract::from_trusted_registration(r).unwrap();
    assert!(ExpectedPublicBlock::new(
        &other,
        expected.context(),
        expected.input(),
        expected.output()
    )
    .is_err());
    let mut output = expected.output().to_vec();
    output[0] += 1;
    let wrong =
        ExpectedPublicBlock::new(&approved, expected.context(), expected.input(), &output).unwrap();
    assert_eq!(
        PublicReceiptOracle::new(&approved, weights)
            .unwrap()
            .prove(&wrong)
            .unwrap_err(),
        "expected public output differs from fixed oracle"
    );
}

#[test]
fn incompatible_process_global_modes_refuse_in_isolated_processes() {
    for case in ["compact", "tamper", "fold", "no_fold", "gpu_env"] {
        let output = std::process::Command::new(std::env::current_exe().unwrap())
            .args(["--exact", "runtime_policy_child", "--test-threads=1"])
            .env("ZK60_B4_POLICY_CHILD", case)
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "policy child {case}: {}",
            String::from_utf8_lossy(&output.stderr)
        );
    }
}

#[test]
fn runtime_policy_child() {
    let Ok(case) = std::env::var("ZK60_B4_POLICY_CHILD") else {
        return;
    };
    let (approved, weights, _) = fixture();
    match case.as_str() {
        "compact" => {
            let mut config = hashline::pcs_compact::CompactCfg::DEFAULT;
            config.enabled = true;
            hashline::pcs_compact::configure(config);
        }
        "tamper" => at::set_tamper_mode(true),
        "fold" => std::env::set_var("HL_FOLD", "small"),
        "no_fold" => std::env::set_var("HL_NO_FOLD", "1"),
        "gpu_env" => std::env::set_var("HL_GPU", "1"),
        _ => panic!("unknown policy case"),
    }
    assert!(PublicReceiptOracle::new(&approved, weights).is_err());
}

#[test]
fn b3_and_b4_domains_are_not_interchangeable() {
    use hashline::public_block_oracle::{verify_public_block, PublicBlockOracle};
    let (approved, weights, expected) = fixture();
    let receipt = PublicReceiptOracle::new(&approved, weights.clone())
        .unwrap()
        .prove(&expected)
        .unwrap();
    assert!(verify_public_block(&approved, &receipt.block).is_err());
    let mut old = PublicBlockOracle::new(&approved, weights)
        .unwrap()
        .prove(expected.input())
        .unwrap();
    old.attention.vals.extend([Fp2::ZERO, Fp2::ZERO]);
    let relabelled = PublicBlockReceipt {
        request_digest: expected.digest(),
        block: old,
    };
    assert!(verify_public_receipt(&approved, &expected, &relabelled).is_err());
}
