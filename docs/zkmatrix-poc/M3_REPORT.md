# M3 Report: One Quantized FFN Block End-to-End (Lattice Track)

Status: **implemented, tested, and measured** on the lattice Route Z
track (`lattice_matmul ffn-demo`); all components -- two Pi2 matmul
claims, the new bias-broadcast link, the M2 rescale/range family, the
ReLU family, two M1 transpose links, and the Class-0 residual -- are
proven under **one claim manifest**, with a seven-case negative battery.
The pairing-track twin stays deferred with the M2 pairing gadgets
(M2 report Section 5). Machine: Core Ultra 9 185H, 22 threads, 15 GB RAM;
another agent ran concurrently during measurement, so wall-clock numbers
are approximate (noted again in Section 4).

## 1. The statement (quantized spec, declared in the demo header)

Demo shape `T = 16, d = 32, f = 64` (1,024 rescaled/ReLU'd elements).
All values are signed integers encoded mod `q = 2^61 - 1` (negative `v`
as `q - |v|`); the fixed-point semantics are exact integer arithmetic:

```text
X:  T x d,   entries 4-bit signed  [-8, 8)
W1: d x f,   entries 4-bit signed
W2: f x d,   entries 4-bit signed
b1: f,       entries 6-bit signed  [-32, 32)

U   = X W1                      (accumulator bound d*2^6 + 2^5 < 2^12)
U_b = U + broadcast(b1)
U'  = floor(U_b / 2^6)          (remainder R in [0, 2^6), U' width-8 signed)
A   = relu(U')                  (A and D = A - U' width-8 unsigned)
Y   = A W2
out = Y + X                     (d_out = d; no second bias/rescale in M3 scope)
```

The width declarations are load-bearing: the accumulator-headroom check
`(d 2^{2(wx-1)} + 2^{wb-1}) / 2^shift < 2^{w-1}` is asserted by the demo,
and every range width is part of the manifest (inside every challenge).

## 2. Composition diagram (claim DAG under one manifest)

```text
 commitments (all inserted before ctx = H(manifest); labels = manifest entries)

 X(rows) --Pi2 matmul--> U(cols) --+                       X(cols)
    |                              | Class-0 Add              |
    |   b1(col) --bias link--> b1-bcast(cols)                 |
    |                              |                          |
    |                        U+b1 (derived)                   |
    |                              | rescale link (shift 6)   |
    |                     U'(cols) + R(cols)                  |
    |                     |  ranges: R-bits (unsigned, w=6)   |
    |                     |          U'-bits (signed,  w=8)   |
    |                     |  binary: R-bits, U'-bits          |
    |            b-sign(cols): binary                         |
    |            A(cols) = b o U'  (Hadamard)                 |
    |            ranges: A-bits (unsigned, w=8)               |
    |                    D = A - U' (derived), D-bits         |
    |                              |                          |
    |            A(rows) <--transpose link--> A(cols)         |
    |                A(rows) --Pi2 matmul--> Y(cols)          |
    |                              |                          |
    +--transpose link--> X(cols) --+-- Class-0 Add --> Out (derived)
```

Operations recorded in the manifest, in order: `Matmul`,
`BiasBroadcast`, `Add` (U+b1), `Rescale`, `Range` x2, `Binary` x2
(rescale family), `Binary` (sign bits), `Hadamard`, `Range` + `Binary`
(A), `Add` (A = D + U', defining D), `Range` + `Binary` (D),
`LinkTranspose` (A), `Matmul`, `LinkTranspose` (X), `Add` (Out).
20 commitment entries (2T + 11f + 3d + 1 = 833 column commitments in 17
freshly committed groups plus 3 derived groups). Every Fiat-Shamir
challenge of every claim binds `ctx`; the reordering negative (N7)
enforces this.

## 3. New links and their soundness notes

### 3.1 Bias-broadcast link (new in M3)

`b1` is committed once as a single column (length `f`) and once as `f`
broadcast columns `B_j = b1_j * ones_T`; the add itself is then Class-0
(`com(U_b,j) = com(U_j) + com(B_j)`). Consistency is ONE batched
scalar-link per repetition: draw `s in S_b^T`, `u in S_b^f`; the claim

```text
sum_j u_j <s, B_j>  =  sum(s) * <u, b1>
```

is linear on both sides. The left scalar comes from the `u`-combined
broadcast commitment under the derived key `g_s = s^T G2[..T]`, the
right from the bias commitment under `g_w = wv^T G2[..f]` with
`wv_j = sum(s) u_j` -- exactly the two-key Sigma shape of the M2
recomposition link. The prover shows knowledge of short
`(rho_l = sum_j u_j rho_Bj, rho_r = rho_b1)` opening both first slots
with `<g_s, rho_l> - <g_w, rho_r> = c_l - c_r`.

Soundness: given binding openings, the relation forces
`<s, sum_j u_j d_j> = 0` for the defect columns
`d_j = B_j - b1_j * ones`. A nonzero defect survives the fresh
`u`-combination with probability <= 2^-b (per-coordinate
Schwartz-Zippel) and the `s`-projection with probability <= 2^-b, so
<= 2^{1-b} per repetition -- the same per-repetition budget as the
transpose and recomposition links (r = 64, b = 6). The gadget is
2-special-sound per repetition; its extracted-relation norm is covered
by the conservative link folding already in `derive_params_gadget`
(bias center ~ 2^{2b} f sqrt(N), dominated by the folded
`2^{2b} max_cols (2 + 2^12) sqrt(N)`).

### 3.2 Derived-randomness bounds (recomposition and rescale links)

M3 range-proves values whose commitments are *derived* homomorphically
(`U_b = U + B`, `D = A - U'`), so the value-side randomness is a
sum/difference of two ternary blinds (entries in [-2, 2]). The
recomposition and rescale links now take an explicit randomness bound
(1 = fresh ternary, 2 = derived) that enters the statement hash and both
sides' Gaussian center / norm-bound derivation. For bound 1 the formulas
reproduce M2 bit-for-bit; bound 2 only widens the centers (still far
inside the folded beta, so the shared SIS parameter `k` is unchanged).

### 3.3 Signed ReLU from unsigned ranges (the "small argument")

Per element, the proven constraints are: `b in {0,1}` (binary claim),
`A = b o U'` (Hadamard, mod q), `A in [0, 2^w)` and
`D = A - U' in [0, 2^w)` (unsigned recomposition ranges; `com(D)` is
derived, costing no commitment), and `U' in [-2^{w-1}, 2^{w-1})` (the
signed range already proven by the rescale family). Then:

- `b = 1`: the Hadamard forces `A = U'` as field elements; `A`'s
  unsigned range intersected with `U'`'s signed encoding forces
  `U' >= 0` (the encodings `[0, 2^w)` and `(q - 2^{w-1}, q)` are
  disjoint since `2^w + 2^{w-1} << q`), so `A = U' = relu(U')`.
- `b = 0`: `A = 0`, and `D = -U' mod q in [0, 2^w)` forces `U' <= 0`,
  so `A = 0 = relu(U')`.

At `U' = 0` both branches are consistent and both give `A = 0`; the sign
bit is auxiliary, the proven relation is `A = relu(U')`. Completeness:
honest `A = max(U', 0) < 2^{w-1}` and `D = max(-U', 0) <= 2^{w-1}`, both
inside `[0, 2^w)`. Negative N2 (Section 5) demonstrates the division of
labor: a flipped sign bit still passes the Hadamard (by design) and is
caught by the D range.

### 3.4 Class-0 operations are verifier recomputations

`U_b`, `D`, and `Out` never receive fresh commitments or proofs: the
manifest records `Add` operations and the verifier recomputes
`com(U) + com(B)`, `com(A) - com(U')`, `com(Y) + com(X)` and rejects on
an entry-digest mismatch (measured at ~1 ms for all three; negative N6).
`D` is recorded as `Add { inputs: [D, U'], output: A }` -- the Class-0
identity `A = D + U'` defines `D` without a subtraction op kind.

## 4. Measurements

`lattice_matmul ffn-demo` (defaults: T=16, d=32, f=64, shift=6,
width=8; 1,024 rescaled/ReLU'd elements). Derived parameters:
`msg = 128, k = 1832, N = 6016` (identical `k` to the M1 chain demo --
the M2/M3 gadget folding does not move the SIS dimension at these
shapes). **Wall-clock caveat**: another agent (the Route R design
spike) ran concurrently on this machine, so treat all timings as
approximate (~±20%); the *ratios* are the stable result and match the
M2 per-element finding.

| component | prove (s) | verify (s) |
|---|---|---|
| CRS expansion | 0.03 | -- |
| commit (833 columns, 17 groups; 3 derived groups free) | 1.11 | -- |
| 2 Pi2 matmul claims (16x32x64, 16x64x32) | 1.69 | 0.48 |
| bias-broadcast link | 0.46 | 0.15 |
| rescale + range family (link, 2 recompositions, 128 packed binary columns) | 108.85 | 28.72 |
| ReLU family (sign binary, Hadamard, 2 recompositions, ranges on A and D: 256 columns) | 204.31 | 54.05 |
| 2 transpose links (A: 16x64, X: 16x32) | 0.97 | 0.31 |
| Class-0 recompute (U+b1, D, Out) | -- | 0.002 |
| **total** | **316.27** | **83.71** |

Headline comparison (the M3 exit measurement):

- **FFN-block prove vs its two matmul claims alone: 187.7x**
  (gadgets 314.6 s vs matmuls 1.69 s). The gadget families cost
  **307 ms per rescaled+ReLU'd element** -- the rescale family alone
  reproduces M2's ~108 ms/element within noise (108.8 s / 1,024
  elements = 106 ms), and the ReLU family adds ~2x that (two more
  packed-bit groups, the sign-bit binary and the Hadamard).
- Everything that is *not* a per-column Sigma gadget is negligible:
  the two matmul claims, the bias link, both transpose links, the
  Class-0 algebra and all commitments together are under 5 s prove /
  1 s verify -- about 1.5% of the block.
- End-to-end wall clock including the negative battery: 6 min 47 s.
  (The plan's ~5-minute demo guideline conflicts with the suggested
  shape at measured Route Z gadget costs; the suggested shape was kept
  and the runtime reported honestly. The test suite runs the same demo
  at T=4, d=8, f=8: prove 35.3 s, verify 9.1 s.)

This is the M2 finding composing exactly as predicted: on Route Z the
FFN block is **gadget-bound, not matmul-bound**, inverting the intended
cost profile (plan Section 2's asymptotics assume sane gadget
constants). The per-element cost is structural (per-column,
per-repetition one-time-pad masking with r = 64 and ~2.76 rejection
restarts); Route R (`r: 64 -> 1`, CRT-slot Hadamard) or the
pairing-track gadget family (~30 us/element MSMs, M2 Section 4) are the
levers, not kernel work.

## 5. Negative-test evidence

All seven cases run inside `ffn-demo` (release build) and must fail for
the demo to print `ok`; family-level negatives run at single-column
scale (the M2 pattern), manifest-level negatives at full scale:

| # | tamper | caught by | result |
|---|---|---|---|
| N1 | wrong ReLU output at one element (in-range value) | Hadamard claim | fails as required |
| N2 | sign bit flipped where U' != 0 (A recomputed honestly) | Hadamard **passes** (by design); D range recomposition | fails as required |
| N3 | one broadcast entry of b1 off by one | bias link | fails as required |
| N4 | wrong rescale quotient at one element | rescale link | fails as required |
| N5 | substituted A between orientations (second matmul re-proven, verifies standalone) | transpose link | fails as required |
| N6 | tampered residual output commitment | Class-0 recompute (digest mismatch) | fails as required |
| N7 | manifest reordering (same commitments, swapped entries) | every proof (ctx changes) | fails as required |

The self-test battery additionally covers the bias link
(valid/tampered/context-swap) and the signed recomposition convention
(valid/out-of-range) at unit scale.

## 6. Gaps toward M4

1. **Route Z gadget cost dominates exactly as the M2 finding predicted**
   (Section 4): the FFN block is gadget-bound, not matmul-bound. M4
   (attention/softmax) multiplies the elementwise work again; Route R
   remains the gate for Class 3 at scale, and the pairing-track gadget
   family (M2 Section 5) is the other lever. Neither is started.
2. **Input/weight ranges are declared, not proven.** The spec declares
   X/W1/W2/b1 widths and the demo asserts them, but no range proof binds
   the committed weights to the declared widths. For a chained
   multi-block statement the *previous* block's rescale+ranges bound the
   activations, but model weights would need one range family per weight
   matrix (or a declared-width commitment discipline) before M5's
   "committed quantized model" claim is fully self-contained.
3. **The exp/softmax primitive decision is still open** (the M4 research
   gate: lookup argument vs piecewise approximation).
4. **Verification is per-family**: each gadget family verifies its own
   repetitions; a chain verifier should run one blocked pass over all
   families (M0/M1 gap 4, still open), and the manifest still lacks
   batch-group declarations.
5. **The manifest does not yet carry the quantized spec as structured
   fields** (widths enter through the Range/Rescale operation
   parameters, which is sufficient for the FFN block, but a spec header
   with scale factors and nonlinearity table digests is needed at M4 for
   softmax).
6. **Memory discipline**: proofs are verified and dropped per family to
   cap peak memory (~0.7 GB per 64-column family at these parameters);
   an L-layer model needs streaming witnesses (plan risk 3).
