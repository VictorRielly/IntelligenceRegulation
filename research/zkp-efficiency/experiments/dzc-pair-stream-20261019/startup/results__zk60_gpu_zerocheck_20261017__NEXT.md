# GPU zero-check lane: what to do next (written at the pause, 2026-10-18 04:26 UTC)

The lane pauses until the laptop's software thermal clock cap is lifted or
the RTX 5090 Linux box is reachable. Everything below assumes the lane copy
`ops/zkp-mvp/gpu-zerocheck/` (patch against review-r3:
`gzc-vs-review-r3.patch`), the scripts in this directory and the ledger
`PROGRESS.md`. Labels: [MEASURED] (shared laptop, n = 1), [COUNTED],
[MODEL].

## 0. Where slot 18 stands

| round | change | body, 2^20, warm, real tables (T128) | plan figure 72 B x 2^20 x 17 / body |
|---|---|---|---|
| 1 | lean per-pair kernel | 42.7 ms | 30 GB/s = 11.7% of 256 |
| 2 | term-group split (K1), fused reduction + pinned result (K3), resident support table (K2) | 34.7 ms | 37 GB/s = 14.4% |
| 3 | derived tables, cubic helpers, base-field round 0, disk module cache | 28.3 ms | 45 GB/s = 17.7% |
| 4 | mapped-flag polling, host tail from 2^5, raw resident-row reads (a wash on this card) | **25.9 ms** (`HL_GZC_RAW=0`), 26.5 ms (default) | **49.6 GB/s = 19.4%** |

All [MEASURED] on the RTX 4070 Laptop held at **P4, SM 1,065 MHz, memory
6,000 MHz, `clocks_throttle_reasons.active = 0x20` (SW thermal slowdown)**
in every busy sample of every measurement (maximum clocks 3,105 / 8,001
MHz). Kernels alone: 20.66 ms at 2^20, 11.3 ms at 2^19, 39.2 ms at 2^21.
The large rounds (round 0 and the fused rounds, ~20.5 of the 26 ms) are
integer-arithmetic-bound at that clock [COUNTED/MODEL].

Gates that hold for the round-4 code: 1,440 synthetic device bodies (incl.
wrong-claim R1d recovery), 128 small-shape and 72 trained-shape equalities
(rung-TC, TinyLlama T32/T128, 8B T32), the seeded proof-byte gate
byte-identical at all four shapes under the round-4 defaults, every GPU job
<= 3,175 MiB VRAM. **Gap:** no 22-block stack ran with the round-4 CLI
(`bin/zk60_trained_block.gpu.release.r6.bin`); the last stack-verified CLI
is r5 (round 3). Run that stack first on resume (section 1, step 0).

## 1. What to run first on the 5090 (in this order, one guarded job each)

Adaptations for plain Linux: `nvidia-smi` is on `$PATH` (the scripts use
`/usr/lib/wsl/lib/nvidia-smi`: change `S=` in `gpu_sampler.sh` /
`gpu_sampler2.sh`); set `CUDA_ROOT` / `LD_LIBRARY_PATH` to the box's CUDA
(`build.sh`, `gtest.sh`, `stack*.sh`); keep the resource guard
(`docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md`); the 4 GiB VRAM rule was
the laptop's WSL-freeze rule and does not apply, but record `peak_vram_mib`
anyway. `arch_str` already emits `compute_120` for sm_120; the module cache
keys itself by device, driver and NVRTC version, so nothing stale is loaded.

0. **Close the round-4 gap (laptop or 5090):** `BIN=bin/...r6.bin stack_r2.sh
   s12-r4 1` then `verify.sh s12-r4` (expects identity `53a5667d...` with the
   frozen review-r3 CPU binary); then `gpu_sampler2.sh` beside it.
