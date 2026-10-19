#!/usr/bin/env python3
"""Independent complete-lifetime audit. No candidate arithmetic imported; intervals and semantic source census."""
import collections
import hashlib
import json
import os
import resource
import signal
import time
from pathlib import Path

H = Path(__file__).resolve().parent


def measure(ns, output, keep_sources=False):
    uses = collections.defaultdict(list)
    for n in ns:
        for d in n['deps']:
            assert 0 <= d < n['id']
            uses[d].append(n['id'])
    uses[output].append(len(ns))
    ends = {n['id']: max(uses[n['id']], default=n['id']) for n in ns}
    if keep_sources:
        ends.update({n['id']: len(ns) for n in ns if n['external']})
    # Independent interval sweep and explicit live-set reconstruction agree.
    delta = collections.Counter()
    for n in ns:
        b, e = n['id'], ends[n['id']]
        delta[b] += n['words']
        delta[e + 1] -= n['words']
        z = n.get('construction_transient_fp2_words', 0)
        delta[b] += z
        delta[b + 1] -= z
    live = peak = 0
    for at in sorted(delta):
        live += delta[at]
        peak = max(peak, live)
    assert live == 0
    direct = max(sum(n['words'] for n in ns if n['id'] <= at <= ends[n['id']]) +
                 ns[at].get('construction_transient_fp2_words', 0)
                 for at in range(len(ns)))
    assert direct == peak
    # The five-word round accumulator remains live outside each row.
    return peak + 5


def signature(ns):
    hashes = []
    for n in ns:
        k = (n['label'], n['words'], n['external'], n.get('source_index'),
             tuple(hashes[d] for d in n['deps']))
        hashes.append(hashlib.sha256(repr(k).encode()).hexdigest())
    return collections.Counter(hashes), hashes[-1]


