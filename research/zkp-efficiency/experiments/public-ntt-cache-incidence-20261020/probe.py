"""Research-only immutable public coset leases; no native code or secrets."""
from pathlib import Path
import hashlib, json, os, platform, random, resource, time

P = 2**64 - 2**32 + 1
SEED = 20261020115
ROOT = Path(__file__).resolve().parent
checks = 0

def ck(x):
    global checks
    assert x
    checks += 1

def powers(h, length):
    out, x = [], 1
    for _ in range(length):
        out.append(x)
        x = x * h % P
    if x == 1:
        raise ValueError('native coset intersects subgroup')
    return tuple(out)

class PublicPowers:
    """Never resize/mutate a live owner. Cache eviction drops its reference only."""
    def __init__(self, enabled=True):
        self.entries = {}
        self.enabled = enabled
        self.builds = 0
    def get(self, h, length, device=0, epoch=0, layout='canonical-u64-v1'):
        h %= P
        # Retain the source helper's actual requested-domain refusal even on hits.
        if pow(h, length, P) == 1:
            raise ValueError('native coset intersects subgroup')
        key = (P, h, device, epoch, layout)
        old = self.entries.get(key)
        if self.enabled and old is not None and len(old) >= length:
            return old
        out = powers(h, length)
        self.builds += 1
        if self.enabled:
            self.entries[key] = out
        return out
    def evict(self):
        self.entries.clear()

