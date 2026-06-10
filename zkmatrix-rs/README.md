# zkmatrix-rs

Optimized native zkMatrix proof prototype.

This crate contains two zkMatrix implementations: the fast toy additive-field
backend used for scaling experiments, and a BLS12-381 structured-SRS backend
used for the cryptographic matrix proof prototype.

- Algorithm 4 core committed matrix multiplication proof.
- Optimized zero-knowledge masking inserted into the four Algorithm 4
  subprotocols.
- Dense exact finite-field matrix multiplication benchmark.
- A real BLS12-381 KZG opening benchmark for the Section 3 accelerated verifier
  primitive, using `blstrs`/`blst` Pippenger MSM.
- A BLS12-381 IPA benchmark with independent hash-to-curve Pedersen bases,
  which is the production-style commitment primitive but still has the ordinary
  linear verifier.
- A BLS12-381 structured matrix proof with Pedersen-hiding statement
  commitments, masked ZK subprotocols, Section 3 KZG verification for the four
  matrix IPAs, OS-backed proof randomness, and Algorithm 6-style same-shape ZK
  batching.
- Fused/specialized inner-product prover paths for the large projection proofs:
  no-`h` proofs skip zero-vector work, each round computes its dot products in
  one pass, and large folds run in parallel.

The BLS12-381 backend is now cryptographically meaningful for the single matrix
proof path, but it is not yet competitive with optimized float32 GEMM. Prover
time is dominated by curve MSM/KZG witness generation, so closing the remaining
gap requires a real fixed-base/GPU MSM backend and deeper batching.

## Build And Test

```bash
cargo build --release
./target/release/zkmatrix-rs self-test
./target/release/section3_kzg self-test
./target/release/curve_ipa self-test
./target/release/structured_matrix self-test
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

1. Add fixed-base/streaming MSM so the prover does not materialize avoidable
   projected bases.
2. Add a batched product-proof prover that processes the per-instance
   Algorithm 6 product proofs together.
3. Add a GPU MSM and finite-field batched-dot backend such as ICICLE CUDA/Metal
   and benchmark against local float SGEMM.
4. Extend Algorithm 6 batching across mixed transformer layer groups with
   shape-aware padding or separate per-shape batches.
5. Build the finite-field transformer trace around the matrix proof backend.

## Batched Product-Proof Dot Products

The current Algorithm 6 ZK batch path amortizes the three large length-`n^2`
projection proofs, but it still runs the `t` length-`n` product proofs one at a
time. Inside each product IPA, the prover repeatedly computes scalar-field dot
products such as:

```text
left_cross_i  = <a_i,left,  b_i,right>
right_cross_i = <a_i,right, b_i,left>
```

For a batch of `t` proofs, those are independent row-wise dot products over the
BLS12-381 scalar field. They are not ordinary floating-point SGEMM operations,
but they should be implemented with the same hardware shape: batched
finite-field reductions over contiguous rows, with shared proof-round control
flow. The implementation should:

1. Build a `prove_zk_products_batched` path that preserves Algorithm 6's
   per-instance product proofs but drives their rounds together.
2. Use shared round scheduling/challenges where the transcript allows it,
   matching the paper's performance-table assumption for concurrent
   Bulletproof protocols.
3. Store product witnesses as structure-of-arrays buffers so each round's
   `t` dot products become one batched row-wise finite-field kernel.
4. Fuse the fold updates for all `t` product proofs into the same pass over
   memory.
5. Batch or specialize the product-proof KZG witness generation; otherwise
   KZG opening MSMs may dominate after the scalar dot products are fused.
6. Move the batched scalar-field reductions and MSMs to a real GPU/fixed-base
   backend. PyTorch, JAX, Accelerate, and cuBLAS float GEMM cannot be used
   directly because proof arithmetic is exact finite-field arithmetic.

This optimization should reduce the marginal latency of large batches, but it
will not by itself close the gap to SGEMM. The remaining bottleneck is still
elliptic-curve MSM/KZG work unless the batched-dot path is paired with
fixed-base and GPU MSM support.

Structured matrix prototype:

```bash
python3 scripts/benchmark_structured_matrix.py --sizes 8 16 32
python3 scripts/benchmark_structured_matrix.py --mode both --sizes 32 64 128 256
python3 scripts/benchmark_structured_matrix.py --mode core --sizes 16 --batch 4
python3 scripts/benchmark_structured_matrix_vs_fast_gemm.py --mode zk --sizes 32 64 128 256
python3 scripts/benchmark_structured_matrix_batch_vs_gemm.py --mode zk --size 256 --batches 1 2 4 8 16 --matmul-backends accelerate
python3 scripts/analyze_structured_batch_scaling.py docs/zkmatrix-poc/results/structured_matrix_batch_vs_sgemm_zk_alg6_n256_2026-06-10.csv
```

Observed local results:

```text
mode,n,setup_s,commit_s,prove_s,verify_s,verified
zk,32,0.170818,0.001918,0.293942,0.008385,true
zk,64,0.643756,0.004458,0.459091,0.009510,true
zk,128,2.563599,0.013528,0.960094,0.011387,true
zk,256,10.222483,0.051182,2.811556,0.016299,true
zk,512,41.043448,0.197627,9.969060,0.035278,true

