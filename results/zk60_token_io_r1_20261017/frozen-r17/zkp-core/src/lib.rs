//! Shared CPU proof primitives, extracted mechanically from hashline.
//!
//! The first migration contains arithmetic, transforms, Merkle trees,
//! transcripts, randomness, multilinear helpers and sumcheck; the second
//! adds the Ligero-form polynomial commitment (`pcs`: CPU commit / open /
//! verify in the plain and the hiding form) behind a narrow backend seam
//! (`pcs::Backend`) that an accelerator outside this crate may implement.
//! The third adds the frozen activation-table registry (`tables`) and the
//! typed pieces of the selected profile (`ffn_v3`: statement, parameters,
//! layout, the proof object with its frozen encoding and a shape-directed
//! bounded decoder). It does not yet contain the FFN prover or verifier.
//! Inherited masking helpers retain the legacy protocol's unresolved privacy
//! obligations; moving them here is not a security review or repair.

pub mod ffn_v3;
pub mod field;
/// [ZK60 D19, ruling T-1] the separating hash tag: BLAKE3's keyed mode, one
/// public key per hash domain, derived from a profile string. Additive: the
/// legacy unkeyed rule is the default and every existing function keeps its
/// body.
pub mod hashtag;
pub mod merkle;
pub mod mle;
pub mod ntt;
pub mod pcs;
pub mod rng;
pub mod sumcheck;
pub mod tables;
pub mod transcript;
