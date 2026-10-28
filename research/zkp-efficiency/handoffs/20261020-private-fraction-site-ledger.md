# Review-only: ordered U8 fraction-tree sites and native data-point mapping

Run `20261020T171854Z-0041295d`,2026-10-20UTC. **No native private proof or speed improvement.**

Patch location: `experiments/private-fraction-site-ledger-20261020/ledger.py`,
`probe.py`, `validate.py`; no production patch is ready. Interface:
`columns(fixture)` yields symbolic original Lk expressions in order;
`obligations(fixture)` yields(column,domain,ordinal,expression_hash,depth,branch,N/D)
with actual native sites/masks/groups null. `native_child_point(rho_lsb,b)` and
`native_merged_point(rho_lsb,eta)` yield reverse(rho)||b/eta. Only data axes map;
extension axes, real Ids, private claims and new transcript draws remain unbuilt.

Rust seams: frozen R9 private_block/layout.rs::lookups_at/Lk; shape.rs::claim_sites,
slots/totals; argument.rs::lk_tables/helper_sum/claim_point/build_claim/run_slot;
protocol.rs::audit_claims/write_h; zkp-core/mle.rs::eq_table_msb/eval_mle_ext and
sumcheck.rs::CfsMask. All are read-only source pinned in source-pins.json.
An owner adapter must resolve shaped numeric planes and the actual calibration,
keep original ordered expressions, source lifetimes, full table lift/pad rules,
fresh masks and denominator refusal/RNG/draw/absorb order. Never publish raw
tree roots, four evaluations or unmasked cubic rows from this arithmetic test.

The baseline is frozen R9 U8 helper data, carried as420.25MiB nonDD /
390.25MiB DD at8B T128. No native proof work was removed. A reviewed fraction-tree
replacement might eliminate those helpers, but adds every source scan, tree
operation, fold, original-A/table link, mask, CFS functional, PCS group, encoding
and transcript/refusal obligation. Existing per-attempt inverse caching is retained.

This ledger counts **semantic evaluation obligations, not actual PCS sites**.
For the unbatched candidate topology, every layer returns both N,D on both child
branches. At the leaves, looked-U8 numerators are public1; their denominators
depend on ordered original A. The single global256-entry table has private
histogram numerators and public denominators. T128 has166 looked-column branch
links +2 histogram links =168 unmerged original-A obligations. Actual native
Ids, mask pairs, extension rounds, CFS coefficients and opening groups remain
null. These obligations can be reduced only by a separately reviewed protocol,
not by equating equal counts or reusing a private opening.

If **all** private intermediate/leaf terminals each retain a fresh native pair
at the current T128 row width2^14, reserved BASE-field mask rows alone total
1527MiB nonDD /1509MiB DD. Formula: C *2rows *2^14words *8B. Even only168 leaf
sites would add42MiB under that same conditional rule. These are conditional
payload subcosts for a naive contract, not universal lower bounds or measured
peaks. Intermediate fractions are challenge-derived, so appending them to the
original pre-challenge A commitment is not an implementation. New commitment
timing/lifetimes and an integrated masked recursion need their own design.
This rejects the naive all-intermediate native-pair approach as a memory win;
it does not reject GKR generally or establish a net leaf-only saving.

The prior36.022MiB selected-array model still omits private protocol costs and
is not repriced as native memory. If f is the unknown exclusive affected time
fraction, even free deletion has speed ceiling<=1/(1-f), before added costs.
There is no numeric complete-GPU throughput prediction. Falsify on original
binding/exactness/refusal/RNG-order/privacy/soundness drift, omitted capacity,
no relevant device capacity cliff or slower complete workloads.

Main: 2715checks,105 complete tiny layer consumers,420 branch/component
point checks,834 tiny original-A affine-expression links and4 zero-table-lift
cases, up through the native T128 row width2^14. Seventy-seven control instances
cover11 families. Every cubic row, parent claim chain and original MLE terminal
matches independent Boolean-basis arithmetic. Challenges include0/1 and non-base
Goldilocks Fp2. Unmasked arithmetic only; synthetic leaf sizes2..64, depths1..6.

Independent audit: 29703checks; all834 descriptors are reconstructed by a
restricted interpreter of the pinned Rust lookups_at source and its frozen
shift constants, then matched in original order across10 public count fixtures.
It independently checks834 tiny affine links,126 MSB half-fold values, four
saved ledgers and all14 source pins. Three in-memory native descriptor mutations
preserve counts but change the binding and are detected. No external code ran.
The symbolic plane names are not numeric native Ids or captured native claims.
Fixtures use w32/fE9 and frozen requantization shifts; they are not real trained
export captures, and exclude the newer LOW fidelity proposal.

Adjacent children2j+b map from LSB row challenges rho to native MSB
reverse(rho)||b. Merging with an internally supplied eta gives reverse(rho)||eta;
the next consumer's LSB parent point is eta||rho. Eta is only an unmasked
arithmetic fixture, not an approved new native transcript draw. Reversing the
whole point, moving the branch to the front or swapping original sites fails.
Native terminal-extension/mask axes are outside this data-axis adapter.
The table lift requires the product of(1-high_coordinate) over zero-pad axes;
omitting that factor fails. Roots alone still permit wrong ordered-source swaps.

Probe 4.375987s /48304KiB RSS;
audit 1.987379s /37176KiB.
One worker, first allowed core0, nice19,59sCPU/alarm,60sparent,512MiB address
space; estimated64MiB. Intel Core Ultra9 185H /WSL2; no GPU, native build or
dependency install. Seed20261020109; independent audit uses deterministic
source interpretation and saved fixtures. These are diagnostic research clocks.
The first audit failed because its parser searched a comment after stripping
comments; exact logs and script are retained in failed-audit-source-boundary/.
The corrected brace-boundary parser passes. Earlier successful stages and the
refinement to a unique count-preserving site permutation are retained.

Every current obligation identity must survive any batching. A count-preserving
permutation is not a binding; the random merge needs a complete masked protocol
argument, fresh randomness, original-A input consistency, audited CFS functionals,
group counts and one-opening obligations. No existing mask pair/opening may be
reused. The source interpreter is not a native verifier or a soundness proof.
Any new profile changes the accepted privacy/soundness scope and needs review.

Next local: test reversible fraction-tree storage against an independent
immutable native-field tree. Recover both N,D at every layer using preserved
right children, keep source order explicit, and count inversions/batch scratch,
leaf-buffer capacity and avoided rescans. Include zero denominator at zero
multiplicity and original ordered-A terminal checks. The OpenVM source is a
lead, not imported code or a private proof design. Do not revisit a full protocol
replacement until its private input-consistency/claim-reduction design is reviewable.

Owner next: complete GPU phase/capacity clocks, independently verified
fixed-context resident1/2/4/8 workloads, DD context scaling and the all-eleven
FZC compiler A/B under shared build/heavy locks. Retain fresh masking and count
only completed, independently verified full-stack receipts.

Main/Claude reviews and integrates if appropriate; no merge in this lane.