def transform(a, inverse=False):
    n = len(a)
    a = list(a)
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        if i < j:
            a[i], a[j] = a[j], a[i]
    size = 2
    while size <= n:
        w = pow(7, (P-1)//size, P)
        if inverse:
            w = pow(w, P-2, P)
        for base in range(0, n, size):
            wj = 1
            for k in range(size//2):
                u, v = a[base+k], a[base+k+size//2] * wj % P
                a[base+k], a[base+k+size//2] = (u+v)%P, (u-v)%P
                wj = wj * w % P
        size *= 2
    if inverse:
        ni = pow(n, P-2, P)
        a = [x*ni%P for x in a]
    return a

def encode(msg, pad, nn, pw):
    n = len(msg)
    assert n+len(pad) <= nn and len(pw) >= nn
    out = transform(msg, True) + [0]*(nn-n)
    for i,x in enumerate(pad):
        out[i] = (out[i]-x)%P
        out[n+i] = (out[n+i]+x)%P
    return transform([x*pw[i]%P for i,x in enumerate(out)])

def independent_row(msg, pad, nn, h):
    """Quadratic interpolation followed by Horner; no butterfly/power cache."""
    n = len(msg)
    w = pow(7, (P-1)//n, P)
    ni = pow(n, P-2, P)
    coeff = [sum(msg[j]*pow(w, (-j*k)%(P-1), P) for j in range(n))*ni%P
             for k in range(n)]
    def horner(v,x):
        a = 0
        for c in reversed(v): a = (a*x+c)%P
        return a
    wn = pow(7, (P-1)//nn, P)
    return [(horner(coeff, h*pow(wn,j,P)%P) +
             (pow(h*pow(wn,j,P)%P,n,P)-1)*horner(pad,h*pow(wn,j,P)%P))%P
            for j in range(nn)]

def run():
    t0=time.monotonic(); rng=random.Random(SEED)
    cache, off = PublicPowers(), PublicPowers(False)
    fixtures=[]; negatives={}; rows=0; positions=0
    for n in [2,4,8,16,32]:
        for rate in [2,4]:
            nn=n*rate
            for q in sorted(set([1,n//2,n])):
                for h in [7,11]:
                    msg=[rng.randrange(P) for _ in range(n)]
                    for attempt in range(2):
                        # Synthetic independent draws, NOT a production RNG/privacy proof.
                        pad=[rng.randrange(P) for _ in range(q)]
                        salt=rng.getrandbits(256).to_bytes(32,'little').hex()
                        lease=cache.get(h,nn)
                        got=encode(msg,pad,nn,lease)
                        ref=independent_row(msg,pad,nn,h)
                        ck(got==ref==encode(msg,pad,nn,off.get(h,nn)))
                        positions+=nn; rows+=1
                        fixtures.append(dict(n=n,rate=rate,q=q,h=h,attempt=attempt,
                                             msg=msg,pad=pad,salt=salt,encoded=got))
    # Delayed opening keeps a big owner across a small request, growth and eviction.
    big=cache.get(7,128); small=cache.get(7,8); ck(big is small)
    grow=cache.get(7,256); ck(grow is not big and grow[:128]==big)
    cache.evict(); ck(big==powers(7,128) and grow==powers(7,256))
    ck(cache.get(7,128) is not big)
    negatives['eviction_keeps_live_lease']=True
    negatives['growth_does_not_mutate_old_owner']=True
    negatives['decreasing_shape_reuses_public_prefix']=True
    default_owner=cache.get(7,128)
    for i,kwargs in enumerate([{'device':1},{'epoch':1},{'layout':'montgomery-v1'}]):
        separated=cache.get(7,128,**kwargs)
        ck(separated is not default_owner)
        ck(cache.get(7,128,**kwargs) is separated)
        negatives['identity_partition_'+str(i)]=True
    # Smaller root-coset request passes; growth into its exact order MUST refuse.
    h=pow(7,(P-1)//32,P); cache.get(h,16)
    try: cache.get(h,32)
    except ValueError: negatives['growth_revalidates_requested_coset']=True
    else: raise AssertionError('domain refusal was cached away')
    ck(pow(h,32,P)==1 and pow(h,16,P)!=1)
    try: cache.get(1,16)
    except ValueError: negatives['unit_coset_refuses']=True
    else: raise AssertionError('unit coset accepted')
    # Preserve existing helper behavior at h=0; do not claim it is a valid profile.
    ck(cache.get(0,8)==(1,0,0,0,0,0,0,0))
    negatives['zero_helper_behavior_preserved_no_profile_admission']=True
    f=fixtures[-1]; msg,pad,nn=f['msg'],f['pad'],f['n']*f['rate']
    good=f['encoded']; pw=cache.get(f['h'],nn)
    wrong=list(pw);wrong[1]=(wrong[1]+1)%P
    ck(encode(msg,pad,nn,wrong)!=good); negatives['mutated_public_power_changes_encode']=True
    ck(encode(msg,pad,nn,cache.get(7,nn))!=good); negatives['coset_omitted_from_key_is_wrong']=True
    other=pad.copy();other[0]=(other[0]+1)%P
    ck(encode(msg,other,nn,pw)!=good);negatives['fresh_pad_changes_encode']=True
    ck(encode(msg,[0]*len(pad),nn,pw)!=good);negatives['pad_elision_is_wrong']=True
    ck(list(reversed(good))!=good);negatives['column_order_changes_encode']=True
    # All samples at a fixed geometry reuse public powers but not private draws.
    for a,b in zip(fixtures[::2],fixtures[1::2]):
        ck(a['pad']!=b['pad'] and a['salt']!=b['salt'] and a['encoded']!=b['encoded'])
    negatives['attempt_private_draws_never_cached']=True
    # Explicit degenerate and field-boundary messages supplement pseudorandom rows.
    for n in [2,4,8,16,32]:
        for rate in [2,4]:
            for kind in ['zero','one','delta','boundary']:
                msg=([0]*n if kind=='zero' else [1]*n if kind=='one' else
                     [1]+[0]*(n-1) if kind=='delta' else [P-1 if j%2 else 0 for j in range(n)])
                q=n//2;nn=n*rate
                for attempt in range(2):
                    pad=[rng.randrange(P) for _ in range(q)]
                    salt=rng.getrandbits(256).to_bytes(32,'little').hex()
                    got=encode(msg,pad,nn,cache.get(7,nn))
                    ck(got==independent_row(msg,pad,nn,7)==encode(msg,pad,nn,off.get(7,nn)))
                    fixtures.append(dict(n=n,rate=rate,q=q,h=7,attempt=attempt,
                                         kind=kind,msg=msg,pad=pad,salt=salt,encoded=got))
                    rows+=1;positions+=nn
    for pin in json.loads((ROOT/'source-pins.json').read_text()):
        ck(hashlib.sha256((ROOT/pin['copy']).read_bytes()).hexdigest()==pin['sha256'])
    (ROOT/'fixtures.json').write_text(json.dumps(fixtures)+'\n')
    result=dict(status='PASS',run_id='20261020T231854Z-2da27679',seed=SEED,
                checks=checks,synthetic_rows=rows,encoded_positions=positions,
                negative_controls=negatives,public_builds=cache.builds,
                cache_off_builds=off.builds,wall_seconds=time.monotonic()-t0,
                rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                threads=1,affinity=sorted(os.sched_getaffinity(0)),
                cpu=next((s.split(':',1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines() if s.startswith('model name')),'unknown'),
                python=platform.python_version(),platform=platform.platform(),
                scope='Synthetic exact row encoding and immutable lease tests; no native proof, GPU or privacy evidence')
    (ROOT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

if __name__=='__main__': run()