mode,n,fastest_float_backend,float_matmul_s,prove_s,proof_over_float_matmul
zk,32,accelerate-c,0.000000169795,0.291328,1715760.670
zk,64,accelerate-c,0.000000582406,0.498969,856737.252
zk,128,accelerate-c,0.000003570411,0.949906,266049.459
zk,256,accelerate-c,0.000021936037,2.863767,130550.779

n,batch,batch_prove_s,prove_per_claim_s,batch_verify_s,verify_per_claim_s
8,4,0.291753,0.072938,0.006460,0.001615
16,4,0.759240,0.189810,0.007278,0.001820

mode,n,batch,batch_prove_s,prove_per_claim_s,batch_verify_s,verify_per_claim_s
zk,256,1,2.824884,2.824884,0.011234,0.011234
zk,256,2,2.987392,1.493696,0.013769,0.006884
zk,256,4,3.289562,0.822391,0.018523,0.004631
zk,256,8,3.942427,0.492803,0.028457,0.003557
zk,256,16,5.203369,0.325211,0.047696,0.002981

mode,n,batch,batch_prove_s,prove_per_claim_s,batch_verify_s,verify_per_claim_s
zk,1024,1,38.650630,38.650630,0.012773,0.012773
zk,1024,2,39.896901,19.948450,0.015545,0.007773
zk,1024,4,42.111365,10.527841,0.020815,0.005204
zk,1024,8,47.056612,5.882076,0.031530,0.003941
zk,1024,16,56.089089,3.505568,0.054287,0.003393
```

The ZK batch path now follows the paper's Algorithm 6 shape: derive `y`, publish
per-instance `d`, `ay`, and `by` commitments, derive `rho`, run three aggregated
length-`n^2` projection proofs, and run one length-`n` product proof per matrix
multiplication. This gives the intended amortization of the large curve/MSM
subproofs. The remaining gap to SGEMM is dominated by CPU elliptic-curve work,
not by matrix multiplication.

The `setup_s` column constructs the local benchmark SRS and is not per-proof
runtime in a deployed system. The ZK path uses `/dev/urandom` rejection sampling
for proof masks and Pedersen blindings. The proof is still far slower than SGEMM
at these sizes because the prover is doing elliptic-curve MSMs and KZG openings
while SGEMM is using highly optimized dense floating-point kernels.

For `n=1024`, fitting the rows above gives approximately:

```text
prove_time(t) ~= 37.55s + 1.16s * t
projected t=1024: 1229s total, 1.20s per proof
```

The paper's Table 3 target for `t=1024` is `512.48s` total and `0.50s` per
proof. The current backend therefore has the right batching shape but still
misses the Table 3 marginal-cost target, mainly because product proofs are not
fused across the batch and the MSM/KZG backend is still CPU-only.
