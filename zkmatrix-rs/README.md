# zkmatrix-rs

Optimized native zkMatrix proof prototype.

This crate implements the same protocol shape as the Python `zk_matrix`
prototype over the same toy prime-order additive field backend:

- Algorithm 4 core committed matrix multiplication proof.
- Optimized zero-knowledge masking inserted into the four Algorithm 4
  subprotocols.
- Dense exact finite-field matrix multiplication benchmark.
- A real BLS12-381 KZG opening benchmark for the Section 3 accelerated verifier
  primitive, using `blstrs`/`blst` Pippenger MSM.
- A BLS12-381 IPA benchmark with independent hash-to-curve Pedersen bases,
  which is the production-style commitment primitive but still has the ordinary
  linear verifier.
- Fused/specialized inner-product prover paths for the large projection proofs:
  no-`h` proofs skip zero-vector work, each round computes its dot products in
  one pass, and large folds run in parallel.

The matrix proof itself is still intentionally not the final cryptographic
backend. The Section 3 binary proves and benchmarks the pairing/KZG primitive
that replaces a verifier MSM, but it is not yet wired into all four zkMatrix
subprotocols.

## Build And Test

```bash
cargo build --release
./target/release/zkmatrix-rs self-test
./target/release/section3_kzg self-test
./target/release/curve_ipa self-test
python3 -m unittest tests/test_zkmatrix_native_backends.py
```

## Benchmarks

Matrix proof over the toy additive backend:

```bash
python3 scripts/benchmark_zkmatrix_rust.py --mode both --sizes 2048 3072 4096
```

Observed on the local Apple Silicon machine after the fused projection-proof
optimization:

```text
core 2048: prove = 0.187 s, proof/exact-matmul = 0.372
core 4096: prove = 0.496 s, proof/exact-matmul = 0.125
core 6144: prove = 1.043 s, proof/exact-matmul = 0.078
core 8192: prove = 1.640 s, proof/exact-matmul = 0.052

zk   2048: prove = 0.244 s, proof/exact-matmul = 0.487
zk   4096: prove = 0.631 s, proof/exact-matmul = 0.159
zk   6144: prove = 1.294 s, proof/exact-matmul = 0.096
zk   8192: prove = 2.082 s, proof/exact-matmul = 0.066
```

These ratios compare against dense exact finite-field multiplication, not
float32 tensor-core GEMM.

Section 3 KZG verifier primitive:

```bash
python3 scripts/benchmark_section3_kzg.py --degrees 1024 4096 16384 65536 262144
```

Observed on the same local CPU:

```text
degree,coefficients,direct_verifier_msm_s,accelerated_verify_s
1024,1025,0.000955459,0.000757542
4096,4097,0.001525792,0.000689375
16384,16385,0.005013083,0.000686208
65536,65537,0.019446041,0.000703833
262144,262145,0.075566666,0.000708042
1048576,1048577,0.301262375,0.000703541
```

This confirms the Section 3 shape: verifier time becomes effectively constant,
while the MSM moves to the prover. Competing with floating-point GEMM therefore
still depends on batching and a real GPU MSM backend such as ICICLE CUDA/Metal.

Production-curve IPA primitive:

```bash
python3 scripts/benchmark_curve_ipa.py --lengths 1024 4096 16384 65536 262144
python3 scripts/benchmark_curve_ipa.py --structured --lengths 1024 4096 16384 65536 262144
```

Observed with independent BLS12-381 hash-to-curve bases:

```text
len,setup_s,commit_s,prove_s,verify_s
1024,0.102363,0.001408,0.140858,0.108560
4096,0.295177,0.003108,0.470504,0.430533
16384,1.180944,0.010405,1.779581,1.715264
65536,4.722018,0.038933,6.992621,6.849216
262144,18.879730,0.154350,27.926828,27.432946
```

This is why the matrix verifier is still slow: the ordinary IPA verifier folds
all bases and is linear in the committed vector length. The paper's logarithmic
verifier requires the Section 3 structured SRS/KZG verification path, not
independent hash-to-curve Pedersen bases.

Structured Section 3 verifier results:

```text
len,prove_with_kzg_open_s,direct_verify_s,fast_verify_s
1024,0.151441,0.111863,0.002034
4096,0.500831,0.430192,0.002197
16384,1.906602,1.811845,0.002785
65536,7.228505,6.848037,0.002676
262144,28.756263,28.142888,0.003009
```

This integrates the Section 3 KZG check at the IPA layer. Lifting it into the
full matrix proof still requires replacing the projected matrix bases with
structured-SRS polynomial formulas, but the verifier bottleneck is resolved for
the primitive itself.

## Next Steps

1. Derive structured-SRS polynomial formulas for the full matrix proof's
   projected `C`, `A`, and `B` bases.
2. Wire the full matrix proof to BLS12-381 structured commitments while keeping
   the toy backend for fast regression tests.
3. Implement Algorithm 6 same-shape batching for repeated transformer matrix
   multiplication claims.
4. Add fixed-base/streaming MSM so the prover does not materialize avoidable
   projected bases.
5. Add a GPU MSM backend such as ICICLE CUDA/Metal and benchmark against local
   float SGEMM.
