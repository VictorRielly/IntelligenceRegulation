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
// [UPERF3-AF] the compact (BaseFold-class FRI) multilinear commitment behind
// `--pcs compact`: the same Claim/Commitment interface as pcs.rs, one batched
// opening per layer. The Ligero form of pcs.rs stays the DEFAULT and byte-identical.
pub mod pcs_compact;
pub mod layer;
pub mod gpu;
// [UPERF3-ZB] the widened-stack (v3) profile: the frozen int16-out table
// families, the m8b v3 export reader + exact chain; the v3 statement lives
// in layer.rs (additive) behind `--profile v3`.
pub mod tables_v3;
pub mod export_v3;
pub mod zk;
// Opt-in single-layer P1 approval boundary; does not change existing verifier calls.
pub mod model_identity;
// Durable public slot journal only; does not enable stable P3 proofs.
pub mod stable_weight_slots;
// Opt-in encrypted registration material; does not enable a stable P3 prover.
#[cfg(feature = "stable-weight-storage")]
pub mod stable_weight_material;
// Experimental one-shot private equality gadget; not integrated into full blocks.
pub mod private_seam;
pub mod phase_profile;
pub mod causal_oracle;
// Public P0 arithmetic validation only; does not satisfy the P1 block policy.
pub mod public_block_oracle;
// Experimental public-only bounded wire and external-I/O receipt profile.
pub mod public_block_wire;
pub mod public_block_receipt;
pub mod public_chain_receipt;
// Opt-in public execution metadata; not a private-proof security inventory.
pub mod attention_schedule;
// Fixed-calibration metadata preflight; not a private-block verifier.
pub mod private_block_contract;
// [UPERF3-AC] the per-model weight-commitment cache (`--wcache DIR`); the
// chunked device encoding lives in gpu/.
pub mod wcache;
// [UPERF3-AE] the attention half of the layer: the exp / rope table
// members and LogUp tags, the RMSNorm gadget, the attention chain + the
// full-layer prover behind `--attn`.
pub mod tables_attn;
pub mod norm;
pub mod attention;
