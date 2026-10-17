//! Exactly two PUBLIC fixed blocks, not private/recursive/generation proofs.
#![cfg(not(feature = "gpu-cuda"))]
use hashline::attention as at;
use hashline::causal_oracle::{
    cpu_weight_commitments, public_synthetic_fixture, FixedCausalOracle, OracleBlock,
    PublicBlockWeights,
};
use hashline::layer::{prove_layer_v3, v3_zcd_point};
use hashline::ntt::NttTables;
use hashline::private_block_contract::{ApprovedP1BlockContract, BlockRegistration};
use hashline::public_block_oracle::{lift_public_weight_claims, PublicBlockProof};
use hashline::public_block_receipt::{
    public_receipt_transcript, verify_public_receipt, ExpectedPublicBlock, PublicBlockReceipt,
    PublicReceiptOracle, WORDS,
};
use hashline::public_chain_receipt::{
    verify_public_chain, verify_public_chain_bytes, ExpectedPublicChain, PublicChainOracle,
    PublicChainReceipt, EXPECTED_CHAIN_BYTES, MAX_CHAIN_BYTES,
};
use hashline::transcript::Transcript;
use std::sync::OnceLock;

struct Fixture {
    approved: [ApprovedP1BlockContract; 2],
    weights: [PublicBlockWeights; 2],
    expected: ExpectedPublicChain,
    receipt: PublicChainReceipt,
}
fn approve(r: BlockRegistration) -> ApprovedP1BlockContract {
    ApprovedP1BlockContract::from_trusted_registration(r).unwrap()
}
fn output(b: &OracleBlock) -> Vec<i16> {
    b.residual
        .xres2
        .iter()
        .map(|v| i16::try_from(*v).unwrap())
        .collect()
}
fn fixture() -> &'static Fixture {
    static FIXTURE: OnceLock<Fixture> = OnceLock::new();
    FIXTURE.get_or_init(|| {
        let (first, w0, input) = public_synthetic_fixture();
        // Distinct, independently fixed second-layer public weights and roots.
        let mut w1 = w0.clone();
        w1.wo[16 + 8] = -11;
        w1.wd_t[7 * 16 + 4] = 9;
        let (aw, fw) = cpu_weight_commitments(&w1).unwrap();
        let mut next = first.registration();
        next.attention.layer = 1;
        next.ffn.l = 1;
        next.attention_weights = aw;
        next.ffn_weights = fw;
        let approved = [first, approve(next)];
        let b0 = FixedCausalOracle::new(&approved[0], w0.clone())
            .unwrap()
            .build(&input)
            .unwrap();
        let intermediate = output(&b0);
        let b1 = FixedCausalOracle::new(&approved[1], w1.clone())
            .unwrap()
            .build(&intermediate)
            .unwrap();
        let expected = ExpectedPublicChain::new(&approved, [61; 32], &input, &output(&b1)).unwrap();
        let weights = [w0, w1];
        let receipt = PublicChainOracle::new(&approved, weights.clone())
            .unwrap()
            .prove(&expected)
            .unwrap();
        assert_eq!(receipt.intermediate.as_slice(), intermediate);
        assert_ne!(expected.input(), intermediate);
        assert_ne!(expected.output(), intermediate);
        Fixture {
            approved,
            weights,
            expected,
            receipt,
        }
    })
}

