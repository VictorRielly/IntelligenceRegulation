# U-AG-B1 tranche ledger — the aggregation BUILD round

Branch: perf/zk-batch-optimizations, opened at 867bfaf (2026-08-08).
Authority: the U-AG4 FINAL decided this round (PROGRESS_UAG4.md item
5, TRANCHE CLOSED 2026-08-06); Victor's console ask of 2026-08-07
("provide the next steps to complete a proof of concept for the zk
proofs of LLMs ... lets proceed with the most reasonable steps
forward") opens the LEDGER and its framing docs. LANE LAUNCH (the
multi-agent build round itself, with Rust engine changes) awaits an
explicit console go, per house pattern — this file is the round's
standing plan until then.

Spec: docs/zkmatrix-poc/LLM_POC_ROADMAP.md (written at open — the
PoC definition and lane grouping); obligation queue verbatim from
PROGRESS_UAG4.md FINAL item 4; contract lines from TARGET_CONTRACT.md
Amendment A1 (Tier N 262,144 B/layer P0-only; Tier Z FROZEN
1,114,112 B/pass P3/W-C, conditions F-Z1/F-Z2/F-O2 carried HERE).

This is a BUILD round: Rust engine changes are in scope (the first
since the U-AG design trench opened). Design-round constraints that
REMAIN binding: I-6 hard (no Gaussian-masked openings at q31 in the
aggregate layer — ZK rides T_blind + masked sumcheck), Z1 privacy
discipline, one-proof-per-witness rule, exact-digit config
(triple-mandated), EB corrections supersede DA tables, numbers only
from repo-recorded sources, [MODEL] flags until measured,
codex-audit-* read-only, suite + freeze-check stay green at every
merge.

## First build target

The frugal-lm 125M integration rung (PROGRESS_UAG4.md FINAL item 5):
12-layer FFN pass, shapes 512x768x2048 SwiGLU, real trained weights
from /Users/victorrielly/frugal-lm (configs/125m.yaml: n_layers 12,
d_model 768, mlp_hidden 2048), int8 per TARGET_CONTRACT Section 2
semantics. PoC-complete definition: LLM_POC_ROADMAP.md Section 1
(P2 mode, W-C layout, AZB green incl. AZB-10/11, verifier <= 2 s,
measured p50/p95, honest FFN-only scope label). Reference 7B shapes
retained for contract anchoring. The 125M-shape Tier Z pass number
must be DERIVED by this round (the frozen A1 number is the
7B-reference P3 figure) [MODEL until then].

## Lanes (proposed at open; final split at lane launch)

- BA (freeze rows + discipline, low risk, mergeable first):
  R-EB1..R-EB4 as engine freeze rows both directions; R-FC2
  per-group digit-headroom rows; E-O1..E-O3; Q4/SR transcriptions
  (AFS-L0..L8 into the house lemma docs).
- BB (engine critical path, ordered): (1) exact-digit plumbing
  (F-N2, load-bearing); (2) dense-encoding committed matmul
  statement at 512x768x2048 — closes the "largest full proof
  128x256x64" gap; multi-wave C2 handling per
  RANGE_AGGREGATION_DESIGN Phase 5; (3) 12-layer chaining under one
  statement; (4) IXF flat fold (12 layers pad to a 16 index space —
  settle against F-IF1, flagged [MODEL]); (5) masked eval-proof path
  (mask-then-fold FP-L2, sampler discipline F-Z3); (6) the canonical
  wire format (audit M-05) — budgets bind on serialized bytes.
- BC (measurement + battery): F-O1..F-O5 (F-O2 kel measurement
  unblocks an A1 freeze condition; F-O4 relaxed-e0 BEFORE any 8B
  freeze); F-Z1/F-Z2 (Phase-2.5 review with SC-L4/SC-L6); AZB
  battery + AZB-10 (IXF segment/group F5 pair) + AZB-11
  (weight-independence canary); O-5/O-6 models to measurement;
  running gates Tier N 262,144 B/layer (P0), 2^20 rig Tier Z
  576,056 B.
- Orchestrator FINAL: merges, suite green, quiesced re-measurement,
  125M-shape budget derivation recorded, A1 freeze conditions
  dispositioned, PoC exit criteria checked against Section 1 of the
  roadmap, push, brief Victor.

## Deliverables

- [x] BA: freeze rows + encoding obligations + transcriptions landed,
      suite + freeze-check green.
      DONE 2026-08-08, merged 883b1f9 (orchestrator re-run: freeze
      script exit 0 + 3/3; main suite 50/50 after merge). 85 rows
      frozen both directions; E-O1 landed + E-O1-BB/E-O2-BB/E-O3-BB
      exported; AFS corpus transcriptions in SR S10 + Q4 S9;
      findings BA-F1..F5 filed (BA-F5 fixed in roadmap same day).
- [~] BB: matmul statement at 125M shape -> 12-layer chain -> IXF
      fold -> masked path -> wire format; battery-grade tamper legs
      at each stage.
      ITEMS 1-2 DONE + 3-SKELETON 2026-08-08, merged 304df33
      (orchestrator re-run: freeze-check green w/ UAGB1 rows +
      pre-existing digests unmoved, D1 27 legs 4.19 s, D2 10 legs
      49.35 s). Exact-digit path landed (the engine's only e0=1
      path, F-BB1); FULL 512x768x2048 statement proves/verifies —
      the 128x256x64 gap CLOSED, multi-wave recipe held as-is (23
      waves at cap 131). Measured [MAC-BOX ~1T]: prove 45.2 s /
      verify 4.2 s / RSS 1.25 GiB. Counted artifact 117,396,459 B =
      447.8x Tier N, opening layer 99.8% — the number items 4-6
      exist to close; Tier N NOT met, NOT claimed. Items 4-6 remain
      OPEN (wave 2 of this round).
      WAVE-2 UPDATE: items 4-5 LANDED by lane BD at single-layer
      scope (merged e3c9825): eval proof bare 344,318 B (341x under
      wave 1, 1.313x over Tier N — pass amortization pending BE) +
      masked Tier-Z path 1,527,878 B corner-safe. Item 6 (wire
      format) still OPEN — counted convention continues.
- [x] BC: F-O/F-Z obligations dispositioned; AZB battery green incl.
      AZB-10/AZB-11; kel measured (F-O2); gates checked.
      DONE 2026-08-08 at spike scope, merged 8b2ffa8 (orchestrator
      re-run 20/20): every AZB id executable at spike level + 11
      [ENGINE PENDING - BB] specs; F-Z1 corner survives (~0.7 b),
      125M point awaits BB's schedule; F-O2 re-scoped by finding —
      kel dw~25 at 125M is one step past the recorded fit point, so
      the measurement is 7B-FREEZE-blocking, not PoC-blocking (the
      A1 condition stands, discharged at the standalone rig or BB
      stages 2-5); byte gates ride on BB's statement. PLUS the
      integration-prep win: 125M calibration VERDICT = CALIBRATES
      as-is (see merge message + M125_CALIBRATION_STUDY.md).
- [~] INTEGRATION: frugal-lm 125M checkpoint imported (int8
      calibration honest — an uncalibratable model fails its range
      facts by design), 12-layer P2 pass proven end to end, measured
      p50/p95, artifact bytes vs derived budget, brief.
      P0 HALF DONE 2026-08-10 (lane BF, merged b8a4b4b): the
      12-layer pass PROVEN on real ckpt-00009536 weights, 12/12
      layers, one v4 statement, prove 3,275 s / verify 411 s
      [MAC-BOX ~1T single-shot, not p50/p95], counted 7.38 GiB
      opening-dominated. The P2 half (masked weight group + BD's
      stack + BE's fold composed onto the pass statement, pass-level
      Tier N/Z bytes vs the derived budget, p50/p95) = WAVE 3.
- [ ] FINAL (orchestrator): reconciliation, A1 condition status,
      ledger closed, pushed.

## Sibling pillar (context, not a lane)

docs/provenance/MUSIC_PROVENANCE_POC.md opened the provenance pillar
the same day (spike PV-S1 7/7 green, scripts/music_provenance_spike.py).
It consumes this round's gadget classes unchanged and nominates the
frugal-lm-stack laundering-screen detector as the engine's second
real model (roadmap Section 6). No B1 lane owns it; its build items
are PV-S2..PV-S5 in that doc.

## Machine note (timing hygiene, this round)

This round runs on Victor's Mac (Darwin, Apple silicon, Homebrew
rust 1.96.0) — NOT the contract's CPU reference machine (the WSL2
Intel box every recorded measurement to date comes from). Every
timing this round is therefore marked [MAC-BOX, non-reference];
magnitudes and ratios only. Contract-grade numbers (p50/p95 ladder
rows) require either a reference-box pass or a dated
TARGET_CONTRACT machine-line amendment — orchestrator decision at
FINAL, not a lane decision. Byte counts and battery verdicts are
machine-independent and land at full grade.

## Lane discipline (all lanes)

- Worktrees: wt-uagb1-ba / wt-uagb1-bb / wt-uagb1-bc under
  /Users/victorrielly/, branches uagb1-ba / uagb1-bb / uagb1-bc.
- Skeleton-commit-first (the U-AG4 FB lesson), then commit early and
  often; NO blocking git inspection commands (no pagers, no -p logs
  — FB hung twice on these).
- Each lane edits ONLY its own status section below plus its own
  deliverable files; file ownership per lane brief; PROGRESS_UAGB1.md
  edits outside your section are orchestrator-only.
- Suite + freeze-check green before every lane-complete claim:
  `python3 -m unittest discover -s tests` from repo root and
  `zkmatrix-rs$ cargo build --release` both work on this box
  (baseline established at launch; see Log).
- codex-audit-* read-only; numbers cited from repo sources;
  [MODEL]/[MEASURED]/[MAC-BOX] flags per house rule.

## Agent BA status (wt-uagb1-ba)

- 2026-08-08: lane OPEN, read phase COMPLETE (ledger; roadmap S3;
  R-EB rows in AGGREGATION_SOUNDNESS_COMPOSITION.md 1.3/2.2/3.2/2.4 +
  5.4 exports; DA tables; R-FC2 + AFS-L0..L8 in
  AGGREGATION_FOLDING_SOUNDNESS.md; F-IF1.5/Section-5 headroom chain
  in AGGREGATION_FOLDING_DESIGN.md; E-O1..E-O3 in
  AGGREGATION_ENCODING_DESIGN.md 5.3; Q4/SR conventions; LKP-7/8/9
  freeze precedent in ring_matmul.rs). Both spikes re-run green on
  this box (slack_composition 36/36, aggregation_folding 33/33) and
  every R-FC2/R-EB constant re-derived by hand against them before
  pinning.
- 2026-08-08 (later): **lane COMPLETE.** All three deliverables
  landed/dispositioned; full suite 50/50 green in this worktree
  (incl. the new freeze battery and the engine freeze-check);
  everything committed to uagb1-ba.

**VERDICT ROW (BA).** FROZEN both directions, enforced by
scripts/aggregation_freeze_rows.py (85 rows) under
tests/test_aggregation_freeze.py, tabled in SC Section 7 + FD
Section 10 (dated additive sections; no historical text edited):
R-EB1 T_cap = 33 (+ diff cap 66, [MODEL] MC pins 38.43/66.77/94.34%,
~3 attempts, cost-of-no-cap 2.96 b); R-EB2 NS22-at-recursed-levels
FORBIDDEN + full r(r+1) garbage count; R-EB3 t >= 7 (t = 5 fails
post-FS) / K-draw class 496 = 16·31 ADOPTED, wire lines +2,584
B/level (t-up) and 1,036 B/level (K-draw at kappa 11); R-EB4 floor
bases e <= 7 (re-derived at floors 620-770 rings, e = 8 fails both
sigma branches), validity line 2^30.5 (= kappa-11 C3 coverage
2^30.49), realized beta_top maxima 2^29.93 (exact-digit) / 2^30.40
(JL), kappa = 11 (kappa-10 coverage 2^29.07 short; >= 128-bit
core-SVP asserted); C-win windows q/125 = 2^24.03, q/168 = 2^23.61,
JL soundness exponents -128/-256; R-FC2 class inventories (act
4,227,072/1,409,024/6,400/4,096 rings; W 33,816,576; 8B 44,040,192
[MODEL]; 2^20 pass set) and per-group headrooms — act e0 = 2 ADOPTED
+0.865 b, act e0 = 3 +0.122, act e0 = 1 vs PL gate +0.336, act
e0 = 5 NEGATIVE -1.559, W-C weight e0 = 1 +0.237, weight-vs-PL-gate
NEGATIVE (F-N2), W-B +0.103 (not recommended), 8B weight +0.047
[MODEL] (F-O4 fence), 2^20 pass +0.561, one-time law +2.5 b =
log2 sqrt(32). EXPORTED: engine wiring of every pin (derive-time
asserts + freeze-check rows, LKP pattern) to BB at aggregate-layer
build time (SC 7.1/FD 10.3); E-O1-BB (Statement v3 manifest
class/base fields + AZB-10 edge + S1-S5 retirements; acceptance =
inventory prints + negative vectors), E-O2-BB (exactly one batched
opening per group, second-opening-in-group = build error), E-O3-BB
(D-R1 rho-sharing verified with battery leg OR split priced
+143,104 B, never silent) — full acceptance criteria in
AGGREGATION_ENCODING_DESIGN.md Section 8; 8B relaxed-e0 amendment
fence to BC (F-O4, FD 10.3); roadmap Section-3 R-EB2/R-EB3 gloss fix
to FINAL (orchestrator-owned file). CORPUS GAINED: Q4_LEMMAS
Section 9 (AFS-L1..L5/L7/L8 transcribed, ids preserved, status
table, certificates-owed list) + SOUNDNESS_REFERENCE Section 10
(AFS-L0 challenge sets + pigeonhole entropy cap, AFS-L6 l2 binding
bound, fold hash-edge merge pointer owned by BB).

**E-O DISPOSITIONS (never silent):** E-O1 = params LANDED (frozen
class widths + adopted bases, EA Section 8.1 table + FC2-cls-*
rows) / manifest+deletion work EXPORTED (E-O1-BB). E-O2 = rule
LANDED as E-O2' (restated per-group per the U-AG4 W-C adoption;
AFS-L8 hypotheses named) / enforcement EXPORTED (E-O2-BB). E-O3 =
EXPORTED whole (E-O3-BB; requires the built pass-scope descent rig).

**FINDINGS (hostile-read, EB precedent — none changes a verdict;
recorded in SC Section 7.3, doc text unedited):** BA-F1 SC 1.4's
sigma formula string "sqrt(2·lambda/C2)" (= 2.92) contradicts its
own printed 2.07; corpus-wide working value is sqrt(128/30) =
2.0656 (DA's 121.7 base, spike S_JL). BA-F2 SC 2.4's "max beta_top
2^30.14 (JL)" vs its own spike's 2^30.39-2^30.40 (and uncapped
"2^31.8-2^34.1" vs spike max 2^34.52) — kappa-11 margin is 0.09 b,
not 0.36 b. BA-F3 SC 1.4's window print 2^24.06 matches neither
C1 = 120 (24.09) nor the spike's 125 (24.03). BA-F4 "op_norm(conc)
= 20.79" prints (SC 0.2, FD F-IF1.5) vs exact 20.80/DA's 20.8.
BA-F5 LLM_POC_ROADMAP.md Section 3 BA paragraph mislabels R-EB2 as
"K-draw restructure" (R-EB2 = NS22 prohibition; K-draw = R-EB3 per
SC 5.4). Minor on-row notes: SC 3.2's "+18-21 KiB" is loose
rounding of 18,088/20,672 B; EB's K-draw band 516-1,032 B vs FA's
adopted 1,036 B = the 4 B length prefix; FD/FS headroom prints
0.86-vs-0.87 and 0.24-vs-0.23 are two rounding directions of the
same exact values (pinned at 3dp).

**Suite note for the orchestrator (pre-existing, NOT fixed, per
lane rule):** first full-suite run hit ONE failure —
tests.test_zk_lattice.CommitmentTests.test_opening_proof_roundtrip
(AssertionError on verify_opening) — which then passed 3/3 in
isolation and the full suite re-ran 50/50 OK. Flaky/probabilistic
(zk_lattice rejection-sampling roundtrip); no BA file touches that
surface. Recorded for the baseline-suite reconcile. All BA timing
[MAC-BOX]; freeze rows themselves are machine-independent
arithmetic.

## Agent BB status (wt-uagb1-bb)

- 2026-08-08 PLAN COMMIT (before any code; skeleton-commit-first).
  Scope this context: items (1)+(2) only; (3) stretch iff 1+2 fully
  green. Baseline on this box at plan time: `cargo build --release`
  GREEN, `ring_matmul freeze-check` GREEN (every LKP-* row), python
  suite launched (result recorded at first code commit).
- READ-PHASE FINDINGS binding the plan:
  * The multi-wave C2 machinery (RANGE_AGGREGATION Phase 5) EXISTS
    in-engine (U-R1/U-Z1: plan_waves, split_claims_prover/-verifier
    _masked, WavePadLayout, closing_round_claims, the `ffn-chain
    layer` rig, LKP-9/LKP-10 rows). Deliverable 2 REUSES it — no
    parallel wave layer is built.
  * The engine's EXACT range mechanism at q31 is the range-table
    lookup (U-R2 — exact, ARP-free, no wrap side condition). The M2
    binary ct-claims at q31 carry the U3 side-condition caveat (ARP
    budget closes at q46-class only). The exact-digit path therefore
    grounds digit alphabets at q31 by range-table lookup instances +
    exact recomposition RingClaims (constant public coefficients) —
    deterministic, Gaussian-free, JL-free; consistent with the
    trench's exact-digit reading (PARAMS 3.4/3.5 committed digit
    columns + deterministic relations) and with I-6.
  * digit_decompose(e=1) cannot represent positive values (balanced
    base-2 digits land in {-1,0}); the exact-digit path adds the
    canonical sign-binary decomposition for e0 = 1 (the F-N2
    weight-group base): d_j = sign(x)*bit_j(|x|) in {-1,0,1}.
- D1 PLAN (exact-digit plumbing, F-N2): new src/ring/digits.rs —
  DigitMode { Balanced, Exact } (Balanced = existing Q2/DigitOpening
  path, UNTOUCHED); ExactDigitConfig (e0, l0, width, signedness) +
  the trench class table (weight int8 e0=1 l0=8; activation offset
  e0=2 l0=4; accumulator 24-bit e0=2 l0=12) + derive-time gates
  (gamma_max exact-digit = (q/8)/58.8 ~ 2^22.12 form; fold-norm
  formula OP_CONC*2^(e0-1)*sqrt(n*l0*D); recomposition non-wrap
  2^(e0*l0-1) < q/2); exact decomposition/recomposition (e0>=2
  balanced via shared digit_decompose, e0=1 sign-binary), exact
  round-trip asserted; digit-column dense packing + shifted-alphabet
  columns ([0,3) at e0=1, [0,2^e0) at e0>=2); base-2^e0
  recomposition RingClaims. Rig: commit value column + digit
  columns, range-table lookup instance over the shifted digits (m,
  blinders, masks, one masked descent pair, pins, root cross-check),
  recomposition claims, ct-round. Battery: differential balanced-vs-
  exact on identical inputs across the class table (round-trip
  bit-identical; balanced leg prove/verify green, response norms in
  bound_sq; exact leg commitments + claims green, digit inf-norms at
  alphabet bounds, gamma arithmetic checked); tamper legs
  out-of-alphabet digit REJECT, recomposition-defect REJECT,
  tampered-commitment REJECT, hash-ordering F5 pair. Freeze row(s)
  UAGB1-1 both directions (class table, gates, canonical
  decomposition digest); existing digests MUST NOT move.
