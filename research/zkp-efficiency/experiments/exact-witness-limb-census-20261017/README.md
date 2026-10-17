# Exact witness projection census — cycle0060

Run `20261017T102624Z-c13de864`, checkpoint2026-10-17T10:38:15.278965+00:00.

Synthetic exact-int8 projection arithmetic passed. **The patch is stale after
concurrent R3 owner changes and must be compared/rebased before use. No native
speedup or private8B performance is established.**

|Retained owner linked-stack diagnostic, T32 /22blocks /n=1|CPU|RTX4070Laptop-assisted|
|---|---:|---:|
|Reported main-path total, s|528.926|545.079|
|Public load, s|10.203|9.063|
|Input-dependent sealing/sequence-read/parity pass, s|230.648|229.941|
|Prove_run including witness rebuild and durable sink, s|282.618|296.036|
|Witness rebuild/source extraction subset, s|222.999|227.970|
|Prove_run minus that subset (not pure cryptographic proving), s|59.619|68.066|
|In-process verify/read/decode, s|4.872|4.901|
|Fresh-process verifier load/read, s|10.253|9.795|
|Fresh-process verifier verify/decode, s|4.886|4.979|
|Receipt bytes|250,855,088|250,855,088|
|Peak reported host HWM, MiB (not VRAM)|2,200|2,032|
|Raw reported32-position/total diagnostic rate, positions/s|0.060500|0.058707|
|Accepted target tokens|0|0|

These are existing public logs, not proofs or fresh verification rerun here.
Both have matching statement identity, block count and receipt length in the
owner's fresh-process log. Sealing includes input/sequence reads and parity;
source timing includes witness and boundary extraction. Their combined clocks
453.647s/457.911s are **85.77%/84.01% of total**, not isolated matmul clocks.
Neither is safely reusable model startup. Serialization is unsplit inside and
outside prove_run; true startup boundary/fraction and steady slope are unknown.
CPU/GPU totals differ by+16.153s; n=1 shared-host samples do not establish a
GPU slowdown distribution. GPU accelerates selected commitment phases, not
these CPU witness loops. Original native CPU thread count is unestablished.
No driver/power/VRAM measurements or high-end-device result were produced here.

Original pinned round-2 baseline: seven native dense projection calls use i64 activations and
accumulation. Six consume checked[-127,127] values; down consumes int16.
AtK2048/4096 the six calls' absolute accumulator bound is33,292,288/66,584,576,
well inside i32. Conservative Kmax132,104 protects every partial sum in any
order. Full down worst-case bounds2^35/2^36 do not fit i32. Score/PV, norms,
requant/range, planes/helper materialization, commitments and serialization
are separate work and are not optimized by this candidate.

Eliminated work: **zero MACs**, narrower operand/accumulator traffic and IO
strided traversal. Added costs: pack/range scan, packed Vec allocation/drop,
256B logical i32 tile, output widening, public route/shape guard and fallback.
The C timings include packing/checking/zeroing/widening but exclude caller
allocations in ALL arms; the Rust candidate allocates its packed Vec and output.
All six calls pack independently; reuse of QKV or gate/up packs is future work.
No native register/spill/peak or wall reduction is known.

Source-loop counts: trainedTiny T32 requires1,912,602,624 projection MACs per
build,1,375,731,712(71.93%) direct-i32 eligible; two builds across22blocks count
84,154,515,456 projection MACs. Allocation-free8B-shaped T512 count is
124,554,051,584/build,72.41% eligible,7,971,459,301,376 for two32-block builds.
These are loop counts over padded axes, not timings or admitted8B profiles.
Full-future-pair attention and pad semantics remain. No private data was read.

Complete-workload ceiling is N/(Ttotal-Csix_native+Cnew_native); neither
Csix_native nor Cnew_native is measured, so no numerical8B ceiling exists.
Even deleting BOTH ENTIRE retained witness-related families bounds that
diagnostic at7.0262× CPU/6.2532×GPU; deleting only sealing gives1.7733×/1.7297×.
Those unattainable deletions are not forecasts, and microbench ratios cannot
be multiplied by projection MAC fractions to infer complete proof throughput.

