# Heterogeneous public/dense sumcheck driver — cycle 0039

Run `20261012T202555Z-550cccf0`, 2026-10-12. A bounded local integration
experiment; **no native proving speed improvement measured**. The tested code
is Python. `driver.rs`, `support.rs` and `causal_mask.rs` are uncompiled,
unapplied owner sketches. Production source was read and pinned, never edited.

Question: can separate compact public support and causal tables pass through
the same full polynomial driver as dense synthetic private/equality tables,
including generic totals, claim recovery, all rounds, original-order finals
and public zero extensions? This removes the representation barrier left by
cycles 0037/0038. GPU SC_SZC and recurring witness remain the largest measured
owner priorities; their native implementation/device jobs are outside this
research lane's authority.

## Reproduce and scope

`/usr/bin/python3 -B experiments/heterogeneous-public-driver-20261012/experiment.py`
from the research directory. `command.json`, `execution.json` and `run.log`
retain the exact final invocation. Code sets nice19, one pinned available CPU,
59-second CPU/wall limits and a 512-MiB address-space cap. No dependency,
native build or GPU. Estimated memory 64 MiB.

Final result: **20.963668 s, 22,656 KiB peak RSS**, Python3.10.12, Intel Core
Ultra9 185H, CPU0, seed2026101239. Shared-host conformance clock includes
reference/oracle work and is not a native performance A/B. Thirty-two fixtures
cover true contexts1/2/3, padded contexts1/2/4, query heads1/3/6, KVheads1/2,
cube logs0/2/6/7, two/three sum limbs, odd/even helper counts and arbitrary
full-Fp2/base/Boolean/zero values and challenges. These are synthetic algebra
geometries, **not registered/admitted profiles**. The padded equation version
is intentionally exercised even when a fixture's supports are constant one.

- 128 schedules, 384 generic SZC total checks, 720 independently checked SZC
  round samples and 2,880 candidate samples.
- 896 independent original-cube SZC finals, 3,584 candidate finals, 1,440
  descriptor binds, 216 claim recoveries.
- Companion full RS equation: 32 generic totals, 600 independent round
  samples, 160 independent finals.
- 43,008 independent extension-table sample values, 1,536 extension polynomial
  samples and 1,536 public selector/terminal values.
- 24 negative/refusal controls, plus an all-public explicit-cube construction.

The literal complete SZC bracket is a reviewed local copy of the source-derived
port from cycle0036. The independent expanded monomials are separately
constructed; their tuple-field multiplication uses schoolbook convolution.
For every round and integer sample, an independent oracle sums ORIGINAL cube
cells against prefix basis weights and evaluates each Boolean tail. It never
calls candidate readers, binding/folding or sample interpolation. Dense folding
is a third comparison. Original-cube MLEs independently check every terminal.
The RS oracle independently constructs `gs*eq_Ht*(mask*e+lam*zsel)`.
Eq_Ht, max and sum cover leading head/token axes, constant over padded j.

All private planes are seeded, deliberately inconsistent synthetic values.
Host slots start recovery with `None`; later claims come from their actual
unmasked rounds. Generic exact totals can seed private-slot recovery. The
release skip and debug identity paths match the direct samples. Chunk lengths
1/3/7/1024 exercise ragged reductions serially; no real parallel execution is
tested. Two synthetic extension stages have independently evaluated table
targets; public targets remain zero and retain **each** `(1-e)` selector.
No native mask row, generator, transcript or proof receipt is constructed.

Controls detect dense-zero causal placeholders, S replacing Ht, swapped table
order, mutated causal cells, dropped nonlinear clauses, gating lookup helpers,
gating future-score hosts, asserted zero host claims, missing public selectors
and nonzero public extension targets. Extent/state/schedule controls reject
wrong cube, length, identity, indices, premature finals and repeated/missing
round/bind steps. Prior shared-axis Boolean-product, symmetric-point,
row-lift/head-padding, compiler/API inflation, slower native fusion and privacy
negative findings remain in their original artifacts.

Initial passing run/source is retained under
`initial-before-RS-and-extension-oracles/`. The refinement changes Eq_Ht from a
generic short equality span to the actual Ht axis span and adds RS/independent
extension-table checks. An indentation error in that edit is retained under
`extension-oracle-edit-syntax-error/`; it produced no result. The corrected
final run passed. Repetition was for added coverage, not timing selection.

## Baseline, removed work, costs and ceiling

Current native `Tab`, builders, total and Closure/Grouped rounds materialize
public vectors and infer the cube from `tables[0].len()`. This experiment uses
an explicit dimension and preserves every original table position. Reads are
immutable during part scans; every table binds **once after reduction**. Dense
private/equality tables continue ordinary MSB half-split folding. Support and
causal tables remain separate polynomials, including off-domain evaluations.

At the pinned m125 map (12 query heads, 4 KVheads, 16 padded heads), T512 has
N=4,194,304 initial data words. **Three SZC public planes contain 192 MiB
logical payload**; two RS public planes contain 128 MiB. Within SZC, dense
public folds are 12,582,909 interpolations; descriptor binds are 1,026
(1,022 causal plus4 support). Logical transient field payload upper bound is
24,768 B, excluding objects/metadata/Vec capacities/allocator. The two slots
are sequential: their peak savings must not be added. Timing-table cube sizes
include public extension; that does not double the initial table census.

