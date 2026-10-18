# Unapplied research handoff: D affine aggregate

Cycle0074, run20261018T032105Z-8464ee28. Exact synthetic CPU result; no native
proof/device/runtime claim. Main/Claude owns review and integration.

Baseline seam: current owner
`ops/zkp-mvp/gpu-zerocheck/hashline/src/private_block/argument.rs::SC_DZC`
(closure around1655–1700). F's slot18 has a device descriptor; D's slot14
does not yet share that port. Native driver seam is
`zkp-core/src/sumcheck/rounds.rs::SumcheckRounds` / `ClosureRounds`, called
by `argument.rs::run_slot` and the unchanged masked driver. Source hashes
and snapshots: `experiments/dzc-affine-aggregate-20261018/source-pins.json`.

Prototype patch location:
`experiments/dzc-affine-aggregate-20261018/candidate.py::{prepare,linear,linear_base,combined}`.
No production patch applied. Interface to port:

```text
prepare(original shaped index bindings, mu[0..11], profile constants)
  -> ([(original_table_index, Fp2 coefficient)], Fp2 affine_constant,
      four Fp2 bilinear coefficients)
build(original sources, coefficients, complete base provenance)
  -> proof-local length-N Fp2 L table
round(original interpolated values, interpolated L)
  -> L + a0*gamma_a*x + a1*d*y + a2*gamma_m*x1 + a3*dm*ym
fold(challenge) -> fold L by the same MSB challenge as every original table
finals() -> ORIGINAL table finals only, in original order
```

The four coefficients are mu0*(2Cn_a), -mu0*2^(tn+1),
mu6*(2Cn_m), -mu6*2^(tn+1). Other coefficients and affine constant are
explicit in `prepare`. Reuse original `Ids`/B-returned table bindings and
limb weight vectors; never transplant toy literal indices. Coefficients
depend on transcript challenges and are prepared separately for each proof.
The support factor gates the entire clause aggregate exactly as before;
helper, pad and hosted terms are untouched. Derived L is internal and is
neither a new claimed opening nor a replacement for the original final oracle.

Validation: captured current Rust eleven-clause expression executed with
exact u128 substitute field against independent Python;96fixtures/9,840
clauses plus full enclosing expressions; base constructor1,032values and48
corruption refusals. Independent native-basis audit24fixtures/1,536linear
coefficients/96bilinear coefficients/396full round sums/original-cube finals;
all seven independent corruptions caught. Four/five limbs tested, but five
and all table bindings here are synthetic. Commands/seed/memory/clocks in
experiment README. No real weights, prompts, activations or tokens used.

Net construction matters: four-limb entry33 general or mixed products,
34adds; prepare26mul_base,9adds,20subs; add all N-1 folds. Extra16N+608B
capacity, and original source tables/finals remain. Native step interpolation
needs additions, not a general multiply per evaluation. Current host policy
evaluates first round fully, later rounds recover s(1); preserve inconsistent
witness refusals. Keep declared D4/D5 and all extension/CFS masking work.
Known-initial-claim N2 generic costs484->547 scalar products, a negative case.
At counted2^19/D4/unknown initial claim, clause-only Rust-five-product counts
285,474,332->183,500,687 generic/131,596,175 base; **not timings**.

Expected impact is limited to clause evaluation inside D. All-D deletion on
the carried 1.1B174.052s run removes at most26.691s (1.18113x); actual clause
time is unisolated and8B ceiling unknown. Added scratch can change CPU Rayon
cutoffs, cache occupancy, GPU registers/spills/shared memory and scheduling.
Original lookup/host dependencies may leave all original loads and folds.

Before promotion: real TinyLlama/8B shaped index and lookup catalogs, aliases
and source lifetime/provenance; same round sums, original finals, extension
rounds, transcript/challenge/RNG states and seeded proof bytes; generic,
unsupported-layout and tampered/inconsistent-input refusal parity; fresh
process verification and current privacy gates. Base eligibility cannot
survive extension folds or be based on sampled/private-value pruning. Never
cache L across proofs or reuse private masks/openings. The CPU identity is
not a new privacy proof or accepted P3 private-weight implementation.

Falsify correctness on any original full-polynomial/final/refusal mismatch.
Reject a speed claim if prep/build/folds/transfers/verify/drain erase the
enclosing gain. Profile actual clause time before a large port. First local
follow-up: capture real D catalog and dependency coverage to quantify whether
the added table can avoid any reads without losing helpers/hosts/finals.
