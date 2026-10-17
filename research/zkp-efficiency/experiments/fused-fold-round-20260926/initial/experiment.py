#!/usr/bin/env python3
"""Exact synthetic Fp2 fusion oracle; no native proof, GPU, or external code.

Logical table traffic is counted, not measured DRAM traffic. SHA-256 driver
below tests a schedule model, not the native masked transcript implementation.
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
SEED = 2026092605
HERE = Path(__file__).resolve().parent


def add(a, b):
    return ((a[0]+b[0]) % P, (a[1]+b[1]) % P)


def sub(a, b):
    return ((a[0]-b[0]) % P, (a[1]-b[1]) % P)


def mul(a, b):
    return ((a[0]*b[0]+7*a[1]*b[1]) % P,
            (a[0]*b[1]+a[1]*b[0]) % P)


def scale(a, b):
    return (a[0]*b % P, a[1]*b % P)


def lerp(a, b, r):
    return add(a, mul(r, sub(b, a)))


def poly(v, degree):
    if degree == 2:
        return add(mul(v[0], v[1]), sub(v[2], v[3]))
    return add(mul(mul(v[0], v[1]), v[2]), v[3])


def interpolate(vals, r):
    out = Z
    for i, v in enumerate(vals):
        num, den = O, 1
        for j in range(len(vals)):
            if i != j:
                num = mul(num, sub(r, (j, 0)))
                den = den*(i-j) % P
        out = add(out, mul(v, scale(num, pow(den, -1, P))))
    return out


def oracle_mul(a, b):
    # Independent schoolbook polynomial product followed by u^2 = 7.
    coeff = [0, 0, 0]
    for i in range(2):
        for j in range(2):
            coeff[i+j] += a[i]*b[j]
    coeff[0] += 7*coeff[2]
    return (coeff[0] % P, coeff[1] % P)


def oracle_poly(v, degree):
    product = O
    for t in v[:degree]:
        product = oracle_mul(product, t)
    if degree == 2:
        return ((product[0]+v[2][0]-v[3][0]) % P,
                (product[1]+v[2][1]-v[3][1]) % P)
    return ((product[0]+v[3][0]) % P, (product[1]+v[3][1]) % P)


def bits(i, n):
    return [(i >> j) & 1 for j in reversed(range(n))]


def direct_mle(table, point):
    # Full cube definition; no recursive folding, interpolation or fusion.
    total = [0, 0]
    for i, value in enumerate(table):
        weight = O
        for bit, r in zip(bits(i, len(point)), point):
            term = r if bit else ((1-r[0]) % P, -r[1] % P)
            weight = oracle_mul(weight, term)
        value = oracle_mul(weight, value)
        total[0] += value[0]
        total[1] += value[1]
    return (total[0] % P, total[1] % P)


def direct_round(original, prefix, degree):
    rem = (len(original[0]).bit_length()-1)-len(prefix)-1
    values = []
    for t in range(degree+1):
        total = [0, 0]
        for i in range(1 << rem):
            point = prefix+[(t, 0)]+[(b, 0) for b in bits(i, rem)]
            v = oracle_poly([direct_mle(tb, point) for tb in original], degree)
            total[0] += v[0]
            total[1] += v[1]
        values.append((total[0] % P, total[1] % P))
    return values


class Separate:
    """Source-derived release schedule: round read, then MSB fold read/write."""
    def __init__(self, tables, degree, recover=True, chunk=3, reverse=False):
        if len(tables) != 4 or not tables[0]:
            raise ValueError('four nonempty tables required by synthetic polynomial')
        n = len(tables[0])
        if n & (n-1) or any(len(t) != n for t in tables):
            raise ValueError('full equal-sized power-of-two tables required')
        if degree not in (2, 3) or chunk < 1:
            raise ValueError('unsupported synthetic degree or chunk')
        self.tables = [list(t) for t in tables]
        self.degree, self.recover, self.chunk = degree, recover, chunk
        self.reverse = reverse
        self.n_vars, self.next = n.bit_length()-1, 0
        self.pending, self.claim, self.ready = None, None, None
        self.reads = self.writes = self.evals = 0

    def measure(self):
        half = len(self.tables[0])//2
        acc = [Z]*(self.degree+1)
        for i in range(half):
            left = [tb[i] for tb in self.tables]
            right = [tb[i+half] for tb in self.tables]
            self.reads += 8
            for t in range(self.degree+1):
                if t == 1 and self.recover and self.claim is not None:
                    continue
                vals = [add(scale(a, 1-t), scale(b, t)) for a, b in zip(left, right)]
                acc[t] = add(acc[t], poly(vals, self.degree))
                self.evals += 1
        if self.recover and self.claim is not None:
            acc[1] = sub(self.claim, acc[0])
        return acc

    def round(self, j):
        if j != self.next or j >= self.n_vars or self.pending is not None:
            raise ValueError('round order')
        sums = self.measure() if self.ready is None else self.ready
        self.ready = None
        self.pending = list(sums)
        return sums

    def begin_fold(self, r):
        if self.pending is None:
            raise ValueError('fold requires round')
        if self.recover:
            self.claim = interpolate(self.pending, r)
        self.pending = None

    def fold(self, r):
        self.begin_fold(r)
        half = len(self.tables[0])//2
        self.tables = [[add(mul(sub(O, r), tb[i]), mul(r, tb[i+half]))
                        for i in range(half)] for tb in self.tables]
        self.reads += 8*half
        self.writes += 4*half
        self.next += 1

    def finals(self):
        if self.next != self.n_vars or self.pending is not None or self.ready is not None:
            raise ValueError('finals requires all folds and no cached round')
        return [tb[0] for tb in self.tables]


class Fused(Separate):
    """Four-quarter in-place fold with next-round samples cached in fold()."""
    def fold(self, r):
        self.begin_fold(r)
        n = len(self.tables[0])
        if n == 2:
            for tb in self.tables:
                tb[0] = lerp(tb[0], tb[1], r)
                del tb[1:]
            self.reads += 8
            self.writes += 4
            self.next += 1
            return
        q = n//4
        acc = [Z]*(self.degree+1)
        chunks = list(range(0, q, self.chunk))
        if self.reverse:
            chunks.reverse()
        for lo in chunks:
            partial = [Z]*(self.degree+1)
            for i in range(lo, min(lo+self.chunk, q)):
                cur, delta = [], []
                for tb in self.tables:
                    a, b, c, d = tb[i], tb[i+q], tb[i+2*q], tb[i+3*q]
                    left, right = lerp(a, c, r), lerp(b, d, r)
                    # This i owns both writes; no other i reads these cells.
                    tb[i], tb[i+q] = left, right
                    cur.append(left)
                    delta.append(sub(right, left))
                    self.reads += 4
                    self.writes += 2
                for t in range(self.degree+1):
                    if t != 1 or not self.recover or self.claim is None:
                        partial[t] = add(partial[t], poly(cur, self.degree))
                        self.evals += 1
                    if t < self.degree:
                        cur = [add(a, b) for a, b in zip(cur, delta)]
            acc = [add(a, b) for a, b in zip(acc, partial)]
        if self.recover and self.claim is not None:
            acc[1] = sub(self.claim, acc[0])
        for tb in self.tables:
            del tb[2*q:]
        self.ready = acc
        self.next += 1


def serialize(values):
    return b''.join(a.to_bytes(8, 'little')+b.to_bytes(8, 'little') for a, b in values)


def schedule_driver(ev, masks):
    state, challenges, messages, events = b'fusion-synthetic-only', [], [], []
    for j in range(ev.n_vars):
        sums = ev.round(j)
        published = [add(v, masks[j][i]) for i, v in enumerate(sums)]
        state = hashlib.sha256(state+serialize(published)).digest()
        r = (int.from_bytes(state[:16], 'little') % P,
             int.from_bytes(state[16:], 'little') % P)
        messages.append(published)
        challenges.append(r)
        events.extend([['publish', j], ['challenge', j], ['fold', j]])
        ev.fold(r)
    return messages, challenges, ev.finals(), events, state.hex()


def expect_refusal(fn):
    try:
        fn()
    except ValueError:
        return True
    raise AssertionError('missing refusal')


def main():
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    start = time.perf_counter()
    rng = random.Random(SEED)
    rand = lambda: (rng.randrange(P), rng.randrange(P))
    cases, direct_rounds, direct_finals, model_drivers = [], 0, 0, 0
    for n in (1, 2, 4, 8, 16, 32, 64, 256, 1024):
        for degree in (2, 3):
            for mode in ('extension', 'base', 'zero_eq'):
                tables = [[rand() for _ in range(n)] for _ in range(4)]
                if mode == 'base':
                    tables = [[(x[0], 0) for x in tb] for tb in tables]
                if mode == 'zero_eq':
                    # Equality to Boolean zero; challenge 1 annihilates factor.
                    tables[0] = [O]+[Z]*(n-1)
                for recover in (False, True):
                    chunk = (1, 3, 7)[(n.bit_length()+degree+recover) % 3]
                    ref = Separate(tables, degree, recover, chunk)
                    fused = Fused(tables, degree, recover, chunk, reverse=bool(recover))
                    challenges = [rand() for _ in range(ref.n_vars)]
                    if challenges and mode == 'zero_eq':
                        challenges[0] = O
                    elif challenges and mode == 'base':
                        challenges[0] = Z
                    prefix = []
                    for j, r in enumerate(challenges):
                        a, b = ref.round(j), fused.round(j)
                        assert a == b
                        if n <= 32:
                            assert a == direct_round(tables, prefix, degree)
                            direct_rounds += 1
                        ref.fold(r)
                        fused.fold(r)
                        assert ref.tables == fused.tables
                        prefix.append(r)
                    expected = [direct_mle(tb, prefix) for tb in tables]
                    assert ref.finals() == fused.finals() == expected
                    direct_finals += 4
                    assert ref.evals == fused.evals
                    reads_ref = 0 if n == 1 else 16*(n-1)
                    reads_fused = 0 if n == 1 else 4*(3*n-2)
                    assert (ref.reads, fused.reads) == (reads_ref, reads_fused)
                    assert ref.writes == fused.writes == 4*(n-1)
                    cases.append(dict(n=n, degree=degree, mode=mode, recover=recover,
                                      chunk=chunk, reverse_chunks=bool(recover),
                                      baseline_reads=ref.reads, fused_reads=fused.reads,
                                      writes=ref.writes, polynomial_evals=ref.evals))
                masks = [[rand() for _ in range(degree+1)] for _ in range(n.bit_length()-1)]
                a = schedule_driver(Separate(tables, degree), masks)
                b = schedule_driver(Fused(tables, degree), masks)
                assert a == b
                model_drivers += 1

    # Mutations deliberately use non-degenerate deterministic extension data.
    tables = [[rand() for _ in range(16)] for _ in range(4)]
    r, q = (3, 5), 4
    correct = [[lerp(tb[i], tb[i+8], r) for i in range(8)] for tb in tables]
    controls = {}
    controls['wrong_adjacent_pairing'] = correct != [[lerp(tb[2*i], tb[2*i+1], r) for i in range(8)] for tb in tables]
    controls['drop_extension_limb'] = correct != [[lerp(tb[i], tb[i+8], (r[0], 0)) for i in range(8)] for tb in tables]
    wrong = [tb[:] for tb in tables]
    for tb in wrong:
        for i in range(q):
            tb[i], tb[i+q] = lerp(tb[i], tb[i+q], r), lerp(tb[i+2*q], tb[i+3*q], r)
        del tb[2*q:]
    controls['wrong_quarters'] = correct != wrong
    controls['swapped_output_halves'] = correct != [tb[q:]+tb[:q] for tb in correct]
    broken = [tb[:] for tb in tables]
    for tb in broken:
        # A naïve chunk loop silently drops q % chunk.
        for i in range((q//3)*3):
            tb[i], tb[i+q] = lerp(tb[i], tb[i+2*q], r), lerp(tb[i+q], tb[i+3*q], r)
        del tb[2*q:]
    controls['dropped_partial_chunk'] = correct != broken
    f = Fused(tables, 3); s = f.round(0); f.fold(r)
    next_s = f.round(1)
    controls['stale_cached_round'] = next_s != s
    wrong_claim = next_s[:]; wrong_claim[1] = add(wrong_claim[1], O)
    controls['masked_claim_used_for_recovery'] = next_s != wrong_claim
    controls['final_table_order'] = [tb[0] for tb in correct] != [tb[0] for tb in reversed(correct)]
    assert all(controls.values())
    refusals = {}
    for cls in (Separate, Fused):
        name = cls.__name__
        refusals[name+'_fold_without_round'] = expect_refusal(lambda: cls(tables, 2).fold(r))
        refusals[name+'_wrong_round_index'] = expect_refusal(lambda: cls(tables, 2).round(1))
        refusals[name+'_premature_finals'] = expect_refusal(lambda: cls(tables, 2).finals())
        ev = cls(tables, 2); ev.round(0)
        refusals[name+'_double_round'] = expect_refusal(lambda: ev.round(0))
        ev.fold(r)
        refusals[name+'_double_fold'] = expect_refusal(lambda: ev.fold(r))
        for bad in ([], [[], [], [], []], [[O]*3]*4, [[O]*4]*3+[[O]*2]):
            expect_refusal(lambda: cls(bad, 2))
    # Independent field primitive sanity including wraparound and basis values.
    for a in (Z, O, (0, 1), (P-1, P-1), rand()):
        for b in (Z, O, (0, 1), (P-1, P-1), rand()):
            assert mul(a, b) == oracle_mul(a, b)
    cpu = next(x.split(':', 1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name'))
    result = dict(status='passed', run_identity='20260926T205233Z-79c00f5e', seed=SEED,
                  threads=1, cpu_affinity=sorted(os.sched_getaffinity(0)), cpu=cpu,
                  platform=platform.platform(), python=platform.python_version(),
                  estimated_memory_mib=32, limits=dict(wall_s=59, cpu_s=55, address_space_mib=512),
                  differential_cases=len(cases), independent_round_oracles=direct_rounds,
                  independent_final_mles=direct_finals, synthetic_masked_driver_cases=model_drivers,
                  negative_controls=controls, schedule_refusals=refusals,
                  malformed_fixture_refusals=8, cases=cases,
                  field='Goldilocks Fp2, u^2=7', tables=4,
                  script_wall_s_not_proving=time.perf_counter()-start,
                  peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                  experiment_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  proving_seconds=None, verification_seconds=None, complete_readiness_seconds=None,
                  native_executed=False, gpu_executed=False,
                  limitations=['Logical loads/stores, not measured DRAM bytes or runtime speedup',
                               'Synthetic degree-2/3 polynomials; full SC_SZC grouped evaluator not ported',
                               'Driver schedule model does not test native CFS masking, RNG, extension rounds, PCS or receipts'])
    (HERE/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k != 'cases'}, indent=2))


if __name__ == '__main__':
    main()
