# Public interval rowfold — cycle 0152

Run `20261029T215649Z-4ef3ea52`, October 29, 2026. **No native proving
speedup measured.** This is an exact CPU linear-algebra experiment and
source operand census using frozen R13 public geometry. It tests whether
the preceding cycle's sorted packed row/membership indices compress into
consecutive intervals without changing any fold output.

An 8-byte `Run { word: u32, len: u32 }` stores `word = row << 4 | flags`.
An interval covers consecutive rows with the same membership flags for a
physical batch of at most four opening vectors. The public selector compares
three per-column logical operand counts: dense `R*(8+16*k)`, point list
`12*U+16*S`, and intervals `8*U+16*S+8*J`, where R is matrix rows, U is union
rows, S is group-membership incidences and J is interval count. It picks
the lowest count, retaining list/dense fallbacks. This criterion has not
been calibrated against device time. Plans use public support or current
public rho coefficients, including both limbs; matrix values never enter it.
The native caller's public provenance still needs owner review.

| Frozen R13 A core, 8B/T128, N16384, original order | noDD | DD32 |
|---|---:|---:|
| Matrix rows / vectors including proximity | 4,577 / 37 | 4,455 / 39 |
| Prior point-list visits per column | 9,654 | 9,328 |
| Pure equal-membership intervals | 74 | 81 |
| Prior plan payload, B | 38,616 | 37,312 |
| Hybrid plan payload, B | 584 | 648 |
| Prior matrix + rho + index operands, B | 4,468,113,408 | 4,340,318,208 |
| Hybrid matrix + rho + metadata operands, B | 3,844,997,120 | 3,739,615,232 |
| Reduction from prior indexed loop | 13.9458% | 13.8401% |
| Reduction from original dense loop | 92.3700% | 92.7224% |

These are **source logical operands**, before compiler/cache/broadcast;
they are not physical DRAM traffic, GPU timing or complete-proof throughput.
The noDD hybrid uses 8 run batches, 1 list batch and 1 dense proximity-only
batch; DD uses 9 run batches and 1 list batch. Every matrix/rho membership
incidence is retained (dense may visit additional zero coefficients).
Prior reordered plans also pass but remain local packing optima, and their
construction/clone/scatter costs remain extra. Reordering is unnecessary.

Source logical metadata reads fall 632.685/611.320 MB to 9.568/10.617 MB,
while one-time payload is only 584/648 B. Physical metadata/rho reads may
already be served by uniform broadcasts and caches. Rho uploads remain
2,709,584/2,779,920 B; outputs, D2H, allocation, encoding, commitments,
fresh masks, actual pads, proximity and all other proof phases remain.
Conversion from an existing list took 10.634/11.060 microseconds and
validation 286.722/292.304 microseconds, n=1 shared CPU. Prior list creation
is additional and was not timed again. Mode dispatch, nested loops, CUDA
code generation, register spills/occupancy and cache effects are unknown.

A useful negative control: setting every third row's public rho to zero
reduces original-order union visits to 6,432/6,214 but creates 3,242/3,134
intervals and 25,728/24,856 B hybrid metadata. Numerical-zero elimination
does not preserve interval compression. Its total source operands still
fall to 2.976/2.891 GB, about 22.60/22.71% below the structural hybrid, so
metadata size alone also cannot reject it. These altered rhos are algebra
fixtures, not admitted native proof instances or a performance prediction.

Validation: 14 native-helper fixtures plus 45 independent support patterns;
184,770 exact output comparisons against separately implemented schoolbook
u128 modular arithmetic (27,360 with source row counts and eight columns),
462 controls, and 102,314 independent Python assertions. Tests cover native
synthetic rhos, imaginary-only rhos, public numerical cancellation, empty,
dense, alternating, short-run and random supports, k=1..9 split into max4,
original/reversed/prior-packed orders, and three extra synthetic pad columns
at small shapes. Missing, overlapping/duplicate, zero-length, oversized,
out-of-range, truncated, wrong-flag/order, omitted-batch and missing
mask/proximity spans are rejected; wrong output scatter is observable.
References are independent code by this researcher, not external review.

The harness retains pinned native field, allocation, offsets, claim and
group/rho helpers; its slot schedule and transcript stand-in are synthetic.
Native define, Fiat–Shamir, actual PCS pad generation, CUDA, receipts,
full-stack proofs and privacy acceptance were not run. R14 split geometry
differs and must be re-pinned separately. `prior-native-pins.json` and
`seam-pins.json` retain exact paths and SHA-256 values; the audit checked
11 native source pins and 6 current seams unchanged. It preserves all
74 prior hypothesis objects and adds tested #75 and follow-up #76.