def main():
    tick = time.perf_counter()
    os.nice(19)
    cpu = min(os.sched_getaffinity(0)); os.sched_setaffinity(0, {cpu})
    resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2,) * 2)
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59)); signal.alarm(59)
    r = json.loads((H / 'result.json').read_text())
    ts = json.loads((H / 'traces.json').read_text())
    checks = 0; rows = []
    for pin in json.loads((H / 'source-pins.json').read_text()):
        want = pin['cycle77_sha256']
        assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest() == want
        if 'snapshot' in pin:
            assert hashlib.sha256((H / pin['snapshot']).read_bytes()).hexdigest() == want
        checks += 1
    for c, t in zip(r['census'], ts):
        nt = c['tables']
        assert signature(t['eager']) == signature(t['lazy']); checks += 1
        for schedule in ['eager', 'lazy']:
            ns = t[schedule]; io = t[schedule + '_io']
            sources = [n for n in ns if n['external']]
            assert [n['id'] for n in ns] == list(range(len(ns))); checks += 1
            assert len(sources) == nt; checks += 1
            assert sorted(n['source_index'] for n in sources) == list(range(nt)); checks += 1
            assert all(n['words'] == 2 and n['construction_transient_fp2_words'] == 1
                       and not n['deps'] for n in sources); checks += 1
            assert io['reads'] == 2 * nt and io['differences'] == nt; checks += 1
            assert io['order'] == [n['source_index'] for n in sources]; checks += 1
            assert sum(n['label'] == 'denominator' for n in ns) == c['lookups']; checks += 1
        eager = measure(t['eager'], t['eager_io']['output'])
        lazy = measure(t['lazy'], t['lazy_io']['output'])
        driven = measure(t['driven'], t['driven_io']['output'])
        retained = measure(t['lazy'], t['lazy_io']['output'], keep_sources=True)
        assert driven < lazy < eager; checks += 1
        dn=t['driven']; dio=t['driven_io']
        sources=[n for n in dn if n['external']]
        assert sorted(n['source_index'] for n in sources)==list(range(nt)); checks+=1
        assert all(n['words']==2 and n['construction_transient_fp2_words']==1 for n in sources); checks+=1
        assert dio['reads']==2*nt and dio['differences']==nt; checks+=1
        assert dio['order']==[n['source_index'] for n in sources]; checks+=1
        terms={j:weight for j,weight in t['affine_terms']}
        contributions=[n for n in dn if n['label']=='affine_contribution']
        assert collections.Counter(n['source_index'] for n in contributions)==collections.Counter({j:1 for j in terms}); checks+=1
        assert dio['affine_order']==[n['source_index'] for n in contributions]; checks+=1
        assert len(contributions)==c['combined_affine_terms']==c['use_driven_affine_count']; checks+=1
        for n in contributions:
            assert n['weight']==terms[n['source_index']]
            assert len(n['deps'])==1
            src=dn[n['deps'][0]]
            assert src['external'] and src['source_index']==n['source_index']
            assert n['words']==src['words']==2
        checks+=len(contributions)
        assert sum(n['label']=='denominator' for n in dn)==c['lookups']; checks+=1
        # Exact operation census includes every first-use endpoint subtraction.
        a,s,m,b=c['row_operations']
        assert c['use_driven_operations']==[a,s+nt,m,b]; checks+=1
        assert measure(dn,dio['output'],keep_sources=True)>lazy; checks+=1
        assert t['driven_no_memo_io']['reads']>=dio['reads'];checks+=1
        assert t['driven_no_memo_io']['differences']>=dio['differences'];checks+=1

        assert t['no_memo_io']['reads'] > 2*nt; checks += 1
        assert t['no_memo_io']['differences'] > nt; checks += 1
        assert t['no_memo_operations'][1] > c['row_operations'][1] + nt; checks += 1
        # Negative control: keeping sources until end defeats last-use savings.
        assert retained >= eager; checks += 1
        primary = c['descriptor'] in ['TinyLlama1.1B', 'Llama3-8B'] and not c['padded']
        if primary:
            assert (nt, c['lookups'], c['helpers']) == (59, 34, 17); checks += 1
            assert (eager, lazy, driven) == (129, 77, 27); checks += 1
        # Full original-table folds remain a separate, challenge-dependent pass.
        # Each pair: 2 reads, 1 write, add/sub/mul once. Reduction/conversion extra.
        a, s, m, b = c['row_operations']
        rows.append(dict(descriptor=c['descriptor'], padded=c['padded'],
            tables=nt, lookups=c['lookups'], helpers=c['helpers'],
            eager_total_logical_words=eager, lazy_total_logical_words=lazy,
            driven_total_logical_words=driven,
            driven_reduction_from_lazy=1-driven/lazy,
            driven_logical_bytes_saved_from_lazy=16*(lazy-driven),
            driven_with_sources_retained_until_end_words=measure(dn,dio['output'],keep_sources=True),
            driven_no_memoization_endpoint_reads=t['driven_no_memo_io']['reads'],
            driven_no_memoization_endpoint_differences=t['driven_no_memo_io']['differences'],
            reduction=1-lazy/eager, logical_bytes_saved=16*(eager-lazy),
            lazy_with_sources_retained_until_end_words=retained,
            endpoint_reads_per_row=2*nt, endpoint_subtractions_per_row=nt,
            no_memoization_endpoint_reads_per_row=t['no_memo_io']['reads'],
            no_memoization_endpoint_subtractions_per_row=t['no_memo_io']['differences'],
            original_fold_reads_per_row=2*nt, original_fold_writes_per_row=nt,
            original_fold_operations_add_sub_mul=[nt, nt, nt],
            row_plus_endpoints_plus_original_fold_operations_add_sub_mul_base=[a+nt,s+2*nt,m+nt,b],
            row_round_reduction_and_sample_conversion_excluded_from_that_census=True,
            full_original_tables_added=0, full_original_tables_removed=0,
            current_unpadded_catalog=primary, physical_register_or_memory_claim=False))
    for k in ['lazy_coefficients', 'charged_endpoint_censuses', 'lazy_value_independent_traces']:
        assert r['checks'][k] > 0; checks += 1
    assert r['checks']['fixtures'] == 30 and r['checks']['round_messages'] == 90; checks += 1
    assert len(r['controls']) == 12 and all(r['controls'].values()); checks += 1
    assert r['checks']['use_driven_coefficients']==1950 and r['checks']['use_driven_value_independent_traces']==390;checks+=1
    assert r['checks']['affine_only_fallbacks']==30;checks+=1
    source = (H / 'native/zkp-core__src__sumcheck__rounds.rs').read_text()
    for marker in ['tr.absorb_fp2(b"sc-round", &sums)', 'let r = tr.challenge_fp2()',
                   'ev.fold(r)', 'self.tables.iter().map(|t| t[0]).collect()',
                   'sums[1] = claim.sub(sums[0])', 'b.sub(*a)']:
        assert marker in source; checks += 1
    out = dict(status='PASS', checks=checks, accounting=rows,
        controls=dict(retain_original_sources_loses_peak_gain=True,
                      no_memoization_increases_reads=r['controls']['no_memoization_adds_reads']),
        limits='59sCPU/wall,512MiBAS,one nice19 thread',
        scope='Logical scheduling model only. Python keeps graph/oracle values; no Python RSS reduction claim. Native byte/RNG/refusal/privacy/timing gates owed.',
        wall_seconds=time.perf_counter()-tick,
        rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        threads=1, cpu_affinity=[cpu])
    (H / 'audit-result.json').write_text(json.dumps(out, indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k!='accounting'}, indent=2))
    print(json.dumps(rows[2], indent=2))


if __name__ == '__main__':
    main()