Main experiment:200 synthetic fixtures;17,820
independent Python arbitrary-integer dot checks,59,496
kernel-output checks,318,888 independent divmod rounding
checks and6,348 zero-padding checks. K extrema2048/4096/8192/
16384 use one output only; benchmark shapes are4×128×256,8×256×512,4×512×1024,
both IO/OI orientations. Twelve controls include unchecked narrowing, K overflow,
weight signedness, orientation, dropped padded K, rounding, full-K completion,
and first gate/up refusal order. FP32 cancellation gives0 instead of exact1;
a constructed int16 down sum2^32 wraps to0 and falsely passes a native range
window. No native profile was run. Seed2026101760; total local compile+test
wall1.866833s, RSS37,876KiB and compiler
child peak37,876KiB. Compiler:gcc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0.
Independent source/patch/accounting audit:145checks,
0.001951s/15,080KiB. AWE arithmetic-only pass:
0.164614s/14,352KiB. Each experiment one thread,
nice19/CPU0,59s wall+CPU/512MiB AS caps; estimated96/32MiB. Tiny own C compile
only; no native Rust/application build, GPU, install, foreign execution or proof.

|Weight layout|T×K×N|wide / narrow literal median|wide / narrow tiled median|
|---|---|---:|---:|
|OI|4×128×256|4.81×|4.81×|
|OI|8×256×512|4.24×|4.64×|
|OI|4×512×1024|5.47×|6.09×|
|IO|4×128×256|0.85×|3.12×|
|IO|8×256×512|1.00×|7.25×|
|IO|4×512×1024|0.97×|7.72×|

Seven alternating-order samples/arm, three calls/sample, shared host, CPU-only
C helpers. These ratios are not trained witness, Rust compiler or end-to-end
speedups; narrowing alone regressed strided IO in these shared-host passes. Earlier
passes are retained; timing variability prevents a precise expected factor.

|Rank|Hypothesis / expected complete-proof opportunity|Prerequisites, added costs and falsifier|
|---|---|---|
|1 REFINED, TESTED SYNTHETIC / OWNER|Six exact int8-fed witness projections can use int32 accumulators. Original baseline had two witness passes; concurrent R3 owner code now tiles/parallelizes and builds once. Incremental benefit versus R3 is unknown.|Stale patch must be reviewed/rebased, then native compiler/witness/refusal/receipt and phase profile; charge packing/allocation/widening. Current R3 uses i32 products widened into i64 accumulators; our i32 accumulation is a potential further change. Keep full K, quantize order and fresh masks. Any mismatch or no enclosing improvement falsifies. Narrowing alone regressed strided cases.|
|2 OWNER|Accelerate remaining native GPU SC_SZC after witness work, following split clocks.|Masked polynomial/finals/RNG/PCS/transcript/privacy gates; launch, transfer, scratch/occupancy costs. Historical one-block phase share is not trained8B evidence. Any oracle/bytes/refusal mismatch or enclosing regression rejects.|
|3 OWNER|Reuse input-independent public setup across fixed-context linked resident passes. Concurrent R3 one-pass work supersedes proposing a cache just to eliminate the old sealing rebuild.|Identity/lifetime and memory/storage traffic; preserve endpoint/parity/refusal semantics, fresh masks/openings and drain. No endpoint-root chaining shortcut. Recurring cost>20ms/new completed position falsifies50/s for that schedule. R3 has no new accepted timing in this experiment.|
|4 OWNER|Exact full-K int16 FFN-down via prior two-byte products, separate from direct int8 route.|Packing, two products, exact i64 reconstruction, full-K final requant, original refusal order, transfers/scratch. Down is27.6–28.1% of these projection MAC counts, not a measured time fraction. Direct int32 down can falsely accept; reject it.|
|5 OWNER, DEMOTED LOCAL|Prior public selector/factory candidates retain their existing scope; no new scheduling toys until native demand.|Actual constructor capture and native literal/fixed/scheduled comparison. No extra arithmetic gain this cycle; compiler may already achieve it. Native parity and enclosing benefit required.|
|6 NEW CONDITIONAL / NEGATIVE FILTER|AWE exact FP4 reconstruction is algebraically valid but not a promising replacement for one native INT8 GEMM on hardware supporting INT8.|Six FP4 products plus plane generation/reconstruction versus native one; author RTXPRO6000/B200 theoretical ratio1/3 excludes those costs. B300 differs; no5090 measurement. Preserve exact integer/wide reconstruction, fixed-format semantics and privacy. Revisit only for a named architecture lacking efficient INT8 or a measured contrary bottleneck.|

