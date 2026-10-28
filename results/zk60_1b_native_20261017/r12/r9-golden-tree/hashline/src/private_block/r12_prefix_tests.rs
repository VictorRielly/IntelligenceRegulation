//! **NATIVE R12: the failing-first record.** The R12 assertions written
//! against the R9 tree's own API (this file lives only in the recording copy
//! `r12/r9-golden-tree/`): each must FAIL here, on R9, and its R12 form in
//! `r12_tests.rs` passes on R12. TEST CODE ONLY.

use super::layout::*;
use super::shape::*;

/// F2: a shape whose query axis (8 x 64 = 512) is wider than its padded
/// model axis (256) builds. R9 refuses it ("d_pad differs from h_pad *
/// head_dim").
#[test]
fn r12_prefix_f2_a_decoupled_shape_builds() {
    let rows = ((32 * 256) >> 10) + super::endpoint_g::MASK_ROWS;
    let r = Shape::new("decoupled rung (prefix test)", "unregistered-dev-twin/private-block-rung-hd-prefix/1", 32, 192, 384, 8, 64, 2, 10, 4, 12, rows, None, None, None, None);
    assert!(r.is_ok(), "R9 refuses the decoupled shape: {:?}", r.err());
}

/// F2: the independent kernel takes Shieldstral's geometry (d 3072, 32 heads
/// of 128). R9's kernel refuses it ("width differs from q_heads *
/// head_dim").
#[test]
fn r12_prefix_f2_the_kernel_takes_shieldstral() {
    let k = private_block_kernel_shaped::Shape::new(128, 3072, 9216, 32, 8, 128, 9, 9, 16, 32);
    assert!(k.check().is_ok(), "R9's kernel refuses Shieldstral's geometry: {:?}", k.check().err());
}

/// F1: the RoPE tables at Shieldstral's base are the transformers YaRN
/// reference's (r12/rope_reference.json). R9's only generator is the
/// unscaled one, whose table differs (sha256 fd6f2e08...).
#[test]
fn r12_prefix_f1_the_shieldstral_tables_are_yarn() {
    use sha2::{Digest as _, Sha256};
    let (c, s) = crate::tables_attn::rope_tables_generate(512, 128, 1_000_000.0, F_RO);
    let mut h = Sha256::new();
    for v in c.iter().chain(s.iter()) {
        h.update(v.to_le_bytes());
    }
    let got: String = h.finalize().iter().map(|b| format!("{b:02x}")).collect();
    assert_eq!(got, "261b32b8e461fa3866ee98455b3a4b39db51d846833115f525809c8375e12a5f", "R9's tables at theta 1e6 are not the YaRN reference");
}

/// F3: a Shieldstral profile exists and pins its tied tensor. R9 registers
/// no such profile and its statement has no field that binds an embedding or
/// head table (the R12 test `f3_a_tied_statement_binds_both_tables_to_the_
/// one_tensor` does not compile against R9).
#[test]
fn r12_prefix_f3_a_tied_profile_is_registered() {
    let shieldstral = TRAINED_CALIBRATION_PROFILES.iter().any(|p| p.contains("shieldstral"));
    assert!(shieldstral, "R9 registers no Shieldstral (tied) profile");
}
