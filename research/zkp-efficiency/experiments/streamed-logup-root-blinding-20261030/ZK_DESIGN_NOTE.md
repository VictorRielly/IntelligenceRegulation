# Root marginal is necessary, not a private GKR construction

For fractions combine `(p,q)+(r,s)=(p*s+r*q,q*s)`. The complete byte
identity has root `(0,D)` with D nonzero and generally dependent on hidden
lookups, even at fixed public length. Publishing D is forbidden here.

The natural cancelling pair `(s,r),(-s,r)` has root `(0,r²)`. For uniform
nonzero r in Fp2, `D*r²` preserves the quadratic character of D. In F121,
two valid lookup cases have disjoint60-element supports, total variation1.
The exact Goldilocks/Fp2 example uses the full public256-entry table and
synthetic private values0/1, with opposite characters. This rejects that
realization, not every possible cancelling-pair construction and not native
code (which never implemented this sketch).

A root-marginal candidate is `(s,1),(-s*r,r)`, with s uniform in Fp2 and
r independent uniform in Fp2 excluding0. It combines to `(0,r)`; adding
it to `(0,D)` gives `(0,D*r)`. Multiplication by any fixed nonzero D is a
bijection of Fp2*, so its denominator is exactly uniform on Fp2*, independent
of D. It is not uniform on the entire field, whose zero is excluded. The
F121 exhaustion has120 outputs, each121times, for both secrets.

This candidate is UNREVIEWED and does not authorize a new native draw or
resampling rule. Define the fresh full-extension-field sampler, bounded
zero handling and complete transcript/refusal schedule for a new profile.
Base-field-only r leaves small cosets. Disclosing r recovers D; reusing r
reveals denominator ratios. Never reuse masks, private openings or scales.

The prover must prove that the two extra leaves cancel and have nonzero
denominators. Otherwise arbitrary leaves cancel a false original identity.
Account for an unbalanced graft versus neutral `(0,1)` padding: a balanced
power-of-two tree can grow to the next power, so two leaves are not
automatically constant-cost inside a frozen layout. This experiment tests
the algebra, not a reviewed topology or soundness theorem.

Every internal numerator/denominator evaluation and sumcheck message still
needs a hiding construction (e.g. an explicitly instantiated Libra/CFS
wrapper), including the joint view with masked PCS openings, salted columns,
root claims and repeated attempts. The earlier mask-per-intermediate row
explosion remains a negative finding. Do not merely attach fresh native
row pairs at every tree terminal and claim a memory win.

Leaves must link to ordered original A limb planes, complete public-table
denominators and committed multiplicities. Reject zero denominators on unused
table entries too. Permuting or deleting matched query/table leaves preserves
the root identity yet changes the proved statement; `(0,0)` passes a weak
cross-product equality. Derive all leaf sites, degrees, mask rows and one
joint opening per commitment (D12), a versioned profile and simulator before
integration. No root, layer claim or mask leaf from this design is proposed
for publication. No whole-proof privacy acceptance follows from this note.
