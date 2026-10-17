# Low-priority bounded pair-helper fallback — cycle0046

`20261013T032555Z-3e60f70b`. Synthetic exactness passes; no native proving
improvement. Refines cycle0004's per-invalid-pair inversion negative.

Interface: private `pair_helper_into(indices,values,public_table,alpha,beta,tag,
h_data,offsets)` in current owner protocol.rs; original zip length retained.
Replace only exp/act construction at908..911, construct/drop a256-entry plan
inside the same proof attempt after challenges. Exact signed index AND public
value match; boundedK1024 batch fallback for all other pairs; direct split-H
writes; short columns bypass setup. Keep later whole-table inversions at941,
histograms, masks/draws/absorbs/commitments/PCS and all proof relations intact.
No externally supplied plan or cross-challenge reciprocal reuse.

Patch location: research-only
[pair_helper_into.proposed.rs](../experiments/lookup-reciprocal-plan-20261013/pair_helper_into.proposed.rs),
uncompiled/unapplied. Native source/report hashes and command/log evidence in
[experiment](../experiments/lookup-reciprocal-plan-20261013/README.md).

203 fixtures/669 schedules/81968 independent helper words,44 modeled attempts,
32 table-helper checks,1601 padded/future words and21 controls pass in0.761940s/
31000KiB RSS, seed2026101346, one CPU thread. Independent Euclidean coefficient
solver plus native-style batch reference; these are synthetic words, not receipts.

Invalid257 pairs:2 inversions atK1024 vs prior258 vs native1;1539 batchmul vs
native771. Sparse fallback pays per occupied input chunk. Current measured
entire helper phase0.197s within16.864s prove/27.523873s test wall bounds its
ideal scope to0.716% test time. Native m125 logical denominator+prefix peak128MiB;
proposed45360B scratch plus2KiB activation conversion, actual peak unmeasured.
H output80MiB and dominant SC_SZC7.794s remain. This is a memory/robustness
option, low priority until actual peak evidence warrants it.

Owner gates: compiled parity for every canonical/off-table/i64/pad/future/zero/
collision case, original zip/refusal/order, cfg(test) hooks and native lengths;
prove partial private H writes die on failure before H commit/any draw/absorb;
no failed-attempt logs exposed, no RNG/mask/receipt/transcript change. D22/D19b/
D23 scopes do not change. Then fresh independent verification/frozen/masked
gates and phase/enclosing/peak A/B under shared locks if useful. No heavy job
queued. Main/Claude reviews and integrates; researcher does not merge.

Next local experiment: source-derived SC_SZC row polynomial coefficients
versus repeated full-extension bracket products, priced against current
compiled denominators including prep/scratch and skipped/debug sample1 plus
zero-factor fallback. Next owner action remains dominant SC_SZC/witness clocks.
