# zkMatrix Implementation Guide

This directory documents the current zkMatrix proof-of-concept implementation.
The goal is to reproduce the zkMatrix paper's matrix multiplication proof
structure and benchmark when proof generation becomes comparable to dense
matrix multiplication.

Reference paper:

- `docs/zkmatrix-poc/references/zkMatrix-eprint-2024-161.pdf`
- https://eprint.iacr.org/2024/161.pdf

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

## Repository Layout

```text
zk_matrix/                         Pure-Python reference implementation
zk_matrix/README.md                Python reference usage and caveats
zkmatrix-rs/                       Optimized Rust implementation
zkmatrix-rs/README.md              Rust backend usage and benchmark notes
zk_matrix_fast/                    C reference backend used during optimization
scripts/benchmark_zkmatrix.py      Python proof benchmark
scripts/benchmark_zkmatrix_rust.py Rust proof benchmark wrapper
scripts/benchmark_section3_kzg.py  Section 3 KZG verifier benchmark wrapper
scripts/benchmark_curve_ipa.py     BLS12-381 hash-to-curve IPA benchmark wrapper
scripts/benchmark_zkmatrix_vs_fast_gemm.py
                                   Compares proof timing to local GEMM backends
tests/test_zkmatrix_protocol.py    Python protocol correctness tests
tests/test_zkmatrix_native_backends.py
                                   Rust accept/reject checks against Python behavior
```

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

The Section 3 KZG check is now integrated at the IPA layer. The remaining
matrix-proof integration work is to express the `C`, `A`, and `B` projected
bases as structured-SRS polynomials instead of materialized arbitrary bases.

## Important Limits

This is still a proof-of-concept, not production cryptography.

- The Rust backend uses the toy additive field backend for speed experiments.
- The Section 3 accelerated pairing primitive is implemented as a standalone
  KZG benchmark, but it is not yet integrated into the full matrix proof
  verifier.
- Production BLS12-381 hash-to-curve commitments are implemented for the IPA
  primitive, but the full matrix proof backend still uses the toy additive field
  for large-scale experiments.
- The full matrix proof backend does not yet use GPU MSM or fixed-base
  precomputation.
- The benchmark crossover is against exact finite-field multiplication, not
  float32 tensor-core or Apple Accelerate GEMM.

## Next Engineering Steps

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

   Deliverable: a small structured matrix verifier for `n <= 64` that matches
   the toy verifier and uses the KZG verifier path for all four IPAs.

2. Replace the toy matrix commitment layer with BLS12-381 structured bases.

   The `curve_ipa` binary proves the production-curve IPA primitive works, but
   the full matrix proof still uses `u64` additive commitments. After Step 1,
   wire the full `prove_zk` and `verify_zk` matrix flow to structured
   BLS12-381 commitments.

   Deliverable: correctness tests for small committed matrix multiplication
   over the real curve backend, with the old toy backend retained for fast
   regression and large-shape experiments.

3. Add Algorithm 6 same-shape batching.

   Same-shape batching should combine many layer/head matrix multiplication
   claims that share dimensions. For a transformer workload, this should batch
   repeated MLP, Q/K/V/O, and attention score/value multiplications whenever
   shapes align.

   Deliverable: `bench-batch <mode> <n> <batch_count>` that reports total
   proof time, marginal proof time, proof size, and verifier time per matrix
   multiplication.

4. Add fixed-base and streaming MSM for prover commitments/openings.

   The prover bottleneck after Section 3 is MSM, not verification. Use cached
   fixed-base precomputation for reusable SRS bases, avoid materializing
   projected bases when a streaming polynomial/MSM formula is available, and
   benchmark memory bandwidth separately from scalar multiplication.

   Deliverable: CPU benchmarks comparing `blst` Pippenger, fixed-base
   precomputation, and streaming structured-basis MSM for IPA lengths from
   `2^20` through `2^28`.

5. Add GPU MSM support.

   Integrate a GPU cryptography backend such as ICICLE CUDA/Metal for MSM and,
   later, any NTT/polynomial operations needed by batching. This must be called
   directly from the proof backend; PyTorch, JAX, and Accelerate GEMM do not
   accelerate cryptographic MSM.

   Deliverable: backend selector `--msm-backend <cpu-blst|gpu-icicle>` and a
   benchmark that reports prover time versus float SGEMM for the same matrix
   shape.

6. Build a finite-field Transformer trace.

   Once the matrix proof backend is real and batched, connect it to a small
   quantized Transformer feed-forward trace, including lookup/range proofs for
   ReLU or other nonlinearities.

   Deliverable: end-to-end proof for a small transformer block with timing
   broken down by matrix proofs, nonlinear proofs, commitment time, proof
   generation, and verification.
