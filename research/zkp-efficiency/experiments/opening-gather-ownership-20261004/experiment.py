#!/usr/bin/env python3
"""CPU-only oracle for chunk-local CUDA opening destinations, not a prover.

Reference: direct DFT/polynomial evaluation and independent query-major reads.
Candidate: radix-2 NTT, native open-plan semantics, kernel store-address model.
All data and pads are synthetic; nothing imported from downloaded code.
"""
import array
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import random
import resource
import signal
import struct
import sys
import time

P = 0xFFFFFFFF00000001
SEED = 2026100419
HERE = Path(__file__).resolve().parent
ROOT = Path('/home/victor/IntelligenceRegulation')


def limits():
    os.nice(19)
    resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2, 512 * 1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (55, 55))
    signal.alarm(59)
    if hasattr(os, 'sched_getaffinity'):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})


def ntt(values, inverse=False):
    """Independent implementation of radix-2 butterflies, natural output."""
    a = list(values)
    n = len(a)
    assert n and n & (n - 1) == 0
    j = 0
    for i in range(1, n):
        b = n >> 1
        while j & b:
            j ^= b
            b >>= 1
        j ^= b
        if i < j:
            a[i], a[j] = a[j], a[i]
    step = 2
    while step <= n:
        w0 = pow(7, (P - 1) // step, P)
        if inverse:
            w0 = pow(w0, P - 2, P)
        for base in range(0, n, step):
            w = 1
            for k in range(step // 2):
                u = a[base + k]
                v = a[base + k + step // 2] * w % P
                a[base + k] = (u + v) % P
                a[base + k + step // 2] = (u - v) % P
                w = w * w0 % P
        step <<= 1
    if inverse:
        scale = pow(n, P - 2, P)
        a = [v * scale % P for v in a]
    return a


def reference_encode(data, pads, nn):
    """Direct inverse DFT then evaluate f+(X^n-1)pad at coset points."""
    n = len(data)
    wn = pow(7, (P - 1) // n, P)
    invn = pow(n, P - 2, P)
    coeffs = [sum(data[j] * pow(wn, (-i * j) % n, P)
                  for j in range(n)) * invn % P for i in range(n)]
    w = pow(7, (P - 1) // nn, P)
    out = []
    for j in range(nn):
        x = 7 * pow(w, j, P) % P
        f = sum(c * pow(x, i, P) for i, c in enumerate(coeffs)) % P
        pad = sum(c * pow(x, i, P) for i, c in enumerate(pads)) % P
        out.append((f + (pow(x, n, P) - 1) * pad) % P)
    return out


def candidate_encode(data, pads, nn):
    n = len(data)
    co = ntt(data, True)
    buf = [0] * nn
    for i, v in enumerate(co):
        buf[i] = v
    for i, v in enumerate(pads):
        buf[i] = (buf[i] - v) % P
        buf[n + i] = (buf[n + i] + v) % P
    return ntt([v * pow(7, i, P) % P for i, v in enumerate(buf)])


def power2(n):
    return n > 0 and n & (n - 1) == 0


def open_plan(idx, nn, blk, group, fuse, prune, events):
    # Match native shape/empty/range refusal order, before scratch/output.
    if not power2(nn) or not power2(blk) or group == 0:
        raise ValueError(f'open plan: malformed shape (nn {nn}, blk {blk}, p2sp_nc {group})')
    if not idx:
        return None
    for j in idx:
        if j >= nn:
            raise ValueError(f'opened index {j} is out of range for {nn} encoded columns')
    fused = fuse and nn > blk
    sel = [-1] * nn
    unique = []
    slots = []
    for j in idx:
        if sel[j] < 0:
            sel[j] = len(unique)
            unique.append(j)
        slots.append(sel[j])
    residues = None
    if fused and prune and nn.bit_length() - blk.bit_length() <= 5:
        rs = sorted(set(j & (blk - 1) for j in idx))
        if len(rs) * 4 <= blk:
            residues = (rs + [rs[-1]] * ((-len(rs)) % group), len(rs))
    events.append('plan')
    return {'fused': fused, 'unique': unique, 'sel': sel,
            'slots': slots if fused else list(range(len(idx))),
            'device_columns': unique if fused else list(idx), 'residues': residues}


def chunk_plan(rows, chunk):
    # Native 128-row granularity; smaller fixtures exercise a single chunk.
    if rows <= chunk:
        return [(0, rows)]
    step = max(chunk // 128, 1) * 128
    return [(r, min(step, rows - r)) for r in range(0, rows, step)]


def reference_columns(value_at, rows, idx):
    return [[value_at(r, j) for r in range(rows)] for j in idx]


def gather(value_at, rows, nn, idx, chunk, fuse, prune, local, blk=4096, group=64):
    events = []
    plan = open_plan(idx, nn, blk, group, fuse, prune, events)
    if plan is None:
        return [], {'events': events, 'd2h_calls': 0, 'peak_device_output': 0,
                    'peak_host_stage': 0, 'final_bytes': 0, 'd2h_bytes': 0}
    chunks = chunk_plan(rows, chunk)
    count = len(plan['device_columns'])
    final = [array.array('Q', [0]) * rows for _ in idx] if local else None
    full = None if local else array.array('Q', [0]) * (rows * count)
    max_stage = 0
    events.append('scratch/output')
    for r0, rc in chunks:
        dest = array.array('Q', [0]) * (rc * count) if local else full
        row0, stride = (0, rc) if local else (r0, rows)
        # CUDA kernels store c*rows_total+(row0+row), both fused/pruned/unfused.
        if plan['fused']:
            if plan['residues']:
                rs, live = plan['residues']
                # The padded lanes compute, but jc >= nc_real NEVER stores.
                visit = [t * blk + rs[k] for k in range(live) for t in range(nn // blk)]
            else:
                visit = range(nn)
            written = set()
            for j in visit:
                c = plan['sel'][j]
                if c < 0:
                    continue
                for r in range(rc):
                    addr = c * stride + row0 + r
                    assert addr not in written, 'padded lane wrote twice'
                    written.add(addr)
                    dest[addr] = value_at(r0 + r, j)
            assert len(written) == rc * count
        else:
            for g in range(rc * len(idx)):
                c, r = divmod(g, rc)
                dest[c * stride + row0 + r] = value_at(r0 + r, idx[c])
        if local:
            # Device -> host copy lifetime overlaps final output exactly here.
            host = array.array('Q', dest)
            max_stage = max(max_stage, len(host) * 8)
            for c, slot in enumerate(plan['slots']):
                final[c][r0:r0 + rc] = host[slot * rc:(slot + 1) * rc]
            del host, dest
    if not local:
        host = array.array('Q', full)
        max_stage = len(host) * 8
        final = [array.array('Q', host[s * rows:(s + 1) * rows]) for s in plan['slots']]
    return final, {'events': events, 'd2h_calls': len(chunks) if local else 1,
                   'peak_device_output': 8 * count * (max(rc for _, rc in chunks) if local else rows),
                   'peak_host_stage': max_stage, 'final_bytes': 8 * rows * len(idx),
                   'd2h_bytes': 8 * rows * count, 'fused': plan['fused'],
                   'unique': len(plan['unique']), 'device_columns': count,
                   'chunks': len(chunks), 'pruned': plan['residues'] is not None}


def raw_at(row, col):
    # Transparent Fp(v) conversion must preserve RAW bits, even a noncanonical
    # device defect. Do not silently add Fp::new or a new production refusal.
    edges = [0, 1, P - 1, P, (1 << 64) - 1]
    if (row * 3 + col) % 17 < 5:
        return edges[(row * 3 + col) % 17]
    x = ((row + 1) * 0x9E3779B97F4A7C15 + (col + 1) * 0xD1342543DE82EF95) & ((1 << 64) - 1)
    return x % P


def ref_bytes(cols, idx):
    return b''.join(j.to_bytes(8, 'little') + b''.join(v.to_bytes(8, 'little') for v in c)
                    for j, c in zip(idx, cols))


def candidate_bytes(cols, idx):
    assert sys.byteorder == 'little'
    return b''.join(struct.pack('<Q', j) + c.tobytes() for j, c in zip(idx, cols))


def cost(rows, queries, cols_out, block):
    b = min(rows, block)
    return {'rows': rows, 'queries': queries, 'cols_out': cols_out, 'row_chunk': block,
            'baseline_host_named_bytes': 8 * rows * (queries + cols_out),
            'candidate_host_named_bytes': 8 * (rows * queries + b * cols_out),
            'saved_host_stage_bytes': 8 * (rows - b) * cols_out,
            'baseline_device_output_bytes': 8 * rows * cols_out,
            'candidate_device_output_bytes': 8 * b * cols_out,
            'unavoidable_final_bytes': 8 * rows * queries,
            'd2h_bytes_each': 8 * rows * cols_out,
            'baseline_d2h_calls': 1, 'candidate_d2h_calls': math.ceil(rows / block)}


def main():
    limits()
    start = time.perf_counter()
    rng = random.Random(SEED)
    records = []
    encode_words = 0
    serialization_digest = hashlib.sha256()
    for n, q, nn, rows in [(1, 1, 4, 1), (2, 3, 8, 3), (8, 9, 32, 5), (16, 5, 64, 7)]:
        data = [[rng.randrange(P) for _ in range(n)] for _ in range(rows)]
        pads = [[rng.randrange(P) for _ in range(q)] for _ in range(rows)]
        matrix = [reference_encode(d, p, nn) for d, p in zip(data, pads)]
        cand = [candidate_encode(d, p, nn) for d, p in zip(data, pads)]
        assert cand == matrix
        encode_words += rows * nn
        idx = [nn - 1, 0, nn - 1, nn // 2, 1, 0]
        for fuse in [False, True]:
            ref = reference_columns(lambda r, j: matrix[r][j], rows, idx)
            got, stats = gather(lambda r, j: cand[r][j], rows, nn, idx, 128, fuse, True, True, blk=4, group=2)
            assert [list(c) for c in got] == ref
            assert candidate_bytes(got, idx) == ref_bytes(ref, idx)
            serialization_digest.update(ref_bytes(ref, idx))
            records.append({'kind': 'hiding-row', 'n': n, 'pad_q': q, 'nn': nn,
                            'rows': rows, 'query_count': len(idx), **stats})
    words = 0
    for rows, nn, chunk in [(1, 16, 128), (127, 8192, 128), (128, 8192, 128),
                             (129, 8192, 128), (259, 8192, 128), (385, 8192, 256)]:
        query_sets = [[], [nn - 1], [nn - 1] * 9,
                      [nn - 1, 0, nn - 1, nn // 2, 1, 0],
                      list(range(17 if nn > 16 else nn))]
        for idx in query_sets:
            ref = reference_columns(raw_at, rows, idx)
            for fuse, prune in [(False, False), (True, False), (True, True)]:
                base, sb = gather(raw_at, rows, nn, idx, chunk, fuse, prune, False)
                got, sc = gather(raw_at, rows, nn, idx, chunk, fuse, prune, True)
                assert [list(c) for c in base] == ref == [list(c) for c in got]
                assert candidate_bytes(got, idx) == ref_bytes(ref, idx)
                serialization_digest.update(ref_bytes(ref, idx))
                assert sb['d2h_bytes'] == sc['d2h_bytes']
                assert sc['peak_device_output'] <= sb['peak_device_output']
                assert len(set(id(c) for c in got)) == len(got)
                words += rows * len(idx)
                records.append({'kind': 'raw-gather', 'rows': rows, 'nn': nn,
                                'query_count': len(idx), 'chunk': chunk,
                                'baseline': sb, 'candidate': sc})
    controls = []
    rows, nn, idx = 259, 8192, [8191, 0, 8191, 4096, 1, 0]
    ref = reference_columns(raw_at, rows, idx)
    got, st = gather(raw_at, rows, nn, idx, 128, True, True, True)
    def detected(name, bad):
        assert bad != ref
        controls.append(name)
    detected('drop duplicate semantic columns', [list(c) for c in got[:2]])
    detected('sort query order', reference_columns(raw_at, rows, sorted(idx)))
    detected('forget global source row offset', reference_columns(lambda r, j: raw_at(r % 128, j), rows, idx))
    detected('normalize raw Fp words silently', [[v % P for v in c] for c in ref])
    bad = [list(c) for c in got]; bad[0][258] ^= 1; detected('corrupt ragged final row', bad)
    bad = [list(c) for c in got]; bad[2] = list(ref[1]); detected('wrong duplicate slot', bad)
    original = got[2][0]; got[0][0] ^= 1; assert got[2][0] == original
    controls.append('duplicate columns own independent buffers')
    for args in [([nn], nn, 4096, 64), ([0, nn - 1, nn], nn, 4096, 64),
                 ([], 3, 4096, 64), ([0], nn, 3, 64), ([0], nn, 4096, 0)]:
        events = []
        try:
            open_plan(*args, True, True, events)
            raise AssertionError('expected boundary refusal')
        except ValueError:
            assert not events
            controls.append('refuse before scratch: ' + str(args))
    empty, empty_st = gather(raw_at, rows, nn, [], 128, True, True, True)
    assert empty == [] and empty_st['events'] == []
    controls.append('empty no allocations/transfers')
    # Address/length control: retaining global stride in local buffer is OOB.
    try:
        dest = array.array('Q', [0]) * (128 * 4)
        dest[3 * rows + 128 + 127] = 1
        raise AssertionError('expected local stride overflow')
    except IndexError:
        controls.append('global stride in tile buffer overflows')
    pruned_plan = open_plan(idx, nn, 4096, 64, True, True, [])
    rs, live = pruned_plan['residues']
    bad_visits = [t * 4096 + r for r in rs for t in range(2)]
    touched = [pruned_plan['sel'][j] for j in bad_visits if pruned_plan['sel'][j] >= 0]
    assert len(touched) > len(set(touched))
    assert live < len(rs)
    controls.append('padded residue lanes without guard duplicate writes')
    # No measured native timing: inspect exact existing A/H row ledgers only.
    prev = json.loads((HERE / 'snapshots/research__zkp-efficiency__experiments__public-witness-lifetimes-20261004__result.json').read_text())
    ledger = []
    for shape in prev['ledger']:
        for plane, key in [('A', 'A_rows'), ('H', 'H_rows')]:
            for block in [128, 512, 2048]:
                ledger.append({'shape': shape['name'], 'context': shape['context'],
                               'registered': shape['registered'], 'plane': plane,
                               'norm_limbs': shape['norm_limbs'],
                               **cost(shape[key], 256, 256, block)})
    assert any(r['saved_host_stage_bytes'] == 0 for r in ledger)
    cpu = next((l.split(':', 1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines()
                if l.startswith('model name')), 'unknown')
    out = {'status': 'passed', 'run_identity': '20261004T010146Z-23455eeb', 'seed': SEED,
           'case_count': len(records), 'cases': records, 'gather_words_compared': words,
           'hiding_encoding_words_compared': encode_words, 'negative_controls': controls,
           'serialized_column_bodies_sha256': serialization_digest.hexdigest(),
           'negative_control_count': len(controls), 'ledger': ledger,
           'elapsed_s': time.perf_counter() - start, 'peak_rss_kib': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
           'threads': 1, 'python': platform.python_version(), 'cpu': cpu, 'device': 'CPU only',
           'estimated_memory_mib': 64, 'script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
           'scope': 'Synthetic hiding-row arithmetic + CUDA gather address/ownership oracle; no native CUDA execution, transcript, mask generator or proof',
           'limits': 'Named u64/Fp payload counts exclude NTT/device pools, stored data/pads/powers, other commitments, receipts, allocation metadata; no RSS/VRAM or speed projection. 8B row shapes unregistered and native ln!=4 refuses.',
           'full_stack': {'countable_tokens': 0, 'passes': 0, 'context_length': None,
                          **{k: None for k in ['steady_tokens_per_s', 'total_tokens_per_s', 'startup_fraction',
                                              'witness_s', 'proof_s', 'serialization_s', 'verification_s',
                                              'proof_lag_s', 'pipeline_drain_s']}}}
    (HERE / 'result.json').write_text(json.dumps(out, indent=2) + '\n')
    print(json.dumps({k: v for k, v in out.items() if k not in ['cases', 'ledger']}, indent=2))


if __name__ == '__main__':
    main()
