# Public coefficient sums for fresh mask pairs — cycle 0141

Run `20261029T105649Z-8532a02d`, October 29, 2026 UTC.
**Exact local component result; no native proving speedup measured.**

The question is whether preparing the public sums `a+b` once can improve the
prior three-product mask dot when several fresh private pairs share one
equality table. The experiment compiles a small Rust component against the
copied native Goldilocks/Fp2 implementation. It compares the original extracted
`mask_eval`, a cached-public-weight paired3 control, and prepared public sums.
No full native prover or receipt was built or verified.

The control and candidate both accumulate `A += a*x`, `B += b*y`,
`C += (a+b)*(x+y)` and return `(A+7B, C-A-B)`. The candidate stores only
canonical public coefficient sums. It reads every supplied fresh private word
on every call. Nothing is cached across proofs. The installed native evaluator
still uses its original two row dots; prior paired3 and public-tail caching
remain research candidates. Their gains cannot be counted as installed work
or added blindly to this experiment.

| One group of K fresh pairs, N coefficients | Cached paired3 control | Eager prepared sums |
|---|---:|---:|
| Variable products | 3KN | 3KN |
| Public coefficient additions | KN | N |
| Private coefficient additions | KN | KN |
| Private source words read | 2KN | 2KN |
| Extra reads beyond control | 0 | 2N preparation + KN sum reads |
| Extra writes beyond control | 0 | N |
| Extra sum-vector allocations | 0 | 1 |
| Additional live payload | 0 | 8N bytes |

The point copies, exact point comparisons, Eq construction, final arithmetic
and ordinary Eq/private reads remain in both arms. These are source-level
counts, not instructions or physical memory traffic. Preparation and drop are
included in the component timing diagnostics.

The prior source-derived norm4/sigma3/P2 T128 non-DD catalog has 174 pairs
across 33 one-entry tail groups: M = 2,436,096 pair coefficients and
S = 495,872 prepared coefficients. Eager preparation removes 1,940,224 public
additions, but adds 33 allocations, 3,427,840 source reads, 495,872 writes,
and 31,389,696 logical access bytes per block. Maximum added sum payload is
131,072 bytes per active context. The model retains 7,308,288 variable
products and all 4,872,192 private-word reads. This is **not** a census of an
actual admitted R13 LOW+h24 calibration. Counting all group buffers as live
at once would overstate peak payload.

Analytically skipping single-use groups would preserve the addition saving
while reducing this to 17 allocations and 23,001,088 logical access bytes.
That variant was not implemented or timed. A new conditional question asks
whether tiles of two or four pairs could share a sum in registers, avoiding
the buffer at the cost of more accumulators and register pressure. It remains
unimplemented, behind evidence of a material native dot cost.

Validation passed: **792 fixtures / 3,168 terminal comparisons / 9,216
direct-Eq values / ten negative controls**. Row logs 0–8, 13 and 14; private
domains below, equal to and above row width; A/H and differently sized input
and output endpoints; nonzero offsets; fresh changed private data; arbitrary
extension, base, Boolean, zero, maximal and zero-first points. An independent
MSB-fold oracle uses schoolbook extension multiplication and `u128 % p`.
Small Eq tables also use a direct Boolean-cube oracle. This is algorithmic
independence within one researcher, not independent external review.

Controls detect swapped rows, stale private results, changed and reversed
points, short rows, raw wrapping coefficient addition, altered reconstruction
and missing private input. The source/cost audit passes **91 checks, eight
static anchor mutations and eight source pins**. The first audit wrongly
expected mutating one occurrence to remove a duplicated anchor; its failure
is preserved under `initial-audit-anchor-failure/`. The corrected audit mutates
all occurrences. The arithmetic experiment passed on its first run.

The copied field file is unchanged. `baseline_mask.rs` only renames the
extracted native function; its metadata types are small stubs in the harness.
`serial_eq.rs` extracts the native constructors and replaces Rayon iteration
with serial iteration. This does not test native `define`, layout admission,
parallel execution, extension messages, RNG, transcripts, PCS, receipts or
privacy gates.

