# ZKP efficiency progress

Cycle 0074 — `20261018T032105Z-8464ee28`, 2026-10-18 UTC.

**No native proving speedup measured.** An affine table plus four bilinear
terms matches D zero-check's eleven clauses in 96 synthetic CPU fixtures,
including 9,840 comparisons with the captured Rust expression. An independent
check passes 1,536 linear coefficients, 96 bilinear coefficients and 396 full
round sums. Main experiment: 3.024 seconds; audit: 0.499 seconds; one Core
Ultra 9 185H CPU thread, no GPU.

The candidate saves counted clause arithmetic after charging preparation,
construction and folds, while adding an 8 MiB table at N=2^19. Original tables
and final checks remain. A small case with a known initial claim loses 63
scalar products. Counts establish no runtime improvement. Even deleting the
entire D phase in the retained 1.1B run would raise diagnostic total throughput
only from 0.735 to 0.869 positions/s; the 8B effect is unknown.

The unapplied [handoff](handoffs/20261018-dzc-affine-aggregate.md) targets
`SC_DZC` and `SumcheckRounds`. Real trained table bindings, native byte/refusal,
RNG/privacy gates and enclosing timings remain. Next: inspect D's actual
lookup, host and final-check dependencies to determine whether the extra
table can avoid any original reads. Owner round 4 device gates pass, but no
new enclosing stack result was credited here.

Carried 8B T128 CPU baseline: one cold pass, 32 blocks, 606.598 seconds total,
diagnostic 0.211 positions/s. Prove 501.126 seconds includes 122.694 seconds
of rebuilt witnesses. Seal 105.287 seconds overlaps loading and witnesses;
its 17.357% share is a phase fraction. Startup and serialization are not
isolated. Fresh verifier: 14.126 seconds load + 43.902 seconds check.

Six LIVE source records cover hardware ZeroCheck, EPFL, Sage, older recursive
GKR training proofs, ROSETTA and Hekate engine releases/privacy analysis.
No drop-in full-stack improvement found. Source dates, license scope and
fetch failures are retained.

New target proofs/passes/positions: **0/0/0**. Target steady/total rates,
startup fraction and witness/proof/serialization/verification clocks remain
unmeasured; device none. No long-context prefill, resident series or decode.
The complete private 8B ≥50-token/s target remains unachieved. Privacy and
fresh-mask requirements are unchanged.

[Dated report](progress/20261018T032105Z-8464ee28.md). Saved reports do not establish delivery.
