#!/usr/bin/env python3
"""Small public R13 block: integer oracle versus the existing fidelity evaluator.

This is a synthetic test fixture, not a trained-model proof or fidelity result.
"""
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import struct
import sys
from types import SimpleNamespace

sys.dont_write_bytecode = True

os.environ['OPENBLAS_NUM_THREADS'] = '1'
os.environ['OMP_NUM_THREADS'] = '1'
ROOT = Path('/home/victor/IntelligenceRegulation')
OUT = Path(__file__).resolve().parent
T, D, F, H, KV, DH = int(os.environ.get('ZK60_REFERENCE_T', '4')), 16, 32, 4, 2, 4
SUFFIX = '' if T == 4 else f'_t{T}'


def rounded(numerator, denominator):
    return (2 * numerator + denominator) // (2 * denominator)


def rq(acc, shift, multiplier=1):
    return rounded(acc * multiplier, 1 << shift)


def matrix(rows, columns, seed):
    return [[(i * 73 + j * 29 + seed) % 31 - 15 for j in range(columns)] for i in range(rows)]


def multiply(x, weights, multipliers, shifts):
    return [[rq(sum(a * b for a, b in zip(row, column)), shifts[j], multipliers[j])
             for j, column in enumerate(zip(*weights))] for row in x]


def exact_norm(x, gain, cn):
    return [[rounded(v * g * cn, max(1, math.isqrt(123 + sum(a * a for a in row))) * 4)
             for v, g in zip(row, gain)] for row in x]


def add(x, y):
    return [[a + b for a, b in zip(rx, ry)] for rx, ry in zip(x, y)]


