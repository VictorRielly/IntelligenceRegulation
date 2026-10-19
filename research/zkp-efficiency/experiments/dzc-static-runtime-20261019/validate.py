#!/usr/bin/env python3
"""Final artifact/prefix/source/deadline checks; read-only outside this experiment."""
import datetime
import hashlib
import json
import os
import resource
import signal
from pathlib import Path
H=Path(__file__).resolve().parent
R=H.parent.parent
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
checks=0
for n in ['FINDINGS.md','sources.jsonl']:
 assert (R/n).read_bytes().startswith((H/'startup'/n).read_bytes());checks+=1
assert (R/'AGENDA.md').read_bytes()==(H/'startup/AGENDA.md').read_bytes();checks+=1
sources=[json.loads(x) for x in (R/'sources.jsonl').read_text().splitlines()]
assert len(sources)==435;checks+=1
new=json.loads((H/'source-records.json').read_text());assert sources[-8:]==new and len({q['id'] for q in new})==8;checks+=1
for p in json.loads((H/'source-pins.json').read_text())+json.loads((H/'owner-evidence-pins.json').read_text()):
 assert hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'];checks+=1
native=[p for p in json.loads((H/'source-pins.json').read_text()) if p['path'].endswith('/field.rs')]
assert len(native)==1 and hashlib.sha256((H/'native-field.rs').read_bytes()).hexdigest()==native[0]['sha256'];checks+=1
for n in ['execution.json','audit-execution.json']:
 q=json.loads((H/n).read_text());assert q['returncode']==0 and q['wall_seconds']<60;checks+=1
r=json.loads((H/'result.json').read_text());a=json.loads((H/'audit-result.json').read_text())
assert r['status']==a['status']=='PASS' and a['checks']==2372;checks+=1
assert r['field_mode']=='native' and r['field_call_boundary']=='noinline Fp2 wrappers';checks+=1
assert len(r['controls'])==7 and all(r['controls'].values());checks+=1
assert r['wall_seconds']<60 and r['compiler_rss_kib']<512*1024 and r['rss_kib']<512*1024;checks+=1
assert r['cpu_affinity']==[0] and r['threads']==1;checks+=1
assert a['assembly']['native']['baseline']['local_stack_allocation_bytes']==1160;checks+=1
assert a['assembly']['native']['driven']['local_stack_allocation_bytes']==360;checks+=1
assert a['assembly']['native']['baseline']['call_instructions']==a['assembly']['native']['driven']['call_instructions']==884;checks+=1
assert json.loads((H/'native-all-inline-timeout/execution.json').read_text())['returncode']!=0;checks+=1
assert 'timed out after 40 seconds' in (H/'native-all-inline-timeout/run.log').read_text();checks+=1
assert 'signed_base_wrap' in (H/'run.py').read_text() and '% P' in (H/'run.py').read_text();checks+=1
t=json.loads((H/'target-accounting.json').read_text())['new_target_work']
for k in ['completed_independently_verified_full_stack_proofs','complete_model_passes','proved_token_positions']:
 assert t[k]==0;checks+=1
for k in ['steady_proved_tokens_per_second','total_workload_proved_tokens_per_second','startup_fraction',
          'witness_seconds','proof_seconds','serialization_seconds','verification_seconds']:
 assert t[k] is None;checks+=1
for p in [R/'STATE.md',R/'PROGRESS.md',R/'progress/20261019T121854Z-575be12a.md',R/'handoffs/20261019-dzc-static-runtime.md',H/'README.md']:
 assert p.is_file() and len(p.read_text())>300;checks+=1
assert (R/'STATE.md').read_bytes()==(H/'final-state.md').read_bytes();checks+=1
assert (R/'PROGRESS.md').read_bytes()==(H/'final-progress.md').read_bytes();checks+=1
now=datetime.datetime.now(datetime.timezone.utc)
assert now<datetime.datetime(2026,10,19,12,38,54,tzinfo=datetime.timezone.utc);checks+=1
v=dict(status='PASS',checks=checks,checked_utc=now.isoformat(),source_records=435,
       production_and_owner_pins_unchanged=True,prior_findings_and_sources_preserved=True,
       target_proved_positions=0,limits='one nice19 CPU,59sCPU/wall,512MiBAS',
       scope='Artifact and source-pin integrity; does not verify a native proof or privacy.')
(H/'validation.json').write_text(json.dumps(v,indent=2)+'\n')
manifest=[]
for p in sorted(H.rglob('*')):
 if not p.is_file() or p.name=='artifact-sha256.json':continue
 b=p.read_bytes();manifest.append(dict(path=str(p.relative_to(H)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
for p in [R/'STATE.md',R/'PROGRESS.md',R/'progress/20261019T121854Z-575be12a.md',R/'handoffs/20261019-dzc-static-runtime.md']:
 b=p.read_bytes();manifest.append(dict(path=str(p.resolve()),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(H/'artifact-sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(v,indent=2))
