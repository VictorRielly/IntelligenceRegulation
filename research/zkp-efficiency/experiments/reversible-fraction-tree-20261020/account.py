"""Bounded symbolic forest census; allocates no native-size witness arrays."""
from pathlib import Path
import json,resource,signal,os,time

resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
from reversible import capacities

HERE=Path(__file__).resolve().parent
start=time.monotonic()
rows=[]
prior=json.loads((HERE/'prior-selected.json').read_text())
for fixture in json.loads((HERE/'inputs.json').read_text()):
    sizes=fixture['sizes'];nodes=sum(n-1 for n in sizes);layers=sum(n.bit_length()-1 for n in sizes)
    row={k:fixture[k] for k in ['model','T','dd','scope','old_U8_helper_bytes']}
    row.update(columns_including_global_table=len(sizes),source_leaf_reads=sum(sizes),
               internal_nodes=nodes,layers=layers,
               build_Fp2_muls=3*nodes,build_Fp2_adds=nodes,
               individual_restore_Fp2_muls=3*nodes,individual_restore_inversions=nodes,
               batch_restore_Fp2_muls=6*nodes-3*layers,batch_restore_inversions=layers,
               restore_Fp2_subtractions=nodes,
               tree_node_reads_by_q={str(q):sum(sum((min(q,d-1)+1)*(1<<d) for d in range(1,n.bit_length())) for n in sizes) for q in range(5)},
               plans=[max([capacities(n,q) for n in sizes],key=lambda x:x['selected_peak_E']) for q in range(5)])
    old=next(p for p in prior if (p['model'],p['T'],p['dd'])==(fixture['model'],fixture['T'],fixture['dd']))
    row['prior_selected']=old
    row['prior_leaf_reads_avoided']=old['leaf_generations']-sum(sizes)
    row['new_private_masks_claims_PCS_cost']=None
    row['histogram_creation_original_A_owners_cache_costs']='Retained obligations; excluded from selected-array census'
    row['scope_limit']='Symbolic payload and field-operation counts; no timing, native allocation, privacy proof or GPU fit'
    rows.append(row)
out=dict(status='PASS',profiles=rows,elapsed_s=time.monotonic()-start,
         maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
         limits={'threads':1,'address_space_MiB':512,'CPU_s':59,'alarm_s':59,'estimated_MiB':32})
(HERE/'forest-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:v for k,v in out.items() if k!='profiles'}))
