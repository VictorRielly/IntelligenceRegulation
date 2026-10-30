"""Geometry-matched synthetic row validation, independently known sparse f/g.

Not native execution, not proof timing; every expanded output checked.
"""
import os, resource, signal, time, json, hashlib
from pathlib import Path
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
os.nice(19)
resource.setrlimit(resource.RLIMIT_CPU,(40,40))
resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2))
signal.alarm(45)
from candidate import split, materialized
HERE=Path(__file__).resolve().parent
p=18446744069414584321
t0=time.perf_counter()
checks=0
def sparse_eval(terms, count, h):
    # Independent sparse polynomial recurrence, no NTT/interpolation/folding.
    omega=pow(7,(p-1)//count,p)
    a=[0]*count
    for exponent, coefficient in terms:
        step=pow(omega,exponent,p)
        value=coefficient*pow(h,exponent,p)%p
        for k in range(count):
            a[k]=(a[k]+value)%p
            value=value*step%p
    return a

rows=[]
for n in (4096,8192,16384):
    N=4*n;q=256;h=7
    ft=[(0,p-1),(1,3),(n//2-1,p-2),(n-2,17),(n-1,p-11)]
    gt=[(0,1),(1,p-1),(q-1,23)]
    msg=sparse_eval(ft,n,1)
    pad=[0]*q
    for j,v in gt:pad[j]=v
    f=sparse_eval(ft,N,h);g=sparse_eval(gt,N,h)
    omega=pow(7,(p-1)//N,p)
    step=pow(omega,n,p);xn=pow(h,n,p)
    ref=[]
    for k in range(N):
        ref.append((f[k]+(xn-1)*g[k])%p)
        xn=xn*step%p
    got=split(msg,pad,4,h)
    literal=materialized(msg,pad,4,h)
    for a,b,c in zip(got,ref,literal):
        checks+=1
        assert a==b==c, (n,checks)
    rows.append(dict(n=n,expanded_length=N,q=q,rate=4,h=h,
        full_output_sha256=hashlib.sha256(b''.join(x.to_bytes(8,'little') for x in got)).hexdigest(),
        known_f_terms=ft,known_g_terms=gt))
result=dict(status='PASS_GEOMETRY_MATCHED_SYNTHETIC_ROWS',checks=checks,rows=rows,
    elapsed_s=time.perf_counter()-t0,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    cpu_affinity=sorted(os.sched_getaffinity(0)),threads=1,nice=19,
    cpu_limit_s=40,alarm_s=45,address_space_mib=256,estimated_memory_mib=64,
    native_execution=False,gpu_execution=False,model_context=None,complete_verified_proofs=0)
(HERE/'large-row-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
