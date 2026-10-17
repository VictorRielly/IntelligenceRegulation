# Progress update — 2026-09-26 PDT / 2026-09-27 UTC

The complete private 8B target remains **at least 50 proved tokens/s on an
RTX 5090 or another named high-end GPU**, with longer workloads permitted.
There is still no complete private 8B GPU throughput measurement.

**Completed:** the native grouped-equality optimization passed all 512 library
tests (17 ignored), earlier receipt compatibility gates, and now all six dense
CPU benchmark runs. The two non-warm samples per version show 37.63 / 36.84 s
before and 34.86 / 33.31 s after, about 8.5% less proving time on average.
The complete softmax phase falls about 18.4%. All receipts verify and remain
40,783,352 bytes. These are one-block synthetic 125M-geometry measurements on
a shared two-thread CPU; warmup times were nearly equal and the sample is
small. They do not establish production, GPU or 8B performance.

**Research:** cycle 0009 completed a 37-case synthetic experiment that fuses
table folding and next-round evaluation. It counts 19.92% less table traffic;
its native runtime benefit is unknown. The standing agenda is now reflected
in the researcher's ranked hypotheses and cycle reports.

**Next:** review and implement the fusion candidate with safe parallel table
ownership, prove equivalence of masks/challenges/receipts, then benchmark the
whole evaluator and block. Commitments still dominate much of the measured
CPU work. Trained 8B integration, larger-profile privacy and actual GPU
validation remain outstanding.

**Reporting:** active work receives progress updates in chat, including new
results and blockers. Background research refreshes this file and adds a
dated report after each hourly cycle. These saved reports do not automatically
send messages to the chat.

Evidence: [audited benchmark summary](../../results/zk60_grouped_rounds_20260926/dense-ab-1/measured-summary.json),
[fusion handoff](handoffs/20260927-grouped-fused-round.md),
[standing agenda](AGENDA.md).
