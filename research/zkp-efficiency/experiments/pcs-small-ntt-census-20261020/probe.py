"""Public shape census and differential request counts. No native/GPU/proof run."""
from pathlib import Path
import json, time, resource, random
import address_model as model
import reference as ref

HERE=Path(__file__).resolve().parent
SEED=0x10201002
checks=0

def check(a,b=True):
    global checks
    assert a==b,(a,b)
    checks+=1

def geometry(lc,rate,q,opened,t,d):
    if rate<2 or rate&(rate-1):raise ValueError('row geometry')
    n=1<<lc;nn=n*rate
    if q<opened:raise ValueError('pad budget')
    if n+q>nn:raise ValueError('pad capacity')
    return dict(n=n,nn=nn,log_nn=nn.bit_length()-1,q_pad=q,
                compact_stride=n+q,endpoint_rows=(t*d+n-1)//n+5)

def cost(logn,stride,row,mode,base=0):
    bs=1<<min(logn,12)
    warps=(model.p1(logn,stride,row,blk,512,base,mode)
           for blk in range((1<<logn)//bs))
    requests=active=0
    for tile in warps:
        requests+=model.sectors(tile)
        active+=sum(a is not None for warp in tile for _,_,a in warp)
    return requests,active

def allowed(logn,backend):
    return backend=='k_ntt_p1' and 8<=logn<=13

def profiles():
    out=[]
    for lane in ['gpu','r9']:
        for t,lc in [(32,12),(64,13),(128,14)]:
            out.append(dict(lane=lane,model='TinyLlama-1.1B',context=t,width=2048,
                            log_cols=lc,inv_rate=4,dd=False,scope='trained geometry'))
        for t,lc in ([(32,13)] if lane=='gpu' else [(32,13),(64,13),(128,14)]):
            out.append(dict(lane=lane,model='Llama-3-8B',context=t,width=4096,
                            log_cols=lc,inv_rate=4,dd=False,scope='trained geometry'))
    for name,d in [('TinyLlama-1.1B',2048),('Llama-3-8B',4096)]:
        out.append(dict(lane='r9',model=name,context=128,width=d,log_cols=14,
                        inv_rate=4,dd=True,scope='DD trained geometry'))
    for name,t,d,lc,rate,el,er in [('toy',32,16,8,8,8,8),
                                   ('rung',24,96,10,4,8,8),
                                   ('rung_g',24,96,10,4,10,4),
                                   ('m125',512,768,14,4,14,4)]:
        out.append(dict(lane='r9',model=name,context=t,width=d,log_cols=lc,
                        inv_rate=rate,dd=False,scope='diagnostic geometry',
                        endpoint_log_cols=el,endpoint_inv_rate=er))
    return out

start=time.monotonic(); census=[]; cache={}; geometries=set()
for p in profiles():
    t,d=p['context'],p['width']
    # Profiles' endpoints use padded D cubes. The trained widths are powers
    # of two; diagnostic rung and m125 widths are padded independently here.
    padded_t=1<<(t-1).bit_length();padded_d=1<<(d-1).bit_length()
    for role in ['A','H','endpoint_or_boundary']:
        lc=p.get('endpoint_log_cols',p['log_cols']) if role=='endpoint_or_boundary' else p['log_cols']
        rate=p.get('endpoint_inv_rate',p['inv_rate']) if role=='endpoint_or_boundary' else p['inv_rate']
        g=geometry(lc,rate,256,256,padded_t,padded_d)
        check(g,ref.geometry(lc,rate,256,256,padded_t,padded_d))
        # Small inverse and expanded forward are distinct actual P1 calls.
        for phase,logn,stride in [('inverse',lc,g['n']),
                                  ('forward_resident',g['log_nn'],g['nn']),
                                  ('forward_compact',g['log_nn'],g['compact_stride'])]:
            key=(logn,stride)
            geometries.add(key)
            if key not in cache:
                old=cost(logn,stride,0,'literal')
                new=cost(logn,stride,0,'rotate1') if allowed(logn,'k_ntt_p1') else old
                check(old,ref.requests(logn,stride,0,False))
                check(new,ref.requests(logn,stride,0,allowed(logn,'k_ntt_p1')))
                check(old[1],min(stride,1<<logn))
                cache[key]=dict(literal_requests=old[0],candidate_requests=new[0],active_words=old[1])
            census.append(dict(**p,role=role,phase=phase,transform_log=logn,
                               message_words=g['n'],encoded_words=g['nn'],
                               endpoint_rows=g['endpoint_rows'] if role=='endpoint_or_boundary' else None,
                               n_src=stride,q_pad=256,backend='k_ntt_p1',
                               eligible=allowed(logn,'k_ntt_p1'),**cache[key]))
    slots=24 if p['dd'] else 23
    census.append(dict(**p,role='M',phase='forward_coset',transform_log=12,
                       n_src=None,q_pad=256,backend='CPU NttTables::forward',
                       eligible=False,mask_rows=2*slots+4))

# Exhaustive all-tiles checks for distinct geometries at rows 0/1 and an
# aligned one-word base offset. Values are public synthetic dimensions only.
for logn,stride in sorted(geometries):
    for row,base in [(0,0),(1,0),(1,8)]:
        for mode in ['literal','rotate1']:
            check(cost(logn,stride,row,mode,base),
                  ref.requests(logn,stride,row,mode=='rotate1',base))

# Random boundary geometry: independent multiplication vs shift reference.
rng=random.Random(SEED);boundary_cases=0
for _ in range(400):
    lc=rng.randrange(6,17);rate=1<<rng.randrange(1,5)
    n=1<<lc;opened=rng.randrange(1,min(n,256)+1)
    q=rng.randrange(opened,n*(rate-1)+1)
    check(geometry(lc,rate,q,opened,32,2048),ref.geometry(lc,rate,opened,q,32,2048))
    boundary_cases+=1
for lc in range(6,17):
    n=1<<lc
    for q in [n-1,n,n+1,3*n]:
        check(geometry(lc,4,q,1,32,2048),ref.geometry(lc,4,1,q,32,2048))
        boundary_cases+=1

controls=[]
def reject(name,predicate):
    check(bool(predicate));controls.append(dict(name=name,rejected=True))
reject('expanded-log-only misses trained small inverse',
       any(x['model']=='Llama-3-8B' and x['phase']=='inverse' and x['eligible'] and x['scope']=='trained geometry' for x in census))
reject('message-width labels forward incorrectly',
       any(x['model']=='Llama-3-8B' and x['phase'].startswith('forward') and x['transform_log']>=15 and not x['eligible'] for x in census))
reject('M log12 does not imply CUDA execution',not allowed(12,'CPU NttTables::forward'))
reject('context128 is not transform_log128',all(x['transform_log'] in range(8,17) for x in census if x['context']==128))
reject('frozenR9 8B T128 remains outside inverse guard',all(not x['eligible'] for x in census if x['model']=='Llama-3-8B' and x['context']==128))
reject('DD adds M rows without device routing',all(x['mask_rows']==52 and not x['eligible'] for x in census if x['dd'] and x['role']=='M'))
for name,args in [('too_few_pads',(12,4,255,256,32,2048)),
                  ('over_capacity',(8,2,257,256,32,2048)),
                  ('non_power_rate',(12,3,256,256,32,2048))]:
    outcomes=[]
    for fn in [lambda:geometry(*args),lambda:ref.geometry(args[0],args[1],args[3],args[2],args[4],args[5])]:
        try:fn();outcomes.append(False)
        except ValueError:outcomes.append(True)
    reject(name,all(outcomes))
# Exact boundary: n+q=nn is valid; it must not be silently rejected.
check(geometry(8,2,256,256,32,16)['compact_stride'],512)

summary=[]
for lc in [12,13,14]:
    n=1<<lc;ni=cache[(lc,n)];dense=cache[(lc+2,4*n)];compact=cache[(lc+2,n+256)]
    summary.append(dict(log_cols=lc,inverse=ni,forward_resident=dense,forward_compact=compact,
        resident_pair_request_fraction_saved=(ni['literal_requests']-ni['candidate_requests'])/(ni['literal_requests']+dense['literal_requests']),
        compact_pair_request_fraction_saved=(ni['literal_requests']-ni['candidate_requests'])/(ni['literal_requests']+compact['literal_requests'])))
full=dict(proofs=0,passes=0,positions=0,context_length=None,device=None,
          witness_s=None,proof_s=None,serialization_s=None,verification_s=None,
          startup_s=None,startup_fraction=None,steady_rate=None,total_rate=None)
result=dict(seed=SEED,checks=checks,profiles=len(profiles()),census_rows=len(census),
            distinct_transform_geometries=len(geometries),boundary_cases=boundary_cases,
            negative_controls=len(controls),summary=summary,
            elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            full_stack=full,scope='Public source geometry/address/request accounting, not native timing or complete proof')
for name,value in [('census.json',census),('negative-controls.json',controls),('result.json',result)]:
    (HERE/name).write_text(json.dumps(value,indent=2)+'\n')
print(json.dumps(result))
