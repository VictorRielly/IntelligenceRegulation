#!/usr/bin/env python3
"""One-thread independent differential/cost gate; produces no proof."""
import copy, hashlib, itertools, json, os, platform, random, resource, signal, time
from pathlib import Path
from field_support import F, P
from baseline import TaggedRounds
from candidate import SplitRounds, analytic_counts
from fixtures import fixture
import oracle

HERE = Path(__file__).resolve().parent
SEED = 2026100431


def main():
    started = time.perf_counter()
    signal.alarm(59)
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    os.nice(10)
    rng = random.Random(SEED)
    cases = []
    round_checks = cube_checks = finals = count_checks = 0
    digest = hashlib.sha256()

    def run(tabs, groups, challenges, n, degree, label):
        nonlocal round_checks, cube_checks, finals, count_checks
        original = [oracle.table(tab, n) for tab in tabs]
        ref = TaggedRounds(tabs, n, degree, groups)
        candidates = [SplitRounds(tabs, n, degree, groups, chunk=c, strategy=strategy)
                      for strategy, c in itertools.product(('split', 'adaptive'), (1, 3, 1024))]
        prefix = []
        for j, r in enumerate(challenges):
            expected = [oracle.round_direct(original, groups, prefix, t, n) for t in range(degree+1)]
            cube_checks += len(expected)
            baseline = ref.round(j)
            assert list(map(oracle.tup, baseline)) == expected, ('baseline', label, j)
            for cand in candidates:
                got = cand.round(j)
                assert list(map(oracle.tup, got)) == expected, ('cube', label, cand.chunk, j)
                round_checks += len(got)
                for v in got: digest.update(v.wire())
                cc = cand.counts[-1]
                assert cc['rows'] == 1 << (n-j-1)
                assert cc['data_loads'] == 2*cc['rows']*len(cand.data_indices)
                totals = dict(literal_mul=0, unit_aware_mul=0, candidate_mul=0,
                              baseline_add=0, candidate_add=0, flushes=0)
                for rec, (ix, terms) in zip(cc['group_records'], groups):
                    tab = tabs[ix]
                    ac = analytic_counts(n, j, tab['start'], len(tab['point']), rec['samples'], cand.chunk, cand.strategy)
                    assert rec['flushes'] == ac['flushes']
                    assert rec['candidate_weight_mul'] == ac['candidate_mul']
                    for key in totals: totals[key] += ac[key]
                    count_checks += 2
                for measured, calculated in [('baseline_literal_weight_mul', 'literal_mul'),
                                             ('baseline_unit_aware_weight_mul', 'unit_aware_mul'),
                                             ('candidate_weight_mul', 'candidate_mul'),
                                             ('baseline_weight_add', 'baseline_add'),
                                             ('candidate_weight_add', 'candidate_add'), ('flushes', 'flushes')]:
                    assert cc[measured] == totals[calculated], (label, measured)
                    count_checks += 1
                count_checks += 2
                if cand.strategy == 'adaptive':
                    assert cc['candidate_weight_mul'] <= cc['baseline_unit_aware_weight_mul']
                    count_checks += 1
                cand.fold(r)
            ref.fold(r)
            prefix.append(oracle.tup(r))
        expected_final = [oracle.mle(a, prefix) for a in original]
        assert list(map(oracle.tup, ref.finals())) == expected_final
        for cand in candidates:
            assert list(map(oracle.tup, cand.finals())) == expected_final
            assert cand.data_fold_ops == len(cand.data_indices)*((1 << n)-1)
            assert cand.eq_scalar_ops == sum(len(t['point']) for t in tabs if t['kind'] == 'Eq')
            finals += len(expected_final)
            count_checks += 2
            cases.append(dict(label=label, n=n, degree=degree, chunk=cand.chunk, strategy=cand.strategy,
                              recoveries=cand.recoveries, zero_fallbacks=cand.zero_fallbacks,
                              data_fold_ops=cand.data_fold_ops, rounds=cand.counts))

    mixed = 0
    for n, mode, variant in itertools.product((0, 1, 2, 3, 5), ('base', 'full', 'zero', 'boolean'), (0, 1)):
        tabs, groups, challenges = fixture(n, mode, variant, rng)
        run(tabs, groups, challenges, n, 5, f'mixed-n{n}-{mode}-shuffle{variant}')
        mixed += 1
    span_cases = 0
    for n in (0, 1, 2, 3, 5):
        for s in range(n+1):
            for length in range(n-s+1):
                draw = lambda: F(rng.randrange(P), rng.randrange(P))
                tabs = [dict(kind='Pub', words=[draw() for _ in range(1 << n)]),
                        dict(kind='Eq', start=s, point=[draw() for _ in range(length)]),
                        dict(kind='Pub', words=[draw() for _ in range(1 << n)])]
                groups = [(1, [(F(3, 7), (0, 2)), (F(5), (2,))])]
                run(tabs, groups, [draw() for _ in range(n)], n, 3, f'span-n{n}-s{s}-l{length}')
                span_cases += 1

    controls = []
    tabs, groups, challenges = fixture(5, 'full', 1, rng)
    original = [oracle.table(t, 5) for t in tabs]
    expected = [oracle.round_direct(original, groups, [], t, 5) for t in range(6)]
    for mutation in ('wrong_outer', 'omit_chunk_flush', 'omit_trailing'):
        # Use a short span with actual trailing broadcasts to exercise its map.
        tt = copy.deepcopy(tabs)
        if mutation == 'omit_trailing':
            ei = next(i for i, t in enumerate(tt) if t['kind'] == 'Eq' and t['point'])
            tt[ei] = dict(kind='Eq', start=0, point=tt[ei]['point'][:3])
            original2 = [oracle.table(t, 5) for t in tt]
            expected2 = [oracle.round_direct(original2, groups, [], t, 5) for t in range(6)]
        else: expected2 = expected
        got = SplitRounds(tt, 5, 5, groups, chunk=3, mutation=mutation).round(0)
        assert list(map(oracle.tup, got)) != expected2, mutation
        controls.append(dict(name=mutation, detected='independent original-cube mismatch'))

    def rejects(name, fn):
        try: fn()
        except (ValueError, AssertionError, IndexError) as e:
            controls.append(dict(name=name, detected=str(e))); return
        raise AssertionError(('missing rejection', name))
    rejects('nonpositive chunk', lambda: SplitRounds(tabs, 5, 5, groups, chunk=0))
    rejects('unknown strategy', lambda: SplitRounds(tabs, 5, 5, groups, strategy='invented'))
    rejects('unfinished finals', lambda: SplitRounds(tabs, 5, 5, groups).finals())
    rejects('fold without round', lambda: SplitRounds(tabs, 5, 5, groups).fold(F(2)))
    rejects('wrong round order', lambda: SplitRounds(tabs, 5, 5, groups).round(1))
    ei = next(i for i, t in enumerate(tabs) if t['kind'] == 'Eq')
    malformed = copy.deepcopy(tabs); malformed[ei]['start'] = 6
    rejects('Eq span overflow', lambda: SplitRounds(malformed, 5, 5, groups))
    badgroups = copy.deepcopy(groups); badgroups[0][1].append((F(1), (ei,)))
    rejects('Eq used inside data bracket', lambda: SplitRounds(tabs, 5, 5, badgroups))
    bad = SplitRounds(tabs, 5, 5, groups); bad.claims = [F(999)]*len(groups)
    assert list(map(oracle.tup, bad.round(0))) != expected
    controls.append(dict(name='invented first subgroup claims', detected='independent cube mismatch'))
    # Tiny chunks can lose field multiplications even with exact arithmetic.
    adverse = analytic_counts(8, 0, 0, 8, 5, 1)
    assert adverse['candidate_mul'] > adverse['literal_mul']
    controls.append(dict(name='chunk1 cost regression', detected=adverse))

    projections = []
    for n, short in ((20, 12), (23, 14), (25, 15)):
        for recovery, strategy in itertools.product((False, True), ('split', 'adaptive')):
            totals = dict(literal_mul=0, unit_aware_mul=0, candidate_mul=0,
                          baseline_add=0, candidate_add=0, flushes=0)
            for j in range(n):
                half = 1 << (n-j-1)
                chunk = half if half*26 <= 1 << 16 else min(half, 1024)
                for length, degree in ((n, 4), (short, 2), (n, 2)):
                    # Nonzero recovery mode only; no mask/challenge resampling.
                    samples = degree+1-int(recovery and j > 0)
                    c = analytic_counts(n, j, 0, length, samples, chunk, strategy)
                    for k in totals: totals[k] += c[k]
            projections.append(dict(n=n, illustrative_short_eq_length=short, recovery=recovery, strategy=strategy,
                                    counts=totals, removed_vs_literal=totals['literal_mul']-totals['candidate_mul'],
                                    removed_vs_unit_aware=totals['unit_aware_mul']-totals['candidate_mul'],
                                    added_additions=totals['candidate_add']-totals['baseline_add'],
                                    extra_accumulator_bytes_per_part=(5+3+3)*16,
                                    native_k_for_chunk_threshold=26,
                                    scope='count only, equality weighting; all data/bracket/fold/setup/masks/PCS/transfers excluded'))

    result = dict(run_id='20261004T130146Z-19e7c75c', cycle='0031', seed=SEED, status='pass',
                  mixed_fixtures=mixed, exhaustive_span_fixtures=span_cases, candidate_schedules=len(cases),
                  independent_original_cube_samples=cube_checks, differential_candidate_samples=round_checks,
                  candidate_direct_MLE_final_values=finals, exact_counter_checks=count_checks,
                  controls=controls, control_count=len(controls), cases=cases, projections=projections,
                  round_digest_sha256=digest.hexdigest(), elapsed_seconds=time.perf_counter()-started,
                  peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                  hardware=dict(cpu=next((x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines()
                                          if x.startswith('model name')), 'unknown'), device='CPU only', threads=1,
                                affinity=sorted(os.sched_getaffinity(0)), nice=os.getpriority(os.PRIO_PROCESS,0),
                                python=platform.python_version(), platform=platform.platform()),
                  resources=dict(wall_cap_seconds=59, cpu_cap_seconds=59, address_space_cap_mib=512,
                                 estimated_memory_mib=64),
                  hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.py')},
                  proof_accounting=dict(accepted_complete_private8b_proofs=0, countable_tokens=0,
                                        context_length=None, passes=0, device='CPU only',
                                        steady_state_tokens_per_s=None, total_workload_tokens_per_s=None,
                                        startup_fraction=None, startup_seconds=None, witness_seconds=None,
                                        proof_seconds=None, serialization_seconds=None, independent_verification_seconds=None,
                                        proof_latency_seconds=None, proof_lag_seconds=None, pipeline_drain_seconds=None,
                                        prefill='none', resident_passes='none', decode='none'),
                  limits=['Synthetic generic grouped polynomial gate, no native SC_SZC closure/IR execution',
                          'Exact tuple-field expanded-cube oracle independently computes every expected sample/final',
                          'Baseline is prior tagged-Eq prototype; native still materializes/folds Eq tables',
                          'No native CFS/RNG/mask/extension/PCS/receipt/refusal/privacy or parallel scheduler test',
                          'Operation counts are not native CPU/GPU timing, peak memory, bandwidth or complete proof rates',
                          'Chunk1 regression retained; common data scan/bracket/fold work unchanged',
                          'No foreign code run, real private values, GPU, build or installed dependencies'])
    (HERE/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('cases', 'controls')}, indent=2))


if __name__ == '__main__': main()
