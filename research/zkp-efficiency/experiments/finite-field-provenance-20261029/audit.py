"""Independent artifact/source audit; no model or native prover execution."""
import os,resource,signal,time,json,hashlib,re
from pathlib import Path
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_CPU,(30,30))
resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));signal.alarm(35)
t=time.perf_counter();E=Path(__file__).resolve().parent;R=E.parent.parent
checks=0
def check(v):
    global checks
    checks+=1
    assert v,checks
def sha(b):return hashlib.sha256(b).hexdigest()
v=json.loads((E/'result.json').read_text())
for f,h in v['source_hashes'].items():check(sha((E/f).read_bytes())==h)
check('candidate' not in (E/'reference.py').read_text())
for pin in json.loads((E/'native-pins.json').read_text()):
    check(sha(Path(pin['path']).read_bytes())==pin['sha256'])
    check(sha((E/pin['snapshot']).read_bytes())==pin['sha256'])
for pin in json.loads((E/'startup/prior-native-pins.json').read_text()):
    check(sha(Path(pin['path']).read_bytes())==pin['sha256'])
native=(E/'native/hashline__src__private_block__argument.rs').read_text()
for s in ('SC_DZC =>','SC_LZC =>','SC_SZC =>','SC_SZC if sh.dd_cap > 0 =>','SC_DD =>',
          'let c1 = ns.add(nr).add(Fp2::ONE).sub(kd)',
          'let c7 = ms.add(mr).add(Fp2::ONE).sub(kdm)'):
    check(s in native)
field=(E/'native/zkp-core__src__field.rs').read_text()
check('pub const P: u64 = 0xFFFF_FFFF_0000_0001;' in field)
P=int('FFFFFFFF00000001',16);a=(P-1)//2
check(2*a+1==P);check((2*a+1)%P==0);check(a>0)
check(v['goldilocks_counterexample']['weak_conclusion']==[-1,-1])
check(v['exhaustive_interval_cases']==sum((p*(p+1)//2)**3 for p in (5,7)))
for row in v['relation_cases']:
    check(len(row['kept'])==1)
    check(row['original_witnesses']==row['k']+1)
    check(row['unsafe_new_witnesses']==row['p']-row['k']-1)
check(sum(x['unsafe_new_witnesses'] for x in v['relation_cases'])==v['unsafe_extra_witness_instances'])
check(v['weak_unsound_cases']>0)
check(v['range_dominance_cases']>v['range_weaker_only_negative_cases']>0)
check(v['native_checks_removed']==v['verified_full_stack_proofs']==v['proved_positions']==0)
check(v['elapsed_s']<60 and v['max_rss_kib']<512*1024)
check(len(v['cpu_affinity'])==1 and v['nice']==19)
prior=(E/'startup/sources.jsonl').read_bytes();current=(R/'sources.jsonl').read_bytes()
check(current.startswith(prior))
rows=[json.loads(l) for l in current.splitlines()]
check(len(rows)==882)
new=rows[873:];check(len(new)==9)
for r in new:
    check(r['run_id']=='20261029T035649Z-8ea509dd')
    check(not r['external_execution'] and not r['reproduced_performance'])
    check(r['access_date']=='2026-10-29' and r['url'].startswith('https://'))
    for k in ('publication_date','verified_update_date','inspected_commit_id','implementation_license','date_evidence'):
        check(k in r)
out=dict(status='PASS_SOURCE_AND_PROVENANCE_AUDIT_ONLY',checks=checks,
 elapsed_s=time.perf_counter()-t,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 native_pins_unchanged=True,prior_eight_native_pins_unchanged=True,
 source_records_before=873,source_records_after=882,external_execution=False)
(E/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
