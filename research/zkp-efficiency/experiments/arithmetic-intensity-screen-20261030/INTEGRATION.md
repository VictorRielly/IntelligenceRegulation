# Conditional integration boundary

The existing CUDA seam is `hashline/src/gpu/kernels.cu::scg_emit<NV>` and
`k_reduce_f2`, launched by legacy `cuda.rs::dev_zerocheck*` and
`dev_tab_zerocheck`. The inspected trained/R14 private slot factories select
host `GroupedEqRounds`/`ClosureRounds`. There is no direct current private-slot
speed benefit and no production patch. Do not port this helper as a claim
to have accelerated that private proof.

`warp_sum.cuh::zke_warp_sum_leader(u64)` returns a canonical Goldilocks sum
only to physical lane0. All32 lanes execute the same three volatile full-mask
redux operations; workload-tail lanes supply zero. Canonical input words,
sm80+, full-warp convergence and exact launched CTA size are preconditions.
`zke_emit_tail<THREADS,NV>` uses WARPS*NV*2 u64 scratch, one CTA producer/
consumer barrier, and a first-warp zero-padded final reduction. It is tail-only;
looped scratch reuse needs a second CTA barrier. The ordinary fallback stays
available on other devices/shapes. No runtime assertion on private values
should become a newly public refusal channel.

The sketch is **uncompiled**. Python fixed-width algebra matches independent
bigint sums and direct-node round polynomials; no physical CUDA/compiler/race
or native CFS/PCS/cryptographic verifier test ran. Volatile assembly and a CTA
barrier are explicit source obligations, not tested hardware guarantees.

A real private GPU evaluator must first implement the additive
`zkp-core::SumcheckRounds::round` boundary. Preserve ordered unmasked values,
all masker/RNG/transcript/next-challenge bytes, extension rounds, terminals,
opened source bindings, fresh masks/pads and malformed-witness refusals.
Legacy APIs own one mutable transcript and are not automatically private
round evaluators. No protocol/field migration or proof/profile weakening.

Owner validation: compile a public-shape candidate under the current shared
build/heavy locks; inspect generated code, registers and collectives; run
device boundary/partial-warp/1024-thread/scratch-reuse controls and native
round differentials; frozen masked transcript/RNG/receipt byte gates;
independent fresh-process full-stack verification and current privacy gates.
Only then compare the identical complete workload with exclusive reduction,
compute/transfer/allocation clocks, actual capacities and startup/drain.

No GPU job, build, launch queue, production change or merge is authorized by
this handoff. Main/Claude owns review/integration. First establish native
private GPU incidence and material critical-path reduction time; park this
component otherwise. Count every fresh proof operation and independently
verified complete position across resident1/2/4/8 workloads, with context and
device named. This helper removes no global proof data, masks or launches.
