# zkMatrix Implementation Guide

This directory documents the current zkMatrix proof-of-concept implementation.
The goal is to reproduce the zkMatrix paper's matrix multiplication proof
structure and benchmark when proof generation becomes comparable to dense
matrix multiplication.

Reference paper:

- `docs/zkmatrix-poc/references/zkMatrix-eprint-2024-161.pdf`
- https://eprint.iacr.org/2024/161.pdf
- Reviewed against the ePrint revision of 2025-02-05 (Cong-Yuen-Yiu,
  AsiaCCS 2024). Re-check claims against the AsiaCCS camera-ready before
  publishing comparisons.

Companion lattice track (post-quantum): `zk_lattice/` implements the two
protocols of `zk-matrix-multiplication-lattice.pdf` (Route Z reference); see
"Lattice Track" below.

Both backends support rectangular claims `C = A B` with `A: r x k`,
`B: k x m`, `C: r x m` (transformer plan milestone M0) and layer chaining
of two matmul claims through a shared activation commitment (milestone
M1: commitment-equality gadget on the pairing track, dual-orientation
commitments plus a transpose-consistency gadget on the lattice track).
The backend-agnostic statement format for multi-claim DAGs is specified
in `CLAIM_MANIFEST.md`; design details, soundness arguments, test
evidence and benchmarks are in `M0_M1_REPORT.md`.

The lattice track additionally implements the M2 elementwise gadget
family (Hadamard/binary claims, packed range proofs, rescale-with-
rounding; `M2_REPORT.md`, including the exit-criterion cost finding) and
the M3 end-to-end quantized FFN block demo (`lattice_matmul ffn-demo`:
two chained matmul claims, bias-broadcast link, rescale + ranges,
sign-bit/Hadamard/range ReLU, transpose links, Class-0 residual, all
under one claim manifest; `M3_REPORT.md`).

## What The Code Implements

The implementation proves committed matrix multiplication statements:

```text
C = A B
```

where `A`, `B`, and `C` are committed matrices. The code follows the paper's
Algorithm 4 reduction:

1. Sample a Fiat-Shamir challenge `y`.
2. Project `C` to a scalar `d = <flatten(C), (1, y, ..., y^(mn-1))>`.
3. Project `A` to `a_y = y_L A`.
4. Project `B` to `b_y = B y_R`.
5. Prove the four linked inner-product relations:
   - `d = <flatten(C), y_vector>`
   - `a_y = y_L A`
   - `b_y = B y_R`
   - `d = <a_y, b_y>`

The optimized zero-knowledge path follows the paper's note after Algorithm 5:
instead of applying the naive whole-matrix masking wrapper, it inserts masks
inside the four Algorithm 4 subprotocols. This avoids the naive wrapper's
extra `O(n^3)` mask-product cost.

The native Rust prover also specializes the large inner-product projection
proofs. When a proof has no `h` vector, it skips the zero-vector work, fuses the
per-round dot products into one pass, and parallelizes large vector folds. This
keeps the protocol algebra unchanged but removes a large constant factor from
the three `O(n^2)` projection proofs.

## Deviations From The Paper

The implementations are a reproduction plus a small number of deliberate
deviations. Each is recorded here so reviewers do not have to rediscover them.

1. Fresh decoupling challenge `x` (paper-faithful, previously missing).

   The paper's Algorithms 2-3 combine each sub-proof's input and output
   commitments as `x * C_out (+) C_in` with a fresh public-coin challenge
   `x`; the knowledge-soundness proofs (Theorems 2-3) rewind over two values
   of `x` to separate the two commitments' contributions. Earlier revisions
   of this code fixed that coefficient to 1. All implementations (Python,
   C, Rust toy backend, Rust BLS12-381 structured backend, including the
   Algorithm 6 batch paths) now derive one extra Fiat-Shamir scalar per
   sub-proof, sampled after every commitment and response blind entering
   the combined commitment, and scale the output commitment and the output
   base family by it. The Python test suite locks the transcript with a
   known-answer test (`test_transcript_kat_locks_decoupling_challenges`).

