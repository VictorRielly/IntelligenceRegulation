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
| k = 8 split (**Q3**) | 8 x 16^2 = 2,048 | 8x | LS18 margin ~4x — verified viable |
| full NTT (k = 128) | ~d log d ~ 900 | ~18x | **breaks LS18 for short challenges — not available directly** |
| auxiliary-modulus NTT (**A1**, below) | ~pointwise + amortized transforms | approaches full-NTT rates for GEMM-shaped work | **none — evaluation strategy only** |

Where it lands in the totals (7B/512-token pass, this machine's measured
kernel rates): commitments are ~80-90% of the Route R prover bill; at
k = 2 they improve only 2-3x over Route Z, keeping the pass at ~2-4 min.
Recovering ~8x (Q3) or more (A1) on ring multiplication moves the
commitment bill roughly proportionally; combined with Q2's hardware-density
gains and GPU kernels, the ladder to ~15 s closes.

## 3. Approved workstreams

### Q3 — the k = 8 split (approved)

Split X^128 + 1 into 8 factors of degree 16 (needs q = 17 mod 32-type
conditions; parameter script to confirm exact residue class). LS18
invertibility threshold ~q^(1/8)/sqrt(8): at q ~ 2^46 that is ~19-24,
comfortably above the quinary challenge-difference bound of 4; at
q ~ 2^31 (post-Q2) it is ~10-13, still above 4 but with the margin to be
re-verified jointly with Q2 (this Q2/Q3 coupling is the main analysis
task). Expected: ~8x on ring multiplication with real (partial) transform
structure; precedent: Kyber ships an incomplete NTT for exactly this
reason.

### Q2 — response decomposition to a 32-bit-class modulus (approved)

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
2. **A1 prototype in the same tranche** (cheap to test at the
   ring_lattice level; commitment-GEMM benchmark vs k = 2 baseline,
   k = 8, and Karatsuba).
3. **A2** opportunistically inside the same kernels.
4. Gate: updated commit-bill projection and the revised 15 s ladder,
   written back into LLM_SCALE_ESTIMATE.md with measured (not assumed)
   ring-mult rates.
5. A3 stays parked unless the gate shows the ladder still short of ~15 s
   with Q2 + Q3 + A1 + GPU.

## 6. The wider honesty note

Even at the 15 s / ~2x-of-CPU-int8 endpoint, proving remains ~100-300x
slower than *float* inference on datacenter GPUs (the A100 baseline).
That gap is the long game: A4/tensor-core mapping is the in-family path;
small-field hash-based proof systems are the out-of-family alternative;
and verification (already milliseconds) remains the deployable win at
every stage. Track, but do not let it gate the current ladder.
