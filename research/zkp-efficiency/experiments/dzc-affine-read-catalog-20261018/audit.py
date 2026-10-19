"""Independent closed-form accounting and source-contract audit; no proof."""
import hashlib,json,os,resource,signal,time
from pathlib import Path
H=Path(__file__).resolve().parent

def main():
    start=time.perf_counter();os.nice(19);cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu});signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    r=json.loads((H/'result.json').read_text());assert r['status']=='PASS';checks=0;rows=[]
    for q in r['catalogs']:
        ln=q['ln'];top=int(q['norm_w']%8!=0);p=int(q['padded_D'])
        lookups=18+4*ln+4*top;helpers=(lookups+1)//2
        expected={'A_columns':19+4*ln,'lookup_descriptors':lookups,'helpers':helpers,'original_tables':26+4*ln+helpers+p,'original_private_finals':21+4*ln+helpers,'linear_build_sources':17+4*ln}
        for k,v in expected.items():assert q[k]==v,(k,q[k],v);checks+=1
        assert q['candidate_online_with_L']==q['original_tables']+p;checks+=1
        assert q['omittable_names']==([] if p else ['A_X2']);checks+=1
        assert q['removable_original_fold_tables']==0 and q['generic_driver_extra_tables']==1;checks+=1
        if q['descriptor'] not in ['TinyLlama1.1B','Llama3-8B'] or p:continue
        width=2048 if q['descriptor']=='TinyLlama1.1B' else 4096;N=128*width
        # One new stream. Pair source reads 32(N-1), fold 48(N-1).
        # Instruction-level tb[i] is mentioned twice by ClosureRounds, so
        # report the source-level model separately: not a DRAM assertion.
        pairs=sum(N//2**(j+1) for j in range(N.bit_length()-1));assert pairs==N-1;checks+=1
        rows.append({'model':q['descriptor'],'context':128,'passes':0,'dimension_D':N,'baseline_tables':q['original_tables'],'generic_candidate_tables':q['original_tables']+1,'original_private_finals_retained':q['original_private_finals'],'extra_capacity_bytes':16*N,'build_generic_logical_bytes':16*N*(q['linear_build_sources']+1),'build_base_logical_bytes':8*N*q['linear_build_sources']+16*N,'extra_fold_logical_bytes':48*(N-1),'extra_pair_unique_endpoint_logical_bytes':32*(N-1),'extra_pair_source_occurrence_bytes':48*(N-1),'extra_round_step_additions_degree4':4*(N-1),'extra_fold_Fp2_products':N-1,'physical_DRAM_bytes':None,'native_timing_s':None,'scope':'Allocation-free counts. Base build requires complete typed provenance, not sampled private values. Existing originals, finals, folds, masks and extensions retained.'})
    a=(H/'native/hashline__src__private_block__argument.rs').read_text();rr=(H/'native/zkp-core__src__sumcheck__rounds.rs').read_text();s=(H/'native/hashline__src__private_block__shape.rs').read_text()
    obligations=['cur[t] = tb[i]','dif[t] = tb[i + half].sub(tb[i])','for tb in self.tables.iter_mut()','self.tables.iter().map(|t| t[0]).collect()']
    for needle in obligations:assert needle in rr;checks+=1
    for needle in ['if sp.terms.len() != n_priv','tr.absorb_fp2(b"pb-term", &terms)','for t in &def.tabs','acc.claims[p.cm as usize].push(build_claim','let d_max = isqrt_i128(i128::from(self.ceps) + width as i128 * INT16_ABS * INT16_ABS);']:
        assert needle in (s if 'd_max' in needle else a);checks+=1
    pins=[]
    for p in json.loads((H/'source-pins.json').read_text()):
        local=hashlib.sha256((H/p['snapshot']).read_bytes()).hexdigest();live=hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()
        assert local==p['sha256'];pins.append({'path':p['path'],'snapshot_sha256':local,'live_sha256':live,'unchanged':live==local})
    assert all(p['unchanged'] for p in pins)
    out={'status':'PASS','checks':checks,'counted_geometries':rows,'source_check':pins,'memory_hypothesis':'FALSIFIED for eliminating unique round input streams or existing fold/final tables in this adapter. Arithmetic benefit remains unmeasured.','native_full_proofs':0,'wall_seconds':time.perf_counter()-start,'rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'cpu_affinity':[cpu],'threads':1}
    (H/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k!='source_check'},indent=2))
if __name__=='__main__':main()
