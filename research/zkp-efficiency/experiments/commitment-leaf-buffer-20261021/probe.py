"""Bounded differential test, including poisoned CV storage and negative controls."""
from pathlib import Path
import hashlib,importlib.metadata,json,platform,random,resource,struct,time
from blake3 import blake3
from candidate import State,chunk_plan,depth_for_rows,hash_columns

ROOT=Path(__file__).resolve().parent
start=time.monotonic(); checks=0; controls=[]; fixtures=[]
rng=random.Random(202610210123)
def check(ok):
    global checks
    checks+=1
    assert ok
def refuse(fn,name):
    try: fn()
    except (ValueError,AssertionError): controls.append(name);check(True)
    else: raise AssertionError('control accepted: '+name)

check(blake3(b'',max_threads=1).hexdigest()=='af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262')
rows_list=[1,7,8,9,127,128,129,255,256,257,383,384,385,511,512,513,1023,1024,1025,3283,3405,3634,3790,7303,8724,9185,11056]
for rows in rows_list:
    nn=3 if rows<1026 else 1
    data=[rng.getrandbits(64) for _ in range(rows*nn)]
    ref=[blake3(b''.join(struct.pack('<Q',data[i*nn+j]) for i in range(rows)),max_threads=1).digest() for j in range(nn)]
    baseline,s0,t0,c0=hash_columns(data,rows,nn,128,24,True)
    out,s1,t1,c1=hash_columns(data,rows,nn,128)
    other,s2,t2,c2=hash_columns(data,rows,nn,384)
    first,s3,t3,c3=hash_columns(data,rows,nn,128,first_launch=True)
    check(baseline==ref);check(out==ref);check(other==ref)
    check(t0==t1);check(c0==c1==c2)
    check(first==ref);check(t3==t0);check(c3==c0)
    check((s0.reads,s0.writes)==(s1.reads,s1.writes))
    check(s1.peak<=depth_for_rows(rows))
    # Compact state must remain correct across a fresh synthetic proof.
    fresh=[rng.getrandbits(64) for _ in data]
    s1.reset()
    again,_,_,_=hash_columns(fresh,rows,nn,256,state=s1)
    fresh_ref=[blake3(b''.join(struct.pack('<Q',fresh[i*nn+j]) for i in range(rows)),max_threads=1).digest() for j in range(nn)]
    check(again==fresh_ref)
    s3.reset()
    reused,_,_,_=hash_columns(fresh,rows,nn,256,state=s3)
    check(reused==fresh_ref)
    # The ordinary host salting and Merkle construction stay unchanged.
    salt=rng.randbytes(32)
    check(blake3(out[0]+salt,max_threads=1).digest()==blake3(ref[0]+salt,max_threads=1).digest())
    fixtures.append(dict(rows=rows,columns=nn,depth=depth_for_rows(rows),peak=s1.peak,
                         compressions=c1,state_reads_u32=s1.reads,state_writes_u32=s1.writes,
                         leaves_sha256=hashlib.sha256(b''.join(out)).hexdigest()))

# Compute every prefix peak directly, independently of the planner formula.
peak=0
for chunks in range(1,65537):
    if chunks>1: peak=max(peak,(chunks-2).bit_count()+1)
    check(peak==(chunks-1).bit_length())

for rows in range(1,131073):
    d=depth_for_rows(rows)
    check(2**d>=(rows+127)//128)
    check(d==0 or 2**(d-1)<(rows+127)//128)

data=[rng.getrandbits(64) for _ in range(385)]
ref=blake3(b''.join(struct.pack('<Q',x) for x in data),max_threads=1).digest()
for mutation in ['endian','no_root','counter_zero']:
    bad,_,_,_=hash_columns(data,385,1,mutation=mutation)
    check(bad[0]!=ref);controls.append(mutation)
refuse(lambda:hash_columns(data,385,1,depth=1),'too_short_public_depth')
bad=State(2,1);bad.words[16]=1
refuse(lambda:hash_columns(data,385,1,state=bad),'stale_nonzero_length')
refuse(lambda:hash_columns(data,385,1,state=State(1,1)),'shape_growth_without_resize')
refuse(lambda:depth_for_rows(0),'zero_rows_not_modelled')
refuse(lambda:depth_for_rows(1<<29),'u32_length_overflow_not_modelled')
refuse(lambda:hash_columns(data[:-1],385,1),'short_input')
check(chunk_plan(513,129)==[(0,128),(128,128),(256,128),(384,128),(512,1)])
controls.append('unaligned_chunk_request_rounded_like_native')
check(hash_columns(data,385,1,first_launch=True)[0][0]==ref)
controls.append('all_poison_including_length_safe_only_with_first_launch_init')

result=dict(status='PASS_CPU_HASH_AND_STATE_MODEL_ONLY',seed=202610210123,checks=checks,
    fixtures=fixtures,control_types=len(controls),controls=controls,
    wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    threads=1,blake3_package_version=importlib.metadata.version('blake3'),
    platform=platform.platform(),new_verified_full_stack_proofs=0,
    native_cuda_executed=False,native_proof_executed=False,
    limits=['Independent installed library hash oracle; state model authored by same researcher',
            'No GPU allocator/compiler/driver/receipt/privacy gate evidence',
            'Compression graph unchanged; only reserved CV state and initialization differ',
            'No claim about physical pooled capacity or critical-path time'])
(ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='fixtures'},indent=2))
