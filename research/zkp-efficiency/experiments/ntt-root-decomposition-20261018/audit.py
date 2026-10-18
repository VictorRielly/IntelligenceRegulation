#!/usr/bin/env python3
"""Independent exact polynomial/DIF/tiled layout audit; no timing inference."""
import ctypes as C
import datetime, hashlib, json, os, random, resource, signal, time
import experiment as e

P=e.P;BASE=e.BASE;CHECKS={}
def eq(a,b,label):
    assert a==b,label
    CHECKS[label]=CHECKS.get(label,0)+1

def rev(i,lg): return int(f'{i:0{lg}b}'[::-1],2) if lg else 0
def shz(i,on): return i^(((i>>4)&1)*15) if on else i

def high_pass(a,p,inverse):
    lg=p.lg;lt=lg-12;nt=1<<lt;lj=12-lt;J=4096>>lt
    for tile in range(nt):
        j0=tile*J
        sh=[a[(q>>lj)*4096+j0+(q&(J-1))] for q in range(4096)]
        stages=range(lg,12,-1) if inverse else range(13,lg+1)
        for st in stages:
            hs=st-13;halft=1<<hs
            for b in range(2048):
                jj=b&(J-1);tb=b>>lj;tl=tb&(halft-1)
                t=((tb>>hs)<<(hs+1))+tl;k=tl*4096+j0+jj
                i=t*J+jj;ip=i+halft*J;u,v=sh[i],sh[ip]
                if inverse:sh[i]=(u+v)%P;sh[ip]=p.action((u-v)%P,st,k)
                else:v=p.action(v,st,k);sh[i]=(u+v)%P;sh[ip]=(u-v)%P
        for q in range(4096):a[(q>>lj)*4096+j0+(q&(J-1))]=sh[q]
    return a

