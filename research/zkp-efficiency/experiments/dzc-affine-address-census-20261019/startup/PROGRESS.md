# ZKP efficiency progress

Cycle 0082 — `20261019T141854Z-0a847d64`, 2026-10-19 UTC.

**No speed improvement found.** Sharing repeated D helper shapes cuts grouped
function code from 145.7 to 78.4 KB, but adds 634 logical bytes of index reads
per row and leaves the static stack span at 504 bytes. Synthetic CPU row
medians: unique groups 4.543 µs, shared templates 4.658 µs. Only three of nine
pairs favor sharing. Shared-host variation prevents a firm runtime conclusion;
the code-size finding stands.

Six differential fixtures and eight native-path controls pass, including a
compiled wrong-map control. A separate 1,455-check address, ownership and
assembly audit passes six corruption controls. All 59 original tables, folds
and finals remain. Each experiment used one nice-19 Core Ultra 9 185H CPU core
and stayed below 59 seconds and 512 MiB. No GPU work ran.

Six LIVE primary-source records append 442→448: LLVM merging research, its
parameterization patch and current release, plus refreshed zkLLMPoT and zkIE
assessments. Dates, license scope, inspected commit and fetch failures are
retained. No external speedup was reproduced.

[Experiment](experiments/dzc-shared-templates-20261019/README.md),
[handoff](handoffs/20261019-dzc-shared-templates.md),
[dated report](progress/20261019T141854Z-0a847d64.md).
Integration seam: `SC_DZC` / `SumcheckRounds`. Next local check: whether exact
typed pointer offsets can replace public per-load map indices. Owner GPU
measurements and completed resident-model passes remain higher priority.

Carried 8B CPU diagnostic: context 128, 32 blocks, one 16-thread pass, GPU off;
total 471.580 s, proof region 370.137 s including witness 94.021 s and block
loading 17.408 s; sealing 101.279 s; D 44.833 s. Fresh verification 34.587 s
plus loading 11.599 s. Serialization, startup fraction and steady slope remain
unisolated. Deleting all D bounds only this diagnostic at 1.105058×. The
researcher did not reverify receipts.

New target proofs / passes / positions: **0 / 0 / 0**, device none. Target
context, steady-state and total-workload rates, startup fraction, and witness,
proof, serialization and verification clocks are unmeasured. No prefill,
resident-pass series or decode ran. Larger workloads remain allowed; attention
may grow quadratically. The complete private 8B / ≥50 proved positions/s GPU
target remains unchanged and unachieved. No mask or opening reuse, production
changes or external messages. Saved reports do not establish message delivery.
