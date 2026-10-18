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
- 19:18:01-19:21:44Z `b4-testbin-release` exit 0 (223 s);
  19:21:44-19:23:02Z `b5-example-release` exit 0 (78 s).
- 19:27:11-19:30:57Z `t6-release-seeded-failclosed` exit 0 (226 s, peak
  RSS 2.04 GiB): **SEEDED PROOF-BYTE GATE BYTE-IDENTICAL** at rung-TC
  (7,591,336 B, blake3 0b618a6a86753571), TinyLlama T32 (11,627,208 B,
  e86ce37599757717), TinyLlama T128 (23,049,192 B, 316ffb3cde4cabf5), 8B
  T32 generic (14,856,216 B, 0bc83ddf85d5cc1f), under HL_GPU_REQUIRED=1
  (a decline would have panicked) with the device body counted once per
  device arm; fail-closed test: the refused layout panics with "fail
  closed", counted, transcript untouched.
  **VRAM VIOLATION: peak_vram 7,123 MiB** (lane limit 4 GiB; guard global
  kill 7,400 MiB). Coordinator flagged it 19:31Z.
  FINDING (19:33Z): the device buffer pool (`gpu/cuda.rs` `POOL`, up to 64
  buffers matched by EXACT length, no byte cap) is never drained on the
  private-block path (only `zk.rs`'s older prover calls
  `gpu::dev_pool_drain`). The seeded gate ran four shapes x two
  `prove_core` runs in ONE process, so every shape's GPU-commit buffers
  (encodings, Merkle scratch) stayed pooled into the next shape: the sum
  over shapes, not any single proof, reached 7.1 GiB. Not the fail-closed
  test (it refuses before any allocation), not NVRTC, not a context per
  thread (`--test-threads=1`, one context). In a stack all blocks share a
  shape, so exact-length reuse holds the footprint (baseline T128 GPU
  stack 3,105 MiB).
  FIX (test code only, no prover path): `drain_device_pool` after every
  shape and arm (trained equality test, seeded gate) and after every
  ladder size, printing device memory in use before/after; `GZC_SHAPES`
  (rung-tc, tl32, tl128, 8b32) so each large shape runs in its own guarded
  GPU command. The guard has no per-job VRAM cap (global 7,400 MiB); the
  4 GiB limit comes from the job design. From now on every GPU job's
  `peak_vram_mib` is recorded here. So far: t2 441, t3 441, t4 1,653,
  t5 125, t6 7,123 (violation), t7 1,457 MiB.
- 19:30:58-19:31:35Z `t7-release-ladder` exit 0 (37 s, peak VRAM 1,457
  MiB; started before the coordinator's message, footprint counted at
  < 2.7 GiB): every variant == CPU body at 2^18..2^21 (synthetic, the real
  layout). Its device-body times are dominated by the H2D upload of the
  synthetic HOST tables (WSL pageable copy, ~2.3 GB/s); the profiled split
  is the useful part. At 2^20, excluding the upload: v2 fused 49.7 ms
  (round 0 18.7, fused rounds 27.3, reduce+D2H+host 3.6), v1 51.6, lean
  fused 29.8 (10.0 / 16.5 / 3.3), lean unfused 30.8 ms. k_sc_fold streams
  at 145-171 GB/s (57-67% of 256). Every round kernel has a FLOOR of
  ~170-340 us even at 4 pairs (a synced tiny fold: ~45-60 us), i.e. the
  serial latency of one pair evaluation.
- 19:35Z `fzc_regs.py` (NVRTC sm_89 + ptxas -v, no device;
  `logs/fzc_regs.txt`): EVERY round kernel uses 255 registers and spills
  (v2 D5: 2,596 B spill stores / 3,848 B loads per thread, round kernel;
  lean D5: 1,052 / 1,100 B). 255 regs x 128 threads -> 2 blocks/SM = 8 of
  48 warps (16.7% occupancy): latency-bound, not bandwidth- or
  issue-bound.
- 19:38Z stack scripts: `stack.sh` capped at 30 min (need 4.5 / cap 7);
  `verify.sh` = fresh-process verify with the FROZEN review-r3 CPU binary
  (unchanged verifier sources), expecting the CPU run's identity 53a5667d...
  (r3/r4 T128 ho00). CLI restaged from b5 (sha256 95b48294...).
  Queued b6 (tests), t9 (seeded gate, T128 alone), s1-lean (+verify),
  s0-base.
