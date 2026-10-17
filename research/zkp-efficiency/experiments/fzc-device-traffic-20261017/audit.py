#!/usr/bin/env python3
"""Independent traffic formulas, source pins and captured equality builders."""
import ctypes, hashlib, json, os, random, resource, signal, subprocess, time
from pathlib import Path
from reference import P, O, mul, sub
HERE=Path(__file__).resolve().parent
U=ctypes.c_uint64; PTR=ctypes.POINTER(U)
def block(src,name):
    a=src.index('extern "C" __global__ void '+name+'('); b=src.index('{',a); e=b+1; d=1
    while d:
        d+=(src[e]=='{')-(src[e]=='}'); e+=1
    return src[a:e]
def main():
    t0=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    pins=json.loads((HERE/'native-pins.json').read_text()); checks=0; drift=[]
    for p in pins:
        snap=Path(p['snapshot']); assert hashlib.sha256(snap.read_bytes()).hexdigest()==p['sha256'];checks+=1
        if hashlib.sha256(Path(p['source']).read_bytes()).hexdigest()!=p['sha256']:drift.append(p['source'])
    # Re-derive schedule by counting reads/writes over actual shrinking lengths.
    result=json.loads((HERE/'result.json').read_text())
    for row in result['rows']:
        N,K=row['N'],row['K']; lean,fused=row['lean'],row['fused']; W=row['nonzero_pad_weights']; S=int(row['supp']); M=32+S+(W if S else 0)
        length=N; bits=row['n']; total=0
        for j in range(bits):
            if fused and j:
                # Fold input -> half-sized output, then evaluate its pairs.
                total+=16*K*length+16*K*(length//2)
                length//=2
                if lean: total+=16*M*length
            else: total+=16*(M if lean else K)*length
            if not fused or j==bits-1:
                total+=16*K*length+16*K*(length//2); length//=2
        assert total==row['source_table_bytes']; checks+=1
        assert sum(16*(r['reads']+r['writes']) for r in row['phases'])==total; checks+=1
    cuda=(HERE/'native/ops__zkp-mvp__gpu-zerocheck__hashline__src__gpu__cuda.rs').read_text()
    assert 'self.st.bytes_fused += 24 * (self.k * self.len) as u64' in cuda
    assert 'self.st.bytes_round += 16 * (self.k * self.len) as u64' in cuda
    assert 'st.bytes_build += 16 * l as u64' in cuda
    checks+=3
    # Only the native Eq kernels; no downloaded code or GPU primitive execution.
    src=(HERE/'native/ops__zkp-mvp__gpu-zerocheck__hashline__src__gpu__kernels.cu').read_text()
    (HERE/'eq_builders.cu').write_text(block(src,'k_eq_table')+'\n'+block(src,'k_eq_join')+'\n')
    argv=['/usr/bin/g++','-std=c++17','-O0','-shared','-fPIC','-Wno-unknown-pragmas','eq_shim.cpp','-o','eq.so']
    cp=subprocess.run(argv,cwd=HERE,text=True,capture_output=True,timeout=25)
    (HERE/'eq-compile.log').write_text(cp.stdout+cp.stderr); assert cp.returncode==0,cp.stderr
    lib=ctypes.CDLL(str(HERE/'eq.so'));leaf=lib.leaf_eq;leaf.argtypes=[PTR,ctypes.c_int,PTR,PTR];join=lib.join_eq;join.argtypes=[PTR,PTR,ctypes.c_int,ctypes.c_int,PTR,PTR]
    rng=random.Random(2026101765); eq_cases=[];eq_words=0
    def build(point):
        n=len(point); N=1<<n;out=(U*(2*N))(); cnt=(U*2)()
        if n<=10:
            r=(U*(2*n))(*(x for p in point for x in p));leaf(r,n,out,cnt)
            assert list(cnt)==[n*N,N]
            return out,16*(n+1)*N
        hi=n-n//2;lo=n//2
        ah,bh=build(point[:hi]);al,bl=build(point[hi:]);join(ah,al,lo,N,out,cnt)
        assert list(cnt)==[2*N,N]
        return out,bh+bl+48*N
    for n in [0,1,2,9,10,11,12]:
        point=[(rng.randrange(P),rng.randrange(P)) for _ in range(n)]
        arr,b=build(point);N=1<<n
        for i in range(N):
            want=O
            for j,r in enumerate(point):want=mul(want,r if (i>>(n-j-1))&1 else sub(O,r))
            assert tuple(arr[2*i:2*i+2])==want;eq_words+=2
        eq_cases.append({'bits':n,'source_read_write_bytes':b,'owner_counted_output_bytes':16*N,'parameter_h2d_bytes':16*n})
    # The inequality is about source accesses; it does not predict DRAM traffic.
    negative={'eq input reads omitted':any(x['source_read_write_bytes']!=x['owner_counted_output_bytes'] for x in eq_cases),'split eq join inputs omitted':eq_cases[-1]['source_read_write_bytes']>48*(1<<12),'original stride omitted':any(p['len']!=r['N'] for r in result['rows'] for p in r['phases'])}
    assert all(negative.values())
    r={'status':'PASS','independent_schedule_and_source_checks':checks,'eq_cases':eq_cases,'independent_eq_words':eq_words,'negative_controls':negative,'live_source_drift':drift,'wall_seconds':time.perf_counter()-t0,'parent_peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'child_peak_rss_kib':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'compiler_argv':argv,'limits':'one CPU thread, 59s wall/CPU, 512 MiB address space; no native crate/GPU'}
    (HERE/'audit-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
if __name__=='__main__':main()
