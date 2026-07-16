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

- [ ] IA-1 (Z1-impl-a): splitter policy + pad plumbing. The
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
