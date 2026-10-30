"""Separate saved-evidence audit, imports neither candidate nor experiment."""
import hashlib, json
from pathlib import Path
from reference import warp_sum, component_sums, polynomial_values
E = Path(__file__).resolve().parent
count = 0


def check(v, label):
    global count
    count += 1
    if not v:
        raise AssertionError(label)


fixtures = json.loads((E/'fixtures.json').read_text())
for f in fixtures['warps']:
    check(warp_sum(f['values'], f['mask']) == f['expected'], 'warp fixture')
for f in fixtures['blocks']:
    check(component_sums(f['rows']) == [tuple(x) for x in f['expected']], 'block fixture')
for f in fixtures['polynomials']:
    check(polynomial_values(f['tables'], f['degree']) == [tuple(x) for x in f['expected']], 'node fixture')
for c in json.loads((E/'costs.json').read_text()):
    t, n = c['threads'], c['nv']
    w, components = t//32, 2*n
    adds = accesses = 0
    stride = t//2
    barriers = 1
    while stride:
        adds += stride * components
        accesses += stride * components * 3
        barriers += 1
        stride //= 2
    accesses += (t + 1)*components
    check(c['baseline_modular_adds'] == adds, 'tree adds')
    check(c['baseline_shared_scalar_accesses'] == accesses, 'tree accesses')
    check(c['baseline_cta_barriers'] == barriers, 'tree barriers')
    check(c['candidate_shared_bytes'] == len(range(w))*n*16, 'scratch bytes')
    check(c['candidate_warp_redux_instructions'] == sum(6*n for _ in range(w+1)), 'warp instructions')
    check(c['candidate_canonical_reductions'] == (w+1)*components, 'leader reductions')
    check(c['removed_global_bytes'] == c['removed_launches'] == c['removed_fresh_masks'] == 0, 'not removed')
for pin in json.loads((E/'native-pins.json').read_text()):
    b = (E/pin['snapshot']).read_bytes()
    check(hashlib.sha256(b).hexdigest() == pin['sha256'], 'snapshot hash')
    check(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest() == pin['sha256'], 'live source hash')
for pin in json.loads((E/'startup-manifest.json').read_text()):
    b = Path(pin['snapshot']).read_bytes()
    check(hashlib.sha256(b).hexdigest() == pin['sha256'], 'startup hash')
for fact in json.loads((E/'source-facts.json').read_text()):
    check(hashlib.sha256(Path(fact['path']).read_bytes()).hexdigest() == fact['sha256'], 'source fact pin')
check(json.loads((E/'hypotheses.json').read_text())[:-1] ==
      json.loads((E/'startup/prior-hypotheses.json').read_text()), 'all prior hypotheses preserved')
sketch = (E/'warp_sum.cuh').read_text()
check('asm volatile("redux.sync.add.u32' in sketch, 'unused-lane collective retained in source sketch')
check(sketch.count('__syncthreads();') == 1, 'tail-only CTA barrier in sketch')
check(32*((1<<27)-1) == 4294967264, 'safe largest sum')
check(32*((1<<10)-1) == 32736, 'top digit largest sum')
check(32*((1<<64)-1) < 1<<69, 'whole sum width')
check(len(set(json.loads((E/'negative-controls.json').read_text()))) ==
      json.loads((E/'result.json').read_text())['negative_controls'], 'unique control labels')
result = dict(status='PASS', checks=count, independent_candidate_import=False,
              native_execution=False, native_verification=False)
(E/'audit-result.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result))
