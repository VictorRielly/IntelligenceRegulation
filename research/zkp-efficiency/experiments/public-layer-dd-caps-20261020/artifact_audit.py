#!/usr/bin/env python3
"""Bounded final evidence-integrity check. No native proof is executed."""
from pathlib import Path
import hashlib
import json
import os
import resource
import signal
import time

def run():
    resource.setrlimit(resource.RLIMIT_AS,(512<<20,512<<20))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    start=time.perf_counter();e=Path(__file__).resolve().parent;w=e.parent.parent
    count=0
    def check(ok,why):
        nonlocal count
        count+=1
        assert ok,why
    snap=json.loads((e/'startup-snapshot.json').read_text())
    for name,rec in snap['files'].items():
        p=Path(name);b=p.read_bytes()
        if p.name in ['FINDINGS.md','sources.jsonl']:
            check(hashlib.sha256(b[:rec['bytes']]).hexdigest()==rec['sha256'],'append-only prefix '+name)
        elif p.name not in ['STATE.md','PROGRESS.md']:
            check(hashlib.sha256(b).hexdigest()==rec['sha256'],'unchanged instruction/status '+name)
    pins=json.loads((e/'source-pins.json').read_text())
    for name,rec in pins.items():
        check(hashlib.sha256(Path(name).read_bytes()).hexdigest()==rec['sha256'],'source '+name)
        check(hashlib.sha256((e/rec['copy']).read_bytes()).hexdigest()==rec['sha256'],'copy '+name)
    ledger=[json.loads(s) for s in (w/'sources.jsonl').read_text().splitlines()]
    records=json.loads((e/'source-records.json').read_text())
    check(len(ledger)==702,'ledger length');check(ledger[-10:]==records,'new source records')
    for r in records:
        for k in ['access_date','url','date_evidence','publication_date','verified_update_date','implementation_license','inspected_commit_id','reproduced_performance']:
            check(k in r,'source key '+k)
        check(r['reproduced_performance'] is False,'no external speed reproduced')
    h=json.loads((e/'hypotheses.json').read_text());old=json.loads((e/'prior/hypotheses.json').read_text())
    check(len(h)==26,'rank count');check(sorted(x['rank'] for x in h)==list(range(1,27)),'rank sequence')
    for a,b in zip(h,old):
        if a['rank']!=5:check(a==b,'prior hypothesis preserved '+str(a['rank']))
    c=json.loads((e/'cycle-result.json').read_text());p=json.loads((e/'result.json').read_text());a=json.loads((e/'validation-result.json').read_text())
    check(c['status']=='COMPLETE' and p['status']==a['status']=='PASS','cycle status')
    check(c['probe']['checks']==p['checks']==53836,'probe checks')
    check(c['audit']['checks']==a['checks']==8915,'audit checks')
    check(c['new_verified_full_stack']['proofs']==c['new_verified_full_stack']['positions']==0,'zero proved positions')
    for r in json.loads((e/'commands.json').read_text()):
        check(r['returncode']==0,'command passed');check(r['parent_elapsed_s']<60,'bounded command')
    for rel in ['STATE.md','PROGRESS.md','progress/20261020T211854Z-71297104.md','handoffs/20261020-public-layer-dd-caps.md']:
        s=(w/rel).read_text();check('20261020T211854Z-71297104' in s,'report run id '+rel)
        check('unmeasured' in s and '0 / 0 / 0' in s,'scope '+rel)
    out=dict(status='PASS',checks=count,original_source_records_preserved=692,source_ledger=702,
             prior_findings_prefix_preserved=True,agenda_unchanged=True,prior_ranked_hypotheses_preserved=23,
             elapsed_s=time.perf_counter()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
    (e/'artifact-audit.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))

if __name__=='__main__':run()
