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
- [ ] U1 — lattice-estimator attempt (clone into tools/, try plain
      python3; record outcome either way).
- [ ] U2 — scripts/estimator_run.py: core-SVP model (Chen delta(b),
      0.292b/0.257b), MSIS l2 at k_Z = kappa*128 x N_Z, MLWE primal uSVP
      at knapsack dim N_Z - (kappa+msg_r)*128 ternary; frozen points +
      kappa +-2 / N_r +-8 sweep; q31 + q46; results/estimator_*.txt.
- [ ] U3 — docs/zkmatrix-poc/ESTIMATOR_NOTE.md: methodology (what ran vs
      modeled), tables, per-shape verdicts, model-vs-estimator movement,
      downstream costs of any recommended movement, freeze-check rows
      affected.
- [ ] U4 — final: script re-run clean, python suite green, PROGRESS final.

## Decisions

- Fast-forward instead of cherry-pick: branch was strict ancestor of the
  perf tip; Route R sources required by the task only exist at the tip.
- beta conventions: all chain betas are l2 bounds (sigma/bound/beta from
  route_r_params.py); MSIS is modeled in l2 at exactly those bounds.
