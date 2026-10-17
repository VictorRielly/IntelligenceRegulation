#!/usr/bin/env python3
"""Bounded final artifact/provenance audit. Does not rerun measurements."""
from pathlib import Path
import datetime, hashlib, json, os, resource, signal, time
P=Path(__file__).resolve().parent
R=P.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    start=time.perf_counter();os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));signal.alarm(59)
    checks=0
    for name,script in [('result.json','run.py'),('audit-result.json','audit.py')]:
        j=json.loads((P/name).read_text());assert j['status']=='pass' and j['source_sha256']==sha(P/script);checks+=2
        assert j['threads']==1 and j['cpu_affinity']==[0] and j['nice']==19;checks+=1
    j=json.loads((P/'result.json').read_text());assert j['wall_seconds']<60 and j['peak_rss_kib']<512*1024 and j['child_peak_rss_kib']<512*1024;checks+=1
    assert j['counts']['fixtures']==72 and len(j['negative_controls'])==12 and all(j['negative_controls'].values());checks+=1
    assert (R/'sources.jsonl').read_bytes().startswith((P/'startup/sources.jsonl').read_bytes());checks+=1
    before=(P/'startup/sources.jsonl').read_text().splitlines();after=(R/'sources.jsonl').read_text().splitlines()
    assert len(before)==325 and len(after)==331;checks+=1
    records=[json.loads(l) for l in after];newids={v['id'] for v in records[-6:]};assert len(newids)==6 and not newids.intersection({v.get('id') for v in records[:-6]});checks+=1
    assert (R/'FINDINGS.md').read_bytes().startswith((P/'startup/FINDINGS.md').read_bytes());checks+=1
    for q in ['STATE.md','PROGRESS.md','progress/20261017T142624Z-6b84b6ef.md','handoffs/20261017-fzc-grouped-equality.md']:
        assert '20261017T142624Z-6b84b6ef' in (R/q).read_text();checks+=1
    assert (R/'AGENDA.md').read_bytes()==(P/'startup/AGENDA.md').read_bytes();checks+=1
    drifts=[]
    for manifest in ['native-pins.json','owner-pins.json']:
        for pin in json.loads((P/manifest).read_text()):
            assert sha(P/pin['snapshot'])==pin['sha256'];checks+=1
            if sha(Path(pin['path']))!=pin['sha256']:drifts.append(dict(path=pin['path'],captured=pin['sha256'],current=sha(Path(pin['path']))))
    files=[]
    for f in sorted(P.rglob('*')):
        if f.is_file() and '__pycache__' not in f.parts and f.name not in ['artifact-manifest.json','final-audit.json']:
            assert f.resolve().is_relative_to(R.resolve());checks+=1
            files.append(dict(path=str(f.relative_to(R)),sha256=sha(f),bytes=f.stat().st_size))
    for q in ['STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl','progress/20261017T142624Z-6b84b6ef.md','handoffs/20261017-fzc-grouped-equality.md']:
        files.append(dict(path=q,sha256=sha(R/q),bytes=(R/q).stat().st_size))
    (P/'artifact-manifest.json').write_text(json.dumps(files,indent=2)+'\n')
    out=dict(status='pass',checks=checks,files_pinned=len(files),completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),live_source_drifts=drifts,
        wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,source_sha256=sha(Path(__file__)),
        limits='one CPU thread, nice19,59s/512MiB caps; no native/proof/GPU tests',scope='artifact/source/checkpoint provenance only')
    (P/'final-audit.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
if __name__=='__main__':main()
