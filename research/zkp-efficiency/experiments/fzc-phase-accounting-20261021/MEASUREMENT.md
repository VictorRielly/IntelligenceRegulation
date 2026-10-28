# Source-backed measurement proposal, cycle 0120

This is a research interface and source audit. No native hook was installed.
Owner review and the shared build/heavy locks precede any native build or run.

The question is whether repeated FZC host allocation/map/free calls occupy enough
of the complete proof's critical path to justify bounded scratch retention.
The prior logical safety experiments are necessary but do not answer materiality.

Baseline: each attempted `DevFzcRounds` eagerly creates a fallback pin and,
conditionally, a mapped pin; the CPU-tail transition allocates a distinct pin
and device pack. The current FZC build timer includes several different costs.
Its total begins after GPU initialization/lock acquisition/optional warmup, is
sampled before reporting and destruction, and is only aggregated on success.
The tail timer samples before its local `pin` and `d_pack` leave scope.
These are source boundaries, not evidence that any omitted cost is large.

Potential eliminated work: repeated driver host allocation, mapping and free API
work on successfully reusable storage. Added costs: leases, capacity reservation,
safe completion/retirement, new active-range clearing, failure quarantine, record
tracking, retention and instrumentation. Binding, zeroing and mandatory fences
must remain charged even when a wrapper allocation disappears. No proof
arithmetic, masks, commitments, transfers or serialization are deleted here.

If f is the unknown **truly removable critical-path** fraction of a complete
workload, even free deletion gives at most 1/(1-f), before added costs. A sum of
API durations or a fraction of nested FZC timers is not f. The synthetic probe
gives two 30-unit workloads with 8 units in the allocation API; deleting that
cost saves either 0 or 8 units depending on dependencies. These are artificial
units, not native nanosecond measurements or a forecast.

Use one enclosing monotonic workload clock through serialization and pipeline
drain. Time independent verification separately. Inside it:

| Scope or role | Proposed native boundary |
|---|---|
| FZC caller attempt | `fzc.rs::prove`, before `DevFzcRounds::new`, through evaluator destruction on success and error |
| constructor pre-body | GPU setup/lock, memory diagnosis and configured warmup, before current `t0` |
| build | Current `t0` to constructor return; split into role/API intervals, leave unclassified remainder charged |
| module | Cache lookup/load/compile, with cold/warm/cache state; remains inside total workload |
| round | Entry through return; lock, launch API, mapped poll or copy/sync in their own host scopes |
| tail transition | Entry through destruction of local `pin` and `d_pack`; allocation, pack enqueue, copy enqueue, existing sync, unpack, frees |
| report / final cleanup | Reporting and every destructor after the old `secs_total` sample; early-return attempts also get terminal accounting |
| host allocation APIs | Exact `cu::malloc_host`, `cuMemHostGetDevicePointer_v2`, `cu::free_host` call boundaries; tag fixed public role |
| retained costs | Context binding, active-range clearing, existing completion waits and any new retirement fences, separate from eliminated APIs |

`source-audit-result.json` gives content hashes, source anchors and current line
numbers. `accounting.py::summarize(spans)` accepts strict fixed-enum metadata:
integer ID/parent/thread ordinal, `host_monotonic_ns`, integer start/end, phase,
role, infrastructure outcome and public requested bytes. Unknown fields, clock
domains, private labels and arbitrary payloads are refused. Integers must stay
integers in JSON consumers; do not parse 64-bit nanoseconds through a floating
point representation. This schema is for interval attribution only; it does
not certify allocation ownership, native fence completion or privacy.

For each anonymous thread ordinal, direct children partition the parent:
exclusive = inclusive minus direct-child coverage. Remainders remain charged.
The sum of exclusive intervals equals that thread root. Parallel thread-wall
may exceed workload elapsed and is never used as the throughput denominator.
`family_thread_wall(spans, selected)` counts selected wrappers and descendants
once; summing a wrapper and nested driver interval double-counts them. Conversely,
summing the wrapper's exclusive label alone omits its driver child.

Device execution and transfer activity belong to separate CUDA/Nsight domains
with correlation to host scopes. Do not cast those timestamps into this host
partition. No new synchronization should be inserted solely to make host ranges
look like device clocks. Existing `sync_if_prof` adds a stream wait in profile
mode, so do not compare its phase attribution to normal mode as identical
scheduling. Use existing completion boundaries where possible, and record
instrumentation off/on enclosing clocks to bound perturbation. Nsight event
tracing itself can introduce overhead/dependencies. Do not add a dependency or
install a profiler in this research lane.

Role sizes are conditional request formulas, not physical registration pages:
round fallback = 16*(D+1) B; mapped = 16*(D+1)+8 B; each tail pin and device
pack = 16*k*half B. At D=5,k=21,half=32, host total is 10,952 B if every
allocation is reached and mapped allocation succeeds. Requested capacity,
driver resident capacity and cumulative allocated bytes remain distinct.

Telemetry contains no private values, prompts, tokens, weights, challenges,
mask words, addresses or arbitrary driver errors. Retain only public role/shape
metadata. Do not export input-dependent eligibility flags or refusal messages.
Local performance diagnostics are not public receipt fields and do not extend
any accepted privacy statement. The mathematical relation, randomness draws,
transcript updates, original refusal behavior and eager fallback stay intact.

Native owner gate: first measure complete admitted proof workloads and public
allocation incidence with this coverage. If material, test the existing scratch
candidate with unchanged masked-round messages, challenges, refusals and full
receipt verification. Complete GPU 8B phase/capacity clocks and verified
fixed-context resident 1/2/4/8 passes remain higher priority. Report startup and
steady/total rates, context, passes, device, witness/proof/serialization/verify
clocks, transfer/peak capacity and pipeline drain. Longer single contexts can
increase attention work quadratically; independent passes are not decode.

Falsify or park on negligible safely removable time, material instrumentation
perturbation, missing/error/unreconciled scopes, leaks, transcript/refusal drift,
unsafe retirement, capacity regression or slower complete workload. The native
allocation fraction and complete GPU slope remain unknown. Park runtime pooling
until those data exist; no numeric 5090 rate follows from this experiment.
