# ZKP efficiency progress

Cycle 0061 — `20261017T112624Z-88d6b64e`, completed 2026-10-17 UTC.

**No native speedup established.** A Python experiment passed 72 synthetic
fixtures, 5,928 plane checks, 293,384 word comparisons and seven negative
controls. It took 0.379 seconds and 17,456 KiB
RSS on one CPU thread. A separate 162-check audit passed.

The [review-only patch](experiments/witness-plane-lifetimes-20261017/witness-candidate.patch)
defers 46 initial allocations that owned vectors later replace. At TinyLlama
T128 this avoids 103.75 MiB of aggregate initial allocation; final witness
storage is unchanged. Actual peak and time savings are unknown. This does
not establish that T256 fits in memory.
[Handoff](handoffs/20261017-deferred-witness-planes.md) identifies native gates.

Six R3 owner diagnostics match successful fresh-verifier logs. TinyLlama
T128 with GPU assistance took 142.783 seconds overall, including 12.872
seconds for witness/parity/extraction. Prove-run minus witness took 107.079
seconds and still includes boundary, serialization and sink work. Fresh
verification took 8.451 seconds, excluding its model load. Diagnostic rate:
0.89646 positions/s; receipt: 497,665,904 bytes. Logs were inspected, not rerun.
Startup, serialization and steady-state throughput remain unmeasured separately.
Deleting all witness time yields at most 1.099×. R2/R3 exports differ, so the
old 529-second/new 56-second comparison is not a controlled optimization A/B.

Six LIVE source records were appended, including the October 14 HybridSpartan
revision, older sublinear-space work and a backend with bounded storage.
Blocked primary/history/license fetches are recorded. Next local experiment:
inspect which current trained lookup columns can borrow existing planes.
The owner needs trained proof-phase clocks and resident fresh-proof slopes.

Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Its context, steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag and drain are **unmeasured**. Local device: one Intel Core Ultra9 185H CPU thread, CPU0, nice19; no GPU. Owner diagnostics: trained TinyLlama1.1B,22 linked blocks, T32/T64/T128, one cold pass per CPU or RTX4070Laptop-assisted arm,16 Rayon threads,n=1; fresh-verifier logs inspected,not rerun, no privacy acceptance at that shape. No resident sweep or decode ran here; no new prefill proof ran. Larger workloads remain allowed with fresh masks; dense attention grows approximately quadratically with context. The >=50 proved-token/s target remains unchanged and unachieved.

Research only; no native build/proof/GPU/install/foreign execution, production,
runtime, Git or external messages. Saved reports do not imply user delivery.
