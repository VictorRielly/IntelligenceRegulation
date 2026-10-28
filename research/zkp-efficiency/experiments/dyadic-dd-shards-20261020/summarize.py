#!/usr/bin/env python3
"""Reaggregate public schedule sensitivity from checked per-layer counts."""
import json
import os
from pathlib import Path
import platform
import resource
import signal

H=Path(__file__).resolve().parent

def main():
    resource.setrlimit(resource.RLIMIT_AS,(512<<20,512<<20))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    r=json.loads((H/'result.json').read_text())
    old=json.loads((H/'prior/result.json').read_text())
    rows={(x['context'],x['base_e_s']):x for x in r['records']}
    schedule=old['existing_public_fixture']['e_s'];summary=[]
    for T in (128,512):
        modes={}
        for mode in ['direct','single','sharded','hybrid']:
            words=body=hist=inversions=peak=0;caps=[]
            for es in schedule:
                x=rows[T,es]['arms']['single' if mode=='single' else 'min_words']
                d=old['per_context'][str(T)]['0']
                direct=mode=='direct' or (mode=='hybrid' and d['totals']['committed']<x['totals']['committed'])
                if direct:
                    words+=d['totals']['committed'];body+=d['wire']['total'];caps.append([])
                else:
                    words+=x['totals']['committed'];body+=x['wire']['conditional_body_bytes']
                    peak=max(peak,x['dictionary_bytes']);caps.append(x['caps'])
                    hist+=x['histogram_words'];inversions+=x['dd_inversions']
            modes[mode]=dict(committed_words=words,conditional_body_bytes=body,
                             selected_dictionary_peak_bytes=peak,caps=caps,
                             DD_histogram_words=hist,DD_inversions=inversions)
        for x in modes.values():x['pct_vs_direct']=100*(x['committed_words']/modes['direct']['committed_words']-1)
        summary.append(dict(context=T,label='Existing b7 exponents only as HIGH/S12 sensitivity; not actual HIGH calibration',
                            modes=modes,sharded_vs_single_pct=100*(modes['sharded']['committed_words']/modes['single']['committed_words']-1)))
    cpu=next(s.split(':',1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines() if s.startswith('model name'))
    out=dict(schedule=schedule,layers=32,heads=32,head_dim=128,summary=summary,
             device=dict(research_cpu=cpu,platform=platform.platform(),gpu_used=False),
             scope='Counts and projections; no model pass or proof')
    dest=H/'model-summary.json'
    if dest.exists():assert out==json.loads(dest.read_text()),'new producer summary differs from checked inline original'
    dest.write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps(dict(status='PASS',same_as_checked_original=True,contexts=[128,512],model_passes=0)))

if __name__=='__main__':main()
