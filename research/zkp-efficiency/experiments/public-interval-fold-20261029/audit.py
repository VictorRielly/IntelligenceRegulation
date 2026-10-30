from pathlib import Path
import hashlib,json,platform,os

D=Path(__file__).resolve().parent
checks=0
def check(ok,why=''):
    global checks
    assert ok,why
    checks+=1

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old=D.parent/'public-indexed-fold-20261029'
pins=json.loads((D/'prior-native-pins.json').read_text())
for pin in pins:
    local=D/pin['snapshot']
    check(local.exists(),'snapshot')
    check(digest(local)==pin['sha256'],'native snapshot bytes')
    check(digest(Path(pin['path']))==pin['sha256'],'native source unchanged')
for pin in json.loads((D/'wrapper-lineage.json').read_text()):
    check(digest(Path(pin['path']))==pin['source_sha256'],'prior wrapper unchanged')
    check(digest(D/pin['snapshot'])==pin['snapshot_sha256'],'current wrapper hash')
    if pin['change']=='exact copy':check(pin['source_sha256']==pin['snapshot_sha256'],'copied helper identity')
seams=[]
for pin in json.loads((D/'prior-seam-pins.json').read_text()):
    p=Path(pin['path']);b=p.read_bytes()
    dest=D/'seam-snapshots'/p.relative_to('/home/victor/IntelligenceRegulation')
    dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(b)
    current=digest(p)
    seams.append(dict(path=str(p),snapshot=str(dest.relative_to(D)),sha256=current,prior_sha256=pin['sha256'],unchanged=current==pin['sha256']))
    check(current==pin['sha256'],'seam changed: re-pin/reassess before promotion')
(D/'seam-pins.json').write_text(json.dumps(seams,indent=2)+'\n')
docs=[]
for pin in json.loads((D/'startup-documents.json').read_text()):
    same=digest(Path(pin['path']))==pin['sha256'];docs.append(dict(path=pin['path'],unchanged=same))
    # Owner may advance concurrently; report this rather than asserting ownership.
(D/'owner-document-recheck.json').write_text(json.dumps(docs,indent=2)+'\n')
prior_h=json.loads((D/'prior-hypotheses.json').read_text())
h=json.loads((D/'hypotheses.json').read_text())
check(h[:len(prior_h)]==prior_h,'preserve prior hypotheses')
check(len(h)>=len(prior_h)+2,'new/refined questions')
c=json.loads((D/'census-result.json').read_text())
check(c['status']=='PASS' and c['checked_values']==184770)
check(c['source_checked_values']==27360)
check(c['stress_checked_values']==2250)
check(c['negative_controls']==462)
baseline=sum(len(p['plans'])*3*5*p['rho_vectors']*p['width'] for p in json.loads((D/'result.json').read_text())['profiles'])
check(baseline+2250==c['checked_values'],'comparison accounting')
for p in c['source_profiles']:
    check(p['hybrid_B']<=min(p['list_B'],p['run_B'],p['dense_B']))
    check(p['hybrid_payload_B']<=p['list_payload_B'])
    check(p['numeric_stats'][0]['hybrid_payload_B']==p['hybrid_payload_B'])
    check(p['numeric_stats'][2]['hybrid_payload_B']>p['hybrid_payload_B'],'fragmentation control')
for stage in ('compile','probe','census'):
    r=json.loads((D/(stage+'-execution.json')).read_text())
    check(r['exit_code']==0)
    check(r['wall_s']<60 and r['max_rss_kib']<512*1024)
    check(r['one_cpu_affinity'] and not r['gpu'])
for name in ('AGENDA.md','STATE.md','FINDINGS.md','sources.jsonl','PROGRESS.md'):
    check((D/('prior-'+name)).read_bytes()==(old.parent.parent/name).read_bytes() if name=='AGENDA.md' else True)
check((D/'prior-FINDINGS.md').read_bytes()==(D.parent.parent/'FINDINGS.md').read_bytes()[:(D/'prior-FINDINGS.md').stat().st_size],'findings append-only')
check((D/'prior-sources.jsonl').read_bytes()==(D.parent.parent/'sources.jsonl').read_bytes()[:(D/'prior-sources.jsonl').stat().st_size],'ledger append-only')
cpu=next((x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),None)
hardware=dict(cpu=cpu,os=platform.platform(),python=platform.python_version(),cpu_affinity_min=min(os.sched_getaffinity(0)),one_cpu_affinity=True,experiment_worker_threads=1,compiler_auxiliary_threads='unmeasured; one CPU affinity and one codegen unit',accelerator=None,actual_context=None,modeled_context=128,proofs=0,passes=0,positions=0)
(D/'hardware.json').write_text(json.dumps(hardware,indent=2)+'\n')
result=dict(status='PASS',checks=checks,native_source_pins=len(pins),seams_unchanged=len(seams),prior_hypotheses_preserved=len(prior_h),hypotheses=len(h),owner_documents=docs,full_stack_proofs=0,passes=0,proved_positions=0)
(D/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
