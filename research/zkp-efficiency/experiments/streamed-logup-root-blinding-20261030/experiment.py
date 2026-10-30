"""Bounded independent-oracle arithmetic and distribution experiment."""
from collections import Counter
from hashlib import sha256
import json
import os
from pathlib import Path
import platform
import random
import resource
from time import perf_counter

from candidate import F, P, Field, query_root, pair_table, table_root, cancelling_pair
from reference import RefField

HERE = Path(__file__).resolve().parent
SEED = 20261030173
rng = random.Random(SEED)  # Public synthetic fixtures only, never proof entropy.
ref = RefField(P, 7)
checks = Counter()


def check(label, condition):
    if not condition:
        raise AssertionError(label)
    checks[label] += 1


def refuses(fn):
    try:
        fn()
    except ValueError:
        return True
    return False


def plain(value):
    if isinstance(value, dict):
        return {k: plain(v) for k, v in value.items()}
    if isinstance(value, (tuple, list)):
        return [plain(v) for v in value]
    return value


started = perf_counter()
cases, table_builds, small = [], [], []
for alpha_index in range(2):
    alpha = (rng.randrange(P), rng.randrange(1, P))
    tab = pair_table(alpha)
    table_builds.append({k: v for k, v in tab.items() if k != 'values'})
    inverses = [ref.inverse(((alpha[0]-v) % P, alpha[1])) for v in range(256)]
    # Independently check every cached entry using alpha^2-alpha(a+b)+ab.
    alpha_squared = ref.product(alpha, alpha)
    for a in range(256):
        for b in range(256):
            scaled = ref.product(alpha, ((-a-b) % P, 0))
            expected = ref.plus(ref.plus(alpha_squared, scaled), (a*b % P, 0))
            j = 2*(256*a+b)
            check('all_pair_entries', tuple(tab['values'][j:j+2]) == expected)
    for n in (1024, 4096, 16384, 65536):
        for pattern in ('uniform', 'single_hot'):
            values = bytearray(rng.randrange(256) for _ in range(n)) if pattern == 'uniform' else bytearray([17])*n
            direct, direct_stats = query_root(values, alpha)
            cached, cached_stats = query_root(values, alpha, tab)
            independent = ref.histogram_root(values, alpha, inverses)
            check('roots_match', direct == cached == independent)
            counts = [0]*256
            for v in values:
                counts[v] += 1
            tr = table_root(counts, alpha)
            combined = F.merge(cached, tr)
            check('full_logup_identity', combined[0] == F.zero and combined[1] != F.zero)
            check('direct_count', direct_stats['fp2_multiplies'] == 2*n-3)
            check('cached_count', cached_stats['fp2_multiplies'] == 3*(n//2-1))
            cases.append({'alpha_index': alpha_index, 'alpha': alpha, 'n': n, 'pattern': pattern,
                          'source_sha256': sha256(values).hexdigest(), 'query_root': cached,
                          'table_root': tr, 'combined_root': combined,
                          'direct': direct_stats, 'cached': cached_stats,
                          'cold_cached_s_diagnostic': tab['build_s']+cached_stats['root_build_s'],
                          'cold_cached_fp2_multiplies': 65536+cached_stats['fp2_multiplies'],
                          'cold_cached_logical_operand_bytes': 48*65536+cached_stats['logical_operand_bytes'],
                          'packed_peak_selected_bytes': cached_stats['peak_live_packed_layer_bytes']+len(values)+tab['packed_bytes']+256*16})
    for n in (2, 4, 8, 16, 32):
        values = [rng.randrange(256) for _ in range(n)]
        root, _ = query_root(values, alpha, tab)
        fractions = [((1, 0), ((alpha[0]-v) % P, alpha[1])) for v in values]
        check('sequential_oracle', root == ref.direct_root(fractions))
        small.append({'alpha': alpha, 'values': values, 'root': root})

# Exhaust the mask distribution in F_11[u]/(u^2-2), not a statistical sample.
toy = Field(11, 2); toyref = RefField(11, 2)
elements = [(a, b) for a in range(11) for b in range(11)]
nonzero = elements[1:]  # (0,0) is the first entry.
alpha = (3, 1); alphabet = range(4)
public_product = (1, 0)
for v in alphabet:
    public_product = toy.mul(public_product, ((alpha[0]-v) % 11, alpha[1]))
valid_den = [toy.mul(public_product, ((alpha[0]-v) % 11, alpha[1])) for v in alphabet]
characters = [toy.power(d, 60) for d in valid_den]
first = 0
second = next(i for i in range(1, 4) if characters[i] != characters[first])
distributions = []
histograms = {}
for mode in ('equal_denominators', 'independent_scale'):
    per_secret = []
    for value in (first, second):
        histogram = Counter()
        for s in elements:
            for r in nonzero:
                zero_pair = cancelling_pair(toy, s, r, mode)
                expected = toyref.direct_root([(s, r), (toy.neg(s), r)]) if mode == 'equal_denominators' else toyref.direct_root([(s, toy.one), (toy.neg(toy.mul(s, r)), r)])
                check('mask_pair_oracle', zero_pair == expected)
                check('cancels_and_nonzero', zero_pair[0] == toy.zero and zero_pair[1] != toy.zero)
                root = toy.merge((toy.zero, valid_den[value]), zero_pair)
                histogram[root[1]] += 1
        histograms[mode, value] = histogram
        per_secret.append({'secret_value': value, 'original_denominator': valid_den[value],
                           'quadratic_character': characters[value],
                           'support_size': len(histogram), 'frequency_values': sorted(set(histogram.values())),
                           'samples': sum(histogram.values())})
    h1, h2 = [histograms[mode, v] for v in (first, second)]
    total = sum(h1.values()); tv_numerator = sum(abs(h1[k]-h2[k]) for k in h1.keys() | h2.keys())
    distributions.append({'mode': mode, 'per_secret': per_secret,
                          'total_variation': tv_numerator/(2*total),
                          'identical_distributions': h1 == h2})
check('square_mask_distinguishes', distributions[0]['total_variation'] == 1)
check('independent_scale_uniform_nonzero', distributions[1]['identical_distributions'] and all(s['support_size'] == 120 and s['frequency_values'] == [121] for s in distributions[1]['per_secret']))

# Native-field existence test with the same public length and complete byte table.
native_alpha = tuple(table_builds[0]['alpha'])
public_c = F.one
for v in range(256):
    public_c = F.mul(public_c, ((native_alpha[0]-v) % P, native_alpha[1]))
native_den = [F.mul(public_c, ((native_alpha[0]-v) % P, native_alpha[1])) for v in range(256)]
native_char = [ref.exponent(d, (P*P-1)//2) for d in native_den]
other = next(v for v in range(1, 256) if native_char[v] != native_char[0])
native_examples = []
for v in (0, other):
    for _ in range(8):
        r = (rng.randrange(P), rng.randrange(1, P)); s = (rng.randrange(P), rng.randrange(P))
        pair = cancelling_pair(F, s, r, 'equal_denominators')
        blinded = F.merge((F.zero, native_den[v]), pair)
        check('native_square_character', ref.exponent(blinded[1], (P*P-1)//2) == native_char[v])
    native_examples.append({'synthetic_value': v, 'denominator': native_den[v], 'character': native_char[v]})

controls = {}
controls['non_byte'] = refuses(lambda: query_root([0, 256], native_alpha))
controls['noncanonical_challenge'] = refuses(lambda: query_root([0, 0], (P+255, 0)))
controls['zero_in_unused_public_table_entry'] = refuses(lambda: query_root([0, 0], (255, 0)))
controls['stale_pair_table'] = refuses(lambda: query_root([0, 0], native_alpha, tab))
controls['zero_mask_denominator'] = refuses(lambda: cancelling_pair(F, F.one, F.zero, 'independent_scale'))
vals = [1, 2, 3, 4]
qr, _ = query_root(vals, native_alpha)
counts = [0]*256
for v in vals:
    counts[v] += 1
wrong = counts[:]; wrong[1] -= 1; wrong[8] += 1
controls['wrong_multiplicity'] = F.merge(qr, table_root(wrong, native_alpha))[0] != F.zero
swapped = list(reversed(vals)); swapped_root, _ = query_root(swapped, native_alpha)
point = [(2, 1), (3, 4)]
controls['ordered_binding_required'] = qr == swapped_root and ref.ordered_mle(vals, point) != ref.ordered_mle(swapped, point)
remaining = vals[1:]; remaining_counts = counts[:]; remaining_counts[1] -= 1
removed_q = ref.histogram_root(remaining, native_alpha)
controls['matched_leaf_deletion_requires_binding'] = F.merge(removed_q, table_root(remaining_counts, native_alpha))[0] == F.zero and remaining != vals
controls['zero_zero_cross_product_vacuous'] = F.merge((F.zero, F.zero), (F.zero, F.one))[0] == F.zero and F.merge((F.zero, F.zero), (F.zero, F.one))[1] == F.zero
controls['drop_leaf_changes_root'] = ref.histogram_root(vals[:-1], native_alpha) != qr
d0, d1 = native_den[0], native_den[other]; r = (19, 23)
r0, r1 = F.mul(d0, r), F.mul(d1, r)
controls['reused_scale_leaks_ratio'] = ref.product(r0, ref.inverse(r1)) == ref.product(d0, ref.inverse(d1))
controls['disclosed_scale_recovers_denominator'] = ref.product(r0, ref.inverse(r)) == d0
controls['equal_denominator_mask_leaks_character'] = distributions[0]['total_variation'] == 1
for name, ok in controls.items():
    check('control_'+name, ok)

result = {'status': 'PASS', 'seed': SEED, 'checks': dict(checks), 'total_checks': sum(checks.values()),
          'cases': cases, 'pair_table_builds': table_builds, 'small_fixtures': small,
          'distribution_field': {'p': 11, 'nonresidue': 2, 'q': 121, 'alpha': alpha, 'alphabet_size': 4},
          'distributions': distributions, 'native_field_examples': native_examples,
          'controls': controls, 'wall_s': perf_counter()-started,
          'peak_rss_kib': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
          'scope': 'Bottom-up arithmetic and root marginal only; no GKR, CFS, PCS, masked claims, proof, or simulator',
          'proofs': 0, 'proved_positions': 0,
          'pair_table_arithmetic_break_even_total_lookups': 131072,
          'logical_bytes_are_not_DRAM_traffic': True,
          'hardware': {'cpu': next((line.split(':', 1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('model name')), 'unknown'),
                       'python': platform.python_version(), 'platform': platform.platform(),
                       'affinity': sorted(os.sched_getaffinity(0)), 'gpu_used': False}}
(HERE/'result.json').write_text(json.dumps(plain(result), indent=2)+'\n')
print(json.dumps({'status': result['status'], 'checks': result['total_checks'], 'cases': len(cases),
                  'distribution_tv_equal_corrected': [x['total_variation'] for x in distributions],
                  'wall_s': result['wall_s'], 'peak_rss_kib': result['peak_rss_kib']}))
