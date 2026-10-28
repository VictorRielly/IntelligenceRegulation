"""Partial source-call accounting; no GPU throughput or physical traffic model."""
from pathlib import Path
from collections import Counter
import json,math,os,resource,time
from affine import Ops,primitive_costs,Z
H=Path(__file__).resolve().parent
KEYS=['base_mul','base_add','base_sub']

def vec(x,n=1):return {k:x.get(k,0)*n for k in KEYS}
def plus(*xs):return {k:sum(x.get(k,0) for x in xs) for k in KEYS}
def minus(a,b):return {k:a.get(k,0)-b.get(k,0) for k in KEYS}
def params(k):
    return dict(kh=512,mu=[(2,3),(5,7),(11,13)],mupad=(17,19) if k else Z,pad=[(j+23,j+29) if j<k else Z for j in range(11)])

def fixed_pair(k,supp,mode):
    # Independent hand derivation from the pinned CUDA call graph.
    if mode=='literal':
        gl=dict(base_mul=34,base_add=72,base_sub=48)
        pl=dict(base_mul=6*(k+1),base_add=18*k+12,base_sub=6*k+8)
        reads=384+48*k*supp
    else:
        gl=dict(base_mul=34,base_add=50,base_sub=46)
        pl=dict(base_mul=6*k,base_add=16*k,base_sub=6*k)
        reads=256+32*k*supp
    return plus(gl,pl if supp else {}),reads

def events(n,tail,supp,k,variant):
    L=1<<n;d=1+supp;p=params(k);out=[]
    literal,lr,_=primitive_costs(p,supp,'literal')
    paired,pr,prep=primitive_costs(p,supp,'paired')
    gl,gr,_=primitive_costs(p,False,'literal')
    # PL-only paired cost, separated from GL.
    pl=minus(paired,primitive_costs(p,False,'paired')[0]);plr=pr-256
    def emit(kind,count,cost=None,read=0,write=0,shared=0,barriers=0,where='device'):
        out.append(dict(kind=kind,count=count,primitives=vec(cost or {},count),global_read_bytes=read*count,global_write_bytes=write*count,logical_shared_read_bytes=shared*count,extra_chunk_barriers=barriers*count,where=where))
    if variant in ['raw_pair','implicit_pair','implicit_pl']:
        emit('prepare_coefficients',1,prep,where='host')
    m=L;rno=0
    while True:
        pairs=m//2
        if rno==0:
            if variant in ['baseline','implicit_literal','boundary_skip']:
                emit('derive_round0_literal',pairs,literal,shared=lr)
            elif variant in ['raw_pair','implicit_pair']:
                emit('derive_round0_paired',pairs,paired,shared=pr)
            else:
                emit('derive_round0_GL_literal',pairs,gl,shared=gr)
                emit('derive_round0_PL_paired',pairs,pl,shared=plr)
            stored=d if variant in ['baseline','raw_pair','boundary_skip'] else 1 if variant=='implicit_pl' else 0
            emit('initial_derived_store',m,write=16*stored)
        else:
            if variant in ['implicit_literal','implicit_pair']:
                cost,reads=(literal,lr) if variant=='implicit_literal' else (paired,pr)
                emit('rematerialize_later',pairs,cost,shared=reads)
                emit('added_chunk_barrier',math.ceil(pairs/32),barriers=1)
            elif variant=='implicit_pl':
                emit('rematerialize_PL_later',pairs,pl,shared=plr)
                emit('added_chunk_barrier',math.ceil(pairs/32),barriers=1)
            # Stored derived folds also form their staged high-low difference.
            stored=d if variant in ['baseline','raw_pair','boundary_skip'] else 1 if variant=='implicit_pl' else 0
            emit('staged_derived_difference',pairs*stored,dict(base_sub=2))
        h=m//2
        to_host=bool(tail and h>=2 and h<=1<<tail)
        boundary=to_host or h==1
        stored=d if variant in ['baseline','raw_pair','boundary_skip'] else 1 if variant=='implicit_pl' else 0
        if boundary:
            if variant=='boundary_skip':stored=0
            emit('generic_boundary_fold',h*stored,dict(base_mul=5,base_add=4,base_sub=2),read=32,write=16)
            break
        emit('fused_derived_fold',h*stored,dict(base_mul=3,base_add=8,base_sub=5),read=32,write=16)
        m=h;rno+=1
    sums=dict(device_primitives=plus(*(e['primitives'] for e in out if e['where']=='device')),host_preparation_primitives=plus(*(e['primitives'] for e in out if e['where']=='host')))
    for key in ['global_read_bytes','global_write_bytes','logical_shared_read_bytes','extra_chunk_barriers']:sums[key]=sum(e[key] for e in out)
    sums['last_device_length']=m;sums['host_transfer_length']=h if to_host else 0
    sums['device_rounds']=rno+1
    return sums,out

