"""Feed actual legacy opening coefficients to Fable's exact rank arithmetic.
Per-column vector/proximity observations only: terminals and cross-column
constraints are excluded. This is a lower-bound diagnostic, not joint privacy.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

ROOT=Path('/home/victor/IntelligenceRegulation')
OUT=Path('/tmp/zk60-round11')
path=ROOT/'scripts/zk60_fable_joint_rank.py'
spec=importlib.util.spec_from_file_location('fable_rank',path)
f=importlib.util.module_from_spec(spec);sys.modules[spec.name]=f;spec.loader.exec_module(f)
report={'schema':1,'kind':'actual-legacy-per-column-rank','coefficient_source':'fully verified Rust A/H/W public captures',
    'tool_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'cases':[],
    'limits':['Only group-vector message coordinates and proximity are modeled, one column at a time.',
        'Individual terminal values, cross-column zero-sum constraints, pads, sampled columns, CFS messages and repeats are excluded.',
        'No disclosure upper bound, simulator or repaired-profile acceptance follows. H rank zero refers only to this observation subset.']}

def span(p,n,log_n):
    length=1<<p['log_size'];assert length>=n and p['offset']%n==0
    start=p['offset']//n
    weights=f.eq_table_msb(p['point'][:p['log_size']-log_n]) if p['point'] else [f.ONE]*(length//n)
    assert len(weights)==length//n
    return [(start+i,w) for i,w in enumerate(weights)]

for file in sorted((OUT/'observations').glob('*.json')):
    capture=json.loads(file.read_text())
    for o in capture['roles']:
        rows=o['commitment']['rows'];ln=o['params']['log_cols'];n=1<<ln
        kinds={}
        for ci,c in enumerate(o['claims']):
            if not c['parts'][0]['point']:continue # H's all-column LogUp sum
            for pi,p in enumerate(c['parts']):
                kind='data' if pi < (2 if o['role']=='H' else 1) else 'mask'
                if o['role']=='H' and ci==4:kind='mask' # public layout: zero-sum u and its u-prime mask
                for row,_ in span(p,n,ln):
                    assert row<rows
                    if row in kinds:assert kinds[row]==kind
                    kinds[row]=kind
        unused=set(range(rows))-kinds.keys();assert len(unused)==1 # sole legacy proximity row
        for row in unused:kinds[row]='mask'
        data=[r for r in range(rows) if kinds[r]=='data'];masks=[r for r in range(rows) if kinds[r]=='mask']
        observations=[]
        for g in o['groups']:
            coefficients=[f.ZERO]*rows
            for ci,lam in zip(g['members'],g['lambdas']):
                for p in o['claims'][ci]['parts']:
                    factor=f.f2_mul(lam,p['coefficient'])
                    for row,weight in span(p,n,ln):
                        coefficients[row]=f.f2_add(coefficients[row],f.f2_mul(factor,weight))
            observations.append(coefficients)
        observations.append(o['proximity_rhos'])
        base=[[c[k] for c in obs] for obs in observations for k in (0,1)]
        b=[[obs[r] for r in masks] for obs in base]
        a_b=[[obs[r] for r in data+masks] for obs in base]
        rank_b=f.rank(b);rank_joint=f.rank(a_b);leak=rank_joint-rank_b
        assert leak=={'A':2,'H':0,'W':2}[o['role']],(file.name,o['role'],leak)
        report['cases'].append({'proof_sha256':capture['proof_sha256'],'capture_sha256':hashlib.sha256(file.read_bytes()).hexdigest(),
            'privacy':capture['privacy'],'shape':capture['shape'],'role':o['role'],'message_columns':n,
            'data_rows':len(data),'mask_rows':len(masks),'base_observation_rows':len(base),
            'rank_mask':rank_b,'rank_joint':rank_joint,'disclosed_base_functionals_per_column':leak})
assert len(report['cases'])==30
(OUT/'captured_rank.json').write_text(json.dumps(report,indent=2)+'\n')
print('30 actual-coefficient per-column cases: A 2, H 0, P3 W 2; restricted observation subset only')
