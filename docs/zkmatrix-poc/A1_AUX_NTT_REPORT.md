# A1 Prototype Report: Auxiliary-Modulus NTT Evaluation of Route R Ring Products

Status: prototyped and measured. Workstream A1 of
`RING_MULT_BOTTLENECK.md` Section 4, feeding the Section 5 measurement
gate. Artifact: `zkmatrix-rs/src/bin/aux_ntt.rs` (standalone bin, no
changes to any existing file; `cargo run --release --bin aux_ntt` runs 24
exactness self-tests and prints the capacity table; `... aux_ntt bench`
adds the benchmark suite). Raw benchmark session:
`docs/zkmatrix-poc/results/aux_ntt_bench_q46.txt`.

**Headline: the GEMM-shaped commitment kernel — the dominant LLM-scale
cost — runs 80x faster than naive schoolbook and 38x faster than the
cached k = 2 split at the FFN module shape (47 x 72, q46), measured,
exact, with zero soundness interaction.** Commit arithmetic lands at
~119 Goldilocks multiplications per committed coefficient — the
"few-hundred class" that `LLM_SCALE_ESTIMATE.md` Section 3b identified as
the ops-side condition for the 2x-overhead endpoint — at the mandated
k = 2 parameter point, without touching q, the challenge set, or any
protocol equation.

## 1. The idea (and why soundness is untouched)

The protocol ring `R_q = Z_q[X]/(X^128 + 1)` has q = 5 mod 8 so that
X^128 + 1 splits into only two factors (the Lyubashevsky-Seiler
invertibility margin needs few factors). That kills any NTT *in R_q*:
v2(q - 1) = 2, no useful roots of unity. But a product of two ring
elements is an exact integer polynomial before reduction: over balanced
representatives, every coefficient of a*b is bounded by
`d * max|a| * max|b|`. Any modulus large enough to determine that integer
uniquely can host the computation. We use the Goldilocks prime

    p = 2^64 - 2^32 + 1,   p - 1 = 2^32 * 3 * 5 * 17 * 257 * 65537

whose 2-adicity (v2(p-1) = 32) gives 256th roots of unity, hence a
psi-twisted **negacyclic** length-128 transform — multiplication directly
in Z_p[X]/(X^128 + 1), no zero-padding. Pipeline: lift balanced mod-q
representatives into Z_p, transform, multiply pointwise, inverse
transform, recover the exact centered integer, reduce mod q.

p carries no protocol role. The challenges, the modulus q, the LS18
argument, every verification equation see exactly the same mod-q numbers
as before, bit for bit (the self-tests check literal equality against
schoolbook mod q). This is the standard RNS-evaluation practice of FHE
implementations, applied to a prover's internal arithmetic.

The transform pair is the Longa-Naehrig merged-twist convention
(Cooley-Tukey DIT forward with psi powers in bit-reversed order,
Gentleman-Sande DIF inverse): 448 butterflies each way, no separate twist
pass. All value-path arithmetic is exact integer (u64/u128/i128); floats
appear only in timing printout.

## 2. Capacity regimes (exact, printed by the bin)

Single-prime contract: `n_acc * d * A * B <= (p-1)/2` (63 bits), where
A, B bound the balanced operand magnitudes and n_acc is how many ring
products accumulate in the NTT domain before the inverse transform (the
module dimension N_r for commitments). Checked in exact u128 arithmetic
at kernel construction — a static property of the parameter regime, never
of the data.