SZC is a HOST: no generic initial total is charged there. Its proposed public
round reads are at most25,165,818 endpoint calls, including at most16,777,212
support integer comparisons. RS is PRIVATE and adds its generic total scan;
its public total-plus-round reads are at most25,165,820. Common polynomial
sample interpolation remains. These are logical counts, **not machine
instructions, traffic, measured peaks or runtime reductions**. Larger
contexts have quadratic N; details are in `cost-accounting.json`.

Added costs: typed dispatch, integer predicates, O(T) causal construction and
binding/drop, support state/axis metadata, row scratch and complete
total/final/verifier/extension/census adapters. Native compiler inlining,
branch/memory behavior, register pressure, parallel scheduling and peaks are
unknown. No enclosing numeric speed forecast is warranted.

Historical bottleneck: shared-host synthetic one-block125M/T512 RTX4070Laptop,
two CPU threads; RS0.600 s and SZC7.794 s inside16.864 s proving; external
witness5.77 s, serialization0.028 s, in-process byte verification0.82 s,
whole test27.523873 s. Removing BOTH ENTIRE slots could subtract at most
8.394 s from that diagnostic. This candidate only affects a subset, and no
accepted private8B baseline or isolated public-table clocks exist.

Complete ceiling: `Nproved/(Ttotal-Cpublic_build_fold+Cnew)`; ideal upper
bound `Nproved/(Ttotal-Cpublic_build_fold)`. Falsify on any field/round/final,
original cube/order/degree, support/future-score, extension/refusal,
mask/RNG/transcript/receipt/privacy mismatch; loss of shape admission; extra
reader/dispatch costs consuming savings; native peak or enclosing regression.

## Native owner seam and unresolved checks

Read-only source pins and snapshots: `native-manifest.json`, `native/`.
Primary seam is candidate `hashline/src/private_block/argument.rs`: `Tab`66,
table construction338, total406, `run_slot`447, census512, verifier613,
`B::public`716, `B::supp`810, causal1013, RS1265, SZC1699. Shared seam:
`zkp-core/src/sumcheck/rounds.rs` Closure52/round94/fold152/finals170 and
`grouped.rs` round99/fold149/finals175. Exact lines can move; pins define
the inspected source.

`driver.rs` proposes an explicit-dimension table enum and a serial additive
SumcheckRounds adapter. It requires its two descriptor modules and existing
Fp2/interpolation. Owner must preserve admission/carries_pad_rule/pads gates,
table/final/private-term counts, generic claimed totals, census labels,
extension targets and verifier reconstruction. **GroupedEqRounds remains
unadapted and untested**: private/masked/native evidence is owed; preserve the
group polynomial and all original equality table/final positions rather than
silently substituting the slower generic fallback. No production patch/merge.

Next owner: admitted-shape descriptor verifier/terminal/refusal/frozen bytes,
then native Closure/Grouped/total/census/extension integration with the owned
actual SC_SZC masked-transcript oracle. Instrument public construction,
reader/dispatch, fold and final shares; guarded complete independently verified
A/B follows only within owner shared build/heavy locks. No heavy job queued.
Next local: complementary heterogeneous GroupedEqRounds with original-cube
oracle, per-group recovery, zero equality factors and false asserted hosts.

## Primary literature/repository search

Six LIVE records with access/date/license/commit qualifications are in
`source-records.json` and appended once to research `sources.jsonl`; exact
queries and fetch blockers in `search-log.json`. No author performance was
reproduced and no foreign code was executed.

[Jolt September standalone sumcheck](https://github.com/a16z/jolt/pull/1865)
and [proposed symbolic/concrete spec](https://github.com/a16z/jolt/blob/main/specs/symbolic-sumcheck.md)
inform interface/terminal/transcript obligations. [Efficient Sumcheck custom
fields](https://github.com/compsec-epfl/efficient-sumcheck/blob/main/docs/compatibility.md)
offers a potential owner oracle, with an unaudited representation contract.
[Formal sumcheck verification (2024)](https://arxiv.org/abs/2402.06093)
motivates explicit arity/degree/evaluation obligations; no formal checker ran.
Newly assessed older [Sparrow (2024)](https://eprint.iacr.org/2024/1631) enters
the architecture queue; full protocol/code access failed and applicability to
this private transformer topology is unresolved. The [displayed Jolt release](https://github.com/a16z/jolt/releases)
has no verified year; linked memory PR916 is explicitly August26 **2025**.
No new commit diff was fetched/inspected; exposed short hashes are not pins.

## Proof accounting

Accepted independently verified complete private8B proofs/passes/tokens: **0**.
Device CPU only; proof context null; passes0. Steady-state and total-workload
rates, startup duration/fraction, witness/proof/serialization/independent-
verification, proof latency/lag/drain clocks are all unmeasured. No long-context
prefill, resident-model pass or decode proof occurred. Target>=50 proved
tokens/s unchanged; larger workloads allowed, fresh masks and full privacy/
coverage required. This research cycle establishes synthetic algebra only.