2. Section 3 verifier: KZG opening at a fresh point `zeta` instead of the
   paper's dual `nu`-shifted SRS.

   The paper realizes its accelerated verifier with a second, `nu`-shifted
   SRS and proves it under q-PDH/q-PKE/q-BSDH-type assumptions. The Rust
   structured backend instead runs a standard KZG opening: after the IPA
   transcript is fixed, a fresh Fiat-Shamir point `zeta` is drawn, the
   prover opens the folded basis polynomial at `zeta`, and the verifier
   evaluates the public folded polynomial in closed form (`formula_value`,
   the Eq.-15-style product formulas, including the batched variants) and
   checks

   ```text
   e(C - v * G, H) = e(W, tau * H - zeta * H)
   ```

   This is a redesign, not a transcription: it rests on KZG evaluation
   binding (AGM / q-SDH-type assumptions), which is more standard than the
   paper's assumption set. Soundness of the closed-form evaluation relies
   on `zeta` being sampled after the IPA transcript (Schwartz-Zippel over
   the committed polynomial identity).

3. Setup digest bound into every Fiat-Shamir challenge.

   All bases/SRS elements are deterministic hash-to-group outputs or SRS
   powers, so binding was previously implicit. Every implementation now
   absorbs an explicit setup digest plus the protocol version and the
   parameter tuple into its challenge derivations: Python hashes the
   generating label set and parameters into `MatmulBases.digest`; the C and
   Rust toy backends mix `setup_digest(n)` into every challenge domain; the
   structured backend hashes `(n, srs_len, tau*G, tau*H, u, blind)` into
   `StructuredSrs.digest` and absorbs it in every challenge, including the
   per-round IPA and KZG challenges.

4. Unconditional Pedersen blinding.

   `commit_*` previously skipped the blinding term when the blind was zero.
   Blinding is now applied unconditionally (a zero blind contributes the
   identity), removing a data-dependent branch without changing any
   commitment value.

## Trusted Setup

The benchmarks generate `tau` locally and discard it, which is correct for
benchmarking only. Any deployment claim requires:

- an MPC ceremony or imported powers-of-tau for the structured SRS, with
  explicit subgroup and point-validation checks on every imported element,
  and a pairing consistency check `e(powers[i+1], H) = e(powers[i], tau*H)`;
- the Pedersen blind base and `u` base with unknown discrete-log relation
  to the SRS powers (hash-to-curve, as implemented);
- awareness that the SRS is `O(n^2)`-sized (about 150 MB at `n = 1024`) and
  shape-specific under the current layout.

## Repository Layout

```text
zk_matrix/                         Pure-Python reference implementation
zk_matrix/README.md                Python reference usage and caveats
zkmatrix-rs/                       Optimized Rust implementation
zkmatrix-rs/README.md              Rust backend usage and benchmark notes
zk_matrix_fast/                    C reference backend used during optimization
zk_lattice/                        Lattice-based (post-quantum) proofs, Route Z
scripts/benchmark_zk_lattice.py    Lattice proof benchmark
scripts/benchmark_zkmatrix.py      Python proof benchmark
scripts/benchmark_zkmatrix_rust.py Rust proof benchmark wrapper
scripts/benchmark_section3_kzg.py  Section 3 KZG verifier benchmark wrapper
scripts/benchmark_curve_ipa.py     BLS12-381 hash-to-curve IPA benchmark wrapper
scripts/benchmark_structured_matrix.py
                                   BLS12-381 structured matrix proof benchmark
scripts/benchmark_structured_matrix_batch_vs_gemm.py
                                   Batched structured proof versus local GEMM
scripts/analyze_structured_batch_scaling.py
                                   Fits fixed and marginal batch proof costs
scripts/benchmark_zkmatrix_vs_fast_gemm.py
                                   Compares proof timing to local GEMM backends
tests/test_zkmatrix_protocol.py    Python protocol correctness tests
tests/test_zkmatrix_native_backends.py
                                   Rust accept/reject checks against Python behavior
tests/test_zk_lattice.py           Lattice protocol correctness tests
```

## Lattice Track

`zk_lattice/` is a pure-Python reference implementation (Route Z of the
companion report `zk-matrix-multiplication-lattice.pdf`) of two protocols:

- `Pi1`: `C = A B` with `A` public and `B`, `C` hidden behind per-column
  Ajtai/BDLOP commitments (`com(x; rho) = (G1 rho, G2 rho + x)`, ternary
  randomness). Binding reduces to SIS in the relaxed slack-scaled sense;
  hiding is statistical (leftover hash lemma) or computational
  (knapsack-LWE) depending on the parameter regime.
- `Pi2`: all three matrices hidden. Double Freivalds compression reduces
  the claim to one scalar inner product; a quadratic garbage-term product
  Sigma-protocol (commitments `t0`, `t1`) handles the single product gate.

