"""Bounded differential arithmetic experiment. No native proof or GPU job."""
from reference import *
(H/'tmp').mkdir(exist_ok=True)
(H/'isolated.rs').write_text(''.join((H/x).read_text() for x in ['field-only.rs','ragged.rs','factorized.rs','pending.rs']))
argv=['/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/rustc','--edition=2021','--crate-type=cdylib','-C','opt-level=1','-C','codegen-units=1','isolated.rs','-o','isolated.so']
with (H/'compile.log').open('w') as log:
 subprocess.run(argv,cwd=H,env=dict(os.environ,TMPDIR=str(H/'tmp'),RAYON_NUM_THREADS='1',OMP_NUM_THREADS='1'),stdout=log,stderr=subprocess.STDOUT,check=True,timeout=25)
lib=C.CDLL(str(H/'isolated.so'));U=C.c_uint64;S=C.c_size_t
for name in ['pending','factorized']:
 getattr(lib,name).argtypes=[S,S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),S,C.POINTER(U),C.POINTER(S)]
lib.captured_mask.argtypes=[C.POINTER(U),S,C.POINTER(U),C.POINTER(U),C.POINTER(U)]
def array(v):return(U*(2*len(v)))(*(x for a in v for x in a))
def unpack(out):return[(out[i],out[i+1])for i in range(0,len(out),2)]
def call(n,c,v,ps,cp,r,name='pending'):
 out=(U*(2*(4*len(r)+3)))();counts=(S*4)();pv=[x for p in ps for x in p]
 rc=getattr(lib,name)(n,c,array(v),len(v),array(pv),len(pv),array(cp),len(cp),array(r),len(r),out,counts)
 d=unpack(out);return rc,[d[4*j:4*j+4]for j in range(len(r))],d[4*len(r):],list(counts)
def cmask(coeff,r,scale):
 out=(U*(2*(4*len(r)+2)))();assert lib.captured_mask(array(coeff),len(r),array(r),array([scale]),out)==0
 d=unpack(out);return[d[4*j:4*j+4]for j in range(len(r))],d[-2],d[-1]
fixtures=[];counts=dict(fixtures=0,prior_fixtures=0,round_values=0,terminal_values=0,masked_chain_rounds=0,causality_unchanged_rounds=0,causality_sensitive_cases=0);controls={}
def control(name,x):assert x,name;controls[name]=bool(x)
def test(tag,n,c,v,ps,cp,r,prior=None):
 k=n.bit_length()-1;w=1<<(c-1).bit_length();ts=[[Z]*(n*w)for _ in range(3)]
 for row in range(n):
  for col in range(c):
   at=row*w+col;ts[0][at]=mul(weight(row,ps[col]),weight(col,cp));ts[1][at]=O;ts[2][at]=v[col*n+row]
 rc,rs,fs,traffic=call(n,c,v,ps,cp,r);assert rc==0,(tag,rc)
 old=call(n,c,v,ps,cp,r,'factorized');ds,df=dense(ts,r)
 assert (rs,fs)==(old[1],old[2])==(ds,df),tag
 expected=[c*(3*n-2)if n>1 else 0,c*(n-1),c*(n-1-k),c*(n-1)]
 assert traffic==expected,(tag,traffic,expected)
 if prior:
  assert rs==[list(map(tuple,x))for x in prior['rounds']] and fs==list(map(tuple,prior['finals']));counts['prior_fixtures']+=1
 coeff=[rnd()for _ in range(3*len(r)+2)]if r else[];scale=rnd();mr=[];mt=mf=Z
 initial=total(prod(x)for x in zip(*ts));claim=initial
 for row,x in zip(rs,r):assert add(row[0],row[1])==claim;claim=interpolate(row,x)
 assert claim==prod(fs)
 if r:
  mr,mt,mf=cmask(coeff,r,scale);claim=add(initial,mt)
  for row,m,x in zip(rs,mr,r):
   both=[add(a,b)for a,b in zip(row,m)];assert add(both[0],both[1])==claim;claim=interpolate(both,x);counts['masked_chain_rounds']+=1
  assert claim==add(prod(fs),mf)
 # Change r[j] and every later challenge: message j and all earlier ones stay fixed.
 for j in range(len(r)):
  changed=r[:j]+[add(x,(17,3))for x in r[j:]]
  alt=call(n,c,v,ps,cp,changed);assert alt[1][:j+1]==rs[:j+1];counts['causality_unchanged_rounds']+=j+1
  if alt[2]!=fs:counts['causality_sensitive_cases']+=1
 f=dict(tag=tag,rows=n,columns=c,values=v,initial_points=ps,column_point=cp,challenges=r,rounds=rs,finals=fs,traffic=traffic,counts=old[3][:3],mask_coefficients=coeff,mask_scale=scale,mask_rounds=mr,mask_total=mt,mask_final=mf,initial_claim=initial)
 fixtures.append(f);counts['fixtures']+=1;counts['round_values']+=4*len(r);counts['terminal_values']+=3
 return f
