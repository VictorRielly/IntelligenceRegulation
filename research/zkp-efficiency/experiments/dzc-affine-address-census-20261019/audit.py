#!/usr/bin/env python3
"""Independent captured-map matrix census and unchanged native-field oracle.

Does not import the candidate generator/interpreter. No native proof executed.
"""
import collections
import ctypes
import hashlib
import json
import os
import random
import resource
import signal
import time
from pathlib import Path

H = Path(__file__).resolve().parent
P = 0xffffffff00000001


def matrix(q, p, ci, kind):
    result = []
    for gi in p['templates'][ci]['instances']:
        g = p['groups'][gi]
        positions = [x for x in q['ops'][g['start']:g['end']]
                     if x['kind'].startswith('load_')]
        row = []
        for i, op in enumerate(positions):
            addr = g['map'][len(g['inputs'])+i]
            assert addr == op['slot']
            if op['kind'] == kind:
                row.append(addr)
        result.append(row)
    return result


def min_groups(rows):
    """Count translation equivalence by pairwise address differences."""
    representatives = []
    for col in range(len(rows[0])):
        for representative in representatives:
            if all(row[col]-row[representative] == rows[0][col]-rows[0][representative]
                   for row in rows):
                break
        else:
            representatives.append(col)
    return len(representatives)


def naive_python(q, arrays, nonresidue=7):
    # Deliberately use complex-number style pairs and arithmetic inline;
    # no dependency on the candidate's primitive or address interpreter.
    values = {}
    for x in q['ops']:
        k = x['kind']
        if k.startswith('load_'):
            v = arrays[k][x['slot']]
        else:
            a, b = (values[d] for d in x['deps'])
            if k == 'add':
                v = ((a[0]+b[0]) % P, (a[1]+b[1]) % P)
            elif k == 'sub':
                v = ((a[0]-b[0]) % P, (a[1]-b[1]) % P)
            elif k == 'base':
                v = tuple(t*b % P for t in a)
            else:
                assert k == 'mul'
                v = ((a[0]*b[0]+nonresidue*a[1]*b[1]) % P,
                     (a[0]*b[1]+a[1]*b[0]) % P)
        values[x['id']] = v
    return [values[d] for d in q['output']]


def main():
    t = time.perf_counter()
    os.nice(19)
    cpu = min(os.sched_getaffinity(0))
    os.sched_setaffinity(0, {cpu})
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2,)*2)
    signal.alarm(59)
    q = json.loads((H/'scalar-dags.json').read_text())['baseline']
    p = json.loads((H/'group-plan.json').read_text())
    partial = json.loads((H/'partial-address-plan.json').read_text())
    result = json.loads((H/'result.json').read_text())
    checks = 0
    groups = {}
    for ci, cls in enumerate(p['templates']):
        if len(cls['instances']) < 2:
            continue
        for kind in ('load_raw', 'load_param', 'load_base'):
            rows = matrix(q, p, ci, kind)
            groups[str((ci, kind))] = min_groups(rows)
            if kind != 'load_raw':
                assert min_groups(rows) == 1
            for index, gi in enumerate(cls['instances']):
                g = partial['groups'][gi]
                if kind == 'load_raw':
                    assert kind not in g['translated']
                else:
                    assert g['translated'][kind] == rows[index]
                checks += len(rows[index])
        for gi in cls['instances']:
            # Scratch/raw maps stay exactly as captured; no altered topology.
            new = partial['groups'][gi].copy()
            del new['address_mode'], new['translated']
            assert new == p['groups'][gi]
            checks += 1
    assert [groups[str((ci, 'load_raw'))] for ci in (3, 6)] == [2, 3]
    # Derive byte accounting from the captured graph/cuts, not fixed totals.
    c = collections.Counter(x['kind'] for x in q['ops'])
    scalar = 16*(c['load_raw']+c['load_param']+len(q['output']))+8*c['load_base']
    crossing = sum(len(g['inputs'])+len(g['outputs']) for g in p['groups'])
    shared = scalar+16*(crossing+len(q['output']))+p['map_bytes']
    cost = result['partial_map_cost']
    assert scalar == cost['scalar_logical_bytes'] == 4320
    assert shared == cost['baseline_shared_logical_bytes'] == 9162
    assert cost['removed_entries'] == 11*(7+2) == 99
    assert cost['remaining_map_bytes'] == 436
    assert cost['partial_logical_bytes'] == shared-198 == 8964
    assert cost['added_nonzero_pointer_shifts'] == 2*(11-2) == 18
    assert partial['slots'] == p['slots'] and partial['templates'] == p['templates']
    checks += 8
    controls = {}
    bad = [row[:] for row in matrix(q, p, 3, 'load_param')]
    bad[1][0] += 1
    assert min_groups(bad) > 1
    controls['corrupt_parameter_uniformity'] = True
    bad = [row[:] for row in matrix(q, p, 6, 'load_raw')]
    for row in bad:
        row[4] = row[0]+2
        row[5] = row[1]+2
    assert min_groups(bad) == 2  # loses the exceptional g14 subgroup
    controls['raw_exception_not_silently_merged'] = True
    for pin in json.loads((H/'oracle-pins.json').read_text()):
        assert hashlib.sha256((H/pin['local']).read_bytes()).hexdigest() == pin['sha256']
        checks += 1
    U = ctypes.c_uint64
    ptr = ctypes.POINTER(U)
    library = ctypes.CDLL(str(H/'oracle/libkernels.so'))
    library.baseline.argtypes = [ptr, ptr, ptr, ptr]
    library.baseline.restype = None
    rng = random.Random(2026101984)
    total = wrong_field = 0
    for index in range(36):
        def elem():
            if index == 0:
                return 0
            if index == 1:
                return P-1
            if index == 2:
                return rng.choice((0, 1, P-1))
            return rng.randrange(P)
        arrays = {k:[elem() if k == 'load_base' else (elem(), elem()) for _ in range(n)]
                  for k, n in [('load_raw',118),('load_param',129),('load_base',36)]}
        bufs = []
        for kind in ('load_raw', 'load_param', 'load_base'):
            data = arrays[kind]
            flat = data if kind == 'load_base' else [v for pair in data for v in pair]
            bufs.append((U*len(flat))(*flat))
        out = (U*10)()
        library.baseline(*bufs, out)
        native = [(out[i], out[i+1]) for i in range(0, 10, 2)]
        assert native == naive_python(q, arrays)
        wrong_field += native != naive_python(q, arrays, nonresidue=-7)
        total += len(native)
    assert wrong_field >= 30
    controls['wrong_extension_polynomial'] = True
    pins = json.loads((H/'pin-recheck.json').read_text())
    assert len(pins) == 20 and all(x['matches'] for x in pins)
    out = dict(status='PASS', checks=checks, translation_groups=groups,
               controls=controls, native_field_oracle_fixtures=36,
               native_field_oracle_coefficients=total, wrong_field_fixtures=wrong_field,
               oracle_scope='Prior research compiled scalar coefficient kernel, unchanged source field. No captured whole-D/catalog, native admission or new proof/final verification.',
               wall_seconds=time.perf_counter()-t,
               rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
               cpu_affinity=[cpu], threads=1, limits='59s CPU/wall;512MiB address space;one nice19 CPU')
    (H/'audit-result.json').write_text(json.dumps(out, indent=2)+'\n')
    print(json.dumps(out, indent=2))


if __name__ == '__main__':
    main()
