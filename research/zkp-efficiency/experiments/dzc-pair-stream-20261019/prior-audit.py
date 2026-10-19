#!/usr/bin/env python3
"""Independent closed-form census and allocation-free workload accounting."""
import hashlib
import json
import os
import resource
import signal
import time
from pathlib import Path

H=Path(__file__).resolve().parent

def plus(*xs):
    return [sum(x[i] for x in xs) for i in range(4)]

def times(x,n):
    return [a*n for a in x]

def weight(x):
    # Native Rust Fp2 source-level product model; NOT CUDA/PTX instructions.
    return 5*x[2]+2*x[3]

def account(c,N,known_first=False,debug=False):
    rounds=N.bit_length()-1; pairs=N-1;d=c['degree'];k=c['tables']
    E=(d+1)*pairs if debug else d*pairs+(0 if known_first else N//2)
    recoveries=0 if debug else rounds-(0 if known_first else 1)
    # Unique table differences plus unchanged original folds. Folds reread
    # endpoints in the current interface; no cached difference saving claimed.
    folds=[k*pairs,k*pairs,k*pairs,0]
    diff=[0,k*pairs,0,0]
    common_base_prep=[c['lookups'],0,(19+4*c['ln']) if c['padded'] else 0,0]
    baseline=plus(common_base_prep,diff,folds,times(c['native_point'],E),
                  [E+d*k*pairs,recoveries,0,0])
    # Five row coefficients, reduced then converted once per round. The
    # registered D4/D5 samples and recovery schedule remain unchanged.
    conversion=plus(times(c['convert_full'],rounds-recoveries),
                    times(c['convert_recovered'],recoveries))
    candidate=plus(c['prep'],diff,folds,times(c['coefficient_row'],pairs),
                   times(c['coefficient_accumulate'],pairs),conversion)
    schoolbook=plus(c['prep'],diff,folds,times(c['schoolbook_row'],pairs),
                    times(c['coefficient_accumulate'],pairs),conversion)
    return dict(N=N,rounds=rounds,known_initial_unmasked_claim=known_first,debug_evaluate_one=debug,
                pair_rows=pairs,baseline_scalar_points=E,baseline_calls=baseline,
                coefficient_calls=candidate,schoolbook_calls=schoolbook,
                baseline_scalar_products=weight(baseline),coefficient_scalar_products=weight(candidate),
                product_reduction_fraction=1-weight(candidate)/weight(baseline),
                baseline_fp2_add_sub=baseline[0]+baseline[1],
                coefficient_fp2_add_sub=candidate[0]+candidate[1],
                added_full_tables=0,removed_original_tables=0,
                retained_original_folds=k*pairs,row_coefficient_output_bytes=80,
                limitation='Source-level API/product counts only; no timing, DRAM/peak scratch/occupancy, native construction, transcripts, masking, PCS, serialization or verifier measured. Common claim interpolation unchanged/excluded; reduction/dispatch must be costed natively.')

def main():
    start=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    r=json.loads((H/'result.json').read_text());checks=0
    for p in json.loads((H/'source-pins.json').read_text()):
        b=Path(p['path']).read_bytes();assert hashlib.sha256(b).hexdigest()==p['current_sha256'];checks+=1
    s=(H/'native/zkp-core__src__sumcheck__rounds.rs').read_text()
    for marker in ['for d in 1..=degree','cur[t] = cur[t].add(dif[t])',
                   'if d != 1 || eval_one','sums[1] = claim.sub(sums[0])',
                   'self.tables.iter().map(|t| t[0]).collect()',
                   'The driver absorbs exactly one `sc-round`']:
        assert marker in s;checks+=1
    costs=[]
    for c in r['census']:
        ln=c['ln'];L=c['lookups'];K=c['helpers'];T=17+4*ln;A=19+4*ln;pad=int(c['padded'])
        odd=2*K-L;assert odd in [0,1];checks+=1
        # Independent count from 11 native clauses, K paired helper relations,
        # two hosts, equality, and the optional A-plane pad sum.
        want=[4*ln+29+4*K+pad*(A+1)-2*odd,17+3*K+pad-odd,
              24+3*K+pad*(A+1)-odd,4*ln+9+L]
        assert c['native_point']==want,(c['descriptor'],want,c['native_point']);checks+=1
        want=[2*T+10*K+36+pad*(2*A+14)-5*odd,8*K+14+4*pad-3*odd,
              2*T+13*K+44+pad*(2*A+26)-7*odd,2*L+4]
        assert c['coefficient_row']==want,(want,c['coefficient_row']);checks+=1
        n_kara=K+6+pad
        assert c['schoolbook_row']==[want[0]-n_kara,want[1]-2*n_kara,want[2]+n_kara,want[3]];checks+=1
        assert c['prep']==[T+L+9,L+20,pad*A,4*ln+14];checks+=1
        d=c['degree'];assert c['convert_full']==[4*d,0,0,4*(d-1)];checks+=1
        assert c['convert_recovered']==[4*(d-1),1,0,4*(d-1)];checks+=1
        for n in [2,8,32,262144,524288]:
          for known,debug in [(False,False),(True,False),(False,True)]:
            costs.append(dict(descriptor=c['descriptor'],padded=c['padded'],**account(c,n,known,debug)))
            checks+=1
    # Re-derive the largest current unpadded geometry without allocating data.
    c=r['census'][2];N=524288;out=account(c,N)
    assert out['baseline_scalar_points']==4*(N-1)+N//2;checks+=1
    assert out['coefficient_calls'][2]==(331+59)*(N-1);checks+=1
    assert out['coefficient_calls'][3]==72*(N-1)+12*19+30;checks+=1
    assert out['added_full_tables']==out['removed_original_tables']==0;checks+=1
    # Important negative tradeoff: after recovery the candidate uses MORE
    # extension multiplies per row: 331 versus 4*75=300 before common folds.
    assert c['coefficient_row'][2]>4*c['native_point'][2];checks+=1
    deletion_total=174.052;D=26.691
    result=dict(status='PASS',checks=checks,costs=costs,
                whole_D_deletion_ceiling=dict(scope='Carried 1.1B T128/22 blocks one-pass laptop-GPU n1 diagnostic',
                  total_seconds=deletion_total,all_D_seconds=D,
                  maximum_speedup=deletion_total/(deletion_total-D),maximum_diagnostic_positions_per_second=128/(deletion_total-D),
                  limitation='Only an upper bound deleting every D, not this schedule estimate and not an 8B ceiling.'),
                wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                cpu_affinity=[cpu],threads=1,
                source_counts='add,sub,Fp2mul,mul_base',product_model='5*Fp2mul+2*mul_base; no multiplication by count treated as measured time')
    (H/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='costs'},indent=2))
    for v in costs:
        if v['descriptor']=='Llama3-8B' and not v['padded'] and not v['debug_evaluate_one'] and v['N']==524288:
            print(json.dumps(v,indent=2))

if __name__=='__main__':main()
