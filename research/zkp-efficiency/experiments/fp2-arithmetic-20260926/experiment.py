#!/usr/bin/env python3
"""Canonical Goldilocks Fp2 arithmetic, fixed-width transcription vs big ints.

Research-only: no native proof or timing projection. All data are synthetic.
"""
import collections
import hashlib
import importlib.util
import itertools
import json
import os
from pathlib import Path
import platform
import random
import resource
import signal
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
P = 2**64 - 2**32 + 1
U64, U128, EPS = 2**64-1, 2**128-1, 2**32-1
SEED = 2026092607
COUNTS = collections.Counter()


def canonical(a):
    if type(a) is not int or not 0 <= a < P:
        raise ValueError('noncanonical test fixture')
    return a


def new(a):
    assert 0 <= a <= U64
    return a-P if a >= P else a


def add(a, b):
    COUNTS['add'] += 1
    s = canonical(a)+canonical(b)
    r = s & U64
    if s > U64:
        r = (r+EPS) & U64
    return new(r)


def sub(a, b):
    COUNTS['sub'] += 1
    canonical(a); canonical(b)
    r = (a-b) & U64
    return (r-EPS) & U64 if a < b else r


def reduce128(x):
    # Exactly the current Rust unsigned wrap/borrow/carry sequence.
    COUNTS['reduce128'] += 1
    assert 0 <= x <= U128
    lo, hi = x & U64, x >> 64
    hi_hi, hi_lo = hi >> 32, hi & EPS
    t0 = (lo-hi_hi) & U64
    if lo < hi_hi:
        t0 = (t0-EPS) & U64
    t1 = hi_lo*EPS
    s = t0+t1
    r = s & U64
    if s > U64:
        r = (r+EPS) & U64
    return new(r)


def bm(a, b):
    COUNTS['variable_mul'] += 1
    return reduce128(canonical(a)*canonical(b))


def times7(a):
    COUNTS['constant_mul_7'] += 1
    return reduce128(canonical(a)*7)


def times7_adds(a):
    return sub(add(add(add(a, a), add(a, a)), add(add(a, a), add(a, a))), a)


def times7_chain(a):
    # Three dependent doubles, then subtract; no noncanonical intermediates.
    x = add(a, a)
    x = add(x, x)
    return sub(add(x, x), a)


def school(a, b, nr=times7):
    ac, bd, ad, bc = bm(a[0], b[0]), bm(a[1], b[1]), bm(a[0], b[1]), bm(a[1], b[0])
    return add(ac, nr(bd)), add(ad, bc)


def kara(a, b, nr=times7):
    ac, bd = bm(a[0], b[0]), bm(a[1], b[1])
    cross = bm(add(a[0], a[1]), add(b[0], b[1]))
    return add(ac, nr(bd)), sub(sub(cross, ac), bd)


def square3(a, nr=times7):
    aa, bb, ab = bm(a[0], a[0]), bm(a[1], a[1]), bm(a[0], a[1])
    return add(aa, nr(bb)), add(ab, ab)


def square2(a, nr=times7):
    ab = bm(a[0], a[1])
    product = bm(add(a[0], a[1]), add(a[0], nr(a[1])))
    twice = add(ab, ab)
    four = add(twice, twice)
    eight = add(four, four)
    return sub(product, eight), twice


def oracle(a, b):
    # Independent unbounded polynomial convolution and long reduction by X^2-7.
    c = [0, 0, 0]
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            c[i+j] += x*y
    for degree in range(len(c)-1, 1, -1):
        c[degree-2] += 7*c[degree]
        c[degree] = 0
    return tuple(x % P for x in c[:2])


def wire(a):
    assert all(0 <= x < P for x in a)
    return b''.join(x.to_bytes(8, 'little') for x in a)