1. **Build and the correctness gates once on the new device:**
   `build.sh b-5090-testbin testbin-release`; then `measure.sh t-5090-small
   release 4 8 2400 gzc_device_synthetic -- --include-ignored
   gzc_device_real_slot18_equals_the_cpu_body_at_every_small_shape
   gzc_descriptor gzc_layout_check gzc_module_cache`; then `measure.sh
   t-5090-trained release 6 10 2400 gzc_device_seeded_receipts_are_byte_identical
   HL_GPU_REQUIRED=1 -- --ignored
   gzc_device_real_slot18_equals_the_cpu_body_at_the_trained_shapes`.
2. **The ladder (the t24 equivalent):** `measure.sh t-5090-ladder release 6 10
   1500 gzc_device_bench_cube_ladder GZC_BENCH_PROFILE=1 GZC_BENCH_ROUNDS=1
   GZC_BENCH_LOGS=19,20,21,22 GZC_BENCH_VARIANTS=split,split-mat,split-nomap,split-t0,lean
   GZC_BENCH_REPS=3 HL_GZC_WARM_MS=300 -- --ignored`. Read the `PB-GZC` lines
   (per-phase ms and counted GB/s) and the `PB-GZC-ROUND` lines; compare
   `split` with `split-mat` to settle `HL_GZC_RAW` on this card.
3. **The real slot (the t23 equivalent):** `measure.sh t-5090-tl128 release 6
   10 1500 gzc_device_real_slot18_equals_the_cpu_body_at_the_trained_shapes
   GZC_SHAPES=tl128 HL_GZC_PROFILE=1 HL_GZC_ROUNDS=1 HL_GZC_WARM_MS=300 --
   --ignored`; the steady `PB-GZC slot 18` totals are the body time. Report
   body ms, the plan figure in GB/s and % of **1,792 GB/s** (the 5090's
   figure), and the clock state from the sampler CSV.
4. **One stack each way:** `build.sh b-5090-cli example`, copy the binary to
   `bin/`, `stack_r2.sh s-5090-warm 1 HL_GZC_PROFILE=1 HL_GZC_ROUNDS=1
   HL_GZC_WARM_MS=300` and `stack_r2.sh s-5090 1`, each followed by
   `verify.sh`; compare against a `stack_r2.sh s-5090-base 0` (slot 18 on
   the CPU, GPU arm) in the same session with `gzc_table.py`.

Expected on the 5090 [MODEL, to be replaced by step 3]: 4.7x the SMs and
~2.2x the clock of the capped laptop give ~10x on the compute-bound rounds
and 7x bandwidth: a body of roughly 2.5-3.5 ms at 2^20, i.e. 370-510 GB/s
= 20-29% of 1,792 GB/s on the plan's figure. The ≥ 25% rule then decides
L3 on measured data.

## 2. Clock settings to record (and pin where allowed)

Record with every measurement (the sampler does it): `nvidia-smi
--query-gpu=pstate,clocks.sm,clocks.mem,clocks_throttle_reasons.active,power.draw,temperature.gpu
--format=csv`; and once per session `nvidia-smi -q -d CLOCK,PERFORMANCE,POWER`
(maximum clocks, power limit, the active and supported clock event reasons).
Reason bits seen on the laptop: 0x1 idle, 0x20 SW thermal slowdown.

