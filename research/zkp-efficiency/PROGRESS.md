# ZKP efficiency progress

Cycle 0062 — `20261017T122624Z-c30acfa0`, completed 2026-10-17 UTC.

**No native speedup established.** The local experiment passed 48 synthetic
fixtures, 23,834 integer comparisons, 12,328 Fp2 checks and 11 negative controls
in 1.050 s / 17,464 KiB on one CPU thread. A separate 235-check audit passed.
The [unapplied patch](experiments/lookup-borrow-catalog-20261017/protocol-candidate.patch)
borrows identity lookup slices. TinyLlama T128 source counts avoid 167.5 MiB
of lookup payload (75.7%); actual peak and runtime gains remain unknown.

New owner GPU-assisted clocks redirect the speed priority: D/F zero-checks
took 25.353/19.484 s, versus softmax 11.834 s. Lookup construction plus
histogram took 0.748 s of a 161.857 s process; deleting the entire mark gives
only 1.005x directly. Borrowing is a capacity candidate. These T128 / 1.1B /
22-block / one-pass phase diagnostics on the RTX 4070 Laptop lack inspected
fresh-process verification and add no credited tokens.

Five LIVE source records were appended. Next local experiment: capture the
actual F zero-check and test public base-constant multiplication shortcuts.
Owner next: native D/F optimization with whole-proof and enclosing clocks.
[Dated report](progress/20261017T122624Z-c30acfa0.md) contains both CPU/GPU phase tables,
all clock limits, rankings and sources; [handoff](handoffs/20261017-borrowed-lookup-columns.md)
contains the capacity candidate's validation gates.

Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Context, steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, latency, lag and drain remain **unmeasured** for that target. Local experiment: one Intel Core Ultra 9 185H CPU thread, CPU0, nice 19; no GPU. No prefill proof, resident-pass sweep or decode ran here. Larger workloads remain allowed with fresh masks; dense attention grows approximately quadratically with context. The >=50 proved-token/s target is unchanged and unachieved.

Research only; no production/runtime/Git/build/proof/GPU/external messages.
Saved reports do not imply user delivery.
