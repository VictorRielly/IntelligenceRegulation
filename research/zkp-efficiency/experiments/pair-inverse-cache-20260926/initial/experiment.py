#!/usr/bin/env python3
"""Exact synthetic pair-helper cache oracle, not a prover benchmark.

No external dependencies/code, no production writes. The unchanged later
public-table inversion is deliberately included in the schedule model.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import resource
import signal
import time

P = 2**64 - 2**32 + 1
Z, O = (0, 0), (1, 0)
SEED = 2026092604
HERE = Path(__file__).resolve().parent
ROOT = Path('/home/victor/IntelligenceRegulation')
NATIVE = Path('/tmp/zk60-groups-20260926')
ERROR = 'zero LogUp denominator; discard attempt'


def limits():
    resource.setrlimit(resource.RLIMIT_AS, (512*2**20, 512*2**20))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})


def add(a, b):
    return ((a[0]+b[0]) % P, (a[1]+b[1]) % P)


def sub(a, b):
    return ((a[0]-b[0]) % P, (a[1]-b[1]) % P)


def mul(a, b):
    return ((a[0]*b[0]+7*a[1]*b[1]) % P,
            (a[0]*b[1]+a[1]*b[0]) % P)


def inverse(a):
    if a == Z:
        raise ZeroDivisionError(ERROR)
    ni = pow((a[0]*a[0]-7*a[1]*a[1]) % P, P-2, P)
    return (a[0]*ni % P, -a[1]*ni % P)


def batch(ds, counts=None):
    """Transcription of field.rs batch_inverse2_checked + batch_inverse2."""
    if Z in ds:
        raise ZeroDivisionError(ERROR)
    if not ds:
        return []
    if counts is not None:
        counts['batch_elements'] += len(ds)
        counts['batch_multiplications'] += 3*len(ds)
        counts['field_inversions'] += 1
    prefix, acc = [], O
    for d in ds:
        prefix.append(acc)
        acc = mul(acc, d)
    acc = inverse(acc)
    out = [Z]*len(ds)
    for i in range(len(ds)-1, -1, -1):
        out[i] = mul(acc, prefix[i])
        acc = mul(acc, ds[i])
    return out


def denominator(i, v, alpha, beta, tag):
    return sub(alpha, add(add((i % P, 0), mul(beta, (v % P, 0))), tag))


def counters():
    return dict(batch_elements=0, batch_multiplications=0, field_inversions=0,
                denominators=0, hits=0, fallback=0)


def reference(pairs, table, alpha, beta, tag, counts):
    counts['denominators'] += len(pairs)
    return batch([denominator(i, v, alpha, beta, tag) for i, v in pairs], counts)


def cache_build(table, alpha, beta, tag, counts):
    ds = [denominator(i, v, alpha, beta, tag) for i, v in enumerate(table)]
    counts['denominators'] += len(ds)
    # Cache construction cannot refuse: an unused zero belongs to the later
    # public-table stage. Compression need not be injective.
    nz = iter(batch([d for d in ds if d != Z], counts))
    return [None if d == Z else next(nz) for d in ds]


def cached(pairs, table, alpha, beta, tag, counts, cache=None):
    if cache is None:
        cache = cache_build(table, alpha, beta, tag, counts)
    out = []
    for i, v in pairs:
        if 0 <= i < len(table) and table[i] == v:
            counts['hits'] += 1
            x = cache[i]
            if x is None:
                raise ZeroDivisionError(ERROR)
        else:
            # Preserve arbitrary/dishonest-witness arithmetic. Do NOT clamp,
            # wrap the index, replace the value, or add a new refusal.
            counts['fallback'] += 1
            counts['denominators'] += 1
            d = denominator(i, v, alpha, beta, tag)
            if d == Z:
                raise ZeroDivisionError(ERROR)
            counts['field_inversions'] += 1
            x = inverse(d)
        out.append(x)
    return out


def oracle(pairs, alpha, beta, tag):
    """Independent direct coefficient solve with Python's Euclidean inverse.

    Does not call denominator(), inverse(), batch(), or candidate helpers.
    Multiplying each answer by its denominator must give 1 + 0*u.
    """
    out = []
    for i, v in pairs:
        a = (alpha[0]-i-beta[0]*v-tag[0]) % P
        b = (alpha[1]-beta[1]*v-tag[1]) % P
        if a == 0 and b == 0:
            raise ZeroDivisionError(ERROR)
        det = (a*a-7*b*b) % P
        scale = pow(det, -1, P)
        x, y = a*scale % P, -b*scale % P
        assert (a*x+7*b*y) % P == 1 and (a*y+b*x) % P == 0
        out.append((x, y))
    return out


def encoded(xs):
    return b''.join(a.to_bytes(8, 'little')+b.to_bytes(8, 'little') for a, b in xs)


def outcome(fn, *args):
    try:
        return ('ok', fn(*args))
    except ZeroDivisionError as e:
        return ('refuse', str(e))


def table_column(table, pairs, alpha, beta, tag, padded_len, counts,
                 skip_zero_counts=False):
    hist = [0]*len(table)
    for i, v in pairs:
        hit = 0 <= i < len(table) and table[i] == v
        hist[i if hit else 0] += 1
    # Production pads public table entries by i % U8_LEN, and multiplicities
    # by zero, not by repeating the histogram.
    weights = hist + [0]*(padded_len-len(table))
    ds = [denominator(k % len(table), table[k % len(table)], alpha, beta, tag)
          for k in range(padded_len)]
    if skip_zero_counts:
        # Intentionally broken control; cancellation of 0/0 is forbidden.
        inv = [Z if m == 0 else inverse(d) for d, m in zip(ds, weights)]
    else:
        inv = batch(ds, counts)
    return [(a*m % P, b*m % P) for (a, b), m in zip(inv, weights)]


def pipeline(engine, tables, columns, alpha, beta, gamma, padded_len,
             eager=False, skip_tables=False, skip_zero_counts=False):
    """Source-derived phase/refusal model, NOT native transcript execution.

    A single U8 looked column is enough to probe relative refusal order.
    Production's RNG/absorbs lie outside this model and still need gates.
    """
    events, values = [], []
    stages = ('u8_helper', 'exp_helper', 'act_helper')
    tags = [mul(gamma, (j, 0)) for j in (1, 2, 3)]
    betas = [Z, beta, beta]
    counts = counters()
    stage = 'cache_build'
    try:
        if eager:
            for tab, b, tag in zip(tables, betas, tags):
                batch([denominator(i, v, alpha, b, tag) for i, v in enumerate(tab)])
        for stage, tab, pairs, b, tag in zip(stages, tables, columns, betas, tags):
            events.append(stage)
            values.append(engine(pairs, tab, alpha, b, tag, counts))
        events.append('drop_transient_buffers')
        if not skip_tables:
            for stage, tab, pairs, b, tag in zip(('u8_table', 'exp_table', 'act_table'),
                                               tables, columns, betas, tags):
                events.append(stage)
                values.append(table_column(tab, pairs, alpha, b, tag, padded_len,
                                           counts, skip_zero_counts))
        return dict(status='ok', events=events, columns=values)
    except ZeroDivisionError as e:
        return dict(status='refuse', stage=stage, error=str(e), events=events,
                    columns=values)


def main():
    limits()
    started = time.perf_counter()
    rng = random.Random(SEED)
    rnd = lambda: (rng.randrange(P), rng.randrange(P))
    cases, comparisons, direct_words = [], 0, 0

    def check(name, tab, pairs, a, b, g):
        nonlocal comparisons, direct_words
        rc, cc = counters(), counters()
        ref = outcome(reference, pairs, tab, a, b, g, rc)
        got = outcome(cached, pairs, tab, a, b, g, cc)
        direct = outcome(oracle, pairs, a, b, g)
        assert ref == got == direct, name
        if ref[0] == 'ok':
            assert encoded(ref[1]) == encoded(got[1]) == encoded(direct[1])
            direct_words += len(pairs)
        comparisons += 1
        cases.append(dict(name=name, table_len=len(tab), words=len(pairs),
                          outcome=ref[0], reference=rc, candidate=cc,
                          digest=hashlib.sha256(encoded(ref[1])).hexdigest()
                          if ref[0] == 'ok' else None))

    for m in (1, 4, 16, 256):
        for n in (0, 1, 31, 257):
            tab = [rng.randint(-32768, 32767) for _ in range(m)]
            for kind in ('valid', 'mixed', 'all_invalid', 'beta_zero'):
                pairs = [(i := rng.randrange(m), tab[i]) for _ in range(n)]
                if kind in ('mixed', 'all_invalid'):
                    step = 3 if kind == 'mixed' else 1
                    for k in range(0, n, step):
                        i, v = pairs[k]
                        pairs[k] = ((-1, v), (m+3, v), (i, v+1),
                                    (-(1 << 63), (1 << 63)-1))[k % 4]
                check(f'm{m}-n{n}-{kind}', tab, pairs, rnd(),
                      Z if kind == 'beta_zero' else rnd(), rnd())
    # Exact zeros at a used/unused pair, and compression collisions.
    tab = [4, -3, 7, 0]
    beta, tag = (5, 9), (17, 13)
    alpha = add(add((2, 0), mul(beta, (tab[2] % P, 0))), tag)
    check('used_zero', tab, [(2, tab[2])], alpha, beta, tag)
    check('unused_zero', tab, [(0, tab[0])], alpha, beta, tag)
    check('altered_valid_index', tab, [(0, tab[0]+1)], (99, 80), beta, tag)
    check('beta_zero_altered_value', tab, [(0, 123456)], (99, 80), Z, tag)
    collision_tab = [10, 9, 8, 7]
    check('all_compressed_equal', collision_tab, list(enumerate(collision_tab)),
          (100, 3), O, tag)
    check('all_compressed_zero_empty', collision_tab, [], add((10, 0), tag), O, tag)
    check('all_compressed_zero_used', collision_tab, [(3, 7)], add((10, 0), tag), O, tag)
    malformed = [(-1, 9), (4, -7), (1, tab[1]+1), (-(1 << 63), (1 << 63)-1)]
    for k, pair in enumerate(malformed):
        a = add(add((pair[0] % P, 0), mul(beta, (pair[1] % P, 0))), tag)
        check(f'invalid_pair_zero_{k}', tab, [pair], a, beta, tag)

    # One somewhat larger counted case remains CPU-light; no scale benchmark.
    bigtab = [rng.randint(-32768, 32767) for _ in range(256)]
    bigpairs = [(i % 256, bigtab[i % 256]) for i in range(16384)]
    check('counted_16384_valid', bigtab, bigpairs, rnd(), rnd(), rnd())

    pipeline_cases = []
    tabs = [[0]*4, [4, -3, 7, 0], [-20, -2, 6, 11]]
    cols = [[(0, 0)], [(0, 4)], [(0, -20)]]
    b, gamma = (5, 9), (17, 13)
    checks = [('normal', (99, 80), cols)]
    for ti in range(3):
        for used in (False, True):
            ix = 0 if used else 2
            a = add(add((ix, 0), mul(Z if ti == 0 else b,
                                     (tabs[ti][ix] % P, 0))), mul(gamma, (ti+1, 0)))
            checks.append((f'zero_table{ti}_{"used" if used else "unused"}', a, cols))
    # A used later zero must win over an unused earlier table zero. With
    # gamma=beta=0 the same index has zero denominator in every table.
    both_cols = [[(0, 0)], [(2, 7)], [(2, 6)]]
    for name, a, c in checks:
        for pad in (4, 16):
            r = pipeline(reference, tabs, c, a, b, gamma, pad)
            q = pipeline(cached, tabs, c, a, b, gamma, pad)
            assert r == q, name
            pipeline_cases.append(dict(name=name, padded_table_len=pad,
                                       status=r['status'], stage=r.get('stage'),
                                       events=r['events']))
    for name, c in [('later_used_wins', both_cols), ('all_empty', [[], [], []]),
                    ('invalid_before_table', [[(0, 0)], [(2, 100)], [(0, -20)]])]:
        r = pipeline(reference, tabs, c, (2, 0), Z, Z, 16)
        q = pipeline(cached, tabs, c, (2, 0), Z, Z, 16)
        assert r == q
        pipeline_cases.append(dict(name=name, padded_table_len=16,
                                   status=r['status'], stage=r.get('stage'), events=r['events']))
    # Random schedules include invalid pairs and arbitrary public challenges.
    for k in range(24):
        c = [[(j % 4, t[j % 4]+(1 if k % 3 == 0 else 0)) for j in range(9)] for t in tabs]
        a, b1, g = rnd(), rnd(), rnd()
        assert pipeline(reference, tabs, c, a, b1, g, 16) == pipeline(cached, tabs, c, a, b1, g, 16)
        pipeline_cases.append(dict(name=f'random_{k}', status='ok', padded_table_len=16))

    negatives = []
    a = (99, 80)
    cache = cache_build(tab, a, beta, tag, counters())
    badpair = [(0, tab[0]+1)]
    assert [cache[0]] != oracle(badpair, a, beta, tag)
    negatives.append('index_only_cache_changes_invalid_value')
    assert [cache[-1]] != oracle([(-1, tab[-1])], a, beta, tag)
    negatives.append('negative_index_wrap')
    assert [cache[0]] != oracle([(len(tab), tab[0])], a, beta, tag)
    negatives.append('out_of_range_index_modulo')
    assert cached([(0, tab[0])], tab, a, beta, add(tag, O), counters(), cache) != oracle([(0, tab[0])], a, beta, add(tag, O))
    negatives.append('cache_reused_across_tags')
    assert cached([(0, tab[0])], tab, add(a, O), beta, tag, counters(), cache) != oracle([(0, tab[0])], add(a, O), beta, tag)
    negatives.append('cache_reused_across_challenges')
    unused = add(add((2, 0), mul(b, (tabs[1][2], 0))), mul(gamma, (2, 0)))
    good = pipeline(reference, tabs, cols, unused, b, gamma, 16)
    assert good['status'] == 'refuse' and good['stage'] == 'exp_table'
    eager = pipeline(cached, tabs, cols, unused, b, gamma, 16, eager=True)
    assert eager['stage'] == 'cache_build' and eager != good
    negatives.append('eager_public_zero_changes_refusal_stage')
    assert pipeline(cached, tabs, cols, unused, b, gamma, 16, skip_tables=True)['status'] == 'ok'
    negatives.append('omitting_whole_table_check_changes_acceptance')
    assert pipeline(cached, tabs, cols, unused, b, gamma, 16, skip_zero_counts=True)['status'] == 'ok'
    negatives.append('skipping_zero_multiplicity_changes_acceptance')
    prior = pipeline(reference, tabs, both_cols, (2, 0), Z, Z, 16)
    assert prior['stage'] == 'exp_helper'
    assert pipeline(cached, tabs, both_cols, (2, 0), Z, Z, 16, eager=True) != prior
    negatives.append('unused_earlier_table_cannot_preempt_used_later_helper')

    native_files = ['hashline/src/private_block/protocol.rs',
                    'hashline/src/private_block/argument.rs', 'zkp-core/src/field.rs']
    pins = {str(NATIVE / f): hashlib.sha256((NATIVE / f).read_bytes()).hexdigest() for f in native_files}
    pins[str(ROOT / 'hashline/src/private_block/protocol.rs')] = hashlib.sha256((ROOT / 'hashline/src/private_block/protocol.rs').read_bytes()).hexdigest()
    out = dict(schema='zkp-efficiency/pair-inverse-cache/v1', status='passed',
               run_identity='20260926T195233Z-cef0b7d6', seed=SEED, threads=1,
               cpu_affinity=sorted(os.sched_getaffinity(0)),
               cpu=next(x.split(':', 1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),
               platform=platform.platform(), python=platform.python_version(),
               limits=dict(wall_s=59, cpu_s=55, address_space_mib=512, estimated_memory_mib=64),
               differential_cases=comparisons, independently_solved_words=direct_words,
               pipeline_cases=pipeline_cases, negative_controls=negatives, cases=cases,
               source_pins=pins, experiment_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               proving_seconds=None, verification_seconds=None, complete_readiness_seconds=None,
               native_executed=False, gpu_executed=False,
               script_wall_s_not_proving=time.perf_counter()-started,
               peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
    (HERE / 'result.json').write_text(json.dumps(out, indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k not in ('cases','pipeline_cases','source_pins')}, indent=2))


if __name__ == '__main__':
    main()
