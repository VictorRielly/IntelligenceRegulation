"""One-thread synthetic differential; all input is generated public fixture data."""
from pathlib import Path
import ctypes as C,datetime,hashlib,json,os,platform,random,resource,signal,subprocess,time
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
START=time.perf_counter();SEED=2026101769;rng=random.Random(SEED)
P=2**64-2**32+1;Z=(0,0);O=(1,0)
def add(a,b):return((a[0]+b[0])%P,(a[1]+b[1])%P)
def sub(a,b):return((a[0]-b[0])%P,(a[1]-b[1])%P)
def mul(a,b):return((a[0]*b[0]+7*a[1]*b[1])%P,(a[0]*b[1]+a[1]*b[0])%P)
def prod(xs):
 v=O
 for x in xs:v=mul(v,x)
 return v
def total(xs):
 v=Z
 for x in xs:v=add(v,x)
 return v
def rnd():return(rng.randrange(P),rng.randrange(P))
def weight(i,r):return prod(x if i>>(len(r)-1-j)&1 else sub(O,x) for j,x in enumerate(r))
def evaluate(v,r):return total(mul(x,weight(i,r)) for i,x in enumerate(v))
def interpolate(v,r):
 ans=Z
 for i,x in enumerate(v):
  a=O;den=1
  for j in range(len(v)):
   if i!=j:a=mul(a,sub(r,(j,0)));den=den*(i-j)%P
  ans=add(ans,mul(x,mul(a,(pow(den,-1,P),0))))
 return ans
def dense(tables,r):
 ts=[list(t) for t in tables];rounds=[]
 for x in r:
  half=len(ts[0])//2
  rounds.append([total(prod(add(t[i],mul((j,0),sub(t[i+half],t[i]))) for t in ts) for i in range(half)) for j in range(4)])
  ts=[[add(t[i],mul(x,sub(t[i+half],t[i]))) for i in range(half)] for t in ts]
 return rounds,[t[0] for t in ts]
def brute_rounds(tables,r):
 # Independent direct polynomial evaluation: no folded intermediate tables.
 k=len(r);out=[]
 for j in range(k):
  out.append([total(prod(evaluate(t,r[:j]+[(x,0)]+[(suffix>>(k-j-2-b)&1,0) for b in range(k-j-1)]) for t in tables) for suffix in range(1<<(k-j-1))) for x in range(4)])
 return out
(H/'isolated.rs').write_text((H/'field-only.rs').read_text()+(H/'ragged.rs').read_text())
(H/'tmp').mkdir(exist_ok=True)
argv=['/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/rustc','--edition=2021','--crate-type=cdylib','-C','opt-level=1','-C','codegen-units=1','isolated.rs','-o','isolated.so']
with(H/'compile.log').open('w')as f:subprocess.run(argv,cwd=H,env=dict(os.environ,TMPDIR=str(H/'tmp'),RAYON_NUM_THREADS='1',OMP_NUM_THREADS='1'),stdout=f,stderr=subprocess.STDOUT,timeout=25,check=True)
lib=C.CDLL(str(H/'isolated.so'));U=C.c_uint64;S=C.c_size_t
lib.candidate.argtypes=[C.POINTER(S),S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),C.POINTER(S)]
lib.captured_mask.argtypes=[C.POINTER(U),S,C.POINTER(U),C.POINTER(U),C.POINTER(U)]
def array(v):return(U*(2*len(v)))(*(x for a in v for x in a))
def call(pos,vals,cube,r):
 out=(U*(2*(4*len(r)+3)))();vis=(S*len(r))()
 rc=lib.candidate((S*len(pos))(*pos),len(pos),array([x for row in vals for x in row]),cube,array(r),len(r),out,vis)
 d=[(out[i],out[i+1])for i in range(0,len(out),2)]
 return rc,[d[4*j:4*j+4]for j in range(len(r))],d[4*len(r):],list(vis)
def cmask(coeff,r,c):
 k=len(r);out=(U*(2*(4*k+2)))();assert lib.captured_mask(array(coeff),k,array(r),array([c]),out)==0
 d=[(out[i],out[i+1])for i in range(0,len(out),2)]
 return [d[4*j:4*j+4]for j in range(k)],d[-2],d[-1]
def mask_eval(coeff,r):
 return add(coeff[0],add(mul(coeff[1],prod(r)),total(mul(coeff[2+3*j+e],prod([x]*(e+1))) for j,x in enumerate(r) for e in range(3))))
