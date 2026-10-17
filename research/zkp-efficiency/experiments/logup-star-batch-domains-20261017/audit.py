"""Independent coefficient-convolution oracle; bounded public synthetic data."""
from pathlib import Path
import json,time,resource,signal,os,hashlib,datetime,collections
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();p=18446744069414584321
# Independent integer polynomial convolution followed by x^2=7 reduction.
def plus(x,y):return tuple((a+b)%p for a,b in zip(x,y))
def times(x,y):
 a=[0,0,0]
 for i in range(2):
  for j in range(2):a[i+j]+=x[i]*y[j]
 return ((a[0]+7*a[2])%p,a[1]%p)
def basis(bits,point):
 a=(1,0)
 for pos,(x,y) in enumerate(point):
  b=(x,y) if (bits>>pos)&1 else ((1-x)%p,(-y)%p)
  a=times(a,b)
 return a
cases=json.loads((H/'fixtures.json').read_text());checks=0;values=0
for f in cases:
 expected=[(0,0)]*f['m'];claim=(0,0)
 for col in range(f['c']):
  assert len(f['cols'][col])<=f['n']
  for row in range(f['active'][col]):
   j=f['cols'][col][row]
   coeff=basis(row | col*f['n'],f['r']+f['s'])
   expected[j]=plus(expected[j],coeff)
   claim=plus(claim,times(coeff,f['table'][j]))
 assert expected==[tuple(z) for z in f['y']]
 assert claim==tuple(f['claim']);checks+=len(expected)+1;values+=len(expected)
# Independent symbolic univariate coefficients of the column equality weights.
def convolution(a,b):
 z=[0]*(len(a)+len(b)-1)
 for i,x in enumerate(a):
  for j,y in enumerate(b):z[i+j]+=x*y
 return tuple(z)
def diagonal_polynomial(i,h):
 a=(1,)
 for k in range(h):a=convolution(a,(0,1) if (i>>k)&1 else (1,-1))
 return a
polys=[diagonal_polynomial(i,7) for i in range(83)]
classes=len(set(polys));assert classes==7
assert polys[1]==polys[2] and 83-classes==76
checks+=3
mat=[[v%p for v in row] for row in sorted(set(polys))];rank=0
for col in range(8):
 pivot=next((i for i in range(rank,len(mat)) if mat[i][col]),None)
 if pivot is None:continue
 mat[rank],mat[pivot]=mat[pivot],mat[rank];scale=pow(mat[rank][col],-1,p)
 mat[rank]=[x*scale%p for x in mat[rank]]
 for i in range(len(mat)):
  if i!=rank:
   scale=mat[i][col];mat[i]=[(x-scale*y)%p for x,y in zip(mat[i],mat[rank])]
 rank+=1
assert rank==7;checks+=1
# Exhaustive finite-field distinction: independent coordinates detect e1=-e2
# on 17^2-17 points. On diagonal they NEVER detect it, even when fixed early.
hits=sum((x*(1-y)-(1-x)*y)%17!=0 for x in range(17) for y in range(17))
assert hits==272;checks+=289
f=next(x for x in cases if x['c']==83 and x['n']==32 and any(x['active']))
reference=tuple(f['claim']);y=[tuple(v) for v in f['y']]
j=next(i for i,t in enumerate(f['table']) if tuple(t)!=(0,0))
mut=list(y);mut[j]=plus(mut[j],(1,0))
value=(0,0)
for a,b in zip(mut,f['table']):value=plus(value,times(a,b))
assert value!=reference;checks+=1
drift=[]
for pin in json.loads((H/'native-pins.json').read_text()):
 if hashlib.sha256((H/pin['capture']).read_bytes()).hexdigest()!=pin['sha256']:drift.append(pin['capture'])
assert not drift
main=json.loads((H/'result.json').read_text());assert values==main['counts']['pushforward_values'] and len(cases)==main['counts']['fixtures'];checks+=2
out=dict(status='PASS',checks=checks,fixtures=len(cases),pushforward_values=values,diagonal_column_weight_polynomials=classes,diagonal_coefficient_matrix_rank=rank,undetectable_fixed_error_subspace_dimension=83-rank,independent_F17_grid_detects=hits,independent_F17_grid_total=289,source_drift=drift,negative_controls={'mutated_pushforward_detected':True,'same_scalar_all_column_bits_loses_fixed_errors':True},wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,scope='Coefficient convolution, symbolic column-weight collision and exhaustive F17 diagnostic only; no native/upstream protocol attack or cryptographic soundness/privacy proof.',completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
