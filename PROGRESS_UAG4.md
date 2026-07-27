# U-AG4 tranche ledger — aggregation design round 3 (folding, O-8) + Option B pricing

Branch: perf/zk-batch-optimizations, opened at 0dd8aab (2026-07-27).
Victor approved: "Let's continue with the tranche from option B"
(console, same day as the Option B adoption). Spec: the U-AG3 FINAL
direction (PROGRESS_UAG3.md) as amended by the Option B decision
(ZK_GAP_OPTIONS.md Section 7, TARGET_CONTRACT.md Amendment A1):
third DESIGN round (M4 pattern, paper + Python spikes, NO Rust
engine changes) building the family-(b) accumulator that folds
sumcheck INSTANCES across the 32-layer pass (EA's 5.7x floor makes
instance folding mandatory), and pricing the Option B / partial-
privacy modes on top of it. PRIMARY deliverables (Section 7 item 4):

1. the folded Tier N pass number and the folded **Tier Z pass
   number** — the latter FREEZES Amendment A1's binding pass-level
   budget (target class 0.5-2 MiB/pass [MODEL] going in);
2. the **P2 split-proof pricing** (ZK_GAP_OPTIONS Section 6
   questions (a)-(c));
3. the **fold/mask interaction**: the fold must not enlarge the
   floor image (the EC export, AGGREGATION_ZK_DESIGN 4.4/5.5), and
   AZ-L4 ordering governs every fold challenge (mask-then-fold);
4. folding SOUNDNESS at our ring: LatticeFold-class extraction
   transcribed to kappa 11 / partially-split GF(q^16) / q31
   balanced digits, composed with SC-L4's per-level result;
5. E4-wrap endgame pricing rides along as the ZK-relief option.

Standing constraints (inherited, non-negotiable):
- U-AG2/U-AG3 verdicts stand: O-3 CLOSES (AGGREGATION_CLAIM_
  REDUCTION.md), O-1 CLOSES-AT-THE-LINE (AGGREGATION_PARAMS_
  DESIGN.md), O-7 PER-LEVEL HOLDS (AGGREGATION_SOUNDNESS_
  COMPOSITION.md SC-L4), O-4 design-closes with the precise gap
  (AGGREGATION_ZK_DESIGN.md). D-1 = DENSE encoding adopted;
  config = EXACT-DIGIT (triple-mandated); scope = PER-PASS with
  per-layer 262,144 B as the B1 engineering gate.
- Option B is adopted (TARGET_CONTRACT Amendment A1): Tier N
  262,144 B/layer is P0/non-ZK-label ONLY; Tier Z interim
  <= 512 KiB/layer unfolded; the binding pass-level Tier Z number
  is frozen at THIS tranche's FINAL. Privacy modes P0-P3 are
  per-deployment declarations, never silent degradations.
- I-6 is HARD: no Gaussian-masked openings anywhere in the
  aggregate layer at q31 — ZK rides T_blind + masked sumcheck only.
- Z1 privacy discipline continues: nothing the old waves masked may
  re-appear on the wire.
- The one-proof-per-witness rule stands (activation floors bounded
  by construction; weight floors accumulate — the Section 6
  asymmetry).
- EB's corrections SUPERSEDE DA's tables where they overlap:
  R-EB1 T_cap=33 sampled-cap rule, R-EB3 K-draw restructure,
  R-EB4 floor bases e<=7, kappa 11.
- Numbers only from repo-recorded sources or refs verified
  in-session, cited inline; [MODEL] flags on unmeasured constants;
  codex-audit-* read-only.
- Design round: paper + Python spikes only, no Rust engine changes.
  Spikes stay modest (single-run < ~10 min, < ~2 GiB RSS — the box
  is 15 GiB and OOMs under concurrent heavy runs).

## Interface note (F-IF1)

Agent FA owns the fold shape and must COMMIT an early interface
section (F-IF1: what folds, the accumulator relation, fold
arity/schedule, challenge draws and their FS ordering, the
norm-growth law, the fold-message byte skeleton) before completing
the full design, so FB/FC can consume it mid-flight from FA's
worktree branch (read-only). Until F-IF1 lands, FB/FC work their
fold-independent items and mark fold-parametric rows [F-IF1
PENDING]; the orchestrator reconciles at FINAL. Changes to F-IF1
after first publication go through the orchestrator (R-1..R-8
precedent).

## Lanes (three parallel agents, docs+spike only, all in worktrees)

- Agent FA (O-8 fold design, WORKTREE wt-uag4-folding): NEW
  docs/zkmatrix-poc/AGGREGATION_FOLDING_DESIGN.md + spike
  scripts/aggregation_folding_spike.py. The family-(b) accumulator
  over the reduced protocol's instance population (the per-layer
  claim/artifact list of AGGREGATION_ENCODING_DESIGN Section 3):
  what folds (descent pairs — the 36-40% named owner — GKR/lookup
  instances, matmul/Hadamard instances, range arms, eval-proof
  openings), the accumulator relation, arity/schedule across 32
  layers, challenge draws (kappa 11, R-EB3 K-draw form), the
  norm-growth law per fold step, fold-message bytes and the
  32-layer wire model, the folded Tier N pass number vs EA's 5.7x
  floor (~1,500,496 B). AZ-L4(a) FS ordering on every fold
  challenge (hash-edge table rows). F-IF1 committed EARLY.
  Verdict row: folded pass number + does instance folding beat
  the 5.7x floor.
