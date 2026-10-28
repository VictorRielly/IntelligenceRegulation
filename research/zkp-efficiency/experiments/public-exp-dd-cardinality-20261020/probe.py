#!/usr/bin/env python3
"""Public LUT census and synthetic integer DD oracle; never a private proof."""
import hashlib
import json
import math
import os
from pathlib import Path
import random
import resource
import signal
import struct
import time

HERE = Path(__file__).resolve().parent
ROOT = Path('/home/victor/IntelligenceRegulation')
SEED = 20261020112

def limits():
    resource.setrlimit(resource.RLIMIT_AS, (512 << 20, 512 << 20))
    resource.setrlimit(resource.RLIMIT_CPU, (59, 59))
    signal.alarm(59)
    os.nice(19)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})

def table(hd, es, fe, bits=8):
    # Same evaluation order as tables_attn.rs. bits>8 is a proposal, not native.
    lam = (2.0 ** es) / math.sqrt(hd)
    return [math.floor((2.0 ** fe) * math.exp(-d * lam) + 0.5)
            for d in range(1 << bits)]

def dd_column(values, cap):
    col = sorted({0, *values})
    if len(col) > cap:
        raise ValueError('D30/B-8: public table exceeds cap')
    return col + [0] * (cap - len(col))

def dd_row(values, col, fp):
    total = sum(values)
    if total <= 0:
        raise ValueError('Sum must be positive')
    by_e = {}
    for e in col:
        q = (e * (1 << fp)) // total
        rem = e * (1 << fp) - q * total
        by_e[e] = (q, rem, total - 1 - rem)
    return [by_e[e] for e in values]

