# U-AG tranche ledger — proof-size aggregation, round 1 (survey + ledger)

Branch: perf/zk-batch-optimizations, opened at 410e81d (2026-07-16).
Spec: codex-audit-2026-07-14 REMEDIATION_PLAN Phase 3 ("solve proof-size
asymptotics" — candidate work selected by proof-size and verifier-cost
MODELS, not prover time; analytic <= 256 KiB path required BEFORE any
production serializer). This round is PAPER-ONLY (the M4 pattern:
literature -> design -> build); no code, no builds, no suite runs.
Standing constraint from U-Z1 (WAVE_SHARE_MASKING_DESIGN Section 7.1):
any aggregator that re-exposes per-wave right-hand sides UNDOES the Z1
masking — privacy-preserving aggregation is a hard requirement, not a
nice-to-have. Numbers only from repo-recorded sources (the C-03 audit
byte table, PROGRESS_US.md P3-EXIT measured KiB, RANGE_AGGREGATION_
DESIGN Section 3b, PROGRESS_UZ1.md IA-4 measured B/el, LKP freeze rows).
codex-audit-* read-only.

## Lanes (two parallel agents, both docs-only, both in worktrees)

- Agent GA (literature, WORKTREE): NEW docs/zkmatrix-poc/
  AGGREGATION_LITERATURE.md. Candidate families, each priced on the
  SAME axes (proof bytes at the 2^20 layer AND the 32-layer pass;
  verifier cost; prover overhead vs the current ~23 us/el; PQ status;
  Z1-masking compatibility; engine reuse — the repo already owns a
  GF(q^16) sumcheck/GKR stack from U-K1..K9):
  (a) LaBRADOR-class recursive amortized opening proofs (native
      lattice/BDLOP fit);
  (b) folding / split-and-fold accumulation (LatticeFold lineage);
  (c) polynomial-commitment reroute (Greyhound-class);
  (d) hash-based sumcheck/FRI transcript compression — the
      GATE_ALTERNATIVES option-2 fallback, one-engine-two-uses
      precedent (M4 chose LogUp partly for engine sharing);
  (e) SNARK-wrap of the verifier (recursion; PQ caveats).
  Verdict row per family + a recommendation with the M4-style
  "adapt X" framing. WebSearch/WebFetch allowed for reference
  verification; every claim about OUR numbers cites the repo source.
- Agent GB (byte ledger + budget model, WORKTREE): NEW
  docs/zkmatrix-poc/PROOF_BYTE_LEDGER.md. (1) The exact per-component
  byte ledger of the CURRENT proof at the measured shapes (every
  opening: z n_r x D + w1 kappa x D per commitment per wave; masked
  descents; reveals; statement; pad commitments post-Z1) — reconcile
  the audit's 2.86 GiB @2^20 and 15.4 GiB/layer numbers against the
  P3-EXIT measured whole-file KiB and the U-Z1 IA-4 B/el rows; flag
  any component the audit table missed. (2) The <= 256 KiB budget
  DECOMPOSED per component (what compression factor each needs —
  headline: ~11,720x on ct openings). (3) The analytic requirements
  sheet any candidate must satisfy (the Phase 3 exit test), incl. the
  Z1 no-re-exposed-RHS constraint and verifier <= 2 s
  (TARGET_CONTRACT Section 4). (4) The hard budget-test spec
  (fails when the complete artifact exceeds budget — audit Phase 3
  item 5). Numbers only from repo-recorded sources, cited inline.
- Orchestrator FINAL: merge GA + GB, review, pick the U-AG2 design
  round's direction, push, brief Victor (Telegram).

## Deliverables

- [ ] GA: AGGREGATION_LITERATURE.md — families (a)-(e) priced on the
      common axes, verdict + recommendation.
- [ ] GB: PROOF_BYTE_LEDGER.md — component ledger reconciled to
      measured bytes, budget decomposition, requirements sheet, hard
      budget-test spec.
- [ ] FINAL (orchestrator): merge, review, U-AG2 direction decided,
      push, Victor briefed.

## Log

- 2026-07-16: tranche opened at 410e81d. Victor approved via Telegram
  ("Go for it") after the U-Z1 close ping recommended the aggregation
  design round. GA + GB launched in parallel (worktrees, docs-only).
