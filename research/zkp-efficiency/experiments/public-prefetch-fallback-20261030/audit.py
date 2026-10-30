"""Independent source and saved-result audit; imports no experiment code."""
import hashlib
import json
import time
from pathlib import Path
D=Path(__file__).resolve().parent
start=time.monotonic(); checks=0


def check(x):
    global checks
    checks+=1
    assert x, checks


def read(name):
    return json.loads((D/name).read_text())


r=read('result.json')
check(r['status']=='PASS')
check(r['proofs']==r['complete_model_passes']==r['proved_positions']==0)
check(r['native_loader'] is False and r['native_prover'] is False)
for p in read('native-pins.json'):
    check(hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
    check(hashlib.sha256((D/p['snapshot']).read_bytes()).hexdigest()==p['sha256'])
for p in read('source-roster.json'):
    source=(D/'native'/p['path'].replace('/','__')).read_text().splitlines()
    check(p['literal'] in source[p['line']-1])

for g in read('logical-payloads.json'):
    # Three separately listed owner sets, summed from saved arrays.
    raw=sum(g['arrays'].values()); padded=sum(g['padded_arrays'].values()); tables=sum(g['tables'].values())
    check(raw==g['raw11'])
    check(padded==g['padded9'])
    check(padded+tables==g['returned'])
    check(raw+2*padded+tables==g['known_loader_payload'])
    check(raw+3*padded+2*tables==g['old_public_plus_new_loader'])
    check(g['actual_capacity_fit'] is None)

s=r['selected']
# Independent reference public8B geometry constants, source only.
check(s['raw11']==218114560)
check(s['padded9']==243277824)
check(s['returned']==243411456)
check(s['known_loader_payload']==704803840)
check(s['old_public_plus_new_loader']==948215296)

for t in read('commit-input-traffic.json'):
    check(t['one_commit_input_bytes']==t['rows']*t['n']*t['width_assumption']+8*t['rows']*t['q']+8*t['nn'])
    check(t['public_file_hint_removed_bytes']==0)
    check(t['actual_runtime_eligibility'] is None)

# Count every successful real advisory call independently from fixture sizes
# and the public fixed budgets, including hints preceding mutation controls.
calls=0; requested=0
for fixture in range(16):
    sizes=[17+fixture,7,7,19,4,4,31,31,31,32,16,24,24]
    for budget in [0,1,7,64,4096]+[64]*13:
        remaining=budget
        for size in sizes:
            n=min(size,remaining)
            if n:
                calls+=1;requested+=n;remaining-=n
obs=read('advice-observations.json')
check(obs['actual_advice_calls']==calls==r['actual_advice_calls'])
check(obs['actual_requested_range_bytes']==requested==r['actual_requested_range_bytes'])
check(obs['mutation_cases']==16*13*6)
check(obs['stale_eager_snapshot_accepts']==obs['mutation_cases'])
check(obs['page_residency_measured'] is False)
check(obs['page_cache_memory_bound_proven'] is False)
check(obs['concurrent_race_test'] is False)

# Public-proof distinction and workload rotation remain explicit.
check(r['fresh_commit_input_bytes_eliminated']==0)
check(r['sealing_new_prefetch_incidence']==0)
out=dict(status='PASS',checks=checks,wall_s=time.monotonic()-start,
         native_pins=len(read('native-pins.json')),no_candidate_import=True)
(D/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
