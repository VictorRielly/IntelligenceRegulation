#!/usr/bin/env python3
"""Research-only larger public cap counts against copied owner R10/R11 oracle."""
import importlib.util
import json
import os
from pathlib import Path
import resource
import signal
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=Path('/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017')
sys.path.insert(0,str(HERE/'vendor/r11'))
import r11_activation_cost as r11
r10=r11.r10

def layout(geo, cap, fp, fe, s12):
    r10.DD_CAP=cap
    r10.F_P=fp
    old=dict(r10.GEOMS[geo])
    try:
        r10.GEOMS[geo]['f_e']=fe
        lay,_=r11.build(geo,cap>0,dict(ds=4 if s12 else 0,dF=fp-9))
        return lay
    finally:
        r10.GEOMS[geo].update(old)

def run():
    resource.setrlimit(resource.RLIMIT_AS,(512<<20,512<<20))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    start=time.perf_counter()
    r10.ROOT=str(ROOT)
    r10.DD_CAP=32; r10.F_P=9
    anchors=r10.anchor()  # read-only, no main() and no production output writes
    probe=json.loads((HERE/'result.json').read_text())
    baseline={}
    checks=0
    for geo in r10.GEOMS:
        baseline[geo]={}
        for cap in (0,32):
            lay=layout(geo,cap,9,9,False)
            baseline[geo][str(cap)]=lay.totals()
    # R9 geometry anchor, independent r9 counts previously matched native Rust.
    expected=json.loads((HERE/'source/r9__r9_counts.json').read_text())
    for geo in r10.GEOMS:
        key=next(k for k in expected if k.startswith(geo))
        for cap, mode in ((0,'today'),(32,'dd')):
            t=baseline[geo][str(cap)]; ref=expected[key][mode]
            for k,rk in [('a_rows','a_rows'),('h_rows','h_rows'),('committed','elems'),('u8','u8'),('review_terms','eterms')]:
                assert t[k]==ref[rk],(geo,cap,k,t[k],ref[rk]); checks+=1
    rows=[]
    for c in probe['cases']:
        if c['bits']!=12: continue
        for geo,g in r10.GEOMS.items():
            if c['head_dim']!=g['hd']:continue
            for fp in (9,12,15,16):
                no=layout(geo,0,fp,c['f_e'],True)
                yes=layout(geo,c['cap_pow2'],fp,c['f_e'],True)
                n,d=no.totals(),yes.totals()
                # DD adds, relative to direct S: one tuple H pair per score,
                # moves lp+2ls A planes, and adds Dd quotient/multiplicity.
                S=no.size['S']; Dd=yes.size['Dd']; N=no.n
                lp,ls=yes.lp,yes.ls
                hp=(lp+1+2*(ls+1)+1)//2
                add_sites=4  # net A sites +3, H sites +1 at every cap
                delta_data=S*(2-lp-2*ls)+Dd*(2+lp+2*ls+2*(hp+1))
                # claim-site masks are per row; two per A and H claim site
                predicted=delta_data+2*add_sites*N
                assert d['committed']-n['committed']==predicted;checks+=1
                lookup_delta=(Dd-S)*(lp+1+2*(ls+1))
                assert d['u8']-n['u8']==lookup_delta;checks+=1
                assert d['a_sites']+d['h_sites']-n['a_sites']-n['h_sites']==add_sites;checks+=1
                rows.append(dict(geometry=geo,context=g['T'],head_dim=c['head_dim'],
                                 base_e_s=c['base_e_s'],actual_e_s=c['actual_e_s'],
                                 f_e=c['f_e'],F_P=fp,n_col=c['n_col'],
                                 proposed_cap=c['cap_pow2'],cap32_supported=c['n_col']<=32,
                                 lp=lp,ls=ls,S_positions=S,Dd_positions=Dd,
                                 direct_committed=n['committed'],DD_committed=d['committed'],
                                 committed_delta=d['committed']-n['committed'],
                                 committed_pct=100*(d['committed']/n['committed']-1),
                                 direct_u8=n['u8'],DD_u8=d['u8'],
                                 direct_element_terms=n['element_terms'],DD_element_terms=d['element_terms'],
                                 direct_review_terms=n['review_terms'],DD_review_terms=d['review_terms'],
                                 dictionary_A_planes=2+lp+2*ls,
                                 dictionary_H_pairs=hp+1,
                                 dictionary_lookup_sites=lp+1+2*(ls+1),
                                 extra_claim_sites=add_sites,
                                 extra_mask_words=2*add_sites*N,
                                 unmasked_dictionary_A_payload_bytes=(2+lp+2*ls)*Dd*8,
                                 H_data_payload_bytes=2*(hp+1)*Dd*8,
                                 scope='Counted hypothetical S12 profile, no native registration/proof/time'))
    # F_P-only 9->12/15 keeps both limb counts and dictionary/table cardinality.
    fp_controls=[]
    for geo in r10.GEOMS:
        for cap in (0,32):
            a=layout(geo,cap,9,9,False).totals()
            for fp in (12,15):
                b=layout(geo,cap,fp,9,False).totals()
                assert a==b; checks+=1
            b=layout(geo,cap,16,9,False).totals()
            assert b['committed']>a['committed'];checks+=1
            fp_controls.append(dict(geometry=geo,cap=cap,F_P_9_12_15_counts_equal=True,
                                    F_P16_committed_delta=b['committed']-a['committed']))
    out=dict(status='PASS',checks=checks,owner_phase_anchor_runs=len(anchors),
             baseline=baseline,rows=rows,F_P_controls=fp_controls,
             elapsed_s=time.perf_counter()-start,
             maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             scope='Exact layout counts on owner replica plus independent affine delta identities; no runtime model')
    (HERE/'cost-result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k not in ('baseline','rows','F_P_controls')}))

if __name__=='__main__':run()
