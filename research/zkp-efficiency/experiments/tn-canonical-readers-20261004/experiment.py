#!/usr/bin/env python3
"""Synthetic exact TN readers. Standard library only; never runs native code."""
import dataclasses
import hashlib
import itertools
import json
import os
from pathlib import Path
import random
import resource
import signal
import struct
import time

P = 2**64 - 2**32 + 1
SEED = 2026100426
ONE, ZERO = (1, 0), (0, 0)


def add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def mul(a, b):
    return ((a[0]*b[0] + 7*a[1]*b[1]) % P,
            (a[0]*b[1] + a[1]*b[0]) % P)


def eq_reference(point):
    # Explicit product of bits, independent of the doubling algorithm.
    out = []
    for bits in itertools.product((0, 1), repeat=len(point)):
        v = ONE
        for bit, r in zip(bits, point):
            v = mul(v, r if bit else ((1-r[0]) % P, -r[1] % P))
        out.append(v)
    return out


def eq_native_order(point):
    out = [ONE]
    for r in reversed(point):
        old = out
        out = [mul(e, ((1-r[0]) % P, -r[1] % P)) for e in old]
        out += [mul(e, r) for e in old]
    return out


def signed(v):
    return v - 256 if v >= 128 else v


def align4(n):
    return (n+3)//4*4


@dataclasses.dataclass(frozen=True)
class TN:
    rows: int
    cols: int
    true_rows: int
    true_cols: int
    ld: int
    physical_cols: int
    data: bytes
    identity: tuple
    orientation: str = 'column-major-input-output'

    def raw(self, i, j):
        return self.data[j*self.ld+i]

    def validate(self):
        if self.orientation != 'column-major-input-output':
            raise ValueError('orientation')
        if (self.rows < 1 or self.cols < 1 or self.ld < align4(self.rows)
                or self.physical_cols != align4(self.cols)
                or len(self.data) != self.ld*self.physical_cols):
            raise ValueError('shape/stride')
        if not (0 <= self.true_rows <= self.rows and 0 <= self.true_cols <= self.cols):
            raise ValueError('support shape')
        # Artificial aligned K/N tails, consumed by a future byte GEMM, are zero.
        # Extra stride guards [align4(rows), ld) are not algebra coordinates.
        for j in range(self.physical_cols):
            for i in range(align4(self.rows)):
                if (i >= self.rows or j >= self.cols) and self.raw(i, j):
                    raise ValueError('adapter tail')
        for i in range(self.rows):
            for j in range(self.cols):
                if self.raw(i, j) and (i >= self.true_rows or j >= self.true_cols):
                    raise ValueError('padded width')


def prepare(original, rows, cols, tr, tc, extra):
    assert len(original) == rows*cols
    ld, pc = align4(rows)+extra, align4(cols)
    physical = bytearray(ld*pc)
    for j in range(pc):
        for i in range(align4(rows), ld):
            physical[j*ld+i] = 0xA5  # ignored guard, not an aligned tail
    for i in range(rows):
        for j in range(cols):
            physical[j*ld+i] = original[i*cols+j] & 255
    identity = ('synthetic-model', 'layer7', 'down', 'profile-test',
                'calibration-test', rows, cols, tr, tc,
                hashlib.sha256(bytes(v & 255 for v in original)).hexdigest())
    return TN(rows, cols, tr, tc, ld, pc, bytes(physical), identity)


def canonical_chunks(store, row_block):
    if row_block < 1:
        raise ValueError('row block')
    for first in range(0, store.rows, row_block):
        nr = min(row_block, store.rows-first)
        scratch = bytearray(nr*store.cols)
        # Read contiguous input rows within each physical output column.
        for j in range(store.cols):
            for local in range(nr):
                scratch[local*store.cols+j] = store.raw(first+local, j)
        yield bytes(scratch)


