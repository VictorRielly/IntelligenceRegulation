# Six exact int8 witness projections — owner handoff,2026-10-17

Run `20261017T102624Z-c13de864`. **Synthetic kernels passed; native Rust candidate is uncompiled
and STALE. Concurrent owner R3 code already tiles/parallelizes and builds once.
Do not apply the original patch without comparing/rebasing against that code.**

Target seam:`ops/zkp-mvp/trained-1b/hashline/src/private_block/witness.rs`:
`matmul`300,`matmul_in_out`312; Q/K/V489–491,AO604,gate677,up680.
Native norm output class is checked at rms_norm; O8 is quantized[-127,127].
FFNdown695 remains on its original i64 helper. Source snapshots/hashes:
`experiments/exact-witness-limb-census-20261017/native-pins.json`.

Candidate interface keeps `(g,x:i64 plane,xs,w:i8,inner,outer,os,out_len)` and
adds public `in_out:bool`; returns the original i64 plane. It packs checked
values, guards `inner<=132104`, otherwise falls back to the original helper.
IO uses64-output i32 tiles; OI retains contiguous dot order. All padded K
coordinates are summed, padded rows/columns remain zero; quantize and caller
refusal order are untouched. Patch:
`experiments/exact-witness-limb-census-20261017/i8-projection-candidate.patch`.
No production file was modified and no Git operation was used.

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


Unresolved: native compiler/Vec allocations can erase C helper gains; packing
reuse and native matmul share are unknown. Full witness/reference and all
first-refusal gates, scalar fallback, toy/padded/trained/large legal K,
transcript/RNG/final/proof-byte identity and fresh verification remain unrun.
Keep current D24 classes, all CFS/PCS masks and blinding lifetimes. D22 does not
cover these trained/GPU shapes. This patch grants no new privacy acceptance.

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

Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Target steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, context length, proof latency/lag/drain: **unmeasured**. Local experiments: one Intel Core Ultra 9 185H CPU thread, CPU0, nice19, no GPU. Retained owner diagnostics: TinyLlama1.1B, T32,22 linked blocks, one CPU pass and one RTX4070Laptop-assisted pass (not resident repeats); shape privacy acceptance is absent. No long-context prefill, resident-model sweep or decode proof ran. Longer contexts increase dense-attention work approximately quadratically. Larger workloads remain permitted with fresh masks and all privacy obligations; the >=50 proved-token/s target remains unchanged and unachieved.
