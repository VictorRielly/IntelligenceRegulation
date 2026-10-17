#!/usr/bin/env python3
"""Bounded F-slot source differential. Only seeded synthetic field elements."""
import ctypes, hashlib, importlib.util, json, os, random, resource, signal, statistics, subprocess, time
from pathlib import Path

HERE=Path(__file__).resolve().parent
SEED=2026101764

def main():
    start=time.perf_counter();os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    import prepare
    prepare.main()
    rustc='/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/rustc'
    cmd=[rustc,'--edition=2021','--crate-type=cdylib','-C','opt-level=3','-C','codegen-units=1','isolated.rs','-o','isolated.so']
    cp=subprocess.run(cmd,cwd=HERE,capture_output=True,text=True,timeout=25)
    (HERE/'compile.log').write_text(cp.stdout+cp.stderr);assert cp.returncode==0,cp.stderr
    spec=importlib.util.spec_from_file_location('independent_f_oracle',HERE/'oracle.py');ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref)
    add,sub,mul,summ,P,ZERO,ONE=ref.add,ref.sub,ref.mul,ref.summ,ref.P,ref.ZERO,ref.ONE
    lib=ctypes.CDLL(str(HERE/'isolated.so'));up=ctypes.POINTER(ctypes.c_uint64)
    lib.drive.argtypes=[up,up,up,up,up,up,up,ctypes.c_size_t,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_size_t,ctypes.c_uint32,ctypes.c_uint32]
    lib.evals.argtypes=[up,up,up,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_size_t]
    def pack(xs):return (ctypes.c_uint64*(2*len(xs)))(*(w for x in xs for w in x))
    def pairs(xs):return list(zip(xs[::2],xs[1::2]))
    def native(tabs,v,pts,rho,hh,gg,pad,nlk,mode,track=True):
        n=len(rho);out=(ctypes.c_uint64*(2*(5*n+21)))();counts=(ctypes.c_uint64*6)();ns=ctypes.c_uint64()
        lib.drive(out,counts,ctypes.byref(ns),pack([z for tb in tabs for z in tb]),pack(v),pack([z for p in pts for z in p]),pack(rho),n,hh,gg,pad,nlk,mode,track)
        return pairs(list(out)),list(counts),ns.value
    def evaluate(row,v,hh,gg,pad,nlk):
        out=(ctypes.c_uint64*8)();lib.evals(out,pack(row),pack(v),hh,gg,pad,nlk);return pairs(list(out))
    def eqpoint(a,b):
        result=ONE
        for x,y in zip(a,b):result=mul(result,add(mul(x,y),mul(sub(ONE,x),sub(ONE,y))))
        return result
    def basis(pt):
        # Direct tensor definition, independent of native table builder/folds.
        return [eqpoint(pt,[(int(bool(j&(1<<(len(pt)-1-k)))),0) for k in range(len(pt))]) for j in range(1<<len(pt))]
    def mle(tabs,pt):
        w=basis(pt);return [summ(mul(a,b) for a,b in zip(tb,w)) for tb in tabs]
    def interpolate(vals,x):
        out=ZERO
        for i,vi in enumerate(vals):
            a=ONE;den=1
            for j in range(len(vals)):
                if i!=j:a=mul(a,sub(x,(j,0)));den=den*(i-j)%P
            out=add(out,mul(vi,ref.scale(a,pow(den,P-2,P))))
        return out
    rng=random.Random(SEED)
    rand=lambda:(rng.randrange(P),rng.randrange(P))
    def fixture(n,pad,case):
        v=[rand() for _ in range(38)];pts=[[rand() for _ in range(n)] for _ in range(3)];rho=[rand() for _ in range(n)]
        if case==2:pts=[[ZERO]*n for _ in range(3)];rho=[ONE]+[rand() for _ in range(n-1)]
        if case==3:pts=[[ONE]*n for _ in range(3)];rho=[ZERO]+[rand() for _ in range(n-1)]
        if case==4:pts[0]=[ZERO if j%2 else ONE for j in range(n)]
        if case==5:
            for p in pts:p[-1]=ZERO
        if case==6:pts=[pts[0][:] for _ in range(3)]
        tabs=[basis(p) for p in pts]+[[rand() for _ in range(1<<n)] for _ in range(18)]
        if case==1:tabs=[*tabs[:3],*[[(a,0) for a,b in tb] for tb in tabs[3:]]]
        if case==7:tabs=[*tabs[:3],*[[ZERO]*(1<<n) for _ in range(18)]]
        if pad:tabs[20]=[ONE if j<max(1,(1<<n)-3) else ZERO for j in range(1<<n)]
        return tabs,v,pts,rho
    counts=dict(fixtures=0,round_values=0,original_cube_round_values=0,terminal_words=0,bracket_values=0,extension_polynomial_values=0,recoveries=0,zero_factor_fallbacks=0)
    controls={};rows=[];digest=hashlib.sha256();example=None
    for n in [1,2,3,4]:
      for pad in [0,1]:
       for case in range(8):
        hh=[9,14,16][case%3];gg=[1,7,8][case%3];nlk=[0,1,2,3,8,9,9,9][case]
        tabs,v,pts,rho=fixture(n,pad,case)
        plain,pc,_=native(tabs,v,pts,rho,hh,gg,pad,nlk,0)
        current,cc,_=native(tabs,v,pts,rho,hh,gg,pad,nlk,1)
        grouped,gc,_=native(tabs,v,pts,rho,hh,gg,pad,nlk,2)
        assert plain==current==grouped,(n,pad,case)
        counts['round_values']+=5*n*2;counts['recoveries']+=gc[4];counts['zero_factor_fallbacks']+=gc[5]
        assert cc[3]==5*(1<<(n-1))+4*((1<<(n-1))-1)
        assert pc[3]==5*((1<<n)-1)
        # Every degree sample is independently recomputed from the ORIGINAL
        # tables at full points, never the candidate's partially folded state.
        for j in range(n):
          vals=plain[5*j:5*j+5]
          for t in [*[(x,0) for x in range(5)],(13,19)]:
            direct=ZERO
            for x in range(1<<(n-j-1)):
              suffix=[(int(bool(x&(1<<(n-j-2-k)))),0) for k in range(n-j-1)]
              row=mle(tabs,rho[:j]+[t]+suffix)
              direct=add(direct,ref.reference(row+v[21:],hh,gg,pad,nlk))
            assert interpolate(vals,t)==direct,(n,pad,case,j,t)
            counts['original_cube_round_values']+=1
        final=mle(tabs,rho);assert final==plain[5*n:];counts['terminal_words']+=21
        fval=ref.reference(final+v[21:],hh,gg,pad,nlk)
        assert interpolate(plain[5*n-5:5*n],rho[-1])==fval
        # Full brackets and arbitrary non-Boolean terminal/extension-like rows.
        for row in [final, [rand() for _ in range(21)]]:
            z,b0,b1,b2=evaluate(row,v,hh,gg,pad,nlk)
            assert z==ref.reference(row+v[21:],hh,gg,pad,nlk)
            assert z==summ(mul(a,b) for a,b in zip(row[:3],[b0,b1,b2]));counts['bracket_values']+=4
            # Simulate private-table extension perturbations. This tests only
            # the polynomial identity, not the native extension protocol.
            ex=[ZERO]*3+[rand() for _ in range(17)]+[ZERO];eta=rand();pert=[add(a,mul(eta,b)) for a,b in zip(row,ex)]
            z,*bs=evaluate(pert,v,hh,gg,pad,nlk)
            assert z==ref.reference(pert+v[21:],hh,gg,pad,nlk)==summ(mul(a,b) for a,b in zip(pert[:3],bs));counts['extension_polynomial_values']+=1
        if n==3 and case==0:
            bad= native(tabs,v,pts,rho,hh,gg,pad,nlk,5)[0]
            controls['asserted host sum cannot seed subgroup recovery']=bad!=plain
        if n==3 and case==5:
            controls['main bracket degree2 misses cubic helper']=native(tabs,v,pts,rho,hh,gg,pad,nlk,3)[0]!=plain
            if pad:controls['padded hosts cannot declare degree1']=native(tabs,v,pts,rho,hh,gg,pad,nlk,4)[0]!=plain
            wrong=[pts[1],pts[0],pts[2]]
            controls['swapped equality points']=native(tabs,v,wrong,rho,hh,gg,pad,nlk,2)[0]!=plain
            wrong=[pts[0]]*3
            controls['shared equality point']=native(tabs,v,wrong,rho,hh,gg,pad,nlk,2)[0]!=plain
        if pad:
            row=[rand() for _ in range(21)]
            for m in ['activation incorrectly gated','helpers incorrectly gated','pad term dropped','whole bracket gated','wrong helper index','host gate omitted','host half omitted']:
                controls[m]=controls.get(m,False) or ref.reference(row+v[21:],hh,gg,pad,nlk,m)!=ref.reference(row+v[21:],hh,gg,pad,nlk)
        rows.append(dict(n=n,pad=bool(pad),case=case,lookups=nlk,ordinary_calls=pc[3],baseline_calls=cc[3],group_calls=gc[:3],recoveries=gc[4],zero_factor_fallbacks=gc[5]))
        digest.update(repr(plain).encode());counts['fixtures']+=1
    assert all(controls.values()),controls
    assert counts['zero_factor_fallbacks']>0 and counts['recoveries']>0
    # Larger synthetic tables test the same source in its serial chunked path.
    # These are generic F-domain axes, never token/context workloads.
    samples=[]
    for n in [4,8,12,13]:
      for pad in [0,1]:
        tabs,v,pts,rho=fixture(n,pad,0)
        for repeat in range(5):
            order=[1,2] if repeat%2==0 else [2,1];got={}
            for mode in order:
                vals,c,ns=native(tabs,v,pts,rho,14,8,pad,9,mode,False);got[mode]=vals
                samples.append(dict(n=n,pad=bool(pad),repeat=repeat,mode=mode,ns=ns))
            assert got[1]==got[2]
        final=mle(tabs,rho);assert final==got[1][5*n:];counts['terminal_words']+=21;counts['fixtures']+=1
    summary=[]
    for n in [4,8,12,13]:
      for pad in [False,True]:
        med={mode:statistics.median(s['ns'] for s in samples if s['n']==n and s['pad']==pad and s['repeat']>0 and s['mode']==mode) for mode in [1,2]}
        summary.append(dict(n=n,pad=pad,baseline_ns=med[1],grouped_ns=med[2],baseline_over_grouped=med[1]/med[2]))
    result=dict(status='pass',cycle='0064',run_id='20261017T142624Z-6b84b6ef',seed=SEED,counts=counts,negative_controls=controls,work_census=rows,synthetic_timing=summary,samples=samples,output_sha256=digest.hexdigest(),
        wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,child_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
        compiler_argv=cmd,threads=1,cpu_affinity=sorted(os.sched_getaffinity(0)),nice=os.getpriority(os.PRIO_PROCESS,0),source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        scope='Captured F full polynomial and grouped source vs independent Python arbitrary-integer original-cube oracle; serial Rayon substitutions; synthetic tables, no native crate, masking, transcript, RNG, PCS, receipt, privacy gate or GPU; timing includes evaluator setup/round/fold/finals but excludes factories/input copying/serialization')
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['work_census','samples','compiler_argv']}))

if __name__=='__main__':main()
