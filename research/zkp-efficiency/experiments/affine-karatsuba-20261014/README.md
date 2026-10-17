# Fixed affine Karatsuba in the SC_SZC row factory

Cycle0050, run `20261014T203626Z-4afb917a`, seed2026101450. CPU synthetic
algebra and operation accounting only. No native proof, GPU timing, privacy
acceptance or complete8B result. All artifacts use generated public fixtures.

The latest baseline is cycle49's public-axis coefficient factory, following
cycle47's selective convolution and cycle48's weighted coefficient reduction.
Native production still evaluates the original samples: this chain needs owner
translation/review before any benchmark. Current native/measurement files are
read-only snapshots in `native/`, with SHA256 in `native-pins.json`.

For public coefficient widths2x2, replace the four-product convolution with:

```
low   = a0*b0
high  = a1*b1
cross = (a0+a1)*(b0+b1) - low - high
output = [low,cross,high]
```

This is exact over the full Goldilocks quadratic extension. It saves one Fp2
multiply, adds one Fp2 add and two Fp2 subs against schoolbook's4mul+1add.
At the pinned native field API it removes five counted base-product calls and
adds four base subtractions after cancellation of the internal addition
counts. The fifth base product multiplies by the constant7: compiler lowering
can change the instruction benefit. Prior four-reduction arithmetic is a
different, unintegrated candidate and is not stacked into this census.

Selection examines expression widths only. It never tests private values,
zero coefficients, inferred degree or equality of operands. It retains fixed
five-word group0 outputs, all original integer samples, declared degree,
sample1 recovery/zero-factor fallback, table folds and ordered finals. No RNG,
mask schedule, challenge, wire format or private commitment reuse is modeled
or proposed. The harness temporarily switches a module arithmetic strategy
inside one-thread row construction and resets it in `finally`; a native
implementation must use a fixed helper, not this global test mechanism.

Run from the research directory:

```
python3 -B experiments/affine-karatsuba-20261014/run.py
```

`run.py` retains exact argv, source hashes and actual exit code. The executed
process caps wall/CPU at59s, address space512MiB (estimated64MiB), pins one CPU
and runs nice19. It completed in8.321726s with21,972KiB peak RSS on an Intel
Core Ultra9 185H; this is total test runtime, not a proving or speedup clock.
`setup.py` is the one-time startup/provenance collector, not a reproduction
step: it restores copied baseline files and writes an early research state.

100 fixtures,600 schedules (chunks1/3/7, debug/release recovery),5,832
independent original-cube samples and16,272 direct-MLE finals pass. Include
zero,Boolean,full extension,zero-variable,even/odd lookup lists,2/3sigma limbs,
padded/unpadded fallback and four independently enumerated logical-head shapes.
75 public-width convolution cases pass300 independent extension evaluations;
40 arbitrary full-clause extension values and8 identical-zero/random operation
schedule checks pass.600 executed row-census checks confirm the exact operation
delta.876 recovery and672 explicit zero-factor paths execute. Five controls
detect incorrect cross-term sign, dropped cross coefficient, both mistakes in
full round construction, and a value-dependent schedule change. The last
control is an equality-of-counters assertion, not an executed secret branch.

For the illustrative hp16/kv4/qh12/Tpad512/T512/3-limb census:

|Count|Cycle49 baseline|Candidate|
|---|---:|---:|
|Fp2 multiplies|986,447,630|934,543,130|
|Fp2 additions|1,349,824,307|1,401,728,807|
|Fp2 subtractions|604,241,789|708,050,789|
|Base products (literal API)|5,121,506,608|4,861,984,108|
|Total field API operations|3,035,147,955|3,138,956,955|

**Useful negative:**5.0673% fewer counted base products comes with3.4202%
more field API operations,51,904,500 affine rewrites and226,492,362 width
tests in the generic harness. Across six illustrative shape/limb cases,
base-product savings range4.9514–5.1328%, field API increases3.3342–3.4859%.
These are allocation-free extrapolated counts, not model-sized execution or
measured memory/throughput. Width tests can be selected once per public
expression/axis pattern in a native fixed-array factory, but their removal is
not measured. Output remains80 logical bytes per group0 part; named temporary
products/sums, carriers, compiler registers/spills and peak memory are unknown.

Break even only if the saved Fp2 product costs more than the added add plus
two subs and marginal dispatch/scratch costs. No operation-count-to-seconds
conversion is justified. The complete throughput expression remains
`N/(T_complete-C_removed_products+C_added_add_sub_dispatch_scratch)`;
the accepted8B critical-path clocks are absent. Removing the entire historical
SC_SZC slot caps that one-block whole-process wall saving at28.317%; this
candidate affects only part of that slot. It is not an8B bound or50/s estimate.

LIVE source records, date/license/commit scope and exact access failures are
in `sources-cycle50.json` and appended to `../../sources.jsonl`. New older
[HyperPlonk](https://eprint.iacr.org/2022/1355) coefficient multiplication
motivates the narrow test. [October11 Plonky3 release](https://github.com/Plonky3/Plonky3/releases/tag/p3-sumcheck-v0.9.0-rc.1)
and its equality-table/RNG PRs refine scheduling/privacy gates. The
[matched hardware paper](https://arxiv.org/abs/2606.16146) uses simulated
255-bit engines; its timing does not transfer to this GPU/field. ICICLE v4
was checked without a new migration or runtime claim. No downloaded code ran.

Owner seam and acceptance gates: [handoff](../../handoffs/20261014-affine-karatsuba.md).
Next local experiment: fixed public multiplication schedule with3x2 blocked
Karatsuba, charging reduction/subtractions, code size and scratch against this
baseline; reject arithmetic/extension mismatch or a worse weighted cost.
Next owner measurement: row construction versus folds/equality/reduction and
both recurring witness paths, before a guarded enclosing proof A/B.

Accepted independently verified complete private8B proofs/passes/tokens0.
Proof contextnull, CPU only. Steady/total rates, startup duration/fraction,
witness/proof/serialization/independent verification,latency/lag/drain are
unmeasured. No long-context prefill,resident-model pass or decode proof ran.
Larger workloads remain permitted with quadratic attention accounting,fresh
masks and complete coverage. Target>=50/s remains unchanged and unachieved.
