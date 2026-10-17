"""Timing-only audit. No tensors, receipts or native binaries are executed/read.

Decimal accounting is checked against a separately authored integer-ms oracle.
Synthetic nested spans test the proposed Rust clock contract, not a prover.
"""
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import random
import resource
import signal
import time
from decimal import Decimal as D

HERE = Path(__file__).resolve().parent
SEED = 2026101759


class Refusal(ValueError):
    pass


def require(ok, reason):
    if not ok:
        raise Refusal(reason)


def seconds(x):
    require(not isinstance(x, bool), 'boolean duration')
    try:
        v = D(str(x))
    except Exception as e:
        raise Refusal('invalid duration') from e
    require(v.is_finite() and v >= 0, 'negative/nonfinite duration')
    return v


def one(events, name):
    found = [x for x in events if x.get('event') == name]
    require(len(found) == 1, 'missing/duplicate ' + name)
    return found[0]


def audit_row(row):
    loaded = one(row['prove_events'], 'loaded')
    parity = one(row['prove_events'], 'parity')
    proved = one(row['prove_events'], 'proved')
    verified = one(row['verify_events'], 'verified')
    require(parity['result'] == 'bit-exact', 'parity failed')
    require(row['blocks_in_receipt'] == 1 and row['context'] == 32, 'scope differs')
    require(row['linked_model_stack'] is False, 'unlinked receipts relabelled')
    for kind in ['prove', 'verify']:
        g = row[kind + '_guard']
        require(row[kind + '_done'] == '0', 'nonzero done marker')
        require(g['exit'] == 0 and g['child_rc'] == 0 and g['guard_killed'] is None, 'guard did not succeed')
    for field in ['segment_bytes', 'segment_sha256', 'statement_identity']:
        require(proved[field] == verified[field], 'fresh verifier mismatch ' + field)
    load = seconds(loaded['seconds'])
    witness = seconds(parity['seconds'])
    prove = seconds(proved['prove_seconds'])
    verify = seconds(proved['in_process_verify_seconds'])
    total = seconds(proved['total_seconds'])
    # Five independently rounded millisecond-valued fields: ±2.5 ms residual.
    residual = total - load - witness - prove - verify
    require(residual >= D('-0.0025'), 'children exceed enclosing total')
    return dict(load=load, witness_parity=witness, prove_inclusive=prove,
                verify_in_process=verify, total=total, unclassified=residual,
                fresh_load=seconds(verified['load_seconds']),
                fresh_verify=seconds(verified['verify_seconds']))


def independent_ms(row):
    # Intentionally no use of seconds(), one(), audit_row() or Decimal sums.
    events = {v['event']: v for v in row['prove_events']}
    fresh = row['verify_events'][0]
    def ms(value):
        whole, _, frac = str(value).partition('.')
        assert len(frac) <= 3
        return int(whole) * 1000 + int(frac.ljust(3, '0'))
    vals = [ms(events['loaded']['seconds']), ms(events['parity']['seconds']),
            ms(events['proved']['prove_seconds']),
            ms(events['proved']['in_process_verify_seconds']),
            ms(events['proved']['total_seconds']),
            ms(fresh['load_seconds']), ms(fresh['verify_seconds'])]
    return vals + [vals[4] - vals[0] - vals[1] - vals[2] - vals[3]]


def exclusive_spans(spans):
    """Validate synchronous nested phase spans and return exclusive ns per span.

    Native parent spans include their children. Siblings must not overlap.
    Cross-device asynchronous phases need separately synchronized enclosing
    wall clocks; these spans do not pretend their durations can be added.
    """
    by_id = {s['id']: s for s in spans}
    require(len(by_id) == len(spans), 'duplicate span')
    roots = [s for s in spans if s['parent'] is None]
    require(len(roots) == 1, 'root count')
    children = {s['id']: [] for s in spans}
    for s in spans:
        require(type(s['start']) is int and type(s['end']) is int, 'noninteger ns')
        require(0 <= s['start'] <= s['end'], 'span time')
        if s['parent'] is not None:
            require(s['parent'] in by_id, 'unknown parent')
            p = by_id[s['parent']]
            require(p['start'] <= s['start'] <= s['end'] <= p['end'], 'child containment')
            children[p['id']].append(s)
    out = {}
    visited = set()
    def visit(s):
        require(s['id'] not in visited, 'cycle')
        visited.add(s['id'])
        c = sorted(children[s['id']], key=lambda x: x['start'])
        for a, b in zip(c, c[1:]):
            require(a['end'] <= b['start'], 'sibling overlap')
        out[s['id']] = s['end'] - s['start'] - sum(v['end'] - v['start'] for v in c)
        for v in c:
            visit(v)
    visit(roots[0])
    require(len(visited) == len(spans), 'unreachable span')
    require(sum(out.values()) == roots[0]['end'] - roots[0]['start'], 'closure')
    return out


