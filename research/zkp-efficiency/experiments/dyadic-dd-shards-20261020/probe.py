#!/usr/bin/env python3
"""Synthetic DD-union arithmetic and conditional R9-skeleton counts; no proof."""
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import random
import resource
import signal
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE/'vendor/r11'))
import r11_activation_cost as r11
# Load the prior adapter against our byte-identical local vendor modules.
spec = importlib.util.spec_from_file_location('prior_adapter', HERE/'prior/probe.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SEED = 20261020114
P = (1 << 64) - (1 << 32) + 1

def limits():
    resource.setrlimit(resource.RLIMIT_AS, (512 << 20, 512 << 20))
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})

def add(x,y): return ((x[0]+y[0])%P,(x[1]+y[1])%P)
def sub(x,y): return ((x[0]-y[0])%P,(x[1]-y[1])%P)
def mul(x,y): return ((x[0]*y[0]+7*x[1]*y[1])%P,(x[0]*y[1]+x[1]*y[0])%P)
def inv(x):
    if x == (0,0): raise ZeroDivisionError('invert every dictionary slot')
    d=pow((x[0]*x[0]-7*x[1]*x[1])%P,-1,P)
    return (x[0]*d%P,-x[1]*d%P)
def tuple_value(total,e,q,beta,tag):
    return add(add(tag,(total,0)),add(mul(beta,(e,0)),mul(mul(beta,beta),(q,0))))

