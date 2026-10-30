# Prover-only dense column preparation — conditional owner handoff

Cycle0146, `20261029T155649Z-9750c59b`. Exact extracted-component result;
**no native proof/runtime/privacy acceptance**. See
[experiment](../experiments/composition-eq-scope-20261029/README.md),
[result](../experiments/composition-eq-scope-20261029/result.json) and
[unapplied patch](../experiments/composition-eq-scope-20261029/native-prover-columns.patch).

Actual seam: frozen R13 `zkp-core/src/pcs.rs:910/1016`, used by current
`private_block/protocol.rs` A/H openings, `run.rs` external endpoints and
the consuming boundary owner. `group_zclaims` constructs dense column weights;
`open_zk` passes groups only to `zk_rhos`, whose loop ignores that tuple field.
Verification requires the dense columns and remains on the original wrapper.

Interface: `group_zclaims_with_columns(&[ZClaim], rows, log_cols, columns)`.
`group_zclaims` delegates with true; `open_zk` alone passes false. Keep the
original tuple shape with empty column Vecs in that prover call. Original
`zpart_weights`, key equality, first-occurrence/member order, row accumulation,
values and all assertions stay byte-for-byte in the helper. Native prover's
mask assertion, challenge/absorb sequence, row folding, paths and store calls
are unchanged. A typed row-only group may be preferable during integration;
it requires its own equivalent validation and is not the tested patch here.

Validation: 162 small fixtures, 662,256 independent full-matrix coefficients,
59,328 synthetic folded values, eight matched-panic cases/eight controls;
four source-descriptor/current-row-sized synthetic grouping+rhos cases.
Thirteen source/model pins and in-memory patch replay pass. Native field and
four unchanged helpers compiled std-only; serial Eq iterator adapter, scripted
Transcript and synthetic row placement are explicit limits. Whole native
patch, actual FS, row-fold backend and receipts were not compiled/executed.

At modeled8BT128, A+H removes45/48 dense column vectors and44/47 Eq builds,
1.092/1.166million source Fp2 products. Counting allocator confirms133/142
calls and19.59/20.90MiB cumulative requests removed; summed retained-column
payload11.25/12MiB is NOT simultaneous peak saving. A/H openings are sequential.
Grouping+rhos+drop serial ratios1.513..2.197 are shared-CPU diagnostics;
private matrix folding and all enclosing work stay. No end-to-end gain inferred.

Eliminated work recurs per proof; this is not resident-model setup amortization.
Added costs: a bool branch/new helper and existing tuple's empty Vec header.
All private rows, pads, masks, salts, commitment/opening schedules and verifier
columns remain fresh and unchanged. No cross-stage/cross-proof cache or
opening reuse is introduced. Generic scheme transfers are invalid: inspected
older Hyrax code uses its column tensor inside the prover's evaluation proof.

Owner first measure exclusive group/Eq/row-fold/open/enclosing time, native
allocator retention and peak. The native compiler may already remove work
that is measurable in extracted code. Keep actual source/profile/calibration
identity. If material, use current shared build/heavy locks for native A/B,
unchanged frozen bytes/RNG/transcript/refusals, multi-thread behavior, native
joint privacy/capture checks and fresh independent full receipt verification.
The researcher launches none of those heavy jobs and does not integrate.

Reject on any coefficient/key/order/refusal/draw/receipt/privacy mismatch,
native compiler zero incidence, extra consumer of columns, no enclosing
workload benefit or worse peak/fit. Native independent review remains owed.
Target ceiling `N/(T-Cexclusive_removed+Aadded)` is unknown. Whole-prover
high-endGPU and independently verified resident1/2/4/8 workloads stay ahead
of this helper in the ranked queue.
