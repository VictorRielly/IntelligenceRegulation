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
      STATUS 2026-07-27 (GA, COMPLETE — checkbox left for the
      orchestrator): doc finished at 404 -> ~1,100 lines, Sections
      0-9 + 15 verified refs, committed one section per commit
      (5225e77 Sections 0-1; then 2/9..9/9 on this worktree branch).
      VERDICT: adapt Greyhound — the family (c) PCS reroute is the
      architecture (a few global lattice polynomial commitments per
      tensor; claim structure collapsed to batched MLE-evaluation
      claims by the house masked sumcheck/GKR engine, the M4 E3/E4
      obligations' third use; Greyhound-class evaluation proofs
      LaBRADOR-compressed, 2026 ZK toolkit closing the ZK gap), with
      LatticeFold-class folding as the cross-layer accumulator and
      family (e) only as an optional endgame wrap. Bottom-up ~150-260
      KiB per complete FFN-layer statement vs the ledger's 18.59 GiB
      (76,162x), verifier ms-to-sub-second vs the ~528x gap — the
      only architecture meeting BOTH budgets; standalone (a)/(b) die
      on the 695.6 MiB identity layer (the Section 0.3 structural
      result, ledger-confirmed), family (d) is walled off from
      WHIR-class costs by v2(q-1) = 4. Z1 is subsumed, not just
      preserved (bytes and privacy force the same move; Section 6
      matrix). U-AG2 obligation list O-1..O-9 in Section 8.1;
      surprises recorded: HyperWolf (claimed log-verifier lattice
      PCS) WITHDRAWN Oct 2025; Orthus (2026/398, sqrt
      batch-verification, same IBM group) may lift family (a)'s
      verifier objection — watch item, does not displace the
      reroute. Pass-scope honesty: 32-layer pass lands ~0.5 MiB
      (~2x over a per-pass budget reading) — scope decision +
      closing levers are obligation O-2.
      STATUS 2026-07-17 (GA, superseded): worktree was
      opened on a stale base (old merge-base 7a3e7a0, no docs); reset
      to e4cd608 before work started — any orchestrator check against
      the old tree state predates that. Committed so far: 5225e77
      (Sections 0-1: ground rules, the 0.67 GiB commitment-bytes
      structural result, family (a) LaBRADOR priced, 8 verified refs).
      Web verification done for (b)/(c) leads (Orthus 2026/398,
      HyperWolf 2025/922, Neo abstract, Greyhound confirmations);
      writing families (b)-(e) + verdict now, committing per section.
- [ ] GB: PROOF_BYTE_LEDGER.md — component ledger reconciled to
      measured bytes, budget decomposition, requirements sheet, hard
      budget-test spec.
- [ ] FINAL (orchestrator): merge, review, U-AG2 direction decided,
      push, Victor briefed.

## Log

- 2026-07-16: tranche opened at 410e81d. Victor approved via Telegram
  ("Go for it") after the U-Z1 close ping recommended the aggregation
  design round. GA + GB launched in parallel (worktrees, docs-only).