def binary_caps(n, minimum):
    n=((n+minimum-1)//minimum)*minimum
    return [1<<i for i in range(n.bit_length()-1,-1,-1) if (n>>i)&1]

def best_caps(n, minimum, data_cost, per_shard_masks):
    """Exact public committed-word objective, not a runtime optimizer."""
    cap=1<<(n-1).bit_length()
    choices=[1<<i for i in range(minimum.bit_length()-1,cap.bit_length())]
    dp={0:[]}
    for total in range(minimum,cap+1,minimum):
        candidates=[dp[total-c]+[c] for c in choices if total>=c and total-c in dp]
        dp[total]=min(candidates,key=lambda cs:(len(cs),tuple(sorted(cs,reverse=True))))
    eligible=[cs for total,cs in dp.items() if total>=n]
    return sorted(min(eligible,key=lambda cs:(sum(cs)*data_cost+len(cs)*per_shard_masks,len(cs),sum(cs))),reverse=True)

def count(T,caps):
    lay=adapter.make_layout(T,256)
    t=dict(lay.totals()); oldsize=lay.size['Dd']; n=lay.n; rows=32*T
    ap,hp=lay.a_planes()['Dd'],lay.h_planes()['Dd']
    ac,hc=lay.claim_sites()[0]['DD'],lay.claim_sites()[1]['DD']
    minimum=max(1,n//rows)
    if not caps or any(c<minimum or c&(c-1) for c in caps): raise ValueError('no-lift/power-of-two')
    newsize=rows*sum(caps); k=len(caps)
    for key,delta in [('a_rows',ap*(newsize-oldsize)//n+2*ac*(k-1)),
                      ('h_rows',2*hp*(newsize-oldsize)//n+2*hc*(k-1)),
                      ('a_sites',ac*(k-1)),('h_sites',hc*(k-1)),
                      ('a_mask_words',2*ac*(k-1)*n),('h_mask_words',2*hc*(k-1)*n),
                      ('u8',lay.lookups()['Dd']*(newsize-oldsize))]: t[key]+=delta
    t['a_words']=t['a_rows']*n; t['h_words']=t['h_rows']*n
    t['committed']=t['a_words']+t['h_words']
    t['element_terms']+=2*(newsize-oldsize)*lay.slot_work()[-1][3]
    # One shared score tuple helper, one DD table helper/histogram per shard.
    w=adapter.wire_parts(lay); orig=w['slots_detail'][-1]
    slots=w['slots_detail'][:-1]
    for i,c in enumerate(caps):
        s=dict(orig);s.update(name='DD%d'%i,main=(rows*c).bit_length()-1)
        s['cfs_len']=(s['main']+s['ext'])*s['degree']+2;slots.append(s)
    slot_count=len(slots); mr=2*slot_count+4
    ag=w['a_groups']+2*(k-1); hg=w['h_groups']+k-1
    def opening(groups, nr):
        return (groups+1)*(n+256)*16+256*(8+nr*8+32+(lay.log_n+2)*32)
    body=16*sum(1+(s['main']+s['ext'])*(s['degree']+1)+s['terms'] for s in slots)
    body+=2*1024*16+256*(8+mr*8+32+12*32)
    body+=opening(ag,t['a_rows'])+opening(hg,t['h_rows'])
    cfs=sum(s['cfs_len'] for s in slots)
    return dict(context=T,caps=caps,minimum_cap=minimum,totals={x:t[x] for x in
        ['committed','a_words','h_words','a_rows','h_rows','a_sites','h_sites','a_mask_words','h_mask_words','u8','element_terms']},
        dictionary_words=(ap+2*hp)*newsize,dictionary_bytes=(ap+2*hp)*newsize*8,
        histogram_words=newsize,dd_inversions=newsize,query_inversions=32*T*T,
        per_shard=dict(a_planes=ap,h_pairs=hp,a_sites=ac,h_sites=hc,data_words_per_cap=(ap+2*hp)*rows,
                       fresh_mask_words=2*(ac+hc)*n),
        wire=dict(conditional_body_bytes=body,slots=slot_count,A_groups=ag,H_groups=hg,
                  mask_rows=mr,M_encoded_bytes=mr*4096*8,M_cfs_coeffs=cfs,
                  M_fresh_base_words=2*cfs+2*slot_count*256+4*1024,
                  M_a_coefs_bytes=2*slot_count*512*8),
        DD_slots=[dict(main=s['main'],ext=s['ext'],degree=s['degree'],terms=s['terms'],cfs=s['cfs_len']) for s in slots[23:]])

def shard_column(column,caps):
    if sum(caps)<len(column):raise ValueError('public support missing')
    flat=column+[0]*(sum(caps)-len(column)); out=[];offset=0
    for c in caps:out.append(flat[offset:offset+c]);offset+=c
    return out

def digest(cols,caps):
    return hashlib.sha256(json.dumps(dict(domain='research/DD-union/1',caps=caps,cols=cols,tag=141),sort_keys=True).encode()).hexdigest()

def run():
    limits();start=time.perf_counter();rng=random.Random(SEED);checks=0;controls=[]
    def ck(v):
        nonlocal checks
        checks+=1
        assert v
    def nc(name,v):ck(v);controls.append(name)
    records=[];tables={};cases=0;positions=0
    for es in range(5):
        table=adapter.exp_table(es);col=sorted(set(table)|{0});cap=1<<(len(col)-1).bit_length()
        tables[es]=dict(n_col=len(col),column=col,table_sha256=hashlib.sha256(json.dumps(table).encode()).hexdigest())
        for T in (128,512):
            base=count(T,[cap]);d=base['per_shard'];minimum=base['minimum_cap']
            binary=binary_caps(len(col),minimum)
            best=best_caps(len(col),minimum,d['data_words_per_cap'],d['fresh_mask_words'])
            arms={name:count(T,cs) for name,cs in [('single',[cap]),('dyadic',binary),('min_words',best)]}
            direct=adapter.make_layout(T,0).totals()['committed']
            for name,r in arms.items():
                r['vs_single_pct']=100*(r['totals']['committed']/base['totals']['committed']-1)
                r['vs_direct_pct']=100*(r['totals']['committed']/direct-1)
                ck(r['totals']['committed']<=base['totals']['committed'] or name=='dyadic')
                ck(sum(r['caps'])>=len(col));ck(all(x<=512 for x in [s['cfs']+256 for s in r['DD_slots']]))
            ck(arms['min_words']['totals']['committed']<=arms['dyadic']['totals']['committed'])
            ck(base['totals']['committed']==adapter.record(T,cap)['totals']['committed'])
            ck(base['wire']['conditional_body_bytes']==adapter.record(T,cap)['wire']['total'])
            records.append(dict(base_e_s=es,n_col=len(col),context=T,direct_words=direct,arms=arms))
            cols=shard_column(col,best);flat=sum(cols,[]);first={e:flat.index(e) for e in set(flat)}
            for trial in range(6):
                # All synthetic; max entry ensures valid denominator and q window.
                row=[512]+[0 if j>trial*T//6 else table[rng.randrange(4096)] for j in range(1,T)]
                total=sum(row);cells=[];hist=[0]*len(flat)
                for e in row:hist[first[e]]+=1
                for e,m in zip(flat,hist):
                    q,rem=divmod(e*4096,total);sg=total-rem-1
                    ck(q*total+rem==e*4096);ck(rem+sg+1==total)
                    ck(0<=q<=4096 and 0<=rem<total and 0<=sg<total)
                    cells.append((e,q,rem,sg,m))
                ck(sum(hist)==T)
                for e in row:
                    q,rem=divmod(e<<12,total);ck(cells[first[e]][1:3]==(q,rem));positions+=1
                # One union lookup; no per-shard query routing or public private histogram.
                beta=(rng.randrange(1,P),rng.randrange(1,P));tag=(rng.randrange(P),rng.randrange(P));alpha=(rng.randrange(P),rng.randrange(1,P))
                query=(0,0);table_sum=(0,0)
                for e in row:query=add(query,inv(sub(alpha,tuple_value(total,e,(e<<12)//total,beta,tag))))
                for e,q,rem,sg,m in cells:
                    term=inv(sub(alpha,tuple_value(total,e,q,beta,tag))) # includes every m=0 slot
                    table_sum=add(table_sum,mul(term,(m,0)))
                ck(query==table_sum);cases+=1
                # Moving a committed histogram count changes the table sum.
                i=first[512];j=first[0]
                moved=sub(add(table_sum,inv(sub(alpha,tuple_value(total,0,0,beta,tag)))),
                          inv(sub(alpha,tuple_value(total,512,(512<<12)//total,beta,tag))))
                ck(moved!=query)
    nc('es2_four_shards_cost_more_than_two',records[4]['arms']['dyadic']['totals']['committed']>records[4]['arms']['min_words']['totals']['committed'])
    nc('small_shard_lift_refused_T128',binary_caps(55,1)[-1]<4)
    nc('small_shard_lift_refused_T512',binary_caps(55,1)[-1]<2)
    for T in (128,512):
        rejected=False
        try:count(T,binary_caps(55,1))
        except ValueError:rejected=True
        nc('count_api_refuses_lift_T%d'%T,rejected)
    rejected=False
    try:shard_column(tables[2]['column'],[128,16,8])
    except ValueError:rejected=True
    nc('missing_public_support_refused',rejected)
    # A forged quotient taken from another row is accepted by a keyless union.
    beta=(13,19);tag=(141,0)
    nc('row_Sum_key_required',tuple_value(512,512,2048,beta,tag)!=tuple_value(1024,512,2048,beta,tag))
    def keyless(cell):
        S,e,q=cell
        return tuple_value(0,e,q,beta,tag)
    forged_query=(512,512,2048);foreign_dictionary=(1024,512,2048)
    nc('dropping_key_accepts_foreign_quotient',keyless(forged_query)==keyless(foreign_dictionary)
       and forged_query[2]!=(forged_query[1]<<12)//forged_query[0])
    def division(cell):
        S,e,q,rem,sg,m=cell
        return e*4096==q*S+rem and rem+sg+1==S and 0<=rem<S and 0<=sg<S
    nc('unused_slot_still_constrained',not division((512,0,1,0,511,0)))
    refused=False
    try: inv((0,0))
    except ZeroDivisionError:refused=True
    nc('zero_denominator_even_zero_multiplicity',refused)
    cols=shard_column(tables[2]['column'],[128,32]);h=digest(cols,[128,32]);changed=[x[:] for x in cols];changed[0][0]=1
    nc('column_swap_changes_schedule',h!=digest(changed,[128,32]))
    nc('cap_order_changes_schedule',h!=digest(cols,[32,128]))
    for T in (128,512):
        x=count(T,[128,32]); y=count(T,[256]);n=(1<<14) if T==128 else (1<<15)
        nc('fresh_masks_not_shared_T%d'%T,x['totals']['a_mask_words']+x['totals']['h_mask_words']==y['totals']['a_mask_words']+y['totals']['h_mask_words']+x['per_shard']['fresh_mask_words'])
        nc('groups_not_free_T%d'%T,x['wire']['A_groups']+x['wire']['H_groups']==y['wire']['A_groups']+y['wire']['H_groups']+3)
    out=dict(status='PASS',seed=SEED,checks=checks,synthetic_rows=cases,synthetic_query_positions=positions,
        negative_controls=controls,tables=tables,records=records,elapsed_s=time.perf_counter()-start,
        maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        scope='Synthetic union arithmetic and conditional fixed R9-skeleton counts only; no native proof/profile/privacy validation',
        limits=dict(threads=1,CPU_s=59,alarm_s=59,parent_wall_s=60,address_space_MiB=512,estimated_MiB=64))
    (HERE/'result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:out[k] for k in ['status','checks','synthetic_rows','synthetic_query_positions','negative_controls','elapsed_s','maxrss_KiB']}))

if __name__=='__main__':run()
