#!/usr/bin/env python3
"""Final evidence/prefix/count integrity check; no producer imports or proof."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import time

H=Path(__file__).resolve().parent
R=H.parent.parent

def main():
    resource.setrlimit(resource.RLIMIT_AS,(512<<20,512<<20))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    t=time.perf_counter();checks=0
    def ck(x):
        nonlocal checks
        checks+=1
        assert x
    def read(name):return json.loads((H/name).read_text())
    idx=read('startup-index.json')
    for item in idx:
        original=Path(item['path'])
        snap=H/'startup'/str(original.relative_to(R.parent.parent)).replace('/','__')
        ck(hashlib.sha256(snap.read_bytes()).hexdigest()==item['sha256'])
        if original.name not in ['STATE.md','PROGRESS.md','FINDINGS.md','sources.jsonl']:
            ck(hashlib.sha256(original.read_bytes()).hexdigest()==item['sha256'])
    before=(H/'startup/research__zkp-efficiency__sources.jsonl').read_bytes()
    current=(R/'sources.jsonl').read_bytes();ck(current.startswith(before))
    ledger=[json.loads(x) for x in current.splitlines()];ck(len(ledger)==709)
    new=read('source-records.json');ck(ledger[702:]==new);ck(len(new)==7)
    for s in new:
        ck(s['access_date']=='2026-10-20');ck(s['run_id']=='20261020T221854Z-d390b45f')
        ck(s['reproduced_performance'] is False and s['external_execution'] is False)
    oldfind=(H/'startup/research__zkp-efficiency__FINDINGS.md').read_bytes()
    ck((R/'FINDINGS.md').read_bytes().startswith(oldfind))
    oldhyp=read('prior/hypotheses.json');hyp=read('hypotheses.json')
    ck(len(oldhyp)==26 and len(hyp)==28)
    # The previously queued dyadic item is deliberately refined; all other
    # hypothesis fields, including negative findings, must survive re-ranking.
    for o in oldhyp[:-1]:
        x=next(x for x in hyp if x['title']==o['title'])
        ck({k:v for k,v in o.items() if k!='rank'}=={k:v for k,v in x.items() if k!='rank'})
    probe=read('result.json');val=read('validation-result.json');cycle=read('cycle-result.json')
    ck(probe['status']==val['status']=='PASS')
    ck(probe['checks']==53680 and val['checks']==8128)
    for pin in read('source-pins.json'):
        ck(hashlib.sha256((H/pin['copy']).read_bytes()).hexdigest()==pin['sha256'])
        ck(hashlib.sha256(Path(pin['source']).read_bytes()).hexdigest()==pin['sha256'])
    for command in read('commands.json'):
        if 'source_sha256' in command:
            leaf=Path(command['command'][-1]).name
            ck(hashlib.sha256((H/leaf).read_bytes()).hexdigest()==command['source_sha256'])
    old=read('prior/result.json');summary=read('model-summary.json')
    rows={(x['context'],x['base_e_s']):x for x in probe['records']}
    for x in summary['summary']:
        T=x['context'];modes=x['modes']
        for mode,r in modes.items():
            words=body=peak=slots=0
            for es,caps in zip(summary['schedule'],r['caps']):
                candidate=rows[T,es]['arms']['single' if mode=='single' else 'min_words']
                direct=old['per_context'][str(T)]['0']
                if not caps:
                    ck(mode in ['direct','hybrid'])
                    words+=direct['totals']['committed'];body+=direct['wire']['total']
                    if mode=='hybrid':ck(direct['totals']['committed']<=candidate['totals']['committed'])
                else:
                    ck(caps==candidate['caps']);words+=candidate['totals']['committed']
                    body+=candidate['wire']['conditional_body_bytes'];peak=max(peak,candidate['dictionary_bytes'])
                    slots+=32*T*sum(caps)
            ck(words==r['committed_words']);ck(body==r['conditional_body_bytes'])
            ck(peak==r['selected_dictionary_peak_bytes'])
            ck(slots==r['DD_inversions']==r['DD_histogram_words'])
        ck(abs(x['sharded_vs_single_pct']-100*(modes['sharded']['committed_words']/modes['single']['committed_words']-1))<1e-12)
    rid='20261020T221854Z-d390b45f'
    for p in [R/'STATE.md',R/'PROGRESS.md',R/'progress'/f'{rid}.md',R/'handoffs/20261020-dyadic-dd-shards.md',H/'README.md']:
        text=p.read_text();ck(rid in text);ck('unmeasured' in text)
    f=cycle['new_verified_full_stack']
    ck(f['proofs']==f['passes']==f['positions']==0)
    for name in ['witness_s','proof_s','serialization_s','verification_s','startup_s','startup_fraction','steady_rate','total_rate']:
        ck(f[name] is None)
    ck((H/'initial-audit-duplicate-zero-control/audit.py.stderr').read_text().find('AssertionError')>=0)
    out=dict(status='PASS',checks=checks,source_ledger=709,original_source_records_preserved=702,
             prior_findings_prefix_preserved=True,prior_hypotheses_preserved=26,agenda_and_project_pins_unchanged=True,
             summary_independently_reaggregated=True,elapsed_s=time.perf_counter()-t,
             maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    (H/'artifact-audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps(out))

if __name__=='__main__':main()