def run():
    limits()
    start = time.perf_counter()
    rng = random.Random(SEED)
    checks = 0
    def check(ok):
        nonlocal checks
        checks += 1
        assert ok
    sweep = []
    for hd in (32, 64, 128):
        for es in range(-8, 9):
            for fe in range(9, 17):
                t = table(hd, es, fe)
                n = len({0, *t})
                check(t[0] == 1 << fe)
                check(all(a >= b for a, b in zip(t, t[1:])))
                check(0 <= min(t) <= max(t) <= 1 << fe)
                sweep.append(dict(head_dim=hd, base_e_s=es, f_e=fe, bits=8,
                                  n_col=n, fits32=n <= 32))
    # Same real score range, sixteen times finer input grid for S12.
    cases = []
    for hd in (64, 128):
        for es in range(0, 5):
            for bits in (8, 10, 12):
                for fe in (9, 12, 16):
                    actual_es = es - (bits - 8)
                    t = table(hd, actual_es, fe, bits)
                    n = len({0, *t})
                    cap = 1 << (n - 1).bit_length()
                    check(n <= min((1 << bits) + 1, (1 << fe) + 1))
                    if bits > 8:
                        coarse = table(hd, es, fe)
                        check(t[::(1 << (bits - 8))] == coarse)
                    cases.append(dict(head_dim=hd, base_e_s=es,
                                      actual_e_s=actual_es, f_e=fe,
                                      bits=bits, n_col=n, cap_pow2=cap,
                                      zero_in_table=0 in t,
                                      table_sha256=hashlib.sha256(
                                          struct.pack('<%dq' % len(t), *t)).hexdigest()))
    # Read only public exp arrays, never weights/activations/token records.
    ledger = json.loads((ROOT / 'results/zk60_1b_native_20261017/r9/r9_ncol.json').read_text())
    exports = []
    for rec in ledger['exports']:
        directory = Path(rec['export'])
        layers = []
        profile = json.loads((directory / 'profile.json').read_text())
        hd = profile.get('head_dim', profile.get('shape', {}).get('head_dim'))
        for i, expected in enumerate(rec['n_col_per_layer']):
            ld = directory / ('layer_%02d' % i)
            m = json.loads((ld / 'manifest.json').read_text())
            arr = m['arrays']['exp']
            p = ld / arr['file']
            b = p.read_bytes()
            vals = list(struct.unpack('<%dq' % (len(b)//8), b))
            check(len(vals) == 256)
            check(len({0, *vals}) == expected)
            constants = m['constants']
            # Head dimension is public; infer only if owner profile omits it.
            hdim = hd or constants.get('head_dim')
            if hdim is None:
                hdim = 128 if '8b' in str(directory).lower() else 64
            generated = table(hdim, constants['exp_e_s'], constants['f_e'])
            check(vals == generated)
            layers.append(dict(layer=i, head_dim=hdim,
                               e_s=constants['exp_e_s'], f_e=constants['f_e'],
                               n_col=expected, public_exp_path=str(p),
                               sha256=hashlib.sha256(b).hexdigest()))
        exports.append(dict(export=str(directory), layers=layers))
    # Direct independently calculated quotient/remainders against dictionary use.
    rows = 0
    for c in cases:
        t = table(c['head_dim'], c['actual_e_s'], c['f_e'], c['bits'])
        col = dd_column(t, c['cap_pow2'])
        check(len(col) == c['cap_pow2'])
        check(len(set(col)) == c['n_col'])
        for T in (32, 128, 512):
            # At least one max exp; masked entries explicitly zero.
            values = [t[0]] + [0 if j % 7 == 0 else t[rng.randrange(len(t))]
                               for j in range(1, T)]
            for fp in (9, 12, 15, 16):
                got = dd_row(values, col, fp)
                total = sum(values)
                for e, actual in zip(values, got):
                    q, rem = divmod(e << fp, total)
                    check(actual == (q, rem, total - 1 - rem))
                    check((0 <= q <= 1 << fp) and 0 <= rem < total)
                rows += 1
    controls = []
    def reject(name, fn):
        try:
            fn()
        except (ValueError, KeyError, AssertionError):
            controls.append(name)
        else:
            raise AssertionError('negative control accepted: '+name)
    reject('33_public_outputs', lambda: dd_column(range(33), 32))
    t = table(128, 1, 9)
    check(len({0, *t}) == 32)  # native R9 boundary test
    check(len({0, *table(128, -3, 9, 12)}) == 248)
    reject('S12_keeps_cap32', lambda: dd_column(table(128, -3, 9, 12), 32))
    pos = table(128, -8, 9)
    check(0 not in pos)
    reject('omits_masked_zero', lambda: dd_row([pos[0], 0], sorted(set(pos)), 9))
    reject('zero_sum', lambda: dd_row([0, 0], [0], 9))
    reject('round_cap_down', lambda: dd_column(table(128, -2, 9, 12), 128))
    # Same quotient does NOT mean same tuple: e remains part of the lookup.
    vals = [512, 1, 2] + [512] * 128
    got = dd_row(vals, [0, 1, 2, 512], 9)
    check(got[1][0] == got[2][0] and got[1][1] != got[2][1])
    reject('merge_equal_quotients', lambda: check(got[1] == got[2]))
    reject('forget_S12_e_s_shift', lambda: check(
        table(128, 2, 9, 12) == table(128, -2, 9, 12)))
    out = dict(status='PASS', seed=SEED, checks=checks,
               sweep=sweep, cases=cases, public_exports=exports,
               synthetic_row_cases=rows, negative_controls=controls,
               elapsed_s=time.perf_counter()-start,
               maxrss_KiB=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
               scope='Public LUT and synthetic exact integer arithmetic; zero proofs',
               limits=dict(threads=1, CPU_s=59, alarm_s=59,
                           parent_wall_s=60, address_space_MiB=512, estimate_MiB=64))
    (HERE/'result.json').write_text(json.dumps(out, indent=2)+'\n')
    print(json.dumps({k:v for k,v in out.items() if k not in ('sweep','cases','public_exports')}))

if __name__ == '__main__':
    run()
