# ZKP efficiency progress

Cycle 0102 complete — `20261020T101854Z-5d2a545a` — 2026-10-20 UTC.

**No proving speed improvement measured.** The public source census finds a
conditional opportunity in small inverse NTTs: at 8B T32/T64, the earlier
sketch halves modeled inverse load requests while leaving the expanded
forward unchanged. Per-row pair requests fall 10% with full-width input or
24.6% with compact input. These are request counts, not memory traffic or time.
At the current T128 layout both phases are outside the guard. The small mask
commitment runs on CPU and receives no benefit from the CUDA sketch.

Completed: 619 independent integer/address checks over 16 lane/profile
entries and 160 role/phase rows; 444 boundaries and nine wrong controls.
Source audit: 933 assertions, 48 fragment mutation controls, 16 unchanged pins.
Final probe: one CPU thread, 3.850 s, 20,620 KiB RSS. No native build or GPU ran.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: none. Witness, proof, serialization,
verification, startup duration/fraction, steady-state and total-workload rates:
**unmeasured**. No long prefill, resident-model pass or decode. The private
8B / >=50 proved tokens/s target remains unachieved.

Seven LIVE primary records added, plus a correction identifying a paper
already assessed in earlier cycles. Caulk+ is a newly screened older source;
its table-size savings have no measured native benefit. Dates, licenses,
commit scope and PDF/commit fetch failures are retained. No author timing
was reproduced.

Next local: count recurring private lookup-helper words and multiplicities
before a LogUp-GKR cost study. Next owner: complete GPU phase clocks and
independently verified resident 1/2/4/8 passes; the all-eleven FZC compiler A/B
remains ahead of the conditional small-NTT sketch. Fresh masking is unchanged.

[Experiment](experiments/pcs-small-ntt-census-20261020/README.md),
[handoff](handoffs/20261020-pcs-small-ntt-census.md),
[dated report](progress/20261020T101854Z-5d2a545a.md).
Saved reports do not establish external message delivery.
