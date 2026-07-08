# A1 aux-modulus NTT prototype — progress log

Task: prototype A1 (auxiliary-modulus NTT evaluation) from
docs/zkmatrix-poc/RING_MULT_BOTTLENECK.md Section 4.
Surface: zkmatrix-rs/src/bin/aux_ntt.rs (new bin),
docs/zkmatrix-poc/A1_AUX_NTT_REPORT.md (new report), this file.
MUST NOT touch: zkmatrix-rs/src/bin/ring_lattice.rs, scripts/route_r_params.py,
RING_MULT_BOTTLENECK.md results (sibling agent owns those).

Build: PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release
Suite: PATH=... python3 -m unittest discover -s tests  (37/37 must stay green)

## State

- [x] U0: worktree contains c731832 (merged perf/zk-batch-optimizations, fast-forward).
- [x] U1: Goldilocks arithmetic + negacyclic NTT (d=128, psi-twisted, no padding), self-tests.
      All green first run: reduce128 vs slow path (12 edges + 1e6 random u128), generator
      order check, roundtrip incl. all-(p-1) input, NTT product == schoolbook mod p incl.
      worst-case-magnitude and X^127*X wraparound cases. Longa-Naehrig merged-twist
      convention (CT-DIT fwd bit-reversed output / GS-DIF inv) worked as written.
- [x] U2: capacity analysis + regime table (exact u128 checks; printed by the bin).
      Regimes measured exactly (u128, no floats): (a) key x ternary FITS single prime
      with FULL module-dim accumulation (q46 FFN N_r=72: 59-bit bound vs 63-bit capacity;
      headroom to n_acc = 2047) — the golden case. (b) key x 12sigma masks: q31 prototype
      JUST fits (63-bit bound); all q46 shapes exceed by ~28 bits -> limb-split fallback.
      (b') quinary x mod-q combination sums fit single prime up to 1023 accumulated terms
      at q46. (c) general x general: 97 bits at q46 -> limb-split (L=23 balanced halves,
      3 Karatsuba sub-products, mid transform via NTT linearity = 2 fwd per operand,
      3 inv + exact i128 recompose + mod q). All paths exactness-tested vs schoolbook
      mod q at q46 and q31, incl. worst-case-magnitude inputs hitting d*(q-1)/2 exactly.
- [x] U3: GEMM-shaped commit kernel (cached key transforms, u128 lazy accumulation), exactness cross-checks.
      A1CommitKernel (cached NTT(G); reduce-each-product-to-u64 then u128-accumulate;
      1 inv NTT/output; capacity contract asserted at construction) == schoolbook ==
      ternary-specialized schoolbook == k2 CRT-split kernel, at q46 and q31, shapes
      4x6 and 14x36, 8 random columns each; worst-case accumulator input hits
      N_r*d*(q-1)/2 exactly (59 bits at q46 N_r=72) and matches the closed form.
      k2 baseline built with runtime sqrt(-1) = 2^((q-1)/4) (asserted r^2 = -1),
      cached key slots, 8192-MAC slot schoolbook, recombination per output.
- [ ] U4: benchmarks (schoolbook / ternary-schoolbook / k2-split / A1-single / A1-limb-split), medians over pinned reps, single-threaded.
- [ ] U5: report A1_AUX_NTT_REPORT.md + revised commit-bill projection.

## Decisions

- Aux prime: Goldilocks p = 2^64 - 2^32 + 1 (v2(p-1) = 32; p-1 = 2^32 * 3*5*17*257*65537,
  generator 7 — verified in self-test). Negacyclic transform via Longa-Naehrig
  merged psi-twist (DIT forward / GS-DIF inverse), verified against schoolbook mod p.
- General-regime fallback (U2c): OPERAND LIMB-SPLITTING (balanced ~23-bit halves,
  3 Karatsuba sub-products over the single Goldilocks prime), NOT two-prime CRT.
  Estimate that drove it: cached-transform GEMM costs are a wash on op counts
  (limb 3 Goldilocks pointwise muls ~= CRT 1 Goldilocks + 1 Montgomery mul + Garner),
  but limb-split reuses the one NTT/tables/reduction path — far less code, one prime.
  Both estimates to be documented in the report.
- Karatsuba mid-operand transform obtained by NTT linearity (NTT(lo)+NTT(hi)) — no
  third forward transform. Recomposition must happen on exact integers per sub-product
  (3 inverse NTTs), THEN mod q; recombining scaled limbs in NTT domain would overflow p.
- Accumulator discipline (U3): reduce each pointwise product to u64 (Goldilocks reduce128),
  accumulate u64s in u128 (safe for >> N_r <= 72 terms), single reduce at the end.
  Worst-case-magnitude test planned: a_i = +-floor(q/2) signs aligned, b = all-ones ternary,
  N_r identical columns -> exact bound N_r * d * floor(q/2) hit exactly.
- Benchmarks single-threaded (sibling agent shares the machine); medians over pinned reps.
- Bin CLI: `self-test` = exactness tests + capacity table (fast; suite-safe);
  `bench` = full benchmark run. Default (no arg) = self-test.
- Protocol moduli benchmarked: q46 = 2^46 - 635 primary (protocol recommendation),
  q31 = 2^31 - 19 secondary. sqrt(-1) mod q computed at runtime for the k2 baseline.

## Next

U4: benchmarks in aux_ntt.rs under `bench` arg. Single ring-mult (schoolbook,
k2 standalone, A1-single standalone, A1-limb standalone) and commit-kernel
throughput (schoolbook, ternary-schoolbook, k2 cached, A1 cached; shapes
demo 14x36, n2048 31x54, FFN 47x72, scaled FFN 47x72 x 512 cols) at q46
(q31 secondary for single mults). Single-threaded, medians over pinned reps,
concurrency caveat printed. Report ring-mults/s and effective MACs/s
(= ring-mults * 16384 / s).
