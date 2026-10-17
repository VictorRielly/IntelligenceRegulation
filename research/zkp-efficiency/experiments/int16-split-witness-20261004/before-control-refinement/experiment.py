#!/usr/bin/env python3
"""Synthetic exact-integer oracle; no dependencies, native builds or secrets."""
import hashlib
import json
import os
from pathlib import Path
import random
import resource
import signal
import struct
import sys
import time

RUN = "20261004T040146Z-c6dec297"
SEED = 2026100422
ROOT = Path(__file__).resolve().parent
PROJECT = Path('/home/victor/IntelligenceRegulation')
I32 = (-(1 << 31), (1 << 31) - 1)
I64 = (-(1 << 63), (1 << 63) - 1)
I16 = (-32768, 32767)


def checked(v, bounds):
    assert bounds[0] <= v <= bounds[1], (v, bounds)
    return v


def split(v):
    checked(v, I16)
    # Center the low unsigned byte. Unlike signed-low-plus-carry, the high
    # byte is always int8 even at +32767. The offset is corrected after GEMM.
    return (v & 255) - 128, v >> 8


def reference_dot(x, w):
    # Independently checked direct integer accumulation, kernel lib.rs style.
    acc = 0
    for a, b in zip(x, w):
        acc = checked(acc + checked(a * b, I64), I64)
    return acc


def split_dot(x, w):
    lo = hi = sw = 0
    for a, b in zip(x, w):
        l, h = split(a)
        lo = checked(lo + l * b, I32)
        hi = checked(hi + h * b, I32)
        sw = checked(sw + b, I32)
    # Widen BEFORE multiplying by 256 or adding offset. i32 is insufficient.
    return checked(lo + 256 * hi + 128 * sw, I64), (lo, hi, sw)


def dense_reference(x, weights, mode):
    m, k, n = len(x), len(x[0]), len(weights[0]) if mode == 'in_out' else len(weights)
    out = []
    for row in x:
        dst = []
        for j in range(n):
            col = [weights[i][j] if mode == 'in_out' else weights[j][i] for i in range(k)]
            dst.append(reference_dot(row, col))
        out.append(dst)
    return out


def flat_weights(weights, kp, np, mode):
    n = len(weights[0]); k = len(weights)
    flat = [0] * (kp * np)
    for i in range(k):
        for j in range(n):
            flat[i * np + j if mode == 'in_out' else j * kp + i] = weights[i][j]
    return flat


