#!/usr/bin/env python3
"""Independent executed-API census and bounded synthetic closure timing.

Does not import the differential runner or use its arithmetic oracle.
"""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import random
import re
import resource
import signal
import statistics
import subprocess
import time

HERE=Path(__file__).resolve().parent


def main():
    t0=time.perf_counter();os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    checks=0
    result=json.loads((HERE/'result.json').read_text());assert result['status']=='pass';checks+=1
    assert result['source_sha256']==hashlib.sha256((HERE/'run.py').read_bytes()).hexdigest();checks+=1
    for f,sha in json.loads((HERE/'native-pins.json').read_text()).items():
        assert hashlib.sha256(Path(f).read_bytes()).hexdigest()==sha
        assert hashlib.sha256((HERE/'native'/Path(f).name).read_bytes()).hexdigest()==sha;checks+=2
    src=(HERE/'isolated.rs').read_text()
    inst=src+'\nthread_local! { static COUNTS: std::cell::Cell<(u64,u64)> = const { std::cell::Cell::new((0,0)) }; }\n'
    mul='pub fn mul(self, r: Fp2) -> Fp2 {';base='pub fn mul_base(self, r: Fp) -> Fp2 {'
    assert inst.count(mul)==inst.count(base)==1
    inst=inst.replace(mul,mul+' crate::COUNTS.with(|c| {let (a,b)=c.get();c.set((a+1,b));});')
    inst=inst.replace(base,base+' crate::COUNTS.with(|c| {let (a,b)=c.get();c.set((a,b+1));});')
    inst=inst.replace('let z=f(&v[..21]);','COUNTS.with(|c|c.set((0,0))); let z=f(&v[..21]); COUNTS.with(|c|{let (a,b)=c.get();*out.add(2)=a;*out.add(3)=b;});')
    (HERE/'instrumented.rs').write_text(inst)
    bench=src+'''
#[no_mangle]
pub unsafe extern "C" fn bench(out:*mut u64, words:*const u64, pad:u32, mode:u32, reps:usize) {
 let w=std::slice::from_raw_parts(words,76); let mut v:Vec<Fp2>=w.chunks_exact(2).map(|x|Fp2::new(Fp(x[0]),Fp(x[1]))).collect();
 let f=match mode {0=>factory_0(&v,14,8,pad!=0,9),1=>factory_1(&v,14,8,pad!=0,9),2=>factory_2(&v,14,8,pad!=0,9),_=>factory_3(&v,14,8,pad!=0,9)};
 let mut acc=Fp2::ZERO;
 let t=std::time::Instant::now();
 for i in 0..reps { v[3].c0=Fp::new(i as u64); acc=acc.add(f(std::hint::black_box(&v[..21]))); }
 let ns=t.elapsed().as_nanos() as u64;
 *out=acc.c0.0;*out.add(1)=acc.c1.0;*out.add(2)=ns;
}
'''
    (HERE/'bench.rs').write_text(bench)
    rustc='/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/rustc'
    build=[]
    for name in ['instrumented','bench']:
        cmd=[rustc,'--edition=2021','--crate-type=cdylib','-C','opt-level=3','-C','codegen-units=1',name+'.rs','-o',name+'.so']
        cp=subprocess.run(cmd,cwd=HERE,capture_output=True,text=True,timeout=20)
        (HERE/(name+'-compile.log')).write_text(cp.stdout+cp.stderr);assert cp.returncode==0,cp.stderr
        build.append(cmd);checks+=1
    lib=ctypes.CDLL(str(HERE/'instrumented.so')); fn=lib.fzc
    u64p=ctypes.POINTER(ctypes.c_uint64)
    fn.argtypes=[u64p,u64p,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_size_t,ctypes.c_uint32]
    rng=random.Random(2026101763);P=2**64-2**32+1
    words=(ctypes.c_uint64*76)(*(rng.randrange(P) for _ in range(76)));out=(ctypes.c_uint64*4)()
    census=[]
    for pad in [0,1]:
      for mode in range(4):
        fn(out,words,14,8,pad,9,mode)
        row=result['costs'][['baseline','base constants','support hoist','combined'][mode]]
        expected_full=row['full_extension_calls_padded' if pad else 'full_extension_calls_unpadded']
        expected_base=row['helper_base_calls']+row['constant_base_calls']
        assert (out[2],out[3])==(expected_full,expected_base),(pad,mode,list(out),row);checks+=1
        census.append(dict(pad=bool(pad),mode=mode,full_extension_calls=out[2],base_calls=out[3]))
    libb=ctypes.CDLL(str(HERE/'bench.so'));bf=libb.bench
    bf.argtypes=[u64p,u64p,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_size_t]
    samples=[]
    for pad in [0,1]:
      for rep in range(7):
        checksums=[]
        order=[0,1,2,3] if rep%2==0 else [3,2,1,0]
        for mode in order:
          bf(out,words,pad,mode,8192);checksums.append(tuple(out[:2]))
          samples.append(dict(pad=bool(pad),mode=mode,repeat=rep,evals=8192,nanoseconds=out[2],checksum=list(out[:2])))
        assert len(set(checksums))==1;checks+=1
    summary=[]
    for pad in [False,True]:
      med={m:statistics.median(s['nanoseconds']/s['evals'] for s in samples if s['pad']==pad and s['mode']==m and s['repeat']>0) for m in range(4)}
      summary.append(dict(pad=pad,median_ns_per_eval=med,baseline_over_candidate={m:med[0]/med[m] for m in range(4)}))
    # Compare candidate boundary: the rest of the source and all called helpers
    # are literally unchanged. This does not prove protocol correctness.
    old=(HERE/'native/argument.rs').read_text();new=(HERE/'argument-candidate.rs').read_text()
    def arm(s):
        start=s.index('        SC_FZC => {'); end=s.index('        SC_QZC | SC_KVZC => {',start);return start,end
    a,b=arm(old);c,d=arm(new);assert old[:a]==new[:c] and old[b:]==new[d:];checks+=1
    assert new[c:d].count('challenge_fp2')==old[a:b].count('challenge_fp2');checks+=1
    assert 'mu[3].mul(f_act)' in new[c:d] and 'helper_sum(v, &lks, h0, alpha, &mu[4..])' in new[c:d] and '.add(pz.eval(v))' in new[c:d];checks+=1
    # A separate static IR census: counts sites, so loop bodies are NOT weighted
    # by iteration count. It is not a runtime multiply or cycle count.
    ir=(HERE/'isolated.ll').read_text();static={}
    for mode in range(4):
      row={}
      for kind,comment in [('body',f'; isolated::factory_{mode}::{{closure#1}}\n'),('l2',f'; isolated::factory_{mode}::{{closure#1}}::{{closure#1}}\n')]:
        st=ir.index(comment);st=ir.index('define ',st);en=ir.index('\n}',st);text=ir[st:en]
        row[kind]=dict(mul_i128_sites=len(re.findall(r'= mul(?: nuw| nsw)* i128 ',text)),capture_bytes=re.findall(r'dereferenceable\((\d+)\)',text.splitlines()[0]))
      static[str(mode)]=row
    output=dict(status='pass',checks=checks,executed_api_census=census,synthetic_timing=summary,samples=samples,llvm_static_sites=static,
       wall_seconds=time.perf_counter()-t0,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,child_peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
       source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),build_argv=build,threads=1,nice=os.getpriority(os.PRIO_PROCESS,0),cpu_affinity=sorted(os.sched_getaffinity(0)),
       scope='independent source audit, executed API count and shared-host synthetic closure microbenchmark; setup not timed; no proof, speed acceptance or extrapolation')
    (HERE/'audit-result.json').write_text(json.dumps(output,indent=2)+'\n');print(json.dumps({k:v for k,v in output.items() if k not in ['samples','build_argv','llvm_static_sites']}))


if __name__=='__main__':main()
