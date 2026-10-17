# Native root-preserving shift twiddles — review candidate

Cycle0045, run `20261013T022555Z-d570e67c`. [Experiment and costs](../experiments/native-twiddle-shifts-20261013/README.md).
Exact serial CPU model passes; **uncompiled CUDA helper, no native speed gain**.

Interface: [shift_twiddle.proposed.cuh](../experiments/native-twiddle-shifts-20261013/shift_twiddle.proposed.cuh)
provides `gl_mul_pow2_192(a,e)` and
`gl_mul_native_twiddle(a,native_w,stage,k,inverse)`, using existing canonical
`gl_reduce`, `gl_sub`, `gl_mul`. Inputs a<p,e<192; stage1..32 and valid k.
The plan is specific to the unchanged generator7/root64=2^39 domain.
Direction/stage/root provenance must come from the immutable native
table constructor. Arbitrary external metadata cannot be trusted; an explicit
control shows eligible arithmetic can ignore a changed supplied twiddle.

Seams: current owner copy
`ops/zkp-mvp/sonnet-hardening/hashline/src/gpu/kernels.cu::k_ntt_p1` at117,
`ntt_p2_body` at167 and corresponding scale stores; its
`hashline/src/gpu/cuda.rs::stage_major` at1624/`ensure_twiddles` at1659 owns
public table/direction dispatch. CPU baseline is `zkp-core/src/ntt.rs::transform`
at69/`two_adic_root` in field.rs81. Exact snapshot hashes live in
[source-pins.json](../experiments/native-twiddle-shifts-20261013/source-pins.json).
Production and the owner candidate were not changed.

First bounded implementation: first6 stages plus known inverse size scale,
within the existing kernels. Leave coset scaling and all other products
general. Preserve zero-pad stage skip, pruned openings, swizzles and launch
count. Late sparse eligibility can diverge warps; its small additional
operation opportunity does not justify all-stage dispatch without measurement.
Use staged template/constants if native PTX shows their benefit, never change
roots to fit paper exponents. No altered PCS/rate/field/encoding or privacy
profile follows from this candidate.

Validation:38,592 shift integer checks; full8,190 forward/inverse native
stage-major entries through log12;24,570 stage arithmetic checks;33 hiding
rows/1,496 values matched independent Lagrange+pad evaluation. Native tiled
serial forward/inverse schedules at logs12/13/14 pass, with48 independent
Horner samples. Forty ordinary fixtures,64 direct DFT comparisons,6 RS
rows and18 controls pass.1.324346s/20,208KiB, one CPU thread/CPU0/nice19,
seed2026101345. A corrected harness failure is retained, not a protocol failure.

Counted full-transform eligible general products are7N/2-32 for N>=64:
35% at N=2^20, of which~30% is first6 stages. These are **source operation
counts**, not phase/full-proof savings. Inverse scale is separate; existing
rb2/rb3 skip leaves27.78%/23.53% eligibility among executed stages. Added
public index/exponent/sign dispatch, shifts/reduction/carries/registers can
erase the gain. No memory/launch/cache-startup saving is assumed.

Owner gates: compiled CUDA versus exact reference and existing CPU path;
zero/carry/sign boundaries, native root/order/scale and q>n row padding;
monotonic table ownership and mixed forward/inverse calls; device sync and
pruned/swizzled routes; native frozen proof bytes/masked RNG/extension parity;
fresh independent verifier and corruption/refusal controls. Only then run
guarded affected/enclosing timings, instruction/register/occupancy and peak
memory with the same complete workload. Falsify on any arithmetic/receipt
change or no enclosing improvement after added costs.

For an accepted complete private8B workload the ceiling remains
Nproved/(Ttotal-Celigible_general+Ccandidate_cost). No affected phase share
is available. Target remains>=50 completed independently verified positions/s
on a named high-end GPU, with separate steady/total/startup/phase/pass/context
records. Accepted private8B proofs/tokens0; no local GPU/heavy job queued.
Main/Claude owns review/integration. Saved handoff is not a delivered message.
