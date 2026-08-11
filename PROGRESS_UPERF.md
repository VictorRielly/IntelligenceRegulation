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

- (lane launches here)

## Agent PD status (wt-uperf-pd)

- (lane launches here)

## Blocker

(none so far)

## Log

- 2026-08-11: tranche opened at ed1b637 on Victor's console go;
  four lanes launching in worktrees. Competitive context recorded
  (Attestable watch item) — pressure, not panic: differential
  discipline unchanged, honesty rules unchanged.
