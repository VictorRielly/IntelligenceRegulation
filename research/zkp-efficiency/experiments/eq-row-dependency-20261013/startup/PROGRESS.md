# ZKP efficiency progress

Cycle 0043 — `20261013T002555Z-f0cb53eb`, checkpoint 2026-10-13T00:40:23.033243+00:00 UTC.

**Compact private softmax tables pass synthetic checks. No native speed gain
was measured.** The experiment covered 32 fixtures and 96 schedules, with
independent cube, round, final-opening and private-extension checks. All 24
negative controls passed. Validation took 14.269 seconds and 22,220 KiB RSS
on one low-priority Core Ultra 9 CPU thread. A separate source-construction
check passed 4,590 cell checks and 270 finals.

At the conditional 512-token reference geometry, two private tables require
0.25 MiB instead of 128 MiB of logical storage, and 16,382 instead of
8,388,606 folds. Bracket scans remain; compact access adds index and dispatch
work. These counts establish neither native peak memory nor proving speed.
The affected phase needs timing before promotion.

[Experiment](experiments/compact-private-grouped-20261013/README.md) and
[handoff](handoffs/20261013-compact-private-grouped.md) retain commands, seeds,
source hashes, logs and the uncompiled Rust helper. The integration seam is
native private-table construction and grouped reads, binding and finals.

LIVE searches covered Plonky3, ICICLE, product sumcheck time-space tradeoffs
and older regular-circuit proofs. Four source records were added; publication,
license, commit-inspection limits and failed fetches are recorded.

Accepted complete private 8B proofs and counted tokens: **0**. Proof context:
none; passes: 0; device: CPU only. Steady-state and total-workload rates,
startup duration/fraction, witness, proof, serialization and independent
verification clocks remain unmeasured. No prefill, resident pass or decode
proof ran. The 50-token/s target and privacy requirements remain unchanged.

Next local test: omit unused equality-table reads in the current grouped
adapter while preserving original finals and extensions. The owner still
needs native masked-proof gates and affected-phase, enclosing and peak-memory
measurements. Production and runtime remain untouched; no heavy job queued.
Saved reports do not establish notification delivery.
