//! Backend-agnostic claim manifest for multi-operation proof DAGs.
//!
//! Specification: `docs/zkmatrix-poc/CLAIM_MANIFEST.md`. This module is the
//! minimal concrete realization used by both proof backends. It is shared by
//! `#[path]` inclusion from each binary (the crate is a collection of
//! stand-alone bins, so a library target is deliberately avoided; the module
//! has no backend dependencies beyond `sha2`).
//!
//! The manifest binds, in a fixed serialization order:
//!
//! 1. a protocol/version tag and a backend tag,
//! 2. the backend setup digest (SRS or CRS digest),
//! 3. every commitment entry: id, role label, shape, orientation, backend
//!    key info (e.g. SRS window offset), and the commitment bytes,
//! 4. the operation list (matmul claims, link claims, class-0 homomorphic
//!    operations recorded proof-free).
//!
//! Transcript-ordering rule: the manifest digest is computed after every
//! commitment in the DAG is fixed, and it is absorbed into every Fiat-Shamir
//! challenge of every claim and gadget proven against the manifest. No
//! challenge may be derived before the digest is available, which enforces
//! "all commitments enter the statement hash before any challenge".

#![allow(dead_code)]

use sha2::{Digest, Sha256};

pub const MANIFEST_VERSION: &str = "zkmatrix-claim-manifest-v1";

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Orientation {
    /// One commitment to the row-major flattening (pairing track windows).
    RowMajor,
    /// One commitment per matrix row (lattice track, left operands).
    ByRows,
    /// One commitment per matrix column (lattice track, right operands and
    /// outputs).
    ByColumns,
}

impl Orientation {
    fn tag(self) -> u8 {
        match self {
            Orientation::RowMajor => 0,
            Orientation::ByRows => 1,
            Orientation::ByColumns => 2,
        }
    }
}

#[derive(Clone, Debug)]
pub struct CommitmentEntry {
    pub id: u32,
    /// Human-readable role label ("X", "W1", "Y#cols", ...). Bound by hash.
    pub label: String,
    pub rows: u32,
    pub cols: u32,
    pub orientation: Orientation,
    /// Backend key binding: SRS window offset for the pairing track, message
    /// dimension / commitment-count data for the lattice track.
    pub key_info: Vec<u8>,
    /// Serialized commitment: compressed G1 point (pairing track) or a
    /// SHA-256 digest of the per-column/per-row commitment group (lattice
    /// track).
    pub commitment_bytes: Vec<u8>,
}

#[derive(Clone, Debug)]
pub enum Operation {
    /// A committed matrix-multiplication claim C = A B over entry ids.
    Matmul { a: u32, b: u32, c: u32 },
    /// Commitment-equality link between two entries holding the same matrix
    /// under different base families (pairing track chaining gadget).
    LinkEqual { left: u32, right: u32 },
    /// Transpose-consistency link between a by-rows entry and a by-columns
    /// entry holding the same matrix (lattice track chaining gadget).
    LinkTranspose { by_rows: u32, by_cols: u32 },
    /// Class-0 homomorphic operation: recorded but proof-free. The verifier
    /// recomputes `output`'s commitment from the inputs' commitments.
    Add { inputs: Vec<u32>, output: u32 },
    /// Class-0 public scalar scaling, recorded proof-free.
    Scale { input: u32, output: u32, scalar_le: Vec<u8> },
    /// Elementwise product claim Z = X o Y over entry ids (Class 3).
    Hadamard { x: u32, y: u32, z: u32 },
    /// Binary constraint B o B = B on a (packed) bit entry.
    Binary { bits: u32 },
    /// Range recomposition: `value` equals the width-bit recomposition of
    /// the per-column packed `bits` entry (signed uses the 2^{width-1}
    /// offset convention).
    Range { value: u32, bits: u32, width: u32, signed: bool },
    /// Rescale-with-rounding link: x = 2^shift * y + r, proven by a
    /// zero-opening on the combined difference; the ranges on r and y are
    /// separate Range operations.
    Rescale { x: u32, y: u32, r: u32, shift: u32 },
}

#[derive(Clone, Debug, Default)]
pub struct ClaimManifest {
    /// Backend tag, e.g. "structured-bls12381" or "lattice-route-z".
    pub backend: String,
    /// Backend setup digest (SRS digest / CRS hash).
    pub setup_digest: Vec<u8>,
    pub commitments: Vec<CommitmentEntry>,
    pub operations: Vec<Operation>,
}

