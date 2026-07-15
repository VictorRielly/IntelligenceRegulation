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
- [x] Z2 (ZA, audit C-01): ARP demoted off the target path. Marked
      non-ZK-grade at the frozen point in: the ct_engine module header,
      the ARP_REJ_T doc (which now RECORDS the demotion argument: 128-bit
      statistical target needs t >= 13.4 by 2e^{-t^2/2} <= 2^-128; at
      alpha 3.5 that is log M_joint(4) ~ 7.82 => ~2.5e3 attempts per
      4-unit q46 round vs ~2.8 today, ~900x; recovering restarts via
      alpha is closed by the extraction budget — arp_budget_ok already
      fails the 512-bit unit at alpha 5. t was NOT retuned), usage()
      (ffn-chain flagged LEGACY), ffn_chain_bench + self_test_ffn_chain
      output labels ("legacy range arm: rejection clipping ~2^-4.75 at
      t=1.5, NOT statistical ZK — see audit 2026-07-14 C-01"), and the
      U-K8 doc block. Runtime center-norm gate ADDED: ArpParams grows
      center_bound_sq = (1.3 sqrt(n/2) w_inf sqrt(rows))^2 and
      arp_attempt/arp_attempt_joint reject any attempt whose ACTUAL
      ||R b|| bundle exceeds it (before any rejection coin; restart =
      fresh mask commit -> fresh h0 -> fresh R) — the density-ratio
      precondition is executable. [Z2] battery leg: an out-of-assumption
      witness rejects at both entry points. LKP-8 wall-2 row, LKP-9 ARP
      row and both freeze fn docs relabeled REPRODUCIBILITY pins, not a
      ZK claim.
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
- [x] Z5 (ZA, audit M-01): wave helpers verifier-safe — plan_waves/
      split_claim_shares/split_claims_prover/split_claims_verifier/
      quad_ring_wave/quad_ring_localized now return Result<_, WaveError>
      (typed errors: ZeroCap, GroupExceedsCap, CommitIndexOutOfRange,
      OverlappingGroups, SlotOutOfRange, PlanInconsistent,
      AjtaiClaimUnsupported, EmptyQuadClaim, QuadStraddlesWaves,
      RevealShapeMismatch, PartialSumGate) instead of panicking; every
      commitment index/slot/group bounds-checked, hand-built plans gated
      by a slot-table consistency check. The Ajtai rule is REJECT:
      split_claim_shares errors on any claim with ajtai_coeffs (the old
      code defaulted an Ajtai-only claim to wave 0 and silently dropped
      the opening's scalar contribution). [Z5] regression legs in
      self_test_wave_split cover the Ajtai reject at all three splitter
      entry points, out-of-range commit/slot indices, empty quads, plan
      errors and reveal-shape mismatches. Layer verifier path maps
      WaveError to fail-closed rejection (sum_gate_ok = false).
- [ ] Z3 (ZB, audit C-03/M-02 + labeling backlog): (a) S2/S3 "transcript
      B/el" rows relabeled "masked-descent bytes only — EXCLUDES per-wave
      CtRoundProofs" in PROGRESS_UR.md + RANGE_AGGREGATION_DESIGN.md, and
      the audit's byte accounting (2.86 GiB @2^20 class, 15.4 GiB/layer,
      the 11,720x gap) adopted into the design doc as the succinctness
      problem statement; (b) M-02: freeze rows documented as
      REPRODUCIBILITY pins; a new "Security exits (fail-closed, OPEN)"
      section listing: negligible rejection distance, multi-wave share
      privacy (Z1), serialized byte budget, adversarial parser, complete
      FFN statement; (c) H-03 rename: "FFN-INTEGRATED/CLOSED" labels
      qualified to "committed activation-chain rig" where they overstate;
      (d) the 07-10 H-07 hash-ceiling note: soundness tables get a
      min(algebraic, hash/FS) cap note with grinding/multi-theorem/quantum
      caveats. Numbers only from repo-recorded sources.
- [ ] FINAL (orchestrator): merge ZB + ZC, suite green, push; review Z1
      design; decide the Z1 implementation tranche.

## Log

- 2026-07-15: tranche opened at 84347ac; ZA/ZB/ZC launched in parallel.
- 2026-07-15 (ZA): Z5 landed — WaveError type + Result signatures across
  the S0 wave helpers, Ajtai-bearing claims REJECTED by the splitter,
  bounds checks on every plan/claim index, [Z5] regression battery legs;
  all callers (S0 battery, layer rig, U-R1b battery, LKP-9 freeze rows)
  ported; suite + freeze-check green.
- 2026-07-15: box shutdown killed all three agents mid-flight. State found
  on resume: ZA nothing started (main checkout clean at 7ee79ca); ZB
  partial Z3(a) uncommitted in worktree ab71648a (C-03 relabels in
  PROGRESS_UR.md + M4_LOOKUP_DESIGN.md + RANGE_AGGREGATION_DESIGN.md
  incl. new Section 3b); ZC nothing started (worktree a3b7416a clean).
  All three relaunched from this state.
