//! Shared CPU proof primitives, extracted mechanically from hashline.
//!
//! The first migration contains arithmetic, transforms, Merkle trees,
//! transcripts, randomness, multilinear helpers and sumcheck; the second
//! adds the Ligero-form polynomial commitment (`pcs`: CPU commit / open /
//! verify in the plain and the hiding form) behind a narrow backend seam
//! (`pcs::Backend`) that an accelerator outside this crate may implement.
//! It does not yet contain a complete FFN prover or a bounded codec.
//! Inherited masking helpers retain the legacy protocol's unresolved privacy
//! obligations; moving them here is not a security review or repair.

pub mod field;
pub mod merkle;
pub mod mle;
pub mod ntt;
pub mod pcs;
pub mod rng;
pub mod sumcheck;
pub mod transcript;