#[test]
fn real_two_block_chain_roundtrips_with_nontrivial_residual_evolution() {
    let f = fixture();
    assert_ne!(
        f.approved[0].registration().attention_weights.root,
        f.approved[1].registration().attention_weights.root
    );
    assert_ne!(
        f.approved[0].registration().ffn_weights.root,
        f.approved[1].registration().ffn_weights.root
    );
    verify_public_chain(&f.approved, &f.expected, &f.receipt).unwrap();
    let bytes = f.receipt.to_bytes().unwrap();
    let decoded = PublicChainReceipt::from_bytes(&bytes).unwrap();
    assert_eq!(decoded.to_bytes().unwrap(), bytes);
    verify_public_chain_bytes(&f.approved, &f.expected, &bytes).unwrap();
    verify_public_chain_bytes(&f.approved, &f.expected, &bytes).unwrap(); // intentional stateless replay
    let public = f.expected.to_bytes();
    assert_eq!(public.len(), EXPECTED_CHAIN_BYTES);
    let expected = ExpectedPublicChain::from_bytes(&f.approved, &public).unwrap();
    assert_eq!(expected.digest(), f.expected.digest());
    assert_eq!(expected.context(), f.expected.context());
    assert_eq!(expected.input(), f.expected.input());
    assert_eq!(expected.output(), f.expected.output());
    verify_public_chain_bytes(&f.approved, &expected, &bytes).unwrap();
    let blocks = expected
        .block_expectations(&f.approved, &decoded.intermediate)
        .unwrap();
    assert_eq!(blocks[0].output(), blocks[1].input());
    assert_ne!(blocks[0].context(), blocks[1].context());
    for i in 0..2 {
        verify_public_receipt(&f.approved[i], &blocks[i], &decoded.blocks[i]).unwrap();
        assert_eq!(decoded.blocks[i].block.attention.vals.len(), 135);
    }
    use sha2::Digest;
    println!("B5 PUBLIC two blocks T32/d16/f16: chain_bytes={} expected_bytes={} sha256={}; no privacy/generation/throughput claim", bytes.len(), public.len(), hashline::silu::hex(&sha2::Sha256::digest(&bytes)));
}

#[test]
fn expected_state_rejects_unapproved_order_identity_profile_and_shapes() {
    let f = fixture();
    let mut input = f.expected.input().to_vec();
    let owned = ExpectedPublicChain::new(
        &f.approved,
        f.expected.context(),
        &input,
        f.expected.output(),
    )
    .unwrap();
    input[0] += 1;
    assert_ne!(owned.input(), input);
    assert!(ExpectedPublicChain::new(
        &f.approved,
        [0; 32],
        f.expected.input(),
        f.expected.output()
    )
    .is_err());
    assert!(
        ExpectedPublicChain::new(&f.approved, [1; 32], &input[..511], f.expected.output()).is_err()
    );
    assert!(f
        .expected
        .block_expectations(&f.approved, &input[..511])
        .is_err());
    for case in 0..5 {
        let mut a = f.approved[0].registration();
        let mut b = f.approved[1].registration();
        match case {
            0 => std::mem::swap(&mut a, &mut b),
            1 => {
                b.attention.layer = 0;
                b.ffn.l = 0;
            }
            2 => {
                b.attention.layer = 2;
                b.ffn.l = 2;
            }
            3 => b.calibration_identity[0] ^= 1,
            _ => {
                a.residual.sh_r2 = 1;
                a.residual.e_r2 = 1;
            }
        }
        let approved = [approve(a), approve(b)];
        assert!(ExpectedPublicChain::new(
            &approved,
            [1; 32],
            f.expected.input(),
            f.expected.output()
        )
        .is_err());
    }
    let bytes = f.expected.to_bytes();
    for cut in [0, 7, 15, 79, bytes.len() - 1] {
        assert!(ExpectedPublicChain::from_bytes(&f.approved, &bytes[..cut]).is_err());
    }
    for at in [0, 8, 12, 16, 48] {
        let mut bad = bytes.clone();
        bad[at] ^= 1;
        assert!(ExpectedPublicChain::from_bytes(&f.approved, &bad).is_err());
    }
    let mut bad = bytes;
    bad.push(0);
    assert!(ExpectedPublicChain::from_bytes(&f.approved, &bad).is_err());
}

fn relabel_requests(
    receipt: &mut PublicChainReceipt,
    approved: &[ApprovedP1BlockContract; 2],
    expected: &ExpectedPublicChain,
) {
    receipt.request_digest = expected.digest();
    let blocks = expected
        .block_expectations(approved, &receipt.intermediate)
        .unwrap();
    for i in 0..2 {
        receipt.blocks[i].request_digest = blocks[i].digest();
        receipt.blocks[i].block.contract_digest = approved[i].public_digest();
    }
}

