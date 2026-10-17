#!/usr/bin/env python3
"""One-thread, <=59s CPU source-access census. No CUDA/GPU execution."""
import ctypes, hashlib, json, os, random, resource, signal, subprocess, time
from pathlib import Path
from reference import P, add, sub, mul, polynomial, fold, round_values

HERE=Path(__file__).resolve().parent
SEED=2026101765
U=ctypes.c_uint64
PTR=ctypes.POINTER(U)

def balanced(src,start):
    b=src.index('{',start); depth=1; end=b+1
    while depth:
        depth+=(src[end]=='{')-(src[end]=='}'); end+=1
    return src[start:end]

def generate():
    cap=HERE/'native'
    src=(cap/'ops__zkp-mvp__gpu-zerocheck__hashline__src__gpu__fzc_kernels.cu').read_text()
    ld='f2 ld_f2(const u64* p, size_t i) { f2 r;'
    st='void st_f2(u64* p, size_t i, f2 v) { p[2 * i]'
    assert src.count(ld)==src.count(st)==1
    src=src.replace(ld,'f2 ld_f2(const u64* p, size_t i) { nread++; f2 r;')
    src=src.replace(st,'void st_f2(u64* p, size_t i, f2 v) { nwrite++; p[2 * i]')
    (HERE/'instrumented.cu').write_text(src)
    kernels=(cap/'ops__zkp-mvp__gpu-zerocheck__hashline__src__gpu__kernels.cu').read_text()
    (HERE/'fold.cu').write_text(balanced(kernels,kernels.index('extern "C" __global__ void k_sc_fold('))+'\n')

def params(rng,supp,w,kind):
    s=[rng.randrange(P) for _ in range(84)]
    # Use the actual nine-column contract. Public shifts stay in trained classes.
    hh,gg=14,7
    s[48:57]=[1,2**(8-gg),1,1,1,1,1,1,2**(16-hh)]
    s[57:62]=[2**hh,2**(hh-1),2**gg,2**(gg-1),256]
    for i in range(11):
        s[62+2*i:64+2*i]=[rng.randrange(1,P),rng.randrange(P)] if i<w else [0,0]
    if kind==1:
        # Some coefficients and extension coordinates vanish: zero is never resampled.
        for i in [0,1,7,8,11,29]: s[i]=0
    return s

def expected(n,supp,lean,fused,w):
    N=1<<n; K=20+supp; M=32+supp+(w if supp else 0)
    if lean: total=(32*M+48*K)*(N-1)
    elif fused: total=64*K*N-48*K
    else: total=80*K*(N-1)
    return total

