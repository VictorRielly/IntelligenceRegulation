# Conditional owner handoff — fresh Eq complement doubling

Cycle0145, `20261029T145649Z-fb1b89ab`; 2026-10-29T15:10:33.803189+00:00.

Exact component improvement; native gain unmeasured. Interface remains
`eq_table(&[Fp2])->Vec<Fp2>` and `eq_table_msb(&[Fp2])->Vec<Fp2>`.
Candidate: `experiments/fresh-eq-doubling-20261029/candidate.rs`.
Unapplied minimal native diff: `experiments/fresh-eq-doubling-20261029/native-eq-doubling.patch`.
Target: canonical `zkp-core/src/mle.rs::eq_table`, both sequential and Rayon
branches; threshold/MSB wrapper/log0 initialization unchanged. Frozen R13
hashline adapter/Cargo path to this core are pinned. Full-native candidate
file exists only for diff review and has not been compiled.

For one n-coordinate table, let B=2^n-1. Native source performs 2B Fp2
products and n Fp2 complement subtractions; candidate performs B products
and B subtractions. Net added subtractions are B-n. Native Fp2::mul expands
to five base products and two base additions, including multiplication by
constant7; these are source API counts, not compiler instructions. Every
table initialization, reverse-vector allocation/copy, node load and both
stores remain. No private-data read, fresh mask draw, CFS term, commitment,
opening, attention operation or serialization work is removed. There is no
cache, modified challenge distribution, basis change or reduced field width.

Validation passes 234 Eq fixtures, 2,691,054 compared entries, 14,094
independently computed direct weights and 198 independent MLE evaluations;
600 priv_table cases /608,976 output words and600 fresh mask cases also
match. Eight controls detect stale points, MSB/LSB confusion, swapped or
corrupted entries, wrong complement sign, empty behavior and changed input.
Fixtures cover logs0..10/14/17 for Eq, log0..7/13/14 table geometries, zero,
one, alternating Boolean, maximal canonical base/extension values, U,
random base/extension coordinates, coordinate flips/permutations/fixed
coordinates, broadcasts and multi-slice coefficients/offsets.

The references are unchanged extracted R13 priv_table/claim_point/mask_eval,
canonical native field arithmetic and a same-researcher independent literal
coordinate walk / schoolbook-u128 modular product / MSB half-fold. Full Eq
vectors are compared with native serial arithmetic; independent direct
weights cover all entries through log8 and selected entries above that.
Independent full-vector MLE folds cover logs0..10. These are algorithmically
independent checks by one researcher, not independent external/native review.
No native constructor/whole sumcheck/transcript/PCS/refusal/receipt/privacy
suite ran. The unchanged native parallel branch is represented by a serial
iterator adapter; the proposed native Rayon patch has not been compiled.

|8B T128 metadata per block|Sites|Fixed Eq products removed|Mask Eq products removed|PCS data-row Eq products removed (partial)|
|---|---:|---:|---:|---:|
|no DD, f_E9|201|2165|2878263|9027|
|no DD, f_E12/16|204|2165|2927412|9151|
|DD32, f_E9|206|2165|2947890|8733|
|DD32, f_E12/16|209|2165|2997039|8761|

These are inherited/source-checked public catalog counts, not executed
constructors, profile admission, clocks, full model totals or physical
traffic. The original144 census rows reduce to36 distinct geometry/f_E
pairs. No32-layer multiplier is applied. Fixed Eq-only optimization is
demoted by its tiny incidence. Mask Eq is larger and recurring once per
declared site in run_slot's extension loop. All146,930,688..153,742,336
private base-word reads per modeled block remain. PCS row accounting omits
mask log0 table calls and unique column-key Eq; public Tab::Eq, weight folds,
general MLE and grouped-sumcheck Eq, verifier and token stages are uncounted.
No total-prover fraction is inferred.

Owner should first measure exclusive Eq construction inside extension/mask,
private/public table building and PCS grouping, plus full enclosing clocks.
Keep dot products and any parallel overlap separate. If material, apply in
the owned native lane, build under current shared locks, and run unchanged
native oracle/refusal/masked-round/next-challenge/legacy byte/independent
receipt and current privacy gates before matched native A/B. No approval or
heavy job is queued here. Main/Claude decides integration; no merge here.

Falsify on any exactness/order/empty/refusal/randomness/transcript/receipt
change, native compiler equivalence, negligible exclusive share or added
subtraction/scheduling cost erasing enclosing benefit. Do not change field,
challenge distribution or CFS/mask/opening work. No native cache is proposed.

End-to-end ceiling: `N/(T-C_removed_exclusive+A_added)`. With affected
exclusive fraction f and actual native phase ratio k, whole-workload speedup
is `1/((1-f)+f/k)`; neither f nor k is measured here. Even free deletion of
that whole fraction has ceiling `1/(1-f)`. Serial helper ratios and operation
counts cannot supply those missing native terms.

New independently verified full-stack proofs / completed model passes / proved
positions: **0 / 0 / 0**. Actual model context / accelerator: **none**. Research
device: one pinned Intel Core Ultra 9 185H CPU worker, no GPU. Witness, proof,
serialization, verification, startup and initial-prefill clocks, startup
fraction, proof latency/bytes, steady-state and total-workload token rates:
**unmeasured**. No long-context prefill, resident-model proof series or decode
ran. Synthetic helper dimensions are not model contexts or completed passes.
Larger workloads remain permitted; dense attention can grow quadratically
with context. Complete private 8B >=50 proved tokens/s on an RTX 5090 or
another named high-end GPU remains **unachieved**.
