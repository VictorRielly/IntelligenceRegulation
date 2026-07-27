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

- [x] EA: AGGREGATION_ENCODING_DESIGN.md + aggregation_byte_model_
      spike.py — D-1 decided w/ derivation; O-2 model reconciled;
      scope recommendation; FFN verdict.
      DONE 2026-07-27, merged (orchestrator-reviewed: spike re-run
      21/21 incl. exact reproduction of DA's six totals). D-1
      recommendation DENSE (adoption at FINAL); FFN 1.02x
      ledger-unit / 1.11x complete-layer, descent pair the named
      owner; scope rec PER-PASS -> U-AG4 = folding design round.
- [x] EB: AGGREGATION_SOUNDNESS_COMPOSITION.md + slack_composition_
      spike.py — O-7 settled or precisely conditioned.
      DONE 2026-07-27, merged (orchestrator-reviewed: spike re-run
      36/36 incl. reproduction of the refuted compounded rule).
      VERDICT: PER-LEVEL HOLDS — architecture stands, fallback NOT
      engaged; four DA corrections (R-EB1 T_cap=33, R-EB3 missing
      ct-aggregation FS term, R-EB4 e<=7 caps, kappa 11); branch
      preference inverts to EXACT-DIGIT (2^20 0.991x PASS, FFN
      1.081x). SC-L4/SC-L6 = top Phase 2.5 review targets.
- [x] EC: AGGREGATION_ZK_DESIGN.md + aggregation_zk_spike.py — O-4
      design-closed or precise gap.
      DONE 2026-07-27, merged (orchestrator-reviewed: spike re-run
      14/14 incl. the floor-recovery demo and the norm/byte kill
      grids). VERDICT: design-CLOSES with a PRECISE GAP — surfaces
      1+2 close with exact simulators; surface 3's LaBRADOR-floor
      bare witness (~79k coords/proof) is unmaskable at q31 under
      I-6 + budget (the digit wall). Posture adopted at FINAL below.
- [x] FINAL (orchestrator): merged, reviewed, decisions adopted,
      U-AG4 direction, pushed, Victor briefed.
      DONE 2026-07-27 — see the FINAL section below.

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

## FINAL (orchestrator) — decisions adopted, tranche close

All three lanes merged; all three spikes re-run by the orchestrator
(21/21, 36/36, 14/14). Decisions ADOPTED:

1. **D-1: DENSE value encoding for Y/UP/Z** (EA's derivation:
   zero added claims, 151x witness reduction; reinforced by EB —
   dense widens every soundness margin ~1.9 bits — and by EC's new
   privacy axis: a ~13x smaller witness against the same fixed
   ~79k-coordinate floor image). Slot form retained nowhere in the
   committed layout; the slot FIELD engine (GF(q^16)) stays.
2. **Configuration: EXACT-DIGIT** — triple-mandated: EB soundness
   (fewest [MODEL] flags, no heuristic JL constants, no window) +
   EB bytes post-corrections (2^20: 259,904 B = 0.991x PASS; FFN
   283,392 B = 1.081x) + EC ZK (deletes the JL cleartext
   projections outright). The 512-JL branch remains recorded as
   sound-but-dominated.
3. **Budget scope: PER-PASS** (EA's three contract anchors), with
   per-layer 262,144 B kept as the U-AG-B1 engineering gate. Pass
   at 8.92 MiB = 35.7x -> O-8 instance folding is MANDATORY.
4. **O-7 recorded: PER-LEVEL HOLDS** (SC-L4 on C-alg/C-ground/
   C-cap/C-msis). The PARAMS 6.3 fallback trigger is CLOSED on both
   horns, subject to Phase 2.5 review of SC-L4/SC-L6 (top targets).
   EB's corrections SUPERSEDE DA's tables where they overlap
   (R-EB1 T_cap=33 sampled-cap rule, R-EB3 K-draw restructure
   recommended over t>=7, R-EB4 floor bases e<=7, kappa 11); DA's
   doc gets a status-header supersession block in the build round
   (the WSMD precedent) — not edited this tranche.
5. **O-4 posture: the M4/R1-precedent NON-ZK deployment label at
   the aggregate layer + the one-proof-per-witness deployment
   rule**, both freeze-row candidates for the build round. The leak
   is exactly confined (simulator complete-minus-R; R's dimension
   and accumulation law stated; AZB-1..9 battery spec certifies
   confinement). Five escapes priced; E4 wrap (~450-500 KiB/layer)
   is the only currently-actionable full-ZK path and joins O-8's
   design space as the endgame option; AZ-T1 (a ZK opening for
   balanced-digit Ajtai at q~2^31 within ~100 KB?) goes to external
   review as a sharply-posed open question.

**U-AG4 DIRECTION (recommendation, pending Victor): the folding
design round (O-8)** — the family-(b) accumulator folding sumcheck
INSTANCES (not just openings; EA's 5.7x floor), fold-message bytes
and the 32-layer wire model, under two standing constraints: the
fold must not enlarge EC's floor image (privacy axis), and AZ-L4(a)
FS-ordering governs every fold challenge. E4-wrap endgame pricing
rides along as the ZK-relief option. Build-round obligation queue
(for U-AG-B1, after U-AG4): E-O1..E-O3, R-EB1..R-EB4 freeze rows,
AZB battery + extension wiring, exact-digit plumbing, Q4/SR
transcriptions, O-5/O-6 models to measurement.

TRANCHE CLOSED 2026-07-27.

## Log

- 2026-07-27: tranche opened at 93a6957 immediately after the U-AG2
  close, on Victor's console go. EA + EB + EC launched in parallel
  worktrees.
- 2026-07-27 (EA close): lane finished first, orchestrator-reviewed
  and merged. Its EB/EC exports (dense norm chain; softened-but-
  still-fatal compounded floor; junk channel gone) are in
  AGGREGATION_ENCODING_DESIGN Section 6 — EB/EC were briefed to
  derive at DA's published parameters and mark encoding-parametric
  rows, so FINAL owns folding these exports in. EB + EC still in
  flight.
