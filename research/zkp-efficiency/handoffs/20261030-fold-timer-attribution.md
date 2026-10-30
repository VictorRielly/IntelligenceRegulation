# Cycle 0159: fold phase measurement prerequisite

20261030T074123Z-71d2f333 — 2026-10-30T07:55:01.314464+00:00. **No measured proving improvement.**

Review [experiment](../experiments/fold-timer-attribution-20261030/README.md)
and [measurement interface](../experiments/fold-timer-attribution-20261030/MEASUREMENT.md).
The existing seam is `hashline/src/gpu/cuda.rs::dev_fold_rows` with unchanged
`(&DevCommit,&[Vec<Fp2>])->Result<Vec<Vec<Fp2>>,String>`.
Research code is `mock.rs`,verbatim extracted `native_fold.rs`,and independent
`reference.py`; no production patch or native observer was implemented.

326fixtures pass:110 successes,216 errors/panics,20malformed shapes,2934clock/
payload comparisons,2,154 bigint payload limbs and8 corruption controls. This is
source-boundary evidence under synthetic APIs and clocks,not native error,
driver,device,receipt,privacy or elapsed-performance evidence.

The legacy fold counter omits pre-timer GPUinit/mutex/clone and post-sample
conversion/drop; STATS wait is included before its sample; errors skip the
counter. Copy wrappers synchronize earlier stream work. With the same32tick
packing reduction, explicit mock schedules save either 0 or 32 ticks. Those
arbitrary units are not a workload speed claim. A queued free is not retired
capacity. Keep enclosing verified workload clocks and actual completion edges.

No mask,pad,opening,FS/RNG,arithmetic or profile changes. Owner instrumentation
must retain error/refusal/publication behavior,private diagnostics only,
current gates,byte/refusal checks and independent full verification. Assess
instrumentation overhead and causal correlation before attribution. Do not
move locks,upgrade dependencies or add timing synchronizations from this result.

Next: owner measures complete verified high-end GPU workloads and fixed-context
resident 1/2/4/8 passes, with current admitted profile, exclusive phases, actual
capacity and startup/drain. For this seam, measure GPU initialization, mutex wait/hold,
packing, allocation, H2D, kernel, D2H, STATS wait, conversion, drop submission and
actual retirement. Reconcile with an enclosing independently verified workload;
do not insert synchronizations just to separate timers. If owner traces are
absent next cycle, test a values-free same-capture correlation adapter with
equal-count shuffled-role and missing/duplicate-ID controls (hypothesis 90).
No more packing/staging variants without measured materiality.

Ceiling unknown: `N/(T-C_critical+A_added)`; park if safely removable costs are
negligible. Main/Claude owns review and integration; nothing merged.
