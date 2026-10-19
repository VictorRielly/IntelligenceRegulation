#!/usr/bin/env python3
"""Independent trace/accounting audit; no candidate arithmetic imports."""
import collections
import hashlib
import json
import os
import resource
import signal
import time
from pathlib import Path

H=Path(__file__).resolve().parent

def interval_peak(nodes,output,denominators=False,retain_denominators=False,include_external=False):
    # Each node occupies [birth, final consumer], inclusive. Reconstruct all
    # consumers independently of the saved last-use implementation.
    uses=collections.defaultdict(list)
    for n in nodes:
        for j in n['deps']:
            assert 0<=j<n['id']
            uses[j].append(n['id'])
    uses[output].append(len(nodes))
    if retain_denominators:
        for n in nodes:
            if n['label']=='denominator':uses[n['id']].append(len(nodes))
    delta=collections.Counter()
    for n in nodes:
        if (n['external'] and not include_external) or (denominators and n['label']!='denominator'):continue
        end=max(uses[n['id']],default=n['id'])
        delta[n['id']]+=n['words'];delta[end+1]-=n['words']
    live=peak=0
    for i in range(len(nodes)+2):
        live+=delta[i];peak=max(peak,live)
    assert live==0
    return peak

def main():
    start=time.perf_counter();os.nice(19)
    cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
    r=json.loads((H/'result.json').read_text())
    traces=json.loads((H/'traces.json').read_text())
    checks=0;accounting=[]
    for q in json.loads((H/'source-pins.json').read_text()):
        assert hashlib.sha256(Path(q['path']).read_bytes()).hexdigest()==q['cycle77_sha256'];checks+=1
    for c,t in zip(r['census'],traces):
        assert (c['descriptor'],c['padded'])==(t['descriptor'],t['padded']);checks+=1
        L,K=c['lookups'],c['helpers'];assert K==(L+1)//2;checks+=1
        for name in ['bank','pair']:
            ns=t[name];life=t[name+'_lifetime']
            assert [n['id'] for n in ns]==list(range(len(ns)));checks+=1
            assert sum(n['label']=='original_endpoint_pair' for n in ns)==c['tables'];checks+=1
            assert sum(n['label']=='denominator' for n in ns)==L;checks+=1
            assert interval_peak(ns,life['output'])==life['peak_scratch_fp2_words'];checks+=1
            assert interval_peak(ns,life['output'],True)==life['denominator_peak_fp2_words'];checks+=1
        signature=lambda ns:collections.Counter((n['label'],n['words'],len(n['deps']),n['external']) for n in ns)
        assert signature(t['bank'])==signature(t['pair']);checks+=1
        # Closed forms derived from the complete helper dependency chain:
        # bank holds 2L denominator coefficients + 3 clause coefficients +
        # 1 zero helper accumulator + 3/4/4 helper product/relation buffers.
        assert c['bank_peak_words']==2*L+11;checks+=1
        assert c['pair_peak_words']==18;checks+=1
        assert c['bank_denominator_words']==2*L;checks+=1
        assert c['pair_denominator_words']==4;checks+=1
        # Negative: streaming source order cannot lower retention if some
        # later user still needs EVERY denominator. This audit catches it.
        assert interval_peak(t['pair'],t['pair_lifetime']['output'],True,True)==2*L;checks+=1
        assert interval_peak(t['pair'],t['pair_lifetime']['output'],False,True)>18;checks+=1
        assert c['common_endpoint_words']==2*c['tables'];checks+=1
        assert c['added_full_tables']==c['removed_original_tables']==0;checks+=1
        bank=c['bank_peak_words']+2*c['tables']+5
        pair=c['pair_peak_words']+2*c['tables']+5
        # Fair compiler-style comparison: input endpoint coefficients must
        # expire after their final consumer just like all derived buffers.
        full_bank=interval_peak(t['bank'],t['bank_lifetime']['output'],include_external=True)+5
        full_pair=interval_peak(t['pair'],t['pair_lifetime']['output'],include_external=True)+5
        # Independently audit the new scope against a direct live-set sweep.
        for name,want in [('bank',full_bank),('pair',full_pair)]:
            ns=t[name];last=t[name+'_lifetime']['last_use'];peak=0
            for at,n in enumerate(ns):
                words=sum(q['words'] for q in ns[:at+1] if last[q['id']]>=at)
                peak=max(peak,words)
            assert peak+5==want;checks+=1
        primary=c['descriptor'] in ['TinyLlama1.1B','Llama3-8B'] and not c['padded']
        if primary:
            assert (full_bank,full_pair)==(130,129);checks+=1
            assert 1-full_pair/full_bank<0.008;checks+=1
        accounting.append(dict(descriptor=c['descriptor'],padded=c['padded'],
            bank_logical_scratch_bytes=16*c['bank_peak_words'],pair_logical_scratch_bytes=16*c['pair_peak_words'],
            bank_with_common_endpoint_and_accumulator_words=bank,
            pair_with_common_endpoint_and_accumulator_words=pair,
            fixed_retained_endpoint_bank_reduction=1-pair/bank,
            fixed_retained_endpoint_bank_is_not_last_use_peak=True,
            total_last_use_bank_words_including_accumulator=full_bank,
            total_last_use_pair_words_including_accumulator=full_pair,
            total_last_use_reduction=1-full_pair/full_bank,
            current_unpadded_catalog=primary,
            full_original_tables_retained=c['tables'],denominators_created_each_row=L,
            baseline_and_pair_same_operations=c['row_operations'],
            physical_memory_or_register_claim=False))
    # Original source's declared samples, point-1 recovery, and final ordering
    # survive; nothing in the candidate authorizes private table deletion.
    s=(H/'native/zkp-core__src__sumcheck__rounds.rs').read_text()
    for marker in ['for d in 1..=degree','if d != 1 || eval_one',
                   'sums[1] = claim.sub(sums[0])',
                   'self.tables.iter().map(|t| t[0]).collect()']:
        assert marker in s;checks+=1
    assert r['checks']['fixtures']==30;checks+=1
    assert all(r['controls'].values()) and len(r['controls'])==7;checks+=1
    baseline_seconds=174.052;D_seconds=26.691
    out=dict(status='PASS',checks=checks,accounting=accounting,
        controls=dict(retain_bank_destroys_streaming_retention_gain=True,
                      common_endpoints_and_accumulator_are_not_eliminated=True,
                      input_last_use_demotes_scratch_only_claim=True),
        end_to_end=dict(measured_8B_D_affected_time=None,predicted_8B_speedup=None,
            measured_native_speedup=None,
            maximum_speedup_if_all_D_deleted_in_carried_1B_diagnostic=baseline_seconds/(baseline_seconds-D_seconds),
            maximum_diagnostic_positions_per_second_if_all_D_deleted=128/(baseline_seconds-D_seconds),
            caveat='A ceiling on deleting ALL D in a 1.1B one-pass GPU-arm diagnostic; no estimate for this schedule or for 8B. Actual D phase, native compilation, registers, spills, occupancy and enclosing clocks owed.'),
        wall_seconds=time.perf_counter()-start,rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        cpu_affinity=[cpu],threads=1)
    (H/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k!='accounting'},indent=2))
    print(json.dumps(accounting[2],indent=2))

if __name__=='__main__':main()
