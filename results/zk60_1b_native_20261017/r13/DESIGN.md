# R13 implementation notes

Spec: `results/zk60_fidelity_parity_20261019/S2_BUILD_SPEC.json`, received SHA-256
`06f6173b604ea70fc1d6470ca0749ebaefb001bc8b6640e3ae628927f8e5ad1a`.
The isolated `working-tree/` starts from the exact live R12 acceptance source;
compare BASE.json to the R12 frozen manifest before integrating. R12's native
working tree remains fixed while its acceptance runs. No R13 proof exists yet.

Implementation order:

1. Exact scalar rounding and remainder arithmetic, with independent rational
   vectors. Capture the initial failing run before replacing accuracy.rs's
   stubs. Reject invalid shifts and arithmetic overflow explicitly.
2. New profile identities and precision parameters, with old profiles taking
   the original branches. Bind public per-channel multipliers, shifts, group
   IDs and table members in block/statement identities. Require all additional
   arrays for new profiles and refuse them under legacy profiles.
3. Shape/Ids/plane/lookup changes for three-limb norm remainders, int16 norm
   and attention words, c2 matmul remainders, F_P=12, int12 group SiLU, and h24.
   Independently derive plane-domain lists and compare them, retaining the
   existing layout-construction refusal. Removed legacy limbs must not alias
   another plane through an old toy ID.
4. Independent reference kernel, witness and public matrix folds, then every
   affected zero-check/reconstruction/lookup/claim-site path. A multiplier
   scales a public matrix coefficient before requantization; the stored int8
   matrix remains int8. Validate the expanded coefficient bounds for no-wrap.
5. Native export schema and loaders, dense proofs/kernel parity, negative
   controls, actual cost census, existing-profile seeded goldens and retained
   receipt compatibility, full suite, freeze. Claude routes D24 and privacy.

## Exact group scaling

The measured `fp_lib.rx_block` converts each table output into common layer
units **before** rounding the gate-times-up product. Moving that factor into
the down projection after rounding changes the computation in general.
`r13_reference.json` records a concrete counterexample.

Let delta_j = e_out_group(j) - e_out_layer and H = base_sh_h - 8. Then

    h_j = floor(a_j u_j 2^delta_j / 2^H + 1/2).

Use a common product remainder shift R >= max_j(H - delta_j) and public
integer coefficient 2^(R - H + delta_j). This preserves one rounding in the
measured common units. Recount the remainder limbs if R > 8; do not retain the
one-byte cost assumption by changing the computation. R and its coefficients
are public and bound. The independent vectors include delta in [-4,4].

For the gate, absorb per-group input steps into a common denominator in the
same manner: choose G >= max_j(base_sh_g + 8 - 4 + 6 + e_in_group(j) - e_in_layer)
and multiply each channel's c2 numerator by the corresponding power of two.
Check the expanded multiplier class and no-wrap bound, and recount any wider
window. Keep all score positions (including masked positions) range-checked,
as the build spec requests; apply its per-layer score/exp adjustment through
the public calibration rather than weakening that relation.

## Precision must propagate through all consumers

Both shape.rs and layout.rs have a legacy F_P constant. New profiles must
derive it consistently in witness arithmetic, relation coefficients, quotient
range pins and DD dictionary claims. The public SiLU table domain grows to
groups * 4096 rows, and the public group column must participate in the lookup
compression and statement binding. Norm output changes also affect Q/K/V,
gate and up shifts. Profile-gating only the witness would be insufficient.

Cost figures in the incoming spec are COUNTED replicas and MODEL times.
Recount from the final native layout, including any corrected group-product
window; no R13 speed or fidelity measurement is claimed by this design.
