"""Locally authored fixed-width model; no CUDA execution or external code."""
P = 0xFFFFFFFF00000001
U64 = (1 << 64) - 1
U32 = (1 << 32) - 1
EPS = (1 << 32) - 1
D27 = (1 << 27) - 1


def reduce128(lo, hi):
    """Port of pinned native reducer, with every u64 wrap explicit."""
    hi_lo, hi_hi = hi & EPS, hi >> 32
    t = (lo - hi_hi) & U64
    if lo < hi_hi:
        t = (t - EPS) & U64
    t1 = ((hi_lo << 32) - hi_lo) & U64
    r = (t + t1) & U64
    if r < t:
        r = (r + EPS) & U64
    if r >= P:
        r -= P
    return r


def add(a, b):
    s = (a + b) & U64
    if s < a:
        s = (s + EPS) & U64
    elif s >= P:
        s -= P
    return s


def warp(values, mask=U32, canonical=True):
    """32 physical lanes, same membermask at three modeled redux operations.

    The proposed CUDA helper uses FULL mask only and zero-valued padding.
    Arbitrary masks are additional arithmetic tests, not a CUDA convergence test.
    canonical=False is representation/reducer testing, not field admission.
    """
    if len(values) != 32 or not isinstance(mask, int) or not 0 < mask <= U32:
        raise ValueError("physical warp/membermask")
    ceiling = P if canonical else 1 << 64
    if any(type(x) is not int or not 0 <= x < ceiling for x in values):
        raise ValueError("noncanonical operand" if canonical else "u64 operand")
    sums = [0, 0, 0]
    for lane, x in enumerate(values):
        if (mask >> lane) & 1:
            for d, v in enumerate((x & D27, (x >> 27) & D27, x >> 54)):
                sums[d] = (sums[d] + v) & U32
    # s0 + 2^27*s1 fits in 60 bits. The final add may carry once.
    low = sums[0] + (sums[1] << 27)
    upper = (sums[2] << 54) & U64
    out_low = (low + upper) & U64
    high = (sums[2] >> 10) + int(out_low < low)
    return reduce128(out_low, high), (sums, out_low, high)


def block(rows):
    """Tail-only scg_emit projection: a power-of-two CTA, one or more Fp2s.

    Each warp leader stores its canonical sums, then a CTA barrier separates
    producers from warp0's consumers. Warp0 pads missing warps with zeros.
    Thread-local polynomial accumulation is deliberately unchanged.
    """
    t = len(rows)
    if t not in (32, 64, 128, 256, 512, 1024):
        raise ValueError("CTA shape")
    nv = len(rows[0])
    if not 1 <= nv <= 6 or any(len(row) != nv for row in rows):
        raise ValueError("evaluation shape")
    if any(len(v) != 2 for row in rows for v in row):
        raise ValueError("Fp2 shape")
    shared = []
    for first in range(0, t, 32):
        shared.append([
            tuple(warp([rows[i][d][c] for i in range(first, first + 32)])[0]
                  for c in (0, 1)) for d in range(nv)
        ])
    out = []
    for d in range(nv):
        out.append(tuple(warp([shared[i][d][c] if i < len(shared) else 0
                               for i in range(32)])[0] for c in (0, 1)))
    return out


def baseline_tree(rows):
    """Pinned native scg_emit order and canonical add, CPU projection only."""
    red = [[list(x) for x in row] for row in rows]
    stride = len(rows) // 2
    while stride:
        for i in range(stride):
            for d in range(len(red[i])):
                for c in (0, 1):
                    red[i][d][c] = add(red[i][d][c], red[i + stride][d][c])
        stride //= 2
    return [tuple(x) for x in red[0]]


def counts(threads, nv):
    if threads not in (32, 64, 128, 256, 512, 1024) or not 1 <= nv <= 6:
        raise ValueError("shape")
    warps = threads // 32
    limbs = 2 * nv
    return dict(threads=threads, nv=nv,
                baseline_shared_bytes=threads * limbs * 8,
                candidate_shared_bytes=warps * limbs * 8,
                baseline_cta_barriers=1 + (threads.bit_length() - 1),
                candidate_cta_barriers=1,
                baseline_modular_adds=(threads - 1) * limbs,
                candidate_canonical_reductions=(warps + 1) * limbs,
                candidate_warp_redux_instructions=3 * (warps + 1) * limbs,
                baseline_shared_scalar_accesses=(4 * threads - 2) * limbs,
                candidate_shared_scalar_accesses=2 * warps * limbs,
                removed_polynomial_products=0, removed_global_bytes=0,
                removed_fresh_masks=0, removed_launches=0)
