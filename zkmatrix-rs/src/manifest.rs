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
    /// Bias-broadcast consistency link: the `broadcast` entry's column j is
    /// `bias_j * ones` for the single-column `bias` entry. Proven by one
    /// batched scalar-link per repetition (M3); the subsequent bias add is a
    /// Class-0 `Add` over the broadcast entry.
    BiasBroadcast { bias: u32, broadcast: u32 },
    /// Elementwise activation through the statement's frozen lookup table
    /// (the header's `table_digest` — ring/lookup.rs `table_spec_digest`):
    /// y_t = table[x_t] for every element. Membership of x in the table
    /// DOMAIN is part of the lookup claim, so a Lookup also serves as the
    /// range fact for its input (LogUp-GKR engine, M4).
    Lookup { x: u32, y: u32 },
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
                Operation::BiasBroadcast { bias, broadcast } => {
                    hasher.update([10u8]);
                    hasher.update(bias.to_le_bytes());
                    hasher.update(broadcast.to_le_bytes());
                }
                Operation::Lookup { x, y } => {
                    hasher.update([11u8]);
                    hasher.update(x.to_le_bytes());
                    hasher.update(y.to_le_bytes());
                }
            }
        }
        hasher.finalize().into()
    }
}

// ===========================================================================
// The versioned, VALIDATED statement format (audit 2026-07-10 finding C-02).
//
// A `ClaimManifest` binds caller-supplied entries and operations by hash but
// never checks them: dangling ids, incompatible shapes, flipped orientations,
// missing range facts, or tensors that silently drop out of the DAG all hash
// fine. `Statement` wraps a manifest with (1) a versioned header carrying the
// model identity digest and the activation-table digest, (2) per-tensor
// quantization metadata, (3) the declared statement outputs — and refuses to
// form a digest until `validate()` passes. Every check returns a structured
// `StatementError`; nothing here panics on malformed input.
//
// Validation model (documented once, enforced below):
//
// - Entry ids must be dense (entry k has id k) and shapes non-empty.
// - Every id an operation references must exist.
// - Matmul C = A B: A.cols == B.rows, C.rows == A.rows, C.cols == B.cols;
//   orientation discipline is either all-RowMajor (pairing track) or
//   A ByRows, B and C ByColumns (lattice tracks).
// - Elementwise operations (Rescale, Hadamard, Add, Scale, LinkEqual)
//   require equal shapes and orientations. LinkTranspose requires equal
//   shapes with the ByRows/ByColumns orientation pair. BiasBroadcast
//   requires a single-column bias with bias.rows == broadcast.cols.
// - Range facts use the STACKED plane convention (the lattice ffn-demo
//   layout): the `bits` entry holds `width` bit planes stacked row-wise,
//   so bits.rows == width * value.rows and bits.cols == value.cols, and
//   the stack must be covered by a Binary operation.
// - Every Rescale remainder r must be covered by a Range fact of width
//   `shift`, unsigned — a rescale without it is exactly the q31 wraparound
//   hole the audit flagged.
// - Quantization metadata (bit width, fraction bits, signedness) must be
//   present for every entry and consistent across operations: magnitude
//   bounds compose (matmul accumulators cover max_a * max_b * inner,
//   Hadamard products cover max_x * max_y, sums cover the sum of maxima),
//   fraction bits add over products and drop by `shift` over rescales,
//   and signedness propagates. Magnitude bound of a tensor: 2^bits - 1
//   unsigned, 2^(bits-1) signed (the offset convention's worst case).
// - Calibrated requantization: a Rescale output declared narrower than
//   the worst case is accepted only when the narrowing is itself proven —
//   a Range fact of the declared width on the output, or a Lookup
//   consuming it (table-domain membership). Lookup operands must match
//   the frozen int8 activation-table quantization.
// - Every committed tensor must be READ by at least one operation or be
//   declared an output; a tensor only ever WRITTEN (produced) must be a
//   declared output. Outputs must exist, be produced, and not repeat.
//   (Multiple producers for one id are allowed: each producing operation
//   is one more claim over the same commitment, which over-determines but
//   never weakens the statement.)
//
// The validator is backend-agnostic: modulus-specific non-wrap budgets
// (e.g. "the declared accumulator width fits under q31/2") are asserted by
// the proving layer against the SAME declared widths this validator pins.

