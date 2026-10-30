# Cycle0167 — exact warp sums, zero direct current slot incidence

Run `20261030T154123Z-20600a3e`, 2026-10-30 UTC. **No measured proving
improvement.** The local model establishes an exact arithmetic prerequisite
for a possible GPU evaluator. The inspected current trained/R14 slot factories
select host `GroupedEqRounds` or `ClosureRounds`; optimizing the legacy CUDA
reducer removes no work from those slot evaluators today. Source evidence is
narrower than a whole-program callgraph or a security review.

The newly assessed older technique is CUDA 11/Ampere integer warp reduction,
documented in [May 2020](https://developer.nvidia.com/blog/cuda-11-features-revealed/)
and the archived [July 2, 2020 guide](https://docs.nvidia.com/cuda/archive/11.0_GA/ampere-tuning-guide/index.html).
Current [PTX semantics](https://docs.nvidia.com/cuda/parallel-thread-execution/#parallel-synchronization-and-communication-instructions-redux-sync)
truncate integer redux sums to 32 bits and require sm80+. This is not a
Goldilocks field reduction. The [CUB documentation](https://nvidia.github.io/cccl/unstable/cub/api/classcub_1_1WarpReduce.html)
also describes three redux instructions for a 64-bit integer sum; a wrapping
u64 sum still loses the carries needed for field arithmetic.

For each canonical Goldilocks word x, split x into binary digits of widths
27, 27 and 10. In a 32-lane warp, each independent digit sum fits u32:
32(2^27−1)=4,294,967,264 and 32(2^10−1)=32,736. Reconstruct the exact at-most
69-bit whole sum as lo/hi, including its last addition carry, and apply the
pinned native canonical reducer. Apply this separately to both Fp2 limbs.
The candidate does not change the field, polynomial, per-thread accumulation,
evaluation order, challenge, mask, fold or opening schedule.

`candidate.py` models u32/u64 wrapping explicitly. `reference.py` instead
uses unbounded integer sums and direct-node product-polynomial evaluation.
Both were authored locally; this is algorithmic independence, not an external
review. `warp_sum.cuh` is a locally authored **uncompiled** integration sketch.
Its collective assembly is volatile so unused nonleader results cannot justify
removing their collective calls. Physical convergence, compiler behavior,
memory ordering, races and device arithmetic have not been tested.

The model passes **53,030 checks**, covering 10,530 warp cases, 96 block
cases, 36 full-Fp2 product-polynomial round cases and 29 negative controls.
The separate saved-evidence audit passes **243 checks**, importing neither
candidate nor experiment. Four saved warp fixtures, three block fixtures and
two polynomial fixtures reproduce against the independent reference.

Dimensions: 32 physical lanes; full, prefix, alternating and random nonempty
masks in the arithmetic model; CTA sizes 32/64/128/256/512/1024; 1/3/5/6
evaluation values; polynomial degrees 2/3/4/5 and half-row counts
1/17/31/32/33/127/128/257/1025. These are synthetic dimensions, not admitted
model layouts or contexts. The CUDA sketch uses a full converged physical
warp with zero padding; arbitrary modeled masks do not establish device
divergence/convergence safety.

Controls detect u64 wrap, u32 truncation, overflowing 28-bit digit sums,
missing middle/high/carry contributions, inconsistent membership, missing
lanes, wrong modulus, swapped Fp2 limbs, duplicate warps, foreign evaluation
values, reversed evaluation order and malformed input shapes/operands.
Raw noncanonical u64 reducer fixtures are separately labeled and refused by
the canonical model API. They do not admit invalid proof inputs.

Conditional **tail-only** source counts for a two-level warp reduction:

| CTA / evaluation values | Shared scratch B, tree → candidate | CTA barriers, tree → candidate | Tree scalar modular adds | Candidate leader canonical reductions / warp redux instructions |
|---|---:|---:|---:|---:|
| 128 / 5 | 10,240 → 320 | 8 → 1 | 1,270 | 50 / 150 |
| 256 / 5 | 20,480 → 640 | 9 → 1 | 2,550 | 90 / 270 |
| 1024 / 1 | 16,384 → 512 | 11 → 1 | 2,046 | 66 / 198 |

These operation kinds have different costs. Counts do not measure executed
instructions, occupancy, allocated peak, DRAM traffic, VRAM or elapsed speed.
`k_reduce_f2` reuses scratch in a loop and needs a further CTA barrier per
value on **both** paths: its 1024-thread counts are 12 → 2, unlike tail-only
`scg_emit`. Other parameter-loading barriers are excluded. No global bytes,
polynomial products, fresh masks or launches are removed. Added work includes
digit extraction, collective operations, reconstruction, dispatch/fallback
and possible register-pressure costs.

The active trained source and separate R14 final working tree are pinned.
Six literal source facts support the incidence screen. Four R14 public
geometry/definition pins match cycle0154; split_protocol changed. This does
not rerun the census, prove current freeze/review status, or turn the 3B
Shieldstral layout into an 8B profile. Owner R14 measurements remain a matched
two-block synthetic CPU diagnostic, not a complete trained high-end GPU run.

The [zkDuel paper](https://arxiv.org/abs/2610.37710), October26, is a **refresh**,
not a new discovery. Its reduction/launch observations motivate this screen;
its standalone base-field kernels do not validate native Fp2/private proofs.
[CCCL3.5](https://github.com/NVIDIA/cccl/releases/tag/v3.5.0) release notes and
current CUB docs are newly assessed here. The rendered release date is
Oct7 16:11 without a year; do not present it as a fully verified ISO date.
Its observed tag commit's arch_traits diff is inspected, not its blocked
warp-reduction implementation. Latest Python1.3.0 maintenance overhead is a
different frontend from this Rust/NVRTC path. The
[prime-ir issue](https://github.com/fractalyze/prime-ir/issues/409) is a
refresh of a retained negative: its author rejected both wider accumulation
and the shorter carry sequence after device tests. Those are author results,
not reproduced here, and warn against converting operation counts to speed.
CUDA13.3 carryless multiplication concerns characteristic-two fields and
does not directly substitute for native odd-characteristic Goldilocks Fp2.

Repository/license/history/raw-code cache misses and the reduction PR timeout
are in source records; none was bypassed. No foreign code was executed,
downloaded as an executable, installed or built. Full license bodies were
unavailable for the inspected repositories; no implementation code is adopted.

Reproduce sequentially from the research directory:

```text
python3 -B experiments/arithmetic-intensity-screen-20261030/run_bounded.py experiment
python3 -B experiments/arithmetic-intensity-screen-20261030/run_bounded.py audit
```

Audit historical pins before rerunning against a changed native tree. Seed
20261030167, commands, hardware, source pins, fixtures and logs are retained.
Main leaf: 0.871774 s / 20,308 KiB maximum RSS; final audit: 0.033268 s /
16,876 KiB. These are correctness-process clocks, not proof/kernel clocks.
One nice19 CPU affinity on Intel Core Ultra9 185H, Python3.10.12; 30s CPU,
40s alarm, 45s parent timeout, 256MiB address-space cap, 64MiB estimate.

Baseline / ceiling: direct current private-slot incidence is absent, so this
helper alone contributes **1x** there. A future real device evaluator has
unknown removed exclusive reduction cost C and added cost A; its enclosing
rate is N/(T−C+A), with necessary 50/s condition T−C+A≤N/50. Reject promotion
on absent incidence, byte/refusal/carry/membermask/convergence mismatch,
negligible reduction fraction, or added occupancy cost exceeding savings.

Top3 remain complete independently verified high-endGPU resident1/2/4/8,
admitted context/DD/fidelity scaling, and exclusive native phase/capacity
measurement. H101 is conditional and demoted; all 100 prior hypotheses are
preserved. No more toy reducer variants without an active private GPU seam.
The [integration handoff](INTEGRATION.md) identifies owner gates and costs.

New verified full-stack proofs / model passes / proved positions: **0/0/0**.
Actual model context: **none**; accelerator: **none**. Witness/proof/
serialization/verification/startup/initial-prefill clocks, startup fraction,
proof latency/bytes and steady-state/total-workload proved-token rates:
**unmeasured**. No long-context prefill, resident proof series or decode ran.
Larger workloads remain permitted; attention can grow quadratically.
Private8B ≥50 proved tokens/s on RTX5090 or another named high-end GPU remains
unachieved. No mask, pad or private-opening reuse or weakened privacy.

Explicit carry-boundary refinement retained: two canonical words sum to2^64; the missing-carry control rejects. Initial syntax-error attempt and the corrected passing replay are preserved under the experiment directory. Final checkpoint 2026-10-30T15:58:05.567640+00:00.
