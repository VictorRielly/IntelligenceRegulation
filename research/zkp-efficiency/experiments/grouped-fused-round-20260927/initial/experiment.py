#!/usr/bin/env python3
"""Source-derived three-group fold/measure oracle, not a native proof.

Uses two pinned prior LOCAL research references, never downloaded code.
Counts table boundary reads/writes; scratch/cache/allocator traffic excluded.
"""
import copy
import hashlib
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
import oracle_groups as G
import oracle_fusion as I

F = G.F
HERE = Path(__file__).resolve().parent
SEED = 2026092709


def fixture(n, padded, mode, rng, tail=1):
    c = G.fixture(max(2, n), padded, mode, rng, limbs=3, tail_vars=min(tail, max(1, n-1)))
    if n < 2:
        c['n'], c['ht'] = n, 0
        c['tabs'] = {k: v[:1 << n] for k, v in c['tabs'].items()}
        c['points'] = [w[:n] if i != 1 else [] for i, w in enumerate(c['points'])]
    return c


class SharedRounds:
    """Serial transcription of the native grouped release loop and table order.

    All group starts are zero, as in SC_SZC. Equality tables are retained and
    folded even though bracket closures ignore them, matching native finals.
    """
    def __init__(self, c, fused=False, tile=3, reverse=False, fault=None):
        n = c['n']
        if tile < 1 or any(len(t) != 1 << n for t in c['tabs'].values()):
            raise ValueError('shape/tile')
        if [len(w) for w in c['points']] != [n, c['ht'], n]:
            raise ValueError('point support')
        self.c, self.n, self.j = c, n, 0
        self.fused, self.tile, self.reverse, self.fault = fused, tile, reverse, fault
        self.names = list(c['names'])
        self.tables = [[G.eq(w, G.bits(i, n)[:len(w)]) for i in range(1 << n)]
                       for w in c['points']] + [list(c['tabs'][k]) for k in self.names]
        self.degree = 5 if c['padded'] else 4
        self.ds = [4, 2, 2] if c['padded'] else [3, 1, 1]
        self.prefix, self.claims = [F(1)]*3, [None]*3
        self.pending = self.ready = None
        self.reads = self.writes = self.fallbacks = 0
        self.brackets = [0]*3
        self.meta_builds = self.split_entries = self.weights = self.partial_adds = 0

    def metadata(self):
        self.meta_builds += 1
        out = []
        for g, w in enumerate(self.c['points']):
            e = [self.prefix[g]*(G.eq(w[self.j:self.j+1], [F(t)]) if self.j < len(w) else F(1))
                 for t in range(self.degree+1)]
            suffix = w[self.j+1:]
            s = len(suffix)//2
            left = [G.eq(suffix[:s], G.bits(i, s)) for i in range(1 << s)]
            right = [G.eq(suffix[s:], G.bits(i, len(suffix)-s)) for i in range(1 << (len(suffix)-s))]
            trailing = self.n-self.j-1-len(suffix)
            self.split_entries += len(left)+len(right)
            recover = self.claims[g] is not None and e[1] != 0
            self.fallbacks += int(self.claims[g] is not None and e[1] == 0)
            out.append((e, left, right, trailing, recover))
        return out

    def zeros(self):
        return [[F()]*(d+1) for d in self.ds]

    def accumulate(self, sums, meta, i, left, right):
        cur = list(left)
        dif = [b-a for a, b in zip(left, right)]
        weights = []
        for _, ls, rs, trailing, _ in meta:
            pos = i >> trailing
            if self.fault == 'wrong_suffix' and self.j > 0:
                pos ^= 1
                pos %= len(ls)*len(rs)
            weights.append(ls[pos//len(rs)]*rs[pos % len(rs)])
            self.weights += 1
        for t in range(max(self.ds)+1):
            v = dict(zip(self.names, cur[3:]))
            for g in range(3):
                if t <= self.ds[g] and (t != 1 or not meta[g][4]):
                    sums[g][t] += weights[g]*G.inner(self.c, v, g)
                    self.brackets[g] += 1
            if t < max(self.ds):
                cur = [a+b for a, b in zip(cur, dif)]

    def finish(self, hs, meta):
        groups = []
        for g, (e, _, _, _, recover) in enumerate(meta):
            if recover:
                claim = self.claims[g]
                if self.fault == 'combined_claim':
                    claim = sum(self.claims, F())
                hs[g][1] = (claim-e[0]*hs[g][0])/e[1]
            groups.append([e[t]*(hs[g][t] if t <= self.ds[g] else G.lagrange(hs[g], F(t)))
                           for t in range(self.degree+1)])
        return groups

    def measure(self):
        h = len(self.tables[0])//2
        meta, hs = self.metadata(), self.zeros()
        for i in range(h):
            left = [tb[i] for tb in self.tables]
            right = [tb[i+h] for tb in self.tables]
            self.reads += 2*len(self.tables)
            self.accumulate(hs, meta, i, left, right)
        return self.finish(hs, meta)

    def round(self, j):
        if j != self.j or j >= self.n or self.pending is not None:
            raise ValueError('round schedule')
        self.pending = self.measure() if self.ready is None else self.ready
        self.ready = None
        return [sum((v[t] for v in self.pending), F()) for t in range(self.degree+1)]

    def fold(self, r):
        if self.pending is None:
            raise ValueError('fold needs a requested round')
        self.claims = [G.lagrange(v, r) for v in self.pending]
        self.pending = None
        for g, w in enumerate(self.c['points']):
            if self.j < len(w) and self.fault != 'stale_prefix':
                self.prefix[g] *= G.eq(w[self.j:self.j+1], [r])
        self.j += 1
        n, k = len(self.tables[0]), len(self.tables)
        if not self.fused or n == 2:
            # Independent nonmutating baseline formula.
            self.tables = [[(1-r)*tb[i]+r*tb[i+n//2] for i in range(n//2)] for tb in self.tables]
            self.reads += n*k
            self.writes += (n//2)*k
            return
        q = n//4
        meta, hs = self.metadata(), self.zeros()
        starts = list(range(0, q, self.tile))
        if self.reverse:
            starts.reverse()
        for start in starts:
            part = self.zeros()
            end = min(start+self.tile, q)
            if self.fault == 'drop_tail' and end-start < self.tile:
                continue
            for i in range(start, end):
                left, right = [], []
                for tb in self.tables:
                    a, b, c, d = tb[i], tb[i+q], tb[i+2*q], tb[i+3*q]
                    if self.fault == 'wrong_quarter':
                        b, c = c, b
                    l, h = a+r*(c-a), b+r*(d-b)
                    tb[i], tb[i+q] = l, h
                    left.append(l); right.append(h)
                    self.reads += 4; self.writes += 2
                self.accumulate(part, meta, i, left, right)
            for g in range(3):
                hs[g] = [a+b for a, b in zip(hs[g], part[g])]
                self.partial_adds += len(part[g])
        for tb in self.tables:
            del tb[2*q:]
        self.ready = self.finish(hs, meta)

    def finals(self):
        if self.j != self.n or self.pending is not None or self.ready is not None:
            raise ValueError('unfinished rounds')
        return [tb[0] for tb in self.tables]


def driver(ev, mask_delta=0):
    state, challenges = b'grouped-fusion-synthetic-only', []
    for j in range(ev.n):
        values = ev.round(j)
        # Independent public deterministic masks are schedule sentinels only.
        state = hashlib.sha256(state+b''.join((x+(F(19+j, 23+j)+mask_delta)*(2*t-1)).wire()
                                             for t, x in enumerate(values))).digest()
        r = F(int.from_bytes(state[:16], 'little'), int.from_bytes(state[16:], 'little'))
        challenges.append(r.wire().hex())
        ev.fold(r)
    return state.hex(), challenges, [v.wire().hex() for v in ev.finals()]


def case(c, tile, reverse=False, direct=False, force=None):
    ref = G.Grouped(c)
    plain, fast = SharedRounds(c), SharedRounds(c, True, tile, reverse)
    prefix, direct_points, samples, groups = [], 0, 0, 0
    for j in range(c['n']):
        a, b, d = ref.round(), plain.round(j), fast.round(j)
        assert a == b == d, ('round', c['n'], j)
        assert ref.pending == plain.pending == fast.pending, ('group polynomials', j)
        samples += len(a); groups += 3*len(a)
        if direct:
            for t, v in enumerate(a):
                assert v == G.oracle(c, prefix, t), ('cube', j, t)
                direct_points += 1
        r = (force[j] if force and j < len(force) else F(123+j, 917+31*j))
        prefix.append(r)
        ref.bind(r); plain.fold(r); fast.fold(r)
        assert plain.tables == fast.tables, ('intermediate tables', j)
        assert ref.claims == plain.claims == fast.claims, ('actual group claims', j)
        assert ref.prefix == plain.prefix == fast.prefix, ('prefix', j)
    finals = fast.finals()
    assert ref.finals() == plain.finals() == finals
    # Independent polynomial-convolution field multiplication AND direct MLE.
    original = SharedRounds(c).tables
    points = [(v.a, v.b) for v in prefix]
    expected = [I.direct_mle([(v.a, v.b) for v in tb], points) for tb in original]
    assert expected == [(v.a, v.b) for v in finals]
    assert fast.brackets == plain.brackets == ref.counts
    assert fast.meta_builds == plain.meta_builds == c['n']
    assert fast.split_entries == plain.split_entries and fast.weights == plain.weights
    n, k = 1 << c['n'], len(finals)
    if n > 1:
        assert plain.reads == (4*n-4)*k
        assert fast.reads == (3*n-2)*k
        assert plain.writes == fast.writes == (n-1)*k
    else:
        assert plain.reads == fast.reads == plain.writes == fast.writes == 0
    a, b = driver(SharedRounds(c)), driver(SharedRounds(c, True, tile, reverse))
    assert a == b
    return dict(rows=n, tables=k, padded=c['padded'], ht=c['ht'], tile=tile,
                reverse_tiles=reverse, samples=samples, group_samples=groups,
                direct_points=direct_points, independent_finals=k,
                reads_unfused=plain.reads, reads_fused=fast.reads, writes=fast.writes,
                logical_bytes_unfused=16*(plain.reads+plain.writes),
                logical_bytes_fused=16*(fast.reads+fast.writes),
                brackets=fast.brackets, fallbacks=fast.fallbacks,
                group_metadata_builds=fast.meta_builds, split_entries=fast.split_entries,
                suffix_weight_products=fast.weights, extra_partial_additions=fast.partial_adds,
                schedule_digest=a[0])


def refused(fn):
    try: fn()
    except ValueError: return True
    return False


def main():
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    os.nice(10)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    start, rng = time.perf_counter(), random.Random(SEED)
    rows = []
    for n, padded, mode in itertools.product((0, 1, 2, 3, 5, 8), (False, True), ('extension', 'base', 'zero')):
        c = fixture(n, padded, mode, rng, tail=max(1, n//2))
        # Three ragged tile sizes; reverse tile order varies by fixture.
        tile = {'extension': 3, 'base': 1, 'zero': 7}[mode]
        rows.append(case(c, tile, reverse=padded, direct=n <= 3))
    c = fixture(4, True, 'extension', rng, tail=2)
    c['points'][0][0] = F(1)
    c['points'][1][1] = F(0)
    rows.append(case(c, 3, direct=True, force=[F(0), F(1)]))
    controls = {}
    c = fixture(5, True, 'extension', rng, tail=2)
    for fault in ('stale_prefix', 'wrong_suffix', 'combined_claim', 'wrong_quarter', 'drop_tail'):
        good, bad = SharedRounds(c, True, 3), SharedRounds(c, True, 3, fault=fault)
        detected = False
        for j in range(c['n']):
            if good.round(j) != bad.round(j):
                detected = True; break
            good.fold(F(5, 11)); bad.fold(F(5, 11))
        controls[fault] = detected
    altered = copy.deepcopy(c); altered['tabs']['sg1'][7] += F(1)
    controls['changed_limb'] = driver(SharedRounds(c, True)) != driver(SharedRounds(altered, True))
    controls['changed_mask_schedule'] = driver(SharedRounds(c, True)) != driver(SharedRounds(c, True), mask_delta=1)
    # Actual changed challenge and equality-final table order controls.
    a, b = SharedRounds(c, True), SharedRounds(c, True)
    a.round(0); b.round(0); a.fold(F(5, 11)); b.fold(F(5, 12))
    controls['changed_challenge'] = a.round(1) != b.round(1)
    result_finals = driver(SharedRounds(c, True))[2]
    controls['swapped_equality_finals'] = result_finals[:2] != list(reversed(result_finals[:2]))
    # The final-two-row branch must not precompute a nonexistent next round.
    one = SharedRounds(fixture(1, False, 'extension', rng), True)
    one.round(0); one.fold(F(2, 3))
    controls['no_round_after_final_fold'] = one.ready is None and refused(lambda: one.round(1))
    schedule = []
    for fused in (False, True):
        x = SharedRounds(c, fused)
        schedule.extend([refused(lambda: x.fold(F(1))), refused(x.finals), refused(lambda: x.round(1))])
        x.round(0)
        schedule.append(refused(lambda: x.round(0)))
        x.fold(F(2, 3))
        schedule.extend([refused(lambda: x.fold(F(1))), refused(lambda: x.round(0))])
    malformed = []
    for kind in ('tile', 'table', 'point'):
        bad = copy.deepcopy(c)
        if kind == 'table': bad['tabs']['s8'].pop()
        if kind == 'point': bad['points'][1].pop()
        malformed.append(refused(lambda: SharedRounds(bad, True, 0 if kind == 'tile' else 3)))
    assert all(controls.values()) and all(schedule) and all(malformed)
    result = dict(status='passed', run_identity='20260927T005233Z-ccb9384b', seed=SEED,
                  field='Goldilocks Fp2, u^2=7', cases=rows, differential_cases=len(rows),
                  samples=sum(r['samples'] for r in rows), group_samples=sum(r['group_samples'] for r in rows),
                  direct_round_points=sum(r['direct_points'] for r in rows),
                  independent_final_mles=sum(r['independent_finals'] for r in rows),
                  zero_factor_fallbacks=sum(r['fallbacks'] for r in rows),
                  negative_controls=controls, schedule_refusals=sum(schedule), malformed_refusals=sum(malformed),
                  synthetic_driver_comparisons=len(rows), threads=1, affinity=sorted(os.sched_getaffinity(0)),
                  cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),
                  python=platform.python_version(), platform=platform.platform(),
                  limits=dict(wall_s=59, cpu_s=55, address_space_mib=512, estimated_memory_mib=40),
                  elapsed_s=time.perf_counter()-start, peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                  source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  proving_s=None, verification_s=None, complete_readiness_s=None,
                  native_compiled=False, gpu_executed=False,
                  scope='Synthetic SC_SZC plane wiring; native transcript/RNG/receipt/security untested. Logical table traffic is not DRAM or timing.')
    (HERE/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k != 'cases'}, indent=2))


if __name__ == '__main__': main()