- Agent FB (fold/mask + Option B pricing, WORKTREE wt-uag4-privacy):
  NEW docs/zkmatrix-poc/AGGREGATION_FOLD_PRIVACY_PRICING.md + spike
  scripts/fold_privacy_pricing_spike.py. The fold/mask interaction
  lemma (folded floor image stays ONE proof's ~79k-coordinate
  image — the EC export made precise; mask-then-fold vs
  fold-then-mask, extending AZ-L4); the folded Tier Z pass number
  (= FA's folded Tier N + ONE floor surcharge +176-240 KB class +
  mask deltas — the Amendment A1 freeze candidate); P2 split-proof
  questions (a) terminal-claim split onto the two commitments
  under CR-L4 (derive, don't assume), (b) the weight-independence
  canary (AZB battery leg spec certifying the bare activation
  floor carries no weight-dependence), (c) weight-side masked
  proof amortization under folding (once per pass?); the P1
  bounded-leak label template per reference shape (dim(z_L)
  constraints, rank margin); E4-wrap endgame pricing under
  folding. Verdict row: Tier Z folded number + P2 price class.
- Agent FC (folding soundness, WORKTREE wt-uag4-soundness): NEW
  docs/zkmatrix-poc/AGGREGATION_FOLDING_SOUNDNESS.md + spike
  scripts/folding_soundness_spike.py. LatticeFold (ePrint
  2024/257) + LatticeFold+ (2025/247) extraction theorems READ IN
  FULL and transcribed to house Q4/SC style AT OUR RING
  (X^128+1, q = 2^31-399, q≡113 mod 256, partially-split
  GF(q^16) slots, kappa 11, balanced digits, R-EB3 K-draws) —
  where their assumptions hold/fail here (incl. the 2026-04-30
  small-slot-field break precedent applied to the fold challenge
  set); the norm-growth/extraction-slack law per fold step
  composed with SC-L4 per-level (fold levels + LaBRADOR levels —
  does per-level still hold under a 32-fold?); the fold FS
  soundness rows (joint with AZ-L4(a)); the total knowledge-error
  budget for a folded pass vs the house target; verification of
  FA's F-IF1 when it lands (file discrepancies as R-FC rows — the
  EB precedent found 4 real errors). Verdict row: extraction
  COMPOSES / conditions / fails.
- Orchestrator FINAL: merge FA+FB+FC, review + re-run spikes,
  reconcile [F-IF1 PENDING] rows, FREEZE Amendment A1's Tier Z
  pass number in TARGET_CONTRACT.md, record the P2/P1 pricing in
  ZK_GAP_OPTIONS.md, decide next round (build round U-AG-B1 queue:
  E-O1..E-O3, R-EB1..R-EB4 freeze rows, AZB battery + extension
  wiring, exact-digit plumbing, Q4/SR transcriptions, O-5/O-6
  models to measurement), push, brief Victor.

## Deliverables

- [ ] FA: AGGREGATION_FOLDING_DESIGN.md + aggregation_folding_
      spike.py — fold designed, F-IF1 published, folded Tier N
      pass number vs the 5.7x floor.
- [ ] FB: AGGREGATION_FOLD_PRIVACY_PRICING.md + fold_privacy_
      pricing_spike.py — fold/mask lemma, folded Tier Z number
      (A1 freeze candidate), P2 (a)-(c) priced, P1 label
      template, E4-wrap pricing.
- [ ] FC: AGGREGATION_FOLDING_SOUNDNESS.md + folding_soundness_
      spike.py — extraction transcribed at our ring, SC-L4
      composition settled or precisely conditioned, F-IF1
      verified.
- [ ] FINAL (orchestrator): merged, reviewed, A1 Tier Z number
      FROZEN, pricing recorded, next round decided, pushed,
      Victor briefed.

## Agent FA status (wt-uag4-folding)

- (lane opens here)

## Agent FB status (wt-uag4-privacy)

- (lane opens here)

## Agent FC status (wt-uag4-soundness)

- 2026-07-27: lane OPEN. House docs read (SC composition in full incl.
  R-EB1..R-EB4 rows; PARAMS Sections 1-4/3.6; AZ-L4; literature
  Section 2 + refs 6/7/9; Q4 style; SOUNDNESS_REFERENCE target line =
  the H-07 min() note, 128-bit class). Fetching primary sources
  (2024/257, 2025/247, + Neo 2025/294) into references/.

## Log

- 2026-07-27: tranche opened at 0dd8aab on Victor's console go
  ("Let's continue with the tranche from option B"). FA + FB + FC
  launching in parallel worktrees.
