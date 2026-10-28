"""Public source/read-memory snapshot and early checkpoint; no model data."""
import datetime, hashlib, json, pathlib, re
HERE = pathlib.Path(__file__).resolve().parent
RESEARCH = HERE.parent.parent
ROOT = RESEARCH.parent.parent
RUN = '20261020T011854Z-224b9b69'
def write(name, data):
    (HERE/name).write_text(json.dumps(data, indent=2)+'\n')
snap = HERE/'startup'
snap.mkdir(exist_ok=True)
paths = [RESEARCH/n for n in ['AGENDA.md','STATE.md','FINDINGS.md','sources.jsonl','PROGRESS.md']]
paths += [ROOT/'CLAUDE.md']
paths += [ROOT/'docs/zkmatrix-poc'/n for n in ['MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md','ZK60_THROUGHPUT_TARGET.md','ZK60_SPEED_PLAN_20261017.md','ZK60_PRIVACY_REQUIREMENTS.md']]
paths += [RESEARCH/'experiments/pool-live-capacity-20261020'/n for n in ['result.json','model-result.json','validation-result.json','hypotheses.json','README.md','source-facts.json']]
manifest = []
for p in paths:
    b = p.read_bytes()
    name = str(p.relative_to(ROOT)).replace('/','__')
    (snap/name).write_bytes(b)
    manifest.append(dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b),snapshot=name))
write('input-manifest.json',manifest)
for name in ['FINDINGS.md','MVP_STATUS.md','ZK60_DECISIONS.md','ZK60_CODEX_FABLE_COORDINATION.md']:
    p = RESEARCH/name if name=='FINDINGS.md' else ROOT/'docs/zkmatrix-poc'/name
    sections = re.split(r'(?m)(?=^#{1,3} )',p.read_text())
    index = [dict(heading=s.splitlines()[0] if s else '',lines=len(s.splitlines()),sha256=hashlib.sha256(s.encode()).hexdigest(),lead=' '.join(s.splitlines()[1:5]),tail=' '.join(s.splitlines()[-3:])) for s in sections]
    write(name+'.read-index.json',index)
ledger = [json.loads(s) for s in (RESEARCH/'sources.jsonl').read_text().splitlines() if s.strip()]
write('sources-read-index.json',[dict(title=s.get('title'),url=s.get('url'),cycle=s.get('cycle'),assessment=s.get('assessment')) for s in ledger])
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
(RESEARCH/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle0093 IN PROGRESS: `{RUN}`, checkpoint {now}.
Deadline 2026-10-20 01:38:54 UTC. Next cycle no earlier 02:18:54 UTC.
Prior complete state/findings/source ledger and latest results preserved in
experiments/device-allocation-coverage-20261020/startup/. Full memory indexes read.

Test: source-pinned allocation coverage and public request horizon for the
prior pool-retention candidate. Inventory pooled/raw/key/twiddle/sumcheck
scratch, actual trained callers and drain sites. Compare structural scanner
with independent source-line/hand-checked oracle and mutated source controls.
Do not repeat the prior synthetic capacity benchmark or infer native VRAM.

Ranked: 1 owner whole-prover GPU + verified fixed-context resident 1/2/4/8;
2 refined pool-retention coverage and lifecycle audit (this cycle);
3 exact DD D30 owner work, unbuilt; 4 prior public-loader ownership/scopes.
Baseline: existing exact/min pool reuse, full drain and reserve-hard retry.
Potential eliminated work: only unnecessary allocation/drain/retry; added
cost: public planner, bookkeeping/sync and lost reuse from incomplete horizon.
Ceiling unknown without native phase clocks; falsify on no complete horizon,
no useful idle capacity, changed outputs/refusals or enclosing regression.

Carried owner CPU8B T128 32blocks one16-thread pass,GPUoff,total478.737s
=0.267370 positions/s diagnostic; not reverified here. No new independently
verified full-stack proofs/passes/positions0/0/0; device/context none.
New witness/proof/serialization/verification clocks, steady/total proved rates
and startup fraction unmeasured. No long-context,resident series or decode.
Complete private8B >=50 proved tokens/s RTX5090/high-endGPU remains unmet.
No mask/opening reuse or privacy weakening. Only research writes; no runtime.
''')
print(json.dumps(dict(status='checkpointed',inputs=len(manifest),source_records=len(ledger),at=now)))
