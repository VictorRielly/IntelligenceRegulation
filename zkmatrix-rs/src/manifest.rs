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

    /// Order-sensitive digest of the whole manifest.
    ///
    /// PRIVATE since Statement v3 (audit 2026-07-12 finding H-03): a bare
    /// manifest digest binds caller-supplied entries without validating
    /// them, so it must never seed a transcript directly. The only path to
    /// a transcript context is `Statement::digest()`, which refuses to
    /// hash an invalid statement. Migration tests may use
    /// `digest_v1_migration_only`.
    fn digest(&self) -> [u8; 32] {
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

    /// The retired v1 bare digest, reachable only from migration tests.
    /// Production code paths must go through `Statement::digest()`.
    #[cfg(test)]
    pub fn digest_v1_migration_only(&self) -> [u8; 32] {
        self.digest()
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
// ===========================================================================
// Statement v3 — TYPED INTEGER SEMANTICS (audit 2026-07-12, Phase 2).
//
// v3 replaces v2's symmetric magnitude model with the following frozen,
// typed integer specification. Every rule below is machine-enforced by
// `validate()`; the digest cannot form until all of them hold.
//
// RAW ENCODING. Every committed tensor element is one integer `raw` stored
// in the backend's residue field: unsigned tensors store `raw` directly,
// signed tensors store the centered two's-complement residue `raw mod q`
// (negative values as `q - |raw|`). A `QuantMeta { bits, frac_bits,
// signed }` declares the STORAGE TYPE of the raw integer:
//
//   unsigned:  raw in [0, 2^bits - 1]
//   signed:    raw in [-2^(bits-1), 2^(bits-1) - 1]
//
// Signed bounds are ASYMMETRIC (audit C-03b): the positive endpoint
// +2^(bits-1) is NOT representable, and the validator propagates lower and
// upper bounds separately through every operation (interval arithmetic),
// so a product like (-2^7) * (-2^7) = +2^14 needs 16 signed bits, not 15.
//
// SCALE EXPONENT. The represented real value is `raw * 2^-frac_bits`.
// `frac_bits` is a pure scale-exponent annotation over the SAME raw
// integer; it composes exactly and is NEVER waived (audit C-03a):
//
//   Matmul / Hadamard:  frac(out) = frac(a) + frac(b)
//   Add / Scale / links: frac(out) = frac(in)   (all inputs equal)
//   Rescale by 2^shift:  frac(y) = frac(x) - shift, frac(r) = frac(x)
//
// A Range or Lookup fact narrows MAGNITUDE; it does not change the scale
// an integer represents, so the scale equations above hold whether or not
// the output is narrowed.
//
// CALIBRATED NARROWING. A Rescale, Hadamard or Add output declared with a
// range (or signedness) the worst-case interval does not cover is legal
// only when the statement itself PROVES the narrowing: a Range fact of
// exactly the declared width/signedness on the output, or a Lookup
// consuming it (table-domain membership). An uncalibrated witness then
// simply cannot produce the fact — completeness loss, never a soundness
// hole. Matmul accumulators never narrow: a range fact on the SUM does
// not bound the partial sums, so the declared accumulator type must cover
// the full worst case. Even when narrowed, the PRE-narrowing worst-case
// interval must fit the modulus window (below) — that containment is what
// turns the mod-q identity plus the range fact into an integer identity.
//
// MODULUS CAPACITY. The header declares `modulus_bits` = floor(log2 q) of
// the smallest backend modulus any entry lives at. Every declared entry
// type must inject into Z_q (bits <= modulus_bits), and every operation's
// worst-case interval must fit the centered window
// [-2^(modulus_bits-1), 2^(modulus_bits-1) - 1] — the non-wrap condition
// the integer-identity arguments need.
//
// TYPED TABLE BINDING (audit C-03c). A statement that uses `Lookup` binds
// a full `TableSpec` — digest, input/output quantization, domain — and
// the validator requires EXACT metadata equality with the canonical
// frozen spec, not merely a nonzero digest.
//
// CANONICAL PADDING. Every entry declares its padded physical extent via
// `PadSpec`: the padded dimension must be the exact next multiple of the
// declared packing unit — no prover-chosen slack in which junk slots can
// hide. Physical slot capacity beyond the canonical padded grid is the
// proving layer's responsibility to keep constrained (junk-free).
//
// TOPOLOGY. The operation list must be topologically ordered: an operation
// may read an entry only if it is a leaf (produced by no operation) or at
// least one producer appears strictly earlier in the list. The entry-level
// producer graph must be acyclic, the operation list nonempty, and at
// least one output declared.
//
// The validator is backend-agnostic: residue-specific proof budgets
// (sigma sizes, ARP budgets) are asserted by the proving layer against the
// SAME declared types this validator pins.

/// Statement format version. v3 = typed integer semantics (asymmetric
/// bounds, typed table spec, modulus capacity, canonical padding,
/// topological ordering); v2 = the first validated format; the bare
/// hash-only manifest above is retroactively "v1". Unknown versions reject.
pub const STATEMENT_VERSION: u32 = 3;
const STATEMENT_TAG: &str = "zkmatrix-statement-v3";

/// Per-tensor quantization metadata: integer bit width, fixed-point
/// fraction bits, signedness. `bits` counts the full two's-complement
/// width when signed (values in [-2^(bits-1), 2^(bits-1))).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct QuantMeta {
    pub bits: u32,
    pub frac_bits: u32,
    pub signed: bool,
}

/// Inclusive lower/upper bounds of a raw integer — the asymmetric
/// signed-bound representation of the v3 typed spec (audit C-03b).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct RawBounds {
    pub lo: i128,
    pub hi: i128,
}

