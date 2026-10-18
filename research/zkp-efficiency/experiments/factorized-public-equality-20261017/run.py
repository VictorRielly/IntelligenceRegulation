"""Synthetic one-thread parity, not a proof benchmark. No downloaded code executed."""
from pathlib import Path
import ctypes as C,datetime,hashlib,json,os,platform,random,resource,signal,subprocess,time
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20))
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
START=time.perf_counter();SEED=2026101770;rng=random.Random(SEED)
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
def evaluate(v,r):return total(mul(x,weight(i,r))for i,x in enumerate(v))
def dense(tables,r):
 ts=[list(t)for t in tables];out=[]
 for x in r:
  half=len(ts[0])//2
  out.append([total(prod(add(t[i],mul((j,0),sub(t[i+half],t[i])))for t in ts)for i in range(half))for j in range(4)])
  ts=[[add(t[i],mul(x,sub(t[i+half],t[i])))for i in range(half)]for t in ts]
 return out,[t[0]for t in ts]
def interpolate(v,r):
 ans=Z
 for i,x in enumerate(v):
  num=O;den=1
  for j in range(len(v)):
   if i!=j:num=mul(num,sub(r,(j,0)));den=den*(i-j)%P
  ans=add(ans,mul(x,mul(num,(pow(den,-1,P),0))))
 return ans
(H/'isolated.rs').write_text((H/'field-only.rs').read_text()+(H/'ragged.rs').read_text()+(H/'factorized.rs').read_text())
(H/'tmp').mkdir(exist_ok=True)
argv=['/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/rustc','--edition=2021','--crate-type=cdylib','-C','opt-level=1','-C','codegen-units=1','isolated.rs','-o','isolated.so']
with(H/'compile.log').open('w')as f:subprocess.run(argv,cwd=H,env=dict(os.environ,TMPDIR=str(H/'tmp'),RAYON_NUM_THREADS='1',OMP_NUM_THREADS='1'),stdout=f,stderr=subprocess.STDOUT,check=True,timeout=25)
lib=C.CDLL(str(H/'isolated.so'));U=C.c_uint64;S=C.c_size_t
lib.factorized.argtypes=[S,S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),C.POINTER(S)]
lib.candidate.argtypes=[C.POINTER(S),S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),C.POINTER(S)]
lib.captured_mask.argtypes=[C.POINTER(U),S,C.POINTER(U),C.POINTER(U),C.POINTER(U)]
def array(v):return(U*(2*len(v)))(*(x for a in v for x in a))
def unpack(out):return[(out[i],out[i+1])for i in range(0,len(out),2)]
def call(n,c,v,ps,cp,r):
 out=(U*(2*(4*len(r)+3)))();counts=(S*3)();pv=[x for row in ps for x in row]
 rc=lib.factorized(n,c,array(v),len(v),array(pv),len(pv),array(cp),len(cp),array(r),len(r),out,counts)
 d=unpack(out);return rc,[d[4*j:4*j+4]for j in range(len(r))],d[4*len(r):],list(counts)
def old(pos,vals,cube,r):
 out=(U*(2*(4*len(r)+3)))();counts=(S*len(r))()
 rc=lib.candidate((S*len(pos))(*pos),len(pos),array([x for row in vals for x in row]),cube,array(r),len(r),out,counts)
 d=unpack(out);return rc,[d[4*j:4*j+4]for j in range(len(r))],d[4*len(r):],list(counts)
def cmask(coeff,r,scale):
 out=(U*(2*(4*len(r)+2)))();assert lib.captured_mask(array(coeff),len(r),array(r),array([scale]),out)==0
 d=unpack(out);return[d[4*j:4*j+4]for j in range(len(r))],d[-2],d[-1]
