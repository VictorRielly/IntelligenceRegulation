# Heterogeneous grouped public-table driver — cycle 0040

Run `20261012T212555Z-0814839f`, seed **2026101240**, October 12, 2026.
**Synthetic algebra passed; no native proving speed improvement measured.**
Only research files written, excluding runtime. No native build, GPU job,
installation, Git command, production edit or external message was launched.

## Question and measured baseline

Can public causal/S/Ht descriptors replace dense public tables while retaining
the native `GroupedEqRounds` arithmetic, original final-table positions and
its previously measured bracket savings? The previous cycle validated only
the generic closure adapter. Falling back to that generic path would lose
the grouped evaluator's benefit; this cycle tests that compatibility boundary.

Current bottleneck evidence is unchanged and source-pinned in
`input-manifest.json`: historical shared-host synthetic one-block 125M/T512,
two CPU threads, RTX 4070 Laptop b2, RS **0.600 s**, SZC **7.794 s**, proving
**16.864 s**, external witness **5.77 s**, serialization **0.028 s**, in-process
byte verification **0.82 s**, whole test **27.523873283003923 s**. Every sample
paid fresh-process initialization; startup was not isolated. These are
different clocks, not an accepted private8B baseline. The earlier 12-block
GPU diagnostic has no fresh independent verification; interrupted CLI has no
terminal result. Stale running reports are not liveness evidence.

## Experiment and reference

Command, from the research directory:

```text
python3 -B experiments/heterogeneous-grouped-driver-20261012/experiment.py
```

The one invocation passed in **14.444178964 s**, **22,808 KiB** peak RSS,
one pinned nice19 Intel Core Ultra 9 185H thread, Python 3.10.12. Wall/CPU
caps are 59 s, address space 512 MiB; estimated memory 64 MiB. This duration
includes synthetic fixture/oracle/control work, not witness or proving time.
`command.json`, `execution.json`, `run.log`, `result.json` retain the evidence.

Thirty-two seeded source-derived SZC fixtures use contexts 1/2/3, padded token
extent up to 4, padded heads up to 8, cube logarithms 0/2/6/7, 26/30 original
tables, two/three sum limbs and padded supports. Full-extension, base-field,
Boolean and zero planes are deliberately inconsistent synthetic values.
No trained model, real private data, admitted full model or honest witness is
used. The literal source bracket is separate from an expanded-monomial oracle;
the latter uses independently implemented tuple arithmetic and the original
Boolean cube, with no descriptor/fold/cache calls.

The checks passed:

- **96** mixed grouped schedules, chunks 1/3/7, release-style recovery and
  debug explicit validation; **32** additional dense grouped schedules.
- **2,520** independently evaluated subgroup samples, including an extra
  point outside the six-point degree-five interpolation grid; **7,560**
  candidate subgroup sample/degree checks and **720** dense generic samples.
- **1,080** actual per-group claim checks, **489** recovered subgroup samples,
  **375** zero-factor explicit fallbacks, **216** terminal subgroup identities.
- **896** independent table finals and **2,688** mixed-table finals, retaining
  original order. Seven additional offset/empty/interior equality supports
  pass **112** direct original-cube round samples.
- **8,064** independent extension-table checks and **288** expanded extension
  polynomial checks, with public extension targets zero.
- **18** controls detect false combined-host seeds, wrong short equality
  point/degree, causal zero placeholders, Ht replaced by S, reordered tables,
  wrongly support-gated helpers, invalid group extent/degree and schedule errors.

The three native equality groups retain starts/points and separate prefixes.
`Eq_Ht` covers leading head/token coordinates and stays constant over padded
j. Claims begin **None** and are obtained from actual unmasked group rounds;
an asserted combined HOST claim cannot seed them. Zero equality factors are
evaluated explicitly, without changing/resampling challenges. Readers remain
immutable while all parts reduce; each table binds exactly once afterwards.
All six round values and declared degrees survive zero fixtures. Actual
`SumcheckRounds` masking/transcript behavior was not executed or certified.