/// Statement format version. v2 = the first validated format; the bare
/// hash-only manifest above is retroactively "v1". Unknown versions reject.
pub const STATEMENT_VERSION: u32 = 2;
const STATEMENT_TAG: &str = "zkmatrix-statement-v2";

/// Per-tensor quantization metadata: integer bit width, fixed-point
/// fraction bits, signedness. `bits` counts the full two's-complement
/// width when signed (values in [-2^(bits-1), 2^(bits-1))).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct QuantMeta {
    pub bits: u32,
    pub frac_bits: u32,
    pub signed: bool,
}

impl QuantMeta {
    /// Worst-case magnitude of any element (unsigned: 2^bits - 1;
    /// signed: 2^(bits-1), the offset convention's extreme).
    fn max_abs(&self) -> u128 {
        if self.signed {
            1u128 << (self.bits - 1)
        } else {
            (1u128 << self.bits) - 1
        }
    }
}

/// The statement header: format version, the identity digest of the exact
/// quantized model being claimed (weights + architecture + quantization
/// spec), and the activation-table digest (ring/lookup.rs
/// `table_spec_digest` — the frozen integer activation semantics).
#[derive(Clone, Copy, Debug)]
pub struct StatementHeader {
    pub version: u32,
    pub model_digest: [u8; 32],
    pub table_digest: [u8; 32],
}

/// A validated proof statement: header + manifest + per-entry quantization
/// metadata (`quant[i]` describes entry id i) + declared outputs.
#[derive(Clone, Debug)]
pub struct Statement {
    pub header: StatementHeader,
    pub manifest: ClaimManifest,
    pub quant: Vec<QuantMeta>,
    pub outputs: Vec<u32>,
}

