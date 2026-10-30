# Normalized fold-attribution interface — research only

The candidate is `adapter.rs::analyze(&str) -> Result<String, String>`.
Its intended observer seam is the unchanged
`hashline/src/gpu/cuda.rs::dev_fold_rows(&DevCommit, &[Vec<Fp2>])`.
This is an offline normalized-metadata adapter, not a CUPTI parser, native
instrumentation patch, trace authenticity check or complete-workload accountant.

Each case contains whitespace-separated unsigned 64-bit integer fields:

```text
M capture dropped_total finalized count_C count_H count_A count_E count_G
C capture pid fold tid device context stream rows n k
H capture pid external fold tid role device context stream host_start host_end reserved
A capture pid correlation tid kind device context stream host_start host_end mode graph reserved
E capture pid correlation external
G capture pid activity correlation kind device context stream gpu_start gpu_end graph reserved
```

Roles/kinds 1, 2, 3 mean H2D, fold kernel, D2H. Mode 1 means a canonical
driver launch/copy record; reserved/graph fields must be zero. A case contains
exactly one capture; PID scopes IDs. The schema assumes one configured
external-correlation kind and one independently established host timestamp
domain for H/A, plus one device timestamp domain per device for G. Integer
units are retained. No host/device timestamp subtraction or cross-thread
elapsed sum is performed. The toy executable separates independent cases
with a literal line `---`; it does not join across cases/captures.

`C` is the declared roster of **successful nonempty** fold calls. Every call
requires three distinct H phase records, consistent tid/device/context/stream,
rows > 0, power-of-two n, and k in 1..4. Host phases on one pid/tid cannot
overlap. Every A must have exactly one E mapping and fit its H phase in the
host domain. Every G must match its initiating A's pid/correlation/kind/device/
context/stream. Every H and A must be used. Multiple A records per H and
multiple G records per A are supported. Device activity can finish outside
the host wrapper; timestamp enclosure never assigns causality.

Output J rows identify `(pid, activity, fold, role, correlation)`. H rows give
API interval unions **per pid/tid**; D rows give activity interval unions
**per device**; R rows give unions **per device/role**. Role unions may overlap,
so they cannot be added to obtain device elapsed or workload critical time.
No function duration, queue latency, startup fraction, proof rate, live VRAM,
free retirement or causal-removal estimate is inferred.

Native collector obligations, all unimplemented/unmeasured here:

- Derive and pin the call roster independently of the lossy trace export.
  A coherent whole-call + roster + count deletion passes this adapter, as
  the retained limitation fixture demonstrates. A manifest is an assertion,
  not authentication. Consistently forged labels or assigned activity IDs
  can also evade local consistency checks.
- Establish source/profile/build pins, call-site roles, CUDA context/stream
  identity and thread-ID convention. A fields for device/context/stream are
  normalized exporter enrichment, not fields claimed to exist in every raw
  `CUpti_ActivityAPI`. Activity IDs are stable exporter-assigned record IDs;
  exact duplicate-ID rejection does not detect every duplicated physical event.
- Accumulate every drop-count sample (the API resets its counter on read),
  callback/export overflow and decode errors. `finalized=1` needs evidence
  that delivery completed after the natural workload completion edge. A flush
  flag or forced delivery alone does not establish completed device records.
- Retain raw, unmatched, unsupported, failed and excluded records in the
  owner's private diagnostic. This schema selects launch/copy activities;
  allocation, synchronization, free, module lookup and other driver calls
  require an explicit separate census. Never silently discard them or report
  this adapter's selected unions as whole `dev_fold_rows` coverage.
- Empty calls, errors/refusals, graphs, runtime/driver nesting, child launches,
  unknown clocks, ambiguous metadata and unknown activity forms reject or
  remain unassigned. They are outside the currently accepted schema. No
  fallback to kernel-name/count/order matching.
- Keep diagnostics private. Roles and shape must be admitted public metadata;
  timing/failure identity is not automatically safe to publish. No pointers,
  rho/challenges, masks, randomness, openings, model data or witness values
  belong in normalized records. All retained fixtures here are synthetic.
- Compare observer off/on enclosing workload cost without adding timing
  synchronizations; charge buffering/export/analysis and drain. Instrument
  entry through return/drop separately; activity completion is not allocator
  retirement. Validate current byte/refusal/privacy gates and independently
  verify every complete receipt before counting positions.

[Version-pinned CUPTI usage](https://docs.nvidia.com/cupti/13.2.1/main/main.html)
and [Activity API](https://docs.nvidia.com/cupti/13.2.1/api/group__CUPTI__ACTIVITY__API.html)
were read live. No CUPTI installation or tracing ran. The native CUDA/cudarc
pins are in `source-pins.json`; upstream APIs are methodological references,
not a dependency upgrade proposal. Main/Claude owns native review/integration.
