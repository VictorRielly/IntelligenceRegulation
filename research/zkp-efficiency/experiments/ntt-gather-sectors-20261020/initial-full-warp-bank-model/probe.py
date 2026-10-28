from pathlib import Path
import json, os, platform, random, resource, time
import model as m
import reference as ref

HERE=Path(__file__).resolve().parent
SEED=20261020101
rng=random.Random(SEED)
start=time.monotonic()
checks=tiles=words=0
negative=[]

def check(value):
    global checks
    checks+=1
    assert value, checks

def layout(w):
    flat=[(q,r,a) for warp in w for q,r,a in warp]
    return sorted(flat)

def reject(name,bad,good):
    check(bad!=good)
    negative.append(name)

specs=[{'label':'dense-public-index','logn':l,'nsrc':1<<l,'width':1<<l}
       for l in [5,6,8,10,11,12,13,14,16,20,24]]
for l,n,q in [(11,128,256),(11,256,256),(13,1024,256),(15,4096,256),(16,8192,256)]:
    specs.append({'label':'compact-hiding-public-geometry-not-profile-admission','logn':l,
                  'nsrc':n+q,'width':n+q,'data_n':n,'q_pad':q})
for l,n in [(12,1),(12,17),(12,(1<<12)-1),(14,513),(14,(1<<14)-1)]:
    specs.append({'label':'ragged-boundary-control','logn':l,'nsrc':n,'width':n})