impl RawBounds {
    fn contains(&self, inner: RawBounds) -> bool {
        self.lo <= inner.lo && inner.hi <= self.hi
    }

    /// Interval product (all four endpoint products; saturating i128 —
    /// saturation only ever widens, which keeps rejection sound).
    fn mul(self, other: RawBounds) -> RawBounds {
        let c = [
            self.lo.saturating_mul(other.lo),
            self.lo.saturating_mul(other.hi),
            self.hi.saturating_mul(other.lo),
            self.hi.saturating_mul(other.hi),
        ];
        RawBounds { lo: *c.iter().min().unwrap(), hi: *c.iter().max().unwrap() }
    }

    fn add(self, other: RawBounds) -> RawBounds {
        RawBounds {
            lo: self.lo.saturating_add(other.lo),
            hi: self.hi.saturating_add(other.hi),
        }
    }

    /// Scale by a nonnegative integer (matmul inner dimension, public
    /// scalar).
    fn scale(self, n: i128) -> RawBounds {
        RawBounds { lo: self.lo.saturating_mul(n), hi: self.hi.saturating_mul(n) }
    }

    /// Floor division by 2^shift (arithmetic shift = the Euclidean
    /// quotient convention of Rescale).
    fn shr(self, shift: u32) -> RawBounds {
        RawBounds { lo: self.lo >> shift, hi: self.hi >> shift }
    }

    /// The centered modulus window [-2^(mb-1), 2^(mb-1) - 1]. mb >= 128
    /// always passes: any i128-representable interval fits.
    fn fits_modulus(&self, modulus_bits: u32) -> bool {
        if modulus_bits >= 128 {
            return true;
        }
        let w = 1i128 << (modulus_bits - 1);
        self.lo >= -w && self.hi < w
    }
}

impl QuantMeta {
    /// The declared storage type's raw-integer bounds (see the v3 typed
    /// spec above): unsigned [0, 2^bits - 1], signed
    /// [-2^(bits-1), 2^(bits-1) - 1] — asymmetric, the positive endpoint
    /// excluded.
    pub fn raw_bounds(&self) -> RawBounds {
        if self.signed {
            RawBounds { lo: -(1i128 << (self.bits - 1)), hi: (1i128 << (self.bits - 1)) - 1 }
        } else {
            RawBounds { lo: 0, hi: (1i128 << self.bits) - 1 }
        }
    }
}

/// Typed activation-table binding (audit C-03c): the digest alone does not
/// pin the table's integer semantics, so the statement binds the exact
/// input/output quantization and the raw input domain, and the validator
/// requires exact metadata equality with the canonical frozen spec.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct TableSpec {
    /// `ring/lookup.rs::table_spec_digest` of the frozen integer table.
    pub digest: [u8; 32],
    /// Quantization of the table's input codes (the lookup domain).
    pub input: QuantMeta,
    /// Quantization of the table's output codes (the lookup image).
    pub output: QuantMeta,
    /// Inclusive raw domain endpoints (must equal the input type's range —
    /// the table is total on its domain).
    pub domain_min: i64,
    pub domain_max: i64,
}

/// The canonical frozen activation table: `silu-int8-table-v1`
/// (int8 -> int8, 4 fraction bits both sides, total on [-128, 127]).
pub const SILU_INT8_TABLE_SPEC: TableSpec = TableSpec {
    digest: SILU_INT8_TABLE_DIGEST,
    input: QuantMeta { bits: 8, frac_bits: 4, signed: true },
    output: QuantMeta { bits: 8, frac_bits: 4, signed: true },
    domain_min: -128,
    domain_max: 127,
};

/// Canonical padded physical extent of one committed tensor. The padded
/// dimensions must be the EXACT next multiples of the declared packing
/// units — canonical padding admits no prover-chosen slack (audit Phase 2
/// item 5).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct PadSpec {
    pub padded_rows: u64,
    pub padded_cols: u64,
    /// Packing unit the padded row count must be the next multiple of
    /// (e.g. the per-commitment slot capacity of a by-columns layout).
    pub row_unit: u64,
    pub col_unit: u64,
}

impl PadSpec {
    fn canonical(dim: u64, unit: u64) -> u64 {
        dim.div_ceil(unit) * unit
    }

    /// An unpadded tensor (physical extent == logical extent).
    pub fn exact(rows: usize, cols: usize) -> Self {
        PadSpec::units(rows, cols, 1, 1)
    }

    /// The canonical padding of `rows x cols` to the given packing units.
    pub fn units(rows: usize, cols: usize, row_unit: usize, col_unit: usize) -> Self {
        let (ru, cu) = (row_unit.max(1) as u64, col_unit.max(1) as u64);
        PadSpec {
            padded_rows: PadSpec::canonical(rows as u64, ru),
            padded_cols: PadSpec::canonical(cols as u64, cu),
            row_unit: ru,
            col_unit: cu,
        }
    }
}

/// Canonical digest of `silu-int8-table-v1`. A Lookup statement is not
/// allowed to choose an arbitrary nonzero table digest: its semantics are
/// this exact, integer-frozen table. `ring/lookup.rs` carries a regression
/// that recomputes the same value from the static rows.
pub const SILU_INT8_TABLE_DIGEST: [u8; 32] = [
    0x76, 0x8b, 0x83, 0xd7, 0xc0, 0x1d, 0x9b, 0xee,
    0xcc, 0x64, 0x5d, 0x26, 0x46, 0xf1, 0x07, 0xdf,
    0x7f, 0xc3, 0x70, 0xdc, 0x80, 0x2f, 0xee, 0x15,
    0x4c, 0x03, 0x18, 0x68, 0x5c, 0x40, 0xd2, 0x97,
];

