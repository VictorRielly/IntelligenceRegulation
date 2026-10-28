"""Final integrity check, bounded and single-threaded."""
from pathlib import Path
import datetime,hashlib,json,resource,time
H=Path(__file__).resolve().parent;R=H.parent.parent
checks=0
def ck(v,msg=''):
    global checks
    checks+=1
    assert v,msg
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
    start=time.monotonic();changes=[]
    startup=json.loads((H/'startup-pins.json').read_text())
    for p in startup:
        ck(sha((H/'startup'/Path(p['path']).name).read_bytes())==p['sha256'])
        path=Path(p['path'])
        if not str(path).startswith(str(R)):
            if sha(path.read_bytes())!=p['sha256']:
                dst=H/'end-read'/path.name;dst.parent.mkdir(exist_ok=True);dst.write_bytes(path.read_bytes())
                changes.append(dict(path=str(path),start_sha256=p['sha256'],end_sha256=sha(dst.read_bytes()),copy=str(dst),classification='Concurrent external document change; only research copy written'))
    live_source_changes=[]
    pins=json.loads((H/'source-pins.json').read_text())
    for p in pins:
        ck(sha((R/p['copy']).read_bytes())==p['sha256'])
        path=Path(p['path']);path=path if path.is_absolute() else R/path
        if sha(path.read_bytes())!=p['sha256']:live_source_changes.append(str(path))
    old=(H/'startup/FINDINGS.md').read_bytes();ck((R/'FINDINGS.md').read_bytes().startswith(old),'prior findings prefix')
    old=(H/'startup/sources.jsonl').read_bytes();new=(R/'sources.jsonl').read_bytes();ck(new.startswith(old),'prior source bytes')
    records=[json.loads(x) for x in new.splitlines()];ck(len(records)==737)
    additions=json.loads((H/'source-records.json').read_text());ck(records[727:]==additions)
    for s in additions:
        for key in ['access_date','publication_date','verified_update_date','url','implementation_license','inspected_commit_id']:
            ck(key in s,key)
        ck(s['external_execution']==False and s['reproduced_performance']==False)
    ck(next(s for s in additions if s['url']=='https://developer.nvidia.com/blog/cuda-graphs/')['prior_exact_url_records']==0)
    old=json.loads((R/'experiments/public-inverse-scale-20261021/hypotheses.json').read_text())
    new=json.loads((H/'hypotheses.json').read_text());ck(len(new)==34)
    for h in old:
        match=next(x for x in new if x['title']==h['title'])
        ck({k:v for k,v in match.items() if k!='rank'}=={k:v for k,v in h.items() if k!='rank'})
    ck(new[:4]==old[:4]);ck([x['rank'] for x in new]==list(range(1,35)))
    for name in ['result.json','census-result.json','validation-result.json']:
        ck(json.loads((H/name).read_text())['status'].startswith('PASS'))
    target=json.loads((H/'target-accounting.json').read_text());ck(target['positions']==target['passes']==target['full_stack_proofs']==0)
    for key in ['witness_s','proof_s','serialization_s','verification_s','startup_fraction','steady_rate','total_rate']:ck(target[key] is None)
    for entry in [json.loads(x) for x in (H/'commands.jsonl').read_text().splitlines()]:ck(entry['exit_code']==0)
    # Parse only syntax, never execute the uncompiled CUDA candidate.
    for path in H.glob('*.py'):compile(path.read_text(),str(path),'exec');ck(True)
    ck('UNCOMPILED' in (H/'candidate_fold_pack.cuh').read_text())
    artifacts=[]
    for p in sorted(H.rglob('*')):
        if not p.is_file() or p.name in ['artifact-hashes.json','artifact-audit-result.json','commands.jsonl','artifact_audit.py.stdout','artifact_audit.py.stderr']:continue
        artifacts.append(dict(path=str(p.relative_to(R)),sha256=sha(p.read_bytes()),bytes=p.stat().st_size))
    (H/'artifact-hashes.json').write_text(json.dumps(artifacts,indent=2)+'\n')
    for p in artifacts:ck(sha((R/p['path']).read_bytes())==p['sha256'])
    out=dict(status='PASS',checks=checks,artifact_hashes=len(artifacts),source_pins=len(pins),prior_source_records=727,new_source_records=10,prior_hypotheses_preserved=31,ranked_hypotheses=34,live_source_changes_after_capture=live_source_changes,concurrent_document_updates=changes,wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    (H/'artifact-audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
if __name__=='__main__':main()
