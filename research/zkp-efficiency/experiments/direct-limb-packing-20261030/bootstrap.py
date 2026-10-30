import collections, datetime, hashlib, json, pathlib, re
D=pathlib.Path(__file__).resolve().parent
R=D.parent.parent
P=R.parent.parent
S=D/'startup'
S.mkdir(exist_ok=True)
paths=[R/n for n in ['STATE.md','FINDINGS.md','AGENDA.md','PROGRESS.md','sources.jsonl']]
paths += [P/'CLAUDE.md']
paths += [P/'docs/zkmatrix-poc'/n for n in ['ZK60_THROUGHPUT_TARGET.md','MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','START_HERE.md','TASK_BOARD.md']]
prior=R/'experiments/hybrid-opening-budget-20261030'
paths += [prior/n for n in ['result.json','hypotheses.json','ranking-current.json','target-accounting.json','cost-study.json','README.md']]
index=[]
for i,p in enumerate(paths):
    b=p.read_bytes()
    dest=S/(str(i).zfill(2)+'-'+p.name)
    dest.write_bytes(b)
    index.append(dict(path=str(p),snapshot=str(dest.relative_to(D)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(D/'startup-index.json').write_text(json.dumps(index,indent=2)+'\n')
findings=(R/'FINDINGS.md').read_text()
heads=re.findall(r'^## (.*)$', findings, flags=re.M)
sources=[json.loads(s) for s in (R/'sources.jsonl').read_text().splitlines()]
memory=dict(findings_sections=heads,source_count=len(sources),sources=[dict(id=s.get('id'),url=s.get('url'),title=s.get('title'),cycle=s.get('cycle')) for s in sources])
(D/'memory-index.json').write_text(json.dumps(memory,indent=2)+'\n')
(D/'prior-hypotheses.json').write_bytes((prior/'hypotheses.json').read_bytes())
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
state=f'''# ZKP efficiency explorer — durable state

Cycle 0158 IN PROGRESS: `20261030T064123Z-6637fd3d`.
Started 2026-10-30T06:41:23Z; early checkpoint {now}.
Deadline 07:01:23Z; next cycle no earlier than 07:41:23Z.
Read AGENDA.md EVERY cycle.

Current experiment: explicit direct c0/c1 limb packing at the native
hashline/src/gpu/cuda.rs::dev_fold_rows seam. Test source-derived packing
against an independent serialization/fold reference and allocator counters.
Baseline uses flat.extend(as_u64s_f2(rho)) and creates a temporary Vec per
rho. Candidate keeps one checked-capacity staging allocation and writes
limbs directly, preserving order and raw limb values without an Fp2 ABI cast.
No native/GPU/full-stack improvement claimed. Complete >=50 proved-token/s
private 8B target remains unachieved; larger workloads remain permitted.

Ranked global questions: (1) full verified high-end GPU and resident 1/2/4/8
pass workloads; (2) admitted context/DD/fidelity scaling; (3) exclusive phase
and capacity clocks. Local candidate 86 is the bounded test below these
owner priorities. Hypothesis history preserved in prior-hypotheses.json.
Falsify if compiled baseline eliminates temporary allocations, exclusive
packing is negligible, any limb/order/refusal/receipt differs, or added
packing/locking/memory costs erase savings. End-to-end ceiling is
N/(T-C_pack_exclusive+A_added), currently unknown.

Prior cycle 0157 result: synthetic public-budget hybrid reduces H2D/API
allocation requests conditionally; no measured proving gain. Native clocks
still needed; no staging variant outranks measured bottleneck evidence.
All durable startup documents, full findings/source history and latest
results read and snapshotted; see experiments/direct-limb-packing-20261030/startup-index.json.
Only research outside runtime is writable. No production/Git/GPU/native
build/install/downloaded-script execution/external write/message/merge.
Finish with updated STATE, FINDINGS, source records and both progress reports.
'''
(R/'STATE.md').write_text(state)
print(json.dumps(dict(status='CHECKPOINT',snapshots=len(index),findings_sections=len(heads),source_records=len(sources),prior_hypotheses=len(json.loads((prior/'hypotheses.json').read_text())))))
