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
    /// [UAGB1-BF, v4 only] Elementwise activation through table index
    /// `table` of the statement's `tables` vector (the per-scale table
    /// FAMILY — D3-F1). Same lookup semantics as `Lookup`, with the
    /// table chosen per operation so one statement can host per-layer
    /// activation scales. Every referenced spec must equal a FROZEN
    /// registry member exactly.
    LookupAt { x: u32, y: u32, table: u32 },
    /// [UAGB1-BF, v4 only] Range fact discharged by a range-TABLE lookup
    /// instance (the U-R2 exact q31 mechanism): `value` is proven to lie
    /// in its declared `width`/`signed` type's range by a [0, 2^width)
    /// table lookup over its (offset) codes — no bit-plane entry, no
    /// Binary fact. The proving layer owes one masked lookup instance
    /// per RangeLookup operation.
    RangeLookup { value: u32, width: u32, signed: bool },
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
                // [UAGB1-BF] v4-only operations: NEW tags, never emitted
                // by v3 statements — every pre-existing digest is unmoved.
                Operation::LookupAt { x, y, table } => {
                    hasher.update([12u8]);
                    hasher.update(x.to_le_bytes());
                    hasher.update(y.to_le_bytes());
                    hasher.update(table.to_le_bytes());
                }
                Operation::RangeLookup { value, width, signed } => {
                    hasher.update([13u8]);
                    hasher.update(value.to_le_bytes());
                    hasher.update(width.to_le_bytes());
                    hasher.update([*signed as u8]);
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
/// [UAGB1-BF] v4 = typed integer semantics with signed scale exponents,
/// symmetric-range declarations, E-O1-BB class/base fields and the
/// activation-table family. v3 stays fully valid under its own rules.
pub const STATEMENT_VERSION_V4: u32 = 4;
const STATEMENT_TAG_V4: &str = "zkmatrix-statement-v4";

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

// ===========================================================================
// [UAGB1-BF] Statement v4 — the ONE versioned codec change deferred by
// lane BB (E-O1-BB: "typed v3 class/base fields ... to the pass statement
// in one versioned codec change"). v4 adds, per entry, the typed fields
// v3's QuantMeta cannot express (findings D3-F2 + the BC symmetric-range
// export), plus the E-O1-BB digit class/base declarations, plus a table
// FAMILY so per-layer activation scales fit one statement (D3-F1):
//
//   - `scale_exp: i32` — the SIGNED scale exponent: value = raw *
//     2^scale_exp. v3's frac_bits is the special case scale_exp =
//     -frac_bits; the calibrated eZ = +1 / eH = +2 layers are now
//     expressible without clamping or widened storage.
//   - `symmetric: bool` — the int8-symmetric range declaration: a signed
//     entry with `symmetric` covers [-(2^(b-1)-1), 2^(b-1)-1], the
//     contract's forced [-127, 127] reading (M125_CALIBRATION_STUDY
//     Section 1). Interval arithmetic then DERIVES the honest 25-bit
//     (inner 768) / 26-bit (inner 2048) accumulator widths — the
//     asymmetric declared-type reading gives 25/27 and stays available
//     as symmetric = false.
//   - `class: u32`, `base_e0: u32` — the E-O1-BB per-entry value-width
//     class and digit-base declaration (AGGREGATION_ENCODING_DESIGN
//     Section 8.1: frozen widths + adopted bases; weight e0 = 1
//     sign-binary per F-N2, activation/accumulator/aux e0 = 2). The
//     validator pins base_e0 to the class and the class window to the
//     declared type — wrong-class and wrong-base statements REJECT
//     before any crypto.
//
// Version gate: v3 statements validate under the UNCHANGED v3 rules and
// their digest/codec bytes DO NOT MOVE (the v3 paths below are
// byte-for-byte the pre-v4 code); v4 uses a new digest tag and codec
// container version. v4-only operations: LookupAt (table family),
// RangeLookup (the U-R2 range-table fact form — no bit planes).

/// v4 per-entry typing extension. For a v4 statement `typing.len()`
/// equals the entry count and entry i's full type is
/// (quant[i].bits, quant[i].signed, typing[i]); quant[i].frac_bits must
/// be 0 (the scale lives HERE — one source of truth on the wire).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct TypingV4 {
    /// Signed scale exponent: represented value = raw * 2^scale_exp.
    pub scale_exp: i32,
    /// Signed entries only: raw range is +-(2^(bits-1) - 1) (the
    /// [-127,127]-style symmetric declaration). Must be false unsigned.
    pub symmetric: bool,
    /// E-O1-BB value-width class id (the CLS_* registry below).
    pub class: u32,
    /// E-O1-BB digit-base declaration; must equal the class's pinned e0.
    pub base_e0: u32,
}

/// [UAGB1-BG] The per-deployment privacy-mode declaration (TARGET_
/// CONTRACT Amendment A1 / ZK_GAP_OPTIONS Section 6): the declared
/// private set is a first-class statement field, never a silent
/// default. mode: 0 = P0 (nothing private), 1 = P1 (inputs/acts
/// private), 2 = P2 (weights private — the accumulation-critical
/// class), 3 = P3 (both). `private_entries` lists the declared-private
/// commitment entry ids (sorted, deduplicated). ADDITIVE discipline:
/// a statement with `mode == None` digests AND serializes byte-
/// identically to a pre-BG statement (enforced by freeze rows
/// UAGB1-BG-1*); when Some, digest and wire carry a trailing tagged
/// section. Declaration-consistency rules live in validate(); WHICH
/// modes a prover can actually run is the composition layer's gate
/// (wave 3: P0 and P2 only — P1/P3 refuse loudly there).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ModeDecl {
    pub mode: u8,
    pub private_entries: Vec<u32>,
}

pub const MODE_P0: u8 = 0;
pub const MODE_P1: u8 = 1;
pub const MODE_P2: u8 = 2;
pub const MODE_P3: u8 = 3;

/// The frozen v4 class registry (E-O1-BB; ids are wire values and MUST
/// NOT be renumbered). Sources: AGGREGATION_ENCODING_DESIGN 8.1 frozen
/// value-width classes + adopted digit bases (weight e0 = 1 sign-binary
/// F-N2; everything else e0 = 2), aligned with the D1 exact-digit class
/// table (ring/digits.rs, freeze row UAGB1-1a).
pub const CLS_W8S: u32 = 1; // weight int8, signed, bits <= 8, e0 = 1
pub const CLS_ACT8: u32 = 2; // activation int8 (signed or offset-unsigned), bits <= 8, e0 = 2
pub const CLS_ACC: u32 = 3; // wide signed accumulator/product, bits <= 31, e0 = 2
pub const CLS_REM: u32 = 4; // unsigned requant remainder, bits <= 16, e0 = 2
pub const CLS_AUX31: u32 = 5; // full-column q31 aux, bits <= 31, e0 = 2

/// (class id, pinned e0, max bits, signedness constraint) rows;
/// signedness: Some(true) = must be signed, Some(false) = must be
/// unsigned, None = either.
pub const V4_CLASS_TABLE: [(u32, u32, u32, Option<bool>); 5] = [
    (CLS_W8S, 1, 8, Some(true)),
    (CLS_ACT8, 2, 8, None),
    (CLS_ACC, 2, 31, Some(true)),
    (CLS_REM, 2, 16, Some(false)),
    (CLS_AUX31, 2, 31, None),
];

/// [UAGB1-BF] The frozen per-scale SiLU family digests (v2 spec headers;
/// ring/lookup.rs::table_spec_digest_v2 — the UAGB1-BF-2a freeze row
/// cross-checks these copies against the generating side, the same
/// duplicated-constant discipline as SILU_INT8_TABLE_DIGEST).
pub const SILU_V2_M3_TABLE_DIGEST: [u8; 32] = [
    0xbd, 0xf8, 0xbc, 0x71, 0x29, 0xdc, 0x6e, 0xc8,
    0xb0, 0x02, 0xaf, 0x51, 0xfd, 0x4d, 0xbe, 0xf3,
    0xd7, 0xc1, 0x24, 0x0f, 0x65, 0xc4, 0xda, 0x01,
    0xce, 0x2d, 0xb2, 0xa7, 0xc9, 0xbb, 0x6c, 0x50,
];
pub const SILU_V2_M4_TABLE_DIGEST: [u8; 32] = [
    0x06, 0x39, 0x93, 0x48, 0x1a, 0x8f, 0xc0, 0x08,
    0x70, 0x14, 0xb2, 0x53, 0x57, 0xa2, 0x2b, 0x95,
    0xd8, 0x8b, 0xda, 0x64, 0x9c, 0xc6, 0x99, 0x7e,
    0x2f, 0xe2, 0x7c, 0x5b, 0xac, 0xd1, 0x7a, 0xda,
];

/// The (-3,-3) family member's typed spec (10 of the 12 calibrated 125M
/// layers). frac_bits carries -scale_exp; v4 operand matching converts.
pub const SILU_V2_M3_TABLE_SPEC: TableSpec = TableSpec {
    digest: SILU_V2_M3_TABLE_DIGEST,
    input: QuantMeta { bits: 8, frac_bits: 3, signed: true },
    output: QuantMeta { bits: 8, frac_bits: 3, signed: true },
    domain_min: -128,
    domain_max: 127,
};

/// The (-4,-4) family member (calibrated layers 1 and 4). Its BYTES are
/// the v1 table (family identity, freeze row UAGB1-BF-1b); the digest
/// differs from v1's only via the v2 header format.
pub const SILU_V2_M4_TABLE_SPEC: TableSpec = TableSpec {
    digest: SILU_V2_M4_TABLE_DIGEST,
    input: QuantMeta { bits: 8, frac_bits: 4, signed: true },
    output: QuantMeta { bits: 8, frac_bits: 4, signed: true },
    domain_min: -128,
    domain_max: 127,
};

/// The frozen table registry a v4 statement's `tables` entries must come
/// from (exact equality, the C-03c discipline extended to the family).
pub fn v4_table_registry() -> [TableSpec; 3] {
    [SILU_INT8_TABLE_SPEC, SILU_V2_M3_TABLE_SPEC, SILU_V2_M4_TABLE_SPEC]
}

