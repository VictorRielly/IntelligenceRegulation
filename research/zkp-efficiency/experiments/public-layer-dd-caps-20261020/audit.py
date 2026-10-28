#!/usr/bin/env python3
"""Independent Decimal/table and affine graph/wire audit; does not import probe."""
import decimal
import hashlib
import json
import os
from pathlib import Path
import random
import resource
import signal
import struct
import time

HERE=Path(__file__).resolve().parent

def run():
    resource.setrlimit(resource.RLIMIT_AS,(512<<20,512<<20))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    start=time.perf_counter();checks=0
    def check(ok,detail=None):
        nonlocal checks
        checks+=1
        assert ok,detail
    out=json.loads((HERE/'result.json').read_text())
    decimal.getcontext().prec=90
    D=decimal.Decimal
    entries=0;tables={}
    for e in range(5):
        step=(-(D(2)**(e-4))/D(128).sqrt()).exp();v=D(512);values=[]
        for _ in range(4096):
            values.append(int(v.to_integral_value(rounding=decimal.ROUND_HALF_UP)));v*=step;entries+=1
        n=len(set(values)|{0});cap=1
        while cap<n:cap*=2
        t=out['tables'][str(e)]
        check(n==t['n_col']);check(cap==t['cap'])
        check(hashlib.sha256(struct.pack('<4096q',*values)).hexdigest()==t['sha256'])
        tables[e]=dict(cap=cap,values=values)
    # Source pins and literal skeleton checks: all source/copy bytes identical.
    pins=json.loads((HERE/'source-pins.json').read_text())
    for src,rec in pins.items():
        check(hashlib.sha256(Path(src).read_bytes()).hexdigest()==rec['sha256'],src)
        check(hashlib.sha256((HERE/rec['copy']).read_bytes()).hexdigest()==rec['sha256'])
    shape=(HERE/'source/hashline/src/private_block/shape.rs').read_text()
    zk=(HERE/'source/hashline/src/zk.rs').read_text()
    sc=(HERE/'source/zkp-core/src/sumcheck.rs').read_text()
    for literal in ['(groups + 1) * vc * 16','COL_CHECKS * (8 + rows * 8 + 32 + pth * 32)',
                    '2 * self.n_slots() + 4','if self.dd_cap > 0 { 2 } else { 0 }',
                    '9 + usize::from(self.dd_cap > 0)']:
        # h_groups source writes 8 + 1 rather than 9.
        check(literal in shape or (literal=='9 + usize::from(self.dd_cap > 0)' and '8 + 1 + usize::from(self.dd_cap > 0)' in shape))
    for literal in ['let n_base = 2 * masks.len() + 4','let pads = rng.fp_vec(MASK_Q)','let mut encoded = vec![Fp::ZERO; n_base * dom]']:
        check(literal in zk)
    check('n_vars * degree + 2' in sc)
    # Independent component graph: DD removes lp+2ls S A planes, shrinks S H
    # pairs, adds dictionary A/H planes and +3 A/+3 H claim sites.
    independent={}
    for Ts,rs in out['per_context'].items():
        T=int(Ts);N=16384 if T==128 else 32768;S=32*T*T
        lp=2;ls=2 if T==128 else 3;v=lp+1+2*(ls+1)
        # HIGH has seven non-division byte lookups on S, independently read
        # from its score/remainder word windows (old 4 plus 3).
        hs0=(7+v+1)//2+1;hs1=(7+1)//2+2
        hdiff=hs1-hs0;ap=2+lp+2*ls;hp=(v+1)//2+1
        base=rs['0']; independent[T]={0:base}
        for cs,r in rs.items():
            cap=int(cs)
            for sl in r['wire']['slots_detail']:
                check(sl['cfs_len']+256<=512,(T,cap,'M row budget',sl['name']))
            if not cap:continue
            dd=32*T*cap
            da=-(lp+2*ls)*S+ap*dd+6*N
            dh=2*hdiff*S+2*hp*dd+6*N
            dlookup=v*(dd-S)
            dterms=2*S*(-lp-2*ls+hdiff)+2*dd*(ap+hp+3)
            # DD degree4, main log2(dd), one extension. Other changes only
            # modify SZC terminal count: A -lp-2ls, H hdiff.
            lg=dd.bit_length()-1;dd_sites=ap+1+hp
            slot_delta=16*(1+5*(lg+1)+dd_sites-(lp+2*ls)+hdiff)
            # +2 A groups,+1 H group,256 columns,2 extra masking rows.
            pcs_delta=3*(N+256)*16+((da+dh)//N)*256*8
            mask_delta=2*256*8
            wire_delta=slot_delta+pcs_delta+mask_delta
            t=r['totals'];b=base['totals']
            for k,d in [('a_words',da),('h_words',dh),('committed',da+dh),('u8',dlookup),('element_terms',dterms),('a_sites',3),('h_sites',3),('a_mask_words',6*N),('h_mask_words',6*N)]:
                check(t[k]-b[k]==d,(T,cap,k,t[k]-b[k],d))
            check(r['wire']['total']-base['wire']['total']==wire_delta,(T,cap,'wire'))
            check(r['wire']['parts']['slots']-base['wire']['parts']['slots']==slot_delta)
            check(r['wire']['parts']['mask_opening']-base['wire']['parts']['mask_opening']==mask_delta)
            check(r['wire']['M_fresh_base_words']-base['wire']['M_fresh_base_words']==2*(4*(lg+1)+2)+512)
            check(r['wire']['M_encoded_bytes']-base['wire']['M_encoded_bytes']==65536)
            check(r['wire']['M_a_coefs_bytes']-base['wire']['M_a_coefs_bytes']==8192)
            independent[T][cap]=r
    # Enumerate schedule nodes without using the producer aggregation.
    stage_checks=0
    for sched in out['schedules']:
        T=sched['context'];es=out['existing_public_fixture']['e_s'] if sched['name']=='existing_b7_sensitivity' else {
            'balanced_synthetic':[2,3,4,4]*8,'broad_synthetic':[0,1,2,3,4,4,3,2]*4,'uniform_synthetic':[2]*32}[sched['name']]
        caps=[tables[e]['cap'] for e in es]
        choices={'direct':[0]*32,'uniform':[max(caps)]*32,'layer':caps,
                 'hybrid':[c if independent[T][c]['totals']['committed']<independent[T][0]['totals']['committed'] else 0 for c in caps]}
        for mode,cs in choices.items():
            arm=sched['arms'][mode];check(cs==arm['caps'])
            rows=[independent[T][c] for c in cs]
            for k,v in arm['totals'].items():check(sum(r['totals'][k] for r in rows)==v)
            for k,v in arm['wire'].items():check(sum(r['wire'][k] for r in rows)==v)
            # Stage interval sweep: dictionary A and H live concurrently;
            # no layer overlap. Separate capacities retain role maxima.
            events=[]
            for i,r in enumerate(rows):
                a,h=r['dictionary_A_bytes'],r['dictionary_H_bytes']
                events.extend([(4*i,a),(4*i+1,h),(4*i+2,-a),(4*i+3,-h)])
            live=peak=0
            for _,delta in sorted(events):live+=delta;peak=max(peak,live);check(live>=0);stage_checks+=1
            check(live==0);life=arm['lifetime'];check(peak==life['exact_stream_peak'])
            check(sum(r['dictionary_A_bytes']+r['dictionary_H_bytes'] for r in rows)==life['retained_all_layers'])
            peakpool=max(r['dictionary_A_bytes'] for r in rows)+max(r['dictionary_H_bytes'] for r in rows)
            check(life['role_pool_peak']==peakpool)
            # Resident passes repeat fresh work. Setup amortization cannot
            # divide per-proof mask/PCS rows by the number of passes.
            for passes in (1,2,4,8):
                check(passes*arm['totals']['a_mask_words']==sum(sum(r['totals']['a_mask_words'] for r in rows) for _ in range(passes)))
                check(passes*arm['wire']['M_fresh_base_words']==sum(sum(r['wire']['M_fresh_base_words'] for r in rows) for _ in range(passes)))
    # Independent synthetic direct sums versus repeated dictionary quotients.
    rng=random.Random(20261020113^0xA0D17);arith=0
    for es in range(5):
        vals=tables[es]['values']
        for length in (32,128,512):
            xs=[512]+[0 if j%5==0 else vals[rng.randrange(4096)] for j in range(1,length)]
            n=sum(xs); byvalue={v:divmod(v*4096,n) for v in set(vals)|{0}}
            for v in xs:check(byvalue[v][0]*n+byvalue[v][1]==v*4096);arith+=1
    # Mutation checks for omissions that could make the numbers look better.
    controls=[]
    def bad(name,condition):check(condition,name);controls.append(name)
    for T,rs in independent.items():
        b,r=rs[0],rs[256]
        true=r['wire']['total']-b['wire']['total']
        rowonly=(r['totals']['committed']-b['totals']['committed'])//(16384 if T==128 else 32768)*2048
        bad('rows_only_wire_T%d'%T,rowonly!=true)
        bad('reused_AH_mask_rows_T%d'%T,r['totals']['a_mask_words']+r['totals']['h_mask_words']-b['totals']['a_mask_words']-b['totals']['h_mask_words']>0)
        bad('ignored_M_encoded_rows_T%d'%T,r['wire']['M_encoded_bytes']>b['wire']['M_encoded_bytes'])
    last=out['schedules'][1]['arms']['layer']['lifetime']
    bad('capacity_not_mean',last['exact_stream_peak']>last['cumulative_requested']/32)
    # Uniform e_s produces no per-layer cap benefit.
    for s in out['schedules']:
        if s['name']=='uniform_synthetic':bad('uniform_no_improvement_T%d'%s['context'],s['arms']['uniform']['totals']==s['arms']['layer']['totals'])
    result=dict(status='PASS',checks=checks,Decimal_precision=90,enumerated_public_entries=entries,
                independent_arithmetic_positions=arith,allocation_events=stage_checks,source_pins=len(pins),
                negative_controls=controls,elapsed_s=time.perf_counter()-start,
                maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                scope='Independent count/wire/synthetic allocation audit; no native proof/privacy validation')
    (HERE/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

if __name__=='__main__':run()
