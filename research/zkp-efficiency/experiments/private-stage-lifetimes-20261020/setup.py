"""Snapshot public source and durable research memory; checkpoint before work."""
import datetime, hashlib, json, pathlib, re
HERE=pathlib.Path(__file__).resolve().parent
R=HERE.parent.parent
P=R.parent.parent
RUN='20261020T021854Z-e084e681'
for d in ['startup','source']: (HERE/d).mkdir(exist_ok=True)
paths=[R/x for x in ['AGENDA.md','STATE.md','FINDINGS.md','sources.jsonl','PROGRESS.md']]
paths += [P/'CLAUDE.md']
paths += [P/'docs/zkmatrix-poc'/x for x in ['MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md','START_HERE.md','TASK_BOARD.md']]
paths += [R/'experiments/device-allocation-coverage-20261020'/x for x in ['result.json','validation-result.json','staging-result.json','census-result.json','hypotheses.json','README.md']]
manifest=[]
for p in paths:
 b=p.read_bytes(); n=str(p.relative_to(P)).replace('/','__'); (HERE/'startup'/n).write_bytes(b)
 manifest.append(dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b),snapshot=n))
 if p.name in ['FINDINGS.md','MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md']:
  ss=re.split(r'(?m)(?=^#{1,3} )',b.decode())
  (HERE/(p.name+'.read-index.json')).write_text(json.dumps([dict(heading=s.splitlines()[0] if s else '',lead=' '.join(s.splitlines()[1:7]),tail=' '.join(s.splitlines()[-4:]),sha256=hashlib.sha256(s.encode()).hexdigest()) for s in ss],indent=2)+'\n')
ledger=[json.loads(s) for s in (R/'sources.jsonl').read_text().splitlines() if s.strip()]
(HERE/'source-ledger-index.json').write_text(json.dumps([dict(title=s.get('title'),url=s.get('url'),assessment=s.get('assessment')) for s in ledger],indent=2)+'\n')
(HERE/'input-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
trees={'gpu':P/'ops/zkp-mvp/gpu-zerocheck','r8':P/'results/zk60_1b_native_20261017/r8/frozen-tree'}
sources=[]
for tree,base in trees.items():
 for name in ['private_block/run.rs','private_block/protocol.rs','private_block/boundary.rs','private_block/layout.rs','private_block/shape.rs','gpu/cuda.rs','pcs.rs','zk.rs']:
  p=base/'hashline/src'/name; b=p.read_bytes(); n=tree+'__'+name.replace('/','__'); (HERE/'source'/n).write_bytes(b)
  sources.append(dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b),snapshot=n))
(HERE/'source-manifest.json').write_text(json.dumps(sources,indent=2)+'\n')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
(R/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle0094 IN PROGRESS `{RUN}`, checkpoint {now}.
Deadline 2026-10-20 02:38:54 UTC; next cycle no earlier 03:18:54 UTC.
Prior memory and latest results preserved in experiments/private-stage-lifetimes-20261020/startup/.
Read AGENDA, all durable source ledger/findings and project status/decisions/coordination.

Test source-pinned private-stage A/M/H, previous/current boundary and endpoint
lifetimes against an independent dependency oracle. Quantify live requested
storage separately from idle pool capacity; reject premature release/reused
boundary claims. No legacy four-commit schedule substituted for private path.
Ranked:1 owner whole-prover GPU + verified resident fixed-context1/2/4/8;
2 private owner lifetime/peak accounting (refined this cycle);3 exactDD D30
unbuilt;4 prior public-loader optimization;5 fallback staging (zero on resident).
Baseline explicit M/A/H drops after their opening; boundary opens in next
stage. Eliminate only genuinely late releases; add lifetime tracking/completion
costs. End-to-end ceiling unknown without native clocks; falsified if already
earliest legal release or any required owner/claim/read is removed.

Carried CPU8B T128 32blocks one16-thread pass,GPUoff,total478.737s
0.267370 positions/s,not reverified. No new independently verified complete
proofs/passes/positions0/0/0. New clocks/rates/startup fraction unmeasured;
no GPU,token context,long-context/resident complete passes or decode this cycle.
Private8B >=50/s high-endGPU target unchanged/unmet. No masking/privacy changes.
Only research writes,excluding runtime. No native build/GPU/Git/install or external writes.
''')
print(json.dumps(dict(status='checkpointed',at=now,inputs=len(manifest),sources=len(sources),ledger_records=len(ledger))))