/// Structured validation errors. `op` fields are indices into
/// `manifest.operations`; `id` fields are commitment entry ids.
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum StatementError {
    /// Header version is not STATEMENT_VERSION.
    UnknownVersion { got: u32 },
    /// Model identity digest is unset (all zero).
    MissingModelDigest,
    /// Activation-table digest is unset (all zero).
    MissingTableDigest,
    /// Entry k's id is not k (ids must be dense and ordered).
    NonDenseIds { index: usize, id: u32 },
    /// Zero rows or columns.
    EmptyShape { id: u32 },
    /// quant.len() != number of commitment entries.
    QuantCount { entries: usize, quants: usize },
    /// Nonsensical quantization metadata (bits outside 1..=64, or
    /// frac_bits > bits).
    BadQuant { id: u32 },
    /// An operation references a commitment id that does not exist.
    DanglingId { op: usize, id: u32 },
    /// Matmul dimensions do not chain (A.cols == B.rows, C = A.rows x B.cols).
    MatmulShape { op: usize, a: u32, b: u32, c: u32 },
    /// Matmul orientation discipline violated (all RowMajor, or A ByRows
    /// with B and C ByColumns).
    MatmulOrientation { op: usize, id: u32 },
    /// Two operands that must have identical shapes differ.
    ShapeMismatch { op: usize, left: u32, right: u32 },
    /// Two operands that must share an orientation differ (or the
    /// LinkTranspose / bias-broadcast orientation pattern is violated).
    OrientationMismatch { op: usize, left: u32, right: u32 },
    /// Quantization metadata inconsistent across an operation; `field`
    /// names the violated rule.
    QuantMismatch { op: usize, id: u32, field: &'static str },
    /// A Range fact whose plane stack does not hold `width` planes of the
    /// value's shape (bits.rows == width * value.rows, bits.cols == value.cols).
    RangePlaneShape { op: usize, value: u32, bits: u32 },
    /// A Range fact's plane stack has no Binary operation covering it.
    MissingBinaryFact { op: usize, bits: u32 },
    /// A Rescale remainder with no unsigned Range fact of width `shift`.
    MissingRangeFact { op: usize, r: u32 },
    /// Scale's public scalar is malformed (empty or wider than 16 bytes).
    BadScalar { op: usize },
    /// A produced tensor that is neither read downstream nor declared an
    /// output — it silently drops out of the statement.
    UnconsumedEntry { id: u32 },
    /// A committed tensor no operation references at all.
    OrphanEntry { id: u32 },
    /// The outputs list repeats an id.
    DuplicateOutput { id: u32 },
    /// The outputs list names a nonexistent id.
    UnknownOutput { id: u32 },
    /// A declared output no operation produces.
    OutputNotProduced { id: u32 },
}

impl std::fmt::Display for StatementError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            StatementError::UnknownVersion { got } => {
                write!(f, "unknown statement version {got} (want {STATEMENT_VERSION})")
            }
            StatementError::MissingModelDigest => write!(f, "model identity digest is unset"),
            StatementError::MissingTableDigest => write!(f, "activation-table digest is unset"),
            StatementError::NonDenseIds { index, id } => {
                write!(f, "entry {index} carries id {id} (ids must be dense)")
            }
            StatementError::EmptyShape { id } => write!(f, "entry {id} has an empty shape"),
            StatementError::QuantCount { entries, quants } => {
                write!(f, "{entries} entries but {quants} quantization records")
            }
            StatementError::BadQuant { id } => write!(f, "entry {id} quantization is nonsensical"),
            StatementError::DanglingId { op, id } => {
                write!(f, "operation {op} references nonexistent id {id}")
            }
            StatementError::MatmulShape { op, a, b, c } => {
                write!(f, "operation {op}: matmul shapes do not chain (a={a} b={b} c={c})")
            }
            StatementError::MatmulOrientation { op, id } => {
                write!(f, "operation {op}: matmul orientation discipline violated at id {id}")
            }
            StatementError::ShapeMismatch { op, left, right } => {
                write!(f, "operation {op}: operand shapes differ (ids {left}, {right})")
            }
            StatementError::OrientationMismatch { op, left, right } => {
                write!(f, "operation {op}: operand orientations differ (ids {left}, {right})")
            }
            StatementError::QuantMismatch { op, id, field } => {
                write!(f, "operation {op}: quantization rule '{field}' violated at id {id}")
            }
            StatementError::RangePlaneShape { op, value, bits } => {
                write!(f, "operation {op}: range plane stack {bits} does not match value {value}")
            }
            StatementError::MissingBinaryFact { op, bits } => {
                write!(f, "operation {op}: plane stack {bits} has no binary fact")
            }
            StatementError::MissingRangeFact { op, r } => {
                write!(f, "operation {op}: rescale remainder {r} has no range fact")
            }
            StatementError::BadScalar { op } => write!(f, "operation {op}: malformed public scalar"),
            StatementError::UnconsumedEntry { id } => {
                write!(f, "entry {id} is produced but never consumed nor declared an output")
            }
            StatementError::OrphanEntry { id } => {
                write!(f, "entry {id} appears in no operation")
            }
            StatementError::DuplicateOutput { id } => write!(f, "output {id} declared twice"),
            StatementError::UnknownOutput { id } => write!(f, "output {id} does not exist"),
            StatementError::OutputNotProduced { id } => {
                write!(f, "output {id} is not produced by any operation")
            }
        }
    }
}

impl Statement {
    pub fn new(model_digest: [u8; 32], table_digest: [u8; 32], manifest: ClaimManifest) -> Self {
        Statement {
            header: StatementHeader { version: STATEMENT_VERSION, model_digest, table_digest },
            manifest,
            quant: Vec::new(),
            outputs: Vec::new(),
        }
    }

