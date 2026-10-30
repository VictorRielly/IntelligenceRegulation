import os, resource, signal, time, json, hashlib, random, platform, sys
from pathlib import Path
from dataclasses import replace, asdict

os.nice(19)
os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_CPU,(40,40))
resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2))
signal.alarm(45)
from model import Shape, ORDER, axis, validate, CheckedWeights, table_fixture, support_key
import reference

start=time.monotonic(); seed=202610290133; rng=random.Random(seed)
checks=0; negative=0; fixtures=0; mutations=0; counterexamples=[]

def check(ok, label, neg=False):
    global checks, negative
    checks+=1
    if neg: negative+=1
    assert ok,label

shapes=[Shape(4,4,2,1,2,4,4,2),Shape(3,3,2,1,2,4,4,2),
        Shape(6,5,3,1,2,8,8,4),Shape(6,5,6,2,2,8,8,8),
        Shape(8,6,4,2,2,8,8,4),Shape(4,5,2,1,4,4,8,2),
        Shape(5,7,3,1,4,8,8,4),Shape(6,5,6,2,2,8,8,8,tokens=4)]
rows=[]
for sh in shapes:
  for style in ['random','ones','edge','zero']:
    words={}
    for r in ORDER:
      a,b=axis(sh,r); out=bytearray(len(a)*len(b))
      for o,ok in enumerate(a):
        for i,ik in enumerate(b):
          if ok and ik:
            out[o*len(b)+i]=rng.randrange(1,256) if style=='random' else {'ones':1,'edge':128,'zero':0}.get(style,1)
      words[r]=out
    t=table_fixture(sh); e,base=validate(sh,words,t)
    check(e==reference.validate(sh,words,t)==None,'honest reference')
    obj=CheckedWeights(sh,words,t); e,cost=obj.check(sh,t)
    check(e is None and cost['support_reads']==0 and cost['cache_hits']==9,'same support fast path')
    check(reference.validate(sh,obj.words(),t) is None,'snapshot oracle')
    fixtures+=1
    # Changing tokens alone changes table lengths; it must not waive that check.
    for new_sh in [replace(sh,tokens=sh.tokens+1),replace(sh,f_e=sh.f_e+1),replace(sh,dd_cap=2),
                   replace(sh,width=max(1,sh.width-1)),replace(sh,hidden=max(1,sh.hidden-1))]:
      for nt in [t,table_fixture(new_sh)]:
        ce,_=obj.check(new_sh,nt)
        check(ce==reference.validate(new_sh,obj.words(),nt),'changed shape/table differential',neg=True)
    # Every single-byte mutation: copied constructor accepts exactly the oracle.
    for r in ORDER:
      for j,old in enumerate(words[r]):
        altered={k:bytes(v) for k,v in words.items()}
        w=bytearray(altered[r]);w[j]=1 if old==0 else 0;altered[r]=bytes(w)
        want=reference.validate(sh,altered,t)
        got,_=validate(sh,altered,t)
        check(got==want,'every-byte baseline differential',neg=want is not None)
        try:
          fresh=CheckedWeights(sh,altered,t); got=fresh.check(sh,t)[0]
        except ValueError as err: got=str(err)
        check(got==want,'every-byte constructor differential',neg=want is not None)
        mutations+=1
    # Preserve table/order obligations after support fast path.
    variants=[]
    for key in ['cos','sin','exp','act']:
      z=dict(t);z[key]=z[key][:-1];variants.append(z)
    for key,index,value in [('cos',0,0),('sin',0,1),('exp',0,0),('exp',1,-1),('act',128,1)]:
      z=dict(t);a=list(z[key]);a[index]=value;z[key]=tuple(a);variants.append(z)
    z=dict(t);z['exp']=tuple([256,0,1]+[0]*253);variants.append(z)
    for z in variants:
      ce,_=obj.check(sh,z);want=reference.validate(sh,obj.words(),z)
      check(ce==want,'dynamic table differential',neg=True)
    # Input mutation cannot mutate owned bytes, matching new_shaped's copy semantics.
    r='wg_t'; words[r][0] ^= 1
    check(obj.check(sh,t)[0]==reference.validate(sh,obj.words(),t),'source alias is isolated',neg=True)
    words[r][0] ^= 1
    # Shape-only/external certificate is a decisive unsafe countermodel.
    for r in ORDER:
      a,b=axis(sh,r)
      js=[o*len(b)+i for o,x in enumerate(a) for i,y in enumerate(b) if not(x and y)]
      if not js: continue
      bad=obj.words();v=bytearray(bad[r]);v[js[0]]=1;bad[r]=bytes(v)
      want=reference.validate(sh,bad,t)
      forged,_=validate(sh,bad,t,{r:support_key(sh,r) for r in ORDER})
      check(want is not None and forged is None,'external cert bypass demonstrated',neg=True)
      if len(counterexamples)<12: counterexamples.append(dict(kind='caller supplied key with changed owner/data',role=r,index=js[0],reference=want,unsafe='accept'))
    # Multiple errors must retain first attention/FFN refusal, not table-first.
    bad=obj.words();r='wg_t';a,b=axis(sh,r)
    js=[o*len(b)+i for o,x in enumerate(a) for i,y in enumerate(b) if not(x and y)]
    if js:
      v=bytearray(bad[r]);v[js[-1]]=1;bad[r]=bytes(v)
      z=dict(t);z['act']=t['act'][:-1]
      check(validate(sh,bad,z)[0]==reference.validate(sh,bad,z),'support before FFN tables',neg=True)
      z['exp']=(0,)*256
      check(validate(sh,bad,z)[0]==reference.validate(sh,bad,z),'attention before FFN support',neg=True)
    rows.append(dict(shape=asdict(sh),style=style,baseline=base,candidate=cost))

