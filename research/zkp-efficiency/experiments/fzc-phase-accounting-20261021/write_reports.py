"""Checkpoint this bounded research cycle; research paths only."""
from pathlib import Path
import datetime,difflib,hashlib,json
E=Path(__file__).resolve().parent;R=E.parents[1];P=R.parents[1]
RUN='20261021T041854Z-cfd5ba2e';NOW=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=json.loads((E/'result.json').read_text());audit=json.loads((E/'source-audit-result.json').read_text())
assert result['status']=='PASS_SYNTHETIC_ACCOUNTING_ONLY' and audit['status']=='PASS_SOURCE_ORDER_AND_ROLE_FORMULAS_ONLY'
assert result['checks']==6829 and audit['checks']==59
agenda=(R/'AGENDA.md').read_text();assert 'Every cycle' in agenda
changes=[]
for x in json.loads((E/'startup/manifest.json').read_text()):
    f=Path(x['path'])
    if f.is_relative_to(P) and not f.is_relative_to(R):
        b=f.read_bytes();old=E/'startup'/str(f.relative_to(P)).replace('/','__')
        if b!=old.read_bytes():
            name='checkpoint__'+old.name;(E/'startup'/name).write_bytes(b)
            changes.append({'path':str(f),'old_sha256':x['sha256'],'new_sha256':hashlib.sha256(b).hexdigest()})
            (E/'startup'/(name+'.diff')).write_text(''.join(difflib.unified_diff(old.read_text().splitlines(True),b.decode().splitlines(True))))
