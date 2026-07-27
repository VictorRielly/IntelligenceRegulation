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

## Agent EC status (O-4, ZK layer) — wt-uag3-zk

Units (commit after each):
- [x] U1: read-in complete (CR Sec 1/10/11, PARAMS 2.4/2.5/7, WSMD 3,
      Q4.7-9, SR 7, PROGRESS_UAG2 FINAL) + external refs verified
      (2026/1289 toolkit, 2024/1293 Greyhound, 2022/1341 LaBRADOR)
      — 2026-07-27. Verified in-session: Greyhound wire objects
      (w = a^T G S, z = S c, verifier's 3 equations, w committed as
      v = D w-hat in the LaBRADOR handoff) and LaBRADOR level
      messages (u1/u2 outer commits, JL p = Pi s in cleartext,
      g_ij = <s_i,s_j> / h_ij garbage, bare final witness) from the
      two zksecurity expositions (read in full); ePrint abstracts
      2024/1293 + 2026/1289 confirmed; both PDFs bot-blocked (same
      as DA's session) — LNP22 internals carried [S10]/[MODEL].
      Early finding shaping the lane: neither published protocol
      carries ANY ZK measure; the composed proof's cleartext tail
      (JL projections + final bare witness) is a deterministic
      witness image — the surface-3 analysis will center on it.
- [x] U2: AGGREGATION_ZK_DESIGN.md Sections 0-1 (scope + leakage
      inventory, JL + exact-digit variants, encoding-parametric rows)
- [x] U3: Section 2 (Surface 1: mask-budget extension to
      matmul/Hadamard/packing instances vs T_blind [MODEL])
- [x] U4: Section 3 (Surface 2: terminal blinding — aggregate-only-pin
      generalized; I-1/I-4 interaction)
- [x] U5: Section 4 (Surface 3: eval-proof ZK under I-6 — toolkit vs
      house pads DECIDED with reasons; costs to O-2)
- [x] U6: Section 5 (the SIMULATOR, WSMD Sec-3 style, graded; the
      fold-round FS-ordering lemma extending WSMD 3.4)
- [x] U7: Section 6 (R3 battery analogue SPEC) + Section 7 (verdict,
      exports/imports for EA, honest scope)
- [x] U8: scripts/aggregation_zk_spike.py (self-checking N/N OK) +
      output recorded in the doc
- [x] U9: final report to orchestrator; ledger updated

Log:
- 2026-07-27 (U2-U7): AGGREGATION_ZK_DESIGN.md complete (Sections
  0-8). Lane verdict: O-4 design-CLOSES surfaces 1-2 and surface 3's
  committed internals; PRECISE GAP at the eval-proof floor — the
  final bare witness (~2^16.3 base coords/proof) is a deterministic
  witness image, unmaskable (norm-or-byte dead: masked response
  256-700 KB vs 79,872 B bare) and unsanitizable (the digit wall,
  AZ-T1) at q31 under I-6 + the byte budget. Toolkit 2026/1289
  REJECTED at tensor scale (in-ring hits the I-6 eviction; out-of-
  ring hits CR 12.2's cross-modulus wall or q46's 1.35x). ZK-mandated
  config = EXACT-DIGIT (deletes the JL cleartext class; +10,112 B at
  FFN). New lemmas AZ-L1a/b (Q4.7 extension incl. shared-challenge
  joint counting), AZ-L2a/b (selector-extension terminal blinding),
  AZ-L3 (floor-leak characterization), AZ-L4 (fold-round FS
  ordering); obligations AZ-O2 (joint rank, the one closure-
  threatening leg), AZ-O4, AZ-O5; battery spec AZB-1..9
  (confinement, not denial). Non-ZK deployment label + one-proof-
  per-witness rule proposed as freeze-row candidates. NEW for D-1:
  dense re-encoding worsens the residual-leak ratio ~1-2 orders (the
  privacy axis of the encoding decision). E4 (budget relief to
  ~450-500 KiB) is the only currently-actionable full-ZK path.
- 2026-07-27 (U8): aggregation_zk_spike.py landed — 14/14 OK, ~0.6 s,
  stdlib, GF(q31). Two of its certificates caught real drafting bugs
  (eq-kernel truthiness, mask-constant redundancy) — recorded in the
  doc's Section 8 notes.
- 2026-07-27 (U9): lane COMPLETE; checkbox for the orchestrator.

## Log

- 2026-07-27: tranche opened at 93a6957 immediately after the U-AG2
  close, on Victor's console go. EA + EB + EC launched in parallel
  worktrees.