| regime (operands) | A | B | n_acc | bound | fits one prime? | configuration |
|---|---|---|---|---|---|---|
| **(a) key x ternary randomness (commit kernel)**, q46, FFN N_r=72 | 2^45 | 1 | 72 | 2^59 | **YES — the golden case** | single-prime, full in-domain accumulation |
| (a) q46, n2048 N_r=54 | 2^45 | 1 | 54 | 2^58 | YES | single-prime |
| (a) q31, prototype N_r=26 | 2^30 | 1 | 26 | 2^42 | YES (21 bits headroom) | single-prime |
| (b) key x Gaussian mask (12 sigma), q31 prototype sigma=177186 | 2^30 | 2^21 | 26 | 2^63 | YES — just | single-prime |
| (b) key x mask, q46 n2048 sigma~2^28.6 | 2^45 | 2^32.2 | 54 | 2^91 | no | limb-split x3 |
| (b) key x mask, q46 FFN sigma~2^30 | 2^45 | 2^33.6 | 72 | 2^92 | no | limb-split x3 |
| (b') quinary challenge x mod-q (combination sums), q46 | 2 | 2^45 | <= 1023 | 2^63 | YES | single-prime, chunk at 1024 terms |
| (c) general mod-q x mod-q (response x response, gate terms), q46 | 2^45 | 2^45 | 1 | 2^97 | no | limb-split x3 |
| (c) general, q31 | 2^30 | 2^30 | 1 | 2^67 | no (by 4 bits) | limb-split x3 |
| (c) limb sub-products after split, q46 (L = 23) | 2^23 | 2^23 | <= 1023 | 2^54..63 | YES | that is the point |

Readings, prominently:

- **The commitment kernel — key x ternary/binary columns, THE dominant
  LLM-scale cost — fits a single Goldilocks prime even at q = 2^46, with
  the entire module dimension accumulated in the NTT domain** (59 of 63
  bits at FFN shape; headroom to n_acc = 2047). Bit-tensor commitments
  (binary columns, the bulk of the LLM-scale bill after w = 12
  decomposition) are the same regime. This is the golden case and it is
  exactly the case that matters.
- Mask commitments (the M ~ 2.76 rejection-sampled Gaussian masks) fit
  single-prime at the q31 prototype point but not at q46: single-prime
  capacity ends at B <= 2047, i.e. sigma <~ 170, and the protocol sigmas
  are 2^24.6-2^30. They take the limb-split path (measured ~3.2x the
  golden-case cost — still 12x over k = 2).
- Protocol combination sums (quinary challenge times commitments/messages)
  stay single-prime up to 1023 accumulated terms at q46 — chunk longer
  sums or reduce partially.
- General products (response x response in gate layers) always need the
  fallback at both moduli.

### The fallback choice: limb-split, not two-prime CRT

Both were estimated; limb-splitting was implemented. With a = a1*2^L + a0
(balanced limbs, one COMMON base for both operands — Karatsuba's middle
term reconstructs only then), a*b needs sub-products P0 = a0*b0,
P2 = a1*b1, PM = (a0+a1)(b0+b1), each far inside single-prime capacity
(L = 23 at q46: 54-bit bounds, >= 10 bits of accumulation headroom).
Estimate that drove the choice, per ring-mult in cached-GEMM form:

| cost | limb-split x3 | CRT over two primes |
|---|---|---|
| cached key transforms | 2 NTTs + 1 vector add (mid via linearity) | 2 NTTs (one per prime) |
| column transforms | 2 NTTs + 1 add | 2 NTTs |
| pointwise per coefficient | 3 Goldilocks muls (~5 ops each) | 1 Goldilocks + 1 Montgomery mul (~5 + ~9 ops) |
| per output element | 3 inverse NTTs + exact recompose mod q | 2 inverse NTTs + Garner + mod q |
| code surface | reuses the single Goldilocks path | second prime: Montgomery arithmetic, root tables, Garner |

Op counts are a wash (~15 vs ~14 pointwise ops); the limb path reuses one
arithmetic/table/reduction implementation and keeps every intermediate in
one field. If AVX-512/GPU vectorization later makes Montgomery lanes
cheap, CRT-2 becomes worth revisiting (it needs one fewer inverse
transform per output); nothing in the design precludes swapping.

One correctness rule worth recording: **recombination must happen on
exact integers** — inverse-transform each sub-product, recover centered
values, then combine with 2^L, 2^2L mod q. Folding the limb scales into
the NTT domain would overflow the exact-integer contract (the recombined
coefficients reach ~2^99 at q46).

## 3. The GEMM-shaped commit kernel

`C = G * R`: G is the fixed commitment key, (kappa + msg_r) x N_r ring
elements; R carries many ternary (or binary) columns. A1 evaluation:

1. Transform G once (`A1CommitKernel::new` caches NTT-domain rows;
   ~3.2 MB at FFN shape — negligible, and CRS expansion can emit it).
2. Per column: N_r forward transforms (one per column element).
3. Per output element: pointwise multiply-accumulate across N_r in the
   NTT domain, one inverse transform, centered recovery, mod q.

Amortized arithmetic per ring-mult at FFN shape (47 x 72): 128 pointwise
mul-accs + (72 + 47) transforms x 448 muls / 3384 ring-mults ~ 16 muls,
i.e. **~144 Goldilocks muls per ring-mult vs 16,384 schoolbook MACs /
8,192 k = 2 MACs** — a ~57-114x op-count reduction, of which ~50-80x
survives in measured wall-clock (Section 4).

**Accumulator correctness** (the overflow trap the design had to get
right):

- NTT-domain values are < 2^64, so one raw pointwise product fills a
  u128 and two cannot be added there. The kernel accumulates the low and
  high 64-bit halves of each raw product in separate u128s (one widening
  mul + two adds per term — no per-product reduction), and recovers
  `sum = reduce128(acc_lo + EPS * acc_hi)` using 2^64 = EPS (mod p).
  Exact while n_acc < 2^31 — the module dimensions are <= 72.
- The Goldilocks primitives are branchless (cmov canonicalization; the
  no-double-wrap case analysis is in the code comments). This mattered:
  data-dependent branches in add/sub/reduce cost ~3x NTT throughput
  (3.3 us -> 1.05 us per transform after the change). `reduce128` is
  differentially tested against the slow `% p` path on 10^6 random u128s
  plus structured edges (0, p-1, p, p+1, 2^64, (p-1)^2, u128::MAX, ...).
- Centered recovery uses a single u64 division per coefficient (valid
  because the contract keeps recovered values < 2^63).
- Worst-case tests drive the accumulator to the EXACT capacity bound:
  key elements patterned +-(q-1)/2 so all d terms add with one sign,
  all-ones ternary columns, full N_r accumulation — output coefficient
  equals `N_r * d * (q-1)/2` exactly (59 bits at q46, checked against
  the closed form and against schoolbook).
- Exactness cross-checks: A1 = schoolbook = ternary-schoolbook = k2 on
  random columns at q46 and q31 (literal mod-q equality), and the
  limb-split GEMM kernel = schoolbook on 12*2^30-bounded mask columns at
  full N_r = 72 depth including max-magnitude columns.

The regime-(b) variant (`A1LimbCommitKernel`) caches 3 NTT vectors per
key element (lo, hi, lo+hi), spends 2 forward transforms + 1 add per
column element, 3 pointwise muls per coefficient, 3 inverse transforms
per output element — measured ~3.2x the golden-case cost.

## 4. Measured results

Setup: 1 thread, medians over 9 pinned repetitions (x1000 mults for
single-mult rows; x16/x2 columns per rep for fast/slow GEMM methods),
q46 = 2^46 - 635 unless noted. **Caveat: the machine is shared with a
sibling agent's concurrent benchmarks; medians within one session are
consistent, but cross-session medians moved up to ~2x on the baselines
(e.g. k2 n2048 column 12.9-24.9 ms across three sessions). All ratios
below are within-session.** Effective MACs/s = ring-mults/s x d^2 =
schoolbook-equivalent throughput, the unit of the LLM-scale estimates.

Single ring-mult, d = 128 (us/mult):

| method (operand regime) | q46 | q31 |
|---|---|---|
| schoolbook (general x general) | 11.5 | 11.6 |
| schoolbook ternary-specialized (key x ternary) | 7.0 | 7.1 |
| k2 split (general x general) | 5.4 | 5.4 |
| **A1 single-prime (key x ternary)** | **3.8** | **3.7** |
| A1 limb-split (general x general) | 11.0 | 12.0 |
| (primitives: ntt_fwd 1.06 us, ntt_inv 1.04 us) | | |

Standalone, A1 wins 3.0x over schoolbook and 1.4x over k2 in the short
regime; the limb path standalone is a wash with schoolbook (7 transforms
per product buy nothing without amortization). The transforms dominate
(3 x ~1.05 us of the 3.8) — which is exactly why the GEMM shape, where
they amortize away, is the payoff case:

Commit kernel C = G x R, q46, ms/column (ternary columns unless noted):

| shape (rows x N_r) | schoolbook | ternary-schb | k2 cached | **A1 (ternary)** | A1 limb (mask 12sigma~2^33.6) |
|---|---|---|---|---|---|
| demo 14 x 36 | 5.85 | 3.74 | 2.93 | **0.116** | 0.343 |
| n2048 Pi2 31 x 54 | 20.5 | 13.1 | 12.9 | **0.390** | 1.20 |
| FFN 47 x 72 | 41.2 | 27.4 | 19.6 | **0.514** | 1.65 |

Speedups and effective throughput (FFN shape, the LLM-relevant one):

| method | eff MMAC/s | vs schoolbook | vs k2 cached | vs ternary-schb |
|---|---|---|---|---|
| schoolbook | 1,347 | 1.0 | 0.5 | 0.7 |
| ternary-schoolbook | 2,026 | 1.5 | 0.7 | 1.0 |
| k2 cached | 2,833 | 2.1 | 1.0 | 1.4 |
| **A1 single-prime** | **107,825** | **80x** | **38x** | **53x** |
| A1 limb-split (mask) | 33,700 | 25x | 12x | 16x |

Scaled FFN-representative run (47 x 72, 256 columns): 0.153 s total,
5.7e6 ring-mults/s, ~93 effective GMAC/s — amortization is stable at
volume (the 16-column and 256-column per-column costs agree to within
session noise). The k2-vs-schoolbook ratio (2.1x) independently
reproduces ROUTE_R_DESIGN's "~2x total win" for the k = 2 split, a
useful sanity anchor. A k2 baseline with Karatsuba slots (not
implemented here; ~1.7x fewer MACs) would put A1's commit-kernel
advantage at ~22x instead of 38x — both numbers quoted below.

Per committed coefficient at FFN shape: 0.514 ms / (msg_r * d = 4096
elements) = **125 ns/element single-thread, ~119 Goldilocks muls/element**
(vs ~3,900 ops/element for k2-Karatsuba in ROUTE_R_DESIGN Section 7, vs
~8-16k MACs/element on Route Z).

## 5. Integration plan (described, not implemented — sibling-agent files untouched)

Where it goes, in the ROUTE_R_DESIGN Section 6 module layout:

1. **`ring/aux_ntt.rs` (new)**: everything in this bin's U1/U2 —
   Goldilocks primitives, tables, fwd/inv transforms, lifts, capacity
   checks, the limb-split product. ~450 self-contained lines exist.
2. **`ring/commit.rs` / the ring_lattice commit path**: CRS expansion
   additionally emits the cached NTT-domain key (`A1CommitKernel::new`
   is that precomputation; +8 * rows * N_r * 128 bytes ~ 3.2 MB at FFN).
   `ring_matvec_small(A1, rho)` calls with ternary rho become
   `A1CommitKernel::commit_column` (regime a). Outputs are bit-identical
   mod q, so nothing downstream (hashing, serialization, manifest,
   verification) changes.
3. **Mask commits** (`A1 y` with Gaussian y inside `prove_opening`'s
   loop): `A1LimbCommitKernel` at q46; at q31 the single-prime kernel
   suffices (capacity table row (b)). Note M ~ 2.76 restarts multiply
   this cost, so the 12x-over-k2 matters.
4. **Combination sums** (x_a = sum_i s_i apack_i, derived keys, tau_v):
   quinary x mod-q single-prime path with chunking at 1023 accumulated
   terms (regime b').
5. **Gate/response products** (z x z garbage terms, Pi2 bilinear layer):
   the limb-split product; or leave on k2 slot kernels initially — these
   are side-linear, not the bill.
6. **Parameter derivation**: add a "P0 capacity" line to the C0-C4
   chain asserting each kernel's regime bound (the kernels also assert at
   construction; the param script owns the policy). A1 imposes NO
   constraint on q, kappa, N_r, sigma — it only reads them.
7. **Verifier**: c * t1 is quinary x mod-q (single-prime path) — but the
   verifier is milliseconds; migrate only if convenient.
8. **Testing discipline**: schoolbook stays as the differential oracle
   (exactly as in this bin); the existing negative-test battery transfers
   unchanged since proofs/commitments are byte-identical.

Effort estimate: **~3-5 days** inside the migration's U1-U2 units
(kernel swap + capacity asserts + differential tests ~1-2 days; mask
path ~1 day; combination-sum chunking ~1 day; no protocol or proof-shape
work anywhere). GPU A1 kernels (batched Goldilocks NTT — the
plonky2/Miden-class primitive) slot into the existing "GPU kernels"
workstream unchanged in scope.

Composition with Q2/Q3: A1 is orthogonal to both. Q2 (q -> 2^31-class)
enlarges the golden regime (even mask commits fit single-prime at q31)
and doubles SIMD density; Q3 (k = 8) still helps protocol-internal
products and the verifier but is no longer needed for the commit bill.
If Q2 lands, revisit CRT-2 vs limb-split (at q31 the general regime
misses one prime by only 4 bits, and single-limb tricks may suffice).

## 6. Revised commit-bill projection, 7B/512-token pass

Anchors (`LLM_SCALE_ESTIMATE.md` Sections 2-3b, `ROUTE_R_DESIGN.md`
Section 7): commit bill ~1.5e14 Route Z MACs incl. w=12 bit tensors;
after Tier-1 ~1.2 h; at Route R k = 2 ~25-35 min (CPU, full machine);
ladder endpoint 2-4 min/pass only AFTER a 20x GPU factor.

The arithmetic, using within-session measured ratios:

- Bill composition: bit-tensor commitments (binary columns — golden
  regime) are ~5/6 of the 1.5e14 (the w=12 decomposition multiplier);
  value tensors (w-bit values, B ~ 2^11 at q46 — just over single-prime,
  so limb path) ~1/6.
- Weighted A1-vs-k2 factor: 5/6 / 22x + 1/6 / 12x, taking the
  CONSERVATIVE 22x (A1 vs k2-Karatsuba, i.e. already crediting k2 with
  the not-yet-written Karatsuba slots) -> combined **~19x** on commit
  arithmetic. (Against the k2 kernels as they exist today: ~28x.)
- **CPU commit bill: 25-35 min / 19 ~ 1.3-1.8 min** per pass, same
  machine class, no GPU. Sanity check from the other direction: 1.5e14
  Route Z MACs at ~11.3k MACs/element = 1.33e10 committed coefficients;
  at the measured 125-400 ns/element (regime-weighted ~170 ns) that is
  ~2,260 s single-thread ~ **1.7 min at 22 threads** (GEMM-shaped,
  embarrassingly parallel over columns). The two routes agree.
- Pass total on CPU: commits ~1.5 min + claim proofs (minutes at k = 2,
  now co-dominant) ~ **3-6 min WITHOUT GPU** — i.e. A1 alone delivers on
  CPU approximately what the ladder had assigned to k2 + GPU.
- With the same 20x GPU factor applied to A1's kernels (batched
  Goldilocks NTT is a mature GPU primitive): commit bill **~5-10 s** —
  at or below the 15 s ladder line, leaving claim proofs and gadget
  layers as the binding terms (Q2's word-width lever and the r = 1
  claim collapse address those).