- D2 PLAN (dense committed matmul statement, 512x768x2048): new
  ring_matmul section + `matmul-statement <rows> <inner> <cols>
  [battery]`. manifest::Statement (Operation::Matmul, QuantMeta
  int8, commitment digests) validated + digest bound into the
  transcript (D-4). Dense D-1 encoding 1 coeff/el, msg_r-packed; A
  512x768 int8 weight-class, B 768x2048 int8 activation-class, C
  512x2048 accumulator-class (|C| <= 768*127^2 < 2^23.6, exact at
  q31); inner 768 zero-extended to 2^10 in prover tables ONLY
  (commitments carry real data; eval functionals touch only
  committed indices). Multi-wave commit via plan_waves at the
  derived cap (c2_max - pin g-groups - pad commitment), every
  commitment bound before any challenge. Claim: Thaler degree-2
  matmul sumcheck over K (rx in K^9, ry in K^11 post-commit; 10
  rounds; endpoint a*, b*; final check v_end = a* * b*); the three
  MLE-eval claims land as PinnedValues -> pin_claims (9 psi copies,
  psi after pins — E4-N1) -> split_claims_*_masked + WavePadLayout +
  closing round (Z1: masked splitter is the shipped path) -> per-
  wave masked ct-rounds. The statement CARRIES the D1 exact-digit
  class declaration for its three tensor classes in the bound
  context (the config the aggregate layer consumes); honest label:
  the eval-proof/aggregate layer (items 4-6) is NOT in this
  statement — the wire is ct-round proofs + sumcheck + pins.
  Battery at a >= 3-wave shape with real 768 padding (128x768x256):
  honest ACCEPT; wrong-C-entry REJECT; tampered-commitment REJECT;
  stale-hash-ordering F5 pair; wave-boundary tamper legs
  (cross-wave content swap; wave-order/binding swap). Measurement
  [MAC-BOX, non-reference; + NOISY-SHARED while siblings run]:
  commit/prove/verify wall-clock + peak RSS at 512x768x2048 + one
  sanity shape; COUNTED bytes (64 B/K-el, counted-not-serialized)
  decomposed (ct-round openings | sumcheck | pins/reveals |
  commitment tags | pads/closing) vs the Tier N 262,144 B/layer P0
  gate — expected far OVER on the openings line (the designed
  eval-proof layer is exactly what replaces it; the number is the
  round's load-bearing designed-vs-built gap, reported, not hidden).
  Freeze row UAGB1-2 (battery-shape operating point) both
  directions. HONEST-FALLBACK: largest green shape + precise wall
  row if the full shape does not land.
- D3 (stretch, only if 1+2 fully green): 12-layer chaining skeleton,
  DAG wiring + statement plumbing only, honest NOT-PROVEN labels.
- WILL NOT DO: IXF fold, masked eval-proof path, wire format (items
  4-6); GPU; attention/softmax; q46 side; edits outside my file
  ownership; any new Gaussian-masked opening class (per-wave
  ct-rounds are the existing C2-gated house machinery; I-6's
  aggregate-layer prohibition respected).
- 2026-08-08 D1 LANDED (commit 0764bfd): ring/digits.rs + [UAGB1-D1]
  rig + battery 27/27 + freeze rows UAGB1-1a..1d; suite 47/47,
  self-test 238.7 s, freeze-check green (existing rows unmoved).
  Findings F-BB1/F-BB2/F-BB3 in UAGB1_ENGINE_REPORT.md Section 1.4.
  Hygiene note: 0764bfd also carries the then-unverified D2
  scaffolding (same file); D2 verified in the next commit.
- 2026-08-08 ORCHESTRATOR UPDATE dispositioned (BA/BC closed, main
  at ac58c23; read-only reads from the main checkout):
  * [-127,127] convention (BC-a): ADOPTED in the D2 witness
    generation (rng 255 - 127). The v3 DECLARED type stays int8
    signed [-128,127] and the accumulator width follows the
    validator's own declared-type arithmetic — both readings give 25
    bits at inner 768 (this statement); at inner 2048 they diverge
    (27 declared vs 26 honest) because QuantMeta has no
    symmetric-range field — flagged as a statement-typing item for
    the pass stage, not silently resolved. D1's class table keeps
    declared-type bounds (classes must COVER the type; [-127,127] is
    inside; landed digest unmoved).
  * Honest accumulator widths (BC-c): my mm_acc_bits DERIVES from
    the declared-type interval (25 at 768 — matches BC; never copies
    the 7B rows). Freeze row UAGB1-2d pins the inner-768 interval.
  * Requantization form (BC-d): N/A this statement — no requant
    edge in the single-matmul statement; choice lands at the
    chaining stage (if D3 skeleton is reached, its requant edge
    carries an honest NOT-PROVEN + floor-vs-rounding OPEN label).
  * Quantization metadata table (BC-b): the 12-row 125M table binds
    the INTEGRATION statement; this synthetic single-matmul
    statement declares frac_bits 0 (recorded); the integration
    statement carries BC's exact fields when built.
  * E-O1-BB: PARTIAL here — the statement BINDS the D1 exact-digit
    class/base declarations through the model digest (functional
    binding), and the battery carries the wrong-base negative
    vector (WrongClassDecl REJECT at the statement gate). The TYPED
    v3 manifest fields + 32-row layer-segment/group maps +
    inventory prints are pass-statement work (one versioned codec
    change together, not two) — remaining E-O1-BB scope recorded as
    open for the pass-statement stage.
  * E-O2-BB: the per-GROUP batched-opening rule binds the
    eval-proof layer (unbuilt, items 4-6). At this stage the
    structural predecessor holds: every data commitment is opened
    in EXACTLY one wave round (plan bijection; pads per pad-wave +
    closing per the U-Z1 canary pattern). Builder-refusal semantics
    land with the eval-proof openings.
  * E-O3-BB: N/A at items 1-2 — the matmul statement has NO descent
    (its claims are sumcheck + pins); the D1 digit rig's descent
    pair is per-instance by design (no sharing assumed, priced as
    its own). D-R1 verification lands with the pass-scope descent
    (item 3+).
  * aggregation_freeze_rows.py citation: my gamma gate matches the
    script's H-gate-ed row (gamma_max(exact-digit) log2 = 28 -
    log2(2*29.4) = 22.12); UAGB1-1b's label carries the value; row
    ids cited in the report. 125M rows: my freeze rows DERIVE
    (UAGB1-2a/2b layout arithmetic), never extrapolate.
  * AZB E-1..E-11: NONE unlocked by items 1-2 (all are
    aggregate/T_blind/eval-proof/IXF legs — first unlock at items
    4-5). My landed batteries carry their own hash-edge F5 pairs
    (stale-alpha, stale-order) which are NOT the AZB legs and are
    not claimed as such.
  * F-Z1 recipe: no floor exists at items 1-2 (no eval proof) — no
    schedule to post yet; recorded.
  * Flaky test noted (tests.test_zk_lattice ...roundtrip):
    will re-run before concluding anything from a suite failure.
  * No conflict with a committed decision — no SendMessage needed.
- 2026-08-08 BB VERDICT ROW (items 1+2 of the critical path):
  * D1 exact-digit plumbing LANDED (0764bfd): config-gated Exact
    path (committed digit columns + alphabet range-lookup + exact
    recomposition; Gaussian-free, JL-free) alongside the untouched
    Balanced Q2 chain; battery 27/27; freeze rows UAGB1-1a..1d;
    findings F-BB1 (exact-digit is the engine's ONLY sign-binary
    base — F-N2 concrete), F-BB2 (balanced chain C2-rejects wide
    classes the exact path accepts), F-BB3 (full-column
    recomposition is mod-q native).
  * D2 dense committed matmul statement LANDED AT THE FULL
    512x768x2048 SHAPE — the "largest full matmul claim proof =
    128x256x64" gap is CLOSED at the 125M integration-rung shape:
    3,014,656 committed values (2,944 data commitments, dense D-1),
    23 first-fit waves at cap 131 (C2 max 134 - pad - 2 g), ONE
    degree-2 matmul sumcheck over K + 3 MLE pins -> 9 psi claims ->
    U-Z1 MASKED share splitter + closing round -> per-wave masked
    ct-rounds; manifest v3 statement (validated, digest = transcript
    ctx) binding the D1 exact-digit class declarations; [-127,127]
    witness convention per BC. Battery 10/10 at 128x768x256 incl.
    the stale-order F5 pair BOTH directions, cross-wave content
    swap, wave-binding swap, compensated-lie, wrong-class-decl
    (E-O1-BB negative vector). Measured [MAC-BOX, ~1T]: commit
    0.31 s / prove 45.2 s / verify 4.2 s / peak RSS 1.13-1.25 GiB
    (2 runs, stable). Counted bytes 117,396,459 B = 447.8x the
    Tier N 262,144 B P0 gate — the OPENING layer (z + w1 + tags) is
    99.8% of it; the claim layer proper is ~226 KB. That ratio is
    the round's designed-vs-built gap number: the eval-proof/
    aggregation layer (items 4-6, unbuilt) replaces exactly the
    opening volume. Tier N NOT met, NOT claimed — no wall hit at
    this shape (no capacity wall, no memory wall).
  * Freeze rows UAGB1-2a..2d (battery + full-shape layouts derived
    both directions); all pre-existing freeze digests unmoved.
  * D3 STRETCH LANDED (skeleton only, honest labels): `ring_matmul
    statement-125m` — the 12-layer 125M FFN-pass statement (288
    entries, 276 ops, 12 outputs) VALIDATES + digests under
    manifest v3 at BC's calibrated quantization (weights 2^-9,
    derived per-layer shifts, stacked-plane range facts); every op
    class labeled NOT PROVEN; inter-layer edge NOT wired
    (RMSNorm/residual not integer-specified — fresh X per layer, the
    honest FFN-only scope). TWO statement-typing findings raised by
    the REAL calibration data, printed per layer (14 surrogate
    deviations): D3-F1 the frozen frac-4 SiLU table cannot host the
    calibrated eGate = -3 on 10/12 layers (per-scale table family
    needed — integration-blocking if unaddressed); D3-F2 QuantMeta
    cannot express positive scale exponents (eZ +1 / eH +2 clamped
    to frac 0 with widened 9/10-bit storage). Both exported to the
    pass-statement typing stage.
- BB LANE STATUS: items (1) and (2) COMPLETE and green (build +
  suite + freeze-check + batteries + measured); item (3) landed as
  the honest skeleton described above. Items (4)-(6) (IXF fold,
  masked eval path, wire format) remain the round's path — NOT
  claimed, next context's bite.

## Agent BC status (wt-uagb1-bc)

- 2026-08-08: lane OPEN. Read phase complete (ledger; roadmap 1/3/5;
  AGGREGATION_ZK_DESIGN Section 6 AZB-1..9 + Section 8 spike output;
  AGGREGATION_FOLDING_DESIGN Section 8 FINAL block AZB-10/11 ruling +
  F-O1..F-O5; AGGREGATION_FOLD_PRIVACY_PRICING FP-L1/L2/L3, AZB-11
  canary spec 4.2, F-Z1 3.1, F-Z3 8.3, Tier Z tables 3.3;
  O-5/O-6 identified from AGGREGATION_LITERATURE 8.1 via the
  PROGRESS_UAG FINAL + PARAMS 5.3/5.4 model rows; TARGET_CONTRACT
  Section 2 + Amendment A1; spike machinery surveyed in
  aggregation_zk_spike.py / aggregation_folding_spike.py /
  fold_privacy_pricing_spike.py). frugal-lm surveyed READ-ONLY:
  runs/125m-baseline ckpt-00009536 is a COMPLETED 2.5e9-token 125M
  run (val_loss 3.0816, bf16 safetensors, blocks.N.mlp.{w_gate,w_up,
  w_down}, shapes 2048x768 / 768x2048; mlp_hidden resolves to 2048
  via config.py default_mlp_hidden — the yaml omits it); frugal-lm
  .venv has mlx+safetensors+numpy (inference possible on-box).
  Deliverable skeletons committed: scripts/azb_battery_spike.py,
  docs/zkmatrix-poc/AZB_BATTERY_PLAN.md,
  scripts/m125_int8_calibration.py,
  docs/zkmatrix-poc/M125_CALIBRATION_STUDY.md. Building the AZB
  battery legs first.
- 2026-08-08 (later): **LANE COMPLETE.** Deliverables landed:
  (1) scripts/azb_battery_spike.py **20/20 OK** (~2 s) — executable
  spike legs for EVERY AZB id 1..11 plus the F-Z1 row; parent
  anchors (zk 14/14, privacy 15/15, folding 33/33) re-run by
  subprocess and asserted before any leg prints; carried by NEW
  tests/test_azb_battery.py. (2) AZB_BATTERY_PLAN.md — disposition
  table (20 executable legs / 11 engine SPEC blocks E-1..E-11
  [ENGINE PENDING - BB], none dropped); F-Z1 dated row; O-5/O-6
  identified (AGGREGATION_LITERATURE 8.1: verifier model to R2 /
  prover model vs H-05) with measurement plans (instruments, shapes,
  replaced [MODEL] rows, [MAC-BOX] rule, precise blocking); F-O2
  plan with the two-route blocking statement (in-statement route
  blocks on the eval-proof implementation via BB stages 2-5;
  standalone-rig route needs only the multi-wave C2 lift) and the
  finding that the 125M-pass descent depth dw ~ 25 [MODEL] sits ONE
  step past the recorded dw-24 point — F-O2 is 7B-freeze-blocking,
  NOT PoC-blocking. (3) F-Z1 RE-CHECK: corner SURVIVES at all
  design-doc floors (act 2^27.27 / wt 2^27.30 / 2^20 2^27.30 vs
  q/8 = 2^28.00; limb-growth branch stays dead; survival threshold
  1,940 rings; the whole plausible 600-800-ring 125M band safe);
  exact 125M point [BB-SCHEDULE PENDING], recipe recorded.
  (4) M125_CALIBRATION_STUDY.md + scripts/m125_int8_calibration.py +
  results/m125_int8_calibration.json — **VERDICT: the completed
  125m-baseline checkpoint (ckpt-00009536, val_loss 3.0816)
  CALIBRATES formally**: range facts 0 violations on held-out data,
  accumulators inside the honest 125M rows (25-bit @ inner 768,
  26-bit @ inner 2048 — the contract's 27/29 rows are 4096/11008 and
  do not transfer), remainders and table domain hold; the PoC
  statement can be built on this model as-is. Quality cost
  quantified and attributed: +4.98 nats val loss as-written; ~2.7 of
  it is the floor-requant bias (FREE fix exported to BB: the same
  relation on the publicly pre-shifted value = round-to-nearest);
  per-channel weight scales buy ~nothing; weights-only int8 is FREE
  (-0.0001 nats); the remaining +2.27 nats is activation-OUTLIER
  resolution (X absmax up to 8.5-31x p99.9), unfixable proof-side
  because the semantics cannot express saturation — the roadmap
  risk-5 branch (quantization-aware frugal-lm pass) now has its
  number. Convention pin exported to BB: int8 symmetric =
  [-127, 127], FORCED by the contract's own 27-bit row.
  Suite green INCLUDING the new test (48 tests OK, 287 s;
  zkmatrix-rs cargo release build green on this box). Findings for
  FINAL: (a) the [-127,127] pin and the 25/26-bit rows are
  contract-transcription-grade exports; (b) frugal-lm's 125m.yaml
  omits mlp_hidden (resolves 2048 via config.py default — cite the
  code, not the yaml); (c) aggregation_folding_spike.py's RSS print
  misreads on Darwin (ru_maxrss is bytes on macOS vs KiB on Linux:
  prints "39168 MiB"; informational only, checks unaffected —
  pre-existing, reported not fixed per lane discipline); (d) B/C
  rounding variants show 13/11 held-out range violations vs floor's
  0 — floor's narrowing tolerates up to 128*2^e vs round's
  127.5*2^e: a rounding deployment needs declared calibration
  margin. Files owned and touched only: the four deliverables +
  tests/test_azb_battery.py + results JSON + this section.
  Deliverables checkbox left for the orchestrator.

## Wave 2 (opened 2026-08-08 on Victor's console go: "Lets go ahead
## and launch wave 2")

Base: 4b1245b (wave 1 closed). Worktrees wt-uagb1-bd / wt-uagb1-be /
wt-uagb1-bf, branches uagb1-bd / uagb1-be / uagb1-bf. Same lane
discipline as wave 1 (skeleton-commit-first, own-section-only ledger
edits, no blocking git commands, suite + freeze-check green, honest
fallbacks, [MAC-BOX]/[NOISY-SHARED] timing marks).