- 19:48:43-19:51:52Z `t9-seeded-tl128` exit 0 (189 s; peak RSS 1.86 GiB;
  **guard peak VRAM 3,393 MiB**): byte-identical at T128 alone (23,049,192
  B, blake3 d75889c82f35ffc3; it differs from t6's 316ffb3c... because
  `prepare_endpoints` commits the endpoints with fresh OS randomness per
  PROCESS — both arms of one process share them, which is what the gate
  compares). In-process cuMemGetInfo
  (device-wide total-free): 4,079 MiB in use after the CPU arm (9 pooled
  buffers), 4,447 MiB after the device arm (8 pooled), 1,199 / 1,247 MiB
  after the drains. So the slot-18 table buffer (336 MiB, fresh, exact
  length) sat on top of ~2.9 GiB of pooled commit scratch.
- 19:55Z FIX 2 (prover, value-neutral): `DevFzcRounds::new` takes its
  table buffer with `Pooled::take_min` (smallest idle pooled buffer of at
  least k x 2^n Fp2) so inside a proof it reuses idle commit scratch
  instead of adding VRAM; kernels index only [t 2^n, (t+1) 2^n). Rebuild
  queued (b7 tests, b8 CLI -> `bin/...r2.bin`, `stack_r2.sh`); queued
  `t10-trained-all-r2` (every trained shape, equality + seeded gate, drains
  between shapes, HL_GPU_REQUIRED=1). s1-lean/s0-base keep the b5 binary
  (their scripts are already running; not touched).
- 19:51:53-19:54:38Z `s1-lean` (b5 CLI, HL_GPU_ZEROCHECK=1 HL_GZC_LEAN=1
  HL_GZC_PROFILE=1, HL_GPU_REQUIRED=1): exit 0, 165 s wall, peak RSS 1.66
  GiB, **guard peak VRAM 3,457 MiB**; 22 device slot-18 sumchecks, 0
  declines. Fresh-process verify (r3 CPU binary, expected 53a5667d...):
  exit 0, 23 s (`stack-s1-lean/verify.log`). Slot-18 phase summed over 22
  blocks: 8.53 s (CPU r4 17.63 s; GPU-arm r4 19.48 s); device body 6.47 s
  (block 0 2.61 s incl. the NVRTC compile of `gzl_d5s`), extension rounds
  (host) 1.95 s. BUT the device body is ~180 ms per block in the stack
  (build 34, round 0 ~50, fused rounds ~94, reduce+D2H ~5 ms) against
  ~30-43 ms for the same 2^20 slot in isolation: a uniform ~5x slowdown,
  steady over all 22 blocks.