def closed(n,tail,supp,k,variant):
    L=1<<n;h=1<<tail if tail else 1;d=1+supp
    B,br=fixed_pair(k,supp,'literal');N,nr=fixed_pair(k,supp,'paired')
    G,gr=fixed_pair(k,False,'literal');NG,_=fixed_pair(k,False,'paired');PL=minus(N,NG)
    fused=dict(base_mul=3,base_add=8,base_sub=5);generic=dict(base_mul=5,base_add=4,base_sub=2)
    stored=d if variant in ['baseline','raw_pair','boundary_skip'] else 1 if variant=='implicit_pl' else 0
    initial=N if variant in ['raw_pair','implicit_pair'] else plus(G,PL) if variant=='implicit_pl' else B
    later=B if variant=='implicit_literal' else N if variant=='implicit_pair' else PL if variant=='implicit_pl' else {}
    count=L-h-L//2
    c=plus(vec(initial,L//2),vec(later,count),vec(fused,stored*(L-2*h)),vec(dict(base_sub=2),stored*count),vec(generic,0 if variant=='boundary_skip' else stored*h))
    return dict(device_primitives=c,global_total_bytes=16*stored*L+48*stored*((L-2*h)+(0 if variant=='boundary_skip' else h)),logical_shared_read_bytes=(nr if variant in ['raw_pair','implicit_pair'] else gr+32*k*supp if variant=='implicit_pl' else br)*(L//2)+(br if variant=='implicit_literal' else nr if variant=='implicit_pair' else 32*k if variant=='implicit_pl' else 0)*count)

def main():
    t=time.perf_counter();checks=0;rows=[];examples=[];negative=[]
    for k in [0,1,3,8,11]:
      for supp in [False,True]:
       for mode in ['literal','paired']:
        c,r,_=primitive_costs(params(k),supp,mode);fc,fr=fixed_pair(k,supp,mode)
        assert c==fc and r==fr,(k,supp,mode,c,fc,r,fr);checks+=1
    for n in [3,6,12,21,24]:
     for tail in sorted({0,1,min(6,n-2),n-2}):
      for supp,k in [(False,0)]+[(True,k) for k in [0,1,3,8,11]]:
       base,_=events(n,tail,supp,k,'baseline')
       for variant in ['baseline','raw_pair','implicit_literal','implicit_pair','implicit_pl','boundary_skip']:
        x,ev=events(n,tail,supp,k,variant);c=closed(n,tail,supp,k,variant)
        assert x['device_primitives']==c['device_primitives'];assert x['global_read_bytes']+x['global_write_bytes']==c['global_total_bytes'];assert x['logical_shared_read_bytes']==c['logical_shared_read_bytes'];checks+=3
        x.update(n=n,table_entries=1<<n,tail_log=tail,support=supp,pad_nonzero=k,variant=variant)
        x['device_delta_vs_baseline']=minus(x['device_primitives'],base['device_primitives'])
        x['saved_global_bytes_vs_baseline']=base['global_read_bytes']+base['global_write_bytes']-x['global_read_bytes']-x['global_write_bytes']
        x['logical_shared_delta_vs_baseline']=x['logical_shared_read_bytes']-base['logical_shared_read_bytes']
        if x['saved_global_bytes_vs_baseline']>0:
            x['extra_base_products_per_saved_global_byte']=max(0,x['device_delta_vs_baseline']['base_mul'])/x['saved_global_bytes_vs_baseline']
        rows.append(x)
        if n==21 and tail==0 and supp and k==11:examples.append(dict(summary=x,events=ev))
    # Accounting controls independent of arithmetic controls in pair_probe.
    for variant,field in [('baseline','global_write_bytes'),('implicit_pair','extra_chunk_barriers'),('raw_pair','logical_shared_read_bytes')]:
        x,_=events(12,1,True,11,variant);bad=dict(x);bad[field]=0
        assert bad[field]!=x[field];negative.append('zero_'+variant+'_'+field)
    x,_=events(12,6,True,11,'baseline');bad=plus(x['device_primitives'],dict(base_mul=-2*(1<<6)*2))
    assert bad!=x['device_primitives'];negative.append('generic_fold_mistaken_for_karatsuba')
    # A one-buffer best-fit pool is enough to falsify request==backing.
    # This is a sanity counterexample, not the prior native pool model.
    def best_fit_capacity(request,pool):
        eligible=[x for x in pool if x>=request]
        return min(eligible) if eligible else request
    backing=[best_fit_capacity(request,[1024]) for request in [736,464,400]]
    naive=[736,464,400]
    assert backing==[1024]*3 and backing[-1]-backing[0]!=naive[-1]-naive[0]
    negative.append('request_saving_mistaken_for_backing_saving')
    x,_=events(21,0,True,11,'implicit_pair')
    assert x['extra_chunk_barriers']!=x['device_rounds']-1
    negative.append('all_chunk_barriers_mistaken_for_round_count')
    result=dict(status='PASS_PARTIAL_SOURCE_ACCOUNTING_ONLY',cases=len(rows),checks=checks,negative_controls=len(negative),wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),scope='Native source-call counts before compilation; logical shared reads assuming unused-load DCE; not physical traffic, cache, occupancy, timings, peak or complete proof',new_verified_full_stack_proofs=0)
    for name,data in [('cost-result.json',result),('cost-cases.json',rows),('illustrative-f21-support11.json',examples),('cost-negative-controls.json',negative)]: (H/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(result));print(json.dumps([{'variant':x['summary']['variant'],'device_delta':x['summary']['device_delta_vs_baseline'],'prep':x['summary']['host_preparation_primitives'],'saved_global_MiB':x['summary']['saved_global_bytes_vs_baseline']/2**20,'shared_delta_MiB':x['summary']['logical_shared_delta_vs_baseline']/2**20,'extra_chunk_barriers':x['summary']['extra_chunk_barriers']} for x in examples]))
if __name__=='__main__':main()
