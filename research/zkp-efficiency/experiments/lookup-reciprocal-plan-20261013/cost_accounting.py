"""Source-derived counts and refreshed native diagnostic phase ceilings."""
from pathlib import Path
import json
import os
import resource
import signal

resource.setrlimit(resource.RLIMIT_AS, (512*2**20,512*2**20))
resource.setrlimit(resource.RLIMIT_CPU, (10,10))
signal.alarm(10)
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
os.nice(19)

ROOT = Path('/home/victor/IntelligenceRegulation')
HERE = Path(__file__).resolve().parent
r = json.loads((HERE/'result.json').read_text())
rows = []
for case in r['cases']:
    if case['name'] in ['large/valid','large/invalid','large/mixed','256/31/0/valid'] and case['chunk']==1024:
        n=case['length']; c=case['counts']
        old_invalid = c['fallback'] if n >= 256 else 0 # short illustrated case is all-valid
        rows.append(dict(case=case['name'], N=n, M=case['table'],
                         native_batch_mul=3*n,native_field_inversions=int(n>0),
                         prior_cycle4_field_inversions=1+old_invalid,
                         prior_cycle4_batch_mul=3*256,candidate=c))
profiles=[]
for name in ['a1-cpu','a2-cpu','b1-gpu','b2-gpu']:
    log=(ROOT/'results/zk60_sol_gpu_20260927/attempt-5-dense-ab'/(name+'.log')).read_text()
    line=next(x for x in log.splitlines() if 'H: exp + activation helper inverses' in x)
    seconds=float(line.split('|')[3])
    profiles.append(dict(run=name,pair_helper_seconds=seconds,raw_line=line,
                         scope='shared synthetic125M one-block/T512 twoCPU threads RTX4070Laptop GPU arms; retained, not reproduced'))
geometries=[]
for label,T,hp,fp in [('native_m125',512,16,2048),('unadmitted8B_arithmetic_only',512,32,16384),('unadmitted8B_T1024',1024,32,16384)]:
    s,f=hp*T*T,T*fp; n=s+f
    geometries.append(dict(label=label,T=T,h_pad=hp,f_pad=fp,exp_occurrences=s,
        act_occurrences=f,pair_occurrences=n,native_batch_multiplications=3*n,
        candidate_all_hit_batch_multiplications=3*512,native_beta_products=n,
        candidate_all_hit_beta_products=512,native_field_inversions=2,
        candidate_all_hit_field_inversions=2,unchanged_H_output_bytes=16*n,
        native_peak_den_plus_prefix_payload_bytes=32*max(s,f),
        candidate_scratch_logical_payload_bound_bytes=40*1024+17*256+48,
        activation_conversion_bytes=2048,notes=[
        'arithmetic/payload not actual peak or speed; headers/allocator/compiler stack unpriced',
        'prefix16N + in-place denominators16N; sequential exp/act peaks cannot be added',
        'native literal full Fp2 beta products; compiler specialization unmeasured',
        'all tablehelpers/masks/PCS/polynomials/extensions/witness retained']))
account=dict(source_census=dict(native_SC_SZC_byte_lookups_at_m125=15,
    native_SC_SZC_paired_byte_helpers=8,native_SC_SZC_exp_pair_helpers=1,
    byte_reciprocals='Already cached across six lookup domains per proof atprotocol889',
    exp_act_reciprocals='Still full occurrence batch at908..911; no SC_SZC bracket inversions',
    table_helper_inversion_actual_rows_per_family=256,
    table_helper_timing_mark_rows_per_family=16384,
    table_helper_mark_warning='mark reports3*sh.size(Tab); helpers call toy-size table_values* then write256 rows into zero-padded H; SC_TAB public tables expand16k separately'),
    executed_rows=rows,geometry_counts=geometries,profiles=profiles,
    ceiling=dict(reference_b2_pair_phase_seconds=.197,reference_b2_prove_seconds=16.864,
    reference_b2_whole_test_seconds=27.523873283003923,
    ideal_prove_removal_fraction=.197/16.864,
    ideal_enclosing_removal_fraction=.197/27.523873283003923,
    ideal_enclosing_seconds_after_deleting_entire_phase=27.523873283003923-.197,
    accepted8b_numeric_ceiling=None,
    formula='Nproved/(Ttotal-Cpair_old+Cplan+Creads+Cfallback+Cscatter)',
    scope='Phase deletion bounds historical synthetic oneblock only; not complete-model throughput',
    other_clocks=dict(external_witness_seconds=5.77,serialization_seconds=.028,
                     inprocess_byte_verification_seconds=.82,startup_seconds=None)),
    tradeoffs=[
    'Short N31 bypass avoids prior768vs93 setup batchmul atK1024; K1 still31 inversions',
    'Invalid257 K1024 candidate2 inversions vs prior258 vs native1; candidate1539batchmul vs native771',
    'Sparse invalid rows incur one inversion per occupied input chunk, not ceil(U/K)',
    'Padded S and future positions still carry exp table pairs; never delete them',
    'SC_SZC7.794s is largely unaffected; helper phase is distinct commitment preparation',
    'Construct privately in same attempt; no cross-challenge/table reciprocal reuse'])
(HERE/'cost-accounting.json').write_text(json.dumps(account,indent=2)+'\n')
assert profiles[-1]['pair_helper_seconds']==.197
assert geometries[0]['pair_occurrences']==5242880
assert geometries[0]['native_peak_den_plus_prefix_payload_bytes']==134217728
print(json.dumps({'profiles':[(x['run'],x['pair_helper_seconds']) for x in profiles],
                  'ideal_enclosing_removal_fraction':account['ceiling']['ideal_enclosing_removal_fraction'],
                  'native_m125_geometry':geometries[0]},indent=2))
