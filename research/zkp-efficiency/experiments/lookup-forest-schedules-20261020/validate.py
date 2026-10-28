"""Independent tiny topology/cost oracle, source pins and mutation controls."""
from pathlib import Path
import json,hashlib,time,resource,random,copy
from schedule import plan,serve
from reference import enumerate_cost,layers,direct
HERE=Path(__file__).resolve().parent;start=time.monotonic();checks=0;mutations=0;cases=0
def check(x):
 global checks
 assert x
 checks+=1
pins=json.loads((HERE/'source-manifest.json').read_text())
for r in pins:
 for p in [Path(r['path']),HERE/r['snapshot']]:check(hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256'])
pin=json.loads((HERE/'input-pin.json').read_text());check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
rng=random.Random(20261020104);p=65537
for i in range(30):
 sizes=[2**rng.randrange(0,9) for j in range(rng.randrange(1,7))]
 for b in range(10):
  got=plan(sizes,b);want=enumerate_cost(sizes,b)
  for key,v in want.items():
   check(got[key]==v)
   changed=dict(got);changed[key]+=1
   check(any(changed[k]!=v for k,v in want.items()));mutations+=1
  # Actual tiny tree layers give the persistent top-cache count independently.
  retained=0;service=[]
  for n in sizes:
   leaves=[(rng.randrange(p),rng.randrange(1,p)) for j in range(n)]
   all_layers=layers(leaves,p);h=len(all_layers)-1;cut=min(b,h)
   retained+=sum(len(v) for v in all_layers[:cut+1])
   root,out,work=serve(leaves.__getitem__,n,b,p)
   check(out==all_layers[1:]);check(root==all_layers[0][0])
   for v in all_layers[cut+1:]:service.append(len(v))
   cases+=1
  retained+=len(sizes)-1
  check(retained==got['retained_nodes'])
  check(32*(retained+max(service+[0]))<=got['arithmetic_peak_upper_bytes'])
# Mixed-height trees, with ONE table: direct inverse sum is independent.
for i in range(30):
 columns=[[(rng.randrange(1,4),rng.randrange(1,p)) for j in range(2**rng.randrange(0,5))] for k in range(5)]
 roots=[layers(v,p)[0][0] for v in columns]
 # The join's concrete non-power-of-two topology uses carry-up, no new leaves.
 while len(roots)>1:
  nxt=[]
  for j in range(0,len(roots),2):
   if j+1==len(roots):nxt.append(roots[j]);continue
   a,b=roots[j];c,d=roots[j+1];nxt.append(((a*d+c*b)%p,b*d%p))
  roots=nxt
 a,b=roots[0];check(a*pow(b,-1,p)%p==sum(direct(v,p) for v in columns)%p)
result=dict(status='PASS',checks=checks,cost_mutation_controls=mutations,
 tiny_column_services=cases,mixed_height_root_checks=30,source_pins=len(pins),
 elapsed_s=time.monotonic()-start,maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 scope='Independent small topology/lifetime and direct-inverse arithmetic, altered cost rejection, unchanged native-source pins. Not native protocol validation.')
(HERE/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
