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

## Agent BC status (wt-uagb1-bc)

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
