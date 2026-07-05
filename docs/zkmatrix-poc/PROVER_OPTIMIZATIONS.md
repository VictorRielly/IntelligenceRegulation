# Prover Optimization Plan and Results

Documented optimization plan for both proof tracks, driven by the measured
bottlenecks in `TRACK_COMPARISON.md`. Tier 0 is implemented and measured
(this document records before/after); Tiers 1-2 are specified with expected
gains and acceptance criteria. Machine: Core Ultra 9 185H, 22 threads
(same environment as the track comparison).

Bottleneck recap, from measurement:

- **Pairing (structured BLS12-381)**: prover = `~n^2` G1 MSM over the
  witness area (masking layer costs ~6%; core and zk prove within a few
  percent of each other); setup = serial `O(n^2)` powers-of-tau (856 s at
  n = 2048); verifier is pairing-count bound only at large batch sizes.
- **Lattice (Route Z)**: every kernel is a product against the 150-300 MB
  `G1/G2` matrices, and the original code streamed those matrices from
  RAM once per vector (per repetition x attempt x column) — memory
  bandwidth, not arithmetic, was the wall. Secondary: the `r = 37/64`
  repetition count and the `M ~= 2.76` rejection restarts are pure
  multipliers; the per-matrix commitment dominates at n >= 1024.

## Tier 0 — implemented in this commit, measured

### P0.1 Parallel SRS generation (pairing)

The powers-of-tau loop is sequential only through the running power;
chunking it (each chunk seeds itself with `tau^start` and walks
sequentially inside) parallelizes it without changing a single output
point. Same SRS, same digest, same proofs.

| n | setup before | setup after | speedup |
|---|---|---|---|
| 256 | 13.5 s | 1.8 s | 7.5x |
| 512 | 54.1 s | 6.9 s | 7.8x |
| 1024 | 214.0 s | 27.0 s | 7.9x |
| 2048 | 856.2 s | ~108 s (projected) | ~8x |

### P0.2 Batched KZG verification (pairing)

Every opening check `e(C - vG, H) = e(W, tauH - zetaH)` rewrites to the
fixed-G2 form `e(C - vG + zeta*W, H) = e(W, tau*H)`, so all checks in one
verification call aggregate under verifier-local random weights into a
single 2-Miller-loop pairing (`KzgBatch`), with `H` and `tau*H` prepared
once per SRS. A `t`-claim batch verification now does 2 Miller loops
instead of `2*(3 + t)`. Measured effect at the sizes benchmarked is
modest (core n = 1024 verify 14.4 -> 12.6 ms; batch n = 256, t = 16:
3.72 -> 3.51 ms/claim) because hashing and the `n^2` public-power
evaluation dominate at small t; the win scales with batch size
(t = 1024: 2054 -> 2 Miller loops). Soundness: standard random-linear-
combination batch verification; a single failing opening survives only
with probability ~1/|scalar field|. All tamper cases in the self-test
still fail.

### L0.1-L0.4 Blocked kernels + wave-scheduled prover + batched verifier (lattice)

- `matmat_signed`: blocked multi-vector kernel — G streams from memory
  once per 8 vectors instead of once per vector.
- Commitment: whole matrices commit through blocked passes
  (`commit_columns_fast`).
- Prover: wave scheduling — every pending repetition's mask commitments
  are computed in one blocked pass per wave (the report Section 13 GEMM
  shape); rejected repetitions carry to the next wave with fresh masks.
  Per-repetition deterministic rng streams make wave sampling parallel.
- Verifier: all repetitions' response matvecs run in one blocked pass,
  then per-repetition checks run repetition-parallel.

Transcripts are unchanged in structure (same challenges, same checks);
only the schedule of the linear algebra changed. Self-test (valid +
invalid, both protocols) passes.

| metric | before | after | speedup |
|---|---|---|---|
| Pi1 prove n=1024 | 2.03 s | 0.52 s | 3.9x |
| Pi1 prove n=2048 | 3.59 s | 0.82 s | 4.4x |
| Pi2 prove n=1024 | 4.85 s | 1.73 s | 2.8x |
| Pi2 prove n=2048 | 8.45 s | 2.41 s | 3.5x |
| Pi1 verify n=2048 | 1.66 s | 0.42 s | 4.0x |
| Pi2 verify n=1024 | 2.48 s | 0.69 s | 3.6x |
| Pi2 verify n=2048 | 5.76 s | 1.29 s | 4.5x |
| Pi2 commit n=2048 | 22.2 s | 19.7 s | 1.1x |