/// The statement header: format version, the identity digest of the exact
/// quantized model being claimed (weights + architecture + quantization
/// spec), the typed activation-table binding (None when the statement
/// proves no Lookup), and the backend modulus capacity in bits
/// (floor(log2 q) of the smallest modulus any entry lives at).
#[derive(Clone, Copy, Debug)]
pub struct StatementHeader {
    pub version: u32,
    pub model_digest: [u8; 32],
    pub table: Option<TableSpec>,
    pub modulus_bits: u32,
}

/// A validated proof statement: header + manifest + per-entry quantization
/// metadata (`quant[i]` describes entry id i) + per-entry canonical
/// padding (`pad[i]`) + declared outputs.
#[derive(Clone, Debug)]
pub struct Statement {
    pub header: StatementHeader,
    pub manifest: ClaimManifest,
    pub quant: Vec<QuantMeta>,
    pub pad: Vec<PadSpec>,
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
    /// A Lookup operation exists but the header binds no table spec, or a
    /// bound table spec carries an all-zero digest.
    MissingTableDigest,
    /// Header modulus capacity is nonsensical (outside 2..=255).
    BadModulus { bits: u32 },
    /// A declared entry type does not inject into the backend modulus
    /// (bits > modulus_bits), or an operation's worst-case interval
    /// escapes the centered modulus window.
    ModulusCapacity { id: u32 },
    /// The operation list is empty: the statement claims nothing.
    EmptyOperations,
    /// Operation `op` reads entry `id` before any producer of that entry
    /// appears in the list (the list is not topologically ordered).
    NotTopologicallyOrdered { op: usize, id: u32 },
    /// pad.len() != number of commitment entries.
    PadCount { entries: usize, pads: usize },
    /// A padded extent is not the exact next multiple of its declared
    /// packing unit (or a unit is zero).
    NoncanonicalPadding { id: u32 },
    /// No outputs are declared: the statement has no visible result.
    NoOutputs,
    /// A bound table spec's metadata does not equal the canonical frozen
    /// spec exactly (digest matches, but quantization/domain lie).
    TableSpecMismatch,
    /// Entry k's id is not k (ids must be dense and ordered).
    NonDenseIds { index: usize, id: u32 },
    /// Zero rows or columns.
    EmptyShape { id: u32 },
    /// quant.len() != number of commitment entries.
    QuantCount { entries: usize, quants: usize },
    /// Nonsensical quantization metadata (bits outside 1..=64 or
    /// frac_bits above 64).
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
    /// Add has no inputs and therefore constrains its output to nothing.
    EmptyAdd { op: usize },
    /// Producer/consumer edges contain a directed cycle.
    CyclicDataflow { id: u32 },
    /// A Lookup selected a table other than the canonical frozen SiLU table.
    TableDigestMismatch,
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
            StatementError::MissingTableDigest => {
                write!(f, "lookup requires a bound activation-table spec (unset or zero digest)")
            }
            StatementError::BadModulus { bits } => {
                write!(f, "modulus capacity {bits} bits is nonsensical")
            }
            StatementError::ModulusCapacity { id } => {
                write!(f, "entry {id} escapes the declared modulus capacity")
            }
            StatementError::EmptyOperations => write!(f, "operation list is empty"),
            StatementError::NotTopologicallyOrdered { op, id } => {
                write!(f, "operation {op} reads entry {id} before any producer of it")
            }
            StatementError::PadCount { entries, pads } => {
                write!(f, "{entries} entries but {pads} padding records")
            }
            StatementError::NoncanonicalPadding { id } => {
                write!(f, "entry {id} padding is not the canonical next unit multiple")
            }
            StatementError::NoOutputs => write!(f, "no outputs declared"),
            StatementError::TableSpecMismatch => {
                write!(f, "table spec metadata does not equal the canonical frozen spec")
            }
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
            StatementError::EmptyAdd { op } => write!(f, "operation {op}: Add has no inputs"),
            StatementError::CyclicDataflow { id } => {
                write!(f, "dataflow contains a cycle through entry {id}")
            }
            StatementError::TableDigestMismatch => {
                write!(f, "lookup table digest is not the canonical silu-int8-table-v1 digest")
            }
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

fn first_dataflow_cycle(graph: &[Vec<usize>]) -> Option<u32> {
    fn visit(node: usize, graph: &[Vec<usize>], state: &mut [u8]) -> Option<u32> {
        match state[node] {
            1 => return Some(node as u32),
            2 => return None,
            _ => {}
        }
        state[node] = 1;
        for &next in &graph[node] {
            if let Some(id) = visit(next, graph, state) {
                return Some(id);
            }
        }
        state[node] = 2;
        None
    }

    let mut state = vec![0u8; graph.len()];
    for node in 0..graph.len() {
        if state[node] == 0 {
            if let Some(id) = visit(node, graph, &mut state) {
                return Some(id);
            }
        }
    }
    None
}

impl Statement {
    pub fn new(
        model_digest: [u8; 32],
        table: Option<TableSpec>,
        modulus_bits: u32,
        manifest: ClaimManifest,
    ) -> Self {
        Statement {
            header: StatementHeader {
                version: STATEMENT_VERSION,
                model_digest,
                table,
                modulus_bits,
            },
            manifest,
            quant: Vec::new(),
            pad: Vec::new(),
            outputs: Vec::new(),
        }
    }

    /// The exact narrowing-fact rule of the typed spec: a Range fact of
    /// exactly the declared width/signedness on `id`, or a Lookup
    /// consuming `id` (table-domain membership bounds it).
    fn narrowing_fact(&self, id: u32, q: &QuantMeta) -> bool {
        self.manifest.operations.iter().any(|other| {
            matches!(other, Operation::Range { value, width, signed, .. }
                if *value == id && *width == q.bits && *signed == q.signed)
                || matches!(other, Operation::Lookup { x: lx, .. } if *lx == id)
        })
    }

