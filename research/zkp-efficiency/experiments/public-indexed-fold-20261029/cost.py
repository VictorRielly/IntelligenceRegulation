"""Source logical operands, not physical DRAM traffic or a runtime prediction."""
from pathlib import Path
import json
D=Path(__file__).resolve().parent
c=json.loads((D/'census-result.json').read_text())
out=[]
for p in c['source_profiles']:
    n=p['n'];rows=p['rows'];groups=p['groups'];chunks=(groups+3)//4
    matrix_dense=chunks*rows*n*8
    rho_dense=groups*rows*n*16
    matrix_indexed=p['union_visits']*n*8
    rho_union=p['rho_union_reads_per_column']*n*16
    rho_flags=p['rho_membership_reads_per_column']*n*16
    index_logical=p['index_bytes']*n
    base=matrix_dense+rho_dense
    plain=matrix_indexed+rho_union+index_logical
    flagged=matrix_indexed+rho_flags+index_logical
    out.append(dict(**p,dense_matrix_B=matrix_dense,dense_rho_B=rho_dense,baseline_matrix_plus_rho_B=base,indexed_matrix_B=matrix_indexed,indexed_union_rho_B=rho_union,indexed_membership_rho_B=rho_flags,index_logical_reads_B=index_logical,plain_union_total_B=plain,membership_total_B=flagged,plain_reduction=1-plain/base,membership_reduction=1-flagged/base,plan_upload_payload_B=p['index_bytes'],rho_upload_B_unchanged=groups*rows*16,logical_index_reads_amplification=n,rho_upload_eliminated=False,private_matrix_reencoding_eliminated=False,all_output_pad_mask_proximity_costs_retained=True))
result=dict(status='PASS',profiles=out,scope='One frozen R13 A core, 8B geometry T128, N16384. Full-message-width counts inferred from exact public plans and source loop; source matrix not materialized. Source logical operands before cache/compiler/broadcast. No physical traffic/time or layer multiplier.',new_verified_full_stack_proofs=0,new_model_passes=0,new_proved_positions=0,actual_context=None,modeled_context=128,accelerator=None,workload_kind='public-shape CPU component, no prefill/resident/decode',clocks={k:None for k in ['witness_s','proof_s','serialization_s','verification_s','startup_s','startup_fraction','initial_prefill_s','steady_rate','total_rate','proof_latency_s','proof_bytes']},end_to_end_ceiling='N/(T-C_removed_exclusive+A_added); exclusive f unknown, free deletion <=1/(1-f); no numerical 8B GPU estimate')
(D/'cost-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