    /// Full structural validation. Fail-fast: returns the FIRST violation
    /// in a deterministic order (header, entries, quant, operations,
    /// DAG coverage, outputs).
    pub fn validate(&self) -> Result<(), StatementError> {
        use StatementError as E;
        // --- Header. ------------------------------------------------------
        if self.header.version != STATEMENT_VERSION {
            return Err(E::UnknownVersion { got: self.header.version });
        }
        if self.header.model_digest == [0u8; 32] {
            return Err(E::MissingModelDigest);
        }
        if self.header.table_digest == [0u8; 32] {
            return Err(E::MissingTableDigest);
        }
        // --- Entries: dense ids, non-empty shapes. -------------------------
        let entries = &self.manifest.commitments;
        for (index, entry) in entries.iter().enumerate() {
            if entry.id as usize != index {
                return Err(E::NonDenseIds { index, id: entry.id });
            }
            if entry.rows == 0 || entry.cols == 0 {
                return Err(E::EmptyShape { id: entry.id });
            }
        }
        // --- Quantization metadata present and sane per entry. -------------
        if self.quant.len() != entries.len() {
            return Err(E::QuantCount { entries: entries.len(), quants: self.quant.len() });
        }
        for (index, q) in self.quant.iter().enumerate() {
            if q.bits == 0 || q.bits > 64 || q.frac_bits > q.bits {
                return Err(E::BadQuant { id: index as u32 });
            }
        }
        let entry = |op: usize, id: u32| -> Result<&CommitmentEntry, StatementError> {
            entries.get(id as usize).ok_or(E::DanglingId { op, id })
        };
        let quant = |id: u32| -> &QuantMeta { &self.quant[id as usize] };
        let same_shape = |op: usize, l: &CommitmentEntry, r: &CommitmentEntry| {
            if l.rows != r.rows || l.cols != r.cols {
                return Err(E::ShapeMismatch { op, left: l.id, right: r.id });
            }
            Ok(())
        };
        let same_orient = |op: usize, l: &CommitmentEntry, r: &CommitmentEntry| {
            if l.orientation != r.orientation {
                return Err(E::OrientationMismatch { op, left: l.id, right: r.id });
            }
            Ok(())
        };
        // read = referenced as an operand or fact subject; written = produced.
        let mut read = vec![false; entries.len()];
        let mut written = vec![false; entries.len()];
        // --- Per-operation checks. -----------------------------------------
        for (op, operation) in self.manifest.operations.iter().enumerate() {
            match operation {
                Operation::Matmul { a, b, c } => {
                    let (ea, eb, ec) = (entry(op, *a)?, entry(op, *b)?, entry(op, *c)?);
                    if ea.cols != eb.rows || ec.rows != ea.rows || ec.cols != eb.cols {
                        return Err(E::MatmulShape { op, a: *a, b: *b, c: *c });
                    }
                    let all_row_major = [ea, eb, ec]
                        .iter()
                        .all(|e| e.orientation == Orientation::RowMajor);
                    if !all_row_major {
                        if ea.orientation != Orientation::ByRows {
                            return Err(E::MatmulOrientation { op, id: *a });
                        }
                        if eb.orientation != Orientation::ByColumns {
                            return Err(E::MatmulOrientation { op, id: *b });
                        }
                        if ec.orientation != Orientation::ByColumns {
                            return Err(E::MatmulOrientation { op, id: *c });
                        }
                    }
                    let (qa, qb, qc) = (quant(*a), quant(*b), quant(*c));
                    if qc.signed != (qa.signed || qb.signed) {
                        return Err(E::QuantMismatch { op, id: *c, field: "matmul signedness" });
                    }
                    if qc.frac_bits != qa.frac_bits + qb.frac_bits {
                        return Err(E::QuantMismatch { op, id: *c, field: "matmul fraction bits" });
                    }
                    // Accumulator magnitude: inner * max_a * max_b must fit.
                    let acc = (ea.cols as u128)
                        .saturating_mul(qa.max_abs())
                        .saturating_mul(qb.max_abs());
                    if acc > qc.max_abs() {
                        return Err(E::QuantMismatch { op, id: *c, field: "matmul accumulator width" });
                    }
                    read[*a as usize] = true;
                    read[*b as usize] = true;
                    written[*c as usize] = true;
                }
                Operation::Hadamard { x, y, z } => {
                    let (ex, ey, ez) = (entry(op, *x)?, entry(op, *y)?, entry(op, *z)?);
                    same_shape(op, ex, ey)?;
                    same_shape(op, ex, ez)?;
                    same_orient(op, ex, ey)?;
                    same_orient(op, ex, ez)?;
                    let (qx, qy, qz) = (quant(*x), quant(*y), quant(*z));
                    if qz.signed != (qx.signed || qy.signed) {
                        return Err(E::QuantMismatch { op, id: *z, field: "hadamard signedness" });
                    }
                    if qz.frac_bits != qx.frac_bits + qy.frac_bits {
                        return Err(E::QuantMismatch { op, id: *z, field: "hadamard fraction bits" });
                    }
                    if qx.max_abs().saturating_mul(qy.max_abs()) > qz.max_abs() {
                        return Err(E::QuantMismatch { op, id: *z, field: "hadamard product width" });
                    }
                    read[*x as usize] = true;
                    read[*y as usize] = true;
                    written[*z as usize] = true;
                }
                Operation::Rescale { x, y, r, shift } => {
                    let (ex, ey, er) = (entry(op, *x)?, entry(op, *y)?, entry(op, *r)?);
                    same_shape(op, ex, ey)?;
                    same_shape(op, ex, er)?;
                    same_orient(op, ex, ey)?;
                    same_orient(op, ex, er)?;
                    let (qx, qy, qr) = (quant(*x), quant(*y), quant(*r));
                    if *shift == 0 || qx.bits <= *shift {
                        return Err(E::QuantMismatch { op, id: *x, field: "rescale shift" });
                    }
                    if qy.signed != qx.signed {
                        return Err(E::QuantMismatch { op, id: *y, field: "rescale signedness" });
                    }
                    // Calibrated requantization: a rescale output declared
                    // NARROWER than the worst-case x >> shift is legal only
                    // when the statement PROVES the narrowing — a Range
                    // fact of exactly the declared width/sign on y, or a
                    // Lookup consuming y (table-domain membership bounds
                    // it). An uncalibrated witness then simply cannot
                    // produce the fact — completeness loss, never a
                    // soundness hole. Without such a fact the declared
                    // width must cover the worst case and the fixed-point
                    // fraction bookkeeping must be exact.
                    let narrowed = self.manifest.operations.iter().any(|other| {
                        matches!(other, Operation::Range { value, width, signed, .. }
                            if value == y && *width == qy.bits && *signed == qy.signed)
                            || matches!(other, Operation::Lookup { x: lx, .. } if lx == y)
                    });
                    if !narrowed {
                        if qx.max_abs() >> shift > qy.max_abs() {
                            return Err(E::QuantMismatch { op, id: *y, field: "rescale width" });
                        }
                        if qx.frac_bits < *shift || qy.frac_bits != qx.frac_bits - shift {
                            return Err(E::QuantMismatch { op, id: *y, field: "rescale fraction bits" });
                        }
                    }
                    if qr.signed || qr.bits != *shift || qr.frac_bits != qx.frac_bits {
                        return Err(E::QuantMismatch { op, id: *r, field: "rescale remainder quant" });
                    }
                    // The remainder MUST carry an unsigned width-`shift`
                    // range fact — without it the mod-q rescale identity
                    // admits integer wraparound (audit C-02).
                    let has_range = self.manifest.operations.iter().any(|other| {
                        matches!(other, Operation::Range { value, width, signed, .. }
                            if value == r && width == shift && !signed)
                    });
                    if !has_range {
                        return Err(E::MissingRangeFact { op, r: *r });
                    }
                    read[*x as usize] = true;
                    written[*y as usize] = true;
                    written[*r as usize] = true;
                    read[*r as usize] = true; // the Range fact below reads it
                }
                Operation::Range { value, bits, width, signed } => {
                    let (ev, eb) = (entry(op, *value)?, entry(op, *bits)?);
                    // Stacked plane convention: `width` planes stacked row-wise.
                    if *width == 0
                        || eb.rows != width.saturating_mul(ev.rows)
                        || eb.cols != ev.cols
                    {
                        return Err(E::RangePlaneShape { op, value: *value, bits: *bits });
                    }
                    same_orient(op, ev, eb)?;
                    let (qv, qb) = (quant(*value), quant(*bits));
                    if qv.bits != *width || qv.signed != *signed {
                        return Err(E::QuantMismatch { op, id: *value, field: "range width/sign" });
                    }
                    if qb.bits != 1 || qb.frac_bits != 0 || qb.signed {
                        return Err(E::QuantMismatch { op, id: *bits, field: "range plane quant" });
                    }
                    let has_binary = self
                        .manifest
                        .operations
                        .iter()
                        .any(|other| matches!(other, Operation::Binary { bits: b } if b == bits));
                    if !has_binary {
                        return Err(E::MissingBinaryFact { op, bits: *bits });
                    }
                    read[*value as usize] = true;
                    read[*bits as usize] = true;
                }
                Operation::Binary { bits } => {
                    entry(op, *bits)?;
                    let qb = quant(*bits);
                    if qb.bits != 1 || qb.frac_bits != 0 || qb.signed {
                        return Err(E::QuantMismatch { op, id: *bits, field: "binary quant" });
                    }
                    read[*bits as usize] = true;
                }
                Operation::Add { inputs, output } => {
                    let eo = entry(op, *output)?;
                    let qo = quant(*output);
                    let mut sum = 0u128;
                    let mut any_signed = false;
                    for input in inputs {
                        let ei = entry(op, *input)?;
                        same_shape(op, ei, eo)?;
                        same_orient(op, ei, eo)?;
                        let qi = quant(*input);
                        if qi.frac_bits != qo.frac_bits {
                            return Err(E::QuantMismatch { op, id: *input, field: "add fraction bits" });
                        }
                        any_signed |= qi.signed;
                        sum = sum.saturating_add(qi.max_abs());
                        read[*input as usize] = true;
                    }
                    if any_signed && !qo.signed {
                        return Err(E::QuantMismatch { op, id: *output, field: "add signedness" });
                    }
                    if sum > qo.max_abs() {
                        return Err(E::QuantMismatch { op, id: *output, field: "add width" });
                    }
                    written[*output as usize] = true;
                }
                Operation::Scale { input, output, scalar_le } => {
                    let (ei, eo) = (entry(op, *input)?, entry(op, *output)?);
                    same_shape(op, ei, eo)?;
                    same_orient(op, ei, eo)?;
                    if scalar_le.is_empty() || scalar_le.len() > 16 {
                        return Err(E::BadScalar { op });
                    }
                    let mut scalar = 0u128;
                    for (i, byte) in scalar_le.iter().enumerate() {
                        scalar |= (*byte as u128) << (8 * i);
                    }
                    let (qi, qo) = (quant(*input), quant(*output));
                    if qo.signed != qi.signed {
                        return Err(E::QuantMismatch { op, id: *output, field: "scale signedness" });
                    }
                    if qo.frac_bits != qi.frac_bits {
                        return Err(E::QuantMismatch { op, id: *output, field: "scale fraction bits" });
                    }
                    if qi.max_abs().saturating_mul(scalar) > qo.max_abs() {
                        return Err(E::QuantMismatch { op, id: *output, field: "scale width" });
                    }
                    read[*input as usize] = true;
                    written[*output as usize] = true;
                }
                Operation::LinkEqual { left, right } => {
                    let (el, er) = (entry(op, *left)?, entry(op, *right)?);
                    same_shape(op, el, er)?;
                    if quant(*left) != quant(*right) {
                        return Err(E::QuantMismatch { op, id: *right, field: "link quant" });
                    }
                    read[*left as usize] = true;
                    read[*right as usize] = true;
                }
                Operation::LinkTranspose { by_rows, by_cols } => {
                    let (er, ec) = (entry(op, *by_rows)?, entry(op, *by_cols)?);
                    same_shape(op, er, ec)?;
                    if er.orientation != Orientation::ByRows {
                        return Err(E::OrientationMismatch { op, left: *by_rows, right: *by_cols });
                    }
                    if ec.orientation != Orientation::ByColumns {
                        return Err(E::OrientationMismatch { op, left: *by_rows, right: *by_cols });
                    }
                    if quant(*by_rows) != quant(*by_cols) {
                        return Err(E::QuantMismatch { op, id: *by_cols, field: "link quant" });
                    }
                    read[*by_rows as usize] = true;
                    read[*by_cols as usize] = true;
                }
                Operation::BiasBroadcast { bias, broadcast } => {
                    let (ebias, ebc) = (entry(op, *bias)?, entry(op, *broadcast)?);
                    if ebias.cols != 1 || ebias.rows != ebc.cols {
                        return Err(E::ShapeMismatch { op, left: *bias, right: *broadcast });
                    }
                    if quant(*bias) != quant(*broadcast) {
                        return Err(E::QuantMismatch { op, id: *broadcast, field: "broadcast quant" });
                    }
                    read[*bias as usize] = true;
                    written[*broadcast as usize] = true;
                }
                Operation::Lookup { x, y } => {
                    let (ex, ey) = (entry(op, *x)?, entry(op, *y)?);
                    same_shape(op, ex, ey)?;
                    same_orient(op, ex, ey)?;
                    let (qx, qy) = (quant(*x), quant(*y));
                    // The frozen activation table (header table_digest) is
                    // the int8 -> int8 SiLU spec: both sides 8-bit signed.
                    if qx.bits != 8 || !qx.signed {
                        return Err(E::QuantMismatch { op, id: *x, field: "lookup domain quant" });
                    }
                    if qy.bits != 8 || !qy.signed {
                        return Err(E::QuantMismatch { op, id: *y, field: "lookup image quant" });
                    }
                    read[*x as usize] = true;
                    written[*y as usize] = true;
                }
            }
        }
        // --- DAG coverage: consumed-or-output, no orphans. ------------------
        let mut is_output = vec![false; entries.len()];
        for output in &self.outputs {
            let Some(slot) = is_output.get_mut(*output as usize) else {
                return Err(E::UnknownOutput { id: *output });
            };
            if *slot {
                return Err(E::DuplicateOutput { id: *output });
            }
            if !written[*output as usize] {
                return Err(E::OutputNotProduced { id: *output });
            }
            *slot = true;
        }
        for id in 0..entries.len() {
            if !read[id] && !written[id] {
                return Err(E::OrphanEntry { id: id as u32 });
            }
            if written[id] && !read[id] && !is_output[id] {
                return Err(E::UnconsumedEntry { id: id as u32 });
            }
        }
        Ok(())
    }

    /// Order-sensitive digest of the FULL statement: header, quantization
    /// metadata, outputs, and the manifest content. Refuses to form a
    /// digest for an invalid statement — this is the enforcement point for
    /// "validate before anything is hashed into a challenge".
    pub fn digest(&self) -> Result<[u8; 32], StatementError> {
        self.validate()?;
        let mut hasher = Sha256::new();
        absorb_bytes(&mut hasher, STATEMENT_TAG.as_bytes());
        hasher.update(self.header.version.to_le_bytes());
        hasher.update(self.header.model_digest);
        hasher.update(self.header.table_digest);
        hasher.update((self.quant.len() as u64).to_le_bytes());
        for q in &self.quant {
            hasher.update(q.bits.to_le_bytes());
            hasher.update(q.frac_bits.to_le_bytes());
            hasher.update([q.signed as u8]);
        }
        hasher.update((self.outputs.len() as u64).to_le_bytes());
        for output in &self.outputs {
            hasher.update(output.to_le_bytes());
        }
        hasher.update(self.manifest.digest());
        Ok(hasher.finalize().into())
    }
}
