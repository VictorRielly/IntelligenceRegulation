"""Source-derived CUDA u64 model, independently checked against exact integers.

No downloaded implementation; gl_reduce/gl_sub mirror pinned native primitives.
All exponent selection is public. This is not a compiled CUDA test.
"""
P = (1 << 64) - (1 << 32) + 1
MASK = (1 << 64) - 1
EPS = (1 << 32) - 1


def reduce_words(lo, hi):
    assert 0 <= lo <= MASK and 0 <= hi <= MASK
    high = hi >> 32
    t = (lo - high) & MASK
    if lo < high:
        t = (t - EPS) & MASK
    t1 = ((hi & EPS) << 32) - (hi & EPS)
    r = (t + t1) & MASK
    if r < t:
        r = (r + EPS) & MASK
    if r >= P:
        r -= P
    return r


def sub(a, b):
    r = (a - b) & MASK
    return (r - EPS) & MASK if a < b else r


def general_mul(a, b):
    z = a * b
    return reduce_words(z & MASK, z >> 64)


def shift_mul(a, exponent):
    """Multiply canonical a by 2^e, 0<=e<192, using <=three u64 limbs.

    2^96=-1, 2^128=-2^32 modulo P. After sign reduction e<96,
    the high limb is <2^32, so its <<32 is an exact canonical u64.
    No shift by 64, truncated 192-bit integer, multiplication or % in body.
    """
    assert 0 <= a < P and 0 <= exponent < 192
    negative = exponent >= 96
    e = exponent - 96 if negative else exponent
    if e == 0:
        r = a
    elif e < 64:
        r = reduce_words((a << e) & MASK, a >> (64 - e))
    else:
        s = e - 64
        mid = (a << s) & MASK
        high = a >> (64 - s) if s else 0
        r = sub(reduce_words(0, mid), high << 32)
    return P - r if negative and r else r


def root(log):
    assert 0 <= log <= 32
    # Matches Fp::two_adic_root, checked against direct generator exponent.
    r32 = pow(7, (P - 1) >> 32, P)
    return pow(r32, 1 << (32 - log), P)


POWER2 = {pow(2, e, P): e for e in range(192)}
assert len(POWER2) == 192


def candidate_mul(a, w, counters=None):
    exponent = POWER2.get(w)
    if counters is not None:
        key = 'fallback_mul' if exponent is None else 'identity' if exponent == 0 else 'shift_mul'
        counters[key] = counters.get(key, 0) + 1
    return general_mul(a, w) if exponent is None else shift_mul(a, exponent)


def stage_exponent(st, k, inverse=False):
    """Public metadata plan for the pinned generator7 roots; no hash lookup.

    root64=2^39. For st>6 only k divisible by 2^(st-6) qualifies.
    The fallback keeps the supplied native twiddle and current general mul.
    """
    assert 1 <= st <= 32 and 0 <= k < 1 << (st-1)
    if st <= 6:
        e = 39 * (k << (6-st)) % 192
    else:
        step = 1 << (st-6)
        if k & (step-1):
            return None
        e = 39 * (k >> (st-6)) % 192
    return (-e) % 192 if inverse else e


def stage_mul(a, w, st, k, inverse=False, counters=None):
    e = stage_exponent(st,k,inverse)
    if counters is not None:
        key = 'fallback_mul' if e is None else 'identity' if e == 0 else 'shift_mul'
        counters[key] = counters.get(key,0)+1
    return general_mul(a,w) if e is None else shift_mul(a,e)
