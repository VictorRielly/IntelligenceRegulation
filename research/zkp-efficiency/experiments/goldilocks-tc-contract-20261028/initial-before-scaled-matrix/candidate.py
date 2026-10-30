"""Research-authored word models; no downloaded implementation executed.

General multiplier equations derive from inspected modular.cuh. Lazy butterfly
is a deliberately out-of-contract control. Byte-dot reduction is our candidate
contract for a future reducer, not the repository's friendly PTX reducer.
"""
P = 0xFFFFFFFF00000001
R = 1 << 64
M = R - 1
E = (1 << 32) - 1


def inverse_word(n):
    x = ((n * 3) ^ 2) & 0xFFFFFFFF
    d = (x * n) & 0xFFFFFFFF
    for _ in range(3):
        t = (2 - d) & 0xFFFFFFFF
        x = (x * t) & 0xFFFFFFFF
        d = (d * t) & 0xFFFFFFFF
    return (x * (2 - n * x)) & M


def prepare(k, n=P):
    b = k * ((-n) & M) % n
    return b, (b * inverse_word(n)) & M


def fixed_mul(a, params, n=P, wrong_borrow=False):
    b, bp = params
    hi = (a * b) >> 64
    q = (a * bp) & M
    qhi = (q * n) >> 64
    z = (hi - qhi) & M
    if hi < qhi and not wrong_borrow:
        z = (z + n) & M
    return z


def friendly_guard(n, bits=64):
    if n.bit_length() >= 63:
        raise ValueError('modulus needs to be within 62 bits for now')
    if n & 0xFFFFFFFF != 1:
        raise ValueError('modulus needs to be Montgomery friendly')
    if bits != 64 and n >> bits:
        raise ValueError('modulus exceeds the specified bit size')


def lazy_butterfly_bypass(a, b, k, n=P):
    """NOT supported by source: replace multiply but bypass friendly guard."""
    twice = (2 * n) & M
    u = (a + b) & M
    if u >= twice:
        u = (u - twice) & M
    v = (a - b + twice) & M
    return u, fixed_mul(v, prepare(k, n), n)


def gl_add(a, b):
    s = (a + b) & M
    if s < a:
        s = (s + E) & M
    elif s >= P:
        s -= P
    return s


def gl_sub(a, b):
    s = (a - b) & M
    return (s - E) & M if a < b else s


def reduce128(lo, hi):
    t = (lo - (hi >> 32)) & M
    if lo < hi >> 32:
        t = (t - E) & M
    u = ((hi & E) << 32) - (hi & E)
    z = (t + u) & M
    if z < t:
        z = (z + E) & M
    if z >= P:
        z -= P
    return z


def gl_mul(a, b):
    x = a * b
    return reduce128(x & M, x >> 64)


def transform(values, root, inverse=False):
    """Canonical radix2 model with fixed-multiplier twiddles, not Tensor NTT."""
    n = len(values)
    assert n and n & (n - 1) == 0
    log = n.bit_length() - 1
    a = [0] * n
    for i, x in enumerate(values):
        a[int(f'{i:0{log}b}'[::-1], 2) if log else 0] = x
    if inverse:
        root = pow(root, P - 2, P)
    size = 2
    while size <= n:
        w = pow(root, n // size, P)
        params = [prepare(pow(w, j, P)) for j in range(size // 2)]
        for off in range(0, n, size):
            for j in range(size // 2):
                x = a[off + j]
                y = fixed_mul(a[off + j + size // 2], params[j])
                a[off + j] = gl_add(x, y)
                a[off + j + size // 2] = gl_sub(x, y)
        size *= 2
    if inverse:
        scale = prepare(pow(n, P - 2, P))
        a = [fixed_mul(x, scale) for x in a]
    return a


def dot_digits(a, b):
    """Source-derived byte diagonals and overlapping 16-bit t words."""
    assert len(a) == len(b) == 16
    ss = [0] * 15
    for x, y in zip(a, b):
        for i in range(8):
            for j in range(8):
                ss[i + j] += ((x >> (8 * i)) & 255) * ((y >> (8 * j)) & 255)
    assert max(ss) < 1 << 31
    tt = [ss[2 * i] + (ss[2 * i + 1] << 8) for i in range(7)] + [ss[14]]
    assert max(tt) < 1 << 31
    return tt, max(ss), max(tt)


def dot_reduce(tt, truncate=False):
    x = sum(t << (16 * i) for i, t in enumerate(tt))
    # Source word-vector can represent a 132-bit dot16, not merely a u128.
    low = reduce128(x & M, (x >> 64) & M)
    if truncate:
        return low
    # R^2 == -2^32 mod P; preserve every top carry.
    return gl_add(low, gl_mul(x >> 128, P - (1 << 32)))
