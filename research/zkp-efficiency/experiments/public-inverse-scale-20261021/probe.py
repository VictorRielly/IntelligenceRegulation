"""Exact public Goldilocks inverse-length adapter; synthetic data only."""
from pathlib import Path
import hashlib, json, random, resource, time

HERE = Path(__file__).resolve().parent
P = (1 << 64) - (1 << 32) + 1
SEED = 202610210116

def scale(log_n, max_log=32):
    # Guard before shifting; never admit an unsupported transform.
    if not isinstance(log_n, int) or not 0 <= log_n <= max_log <= 32:
        raise ValueError('unsupported public NTT size')
    return P - ((P - 1) >> log_n)

def scale_table(max_log):
    if not 0 <= max_log <= 32:
        raise ValueError('unsupported public table')
    values = [1]
    for _ in range(max_log):
        x = values[-1]
        values.append((x + (P if x & 1 else 0)) // 2)
    return values

def literal_inverse(x):
    if not x: raise ValueError('inverse of zero')
    base, acc, e, multiplies = x, 1, P - 2, 0
    while e:
        if e & 1:
            acc = acc * base % P
            multiplies += 1
        base = base * base % P
        multiplies += 1
        e >>= 1
    return acc, multiplies

def ntt(data, inverse=False, mode='closed', max_log=32):
    a = list(data); n = len(a)
    if not n or n & (n-1): raise ValueError('non-power-of-two')
    log_n = n.bit_length()-1
    if log_n > max_log: raise ValueError('tables too small')
    j = 0
    for i in range(1,n):
        bit = n >> 1
        while j & bit:
            j ^= bit; bit >>= 1
        j |= bit
        if i < j: a[i],a[j] = a[j],a[i]
    length = 2
    while length <= n:
        w = pow(7,(P-1)//length,P)
        if inverse: w = pow(w,P-2,P)
        for start in range(0,n,length):
            wk = 1
            for k in range(length//2):
                u,v = a[start+k],a[start+k+length//2]*wk%P
                a[start+k],a[start+k+length//2] = (u+v)%P,(u-v)%P
                wk = wk*w%P
        length *= 2
    if inverse:
        inv = literal_inverse(n)[0] if mode=='literal' else (scale_table(max_log)[log_n] if mode=='table' else scale(log_n,max_log))
        a = [x*inv%P for x in a]
    return a

def encode(msg, pad, rate, h, mode):
    n=len(msg);nn=n*rate
    if n+len(pad)>nn or pow(h,nn,P)==1: raise ValueError('bad geometry/coset')
    out=ntt(msg,True,mode)+[0]*(nn-n)
    # Keep the native ordered subtraction/assignment, including q>n.
    for i,x in enumerate(pad):
        out[i]=(out[i]-x)%P
        out[n+i]=x
    power=1
    for i in range(n+len(pad)):
        out[i]=out[i]*power%P;power=power*h%P
    return ntt(out)

def run():
    start=time.monotonic();rng=random.Random(SEED);checks=0;controls=[]
    def ck(x):
        nonlocal checks
        assert x
        checks+=1
    def reject(name, fn):
        try: fn()
        except ValueError: controls.append(name);ck(True);return
        raise AssertionError(name)
    table=scale_table(32)
    for k in range(33):
        val,ops=literal_inverse(1<<k)
        ck(val==scale(k)==table[k]==pow(1<<k,P-2,P));ck(ops==127)
        ck(((1<<k)*scale(k))%P==1)
    for k in [-1,33,64]:reject('scale_reject_'+str(k),lambda k=k:scale(k))
    reject('table_reject_33',lambda:scale_table(33))
    reject('max_log_before_lookup',lambda:scale(14,13))
    reject('empty_transform',lambda:ntt([],True))
    reject('non_power_of_two',lambda:ntt([1,2,3],True))
    reject('undersized_transform_tables',lambda:ntt([1]*8,True,max_log=2))
    ck((P-((P-1)>>33))*(1<<33)%P!=1);controls.append('unguarded_formula_33_is_wrong')
    fixtures=[]
    for n in [1,2,4,8,16,32]:
        for rate in [2,4]:
            for q in sorted({0,1,n,n*(rate-1)}):
                for kind in ['zero','one','monomial','edge','random']:
                    msg=([0]*n if kind=='zero' else [1]*n if kind=='one' else
                         [1]+[0]*(n-1) if kind=='monomial' else
                         [(P-1 if i&1 else 0) for i in range(n)] if kind=='edge' else
                         [rng.randrange(P) for _ in range(n)])
                    pad=[rng.randrange(P) for _ in range(q)]
                    old=encode(msg,pad,rate,7,'literal')
                    new=encode(msg,pad,rate,7,'closed')
                    tab=encode(msg,pad,rate,7,'table')
                    ck(old==new==tab)
                    ck(ntt(ntt(msg),True)==msg)
                    fixtures.append(dict(n=n,rate=rate,q=q,kind=kind,msg=msg,pad=pad,h=7,
                                         encoded=new,encoded_sha256=hashlib.sha256(b''.join(x.to_bytes(8,'little') for x in new)).hexdigest()))
    row=[3,5,7,9,11,13,17,19];correct=ntt(row,True)
    wrong=[x*scale(4)%P for x in ntt(row,True)]
    ck(correct!=wrong);controls.append('double_normalization_detected')
    ck(correct!=[x*2%P for x in correct]);controls.append('wrong_length_scale_detected')
    ck(ntt(row)!=ntt(row,True));controls.append('forward_must_keep_scale_one')
    a=encode(row,[1]*8,4,7,'closed');b=encode(row,[2]*8,4,7,'closed')
    ck(a!=b);controls.append('fresh_pad_change_detected')
    reject('coset_meets_subgroup',lambda:encode(row,[1],4,1,'closed'))
    reject('pad_capacity',lambda:encode(row,[1]*25,4,7,'closed'))
    # CPU reference permits q>n; CUDA's branch is not used as an overlap oracle.
    ck(any(x['q']>x['n'] for x in fixtures))
    result=dict(status='PASS',seed=SEED,checks=checks,synthetic_rows=len(fixtures),
                encoded_positions=sum(len(x['encoded']) for x in fixtures),
                scale_entries=33,literal_multiplications_per_inverse=127,
                negative_controls=controls,wall_seconds=time.monotonic()-start,
                rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                scope='Exact public scale/CPU-style row adapter only; no native/GPU/proof execution')
    (HERE/'fixtures.json').write_text(json.dumps(fixtures,indent=2)+'\n')
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__':run()
