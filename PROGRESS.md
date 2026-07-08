# Q5 estimator sign-off — progress

Branch: worktree-agent-aa0f8aa0d4a9fb1dc (fast-forwarded from stale base
7a3e7a0 to perf/zk-batch-optimizations tip 32b13fb — the branch had zero
unique commits, so the ff is clean; my deliverables sit on top).

File lanes (CREATE only): docs/zkmatrix-poc/ESTIMATOR_NOTE.md,
scripts/estimator_run.py, results/estimator_*.txt. tools/ clones stay
UNCOMMITTED (clone commands recorded in the note instead).

## Units

- [x] U0 — setup: fast-forward to 32b13fb, read the design/params sources,
      PROGRESS.md started.
      Frozen instances confirmed from freeze_check (ring_matmul.rs:2620):
      Pi2 2048^3 e=2 (kappa 8, N_r 40), e=3 (8, 40), e=4 (9, 40), FFN
      512x4096x11008 e=4 (9, 57, msg_r 32), prototype opening (kappa 8,
      N_r 26, msg_r 2, plain worst-case chain, ring_lattice.rs). Moduli:
      q8_31 = 2147483249, fallback q8_46 = 70368744176561.
- [x] U1 — lattice-estimator RUNS here: cloned to tools/lattice-estimator
      (commit 3e48ef4, NOT committed), imports under the pure-Python
      sage.all float shim inside estimator_run.py + one disclosed
      log1p monkey-patch of prob.amplify (double-precision underflow;
      disk code untouched). Shim VALIDATED against the estimator's own
      doctest anchors (Kyber512 usvp beta 406 rop 2^143.8; SIS l2 toy
      beta 61 2^47.0; Dilithium2 MSIS linf beta 427 2^152.2 — all exact).
- [x] U2 — scripts/estimator_run.py: [core-SVP] model (Chen delta(b),
      0.292b/0.257b), MSIS l2 at k_Z = kappa*128 x N_Z, MLWE primal uSVP
      at knapsack dim N_Z - (kappa+msg_r)*128 ternary; frozen points +
      kappa +-2 / N_r +-8 sweep; q31 + q46; plus the [lattice-estimator]
      leg (MATZOV + ADPS16, usvp + bdd) on all 10 anchor points.
      Results: all frozen q31 points PASS 128-bit classical (min side is
      MSIS: 136.7-153.0 core-SVP; 162.8-178.1 MATZOV); quantum 0.257b
      dips below 128 at e=2/e=3/FFN (125.9/120.3/126.2). ADPS16
      estimator numbers match core-SVP within 1 block everywhere.
      C3's delta0=1.0037 = Chen b=445 = a ~130-bit classical line.
      C4's 11.7-line is ~60 bits conservative (MLWE never binds).
      Integral-kappa n_sec at Pi2 e=4 (1920 < model d_lwe 2035) still
      gives 177.8 bits — bookkeeping gap, harmless.
- [x] U3 — docs/zkmatrix-poc/ESTIMATOR_NOTE.md committed: methodology
      with per-figure source tags, frozen-point tables (q31 + q46),
      margin structure, the C3=130-bit-line / C4=~190-bit-line model
      comparison (movement 0%), the two caveat findings costed (quantum
      kappa+1: commit +2.4-4.2%, proof +1.4-2.1%; integral-C4 N_r 41 at
      Pi2 e=4: proof +1.9%), freeze-check impact NONE, native-Sage
      reproduction block (values verified against the shim run
      value-for-value).
- [x] U4 — final: full script run clean end-to-end ([lattice-estimator]
      VALIDATED), python suite green (41 tests OK, 124 s), PROGRESS
      final. tools/lattice-estimator remains uncommitted by design;
      clone commands are in the note Section 8.

## Final verdicts (q8_31, frozen)

| shape | classical (min side = MSIS) | quantum | 128-cl |
|---|---|---|---|
| Pi2 2048^3 e=2 (8,40)  | 143.1 core-SVP / 168.9 MATZOV | 125.9 | PASS |
| Pi2 2048^3 e=3 (8,40)  | 136.7 / 162.8 | 120.3 | PASS |
| Pi2 2048^3 e=4 (9,40)  | 151.3 / 176.8 | 133.1 | PASS |
| FFN e=4 (9,57)         | 143.4 / 169.3 | 126.2 | PASS |
| prototype (8,26)       | 153.0 / 178.1 | 134.7 | PASS |

Frozen point HOLDS; movement 0%; q46 fallback candidates also PASS.
Sign-off grade: estimator-validated (shimmed CPython run of the real
lattice-estimator, doctest-anchor validated); native-Sage rerun is the
optional last-residue confirmation.

## Decisions

- Fast-forward instead of cherry-pick: branch was strict ancestor of the
  perf tip; Route R sources required by the task only exist at the tip.
- beta conventions: all chain betas are l2 bounds (sigma/bound/beta from
  route_r_params.py); MSIS is modeled in l2 at exactly those bounds.
