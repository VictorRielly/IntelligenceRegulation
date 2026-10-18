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
- 00:06:32-00:11:49Z `t14-r2-trained` exit 0 (317 s, peak RSS 2.22 GiB,
  **peak VRAM 3,173 MiB**, HL_GPU_REQUIRED=1): 54 "device == CPU" lines
  (rung-TC, TL T32, TL T128, 8B T32; split, split-tail10, lean; dense +
  honest; resident rows, + host words at rung-TC; claim none/given) and the
  SEEDED PROOF-BYTE GATE byte-identical at all four shapes with the round-2
  DEFAULT (split kernel): rung-TC 7,591,336 B (40e8db62...), TL T32
  11,627,208 B (7d9a6f47...), TL T128 23,049,192 B (bf984e0c...), 8B T32
  14,856,216 B (59829d9b...). prove_core wall CPU -> device slot 18: 1.19 ->
  1.11, 2.19 -> 1.88, 5.13 -> 4.56, 3.70 -> 2.72 s.
- 00:11:49-00:12:46Z `t16-r2-ladder` (warm 300 ms, profile; synthetic real
  layout, H2D-built tables so only the kernel phases count) exit 0, peak
  VRAM 885 MiB. KERNELS ONLY (round 0 + fused + folds + copy/sync + tail) at
  2^20: split fused 29.85 ms, split unfused 28.87, split-t4 29.11, -t6
  29.23, -t8 30.35, -t10 30.37, lean 33.53, v2 53.61 ms. At 2^19: split
  16.07, lean 19.15, v2 29.48; at 2^21: split 54.83, lean 59.58, v2 98.69.
  Per round (2^20, split): round 0 10.6 ms, rounds 1-5 16.6 ms, the tail
  floor 70-85 us per tiny round (lean 230-260 us), copy+sync 20-100 us per
  round (lean reduce+D2H 80-180 us). => K1 removed the latency floor (3x)
  and K3 the reduce launch, but the big rounds barely moved (round 0 12.05
  -> 10.6 ms): after the occupancy fix they are INTEGER-THROUGHPUT-bound at
  the P4 clock (~2^19 x ~27k instructions in 10.6 ms = ~1.3e12 instr/s =
  ~54% of 36 SMs x 64 INT32/clk x 1.065 GHz) [COUNTED/MODEL]. Host tail
  (K4): <= 0.7 ms (within noise) from 2^4-2^6, a loss from 2^8 up; the
  default stays 0 (off), the path is gated by the equality tests.
- 00:21-00:26:56Z `t15-r2-tl128-warm` exit 0 (82 s, peak VRAM 1,059 MiB):
  REAL slot 18 at TinyLlama T128, tables from device-resident rows, warm:
  steady split body **34.68 ms** = build 5.64 (support table cached, K2:
  hit) + round 0 9.16 + fused 18.58 + folds 0.07 + copy/sync 1.02 ms
  (round 1: 42.7 ms lean incl. build ~12.9); lean in the same run 37.6-41.7
  ms (build 5.1-5.6, reduce 1.9-3.5). First body per data set 25-35 ms of
  build (fresh resident buffers / first upload of the support table).
- 00:28Z nvidia-smi -q: max clocks SM 3,105 MHz / memory 8,001 MHz, power
  limit 62.4 W, yet under 100% load the card holds P4 (1,065 / 6,000 MHz,
  10-35 W): NOT a power cap. `gpu_sampler2.sh` logs
  clocks_event_reasons.active during the next stacks.
- 00:29Z b11 (CLI) exit 0 -> `bin/...r4.bin` (sha256 3f792ae1...). Queued
  `s6-split` (default config, HL_GPU_REQUIRED=1) + verify and
  `s7-split-warm` (profile, warm 300 ms) + verify, both with sampler2.
