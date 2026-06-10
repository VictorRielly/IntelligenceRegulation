# zkmatrix-rs

Optimized native zkMatrix proof prototype.

This crate implements the same protocol shape as the Python `zk_matrix`
prototype over the same toy prime-order additive field backend:

- Algorithm 4 core committed matrix multiplication proof.
- Optimized zero-knowledge masking inserted into the four Algorithm 4
  subprotocols.
- Dense exact finite-field matrix multiplication benchmark.

It is intentionally not the final cryptographic backend. The next performance
step is replacing the toy additive backend with a real curve/MSM backend and
then implementing the Section 3 accelerated pairing verifier.

## Build And Test

```bash
cargo build --release
./target/release/zkmatrix-rs self-test
python3 -m unittest tests/test_zkmatrix_native_backends.py
```

## Benchmarks

```bash
python3 scripts/benchmark_zkmatrix_rust.py --mode both --sizes 2048 3072 4096
```

Observed on the local Apple Silicon machine:

```text
core 2048: proof/exact-matmul = 1.085
core 3072: proof/exact-matmul = 0.932
core 4096: proof/exact-matmul = 0.526

zk   2048: proof/exact-matmul = 1.474
zk   3072: proof/exact-matmul = 1.186
zk   4096: proof/exact-matmul = 0.616
```

These ratios compare against dense exact finite-field multiplication, not
float32 tensor-core GEMM.
