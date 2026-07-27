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
- [x] DB: AGGREGATION_CLAIM_REDUCTION.md + claim_reduction_spike.py —
      O-3 reduction table complete; walls surfaced; O-4 inputs.
      DONE 2026-07-27, merged 740152c (orchestrator-reviewed: spike
      re-run 25/25; CR-L2's number-theoretic hinge — q ≡ 113 mod 256,
      ord 16, v2(q^16-1)=8 via LTE — independently re-derived and
      confirmed). VERDICT: O-3 CLOSES, no walls, fallback NOT pulled;
      gate retires via twist-on-points; details in the DB status
      section below and the doc's executive verdict.
- [ ] FINAL (orchestrator): merged, reviewed, verdicts recorded,
      U-AG3 direction decided, pushed, Victor briefed.

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
