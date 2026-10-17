# GPU ZERO-CHECK lane (speed plan task 2), progress ledger

Lane: move the FFN F-slot (slot 18, `SC_FZC`) masked zero-check of the
private block onto the laptop RTX 4070 (8 GB, 256 GB/s) with a byte-identical
transcript, and measure the achieved bandwidth (the plan's GO/NO-GO number,
`docs/zkmatrix-poc/ZK60_SPEED_PLAN_20261017.md` section 6 task 2).

Write set: `ops/zkp-mvp/gpu-zerocheck/` (rsync of the frozen
`ops/zkp-mvp/trained-1b-review-r3/`, target dirs excluded) and this
directory. No git. Every build/test/proof through
`scripts/zk60_resource_guard.py`.

## Ledger (UTC)

- 2026-10-17T13:40Z lane start; read CLAUDE.md, ZK60_RESOURCE_PROTOCOL.md,
  the speed plan, `results/zk60_1b_native_20261017/r4/PHASES_T128.md`, the
  research handoffs (device round, grouped fused round, fused fold round,
  split-eq accumulation), `gpu/{cuda.rs,mod.rs,kernels.cu}`,
  `zkp-core/src/sumcheck/rounds.rs`, `hashline/src/zk.rs`
  (`masked_prove_rounds`), `private_block/argument.rs` (`run_slot`,
  `SC_FZC`).
- 13:47Z workspace copied (`baseline_sources.sha256`: 196 files, the frozen
  review-r3 sources before any edit).
- 13:50Z guarded warm-up build of the copy queued (`logs/b0-warm-debug.*`);
  the heavy lock was held by another lane's cpu job.
- 13:56Z warm-up build done (42 s, peak 1.44 GiB). G1 design written:
  `DESIGN.md` (what moves / stays, layout, counted traffic per round, why
  the bytes are identical, tests, measurement plan).
