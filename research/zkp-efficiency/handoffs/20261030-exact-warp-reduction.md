# Exact warp reduction — conditional component, no current slot gain

Cycle0167, `20261030T154123Z-20600a3e`. No measured proving improvement.

New locally authored model: sum each Goldilocks limb using three exact
27/27/10-bit digit sums, reconstruct the ≤69-bit whole sum, canonicalize.
53,030 checks / 29 controls PASS; 10,530 warp cases,96 CTA cases,36 fullFp2
product-polynomial round cases. Separate243-check saved-evidence audit.
One CPU affinity, <1s main leaf,20MiB RSS; no native build/GPU/proof/verifier.

Source screen: both current trained and R14 slot evaluator factories select
CPU GroupedEqRounds/ClosureRounds. Legacy CUDA scg_emit/k_reduce_f2 is the
helper seam; optimizing it alone removes no current private-slot work.
Four R14 geometry/definition pins match cycle0154; protocol source differs.
Do not re-label a legacy GPU kernel gain as private8B throughput.

At128threads/NV5, modeled tail scratch10240→320B and CTA barriers8→1.
Added digit/collective/carry/canonicalization/register costs unknown; unchanged
polynomial products,global bytes,launches,masks. Counts are not executed
instructions,allocated peak or elapsed speed. Looped scratch reuse needs one
extra barrier on both paths. Current direct contribution1x; future enclosing
N/(T−C+A) unknown.

[Interface/sketch/gates](../experiments/arithmetic-intensity-screen-20261030/INTEGRATION.md).
Patch location: research-only `warp_sum.cuh`, UNCOMPILED. Native source pins,
fixtures,commands,seed20261030167 and raw logs in the same directory.
Full-warp convergence,volatile collectives,canonical operands,CTA ordering,
compiler/occupancy/device differentials and native masked-byte/refusal/privacy
gates remain owed. No mask/opening reuse. Main/Claude reviews; no merge.

Next owner action: establish real private SumcheckRounds GPU incidence and
exclusive reduction cost before any helper port. Highest priority remains
independently verified complete high-endGPU resident1/2/4/8 workloads with
all clocks and actual capacity/startup/drain. New full-stack proofs/tokens0.