def padded_candidate(x, m, k, n, mp, kp, np, weights, mode, stacked=False):
    # Model the exact padded-stride seam, not merely a dense transpose.
    # Inputs outside true rows remain at zero, but every K coordinate on a
    # true row participates, as in witness.rs::matmul[_in_out].
    assert len(x) == mp * kp and len(weights) == kp * np
    low = [0] * (m * kp); high = [0] * (m * kp)
    for t in range(m):
        for i in range(kp):
            low[t * kp + i], high[t * kp + i] = split(x[t * kp + i])
    sums = [sum(weights[i * np + j if mode == 'in_out' else j * kp + i]
                for i in range(kp)) for j in range(np)]
    partials = [[0] * (m * np), [0] * (m * np)]
    # stacked=True models one [low;high] GEMM call of shape (2M,K)x(K,N).
    # It does not establish actual device weight reuse or a launch speedup.
    if stacked:
        packed = low + high
        for row in range(2 * m):
            for j in range(np):
                acc = 0
                for i in range(kp):
                    w = weights[i * np + j if mode == 'in_out' else j * kp + i]
                    acc = checked(acc + packed[row * kp + i] * w, I32)
                partials[row // m][(row % m) * np + j] = acc
    else:
        for axis, packed in enumerate((low, high)):
            for t in range(m):
                for j in range(np):
                    acc = 0
                    for i in range(kp):
                        w = weights[i * np + j if mode == 'in_out' else j * kp + i]
                        acc = checked(acc + packed[t * kp + i] * w, I32)
                    partials[axis][t * np + j] = acc
    out = [0] * (mp * np)
    for t in range(m):
        for j in range(np):
            q = t * np + j
            out[q] = checked(partials[0][q] + 256 * partials[1][q] + 128 * sums[j], I64)
    return out


def quant_ref(acc, shift):
    # Independent quotient/remainder reference with floor division.
    bias = 0 if shift == 0 else 2 ** (shift - 1)
    q = (acc + bias) // (2 ** shift)
    rem = acc - q * 2 ** shift
    return q, rem + bias


def quant_candidate(acc, shift):
    half = 0 if shift == 0 else 1 << (shift - 1)
    q = (acc + half) >> shift
    return q, acc - (q << shift) + half


def suffix_ref(g, up, act, wd, x1, shift=6):
    # Already-computed gate/up accumulator interface; norm/attention excluded.
    # Kernel order: gate class, up class, activation, product, down, residual.
    gp = [[quant_ref(v, 7) for v in row] for row in g]
    if any(not -128 <= q <= 127 for row in gp for q, rem in row):
        return {'refusal': 'FFN gate'}
    if any(not -32768 <= v <= 32767 for row in up for v in row):
        return {'refusal': 'FFN up'}
    hp = [[quant_ref(act[q + 128] * u, 14) for (q, _), u in zip(gr, ur)]
          for gr, ur in zip(gp, up)]
    if any(not -32768 <= q <= 32767 for row in hp for q, rem in row):
        return {'refusal': 'FFN product'}
    h = [[q for q, rem in row] for row in hp]
    zacc = dense_reference(h, wd, 'in_out')
    zp = [[quant_ref(v, shift) for v in row] for row in zacc]
    if any(not -32768 <= q <= 32767 for row in zp for q, rem in row):
        return {'refusal': 'FFN down'}
    result = [[a + q for a, (q, _) in zip(xr, zr)] for xr, zr in zip(x1, zp)]
    if any(not -32768 <= v <= 32767 for row in result for v in row):
        return {'refusal': 'residual 2'}
    return {'g': gp, 'up': up, 'h': hp, 'zacc': zacc, 'z': zp, 'x2': result}


def suffix_candidate(g, up, act, wd, x1, shift=6):
    # Separate implementation of ordered site checks on padded flat planes.
    m, k, n = len(g), len(g[0]), len(x1[0])
    mp, kp, np = 1 << (m - 1).bit_length(), 1 << (k - 1).bit_length(), 1 << (n - 1).bit_length()
    gp = []
    for row in g:
        rr = []
        for v in row:
            q, r = quant_candidate(v, 7)
            if q < -128 or q > 127:
                return {'refusal': 'FFN gate'}
            rr.append((q, r))
        gp.append(rr)
    for row in up:
        for v in row:
            if v < -32768 or v > 32767:
                return {'refusal': 'FFN up'}
    hp = []; flat = [0] * (mp * kp)
    for t in range(m):
        rr = []
        for i in range(k):
            q, r = quant_candidate(act[gp[t][i][0] + 128] * up[t][i], 14)
            if q < -32768 or q > 32767:
                return {'refusal': 'FFN product'}
            rr.append((q, r)); flat[t * kp + i] = q
        hp.append(rr)
    zflat = padded_candidate(flat, m, k, n, mp, kp, np, flat_weights(wd, kp, np, 'in_out'), 'in_out', True)
    zacc = [[zflat[t * np + j] for j in range(n)] for t in range(m)]
    zp = []
    for row in zacc:
        rr = []
        for v in row:
            q, r = quant_candidate(v, shift)
            if q < -32768 or q > 32767:
                return {'refusal': 'FFN down'}
            rr.append((q, r))
        zp.append(rr)
    result = []
    for xr, zr in zip(x1, zp):
        rr = []
        for a, (q, _) in zip(xr, zr):
            v = a + q
            if v < -32768 or v > 32767:
                return {'refusal': 'residual 2'}
            rr.append(v)
        result.append(rr)
    return {'g': gp, 'up': up, 'h': hp, 'zacc': zacc, 'z': zp, 'x2': result}


def main():
    resource.setrlimit(resource.RLIMIT_AS, (512 << 20, 512 << 20))
    signal.alarm(59)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    os.nice(10)
    started = time.monotonic(); rng = random.Random(SEED)
    digest = hashlib.sha256(); controls = []; totals = {}
    def negative(name, expected, wrong):
        assert expected != wrong, name
        controls.append({'name': name, 'expected': expected, 'wrong': wrong})
    scalar_cases = 0
    for v in range(-32768, 32768):
        lo, hi = split(v)
        assert -128 <= lo <= 127 and -128 <= hi <= 127
        # Also independently decode two's-complement bytes.
        raw = struct.pack('<h', v)
        assert lo == raw[0] - 128 and hi == struct.unpack('b', raw[1:])[0]
        for w in (-128, -127, -1, 0, 1, 127):
            assert lo * w + 256 * hi * w + 128 * w == v * w
            scalar_cases += 1
        digest.update(struct.pack('<hbb', v, lo, hi))
    totals['full_i16_values'] = 65536; totals['scalar_products'] = scalar_cases
    dot_cases = dot_terms = 0
    for k in (1, 3, 17, 257, 1024, 14336, 16384):
        for v, w in ((-32768, -128), (32767, 127), (-32768, 127), (32767, -128), (0, 127)):
            x = [v] * k; ww = [w] * k
            actual, parts = split_dot(x, ww); assert actual == reference_dot(x, ww)
            assert max(abs(parts[0]), abs(parts[1])) <= k * 16384
            assert abs(actual) <= k * (1 << 22)
            digest.update(struct.pack('<qiii', actual, *parts))
            dot_cases += 1; dot_terms += k
        x = [rng.randint(*I16) for _ in range(k)]; ww = [rng.randint(-128, 127) for _ in range(k)]
        actual, parts = split_dot(x, ww); assert actual == reference_dot(x, ww)
        digest.update(struct.pack('<qiii', actual, *parts)); dot_cases += 1; dot_terms += k
    totals.update(dot_cases=dot_cases, dot_terms=dot_terms)
    matrix_cases = matrix_outputs = 0
    dims = [(1, 1, 1), (3, 3, 3), (7, 17, 7), (3, 31, 5), (2, 64, 3), (1, 257, 2)]
    for m, k, n in dims:
        mp, kp, np = 1 << m.bit_length(), 1 << k.bit_length(), 1 << n.bit_length()
        for style in ('random', 'extreme', 'zero'):
            xx = [[rng.randint(*I16) if style == 'random' else (I16[(i + t) % 2] if style == 'extreme' else 0)
                   for i in range(k)] for t in range(m)]
            ww = [[rng.randint(-128, 127) for j in range(n)] for i in range(k)]
            flat = [0] * (mp * kp)
            for t in range(m): flat[t * kp:t * kp + k] = xx[t]
            ref = dense_reference(xx, ww, 'in_out')
            outref = [0] * (mp * np)
            for t in range(m): outref[t * np:t * np + n] = ref[t]
            wt = [list(col) for col in zip(*ww)]
            assert ref == dense_reference(xx, wt, 'out_in')
            for mode in ('in_out', 'out_in'):
                wf = flat_weights(ww, kp, np, mode)
                for stacked in (False, True):
                    out = padded_candidate(flat, m, k, n, mp, kp, np, wf, mode, stacked)
                    assert out == outref
                    for v in out: digest.update(struct.pack('<q', v))
                    matrix_cases += 1; matrix_outputs += len(out)
    # Helper equivalence must preserve a supplied nonzero internal coordinate.
    dirty = [1, 2, 3, 99]; dirty_w = [1, 2, 3, 7]
    assert padded_candidate(dirty, 1, 3, 1, 1, 4, 1, dirty_w, 'in_out') == [reference_dot(dirty, dirty_w)]
    negative('skip supplied internal K coordinate', reference_dot(dirty, dirty_w), reference_dot(dirty[:3], dirty_w[:3]))
    totals.update(matrix_cases=matrix_cases, matrix_output_words=matrix_outputs)
    quant_cases = 0
    for shift in (0, 1, 6, 7, 14, 31):
        half = 0 if shift == 0 else 1 << (shift - 1)
        values = [rng.randint(-(1 << 36), 1 << 36) for _ in range(1000)]
        for q in (-32769, -32768, -128, -1, 0, 1, 127, 32767, 32768):
            values.extend((q * (1 << shift) - half + d) for d in (-1, 0, 1))
        for v in values:
            a = quant_ref(v, shift); b = quant_candidate(v, shift)
            assert a == b and 0 <= a[1] < (1 << shift)
            digest.update(struct.pack('<qqq', v, *a)); quant_cases += 1
    totals['quant_cases'] = quant_cases
    suffix_cases = 0; outcomes = {}
    for idx in range(100):
        m, k, n = rng.choice((1, 3, 7)), rng.choice((1, 3, 7)), rng.choice((1, 3, 5))
        g = [[rng.randint(-16384, 16383) for _ in range(k)] for _ in range(m)]
        up = [[rng.randint(*I16) for _ in range(k)] for _ in range(m)]
        act = [rng.randint(-16000, 16000) for _ in range(256)]
        wd = [[rng.randint(-8, 8) for _ in range(n)] for _ in range(k)]
        x1 = [[rng.randint(-16000, 16000) for _ in range(n)] for _ in range(m)]
        a = suffix_ref(g, up, act, wd, x1); b = suffix_candidate(g, up, act, wd, x1)
        assert a == b
        label = a.get('refusal', 'accepted'); outcomes[label] = outcomes.get(label, 0) + 1
        digest.update(json.dumps(a, sort_keys=True).encode()); suffix_cases += 1
    # First-refusal precedence, inclusive -128 gate, -32768 up/product.
    fixtures = [
        ('FFN gate', [[16384]], [[32768]], [32767]*256, [[127]], [[32767]]),
        ('FFN up', [[0]], [[32768]], [32767]*256, [[127]], [[32767]]),
        ('FFN product', [[0]], [[32767]], [32767]*256, [[127]], [[32767]]),
        ('FFN down', [[0]], [[32767]], [16384]*256, [[127]], [[32767]]),
        ('residual 2', [[0]], [[4096]], [16384]*256, [[1]], [[32767]]),
        ('accepted', [[-16384]], [[-32768]], [16384]*256, [[0]], [[-32768]]),
    ]
    for label, g, u, a, wd, x1 in fixtures:
        ref = suffix_ref(g, u, a, wd, x1); cand = suffix_candidate(g, u, a, wd, x1)
        assert ref == cand and ref.get('refusal', 'accepted') == label
        outcomes[label] = outcomes.get(label, 0) + 1; suffix_cases += 1
        digest.update(json.dumps(ref, sort_keys=True).encode())
    totals.update(suffix_cases=suffix_cases, suffix_outcomes=outcomes)
    # Decisive bad ports: all have concrete public synthetic counterexamples.
    v, w = 0, 1; lo, hi = split(v)
    negative('omit +128 weight-column-sum correction', v*w, lo*w + 256*hi*w)
    v = -1; lo, hi = split(v)
    negative('logical high-byte shift', v, lo + 256*((v & 65535) >> 8) + 128)
    negative('reinterpret low byte as int8 without carry repair', v, -1 + 256*hi + 128)
    v = 32767; high_with_carry = (v + 128) >> 8
    negative('signed-low carry high byte fits int8 at +32767', True, -128 <= high_with_carry <= 127)
    exact, parts = split_dot([32767]*1024, [127]*1024)
    wrapped = (exact + (1 << 31)) % (1 << 32) - (1 << 31)
    negative('i32 reconstruction wraps full accumulator', exact, wrapped)
    negative('round per term before accumulation', quant_ref(64, 6)[0], quant_ref(32, 6)[0] + quant_ref(32, 6)[0])
    negative('truncate signed requant toward zero', quant_ref(-97, 6)[0], int((-97 + 32) / 64))
    negative('ties away from zero', quant_ref(-32, 6)[0], -1)
    negative('stale cached weight sum after model change', 0, -128*2 + 128*1)
    negative('pack padded token as low zero but apply correction', 0, 128*3)
    negative('wrong weight orientation', dense_reference([[1,2]], [[3,4],[5,6]], 'in_out'),
             dense_reference([[1,2]], [[3,4],[5,6]], 'out_in'))
    negative('exclude gate -128', True, -127 <= -128 <= 127)
    negative('exclude int16 -32768', True, -32767 <= -32768 <= 32767)
    # i32 partial bound for future large K: exact and conservative at K=2^17.
    negative('assume i32 partial safe at K=131072', True, 131072*16384 <= I32[1])
    invalid = []
    for value in (-32769, 32768):
        try: split(value)
        except AssertionError: invalid.append(value)
        else: raise AssertionError('invalid int16 accepted')
    totals['domain_controls'] = invalid
    result = dict(run_identity=RUN, seed=SEED, status='pass', **totals,
                  digest=digest.hexdigest(), controls=controls, control_count=len(controls),
                  max_profile_k=16384, signed_byte_partial_abs_bound=1 << 28,
                  int16_full_dot_abs_bound=1 << 36, weight_sum_abs_bound=1 << 21,
                  elapsed_s=time.monotonic()-started, peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                  threads=1, affinity=sorted(os.sched_getaffinity(0)), device='CPU only',
                  python=sys.version.split()[0], estimated_memory_mib=64,
                  RLIMIT_AS_mib=512, alarm_s=59,
                  script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  scope='Synthetic exact split-int16 witness arithmetic, stacked/two-call scheduling, padding, quantization and ordered FFN suffix; no native/CUDA/proof/secret data',
                  actual_gpu_speedup=None, actual_end_to_end_saved_s=None,
                  full_stack=dict(countable_tokens=0, passes=0, context_length=None,
                                  steady_tokens_per_s=None, total_tokens_per_s=None, startup_fraction=None,
                                  witness_s=None, proof_s=None, serialization_s=None, verification_s=None,
                                  proof_latency_s=None, proof_lag_s=None, pipeline_drain_s=None))
    result['cpu'] = next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')), 'unknown')
    (ROOT/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: result[k] for k in ('status','scalar_products','dot_cases','dot_terms','matrix_cases','matrix_output_words','quant_cases','suffix_cases','suffix_outcomes','control_count','elapsed_s','peak_rss_kib','digest')}, indent=2))


if __name__ == '__main__':
    main()