(E/'checkpoint-updates.json').write_text(json.dumps({'utc':NOW,'production_changes_since_startup':changes,'agenda_sha256':hashlib.sha256(agenda.encode()).hexdigest()},indent=2)+'\n')
src_new=(E/'source-records.jsonl').read_bytes();prior_src=(E/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
src_path=R/'sources.jsonl';assert src_path.read_bytes()==prior_src,'unexpected source ledger mutation'
src_path.write_bytes(prior_src+src_new)
accounting={'run_id':RUN,'completed_independently_verified_full_stack_proofs':0,'complete_model_passes':0,'proved_positions':0,
 'model_context_length':None,'accelerator':None,'research_device':'Intel Core Ultra 9 185H; one pinned CPU worker',
 'witness_seconds':None,'proof_seconds':None,'serialization_seconds':None,'verification_seconds':None,
 'startup_seconds':None,'startup_fraction':None,'steady_state_proved_positions_per_second':None,
 'total_workload_proved_positions_per_second':None,'long_context_prefill_executed':False,
 'resident_model_pass_series_executed':False,'decode_executed':False,'target_achieved':False,
 'synthetic_traces_are_model_passes':False,'gpu_job_executed':False}
(E/'target-accounting.json').write_text(json.dumps(accounting,indent=2)+'\n')
scope='''New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel Core Ultra 9
185H CPU worker per diagnostic. Witness, proof, serialization and verification clocks:
**unmeasured**. Startup duration/fraction, steady-state rate and total-workload rate:
**unmeasured**. No long-context prefill, resident-model proof series or decode ran.
Synthetic interval traces are not model passes. Larger workloads remain allowed;
longer contexts can increase attention work quadratically. The complete private8B
target of >=50 proved tokens/s remains unachieved.
'''
next_local='''Next local experiment: rank25 one-hot U8 address/increment contract on tiny ordered
synthetic queries, compared to an independent direct-index reference and a dense256-way
cost control. Test dropped/duplicate/out-of-range queries and tampered histogram; charge
fresh source binding and every added commitment/mask. A histogram alone is insufficient.
This is a new protocol question, not a privacy or throughput acceptance. Do not repeat the
already-known tiny-public-table preprocessing negative. Scratch runtime pooling is parked
until native materiality data exist.'''
findings=f'''

## Cycle 0120 — FZC exclusive phase and role accounting, 2026-10-21

Run `{RUN}`. Checkpoint UTC: {NOW}. AGENDA, durable state and
required project files read/snapshotted; 751 prior source records fully parsed and
10,218 prior findings lines preserved. Latest retirement/storage/tail results read.
No new instruction changes the private8B target; D41 classifier chunking is a separate
product direction. All34 hypotheses retained; rank3 materially refined, rank34 parked
pending materiality, rank25 concretized for the next local test. Owner top-four order stays.

**No proving improvement measured.** Strict fixed-enum host interval accounting passes
**6,829 checks / 1,500 differential synthetic traces / 400 dependency graphs**, with
21 control types. A separate integer-tick replay and recursive-path oracle import no
candidate helpers. Traces include nested/equal/zero endpoints, shuffled input, clocks
above2^53, simulated parallel thread ordinals and infrastructure errors. No threads
are spawned. Separate source/order/role audit passes59checks and matches3 live/copy
source pins. These are independent reference implementations by this researcher, not
an external reviewer or native run.

Source finding: `DevFzcRounds::new` starts its body clock after GPU setup/lock and
optional diagnosis/warmup. Build combines allocation/upload/module/synchronization.
`report` samples total before its own logging, transcript assignment and evaluator
destruction. Tail samples before local pin/device-pack destruction. Constructor or
round errors can return without success aggregation. These omissions have unknown
magnitude and do not establish an omission from enclosing complete-proof clocks.
Current profile-only synchronization also changes where host waits are charged.

The proposed partition subtracts direct children only and leaves every remainder
charged. Per-thread exclusive time reconciles to its root; parallel thread-wall is
not application elapsed. Selected wrapper coverage includes descendants once;
exclusive wrapper labels alone omit nested driver time. GPU timestamps are rejected
from the host schema. Arbitrary payloads/private labels/outcome strings are refused.
Only public role/shape metadata is allowed; no addresses, values, private eligibility,
arbitrary errors or new receipt disclosure. Native adapter/privacy not established.

Decisive synthetic negative: two30-unit workloads each spend8units in allocation;
deleting that API cost saves0 or8units depending on overlap. These artificial units
are not measurements. Counts or API fractions cannot supply an end-to-end prediction.
Mandatory clearing, binding and completion/retirement waits remain charged.

Baseline: per-attempt round fallback pin, conditional mapped pin and distinct
tail pin/device pack. Eliminated native work: **none**. Potential eliminated work:
recurring safe-reuse host allocation/map/free API work only. Added costs: leases,
completion metadata/fences, fresh active clearing, failure quarantine, retention and
instrumentation. If f is unknown truly removable critical-path fraction, even free
deletion gives at most1/(1-f), before costs. No numeric complete GPU ceiling follows.
Falsify on unreconciled/missing failure/drop scopes, privacy/transcript/refusal drift,
unsafe reuse/capacity growth, material profiler perturbation, negligible removable
cost or slower enclosing verified workload.

| Rank | Current hypothesis | Prerequisites and integration burden |
|---:|---|---|
|1|Whole-prover high-end GPU and verified fixed-context resident1/2/4/8|Complete phase/capacity clocks, actual fit, fidelity/refusal/privacy gates; transfers, fresh masks, serialization and drain all charged. Large owner work; slope unknown.|
|2|DD at larger admitted context, cheapest passing fidelity stack|T128 owner A/B was null; T512 is different geometry. Added dictionary/helpers/profile binding/review and native clocks remain. No rate from word reductions.|
|3,refined/tested|Public-role exclusive phase and actual private lifetime telemetry|This cycle supplies source anchors and interval oracle; owner adapter/driver capacity, perturbation and whole-proof clocks remain. No arithmetic/order changes; measurement prerequisite.|
|4|Native all-eleven FZC coefficient A/B|Owner parity, occupancy/register and enclosing elapsed gates; no kernel speed assumed.|
|34,parked|Safe bounded scratch retention|Prior completion/quarantine model retained; no promotion before measured materiality. Exact requested lengths, eager fallback and current privacy obligations stay.|

Probe/source-audit diagnostic clocks: {result['wall_seconds']:.6f}/{audit['wall_seconds']:.6f}s;
RSS {result['rss_kib']:,}/{audit['rss_kib']:,}KiB. Seed202610210120; one worker/core,nice19,
30sCPU/alarm,35sparent,256MiBAS,estimated32MiB. Commands/source hashes retained.
These are checking clocks. No CUDA/native build,witness,mask,transcript,receipt or verifier.

Eight native LIVE queries and nine primary records append751->760. Current Nsight
analysis/user docs support separate host/device accounting and perturbation checks;
the newly assessed older2020-09-18 NVIDIA overhead article adds the short-API tracing
methodology. NVTX/ICICLE release and root license views inspected; abbreviatedNVTX
commit and separateRust license cache-missed, so no full commit or crate license is
inferred. Chimera October16 and zkLLMPoT October11 revisions refreshed; the latter's
covered-operator/public-input scope does not establish this full private target.
The nonlinear lookup refresh preserves the existing256-entry-table negative.
Exact URLs, verified/unknown dates, licenses and failures are in source-records.jsonl;
no upstream performance or security reproduced and no downloaded code executed.

{scope}
{next_local}

Owner next: actual allocation incidence plus exclusive/enclosing complete-proof clocks,
then native safety/parity A/B if useful under shared heavy/build locks. Measurement
interface and source pins: `experiments/fzc-phase-accounting-20261021/MEASUREMENT.md`;
handoff: `handoffs/20261021-fzc-phase-accounting.md`. Main/Claude reviews and integrates;
no merge. Only research files outside runtime/ written. No production/Git/receipt/
calibration/reviewer/instruction edits,build,GPU,install,external write/message or escalation.
Saved reports do not establish delivery or supervisor liveness.
'''
prior_find=(E/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes();fp=R/'FINDINGS.md'
assert fp.read_bytes()==prior_find,'unexpected findings ledger mutation';fp.write_bytes(prior_find+findings.encode())
progress=f'''# ZKP efficiency progress

Cycle0120 complete — `{RUN}` — 2026-10-21 UTC.

**No proving speedup measured.** FZC clock proposal passes6,829 synthetic checks
across1,500 nested traces/400 dependency graphs; a separate source audit passes59.
Existing FZC totals omit pre-body/post-report work, tail-local destruction and failed
attempt aggregation; magnitude unknown. Identical allocation API fractions can yield
different elapsed savings, so counts alone do not justify a pool.

Owner handoff supplies exact source anchors and public-role scopes, with mandatory
clearing/fences retained and profiler perturbation checked. No native adapter.
All34 hypotheses preserved; rank3 refined; runtime scratch pooling parked pending
native materiality. Eight LIVE queries/nine primary records saved; no upstream speed
reproduced. D41 classifier chunking does not change the private8B research target.

{scope}
Next: tiny U8 one-hot address/increment contract with independent ordered-query and
histogram controls plus dense256-way cost. Owner complete GPU phase/capacity and
verified resident1/2/4/8 measurements remain first.

[Experiment](experiments/fzc-phase-accounting-20261021/README.md),
[dated report](progress/{RUN}.md),
[handoff](handoffs/20261021-fzc-phase-accounting.md).
Saved reports are not delivered messages or evidence of supervisor liveness.
'''
(R/'PROGRESS.md').write_text(progress)
(R/'progress'/f'{RUN}.md').write_text(findings.lstrip())
state=f'''# ZKP efficiency explorer — durable state

Cycle0120 COMPLETE: `{RUN}`. Checkpoint UTC{NOW}.
Started04:18:54UTC; deadline04:38:54UTC. Next cycle no earlier than2026-10-21T05:18:54Z.
AGENDA read at startup and checkpoint. Required project files and latest results read.
Prior10,218 findings lines and751 sources preserved; nine primary records append->760.
Startup snapshot: experiments/fzc-phase-accounting-20261021/startup/.

No proving improvement measured. Phase probe passes6,829checks,1,500synthetic traces,
400DAGs/21control types. Separate source/order/role audit passes59checks;3 live/copy
source pins match. Independent tick/path references authored here, no external review.
Diagnostic clocks {result['wall_seconds']:.6f}/{audit['wall_seconds']:.6f}s;
RSS{result['rss_kib']}/{audit['rss_kib']}KiB; seed202610210120,one CPU/nice19,
30sCPU/alarm,35sparent,256MiBAS,estimated32MiB. No native/GPU/proof executed.

Source FZC body starts after init/lock/warmup; build mixes allocations/uploads/module/
sync; successful total sampled before reporting/transcript assignment/destruction;
tail timer before local pin/pack drop; failures can skip aggregation. Cost unknown,
not evidence of omission from complete-proof clocks. Proposed public-role integer
host partition reconciles per thread, counts nested scopes once and rejects mixed
GPU clocks/private fields. Parallel thread-wall is not workload elapsed. Same
synthetic8/30allocation fraction can save0or8units; no numeric GPU ceiling follows.
Charge required clearing/binding/fences; no masks/openings/challenges reused.

All34hypotheses retained. Rank3 materially refined; rank34 scratch runtime promotion
parked pending native allocation materiality. Top four unchanged: complete GPU +
verified fixed-context resident1/2/4/8; larger-context DD + cheapest passing fidelity;
private lifetime/phase/capacity telemetry; native all-eleven FZC A/B. D32<=1.02x and
zero refusals,D33/D36 narrow TinyLlamaCPU scope retained. D41 chunked classifier
product direction is separate and does not amend this lane's private8B target.

{scope}
{next_local}

Owner next: actual public-role allocation incidence and exclusive/enclosing proof
clocks; native pool/failure/transcript/privacy parity only if material. Interface:
experiments/fzc-phase-accounting-20261021/MEASUREMENT.md. Handoff:
handoffs/20261021-fzc-phase-accounting.md. Main/Claude reviews/integrates; no merge.

Eight LIVE queries/nine primary records: Nsight,NVTX/ICICLE releases,Chimera,
zkLLMPoT and lookup/hardware filters. Newly assessed older2020NVIDIA overhead
methodology. NVTX commit and Rustlicense cache-missed; rootlicense inspected but
no crate-specific conclusion/fullcommit. No upstream performance/security reproduced.

Historical diagnostic carried without rerun/reverification: non-DD8B,T128,32layers,
one16-thread CPU pass,GPUoff,total478.737s=0.267370positions/s; prove_run393.785s
includeswitness98.348s/load17.595s; seal84.824s overlaps. Receipt922,711,264B.
Freshverify42.709s+load13.681s; recheck34.395s+load10.739s. Isolatedserialization,
startupfraction/steadyslope unknown; not a high-endGPU baseline. Owner DD478.7->474.9s
atT128 is a shared-box n=1 null, not a reproduced gain here.

Only research files outside runtime/ written. No production/Git/receipt/calibration/
safety/reviewer/instruction changes; no build,GPU,install,downloadedcodeexecution,
external write/message,purchase or escalation. Reports do not establish delivery/liveness.
'''
(R/'STATE.md').write_text(state)
print(json.dumps({'run_id':RUN,'checkpoint_utc':NOW,'source_records':760,'hypotheses':34,'production_changes_read':changes}))