Initial Rust-sketch generation rejected a legitimate pending `Vec<Vec<Fp2>>`
through an overbroad assertion; this is retained in `sketch-generation.log`.
Source-registration preparation encountered older rows without `id`, then
appended five records once using a corrected schema-tolerant check. Neither
bookkeeping failure was a failed algebra experiment. Previous scientific
negative findings remain unchanged.

## Eliminated work, added costs and ceiling

Baseline for this change is **dense public storage with the existing grouped
evaluator**, not a generic unoptimized sumcheck. Tested dense/mixed grouped
bracket-call counts are identical. In the full-extension 128-row synthetic
fixture each performs **572/318/318** calls across the three groups. The
explicit generic reference uses 762 calls per group; that comparison checks
preservation of an existing optimization and is not a new native speedup.
Three public dense planes require 381 fold lerps in that fixture; descriptors
perform 16 bind lerps, plus 763 reader calls and 1,230 integer predicates.
Reader counts include implementation-specific terminal accesses.

At the pinned m125 head map (12 query/4 KV/16 padded heads), T512 has
4,194,304 data words. Three public SZC planes hold **192 MiB logical field
payload** and **12,582,909** dense folds become **1,026** descriptor bind
lerps. This is conditional allocation/arithmetic accounting, not measured
native peak RSS or admitted larger-context performance. `cost-accounting.json`
retains T512/1024/2048/4096 counts; attention payload grows quadratically.
The separate sequential RS public payload is 128 MiB at T512 and cannot be
added to SZC peak savings. Slot timing dimensions include extension and must
not double the initial data-cube census.

Unchanged: dense private and equality tables, grouped brackets, split-Eq
preparation, sample interpolation, generic private totals, all host/helper/
future-score constraints, witness work, fresh masks/commitments, PCS, transfer,
serialization and independent verification. New costs: typed dispatch,
integer reader predicates, O(T) causal state, support metadata, constructor/
terminal/census/extension/verifier wiring, scratch, compiler/register/allocator
effects and review of native parallel thresholds/reductions. Python timings
cannot price those costs or prove a hardware speedup.

End-to-end ceiling is `Nproved/(Ttotal-Cpublic_build_fold+Cnew)`; the ideal
bound drops only `Cpublic_build_fold`. **Numeric accepted private8B ceiling:
unknown.** Removing both entire historical RS/SZC slots only bounds savings
at 8.394 s on that diagnostic; public storage/fold savings are a subset.
There are no native affected-phase clocks or accepted full8B workload clocks.
Measure public build/read/fold/final and total enclosing time before promotion.

Falsify on any round/subgroup/claim/final/cube/order/degree mismatch, incorrect
short support or future-pair handling, shape/refusal/extension differences,
mask/RNG/transcript/frozen-proof/independent-verification/privacy mismatch,
reader/preparation costs consuming savings, or higher native peak/enclosing
time. A memory reduction alone does not establish >=50 proved tokens/s.

## Ranked hypotheses and integration

| Rank | Hypothesis / scope | Prerequisites, cost and falsification |
|---|---|---|
| 1, owner | GPU SZC plus recurring witness, largest measured remaining scope. | Exact CUDA/memory integration; instrument duplicate witness work. Native masked/frozen/refusal gates, complete independently verified A/B; enclosing or peak regression rejects. |
| 2, owner | Exact full-K split-int16 FFN down. | Packing, two products, i64/requant, workspace/transfers; isolated share unknown. Native range/calibration/device checks and enclosing gain required. |
| 3, tested prior | Four-reduction canonical Fp2. | Arithmetic reduction counts are not time. Canonical callers, carry/register/compiler and masked/receipt checks; no enclosing gain demotes. |
| 4, NEW refined/tested | Mixed public descriptors preserve GroupedEqRounds. | This cycle closes a synthetic compatibility gap. Moderate total/census/extension/verifier/parallel integration; dispatch/predicate overhead unknown. Native mismatch or no enclosing gain rejects. |
| 5, owner | Fresh fixed-context resident complete-pass workload sweep. | Startup/slope/lag/drain, peak memory, context/pass/concurrency and independent verification with fresh masks. Recurring >20ms/new proved position rejects 50/s for that schedule. |
| 6, next local | Cache per-proof split-Eq suffix levels rather than rebuilding each round. | Charge preparation/retention/free traffic; support start/short/zero points and exact original-cube parity. Reuse only public per-proof data; no retained private masks. Negative gain or cache-key mismatch rejects. |
| 7, NEW older architecture filter | deVirgo independent-copy batched sumcheck/PCS. | Independent resident contexts may fit; within-context attention positions are coupled. One-GPU total arithmetic persists; migration, copy-index, PCS, verifier and joint privacy costs. No numeric ceiling; unsupported topology or extra-cost dominance rejects. |
| 8, retained | Compiled denominators, structured PCS, GPU NTT and composition. | Preserve prior small-phase, fusion, projective, cache and privacy negatives. Author/kernel figures do not establish complete-model throughput. |

