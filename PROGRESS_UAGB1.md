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

## Blocker

(none so far)

## Log

- 2026-08-08: ledger opened at 867bfaf with the roadmap + provenance
  pillar docs (this session). Lane launch pending console go.
