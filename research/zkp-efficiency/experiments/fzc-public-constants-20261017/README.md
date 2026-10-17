# F zero-check: public constants and support factoring

Run `20261017T132624Z-393ef603`, cycle 0063, 2026-10-17 UTC.
Research only; the production source is unchanged.

The complete current `SC_FZC` closure is captured from
`ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs:1635`.
`native-pins.json` identifies the actual lane; the older root `hashline/`
file is not that lane. The standalone harness includes the pinned field,
helper sum, pad term and support gate, with a synthetic F table constructor.
It never loads a model, witness, prompt, private tokens, or RNG state.

Commands, from the research directory:

```sh
python3 experiments/fzc-public-constants-20261017/run.py
python3 experiments/fzc-public-constants-20261017/audit.py
```

Both scripts bind CPU0, set nice19, cap address space at 512 MiB and CPU/wall
at 59 seconds. Standalone `rustc` is std-only, one codegen unit, no Cargo,
dependencies or production build. Actual compile commands are in the results.
Intel Core Ultra 9 185H; no GPU. Compiler version is pinned in `environment.json`.

The reference uses Python arbitrary integers with `u²=7` modulo
`2^64-2^32+1`, independently expresses all four constraints, nine affine
lookup columns, paired/singleton helpers, pad-zero term and two host terms.
It compares baseline, base constants only, support hoist only, and combined.
It tests 480 fixtures including all 336 combinations of seven product shifts,
four gate shifts, two pad branches and six helper-catalog lengths. Values
include full-extension inputs, base-valued inputs, canonical boundaries,
support 0/1 and non-Boolean extension supports. Synthetic ordinary sumcheck
samples use 21 tables of 2,4,8,32 rows, six sample points and folded terminals.
These are polynomial checks, not a masked sumcheck proof.

Result: 2,480 comparisons pass, including 528 aggregated round-sample
comparisons and 32 terminal comparisons. Nine negative controls distinguish
incorrect activation/helper/support/pad/host arithmetic, a wrong helper index
and truncating a challenge coefficient. They detect changed algebra; they
are not native verifier refusal tests. Runtime 1.692 s; Python RSS 17,948 KiB,
compiler child high-water 138,316 KiB. Separate audit: 45 checks in 2.049 s,
Python 19,308 KiB, compiler child 137,956 KiB. All are bounded CPU work.

Executed per-polynomial API counts, measured with a separate instrumented
copy, exclude construction. Nine lookup columns / five helpers:

| Variant | Full Fp2 mul, unpadded | Full Fp2 mul, padded | mul_base |
|---|---:|---:|---:|
| Baseline | 37 | 49 | 9 |
| Base constants | 32 | 44 | 14 |
| Support hoist | 35 | 47 | 9 |
| Combined | 30 | 42 | 14 |

The base change replaces three byte-limb and two shift-constant products
with `mul_base`; it preserves both components of every private value.
The support change replaces `sum_i mu_i*g*f_i` for three inhomogeneous
constraints with `g*sum_i mu_i*f_i`. Lookup and activation helpers remain
ungated, and the pad term and host gates remain intact. Added cost: one
Fp2 accumulator and one extra Fp2 addition, five base-product calls instead
of five general calls; no additional table, transfer or randomness.

The isolated optimized LLVM functions retain fewer multiplication sites
with explicit base types (body plus three l2 helper invocations: 90 -> 75
i128 sites). This is a static proxy; loops, branches and shared helpers
mean it is not an executed instruction count. Closure capture is 296 ->
272 bytes in this harness, not a native memory-peak measurement.

Seven alternating-order CPU microbenchmark repetitions per branch/variant,
8,192 evaluations each; first repetition excluded from median:

| Variant | Unpadded ns/eval | Padded ns/eval |
|---|---:|---:|
| Baseline | 350.54 | 440.47 |
| Base constants | 329.11 | 420.37 |
| Support hoist | 354.03 | 431.20 |
| Combined | 314.69 | 401.24 |

Combined ratio 1.114x / 1.098x. **Negative preserved:** support hoist alone
is 0.990x in the unpadded branch despite fewer API calls. Shared-host sample
ranges overlap; configuration construction, allocation and Python calls are
outside this timing. This establishes a bounded local arithmetic observation,
not a stable native proof, GPU or end-to-end gain.

The earlier trained 1.1B T128 RTX4070Laptop diagnostic charges 19.484 s to
F of 161.857 s process wall. Even deleting that entire phase is only 1.137x;
this patch addresses a subset. The new 8B T32 diagnostics have no F phase
clock, so the specific 8B ceiling is unknown. `owner-accounting.json` records
the new CPU/GPU public clocks without copying private payloads. Native review,
all profile oracles, byte/RNG/transcript/PCS equality, fresh verification,
privacy gates and enclosing workload A/B remain owner work.

`argument-candidate.patch` is review-only and unapplied. The entire candidate
source is retained for inspection, but was not compiled as a production crate.
The two initial harness failures (missing Vec type and library output name)
are retained in separate subdirectories. No failed run is counted as passing.

See the [handoff](../../handoffs/20261017-fzc-public-constants.md) and
[cycle report](../../progress/20261017T132624Z-393ef603.md).

Final source-drift check: the owner changed `layout.rs` and `shape.rs` during
this cycle, adding CS-8 constructor/layout validation methods. The captured
F closure and field/helper code hashes still agree. The original final audit
correctly failed its live-pin assertion; `initial-artifact-audit-failure.json`,
`pin-drift.json` and the exact owner diffs are retained. Kernel evidence remains
bound to the captured source snapshot. This is not approval of the owner
changes; rebase/review and native validation are required before integration.
