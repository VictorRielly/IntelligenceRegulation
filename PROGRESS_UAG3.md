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

## Agent EA status (wt-uag3-encoding) — LANE COMPLETE

- done: BOTH deliverables landed.
  docs/zkmatrix-poc/AGGREGATION_ENCODING_DESIGN.md — D-1 consumer
  enumeration S1-S8 (code-cited) + soundness derivation + the
  recommendation; O-2 reconciled byte model (R8-a..d, two statement
  scopes, DA overlap machine-checked, DB band-checked); pass-vs-layer
  scope analysis; verdict + claim grades + EB/EC exports.
  scripts/aggregation_byte_model_spike.py — 21/21 self-checks,
  imports DA's spike read-only and reproduces its six verdict totals
  exactly before printing anything.
- **D-1 DECIDED (recommendation to FINAL): DENSE value encoding for
  Y/UP/Z; slot form retained nowhere; IA-O1-4 CONFIRMED; R-2
  closed.** Every load-bearing slot consumer is a Sigma-engine
  artifact (S1-S6); the survivors consume the slot FIELD, not the
  packing; dense adds ZERO claims (the packing-image class only
  ties packed-to-dense and nothing packed remains). Width finding
  F-2: slot idempotents force 31-bit coefficients vs dense 8/15-bit
  — witness 151x down, FFN e0 relaxes 1->4/2->5, C2' headroom
  0.20->0.82 b, top-MSIS 132.6->141.4 b. Honest negative F-4: R-2's
  sqrt-law is REFUTED (eval proof is recursion-floor-dominated;
  dense buys ~15-25 KiB, not sqrt(13)x).
- **O-2 verdicts (dense, per-level + 512-row JL):** 2^20 ledger-unit
  242,128 B = 0.92x PASS (completed slot form 1.00x OVER — dense is
  what keeps the PASS alive); FFN ledger-unit 266,832 B = 1.02x
  FAILS by 1.8%; FFN complete-layer 292,240 B = 1.11x (band
  1.09-1.12x); descent pair 105,664 B = 36-40% is the one named
  owner of the gap (GKR/O-8). Named risks D-R1 (range-arm
  rho-sharing) / D-R2 (extra eval proofs ~136 KiB each ->
  budget-fatal; E-O2 one-batched-opening rule).
- **Scope recommendation (adoption at FINAL): PER-PASS** — the
  contract text pins it (three anchors incl. the 150-KB/pass
  tightness flag); pass = 8.92 MiB = 35.7x; O-8 floor 5.7x even
  with perfect descent/eval folding -> the (b) accumulator must
  fold INSTANCES; keep per-layer 262,144 B as the B1 engineering
  gate; U-AG4 = folding design round.
- exports recorded (doc Section 6): EB — dense norm chain,
  compounded L=2 now hosted, kill-switch byte floor 41.6 MB ->
  1.23 MB (4.7x, still architecture-fail; boundary restatement
  owed); EC — junk channel gone, 3 fewer masked instances than
  slot+image, T_blind unchanged, entries = surface-(ii) population.
- deliverable checkbox left for the orchestrator (GA/DB precedent).
- commits: 88a9dfe, 03b6847, 154e6a6, bdd60d2, 899a4cd, acafee6
  (+ this close-out).

## Log

- 2026-07-27: tranche opened at 93a6957 immediately after the U-AG2
  close, on Victor's console go. EA + EB + EC launched in parallel
  worktrees.
