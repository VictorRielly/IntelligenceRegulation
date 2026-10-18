#!/usr/bin/env python3
"""Bounded independent derived-table audit; synthetic inputs only."""
import ctypes, hashlib, json, os, platform, random, resource, signal, subprocess, time
from pathlib import Path
from reference import P,Z,O,add,sub,mul,scale,sm,fold
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
SRC=ROOT/'ops/zkp-mvp/gpu-zerocheck/hashline/src/gpu/fzc_kernels.cu'
SEED=2026101873
U=ctypes.c_uint64
PTR=ctypes.POINTER(U)
def balanced(s,start):
    k=s.index('{',start); d=1; j=k+1
    while d:
        d+=(s[j]=='{')-(s[j]=='}'); j+=1
    return s[start:j]
def capture():
    native=HERE/'native';native.mkdir(exist_ok=True)
    names=['gpu/fzc_kernels.cu','gpu/cuda.rs','gpu/fzc.rs','private_block/argument.rs']
    pins=[]
    for n in names:
        p=SRC.parents[1]/n;b=p.read_bytes();q=native/n.replace('/','__');q.write_bytes(b)
        pins.append({'path':str(p),'snapshot':str(q.relative_to(HERE)),'sha256':hashlib.sha256(b).hexdigest()})
    (HERE/'source-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
    s=(native/'gpu__fzc_kernels.cu').read_text();parts=[]
    parts += [s[s.index('#define FZ_ALPHA'):s.index('__device__ __forceinline__ f2 f2_base')]]
    for key in ['__device__ __forceinline__ f2 f2_base(', '__device__ __forceinline__ f2 ld_f2(', '__device__ __forceinline__ void st_f2(', '__device__ __forceinline__ f2 prm_f2(', '__device__ __forceinline__ f2 fz_mulk(', '__device__ __forceinline__ f2 fz_neg(']:
        parts.append(balanced(s,s.index(key)))
    parts += [s[s.index('#define FZS_K0'):s.index('// A Fp2 linear form')]]
    parts.append(balanced(s,s.index('template <bool SUPP>\n__device__ __forceinline__ void fzs_derive_impl')))
    cap='\n'.join(parts).replace('f2 r; r.c0 = p[2 * i]','nread++; f2 r; r.c0 = p[2 * i]').replace('{ p[2 * i] = v.c0','{ nwrite++; p[2 * i] = v.c0')
    assert cap.count('nread++')==cap.count('nwrite++')==1
    (HERE/'captured.hpp').write_text(cap+'\n')
def reference(v,s,supp):
    """Independent equation, conventional complex-style arithmetic mod p."""
    q=lambda i:tuple(s[i:i+2])
    h=v[9];u=v[6]
    a=sub((s[58],0),sm([scale(h,s[57]),v[12],scale(v[13],s[61])]))
    b=sub(add(u,(32768,0)),add(v[7],scale(v[8],s[61])))
    c=sub(add(h,(32768,0)),add(v[10],scale(v[11],s[61])))
    gl=sm([mul(q(10),a),mul(q(12),b),mul(q(14),c)])
    pl=mul(q(28),sm(mul(q(62+2*j),v[3+j]) for j in range(11)))
    return [gl,pl] if supp else [gl]
def params(rng,w,kind):
    s=[rng.randrange(P) for _ in range(84)]
    s[57:62]=[16384,8192,128,64,256]
    for j in range(11): s[62+2*j:64+2*j]=[rng.randrange(1,P),rng.randrange(P)] if j<w else [0,0]
    if kind==1:s[28:30]=[0,0] # numeric zero must not change public weight skips
    if kind==2:s[10:16]=[0]*6
    return s
def main():
    t=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    capture()
    argv=['/usr/bin/g++','-std=c++17','-O0','-shared','-fPIC','shim.cpp','-o','isolated.so']
    cp=subprocess.run(argv,cwd=HERE,capture_output=True,text=True,timeout=25)
    (HERE/'compile.log').write_text(cp.stdout+cp.stderr);assert cp.returncode==0,cp.stderr
    lib=ctypes.CDLL(str(HERE/'isolated.so'));fun=lib.derive;fun.argtypes=[PTR,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int,PTR,PTR]
    rng=random.Random(SEED);checks={'fixtures':0,'native_reference_values':0,'candidate_reference_values':0,'count_formulas':0,'fold_commutation_values':0,'offcube_values':0,'unchanged_source_values':0};neg={k:False for k in ['forced_base_on_extension','base_flag_cannot_survive_extension_fold','stale_mu_pad','stale_mu_gate','omit_affine_constant','pad_index_swap','nonlinear_table_cannot_be_folded','omit_preparation_cost','private_zero_does_not_remove_work','logical_reads_not_unique_union']};rows=[];digest=hashlib.sha256()
    def execute(tabs,s,supp,var,base):
        L=len(tabs[0]);K=20+supp;KD=K+1+supp
        buf=(U*(2*KD*L))(*(c for tab in tabs for a in tab for c in a));cnt=(U*6)();ss=(U*84)(*s)
        fun(buf,L,supp,var,base,ss,cnt)
        got=[[tuple(buf[2*(j*L+i):2*(j*L+i)+2]) for i in range(L)] for j in range(K,KD)]
        assert list(buf[:2*K*L])==[c for tab in tabs for a in tab for c in a]
        checks['unchanged_source_values']+=K*L
        return got,list(cnt)
    for n in [1,2,4,6]:
      N=1<<n
      for supp in [0,1]:
       for w in ([0,1,3,11] if supp else [0]):
        for base in [0,1]:
         for kind in range(3):
          K=20+supp;s=params(rng,w,kind)
          tabs=[[(rng.randrange(P),rng.randrange(P)) for _ in range(N)] for _ in range(K)]
          if base:
              for j in list(range(3,14))+([20] if supp else []):tabs[j]=[(a[0],0) for a in tabs[j]]
          # Eligibility is the existing complete host contract, not sampled data.
          eligible=all(a[1]==0 for j in list(range(3,14))+([20] if supp else []) for a in tabs[j])
          assert eligible==bool(base)
          if kind==2:
              for j in range(3,14):tabs[j]=[Z]*N
          old,oc=execute(tabs,s,supp,0,base);new,nc=execute(tabs,s,supp,1,base)
          want=list(map(list,zip(*(reference([tab[i] for tab in tabs],s,supp) for i in range(N)))))
          assert old==new==want
          checks['native_reference_values']+=(1+supp)*N;checks['candidate_reference_values']+=(1+supp)*N
          expected_old=N*(17+supp*(3*w+3));expected_new=N*((10 if base else 17)+supp*w*(2 if base else 3))+supp*3*w
          assert oc[0]==expected_old and nc[0]==expected_new,(oc,nc,expected_old,expected_new)
          assert oc[3:5]==nc[3:5]==[N*(8+supp*w),N*(1+supp)]
          assert nc[5]==supp*3*w;checks['count_formulas']+=5
          for r in [Z,O,(rng.randrange(P),rng.randrange(1,P))]:
              ft=fold(tabs,r);fd=fold(new,r)
              # Derived tables remain the same affine combination after binding.
              for i in range(N//2):
                  val=reference([tab[i] for tab in ft],s,supp)
                  assert [x[i] for x in fd]==val
                  checks['fold_commutation_values']+=1+supp
              for d in [(2,0),(5,0),(rng.randrange(P),rng.randrange(1,P))]:
                  vals=[add(tab[0],mul(d,sub(tab[N//2],tab[0]))) for tab in tabs]
                  gd=[add(tab[0],mul(d,sub(tab[N//2],tab[0]))) for tab in new]
                  assert gd==reference(vals,s,supp);checks['offcube_values']+=1+supp
              if base and r[1] and kind==0:
                  bad,_=execute(ft,s,supp,1,1);neg['base_flag_cannot_survive_extension_fold'] |= bad!=fd
          if not base and kind==0:
              bad,_=execute(tabs,s,supp,1,1);neg['forced_base_on_extension'] |= bad!=old
          if kind==0:
              sc=list(s);sc[10]=(sc[10]+1)%P;neg['stale_mu_gate'] |= reference([x[0] for x in tabs],sc,supp)!=[x[0] for x in new]
              sc=list(s);sc[58]=0;neg['omit_affine_constant'] |= reference([x[0] for x in tabs],sc,supp)!=[x[0] for x in new]
              if supp and w:
                  sc=list(s);sc[28]=(sc[28]+1)%P;neg['stale_mu_pad'] |= reference([x[0] for x in tabs],sc,supp)!=[x[0] for x in new]
                  sc=list(s);sc[62:64],sc[82:84]=sc[82:84],sc[62:64];neg['pad_index_swap'] |= reference([x[0] for x in tabs],sc,supp)!=[x[0] for x in new]
                  neg['omit_preparation_cost'] |= nc[0]!=nc[0]-nc[5]
                  neg['logical_reads_not_unique_union'] |= nc[3]!=11*N
          if kind==2:neg['private_zero_does_not_remove_work'] |= nc[0]==expected_new
          r=(5,7);a=tabs[5];b=tabs[6]
          prod=[mul(x,y) for x,y in zip(a,b)];foldprod=add(prod[0],mul(r,sub(prod[N//2],prod[0])))
          aprod=mul(add(a[0],mul(r,sub(a[N//2],a[0]))),add(b[0],mul(r,sub(b[N//2],b[0]))))
          neg['nonlinear_table_cannot_be_folded'] |= foldprod!=aprod
          digest.update(repr(new).encode());checks['fixtures']+=1
          if n==6 and kind==0:rows.append({'N':N,'supp':supp,'w':w,'base':base,'baseline':oc,'candidate':nc,'saved_mul_including_prep':oc[0]-nc[0]})
    assert all(neg.values()),neg
    projection=[]
    for n in [19,20,21,23]:
        N=1<<n
        projection.append({'logN':n,'scope':'counted only; no allocation/device measurement','full_pad_baseline_gl_mul':53*N,'full_pad_candidate_gl_mul':32*N+33,'saved_gl_mul':21*N-33,'extra_coefficient_bytes':176,'unchanged_derived_table_capacity_bytes':32*N,'derivation_source_load_store_bytes':336*N,'owner_unique_union_counter_bytes':208*N,'extra_fold_Fp2_products_for_two_tables':2*(N-1),'extra_fold_table_bytes':96*(N-1)})
    out={'status':'PASS','cycle':'0073','run_id':'20261018T022105Z-6cb6453f','seed':SEED,'checks':checks,'negative_controls':neg,'counts_order':['gl_mul','gl_add','gl_sub','Fp2_source_reads','Fp2_source_writes','prep_gl_mul'],'census':rows,'projections':projection,'synthetic_sha256':digest.hexdigest(),'wall_seconds':time.perf_counter()-t,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'compiler_rss_kib':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'cpu_affinity':[cpu],'nice':os.getpriority(os.PRIO_PROCESS,0),'threads':1,'platform':platform.platform(),'compiler_argv':argv,'scope':'Captured native derived-table source executed serially on CPU with exact u128 modular substitutes vs independent Python Fp2. Candidate and operation census only; no native primitives/PTX/CUDA/races/DRAM/proof/transcript/RNG/privacy or runtime gain.'}
    (HERE/'result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:out[k] for k in ['status','checks','negative_controls','wall_seconds','rss_kib','compiler_rss_kib']},indent=2))
if __name__=='__main__':main()
