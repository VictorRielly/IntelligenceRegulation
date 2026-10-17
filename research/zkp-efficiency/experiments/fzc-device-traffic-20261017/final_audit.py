#!/usr/bin/env python3
"""Bounded artifact/source consistency gate; no native or GPU work."""
from pathlib import Path
import datetime, hashlib, json, os, resource, signal, time
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    t0=time.perf_counter();os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    checks=0
    def ck(x):
        nonlocal checks
        assert x;checks+=1
    r=json.loads((HERE/'result.json').read_text());a=json.loads((HERE/'audit-result.json').read_text())
    ck(r['status']==a['status']=='PASS');ck(r['checks']['fixtures']==96);ck(r['checks']['variant_runs']==384)
    ck(r['checks']['round_words']==12576);ck(r['checks']['recovered_one_words']==1152);ck(r['checks']['final_words']==15936)
    ck(r['checks']['phase_access_counts']==4128);ck(r['checks']['source_formula_checks']==384)
    ck(a['independent_schedule_and_source_checks']==148);ck(a['independent_eq_words']==15374)
    ck(len(r['negative_controls'])==10 and all(r['negative_controls'].values()))
    ck(len(a['negative_controls'])==3 and all(a['negative_controls'].values()))
    for run in [r,a]:
        ck(run['wall_seconds']<60);ck(run['child_peak_rss_kib']<512*1024);ck(run['parent_peak_rss_kib']<512*1024)
    lines=(ROOT/'sources.jsonl').read_text().splitlines();prior=(HERE/'startup/sources.jsonl').read_text().splitlines()
    ck(lines[:len(prior)]==prior);ck(len(prior)==331);ck(len(lines)==337)
    new=[json.loads(x) for x in lines[len(prior):]];old_ids={json.loads(x).get('id') for x in prior}
    ck(len({x['id'] for x in new})==6);ck(all(x['id'] not in old_ids for x in new))
    for record in new:
        ck(record['access_date']=='2026-10-17' and record['run_id']==r['run_id'])
        ck('date_evidence' in record and 'implementation_license' in record and 'inspected_commit_id' in record)
    pins=json.loads((HERE/'native-pins.json').read_text());drift=[]
    for pin in pins:
        ck(digest(ROOT/pin['snapshot'])==pin['sha256'])
        if digest(Path(pin['source']))!=pin['sha256']:drift.append(pin['source'])
    code_drift=[x for x in drift if x.endswith(('.rs','.cu'))]
    ck(not code_drift)
    src=(HERE/'native/ops__zkp-mvp__gpu-zerocheck__hashline__src__gpu__fzc_kernels.cu').read_text()
    instrumented=(HERE/'instrumented.cu').read_text()
    ck(instrumented.replace('{ nread++; f2 r;','{ f2 r;').replace('{ nwrite++; p[2 * i]','{ p[2 * i]')==src)
    reports=[ROOT/'STATE.md',ROOT/'PROGRESS.md',ROOT/'progress'/f"{r['run_id']}.md",ROOT/'handoffs/20261017-fzc-device-traffic.md']
    for path in reports:ck('0065' in path.read_text())
    ck('COMPLETE' in (ROOT/'STATE.md').read_text());ck('unachieved' in (ROOT/'PROGRESS.md').read_text())
    patch=(HERE/'measurement-note.patch').read_text();ck('1,848' in patch and '1,344' in patch)
    files=sorted(p for p in HERE.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name not in ['artifact-manifest.json','final-audit.json'])
    files+=reports+[ROOT/'FINDINGS.md',ROOT/'sources.jsonl']
    manifest=[{'path':str(p.relative_to(ROOT)),'bytes':p.stat().st_size,'sha256':digest(p)} for p in files]
    ck(len(manifest)==len({p['path'] for p in manifest}))
    (HERE/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    out={'status':'PASS','checks':checks,'files_pinned':len(manifest),'captured_native_files':len(pins),'live_code_drift':code_drift,'live_noncode_drift':drift,'notes':'Owner progress-ledger drift retained; captured source and instrumented functions remain pinned. Not native/GPU/privacy validation.','finished_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'wall_seconds':time.perf_counter()-t0,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
    (HERE/'final-audit.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
if __name__=='__main__':main()
