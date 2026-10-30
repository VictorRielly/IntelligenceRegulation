"""Guaranteed public-mask incidence bounds, NOT an actual native rho census."""
from pathlib import Path
import json,math,platform
import model,legacy_catalog
D=Path(__file__).resolve().parent
native=json.loads((D/'native/NATIVE_LAYOUT_CENSUS.json').read_text())
expected=json.loads((D.parent/'composition-eq-scope-20261029/sized-metadata.json').read_text())
out=[];checks=0;seen=set()
def cost(sets,order,b=4):
    return sum(len(set().union(*(sets[j] for j in order[i:i+b]))) for i in range(0,len(order),b))
for row in native['rows']:
    if '8b-t128' not in row['profile'] or row['profile'] in seen or row['f_e']!=9:continue
    seen.add(row['profile']);g=model.geometry(row)
    for cm in ['A','H']:
        r=row[cm.lower()+'_rows'];s=row[cm.lower()+'_sites'];base=row[cm.lower()+'_mask_base'];n=row['n']
        assert r==base+2*s+2;checks+=1
        sites=[p for slot in legacy_catalog.catalog(g) for p in legacy_catalog.schedule(slot) if p.cm==cm]
        assert len(sites)==s;checks+=1
        members={}
        for p in sites:members.setdefault((p.slot,p.tail,p.c0),[]).append(p.pair)
        groups=list(members.values())+([[]] if cm=='H' else [])
        label=('DD' if g.dd else 'nonDD')+'-'+cm
        exp=next(x for x in expected if x['label']==label)
        assert len(groups)==exp['groups'];checks+=1
        assert sorted(x for group in groups for x in group)==list(range(s));checks+=1
        # All non-site, non-proximity rows are treated as LIVE in EVERY
        # ordinary group, even if the true data-domain support is sparse.
        # Thus these are support SUPERSETS, not fabricated actual supports.
        sets=[set(range(base))|{base+2*site+k for site in m for k in [0,1]} for m in groups]
        sets.append(set(range(r))) # conservative dense proximity floor
        k=len(sets);order=list(range(k));scans=math.ceil(k/4);baseline=scans*r
        upper=cost(sets,order);last=order[(k-1)//4*4:];proxsites=sum(len(groups[j]) for j in last if j<len(groups))
        formula=(scans-1)*base+2*(s-proxsites)+r
        assert upper==formula;checks+=1
        # Bound independent of symbolic group ordering: all site pairs may
        # contribute outside the prox batch, but at most once each.
        order_free_upper=(scans-1)*base+2*s+r
        assert upper<=order_free_upper<=baseline;checks+=2
        mac_upper=sum(len(x) for x in sets);mac_formula=len(groups)*base+2*s+r
        assert mac_upper==mac_formula;checks+=1
        # Counterfactual mask-only packing. This optimizes only the dense-
        # data envelope. It is NOT a claim of optimal actual support packing.
        hot=sorted(range(len(groups)),key=lambda j:(-len(groups[j]),j))[:3]
        packed=[j for j in range(len(groups)) if j not in hot]+hot+[k-1]
        # Put a full proximity batch first so all other batches remain <=4.
        packed=hot+[k-1]+[j for j in range(len(groups)) if j not in hot]
        assert sorted(packed)==order;checks+=1
        packedupper=cost(sets,packed)
        out.append(dict(label=label,profile=row['profile'],context=128,rows=r,cols=n,ordinary_groups=len(groups),rhos=k,sites=s,mask_rows=2*s,non_site_non_proximity_rows=base,group_site_counts=list(map(len,groups)),baseline_chunk4_row_visits=baseline,mask_only_row_visit_upper_bound=upper,guaranteed_skipped_row_visits=baseline-order_free_upper,symbolic_order_skipped_row_visits=baseline-upper,guaranteed_row_visit_reduction=(baseline-order_free_upper)/baseline,symbolic_order_row_visit_reduction=(baseline-upper)/baseline,baseline_logical_matrix_bytes=baseline*n*8,mask_only_logical_matrix_byte_upper_bound=upper*n*8,baseline_fp2_base_macs=k*r*n,mask_only_fp2_base_mac_upper_bound=mac_upper*n,mask_only_packed_row_visit_upper_bound=packedupper,mask_only_packing_additional_envelope_reduction=upper-packedupper,proximity_batch_groups=last,group_sites_in_proximity_batch=proxsites,scope='R13 source geometry and symbolic generic accepted grouping; conservative all-data-live support envelope. Not actual native invocation/support density, R14 split geometry, CUDA time, physical DRAM or full proof.'))
# Negative control: an apparently better mask-only packing fragments actual
# data support and increases total row visits. Both have the same mask ownership.
counts=[20,1,1,1,20,1,1,1,20];base=1024;s=sum(counts);r=base+2*s+2;sets=[];maskat=base
for j,c in enumerate(counts):
    support=set(range(0,512)) if j<4 or j==8 else set(range(512,1024))
    sets.append(support|set(range(maskat,maskat+2*c)));maskat+=2*c
sets.append(set(range(r)));original=list(range(10));packed=[0,4,8,9,1,2,3,5,6,7]
dense_sets=[set(range(base))|(x-set(range(base))) for x in sets[:-1]]+[set(range(r))]
neg=dict(counts=counts,original_order=original,packed_order=packed,original_actual_row_visits=cost(sets,original),packed_actual_row_visits=cost(sets,packed),original_envelope_row_visits=cost(dense_sets,original),packed_envelope_row_visits=cost(dense_sets,packed))
assert neg['packed_actual_row_visits']>neg['original_actual_row_visits'];assert neg['packed_envelope_row_visits']<neg['original_envelope_row_visits'];checks+=2
result=dict(status='PASS',checks=checks,profiles=out,mask_count_packing_counterexample=neg,full_stack_proofs=0,model_passes=0,proved_positions=0,ceiling='N/(T-Cremoved_exclusive+Aadded); native exclusive rowfold fraction unknown. Bounds are logical kernel work, not an end-to-end speedup. Dense proximity, all output vectors, rho transfers, host pad folds and fresh masks remain.')
(D/'census-result.json').write_text(json.dumps(result,indent=2)+'\n')
cpu=next((x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),'unknown')
(D/'hardware.json').write_text(json.dumps(dict(cpu=cpu,worker_cpu_affinity=1,worker_threads=1,os=platform.platform(),python=platform.python_version(),gpu_jobs=0,model_context=None,model_passes=0),indent=2)+'\n')
print(json.dumps(dict(status='PASS',checks=checks,counterexample=neg)))
for x in out:print(x['label'],x['baseline_logical_matrix_bytes'],x['mask_only_logical_matrix_byte_upper_bound'],x['guaranteed_row_visit_reduction'],x['symbolic_order_row_visit_reduction'],x['mask_only_packing_additional_envelope_reduction'])
