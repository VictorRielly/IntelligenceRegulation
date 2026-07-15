# U-Z tranche ledger — closing the 2026-07-14 audit's new criticals

Branch: perf/zk-batch-optimizations, opened at 84347ac (2026-07-15).
Spec: codex-audit-2026-07-14/FINDINGS.md (C-01..C-04, H-01/H-02, M-01/M-02)
+ REMEDIATION_PLAN.md. Audit snapshot was 80ec1a1 — it did NOT see e234693
(P1), e1f5dce (P2 merge), 264aec1/84347ac (P3); C-04 and H-04 are largely
superseded by those commits but their specific complaints must be VERIFIED,
not assumed (Z4).
Build: PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release
Suite: python3 -m unittest discover -s tests (47 tests + freeze-check green
at every commit). Heavy runs: ONE per agent, systemd-run MemoryMax=5G.
codex-audit-* read-only.

## Lanes (three parallel agents)

- Agent ZA (code, MAIN checkout): Z2 + Z4 + Z5. Files: zkmatrix-rs/src/**
  (ring internals, ring_matmul.rs, manifest.rs only if Z4 requires),
  this ledger's ZA boxes. NOT docs/**.
- Agent ZB (docs, WORKTREE): Z3 + the honest-labeling backlog. Files:
  docs/zkmatrix-poc/*.md, PROGRESS_UR.md (S2 relabel), PROGRESS.md
  (milestone rename note), this ledger's ZB boxes. NO code, NO builds.
- Agent ZC (design, WORKTREE): Z1 paper-first. Files: NEW
  docs/zkmatrix-poc/WAVE_SHARE_MASKING_DESIGN.md, this ledger's ZC box.
  NO code — the design is reviewed before implementation.

## Deliverables

- [ ] Z1 (ZC, audit C-02, PAPER-FIRST): masked per-wave partial shares —
      random additive pads, committed pre-challenge, canceling only in
      aggregate; a SIMULATOR argument for the complete multi-wave
      transcript; a rank/leakage/recovery battery spec (what is learnable
      from the total claim vs from every wave share); cost delta priced
      (pads are per-claim-per-wave — compare against the measured ~1.3
      dce/el pin floor). Design doc only; implementation is a follow-up
      tranche gated on review.
- [ ] Z2 (ZA, audit C-01): ARP demoted off the target path. The layer rig
      is already ARP-free (D-5); the block chain (ffn-chain) keeps ARP as
      the LEGACY range arm — mark it non-ZK-grade at the frozen point in
      code comments + usage() + bench output labels ("legacy range arm:
      rejection clipping ~2^-4.75 at t=1.5, NOT statistical ZK — see
      audit 2026-07-14 C-01"). Add the missing runtime center-norm gate
      in arp_attempt/arp_attempt_joint (reject when actual ||R b|| exceeds
      the sigma-derivation assumption) so the density-ratio precondition
      is executable. LKP-8/9 freeze text updated to say the pinned
      rejection constants are REPRODUCIBILITY pins, not a ZK claim.
      Do NOT retune t (the security-target t ~ 13.4 kills ARP economics —
      that IS the demotion argument; record it).
- [ ] Z4 (ZA, audit C-04/H-01): verification pass on the P3 artifact
      against C-04's four complaints: (a) serialized verify runs masked
      descents WITH the mask-pin checks (pin = true) — if not, fix; (b)
      port the E3Z-N1 false-lookup attack to the serialized byte API and
      require REJECT; (c) statement/commitments arrive separately from
      proof bytes (verify, document); (d) canonical <q coordinate checks +
      total resource budget (verify, tighten if gaps). Plus H-01: put
      harness_clone + from_test_seed behind #[cfg(any(test,
      feature = "harness"))] (batteries/self-test keep working — they are
      the harness); make ProverRng fork-safe (no fork-duplicable userspace
      buffer: unbuffered read or reseed-on-fork); session_nonce claim
      downgraded to bookkeeping OR bound publicly — pick one, record why.
- [ ] Z5 (ZA, audit M-01): wave helpers verifier-safe — plan_waves/
      split_claim_shares/split_claims_verifier/quad_ring_* return Result
      (typed errors) instead of panicking on malformed input; bounds-check
      every commitment index/group; the Ajtai rule made explicit: either
      compute the Ajtai opening's scalar contribution or REJECT
      Ajtai-bearing claims in the splitter (pick reject — the layer's
      claims carry none; add the regression).
- [x] Z3 (ZB, audit C-03/M-02 + labeling backlog) — CLOSED 2026-07-15,
      four commits, one per item: (a) [DONE 2026-07-15]
      S2/S3 "transcript
      B/el" rows relabeled "masked-descent bytes only — EXCLUDES per-wave
      CtRoundProofs" in PROGRESS_UR.md + RANGE_AGGREGATION_DESIGN.md, and
      the audit's byte accounting (2.86 GiB @2^20 class, 15.4 GiB/layer,
      the 11,720x gap) adopted into the design doc as the succinctness
      problem statement; (b) [DONE 2026-07-15] M-02: freeze rows
      documented as
      REPRODUCIBILITY pins; a new "Security exits (fail-closed, OPEN)"
      section listing: negligible rejection distance, multi-wave share
      privacy (Z1), serialized byte budget, adversarial parser, complete
      FFN statement; (c) [DONE 2026-07-15] H-03 rename:
      "FFN-INTEGRATED/CLOSED" labels
      qualified to "committed activation-chain rig" where they overstate;
      (d) [DONE 2026-07-15] the 07-10 H-07 hash-ceiling note: soundness
      tables get a
      min(algebraic, hash/FS) cap note with grinding/multi-theorem/quantum
      caveats. Numbers only from repo-recorded sources.
- [ ] FINAL (orchestrator): merge ZB + ZC, suite green, push; review Z1
      design; decide the Z1 implementation tranche.

## Log

- 2026-07-15: tranche opened at 84347ac; ZA/ZB/ZC launched in parallel.
- 2026-07-15 (ZB): Z3(a) DONE — C-03 relabels ("masked transcript B/el"
  = masked-descent bytes + 12 B partial-scalar reveals ONLY, per-wave
  CtRoundProofs EXCLUDED) in PROGRESS_UR.md S2/S3, M4_LOOKUP_DESIGN.md
  quiesced-cost table, RANGE_AGGREGATION_DESIGN.md (Sections 1, 2b, 3,
  3a table); new RANGE_AGGREGATION_DESIGN.md Section 3b "Proof bytes,
  honestly" adopts the audit byte accounting (11.99 MiB battery /
  2.86 GiB @2^20 / 11,720x gap / 15.4 GiB-per-layer + 492 GiB-per-pass
  projections) plus the measured P3-EXIT whole-file anchors. All
  numbers sourced: codex-audit-2026-07-14/FINDINGS.md C-03 +
  PROGRESS_US.md P3-EXIT. Section 3b forward-references "Section 0's
  security-exit list", which Z3(b) adds next.
- 2026-07-15 (ZB): Z3(b) DONE — RANGE_AGGREGATION_DESIGN.md Section 0
  "Security exits (fail-closed, OPEN)": freeze rows = REPRODUCIBILITY
  pins (audit M-02 quote), five OPEN exits with sourced numbers
  (C-01 t=1.5 tails + t~13.4/128-bit + Q4.2b 2^-102.9@t=12; C-02 670
  waves x 9 pins ~ 6e3 measurements; C-03/Section 3b byte gap; C-04
  parser exits pending Z4; H-03 complete-FFN statement). M-02 pin
  notes at M4_LOOKUP_DESIGN.md LKP-8, LKP-9, and the Section 8
  freeze-row discipline line. DISCREPANCY recorded in Section 0 item
  3: TARGET_CONTRACT.md budget unit is "256 KB", audit computes vs
  "256 KiB" — immaterial at 11,720x, contract line binding.
- 2026-07-15 (ZB): Z3(c) DONE — H-03 renames at six sites:
  M4_LOOKUP_DESIGN.md status header + 7' header + new 7'' rename
  note; TARGET_CONTRACT.md Section 5 SiLU row; LLM_SCALE_ESTIMATE.md
  lever-stack row; TRANSFORMER_PROOF_PLAN.md Section 2
  reconciliation; PROGRESS.md milestone rename note (additive,
  historical entries unedited). All read "committed activation-chain
  rig — no FFN matmul/requant/residual in the proven statement" and
  point to RANGE_AGGREGATION_DESIGN.md Section 0 item 5. Conservative
  "remains OPEN" mentions (M4_LOOKUP_DESIGN.md Section 3,
  Q4_LEMMAS.md honesty note) left as-is — they do not overstate.
- 2026-07-15 (ZB): Z3(d) DONE — hash-ceiling cap notes (min(algebraic,
  hash/FS incl. grinding + multi-theorem, commitment assumptions,
  parameters); quantum preimage halving) on the three soundness
  tables: M4_LOOKUP_DESIGN.md Section 2.1 (the H-07-cited 2^-486-class
  rows + psi-capped 2^-279 total) and Section 6 graded table, and
  ROUTE_R_DESIGN.md's challenge-set table (its post-FS column prices
  Q=2^64 grinding but is still algebraic). Each note cites the
  governing convention already in SOUNDNESS_REFERENCE.md Section 8
  (Fiat-Shamir claim-discipline note, landed post-07-10-audit).
  Z3 CLOSED — box ticked; commits dd35e12 (a), 9be8b46 (b),
  82f47b3 (c), + this one (d).
