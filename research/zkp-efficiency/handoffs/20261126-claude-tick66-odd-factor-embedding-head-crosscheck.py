"""Coordinator's cross-check of research tick 66, section 3 (the head's per-row multiplier and the claim grammar).

A port of zkp_core::pcs::zpart_weights, zkey_weights and group_zclaims (ops/zkp-mvp/gpu-metal/zkp-core/src/pcs.rs,
lines 857-951) over the Goldilocks base field, and three toy claims on a small head table W' with per-row multipliers m:

  route 1  one claim, one part per vocabulary row (multiplier outside the words): the grammar refuses it when a
           commitment row holds more than one vocabulary row, because the parts' column ranges differ;
  route 2  one claim per column range (multiplier outside the words): every part of a claim is a vocabulary row at the
           same column offset, coefficient eq(r_j)[j] * m_j, point rho_d. Groups = vocabulary rows per commitment row;
  route 3  the multiplier folded into the committed words (W'' = m W'): one plain claim, one group.

Then the receipt bytes of the three forms at the 8B head (formula of ticks 54, 59 and 61; nothing built or run).
Prints no clock reading and no path. Standard library only."""
import math
import random

P = 2**64 - 2**32 + 1


def eq_table_msb(r):
    t = [1]
    for x in r:
        t = [v * c % P for v in t for c in ((1 - x) % P, x % P)]
    return t


def zpart_weights(part, rows, log_cols):
    off, ls, coef, point = part
    n = 1 << log_cols
    row_w = [0] * rows
    assert point and len(point) == ls, 'zk claim: point arity != slice size'
    if ls >= log_cols:
        assert off % n == 0
        lr = ls - log_cols
        r0 = off // n
        for i, e in enumerate(eq_table_msb(point[:lr])):
            row_w[r0 + i] = (row_w[r0 + i] + coef * e) % P
        key = (tuple(point[lr:]), 0, n)
    else:
        r0, c0 = off // n, off % n
        assert c0 + (1 << ls) <= n
        row_w[r0] = (row_w[r0] + coef) % P
        key = (tuple(point), c0, 1 << ls)
    return row_w, key


def zkey_weights(key, log_cols):
    tail, c0, ln = key
    col = [0] * (1 << log_cols)
    col[c0:c0 + ln] = eq_table_msb(list(tail))
    return col


def group_zclaims(claims, rows, log_cols):
    keys, groups = [], []
    for parts in claims:
        rw, key = zpart_weights(parts[0], rows, log_cols)
        for p in parts[1:]:
            rw2, key2 = zpart_weights(p, rows, log_cols)
            assert key2 == key, 'zk claim: parts with different column weights'
            rw = [(a + b) % P for a, b in zip(rw, rw2)]
        if key in keys:
            groups[keys.index(key)][1].append(rw)
        else:
            keys.append(key)
            groups.append((zkey_weights(key, log_cols), [rw]))
    return groups


def value(groups, mat):
    """the sum of every claim's value: sum over rows and columns of row weight * column weight * word"""
    tot = 0
    for col_w, members in groups:
        for rw in members:
            for r, w in enumerate(rw):
                if w:
                    tot = (tot + w * sum(c * x for c, x in zip(col_w, mat[r]))) % P
    return tot


def toy(v, d_pad, log_cols, rnd):
    n = 1 << log_cols
    per = n // d_pad                                   # vocabulary rows in one commitment row
    v_pad = 1 << (v - 1).bit_length()
    ld, lv = d_pad.bit_length() - 1, v_pad.bit_length() - 1
    w = [[rnd.randint(-127, 127) for _ in range(d_pad)] for _ in range(v)]
    m = [rnd.randint(1, 1 << 12) for _ in range(v)]
    r_j = [rnd.randrange(P) for _ in range(lv)]
    rho_d = [rnd.randrange(P) for _ in range(ld)]
    ej, ed = eq_table_msb(r_j), eq_table_msb(rho_d)
    want = sum(ej[j] * m[j] % P * sum(ed[i] * w[j][i] for i in range(d_pad)) for j in range(v)) % P
    rows = v_pad * d_pad // n

    def matrix(fold):
        flat = [0] * (rows * n)
        for j in range(v):
            for i in range(d_pad):
                flat[j * d_pad + i] = (w[j][i] * (m[j] if fold else 1)) % P
        return [flat[r * n:(r + 1) * n] for r in range(rows)]

    part = lambda j: (j * d_pad, ld, ej[j] * m[j] % P, rho_d)
    # route 1: one claim holding every vocabulary row
    try:
        group_zclaims([[part(j) for j in range(v)]], rows, log_cols)
        one_claim = 'accepted'
    except AssertionError as e:
        one_claim = 'refused (%s)' % e
    # route 2: one claim per column range
    claims = [[part(j) for j in range(v) if j % per == c] for c in range(per)]
    g2 = group_zclaims([c for c in claims if c], rows, log_cols)
    ok2 = value(g2, matrix(False)) == want
    # route 3: the multiplier folded into the words, one plain claim on the padded table
    g3 = group_zclaims([[(0, lv + ld, 1, r_j + rho_d)]], rows, log_cols)
    ok3 = value(g3, matrix(True)) == want
    return per, one_claim, len(g2), ok2, len(g3), ok3


print('== 1. toy head claims through a port of the claim grammar (Goldilocks base field)')
rnd = random.Random(20261126)
for v, d_pad, log_cols in [(12, 8, 3), (12, 8, 5), (20, 16, 6), (24, 8, 6), (40, 4, 6)]:
    per, one, n2, ok2, n3, ok3 = toy(v, d_pad, log_cols, rnd)
    print('  V=%d d_pad=%d n=%d: vocabulary rows per commitment row %d; one claim over all rows: %s; by column range: '
          '%d groups, value reproduced: %s; folded: %d group, value reproduced: %s' % (v, d_pad, 1 << log_cols, per, one, n2, ok2, n3, ok3))
    assert ok2 and ok3 and n2 == per and n3 == 1
    assert (one == 'accepted') == (per == 1)

print()
print('== 2. receipt bytes of one head opening at 8B (V = 128,256, d_pad = 4,096), formula level')
n, k, Q = 1 << 16, 16, 172
qpad = k * Q
path = int(math.log2(4 * n))
group = (n + qpad) * 16


def wire(rows, groups):
    return (groups + 1) * group + Q * 8 * rows + Q * (8 + 32 + 32 * path)


per = n // 4096
dense, padded = 128256 * 4096 // n, 131072 * 4096 // n
print('  vocabulary rows per commitment row at n = 2^16: %d; rows dense %s, padded %s; one group = %s B' % (
    per, format(dense, ','), format(padded, ','), format(group, ',')))
a, b, c = wire(dense, 1), wire(padded, 1), wire(dense, per)
print('  multiplier folded into the words, dense, 1 group:   %s B = %.2f MB' % (format(a, ','), a / 1e6))
print('  multiplier folded into the words, padded, 1 group:  %s B = %.2f MB' % (format(b, ','), b / 1e6))
print('  multiplier outside the words, dense, %d groups:     %s B = %.2f MB (+%.2f MB over the folded dense form)' % (
    per, format(c, ','), c / 1e6, (c - a) / 1e6))
print('  the handoff counted this case as up to %s groups, %.2f GB' % (format(dense, ','), dense * group / 1e9))