// ===========================================================================
// [UPERF3-BB C5] The v3 statement profile's INT16-OUTPUT table members
// (TARGET_CONTRACT §2 v3 + the widened-stack amendment — ADOPTED,
// Victor's ruling of record 2026-08-26; the C5 registry additions ride
// that ruling). ADDITIVE and VERSIONED: nothing above this line moves —
// v4_table_registry() and every v4 statement's digest/codec bytes are
// unchanged; the members below are reachable only through the NEW
// uperf3_v3_table_registry(), which only v3-profile statements consult.
// PROVISIONAL member set (reconciled with lane AA's generation script
// when it lands): the distinct calibrated (eGate, eA) pairs of the two
// measured checkpoints at e_out = eA - 8 — Mistral-7B's 9 silu pairs +
// Gemma-4-12B's 6 gelu_pytorch_tanh pairs; the m125 pass's two pairs
// map to (-3, -11)/(-4, -12), both present. Duplicated-constant
// discipline (UAGB1-BF-2a): these digests are independent copies of
// ring/lookup.rs::SILU16_V3_DIGESTS / GELU16_V3_DIGESTS; the
// freeze_check_uperf3_bb rows cross-check the two files against each
// other AND against regeneration.

/// (e_in = eGate, e_out = eA - 8) of the frozen silu int16-out members.
pub const UPERF3_SILU16_MEMBERS: [(i32, i32); 9] = [
    (-5, -13), (-4, -13), (-4, -12), (-3, -12), (-3, -11), (-2, -11), (-1, -11), (-1, -10),
    (-1, -9),
];
#[rustfmt::skip]
pub const UPERF3_SILU16_TABLE_DIGESTS: [[u8; 32]; 9] = [
    // (-5, -13)
    [
    0xbf, 0x3e, 0xb0, 0x4e, 0xee, 0xee, 0xc8, 0x44, 0xa3, 0x13, 0xbe, 0x91, 0x34, 0x80, 0x60, 0x6b,
    0x4b, 0x79, 0x2c, 0xdf, 0x6f, 0x26, 0x90, 0x2b, 0xbb, 0x7f, 0xea, 0x4e, 0x57, 0x1b, 0x92, 0xbc,
    ],
    // (-4, -13)
    [
    0x0c, 0x74, 0xb0, 0xe6, 0xfb, 0x57, 0xdd, 0x67, 0xa4, 0x9c, 0x61, 0xbe, 0xf5, 0xda, 0xe0, 0x93,
    0xf6, 0xce, 0x15, 0x4d, 0x6f, 0x33, 0x1b, 0xd6, 0x5d, 0x0d, 0x54, 0x8f, 0xaf, 0x0e, 0xca, 0x60,
    ],
    // (-4, -12)
    [
    0xaf, 0xed, 0x7d, 0xc5, 0xc2, 0x89, 0xcb, 0xdb, 0x18, 0xfb, 0xf5, 0xd7, 0x94, 0x28, 0x5b, 0xa5,
    0x90, 0x1e, 0xbe, 0x43, 0xe9, 0xe5, 0x61, 0xaa, 0xd6, 0xec, 0x32, 0x98, 0x7f, 0xa6, 0x6d, 0x54,
    ],
    // (-3, -12)
    [
    0x85, 0x93, 0x44, 0xba, 0x5e, 0xd5, 0x7b, 0xd3, 0xf8, 0x31, 0xc9, 0x08, 0x2e, 0x59, 0x91, 0xfe,
    0x70, 0x12, 0xa0, 0xc5, 0x69, 0x6c, 0xfa, 0x70, 0x53, 0x20, 0xff, 0xdb, 0x6c, 0xb1, 0x7a, 0x25,
    ],
    // (-3, -11)
    [
    0x10, 0x01, 0xc1, 0x38, 0xce, 0x0d, 0x00, 0xf0, 0x93, 0x90, 0xb3, 0x61, 0x78, 0x04, 0x4d, 0x72,
    0x71, 0x2f, 0xbd, 0xca, 0x10, 0x71, 0x46, 0x7e, 0xa2, 0x74, 0xdc, 0x98, 0x0b, 0xd9, 0xa3, 0xf7,
    ],
    // (-2, -11)
    [
    0xed, 0xa5, 0xf3, 0x4a, 0x1c, 0x0d, 0xd9, 0x4c, 0xe7, 0x39, 0x8d, 0x67, 0x62, 0x20, 0x2e, 0xd8,
    0x5e, 0x3f, 0x6f, 0x2c, 0x49, 0x84, 0xa5, 0xb0, 0x7a, 0xca, 0x57, 0xb0, 0x0b, 0x30, 0xba, 0x56,
    ],
    // (-1, -11)
    [
    0x49, 0x32, 0x02, 0xf2, 0xd8, 0x9b, 0x0f, 0xfe, 0x79, 0x81, 0xde, 0xcf, 0xb8, 0x18, 0xaa, 0xfa,
    0xac, 0xea, 0x4c, 0xcc, 0xb1, 0x17, 0xd7, 0x58, 0xb9, 0xe6, 0xb4, 0x16, 0x46, 0x3d, 0x9a, 0x4b,
    ],
    // (-1, -10)
    [
    0x53, 0x23, 0xca, 0x1b, 0xd1, 0x09, 0x1e, 0xc1, 0x8b, 0xf5, 0x03, 0x6c, 0xa7, 0xea, 0x4e, 0x00,
    0x72, 0x24, 0xeb, 0xc3, 0xa2, 0x6a, 0xd5, 0x67, 0x59, 0xa4, 0xb9, 0xda, 0x0c, 0x41, 0x9a, 0x79,
    ],
    // (-1, -9)
    [
    0xd8, 0x35, 0x99, 0x89, 0x09, 0xad, 0xcd, 0x25, 0xdc, 0xc7, 0xeb, 0xa1, 0x02, 0x39, 0xe8, 0x2e,
    0xa0, 0x32, 0x34, 0x37, 0xb5, 0xba, 0x41, 0x9d, 0x9f, 0xa5, 0xc2, 0x8e, 0x6f, 0xa6, 0xc6, 0x89,
    ],
];

/// (e_in = eGate, e_out = eA - 8) of the frozen gelu_pytorch_tanh
/// int16-out members.
pub const UPERF3_GELU16_MEMBERS: [(i32, i32); 6] =
    [(-4, -12), (-3, -12), (-3, -11), (-2, -11), (-2, -10), (-1, -9)];
#[rustfmt::skip]
pub const UPERF3_GELU16_TABLE_DIGESTS: [[u8; 32]; 6] = [
    // (-4, -12)
    [
    0x13, 0xec, 0xf1, 0x1e, 0x56, 0x08, 0xd6, 0x03, 0x2a, 0xe9, 0xe3, 0xe1, 0x19, 0x97, 0x4e, 0x0f,
    0x22, 0xa6, 0x8f, 0xee, 0x70, 0x62, 0x4d, 0x22, 0x95, 0x87, 0x1b, 0x7e, 0x6f, 0x5e, 0xc1, 0xdf,
    ],
    // (-3, -12)
    [
    0x37, 0x55, 0x8a, 0x0d, 0x99, 0xcb, 0x5a, 0x22, 0x6f, 0x4f, 0x8e, 0xf4, 0x8f, 0x50, 0x4e, 0x09,
    0x72, 0x49, 0xdf, 0xfd, 0xa5, 0x4a, 0x9c, 0x56, 0x3d, 0xe2, 0xde, 0x4e, 0x66, 0x38, 0xea, 0x6b,
    ],
    // (-3, -11)
    [
    0x4c, 0x81, 0x1e, 0x7d, 0x93, 0xde, 0x21, 0xa9, 0xbd, 0x2c, 0xd9, 0x25, 0xed, 0x7b, 0x4a, 0xbb,
    0x87, 0xaf, 0xda, 0x22, 0x9e, 0xe4, 0x9a, 0xdd, 0x8c, 0x22, 0xab, 0xec, 0x4b, 0x32, 0xfb, 0x1a,
    ],
    // (-2, -11)
    [
    0xf9, 0xee, 0xfe, 0xf1, 0xe2, 0xe9, 0xe6, 0x6d, 0x11, 0xa8, 0x21, 0xd3, 0xfe, 0xc7, 0xf4, 0x56,
    0x7e, 0x2e, 0x93, 0x6b, 0x58, 0x17, 0xf2, 0xd1, 0x57, 0x72, 0x53, 0x01, 0xd3, 0x3b, 0x0a, 0x15,
    ],
    // (-2, -10)
    [
    0x77, 0x5e, 0x02, 0x3b, 0x20, 0xb4, 0x41, 0x26, 0x8b, 0x90, 0x37, 0xc0, 0xf8, 0x26, 0xd4, 0x37,
    0x80, 0x44, 0x99, 0x17, 0x90, 0xe3, 0x22, 0x74, 0xe1, 0xd6, 0x13, 0xc3, 0xb4, 0xde, 0x5e, 0x09,
    ],
    // (-1, -9)
    [
    0x04, 0x6e, 0xff, 0xd4, 0x33, 0xa6, 0xca, 0x20, 0x41, 0x31, 0xa2, 0x5e, 0xd3, 0xe0, 0x63, 0x43,
    0x23, 0x6b, 0x5e, 0xb7, 0x7e, 0x2a, 0x0e, 0x6d, 0x56, 0x2d, 0x8a, 0xf7, 0x3c, 0xc2, 0x9e, 0xab,
    ],
];

/// The typed spec of one int16-out member: int8 domain (256 rows,
/// [-128, 127]), int16 output at e_out = eA - 8. frac_bits carries
/// -scale_exp (both exponents are negative on every frozen member);
/// v3-profile operand matching converts, exactly the SILU_V2 pattern.
fn uperf3_int16out_spec(e_in: i32, e_out: i32, digest: [u8; 32]) -> TableSpec {
    assert!(e_in < 0 && e_out < 0, "frozen int16-out members carry negative exponents");
    TableSpec {
        digest,
        input: QuantMeta { bits: 8, frac_bits: (-e_in) as u32, signed: true },
        output: QuantMeta { bits: 16, frac_bits: (-e_out) as u32, signed: true },
        domain_min: -128,
        domain_max: 127,
    }
}

