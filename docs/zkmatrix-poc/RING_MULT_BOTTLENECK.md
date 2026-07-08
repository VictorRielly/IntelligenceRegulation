# The Ring-Multiplication Bottleneck

Status: **the current top bottleneck in total proof computation**, identified
by the Route R design spike (ROUTE_R_DESIGN.md, finding 3) and now the
primary optimization target. This document explains it from first
principles, quantifies its impact, and lays out the full solution space —
the approved Q2/Q3 workstreams plus the creative alternatives worth
trying. Companion explanation in plain language: see the project
conversation summary; technical grounding: ROUTE_R_DESIGN.md Sections 1-3.

## 1. The finding, in one paragraph

Route R packs 128 numbers into one polynomial ("ring element") so that a
single giant challenge replaces 64 protocol repetitions. That works and is
prototype-verified. But multiplying two ring elements the schoolbook way
costs 128 x 128 = 16,384 small multiplications — the packing gains nothing
on multiplication cost by itself. The standard rescue is the NTT (the
FFT's modular cousin: convert to "frequency form," multiply pointwise,
convert back), which needs the modulus q to contain enough roots of unity
— and that requires the polynomial X^128 + 1 to split into many factors
mod q. Our soundness argument, however, *needs it to split into few
factors*: the knowledge extractor divides by challenge differences, and
the Lyubashevsky-Seiler invertibility guarantee (nonzero elements with
coefficients below ~q^(1/k) are invertible when the ring splits k ways)
collapses as k grows. The spike chose the maximally safe k = 2
(q = 5 mod 8), where ring multiplication is only ~2x cheaper than naive —
so the commitment bill, the dominant LLM-scale cost, shrinks ~2-3x under
Route R instead of the ~15x the estimate had assumed.

Is "we need more compute than expected" the right reading? Yes, at the
safe baseline: the *operation count* of the prover is higher than the
estimate assumed, so at fixed hardware the wall-clock is longer (2-4 min
per 7B/512 pass instead of continuing toward 15 s), or equivalently the
15 s target needs more hardware than assumed. The refinement: most of the
assumed efficiency is *recoverable* — the loss is not fundamental to the
protocol, it is a property of one conservative parameter choice (k = 2),
and the table below shows the recovery paths. Soundness is unaffected
throughout; this is purely an arithmetic-cost correction.

## 2. Quantified impact

Cost of one ring multiplication (d = 128), small multiplications:

| method | mults | vs naive | soundness interaction |
|---|---|---|---|
| naive schoolbook | 16,384 | 1x | none |
| k = 2 split (current design) | 2 x 64^2 = 8,192 | 2x | none (LS18 margin ~8000x) |
| k = 8 split (**Q3**) | 8 x 16^2 = 2,048 | 8x | LS18 margin ~4x at q46, 1.30x at q31 — verified viable (Section 6.1) |
| full NTT (k = 128) | ~d log d ~ 900 | ~18x | **breaks LS18 for short challenges — not available directly** |
| auxiliary-modulus NTT (**A1**, below) | ~pointwise + amortized transforms | approaches full-NTT rates for GEMM-shaped work | **none — evaluation strategy only** |

Where it lands in the totals (7B/512-token pass, this machine's measured
kernel rates): commitments are ~80-90% of the Route R prover bill; at
k = 2 they improve only 2-3x over Route Z, keeping the pass at ~2-4 min.
Recovering ~8x (Q3) or more (A1) on ring multiplication moves the
commitment bill roughly proportionally; combined with Q2's hardware-density
gains and GPU kernels, the ladder to ~15 s closes.

## 3. Approved workstreams

### Q3 — the k = 8 split (approved; DONE, see Section 6)

Split X^128 + 1 into 8 factors of degree 16 (needs q = 17 mod 32-type
conditions; parameter script to confirm exact residue class). LS18
invertibility threshold ~q^(1/8)/sqrt(8): at q ~ 2^46 that is ~19-24,
comfortably above the quinary challenge-difference bound of 4; at
q ~ 2^31 (post-Q2) it is ~10-13 *(superseded — the exact bound at 2^31
is 5.19, margin 1.30x; see Section 6)*, still above 4 but with the
margin to be re-verified jointly with Q2 (this Q2/Q3 coupling is the
main analysis task). Expected: ~8x on ring multiplication with real (partial) transform
structure; precedent: Kyber ships an incomplete NTT for exactly this
reason.

