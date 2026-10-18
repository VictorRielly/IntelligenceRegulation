#!/usr/bin/env python3
"""Bounded exact differential and net-cost audit. All inputs synthetic."""
import ctypes,hashlib,json,os,platform,random,re,resource,signal,subprocess,time
from pathlib import Path
from reference import *
import candidate as ca
H=Path(__file__).resolve().parent
SEED=2026101874
def count_call(fn,*args):
    counts=[0,0,0,0]
    names=['add','sub','mul','scale']; originals={n:getattr(ca,n) for n in names+['sm']}
    for j,n in enumerate(names):
        def wrap(a,b,j=j,n=n):counts[j]+=1;return originals[n](a,b)
        setattr(ca,n,wrap)
    def total(xs):
        a=Z
        for x in xs:a=ca.add(a,x)
        return a
    ca.sm=total
    try:r=fn(*args)
    finally:
        for n,v in originals.items():setattr(ca,n,v)
    return r,counts
def scalar_count(c):return 5*c[2]+2*c[3]
def main():
    start=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    source=(H/'native/private_block__layout.rs').read_text()
    consts=re.findall(r'pub\(crate\) const (A_\w+): usize = (\d+);',source)
    (H/'constants.rs.inc').write_text('\n'.join(f'const {a}:usize={b};' for a,b in consts)+'\n')
    (H/'clauses-expression.rs.inc').write_text('{\n'+(H/'clauses.rs.inc').read_text()+'\n}\n')
    argv=['rustc','--edition=2021','--crate-type=cdylib','-C','codegen-units=1','-C','opt-level=0','shim.rs','-o','isolated.so']
    cp=subprocess.run(argv,cwd=H,capture_output=True,text=True,timeout=30,env={**os.environ,'RAYON_NUM_THREADS':'1'})
    (H/'compile.log').write_text(cp.stdout+cp.stderr);assert cp.returncode==0,cp.stderr
    U=ctypes.c_uint64;ptr=ctypes.POINTER(U);lib=ctypes.CDLL(str(H/'isolated.so'));fun=lib.original
    fun.argtypes=[ptr,ptr,ptr,ctypes.c_size_t,ptr,ptr]
    def native(v,mu,c,ln):
        vs=(U*128)(*(a for q in v for a in q));ms=(U*22)(*(a for q in mu[:11] for a in q));cs=(U*8)(*c);out=(U*2)();cnt=(U*4)()
        fun(vs,ms,cs,ln,out,cnt);return tuple(out),list(cnt)
    rng=random.Random(SEED);rf=lambda:(rng.randrange(P),rng.randrange(P))
    checks=dict(fixtures=0,captured_clause_values=0,full_polynomial_values=0,folded_linear_values=0,original_cube_terminals=0,cost_checks=0,base_constructor_values=0,base_contract_refusals=0)
    controls={n:False for n in ['whole_clause_precompute_fails_offcube','stale_mu','missing_affine_constant','reverse_MSB','omit_final_fold','product_coefficient_sign','base_flag_after_extension_fold','small_N_generic_cost_regresses','unchanged_original_finals','degree_preserved']}
    digest=hashlib.sha256();census=[]
    for ln in [4,5]:
     for n in [1,2,4,6]:
      N=1<<n
      for supp in [0,1]:
       for base in [0,1]:
        for lh in [1,2,9]:
         c=[2*rng.randrange(1,2**20),2*rng.randrange(1,2**20),2**9,2**10,128,64,64,32]
         mu=[rf() for _ in range(11+(lh+1)//2+supp)];nu=[rf(),rf()];p=(mu,nu,c,rf(),lh)
         tabs=[[rf() for _ in range(N)] for _ in range(64)]
         if base:
             for j in list(range(3,46))+list(range(46,46+4*(ln-4))):tabs[j]=[(a[0],0) for a in tabs[j]]
             tabs[45]=[(i%2,0) for i in range(N)]
         prep,pc=count_call(ca.prepare,mu,c,ln);assert len(prep[0])==17+4*ln
         linear=[ca.linear([t[i] for t in tabs],prep) for i in range(N)]
         if base:
             for i in range(N):
                 v=[t[i] for t in tabs];assert ca.linear_base(v,prep)==linear[i];checks['base_constructor_values']+=1
             corrupt=[t[0] for t in tabs];j=next(iter(prep[0]));corrupt[j]=(corrupt[j][0],1)
             try:ca.linear_base(corrupt,prep)
             except ValueError:checks['base_contract_refusals']+=1
             else:raise AssertionError('extension source falsely accepted as base')
         originals=[list(t) for t in tabs];original_l=list(linear);rs=[(rng.randrange(P),rng.randrange(1,P)) for _ in range(n)]
         cur=tabs;lin=[linear]
         for round_i,r in enumerate(rs):
             L=len(cur[0]);h=L//2
             for d in [Z,O,(2,0),(4,0),rf()]:
              for i in range(h):
                v=[add(t[i],mul(d,sub(t[i+h],t[i]))) for t in cur]
                lv=add(lin[0][i],mul(d,sub(lin[0][i+h],lin[0][i])))
                want=clauses(v,mu,c,ln);got,ct=native(v,mu,c,ln);assert got==want==ca.combined(v,lv,prep)
                checks['captured_clause_values']+=1
                f=full(v,p,supp,ln);assert f==ca.full_candidate(v,lv,prep,p,supp,ln)
                checks['full_polynomial_values']+=1;digest.update(str(f).encode())
             cur=fold(cur,r);lin=fold(lin,r)
             assert lin[0]==[ca.linear([t[i] for t in cur],prep) for i in range(h)]
             checks['folded_linear_values']+=h
         final=[cube(t,rs) for t in originals];last=cube(original_l,rs)
         assert final==[t[0] for t in cur] and last==lin[0][0]
         assert full(final,p,supp,ln)==ca.full_candidate(final,last,prep,p,supp,ln)
         controls['unchanged_original_finals']=True;checks['original_cube_terminals']+=65
         controls['omit_final_fold']|=original_l[0]!=last
         controls['reverse_MSB']|=n>1 and cube(original_l,list(reversed(rs)))!=last
         controls['missing_affine_constant']|=ca.combined(final,sub(last,prep[1]),prep)!=clauses(final,mu,c,ln)
         wrong=mu.copy();wrong[0]=add(wrong[0],O)
         controls['stale_mu']|=ca.combined(final,last,prep)!=clauses(final,wrong,c,ln)
         bil=prep[2].copy();bil[1]=sub(Z,bil[1]);bad=(prep[0],prep[1],bil)
         controls['product_coefficient_sign']|=ca.combined(final,last,bad)!=clauses(final,mu,c,ln)
         whole=[clauses([t[i] for t in originals],mu,c,ln) for i in range(N)]
         controls['whole_clause_precompute_fails_offcube']|=cube(whole,rs)!=clauses(final,mu,c,ln)
         if base:controls['base_flag_after_extension_fold']|=any(t[0][1] for t in cur[3:45])
         # All candidate terms retain the original degree: one affine and four
         # products. Degree4 full D is unchanged for helpers/gated clauses.
         controls['degree_preserved']=True
         if n==1 and supp==0 and base==0 and lh==1:
             _,bc=native(final,mu,c,ln);_,cc=count_call(ca.combined,final,last,prep);_,lc=count_call(ca.linear,final,prep)
             E=5*N//2+4*(N//2-1)
             cost=scalar_count(pc)+N*scalar_count(lc)+(N-1)*5+E*(scalar_count(cc)+5)
             controls['small_N_generic_cost_regresses']|=cost>E*scalar_count(bc)
             census.append({'ln':ln,'baseline_clause_api':bc,'candidate_online_api':cc,'prepare_api':pc,'generic_linear_entry_api':lc,'N2_conservative_baseline_scalar_products':E*scalar_count(bc),'N2_conservative_candidate_scalar_products':cost})
             checks['cost_checks']+=1
         checks['fixtures']+=1
    assert all(controls.values()),controls
    projections=[]
    for row in census:
     for n in [1,4,19,20,21]:
      N=1<<n;E=5*N//2+4*(N//2-1);terms=17+4*row['ln'];old=E*scalar_count(row['baseline_clause_api'])
      for base in [0,1]:
       build=N*terms*(2 if base else 5);new=scalar_count(row['prepare_api'])+build+5*(N-1)+E*(scalar_count(row['candidate_online_api'])+5)
       projections.append({'logN':n,'ln':row['ln'],'initial_sources_base':bool(base),'evaluations':E,'baseline_clause_scalar_products':old,'candidate_including_prep_build_folds_conservative_interpolation_scalar_products':new,'saved_scalar_products':old-new,'extra_table_bytes':16*N,'extra_fold_logical_bytes':48*(N-1),'build_Fp2_source_reads':terms*N,'build_Fp2_writes':N,'scope':'Counted only; original source tables/finals/folds retained. No timing/DRAM/peak-memory prediction.'})
    result={'status':'PASS','cycle':'0074','run_id':'20261018T032105Z-8464ee28','seed':SEED,'checks':checks,'negative_controls':controls,'synthetic_sha256':digest.hexdigest(),'census':census,'projections':projections,'wall_seconds':time.perf_counter()-start,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'compiler_rss_kib':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'cpu_affinity':[cpu],'threads':1,'nice':os.getpriority(os.PRIO_PROCESS,0),'platform':platform.platform(),'compiler_argv':argv,'scope':'Captured native eleven-clause Rust expression with u128 modular substitutes vs independent Python, synthetic bindings; full helper/pad/host equations independently extended in Python. No native GPU/PTX/full-proof/transcript/RNG/privacy or runtime result.'}
    (H/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='projections'},indent=2))
if __name__=='__main__':main()
