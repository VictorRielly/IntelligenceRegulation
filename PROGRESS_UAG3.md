# U-AG3 tranche ledger — aggregation design round 2 (encoding, soundness, ZK)

Branch: perf/zk-batch-optimizations, opened at 93a6957 (2026-07-27).
Victor approved: "Go ahead and start on U-AG3" (console, same day as
the U-AG2 close). Spec: the U-AG2 FINAL recommendation
(PROGRESS_UAG2.md): second DESIGN round (M4 pattern, paper + Python
spikes, NO Rust engine changes) closing the three items that decide
whether the Greyhound reroute ships: D-1 (the Y/UP/Z dense-vs-slot
encoding decision — U-AG2's R-2 reconciliation finding), O-7 (the
extraction-slack composition lemma — the architecture's kill switch),
and O-4 (the ZK layer under the no-Gaussian-mask constraint), with
O-2's reconciled byte model riding the D-1 lane and O-8's cross-layer
interaction recorded but not fully designed (defer full folding design
to the next round if scope demands).

Standing constraints (inherited, non-negotiable):
- U-AG2 verdicts stand: O-3 CLOSES (AGGREGATION_CLAIM_REDUCTION.md),
  O-1 CLOSES-AT-THE-LINE conditional (AGGREGATION_PARAMS_DESIGN.md).
  The BaseFold fallback boundary is AGGREGATION_PARAMS_DESIGN 6.3 —
  it can only be pulled by O-7 landing compounded AND exact-digit
  failing; nothing in this round improvises a different architecture.
- Interface reconciliation R-1..R-8 (PROGRESS_UAG2.md FINAL) is the
  contract between lanes; changes to it go through the orchestrator.
- I-6 is HARD: no Gaussian-masked openings anywhere in the aggregate
  layer at q31 — ZK rides T_blind + masked sumcheck only.
- Z1 privacy discipline continues: nothing the old waves masked may
  re-appear on the wire (the reduced protocol has no waves; the three
  exposure surfaces are AGGREGATION_CLAIM_REDUCTION Section 11).
- Numbers only from repo-recorded sources or refs verified in-session,
  cited inline; [MODEL] flags on unmeasured constants; codex-audit-*
  read-only.

## Lanes (three parallel agents, docs+spike only, all in worktrees)

- Agent EA (D-1 + O-2, WORKTREE wt-uag3-encoding): NEW
  docs/zkmatrix-poc/AGGREGATION_ENCODING_DESIGN.md + spike
  scripts/aggregation_byte_model_spike.py. The D-1 derivation both
  lanes skipped: what the slot form of Y/UP/Z actually serves under
  the NEW engine (enumerate every consumer of slot structure from
  code + docs), whether dense re-encoding is sound and what it costs
  (packing-image claims vs ~13x ring reduction), the recommended
  encoding per tensor; then the O-2 reconciled closed-form byte model
  (DA skeleton + DB instance list + the encoding decision) at both
  reference shapes vs 262,144 B, the pass-vs-layer budget scope
  analyzed with a recommendation, the ~2x pass levers priced, and the
  O-8 folding interaction recorded (full folding design NOT in
  scope). Verdict row: FFN layer PASSES/FAILS at the recommended
  encoding, with the byte table.
- Agent EB (O-7, WORKTREE wt-uag3-soundness): NEW
  docs/zkmatrix-poc/AGGREGATION_SOUNDNESS_COMPOSITION.md + spike
  scripts/slack_composition_spike.py. The kill-switch lemma:
  extraction/knowledge-error composition across LaBRADOR recursion
  levels at our ring — per-level vs compounded settled by proof (Q4
  transcription style), the recursive-FS composition (PSS pattern),
  and the RLC-batching-over-partially-split-rings knowledge error
  that BOTH U-AG2 lanes restated to O-7 (DA 4.4, DB 12.3). Verdict
  row: per-level HOLDS (architecture stands) / compounded (fallback
  boundary engages) / partial with exact conditions.
- Agent EC (O-4, WORKTREE wt-uag3-zk): NEW
  docs/zkmatrix-poc/AGGREGATION_ZK_DESIGN.md + spike
  scripts/aggregation_zk_spike.py. The aggregated-transcript
  simulator in WSMD Section 3 style over the reduced protocol's
  three exposure surfaces (masked sumcheck rounds, terminal
  evaluation values, eval-proof internals); the ZK layer on the
  Greyhound/LaBRADOR evaluation proof under I-6 (toolkit ePrint
  2026/1289 composition vs house pad-polynomial masking — pick with
  reasons); mask-budget extension to the new matmul/Hadamard
  instances; the fold-round FS-ordering lemma extending WSMD 3.4;
  the R3 rank/recovery battery analogue SPEC (implementation is
  build-round scope). Verdict row: ZK CLOSES at design level /
  precise gap.
- Orchestrator FINAL: merge EA+EB+EC, review, adopt the D-1
  encoding decision and the budget-scope reading, record O-7's
  verdict against the fallback boundary, decide U-AG4 (build round
  vs folding design round), push, brief Victor.

## Deliverables

- [ ] EA: AGGREGATION_ENCODING_DESIGN.md + aggregation_byte_model_
      spike.py — D-1 decided w/ derivation; O-2 model reconciled;
      scope recommendation; FFN verdict.
- [ ] EB: AGGREGATION_SOUNDNESS_COMPOSITION.md + slack_composition_
      spike.py — O-7 settled or precisely conditioned.
- [ ] EC: AGGREGATION_ZK_DESIGN.md + aggregation_zk_spike.py — O-4
      design-closed or precise gap.
- [ ] FINAL (orchestrator): merged, reviewed, decisions adopted,
      U-AG4 direction, pushed, Victor briefed.

## Agent EA status (wt-uag3-encoding) — D-1 + O-2 lane

- done: read-first set complete (PROGRESS_UAG2 FINAL R-1..R-8;
  AGGREGATION_PARAMS_DESIGN 2/5/6/7 + greyhound_params_spike re-run,
  15/15 OK, per-level q31 schedules captured for cross-check;
  AGGREGATION_CLAIM_REDUCTION 0.3/2/6/10/11; PROOF_BYTE_LEDGER unit
  costs + 3.1 allocation; TARGET_CONTRACT budget wording; slot
  consumers from source: ct_engine.rs quads/slot machinery,
  link.rs crt_coord_rows/derive_link_zeta/link_claims_tgt_slot,
  lookup.rs slot_pin_weights + pin/E4 layer, ring_matmul.rs
  slot_pack + U-K8 header ("Y lives ONLY slot-packed so the
  downstream Hadamard can consume it"), WSMD 0.1/1.2,
  SOUNDNESS_REFERENCE 8.3, M4_LOOKUP_DESIGN 3.1/3.4).
- key findings so far (to be derived in the doc + spike):
  (1) every slot-form consumer is either a Sigma-engine artifact
  (Hadamard-as-ring-mult, E1 projection reads, E2 zeta junk
  pinning, slot_pin_weights adapter) or encoding-agnostic (lookup
  descent consumes VALUES; kappa:=Y fusion is K-field structure,
  not H3 packing) — dense re-encoding of Y/UP/Z looks sound with
  NO packing-image claim (nothing slot-packed remains to tie);
  (2) slot idempotents force full 31-bit coefficients, dense
  values are 8-15 bit — the norm-chain relaxation is therefore
  bigger than the 13x ring count alone (l0 drops too);
  (3) DA's eval proof is near-shape-invariant (deep-recursion
  floor), so the sqrt-law expectation from R-2 needs testing —
  savings come from fewer levels + relaxed e0, spike to settle.
- next: scripts/aggregation_byte_model_spike.py (reconciled model,
  both shapes x both encodings, dense norm-chain re-derivation,
  self-checked vs DA overlap rows), then
  docs/zkmatrix-poc/AGGREGATION_ENCODING_DESIGN.md sections with a
  commit each: D-1 enumeration+derivation, O-2 model, pass-vs-layer
  scope, verdict + exports to O-4/O-7.
- decisions pending: none adopted here — D-1 recommendation and
  scope reading go to FINAL.

## Log

- 2026-07-27: tranche opened at 93a6957 immediately after the U-AG2
  close, on Victor's console go. EA + EB + EC launched in parallel
  worktrees.