- 19:56Z diagnosis: hypotheses (a) WDDM host-paged device memory near the
  budget inside a proof, (b) GPU at a low clock after the 2-3 s CPU-only
  slots 14-17 (idle card: P8, 210 MHz). Added a profile-only memory
  snapshot at slot-18 start (`PB-GZC-MEM`: free device memory, the pool's
  idle buffers); `gpu_sampler.sh` (nvidia-smi queries ~3/s: P-state, SM/mem
  clocks, power, memory used, utilisation; ends on the run's .done).
- 19:55:01-19:57:56Z b7 (tests) exit 0; 19:57:56-19:59:15Z b8 (CLI) exit
  0 -> `bin/zk60_trained_block.gpu.release.r2.bin` (sha256 c2cf625f...,
  contains take_min + PB-GZC-MEM). Queued `s4-diag` (r2, lean, profile +
  per-round lines) + verify, with sampler; sampler also armed for s0-base.
- 20:02:53-20:09:13Z `t10-trained-all-r2` (r2 code: take_min + drains;
  HL_GPU_REQUIRED=1) exit 0, 380 s, peak RSS 2.16 GiB, **guard peak VRAM
  3,125 MiB** for ALL four shapes in one process. 36 "device == CPU" lines
  again (equality at every trained shape, both data kinds, lean 0/1, claim
  none/given); seeded gate byte-identical at all four shapes (rung-TC
  7,591,336 B 56f8baf6..., TL T32 11,627,208 B 8ba7e328..., TL T128
  23,049,192 B 1eef72e0..., 8B T32 14,856,216 B 59485a30...; per-process
  digests, endpoints are OS-random). In-process device memory in use is
  now the SAME after the device arm as after the CPU arm (T128 4,131 /
  4,131 MiB; 8B T32 3,427 / 3,395 MiB): slot 18 adds no VRAM. prove_core
  wall, slot 18 CPU -> device (v2, modules already compiled): rung-TC
  1.37 -> 1.18 s, TL T32 2.63 -> 2.02 s, TL T128 5.33 -> 4.61 s, 8B T32
  3.68 -> 2.94 s (shared box, n=1).
- 20:21-21:03Z heavy queue jammed: the native lane's
  `r5-ladder8b-T128-cpu` guard held the heavy lock while waiting for 7 GiB
  of budget held by two light jobs of other lanes. Told the coordinator
  (SendMessage to main, 20:45Z); it held the calibration lane's launches.
- 21:10:45-21:13:37Z `s0-base` (b5 CLI, HL_GPU_ZEROCHECK=0, GPU arm):
  exit 0, 173 s, peak RSS 1.83 GiB, **guard peak VRAM 3,105 MiB**. Slot-18
  phase 17.54 s (CPU body 14.84 s, tables 0.92 s, extension 1.65 s); sum
  of block walls 134.42 s. Telemetry (`stack-s0-base/gpu_samples.csv`, 564
  samples): the card NEVER left P4/P5/P8; SM <= 1,155 MHz (median 1,065
  when busy), memory 6,000 MHz, power <= 35 W.
- 21:23:52-21:26:31Z `s4-diag` (r2 CLI, lean, HL_GZC_PROFILE=1
  HL_GZC_ROUNDS=1): exit 0, 159 s, peak RSS 1.65 GiB, **guard peak VRAM
  3,105 MiB = the baseline** (take_min: slot 18 adds no VRAM); 22 device
  sumchecks, 0 declines; fresh verify exit 0 (19 s, identity 53a5667d...).
  Slot-18 phase 8.11 s (device body 6.25 s of which block 0 2.56 s incl.
  NVRTC; extension 1.76 s on the host); sum of block walls 122.64 s.
  Steady blocks (1-21) median: body 182 ms = build 34.4, round 0 49.2,
  fused rounds 92.8 (rounds 1-5 81.8, tail rounds 6-19 10.5), reduce+D2H+
  host 4.7 ms. `PB-GZC-MEM`: 4,076 MiB device memory FREE at every slot-18
  start (pool 8-10 idle buffers, ~1.4 GiB): no memory pressure.
  DIAGNOSIS: per-round kernel times vs the isolated ladder: large rounds
  5.3-6.8x slower, but the TINY rounds (a few pairs, no traffic: pure
  serial latency of one thread) also 2.5-4x slower (450-830 us vs 205-230
  us), recovering to ~1.2x in the last rounds of some blocks after ~140 ms
  of continuous GPU work; reduce+D2H+host per round is the same as
  isolated (210-370 us). Telemetry (`stack-s4-diag/gpu_samples.csv`):
  P4 (SM <= 1,200 MHz, mem 6,000 MHz) at up to 99% utilisation, and P5
  (SM ~300 MHz, mem 810 MHz) at up to 73% utilisation. => the in-stack
  slowdown is the laptop GPU's power management (DVFS): with the rest of
  the prover on the CPU, the card idles ~90% of each block and the driver
  keeps it in P4/P5; not transfers (reduce/D2H unchanged), not launch
  count (~80 launches, ~21 syncs per sumcheck, ~1-2 ms), not paging (4 GiB
  free, tiny rounds slowed too), not CPU-thread contention for the GPU
  (the host waits during the body). Isolated-clock comparison queued
  (`t11-ladder-clock`, ladder n 20 lean+v2 with telemetry).
- 21:44:27-21:44:47Z `t11-ladder-clock` exit 0 (20 s, peak VRAM 481 MiB):
  isolated profile reproduces t7 (lean: round 0 11.7, fused 18.5,
  reduce 2.8 ms; v2: 20.6 / 29.4 / 3.3 ms). Telemetry: the card ALSO sits
  in P4 (SM ~1,065 MHz, mem 6,000 MHz) in isolation; it never boosts on
  this box in either run. So "isolated = boost clocks" is FALSE; the
  stack differs by P5 samples (SM ~300 MHz, mem 810 MHz) at up to 73%
  utilisation. The CLI stack path spawns no threads (no concurrent CPU
  work during slot 18).
- 21:52Z decisive probe (diagnosis only): `HL_GZC_WARM_MS=W` launches a
  pure-arithmetic spin kernel `k_fzc_spin` (16 registers, no table, no
  transcript) for ~W ms before slot 18 touches the device and prints the
  first/last launch times (`PB-GZC-WARM`): a falling spin time = the SM
  clock rising. Queued: b9 CLI -> `bin/...r3.bin` -> `s5-warm` (lean,
  profile, per-round, WARM 300 ms) + verify + sampler; and `t12-ladder-warm`
  (isolated reference with the same probe).
- 21:56:59-22:00:39Z `t12-ladder-warm` exit 0 (220 s incl. the test
  build; peak VRAM 481 MiB). **CLOCK RAMP MEASURED**: first warm-up of the
  process (after the 0.7 s CPU body, GPU idle): spin launch #1 9,946 us,
  mean of the first 5 6,871 us, mean of the last 5 1,275 us (104 launches
  in 300 ms); the next two warm-ups (card already busy): 1,222-1,272 us from
  the first launch. => this laptop GPU runs pure integer arithmetic 5-8x
  slower for the first ~100-200 ms after an idle period, i.e. for about
  the whole of one in-stack slot-18 body (150-190 ms after 2+ s of CPU-only
  slots 14-17). Isolated lean profile unchanged (round 0 11.6, fused 18.4,
  reduce 3.1 ms).
- 22:12-23:00Z heavy queue again held by other lanes' suites (r4-suite,
  r5b-suite1, tio-s1-suite); b9 waited 55 min. Coordinator told of the
  diagnosis (SendMessage 22:25Z).