def tiled_dit(src,p,swz=False,rb=0,skip=False):
    lg=p.lg;n=1<<lg;lb=min(12,lg);bs=1<<lb;out=[0]*n
    for blk in range(n//bs):
        sh=[0]*bs
        for q in range(bs):
            x=blk*bs+q
            # Native dit_p1_pad input is BIT-REVERSED coefficient storage.
            if rb:
                idx=x>>rb
                v=src[idx] if skip or not x&((1<<rb)-1) else 0
            else:
                r=rev(x,lg);v=src[r] if r<len(src) else 0
            sh[shz(q,swz)]=v
        for st in range((rb if skip else 0)+1,lb+1):
            half=1<<(st-1)
            for b in range(bs//2):
                k=b&(half-1);i=((b>>(st-1))<<st)+k
                si=shz(i,swz);sp=shz(i+half,swz)
                u=sh[si];v=p.action(sh[sp],st,k)
                sh[si]=(u+v)%P;sh[sp]=(u-v)%P
        out[blk*bs:(blk+1)*bs]=[sh[shz(q,swz)] for q in range(bs)]
    return high_pass(out,p,False) if lg>12 else out

def tiled_dif(src,p,swz=False):
    lg=p.lg;n=1<<lg;lb=min(12,lg);bs=1<<lb
    out=high_pass(list(src),p,True) if lg>12 else list(src)
    scale=pow(n,P-2,P)
    for blk in range(n//bs):
        sh=[0]*bs
        for q in range(bs):sh[shz(q,swz)]=out[blk*bs+q]
        for st in range(lb,0,-1):
            half=1<<(st-1)
            for b in range(bs//2):
                k=b&(half-1);i=((b>>(st-1))<<st)+k
                si=shz(i,swz);sp=shz(i+half,swz)
                u,v=sh[si],sh[sp];sh[si]=(u+v)%P;sh[sp]=p.action((u-v)%P,st,k)
        for q in range(bs):out[blk*bs+q]=sh[shz(q,swz)]*scale%P
    # This is the native bit-reversed coefficient buffer before the pad path.
    return out

def generic_tables(s,b,inv):
    w=pow(7,(P-1)//(1<<s),P)
    if inv:w=pow(w,P-2,P)
    lo=[pow(w,j,P) for j in range(1<<b)]
    hi=[pow(w,j<<b,P) for j in range(1<<(s-1-b))]
    return lo,hi

def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024*1024,)*2);resource.setrlimit(resource.RLIMIT_CPU,(59,)*2)
    signal.alarm(59);os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    start=time.monotonic();rng=random.Random(e.SEED+1)
    e.LIB=C.CDLL(str(BASE/'host.so'));e.LIB.action.argtypes=[e.U,e.PTR,e.UI,e.UI,C.c_int];e.LIB.action.restype=e.U
    e.LIB.transform.argtypes=[e.PTR,C.c_size_t,e.UI,e.PTR,e.PTR,C.c_int,e.UI,C.c_int];e.LIB.transform.restype=C.c_int
    # Independent original-source polynomial evaluations: not inverse-roundtrip alone.
    for lg in (7,12,13,14):
        n=1<<lg;src=[rng.randrange(P) for _ in range(n)];pf=e.Plan(lg);pi=e.Plan(lg,True)
        dense=pf.transform(src)
        for swz in (False,True):
            eq(tiled_dit(src,pf,swz),dense,'native_tiled_DIT')
            br=tiled_dif(src,pi,swz)
            natural=[br[rev(i,lg)] for i in range(n)]
            eq(natural,pi.transform(src),'native_tiled_DIF_inverse')
            for j in [0,1,n//2,n-1]+[rng.randrange(n) for _ in range(12)]:
                w=pow(7,(P-1)//n,P)
                eq(dense[j],e.horner(src,pow(w,j,P)),'original_polynomial_samples')
                wi=pow(w,P-2,P)
                eq(natural[j],e.horner(src,pow(wi,j,P))*pow(n,P-2,P)%P,'original_inverse_polynomial_samples')
        for rb in (2,3):
            nsrc=n>>rb;natural_src=[rng.randrange(P) for _ in range(nsrc)]
            bit_src=[natural_src[rev(j,lg-rb)] for j in range(nsrc)]
            dense_pad=pf.transform(natural_src)
            for swz in (False,True):
                eq(tiled_dit(bit_src,pf,swz,rb,False),dense_pad,'bitreversed_pad_full_stages')
                eq(tiled_dit(bit_src,pf,swz,rb,True),dense_pad,'bitreversed_pad_skip_stages')
    # Generic consecutive-product comparator: square-root footprint, more products.
    generic=[]
    for s in (7,12,16,20):
        b=(s-1)//2;half=1<<(s-1)
        for inv in (False,True):
            low,high=generic_tables(s,b,inv)
            for k in [0,1,half-1]+[rng.randrange(half) for _ in range(128)]:
                a=rng.randrange(P);v=a
                if k&((1<<b)-1):v=v*low[k&((1<<b)-1)]%P
                if k>>b:v=v*high[k>>b]%P
                eq(v,a*pow(e.root(s,inv),k,P)%P,'generic_OT_exactness')
        # No runtime inference; direct counts for a complete stage's distinct k.
        two=(half-(1<<b)-(1<<(s-1-b))+1)
        generic.append({'stage':s,'full_stage_words':half,'two_table_words':(1<<b)+(1<<(s-1-b)),
                        'action_gl_mul_calls_per_distinct_k_sum':2*half-(1<<b)-(1<<(s-1-b)),
                        'two_general_product_k_count':two,'baseline_products_including_identity':half})
    result={'status':'PASS','seed':e.SEED+1,'checks':CHECKS,'generic_comparator':generic,
            'wall_seconds':time.monotonic()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'threads':1,'cpu_affinity':list(os.sched_getaffinity(0)),'limits':'59s wall/CPU,512MiB AS',
            'scope':'Independent exact polynomial samples and source-derived serial DIT/DIF/tile/swizzle/pad-skip model. No CUDA race/sync, pruned output kernel, native transcript/proof/RNG or GPU check.',
            'completed_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
    (BASE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

if __name__=='__main__':main()
