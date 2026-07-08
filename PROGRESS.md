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
- [ ] U2: capacity analysis + regime table (exact u128 checks; printed by the bin).
- [ ] U3: GEMM-shaped commit kernel (cached key transforms, u128 lazy accumulation), exactness cross-checks.
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

U2: capacity analysis in aux_ntt.rs — exact u128 regime checks (a/b/c), printed
regime table; balanced-lift helpers Zq -> Zp and centered recovery Zp -> Z -> Zq;
limb-split general product (3 Karatsuba sub-products) with exactness test vs
schoolbook mod q.