census=[]
for si,s in enumerate(specs):
    logn=s['logn']; n=1<<logn; bs=min(n,4096); bpr=n//bs
    blocks=sorted({0,bpr//2,bpr-1})
    for row in [0,1,2]:
        base=[0,8,24][row] if s['label']=='ragged-boundary-control' else 0
        for blk in blocks:
            oracle=ref.tile(logn,s['nsrc'],row,blk,base)
            expected=ref.expected_values(logn,row,blk,s['width'],SEED)
            for threads in [32,512]:
                for mode in ['literal','rotate1','rotate2','reverse']:
                    w=m.p1(logn,s['nsrc'],row,blk,threads,base,mode)
                    flat=layout(w)
                    check(len(flat)==bs and [q for q,_,_ in flat]==list(range(bs)))
                    check([(r,a) for _,r,a in flat]==oracle)
                    vals=[ref.read(a,base,s['nsrc'],s['width'],SEED) if a is not None else 0
                          for _,_,a in flat]
                    check(vals==expected)
                    check(m.sectors(w)==ref.sectors(w))
                    # Reference bank audit on two independent warp positions.
                    check(m.bank_demand(w[:1]+w[-1:])==ref.banks(w[:1]+w[-1:]))
                    active=sum(a is not None for warp in w for _,_,a in warp)
                    unique={a//32 for warp in w for _,_,a in warp if a is not None}
                    bank=m.bank_demand(w[:1]+w[-1:])
                    census.append({**s,'row':row,'base_byte_offset':base,'blk':blk,
                                   'blocks_per_row':bpr,'threads':threads,'mode':mode,
                                   'source_words':active,'requested_sectors':m.sectors(w),
                                   'unique_source_sectors':len(unique),'bank_peak_unique_u32_words_sampled':bank,
                                   'modeled_shared_write_bytes':bs*8,
                                   'global_load_useful_byte_fraction':active*8/(32*m.sectors(w)) if active else None})
                    tiles+=1;words+=bs
    # Compact/full-width must create the same logical tile, even though row addresses differ.
    if s['nsrc']<n:
        for blk in blocks:
            compact=m.p1(logn,s['nsrc'],2,blk,512)
            full=m.p1(logn,n,2,blk,512)
            cv=[ref.read(a,0,s['nsrc'],s['width'],SEED) if a is not None else 0 for _,_,a in layout(compact)]
            fv=[ref.read(a,0,n,s['width'],SEED) if a is not None else 0 for _,_,a in layout(full)]
            check(cv==fv)

# Closed-form stride identity, independently checked against scalar full bit reversal.
identity_cases=0
for logn in [5,12,13,14,16,20,24]:
    lb=min(12,logn); lt=logn-lb
    for _ in range(80):
        blk=rng.randrange(1<<lt); q=rng.randrange(1<<lb)
        rhs=ref.reverse(q,lb)*(1<<lt)+(ref.reverse(blk,lt) if lt else 0)
        check(rhs==(m.brev32((blk<<lb)+q)>>(32-logn)))
        identity_cases+=1

# Existing DIF routes: no bit-reversed natural-order gather here.
routes=[]
for logn in [12,13,14,16,20,24]:
    n=1<<logn; bpr=n//4096
    pa=m.dif_pa(logn,1,0,512) if logn>12 else None
    if pa:
        J=4096//bpr
        indices=[t*4096+j for t in range(bpr) for j in range(J)]
        check([r for _,r,_ in layout(pa)]==indices)
        check(m.sectors(pa)==ref.sectors(pa))
        routes.append({'route':'DIF_PA','logn':logn,'sample_tile':0,'words':4096,'sectors':m.sectors(pa),'unique':len({a//32 for w in pa for _,_,a in w})})
    pb=m.dif_pb(logn,1,0,512)
    check([r for _,r,_ in layout(pb)]==list(range(4096)))
    check(m.sectors(pb)==1024)
    routes.append({'route':'DIF_PB','logn':logn,'sample_tile':0,'words':4096,'sectors':m.sectors(pb)})
    for skip in [False,True]:
        pad=m.dit_pad(logn,1,0,2,skip)
        check(m.sectors(pad)==ref.sectors(pad))
        routes.append({'route':'DIT_PAD_SKIP' if skip else 'DIT_PAD_LITERAL','logn':logn,
                       'sample_tile':0,'lane_loads':sum(a is not None for w in pad for _,_,a in w),
                       'sectors':m.sectors(pad),'unique':len({a//32 for w in pad for _,_,a in w if a is not None})})

# Negative controls are deliberate wrong implementations, never evidence of parity.
good=layout(m.p1(13,1280,2,0,512))
reject('compact stride incorrectly uses nn',layout(m.p1(13,8192,2,0,512)),good)
reject('zero bound incorrectly drops q pads',layout(m.p1(13,1024,2,0,512)),good)
wrong=[(q,(q),8*(2*1280+q) if q<1280 else None) for q in range(4096)]
reject('omit global bit reversal',wrong,good)
wrong=[(q,m.brev32(q)>>(32-12),a) for q,_,a in good]
reject('reverse tile bits instead of whole-domain bits',wrong,good)
wrong=[(q,r,(a+8 if a is not None else None)) for q,r,a in good]
reject('source view offset one word wrong',wrong,good)
rev=m.p1(12,4096,0,0,512,mode='reverse')
wrong=[(j,r,a) for j,(_,r,a) in enumerate(z for w in rev for z in w)]
reject('permute source without matching logical shared index',sorted(wrong),layout(rev))
lit=m.p1(12,4096,0,0,512)
reject('count unique sectors as requested sectors',len({a//32 for w in lit for _,_,a in w}),m.sectors(lit))
reject('assume reordered shared stores remain bank-free',m.bank_demand(lit),m.bank_demand(rev))
reject('mistake eight-byte elements for four-byte sectors',sum(len({a//16 for _,_,a in w}) for w in rev),m.sectors(rev))
check(m.sectors(m.p1(14,16384,0,0,512))==m.sectors(m.p1(14,16384,0,0,512,mode='reverse')))
negative.append('large-transform no-sector-gain control')

summary=[]
for logn in [5,6,8,10,11,12,13,14,16,20,24]:
    c=[x for x in census if x['logn']==logn and x['label']=='dense-public-index'
       and x['row']==0 and x['blk']==0 and x['threads']==512]
    summary.append({'logn':logn,'tiles_per_row':1<<max(logn-12,0),
                    'modes':{x['mode']:{k:x[k] for k in ['source_words','requested_sectors','unique_source_sectors','bank_peak_unique_u32_words_sampled','global_load_useful_byte_fraction']} for x in c}})

out={'status':'PASS_SYNTHETIC_PUBLIC_ADDRESS_MODEL_ONLY','seed':SEED,'specs':len(specs),
     'checks':checks,'tile_schedules':tiles,'logical_words_checked':words,'stride_identity_cases':identity_cases,
     'negative_controls':len(negative),'wall_s':time.monotonic()-start,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
     'threads':1,'affinity':sorted(os.sched_getaffinity(0)),
     'dense_summary':summary,'scope':'Address/zero-tail equivalence, source sector requests and sampled shared-bank address pressure; no native instruction/cache/DRAM/time/proof claims',
     'full_stack':{'proofs':0,'passes':0,'positions':0,'context_length':None,'device':None,
                   'witness_s':None,'proof_s':None,'serialization_s':None,'verification_s':None,
                   'startup_s':None,'startup_fraction':None,'steady_rate':None,'total_rate':None}}
for name,data in [('result.json',out),('census.json',census),('routes.json',routes),('negative-controls.json',negative)]:
    (HERE/name).write_text(json.dumps(data,indent=2)+'\n')
hardware={'cpu':next((l.strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),None),
          'platform':platform.platform(),'python':platform.python_version(),'actual_gpu_used':False,
          'estimated_experiment_memory_MiB':64,'hardware_scope':'CPU synthetic address arithmetic only; no GPU query/job'}
(HERE/'hardware.json').write_text(json.dumps(hardware,indent=2)+'\n')
print(json.dumps({k:v for k,v in out.items() if k!='dense_summary'},indent=2))
