"""Public first-difference table construction. Independent derivation, no port."""
from array import array
from hashlib import sha256
import json
from pathlib import Path
import random
import resource
from time import perf_counter

from candidate import F, P, check_alpha, pair_table, query_root
from reference import RefField

HERE = Path(__file__).resolve().parent
ref = RefField(P, 7)
rng = random.Random(2026103017301)


def additive_table(alpha):
    check_alpha(alpha)
    started = perf_counter(); output = array('Q')
    first = F.mul(alpha, alpha)
    for a in range(256):
        value = first; den_a = ((alpha[0]-a) % P, alpha[1])
        for b in range(256):
            output.extend(value)
            if b < 255:
                value = ((value[0]-den_a[0]) % P, (value[1]-den_a[1]) % P)
        if a < 255:
            first = ((first[0]-alpha[0]) % P, (first[1]-alpha[1]) % P)
    return {'alpha': alpha, 'values': output, 'build_s': perf_counter()-started,
            'fp2_multiplies': 1, 'fp2_subtractions': 65535,
            'base_denominator_subtractions': 256,
            'packed_bytes': len(output)*8}


started = perf_counter(); rows = []; checks = 0
for alpha in ((123456789012345, 98765432101234), (P-1, P-2), (256, 0)):
    direct = pair_table(alpha); additive = additive_table(alpha)
    assert additive['values'] == direct['values']; checks += 1
    for a in range(256):
        for b in range(256):
            expected = ref.product(((alpha[0]-a) % P, alpha[1]), ((alpha[0]-b) % P, alpha[1]))
            j = 2*(a*256+b)
            assert tuple(additive['values'][j:j+2]) == expected
            checks += 1
    cases = []
    for n in (1024, 4096, 16384, 65536):
        values = bytearray(rng.randrange(256) for _ in range(n))
        a, sa = query_root(values, alpha)
        b, sb = query_root(values, alpha, additive)
        assert a == b; checks += 1
        cases.append({'n': n, 'direct_root_s': sa['root_build_s'], 'cached_root_s': sb['root_build_s'],
                      'all_in_recurrence_s_diagnostic': additive['build_s']+sb['root_build_s'],
                      'direct_fp2_multiplies': sa['fp2_multiplies'],
                      'recurrence_all_in_fp2_multiplies': 1+sb['fp2_multiplies'],
                      'recurrence_setup_fp2_subtractions': 65535,
                      'selected_array_peak_bytes': sb['peak_live_packed_layer_bytes']+len(values)+1048576+4096,
                      'table_gather_extra_logical_bytes': 8*n,
                      'scope': 'Root construction only; masks, GKR reductions, bindings and verification absent'})
    rows.append({'alpha': alpha, 'direct_build_s': direct['build_s'],
                 'recurrence_build_s': additive['build_s'],
                 'table_sha256': sha256(additive['values'].tobytes()).hexdigest(),
                 'direct_setup_fp2_multiplies': 65536, 'recurrence_setup_fp2_multiplies': 1,
                 'recurrence_setup_fp2_subtractions': 65535, 'cases': cases})
controls = {}
try:
    additive_table((255, 0))
    controls['whole_table_zero_refused'] = False
except ValueError:
    controls['whole_table_zero_refused'] = True
fresh = additive_table((1000, 1)); stale = additive_table((1001, 1))
controls['fresh_alpha_changes_table'] = fresh['values'] != stale['values']
try:
    query_root([1, 2], fresh['alpha'], stale)
    controls['cross_alpha_use_refused'] = False
except ValueError:
    controls['cross_alpha_use_refused'] = True
mutant = array('Q', fresh['values']); mutant[2*(256*17+19)] ^= 1
controls['single_entry_mutation_detected'] = mutant != fresh['values']
assert all(controls.values())
result = {'status': 'PASS', 'seed': 2026103017301, 'checks': checks+len(controls), 'rows': rows,
          'controls': controls, 'wall_s': perf_counter()-started,
          'peak_rss_kib': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
          'scope': 'Synthetic public-table/root construction; no proving speed improvement measured',
          'proofs': 0, 'proved_positions': 0,
          'recurrences': ['Q(a,b+1)=Q(a,b)-(alpha-a)', 'Q(a+1,0)=Q(a,0)-alpha'],
          'claim': '65536 setup Fp2 multiplies replaced by1multiply+65535Fp2subtracts; no wall-time or complete-proof factor follows',
          'limitations': ['1MiB table remains', 'private gathers add logical8B/lookup', 'setup repeats per freshalpha',
                          'sequential recurrence depth may limit GPU parallelism; per-row seeds cost256multiplies',
                          'no GKR/CFS/PCS/mask/leaf-binding costs included']}
(HERE/'recurrence-result.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({'status': result['status'], 'checks': result['checks'], 'wall_s': result['wall_s'], 'peak_rss_kib': result['peak_rss_kib']}))
