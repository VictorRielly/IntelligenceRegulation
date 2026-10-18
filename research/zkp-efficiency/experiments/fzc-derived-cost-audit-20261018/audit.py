#!/usr/bin/env python3
"""Independent complete fold-chain and original F-polynomial differential audit."""
import ctypes,hashlib,json,os,random,resource,signal,time
from pathlib import Path
from reference import P,Z,O,add,sub,mul,scale,sm,fold,polynomial
H=Path(__file__).resolve().parent
def derived_polynomial(v,ds,s,supp):
    q=lambda i:tuple(s[i:i+2])
    ds8=[sub(q(0),add(q(30+2*i),scale(v[j],s[48+i]))) for i,j in enumerate([4,4,7,8,10,11,12,13,13])]
    lookups=sm(mul(q(18+2*i),sub(mul(v[14+i],mul(ds8[2*i],ds8[2*i+1])),add(ds8[2*i],ds8[2*i+1]))) for i in range(4))
    lookups=add(lookups,mul(q(26),sub(mul(v[18],ds8[8]),O)))
    act=mul(q(16),sub(mul(v[19],sub(q(0),sm([v[3],(128,0),mul(q(2),v[5]),q(4)]))),O))
    indicator=v[20] if supp else O
    gated=mul(indicator,add(mul(q(10),mul(v[5],v[6])),ds[0]))
    pad=mul(sub(O,indicator),ds[1]) if supp else Z
    hosts=sm([mul(mul(q(6),v[1]),sub(add(scale(v[3],s[59]),v[4]),(s[60],0))),mul(mul(q(8),v[2]),v[6])])
    return add(mul(v[0],sm([lookups,act,gated,pad])),mul(indicator,hosts))
def cube_eval(tab,rs):
    # Direct original-cube Lagrange weights; no calls to fold.
    out=Z;n=len(rs)
    for j,a in enumerate(tab):
        w=O
        for k,r in enumerate(rs):w=mul(w,r if (j>>(n-1-k))&1 else sub(O,r))
        out=add(out,mul(w,a))
    return out
def main():
    t=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    rng=random.Random(2026101874);U=ctypes.c_uint64;PTR=ctypes.POINTER(U)
    lib=ctypes.CDLL(str(H/'isolated.so'));f=lib.derive;f.argtypes=[PTR,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int,PTR,PTR]
    checks={'fixtures':0,'full_round_polynomial_values':0,'original_cube_terminal_values':0,'all_prefix_rederived_values':0,'cost_small_N':0}
    controls={'reverse_MSB_binding_detected':False,'omit_terminal_fold_detected':False,'stale_pad_coefficients_detected':False,'generic_N2_pad_prep_can_lose':False,'whole_row_product_precompute_invalid_offcube':False}
    edges=[0,1,P-1,P-2,2**32-1,2**32,2**63]
    digest=hashlib.sha256()
    for n in [1,2,3,6]:
     N=1<<n
     for supp in [0,1]:
      for base in [0,1]:
       for w in ([0,1,11] if supp else [0]):
        K=20+supp;KD=K+1+supp
        tabs=[[(rng.randrange(P),rng.randrange(P)) for _ in range(N)] for _ in range(K)]
        if base:
            for j in range(3,14):tabs[j]=[(edges[(j+i)%len(edges)],0) for i in range(N)]
            if supp:tabs[20]=[(i%2,0) for i in range(N)]
        s=[rng.randrange(P) for _ in range(84)];s[57:62]=[16384,8192,128,64,256]
        for j in range(11):s[62+2*j:64+2*j]=[rng.randrange(1,P),rng.randrange(P)] if j<w else [0,0]
        def derive(cur,variant,flag):
            L=len(cur[0]);buf=(U*(2*KD*L))(*(c for tab in cur for a in tab for c in a));ss=(U*84)(*s);cnt=(U*6)()
            f(buf,L,supp,variant,flag,ss,cnt)
            return [[tuple(buf[2*(j*L+i):2*(j*L+i)+2]) for i in range(L)] for j in range(K,KD)],list(cnt)
        ds,ct=derive(tabs,1,base);orig=[list(t) for t in tabs];orig_ds=[list(t) for t in ds]
        rs=[(rng.randrange(P),rng.randrange(1,P)) for _ in range(n)]
        cur=tabs;curds=ds
        for j,r in enumerate(rs):
            L=len(cur[0]);h=L//2
            rederived,_=derive(cur,0,0);assert rederived==curds;checks['all_prefix_rederived_values']+=(1+supp)*L
            for d in [Z,O,(2,0),(5,0),(rng.randrange(P),rng.randrange(1,P))]:
                for i in range(h):
                    vals=[add(tab[i],mul(d,sub(tab[i+h],tab[i]))) for tab in cur]
                    dv=[add(tab[i],mul(d,sub(tab[i+h],tab[i]))) for tab in curds]
                    got=derived_polynomial(vals,dv,s,supp);want=polynomial(vals,s,supp)
                    assert got==want,(n,supp,base,w,j,d,i)
                    checks['full_round_polynomial_values']+=1;digest.update(str(got).encode())
            prev=curds;cur=fold(cur,r);curds=fold(curds,r)
        finalv=[cube_eval(tab,rs) for tab in orig];finalds=[cube_eval(tab,rs) for tab in orig_ds]
        assert finalv==[x[0] for x in cur];assert finalds==[x[0] for x in curds]
        assert derived_polynomial(finalv,finalds,s,supp)==polynomial(finalv,s,supp)
        checks['original_cube_terminal_values']+=K+1+supp
        controls['omit_terminal_fold_detected'] |= [x[0] for x in prev]!=finalds
        if n>1:controls['reverse_MSB_binding_detected'] |= cube_eval(orig_ds[0],list(reversed(rs)))!=finalds[0]
        if supp and w:
            wrong=list(s);wrong[28]=(wrong[28]+1)%P
            controls['stale_pad_coefficients_detected'] |= derived_polynomial(finalv,finalds,wrong,supp)!=polynomial(finalv,wrong,supp)
        if n==1 and supp and not base and w==11:
            _,old=derive(tabs,0,0);controls['generic_N2_pad_prep_can_lose']=ct[0]>old[0];checks['cost_small_N']+=1
        values=[polynomial([tab[i] for tab in orig],s,supp) for i in range(N)]
        controls['whole_row_product_precompute_invalid_offcube'] |= cube_eval(values,rs)!=polynomial(finalv,s,supp)
        checks['fixtures']+=1
    assert all(controls.values()),controls
    out={'status':'PASS','seed':2026101874,'checks':checks,'negative_controls':controls,'synthetic_sha256':digest.hexdigest(),'wall_seconds':time.perf_counter()-t,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'threads':1,'cpu_affinity':[cpu],'nice':os.getpriority(os.PRIO_PROCESS,0),'scope':'Independent original full F-polynomial, direct original-cube Lagrange terminal and every fold prefix; synthetic scalar CPU only, no native proof/device/privacy result.'}
    (H/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
if __name__=='__main__':main()