def independent_sweep(spans):
    # Independent reference: split time at every endpoint, assign each open
    # interval to the unique deepest span. No subtraction of child totals.
    cuts = sorted({s[k] for s in spans for k in ['start', 'end']})
    out = {s['id']: 0 for s in spans}
    by_id = {s['id']: s for s in spans}
    def depth(s):
        n = 0
        while s['parent'] is not None:
            n += 1
            s = by_id[s['parent']]
        return n
    for a, b in zip(cuts, cuts[1:]):
        active = [s for s in spans if s['start'] <= a and b <= s['end']]
        if active:
            winner = max(active, key=depth)
            out[winner['id']] += b - a
    return out


def synthetic_trace(rng, blocks):
    spans = []
    cursor = 0
    def leaf(name, parent):
        nonlocal cursor
        start = cursor
        cursor += rng.randrange(1, 1000000)
        spans.append(dict(id=name, parent=parent, start=start, end=cursor))
    leaf('load', 'total')
    leaf('seal_witness_and_parity', 'total')
    leaf('endpoint_prepare', 'total')
    pstart = cursor
    leaf('rng_ntt_header', 'prove_run')
    for k in range(blocks):
        start = cursor
        for kind in ['witness_rebuild', 'boundary_prepare', 'core_open', 'encode', 'durable_sink']:
            leaf(f'{k}/{kind}', f'stage/{k}')
        spans.append(dict(id=f'stage/{k}', parent='prove_run', start=start, end=cursor))
    spans.append(dict(id='prove_run', parent='total', start=pstart, end=cursor))
    leaf('in_process_verify_read_decode_crypto', 'total')
    leaf('metadata_write', 'total')
    spans.append(dict(id='total', parent=None, start=0, end=cursor))
    return spans


def resident_floor(startup, recurring, positions, passes):
    """Synthetic complete-workload budget, never fitted to unlinked blocks."""
    require(startup >= 0 and recurring > 0 and positions > 0 and passes > 0, 'workload dimensions')
    elapsed = startup + passes * recurring
    return D(passes * positions) / elapsed, startup / elapsed


