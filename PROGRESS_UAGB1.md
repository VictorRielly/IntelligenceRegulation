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

- (lane launches here)

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
