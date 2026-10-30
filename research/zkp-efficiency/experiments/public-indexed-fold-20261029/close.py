"""Final read-only artifact/mandate audit and local hash manifest."""
from pathlib import Path
import hashlib,json,datetime,re,resource,signal,os
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_CPU,(40,40));resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2));signal.alarm(45)
D=Path(__file__).resolve().parent;R=D.parent.parent;run='20261029T205649Z-c620e79d'
checks=0
def check(x,why=''):
    global checks
    assert x,why
    checks+=1
def sha(b):return hashlib.sha256(b).hexdigest()
for n in ['FINDINGS.md','sources.jsonl']:
    old=(D/'startup'/n).read_bytes();new=(R/n).read_bytes()
    check(new.startswith(old),'prior ledger prefix '+n)
    check(sha(new[:len(old)])==sha(old))
for pin in json.loads((D/'memory-index.json').read_text()):
    if Path(pin['path']).name in ['STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl']:continue
    check(sha(Path(pin['path']).read_bytes())==pin['sha256'],'mandate/source drift')
for collection in ['native-pins.json','seam-pins.json']:
    for pin in json.loads((D/collection).read_text()):
        check(sha(Path(pin['path']).read_bytes())==pin['sha256'],'native source drift')
        check(sha((D/pin['snapshot']).read_bytes())==pin['sha256'],'snapshot drift')
for n in ['result.json','census-result.json','cost-result.json','audit-result.json']:
    check(json.loads((D/n).read_text())['status']=='PASS',n)
for stage in ['compile','probe','census','cost','audit']:
    x=json.loads((D/(stage+'-execution.json')).read_text())
    check(x['exit_code']==0 and x['wall_s']<60 and x['max_rss_kib']<512*1024)
    check(x['one_cpu_affinity'] and x['address_space_mib']<=512 and not x['gpu'])
old=json.loads((D/'startup/prior-hypotheses.json').read_text());new=json.loads((D/'hypotheses.json').read_text())
check(len(new)==74 and new[:72]==old)
check(len((R/'sources.jsonl').read_text().splitlines())==1010)
for p in [R/'STATE.md',R/'PROGRESS.md',R/'progress'/f'{run}.md']:
    s=p.read_text();check(run in s);check('unmeasured' in s);check('unachieved' in s);check('8B' in s)
    check('109,512' in s and '376' in s and '1,206' in s,'final counts')
    check('0 / 0 / 0' in s)
    for link in re.findall(r'\]\(([^)]+)\)',s):
        if not link.startswith('https://'):check((p.parent/link).exists(),'local report link '+link)
check((D/'final-state.md').read_bytes()==(R/'STATE.md').read_bytes())
check(len(list(D.glob('web*.json')))==8)
for p in D.glob('web*.json'):
    x=json.loads(p.read_text());check('See tool output' not in str(x),'placeholder raw log')
completion=json.loads((D/'completion.json').read_text());check(completion['status']=='COMPLETE')
for k in ['new_verified_full_stack_proofs','new_model_passes','new_proved_positions']:check(completion[k]==0)
now=datetime.datetime.now(datetime.timezone.utc)
check(now<datetime.datetime.fromisoformat(completion['deadline_utc']),'cycle deadline')
manifest=[]
for p in sorted(D.rglob('*')):
    if p.is_file() and p.name not in ['artifact-manifest.json','closing-audit-result.json']:
        b=p.read_bytes();manifest.append(dict(path=str(p.relative_to(D)),bytes=len(b),sha256=sha(b)))
(D/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
out=dict(status='PASS',checks=checks,run_id=run,closed_at_utc=now.isoformat(),artifact_files=len(manifest),prior_findings_sources_preserved=True,production_and_owner_pins_unchanged=True,prior_hypotheses_preserved=72,ranked_hypotheses=74,new_verified_full_stack_proofs=0,new_model_passes=0,new_proved_positions=0)
(D/'closing-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