Reproduce each serial bounded stage from the research directory:

```text
python3 experiments/public-interval-fold-20261029/run_bounded.py compile
python3 experiments/public-interval-fold-20261029/run_bounded.py probe
python3 experiments/public-interval-fold-20261029/run_bounded.py census
python3 experiments/public-interval-fold-20261029/run_bounded.py audit
```

Seed `202610290152`; Intel Core Ultra 9 185H, WSL2, Python 3.10.12,
Rust 1.75. Final standalone compile 3.039 s / 198,680 KiB RSS; probe
0.975 s / 28,696 KiB; census 0.167 s / 20,492 KiB; audit 0.066 s /
19,440 KiB. Each stage has one CPU affinity, nice19, 40 s CPU / 45 s alarm /
50 s parent timeout, and 384 MiB address-space cap. The numerical/Python
workers are single-threaded; compiler auxiliary threads were not counted,
with one codegen unit and one CPU affinity. Estimated memory 300 MiB compile,
96 MiB other stages. First passing artifacts are retained; the second run
adds numeric-fragmentation accounting. Source count accounting was corrected
to exclude 2,250 stress comparisons from the source-row subtotal. No native
build, GPU, dependency installation or foreign execution occurred.

Integration: `fold_rows_multi_zk → EncodedStore::fold_rows → dev_fold_rows`.
`interval.rs` is the tested prototype; `candidate-kernel.cuh` is an
**uncompiled owner-review sketch**. Register a separate kernel, upload a
validated current public plan, retain it until synchronized output copy,
and preserve existing group/output order and max4 batches. Keep native
`assert_mask_sites`, all fresh masking/pads/proximity, H sum/U, refusals,
RNG draw order, FS and PCS unchanged. No private sparsity dispatch or reuse
of private openings/masks is authorized. Main/Claude reviews/integrates;
no production file was changed.

The first owner priorities remain complete high-end GPU proofs and verified
resident 1/2/4/8 workloads, admitted context/DD/fidelity scaling, and exclusive
phase/capacity clocks. Measure rho H2D, allocation, kernel, D2H, pad/open and
enclosing clocks before adding device complexity; current `secs_fold`
encloses several phases. Later owner checks require current shared locks,
native golden/refusal/RNG/FS/PCS/privacy gates, actual CUDA registers/spills
and independently verified enclosing/workload A/B. Free phase deletion is
bounded by `1/(1-f)` with unknown exclusive f; complete rate would be
`N/(T-C_removed_exclusive+A_added)`. A mismatch or no verified enclosing
benefit falsifies promotion. No numerical 8B GPU forecast is justified.

LIVE sources: [Celty v2](https://arxiv.org/html/2608.01536v2) motivates
charging index reconstruction; its inference pruning/hardware are not proof
substitutes. [BRO 2013](https://www.comp.nus.edu.sg/~wongwf/papers/SC13.pdf)
and [DIV 2025](https://hpcrl.github.io/ICS2025-webpage/program/Proceedings_ICS25/ics25-28.pdf)
provide older compression context. [VDHA](https://craft.cs.tsinghua.edu.cn/publication/vdha-vector-drivenhash-aggregation-for-sparse-matrixsparse-vector-multiplication-on-gpus/)
targets scatter conflicts absent from the current one-writer fold.
[Pico3.0](https://blog.brevis.network/2026/09/30/pico-3-0-real-time-ethereum-proving-on-4-gpus-with-100-bit-provable-security/)
is an author-reported composition/chunking lead, not reproduced evidence.
BlockSmith publisher metadata was found, but its full text returned403.
Six records retain exact URLs, verified dates/nulls, licenses and blockers;
ten search provenance records with raw-response hashes are saved. No external commit ID was inspected. No foreign
implementation was copied or executed.

New verified full-stack proofs / model passes / proved positions: **0/0/0**.
Actual context/accelerator: none; modeled context T128. Witness, proof,
serialization, verification, startup/initial-prefill duration and fraction,
proof latency/bytes, steady-state and total-workload rates: **unmeasured**.
No long prefill, resident-model series or decode ran; larger workloads remain
allowed and attention may grow quadratically. Complete private 8B >=50
proved tokens/s remains unachieved.
