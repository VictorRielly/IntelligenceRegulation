# U-AG2 tranche ledger — aggregation DESIGN round (Greyhound adapt)

Branch: perf/zk-batch-optimizations, opened at 379e34f (2026-07-27).
Spec: the U-AG verdict (AGGREGATION_LITERATURE.md Section 8, adopted in
PROGRESS_UAG.md FINAL): adapt Greyhound — family (c) PCS reroute as the
architecture (a few global lattice polynomial commitments per tensor;
claim structure collapsed to batched MLE-evaluation claims by the house
masked sumcheck/GKR engine; Greyhound-class evaluation proofs,
LaBRADOR-compressed), family (b) folding as the cross-layer accumulator,
family (e) optional endgame wrap only. This round is the M4-pattern
DESIGN step (literature -> design -> build): paper + Python spikes, NO
Rust engine changes, no production serializer. Exit sheet = the Section
8.1 obligations O-1..O-9; this round leads with the two load-bearing
unknowns, O-1 (parameters) and O-3 (claim-class reduction), and collects
their fallout for O-2/O-4..O-9.

Standing constraints (inherited, non-negotiable):
- Z1 privacy: any design that re-exposes per-wave right-hand sides
  undoes WAVE_SHARE_MASKING_DESIGN — the reroute must subsume Z1, not
  leak around it (AGGREGATION_LITERATURE Section 6.1).
- Numbers only from repo-recorded sources (PROOF_BYTE_LEDGER.md, the
  LKP/freeze rows, PROGRESS_US.md P3-EXIT, PROGRESS_UZ1.md IA-4) or
  from the verified refs in AGGREGATION_LITERATURE Section 10; every
  new landing constant flagged [MODEL] until measured.
- codex-audit-* directories read-only.
- Fallback trigger (Section 8 runner-ups): if O-1 fails at D=128/q31 or
  O-3 hits an obstruction, the recorded fallback is family (d) via
  concrete BaseFold pricing — record the failure precisely, do not
  improvise a different architecture.

## Lanes (two parallel agents, docs+spike only, both in worktrees)

- Agent DA (O-1 parameters, WORKTREE wt-uag2-params): NEW
  docs/zkmatrix-poc/AGGREGATION_PARAMS_DESIGN.md + spike
  scripts/greyhound_params_spike.py. Global-commitment layout per
  tensor (two-tier Ajtai at D=128/q31; CRS sizing; C2-cap re-derived
  for the global shape); Greyhound + LaBRADOR security re-derivation
  at our ring (challenge operator norms, recursion slack absorbed into
  the C2/C3 parameter chains — the Section 1.2 frictions, now on the
  critical path); the O-2 byte-model skeleton its parameters imply.
  Verdict row: does the (c) architecture CLOSE at our ring, at what
  parameters, at what bytes/verifier [MODEL] cost.
- Agent DB (O-3 claim-class reduction, WORKTREE wt-uag2-claims): NEW
  docs/zkmatrix-poc/AGGREGATION_CLAIM_REDUCTION.md + spike
  scripts/claim_reduction_spike.py. Every ct-engine claim class — pins,
  zeta/ForcedZero, QuadRing/Hadamard, the committed-executions gate
  (THE hard case), the U-L cross-modulus link, lookup claims —
  re-expressed as MLE-evaluation claims against global per-tensor
  commitments; any class that cannot reduce is a surfaced WALL
  (residual wave structure re-imports the old bytes). Z1 masking
  compatibility argued per class (O-4 inputs).
- Orchestrator FINAL: merge DA + DB, review, reconcile the two lanes'
  assumed interfaces, decide O-1/O-3 verdicts and whether U-AG3 is a
  second design round (O-2/O-4/O-7/O-8) or the fallback path, push,
  brief Victor.

## Deliverables

