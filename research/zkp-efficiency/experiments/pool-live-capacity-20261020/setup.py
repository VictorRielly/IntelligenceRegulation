"""Read-only input census; writes only this experiment and early STATE."""
import datetime, hashlib, json, pathlib, re, shutil

HERE = pathlib.Path(__file__).resolve().parent
RESEARCH = HERE.parent.parent
ROOT = RESEARCH.parent.parent
RUN = '20261020T001854Z-f39e44f4'
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
startup = HERE / 'startup'
startup.mkdir(exist_ok=True)
manifest = []
paths = [RESEARCH / n for n in ['AGENDA.md','STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl']]
paths += [ROOT / 'CLAUDE.md']
paths += [ROOT / 'docs/zkmatrix-poc' / n for n in ['MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md','ZK60_SPEED_PLAN_20261017.md','ZK60_PRIVACY_REQUIREMENTS.md']]
paths += [ROOT / n for n in ['hashline/src/gpu/cuda.rs','hashline/src/zk.rs','hashline/src/layer.rs','ops/zkp-mvp/gpu-zerocheck/hashline/src/gpu/cuda.rs','results/zk60_1b_native_20261017/r8/frozen-tree/hashline/src/gpu/cuda.rs']]
paths += [RESEARCH / 'experiments/vec-allocation-scopes-20261019' / n for n in ['result.json','validation-result.json','hypotheses.json','carried-report.json']]
for p in paths:
    data = p.read_bytes()
    label = str(p.relative_to(ROOT)).replace('/','__')
    # Public source and existing research memory only; no model/receipt content.
    if p.suffix == '.rs' or p.is_relative_to(RESEARCH):
        (startup / label).write_bytes(data)
    manifest.append(dict(path=str(p), sha256=hashlib.sha256(data).hexdigest(), bytes=len(data), lines=len(data.splitlines()), snapshot=label if (startup / label).exists() else None))
(HERE/'input-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
findings = (RESEARCH/'FINDINGS.md').read_text()
sections = re.split(r'(?m)(?=^## )', findings)
index = []
for s in sections:
    lines = s.splitlines()
    index.append(dict(heading=lines[0] if lines else '',sha256=hashlib.sha256(s.encode()).hexdigest(),lines=len(lines),lead=' '.join(lines[1:5]),tail=' '.join(lines[-3:])))
(HERE/'findings-read-index.json').write_text(json.dumps(index,indent=2)+'\n')
ledger = [json.loads(s) for s in (RESEARCH/'sources.jsonl').read_text().splitlines() if s.strip()]
(HERE/'sources-read-index.json').write_text(json.dumps([dict(title=s.get('title'),url=s.get('url'),cycle=s.get('cycle'),assessment=s.get('assessment'),published=s.get('published'),updated=s.get('updated')) for s in ledger],indent=2)+'\n')
checkpoint = f'''# ZKP efficiency explorer — durable state

Cycle0092 IN PROGRESS: `{RUN}`, checkpoint {now}.
Deadline 2026-10-20 00:38:54 UTC; no additional cycle before 01:18:54 UTC.
Previous complete state, findings and sources preserved under
experiments/pool-live-capacity-20261020/startup/; input and read indexes saved.

Question: audit simultaneous live pooled + idle pooled + raw capacity at
actual public CUDA request formulas, including returned-buffer tails and
allocation failure. Exact and best-fit reuse ALREADY exist. Newly read:
dev_pool_drain and dev_reserve_hard already drain/retry, and zk.rs calls
drain at layer top; do not present these as new optimizations. Native comments
about old layer failures are explicitly labelled hypotheses, not new evidence.
Experiment will extract unchanged source policy into a capacity-only Rust
mock and compare event results with a separately written Python oracle.
No GPU, native dependency build, downloaded code, or private content.

Ranked questions: 1 whole-prover GPU + independently verified fixed-context
resident 1/2/4/8 workloads (owner); 2 NEW source-pinned pool live/idle/raw
capacity census and existing drain costs; 3 exact DD layout (D30 unbuilt,
owner integration); 4 pending checked public-loader transfer/scopes.
Do not infer speed from hit counts or claim live-capacity logging speeds proof.

Carried owner R8 CPU diagnostic only: 8B T128, 32 blocks, one 16-thread pass,
GPU off, total 478.737s = 0.267370 positions/s. Researcher has not reverified.
No new independently verified full-stack proofs/passes/positions: 0/0/0.
New witness/proof/serialization/verification clocks, startup fraction and
steady/total proved rates unmeasured; no long-context, resident series or decode.
Complete private 8B >=50 proved tokens/s RTX5090/high-end GPU remains unmet.
No mask or opening reuse. D33 narrow TinyLlama T32 CPU R7 scope persists;
next-token gate evidence does not itself extend acceptance. Only research writes.
'''
(RESEARCH/'STATE.md').write_text(checkpoint)
print(json.dumps(dict(status='checkpointed',inputs=len(manifest),finding_sections=len(index),source_records=len(ledger),at=now)))
