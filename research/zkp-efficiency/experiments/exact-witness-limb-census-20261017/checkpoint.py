from pathlib import Path
import datetime,hashlib,json

e=Path(__file__).resolve().parent;r=e.parents[1]
run='20261017T102624Z-c13de864';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
j=json.loads((e/'result.json').read_text());a=json.loads((e/'audit-result.json').read_text());aw=json.loads((e/'awe-filter-result.json').read_text())
c=j['counts'];cpu,gpu=j['retained_linked_stack_accounting']
ratio_lo=min(b['wide_over_tiled'] for b in j['cpu_microbenchmarks']);ratio_hi=max(b['wide_over_tiled'] for b in j['cpu_microbenchmarks'])
timingrows='\n'.join(f"|{b['orientation']}|{b['T']}×{b['K']}×{b['N']}|{b['wide_over_narrow']:.2f}×|{b['wide_over_tiled']:.2f}×|" for b in j['cpu_microbenchmarks'])
measurement='''Accepted independently verified complete private **8B** proofs / passes / positions: **0 / 0 / 0**. Target steady-state and total-workload rates, startup seconds/fraction, witness/proof/serialization/independent-verification clocks, context length, proof latency/lag/drain: **unmeasured**. Local experiments: one Intel Core Ultra 9 185H CPU thread, CPU0, nice19, no GPU. Retained owner diagnostics: TinyLlama1.1B, T32,22 linked blocks, one CPU pass and one RTX4070Laptop-assisted pass (not resident repeats); shape privacy acceptance is absent. No long-context prefill, resident-model sweep or decode proof ran. Longer contexts increase dense-attention work approximately quadratically. Larger workloads remain permitted with fresh masks and all privacy obligations; the >=50 proved-token/s target remains unchanged and unachieved.'''
baseline='''|Retained owner linked-stack diagnostic, T32 /22blocks /n=1|CPU|RTX4070Laptop-assisted|
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
'''
queue='''|Rank|Hypothesis / expected complete-proof opportunity|Prerequisites, added costs and falsifier|
|---|---|---|
|1 REFINED, TESTED SYNTHETIC / OWNER|Six exact int8-fed witness projections can use int32 accumulators. Original baseline had two witness passes; concurrent R3 owner code now tiles/parallelizes and builds once. Incremental benefit versus R3 is unknown.|Stale patch must be reviewed/rebased, then native compiler/witness/refusal/receipt and phase profile; charge packing/allocation/widening. Current R3 uses i32 products widened into i64 accumulators; our i32 accumulation is a potential further change. Keep full K, quantize order and fresh masks. Any mismatch or no enclosing improvement falsifies. Narrowing alone regressed strided cases.|
|2 OWNER|Accelerate remaining native GPU SC_SZC after witness work, following split clocks.|Masked polynomial/finals/RNG/PCS/transcript/privacy gates; launch, transfer, scratch/occupancy costs. Historical one-block phase share is not trained8B evidence. Any oracle/bytes/refusal mismatch or enclosing regression rejects.|
|3 OWNER|Reuse input-independent public setup across fixed-context linked resident passes. Concurrent R3 one-pass work supersedes proposing a cache just to eliminate the old sealing rebuild.|Identity/lifetime and memory/storage traffic; preserve endpoint/parity/refusal semantics, fresh masks/openings and drain. No endpoint-root chaining shortcut. Recurring cost>20ms/new completed position falsifies50/s for that schedule. R3 has no new accepted timing in this experiment.|
|4 OWNER|Exact full-K int16 FFN-down via prior two-byte products, separate from direct int8 route.|Packing, two products, exact i64 reconstruction, full-K final requant, original refusal order, transfers/scratch. Down is27.6–28.1% of these projection MAC counts, not a measured time fraction. Direct int32 down can falsely accept; reject it.|
|5 OWNER, DEMOTED LOCAL|Prior public selector/factory candidates retain their existing scope; no new scheduling toys until native demand.|Actual constructor capture and native literal/fixed/scheduled comparison. No extra arithmetic gain this cycle; compiler may already achieve it. Native parity and enclosing benefit required.|
|6 NEW CONDITIONAL / NEGATIVE FILTER|AWE exact FP4 reconstruction is algebraically valid but not a promising replacement for one native INT8 GEMM on hardware supporting INT8.|Six FP4 products plus plane generation/reconstruction versus native one; author RTXPRO6000/B200 theoretical ratio1/3 excludes those costs. B300 differs; no5090 measurement. Preserve exact integer/wide reconstruction, fixed-format semantics and privacy. Revisit only for a named architecture lacking efficient INT8 or a measured contrary bottleneck.|
'''
sources='''LIVE primary review: [Integer Alibi](https://arxiv.org/abs/2608.13756)
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
'''
ceiling='''Original pinned round-2 baseline: seven native dense projection calls use i64 activations and
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
'''
validation=f'''Main experiment:200 synthetic fixtures;{c['raw_dot_reference_checks']:,}
independent Python arbitrary-integer dot checks,{c['kernel_output_checks']:,}
kernel-output checks,{c['requant_reference_checks']:,} independent divmod rounding
checks and{c['padding_checks']:,} zero-padding checks. K extrema2048/4096/8192/
16384 use one output only; benchmark shapes are4×128×256,8×256×512,4×512×1024,
both IO/OI orientations. Twelve controls include unchecked narrowing, K overflow,
weight signedness, orientation, dropped padded K, rounding, full-K completion,
and first gate/up refusal order. FP32 cancellation gives0 instead of exact1;
a constructed int16 down sum2^32 wraps to0 and falsely passes a native range
window. No native profile was run. Seed{j['seed']}; total local compile+test
wall{j['experiment_wall_seconds']:.6f}s, RSS{j['peak_rss_kib']:,}KiB and compiler
child peak{j['compiler_child_peak_rss_kib']:,}KiB. Compiler:{j['compiler_version']}.
Independent source/patch/accounting audit:{a['checks']}checks,
{a['wall_seconds']:.6f}s/{a['max_rss_KiB']:,}KiB. AWE arithmetic-only pass:
{aw['wall_seconds']:.6f}s/{aw['peak_rss_kib']:,}KiB. Each experiment one thread,
nice19/CPU0,59s wall+CPU/512MiB AS caps; estimated96/32MiB. Tiny own C compile
only; no native Rust/application build, GPU, install, foreign execution or proof.

|Weight layout|T×K×N|wide / narrow literal median|wide / narrow tiled median|
|---|---|---:|---:|
{timingrows}

Seven alternating-order samples/arm, three calls/sample, shared host, CPU-only
C helpers. These ratios are not trained witness, Rust compiler or end-to-end
speedups; narrowing alone regressed strided IO in these shared-host passes. Earlier
passes are retained; timing variability prevents a precise expected factor.
'''
next_action='''Owner next: compare the stale six-call research patch with the concurrent
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
'''
readme=f'''# Exact witness projection census — cycle0060

Run `{run}`, checkpoint{now}.

Synthetic exact-int8 projection arithmetic passed. **The patch is stale after
concurrent R3 owner changes and must be compared/rebased before use. No native
speedup or private8B performance is established.**

{baseline}\n{ceiling}\n{validation}\n{queue}\n{sources}\n{next_action}

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

{measurement}

Research only: production/runtime/Git/calibration/gates/instructions/reviewer
files untouched; no external writes/messages or merge. Saved reports do not
prove user notification or supervisor liveness.
'''
(e/'README.md').write_text(readme)
handoff=f'''# Six exact int8 witness projections — owner handoff,2026-10-17

Run `{run}`. **Synthetic kernels passed; native Rust candidate is uncompiled
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

{ceiling}\n{validation}

Unresolved: native compiler/Vec allocations can erase C helper gains; packing
reuse and native matmul share are unknown. Full witness/reference and all
first-refusal gates, scalar fallback, toy/padded/trained/large legal K,
transcript/RNG/final/proof-byte identity and fresh verification remain unrun.
Keep current D24 classes, all CFS/PCS masks and blinding lifetimes. D22 does not
cover these trained/GPU shapes. This patch grants no new privacy acceptance.

{baseline}\n{next_action}\n{measurement}
'''
(r/'handoffs/20261017-exact-witness-projections.md').write_text(handoff)
progress=f'''# ZKP efficiency progress

Cycle0060 — `{run}`, completed2026-10-17 UTC.

**No native speedup established.** New linked TinyLlama T32 owner logs put
sealing/parity plus witness rebuilding at453.647/528.926s CPU(85.77%) and
457.911/545.079s GPU-assisted(84.01%). Matching fresh-verifier logs were inspected,
not rerun. These phases are recurring/input-dependent; startup is unsplit.

Tested exact int8/int32 projection helpers:200fixtures,{c['raw_dot_reference_checks']:,}
independent dot checks,{c['requant_reference_checks']:,} rounding checks and12controls.
Small C kernels including packing/widening ran{ratio_lo:.2f}–{ratio_hi:.2f}× faster in the tiled
arm; narrowing alone regressed strided IO. This is a synthetic CPU result,
not a native witness/proof speedup. Main run{j['experiment_wall_seconds']:.3f}s,
{j['peak_rss_kib']:,}KiB RSS,one nice19 CPU thread; audit{a['checks']}snapshot checks passed.

Six source calls are exact-int32 eligible; int16 FFNdown is not. An uncompiled
[Rust patch/handoff](handoffs/20261017-exact-witness-projections.md) preserves
full K and original quantize order. Next owner: native parity/refusal/bytes
and projection phase clocks against the new R3 path. **Concurrent owner source
drift makes the patch stale:** R3 already tiles/parallelizes and builds witnesses
once; no R3 verified timing was reproduced. Next local: new-path allocation/
lifetime census. Six LIVE source records appended, including
IntegerAlibi/CUTLASS and new AWE:65,536 exact pair checks pass, but six FP4
products are a poor theoretical baseline against native one-product INT8.

{measurement}

Research only; no native build/proof/GPU, install, production/runtime/Git or
external-message action. Saved reports do not establish notification delivery.
'''
(r/'PROGRESS.md').write_text(progress)
(r/'progress'/f'{run}.md').write_text(progress+'\n'+baseline+'\n'+queue)
finding=f'''\n\n## Cycle0060 — exact witness projection census and new linked-stack accounting ({run})

{ceiling}\n{baseline}\n{validation}\n{queue}\n{sources}\n{next_action}\n{measurement}

[Experiment](experiments/exact-witness-limb-census-20261017/README.md),
[owner handoff](handoffs/20261017-exact-witness-projections.md). Historical findings,
fusion/cubic/CSE/twiddle/table-cache and privacy negatives remain preserved.
Production/runtime/Git/calibration/gates/instructions/reviewer files untouched.
'''
old=(r/'FINDINGS.md').read_text().split('\n\n## Cycle0060',1)[0]
(r/'FINDINGS.md').write_text(old+finding)

