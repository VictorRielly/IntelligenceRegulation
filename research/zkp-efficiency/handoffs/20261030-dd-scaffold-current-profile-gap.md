# DD grouping: selected LOW+h24 source gap and full legacy scalar counts

Cycle0170, `20261030T184123Z-46af51dd`. **No measured proving improvement.**
This qualifies the cycle0168/0169 handoffs; it does not supersede their exact
legacy arithmetic evidence with a current-profile validation.

Before porting H103, follow actual dispatch. R14 `argument.rs::define` calls
`accuracy::define_changed` for non-Legacy stacks. That dispatch selects
`argument_accuracy.rs::szc_dd`, ahead of the legacy DD arm. It uses three
`L::Rs` limbs and `precision.score=base.score+12`, six lookups/three helpers.
The native14-terminal census counts private tables only; three Eq tables and
one public causal mask make18 total. The prior15-table/four-lookup/two-helper,
shift1..8 projection is not current LOW/LOW+h24 conformance. A reachable-shift
synthetic host counterexample459779vs99 detects the stale projection.

The actual future seam remains `argument_accuracy.rs::szc_dd -> SlotDef.groups
-> zkp-core/src/sumcheck/grouped.rs::GroupedEqRounds`, with owner R14 whole-slot
mapping retained. Derive its real brackets and degrees from the full selected
source; preserve every original table/fold/final, keyed tuple, range/exp helper,
row-host multiplicity, extension, fresh mask and opening. No subgroup values
may become public. No production patch is applied or merged.

The research [experiment](../experiments/dd-group-scaffold-cost-20261030/README.md)
now counts the previously excluded scalar scaffold of the **legacy** projection.
At n7/span4 expanded base products regress7.65%; at n19/span12 legacy counts
drop26.62%, or16.66% when all group recovery falls back. These are not LOW+h24
counts, compiler instructions or runtime predictions. The complete-model
ceiling remains `N/(T-C+A)`, unknown without actual exclusive clocks and all
added costs. Earlier per-pair scan savings are conditional on recovery and
are not a second additive optimization. H39 interpolation also overlaps.

Both inverse arms replay160 legacy fixtures,3200 round values and4800 finals.
160 inverse arrays include all64zero/eligibility patterns;8negative controls
fire. Standalone original-cube/count/source audit passes11422 checks. One CPU,
main0.519s/24056KiB, finalaudit1.174s/21624KiB; no native proof/GPU/build. Zero
new independently verified complete proofs or proved positions.

Optional, demoted helper:
[inverse_three_factors.rs](../experiments/dd-group-scaffold-cost-20261030/inverse_three_factors.rs)
implements `[Fp2;3] × [bool;3] -> [Option<Fp2>;3]` via base-norm batching.
Prepare all group factors first; only eligible nonzero factors participate,
with original `None` fallback and no challenge resampling. Other group counts
retain their generic path. Uncompiled/unreviewed. At legacy n19 only4410
expanded products are saved against381million counted baseline products;
do not prioritize a standalone port without material inverse-phase clocks.

Next local: differential of the actual18-table accuracy DD polynomial with
multi-limb/precision/helper negative controls, original-cube reference and its
own scan/scaffold census. Next owner: selected-path incidence and exclusive
scan/scaffold/slot/enclosing clocks, then native masked-round/RNG/transcript/
refusal/degree/final/PCS/receipt parity, current privacy gates and fresh
independent full-stack verification under current shared build/heavy locks.
No duplicate R14 freeze/review jobs. Reject any mismatch, changed refusal or
privacy boundary, or added critical cost at least removed cost.
