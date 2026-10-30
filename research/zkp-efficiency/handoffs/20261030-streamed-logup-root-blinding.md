# Review handoff: streamed LogUp root masks and additive public table

Cycle0173, `20261030T214123Z-4c34fc82`. No proving improvement, native proof, Rust patch or privacy
acceptance. [Evidence](../experiments/streamed-logup-root-blinding-20261030/README.md) and
[one-page design note](../experiments/streamed-logup-root-blinding-20261030/ZK_DESIGN_NOTE.md).

The equal-denominator realization `(s,r),(-s,r)` of the coordinator's
cancelling-leaf sketch leaks the quadratic character of hidden D. This is a
counterexample to that realization, not a native vulnerability. Exhaustive
F121 shows TV1 for valid equal-length cases; the full-byte GoldilocksFp2
example confirms opposite characters. A pair `(s,1),(-s*r,r)`, with fresh
uniform nonzero Fp2 r and independent Fp2 s, has exactly uniform nonzero root
denominator after multiplication by any fixed D. Only the root marginal is
proved. All intermediate/leaf claims remain private pending a joint simulator.
Constrain the zero-pair itself: otherwise mask leaves can fix a false identity.
Base-field scales, disclosed/reused scales and `(0,0)` are explicitly negative.

Useful exact table refinement: initialize `Q(0,0)=alpha²`, step b by subtracting
`alpha-a`, and step row starts by subtracting alpha. Full65536entry setup
falls from65536Fp2multiplications to1multiply+65535Fp2subtracts (plus256base
subtractions). All196608entries across3challenges match independently; a
corrupted entry changes the two-leaf root. A parallel per-row version would
cost256multiplies instead of1; no GPU test. The1MiB table, fresh-alpha rebuild,
8logicalB/lookup gathers and every private-GKR cost remain. Final all-in
root construction slower11/12 diagnostic cases; **do not claim speedup**.

Interface: local `query_root(values,alpha,table)` returns PRIVATE `(numerator,
denominator)` plus every layer's arithmetic/byte/buffer ledger. `additive_table`
returns the public effective-alpha keyed array. Neither returns a proof.
`cancelling_pair(field,s,r,mode)` is arithmetic only. Patch/design location:
native private_block H helper generation (`write_h`, `logup_sum_claim`,
`prove_core`), shape/layout H domains, masked argument and ordered original-A
terminal claims. Main toy protocol and frozenR18 shape are pinned separately.
No production change is supplied or authorized; main/Claude reviews/integrates.

Validation: main247337checks/16large+10tiny fixtures/13controls; independent
audit179checks/3extra controls; recurrence196627checks/12roots/4controls.
One nice19CPU; main2.131s/19992KiB; audit0.167s/15400KiB;
recurrence1.730s/20716KiB. No nativeGKR/PCS/CFS/proof verification.

Baseline current helper commit/inverse/open plus constraints. Potential
elimination is recurring H work, not startup. Added masks, all tree reductions,
leaf bindings, new sites, topology/padding, recomputation and verifier costs
are unpriced. Historical30.03/152.2sH attribution and owner54ns/lookup16-thread
law/170B GPU model are not matched Python baselines. Complete8B gain unknown.
Reject any arithmetic/order/multiplicity/whole-table-zero/refusal/privacy
mismatch or all-in added cost>=removed critical work. The native0.7helperCPU
AND equal-bytes kill rule is still unevaluated.

Next local experiment: adapt the existing cycle0109 tiny top-down fraction
layer consumer to an explicit hidden-root/leaf-mask contract. Enumerate every
new layer message, original-A/histogram leaf claim, CFS/Libra mask and opening
group; test its joint-view distribution/rank in a toy field before larger
arrays. Preserve the prior mask-row capacity negative. Main/Claude and the
security owner review the construction; the native owner handles matched
masked receipts and exclusive whole-workload GPU clocks under shared locks.
Do not duplicate D53's Claude GPU-classifier lane or the R14 review.
