#!/usr/bin/env python3
"""Locally authored bounded oracle, not a native proof or performance result."""
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
import time
import reference_support as ref

F = ref.F
HERE = Path(__file__).resolve().parent
SEED = 2026100429


def prefix_stream(challenges):
    """MSB prefix weights, O(j) stack, no 2^j-sized weight allocation."""
    def visit(depth, index, weight):
        if depth == len(challenges):
            yield index, weight
        else:
            r = challenges[depth]
            yield from visit(depth + 1, index * 2, weight * (1 - r))
            yield from visit(depth + 1, index * 2 + 1, weight * r)
    yield from visit(0, 0, F(1))


class WindowRounds:
    """Keep original inputs external, reconstruct bounded half-split pairs.

    One source scan per early round; switch once the whole residual fits.
    Source is borrowed and assumed immutable, not duplicated or authenticated
    by this class. Native readers must resolve the actual A/H slices/gates.
    """
    def __init__(self, c, pairs, reverse_index=False):
        if pairs < 1:
            raise ValueError('pair capacity')
        size = 1 << c['n']
        if not c['tabs'] or any(len(v) != size for v in c['tabs'].values()):
            raise ValueError('table shape')
        if any(len(w) > c['n'] for w in c['points']) or len(c['points']) != 3:
            raise ValueError('equality shape')
        self.c, self.pairs, self.reverse_index = c, pairs, reverse_index
        self.j, self.pending, self.prefix = 0, None, []
        self.group_claims = [None] * 3
        self.resident = None
        self.counts = dict(source_reads=0, reconstruction_mul=0,
                           reconstruction_add=0, prefix_weight_mul=0,
                           prefix_nodes=0, inplace_fold_mul=0,
                           inplace_fold_add=0, inplace_fold_sub=0,
                           peak_pair_entries=0, resident_capacity_entries=0,
                           fallback_zero_factor=0, recovered_one=0,
                           source_round_scans=0, switch_round=None)

    def reconstruct(self, rows):
        remaining = 1 << (self.c['n'] - self.j)
        out = {name: [F() for _ in rows] for name in self.c['names']}
        for index, weight in prefix_stream(self.prefix):
            for name in self.c['names']:
                src = self.c['tabs'][name]
                for k, row in enumerate(rows):
                    address = index * remaining + row
                    if self.reverse_index:
                        address = int(f'{address:0{self.c["n"]}b}'[::-1], 2)
                    value = src[address]
                    self.counts['source_reads'] += 1
                    if self.j == 0:
                        out[name][k] = value
                    else:
                        out[name][k] += weight * value
                        self.counts['reconstruction_mul'] += 1
                        self.counts['reconstruction_add'] += 1
        # prefix_stream produces each internal edge weight once per invocation.
        edges = 2 * ((1 << self.j) - 1)
        self.counts['prefix_nodes'] += edges
        self.counts['prefix_weight_mul'] += edges
        self.counts['peak_pair_entries'] = max(self.counts['peak_pair_entries'],
                                               len(rows) * len(out))
        return out

    def round(self, j):
        if j != self.j or self.pending is not None or j >= self.c['n']:
            raise ValueError('round order')
        remaining = 1 << (self.c['n'] - j)
        half = remaining // 2
        if self.resident is None:
            self.counts['source_round_scans'] += 1
            if remaining <= 2 * self.pairs:
                self.resident = self.reconstruct(list(range(remaining)))
                self.counts['resident_capacity_entries'] = remaining * len(self.c['names'])
                self.counts['switch_round'] = j
        degree = 5 if self.c['padded'] else 4
        degrees = [4 if self.c['padded'] else 3,
                   2 if self.c['padded'] else 1,
                   2 if self.c['padded'] else 1]
        factors, suffixes = [], []
        for point in self.c['points']:
            used = min(j, len(point))
            prev = ref.eq(point[:used], self.prefix[:used])
            factors.append([prev * ref.eq(point[j:j+1], [F(t)])
                            if j < len(point) else prev
                            for t in range(degree + 1)])
            suffixes.append(point[j+1:])
        recover = [self.group_claims[g] is not None and factors[g][1] != 0
                   for g in range(3)]
        for g in range(3):
            if self.group_claims[g] is not None:
                self.counts['recovered_one' if recover[g] else 'fallback_zero_factor'] += 1
        sums = [[F() for _ in range(d + 1)] for d in degrees]
        for lo in range(0, half, self.pairs):
            count = min(self.pairs, half - lo)
            if self.resident is None:
                rows = list(range(lo, lo + count)) + list(range(lo + half, lo + half + count))
                buf = self.reconstruct(rows)
            for k in range(count):
                if self.resident is None:
                    left = {name: buf[name][k] for name in self.c['names']}
                    right = {name: buf[name][k + count] for name in self.c['names']}
                else:
                    left = {name: self.resident[name][lo + k] for name in self.c['names']}
                    right = {name: self.resident[name][lo + k + half] for name in self.c['names']}
                dif = {name: right[name] - left[name] for name in self.c['names']}
                tail = ref.bits(lo + k, self.c['n'] - j - 1)
                weights = [ref.eq(suffix, tail[:len(suffix)]) for suffix in suffixes]
                cur = left
                for t in range(max(degrees) + 1):
                    for g in range(3):
                        if t <= degrees[g] and not (t == 1 and recover[g]):
                            sums[g][t] += weights[g] * ref.inner(self.c, cur, g)
                    cur = {name: cur[name] + dif[name] for name in self.c['names']}
            if self.resident is None:
                del buf
        groups = []
        for g in range(3):
            if recover[g]:
                sums[g][1] = (self.group_claims[g] - factors[g][0] * sums[g][0]) / factors[g][1]
            groups.append([factors[g][t] * (sums[g][t] if t < len(sums[g])
                          else ref.lagrange(sums[g], F(t))) for t in range(degree + 1)])
        self.pending = groups
        return [sum((row[t] for row in groups), F()) for t in range(degree + 1)]

    def fold(self, r):
        if self.pending is None:
            raise ValueError('fold requires round')
        self.group_claims = [ref.lagrange(row, r) for row in self.pending]
        if self.resident is not None:
            for array in self.resident.values():
                half = len(array) // 2
                for k in range(half):
                    array[k] = array[k] + r * (array[k + half] - array[k])
                del array[half:]
                for op in ('mul', 'add', 'sub'):
                    self.counts['inplace_fold_' + op] += half
        self.prefix.append(r)
        self.j += 1
        self.pending = None

    def finals(self):
        if self.j != self.c['n'] or self.pending is not None:
            raise ValueError('unfinished finals')
        if self.resident is None:
            values = self.reconstruct([0])
            words = [values[name][0] for name in self.c['names']]
        else:
            words = [self.resident[name][0] for name in self.c['names']]
        return [ref.eq(w, self.prefix[:len(w)]) for w in self.c['points']] + words


