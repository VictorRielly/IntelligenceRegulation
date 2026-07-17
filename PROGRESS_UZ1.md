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
- [x] IA-2 (Z1-impl-b): the closing round + the zeta deletion. Nine
      exact zero-sum claims (design eq. 4) over the pad commitments, one
      standalone ct-round (or folded into the last wave — pick one,
      record why); zeta family switched to ForcedZero per-wave zero
      claims, reveal wire deleted, zeta_sums retired, pack-time junk==0
      canary. Exit: honest layer ACCEPT at the 2^12 battery shape, BOTH
      arms (A and R); Z1-d both-directions pair + Z1-f legs green.
      DONE 2026-07-16 (IA, two commits — closing round fe5dc21, zeta
      deletion this one). Gate read before starting: P1 GO (shared
      layout; no option-1 fallback). Closing round: STANDALONE (choice
      recorded: auditability — the design specifies it — and budget
      isolation: folding would couple the wave plan to the closing
      shape); per padded claim row ONE exact zero-sum claim reading
      EXACTLY the wave rounds' pad positions (the Section 2.3 read-set
      sharpening); closing g's committed pre-h0_link (D-4); c_z's h0 =
      lkp state + closing tag + all pad commitments (design 2.5 row 3);
      no reveals — the verifier rebuilds the claims. Zeta deletion:
      per-wave ForcedZero claims (public scalar 0), reveal wire DELETED
      (57 -> 9 reveals/wave measured in-battery: 27 == 9 x 3 pad waves
      at 2^12), zeta_sums layer gate RETIRED (per-wave zero strictly
      stronger), pack-time junk==0 canary on every Y/UP chunk (the
      design 2.4 fragility flag — packer drift becomes a named assert),
      prover no longer computes zeta partials at all (the per-share
      ct_mul_centered walk went with the wire). [Z1-d] both directions
      green (attack accepts a false total T+delta with the closing
      round absent; the closing round rejects exactly there). [Z1-f]
      legs green: (i) identity-2 executable — honest TRUE zeta partials
      identically zero per wave, asserted inside the differential leg +
      the pack canary; (ii) JunkY — a junk-bearing witness (junk CRT
      coordinate in a Y chunk, consumed consistently so the Hadamard
      quad stays TRUE and lookup/pins pass) REJECTS at exactly its
      wave's ForcedZero claim; (iii) the reveal-byte differential
      recorded (-576 B/chunk-wave class). Honest ACCEPT at 2^12 on
      BOTH arms (A and R) + RangeOnly/Bare. Suite 47 + freeze-check
      green.
