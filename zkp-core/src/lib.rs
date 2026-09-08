//! Shared CPU proof primitives, extracted mechanically from hashline.
//!
//! This first migration contains arithmetic, transforms, Merkle trees,
//! transcripts, randomness, multilinear helpers and sumcheck. It does not
//! yet contain a complete FFN prover, commitment opening or bounded codec.
//! Inherited masking helpers retain the legacy protocol's unresolved privacy
//! obligations; moving them here is not a security review or repair.

pub mod field;
pub mod merkle;
pub mod mle;
pub mod ntt;
pub mod rng;
pub mod sumcheck;
pub mod transcript;
