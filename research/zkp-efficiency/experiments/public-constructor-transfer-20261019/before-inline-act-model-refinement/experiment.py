#!/usr/bin/env python3
"""Synthetic public-only layout/checked-move oracle and source-lifetime ledger.

No model data, native admission, proof, GPU or throughput benchmark. Python's
consumed wrapper models a Rust move; it does not establish Rust ownership safety.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import resource
import signal
import time

HERE = Path(__file__).resolve().parent
SEED = 2026101986
NAMES = ['wq', 'wk', 'wv', 'wo', 'gamma_a', 'gamma_m', 'wg', 'wu', 'wd']
TNAMES = ['rope_cos', 'rope_sin', 'exp', 'act']
checks = 0


def check(ok):
    global checks
    assert ok
    checks += 1


def limits():
    resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2,) * 2)
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})


def p2(n):
    return 1 << (n - 1).bit_length()


def spec(s):
    d, f, dp, fp, kv = s['d'], s['f'], s['dp'], s['fp'], s['kv'] * s['dh']
    return {
        'wq': (d, d, dp, dp, 'Q', 'D'),
        'wk': (kv, d, kv, dp, 'K', 'D'),
        'wv': (kv, d, kv, dp, 'K', 'D'),
        'wo': (d, d, dp, dp, 'D', 'Q'),
        'gamma_a': (1, d, 1, dp, '1', 'D'),
        'gamma_m': (1, d, 1, dp, '1', 'D'),
        'wg': (d, f, dp, fp, 'D', 'F'),
        'wu': (d, f, dp, fp, 'D', 'F'),
        'wd': (f, d, fp, dp, 'F', 'D'),
    }


def qmap(s, j):
    h, lane = divmod(j, s['dh'])
    group = s['qh'] // s['kv']
    slot = (h // group) * (s['hp'] // s['kv']) + h % group
    return slot * s['dh'] + lane


def pack(s, raw, prefix_bug=False):
    out = {}
    for name, (nr, nc, pr, pc, ra, ca) in spec(s).items():
        om = [qmap(s, i) if ra == 'Q' and not prefix_bug else i for i in range(nr)]
        im = [qmap(s, i) if ca == 'Q' and not prefix_bug else i for i in range(nc)]
        dst = [0] * (pr * pc)
        for i, r in enumerate(om):
            if im == list(range(nc)):
                dst[r * pc:r * pc + nc] = raw[name][i * nc:(i + 1) * nc]
            else:
                for j, c in enumerate(im):
                    dst[r * pc + c] = raw[name][i * nc + j]
        out[name] = dst
    out.update({k: list(raw[k]) for k in TNAMES})
    return out


def inverse_reference(s, raw):
    """Independent per-destination inversion; no candidate pack or qmap call."""
    heads = []
    for g in range(s['kv']):
        heads += [g * (s['hp'] // s['kv']) + h for h in range(s['qh'] // s['kv'])]
    mapped = [h * s['dh'] + k for h in heads for k in range(s['dh'])]
    out = {}
    for name, (nr, nc, pr, pc, ra, ca) in spec(s).items():
        rows = dict(zip(mapped if ra == 'Q' else range(nr), range(nr)))
        cols = dict(zip(mapped if ca == 'Q' else range(nc), range(nc)))
        out[name] = [raw[name][rows[r] * nc + cols[c]] if r in rows and c in cols else 0
                     for r in range(pr) for c in range(pc)]
    for k in TNAMES:
        out[k] = raw[k][:]
    return out


def support(s, axis, i):
    if axis == 'D':
        return i < s['d']
    if axis == 'F':
        return i < s['f']
    if axis == 'Q':
        return i // s['dh'] % (s['hp'] // s['kv']) < s['qh'] // s['kv']
    return True


def validate(s, a):
    """Serial model of constructor check order, with abstract refusal classes."""
    ss = spec(s)
    for names, shape_error in [(NAMES[:5], 'weight_shape'), (NAMES[5:], 'ff_shape')]:
        if any(len(a[n]) != ss[n][2] * ss[n][3] for n in names):
            raise ValueError(shape_error)
        for n in names:
            _, _, pr, pc, ra, ca = ss[n]
            for r in range(pr):
                for c in range(pc):
                    if a[n][r * pc + c]:
                        for axis, index in [(ra, r), (ca, c)]:
                            if not support(s, axis, index):
                                raise ValueError('head_support' if axis == 'Q' else 'width_support')
        if names == NAMES[:5]:
            half = s['dh'] // 2
            if any(len(a[n]) != s['t'] * half for n in TNAMES[:2]) or len(a['exp']) != 256:
                raise ValueError('table_shape')
            if (any(abs(v) > 65536 for n in TNAMES[:2] for v in a[n])
                or any(v != 65536 for v in a['rope_cos'][:half])
                or any(a['rope_sin'][:half])):
                raise ValueError('rope_structure')
            e = a['exp']
            if e[0] != 512 or any(v < 0 or v > 512 for v in e) or any(x < y for x, y in zip(e, e[1:])):
                raise ValueError('exp_structure')
        else:
            if len(a['act']) != 256:
                raise ValueError('act_shape')
            if s['f'] < s['fp'] and a['act'][128] != 0:
                raise ValueError('act_zero')


def reference_verdict(s, a):
    """Separate support-set validator, independently enumerated query slots."""
    dims = spec(s)
    occupied = set()
    slots = s['hp'] // s['kv']
    for g in range(s['kv']):
        occupied.update(range(g * slots, g * slots + s['qh'] // s['kv']))
    sets = {'D': set(range(s['d'])), 'F': set(range(s['f'])),
            'Q': {sl * s['dh'] + j for sl in occupied for j in range(s['dh'])}}
    for names, error in [(NAMES[:5], 'weight_shape'), (NAMES[5:], 'ff_shape')]:
        for n in names:
            if len(a[n]) != dims[n][2] * dims[n][3]:
                return error
        for n in names:
            nr, nc, pr, pc, ra, ca = dims[n]
            for k, v in enumerate(a[n]):
                if v == 0:
                    continue
                r, c = divmod(k, pc)
                for axis, pos in [(ra, r), (ca, c)]:
                    if axis in sets and pos not in sets[axis]:
                        return 'head_support' if axis == 'Q' else 'width_support'
        if names == NAMES[:5]:
            h = s['dh'] // 2
            if len(a['exp']) != 256 or len(a['rope_cos']) != s['t'] * h or len(a['rope_sin']) != s['t'] * h:
                return 'table_shape'
            if (max(a['rope_cos'] + a['rope_sin']) > 65536 or min(a['rope_cos'] + a['rope_sin']) < -65536
                or a['rope_cos'][:h] != [65536] * h or a['rope_sin'][:h] != [0] * h):
                return 'rope_structure'
            if a['exp'][0] != 512 or sorted(a['exp'], reverse=True) != a['exp'] or min(a['exp']) < 0 or max(a['exp']) > 512:
                return 'exp_structure'
        else:
            if len(a['act']) != 256:
                return 'act_shape'
            if s['fp'] != s['f'] and a['act'][128]:
                return 'act_zero'
    return 'accept'


def verdict(s, a):
    try:
        validate(s, a)
        return 'accept'
    except ValueError as e:
        return str(e)


class MoveBundle:
    def __init__(self, arrays):
        self.arrays = arrays

    def take_checked(self, s):
        if self.arrays is None:
            raise ValueError('consumed')
        validate(s, self.arrays)
        a, self.arrays = self.arrays, None
        return a


def encoding(a):
    b = bytearray()
    for n in NAMES + TNAMES:
        size = 8 if n in ['rope_cos', 'rope_sin', 'exp'] else 2 if n == 'act' else 1
        b += len(a[n]).to_bytes(8, 'little')
        for v in a[n]:
            b += int(v).to_bytes(size, 'little', signed=True)
    return bytes(b)


def accounting():
    d, f, dp, fp, kv, t, half = 4096, 14336, 4096, 16384, 1024, 128, 64
    raw_i8 = 2*d*d + 2*kv*d + 2*d + 3*d*f
    raw = raw_i8 + 256*8 + 256*2
    padded = 2*dp*dp + 2*kv*dp + 2*dp + 3*dp*fp
    rope = 2*t*half*8
    public = padded + rope + 256*8 + 256*2
    max_raw = d*f
    max_padded = dp*fp
    # Wide conservative reservation: max Option<usize> row map + usize inner map.
    maps = max(16*fp+8*dp, 16*dp+8*fp)
    small = 256*8 + 256*2
    # Extra RoPE pair covers generated vectors retained on opt-in export branch.
    branch_rope = rope
    support_scratch = 8*max(dp,fp)  # loose public inner_off index reservation
    rows = []
    for mode in ['borrowed_copy', 'checked_move']:
        # These are sums of known payload lengths, not actual capacities or RSS.
        pad_peak = raw + padded + max_raw + maps + rope + branch_rope + small
        construct_peak = raw + padded + rope + branch_rope + public + small if mode == 'borrowed_copy' else raw + public + branch_rope + small
        construct_peak += support_scratch
        for workers in [1, 16]:
            hash_scratch = max_padded if workers == 1 else padded
            post_pad_extra = padded + rope if mode == 'borrowed_copy' else 0
            record_peak = raw + public + post_pad_extra + hash_scratch + branch_rope + small
            peak = max(pad_peak, construct_peak, record_peak)
            for pins in [0, 4]:
                # One distinct current block while next loader constructs; pins distinct.
                envelope = (pins+1)*public + peak
                rows.append(dict(mode=mode, native_workers_accounted=workers, pins=pins,
                                 pad_phase_bytes=pad_peak, constructor_phase_bytes=construct_peak,
                                 record_phase_bytes=record_peak, loader_payload_envelope_bytes=peak,
                                 current_next_with_pins_payload_envelope_bytes=envelope,
                                 envelope_gib=envelope/2**30))
    return dict(raw11_bytes=raw, padded_i8_bytes=padded, public_payload_bytes=public,
                rope_pair_bytes=rope, support_index_reservation_bytes=support_scratch,
                avoided_to_vec_bytes_per_load=public-512,
                avoided_vector_allocations_per_load=12, unchanged_act_inline_copy_bytes=512,
                max_decode_temporary_bytes=max_raw, pad_index_map_reservation_bytes=maps,
                tables_stack_payload_bytes=small, exported_branch_extra_rope_reservation_bytes=branch_rope,
                rows=rows,
                exclusions=['allocator/capacity slack','JSON/manifest/source_tensors','Rayon stacks and metadata',
                            'file/page cache','witness/planes','proof/commitment','serialization','GPU/device buffers'],
                scope='Full sealing load with LayerRecord::of_block; source-lifetime logical payload envelopes only. NOT actual allocator peaks, host limits, fit, VRAM or time. Reload skips LayerRecord and needs its own timeline.')


def main():
    limits()
    t0 = time.perf_counter()
    rng = random.Random(SEED)
    fixtures, controls, mutations = [], set(), 0
    geometries = [(2,1,2,5), (6,2,2,11), (12,4,2,19), (8,2,2,16), (3,1,4,9), (12,4,4,25)]
    for fixture in range(48):
        qh, kv, dh, f = geometries[fixture % len(geometries)]
        s = dict(qh=qh, kv=kv, dh=dh, hp=p2(qh), d=qh*dh, dp=p2(qh)*dh, f=f, fp=p2(f), t=3)
        raw = {n: [rng.choice([v for v in range(-128,128) if v]) for _ in range(nr*nc)]
               for n, (nr,nc,*_) in spec(s).items()}
        raw.update(rope_cos=[65536]*(s['t']*(dh//2)), rope_sin=[0]*(s['t']*(dh//2)),
                   exp=[512-2*k for k in range(256)], act=[(k-128)*4 for k in range(256)])
        padded = pack(s, raw)
        ref = inverse_reference(s, raw)
        check(padded == ref)
        check(verdict(s,padded) == reference_verdict(s,padded) == 'accept')
        # Baseline borrowed constructor copies; candidate transfers the buffers.
        base = {n: list(v) for n,v in padded.items()}
        bundle = MoveBundle(padded)
        before = {n:id(v) for n,v in padded.items()}
        owned = bundle.take_checked(s)
        check(all(id(owned[n]) == before[n] for n in owned))
        check(all(base[n] is not owned[n] for n in owned))
        check(encoding(base) == encoding(owned))
        try:
            bundle.take_checked(s)
            raise AssertionError('consumed wrapper reused')
        except ValueError as e:
            check(str(e) == 'consumed')
        controls.add('consumed_wrapper_reuse_refused')
        cases = []
        for name in NAMES+TNAMES:
            bad = copy.deepcopy(owned); bad[name].pop(); cases.append(('length_'+name,bad))
        for name, (_,_,pr,pc,ra,ca) in spec(s).items():
            off = [r*pc+c for r in range(pr) for c in range(pc) if not support(s,ra,r) or not support(s,ca,c)]
            for index in off[:2] + off[-2:]:
                bad = copy.deepcopy(owned); bad[name][index]=1; cases.append(('support_'+name,bad))
        for n,i,v in [('rope_cos',0,0),('rope_sin',0,1),('rope_cos',-1,65537),
                      ('exp',0,511),('exp',-1,-1),('exp',4,512),('act',128,1)]:
            bad=copy.deepcopy(owned);bad[n][i]=v;cases.append((n+'_structure',bad))
        for label,bad in cases:
            expected=reference_verdict(s,bad)
            check(verdict(s,bad)==expected)
            b=MoveBundle(bad)
            if expected=='accept':
                check(b.take_checked(s)==bad)
                controls.add('act128_change_allowed_without_f_padding')
            else:
                try:
                    b.take_checked(s)
                    raise AssertionError('bad public bundle accepted')
                except ValueError as e:
                    check(str(e)==expected)
                check(b.arrays is bad)
                mutations += 1
                controls.add(label)
        # A move without checks would accept exactly the bad support above.
        if s['qh'] != s['hp'] and s['kv'] > 1:
            wrong=pack(s,raw,prefix_bug=True)
            check(wrong != ref)
            check(reference_verdict(s,wrong)=='head_support')
            check(verdict(s,wrong)=='head_support')
            controls.add('prefix_query_axis_shortcut_refused')
        both=copy.deepcopy(owned);both['wq'].pop();both['exp'][0]=0
        check(verdict(s,both)==reference_verdict(s,both)=='weight_shape')
        controls.add('first_error_order_preserved')
        fixtures.append(dict(shape=s, raw=raw, padded=owned, serialized_sha256=hashlib.sha256(encoding(owned)).hexdigest()))
    ledger=accounting()
    check(ledger['public_payload_bytes']==243411456)
    check(ledger['avoided_to_vec_bytes_per_load']==243410944)
    result=dict(status='PASS', run_id='20261019T181854Z-f5bd1f03', seed=SEED, checks=checks,
                fixtures=len(fixtures), rejected_mutations=mutations, controls=sorted(controls),
                wall_seconds=time.perf_counter()-t0, rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                affinity=sorted(os.sched_getaffinity(0)), threads=1,nice=os.nice(0),python=platform.python_version(),
                platform=platform.platform(),cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),
                scope='Synthetic public buffer/layout/check-order and logical payload only. Not native proof equivalence or measured savings.',
                limits='59s wall/CPU,512MiB AS,one nice19 CPU; estimated64MiB; no native/GPU/build')
    for name,value in [('fixtures.json',fixtures),('payload-ledger.json',ledger),('result.json',result)]:
        (HERE/name).write_text(json.dumps(value,indent=2)+'\n')
    print(json.dumps(result,sort_keys=True))


if __name__=='__main__':
    main()
