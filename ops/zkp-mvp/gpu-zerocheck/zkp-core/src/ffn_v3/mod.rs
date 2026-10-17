//! The selected profile of the maintained core: the non-hiding v3 FFN
//! layer proof (`hashline pass --profile v3`; frozen 12 x 512 digest
//! `5f368db6…`, 70,758,084 B). Privacy class P0: W, A and H are committed
//! but nothing is hidden; it is attested computation over a committed
//! witness, not zero-knowledge.
//!
//! Round 12 moves the typed pieces: the statement, parameters and layout
//! ([`statement`]) and the proof object with its frozen encoding and a
//! shape-directed bounded decoder ([`proof`]). The prover and verifier
//! (`hashline::layer::{prove_layer_v3, verify_layer_v3}`) still live in
//! hashline and consume these types through re-exports; see
//! `MIGRATION.md`, "The next step in detail", for what blocks their move.

pub mod proof;
pub mod statement;

pub use proof::{DecodeError, ExtraOpening, NoExtra, OpeningShape, Proof, Shape, MATMUL_DEGREE, ZEROCHECK_DEGREE};
pub use statement::{
    absorb_com, absorb_mults, absorb_statement, pow2_signed, rem_index, rem_rows, rem_value, tag_rem_v3, Layout, Params, Statement,
    TAG_ACT16, TAG_INT16,
};

/// The transcript domain of one layer proof (`hashline layer`).
pub const DOMAIN_LAYER: &[u8] = b"hashline-layer-v3";
/// The transcript domain of the twelve-layer pass (`hashline pass`).
pub const DOMAIN_PASS: &[u8] = b"hashline-pass-v3";
