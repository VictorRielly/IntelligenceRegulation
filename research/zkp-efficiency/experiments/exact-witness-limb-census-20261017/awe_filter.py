"""Independent arithmetic-only filter of AWE's six-product INT8 construction.
No foreign code; mathematical coefficients from arXiv2609.24519v1 Appendix A.
No GPU/FP4 implementation, author throughput replication or native proof.
"""
from pathlib import Path
from itertools import product
import hashlib,json,os,resource,signal,time
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter()
s={0,-1,1,-2,2,-3,3,-4,4,-6,6}
enc={}
for a in product(sorted(s),repeat=3):
    planes=(*a,a[0]+a[1],a[0]+a[2],a[1]+a[2])
    if not set(planes)<=s:continue
    value=a[0]+29*a[1]+37*a[2]
    if value not in enc or (sum(x*x for x in planes),a)<(sum(x*x for x in enc[value][1]),enc[value][0]):enc[value]=(a,planes)
coverage=0
while coverage+1 in enc and -coverage-1 in enc:coverage+=1
assert coverage>=128
coeff=(-65,-261,259,29,37,1073)
digest=hashlib.sha256();checks=0;mutated=0
for x,y in product(range(-128,128),repeat=2):
    a=enc[x][1];b=enc[y][1]
    p=tuple(u*v for u,v in zip(a,b))
    z=sum(c*q for c,q in zip(coeff,p))
    assert z==x*y
    checks+=1;digest.update(f'{x},{y},{z};'.encode())
    mutated+=sum(c*q for c,q in zip((-64,*coeff[1:]),p))!=x*y
assert mutated>0
bound=(2**24)//36
assert bound*36<=2**24<(bound+1)*36
j={'status':'pass','source':'https://arxiv.org/html/2609.24519v1','published':'2026-09-21','scope':'arithmetic reproduction of one encoding only; source peak ratios are author theoretical estimates, not GPU measurements','independent_pair_checks':checks,'contiguous_symmetric_coverage':coverage,'mutated_coefficient_mismatches':mutated,'max_stored_plane_abs':6,'coefficients':coeff,'fp32_accumulator_abs_sum_K_bound':bound,'native_i32_projection_K_bound':(2**31-1)//(127*128),'author_sm120_rtx_pro6000_awe_over_native_int8_peak_ratio':1/3,'hardware_transfer_limit':'RTX PRO6000/B200 theoretical source; no5090 implementation/measurement. Six FP4 products+packing+reconstruction versus one native INT8. Do not promote reduced9->6 product count as improvement over native1.','seed':None,'deterministic':True,'wall_seconds':time.perf_counter()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'threads':1,'affinity':sorted(os.sched_getaffinity(0)),'estimated_memory_MiB':32,'AS_limit_MiB':512,'wall_cpu_limit_s':59,'output_sha256':digest.hexdigest(),'accepted_complete_8b_positions':0}
Path(__file__).with_name('awe-filter-result.json').write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(j))
