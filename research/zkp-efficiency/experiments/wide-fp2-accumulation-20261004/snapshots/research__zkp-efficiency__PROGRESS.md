# ZKP efficiency progress

Cycle0034 — `20261004T185034Z-0cf2c35e`, checkpoint2026-10-04T19:07:51.986983+00:00.

**No proving speed improvement measured. Row stepping is demoted.** 128 synthetic complete-clause fixtures/768 schedules pass independent original-cube/final-MLE checks and11 negative controls. Final11.575187s/17,332KiB RSS; one pinned low-priority CPU thread,59s/512MiB caps. Forty-eight accounting checks match the previous baseline.

Compared with the compiled plan, illustrated n23/ls3/padded/release stepping removes1.272% of counted scan/fold base multiplications but increases API operations1.325%, adds per-row setup and480B logical scratch per part. Full Fp2 products stay. Counts/synthetic validation establish no native runtime or complete-proof ceiling; GPU/compiler/spill and enclosing costs are unknown.

Five LIVE primary source records saved: newly assessed older Vega with September2026 revision and July implementation bounds, plus qualified SumCATS/NVIDIA/hardware-locality refreshes. Exact dates/licenses/fetch failures retained; no remote commit diff or performance reproduced. [Experiment](experiments/affine-denominator-stepping-20261004/README.md) · [Owner disposition](handoffs/20261004-affine-denominator-stepping.md). Native seam: helper_sum/SC_SZC definition and grouped row/sample loops; immutable shared closure currently lacks per-part row-state hooks. No native patch/build/GPU/merge.

Accepted independently verified complete private8B proofs/passes: **0**; countable tokens: **0**. Device: CPU only; proof context: null; passes:0. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks, proof latency/lag and pipeline drain are unmeasured. No long-context prefill, resident-model passes or decode proof occurred. >=50 proved tokens/s remains unachieved. Larger workloads are allowed; attention can grow quadratically with context. Fresh masks, privacy and full coverage remain required.

Next LOCAL: chunked wide Fp2 dot-product accumulation against independent integer-mod-p reference; prove maximum-value batch bounds and test carry/overflow/zero/ragged/flush failures, charging carry/reduction/scratch costs. OWNER: isolate native denominator/helper/bracket/weight/fold/recovery and both witness/down clocks, then shared-lock masked/frozen/fresh independent-verifier complete-stack A/B. No heavy job is queued.

Reports saved locally do not establish external notification delivery.