# Same lengths and same true query width do not bind head-slot support.
s1=Shape(6,5,6,2,2,8,8,8);s2=Shape(6,5,3,1,4,8,8,4)
check(len(axis(s1,'wq')[0])==len(axis(s2,'wq')[0]),'equal Q padded lengths')
check(sum(axis(s1,'wq')[0])==sum(axis(s2,'wq')[0]),'equal Q true cardinality')
check(support_key(s1,'wq')!=support_key(s2,'wq'),'head permutation key discriminates',neg=True)
for j,(x,y) in enumerate(zip(axis(s1,'wq')[0],axis(s2,'wq')[0])):
  if x and not y:
    w={r:bytes(len(axis(s1,r)[0])*len(axis(s1,r)[1])) for r in ORDER}
    v=bytearray(w['wq']);v[j*s1.d_pad]=1;w['wq']=bytes(v)
    t=table_fixture(s1);obj=CheckedWeights(s1,w,t)
    got=obj.check(s2,table_fixture(s2))[0];want=reference.validate(s2,w,table_fixture(s2))
    check(got==want and got is not None,'same length/permutation swap fallback',neg=True)
    break

native=Shape(4096,14336,32,8,128,4096,16384,32,tokens=128)
census=[]
for r in ORDER:
  a,b=axis(native,r);off=len(a)*len(b)-sum(a)*sum(b)
  census.append(dict(role=r,padded_bytes=len(a)*len(b),off_support_reads_per_honest_check=off,
                     row_visits=len(a),inner_support_metadata_tests=len(b)))
n=sum(x['off_support_reads_per_honest_check'] for x in census)
proof=dict(independently_verified_full_stack_proofs=0,passes=0,countable_positions=0,context_length=None,
           device='CPU contract checking only; no model/GPU',startup_s=None,prefill_s=None,startup_fraction=None,
           witness_s=None,proof_s=None,serialization_s=None,verification_s=None,proof_latency_s=None,proof_bytes=None,
           steady_state_positions_s=None,total_workload_positions_s=None,long_prefill='none',resident_passes='none',decode='none')
result=dict(status='PASS_SYNTHETIC_SUPPORT_CONTRACT_ONLY',seed=seed,checks=checks,negative_control_checks=negative,
            fixtures=fixtures,single_byte_mutations=mutations,rows=rows,unsafe_counterexamples=counterexamples,
            census=dict(geometry=asdict(native),roles=census,all_i8_bytes=sum(x['padded_bytes'] for x in census),
                        support_reads_per_check=n,support_reads_per_32_layers=32*n,
                        weight_payload_fraction_read=n/sum(x['padded_bytes'] for x in census),
                        repeated_checks=[dict(rechecks=c,logical_bytes_avoided_per_block=c*n,proof_positions=0) for c in [1,2,4,8]],
                        scope='logical element accesses; not DRAM traffic, critical path, native runtime incidence, memory peak or speed'),
            elapsed_s=time.monotonic()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            hardware=dict(cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
                          affinity=sorted(os.sched_getaffinity(0)),threads=1,python=sys.version,platform=platform.platform(),gpu=False),
            limits=dict(cpu_s=40,alarm_s=45,address_space_MiB=256,estimated_memory_MiB=64),proof_accounting=proof,
            hashes={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in ['model.py','reference.py','run.py']})
Path('result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['status','checks','negative_control_checks','fixtures','single_byte_mutations','elapsed_s','peak_rss_kib']}))
print(json.dumps(result['census']))
