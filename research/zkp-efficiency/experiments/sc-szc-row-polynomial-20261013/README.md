# SC_SZC row coefficients at the original samples

Cycle 0047, run `20261013T042555Z-29e31968`, 2026-10-13 UTC.
**A synthetic arithmetic candidate passes; no proving speed improvement is measured.**

The baseline is cycle 0033's definition-local compiled lookup denominators,
evaluated by the source-derived full SC_SZC bracket at every required sample.
The candidate substitutes each current table value by the polynomial
`cur + X*dif`, computes the padded zero-check group's five coefficients once
per row, and evaluates them at the original integer sample coordinates.
The two small host groups retain their original bracket. Unpadded profiles
retain the baseline. Selection and coefficient lengths depend only on public
expression shape; coefficients are never trimmed by their values.

The convolution's first contribution initializes its output directly. That
assignment depends on loop position, including when the product is zero.
Subsequent contributions add normally. Every coefficient multiplication,
subtraction, addition and base-scalar evaluation is charged. No infinity
sample, new challenge domain, claim, degree or protocol is introduced.

## Completed checks

128 fixtures and 768 schedules pass: 6,912 round samples agree with a separate
tuple-field expanded original-cube oracle and the compiled-denominator baseline;
20,736 final table values agree with direct MLE evaluation. An additional
1,536 arbitrary row-polynomial values include full-extension evaluation points,
100 convolution values use an independent schoolbook extension field, 948
general denominator samples cover empty/multiple terms, aliases and zero,
negative and non-unit coefficients, and 48 loop counts match the retained
cycle 0033 census. Twenty-five convolution counts and an exact clause-body
comparison pass. Ten mutation/lifecycle controls fire.

Fixture dimensions: cube log n=0..3, limb counts 2/3, both pad configurations,
odd/even helper lists, full-extension/base/zero/Boolean values, chunks 1/3/7,
debug and release sample-1 schedules. The schedules exercise 2,112 rows,
1,080 group recoveries and 648 explicit zero-factor fallbacks. Debug explicitly
checks recovered sample 1 against its computed value. Neither zero factors
nor zero lookup denominators introduce a new inverse or refusal here.
These are arbitrary synthetic clauses, not honest native witnesses.

Final experiment: **5.737249 seconds, 17,764 KiB peak RSS**, seed 2026101347,
one nice-19 CPU-0 thread on Intel Core Ultra 9 185H. Limits: 59 seconds wall/CPU,
512 MiB address space, estimated 64 MiB. The wrapper elapsed 5.805758 seconds.
No native build, CUDA, GPU, masks, transcript, proof receipt or fresh verifier ran.
Commands and raw stdout are in `command.json`, `execution.json` and `run.log`;
local source provenance, startup snapshots and native source/log pins are retained.

Reproduce from the research directory:

```text
python3 -B experiments/sc-szc-row-polynomial-20261013/experiment.py
```

## Charged costs and negatives

Illustrative n=23, three limbs, padded, release, nonzero recovery census:

| Literal operation | Compiled baseline | Selective coefficients |
|---|---:|---:|
| Full Fp2 multiply | 2,478,833,399 | 2,118,123,271 |
| Fp2 by base multiply | 398,458,838 | 314,572,765 |
| Fp2 add | 3,305,111,186 | 2,956,983,972 |
| Fp2 subtract | 1,732,247,377 | 1,245,708,155 |

Charging the inspected native multiplication's five base products per full
Fp2 multiplication and two per `mul_base`, **14.944357% of counted base
multiplications and 16.163223% of total field API operations are removed**.
This is operation accounting, not instructions, bandwidth, runtime or an
end-to-end ceiling. The same native mixed-table scan, table interpolation,
folds, equality weights and per-sample weight products are retained in both
census arms. The symbolic-equality fixture driver is a previously validated
local algebra tool; its memory behavior is not the current native driver.

Setup per row: 200 full multiplies, 21 base multiplies, 174 additions and 86
subtractions. Each subsequent nonzero integer sample uses four base multiplies
and four additions for the zero-check group. Row setup is paid again for
every row in every round, not once at workload startup. Coefficient dispatches
fall from 566,230,980 to 251,658,210. Five retained output coefficients use
80 logical bytes per part, **excluding input carriers, expression temporaries,
allocator metadata, registers and spills**. Actual native peak and compiler
elimination are unmeasured. The native implementation should use fixed arrays
and scratch owned by each part, not this prototype's Python object allocations.

Without sample-1 recovery, counted base/API removal is 21.659%/21.680% in the
same padded case. This difference forbids promoting a debug fraction as the
release benefit. Unpadded cases use the baseline and have zero counted saving.
The generalized all-coefficient policy and all 96 census configurations remain
in the result to expose shape-dependent regressions.

`initial-all-coefficients/` preserves the first successful, deliberately naive
version: its padded census removed 13.609% of base products but increased API
work; unpadded recovery cases regressed. Its API denominator omitted fold
subtractions. The final denominator is corrected and independently matches
cycle 0033; do not use the initial API percentage. First-write convolution and
public-shape selection are the substantive refinement.

`failed-leading-coefficient-control/` preserves a real negative-control failure:
removing the declared highest coefficient did not change round zero because
the public causal mask is constant along that first axis. The final control
checks all rounds and detects the mutation later. No sample was deleted and
no private coefficient was inspected to select a degree. The observation
motivates a separate public-dependency experiment, not a protocol change.

## Complete-workload scope and ceiling

