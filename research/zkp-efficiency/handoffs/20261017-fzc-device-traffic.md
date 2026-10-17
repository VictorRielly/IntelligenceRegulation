# Review handoff: F-device traffic definitions and fused-count correction

Cycle 0065, run `20261017T182105Z-44205280`. Measurement-only handoff; no
production patch, integration, native proof or GPU benchmark has run here.

The actual seam is the active owner copy's
`hashline/src/gpu/cuda.rs::DevFzcRounds::{new,try_round,try_fold}` and
`FzcStats::{device_bytes,line}`, plus `gpu/fzc_kernels.cu`'s direct/lean
round/fold functions. Do not duplicate the owner's port. The self-contained
patch location is `experiments/fzc-device-traffic-20261017/`: `run.py`
instruments the captured source, `shim.cpp` supplies CPU-only substitutes,
`reference.py` supplies an independent semantic oracle, and `audit.py`
independently counts the shrinking schedule and checks native Eq builders.
`native-pins.json` binds the exact copy. `measurement-note.patch` is an
unapplied correction to the captured design note only.

Interface for a counter/analysis adapter: public `(n, support, lean, fused,
nonzero_pad_weight_count)` -> source table bytes, alongside existing
`FzcStats` useful/logical bytes and hardware counters. Let N = 2^n,
K = 20 + support, M = 32 + support + (support ? W : 0).

| schedule | source table bytes |
|---|---:|
| direct separate | 80 K (N - 1) |
| direct fused | 64 K N - 48 K |
| lean, separate or fused | (32 M + 48 K) (N - 1) |

1. **Direct counter is consistent, design note is not.** The Rust increments
   16 K L for round 0, 24 K L for each deferred fold+round, and 48 K for the
   final fold. Thus direct fusion approaches 64 K N, not 40 K N. At K = 21,
   total including the stated 504 N construction counter approaches 1,848 N,
   not 1,344 N. Byte reduction is about 20% table-only / 15.38% with that
   construction counter. These are byte ratios, not time bounds.
2. **Lean counter has a different meaning.** The lean function stages M
   pair loads rather than loading each of K tables once. Its fused function
   explicitly stores folds and rereads the folded entries. The shared
   FzcStats formula remains a useful algorithmic normalization but is not
   the source-access count for this variant. Compiler reuse, caches, spills
   and register benefits need real-device evidence; no DRAM regression or
   runtime ranking is asserted.
3. **Construction counter counts Eq outputs.** It omits Eq input/temporary
   reads, as well as some parameter/point transfers. Keep that convention
   explicit. Also separate round partials/reduction, shared memory, finals
   and all transfers. The current code has 16-byte Fp2 tables even in round
   0; the plan's compact/base-field first round is a future variant.

Validation: 96 synthetic fixtures / 384 variant schedules; 6,288 independent
Fp2 round-value comparisons, 576 recovered s(1) values, 7,968 terminals,
4,128 phase-counter assertions; ten mutation controls. Independent audit:
148 schedule/source/pin assertions, 7,687 Eq outputs and three controls.
One CPU thread, each experiment under one second, under 35 MiB compiler RSS.
The CPU arithmetic substitutes do not validate GPU integer instructions or
parallel synchronization. No native/shape/mask/privacy acceptance follows.

Owner next: preserve all existing byte, refusal, shadow-transcript, RNG,
PCS/M, fail-closed and fresh-verifier gates. Retain the design-note correction
and label each numerator by scope before interpreting the speed-plan metric.
Under the owner's shared locks, compare direct and lean, fused and separate,
with actual slot/enclosing proof times and device, L2, instruction, occupancy
and spill evidence. Keep profiler replay/cache settings identical and report
unprofiled enclosing times separately. A source-only count cannot decide a
DRAM bottleneck or close the >=50 proved-token/s target.

Research next rotates to lookup/softmax and composition: audit when a
host-only helper build feeds the supposedly resident device path, and what
can be removed without dropping its commitment/masking obligations. Earlier
LogUp-GKR privacy and borrowed-catalog negative results remain prerequisites.
