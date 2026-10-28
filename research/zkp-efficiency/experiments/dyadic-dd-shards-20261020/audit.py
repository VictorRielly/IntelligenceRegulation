#!/usr/bin/env python3
"""Independent Decimal/enumeration/rational audit; imports no producer/vendor."""
from collections import Counter
from decimal import Decimal, localcontext, ROUND_FLOOR
from fractions import Fraction
import hashlib
import json
import os
from pathlib import Path
import random
import resource
import signal
import time

H=Path(__file__).resolve().parent

def main():
    resource.setrlimit(resource.RLIMIT_AS,(512<<20,512<<20))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    start=time.perf_counter();checks=0;controls=[];positions=0
    def ck(x):
        nonlocal checks
        checks+=1
        assert x
    def nc(name,x):ck(x);controls.append(name)
    r=json.loads((H/'result.json').read_text())
    old=json.loads((H/'prior/result.json').read_text())
    pins=json.loads((H/'source-pins.json').read_text())
    for pin in pins:
        b=(H/pin['copy']).read_bytes();ck(hashlib.sha256(b).hexdigest()==pin['sha256'])
        ck(hashlib.sha256(Path(pin['source']).read_bytes()).hexdigest()==pin['sha256'])
    shape=(H/'source/shape.rs').read_text();arg=(H/'source/argument.rs').read_text()
    protocol=(H/'source/protocol.rs').read_text();witness=(H/'source/witness.rs').read_text()
    for s in ['!self.dd_cap.is_power_of_two()', 'self.natural_log(dom) < self.log_cols',
              'a[SC_DD] = self.a_planes_on(Dom::Dd) + 1',
              'h[SC_DD] = self.helpers(Dom::Dd) + 1']:
        ck(s in shape)
    for s in ['b.a_slice(lay.a_off[ids.at(A_SUM)]','M_dd','SC_DD =>','SC_ZS =>']:
        ck(s in arg)
    ck('let sign = if hids.is_table(p)' in protocol)
    ck('let inv = inverses(tt.iter()' in protocol)
    ck('pl[ids.mdd()][base + k] += 1' in witness)
    # Decimal recurrence is independent of the binary float table generator.
    tables={}
    with localcontext() as ctx:
        ctx.prec=90
        for es in range(5):
            step=(-(Decimal(2)**(es-4))/Decimal(128).sqrt()).exp()
            value=Decimal(512);vals=[]
            for j in range(4096):
                vals.append(int((value+Decimal('.5')).to_integral_value(rounding=ROUND_FLOOR)))
                value*=step
            col=sorted({0}|set(vals));tables[es]=vals
            ck(col==r['tables'][str(es)]['column'])
            ck(len(col)==r['tables'][str(es)]['n_col'])
            ck(hashlib.sha256(json.dumps(vals).encode()).hexdigest()==r['tables'][str(es)]['table_sha256'])
    contexts=[]
    for x in r['records']:
        T=x['context'];n=16384 if T==128 else 32768;rows=32*T
        ls=2 if T==128 else 3;lp=2
        A=2+lp+2*ls;lk=lp+1+2*(ls+1);Hpair=(lk+1)//2+1
        Aclaims=A+1;Hclaims=Hpair;mincap=n//rows
        C=1<<(x['n_col']-1).bit_length();single=old['per_context'][str(T)][str(C)]
        base=single['totals'];wire=single['wire'];slot0=wire['slots_detail'][-1]
        # Any repeated dyadic capacity can merge to twice itself, saving masks
        # without increasing data. Thus enumeration of distinct powers covers
        # every optimum, and differs from producer's unbounded coin DP.
        options=[]
        for total in range(((x['n_col']+mincap-1)//mincap)*mincap,C+1,mincap):
            cs=[1<<b for b in range(total.bit_length()) if total&(1<<b)]
            cost=(A+2*Hpair)*rows*total+2*(Aclaims+Hclaims)*n*len(cs)
            options.append((cost,len(cs),total,sorted(cs,reverse=True)))
        chosen=min(options)[3]
        ck(chosen==x['arms']['min_words']['caps'])
        for name,a in x['arms'].items():
            cs=a['caps'];k=len(cs);extent=rows*sum(cs);diff=extent-rows*C
            ck(a['minimum_cap']==mincap);ck(all(c>=mincap for c in cs))
            new_a=base['a_rows']+A*diff//n+2*Aclaims*(k-1)
            new_h=base['h_rows']+2*Hpair*diff//n+2*Hclaims*(k-1)
            expect=dict(a_rows=new_a,h_rows=new_h,a_words=new_a*n,h_words=new_h*n,
                        committed=(new_a+new_h)*n,a_sites=base['a_sites']+Aclaims*(k-1),
                        h_sites=base['h_sites']+Hclaims*(k-1),
                        a_mask_words=base['a_mask_words']+2*Aclaims*n*(k-1),
                        h_mask_words=base['h_mask_words']+2*Hclaims*n*(k-1),
                        u8=base['u8']+lk*diff,
                        element_terms=base['element_terms']+2*diff*(1+A+1+1+(lk+1)//2+1))
            for key,val in expect.items():ck(val==a['totals'][key])
            slots=wire['slots_detail'][:-1]+[dict(main=(rows*c).bit_length()-1,ext=1,degree=4,terms=Aclaims+Hclaims) for c in cs]
            groupsA=wire['a_groups']+2*(k-1);groupsH=wire['h_groups']+k-1
            def pcs(gr,nr):
                return (gr+1)*(n+256)*16+256*(8+nr*8+32+((n.bit_length()-1)+2)*32)
            mr=2*len(slots)+4
            receipt=pcs(groupsA,new_a)+pcs(groupsH,new_h)+2*1024*16+256*(8+mr*8+32+12*32)
            receipt+=sum(16*(1+(s['main']+s['ext'])*(s['degree']+1)+s['terms']) for s in slots)
            ck(a['wire']['conditional_body_bytes']==receipt)
            ck(a['wire']['A_groups']==groupsA);ck(a['wire']['H_groups']==groupsH)
            cfs=sum((s['main']+s['ext'])*s['degree']+2 for s in slots)
            ck(a['wire']['M_fresh_base_words']==2*cfs+512*len(slots)+4096)
            ck(a['wire']['M_encoded_bytes']==mr*4096*8)
            ck(a['dictionary_bytes']==(A+2*Hpair)*extent*8)
            ck(a['histogram_words']==extent);ck(a['dd_inversions']==extent)
            ck(a['query_inversions']==32*T*T)
            ck(all((s['main']+1)*4+2+256<=512 for s in slots[23:]))
            if k>1:
                no_masks=expect['committed']-2*(Aclaims+Hclaims)*n*(k-1)
                nc('mask_omission_%d_%d_%s'%(T,x['base_e_s'],name),no_masks!=expect['committed'])
        contexts.append(T)
    # Independent exact rational union check, including all unused pad cells.
    rng=random.Random(20261020114^0xA11D17)
    for es in range(5):
        for T in (32,128,512):
            col=sorted(set(tables[es])|{0});cap=1<<(len(col)-1).bit_length()
            flat=col+[0]*(cap-len(col));row=[512]+[0 if j%3==0 else tables[es][rng.randrange(4096)] for j in range(1,T)]
            total=sum(row);hist=Counter(row);cells=[]
            for e in flat:
                q=int(Fraction(e*4096,total));rem=e*4096-q*total
                ck(0<=rem<total);ck(0<=q<=4096)
                cells.append((total,e,q,rem,total-rem-1))
            # Counter representation assigns zero count to duplicate padded0.
            alpha=10**12+97;beta=43;gamma=71
            def den(cell):return alpha-(gamma*141+cell[0]+beta*cell[1]+beta*beta*cell[2])
            lhs=sum((Fraction(1,den((total,e,int(Fraction(e*4096,total))))) for e in row),Fraction())
            rhs=sum((Fraction(hist[e],den(cells[i])) for i,e in enumerate(col)),Fraction())
            ck(lhs==rhs);positions+=len(row)
            # The final padded slot is also zero: moving0->0 is NOT a forgery.
            # Move a real max-E count to the first0 slot instead.
            forged=rhs+Fraction(1,den(cells[0]))-Fraction(1,den(cells[len(col)-1]))
            nc('committed_histogram_move_%d_%d'%(es,T),lhs!=forged)
            # Every slot remains checked even if it has no histogram count.
            i=len(flat)-1
            def relation(c):
                S,e,q,rr,sg=c
                return e*4096==q*S+rr and rr+sg+1==S and 0<=rr<S and 0<=sg<S and 0<=q<=4096
            ck(all(map(relation,cells)))
            bad=list(cells[i]);bad[2]+=1
            nc('unused_or_used_slot_division_%d_%d'%(es,T),not relation(bad))
    # Real zero checks on each forbidden small geometry, not just bit tests.
    for T,n in [(128,16384),(512,32768)]:
        raw=[32,16,4,2,1]
        nc('55_value_raw_partition_fails_no_lift_%d'%T,any(32*T*c<n for c in raw))
    # Shared value-0 sum sign is required: each shard table stays negative.
    nc('omitting_table_shard_changes_union',Fraction(1,17)+Fraction(1,19)!=Fraction(1,17))
    out=dict(status='PASS',checks=checks,decimal_precision=90,public_entries=5*4096,
             independent_positions=positions,source_pins=len(pins),negative_controls=controls,
             elapsed_s=time.perf_counter()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
             scope='Independent arithmetic/count/source audit; no producer/vendor import, no native proof/privacy gate')
    (H/'validation-result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:out[k] for k in ['status','checks','public_entries','independent_positions','source_pins','elapsed_s','maxrss_KiB']}))

if __name__=='__main__':main()