#[test]
fn changed_external_context_tensors_or_roots_cannot_be_relabelled() {
    let f = fixture();
    for case in 0..3 {
        let mut input = f.expected.input().to_vec();
        let mut output = f.expected.output().to_vec();
        let mut context = f.expected.context();
        match case {
            0 => context[0] ^= 1,
            1 => input[5] += 1,
            _ => output[7] += 1,
        }
        let expected = ExpectedPublicChain::new(&f.approved, context, &input, &output).unwrap();
        let mut bad = f.receipt.clone();
        assert!(verify_public_chain(&f.approved, &expected, &bad).is_err());
        relabel_requests(&mut bad, &f.approved, &expected);
        assert_eq!(
            verify_public_chain_bytes(&f.approved, &expected, &bad.to_bytes().unwrap())
                .unwrap_err(),
            "public chain block 0: receipt attention argument"
        );
    }
    for block in 0..2 {
        let mut bad = f.receipt.clone();
        bad.blocks[block]
            .block
            .attention
            .w_com
            .as_mut()
            .unwrap()
            .root[0] ^= 1;
        assert_eq!(
            verify_public_chain(&f.approved, &f.expected, &bad).unwrap_err(),
            format!("public chain block {block}: public receipt unapproved W root/shape")
        );
    }
    let mut a = f.approved[0].registration();
    a.attention_weights.root[0] ^= 1;
    let approved = [approve(a), approve(f.approved[1].registration())];
    assert!(verify_public_chain(&approved, &f.expected, &f.receipt).is_err());
    let expected = ExpectedPublicChain::new(
        &approved,
        f.expected.context(),
        f.expected.input(),
        f.expected.output(),
    )
    .unwrap();
    let mut bad = f.receipt.clone();
    relabel_requests(&mut bad, &approved, &expected);
    assert!(verify_public_chain_bytes(&approved, &expected, &bad.to_bytes().unwrap()).is_err());
}

#[test]
fn swapped_duplicate_and_changed_middle_receipts_refuse_even_after_relabelling() {
    let f = fixture();
    for case in 0..3 {
        let mut bad = f.receipt.clone();
        match case {
            0 => bad.blocks.swap(0, 1),
            1 => bad.blocks[1] = bad.blocks[0].clone(),
            _ => bad.intermediate[19] += 1,
        }
        assert!(verify_public_chain(&f.approved, &f.expected, &bad).is_err());
        relabel_requests(&mut bad, &f.approved, &f.expected);
        assert!(
            verify_public_chain_bytes(&f.approved, &f.expected, &bad.to_bytes().unwrap()).is_err()
        );
    }
}

#[test]
fn splicing_genuine_other_request_constituents_refuses_transcript_transplant() {
    let f = fixture();
    let other = ExpectedPublicChain::new(
        &f.approved,
        [62; 32],
        f.expected.input(),
        f.expected.output(),
    )
    .unwrap();
    let receipt = PublicChainOracle::new(&f.approved, f.weights.clone())
        .unwrap()
        .prove(&other)
        .unwrap();
    verify_public_chain(&f.approved, &other, &receipt).unwrap();
    for i in 0..2 {
        let mut spliced = f.receipt.clone();
        spliced.blocks[i] = receipt.blocks[i].clone();
        assert!(verify_public_chain(&f.approved, &f.expected, &spliced).is_err());
        relabel_requests(&mut spliced, &f.approved, &f.expected);
        assert_eq!(
            verify_public_chain_bytes(&f.approved, &f.expected, &spliced.to_bytes().unwrap())
                .unwrap_err(),
            format!("public chain block {i}: receipt attention argument")
        );
    }
}

