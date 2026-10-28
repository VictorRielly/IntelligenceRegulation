#!/usr/bin/env python3
"""Exact public-address census. Synthetic field values only; no prover run.

Independent reference is the original SSA DAG; candidates interpret the shared
shape and scratch maps. No imports or execution of prior research code.
"""
import collections
import copy
import hashlib
import json
import os
import platform
import random
import resource
import signal
import time
from pathlib import Path

H = Path(__file__).resolve().parent
P = 2**64 - 2**32 + 1
SEED = 2026101983
KINDS = ('load_raw', 'load_param', 'load_base')
LIMITS = dict(load_raw=118, load_param=129, load_base=36)


def primitive(kind, a, b):
    if kind == 'add':
        return ((a[0]+b[0]) % P, (a[1]+b[1]) % P)
    if kind == 'sub':
        return ((a[0]-b[0]) % P, (a[1]-b[1]) % P)
    if kind == 'mul':
        return ((a[0]*b[0]+7*a[1]*b[1]) % P,
                (a[0]*b[1]+a[1]*b[0]) % P)
    assert kind == 'base'
    return ((a[0]*b) % P, (a[1]*b) % P)


def direct(q, arrays):
    """No templates, offsets, scratch or candidate address data."""
    values = []
    for op in q['ops']:
        k = op['kind']
        if k in KINDS:
            v = arrays[k][op['slot']]
        else:
            v = primitive(k, *(values[d] for d in op['deps']))
        values.append(v)
    return [values[d] for d in q['output']]


def source_slots(q, g):
    out = {k: [] for k in KINDS}
    for op in q['ops'][g['start']:g['end']]:
        if op['kind'] in out:
            out[op['kind']].append(op['slot'])
    return out


def census(q, plan):
    families = []
    for ci, cls in enumerate(plan['templates']):
        if len(cls['instances']) == 1:
            continue
        vectors = [source_slots(q, plan['groups'][i]) for i in cls['instances']]
        family = dict(template=ci, instances=cls['instances'], sources={})
        for kind in KINDS:
            reference = vectors[0][kind]
            differences = [[s-r for s, r in zip(v[kind], reference)] for v in vectors]
            assert all(len(v[kind]) == len(reference) for v in vectors)
            # Columns with equal difference vectors may share one pointer.
            # This does NOT claim a compiler lowering or general affine map.
            classes = collections.defaultdict(list)
            for col in range(len(reference)):
                classes[tuple(row[col] for row in differences)].append(col)
            family['sources'][kind] = dict(
                reference_slots=reference, slots=[v[kind] for v in vectors],
                differences=differences,
                uniform=[len(set(row)) <= 1 for row in differences],
                minimal_translation_groups=[dict(columns=cols, offsets=list(ds))
                                            for ds, cols in classes.items()])
        families.append(family)
    return families


def translated_plan(q, plan, kinds):
    out = copy.deepcopy(plan)
    for g in out['groups']:
        cls = out['templates'][g['template']]
        g['address_mode'] = 'mapped'
        if len(cls['instances']) == 1:
            continue
        ref = source_slots(q, out['groups'][cls['instances'][0]])
        actual = source_slots(q, g)
        g['address_mode'] = 'partial_translation'
        g['translated'] = {}
        for kind in kinds:
            rs, ss = ref[kind], actual[kind]
            delta = ss[0]-rs[0]
            # Deliberately do not assert uniformity here: the naive candidate
            # is independently falsified by the lineage oracle and values.
            g['translated'][kind] = [r+delta for r in rs]
    return out


