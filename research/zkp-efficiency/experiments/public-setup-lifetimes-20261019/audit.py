#!/usr/bin/env python3
"""Separate audit: no imports from the candidate experiment."""
import hashlib
import json
import os
from pathlib import Path
import random
import re
import resource
import signal
import time

start = time.monotonic()
resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2,) * 2)
resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
signal.alarm(59)
os.nice(19)
os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
p = Path(__file__).resolve().parent
read = lambda n: json.loads((p / n).read_text())
checks = 0
controls = {}
pins = read('source-pins.json')
manifest = read('native/manifest_frozen.json')
for pin in pins:
    saved = (p / pin['snapshot']).read_bytes()
    current = Path(pin['source']).read_bytes()
    assert hashlib.sha256(saved).hexdigest() == pin['sha256']
    assert current == saved
    checks += 2
    if pin['r8_manifest_match']:
        rel = pin['source'].split('/trained-1b-review-r8/')[1]
        assert manifest['files'][rel] == pin['sha256']
        checks += 1

native = lambda n: (p / 'native' / n.replace('/', '__')).read_text()
field = native('zkp-core/src/field.rs')
modulus = int(re.search(r'pub const P: u64 = (0x[\w_]+);', field)[1].replace('_', ''), 16)
generator = int(re.search(r'pub const GENERATOR: u64 = (\d+);', field)[1])
assert modulus == 2**64 - 2**32 + 1
checks += 1
fixtures = read('fixtures.json')
# Direct dot product at each root: unlike the candidate's iterative butterfly
# and its Horner oracle, this uses explicit independent monomial powers.
for f in fixtures:
    n = 2**f['log_n']
    assert len(f['values']) == n == len(f['evaluations'])
    omega = pow(generator, (modulus - 1) // n, modulus)
    for k, got in enumerate(f['evaluations']):
        want = sum(c * pow(omega, j * k, modulus) for j, c in enumerate(f['values'])) % modulus
        assert got == want
        checks += 1
    checks += 1
random_fixture = next(f for f in fixtures if f['log_n'] == 5 and f['kind'] == 'random')
controls['one_word_evaluation_corruption'] = (random_fixture['evaluations'][0] + 1) % modulus != sum(random_fixture['values']) % modulus

cases = read('io-site-cases.json')
for case in cases:
    blocks, t = case['blocks'], case['tokens']
    # Deduce IO row width separately from source-registered context choice.
    lc = 14 if t == 128 else 13
    data = t * 4096 // 2**lc
    for k, (incoming, outgoing) in enumerate(case['correct_sites']):
        assert incoming == [data + (2 if k else 0), data + (3 if k else 1)]
        assert outgoing == [data, data + 1]
        checks += 2
    assert case['whole_layout_shape_only_wrong_stages'] == blocks - 1
    checks += 1
controls['incoming_site0_aliases_previous_outgoing'] = set(cases[-1]['correct_sites'][0][1]) == set(cases[-1]['correct_sites'][0][0]) and set(cases[-1]['correct_sites'][0][1]).isdisjoint(cases[-1]['correct_sites'][1][0])

ledger = read('ntt-lifetime-ledger.json')
for row in ledger:
    log = 16 if row['context'] == 128 else 15
    # Four Vec<Fp> backing payloads, Fp repr(transparent) u64. No claim about
    # Vec headers, capacities beyond requested, allocator overhead or device.
    roots = 2 * (log + 1)
    twiddles = 2 * 2**(log - 1)
    assert row['public_ntt_fp_payload_bytes'] == 8 * (roots + twiddles)
    assert row['current_prover_ntt_constructions'] == 2 * row['passes']
    assert row['removed_constructions'] == 2 * row['passes'] - 1
    assert row['existing_gpu_twiddle_payload_bytes'] == 2 * (2**log - 1) * 8
    assert row['additional_gpu_uploads_removed_by_cpu_cache'] == 0
    checks += 5
run_source = native('hashline/src/private_block/run.rs')
prover = run_source.split('pub(crate) fn prove_run_with(', 1)[1].split('/// **THE RUN VERIFIER', 1)[0]
assert prover.count('NttTables::new(') == 1
assert prover.index('NttTables::new(') < prover.index('for k in 0..l')
endpoint = native('hashline/src/private_block.rs').split('pub fn prepare_endpoints(', 1)[1].split('/// The SECRET block output', 1)[0]
assert endpoint.count('let ntt = NttTables::new(') == 2  # exclusive general/frozen branches
gpu = native('hashline/src/gpu/cuda.rs')
assert 'if *ml >= ntt.max_log' in gpu
assert 'static GPU: OnceLock<Option<Mutex<Gpu>>>' in gpu
checks += 5

# Fresh arithmetic counterexample to a shape-geometry-only coefficient plan.
rng = random.Random(2026101985)
different = 0
for _ in range(32):
    g, x = rng.randrange(-127, 128), rng.randrange(-32768, 32768)
    old_term, new_term = g * x * 2 * 2092, g * x * 2 * 2093
    assert new_term - old_term == 2 * g * x
    different += old_term != new_term
    checks += 1
controls['geometry_only_norm_coefficient_is_stale'] = different == 32

report = read('native/report.json')
public_tables = report['checks']['table_keys']
unique_table_keys = {(r['exp_e_s'], tuple(r['silu_member'])) for r in public_tables.values()}
# Real public metadata, no private model/activation data. Same full Shape
# repeats at 31 layers but their public table keys are not all the same.
base_layers = [k for k in public_tables if k not in report['checks']['layers_own_constants']]
base_table_keys = {(public_tables[k]['exp_e_s'], tuple(public_tables[k]['silu_member'])) for k in base_layers}
controls['same_native_shape_has_distinct_public_tables'] = len(base_table_keys) > 1
components = read('public-block-payload-components.json')
for t in [32, 64, 128]:
    # Independent block-matrix decomposition: two square attention matrices,
    # two narrow KV matrices, three padded FFN matrices, two norm vectors.
    want = (2*4096**2 + 2*1024*4096 + 3*4096*16384 + 2*4096
            + 2*t*64*8 + 256*8 + 256*2)
    assert sum(components[str(t)].values()) == want
    checks += 1
for row in read('public-block-residency-ledger.json'):
    cap, scans = row['capacity_layers'], 2*row['passes']
    assert row['lru']['misses'] == (32*scans if cap < 32 else 32)
    assert row['public_fixed_pinned_subset']['misses'] == 32*scans - cap*(scans-1)
    assert row['retained_backing_payload_bytes'] == cap*sum(components[str(row['context'])].values())
    checks += 3
controls['one_layer_is_not_repeated_pass_residency'] = all(r['lru']['hits'] == 0 for r in read('public-block-residency-ledger.json') if r['capacity_layers'] == 1)
acc = read('target-accounting.json')
assert acc['total_seconds'] == 478.737
assert acc['diagnostic_positions_per_second'] == 128 / 478.737
assert acc['sealing_load_task_seconds'] == 27.151
assert acc['proof_block_load_seconds'] == 17.595
assert abs(acc['all_load_zero_cost_upper_speedup'] - 478.737/(478.737-27.151-17.595)) < 1e-12
assert all(acc[k] is None for k in ['startup_seconds', 'startup_fraction', 'serialization_seconds', 'steady_positions_per_second', 'candidate_saving_seconds'])
assert [acc['new_target_proofs'], acc['new_target_passes'], acc['new_target_positions']] == [0, 0, 0]
checks += 7
assert all(controls.values()), controls
result = dict(status='PASS', checks=checks, controls=controls,
              direct_dft_fixtures=len(fixtures), fresh_norm_coefficient_cases=32,
              unique_public_table_keys=len(unique_table_keys),
              repeated_base_shape_layers=len(base_layers), base_shape_distinct_table_keys=len(base_table_keys),
              scope='Independent source/payload/site/value audit; no candidate import, native proof, native admission or privacy gate.',
              wall_seconds=time.monotonic() - start, rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
              affinity=sorted(os.sched_getaffinity(0)), threads=1, limits='59s CPU/wall,512MiB AS,one nice19 CPU')
(p / 'audit-result.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
print(json.dumps(result, sort_keys=True))
