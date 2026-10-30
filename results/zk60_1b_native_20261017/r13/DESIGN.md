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

## Shieldstral extension corner (2026-10-28)

The approved (0,-8) member adds a real endpoint to the group-fold audit. At
base output exponent -13 and base product shift13, its effective direct
product shift is13-8-((-8)-(-13))=0. The exact result is the integer product
(no rounding ambiguity). At aligned remainder shift16, coefficient2^16
gives the same result, including negative values: floor((z*65536+32768)/65536)=z.
The current draft group_folds rejects effective shift0 before the aligned
helper is called. Resolve this explicitly when implementing the Shieldstral
registry; do not silently widen TinyLlama/8B's registry or move a rounding.
One valid positive-denominator representation uses common shift>=1 and
multiplier2 for an otherwise zero-shift clause, then the aligned helper
replaces it by its fixed16/24 denominator. Add independent integer endpoint
vectors for both stacks and recheck every resulting coefficient bound.
This is a construction finding; the new member is not yet enabled natively.

## Lookup census and integration gates

The int12 activation lookup has THREE coordinates (signed gate index,
verifier-derived scaled output, public group id), whereas the legacy ACT
lookup has two. Its padding query must represent the real zero-gate row of
group0; the table padding repeats a valid row and the ACT histogram/helper
support ends at ngroups*4096. Byte/EXP supports remain256.

Do not inherit R12's N+2303 lookup numerator without re-deriving it. The
activation table's true extent and the compression polynomial's group
coordinate affect collision-degree/table terms even when no committed plane
or private claim is added. Derive the actual query/table census from the
built declarations and send its error term to D24 with the freeze.

Before an expensive full native suite after adding modules: run the source
pin partition, hash-call classification and absorb-label census first. R12b
resumption exposed that the older scanners did not automatically include a
public child module or its nested implementation. New R13 modules must be
explicitly classified and scanned; reducing scanner coverage is not a fix.
