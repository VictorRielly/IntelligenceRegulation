# zkMatrix Optimization Roadmap

This note captures the remaining work needed to test and approach the zkMatrix
paper's Table 3 claim for `1,024 x 1,024` matrix multiplications.

## Table 3 Target

The paper estimates the following BLS12-381 performance:

```text
single proof:             197.04s prover, 176 MB RAM
batch of 1024 proofs:     512.48s prover total, 304 MB RAM total
amortized batched proof:    0.50s prover
```

The important claim is the batched marginal cost: amortized proving time drops
from about `200s` per multiplication to about `0.5s` per multiplication when
`1024` same-shape multiplications are proved together.

## Current Local Result

The current Algorithm 6-shaped ZK batch prover has been measured for
`n=1024` and `t in {1, 2, 4, 8, 16}`:

```text
prove_time(t) ~= 37.55s + 1.16s * t
projected t=1024: 1229s total, 1.20s per proof
```

Raw results:

```text
docs/zkmatrix-poc/results/structured_matrix_batch_vs_sgemm_zk_alg6_n1024_2026-06-10.csv
docs/zkmatrix-poc/results/structured_matrix_batch_vs_sgemm_zk_alg6_n1024_scaling_2026-06-10.txt
```

This confirms that batching is amortizing the fixed projection-proof cost, but
the current backend is still about `2.4x` slower than the paper's batched
prover estimate. It also has no crossing point against local float SGEMM,
because the marginal proof cost remains much larger than the marginal matrix
multiplication cost.

## Current Memory Mismatch

The current benchmark harness stores every dense witness matrix for every batch
item:

```text
3 * t * n^2 field elements for A, B, and C
```

For `n=1024` and `t=1024`, this is roughly `96 GB` before proof buffers and SRS
state. Table 3's `304 MB` RAM estimate assumes a streaming or aggregating
prover. Therefore, the current benchmark can fit small-batch timing trends but
cannot validate Table 3's memory claim.

## Required Optimizations

1. Streaming Table 3 benchmark

   Store deterministic witness seeds, statements, commitments, and compact
   intermediate values instead of retaining every dense witness. Use passes:
   commit inputs, derive `y`, compute `d_i`, `ay_i`, `by_i`, derive `rho`, then
   aggregate the large `A`, `B`, and `C` witnesses into one length-`n^2` buffer.

2. Batched product-proof prover

   Algorithm 6 still requires one length-`n` product proof per multiplication.
   The current code runs those proofs independently. Add
   `prove_zk_products_batched` so product proofs share round scheduling and
   execute same-round scalar-field dot products and folds as batched row-wise
   kernels.

3. Batched finite-field dot backend

   The dot products are over the BLS12-381 scalar field, not floating point.
   Ordinary SGEMM/cuBLAS/PyTorch/JAX cannot be used directly. Implement a
   CPU-vectorized and GPU-ready exact finite-field batched reduction backend.

4. Fixed-base and streaming MSM

   The prover remains dominated by elliptic-curve MSM and KZG witness
   generation. Add reusable fixed-base precomputation for SRS windows and avoid
   materializing projected bases when a streaming polynomial/MSM formula is
   available.

5. GPU MSM backend

   Integrate a real cryptographic GPU MSM backend, such as ICICLE CUDA or a
   Metal-compatible equivalent for Apple Silicon. This is separate from float
   matrix multiplication acceleration.

6. Compact SRS representation

   The local benchmark constructs and stores SRS powers directly. A Table
   3-style benchmark needs compact setup/loading and careful accounting so SRS
   construction is not confused with per-proof RAM or runtime.

## Acceptance Tests

The next optimization pass should produce:

```text
benchmark: n=1024, t up to 1024, streaming memory mode
reported: setup time, commit time, prove time, verify time, peak RSS
fit: fixed prover cost, marginal prover cost, projected t=1024 cost
target: total prove time near 512.48s and peak RAM near 304 MB
```

Until the streaming benchmark exists, do not interpret a failed `t=1024`
current-harness run as a contradiction of the paper. It would mostly measure
our witness-storage strategy, not the optimized zkMatrix prover model.
