#!/usr/bin/env python3
"""Independent native-basis coefficients and complete release-round audit."""
import ctypes,hashlib,json,os,random,resource,signal,time
from pathlib import Path
from reference import P,Z,O,add,sub,mul,scale,sm,fold,cube,full
from candidate import prepare,linear,combined,full_candidate
H=Path(__file__).resolve().parent
def main():
    t=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    U=ctypes.c_uint64;ptr=ctypes.POINTER(U);f=ctypes.CDLL(str(H/'isolated.so')).original;f.argtypes=[ptr,ptr,ptr,ctypes.c_size_t,ptr,ptr]
    def native(v,mu,c,ln):
        out=(U*2)();ct=(U*4)();f((U*128)(*(a for q in v for a in q)),(U*22)(*(a for q in mu[:11] for a in q)),(U*8)(*c),ln,out,ct);return tuple(out)
    rng=random.Random(2026101875);rf=lambda:(rng.randrange(P),rng.randrange(P));checks={'fixtures':0,'native_basis_coefficients':0,'native_four_product_coefficients':0,'release_round_sums':0,'original_native_terminal_values':0,'degree_bound_differences':0,'synthetic_boundary_values':0}
    negatives={x:False for x in ['swap_two_coefficients','omit_constant','whole_clause_MLE_offcube','reversed_MSB','wrong_initial_claim','stale_coefficients','missing_final_fold']}
    digest=hashlib.sha256();edges=[0,1,P-1,P-2,2**32-1,2**32,2**63]
    for ln in [4,5]:
     for supp in [0,1]:
      for base in [0,1]:
       for n in [1,3,5]:
        N=1<<n;c=[2,2**21,512,1024,1,0,256,128];mu=[rf() for _ in range(17)];p=(mu,[rf(),rf()],c,rf(),9);prep=prepare(mu,c,ln)
        zero=[Z]*64;k0=native(zero,mu,c,ln);assert k0==prep[1]
        # Derive every linear coefficient using native oracle probes, without
        # the candidate's hand algebra or Python original-clause function.
        for j in range(64):
            e=zero.copy();e[j]=O;observed=sub(native(e,mu,c,ln),k0);assert observed==prep[0].get(j,Z);checks['native_basis_coefficients']+=1
        for a,(j,k) in zip(prep[2],[(3,8),(43,11),(4,24),(44,27)]):
            e=zero.copy();e[j]=O;e[k]=O
            ej=zero.copy();ej[j]=O;ek=zero.copy();ek[k]=O
            q=add(sub(sub(native(e,mu,c,ln),native(ej,mu,c,ln)),native(ek,mu,c,ln)),k0)
            assert q==a;checks['native_four_product_coefficients']+=1
        tabs=[[rf() for _ in range(N)] for _ in range(64)]
        for j in range(8,45):
            tabs[j][0]=(edges[j%len(edges)],0 if base else edges[(j+1)%len(edges)])
            checks['synthetic_boundary_values']+=1
        if base:
            for j in range(3,50):tabs[j]=[(a[0],0) for a in tabs[j]]
        orig=[list(x) for x in tabs];derived=[[linear([x[i] for x in tabs],prep) for i in range(N)]];original_d=derived[0][:]
        rs=[rf() for _ in range(n)];cur=tabs;current_claim=None
        degree=4+supp
        for r in rs:
            half=len(cur[0])//2;want=[];got=[]
            for d in range(degree+1):
                oldvals=[];newvals=[]
                for i in range(half):
                    v=[add(x[i],scale(sub(x[i+half],x[i]),d)) for x in cur]
                    dv=add(derived[0][i],scale(sub(derived[0][i+half],derived[0][i]),d))
                    # Native original clauses enter the enclosing polynomial.
                    from reference import extras
                    ex,host,g=extras(v,p,supp,ln)
                    oldvals.append(add(mul(v[0],add(ex,mul(g,native(v,mu,c,ln)))),host))
                    newvals.append(full_candidate(v,dv,prep,p,supp,ln))
                want.append(sm(oldvals));got.append(sm(newvals))
            assert want==got
            if current_claim is not None:
                assert add(got[0],got[1])==current_claim
                negatives['wrong_initial_claim']|=sub(add(current_claim,O),got[0])!=got[1]
            # Lagrange evaluation from the actual declared degree and MSB fold.
            claim=Z
            for j,a in enumerate(got):
                w=O
                for k in range(len(got)):
                    if j!=k:w=mul(w,scale(sub(r,(k,0)),pow((j-k)%P,-1,P)))
                claim=add(claim,mul(a,w))
            current_claim=claim;checks['release_round_sums']+=len(got);digest.update(str(got).encode())
            prev=derived;cur=fold(cur,r);derived=fold(derived,r)
        fv=[cube(x,rs) for x in orig];d=cube(original_d,rs)
        assert fv==[x[0] for x in cur] and d==derived[0][0]
        assert native(fv,mu,c,ln)==combined(fv,d,prep)
        assert current_claim==full_candidate(fv,d,prep,p,supp,ln);checks['original_native_terminal_values']+=1
        negatives['missing_final_fold']|=prev[0][0]!=d
        negatives['reversed_MSB']|=n>1 and cube(original_d,list(reversed(rs)))!=d
        negatives['omit_constant']|=combined(fv,sub(d,prep[1]),prep)!=native(fv,mu,c,ln)
        ts=prep[0].copy();ts[8],ts[20]=ts[20],ts[8]
        negatives['swap_two_coefficients']|=linear(fv,(ts,prep[1],prep[2]))!=linear(fv,prep)
        wrong=mu.copy();wrong[6]=add(wrong[6],O)
        negatives['stale_coefficients']|=native(fv,wrong,c,ln)!=combined(fv,d,prep)
        allcl=[native([x[i] for x in orig],mu,c,ln) for i in range(N)]
        negatives['whole_clause_MLE_offcube']|=cube(allcl,rs)!=native(fv,mu,c,ln)
        # Degree <=4 must hold as a formal univariate restriction even when
        # the registered padded schedule conservatively declares degree5.
        vals=[]
        for x in range(6):
            v=[add(tb[0],scale(sub(tb[N//2],tb[0]),x)) for tb in orig]
            vals.append(full(v,p,supp,ln))
        for _ in range(5):vals=[sub(vals[i+1],vals[i]) for i in range(len(vals)-1)]
        assert vals==[Z];checks['degree_bound_differences']+=1;checks['fixtures']+=1
    assert all(negatives.values()),negatives
    report={'status':'PASS','seed':2026101875,'checks':checks,'negative_controls':negatives,'synthetic_sha256':digest.hexdigest(),'wall_seconds':time.perf_counter()-t,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'threads':1,'cpu_affinity':[cpu],'nice':19,'scope':'Native-basis affine/bilinear coefficients, full enclosing round sums at declared degree4/5, claim recovery and direct original-cube finals. Synthetic bindings only; no full proof/privacy/device result.'}
    (H/'audit-result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