counts=dict(fixtures=0,prior_fixtures=0,round_field_values=0,terminal_values=0,masked_chain_rounds=0,row_degree_checks=0)
fixtures=[];controls={}
def control(name,value):assert value,name;controls[name]=bool(value)
def test(tag,n,c,v,ps,cp,r,prior=None):
 k=n.bit_length()-1;w=1<<(c-1).bit_length();cube=n*w;ts=[[Z]*cube for _ in range(3)];pos=[];vals=[]
 for row in range(n):
  for col in range(c):
   at=row*w+col;e=mul(weight(row,ps[col]),weight(col,cp));rowvals=[e,O,v[col*n+row]]
   pos.append(at);vals.append(rowvals)
   for f,x in enumerate(rowvals):ts[f][at]=x
 rc,rounds,finals,stats=call(n,c,v,ps,cp,r);assert rc==0,(tag,rc)
 ds,df=dense(ts,r);assert rounds==ds and finals==df,tag
 orc,os,of,ov=old(pos,vals,cube,r);assert orc==0 and rounds==os and finals==of
 assert sum(ov)==c*(n-1)+w-1
 assert stats==[c*(n-1),c*(n-1-k),w-1],(tag,stats)
 if prior is not None:
  assert rounds==[list(map(tuple,x))for x in prior['rounds']]
  assert finals==list(map(tuple,prior['finals']));counts['prior_fixtures']+=1
 # The row rounds are quadratic, but the column rounds can be cubic.
 for row in rounds[:k]:
  assert add(sub(row[3],mul((3,0),row[2])),sub(mul((3,0),row[1]),row[0]))==Z
  counts['row_degree_checks']+=1
 coeff=[rnd()for _ in range(3*len(r)+2)]if r else[];scale=rnd();mr=[];mt=mf=Z
 initial=total(prod(x)for x in zip(*ts));claim=initial
 for row,x in zip(rounds,r):assert add(row[0],row[1])==claim;claim=interpolate(row,x)
 assert claim==prod(finals)
 if r:
  mr,mt,mf=cmask(coeff,r,scale);claim=add(initial,mt)
  for row,m,x in zip(rounds,mr,r):
   both=[add(a,b)for a,b in zip(row,m)];assert add(both[0],both[1])==claim;claim=interpolate(both,x);counts['masked_chain_rounds']+=1
  assert claim==add(prod(finals),mf)
 f=dict(tag=tag,rows=n,columns=c,values=v,initial_points=ps,column_point=cp,challenges=r,rounds=rounds,finals=finals,counts=stats,mask_coefficients=coeff,mask_scale=scale,mask_rounds=mr,mask_total=mt,mask_final=mf,initial_claim=initial)
 fixtures.append(f);counts['fixtures']+=1;counts['round_field_values']+=4*len(r);counts['terminal_values']+=3
 return f,ts
prior=json.loads((H.parent/'ragged-logup-rounds-20261017/fixtures.json').read_text())
for f in prior:
 if f.get('layout')=='row_first':
  n=f['rows'];c=f['columns'];w=1<<(c-1).bit_length();mapping={i:v for i,v in zip(f['positions'],f['values'])}
  v=[tuple(mapping[row*w+col][2])for col in range(c)for row in range(n)]
  test('prior-'+f['tag'],n,c,v,[[tuple(x)for x in p]for p in f['initial_row_points']],[tuple(x)for x in f['column_point']],[tuple(x)for x in f['challenges']],prior=f)
for n in [1,2,4,8,16,32]:
 for c in [1,2,3,5,9,25,47,83]:
  k=n.bit_length()-1;l=(c-1).bit_length()
  ps=[[rnd()for _ in range(k)]for _ in range(c)];cp=[rnd()for _ in range(l)];r=[rnd()for _ in range(k+l)]
  test(f'new-N{n}-C{c}',n,c,[rnd()for _ in range(n*c)],ps,cp,r)
