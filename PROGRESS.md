# Proof-debt tranche (U-P) — PROGRESS

Branch: worktree-agent-aadc19230c8a43022, reset to 3ca80ff (parent tip).
Lane: docs only (Q4_LEMMAS.md, AUTOMORPHISM_GATE_DESIGN.md new appendix,
SOUNDNESS_REFERENCE.md grade/pointer updates, PROGRESS.md,
scripts/zk_lemma_check.py). NO .rs changes.

## Key finding (drives everything below)

The unmasked quadratic garbage images are PROVABLY not ZK — not merely
"formal lemma owed". Reason: the response z reveals the whole mask
(y = z - c rho given rho), so conditioned on the transcript the mask
images Y_i = A2 z_i - c t2_i + c x_i carry NO residual entropy; every
head image is a deterministic function of (publics, z, c, x). Exact
leak per twisted quad claim: the triple (Q(x), Lambda_a, Lambda_b)
where Q is the claim's quadratic form VALUE over the ring and
Lambda_a/b are known-coefficient linear functionals (coefficients
P = c t2 - A2 z, verifier-computed). For the committed-executions gate
this includes L(x) = -D sum conj(s_i) v_j C[i][j], from which C is
generically recoverable by linear algebra (128 coordinate equations vs
rows*cols unknowns). Q4.3c's "for generic x simulation goes through"
is WRONG (it treats Y as fresh entropy — invalid once z is revealed).
R1 (3 committed pads per twisted/ct quad claim, 2 per untwisted) fixes
it with a clean MLWE-only HVZK proof.

Second win: Q4.4' can be partially discharged with a self-contained
coordinate-wise direct-witness lemma (per-row miss <= 1/2 when some
|b*_j| > 2*y_bound; 2^-rows total), no integer lift, no c-bar on the
witness — beats the coded SLACK_OP budget ~5x at the frozen q46 point.

## Plan / status

- [x] Read all four sources; derived identities.
- [x] U-P0: scripts/zk_lemma_check.py (all checks pass). COMMITTED.
- [x] U-P1: Q4.3 rewrite (Q4.3d leak, Q4.3e gate-leaks-C, regrades,
      Q4.3c' retraction). COMMITTED.
- [x] U-P2: R1 hardening spec (Section R1 in Q4_LEMMAS.md). COMMITTED.
- [x] U-P3: Appendix B.2 in AUTOMORPHISM_GATE_DESIGN.md. COMMITTED.
- [x] U-P4: Q4.4c discharged + Q4 audit + summary table. COMMITTED.
- [x] U-P5: SOUNDNESS_REFERENCE.md updates (3.2, 4.5, 4.7, 8, changelog);
      42-test suite green (140s). COMMITTED.

ALL DELIVERABLES DONE.

## Decisions

- Leak lemma validated numerically before writing (zk_lemma_check.py).
- R1 spec: pads live in g-group message slots (existing machinery);
  sigma(c)-coefficient pads committed pre-conjugated (conj(m)) so the
  standard virtual opening supplies sigma(c)*m — matches the Q4.3c
  post-merge design note. No new challenges; new hash EDGES only.
- Section 7 of SOUNDNESS_REFERENCE is NOT edited (it documents the
  shipped protocol); R1's draft challenge-edge rows live in the R1
  spec section of Q4_LEMMAS.md, to be moved into Section 7 when the
  engine tranche lands.
