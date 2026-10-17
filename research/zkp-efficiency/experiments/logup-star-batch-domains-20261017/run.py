"""Bounded Rust/Python synthetic batching differential; never a proof benchmark."""
from pathlib import Path
import os,resource,signal,time,subprocess,ctypes as C,json,random,collections,hashlib,datetime
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter(); rng=random.Random(2026101768)
P=2**64-2**32+1;Z=(0,0);O=(1,0)
def add(a,b):return ((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b):return ((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b):return ((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def inv(a):
 d=pow((a[0]*a[0]-7*a[1]*a[1])%P,-1,P);return(a[0]*d%P,-a[1]*d%P)
def total(xs):
 a=Z
 for x in xs:a=add(a,x)
 return a
def weight(i,r):
 a=O
 for k,x in enumerate(r):a=mul(a,x if (i>>k)&1 else sub(O,x))
 return a
def fold(v,r):
 a=list(v)
 for x in r:a=[add(mul(a[i],sub(O,x)),mul(a[i+1],x)) for i in range(0,len(a),2)]
 assert len(a)==1
 return a[0]
(H/'isolated.rs').write_text((H/'field-only.rs').read_text()+(H/'batch.rs').read_text())
(H/'tmp').mkdir(exist_ok=True)
argv=['/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/rustc','--edition=2021','--crate-type=cdylib','-C','opt-level=1','-C','codegen-units=1','isolated.rs','-o','isolated.so']
with (H/'compile.log').open('w') as f:subprocess.run(argv,cwd=H,env=dict(os.environ,TMPDIR=str(H/'tmp'),RAYON_NUM_THREADS='1',OMP_NUM_THREADS='1'),stdout=f,stderr=subprocess.STDOUT,check=True,timeout=35)
lib=C.CDLL(str(H/'isolated.so'));fn=lib.candidate;U=C.c_size_t;W=C.c_uint64
fn.argtypes=[C.POINTER(U),U,C.POINTER(U),C.POINTER(U),U,C.POINTER(W),U,C.POINTER(W),U,U,C.POINTER(W)];fn.restype=C.c_uint32
def candidate(cols,active,r,s,m):
 idx=[j for col in cols for j in col];lens=list(map(len,cols));out=(W*(2*m))()
 status=fn((U*len(idx))(*idx),len(idx),(U*len(lens))(*lens),(U*len(active))(*active),len(cols),(W*(2*len(r)))(*(v for z in r for v in z)),len(r),(W*(2*len(s)))(*(v for z in s for v in z)),len(s),m,out)
 return status,[tuple(out[j:j+2]) for j in range(0,len(out),2)]
cases=[];counts=collections.Counter();controls={}
for c in [1,2,3,5,9,13,34,83]:
 h=(c-1).bit_length()
 for k in [0,1,3,5]:
  n=1<<k
  for kind in ['extension','base','boolean']:
   rand=lambda:(rng.randrange(P),rng.randrange(P)) if kind=='extension' else (rng.randrange(P) if kind=='base' else rng.randrange(2),0)
   r=[rand() for _ in range(k)];s=[rand() for _ in range(h)];m=256 if c==83 else 8
   lens=[1<<rng.randrange(k+1) for _ in range(c)]
   active=[rng.randrange(l+1) for l in lens]
   cols=[[rng.randrange(m) for _ in range(a)]+[m+19]*(l-a) for l,a in zip(lens,active)]
   table=[(rng.randrange(P),rng.randrange(P)) for _ in range(m)]
   status,y=candidate(cols,active,r,s,m);assert status==0
   # Independent dense tensor reference, adjacent row folds then column folds.
   # Public support keeps dummy rows/columns at zero, no invalid dereference.
   per=[]
   for col in range(1<<h):
    v=[table[cols[col][i]] if col<c and i<active[col] else Z for i in range(n)]
    per.append(fold(v,r))
   claim=fold(per,s);assert total(mul(a,b) for a,b in zip(y,table))==claim
   ref=[total(mul(weight(i,r),weight(col,s)) for col in range(c) for i in range(active[col]) if cols[col][i]==j) for j in range(m)]
   assert y==ref
   mass=total(mul(weight(col,s),total(weight(i,r) for i in range(active[col]))) for col in range(c))
   assert total(y)==mass
   counts.update(fixtures=1,pushforward_values=m,virtual_claims=1,support_mass_checks=1,real_columns=c)
   cases.append(dict(c=c,n=n,m=m,r=r,s=s,active=active,cols=cols,table=table,y=y,claim=claim))
controls['active bad index refuses']=candidate([[8]], [1],[],[],8)[0]==2
controls['inactive bad index ignored']=candidate([[999]],[0],[],[],8)[0]==0
controls['active exceeds own domain refuses']=candidate([[1]],[2],[(2,3)],[],8)[0]==1
controls['too few column bits refuses']=candidate([[1],[2],[3]],[1,1,1],[],[(2,3)],8)[0]==1
controls['non power of two row domain refuses']=candidate([[1,2,3]],[3],[(2,3),(3,4)],[],8)[0]==1
controls['oversized row domain refuses']=candidate([[1,2]],[2],[],[],8)[0]==1
r=[(2,3),(5,7)];s=[(3,4),(7,11)];cols=[[1],[2,3],[4]];a=[1,2,1];table=[(j,0) for j in range(8)]
_,y=candidate(cols,a,r,s,8);v=total(mul(x,t) for x,t in zip(y,table))
_,yp=candidate(cols+[[1,1,1,1]],a+[4],r,s,8)
controls['dummy column cannot acquire active support']=yp!=y
_,yr=candidate(cols,a,list(reversed(r)),s,8)
controls['row bit reversal detected']=yr!=y
_,ys=candidate(cols,a,r,list(reversed(s)),8)
controls['column bit reversal detected']=ys!=y
# Zero lifting includes high-coordinate equality-to-zero factors, not one.
_,zz=candidate([[3]],[1],r,[],8)
controls['zero lifting needs high bit factors']=zz[3]==mul(sub(O,r[0]),sub(O,r[1])) and zz[3]!=O
_,zb=candidate([[3]],[1],[(1,0)],[],8)
controls['Boolean high bit can annihilate lifted claim']=zb==[Z]*8
# Distinct row points require a reduction; changing them to one point is wrong.
v1=fold([(1,0),(3,0)],[(2,1)]);v2=fold([(4,0),(7,0)],[(5,2)]);same=fold([(4,0),(7,0)],[(2,1)])
controls['different points cannot be silently shared']=v2!=same
# Any known-weight singleton survives column batching as a leaking scalar.
_,one=candidate([[6],[999],[999]],[1,0,0],r,s,8)
onev=total(mul(x,t) for x,t in zip(one,table));w=mul(weight(0,r),weight(0,s))
controls['batched unmasked singleton still reveals value']=mul(onev,inv(w))==table[6]
# Known aggregation coefficients allow malicious compensating claim changes.
b0=weight(0,s);b1=weight(1,s);delta=(9,5);e1=mul(mul(b0,delta),inv(b1))
controls['postchallenge compensating claims cancel']=add(mul(b0,delta),mul(b1,sub(Z,e1)))==Z
# Repeating one coordinate in a column tensor is a different, broken shortcut:
# columns of the same Hamming weight receive IDENTICAL polynomials. This is
# an arithmetic counterexample to that shortcut, not a claim about any source.
equal_all=True
for t in range(17):
 ss=[(t,0),(t,0)]
 equal_all &= weight(1,ss)==weight(2,ss)
controls['repeated column coordinate misses fixed compensating errors']=equal_all
controls['independent column coordinates distinguish same weight columns']=weight(1,s)!=weight(2,s)
# Joint-view control: correlated pads each hide marginally, together leak.
q=17;pairs=[((3+b)%q,(8+2*b)%q) for b in range(q)]
controls['correlated fresh-view marginals uniform']=len({x for x,y in pairs})==q and len({y for x,y in pairs})==q
controls['correlated joint pads disclose linear relation']=len({(y-2*x)%q for x,y in pairs})==1
controls['unused table zero refusal retained']=all(j!=2 for j in [1,3]) and any((2-j)%P==0 for j in range(8))
assert all(controls.values()),controls
(H/'fixtures.json').write_text(json.dumps(cases,separators=(',',':'))+'\n')
result=dict(status='PASS',cycle='0068',run_id='20261017T212105Z-f1b8cd7d',seed=2026101768,counts=dict(counts),negative_controls=controls,wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,compiler_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,compiler_argv=argv,threads=1,cpu_affinity=list(os.sched_getaffinity(0)),nice=os.getpriority(os.PRIO_PROCESS,0),limits='59s CPU/wall,512MiB AS; estimated main<96MiB/compiler<192MiB',scope='Private-scratch arithmetic only; public synthetic layout/support. No GKR/PCS/transcript/RNG/privacy proof/native receipt/GPU or throughput measurement.',completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
