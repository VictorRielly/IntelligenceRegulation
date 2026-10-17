"""Independent retained-artifact audit, no import of the generating harness."""
from pathlib import Path
import datetime,hashlib,json,os,resource,signal,time
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();P=0xffffffff00000001;zero=(0,0);one=(1,0)
def A(x,y):return((x[0]+y[0])%P,(x[1]+y[1])%P)
def N(x):return(-x[0]%P,-x[1]%P)
def M(x,y):
 # Polynomial convolution over u, reduced by u^2=7.
 coeff=[0,0,0]
 for i in range(2):
  for j in range(2):coeff[i+j]+=x[i]*y[j]
 return((coeff[0]+7*coeff[2])%P,coeff[1]%P)
def sumv(v):
 s=zero
 for x in v:s=A(s,x)
 return s
def product(v):
 s=one
 for x in v:s=M(s,x)
 return s
def evalpoly(c,x):
 s=zero
 for v in reversed(c):s=A(v,M(x,s))
 return s
def conv(a,b):
 out=[zero]*(len(a)+len(b)-1)
 for i,x in enumerate(a):
  for j,y in enumerate(b):out[i+j]=A(out[i+j],M(x,y))
 return out
def mle(v,r):
 ans=zero
 for i,x in enumerate(v):
  factors=[t if i>>(len(r)-1-j)&1 else A(one,N(t))for j,t in enumerate(r)]
  ans=A(ans,M(x,product(factors)))
 return ans
checks=0;fixtures=json.loads((H/'fixtures.json').read_text());result=json.loads((H/'result.json').read_text())
assert result['fixture_sha256']==hashlib.sha256((H/'fixtures.json').read_bytes()).hexdigest();checks+=1
for f in fixtures:
 n=f['cube'];pos=f['positions'];values=f['values'];r=[tuple(x)for x in f['challenges']]
 ts=[[zero]*n for _ in range(3)]
 for i,vs in zip(pos,values):
  for j,x in enumerate(vs):ts[j][i]=tuple(x)
 originals=[t[:]for t in ts];support=set(pos)
 for j,x in enumerate(r):
  half=len(ts[0])//2;co=[zero]*4
  for i in range(half):
   p=[one]
   for t in ts:p=conv(p,[t[i],A(t[i+half],N(t[i]))])
   co=[A(a,b)for a,b in zip(co,p)]
  for a in range(4):assert evalpoly(co,(a,0))==tuple(f['rounds'][j][a]);checks+=1
  projected={i%half for i in support};assert len(projected)==f['pair_visits'][j];checks+=1
  support=projected;ts=[[A(t[i],M(x,A(t[i+half],N(t[i]))))for i in range(half)]for t in ts]
 for j,t in enumerate(originals):assert mle(t,r)==tuple(f['finals'][j]);checks+=1
 # Independent monomial integration of the captured mask, not its round formula.
 coeff=[tuple(x)for x in f['mask_coefficients']];scale=tuple(f['mask_scale'])
 if coeff:
  k=len(r);monomials=[(coeff[0],[0]*k),(coeff[1],[1]*k)]
  for j in range(k):
   for e in range(1,4):
    powers=[0]*k;powers[j]=e;monomials.append((coeff[2+3*j+e-1],powers))
  for j in range(k):
   for a in range(4):
    val=zero
    for c,powers in monomials:
     z=c
     for i,e in enumerate(powers):
      if i<j:z=M(z,product([r[i]]*e))
      elif i==j:z=M(z,product([(a,0)]*e))
      else:z=M(z,(2 if e==0 else 1,0))
     val=A(val,z)
    assert M(scale,val)==tuple(f['mask_rounds'][j][a]);checks+=1
# Check exact source extraction. Only the unused RNG constructor was omitted.
s=(H/'native/sumcheck.rs').read_text();part=s[s.index('#[derive(Clone, Debug)]\npub struct CfsMask'):s.index('/// The transcript masker')]
constructor='''    pub fn random(rng: &mut crate::rng::ZkRng, n_vars: usize, degree: usize) -> CfsMask {
        CfsMask { n_vars, degree, coeffs: rng.fp2_vec(Self::len(n_vars, degree)) }
    }
'''
assert part.replace(constructor,'')==(H/'captured-mask.rs').read_text();checks+=1
# Existing negative controls must all have fired, no skip-success flags.
assert len(result['negative_controls'])==22 and all(result['negative_controls'].values());checks+=22
out=dict(status='PASS',checks=checks,fixtures=len(fixtures),method='Polynomial-convolution round coefficients; direct tensor MLE; monomial mask integration; public support projection; captured-source extraction equality.',wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,scope='Independent local arithmetic audit only; no cryptographic verification or full-stack proof.',completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
