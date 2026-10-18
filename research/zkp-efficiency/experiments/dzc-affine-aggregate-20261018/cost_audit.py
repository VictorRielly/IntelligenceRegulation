#!/usr/bin/env python3
"""Source-pinned schedule census. Counts are not timings or measured DRAM."""
import hashlib,json,os,resource,signal,time
from pathlib import Path
H=Path(__file__).resolve().parent
def main():
    t=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2);resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    r=json.loads((H/'result.json').read_text());src=(H/'native/zkp-core__src__sumcheck__rounds.rs').read_text()
    assert 'cur[t] = cur[t].add(dif[t])' in src
    assert 'claim.is_none() || cfg!(debug_assertions)' in src
    rows=[]
    for row in r['census']:
     ln=row['ln'];terms=17+4*ln;prep=row['prepare_api']
     for logn in [1,2,4,18,19,20,21]:
      N=1<<logn
      for degree in [4,5]:
       for known in [False,True]:
        # Sum actual per-round pair counts, then independently closed form.
        E=sum((N>>(i+1))*(degree+(not known and i==0)) for i in range(logn))
        assert E==degree*(N-1)+(0 if known else N//2)
        for base in [False,True]:
         before=E*(5*row['baseline_clause_api'][2]+2*row['baseline_clause_api'][3])
         after=2*prep[3]+N*terms*(2 if base else 5)+5*(N-1)+40*E
         # Native interpolation steps in additions. The earlier deliberately
         # conservative +5/E multiplication charge is retained in result.json
         # and is separated here instead of silently claiming it was measured.
         old_add=E*row['baseline_clause_api'][0];old_sub=E*row['baseline_clause_api'][1]
         new_add=prep[0]+N*(terms+1)+5*E+(N-1)+degree*(N-1)
         new_sub=prep[1]+2*(N-1)
         rows.append({'ln':ln,'logN':logn,'declared_degree':degree,'initial_claim_known':known,'sources_base_at_initial_build':base,'poly_evaluations':E,'baseline_clause_scalar_products_Rust5':before,'candidate_scalar_products_Rust5_including_prep_build_folds':after,'saved_scalar_products':before-after,'baseline_add_sub':[old_add,old_sub],'candidate_add_sub':[new_add,new_sub],'extra_table_capacity_bytes':16*N,'proof_local_coefficients_constant_bilinear_bytes':16*(terms+1+4),'build_logical_source_output_bytes':N*(terms*(8 if base else 16)+16),'extra_fold_logical_bytes':48*(N-1),'extra_round_table_source_read_bytes':32*(N-1)})
    # The inherited profile supplies an absolute deletion bound for the whole
    # D slot, not an estimate for the subexpression and not an 8B forecast.
    app=174.052;whole_d=26.691
    result={'status':'PASS','scope':'Counted exact fieldAPI/Rust-five-scalar-product model for clause path only. Includes one-time preparation, entire table construction and all added folds; original source tables/finals retained. Schedule uses native step additions. Common helper/pad/host, Eq/PCS/masks, witness, original interpolation/folds, transfers/launches, serialization and verify unchanged/unmodeled. No GPU/runtime/DRAM or peak-memory claim. Debug evaluates (degree+1)*(N-1) points and needs its own count. Base build eligibility is complete public provenance, never a sampled/private-value schedule.','rows':rows,'whole_D_phase_deletion_bound_1b_n1':{'context':128,'blocks':22,'passes':1,'app_s':app,'D_slot_s':whole_d,'fraction':whole_d/app,'delete_all_D_app_s':app-whole_d,'delete_all_D_diagnostic_positions_per_s':128/(app-whole_d),'speedup_upper_bound':app/(app-whole_d),'target8B_ceiling':None},'controls':{'closed_form_matches_round_sum':True,'generic_N2_none_claim_with_native_steps_saves':next(q for q in rows if q['ln']==4 and q['logN']==1 and q['declared_degree']==4 and not q['initial_claim_known'] and not q['sources_base_at_initial_build'])['saved_scalar_products']>0,'generic_N2_known_claim_can_lose':next(q for q in rows if q['ln']==4 and q['logN']==1 and q['declared_degree']==4 and q['initial_claim_known'] and not q['sources_base_at_initial_build'])['saved_scalar_products']<0},'wall_seconds':time.perf_counter()-t,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'threads':1,'cpu_affinity':[cpu]}
    assert all(result['controls'].values())
    (H/'cost-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='rows'},indent=2))
if __name__=='__main__':main()