def analytic(n, table_count, pairs):
    original = 1 << n
    switch = next(j for j in range(n) if (1 << (n-j)) <= 2*pairs)
    scans = switch + 1
    residual = 1 << (n-switch)
    return dict(n=n, data_tables=table_count, pair_capacity=pairs,
                source_round_scans=scans, switch_round=switch,
                original_reads=table_count*original*scans,
                reconstruction_mul=table_count*original*switch,
                inplace_fold_mul=table_count*(residual-1),
                baseline_build_reads=table_count*original,
                baseline_fold_mul=table_count*(original-1),
                baseline_native_table_capacity_bytes=16*(table_count+3)*original,
                candidate_native_table_buffer_bound_bytes=16*table_count*min(2*pairs, original),
                source_retention_bytes_if_copied=16*table_count*original,
                prefix_stack_bound_entries=n+1,
                exclusions='source PCS/gates, brackets/cur/dif, metadata, transcript/masks, proof, codewords and allocator overhead')


def main():
    started = time.perf_counter()
    signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    os.nice(10)
    rng = random.Random(SEED)
    cases, direct_points, round_checks, final_checks, count_checks = [], 0, 0, 0, 0
    symbolic_round_checks, symbolic_final_checks = 0, 0
    fixtures = []
    for n, padded, mode in itertools.product((2, 3, 4, 6), (False, True), ('base', 'full', 'zero')):
        c = ref.fixture(n, padded, mode, rng, limbs=1+(n%3), lookup_count=4+(n%2), tail_vars=1+(n>3))
        # Force actual equality-factor-zero paths, without resampling.
        if mode == 'zero':
            c['points'] = [[F(0), F(0)] + w[2:] if len(w)>=2 else [F(0)] for w in c['points']]
        fixtures.append(c)
    digest = hashlib.sha256()
    for c in fixtures:
        original = ref.Reference(c)
        symbolic = ref.Grouped(c)
        challenges = [F(0) if c['tabs']['e'][0] == 0 else F(rng.randrange(ref.P), rng.randrange(ref.P))
                      for _ in range(c['n'])]
        candidates = [WindowRounds(c, cap) for cap in (1, 3, 16)]
        prefix = []
        for j, r in enumerate(challenges):
            expected = original.round()
            assert symbolic.round() == expected
            symbolic_round_checks += len(expected)
            if c['n'] <= 4:
                for t, value in enumerate(expected):
                    assert value == ref.oracle(c, prefix, t), ('cube round', j, t)
                    direct_points += 1
            for candidate in candidates:
                actual = candidate.round(j)
                assert actual == expected, ('window round', c['n'], candidate.pairs, j)
                round_checks += len(expected)
                for value in actual:
                    digest.update(value.wire())
                candidate.fold(r)
            original.bind(r)
            symbolic.bind(r)
            prefix.append(r)
        expected_finals = [ref.eq(w, prefix[:len(w)]) for w in c['points']] + [ref.mle_direct(c['tabs'][name], prefix) for name in c['names']]
        assert original.finals() == expected_finals
        assert symbolic.finals() == expected_finals
        symbolic_final_checks += len(expected_finals)
        for candidate in candidates:
            assert candidate.finals() == expected_finals
            final_checks += len(expected_finals)
            account = analytic(c['n'], len(c['names']), candidate.pairs)
            for a, b in [('source_reads','original_reads'),('reconstruction_mul','reconstruction_mul'),('inplace_fold_mul','inplace_fold_mul'),('source_round_scans','source_round_scans')]:
                assert candidate.counts[a] == account[b], (a, candidate.counts[a], account[b])
                count_checks += 1
            assert max(candidate.counts['peak_pair_entries'],candidate.counts['resident_capacity_entries'])*16 <= account['candidate_native_table_buffer_bound_bytes']
            cases.append(dict(n=c['n'], ht_vars=c['ht'], padded=c['padded'], data_mode=('zero' if c['tabs']['e'][0]==0 else ('base' if c['tabs']['e'][0].b==0 else 'full')), tables=len(c['names']), pairs=candidate.pairs, counts=candidate.counts, account=account))
    controls = []
    def refuse(name, action):
        try:
            action()
        except ValueError as exc:
            controls.append(dict(name=name, detected=str(exc)))
        else:
            raise AssertionError(name)
    c = ref.fixture(3, True, 'full', rng)
    refuse('zero capacity', lambda: WindowRounds(c,0))
    bad = copy.deepcopy(c); bad['tabs']['e'].pop()
    refuse('short source', lambda: WindowRounds(bad,1))
    bad = copy.deepcopy(c); bad['points'][0].append(F(1))
    refuse('long equality point', lambda: WindowRounds(bad,1))
    w=WindowRounds(c,1)
    refuse('finals before folds',w.finals)
    refuse('fold before round',lambda:w.fold(F(2)))
    refuse('wrong round index',lambda:w.round(1))
    expected=w.round(0)
    refuse('second pending round',lambda:w.round(0))
    assert WindowRounds(c,1,reverse_index=True).round(0) != expected
    controls.append(dict(name='LSB source instead of MSB',detected='round mismatch'))
    bad=copy.deepcopy(c); bad['tabs']['e'][-1]+=F(1)
    assert WindowRounds(bad,1).round(0) != expected
    controls.append(dict(name='dirty padding is retained',detected='round mismatch, not skipped'))
    bad=copy.deepcopy(c); bad['points'][1]=bad['points'][1]+[F(0)]
    assert WindowRounds(bad,1).round(0) != expected
    controls.append(dict(name='short p_ht incorrectly includes tail',detected='round mismatch'))
    # Inconsistent host sum cannot seed per-group recovery.
    host_assertions=[F(0),F(123,456)]
    assert all(WindowRounds(c,1).round(0)==expected for _ in host_assertions)
    controls.append(dict(name='unrelated host assertions',detected='same computed first round; host assertion never consumed'))
    seeded=WindowRounds(c,1);seeded.group_claims=[F(123,456)]*3
    assert seeded.round(0)!=expected
    controls.append(dict(name='host sum seeds subgroup recovery',detected='first round mismatch'))
    w.fold(F(2,1)); before=w.round(1)
    wrong=WindowRounds(c,1);wrong.round(0);wrong.fold(F(3,1))
    assert wrong.round(1)!=before
    controls.append(dict(name='changed recorded challenge',detected='later round mismatch'))
    # A borrowed source mutation remains a caller ownership hazard, detected by oracle.
    w=WindowRounds(c,1);w.round(0);w.fold(F(2,1)); before=w.round(1)
    bad=copy.deepcopy(c); bad['tabs']['e'][0]+=F(9)
    changed=WindowRounds(bad,1);changed.round(0);changed.fold(F(2,1))
    assert changed.round(1)!=before
    controls.append(dict(name='changed source owner',detected='round mismatch; immutability not enforced here'))
    assert sum(case['counts']['fallback_zero_factor'] for case in cases)>0
    projected=[analytic(n,23,cap) for n,cap in itertools.product((8,20,22,23,25),(1,256,4096))]
    equality_only=[dict(n=n,illustrative_data_table_count=23,equality_tables=3,
                        removed_native_capacity_bytes=3*(1<<n)*16,
                        removed_fold_fp2_mul=3*((1<<n)-1),
                        removed_fold_fp2_add=3*((1<<n)-1),
                        removed_fold_fp2_sub=3*((1<<n)-1),
                        data_source_rereads_added=0,
                        capacity_fraction_of_K23_plus_3=3/26,
                        remaining_native_data_capacity_bytes=23*(1<<n)*16,
                        extra_obligations='symbolic Eq final order; no change to round, extension or opening semantics; native integration untested')
                   for n in (8,20,22,23,25)]
    cpu=next((line.split(':',1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('model name')),'unknown')
    output=dict(run_id='20261004T110146Z-56ac7478',seed=SEED,status='pass',synthetic_case_count=len(cases),fixture_count=len(fixtures),round_degree_sample_comparisons=round_checks,original_cube_degree_sample_comparisons=direct_points,final_table_value_comparisons=final_checks,analytic_count_checks=count_checks,controls=controls,control_count=len(controls),cases=cases,count_only_projection=projected,round_digest_sha256=digest.hexdigest(),elapsed_seconds=time.perf_counter()-started,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,hardware=dict(device='CPU only',cpu=cpu,python=platform.python_version(),platform=platform.platform(),affinity=list(os.sched_getaffinity(0)),nice=os.getpriority(os.PRIO_PROCESS,0),threads=1),resources=dict(wall_cap_seconds=59,cpu_cap_seconds=59,address_space_cap_mib=512,estimated_memory_mib=64),script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),reference_sha256=hashlib.sha256((HERE/'reference_support.py').read_bytes()).hexdigest(),proof_accounting=dict(context_length=None,passes=0,accepted_complete_private8b_passes=0,countable_tokens=0,device='CPU only',steady_state_tokens_per_s=None,total_workload_tokens_per_s=None,startup_fraction=None,startup_seconds=None,witness_seconds=None,proof_seconds=None,serialization_seconds=None,independent_verification_seconds=None,total_workload_seconds=None,proof_latency_seconds=None,proof_lag_seconds=None,pipeline_drain_seconds=None,prefill='none',resident_passes='none',decode='none'),limits=['Synthetic layout port, not native closure/IR/MSB source-reader execution','Native masked transcript/RNG/extension/PCS/receipt/refusals/privacy untested','Direct original-cube every degree sample for n<=4 only; all finals for all n','Candidate bracket shares port with materialized reference; independent expanded cube oracle provides separate formula','Native table capacity accounting, not measured Rust RSS/device occupancy/DRAM/time','Existing source data cannot be freed; making separate full Fp2 source copies can erase the capacity gain','No trained data, native build, GPU job or accepted proof'])
    output.update(symbolic_equality_only_round_samples=symbolic_round_checks,
                  symbolic_equality_only_final_values=symbolic_final_checks,
                  symbolic_equality_only_projection=equality_only,
                  symbolic_equality_only_status='synthetic port prerequisite passes; no native allocation/time measured')
    (HERE/'result.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({k:output[k] for k in ('status','synthetic_case_count','round_degree_sample_comparisons','original_cube_degree_sample_comparisons','final_table_value_comparisons','analytic_count_checks','control_count','elapsed_seconds','peak_rss_kib')}))


if __name__=='__main__':
    main()
