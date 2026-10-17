# Public row expression reuse: small arithmetic saving, no multiplication saving

Cycle 0052, `20261017T022624Z-f3bec81b`, 2026-10-17 UTC. CPU synthetic algebra
and accounting only. No native change, compiled Rust, GPU execution or proof.

Baseline is cycle51's public-axis, suffix-weighted coefficient factory with
2x2 Karatsuba and blocked 3x2 multiplication. `row_graph.py` traces the entire
group-0 coefficient expression using distinct symbolic input identities.
The planner receives public layouts, axis metadata, and input labels; it never
receives witness values or challenge values. Public challenges, prepared
denominators and padding weights are separate runtime slots. Constants in the
source expression may intern; commutative add/mul operand identities may sort.
Subtraction keeps its order. Equality on symbolic values raises an assertion.

Four ablations are checked: previous factory; unoptimized whole-row graph;
graph with common subexpression elimination (CSE); CSE with direct affine
squaring `[a0*a0, a0*a1+a0*a1, a1*a1]`. The direct square replaces the generic
coefficient Karatsuba identity; it does not change Fp2 multiplication itself.
Graph replay is a validation interpreter, not a proposed native dispatch path.
Fixed declared widths, original sample coordinates, suffix weighting, own
group running claims, zero-factor fallback, table folds and finals remain.

Command from the research directory:

```
python3 -B experiments/public-row-cse-20261017/run.py
```

Seed 2026101752; final exit 0. Final process: 24.749455 seconds, 28,664 KiB RSS,
one nice-19 Intel Core Ultra 9 185H thread pinned to CPU 0. Caps: 59 seconds
wall/CPU, 512 MiB address space; wrapper timeout 60 seconds; estimate 64 MiB.
Initial passing run retained under `initial-before-accounting-label-refinement/`.
Python runtime varies on this shared host and is not a native A/B speed result.

100 fixtures / 600 schedules pass 5,832 independent original-cube round
samples and 16,272 ordered direct-MLE finals. Tests cover cube logs 0–3,
two/three remainder limbs, padded/unpadded policies, odd/even lookup counts,
full-extension/zero/Boolean values, chunks 1/3/7, debug/release recovery, and
four small logical-head layouts. A further 256 cases sweep two/three limbs,
one/two probability limbs, lookup counts 1–8, and all eight public-axis
patterns. They pass 1,024 arbitrary extension clause evaluations, 256 raw
graph/previous-factory operation-counter comparisons and 256 zero/random
schema/count comparisons. The independent tuple-ring/cube oracle calls no
candidate arithmetic, cache or fold implementation. 912 recoveries and 636
explicit zero-factor fallbacks occur. Two arithmetic/output mutations are
detected independently. Equal-valued distinct input slots do not qualify as
a structural square; changing one still gives the independent product and
disagrees with an incorrectly reused square.

Illustrative hp16 / kv4 / qh12 / T512 / three-limb census:

| Quantity | Before | After |
|---|---:|---:|
| Counted base products | 4,708,629,913 | 4,708,629,913 |
| Total field API operations | 3,200,298,633 | 3,183,259,278 |
| Fp2 additions | 1,432,399,646 | 1,423,748,897 |
| Fp2 subtractions | 769,392,467 | 761,003,861 |

No Fp2mul or mul_base disappears. CSE alone removes 12,845,052 adds; choosing
the direct square instead adds back 4,194,303 adds but removes 8,388,606 subs.
Combined field API saving is 0.532430%; across six illustrative cases it is
0.529919–0.590470%. These are counts, not weighted runtime fractions or wall
time ceilings. Executed small-fixture deltas are -2,976 adds / -2,688 subs,
zero multiplication changes.

The three public pattern traces visit 1,465 symbolic operators and compile
162 coefficient products. Four structural CSE hits remain after the square
rewrite (one structural square per pattern). Serialized JSON graph storage is
30,268 bytes, compared with 30,460 for raw graphs; this is an actual encoding
size, not native machine code or a compact-IR estimate. Fixed-trace live-word
model rises from 119/121/122 to 120/122/123 including inputs, literals and
outputs. The interpreter retains 590/612/619 words per pattern. Native load
scheduling, registers, spills, code size and peak memory are unknown.
Candidate dispatch still pays 4,194,303 pattern lookups and 1,996,226,061
arithmetic opcode steps; a whole-row interpreter is not a scheduling speedup.

Fourteen proof-local padding-weight multiplications are separately charged
at definition construction. They are not a new optimization: native
`PadTerm::add` already precomputes weights. The scalar port's repeated weight
formation was outside its coefficient counter. The optional `pad_weights`
argument in the local copied bracket makes that existing boundary explicit.

**Scope correction for the next cycle:** these inherited six projections
are illustrative padded scalar formulas, not validated native slot layouts.
In particular, full-head/full-token qh32/T512 has no Ht/S padding. Native
`B::supp` returns `None`, `Gate::at` supplies ONE, and `PadTerm::add` omits
those groups. The inherited padded census still supplies both symbolic gates
and both pad groups. Do not present it as exact Llama-3-8B operation counts.
The qh12 padded example above remains explicitly an illustrative scalar seam.
Next local work must port independent optional support presence before using
this chain to compare actual new trained shapes. Native already omits absent
groups: this is a research-port correction, not a newly found native saving.

Falsification: any extension/cube/final/schema mismatch rejects the rewrite.
Native promotion additionally needs masked/frozen proof bytes, refusals,
challenge/RNG continuation, final/PCS openings and fresh independent receipt
verification. LLVM may already share these expressions; any added dispatch,
code or spill cost exceeding saved adds/subs rejects a speed claim. Demote
whole-row graph compilation as a major optimization; preserve only a small
optional square/helper cleanup for an owner already translating the factory.

Actual seam: read-only `ops/zkp-mvp/sonnet-hardening/hashline/src/private_block/argument.rs`
SC_SZC at 1699, groups 1783, bracket 1788; `zkp-core/src/sumcheck/grouped.rs`
row/part 93, sample 107, reduction 121, recovery 132. Source constants and
optional support/pad semantics are at argument.rs 810 and 929–984. All ten
native/measurement pins match cycle51. Main/Claude owns integration; no merge.

Complete-proof ceiling remains unknown:
`N / (T_complete - saved_add_sub_time + added_compile_dispatch_spill_time)`.
Even removing all SC_SZC caps one historical 125M/T512/one-pass RTX 4070
Laptop whole-test saving at 28.317%; this is not an 8B estimate and cannot be
scaled by the operation count above. Historical clocks and owner priorities
are retained in FINDINGS.md. The slower native fusion negative still stands.

LIVE sources: older [haggies](https://arxiv.org/abs/0907.3714), new assessment
of [Plonky3 compiled components](https://github.com/Plonky3/Plonky3/pull/2292)
and October16 rc.2, and the
[DeepProve softmax exactness boundary](https://github.com/Lagrange-Labs/deep-prove/blob/master/zkml/docs/src/softmax.md).
`sources-cycle52.json` records exact URLs, dates, license scope and failures;
author performance/tests/security claims were not reproduced. No foreign code
was downloaded or executed. Native source snapshots, runner source hashes,
seed, commands, actual exit and logs are retained here.

Accepted independently verified complete private 8B proofs/passes/tokens:
0/0/0. Proof context null; CPU only. Steady/total rates, startup duration and
fraction, witness/proof/serialization/independent-verification clocks,
latency/lag/drain unmeasured. No long-prefill, resident-pass or decode proof.
Larger workloads remain allowed with quadratic attention, fresh masks,
complete coverage and privacy; the >=50/s target is unchanged and unachieved.
