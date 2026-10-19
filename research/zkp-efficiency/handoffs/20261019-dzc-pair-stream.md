# D pair streaming: preserve the schedule, demote the standalone memory case

Research-only, unapplied handoff, cycle0077, 2026-10-19 UTC.

The cycle76 endpoint-coefficient arithmetic candidate remains intact.
`experiments/dzc-pair-stream-20261019/run.py::row(v,p,streamed=True)` computes
the same five complete-D coefficients as its all-denominator schedule and
the captured full Rust D expression. `prior.plan/convert` supply the same
public-role catalog and original evaluation-message conversion.

Candidate location: that new `row` function's `denominator`/helper loop.
Owner integration seam: `hashline/src/private_block/argument.rs::SC_DZC`
and `zkp-core/src/sumcheck/rounds.rs::SumcheckRounds`. No production patch
has been made. The Python Graph objects are instrumentation, not a proposed
native allocation strategy.

For helper k, construct only denominator pairs 2k and 2k+1, consume them in
the original helper relation, and accumulate the weighted coefficient tuple.
The odd final helper remains H*a−1. Keep all catalog order, alias additions,
support, both hosted terms, degree4/5 declaration and full original final
ordering. Convert after coefficient reduction; preserve evaluation-1 recovery.

**Do not port this scheduling change alone as a large memory optimization.**
At current actual unpadded T128 catalogs, derived-buffer peak falls79→18
Fp2 words, but total last-use peak with original endpoints and the accumulator
falls only130→129. Assuming the entire endpoint bank stays resident gives
202→141, a different scope. Generic padded gains do not apply to those actual
catalogs. No register/spill/occupancy/DRAM/native runtime result follows.

Validation: seed2026101977; 30 synthetic fixtures,N2/8/32, actual public
T128 catalogs plus generic branches. 2,145 captured-Rust grid and390 off-grid
values,90messages,1,845original finals,30final relations,30permutations/
aliases;7algebra controls. 246independent source/formula/lifetime checks.
All390row operation censuses identical; all originals/folds retained.
Reference substitutes Shape/Layout and exactu128 field; no native admission,
actual challenge plumbing, transcript/RNG/masks/PCS or privacy gate passed.

More useful next comparator: a public schedule that constructs original
endpoint pairs on first use instead of materializing all59pairs up front.
Use fixed arrays/scalars and an explicit role/alias plan; charge each read,
difference, dispatch, allocation, reduction, original fold and final. First
establish exact same samples and complete logical peak with no hidden
recomputation; then inspect actual native assembly/registers/spills and
enclosing phase clocks under the owner's shared-lock protocol.

Before promotion: actual alpha/g_u8 from this proof; real native shape/layout;
frozen seeded proof bytes, RNG draws and refusals; unchanged extension/mask/
final-opening stages; independent fresh verification and joint-view privacy.
Do not add a private aggregate claim or reuse masks/openings. Falsify on any
divergence, no lower complete lifetime peak, uncharged work or enclosing loss.

The 8B ceiling remains unknown. Deleting every D in the carried1.1B diagnostic
would yield only1.18113×, not an8B estimate. New target proofs/passes/positions
0/0/0; no device or target clocks/rates. ≥50/s on5090/namedhigh-endGPU remains
the unchanged complete-private-stack goal. Main/Claude reviews integration.
