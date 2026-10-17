"""Retain historical prefixes and verify research artifacts, never native gates."""
from pathlib import Path
import json,hashlib,datetime,resource,os,signal
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]


def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    checks=[]
    def check(label,ok):
        checks.append({'label':label,'pass':bool(ok)})
        if not ok:raise AssertionError(label)
    check('historical findings prefix retained',(ROOT/'FINDINGS.md').read_bytes().startswith((HERE/'startup/FINDINGS.md').read_bytes()))
    check('historical sources bytes retained',(ROOT/'sources.jsonl').read_bytes().startswith((HERE/'startup/sources.jsonl').read_bytes()))
    sources=[json.loads(x) for x in (ROOT/'sources.jsonl').read_text().splitlines()]
    check('source count297',len(sources)==297)
    new=[x for x in sources if x.get('cycle')=='0058']
    old=[x for x in sources if x.get('cycle')!='0058']
    # Five legacy records omit id. Do not rewrite historical records merely
    # to meet an invented whole-ledger uniqueness rule.
    check('five new IDs unique',len(new)==len({x['id'] for x in new})==5)
    check('new IDs disjoint from old',{x['id'] for x in new}.isdisjoint({x.get('id') for x in old}))
    for pin in json.loads((HERE/'native-pins.json').read_text()):
        check('unchanged native/measurement '+pin['path'],hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
    for pin in json.loads((HERE/'startup-pins.json').read_text()):
        if Path(pin['path']).name not in ['STATE.md','FINDINGS.md','PROGRESS.md','sources.jsonl']:
            check('unchanged instructions/owner memory '+pin['path'],hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
    res=json.loads((HERE/'result.json').read_text())
    execution=json.loads((HERE/'execution.json').read_text())
    audit=json.loads((HERE/'audit.json').read_text())
    check('experiment and audit pass',res['status']==audit['status']=='pass' and execution['exit_code']==0)
    check('experiment bounds',res['wall_seconds']<60 and execution['wall_seconds']<60 and res['max_rss_kib']<512*1024 and res['hardware']['threads']==1 and res['hardware']['gpu'] is None)
    check('18 controls',len(res['controls'])==18)
    check('no counted target tokens',res['proof_accounting']['tokens']==res['proof_accounting']['passes']==0)
    for name in ['STATE.md','PROGRESS.md','FINDINGS.md','progress/20261017T082624Z-8668a63c.md','handoffs/20261017-causal-axis-selector.md']:
        t=(ROOT/name).read_text()
        check('cycle report '+name,'20261017T082624Z-8668a63c' in t and 'unmeasured' in t)
    check('durable reports agree',(ROOT/'PROGRESS.md').read_text().split('\n',1)[1]==(ROOT/'progress/20261017T082624Z-8668a63c.md').read_text().split('\n',1)[1])
    check('run log pinned',hashlib.sha256((HERE/'run.log').read_bytes()).hexdigest()==execution['log_sha256'])
    manifest=[]
    for f in sorted(HERE.rglob('*')):
        if f.is_file() and '__pycache__' not in str(f) and f.name not in ['artifact-pins.json','checkpoint-audit.json']:
            b=f.read_bytes();manifest.append({'path':str(f.relative_to(HERE)),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()})
    (HERE/'artifact-pins.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for x in manifest:
        check('artifact '+x['path'],hashlib.sha256((HERE/x['path']).read_bytes()).hexdigest()==x['sha256'])
    out={'status':'pass','checks':checks,'check_count':len(checks),'artifacts':len(manifest),
         'finished_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
         'scope':'Research prefix/source/artifact integrity, no native proof or speed acceptance'}
    (HERE/'checkpoint-audit.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:out[k] for k in ['status','check_count','artifacts','finished_at_utc']}))


if __name__=='__main__':main()
