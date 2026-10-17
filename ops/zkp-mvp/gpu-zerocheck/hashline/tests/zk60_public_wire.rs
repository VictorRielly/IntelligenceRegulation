//! Canonical public-fixture transport tests; no private proof or GPU.
#![cfg(not(feature = "gpu-cuda"))]
use hashline::causal_oracle::public_synthetic_fixture;
use hashline::field::{Fp, Fp2, P};
use hashline::pcs_compact::BatchOpening;
use hashline::public_block_oracle::{verify_public_block, PublicBlockOracle, PublicBlockProof};
use hashline::public_block_wire::{
    decode_components, encode_components, validate_structure, MAX_WIRE_BYTES,
};
use std::sync::OnceLock;

fn fixture() -> &'static PublicBlockProof {
    static PROOF: OnceLock<PublicBlockProof> = OnceLock::new();
    PROOF.get_or_init(|| {
        assert!(std::env::var("HL_GPU").unwrap_or_default().is_empty());
        assert!(std::env::var("HL_FOLD").unwrap_or_default().is_empty());
        assert!(std::env::var("HL_NO_FOLD").unwrap_or_default().is_empty());
        let (approved, weights, input) = public_synthetic_fixture();
        PublicBlockOracle::new(&approved, weights)
            .unwrap()
            .prove(&input)
            .unwrap()
    })
}
fn bytes() -> Vec<u8> {
    encode_components(fixture()).unwrap()
}
fn set32(b: &mut [u8], at: usize, value: u32) {
    b[at..at + 4].copy_from_slice(&value.to_le_bytes());
}
fn read32(b: &[u8], at: usize) -> usize {
    u32::from_le_bytes(b[at..at + 4].try_into().unwrap()) as usize
}
fn skip_vec(b: &[u8], at: &mut usize, width: usize) {
    *at += 4 + width * read32(b, *at);
}
fn skip_sc(b: &[u8], at: &mut usize) {
    let n = read32(b, *at);
    *at += 4;
    for _ in 0..n {
        skip_vec(b, at, 16);
    }
}
/// Locate fields in a KNOWN GOOD test fixture only; never used as decoder bounds.
fn offsets(b: &[u8]) -> Vec<usize> {
    let mut at = 49 + 3 * 38;
    let mut out = vec![82, at, at + 4 + 8]; // commitment rows, table count/rows
    let n = read32(b, at);
    at += 4;
    for _ in 0..n {
        at += 8;
        skip_vec(b, &mut at, 4);
    }
    out.push(at); // attention value count
    skip_vec(b, &mut at, 16);
    out.push(at); // SC count
    let n = read32(b, at);
    at += 4;
    out.push(at); // first SC round count
    out.push(at + 4); // first round width
    for _ in 0..n {
        skip_sc(b, &mut at);
    }
    out.push(at); // unused attention helper_sums count
    skip_vec(b, &mut at, 16);
    out.push(at); // collapse count
    let n = read32(b, at);
    at += 4;
    for _ in 0..n {
        skip_sc(b, &mut at);
        at += 16;
    }
    assert_eq!(b[at], 0xb1);
    at += 1;
    out.push(at); // group count
    let n = read32(b, at);
    at += 4;
    out.push(at); // first group vector length
    for _ in 0..n {
        skip_vec(b, &mut at, 16);
    }
    out.push(at); // proximity length
    skip_vec(b, &mut at, 16);
    out.push(at); // column count
    at += 4;
    out.push(at); // column index
    at += 4;
    out.push(at); // column value count
    skip_vec(b, &mut at, 8);
    out.push(at); // Merkle path length
    out
}

#[test]
fn complete_roundtrip_preserves_every_component_and_verifies() {
    let proof = fixture();
    validate_structure(proof).unwrap();
    let encoded = bytes();
    let decoded = decode_components(&encoded).unwrap();
    assert_eq!(encoded, encode_components(&decoded).unwrap());
    assert_eq!(proof.contract_digest, decoded.contract_digest);
    assert_eq!(proof.attention.to_bytes(), decoded.attention.to_bytes());
    assert_eq!(proof.ffn.to_bytes(), decoded.ffn.to_bytes());
    // Also compare the typed structure so legacy length ambiguity cannot hide loss.
    assert_eq!(format!("{proof:?}"), format!("{decoded:?}"));
    let (approved, _, _) = public_synthetic_fixture();
    verify_public_block(&approved, &decoded).unwrap();
    println!(
        "B4 wire v1 public T32: bytes={} blake3={} legacy_payload={}",
        encoded.len(),
        blake3::hash(&encoded).to_hex(),
        proof.payload_size_bytes()
    );
}

#[test]
fn receipt_extra_claim_slots_are_preserved_not_treated_as_verification() {
    let mut p = fixture().clone();
    p.attention.vals.extend([Fp2::ONE, Fp2::U]);
    let decoded = decode_components(&encode_components(&p).unwrap()).unwrap();
    assert_eq!(decoded.attention.vals, p.attention.vals);
    assert_eq!(decoded.attention.vals.len(), 135);
    let (approved, _, _) = public_synthetic_fixture();
    // Appending claims does not create a valid receipt/B3 proof.
    assert!(verify_public_block(&approved, &decoded).is_err());
}