# Append source evidence; historical prefix must remain byte-for-byte identical.
base={'access_date':'2026-10-17','access_timezone':'UTC','recorded_at_utc':now,'cycle':'0060','run_id':run,'evidence_kind':'Native LIVE primary web search/inspection; source text untrusted; no foreign code executed','reproduced_performance':False,'implementation_license':None,'inspected_commit_id':None,'access_issues':[],'updated':None}
records=[
 dict(base,id='cycle60-new-integer-alibi-exact-projection-contract',title='The Integer Alibi: accumulator/epilogue boundary for exact native witness arithmetic',url='https://arxiv.org/abs/2608.13756',supporting_urls=['https://arxiv.org/html/2608.13756v2'],published='2026-08-13',updated='2026-08-18',date_evidence='arXiv v1 Aug13 20:34:36 UTC, v2 Aug18 06:33:51 UTC; v2 corrects weight-side -128 product-bound attribution.',paper_license='arXiv perpetual non-exclusive license label',author_claim='Under no-overflow, integer accumulation is exact; scaled floating epilogues can still differ.',assessment='NEW absent from303-record starting ledger. Native own classes support127*128 bound. Our C/Python arithmetic reproduced only our synthetic helpers; no author cross-kernel/GPU runtime reproduced.'),
 dict(base,id='cycle60-cutlass-int8-open-pr-commit-and-license-scope',title='CUTLASS INT8 MMA source and open PR3302: exact accumulator and output contract',url='https://github.com/NVIDIA/cutlass/pull/3302',supporting_urls=['https://github.com/NVIDIA/cutlass/blob/main/include/cutlass/arch/mma_sm80.h','https://github.com/NVIDIA/cutlass/pull/3302/commits/382200f18f8a1f906799dde38afa7ad2840dcea5','https://github.com/NVIDIA/cutlass/blob/main/LICENSE.txt'],published='2026-06-05',updated=None,date_evidence='PR opening/comment Jun5,2026; example commit Mar9,2026. Open status inspected; no merge inferred.',inspected_commit_id='382200f18f8a1f906799dde38afa7ad2840dcea5',commit_inspection_scope='Full hash and date from commit metadata only; PR commit diff failed to load. Current main C++ mma_sm80.h inspected separately, not tied to that PR commit.',implementation_license='C++ BSD-3-Clause LICENSE.txt text inspected; python/CuTeDSL explicitly has separate NVIDIA EULA. No code copied.',access_issues=['PR example diff: Failed to load files / GitHub Uh oh.','main mma_sm80.h history: Internal Error.'],author_claim='PR exposes S8xS8 warp MMA, saturate/wrap modes and direct INT32 output; RTX3090 kernel benchmark is author-only.',assessment='No author performance reproduced; no native CUDA or Rust integration. Absolute partial-sum bound must precede using either MMA overflow mode; output must retain integer rounding/remainder semantics.'),
 dict(base,id='cycle60-cutlass48-current-release-date-discrepancy',title='CUTLASS4.8.0 current release and September changelog date',url='https://github.com/NVIDIA/cutlass/releases/tag/v4.8.0',supporting_urls=['https://github.com/NVIDIA/cutlass/blob/main/CHANGELOG.md?plain=1','https://github.com/NVIDIA/cutlass/blob/main/README.md'],published=None,updated=None,date_evidence='Changelog labels4.8.0 with2026-09-17; README saysSept2026. Release UI says22Sep03:37 without year. These are distinct date claims; actual full release date not established.',inspected_commit_id='098de2a (abbreviated release target only)',commit_inspection_scope='Release link identity only; commit page Internal Error, no diff/full hash inspected.',implementation_license='C++ BSD-3-Clause text, CuTeDSL separate EULA as above.',access_issues=['Release target commit/tag click Internal Error.'],author_claim='New architecture and layout/compiler features; release itself is not an exact native witness benchmark.',assessment='Recent primary release searched and inspected. No install, backend suitability, native security or performance claim follows.'),
 dict(base,id='cycle60-new-awe-fp4-exactness-negative-native-int8-baseline',title='AWE: exact six-FP4-product INT8 encoding, baseline filter',url='https://arxiv.org/abs/2609.24519',supporting_urls=['https://arxiv.org/html/2609.24519v1'],published='2026-09-21',date_evidence='Only arXiv v1 Sep21,2026 12:55:45 UTC displayed.',paper_license='arXiv perpetual non-exclusive label',author_claim='INT8 products via6FP4 GEMMs instead of positional9; theoretical RTXPRO6000/B200 peak is1/3 nativeINT8 before plane/reconstruction costs.',assessment='NEW absent from starting ledger. Independently reproduced one coefficient encoding for all65536 signed-byte pairs, coverage±148, stored-plane bound6, changed coefficient42849 mismatches. Arithmetic only, no GPU/performance reproduction. Native six projections need oneINT8 product; demoted for INT8-capable hardware. B300 comparison differs; no5090 result.',arithmetic_reproduction='experiments/exact-witness-limb-census-20261017/awe-filter-result.json'),
 dict(base,id='cycle60-ozaki-known-older-refresh-width-bound',title='DGEMM on Integer Matrix Multiplication Unit / ozIMMU refresh',url='https://arxiv.org/abs/2306.11975',supporting_urls=['https://arxiv.org/html/2306.11975v4','https://github.com/enp1s0/ozIMMU'],published='2023-06-21',updated='2024-03-30',date_evidence='arXiv v1 Jun21,2023 and v4 Mar30,2024; repository update date not established.',implementation_license='MIT repository label inspected this cycle; license text previously inspected in cycle22, not repeated now.',author_claim='Integer matrix units can emulate high-precision products through exact components/reconstruction.',assessment='Known source from cycle22, not new. Useful decomposition background for int16down but not needed for six direct-int8 sites. No implementation execution, throughput reproduction or new native gain.'),
 dict(base,id='cycle60-new-zkie-public-activation-and-verifier-rerun-filter',title='zkIE current README: public activations, verifier recomputation',url='https://github.com/trustless-ai/zkIE',published=None,date_evidence='No verified publication/update date; current README inspected, history unavailable.',implementation_license='Apache-2.0 repository/README label only; full license text not inspected.',access_issues=['commits/main: Internal Error.'],author_claim='Goldilocks GKR/LogUp/WHIR/FRI inference engine under development, current weights/activations public and verifier reruns forward work.',assessment='NEW absent from starting ledger. Explicit public activations violate native P1 requirements; not a plug-in replacement. No code or benchmarks reproduced; architecture/scheduler reference only.')]
