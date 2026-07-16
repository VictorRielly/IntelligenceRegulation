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

- [x] Z1 (ZC, audit C-02, PAPER-FIRST): masked per-wave partial shares —
      random additive pads, committed pre-challenge, canceling only in
      aggregate; a SIMULATOR argument for the complete multi-wave
      transcript; a rank/leakage/recovery battery spec (what is learnable
      from the total claim vs from every wave share); cost delta priced
      (pads are per-claim-per-wave — compare against the measured ~1.3
      dce/el pin floor). Design doc only; implementation is a follow-up
      tranche gated on review.
      DONE 2026-07-15 (ZC): docs/zkmatrix-poc/WAVE_SHARE_MASKING_DESIGN.md.
      Construction: coset one-time pads (Σ pads = 0, last pad solved) in
      ceil(9W/1024) SHARED pad commitments bound in h0_link, per-wave
      share claims gain a +1 pad read, ONE closing ct-round proves the
      nine exact zero-sum claims; free rider: the zeta shares are
      IDENTICALLY ZERO honest (proven), so their 48-reveals/wave wire is
      deleted (per-wave zero claims — strictly stronger). Simulator for
      the complete transcript graded: the pad-coset lemma is exact
      ([PROVEN* — paper-only round, machine certs named]), the one new
      engine pattern (a commitment opened in ~114 rounds) surfaced as an
      OBLIGATION with a priced fallback (+0.65 dce/el). Battery spec
      [Z1-a..i] (leak/recovery pair, F5 order pair, zero-sum load-bearing
      pair, accumulation stall, pad freshness). Priced vs S2: +0.025
      dce/el on the 1.335 floor at 2^20 (+1.9%); masked-descent B/el
      0.512 → ~0.14 (zeta deletion); C-03 full-wire +1.3% — succinctness
      explicitly NOT closed (orthogonal, Phase 3). Review before any
      implementation tranche (Section 8 sketch + LKP-10 candidate).
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
- [x] Z4 (ZA, audit C-04/H-01): verification pass on the P3 artifact.
      (a) pin=false is CORRECT-by-design, not a gap: the verifier holds
      only zero-mask SHELLS (pin=true would demand g_sum==0 and reject
      honest proofs); the mask-pin boundary is enforced downstream by the
      ct-round — p3_descent_pins makes g_sum/open_g/open_r PinnedValues
      over the COMMITTED masks and verify_ct_round binds them to t1s/t2s.
      Documented at the masked_gkr_verify call site. Satisfied by P3 as
      built (84347ac) once verified; no code change needed for (a).
      (b) E3Z-N1 PORTED to the serialized byte API: two legs in
      self_test_p3 replay the attack's crafting moves on the honest
      committed proof — the layer-1 root-ratio repair (p-value shift by
      the derived-root delta) and the free g_sum-after-nu choice — and
      require REJECT in-process AND in the fresh verify process. Both
      reject (real-FS h0 recomputation + ct-round pinning close the
      pin=false gap the isolated toy exposed).
      (c) Statement/commitments arrive SEPARATELY from proof bytes:
      verified — p3_verify_main decodes the statement from its own
      file/arg, never from proof bytes; the statement independently binds
      commitment identity (X/Y group digests + model_digest recomputed
      from the proof's commitments and checked). Documented; commitment-
      swap + model_digest tamper legs already require reject.
      (d) Canonical <q + total budget: TIGHTENED — P3R now enforces
      canonical `<q` on every decoded poly coefficient, p3_descent_canonical
      checks every masked-descent K-limb, a single P3_MAX_TOTAL_SCALARS
      budget spans all sections (charge()), and vec_norm_sq_i64 is now
      SATURATING so a hostile response bundle can never wrap its l2^2 past
      a norm bound. [Z4] canonical-reject legs added.
      H-01: harness_clone + from_test_seed gated behind
      #[cfg(any(test, feature="harness"))], default-on `harness` feature
      in Cargo.toml; a library consumer with default-features=false gets
      no reuse-path symbol (verified: --no-default-features strips them,
      36 errors from the inline batteries). ProverRng is fork-safe:
      Os inner records the filling PID and reopens /dev/urandom (dropping
      the inherited buffer) on any post-fork draw; buffer shrunk to 64KiB.
      session_nonce DOWNGRADED to internal diagnostic bookkeeping (it is
      private prover state, never committed/absorbed, so no verifier can
      read it to detect reuse — the real no-reuse property is structural:
      masks moved by value, ProverRng non-Clone, OS stream fork-reseeded);
      doc rewritten to drop the "auditable freshness handle" claim.
      OPEN (recorded): a compilable production `--no-default-features`
      BINARY needs the ~46 inline battery call sites + self-test dispatch
      gated too; deferred as a follow-up (the library boundary is closed
      now; gating 50 sites risks the suite-green invariant this tranche
      holds).
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
- 2026-07-15 (ZA): Z5 landed — WaveError type + Result signatures across
  the S0 wave helpers, Ajtai-bearing claims REJECTED by the splitter,
  bounds checks on every plan/claim index, [Z5] regression battery legs;
  all callers (S0 battery, layer rig, U-R1b battery, LKP-9 freeze rows)
  ported; suite + freeze-check green.
- 2026-07-15 (ZA): Z2 landed — ARP relabeled LEGACY/non-ZK across code +
  usage() + bench/self-test output + LKP-8/9 freeze rows; demotion
  argument recorded at ARP_REJ_T; runtime center-norm gate added to
  arp_attempt/arp_attempt_joint with a [Z2] battery leg. Suite green.
- 2026-07-15 (ZA): Z4 landed — verified P3's four C-04 complaints against
  the current code: (a) pin=false is correct-by-design (ct-round pins the
  mask openings; documented) — satisfied by P3 P1/P3 as built, no code
  change; (c) statement/commitments are separate (documented). Fixed (b)
  E3Z-N1 ported to the byte API (root-repair + free-g_sum legs, REJECT
  in-process + fresh process) and (d) canonical <q + total-scalar budget
  in the decoder + saturating vec_norm_sq_i64 + [Z4] canonical-reject
  legs. H-01: harness_clone/from_test_seed cfg-gated behind default-on
  `harness` feature (library boundary closed; binary --no-default-features
  gating deferred), ProverRng fork-reseeds on PID change, session_nonce
  downgraded to diagnostic bookkeeping. Suite + freeze-check green.
- 2026-07-15: box shutdown killed all three agents mid-flight. State found
  on resume: ZA nothing started (main checkout clean at 7ee79ca); ZB
  partial Z3(a) uncommitted in worktree ab71648a (C-03 relabels in
  PROGRESS_UR.md + M4_LOOKUP_DESIGN.md + RANGE_AGGREGATION_DESIGN.md
  incl. new Section 3b); ZC nothing started (worktree a3b7416a clean).
  All three relaunched from this state.
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
- 2026-07-15 (ZC): Z1 design round landed (5 incremental commits,
  WAVE_SHARE_MASKING_DESIGN.md). Two facts the other lanes should know:
  (a) the zeta reveal wire is deletable outright (honest shares are
  identically zero) — worth folding into Z3's byte-ledger narrative as
  a designed follow-up, NOT as an as-built number; (b) the design
  constrains Phase 3 aggregation: any succinct aggregator must not
  re-expose per-wave right-hand sides, or it undoes Z1 (recorded in the
  doc's Section 7.1).
