"""Bounded differential hashes, public plans, poisoned reuse and failures."""
from pathlib import Path
import hashlib, json, random, resource, struct, time
from blake3 import blake3
from model import Scratch, Interrupted, frontier, plan_for, run, MAX_ROWS

ROOT=Path(__file__).resolve().parent
start=time.monotonic(); checks=0; controls=[]; fixtures=[]; keyed_fixtures=[]; restarts=0
rng=random.Random(202610210124)
def check(ok):
    global checks
    checks += 1
    assert ok
def reject(fn,name):
    try: fn()
    except (ValueError,IndexError,AssertionError):
        controls.append(name); check(True)
    else: raise AssertionError('bad control accepted: '+name)
def reference(data,rows,nn,key=None):
    kw={} if key is None else {'key':key}
    return [blake3(b''.join(struct.pack('<Q',data[i*nn+j]) for i in range(rows)),max_threads=1,**kw).digest() for j in range(nn)]

for rows in [1,7,8,9,127,128,129,255,256,257,383,384,385,511,512,513,767,768,769,1023,1024,1025,3283,3405,3634,3790,7303,8724,9185,11056]:
    nn = 2 if rows < 1026 else 1
    data=[rng.getrandbits(64) for _ in range(rows*nn)]
    ref=reference(data,rows,nn)
    base,s0,t0,_=run(data,rows,nn,plan_for(rows,128))
    check(base==ref)
    plans=[plan_for(rows,128),plan_for(rows,384)]
    irregular=[]; at=0
    while at<rows:
        rc=min(rows-at,128*rng.randint(1,5)); irregular.append((at,rc)); at+=rc
    plans.append(irregular)
    for plan in plans:
        for mode in ['first','derived']:
            depth=24 if mode=='first' else (((rows+127)//128)-1).bit_length()
            out,s,t,pc=run(data,rows,nn,plan,mode=mode,depth=depth)
            check(out==ref); check(t==t0)
            check((s.reads,s.writes)==(s0.reads,s0.writes))
            check(s.peak<=depth)
            check((s.count_reads,s.count_writes)==((0,0) if mode=='derived' else ((len(plan)-1)*nn,(len(plan)-1)*nn)))
            check(pc==((len(plan)-1)*nn if mode=='derived' else 0))
    # Reuse the same allocated bytes after every possible interruption point
    # on a small seven-chunk shape, and selected points on larger shapes.
    plan=plan_for(rows,128)
    positions=range(1,len(plan)+1) if rows<=769 else sorted({1,max(1,len(plan)//2),len(plan)})
    s=Scratch((((rows+127)//128)-1).bit_length(),nn,False)
    for point in positions:
        try: run(data,rows,nn,plan,'derived',s,s.depth,fail_after=point)
        except Interrupted: check(True)
        else: raise AssertionError('failure injection missed')
        fresh=[rng.getrandbits(64) for _ in data]
        new_ref=reference(fresh,rows,nn)
        again,_,_,_=run(fresh,rows,nn,plan_for(rows,256),'derived',s,s.depth)
        check(again==new_ref)
        restarts+=1
    fixtures.append({'rows':rows,'columns':nn,'plans':len(plans),'depth':s.depth,
                     'leaf_sha256':hashlib.sha256(b''.join(ref)).hexdigest(),
                     'cv_reads_u32':s0.reads,'cv_writes_u32':s0.writes})

# Negative controls must break a nontrivial multichunk reference or fail safely.
data=[rng.getrandbits(64) for _ in range(769)]; ref=reference(data,769,1)
for mutation in ['eager_count','off_by_one','endian','no_root','local_counter']:
    try: bad=run(data,769,1,plan_for(769,128),'derived',mutation=mutation)[0]
    except (ValueError,IndexError): bad=None
    check(bad!=ref);controls.append(mutation)
for name,plan in [('skip_first',[(128,641)]),('gap',[(0,128),(256,513)]),
                  ('duplicate',[(0,128),(0,641)]),('reorder',[(128,128),(0,128),(256,513)]),
                  ('partial_nonfinal',[(0,129),(129,640)]),('short',[(0,768)]),
                  ('overrun',[(0,896)]),('zero_launch',[(0,0),(0,769)])]:
    reject(lambda p=plan:run(data,769,1,p,'derived'),name)
reject(lambda:run(data,769,1,plan_for(769,128),'derived',depth=1),'short_depth')
reject(lambda:run(data[:-1],769,1,plan_for(769,128),'derived'),'short_input')
reject(lambda:plan_for(0,128),'zero_rows_outside_model')
reject(lambda:plan_for(MAX_ROWS+1,128),'overflow_outside_model')
reject(lambda:frontier(-1),'negative_chunk')
reject(lambda:Scratch(2,1,False).get(0,0),'stale_cv_direct')
reject(lambda:run(data,769,1,plan_for(769,128),'derived',Scratch(24,2,False)),'shape_growth')
check(frontier(0)==0);check(frontier(2)==2);check(2 .bit_count()==1)

# The active private lane dispatches a separate keyed streaming kernel.
# Its key words and KEYED_HASH flag must apply to chunks AND every parent.
for rows in [1,8,9,127,128,129,255,256,257,383,384,385,511,512,513,769,1025,3283,11056]:
    nn=2 if rows<1026 else 1; key=rng.randbytes(32)
    data=[rng.getrandbits(64) for _ in range(rows*nn)];ref=reference(data,rows,nn,key)
    base,s0,t0,_=run(data,rows,nn,plan_for(rows,128),key=key)
    check(base==ref)
    for chunk in [128,384]:
        out,s,t,pc=run(data,rows,nn,plan_for(rows,chunk),'derived',key=key)
        check(out==ref);check(t==t0);check((s.reads,s.writes)==(s0.reads,s0.writes))
        check(s.count_reads==s.count_writes==0)
    # Fresh profile key and fresh contents on the same poisoned backing.
    s=Scratch(24,nn,False)
    try:run(data,rows,nn,plan_for(rows,128),'derived',s,fail_after=1,key=key)
    except Interrupted:check(True)
    fresh=[rng.getrandbits(64) for _ in data];key2=rng.randbytes(32)
    # Model an interrupted launch having written arbitrary partial CV bytes.
    for at in range(0,len(s.words),3):s.words[at]=rng.getrandbits(32)
    out,_,_,_=run(fresh,rows,nn,plan_for(rows,256),'derived',s,key=key2)
    check(out==reference(fresh,rows,nn,key2));restarts+=1
    keyed_fixtures.append({'rows':rows,'columns':nn,'leaf_sha256':hashlib.sha256(b''.join(ref)).hexdigest()})

data=[rng.getrandbits(64) for _ in range(769)];key=rng.randbytes(32);ref=reference(data,769,1,key)
for mutation in ['drop_parent_key_flag']:
    bad=run(data,769,1,plan_for(769,128),'derived',mutation=mutation,key=key)[0]
    check(bad!=ref);controls.append(mutation)
for name,badkey in [('missing_key',None),('wrong_key',rng.randbytes(32)),
                    ('key_word_endian',b''.join(key[i:i+4][::-1] for i in range(0,32,4)))]:
    bad=run(data,769,1,plan_for(769,128),'derived',key=badkey)[0]
    check(bad!=ref);controls.append(name)
reject(lambda:run(data,769,1,plan_for(769,128),'derived',key=b'bad'),'short_key')

result={'status':'PASS_CPU_PUBLIC_FRONTIER_MODEL_ONLY','seed':202610210124,'checks':checks,
        'fixtures':fixtures,'keyed_fixtures':keyed_fixtures,'restart_cases':restarts,'control_types':len(controls),'controls':controls,
        'wall_seconds':time.monotonic()-start,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        'threads':1,'native_cuda_executed':False,'native_proof_executed':False,
        'new_verified_full_stack_proofs':0,'new_verified_positions':0,
        'limits':['Research-authored model; installed independent blake3 reference',
                  'No native failure/completion,compiler,pool,receipt or privacy gates',
                  'Plan validation is a model precondition, not a new native refusal']}
(ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('fixtures','keyed_fixtures')},indent=2))