### Q2 — response decomposition to a 32-bit-class modulus (approved; DONE, see Section 6)

The modulus is currently forced to ~2^46 by norm headroom (C2: q > 8 beta).
Decomposing the prover's responses into small digits (base-2^e limbs,
each range-checked by the existing gadget machinery) shrinks the norms
the extractor handles, letting q drop to ~2^31 or below. Payoff is
hardware density, not op count: products fit 64-bit words, SIMD density
doubles, GPU int32 units and the RNS/tensor-core mapping become
available. Cost: more (smaller) committed responses — the digit count
enters the proof size and the gadget bill; the trade must be computed,
not assumed.

## 4. Creative alternatives (not yet approved; ranked by promise)

### A1 — auxiliary-modulus NTT evaluation (most promising; recommend prototyping with Q2/Q3)

The key observation: **the q = 5 mod 8 constraint restricts the ring's
algebraic structure inside the protocol, not how we numerically compute
products.** A product of two ring elements is an exact integer polynomial
whose coefficients are bounded (< d * q^2, ~2^99 at q46, ~2^69 at q31).
Nothing stops us from computing that integer product with *any* fast
method — in particular with NTTs over one or two *auxiliary*
NTT-friendly primes (e.g. Goldilocks-class p = 2^64 - 2^32 + 1, chosen
purely for arithmetic, carrying no protocol role) — and reducing the
result mod q at the end. Soundness interaction: none whatsoever; q, the
ring, the challenges, and every protocol equation are untouched. This is
standard practice in FHE implementations (RNS evaluation).

For GEMM-shaped work — exactly what commitments are — the transforms
amortize beautifully: transform the (fixed) commitment key rows once,
transform each randomness vector once, then all the multiply-accumulates
are pointwise in the frequency domain, with one inverse transform per
output row. Effective cost per ring multiplication approaches the full-
NTT rate that the protocol ring itself cannot offer. If A1 benchmarks as
expected, it may *dominate* Q3 for the commitment bill (Q3 still helps
protocol-internal products and the verifier), and the two compose.

### A2 — Karatsuba/Toom on the schoolbook halves

Sub-quadratic classical multiplication inside the k = 2 (or k = 8)
factors: Karatsuba gives d^1.585 scaling; at degree 64 that is ~2x over
schoolbook, stacking with the split. Cheap to implement, modest gain,
zero risk. Worth doing regardless.

### A3 — two-ring / challenge-separation designs (needs real analysis)

Use an NTT-friendly ring for the *commitment arithmetic* while drawing
challenges from a set engineered to stay invertible there (large-
coefficient challenges, subring challenges, or ALS20-style challenge
spaces with per-slot soundness accounting). This is a genuine protocol
change with soundness on the line — the exact failure mode the k = 2
choice avoided — so it requires a dedicated analysis phase before any
code. Recorded because the literature (ALS20, LNP22) does operate in
fully-splitting rings with carefully built challenge sets; if A1+Q3
underdeliver, this is the researched fallback.

### A4 — RNS limb mapping onto GPU tensor cores

