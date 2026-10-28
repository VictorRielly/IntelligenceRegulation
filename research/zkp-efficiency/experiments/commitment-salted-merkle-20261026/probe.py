"""Differential roots, every retained node/path, roles, boundary shapes."""
from pathlib import Path
import hashlib, json, random, resource, struct, time
import blake3
from model import fused_tree, hash64, path

ROOT=Path(__file__).resolve().parent
SEED=202610260125
start=time.monotonic(); rng=random.Random(SEED); checks=0; controls=[]; cases=[]

def check(ok):
    global checks
    checks+=1
    assert ok

def h(data,key):
    return blake3.blake3(data,max_threads=1,**({} if key is None else {'key':key})).digest()

def tag(profile):
    return {role: blake3.blake3(profile.encode(),derive_key_context='hashline-zk-mr1 2026-09-20 '+ctx,max_threads=1).digest()
            for role,ctx in [('column','pcs column digest'),('leaf','pcs salted merkle leaf'),('node','pcs merkle inner node')]}

def reference(leaves,salts,lk,nk):
    levels=[[h(a+b,lk) for a,b in zip(leaves,salts)]]
    while len(levels[-1])>1:
        p=levels[-1];levels.append([h(p[j]+p[j+1],nk) for j in range(0,len(p),2)])
    return levels

def reference_path(leaves,index,nk):
    # A separate tree rebuild, without candidate indexing or stored levels.
    out=[]; p=leaves[:]; at=index
    while len(p)>1:
        out.append(p[at^1]); at//=2
        p=[h(p[j]+p[j+1],nk) for j in range(0,len(p),2)]
    return out

def verify(root,leaf,salt,index,siblings,n,lk,nk):
    if not 0<=index<n or len(siblings)!=n.bit_length()-1: return False
    v=h(leaf+salt,lk)
    for s in siblings:
        v=h(s+v if index&1 else v+s,nk);index//=2
    return v==root

profiles=[None,'hashline-zk-mr1/private-block-rung-g-t24-dev/1','research-synthetic-profile-20261026']
for profile in profiles:
    keys={r:None for r in ('column','leaf','node')} if profile is None else tag(profile)
    for n in [1,2,4,8,16,32,64,128]:
        for rows in [1,8,9,128,129]:
            # Synthetic encoded column bytes only. This is NOT an NTT/witness.
            columns=[rng.randbytes(rows*8) for _ in range(n)]
            leaves=[h(c,keys['column']) for c in columns]; salts=[rng.randbytes(32) for _ in range(n)]
            ref=reference(leaves,salts,keys['leaf'],keys['node'])
            got,counts=fused_tree(leaves,salts,keys['leaf'],keys['node'])
            check(got==ref)
            check(sum(map(len,got))==2*n-1)
            check(counts['salt_calls']==n and counts['node_calls']==n-1)
            check(counts['read_bytes']==(64 if n==1 else 96*n-64))
            check(counts['write_bytes']==32*(2*n-1))
            for j in range(n):
                p=path(got,j); rp=reference_path(ref[0],j,keys['node'])
                check(p==rp)
                check(verify(got[-1][0],leaves[j],salts[j],j,p,n,keys['leaf'],keys['node']))
                bad=bytearray(salts[j]);bad[0]^=1
                check(not verify(got[-1][0],leaves[j],bytes(bad),j,p,n,keys['leaf'],keys['node']))
                if n>1:
                    check(not verify(got[-1][0],leaves[j],salts[j],j^1,p,n,keys['leaf'],keys['node']))
                    check(not verify(got[-1][0],leaves[j],salts[j],j,p[:-1],n,keys['leaf'],keys['node']))
            # A second commitment uses fresh synthetic leaves/salts on the same shape.
            fresh_salts=[rng.randbytes(32) for _ in range(n)]
            fresh,unused=fused_tree(leaves,fresh_salts,keys['leaf'],keys['node'])
            check(fresh==reference(leaves,fresh_salts,keys['leaf'],keys['node']))
            check(fresh[-1][0]!=got[-1][0])
            cases.append(dict(profile=profile,encoded_columns=n,synthetic_column_rows=rows,
                              root=got[-1][0].hex(),counts=counts))

keys=tag(profiles[1]); n=16; leaves=[rng.randbytes(32) for _ in range(n)];salts=[rng.randbytes(32) for _ in range(n)]
ref=reference(leaves,salts,keys['leaf'],keys['node'])
for mutation in ['parent_flag','no_root','no_key_flag','big_endian','leaf_uses_node_key','node_uses_leaf_key','salt_first','reverse_children','drop_leaf_level']:
    got,_=fused_tree(leaves,salts,keys['leaf'],keys['node'],mutation)
    check(got!=ref);controls.append(mutation)
for name,lk,nk in [('legacy',None,None),('wrong_profile',tag(profiles[2])['leaf'],tag(profiles[2])['node']),('roles_swapped',keys['node'],keys['leaf'])]:
    got,_=fused_tree(leaves,salts,lk,nk);check(got[-1][0]!=ref[-1][0]);controls.append(name)
for name,l,s in [('zero',[],[]),('non_power_two',leaves[:3],salts[:3]),('short_salts',leaves,salts[:-1]),('short_digest',[b'bad']+leaves[1:],salts)]:
    try:fused_tree(l,s,keys['leaf'],keys['node'])
    except ValueError:check(True);controls.append(name)
    else:raise AssertionError(name)
try:hash64(b'bad',keys['leaf'])
except ValueError:check(True);controls.append('short_message')
else:raise AssertionError('short_message')

result=dict(status='PASS_CPU_SALTED_MERKLE_MODEL_ONLY',seed=SEED,checks=checks,
            fixtures=len(cases),path_positions=sum(x['encoded_columns'] for x in cases),
            control_types=len(controls),controls=controls,cases=cases,
            diagnostic_wall_seconds=time.monotonic()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            threads=1,new_verified_full_stack_proofs=0,new_verified_passes=0,new_verified_positions=0,
            actual_model_context=None,native_build=False,gpu_executed=False,
            independent_reference='installed Python blake3, max_threads=1; reference tree/path authored separately by same researcher',
            limits=['Synthetic hashes; no witness/encoding/PCS algebra/transcript/receipt proof',
                    'No concurrency, allocator, GPU completion, native refusal or privacy acceptance tested'])
(ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='cases'},indent=2))
