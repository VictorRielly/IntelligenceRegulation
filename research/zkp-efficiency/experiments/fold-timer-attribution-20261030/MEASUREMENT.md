# Owner measurement interface — review only

The interface is the existing
`dev_fold_rows(&DevCommit, &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String>` in
`hashline/src/gpu/cuda.rs`. No production patch is applied or requested for
automatic integration. This is a measurement prerequisite for packing, staging,
or lock-placement decisions, supplementing cycle 0120's general FZC schema.

An enclosing observer must begin before `gpu()` and finish after the function
returns and its local buffers/guard drop. Record success and failure observations
privately. Keep original exception, initialization and publication behavior.
Dropping device slices can merely enqueue stream-ordered frees; a returned host
scope is not an allocator-retirement/device-completion certificate. Record the
actual later completion edge without adding a synchronization for measurement.

Suggested call-local public metadata: workload/pass/layer/group identifiers,
public role and shape `(rows,n,k)`, a monotonic integer call ordinal, outcome in
the owner's private diagnostic, and integer timestamp offsets for:

1. entry; GPU lookup/initialization return; mutex wait start/acquire; dev clone;
2. packing begin/end; upload wrapper enter/return; output allocation enter/return;
3. kernel lookup; launch API enter/return; download wrapper enter/return;
4. stats-mutex wait/acquire; legacy stats sample; conversion begin/end;
5. local device-free submission, guard release, function return, enclosing drain.

Do not log pointer addresses, private lengths not admitted by the profile,
rho/field elements, challenge values, random seeds, pads, openings, inputs,
outputs or weights. Error identity can depend on hidden input: do not export
failure detail or enable publication of a failed run. Public diagnostic roles
must themselves be admitted public metadata. Logging overhead, buffering, and
off/on comparisons remain costs and review obligations.

Host wrapper ranges include wrapper overhead and synchronous waits. Installed
cudarc 0.13.9 copy wrappers synchronize its stream; a wait can cover preceding
work. `GpuStats::secs_fold` also waits for STATS before taking its elapsed
sample. It is neither pure kernel time nor a complete helper wall clock.

Correlate actual CUDA activities with the launching API using process/context/
stream identity and correlation IDs from the *same* capture. Retain unmatched
activity and missing/multiple mappings as unexplained evidence. A host timestamp
enclosure or kernel name alone is insufficient. Cross-capture Nsight Compute
metrics are a separate diagnostic requiring identical invocation/shape/order
and replay conditions; matching per-kernel counts alone cannot certify this.
Do not subtract clocks from different domains. No correlation adapter or native
instrumented observer was implemented/tested in this cycle.

Measure actual exclusive packing/allocation/conversion, queue waits, lock
contention, device activity, capacity and the enclosing verified workload. Do
not sum overlapping host/API/device ranges or equate a queued free with freed
capacity. All fallback work and cleanup remain in workload clocks.

Owner acceptance: current source/build/profile pins, GPU/CPU byte/refusal
controls and fresh-process complete-proof verification; full phase/workload
reconciliation including serialization and drain; no mask/RNG/FS/order changes;
unchanged admitted P1/P3 relation and privacy gates. Native heavy/device work
belongs to the owner under current guard and common build/heavy locks.

Only then rank an optimization using `N/(T-C_critical+A_added)`, with
`C_critical` measured safely removable end-to-end critical-path time. A duration
inside a synchronization wrapper is not automatically removable. If packing
or mutex contention is negligible, park those variants. No numerical complete
8B GPU ceiling is available from this experiment.
