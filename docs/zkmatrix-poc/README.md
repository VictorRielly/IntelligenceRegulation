# zkMatrix Proof-of-Concept Plan

This document records the proposed proof-of-concept path for proving correct
feed-forward execution of a small Transformer-like model using committed matrix
multiplication proofs.

## Goal

Build a proof of concept that demonstrates the following statement:

> Given a public model definition and committed/private input activations, the
> prover ran the specified model feed-forward correctly and obtained the claimed
> output, without revealing the private input content.

The target is not a full production LLM proof initially. The target is a small,
carefully designed Transformer-like model whose dominant operations can be
represented as matrix multiplication claims and whose nonlinearities are simple
enough to prove explicitly.

## Core Approach

The project should not try to encode a full Transformer feed-forward as one
literal dense matrix multiplication. A realistic feed-forward contains
nonlinearities and private-private products, especially inside attention.

The more accurate formulation is:

1. Represent all linear and bilinear tensor operations as a batch of matrix
   multiplication claims.
2. Commit to all private activations and intermediate matrices.
3. Prove the matrix multiplication claims with zkMatrix-style committed matrix
   multiplication proofs.
4. Prove nonlinear activation steps separately with lookup, range, or
   low-degree polynomial constraints.
5. Bind the whole trace with a transcript that includes the model identifier,
   layer shapes, quantization parameters, commitments, public output, and proof
   challenges.

The proof should certify the exact finite-field/fixed-point model used by the
POC. It should not attempt to certify unconstrained floating-point PyTorch
semantics.

## Current zkMatrix Assumption

The zkMatrix paper describes a zero-knowledge proof for multiplication of
committed matrices with:

- `O(n^2)` prover time and RAM for multiplying two `n x n` matrices.
- `O(log n)` transcript size.
- `O(log n)` verifier time.
- Batched mode where each additional matrix multiplication adds only `O(n)`
  group operations in prover time.

We have not yet confirmed a public production-ready zkMatrix library. The POC
should therefore begin with one of two paths:

1. Obtain implementation code from the zkMatrix authors.
2. Implement a minimal committed matrix multiplication proof from the paper,
   scoped only to the matrix shapes needed by the toy model.

If neither path is immediately available, use a finite-field Freivalds-style
checker as a non-ZK baseline while the committed proof layer is developed.

## POC Model

Start with the smallest model that still exercises the architecture:

- Sequence length: `8` or `16`.
- Hidden dimension: `16` or `32`.
- Attention heads: `1`.
- Layers: `1`, then `2`.
- Dropout: none.
- Layer norm: omit initially.
- MLP nonlinearity: ReLU.
- Attention: use linear or polynomial attention for the first POC.

Avoid standard softmax attention in the first version. Standard attention
requires exponentials, row-wise normalization, and division. Those can be
handled later with lookup or polynomial/rational approximations, but they should
not block the first end-to-end proof.

An initial attention block can use:

```text
Q = X Wq
K = X Wk
V = X Wv
Qp = phi(Q)
Kp = phi(K)
S = Qp Kp^T
O = S V
```

where `phi` is a simple proven basis transform such as identity, ReLU, square,
or a small lookup-backed polynomial feature map.

## Computation Trace

Every important intermediate tensor should be represented as a named committed
matrix. For example:

```text
X       input token embeddings / input activations
Q       query activations
K       key activations
V       value activations
Qp      basis-expanded query activations
Kp      basis-expanded key activations
S       attention scores or kernel matrix
O       attention output
Hpre    feed-forward pre-activation
H       feed-forward activation
Y       final output logits or activations
```

The trace should produce matrix multiplication claims such as:

```text
Q    = X Wq
K    = X Wk
V    = X Wv
S    = Qp Kp^T
O    = S V
Hpre = O W1
Y    = H W2
```

Public model weights may be treated as public matrices. Private inputs and
intermediate activations should be committed.

## Batched Matrix Multiplication Proof

All matrix multiplication claims should be batched into a single proof where
possible.

One engineering approach is to build block-diagonal matrices:

```text
blockdiag(A1, A2, ..., Am) * blockdiag(B1, B2, ..., Bm)
=
blockdiag(C1, C2, ..., Cm)
```

This allows one batched committed matrix multiplication argument to cover many
layer equations. Shape padding will be needed, and the benchmark should account
for the padding overhead.

