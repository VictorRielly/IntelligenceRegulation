#!/usr/bin/env python3
"""Independent source-boundary, work-census and degree audit; no runner import."""
import ctypes, hashlib, json, os, random, resource, signal, time
from pathlib import Path

HERE=Path(__file__).resolve().parent

def main():
    t0=time.perf_counter();os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    checks=0;drifts=[]
    r=json.loads((HERE/'result.json').read_text());assert r['status']=='pass';checks+=1
    assert r['source_sha256']==hashlib.sha256((HERE/'run.py').read_bytes()).hexdigest();checks+=1
    for pin in json.loads((HERE/'native-pins.json').read_text()):
        assert hashlib.sha256((HERE/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'];checks+=1
        if hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()!=pin['sha256']:drifts.append(pin['path'])
    old=(HERE/'native/hashline__src__private_block__argument.rs').read_text();new=(HERE/'argument-candidate.rs').read_text()
    def arm(s):
        a=s.index('        SC_FZC => {');b=s.index('        SC_QZC | SC_KVZC => {',a);return a,b
    a,b=arm(old);c,d=arm(new)
    assert old[:a]==new[:c] and old[b:]==new[d:];checks+=1
    # Challenge draws, table constructors, helper/pad setup and range remain
    # identical. The three descriptors reference the captured full points.
    assert old[a:b].split('            let poly = move')[0]==new[c:d].split('            let groups = vec!')[0];checks+=1
    for term in ['point: tau, start: 0, bracket_degree: 3','point: pts.p_g.clone()','point: pts.p_u.clone()','def.groups = Some((groups, bracket))']:
        assert term in new[c:d];checks+=1
    for row in r['work_census']:
        n=row['n'];h=1<<(n-1)
        assert row['ordinary_calls']==5*((1<<n)-1);assert row['baseline_calls']==9*h-4;checks+=2
        if row['case']==0:
            host=5*h-2 if row['pad'] else 3*h-1
            assert row['group_calls']==[7*h-3,host,host];checks+=1
            assert row['recoveries']==3*(n-1) and row['zero_factor_fallbacks']==0;checks+=1
    # Independent finite-difference degree census through the compiled closure.
    # No sharing of the differential runner's field or interpolation code.
    mod=2**64-2**32+1
    plus=lambda x,y:((x[0]+y[0])%mod,(x[1]+y[1])%mod)
    minus=lambda x,y:((x[0]-y[0])%mod,(x[1]-y[1])%mod)
    rng=random.Random(2026101764001)
    draw=lambda:(rng.randrange(mod),rng.randrange(mod))
    pack=lambda xs:(ctypes.c_uint64*(2*len(xs)))(*(w for x in xs for w in x))
    lib=ctypes.CDLL(str(HERE/'isolated.so'));ptr=ctypes.POINTER(ctypes.c_uint64)
    lib.evals.argtypes=[ptr,ptr,ptr,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_size_t]
    def evals(v,conf,pad):
        out=(ctypes.c_uint64*8)();lib.evals(out,pack(v),pack(conf),14,8,pad,9);return list(zip(out[::2],out[1::2]))
    degrees=[]
    for pad in [0,1]:
      for fixture in range(8):
        conf=[draw() for _ in range(38)];base=[draw() for _ in range(21)];step=[draw() for _ in range(21)]
        samples=[];v=base
        for _ in range(7):samples.append(evals(v,conf,pad));v=[plus(x,y) for x,y in zip(v,step)]
        for group,degree in [(0,4),(1,3),(2,2 if pad else 1),(3,2 if pad else 1)]:
            ds=[s[group] for s in samples]
            for _ in range(degree):ds=[minus(ds[i+1],ds[i]) for i in range(len(ds)-1)]
            assert any(z!=(0,0) for z in ds);checks+=1
            ds=[minus(ds[i+1],ds[i]) for i in range(len(ds)-1)]
            assert all(z==(0,0) for z in ds);checks+=1
            degrees.append(dict(pad=bool(pad),fixture=fixture,expression=group,exact_degree=degree))
    assert len(r['negative_controls'])==12 and all(r['negative_controls'].values());checks+=1
    assert r['counts']['zero_factor_fallbacks']==98 and r['counts']['recoveries']==190;checks+=1
    result=dict(status='pass',checks=checks,live_native_drifts=drifts,degree_census=degrees,wall_seconds=time.perf_counter()-t0,
        peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        threads=1,cpu_affinity=sorted(os.sched_getaffinity(0)),nice=os.getpriority(os.PRIO_PROCESS,0),scope='separate executable source/work/finite-difference audit; no native acceptance or privacy gate')
    (HERE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='degree_census'}))

if __name__=='__main__':main()
