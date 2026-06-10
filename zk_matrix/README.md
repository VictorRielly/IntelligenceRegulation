# zkMatrix Prototype

This package implements a local proof-of-concept for the zkMatrix paper,
`zkMatrix: Batched Short Proof for Committed Matrix Multiplication`
(`ePrint 2024/161`).

## What Is Implemented

- Pedersen-style vector commitments over a cyclic group interface.
- A recursive Bulletproof-style inner-product argument.
- Algorithm 4, `MatMul`, reducing `C = A B` to four committed
  inner-product statements:
  - `d = <flatten(C), y>`
  - `a_y = y_L A`
  - `b_y = B y_R`
  - `d = <a_y, b_y>`
- The paper's optimized zero-knowledge placement described after Algorithm 5:
  masks are inserted inside the four Algorithm 4 subprotocols, avoiding the
  direct Algorithm 5 whole-matrix masking cost of `O(n^3)`.
- A direct Algorithm 5 wrapper is kept as `prove_naive_zk_matmul` for comparison.

## What Is Not Implemented Yet

- The Section 3 accelerated pairing verifier with a structured reference string.
  Verification currently uses the ordinary recursive inner-product verifier.
- Batched zkMatrix from Algorithm 6.
- A production elliptic-curve or GPU backend. The provided backends are:
  - `toy`: fast additive field group for scaling experiments only.
  - `small-subgroup`: small safe-prime subgroup for a closer DLOG-shaped model.
  - `rfc3526-2048`: 2048-bit MODP subgroup, still pure Python and slow.

## Run Tests

```bash
python3 -m unittest tests/test_zkmatrix_protocol.py
```

## Run Benchmarks

```bash
python3 scripts/benchmark_zkmatrix.py --backend toy --sizes 2 4 8 16 32 64 128 256
python3 scripts/benchmark_zkmatrix.py --backend small-subgroup --sizes 2 4 8
python3 scripts/benchmark_zkmatrix.py --backend toy --mode naive-zk --sizes 8 16 32
```

The benchmark reports finite-field matrix multiplication time, commitment time,
proof generation time, verification time, and `proof_over_matmul`.

## Interpreting Runtime

The `toy` backend is useful for checking the paper's asymptotic shape:
matrix multiplication is cubic, while the proof work in the optimized ZK path is
quadratic up to logarithmic inner-product folding overhead. On this machine, the
toy backend crosses below raw Python multiplication around `256 x 256`.

The cryptographic backends are not competitive in pure Python because modular
exponentiation dominates. The paper's practical estimates depend on optimized
fixed-base multi-exponentiation, parallelism, and the pairing-based verifier.