def main():
    begin = time.monotonic()
    rng = random.Random(SEED)
    rows = json.loads((HERE / 'retained-timing-only.json').read_text())
    require(len(rows) == 22 and sorted(x['layer'] for x in rows) == list(range(22)), 'layer coverage')
    totals = {}
    controls = []
    checks = 0
    for row in rows:
        vals = audit_row(row)
        ref = independent_ms(row)
        keys = ['load', 'witness_parity', 'prove_inclusive', 'verify_in_process', 'total', 'fresh_load', 'fresh_verify', 'unclassified']
        for k, v in zip(keys, ref):
            require(vals[k] * 1000 == v, 'independent-ms mismatch')
            totals[k] = totals.get(k, D(0)) + vals[k]
            checks += 1
    def reject(name, fn):
        try:
            fn()
        except (Refusal, AssertionError, KeyError):
            controls.append(name)
        else:
            raise AssertionError('mutation escaped: ' + name)
    for name, mutate in [
        ('missing fresh verification', lambda x: x.update(verify_events=[])),
        ('duplicate loaded clock', lambda x: x['prove_events'].append(x['prove_events'][0])),
        ('wrong proof bytes', lambda x: x['verify_events'][0].update(segment_bytes=1)),
        ('wrong statement identity', lambda x: x['verify_events'][0].update(statement_identity='bad')),
        ('wrong proof hash', lambda x: x['verify_events'][0].update(segment_sha256='bad')),
        ('nonzero completion', lambda x: x.update(verify_done='1')),
        ('guard kill', lambda x: x['prove_guard'].update(guard_killed='limit')),
        ('unlinked receipts relabelled as stack', lambda x: x.update(linked_model_stack=True)),
        ('proof clock exceeds enclosing', lambda x: x['prove_events'][2].update(prove_seconds=10000)),
        ('nan clock', lambda x: x['prove_events'][2].update(prove_seconds='NaN')),
        ('negative clock', lambda x: x['prove_events'][2].update(prove_seconds=-1)),
    ]:
        bad = copy.deepcopy(rows[0]); mutate(bad)
        reject(name, lambda: audit_row(bad))
    span_count = 0
    for blocks in [1, 2, 3, 22, 32]:
        for _ in range(40):
            spans = synthetic_trace(rng, blocks)
            a, b = exclusive_spans(spans), independent_sweep(spans)
            require(a == b, 'independent span sweep mismatch')
            span_count += len(spans)
            checks += len(spans)
            # Includes both witness passes and never counts encode/sink twice.
            require(sum(a.values()) == spans[-1]['end'], 'end-to-end closure')
    spans = synthetic_trace(rng, 3)
    bad = copy.deepcopy(spans); bad[1]['end'] = bad[-1]['end'] + 1
    reject('out-of-parent span', lambda: exclusive_spans(bad))
    bad = copy.deepcopy(spans); bad[1]['start'] = bad[0]['start']
    reject('overlapping siblings', lambda: exclusive_spans(bad))
    bad = copy.deepcopy(spans); bad[1]['parent'] = 'missing'
    reject('missing parent', lambda: exclusive_spans(bad))
    bad = copy.deepcopy(spans); bad.append(bad[0])
    reject('duplicate span id', lambda: exclusive_spans(bad))
    # Strong amortization falsifier: even arbitrarily many synthetic passes
    # cannot beat the recurring floor. No fit to this model's unlinked logs.
    slopes = []
    for recurring in [D('0.5'), D('0.64'), D('0.8'), D('2')]:
        rates = []
        for passes in [1, 2, 8, 64, 4096, 1048576]:
            rate, fraction = resident_floor(D(7), recurring, 32, passes)
            require(rate < D(32) / recurring and 0 < fraction < 1, 'slope floor')
            if recurring >= D('0.64'):
                require(rate < 50, 'startup amortization escaped recurring floor')
            rates.append(str(rate)); checks += 1
        slopes.append(dict(recurring_s=str(recurring), rates=rates))
    src = (HERE / 'source/current-run.rs').read_text()
    body = src.split('for k in 0..l {', 1)[1].split('Ok(stats)', 1)[0]
    markers = ['let t0 = Instant::now();', 'src.boundary_plane(k)?', 'let wit = src.witness(k)?;', 'protocol::prove_core', 'wire::encode_segment', 'sink(k, bytes)?;', 'stats.prove_s.push(t0.elapsed()']
    offsets = [body.index(x) for x in markers]
    require(offsets == sorted(offsets), 'native stage clock placement changed')
    old = (HERE / 'source/trained_block-t5.rs').read_text()
    old_body = old.split('fn prove_inner(', 1)[1].split('fn inconsistent_witness_controls', 1)[0]
    markers_old = ['let t1 = Instant::now();', 'let (x_in, x_out) = ex.load_seq', 'let w = parity(', 'prepare_endpoints(', 'let t2 = Instant::now();', 'w: Some(w)', 'run::prove_run', 'let prove_s =', 'run::verify_run', 'write_new(&out.join("segment-000.bin")', 't_total.elapsed()', 'if flag(f, "--controls")']
    offsets = [old_body.index(x) for x in markers_old]
    require(offsets == sorted(offsets), 'archived CLI clock order')
    checks += len(markers) + len(markers_old)
    source = (HERE / 'source/current-trained_block.rs').read_text()
    require('self.busy_s = 0.0;' in source and 'let witness_s = src.busy_s;' in source, 'stack witness subset counter missing')
    total = totals['total']
    summary = dict(
        status='pass', run_id='20261017T092624Z-0a2ee588', cycle='0059', seed=SEED,
        counts=dict(retained_independent_block_diagnostics=22, fresh_verifier_log_pairs=22,
                    accounting_reference_checks=checks, synthetic_traces=200, synthetic_spans=span_count,
                    negative_controls=len(controls)),
        controls=controls, diagnostic_seconds={k:str(v) for k,v in totals.items()},
        diagnostic_fraction={k:str(v/total) for k,v in totals.items() if k not in ['total','fresh_load','fresh_verify']},
        diagnostic_ideal_delete_all_prove_ceiling=str(total/(total-totals['prove_inclusive'])),
        diagnostic_ideal_delete_load_ceiling=str(total/(total-totals['load'])),
        diagnostic_prove_only_understates_total_by=str(total/totals['prove_inclusive']),
        diagnostic_receipt_bytes=sum(x['prove_events'][2]['segment_bytes'] for x in rows),
        residual_aggregate_rounding_radius_s='0.055', residual_split='unknown: endpoints, statements, file writes and other gaps',
        startup_seconds=None, startup_fraction=None, target_total_workload_rate=None, target_steady_rate=None,
        accepted_complete_8b_proofs=0, accepted_complete_8b_passes=0, accepted_complete_8b_positions=0,
        target_context=None, witness_seconds_8b=None, proof_seconds_8b=None, serialization_seconds_8b=None, verification_seconds_8b=None,
        synthetic_slopes=slopes, experiment_wall_seconds=time.monotonic()-begin,
        peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        cpu_affinity=sorted(os.sched_getaffinity(0)), experiment_threads=1,
        limits='59s wall/CPU;512MiB AS;64MiB estimated;nice19;no GPU/dependencies/native proof',
        scope='Read-only audit of existing public timing/size metadata. No fresh verification or native performance reproduction; no linked stack claim. Current stack source differs from t5 sources.',
    )
    (HERE / 'result.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps({k:summary[k] for k in ['status','counts','diagnostic_seconds','diagnostic_ideal_delete_all_prove_ceiling','experiment_wall_seconds','peak_rss_kib']}))


if __name__ == '__main__':
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    main()