    /// Full structural validation. Fail-fast: returns the FIRST violation
    /// in a deterministic order (header, entries, quant + modulus
    /// injection, operations, cycles, topological order, padding,
    /// outputs/coverage).
    pub fn validate(&self) -> Result<(), StatementError> {
        use StatementError as E;
        // --- Header. ------------------------------------------------------
        if self.header.version != STATEMENT_VERSION {
            return Err(E::UnknownVersion { got: self.header.version });
        }
        if self.header.model_digest == [0u8; 32] {
            return Err(E::MissingModelDigest);
        }
        if let Some(table) = &self.header.table {
            if table.digest == [0u8; 32] {
                return Err(E::MissingTableDigest);
            }
        }
        let mb = self.header.modulus_bits;
        if !(2..=255).contains(&mb) {
            return Err(E::BadModulus { bits: mb });
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
        // --- Quantization metadata present and sane per entry; every
        // --- declared type must inject into the backend modulus. -----------
        if self.quant.len() != entries.len() {
            return Err(E::QuantCount { entries: entries.len(), quants: self.quant.len() });
        }
        for (index, q) in self.quant.iter().enumerate() {
            // frac_bits may exceed bits (a fixed-point value below 1, e.g.
            // a rescale remainder narrower than its fraction).
            if q.bits == 0 || q.bits > 64 || q.frac_bits > 64 {
                return Err(E::BadQuant { id: index as u32 });
            }
            if q.bits > mb {
                return Err(E::ModulusCapacity { id: index as u32 });
            }
        }
        if self.manifest.operations.is_empty() {
            return Err(E::EmptyOperations);
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
        let mut flow = vec![Vec::<usize>::new(); entries.len()];
        // Topological-order bookkeeping: the first operation index that
        // PRODUCES each entry, and every (op, id) operand-read event. A
        // fact subject (Range/Binary/link operands) is a read.
        let mut first_producer = vec![usize::MAX; entries.len()];
        let mut read_events: Vec<(usize, u32)> = Vec::new();
        // --- Per-operation checks. -----------------------------------------
        for (op, operation) in self.manifest.operations.iter().enumerate() {
            let mut reads: Vec<u32> = Vec::new();
            let mut writes: Vec<u32> = Vec::new();
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
                    // Accumulator interval: inner * (a-bounds x b-bounds),
                    // lower and upper endpoints tracked separately. A
                    // matmul accumulator NEVER narrows: a range fact on
                    // the sum does not bound the partial sums.
                    let acc = qa.raw_bounds().mul(qb.raw_bounds()).scale(ea.cols as i128);
                    if !qc.raw_bounds().contains(acc) {
                        return Err(E::QuantMismatch { op, id: *c, field: "matmul accumulator width" });
                    }
                    if !acc.fits_modulus(mb) {
                        return Err(E::QuantMismatch { op, id: *c, field: "modulus capacity" });
                    }
                    flow[*a as usize].push(*c as usize);
                    flow[*b as usize].push(*c as usize);
                    read[*a as usize] = true;
                    read[*b as usize] = true;
                    written[*c as usize] = true;
                    reads.extend([*a, *b]);
                    writes.push(*c);
                }
                Operation::Hadamard { x, y, z } => {
                    let (ex, ey, ez) = (entry(op, *x)?, entry(op, *y)?, entry(op, *z)?);
                    same_shape(op, ex, ey)?;
                    same_shape(op, ex, ez)?;
                    same_orient(op, ex, ey)?;
                    same_orient(op, ex, ez)?;
                    let (qx, qy, qz) = (quant(*x), quant(*y), quant(*z));
                    // Scale exponents compose unconditionally (C-03a).
                    if qz.frac_bits != qx.frac_bits + qy.frac_bits {
                        return Err(E::QuantMismatch { op, id: *z, field: "hadamard fraction bits" });
                    }
                    let worst = qx.raw_bounds().mul(qy.raw_bounds());
                    // Calibrated narrowing: a declared type the worst case
                    // does not cover (width OR signedness) is legal only
                    // with a Range/Lookup fact on z.
                    if !self.narrowing_fact(*z, qz) {
                        if qz.signed != (qx.signed || qy.signed) {
                            return Err(E::QuantMismatch { op, id: *z, field: "hadamard signedness" });
                        }
                        if !qz.raw_bounds().contains(worst) {
                            return Err(E::QuantMismatch { op, id: *z, field: "hadamard product width" });
                        }
                    }
                    // Narrowed or not, the PRE-narrowing interval must fit
                    // the modulus window — that is what lets the mod-q
                    // identity plus the fact imply the integer identity.
                    if !worst.fits_modulus(mb) {
                        return Err(E::QuantMismatch { op, id: *z, field: "modulus capacity" });
                    }
                    flow[*x as usize].push(*z as usize);
                    flow[*y as usize].push(*z as usize);
                    read[*x as usize] = true;
                    read[*y as usize] = true;
                    written[*z as usize] = true;
                    reads.extend([*x, *y]);
                    writes.push(*z);
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
                    // Integer identity and fixed-point interpretation are
                    // independent of whether a later Range/Lookup proves a
                    // calibrated narrowing. Narrowing may justify width; it
                    // cannot waive the scale equation (C-03a).
                    if qx.frac_bits < *shift || qy.frac_bits != qx.frac_bits - shift {
                        return Err(E::QuantMismatch { op, id: *y, field: "rescale fraction bits" });
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
                    let worst = qx.raw_bounds().shr(*shift);
                    if !self.narrowing_fact(*y, qy) && !qy.raw_bounds().contains(worst) {
                        return Err(E::QuantMismatch { op, id: *y, field: "rescale width" });
                    }
                    if !worst.fits_modulus(mb) {
                        return Err(E::QuantMismatch { op, id: *y, field: "modulus capacity" });
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
                    flow[*x as usize].push(*y as usize);
                    flow[*x as usize].push(*r as usize);
                    reads.push(*x);
                    writes.extend([*y, *r]);
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
                    reads.extend([*value, *bits]);
                }
                Operation::Binary { bits } => {
                    entry(op, *bits)?;
                    let qb = quant(*bits);
                    if qb.bits != 1 || qb.frac_bits != 0 || qb.signed {
                        return Err(E::QuantMismatch { op, id: *bits, field: "binary quant" });
                    }
                    read[*bits as usize] = true;
                    reads.push(*bits);
                }
                Operation::Add { inputs, output } => {
                    let eo = entry(op, *output)?;
                    let qo = quant(*output);
                    if inputs.is_empty() {
                        return Err(E::EmptyAdd { op });
                    }
                    let mut sum = RawBounds { lo: 0, hi: 0 };
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
                        sum = sum.add(qi.raw_bounds());
                        read[*input as usize] = true;
                        reads.push(*input);
                    }
                    // Calibrated narrowing (as for Hadamard): a declared
                    // output type the worst-case sum does not cover needs
                    // a Range/Lookup fact on the output.
                    if !self.narrowing_fact(*output, qo) {
                        if any_signed && !qo.signed {
                            return Err(E::QuantMismatch { op, id: *output, field: "add signedness" });
                        }
                        if !qo.raw_bounds().contains(sum) {
                            return Err(E::QuantMismatch { op, id: *output, field: "add width" });
                        }
                    }
                    if !sum.fits_modulus(mb) {
                        return Err(E::QuantMismatch { op, id: *output, field: "modulus capacity" });
                    }
                    written[*output as usize] = true;
                    for input in inputs {
                        flow[*input as usize].push(*output as usize);
                    }
                    writes.push(*output);
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
                    let worst = qi.raw_bounds().scale(scalar.min(i128::MAX as u128) as i128);
                    if !qo.raw_bounds().contains(worst) {
                        return Err(E::QuantMismatch { op, id: *output, field: "scale width" });
                    }
                    if !worst.fits_modulus(mb) {
                        return Err(E::QuantMismatch { op, id: *output, field: "modulus capacity" });
                    }
                    read[*input as usize] = true;
                    written[*output as usize] = true;
                    flow[*input as usize].push(*output as usize);
                    reads.push(*input);
                    writes.push(*output);
                }
                Operation::LinkEqual { left, right } => {
                    let (el, er) = (entry(op, *left)?, entry(op, *right)?);
                    same_shape(op, el, er)?;
                    same_orient(op, el, er)?;
                    if quant(*left) != quant(*right) {
                        return Err(E::QuantMismatch { op, id: *right, field: "link quant" });
                    }
                    read[*left as usize] = true;
                    read[*right as usize] = true;
                    reads.extend([*left, *right]);
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
                    reads.extend([*by_rows, *by_cols]);
                }
                Operation::BiasBroadcast { bias, broadcast } => {
                    let (ebias, ebc) = (entry(op, *bias)?, entry(op, *broadcast)?);
                    if ebias.cols != 1 || ebias.rows != ebc.cols {
                        return Err(E::ShapeMismatch { op, left: *bias, right: *broadcast });
                    }
                    if ebias.orientation != Orientation::ByColumns
                        || ebc.orientation != Orientation::ByColumns
                    {
                        return Err(E::OrientationMismatch {
                            op,
                            left: *bias,
                            right: *broadcast,
                        });
                    }
                    if quant(*bias) != quant(*broadcast) {
                        return Err(E::QuantMismatch { op, id: *broadcast, field: "broadcast quant" });
                    }
                    read[*bias as usize] = true;
                    written[*broadcast as usize] = true;
                    flow[*bias as usize].push(*broadcast as usize);
                    reads.push(*bias);
                    writes.push(*broadcast);
                }
                Operation::Lookup { x, y } => {
                    let (ex, ey) = (entry(op, *x)?, entry(op, *y)?);
                    same_shape(op, ex, ey)?;
                    same_orient(op, ex, ey)?;
                    let (qx, qy) = (quant(*x), quant(*y));
                    // Typed table binding (C-03c): the statement must bind
                    // the canonical frozen spec by EXACT metadata equality
                    // — digest, input/output quantization, domain — and
                    // the operand types must equal the spec's types.
                    let Some(table) = &self.header.table else {
                        return Err(E::MissingTableDigest);
                    };
                    if table.digest != SILU_INT8_TABLE_DIGEST {
                        return Err(E::TableDigestMismatch);
                    }
                    if *table != SILU_INT8_TABLE_SPEC {
                        return Err(E::TableSpecMismatch);
                    }
                    if *qx != table.input {
                        return Err(E::QuantMismatch { op, id: *x, field: "lookup domain quant" });
                    }
                    if *qy != table.output {
                        return Err(E::QuantMismatch { op, id: *y, field: "lookup image quant" });
                    }
                    read[*x as usize] = true;
                    written[*y as usize] = true;
                    flow[*x as usize].push(*y as usize);
                    reads.push(*x);
                    writes.push(*y);
                }
            }
            for id in writes {
                let slot = &mut first_producer[id as usize];
                if *slot == usize::MAX {
                    *slot = op;
                }
            }
            for id in reads {
                read_events.push((op, id));
            }
        }
        // A manifest is a DAG, not merely a bag of individually shaped
        // operations. Detect cycles after all ids and edges are validated.
        if let Some(id) = first_dataflow_cycle(&flow) {
            return Err(E::CyclicDataflow { id });
        }
        // Topological order: an operation may read an entry only if it is
        // a leaf (no producer at all) or at least one producer appears
        // strictly earlier in the operation list.
        for (op, id) in read_events {
            let producer = first_producer[id as usize];
            if producer != usize::MAX && producer >= op {
                return Err(E::NotTopologicallyOrdered { op, id });
            }
        }
        // --- Canonical padding: every entry declares its padded physical
        // --- extent, and it must be the exact next unit multiple. ----------
        if self.pad.len() != entries.len() {
            return Err(E::PadCount { entries: entries.len(), pads: self.pad.len() });
        }
        for (entry, pad) in entries.iter().zip(self.pad.iter()) {
            if pad.row_unit == 0
                || pad.col_unit == 0
                || pad.padded_rows != PadSpec::canonical(entry.rows as u64, pad.row_unit)
                || pad.padded_cols != PadSpec::canonical(entry.cols as u64, pad.col_unit)
            {
                return Err(E::NoncanonicalPadding { id: entry.id });
            }
        }
        // --- DAG coverage: consumed-or-output, no orphans. ------------------
        if self.outputs.is_empty() {
            return Err(E::NoOutputs);
        }
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

    /// Order-sensitive digest of the FULL statement: header (version,
    /// model digest, typed table spec, modulus capacity), quantization
    /// metadata, canonical padding, outputs, and the manifest content.
    /// Refuses to form a digest for an invalid statement — this is the
    /// enforcement point for "validate before anything is hashed into a
    /// challenge".
    pub fn digest(&self) -> Result<[u8; 32], StatementError> {
        self.validate()?;
        let mut hasher = Sha256::new();
        absorb_bytes(&mut hasher, STATEMENT_TAG.as_bytes());
        hasher.update(self.header.version.to_le_bytes());
        hasher.update(self.header.model_digest);
        let absorb_quant = |hasher: &mut Sha256, q: &QuantMeta| {
            hasher.update(q.bits.to_le_bytes());
            hasher.update(q.frac_bits.to_le_bytes());
            hasher.update([q.signed as u8]);
        };
        match &self.header.table {
            None => hasher.update([0u8]),
            Some(table) => {
                hasher.update([1u8]);
                hasher.update(table.digest);
                absorb_quant(&mut hasher, &table.input);
                absorb_quant(&mut hasher, &table.output);
                hasher.update(table.domain_min.to_le_bytes());
                hasher.update(table.domain_max.to_le_bytes());
            }
        }
        hasher.update(self.header.modulus_bits.to_le_bytes());
        hasher.update((self.quant.len() as u64).to_le_bytes());
        for q in &self.quant {
            absorb_quant(&mut hasher, q);
        }
        hasher.update((self.pad.len() as u64).to_le_bytes());
        for pad in &self.pad {
            hasher.update(pad.padded_rows.to_le_bytes());
            hasher.update(pad.padded_cols.to_le_bytes());
            hasher.update(pad.row_unit.to_le_bytes());
            hasher.update(pad.col_unit.to_le_bytes());
        }
        hasher.update((self.outputs.len() as u64).to_le_bytes());
        for output in &self.outputs {
            hasher.update(output.to_le_bytes());
        }
        hasher.update(self.manifest.digest());
        Ok(hasher.finalize().into())
    }
}

// ===========================================================================
// [U-S2] Statement v3 negative-vector battery (audit Phase 2 exit): every
// vector of the exit list — inconsistent fraction bits, the +2^(w-1)
// signed endpoint, cycles, empty add, wrong table digest/scale, dangling
// roles, noncanonical padding — plus the v3-new gates (empty operations,
// topological order, output visibility, modulus capacity) is REJECTED
// with the exact structured error, pre-crypto. Self-contained: entries
// carry dummy commitment bytes because validation is metadata-only.

/// Runs the battery, printing one line per vector; returns overall pass.
pub fn statement_negative_battery() -> bool {
    let q8 = QuantMeta { bits: 8, frac_bits: 4, signed: true };
    let plane = QuantMeta { bits: 1, frac_bits: 0, signed: false };

    // The base statement: a mini gate chain W X -> ACC -> rescale -> SiLU
    // lookup -> Hadamard, with the remainder's range fact. Valid under v3.
    let base = || -> Statement {
        let mut mf = ClaimManifest::new("statement-battery", b"battery-setup");
        let mut add_entry = |label: &str, rows: usize, cols: usize| -> u32 {
            mf.add_commitment(label, rows, cols, Orientation::RowMajor, vec![], vec![])
        };
        let w = add_entry("W", 4, 4);
        let x = add_entry("X", 4, 4);
        let acc = add_entry("ACC", 4, 4);
        let g8 = add_entry("G8", 4, 4);
        let r = add_entry("R", 4, 4);
        let r_bits = add_entry("R-bits", 16, 4);
        let a8 = add_entry("A8", 4, 4);
        let u8v = add_entry("U8", 4, 4);
        let h = add_entry("H", 4, 4);
        mf.add_operation(Operation::Matmul { a: w, b: x, c: acc });
        mf.add_operation(Operation::Rescale { x: acc, y: g8, r, shift: 4 });
        mf.add_operation(Operation::Binary { bits: r_bits });
        mf.add_operation(Operation::Range { value: r, bits: r_bits, width: 4, signed: false });
        mf.add_operation(Operation::Lookup { x: g8, y: a8 });
        mf.add_operation(Operation::Hadamard { x: a8, y: u8v, z: h });
        let mut st = Statement::new([9u8; 32], Some(SILU_INT8_TABLE_SPEC), 30, mf);
        st.quant = vec![
            q8,                                                   // W
            q8,                                                   // X
            QuantMeta { bits: 18, frac_bits: 8, signed: true },   // ACC
            q8,                                                   // G8 (lookup-narrowed)
            QuantMeta { bits: 4, frac_bits: 8, signed: false },   // R
            plane,                                                // R-bits
            q8,                                                   // A8
            q8,                                                   // U8
            QuantMeta { bits: 16, frac_bits: 8, signed: true },   // H
        ];
        st.pad = st
            .manifest
            .commitments
            .iter()
            .map(|e| PadSpec::exact(e.rows as usize, e.cols as usize))
            .collect();
        st.outputs = vec![h];
        st
    };

    let mut ok = true;
    use StatementError as SE;

    // Positive control: the honest base validates and digests
    // deterministically; any bound byte (a role label) moves the digest.
    let honest = base();
    match (honest.digest(), honest.digest()) {
        (Ok(d1), Ok(d2)) if d1 == d2 => {
            let mut relabeled = honest.clone();
            relabeled.manifest.commitments[0].label = "W'".to_string();
            match relabeled.digest() {
                Ok(d3) if d3 != d1 => {
                    println!("  ok   honest base validates; digest deterministic, label-sensitive")
                }
                Ok(_) => {
                    println!("  FAIL relabeled statement digest did not move");
                    ok = false;
                }
                Err(err) => {
                    println!("  FAIL relabeled statement does not validate: {err}");
                    ok = false;
                }
            }
        }
        (Err(err), _) => {
            println!("  FAIL honest base statement does not validate: {err}");
            ok = false;
        }
        _ => {
            println!("  FAIL statement digest is not deterministic");
            ok = false;
        }
    }

    let mut expect = |label: &str, st: &Statement, want: fn(&StatementError) -> bool| {
        match st.validate() {
            Ok(()) => {
                println!("  FAIL malicious statement accepted ({label})");
                ok = false;
            }
            Err(err) => {
                if want(&err) {
                    println!("  ok   statement rejects {label}: {err}");
                } else {
                    println!("  FAIL wrong rejection for {label}: {err}");
                    ok = false;
                }
            }
        }
    };

    // (1) Unknown format version.
    let mut bad = base();
    bad.header.version = 2;
    expect("retired statement version 2", &bad, |e| matches!(e, SE::UnknownVersion { got: 2 }));

    // (2) Empty operation list: a statement that claims nothing.
    let mut bad = base();
    bad.manifest.operations.clear();
    expect("empty operation list", &bad, |e| matches!(e, SE::EmptyOperations));

    // (3) Cyclic producer graph (operation order cannot repair it).
    let mut mf = ClaimManifest::new("statement-battery", b"cycle");
    let a = mf.add_commitment("A", 1, 1, Orientation::RowMajor, vec![], vec![]);
    let b = mf.add_commitment("B", 1, 1, Orientation::RowMajor, vec![], vec![]);
    mf.add_operation(Operation::Scale { input: a, output: b, scalar_le: vec![1] });
    mf.add_operation(Operation::Scale { input: b, output: a, scalar_le: vec![1] });
    let mut cycle = Statement::new([9u8; 32], None, 30, mf);
    cycle.quant = vec![QuantMeta { bits: 8, frac_bits: 0, signed: false }; 2];
    cycle.pad = vec![PadSpec::exact(1, 1); 2];
    expect("cyclic dataflow", &cycle, |e| matches!(e, SE::CyclicDataflow { .. }));

    // (4) Acyclic but misordered: the Hadamard consumes A8 before the
    // Lookup that produces it appears.
    let mut bad = base();
    bad.manifest.operations.swap(4, 5);
    expect("non-topological operation order", &bad, |e| {
        matches!(e, SE::NotTopologicallyOrdered { id: 6, .. })
    });

    // (5) Empty Add constrains its output to nothing.
    let mut bad = base();
    bad.manifest.operations.push(Operation::Add { inputs: vec![], output: 8 });
    expect("empty Add", &bad, |e| matches!(e, SE::EmptyAdd { .. }));

    // (6) The +2^(w-1) signed endpoint: 4096 int8 x int8 products reach
    // +2^26 ((-128)*(-128) pairs), which a signed 27-bit accumulator's
    // positive side cannot hold. A symmetric magnitude model accepts this;
    // asymmetric bounds reject it.
    let mut mf = ClaimManifest::new("statement-battery", b"endpoint");
    let a = mf.add_commitment("A", 1, 4096, Orientation::RowMajor, vec![], vec![]);
    let b = mf.add_commitment("B", 4096, 1, Orientation::RowMajor, vec![], vec![]);
    let c = mf.add_commitment("C", 1, 1, Orientation::RowMajor, vec![], vec![]);
    mf.add_operation(Operation::Matmul { a, b, c });
    let mut endpoint = Statement::new([9u8; 32], None, 30, mf);
    endpoint.quant = vec![q8, q8, QuantMeta { bits: 27, frac_bits: 8, signed: true }];
    endpoint.pad = vec![PadSpec::exact(1, 4096), PadSpec::exact(4096, 1), PadSpec::exact(1, 1)];
    endpoint.outputs = vec![c];
    expect("signed +2^(w-1) accumulator endpoint", &endpoint, |e| {
        matches!(e, SE::QuantMismatch { field: "matmul accumulator width", .. })
    });

    // (7) Inconsistent fraction bits, rescale: the lookup-narrowing fact
    // on G8 must NOT waive the scale equation (C-03a).
    let mut bad = base();
    bad.quant[3].frac_bits = 3;
    expect("rescale fraction-bit lie under a narrowing fact", &bad, |e| {
        matches!(e, SE::QuantMismatch { field: "rescale fraction bits", .. })
    });

    // (8) Inconsistent fraction bits, matmul.
    let mut bad = base();
    bad.quant[2].frac_bits = 7;
    expect("matmul fraction-bit lie", &bad, |e| {
        matches!(e, SE::QuantMismatch { field: "matmul fraction bits", .. })
    });

    // (9) Wrong table digest: nonzero but not the frozen SiLU table.
    let mut bad = base();
    bad.header.table = Some(TableSpec { digest: [7u8; 32], ..SILU_INT8_TABLE_SPEC });
    expect("attacker-chosen table digest", &bad, |e| matches!(e, SE::TableDigestMismatch));

    // (10) Wrong table scale: right digest, lying quantization metadata.
    let mut bad = base();
    bad.header.table = Some(TableSpec {
        input: QuantMeta { bits: 8, frac_bits: 3, signed: true },
        ..SILU_INT8_TABLE_SPEC
    });
    expect("table spec scale lie", &bad, |e| matches!(e, SE::TableSpecMismatch));

    // (11) Lookup image scale off the frozen spec.
    let mut bad = base();
    bad.quant[6].frac_bits = 3;
    expect("lookup image scale mismatch", &bad, |e| {
        matches!(e, SE::QuantMismatch { field: "lookup image quant", .. })
    });

    // (12) Lookup with no bound table spec at all.
    let mut bad = base();
    bad.header.table = None;
    expect("lookup without a table spec", &bad, |e| matches!(e, SE::MissingTableDigest));

    // (13) Dangling role: an operation names a commitment nobody made.
    let mut bad = base();
    bad.manifest.operations.push(Operation::Binary { bits: 99 });
    expect("dangling operand id", &bad, |e| matches!(e, SE::DanglingId { id: 99, .. }));

    // (14) Dangling entry: committed but appearing in no operation.
    let mut bad = base();
    bad.manifest.add_commitment("orphan", 4, 4, Orientation::RowMajor, vec![], vec![]);
    bad.quant.push(q8);
    bad.pad.push(PadSpec::exact(4, 4));
    expect("orphan entry", &bad, |e| matches!(e, SE::OrphanEntry { .. }));

    // (15) Dangling output role: declared output nobody produces.
    let mut bad = base();
    bad.outputs = vec![1];
    expect("output produced by no operation", &bad, |e| {
        matches!(e, SE::OutputNotProduced { id: 1 })
    });

    // (16) A produced tensor that silently drops out of the statement.
    let mut bad = base();
    bad.outputs = vec![4];
    expect("produced-but-unconsumed tensor", &bad, |e| {
        matches!(e, SE::UnconsumedEntry { id: 8 })
    });

    // (17) No declared outputs: no visible result.
    let mut bad = base();
    bad.outputs.clear();
    expect("no declared outputs", &bad, |e| matches!(e, SE::NoOutputs));

    // (18) Noncanonical padding: slack rows beyond the next unit multiple.
    let mut bad = base();
    bad.pad[0].padded_rows = 8;
    expect("noncanonical padding", &bad, |e| matches!(e, SE::NoncanonicalPadding { id: 0 }));

    // (19) Missing padding declaration.
    let mut bad = base();
    bad.pad.pop();
    expect("missing padding record", &bad, |e| matches!(e, SE::PadCount { .. }));

    // (20) Modulus injection: a declared type wider than the modulus.
    let mut bad = base();
    bad.quant[2].bits = 40;
    expect("entry wider than the modulus", &bad, |e| matches!(e, SE::ModulusCapacity { id: 2 }));

    // (21) Modulus window: a range-narrowed Hadamard whose PRE-narrowing
    // interval wraps an 8-bit modulus — the fact cannot ground the
    // integer identity there.
    let mut mf = ClaimManifest::new("statement-battery", b"window");
    let x = mf.add_commitment("X", 1, 1, Orientation::RowMajor, vec![], vec![]);
    let y = mf.add_commitment("Y", 1, 1, Orientation::RowMajor, vec![], vec![]);
    let z = mf.add_commitment("Z", 1, 1, Orientation::RowMajor, vec![], vec![]);
    let z_bits = mf.add_commitment("Z-bits", 8, 1, Orientation::RowMajor, vec![], vec![]);
    mf.add_operation(Operation::Hadamard { x, y, z });
    mf.add_operation(Operation::Binary { bits: z_bits });
    mf.add_operation(Operation::Range { value: z, bits: z_bits, width: 8, signed: false });
    let mut window = Statement::new([9u8; 32], None, 8, mf);
    window.quant = vec![
        QuantMeta { bits: 8, frac_bits: 0, signed: true },
        QuantMeta { bits: 8, frac_bits: 0, signed: true },
        QuantMeta { bits: 8, frac_bits: 0, signed: false },
        plane,
    ];
    window.pad = vec![
        PadSpec::exact(1, 1),
        PadSpec::exact(1, 1),
        PadSpec::exact(1, 1),
        PadSpec::exact(8, 1),
    ];
    window.outputs = vec![z];
    expect("narrowed product escaping the modulus window", &window, |e| {
        matches!(e, SE::QuantMismatch { field: "modulus capacity", .. })
    });

    // (22) Unproven narrowing: a signed product declared unsigned with no
    // fact backing the sign change.
    let mut bad = base();
    bad.quant[8].signed = false;
    expect("unproven sign narrowing", &bad, |e| {
        matches!(e, SE::QuantMismatch { field: "hadamard signedness", .. })
    });

    if ok {
        println!("statement-negatives passed");
    } else {
        println!("statement-negatives FAILED");
    }
    ok
}
