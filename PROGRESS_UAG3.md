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

## Agent EB status (wt-uag3-soundness) — O-7 slack composition — LANE COMPLETE

- done: BOTH deliverables landed.
  docs/zkmatrix-poc/AGGREGATION_SOUNDNESS_COMPOSITION.md — the O-7
  composition doc: SC-L0..SC-L6 in Q4 transcription style, THE lemma
  (SC-L4) proved by downward induction over the published skeleton
  (LaBRADOR Thm 5.1 + Remark 5.2 + Lemma 3.7, PSS Thm 4.1/Eq 18,
  Greyhound Thm 4.1 — all three ePrint PDFs READ IN FULL this session
  via Wayback-archived copies; the bot check blocks live PDFs), house
  constants substituted and spike-checked.
  scripts/slack_composition_spike.py — 36/36 OK, <1 s, arithmetic +
  MC only (says so in its header).
- **VERDICT: O-7 SETTLES PER-LEVEL — the architecture stands; the
  PARAMS 6.3 BaseFold boundary is NOT engaged.** Mechanism: (i)
  relaxation factors clear ALGEBRAICALLY per level (LS18/C0'
  invertibility — they never accumulate as algebra); (ii) every
  level's extracted-witness norm is RE-GROUNDED by that level's own
  norm statement (modular-JL Lemma 4.2 with its q/C1 window — margins
  +5.8 bits min at DA's shapes — or exact-digit residue pinning at
  slack exactly 1); (iii) one slack factor sigma per level enters
  that level's MSIS bounds (Remark 5.2 / PSS Eq 18 "additional
  slack"), never a product over depth; (iv) knowledge errors ADD,
  linear in Q under FS (PSS). Compounded is the correct arithmetic
  only for fold-only recursion, the NS22 garbage optimization under
  FS, or broken-window levels — none ours; fenced by R-EB1/2/4.
- four quantitative findings (all with fixes, none architecture-
  fatal): (1) LaBRADOR's ct-aggregation term q^-ceil(128/31) =
  2^-155 is MISSING from all house accounting and post-FS lands at
  2^-87 — FAILS the target at q31 unless t >= 7 reps (+18-21 KiB) or
  the K-draw restructure (~free, recommended) [R-EB3]; (2) the house
  quinary set has NO op-norm cap and conc 20.8 is BELOW the true
  op-norm median (MC p50 = 34.2) — extraction constants need a
  sampled cap, T_cap = 33 at ~3 attempts/challenge [R-EB1]; (3) DA's
  e = 8-10 floor bases give binding bounds beta_top up to 2^34.1 > q
  (vacuous MSIS) — deep bases cap at e <= 7 [R-EB4]; (4) with all
  corrections (kappa 10 -> 11), the branch preference INVERTS:
  exact-digit is now cheaper AND cleaner (2^20: 259,904 B = 0.991x
  PASS; FFN 1.081x) vs 512-JL (1.088x / 1.194x).
- for the orchestrator: exports in doc 5.4 (R-EB1..R-EB4, freeze
  rows, DA-table corrections to reconcile at FINAL — this lane did
  not edit DA's doc); Phase 2.5 review list in doc 5.3 (SC-L4
  transfer + SC-L6 first-written treatment at top); EA direction
  note: dense re-encoding strictly WIDENS every margin here (~1.9
  bits) — nothing in the lane resists D-1.
- deliverable checkbox left for the orchestrator (GA precedent).
- commits: 85442f1, 641798d, 7658390, 238b601, 7b2ea39, 27ded03,
  c133ba8, 736d61c (+ this close-out).

## Log

- 2026-07-27: tranche opened at 93a6957 immediately after the U-AG2
  close, on Victor's console go. EA + EB + EC launched in parallel
  worktrees.
