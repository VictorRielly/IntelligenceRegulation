"""Independent interval oracle, native metadata differential and tiny allocations."""
from pathlib import Path
import json,subprocess,time,random,hashlib,platform,os
from envelope import constructor,proof_phases,reserve
D=Path(__file__).resolve().parent;SEED=20261030164
checks=0;controls=0
def check(b,msg='check'):
 global checks
 checks+=1
 if not b:raise AssertionError(msg)
def dump(n,x):(D/n).write_text(json.dumps(x,indent=2)+'\n')
def l2(x):return (x-1).bit_length()
def oracle_meta(v):
 t,w,f,h,dh,kv,lc,dd,nw,sw,low=v;n=1<<lc;tp=1<<l2(t);hp=1<<l2(h)
 natural={'T':tp,'Ht':hp*tp,'L':16*tp,'D':tp*(1<<l2(w)),'Q':tp*hp*dh,'Kv':tp*kv*dh,'S':hp*tp*tp,'F':tp*(1<<l2(f)),'Tab':256,'Dd':hp*tp*max(1,dd)}
 size={d:s if d in ['T','Ht'] else max(n,1<<l2(s)) for d,s in natural.items()}
 true={'T':t,'Ht':h*t,'L':9*t,'D':t*w,'Q':t*h*dh,'Kv':t*kv*dh,'S':h*t*t,'F':t*f,'Tab':256,'Dd':h*t*max(dd,1)}
 ln=(nw+7)//8;ls=(sw+7)//8
 look={'L':2,'D':14+2*(2+2*(ln+int(nw!=8*ln))),'Q':13,'Kv':12,'S':4 if dd else 4+3+2*(ls+1),'F':9}
 if dd:look['Dd']=3+2*(ls+1)
 if low:
  look.update(D=34,Q=14,Kv=14,F=14,S=6 if dd else 11+2*ls)
  if dd:look['Dd']=5+2*ls
 looked=sum(count*size[d] for d,count in look.items())
 # Independent per-slot declaration, in physical order; no Rust text parsed.
 desc=[('D',3),('D',3),('T',3),('L',4),('S',3),('innerD',2),('innerD',2),('innerD',2),('innerScore',2),('innerPV',2),('innerQ',2),('innerD',2),('innerD',2),('innerF',2),('D',4),('Q',4),('Kv',4),('S',4),('F',4),('Tab',3),('Tab',2),('D',2),('D',2)]
 if dd:desc.append(('Dd',4))
 indicator={0,1,4,14,15,16,17,18};coeffs=0
 for i,(d,degree) in enumerate(desc):
  main={'innerD':l2(w),'innerScore':l2(kv)+l2(dh),'innerPV':l2(kv)+l2(tp),'innerQ':l2(hp*dh),'innerF':l2(f)}.get(d)
  if main is None:main=l2(size[d])
  degree+=int(i in indicator and size[d]!=true[d])
  degree+=int(i in [8,9] and kv>1)
  coeffs+=(main+(2 if i in [8,9] else 1))*degree+2
 return [looked,size['S'],size['F'],2*len(desc)+4,coeffs,len(desc)]
def alloc_reference(r,n,q,stage):
 # List of independent live intervals at each observation. This does not
 # call constructor() or reuse its phase dictionary to compute expectations.
 nn=4*n
 life=[(8*r*n,0,8),(8*r*q,1,8),(32*nn,1,8),(8*nn,1,7),
       (8*r*nn,2,8),(8*n,2,2),(32*nn,4,7),(8*r*min(64,nn),4,4),
       (32*nn,6,6),((2*nn-1)*32,7,8)]
 return sum(b for b,first,last in life if first<=stage<=last)
