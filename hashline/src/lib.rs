//! hashline — U-PERF3 lane UU: a hash-based, small-prime-field prover and
//! verifier for the exact int8 125M FFN statement (12 layers x 512
//! tokens) the lattice engine proves, built as the comparison row of
//! docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md section 3.
//!
//! Stack: Goldilocks F_p with a degree-2 extension for challenges; a
//! Ligero/Brakedown-class multilinear commitment (rows Reed-Solomon
//! encoded via NTT, blake3 Merkle over columns); the matrix-multiplication
//! sumcheck for the matmuls; LogUp lookups (committed helper columns +
//! zero-checks) for the SiLU table and every range/requant fact;
//! zero-check sumchecks for the Hadamard/requant identities; Fiat-Shamir
//! over blake3.

pub mod field;
pub mod ntt;
pub mod merkle;
pub mod transcript;
pub mod silu;
pub mod export;
pub mod chain;
pub mod mle;
pub mod sumcheck;
pub mod pcs;
pub mod layer;
pub mod gpu;
// [UPERF3-ZB] the widened-stack (v3) profile: the frozen int16-out table
// families, the m8b v3 export reader + exact chain; the v3 statement lives
// in layer.rs (additive) behind `--profile v3`.
pub mod tables_v3;
pub mod export_v3;