- [x] IA-3 (Z1-impl-c): the full [Z1] battery. Z1-a (unmasked exact-
      recovery exhibit vs the legacy Revealed policy — PERMANENT), Z1-b
      (masked non-recovery + coset check + counting canaries), Z1-c (F5
      pad-commitment-binding pair, both directions), Z1-e (S1/S3 tamper
      set re-run under masking), Z1-g (accumulation stall across P
      proofs), Z1-h (pad-reuse leak demonstrated + engine refuses).
      Exit: full battery green at battery shape; suite + freeze-check
      green.
      DONE 2026-07-16 (IA, two commits — rank battery cc5b3ca, F5 pair
      + tamper re-run + Q4.2a' canary this one). Z1-a/b/g/h are the
      splitter-level rank harness (self_test_z1, suite-permanent; cc5b3ca
      note). This commit adds: [Z1-c] the F5 pad-commitment binding pair
      (self_test_wave_split, ct-round level) — the closing round ACCEPTS
      against its bound pad commitment and REJECTS when the verifier's
      h0/openings are a swapped/unbound one (design 2.5 row-1, both
      directions); [Z1-e] the S1/S3 tamper set re-certified UNDER
      MASKING (every layer-battery tamper leg now runs masked=true with
      the closing round wired — recorded as one explicit leg);
      [Z1-c-rig] the Q4.2a' OPENING-COUNT / mask-freshness canary at
      engine scale (PA's P1 note): the rig counts, per shared pad
      commitment, wave-round opens + 1 closing open, and asserts it
      equals the plan-derived opening set (openings_canary_ok in
      all_ok) — the multi-round-opening composition's counted
      hypothesis. Full [Z1] + [U-R1b]/[U-R2a] battery green; suite 47 +
      freeze-check green.
- [x] IA-4 (Z1-impl-d, measure): one measured run per S2 shape
      (2^16/2^18/2^20, arm A; plus the 2^20 arm-R spot check),
      SERIALIZED, systemd-run MemoryMax=10G, recording against design
      Section 6 projections: committed dce/el (+0.025 predicted at
      2^20), masked-descent B/el (0.512 -> ~0.14 predicted), attribution
      counters (the clean signal, not A-B totals), peak RSS. Freeze row
      LKP-10: pad layout rule, pad freshness rule, closing-round shape,
      zeta deletion (57 -> 9 reveals/wave), re-derived data cap.
      DONE 2026-07-16. LKP-10 landed (ca2184c). All four runs honest
      ACCEPT end-to-end under masking (closing round + the Q4.2a'
      opening-count canary live at 670 waves). Serialized,
      MemoryMax=10G, 1T [NOISY-SHARED — box load was ~3x the S2
      session's: arm B (zero masking changes) slowed identically, so
      A-B deltas and the attribution counters remain the valid
      signals]. MEASURED vs design Section 6 (S2 baselines cited):

      committed marginal dce/el   S2      masked  delta    predicted
      2^16 (43 waves, 1 pad cm)   1.609   1.656   +0.047   +0.068
      2^18 (168 waves, 2 cms)     1.387   1.402   +0.015   +0.034
      2^20 (670 waves, 6 cms)     1.335   1.343   +0.008   +0.025

      -> the measured delta is EXACTLY the pad material at every shape
      (3072 / 4096 / 8192 dce: pads x 1024 + 2048 closing g). The
      design 6.1 wave-count term ([MODEL], cap 76 -> 75 ~ +1.3% waves)
      NEVER BOUND: first-fit kept 43/168/670 waves at cap 75 at every
      shape, so the 2^20 cost is +0.6% of the 1.335 floor, ~3x better
      than the +1.9% projection.

      masked-descent B/el         S2      masked  predicted
      2^16                        1.417   1.047   ~1.04
      2^18                        0.716   0.354   ~0.35
      2^20                        0.512   0.151   ~0.14

      -> net NEGATIVE as designed: the zeta deletion (-0.361 measured
      at 2^20 vs -0.368 predicted) pays for the masking three times
      over on this ledger; reveals 387/1512/6030 == 9 x waves exactly
      (the 57 -> 9 collapse at scale). [Same C-03 relabel as S2: this
      ledger EXCLUDES per-wave CtRoundProofs — not proof size.]

      attribution p/v us/el       S2          masked
      2^16                        24.6/9.9    22.2/10.0
      2^18                        22.5/9.8    22.5/9.8
      2^20                        23.4/10.2   23.0/10.0

      -> FLAT: the masking is invisible in the clean signal (design
      6.4's inside-the-noise-band claim, confirmed via counters). A-B
      totals (+82.7/+14.1 us/el at 2^20) are box-noise-wide, exactly
      as S2 warned — not the signal. Peak RSS 0.52 / 2.07 / 8.23 GiB
      == S2's 0.52 / 2.06 / 8.23 (the +6 commitment stores are noise;
      the 2^20 CLI cap and 2^22 wall unmoved).

      2^20 arm-R spot check: RANGE marginal 0.0146 dce/el == S3's
      0.0146 EXACTLY and range share 0.082 B/el == S3's 0.082 — the
      shared psi batch means the pad commitments do NOT double
      (design 2.1 confirmed); reveals R == A == 6030; range descent
      attribution +16.9/+1.0 us/el (S3 +15.3/+1.4, flat); peak RSS
      8.40 GiB == S3's 8.40. Raw shape-line detail per run:
      * 2^16 arm A (43 waves, cap 75, 1 pad cm): committed marginal
        1.656 dce/el (S2 unmasked 1.609 -> DELTA +0.047 = exactly the
        pad material 3072 dce = 1024 pad cm + 2048 closing g; the
        design 6.1 wave-count term +0.021 did NOT bind — the wave
        count stayed 43 at cap 75); masked-descent 1.047 B/el vs ~1.04
        predicted (S2 1.417; zeta deletion measured -0.370 vs -0.378
        predicted; reveals 387 == 9 x 43); attribution 22.2/10.0
        us/el prove/verify (S2 24.6/9.9 — flat); peak RSS 0.52 GiB
        (== S2).
      * 2^18 arm A (168 waves, cap 75, 2 pad cms): committed marginal
        1.402 dce/el (S2 1.387 -> DELTA +0.015 = exactly the pad
        material 4096 dce; wave count again UNCHANGED at 168 — the
        cap term did not bind at this shape either); masked-descent
        0.354 B/el vs ~0.35 predicted (S2 0.716; zeta deletion -0.362
        vs -0.369 predicted; reveals 1512 == 9 x 168); attribution
        22.5/9.8 us/el — IDENTICAL to S2's 22.5/9.8; peak RSS
        2.07 GiB (S2 2.06).
      * 2^20 arm A (670 waves, cap 75, 6 pad cms — the headline shape):
        committed marginal 1.343 dce/el (S2 1.335 -> DELTA +0.008 =
        exactly the pad material 8192 dce = 6 x 1024 pad + 2048
        closing g; design predicted +0.025 — the [MODEL] wave-count
        term +0.017 never bound, the first-fit plan kept 670 waves at
        cap 75 at EVERY shape, so the measured cost is the pure pad
        term, ~3x BETTER than projected); masked-descent 0.151 B/el
        (S2 0.512, -70.5%; ~0.14 predicted; reveals 6030 == 9 x 670 —
        the 57 -> 9/wave collapse at scale); attribution 23.0/10.0
        us/el vs S2 23.4/10.2 (flat — the masking is invisible in the
        clean signal, confirming design 6.4's inside-noise-band
        claim); peak RSS 8.23 GiB == S2's 8.23 exactly. A-B totals
        prove +82.7 / verify +14.1 us/el [NOISY-SHARED, box-noise-wide
        exactly as S2 warned — not the signal].
- [x] P1 (PA, FIRST): Q4.2a' — the multi-round-openings composition
      corollary (one commitment opened in ~114 rounds; joint
      distribution = product of per-round Q4.2a-simulable openings,
      linear defect accumulation). Transcribe into Q4_LEMMAS.md in the
      Q4.2a style with explicit hypotheses (fresh y per round, rejection
      sampling per round, binding across rounds). POST the verdict in
      this ledger's Log as "P1 GO" or "P1 NO-GO + reason" — IA's impl-b
      gate reads it. If NO-GO: also price/record what option 1 must
      prove instead.
- [x] P2 (PA): Q4.10 — the pad-coset lemma (design Section 3.1,
      bijective one-time pad on {Σ = T}; exact, witness-independent,
      independent across claims) + the extraction note (design Section 4
      item 3: σ_w := σ̃_w − e_w reduces to the unmasked split-claim
      extraction). Q4_LEMMAS summary table rows added.
- [x] P3 (PA): SOUNDNESS_REFERENCE.md Section 7 gains the design
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
- 2026-07-16 (IA, impl-b 1/2 — gate read: P1 GO, shared layout kept):
  the CLOSING ROUND. Engine closing_round_claims: per padded claim row,
  ONE exact zero-sum ct-claim reading — weight 1 — EXACTLY the pad
  positions the wave rounds read (the Section 2.3 sharpening; all pad
  waves, row-major), public zero scalar, no psi compression, one g-slot
  each. Rig: STANDALONE round (recorded choice vs folding into the last
  wave: (a) auditability — the design specifies it; (b) budget
  isolation — folding would charge the last wave's C2 budget the
  n_pad_cms + closing-g commitments and couple the wave plan to the
  closing shape); closing g-groups (9 slots -> 2 groups at msg_r 8)
  committed BEFORE h0_link with every other g (D-4); c_z's h0 = lookup
  transcript state + closing tag + the round's list (all pad
  commitments), design 2.5 row 3; verifier rebuilds the claims itself —
  no reveals ride the round; LayerVerdict.closing_ok in all_ok. [Z1-d]
  BOTH DIRECTIONS at toy scale: ATTACK — pads rigged to sum delta +
  honestly-computed masked reveals ACCEPT a false total T + delta
  through the sum gate and every wave round when the closing round is
  absent (the exhibited design 4.2 forgery); DEFENSE — the closing
  round accepts honest pads and REJECTS the rigged set at exactly the
  zero-sum claims. Battery green (closing round live on the honest
  arms); suite 47 + freeze-check green.
- 2026-07-16 (IA, impl-b 2/2 — IA-2 DONE): the zeta deletion. Reveal
  wire deleted (the layer battery counts 27 == 9 x 3 pad-wave reveals
  at 2^12 — the 57 -> 9/wave collapse), per-wave ForcedZero zeta claims
  on both sides, zeta_sums layer gate retired, pack-time junk==0 canary
  on every Y/UP chunk, prover-side zeta partial computation deleted
  outright. PartialLieZeta/CompensatedZeta tampers retired with the
  wire they tampered; new JunkY tamper (junk CRT coordinate consumed
  consistently — quad TRUE, lookup/pins pass) REJECTS at exactly its
  wave. Differential leg now also asserts identity (2): honest TRUE
  zeta partials are identically zero per wave. IA-2 exit met: honest
  ACCEPT at 2^12 on arms A and R; Z1-d pair + Z1-f legs green; suite
  47 + freeze-check green. NOTE for IA-4's ledgers: reveal_shares now
  counts pins only — the masked-descent B/el row will show the design
  6.2 zeta-deletion drop directly.
- 2026-07-16 (IA, impl-c 1/2): the [Z1] rank/leakage/recovery battery
  (self_test_z1, suite-permanent — the splitter-level linear-algebra
  harness; the C-02 leak lives in the revealed scalars, so no ct-rounds
  are needed to demonstrate what a transcript observer can solve for).
  [Z1-a] PERMANENT C-02 regression: legacy Revealed shares at the
  rigged 27-unknown/3-wave shape (s_w = 9 = psi copies) recover the
  committed witness EXACTLY from ONE transcript (rank s_w/s_w per
  wave, the public system eq. 1). [Z1-b]: the same solver against the
  masked shares returns a full-rank phantom != witness; an ALTERNATIVE
  witness with the same totals explains the masked transcript exactly
  (its implied pads satisfy the zero-sum) — constructive full-coset
  membership; counting canary #free exposures == #free pads == k_j - 1
  per claim, counted from the layout. [Z1-g] at the 26-unknown/2-wave
  shape: unmasked rank grows 18 -> 26 across proofs to EXACT recovery
  at P = 2; masked solution dimension EQUALS the totals-only baseline
  at every P (the stall — zero fresh witness equations per proof).
  [Z1-h]: three proofs sharing one pad table -> pairwise differences
  cancel the pads and EXACTLY recover the witness (26/26, half rate);
  the fresh-pad control's differences keep an 8-dim solution set;
  freshness is STRUCTURAL (WavePads non-Clone, consumed by the
  splitter, drawn per proof from the ProverRng — the reuse arm needed
  the harness-only escape hatch), pinning Q4.2a''s per-proof
  hypothesis. Suite 47 + freeze-check green.
- 2026-07-16 (IA, impl-c 2/2 — IA-3 DONE): the F5 pad-commitment
  binding pair [Z1-c] (closing round accepts its bound pad commitment,
  rejects a swapped/unbound one — design 2.5 row 1, both directions),
  the [Z1-e] S1/S3-tamper-under-masking leg (every layer-battery
  tamper now runs masked=true with the closing round live), and the
  Q4.2a' opening-count/mask-freshness canary at engine scale
  (openings_canary_ok: each shared pad commitment opened exactly its
  pad waves + 1 closing time, fresh masks — PA's P1 engine cert). IA-3
  exit met: full [Z1] battery green (Z1-a/b/c/e/g/h + the Z1-i/Z1-d/
  Z1-f legs from impl-a/b); suite 47 + freeze-check green. The
  permanent [Z1-a] C-02 regression is in the always-on self-test.
- 2026-07-16 (IA, impl-d 1/2 — LKP-10 freeze row): freeze_check_uz1
  added and wired into freeze-check, pinning both directions: pad
  layout rule (9/wave, wave-major, 113 pad-waves/1024-coeff commitment,
  6 pad commitments at W=670, layout_bytes deterministic); the
  re-derived data cap (masked 75 vs legacy 76 — the engine's own scan,
  not hand-carried); the closing-round shape (9 exact zero-sum claims,
  2 g-groups); the zeta deletion (57 -> 9 reveals/wave, l=24, 2
  families); the pad freshness rule (solved last pad, non-Clone
  consumed WavePads). freeze-check + suite green. Measured numbers
  (dce/el, B/el, attribution, RSS) go in the IA-4 box next, from the
  serialized S2-shape runs.
- 2026-07-16 (IA, impl-d 2/2 — IA-4 DONE, IA lane COMPLETE): the four
  serialized measured runs landed (table in the IA-4 box, verbatim).
  Headlines: committed delta at 2^20 is +0.008 dce/el — EXACTLY the
  pad material, ~3x better than the design's +0.025 projection because
  the [MODEL] wave-count term never bound (first-fit kept 43/168/670
  waves at cap 75 at every shape — a surfaced conservative assumption,
  design Section 6.1/7.3); masked-descent ledger 0.512 -> 0.151 B/el
  at 2^20 (-70.5%, ~-72% predicted) — the zeta deletion pays for the
  masking; attribution counters FLAT at all shapes (the masking is
  invisible in the clean signal); RSS unchanged everywhere; arm R's
  range marginal and byte share IDENTICAL to S3's (pads shared across
  tables, not doubled). All runs honest ACCEPT under masking with the
  closing round and the Q4.2a' opening-count canary live at 670 waves.
  IA lane (impl-a..d) COMPLETE: C-02 closed at engine scale on this
  rig's wave shares — the [Z1-a] exhibit remains in the suite
  permanently as the regression, per the review condition. Remaining
  for the ORCHESTRATOR (FINAL box): merge PA, re-grade the design
  doc's [PROVEN*] rows against the [Z1] battery + these measurements
  (IA recommendation: 3.1 pad-coset -> PROVEN at engine scale via
  Z1-b/Z1-g; identity-2/zeta rows -> PROVEN at engine scale via
  Z1-f + the differential's zero-partials cert; 3.4 multi-round
  composition -> per Q4.2a' + the opening-count canary; the design
  6.1 wave-count term -> relabel measured-not-binding), suite, push.
- 2026-07-15 (PA): P1 GO — Q4.2a' closes on paper: the rejection
  lemma Q4.2a invokes ([Lyu12] Thm 4.6) holds POINTWISE in the
  center, so a round-by-round hybrid factors the ~114 openings of one
  (x, rho) into center-independent per-round laws with defect
  <= 114·2^-100-class ~ 2^-93; all four hypotheses (fresh y/round,
  per-round rejection, one message across rounds, no shared
  randomness beyond the commitment) check against the construction.
  Q4.2a' graded PROVEN on paper, engine certs PLANNED
  ([Z1-b]/[Z1-e]/[Z1-g] + opening-count canary). One transcription
  repair recorded IN the lemma, not silently fixed: design 3.4's
  marginal-independence inference strengthened to the
  pointwise/conditional form (which the cited lemma provides —
  marginal alone would not factor the joint law, since all centers
  share rho). IA's impl-b gate is OPEN: shared-pad-commitment
  pattern approved, no fallback needed.
- 2026-07-15 (PA): P2 done — Q4.10 (pad-coset lemma: solved last pad
  uniform on H = {sum e = 0}; e |-> sigma + e bijects H onto
  {sum x = T_j}; masked shares EXACTLY uniform on the coset,
  witness-independent, independent across claims; k_j = 1 takes no
  pad) and Q4.10-X (binding fixes pads across rounds;
  sigma*_w := sigma~_w - e*_w reduces to the unmasked split-claim
  extraction; eq. (4) load-bearing) transcribed into Q4_LEMMAS.md
  with summary rows. Both PROVEN on paper; certs PLANNED: Q4.10 —
  [Z1-b]/[Z1-g]/[Z1-h]/[Z1-i]; Q4.10-X — [Z1-d] both
  directions/[Z1-e]/[Z1-c]. No design-doc repairs needed for P2.
- 2026-07-15 (PA): P3 done — SOUNDNESS_REFERENCE.md Section 7 gains
  the four Z1 hash-edge rows (h0_link pad binding / c_w / c_z / psi
  scope note) in the table's format, every "pinned by" entry marked
  PLANNED naming its [Z1-c]/[Z1-e]-class leg (flip to live names at
  Z1-impl-c). No pre-existing row touched; one non-row consistency
  amendment recorded: the E3-Z intro's "last four rows" phrase
  updated since the Z1 rows now sit last. PA lane complete
  (P1/P2/P3); ready for orchestrator merge.