def replay(q, plan, arrays=None):
    """Candidate evaluator plus independent symbolic address/alias lineage."""
    memory = {}
    checks = 0
    slots = {int(k): v for k, v in plan['slots'].items()}
    for g in plan['groups']:
        cls = plan['templates'][g['template']]
        shape = cls['shape']
        addresses = iter(g['map'])
        local = []
        loads = collections.Counter()
        for d in g['inputs']:
            addr = next(addresses)
            assert 0 <= addr < plan['capacity'] and addr in memory
            value = memory[addr]
            if arrays is None:
                assert value == d, ('input_lineage', g['index'], d, addr)
            local.append(value)
            checks += 1
        for j, op in enumerate(shape['ops']):
            original = q['ops'][g['start']+j]
            k = op['kind']
            assert k == original['kind']
            if arrays is None:
                assert [local[d] for d in op['deps']] == original['deps']
            if k in KINDS:
                addr = next(addresses)
                if k in g.get('translated', {}):
                    addr = g['translated'][k][loads[k]]
                loads[k] += 1
                assert 0 <= addr < LIMITS[k], ('out_of_bounds', k, addr)
                if arrays is None:
                    assert addr == original['slot'], ('source_lineage', g['index'], j, k, addr, original['slot'])
                    value = original['id']
                else:
                    value = arrays[k][addr]
            elif arrays is None:
                value = original['id']
            else:
                value = primitive(k, *(local[d] for d in op['deps']))
            local.append(value)
            checks += 1
        for d in shape['outputs']:
            addr = next(addresses)
            assert 0 <= addr < plan['capacity']
            memory[addr] = local[d]
            checks += 1
        assert next(addresses, None) is None
        if arrays is None:
            boundary = g['end']
            future = {d for op in q['ops'][boundary:] for d in op['deps'] if d < boundary}
            future |= {d for d in q['output'] if d < boundary}
            assert all(memory.get(slots[d]) == d for d in future)
            assert len({slots[d] for d in future}) == len(future)
            checks += 1
    final = [memory[slots[d]] for d in q['output']]
    if arrays is None:
        assert final == q['output']
    return checks, final


def fixture(rng, mode):
    def value():
        if mode == 'zero':
            return (0, 0)
        if mode == 'boundary':
            return tuple(rng.choice((0, 1, P-2, P-1)) for _ in range(2))
        return (rng.randrange(P), rng.randrange(P))
    return {k: [value()[0] if k == 'load_base' else value()
                for _ in range(n)] for k, n in LIMITS.items()}


