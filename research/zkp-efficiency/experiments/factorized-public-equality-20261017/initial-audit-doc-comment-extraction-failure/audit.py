"""Independent original-table / power-basis audit. Never imports run.py."""
from pathlib import Path
import datetime,hashlib,json,os,resource,signal,time
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();P=0xffffffff00000001;zero=(0,0);one=(1,0)
def A(x,y):return((x[0]+y[0])%P,(x[1]+y[1])%P)
def N(x):return(-x[0]%P,-x[1]%P)
def M(x,y):
 c=[0,0,0]
 for i in range(2):
  for j in range(2):c[i+j]+=x[i]*y[j]
 return((c[0]+7*c[2])%P,c[1]%P)
def sumv(xs):
 s=zero
 for x in xs:s=A(s,x)
 return s
def product(xs):
 s=one
 for x in xs:s=M(s,x)
 return s
def tensor(i,r):return product(t if i>>(len(r)-1-j)&1 else A(one,N(t))for j,t in enumerate(r))
def mle(v,r):return sumv(M(x,tensor(i,r))for i,x in enumerate(v))
def conv(a,b):
 o=[zero]*(len(a)+len(b)-1)
 for i,x in enumerate(a):
  for j,y in enumerate(b):o[i+j]=A(o[i+j],M(x,y))
 return o
def peval(c,x):
 o=zero
 for a in reversed(c):o=A(a,M(x,o))
 return o
def eq(a,b):return product(A(M(x,y),M(A(one,N(x)),A(one,N(y))))for x,y in zip(a,b))
fs=json.loads((H/'fixtures.json').read_text());res=json.loads((H/'result.json').read_text());checks=0;rounds=0;directs=0
assert hashlib.sha256((H/'fixtures.json').read_bytes()).hexdigest()==res['fixture_sha256'];checks+=1
for f in fs:
 n=f['rows'];c=f['columns'];w=1<<(c-1).bit_length();k=n.bit_length()-1;l=w.bit_length()-1;cube=n*w
 vals=[tuple(x)for x in f['values']];ps=[[tuple(x)for x in p]for p in f['initial_points']];cp=[tuple(x)for x in f['column_point']];r=[tuple(x)for x in f['challenges']]
 ts=[[zero]*cube for _ in range(3)]
 for i in range(n):
  for col in range(c):ts[0][i*w+col]=M(tensor(i,ps[col]),tensor(col,cp));ts[1][i*w+col]=one;ts[2][i*w+col]=vals[col*n+i]
 # Independent off-cube terminals: mixture of DIFFERENT row points.
 et=sumv(M(M(tensor(col,cp),tensor(col,r[k:])),eq(ps[col],r[:k]))for col in range(c))
 st=sumv(tensor(col,r[k:])for col in range(c))
 vt=sumv(M(tensor(col,r[k:]),mle(vals[col*n:(col+1)*n],r[:k]))for col in range(c))
 assert[et,st,vt]==list(map(tuple,f['finals']));checks+=3
 assert[mle(t,r)for t in ts]==[et,st,vt];checks+=3
 # All rounds reconstructed from ORIGINAL tables, without table folding.
 # Boolean suffixes select one original suffix; sum over every original prefix.
 for j in range(len(r)):
  half=1<<(len(r)-j-1);co=[zero]*4
  wp=[tensor(prefix,r[:j])for prefix in range(1<<j)]
  for suffix in range(half):
   polynomial=[one]
   for t in ts:
    a=sumv(M(t[(prefix*2)*half+suffix],wt)for prefix,wt in enumerate(wp))
    b=sumv(M(t[(prefix*2+1)*half+suffix],wt)for prefix,wt in enumerate(wp))
    polynomial=conv(polynomial,[a,A(b,N(a))])
   co=[A(x,y)for x,y in zip(co,polynomial)]
  assert[peval(co,(t,0))for t in range(4)]==list(map(tuple,f['rounds'][j]));checks+=4;rounds+=1
  if cube<=16:
   for t in range(4):
    expected=sumv(product(mle(tab,r[:j]+[(t,0)]+[(suffix>>(len(r)-j-2-b)&1,0)for b in range(len(r)-j-1)])for tab in ts)for suffix in range(half))
    assert expected==tuple(f['rounds'][j][t]);checks+=1;directs+=1
 coeff=[tuple(x)for x in f['mask_coefficients']];scale=tuple(f['mask_scale'])
 if coeff:
  m=len(r);monos=[(coeff[0],[0]*m),(coeff[1],[1]*m)]
  for j in range(m):
   for e in range(1,4):
    powers=[0]*m;powers[j]=e;monos.append((coeff[2+3*j+e-1],powers))
  for j in range(m):
   for t in range(4):
    val=zero
    for a,powers in monos:
     v=a
     for i,e in enumerate(powers):v=M(v,product([r[i]]*e)if i<j else(product([(t,0)]*e)if i==j else(2 if e==0 else 1,0)))
     val=A(val,v)
    assert M(scale,val)==tuple(f['mask_rounds'][j][t]);checks+=1
 assert f['counts']==[c*(n-1),c*(n-1-k),w-1];checks+=3
 # Fixture mutation controls use this independent terminal reference.
 if cube>1 and f['tag'].startswith('new-'):
  bad=list(map(tuple,f['finals']));bad[2]=A(bad[2],one)
  assert bad!=[et,st,vt];checks+=1
assert len(res['negative_controls'])==22 and all(res['negative_controls'].values());checks+=22
s=(H/'native/sumcheck.rs').read_text();part=s[s.index('#[derive(Clone, Debug)]\npub struct CfsMask'):s.index('/// The transcript masker')]
constructor='''    pub fn random(rng: &mut crate::rng::ZkRng, n_vars: usize, degree: usize) -> CfsMask {
        CfsMask { n_vars, degree, coeffs: rng.fp2_vec(Self::len(n_vars, degree)) }
    }
'''
assert part.replace(constructor,'')==(H/'captured-mask.rs').read_text();checks+=1
field=(H/'native/field.rs').read_text().split('#[cfg(test)]')[0]
assert(H/'field-only.rs').read_text()=='#![allow(dead_code)]\nmod field {\n'+field+'\n}\n';checks+=1
out=dict(status='PASS',checks=checks,fixtures=len(fs),original_table_rounds=rounds,direct_mle_round_values=directs,method='Original-table prefix sums, power-basis polynomial convolution, independent closed-form mixtures/selector terminals and monomial integration of whole-cube CFS masks.',wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,scope='Independent local arithmetic/reference audit, not cryptographic verification.',completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
