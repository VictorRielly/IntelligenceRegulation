#!/usr/bin/env python3
"""Allocation-free logical accounting; no native clock or large table."""
import json,hashlib
from pathlib import Path
from fixture import limits

def geometry(T,hp):
    n=(hp.bit_length()-1)+2*(T.bit_length()-1)
    L=(hp.bit_length()-1)+(T.bit_length()-1)
    H=(1<<n)-1;active=2*n+L;before=25*H+2*((1<<L)-1);folds=3*H
    return dict(context=T,h_pad=hp,cube_log=n,leading_log=L,
      scope='conditional m125' if hp==16 else 'unadmitted 32 padded-query-head geometry',
      eq_payload_bytes_removed=3*(1<<n)*16,descriptor_point_Fp2_bytes=active*16,descriptor_scale_Fp2_bytes=48,
      eq_dense_fold_lerps_removed=folds,eq_fold_Fp2_mul_sub_add_each_removed=folds,
      scalar_active_binds_added=active,scalar_Fp2_muls_added=3*active,scalar_Fp2_subs_added=2*active,scalar_Fp2_adds_added=active,
      endpoint_Fp2_reads_removed=6*H,logical_endpoint_read_bytes_removed=6*H*16,
      row_Fp2_differences_removed=3*H,sample_Fp2_adds_removed=12*H,
      full_cube_Eq_build_Fp2_writes_removed=3*(1<<n),
      all30dense_fold_fraction_removed=folds/(30*H),prior_mixed_compact_fold_lerps=before,after_eq_fold_lerps=before-folds,
      prior_mixed_compact_fold_fraction_removed=folds/before,
      generic_total_or_census_3Eq_reads_if_called=3*(1<<n),generic_original_cube_weight_muls_if_called=active*(1<<n),
      Eq_table_build_muls_removed_if_native_eq_table=2*(2*((1<<n)-1)+((1<<L)-1)),
      exclusions=['No full geometry allocated. Logical bytes/API operations, not native traffic/peak/clocks.',
       'Point copies, metadata, enums/dispatch, allocation, liveness/dependency validation, native parallel threshold and oracle/census integration.',
       'Generic Eq readers trade stored loads for exact basis products. SC_SZC Host does not call total but census may.',
       'All other data reads/differences/sample advances/folds, grouped factors/suffix preparation/recovery/brackets/extensions, masks/PCS/witness/proof/verification remain.'])

def main():
    limits();here=Path(__file__).parent;result=json.loads((here/'result.json').read_text());checks=0
    # Independent enumeration of small loop extents, including the empty cube.
    for n in range(11):
        folded=reads=diffs=adds=0
        for j in range(n):
            for _ in range(1<<(n-j-1)):
                folded+=3;reads+=6;diffs+=3;adds+=12
        H=(1<<n)-1
        assert (folded,reads,diffs,adds)==(3*H,6*H,3*H,12*H);checks+=4
    for row in result['cost_rows']:
        H=(1<<row['cube_log'])-1
        assert row['eq_fold_lerps_removed']==3*H
        assert row['eq_endpoint_reads_removed']==6*H
        assert row['eq_row_differences_removed']==3*H
        assert row['eq_sample_additions_removed']==12*H;checks+=4
    out=dict(geometry_rows=[geometry(T,hp) for hp in (16,32) for T in (512,1024,2048,4096)],
      runtime_formula_checks=result['counts']['count_formula_checks'],independent_small_loop_formula_checks=checks,
      source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
      scope='Additional Eq removal relative to prior mixed public+compact private candidate; no native/accepted private8B result')
    (here/'cost-accounting.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({'status':'pass','checks':checks,'T512':out['geometry_rows'][0]},indent=2))

if __name__=='__main__':main()
