# ZKP efficiency progress

Cycle 0073 — `20261018T022105Z-6cb6453f`, 2026-10-18 UTC.

**No native proving speedup measured.** A base-aware F derived-table builder
passes 120 CPU fixtures and an independent 32-fixture polynomial/fold audit.
For N=2^20 and 11 pad weights, counted scalar products fall from 55,574,528 to
33,554,465 in that constructor. It adds proof-local coefficient preparation
and 176B workspace. Source loads, derived tables and their folds remain.
Main 0.439s including compilation; audit 0.465s; one Core Ultra 9 185H thread,
no GPU. A tiny generic case loses 27 counted products to setup overhead.

Owner round 3 TinyLlama 1.1B at T128, 22 blocks: default 174.052s / warm 216.500s,
both verified in fresh processes, diagnostic 0.735/0.591 positions/s. Even
removing all slot18 build work saves only 0.547%/0.246% of those application
clocks; this candidate changes a subset. Steady throughput and isolated
startup/serialization remain unknown. This is a low-priority
[unapplied handoff](handoffs/20261018-base-aware-derived-build.md).

Carried 8B T128 CPU baseline: 606.598s total, diagnostic 0.211 positions/s.
Seal 105.287s (17.357%) is a phase fraction, not startup. Prove 501.126s includes
rebuilt witnesses; serialization is unisolated. Fresh verifier load 14.126s +
check 43.902s. Trained-shape privacy acceptance remains open.

Six LIVE source records cover SumCATS, extended sumcheck, older GKR array
precombination and current Plonky3 releases/guards/planning. Dates, license
scope and fetch errors are retained. Next: audit D zero-check affine
aggregation with construction/fold costs; its 26.691s default phase is larger.

New target proofs/passes/positions: **0/0/0**. Target steady/total rates,
startup fraction and phase clocks were not measured this cycle; device none.
No long-context prefill, resident series or decode. The >=50/s complete
private 8B high-end-GPU target remains unachieved; fresh-mask/privacy
requirements are unchanged.
[Dated report with clocks, rankings and sources](progress/20261018T022105Z-6cb6453f.md).
Final source check found concurrent owner round4 changes: resident sources
and inline derived construction. Tested round3 snapshots are preserved; the
handoff now requires rebasing on both construction paths. New code is untested
here; round3 ceilings do not transfer automatically.
Saved reports do not establish message delivery.
