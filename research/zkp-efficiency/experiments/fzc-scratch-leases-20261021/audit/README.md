# Independent FZC scratch lease audit (cycle 0118)

The standalone [script](independent_audit.py) reads the native Rust/CUDA seam, checks source anchors, and evaluates a synthetic 32-attempt trace. Its [JSON report](independent_audit.json) contains source SHA-256 hashes, anchor lines, formulas, counts, negative controls, and limitations. It imports no candidate model and executes no native source.

Exact run command (completed once, exit 0):

```sh
nice -n 19 python3 experiments/fzc-scratch-leases-20261021/audit/independent_audit.py
```

The script pins itself to one allowed CPU and sets 30-second CPU and alarm limits and a 256 MiB address-space limit. Wall time was under one second. No GPU, build, installation, network, or native test was used.

The trace cycles `(degree, k, tail_log)` = `(4,20,5), (5,21,6), (5,20,5), (4,21,6)` eight times. It assumes each split attempt reaches a host-tail transition with `half = 2^tail_log` and mapped allocation succeeds. Per attempt, mapped capacity is `2*(degree+1)+1` u64, eager fallback is `2*(degree+1)` u64, and tail host pin is `2*k*2^tail_log` u64. Baseline: 96 native pinned-allocation events, 513,792 cumulative requested bytes. A single sequential same-context cache that grows on demand has 6 events, 32,112 cumulative allocated bytes, and 21,704 bytes retained at the end. Growth can temporarily hold old and new allocations together. The separate device `d_pack` allocation is outside these pinned-host counts.

Source-level risks and controls:

- `DevFzcRounds` resets `seq` to zero per attempt. A reused mapped flag of one can satisfy the next first-round poll before the new kernel publishes. Changing degree shifts the flag offset; for degree 5 to 4 the new index 10 was old payload, which can equal one. Synchronize prior writers before resetting the active flag offset, then keep a generation/owner discipline through every round.
- The kernel writes mapped result words, then executes `__threadfence_system`, then writes the flag. Host observation of the flag is a message signal; it does not by itself establish stream completion for release or reuse.
- On the existing timeout path, `cuda.rs` assigns `self.mapped = None` before fallback `cu::stream::synchronize`. This may free a mapping still referenced by the launched kernel. It is a source-level risk, not a confirmed use-after-free: driver `free_host` behavior was not tested here. Retained storage must be quarantined when completion is uncertain and never reissued after a poisoned context.
- Eager fallback pinned allocation precedes mapped allocation in the constructor. Acquire a fresh fallback **lease** at construction, even if a cached allocation serves it, so failure/refusal remains a constructor-stage event. Allocating fallback only after a mapped timeout moves the failure point. A cache hit avoids a new native allocator call, so it cannot reproduce every physical allocation refusal.
- Existing `cuda.rs` constructor calls `dev.synchronize()` after allocating the mapped buffer. In local `cudarc 0.13.9`, `CudaDevice::synchronize()` calls `result::stream::synchronize(self.stream)` (`driver/safe/alloc.rs:407`): it covers that device stream, not every stream in the context. For same-stream sequential reuse, resetting retained storage **after** this successful constructor sync can use the existing fence. Resetting before it can race with an old writer. Other-stream references need their own completion evidence.

The JSON negative controls assert false-completion possibilities for stale same-degree `seq=1`, both degree-direction offset hazards, and a reset before old-stream completion. They assert that fresh zeroed storage and sync followed by current-offset reset do not spuriously satisfy the first poll in the synthetic model. These are logical controls; they do not prove CUDA memory-order behavior.