def main():
 global controls
 start=time.monotonic();geo=json.loads((D/'geometry.json').read_text());rng=random.Random(SEED)
 inp=''.join(c['id']+' '+' '.join(map(str,c['v']))+'\n' for c in geo);(D/'probe-input.txt').write_text(inp)
 p=subprocess.run([str(D/'probe')],input=inp,text=True,capture_output=True,timeout=10)
 (D/'probe-stdout.log').write_text(p.stdout);(D/'probe-stderr.log').write_text(p.stderr);check(p.returncode==0,p.stderr)
 meta={};obs={}
 for line in p.stdout.splitlines():
  s=line.split()
  if s[0]=='M':meta[s[1]]=list(map(int,s[2:]))
  if s[0]=='A':
   r,n,q,st,live,overhead,peak=map(int,s[1:]);obs.setdefault((r,n,q),[]).append((st,live,overhead,peak))
 check(len(meta)==216);check(len(obs)==24)
 for c in geo:
  want=oracle_meta(c['v']);got=meta[c['id']]
  for x,y in zip(got,want):check(x==y,(c['id'],got,want))
 small=[]
 for (r,n,q),rows in obs.items():
  for st,live,overhead,peak in rows:
   check(live-overhead==alloc_reference(r,n,q,st),(r,n,q,st,live,overhead,alloc_reference(r,n,q,st)))
  model=constructor(r,n,q);check(model['resident']==rows[8][1]-rows[8][2]);check(rows[-1][1]==0)
  # Actual requested-byte peak includes Vec headers and transient old header
  # during reserve growth; allocator RSS/realloc-copy overlap is not observed.
  check(rows[0][3]>=model['peak']);check(rows[0][3]<=model['peak']+4096)
  small.append(dict(rows=r,n=n,q=q,model_payload_peak=model['peak'],observed_requested_peak=rows[0][3],resident_payload=model['resident']))
  # Dropping pows/leaves at return is observable, but the owner remains.
  check(rows[7][1]-rows[8][1]==(4*n)*(8+32))
 projections=[]
 for c in geo:
  for workers in [1,8,16]:
   e=proof_phases(c,meta[c['id']],workers)
   # Separate flattened component oracle for returned PCS owner bytes.
   n=1<<c['v'][6]
   for role,ri in [('A',0),('H',1)]:
    r=c['metadata'][ri];ref=8*r*n+8*r*n*4+8*r*256+32*4*n+(2*4*n-1)*32
    check(e[role]['resident']==ref)
   # At M hash the future salted tree is absent. The independent expression
   # counts source-live encoded/coefficient/acoef/b/u/salts/pows/leaf buffers.
   looked,scores,acts,mrows,coeffs,slots=meta[c['id']]
   transient=8*(looked+scores+(0 if c['v'][10] else acts))
   mr=8*mrows*4096+16*coeffs+8*(2*slots*512+4*1024)+32*4096
   expected=2*constructor(e['endpoint_rows'],n)['resident']+e['A']['resident']+mr+8*4096+32*4096+min(workers,64)*64*mrows*8+transient
   check(e['phases']['M_hash']['known_bytes']==expected)
   check(reserve(e['max_known_payload'],{'witness':None,'backend':None}) is None)
   projections.append(e)
 selected=next(x for x in projections if x['id']=='g79' and x['workers_model_only']==1)
 # Capacity-negative: two constructors simultaneously own private PCS data,
 # their temporary leaves and powers. Final-owner-only budgeting is too low.
 c=selected['H'];single=c['peak'];resident=c['resident'];budget=2*resident
 check(2*single>budget);controls+=1
 counter=dict(scope='symbolic two H constructors only; no proof schedule',final_owner_budget=budget,simultaneous_constructor_peak=2*single,excess_bytes=2*(single-resident),staggered_one_constructor_plus_one_resident=single+resident,known_payload_only=True)
 # An idle pool and an error-retained owner consume space independently.
 controls_log=[]
 for _ in range(100):
  pooled=rng.randrange(1,2**20);quarantine=rng.randrange(1,2**20);known=rng.randrange(1,2**24)
  total=reserve(known,{'idle':pooled,'quarantine':quarantine});check(total==known+pooled+quarantine)
  check(total>known+pooled);check(reserve(known,{'idle':pooled,'quarantine':None}) is None);controls+=2
  if len(controls_log)<4:controls_log.append(dict(known=known,idle=pooled,quarantine=quarantine,total=total))
 # Mutation negatives are independently recomputed, not expected identities.
 for r,n,q in obs:
  owner=constructor(r,n,q);wrong=owner['resident']-r*q*8
  check(wrong!=alloc_reference(r,n,q,8));controls+=1
  wrongtree=owner['resident']-(4*n-1)*32
  check(wrongtree!=alloc_reference(r,n,q,8));controls+=1
 dump('allocation-observations.json',small);dump('phase-projections.json',projections);dump('counterexample.json',counter);dump('reserve-controls.json',controls_log)
 dump('hardware.json',dict(cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),platform=platform.platform(),affinity=list(os.sched_getaffinity(0)),gpu_used=False))
 result=dict(status='PASS',seed=SEED,metadata_cases=len(geo),metadata_comparisons=len(geo)*6,allocation_skeleton_cases=len(obs),allocation_snapshots=len(obs)*10,phase_projections=len(projections),checks=checks,negative_controls=controls,selected=selected,counterexample=counter,wall_s=time.monotonic()-start,native_constructors=False,native_prover=False,gpu=False,full_stack_proofs=0,proved_positions=0)
 dump('result.json',result);print(json.dumps({k:v for k,v in result.items() if k not in ['selected','counterexample']}));print(json.dumps({'selected_phase_bytes':selected['phases'],'counterexample':counter}))
if __name__=='__main__':main()