def admit(store, expected_identity):
    store.validate()
    if store.identity != expected_identity or store.identity[5:9] != (
            store.rows, store.cols, store.true_rows, store.true_cols):
        raise ValueError('identity metadata')
    h = hashlib.sha256()
    for chunk in canonical_chunks(store, 3):
        h.update(chunk)
    if h.hexdigest() != expected_identity[-1]:
        raise ValueError('canonical content identity')
    return store


def witness_reference(original, rows, cols, x, xs, true_t, out_stride, out_len):
    # Independent source-style logical i64 dot, including all inner padding.
    out = [0]*out_len
    for t in range(true_t):
        for j in range(cols):
            out[t*out_stride+j] = sum(x[t*xs+i]*original[i*cols+j] for i in range(rows))
    return out


def witness_candidate(store, x, xs, true_t, out_stride, out_len):
    out = [0]*out_len
    for j in range(store.cols):
        for t in range(true_t):
            acc = 0
            for i in range(store.rows):
                acc += x[t*xs+i]*signed(store.raw(i, j))
            assert -(1 << 63) <= acc < (1 << 63)
            out[t*out_stride+j] = acc
    return out


def fold_reference(original, rows, cols, point):
    eq = eq_reference(point)
    assert len(eq) == cols
    out = []
    for i in range(rows):
        acc = ZERO
        for j in range(cols):
            acc = add(acc, mul(eq[j], (original[i*cols+j] % P, 0)))
        out.append(acc)
    return out


def fold_candidate(store, point, row_block, column_block):
    eq = eq_native_order(point)
    if len(eq) != store.cols:
        raise ValueError('challenge shape')
    if row_block < 1 or column_block < 1:
        raise ValueError('fold block')
    out = []
    for first in range(0, store.rows, row_block):
        nr = min(row_block, store.rows-first)
        # Two independent base components; no challenge-dependent value cached.
        a, b = [0]*nr, [0]*nr
        for c0 in range(0, store.cols, column_block):
            for j in range(c0, min(store.cols, c0+column_block)):
                ca, cb = eq[j]
                for local in range(nr):
                    v = signed(store.raw(first+local, j))
                    a[local] = (a[local] + ca*v) % P
                    b[local] = (b[local] + cb*v) % P
        out.extend(zip(a, b))
    return out


def ff_bytes_reference(gamma, wg, wu, wd, act):
    out = bytearray()
    for w in (gamma, wg, wu, wd):
        out.extend(struct.pack('<Q', len(w)))
        out.extend(struct.pack(f'{len(w)}b', *w))
    out.extend(struct.pack('<Q', len(act)))
    out.extend(struct.pack('<256h', *act))
    return bytes(out)


def ff_chunks_candidate(gamma, wg, wu, down, act, block):
    for w in (gamma, wg, wu):
        yield len(w).to_bytes(8, 'little')
        yield bytes(v & 255 for v in w)
    yield (down.rows*down.cols).to_bytes(8, 'little')
    yield from canonical_chunks(down, block)
    yield len(act).to_bytes(8, 'little')
    for v in act:
        yield v.to_bytes(2, 'little', signed=True)


def support_reference(w, rows, cols, tr, tc):
    if len(w) != rows*cols:
        return 'shape'
    return 'padded width' if any(v and (i >= tr or j >= tc)
        for i, row in enumerate([w[x:x+cols] for x in range(0, len(w), cols)])
        for j, v in enumerate(row)) else 'accepted'


def line_episodes_enumeration(rows, cols, ld, block, line):
    return sum(len({(j*ld+i)//line for j in range(cols)
                    for i in range(first, min(rows, first+block))})
               for first in range(0, rows, block))


