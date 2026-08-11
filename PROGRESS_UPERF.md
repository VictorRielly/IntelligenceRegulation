# U-PERF tranche ledger — the performance round (prove/verify walls)

Branch: perf/zk-batch-optimizations, opened at ed1b637 (2026-08-11).
Authority: Victor, console 2026-08-11 ("Let's move on to the next
stages ... it also provides pressure for us to get there faster") —
the speed round the roadmap's Section 4/5 levers and the Attestable
watch item (AGGREGATION_LITERATURE addendum 2026-08-11) both point
at. U-AG-B1 stays OPEN pending its FINAL (quiesced p50/p95 + A1
reconciliation — runs at THIS round's close when the box is quiet;
BL-F2 hiding-tails ruling and the [MODEL]-line reconcile ride that
FINAL).

Standing constraints inherited from U-AG-B1 verbatim (I-6 hard, Z1,
one-proof rule, exact-digit, freeze digests NEVER move, suite +
freeze-check green at every claim, [MODEL]/[MEASURED]/[MAC-BOX]
flags, codex-audit-* read-only, honest fallbacks). PERF-SPECIFIC
RULE: every optimization lane is DIFFERENTIAL — bit-identical
verdicts and unmoved freeze digests are the acceptance floor; a
speedup that moves a digest is a bug, full stop.

Baseline profile (wave-4 close, [MAC-BOX ~1T, NOISY-SHARED]):
composed P0 pass prove ~4,117-4,811 s (waves 68.8%, descents
25.5%, level-0 h cross-garbage Theta(n_0*r) at r=64 cap), verify
199.6 s post-split, m125 layer prove 250.4 s post-BF-F3; lookup
core 10.8 us/el scalar vs 0.5-1 us/el kernel-grade [MODEL]; U-K9
items B-D1..B-D3 (PROGRESS.md) still open — the oldest unclaimed
10-20x.

## Lanes (worktrees wt-uperf-pa/pb/pc/pd, branches uperf-pa..pd)

- PA (KERNEL, wt-uperf-pa): U-K9 at last — B-D1 lane-packed bulk
  slot arithmetic through the A1 kernel class + lazy reduction in
  round_poly/build_tree/fuse/descent hot loops; B-D2 KElem inline
  [u64;16]/SoA + streamed layers; B-D3 measured kernel report.
  Owns src/ring/kfield.rs + sumcheck.rs + gkr.rs + gkr_masked.rs
  INTERNALS (public API source-compatible — every other module
  consumes as-is). Differential battery: bulk path bit-identical
  to scalar; ALL freeze digests unmoved. Target class: the
  recorded 10-20x on the slot-mult-bound shares.
- PB (GPU RUNG, wt-uperf-pb): the first GPU kernel prototype per
  codex-gpu-readiness-2026-07-12 (verdict GO on prototyping) +
  GPU_PORT_CONTRACT.md. HONEST SCOPE: this box is Apple silicon —
  the prototype is Metal (or wgpu targeting Metal), proving the
  kernel STRUCTURE (NTT/ring-mult/commit hot loop off-loaded,
  bit-identical results vs CPU, measured speedup on THIS box);
  the CONTRACT's consumer-GPU rung (CUDA-class) remains
  conditional on hardware and is NOT claimed. Feature-gated build
  (default build unchanged); new zkmatrix-rs/src/gpu/ module +
  build plumbing only.
- PC (WAVE/OPENING OVERHEAD, wt-uperf-pc): the 68.8% — wave-round
  batching/lifting in ct_engine.rs + the level-0 h cross-garbage
  Theta(n_0*r) hot spot + the 1.03 s seed-XOF CRS expansion (BH's
  residual profile) in eval_proof.rs. Owns ct_engine.rs +
  eval_proof.rs internals (public API stable; PA does NOT touch
  these two files). Differential + digest discipline identical to
  PA. Target: measured pass-prove reduction with the profile
  attribution table.
- PD (ATTENTION INTEGER SPEC, wt-uperf-pd): the contract's
  declared 8B gap and the full-LLM comparability long pole —
  DESIGN round (M4 pattern: paper + Python spike, NO engine
  files): integer specifications for softmax, RMSNorm, RoPE,
  residual/embedding at the frugal-lm 125M shapes first (real
  activation ranges from the calibration study), gadget
  assignments from the existing family (matmul/Hadamard/lookup/
  range — softmax exp via the lookup class, normalization via
  range+requant), the claim-DAG extension, byte/prove cost
  derivations [MODEL], and the build-round obligation list. NEW
  docs/zkmatrix-poc/ATTENTION_INTEGER_SPEC.md + scripts/
  attention_spec_spike.py.
- Orchestrator: merges (PA/PC seam = none by file zones; PB
  feature-gated; PD doc-only), differential gates at every merge,
  U-AG-B1 FINAL quiesced pass + A1 reconciliation at this round's
  close, push, brief.

## Agent PA status (wt-uperf-pa)

- (lane launches here)

## Agent PB status (wt-uperf-pb)

- (lane launches here)

## Agent PC status (wt-uperf-pc)

- 2026-08-11 PLAN COMMIT (lane open at c081212, branch uperf-pc).
  Scope check done: read PROGRESS_UPERF (PERF RULE internalized:
  differential bit-identical bytes + digests + verdicts is the
  acceptance floor; transcript-CHANGING candidates go to the R-row
  appendix, not the build), UAGB1_PASS_AGG_REPORT (BG-F3 wall),
  UAGB1_AGG_STACK/VERIFIER reports (BD/BH structure + the 1.03 s
  CRS residual), RANGE_AGGREGATION_DESIGN Phase 5, M125_PASS_REPORT
  Section 5 (the 68.8% = 2,251.8 s of 3,275.1 s 12-layer prove,
  127 masked wave ct-rounds/layer at ~131 commitments), and both
  owned files end to end (ct_engine.rs 2459 ln, eval_proof.rs
  1434 ln) plus the callers (bf_layer_run wave loop, bg_prove_group
  / bg_level_h / bg_kernel_pass, bg_verify_group) and the kernel
  substrate (aux_ntt_core capacity discipline, mod.rs primitives).
- PLAN, in order, honest-fallback at every step:
  1. PROFILE FIRST (deliverable 1): env-gated (ZK_UPERF_PROF=1)
     phase accumulators INSIDE prove_ct_round (mask sampling /
     A1-A2 matvecs / claim combos / challenge hashing / center+
     rejection bookkeeping / attempt count) and inside
     eval_proof.rs (expand_level_matrix, matvec_modq_small,
     ring_ip_modq_small) — counters only, zero transcript effect,
     off by default. Plus a marked [UPERF-PC] bench arm in
     ring_matmul.rs: `uperf-pc wave-profile <layer> [t]` running
     the m125 layer prove path with the attribution printout and a
     WAVE-TRANSCRIPT SHA-256 (all CtRoundProof bytes, fixed test
     seeds) as the differential digest. Baseline table at T=512
     layer 2 (the report row) + small-T iteration shape; composed
     scope attributed via the same in-eval_proof counters under
     `pass-agg prove`-shaped small runs + BG-F3 arithmetic.
  2. Optimizations by measured share, TRANSCRIPT-PRESERVING only,
     each landing with its own differential check at fixed seeds
     (bytes SHA equal, digests unmoved, verdicts equal):
     O1 expand_level_matrix memo cache (eval_proof internal;
        values byte-identical by construction — kills the 1.03 s
        BH residual class + double re-expansions in verify);
     O2 the Theta(n_0*r) h cross-garbage restructure (the BG-F3
        wall): batch single-prime NTT MAC — phi slices transformed
        once (in place, exactly restored), w slices streamed, pair
        accumulation pointwise in Z_p under the aux capacity
        contract (chunk*D*(q/2)*2^(e-1) checked at runtime via
        aux::capacity, kara fallback if it ever fails), one
        inverse transform per pair — exact mod-q regrouping,
        values bit-identical; new eval_proof API + minimal marked
        call-site switch in bg_level_h (both call sites);
     O3 matvec_modq_small same-class NTT MAC internal (the
        that/u_i matvec share, ~kappa*n_0 kara-muls at pass
        scope);
     O4 prove_ct_round allocation/borrow work: drop the all_x
        clone, reuse attempt buffers, alloc-free combo
        accumulators, flat-norm without re-materialization —
        RNG-ORDER-PRESERVING (the draw sequence is the
        transcript);
     O5 wave-caller clone removals via additive _ref variants
        only if measured to matter.
  3. Walls / cross-zone findings (measured, FILED not built):
     gaussian_ivec economics (~10% proposal acceptance x 2 u64
     draws/proposal — any sampler change moves proof bytes at
     fixed seeds => R-row), XofReader per-8-byte alloc (mod.rs,
     off-zone), a1/a2 mask-matvec shared column transforms
     (commit.rs/aux off-zone), 1T thread model kept (recorded
     [MAC-BOX ~1T] baseline — no new parallelism).
  4. Gates at HEAD: build, freeze-check, full suite, agg-matmul
     battery, ixf-fold battery, my differential battery; then
     U_PERF_WAVE_REPORT.md (attribution, before/after, cumulative,
     R-row appendix, digest evidence) + this section updated.
  Files touched: ct_engine.rs + eval_proof.rs internals (public
  API source-compatible), marked [UPERF-PC] section in
  ring_matmul.rs, U_PERF_WAVE_REPORT.md, this section. NOT
  touching: kfield/sumcheck/gkr/gkr_masked (PA), lookup/digits/
  fold/pass_agg/t_blind/descent_fold/manifest/wire, other ledger
  sections.

## Agent PD status (wt-uperf-pd)

- (lane launches here)

## Blocker

(none so far)

## Log

- 2026-08-11: tranche opened at ed1b637 on Victor's console go;
  four lanes launching in worktrees. Competitive context recorded
  (Attestable watch item) — pressure, not panic: differential
  discipline unchanged, honesty rules unchanged.