def main():
    t0=time.perf_counter(); os.nice(19)
    cpu=min(os.sched_getaffinity(0)); os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(59,59)); signal.alarm(59)
    generate()
    argv=['/usr/bin/g++','-std=c++17','-O0','-shared','-fPIC','-Wno-unknown-pragmas','shim.cpp','-o','isolated.so']
    cp=subprocess.run(argv,cwd=HERE,capture_output=True,text=True,timeout=25)
    (HERE/'compile.log').write_text(cp.stdout+cp.stderr)
    assert cp.returncode==0,cp.stderr
    lib=ctypes.CDLL(str(HERE/'isolated.so'))
    cr=lib.calc_round; cr.argtypes=[PTR,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int,PTR,ctypes.c_int,ctypes.c_int,ctypes.c_int,U,U,PTR,PTR]
    cf=lib.calc_fold; cf.argtypes=[PTR,ctypes.c_int,ctypes.c_int,ctypes.c_int,U,U,PTR]
    rng=random.Random(SEED); digest=hashlib.sha256(); checks={'fixtures':0,'variant_runs':0,'round_words':0,'recovered_one_words':0,'final_words':0,'phase_access_counts':0,'source_formula_checks':0}
    neg={x:False for x in ['drop final fold','halve fused fold bytes','lean equals direct loads','lean fusion removes rereads','omit support table','pad zero weights all loaded','plan equals direct complete bytes','omit activation helper','swap limb planes','flip output extension word']}
    rows=[]
    edge=[0,1,P-1,P-2,2**32-1,2**32,2**63]
    for n in [1,2,4,6]:
      N=1<<n
      for supp in [0,1]:
       K=20+supp
       for w in ([0,3,11] if supp else [0]):
        for degree in [4,5]:
         for kind in [0,1,2]:
          tabs=[[(rng.randrange(P),rng.randrange(P)) for _ in range(N)] for _ in range(K)]
          if kind==1:
              tabs=[[(edge[(i+t)%len(edge)],0) for i in range(N)] for t in range(K)]
          if supp: tabs[20]=[(i%2,0) if kind==1 else (rng.randrange(P),rng.randrange(P)) for i in range(N)]
          s=params(rng,supp,w,kind); ss=(U*84)(*s)
          rs=[(rng.randrange(P),rng.randrange(P)) for _ in range(n)]
          ref=tabs; want=[]
          for j in range(n):
              want.append(round_values(ref,degree,s,supp)); ref=fold(ref,rs[j])
          # Semantic controls: changing witness operands must change a sampled relation.
          v=[t[0] for t in tabs]; z=polynomial(v,s,supp)
          vm=list(v); vm[19]=(0,0)
          neg['omit activation helper'] |= polynomial(vm,s,supp)!=z
          vm=list(v); vm[7],vm[12]=vm[12],vm[7]
          neg['swap limb planes'] |= polynomial(vm,s,supp)!=z
          for lean in [0,1]:
           for fused in [0,1]:
            buf=(U*(2*K*N))(*(x for t in tabs for a in t for x in a))
            phases=[]; length=N
            for j in range(n):
                # A fused call folds the preceding physical tables before evaluating.
                deferred=bool(fused and j>0)
                rr=rs[j-1] if deferred else (0,0)
                out=(U*(2*(degree+1)))(); cnt=(U*2)()
                # The debug path evaluates s(1) in every round; release recovers it.
                one=int(j==0 or kind==2)
                cr(buf,length,N,degree,supp,ss,one,lean,int(deferred),*rr,out,cnt)
                phases.append({'phase':'fused' if deferred else 'round','len':length,'reads':cnt[0],'writes':cnt[1]})
                M=32+supp+(w if supp else 0)
                if deferred:
                    q=length//4
                    er=(4*K+2*M)*q if lean else 4*K*q
                    ew=2*K*q; length//=2
                else:
                    er=(M if lean else K)*length; ew=0
                assert list(cnt)==[er,ew],(n,supp,w,lean,fused,j,list(cnt),er,ew)
                checks['phase_access_counts']+=2
                for d in range(degree+1):
                    got=tuple(out[2*d:2*d+2])
                    if d==1 and not one:
                        assert got==(0,0)
                        # Independently evaluate the previous round polynomial at r.
                        vals=want[j-1]; r=rs[j-1]; claim=(0,0)
                        for a,y in enumerate(vals):
                            numerator=(1,0); denominator=1
                            for b in range(len(vals)):
                                if a!=b:
                                    numerator=mul(numerator,sub(r,(b,0)))
                                    denominator=denominator*(a-b)%P
                            claim=add(claim,mul(y,mul(numerator,(pow(denominator,-1,P),0))))
                        assert sub(claim,tuple(out[:2]))==want[j][1]
                        checks['recovered_one_words']+=2
                        continue
                    assert got==want[j][d],(n,supp,w,degree,kind,lean,fused,j,d,got,want[j][d])
                    digest.update(str(got).encode()); checks['round_words']+=2
                    neg['flip output extension word'] |= (got[0],(got[1]+1)%P)!=want[j][d]
                if not fused or j==n-1:
                    cnt=(U*2)(); cf(buf,length,N,K,*rs[j],cnt)
                    assert list(cnt)==[K*length,K*length//2]
                    phases.append({'phase':'fold','len':length,'reads':cnt[0],'writes':cnt[1]})
                    checks['phase_access_counts']+=2; length//=2
            for t in range(K):
                got=tuple(buf[2*t*N:2*t*N+2]); assert got==ref[t][0]
                checks['final_words']+=2
            byte_count=sum(16*(p['reads']+p['writes']) for p in phases)
            closed=expected(n,supp,lean,fused,w)
            assert byte_count==closed,(n,supp,lean,fused,w,byte_count,closed)
            checks['source_formula_checks']+=1; checks['variant_runs']+=1
            if kind==0 and degree==5:
                rows.append({'n':n,'N':N,'K':K,'supp':bool(supp),'nonzero_pad_weights':w,'lean':bool(lean),'fused':bool(fused),'source_table_bytes':byte_count,'owner_counter_table_bytes':expected(n,supp,False,fused,w),'phases':phases})
            neg['drop final fold'] |= byte_count!=closed-48*K
            if fused and n>1 and not lean: neg['halve fused fold bytes'] |= byte_count!=16*K*N+12*K*(2*N-4)+48*K
            if lean:
                neg['lean equals direct loads'] |= byte_count!=expected(n,supp,False,fused,w)
                if fused and n>1: neg['lean fusion removes rereads'] |= byte_count!=closed-16*(32+supp+w)*(N-2)
                if supp and w<11: neg['pad zero weights all loaded'] |= byte_count!=expected(n,supp,True,fused,11)
            if supp: neg['omit support table'] |= byte_count!=expected(n,0,lean,fused,0)
            neg['plan equals direct complete bytes'] |= byte_count+504*N!=1224*N
          checks['fixtures']+=1
    assert all(neg.values()),neg
    projections=[]
    for n in [19,20,21,23]:
        N=1<<n; K=21
        projections.append({'n':n,'N':N,'round_table_width_bytes':16,'scratch_tables_bytes':16*K*N,'plan_bytes':1224*N,'owner_doc_v1_approx_bytes':2184*N,'owner_doc_v2_approx_bytes':1344*N,'counted_build_bytes':504*N,'direct_unfused_table_bytes':expected(n,1,False,False,0),'direct_fused_table_bytes':expected(n,1,False,True,0),'direct_fused_plus_counted_build':expected(n,1,False,True,0)+504*N,'lean_source_table_bytes_w0':expected(n,1,True,True,0),'lean_source_table_bytes_w11':expected(n,1,True,True,11),'fused_table_deletion_fraction':1-expected(n,1,False,True,0)/expected(n,1,False,False,0),'fused_including_counted_build_deletion_fraction':1-(expected(n,1,False,True,0)+504*N)/(expected(n,1,False,False,0)+504*N)})
    result={'status':'PASS','cycle':'0065','run_id':'20261017T182105Z-44205280','seed':SEED,'checks':checks,'negative_controls':neg,'rows':rows,'projection_counts_not_measurements':projections,'wall_seconds':time.perf_counter()-t0,'parent_peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'child_peak_rss_kib':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'cpu_affinity':[cpu],'nice':os.getpriority(os.PRIO_PROCESS,0),'compiler_argv':argv,'output_sha256':digest.hexdigest(),'scope':'Captured local CUDA functions executed serially on CPU with arbitrary-integer modular substitutes and fake CUDA builtins; source accesses, not compiled GPU instructions, concurrency, hardware traffic or native proof evidence. Reductions/parameters/build/finals/transfers kept separate. No GPU/runtime/production execution.'}
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['status','checks','negative_controls','wall_seconds','parent_peak_rss_kib','child_peak_rss_kib','output_sha256']},indent=2))

if __name__=='__main__': main()