- 14:00-14:20Z G2 code in the lane copy (type-checks with and without
  `--features gpu-cuda`, light-class `cargo check -j1` capped at 1.5 GiB while
  another lane held the heavy lock: `logs/k*-check-*.log`):
  - `hashline/src/gpu/fzc.rs` (new, every config): `FzcDesc` (the public
    parameters of `SC_FZC`'s polynomial), its layout check and parameter
    block, `FzcDesc::eval` (host mirror of the kernel expression), the
    switches `HL_GPU_ZEROCHECK` / `HL_GZC_CHECK` / `HL_GZC_PROFILE`, and
    `prove` (device attempt on a cloned transcript; `Err` leaves `tr` alone);
  - `gpu/kernels.cu`: `k_fzc_round_d{4,5}[s]` (round sums, v1),
    `k_fzc_fold_round_d{4,5}[s]` (fused fold + next round, v2, default),
    `k_fzc_expand`, `k_fzc_finals`;
  - `gpu/cuda.rs`: `DevFzcRounds` (a `SumcheckRounds` evaluator; tables built
    on the device from resident A/H rows, `ClosureRounds::recover_one`'s R1d
    logic line for line), `FzcStats` counted bytes/seconds, `fzc_totals`;
  - `private_block/argument.rs`: `SlotDef.fzc` captured in the `SC_FZC` arm
    from the closure's own variables; `ProverData.dev` (resident A/H);
    `run_slot` dispatch (`device_fzc`: sources from the definition, decline
    through `gpu::declined` = panic under `HL_GPU_REQUIRED=1`, shadow check);
  - `protocol.rs` passes the resident commitments; `trained_block.rs`
    stack-prove prints the switch in the header and a `gpu_zerocheck` summary
    (device sumchecks, shadow checks passed, declines, totals);
  - tests `private_block/gpu_zc_tests.rs` (descriptor == closure at every
    shape; layout refusals; device == CPU on synthetic edges, real slot 18 at
    small and trained shapes from host words and resident rows; seeded
    proof-byte gate; fail-closed; cube-size ladder).
- 14:19Z first device test run queued (`logs/t1-debug-small.*`, gpu class);
  heavy lock held by another lane's cpu job since 14:00Z.
- 14:25-14:45Z (still queued for the heavy lock / the 11.9 GiB budget):
  NVRTC compile check without a device (`nvrtc_check.py`): the eight round
  kernels inside `kernels.cu` made the per-process start-up compile 26 s
  (from 4.5 s). Moved them to `gpu/fzc_kernels.cu`, compiled lazily, one
  variant per module (`fzc_module`); every variant NVRTC-compiles (v2 D5+gate
  6.8 s, lean 3.3 s). Added the v3 lean evaluation (`HL_GZC_LEAN=1`,
  DESIGN.md section 9). Tests now cover v1, v2, lean and lean-unfused.
- 14:59:49Z `t1-debug-small` started, killed 6 s later (exit 143) by the
  clean box shutdown at 14:59:58Z (still compiling; nothing ran on the
  device). `c1-check-gpu` killed too. Box rebooted 18:21Z, `/tmp` wiped.

### Session 2 (successor agent, from 18:28Z)

- 18:28Z resumed; read LANE_RULES_20261017.md, this ledger, DESIGN.md, the
  speed plan sections 4-6, the lane code. Guard status: idle box, heavy lock
  free, GPU 0 MiB.
- 18:28:33-18:28:56Z `b1-testbin-debug` (build class, gpu-cuda, debug test
  binary): exit 0, 23 s, peak 1.74 GiB.
- 18:29Z `t2-debug-small` queued (gpu class, debug): synthetic edges +
  real slot 18 at every small shape (host words and resident rows) +
  descriptor/layout tests.
- 18:29:20-18:31:44Z `t2-debug-small` exit 0 (145 s, peak RSS 0.89 GiB,
  peak VRAM 441 MiB): FIRST DEVICE RUN, no code change needed. 4 passed:
  descriptor == closure at the 8 small shapes; layout refusals; 240
  synthetic device bodies (n 1,2,3,4,7,10; D 4/5; gate/pad on/off; claim
  None/correct; v1, v2, lean, lean-unfused) == CPU body; real slot 18 at
  the 8 small shapes, dense random data, host words AND device-resident
  rows, lean 0/1, claim None/given: 64 "GZC device == CPU" lines
  (`logs/t2-debug-small.log`).
- 18:30Z release test binary + CLI example builds queued (`b2`, `b3`).
- 18:31:45-18:36:29Z `b2-testbin-release` exit 0 (285 s, 1.64 GiB);
  18:36:29-18:38:08Z `b3-example-release` exit 0 (98 s). CLI copied to
  `bin/zk60_trained_block.gpu.release.bin` (sha256 in `bin/binaries.sha256`).
  Lane patch vs frozen review-r3: `gzc-vs-review-r3.patch` (12 files);
  source hashes `lane_sources_after.sha256`.
- 18:47:40-18:48:36Z `t3-release-small` exit 0 (waited 657 s for another
  lane's lock; 56 s; peak VRAM 441 MiB): 5 passed. 360 synthetic device
  bodies == CPU (release adds the WRONG initial claim, which only the R1d
  recovery reproduces); descriptor == closure at rung-TC, TinyLlama T32
  (n 18) / T128 (n 20), 8B T32 (n 19), all degree 5, 21 tables, pad on.
- 18:49Z queued `t4-release-trained` (real slot 18 at the trained shapes)
  and `t5-release-seeded` (seeded proof-byte gate), separate guarded jobs.
- 19:02:43-19:07:25Z `t4-release-trained` exit 0 (waited 826 s; 282 s;
  peak RSS 2.41 GiB, peak VRAM 1,653 MiB): real slot 18 == CPU body at
  rung-TC (n 14 D 4 k 20), TinyLlama T32 (n 18) and T128 (n 20), 8B T32
  generic (n 19), all D 5 k 21: dense random AND honest-witness data,
  device-resident rows (plus host words at rung-TC), lean 0/1, claim
  none/given; masked rounds, challenges, finals, transcript state and next
  challenge equal (36 lines). Device bodies at 2^20 incl. table build:
  v2 56-81 ms, lean 37-43 ms (first body per variant includes NVRTC).
- 19:07:26-19:07:38Z `t5-release-seeded` exit 101: the TEST's header
  `protocol::transcript` refuses trained-calibration shapes by design
  (R2-4/F-2 assert, protocol.rs:118). Nothing proved. FIX (test only): the
  gate now starts from `protocol::tagged_transcript(sh, profile)` + its
  label + expected-IO + public digest + schedule digest (the run header's
  form); both arms start from the same state.
- 19:10Z also: ladder loops over the four variants in one process
  (`GZC_BENCH_VARIANTS`, default v2,v1,lean,lean-unfused) with one extra
  profiled body per variant (`GZC_BENCH_PROFILE=1`, per-round lines with
  `GZC_BENCH_ROUNDS=1`); cuda.rs: profile line names the module and
  fused/unfused, per-round log under `HL_GZC_ROUNDS=1` (profile mode only;
  no transcript effect).
- 19:18Z `b4`/`b5` rebuild (tests, CLI) running; queued
  `t6-release-seeded-failclosed` (HL_GPU_REQUIRED=1) and `t7-release-ladder`.
