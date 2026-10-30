import os, resource, signal, time, json, random, hashlib, platform
from pathlib import Path
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
os.nice(19)
resource.setrlimit(resource.RLIMIT_CPU,(40,40))
resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2))
signal.alarm(45)
from candidate import P, root, transform, split, materialized, columns, operation_counts
from reference import original, interpolate, lagrange_at, horner, byte_columns

HERE=Path(__file__).resolve().parent
PROJ=Path('/home/victor/IntelligenceRegulation')
SEED=202610290135
rng=random.Random(SEED)
t0=time.perf_counter()
checks=0
def check(ok):
    global checks
    checks+=1
    assert ok, checks

fixtures=[]; points=0; lagrange_checks=0; rejected=[]
for n in (2,4,8,16,32,64):
    for rate in (2,4,8):
        for q in sorted({0,1,n//2,n,n+1,(rate-1)*n}):
            if n+q > n*rate: continue
            for mode in ('random','edge'):
                msg=[rng.randrange(P) for _ in range(n)] if mode=='random' else [0,P-1,1,P-2]*(n//4)+[P-1]*(n%4)
                pad=[rng.randrange(P) for _ in range(q)] if mode=='random' else [P-1 if i%2 else 1 for i in range(q)]
                h=7 if mode=='random' else 11
                a=split(msg,pad,rate,h)
                ref=original(msg,pad,n*rate,h)
                b=materialized(msg,pad,rate,h)
                for v,w,z in zip(a,ref,b):check(v==w==z)
                check(transform(msg,True)==interpolate(msg))
                for k in sorted({0,1,n*rate//2,n*rate-1}):
                    x=h*pow(root(n*rate),k,P)%P
                    check(ref[k]==(lagrange_at(msg,x)+(pow(x,n,P)-1)*horner(pad,x))%P)
                    lagrange_checks+=1
                points+=len(a)
                fixtures.append(dict(n=n,rate=rate,q=q,h=h,mode=mode,
                    sha256=hashlib.sha256(b''.join(v.to_bytes(8,'little') for v in a)).hexdigest()))

# Existing synthetic native conformance outputs are a third implementation.
vectors=json.loads((PROJ/'results/zk60_encode_vectors/vectors.json').read_text())['vectors']
full=json.loads((PROJ/'results/zk60_encode_vectors/full_rows.json').read_text())['rows']
conformance=[]
for v in vectors:
    if v['n']>64:continue
    got=split(v['msg'],v['pad'],v['nn']//v['n'],v['coset_h'])
    check(got==full[v['name']])
    check(hashlib.sha256(b''.join(x.to_bytes(8,'little') for x in got)).hexdigest()==v['encoded_sha256'])
    conformance.append(v['name'])

# Deliberately wrong arithmetic/order/pad folding is detected independently.
n=8; rate=4; h=7
msg=[rng.randrange(P) for _ in range(n)]
pad=[rng.randrange(P) for _ in range(3*n)]
ref=original(msg,pad,n*rate,h)
for fault in ('inverse_scale','coset','wrong_root','fold_power','pad_sign','output_order','truncate_q'):
    check(split(msg,pad,rate,h,fault)!=ref);rejected.append(fault)
# q>n must not silently use the q<=n shortened coefficient construction.
minimal_pad=[0]*(n+1);minimal_pad[n]=1
check(split([0]*n,minimal_pad,4,7)==original([0]*n,minimal_pad,n*4,7))
check(split([0]*n,minimal_pad,4,7,'truncate_q')!=original([0]*n,minimal_pad,n*4,7))
rejected.append('minimal_high_pad_ignored')

# Multiple physical rows, ragged last chunk, output selection and duplicates.
n=16; rate=4
msgs=[[rng.randrange(P) for _ in range(n)] for _ in range(7)]
pads=[[rng.randrange(P) for _ in range(n+3)] for _ in range(7)]
refrows=[original(m,p,n*rate,11) for m,p in zip(msgs,pads)]
indices=[63,0,19,19,5,32,1]
chunk_checks=0
for chunk in (1,2,3,7):
    rows=[]
    for start in range(0,len(msgs),chunk):
        for r in range(start,min(start+chunk,len(msgs))):
            rows.append(split(msgs[r],pads[r],rate,11))
    for k in range(n*rate):
        check(columns(rows,[k])==byte_columns(refrows,[k]));chunk_checks+=1
    check(columns(rows,indices)==byte_columns(refrows,indices))
    check(columns(rows,list(dict.fromkeys(indices)))!=byte_columns(refrows,indices))
    check(columns(list(reversed(rows)),indices)!=byte_columns(refrows,indices))
rejected+=['lost_duplicate_requests','reversed_rows']
# Stale pad proof cache invalid: fixed message, fresh per-proof pad changes.
newpad=list(pads[0]);newpad[-1]=(newpad[-1]+1)%P
old=split(msgs[0],pads[0],rate,11)
new=split(msgs[0],newpad,rate,11)
check(old!=new and new==original(msgs[0],newpad,n*rate,11))
rejected.append('stale_cross_proof_private_result')
# Flat stride mistakes must alter a complete selected column byte stream.
flat=[v for row in refrows for v in row]
wrong=[flat[r*(n*rate-1):r*(n*rate-1)+n*rate] for r in range(7)]
check(columns(wrong,indices)!=byte_columns(refrows,indices));rejected.append('wrong_row_stride')
wrongpad=[split(msgs[r],pads[0],rate,11) for r in range(7)]
check(columns(wrongpad,indices)!=byte_columns(refrows,indices));rejected.append('stale_chunk_pad_offset')

# Algebra fixture refusals only, not native acceptance/refusal coverage.
for args in [([1]*3,[],4,7),([1]*4,[1]*13,4,7),([1]*4,[],3,7),
             ([1]*4,[],4,1),([P]*4,[],4,7),([1]*4,[],4,0)]:
    try:split(*args)
    except AssertionError:check(True)
    else:raise AssertionError('missing refusal')

counts=[operation_counts(n,q,r) for n in (1024,4096,8192,16384) for r in (2,4,8) for q in (0,256,n)]
for c in counts:
    n,q,r=c['n'],c['q'],c['rate']
    # Independently sum stage-wise incidences rather than use closed forms.
    base=sum((r*n)//2 for _ in range((r*n).bit_length()-1))
    sub=sum(n//2 for _ in range(n.bit_length()-1))*r
    check(c['forward_butterflies_removed']==base-sub)
    check(c['mul_saved']==base-sub-(r-1)*(n+q))
check(operation_counts(16384,256,4)['mul_saved']==15616)
check(operation_counts(16384,16384,4)['mul_saved']<0)

result=dict(status='PASS_EXACT_SYNTHETIC_ONLY_NO_NATIVE_GAIN',seed=SEED,checks=checks,
    fixtures=len(fixtures),encoded_points=points,lagrange_checks=lagrange_checks,
    conformance_vectors=conformance,chunk_column_checks=chunk_checks,
    rejected_controls=rejected,fixture_refusals=6,counts=counts,
    elapsed_s=time.perf_counter()-t0,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    cpu_affinity=sorted(os.sched_getaffinity(0)),python=platform.python_version(),platform=platform.platform(),
    limits=dict(cpu_s=40,alarm_s=45,address_space_mib=256,estimated_memory_mib=64,threads=1,nice=19),
    native_execution=False,gpu_execution=False,complete_verified_proofs=0,
    complete_passes=0,proved_positions=0)
(HERE/'fixtures.json').write_text(json.dumps(fixtures,indent=2)+'\n')
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='counts'},indent=2))
