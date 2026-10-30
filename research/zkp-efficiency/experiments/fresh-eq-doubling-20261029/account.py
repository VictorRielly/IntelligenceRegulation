"""Source-derived incidence; no time, device or full-proof prediction."""
from pathlib import Path
from collections import Counter
import json,time,resource,statistics
import model,legacy_catalog as base
H=Path(__file__).resolve().parent;start=time.monotonic();checks=0
def ck(v,label):
 global checks
 checks+=1
 if not v:raise AssertionError(label)
def counts(logs):
 logs=list(logs);nodes=sum((1<<n)-1 for n in logs);dims=sum(logs)
 return dict(calls=len(logs),log_histogram=dict(Counter(logs)),entries=sum(1<<n for n in logs),nodes=nodes,
 native_fp2_products=2*nodes,candidate_fp2_products=nodes,removed_fp2_products=nodes,
 native_fp2_subtractions=dims,candidate_fp2_subtractions=nodes,net_added_fp2_subtractions=nodes-dims,
 removed_base_products=5*nodes,removed_base_additions=2*nodes,net_added_base_subtractions=2*(nodes-dims),
 initialized_bytes=16*sum(1<<n for n in logs),node_read_bytes=16*nodes,node_write_bytes=32*nodes,
 reverse_copy_bytes=16*dims,vector_constructions_retained=2*len(logs),
 nonempty_vector_payload_allocations_retained=len(logs)+sum(n>0 for n in logs))
rows=json.loads((H/'native/NATIVE_LAYOUT_CENSUS.json').read_text())['rows'];seen=set();costs=[]
for row in rows:
 key=row['profile'],row['f_e']
 if key in seen:continue
 seen.add(key);g=model.geometry(row);sites=[p for ss in base.catalog(g)for p in ss];cm=Counter(p.cm for p in sites)
 ck(cm['A']==row['a_sites']and cm['H']==row['h_sites'],'native site census')
 fixed=counts(sum(kind=='fixed'for kind,_ in p.coords)for p in sites)
 masks=counts(min(p.log,p.row)for p in sites)
 # Partial static PCS scope: one row Eq per data slice with ls>=row.
 # At log0 native builds [1] without products; mask parts have zero row vars.
 pcs_row=counts(p.log-p.row for p in sites for _ in range(2 if p.cm=='H'else 1)if p.log>=p.row)
 for c in [fixed,masks,pcs_row]:
  ck(c['entries']-c['calls']==c['nodes'],'per-table nodes identity')
  ck(c['native_fp2_products']-c['candidate_fp2_products']==c['removed_fp2_products'],'product reduction')
 private_reads=sum((2 if p.cm=='H'else 1)*(1<<p.log)for p in sites)
 costs.append(dict(profile=row['profile'],f_e=row['f_e'],tokens=row['tokens'],dd=bool(g.dd),sites=len(sites),
  fixed_eq=fixed,mask_eval_eq=masks,pcs_data_row_eq_partial=pcs_row,private_base_reads_retained=private_reads,
  total_model_layers_not_applied=True,unaccounted='Public Tab::Eq, weight folding, MLE evaluations, grouped sumcheck Eq builders, PCS unique column keys, verifier and token stages. Counts are source metadata, not executed native constructors or actual call clocks. PCS mask row log0 calls excluded; grouping retains all data-row builds.'))

# Independent execution trace for operation formulas, separate from closed form.
trace=[]
for n in range(23):
 length=1;oldmul=newmul=oldsub=newsub=reads=writes=0
 for _ in range(n):
  oldsub+=1
  # Enumerate nodes without allocating field tables.
  for _ in range(length):oldmul+=2;newmul+=1;newsub+=1;reads+=1;writes+=2
  length*=2
 c=counts([n]);ck(oldmul==c['native_fp2_products'],'native op trace');ck(newmul==c['candidate_fp2_products'],'candidate op trace');ck(oldsub==c['native_fp2_subtractions']and newsub==c['candidate_fp2_subtractions'],'sub trace');ck(reads*16==c['node_read_bytes']and writes*16==c['node_write_bytes'],'same dataflow')
 trace.append(dict(log=n,native_products=oldmul,candidate_products=newmul,native_subtractions=oldsub,candidate_subtractions=newsub))
r=json.loads((H/'result.json').read_text());summary=[]
for b in r['bench']:
 a=statistics.median(b['native_ns']);c=statistics.median(b['candidate_ns']);summary.append(dict(log=b['log'],entries=b['entries'],native_median_ns=a,candidate_median_ns=c,serial_helper_ratio=a/c))
(H/'costs.json').write_text(json.dumps(costs,indent=2)+'\n');(H/'operation-traces.json').write_text(json.dumps(trace,indent=2)+'\n');(H/'diagnostic-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
result=dict(status='PASS',checks=checks,geometries=len(costs),registry_rows=len(rows),operation_traces=len(trace),elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 diagnostic_faster_rows=sum(x['serial_helper_ratio']>1 for x in summary),diagnostic_rows=len(summary),
 end_to_end_ceiling='N/(T-C_removed_exclusive+A_added); for exclusive phase fraction f and measured native phase ratio k: speedup=1/((1-f)+f/k). No f or k measured for native prover/GPU.',
 startup_fraction=None,steady_tokens_per_s=None,total_tokens_per_s=None,full_stack_proofs=0,model_passes=0,proved_positions=0,gpu=False)
(H/'account-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
for c in costs:
 if c['tokens']==128 and 'llama-3-8b' in c['profile']:
  print(json.dumps(dict(profile=c['profile'],f_e=c['f_e'],dd=c['dd'],sites=c['sites'],fixed_eq_removed=c['fixed_eq']['removed_fp2_products'],mask_eq_removed=c['mask_eval_eq']['removed_fp2_products'],pcs_data_row_removed_partial=c['pcs_data_row_eq_partial']['removed_fp2_products'],private_reads_retained=c['private_base_reads_retained'])))