Two notable consequences:

- The lattice Pi2 prover at n = 2048 (2.41 s) now costs only ~1.3x the
  raw modular matrix multiplication itself (1.88 s) — proving is
  approaching the cost of computing.
- The n = 2048 prover crossover vs structured Alg-6 batching moves from
  t ~ 46-50 to **t ~ 150-190** (prove-only; `368/t < 2.4`), and from
  t ~ 15-16 to **t ~ 22** all-in with commitments. The commit kernel saw
  little gain (it was already column-parallel and is closer to
  compute-bound); it is the next lattice target.

## Tier 1 — specified, next up

Pairing prover:

1. **Precomputed affine SRS + direct blst MSM.** `multi_exp` converts
   projective points per call; storing `powers` in affine once and using
   the affine-input Pippenger avoids repeated batch conversions.
   Expected 1.3-2x on MSM-heavy paths. Acceptance: self-test + identical
   proofs at fixed seeds.
2. **Delayed-fold IPA prover.** Round messages L_j/R_j computed as MSMs
   over the *original* SRS windows with fold-coefficient-adjusted scalar
   vectors, never materializing or point-folding the bases (~n^2 full
   scalar-mults replaced by Pippenger additions). Expected 2-4x on the
   projection proofs; the KZG quotient MSM then dominates. Risk: medium
   (transcript-identical but heavy restructure); lock with fixed-seed
   proof-equality tests.
3. **GPU MSM backend (ICICLE-class), `--msm-backend` flag.** 10-50x on
   MSM; only worthwhile after (1)-(2) set the CPU baseline.
4. **Streaming witness batch prover** (unchanged from the roadmap): gates
   the t = 1024 Table-3 RAM replication.

Lattice prover:

1. **Commit kernel: ternary add/sub specialization + deeper blocking.**
   Commitment randomness is ternary, so `G*rho` is pure add/sub of u64
   rows (no multiplies); combine with two-level cache blocking (tile
   over width as well as vectors). Expected 2-4x on the commit phase,
   which is now the dominant lattice cost at n >= 1024.
2. **CDT/Karney Gaussian sampler** (replaces ~10-iteration window
   rejection): ~5-10x on sampling, which is ~15-25% of the wave prover.
3. **Bimodal Gaussian masking** (BLISS-style): halves sigma at equal
   rejection rate or drops M from 2.76 toward ~1.4 at equal sigma.
   Touches the ZK argument — requires re-deriving Lemma 6.3 constants;
   do only with the report's Section 6 math re-checked.
4. **Pi1 Algorithm-6-style claim aggregation.** The Pi1 relation is
   linear in the hidden matrices, so t same-shape claims (shared public
   A) aggregate under small per-repetition batch coefficients into one
   proof. Norm surcharge multiplies beta by ~t*2^b: at q = 2^61 - 1 this
   supports t <= ~16-32 (constraint C2); larger t needs the two-limb
   modulus (2^89 - 1) or Route R. Pi2's product gate cannot batch this
   way (per-claim masks are one-time pads); its linear openings can,
   for a ~30-40% saving at most.

## Tier 2 — design work

1. **Route R ring lift (lattice).** `R_q = Z_q[X]/(X^d + 1)`, d = 128:
   exponentially large challenge set, r -> 1. Divides lattice prover,
   verifier, and proof size by ~30-60x simultaneously (KB-scale proofs,
   ~0.1 s verification). The one design point: applying a general A over
   the ring in Pi1 (negacyclic-block or trace techniques, ALS20/LNP22).
   This is the highest-leverage item in the whole plan.
2. **LaBRADOR-style folding (lattice).** True cross-claim batch proofs
   and sublinear proof size; subsumes Algorithm-6-style aggregation.
3. **Pairing-side commitment alternatives.** The n^2 curve-op floor is
   inherent to committing the witness on curve points; assess
   sumcheck-based matmul (Thaler/zkLLM-style) as the pairing track's own
   escape hatch for prover cost, at the price of different (non-hiding
   by default) machinery.

## Measurement discipline

Every tier-0 item was validated by: (a) backend self-test (valid and
tampered cases), (b) the full repository test suite, (c) before/after
benchmarks on the same machine recorded in this file. Tier 1 items must
additionally lock transcript equality at fixed seeds where the
optimization claims to be schedule-only.
