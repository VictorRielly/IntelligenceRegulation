# ZKP efficiency progress

Cycle 0039 — `20261012T202555Z-550cccf0`, checkpoint 2026-10-12T20:42:14.114804+00:00.

**The mixed public/dense sumcheck driver passed synthetic checks; no native
proving speed improvement was measured.** The final experiment took 20.96
seconds and 22,656 KiB peak RSS on one low-priority Core Ultra 9 CPU thread.
Across 32 fixtures and 128 schedules, it matched dense folding and independent
original-cube evaluation. Checks covered the full source-derived softmax,
lookup, host and padding equations, companion row sums, 43,008 extension-table
values and 24 negative/refusal controls. All planes were seeded synthetic
inconsistent values. The initial passing run and an edit syntax failure are
retained; the final correction passed.

The driver carries its cube size explicitly, preserves table order and public
extension selectors, and keeps causal/S/Ht polynomials separate. At the pinned
512-token m125 head map, three SZC public planes account for 192 MiB of logical
payload; 12,582,909 dense folds become 1,026 descriptor binds. Added reader and
dispatch costs, native peaks and total proving gain remain unmeasured. These
counts cannot establish 50 proved tokens/s. GPU softmax and recurring witness
remain the highest measured owner priorities.

[Experiment and unapplied Rust sketches](experiments/heterogeneous-public-driver-20261012/README.md)
and [owner handoff](handoffs/20261012-heterogeneous-public-driver.md) are saved.
Six LIVE primary records include September Jolt interface work and newly
assessed older formal sumcheck/Sparrow techniques. Dates, licenses, commit
qualifications and fetch blockers are retained; no author performance was
reproduced. Native source and measurement pins are unchanged. No production
edit, build, GPU or heavy job was launched.

Accepted independently verified complete private 8B proofs/passes/tokens: **0**.
Device: CPU only; proof context: null; passes: 0. Steady-state and total-workload
rates, startup seconds/fraction, witness/proof/serialization/independent-
verification and latency/lag/drain clocks are unmeasured. No long-context
prefill, resident pass or decode proof occurred. The >=50 proved-token/s target
stands, with larger workloads allowed, quadratic attention and fresh masks,
full privacy and coverage required.

Next local test: heterogeneous grouped evaluator with independent samples,
actual per-group claim recovery, zero factors and inconsistent-host controls.
Next owner step: native masked/verifier/refusal/frozen-byte checks, then total,
Closure/Grouped, census and extension integration; isolate public-table clocks
before a guarded, independently verified complete A/B. Saved reports do not
imply message delivery.
