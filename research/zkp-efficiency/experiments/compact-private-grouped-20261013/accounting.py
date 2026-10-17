#!/usr/bin/env python3
"""Allocation-free conditional geometry accounting, NOT hardware timings."""
import json,hashlib,resource,signal,os
from pathlib import Path
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
HERE=Path(__file__).resolve().parent
result=json.loads((HERE/'result.json').read_text());checks=0
for c in result['cost_rows']:
    n,L=c['cube_log'],c['leading_log'];N,H=1<<n,1<<L
    assert c['dense_private_words']==2*N and c['compact_private_words']==2*H
    assert c['dense_private_lerps']==2*(N-1) and c['compact_private_lerps']==2*(H-1)
    # Includes this harness's cube validation + one generic total scan.
    assert c['private_reads']==10*N-8
    assert c['private_shifts']==(2*N if L else 0)+8*(N-(1<<(n-L)))
    assert c['noop_binds']==2*(n-L);checks+=6
rows=[]
for h_pad in (16,32):
 for T in (512,1024,2048,4096):
    H=h_pad*T;N=H*T;n=N.bit_length()-1;L=H.bit_length()-1
    removed=2*(N-H)
    # Current priv_table one-slice/simple path: N zero stores, H plane
    # writes, N-H broadcast writes per plane. Compact stores H per plane.
    build_writes_old=4*N;build_writes_new=2*H
    rows.append(dict(context=T,h_pad=h_pad,cube_log=n,leading_log=L,
        scope='conditional m125 h_pad16' if h_pad==16 else 'conditional 32 padded query-head geometry; unadmitted full8B profile',
        dense_two_private_bytes=2*N*16,compact_two_private_bytes=2*H*16,
        private_payload_bytes_removed=removed*16,
        dense_two_private_fold_lerps=2*(N-1),compact_two_private_fold_lerps=2*(H-1),
        fold_Fp2_mul_sub_add_each_removed=removed,
        all30_dense_table_folds_before=30*(N-1),all30_dense_table_folds_after=28*(N-1)+2*(H-1),
        all30_fold_fraction_removed=removed/(30*(N-1)),
        mixed_public_baseline_dense27_folds=27*(N-1),mixed_after_dense25_plus_compact=25*(N-1)+2*(H-1),
        mixed_baseline_fold_fraction_removed=removed/(27*(N-1)),
        unchanged_two_private_grouped_endpoint_reads=4*(N-1),
        private_reader_index_shifts_added=4*(N-(1<<(n-L))),
        noop_bind_calls_added=2*(n-L),
        private_total_reads_if_needed=2*N,private_total_index_shifts_if_needed=2*N,
        two_private_build_source_Fp_reads_unchanged=2*H,
        dense_build_Fp2_writes=build_writes_old,compact_build_Fp2_writes=build_writes_new,
        logical_build_write_bytes_removed=(build_writes_old-build_writes_new)*16,
        logical_build_broadcast_read_bytes_removed=removed*16,
        dense_cube_index_loop_visits_removed=2*N,
        original_map_metadata_entries_avoided=2*((1<<((L+1)//2))+(1<<(L//2))),
        row_differences_sample_advances_and_brackets='all unchanged',
        extension_rounds_original_Priv_sites='all unchanged, arbitrary private targets',
        exclusions=['Metadata/enum dispatch/allocator/capacity/compiler/parallel thresholds',
                    'Actual DRAM and source maps traffic; peak overlap/census/debug oracle clones',
                    'Other tables/commitments/masks/PCS/witness/proof/serialization/verification clocks']))
out=dict(formula_checks=checks,geometry_rows=rows,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    scope='No large geometry allocated; logical source-pinned counts, not peak/time/accepted private8B throughput')
(HERE/'cost-accounting.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(dict(formula_checks=checks,T512=rows[0]),indent=2))
