"""Negative for a naive tensor-style degree reduction, not a paper audit."""
import hashlib,json,os,resource,signal,time
from pathlib import Path
import oracle
here=Path(__file__).resolve().parent
signal.alarm(59);resource.setrlimit(resource.RLIMIT_CPU,(59,59))
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(10)
start=time.perf_counter(); left=[(2,0),(3,0),(11,0)];right=[(5,0),(7,0),(13,0)]
rows=[]
for t in range(4):
    vals=[oracle.add(a,oracle.mul((t,0),oracle.sub(b,a))) for a,b in zip(left,right)]
    full=oracle.mul(vals[0],oracle.mul(vals[1],vals[2]))
    gh0=oracle.mul(left[1],left[2]);gh1=oracle.mul(right[1],right[2])
    collapsed=oracle.mul(vals[0],oracle.add(gh0,oracle.mul((t,0),oracle.sub(gh1,gh0))))
    assert (full==collapsed)==(t in (0,1))
    rows.append({'t':t,'full_product':full,'collapsed_product':collapsed,'equal':full==collapsed})
out={'run_id':'20261004T120146Z-d7433b90','status':'expected negative observed','seed':'deterministic explicit endpoints',
     'endpoint0':left,'endpoint1':right,'samples':rows,'device':'CPU only','threads':1,'countable_tokens':0,
     'elapsed_seconds':time.perf_counter()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
     'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
     'reference_sha256':hashlib.sha256((here/'oracle.py').read_bytes()).hexdigest(),
     'scope':'Naive pre-multiplication then multilinear extension loses the original degree-3 round polynomial. Does not assert TensorZKP implements only this or establish a paper defect; additional mechanism must be inspected/reproduced before native transfer.',
     'resources':{'wall_cap_seconds':59,'cpu_cap_seconds':59,'address_space_cap_mib':512,'estimated_memory_mib':32}}
(here/'highdegree-control.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
