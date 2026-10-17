# ZKP efficiency progress

Cycle 0031 — `20261004T130146Z-19e7c75c`, checkpoint 2026-10-04T13:20:07.356852+00:00.

**No proving speed improvement measured.** 40 mixed fixtures and 41 exhaustive equality spans, 486 split/adaptive chunk schedules, passed 1,128 independent original-cube samples against 6,768 candidate samples, 2,178 direct-MLE final values, 18,078 counter checks and 12 controls. Final run: 10.406792 s / 18,332 KiB RSS, seed 2026100431, one pinned low-priority Core Ultra 9 185H thread; 59 s wall/CPU and 512 MiB address-space caps.

Two-layer equality accumulation preserves the common data scan and original higher-degree samples/finals in this synthetic gate. An adaptive guard retains ordinary weighting when split weighting would add multiplications. The n23 illustrative count removes 25,079,832 equality-weight multiplications versus a unit-aware baseline, adds 83,904 additions and 176 bytes of logical accumulator payload per parallel part plus metadata. These are counts, not native timing/peak or a complete-proof rate. Expensive brackets, data folds, witnesses, commitments and verification remain. Unconditional chunk1 regression and tiny-case costs are retained.

[Experiment](experiments/split-eq-accumulation-20261004/README.md) · [Owner handoff](handoffs/20261004-split-eq-accumulation.md). Seven qualified LIVE primary records cover sumcheck literature/Jolt source, ICICLE batching API and recent packed-field/Flock revisions. Remote history/full-SHA/raw-source and some PDFs failed; local work was unblocked. No author speed claim reproduced.

Accepted independently verified complete private 8B proofs/passes: **0**; countable tokens: **0**. Device: CPU only; proof context: null; model passes: 0. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks and proof latency/lag/drain are unmeasured. No long-context prefill, resident-model pass or decode proof occurred. >=50 proved tokens/s remains unachieved. Larger workloads are permitted; attention grows quadratically with context, with full coverage, fresh masks and decided privacy preserved.

Next: count the actual source-derived SC_SZC brackets/folds by arithmetic type, then owner isolates native phase costs and validates masked/frozen receipts with independent verification under shared locks. No heavy job queued. These saved reports are local artifacts, not external notification-delivery records.
