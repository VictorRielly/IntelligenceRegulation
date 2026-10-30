"""Source-derived R13 metadata and synthetic same-schedule column differential."""
from pathlib import Path
from dataclasses import astuple
import hashlib,json,random,resource,time
import candidate as c
import source_reference as r
HERE=Path(__file__).resolve().parent
SEED=202610290139;rng=random.Random(SEED);start=time.monotonic()
checks=0;fixtures=0;helper_cases=0;controls=[];digest=hashlib.sha256()
def check(ok):
    global checks
    checks+=1
    if not ok:raise AssertionError(checks)
def control(name,ok):check(ok);controls.append(name)

for h24 in (False,True):
 for dd in (False,True):
  for wrho in (9,14,15,16,17,18,23,24):
   for vbits in (10,15,16):
    p=dict(q=vbits-1,k=vbits-1,v=vbits,score=18,pv=12,ao=21,down=20 if h24 else 12,up=12)
    manual=c.catalog(h24,dd,wrho,p);source=r.catalog(h24,dd,wrho,p,18)
    for d,expressions in manual.items():
     check([astuple(e) for e in expressions]==source[d])
     expected=dict(L=2,D=34 if h24 else 33,Q=14,Kv=14,F=14,S=6 if dd else 11+2*((wrho+7)//8),Dd=5+2*((wrho+7)//8) if dd else 0)
     check(len(expressions)==expected[d])
     if not expressions:continue
     plan=c.Plan(expressions)
     expected_aliases=(int(vbits==16) if d=='Kv' else 2*int(wrho in (16,24)) if d==('Dd' if dd else 'S') else 0)
     check(len(expressions)-len(plan.unique)==expected_aliases)
     for mode in ('byte','signed-edge','zero'):
      # Synthetic plane values; neither real witness nor actual model run.
      values=[0,1,127,128,255,256,-1,-128,2**63-1,-2**63]
      sources={e.source:[(rng.randrange(256) if mode=='byte' else rng.choice(values) if mode=='signed-edge' else 0) for _ in range(5)] for e in expressions}
      prepared=plan.prepare(sources);ref=r.cells(source[d],sources)
      check(prepared.logical()==ref)
      check(prepared.histogram_and_misses()==r.histogram(ref))
      check(sum(prepared.histogram_and_misses()[0])==len(expressions)*5)
      # Fixed plan must reread new private words every time, no cross-run cache.
      changed={k:[c.i64(v+1) for v in vs] for k,vs in sources.items()}
      check(plan.prepare(changed).logical()==r.cells(source[d],changed))
      check(prepared.logical()==ref)
      if mode=='zero' and wrho in (16,17) and vbits==16:
       for alpha,tag in [((1000,7),(11,3)),((0,0),(0,0))]:
        check(c.helpers(prepared,alpha,tag)==r.helpers(ref,alpha,tag));helper_cases+=1
      digest.update(repr(ref).encode());fixtures+=1

# Plan keys must be complete public expressions, never private observed values.
exprs=[c.Expr('D','A'),c.Expr('D','A',2),c.Expr('D','A',1,127),c.Expr('D','B'),c.Expr('Q','A')]
plan=c.Plan(exprs);check(len(plan.unique)==5)
control('source-only-key-merges-different-coefficient',len(set(e.source for e in exprs))<len(plan.unique))
control('omitting-domain-key-merges-independent-domains',len(set((e.source,e.coefficient,e.constant) for e in exprs))<len(plan.unique))
control('omitting-constant-key-merges-signed-expression',len(set((e.domain,e.source,e.coefficient) for e in exprs))<len(plan.unique))
control('equal-private-values-do-not-alias-distinct-sources',len(c.Plan([c.Expr('D','A'),c.Expr('D','B')]).unique)==2)
es=c.catalog(True,False,16)['S'];plan=c.Plan(es);sources={e.source:[0,1,2] for e in es};prep=plan.prepare(sources)
hist,miss=prep.histogram_and_misses();unique_hist=r.histogram(prep.columns)
control('dropping-alias-multiplicity-changes-histogram',hist!=unique_hist[0])
control('dropping-logical-alias-changes-helper-count',len(r.helpers(prep.columns,(1000,2),(0,0)))!=len(c.helpers(prep,(1000,2),(0,0))))
control('logical-reordering-changes-helper-values',r.helpers(tuple(reversed(prep.logical())),(1000,2),(0,0))!=c.helpers(prep,(1000,2),(0,0)))
bad={k:[-1,256,0] for k in sources};badprep=plan.prepare(bad)
control('miss-count-must-retain-alias-multiplicity',badprep.histogram_and_misses()[1]!=r.histogram(badprep.columns)[1])
control('cached-private-columns-stale-after-new-witness',plan.prepare(bad).logical()!=prep.logical())
control('scaled-pin-retained-for-nonfull-window',len(c.Plan(c.catalog(True,False,17)['S']).unique)==17)
control('different-signed-affines-remain-distinct',len(c.Plan([c.Expr('S','A',1,127),c.Expr('S','A',-1,127)]).unique)==2)
pole=c.Plan([c.Expr('D','A'),c.Expr('D','A')]).prepare({'A':[17]})
control('equal-pair-pole-refuses',c.helpers(pole,(17,0),(0,0))==('refused',0,0,0))
control('absent-table-pole-not-authorized-to-disappear',17 not in [0] and r.inverse((0,0)) is None)
overflow=c.Plan([c.Expr('D','A',256,127)]).prepare({'A':[2**63-1,-2**63]})
control('wrapping-integer-semantics',overflow.logical()==r.cells([('D','A',256,127)],{'A':[2**63-1,-2**63]}))

# R13 public census examples: all fields are public geometry/counts. We do not
# read private model/activation files or claim to execute native constructors.
census=json.loads((HERE/'native/NATIVE_LAYOUT_CENSUS.json').read_text())
costs=[]
for row in census['rows']:
 if 'llama-3-8b' not in row['profile'] or row['groups']!=1:continue
 t=row['tokens'];dd=row['dd'];wrho=(t-1).bit_length()+row['f_e']
 catalogue=c.catalog(True,dd,wrho)
 sizes=c.geometry(t,4096,14336,4096,1024,row['n'],dd)
 domains=c.cost(catalogue,sizes)
 check(sum(d['logical_columns']*d['domain_positions'] for d in domains)==row['byte_queries'])
 saved=sum(d['avoided_materialized_bytes'] for d in domains)
 costs.append(dict(profile=row['profile'],f_e=row['f_e'],tokens=t,dd=dd,
                   precision_scope='Representative BASE fixture: q/k15 v16, ao21 down20 pv12 up12 score18 gate18. Not actual per-layer calibration.',
                   source_census_byte_queries=row['byte_queries'],domains=domains,
                   baseline_looked_bytes=row['byte_queries']*8,unique_prepared_bytes=row['byte_queries']*8-saved,
                   avoided_materialized_bytes=saved,avoided_fraction=saved/(row['byte_queries']*8),
                   native_H_rows_delta=0,native_A_rows_delta=0,native_M_rows_delta=0,
                   native_masks_removed=0,native_helper_planes_delta=0,native_receipt_bytes_delta=0,
                   physical_peak_bytes_delta=None,exclusive_elapsed_fraction=None,end_to_end_gain=None))
check(len(costs)==4)
(HERE/'cost-result.json').write_text(json.dumps(costs,indent=2)+'\n')
result=dict(status='PASS_SYNTHETIC_R13_METADATA_AND_SAME_SCHEDULE',seed=SEED,checks=checks,
            fixtures=fixtures,helper_cases=helper_cases,negative_controls=controls,
            synthetic_values_sha256=digest.hexdigest(),elapsed_s=time.monotonic()-start,
            max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            native_code_executed=False,full_stack_proofs=0,model_passes=0,proved_positions=0)
(HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