Both are non-interactive via Fiat-Shamir with SHAKE-256 and Schnorr-style
transcript compression; masked responses use uniform-mod-q masking in the
message slot and Gaussian rejection sampling (alpha = 12, M ~= 2.76) in the
randomness slot, with the accept decision evaluated in >= 128-bit fixed
point. `zk_lattice/params.py` encodes the report's constraint system
(C0-C4); `toy_params` is for tests, and the `reference_params_pi1/pi2`
sets mirror the report's worked `n = m = 1024` columns. Before any
deployment, validate concrete parameters with the Albrecht-Player-Scott
lattice estimator; C3/C4 are design models, not a security review.

Setup is transparent (the CRS is expanded from a public seed), there is no
pairing or curve arithmetic anywhere, and the protocols are conjectured
post-quantum (SIS / knapsack-LWE). Proof sizes are linear in `r * N`
(megabytes at reference parameters); the report's Route R (cyclotomic ring)
and LaBRADOR/Greyhound folding are the documented paths to 50-150 KB and
sublinear proofs respectively.

## Requirements

For the Python reference:

```bash
python3
```

For the optimized backend:

```bash
cargo
rustc
```

On macOS with Homebrew:

```bash
brew install rust
```

Optional matrix-multiplication comparison backends:

```bash
python3 -m pip install numpy scipy torch jax jaxlib
```

CuPy is not useful on this Apple Silicon machine unless a CUDA/ROCm-capable
environment is available.

## Build And Test

Run all local tests:

```bash
python3 -m unittest discover -s tests
```

Build and self-test the Rust backend directly:

```bash
cd zkmatrix-rs
cargo build --release
./target/release/zkmatrix-rs self-test
./target/release/section3_kzg self-test
./target/release/curve_ipa self-test
./target/release/structured_matrix self-test
./target/release/lattice_matmul self-test
```

Chained-inference demos (M1: `Z = (X W1) W2` with the activation
commitment shared between the claims, including negative link cases):

```bash
./target/release/structured_matrix chain-demo   # 16x32, 32x64, 64x8
./target/release/lattice_matmul chain-demo
```

Rectangular single-claim benchmarks:

```bash
./target/release/structured_matrix bench-rect zk 256 512 128
./target/release/lattice_matmul bench-rect pi2 256 512 128
```

## Benchmarks

Python reference benchmark:

```bash
python3 scripts/benchmark_zkmatrix.py --backend toy --sizes 2 4 8 16 32 64 128 256
```

Optimized Rust benchmark:

```bash
python3 scripts/benchmark_zkmatrix_rust.py --mode both --sizes 2048 3072 4096
```

The Rust benchmark compares proof generation with dense exact finite-field
matrix multiplication over the same toy field. Recent local results after the
fused projection-proof optimization:

```text
core 2048: prove = 0.187 s, proof/exact-matmul ~= 0.37
core 4096: prove = 0.496 s, proof/exact-matmul ~= 0.13
core 6144: prove = 1.043 s, proof/exact-matmul ~= 0.08
core 8192: prove = 1.640 s, proof/exact-matmul ~= 0.05

zk   2048: prove = 0.244 s, proof/exact-matmul ~= 0.49
zk   4096: prove = 0.631 s, proof/exact-matmul ~= 0.16
zk   6144: prove = 1.294 s, proof/exact-matmul ~= 0.10
zk   8192: prove = 2.082 s, proof/exact-matmul ~= 0.07
```

So the optimized Rust proof now crosses dense exact finite-field multiplication
by `2048 x 2048` on the local Apple Silicon machine.

Section 3 accelerated verifier primitive:

```bash
python3 scripts/benchmark_section3_kzg.py --degrees 1024 4096 16384 65536 262144
```

This benchmark implements the paper's KZG-style opening check over BLS12-381
with `blstrs`/`blst` Pippenger MSM. It compares the direct verifier MSM that
Section 3 removes with the pairing verification cost that replaces it. Recent
local CPU results:

```text
degree 1024:    direct MSM 0.000955 s, accelerated verify 0.000758 s
degree 4096:    direct MSM 0.001526 s, accelerated verify 0.000689 s
degree 16384:   direct MSM 0.005013 s, accelerated verify 0.000686 s
degree 65536:   direct MSM 0.019446 s, accelerated verify 0.000704 s
degree 262144:  direct MSM 0.075567 s, accelerated verify 0.000708 s
degree 1048576: direct MSM 0.301262 s, accelerated verify 0.000704 s
```

Production-curve IPA primitive:

```bash
python3 scripts/benchmark_curve_ipa.py --lengths 1024 4096 16384 65536 262144
python3 scripts/benchmark_curve_ipa.py --structured --lengths 1024 4096 16384 65536 262144
```