- BD (aggregation stack, WORKTREE wt-uagb1-bd): the batched
  opening/eval-proof layer that replaces the wave-1 opening volume
  (99.8% of 117.4 MB): CR-L4-class batching of the statement's
  claims per commitment group -> descent -> the eval proof, bare
  (unmasked) first, at the 125M single-layer statement; then the
  masked path (FP-L2 mask-then-fold ordering hooks, F-Z3 sampler
  discipline, I-6 respected) and the AZB engine legs its stages
  unlock (E-blocks per AZB_BATTERY_PLAN.md Section 3); posts the
  FLOOR SCHEDULE (coords/rings) the moment a floor exists (unblocks
  BC's F-Z1 recompute recipe + kel/F-O2 instrumentation); wire
  format (audit M-05) as stretch. 125M-shape rows DERIVED and
  frozen, never extrapolated (BA rule); freeze-script row ids cited
  in derive-time asserts.
- BE (IXF fold, WORKTREE wt-uagb1-be): index-extension folding over
  the per-layer instance families at the 12-layer 125M pass —
  settle 12->16 padding against F-IF1 (4 index vars vs the frozen
  5-at-32; norm law one-time sqrt(16) — every delta from F-IF1
  re-derived and pinned as 125M-shape rows, R-row filed if anything
  would move a frozen constant); fold the sumcheck instances
  (stacked zero-check + joint matmul terminals per FA's design)
  with tamper legs incl. AZB-10 group/segment-map F5 pairs at
  engine scale where its stages allow; coordinates with BD ONLY
  through F-IF1 + the orchestrator.
- BF (integration, WORKTREE wt-uagb1-bf): D3-F1 per-scale SiLU
  table family (frozen per-exponent int8 tables + digests, eGate=-3
  hosted on all 12 layers); D3-F2 QuantMeta typing (positive
  exponents, [-127,127] symmetric range, honest declared-type
  accumulator widths 25/26-bit); then the 12-LAYER P0 PASS ON REAL
  WEIGHTS (ckpt-00009536 exported read-only from frugal-lm):
  per-layer gate/up/down full-shape matmul proofs + SiLU lookup at
  the new tables + Hadamard + range chain, honest byte/time
  reporting (bytes stay opening-dominated until BD lands — report,
  don't hide). Committed exit: >= 2 layers fully proven + all 12
  validated/digested + measured cost table + extrapolation; full
  12-layer prove if wall-clock permits (background runs fine).
  Housekeeping (tight-scope exceptions to the frozen-files rule):
  pinned-entropy fix for tests/test_zk_lattice.py
  CommitmentTests.test_opening_proof_roundtrip (the Pi1 precedent
  in the same file; do NOT weaken the test) + the Darwin ru_maxrss
  print scaling in scripts/aggregation_folding_spike.py
  (print-only, checks untouched).
- Orchestrator: merges in dependency order (BF/BE mergeable
  independently; BD last if interface friction), re-runs, F-Z1
  recompute when BD posts the schedule, reconciliation, push,
  brief. P2/Tier Z 12-layer composition = wave-3 unless BD+BF both
  land with room.

## Agent BD status (wt-uagb1-bd)

- 2026-08-08 PLAN COMMIT (skeleton-commit-first; read phase COMPLETE:
  ledger + BB dispositions; UAGB1_ENGINE_REPORT (waves/splitter/
  ct-rounds/byte rows); CR (CR-L1..L6, 10.2 one-batched-claim-per-
  group, 10.5 FS table); DA (2.2 two-tier shape, 3.2 chains, 5.1
  model, I-1..I-8); EA S8 (E-O1/O2/O3-BB); ZK 4.4-4.6 (AZ-T1, floor
  posture, one-proof-per-witness); FP (FP-L1/L2, 3.1 surcharges,
  F-Z1/F-Z2/F-Z3, 1.4 I-6-vs-TierZ reconciliation); FD S2 (F-IF1.0-
  1.8 frozen fold interface, 6,716 B/level class, kel model); FS 8.2
  (AFS-L8 two-group lemma), R-FC2/R-FC3/R-FC4;
  AZB_BATTERY_PLAN S3 (E-1..E-11 specs) + S4 (F-Z1 recipe b = 27.2 +
  0.5*log2(coords/81920)); aggregation_freeze_rows.py (85 rows — the
  citable ids); engine: commit.rs, digits.rs, sumcheck.rs, kfield.rs,
  gkr_masked.rs (masked_transcript_totals), lookup.rs
  (k_weight_coords), uagb1_matmul_run end to end).
- READ-PHASE FINDING (pre-registered for the report): the engine's
  OWN structural counter masked_transcript_totals(dw,0,1) +
  masked_transcript_totals(9,0,1) reproduces ALL FOUR recorded kel
  points EXACTLY (dw 17/19/21/24 -> 1,000/1,166/1,348/1,651) and
  yields 1,760/1,873/2,236 at dw 25/26/29 — bit-identical to the
  [MODEL] quadratic fit kel(dw,9) = 2dw^2+11dw+235. The fit is not a
  fit; it is the transcript-shape arithmetic. F-O2 standalone route
  therefore = validate counter == real flatten at reachable dw
  (real runs), then cite counter values at 25/26/29 as
  ENGINE-STRUCTURAL (not extrapolated) counts.
- STAGE PLAN (honest-fallback at every stage; files owned:
  src/ring/eval_proof.rs (new), [UAGB1-BD] section + one `agg-matmul`
  match arm + one freeze_check line in ring_matmul.rs, ADDITIVE
  aggregated-artifact descriptor in manifest.rs (QuantMeta untouched),
  docs/zkmatrix-poc/UAGB1_AGG_STACK_REPORT.md, optional additive
  tests/test_uagb1_agg.py, this section):
  * S1 BATCHING (CR-L4-class): W-C commitment groups at the 125M
    single-layer statement — T_W = {A 512x768 w8s e0=1 l0=8}, T_act =
    {B 768x2048 a8s e0=2 l0=5; C 512x2048 acc24-768 e0=2 l0=13}
    (frozen class table UAGB1-1a consumed as-is). Values enter the
    two-tier global commitment DIGIT-decomposed (exact-digit branch,
    the only e0=1 path — F-BB1); per group ONE outer identity u_0
    (4 + 11*516 = 5,680 B at KAP-11) binds the level-0 column
    commitments t_j (witness, never wire). Claim layer: the SAME
    degree-2 matmul sumcheck over K as wave 1 (rx/ry from h0_agg
    binding statement + BOTH groups' u_0), terminals -> per-group
    nu_g RLC (drawn after ALL terminals absorbed — CRB-N5; AFS-L8
    hypothesis (iii)) -> K_DEG = 16 coordinate rows (k_weight_coords
    pattern, IA-O1-2 fallback) -> 16 ring-embedded functional claims
    F_c(w) = B_c with ct(B_c) publicly pinned to the K-claim
    coordinate (conj-packing ct(conj(a)b) = <a,b>, SR 1.2 fact 3).
    Multi-point-per-tensor input supported via mu-additive row
    weights (folded instance families remain valid inputs — F-IF1
    NOT foreclosed; no fold-zone code touched). E-O2-BB LANDS HERE:
    group descriptor counts openings; a second batched opening in a
    group = BUILD ERROR + negative test. E-O3-BB DISPOSITION: the
    single-matmul statement carries NO lookup/range descent pair —
    D-R1 rho-sharing has no object at this scope; neither the
    battery leg nor the +143,104 B split price applies HERE;
    obligation transfers to the pass statement (recorded, not
    silent).
  * S2 DESCENT / EVAL PROOF, BARE: per group, the LaBRADOR-form
    recursion at kappa 11 — per level: K-draw ct-aggregation of the
    accumulated constraint set (full-entropy R_q alphas, R-EB3
    K-draw class 496 = EB3-kdraw; alphas drawn AFTER claim material
    absorbed), chunk split r_i (derive-time search seeded by the DA
    balance rule), garbage families g_jk = <s_j,s_k> and h_jk
    (functional cross terms) at the FULL r(r+1) count (R-EB2
    EB2-count — g carried although exact-digit norms are syntactic,
    keeping the frozen recurrence), outer commitment u_i over
    (t-hat ++ g-hat ++ h-hat) digits (5,680 B/level wire), quinary
    fold challenges resample-until-under T_cap = 33 (EB1-tcap,
    deterministic FS counter), fold z; next witness = [z-hat | t-hat
    | g-hat | h-hat] at adaptive base e_{i+1}: largest e with
    OP_CONC*2^(e-1)*sqrt(n*D) <= gamma_max(exact) = 2^22.12
    (H-gate-ed) AND e <= 7 (EB4-emax); transported constraints (fold
    consistency A_i z = sum c_j t_j; functional transport via h;
    norm transport <z,z> = sum c_j c_k g_jk via next-level quadratic
    terms; outer binding B_i(...) = u_i) — ALL targets public;
    FLOOR: bare witness (1 B/coord class at e_L <= 7), verifier
    evaluates every accumulated constraint + alphabet membership
    directly. THE MOMENT THE SCHEDULE DERIVES: floor
    coordinates/rings per group POSTED here + "FLOOR SCHEDULE
    POSTED" commit line (BC's F-Z1 recipe + F-O2 hang on it). kel:
    real masked-descent runs at reachable dw (counter == flatten
    asserted) + structural counts at 25/26/29.
  * S3 BYTE ACCOUNTING: counted-not-serialized convention (64 B/K-el,
    4 B/coeff, 8 B/response, 12 B/reveal, 4 + 516/poly), full
    per-group per-level decomposition vs Tier N 262,144 B/layer
    (P0) and vs wave-1's 117,396,459 B. Whether Tier N is met is a
    RESULT, reported as it lands. Rough pre-registered expectation
    [MODEL, hand recurrence]: floors ~650-750 rings/group, totals
    250-290 KB class — either side of the gate is a finding, not a
    failure.
  * S4 MASKED PATH (only after 1-3 green): the Tier-Z floor
    treatment EXACTLY as priced — re-derived Tier-Z schedule with
    e_L <= 4 floor base (the F-Z1 no-limb-growth corner), F-Z1
    asserted at derive (b = 27.2 + 0.5*log2(coords/81920) < 28.00,
    growth branch dead), rejection-sampled masked floor response at
    ~4 B/coord (F-Z3 sampler + abort discipline; mask
    prover-internal, never committed, NO hash edge — FP-L2 row A8;
    response sent after ALL of that group's level challenges —
    AZB-6 ordering unchanged; restart counts logged). I-6 HARD
    everywhere else: the floor response under the A1 carve-out is
    the ONLY Gaussian-masked object; if anything else seems to need
    one, STOP and file an R-row. AZB E-blocks unlocked and wired:
    E-6 (per-level per-group c-before-u F5 pair, both directions),
    E-7(i) floor recompute byte-exact from (witness, challenges) +
    (ii) toy rank law, E-11 legs 1-2 (static support + activation
    recompute from (T_act, challenges) alone) — legs 3-4 are
    pass-scope, labeled PARTIAL. AZB-11 at engine scale only as far
    as legs 1-2 reach at this statement (P2 group-map semantics are
    pass-stage).
  * S5 STRETCH: canonical wire format (M-05). If unreached: counted
    convention continues, stated in report + ledger.
- BATTERY (house F5 discipline, pairs on every negative): S1 —
  honest ACCEPT small + full shape; E-O2-BB second-opening build
  error; nu-ordering F5 pair (CRB-N5 class); tampered claim value
  REJECT. S2 — honest ACCEPT; floor coordinate tamper REJECT; OOA
  floor digit REJECT; level-ordering F5 pair (E-6/AZB-6 class:
  c^(i) before u_i ACCEPTS under hook / shipped REJECTS); alpha-
  before-B_c F5 pair (CRB-N3/N4 class); wrong-V transport REJECT;
  garbage tamper REJECT; global stale-rx/ry F5 (h0_agg edge, the
  wave-1 StaleOrder shape at the aggregate statement). S4 — masked
  honest ACCEPT; masked-floor norm tamper REJECT; F-Z1 derive
  assert; E-7/E-11 canaries as above.
- FREEZE: run `freeze-check` before/after every stage (ALL existing
  digests must not move); new rows UAGB1-BD-1..(layouts, schedules,
  floors, gammas vs H-gate-ed, byte totals) both directions in
  freeze_check_uagb1_bd(); derive-time asserts cite row ids
  (EB1-tcap, EB4-emax, H-gate-ed, EB3-kdraw, FC2-act-e0, FC2-w-e0),
  never re-derive ad hoc.
- WILL NOT DO: fold-zone code / 12->16 index padding (lane BE;
  F-IF1 is the ruling where we meet); lookup.rs / QuantMeta / SiLU
  tables (lane BF); q46 side; GPU; attention; any Gaussian-masked
  opening outside the priced Tier-Z floor carve-out; edits to
  existing scripts/tests or other ledger sections; push.
- 2026-08-09 **FLOOR SCHEDULE POSTED** (derived by the public
  planner, frozen in freeze_check_uagb1_bd BD-3, single-layer 125M
  statement 512x768x2048, exact-digit branch, kappa 11, R-EB caps):
  * weight group (T_W, A 512x768 w8s e0=1): n_0 = 24,576 digit
    rings -> 6 levels -> FLOOR 939 rings = 120,192 coords at
    e_L = 7 (1 B/coord bare).
  * act group (T_act, B a8s + C acc24-768, e0=2): n_0 = 167,936
    digit rings -> 7 levels -> FLOOR 936 rings = 119,808 coords at
    e_L = 7.
  * F-Z1 recompute (BC recipe b = 27.2 + 0.5*log2(coords/81920)):
    weight b = 2^27.48, act b = 2^27.47 — both < 28.00: the masking
    corner SURVIVES with ~0.53 b at both floors; the limb-growth
    branch (28.6 + same scaling) stays dead; both floors far under
    the 1,940-ring survival threshold.
  * FINDING (mild, for BC/orchestrator): the floors land ~17% ABOVE
    the 600-800-ring band BC called the expected landing zone
    (AZB_BATTERY_PLAN S4 said "a schedule outside it would itself
    be a finding") — driver: this planner's l_z sizing uses the
    deterministic-concentration bound with +2 bits restart headroom
    and the byte-optimal stop rule fires one level earlier than the
    design-doc spike's schedules; the corner margin absorbs it.
  * kel (F-O2 standalone route): REAL masked descent pairs at
    dw 10/12/14/17/19/21 (dt 9) count EXACTLY equal to the engine's
    structural counter masked_transcript_totals AND to the recorded
    fit (545/655/781/1,000/1,166/1,348); the counter at 24/25/26/29
    gives 1,651/1,760/1,873/2,236 = the fit values — the [MODEL]
    fit is the engine's transcript-shape arithmetic, not an
    extrapolation. dw 24/25 REAL runs in flight.
- 2026-08-09 **BD VERDICT ROW (stages 1-4 landed; 5 unreached,
  stated).**
  * S1 BATCHING LANDED: W-C two-group claim layer (nu_g post-
    terminals CRB-N5; 16 conj-packed ring rows/group, ct publicly
    pinned; alpha K-draw RLC at the EB3-kdraw class; multi-claim
    inputs additive — F-IF1 NOT foreclosed). E-O2-BB ENFORCED (a
    second batched opening in a group = AggBuildError, negative
    test green). E-O3-BB DISPOSITIONED: N/A at the single-matmul
    statement (no lookup/range descent pair exists to rho-share;
    neither the battery leg nor the +143,104 B price applies at
    this scope; obligation transfers to the pass statement) — not
    silent.
  * S2 DESCENT/EVAL PROOF BARE LANDED at 512x768x2048: kappa 11
    LaBRADOR-form recursion, exact-digit branch, per-level K-draw
    aggregation + h cross-garbage + one 5,680 B outer commitment
    committed pre-challenge + T_cap-33 exact-spectral-norm
    resampling + adaptive bases e <= 7; floors checked bare
    (T5/T4/T1/L1 + alphabet). g-family NOT carried (exact-digit:
    nothing consumes it; NO NS22 shrink of h — R-EB2 respected;
    deviation vs the modeled r(r+1) count named in the report).
  * S3 BYTES (counted convention, measured): **344,318 B =
    1.313x Tier N (OVER — reported, not forced; floor line 69.7%)
    = 341.0x under wave-1's 117,396,459 B.** Prove 55.9 s / verify
    17.4 s / RSS 1.36 GiB [MAC-BOX, NOISY-SHARED]. The verifier
    carries an O(N_limb) claim-kernel materialization — the
    recorded wall; the Greyhound row-column split is the designed
    fix (bytes unaffected).
  * S4 MASKED PATH LANDED (the A1 Tier-Z carve-out; I-6 holds
    everywhere else): e_L = 4 refit schedules with the F-Z1 corner
    ASSERTED at derive; prover-internal Gaussian mask (FP-L2 A8:
    no hash edge), images-then-capped-challenge-then-response
    (AZB-6), Lyubashevsky rejection w/ logged restarts (F-Z3);
    response 4 B/coord as priced. Measured 512x768x2048: floors
    1,368/1,364 rings e4, corner 2^27.75 SURVIVES, TOTAL 1,527,878
    B, restarts 0. LIVE FINDING: at small statements (battery
    shape) the Tier-Z floors (2,428 rings) CLOSE the corner
    (b = 2^28.16) and the derive gate refuses them — the corner
    needs floors < 1,940 rings; 125M/pass scales safely inside.
  * BATTERY 23/23 (~224 s): honest degenerate + recursed + Tier-Z;
    E-O2-BB build error; WrongC (ct-gate AND transported-floor
    forms); floor tamper; SHARP OOA-alphabet leg; F5 PAIRS both
    directions (alpha-before-rows binding collapse = CRB-N4 class;
    level-1 challenge-before-commitment h compensation = the E-6/
    AZB-6 engine leg); WrongClassDecl statement gate (E-O1-BB
    vector); Tier-Z response-norm + mask-image REJECTs; stale-order
    encoding-gate finding (wave-1-style mod-q forgery NOT ENCODABLE
    under exact-digit classes).
  * kel/F-O2: kel(24,9) = 1,651 RE-MEASURED real (33.7 s);
    **kel(25,9) = 1,760 MEASURED real (67.5 s) — the 125M pass
    point**; all 8 measured points EXACT vs counter vs fit; the
    fit is engine transcript arithmetic; kel(29) stays structural
    (7B-freeze residue).
  * AZB E-blocks: E-6 WIRED (engine-scale F5 pair per level
    structure); E-7(i) wired in substance (floor families ARE the
    byte-exact recompute); E-1..E-5/E-7(ii,iii)/E-8..E-11 NOT
    claimed (bind T_blind/pass-manifest machinery absent at this
    statement); AZB-11 honestly NOT reachable at a single-matmul
    statement (activation claims depend on A through the shared
    sumcheck terminals) — semantics attach to the P2 pass group
    map.
  * Freeze: BD-0..3 rows both directions in freeze-check; every
    derive assert cites its row id; ALL pre-existing digests
    unmoved at every commit. Suite: tests/test_uagb1_agg.py (2
    light tests); full-suite run at close (result in Log).
  * S5 wire format NOT REACHED — counted-byte convention continues
    (stated in report Section 1).
  * Report: docs/zkmatrix-poc/UAGB1_AGG_STACK_REPORT.md (byte
    decompositions, floor schedules, F-Z1, walls/findings,
    E-block table, exports, reproduction lines).
- 2026-08-09 **LANE CLOSE-OUT: full suite 53/53 OK (296.7 s,
  in-lane; 51 base + the 2 new agg tests) + freeze-check green at
  the final build (every pre-existing digest unmoved). Second
  full-shape bare sample: bytes IDENTICAL 344,318 (deterministic),
  commit 8.5 / prove 56.9 / verify 17.7 s, RSS 1.52 GiB [MAC-BOX,
  NOISY-SHARED both samples — sibling/suite activity overlapped;
  magnitudes stable across runs]. All work committed to uagb1-bd;
  no push (per brief). Deliverables checkbox left for the
  orchestrator.**

## Agent BE status (wt-uagb1-be)

- 2026-08-08 PLAN COMMIT (before any code; skeleton-commit-first).
  Read phase COMPLETE: ledger (wave-1 verdicts, BB dispositions, my
  lane definition); AGGREGATION_FOLDING_DESIGN.md IN FULL (F-IF1.0-1.8,
  FD-L1..L4, AZ-L4(a) rows S7, byte tables S6, F-N2/N3/N4, Section 10
  freeze table + 10.3's explicit 125M-row commission); AGGREGATION_
  FOLDING_SOUNDNESS.md (AFS-L0..L8, F-C fences, R-FC1..4, V1-V6);
  scripts/aggregation_folding_spike.py (toy IXF reference semantics —
  READ ONLY, Darwin RSS print left for BF); aggregation_freeze_rows.py
  (R-FC2/FC2-* row ids cited, never re-derived ad hoc);
  UAGB1_ENGINE_REPORT.md + engine (ring_matmul.rs [UAGB1-D1/D2/D3]
  sections incl. the full uagb1_matmul_run pipeline, sumcheck.rs,
  digits.rs, lookup.rs pins, manifest.rs v3, freeze_check chain);
  AZB_BATTERY_PLAN.md S3 (E-10 spec).
- THE 12->16 RULING (settled at plan time; full text + rows land as
  D-BE1): lambda(125M) = 4 DERIVED (F-IF1's 5 is the 32-layer 7B
  instantiation; FD-L1 "variable-count-generic", FD 10.3 commissions
  the 125M rows); PADS = 4 vacuous slots handled by the engine's
  existing zero-extension discipline (D-1/D2 precedent: prover tables
  extend, commitments carry real data, verifier functionals touch only
  committed indices) — I-3 kept (the sumcheck runs over all 16 slots),
  padded-slot tamper leg fences it; NORM LAW one-time log2 sqrt(12) =
  1.79 b on the committed inventory (conservative index-space bound
  sqrt(16) = 2.0 b also pinned; both < the frozen 7B sqrt(32) = 2.5 b
  row FC2-law, which does NOT move); DESCENT dim dw_pass = dw + 4
  (BC's kel(25) = 1,760 [MODEL] row STANDS); no frozen constant moves,
  no F-IF1/AFS-L8 contradiction => no R-row at plan time.
- D-BE1: ruling pinned — UAGB1_FOLD_REPORT.md Section 1 + freeze rows
  UAGB1-BE* (both directions, new fn freeze_check_uagb1_be in the
  freeze-check chain; every pre-existing digest must stay unmoved).
- D-BE2: src/ring/fold.rs (FoldLayout; degree-SCHEDULED sumcheck
  prove/verify — FD-L2's (3,2) wire form; stacked eq/table/pin
  builders with layer-extended position-determined weights; the norm
  arithmetic) + [UAGB1-BE] section in ring_matmul.rs: `ixf-fold`
  subcommand (one match arm) — TWO engine-scale fold rigs with full
  commitment grounding (multi-wave C2 + U-Z1 masked splitter +
  per-wave masked ct-rounds, the D2 pipeline layer-extended): (i) the
  JOINT MATMUL fold (12 x C_l = A_l*B_l, one (lambda+lk)-round
  sumcheck, 3 stacked pins), (ii) the STACKED ZERO-CHECK fold
  (12 x Z_l = Y_l o U_l Hadamard form, one (lambda+n)-round
  zero-check, 3 stacked pins). Zero fold messages; h0 binds statement
  (incl. layer-segment map through the model digest — D2's digest
  pattern; NO manifest.rs codec change, see WILL-NOT-DO) + all
  commitments before every draw (AZ-L4(a); hash-edge rows in report).
- D-BE3 BATTERY: honest ACCEPT at toy layer count AND at 12 layers
  (both families); cross-layer content swap REJECT (index binding);
  early-draw A1/A2 F5 pairs BOTH directions (zero-check two-position
  crafting + matmul stale-order stacked-C forge); naive-product
  cross-term negative BOTH directions (FD-L2 exhibit at engine
  arithmetic); padded-slot tamper REJECT (content smuggled into a
  vacuous slot); AZB-10a segment-map F5 pair at engine scale
  (statement-digest edge). AZB-10b group face: recorded BLOCKED on
  BD's eval-proof layer (the leak semantics need a floor) — spec
  stays E-10. Freeze-check + suite green at every commit.
- D-BE4 NORM, measured: engine-ring (D = 128) quinary negacyclic
  fold-norm slope re-measure (spike's 0.49 at toy D = 32); 12x ratio
  vs sqrt(12) law; e0 absorption re-derived at the REAL 125M
  12-layer matmul-family inventory (derived rows, both directions,
  incl. the honest finding if the layer e0 = 5 negative does NOT
  transfer at this inventory scale). [MAC-BOX]/[NOISY-SHARED] flags.
- D-BE5 BYTES: folded vs unfolded instance-transcript accounting at
  the 12-layer 125M shape (counted-not-serialized), FA-model vs
  engine-actual (d+1 evals) conventions BOTH reported; full-shape
  table DERIVED from layout arithmetic + measured where runs land;
  opening layer honestly reported as unchanged-until-BD.
- WILL NOT DO: eval/opening-zone changes (BD's lane; seam = folded
  families in, one eval proof per commitment group out, F-IF1.4/AFS-L8
  — orchestrator reconciles at merge); ring/lookup.rs + QuantMeta
  (BF's); manifest.rs codec changes (a typed segment-map field would
  move existing statement digests OR need the E-O1-BB one-versioned-
  codec-change — BB's recorded disposition defers that to the pass
  statement; my segment map binds through the model digest instead,
  the D2 pattern); the folded DESCENT implementation (FD-L3 dw+4
  ruling on paper; the rig needs the multi-wave C2 lift per
  AZB_BATTERY_PLAN S7 route 2 — recorded, not built); edits to
  existing scripts/tests/other ledger sections.
- 2026-08-09 (lane opened 2026-08-08): **lane COMPLETE.** All five
  deliverables landed at or above briefed scope; full suite green
  in-lane (53 tests, incl. new tests/test_uagb1_fold.py; the one
  first-pass failure was my own test's over-broad "FAIL" substring
  marker tripping on a leg LABEL — marker fixed to assert_true's
  exact "  FAIL " prefix, module re-run green, full-suite re-run
  green); freeze-check green at every commit with every
  pre-existing digest unmoved; everything committed to uagb1-be.

**VERDICT ROW (BE).** THE 12->16 RULING SETTLED — zero frozen
constants moved, zero R-rows: lambda(12) = 4 DERIVED over 16 slots
with 4 vacuous pads (F-IF1's 5 = the 32-layer instantiation,
reproduced unmoved; FD 10.3's commissioned 125M rows now exist);
pads = the engine's zero-extension discipline (commitments carry 12
real layers only; prover tables extend; verifier pins are
position-determined — I-3 KEPT, sumcheck runs over all 16 slots);
one-time norm law log2 sqrt(12) = 1.792 b on the real committed
inventory (sqrt(16) = 2.0 conservative bound; frozen 7B FC2-law 2.5
untouched); descent dim dw_pass = 21 + 4 = 25, kel(25) = 1,760
[MODEL] (BC's F-O2 row STANDS). Freeze rows UAGB1-BE1a..1e both
directions. IXF FOLD LANDS: src/ring/fold.rs (degree-scheduled
sumcheck in FD-L2's (3,2) form + the norm-law chain) + two
[UAGB1-BE] engine rigs with FULL commitment grounding (multi-wave
C2 + segment-map-bearing statement v3 + stacked pins -> psi -> U-Z1
masked splitter -> per-wave masked ct-rounds): the FD-L1 stacked
zero-check and the FD-L2 joint matmul (eq INSIDE, deg-2 inner /
deg-3 layer rounds, 3 stacked pins, eq* verifier-recomputed);
ZERO fold messages (only +lambda outer coords, CRB-N1 class, +
lambda in-round challenges). BATTERY 20/20 (53 s) + smoke in
self-test: honest ACCEPT at 4 AND 12 layers BOTH families;
cross-layer content swap REJECT (index binding); early-draw F5
pairs BOTH directions BOTH families; PADDED-SLOT tampers REJECT
both families (committed defect + post-draw pad-table cover:
sumcheck green — and on the matmul family the C pin consistent by
construction — caught exactly by the committed pin functionals);
AZB-10a segment-map completeness/DEFENSE/ATTACK both families
(registered map in h0 rejects a self-consistent full-layer relabel;
unbound-map weakened verifier accepts it, wrong-slice binding
exhibited); FD-L2 naive-fold negative all three directions. AZB-10b
(group face) honestly BLOCKED on BD's eval-proof layer — E-10 spec
stands. CAPSTONE MEASURED: the 12-layer fold AT THE FULL 125M LAYER
SHAPE 512x768x2048 honest-ACCEPTS as ONE folded instance — 35,328
data cms, 270 waves (= derived), commit 4.07 s / prove 431.5 s /
verify 59.3 s / peak RSS 13.57 GiB [MAC-BOX, NOISY-SHARED], folded
sumcheck measured EXACTLY the derived 3,200 B; counted total
1,406,719,131 B with the opening layer 99.8% (= the D2 wave-1
finding at 12x, byte-for-byte the volume lane BD's per-group eval
proof replaces — the folded family is its clean single-instance
input). NORM measured at engine ring D = 128: slope 0.52 (sqrt
law; spike's toy was 0.49), 12x ratio 3.9x vs sqrt(12) = 3.46, law
identity exact; 125M e0 rows DERIVED + pinned: weight e0 = 1
+5.159 b, act e0 = 2 ADOPTED +2.828 b. BYTES: claim-layer fold
9.4x derived (9,856 vs 92,928 B, both conventions reported);
full-F-IF1.1-population FA-table line at 125M = 511 kel = 32,704 B
[MODEL terminal-batch rounds]. FINDINGS: BE-F1 — the 7B FC2-act5
negative (e0 = 5 fails at x32) does NOT transfer to the 125M
matmul-family inventory (+0.452 b, FITS; pinned as an honest
positive row; e0 = 2 stays the declared class base by consistency
not necessity); BE-F2 — the K-draw engine forces 17-position
early-draw crafting (16 Gaussian-solved + 1 free) where the
base-field spike toy needed 2 positions: one K equation = 16 base
equations, R-EB3's full-entropy margin concrete in an executable
attack leg. Report: docs/zkmatrix-poc/UAGB1_FOLD_REPORT.md
(ruling, hash-edge table, battery table, norm/byte tables, BD/BF
exports). Deliverables checkbox left for the orchestrator.

## Agent BF status (wt-uagb1-bf)

- 2026-08-09 PLAN COMMIT (before any code; skeleton-commit-first).
  Read phase COMPLETE (ledger incl. BB dispositions binding this lane;
  UAGB1_ENGINE_REPORT D2 machinery + D3-F1/F2; M125_CALIBRATION_STUDY
  + script + JSON; M4_LOOKUP_DESIGN + lookup.rs + the U-R1/U-R2
  ffn-layer rig; manifest.rs v3 whole; AGGREGATION_ENCODING Section 8
  E-O1-BB/E-O2'/E-O3; TARGET_CONTRACT S2 + A1). Baseline on this box
  at plan time: cargo release GREEN (37 s warm), freeze-check GREEN,
  statement-125m digest 7b913619fbffa5da captured (a v3 digest that
  MUST NOT move). frugal-lm ckpt-00009536 + .venv + val shard
  confirmed present (READ-ONLY).
- READ-PHASE FINDINGS binding the plan:
  * eGate == eA on ALL 12 calibrated layers; the family needs exactly
    TWO members: (eGate,eA) = (-3,-3) [10 layers] and (-4,-4)
    [layers 1/4]. The calibration script's generator
    (silu_table(eg,ea): clamp(round(silu(g*2^eg)/2^ea), +-127)) is
    the family formula; the v1 frozen table IS the (-4,-4) member
    under round_half_up — a byte-identity freeze check, not a new
    table.
  * QuantMeta frac_bits is u32 and signed bounds are asymmetric
    [-2^(b-1), 2^(b-1)-1]: D3-F2 (positive exponents) and the
    [-127,127] symmetric declaration both need new typed fields —
    with true exponents, h8 and z return to honest 8-bit and the
    D3 skeleton's widened 9/10-bit storage disappears.
  * The contract's recorded state: X and W ranges are DECLARED, not
    proven (open M3 finding); proven facts = requant remainders +
    requant-output narrowings (or table-domain membership). g8/a8
    narrowing is FREE via SiLU domain; u8/h8/z need w8 facts;
    rg/ru/rh/rd need [0,2^shift) facts.
  * The exact q31 range mechanism is the U-R2 range-table lookup
    (masked descent + root cross-check) at variable width — no bit
    planes, no digit columns needed for dense value columns at
    2^20 els (ceiling 2^25 clears). The requant EDGE itself is a
    linear ring identity (Gacc - 2^s*g8 - rg = 0 per chunk) — the
    D1 recomposition-RingClaim family with public constants.
  * BB dispositions carried: [-127,127] adopted in witness data;
    requant form = FLOOR as recorded (variant A semantics — the
    calibrated 0-violation guarantee is for floor; the pre-add
    rounding note stays a recorded option, NOT taken here).
- D1 PLAN (per-scale SiLU table family; integration-blocking D3-F1):
  additive in src/ring/lookup.rs — `silu-int8-table-v2` family:
  deterministic generation per (eGate, eA) (f64 silu, round_half_up,
  clamp +-127, domain all 256 int8 codes; platform-drift-loud via
  digests, the v1 discipline); FROZEN byte arrays + digest constants
  for the two members; v2 spec-header digest (canonical JSON with
  SIGNED scale_exp fields); freeze rows UAGB1-BF-1* in a new
  freeze_check_uagb1_bf() (hooked by ONE line in freeze_check):
  regeneration == frozen bytes+digests both members; family(-4,-4)
  bytes == SILU_INT8_OUTPUTS and v1-header digest ==
  SILU_INT8_TABLE_DIGEST (v1 unmoved); (-3,-3) digest != v1 digest
  (wrong-member direction). Generation spec written in
  M125_PASS_REPORT.md (byte-identical regeneration procedure).
- D2 PLAN (QuantMeta typing, ONE versioned codec change; D3-F2 +
  E-O1-BB): manifest.rs v4 alongside v3 — Statement gains
  `typing: Vec<TypingV4>` (scale_exp i32, symmetric bool, class u32,
  base_e0 u32) and `tables: Vec<TableSpec>` (empty for v3;
  Statement::new unchanged); new Operation::LookupAt {x, y, table}
  (manifest-digest tag 12, codec tag 11 — existing variants' bytes
  untouched); validate() version-gated: v3 = the byte-identical old
  path + typing/tables must be EMPTY + LookupAt rejected; v4 =
  typing required per entry, signed scale-exponent arithmetic
  (matmul/hadamard add, rescale y = x + shift), symmetric signed
  bounds +-(2^(b-1)-1) (the [-127,127] declaration -> honest 25/26
  accumulator bits DERIVED by the validator), frozen v4 class
  registry (E-O1 value-width classes + adopted bases: weight e0=1
  sign-binary, act/acc/aux e0=2; class covers declared bounds,
  base_e0 == class pin), LookupAt table in the frozen registry
  (v1 spec + v2 family members) with operand typing == spec typing;
  digest(): v3 path byte-for-byte untouched, v4 = new tag absorbing
  typing+tables; codec: v3 -> cv1 bytes unchanged, v4 -> cv2.
  Battery statement_v4_battery(): v3 sample digest/codec unchanged
  (pinned), positive-exponent expressibility (eZ +1 / eH +2
  un-clamped), symmetric-vs-asymmetric accumulator pair (26-bit at
  inner 2048 ACCEPTS symmetric / REJECTS asymmetric), wrong-class +
  wrong-base negative vectors, version-gate negatives (v3+typing,
  v4-typing, LookupAt-in-v3, bad table index, off-registry table),
  codec round-trip v4 + malformed vectors. Freeze rows: v3
  codec-sample digest + statement-125m digest pinned (existing
  digests must not move — enforced, not asserted).
- D3 PLAN (the 12-layer P0 pass on real weights):
  * Export (scripts/m125_export_ffn.py, additive; frugal venv;
    READ-ONLY): 36 weight tensors via the pure-numpy safetensors
    reader -> int8 at 2^-9 (transposed to matmul layouts WgT/WuT
    768x2048, WdT 2048x768); per-layer X [512,768] captured from
    ONE seeded held-out fineweb-edu-val sequence (same rng
    construction as BC's script -> a window inside BC's measured
    0-violation set) via frugal_lm's own model code (mlx walk,
    fp32 reference, the study's capture point); per-layer z digests
    from a Python variant-A replica for cross-validation. Binary
    .bin exports + manifest JSON with SHA-256 digests into
    results/m125_ffn_export/ (data git-ignored via a local
    .gitignore inside that directory; JSON manifest + script
    committed — regeneration documented).
  * Witness chain derived IN RUST from X + weights (floor requant,
    v2 family tables, exact integer arithmetic), range facts
    asserted at derive time (loud fail = intended), z cross-checked
    against the Python digests.
  * The pass statement (v4): 12 layers, TRUE exponents (no
    surrogates), per-layer LookupAt into the family, [-127,127]
    symmetric on X/W (25/26-bit honest accumulators), entries bind
    real commitment digests (commit pass per layer, streamed);
    validates + digests = the ctx of EVERY proof instance.
  * Per-layer proof (my own [UAGB1-BF] section; one commitment set,
    one transcript, ONE first-fit wave plan at the derived cap —
    every commitment opened exactly once per layer): 3 dense matmul
    sumchecks (D2 recipe: gate/up at 512x768x2048, down at
    512x2048x768, wave plan DERIVED at the down shape) + 9 MLE
    pins; SiLU fused-pair masked descent pair at the layer's family
    table (g8,a8 dense, dw = 22 for 2^20 els) + aggregate pins;
    Hadamard by ONE degree-3 sumcheck (eq*a8*u8 vs H~(r)) + pins;
    requant edges Gacc/Uacc/H/Dacc as per-chunk linear RingClaims
    (public 2^shift constants); range facts as U-R2-style
    [0,2^w) range-table masked descents: u8/h8/z offset codes at
    w=8, rg/ru/rh/rd at w=shift; all pins psi-batched into the
    shared wave rounds (U-Z1 masked splitter + closing round).
  * COMMITTED EXIT (honest-fallback): layers 1-2 fully proven with
    battery legs + all 12 validated/digested + measured per-op-class
    cost table + honest 12-layer extrapolation; FULL 12-layer run
    only if layer-1 wall-clock permits (measure first, decide,
    report the decision). Long runs in background. P0 mode: no
    privacy claim; byte totals reported opening-dominated (the
    monster number reported, not hidden; BD's stack is what
    replaces it).
  * Battery (pass-level, real data at a reduced-T slice for the
    suite + full-shape legs subcommand-driven): wrong weight tensor
    in layer k (statement-digest gate); wrong table for a layer's
    exponent (root cross-check REJECT with everything else green —
    the sharp new leg; plus the v4 statement-level scale-mismatch
    REJECT); cross-layer output/input mismatch at the statement
    seam (g8 commitment swap across layers -> digest recompute
    REJECT); range violation (out-of-range remainder value ->
    range root cross-check REJECT).
  * tests/test_uagb1_pass.py (additive): v4 battery + freeze rows +
    the reduced-shape pass battery inside the suite budget.
- HOUSEKEEPING PLAN (each its own tight-scope commit):
  * 4a tests/test_zk_lattice.py: wrap test_opening_proof_roundtrip's
    instance+prove in the file's OWN pinned_entropy() precedent
    (seed chosen so honest ACCEPTS and both tamper arms REJECT);
    asserts untouched; stability demonstrated 25/25 consecutive
    runs.
  * 4b scripts/aggregation_folding_spike.py: ru_maxrss print-only
    platform fix (bytes on Darwin vs KiB on Linux); checks
    untouched; spike re-run 33/33.
- STRETCH (only if 1-3 fully land): P2-mode declaration plumbing
  (mode field + private commitment-group declaration) — plumbing
  only, no masking claim (BD's stack).
- WILL NOT DO: BD's eval-proof/aggregation zone; BE's fold zone
  (ring/fold.rs); the aggregated-artifact descriptor zone of
  manifest.rs; edits to other lanes' files or ledger sections; any
  Tier N/Tier Z compliance claim (P0 honest byte totals only); the
  pre-add rounding requant switch (recorded option, not taken);
  pushes.
- 2026-08-10: **lane COMPLETE.** Deliverables 1-3 landed ABOVE
  committed scope (full 12-layer proven run, not the 2-layer
  fallback), 4a/4b landed, stretch 5 not taken (declared, not
  silently dropped: the 12-layer run consumed the wall-clock room).
  Full suite 54/54 green in-lane (367 s [NOISY-SHARED]); freeze-check
  green with every pre-existing row unmoved; everything committed to
  uagb1-bf. Report: docs/zkmatrix-poc/M125_PASS_REPORT.md.

**VERDICT ROW (BF).** THE 12-LAYER 125M P0 PASS IS PROVEN ON REAL
WEIGHTS: ckpt-00009536, T = 512, one held-out fineweb-edu-val
sequence, **12/12 layers accept = true** against ONE validated v4
pass statement (204 entries, 192 ops, 12 z outputs, 2 family tables,
digest 76dbf204.., 26,116 B serialized, ZERO surrogate deviations —
the D3 skeleton's 14 are gone). Per layer: 3 full-shape dense matmul
sumchecks (gate/up 512x768x2048, down 512x2048x768 — the
down-projection wave plan derived honestly), SiLU fused-pair masked
lookup at the layer's per-scale family member, degree-3 Hadamard
sumcheck, 4 requant edges as zero-valued MLE pins, 7 range-table
facts (remainders at [0,2^shift) + u8/h8/z at w8) — all pins
psi-batched into the D2 multi-wave machinery consumed AS-IS (127
waves/layer, ~16.8k commitments, each opened exactly once).
Deliverable detail:
  * D1 (6df3cf2): silu-int8-table-v2 family — deterministic
    generation per signed exponent pair; frozen members (-3,-3) [10
    layers] and (-4,-4) [layers 1/4]; the (-4,-4) member is
    BYTE-IDENTICAL to v1 and the v1 digest is UNMOVED (freeze rows
    UAGB1-BF-1a..1d both directions). D3-F1 CLOSED.
  * D2 (e2d399b): manifest v4 in ONE versioned codec change —
    TypingV4 (signed scale_exp: eZ +1 / eH +2 un-clamped; symmetric
    [-127,127] with the validator DERIVING the honest 25/26-bit
    accumulator rows and REJECTING the asymmetric 27-bit reading;
    E-O1-BB class/base fields, frozen 5-class registry, weight e0=1
    F-N2) + tables[]/LookupAt (per-layer members, registry-gated) +
    RangeLookup (the U-R2 fact form, plane-free); v3 rules, digests
    AND cv1 wire bytes untouched (pinned: UAGB1-BF-2a..2c;
    statement-125m 7b913619 verified unmoved through full
    self-test); battery 19/19 incl. wrong-class/wrong-base vectors
    and both version-gate directions. D3-F2 CLOSED; E-O1-BB typed
    form LANDED.
  * D3 (8928f7a, f759575, cc783f4): read-only exports (weights int8
    @ 2^-9 via pure tensor reads; X from the QUANTIZED end-to-end
    walk after the fp32-reference construction FAILED z facts on
    2/12 layers — finding BF-F1, the loud-fail path working);
    Rust-derived witness chain, range facts 0 violations, z
    byte-identical to the Python replica on all 12 layers; the
    [UAGB1-BF] runner (one commitment set / transcript / wave plan
    per layer). MEASURED [MAC-BOX ~1T, runs partly NOISY-SHARED]:
    prove 3,275 s total (~273 s/layer; waves 68.8%, descents 25.5%,
    matmul sumchecks 0.9%), verify 411 s (~34.3 s/layer), commit
    444 s (incl. ~33 s/run statement-rebuild overhead), peak RSS
    12.0-13.5 GiB/run. COUNTED BYTES: 7,923,653,984 B = 7.38 GiB
    the pass, 660.3 MB/layer = 2,518.9x Tier N (P0) — the OPENING
    layer (z+w1+tags) is 99.7%; claim layer ~1.9 MB/layer. Reported,
    not hidden: exactly the volume BD's stack replaces. Tier N NOT
    met, NOT claimed; verifier 34 s/layer vs the 2 s line = the
    AGGREGATE verifier's job, not claimed.
  * Battery (pass level, real data): 6/6 — honest layers 0 ((-3,-3))
    and 1 ((-4,-4)); wrong-weight REJECT at the STATEMENT gate (P0
    public-model discipline: the verifier recomputes weight
    commitments); wrong-table-for-exponent REJECT with statement/
    matmuls/descents/roots ALL green (the verifier's statement-table
    leaf pins fail in the wave rounds — the sharp leg; plus the
    statement-level wrong-member REJECT in the v4 battery);
    cross-layer g8 seam REJECT (requant+lookup pins); range
    violation REJECT isolated to the rd instance's root cross-check.
    Suite-riding subset in tests/test_uagb1_pass.py (v4 battery +
    freeze rows + real-data smoke).
  * Housekeeping: 4a (6b5e3ea) roundtrip flake pinned per the file's
    own precedent, asserts unchanged, 25/25 consecutive green; 4b
    (0ad84c6) Darwin ru_maxrss print fix, spike 33/33.
  * FINDINGS: BF-F1 (committed-X construction must be pinned to the
    quantized walk — the fp32-reference hybrid fails z facts on 2/12
    layers; a deployment must declare WHICH forward produces X);
    BF-F2 (the all-pins composition carries a full FFN layer on the
    EXISTING psi/splitter/ct-round machinery with zero new claim
    families — the D2 wave recipe is generic); BF-F3 (gkr_masked
    capacity 2^(d-1)-4 forces dw=22 dummy-padding for 2^20 tensors,
    ~2x tree work — an optimization seam, not a wall; waves, not
    descents, dominate).
  * For the orchestrator: exports regenerate via ONE script run
    (frugal venv, READ-ONLY); binaries git-ignored,
    manifest.json + digests.txt committed; full-shape runs are
    subcommand-driven (`m125-pass statement | prove <l> | battery`);
    P2-mode plumbing (stretch 5) NOT taken — wave-3 item alongside
    BD's masked path.

## Wave 2 close (orchestrator, 2026-08-10)

ALL THREE LANES LANDED AND MERGED (BD e3c9825, BE 9462d89, BF
b8a4b4b), every gate re-run green at every merge, every
pre-existing freeze digest unmoved, zero blockers, zero dishonest
claims. The round now holds, on main: (1) the eval-proof stack
collapsing a single-layer artifact 341x (344,318 B bare /
1,527,878 B masked, corner-safe); (2) the IXF fold turning 12
layers into ONE instance at full shape (ruling settled, zero
R-rows); (3) the 12-layer P0 pass PROVEN on real 125M weights
under one statement. F-Z1 + F-O2 discharged at 125M scale; the
opening-proof flake fixed (25/25); manifest v4 typing + SiLU
family v2 landed.

WAVE 3 QUEUE (the composition wave — next console go): compose
BE's folded pass family into BD's per-group eval proofs on BF's
pass statement -> THE pass-level Tier N number vs the 262,144
B/layer-x-amortization expectation and the Tier Z pass number vs
A1's derived-budget obligation (P2 mode declaration plumbing +
masked weight group, AZB-11 at the pass group map, AZB-10b at the
floor layer, E-blocks remaining); the verifier kernel row-column
split (17.4 s + 34.3 s/layer walls vs the 2 s aggregate line);
wire format (M-05) so budgets bind on serialized bytes; p50/p95
measurement discipline; E-O3-BB at the pass statement; BF-F3
gkr_masked padding seam as an optimization item.

## Wave 3 (opened 2026-08-10 on Victor's console go: "Okay, let's
## continue to the next wave")

Base: a9ed98b (wave 2 closed). Worktrees wt-uagb1-bg / wt-uagb1-bh /
wt-uagb1-bi, branches uagb1-bg / uagb1-bh / uagb1-bi. Lane
discipline block above applies verbatim (skeleton-commit-first,
own-section ledger edits, no blocking git, suite + freeze-check
green at every claim, honest fallbacks, [MAC-BOX]/[NOISY-SHARED]).

- BG (COMPOSITION, wt-uagb1-bg): compose BF's real-weights pass
  statement -> BE's IXF folded instance families -> BD's per-group
  batched opening + eval proof. Deliver: (1) the pass-level Tier N
  (P0, bare) artifact MEASURED + the 125M pass budget expectation
  DERIVED (BA rule: derived, never extrapolated from the 7B rows);
  (2) the P2 pass: mode-declaration plumbing, weight group masked
  ONCE per pass (the FP-L3 split; activation group bare), the
  125M Tier Z pass number vs A1's derived-budget obligation;
  (3) AZB-11 weight-independence canary AT THE PASS GROUP MAP
  (its semantics live here — BD's disposition), AZB-10b at the
  floor layer, E-O3-BB dispositioned at the pass statement,
  remaining E-blocks its stages unlock. MUST NOT edit
  eval_proof.rs internals (BH's zone this wave) — consume the API;
  needed diffs filed as exports to the orchestrator.
- BH (VERIFIER PERF, wt-uagb1-bh): owns eval_proof.rs this wave.
  (1) The claim-kernel row-column split (the O(N_limb)
  materialization behind the 17.4 s single-layer eval verify and
  the per-layer pass verify wall) — measured before/after, public
  API source-stable for BG; (2) BF-F3: the gkr_masked 2^(d-1)-4
  capacity padding seam (~2x tree work at dw=22) — lift or avoid,
  differential-tested; (3) all existing batteries green, freeze
  digests unmoved. The 2 s contract line binds the aggregate
  verifier on the reference box — BH targets the complexity fix
  and reports ratios [MAC-BOX], not the contract claim.
- BI (WIRE FORMAT + MEASUREMENT, wt-uagb1-bi): (1) the canonical
  serialized wire format (audit M-05) — versioned, deterministic,
  round-trip-tested — for the eval-proof artifact (bare + Tier-Z),
  the folded-family transcript, and the pass statement; the
  serialized-vs-counted byte table (budgets bind on serialized
  bytes at FINAL); the writer API + format section BG's composed
  artifact conforms to; (2) the p50/p95 measurement harness per
  the contract statistic (>= 20 warm runs, p50+p95, cold-start
  separate) + protocol doc for a reference-box pass; Mac runs
  flagged. Visibility-only one-line edits in other zones allowed,
  each listed in the report.
- Orchestrator: merge by completion order with seam resolution
  (BG consumes BH's API and BI's format — deferred conformance at
  merge is acceptable and recorded); A1/F-IF1 comparisons + p50/
  p95 + serialized-bytes reconciliation at FINAL; push; brief.

## Agent BG status (wt-uagb1-bg)

- 2026-08-10 PLAN COMMIT (before any code; skeleton-commit-first).
  Read phase COMPLETE: ledger in full (wave-1/2 verdicts, BD/BE/BF
  rows, wave-3 lane definitions); UAGB1_AGG_STACK_REPORT.md (the
  claim interface, floor schedules, Tier-Z path, deviations 2.5);
  UAGB1_FOLD_REPORT.md (12->16 ruling, both fold families, exports:
  per-tensor stacked pins = my batched-opening input);
  M125_PASS_REPORT.md (v4 statement, per-layer shifts/exponents,
  exports present in results/m125_ffn_export/); F-IF1 whole (esp.
  1.4 groups + 1.7 byte skeleton), FP (FP-L3 split, 4.2 AZB-11 spec,
  4.3 P2 once-per-pass amortization, 3.x Tier Z structure),
  ZK_GAP_OPTIONS 6-8 (mode table; 7B rows NOT copied),
  TARGET_CONTRACT A1, AZB_BATTERY_PLAN S3 (E-10/E-11 specs) + S4
  (F-Z1 recipe); engine: eval_proof.rs public API in full (consumed
  AS-IS), fold.rs in full (scheduled sumcheck is combiner-generic —
  my requant fold rides the public API), BD's bin driver pattern,
  BF's loaders (bf_load_layer/bf_derive_chain/m125_build_statement),
  manifest.rs Statement/digest/v4 zones.
- PLAN (honest-fallback at every stage; deviations pre-registered):
  * COMPOSED RELATION SET at wave-3 machinery state: 3 folded
    matmuls (gate/up/down — BE's FD-L2 form iterated at the 3 pass
    positions) + 1 folded Hadamard zero-check (FD-L1) + 4 folded
    REQUANT zero-checks (new instance family on fold.rs's public
    scheduled-sumcheck API: stacked linear zero-check with the
    PUBLIC layer-coefficient MLE c~(l) = 2^{s_l} from the statement
    shift table; schedule [2; n_pos]++[3; lambda]; sh*/eq* verifier-
    recomputed) + PUBLIC-TENSOR BINDING claims (X_l, z_l at a shared
    post-h0 point; verifier computes the values from public data;
    weights NEVER — the FD 6.4 W-A rejection ruling; weight binding
    = u_0 identity + statement digests, the per-model off-clock
    discipline) -> ALL claims into BD-pattern per-group batching
    (T_W = 36 per-layer weight tensors, T_act = 168 per-layer act
    tensors; stacked claims decompose per layer with eq(l*,l) row-
    kernel scales) -> ONE eval proof per group (W-C, E-O2-BB gate).
  * NOT COMPOSED (loud label, everywhere): the table-membership
    facts (SiLU LookupAt + 7 RangeLookups/layer). The folded masked
    descent is the recorded unbuilt piece (BE WILL-NOT-DO: needs the
    multi-wave C2 lift; AZB_BATTERY_PLAN S7 route 2). 125M finding
    to record: the design's shared-table fold assumption breaks at
    125M structure (2 SiLU family members; 6 distinct remainder
    widths) — per-table fold groups derived in the report; the
    descent line rides the DERIVED expectation [MODEL], both
    structural forms, not the measured artifact. Consequence stated
    honestly: without range/lookup facts the composed relation set
    pins the chain up to the known table-fact freedoms.
  * MULTI-CLAIM KERNELS: eval_proof.rs's ClaimKernelCtx takes ONE
    product-form kernel per tensor (kernels.find on tensor_idx) —
    my pass has 2-3 claims/tensor. Built around in MY module
    (generalized additive value-weight assembly, on-the-fly, no vw
    materialization); API-change export row filed for BH's zone
    (below), eval_proof.rs NOT edited.
  * MODE DECLARATION (deliverable 2 plumbing): ADDITIVE manifest.rs
    field `Statement.mode: Option<ModeDecl>` (mode P0..P3 + declared
    private entry set). Digest + codec absorb the field ONLY when
    Some — v3/v4 digests and cv1/cv2 wire bytes of mode-less
    statements provably unmoved (freeze rows). Validation: internal
    consistency (P0 = empty set; P2 = exactly the CLS_W8S entries;
    P1/P3 expressible). The composition layer RUNS P0 (bare) and P2
    (FP-L3 split: weight group Tier-Z masked once per pass via the
    BD S4 carve-out machinery, act group bare); P1/P3 are REFUSED
    loudly (the act-side mask + T_blind instance masking are absent
    this wave). P2 honest label pre-registered: the weight-group
    FLOOR is masked; the matmul/terminal ROUND POLYNOMIALS carry
    weight functionals unmasked (T_blind machinery = the E-1..E-5
    block, absent) — priced in the expectation as the design's
    masked-instance delta [MODEL], stated in report + statement
    scope note, deployment-grade P2 named as requiring it.
  * BATTERY (small shape = 2-3 layers, T = 16, REAL ckpt data;
    wire tampers re-verify the honest proof, witness tampers
    re-prove): honest ACCEPT small + full; folded-family/claim-
    interface mismatch REJECT (tampered v_C / tampered stacked
    terminal); group-map relabel REJECT (h0_agg gate) + AZB-10b F5
    BOTH directions (map-unbound weak verifier accepts + the act
    floor's weight-functional delta EXHIBITED; shipped rejects);
    wrong-layer content REJECT through the composed path (cross-
    layer tensor swap caught by the eq(l*)-keyed claims/requant
    publics); floor tamper + OOA legs (BD classes) at the composed
    scope; Tier-Z response-norm + image tampers (P2); public-claim
    (z-output) mismatch REJECT.
  * AZB-11 AT THE PASS GROUP MAP (E-11, FP 4.2 four legs + reject
    semantics): leg 1 static support (derive-time, every pass);
    leg 2 functional recompute of act-group batched claims AND act
    floor from (T_act, challenges) alone — byte-exact (replay
    harness); leg 3 W-perturbation invariance under the pinned
    challenge tape (rigged harness, labeled); leg 4 migration F5
    REJECT; AZB-11b BOTH contaminated variants FIRE (claim-layer
    smuggle -> leg 1; floor fold-in -> leg 2 with the explicit
    weight-functional delta printed). Canary failure semantics =
    deployment-blocking for P2, wired as errors not warnings.
  * E-O3-BB DISPOSITION at the pass statement: the composed
    artifact carries NO descent pair (fallback above), so D-R1
    rho-sharing has no engine object THIS wave; the derived
    expectation prices BOTH branches (rho-shared vs split
    +kel-pair); the battery leg lands when the folded descent
    lands. Named in ledger + report, not silent. E-blocks NOT
    unlocked: E-1..E-5, E-8, E-9 (T_blind machinery absent at the
    composed bare/Tier-Z path) — stated.
  * DERIVED 125M PASS-BUDGET EXPECTATION (BA rule, executable):
    `pass-agg expect` derives from the design formulas AT 125M
    shapes — group inventories from the statement class table,
    schedules/floors from eval_proof::plan_schedule{,_tier_z},
    folded-instance kel arithmetic at 125M rounds, descent line
    [MODEL] both structural forms, A1 comparisons (Tier N P0 gate
    per layer x12; Tier Z vs the DERIVED 125M obligation — the
    frozen 1,114,112 B is the 7B P3 reference, cited not copied).
  * PRE-REGISTERED [MODEL] plan-time estimates (found honest or
    found wrong, either lands in the report): T_act n_0 ~ 8.2M
    digit rings, T_W ~ 3.5M; composed bare pass total ~ 0.4-0.55
    MB class; P2 pass ~ 1.0-1.1 MiB class; prove wall 25-70 min,
    verify 10-25 min [MAC-BOX, the BD O(N_limb) claim-kernel wall
    at pass scale — BH's split not depended on]; RSS tens of GiB.
- FILES: src/ring/pass_agg.rs (new); [UAGB1-BG] section + ONE
  `pass-agg` dispatch arm in ring_matmul.rs + the one-line
  freeze_check_uagb1_bg() hook (BD/BE/BF precedent); ADDITIVE
  manifest.rs mode field ONLY; docs/zkmatrix-poc/
  UAGB1_PASS_AGG_REPORT.md; tests/test_uagb1_pass_agg.py
  (additive); this section.
- WILL NOT DO: eval_proof.rs edits (BH's zone — needed diffs filed
  as export rows here); fold.rs internals (public API consumed);
  lookup.rs; the folded masked descent (recorded gap); P1/P3
  masked-act paths; wire format (BI's); edits to existing
  scripts/tests or other ledger sections; push.
- API-CHANGE EXPORTS filed against BH's zone (build-around in
  place, nothing blocked): (1) ClaimKernelCtx/kw_row support for
  MULTIPLE additive kernels per tensor (currently first-match);
  (2) a vw-free streaming kw_row variant (the materialized
  per-value table is O(N_values) K-elems — prohibitive at pass
  scale); both non-blocking for BH's row-column split.
- 2026-08-10 (later): **lane COMPLETE.** All three deliverables
  green + measured + written (UAGB1_PASS_AGG_REPORT.md complete);
  stretch (p95 repeats) NOT taken — each full run is ~1.5 h wall on
  this box and lane BI owns the harness; single-shot numbers
  recorded honestly. Full suite 61/61 OK (717 s, in-lane, incl. the
  new test module) + freeze-check green at the final build with
  EVERY pre-existing digest unmoved. All committed to uagb1-bg; no
  push (per brief).

**VERDICT ROW (BG).** THE COMPOSITION LANDS, END TO END, ON THE
REAL CHECKPOINT — BF's 12-layer v4 pass statement -> BE's folded
families (+ the new folded requant family with public
layer-coefficient MLEs) -> BD's per-group batched opening + eval
proofs (W-C, E-O2-BB enforced), modes P0 AND P2, 12/12 layers at
T = 512, accept = true both modes. **THE TWO PASS NUMBERS
[MEASURED, counted convention, composed-relation scope]:**
  * **Tier N (P0 bare): 426,455 B = 0.407 MiB = 0.1356x the P0
    pass gate** (12 x 262,144 = 3,145,728 B; 35.5 KiB/layer
    amortized) — vs the DERIVED expectation 426,622 B (BA rule,
    executable via `pass-agg expect`): agreement to the
    statement-section byte, every instance kel and group line
    EXACT. 18,581x under BF's wave-path pass (7.38 GiB): the
    opening volume is GONE. The U-AG4 folded W-C 0.3-0.5 MiB
    class [MODEL] is now MEASURED at 0.407 MiB.
  * **Tier Z (P2, the FP-L3 split: weight floor masked ONCE per
    pass, act bare): 1,019,211 B = 0.972 MiB** — vs derived
    1,019,234 B; restarts 0 (F-Z3 logged); F-Z1 corner 2^27.748
    asserted at derive; measured once-per-pass weight-mask
    surcharge = 592,756 B (the FP 4.3 amortization, measured).
    THE 125M-PASS TIER Z OBLIGATION (ledger: "must be DERIVED by
    this round") = this number at composed scope; A1's frozen
    1,114,112 B is the 7B-P3 scope, cited not transferred (the
    125M P2 sits 94,901 B under it; the full-statement [MODEL]
    extension adds ~0.92 MiB of descent lines — finding BG-F1).
  * HONEST SCOPE LABEL (on every print + report S1): composed =
    arithmetic relations (3 folded matmuls + Hadamard + 4 requant)
    + X/z public binding + weight binding via u_0/model identity;
    NOT composed = the table-membership facts (SiLU + range) — the
    folded masked descent stays the recorded unbuilt piece (BE's
    WILL-NOT-DO carried), priced in the expectation BOTH structural
    forms. BG-F1: the design's shared-table fold assumption BREAKS
    at 125M (2 SiLU members + 6 remainder widths -> 9 per-table
    pairs ~0.92 MiB [MODEL] vs the one-pair ~0.11 MiB form).
  * MODE PLUMBING (deliverable 2): manifest::ModeDecl ADDITIVE
    (digest/codec absorb only-when-declared; mode-less digests AND
    wire bytes provably unmoved — freeze row BG-2 + the pre-existing
    BF-2b/2c rows green; ByteReader::peek_u8 the one shared-plumbing
    addition); validation P0..P3 (P2 = exactly the CLS_W8S set);
    P1/P3 REFUSED loudly by the composition layer (E-1..E-5 gap
    named — no silent degradation either direction). P2's residual
    honest gap pre-registered and held: weight-touching ROUND
    POLYNOMIALS ride unmasked (T_blind machinery absent; ~1,664 B
    [MODEL] deltas priced), deployment-grade P2 requires it.
  * BATTERY 14/14 (4,682.8 s, 3 layers T=16 real data): honest P0
    (383,798 B) + P2 (966,462 B, restarts 0); the composed-SEAM leg
    (fold-family claim lie -> REJECT at floor-target THROUGH the
    eval proof); cross-layer Gacc swap -> sc-matmul REJECT;
    floor/OOA (alphabet-isolated)/Tier-Z-response/Tier-Z-image
    tampers; public-claim lie; AZB-10b THREE directions (derive
    refusal + h0-map REJECT + weak-verifier ACCEPT with leak live);
    E-O2-BB build error; mode-plumbing negatives.
  * AZB-11 CANARY 6/6 at the pass group map (E-11 LANDED; 1,777.8
    s): leg 1 static support (runs in EVERY shipped prove+verify as
    an ERROR — deployment-blocking, F-Z3); leg 2 functional
    recompute — act batched claims AND act floor BYTE-EXACT from
    (T_act, challenges) alone (weight witness zeroed; the engine's
    own fixed-coins honest-verifier harness); leg 3 W-perturbation
    invariance (byte-identical act transcript); leg 4 migration F5
    three directions; AZB-11b(i) claim smuggle + (ii) floor fold-in
    both FIRE. AZB-10b leak face EXHIBITED (E-10 group face): the
    weak-accepted migrated act floor (936 vs 921 rings) carries the
    migrated WgT_0 digit rings — an explicit weight functional.
    THE POSITIVE CERT: the P2 bare activation floor is
    weight-independent, demonstrated not asserted.
  * E-O3-BB DISPOSITIONED at the pass statement (not silent): the
    composed path carries NO descent pair, so D-R1 rho-sharing has
    no engine object this wave; BOTH branches priced in the
    expectation; the battery leg transfers to the folded-descent
    build item. E-blocks: E-10 group face + E-11 WIRED here;
    E-6/E-7(i) inherited from BD; E-1..E-5/E-7(ii,iii)/E-8/E-9 NOT
    unlocked (T_blind absent) — stated.
  * FREEZE rows UAGB1-BG-1a..1c + BG-2 both directions (pass
    inventories 7,823,360/3,538,944 digit rings; schedules L9/915-e7
    act, L8/939-e7 weight, 1,368-e4 Tier-Z; F-Z1 corner; mode
    digest/codec discipline); every pre-existing digest unmoved at
    every commit. FINDING BG-F4: the weight floors (939 bare /
    1,368 Tier-Z) EQUAL BD's single-layer values at a 144x witness
    — FP-L1 witness-size independence measured.
  * WALLS [MAC-BOX, NOISY-SHARED, 1T]: P0 commit 380/prove
    4,178/verify 955 s, RSS 38.2 GiB; P2 367/4,122/950 s, RSS 42.9
    GiB. Prover = level-0-dominated (h cross-garbage Theta(n_0*r),
    r at the 64 cap, + 3 O(N_limb) kernel passes); verifier = BD's
    recorded O(N_limb) claim-kernel wall at pass scale (this lane
    consumed the pre-split eval_proof API; BH's row-column split is
    the fix, bytes unaffected).
  * FIXED IN-LANE (findings BG-F5-class): E-11 derive refusal
    converted from panic to observable deployment-blocking verdict;
    PublicClaimLie re-plumbed (lie on the wire, truth in the batch);
    mode-decl decode gated on the 0x4D section tag so the pre-BG
    codec negative vectors keep their exact errors (regression
    caught by the suite, fixed, statement-codec + fuzz green).
  * Report: docs/zkmatrix-poc/UAGB1_PASS_AGG_REPORT.md (headlines,
    construction, derived expectation w/ executable printer, both
    battery tables, E-block table, walls/findings BG-F1..F5,
    exports, reproduction). Deliverables checkbox left for the
    orchestrator.

## Agent BH status (wt-uagb1-bh)

- 2026-08-10 PLAN COMMIT (before any code; skeleton-commit-first).
  Read phase COMPLETE: ledger in full; UAGB1_AGG_STACK_REPORT.md
  (Section 6 item 1 = my target: verify 17.4 s at 512x768x2048, the
  O(N_limb) claim-kernel materialization; Section 2 wire objects);
  M125_PASS_REPORT.md (34.3 s/layer pass verify; BF-F3 gkr_masked
  2^(d-1)-4 cap -> dw=22 dummy padding ~2x tree work);
  AGGREGATION_PARAMS_DESIGN.md 2.2/5.3 (the designed verifier =
  level-1 statement pass ~ kappa*(z+t+w) MACs, NEVER the level-0
  functional; Greyhound two-tier row-column structure);
  AGGREGATION_LITERATURE.md 3.1-3.2; src/ring/eval_proof.rs WHOLE
  (mine this wave); src/ring/gkr_masked.rs WHOLE (mine);
  [UAGB1-BD] section of ring_matmul.rs (agg_prove_group /
  agg_verify_group / tier-z / battery / bench — read, not owned).
- READ-PHASE FINDING binding the D1 plan (the row-column split has
  an exact seam): in the RECURSED verifier path, phi_0 (n_0 rings,
  materialized at n_0 x 16 ring-mults after an N_values K-mult vw
  table) is consumed ONLY through compute_psi(phi_0, chunk_0, c_0)
  inside transport_level at level 1 — psi_0 (chunk_0 rings) is the
  single phi_0-derived object the whole chain needs (for L = 1
  schedules the floor L1/Tier-Z families need the SAME psi_0). The
  claim kernel is rank-1 per tensor (row_kernel x col_kernel) and
  kf.mul is F_q-bilinear, so with cols % 128 == 0 (all 125M-shape
  tensors; per-tensor fallback to the generic per-ring path
  otherwise): phi_0[v] = radix_limb * sum_d beta[row][d] *
  conjQ[cb][d] with beta[row][d] = sum_c L(row_ker[row])[d][c] *
  alpha_c (scalar-scaled alpha sums, no ring-mults) and
  conjQ[cb][d] = conj(d-coordinate slice of the col-kernel block) —
  psi_0 then assembles at ~(n_value_rings x 16) ring-mults +
  n_0 radix-scale-adds instead of (N_values K-mults + n_0 x 16
  ring-mults + n_0 fold mults). Exact mod-q identity (sum
  regrouping only) => bit-identical psi_0 => bit-identical
  transcripts and verdicts BY CONSTRUCTION; asserted by
  differential legs anyway.
- D1 PLAN (row-column split, additive in eval_proof.rs + minimal
  MARKED [UAGB1-BH] edits inside agg_verify_group / the two
  floor-family call sites — the smallest possible BD-zone touch,
  each line marked; prover UNTOUCHED this deliverable):
  eval_proof.rs gains phi0_full (reference materialization via the
  existing ClaimKernelCtx — the differential oracle),
  psi_level0_factored (the split; per-tensor aligned/generic
  branches), transport_level_from_psi (transport_level refactored
  to delegate — public signature/behavior of transport_level
  UNCHANGED); agg_verify_group's recursed path drops vw + phi_0 and
  feeds psi_0 to level-1 transport (degenerate path untouched);
  agg_floor_family_values takes psi (both call sites compute it —
  the prover's Tier-Z restart loop also stops recomputing an
  identical psi per attempt, values unchanged). Differential
  battery (my own [UAGB1-BH] section + `bh-verifier` dispatch arm):
  psi_level0_factored == compute_psi(phi0_full) EXACT at aligned +
  misaligned (64x96x128 A-tensor cols 96) + forced-1-level +
  full-shape legs; BD's agg-matmul battery re-run green (23 legs =
  every tamper/F5 leg through the new verifier, verdicts +
  first_fail strings asserted by the battery itself); full-shape
  bare bytes must stay EXACTLY 344,318 (wire untouched);
  before/after verify timings at 512x768x2048 bare + Tier-Z
  [MAC-BOX, NOISY-SHARED — siblings BG/BI run this wave], kernel-
  phase ratio measured standalone (reference vs factored psi_0 at
  the full shape). The 2 s line binds the AGGREGATE verifier on the
  REFERENCE box — I report complexity-fix ratios, never the
  contract claim.
- D2 PLAN (BF-F3, gkr_masked.rs): lift the blinded_witness_tree
  capacity 2^(d-1)-4 -> n-8 by the SPLIT fill (left block
  [0, n/2-4), overflow at [n/2, n/2 + rest), rest <= n/2-4) — the
  exact table_row_positions precedent extended to witness columns;
  <= cap layout BIT-IDENTICAL to today (same contiguous fill, same
  blinder installs — the old assert becomes the n-8 gate);
  blinder_positions / mask counts / transcript-shape functions /
  masked_gkr_prove / masked_gkr_verify UNTOUCHED (they are
  layout-agnostic). New pub witness_leaf_positions(n_used, n) is
  the public map pin-builders consume. Battery (my section):
  <= cap layout identity vs an inline reference of the old fill;
  > cap honest END-TO-END masked descent pair at the REAL pass
  shape (2^20 fused leaves, dt = 9) with root cross-check + leaf
  MLE claims recomputed against the split layout (the house
  battery pin-modelling convention); tamper legs (right-half leaf
  tamper REJECT; contiguous-map pin mismatch REJECT); measured
  dw=22 (old cap) vs dw=21 (split) at 2^20 leaves: tree build +
  prove + verify wall clock, the tree-work ratio, and the
  masked_transcript_totals byte delta. m125 rig wiring is BF-zone
  (p3_dw-class layouts) — machinery + measured demonstration land
  here, the rig switch is an EXPORT to the orchestrator.
- D3 PLAN: re-run ALL engine batteries at my HEAD green
  (uagb1-digit-battery, matmul-statement battery, agg-matmul
  battery, ixf-fold battery, m125-pass v4-battery + battery smoke
  on the present exports), full python suite + freeze-check (all
  pre-existing digests unmoved), long runs backgrounded.
- D4 STRETCH (only if 1-3 green): prover-side phi_0 via the same
  factored helper (values identical, ~l0-fold cut of the prover's
  second pass); any further verifier hot-spot with measured
  evidence.
- WILL NOT DO: prover protocol/wire changes; fold.rs / lookup.rs /
  manifest.rs / pass-integration sections; edits to existing
  scripts/tests or other ledger sections; blinder_positions or any
  frozen-row constant; the contract verify claim; pushes.
- BASELINE at a714935 on this box: cargo release GREEN (42.5 s);
  baseline full-shape bare + tierz + freeze-check runs launched
  (results recorded at the first code commit).
- 2026-08-10 (later): **lane COMPLETE.** All three deliverables
  landed and measured; stretch D4 declared NOT TAKEN (the remaining
  hot spots are the DESIGNED level-1 pass + seed-XOF CRS expansion —
  the XOF lives outside my file zone; measured and exported, not
  patched). Full suite green in-lane: **58 tests OK, 430.4 s**
  (python3 -m unittest discover -s tests, quiesced, incl. the Rust
  self-test battery 246.0 s and every uagb1-* module — zero
  ERROR/FAIL lines); freeze-check green at every commit, every
  pre-existing digest unmoved; everything committed to uagb1-bh;
  no push.

**VERDICT ROW (BH).** THE VERIFIER'S O(N_limb) WALL IS CLOSED —
bit-identically. D1 row-column split LANDED (the Greyhound structure,
PARAMS 2.2/5.3): in the recursed path Phi_0 is consumed ONLY through
Psi_0 (transport_level's psi seam, now public as
transport_level_from_psi; floor/Tier-Z L1 at L = 1 need the same
object), and psi_level0_factored computes Psi_0 from the rank-1
kernel factors (K-mult F_q-bilinearity + conj Z_q-linearity; exact
mod-q regrouping; per-tensor generic branch for misaligned cols) —
the verifier never materializes Phi_0 (192,512 rings at the 125M
layer shape) or the 3.0M-value K-mult weight table. MEASURED
[MAC-BOX, quiesced, 512x768x2048]: bare verify **17.16 -> 5.31 s
(3.23x)**, Tier-Z verify **17.46 -> 5.38 s (3.25x)**, claim-kernel
phase in isolation **13.96 -> 1.62 s (8.6x; weight 7.8x, act
8.8x)**, prove/commit/bytes UNCHANGED (344,318 B bare / 1,527,878 B
Tier-Z, byte-identical — the wire, transcript edges, and soundness
structure untouched; the 2 s line binds the AGGREGATE verifier on
the REFERENCE box and is NOT claimed). Differential evidence:
bh-verifier battery 21/21 (factored == the verbatim wave-2 reference
pipeline EXACTLY at aligned/misaligned/multi-tensor/forced-1-and-
2-level shapes + full shape inside the kernel bench, twice; e2e
honest + OOA-first-fail identical), BD's unmodified agg-matmul
battery all 22 source legs green on the new verifier (194 s; BD
prose said 23 — source carries 22 assert legs, a prose nit). D2
BF-F3 LANDED: blinded_witness_tree capacity 2^(d-1)-4 -> n-8 by the
split fill (witness_leaf_positions, the frozen table_row_positions
discipline extended to witness columns; <= cap layout BIT-IDENTICAL
incl. leaf-vector equality legs; blinder positions/mask
families/prove/verify untouched). MEASURED at the 2^20 pass shape:
depth 22 -> 21 = **tree 2.08x, prove 2.03x, tree+prove 2.03x** —
BF-F3's ~2x removed — plus **-6,208 B per descent-pair transcript**
(1,445 -> 1,348 K-el with the dt = 9 table side). Beyond-cap
battery: honest e2e masked descent (roots + split-layout leaf P/Q
pins), right-block leaf tamper REJECT, wrong-map (contiguous
assumption) REJECT — the position map is load-bearing, demonstrated.
D3: ALL engine batteries green at this HEAD — uagb1-digit-battery
33 ok / matmul-statement 10 ok / agg-matmul 22 ok / ixf-fold 20 ok /
m125-pass v4-battery 19 ok / m125-pass battery smoke on real
layer-0/1 exports (73.7 s) / freeze-check 87 rows (pre-existing
digests unmoved at every commit). API: eval_proof.rs public surface
SOURCE-COMPATIBLE (nothing removed or re-signed; additions only —
BG consumes as-is); BD-zone edits minimal + [UAGB1-BH]-marked
(verifier psi seam, agg_floor_family_values takes psi at both call
sites, Tier-Z prover psi hoisted out of the restart loop — BH-F2,
values identical; one stale bench print corrected). FINDINGS:
BH-F1 the wall WAS the claim kernel (81% of wave-2 verify; residual
5.3 s = measured 1.03 s level-0 seed-XOF CRS expansion + the
designed level-1 transport pass + deeper levels + floor checks —
none O(N_limb); prover keeps its O(N_limb) passes by design);
BH-F2 the Tier-Z restart loop recomputed a challenge-fixed Psi per
attempt (hoisted); BH-F3 the BF-F3 depth drop is also a transcript
byte win (-6,208 B/pair, kel freeze rows pin the function, unmoved).
EXPORTS: (a) pass-rig wiring of the split map (BF-zone p3_dw-class
layouts + leaf-pin builders; wrong-map leg = the acceptance test;
~2x of the descents' 25.5% prove share ~ 10-12% pass-prove class +
6,208 B x 8 pairs/layer counted [MODEL until wired]) — orchestrator/
next wave; (b) the residual verifier profile (CRS XOF + level-1
pass) as the next hot spots if the aggregate verifier needs them —
XofReader is outside BH's file zone. Report:
docs/zkmatrix-poc/UAGB1_VERIFIER_REPORT.md (algebra, tables,
battery evidence, reproduction). Deliverables checkbox left for the
orchestrator.

## Agent BI status (wt-uagb1-bi)

- 2026-08-10 PLAN COMMIT (before any code; skeleton-commit-first).
  Read phase COMPLETE: ledger in full (wave 1-3 sections, lane
  discipline, machine note); TARGET_CONTRACT.md Section 4 (the M-05
  finding: "budget binds once a canonical encoding exists"; the
  statistic: p95 over >= 20 warm runs, p50 alongside, cold-start
  separate) + Amendment A1 tiers; UAGB1_AGG_STACK_REPORT.md (byte
  table S3, Tier-Z S5, counted conventions); UAGB1_FOLD_REPORT.md
  (S5.2/5.4 byte model + capstone decomposition); M125_PASS_REPORT.md
  (v4 statement 26,116 B cv2, v3 digest 7b913619 unmoved obligation);
  engine surfaces: eval_proof.rs (GroupEvalProof + counted_bytes),
  ct_engine.rs (CtRoundProof, masked splitter reveal type
  Vec<Vec<(usize,i64)>>), fold.rs, sumcheck.rs (SumcheckProof),
  manifest.rs (encode/decode cv1/cv2, digest), the BD/BE/BF rig
  drivers in ring_matmul.rs (same-module private fns REUSABLE from my
  section — no signature changes needed), freeze_check chain (BF's
  one-line-hook precedent). Baseline on this box at plan time: cargo
  release GREEN (44.7 s warm), freeze-check GREEN (every row), python
  suite launched (result recorded at first code commit).
- D1 PLAN (the canonical wire format, M-05). Spec FIRST in
  docs/zkmatrix-poc/WIRE_FORMAT.md, then src/wire.rs (self-contained
  codec module, path-included from my [UAGB1-BI] section the way
  ring/manifest are). Format "ZKWF v1": magic + u32 version + u16
  artifact kind + field-id (q8_31) envelope; fixed little-endian
  widths; per-kind FIXED section order (tag u16 + u64 len), unknown/
  out-of-order/duplicate/trailing = structured decode REJECT; q31
  poly = 128 x u32 canonical-range coeffs (512 B, count hoisted to
  block header — the counted 4 B/poly prefix disappears); K element
  = 16 x u32 = 64 B ON the counted convention (kept: word-aligned;
  bit-packing would save 3.1% and is declined, stated in spec);
  signed-integer blocks (floor digits, ct-z responses, Tier-Z
  responses) = u32 count + u8 width in {1,2,4,8} + two's-complement
  LE values under a CANONICAL-MINIMAL-WIDTH rule (decoder re-checks
  minimality; re-encode byte-identity by construction) — floor stays
  1 B/coord, Tier-Z stays 4 B/coord, ct-z drops 8 -> 4 B/coord
  (honest values bounded by the wave l2 bound < 2^27; the fold
  transcript's dominant line HALVES — the big serialized-vs-counted
  delta, pre-registered); reveals (u32 wave, i32 centered) = 8 B vs
  12 counted. Artifact kinds: (1) EVAL-PROOF ARTIFACT bare+Tier-Z
  (META shape/crs-seed/flags, STATEMENT = manifest bytes verbatim,
  SUMCHECK, per-group u0/ugh0/b_rows/level_us/floor(+e)/TierZ
  images+response+restarts; tcap diagnostics excluded from wire —
  deterministic FS counter); (2) FOLD TRANSCRIPT (META family/shape,
  STATEMENT, TAGS t1+t2, SUMCHECK, REVEALS, WAVES = per-wave
  h/w1/w_claim/z records, CLOSING) — kind-2 v1 scopes the plain-
  commitment linear-claim record (what the BE rigs emit; richer
  claim classes reserved); (3) STATEMENT WRAP (v3 cv1 / v4 cv2
  bytes verbatim; digest stability ASSERTED — serialization must
  not move 7b913619 / 76dbf204 / any digest); (4) PASS ARTIFACT
  (BG's) — tag allocated, layout spec'd, writer API landed (D3).
  Round-trip tests: encode -> decode -> re-encode byte-identical;
  verify-after-round-trip ACCEPTS from DECODED objects (my own
  honest-path drivers in the [UAGB1-BI] section reuse BD's
  agg_prove_group/agg_verify_group and BE's machinery — same-module
  access, zero signature changes, zero edits in their zones);
  corrupted-byte legs BOTH classes (structural byte -> decode
  REJECT; in-range value byte -> decode OK + verify REJECT; panic=
  abort profile means decode must be panic-free by construction —
  all-Result, every shape/range validated before objects reach a
  verifier). THE TABLE: serialized vs counted at the recorded
  shapes — eval bare + Tier-Z at 512x768x2048 (counted 344,318 /
  1,527,878), fold mm at 12x(64x96x128) battery shape + the
  12x(512x768x2048) capstone (counted 1,406,719,131; run in
  background, honest fallback = derived from the same per-component
  arithmetic validated at the measured smaller shapes), zc mid
  12x(512x256) if wall-clock permits, pass statement (26,116 B cv2).
  Every divergence explained (prefix hoisting, width rule, envelope).
- D2 PLAN (p50/p95 harness + protocol): ONE dispatch arm
  `uagb1-bi` sub-dispatching {wire-battery, wire-bench, bench-stat}.
  bench-stat implements the contract statistic (>= 20 warm, p50 +
  p95 nearest-rank, cold-start = first run after setup, reported
  separately): named in-process workloads `eval-verify [shape]`
  (prove ONCE = setup; N+1 verifies via agg_verify_group),
  `matmul-prove [shape]` (N+1 full uagb1_matmul_run instances,
  per-phase stats from MmCost — prove is the statistic),
  `freeze-check` + generic `spawn <n> -- <argv...>` (subprocess
  whole-invocation timing, applicable to ANY subcommand; spawn
  overhead stated). docs/zkmatrix-poc/MEASUREMENT_PROTOCOL.md: the
  quiesced-machine reference-box protocol (preconditions, fixed run
  order incl. the freeze-check calibration row, recorded fields,
  [MAC-BOX]/[NOISY-SHARED]/reference labeling rules per the ledger
  Machine note, how the full ~55-min reference pass would run — not
  executed this lane). Measured this lane [MAC-BOX, NOISY-SHARED if
  siblings run]: eval-verify at 512x768x2048, matmul-prove at
  128x768x256 (the recorded battery mid shape), freeze-check
  calibration row.
- D3 PLAN (BG's writer API): kind-4 PASS ARTIFACT in WIRE_FORMAT.md
  (mode P0-P3 declaration, statement, per-group eval-proof records
  reusing kind-1 group form, folded-claim records reusing kind-2
  forms, extensible (tag,len) sections with allocated tag space) +
  PassArtifactWriter/Reader in wire.rs (new/add_*/add_raw_section/
  finish; reader returns typed + raw sections). BG may finish after
  me; deferred conformance at the orchestrator's merge expected.
- Shared-zone touches (each ONE line, listed in the report): the
  `uagb1-bi` arm in main's match; `all_ok &= freeze_check_uagb1_bi()`
  in freeze_check (BF precedent). Freeze row UAGB1-BI-1: golden
  wire sample digest pinned both directions (format stability).
  Visibility edits in eval_proof.rs/fold.rs/manifest.rs: expected
  ZERO (all consumed fields already pub; TierZFloor is same-module);
  any that prove necessary will be one-line pub exposures listed
  explicitly.
- WILL NOT DO: edits to BD/BE/BF/BB functions or zones beyond the
  two one-line hooks; lookup.rs / gkr_masked.rs internals; manifest
  codec changes (wire WRAPS manifest bytes; digests must not move);
  existing scripts/tests; other ledger sections; the full 55-min
  reference pass (protocol doc only); pushes.
- 2026-08-10 (later): **lane COMPLETE.** All three deliverables
  landed; wire battery green (full 65.5 s incl. Tier-Z; light face
  rides the suite via tests/test_wire_format.py); freeze-check green
  with UAGB1-BI-1a..c and every pre-existing digest unmoved; FULL
  SUITE 59/59 OK in-lane (437.6 s [NOISY-SHARED-free run at close];
  58 at base + the new wire module); everything committed to
  uagb1-bi. Deliverables checkbox left for the orchestrator.

**VERDICT ROW (BI).** THE CANONICAL WIRE FORMAT EXISTS (M-05
discharged at the recorded artifacts): ZKWF v1 —
docs/zkmatrix-poc/WIRE_FORMAT.md (the byte-level spec, written
first) + src/wire.rs (standalone codec, manifest.rs pattern) +
[UAGB1-BI] drivers/battery/bench in ring_matmul.rs. Format: magic
ZKMXWIRE + u32 version + u16 kind + field id (q8_31) envelope; fixed
little-endian widths; per-kind FIXED section order under u64 length
prefixes; q31 poly = 128 x u32 (counts hoisted — the counted 4 B/poly
prefix disappears); K element = 16 x u32 = 64 B ON the counted
convention (bit-packing declined, stated); signed blocks under a
CANONICAL-MINIMAL-WIDTH rule the decoder re-checks (floor 1 B/coord,
Tier-Z response 4 B/coord, ct-z responses 8 -> 4 B/coord — the
in-memory i64 was never the value range); reveals (u32, i32) = 8 B.
Kinds: 1 = eval-proof artifact bare+Tier-Z (Tier-Z carries the
masked response ONCE in the floor slot — the engine's own semantics);
2 = folded-family transcript (tags + scheduled sumcheck + reveals +
per-wave ct-round records + closing; v1 scopes the plain
linear-claim record the BE rigs emit); 3 = statement wrap (manifest
bytes VERBATIM, digest neutrality structural); 4 = the multi-group
PASS ARTIFACT for lane BG — tags allocated, layout spec'd (mode
P0-P3 + per-group masked flags + kind-1 group records + fold-claim
records + RAW extension subtag space), PassArtifactWriter/Reader
LANDED (deliverable 3; BG conformance deferred to the orchestrator's
merge as briefed). Decode NEVER panics (panic=abort profile): all
Result, every coeff range-checked, width canonicity re-derived,
shapes gated against the expected instance before any derive-time
assert can see wire data.
  * BATTERY (`uagb1-bi wire-battery`, 65.5 s, all green; suite face
    7.7 s): golden-sample canonicality + pinned digest; 10
    structural corruption legs (magic/version/kind/field-id/
    reserved/payload-len/section-tag/section-len/truncation/
    trailing) each REJECTING with the right error; CoeffRange +
    NonCanonicalWidth value legs; kind-1 round trips at degenerate
    AND recursed schedules AND Tier-Z (256x768x2048) — every one
    re-encode byte-identical + verify-after-round-trip ACCEPTS from
    DECODED objects; value corruptions that decode cleanly are
    REJECTED by the verifier at the right gate (floor-alphabet,
    claim-row-eval, floor-outer-binding, tierz-family); kind-2 fold
    round trip + tag corruption -> statement-digest REJECT, z
    corruption -> wave REJECT, reveal corruption -> sum-gate REJECT;
    kind-3 v3+v4 digest-UNMOVED legs + both pairing negatives;
    kind-4 writer round trip + mode-corruption REJECT. Freeze row
    UAGB1-BI-1a..c: golden 51,715 B sha e5c2f998852ff373 pinned both
    directions.
  * **THE TABLE (serialized vs counted, measured by real encoding;
    counted totals reproduce the recorded wave-2 numbers EXACTLY):**
    | artifact (recorded shape) | counted B | serialized B | ratio |
    | eval bare 512x768x2048 | 344,318 | **343,709** | 0.9982 |
    | eval Tier-Z 512x768x2048 | 1,527,878 | **1,527,085** | 0.9995 |
    | eval Tier-Z 256x768x2048 | 1,511,494 | 1,510,701 | 0.9995 |
    | mm fold 12x(64x96x128) | 12,627,383 | 8,314,493 | 0.6584 |
    | mm fold 12x(512x768x2048) CAPSTONE | 1,406,719,131 | **925,578,652** | 0.6580 |
    | v4 pass statement (real) | 26,116 | 26,168 | 1.0020 |
    Per-component tables in WIRE_FORMAT.md S5 + the wire-bench
    output; serialized sub-line arithmetic is cross-ASSERTED against
    every measured encoding. **Budget consequence: the A1-relevant
    lines move < 0.2% — serialized bare eval = 343,709 B = 1.311x
    Tier N (counted said 1.313x); the byte story the trench has been
    telling carries over onto real bytes.** The fold transcript
    serializes at ~0.658x counted (the ct-z 8 -> 4 B halving,
    pre-registered at plan time; z is 68% of that artifact) —
    honesty about the wave-2 artifact, not an A1 line (the composed
    pass artifact replaces the opening volume). The capstone row is
    a full real round trip at 1.4 GB: serialize 0.77 s / deserialize
    0.54 s / verify-FROM-WIRE 60.5 s accept true / RSS 18.3 GiB
    [MAC-BOX]. zc-family driver NOT built (declared): identical
    section forms, transforms validated at two measured mm shapes;
    its recorded mid-shape row lands in the same ~0.658x class.
  * Format decisions that changed budget-relevant numbers (each in
    the spec with rationale): per-poly prefix hoisting (-4 B/poly);
    K-el KEPT at 64 B (counted-identical; -3.1% bit-packing
    declined); canonical-minimal-width signed blocks (ct-z 8 -> 4 B
    — fold artifacts only); reveals 12 -> 8 B; envelope + section
    headers +121 B/kind-1 artifact (+52 statement wrap, +142
    kind-2). Digest neutrality MEASURED on the real object: the
    12-layer v4 pass statement digest 76dbf2040409333e byte-stable
    through the wire round trip; v3 7b913619 pinned unmoved by the
    existing freeze rows (untouched).
  * p50/p95 HARNESS (deliverable 2, contract Section 4 statistic):
    `uagb1-bi bench-stat` — eval-verify (prove-once setup excluded;
    clock = deserialize + full verify), matmul-prove (n+1 full
    honest instances, per-phase from MmCost), freeze-check
    calibration + generic `spawn <n> -- <argv>` for ANY subcommand;
    nearest-rank p50/p95, >= 20 warm, cold-start separate.
    MEASURED [MAC-BOX, non-reference; solo runs]: freeze-check
    calibration cold 0.003 / p50 0.003 / p95 0.004 s (the noise
    floor; freeze-check is 5 ms of pure arithmetic); matmul-prove
    128x768x256 prove cold 1.737 / p50 1.727 / p95 1.733 s (commit
    p50 0.036, verify p50 0.467); **eval-verify 512x768x2048 cold
    17.576 / p50 17.549 / p95 17.574 s over 20 warm** (max/min
    1.003 — quiesced; the BD claim-kernel wall now measured under
    the contract statistic; BH's row-column split is the fix lane).
    docs/zkmatrix-poc/MEASUREMENT_PROTOCOL.md: the quiesced
    reference-box protocol (preconditions, calibration-first order,
    recorded fields, labeling rules per the Machine note, how the
    ~55-min reference pass runs — NOT executed this lane, as
    briefed).
  * Files: src/wire.rs (new), docs/zkmatrix-poc/WIRE_FORMAT.md +
    MEASUREMENT_PROTOCOL.md (new), tests/test_wire_format.py (new,
    additive), [UAGB1-BI] section + freeze_check_uagb1_bi in
    ring_matmul.rs. SHARED-ZONE TOUCHES, complete list: (1) ONE
    dispatch arm `Some("uagb1-bi") => bi_main(..)` in main's match;
    (2) ONE line `all_ok &= freeze_check_uagb1_bi();` in
    freeze_check. **Visibility edits in eval_proof.rs / fold.rs /
    manifest.rs: ZERO** (every consumed field was already pub;
    TierZFloor is same-module). BD/BE/BF zones untouched — my
    drivers REUSE their machinery same-module and replicate only
    driver flow (the honest paths), verified by counted totals
    matching their recorded numbers bit-exactly.
  * Walls/findings: BI-F1 — the counted convention was already
    byte-honest for every A1-relevant line (the wire confirms the
    trench's byte tables at < 0.2%); the one materially counted-vs-
    real gap in the corpus was the fold transcript's 8 B/response
    convention (in-memory width, not value width) — now closed by
    measurement. BI-F2 — verify-from-wire adds < 0.6 s decode at
    1.4 GB and ~1 ms at 344 KB: deserialization is NOT a verifier-
    budget concern at any recorded scale. BI-F3 — freeze-check is
    5 ms end to end, so the calibration row measures spawn+noise
    floor (0.003-0.004 s), useful exactly as intended.

## Wave 3 close (orchestrator, 2026-08-10)

ALL THREE LANES LANDED AND MERGED (BH 876f952, BI dd1ed9a, BG
402da1d). Headlines: pass-level Tier N 426,455 B = 0.407 MiB
(0.1356x gate; U-AG4's 0.3-0.5 MiB [MODEL] class now MEASURED);
Tier Z P2 1,019,211 B = 0.972 MiB; verifier kernel wall 3.2x down
(nothing O(N_limb) left); wire format landed, counted convention
proven honest (< 0.2% on A1 lines); AZB-11 6/6 + AZB-10b in-lane.
Suite 62/62 at the final merge; freeze-check green throughout,
pre-existing digests never moved.

**R-BG1 (OPEN, the one merge-seam defect):** BG's canary
fixed-coins recompute harness feeds multi-tensor concatenated psi
(len 972 = 6x162) into the BH-factored per-chunk API
(ring_matmul.rs:21318 assert, left 972 right 162) — the exact
ClaimKernelCtx one-kernel-per-tensor limit BG's report exported
against BH's zone. SHIPPED paths unaffected (suite green; composed
prove/verify green; canary was 6/6 in-lane pre-BH). Fix = the
additive multi-claim API BG specified; first item of the next
session, before any new lane.

WAVE 4 / FINAL QUEUE: R-BG1 fix + canary re-run green at merged
HEAD; composed-verify re-measure under BH's split (955 s expected
~3x down); BF-F3 m125 rig wiring (~10-12% pass prove); folded
masked descent for table-membership facts (BG-F1 shared-table
break: 9 per-table pairs, the full-statement Tier N ~1.39 MiB
[MODEL] line); T_blind (E-1..E-5) for the P2 round-poly residual;
p50/p95 quiesced pass per MEASUREMENT_PROTOCOL.md; A1 condition
reconciliation + ledger FINAL.

## Wave 4 (opened 2026-08-10 on Victor's console go: "Let's go ahead
## with wave 4") — STAGED

Stage 1 (NOW): lane BJ (wt-uagb1-bj) — integration hardening on the
merged HEAD: (1) R-BG1 FIX: the additive ClaimKernelCtx multi-claim
API exactly as BG's report specified, canary harness call sites
updated, AZB-11 canary 6/6 GREEN at merged HEAD (the gate this
stage exists for); (2) composed-verify re-measure under BH's split
(955 s baseline, expected ~3x); (3) BF-F3 m125 rig wiring per BH's
export (p3_dw layouts + leaf-pin builders; acceptance = the
wrong-map leg; ~10-12% pass-prove class to confirm); dated addenda
to the existing reports, freeze digests unmoved, suite green.

Stage 2 (after BJ merges — lanes branch from the FIXED base to
avoid another R-BG1-class seam): BK = the folded masked descent for
table-membership facts (BG-F1: per-table pairs, the full-statement
Tier N line, [MODEL] ~1.39 MiB to beat or price honestly); BL =
T_blind (E-1..E-5) for the P2 round-poly residual + the remaining
AZB E-blocks it unlocks. Then the quiesced p50/p95 pass + A1
reconciliation + ledger FINAL (orchestrator).

STAGING OVERRIDDEN 2026-08-10 (Victor, console: "Go ahead and
Launch multiple agents so we can expidite the process"): BK + BL
launch NOW from fc3fa8f in parallel with BJ, plus PV-S2 (provenance
pillar, zero engine overlap). Seam mitigation: strict zones — BJ
owns eval_proof.rs + the BG canary call sites + BF rig wiring; BK
owns lookup.rs + a NEW descent-fold module + its own section (NO
eval_proof edits — needs filed as exports; BJ's multi-claim API is
coming, consume via public surface); BL owns pass_agg.rs + a NEW
T_blind module + its own section (avoid the canary harness
functions, BJ's this stage). Merge order: BJ -> BL -> BK,
orchestrator resolves dispatch/EOF seams per the established
recipe.

- BK (folded masked descent, wt-uagb1-bk): the table-membership
  facts (SiLU + range) into the composed artifact — per-table
  descent pairs (BG-F1: 2 SiLU members + 6 remainder widths at
  125M), folded per FP-L2 mask-then-fold, masked per the U-K5c
  lineage; beat or honestly price the [MODEL] full-statement lines
  (Tier N ~1.39 MiB / P2 ~1.98 MiB); battery w/ per-table tamper
  legs + the E-O3-BB transferred leg.
- BL (T_blind, wt-uagb1-bl): E-1..E-5 — T_blind masking for the
  weight-touching round polynomials in the composed P2 path (the
  ~1,664 B [MODEL] residual BG priced), I-6-compliant (T_blind +
  masked sumcheck only), unlocking the remaining AZB E-blocks;
  measured surcharge + battery legs.
- PV-S2 (music pillar, wt-pv-s2): per
  docs/provenance/MUSIC_PROVENANCE_POC.md Section 7 — WAV I/O +
  session evidence objects + block-chained Pi1 at song scale,
  reference-params measurement; no engine files touched.

## Agent BJ status (wt-uagb1-bj)

- 2026-08-10 PLAN COMMIT (skeleton-commit-first; read phase COMPLETE:
  ledger wave-3 close + wave-4 brief; UAGB1_PASS_AGG_REPORT 2.2/6/7.4
  (the ClaimKernelCtx one-kernel-per-tensor export + the additive
  GroupClaims built-around + canary 6/6 design); UAGB1_VERIFIER_REPORT
  1-2 (the row-column split, transport_level_from_psi, the BF-F3
  capacity lift + Section 2.4 export); eval_proof.rs (ClaimKernelCtx,
  psi_level0_factored, transport_level/_from_psi, compute_psi,
  agg_floor_family_values seam); pass_agg.rs GroupClaims (read-only,
  not mine); ring_matmul.rs [UAGB1-BG] bg_prove_group/bg_verify_group/
  bg_pass_run/canary + [UAGB1-BD] post-BH agg_verify_group (the
  reference wiring shape) + [UAGB1-BF] bf_dw_for/bf_layout/leaf_pins;
  gkr_masked.rs witness_leaf_positions/blinded_witness_tree;
  freeze_check_uagb1_bf/bg (no row pins dw/bytes I touch)).
- R-BG1 ROOT CAUSE (pinned by read, to be confirmed by reproduce):
  BH's merge changed agg_floor_family_values's last parameter from
  phi (level array, r*chunk rings) to psi (per-chunk, chunk rings —
  assert at ring_matmul.rs:21318). BD's call sites were updated by
  BH; BG's bg_verify_group Tier-Z arm (written pre-BH, merged after)
  still passes &phi_cur (len r*chunk = 6x162 = 972 at the canary
  shape) — every P2 composed VERIFY panics there; P0 verify and the
  P2 PROVER (agg_tier_z_mask_floor kept its phi parameter) are
  unaffected — consistent with the wave-3 close's "shipped paths
  unaffected" (P0 composed + suite green; the canary is the first P2
  verify at merged HEAD).
- D1 PLAN (R-BG1 fix): eval_proof.rs ADDITIVE ONLY — MultiClaimKernel
  {tensor_idx, scale, Rc row/col kernels} (BG's ClaimContrib shape) +
  psi_level0_factored_multi (the additive multi-claim generalization
  of the row-column split: per tensor SUM over its kernels, scale
  folded into the row factor; aligned + generic branches; vw-free —
  subsumes BG export item 2) + phi0_reference_multi (differential
  oracle). ClaimKernelCtx/psi_level0_factored/transport_level*
  UNTOUCHED (BD's path byte-identical). ring_matmul.rs [UAGB1-BG]
  call sites: bg_verify_group rewired to BD's post-BH shape (psi0
  factored-multi after c0; transport_level_from_psi at level 1;
  psi_floor = psi0 at 1-level schedules else compute_psi of the
  transported phi; Tier-Z arm passes psi_floor — THE FIX; bare arm
  consumes the same psi_floor). bg_prove_group untouched (its phi
  materialization feeds bg_level_h by design, the BH prover
  posture). GATE: pass-agg canary 6/6 GREEN at HEAD from the
  worktree root; pass-agg battery re-run for the seam legs
  (wall-clock permitting — full 14 legs preferred since the rewire
  touches every composed verify; honest statement of what ran).
- D2 PLAN (composed-verify re-measure): pass-agg prove 12 512 p0 at
  HEAD, single-shot honest [MAC-BOX], backgrounded (~70 min prove +
  verify in one invocation — no serialized-artifact reverify path
  exists in the BG rig; stated as such); record verify_s vs the
  955 s pre-split baseline + ratio in a dated addendum to
  UAGB1_PASS_AGG_REPORT.md. The rewire is exactly what lets the
  composed verifier ride BH's split (pre-fix it materializes phi via
  bg_kernel_pass — the O(n_0) claim-kernel wall at pass scale).
- D3 PLAN (BF-F3 wiring per BH's 2.4 export): bf_dw_for -> lifted
  capacity (smallest d with 2^d - 8 >= n, the witness_leaf_positions
  contract; T=512: dw 22->21 on the six 2^20-class instances, 20->19
  on the two nd instances); leaf_pins closure -> the public map
  (hw + committed-column/pair weights at witness_leaf_positions;
  ddw complement form unchanged); prover trees already ride the map
  inside blinded_witness_tree. Acceptance: NEW wrong-map battery leg
  (BfTamper::WrongMap — honest proof, verifier leaf pins computed
  under the contiguous assumption -> REJECT in the wave rounds;
  asserted non-identity map at battery shape). Measure [MAC-BOX]:
  m125-pass battery smoke + m125-pass prove 0 BEFORE (baseline at
  the fixed base) and AFTER; expected ~10-12% pass-prove class +
  -6,208 B per (22->21, dt 9) pair x6 + the (20->19) delta x2 per
  layer; dated addendum to M125_PASS_REPORT.md (the rig's own
  report). KNOWN DERIVED-LINE MOVEMENT (recorded, not hidden):
  bg_expect's 125M-STRUCTURAL [MODEL] descent lines ride bf_dw_for
  and will shift down at the lifted capacity — the ~1.39 MiB
  full-statement line moves; BK's brief number gets the update in
  the addendum + verdict row. No freeze row pins these (checked
  freeze_check_uagb1_bf/bg).
- GATES at HEAD: cargo build --release; freeze-check green with
  every pre-existing digest unmoved; full python suite (62 at base)
  from the worktree root; canary 6/6.
- WILL NOT DO: pass_agg.rs / fold.rs / lookup.rs / manifest.rs /
  wire.rs edits; p3_dw (the U-K5c us1 path with serialized frozen
  fixtures); restructuring BH's factored functions or BD's call
  sites; other ledger sections; existing scripts/tests; push.
- 2026-08-11 MID-LANE STATUS: R-BG1 REPRODUCED at the merged base
  exactly as pinned (assert 972 vs 162, bg_pass_run ->
  bg_verify_group -> agg_floor_family_values:21318, backtrace on
  file) then FIXED (D1 landed, commit d4c7dd4): eval_proof.rs
  additive MultiClaimKernel + psi_level0_factored_multi +
  phi0_reference_multi; bg_verify_group on BD's post-BH factored
  shape; NEW `pass-agg seam` differential 12/12 (46.3 s) — the
  factored-multi Psi_0 == compute_psi(bg_kernel_pass phi) on REAL
  groups (act 42 kernels / weight 9, e0=1) + misaligned generic
  branch + per-ring oracle + non-vacuity. GATE MET: `pass-agg
  canary` 6/6 GREEN at the fixed HEAD, 1,621.9 s [MAC-BOX,
  NOISY-SHARED], AZB-10b exhibit intact (936 vs 921). D3 LANDED
  (commit 46652b4): bf_dw_for -> capacity n-8 (T=512 dw 22->21 x6,
  20->19 x2), leaf_pins on witness_leaf_positions, WrongMap
  acceptance leg REJECTS in the wave rounds w/ non-identity
  precondition — m125-pass battery small 8/8 (558.2 s,
  NOISY-SHARED); derived [MODEL] line movement recorded (structural
  959,232 -> 898,496 B; full-statement Tier N 1,385,854 ->
  1,325,118 B). IN FLIGHT: quiet sequential measurement phase
  (m125 smoke + prove-0 before/after; then the composed 12-layer
  P0 re-measure); then pass-agg battery + canary re-run at final
  HEAD + suite + freeze-check; addenda drafted in both reports
  (measured tables pending).
- 2026-08-11 **LANE COMPLETE. VERDICT ROW (BJ).**
  * **D1 R-BG1 FIXED, gate MET.** Defect reproduced at the merged
    base with backtrace (assert 972 vs 162 at
    agg_floor_family_values:21318 via bg_verify_group — the Tier-Z
    arm fed phi (r x chunk) into BH's psi-shaped parameter; every
    composed P2 VERIFY panicked at merged HEAD; P0 + prover
    unaffected). Fix = BG's export, landed ADDITIVELY in
    eval_proof.rs ([UAGB1-BJ] MultiClaimKernel +
    psi_level0_factored_multi + phi0_reference_multi — scale folds
    into the row factor, contributions add ring-linearly; vw-free;
    ClaimKernelCtx/psi_level0_factored/transport_level*/BD-BH call
    sites untouched) + bg_verify_group rewired to BD's post-BH
    factored shape (psi0 factored-multi; transport_level_from_psi
    at level 1; psi_floor to BOTH floor branches). NEW `pass-agg
    seam` differential 12/12 (46.3 s): factored-multi ==
    compute_psi(bg_kernel_pass phi) on REAL groups (act 42
    kernels / weight 9, e0=1 branch) + misaligned 64x96 generic
    branch L2/L1 + per-ring oracle + perturbed-scale non-vacuity.
    **Canary 6/6 GREEN TWICE (1,621.9 s at the fix commit; 1,600.9
    s at the final HEAD)** with the AZB-10b exhibit intact (936 vs
    921). **pass-agg battery 14/14 at the final HEAD** (4,177.6 s
    [NOISY-SHARED]): honest P0/P2 counted bytes reproduce wave 3
    EXACTLY (383,798 / 966,462 B); the Tier-Z tamper REJECTs now
    RUN (they panicked pre-fix); every first-fail string as
    recorded.
  * **D2 COMPOSED-VERIFY RE-MEASURED under BH's split: 955.2 s ->
    199.6 s = 4.79x** (12 layers, T=512, P0, single-shot, fresh
    full prove+verify in one invocation — no serialized re-verify
    path exists in the BG rig, stated; [MAC-BOX, NOISY-SHARED —
    BK/BL ran concurrently; 99.6% CPU user-dominated]). Prove
    4,117.4 s / commit 375.4 s (~1x, untouched); **counted bytes
    426,455 B and statement digest 6a2b52f5.. BYTE-IDENTICAL** to
    wave 3, every byte line reproduced. Beats the queued "~3x
    expected" — at pass scale the removed multi-claim kernel pass
    was a bigger verify share than BD's single-kernel wall. RSS
    40.8 GiB (peak sits in the untouched prover). Dated addendum:
    UAGB1_PASS_AGG_REPORT.md Section 9.
  * **D3 BF-F3 WIRED into the m125 rig per BH's 2.4 export:**
    bf_dw_for -> split-fill capacity n-8 (T=512: dw 22->21 x6
    instances, 20->19 x2; smoke T=16: 17->16, 15->14); leaf_pins
    witness weights on the PUBLIC witness_leaf_positions map
    (trees already rode it). **Acceptance leg PASSES: WrongMap
    (honest proof, contiguous-assumption verifier pins) REJECTS in
    the wave rounds** with statement/matmuls/roots green +
    non-identity precondition — m125-pass battery small 8/8
    (558.2 s). **Measured effect [MAC-BOX single-shot]: layer-0
    prove 288.5 -> 250.4 s = -13.2% (the exported ~10-12% class),
    lkp phase 69.9 -> 35.1 s = 1.99x, verify 34.6 -> 31.9 s,
    descent transcripts -48,640 B/layer (= 6 x 6,208 + 2 x 5,696,
    exact kel arithmetic)**; statement digest stable. Finding
    BJ-F1: T=16 smoke +6.9 s from the first-fit wave repack
    (40->39 fuller waves — small-shape artifact; T=512 wave count
    unchanged at 127, all phases down). Derived-line movement
    recorded: 125M-STRUCTURAL [MODEL] 959,232 -> 898,496 B;
    FULL-STATEMENT Tier N 1,385,854 -> 1,325,118 B, P2 1,978,466
    -> 1,917,730 B (BK targets the UPDATED lines). Dated addendum:
    M125_PASS_REPORT.md Section 9 (+ cross-note in PASS_AGG 9.5).
  * **D4 GATES at the final HEAD: cargo build --release green;
    freeze-check green (exit 0, every pre-existing digest
    unmoved); python suite Ran 62 tests OK (674.0 s, incl.
    self-test 239.1 s); canary 6/6.** Machine notes: all timings
    [MAC-BOX, non-reference]; the wave-4 stage-2 lanes (BK/BL)
    launched on this box mid-lane — measurement labels state the
    overlap per run (D3 BEFORE quiet / AFTER tail-overlapped,
    user-time consistent; D2 NOISY-SHARED like its wave-3
    baseline). One harness-side note: a background measurement
    script was killed mid-composed-run by the runner (~40 min
    lost); re-run detached (nohup) to completion — no engine
    artifact was affected.
  * FILES: eval_proof.rs (additive [UAGB1-BJ] block only),
    ring_matmul.rs ([UAGB1-BG] verifier call sites + bg_multi_kernels
    + `pass-agg seam` arm + [UAGB1-BF] bf_dw_for/leaf_pins/WrongMap
    leg), dated addenda in UAGB1_PASS_AGG_REPORT.md +
    M125_PASS_REPORT.md, this section. NOT touched: pass_agg.rs,
    fold.rs, lookup.rs, manifest.rs, wire.rs, gkr_masked.rs (the
    wiring needed no library change), p3_dw/us1, other ledger
    sections, existing scripts/tests. Deliverables checkbox left
    for the orchestrator; wave-4 stage 2 (BK/BL) proceeds from the
    fixed base.
  * MERGE-RECONCILIATION NOTE (orchestrator ask, for the BJ->BL
    ruling): my fix lands AT THE bg_verify_group CALL SITE ITSELF —
    the SHIPPED composed verifier every P0/P2 verify runs through
    (pass-agg prove/battery/canary all ride it) — NOT a
    canary-harness-only patch. It confirms BK-F2 (the shipped
    Tier-Z P2 verify panic pre-exists on the merged base; P0
    unaffected) and REPAIRS it: the Tier-Z arm now receives
    psi_floor, and the whole recursed path additionally rides BH's
    split via the additive multi-claim API BG's export specified
    (psi_level0_factored_multi; transport_level_from_psi at level
    1) — evidence: seam differential 12/12, canary 6/6 twice,
    battery 14/14 with the Tier-Z REJECT legs reachable again, and
    the 4.79x composed-verify drop. Versus BL-F1 (BL independently
    fixed the same seam in its own lane): if BL's form is the
    minimal psi insertion at the call site, this fix SUBSUMES it
    functionally (same corrected semantics, plus the exported API
    + the split ride + the measurements); if BL's form also
    restructured the verifier, reconcile on the invariant that
    agg_floor_family_values receives per-chunk psi of
    plan_last.chunk rings and the battery/canary verdicts + wave-3
    byte identity (383,798 / 966,462 / 426,455 B, digest
    6a2b52f5..) — all reproduced at my HEAD — are the acceptance
    tests either way. Keep-or-subsume is the orchestrator's call
    at the BJ->BL merge.

## Agent BK status (wt-uagb1-bk)

- 2026-08-10 PLAN COMMIT (before any code; read phase COMPLETE: ledger
  wave-3 close + wave-4 zones; UAGB1_PASS_AGG_REPORT (BG-F1 9-pair
  [MODEL] inventory, Section 4 descent lines, 7.1 E-O3-BB transfer);
  FP-L2/A5-A8 + F-Z3 in AGGREGATION_FOLD_PRIVACY_PRICING; M4_LOOKUP_
  DESIGN Sections 4-5 (characteristic ceiling + the per-layer-instance
  batching DECISION); M4_LOOKUP_ZK_DESIGN 3.1-3.4 (U-K5c masks/
  blinders/pins); D-R1 in AGGREGATION_ENCODING_DESIGN 8.3; engine:
  gkr_masked.rs (masked_gkr_prove/verify multi-tree eq-batching,
  inst-major joint index CONFIRMED at masked_rounds_scalar), lookup.rs
  pins, fold.rs, eval_proof.rs public API, pass_agg.rs GroupClaims,
  bf_* chain/instances, bg_* composed run end to end).
- **TWO ENGINE GATES BIND THE DESIGN (pre-registered as findings):**
  (1) LKP-2 ceiling `ceiling_gate_ok(n*64 < q)` caps any one LogUp
  instance at depth <= 24 at q31; (2) the AUDITED K9 packed-table cap
  `K9_MAX_LEAVES = 2^25` (raisable only with a new integer-bound
  proof — not this lane). BG-F1's [MODEL] kel-fit lines priced
  MONOLITHIC depth-25/26 folded trees — both gates FORBID that form
  (silu-m3 dw25, narrowing dw26, rem-w8 dw25). The buildable folded
  form is M4 Section 5's OWN decided shape: per-instance trees at a
  shared depth, eq-batched into ONE masked descent via the engine's
  multi-tree masked_gkr_prove (e_bits = instance vars = the IXF index
  extension at the descent; pads = neutral trees, 12->16-class per
  F-IF1). Per-instance m columns keep the ceiling per-layer-class;
  per-instance root cross-checks keep isolation.
- **THE RULING (deliverable 1, derived from the real statement —
  M125_EXP shifts, never the [MODEL] table):** widths per (layer,
  edge): g: w7 x2, w8 x9, w9 x1; u: w7 x2, w8 x6, w9 x4; h: w5 x4,
  w6 x6, w7 x2; z(nd): w6 x1, w7 x4, w8 x2, w9 x2, w10 x3. Pair
  inventory = **10 per-table folded pairs** (BG-F1's 9 re-derived:
  the narrowing family needs TWO pairs under the memory/gate
  discipline): silu-m3 (10 cols, l=8), silu-m4 (2, l=1), nrw-88
  (u8+h8, 24 cols, l=16), nrw-z (12 nd, l=2), rem-w5 (l=2), rem-w6
  (l=4), rem-w7 (l=4), rem-w8 (l=8), rem-w9 (l=4), rem-w10 (l=1) —
  UNIFORM tree depth 22 (dual-nf / multi-nd packing, both halves,
  aligned power-of-2 blocks so every leaf pin is product-form), table
  depth w+1 (silu/narrow 9). Derived transcript expectation (engine
  counter masked_transcript_totals, BA rule): **~16,727 kel =
  1,070,528 B** descent lines — ~12% ABOVE BG's [MODEL] 959,232 B
  (the kel fit underpriced instance quadruples + the depth caps);
  full-statement expectations land ~1.43-1.46 MiB Tier N /
  ~2.05-2.08 MiB P2 vs the [MODEL] 1.39/1.98 — priced honestly,
  exact rows from the derive at build.
- COMPOSITION (deliverable 2): aux material (per-pair m columns,
  blinder columns, witness/table mask coords) = ~40 ADDITIVE act-
  group tensors (~35k digit rings, +0.45% act n0) — inside u_0(T_act)
  hence inside h0_agg BEFORE every challenge = FP-L2 mask-then-fold
  BY CONSTRUCTION; descents run as instances on the rolling pass
  transcript after rq-d; descent-end P/Q pins + G_j/mask openings
  land as GroupClaims contributions into the SAME act batched opening
  (E-O2-BB: still exactly one opening per group; claims fold into the
  existing 16 b_rows — zero wire growth there). P2 untouched on the
  weight side (aux is all act-side; AZB-11 static-support semantics
  preserved). My own composed-run fn in a NEW [UAGB1-BK] ring_matmul
  section (mirrors bg_pass_run's claim layer; REUSES bg_precommit/
  bg_prove_group/bg_verify_group/bg_mle/bg_stack_table verbatim as
  callees — bg_* code, eval_proof.rs, pass_agg.rs, gkr_masked.rs,
  canary harness NOT edited); NEW src/ring/descent_fold.rs (aligned
  leaf layout, tree planning/build, pin-weight builders, derived
  expectations); lookup.rs ADDITIVE helpers (K-elem coordinate
  weights); subcommand `table-descent expect|prove|battery`; one
  dispatch arm + one freeze_check_uagb1_bk() call line (the
  established per-lane seam).
- BATTERY PLAN: honest ACCEPT small shape (3 layers T=16, all 10
  pairs live) P0 + P2; off-table value (remainder bump, the BF
  RangeViolation shape) REJECT isolated at the pair's root
  cross-check; wrong-table-for-exponent (consistent m3<->m4 swap)
  REJECT at the verifier's statement-side table fold; cross-table
  content swap (m/tree swapped between two pairs, self-consistent
  descents) REJECT at the committed-column pins; mask-ordering F5
  pair on the alpha edge (weak transcript seeded pre-u_0(T_act):
  post-alpha crafted m ACCEPTS under the weak verifier — attack
  live; shipped h0 order REJECTS the same craft); per-instance
  Q != 0 + cross-check + ceiling asserts standing. E-O3-BB: THE
  SPLIT IS THE LANDED DESIGN (BG-F1 break case realized per-table) —
  disposition = split branch, priced by the measured per-pair rows
  (the 7B +143,104 B figure cited as scope, not transferred); a
  rho-sharing battery leg has no shared-arm object in this design —
  recorded loud, not silent.
- MEASUREMENT (deliverable 3): full 12x512 P0 + P2 composed runs
  incl. descents [MAC-BOX, NOISY-SHARED — BJ/BL/PV-S2 run
  concurrently]; per-pair measured kel vs derived vs [MODEL]; totals
  vs 426,455/1,019,211 composed baselines and vs the [MODEL]
  full-statement lines; prove/verify wall deltas. Honest-fallback
  ladder: ruling+expect -> small-shape composed accept -> full-shape
  measured -> battery; largest green scope reported if a wall lands.
- WILL NOT DO: eval_proof.rs / pass_agg.rs / fold.rs internals /
  manifest.rs / wire.rs / gkr_masked.rs edits; bg_battery/bg_canary/
  fixed-coins harness call sites (BJ's); other ledger sections;
  existing scripts/tests; K9 cap or ceiling-gate changes; push.
- 2026-08-11 **BK VERDICT ROW (deliverables 1-3 at honest scope;
  gates green; committed 0085003 + follow-ups).**
  * THE RULING LANDED (deliverable 1): BG-F1 re-derived against the
    real M125_EXP statement = **10 per-table folded pairs** (silu-m3
    x10 layers, silu-m4 x2, nrw-88 [u8+h8], nrw-z [z], rem-w5..w10 by
    width). `table-descent expect 12 512` derives every pair plan +
    byte line (freeze row UAGB1-BK-2); the fold/mask ordering is
    FP-L2 mask-then-fold BY CONSTRUCTION (aux in u_0(T_act) in
    h0_agg). **Finding BK-F1:** the [MODEL] monolithic dw25/26 form
    is FORBIDDEN by the engine's OWN frozen gates (LKP-2
    ceiling_gate_ok depth <= 24 at q31; audited K9_MAX_LEAVES 2^25) —
    the eq-batched per-instance form (M4 Section 5's decided shape)
    is the buildable one; freeze row UAGB1-BK-3 pins the cap
    predicates.
  * THE FOLDED MASKED DESCENT COMPOSED (deliverable 2): per-table
    pairs over the 12-layer instances, IXF-folded across layers via
    the engine's multi-tree masked_gkr_prove (e_bits = instance
    extension, neutral pads), masked per the U-K5c lineage,
    descent-end P/Q pins + G_j/mask openings folded into the SAME act
    batched opening (E-O2-BB PRESERVED — no second opening, no new
    outer identity; +0.40% act n0, schedule UNMOVED). Aux is all
    act-side; weight group + P2 weight-floor semantics untouched.
    NEW src/ring/descent_fold.rs (aligned tree layout + factored pin
    publics + derived expectation), lookup.rs additive
    kelem_coord_weights, the [UAGB1-BK] ring_matmul section (composed
    run + battery + expect + one dispatch arm + one freeze_check
    line). eval_proof.rs / pass_agg.rs / fold.rs / gkr_masked.rs /
    manifest.rs / wire.rs NOT edited; bg_* group prove/verify +
    GroupClaims CONSUMED verbatim.
  * THE NUMBERS (deliverable 3): **THE FULL-STATEMENT TIER N PASS IS
    MEASURED — 12 layers, T = 512, real ckpt data, accept = true:
    1,509,911 B = 1.440 MiB = 0.48x the P0 pass gate (2.08x UNDER;
    125,826 B/layer amortized), and measured == derived TO THE BYTE**
    (every pair kel line exact; the act schedule + floor UNMOVED by
    the 31,116 aux digit rings — 915 rings e7 / 9 levels, BG's exact
    line; weight group byte-identical). Walls [MAC-BOX,
    NOISY-SHARED]: commit 384.9 s / prove 4,811.0 s / verify 990.7 s
    = +15% prove / +3.7% verify over BG's composed-scope run for all
    10 pairs. vs the [MODEL] lines: Tier N 1,509,911 vs ~1,385,854
    (+9.0%), P2 derived-from-measured 2,102,667 (= P0 + BG's
    measured 592,756 weight-mask surcharge) vs ~1,978,466 (+6.3%) —
    priced honestly ABOVE both, named cause = BK-F1 (the buildable
    eq-batched form pays per-instance layer-1 quadruples the
    monolithic kel fit omitted; the monolithic form is gate-
    forbidden). Small-shape composed P0: 985,142 B accept
    (342-475 s).
  * E-O3-BB DISPOSITIONED CLOSED: the SPLIT branch is the landed
    design (BG-F1's break case realized per-table) — every range
    width is its own pair, no shared witness arm to rho-share; cost
    MEASURED per-table (the 8 non-SiLU pairs = 872,640 B derived),
    the 7B +143,104 B single-shared-arm figure cited as scope not
    transferred. A rho-sharing battery leg has no object in this
    design; discharged by the landed split + this note, not silent.
  * **Finding BK-F2 (R-BG1 blast radius, BJ's zone, filed to
    FINAL):** on the merged base (INCLUDES BH's split),
    bg_verify_group's Tier-Z (P2) branch passes phi_cur[r*chunk] into
    the post-split floor-family API which asserts psi[chunk]
    (ring_matmul.rs 21326) -> P2 verify PANICS at last-level r>1
    (r=6 at BOTH 3x16 and 12x512). PRE-EXISTING (weight group
    byte-identical to BG's; BG's own `pass-agg prove 3 16 p2` panics
    identically — BG measured P2 pre-split); BJ's R-BG1 fix closes
    it. P0 unaffected; descents verify fully in P0 and are
    mode-independent, so P2 lands as derived + this caveat.
  * eval_proof EXPORT ROW filed: the additive multi-claim
    ClaimKernelCtx BG specified is what the pins want — built AROUND
    it in pass_agg::GroupClaims (streaming kw_value_row), migratable
    verbatim when BJ lands it (non-blocking).
  * BATTERY **5/5 GREEN** (1,806.7 s [MAC-BOX, NOISY-SHARED], 3
    layers T=16 real data): honest-p0 ACCEPT (985,142 B); off-table
    REJECT isolated at pair-cross-check:rem-w10 (the LogUp gate);
    wrong-table REJECT at ct-row-gate (the statement-side fold);
    cross-table m-swap REJECT at floor-target (the act floor chain);
    mask-order A6 binding leg both directions (SHIPPED h0 moves with
    u_0(T_act), WEAK h0 invariant — the FP-L2 edge). **Finding
    BK-F3:** the concrete adaptive blinder forge was attempted but
    NOT exhibited (rejected under both orders — the harness did not
    reproduce the masked-tree root arithmetic); the binding property
    IS demonstrated; honest scope stated in the report.
  * GATES: build green; freeze-check exit 0 (pre-existing digests
    UNMOVED, new rows UAGB1-BK-1/2/3 both directions); **full suite
    62/62 OK (748.7 s) from the worktree root** [MAC-BOX,
    NOISY-SHARED]; report docs/zkmatrix-poc/UAGB1_TABLE_DESCENT_
    REPORT.md. The measured 12x512 full-statement number follows the
    backgrounded run (recorded below when landed).

## Agent BL status (wt-uagb1-bl)

- 2026-08-10 PLAN COMMIT (skeleton-commit-first; read phase COMPLETE:
  ledger wave-3 close + wave-4 zones; UAGB1_PASS_AGG_REPORT (the P2
  residual: weight-touching round polynomials unmasked, T_blind
  absent = E-1..E-5, ~1,664 B [MODEL] = FP 3.2's 4 x 416 B);
  AGGREGATION_ZK_DESIGN 2.2-2.4/3.2 (AZ-L1a mask counting n_g =
  1 + sum d_t, AZ-L1b, AZ-L2a/b selector-extension pads + unit-weight
  claim segment), FP 2.2 (A5-A8 hash edges)/3.2 (mask wire deltas);
  AZB_BATTERY_PLAN S3 E-1..E-9 specs; engine: the [UAGB1-BG] composed
  path end to end (bg_pass_run claim layer -> bg_prove/verify_group),
  pass_agg.rs GroupClaims (tensor_idx-generic — carries blind claims
  unchanged), fold.rs public sumcheck API + sumcheck.rs public
  round_poly/fold/lagrange_eval, digits CLASS_Q31C, kfield
  lane_split/lane_merge, eval_proof plan_schedule/force_levels).
- LEAK INVENTORY at the composed P2 path (what T_blind must cover;
  act side public in P2 by declaration): (1) the 3 matmul instances'
  ROUND POLYNOMIALS (functions of the weight tables); (2) the
  weight-side TERMINALS b* (raw folded-weight MLE values); (3) the
  weight-group CLAIM ROWS b_rows — ct is public by design (= v_batch)
  but the 16 x 127 non-ct coordinates are weight functionals (the
  AZ-L2b batch-value face BG's label subsumed under E-blocks).
- DESIGN TRANSCRIPTION (the plan; masked sumcheck = Libra
  Construction-1 univariate-sum masks per AZ-L1a; pads per AZ-L2a;
  claim segment per AZ-L2b; T_blind commitment = CLASS_Q31C tensors
  APPENDED TO THE WEIGHT GROUP pre-h0 — one u_0 covers T_W ++
  T_blind, so the E-3 "T_blind digest inside h0" edge is realized at
  the u_0/descent face with ZERO extra identity bytes; deviation from
  the design's third-outer-identity shape recorded): per matmul
  instance a mask tensor (n_g x 16 Z_q coords, n_g = 2*lk + 3*lambda
  + 4 incl. the +1 extension round), one pad ring (1 x 128), plus ONE
  claim-segment tensor (16 x 128) per weight group entering b_rows
  DIAGONALLY at unit weight. Instance FS order: v_c -> G pin -> rho
  -> masked rounds (product part via house round_poly arithmetic +
  rho * additive mask part) -> finals -> g_open; extension bit = top
  variable, sched [2;lk]++[3;lambda]++[2], b* pad summand ext* *
  eq_ks[0] * <beta, eq_ry[..128]> (guards asserted, restarts logged);
  masked initial claim v_c + rho*G; end check combine(finals) +
  rho*g_open; g_open/pad/segment ride GroupClaims into the ONE
  weight-group batched opening (E-O2-BB intact), grounded by the
  Tier-Z-masked descent (mask material NEVER in a bare floor — the
  act floor stays blind-free, AZB-11 invariant preserved).
- DERIVED SURCHARGE (counted convention): per masked instance G 64 +
  g_open 64 + ext round 192 = 320 B; x3 + segment value 64 =
  **1,024 B** vs BG's ~1,664 B [MODEL] (the model priced a 4th
  masked instance — the CR-L4 terminal batch sumcheck — which the
  engine composed path replaced by direct nu-RLC; its face here is
  the 64 B claim segment). Committed-only (zero wire): 544 blind
  digit rings at 125M (3x96 + 256) on 3,538,944 — floors expected
  UNCHANGED by BG-F4's regrowth law, verified at derive.
- PLAN: (D1) src/ring/t_blind.rs — MaskSpec (draw/commit/G/round
  contribs/eval/kernel), masked scheduled sumcheck prove/verify
  (house transcript discipline, own labels), pad/segment builders,
  freshness registry (witness digest, T_blind digest — E-5), rank
  certificates (AZ-L1a per instance, AZ-L2a pad diagonal, segment
  diagonal, E-8 block-triangular composition), slot tools via
  lane_split. (D2) surgical mode-gated hooks in the [UAGB1-BG]
  composed path, every touch marked [UAGB1-BL], all defaults
  preserving byte-identical P0/noblind behavior (bg_battery/
  bg_canary untouched and must stay green); BgOpts.t_blind +
  battery-only hooks (h0_salt, stop_after_claims, tblind_unbound,
  nu_early, rho_early, pad_late, reuse, slot_shared, rig_weights);
  BgClaim.blind_parts; BgBundle.tbl wire face; assemble carries the
  unit-weight segment; `pass-agg prove ... p2` flips t_blind ON
  (single marked line — P2 carries the surcharge; noblind P2 remains
  the battery-internal regression config). (D3) [UAGB1-BL] section +
  ONE dispatch arm `t-blind` (expect | prove | battery); AZB legs:
  E-1 (rigged sparse weights, claims-only multi-proof collection,
  exact recovery at the predicted count, rank growth law), E-2
  (blind-on coset + 2 planted wrong tensors explained; derive-time
  AZ-L1a/L1b-sequential/L2a counting canaries in the shipped blind
  path), E-3 (unbound-hook swap ACCEPTS / shipped REJECTS at the
  u_0-descent face — engine realization of the h0 digest edge,
  documented), E-4 (pad-late, nu-early, rho-early F5 pairs), E-5
  (shared-blind differencing recovery at the predicted count vs
  fresh-blind stuck + shipped derive-time reuse REFUSAL), E-7(ii)
  (toy 1-level floor accumulation rank law via a direct LevelPlan
  harness) + E-7(iii) (toy-scale simulator match for the components
  this lane adds; commitments documented computational), E-8
  (block-triangular conditional-rank certificate at derive,
  deployment-blocking), E-9 (slot-shared segment hook leaks
  slot-differences of b_rows / shipped ring-granular draw certified
  per-slot). Freeze rows UAGB1-BL-1a.. (blind inventories, schedule
  vs BG pins, derived surcharge, exposure/dim counts) both
  directions. Gates: build; freeze-check (pre-existing digests
  unmoved); suite; P0 differential (P0 3/16 counted bytes == BG's
  383,798 + structural no-blind assert); P2-blind 3/16 accept=true;
  full-pass single-shot in background if wall-clock permits
  [MAC-BOX, NOISY-SHARED — three siblings run].
- WILL NOT DO: eval_proof.rs, lookup.rs, fold.rs, gkr_masked.rs,
  manifest.rs, wire.rs edits; bg_battery/bg_canary/canary-harness
  edits (BJ's stage); act-side masks (P1/P3 stay refused, refusal
  text updated to name only the remaining gap); descent-fold work
  (BK); push.
- 2026-08-11 **BL VERDICT ROW (T_blind: masking the weight-touching
  round polynomials of the composed P2 path).**
  * D1 T_BLIND ENGINE CORE + CERTIFICATE BATTERY LANDED (bef1086):
    ring/t_blind.rs — the O-4 masked-sumcheck construction at real K
    arithmetic (RoundMask n_g = 1 + sum d_t fresh uniform K coeffs =
    AZ-L1a; masked_sumcheck_prove/verify with round polys = product +
    rho*M_t, c_0 = claim + rho*G, end = combine(finals) + rho*g_open;
    grounding-weight kernels; freshness registry E-5). `t-blind
    battery` **11/11** at real matmul schedules: completeness +
    soundness + E-1 (unblinded terminal recovers a dim-6 secret at
    exactly 6 proofs) + E-2/E-7(ii) (blinded non-recovery, fresh
    pad/proof) + AZ-L1a full column rank 16*n_g + E-8/AZ-O2 joint-
    blinding cert + E-3 (adaptive forged-G accepts unbound / rejects
    shipped rho = H(..,G)) + E-4 (terminal grounding) + E-5 (reuse
    refusal + shared-pad differencing) + E-9 (ring-granular slots rank
    8 / slot-shared rank 1 via lane_split) + E-7(iii) simulator
    surjectivity. I-6 HELD (no new Gaussian-masked opening).
  * D2 IN-PATH (Surface 1 round mask + Surface 3 claim segment) LANDED
    in the composed P2 prover/verifier (pass_agg zone): the 3 matmul
    ROUND POLYNOMIALS masked (G pinned pre-rho, masked_sumcheck,
    g_open), grounded as claims on committed CLASS_Q31C mask tensors
    in the WEIGHT group (zero extra outer identity — u_0 covers T_W ++
    T_blind, the E-3 edge realized at the descent face); the unit-
    weight segment decouples the opened batch value. Mode-gated
    (BgOpts.t_blind, all touches behind `if opts.t_blind`):
    **P0 BYTE-IDENTICAL — `pass-agg prove 3 16 p0` = 383,798 B accept,
    BG's pinned P0 value EXACTLY** (differential); **P2-noblind
    regression = 966,462 B accept, BG's pinned P2 value EXACTLY**;
    **P2+T_blind = 966,910 B accept, blind surcharge 448 B MEASURED**
    (the weight round polynomials masked on real ckpt data, 3 layers
    T=16 [MAC-BOX, NOISY-SHARED]). SURCHARGE: derived 448 B in-path
    (3 x (G 64 + g_open 64) + segment 64) = MEASURED BYTE-EXACT;
    derived-full 1,024 B (adds Surface 2 terminal pad +576); vs BG's
    ~1,664 B [MODEL] (structurally superseded — no CR-L4 terminal-
    batch sumcheck in the engine). Committed-only 1,728 blind digit
    rings on 3,538,944; schedules UNMOVED (freeze BL-1d: tierz
    L8/1,368/e4 + bare L8/939/e7, BG's exact pins). Restarts 0.
  * SURFACE 2 (terminal selector-extension pad) CERTIFIED in
    t_blind.rs (battery L1/L6/L8) but IN-PATH-PENDING: the extended
    index space + the (1-ext*) a*/b*/v_c claim reconstruction + the
    eq_ks tensor-product pad kernel — a point-structure change the
    round-mask wiring does not need; its +576 B is in the derived-full
    total, not on the wire this wave. Honest label carried in the
    refusal text (P1/P3 now name only the ACT-side mask as absent).
  * FINDING BL-F1 (the R-BG1 seam's SECOND face, fixed in the composed
    verifier): the BH merge hoisted the Tier-Z L1 psi fold to callers
    (parameter contract raw phi -> FOLDED compute_psi; "values
    unchanged" = the prover); BG's composed VERIFIER call site stayed
    on the old contract at merged HEAD. At last-level r > 1 it panics
    the length assert (R-BG1's exact "972 vs 162" = 6x162 signature —
    the canary was just the first P2 verify to run); at r = 1 the
    assert passes but the verifier's L1 functional (raw phi) differs
    from the prover's images (phi (x) c_0) — an honest P2 proof would
    REJECT at tierz-family (arithmetic consequence; empirical 12/512
    confirmation = BJ's composed-verify re-measure, the post-merge P2
    verify having never been re-exercised — the suite smoke is
    P0-only). FIX: compute_psi in bg_verify_group's Tier-Z branch (one
    marked block) — anchors: pre-fix P2+blind 2/16 panics (960 vs
    160); post-fix P2-noblind 3/16 ACCEPTS at BG's exact in-lane bytes
    (966,462 B) = BG's pre-merge prover/verifier consistency restored.
    BJ owns R-BG1 — orchestrator reconciles at BJ -> BL merge
    (keep-or-subsume).
  * E-BLOCK DISPOSITION: E-1/E-2/E-3/E-4/E-5/E-7(ii,iii)/E-8/E-9 wired
    as executable certificate legs (t-blind battery). E-6/E-7(i)/E-10/
    E-11 remain BD/BG's landed legs (consumed, not re-claimed).
  * GATES: build green; freeze-check green (BL-1a..1d, pre-existing
    digests unmoved); **FULL SUITE 67/67 OK in 1,013.9 s** from the
    worktree root [MAC-BOX, NOISY-SHARED]; P0 differential green;
    P2+blind 3/16 accept. `pass-agg battery` + the full-pass 12/512
    P2+blind single-shot were LAUNCHED at lane close on the
    oversubscribed box (5+ CPU-bound sibling jobs): the battery run
    was KILLED by the session harness ~22 min in — NO verdict, NOT
    claimed (its P2 legs ride the BL-F1-fixed verifier and were
    previously blocked by the R-BG1-class assert at the merged base;
    the orchestrator's merge re-run is the venue per house pattern —
    wave-3 precedent: batteries follow pre-push). The full-pass run
    was still alive at close (derived expectation exact by BL-1d =
    1,019,659 B; single-shot honest-if-it-lands, output in this
    worktree's session task log).
  * Freeze rows UAGB1-BL-1a..1d; pre-existing digests unmoved,
    freeze-check green. Report UAGB1_TBLIND_REPORT.md; additive test
    tests/test_uagb1_tblind.py. Files: NEW ring/t_blind.rs, ring/mod.rs
    (one mod line), the [UAGB1-BL] section + `t-blind` dispatch arm +
    the mode-gated T_blind hooks inside the [UAGB1-BG] composed path +
    the BL-F1 one-block Tier-Z fix, NEW UAGB1_TBLIND_REPORT.md, NEW
    test, this ledger section.

## Blocker

(none blocking — R-BG1 owned by BJ, stage 1)

## Log

- 2026-08-08: ledger opened at 867bfaf with the roadmap + provenance
  pillar docs (this session). Lane launch pending console go.
- 2026-08-08 (later): console GO received ("Go for it. Go ahead and
  launch the U-AG-B1 lanes"). Baseline build + suite run on the Mac
  box; machine note added; BA/BB/BC launched in worktrees. BB scoped
  to critical-path items (1)-(2) first (exact-digit plumbing +
  committed matmul statement at 125M layer shape), (3)+ only after
  those land green — the ledger's six-item list is the ROUND's path,
  not one context's bite. BC additionally owns the frugal-lm 125M
  int8 calibration study (roadmap risk 5 de-risk) as its unblocked
  integration-prep item.
- 2026-08-08: Mac-box BASELINE GREEN at bfd2753 — cargo build
  --release clean (30.4 s warm, warnings only), Python suite 47/47
  OK in 287.3 s including the Rust self-test battery (235.8 s) and
  freeze-check [MAC-BOX]. Stale wt-uag4-* worktrees from the
  superseded local line removed (clean, content preserved in the
  merged remote round). Lanes BA/BB/BC launched in their worktrees.
- 2026-08-08: BA closed first (suite 50/50 in-lane), merged 883b1f9
  (orchestrator re-run: freeze script exit 0 + 3/3 test module in
  the main checkout; full-suite pass follows before push). BA-F5
  (roadmap R-EB2/R-EB3 mislabel) fixed in LLM_POC_ROADMAP.md same
  day. NEW KNOWN FLAKE for reconcile: tests.test_zk_lattice
  CommitmentTests.test_opening_proof_roundtrip failed once in BA's
  first full-suite run, passes isolated 3/3 and on re-run —
  probabilistic, same class as the 2026-07 Pi1 tamper flake that got
  pinned entropy; queue a pinned-entropy fix (Agent-C-class lane or
  FINAL housekeeping), do NOT weaken the test.
- 2026-08-08: BC closed second (suite 48 in-lane), merged 8b2ffa8
  (orchestrator re-run: azb battery 20/20 + test module in main).
  Load-bearing reads: (1) roadmap risk 5 RETIRED in its worst form —
  the completed 125m-baseline checkpoint calibrates with zero
  range-fact violations and the weights-only side is free, so the
  P2 PoC statement targets it as-is; the +2.29-nat activation
  quality delta is a model-side QAT option, not a proof-system
  blocker; (2) F-O2 demoted from PoC-blocking to 7B-freeze-blocking;
  (3) BC exports to BB queued via orchestrator message ([-127,127]
  forced, 25/26-bit honest accumulators at 125M, pre-add-rounding
  requant form ~2.7 nats free w/ boundary caveat + declared-margin
  requirement, metadata table in M125_CALIBRATION_STUDY.md).
  Housekeeping queue: BC-f Darwin ru_maxrss print misread in
  aggregation_folding_spike.py (cosmetic, checks unaffected) — FINAL.
  Calibration script re-run (seeded, frugal venv) scheduled at FINAL
  quiesced pass rather than at this merge.
- 2026-08-08: BB closed last (items 1-2 + honest 3-skeleton),
  merged 304df33 (orchestrator re-run: freeze-check + both
  batteries green in main; full suite pass follows before push).
  WAVE 1 OF THE ROUND IS CLOSED: all three launched lanes landed
  and merged, every deliverable at its briefed scope or better,
  zero blockers, zero dishonest claims. The round's load-bearing
  number: the full-shape statement artifact is 447.8x Tier N with
  99.8% of it in the OPENING layer — exactly the volume the
  designed eval-proof/aggregation stack (BB items 4-6) replaces;
  per the U-AG4 tables the folded W-C pass target for 12 layers is
  the 0.3-0.5 MiB class [MODEL until built]. WAVE 2 QUEUE (next
  console go): BB items 4-6 (IXF fold at 12->16 index padding,
  masked eval-proof path, wire format) + the two integration
  unblocks from D3 findings (per-scale SiLU table family for
  eGate=-3 on 10/12 layers; QuantMeta typing for positive
  exponents + [-127,127]) + AZB engine legs E-1..E-11 as stages
  land + F-Z1 exact 125M point once a floor schedule exists +
  INTEGRATION (the 12-layer P2 pass on ckpt-00009536) + the
  pinned-entropy flake fix + BC-f Darwin RSS print fix
  (housekeeping). The tranche ledger STAYS OPEN across waves
  (U-K8/U-K9 precedent).

## Wave 4 close (orchestrator, 2026-08-11)

ALL FOUR LANES LANDED AND MERGED (BJ 122da24, BL 202edfa, BK
f69a6f6; PV-S2 pillar lane still measuring, merges independently).
Consolidated gate at the merged tree: seam 12/12, t-blind 11/11,
table-descent 5/5, canary 6/6 (deployment-blocking semantics
confirmed), suite 67/67, freeze-check green throughout,
pre-existing digests never moved. Pushed a9e9199.

THE STATE AFTER WAVE 4: the composed pass artifact carries EVERY
claim family (matmul + Hadamard + requant + table membership) —
full-statement Tier N 12x512 P0 = 1,509,911 B = 1.44 MiB measured
== derived to the byte = 0.48x the pass gate; P2 privacy complete
through T_blind (+448 B measured byte-exact; derived full-pass
P2+blind 1,019,659 B); R-BG1 CLOSED at the shipped call site;
composed verify 199.6 s (4.79x); BF-F3 wired (-13.2% layer prove);
AZB E-1..E-11 ALL executable. Open for FINAL: BL-F2 (commitment
hiding tails — engine-wide, needs a ruling), BK's +9%-over-[MODEL]
reconcile vs BJ's re-derived lines, Surface-2 T_blind in-path
(+576 B), the quiesced p50/p95 pass, A1 condition reconciliation,
ledger FINAL close. External watch: AGGREGATION_LITERATURE
addendum 2026-08-11 (Attestable claims).