for f in json.loads((H/'prior-fixtures.json').read_text()):
 test('prior-'+f['tag'],f['rows'],f['columns'],list(map(tuple,f['values'])),[[tuple(x)for x in p]for p in f['initial_points']],list(map(tuple,f['column_point'])),list(map(tuple,f['challenges'])),f)
for n in [1,2,4,8,16,64]:
 for c in [1,3,5,9,25,47,83]:
  k=n.bit_length()-1;l=(c-1).bit_length()
  test(f'new-N{n}-C{c}',n,c,[rnd()for _ in range(n*c)],[[rnd()for _ in range(k)]for _ in range(c)],[rnd()for _ in range(l)],[rnd()for _ in range(k+l)])
for x in [Z,O,((P+1)//2,0),(P-1,0),(0,1)]:
 test('special-'+str(x),8,5,[rnd()for _ in range(40)],[[x]*3 for _ in range(5)],[x]*3,[x]*6)
f=test('controls-N4-C3',4,3,[rnd()for _ in range(12)],[[rnd(),rnd()]for _ in range(3)],[rnd(),rnd()],[rnd()for _ in range(4)])
n=4;c=3;v=f['values'];ps=f['initial_points'];cp=f['column_point'];r=f['challenges']
for name,args in [
 ('zero rows',(0,c,[],ps,cp,r)),('nonpower rows',(3,c,v,ps,cp,r)),('zero columns',(n,0,[],[],[],[])),
 ('oversized rows',(1<<16,c,[],[],[],[])),('too many columns',(n,129,[],[],[],[])),
 ('wrong value count',(n,c,v[:-1],ps,cp,r)),('wrong point count',(n,c,v,ps[:-1],cp,r)),
 ('wrong column point',(n,c,v,ps,cp[:-1],r)),('wrong challenge count',(n,c,v,ps,cp,r[:-1]))]:control(name+' refuses',call(*args)[0]!=0)
control('eight lifecycle refusal/idempotence checks',lib.lifecycle_controls()==8)
control('current challenge unavailable to own message',counts['causality_unchanged_rounds']>1000)
control('challenge mutation does change final state',counts['causality_sensitive_cases']>100)
zero=call(n,c,[Z]*len(v),ps,cp,r)
control('private numeric zeros preserve traffic',zero[3]==f['traffic'])
control('zero values retain public E/S terminals',zero[2][:2]==f['finals'][:2])
control('distinct column points cannot be shared',call(n,c,v,[ps[0]]*c,cp,r)[1]!=f['rounds'])
control('column terminal selector cannot be one',prod(f['finals'])!=mul(f['finals'][0],f['finals'][2]))
control('all whole-cube cubic mask samples retained',any(add(sub(row[3],mul((3,0),row[2])),sub(mul((3,0),row[1]),row[0]))!=Z for row in f['mask_rounds'][:2]))
control('omitted last pending fold changes terminal',call(2,1,[(2,1),(9,3)],[[rnd()]],[],[(3,1)])[2][2]!=(2,1))
control('row reversal changes transcript arithmetic',call(n,c,[v[col*n+int(f'{row:02b}'[::-1],2)]for col in range(c)for row in range(n)],ps,cp,r)[1]!=f['rounds'])
mut=v[:];mut[0]=add(mut[0],O)
control('self consistent replacement still needs original witness binding',call(n,c,mut,ps,cp,r)[1]!=f['rounds'])
control('raw singleton remains revealing',call(1,1,[(7,2)],[[]],[],[])[2][2]==(7,2))
control('N2 read saving is zero',call(2,1,[O,O],[[O]],[],[O])[3][0]==4)
control('column-only has no row traffic',call(1,c,v[:c],[[]for _ in range(c)],cp,r[:2])[3]==[0,0,0,0])
(H/'fixtures.json').write_text(json.dumps(fixtures,separators=(',',':'))+'\n')
result=dict(status='PASS',cycle='0071',run_id='20261018T002105Z-32d7e4fc',seed=SEED,counts=counts,negative_controls=controls,wall_seconds=time.perf_counter()-START,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,compiler_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,compiler_argv=argv,fixture_sha256=hashlib.sha256((H/'fixtures.json').read_bytes()).hexdigest(),threads=1,cpu_affinity=list(os.sched_getaffinity(0)),limits='59s CPU/wall,512MiB AS,single codegen unit',scope='Synthetic public-shape E*S*V arithmetic, not a lookup proof/native proof/privacy theorem/GPU or speed result.',completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'result.json').write_text(json.dumps(result,indent=2)+'\n')
(H/'environment.json').write_text(json.dumps(dict(cpu=next(x.split(':',1)[1].strip()for x in Path('/proc/cpuinfo').read_text().splitlines()if x.startswith('model name')),platform=platform.platform(),python=platform.python_version(),device='CPU only',threads=1,seed=SEED),indent=2)+'\n')
print(json.dumps(result,indent=2))