fn absorb_bytes(hasher: &mut Sha256, bytes: &[u8]) {
    hasher.update((bytes.len() as u64).to_le_bytes());
    hasher.update(bytes);
}

impl ClaimManifest {
    pub fn new(backend: &str, setup_digest: &[u8]) -> Self {
        ClaimManifest {
            backend: backend.to_string(),
            setup_digest: setup_digest.to_vec(),
            commitments: Vec::new(),
            operations: Vec::new(),
        }
    }

    pub fn add_commitment(
        &mut self,
        label: &str,
        rows: usize,
        cols: usize,
        orientation: Orientation,
        key_info: Vec<u8>,
        commitment_bytes: Vec<u8>,
    ) -> u32 {
        let id = self.commitments.len() as u32;
        self.commitments.push(CommitmentEntry {
            id,
            label: label.to_string(),
            rows: rows as u32,
            cols: cols as u32,
            orientation,
            key_info,
            commitment_bytes,
        });
        id
    }

    pub fn add_operation(&mut self, operation: Operation) {
        self.operations.push(operation);
    }

    /// Order-sensitive digest of the whole manifest. Absorbed into every
    /// Fiat-Shamir challenge of every claim proven against this manifest.
    pub fn digest(&self) -> [u8; 32] {
        let mut hasher = Sha256::new();
        absorb_bytes(&mut hasher, MANIFEST_VERSION.as_bytes());
        absorb_bytes(&mut hasher, self.backend.as_bytes());
        absorb_bytes(&mut hasher, &self.setup_digest);
        hasher.update((self.commitments.len() as u64).to_le_bytes());
        for entry in &self.commitments {
            hasher.update(entry.id.to_le_bytes());
            absorb_bytes(&mut hasher, entry.label.as_bytes());
            hasher.update(entry.rows.to_le_bytes());
            hasher.update(entry.cols.to_le_bytes());
            hasher.update([entry.orientation.tag()]);
            absorb_bytes(&mut hasher, &entry.key_info);
            absorb_bytes(&mut hasher, &entry.commitment_bytes);
        }
        hasher.update((self.operations.len() as u64).to_le_bytes());
        for operation in &self.operations {
            match operation {
                Operation::Matmul { a, b, c } => {
                    hasher.update([1u8]);
                    hasher.update(a.to_le_bytes());
                    hasher.update(b.to_le_bytes());
                    hasher.update(c.to_le_bytes());
                }
                Operation::LinkEqual { left, right } => {
                    hasher.update([2u8]);
                    hasher.update(left.to_le_bytes());
                    hasher.update(right.to_le_bytes());
                }
                Operation::LinkTranspose { by_rows, by_cols } => {
                    hasher.update([3u8]);
                    hasher.update(by_rows.to_le_bytes());
                    hasher.update(by_cols.to_le_bytes());
                }
                Operation::Add { inputs, output } => {
                    hasher.update([4u8]);
                    hasher.update((inputs.len() as u64).to_le_bytes());
                    for input in inputs {
                        hasher.update(input.to_le_bytes());
                    }
                    hasher.update(output.to_le_bytes());
                }
                Operation::Scale {
                    input,
                    output,
                    scalar_le,
                } => {
                    hasher.update([5u8]);
                    hasher.update(input.to_le_bytes());
                    hasher.update(output.to_le_bytes());
                    absorb_bytes(&mut hasher, scalar_le);
                }
                Operation::Hadamard { x, y, z } => {
                    hasher.update([6u8]);
                    hasher.update(x.to_le_bytes());
                    hasher.update(y.to_le_bytes());
                    hasher.update(z.to_le_bytes());
                }
                Operation::Binary { bits } => {
                    hasher.update([7u8]);
                    hasher.update(bits.to_le_bytes());
                }
                Operation::Range {
                    value,
                    bits,
                    width,
                    signed,
                } => {
                    hasher.update([8u8]);
                    hasher.update(value.to_le_bytes());
                    hasher.update(bits.to_le_bytes());
                    hasher.update(width.to_le_bytes());
                    hasher.update([*signed as u8]);
                }
                Operation::Rescale { x, y, r, shift } => {
                    hasher.update([9u8]);
                    hasher.update(x.to_le_bytes());
                    hasher.update(y.to_le_bytes());
                    hasher.update(r.to_le_bytes());
                    hasher.update(shift.to_le_bytes());
                }
            }
        }
        hasher.finalize().into()
    }
}