- [x] DA: AGGREGATION_PARAMS_DESIGN.md + greyhound_params_spike.py —
      O-1 discharged or precisely failed; O-2 skeleton.
      DONE 2026-07-27, merged (orchestrator-reviewed: spike re-run
      15/15 with the corrected deep-recursion frontier). VERDICT:
      O-1 CLOSES-AT-THE-LINE, conditional — 2^20 layer 0.96x budget
      PASS, FFN 1.04-1.10x, verifier PASS, kill switch = O-7
      slack-composition lemma; BaseFold boundary recorded (doc 6.3).
- [x] DB: AGGREGATION_CLAIM_REDUCTION.md + claim_reduction_spike.py —
      O-3 reduction table complete; walls surfaced; O-4 inputs.
      DONE 2026-07-27, merged 740152c (orchestrator-reviewed: spike
      re-run 25/25; CR-L2's number-theoretic hinge — q ≡ 113 mod 256,
      ord 16, v2(q^16-1)=8 via LTE — independently re-derived and
      confirmed). VERDICT: O-3 CLOSES, no walls, fallback NOT pulled;
      gate retires via twist-on-points; details in the DB status
      section below and the doc's executive verdict.
- [x] FINAL (orchestrator): merged, reviewed, verdicts recorded,
      U-AG3 direction decided, pushed, Victor briefed.
      DONE 2026-07-27 — see the FINAL section below (R-1..R-8
      reconciliation; U-AG3 direction: D-1 encoding decision + O-7 +
      O-2 lead, recommendation pending Victor).

## Agent DB status (wt-uag2-claims) — LANE COMPLETE

- done: BOTH deliverables landed.
  docs/zkmatrix-poc/AGGREGATION_CLAIM_REDUCTION.md — complete O-3
  design doc: reduction lemmas CR-L1..CR-L6, code-enumerated
  inventory C1-C13 reconciled vs docs (deltas d1-d3, no undocumented
  class found), per-class reductions CR-1..CR-10, claim-count +
  batching arithmetic (O-2 feed), FS table CRB-N1..N5, Z1/ZK
  per-class O-4 handoff. scripts/claim_reduction_spike.py — 25/25 OK
  ~15 ms, every reduction leg with a tamper negative.
- **VERDICT: O-3 CLOSES — no walls; the family (d)/BaseFold fallback
  trigger is NOT pulled.** The committed-executions gate (the flagged
  hard case) REDUCES BY RETIREMENT: the matmul statement becomes the
  textbook degree-2 sumcheck (CR-1), and the general conj-twisted
  claim form reduces via twist-on-the-public-point (CR-2) — the tie
  obstruction is Sigma-engine-specific and has no counterpart.
  REDUCES: C1-C5, C7, C9. REDUCES-WITH-COST: C8 (link; unit-scoped,
  dense-xi kernel priced, tensor-scale boundary recorded). DISSOLVES:
  C6 (zeta — load-bearing on IA-O1-4 dense packing), C10 (waves/
  pads). RETIRED: C11-C13.
- for the orchestrator/DA reconciliation: six interface assumptions
  IA-O1-1..6 (doc Section 0.3) — IA-O1-4 (dense value packing) is the
  single most important one to confirm (the zeta dissolution rides
  it; its violation costs one packing-image sumcheck per packed
  tensor, priced, not a wall). O-2 feed: +27-40 KiB [MODEL] new
  sumcheck transcript; 1-3 eval proofs/layer. O-4/O-7 obligation
  lists in doc Sections 11/12.3.
- deliverable checkbox left for the orchestrator (GA precedent).
- commits: e80c617, 6383cfd, 1c15d5c, 49924a1, 3d3b437, 57e29f7
  (+ this close-out).

## Log

- 2026-07-27: tranche opened at 379e34f, same session as the U-AG
  close. Victor: "continue to the next steps on both" (this + the song
  lane). DA + DB launched in parallel worktrees.
- 2026-07-27 (DB): lane started; reading + code enumeration done;
  status section above is the lane's checkpoint surface.