def exponent(a, n, mul, square):
    z = (1, 0)
    while n:
        if n & 1:
            z = mul(z, a)
        a = square(a)
        n >>= 1
    return z


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE/filename)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def downstream(rng):
    f = module('fusion_fixture', 'fused_reference.py')
    g = module('group_fixture', 'grouped_reference.py')
    draw = lambda: (rng.randrange(P), rng.randrange(P))
    variants = {'schoolbook': school, 'karatsuba': kara,
                'karatsuba_add7': lambda a, b: kara(a, b, times7_chain)}
    fused_cases, grouped_cases, rounds, finals, direct_points = 0, 0, 0, 0, 0
    profiles = {}
    digests = hashlib.sha256()
    for n, degree, mode in itertools.product((1, 2, 4, 8, 16, 32), (2, 3), ('full', 'zero_eq')):
        tables = [[draw() for _ in range(n)] for _ in range(4)]
        if mode == 'zero_eq':
            tables[0] = [(1, 0)]+[(0, 0)]*(n-1)
        challenges = [draw() for _ in range(n.bit_length()-1)]
        if challenges and mode == 'zero_eq':
            challenges[0] = (1, 0)
        expected_rounds, prefix = [], []
        for r in challenges:
            expected_rounds.append(f.direct_round(tables, prefix, degree))
            prefix.append(r)
        expected_final = [f.direct_mle(tb, prefix) for tb in tables]
        for name, mul in variants.items():
            f.mul = mul
            ev = f.Fused(tables, degree, recover=True, chunk=3, reverse=True)
            for j, r in enumerate(challenges):
                actual = ev.round(j)
                assert actual == expected_rounds[j], ('fused', name, n, degree, j)
                rounds += len(actual)
                ev.fold(r)
            assert ev.finals() == expected_final
            finals += 4
        masks = [[draw() for _ in range(degree+1)] for _ in challenges]
        outcomes = []
        for mul in variants.values():
            f.mul = mul
            outcomes.append(f.schedule_driver(f.Fused(tables, degree, chunk=3), masks))
        assert outcomes[0] == outcomes[1] == outcomes[2]
        digests.update(outcomes[0][-1].encode())
        fused_cases += 1

    original_mul = g.F.__mul__
    for n, padded, mode in itertools.product((2, 3), (False, True), ('base', 'extension', 'zero')):
        g.F.__mul__, g.F.__rmul__ = original_mul, original_mul
        c = g.fixture(n, padded, mode, rng)
        # Exercise subgroup zero-factor fallback in a dedicated fixture below.
        baseline = g.run_case(c, direct=True)
        direct_points += baseline['direct_points']
        for name, mul in variants.items():
            def replacement(x, y, kernel=mul):
                if not isinstance(y, g.F):
                    return g.F(x.a*y, x.b*y)
                return g.F(*kernel((x.a, x.b), (y.a, y.b)))
            g.F.__mul__, g.F.__rmul__ = replacement, replacement
            COUNTS.clear()
            actual = g.run_case(c, direct=False)
            # Independent original-arithmetic round/MLE oracle was evaluated above.
            assert {k:v for k,v in baseline.items() if k != 'direct_points'} == {k:v for k,v in actual.items() if k != 'direct_points'}
            if (n, padded, mode) == (3, True, 'extension'):
                profiles[name] = dict(COUNTS)
        digests.update(baseline['digest'].encode())
        grouped_cases += 1
    g.F.__mul__, g.F.__rmul__ = original_mul, original_mul
    c = g.fixture(4, True, 'extension', rng)
    c['points'][0][0], c['points'][1][1] = g.F(1), g.F(0)
    baseline = g.run_case(c, direct=True, forced=[g.F(0)])
    direct_points += baseline['direct_points']
    for name, mul in variants.items():
        def replacement(x, y, kernel=mul):
            if not isinstance(y, g.F):
                return g.F(x.a*y, x.b*y)
            return g.F(*kernel((x.a, x.b), (y.a, y.b)))
        g.F.__mul__, g.F.__rmul__ = replacement, replacement
        actual = g.run_case(c, forced=[g.F(0)])
        assert actual['digest'] == baseline['digest'] and actual['zero_factor_fallbacks'] > 0
    return dict(fused_fixtures=fused_cases, fused_round_samples=rounds, final_mles=finals,
                synthetic_schedule_cases=fused_cases, grouped_fixtures=grouped_cases+1,
                grouped_independent_round_points=direct_points,
                zero_factor_fallbacks=baseline['zero_factor_fallbacks'],
                synthetic_digest=digests.hexdigest(),
                grouped_harness_field_kernel_counts=profiles,
                counts_scope='All extension multiplications in small run_case harness including reference, grouped, no-recovery and final-MLE checks; NOT native slot counts')


