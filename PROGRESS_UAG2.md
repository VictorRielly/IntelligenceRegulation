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

## Agent DB status (wt-uag2-claims)

- done: read-first set complete (AGGREGATION_LITERATURE 0/3/6/8/9,
  SOUNDNESS_REFERENCE, AUTOMORPHISM_GATE_DESIGN + B.1/B.2,
  WAVE_SHARE_MASKING_DESIGN, M4_LOOKUP_DESIGN 3.x, Q4_LEMMAS style,
  PROOF_BYTE_LEDGER counts; code enumeration: ct_engine.rs claim
  structs + splitter/pads, lookup.rs pin layer, link.rs, sigma.rs,
  gkr_masked.rs, ring_matmul.rs wave loop).
- next: AGGREGATION_CLAIM_REDUCTION.md in units (framework + inventory
  -> gate -> quadratics -> linear/zeta -> link/lookup -> counts +
  Z1 table + verdict), then claim_reduction_spike.py.
- decisions so far: (1) reductions written PARAMETRIC in DA's layout
  (explicit "Interface assumptions for O-1" section); (2) the two
  load-bearing reduction lemmas are the power-point lemma (tensor
  weights = shifted MLE evaluation) and the slot-evaluation lemma
  (ring claims = evaluation claims at order-256 points of GF(q^16);
  Galois twists move the PUBLIC point, not the committed data) —
  ord(q mod 256) = 16 checked, consistent with the k = 8 split.

## Log

- 2026-07-27: tranche opened at 379e34f, same session as the U-AG
  close. Victor: "continue to the next steps on both" (this + the song
  lane). DA + DB launched in parallel worktrees.
- 2026-07-27 (DB): lane started; reading + code enumeration done;
  status section above is the lane's checkpoint surface.