# All singular/Boolean challenges are legal: factorization must not divide.
for special in [Z,O,((P+1)//2,0),(P-1,0),(0,1)]:
 n=8;c=5;k=3;l=3
 ps=[[special]*k for _ in range(c)];cp=[special]*l;r=[special]*(k+l)
 test('special-'+str(special),n,c,[rnd()for _ in range(n*c)],ps,cp,r)
f,ts=test('controls-N4-C3',4,3,[rnd()for _ in range(12)],[[rnd(),rnd()]for _ in range(3)],[rnd(),rnd()],[rnd()for _ in range(4)])
n=4;c=3;v=list(map(tuple,f['values']));ps=f['initial_points'];cp=f['column_point'];r=f['challenges']
control('zero row domain refuses',call(0,c,[],ps,cp,r)[0]!=0)
control('nonpower row domain refuses',call(3,c,v,ps,cp,r)[0]!=0)
control('zero columns refuses',call(n,0,[],[],[],[])[0]!=0)
control('too many columns refuses',call(n,129,[],[],[],[])[0]!=0)
control('oversized row domain refuses',call(1<<16,c,[],[],[],[])[0]!=0)
control('value count mismatch refuses',call(n,c,v[:-1],ps,cp,r)[0]!=0)
control('point count mismatch refuses',call(n,c,v,ps[:-1],cp,r)[0]!=0)
control('column point mismatch refuses',call(n,c,v,ps,cp[:-1],r)[0]!=0)
control('round count mismatch refuses',call(n,c,v,ps,cp,r[:-1])[0]!=0)
control('different per column points cannot be shared',call(n,c,v,[ps[0]]*c,cp,r)[1]!=f['rounds'])
control('column weights cannot be omitted',call(n,c,v,ps,[Z]*len(cp),r)[1]!=f['rounds'])
control('column selector terminal cannot be replaced by one',prod(f['finals'])!=mul(f['finals'][0],f['finals'][2]))
control('column mixture E terminal cannot use column0 only',f['finals'][0]!=mul(weight(0,cp),prod(add(mul(sub(O,a),sub(O,b)),mul(a,b))for a,b in zip(ps[0],r[:2]))))
control('row and column challenge blocks cannot be exchanged',call(n,c,v,ps,cp,r[2:]+r[:2])[1]!=f['rounds'])
control('row bit reversal detected',call(n,c,[v[col*n+int(f'{row:02b}'[::-1],2)]for col in range(c)for row in range(n)],ps,cp,r)[1]!=f['rounds'])
control('column rounds genuinely cubic',any(add(sub(row[3],mul((3,0),row[2])),sub(mul((3,0),row[1]),row[0]))!=Z for row in f['rounds'][2:]))
zero=call(n,c,[Z]*len(v),ps,cp,r)
control('private numeric zeros do not change schedule',zero[3]==f['counts'])
control('zero private values preserve public E and S finals',zero[2][:2]==f['finals'][:2])
mut=v[:];mut[0]=add(mut[0],O)
control('coherent changed values still need original ordered witness binding',call(n,c,mut,ps,cp,r)[1]!=f['rounds'])
control('whole cube masks retained',any(x!=Z for row in f['mask_rounds']for x in row))
control('quadratic base row rounds do not make masked messages quadratic',any(add(sub(row[3],mul((3,0),row[2])),sub(mul((3,0),row[1]),row[0]))!=Z for row in f['mask_rounds'][:2]))
control('unmasked singleton still reveals value',call(1,1,[(7,2)],[[]],[],[])[2][2]==(7,2))
(H/'fixtures.json').write_text(json.dumps(fixtures,separators=(',',':'))+'\n')
result=dict(status='PASS',cycle='0070',run_id='20261017T232105Z-d713e393',seed=SEED,counts=counts,negative_controls=controls,wall_seconds=time.perf_counter()-START,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,compiler_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,compiler_argv=argv,threads=1,cpu_affinity=list(os.sched_getaffinity(0)),nice=19,estimated_memory_mib=128,limits='59s wall/CPU,512MiB AS;single codegen unit',fixture_sha256=hashlib.sha256((H/'fixtures.json').read_bytes()).hexdigest(),scope='Public synthetic rectangular E*S*V arithmetic only; no lookup protocol, Fiat-Shamir, entropy, PCS, GKR, native proof, GPU or proving speed result.',completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'result.json').write_text(json.dumps(result,indent=2)+'\n')
(H/'environment.json').write_text(json.dumps(dict(cpu=next(x.split(':',1)[1].strip()for x in Path('/proc/cpuinfo').read_text().splitlines()if x.startswith('model name')),platform=platform.platform(),python=platform.python_version(),device='CPU only',threads=1,seed=SEED,cpu_affinity=list(os.sched_getaffinity(0))),indent=2)+'\n')
print(json.dumps(result,indent=2))
