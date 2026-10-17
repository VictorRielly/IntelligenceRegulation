"""Bounded serial differential arithmetic and decisive privacy controls."""
import collections, ctypes as C, datetime, hashlib, itertools, json, os
from pathlib import Path
import random, resource, signal, subprocess, time

HERE=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))}); os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
start=time.perf_counter(); seed=2026101767; rng=random.Random(seed)
P=2**64-2**32+1; Z=(0,0); O=(1,0)
def add(a,b): return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b): return ((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b): return ((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def inv(a):
    d=(a[0]*a[0]-7*a[1]*a[1])%P
    if not d: raise ZeroDivisionError
    d=pow(d,-1,P); return (a[0]*d%P,-a[1]*d%P)
def total(xs):
    out=Z
    for x in xs: out=add(out,x)
    return out
def weight(i,r):
    out=O
    for k,x in enumerate(r): out=mul(out,x if (i>>k)&1 else sub(O,x))
    return out
def fold(values,r):
    a=list(values)
    for x in r: a=[add(mul(a[i],sub(O,x)),mul(a[i+1],x)) for i in range(0,len(a),2)]
    assert len(a)==1
    return a[0]

rustc=Path('/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/rustc')
(HERE/'tmp').mkdir(exist_ok=True)
env=dict(os.environ,TMPDIR=str(HERE/'tmp'),RAYON_NUM_THREADS='1',OMP_NUM_THREADS='1')
argv=[str(rustc),'--edition=2021','--crate-type=cdylib','-C','opt-level=1','-C','codegen-units=1','isolated.rs','-o','isolated.so']
with (HERE/'compile.log').open('w') as f: subprocess.run(argv,cwd=HERE,env=env,stdout=f,stderr=subprocess.STDOUT,check=True,timeout=35)
lib=C.CDLL(str(HERE/'isolated.so')); fn=lib.candidate
fn.argtypes=[C.POINTER(C.c_size_t),C.c_size_t,C.c_size_t,C.POINTER(C.c_uint64),C.c_size_t,C.POINTER(C.c_uint64),C.c_size_t,C.POINTER(C.c_uint64)];fn.restype=C.c_uint32
def candidate(indices,active,r,table):
    ii=(C.c_size_t*len(indices))(*indices)
    rr=(C.c_uint64*(2*len(r)))(*(v for z in r for v in z))
    tt=(C.c_uint64*(2*len(table)))(*(v for z in table for v in z))
    out=(C.c_uint64*(2*len(table)+2))()
    status=fn(ii,len(indices),active,rr,len(r),tt,len(table),out)
    return status,[tuple(out[i:i+2]) for i in range(0,len(out),2)]

counts=collections.Counter(); cases=[]; controls={}
for m,k in itertools.product([2,4,8,16,256],[0,1,2,3,4,6]):
    n=1<<k
    for active in sorted({0,1,n,max(0,n-1),min(n,3),min(n,5)}):
        indices=[rng.randrange(m) for _ in range(active)]+[m+71]*(n-active)
        # All synthetic. Inactive garbage tests support without dereferencing it.
        for kind in ['extension','base','boolean']:
            r=[(rng.randrange(P),rng.randrange(P)) if kind=='extension' else ((rng.randrange(P),0) if kind=='base' else (rng.randrange(2),0)) for _ in range(k)]
            table=[(rng.randrange(P),rng.randrange(P)) for _ in range(m)]
            status,out=candidate(indices,active,r,table);assert status==0
            # Independent product-form equality basis and one-hot matrix enumeration.
            w=[weight(i,r) for i in range(n)]
            y=[total(w[i] for i in range(active) if indices[i]==j) for j in range(m)]
            values=[table[indices[i]] if i<active else Z for i in range(n)]
            claimed=total(mul(w[i],values[i]) for i in range(n))
            assert out==y+[claimed]
            assert claimed==fold(values,r)
            assert total(y)==total(w[:active])
            counts['fixtures']+=1; counts['pushforward_fp2_values']+=m;counts['virtual_claims']+=1;counts['support_checks']+=1
            cases.append(dict(m=m,n=n,active=active,r=r,index=indices,table=table,out=out))

# Invalid active index must refuse. Inactive index was intentionally out of range.
controls['active invalid index refuses']=candidate([4,0],1,[(2,3)],[(7,1)]*4)[0]==2
controls['inconsistent cube size refuses']=candidate([0,0,0],3,[(2,3)],[(7,1)]*4)[0]==1
controls['active length overflow refuses']=candidate([0,0],3,[(2,3)],[(7,1)]*4)[0]==1
controls['missing support changes virtual value']=candidate([0,0],1,[(2,3)],[(7,1)]*4)[1][-1]!=candidate([0,0],2,[(2,3)],[(7,1)]*4)[1][-1]

# A single private value is exactly recovered from an unmasked virtual claim,
# even if its pushforward commitment were perfectly hiding. These are NOT
# messages emitted by the existing native proof or an attack on upstream LogUp*.
recovery=[]
for k in [0,1,2,3,6]:
    r=[(11+i,3+i) for i in range(k)];n=1<<k
    table=[(j+1,(3*j+2)%P) for j in range(8)]
    for secret in [0,1,5,7]:
        _,out=candidate([secret]+[999]*(n-1),1,r,table)
        got=mul(out[-1],inv(weight(0,r)));assert got==table[secret]
        recovery.append(dict(k=k,index=secret,claim=out[-1],recovered=got))
controls['unmasked virtual evaluation reveals singleton despite hidden commitment']=len(recovery)==20
table=[(j,0) for j in range(4)];r=[(3,5)]
_,left=candidate([1,3],2,r,table);_,right=candidate([3,1],2,r,table)
assert collections.Counter([1,3])==collections.Counter([3,1])
controls['histogram equality does not bind ordered original witness']=left[-1]!=right[-1]
half=(pow(2,-1,P),0)
controls['degenerate half challenge correctly loses permutation distinction']=candidate([1,3],2,[half],table)[1][-1]==candidate([3,1],2,[half],table)[1][-1]

# A zero-sum mask cannot both preserve the raw value and hide that value.
y=left[:-1];t=[(0,0),(1,0),(2,0),(3,0)];mask=[(1,0),(P-1,0),Z,Z]
masked=[add(a,b) for a,b in zip(y,mask)]
controls['zero sum pushforward mask changes virtual evaluation']=total(mul(a,b) for a,b in zip(masked,t))!=left[-1]
orthogonal=[(1,0),(P-2,0),(1,0),Z]
controls['value preserving mask preserves leaking scalar']=total(mul(add(a,b),c) for a,b,c in zip(y,orthogonal,t))==left[-1]

# A literal denominator-support test from native whole-table inversion contract.
# Membership validity alone accepts used indices [1,3]; old zero at UNUSED2 refuses.
alpha=(2,0);public=[(j,0) for j in range(4)];used=[1,3]
whole=all(sub(alpha,v)!=Z for v in public)
used_only=all(sub(alpha,public[j])!=Z for j in used)
controls['unused table zero cannot be omitted']=not whole and used_only
controls['tampered table terminal changes arithmetic']=candidate([1,3],2,r,[(0,0),(1,0),(2,0),(4,0)])[1][-1]!=left[-1]
controls['tampered pushforward terminal changes arithmetic']=total(mul(add(v,(1,0) if j==1 else Z),table[j]) for j,v in enumerate(y))!=left[-1]

# Pure counting illustration over F17: one fresh scalar one-time pad hides this
# one scalar; REUSE reveals differences. This is NOT a ZK lookup construction.
q=17;histograms=[collections.Counter((v+b)%q for b in range(q)) for v in range(q)]
controls['fresh scalar mask marginal is uniform in finite field toy']=all(h==histograms[0] for h in histograms)
controls['reusing scalar mask exposes differences']=all((((3+b)%q-(9+b)%q)%q)==(3-9)%q for b in range(q))
assert all(controls.values()),controls
(HERE/'fixtures.json').write_text(json.dumps(cases,separators=(',',':'))+'\n')
(HERE/'disclosure-controls.json').write_text(json.dumps(dict(recovery=recovery,permutation=dict(r=r,left=left,right=right),controls=controls),indent=2)+'\n')
data=dict(status='PASS',cycle='0067',run_id='20261017T202105Z-363d38a1',seed=seed,counts=dict(counts),negative_controls=controls,wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,child_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,compiler_argv=argv,cpu_affinity=list(os.sched_getaffinity(0)),threads=1,nice=os.getpriority(os.PRIO_PROCESS,0),limits='59s CPU/wall,512MiB address space; estimated<96MiB Python/<192MiB rustc',fixture_sha256=hashlib.sha256((HERE/'fixtures.json').read_bytes()).hexdigest(),scope='Local Rust pushforward uses captured native Goldilocks Fp2; independent Python one-hot/product/fold oracle. No GKR, PCS, native receipt, GPU, masking proof or performance result.',completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(HERE/'result.json').write_text(json.dumps(data,indent=2)+'\n');print(json.dumps(data,indent=2))