#[test]
fn individually_valid_b4_receipts_with_inconsistent_actual_seam_cannot_compose() {
    let f = fixture();
    let mut second_input = f.receipt.intermediate;
    second_input[21] += 1;
    let b1 = FixedCausalOracle::new(&f.approved[1], f.weights[1].clone())
        .unwrap()
        .build(&second_input)
        .unwrap();
    let expected =
        ExpectedPublicChain::new(&f.approved, [63; 32], f.expected.input(), &output(&b1)).unwrap();
    let chain_requests = expected
        .block_expectations(&f.approved, &f.receipt.intermediate)
        .unwrap();
    let requests = [
        chain_requests[0].clone(),
        ExpectedPublicBlock::new(
            &f.approved[1],
            chain_requests[1].context(),
            &second_input,
            expected.output(),
        )
        .unwrap(),
    ];
    let blocks = [
        PublicReceiptOracle::new(&f.approved[0], f.weights[0].clone())
            .unwrap()
            .prove(&requests[0])
            .unwrap(),
        PublicReceiptOracle::new(&f.approved[1], f.weights[1].clone())
            .unwrap()
            .prove(&requests[1])
            .unwrap(),
    ];
    for i in 0..2 {
        // These are independently VALID complete B4 receipts, not just proofs
        // with valid component arithmetic under false endpoint expectations.
        verify_public_receipt(&f.approved[i], &requests[i], &blocks[i]).unwrap();
    }
    assert_ne!(requests[0].output(), requests[1].input());
    for (middle, failing_block) in [(f.receipt.intermediate, 1), (second_input, 0)] {
        let mut receipt = PublicChainReceipt {
            request_digest: expected.digest(),
            intermediate: middle,
            blocks: blocks.clone(),
        };
        assert_eq!(
            verify_public_chain_bytes(&f.approved, &expected, &receipt.to_bytes().unwrap())
                .unwrap_err(),
            format!("public chain block {failing_block}: public receipt request/approval mismatch")
        );
        relabel_requests(&mut receipt, &f.approved, &expected);
        assert_eq!(
            verify_public_chain_bytes(&f.approved, &expected, &receipt.to_bytes().unwrap())
                .unwrap_err(),
            format!("public chain block {failing_block}: receipt attention argument")
        );
    }
}

#[test]
fn original_b4_layer_zero_bytes_remain_frozen() {
    let f = fixture();
    let expected = ExpectedPublicBlock::new(
        &f.approved[0],
        [47; 32],
        f.expected.input(),
        &f.receipt.intermediate,
    )
    .unwrap();
    let receipt = PublicReceiptOracle::new(&f.approved[0], f.weights[0].clone())
        .unwrap()
        .prove(&expected)
        .unwrap();
    let bytes = receipt.to_bytes().unwrap();
    assert_eq!(bytes.len(), 2_144_946);
    use sha2::Digest;
    assert_eq!(
        hashline::silu::hex(&sha2::Sha256::digest(&bytes)),
        "ba5d82150b92e1ef4f58a29fe90fc65c756ac2f49c18f6df6b5de3f6f2fc6b94"
    );
}