def main():
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    os.nice(10)
    start = time.perf_counter()
    rng = random.Random(SEED)
    edges = [0, 1, 2, 7, EPS, EPS+1, 2**63, P//2, P-8, P-2, P-1]
    base_pairs = list(itertools.product(edges, repeat=2))
    base_pairs += [(rng.randrange(P), rng.randrange(P)) for _ in range(10000)]
    for a, b in base_pairs:
        assert add(a,b) == (a+b) % P
        assert sub(a,b) == (a-b) % P
        assert bm(a,b) == a*b % P
    wide = [0, 1, U128, U128-1, (P-1)**2, 2**64, 2**96]
    wide += [rng.getrandbits(128) for _ in range(10000)]
    for x in wide:
        assert reduce128(x) == x % P
    products = itertools.chain(itertools.product(edges, repeat=4),
                               ([rng.randrange(P) for _ in range(4)] for _ in range(10000)))
    count = 0
    digest = hashlib.sha256()
    for a,b,c,d in products:
        x,y=(a,b),(c,d)
        expected=oracle(x,y)
        for actual in (school(x,y), kara(x,y), kara(x,y,times7_chain)):
            assert wire(actual)==wire(expected)
        digest.update(wire(expected)); count+=1
    square_inputs = list(itertools.product(edges, repeat=2))
    square_inputs += [(rng.randrange(P), rng.randrange(P)) for _ in range(10000)]
    for x in square_inputs:
        expected=oracle(x,x)
        for actual in (school(x,x), square3(x), square2(x), square2(x,times7_chain)):
            assert wire(actual)==wire(expected)
        digest.update(wire(expected))
    powers=0
    for a in [(0,0),(1,0),(0,1),(P-1,P-1),(13,17)]:
        for n in (0,1,2,3,31,255,2**127+31):
            expected=exponent(a,n,oracle,lambda x:oracle(x,x))
            assert exponent(a,n,kara,square2)==expected
            powers+=1
    # Deliberate wrong arithmetic; every control must be distinguished.
    x,y=(P-1,P-1),(P-1,P-1)
    ac,bd=bm(x[0],y[0]),bm(x[1],y[1])
    wrong_cross = (((x[0]+x[1]) & U64)*((y[0]+y[1]) & U64)) % P
    controls={
        'unreduced_u64_sums': (add(ac,times7(bd)), sub(sub(wrong_cross,ac),bd)) != oracle(x,y),
        'deferred_real_u128_overflow': ((x[0]*y[0]+7*x[1]*y[1]) & U128) % P != oracle(x,y)[0],
        'deferred_cross_u128_overflow': ((x[0]*y[1]+x[1]*y[0]) & U128) % P != oracle(x,y)[1],
        'wrong_nonresidue': kara((0,1),(0,1),lambda a:bm(a,3)) != oracle((0,1),(0,1)),
        'drop_cross_term': (oracle((3,5),(7,11))[0],3*11 % P) != oracle((3,5),(7,11)),
        'square_missing_double': (square2((3,5))[0],15) != oracle((3,5),(3,5)),
        'square_subtract_7ab': ((8*38-7*15)%P,30) != oracle((3,5),(3,5)),
        'omit_subtraction_borrow': ((0-1)&U64) != sub(0,1),
        'omit_addition_carry': new((2*(P-1))&U64) != add(P-1,P-1),
        'wire_limb_swap': wire(kara((3,5),(7,11))[::-1]) != wire(oracle((3,5),(7,11))),
        'changed_input': kara((3,6),(7,11)) != oracle((3,5),(7,11)),
    }
    assert all(controls.values()), controls
    refusals=0
    for bad in (-1,P,U64,True):
        try: kara((bad,0),(1,0))
        except ValueError: refusals+=1
    assert refusals==4
    costs={}
    funcs={'schoolbook_mul':lambda:school((3,5),(7,11)),
           'karatsuba_mul':lambda:kara((3,5),(7,11)),
           'karatsuba_mul_add7':lambda:kara((3,5),(7,11),times7_chain),
           'literal_square_via_mul':lambda:school((3,5),(3,5)),
           'square3_or_ideal_cse':lambda:square3((3,5)),
           'square2':lambda:square2((3,5)),
           'square2_add7':lambda:square2((3,5),times7_chain)}
    for k,fn in funcs.items():
        COUNTS.clear(); fn(); costs[k]=dict(COUNTS)
    ds=downstream(rng)
    result=dict(status='passed',run_identity='20260926T225233Z-f66107c9',seed=SEED,
                threads=1,cpu_affinity=sorted(os.sched_getaffinity(0)),
                cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),
                platform=platform.platform(),python=platform.python_version(),
                limits=dict(wall_s=59,cpu_s=55,address_space_mib=512),estimated_memory_mib=32,
                base_pair_cases=len(base_pairs),wide_reduction_cases=len(wide),
                multiplication_cases=count,square_cases=len(square_inputs),exponent_cases=powers,
                multiplication_variants=3,square_variants=4,
                negative_controls=controls,fixture_refusals=refusals,
                arithmetic_digest=digest.hexdigest(),operation_counts=costs,downstream=ds,
                source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                elapsed_s=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                proving_s=None,verification_s=None,complete_readiness_s=None,
                native_compiled=False,gpu_executed=False,
                limitations=['Fixed-width Python transcription, not compiled Rust or CUDA',
                             'Operation counts are unweighted source-level calls, not instructions, latency or speed',
                             'Compiler may CSE duplicate cross product in original square; square3 is not claimed as saving',
                             'Synthetic schedule hashes do not test native masking/RNG/PCS/receipt behavior',
                             'Canonical limb contract unchanged; malformed fixtures are harness refusals only'])
    (HERE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    main()
