# Owner handoff — suffix-weighted SC_SZC coefficient reduction

Run `20261013T052555Z-bb2755b6`, cycle0048. Exact synthetic candidate; no native
proof/time/privacy result. [Experiment](../experiments/sc-szc-weighted-coefficients-20261013/README.md),
[tested driver](../experiments/sc-szc-weighted-coefficients-20261013/weighted_rounds.py),
[uncompiled fixed-array sketch](../experiments/sc-szc-weighted-coefficients-20261013/weighted_accumulator.rs).
No production modification, integration, merge or heavy job queued.

Prerequisites: cycle33 compiled denominator plan and
[cycle47 row factory](20261013-sc-szc-row-coefficients.md).
Read-only owner seam in ops/zkp-mvp/sonnet-hardening/:
hashline/src/private_block/argument.rs SC_SZC1699/groups1783/adapter553;
zkp-core/src/sumcheck/grouped.rs part93/sample107/reduce121/recovery132.
Actual source snapshots and SHA256 pins are in the experiment native-pins.json.

Add an optional immutable factory `Fn(cur: &[Fp2], dif: &[Fp2]) -> [Fp2;5] + Sync`
for the padded zero-check group. At each row construct coefficients as before,
accumulate `suffix_weight * coefficients[k]` into the group's five part slots.
Keep the two host groups as original sample accumulators and retain all data
interpolation. Reduce coefficient slots with the same componentwise addition.
Convert to original samples0..4 once after complete reduction; retain skipped
sample1 ZERO in release recovery mode, debug computes/checks it, then run
existing recovery and sample5 interpolation. Keep group factors outside this
sum, original pending group values, ordered table folds/finals and final oracle.
Typed coefficients must not reach sample interpolation before conversion.
Dispatch only on public padded profile and half>=2; singleton/unpadded baseline.
No coefficient trimming, new wire, infinity sample, transcript/RNG/degree/mask
change, blinding/opening reuse or cross-proof coefficient/plan reuse.

128 fixtures/1536 schedules,
13,824 independent original-cube samples,41,472 ordered direct-MLE finals,
60 arbitrary weighted-polynomial values,144 executed counter checks and
seven mutation/lifecycle controls pass. Debug/release, ragged1/3/7 parts,
reversed reduction, arbitrary extension/base/zero/Boolean data and challenges,
odd/even helpers, padded/unpadded and zero-factor fallback are covered.
Final10.936208s/20,788KiB, one nice19CPU0 CoreUltra9 thread,
seed2026101348,59s/512MiB caps. Synthetic arbitrary clauses, not native witnesses.

Illustrative n23/ls3/padded/release:1.906537% counted base products and3.413346%
API operations removed vs cycle47 after added4,194,302 full coefficient-weight
products. Horner base products117,440,500 to280; same89,958 modeled part
reduction adds. Group0 output80logical bytes replaces same80sample bytes;
row scratch80bytes retained. Allocator/carriers/flags/registers/spills/peak
and parallel identity reductions unknown. Actual always-on singleton policy
passes algebra but adds one full multiply and one add under recovery; public
fallback prevents that regression. Combined16.565974% base-product count vs
compiled denominators does not predict time.

Native acceptance still requires original/frozen/masked/tagged bytes, honest and
refused witnesses, extension finals, zero-factor challenge behavior, unchanged
RNG/PCS and fresh independent full-stack verification. Then owner measures
factory/weights/Horner/reduction/fold/both witness paths plus peak/registers,
transfers, enclosing cold/warm workloads under shared heavy lock. Reject any
mismatch, hidden-value-dependent selection, peak/spill failure or enclosing
regression. Privacy/soundness acceptance and P3 remain separate obligations.

Historical whole-test phase-removal ceiling28.317% (SC_SZC7.794s inside
27.523873s one-block125M/T512 RTX4070 diagnostic); accepted8B critical-path
costs/rate ceiling unknown. Required accepted rates, startup and phase clocks
remain unmeasured;0new complete8B proofs/tokens. Larger resident workloads
are allowed with fresh masks; prefill and later decode are distinct.

Next local: specialize coefficient factory using only public mask/support
axis dependencies, retaining original samples and fixed declared width.
The main agent/Claude reviews and integrates; this saved handoff is not a
message-delivery claim.