#[test]
fn header_backend_section_and_eof_tags_are_strict() {
    let original = bytes();
    let ffn_tag = 49 + read32(&original, 45);
    for at in [
        0,
        8,
        10,
        11,
        44,
        49,
        ffn_tag,
        original.len() - 2,
        original.len() - 1,
    ] {
        let mut bad = original.clone();
        bad[at] ^= 1;
        assert!(decode_components(&bad).is_err(), "changed tag at {at}");
    }
    let mut appended = original.clone();
    appended.push(0);
    assert!(decode_components(&appended).is_err());
    let mut bad = original.clone();
    set32(&mut bad, 45, u32::MAX);
    assert!(decode_components(&bad).is_err());
    let mut bad = original.clone();
    set32(&mut bad, 45, 0);
    assert!(decode_components(&bad).is_err());
    let mut bad = original.clone();
    set32(&mut bad, 45, read32(&original, 45) as u32 - 1);
    assert!(decode_components(&bad).is_err());
    assert!(decode_components(&vec![0; MAX_WIRE_BYTES + 1]).is_err());
}

#[test]
fn nested_counts_reject_before_unbounded_allocation() {
    let original = bytes();
    for at in offsets(&original) {
        let mut bad = original.clone();
        set32(&mut bad, at, u32::MAX);
        let result = std::panic::catch_unwind(|| decode_components(&bad));
        assert!(result.is_ok() && result.unwrap().is_err(), "count at {at}");
    }
}

#[test]
fn truncation_at_headers_nested_fields_and_tail_refuses_without_panic() {
    let original = bytes();
    let mut cuts: Vec<usize> = (0..180).collect();
    cuts.extend(offsets(&original));
    cuts.extend((1..=32).map(|n| original.len() - n));
    cuts.extend((2048..original.len()).step_by(131071));
    for cut in cuts {
        let result = std::panic::catch_unwind(|| decode_components(&original[..cut]));
        assert!(result.is_ok() && result.unwrap().is_err(), "prefix {cut}");
    }
}

#[test]
fn noncanonical_base_and_extension_fields_are_not_reduced() {
    let original = bytes();
    let positions = offsets(&original);
    let first_fp2 = positions[3] + 4;
    let first_column_fp = positions[14] + 4;
    for at in [first_fp2, first_fp2 + 8, first_column_fp] {
        for word in [P, u64::MAX] {
            let mut bad = original.clone();
            bad[at..at + 8].copy_from_slice(&word.to_le_bytes());
            assert!(decode_components(&bad).is_err());
        }
    }
    let mut bad = fixture().clone();
    bad.ffn.zcd_term[0].c1 = Fp(P);
    assert!(validate_structure(&bad).is_err());
    assert!(encode_components(&bad).is_err());
    let mut changed = fixture().clone();
    changed.attention.vals[0] = Fp2::new(Fp(P - 1), Fp::ZERO);
    let decoded = decode_components(&encode_components(&changed).unwrap()).unwrap();
    assert_eq!(decoded.attention.vals[0].c0.0, P - 1);
}

#[test]
fn unsupported_compact_missing_unused_and_shape_fields_refuse() {
    let mut bad = fixture().clone();
    bad.ffn.cpcs_open = Some(BatchOpening::default());
    assert!(encode_components(&bad).is_err());
    let mut bad = fixture().clone();
    bad.attention.helper_sums.push(Fp2::ZERO);
    assert!(encode_components(&bad).is_err());
    let mut bad = fixture().clone();
    bad.ffn.helper_sums.pop();
    assert!(encode_components(&bad).is_err());
    let mut bad = fixture().clone();
    bad.attention.sc.push(Default::default());
    assert!(encode_components(&bad).is_err());
    let mut bad = fixture().clone();
    bad.attention.collapse.clear();
    assert!(encode_components(&bad).is_err());
    let mut bad = fixture().clone();
    bad.attention.w_com = None;
    assert!(encode_components(&bad).is_err());
    let mut bad = fixture().clone();
    bad.ffn.a_com.as_mut().unwrap().rows = usize::MAX;
    assert!(encode_components(&bad).is_err());
    let mut bad = fixture().clone();
    bad.attention.h_open.columns[0].2.pop();
    assert!(encode_components(&bad).is_err());
}

#[test]
fn table_order_duplicates_and_excessive_multiplicities_are_rejected() {
    let mut bad = fixture().clone();
    bad.attention.mults.swap(0, 1);
    assert!(encode_components(&bad).is_err());
    let mut bad = fixture().clone();
    bad.ffn.mults[1].0 = bad.ffn.mults[0].0;
    assert!(encode_components(&bad).is_err());
    let mut bad = fixture().clone();
    bad.ffn.mults[0].1[0] = u32::MAX;
    assert!(encode_components(&bad).is_err());
    let original = bytes();
    let mut bad = original.clone();
    bad[167..175].copy_from_slice(&0u64.to_le_bytes());
    assert!(decode_components(&bad).is_err());
}
