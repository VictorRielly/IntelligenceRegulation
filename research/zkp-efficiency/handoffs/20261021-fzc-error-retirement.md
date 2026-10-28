# FZC error retirement — cycle 0119 handoff

No native speedup or bug reproduced. Main/Claude reviews integration; this lane does not merge.

Research model: experiments/fzc-error-retirement-20261021/retirement.py and reference.py.
The model is not a Rust/CUDA adapter. Four exact live/source-copy pins are in source-pins.json.

Active seam: ops/zkp-mvp/gpu-zerocheck/hashline/src/gpu/cuda.rs:
PinBuf::new_read/slices/Drop (~783), FzcMapped (~4124), DevFzcRounds::new (~4477),
try_round mapped timeout/fallback (~4680–4716), and try_fold tail copy (~4766–4784).
Cudarc0.13.9 alloc.rs:407 synchronizes its own stream. Kernel publication is
fzc_kernels.cu:904 onward. Current native source, frozen CPU profiles and this model
are separate scopes.

Candidate ownership interface for review:

1. Reserve capacity for each physical allocation before device submission. Bind its
   context, allocation generation, role/flags, capacity and active length to the lease.
   Count active+idle+quarantined+growth storage, not only idle entries. Deny admission
   before exceeding the cap; do not drop an already-live allocation on exhaustion.
2. Record each possibly submitted use, conservatively including ambiguous copy/launch
   errors. Close further submissions before retirement. The native adapter must bind
   completion evidence to the successful event RECORD INSTANCE and its captured stream
   frontier. Query SUCCESS on an unrecorded event is not evidence of any submitted work.
   A re-record or later submission must never silently advance an old certificate.
3. Reuse/free only after reliable completion covers all last uses. Existing successful
   constructor sync may cover same-stream prior work, followed by fresh active clearing;
   another stream needs its own completion or a proven event-wait join. Do not add a
   per-round event by default: account for its overhead first. The publication flag is
   not used as a lifetime certificate by this conservative model.
4. Timeout disables mapping as before. Failed copy/sync/record/query does not prove
   cancellation; quarantine unresolved ownership. A later valid fence can retire it,
   while the failed proof remains refused. Poison stops context admission; no bounded
   eventual release is claimed. An ambiguous free error stays charged and must not
   cause a blind free retry, dereference or reuse. Leave teardown policy to owner review.
5. Preserve eager fallback acquisition, process-wide FZC_MAPPED_BROKEN, original slice
   lengths, arithmetic, refusals, fresh masks/openings/challenges and RNG/transcript order.
   Reuse storage only. Cache hits change physical OOM possibilities; no identical OOM
   contract is asserted. No private values, prompts, weights or raw addresses in logs.

Validation: 5,037 checks /4,800 differential cases  / 105 interleavings; separate
61-check source/permutation audit /36 role-error paths. Candidate frontier counters
and reference token sets agree. Three unsafe-policy counts67/46/1 are model results.
Operation completion is a sufficient last-use upper bound; this model does not show
post-flag mapped accesses or native use-after-free. No CUDA memory-order, masked-round,
receipt, verifier or privacy test was run. Final CPU script clocks are diagnostic only.

Before promotion: owner measures host allocation/map/free incidence and exclusive
allocation fraction plus enclosing witness/prove/serialize/verify clocks. If material,
under shared heavy/build locks test native parity and independent receipt verification,
same/changing degree/shape, mapped on/off, split/fused/tail, timeout, failed copy/sync/
record/query, wrong stream, stale record, poison and teardown. Record failed attempts.
No recurring masks or openings may be reused to improve amortization.

End-to-end ceiling: unknown. Even free deletion of exclusive fraction f is <=1/(1-f),
and bookkeeping/fence/retention costs lower it. Full device/model proof clocks and
verified fixed-context resident 1/2/4/8 remain higher priorities. Park this candidate
until allocation clocks justify it. Next local deliverable is a source-backed measurement
schema with independent nested-interval replay, not another pooling speed claim.
