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

- 2026-07-27: docs read (ENCODING 3/4/6, CLAIM_REDUCTION lemmas+10,
  PARAMS 2/3/5, SC-L4 + R-EB rows, AZ-L4/4.4, ZK_GAP 6-7, A1, PBL,
  three prior spikes). **F-IF1 COMMITTED** in
  docs/zkmatrix-poc/AGGREGATION_FOLDING_DESIGN.md Section 2: the
  fold is INDEX-EXTENSION FOLDING (IXF), flat arity 32 — 5
  layer-index MLE variables extend every instance family; zero fold
  messages; norm law = one-time sqrt(32) absorbed at e0 (act group
  e0=2 exact-digit gate / weights e0=1); one eval proof per
  commitment group (P2 split hook built in); descent pair folds to
  ONE at dw+5, dt unchanged. Sequential/tree RLC folding priced and
  REJECTED (>=176 KB messages + per-step norm growth + new
  extraction surface). kel(dw,9) = 2dw^2+11dw+235 exact fit to the
  4 recorded points [MODEL].
- FLAG for orchestrator: recorded per-layer artifacts (DA 5.2 /
  EA 3.3 / EB 2.4) price NO weight-domain opening (activation-only
  witnesses) — latent assumption made explicit in F-IF1.4; EB's
  corrected byte rows run on the SLOT 31-bit witness (never composed
  with EA's dense encoding) — FA's spike does that composition with
  anchors on both sides.
- 2026-07-27 (later): **LANE COMPLETE.** Spike
  scripts/aggregation_folding_spike.py 33/33 (DA/EA/EB anchors
  reproduced incl. the 1,500,496 B floor and EB's kappa-11 totals;
  toy IXF folds verify with tampers rejected; AZ-L4 A1/A2 early-draw
  negative caught both directions; naive-product cross-term negative
  both directions; norm laws measured — stacked sqrt slope 0.49 over
  m=4..512, 12-fold RLC chain under the linear certified bound,
  +10.0 vs +2.5 bits at 32 folds; decompose-refold reset shown).
  AGGREGATION_FOLDING_DESIGN.md complete: FD-L1..L4, sequential fold
  rejected+priced, norm tables, byte tables, AZB-7 hash edges,
  verdict, FB/FC exports, obligations F-O1..F-O5.
- **VERDICT: floor BEATEN.** Folded Tier N pass (FFN complete):
  activation-only 352,948 B = 0.337 MiB (4.25x under the 1,500,496 B
  floor; EA-comparable unit); RECOMMENDED W-C two-proof layout
  (committed weights, P2-ready, 8B-viable) 505,272 B = 0.482 MiB
  (2.97x under); W-B merged 356,020 B (7B-only — dies at 8B, F-N4).
  2^20 ledger-unit pass 294,136 B. Per-layer amortized 15,789 B =
  0.060x of the B1 gate. Tier Z preview on the W-C base: P2
  ~0.65-0.71 MiB, P3 ~0.82-0.94 MiB — inside A1's 0.5-2 MiB class
  (FB owns the freeze number).
- Findings for FINAL: F-N2 (weight-group opening infeasible at the
  per-level gate — exact-digit branch load-bearing), F-N3 (robust
  act e0=2 costs zero bytes — adopted), F-N4 (8B weight-group
  headroom 0.05 b — relaxed-e0 line must be adopted for the 8B rung,
  obligation F-O4), floor dims at pass scope are 90,880/93,952 B
  (R-EB4-corrected, larger than EC's 64-80k class — export note to
  FB), plus the weight-domain latent-assumption flag above.
- Deliverables checkbox left for the orchestrator.

## Agent FB status (wt-uag4-privacy)

- IN FLIGHT. Read-phase complete: ledger, ZK_GAP_OPTIONS (full),
  TARGET_CONTRACT A1, AGGREGATION_ZK_DESIGN (full),
  AGGREGATION_CLAIM_REDUCTION (CR-L4 + Sec. 11),
  AGGREGATION_ENCODING_DESIGN (full), AGGREGATION_PARAMS_DESIGN
  (full), WSMD Sec. 3, PROOF_BYTE_LEDGER Sec. 0. F-IF1 is FINAL
  (IXF flat-32, both sibling lanes merged): FA's
  AGGREGATION_FOLDING_DESIGN.md read in full (bases: act-only
  352,948 B / W-C 505,272 B / 2^20 pass 294,136 B; floor
  correction 710/734 rings = 90,880/93,952 cleartext B), FC's
  AGGREGATION_FOLDING_SOUNDNESS.md read at the FB-relevant
  sections (Sec. 8 R-FC rows, Sec. 10 exports to FB). No
  [F-IF1 PENDING] rows needed — building directly on the final
  interface.
- **LANE COMPLETE (2026-08-06).** Deliverables landed:
  docs/zkmatrix-poc/AGGREGATION_FOLD_PRIVACY_PRICING.md +
  scripts/fold_privacy_pricing_spike.py (15/15 OK, < 1 s).
- Verdict: fold/mask lemma HOLDS for IXF (FP-L1: one floor per
  group, 14-29x less floor exposure than 32 unfolded proofs,
  accumulation law unchanged; FP-L2: mask-then-fold by
  construction, group-map hash edge = the one new privacy edge;
  fences FP-C1 cleartext-per-step folds, FP-C2 W-B has no partial
  privacy). Tier Z surcharges RE-DERIVED at the corrected floors
  (+272,640 / +281,856 B per masked group floor — the +176-240 KB
  class retired). Folded Tier Z pass (FFN, W-C): P3 = 1,063,096 B
  = 1.014 MiB, P2 = 788,792 B = 0.752 MiB = Tier N + 283,520 B,
  P1-label = 508,600 B, P1-strict = 781,240 B; 2^20 rig pass
  Tier Z = 576,056 B. **A1 freeze candidate: 1,114,112 B = 1.0625
  MiB** (P3 scope; conditions F-Z1 corner / F-Z2 extraction at
  masked bound / F-O2 kel). P2 (a) VERIFIED (FP-L3 + spike
  positive/negative), (b) canary specified as AZB-11, (c)
  amortization CONFIRMED (once per pass, W-C-conditional).
  Unfolded 14-16 MiB class reproduced from formulas; E4 endgame =
  one wrap per pass per private group (14.0-15.9x vs unfolded).
- Cross-checks vs FA: preview Tier Z rows superseded (floor
  correction explains +0.05-0.09 MiB); FA's FFN instance
  transcript independently re-derived and matches; AZB numbering
  collision flagged (FA's "AZB-7" pair -> proposed AZB-10, canary
  AZB-11); A1 interim 512 KiB/layer line inconsistent with its own
  corridor top (516.75 KiB) — retire at freeze.
- Deliverables checkbox left for the orchestrator.

## Agent FC status (wt-uag4-soundness)

- 2026-07-27: lane OPEN. House docs read (SC composition in full incl.
  R-EB1..R-EB4 rows; PARAMS Sections 1-4/3.6; AZ-L4; literature
  Section 2 + refs 6/7/9; Q4 style; SOUNDNESS_REFERENCE target line =
  the H-07 min() note, 128-bit class). Fetching primary sources
  (2024/257, 2025/247, + Neo 2025/294) into references/.
- PRIMARY SOURCES READ: LatticeFold 2024/257 (Dec 15 2025 revision,
  Wayback route — ePrint bot-check again) read IN FULL: Thms
  3.1/3.2/3.3 + extractor + Lemma 3.7 + Section 3.3 small-modulus
  challenge set (slot-diagonal, size q^tau) + Section 4 CCS variant +
  App. B. LatticeFold+ 2025/247 (Aug 9 2025 revision) read IN FULL:
  monomial range proof (Lemmas 4.2-4.7), Pi_cm extraction (Thm 4.3 /
  Lemma 4.10 with the mu*|S|-union + two-parallel-sumcheck artifact,
  Remark 4.9), folding Thms 5.1-5.3 + Eq. (28), App. B tensor-of-rings
  (sumchecks over K, folding over R_q — the house split exactly).
  Neo 2025/294: soundness core read (Thm 1 invertibility, Defs 14/15,
  Lemma 3, the phi-restricted composition Thm 5 — the linearization
  seam is NOT plain-composable; noted for FA). Key early findings:
  LF Lemma 2.3 hypothesis at our ring IS house C0'/LS18 with the same
  1.30x margin; LF's range arm = SC-L3-class exact pinning (slack 1);
  fold-challenge entropy capped by q^16 = 2^496 pigeonhole (the
  small-slot axis); FS of the fold left as FUTURE WORK by LF Remark
  3.3 — the house PSS/SC-L5 transfer must carry it. F-IF1 not landed
  yet (checked). Writing AGGREGATION_FOLDING_SOUNDNESS.md now.
- LANE COMPLETE: AGGREGATION_FOLDING_SOUNDNESS.md (AFS-L0..L8,
  F-C1..F-C6, small-slot margins re-derived +92/+286 bits, budget
  2^-219.5 post-FS / margin 91.5 b [MODEL], FS rows FSB-1..4 + F-N1)
  + folding_soundness_spike.py 10/10 OK (<5 s, ~10 MB RSS). Two
  substantive findings beyond the brief: (1) the l_inf/l2 norm-shape
  gap — LF theorems costed naively fail 13/48 of the envelope at
  q31; house l2 re-derivation AFS-L6 recovers 2.96 b/row, 48/48
  PASS; (2) spike-caught inversion — [LF+] two-parallel sumchecks
  are REQUIRED at our ring (mu|S|-union does not cancel, single form
  2^-116 post-FS FAILS). F-IF1 LANDED mid-lane (0aeae08, IXF flat-32,
  LatticeFold shape REJECTED by FA): hostile-read + VERIFIED (V1-V6;
  spike check 10 confirms FA's e0 negative check and headroom chain
  within 0.1 b); new lemma AFS-L8 (SC-L6 at two commitment groups)
  discharged; R-FC1..R-FC4 filed (none architectural: R-FC1 LF
  rejection-reason imprecision — rejection survives on corrected
  grounds; R-FC2 knife-edge pass headrooms < 1 b need per-group
  freeze rows; R-FC3 "SC-L6 verbatim" needs AFS-L8 at two groups;
  R-FC4 slot-completeness not restated in the binding interface).
  VERDICT: extraction COMPOSES — IXF via SC-L4 at pass shape +
  AFS-L8 (folding costs ~0 bits); RLC shape composes under
  F-C1..F-C6 (archived, governs eval-proof-internal folds +
  streaming variant). Deliverables checkbox left for orchestrator.

## Log

- 2026-07-27: tranche opened at 0dd8aab on Victor's console go
  ("Let's continue with the tranche from option B"). FA + FB + FC
  launching in parallel worktrees.