- 22:59:27-23:00:49Z b9 (CLI) exit 0 -> `bin/...r3.bin` (sha256
  62b5adc4..., contains the spin probe).
- 23:00:49-23:03:59Z `s5-warm` (r3 CLI, lean, profile, per-round,
  HL_GZC_WARM_MS=300): exit 0, 190 s, peak RSS 1.58 GiB, **guard peak VRAM
  3,105 MiB**; fresh verify exit 0 (24 s, identity 53a5667d...). **IN-STACK
  CONFIRMATION**: every block's spin probe starts cold (launch #1 ~6.9 ms,
  first-5 mean ~6.2 ms) and ramps to ~1.22 ms; AFTER the warm-up slot 18
  runs at the ISOLATED speed: median (blocks 1-21) round 0 12.1 ms
  (isolated 11.6-11.7), fused rounds 18.8 ms (18.4-18.5), table build ~8.6
  ms (309.1 incl. the 300 ms warm-up; 34.4 cold), reduce+D2H+host 2.7 ms:
  ~42 ms vs 182 ms cold. The four blocks whose warm-up had not finished
  ramping (last-5 spin 2.8-5.7 ms) show round 0 at ~28 ms. (This run's
  slot-18 phase includes 22 x 0.3 s of warm-up: not an end-to-end number.)
