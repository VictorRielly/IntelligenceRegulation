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

- PLAN (2026-08-11, lane open at c081212). Situation read: U-K9's
  kernel layer ALREADY landed at ecd2482 (KKern/KTab lane-packed u32
  SoA + lazy reduction; gkr/sumcheck/gkr_masked bulk dispatch; [U-K9]
  differential battery; 12.48 -> 5.21 us/el on the then-shared x86
  box) — but the tranche never closed: the in-place fold/eq-double
  residue (uk9-residue-2026-07-12.patch, no longer applies — kfield
  gained layout asserts in c377d0d) was never landed, B-D2's RSS
  table and streamed-leaf construction never happened, no kernel
  report exists, PROGRESS.md B-D1..D3 still open. Lane plan:
  * S0 skeleton: [U-PERF-PA] marked bench arm `uk9-bench
    <log2_n> [scalar|bulk|stream]` in ring_matmul.rs replicating
    lookup-bench's exact workload (same seeds/shape; lookup-bench
    itself UNTOUCHED as the yardstick) + peak-RSS readout; baseline
    sweep on THIS box (M3 Ultra, portable kernel path — AVX2 arm is
    dead code here; all numbers [MAC-BOX], 1T).
  * S1 (B-D1 finish): rebase the residue onto current kfield.rs —
    in-place packed fold (kt_fold allocation-free) + in-place eq
    doubling; call sites layer_sumcheck_bulk/masked_rounds_bulk/
    kt_mle_eval/kt_eq_table; battery legs extended; freeze-check +
    [U-K9] battery green at every step.
  * S2 (B-D2): streamed leaf construction — additive builder in
    gkr.rs packing leaves straight into KTab (no boxed leaf vectors),
    battery leg bulk==stream bit-identical; KElem stays Vec<u64> per
    the recorded U-K9 ledger decision (ring_matmul binds ...to_vec()
    — an inline [u64;16] KElem is not source-compatible; SoA is
    delivered where it matters, in the layers). RSS measured at
    2^20/2^22 (+2^23 headroom probe; this box is 256 GB — the 15 GB
    deployment wall is reported as arithmetic, not re-measured).
  * S3 (B-D3): U_PERF_KERNEL_REPORT.md — us/el scalar-oracle vs
    base-bulk vs HEAD at lookup-bench shapes, m125 layer prove
    before/after at the same layer, composed-pass point if wall-clock
    permits; attribution lazy-reduction/lane-occupancy vs
    layout/allocation; honest [MAC-BOX]/[NOISY-SHARED] flags.
  * Gates before exit: freeze-check, self-test suite,
    uagb1-digit-battery, matmul-statement battery, ixf-fold battery
    at HEAD, differential arms green. Differential floor: bulk paths
    bit-identical to the scalar oracle; EVERY pre-existing freeze
    digest unmoved.

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

- PLAN (2026-08-11, committed before work). Deliverables:
  docs/zkmatrix-poc/ATTENTION_INTEGER_SPEC.md (NEW),
  scripts/attention_spec_spike.py (NEW, stdlib+numpy), one dated
  additive note in TRANSFORMER_PROOF_PLAN.md Section 2, this ledger
  section. Design decisions the spike must machine-check: (1)
  softmax exp via the HOUSE LOOKUP CLASS at a 256-row per-(eS, d_h)
  table family (silu-int8-table-v2 family precedent); range
  reduction stated exactly as: proven power-of-two requant of raw
  scores to the calibrated int8 grid, then EXACT row-max
  subtraction — dominance = the [0, 2^8) range fact on d = m - s,
  attainment = a binary argmax selector (RangeLookup w1 +
  row-sum-1 thin sumcheck + z o d = 0 zero-check); (2) causal mask
  by public-weight derivation of the masked score read sM (no
  masked-leaf machinery; d in [0,254] structural, full-rectangle
  lookup); (3) BOTH normalizations (softmax row-normalize, RMSNorm)
  as floor-division relation facts — deg-3 zero-check with
  broadcast divisor + two-sided remainder range facts — the
  reciprocal-class fact in the range/lookup vocabulary, no
  floating-point escape; (4) RMSNorm sqrt as the isqrt fact pair
  D^2 <= SS + Ceps < (D+1)^2 (two range facts + one self-Hadamard);
  the rsqrt TABLE alternative REJECTED with the
  mantissa-normalization variable-shift arithmetic recorded; (5)
  RoPE via frozen PUBLIC cos/sin integer tables + the bit-flip MLE
  read (degree-2, non-interleaved mlx convention); (6) GQA via
  public head-map weights on the K/V side; (7) embedding: public-
  input form = public-selector matmul claim; private-input form =
  the one OPEN gadget, priced honestly (AZ-T1 style); unembedding =
  standard matmul (tied Emb reused), last-position variant priced.
  No new claim family for P0/P2 modes. Costs [MODEL] derived per
  layer + per pass at 125M and 7B/8B, anchored on M125_PASS_REPORT
  measured lines and the F-IF1/kel byte model. Gates: spike seeded
  + green < 10 min; python suite green from worktree root; no Rust
  files touched; no push.

