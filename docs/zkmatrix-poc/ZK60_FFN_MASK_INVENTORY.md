# Actual FFN mask inventory — source findings and diagnostic follow-up

**2026-09-06:** the round-6 X-at-p2/h16-at-p5 hypothesis is now reproduced
on actual verified FFN proofs. See [the executed diagnostic](ZK60_FFN_MASK_DIAGNOSTIC.md)
for complete tiny-row recovery and T32 linear-functional observations under
P1/P3, public-data replay and controls. The source inventory below is retained
as historical evidence; its statements about the failed round-6 attempt do
not describe the new implementation. Joint A/H/W review remains open.

Read-only Codex investigation at `a118da4`, reviewed during round 6. This
narrows the outstanding Fable audit; **it is not an executed real-FFN
disclosure test or a privacy theorem**. No `zk.rs`/PCS production code changed.
The previously executed isolated singleton diagnostic remains in
`hashline/tests/zk60_mask_rank.rs`; do not confuse it with the cases below.

## Source-derived observations

`zk.rs::build_claims_zk_v3` uses one base-field mask row for each A terminal
plane. `prove_layer_zk_v3` fills those rows with `rng.fp_vec(n)` before A is
committed. H helper claims generally use independent real/imaginary mask
rows; their u rows additionally have a cross-column zero-sum constraint.

Without predicates, **assuming the actual transcript-derived column keys
are distinct where the roles below differ**, the claim inventory is:

| Commitment / role | Claims sharing the role | Mask allocation |
|---|---:|---|
| A at `rho_f` | `7*nb_f` | One base row per f-plane |
| A at `rho_d` | `3*nb_d` | One base row per X/z/rd plane |
| A, X at `p2` | `nb_d` | One base row per X block (`a_mgu`) |
| A, h16 at `p5` | `nb_f` | One base row per h16 block (`a_mdd`) |
| A table multiplicities | 6 | Same-shaped base-field masks |
| H at `rho_f` / `rho_d` | `3*nb_f` / `nb_d` | Real/imaginary mask pairs |
| H zsum / table / sum | 1 / 6 / 1 | u-prime pair / same-shaped pairs / constrained u pair |
| P3 W at `p3` / `p6` | `2*nb_d*nb_f` / `nb_d*nb_f` | One base row per weight block |

This table is a claim-role inventory, not a captured runtime group count.
`pcs.rs::group_zclaims` groups by exact column-weight key (tail, offset,
length), preserving first occurrence. Every part of a claim must have the
same key. `zk_rhos` draws group lambdas and then proximity coefficients
**before** the vectors are absorbed. Analyze that actual code ordering.
`assert_mask_sites` establishes nonzero mask support, not joint base-field rank.

Each A, H and P3 W commitment additionally reserves **one base-field proximity
row**; H's dedicated proximity reservation is not an Fp2 pair. All mask rows
also enter proximity observations. X is used at both `rho_d`
and `p2`; h16 at both `rho_f` and `p5`, with separate masks. H helpers enter
point openings, the LogUp sum and proximity. H's constrained u participates
in its zsum opening, LogUp sum and proximity. Local paired masking alone
does not settle these joint observations, pads or CFS functionals.

## Specific next diagnostic cases

When `nb_d=1`, the X-at-p2 role contains one claim; when `nb_f=1`, h16-at-p5
does too. The existing `zk.rs::tests_v3::synth` T2/d16/f16 fixture with
`log_cols=5` fits an entire such plane into one PCS row. If public verifier
replay confirms distinct singleton groups and nondegenerate coefficients,
their algebra matches the already executed isolated one-base-mask test.
That is a concrete reproduction hypothesis, **not a new executed result**.

At A00's T32/log_cols8 shape, a plane spans two rows, so the same analysis
must retain the row-combination coefficients. It cannot simply be reported
as disclosure of the whole plane. P3's Wd-at-p6 role is another candidate
when `nb_d*nb_f=1`; that observation does not repair or establish model identity.

The attempted implementation worker could not complete the diagnostic because
its tool execution was refused. Its isolated checkout stayed clean. No hook,
partial test, proof artifact, pass count or claimed real-FFN extraction is
included in round 6. The source investigation above was completed separately.

## Fable handoff and acceptance

1. Capture actual verifier-reconstructed claims, approved parameters/root and
   public transcript at A verification. No private witness, unexposed per-row
   pad/full salt tables or RNG state may enter the observer. Public opening
   fields (including folded pad coordinates and sampled salts already exposed
   in `OpeningZk`) are allowed and needed for replay. Any shared-source test hook needs Codex review;
   do not edit Claude-owned `pcs.rs` concurrently.
2. First require complete FFN verification. Reconstruct the exact grouping and
   challenge schedule; cross-check against ordinary PCS verification, including
   sampled indices and final transcript state. Reject unsupported mappings.
3. Test the specific rank/disclosure hypothesis using only authenticated public
   observations. Compare any computed diagnostic output with fixture truth
   **outside** that public-data analysis. Include fresh default randomness and
   degenerate/negative controls; do not silently resample to force a result.
4. Preserve legacy bytes and distinguish tiny diagnostic parameters from the
   deployed profiles. Expand to all joint A/H/W observations before recommending
   a repair. No blanket privacy conclusion from a single passing control.

See [Fable's prioritized queue](ZK60_FABLE_QUEUE.md) and
[A03's existing masking prerequisites](ZK60_PENDING_FFN.md).