Native source pins are unchanged. The inspected seam is candidate
`hashline/src/private_block/argument.rs` Tab/build/total/run/census/verifier/
public/support/RS/SZC and `zkp-core/src/sumcheck/grouped.rs` round/fold/finals,
with `rounds.rs` and `SumcheckRounds` interfaces retained. Python is tested.
`grouped_adapter.rs` is an **uncompiled, unapplied serial sketch**, generated
from the pinned grouped evaluator for inclusion beside the copied `driver.rs`
in one owner-selected module. The serial sketch does not prescribe production
parallel scheduling. No production edit, merge or heavy job is queued.

Owner next: native tiny descriptor verifier/terminal/refusal/frozen-byte tests,
then grouped and generic total/census/extension integration with the owner's
actual masked SZC oracle. Preserve admitted shape and all original final
positions/public zero selectors. Only the owner can launch guarded builds
and complete A/B under shared build/heavy locks.

## Source assessment

Five qualified LIVE primary records were appended to `sources.jsonl` (220
total). Queries, dates, licenses, exact URLs and fetch blockers are retained
in `search-log.json` and `source-records.json`. No foreign code executed or
author performance reproduced.

[Akita's equality-factored documentation](https://layerzero-labs.github.io/akita/foundations/eq-factored-sumcheck.html)
distinguishes internal split tables from normalized common-factor messages;
the three-factor native slot keeps its existing equations. Its document date
is unknown. The [v0.1.0-linked validation commit](https://github.com/LayerZero-Labs/akita/commit/029ceceaba879a0d9bf80a47d2e08534e630457d)
was inspected in visible diff portions and pinned, including handling of
empty compressed rounds and typed-verifier controls. The release displays
September9 without a year; commit date is unknown. A separate author release
announcement is explicitly September9 2026 and described a future ZK addition
at publication. It does not establish today's P1/P3 status or model throughput.

[NVIDIA's July15 binary-field report](https://developer.nvidia.com/blog/?p=119649)
and current PTX clmad contract reinforce that carryless/XOR hardware does not
substitute for native Goldilocks2 multiplication. The [monomial benchmark
repository](https://github.com/quangvdao/monomial-sumcheck-benchmarks) separates
preparation from timed kernels; its displayed September4 2026 methodology
history is not live HEAD evidence, license/runtime fetches failed. Neither
benchmark was reproduced.

Newly assessed older [deVirgo/zkBridge (2022)](https://arxiv.org/pdf/2210.00264)
aggregates same-shape independent copies, but its PCS/verification work grows
and its public application does not require zero knowledge. Native private
batching needs a new full cost/privacy derivation. Expander's separate root
and AGPLv3 license were inspected as an architecture reference; no current
code commit or deVirgo implementation lineage was established. Refreshed
Thaler/Fold-DCS/streaming papers were already assessed here and are not
reported as newly discovered work. Fetch failures were recorded, not bypassed.

## Proof accounting

Accepted independently verified complete private8B proofs/passes/tokens: **0**.
CPU only, proof context null, passes0. Steady-state/total-workload throughput,
startup duration/fraction, witness/proof/serialization/independent-verification,
proof latency/lag/drain are **unmeasured**, not inferred from this algebra test.
No long-context prefill, resident-model pass or decode proof occurred.
Target >=50 proved tokens/s is unchanged. Larger workloads remain allowed;
quadratic attention, all complete coverage and fresh masks/privacy obligations
remain. Saved reports are not evidence of message delivery.