- 2026-07-27 (DB close): lane survived one mid-run watchdog kill
  (resumed from its 4-commit checkpoint — the resumable discipline
  paid again), finished, orchestrator-reviewed and merged (740152c).
  DA lane still in flight (also crash-resumed once, from an
  uncommitted-spike checkpoint; commit discipline re-imposed).
  FINAL reconciliation (esp. IA-O1-4 dense packing vs DA's layout)
  waits on DA.

### Agent DA lane log (worktree wt-uag2-params)

- 2026-07-27 (run 1, crashed on API drop; run 2 resumed at 683a373):
  DONE: read-first set complete (params.rs verified: D=128,
  q31=2147483249, quinary |C|=2^297.2, op conc 20.8, C2/C3 chains;
  ledger inventory + budgets; ESTIMATOR_NOTE core-SVP conventions);
  external refs verified this session: Greyhound abstract (ePrint
  2024/1293: 53 KB @ N=2^30, O(sqrt N) verifier), LaBRADOR abstract
  (2022/1341: 58 KB @ 2^20 R1CS), full protocol structure via the two
  zksecurity expositions (Greyhound three-round w/z/t-hat + outer
  commitment; LaBRADOR fold/outer-commit/JL recursion, JL slack
  sqrt(128/30), z 2-part decomposition, r ~ cbrt schedules) plus the
  2026-04-30 zksecurity finding that LaBRADOR soundness collapses in
  small-slot-field NTT-friendly rings (our 8-slot GF(q^16) = 2^496
  survives the exact failure mode — quotable external check).
  greyhound_params_spike.py committed (683a373): 15/15 anchor
  self-checks OK, incl. exact reproduction of the ct_engine C2 wave
  cap at 134 commitments (sigma 2^17.3) — the cap the reroute vacates.
  DECISIONS so far: two super-commitments (data + blind segments);
  e0=1..2 digit bases at q31 (gamma_z ~ 2^20.9-21.4); no Gaussian
  masking anywhere in the aggregate opening layer (derived: sigma =
  12*gamma_z blows past q31 — ZK must ride masked tensors + blind
  segment, O-4 interface); three slack-composition readings carried
  (per-level / exact-digit / compounded) — the O-7 lemma decides.
  NEXT: fix the spike's depth-loop bug (recursion capped at 1 level —
  current 21-159x OVER table is NOT the derivation's verdict), re-run
  the frontier, then AGGREGATION_PARAMS_DESIGN.md sections (a)-(e),
  one commit each.
- 2026-07-27 (run 2, LANE COMPLETE at b842636): spike depth bug fixed
  (d72540f — deep recursion restored, g-garbage term, byte-optimal
  stop bases, JL/exact-digit FS split); AGGREGATION_PARAMS_DESIGN.md
  landed in 5 commits (dd8c9e7, c820acc, 88f9723, ceb82fb, b842636).
  O-1 VERDICT: CLOSES-AT-THE-LINE, conditional — 2^20 layer 252,868 B
  = 0.96x budget PASS; FFN 272,824-289,080 B = 1.04-1.10x OVER (sound
  configs; descent pair is 39% and GKR-owned); verifier 0.14-0.93 s
  PASS; prover +2-4%; top MSIS 132-140 bits [core-SVP]; post-FS
  2^-211/-217 [MODEL]. BaseFold NOT triggered; precise trigger
  boundary recorded (doc 6.3: compounded slack lemma AND exact-digit
  failure -> one fold level only, 41.6 MB floor). O-2 skeleton + O-7
  export list + I-1..I-8 DB interface assumptions in the doc.
  DA deliverable checkbox: ready for orchestrator review.

## FINAL (orchestrator) — reconciliation, verdicts, tranche close

Merged: DB 740152c, DA (this merge). Both spikes re-run by the
orchestrator (25/25, 15/15). Verdicts adopted: **O-3 CLOSES (no
walls); O-1 CLOSES-AT-THE-LINE, conditional on the O-7
slack-composition lemma. The family (d)/BaseFold fallback is NOT
triggered; its precise boundary is AGGREGATION_PARAMS_DESIGN 6.3.**

Interface reconciliation (DB IA-O1-1..6 x DA I-1..I-8):

- R-1 CONFIRMED (layout): DA's two super-commitments with segment
  addressing satisfy DB's IA-O1-1, PROVIDED segment boundaries are
  bit-block (power-of-two) aligned in the Statement v3 manifest —
  build-round requirement. I-2 confirmed: no claim class needs
  per-tensor commitments (DB's reductions are layout-parametric).
- R-2 **PARTIAL VIOLATION, and the lead U-AG3 question (D-1)**:
  IA-O1-4 (dense value packing) is violated for Y/UP/Z — DA's layout
  keeps them slot-form (16 coeff/el, straight from ledger encodings);
  X is dense. As drawn: DB 6.3's packing-image sumcheck activates per
  slot-packed tensor (priced there) and zeta's dissolution stands
  only for dense tensors. THE COUNTER-LEVER: dense re-encoding of
  Y/UP/Z would cut committed rings ~13x (FFN 2,157,768 -> ~170k),
  shrink the eval proof by roughly the sqrt of that, likely flip
  DA's FFN 1.04-1.10x overage to PASS, and restore full zeta
  dissolution — at the cost of re-deriving the slot-form semantics
  the H3 layer assumes. Neither lane derived this; it is not decided
  here. U-AG3 leads with it.
- R-3 CONFIRMED (points): both lanes converge on one-common-point
  batch opening (IA-O1-3 = I-1); DB's 8 slot-orbit points fold
  inside the GKR engine before the commitment interface. Merge-block
  count arithmetic (DA: >~4 point families erodes the line) = O-2.
- R-4 CONFIRMED w/ split domains (challenges): field-scalar RLC
  inside the GKR engine (DB), quinary ring challenges at the
  commitment interface (DA 4.1 lemma, per-slot-injective; I-4).
  Composition of the two knowledge-error accountings is owed to O-7
  — restated, not absorbed (both lanes flagged it independently).
- R-5 CONFIRMED (linear interface): I-5 is DB's architecture by
  construction — quadratics sumcheck-reduce before the interface.
- R-6 CONFIRMED (ZK): DA's derived no-Gaussian-masks constraint
  (I-6) is compatible with DB's three exposure surfaces; the ZK
  story = masked sumcheck + T_blind segment + eval-proof ZK layer.
  Joint export to O-4 (simulator + R3 battery analogue owed).
- R-7 CONFIRMED (q46): both lanes exclude q46 from the target path
  (IA-O1-6 = I-7); legacy-arm bytes join O-2 only if a legacy arm
  survives the build round.
- R-8 OPEN ARITHMETIC (bytes): DA's Section 5 assumes today's single
  descent pair (I-8); DB adds +27-40 KiB [MODEL] of new sumcheck
  transcript (~8-10 instances). Reconciled honest headline at FFN:
  ~1.04-1.25x pre-lever, likely under 1.0x if R-2's dense
  re-encoding lands. The reconciled closed-form model is O-2's first
  task in U-AG3.

U-AG3 DIRECTION (recommendation, pending Victor): second design
round, led by (1) D-1 — the Y/UP/Z dense-vs-slot encoding decision
(R-2; the byte lever AND the zeta story), (2) O-7 — the
extraction-slack composition lemma (the kill switch: per-level
holds everything above; compounded kills the architecture at this
ring), (3) O-2 — the reconciled byte model to R1 discipline incl.
the pass-vs-layer budget scope decision; then O-4 (ZK under I-6)
and O-8 (cross-layer folding — mandatory under a per-pass budget
reading). O-5/O-6 models carried in DA's doc; O-9 watch items
standing (Orthus, toolkit 2026/1289, BaseFold pricing, SuperNeo).

TRANCHE CLOSED 2026-07-27.
