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

## Repository Layout

```text
zk_matrix/                         Pure-Python reference implementation
zk_matrix/README.md                Python reference usage and caveats
zkmatrix-rs/                       Optimized Rust implementation
zkmatrix-rs/README.md              Rust backend usage and benchmark notes
zk_matrix_fast/                    C reference backend used during optimization
scripts/benchmark_zkmatrix.py      Python proof benchmark
scripts/benchmark_zkmatrix_rust.py Rust proof benchmark wrapper
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
matrix multiplication over the same toy field. Recent local results:

```text
core 2048: proof/exact-matmul ~= 1.07
core 3072: proof/exact-matmul ~= 0.93
core 4096: proof/exact-matmul ~= 0.53

zk   2048: proof/exact-matmul ~= 1.46
zk   3072: proof/exact-matmul ~= 1.19
zk   4096: proof/exact-matmul ~= 0.62
```

So the optimized Rust proof crosses dense exact finite-field multiplication by
`4096 x 4096` on the local Apple Silicon machine.

## Important Limits

This is still a proof-of-concept, not production cryptography.

- The Rust backend uses the toy additive field backend for speed experiments.
- The Section 3 accelerated pairing verifier from the paper is not implemented.
- The backend does not yet use a real elliptic curve, GPU MSM, or fixed-base
  precomputation.
- The benchmark crossover is against exact finite-field multiplication, not
  float32 tensor-core or Apple Accelerate GEMM.

## Next Engineering Steps

1. Replace the toy additive backend with a real curve backend such as
   `blstrs`, `ark-bls12-381`, or another pairing-friendly curve library.
2. Implement fixed-base MSM and parallel MSM paths.
3. Add the paper's Section 3 accelerated verifier using structured bases and
   pairings.
4. Add Algorithm 6 batching so many model-layer matrix multiplications share
   transcript challenges and proof work.
5. Add GPU support through an MSM library such as ICICLE or a Metal/CUDA backend.
6. Integrate the proof backend into a finite-field Transformer trace.
