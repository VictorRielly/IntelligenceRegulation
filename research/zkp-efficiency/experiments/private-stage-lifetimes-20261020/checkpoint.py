"""Publish research-only checkpoint/report; preserve all prior findings."""
import datetime,hashlib,json,pathlib
H=pathlib.Path(__file__).resolve().parent;R=H.parent.parent;P=R.parent.parent
RUN='20261020T021854Z-e084e681'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
res=json.loads((H/'result.json').read_text());model=json.loads((H/'model-result.json').read_text())
def dump(n,v):(H/n).write_text(json.dumps(v,indent=2)+'\n')
hypotheses=[
dict(rank=1,title='Owner whole-prover high-end GPU plus verified fixed-context resident1/2/4/8',baseline='Carried CPU8B T128 total478.737s; one-slot/device results do not cover the whole prover.',eliminated_work='Recurring CPU proof work and genuinely once-per-workload model/device setup.',added_costs='Transfers,witness,all fresh masking,serialization,pipeline drain,independent verify.',prerequisites='Owner native device lane,complete phase clocks,actual fit,privacy/source pins,shared heavy/build locks.',integration_cost='Large; owner work, no GPU authority here.',exactness='Original full attention+FFN relation and refusals.',privacy_soundness='No mask/opening reuse; every counted full receipt independently verifies and meets current scope.',compatibility='Existing Rust/CUDA native lane.',end_to_end_ceiling='Unknown until measured complete workload slope; no CPU/kernel projection to50/s.',falsification='Recurring full-proof rate below50/s,failed coverage or fit,or backlog grows.'),
dict(rank=2,title='Exact DD D30 owner prototype; status corrected from prior unbuilt entry',baseline='Native R9 source/count report: T128 A/H3405/3790; previous T51220.82% count is only an anchor.',eliminated_work='Counted T128 A/H3283/3634 (-3.86% committed words); no elapsed saving verified here.',added_costs='Dictionary,additional bound slot/lookup terms and capacity/refusal checks.',prerequisites='Owner code review,full relation/soundness/privacy/fidelity review and independently verified full receipts.',integration_cost='Owner prototype exists: retained log has85 tests passing,1ignored,519filtered. Not rerun here.',exactness='D30 exact arithmetic and every declared binding retained.',privacy_soundness='D27 whole-run security,fresh masking,new-profile review; tests are not privacy acceptance.',compatibility='Owner R9; this experiment pins R8 baseline and active GPU source separately.',end_to_end_ceiling='Unknown; no native DD complete-stack timing established here.',falsification='Over-cap/refusal/binding failure or full-workload overhead erases gain.'),
dict(rank=3,title='REFINED complete private-stage device capacity trace before any pool change',baseline='This cycle: simultaneous logical owners A/H/M,previous+current boundaries,OUT; M encoded buffer is CPU only.',eliminated_work='Only actual idle capacity or scratch overlap exposed by complete native phase evidence.',added_costs='Public-role lifecycle telemetry,capacity rather than requested length,completion edges and local timing.',prerequisites='Instrument raw+pooled+idle+cache+driver capacity and transient commit/open/sumcheck phases. Source accounting alone cannot locate actual HWM.',integration_cost='Small telemetry hook; broad enclosing measurement and owner locks required.',exactness='No arithmetic/transcript/order changes.',privacy_soundness='Log public role/stage/shape only; no addresses/values/private challenge material in public receipts.',compatibility='prove_run_with/prove_core/Pooled and raw allocation seams in pinned sources.',end_to_end_ceiling='No gain established; prerequisite for useful capacity/performance choice.',falsification='Native coverage already complete or no avoidable capacity in actual peak phase.'),
dict(rank=4,title='Prior checked public-loader ownership/scopes',baseline='Existing prior copy/overlap evidence; not repeated this cycle.',eliminated_work='Previously identified public array copies/overlap.',added_costs='Lifetime plumbing,all digest/refusal checks unchanged.',prerequisites='Native owner review/measurement.',integration_cost='Small/medium prior review candidates.',exactness='Same checked bytes and first refusal.',privacy_soundness='Only public model material cached; no private masks/openings.',compatibility='TrainedExport::load_layer_mode.',end_to_end_ceiling='Earlier all-load removal CPU bound1.103104x; candidate narrower,not GPU forecast.',falsification='Native compiler/allocator already removes cost or whole workload regresses.'),
dict(rank=5,title='NEW output-only device residency eviction; demoted by bounded capacity result',baseline='OUT owner sealed before run and held until final stage. Earlier logical release is forbidden.',eliminated_work='No proof arithmetic. At8B T128,L32,modeled persistent device owner storage falls23.125MiB resident or5.197265625MiB chunked (~0.51/0.56%).',added_costs='Keep host data,pads,salts/tree; restore/reencode device material with exact old randomness; completion and targeted backing reuse/free. Dropped pooled buffers stay allocated: resident23.125MiB remains idle; chunked4.625MiB remains idle,only0.572265625MiB raw could free directly.',prerequisites='Actual OUT residency/peak contribution; native exact hiding reencoding and stream safety; all original receipts/refusals/privacy checks.',integration_cost='Unimplemented. No eviction patch recommended absent a measured capacity cliff.',exactness='36 toy byte fixtures match immutable reference; native NTT/PCS/masks/receipt equivalence untested.',privacy_soundness='One logical owner/one opening; fresh proof randomness unchanged. Storage residency is distinct from recreating/reusing commitments.',compatibility='Run external OUT and DevCommit data/enc/ZkReenc; no active-source edit.',end_to_end_ceiling='No measured gain; <=one OUT owner in this partial capacity model,not a latency/VRAM bound. Initial seal/transient peak may erase any global saving.',falsification='OUT host-backed,peak elsewhere,no backing reclaimed/reused,or reencoding/transfers regress full proof.'),
dict(rank=6,title='Release A/M/H or boundary owners earlier without rematerialization',baseline='Explicit drops already immediately follow sole openings in both pinned trees.',eliminated_work='0 requested logical owner bytes under unchanged schedule.',added_costs='Any earlier drop loses slot data/opening storage or one adjacent boundary claim.',prerequisites='Separate storage-representation change would be a different hypothesis.',integration_cost='None proposed; rejected.',exactness='330 negative controls include early/missing/double/misbound openings and pool-accounting errors.',privacy_soundness='Never open a boundary twice or omit its consumer claim.',compatibility='Existing source already follows earliest legal post-opening release.',end_to_end_ceiling='Zero release-only opportunity in modeled pinned schedule.',falsification='A native owner is shown to survive beyond its last required opening; not found here.'),
dict(rank=7,title='NTT direct output order and same-degree composition remain in rotating queue',baseline='SP1 September ordering diff/October release and previous gnark batching lead.',eliminated_work='Only demonstrated redundant native reorder or compatible scheduling overhead.',added_costs='Consumer remapping or protocol binding changes,possibly retained tables.',prerequisites='Native order/dependency census; independent DFT oracle or separate composition proof.',integration_cost='Unknown/high for protocol changes.',exactness='All codewords/column indices and current frozen profile preserved.',privacy_soundness='Whole terminal binding,fresh masks,exact current proof byte contract or versioned review.',compatibility='Upstream field/backend/proof format differs.',end_to_end_ceiling='Unknown; zero if native already consumes produced order.',falsification='No native redundant reorder or degree/dependency constraints forbid batching.')]
dump('hypotheses.json',hypotheses)
report=f'''# Cycle0094 — private-stage commitment lifetimes

Run `{RUN}`, checkpoint {now}. **No proving speed improvement found.**

The leading executable question was whether releasing private-stage owners
earlier could remove retained device capacity. The pinned source already drops
M, A and H immediately after their sole openings. An internal boundary is
opened in its consumer stage, after BOTH adjacent claims exist; moving it to
the producer stage fails the dependency oracle. Logical owners cannot be
released earlier under the unchanged schedule. Returning their `Pooled` buffers
to idle does not itself free device backing.

The baseline is source-derived, not a runtime trace. `prove_run_with` starts
with IN/OUT, commits current B before the core, retains previous B, runs the
core, opens the incoming owner, opens OUT only at the last stage, serializes
and sinks one segment, then hands current B to the next stage. The core commits
A, M, H, runs23 slots, and opens/drops M, A, H in that order. Source pins cover
native R8 and the separate active GPU candidate. They are different revisions:
R8's stage-specific shape differs from the older GPU door. Numeric geometry is
R8 f_e9,8B T32/64/128; this is no assertion that the active GPU tree supports
the newer complete workloads. M's50x4096 encoded field buffer is HOST memory,
not a device PCS owner (1.5625MiB encoded payload, other mask buffers excluded).

Independent authored single-agent checks pass: **{res['checks']} checks,
{res['negative_controls']} negative controls**,6 traces with1/2/3/4/8/32 BLOCKS,
36 public-capacity cases and36 synthetic byte fixtures; seed2026102094.
The reference derives owner/read/claim/open obligations from adjacent-block
relations, checks interval overlaps separately from the forward simulator,
and compares immutable host checksums with output cache eviction/restore.
It rejects premature/missing/double openings, incorrect boundary claim sides,
wrong stage/read/open order, missing sink, stale/short restore and pooled-free
misaccounting. These are accounting/193-byte toy storage tests, not native
polynomials, hiding encodings, masks, transcripts, receipt bytes or verification.

A new, separate question from SlackSwap/vDNN is whether OUT's device backing
can be evicted while retaining its logical owner until the last stage. It is
**demoted**, with no native patch recommended. At T128,32blocks,row2^14:

| Hypothetical store policy | Persistent-owner device subset | With OUT device backing omitted until final opening | Difference |
|---|---:|---:|---:|
| All resident |4568.750MiB|4545.625MiB|23.125MiB (0.506%)|
| All chunked |930.527344MiB|925.330078MiB|5.197266MiB (0.559%)|

Both are public requested-storage models, not actual VRAM, hardware fit or
full peaks. Mode/threshold and allocation success determine real mixed stores.
At this subset's maximum, live owners are A/H/M, previous B,current B,OUT;
M adds no GPU bytes. Host data/pads/salts/tree persist. The model omits
initial endpoint sealing transients, commit/open scratch, raw sumcheck tables,
idle/oversized pool backing, twiddles,FZC public cache, driver allocations,
proof vectors and other host memory. Thus the actual peak phase remains unknown.
Naive output-device drop moves23.125MiB to idle in resident mode, releasing
ZERO pooled backing; in chunked mode4.625MiB becomes idle and only0.572266MiB
raw pads/powers could be directly freed. Restoring needs the original hiding
material and exact encoding/copy work, not new random masks. Whole-workload
time benefit is unknown and can be negative. Initial seal or scratch peaks can
erase any global saving. The tested release-only hypothesis has zero opportunity
within the unchanged schedule; physical storage changes are different work.

Final model leaf: {model['wall_seconds']:.6f}s/{model['rss_kib']}KiB;
audit: {res['wall_seconds']:.6f}s/{res['rss_kib']}KiB. One nice19 CPU0 thread,
Intel CoreUltra9 185H,Python3.10.12/WSL2; leaf CPU/wall59s and512MiB AS caps.
These are harness validation clocks. Three initial extraction failures
(prover/verifier duplicate anchors,stage-shape spelling) and one later Python
indentation failure are retained in commands/logs; corrected runs pass.

Status correction discovered while reading owner public counts: D30/DD is no
longer wholly unbuilt. `r9_counts.json` and `r9-check.log` show counted T128
layouts and85 tests passing/1ignored/519filtered, including a generic DD proof
test. At8B T128,owner counts A/H3405/3790 ->3283/3634 (-3.86% words), smaller
than the earlier20.82% T512 anchor. This log was not rerun here. It establishes
neither independently reviewed DD full-stack throughput nor privacy acceptance.
The experiment retains the R8 baseline; no R9 production/source edit occurred.

New independently verified complete proofs/passes/positions **0/0/0**.
New token context/device none; CPU-only synthetic/accounting scope. New witness,
proof,serialization and verification clocks; steady-state and total-workload
proved rates; startup fraction all **unmeasured**. No long-context prefill,
resident-model complete-proof series or decode ran. Blocks in a trace are not
model passes. Carried owner CPU8B T128,32blocks,one16-thread pass,GPUoff:
total478.737s,0.267370positions/s; prove_run393.785s contains witness98.348s
and load17.595s; sealing84.824s overlaps witness/load. Receipt922711264B;
fresh verify42.709s+13.681s load, recheck34.395s+10.739s load. Not reverified.
Startup/steady/isolated serialization unknown; nested clocks must not be summed.
The newer CPU next-token501.6/529.2s owner workloads remain distinct.

LIVE sources searched: [SlackSwap](https://arxiv.org/abs/2610.13003),
[vDNN](https://research.nvidia.com/publication/2016-10_vdnn-virtualized-deep-neural-networks-scalable-memory-efficient-neural-network),
[ICICLE NTT/release](https://github.com/ingonyama-zk/icicle/releases/tag/v4.0.0),
[SP1 NTT diff](https://github.com/succinctlabs/sp1/pull/2990/files),
[zkLLMPoT](https://arxiv.org/abs/2610.08258),
[matched NTT/sumcheck study](https://arxiv.org/abs/2606.16146),
[archived zkLLM](https://github.com/jvhs0706/zkllm-ccs2024).
Seven records appended531->538. Exact dates/unknown dates,license scope and
inspected/unresolved commits are saved. SlackSwap is a simulation; vDNN is
older training evidence. No author performance reproduced. ICICLE full commit
6c77775961b0e4dc2be359feec1ac11536c18043 is a VERSION change only. ICICLE
repository and zkLLM MIT texts inspected; SP1 license/full PR commit and the
backlinked fork5090 PR fetches failed. No performance claim from that fork.

Rankings and baseline/eliminated work/added costs/ceilings/falsifiers are in
hypotheses.json. First owner action remains whole-prover high-endGPU clocks
and independently verified fixed-context resident1/2/4/8 workloads. Next local
experiment: add exact source-derived H-commit and FZC/DZC raw scratch intervals
to this owner trace, check overlapping/deferred-opening controls, and specify
native per-phase actual capacity counters. Do not repeat the release-only or
fallback staging experiments. No eviction build without an actual capacity cliff.

Integration seam: `prove_run_with` (R8 run.rs917..1031; GPU684..791),
`prove_core` (R8 protocol.rs1018..1172; GPU882..1039), and `DevCommit`/`Pooled`
in cuda.rs. The handoff provides telemetry fields/phase points; no production
patch, build, integration or merge. Native phase/memory counters, complete GPU
receipts,independent verification and current security/privacy gates remain
owner work under shared build/heavy locks. D33 remains scoped to its accepted
R7 artifact; D34 accounting does not accept new profiles. D32 fidelity and D27
whole-run obligations persist. No mask reuse or privacy weakening.

Complete private8B >=50 proved tokens/s on RTX5090/another named high-end GPU
is unchanged and unachieved. Larger workloads may amortize startup; increasing
context can increase attention work quadratically. Only research changed,
excluding runtime; no GPU,build,install,Git,external write/message,purchase or
escalation. Saved reports are not evidence of delivery to Victor.
'''
(H/'README.md').write_text(report+'\nReproduce from research root:\n\n```\npython3 -B experiments/private-stage-lifetimes-20261020/run_bounded.py model.py\npython3 -B experiments/private-stage-lifetimes-20261020/run_bounded.py audit.py\npython3 -B experiments/private-stage-lifetimes-20261020/run_bounded.py validate.py\n```\n')
(R/'progress'/f'{RUN}.md').write_text(report)
with (R/'FINDINGS.md').open('a') as f:f.write('\n'+report)
progress=f'''# ZKP efficiency progress

Cycle0094 complete — `{RUN}` — {now}.

**No proving speed improvement found.** The private prover already releases
A/M/H immediately after their openings; boundaries must wait for the next
stage's claim. Release-only optimization saves zero modeled owner storage.
M's encoded buffer is on the CPU. Dropped pooled buffers remain allocated.

{res['checks']} independent authored accounting checks and {res['negative_controls']}
negative controls pass;6 traces,36 capacity cases,36 toy byte fixtures.
An output-only GPU residency idea is demoted: modeled8B T128 persistent-owner
storage reduction only5.20MiB chunked (~0.56%),mostly returned to idle pool.
No measured VRAM/time gain,eviction patch or native proof.

New independently verified complete proofs/passes/positions **0/0/0**;
token context/device none. New witness/proof/serialization/verification clocks,
steady-state/total-workload proved rates and startup fraction **unmeasured**.
No long-context,resident complete-proof series or decode. Private8B >=50/s
RTX5090/high-endGPU target unchanged and unachieved. No masking/privacy change.
Carried CPU8B T128 one16-thread pass,GPUoff,total478.737s,not reverified.

LIVE: SlackSwap,vDNN,ICICLE,SP1,zkLLMPoT,NTT/sumcheck study,zkLLM;
seven source records. SlackSwap is simulation,not reproduced prover evidence.
Owner DD status corrected: an R9 prototype/count/test log now exists;
full-stack DD timing/privacy acceptance not established here.

Next: source-map H-commit and raw FZC/DZC scratch alongside this owner trace.
Owner completeGPU phase clocks and verified resident1/2/4/8 remain first.
[Experiment](experiments/private-stage-lifetimes-20261020/README.md),
[handoff](handoffs/20261020-private-stage-lifetimes.md),
[dated report](progress/{RUN}.md). Saved reports imply no message delivery.
'''
(R/'PROGRESS.md').write_text(progress)
(R/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle0094 COMPLETE `{RUN}`, checkpoint {now}.
Deadline02:38:54UTC; next cycle no earlier2026-10-20 03:18:54UTC.
Evidence:experiments/private-stage-lifetimes-20261020/.

No proving speed improvement found. Source-pinned private-run schedule:
M/A/H drop immediately after their sole opening; boundary waits for BOTH
adjacent claims and opens in consumer stage. No earlier logical release.
M50x4096 encoded payload is CPU only. Pooled drop returns idle backing.
{res['checks']} independent authored source/dependency/interval/byte checks,
{res['negative_controls']} negatives;6 traces,36 capacity cases,36 toy byte fixtures;
seed2026102094. No native proof/security review implied.

NEW output-only GPU residency eviction demoted. AtR8 8B T128,32blocks,row2^14:
resident persistent-owner subset4568.75->4545.625MiB;chunked930.527344->
925.330078MiB (~0.56%). These omit transient/scratch/idle/cache/driver costs,
not nativeVRAM/fit/time. Resident drop23.125MiB becomes idle,0pooled freed;
chunked4.625MiB becomes idle,only0.572266MiB raw could directly free.
Original host owner,pads,salts/tree and single opening must persist;restore
needs exact encoding and measured copies/completion. No native patch/build.

CORRECTION:DD D30 ownerR9 is no longer wholly unbuilt. Read-only owner log:
85pass/1ignored/519filtered,including genericDD proof test and countedT128.
8B T128 A/H3405/3790->3283/3634 (-3.86% words),not20.82%T512 anchor.
Not rerun;no independently reviewed full-stackDD time/privacy inferred.

Carried CPU8B T128,32blocks,one16-thread pass,GPUoff,total478.737s=>0.267370
positions/s;prove_run393.785s contains witness98.348/load17.595;sealing84.824
overlaps witness/load. Receipt922711264B;fresh verify42.709+13.681load,
recheck34.395+10.739load. Not reverified. Startup/steady/serialization unknown.
Newer CPU next-token501.6/529.2s owner workloads remain distinct.
New independently verified full-stack proofs/passes/positions0/0/0;
token context/device none;new witness/proof/serialization/verify clocks,
steady/total rates/startup fraction unmeasured. No long-context,resident
complete passes or decode. Larger workloads allowed;attention can growT^2.
Private8B >=50/s RTX5090/high-endGPU target unchanged/unmet.

Ranked:1owner whole-proverGPU+verified resident1/2/4/8;2DD ownerprototype;
3actual phase/capacity coverage;4prior publicloader;5output residency(demoted);
6release-only(rejected);7NTTordering/composition. Full obligations in hypotheses.json.
Next local:derive H-commit transient and FZC/DZC raw-scratch lifetimes alongside
these owner intervals;include chunked deferred openings,all raw/cache capacity
and independent overlap controls. Native actual peak phase still unknown.
Do not repeat release-only or all-resident fallback staging;do not recommend
output eviction without an actual capacity cliff. Owner locks/native counters,
fullreceipt verification/privacy gates remain necessary.

LIVE531->538:NEWSlackSwap(Oct9simulation),NEWoldvDNN(Oct15,2016),ICICLE,
SP1recentrelease/orderdiff,zkLLMPoT,NTT/sumcheck,archivedzkLLM. Exact URLs,
verified/unknown dates,scopedlicenses/full vs unresolvedcommits and failures
saved. No foreign code executed or performance reproduced. Next rotation
sumcheck/GKR,quantization/arithmetic,composition,amortization;retainNTT,
lookup/softmax,memory. Handoff:handoffs/20261020-private-stage-lifetimes.md.
Onlyresearch(excludingruntime) changed;no native/GPU/Git/install/external
messages/writes/purchases/escalation. D27/D32/D33/R7/D34 scopes preserved.
No masks/openings reuse or weakenedprivacy. Reports imply no delivery.
''')
handoff='''# Private-stage lifetime accounting for owner review

No optimization patch is proposed. Release-only saves no work in the pinned
schedule; output-only residency eviction is too small to justify a build
without a measured capacity cliff. This handoff is an accounting/telemetry
interface, not an integration request or security acceptance.

Research code: `experiments/private-stage-lifetimes-20261020/model.py` and
`audit.py`; source line anchors/hashes in source-facts.json/source-manifest.json.
R8 run.rs917..1031 and protocol.rs1018..1172; separate GPU candidate
run.rs684..791 and protocol.rs882..1039. R8 stage-specific shape is distinct
from the older GPU door. Never assume these trees have equal supported profiles.

Observed source order: OUT retained across the run; previous/current boundary
coexist in intermediate stages; A/H coexist until their openings; M is host
encoded, not a GPU PCS commitment. A/M/H already drop after their openings.
Boundary opens exactly once with both adjacent claims. Pool drops retain idle
backing. Chunked DevCommit additionally retains raw pads and powers.

Proposed LOCAL telemetry event (not public receipt data):
`stage,phase,role,public_geometry,store_mode,requested_data_bytes,
actual_pooled_active_capacity,pooled_idle_capacity,raw_active_bytes,
twiddle_capacity,public_cache_capacity,driver_free_delta,completion_epoch`.
Roles A,H,IN,OUT,B_previous,B_current,mask_host,constructor_scratch,
opening_scratch,FZC/DZC raw tables. M host bytes reported separately.
Use public stage/shape metadata and allocator capacity; no values,addresses,
prompt-dependent logs,randomness or challenge material. No caches of masks.

Phase points: before/after boundary prepare; A commit; M host commit;
H commit; raw sumcheck construction/finalization; mask opening; A/H opening
and drops; incoming boundary/endpoint opening; output opening; serialization
and sink. Record commit/open transients inside cuda.rs as well as phase ends;
sampling just phase ends misses scratch peaks. Completion must precede any
reuse/free. Keep actual device counts/VRAM and CPU/driver/build pins.

Current tests: independent declarative relation/dependency oracle and interval
capacity checker; toy storage checksums only. Run commands in README. Earlier
releases/double openings/wrong boundary sides/stale restores are negatives.
No native Rust/CUDA build,mask/NTT/PCS/receipt differential or GPU run occurred.

Owner validation: complete phase/backing counters on a supported workload,
strict device/fallback accounting,actual peak and transfer clocks; exact
native receipt bytes and independent fresh verifier; current refusal,H-1,
soundness/privacy pins. All native work uses shared build/heavy locks. Then
measure fixed-context resident1/2/4/8 complete passes,witness/proof/serialize/
verify,total/steady rates and startup fraction. Keep prefill/decode distinct.
Do not count one block as a model pass. No merge from this lane.

Next local extension is H-commit and FZC/DZC raw scratch intervals; actual
whole-prover peak remains unmeasured. See owner-dd-update.json for newly found
R9 count/test status; it does not establish a reviewed DD full-stack result.
'''
(R/'handoffs/20261020-private-stage-lifetimes.md').write_text(handoff)
dump('completion.json',dict(run_id=RUN,cycle='0094',checkpoint=now,status='complete',new_verified_full_stack_proofs=0,countable_positions=0,production_patch=None,native_build=False,gpu_job=False,source_records_appended=7,next_cycle_not_before='2026-10-20T03:18:54Z'))
print(json.dumps(dict(status='checkpointed',at=now,checks=res['checks'],negative_controls=res['negative_controls'])))
