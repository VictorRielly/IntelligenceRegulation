"""Separately authored arithmetic audit. No imports of candidate/reference code."""
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
import random
import resource
from time import perf_counter

HERE = Path(__file__).resolve().parent
r = json.loads((HERE/'result.json').read_text())
P = 18446744069414584321
checks = Counter()


def check(name, condition):
    assert condition, name
    checks[name] += 1


def arithmetic(p, nr):
    def plus(x, y):
        return ((x[0]+y[0]) % p, (x[1]+y[1]) % p)

    def times(x, y):
        # Three coordinate products, independently implemented Karatsuba.
        ac, bd = x[0]*y[0], x[1]*y[1]
        cross = (x[0]+x[1])*(y[0]+y[1])-ac-bd
        return ((ac+nr*bd) % p, cross % p)

    def inv(x):
        norm = (x[0]*x[0]-nr*x[1]*x[1]) % p
        if norm == 0:
            raise ValueError('zero norm')
        scalar = pow(norm, p-2, p)
        return (x[0]*scalar % p, -x[1]*scalar % p)

    def power(x, exponent):
        value = (1, 0)
        while exponent:
            if exponent % 2:
                value = times(value, x)
            x = times(x, x); exponent //= 2
        return value
    return plus, times, inv, power


plus, times, inv, power = arithmetic(P, 7)


def histogram_oracle(values, alpha):
    counts = Counter(values)
    product, ratio = (1, 0), (0, 0)
    for v, count in counts.items():
        d = ((alpha[0]-v) % P, alpha[1])
        product = times(product, power(d, count))
        ratio = plus(ratio, times((count, 0), inv(d)))
    return times(product, ratio), product


def table_oracle(values, alpha):
    counts = Counter(values)
    product, ratio = (1, 0), (0, 0)
    for v in range(256):
        d = ((alpha[0]-v) % P, alpha[1])
        product = times(product, d)
        ratio = plus(ratio, times((-counts[v] % P, 0), inv(d)))
    return times(product, ratio), product


started = perf_counter(); generator = random.Random(r['seed']); index = 0; small_index = 0
for alpha_index in range(2):
    alpha = (generator.randrange(P), generator.randrange(1, P))
    for n in (1024, 4096, 16384, 65536):
        for pattern in ('uniform', 'single_hot'):
            values = bytearray(generator.randrange(256) for _ in range(n)) if pattern == 'uniform' else bytearray([17])*n
            c = r['cases'][index]; index += 1
            check('dimensions_and_seed', c['n'] == n and c['pattern'] == pattern and c['alpha'] == list(alpha))
            check('source_digest', sha256(values).hexdigest() == c['source_sha256'])
            check('independent_query', histogram_oracle(values, alpha) == tuple(tuple(x) for x in c['query_root']))
            check('independent_table', table_oracle(values, alpha) == tuple(tuple(x) for x in c['table_root']))
            nodes = n//2; m_direct = nodes; m_cache = 0; b_direct = 17*n; b_cache = 25*n
            layers = [nodes]
            while nodes > 1:
                nodes //= 2; layers.append(nodes)
                m_direct += 3*nodes; m_cache += 3*nodes
                b_direct += 96*nodes; b_cache += 96*nodes
            check('all_layers', [x['nodes'] for x in c['direct']['layers']] == layers == [x['nodes'] for x in c['cached']['layers']])
            check('arithmetic_cost', m_direct == c['direct']['fp2_multiplies'] and m_cache+65536 == c['cold_cached_fp2_multiplies'])
            check('logical_bytes', b_direct == c['direct']['logical_operand_bytes'] and b_cache+48*65536 == c['cold_cached_logical_operand_bytes'])
            check('selected_buffers', c['packed_peak_selected_bytes'] == 32*n+n+1048576+4096)
    for n in (2, 4, 8, 16, 32):
        values = [generator.randrange(256) for _ in range(n)]
        s = r['small_fixtures'][small_index]; small_index += 1
        check('tiny_fixture_seed', values == s['values'])
        # Left fold directly over the original fractions, rather than histogram.
        a, b = (0, 0), (1, 0)
        for v in values:
            d = ((alpha[0]-v) % P, alpha[1])
            a, b = plus(times(a, d), b), times(b, d)
        check('tiny_sequential', [list(a), list(b)] == s['root'])

