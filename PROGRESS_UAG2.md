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

- [ ] DA: AGGREGATION_PARAMS_DESIGN.md + greyhound_params_spike.py —
      O-1 discharged or precisely failed; O-2 skeleton.
- [ ] DB: AGGREGATION_CLAIM_REDUCTION.md + claim_reduction_spike.py —
      O-3 reduction table complete; walls surfaced; O-4 inputs.
- [ ] FINAL (orchestrator): merged, reviewed, verdicts recorded,
      U-AG3 direction decided, pushed, Victor briefed.

## Log

- 2026-07-27: tranche opened at 379e34f, same session as the U-AG
  close. Victor: "continue to the next steps on both" (this + the song
  lane). DA + DB launched in parallel worktrees.

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
