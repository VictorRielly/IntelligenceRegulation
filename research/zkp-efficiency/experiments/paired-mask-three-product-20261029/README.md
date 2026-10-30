# Three-product reserved-mask-pair dot — cycle 0137

Run `20261029T065649Z-ae3c483b`, 2026-10-29 UTC. **Algebraic model passes;
no native proving improvement measured.** This experiment targets the existing
`trained-1b/hashline/src/private_block/argument.rs::mask_eval` seam. It does
not change the private 8B ≥50 proved-token/s target or its workload definition.

The baseline separately evaluates the two fresh base-field reserved mask rows
against one public Fp2 equality table, then combines their results with U,
where U²=7. With equality coefficient `(a,b)` and original row words `(x,y)`,
its paired dot requires four variable products per coefficient.
The new question is whether linearity permits three dot accumulators with
only one final cross reconstruction. Earlier scalar Fp2 Karatsuba, wide-u192
accumulation and four-reduction MAC experiments were read first. They did
not test this exact paired `mul_base` consumer. The wide/carry and small-phase
negative findings remain valid; no gains are added across those alternatives.

Accumulate canonical base-field sums `A=Σa*x`, `B=Σb*y`,
`C=Σ(a+b)*(x+y)`, then return `(A+7B, C−A−B)`.
Both input sums are reduced canonically before multiplication; raw u64 wrapping
fails retained controls. No deferred wide sums or unchecked representation is
introduced. Every private real and imaginary word remains necessary.

| Per N-coefficient pair, excluding unchanged Eq construction | Baseline, U lowered algebraically | Paired four-product control | Paired three-product |
|---|---:|---:|---:|
| Variable base products / their reductions | 4N | 4N | 3N |
| Constant-seven products | 1 | 1 | 1 |
| Canonical base additions | 4N+2 | 4N+2 | 5N+1 |
| Canonical base subtractions | 0 | 0 | 2 |
| Private source-word reads | 2N | 2N | 2N |
| Eq component accesses in source loops | 4N | 2N | 2N |
| Additional persistent payload | 0 | 0 | 0 |

Thus the trade is N variable products for N−1 net additions and two
subtractions, with altered dependency chains. These are primitive/source-loop
counts, not machine instructions, physical traffic or time. The original
literal `U.mul(row)` calls five base multiplications, including constant zero
and one operands. The comparison already allows those to simplify: their
removal is not claimed as another optimization. Reusing hot Eq data can mean
that fewer source accesses remove no DRAM traffic. Actual LLVM lowering,
register use, peak memory and timing remain unknown.

At N=16,384, one pair's variable products fall 65,536→49,152, adding 16,383
net additions and two subtractions. Six separate SC_TAB pairs remove 98,304
products/reductions while retaining all 196,608 private source-word reads.
Eq construction remains six independent builds in this standalone candidate.
The prior public-tail-weight patch is a separate alternative, not stacked here.
The proposed arithmetic function covers all existing `mask_eval` callers;
actual per-slot row lengths, multiplicities and exclusive time are still owed.

`candidate.py` models the native u64 carry/borrow and `reduce128` steps.
`reference.py` imports no candidate code and uses unbounded integer polynomial
convolution modulo p, original Boolean-cube evaluation, and separate MSB folds
for larger cases. The four-product paired control separates a single scan
from the algebraic product reduction. No foreign implementation was run.

Result: **7,399 checks, 168 fixtures, 18 negative-control families PASS**.
Coverage includes 1,296 extrema products, 4,096 seeded random products,
arbitrary dot lengths 0/1/2/3/7/31/127/1025, row logs 0..8 with smaller/equal/
larger private domains, subrow offsets, separate fresh pairs, full-extension,
base, Boolean, maximal and zero-first points. Six-pair cases use row lengths
256, 8,192 and 16,384; these are synthetic row lengths, not model contexts.
Ordered synthetic extension outputs and canonical terminal bytes match; later
zero extensions remain present. Controls catch wrong nonresidue, missing
cross subtractions, raw-sum overflow, dropped terms, reused/wrong private
rows, widths/offsets/tails, stale results, swapped limbs, changed terminal/
extension order and an unsafe u128 sum premise. These are algebra controls,
not native privacy or receipt tests.