- 00:34:20-00:37:13Z `s6-split` (r4 CLI, ROUND-2 DEFAULTS: split kernel,
  tail 0, HL_GPU_REQUIRED=1): exit 0, 173 s, peak RSS 1.66 GiB, **guard peak
  VRAM 3,137 MiB**; 22 device sumchecks, 0 declines; fresh verify (r3 CPU
  binary, identity 53a5667d...) exit 0 (21 s). Cold in-stack (DVFS-bound):
  slot-18 phase 9.43 s; per-block body median 183 ms = lean's 182-186 ms
  (s1/s4): the cold slot is set by the clock ramp, not the kernel; block 0
  3.64 s (the split module's one-time NVRTC compile ~3.5 s vs ~2.5 s).
  Telemetry (`stack-s6-split/gpu_samples.csv`): clocks_event_reasons.active
  = **0x20 = SW THERMAL SLOWDOWN** in 30 of 43 samples at >= 50%
  utilisation (all P4, SM 1,065-1,080 MHz; max 65 C, 37 W): a software
  thermal policy holds the card at ~1/3 of its 3,105 MHz maximum.
- 00:37:34-00:40:39Z `s7-split-warm` (r4, profile, per-round, warm 300 ms):
  exit 0, 185 s, **guard peak VRAM 3,137 MiB**; fresh verify exit 0.
  In-stack WARM split body: steady median **36.4 ms** (35.4 ms over the 15
  blocks whose warm-up finished ramping; min 34.5) = build 5.60 (K2 hits
  21/22) + round 0 9.62 + fused 18.51 + folds 0.04 + copy/sync 1.15 +
  finals 0.08 ms (round 1, s5 lean warm: 42 = 8.6 / 12.1 / 18.8 / 2.7).
- RESULT (plan figure 72 B x 2^20 x 17 = 1.2835 GB): body 42.7 -> 34.7 ms
  isolated (37.0 GB/s = **14.4% of 256 GB/s**), 35.4-36.4 ms in-stack warm
  (13.8-14.2%); counted device bytes 1,880 B/entry = 1.97 GB -> 54-57 GB/s
  (21-22%). Per kernel class (in-stack warm, counted): build 562 MB / 5.6 ms
  = 100 GB/s; round 0 352 MB / 9.6 ms = 37 GB/s; fused rounds ~1,057 MB /
  18.5 ms = 57 GB/s; copy/sync 20 x ~57 us. Still the 10-25% band: no L3
  plan written (brief: only at >= 25%).
- 00:42Z ROUND 2 DONE; all lane jobs finished (no wrapper, sampler or
  guard of this lane running). Patch regenerated (12 files), source hashes
  refreshed, binaries in `bin/binaries.sha256` (r4 = round-2 CLI). Register
  report: `logs/fzc_regs_round2.txt`. Next step proposed in the hand-back:
  (1) lift the laptop's SW thermal clock cap (power/thermal profile; Victor)
  and re-measure, (2) arithmetic cuts on the compute-bound rounds (derived
  tables for the pad and gated linear combinations, cubic forward
  differences in the helper groups, base-field round 0), (3) cache the
  slot-18 NVRTC module across processes (3.6 s per process).

### Round 3: exact arithmetic cuts + cross-process module cache (brief ~00:45Z)

Brief: slot 18 only, same gates and rules. (2) derived tables for the pad
sum and the gated linear form; cubic forward differences in the 4 helper
groups; a base-field specialisation of round 0 — each proved equal by the
t13/t14 gates; (3) cache the compiled slot-18 module across processes
(keyed by source hash + device + driver; refuse a stale cache). Record the
clock-limit reason with every measurement. Report body time, % of 256
GB/s and the clock state; L3 plan (written, not started) only if >= 25%
isolated. Victor is asked to lift the laptop's SW thermal cap meanwhile.
- 00:46-00:49Z round-3 code (lane copy):
  - DERIVED TABLES (split kernel): T_GL = mu0 f0l + mu1 f1 + mu2 f2 (the
    gated clauses' affine part) and T_PL = mu_pad sum_j w_j A_j (the pad sum),
    appended after the slot's own 21 (20) tables, built once by
    `k_fzc_derive` (42 regs) and folded with the others (a fold is linear;
    an affine constant is a fixed point); the pad and gated groups read them
    instead of 11 / 9 tables (saves ~30 products per pair, adds 2 folded
    tables).
  - CUBIC helpers: inner = H d1 d2 - d1 - d2 evaluated at d = 0..3 (8
    products) and stepped by forward differences; one (mu E0) x inner
    product per point (13-14 products per helper instead of 15-18).
  - BASE round 0 (`k_fzc_round_b` / `_rb`): when every A plane and S hold
    base-field values (committed planes by construction; host / public
    tables checked once, the public cache stores the flag), products with
    their linear forms use base multiplications (gated A16 U16, host HG and
    U16, pad (1 - S), A(d) = E0 S, beta A16). Only before the first fold.
  - MODULE CACHE: PTX on disk under blake3(source + arch + device + cc +
    driver + NVRTC version), header = magic + key + blake3(PTX); a stale key,
    corrupt body or foreign file is REFUSED and recompiled; atomic write.
    `HL_GZC_CACHE_DIR` (`0` = off; default $HOME/.cache/hashline-gzc); this
    lane's scripts pin it to `results/.../gzc_module_cache`. The CLI summary
    reports module-load seconds, cache hits and refusals.
  - ptxas -v (sm_89, production D 5 + gate): `k_fzc_round_b`, `_rb`,
    `k_fzc_round_r`, `k_fzc_fold_round_r` 80 regs, **0 spills**; the
    debug-only `k_fzc_fold_round` (s(1) in fused rounds) 8 B and the generic
    `k_fzc_round` 4 B; smem 25.0 KB/block (3 blocks/SM fit); 24 warps/SM.
  - tests: synthetic edges add base-valued A planes + 0/1 indicator for the
    split variants; host-only `gzc_module_cache_refuses_stale_and_corrupt_
    entries`; `measure.sh` = one guarded test job + the clock sampler
    (clocks.sm, clocks.mem, clocks_throttle_reasons.active).
- 00:49Z light checks (gpu, cpu) exit 0; t17-r3-small queued.
- 00:52:12-00:56:40Z `t17-r3-small` exit 0 (268 s incl. the test build,
  peak VRAM 447 MiB): **1,080 synthetic device bodies == CPU body** (720
  generic + 360 with base-valued A planes and a 0/1 indicator on the split
  variants, which run the base-field round 0), incl. the wrong-claim R1d
  cases; 96 small-shape equalities (real slots take the BASE path); the
  module-cache refusal test passes (valid entry loads; stale key, corrupt
  body, foreign file refused). Cache populated (`gzc_module_cache/`, one
  keyed PTX file per module).
- 01:02:00-01:02:28Z `t20-r3-ladder` exit 0 (peak VRAM 899 MiB; clock:
  busy samples 32/34 reason 0x20 SW thermal, SM 1,065-1,125 MHz). KERNELS
  ONLY at 2^20: split (round 3, base round 0) **23.02 ms** = round 0 7.09 +
  fused 14.04 + copy 1.76 (round 2: 29.85 = 10.58 / 18.24 / 0.92); split-t5
  22.56; lean 33.57. 2^19: 12.56 (r2 16.07); 2^21: 40.84 (r2 54.83).
- 01:09:25-01:11:23Z `t19-r3-tl128-warm` exit 0 (peak VRAM 1,091 MiB; clock:
  19/22 busy samples 0x20, P4, SM 1,080-1,155 MHz, mem 6,000 MHz; modules
  **loaded from the disk cache in 0.01-0.02 s**): REAL slot 18, T128, warm,
  steady split bodies **28.25 / 29.83 ms** = build 6.0-6.8 + round 0
  6.3-6.8 + fused 13.8-14.0 + copy 1.6-1.7 ms (round 2: 34.7; round 1:
  42.7); lean in the same run 37.3-41.2 ms.
- 01:11:23-01:19:14Z `t18-r3-trained` exit 0 (471 s, peak VRAM 3,173 MiB,
  HL_GPU_REQUIRED=1): 54 equalities at all four shapes and the SEEDED
  PROOF-BYTE GATE byte-identical at all four shapes with the ROUND-3 DEFAULT
  (rung-TC 65c84869..., TL T32 bb8014ce..., TL T128 31b06489..., 8B T32
  d794f590...; lengths unchanged).
- 01:22:24Z b13 (CLI) exit 0 -> `bin/...r5.bin` (sha256 defa81e7...).
  Queued `s10-r3` (defaults) + verify and `s11-r3-warm` (profile, warm) +
  verify, both with sampler2.
- 01:41:30-01:44:08Z `s11-r3-warm` (r5 CLI, round-3 defaults + profile +
  warm 300 ms, HL_GPU_REQUIRED=1): exit 0, 217 s, **guard peak VRAM 3,137
  MiB**; 22 device sumchecks, 0 declines; **module loaded from the disk
  cache in 0.03 s (hits 1, refused 0)**; fresh verify exit 0, identity
  53a5667d... In-stack warm body: steady median 31.1 ms; **29.0 ms** over
  the 13 blocks whose warm-up finished ramping (min 26.9) = build 7.0 +
  round 0 7.1 + fused 13.9 + copy 1.2 ms. Clock: busy samples 38/52 reason
  0x20 (SW thermal), P4 1,080 MHz, plus P5 samples down to 270 MHz.
- 01:22-02:15Z s10 waited 3,155 s (other lanes' suites, then admission:
  two light jobs held 9.5 of 11.9 GiB).
- 02:15:17-02:18:12Z `s10-r3` (r5 CLI, ROUND-3 DEFAULTS, no profile,
  HL_GPU_REQUIRED=1): exit 0, 174 s, peak RSS 1.61 GiB, **guard peak VRAM
  3,137 MiB**; 22 device sumchecks, 0 declines; module from the disk cache
  in 0.02 s; fresh verify (r3 CPU binary) exit 0, identity 53a5667d...
  COLD in-stack: slot-18 phase **5.49 s** (r2 s6 9.43 s; CPU-body GPU arm
  s0 17.54 s); body steady median 159 ms (r2 183), block 0 0.205 s (r2 3.64
  s: the compile is gone); extension rounds (host) 1.94 s; sum of block
  walls 131.37 s (s0 134.42; shared box: a 6 GiB light job of another lane
  ran alongside). Clock: 31/47 busy samples 0x20, P4/P5.
- RESULT ROUND 3 (plan figure 1.2835 GB per body, card at P4 ~1.1 GHz under
  the SW thermal cap 0x20 in every measurement): body 42.7 (r1) -> 34.7
  (r2) -> **28.25-29.83 ms isolated** (t19) = 43.0-45.4 GB/s = **16.8-17.7%
  of 256 GB/s**; in-stack warm 29.0 ms (17.3%); kernels only 23.0 ms (21.8%
  if the build were free). Code's own counted bytes 2,216 B/entry (2.32 GB:
  derived tables add folds) -> 78-82 GB/s. Below 25%: no L3 plan written.
- 02:25Z ROUND 3 DONE; all lane jobs finished.

### Round 4 (last round before the pause; brief ~02:30Z)

Brief: (1) build directly from the resident rows (no A widenings, no helper
interleavings; derived tables inside round 0); (2) flag polling on mapped
pinned memory instead of cuStreamSynchronize; (3) the host tail from 2^5 as
the default, after a seeded-gate run. Same gates and clock recording. Then
a short NEXT.md for the 5090 (first runs, clock settings to record/pin, the
L3 port outline on the split template) and STOP: the lane pauses until the
laptop's clock cap is lifted or the 5090 is reachable.
- 02:26-02:32Z round-4 code (lane copy):
  - RAW SOURCES (1): per-table source descriptors (mode 0 = the Fp2 table
    in `tabs`, 1 = a base plane's resident words, 2 = a helper pair's re /
    im words); with `raw` round 0 and the fused round 1 read the A planes and
    helper pairs straight from the device-resident commitment rows (no 11
    widenings, no 6 interleavings: -456 B/entry of build traffic, A reads 8 B
    instead of 16), and round 0 computes T_GL / T_PL in place (phase 1b,
    written at full length for round 1; no `k_fzc_derive` pass). Round 1's
    fold writes the folded halves into `tabs`, which every later round reads.
    Enabled iff split + fused + `HL_GZC_RAW` (default 1) + n >= 3 + n-1 above
    the host-tail threshold + every A plane / helper pair device-resident;
    else the materialised build. Derived tables never read a descriptor.
  - MAPPED FLAG (2): `cuMemHostAlloc(DEVICEMAP)` buffer per evaluator; the
    last block writes the 2 (D+1) words, `__threadfence_system`, then the
    sequence flag; the host polls it (no driver call per round). 5 s timeout
    -> stream sync (surfaces any kernel error), the copy path, and the mapped
    path off for the process. `HL_GZC_MAPPED` (default 1).
  - TAIL DEFAULT (3): `FZC_TAIL_DEFAULT = 5`.
  - ptxas -v (production D 5 + gate): all four round entry points and
    `k_fzc_fold_round_r` 80 regs, 0 spills, smem 25.5 KB/block; the
    debug-only fused s(1) kernel 8 B.
  - tests: `split` = the production default (tail 5, raw, mapped);
    `split-mat`, `split-nomap` variants; trained real-slot cases run split /
    split-mat / split-tail10 / lean.
- 02:32Z light checks exit 0; queued t21-r4-small and t22-r4-trained (seeded
  gate under the round-4 defaults incl. tail 5).
- 03:17Z the session was stopped by a usage limit with t22-t24 and b14
  queued; the box finished them (coordinator, resumed 04:21Z). All exit 0.
- 02:35:44-02:39:52Z `t21-r4-small` exit 0 (248 s, peak VRAM 449 MiB):
  **1,440 synthetic device bodies == CPU body** (10 variants incl. the
  round-4 default split = raw + mapped + tail 5, split-mat, split-nomap;
  base-valued and generic data; claim none / correct / WRONG); 128
  small-shape equalities (split, split-mat, split-tail10, lean); module
  cache refusal test passes.
- 02:57:20-03:03:16Z `t22-r4-trained` exit 0 (355 s, peak RSS 2.25 GiB,
  **peak VRAM 3,175 MiB**, HL_GPU_REQUIRED=1): 72 equalities at rung-TC,
  TL T32, TL T128, 8B T32 (split, split-mat, split-tail10, lean; dense +
  honest; resident rows, host words at rung-TC) and the SEEDED PROOF-BYTE
  GATE byte-identical at all four shapes under the ROUND-4 DEFAULTS
  (tail 5, raw, mapped): rung-TC 7,591,336 B (16045127...), TL T32
  11,627,208 B (df35571c...), TL T128 23,049,192 B (8a898f43...), 8B T32
  14,856,216 B (106495b1...).
- 03:13:56-03:14:19Z `t24-r4-ladder` exit 0 (peak VRAM 899 MiB; clock:
  38/38 busy samples 0x20 SW thermal, SM 1,065 MHz). KERNELS ONLY at 2^20:
  split (tail 5, mapped) **20.66 ms** = round 0 6.77 + fused 13.67 + copy
  0.01 + tail 0.18 (round 3: 23.02; round 2: 29.85; lean 33.5); split-nomap
  21.06 (copy 0.59: the mapped flag saves ~0.5 ms here, ~1.6 ms with real
  tables); tail 0 20.89. 2^19: 11.26; 2^21: 39.22 ms. Per round, mapped:
  the host sees the words 0-2 us after the kernel (was 20-90 us).
- 03:14:20-03:15:40Z `t23-r4-tl128-warm` exit 0 (peak VRAM 1,059 MiB;
  modules from the disk cache in 0.01 s; clock: 26/27 busy samples 0x20,
  P4, SM 1,065 MHz, mem 6,000 MHz). REAL slot 18, T128, warm, steady:
  split (DEFAULT: raw + mapped + tail 5) **26.47-27.92 ms** = build
  3.25-3.88 + round 0 9.17-9.48 + fused 13.62-14.31 + copy 0.01 + tail
  0.18-0.23; split-mat (materialised build + mapped + tail 5)
  **25.86-27.09 ms** = build 5.28-6.35 + round 0 6.47-6.85 + fused
  13.53-13.80 + copy 0.01 + tail 0.16-0.21; lean 38.4-39.2.
  LEVER VERDICTS: (1) raw build saves ~2.0 ms of build but costs ~2.7 ms in
  round 0 (phase 1b: the in-place derivation runs on 2 of the 8 warps and
  writes the two derived tables at full length) -> a wash / -0.7 ms on this
  card: `HL_GZC_RAW=0` (split-mat) is the measured choice on the 4070, the
  default stays as the seeded gate ran it (raw); re-measure on the 5090.
  (2) mapped flag: copy/sync 1.6-1.7 -> 0.01 ms: works. (3) tail 5: -0.2 to
  -0.7 ms vs tail 0: kept as the default.
- RESULT ROUND 4 (plan figure 1.2835 GB per body; card at P4 1,065 MHz under
  the SW thermal cap 0x20 in every measurement): body 42.7 (r1) -> 34.7
  (r2) -> 28.3 (r3) -> **25.9-27.1 ms (split-mat) / 26.5-27.9 (default)**
  isolated warm = 46-49.6 GB/s = **18.5-19.4% of 256 GB/s**; kernels only
  20.66 ms (24.0% if the build were free). Below 25%: no L3 plan started;
  the outline goes into NEXT.md as briefed.
- GAP: no 22-block stack ran with the round-4 CLI (b14 -> `bin/...r6.bin`,
  built 03:04Z; the session stopped before a stack was queued, and the
  coordinator's resume instruction is to record, write NEXT.md and pause).
  The round-4 defaults are gated by t21/t22 (incl. the seeded proof-byte
  gate) but NOT by a stack + fresh verify; that is the first run on resume
  (`stack_r2.sh` with BIN=r6 + `verify.sh`). The last stack-verified CLI
  is r5 (round 3, s10/s11).
- 04:26Z round-4 artifacts: `bin/zk60_trained_block.gpu.release.r6.bin`
  (sha256 a22b8061...; `bin/binaries.sha256`), patch regenerated (12 files),
  `lane_sources_after.sha256`, `logs/fzc_regs_round4.txt` (production
  entry points 80 regs, 0 spills, 25.5 KB smem, 24 warps/SM). `arch_str`
  already emits compute_120 for the 5090. `NEXT.md` written (first runs on
  the 5090, clock settings to record/pin, the L3 outline on the split
  template, open items).
- 04:27Z LANE PAUSED (coordinator): no job of this lane running or queued.