The POC should first implement batching for same-shape claims, then extend to
mixed-shape claims.

## Nonlinear Proofs

Nonlinearities cannot be accepted as arbitrary witness matrices. The prover
must prove each nonlinear output was derived correctly from its input.

### ReLU

For the first POC, use bounded integer activations and a lookup table:

```text
y = max(0, x)
```

over a small signed range such as `[-128, 127]` or `[-32768, 32767]`, depending
on the quantization scale.

Later versions can replace this with range/sign constraints.

### Polynomial Basis Values

If using basis expansion for attention, every basis column must be constrained.
For example:

```text
phi(x) = [1, x, x^2]
```

requires explicit constraints that the third component equals `x * x`.
For small ranges, lookup tables may be faster and simpler.

### Softmax

Softmax should be a later milestone. If included, define the proof target as an
approximated fixed-point softmax, not floating-point PyTorch softmax.

Viable options:

1. Table lookup for `exp(x)` over a bounded input range.
2. Polynomial approximation for `exp(x)`.
3. Rational approximation with explicit inverse/normalization constraints.
4. Replace softmax with linear attention for the first product milestone.

## Fixed-Point And Field Semantics

The POC needs a precise arithmetic contract:

- Choose a field.
- Choose signed integer encoding.
- Choose activation and weight scales.
- Define rounding behavior.
- Define overflow bounds.
- Define clipping behavior, if any.

Candidate fields:

- BN254 scalar field if compatibility with Halo2/KZG/EVM verification is a
  priority.
- Goldilocks, BabyBear, or similar STARK-friendly fields if prover speed is the
  priority.

The proof certifies the quantized finite-field model. Accuracy against the
floating-point model is a separate validation task.

## GPU Considerations

Native neural inference benefits from tensor-core GEMM. ZK proof generation
uses different kernels: finite-field arithmetic, commitments, MSM, NTT,
hashing, and transcript operations.

The POC should assume GPU acceleration is possible but not automatic.
Cryptographic GPU libraries such as ICICLE support CUDA and Metal backends for
many relevant primitives. However, a zkMatrix implementation will need to
actually call those primitives or provide equivalent GPU kernels.

Benchmarks must distinguish:

1. PyTorch floating-point inference time.
2. Quantized finite-field inference time.
3. Matrix proof generation time on CPU.
4. Matrix proof generation time on GPU, if available.
5. Nonlinear proof overhead.
6. Proof verification time.

The project is only practically compelling if proof generation is a modest
multiple of quantized inference for the target workload.

## Milestones

### Milestone 1: Finite-Field Matmul Baseline

- Implement exact finite-field matrix multiplication.
- Implement a finite-field Freivalds checker.
- Benchmark against the existing floating-point GPU benchmark.
- Support rectangular Transformer-like shapes, not only square matrices.

Deliverable: benchmark report for plain matmul and Freivalds verification.

### Milestone 2: Toy Trace Without ZK

- Implement the toy Transformer-like model in finite-field arithmetic.
- Emit a full computation trace.
- Verify every matrix equation with finite-field Freivalds checks.
- Verify ReLU or basis expansion with direct checks.

Deliverable: a deterministic trace verifier for one tiny model/input pair.

### Milestone 3: Commitments

- Add commitments for private input and intermediate matrices.
- Bind commitments, public model metadata, and output into a transcript.
- Keep verification non-ZK initially if needed.

Deliverable: committed trace format and transcript hash.

### Milestone 4: Single Committed Matmul Proof

- Implement or integrate a zkMatrix-style proof for one committed matrix
  multiplication.
- Support one shape used by the toy model.
- Validate soundness with injected faulty witnesses.

Deliverable: one proven committed matrix multiplication claim.

### Milestone 5: Batched Matrix Claims

- Batch all linear claims in the toy model.
- Add mixed-shape padding or a shape-aware batching strategy.
- Benchmark prover and verifier scaling as layers/sequence length increase.

Deliverable: one proof covering all matrix multiplication claims.

### Milestone 6: Nonlinear Proofs

- Add ReLU lookup/range proof.
- Add basis expansion proof for attention.
- Bind nonlinear proof outputs to the committed trace.

Deliverable: end-to-end proof for a model with attention-like bilinear mixing
and an MLP ReLU.

### Milestone 7: Softmax Or Production Attention

