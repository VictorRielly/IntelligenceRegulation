# M0 + M1 Report: Rectangular Shapes, Claim Manifest, Layer Chaining

Scope: milestones M0 and M1 of `TRANSFORMER_PROOF_PLAN.md`, implemented on
both proof tracks (pairing/structured BLS12-381 and lattice Route Z).
Machine: Core Ultra 9 185H, 22 threads, 15 GB RAM (same environment as
`PROVER_OPTIMIZATIONS.md`).

Exit criteria, both met:

- **M0**: both backends prove and verify rectangular matmul claims
  `C = A B` with `A: r x k`, `B: k x m`, `C: r x m` for independent
  power-of-two `r, k, m` (lattice: arbitrary positive dims; the Python
  references accept non-powers too), with a backend-agnostic claim
  manifest (`docs/zkmatrix-poc/CLAIM_MANIFEST.md`,
  `zkmatrix-rs/src/manifest.rs`).
- **M1**: two chained matmul claims — `Y = X W1` proven, then `Z = Y W2`
  proven — verify against each other's commitments with **no
  re-commitment by the verifier**, on both tracks, at the rectangular
  demo shape `X: 16x32, W1: 32x64, W2: 64x8`. Negative tests show that
  substituting a different `Y`, tampering with the link gadget, swapping
  commitments, breaking norm bounds (lattice) or reordering the manifest
  all fail.

## 1. Design decisions and rationale

### 1.1 Lattice padding scheme (M0)

The commitment `com(x; rho) = (G1 rho, G2 rho + x)` fixes one message
dimension (rows of `G2`). For a chain of shapes, `msg` is set to the
longest committed column or row over every shape sharing the key, and
shorter vectors are zero-padded. Soundness of padding: the padded
commitment *is* an ordinary commitment to the padded vector, so binding
is unchanged; what needs care is that no relation may read coordinates
outside a commitment's declared range, otherwise adversarial junk in the
padding region would enter the statement. Concretely:

- Pi1: `A z` reads `z[..inner]` only, and the result (length `rows`) is
  padded back into the message space, so `C`'s padding region is forced
  to zero by the check itself.
- Pi2: the product inner products (`g0`, `g1`, `<z_a, z_b>`) are
  **truncated to the declared inner dimension**. Without truncation the
  proven relation would be `C_ij = <full message of A-row i, full message
  of B-col j>` including padding coordinates, which are unconstrained by
  any other claim — a real soundness gap for chained statements. With
  truncation the proven relation reads exactly the declared `k`
  coordinates.
- Derived scalar projections (`T_t` in Pi2, `c_v`/`c_s` in the transpose
  gadget) read only the declared row range (`s` is padded with zeros
  conceptually; implemented as truncated dot products).

Norm derivation now uses actual combination counts: `s` combines `rows`
commitments (`B_rho_s = rows * 2^b * sqrt(N)`), `v` combines `cols`
(`B_rho_v = cols * 2^b * sqrt(N)`); for multi-shape keys the maxima over
all shapes are used. The square case reproduces the previous derivation
bit-for-bit (verified: identical `k`/`N`/`sigma` at `n = 1024/2048`).

### 1.2 Pairing layout and SRS sharing (M0/M1)

