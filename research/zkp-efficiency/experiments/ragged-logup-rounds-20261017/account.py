"""Closed-form large geometry only. Never allocates an 8B fixture."""
from pathlib import Path
import datetime,json,os,resource,signal,time
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();prior=json.loads((H/'prior-accounting.json').read_text());fs=json.loads((H/'fixtures.json').read_text())
def geometry(n,c):
 w=1<<(c-1).bit_length()
 # MSB column bits first mix padding in round zero; row first retains columns.
 return dict(rows=n,columns=c,padded_columns=w,queries=n*c,dense_pairs=n*w-1,column_first_pairs=n*w-1,row_first_pairs=c*(n-1)+w-1)
# Independently check formulas against every complete rectangular small fixture.
checked=0
for f in fs:
 if not f['tag'].startswith(('column_first-N','row_first-N')):continue
 layout,n,c=f['tag'].split('-');n=int(n[1:]);c=int(c[1:]);g=geometry(n,c)
 assert sum(f['pair_visits'])==g[layout+'_pairs'];checked+=1
groups=[dict(domains=d,**geometry(n,c))for d,n,c in [('L',8192,2),('D+Q',131072,47),('Kv+S',32768,25),('F',524288,9)]]
q=sum(g['queries']for g in groups);dense=sum(g['dense_pairs']for g in groups);rag=sum(g['row_first_pairs']for g in groups)
assert q==prior['U8_queries'] and q==11714560
out=dict(status='PASS',label='COUNTED unmasked base arithmetic geometry only; not native executed work or a proof/GKR implementation.',context=32,groups=groups,small_formula_checks=checked,total_queries=q,dense_pairs=dense,column_first_pairs=dense,row_first_pairs=rag,pairs_avoided=dense-rag,fraction_pairs_avoided=(dense-rag)/dense,conditional_pair_count_ratio=dense/rag,
 baseline_dense_factor_payload_bytes=3*(dense+4)*16,row_first_factor_payload_bytes=3*q*16,full_expanded_public_weight_bytes=q*16,naive_index_plus_three_factor_payload_bytes=q*(8+3*16),
 costs_not_in_pair_counts=['public support generation/validation and indexing','BTreeMap allocation and comparison traffic (prototype only)','per-column distinct-point initial reduction and final ordered original-A/wrapping links','PCS encoding/opening/serialization and GPU transfers','full-cube fresh CFS masks, extension rounds and final openings','joint-view hiding and workload soundness accounting'],
 native_protocol_change='Both are new batched lookup layouts. Row-first is not a byte-preserving change to the frozen native relation, proof schedule or PCS geometry.',
 hidden_support='Only fixed public shape padding may compact. Hidden prompt lengths, token selectors, witness sparsity and private mask rows are not public support.',
 owner_clocks=prior['owner_clocks'],conditional_8b_direct_H_phase_deletion_ceiling=prior['owner_clocks']['conditional_fixed_other_work_ceiling_ratio'],
 new_target_compliant_proofs=0,new_target_compliant_positions=0,passes=0,steady_state_rate=None,total_workload_target_rate=None,wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'accounting.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:out[k]for k in ['groups','dense_pairs','row_first_pairs','pairs_avoided','fraction_pairs_avoided','conditional_pair_count_ratio','row_first_factor_payload_bytes','naive_index_plus_three_factor_payload_bytes']},indent=2))
