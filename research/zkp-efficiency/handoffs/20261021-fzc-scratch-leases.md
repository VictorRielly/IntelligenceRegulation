# FZC scratch storage leases — research handoff, cycle 0118

No native speedup measured. Main/Claude reviews and integrates; this lane does not merge.

Research code and source hashes: `experiments/fzc-scratch-leases-20261021/`.
`lease_model.py` is a Python lifecycle sketch, not a CUDA concurrency implementation.

The active seam is `ops/zkp-mvp/gpu-zerocheck/hashline/src/gpu/cuda.rs`:
`PinBuf::new_read`/slice methods/Drop (783 onward), `FzcMapped` (4124 onward),
`DevFzcRounds::new` (4477–4503), mapped poll/fallback (4680–4716), and host-tail
packing (4766 onward). The kernel publishes words, a system fence and a sequence
flag at `fzc_kernels.cu:904`. This is the active GPU lane, not an accepted GPU
privacy profile or the frozen CPU artifact.

Current constructor allocates a cached-read fallback pin before attempting mapping.
Every mapped attempt starts seq=0 and zeroes its new mapped allocation. Tail packing
allocates another host pin and a separate device d_pack. Reusing storage could avoid
host allocation/free/map calls, while all mathematical work and transfers remain.

A conditional same-shape 32-attempt trace (degree5, support on, tail_log5,
each attempt reaches half32) reduces 96 host allocations to three and map queries
from32 to1. It retains10,952B. A changing-shape trace independently agrees on96->6
allocations,513,792->32,112 cumulative allocated bytes and21,704B idle retention.
The changing-shape transient peak rises from21,704B to31,944B during replacement.
These are host-capacity/request counts, not driver page granularity, VRAM or clocks.
The separate device d_pack, device tables, round messages, copies and syncs remain.

Proposed interface for owner review:

1. A bounded ScratchOwner keys allocation role, device/context identity, owning
   stream, cached-read versus mapped flags and capacity. Return a reserved lease
   with explicit requested length and generation; retain allocation ownership
   through all asynchronous uses. Never publish raw contents or addresses.
2. Activate retained mapped storage only after successful completion of every prior
   use, then clear the active range including the NEW flag offset2*(degree+1).
   Cudarc0.13.9 `CudaDevice::synchronize` synchronizes its stream only. The existing
   constructor sync at4494 may provide this fence if reset moves after it and all
   prior uses are on that stream. This conditional route avoids adding a barrier;
   it does not justify resetting before the fence or covering other streams.
3. Acquire fallback storage eagerly at constructor stage. Preserve process-wide
   FZC_MAPPED_BROKEN, environment opt-out, split eligibility and copy+sync fallback.
   A cached hit avoids a physical allocator call and cannot reproduce every OOM.
   Do not claim identical resource-failure behavior. Lazy fallback is not proposed.
4. Pass EXACT requested-length slices to memcpy and readers. Current PinBuf methods
   return its full len. If a12-word capacity serves a10-word result and the whole
   capacity is copied, the smaller d_sums is overread. Capacity and active length
   must be separate in the native adapter, for both fallback and tail pins.
5. A mapped sequence flag signals message publication, not stream completion.
   Retire with a last-use event bound to allocation generation, stream and all
   submissions. An earlier-round event cannot authorize later reuse. Checked
   sequence overflow must refuse. Keep current native system-fence behavior;
   this model does not prove CPU/GPU memory ordering.
6. Timeout or failed synchronization must not return storage to an available pool.
   Bound quarantined capacity, stop admission if exhausted and leave safe teardown
   to the owner. Existing timeout sets self.mapped=None before explicit fallback
   sync: review the driver lifetime semantics before changing cleanup. This is a
   source-level risk, not a reproduced native use-after-free.

Validation: storage probe1,418 checks,96 fixtures/320 messages,36 changed-shape
cases and17 control types; source/order model120 interleavings in16 families, with
zero failures in eight same-stream/post-sync cases; independent audit6 checks with
matching changed-shape counts. Synthetic bytes and hash chains are not field-proof
or native transcript evidence. No masks, RNG, commitments, receipt or verifier ran.

Before promotion, measure public-role allocation incidence and exclusive/enclosing
costs. Under shared heavy/build locks, run native same-seed round/next-challenge/
final/receipt parity and independent verification, mapped on/off and split/fused/
tail variants, growth/shrink, mapping denial, timeout, async error, poisoned context
and wrong-stream controls. Preserve all original refusal and privacy obligations.
Reuse allocation storage only; fresh masks, challenges, openings, private contents
and RNG order remain mandatory. Do not cache any unmasked result as preprocessing.

With unknown exclusive allocation fraction f, even free removal is bounded by
1/(1-f); owner/reset/event costs reduce that bound. No numeric complete8B rate
follows. Falsify on stale/incorrect words, incorrect lengths, different semantic
refusal, changed proof bytes, unsafe lifetime, unbounded retention, negligible
allocation fraction or worse enclosing complete-proof time. Prioritize complete
GPU clocks and verified resident1/2/4/8 workloads above this rank34 candidate.
