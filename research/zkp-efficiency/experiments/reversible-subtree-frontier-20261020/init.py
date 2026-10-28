from pathlib import Path
import hashlib,json,datetime,platform

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
PROJECT=ROOT.parents[1]
RUN='20261020T191854Z-93bbe548'
PRIOR=ROOT/'experiments/reversible-fraction-tree-20261020'
def sha(b):return hashlib.sha256(b).hexdigest()
def write(name,x):
    (HERE/name).write_text(json.dumps(x,indent=2)+'\n')
manifest=[]
for p in [ROOT/x for x in ['AGENDA.md','STATE.md','FINDINGS.md','sources.jsonl','PROGRESS.md']]+[PROJECT/x for x in ['CLAUDE.md','docs/zkmatrix-poc/MVP_STATUS.md','docs/zkmatrix-poc/ZK60_DECISIONS.md','docs/zkmatrix-poc/ZK60_CODEX_FABLE_COORDINATION.md','docs/zkmatrix-poc/ZK60_THROUGHPUT_TARGET.md','docs/zkmatrix-poc/START_HERE.md','docs/zkmatrix-poc/ZK60_PRIVACY_REQUIREMENTS.md','docs/zkmatrix-poc/ZK60_SPEED_PLAN_20261017.md']]:
    b=p.read_bytes(); dest=HERE/'startup'/p.name;dest.parent.mkdir(exist_ok=True);dest.write_bytes(b)
    manifest.append(dict(path=str(p),snapshot=str(dest.relative_to(HERE)),sha256=sha(b),bytes=len(b)))
write('startup/manifest.json',manifest)
records=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines() if x.strip()]
write('starting-source-index.json',dict(records=len(records),urls=sorted({r.get('url','') for r in records}),last_records=records[-9:]))
findings=(ROOT/'FINDINGS.md').read_text()
write('starting-findings-index.json',dict(bytes=len(findings.encode()),sections=[x for x in findings.splitlines() if x.startswith('## ')]))
pins=[]
for name in ['fp2.py','reference.py','support.py','tiled_fp2.py','reversible.py','run_bounded.py','hypotheses.json','inputs.json','prior-model-result.json','forest-result.json','capacity-result.json','result.json','validation-result.json','cycle-result.json']:
    p=PRIOR/name;b=p.read_bytes();(HERE/name).write_bytes(b)
    pins.append(dict(path=str(p),snapshot=name,sha256=sha(b),bytes=len(b)))
for r in json.loads((PRIOR/'source-pins.json').read_text()):
    if r['snapshot'].startswith('source/'):
        p=Path(r['path']);b=p.read_bytes();d=HERE/r['snapshot'];d.parent.mkdir(exist_ok=True);d.write_bytes(b)
        pins.append(dict(path=str(p),snapshot=r['snapshot'],sha256=sha(b),bytes=len(b),matches_prior=sha(b)==r['sha256']))
write('source-pins.json',pins)
write('hardware.json',dict(platform=platform.platform(),processor=platform.processor(),cpuinfo=Path('/proc/cpuinfo').read_text().split('\n\n')[0],gpu_used=False,estimated_experiment_MiB=64))
for name in ['result.json','validation-result.json','cycle-result.json','forest-result.json','capacity-result.json']:
    (HERE/name).rename(HERE/('prior-'+name))
(ROOT/'STATE.md').write_text(f'''# ZKP efficiency explorer — durable state

Cycle0111 IN PROGRESS: `{RUN}`. Started 2026-10-20T19:18:54Z.
Deadline 19:38:54 UTC; checkpoint early at {datetime.datetime.now(datetime.timezone.utc).isoformat()}.
Read AGENDA, durable memory, all670 source records indexed, latest0110 results,
project instructions/current status/decisions/coordination and throughput target.
Snapshots/hashes: experiments/reversible-subtree-frontier-20261020/startup/.
Prior findings and negative results preserved; no production files modified.

Bounded experiment: reversible subtree tiles plus immutable frontier, native Fp2
synthetic sources, independent immutable reference and ordered cubic consumer.
Charge source rereads, rebuild/recovery/inversion costs, frontier capacity,
consumer inactive tails and prefix scratch. Existing per-attempt U8 reciprocal
cache may avoid only the final recovery inversion; investigate exact eligibility.
Baseline previous full-column selected80–128MiB at2^21 leaves exceeds prospective
36.022MiB budget; no native/private proof work has been removed.
Top3 remain owner wholeGPU+verified resident1/2/4/8, DDcontext scaling, complete
phase/capacity telemetry. Tile hypothesis refined this cycle; falsify on original
ordered consumer mismatch, omitted capacity or overhead erasing enclosing benefit.

New independently verified full-stack proofs/passes/positions0/0/0; actual model
context/device none; witness/proof/serialization/verification/startup and rates
unmeasured. No long-prefill/resident-model/decode run, no GPU/build/install/Git.
Larger workloads allowed, fresh masks required, target >=50 proved positions/s
on RTX5090 or another named high-endGPU remains unachieved.
''')
print(json.dumps(dict(run_id=RUN,sources=len(records),snapshots=len(manifest),pins=len(pins))))
