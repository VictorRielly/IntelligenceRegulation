# Handoff: mixed public tables preserve grouped sumcheck arithmetic

Cycle0040, `20261012T212555Z-0814839f`. Research-only, unapplied.
**Synthetic conformance passes; no native speed or full-proof result.**

Artifact directory:
`research/zkp-efficiency/experiments/heterogeneous-grouped-driver-20261012/`.
Read its README/result/input-manifest before promotion. Prior generic adapter
handoff: `20261012-heterogeneous-public-driver.md`.

## Interface and patch location

The owner-controlled candidate files remain unchanged:

- `zkp-core/src/sumcheck/grouped.rs`: GroupedEqRounds constructor, immutable
  endpoint reads during round reduction, table binds, original-order finals.
- `hashline/src/private_block/argument.rs`: Tab/Public materialization,
  total/run/census, Bpublic/supp and RS/SZC wiring, verifier public terminals
  and zero-target extension selectors.
- Existing `rounds.rs` / `SumcheckRounds`: keep the generic fallback and the
  transcript/mask/RNG interface unchanged.

Replace the grouped evaluator's concrete dense-table access with an explicit
cube table reader that accepts dense private/equality tables and causal/S/Ht
public descriptors. `driver.rs`, `support.rs`, `causal_mask.rs` are copied
uncompiled sketches from the prior tested Python representation. The NEW
`grouped_adapter.rs` mechanically adapts the pinned native grouped evaluator
for inclusion beside `driver.rs` **in one owner-selected module**, so its
reader/state fields are in scope. `make_adapter.py` documents that derivation.
This serial sketch is **uncompiled/unapplied** and does not prescribe native
parallel thresholds or a production package layout. No patch was merged.

The tested Python `grouped.py` interface takes Tables(n,entries), declared
degree, group(point,start,bracket_degree), bracket(group,row), and chunk size.
Group claims start None; rounds retain actual subgroup polynomials, bind
updates their claims from those polynomials and binds every original table
once. No asserted combined HOST claim is accepted as a group seed.

## Validation obtained

One bounded CPU invocation passes: seed2026101240,14.444178964s,22,808KiB,
one pinned nice19 Core Ultra9 thread,59s and512MiB caps. Thirty-two synthetic
complete SZC fixtures (T1/2/3, ragged/short/padded head/token domains,
26/30 tables, two/three limbs, full-extension/base/Boolean/zero planes) pass
96 mixed grouped schedules and32 dense grouped schedules. Independent tuple
original-cube arithmetic checks2,520 subgroup samples;7,560 candidate
samples/degree checks,1,080 group claims,489 recoveries,375 zero-factor
fallbacks,216 terminal identities,896 independent and2,688 candidate table
finals. Seven generic offset/empty/interior domains pass112 samples.
Extension checks:8,064 table values and288 full scalar polynomials.
Eighteen controls exercise false host/group seeds, wrong point/degree,
causal/Ht/table-order/helper mutations, shape and schedule errors.

Dense and descriptor-backed grouped bracket counts match exactly. The
representation removes public storage/folds while preserving existing grouped
savings. Native initial equality planes remain dense and in the original
table/final order. Eq_Ht remains leading-axis support, constant over j;
future-score/ungated helper and public zero-extension conventions remain.
Fixtures are inconsistent synthetic planes, not honest witnesses or proofs.
Native compilation, masks/RNG/transcripts, verifier refusals, receipts,
device execution and full privacy are **not tested**.

## Costs and acceptance gates

At the conditional m125/T512 head map the three public SZC vectors have
192MiB initial logical payload;12,582,909 dense folds become1,026 descriptor
bind lerps. Reader predicates/dispatch, O(T) causal preparation, allocation,
scratch, compiler and native parallel costs are additional and unmeasured.
RS is sequential: its128MiB cannot be added to SZC peak savings. All private
folds, grouped brackets, split-Eq prep, fresh masks/commitments, PCS, witness,
transfers and independent verification remain. No accepted private8B ceiling
can be computed; complete affected-phase clocks are missing. The historical
8.394s entire RS+SZC envelope is much broader than this change.

Owner gates, under the shared guarded build/heavy protocol:

1. Native descriptor shape/terminal/verifier/refusal tests against dense
   original-cube reference; preserve every original table identity and final
   position, explicit n, admission, support/future-score rules, generic totals,
   extension targets/selectors and census labels.
2. Adapt generic and grouped reader paths without surrendering existing group
   savings. Use the owner's actual SZC masked-transcript oracle. Require
   subgroup and zero-factor parity plus identical mask/RNG/transcript/frozen
   bytes and fresh independent receipt verification.
3. Instrument public build/reader/fold/final times and enclosing clocks/peaks;
   keep compiler/parallel thresholds explicit. Only a complete independently
   verified A/B can establish end-to-end improvement.

Reject semantic/privacy/refusal mismatches, stale descriptors, changed degree
or wire widths, native peak/enclosing regression or added reader/preparation
costs consuming savings. Akita's inspected compressed-round fix is a foreign
compatibility lesson; it does not identify a vulnerability in this project.
No native build, GPU run or heavy queue was launched here.

Next complementary local experiment: per-proof cached split-Eq suffix levels,
pricing construction/retention/free traffic and testing short/offset/zero
supports against the independent cube oracle. Cache public per-proof values
only; fresh private randomness remains mandatory. Owner GPU SZC/recurring
witness priorities remain above that unpriced local refinement.