Probe: **3.984581 s, 32,852 KiB peak RSS**, seed 202610290137.
Independent source/count/patch audit: **495 checks, 0.185084 s, 17,528 KiB**.
The audit checks all eight current source pins, actual primitive calls for
all three arms, direct-cube Eq basis values, and an exact single-function
replacement. Hardware: one nice19 pinned CPU0 worker, Intel Core Ultra9
185H, Python3.10.12, WSL2. Each experiment has a 40 s CPU cap, 45 s alarm,
50 s parent timeout, 256 MiB address-space cap and 96 MiB memory estimate.
No native build, GPU, installation, external execution or production edit.

Reproduce sequentially from the research root:

```text
python3 experiments/paired-mask-three-product-20261029/prepare_adapter.py
python3 experiments/paired-mask-three-product-20261029/run_bounded.py probe.py
python3 experiments/paired-mask-three-product-20261029/run_bounded.py audit.py
```

The research Rust adapter and `paired-mask-dot.unapplied.patch` are **uncompiled
and unapplied**. It retains the exact point tail, c0 and row-width calculation,
two original slices and current pair identity. Shape/canonical admission and
all native refusal, RNG, transcript, masking, PCS, capture, privacy and
independent-receipt gates remain owner obligations. Earlier evaluation of
the second slice changes the malformed-slice panic schedule; accepted-layout
support is unchanged in the model, but this is not a native refusal-equivalence
claim. Main/Claude reviews and integrates; this lane does not merge.

The historical R4 TinyLlama T128/L22 raw logs were reread and hashed, not
rerun or reverified. Summing all 506 extension-step rows per arm gives
15.938 s / 153.072 s prove_run on CPU and 13.303 s / 135.809 s with RTX4070
Laptop assistance, 16 CPU threads and one pass each. These phases include
Eq construction, all mask dots, extension polynomials and CFS work. Even
deleting the entire phase for free gives only **1.116222× / 1.108591×
proving-only** counterfactual speedup on those diagnostics, using displayed
rounded timers. These are approximate timer-based bounds, not exact phase
measurements. The actual removed
products cover only part of these phases; no measured fraction is available.
Historical R4 scope is not current R12b, trained 8B or a named high-end GPU.
The earlier SC_TAB-only ceiling remains a distinct, smaller scope.

For the target, the ceiling remains `Npositions/(T−C_removed+A_added)`.
Exclusive critical-path costs are unknown. A 25% arithmetic-product reduction
is not a 25% dot runtime or proof speedup. Falsify on any exact-value, support,
tail/offset/width/site/order, refusal, RNG, transcript, PCS, receipt or privacy
mismatch; compiler-equivalent baseline work, worse peak/register behavior,
or no enclosing verified-workload gain also reject promotion.

LIVE primary search added eight records, sources.jsonl 901→909. Newly screened
[October28 polynomial-evaluation preprocessing](https://eprint.iacr.org/2026/2668)
has no established native repeated-public-query benefit. The newly assessed
[older matrix Karatsuba paper](https://arxiv.org/abs/2501.08889) motivates
charging additions and accumulation costs, without transferring hardware gains.
[Jolt Atlas](https://arxiv.org/abs/2602.17452) was refreshed with full stage
clocks; its current [dimension proposal](https://github.com/ICME-Lab/jolt-atlas/pull/401)
and [migration plan](https://github.com/ICME-Lab/jolt-atlas/pull/400) are specs.
Current ICME license terms were inspected; no implementation was copied.
No releases were listed. A stale August history coordinate is observed, not
an inspected/current code pin; its fetch failed. TenseUp primary metadata/PDF
were inaccessible and remain an unassessed lead. Exact dates, URLs, license
scopes and blockers are saved; no author timing or theorem was reproduced.

The ranked queue retains all 54 earlier entries and adds two, with the top
three unchanged: owner whole-prover high-end-GPU and verified resident1/2/4/8
workloads; admitted DD/fidelity context scaling; complete exclusive phase and
capacity clocks. Paired-dot arithmetic is a secondary owner A/B after those
measurements. Next local experiment: source-derived `define`/`Priv` incidence
across all 23 slots, checking earlier descriptor catalogs first. Count actual
tail lengths, paired source loads and Eq work before pricing a public-sum
preparation or another cache. Do not repeat cycle20 A-row assembly or cycle21
conversion tests, which were reread and already cover those obvious levers.

New independently verified full-stack proofs / passes / positions: **0/0/0**.
Actual model context / accelerator: none. Witness/proof/serialization/
verification, startup/initial-prefill duration and fraction, latency/bytes,
steady-state and total-workload rates: **unmeasured**. No long prefill,
resident-model proof series or decode ran. Larger workloads remain allowed;
longer attention can grow quadratically. Private8B ≥50 proved tokens/s on
RTX5090 or another named high-end GPU remains unachieved.
