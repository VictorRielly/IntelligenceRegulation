#!/usr/bin/env python3
"""Write this cycle's research-only durable reports and source records."""
from pathlib import Path
import datetime, hashlib, json, os, resource, signal

HERE=Path(__file__).resolve().parent
RESEARCH=HERE.parents[1]
RUN='20261017T142624Z-6b84b6ef'

def main():
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));signal.alarm(59)
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    result=json.loads((HERE/'result.json').read_text());audit=json.loads((HERE/'audit-result.json').read_text())
    assert result['status']==audit['status']=='pass'
    records=[
      dict(id='cycle64-new-older-arkworks-product-list-oracle',title='Arkworks older product-list sumcheck: oracle structure and ordering boundary',url='https://github.com/arkworks-rs/sumcheck',
        published='2021-06-07',updated=None,date_evidence='Repository root explicitly labels latest v0.3.0 Jun7 2021. Current master prover file has no visible commit/update date; release-tag fetch failed, so do not pin master code to2021.',
        implementation_license='Repository README labels dual MIT/Apache-2.0; actual GitHub license views returned chrome without terms, raw MIT Internal Error and raw Apache Cache miss. Terms not inspected.',
        inspected_commit_id=None,inspected_urls=['https://github.com/arkworks-rs/sumcheck/blob/master/src/ml_sumcheck/protocol/prover.rs','https://github.com/arkworks-rs/sumcheck/blob/master/LICENSE-MIT','https://github.com/arkworks-rs/sumcheck/blob/master/LICENSE-APACHE'],
        author_claim='Products of MLEs, flattened tables and common maximum degree; source explicitly points to Libra section3.2. Academic prototype warning; BLS12-381 Xeon benchmarks.',
        assessment='NEW older implementation absent from325-record inventory. Product-list oracle design is useful as an independent check, but source evaluates all addends at the common maximum degree and uses adjacent-bit pairs. Native MSB Fp2 grouping cannot be replaced by this LSB/base-field path. No benchmark, library or source executed/copied.',
        access_issues=['v0.3.0 tag Internal Error','raw LICENSE-MIT Internal Error','raw LICENSE-APACHE Cache miss','current file commit/date not exposed']),
      dict(id='cycle64-plonky3-oct16-release-refresh',title='Plonky3 October release refresh: equality and mask-sampling scope',url='https://github.com/Plonky3/Plonky3/releases',published=None,updated=None,
        date_evidence='Current release listing shows p3-sumcheck0.9.0-rc.2 16Oct10:17 without year. Prior cycle independently verified2026 from companion official metadata; both sumcheck and companion docs.rs fetches failed this cycle. No new year-level verification claimed.',
        implementation_license='Current main MIT full text inspected at raw URL; Apache option and tag-scoped license not re-inspected.',inspected_commit_id=None,exposed_uninspected_commit_id='fe5e46d',
        inspected_urls=['https://github.com/Plonky3/Plonky3/releases/tag/p3-sumcheck-v0.9.0-rc.2','https://raw.githubusercontent.com/Plonky3/Plonky3/main/LICENSE-MIT'],
        author_claim='Release includes ordinary/hiding bind+measure, equality-table kernel and CryptoRng fix.',assessment='Known release refreshed with actual relevant PR inspection below. No field/transcript compatibility or runtime gain transferred.',
        access_issues=['Direct release/target commit Internal Error','p3-sumcheck docs Internal Error','p3-multi-stark docs Cache miss']),
      dict(id='cycle64-plonky3-equality-kernel-negative-refinement',title='Plonky3 PR2305: bit order, equality setup costs and small-shape regression',url='https://github.com/Plonky3/Plonky3/pull/2305',published='2026-09-22',updated='2026-09-23',
        date_evidence='PR first author post Sep22 2026, merge Sep23 2026 shown explicitly; no full commit diff inspected.',implementation_license='Main MIT full text inspected; PR-scoped terms not pinned.',inspected_commit_id=None,
        exposed_uninspected_commit_ids=['8e0f9f0','128b24b','cdb48a0'],
        author_claim='One multiplication per Eq-table entry using high=low*c, low-=high; one packed MSB/LSB kernel. Packed base parallel split lost2-5x; extension n14 split slightly slower than serial. Loaded32-thread timings and reviewer64-proof hashes are author/reviewer evidence.',
        assessment='NEW concrete implementation/refinement of previously listed release feature. Material for charging grouped equality setup and testing cutovers; native current eq builder uses two products per entry. Local F tests retain the native builder, so these savings are NOT combined or claimed. No external proof speed reproduced.',
        access_issues=['PR commits listing Cache miss']),
      dict(id='cycle64-mask-rng-obligation-refresh',title='Plonky3 PR2260: fresh unpredictable masks remain required',url='https://github.com/Plonky3/Plonky3/pull/2260',published='2026-09-20',updated='2026-09-20',date_evidence='Author and merge Sep20 2026 explicitly displayed.',
        implementation_license='Main MIT inspected; PR-specific tag terms not pinned.',inspected_commit_id=None,exposed_uninspected_commit_id='876dc37ae82f2fc903cdff5bbd4e014a0b53513a',
        author_claim='Require CryptoRng on mask-sampling entrypoints; predictable seeded stream can reveal unmasked round coefficients.',assessment='No native vulnerability asserted. Public preprocessing reuse cannot reuse masks or weaken their source. The seeded researcher fixtures are arithmetic tests without privacy acceptance.',access_issues=['Exact commit page Cache miss']),
      dict(id='cycle64-statesync-october-prepared-request-boundary',title='StateSync-GKR October paper: prepared requests still charge full-proof delivery',url='https://arxiv.org/abs/2610.14849',published='2026-10-10',updated=None,date_evidence='arXiv v1 history Sat10Oct2026 12:06:57UTC explicitly read.',implementation_license=None,inspected_commit_id=None,
        author_claim='Sparse reduction, reusable preparation and independent request results; reports3.46-4.45x fresh/prepared latency and studies queue/delivery costs.',assessment='Known recent paper refreshed to compare setup boundaries. Sparse circuit-engine study and its assurance model do not establish P1 dense8B throughput. No masks/state openings reused and no author speedup reproduced.'),
      dict(id='cycle64-equality-paper-degree-and-group-claim-contract',title='More Optimizations to Sum-Check Proving: exact per-group applicability',url='https://eprint.iacr.org/2024/1210',published='2024-07-27',updated=None,date_evidence='Primary page receivedJul27 approvedJul29 2024; no revision timestamp displayed.',paper_license='CC BY on primary page',implementation_license=None,inspected_commit_id=None,
        author_claim='Reduced equality-factor cost for eq(w,x)*p(x).',assessment='Known older method materially specialized to actual current F bracket degrees3/1/1 or3/2/2. Three different equality points and true preceding unmasked subgroup claims are required. Synthetic differential is local evidence; paper runtime percentages are not transferred.')
    ]
    previous=[json.loads(x) for x in (RESEARCH/'sources.jsonl').read_text().splitlines() if x.strip()]
    oldids={r.get('id') for r in previous};added=0
    with (RESEARCH/'sources.jsonl').open('a') as f:
      for row in records:
        if row['id'] in oldids:continue
        row.update(cycle='0064',run_id=RUN,access_date='2026-10-17',access_timezone='UTC',recorded_at_utc=now,reproduced_performance=False,evidence_kind='Native LIVE primary search and inspection; external text treated as data; no foreign code executed')
        f.write(json.dumps(row,sort_keys=True)+'\n');added+=1
    (HERE/'source-records.json').write_text(json.dumps(records,indent=2)+'\n')
    handoff='''# Current F-slot grouped equality candidate

Cycle0064, 2026-10-17, `20261017T142624Z-6b84b6ef`. Research-only, unapplied.

The captured trained-lane F zero-check at
`ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs:1602` already
has three equality factors. Add `SlotDef.groups` using existing
`GroupedEqRounds`; polynomial = Eq(tau)*B0 + Eq(p_g)*B1 + Eq(p_u)*B2.
B0 is degree3 with or without padding. B1/B2 are degree1 without a support
table and degree2 with it. The conservative `pad_on` descriptor is safe when
the global pad rule is on but F itself needs no support table (not separately
covered by this harness). Slot degree4, table order and all equality tables
remain. Do not seed subgroup recovery from asserted hosted sums.

[Patch](../experiments/fzc-grouped-equality-20261017/argument-candidate.patch)
and [source pins](../experiments/fzc-grouped-equality-20261017/native-pins.json).
The proposed whole-source file is not compiled as a native crate. Its bracket,
the original full closure, field/helpers/pad code and two real evaluators were
compiled in a standalone std-only harness. Rayon calls are replaced by serial
iteration; no native dispatch, shape door or private proof was executed.
The candidate reconstructs the same full polynomial for extensions/verifier;
it has not proved masked transcript or receipt identity.

72 synthetic fixtures:1,600 evaluator round-value comparisons,960 independent
original-cube values including extension-field off-grid samples,1,512 terminal
words,512 bracket/full values,128 extension-like perturbations. Twelve
controls pass;190 actual subgroup recoveries and98 zero-factor fallbacks,
without resampling. Independent290-check source/work/degree audit passes.
One run7.060s/74,824KiB parent,149,768KiB compiler; audit0.0052s/16,112KiB.
Intel Core Ultra9 185H, CPU0, one thread, nice19,59s/512MiB caps, seed2026101764.
Two harness failures are preserved. No production/native/GPU/receipt gate.

For N=2^n, H=N/2 and nonzero factors, the present host-slot R1d baseline
evaluates its full polynomial9H-4 times. Grouped B0 runs7H-3 times;
each host runs3H-1 unpadded or5H-2 padded times. Independent executed counts
match. Added: three subgroup claims/prefixes, split Eq tables per round,
up to3(n-1) inversions, interpolation and group dispatch/accumulators. All
original table reads/folds stay. No per-proof mask reuse or private cache.

Small N=16 is a negative: grouped time is1.58x unpadded/1.37x padded baseline.
Larger N256/4096/8192 baseline/grouped ratios range1.03-1.42 in a short
shared-host test. N4096 stays in the serial-small arm; N8192 crosses the
common chunk cutoff (the captured parallel arm was serialized). This is
not a stable factor, a p95, a Rayon result or a token/context benchmark.
Timing includes evaluator initialization/rounds/folds/finals; factories,
input copies, serialization and the complete private proof are excluded.

End-to-end ceiling: retained TinyLlamaT128 GPU-assisted diagnostic total
161.857226s, F slot19.484s and masked portion16.457s. Removing the ENTIRE
masked F cost caps direct improvement at1.1132x; removing all F gives1.1369x.
This candidate removes only some of the arithmetic. No corresponding8B F
subclock or5090 measurement exists; no8B ceiling or rate is inferred.

Owner gates: rebase against active F-device lane first; no concurrent edits.
Compile actual crate, run bounded shape/pad/refusal/terminal oracles, compare
masked messages/challenges/finals/RNG continuation and frozen bytes, PCS/M
and shape-privacy obligations, saved receipt and fresh verifier controls.
Then alternate grouped/current F/full-workload timings under shared locks,
including extra table/setup costs and memory. Reject correctness on any
polynomial/degree/refusal/byte difference. Demote for speed if enclosing F or
whole-workload time does not improve. Keep ordinary path available for small
tables if an owner-measured crossover supports it. Do not combine this
synthetic factor with the prior base-constant rewrite or GPU forecasts.
'''
    (RESEARCH/'handoffs/20261017-fzc-grouped-equality.md').write_text(handoff)
    report=f'''# Research cycle0064 — exact F grouped equality

Run `{RUN}`; started2026-10-17T14:26:24Z; checkpoint{now}.
AGENDA/current target and durable/project memory read; latest3 experiment
results and handoffs inspected. Startup snapshots retained; starting325
source records preserved,6 appended (331total). No supervisor/runtime write
or liveness assertion. Saved reports do not establish user-message delivery.

**Result: exact synthetic candidate with a small-table regression; no native
proof speedup established.** F's current three-bracket relation plugs into
the existing grouped evaluator. Original arbitrary-integer semantic equation
and direct original-cube MLE evaluation are independent of that rewrite.
72 fixtures pass, with1600 cross-evaluator round-value comparisons,960
independent original-cube/off-grid checks,1512 terminal words,512 bracket/full
values and128 extension-like perturbations. Twelve mutation controls catch
degree understatements, wrong equality points, asserted-host claim seeding,
helper/activation gating, omitted pad/host terms and helper addressing.
190recoveries/98zero-factor fallbacks; no resampling. Separate290-check audit
also verifies exact affine degree4(full),3(main),1/2(hosts), source boundary
and closed-form executed-call counts. This does not execute a native shape,
masker, transcript, RNG, extension protocol, PCS, receipt or privacy gate.

Experiment `python3 experiments/fzc-grouped-equality-20261017/run.py`:
7.059977s,74824KiB parent,149768KiB compiler. Separate `audit.py`:
0.005162s,16112KiB. Standalone std-only Rust1.97.0 cdylib, no Cargo/crate
build. CPU IntelCoreUltra9 185H, CPU0, one thread, nice19, seed2026101764,
59s wall/CPU and512MiB address caps. Original Rayon scheduling substituted
with serial iteration; n13 exercises the serialized chunk arm. No GPU,
native prover, dependencies, production/Git/receipt/calibration/gate changes,
private payloads or external writes/messages. Full commands, hardware, pins,
output digest and raw source responses are under the experiment directory.
Initial helper-control coverage failure and source-indent audit failure are
preserved with corrections. No live native drift at the independent audit.

Baseline: native F host-slot ClosureRounds.recover_one(None), degree4.
For H=2^(n-1), it invokes the full closure9H-4 times; groups invoke B0
7H-3 times and each host3H-1 unpadded/5H-2 padded. For large n that cuts
main-bracket calls about22.2%, hosts66.7%/44.4%. Added costs are split Eq
setup, weighting, interpolation, up to3(n-1) inversions, dispatch and subgroup
state. Table construction, retained Eq tables, all folds and fresh masks stay.
Source-level counts are not GPU bytes or instruction/time counts.

| synthetic axis bits / table entries | baseline/grouped unpadded | padded |
|---|---:|---:|
|4 /16|0.633|0.731|
|8 /256|1.034|1.095|
|12 /4096|1.367|1.423|
|13 /8192|1.187|1.031|

Four non-warm samples per cell after one discarded first sample; no quiescence
or stable factor/p95. The cutoff and timing variability limit interpretation.
These are generic F-domain dimensions, **not context lengths or proved tokens**.
Factory construction, input copying and serialization excluded. Small-table
negative is preserved; larger speed signals justify owner review only.

Integration: [unapplied handoff](../handoffs/20261017-fzc-grouped-equality.md),
actual `argument.rs::SC_FZC` + `zkp-core::GroupedEqRounds`. The owner currently
ports F to a device; this lane does not duplicate that work or edit its source.
Native acceptance/byte/refusal/privacy/fresh-verifier gates and parent timing
are prerequisites. A mismatch falsifies exactness; unchanged enclosing cost
or setup/dispatch cancellation falsifies a speed benefit.

**Measured owner baseline carried forward, not rerun here.** One cold pass
per arm, actual Llama3-8B8030261248parameters,32linked blocks,T32,16threads,
public weights/P1 intent. Owner saved logs/fresh-verifier records were inspected
in cycle63; current public r4 table and phase report are re-read and pinned.

|clock / scope|CPU|RTX4070Laptop GPU-assisted|
|---|---:|---:|
|whole proving process incl inprocverify(s)|384.542564|391.287091|
|diagnostic32/process positions/s|0.083216|0.081781|
|initial public digest/load(s)|83.012|79.490|
|endpoint seal(s)|0.020|0.044|
|witness(s)|18.629|18.109|
|inclusive prove_run(s)|208.019|213.831|
|block reload within proving(s)|79.222|77.997|
|proof minus witness/reload(s), includes sink/serialization|110.168|117.725|
|inproc verify(s)|93.356|92.741|
|fresh verifier check(s), includes reload|96.103|90.935|
|fresh verifier initial load(s), outside check|80.675|78.635|
|fresh verifier block reload(s), inside check|82.836|77.702|
|first fresh success load+check(s)|176.778|169.570|
|load+seal partial startup fraction|21.595%|20.341%|
|receipt bytes|465815776|465815776|
|owner sampled host RSS(GiB)|1.90|1.57|
|owner sampled VRAM(MiB)|—|2369|

Do not sum arms as throughput samples. Fresh CPU guard456.227s also runs11
controls; GPU169.595s has no control battery. A serial process+first-fresh-check
boundary, if chosen, would be561.320564/560.857091s (diagnostic0.057008/
0.057056positions/s); not a pipeline slope. Full startup/initial-prefill,
isolated serialization, proof-only latency, backlog/lag/drain and steady slope
are unmeasured. Owner GPU is8GB/sm89/36SM (printed8.6GB decimal), not5090;
device driver/build/power/counters were not newly measured. No long-context
prefill sweep, resident-pass sweep or decode here. Accepted target-compliant
new proofs/passes/positions remain0/0/0 because shape privacy acceptance and
independent8B profile review remain open, with no named high-end-device result.

The current owner speed plan is a model, not evidence of50/s: its 5090 T512
estimates include unimplemented kernels and assumed efficiency. Even deleting
all F masked-sumcheck work16.457s from the earlier1.1B T128 GPU diagnostic
161.857226s caps direct gain1.113184x; deleting whole F19.484s caps1.136852x.
No measured8B F subclock exists. This patch affects only part of that work;
there is no8B/5090 rate extrapolation. The earlier full8B proof-remainder
deletion ceiling1.402xCPU/1.430xGPU is far broader than this candidate.

**Ranked hypotheses, all preserve exactness and fresh per-proof privacy:**

1. **Owner: current F/D device arithmetic and full prover residency.** Highest
   potential by present phase measurements, high implementation cost. Requires
   real Fp2, byte/refusal/PCS/M/privacy gates and transfer/scratch accounting.
   Baseline16.457s F masked on1.1B T128; actual8B subclock unknown. F-only
   ceiling above; no native bandwidth/performance measured here. Falsify gain
   if complete enclosing time fails to improve or transfers dominate.
2. **Owner: public digest/load/reload residency across complete fixed-context
   fresh-proof passes.** Actual8B initial83.012/79.490s and proving reload
   79.222/77.997s are measured. Retain authenticated immutable public identity,
   mutation refusals; charge memory, revalidation, IO and startup. Removing
   first load alone cold ceiling about1.275xCPU, not a resident slope. Falsify
   setup-reuse gain if recurring reload/validation costs remain or mutation
   detection fails. Profile pass-count slopes with all receipts freshly checked.
3. **Tested: F three-bracket grouped evaluation.** Modest integration cost;
   compare to the true R1d host baseline, charge Eq/inversions/dispatch. Exact
   local evidence and small-table negative above; native timing gate is owed.
   Do not combine its factor with prior constant factoring or GPU projections.
4. **NEW next local question: is the proposed F-device bandwidth numerator
   measuring logical term traffic or actual buffer/DRAM traffic?** The owner
   plan uses72B*size(F)*17terms/time as a decision metric. Enumerate actual
   table reads/writes, shared columns, folds, base-vs-extension round0, padding,
   allocations/transfers and per-round reuse from captured CUDA/Rust buffers.
   Expected benefit is better kernel prioritization, not a claimed speedup;
   cost is counters/code review, no relation or transcript change. Falsify a
   claimed bandwidth bottleneck if arithmetic/latency dominates after measuring
   actual device counters. No speed ceiling until phases/counters are measured.

Borrowed lookup columns remain a capacity option: deleting even all lookup+
histogram gives only1.004643xGPU on prior trainedT128. Previous grouping/fusion
and support-only negatives remain. No private openings/masks cached.

LIVE sources searched: old Arkworks product-list prover (new here), current
Plonky3 release and concrete Eq/RNG PRs, October StateSync-GKR, Dao/Thaler
equality paper and September author explanation. Six source records preserve
exact primary URLs, access/publication/merge evidence, license scope and
uninspected commit labels. The new older implementation is not transplanted:
it uses adjacent variable pairing and common max-degree evaluations; field,
masking, transcript and terminal binding still need native checks. Plonky3's
Eq setup regressions support retaining measured cutovers; external author's
runtime factors are not local evidence. Exact-target docs/commit/arkworks
license fetch errors are recorded; no permission or network bypass attempted.

Next local: source-level F device/table traffic census; then rotate to
lookup/softmax and proof composition. Next owner: review this small candidate
against active device work and run real acceptance and enclosing timings
under shared locks. No heavy/GPU benchmark was queued or launched.
The >=50proved-token/s complete-private8B target is unchanged and unachieved.
Larger workloads remain allowed; count only fresh verified complete work,
keep resident independent contexts/prefill/decode separate, and charge the
quadratic dense-attention growth of longer contexts.
'''
    progress='''# ZKP efficiency progress

Cycle0064 — `20261017T142624Z-6b84b6ef`, 2026-10-17 UTC.

**Exact synthetic F-slot candidate; no native proof speedup established.**
The current FFN zero-check can use three grouped equality brackets. Seventy-two
fixtures,960 independent original-cube round checks,12 mutation controls and
a separate290-check audit pass. Small tables regress; larger synthetic tests
show1.03–1.42x, with shared-host variability. Main-bracket calls fall about22%
in the large-domain count, while Eq setup/inversions/dispatch add costs.
One CPU thread,7.06s,under147MiB compiler RSS; no GPU/native proof job.
[Unapplied handoff](handoffs/20261017-fzc-grouped-equality.md).

Owner baseline remains one complete functional8B T32 cold pass per arm:
CPU384.54s / RTX4070Laptop391.29s, diagnostic0.08322/0.08178positions/s.
Witness18.63/18.11s; inclusive proving208.02/213.83s includes reload79.22/
78.00s; proof remainder110.17/117.73s includes serialization/sink. Initial
load+seal is21.60%/20.34% of internal total, only a partial startup boundary.
In-process verify93.36/92.74s; fresh check96.10/90.94s plus initialload80.68/
78.64s. Full startup/prefill, isolated serialization and steady slope unknown.
No resident-pass sweep, longer-context sweep or decode ran here. Functional
owner proof evidence is separate from still-open shape privacy/8B review.

Six LIVE primary source records added. Even deleting the whole F masked
sumcheck caps direct gain at1.113x on the earlier trained1.1B GPU diagnostic;
this candidate affects only part. No8B/5090 extrapolation. Next local: audit
actual F-device table traffic against the proposed logical bandwidth metric.
Owner next: native byte/refusal/privacy/fresh-verifier gates and enclosing
timing, coordinated with the active F-device lane and shared resource locks.

Accepted target-compliant new8B proofs/passes/positions:0/0/0. The >=50/s
target remains unchanged and unachieved. Larger workloads may amortize setup
with fresh masks; dense attention can grow quadratically. Production/runtime/
Git/calibration/receipt/gate files untouched; no external messages sent.
[Dated report](progress/20261017T142624Z-6b84b6ef.md) retains clocks and limits.
Saved reports do not establish message delivery or supervisor liveness.
'''
    findings='''

## Cycle0064 — current F three-bracket grouped arithmetic, 2026-10-17

Run `20261017T142624Z-6b84b6ef`. New captured F source test, not a repeat of
generic equality algebra: B0 degree3; two host brackets degree1 unpadded/2
padded. Current ClosureRounds.recover_one(None) baseline is retained and
independently compared to unoptimized rounds and GroupedEqRounds. Full
original-cube arbitrary-integer checks include off-grid extension points,
actual zero-factor fallbacks and separate extension-like polynomial rows.
72fixtures,1600 cross-evaluator round values,960 independent cube values,
1512terminal words,512bracket values,128extension-like values,12controls pass;
190recoveries/98fallbacks. Independent290-check degree/source/work audit passes.
Run7.059977s/74824KiB; compiler149768KiB; audit0.005162s/16112KiB. Seed2026101764,
IntelCoreUltra9 185H/CPU0,one thread,nice19,59s/512MiB limits. Native Rayon
substituted with serial iteration. No native crate/proof/transcript/PCS/privacy
or device gate. Two corrected harness failures retained.

For H=2^(n-1), current full closure9H-4 calls; main bracket7H-3; each host
3H-1 unpadded/5H-2 padded. Added split Eq setup, weighting/interpolation,
up to3(n-1) inversions and subgroup state. Original tables/folds remain.
Small N16 grouped is slower (baseline/grouped0.633/0.731). N256/4096/8192
ratios1.034–1.423; N8192 crosses the serialized chunk cutoff and padded gain
falls to1.031. Shared-host microtiming, not a stable factor or native rate.
Do not multiply it by the prior constant rewrite or a device forecast.

Unapplied `handoffs/20261017-fzc-grouped-equality.md` identifies argument.rs
SC_FZC + existing GroupedEqRounds. Native correctness/bytes/masks/RNG/PCS/M/
shape-privacy and fresh-receipt verification remain owner gates. Active owner
F-device work takes precedence; no duplicate production edit or GPU job here.
Deleting ALL masked F16.457s from prior1.1B GPU161.857226s caps gain1.113184x;
whole F19.484s deletion caps1.136852x. No actual8B F subclock or5090 evidence.

Current owner public table/phase records re-read/pinned;8B T32 onepass perarm
384.542564CPU/391.287091GPU seconds, witness18.629/18.109, inclusiveproof208.019/
213.831 includes reload79.222/77.997 and remaining110.168/117.725. Diagnostic
32/process0.083216/0.081781. Partial startup load+seal21.595%/20.341%; full
startup/prefill and serialization isolated clocks absent. Fresh check96.103/
90.935 plus initialload80.675/78.635. Owner functional freshlyverified stack
evidence remains distinct from target credit; shapeprivacy/8Breview open.
Accepted newlyproved targetpositions0. No resident/decode/longprefill result.

Six LIVE primary records appended (331total). NEW older Arkworks product-list
prover is common-degree, adjacent-pair/MSB incompatible without translation;
not transplanted. Concrete Plonky3Eq PR has author small-shape and parallel
regressions and a one-product Eq fill; local harness deliberately keeps native
two-product fill. October preparation studies do not license private/mask
reuse. Failed target commit/docs/license fetches explicitly retained.

Rank:1owner F/D device arithmetic with full-workload costs;2owner immutable
public residency across fresh complete passes;3tested F grouping, keep small
negative;4NEW local audit of F-device logical-term bandwidth numerator versus
actual table/buffer/DRAM traffic and arithmetic cost. No expected speed without
measured subclocks/counters. Next local: source-captured buffer census, then
lookup/softmax/composition rotation. Full dated report and limits retained.
'''
    (RESEARCH/'progress').mkdir(exist_ok=True);(RESEARCH/'progress'/f'{RUN}.md').write_text(report)
    (RESEARCH/'PROGRESS.md').write_text(progress)
    if f'## Cycle0064 —' not in (RESEARCH/'FINDINGS.md').read_text():
        with (RESEARCH/'FINDINGS.md').open('a') as f:f.write(findings)
    state=f'''# ZKP efficiency explorer — durable state

Cycle0064 COMPLETE: `{RUN}`; checkpoint {now}.
AGENDA/current target,durable/project memory,latest3results/handoffs read.
Startup snapshots:experiments/fzc-grouped-equality-20261017/startup/.
Prior325sources preserved;6LIVE primary records appended,331total.
No supervisor/runtime write or liveness claim. Earlier findings retained.

Tested current F three-bracket grouping at actual Rust seam. Baseline current
host R1d recover_one(None), not old all-samples closure. Independent Python
original-cube equation vs compiled capturedfield/helper/pad/closure/evaluators:
72fixtures,1600roundvalues,960original-cube/offgrid,1512terminalwords,
512bracketvalues,128extension-like polynomialvalues;12controls pass.
190recoveries/98zero-factor fallbacks without resampling. Separate290check
source/work/finite-degree audit0.005162s/16112KiB. Mainrun7.059977s/74824KiB,
compiler149768KiB;one pinnedCPU0/Ultra9185H,nice19,59s/512MiB limits,
seed2026101764. Standalone std-only rustc1.97,no Cargo/nativecrate/GPU.
Original Rayon path serialized; no native transcript/PCS/RNG/privacy receipt.
Two corrected harness failures retained. Final native pin drift at audit:none.

Mainbracketdegree3,hosts1unpad/2pad. H=N/2:baseline9H-4fullcalls,
grouped7H-3main and3H-1/5H-2eachhost. Added Eqsetup,weighting,inversions,
interpolation and groupstate. All originaltables/folds remain. N16regression
ratios.633/.731;larger256/4096/8192ratios1.03-1.42 noisysharedhost.
No stablefactor/nativeprovegain. Unappliedhandoff:
handoffs/20261017-fzc-grouped-equality.md. Review against active ownerGPUF
lane;realshape/bytes/refusal/masking/RNG/PCS/M/privacy/freshverify gates owed.

Owner8B functionaldiagnostics unchanged:onecoldpass,T32,32linkedblocks,
8030261248params,16threads. CPU384.542564/RTX4070Laptop391.287091s;
witness18.629/18.109,inclusiveproof208.019/213.831 includes blockreload79.222/
77.997;remaining110.168/117.725 includes serialization/sink. Initialload83.012/
79.490+seal.020/.044 gives partialstartupfraction21.595%/20.341%;fullstartup/
prefillunknown. Inprocverify93.356/92.741;freshcheck96.103/90.935 plusinitial
load80.675/78.635 (firstsuccess176.778/169.570). Proofbytes465815776each.
Diagnostic32/processrates.083216/.081781;freshCPUguard456.227 includes11
controls,GPUguard169.595 no controls. Do notaggregatearms. Scope/pins/report:
progress/{RUN}.md. No actual8B Fsubclock or5090measurement.

Ranked queue:
1 OWNER:F/D device arithmetic/fullproverresidency. Prior1.1BT128GPU Fmasked
16.457/161.857226s:entiremaskedFdeletionceiling1.113184x;wholeF1.136852x.
No nativegain established here;charge transfers/scratch and fullgates.
2 OWNER:immutablepublic digest/load/reload residency acrossfixedcontext
freshproofpasses. Actual8Bloads dominate T32;charge memory/revalidation,
preserve mutationrefusal/freshmasks;measure workloadslopes,not delete clocks.
3 TESTED:Fthreebracket grouping;smallregression preserved,actualnativeABowed.
Do notcombine factorwithpriorbaseconstantrewrite orGPUforecasts.
4 NEW NEXTLOCAL:does72B*size(F)*17terms/time count logicaltermbytes ratherthan
actual devicebuffer/DRAMtraffic? Source-captureFdevicebuffers;count unique
reads/writes/sharedcolumns,round0fieldwidth,folds,padding/transfers,scratch.
No speedestimate without actualphase/counters. Do notoverride ownerthresholds.

Nextlocal:exactFdevice/tabletrafficcensus,thenlookup/softmax/compositionrotation.
Nextowner:reviewhandoff againstactiveFport,nativecorrectness/bytes/privacy/
freshverification andparentclocks under sharedguard. No heavy/GPUjobqueued.
Borrowedlookups capacity-only;allpriornegativefindings retained.

Acceptedtarget-compliant new8Bproofs/passes/positions0/0/0. Ownerfunctional
freshlyverified8B evidence separate;shapeprivacyacceptance/independent8Breview
open. Steadyrate,totalacceptedrate,fullstartup/prefillfraction,isolated
serialization,prooflag/drain unmeasured. No residentpasses,longcontextprefill
sweep ordecode. Largerworkloads allowed,freshmasks/fullverificationmandatory;
attentioncan growquadratically. >=50/s unchanged/unachieved. No production,
runtime,Git,receipts,calibration,gates,instructions/reviewerwrites;no native
proof/GPU/install/foreignscriptexecution/externalwrite/message/merge.
Nextcycle noearlierthan2026-10-17T15:26:24Z.
'''
    (RESEARCH/'STATE.md').write_text(state)
    print(json.dumps(dict(checkpoint=now,source_records_added=added,sources_total=len(previous)+added,report=str(RESEARCH/'progress'/f'{RUN}.md'))))

if __name__=='__main__':main()
