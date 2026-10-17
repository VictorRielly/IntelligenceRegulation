#!/usr/bin/env python3
"""Literal API count study; includes unchanged table folds, excludes timing."""
import json,hashlib,resource,signal,os
from pathlib import Path
from field import F
from source_port import layout,bracket

resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
HERE=Path(__file__).resolve().parent
r=json.loads((HERE/'result.json').read_text());cfg=layout(ls=3,lp=2,padded=True)
v=[F(3,5) for _ in cfg['names']]
const={n:F(7,11) for n in ['alpha','beta','gexp','gu8','lam','nu0','nu1','zeta','mupad']+['mu'+str(j) for j in range(6+cfg['helpers'])]}
ops=[dict(bracket(g,v,cfg,const)[1]) for g in range(3)];rows=[]
for row in r['geometry_counts']:
    n,l=row['cube_log'],row['ht_log'];old=row['baseline_bracket_calls'];new=row['collapsed_bracket_calls']
    old_weight=3*((1<<n)-1);new_weight=2*((1<<n)-1)+((1<<l)-1)
    old_aggregate=sum(old);new_aggregate=sum(new)-(n-l)
    unchanged_folds=len(v)*((1<<n)-1)
    before=sum(c*(op.get('mul',0)+1) for c,op in zip(old,ops))+old_weight+unchanged_folds
    after=sum(c*op.get('mul',0) for c,op in zip(new,ops))+new_aggregate+new_weight+unchanged_folds
    before_base=sum(c*op.get('mul_base',0) for c,op in zip(old,ops))
    after_base=sum(c*op.get('mul_base',0) for c,op in zip(new,ops))+3*n
    lowered_before=5*before+2*before_base;lowered_after=5*after+2*after_base
    rows.append({**row,'per_bracket_literal_API_counts':ops,'unchanged_private_Eq_public_fold_Fp2_muls':unchanged_folds,
        'Fp2_mul_API_before':before,'Fp2_mul_API_after':after,'Fp2_mul_API_removed':before-after,
        'Fp2_mul_API_fraction_removed':(before-after)/before,
        'five_reduction_base_mul_before':lowered_before,'five_reduction_base_mul_after':lowered_after,
        'five_reduction_base_mul_fraction_removed':(lowered_before-lowered_after)/lowered_before,
        'base_multiplicity_scalings_added':3*n,'extra_host_differences':2*((1<<l)-1),
        'extra_host_sample_additions':4*((1<<l)-1),'extra_reader_payload_bytes':row['extra_host_endpoint_reads']*16,
        'peak_scratch':'O(degree) scalars, no compact private table allocated; split equality tables unchanged',
        'exclusions':['Full-row differences/sample advances, factor/preparation/inversion, group interpolation/recovery/reduction, extensions, construction/census/verifier, masks/PCS/witness/transfer/serialization/independent verification',
                      'Literal API counts: optimizer may remove constants/zero operations. Five-base-multiply lowering is a conditional source model, not measured instructions or time.']})
# Formula must match actually counted small full-extension fixtures.
checks=0
for row in r['cost_rows']:
    if row['mode']!='full':continue
    n,l=row['cube_log'],row['ht_log'];old=[0,0,0];new=[0,0,0]
    for j in range(n):
        half=1 << (n-j-1);samples=[5,3,3] if j==0 or row['debug'] else [4,2,2]
        old=[a+half*s for a,s in zip(old,samples)];new[0]+=half*samples[0];new[2]+=half*samples[2]
        new[1]+=(1 << (l-j-1))*samples[1] if j<l else 1
    assert old==row['baseline_calls'] and new==row['collapsed_calls'];checks+=1
out=dict(geometry_rows=rows,per_bracket_table_count=len(v),formula_checks=checks,
         source_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
         scope='Conditional m125 h_pad16/ls3/lp2 count geometry, not accepted model/profile or timing')
(HERE/'cost-accounting.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({'formula_checks':checks,'T512':rows[0]},indent=2))