Pinning (root; Victor's call, bounded by the amended 600 W contract limit):
`nvidia-smi -pm 1` (persistence mode: no context teardown between jobs);
`nvidia-smi -lgc <min>,<max>` locks the graphics clock on GeForce with recent
drivers (`-rgc` resets); `nvidia-smi -lmc` likewise for memory; application
clocks (`-ac`) are usually unsupported on GeForce. A locked clock removes the
DVFS ramp that made every cold in-stack slot-18 body 5x slower on the laptop
(`HL_GZC_WARM_MS` was the diagnosis aid, not a fix). Whatever is pinned goes
into the ledger line of the measurement, with the throttle-reason bitmask.

## 3. L3 port outline on the split template (slots 14-17 + the extension rounds)

CPU cost at TinyLlama T128, 22 blocks (`N/r4/PHASES_T128.md`): masked
sumchecks slot 14 21.1 s, 17 8.8 s, 15 5.9 s, 16 2.8 s (slot 18 was 14.6 s);
extension rounds 14 5.9 s, 17 2.1 s, 18 1.9 s, 15 1.7 s, 16 1.4 s. Together
53 s of sumchecks and 13 s of extension rounds out of 152 s of block walls.

The template, per slot, in the order that paid on slot 18:
1. a public descriptor of the slot's polynomial (`FzcDesc`-like: the
   challenge scalars, lookup constants, table indices), `check_layout`
   (refuse anything but the canonical table order: a decline, never a wrong
   polynomial), and a host mirror `eval` compared against the slot's own
   closure at random points;
2. the split kernel: one warp per term group x 32 pairs, phase 1 stages
   (or folds) every table entry once into shared memory, phase 2 evaluates
   per group with stepped linear forms, forward-difference quadratics /
   cubics, Karatsuba Fp2 products; `_r` entry points for the recovery
   rounds; target 80 registers, 0 spills, >= 24 warps/SM (`fzc_regs.py`);
3. derived tables for affine combinations the polynomial reuses, the
   base-field round 0 when the A planes are base-valued, the fused
   last-block reduction with the mapped-flag result, the host tail from 2^5,
   the per-process public-table cache and the disk module cache (all exist
   and are slot-independent);
4. gates, unchanged: descriptor == closure, synthetic edges incl. the
   wrong-claim R1d case, trained equality at the four shapes, the seeded
   proof-byte gate, a stack + fresh verify, 0 declines, VRAM recorded.

Slot notes: slot 17 (softmax) runs `GroupedEqRounds` on the CPU; the device
evaluator returns the same unmasked sums from the plain closure form (field
sums are exact), so the grouped-Eq bracket is not needed on the device.
Slot 14 (D zero-check, hosts 12 and 13D) is the largest and goes first.
Slots 15 (Q) and 16 (KV) share the attention tables; port them together.

The extension rounds are the largest HOST item left in slot 18 (86 ms per
block, 3x the device body): `mask_eval` is, per private table, an inner
product of a committed row slice with an eq table at the claim point, so
one batched kernel over the resident rows (one block per table, a dot
product of 2^log_cols words with the device-built eq table) replaces it;
`zk::extension` itself stays on the host (degree-D interpolation). Expected
per block [MODEL]: 86 ms -> ~1 ms on the laptop.

Expected gains [MODEL], laptop at the capped clock, from slot 18's measured
25x (14.6 s -> 0.57 s over 22 blocks): slots 14-17 38.7 s -> ~1.6 s; the
five extension rounds 12.9 s -> ~0.3 s. Block walls 152 s -> ~90 s at T128
(commit 64 s, witness 13 s, inverses 8 s, openings 9 s remain: L4/L5). On
the 5090 all of it scales by the ratio step 3 measures.

Cost [MODEL, calibrated on this lane]: slot 18 took four rounds (one
lane-day); with the template in place, one round per slot for 14-17 and
one for the extension rounds: 5 lane-days to an L3-complete 22-block
TinyLlama T128 stack on the laptop GPU.

## 4. Open items

- `HL_GZC_RAW`: a wash on the 4070 (build -2 ms, round 0 +2.7 ms); settle
  on the 5090 (step 2) and set the default accordingly, then re-run the
  seeded gate.
- Round 0's phase 1b (in-place derivation) runs on 2 of 8 warps; if raw
  stays, spread it over all warps.
- The cross-block reduction's `__threadfence_system` + mapped write costs
  nothing measurable; keep.
- If the laptop's cap is lifted instead: re-run t23/t24 with `measure.sh`;
  the throttle reason must leave 0x20 before the numbers are comparable.
