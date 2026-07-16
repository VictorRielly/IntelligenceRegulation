# U-Z1 tranche ledger — wave-share masking implementation (Z1-impl-a..d)

Branch: perf/zk-batch-optimizations, opened at 274befd (2026-07-15).
Spec: docs/zkmatrix-poc/WAVE_SHARE_MASKING_DESIGN.md Section 8, under the
review conditions recorded in PROGRESS_UZ.md's FINAL box: (i) the Section
3.4 multi-round shared-commitment composition [OBLIGATION] must be
transcribed to Q4_LEMMAS (a Q4.2a' corollary) — if it does NOT close on
paper, the construction falls back to Section 2.6 option 1 (per-wave pad
commitments, +0.65 dce/el) BEFORE the shared pattern is wired into the
closing round; (ii) the [Z1-a] unmasked-leak exhibit stays in the suite
permanently as the C-02 regression.
Build: PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release
Suite: python3 -m unittest discover -s tests (47 tests + freeze-check
green at every commit; battery legs grow the count). Heavy runs: ONE at a
time box-wide, systemd-run MemoryMax=10G, sizes <= 2^22 (the S2
protocol, PROGRESS_UR.md header). codex-audit-* read-only.

## Lanes (two parallel agents)

- Agent IA (code, MAIN checkout): impl-a -> impl-b -> impl-c -> impl-d
  measurements, sequential. Files: zkmatrix-rs/src/** (ct_engine.rs,
  lookup.rs, ring_matmul.rs, gkr*/sumcheck as needed), tests/**, this
  ledger's IA boxes. NOT docs/** (PA owns those). GATE: before starting
  impl-b's closing round, check this ledger for PA's P1 GO/NO-GO line;
  on NO-GO switch to the option-1 fallback layout (design Section 2.6).
- Agent PA (paper, WORKTREE): P1 -> P2 -> P3. Files:
  docs/zkmatrix-poc/Q4_LEMMAS.md, docs/zkmatrix-poc/SOUNDNESS_REFERENCE.md
  (Section 7 rows only), this ledger's PA boxes. NO code, NO builds.
- Orchestrator: merge PA, run the impl-d re-grade of
  WAVE_SHARE_MASKING_DESIGN.md's [PROVEN*] rows against battery+measured
  results, freeze row LKP-10, final suite, push.

## Deliverables

- [x] IA-1 (Z1-impl-a): splitter policy + pad plumbing. The
      {Padded, ForcedZero, Revealed} policy enum on the Result-typed
      split_claims_prover/verifier (coordinate with Z5's WaveError
      signatures — landed at 30ac90b); pad sampling from the per-proof
      ProverRng stream (solved last pad, no restarts); wave-major layout
      9/wave, 1024/commitment; shared pad commitments bound in h0_link;
      per-wave round lists gain the wave's pad commitment (verifier-
      derived from the public plan; C2 cap re-derived by
      derive_ct_round_params' own scan, expect 76 -> 75). Legacy
      `Revealed` behavior kept compile-away for the Z1-a baseline leg
      only. Exit: [U-R1a]-style self-test with pads live, honest ACCEPT
      at toy scale, Z1-i determinism/edge legs (byte-for-byte layout
      agreement; k_j = 1 claims take NO pad; centered reps near ±q/2).
      DONE 2026-07-16 (IA, two commits — engine 89a87e0, rig this one).
      Engine: SplitPolicy {Padded, ForcedZero, Revealed(harness-gated)}
      + WavePadLayout (plan-derived pad-wave set = the pin-bearing
      waves; wave-major 9/wave; 113 whole pad-waves per 1024-coeff
      commitment; canonical layout_bytes) + WavePads (per-proof RNG,
      solved last pad, non-Clone, consumed by the prover splitter) +
      masked splitter pair (weight-1 conj(X^i) pad read at wave-local
      index = the wave's data count; mod-q sum gate; fail-closed typed
      errors). Rig: pad commitments committed in Pass 1.5 (bound by
      h0_link before every challenge); every pin-bearing wave's round
      list gains its shared pad commitment (verifier-built from the
      plan; g_base shifts by one); verifier re-derives the layout from
      the public shape and asserts byte-for-byte agreement. C2 cap
      RE-DERIVED by the engine's own scan: 76 -> 75 at the 2^12/silu
      point (design 6.1's prediction confirmed; LKP-9's legacy pins
      keep gating the masked=false path, untouched). Exit evidence:
      full [U-R1b]+[U-R2a] battery green at 2^12 UNDER MASKING (honest
      ACCEPT all four arms incl. RangeOnly's pad_waves-proper-subset
      case; every S1/S3 tamper leg re-passes — pre-staging Z1-e);
      [Z1-i] legs green (layout determinism byte-for-byte, k_j = 1
      takes NO pad, masked round-trip against a SHARED pad commitment
      opened by multiple rounds, lied/compensated masked reveals,
      centered reps at exactly ±(q-1)/2, ForcedZero round-trip,
      fail-closed pad coverage). Suite 47 + freeze-check green.
- [ ] IA-2 (Z1-impl-b): the closing round + the zeta deletion. Nine
      exact zero-sum claims (design eq. 4) over the pad commitments, one
      standalone ct-round (or folded into the last wave — pick one,
      record why); zeta family switched to ForcedZero per-wave zero
      claims, reveal wire deleted, zeta_sums retired, pack-time junk==0
      canary. Exit: honest layer ACCEPT at the 2^12 battery shape, BOTH
      arms (A and R); Z1-d both-directions pair + Z1-f legs green.
- [ ] IA-3 (Z1-impl-c): the full [Z1] battery. Z1-a (unmasked exact-
      recovery exhibit vs the legacy Revealed policy — PERMANENT), Z1-b
      (masked non-recovery + coset check + counting canaries), Z1-c (F5
      pad-commitment-binding pair, both directions), Z1-e (S1/S3 tamper
      set re-run under masking), Z1-g (accumulation stall across P
      proofs), Z1-h (pad-reuse leak demonstrated + engine refuses).
      Exit: full battery green at battery shape; suite + freeze-check
      green.
- [ ] IA-4 (Z1-impl-d, measure): one measured run per S2 shape
      (2^16/2^18/2^20, arm A; plus the 2^20 arm-R spot check),
      SERIALIZED, systemd-run MemoryMax=10G, recording against design
      Section 6 projections: committed dce/el (+0.025 predicted at
      2^20), masked-descent B/el (0.512 -> ~0.14 predicted), attribution
      counters (the clean signal, not A-B totals), peak RSS. Freeze row
      LKP-10: pad layout rule, pad freshness rule, closing-round shape,
      zeta deletion (57 -> 9 reveals/wave), re-derived data cap.
- [ ] P1 (PA, FIRST): Q4.2a' — the multi-round-openings composition
      corollary (one commitment opened in ~114 rounds; joint
      distribution = product of per-round Q4.2a-simulable openings,
      linear defect accumulation). Transcribe into Q4_LEMMAS.md in the
      Q4.2a style with explicit hypotheses (fresh y per round, rejection
      sampling per round, binding across rounds). POST the verdict in
      this ledger's Log as "P1 GO" or "P1 NO-GO + reason" — IA's impl-b
      gate reads it. If NO-GO: also price/record what option 1 must
      prove instead.
- [ ] P2 (PA): Q4.10 — the pad-coset lemma (design Section 3.1,
      bijective one-time pad on {Σ = T}; exact, witness-independent,
      independent across claims) + the extraction note (design Section 4
      item 3: σ_w := σ̃_w − e_w reduces to the unmasked split-claim
      extraction). Q4_LEMMAS summary table rows added.
- [ ] P3 (PA): SOUNDNESS_REFERENCE.md Section 7 gains the design
      Section 2.5 hash-edge rows (h0_link pad binding / c_w / c_z /
      psi scope note) marked PLANNED-[Z1-c] until the battery lands.
- [ ] FINAL (orchestrator): merge PA, impl-d re-grade of the design
      doc's [PROVEN*] rows (promote to PROVEN-at-engine-scale or demote,
      row by row, against IA-3/IA-4 results), suite green, push.

## Log

- 2026-07-15: tranche opened at 274befd; IA (code, main checkout) + PA
  (paper, worktree) launched in parallel. Victor approved the launch.
- 2026-07-16 (orchestrator, relaying PA's committed verdict 92a58d6):
  **P1 GO** — Q4.2a' closes on paper (Q4.2a's rejection bound holds
  pointwise in the center, surviving conditioning across rounds; ~114
  openings factor with total defect ~2^-93; all four hypotheses check
  against the construction). IA's impl-b gate is OPEN: shared-pad-
  commitment layout approved, no option-1 fallback. PA lane fully done
  (P1/P2/P3, commits 92a58d6/19e1bba/df85b63 on its worktree branch;
  Q4.2a' + Q4.10 + Q4.10-X graded PROVEN-on-paper with [Z1] certs
  PLANNED; design 3.4's "so" repaired to the pointwise/conditional
  form — delta recorded in the lemma). Orchestrator merges PA at
  FINAL. NOTE for IA-3: Q4.2a' needs the opening-count/mask-freshness
  canary; Z1-h pad freshness is load-bearing for the composition
  (defect bound is per-proof).
- 2026-07-16 (IA, impl-a 1/2): the ct_engine masking layer landed —
  SplitPolicy {Padded, ForcedZero, Revealed(harness-gated, compile-away)}
  with policy dispatchers on the Result-typed Z5 signatures; WavePadLayout
  (wave-major, n_claims/wave, whole pad-waves per commitment, plan-derived
  pad-wave set, canonical layout_bytes for the Z1-i byte-for-byte leg);
  WavePads (non-Clone, drawn from the per-proof RNG stream, solved last
  pad, CONSUMED by the prover splitter — the Z1-h structural freshness);
  pack_wave_pads (unused coefficients uniform); masked prover/verifier
  splitters (weight-1 conj(X^i) pad read at the wave-local convention
  index = the wave's data count; mod-q sum gate; typed PadLayoutMismatch/
  PadCoverage errors, FAIL-CLOSED on uncoverable multi-wave claims);
  split_claims_forced_zero (zero totals enforced). [Z1-i] engine legs in
  self_test_wave_split: layout determinism byte-for-byte, k_j = 1 takes NO
  pad, masked round-trip against a SHARED pad commitment opened in both
  toy waves, lied + compensated masked reveals, centered reps at exactly
  +-(q-1)/2 accept, ForcedZero round-trip, fail-closed coverage. DESIGN
  SHARPENING recorded (design Section 2.3, found in code): the closing
  round's zero-sum read set must EQUAL the wave rounds' pad-read set —
  an all-positions closing read over a strict superset leaves the extra
  positions unbound and a delta parked there forges a shifted total. The
  splitter therefore gives every multi-wave padded claim a share in EVERY
  pad wave (empty functional + pad read where support is absent), so wave
  reads == closing reads == the full pad-wave set per claim row; the
  psi-circularity rule (2.5) is honored by deriving the pad-wave set from
  the PLAN (pin-bearing waves), never from claim support.
- 2026-07-16 (IA, impl-a 2/2 — IA-1 DONE): pads live in the layer rig.
  ur1_layer_shape(masked) derives the pad layout + charges each
  pin-bearing wave's C2 budget the +1 pad commitment (cap re-derived by
  the engine's scan: 76 -> 75 at 2^12/silu — the design 6.1 prediction,
  not hand-carried); ffn_layer_run(masked): pads drawn from the
  per-proof ProverRng and committed in Pass 1.5 (h0_link binds them
  before alpha/psi/wave h0s), masked splitter both sides, verifier
  re-derives the layout independently and asserts byte-for-byte
  agreement, wave round lists gain the shared pad commitment with
  g_base +1. Battery + smoke + benches run MASKED by default; the
  legacy Revealed rig path (masked=false) exists solely for [Z1-a] and
  the LKP-9 legacy pins (which pin the masked=false shape, unchanged).
  Full 2^12 battery green under masking on all four arms — including
  RangeOnly, where the pad-wave set is a PROPER subset of the waves
  (triple waves are not pin-bearing there) — and every S1/S3 tamper
  leg re-passes (Z1-e pre-staged). Suite 47 + freeze-check green.