def rotate(words, heads, cos, sin):
    result = [[0] * (heads * DH) for _ in range(T)]
    for t in range(T):
        for h in range(heads):
            for i in range(DH // 2):
                a, b = words[t][h * DH + i], words[t][h * DH + i + DH // 2]
                result[t][h * DH + i] = rq(a * cos[t][i] - b * sin[t][i], 7)
                result[t][h * DH + i + DH // 2] = rq(b * cos[t][i] + a * sin[t][i], 7)
    return result


def fixture():
    x = [[((t * D + i) * 109 % 61 - 30) * 4 for i in range(D)] for t in range(T)]
    widths = {'q': (D, D), 'k': (D, KV * DH), 'v': (D, KV * DH),
              'o': (D, D), 'g': (D, F), 'u': (D, F), 'd': (F, D)}
    weights = {name: matrix(*shape, j * 11 + 3) for j, (name, shape) in enumerate(widths.items())}
    bits = {'q': 5, 'k': 5, 'v': 6, 'o': 8, 'g': 6, 'u': 4, 'd': 6}
    mult = {name: [(j * 7 + 3) % (1 << bits[name]) + 1 for j in range(len(w[0]))]
            for name, w in weights.items()}
    gamma = [127 - (i % 3) for i in range(D)]
    cos = [[math.floor(128 * math.cos(t * 10000 ** (-2 * i / DH)) + 0.5) for i in range(DH // 2)] for t in range(T)]
    sin = [[math.floor(128 * math.sin(t * 10000 ** (-2 * i / DH)) + 0.5) for i in range(DH // 2)] for t in range(T)]
    exp = [math.floor(512 * math.exp(-j) + 0.5) for j in range(256)]
    members = [(-4, -13), (-1, -11)]
    groups = [j % 2 for j in range(F)]
    tabs = [list(struct.unpack('<4096h', (OUT / f'working-tree/hashline/src/private_block/r13_vectors/silu_{a}_{b}.bin').read_bytes())) for a, b in members]
    return x, weights, bits, mult, gamma, cos, sin, exp, members, groups, tabs


def integer_block(data, h_extra=8):
    x, w, bits, m, gamma, cos, sin, exp, members, groups, tabs = data
    trace = {}
    trace['y'] = exact_norm(x, gamma, 200)
    for name in ('q', 'k', 'v'):
        trace[name] = multiply(trace['y'], w[name], m[name], [8 + 8 - 6 + bits[name]] * len(m[name]))
    trace['qr'] = rotate(trace['q'], H, cos, sin)
    trace['kr'] = rotate(trace['k'], KV, cos, sin)
    scores, probabilities, output = [], [], [[0] * D for _ in range(T)]
    for h in range(H):
        kh = h // (H // KV)
        head_scores, head_p = [], []
        for t in range(T):
            s = [rq(sum(trace['qr'][t][h * DH + i] * trace['kr'][j][kh * DH + i] for i in range(DH)), 18) for j in range(T)]
            maximum = max(s[:t + 1])
            e = [exp[maximum - s[j]] if j <= t else 0 for j in range(T)]
            p = [(v << 12) // sum(e) for v in e]
            head_scores.append(s)
            head_p.append(p)
            for i in range(DH):
                output[t][h * DH + i] = rq(sum(p[j] * trace['v'][j][kh * DH + i] for j in range(T)), 12)
        scores.append(head_scores)
        probabilities.append(head_p)
    trace['s'], trace['p'], trace['o8'] = scores, probabilities, output
    trace['ao'] = multiply(output, w['o'], m['o'], [7 + 6 + 8] * D)
    trace['x1'] = add(x, trace['ao'])
    trace['nm'] = exact_norm(trace['x1'], gamma, 180)
    gate_shifts = [18 + members[g][0] - (-3) for g in groups]
    gate = multiply(trace['nm'], w['g'], m['g'], gate_shifts)
    a = [[tabs[groups[j]][word + 2048] for j, word in enumerate(row)] for row in gate]
    up = multiply(trace['nm'], w['u'], m['u'], [12] * F)
    h = [[rq(a[t][j] * up[t][j], 14 - h_extra - (members[groups[j]][1] - (-11))) for j in range(F)] for t in range(T)]
    z = multiply(h, w['d'], m['d'], [6 + h_extra + 6] * D)
    scaled = [[word * (1 << (24 - 14 + members[groups[j]][1] + 11)) for j, word in enumerate(row)] for row in a]
    trace.update(gate=gate, a_group=a, a_scaled=scaled, u16=up, h16=h, z16=z, x2=add(trace['x1'], z))
    return trace


def crosscheck(data, trace, h_extra=8):
    import numpy as np
    sys.path.insert(0, str(ROOT / 'results/zk60_fidelity_parity_20261019'))
    import fp_lib as fl
    x, w, bits, m, gamma, cos, sin, exp, members, groups, tabs = data
    fl.GEO = SimpleNamespace(H=H, KV=KV, G=H // KV, dh=DH)
    matrices = {name: fl.Mat(np.asarray(words)) for name, words in w.items()}
    model = SimpleNamespace(
        mods=frozenset({'y8', 'fp12', 'a8', 'ah2', 'g4'} | ({'h8'} if h_extra else set())),
        c=dict(norm_cn_a=200, norm_cn_m=180, norm_tn=10, norm_ceps=123,
               wrho=32, f_p=9, f_e=9, f_ro=7, sh_qkv=8, sh_s=6,
               sh_rope=7, sh_o=9, sh_ao=7, sh_g=8, sh_u=0, sh_h=14,
               sh_z=6, e_s=1, silu=(-3, -11)),
        w={'gamma_a': np.asarray(gamma), 'gamma_m': np.asarray(gamma)},
        mult={name: (np.asarray(values), bits[name]) for name, values in m.items()},
        mat=lambda name, exact: matrices[name],
        rope_int=(np.asarray(cos), np.asarray(sin)),
        rope_real=(np.asarray(cos), np.asarray(sin)),
        exp_t=np.asarray(exp), act_t=np.zeros(256), lam=1.0,
        gate_pc=(np.asarray([members[g][0] for g in groups]),
                 np.asarray([members[g][1] for g in groups]), None, False))
    recorder = fl.RecPos(1)
    measured = {}
    fl.rx_block(np.asarray([x], dtype=np.float64), model, frozenset(fl.SITES),
                rec=recorder, trace=measured)
    violations = {name: site['violations'] for name, site in recorder.sites.items() if site['violations']}
    assert not violations, violations
    compared = []
    for name in ('y', 'q', 'k', 'v', 'o8', 'ao', 'x1', 'nm', 'u16', 'h16', 'z16', 'x2'):
        expected = np.asarray(trace[name])
        got = measured[name][0]
        assert np.array_equal(expected, got), (name, expected, got)
        compared.append(name)
    for name in ('s', 'p'):
        assert np.array_equal(np.asarray(trace[name]), measured[name][0].reshape(H, T, T)), name
        compared.append(name)
    common_a = [[word * 2.0 ** (members[groups[j]][1] + 11) for j, word in enumerate(row)]
                for row in trace['a_group']]
    assert np.array_equal(np.asarray(common_a), measured['a16'][0])
    compared.append('a16')
    name = 'low_h24' if h_extra else 'low'
    report = dict(scope='MEASURED n=1 public synthetic small block, not a trained-model proof or fidelity evaluation', stack=name,
                  geometry=dict(tokens=T, width=D, hidden=F, heads=H, kv_heads=KV, head_dim=DH),
                  compared_traces=compared, bit_exact=True, violations=violations,
                  fidelity_evaluator_sha256=hashlib.sha256(Path(fl.__file__).read_bytes()).hexdigest(),
                  output=trace['x2'])
    (OUT / f'block_crosscheck_{name}{SUFFIX}.json').write_text(json.dumps(report, indent=2) + '\n')
    print(name, 'exact integer reference equals fp_lib.rx_block at', len(compared), 'trace sites; no violations.')


if __name__ == '__main__':
    data = fixture()
    keys = ['input', 'weights', 'bits', 'multipliers', 'gamma', 'cos', 'sin', 'exp', 'members', 'groups', 'tables']
    fixture_path = OUT / f'working-tree/hashline/src/private_block/r13_vectors/block_fixture{SUFFIX}.json'
    fixture_path.write_text(json.dumps(dict(zip(keys, data)), indent=2) + '\n')
    for name, extra in [('low', 0), ('low_h24', 8)]:
        trace = integer_block(data, extra)
        path = OUT / f'working-tree/hashline/src/private_block/r13_vectors/block_trace_{name}{SUFFIX}.json'
        path.write_text(json.dumps({'geometry': [T, D, F, H, KV, DH], 'trace': trace}, indent=2) + '\n')
        crosscheck(data, trace, extra)