Orthogonal hardware lever (already in the estimate's GPU row): decompose
q31 arithmetic into int8 limb products executable on tensor cores. Only
sensible after Q2; pairs naturally with A1 since both are RNS-flavored.

## 5. Recommended order and measurement gates

1. **Q3 + Q2 jointly** (approved): k = 8 arithmetic + LS18/parameter
   re-verification, digit-decomposition design + norm re-derivation, and
   their *coupling* (the k = 8 invertibility margin at the smaller q).
   **DONE — Section 6.1/6.2; coupling retired.**
2. **A1 prototype in the same tranche** (cheap to test at the
   ring_lattice level; commitment-GEMM benchmark vs k = 2 baseline,
   k = 8, and Karatsuba). **Split to a parallel agent (aux_ntt.rs);
   results pending reconciliation.**
3. **A2** opportunistically inside the same kernels. **DONE — Section
   6.3.**
4. Gate: updated commit-bill projection and the revised 15 s ladder,
   written back into LLM_SCALE_ESTIMATE.md with measured (not assumed)
   ring-mult rates. **DONE — Section 6.4/6.5.**
5. A3 stays parked unless the gate shows the ladder still short of ~15 s
   with Q2 + Q3 + A1 + GPU. **Still parked pending A1's measured rates
   (Section 6.5).**

## 6. Results — the measurement gate (Q2/Q3/A2 tranche, measured)

Prototype artifacts: `zkmatrix-rs/src/bin/ring_lattice.rs` self-test
sections 10-13 (k = 8 arithmetic + Sigma round, digit-decomposed round,
benchmark battery; all green, tamper batteries included) and
`scripts/route_r_params.py` (`k_split_study`, `derive_q2`,
`q2_frontier`). Machine: the repo's 22-thread workstation; kernel
timings single-thread, min-of-batches (load-robust), reproduced across
3 runs. **A1 rows: pending — see the A1 agent's parallel tranche
(`aux_ntt.rs`); the tables below carry placeholders, and the ladder
verdict is stated both without and with the A1 projection.**

### 6.1 Q3: the k = 8 split — verified and measured

Residue condition: **q = 17 (mod 32)** (equivalently v2(q-1) = 4:
primitive 16th roots of unity exist, no 32nd roots), giving
`X^128 + 1 = prod_{t=0..7} (X^16 - eta^(2t+1))` with every binomial
irreducible (verified by the Lidl-Niederreiter criterion *and* direct
Frobenius checks, plus product reconstruction). Selected single-limb
primes:

| prime | value | eta (prim. 16th root) | LS18 bound q^(1/8)/sqrt(8) | quinary margin |
|---|---|---|---|---|
| q8_31 | 2^31 - 399 = 2147483249 | 2056890868 | 5.19 | 1.30x |
| q8_46 | 2^46 - 1103 = 70368744176561 | 49533544627797 | 19.03 | 4.76x |

LS18 coverage frontier for quinary differences (min q with
q^(1/k)/sqrt(k) > 4 is (4 sqrt(k))^k):

| k | residue class | min q | verdict |
|---|---|---|---|
| 2 | 5 mod 8 | 2^5.0 | trivial |
| 4 | 9 mod 16 | 2^12.0 | easy |
| 8 | 17 mod 32 | **2^28.0** | the deepest single-limb split |
| 16 | 33 mod 64 | 2^64.0 | **infeasible at single-limb q** |

(The Section 3 estimate "~10-13 at q ~ 2^31" was wrong; the exact
bound is 5.19. The conclusion survives: covered, margin 1.30x, and
verified in practice — 100 challenge differences inverted through all
8 slots, zero-divisor negative control, full Sigma opening round with
tamper battery at (k = 8, q8_31).)

### 6.2 Q2: digit decomposition — design, prototype, coupling

Design (implemented at prototype level; full rationale in
`route_r_params.py`): combination witnesses are decomposed into
balanced base-2^e digit vectors with published digit statements
`t_j = A1 u_j`, the public recombination `sum_j 2^(ej) t_j = t`, exact
per-digit range claims (M2 binary ct-claims in the full protocol; the
prototype stands in with the bundle norm check), and per-digit Sigma
rounds sharing one challenge, jointly rejection-sampled. The C2/C3
norms collapse to the digit scale — beta becomes beta(e), independent
of the combination count t. Demonstrated in the prototype: a
||u||_inf = 2^10 witness (t ~ 2048-class) *cannot* run the plain
opening round at a 31-bit q (needs q > 2^33.9); decomposed at e = 4 it
fits q8_31 with 2.5 bits of C2 headroom. Tamper battery: wrong digit,
out-of-range-but-recombining digits, recombination mismatch, context
binding, +q overflow — all caught.

The (k, q, e) frontier at Pi2 n = 2048 (concentration discipline;
baseline q46: kappa = 15, N_r = 54, proof 117.0 KB):

| e | L | min log2 q (C2) | C2 headroom @q31 | kappa | N_r | proof KB @q31 | delta |
|---|---|---|---|---|---|---|---|
| 2 | 6 | 29.5 | 2.9 bits | 8 | 40 | 296.0 | +179.0 |
| 3 | 4 | 30.0 | 2.5 bits | 8 | 40 | 209.3 | +92.3 |
| 4 | 3 | 30.5 | 1.9 bits | 9 | 40 | 169.8 | +52.8 |
| 6 | 2 | 32.0 | exceeds q31 | - | - | - | - |
| 8 | 2 | 34.0 | exceeds q31 | - | - | - | - |

**Coupling verdict: the C2 floor (2^29.5 at e = 2) sits ABOVE the
k = 8 LS18 minimum (2^28.07), so no achievable q forces k below 8.**
Recommended operating point: **(k = 8, q = q8_31 = 2^31 - 399,
e in {2, 3, 4})** — e = 4 for proof size (+45% vs q46 baseline), e = 2
for C2 headroom. FFN shape 512x4096x11008 at (q31, e = 4): kappa = 9,
N_r = 57, msg_r = 32, headroom 1.4 bits (e = 2: kappa = 8, N_r = 56,
2.4 bits). Commit/column shrinks 22.3 KB -> 12.1 KB (q and kappa both
drop). Proof-size delta is the price of Q2; commit-arithmetic density
is the payoff.

### 6.3 Measured multiplication and commit-kernel rates

Ring multiplication, d = 128, one product, transforms included
(us single-thread; mult op counts in parentheses):

| method | mults | us/mul | vs naive |
|---|---|---|---|
| naive schoolbook @q31 | 16,384 | 12.2-12.8 | 1.0x |
| k = 2 split @q31 | ~8,512 | 5.7-6.2 | 2.1x |
| k = 2 split + Karatsuba | ~4,928 | 4.3-4.6 | **2.8x** |
| k = 8 split @q8 | ~2,752 | 3.9-4.1 | **3.1x** |
| k = 8 split + Karatsuba | ~2,240 | 4.2-4.4 | 2.9-3.0x |
| aux-NTT (A1) | ~2 x 1,472 + transforms | 3.8 (q46, measured) | 3.2x standalone — transforms dominate; the GEMM shape below is the payoff |

Commit kernel `t1 = A1 rho` (GEMM shape, key rows split once per CRS,
columns once per commit — the transforms amortize; naive baseline
exploits ternary sparsity):

| method | us/ring-MAC (1T) | ring-MACs/s (1T) | vs naive |
|---|---|---|---|
| naive i128 matvec (ternary) | 9.0-9.4 | 1.1e5 | 1.0x |
| k = 2 amortized split | 6.2-6.5 | 1.6e5 | 1.45x |
| k = 2 split + Karatsuba | 2.5-2.6 | 4.0e5 | 3.6x |
| k = 8 amortized split @q8 | 1.9-2.0 | 5.2e5 | 4.7x |
| k = 8 split + Karatsuba @q8 | **1.10-1.17** | **~9.0e5** | **8.1x** |
| aux-NTT GEMM (A1, measured at q46, 47x72 shape) | **~0.15** (0.514 ms/column) | **~6.6e6** | **~60x vs naive, ~7x vs k=8+Kara** (single Goldilocks prime suffices in the ternary regime; A1_AUX_NTT_REPORT.md) |

Findings: (i) the k = 8 split delivers its ~8x in the GEMM-shaped
commit kernel (where the transforms amortize), not in isolated
products; (ii) Karatsuba (A2) pays *inside* the GEMM accumulation
(fixed-buffer, i128-lazy, one reduction per output: 2.4x on the k = 2
kernel, 1.7x on k = 8) but not in single multiplications, and naive
recursive (allocating) Karatsuba loses outright — kernel shape matters
more than op count at these degrees; (iii) one k = 8 + Karatsuba
ring-MAC executes 16,384 useful scalar MACs in 1.11 us single-thread =
1.5e10 scalar-MAC-equivalents/s — above the repo's *multithreaded*
Route Z commit rate (1.1e10 MACs/s) on one thread.

### 6.4 Revised projections

Per-element commit cost (FFN-shape parameters, msg_r = 32):
ring-MACs/element = (1 + kappa/msg_r) * N_r / 128.

| design point | ring-MACs/element | us/element (1T, measured kernel) | ~mults/element |
|---|---|---|---|
| Route Z scalar (anchor) | — | — | ~11,300-16,000 |
| Route R k = 2 q46 (kappa 15, N_r 72) | 0.826 | 2.1 (Kara) | ~3,900 |
| **Q2+Q3: k = 8 + Kara, q31 (kappa 9, N_r 57)** | **0.571** | **0.63** | **~950-1,070** |
| + A1 aux-NTT (**measured**) | 0.571 | ~0.09-0.15 | **~119** (q46 ternary regime — below the ~200-300 close threshold) |

**(a) The commit bill, 7B/512-token pass** (same ~9.4e9 committed
element-equivalents as LLM_SCALE_ESTIMATE.md, incl. bit tensors;
22-thread scaling taken at ~15x measured-1T — flagged as extrapolation):

| stage | commit bill |
|---|---|
| Route Z today (measured, 22T) | ~3.8 h |
| Route R k = 2 + Kara, q46 | ~19,400 s 1T -> **~22 min** 22T |
| **Q2+Q3+A2 (this tranche, measured)** | ~5,960 s 1T -> **~6.6 min** 22T (**~34x vs Route Z**) |
| + GPU integer GEMM (the estimate's 20x row; int32 density at q31 is what makes 20x credible without the q46 2.4x int8-GEMM penalty) | **~20 s** |
| + A1 (measured kernel ~7x over k8+Kara; regime-weighted 2-4x at bill level) | **~1-2 min 22T CPU -> ~3-6 s GPU** |

**(b) The 15 s ladder.** Claim proofs (r = 1, side-linear, ~2,200
claims) at q31/k8 kernels: ~0.05-0.15 s each 1T -> ~10-25 s wall on 22
threads (digit rounds add L x to the opening layer only — percent-level
on claim time, +45% on proof bytes at e = 4). Elementwise gadgets stay
noise (~2-3x better than the ~17 us/element projection at q31). Total
per pass: **~25-45 s with Q2+Q3+A2+GPU; ~15 s with A1 on top if it
lands at its op-count projection.**

### 6.5 Gate verdict (per Section 5)

- Q2 + Q3 are **verified jointly feasible** at a 31-bit single-limb
  modulus — the coupling risk is retired (C2 floor 2^29.5 > LS18-k8
  floor 2^28.07). Recommended point: (k = 8, q8_31, e in {2, 3, 4}).
- Measured commit-arithmetic recovery: **8.1x kernel speedup, ~34x
  commit-bill reduction vs Route Z** (vs the 2-3x the k = 2 mandate
  left on the table) — most of the "assumed efficiency" of the original
  estimate is recovered, as Section 1 predicted.
- **The ~15 s gate does NOT close on Q2+Q3+A2 alone: ~25-45 s with the
  GPU row.** The remaining 2-3x is exactly A1's lane (amortized
  aux-modulus NTT in the commit GEMM).
- **Reconciliation with the A1 agent's measurements (parallel tranche,
  A1_AUX_NTT_REPORT.md): the gate CLOSES at projection level.** A1
  measured ~119 helper-prime multiplications per committed element in
  the dominant ternary regime — well below the ~200-300 threshold this
  gate required — and ~7x over the k=8+Karatsuba kernel at GEMM shape,
  with single-prime capacity confirmed for the golden regime (and, at
  q31, for the Gaussian-mask regime too). Combined projection per
  7B/512 pass: commit bill ~3-6 s (GPU) + claim proofs ~10-25 s wall
  (22T) + gadgets at noise level = **~15-30 s, i.e. ~2-4x the
  quantized-CPU inference baseline — the 15 s rung is within the
  projection's error bars.** The remaining conversion from projection
  to measurement is the A1 integration tranche (~3-5 days, plan in
  A1_AUX_NTT_REPORT.md Section 5) plus GPU kernels. **A3 is parked
  indefinitely** unless integration falsifies these rates.

## 7. The wider honesty note

Even at the 15 s / ~2x-of-CPU-int8 endpoint, proving remains ~100-300x
slower than *float* inference on datacenter GPUs (the A100 baseline).
That gap is the long game: A4/tensor-core mapping is the in-family path;
small-field hash-based proof systems are the out-of-family alternative;
and verification (already milliseconds) remains the deployable win at
every stage. Track, but do not let it gate the current ladder.