LIVE primary review: [Integer Alibi](https://arxiv.org/abs/2608.13756)
(Aug13/18,2026) reinforced the accumulator/epilogue boundary; our weights include
-128, so the independent absolute-product bound is127×128, not127².
[CUTLASS PR3302](https://github.com/NVIDIA/cutlass/pull/3302) remains open;
March9 example commit382200f18f8a1f906799dde38afa7ad2840dcea5 was resolved from
metadata but its diff failed to load. C++ mma_sm80.h was inspected on main.
CUTLASS4.8.0 changelog saysSep17,2026 while release UI saysSep22 without a year;
keep these as different date evidence. C++ BSD-3-Clause license text inspected;
python/CuTeDSL has separate NVIDIA EULA terms. No foreign code imported.

[AWE](https://arxiv.org/abs/2609.24519), newSep21,2026 lead, passed our own
65,536-pair arithmetic reproduction of one six-product INT8 encoding; contiguous
coverage±148 with all stored planes≤6, FP32 absolute-sum boundK≤466,033.
Changing one coefficient failed42,849 pairs. This is algebra only. Its own
RTXPRO6000/B200 theoretical comparison gives1/3 nativeINT8 throughput before
plane generation/reconstruction; fewer products than its9-product baseline
does not beat a native1-product baseline. No author runtime replicated.

Older [Ozaki/ozIMMU](https://arxiv.org/abs/2306.11975) refreshed
(Jun21,2023/Mar30,2024), already assessed in cycle22; no new implementation gain.
[zkIE](https://github.com/trustless-ai/zkIE) README discloses public activations
and verifier forward reexecution; not a P1 replacement. History fetch failed,
so no verified update/commit for zkIE. Exact dates, license scope, commit scope,
queries and errors are in source records. Native LIVE search was used; source
text was treated as untrusted data, and no downloaded script was executed.

Owner next: compare the stale six-call research patch with the concurrent
R3 native path before any integration. R3 uses tiled/parallel i32 products with
i64 accumulation and removes the old pre-prove witness pass using exported
endpoints checked during proving; no new R3 timing/verification is reproduced
here. Our potential remaining delta is full int32 accumulation on six checked
int8 sites. Review/rebase only if that delta merits measurement, then compile under the
shared build/heavy guard, run native witness/reference and first-refusal gates
at toy/padded/trained geometries, then byte/RNG/transcript/fresh-verifier gates.
Profile all seven projections, norm/range/plane materialization and the current
one-pass source with allocation/packing included before committing GPU integration.
No heavy job was queued here; main agent/Claude owns review and integration.

Next local: allocation-free witness allocation/lifetime census, focused on
initial pl allocation/replacement and clones in the NEW one-pass path. Do not
duplicate the owner's parallel-loop or one-pass implementation. No private
fixture/cache is authorized for these research artifacts. Next search rotation: memory traffic and
NTT/commitments, following new native phase clocks; preserve architecture leads
and all previous negative results.


Commands (working directory is the research directory):

```sh
python3 experiments/exact-witness-limb-census-20261017/run.py
python3 experiments/exact-witness-limb-census-20261017/prepare_candidate.py
python3 experiments/exact-witness-limb-census-20261017/awe_filter.py
python3 experiments/exact-witness-limb-census-20261017/audit.py
```

run.py records the exact gcc invocation and compiles only our own kernels.c.
Retained source/native pins and artifacts.sha256.json bind all artifacts.
`i8-projection-candidate.patch`, `i8_projection.rs` and `candidate/witness.rs`
are research-only, uncompiled and unapplied. The existing Rust down call and
all quantize callers are retained byte-for-byte after inverse reconstruction.

Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Target steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, context length, proof latency/lag/drain: **unmeasured**. Local experiments: one Intel Core Ultra 9 185H CPU thread, CPU0, nice19, no GPU. Retained owner diagnostics: TinyLlama1.1B, T32,22 linked blocks, one CPU pass and one RTX4070Laptop-assisted pass (not resident repeats); shape privacy acceptance is absent. No long-context prefill, resident-model sweep or decode proof ran. Longer contexts increase dense-attention work approximately quadratically. Larger workloads remain permitted with fresh masks and all privacy obligations; the >=50 proved-token/s target remains unchanged and unachieved.

Research only: production/runtime/Git/calibration/gates/instructions/reviewer
files untouched; no external writes/messages or merge. Saved reports do not
prove user notification or supervisor liveness.