tplus, tmul, tinv, tpow = arithmetic(11, 2)
elements = [(a, b) for a in range(11) for b in range(11)]
nonzero = [x for x in elements if x != (0, 0)]
alpha = (3, 1); constant = (1, 0)
for v in range(4):
    constant = tmul(constant, ((alpha[0]-v) % 11, 1))
secrets = [s['secret_value'] for s in r['distributions'][0]['per_secret']]
denominators = [tmul(constant, ((alpha[0]-v) % 11, 1)) for v in secrets]
all_hist = {}
for mode_index, mode in enumerate(('equal_denominators', 'independent_scale')):
    for secret_index, denominator in enumerate(denominators):
        hist = Counter()
        for scale in nonzero:
            factor = tmul(scale, scale) if mode_index == 0 else scale
            # All 121 choices of s give the same root denominator.
            hist[tmul(denominator, factor)] += 121
        recorded = r['distributions'][mode_index]['per_secret'][secret_index]
        check('distribution_support', len(hist) == recorded['support_size'])
        check('distribution_frequencies', sorted(set(hist.values())) == recorded['frequency_values'])
        check('distribution_total', sum(hist.values()) == recorded['samples'])
        all_hist[mode_index, secret_index] = hist
    h0, h1 = all_hist[mode_index, 0], all_hist[mode_index, 1]
    tv = sum(abs(h0[k]-h1[k]) for k in h0.keys() | h1.keys())/(2*sum(h0.values()))
    check('independent_tv', tv == r['distributions'][mode_index]['total_variation'])

controls = {}
base_hists = [Counter(tmul(d, (a, 0)) for a in range(1, 11)) for d in denominators]
controls['base_field_scale_not_extension_uniform'] = all(len(h) == 10 for h in base_hists) and base_hists[0].keys().isdisjoint(base_hists[1].keys())
# Arbitrary leaves can cancel a FALSE rational identity if the zero-pair relation
# is not itself constrained and bound. This is an architecture obligation.
bad_n, bad_d = (3, 4), (5, 2)
cancel_n = (-bad_n[0] % 11, -bad_n[1] % 11)
fake_n = tplus(tmul(bad_n, bad_d), tmul(cancel_n, bad_d))
controls['unconstrained_mask_repairs_false_statement'] = bad_n != (0, 0) and fake_n == (0, 0)
controls['zero_scale_is_not_valid_padding'] = tmul(denominators[0], (0, 0)) == (0, 0)
for name, condition in controls.items():
    check(name, condition)
for example in r['native_field_examples']:
    check('native_character_recount', power(tuple(example['denominator']), (P*P-1)//2) == tuple(example['character']))
check('main_controls', len(r['controls']) == 13 and all(r['controls'].values()))
check('main_pass', r['status'] == 'PASS' and r['proofs'] == 0 and r['proved_positions'] == 0)

manifest = json.loads((HERE/'source-pins.json').read_text())
for item in manifest:
    check('production_read_only_pin', sha256(Path(item['path']).read_bytes()).hexdigest() == item['sha256'])
    check('snapshot_pin', sha256((HERE/item['snapshot']).read_bytes()).hexdigest() == item['sha256'])

out = {'status': 'PASS', 'checks': dict(checks), 'total_checks': sum(checks.values()),
       'additional_controls': controls, 'wall_s': perf_counter()-started,
       'peak_rss_kib': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
       'scope': 'Independent arithmetic/cost/distribution audit; not a native proof, privacy simulator, or cryptographic verification'}
(HERE/'audit-result.json').write_text(json.dumps(out, indent=2)+'\n')
print(json.dumps(out))
