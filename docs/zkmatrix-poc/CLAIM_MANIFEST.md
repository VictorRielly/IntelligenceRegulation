# Claim Manifest: Backend-Agnostic Statement Format for a Claim DAG

Status: implemented for M0/M1 as `zkmatrix-rs/src/manifest.rs`, shared by
`#[path]` inclusion from both proof binaries (`structured_matrix` and
`lattice_matmul`). This document is the specification; the module is the
minimal concrete realization sufficient to drive the M1 chained-inference
demos. See `TRANSFORMER_PROOF_PLAN.md` Section 3 for the batching
architecture this format is designed to grow into.

## 1. Purpose

A multi-operation proof (ultimately: one transformer forward pass) is a
*claim DAG* over one global commitment set. The manifest is the statement:
it declares every commitment, every operation over those commitments, and
the setup they live under. Proofs are made and verified *against a manifest
digest*, never against loose commitments, so that:

- a proof for one DAG cannot be transplanted into another (context
  binding);
- every Fiat-Shamir challenge in every claim provably comes after every
  commitment in the DAG (transcript ordering);
- the verifier's work is defined entirely by the manifest plus the proof
  objects — it never re-commits any matrix.

## 2. Manifest contents

A manifest consists of, in fixed serialization order:

1. **Version tag** (`zkmatrix-claim-manifest-v1`) and **backend tag**
   (`structured-bls12381`, `lattice-route-z-pi2`, ...). The tags are
   absorbed into the digest, so proofs are bound to one protocol version
   and one backend.
2. **Setup digest**: the backend's setup binding — the structured SRS
   digest (which itself binds `srs_len`, `tau G`, `tau H`, `u`, the blind
   base) or the lattice CRS hash (which binds the seed, modulus, message
   dimension, `k`, `N`, `b`, `r`).
3. **Commitment manifest**: an ordered list of entries
   `(id, label, rows, cols, orientation, key_info, commitment_bytes)`:
   - `id`: dense index assigned in insertion order; operations reference
     ids.
   - `label`: human-readable role name ("X", "W1", "Y", ...). Hashed, so
     it is part of the statement.
   - `rows x cols`: the declared matrix shape. Every gadget reads only the
     declared coordinate ranges of a commitment (see the padding rules in
     the backend notes below), so the shape declaration is load-bearing.
   - `orientation`: how the matrix is committed —
     `RowMajor` (one commitment to the row-major flattening; pairing
     track), `ByRows` / `ByColumns` (one commitment per row/column;
     lattice track). A matrix may appear under several entries with
     different orientations (dual-orientation activations on the lattice
     track) or under different key windows (pairing track); each entry is
     a distinct id and a link operation ties them together.
   - `key_info`: backend key binding — the SRS window offset for the
     pairing track (each entry must name the exponent window its
     commitment opens over), the message dimension for the lattice track.
   - `commitment_bytes`: the commitment itself — a compressed G1 point
     (pairing) or a SHA-256 digest of the per-column/per-row commitment
     group (lattice; the group itself travels with the proof and the
     verifier recomputes the digest).
4. **Operation list**, ordered:
   - `Matmul { a, b, c }`: a committed matmul claim `C = A B` over entry
     ids; carries one matmul proof (zkMatrix-zk / Pi2).
   - `LinkEqual { left, right }`: commitment-equality link (pairing
     track); carries one equality-gadget proof.
   - `LinkTranspose { by_rows, by_cols }`: transpose-consistency link
     (lattice track); carries one transpose-gadget proof.
   - `Add { inputs, output }` / `Scale { input, output, scalar }`:
     class-0 homomorphic operations. **Recorded but proof-free**: the
     verifier recomputes `output`'s commitment from the inputs'
     commitments (`com(X + O) = com(X) + com(O)`, blinds add) and rejects
     the manifest if the recomputed commitment disagrees with the entry.

## 3. Transcript-ordering rule

**All commitments enter the statement hash before any challenge is
derived.** Concretely:

1. The prover commits everything first — weights, inputs, every
   intermediate activation (in every orientation it is used), every
   auxiliary witness — and assembles the manifest.
