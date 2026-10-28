"""Persist this cycle's result, ranked queue and owner handoff; research only."""
import datetime, hashlib, json, os, resource, subprocess
from pathlib import Path
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
resource.setrlimit(resource.RLIMIT_CPU,(59,59))
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1];PROJECT=ROOT.parents[1]
RUN='20261019T231854Z-28e6b36b';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
r=json.loads((HERE/'result.json').read_text());assert r['status']=='PASS'
prior=ROOT/'experiments/decode-statement-scopes-20261019'
pins=json.loads((HERE/'input-pins.json').read_text())
for path,name in [
 (PROJECT/'ops/zkp-mvp/trained-1b-review-r8/hashline/src/gpu/cuda.rs','native-cuda.rs'),
 (PROJECT/'results/zk60_1b_native_20261017/r8/manifest_frozen.json','native-manifest_frozen.json'),
 (prior/'native/report.json','carried-report.json'),
 (prior/'native/fid_runs_phases.txt','carried-fid_runs_phases.txt')]:
 data=path.read_bytes();(HERE/name).write_bytes(data)
 pins.append(dict(path=str(path),copy=name,sha256=hashlib.sha256(data).hexdigest()))
(HERE/'input-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
frozen=json.loads((HERE/'native-manifest_frozen.json').read_text())['files']
assert frozen['hashline/src/private_block/trained_block.rs']==hashlib.sha256((HERE/'native-trained_block.rs').read_bytes()).hexdigest()
assert frozen['hashline/src/gpu/cuda.rs']==hashlib.sha256((HERE/'native-cuda.rs').read_bytes()).hexdigest()
rustc='/home/victor/.rustup/toolchains/1.90.0-x86_64-unknown-linux-gnu/bin/rustc'
info=subprocess.run([rustc,'--version','--verbose'],capture_output=True,text=True,check=True,timeout=10)
(HERE/'toolchain.json').write_text(json.dumps(dict(argv=[rustc,'--version','--verbose'],stdout=info.stdout,
 rustc_sha256=hashlib.sha256(Path(rustc).read_bytes()).hexdigest()),indent=2)+'\n')

# Keep detailed inherited hypotheses and negative findings, then rerank/add.
hyp=json.loads((HERE/'prior-hypotheses.json').read_text())
hyp=[h for h in hyp if h['id']!='new-unwrapped-vec-allocation-scope-probe']
tested=next(h for h in hyp if h['id']=='tested-per-call-decode-statement-scopes')
tested['disposition']='Cycle0091: observed original Vec allocations in scalar System analogue at opt0/3; no custom Drop/black_box. Native Rayon/allocator and enclosing clocks still owed.'
tested['prerequisites']+=' New:80 regions,720 independent vector/byte corruption checks,240 event mutations,32 reference/clone masquerades; all pass. Same36 allocations and total requested volume; peak overlap lower in all8 shapes.'
tested['falsification']+=' No elision observed in this specific Rust1.90 build; not a language guarantee or evidence for the production optimizer.'
new=dict(rank=2,id='new-public-device-pool-live-capacity-audit',
 baseline='Frozen R8 cuda.rs already pools buffers,uses exact take and smallest-fitting take_min,retains at most64 cached buffers,and drains/retries on reserve failure. Existing counters are cumulative allocated/reused requested/capacity bytes,not peak live+idle capacity.',
 eliminated_work='Question: can a public shape-driven retention budget avoid dead cached capacities and destructive whole-pool drains while retaining useful scratch reuse across resident complete passes?',
 added_costs='Live/idle event accounting,byte-budget decisions,synchronization needed before reuse/free,capacity slack,possible extra allocations/first-touch; preserve all existing fallback and injected-error gates.',
 end_to_end_ceiling='Unknown: private GPU phase-exclusive allocation/drain clocks absent. CPU commit121.32s is not a GPU pool share. No pooled-byte or hit-count to time multiplier.',
 prerequisites='Next local only: extract and pin take/take_min/put semantics,build bounded event model from public request sizes,compare independent live-capacity oracle and adversarial mixed-size/tail/failure schedules. Owner actual device/enclosing clocks under locks later.',
 integration_cost='Low source/cost model first;medium native allocator policy integration;do not duplicate existing reuse or take_min.',
 exactness='Storage-only changes must leave every read initialized,logical lengths/tails identical,and seeded CPU/GPU transcript/receipt and first-refusal gates intact.',
 privacy_soundness='Cache storage only,never mask contents/private commitments/openings. Fresh per-proof randomization,stream completion and full-write-before-read obligations. D27/D32/D33 scope retained.',
 compatibility='hashline/src/gpu/cuda.rs pool_take,pool_take_min,pool_put,dev_reserve_hard,commit_zk_chunked. No native mutation in research.',
 falsification='No avoidable idle capacity/drain under real public stage requests;all useful cache hits lost;extra first-touch or synchronization dominates;stale/private reads,allocation-error or receipt mismatch.')
hyp.insert(1,new)
for i,h in enumerate(hyp,1):h['rank']=i
(HERE/'hypotheses.json').write_text(json.dumps(hyp,indent=2)+'\n')

body=f'''Run `{RUN}` — cycle0091 — 2026-10-19 UTC.

**No speed improvement measured.** This cycle closes one local evidence gap:
the previous statement-scope finding also holds for observed original Vec
allocations in a scalar analogue, without a custom decoded Drop wrapper.
It does not establish production/Rayon behavior or an elapsed improvement.

Rust1.90.0,edition2021,no dependencies,optimization levels0 and3,one codegen
unit. Eight synthetic shapes (identity/scattered head slots,odd FFN widths,
padding and both inner-map branches),five variants each,80 observed regions.
Original `Array::i8s() -> Vec<i8>` body is copied exactly from pinned R8;
the destination-row pad analogue replaces Rayon iteration with serial rows.
The wrapper forwards allocations to System and records pointer/size/phase
events into a fixed32768B atomic log. Raw inputs and spec maps are prepared
outside regions;outputs/logs are serialized after tracking stops. No
black_box,custom decoded Drop,per-region timing or target-size allocation.
The log itself does not heap-allocate. Compiler elision/merging is permitted
by Rust;these results describe these binaries only,not a language guarantee.

Largest proxy:qh32,kvh8,head_dim4,d128,f448,dp128,fp512,seed2026101991.
This reduces target widths by32;it is NOT a128-token proof or8B allocation.

| Variant | Peak live requested B | Peak decode B | Allocations | Total requested B |
|---|---:|---:|---:|---:|
| Grouped aw/fw statements |419200|172160|36|482848|
| Separate result statements |304384|57344|36|482848|
| Reference-binding negative |460288|213248|36|482848|
| Direct-byte control |247040|0|27|269600|
| Separate results plus clone negative |475648|57344|45|720672|

Opt0 and opt3 match all rows and all output bytes. Local scope saving114816B;
neither allocation count nor aggregate volume changes. All8 fixtures show a
strictly lower region peak. Retained output237824B in the largest proxy is
unchanged. Nine decode allocations remain;the direct-byte control removes
them but still carries the previous unmeasured cast-loop/native cost risks.
The reference-binding and extra-copy variants are value-equivalent and are
correctly rejected when presented as the intended scope implementation.

Independent audit uses a destination-indexed inverse-head-map byte oracle,
pointer-owned allocation replay and separate closed-form phase envelopes.
**1389 checks**,720 vector comparisons,720 one-byte corruptions,240 event
mutations (wrong size,missing allocation,missing free),32 reference/clone
masquerades pass. This is an authored single-agent differential audit,not an
external review. Original source/refusal/record/receipt gates remain owner work.
All byte fixtures and output SHA256s are retained. Audit0.856544s internal,
0.897139s process,18316KiB own HWM (runner child accounting18492KiB).
Compile opt0/3 processes0.568761/0.781899s,HWM136832/138848KiB;
probe processes0.026704/0.005584s,HWM8744/8556KiB. These process clocks include
synthetic output writing and instrumentation,not timed padding improvements.
One nice19 CPU0 affinity on CoreUltra9 185H/WSL2. Probe reports1 thread;
compiler helper-thread count unobserved,one CPU affinity/codegen unit.
Every leaf59s CPU/wall alarm and512MiB AS;no production/native build or GPU.

Baseline/eliminated work/added costs:grouped native5+4 argument temporaries
versus one owned padded result per statement. No decode,copy,pad,IO,hash,
constructor,witness or proof operation removed;only shorter requested-allocation
overlap,with the same frees earlier. Native optimizer,allocator bookkeeping,
threadpool and enclosing critical-path changes are unmeasured.

[MODEL,carried]8B T128 pad envelope638116864->520672256B (112.003906MiB).
Standalone original borrowed full/reload loader peak saving remains **0B**,
because constructor/hash phases dominate. With prior checked moves+post raw
release,current+next+four distinct pinned public blocks1.727765560->
1.618386745GiB. Direct-byte+move+release remains the prior lower1.586862GiB.
These are public payload models,not actual allocator/RSS/VRAM or complete
model fit. No additive peak savings;exclude page cache,allocator slack,JSON,
thread stacks,private witness/proof/serialization/device and extra live leases.
This cycle strengthens only the scalar allocation premise,not these full-loader
or target-size measurements. Falsify promotion on native bytes/first-refusal/
record/receipt/CS/H-1 divergence,already-elided native overlap,no lower actual
whole-loader peak,or enclosing elapsed regression.

Carried owner R8 diagnostic only:8B T128,32 blocks,one16-thread CPU pass,
GPU off,n=1,total478.737s=>0.267370 positions/s diagnostic. Prove_run393.785s
contains witness98.348s,including17.595s block-load tasks. Sealing84.824s
contains overlapping load/witness27.151/80.897s. Commit121.32s/31.0% of
summed391.9s block walls is a larger priority. Receipt922711264B;fresh
verification42.709s+13.681s initial load,recheck34.395s+10.739s load;
guard165.982s includes controls. Do not add nested/overlapping clocks or call
sealing pure startup. Researcher did not reverify this receipt. Even deleting
ALL load tasks leaves433.991s:at most1.103104x and0.294937 positions/s on that
CPU diagnostic,an overbroad bound for this candidate;no high-end GPU forecast.

New independently verified full-stack proofs/passes/positions **0/0/0**;
device/context none. New witness/proof/serialization/verification clocks,
steady-state and total-workload proved rates,startup fraction **unmeasured**.
No long-context prefill,resident complete-proof series or decode ran. Larger
workloads remain allowed;attention can grow quadratically with context.
Complete private8B >=50 proved positions/s on RTX5090 or another named
high-end GPU remains unchanged and unachieved. No private mask/commitment/
opening reuse or privacy weakening. D33 covers only the accepted TinyLlama
T32 pg_rot1 CPU R7 artifact;8B,R8,GPU and next-token stages need their own
scope/re-pin. D27 whole-run security,D32 fidelity and D30 unbuilt status stand.

Integration seam:TrainedExport::load_layer_mode aw/fw statements in frozen
R8 hashline/src/private_block/trained_block.rs (~1037). The prior
review-only-statement-scopes.patch is copied and remains UNBUILT/UNAPPLIED;
no new production diff. Native owner must review/rebase with checked
ownership/raw-release changes,then run full/reload malformed/paired-first-
refusal/record/receipt/CS/H-1 gates and exclusive allocation,HWM and enclosing
clocks under shared build/heavy locks. No merge here.

Queue:hypotheses.json retains prior negatives.1 owner whole-prover GPU and
verified fixed-context resident1/2/4/8;2 NEW device-pool live-capacity audit;
3 checked public constructor transfer;4 tested scopes;remaining raw releases,
direct bytes and public-owner guards are capacity candidates awaiting native
evidence. New pool question follows source facts:exact take plus best-fit
take_min already exist,64 cached buffers bound count rather than bytes,
and cumulative counters are not simultaneous live+idle capacity. Next local:
pin take/take_min/put and extract a public request trace;compare a bounded
event model to an independent live-capacity oracle under mixed-size/tail/
allocation-failure controls. Do not reimplement existing reuse,execute GPU
work,or infer time from hit counts. Owner actual-device clocks remain first.

LIVE sources and exact access/date/license/commit limits are in source-records
and search-log. Recent Chimera Oct16 retains whole-prover residency priority;
GPU NTT older sources distinguish L2 batches from whole memory traffic.
Newly assessed older Huerta2025 register-file/cache and software-dependency
scheduling is a possible future CUDA source-order lead,not a5090 speed claim;
the abstract and HTML differ on simulator error numbers,so none is imported.
No downloaded code executed or author performance reproduced. Current web
release/cache misses and unavailable PDF/license/history reads are recorded.
Rotation next:lookup/softmax and memory/batching;retain NTT/commitments,
sumcheck/GKR,quantization/arithmetic and composition in the queue.

Only research changed;runtime/,production,Git,receipts,calibration,safety,
instructions and reviewer files untouched. No installs,GPU jobs,external
writes/messages,purchases,privilege escalation or foreign code execution.
Saved reports do not establish user-message delivery. Checkpoint {now}.
'''
(HERE/'README.md').write_text('# Cycle0091 — observed Vec allocation scopes\n\n'+body)
(ROOT/'progress'/f'{RUN}.md').write_text('# ZKP efficiency cycle0091\n\n'+body)
with (ROOT/'FINDINGS.md').open('a') as f:f.write('\n\n## Cycle0091 — original Vec allocation-scope evidence\n\n'+body)
handoff=f'''# Owner handoff — original Vec allocation-scope evidence

{RUN};2026-10-19 UTC. **Capacity evidence only;no speed gain measured.**

Interface unchanged:`Array::i8s()->Vec<i8>` and pad_matrix outputs. Frozen R8
TrainedExport::load_layer_mode aw/fw initializer seam. Patch location:
experiments/vec-allocation-scopes-20261019/prior-review-only-statement-scopes.patch
(copied cycle0090 diff). Production diff remains UNBUILT/UNAPPLIED.

New validation:Rust1.90 opt0/3 original Vec/System allocation events,8 synthetic
shapes x5 modes x2 builds=80 regions. Independent destination oracle and event
formulas:1389 checks,720 corrupted vector controls,240 event mutations,32
reference/extra-clone masquerades. Largest reduced proxy peak419200->304384B;
same36 allocations/482848B total. All output bytes equal. Source and binary
pins,commands,seed2026101991,logs,synthetic output bins and hardware retained in
experiments/vec-allocation-scopes-20261019/. No custom decoded Drop/black_box.

Limits:scalar row analogue,not native Rayon;System requested sizes,not usable
capacity/RSS/VRAM;optimizer may elide allocations in other builds. Unchanged
standalone loader modeled saving0B;112.003906MiB target pad overlap and prior
move/release composition are models only. Same total work/free count remains.
All-load-deletion bound1.103104x is much broader than this candidate,CPU only.

Owner action:review/rebase with checked moves/raw release,run native full/
reload byte/first-refusal/record/receipt/source-freshness/CS/H-1 gates,and
measure actual allocator live/peak plus enclosing clocks under shared locks.
Reject changed bytes/refusals/lifetime,whole-loader peak erasure or elapsed
regression. No private masks/commitments/openings reused;no privacy scope
promotion. New verified proofs/passes/positions0/0/0;50/s target unachieved.

Next local work redirects to the existing GPU buffer pool's simultaneous
live+idle capacity,not another loader variant. Whole-prover device and
verified resident1/2/4/8 workloads remain the main end-to-end priority.
'''
(ROOT/'handoffs/20261019-vec-allocation-scopes.md').write_text(handoff)
progress=f'''# ZKP efficiency progress

Cycle0091 complete — `{RUN}` —2026-10-19 UTC.

**No speed improvement measured.** Original Vec/System allocation probe
confirms shorter overlap in a scalar pad analogue:largest reduced fixture
419200->304384B peak requested,identical outputs at Rust opt0/3. Same36
allocations and482848B total.80 regions;independent audit1389 checks,720
corruptions,240 event mutations,32 reference/clone negatives. Native loader,
Rayon,RSS/VRAM and enclosing-time gains remain unknown;patch unbuilt/unapplied.

New verified complete proofs/passes/positions **0/0/0**;device/context none.
New witness/proof/serialization/verification clocks,steady/total proved rates
and startup fraction unmeasured. Carried owner CPU diagnostic only:8B T128,
32 blocks,one16-thread pass,GPU off,total478.737s(0.267370 positions/s),
prove_run393.785s includes witness98.348s;fresh verify42.709s+13.681s load.
Researcher did not reverify it. No long-context,resident proof series or
decode ran;larger workloads allowed,attention may grow quadratically.
Complete private8B >=50 proved positions/s on RTX5090 remains unachieved.

LIVE search covered GPU NTT/commitments,sumcheck/GKR and Rust allocation
semantics;new older register-file scheduling lead screened. Sources and
access/cache blockers saved. Seam:load_layer_mode aw/fw;owner owes native
gates/clocks. Next local:existing GPU pool live+idle capacity audit;whole-
prover GPU and verified resident1/2/4/8 remain first. No mask/opening reuse.

[Experiment](experiments/vec-allocation-scopes-20261019/README.md),
[handoff](handoffs/20261019-vec-allocation-scopes.md),
[dated report](progress/{RUN}.md). Only research changed;no delivery implied.
'''
(ROOT/'PROGRESS.md').write_text(progress)
state=f'''# ZKP efficiency explorer — durable state

Cycle0091 COMPLETE:`{RUN}`,2026-10-19 UTC. Checkpoint {now}.
Next cycle no earlier2026-10-20 00:18:54 UTC;deadline was23:38:54 UTC.
Startup snapshots and full findings/source read index:
experiments/vec-allocation-scopes-20261019/.

**No speed improvement measured.** Original Vec decode API/System allocator,
scalar native pad analogue,Rust1.90 opt0/3:no custom decoded Drop/black_box.
80 regions,8 geometries,5 variants. Largest reduced proxy419200->304384B
live requested peak,decode172160->57344B;36 allocations/482848B volume
unchanged. Direct-byte27allocs,reference negative460288B,clone negative
45allocs/475648B. Outputs byte-equal. Independent audit1389 checks,720
corruptions,240 event mutations,32 masquerades. Seed2026101991. Opt0/3
compile0.568761/0.781899s,136832/138848KiB;probe0.026704/0.005584s,
8744/8556KiB;audit0.856544s,18316KiB. Nice19,CPU0,CoreUltra9 185H,WSL2;
probe1thread,compiler helpers unobserved/one CPU affinity and codegen unit.
Every leaf59s CPU/wall,512MiB AS. Actual production/Rayon/RSS/VRAM/clocks
unknown. No production compile/proof. Prior scope patch copied,unbuilt/unapplied.

[MODEL,carried]8B T128 pad638116864->520672256B(112.003906MiB),standalone
borrowed full/reload loader peak saving0B. Prior moves+post release+four
distinct pins/current+next1.727765560->1.618386745GiB. Direct-byte composition
lower1.586862GiB model. Models exclude private proof/witness/device/allocator/
cache/slack and are not complete-model fit or elapsed measurements.

Carried R8 diagnostic only:8B T128,32 blocks,one16-thread CPU pass,GPU off,
total478.737s=>0.267370positions/s. Prove_run393.785s includes witness98.348s
and its17.595s loads;sealing84.824s overlaps27.151s load/80.897s witness.
Commit121.32s/31% summed block walls. Receipt922711264B;fresh verify42.709s
+13.681s load,recheck34.395s+10.739s load;guard165.982s includes controls.
Researcher did not reverify. All-load deletion bound1.103104x CPU only,
much broader than candidate. Startup,steady slope,isolated serialization unknown.

New independently verified full-stack proofs/passes/positions **0/0/0**;
device/context none. New witness/proof/serialization/verification clocks,
steady/total proved rates,startup fraction unmeasured. No long-context prefill,
resident proof series or decode ran. Larger workloads allowed;attention may
grow quadratically. Target complete private8B >=50positions/s RTX5090 or
named high-end GPU unchanged/unachieved. No masks/private openings reused.

Ranked hypotheses:1 owner whole-prover GPU+verified fixed-context resident
1/2/4/8;2 NEW device-pool simultaneous live+idle capacity;3 checked public
constructor transfer;4 tested scopes;5 split raw release;6 postconstructor
release;7 direct bytes;8 guarded public owner. Details/costs/falsifiers:
experiments/vec-allocation-scopes-20261019/hypotheses.json.

Next local:pin cuda.rs pool_take,pool_take_min,pool_put,commit_zk_chunked
and build a bounded public request/event census. Exact and best-fit reuse
ALREADY exist;64 cached buffers bound count,not bytes;cumulative counters
are not peak live+idle. Compare independent live-capacity oracle using
mixed-size/tail/returned-buffer/one-shot-allocation-failure negatives. First
derive actual public call sizes;do not invent a stage trace or call private
content reusable. Measure no GPU here. Owner owes device timing,full-write-
before-read/stream completion,CPU/GPU bytes/refusal/privacy gates under locks.
Falsify on no avoidable retention/drain,loss of useful reuse,or overhead.
No repeat of completed loader/digest-only/LRU/registry-only microvariants.

LIVE literature:Rust allocator/System,Chimera Oct16,GPU NTT/Goldilocks,
Plonky release/RNG and older Huerta register-file scheduling. Sources/date/
license/commit scope and fetch/cache errors recorded;no author performance
reproduced or foreign code executed. Next rotation lookup/softmax and
memory/batching;retain NTT,SC/GKR,quantization/arithmetic,composition.

D33 only accepted TinyLlama T32 pg_rot1 CPU R7;R8/8B/GPU/next-token need
their scope/re-pin.D27/D32,D30 unbuilt bind. Only research written;
runtime/,production,Git,receipts,calibration,safety,instructions/reviewer
files untouched. No GPU/install/external write/message/purchase/escalation.
Saved reports imply no delivery. Handoff:handoffs/20261019-vec-allocation-scopes.md.
'''
(ROOT/'STATE.md').write_text(state)
print(json.dumps(dict(checkpoint=now,status='COMPLETE',hypotheses=len(hyp),input_pins=len(pins))))
