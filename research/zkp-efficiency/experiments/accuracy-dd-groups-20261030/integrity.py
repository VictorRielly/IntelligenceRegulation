"""Bounded final integrity check; no native execution."""
from pathlib import Path
import datetime,hashlib,json,os,re,resource,signal,time
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
os.nice(19)
resource.setrlimit(resource.RLIMIT_CPU,(30,30))
resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,)*2)
signal.alarm(40)
start=time.monotonic()
E=Path(__file__).resolve().parent
ROOT=E.parents[1]
RUN='20261030T194123Z-776cb104'
checks=0
old=(E/'startup/FINDINGS.md').read_bytes()
current=(ROOT/'FINDINGS.md').read_bytes()
assert current.startswith(old);checks+=1
old_sources=(E/'startup/sources.jsonl').read_bytes()
current_sources=(ROOT/'sources.jsonl').read_bytes()
assert current_sources.startswith(old_sources);checks+=1
records=[json.loads(x) for x in current_sources.splitlines() if x.strip()]
assert len(records)==1158 and all(x['run_id']==RUN for x in records[-8:]);checks+=1
old_h=json.loads((E.parent/'dd-group-scaffold-cost-20261030/hypotheses.json').read_text())
new_h=json.loads((E/'hypotheses.json').read_text())
assert len(new_h)==106
for old,new in zip(old_h,new_h):
    new=dict(new);new.pop('cycle0171_refinement',None)
    assert new==old;checks+=1
for p in json.loads((E/'source-pins.json').read_text()):
    assert hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'];checks+=1
for p in json.loads((E/'closing-documents.json').read_text()):
    assert p['unchanged_since_startup']
    assert hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'];checks+=1
for mode in ['experiment','audit']:
    x=json.loads((E/(mode+'-execution.json')).read_text())
    assert x['returncode']==0 and x['wall_s']<60 and x['maxrss_kib']<512*1024;checks+=1
    for name in ['engine.py','reference.py','experiment.py']+(['audit.py'] if mode=='audit' else []):
        assert hashlib.sha256((E/name).read_bytes()).hexdigest()==x['source_sha256'][name];checks+=1
docs=[ROOT/'STATE.md',ROOT/'PROGRESS.md',ROOT/'progress'/f'{RUN}.md',E/'README.md',ROOT/'handoffs/20261030-accuracy-dd-groups.md',ROOT/'FINDINGS.md']
links=[]
for p in docs:
    t=p.read_text()
    if p.name=='FINDINGS.md':t=t[t.index('## Cycle0171 —'):]
    for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)',t):
        if '://' in target or target.startswith('#'):continue
        target=target.split('#')[0]
        assert (p.parent/target).exists(),(str(p),target)
        links.append(dict(document=str(p.relative_to(ROOT)),target=target));checks+=1
account=json.loads((E/'target-accounting.json').read_text())
assert account['new_independently_verified_full_stack_proofs']==account['proved_positions']==account['passes']==0
assert all(x is None for x in account['clocks'].values());checks+=1
artifact=[]
for p in sorted(E.rglob('*')):
    if not p.is_file() or p.name in ['artifact-manifest.json','final-integrity.json']:continue
    b=p.read_bytes();artifact.append(dict(path=str(p.relative_to(ROOT)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
for p in docs:
    b=p.read_bytes();artifact.append(dict(path=str(p.relative_to(ROOT)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(E/'artifact-manifest.json').write_text(json.dumps(artifact,indent=2)+'\n')
out=dict(status='PASS',checks=checks,report_links=len(links),artifact_records=len(artifact),
         checkpoint_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),wall_s=time.monotonic()-start,
         maxrss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,new_proofs=0,proved_positions=0,
         preserves_prior_findings_and_sources=True,owner_source_pins_unchanged=True,deadline='2026-10-30T20:01:23Z')
(E/'final-integrity.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