def main():
    t = time.perf_counter()
    os.nice(19)
    cpu = min(os.sched_getaffinity(0))
    os.sched_setaffinity(0, {cpu})
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2,)*2)
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    captured = json.loads((H/'scalar-dags.json').read_text())
    assert captured['baseline'] == captured['driven']
    q = captured['baseline']
    plan = json.loads((H/'group-plan.json').read_text())
    families = census(q, plan)
    (H/'address-families.json').write_text(json.dumps(families, indent=2)+'\n')
    partial = translated_plan(q, plan, ('load_param', 'load_base'))
    naive = translated_plan(q, plan, KINDS)
    checks, _ = replay(q, plan)
    n, _ = replay(q, partial)
    checks += n
    try:
        replay(q, naive)
    except AssertionError as e:
        naive_failure = str(e)
    else:
        raise AssertionError('expected nonuniform raw addresses')
    controls = {}
    def reject(name, bad):
        try:
            replay(q, bad)
        except (AssertionError, IndexError, KeyError):
            controls[name] = True
        else:
            raise AssertionError(('undetected', name))
    for kind in ('load_param', 'load_base'):
        bad = copy.deepcopy(partial)
        bad['groups'][4]['translated'][kind][0] += 1
        reject('wrong_'+kind+'_offset', bad)
    bad = copy.deepcopy(partial)
    bad['groups'][4]['translated']['load_param'][0] *= 16
    reject('byte_element_unit_confusion', bad)
    nin = len(partial['groups'][4]['inputs'])
    ops = q['ops'][partial['groups'][4]['start']:partial['groups'][4]['end']]
    loads = [op for op in ops if op['kind'] in KINDS]
    raw_index = next(i for i, op in enumerate(loads) if op['kind'] == 'load_raw')
    bad = copy.deepcopy(partial)
    bad['groups'][4]['map'][nin+raw_index] = 65535
    reject('retained_raw_out_of_bounds', bad)
    bad = copy.deepcopy(partial)
    bad['groups'][4]['map'][0] = (bad['groups'][4]['map'][0]+1) % plan['capacity']
    reject('scratch_alias', bad)
    bad = copy.deepcopy(partial)
    bad['groups'][4]['translated']['load_param'] = bad['groups'][3]['translated']['load_param'][:]
    reject('stale_instance', bad)
    # The full naive candidate also goes out of bounds in a later instance.
    # Isolate its first nonuniform instance for an in-bounds numerical control.
    wrong_local = copy.deepcopy(partial)
    wrong_local['groups'][4]['translated']['load_raw'] = naive['groups'][4]['translated']['load_raw'][:]
    rng = random.Random(SEED)
    digest = hashlib.sha256()
    numerical = collections.Counter()
    for mode, count in [('random', 24), ('boundary', 8), ('zero', 1)]:
        for _ in range(count):
            arrays = fixture(rng, mode)
            ref = direct(q, arrays)
            _, mapped = replay(q, plan, arrays)
            _, shifted = replay(q, partial, arrays)
            _, wrong = replay(q, wrong_local, arrays)
            assert ref == mapped == shifted
            numerical['fixtures'] += 1
            numerical['coefficients_per_arm'] += len(ref)
            numerical['naive_wrong_'+mode] += (wrong != ref)
            digest.update(json.dumps(ref).encode())
    assert numerical['naive_wrong_random'] == 24
    assert numerical['naive_wrong_boundary'] > 0
    assert numerical['naive_wrong_zero'] == 0
    controls['naive_uniform_raw_value_failure'] = True
    controls['all_zero_cannot_validate_address_mapping'] = True
    repeated = [g for g in plan['groups'] if len(plan['templates'][g['template']]['instances']) > 1]
    removed_entries = sum(len(g['translated'][k]) for g in partial['groups']
                          for k in g.get('translated', {}))
    source_counts = {k: sum(len(source_slots(q, g)[k]) for g in repeated) for k in KINDS}
    shifts = sum(any(x != 0 for x in f['sources'][k]['differences'][i])
                 for f in families for i in range(len(f['instances']))
                 for k in ('load_param', 'load_base'))
    pins = json.loads((H/'input-pins.json').read_text())
    for pin in pins:
        assert hashlib.sha256((H/pin['local']).read_bytes()).hexdigest() == pin['sha256']
    cpu_model = next(line.split(':', 1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines()
                     if line.startswith('model name'))
    out = dict(status='PASS', hypothesis_result='Uniform raw-pointer translation FALSIFIED; partial parameter/base translation exact in symbolic and synthetic tests only',
               run_id='20261019T151854Z-4f2eec2a', seed=SEED,
               symbolic_checks=checks, negative_controls=controls, numerical=dict(numerical),
               naive_first_failure=naive_failure, output_digest=digest.hexdigest(),
               dag_ops=len(q['ops']), field_primitives={k:v for k,v in q['census'].items() if not k.startswith('load_')},
               original_tables=59, original_fold_reads=118, original_fold_writes=59,
               original_finals=59, original_folds_unchanged=True, degree=4,
               families=len(families), repeated_calls=len(repeated),
               noncanonical_instances=sum(len(f['instances'])-1 for f in families),
               nonuniform_raw_instances=sum(not b for f in families for b in f['sources']['load_raw']['uniform']),
               minimal_raw_translation_groups={str(f['template']):len(f['sources']['load_raw']['minimal_translation_groups']) for f in families},
               partial_map_cost=dict(baseline_map_bytes=plan['map_bytes'], removed_entries=removed_entries,
                    removed_map_bytes=2*removed_entries, remaining_map_bytes=plan['map_bytes']-2*removed_entries,
                    repeated_source_loads=source_counts, added_nonzero_pointer_shifts=shifts,
                    extra_helper_arguments=0, partial_logical_bytes=9162-2*removed_entries,
                    baseline_shared_logical_bytes=9162, scalar_logical_bytes=4320,
                    scratch_bytes=16*plan['capacity'], compiled_code_bytes=None,
                    physical_DRAM_bytes=None, candidate_runtime_seconds=None,
                    note='Static address-index requests only. Interpreter retains full maps as oracle; no lowered kernel implemented. Pointer arithmetic/stack/compiler costs unmeasured.'),
               wall_seconds=time.perf_counter()-t, rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
               cpu_model=cpu_model, cpu_affinity=[cpu], threads=1, nice=os.getpriority(os.PRIO_PROCESS,0),
               platform=platform.platform(), python=platform.python_version(),
               limits='59 seconds CPU/wall;512MiB address space;one nice19 CPU;no GPU/build/install/foreign execution',
               scope='Public topology/address census and arbitrary synthetic Fp2 coefficient values. No native admission, profile fixture generation, sampler/folds/finals proof test, transcript/RNG/masks/PCS/proof/verification/GPU timing. No tokens counted.')
    (H/'result.json').write_text(json.dumps(out, indent=2)+'\n')
    (H/'partial-address-plan.json').write_text(json.dumps(partial, indent=2)+'\n')
    print(json.dumps(out, indent=2))


if __name__ == '__main__':
    main()