src=r/'sources.jsonl';prefix=src.read_bytes()
check_prefix=(e/'startup/sources.jsonl').read_bytes();assert prefix.startswith(check_prefix)
existing=[json.loads(line) for line in prefix.decode().splitlines() if line.strip()]
prior_records=[rec for rec in existing if rec.get('run_id')==run]
if prior_records:
 assert len(prior_records)==6
 records=prior_records
else:
 assert prefix==check_prefix
 with src.open('a') as f:
  for record in records:f.write(json.dumps(record,sort_keys=True)+'\n')
(e/'sources-this-cycle.json').write_text(json.dumps(records,indent=2)+'\n')
(e/'queries.json').write_text(json.dumps(['exact quantized integer matrix multiplication GPU int64 accumulation overflow CUTLASS2026 zero knowledge witness','zero knowledge inference exact quantization rounding witness GPU2026 zkLLM zkGPT','Ozaki scheme int8 exact integer matrix multiplication2025 2026 Ootomo Ozaki ozIMMU GitHub','site:github.com/NVIDIA/cutlass int8 saturating OpMultiplyAddSaturate int32','site:arxiv.org integer matrix2026 exact GPU witness','site:github.com/NVIDIA/cutlass/releases4.8.0','DGEMM on Integer Matrix Multiplication Unit ozIMMU'],indent=2)+'\n')
state=f'''# ZKP efficiency explorer — durable state

Cycle0060 COMPLETE: `{run}`; checkpoint{now}. AGENDA/current target,
durable/project memory and latest3 experiment results read/snapshotted.
303 source records parsed;6 LIVE primary records appended,309 total.
Historical FINDINGS/source prefixes preserved. No native speedup established.

Latest owner evidence: linked trainedTinyLlama1.1B,T32,22blocks,one CPU pass
528.926s and one RTX4070Laptop-assisted pass545.079s,each with matching retained
fresh-verifier log. Sealing/parity+source rebuild453.647/457.911s(85.77%/84.01%);
these include reads/parity/extraction,not isolated matmul. Pure startup and
serialization unsplit. Prove_run includes witness and sink; exclusive remainder
59.619/68.066s is not pure proving. No fresh native verification rerun here.
D24 round2 accepted with conditions in current register; no trained/GPU shape
privacy acceptance. None of these diagnostics count toward8B target tokens.

Experiment experiments/exact-witness-limb-census-20261017:
200fixtures,17820 independent dots,59496 kernel output,318888 rounding,
6348 padding checks,12 real controls. Own tiny C helper compile+test only:
{j['experiment_wall_seconds']:.6f}s/{j['peak_rss_kib']}KiB,seed2026101760,one nice19 CPU0
thread,59s/512MiB. Synthetic tiled C median ratios{ratio_lo:.2f}–{ratio_hi:.2f}x; IO narrowing alone
slower. Not native Rust/proof/GPU gains. Six exact-int8-fed calls are direct
i32 eligible (K<=132104,including -128 weights); int16down is not. Full padded
K and original quantize/refusal order retained. CSE/fusion/older negatives preserved.
Candidate i8-projection-candidate.patch changes six calls+one helper,uncompiled,
unapplied; exact inverse source reconstruction. Independent audit{a['checks']}snapshot checks pass.
Live hashes changed in witness.rs/shape.rs/run.rs/trained_block.rs during the cycle; original
live-hash audit failed as designed. Drift is retained in live-source-drift.json.
Owner R3 now tiles/parallelizes with i32 products/i64 accumulation and builds
witnesses ONCE with endpoint/parity checks during proving. Candidate is STALE;
do not apply without comparing/rebasing. No R3 verified timing reproduced here.
Handoff handoffs/20261017-exact-witness-projections.md; main/Claude integrates.

Ranked queue:
1 REFINED/TESTED SYNTHETIC/OWNER exact i32 accumulation on six i8 projection paths;
 compare to concurrent R3 tiled i32-product/i64-accumulating one-pass code first;
 native compiler/allocations/phase/refusal/bytes gates before any end-to-end factor.
2 OWNER native GPU SC_SZC with masked/transcript/RNG/PCS/privacy gates.
3 OWNER resident complete-pass slope; R3 one-pass changes supersede old duplicate
 witness cache proposal; no startup relabel of old sealing and no mask reuse.
4 OWNER prior split-int16down fullK/i64 reconstruction; never direct i32 down.
5 OWNER prior public selector/factory actual capture and profile,local demoted.
6 NEW AWE exactFP4 encoding algebra reproduced65536pairs,coverage±148,stored<=6;
 42849 coefficient mutation failures. Source theoreticalRTXPRO6000/B200 ratio1/3
 versus nativeINT8 before overhead; demoted on INT8-capable hardware,not5090
 measured. No author performance reproduced. Ozaki knowncycle22 refresh;
 IntegerAlibi newAug13/18,2026;CUTLASS4.8 September date evidence qualified;
 PR3302 open,full example commit metadata only,diff blocked;C++BSD3 vsDSLEULA.
 zkIE public activations/verifier rerun excludesP1;history update unknown.

Next LOCAL: allocation-free witness allocation/lifetime census at initialpl
 allocation/replacement and clones in new R3 one-pass code. Do not duplicate
 owner's parallelization/one-pass work. No private data written to research.
Next OWNER: compare/rebase stale patch versus R3 before shared build/heavy guard,native exact witness /
 first-refusal / transcript/RNG/proof bytes / fresh verifier gates; split all
 seven projection/norm/range/plane clocks including packing/allocations,then
 fixed-context resident workloads with true startup,slope,lag/drain and masks.
Complete8B ceiling unknown; deleting ENTIRE retained witness-related families
 yields only diagnostic7.0262xCPU/6.2532xGPU,not predictions or8B bounds.

{measurement}

Research only:production/runtime/Git/calibration/gates/instructions/reviewer
files untouched.No native/application build,proof,GPU,install,foreign script,
external write/message,merge or heavy job queued.Own tiny C compilation only.
Saved reports do not establish user delivery or supervisor liveness.
Next cycle not before2026-10-17T11:26:24Z.
'''
(r/'STATE.md').write_text(state)
print(json.dumps({'checkpoint':now,'sources_before':len(prefix.splitlines()),'sources_appended':0 if prior_records else len(records),'sources_total':len(src.read_text().splitlines()),'reports_written':['STATE.md','PROGRESS.md',f'progress/{run}.md','FINDINGS.md','handoffs/20261017-exact-witness-projections.md']}))