2. `ctx = manifest.digest()` is computed. The digest is order-sensitive
   over the full serialization of Section 2.
3. Every Fiat-Shamir challenge of every claim and link gadget absorbs
   `ctx` at the base of its transcript:
   - pairing track: `ctx` replaces the bare SRS digest as the transcript
     seed threaded through every challenge (statement challenge `y`,
     decoupling challenges, mask challenges, IPA round challenges, KZG
     `zeta`) — the SRS digest itself is inside the manifest, so setup
     binding is preserved;
   - lattice track: `ctx` is absorbed into each claim's statement hash
     `h0`, from which all repetition challenges derive.
4. Per-proof mask/aggregation challenges are still derived after the
   specific commitments they bind (mask commitments, `d/ay/by`
   commitments, response blinds), exactly as in the single-claim
   protocols; the manifest digest is *in addition to*, not instead of,
   the existing ordering discipline.

Consequence (tested in both chain demos): reordering any two manifest
entries changes `ctx`, and every proof made for the honest ordering fails
against the reordered manifest.

## 4. Backend notes

### 4.1 Pairing track (structured BLS12-381)

- One SRS serves the whole DAG. Each matmul claim gets a `Layout` block of
  SRS exponent windows (`ay`, `by`, `A`, `B`, `C`) placed at a base offset
  via `layout_at`; blocks of distinct claims are **disjoint by
  construction**. Disjointness is required by the equality-gadget
  extraction argument (a nontrivial relation across two overlapping
  windows would not force coefficient-wise equality) and preserves the
  paper's footnote-7 discipline: no base family is shared across
  sub-proofs, so the base-family collapse analysis is not needed (the
  safe-fallback design).
- `LinkEqual` between entry `L` (window `w_l`) and entry `R` (window
  `w_r`) is proven by the equality gadget: knowledge of an opening of
  `D = C_L - C_R` over the difference family `{P(w_l+i) - P(w_r+i)}` plus
  the blind base, via the existing masked-IPA + Section 3 KZG machinery.
  Soundness sketch: the extractors of the neighbouring matmul sub-proofs
  yield openings `X_L` (over `w_l`) and `X_R` (over `w_r`); together with
  the difference opening `X~`, the exponent identity
  `sum_i (X_L[i] - X~[i]) tau^{w_l+i} - sum_i (X_R[i] - X~[i]) tau^{w_r+i}
  + (b_L - b_R - b~) s = 0` (with `s` the independent hash-to-curve blind
  base's dlog) must hold; with disjoint windows, any nonzero coefficient
  is a nontrivial discrete-log relation over the SRS (AGM / q-SDH-type),
  hence `X_L = X~ = X_R`.

### 4.2 Lattice track (Route Z)

- One CRS `(G1, G2)` serves the whole DAG. The message dimension `msg`
  (rows of `G2`) covers the longest committed column/row over all shapes;
  shorter vectors are zero-padded, i.e. each commitment is an ordinary
  commitment to the padded vector. Every relation reads only the declared
  coordinate ranges, so padding junk in an adversarial commitment cannot
  influence any verified statement (the Pi2 product inner products are
  explicitly truncated to the declared inner dimension for this reason).
- `LinkTranspose` between a `ByRows` entry and a `ByColumns` entry of the
  same matrix is proven by the transpose-consistency gadget (per
  repetition: random `s, v`; homomorphically derived `com(Y v)` and
  `com(Y^T s)`; derived-key Sigma-protocol for
  `s^T (Y v) = v^T (Y^T s)`), with the gadget's Gaussian parameters sized
  for the combined-randomness norm growth and its extracted-relation norm
  folded into the shared SIS bound `beta`.

## 5. Known gaps (toward M2+)

- The manifest does not yet carry the quantized model spec (scale
  factors, bit widths, nonlinearity tables); that field set is required
  before M2's rescale/range gadgets and must be added to the digest.
- Same-shape batching (Algorithm 6 / wave scheduling) currently runs per
  claim family outside the manifest; the manifest should eventually
  declare batch groups so the verifier knows which claims share one
  batched proof.
- Serialization is hash-defined but not yet a wire format; the Rust
  structs are the source of truth.