/// The frozen table registry of the v3 STATEMENT PROFILE: the complete
/// v4 registry (unchanged, same order) followed by the silu then gelu
/// int16-out members in member order. Only v3-profile statements
/// consult this; v4 statements keep v4_table_registry().
pub fn uperf3_v3_table_registry() -> Vec<TableSpec> {
    let mut out: Vec<TableSpec> = v4_table_registry().to_vec();
    for (i, &(ei, eo)) in UPERF3_SILU16_MEMBERS.iter().enumerate() {
        out.push(uperf3_int16out_spec(ei, eo, UPERF3_SILU16_TABLE_DIGESTS[i]));
    }
    for (i, &(ei, eo)) in UPERF3_GELU16_MEMBERS.iter().enumerate() {
        out.push(uperf3_int16out_spec(ei, eo, UPERF3_GELU16_TABLE_DIGESTS[i]));
    }
    out
}

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
    /// [UAGB1-BF] v4 per-entry typing (empty and forbidden for v3).
    pub typing: Vec<TypingV4>,
    /// [UAGB1-BF] v4 table family (empty and forbidden for v3; every
    /// entry must equal a `v4_table_registry()` member exactly).
    pub tables: Vec<TableSpec>,
    /// [UAGB1-BG] Optional per-deployment privacy-mode declaration
    /// (Amendment A1). None = no declaration — digest and wire bytes
    /// are byte-identical to the pre-BG statement (additive-only).
    pub mode: Option<ModeDecl>,
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
    /// [UAGB1-BF, v4] typing.len() != entry count (v4), or typing/tables
    /// nonempty on a v3 statement.
    TypingCount { entries: usize, typings: usize },
    /// [UAGB1-BF, v4] A typed-field rule violated at entry `id`; `field`
    /// names the rule (nonzero v3 frac_bits, symmetric-on-unsigned, ...).
    TypingViolation { id: u32, field: &'static str },
    /// [UAGB1-BF, v4] An entry's declared class does not exist or its
    /// window/signedness does not cover the declared type (E-O1-BB
    /// wrong-class vector).
    WrongClass { id: u32 },
    /// [UAGB1-BF, v4] An entry's declared digit base differs from its
    /// class's pinned e0 (E-O1-BB wrong-base vector; weight e0 = 1 is
    /// F-N2-mandated).
    WrongBase { id: u32 },
    /// [UAGB1-BF, v4] LookupAt names a table index outside `tables`.
    TableIndex { op: usize, table: u32 },
    /// [UAGB1-BF, v4] A `tables` entry equals no frozen registry member.
    TableNotFrozen { index: usize },
    /// [UAGB1-BF] An operation is not admissible under the statement's
    /// version (LookupAt/RangeLookup in v3; plain Lookup in v4).
    VersionedOperation { op: usize },
    /// [UAGB1-BG] The privacy-mode declaration is inconsistent; `rule`
    /// names the violated rule (bad mode id, v3 statement, unsorted or
    /// unknown ids, or a mode/private-set mismatch: P0 = empty, P1 =
    /// nonempty excluding every weight-class entry, P2 = exactly the
    /// weight-class entries, P3 = every entry).
    ModeDeclInvalid { rule: &'static str },
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
            StatementError::TypingCount { entries, typings } => {
                write!(f, "{entries} entries but {typings} v4 typing records")
            }
            StatementError::TypingViolation { id, field } => {
                write!(f, "v4 typing rule '{field}' violated at entry {id}")
            }
            StatementError::WrongClass { id } => {
                write!(f, "entry {id} declares a class that does not cover its type (E-O1-BB)")
            }
            StatementError::WrongBase { id } => {
                write!(f, "entry {id} declares a digit base off its class's pinned e0 (E-O1-BB)")
            }
            StatementError::TableIndex { op, table } => {
                write!(f, "operation {op} references table index {table} outside the family")
            }
            StatementError::TableNotFrozen { index } => {
                write!(f, "tables[{index}] equals no frozen registry member")
            }
            StatementError::ModeDeclInvalid { rule } => {
                write!(f, "privacy-mode declaration invalid: {rule}")
            }
            StatementError::VersionedOperation { op } => {
                write!(f, "operation {op} is not admissible under this statement version")
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

// ===========================================================================
// U-S Phase 3 (P3-D1/D2/D4): canonical PublicStatement serialization. A
// versioned, length-prefixed, little-endian byte codec with hard decode-
// time resource limits and structured, panic-free errors. `Statement` IS
// the PublicStatement (its v3 `digest()` is the sole transcript context);
// these methods are its canonical wire form.

const STATEMENT_CODEC_MAGIC: &[u8; 4] = b"ZKMS";
const STATEMENT_CODEC_VERSION: u32 = 1;
/// [UAGB1-BF] Container version of the v4 statement layout (adds the
/// per-entry typing records and the table family after the outputs).
const STATEMENT_CODEC_VERSION_V4: u32 = 2;

// Absolute decode caps (independent of the wire). A well-formed statement
// for any admissible model is far below these; the caps bound allocation
// against a hostile length prefix. Every length is ALSO checked against the
// bytes remaining (a vec of >=1-byte items cannot exceed the buffer).
const MAX_COMMITMENTS: usize = 1 << 24;
const MAX_OPERATIONS: usize = 1 << 24;
const MAX_ENTRIES: usize = 1 << 24;
const MAX_LABEL_LEN: usize = 4096;
const MAX_SETUP_LEN: usize = 1 << 16;
const MAX_KEYINFO_LEN: usize = 1 << 16;
const MAX_COMMIT_BYTES_LEN: usize = 1 << 20;
const MAX_OP_VEC_LEN: usize = 1 << 24;
const MAX_SCALAR_LEN: usize = 64;

/// Structured decode failure (never a panic). Distinct from
/// `StatementError` (semantic validation) which it wraps via `Invalid`.
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum DecodeError {
    /// Fewer bytes remain than the field requires.
    Truncated { needed: usize, have: usize },
    /// Bytes remain after a complete decode (reject-don't-truncate).
    TrailingBytes { extra: usize },
    /// The leading magic is not `ZKMS`.
    BadMagic,
    /// Codec container version is not understood.
    UnknownCodecVersion { got: u32 },
    /// A length prefix exceeds its hard cap or the bytes remaining.
    LengthTooLarge { ctx: &'static str, got: u64, cap: usize },
    /// An enum tag byte is out of range.
    BadTag { ctx: &'static str, tag: u8 },
    /// A length-prefixed string is not valid UTF-8.
    BadUtf8,
    /// The decoded statement failed semantic validation.
    Invalid(StatementError),
}

impl std::fmt::Display for DecodeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DecodeError::Truncated { needed, have } => {
                write!(f, "truncated: needed {needed} bytes, {have} remain")
            }
            DecodeError::TrailingBytes { extra } => write!(f, "{extra} trailing bytes after decode"),
            DecodeError::BadMagic => write!(f, "bad magic (not a ZKMS statement)"),
            DecodeError::UnknownCodecVersion { got } => write!(f, "unknown codec version {got}"),
            DecodeError::LengthTooLarge { ctx, got, cap } => {
                write!(f, "length {got} for {ctx} exceeds cap {cap}")
            }
            DecodeError::BadTag { ctx, tag } => write!(f, "bad {ctx} tag {tag}"),
            DecodeError::BadUtf8 => write!(f, "invalid utf-8 in a string field"),
            DecodeError::Invalid(e) => write!(f, "decoded statement is invalid: {e}"),
        }
    }
}

/// A canonical little-endian writer (infallible).
struct StatementWriter {
    buf: Vec<u8>,
}
impl StatementWriter {
    fn new() -> Self {
        StatementWriter { buf: Vec::new() }
    }
    fn raw(&mut self, b: &[u8]) {
        self.buf.extend_from_slice(b);
    }
    fn u8(&mut self, v: u8) {
        self.buf.push(v);
    }
    fn u32(&mut self, v: u32) {
        self.buf.extend_from_slice(&v.to_le_bytes());
    }
    fn u64(&mut self, v: u64) {
        self.buf.extend_from_slice(&v.to_le_bytes());
    }
    fn i64(&mut self, v: i64) {
        self.buf.extend_from_slice(&v.to_le_bytes());
    }
    fn bytes(&mut self, b: &[u8]) {
        self.u32(b.len() as u32);
        self.raw(b);
    }
    fn string(&mut self, s: &str) {
        self.bytes(s.as_bytes());
    }
    fn quant(&mut self, q: &QuantMeta) {
        self.u32(q.bits);
        self.u32(q.frac_bits);
        self.u8(q.signed as u8);
    }
    fn into_vec(self) -> Vec<u8> {
        self.buf
    }
}

/// A bounds-checked little-endian reader. Every accessor validates the
/// remaining length before reading; nothing panics on hostile input.
struct ByteReader<'a> {
    buf: &'a [u8],
    pos: usize,
}
impl<'a> ByteReader<'a> {
    fn new(buf: &'a [u8]) -> Self {
        ByteReader { buf, pos: 0 }
    }
    fn remaining(&self) -> usize {
        self.buf.len() - self.pos
    }
    /// [UAGB1-BG] Non-consuming look at the next byte (the optional
    /// trailing mode-declaration section's tag gate).
    fn peek_u8(&self) -> Option<u8> {
        self.buf.get(self.pos).copied()
    }
    fn take(&mut self, n: usize) -> Result<&'a [u8], DecodeError> {
        if n > self.remaining() {
            return Err(DecodeError::Truncated { needed: n, have: self.remaining() });
        }
        let s = &self.buf[self.pos..self.pos + n];
        self.pos += n;
        Ok(s)
    }
    fn u8(&mut self) -> Result<u8, DecodeError> {
        Ok(self.take(1)?[0])
    }
    fn u32(&mut self) -> Result<u32, DecodeError> {
        Ok(u32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }
    fn u64(&mut self) -> Result<u64, DecodeError> {
        Ok(u64::from_le_bytes(self.take(8)?.try_into().unwrap()))
    }
    fn i64(&mut self) -> Result<i64, DecodeError> {
        Ok(i64::from_le_bytes(self.take(8)?.try_into().unwrap()))
    }
    fn bytes32(&mut self) -> Result<[u8; 32], DecodeError> {
        Ok(self.take(32)?.try_into().unwrap())
    }
    /// Read a u32 length prefix and check it against a hard cap AND the
    /// bytes remaining (a vec of >=1-byte items cannot exceed the buffer).
    fn len(&mut self, cap: usize) -> Result<usize, DecodeError> {
        self.len_ctx("length", cap)
    }
    fn len_ctx(&mut self, ctx: &'static str, cap: usize) -> Result<usize, DecodeError> {
        let n = self.u32()? as usize;
        if n > cap || n > self.remaining() {
            return Err(DecodeError::LengthTooLarge { ctx, got: n as u64, cap: cap.min(self.remaining()) });
        }
        Ok(n)
    }
    fn bytes(&mut self, cap: usize) -> Result<Vec<u8>, DecodeError> {
        let n = self.len_ctx("bytes", cap)?;
        Ok(self.take(n)?.to_vec())
    }
    fn string(&mut self, cap: usize) -> Result<String, DecodeError> {
        let b = self.bytes(cap)?;
        String::from_utf8(b).map_err(|_| DecodeError::BadUtf8)
    }
    fn vec_u32(&mut self, cap: usize) -> Result<Vec<u32>, DecodeError> {
        // Each element is 4 bytes: cap the count by remaining/4 implicitly
        // via len (which checks n <= remaining, conservative) then read.
        let n = self.len_ctx("u32-vec", cap)?;
        let mut v = Vec::with_capacity(n);
        for _ in 0..n {
            v.push(self.u32()?);
        }
        Ok(v)
    }
    fn quant(&mut self) -> Result<QuantMeta, DecodeError> {
        let bits = self.u32()?;
        let frac_bits = self.u32()?;
        let signed = match self.u8()? {
            0 => false,
            1 => true,
            t => return Err(DecodeError::BadTag { ctx: "signed", tag: t }),
        };
        Ok(QuantMeta { bits, frac_bits, signed })
    }
    fn finish(&mut self) -> Result<(), DecodeError> {
        if self.remaining() != 0 {
            return Err(DecodeError::TrailingBytes { extra: self.remaining() });
        }
        Ok(())
    }
}

fn encode_operation(w: &mut StatementWriter, op: &Operation) {
    match op {
        Operation::Matmul { a, b, c } => {
            w.u8(0);
            w.u32(*a);
            w.u32(*b);
            w.u32(*c);
        }
        Operation::LinkEqual { left, right } => {
            w.u8(1);
            w.u32(*left);
            w.u32(*right);
        }
        Operation::LinkTranspose { by_rows, by_cols } => {
            w.u8(2);
            w.u32(*by_rows);
            w.u32(*by_cols);
        }
        Operation::Add { inputs, output } => {
            w.u8(3);
            w.u32(inputs.len() as u32);
            for i in inputs {
                w.u32(*i);
            }
            w.u32(*output);
        }
        Operation::Scale { input, output, scalar_le } => {
            w.u8(4);
            w.u32(*input);
            w.u32(*output);
            w.bytes(scalar_le);
        }
        Operation::Hadamard { x, y, z } => {
            w.u8(5);
            w.u32(*x);
            w.u32(*y);
            w.u32(*z);
        }
        Operation::Binary { bits } => {
            w.u8(6);
            w.u32(*bits);
        }
        Operation::Range { value, bits, width, signed } => {
            w.u8(7);
            w.u32(*value);
            w.u32(*bits);
            w.u32(*width);
            w.u8(*signed as u8);
        }
        Operation::Rescale { x, y, r, shift } => {
            w.u8(8);
            w.u32(*x);
            w.u32(*y);
            w.u32(*r);
            w.u32(*shift);
        }
        Operation::BiasBroadcast { bias, broadcast } => {
            w.u8(9);
            w.u32(*bias);
            w.u32(*broadcast);
        }
        Operation::Lookup { x, y } => {
            w.u8(10);
            w.u32(*x);
            w.u32(*y);
        }
        Operation::LookupAt { x, y, table } => {
            w.u8(11);
            w.u32(*x);
            w.u32(*y);
            w.u32(*table);
        }
        Operation::RangeLookup { value, width, signed } => {
            w.u8(12);
            w.u32(*value);
            w.u32(*width);
            w.u8(*signed as u8);
        }
    }
}

fn decode_operation(r: &mut ByteReader) -> Result<Operation, DecodeError> {
    let tag = r.u8()?;
    Ok(match tag {
        0 => Operation::Matmul { a: r.u32()?, b: r.u32()?, c: r.u32()? },
        1 => Operation::LinkEqual { left: r.u32()?, right: r.u32()? },
        2 => Operation::LinkTranspose { by_rows: r.u32()?, by_cols: r.u32()? },
        3 => Operation::Add { inputs: r.vec_u32(MAX_OP_VEC_LEN)?, output: r.u32()? },
        4 => Operation::Scale { input: r.u32()?, output: r.u32()?, scalar_le: r.bytes(MAX_SCALAR_LEN)? },
        5 => Operation::Hadamard { x: r.u32()?, y: r.u32()?, z: r.u32()? },
        6 => Operation::Binary { bits: r.u32()? },
        7 => Operation::Range {
            value: r.u32()?,
            bits: r.u32()?,
            width: r.u32()?,
            signed: match r.u8()? {
                0 => false,
                1 => true,
                t => return Err(DecodeError::BadTag { ctx: "range-signed", tag: t }),
            },
        },
        8 => Operation::Rescale { x: r.u32()?, y: r.u32()?, r: r.u32()?, shift: r.u32()? },
        9 => Operation::BiasBroadcast { bias: r.u32()?, broadcast: r.u32()? },
        10 => Operation::Lookup { x: r.u32()?, y: r.u32()? },
        11 => Operation::LookupAt { x: r.u32()?, y: r.u32()?, table: r.u32()? },
        12 => Operation::RangeLookup {
            value: r.u32()?,
            width: r.u32()?,
            signed: match r.u8()? {
                0 => false,
                1 => true,
                t => return Err(DecodeError::BadTag { ctx: "rangelookup-signed", tag: t }),
            },
        },
        t => return Err(DecodeError::BadTag { ctx: "operation", tag: t }),
    })
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
            typing: Vec::new(),
            tables: Vec::new(),
            mode: None,
        }
    }

    /// [UAGB1-BF] A v4 statement: table FAMILY instead of the single
    /// header table (header.table stays None), typed per-entry metadata
    /// in `typing` (caller fills it alongside `quant`).
    pub fn new_v4(
        model_digest: [u8; 32],
        tables: Vec<TableSpec>,
        modulus_bits: u32,
        manifest: ClaimManifest,
    ) -> Self {
        Statement {
            header: StatementHeader {
                version: STATEMENT_VERSION_V4,
                model_digest,
                table: None,
                modulus_bits,
            },
            manifest,
            quant: Vec::new(),
            pad: Vec::new(),
            outputs: Vec::new(),
            typing: Vec::new(),
            tables,
            mode: None,
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
                || matches!(other, Operation::LookupAt { x: lx, .. } if *lx == id)
                || matches!(other, Operation::RangeLookup { value, width, signed }
                    if *value == id && *width == q.bits && *signed == q.signed)
        })
    }

    /// Full structural validation. Fail-fast: returns the FIRST violation
    /// in a deterministic order (header, entries, quant + modulus
    /// injection, operations, cycles, topological order, padding,
    /// outputs/coverage).
    pub fn validate(&self) -> Result<(), StatementError> {
        use StatementError as E;
        // --- Header (version gate: v3 rules are UNCHANGED; v4 adds the
        // --- typed extension — [UAGB1-BF]). --------------------------------
        let v4 = self.header.version == STATEMENT_VERSION_V4;
        if self.header.version != STATEMENT_VERSION && !v4 {
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
        // --- [UAGB1-BF] v4 typing extension / v3 emptiness gate. -----------
        if !v4 {
            if !self.typing.is_empty() {
                return Err(E::TypingCount { entries: entries.len(), typings: self.typing.len() });
            }
            if !self.tables.is_empty() {
                return Err(E::TypingViolation { id: 0, field: "tables[] on a v3 statement" });
            }
        } else {
            if self.typing.len() != entries.len() {
                return Err(E::TypingCount { entries: entries.len(), typings: self.typing.len() });
            }
            if self.header.table.is_some() {
                return Err(E::TypingViolation { id: 0, field: "v4 binds tables[], not header.table" });
            }
            for (index, t) in self.typing.iter().enumerate() {
                let q = &self.quant[index];
                let id = index as u32;
                // One source of truth for the scale on the wire.
                if q.frac_bits != 0 {
                    return Err(E::TypingViolation { id, field: "v4 quant.frac_bits must be 0" });
                }
                if t.symmetric && !q.signed {
                    return Err(E::TypingViolation { id, field: "symmetric on unsigned" });
                }
                if !(-64..=64).contains(&t.scale_exp) {
                    return Err(E::TypingViolation { id, field: "scale exponent range" });
                }
                // E-O1-BB class/base declarations against the frozen table.
                let Some(row) = V4_CLASS_TABLE.iter().find(|r| r.0 == t.class) else {
                    return Err(E::WrongClass { id });
                };
                if q.bits > row.2 {
                    return Err(E::WrongClass { id });
                }
                if let Some(want_signed) = row.3 {
                    if q.signed != want_signed {
                        return Err(E::WrongClass { id });
                    }
                }
                if t.base_e0 != row.1 {
                    return Err(E::WrongBase { id });
                }
            }
            let registry = v4_table_registry();
            for (index, spec) in self.tables.iter().enumerate() {
                if !registry.iter().any(|r| r == spec) {
                    return Err(E::TableNotFrozen { index });
                }
            }
        }
        if self.manifest.operations.is_empty() {
            return Err(E::EmptyOperations);
        }
        let entry = |op: usize, id: u32| -> Result<&CommitmentEntry, StatementError> {
            entries.get(id as usize).ok_or(E::DanglingId { op, id })
        };
        let quant = |id: u32| -> &QuantMeta { &self.quant[id as usize] };
        // [UAGB1-BF] Effective typed views. v3: scale = -frac_bits and the
        // asymmetric declared-type bounds (byte-identical semantics to the
        // pre-v4 code). v4: the signed scale exponent and, for symmetric
        // signed entries, the +-(2^(b-1)-1) window ([-127,127] at int8).
        let se = |id: u32| -> i64 {
            if v4 {
                self.typing[id as usize].scale_exp as i64
            } else {
                -(self.quant[id as usize].frac_bits as i64)
            }
        };
        let bnd = |id: u32| -> RawBounds {
            let q = &self.quant[id as usize];
            if v4 && q.signed && self.typing[id as usize].symmetric {
                let m = (1i128 << (q.bits - 1)) - 1;
                RawBounds { lo: -m, hi: m }
            } else {
                q.raw_bounds()
            }
        };
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
                    if se(*c) != se(*a) + se(*b) {
                        return Err(E::QuantMismatch { op, id: *c, field: "matmul fraction bits" });
                    }
                    // Accumulator interval: inner * (a-bounds x b-bounds),
                    // lower and upper endpoints tracked separately. A
                    // matmul accumulator NEVER narrows: a range fact on
                    // the sum does not bound the partial sums. Under v4
                    // symmetric operands ([-127,127]) this DERIVES the
                    // honest 25/26-bit 125M accumulator rows.
                    let acc = bnd(*a).mul(bnd(*b)).scale(ea.cols as i128);
                    if !bnd(*c).contains(acc) {
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
                    if se(*z) != se(*x) + se(*y) {
                        return Err(E::QuantMismatch { op, id: *z, field: "hadamard fraction bits" });
                    }
                    let worst = bnd(*x).mul(bnd(*y));
                    // Calibrated narrowing: a declared type the worst case
                    // does not cover (width OR signedness) is legal only
                    // with a Range/Lookup fact on z.
                    if !self.narrowing_fact(*z, qz) {
                        if qz.signed != (qx.signed || qy.signed) {
                            return Err(E::QuantMismatch { op, id: *z, field: "hadamard signedness" });
                        }
                        if !bnd(*z).contains(worst) {
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
                    // cannot waive the scale equation (C-03a). v3 keeps its
                    // frac_bits >= shift floor (unsigned storage); v4's
                    // signed exponents need no floor — se(y) = se(x) + shift
                    // covers the calibrated eZ = +1 / eH = +2 layers
                    // (D3-F2 closed).
                    if (!v4 && qx.frac_bits < *shift) || se(*y) != se(*x) + *shift as i64 {
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
                    let worst = bnd(*x).shr(*shift);
                    if !self.narrowing_fact(*y, qy) && !bnd(*y).contains(worst) {
                        return Err(E::QuantMismatch { op, id: *y, field: "rescale width" });
                    }
                    if !worst.fits_modulus(mb) {
                        return Err(E::QuantMismatch { op, id: *y, field: "modulus capacity" });
                    }
                    if qr.signed || qr.bits != *shift || se(*r) != se(*x) {
                        return Err(E::QuantMismatch { op, id: *r, field: "rescale remainder quant" });
                    }
                    // The remainder MUST carry an unsigned width-`shift`
                    // range fact — without it the mod-q rescale identity
                    // admits integer wraparound (audit C-02). v4 may
                    // discharge it by a RangeLookup (the U-R2 range-table
                    // form) instead of a bit-plane Range.
                    let has_range = self.manifest.operations.iter().any(|other| {
                        matches!(other, Operation::Range { value, width, signed, .. }
                            if value == r && width == shift && !signed)
                            || matches!(other, Operation::RangeLookup { value, width, signed }
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
                        if se(*input) != se(*output) {
                            return Err(E::QuantMismatch { op, id: *input, field: "add fraction bits" });
                        }
                        any_signed |= qi.signed;
                        sum = sum.add(bnd(*input));
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
                        if !bnd(*output).contains(sum) {
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
                    if se(*output) != se(*input) {
                        return Err(E::QuantMismatch { op, id: *output, field: "scale fraction bits" });
                    }
                    let worst = bnd(*input).scale(scalar.min(i128::MAX as u128) as i128);
                    if !bnd(*output).contains(worst) {
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
                    if v4 && self.typing[*left as usize] != self.typing[*right as usize] {
                        return Err(E::QuantMismatch { op, id: *right, field: "link typing" });
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
                    if v4 && self.typing[*by_rows as usize] != self.typing[*by_cols as usize] {
                        return Err(E::QuantMismatch { op, id: *by_cols, field: "link typing" });
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
                    if v4 && self.typing[*bias as usize] != self.typing[*broadcast as usize] {
                        return Err(E::QuantMismatch { op, id: *broadcast, field: "broadcast typing" });
                    }
                    read[*bias as usize] = true;
                    written[*broadcast as usize] = true;
                    flow[*bias as usize].push(*broadcast as usize);
                    reads.push(*bias);
                    writes.push(*broadcast);
                }
                Operation::Lookup { x, y } => {
                    // [UAGB1-BF] v4 statements bind their tables through
                    // the FAMILY (LookupAt); the single-header form is
                    // v3-only.
                    if v4 {
                        return Err(E::VersionedOperation { op });
                    }
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
                // [UAGB1-BF] v4-only: the per-scale table family form.
                Operation::LookupAt { x, y, table } => {
                    if !v4 {
                        return Err(E::VersionedOperation { op });
                    }
                    let (ex, ey) = (entry(op, *x)?, entry(op, *y)?);
                    same_shape(op, ex, ey)?;
                    same_orient(op, ex, ey)?;
                    let Some(spec) = self.tables.get(*table as usize) else {
                        return Err(E::TableIndex { op, table: *table });
                    };
                    // Registry equality holds globally (TableNotFrozen);
                    // the OPERANDS must match the member's typed spec —
                    // width, signedness, and the SIGNED scale (spec
                    // frac_bits reads as scale_exp = -frac_bits). A
                    // per-layer scale mismatch (the D3-F1 wrong-table
                    // statement form) rejects HERE, pre-crypto.
                    let (qx, qy) = (quant(*x), quant(*y));
                    if qx.bits != spec.input.bits
                        || qx.signed != spec.input.signed
                        || se(*x) != -(spec.input.frac_bits as i64)
                    {
                        return Err(E::QuantMismatch { op, id: *x, field: "lookup domain quant" });
                    }
                    if qy.bits != spec.output.bits
                        || qy.signed != spec.output.signed
                        || se(*y) != -(spec.output.frac_bits as i64)
                    {
                        return Err(E::QuantMismatch { op, id: *y, field: "lookup image quant" });
                    }
                    read[*x as usize] = true;
                    written[*y as usize] = true;
                    flow[*x as usize].push(*y as usize);
                    reads.push(*x);
                    writes.push(*y);
                }
                // [UAGB1-BF] v4-only: a range fact in range-table form (no
                // plane stack, no Binary fact; the proving layer owes one
                // masked [0, 2^width) lookup instance per operation).
                Operation::RangeLookup { value, width, signed } => {
                    if !v4 {
                        return Err(E::VersionedOperation { op });
                    }
                    entry(op, *value)?;
                    let qv = quant(*value);
                    if *width == 0 || qv.bits != *width || qv.signed != *signed {
                        return Err(E::QuantMismatch { op, id: *value, field: "range width/sign" });
                    }
                    read[*value as usize] = true;
                    reads.push(*value);
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
        // --- [UAGB1-BG] Privacy-mode declaration (Amendment A1). The
        // --- declaration is DECLARATION-consistent here; which modes a
        // --- prover can run is the composition layer's gate. ---------------
        if let Some(m) = &self.mode {
            if m.mode > MODE_P3 {
                return Err(E::ModeDeclInvalid { rule: "mode id outside P0..P3" });
            }
            if !v4 {
                return Err(E::ModeDeclInvalid {
                    rule: "mode declaration requires v4 typed entries",
                });
            }
            if !m.private_entries.windows(2).all(|w| w[0] < w[1]) {
                return Err(E::ModeDeclInvalid {
                    rule: "private set must be sorted and duplicate-free",
                });
            }
            if m.private_entries.iter().any(|&id| id as usize >= entries.len()) {
                return Err(E::ModeDeclInvalid { rule: "private set names a nonexistent id" });
            }
            let weight_ids: Vec<u32> = (0..entries.len() as u32)
                .filter(|&id| self.typing[id as usize].class == CLS_W8S)
                .collect();
            match m.mode {
                MODE_P0 => {
                    if !m.private_entries.is_empty() {
                        return Err(E::ModeDeclInvalid { rule: "P0 declares a nonempty private set" });
                    }
                }
                MODE_P1 => {
                    if m.private_entries.is_empty() {
                        return Err(E::ModeDeclInvalid { rule: "P1 declares an empty private set" });
                    }
                    if m.private_entries.iter().any(|id| weight_ids.contains(id)) {
                        return Err(E::ModeDeclInvalid {
                            rule: "P1 private set includes a weight-class entry (that is P2/P3)",
                        });
                    }
                }
                MODE_P2 => {
                    // The accumulation-critical class: EXACTLY the weight
                    // entries (A1: any mode with private weights masks
                    // every weight-touching proof, every pass).
                    if m.private_entries != weight_ids {
                        return Err(E::ModeDeclInvalid {
                            rule: "P2 private set must be exactly the weight-class entries",
                        });
                    }
                }
                _ => {
                    // P3: everything committed is private.
                    let all: Vec<u32> = (0..entries.len() as u32).collect();
                    if m.private_entries != all {
                        return Err(E::ModeDeclInvalid {
                            rule: "P3 private set must be every entry",
                        });
                    }
                }
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
    /// Canonical byte encoding of the public statement (U-S Phase 3
    /// P3-D1/D2). Versioned magic + length-prefixed, little-endian,
    /// canonical field order — the exact bytes a fresh verifier process
    /// decodes. Every field the digest binds is present (plus the wire-only
    /// commitment/key bytes the digest already covers), so a decode ->
    /// re-digest reproduces the transcript context with no prover state.
    pub fn encode(&self) -> Vec<u8> {
        let v4 = self.header.version == STATEMENT_VERSION_V4;
        let mut w = StatementWriter::new();
        w.raw(STATEMENT_CODEC_MAGIC);
        // [UAGB1-BF] Container version 2 = the v4 layout (cv1 bytes for
        // v3 statements are unchanged — the one versioned codec change).
        w.u32(if v4 { STATEMENT_CODEC_VERSION_V4 } else { STATEMENT_CODEC_VERSION });
        // Header.
        w.u32(self.header.version);
        w.raw(&self.header.model_digest);
        match &self.header.table {
            None => w.u8(0),
            Some(t) => {
                w.u8(1);
                w.raw(&t.digest);
                w.quant(&t.input);
                w.quant(&t.output);
                w.i64(t.domain_min);
                w.i64(t.domain_max);
            }
        }
        w.u32(self.header.modulus_bits);
        // Manifest backend + setup + commitments + operations.
        w.string(&self.manifest.backend);
        w.bytes(&self.manifest.setup_digest);
        w.u32(self.manifest.commitments.len() as u32);
        for c in &self.manifest.commitments {
            w.u32(c.id);
            w.string(&c.label);
            w.u32(c.rows);
            w.u32(c.cols);
            w.u8(c.orientation.tag());
            w.bytes(&c.key_info);
            w.bytes(&c.commitment_bytes);
        }
        w.u32(self.manifest.operations.len() as u32);
        for op in &self.manifest.operations {
            encode_operation(&mut w, op);
        }
        // Per-entry quant + pad, outputs.
        w.u32(self.quant.len() as u32);
        for q in &self.quant {
            w.quant(q);
        }
        w.u32(self.pad.len() as u32);
        for p in &self.pad {
            w.u64(p.padded_rows);
            w.u64(p.padded_cols);
            w.u64(p.row_unit);
            w.u64(p.col_unit);
        }
        w.u32(self.outputs.len() as u32);
        for o in &self.outputs {
            w.u32(*o);
        }
        if v4 {
            w.u32(self.typing.len() as u32);
            for t in &self.typing {
                w.u32(t.scale_exp as u32);
                w.u8(t.symmetric as u8);
                w.u32(t.class);
                w.u32(t.base_e0);
            }
            w.u32(self.tables.len() as u32);
            for spec in &self.tables {
                w.raw(&spec.digest);
                w.quant(&spec.input);
                w.quant(&spec.output);
                w.i64(spec.domain_min);
                w.i64(spec.domain_max);
            }
        }
        // [UAGB1-BG] Trailing mode-declaration section, present ONLY
        // when declared: mode-less statements' wire bytes (cv1 AND cv2)
        // are unchanged — additive-only discipline.
        if let Some(m) = &self.mode {
            w.u8(0x4D); // 'M' section tag
            w.u8(m.mode);
            w.u32(m.private_entries.len() as u32);
            for id in &m.private_entries {
                w.u32(*id);
            }
        }
        w.into_vec()
    }

    /// Decode a statement from untrusted bytes (U-S Phase 3 P3-D2/D4).
    /// Bounds-checked at every field, hard resource limits, and a final
    /// `validate()` pass — a decoded statement is always a VALID statement
    /// or a structured error. NEVER panics on any input; trailing bytes
    /// and oversized lengths are rejected (reject-don't-truncate).
    pub fn decode(bytes: &[u8]) -> Result<Statement, DecodeError> {
        let mut r = ByteReader::new(bytes);
        if r.take(STATEMENT_CODEC_MAGIC.len())? != STATEMENT_CODEC_MAGIC {
            return Err(DecodeError::BadMagic);
        }
        let cv = r.u32()?;
        if cv != STATEMENT_CODEC_VERSION && cv != STATEMENT_CODEC_VERSION_V4 {
            return Err(DecodeError::UnknownCodecVersion { got: cv });
        }
        let version = r.u32()?;
        let model_digest = r.bytes32()?;
        let table = match r.u8()? {
            0 => None,
            1 => Some(TableSpec {
                digest: r.bytes32()?,
                input: r.quant()?,
                output: r.quant()?,
                domain_min: r.i64()?,
                domain_max: r.i64()?,
            }),
            t => return Err(DecodeError::BadTag { ctx: "table-present", tag: t }),
        };
        let modulus_bits = r.u32()?;
        let backend = r.string(MAX_LABEL_LEN)?;
        let setup_digest = r.bytes(MAX_SETUP_LEN)?;
        let n_c = r.len(MAX_COMMITMENTS)?;
        let mut commitments = Vec::with_capacity(n_c);
        for _ in 0..n_c {
            let id = r.u32()?;
            let label = r.string(MAX_LABEL_LEN)?;
            let rows = r.u32()?;
            let cols = r.u32()?;
            let orientation = match r.u8()? {
                0 => Orientation::RowMajor,
                1 => Orientation::ByRows,
                2 => Orientation::ByColumns,
                t => return Err(DecodeError::BadTag { ctx: "orientation", tag: t }),
            };
            let key_info = r.bytes(MAX_KEYINFO_LEN)?;
            let commitment_bytes = r.bytes(MAX_COMMIT_BYTES_LEN)?;
            commitments.push(CommitmentEntry {
                id,
                label,
                rows,
                cols,
                orientation,
                key_info,
                commitment_bytes,
            });
        }
        let n_op = r.len(MAX_OPERATIONS)?;
        let mut operations = Vec::with_capacity(n_op);
        for _ in 0..n_op {
            operations.push(decode_operation(&mut r)?);
        }
        let n_q = r.len(MAX_ENTRIES)?;
        let mut quant = Vec::with_capacity(n_q);
        for _ in 0..n_q {
            quant.push(r.quant()?);
        }
        let n_p = r.len(MAX_ENTRIES)?;
        let mut pad = Vec::with_capacity(n_p);
        for _ in 0..n_p {
            pad.push(PadSpec {
                padded_rows: r.u64()?,
                padded_cols: r.u64()?,
                row_unit: r.u64()?,
                col_unit: r.u64()?,
            });
        }
        let n_out = r.len(MAX_ENTRIES)?;
        let mut outputs = Vec::with_capacity(n_out);
        for _ in 0..n_out {
            outputs.push(r.u32()?);
        }
        // [UAGB1-BF] cv2 carries the v4 typing + table-family records;
        // the container and header versions must pair (canonicality).
        if (cv == STATEMENT_CODEC_VERSION_V4) != (version == STATEMENT_VERSION_V4) {
            return Err(DecodeError::BadTag { ctx: "codec/version pairing", tag: cv as u8 });
        }
        let (mut typing, mut tables) = (Vec::new(), Vec::new());
        if cv == STATEMENT_CODEC_VERSION_V4 {
            let n_t = r.len(MAX_ENTRIES)?;
            typing.reserve(n_t);
            for _ in 0..n_t {
                let scale_exp = r.u32()? as i32;
                let symmetric = match r.u8()? {
                    0 => false,
                    1 => true,
                    t => return Err(DecodeError::BadTag { ctx: "typing-symmetric", tag: t }),
                };
                typing.push(TypingV4 { scale_exp, symmetric, class: r.u32()?, base_e0: r.u32()? });
            }
            let n_tb = r.len(MAX_ENTRIES)?;
            tables.reserve(n_tb);
            for _ in 0..n_tb {
                tables.push(TableSpec {
                    digest: r.bytes32()?,
                    input: r.quant()?,
                    output: r.quant()?,
                    domain_min: r.i64()?,
                    domain_max: r.i64()?,
                });
            }
        }
        // [UAGB1-BG] Optional trailing mode-declaration section,
        // parsed ONLY when the section tag 0x4D opens it (a mode
        // section is at least tag + mode + u32 count = 6 bytes).
        // Absent = None (the pre-BG wire); any OTHER trailing content
        // still rejects below as TrailingBytes — the pre-BG negative
        // vectors keep their exact errors.
        let mode = if r.remaining() >= 6 && r.peek_u8() == Some(0x4D) {
            let _tag = r.u8()?;
            let mode = r.u8()?;
            let n_ids = r.len(MAX_ENTRIES)?;
            let mut private_entries = Vec::with_capacity(n_ids);
            for _ in 0..n_ids {
                private_entries.push(r.u32()?);
            }
            Some(ModeDecl { mode, private_entries })
        } else {
            None
        };
        r.finish()?; // reject trailing bytes
        let st = Statement {
            header: StatementHeader { version, model_digest, table, modulus_bits },
            manifest: ClaimManifest {
                backend,
                setup_digest,
                commitments,
                operations,
            },
            quant,
            pad,
            outputs,
            typing,
            tables,
            mode,
        };
        // A decoded statement must be a VALID statement — the fresh verifier
        // never trusts a wire statement's structure.
        st.validate().map_err(DecodeError::Invalid)?;
        Ok(st)
    }

    pub fn digest(&self) -> Result<[u8; 32], StatementError> {
        self.validate()?;
        let v4 = self.header.version == STATEMENT_VERSION_V4;
        let mut hasher = Sha256::new();
        // [UAGB1-BF] Version-gated tag: the v3 byte stream is UNTOUCHED
        // (existing frozen digests must not move); v4 hashes under its
        // own tag and additionally absorbs typing + tables below.
        absorb_bytes(&mut hasher, if v4 { STATEMENT_TAG_V4 } else { STATEMENT_TAG }.as_bytes());
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
        if v4 {
            hasher.update((self.typing.len() as u64).to_le_bytes());
            for t in &self.typing {
                hasher.update(t.scale_exp.to_le_bytes());
                hasher.update([t.symmetric as u8]);
                hasher.update(t.class.to_le_bytes());
                hasher.update(t.base_e0.to_le_bytes());
            }
            hasher.update((self.tables.len() as u64).to_le_bytes());
            for spec in &self.tables {
                hasher.update(spec.digest);
                absorb_quant(&mut hasher, &spec.input);
                absorb_quant(&mut hasher, &spec.output);
                hasher.update(spec.domain_min.to_le_bytes());
                hasher.update(spec.domain_max.to_le_bytes());
            }
        }
        hasher.update(self.manifest.digest());
        // [UAGB1-BG] Privacy-mode declaration: absorbed ONLY when
        // declared — a mode-less statement's digest is byte-identical
        // to the pre-BG stream (freeze rows UAGB1-BG-1*).
        if let Some(m) = &self.mode {
            absorb_bytes(&mut hasher, b"uagb1-mode-decl");
            hasher.update([m.mode]);
            hasher.update((m.private_entries.len() as u64).to_le_bytes());
            for id in &m.private_entries {
                hasher.update(id.to_le_bytes());
            }
        }
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

/// A small VALID lookup+Hadamard statement for the codec round-trip: SiLU
/// lookup g8 -> a8, then a8 o u8 -> h. Self-contained, metadata-only.
pub fn codec_sample_statement() -> Statement {
    let q8 = QuantMeta { bits: 8, frac_bits: 4, signed: true };
    let mut mf = ClaimManifest::new("statement-codec", b"codec-setup");
    let g8 = mf.add_commitment("g8", 4, 4, Orientation::ByColumns, vec![1, 2, 3], vec![0xaa; 8]);
    let a8 = mf.add_commitment("a8", 4, 4, Orientation::ByColumns, vec![], vec![0xbb; 8]);
    let u8v = mf.add_commitment("u8", 4, 4, Orientation::ByColumns, vec![9], vec![0xcc; 8]);
    let h = mf.add_commitment("h", 4, 4, Orientation::ByColumns, vec![], vec![0xdd; 8]);
    mf.add_operation(Operation::Lookup { x: g8, y: a8 });
    mf.add_operation(Operation::Hadamard { x: a8, y: u8v, z: h });
    let mut st = Statement::new([7u8; 32], Some(SILU_INT8_TABLE_SPEC), 30, mf);
    st.quant = vec![q8, q8, q8, QuantMeta { bits: 16, frac_bits: 8, signed: true }];
    st.pad = st
        .manifest
        .commitments
        .iter()
        .map(|e| PadSpec::exact(e.rows as usize, e.cols as usize))
        .collect();
    st.outputs = vec![h];
    st
}

/// [UAGB1-BF] A small VALID v4 statement exercising every new typed
/// feature on the 125M pass semantics in miniature: symmetric [-127,127]
/// int8 operands, a POSITIVE scale exponent chain (eH = +2 -> eZ = +1,
/// the D3-F2 layers), a LookupAt into the per-scale family ((-3,-3)
/// member), a RangeLookup remainder fact, and full class/base
/// declarations. Shapes tiny; metadata-only.
pub fn codec_sample_statement_v4() -> Statement {
    let mut mf = ClaimManifest::new("statement-codec-v4", b"codec-setup-v4");
    // h8 (se +2, the calibrated layer-2 eH) @ Wd (se -9) -> Dacc (se -7)
    // -> rescale shift 8 -> z (se +1, the calibrated eZ) + remainder r8;
    // g8 (se -3) -> LookupAt[(-3,-3)] -> a8; a8 o u8 -> H (se -6).
    let h8 = mf.add_commitment("h8", 4, 8, Orientation::RowMajor, vec![], vec![0x11; 8]);
    let wd = mf.add_commitment("Wd", 8, 4, Orientation::RowMajor, vec![], vec![0x22; 8]);
    let dacc = mf.add_commitment("Dacc", 4, 4, Orientation::RowMajor, vec![], vec![0x33; 8]);
    let zv = mf.add_commitment("z", 4, 4, Orientation::RowMajor, vec![], vec![0x44; 8]);
    let rd = mf.add_commitment("Rd", 4, 4, Orientation::RowMajor, vec![], vec![0x55; 8]);
    let g8 = mf.add_commitment("g8", 4, 4, Orientation::RowMajor, vec![], vec![0x66; 8]);
    let a8 = mf.add_commitment("a8", 4, 4, Orientation::RowMajor, vec![], vec![0x77; 8]);
    let u8v = mf.add_commitment("u8", 4, 4, Orientation::RowMajor, vec![], vec![0x88; 8]);
    let hh = mf.add_commitment("H", 4, 4, Orientation::RowMajor, vec![], vec![0x99; 8]);
    mf.add_operation(Operation::Matmul { a: h8, b: wd, c: dacc });
    mf.add_operation(Operation::Rescale { x: dacc, y: zv, r: rd, shift: 8 });
    mf.add_operation(Operation::RangeLookup { value: rd, width: 8, signed: false });
    mf.add_operation(Operation::RangeLookup { value: zv, width: 8, signed: true });
    mf.add_operation(Operation::LookupAt { x: g8, y: a8, table: 0 });
    mf.add_operation(Operation::Hadamard { x: a8, y: u8v, z: hh });
    let mut st = Statement::new_v4([8u8; 32], vec![SILU_V2_M3_TABLE_SPEC], 30, mf);
    let q = |bits: u32, signed: bool| QuantMeta { bits, frac_bits: 0, signed };
    let t = |scale_exp: i32, symmetric: bool, class: u32, base_e0: u32| TypingV4 {
        scale_exp,
        symmetric,
        class,
        base_e0,
    };
    st.quant = vec![
        q(8, true),  // h8
        q(8, true),  // Wd
        q(19, true), // Dacc: 8 * 127^2 = 129,032 -> 18 bits + margin
        q(8, true),  // z (narrowed by its RangeLookup)
        q(8, false), // Rd
        q(8, true),  // g8
        q(8, true),  // a8
        q(8, true),  // u8
        q(16, true), // H
    ];
    st.typing = vec![
        t(2, true, CLS_ACT8, 2),   // h8: eH = +2, symmetric
        t(-9, true, CLS_W8S, 1),   // Wd: weight, e0 = 1 (F-N2)
        t(-7, false, CLS_ACC, 2),  // Dacc
        t(1, true, CLS_ACT8, 2),   // z: eZ = +1
        t(-7, false, CLS_REM, 2),  // Rd (se == se(Dacc))
        t(-3, false, CLS_ACT8, 2), // g8 (matches the (-3,-3) member)
        t(-3, false, CLS_ACT8, 2), // a8
        t(-3, false, CLS_ACT8, 2), // u8
        t(-6, false, CLS_ACC, 2),  // H = a8 o u8
    ];
    st.pad = st
        .manifest
        .commitments
        .iter()
        .map(|e| PadSpec::exact(e.rows as usize, e.cols as usize))
        .collect();
    st.outputs = vec![zv, hh];
    st
}

/// [UAGB1-BF] The v4 typing/codec battery: the ONE versioned codec
/// change's positive and negative vectors. Returns overall pass.
pub fn statement_v4_battery() -> bool {
    fn note(label: &str, pass: bool, ok: &mut bool) {
        if pass {
            println!("  ok   {label}");
        } else {
            println!("  FAIL {label}");
            *ok = false;
        }
    }
    let mut ok = true;
    use StatementError as SE;

    let expect = |label: &str, st: &Statement, want: fn(&StatementError) -> bool, ok: &mut bool| {
        match st.validate() {
            Ok(()) => {
                println!("  FAIL malicious statement accepted ({label})");
                *ok = false;
            }
            Err(err) if want(&err) => println!("  ok   statement rejects {label}: {err}"),
            Err(err) => {
                println!("  FAIL wrong rejection for {label}: {err}");
                *ok = false;
            }
        }
    };

    // (P1) The v4 base validates, digests deterministically, and its
    // POSITIVE scale exponents (eH = +2, eZ = +1) are carried un-clamped
    // at honest 8-bit storage — the D3-F2 gap closed.
    let base = codec_sample_statement_v4();
    match (base.validate(), base.digest(), base.digest()) {
        (Ok(()), Ok(d1), Ok(d2)) if d1 == d2 => {
            note("v4 base validates (eH +2 / eZ +1 expressible, 8-bit storage); digest deterministic", true, &mut ok)
        }
        _ => note("v4 base validates + digests", false, &mut ok),
    }

    // (P2) The v3 sample's digest and wire bytes are UNMOVED by the v4
    // change (same statement, byte-identical cv1 encoding).
    let v3 = codec_sample_statement();
    let v3_bytes = v3.encode();
    note(
        "v3 sample still encodes at cv1 and round-trips (bytes + digest preserved)",
        v3_bytes[4..8] == 1u32.to_le_bytes()
            && Statement::decode(&v3_bytes).map(|b| b.encode() == v3_bytes).unwrap_or(false),
        &mut ok,
    );

    // (P3) v4 codec round-trip: cv2, byte-identical re-encode, digest
    // preserved across the wire.
    let v4_bytes = base.encode();
    match Statement::decode(&v4_bytes) {
        Ok(back) => {
            let d0 = base.digest().expect("base digests");
            let dr = back.digest().expect("round-tripped digests");
            note(
                "v4 codec round-trip (cv2): re-encode byte-identical, digest preserved",
                v4_bytes[4..8] == 2u32.to_le_bytes() && back.encode() == v4_bytes && d0 == dr,
                &mut ok,
            );
        }
        Err(e) => note(&format!("v4 codec round-trip decode ({e})"), false, &mut ok),
    }

    // (P4) The symmetric-range pair at the REAL 125M inner dims: under
    // symmetric [-127,127] operands the validator itself derives the
    // honest accumulator rows (25-bit @ 768 ACCEPTS, 26-bit @ 2048
    // ACCEPTS); the SAME declarations under asymmetric operands REJECT —
    // the BC-c divergence, now machine-checked instead of recorded.
    let acc_pair = |inner: usize, acc_bits: u32, symmetric: bool| -> Statement {
        let mut mf = ClaimManifest::new("statement-v4-acc", b"acc-pair");
        let a = mf.add_commitment("A", 1, inner, Orientation::RowMajor, vec![], vec![]);
        let b = mf.add_commitment("B", inner, 1, Orientation::RowMajor, vec![], vec![]);
        let c = mf.add_commitment("C", 1, 1, Orientation::RowMajor, vec![], vec![]);
        mf.add_operation(Operation::Matmul { a, b, c });
        let mut st = Statement::new_v4([9u8; 32], vec![], 30, mf);
        st.quant = vec![
            QuantMeta { bits: 8, frac_bits: 0, signed: true },
            QuantMeta { bits: 8, frac_bits: 0, signed: true },
            QuantMeta { bits: acc_bits, frac_bits: 0, signed: true },
        ];
        st.typing = vec![
            TypingV4 { scale_exp: -2, symmetric, class: CLS_ACT8, base_e0: 2 },
            TypingV4 { scale_exp: -9, symmetric, class: CLS_W8S, base_e0: 1 },
            TypingV4 { scale_exp: -11, symmetric: false, class: CLS_ACC, base_e0: 2 },
        ];
        st.pad = vec![
            PadSpec::exact(1, inner),
            PadSpec::exact(inner, 1),
            PadSpec::exact(1, 1),
        ];
        st.outputs = vec![c];
        st
    };
    note(
        "symmetric [-127,127] operands: 25-bit @ inner 768 and 26-bit @ inner 2048 ACCEPT (honest 125M rows derived)",
        acc_pair(768, 25, true).validate().is_ok() && acc_pair(2048, 26, true).validate().is_ok(),
        &mut ok,
    );
    expect(
        "the SAME 26-bit @ 2048 declaration under ASYMMETRIC operands (needs 27)",
        &acc_pair(2048, 26, false),
        |e| matches!(e, SE::QuantMismatch { field: "matmul accumulator width", .. }),
        &mut ok,
    );

    // (N1) E-O1-BB wrong-class vector: the accumulator declared as an
    // 8-bit activation class it does not fit.
    let mut bad = codec_sample_statement_v4();
    bad.typing[2].class = CLS_ACT8;
    expect("wrong class declaration (acc entry as CLS_ACT8)", &bad, |e| {
        matches!(e, SE::WrongClass { id: 2 })
    }, &mut ok);

    // (N2) E-O1-BB wrong-base vector: weight base e0 = 2 against the
    // F-N2-mandated sign-binary e0 = 1.
    let mut bad = codec_sample_statement_v4();
    bad.typing[1].base_e0 = 2;
    expect("wrong digit base (weight e0 = 2)", &bad, |e| matches!(e, SE::WrongBase { id: 1 }), &mut ok);

    // (N3) Version gates, both directions.
    let mut bad = codec_sample_statement();
    bad.typing = vec![TypingV4 { scale_exp: 0, symmetric: false, class: CLS_ACT8, base_e0: 2 }];
    expect("typing records on a v3 statement", &bad, |e| matches!(e, SE::TypingCount { .. }), &mut ok);
    let mut bad = codec_sample_statement_v4();
    bad.typing.clear();
    expect("v4 statement missing its typing", &bad, |e| matches!(e, SE::TypingCount { .. }), &mut ok);
    let mut bad = codec_sample_statement();
    bad.manifest.operations.push(Operation::RangeLookup { value: 3, width: 16, signed: true });
    expect("RangeLookup inside a v3 statement", &bad, |e| matches!(e, SE::VersionedOperation { .. }), &mut ok);
    let mut bad = codec_sample_statement_v4();
    bad.manifest.operations.push(Operation::Lookup { x: 5, y: 6 });
    expect("plain Lookup inside a v4 statement", &bad, |e| matches!(e, SE::VersionedOperation { .. }), &mut ok);

    // (N4) Table-family gates: bad index, off-registry spec, and the
    // per-layer scale mismatch (the D3-F1 wrong-table statement form).
    let mut bad = codec_sample_statement_v4();
    if let Operation::LookupAt { table, .. } = &mut bad.manifest.operations[4] {
        *table = 7;
    }
    expect("LookupAt with an out-of-family table index", &bad, |e| {
        matches!(e, SE::TableIndex { table: 7, .. })
    }, &mut ok);
    let mut bad = codec_sample_statement_v4();
    bad.tables[0].digest[0] ^= 0xff;
    expect("a tables[] entry equal to no frozen registry member", &bad, |e| {
        matches!(e, SE::TableNotFrozen { index: 0 })
    }, &mut ok);
    let mut bad = codec_sample_statement_v4();
    bad.tables[0] = SILU_V2_M4_TABLE_SPEC; // frozen, but the wrong member for se = -3 operands
    expect("the WRONG family member for the layer's exponent (g8 se -3 vs the (-4,-4) table)", &bad, |e| {
        matches!(e, SE::QuantMismatch { field: "lookup domain quant", .. })
    }, &mut ok);

    // (N5) Typed-field rules: nonzero v4 frac_bits, symmetric-on-unsigned.
    let mut bad = codec_sample_statement_v4();
    bad.quant[0].frac_bits = 4;
    expect("nonzero quant.frac_bits on a v4 statement", &bad, |e| {
        matches!(e, SE::TypingViolation { field: "v4 quant.frac_bits must be 0", .. })
    }, &mut ok);
    let mut bad = codec_sample_statement_v4();
    bad.typing[4].symmetric = true; // Rd is unsigned
    expect("symmetric flag on an unsigned entry", &bad, |e| {
        matches!(e, SE::TypingViolation { field: "symmetric on unsigned", .. })
    }, &mut ok);

    // (N6) Remainder coverage: deleting the RangeLookup starves the
    // rescale of its remainder fact (the C-02 wraparound gate, v4 form).
    let mut bad = codec_sample_statement_v4();
    bad.manifest.operations.remove(2);
    expect("rescale remainder with its RangeLookup deleted", &bad, |e| {
        matches!(e, SE::MissingRangeFact { .. })
    }, &mut ok);

    // (N7) Codec pairing: a cv1 container claiming a v4 header (and the
    // reverse) reject as structured errors, never as misparses.
    let mut wire = codec_sample_statement_v4().encode();
    wire[4..8].copy_from_slice(&1u32.to_le_bytes()); // cv2 -> cv1
    note(
        "codec pairing: v4 payload under a cv1 container rejects",
        Statement::decode(&wire).is_err(),
        &mut ok,
    );
    let mut wire = codec_sample_statement().encode();
    wire[4..8].copy_from_slice(&2u32.to_le_bytes()); // cv1 -> cv2
    note(
        "codec pairing: v3 payload under a cv2 container rejects",
        Statement::decode(&wire).is_err(),
        &mut ok,
    );

    if ok {
        println!("statement-v4 passed");
    } else {
        println!("statement-v4 FAILED");
    }
    ok
}

/// U-S Phase 3 (P3-D2/D4): canonical statement codec battery. Round-trip
/// determinism + canonicality (encode is a bijection on valid statements),
/// and every malformed-input class decodes to a STRUCTURED error, never a
/// panic. Returns overall pass.
pub fn statement_codec_battery() -> bool {
    fn note(label: &str, pass: bool, ok: &mut bool) {
        if pass {
            println!("  ok   {label}");
        } else {
            println!("  FAIL {label}");
            *ok = false;
        }
    }
    let mut ok = true;

    let st = codec_sample_statement();
    let bytes = st.encode();
    let d0 = st.digest().expect("sample statement validates");

    // Round-trip: decode succeeds, re-encodes to the SAME bytes (canonical),
    // and re-digests to the same transcript context.
    match Statement::decode(&bytes) {
        Ok(back) => {
            let re = back.encode();
            let dr = back.digest().expect("round-tripped statement validates");
            note("codec round-trip: decode(encode(st)) re-encodes byte-identically", re == bytes, &mut ok);
            note("codec round-trip: transcript digest preserved across the wire", dr == d0, &mut ok);
        }
        Err(e) => {
            note(&format!("codec round-trip decode succeeds (got {e})"), false, &mut ok);
        }
    }

    // Determinism: encode is a pure function.
    note("codec determinism: encode is stable", st.encode() == bytes, &mut ok);

    // --- Malformed-input classes: each must be a structured DecodeError. ---
    let expect_err = |label: &str, buf: Vec<u8>, pred: &dyn Fn(&DecodeError) -> bool, ok: &mut bool| {
        match Statement::decode(&buf) {
            Ok(_) => {
                println!("  FAIL {label}: decoded a malformed input");
                *ok = false;
            }
            Err(e) if pred(&e) => println!("  ok   {label} -> {e}"),
            Err(e) => {
                println!("  FAIL {label}: wrong error {e}");
                *ok = false;
            }
        }
    };

    // Truncation at every prefix length must error, never panic.
    let mut trunc_ok = true;
    for cut in 0..bytes.len() {
        if Statement::decode(&bytes[..cut]).is_ok() {
            trunc_ok = false;
            break;
        }
    }
    note("codec truncation: every proper prefix rejects (no panic)", trunc_ok, &mut ok);

    // Trailing bytes.
    let mut extended = bytes.clone();
    extended.push(0);
    expect_err(
        "codec trailing bytes rejected",
        extended,
        &|e| matches!(e, DecodeError::TrailingBytes { .. }),
        &mut ok,
    );

    // Bad magic.
    let mut bad_magic = bytes.clone();
    bad_magic[0] ^= 0xff;
    expect_err(
        "codec bad magic rejected",
        bad_magic,
        &|e| matches!(e, DecodeError::BadMagic),
        &mut ok,
    );

    // Unknown codec version (bytes 4..8 after the 4-byte magic).
    let mut bad_cv = bytes.clone();
    bad_cv[4] = 0xff;
    expect_err(
        "codec unknown container version rejected",
        bad_cv,
        &|e| matches!(e, DecodeError::UnknownCodecVersion { .. }),
        &mut ok,
    );

    // Oversized length prefix: rewrite the commitment-count u32 to u32::MAX.
    // Its offset: magic(4) + cv(4) + version(4) + model_digest(32) +
    // table_present(1)+table(32+ (4+4+1)*2 + 8 + 8 = 82) + modulus_bits(4) +
    // backend(len 4 + "statement-codec"=15) + setup(len 4 + "codec-setup"=11).
    {
        let mut oversize = bytes.clone();
        // Corrupt the backend string's length prefix to a huge value; the
        // reader must reject it as LengthTooLarge, not allocate. Offset:
        // magic 4 + codec_ver 4 + version 4 + model_digest 32 + table_present
        // 1 + table (digest 32 + input 9 + output 9 + dmin 8 + dmax 8 = 66) +
        // modulus_bits 4 -> the backend length u32.
        let off = 4 + 4 + 4 + 32 + 1 + 66 + 4;
        oversize[off..off + 4].copy_from_slice(&u32::MAX.to_le_bytes());
        expect_err(
            "codec oversized length prefix rejected (no huge alloc)",
            oversize,
            &|e| matches!(e, DecodeError::LengthTooLarge { .. } | DecodeError::Truncated { .. }),
            &mut ok,
        );
    }

    // Semantic invalidity survives the wire: a decoded statement that fails
    // validation is rejected via DecodeError::Invalid. Build an invalid
    // statement (no outputs) and encode it directly (encode doesn't validate).
    {
        let mut invalid = codec_sample_statement();
        invalid.outputs.clear();
        let buf = invalid.encode();
        expect_err(
            "codec decoded-but-invalid statement rejected (re-validated)",
            buf,
            &|e| matches!(e, DecodeError::Invalid(_)),
            &mut ok,
        );
    }

    // Randomized bit-flip fuzz (fixed seed): no input, however corrupt,
    // may panic; every decode is Ok or a structured Err.
    {
        let mut state = 0x5eed_c0dec0deu64;
        let mut next = || {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            state
        };
        let mut fuzz_ok = true;
        for _ in 0..4000 {
            let mut buf = bytes.clone();
            let flips = 1 + (next() % 6) as usize;
            for _ in 0..flips {
                let i = (next() as usize) % buf.len();
                buf[i] ^= (next() & 0xff) as u8;
            }
            // Also sometimes truncate/extend.
            match next() % 3 {
                0 => buf.truncate((next() as usize) % (buf.len() + 1)),
                1 => buf.push((next() & 0xff) as u8),
                _ => {}
            }
            // The contract: decode returns without panicking. (Any panic
            // aborts the process under panic=abort and fails the battery.)
            let _ = Statement::decode(&buf);
        }
        note("codec fuzz: 4000 bit-flip/truncate/extend inputs, zero panics", fuzz_ok, &mut ok);
    }

    if ok {
        println!("statement-codec passed");
    } else {
        println!("statement-codec FAILED");
    }
    ok
}

// ===========================================================================
// [UAGB1-BD] dated ADDITIVE section (2026-08-08, U-AG-B1 wave 2 lane BD):
// the aggregated-artifact GROUP DESCRIPTOR — the statement-side object
// binding the W-C commitment-group layout (which tensors live in which
// group, each tensor's exact-digit class declaration, and the group's
// batched-opening count) into the model digest of an aggregated
// statement. E-O2' (AGGREGATION_ENCODING_DESIGN 8.2) binds one batched
// evaluation proof per group; the descriptor is what the builder's
// refusal and the statement-inventory print read. Nothing here touches
// QuantMeta or any existing codec (lane-BF territory); this is a pure
// addition consumed by the [UAGB1-BD] statement builder.

/// One tensor's row in an aggregated-artifact group descriptor.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AggTensorDecl {
    pub name: String,
    pub rows: u64,
    pub cols: u64,
    /// Exact-digit class declaration (name, e0, l0) — the frozen
    /// UAGB1-1a class-table semantics the aggregate layer consumes.
    pub class_name: String,
    pub e0: u32,
    pub l0: u32,
}

/// One commitment group of the aggregated artifact (W-C layout:
/// "act" always; "weight" per deployment mode).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AggGroupDescriptor {
    pub name: String,
    pub tensors: Vec<AggTensorDecl>,
    /// Batched openings emitted for this group. E-O2' requires exactly
    /// one; the builder REFUSES a second (build error, not a warning).
    pub openings: u32,
}

impl AggGroupDescriptor {
    /// Canonical bytes for the model digest (length-prefixed, order-
    /// preserving — any reordering, renaming, or class drift moves the
    /// statement digest).
    pub fn encode(&self) -> Vec<u8> {
        let mut out = b"agg-group-v1".to_vec();
        let put_str = |out: &mut Vec<u8>, s: &str| {
            out.extend((s.len() as u64).to_le_bytes());
            out.extend(s.as_bytes());
        };
        put_str(&mut out, &self.name);
        out.extend((self.tensors.len() as u64).to_le_bytes());
        for t in &self.tensors {
            put_str(&mut out, &t.name);
            out.extend(t.rows.to_le_bytes());
            out.extend(t.cols.to_le_bytes());
            put_str(&mut out, &t.class_name);
            out.extend(t.e0.to_le_bytes());
            out.extend(t.l0.to_le_bytes());
        }
        out.extend(self.openings.to_le_bytes());
        out
    }
}