/// Fresh genuine arithmetic/openings under deliberately false expectations.
/// Only the local endpoint comparison is omitted; the production verifier must
/// reject the actual committed boundary. No global/public override is installed.
fn actual_block_under_wrong_expectation(
    approved: &ApprovedP1BlockContract,
    expected: &ExpectedPublicBlock,
    b: &OracleBlock,
) -> PublicBlockReceipt {
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
fn freshly_recommitted_wrong_middle_reaches_both_actual_arithmetic_endpoint_refusals() {
    let f = fixture();
    let b0 = FixedCausalOracle::new(&f.approved[0], f.weights[0].clone())
        .unwrap()
        .build(f.expected.input())
        .unwrap();
    for bad_side in 0..2 {
        let mut wrong = output(&b0);
        wrong[17] += 1;
        let b1 = FixedCausalOracle::new(&f.approved[1], f.weights[1].clone())
            .unwrap()
            .build(&wrong)
            .unwrap();
        let middle: [i16; WORDS] = if bad_side == 0 {
            wrong.try_into().unwrap()
        } else {
            output(&b0).try_into().unwrap()
        };
        let expected = ExpectedPublicChain::new(
            &f.approved,
            [70 + bad_side as u8; 32],
            f.expected.input(),
            &output(&b1),
        )
        .unwrap();
        let requests = expected.block_expectations(&f.approved, &middle).unwrap();
        let first = if bad_side == 0 {
            actual_block_under_wrong_expectation(&f.approved[0], &requests[0], &b0)
        } else {
            PublicReceiptOracle::new(&f.approved[0], f.weights[0].clone())
                .unwrap()
                .prove(&requests[0])
                .unwrap()
        };
        let second = if bad_side == 1 {
            actual_block_under_wrong_expectation(&f.approved[1], &requests[1], &b1)
        } else {
            PublicReceiptOracle::new(&f.approved[1], f.weights[1].clone())
                .unwrap()
                .prove(&requests[1])
                .unwrap()
        };
        let receipt = PublicChainReceipt {
            request_digest: expected.digest(),
            intermediate: middle,
            blocks: [first, second],
        };
        let good_side = 1 - bad_side;
        verify_public_receipt(
            &f.approved[good_side],
            &requests[good_side],
            &receipt.blocks[good_side],
        )
        .unwrap();
        assert_eq!(
            verify_public_chain_bytes(&f.approved, &expected, &receipt.to_bytes().unwrap())
                .unwrap_err(),
            format!("public chain block {bad_side}: external public boundary")
        );
    }
}

fn read32(bytes: &[u8], at: usize) -> usize {
    u32::from_le_bytes(bytes[at..at + 4].try_into().unwrap()) as usize
}
fn set32(bytes: &mut [u8], at: usize, n: u32) {
    bytes[at..at + 4].copy_from_slice(&n.to_le_bytes());
}

#[test]
fn bounded_parser_rejects_missing_extra_counts_lengths_tags_and_truncation() {
    let f = fixture();
    let bytes = f.receipt.to_bytes().unwrap();
    let first_index = 48 + 2 * WORDS;
    let first_body = first_index + 8;
    let second_index = first_body + read32(&bytes, first_index + 4);
    for at in [
        40,
        44,
        first_index,
        first_index + 4,
        second_index,
        second_index + 4,
    ] {
        for value in [u32::MAX, 0, 3] {
            if read32(&bytes, at) == value as usize {
                continue;
            }
            let mut bad = bytes.clone();
            set32(&mut bad, at, value);
            assert!(
                std::panic::catch_unwind(|| PublicChainReceipt::from_bytes(&bad))
                    .unwrap()
                    .is_err()
            );
        }
    }
    for at in [0, 7, first_body, second_index + 8, bytes.len() - 1] {
        let mut bad = bytes.clone();
        bad[at] ^= 1;
        assert!(PublicChainReceipt::from_bytes(&bad).is_err());
    }
    let mut cuts: Vec<_> = (0..80).collect();
    cuts.extend([
        first_index,
        first_body,
        second_index,
        second_index + 8,
        bytes.len() / 2,
        bytes.len() - 1,
    ]);
    for cut in cuts {
        assert!(
            std::panic::catch_unwind(|| PublicChainReceipt::from_bytes(&bytes[..cut]))
                .unwrap()
                .is_err()
        );
        assert!(verify_public_chain_bytes(&f.approved, &f.expected, &bytes[..cut]).is_err());
    }
    let mut extra = bytes.clone();
    extra.push(0);
    assert!(PublicChainReceipt::from_bytes(&extra).is_err());
    let mut missing = bytes[..second_index].to_vec();
    missing.push(0xe5);
    assert!(PublicChainReceipt::from_bytes(&missing).is_err());
    assert!(PublicChainReceipt::from_bytes(&vec![0; MAX_CHAIN_BYTES + 1]).is_err());
    // Exact outer framing does not waive inner B4 canonical-field/count checks.
    let mut bad = bytes.clone();
    set32(&mut bad, first_body + 40, u32::MAX);
    assert!(PublicChainReceipt::from_bytes(&bad).is_err());
}

#[test]
fn honest_prover_refuses_wrong_output_or_unapproved_weights() {
    let f = fixture();
    let mut output = f.expected.output().to_vec();
    output[17] += 1;
    let wrong = ExpectedPublicChain::new(
        &f.approved,
        f.expected.context(),
        f.expected.input(),
        &output,
    )
    .unwrap();
    assert!(PublicChainOracle::new(&f.approved, f.weights.clone())
        .unwrap()
        .prove(&wrong)
        .is_err());
    let mut weights = f.weights.clone();
    weights[1].gamma_a[0] += 1;
    assert!(PublicChainOracle::new(&f.approved, weights).is_err());
}

#[test]
fn incompatible_runtime_policies_refuse_in_isolated_processes() {
    for case in ["compact", "tamper", "fold", "no_fold", "gpu_env"] {
        let output = std::process::Command::new(std::env::current_exe().unwrap())
            .args(["--exact", "runtime_policy_child", "--test-threads=1"])
            .env("ZK60_B5_POLICY_CHILD", case)
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
    let Ok(case) = std::env::var("ZK60_B5_POLICY_CHILD") else {
        return;
    };
    let f = fixture();
    let bytes = f.receipt.to_bytes().unwrap();
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
        _ => panic!("unknown policy"),
    }
    assert!(PublicChainOracle::new(&f.approved, f.weights.clone()).is_err());
    assert!(verify_public_chain_bytes(&f.approved, &f.expected, &bytes).is_err());
}
