# ZKP efficiency progress

Cycle 0040 — `20261012T212555Z-0814839f`, checkpoint 2026-10-12T21:38:13.733244+00:00.

**Compact public tables preserve grouped sumcheck arithmetic in synthetic
checks; no native proving speed improvement was measured.** One bounded run
passed in 14.44 seconds and 22,808 KiB RSS on one low-priority Core Ultra 9 CPU
thread. Thirty-two fixtures pass 96 mixed grouped and 32 dense grouped schedules,
2,520 independent subgroup samples,375 zero-factor fallbacks,18 controls and
original table finals/extensions. Deliberately inconsistent seeded planes,
short/offset equality support and actual per-group claims were checked against
independent original-cube tuple arithmetic; no masks or full proofs were run.

The new adapter retains the existing grouped bracket-call savings. At the
conditional m125/T512 head map three public planes hold 192 MiB logical payload;
12,582,909 dense folds become 1,026 descriptor binds. Dispatch/predicate,
constructor/compiler/parallel and native peak/enclosing costs remain unknown.
The historical RS+SZC envelope is 8.394 seconds within 16.864 seconds proving for
one synthetic 125M block on RTX 4070 Laptop; this candidate affects a subset.
That result cannot establish complete private 8B throughput.

[Experiment](experiments/heterogeneous-grouped-driver-20261012/README.md) and
[owner handoff](handoffs/20261012-heterogeneous-grouped-driver.md) retain tested
Python and uncompiled/unapplied Rust sketches. Five LIVE primary records were
appended (220 total): mixed-factor Akita/inspected release validation commit,
NVIDIA binary-field ISA scope, benchmark preparation boundaries and newly
assessed older deVirgo batching/privacy costs. Dates/licenses/commit limits
and fetch blockers are retained. No author performance reproduced. Two
bookkeeping failures are logged; the algebra experiment passed on its first
invocation. No production edit, build, GPU job, installation, Git or heavy job.

Accepted independently verified complete private 8B proofs/passes/tokens: **0**.
Device CPU only, proof context null, passes 0. Steady-state/total-workload rates,
startup seconds/fraction, witness/proof/serialization/independent-verification
and proof latency/lag/drain clocks are unmeasured. No long-context prefill,
resident-model pass or decode proof. >=50 proved tokens/s unchanged; larger
workloads allowed, quadratic attention and fresh masks/full privacy required.

Next local: per-proof split-Eq suffix-cache preparation/storage accounting and
original-cube checks for short/offset/zero supports. Next owner: native
masked/verifier/refusal/frozen-byte gates at GroupedEqRounds and argument.rs,
then isolate public build/reader/fold/final clocks before guarded complete
independently verified A/B. Saved reports do not imply notification delivery.