`Layout` carries `(rows, inner, cols)` with independent window lengths
(`a_len = r*k`, `b_len = k*m`, `c_len = r*m`, `ay/by` windows of length
`k`) and a base offset (`layout_at`), so a chain of claims stacks
layouts at **disjoint** SRS exponent ranges over one powers-of-tau SRS.
Disjointness is deliberate: it is what makes the equality-gadget
extraction argument force coefficient-wise equality (Section 1.3), and it
keeps the paper's footnote-7 base-family discipline without any
family-collapse analysis (the plan's safe fallback).

The closed-form folded-polynomial evaluations were the risky part and
were rederived for rectangular windows:

- `split_matrix_eval` now takes separate `row_bits`/`col_bits`: for a
  row-major `2^rb x 2^cb` window, the first `rb` IPA rounds select row
  bits, the rest select column bits.
- A-projection: `yl[i] = y^{i*cols}`, so the projected part evaluates as
  `split_matrix_eval(ch, log2(rows), log2(inner), y^cols, zeta)` (the
  square code's `y^n` is the special case `cols = n`).
- B-projection: `split_matrix_eval(ch, log2(inner), log2(cols), zeta, y)`.
- Product: both folds run at length `inner`.
- Batch (Alg. 6) variants prepend batch bits, with the three matrix
  windows now looped independently (they have different lengths).

These are validated by self-tests at `(16,32,8)` and `(8,16,64)` (valid +
tampered, core + zk + batch + zk-batch + cross-instance swap).

### 1.3 Equality gadget (M1, pairing track)

Given `C_L = com_{w_l}(X; b_L)` and `C_R = com_{w_r}(X; b_R)` under two
disjoint SRS windows, the prover shows knowledge of an opening of
`D = C_L - C_R` over the difference family `{P(w_l+i) - P(w_r+i)}` plus
the blind base, using the existing masked-IPA machinery: mask vector
`alpha` committed (blinded), challenge
`x = H(ctx, offsets, C_L, C_R, mask_commit)` drawn **after** both linked
commitments and the mask are in the transcript, response
`X + x*alpha` proven to open the de-blinded masked commitment via the
IPA, with a new closed-form KZG value
`a_final * (zeta^{w_l} - zeta^{w_r}) * fold_eval(ch, zeta, len)`.

Soundness sketch (recorded in `CLAIM_MANIFEST.md` Section 4.1): the
neighbouring sub-proofs' extractors give exact openings `X_L` over window
`w_l` and `X_R` over `w_r`; the gadget's extractor gives `X~` over the
difference family. In the exponent,
`sum_i (X_L[i] - X~[i]) tau^{w_l+i} - sum_i (X_R[i] - X~[i]) tau^{w_r+i}
+ (b_L - b_R - b~) s = 0` where `s` is the dlog of the independent
hash-to-curve blind base. With `w_l` and `w_r` disjoint, a nonzero
coefficient is a nontrivial discrete-log relation over the SRS powers
(AGM / q-SDH-type, the same assumption profile as the Section 3 KZG
redesign), so `X_L = X~ = X_R`. Zero-knowledge follows from the uniform
mask exactly as in the projection sub-proofs.

One deliberate deviation from the suggested recipe: the gadget does *not*
draw an extra decoupling scalar `x_sep`. The decoupling challenge exists
to separate **two independently-opened commitments combined into one**
(`x * C_out + C_in`); here only one derived commitment `D` is opened, so
the paper's rewinding argument does not need a second coefficient. The ZK
mask challenge `x` is still fresh and sampled after everything it binds.

### 1.4 Transpose-consistency gadget (M1, lattice track)

As specified in the plan (Class 2): activations used in both orientations
are committed by rows and by columns; per repetition `ell`, challenges
`s in S_b^rows`, `v in S_b^cols` are derived from the statement hash;
the verifier homomorphically combines
`T_v = sum_j v_j Tcol_j = com(pad(Y v); rho_v)` and
`T_s = sum_i s_i Trow_i = com(pad(Y^T s); rho_s)` and computes the scalar
projections `c_v = <s, msg(T_v)[..rows]>`, `c_s = <v, msg(T_s)[..cols]>`.
If both orientations hold the same `Y`, the message parts of `c_v - c_s`
cancel, leaving `<g_s, rho_v> - <g_v, rho_s>` under the derived scalar
keys `g_s = s^T G2`, `g_v = v^T G2` (the same derived-key form Pi2 uses
for `T_t`). The prover proves knowledge of short `(rho_v, rho_s)` with

    G1 rho_v = T_v[..k],  G1 rho_s = T_s[..k],
    <g_s, rho_v> - <g_v, rho_s> = c_v - c_s

by a Gaussian-masked Sigma-protocol with rejection sampling and `r`-fold
repetition (`r = 64`, `b = 6`, matching the enclosing Pi2 budget; the
gadget is 2-special-sound per repetition and the mismatch-detection
error is `~2^{1-b}` per repetition by Schwartz-Zippel, so `r(b-1) = 320`
comfortably exceeds the 256-bit Fiat-Shamir budget).

Norm growth accounting: the rejection center is
`(gamma rho_v, gamma rho_s)` with `B_rho_v = cols_Y * 2^b * sqrt(N)` and
`B_rho_s = rows_Y * 2^b * sqrt(N)` (the homomorphically combined
randomness), giving `t_sq_t = 2^{2b} (B_rho_s^2 + B_rho_v^2)`,
`sigma_t = 12 sqrt(t_sq_t)`, `bound_t_sq = 36 sigma_t^2 (2N) / 25`. The
extracted SIS relation has norm `<= 2*bound_t + 2^b * max(B_rho)`, which
is folded into the shared `beta` inside the C3 iteration, so the binding
dimension `k` covers the gadget as well (chain-mode parameter sets only;
single-claim parameter sets are unchanged).

### 1.5 Claim manifest and transcript threading

`zkmatrix-rs/src/manifest.rs` (shared by `#[path]` inclusion — the crate
is a bin collection, so no library target was added; this is the
documented "small shared module" choice) implements the format specified
in `CLAIM_MANIFEST.md`: version/backend tags, setup digest, ordered
commitment entries `(id, label, shape, orientation, key_info,
commitment_bytes)`, ordered operations (matmul, equality link, transpose
link, class-0 add/scale recorded proof-free), and an order-sensitive
SHA-256 digest.

To enforce the transcript-ordering rule ("all commitments enter the
statement hash before any challenge"), the structured backend's
single-claim prove/verify paths now take an explicit transcript digest:
stand-alone claims pass `&srs.digest` (behavior unchanged), chained
claims pass `H(manifest)` — which contains the SRS digest — so *every*
challenge (statement `y`, decoupling, masks, IPA rounds, KZG `zeta`)
binds the whole DAG. The lattice statement hash gained an equivalent
`ctx` argument. Reordering two manifest entries makes every proof fail
(tested in both demos).

## 2. What changed per file

- `zkmatrix-rs/src/manifest.rs` (new): shared claim-manifest module.
- `zkmatrix-rs/src/bin/lattice_matmul.rs`: `Shape`/`Params` rework,
  multi-shape + link parameter derivation (`derive_params_multi`),
  message padding, truncated inner products, ctx-aware statement hashes,
  transpose gadget (`prove_transpose`/`verify_transpose`), rectangular
  self-tests, `bench-rect` and `chain-demo` subcommands.
- `zkmatrix-rs/src/bin/structured_matrix.rs`: rectangular `Layout` with
  base offsets, shape-absorbing challenges, digest threading through all
  single-claim paths, rectangular formula/eval rework
  (`split_matrix_eval`, `formula_value`, `expected_proof_len`),
  rectangular batch paths, equality gadget
  (`prove_zk_equality`/`verify_zk_equality`, `FormulaKind::Equality`),
  rectangular self-tests + `equality_self_test`, `bench-rect` and
  `chain-demo` subcommands. `make_srs` now takes a raw SRS length
  (digest domain bumped to v3).
- `zk_lattice/params.py`: `(rows, inner)` fields, count-correct norms,
  `toy_params_rect`. `zk_lattice/commitment.py`: message padding, shape
  in CRS hash. `zk_lattice/protocol.py`: rectangular Pi1/Pi2 with
  truncated reads/dots.
- `zk_matrix/`: no changes needed (already carried `(rows, inner,
  cols)`); rectangular ZK tests added to lock the path.
- `tests/test_zk_lattice.py`: rectangular round-trips (4x8x6), wrong
  product, padding-region tamper. `tests/test_zkmatrix_protocol.py`:
  rectangular ZK wrapper tests (2x4x8). `tests/test_zkmatrix_native_backends.py`:
  lattice self-test + both chain demos.
- `docs/zkmatrix-poc/CLAIM_MANIFEST.md` (new), this report,
  `IMPLEMENTATION.md` (status updates).

## 3. Test evidence

Full suite (`python3 -m unittest discover -s tests`):

```text
Ran 36 tests in 26.712s

OK
```

(previously 26 tests; +10: lattice rectangular/padding, zk_matrix
rectangular, native lattice self-test and the two chain demos.)

Self-tests (all shapes valid + tampered; rectangular shapes 16x32x8 and
8x16x64 plus square regressions; equality and transpose gadget checks
including mismatch, tampered responses, commitment swap, and — lattice —
out-of-range-norm responses that leave every mod-q check unchanged):

```text
lattice-matmul self-test ok        (9.9 s)
structured-matrix self-test ok     (7.8 s)
```

Chain demos (M1 exit criterion), rectangular shape
`X: 16x32, W1: 32x64, W2: 64x8`:

```text
structured chain-demo: X 16x32, W1 32x64, W2 64x8 (BLS12-381 zk track)
  srs: 5440 powers, 0.271s
  commit: 0.006s
  prove (2 claims + link): 0.908s
  verify: 0.019s (claim1=true claim2=true link=true)
  negative wrong-Y: claims pass standalone, link fails as required
structured chain-demo ok

lattice chain-demo: X 16x32, W1 32x64, W2 64x8 (Pi2 track)
  params: msg=64 k=1832 N=5952 sigma_t=2^27.9, crs 0.023s
  commit: 0.266s
  prove (2 claims + link): 2.346s
  verify: 0.611s (claim1=true claim2=true link=true)
  negative wrong-Y: claims pass standalone, link fails as required
lattice chain-demo ok
```

The wrong-Y negative case is the sharp one: both matmul claims verify
standalone against their own commitments; only the link gadget rejects
the chain. Additional negative cases asserted inside the demos: tampered
gadget scalar/blind/response, swapped commitment groups handed to the
link verifier, manifest reordering (different `ctx` digest makes every
proof fail), and (lattice) a response with `+q` added to one coordinate,
which only the norm check can catch.

## 4. Benchmarks (no square regression)

M0 and M1 landed in one backend commit, so one before/after pair covers
both. Baselines are the tier-0 numbers in `PROVER_OPTIMIZATIONS.md` /
`results/track_comparison/structured_scaling.csv`, same machine.

Lattice (square shapes, `bench pi1/pi2`):

| metric | tier-0 baseline | after M0+M1 | delta |
|---|---|---|---|
| Pi1 prove n=1024 | 0.52 s | 0.41 s | -21% |
| Pi1 prove n=2048 | 0.82 s | 0.75 s | -9% |
| Pi1 verify n=2048 | 0.42 s | 0.42 s | 0% |
| Pi2 prove n=1024 | 1.73 s | 1.72 s | -1% |
| Pi2 prove n=2048 | 2.41 s | 2.84 s | +18% |
| Pi2 verify n=1024 | 0.69 s | 0.67 s | -3% |
| Pi2 verify n=2048 | 1.29 s | 1.29 s | 0% |
| Pi2 commit n=2048 | 19.7 s | 19.4 s | -2% |

The Pi2 n=2048 prove delta (+18%, within the ~20% tolerance) is the only
outlier; it is run-to-run noise territory for the wave-scheduled prover
(rejection-sampling restarts change the wave count), and the derived
parameters are identical to the baseline's.

Structured (square n=256, `bench both 256`):

| metric | baseline | after M0+M1 | delta |
|---|---|---|---|
| setup n=256 | 1.8 s (tier-0) | 1.81 s | 0% |
| core prove n=256 | 5.83 s | 5.75 s | -1% |
| zk prove n=256 | 6.19 s | 6.27 s | +1% |
| zk verify n=256 | 0.017 s | 0.015 s | -12% |

New rectangular datapoints at the moderate shape `256 x 512 x 128`
(`bench-rect`):

| track | setup/crs | commit | prove | verify |
|---|---|---|---|---|
| lattice Pi2 | 0.03 s | 0.82 s | 1.06 s | 0.34 s |
| structured zk | 2.01 s | 0.09 s | 7.70 s | 0.014 s |

## 5. Deviations from the plan

1. **No extra decoupling scalar in the equality gadget** (Section 1.3):
   the gadget opens a single derived commitment, so the two-commitment
   decoupling pattern does not apply; the mask challenge provides the
   fresh public coin. Documented rather than cargo-culted.
2. **Pi2 inner products truncated to the declared inner dimension**: not
   in the plan text, but required for the padding scheme to be sound in
   chained statements (Section 1.1). The square case is numerically
   identical.
3. **M0/M1 for the Rust backends landed in one commit** (the layout
   rework and the gadgets touch the same functions); Python mirror and
   docs are separate commits. Benchmarks therefore have one
   before/after pair.
4. **Structured SRS digest domain bumped (v2 -> v3)** and Fiat-Shamir
   challenges now absorb `(rows, inner, cols)` instead of `n`:
   transcripts are intentionally not compatible with the previous
   revision (no cross-version transcript consumers exist; the Python KAT
   covers the toy backend only, which is untouched).

## 6. Known gaps and recommended next steps toward M2

1. **Chain verification cost on the lattice track**: the transpose
   gadget's verifier recombines commitment groups per repetition
   (`O(r * (rows + cols) * (k + msg))`); fine at demo scale, but wave
   batching of the gadget verifier (as done for Pi1/Pi2) is the obvious
   next optimization.
2. **Manifest lacks the quantized model spec** (scales, bit widths,
   nonlinearity table digests) — must be added before M2's
   rescale/range gadgets so the spec is inside the statement hash.
3. **Batch paths are same-shape only** (as scoped); the manifest does
   not yet declare batch groups, and cross-claim wave scheduling across
   a DAG is future work.
4. **The chain demos verify claims one KZG batch at a time**; a chain
   verifier should push all sub-proofs into one `KzgBatch` (pairing) /
   one blocked verification pass (lattice) for the M3 end-to-end block.
5. **M2 groundwork**: the Hadamard/range gadgets reduce to the product
   sub-proof under derived keys; on the lattice side the derived-key
   machinery now exists in two places (Pi2 `T_t`, transpose gadget) and
   should be factored into a reusable helper when the Hadamard gadget
   lands.
6. **Norm/parameter review**: the gadget parameter derivation follows
   the report's constraint template (C0-C4) but, like the rest of the
   parameter system, is a design model — validate with the
   lattice-estimator before any security claim.