- Section 3b condition check: measured ~119 Goldilocks muls/element
  ~ 300-400 int-MAC equivalents — **the "few-hundred MACs/element" class
  that the 2x-overhead decomposition requires is reached at k = 2**,
  vs the 4096-11008 MACs/element the FFN itself spends: commit ops are
  ~3-9% of inference ops. The ops-side gate to the 2x endpoint no longer
  runs through Q3's soundness-coupled k-split; it runs through ordinary
  kernel/GPU engineering plus Q2 for throughput density.

Honesty notes: the 19-33x range depends on which k2 baseline is
credited; the sibling Q2/Q3 workstream may move the anchor numbers
(25-35 min) themselves; cross-session load variance on this shared
machine is up to ~2x on baselines (ratios within a session are the
reliable statistic); and the GPU factor remains the estimate's assumed
20x, not a measurement.

## 7. Descoped / follow-ups

- Two-prime CRT variant: estimated (Section 2), not implemented.
- k2-Karatsuba baseline: op-count-credited in the ratios, not coded.
- AVX-512/GPU A1 kernels; multithreaded (rayon) commit benchmark.
- q31 commit-kernel benchmark table (single-mult rates measured; the
  q31 story is strictly better — even masks fit single-prime).
- Integration into ring_lattice/route-r kernels (sibling agent owns
  those files; plan in Section 5).
- Negacyclic transforms of length 256/512 for a future d = 256 fallback
  (v2(p-1) = 32 leaves abundant room; not needed at d = 128).