- 23:06Z ALL JOBS OF THIS LANE FINISHED (every `.exit`/`.done` present;
  no sampler or wrapper running). Final numbers, verdict and the proposed
  next step are in the hand-back report to the coordinator (the harness
  refused the subagent's write of `REPORT.md`; the coordinator saves it).
  VERDICT (plan section 6 decision rule): achieved bandwidth on the plan's
  figure (72 B x 2^20 x 17 = 1.2835 GB per slot-18 body at TinyLlama T128):
  lean 42 ms = 30 GB/s = **11.7% of 256 GB/s** [MEASURED, isolated and
  in-stack warm, incl. the table build]; v2 (code default) 62 ms = 8.0%;
  v1 ~7.9%; cold in the laptop stack 182 ms = 2.7% (DVFS). Band 10-25% ->
  **kernel-design work before porting more slots**.

### Round 2: K1-K4 (coordinator brief, session resumed 23:21Z)

Brief: slot 18 only, lane copy. (0) lean as the default variant; K1 the
term-group split kernel (no spills, >= 24 warps/SM, checked with ptxas -v);
K2 the support table resident per process or generated on the device; K3
the reduction folded into the round kernel with a pinned 96-byte result
(one launch + one sync per round); K4 the tail rounds below 2^10 in one
kernel or on the host. Acceptance: the existing gates unchanged (t3
synthetic incl. wrong-claim R1d, t10 trained equality at all four shapes +
the seeded proof-byte gate, a 22-block stack verified in a fresh process
with identity 53a5667d...), 0 declines, VRAM <= 4 GiB per job. Measure the
isolated ladder with HL_GZC_WARM_MS; report bandwidth per kernel class and
the body time against 42.7 ms. If >= 25%: write (not start) a one-page L3
plan.
- 23:22Z round 2 start; guard: heavy lock held by another lane (cpu).
- 23:25-23:40Z round-2 code (lane copy):
  - `fzc_kernels.cu` v4 SPLIT kernel (K1): one warp per TERM GROUP x 32
    pairs (8 groups with the support indicator: 4 paired U8 helpers in the
    stepped (mu E0) form; single helper + activation merged (shared E0);
    pad; gated; host), phase 1 loads/FOLDS each table entry once into
    shared memory, phase 2 evaluates per group; groups with five linear
    forms step their inner factor as an exact QUADRATIC by forward
    differences (q2_term / q2_steps: fewer live values, fewer products);
    s(1) evaluation is a template parameter (`_r` entry points for the
    recovery rounds). K3 in the same kernel: block partials by warp
    shuffles, the LAST block (threadfence + counter) sums them into
    `sums`; host: ONE async copy into a page-locked 96-byte buffer + ONE
    stream sync (also used by the legacy kernels after k_reduce_f2).
    ptxas -v (sm_89, `logs/fzc_regs.txt` regenerated below): the production
    variant (D 5 + gate, every trained shape) = **80 registers, 0 spills,
    3 blocks x 8 warps = 24 warps/SM** for all four entry points; the D 4
    toy variant (no gate, 7 warps) 80 regs with 4-8 B spills.
    Path to zero spills (each a field identity): 9 groups x 72 regs spilled
    364-436 B -> merged the two light groups (8 warps, 80-reg cap) -> stepped
    (mu E0) form -> templated s(1) -> forward-difference quadratics.
  - `cuda.rs`: HL_GZC_SPLIT (default 1), HL_GZC_LEAN default 1 (lean is now
    the per-pair default), K2 public-table cache `FZC_PUB` (key = blake3 of
    the full shape Debug + slot + table index + n; used only if 128 sampled
    entries also match, else re-uploaded; D2D copy 32 B/entry), K4 host tail
    `HL_GZC_TAIL_LOG=t` (fold on the device, `k_fzc_pack` the 21 prefixes,
    one pinned copy, then `ClosureRounds`' arithmetic on `FzcDesc::eval`
    (now allocation-free)); default 0 until measured.
  - `argument.rs` maps the slot's full-length public table to
    `FzcSrc::Public`; tests: 8 variants in the synthetic test (split,
    split-tail3, split-tail10, split-unfused, lean, lean-unfused, v2, v1),
    split / split-tail10 / lean at every real-slot case, ladder variants
    incl. `split-tN`.
- 23:40Z light `cargo check` (gpu feature) exit 0; CPU check running; b10
  (release test binary) queued.
- 23:46Z the body clock (`t0`) now starts after the optional warm-up probe
  (PB-GZC totals exclude it). 23:50-23:52Z b10 (release tests) exit 0.
- 23:55:56-23:58:30Z `t13-r2-small` exit 0 (154 s, peak VRAM 447 MiB):
  FIRST DEVICE RUN OF THE ROUND-2 CODE, no fix needed. 720 synthetic device
  bodies == CPU body (8 variants x n 1,2,3,4,7,10 x D 4/5 x gate/pad x claim
  none / correct / WRONG); real slot 18 at the 8 small shapes, host words
  and resident rows, split / split-tail10 / lean, claim none/given: 96
  equality lines; descriptors and layout refusals pass.
- 23:59Z queued t14-r2-trained (trained equality, all 4 shapes, + seeded
  gate, HL_GPU_REQUIRED=1), t15-r2-tl128-warm (T128 real slot, profile,
  warm 300 ms: the body against 42.7 ms), t16-r2-ladder (19-21, 8 variants
  incl. host-tail thresholds 4/6/8/10, warm, profile).