counts=dict(fixtures=0,round_field_values=0,terminal_values=0,brute_round_values=0,mask_field_values=0,masked_chain_checks=0)
fixtures=[];observed={}
def test_case(tag,cube,pos,vals,r,brute=False):
 ts=[[Z]*cube for _ in range(3)]
 for i,row in zip(pos,vals):
  for t,x in enumerate(row):ts[t][i]=x
 rc,s,f,vis=call(pos,vals,cube,r);assert rc==0
 ds,df=dense(ts,r);assert s==ds and f==df,(tag,s,ds)
 assert f==[evaluate(t,r)for t in ts]
 claim=total(prod(v)for v in zip(*ts));initial=claim
 for row,x in zip(s,r):assert add(row[0],row[1])==claim;claim=interpolate(row,x)
 assert claim==prod(f)
 counts['fixtures']+=1;counts['round_field_values']+=4*len(r);counts['terminal_values']+=3
 if brute:assert s==brute_rounds(ts,r);counts['brute_round_values']+=4*len(r)
 coeff=[];c=O;ms=[]
 if r:
  coeff=[rnd()for _ in range(3*len(r)+2)];c=rnd();ms,mt,mf=cmask(coeff,r,c)
  # Brute force sum of the native masking polynomial for small fixtures.
  if brute:
   br=[]
   for j in range(len(r)):
    br.append([mul(c,total(mask_eval(coeff,r[:j]+[(x,0)]+[(suffix>>(len(r)-j-2-b)&1,0)for b in range(len(r)-j-1)])for suffix in range(1<<(len(r)-j-1))))for x in range(4)])
   assert ms==br
  assert mf==mul(c,mask_eval(coeff,r))
  claim=add(initial,mt)
  for row,m,x in zip(s,ms,r):
   both=[add(a,b)for a,b in zip(row,m)];assert add(both[0],both[1])==claim;claim=interpolate(both,x);counts['masked_chain_checks']+=1
  assert claim==add(prod(f),mf);counts['mask_field_values']+=4*len(r)+2
 fixture=dict(tag=tag,cube=cube,positions=pos,values=vals,challenges=r,rounds=s,finals=f,pair_visits=vis,mask_coefficients=coeff,mask_scale=c,mask_rounds=ms)
 fixtures.append(fixture);return fixture,ts

# Both bit placements preserve their own dense relation. They are distinct layouts.
for n in [1,2,4,8,16]:
 for cols in [1,2,3,5,7,9]:
  width=1<<(cols-1).bit_length();cube=n*width;k=cube.bit_length()-1
  initial_points=[[rnd()for _ in range(n.bit_length()-1)]for _ in range(cols)]
  col_point=[rnd()for _ in range(width.bit_length()-1)]
  for layout in ['column_first','row_first']:
   pairs=[]
   for col in range(cols):
    for i in range(n):
     at=col*n+i if layout=='column_first'else i*width+col
     # Independent initial row points for every column, plus tensor column weights.
     e=mul(weight(i,initial_points[col]),weight(col,col_point))
     pairs.append((at,[e,O,rnd()]))
   pairs.sort();pos=[p[0]for p in pairs];vals=[p[1]for p in pairs]
   r=[rnd()for _ in range(k)]
   test_case(f'{layout}-N{n}-C{cols}',cube,pos,vals,r,brute=cube<=16)
   observed[(layout,n,cols)]=fixtures[-1]['pair_visits']
# Actual four group column counts, scaled row size only (not an 8B execution).
for cols in [2,47,25,9]:
 n=2;w=1<<(cols-1).bit_length();pairs=[(i*w+c,[rnd(),O,rnd()])for i in range(n)for c in range(cols)]
 test_case(f'group-count-C{cols}',n*w,[p[0]for p in pairs],[p[1]for p in pairs],[rnd()for _ in range((n*w).bit_length()-1)])
# Empty, singleton, irregular public support; retain numerical zeros structurally.
for cube in [1,2,4,8,16,32,64]:
 for mode in ['empty','single','holes','full']:
  pos=[]if mode=='empty'else([cube-1]if mode=='single'else([i for i in range(cube)if i%3!=1]if mode=='holes'else list(range(cube))))
  vals=[[rnd(),rnd(),rnd()]for _ in pos]
  test_case(f'{mode}-{cube}',cube,pos,vals,[rnd()for _ in range(cube.bit_length()-1)],brute=cube<=8)

