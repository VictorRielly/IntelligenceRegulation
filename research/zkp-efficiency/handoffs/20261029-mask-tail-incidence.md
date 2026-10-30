# Broader current-slot public mask-tail weights — research handoff

Run `20261029T075649Z-ff4ec0d7`; cycle0138,2026-10-29 UTC. No native gain.

The concrete seam is `ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs`:
`run_slot`'s extension closure uses `MaskTailWeights` for `n_priv >1` and calls
`mask_eval_cached(sh,p,data,point,&mut weights)`. The original function stays as
the single-site fallback. Patch:
`research/zkp-efficiency/experiments/mask-tail-incidence-20261029/mask-tail-weights.unapplied.patch`.
It is **uncompiled/unapplied**, pinned to argument sha256
`c4f9f9f4cb477346b03e9f769d7c3141a8529f096d08da2be6c415d5160a5e66`.
Eight native source pins and exact in-memory patch-application audit are retained.

The new metadata census covers all23 slots and the optional24th DD slot, checked
against separately parsed `Shape::claim_sites`. At the explicit baseline T128
four-limb class:174 pairs, Eq builds174→33, Eq-constructor products
4,871,844→991,678; all4,872,192 private base-word reads remain. Two-entry LRU
builds29, but up to524,288B rather than262,144B public payload. The one-entry
proposal retains a vector through extension work and adds point copying/exact
comparison/dispatch. Whole-prover peak and time delta unknown. Current R13
LOW/h24/fidelity configurations must rerun the census; these baseline counts
are not such measurements.

Only the actual ordered public Fp2 tail is memoized. c0,cm,pair,width and all
fresh private rows are still read at each original site; no private value,
result, mask, challenge, opening or commitment is shared across proofs. The
cache dies after the slot. SCORE/PV retain two distinct tails/extension families;
later zero extension still rescales terminals. Native dot arithmetic is unchanged,
so this is separate from cycle0137 paired3. No privacy acceptance is asserted.

Validation:22,307 synthetic/model checks,423 fixtures,35 negative controls;
6,270 site comparisons and6,270 independent extension terminals. Separate
audit4,856 checks,57 anchor mutations, all8 native pins, exact patch replay.
Probe2.818003s/26,300KiB; audit0.041339s/20,596KiB; one pinned nice19
CoreUltra9 worker. Rowlogs8/13/14 checks are synthetic row lengths, not contexts.
Native define/refusal/masking/RNG/transcript/PCS/privacy/receipt gates remain.

Owner A/B, when authorized under current shared locks: exclusive Eq constructor,
row-dot, extension, enclosing prove_run/complete workload, allocations and peak
capacity; baseline/single-entry/two-entry separately. Check malformed-slice and
allocation failure schedule too. Falsify on any changed values, ordered terms,
extension schedule, support/refusal, randomness, transcript, PCS/receipt/privacy
failure, compiler-equivalent removed work, bad peak or no enclosing gain.

HistoricalR4 TinyLlama T128/L22 whole-extension free-deletion ceiling is only
~1.109x GPU-assisted prove_run; this cache removes a subset, with no transfer to
8B/R13/high-endGPU. Owner whole-prover GPU and verified resident1/2/4/8 sweeps
remain higher priority. Zero new full-stack proofs or proved positions; all
full-proof clocks and rates unmeasured. Main/Claude reviews/integrates; no merge.