## Blocker

(none so far)

## Log

- 2026-08-11: tranche opened at ed1b637 on Victor's console go;
  four lanes launching in worktrees. Competitive context recorded
  (Attestable watch item) — pressure, not panic: differential
  discipline unchanged, honesty rules unchanged.

## Round status (orchestrator, 2026-08-12) — lanes ended early, work salvaged

All four U-PERF lane agents terminated mid-flight on a model usage
limit (not a technical failure). Every lane's committed work was
surveyed, verified, and merged by the orchestrator; the uncommitted
work in PA/PD/PV-S2 was verified and committed on their behalf.
What LANDED vs what remains:

- **PA (kernel) — LANDED, U-K9 CLOSES.** Lane-packed bulk slot
  arithmetic + lazy reduction + streamed leaves across
  kfield/sumcheck/gkr/gkr_masked. MEASURED on the uk9-bench
  yardstick (2^18 int8 SiLU lookups, 1T [MAC-BOX]): scalar 8,965
  ns/el -> bulk 2,284 (3.93x) -> stream 2,221 (4.04x); primitive
  attribution layout/lanes 1.55x x reduction-discipline 1.44x =
  2.23x (packed lazy 103.2 ns/K-mult). DIFFERENTIAL FLOOR MET:
  root+transcript digest 979e4d82b4db7f6d IDENTICAL across all four
  modes; freeze-check green; every pre-existing digest unmoved.
  PROGRESS.md B-D1/B-D2/B-D3 are answerable from this lane's report.
  NOTE the honest gap vs the ladder's model: 2.2 us/el is 4x off
  the 10.8 baseline but still ~2-4x above the 0.5-1 us/el
  kernel-grade [MODEL] target — the remaining factor is the
  AVX2/NEON-width and multithreading axes, neither claimed here.
- **PD (attention integer spec) — LANDED.**
  ATTENTION_INTEGER_SPEC.md + attention_spec_spike.py 18/18 (734
  range facts, 522 identities, 100 s, seeded): softmax with exact
  row-max + range-reduced exp on the lookup family + division-
  relation normalization (declared honestly as NOT exact
  row-stochasticity — row mass in [282, 512] against 2^9),
  RMSNorm isqrt, public-table RoPE, GQA public map, residual and
  embedding. The contract's declared 8B gap now has a written,
  machine-checked integer specification at 125M shapes.
- **PC (wave/opening) — SKELETON ONLY.** Profile counters +
  differential-digest hooks (observation-only, off by default) and
  the harness arms landed; NONE of the four planned optimizations
  (O1 CRS memo / O2 h-garbage / O3 matvec NTT / O4 alloc
  discipline) were reached. The 68.8% wave share is UNTOUCHED —
  this is the round's largest unclaimed CPU factor and the first
  item of any resumption.
- **PB (GPU) — PLAN ONLY, NOT MERGED.** The plan commit (A1
  batch-NTT commit kernel on Metal, feature-gated gpu-metal
  default-OFF, differential battery vs A1CommitKernel) and dirty
  Cargo plumbing remain on branch uperf-pb; no kernel was written.
  The GPU rung stays entirely unbuilt and every GPU row in the
  cost docs stays [ASSUMED].

Also landed this session: PV-S2 (music pillar, song-scale
block-chained Pi1 over a real 60-block WAV session; whole-song
prove 54.6 s / verify 30.7 s [MAC-BOX]) with a genuine finding —
the toy-parameter COMPLETENESS tail becomes visible at song scale
(one honest block rejected in one run; identical re-run all-60
green; unseeded prover masks over a 240-repetition conjunction),
recorded with its fix direction in MUSIC_PROVENANCE_POC.md.

RESUMPTION QUEUE (unchanged in priority): PC's four optimizations
(the 68.8%), PB's Metal kernel, PA's remaining width/threading
axes, then the U-AG-B1 FINAL (quiesced p50/p95 + A1
reconciliation + BL-F2 ruling + the [MODEL]-line reconcile).