This benchmark uses independent BLS12-381 hash-to-curve bases for a Pedersen
inner-product commitment. It is the production-style commitment primitive, but
it intentionally uses the ordinary IPA verifier:

```text
len 1024:   setup 0.102363 s, prove 0.140858 s, verify 0.108560 s
len 4096:   setup 0.295177 s, prove 0.470504 s, verify 0.430533 s
len 16384:  setup 1.180944 s, prove 1.779581 s, verify 1.715264 s
len 65536:  setup 4.722018 s, prove 6.992621 s, verify 6.849216 s
len 262144: setup 18.879730 s, prove 27.926828 s, verify 27.432946 s
```

The linear verifier here explains the current full matrix verifier behavior.
Logarithmic verification requires the Section 3 structured SRS/KZG path, not
independent hash-to-curve bases.

Structured Section 3 verifier results:

```text
len 1024:   prove+open 0.151441 s, direct verify 0.111863 s, fast verify 0.002034 s
len 4096:   prove+open 0.500831 s, direct verify 0.430192 s, fast verify 0.002197 s
len 16384:  prove+open 1.906602 s, direct verify 1.811845 s, fast verify 0.002785 s
len 65536:  prove+open 7.228505 s, direct verify 6.848037 s, fast verify 0.002676 s
len 262144: prove+open 28.756263 s, direct verify 28.142888 s, fast verify 0.003009 s
```

The Section 3 KZG check is now integrated into the BLS12-381 structured matrix
proof. The single-matrix path also has Pedersen-hiding commitments, OS-backed
random proof masks, and masked ZK subprotocols for the `C`, `A`, `B`, and
product proofs.

## Important Limits

This is still a proof-of-concept, not a production prover.

- The BLS12-381 structured single-matrix proof is cryptographically meaningful,
  but it has not had an external audit.
- The structured SRS must come from a trusted or MPC setup where the toxic waste
  `tau` is not known to the prover, and the Pedersen blind base must have
  unknown discrete-log relation to the SRS powers.
- Fiat-Shamir challenges are modeled as random-oracle challenges over the
  transcript. The benchmark code is not a final serialization format.
- The structured batch proof now has an Algorithm 6-style masked ZK path:
  the three length-`n^2` projection subproofs are run once on `rho`-aggregated
  inputs, while the length-`n` product subproof remains per multiplication.
- The full matrix proof backend does not yet use GPU MSM or a true fixed-base
  MSM precomputation table.
- The prover remains much slower than float32 tensor-core or Apple Accelerate
  GEMM at matrix sizes through `256 x 256`.

## Next Engineering Steps

The first three roadmap steps now exist as a correctness-first prototype in
`zkmatrix-rs/src/bin/structured_matrix.rs`. The remaining work is to harden and
optimize that prototype into the production backend.

1. Derive full matrix structured-SRS formulas.

   The current full matrix proof materializes projected bases:

   ```text
   C bases:           C_ij
   A projected bases: A_ij + yL_i * AY_j
   B projected bases: B_ij + yR_j * BY_i
   ```

   Section 3 verification requires those bases to be represented as known
   polynomials over a structured SRS instead of arbitrary vectors. The next
   proof-system task is to assign SRS exponent ranges for `A`, `B`, `C`,
   `AY`, `BY`, scalar, and blind bases, then derive verifier-side polynomial
   evaluation formulas for the `C`, `A`, and `B` projection proofs.

   Status: implemented for the core matrix proof. The structured prototype
   assigns exponent ranges for `A`, `B`, `C`, `AY`, and `BY`, and verifies all
   four matrix IPAs through Section 3 KZG openings.

2. Replace the toy matrix commitment layer with BLS12-381 structured bases.

   The `curve_ipa` binary proves the production-curve IPA primitive works, but
   the full matrix proof still uses `u64` additive commitments. After Step 1,
   wire the full `prove_zk` and `verify_zk` matrix flow to structured
   BLS12-381 commitments.

   Status: implemented as a separate BLS12-381 structured matrix binary. The
   old toy backend is retained for fast regression and large-shape experiments.

