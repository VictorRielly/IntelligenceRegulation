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
- [ ] INTEGRATION: frugal-lm 125M checkpoint imported (int8
      calibration honest — an uncalibratable model fails its range
      facts by design), 12-layer P2 pass proven end to end, measured
      p50/p95, artifact bytes vs derived budget, brief.
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

- (lane launches here)

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

- (lane launches here)

## Blocker

(none so far)

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