Probe: **0.199780 s / 8,684 KiB peak RSS**; compile: **0.822278 s / 161,076
KiB**. Seed 202610290141. One pinned CPU0, nice19, Intel Core Ultra 9 185H;
Rust 1.75.0, opt-level1, one codegen unit. Auxiliary compiler OS thread count
was not measured. Per experiment: 40 s CPU cap, 45 s alarm, 50 s parent
timeout, 384 MiB address-space cap; memory estimates 64 MiB harness and
320 MiB compiler. No Cargo, dependencies, GPU or large build.

Five small alternating-order samples per arm/shape are retained in
`result.json`. For N = 16,384, cached/prepared median ratios at K = 1/2/6/17
are **0.9626 / 0.9673 / 1.0203 / 1.0318**. This unquiesced, opt-level1
component diagnostic does not establish a native speedup. It provides no
support for unconditional eager preparation; small differences at higher
reuse need proper owner measurements. Single- and two-use negatives remain.

The complete-workload ceiling is unknown:
`Npositions / (T - C_exclusive_removed + A_added)`. Exclusive costs are absent;
even free deletion of a measured fraction f gives at most `1/(1-f)` speedup.
The older R4 TinyLlama entire extension phase has approximate free-deletion
proving-only bounds 1.116222× CPU / 1.108591× RTX4070 Laptop assisted. This
candidate affects only part of that phase. Those bounds do not transfer to
R13, trained 8B or a high-end GPU.

Reject promotion on any value, support, tail, width, offset, source identity,
order, refusal, RNG, transcript, PCS, receipt or privacy mismatch, or if added
traffic, allocation, register pressure or peak payload removes the enclosing
verified-workload gain. First obtain actual exclusive Eq/dot/extension clocks
and admitted-profile incidence; unconditional preparation is parked.

Reproduce sequentially from the research directory:

```text
python3 experiments/public-mask-component-sums-20261029/prepare.py
python3 experiments/public-mask-component-sums-20261029/run_bounded.py compile
python3 experiments/public-mask-component-sums-20261029/run_bounded.py probe
python3 experiments/public-mask-component-sums-20261029/run_bounded.py audit
```

The audit's copied catalog/count inputs are retained with hashes; it has no
dependency on a foreign repository or production write. `prepare.py` refreshes
all eight native pins; three files provide the compiled components. For a
different source revision, reconcile the copied catalog with the new native
source before accepting its accounting. This cycle used the retained pins,
not a speculative source HEAD.

LIVE primary search screened October StateSync-GKR changes and release scope,
new Akita public-factor grouping documentation, a pinned monomial benchmark
methodology diff, and older finite-field dot/REDQ techniques. Exact URLs,
verified dates, licenses, inspected commit and blockers are in
`sources-cycle.jsonl`. No foreign implementation or author benchmark was run.
The older delayed-reduction bound permits only one maximal canonical
Goldilocks product in u128; a sum of 16,384 needs 142 bits. It does not justify
reusing small-prime packing gains or undoing earlier carry/wide negatives.

New independently verified full-stack proofs / model passes / positions:
**0 / 0 / 0**. Model context and accelerator: **none**. Witness, proof,
serialization, verification, startup/initial-prefill duration and fraction,
proof latency/bytes, steady-state and total-workload rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Larger
workloads remain allowed; dense attention can grow quadratically with context.
The complete private 8B ≥50 proved-token/s high-end-GPU target remains unachieved.

Integration seam: `trained-1b/hashline/src/private_block/argument.rs:405`
and its ordered extension-round mapper near line 618. Compiled helper:
`candidate.rs`. [Review-only handoff](../../handoffs/20261029-public-mask-component-sums.md).
Nothing was applied or merged. Main/Claude reviews and integrates.