3. Add Algorithm 6 same-shape batching.

   Same-shape batching should combine many layer/head matrix multiplication
   claims that share dimensions. For a transformer workload, this should batch
   repeated MLP, Q/K/V/O, and attention score/value multiplications whenever
   shapes align.

   Status: implemented for the structured ZK matrix proof with
   `structured_matrix bench-batch zk <n> <batch_count>`. The batch mode follows
   Algorithm 6's transcript order: derive `y`, commit each `d_i`, `ay_i`, and
   `by_i`, derive `rho`, aggregate `A`, `B`, and `C` commitments and witnesses,
   run one length-`n^2` ZK projection proof for each of `C`, `A`, and `B`, and
   run one length-`n` ZK product proof per matrix multiplication.

   Recent local results against Apple Accelerate SGEMM are stored in:

   ```text
   docs/zkmatrix-poc/results/structured_matrix_batch_vs_sgemm_zk_alg6_n64_2026-06-10.csv
   docs/zkmatrix-poc/results/structured_matrix_batch_vs_sgemm_zk_alg6_n128_2026-06-10.csv
   docs/zkmatrix-poc/results/structured_matrix_batch_vs_sgemm_zk_alg6_n256_2026-06-10.csv
   ```

   At `n=256`, proof generation was `2.82s` for one claim and `5.20s` for
   sixteen claims, reducing per-claim prover time from `2.82s` to `0.325s`.
   This shows the intended Algorithm 6 amortization in the curve-proof work,
   although it remains far slower than optimized floating-point GEMM.

   At `n=1024`, the current product-SRS implementation has been measured for
   `t in {1,2,4,8,16}` using the shared-setup batch-series benchmark. The raw
   CSV and fitted projection are:

   ```text
   docs/zkmatrix-poc/results/structured_matrix_batch_vs_sgemm_zk_product_srs_series_n1024_2026-06-10.csv
   docs/zkmatrix-poc/results/structured_matrix_batch_vs_sgemm_zk_product_srs_series_n1024_scaling_2026-06-10.txt
   ```

   The fitted model is approximately `36.65s + 0.253s * t`, projecting to
   `296s` total and `0.289s` amortized per proof at `t=1024`. This is better
   than the paper Table 3 prover-time estimate of `512.48s` total and `0.50s`
   amortized per proof. The current benchmark still stores all dense witnesses
   and therefore cannot validate Table 3's `304 MB` RAM claim.

4. Add fixed-base and streaming MSM for prover commitments/openings.

   The prover bottleneck after Section 3 is MSM, not verification. Use cached
   fixed-base precomputation for reusable SRS bases, avoid materializing
   projected bases when a streaming polynomial/MSM formula is available, and
   benchmark memory bandwidth separately from scalar multiplication.

   Status: partially implemented. Contiguous SRS-window commitments now avoid
   basis materialization, no-`h` IPA proofs skip dummy curve-base folding, large
   dot products/folds run through Rayon, witness field matmul is row parallel,
   and product proofs open low-degree `AY/BY` polynomials instead of the full
   matrix SRS. A true reusable fixed-base MSM table is still missing.

5. Add batched product-proof dot products.

   The Algorithm 6 ZK batch path currently amortizes the three length-`n^2`
   projection proofs, but it still runs the `t` length-`n` product proofs as
   independent IPAs. Each product IPA computes repeated scalar-field dot
   products and vector folds. For a large batch, those operations should be
   scheduled together as batched row-wise finite-field kernels, similar to the
   memory shape of a matrix operation but over the BLS12-381 scalar field.

   Deliverable: `prove_zk_products_batched` should preserve the per-instance
   product-proof transcript while sharing round scheduling, fusing all product
   dot products and folds across the batch, and preparing for GPU/fixed-base
   KZG witness generation.

   Status: not implemented. The current code only parallelizes individual dot
   products with Rayon; it does not yet turn the product-proof batch into a
   batched finite-field matrix-style kernel.

6. Add GPU MSM support.

   Integrate a GPU cryptography backend such as ICICLE CUDA/Metal for MSM and,
   later, any NTT/polynomial operations needed by batching. This must be called
   directly from the proof backend; PyTorch, JAX, and Accelerate GEMM do not
   accelerate cryptographic MSM.

   Deliverable: backend selector `--msm-backend <cpu-blst|gpu-icicle>` and a
   benchmark that reports prover time versus float SGEMM for the same matrix
   shape.

   Status: not implemented. The new
   `scripts/benchmark_structured_matrix_vs_fast_gemm.py` benchmark shows the
   size of the remaining gap against local SGEMM.

7. Build a finite-field Transformer trace.

   Once the matrix proof backend is real and batched, connect it to a small
   quantized Transformer feed-forward trace, including lookup/range proofs for
   ReLU or other nonlinearities.

   Deliverable: end-to-end proof for a small transformer block with timing
   broken down by matrix proofs, nonlinear proofs, commitment time, proof
   generation, and verification.
