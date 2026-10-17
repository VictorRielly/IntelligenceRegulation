"""Cycle0056 reports derived from the retained bounded result and audit."""
import datetime,json
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
RUN='20261017T062624Z-e471348a'
r=json.loads((HERE/'result.json').read_text())
a=json.loads((HERE/'audit.json').read_text())
assert r['status']==a['status']=='passed'
assert all(x['unchanged'] for x in a['owner_memory'])
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
account='''Accepted independently verified complete private 8B proofs/passes/tokens: **0/0/0**. Proof context length: unmeasured (null). Device: Intel Core Ultra 9 185H CPU only, one thread, nice19, CPU0 affinity. Steady-state and total-workload rates, startup duration/fraction, witness/proof/serialization/independent-verification clocks and proof latency/lag/drain are **all unmeasured**. No long-context prefill, resident-model pass or decode proof ran. Synthetic cubes contain at most16 cells; T512/T1024 figures are allocation-free accounting. Doubling dense-attention context produces roughly4x score work. Larger workloads remain permitted with fresh masks and complete coverage. The complete private8B >=50 proved-token/s target remains unachieved.'''
baseline=json.loads((ROOT/'experiments/fixed-round0-factory-20261017/report-components.json').read_text())['baseline']
rank='''|Rank|Hypothesis / end-to-end opportunity|Prerequisites, added costs and falsifier|
|---|---|---|
|1 owner|GPU SC_SZC plus both recurring witness paths. Largest measured phase opportunity; complete8B ceiling unknown.|Exact native profile/refusal/masked/RNG/finals/PCS/privacy and fresh-verifier gates. Charge device storage,transfers,launches,scratch and both witnesses; reject mismatch,overflow or enclosing regression.|
|2 refined local / owner gate|Public DAG scheduling preserves prior first-round field savings while reducing logical scratch. Native benefit unknown; no additional arithmetic saving.|Next local: construct and independently validate immutable native-capture index mapping; do not derive indices from witness values. Owner: compile/profile literal,unscheduled fixed,scheduled fixed arms, including registers/spills/code size and enclosing clocks. Reject any value/refusal/RNG difference,or unchanged native code/no enclosing gain. Tested <=16-live goal failed; no optimality claim.|
|3 workload owner|Resident complete passes at fixed context can amortize public setup; startup/slope not measured.|Fresh masks/openings per accepted policy; cache identity,residency,lag,drain and independent verification. Recurring complete cost>20ms/new proved position falsifies50/s for that schedule. Long-context prefill and growing-context decode remain distinct; decode needs state binding.|
|4 owner|Exact full-K split-int16 down witness; affected complete-proof fraction unknown.|Packing,two products,i64 reconstruction,exact requant/refusal,transfer and scratch. Reject integer/native-receipt mismatch or enclosing regression.|
|5 conditional architecture|Commitment transfer overlap or different GKR/PCS designs might affect dominant phases; no native estimate.|Extra device buffers,completion ownership,field/profile migration,hiding,state binding,composition and verifier costs. ICICLE example alone does not establish our field adapter or bytes; Ethereum proof claims do not transfer.|
|Demoted|Broad later-round cubic,CSE,prior native fusion,twiddle/memory/table-cache negatives retained.|Do not credit padded savings to full-domain8B or treat table shrink as fewer queries. No reconstruction/spill optimization promoted without native measurement.|'''
result=f'''A deterministic public DAG scheduler tests102 orders per public shape (96 depth-first operand/output orders,5 ready-list heuristics and the original order). All operations,operand order,outputs and even dead pure operations are retained; there is no CSE,algebraic rewrite,recomputation or private-value pruning. The full-head three-limb constant/moving-mask bodies retain393/419 field API calls. Their peak live logical field results after assignments fall20->18 and23->20 (320->288B and368->320B). Seven-lookup moving-mask shapes reach19. All12 shapes improve, but none reaches the proposed<=16 goal. This bounded miss is not a lower bound or an optimality result. Read-only inputs,proof-local offsets/constants,caller arrays,Eq/accumulators and field-API internals are excluded; native registers,spills,stack,occupancy and runtime remain unknown.

The final experiment passes2,790 synthetic schedules/93 fixtures,28,650 independent round samples,67,770 finals,192 extension checks,1,116 schedule counter comparisons,48 executed operation censuses,24 value-independent censuses and24 branchless generated bodies. There are1,026 recoveries/1,062 zero-factor fallbacks,3 padded refusals and5 detected arithmetic/metadata/lifetime mutations. Final wall={r['wall_seconds']:.6f}s,RSS={r['max_rss_kib']:,}KiB,one nice19 CPU thread,seed{r['seed']},exit0,59s/512MiB caps; estimated64MiB. The independent AST/DAG/integrity audit passes{a['checks']:,} checks and refuses dropped,duplicate and use-before-definition schedules plus a corrupt RHS. It verifies the exact original operation/operand/output correspondence under the permutation. This is not a native proof or privacy gate.'''
cost='''Baseline for this cycle is the prior fixed unpadded round0 factory. Eliminated work: **no field operations**; only shorter logical retention of2/3 full-head intermediate results. Added costs: public generation/search,permutation/remapping,source/metadata and compiler scheduling constraints; static helpers can be generated ahead of time. These must not be presented as measured native startup. The prior scoped full-head hp32/kv8/qh32/T512/3limb count remains3,527,474,753 prepared scalar ->3,280,010,835 fixed round0 (7.0153% fewer API calls), with the same exclusions. No further arithmetic saving or timing factor is established. The earlier159,383,552 eliminated width tests concern a dynamic RESEARCH prototype,not native scalar work. Round0 recurs for every proof; it is not startup amortization.

End-to-end ceiling remains unknown: `N/(T_complete - avoided_native_spill_or_scheduling_time + added_native_setup_dispatch_time)`. All native terms for this scheduling change are unmeasured; a compiler may already find an equivalent schedule, yielding zero benefit. Even erasing all historical SC_SZC is only a28.317% ceiling on that one synthetic block's enclosing diagnostic,not an8B bound or a path to50/s by itself.'''
sources='''Six LIVE source records were appended (282->288), with URLs,access date,verified versus unknown dates,license scope,inspected commit and exact blockers in sources-cycle56.json. New October13 Airbender Prime is an author Ethereum/GPU claim; unversioned repository final-CPU documentation is not mapped to Prime. New older Sethi1975 register-allocation abstract supports bounded heuristic/optimality caution. ICICLE's NTT-overlap example explicitly charges extra device vectors; its release-target diff6c77775961b0e4dc2be359feec1ac11536c18043 includes a Goldilocks crate,correcting any inference from the previously incomplete advertised field list. Native Fp2/mask/challenge compatibility is unestablished. SumCATS register-storage discussion and2026-revised product-sumcheck time/space source were refreshed; hardware-locality/PIM scope retained. No author performance/security reproduced or foreign code copied/executed. PDF,license,history and example-source fetch failures did not block the local experiment.'''
limits='''Generated Rust is uncompiled and uses research-port carrier indices. Public topology scheduling changes no field formula, but native masked transcript,RNG,refusal,profile,terminal oracle,PCS,proof bytes and independent verifier gates remain mandatory for owner integration. Public helper code may be cached; offsets depend on the current proof's challenges. No witness,mask,private opening or proof-local denominator cache across proofs is authorized. All11 native/measurement pins and7 owner memory files match the starting snapshot. D24 remains proposed; no new profile or privacy ruling is accepted.'''
seam='''Candidate seam: `ops/zkp-mvp/sonnet-hardening/hashline/src/private_block/argument.rs:1699` SC_SZC constructor and1788 bracket; `zkp-core/src/sumcheck/grouped.rs:93` part loop,107 row loop,121 samples and132 reduction. Review patch: `experiments/clause-stream-schedule-20261017/research-source-diff.patch`; generated Python/Rust and liveness schedules are under `generated/`. Interface remains four fixed coefficients from immutable current-row values,differences,constants and proof-local offsets. There is no production patch or merge.'''
next_action='''Next local experiment: replace research-port carrier indices with an immutable captured-index adapter matching the native SC_SZC constructor (`idx`,`im`,`imx`,`isum`,`ihx`,`h0`,limb vectors and lookup terms),then differentially compare literal/native-shaped and generated clauses at arbitrary extension points. Preserve optional support refusals and original group/terminal order. Native owner next: guarded three-arm compile/profile and complete resident-workload startup/slope,with both witness paths,peak memory,all clocks,fresh masks,proof lag/drain and independent verification. Do not repeat heuristic search merely to obtain a smaller toy frontier before this integration question is answered.'''
history='''The initial scheduled arithmetic pass is retained under before-independent-dag-audit/. Expanding the independent audit after the wrapper had pinned every local Python file correctly triggered `AssertionError: audit.py`; that failure is retained under initial-audit-source-pin-refusal/. The final source freeze rerun and expanded audit pass. No arithmetic failure was hidden and no integrity check was disabled.'''
prohibition='''No production,runtime,Git,calibration,safety gate or reviewer files modified; no GPU,build,dependency install,external write/message,merge or heavy job queued. Saved reports do not establish message delivery or supervisor/job liveness.'''
readme=f'''# Public SC_SZC DAG scheduling — cycle0056

Run `{RUN}`,2026-10-17 UTC; checkpoint{now}.

**No native proving speed improvement established.**

{result}

|Three-limb/full15 lookups|API calls|Old retained field results|New retained field results|Logical scratch|
|---|---:|---:|---:|---:|
|constant mask|393|20|18|320->288B|
|moving mask|419|23|20|368->320B|

{cost}

{baseline}

{rank}

{limits}

{seam}

{next_action}

Commands,source hashes,logs and exit status are retained in command.json/execution.json/run.log. Standard library only:

```bash
python3 -B /home/victor/IntelligenceRegulation/research/zkp-efficiency/experiments/clause-stream-schedule-20261017/run.py
python3 -B /home/victor/IntelligenceRegulation/research/zkp-efficiency/experiments/clause-stream-schedule-20261017/audit.py
```

{history}

{sources}

{account}

{prohibition}
'''
(HERE/'README.md').write_text(readme)
progress=f'''# ZKP efficiency progress

Cycle0056 — `{RUN}`,completed2026-10-17 UTC.

**No native speed improvement established.** Public operation scheduling reduces full-head logical temporaries20->18 and23->20 with identical field calls. The<=16 goal was missed by all tested heuristics; no optimum is claimed. This is scratch accounting,not measured native registers or proving speed.

The final CPU experiment passes2,790 synthetic schedules/93 fixtures,28,650 independent round samples,67,770 finals and192 extension checks. Five mutations are detected; the independent DAG/lifetime/integrity audit passes{a['checks']:,} checks. Final run:{r['wall_seconds']:.2f}s,{r['max_rss_kib']:,}KiB RSS,one low-priority CPU thread. A source-pin refusal after an audit edit is preserved; final frozen rerun passes.

Seam: SC_SZC in argument.rs and grouped.rs. Generated Rust remains uncompiled,with research-port indices. Next local step is an independently checked native captured-index adapter; native owner should then compare literal/unscheduled/scheduled arms with registers,spills,both witnesses and enclosing proof clocks. The prior scoped7.0153% API reduction remains; this cycle adds no arithmetic saving. All11 native/measurement pins and7 owner memory files match.

LIVE searches inspected new October13 Airbender Prime,ICICLE transfer-overlap/release history,SumCATS,time/space sumcheck,hardware locality and a new older register-allocation source. Six records appended,288 total; source/access/commit/license limits retained. No foreign benchmark reproduced. Details: [experiment](experiments/clause-stream-schedule-20261017/README.md),[handoff](handoffs/20261017-clause-stream-schedule.md).

{account}

{prohibition}
'''
(ROOT/'PROGRESS.md').write_text(progress)
(ROOT/'progress'/f'{RUN}.md').write_text(progress)
finding=f'''\n\n## Cycle0056 — 2026-10-17 — exact public DAG order reduces logical retention

Run `{RUN}`; checkpoint{now}. Agenda,target,durable/project memory and latest three results read/snapshotted. All282 starting source records parsed;6 appended,288 total. Prior findings and source prefixes retained.

{result}

{cost}

{rank}

{seam}

{limits}

{history}

{sources}

{next_action}

{account}

{prohibition}
'''
before=(HERE/'startup/FINDINGS.md').read_bytes()
assert (ROOT/'FINDINGS.md').read_bytes()==before
with (ROOT/'FINDINGS.md').open('a') as f:f.write(finding)
handoff=f'''# Review handoff — public SC_SZC DAG scheduling

Cycle0056,`{RUN}`,2026-10-17 UTC. Research candidate only; main agent/Claude reviews and integrates. No native speedup established.

{seam}

Implementation: locally authored scheduler.py retains each original operation once. It compares102 public orders per shape,then emits a renamed topological graph through generate.py. Schedule choice depends only on graph/layout metadata; no values are inspected. SSA and recycled-slot Python bodies and uncompiled Rust helpers retain four coefficient outputs. FixedPlan uses the existing public round0/unpadded selector; original scalar fallback and later-round claim recovery stay in the research port.

{result}

{cost}

{limits}

{next_action}

For native acceptance require original five samples,group claims,all ordered finals,zero-factor recovery fallback,optional support refusals,mask/RNG draw order,old fixture bytes and fresh independent-verifier acceptance plus tamper refusals. End-to-end privacy is a separate owner review; synthetic equations/AST checks cannot establish it. Do not change the target or model profile from this handoff.

{account}

{prohibition}
'''
(ROOT/'handoffs/20261017-clause-stream-schedule.md').write_text(handoff)
state=f'''# ZKP efficiency explorer — durable state

Cycle0056 COMPLETE:`{RUN}`; checkpoint{now}.
Read/snapshotted agenda,target,durable/project memory;282 starting sources parsed,
6LIVE records appended,288 total. Latest3 results read; historical findings/negatives
preserved. All11 native/measurement pins and7 owner memory files match. No new
trained proof or privacy ruling;D24 remains proposed. No heavy job queued.

Public DAG scheduler tests102 orders/shape,without field elimination,recomputation,
CSE or algebraic rewrite. Full-head constant/moving mask:393/419 API calls remain;
live logical field results20->18 and23->20;320->288B/368->320B after assignments.
Seven-lookup moving shapes reach19. No tested shape reaches<=16; no optimality
or impossibility claim. Inputs/constants/offsets,caller arrays,Eq/accumulators and
native API internals excluded. Native registers/spills/occupancy/time unknown.

Final experiment:2790 synthetic schedules/93 fixtures,28650 independent samples,
67770 finals,192 extension checks,1116 counter comparisons,48 executed censuses,
24 value-independent censuses,24 branchless bodies,3 padded refusals,5 mutations.
1026 recoveries/1062 zero-factor fallbacks. Wall{r['wall_seconds']:.6f}s,RSS{r['max_rss_kib']}KiB,
one nice19 CoreUltra9 CPU0 thread,seed{r['seed']},exit0;59s/512MiB caps.
Independent AST/DAG/integrity audit:{a['checks']} checks pass,including invalid
schedule/RHS controls. Audit-source edit triggered correct source-pin refusal;
initial pass/failure retained;final frozen rerun passes. No native proof gate.

No extra arithmetic saving. Prior scoped T512/full-head3limb7.0153% API reduction
vs prepared scalar remains3527474753->3280010835. No native timing factor follows.
Round0 recurs per proof;public code reuse never reuses proof-local offsets/masks.
Complete8B ceiling unknown;compiler may already produce equivalent scheduling.

Ranked hypotheses:
1OWNER:dominant GPU SC_SZC plus BOTH recurring witness paths,all native gates.
2REFINED:map generated carrier indices to immutable native constructor captures,
then owner literal/unscheduled/scheduled A/B with register/spill/enclosing clocks.
Reject value/refusal/RNG difference or no measured enclosing benefit;<=16 missed.
3OWNER:resident complete-workload startup/slope,fresh masks,all clocks,lag/drain.
Recurring>20ms/new proved position rejects50/s for that schedule.
4OWNER:exact full-K split-int16 down witness,integer/refusal/receipt parity.
5ARCHITECTURE:transfer overlap/PCS designs need extra buffers,hiding/composition
and full costs. Broad later-round cubic,prior CSE/fusion/twiddle/table negatives
remain demoted. Do not run more toy scheduling merely to lower the frontier.

Experiment:experiments/clause-stream-schedule-20261017.
Handoff:handoffs/20261017-clause-stream-schedule.md.
Next LOCAL:independent native captured-index adapter for SC_SZC idx/im/imx/isum/
ihx/h0/limbs/lookups,arbitrary-extension and optional-support/refusal comparisons.
Next OWNER:guarded three-arm native compile/profile,then resident complete workload
with both witness paths,all phase clocks,peak memory,fresh masks,lag/drain and
fresh independent verification. Generated Rust is uncompiled;no production patch.

LIVE:October13 AirbenderPrime announcement/new older Sethi1975 register problem;
ICICLE overlap/release commit6c77775961b0e4dc2be359feec1ac11536c18043;
SumCATS spill discussion,time-space sumcheck and hardware-locality refresh.
Goldilocks crate appears in inspected ICICLE release-commit message;prior incomplete
advertised field list was not absence evidence. Fp2/backend compatibility unknown.
Prime and old unversioned final-CPU documentation not version-mapped. Source dates,
licenses/unknowns and exact access errors retained;no foreign code executed.
Next rotation:lookup query work,exact nonlinear/quantization and proof composition,
with current native bottlenecks ahead of architecture migrations.

{account}

{prohibition}
Next cycle not before2026-10-17T07:26:24Z.
'''
(ROOT/'STATE.md').write_text(state)
(HERE/'report-components.json').write_text(json.dumps(dict(account=account,baseline=baseline,rank=rank,result=result,cost=cost,sources=sources,limits=limits,seam=seam,next_action=next_action),indent=2)+'\n')
(HERE/'checkpoint.json').write_text(json.dumps(dict(run_id=RUN,cycle='0056',status='complete',checkpoint_utc=now,source_records=288,accepted_complete_private_8b_proofs=0,proved_tokens=0,passes=0,experiment_status='passed',audit_checks=a['checks'],owner_memory_changed=False),indent=2)+'\n')
print(json.dumps(dict(status='reports_written',run_id=RUN,audit_checks=a['checks'],source_records=288)))
