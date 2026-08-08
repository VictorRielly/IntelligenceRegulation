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

- [ ] BA: freeze rows + encoding obligations + transcriptions landed,
      suite + freeze-check green.
- [ ] BB: matmul statement at 125M shape -> 12-layer chain -> IXF
      fold -> masked path -> wire format; battery-grade tamper legs
      at each stage.
- [ ] BC: F-O/F-Z obligations dispositioned; AZB battery green incl.
      AZB-10/AZB-11; kel measured (F-O2); gates checked.
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

- (lane launches here)

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