controls={}
def control(name,value):assert value,name;controls[name]=bool(value)
control('duplicate public position refuses',call([0,0],[[O,O,O]]*2,2,[O])[0]!=0)
control('unsorted public support refuses',call([1,0],[[O,O,O]]*2,2,[O])[0]!=0)
control('out of cube support refuses',call([2],[[O,O,O]],2,[O])[0]!=0)
control('nonpower cube refuses',call([0],[[O,O,O]],3,[O])[0]!=0)
control('wrong round count refuses',call([0],[[O,O,O]],4,[O])[0]!=0)
control('zero cube refuses',call([],[],0,[])[0]!=0)
control('oversized cube refuses',call([],[],1<<21,[O]*21)[0]!=0)
cross,ts=test_case('disjoint-factor-support',2,[0,1],[[O,O,Z],[O,Z,O]],[(2,3)],brute=True)
empty=call([],[],2,[(2,3)])[1]
control('zero Boolean products do not authorize skipping factor support',cross['rounds']!=empty)
control('product MLE changes nonBoolean rounds',cross['rounds'][0][2]!=(0,0))
# Initial shape support S is not an off-cube Boolean selector; retain its terminal.
single,ts=test_case('public-selector-terminal',2,[0],[[O,O,(7,2)]],[(3,4)],brute=True)
control('dropping selector terminal changes final product',prod(single['finals'])!=mul(single['finals'][0],single['finals'][2]))
control('dropping one factor terminal changes final product',prod(single['finals'])!=mul(single['finals'][0],single['finals'][1]))
control('unmasked singleton value still disclosed',mul(single['rounds'][0][0],O)==(7,2))
control('same starting point cannot replace distinct per-column weights',weight(0,[(2,3)])!=weight(0,[(5,7)]))
control('wrong bit order changes rounds',dense([list(reversed(t))for t in ts],[(3,4)])[0]!=single['rounds'])
# Masks live over the WHOLE cube. Sparse base arithmetic must not sparse-sum g.
coeff=single['mask_coefficients'];c=single['mask_scale'];ms=single['mask_rounds']
control('dropping mask messages changes rounds',any(x!=Z for row in ms for x in row))
# N=1: full mask sum is g(0)+g(1), support {0} only would omit g(1).
control('summing mask only over active shape changes initial claim',mask_eval(coeff,[O])!=Z)
control('constant-half mask singularity not special-cased',call([0],[[O,O,O]],2,[((P+1)//2,0)])[0]==0)
control('numeric zero values preserve public visit schedule',call([0,1],[[Z,Z,Z]]*2,4,[O,O])[3]==call([0,1],[[O,O,O]]*2,4,[O,O])[3])
control('MSB column first compaction saves no pairs for C5 N16',sum(observed[('column_first',16,5)])==16*8-1)
control('MSB row first skips structural padding for C5 N16',sum(observed[('row_first',16,5)])<16*8-1)
# A coherent self-consistent replacement still requires ORIGINAL-witness binding.
mutvals=[[O,O,(8,2)]];mut=call([0],mutvals,2,[(3,4)])
control('self consistent replacement changes original ordered value',mut[0]==0 and mut[1]!=single['rounds'])
control('terminal tamper rejected by product oracle',prod([add(single['finals'][0],O)]+single['finals'][1:])!=prod(single['finals']))
(H/'fixtures.json').write_text(json.dumps(fixtures,separators=(',',':'))+'\n')
result=dict(status='PASS',cycle='0069',run_id='20261017T222105Z-d6d7aa4d',seed=SEED,counts=counts,negative_controls=controls,wall_seconds=time.perf_counter()-START,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,compiler_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,compiler_argv=argv,threads=1,cpu_affinity=list(os.sched_getaffinity(0)),nice=19,estimated_memory_mib=128,limits='59s CPU/wall per command;512MiB AS;std-only single-codegen-unit Rust',fixture_sha256=hashlib.sha256((H/'fixtures.json').read_bytes()).hexdigest(),scope='Synthetic three-factor MSB sumcheck round arithmetic and source-captured CFS polynomial; externally supplied challenges/coefficient fixtures. No Fiat-Shamir/RNG/PCS/GKR/native proof/privacy/speed reproduction.',completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'result.json').write_text(json.dumps(result,indent=2)+'\n')
(H/'environment.json').write_text(json.dumps(dict(cpu=next(x.split(':',1)[1].strip()for x in Path('/proc/cpuinfo').read_text().splitlines()if x.startswith('model name')),platform=platform.platform(),python=platform.python_version(),device='CPU only',threads=1,seed=SEED,cpu_affinity=list(os.sched_getaffinity(0))),indent=2)+'\n')
print(json.dumps(result,indent=2))
