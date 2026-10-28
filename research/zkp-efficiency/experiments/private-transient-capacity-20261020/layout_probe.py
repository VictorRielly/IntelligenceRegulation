"""Mixed full/half initial FZC layout: toy fold/address oracle, not native fzc.

Packs 17 raw-source tables3..19 at HALF length. Eq/public/derived tables
keep FULL length. Canonical Fp2 Goldilocks arithmetic is deliberately not
claimed: each synthetic value is two independent residues mod101 and the
fold challenges are base scalars. Test covers ownership/offset/write/read
mechanism. No masked rounds, transcript, proof or security implementation.
"""
from pathlib import Path
import json,random,time,resource,os
import model,audit
H=Path(__file__).resolve().parent
P=101
CHECKS=0;NEG=0

def ck(x,m=''):
 global CHECKS
 CHECKS+=1
 assert x,m

def widths(kd,l,policy):
 if policy=='mixed':return [l//2 if 3<=t<=19 else l for t in range(kd)]
 if policy=='naive_half':return [l//2]*kd
 if policy=='unsafe_quarter':return [l//4 if 3<=t<=19 else l for t in range(kd)]
 raise AssertionError(policy)

def fold(a,b,r):return tuple((x+r*(y-x))%P for x,y in zip(a,b))

def direct(src,rs):
 # Independent full multilinear evaluation: explicit Boolean weights over
 # ORIGINAL source; does not reuse candidate's in-place folds.
 l=len(src);d=len(rs);m=l>>d;out=[]
 for base in range(m):
  total=[0,0]
  for b in range(1<<d):
   weight=1
   for j,r in enumerate(rs):weight=weight*(r if b&(1<<(d-1-j)) else 1-r)%P
   value=src[b*m+base]
   for c in range(2):total[c]=(total[c]+weight*value[c])%P
  out.append(tuple(total))
 return out

def run_fixture(n,supp,seed,policy='mixed',omit_derived=False,alias=False):
 rng=random.Random(seed);l=1<<n;k=20+supp;kd=k+1+supp
 src=[[(rng.randrange(P),rng.randrange(P)) for i in range(l)] for t in range(kd)]
 w=widths(kd,l,policy);offs=[];cursor=0
 for width in w:offs.append(cursor);cursor+=width
 if alias:offs[4]=offs[3]
 mem=[None]*cursor
 def store(t,i,v):
  ck(0<=i<w[t],('store bounds',t,i,w[t]))
  mem[offs[t]+i]=v
 def load(t,i):
  ck(0<=i<w[t],('load bounds',t,i,w[t]));v=mem[offs[t]+i];ck(v is not None,('uninitialized',t,i));return v
 # Constructor writes eq0..2 and support20; round0 writes derived k..kd.
 for t in list(range(3))+([20] if supp else [])+([] if omit_derived else list(range(k,kd))):
  for i,v in enumerate(src[t]):store(t,i,v)
 # A/H source rows stay separately owned; first fold reads them DIRECTLY.
 rs=[];active=l
 while active>1:
  r=rng.randrange(P);rs.append(r);half=active//2
  for t in range(kd):
   raw=3<=t<=19 and active==l
   # Permute independent output pairs: catches accidental in-place overlap.
   order=list(range(half));rng.shuffle(order)
   for i in order:
    a,b=(src[t][i],src[t][i+half]) if raw else (load(t,i),load(t,i+half))
    store(t,i,fold(a,b,r))
   got=[load(t,i) for i in range(half)];ck(got==direct(src[t],rs),('values',t,len(rs)))
  active=half
 ck(len(mem)==(2*kd-17)*l//2 if policy=='mixed' else True)
 return dict(n=n,supp=supp,l=l,kd=kd,full_entries=kd*l,mixed_entries=len(mem),saving_entries=kd*l-len(mem),folds=n,seed=seed)

def main():
 global NEG
 t=time.perf_counter();s=(H/'source/gpu__gpu__fzc_kernels.cu').read_text()
 ck('st_f2(tabs, tb + i + q, hi);' in s)
 ck('st_f2(tabs, tb + i + npairs, hi);' in s)
 ck('const int rawt = (raw && t < K0)' in s)
 cases=[]
 for n in [3,4,5,6,8]:
  for supp in [0,1]:
   for j in range(3):
    seed=model.SEED+100*n+10*supp+j
    cases.append(run_fixture(n,supp,seed))
    for policy,omit in [('naive_half',False),('unsafe_quarter',False),('mixed',True),('alias',False)]:
     try:run_fixture(n,supp,seed,'mixed' if policy=='alias' else policy,omit,alias=policy=='alias')
     except AssertionError:NEG+=1
     else:raise AssertionError('bad layout accepted')
 try:model.fzc(model.Trace(),32,1,raw=False,packed=True)
 except AssertionError:NEG+=1
 else:raise AssertionError('mixed without raw accepted')
 # Compare same partial source-order allocation schedule before/after new
 # REQUEST size. No native candidate; calls the independent interval oracle.
 baseline=json.loads((H/'traces.json').read_text());projection=[]
 for c in baseline:
  alt=model.run(c['geometry'],c['mode'],c['compact'],c['supp'],c['repetitions'],packed=True)
  audit.oracle(alt['events'])
  ck(c['fzc']['tabs_requested']-alt['fzc']['tabs_requested']==17*c['geometry']['T']*16384*8)
  ck(alt['peak_backing']<=c['peak_backing'])
  projection.append(dict(T=c['geometry']['T'],mode=c['mode'],compact=c['compact'],supp=c['supp'],repetitions=c['repetitions'],baseline_tabs=c['fzc']['tabs_requested'],mixed_tabs=alt['fzc']['tabs_requested'],baseline_peak=c['peak_backing'],mixed_peak=alt['peak_backing'],backing_saving=c['peak_backing']-alt['peak_backing'],baseline_phase=c['peak_phase'],mixed_phase=alt['peak_phase']))
 model.dump('layout-cases.json',cases);model.dump('layout-projection.json',projection)
 res=dict(status='PASS',checks=CHECKS,negative_controls=NEG,fixtures=len(cases),allocation_projections=len(projection),allocation_reference_checks=audit.CHECKS,seed=model.SEED,wall_seconds=time.perf_counter()-t,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,affinity=sorted(os.sched_getaffinity(0)),scope='Synthetic2-lane mod101/base-challenge fold+offset oracle; source constraints and partial allocator projection; no native extension-field arithmetic,masks,proof bytes,GPU fit or performance')
 model.dump('layout-result.json',res);print(json.dumps(res))
if __name__=='__main__':main()