The retained native `b2-gpu` diagnostic is synthetic one-block 125M geometry,
T512, one pass, RTX 4070 Laptop 8,188 MiB, driver 566.14, two CPU threads,
shared host. Its whole test elapsed 27.523873 seconds; witness 5.77 seconds;
internal prove 16.864 seconds; encode 0.028 seconds; decode 0.013 seconds;
in-process verifier 0.806 seconds (from bytes about 0.82 seconds);
SC_SZC 7.794 seconds; receipt 40,783,352 bytes. The residual reported as
serialization-and-other is **not** a pure serialization or startup clock.
Startup boundary/fraction and recurring slope are absent. Both witness paths
still need attribution; no independent verification was run in this cycle.

Even deleting that entire SC_SZC phase bounds whole-test savings to 28.317%
for this historical diagnostic. It does not bound a larger resident workload,
different GPU or complete 8B proof. The current hypothesis's complete ceiling is
`N/(T - C_repeated_bracket + C_coefficients + C_horner + C_scratch + C_dispatch)`.
An accepted 8B workload's T and isolated recurring bracket cost are unknown;
no numerical 8B rate or conversion from the 14.94% count into seconds is justified.

The historical twelve-block T512 diagnostic remains 408.609226 seconds total,
318.22 seconds prove-run, 12.15 seconds in-process verification, 484,107,456
receipt bytes, one synthetic pass on RTX 4070 Laptop. Its 1.253 diagnostic
positions/s is not an accepted private 8B rate. The later CLI report remains
nonterminal; its saved `running` label does not establish liveness.

Accepted independently verified complete private 8B proofs/passes/tokens: **0**.
Proof context null, device CPU only this cycle. Steady-state and total-workload
rates, startup duration/fraction, witness/proof/serialization/independent
verification, latency, proof lag and pipeline drain are unmeasured. No
long-context prefill, resident-model pass or decode proof ran. Larger workloads
remain allowed; prefill attention can grow quadratically, decode requires
authenticated growing KV state, and every counted proof needs fresh masks,
full relation coverage and independent verification.

## Integration and ranked questions

Owner source seam: `ops/zkp-mvp/sonnet-hardening/hashline/src/private_block/argument.rs`
SC_SZC definition around 1724/1782, helper near 894; and
`zkp-core/src/sumcheck/grouped.rs` part initialization around 86 and sample loop
around 110. Research patch locations: `coefficients.py`, `candidate.py`,
`polynomial_clause.py` and the row hooks in `row_rounds.py`. No production file
was modified, compiled, integrated or merged. See the
[handoff](../../handoffs/20261013-sc-szc-row-coefficients.md).

| Rank | Hypothesis and expected complete-proof scope | Prerequisites, costs and rejection condition |
|---|---|---|
| 1 owner | GPU SC_SZC and recurring witness work address the dominant measured scope. | High CUDA/memory integration; measure both witness paths and bracket/fold/weight/recovery clocks. Exact masked bytes, native final oracle, fresh independent full-stack verification and enclosing improvement required. Any mismatch, peak failure or slower enclosing run rejects. |
| 2 tested | Selective padded SC_SZC row coefficients reduce repeated products; conditional on native translation. | Moderate additive row factory and prior compiled-denominator plan; per-row convolution/Horner/scratch/dispatch costs counted above. No new privacy claim. Native compiler already eliminating work, transcript/final/refusal mismatch, spill/peak failure or enclosing regression rejects. |
| 3 owner | Exact full-K split-int16 FFN-down attacks recurring witness arithmetic. | Two byte products, packing, i64/requant/refusal/transfer/workspace costs; native down share unknown. Integer/profile/receipt/privacy equality and enclosing gain required. |
| 4 NEW next local | Accumulate suffix-weighted row coefficients before evaluating samples, retaining the same emitted round vector. | Five full weight products per row instead of four/five sample products; per-part coefficient accumulation/reduction/Horner/scratch costs. Current row construction stays charged. Any exact sample/recovery/final mismatch or higher complete field cost rejects. |
| 5 local | Four-reduction Fp2 arithmetic and public Eq/mixed readers remain pending owner gates. | Canonical carry, representation, masking, native peak/register and enclosing A/B validation; earlier wide/SIMD/fusion negatives retained. |
| 6 workload | Fresh fixed-context resident complete passes may amortize startup. | Measure pass/context/concurrency, startup fraction, slope, serialization, lag/drain and independent verification. Recurring complete cost above 20 ms/new proved position falsifies 50/s for that schedule. No mask/opening reuse. |
| 7 demoted | Exact pair inverse fallback remains a bounded memory/robustness candidate. | Phase-only 0.716% prior whole-test ceiling; sparse fallback/setup still cost work. Native refusal/lifetime/peak gates remain. |
| 8 architecture | GKR/MLE lookup/PCS composition might remove more dominant work. | High relation, setup, transcript, joint hiding and whole-proof soundness migration; author's kernel timings are insufficient. |

LIVE searches refreshed the coefficient factory and its wire boundary, the
September monomial benchmark methodology, the extended product-sumcheck paper,
a newly assessed older sumcheck-argument framework and a new October binary
field package. Exact URLs, verified dates, license declarations, uninspected
commit prefixes and access blockers are in `source-records.json`; queries are
in `search-log.json`. Foreign performance remains authors' claims. PDF 403 and
code/commit/license/tag Cache miss/Internal Errors were retained; no bypass,
installation or downloaded execution occurred.

Next local: weighted coefficient accumulation versus this source-pinned hybrid,
with independent original-cube samples, debug/release recovery, zero-factor
fallback, ragged parts, exact ordered finals and full setup/reduction costs.
Owner: compiled native factory, masked/frozen/refusal/extension tests and fresh
independent verifier first; then shared-lock peak/enclosing A/B. No heavy job queued.