- Decide whether to add approximated softmax or keep a ZK-native attention
  variant.
- If softmax is added, prove the approximation with lookup or polynomial
  constraints.
- Measure accuracy and proof overhead.

Deliverable: documented choice of attention mechanism for the first public POC.

### Milestone 8: Content Governance Integration

- Connect the proof to the existing content-filtering pipeline.
- Commit to tokenized private input.
- Produce public safe/unsafe output.
- Optionally bind encrypted message plaintext to the same input commitment via
  the AES/Poseidon plan described in the framework document.

Deliverable: proof bundle for private content moderation on a toy model.

## Initial Repository Work Items

1. Add a finite-field arithmetic module. Status: initial implementation in
   `zk_matrix/`.
2. Add a rectangular matrix benchmark. Status: square benchmark in
   `scripts/benchmark_zkmatrix.py`; rectangular shapes are supported by the
   protocol code and should be added to the benchmark.
3. Add a toy Transformer trace generator.
4. Add a trace verifier using exact checks.
5. Research or obtain zkMatrix implementation code. Status: no public author
   implementation has been integrated; the local prototype follows the paper.
6. Decide the initial commitment scheme and field. Status: prototype uses
   Pedersen-style commitments over dependency-free cyclic group backends.
7. Add benchmark scripts that report inference, trace generation, proof
   generation, and verification separately. Status: matrix multiplication,
   commitment, proof, and verification are reported separately.

## Current Prototype

The repository now contains `zk_matrix/`, a dependency-free implementation of
the zkMatrix proof structure from the paper:

- `prove_core_matmul` implements Algorithm 4's committed matrix multiplication
  reduction.
- `prove_zk_matmul` implements the optimized zero-knowledge placement described
  after Algorithm 5 by adding masks inside the four Algorithm 4 subprotocols.
- `prove_naive_zk_matmul` keeps the direct Algorithm 5 whole-matrix masking
  wrapper for comparison; this path materializes the mask cross-products and
  therefore has the paper's noted `O(n^3)` overhead.

Run:

```bash
python3 -m unittest tests/test_zkmatrix_protocol.py
python3 scripts/benchmark_zkmatrix.py --backend toy --sizes 2 4 8 16 32 64 128 256
python3 scripts/benchmark_zkmatrix.py --backend small-subgroup --sizes 2 4 8
```

The pure-Python implementation does not reproduce the paper's accelerated
pairing verifier or Rust/BLS12-381 performance estimates. It reproduces the
protocol algebra and scaling structure, then leaves the group backend boundary
available for a Rust/arkworks or GPU MSM backend.

## Native Backend

The repository also contains `zkmatrix-rs/`, an optimized Rust implementation
of the same toy-field protocol. It is the first backend fast enough to show the
expected crossover against dense exact finite-field multiplication:

```bash
python3 scripts/benchmark_zkmatrix_rust.py --mode both --sizes 2048 3072 4096
```

Observed local results:

```text
core 2048: proof/exact-matmul = 1.085
core 3072: proof/exact-matmul = 0.932
core 4096: proof/exact-matmul = 0.526

zk   2048: proof/exact-matmul = 1.474
zk   3072: proof/exact-matmul = 1.186
zk   4096: proof/exact-matmul = 0.616
```

This is still not a production cryptographic implementation. It proves that the
protocol structure can cross dense exact field multiplication once Python object
overhead is removed. The next implementation milestone is a real curve/MSM
backend and the Section 3 accelerated pairing verifier.

## Main Risks

- No usable public zkMatrix implementation exists.
- Cryptographic GPU kernels are not integrated with the chosen proof system.
- Fixed-point quantization changes model behavior too much.
- Softmax proof overhead dominates the matrix proof savings.
- Matrix batching loses too much efficiency due to padding and mixed shapes.
- Matrix-vector decode workloads do not benefit as much as batched
  matrix-matrix workloads.

## Success Criteria

The POC should be considered successful if it demonstrates:

1. A complete finite-field model trace.
2. Committed private inputs and intermediate activations.
3. A proof that the dominant matrix multiplications were correct.
4. A proof or explicit verifier for nonlinear steps.
5. Public output suitable for a governance decision.
6. Benchmarks showing the proof overhead relative to quantized inference.

The strongest success outcome is proof generation within a small constant
factor of quantized inference for a batched Transformer-like workload.