def line_episodes_interval(rows, cols, ld, block, line):
    total = 0
    for first in range(0, rows, block):
        nr = min(block, rows-first)
        intervals = sorted(( (j*ld+first)//line, (j*ld+first+nr-1)//line)
                           for j in range(cols))
        lo, hi = intervals[0]
        for x, y in intervals[1:]:
            if x <= hi+1:
                hi = max(hi, y)
            else:
                total += hi-lo+1
                lo, hi = x, y
        total += hi-lo+1
    return total


def main():
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    available = sorted(os.sched_getaffinity(0))
    os.sched_setaffinity(0, {available[0]})
    os.nice(10)
    start = time.perf_counter()
    rng = random.Random(SEED)
    cases = folds = words = digest_bytes = support_cases = line_cases = raw_dots = 0
    controls = []
    checksums = hashlib.sha256()
    def mismatch(name, expected, wrong):
        assert expected != wrong, name
        controls.append({'name': name, 'detected': 'independent mismatch'})
    def refusal(name, obj):
        try:
            obj.validate()
        except ValueError as e:
            controls.append({'name': name, 'detected': str(e)})
        else:
            raise AssertionError(name)

    for rows, cols, extra, mode in itertools.product((1, 2, 4, 8, 16, 32),
            (1, 2, 4, 8, 16, 32), (0, 1, 5), ('zero', 'extrema', 'random')):
        tr, tc = max(1, rows-1), max(1, cols-1)
        values = [0 if mode == 'zero' else rng.choice((-128, 127))
                  if mode == 'extrema' else rng.randrange(-128, 128)
                  for _ in range(rows*cols)]
        w = [values[i*cols+j] if i < tr and j < tc else 0
             for i in range(rows) for j in range(cols)]
        s = prepare(w, rows, cols, tr, tc, extra)
        admit(s, s.identity)
        assert support_reference(w, rows, cols, tr, tc) == 'accepted'
        gamma = [rng.randrange(-128, 128) for _ in range(cols)]
        wg = [rng.randrange(-128, 128) for _ in range(cols*rows)]
        wu = [rng.randrange(-128, 128) for _ in range(cols*rows)]
        act = [rng.randrange(-32768, 32768) for _ in range(256)]
        act[:4] = [-32768, 32767, -1, 0]
        ref_stream = ff_bytes_reference(gamma, wg, wu, w, act)
        xs, os_ = rows+1, cols+3
        # Three true token rows, one dirty pad row and dirty stride guards.
        x = [rng.choice((-32768, 32767, -1, 0, 1)) for _ in range(4*xs)]
        raw_ref = witness_reference(w, rows, cols, x, xs, 3, os_, 4*os_)
        assert witness_candidate(s, x, xs, 3, os_, 4*os_) == raw_ref
        raw_dots += 3*cols
        for block in (1, 3, 8, 64):
            chunks = list(ff_chunks_candidate(gamma, wg, wu, s, act, block))
            stream = b''.join(chunks)
            assert stream == ref_stream
            digest_bytes += len(stream)
            h = hashlib.sha256()
            for chunk in chunks:
                h.update(chunk)
            assert h.digest() == hashlib.sha256(ref_stream).digest()
        for kind in ('extension', 'base', 'boolean'):
            n = cols.bit_length()-1
            point = [(rng.randrange(P), rng.randrange(1, P)) for _ in range(n)]
            if kind == 'base': point = [(a, 0) for a, _ in point]
            if kind == 'boolean': point = [(rng.randrange(2), 0) for _ in point]
            assert eq_reference(point) == eq_native_order(point)
            ref = fold_reference(w, rows, cols, point)
            for rb, cb in ((1, 1), (3, 3), (8, 5), (64, 64)):
                got = fold_candidate(s, point, rb, cb)
                assert got == ref
                folds += 1
                words += len(got)
                checksums.update(repr(got).encode())
            if kind == 'extension' and rows == 8 and cols == 8 and extra == 1 and mode == 'random':
                saved = s, w, point, ref, ref_stream, gamma, wg, wu, act
        # Independent native support outcome for every nonempty padded axis.
        if tr < rows or tc < cols:
            bad = w.copy()
            i, j = (tr, 0) if tr < rows else (0, tc)
            bad[i*cols+j] = 1
            bs = prepare(bad, rows, cols, tr, tc, extra)
            assert support_reference(bad, rows, cols, tr, tc) == 'padded width'
            try: bs.validate()
            except ValueError as exc: assert str(exc) == 'padded width'
            else: raise AssertionError('internal support must not be trimmed')
            support_cases += 1
        cases += 1

    s, w, point, ref, stream, gamma, wg, wu, act = saved
    refusal('stale orientation', dataclasses.replace(s, orientation='row-major'))
    for field_index in range(5):
        identity = list(s.identity); identity[field_index] += '-stale'
        try: admit(dataclasses.replace(s, identity=tuple(identity)), s.identity)
        except ValueError as exc: controls.append({'name': 'stale identity field '+str(field_index), 'detected': str(exc)})
        else: raise AssertionError('stale metadata')
    refusal('short physical buffer', dataclasses.replace(s, data=s.data[:-1]))
    refusal('wrong leading dimension', dataclasses.replace(s, ld=s.ld+1))
    refusal('wrong aligned columns', dataclasses.replace(s, physical_cols=s.physical_cols+4))
    refusal('invalid support metadata', dataclasses.replace(s, true_rows=s.rows+1))
    small = prepare([1, 2], 1, 2, 1, 2, 0)
    dirty = bytearray(small.data); dirty[1] = 1
    refusal('dirty artificial K tail', dataclasses.replace(small, data=bytes(dirty)))
    dirty = bytearray(small.data); dirty[small.cols*small.ld] = 1
    refusal('dirty artificial output tail', dataclasses.replace(small, data=bytes(dirty)))
    wrong = [signed(x) for x in s.data[:s.rows*s.cols]]
    mismatch('reinterpret TN as canonical row-major', w, wrong)
    mismatch('hash physical TN bytes', bytes(v & 255 for v in w), s.data)
    mismatch('include physical length in canonical frame', len(w).to_bytes(8, 'little'), len(s.data).to_bytes(8, 'little'))
    mismatch('reverse MSB challenge order', ref, fold_candidate(s, list(reversed(point)), 3, 3))
    mismatch('discard extension challenge component', ref, fold_candidate(s, [(a, 0) for a, b in point], 3, 3))
    unsigned_fold = [(sum(eq_reference(point)[j][0]*(w[i*s.cols+j]&255) for j in range(s.cols)) % P,
                      sum(eq_reference(point)[j][1]*(w[i*s.cols+j]&255) for j in range(s.cols)) % P) for i in range(s.rows)]
    mismatch('unsigned i8 field conversion', ref, unsigned_fold)
    fresh_point = [(rng.randrange(P), rng.randrange(1, P)) for _ in point]
    mismatch('reuse challenge-dependent fold', ref, fold_candidate(s, fresh_point, 3, 3))
    dirty = bytearray(s.data); dirty[0] ^= 1
    changed = dataclasses.replace(s, data=bytes(dirty))
    try: admit(changed, s.identity)
    except ValueError as exc: controls.append({'name': 'changed immutable bytes at admission', 'detected': str(exc)})
    else: raise AssertionError('stale content')
    mismatch('reuse caller content identity after changed bytes', s.identity[-1],
             hashlib.sha256(b''.join(canonical_chunks(changed, 3))).hexdigest())
    mismatch('big-endian act words', stream, stream[:-512] + struct.pack('>256h', *act))
    # Padding cancellation does not replace the constructor's entrywise check.
    bad = prepare([0, 0, 1, -1], 2, 2, 1, 2, 0)
    assert fold_candidate(bad, [(pow(2, -1, P), 0)], 2, 2)[1] == ZERO
    refusal('folded zero does not validate dirty canonical support', bad)
    for name, args in [('wrong challenge dimension', (s, point[:-1], 3, 3)),
                       ('empty row block', (s, point, 0, 3)),
                       ('empty column block', (s, point, 3, 0))]:
        try: fold_candidate(*args)
        except ValueError as exc: controls.append({'name': name, 'detected': str(exc)})
        else: raise AssertionError(name)

    for rows, cols, extra, block, line in itertools.product((1, 4, 8, 17, 32, 65),
            (1, 3, 8, 17), (0, 1, 5), (1, 3, 8, 64), (32, 64)):
        ld = align4(rows)+extra
        a = line_episodes_enumeration(rows, cols, ld, block, line)
        b = line_episodes_interval(rows, cols, ld, block, line)
        assert a == b
        line_cases += 1
    counts = []
    k, n, layers = 16384, 4096, 32  # Unadmitted metadata; no allocation.
    for rb in (1, 16, 64, 128, 256):
        # Aligned ld, k and block permit this exact closed-form episode count.
        episodes = layers*(k//rb)*n*((rb+63)//64)
        counts.append({'row_block': rb, 'canonical_digest_scratch_bytes': rb*n,
            'python_immutable_chunk_copy_peak_bytes': 2*rb*n,
            'source_64byte_line_episodes_all_layers': episodes,
            'model': 'cache reset between row blocks; union within each block',
            'not_measured_DRAM_bytes': True})
    result = {'run_id': '20261004T080146Z-55b15f9d', 'seed': SEED, 'status': 'pass',
        'cases': cases, 'fresh_fold_comparisons': folds, 'fold_output_words': words,
        'canonical_FFN_bytes_compared': digest_bytes, 'padded_support_refusals': support_cases,
        'raw_witness_dots_compared': raw_dots,
        'independent_line_accounting_cases': line_cases, 'controls': controls,
        'control_count': len(controls), 'digest': checksums.hexdigest(),
        'elapsed_seconds': time.perf_counter()-start,
        'peak_rss_kib': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        'resources': {'threads': 1, 'affinity': list(os.sched_getaffinity(0)), 'nice': os.nice(0),
            'cpu_seconds_cap': 59, 'wall_alarm_seconds': 59, 'address_space_cap_MiB': 512,
            'estimated_memory_MiB': 64},
        'dimensions': {'logical_rows_cols_powers_of_two': [1, 2, 4, 8, 16, 32],
            'extra_ld': [0, 1, 5], 'modes': ['zero', 'extrema', 'random'],
            'digest_row_blocks': [1, 3, 8, 64], 'fold_blocks': [[1, 1], [3, 3], [8, 5], [64, 64]]},
        'count_only_unadmitted_down': {'layers': layers, 'Kpad': k, 'Npad': n,
            'removed_original_duplicate_bytes_if_all_consumers_migrate': layers*k*n,
            'unchanged_single_TN_payload_bytes': layers*k*n,
            'column_sum_bytes': layers*n*4, 'digest_counts': counts,
            'removed_current_down_cast_vector_bytes_per_layer': k*n,
            'no_large_allocation': True},
        'proof_accounting': {'accepted_complete_private8b_passes': 0, 'countable_tokens': 0,
            'context_length': None, 'passes': 0, 'device': 'CPU only; no GPU',
            'steady_state_proved_tokens_per_second': None, 'total_workload_proved_tokens_per_second': None,
            'startup_fraction': None, 'witness_seconds': None, 'proof_seconds': None,
            'serialization_seconds': None, 'independent_verification_seconds': None,
            'prefill': 'none', 'resident_passes': 'none', 'decode': 'none'},
        'limits': ['Locally authored arithmetic/storage model, not native Rust/CUDA',
            'Exact absorb bytes checked; SHA256 diagnostic, no native BLAKE3/full statement/transcript',
            'No real weights/activations/prompts; synthetic only',
            'No claim about immutable Rust ownership, RNG/PCS/soundness/privacy or actual speed/peak',
            'All original consumers including witness/loader/verifier must migrate before removal',
            'Line episodes are a cache model, not measured memory traffic']}
    here = Path(__file__).resolve().parent
    (here/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: result[k] for k in ('status', 'cases', 'fresh_fold_comparisons',
        'fold_output_words', 'canonical_FFN_bytes_compared', 'padded_support_refusals',
        'independent_line_accounting_cases', 'control_count', 'elapsed_seconds', 'peak_rss_kib')}))


if __name__ == '__main__':
    main()
