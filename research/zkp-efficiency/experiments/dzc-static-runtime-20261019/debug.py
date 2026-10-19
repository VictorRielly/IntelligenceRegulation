import importlib.util,ctypes,json,random,resource,os,signal,time
from pathlib import Path
H=Path(__file__).resolve().parent
sp=importlib.util.spec_from_file_location('static80',H/'run.py');r=importlib.util.module_from_spec(sp);sp.loader.exec_module(r)
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
cat,native=r.load_reference();m,lk,idx,h0,na=cat();rng=random.Random(r.SEED);rf=lambda:(rng.randrange(r.P),rng.randrange(r.P))
sc=json.loads((r.PREV/'reference/public-profile-scalars.json').read_text())[0]['public_scalars']
c=[2*sc['norm_cn_a'],2*sc['norm_cn_m'],2**sc['norm_tn'],2**(sc['norm_tn']+1),2**sc['sh_ao'],2**(sc['sh_ao']-1),2**sc['sh_z'],2**(sc['sh_z']-1)]
mu=[rf() for _ in range(28)];nu=[rf(),rf()];p=r.prior.plan(m,lk,list(range(h0,59)),mu,nu,c,4,None,rf());raw=[(rf(),rf()) for _ in range(59)]
U=ctypes.c_uint64;ptr=ctypes.POINTER(U);lib=ctypes.CDLL(str(H/'libkernels.so'))
for name,d in [('baseline',False),('driven',True)]:
 want,q=r.graph(raw,p,d);vals=[]
 for n in q.ops:
  k=n['kind'];ds=[vals[j] for j in n['deps']];s=n['slot']
  if k=='load_raw':v=raw[s//2][s%2]
  elif k=='load_param':v=q.params[s]
  elif k=='load_base':v=q.bases[s]
  else:v={'add':r.add,'sub':r.sub,'mul':r.mul,'base':r.scale}[k](*ds)
  vals.append(v)
 rr=(U*236)(*(a for pair in raw for x in pair for a in x));pp=(U*(2*len(q.params)))(*(a for x in q.params for a in x));bb=(U*len(q.bases))(*q.bases);out=(U*10)()
 f=getattr(lib,name);f.argtypes=[ptr]*4;f(rr,pp,bb,out);got=[tuple(out[2*i:2*i+2]) for i in range(5)]
 print(json.dumps({'name':name,'lower_interpreter_matches':want==[vals[j] for j in q.output],'compiled_matches':want==got,'base_min':min(q.bases),'base_max':max(q.bases),'base_over_u64':[x for x in q.bases if x<0 or x>2**64-1],'want':want,'got':got,'signature':q.signature()}))
