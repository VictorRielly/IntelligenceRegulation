import hashlib, json, os, platform, random, time
from pathlib import Path
import candidate as C
import reference as R

E = Path(__file__).resolve().parent
SEED = 20261030167
rng = random.Random(SEED)
checks = 0
negatives = []
started = time.monotonic()


def check(ok, msg):
    global checks
    checks += 1
    if not ok:
        raise AssertionError(msg)


def reject(call, label):
    try:
        call()
    except ValueError:
        negatives.append(label)
    else:
        raise AssertionError('accepted ' + label)


def different(got, ref, label):
    check(got != ref, label)
    negatives.append(label)


patterns = [0, 1, C.P - 1, (1 << 27) - 1, 1 << 27,
            (1 << 32) - 1, 1 << 32, (1 << 54) - 1, 1 << 54, C.P - 2]
masks = [C.U32, 1, 1 << 31, 0xAAAAAAAA, 0x55555555, 0x80000001]
masks += [(1 << n) - 1 for n in range(1, 33)]
warp_cases = 0
saved_warps = []
for i in range(270):
    if i < len(patterns):
        values = [patterns[i]] * 32
    elif i < 2 * len(patterns):
        values = [patterns[(j + i) % len(patterns)] for j in range(32)]
    else:
        values = [rng.randrange(C.P) for _ in range(32)]
    for mask in masks + [rng.randrange(1, 1 << 32)]:
        got, (digits, lo, hi) = C.warp(values, mask)
        selected = [x for j, x in enumerate(values) if mask & (1 << j)]
        check(got == R.warp_sum(values, mask), 'warp oracle')
        check(lo + (hi << 64) == sum(selected), 'whole carry reconstruction')
        check(0 <= hi <= 31, 'carry bound')
        check(all(s < 1 << 32 for s in digits), 'digit bound')
        check(0 <= got < C.P, 'canonical output')
        warp_cases += 1
    if i in (2, 10, 31, 269):
        saved_warps.append(dict(values=values, mask=C.U32,
                                expected=R.warp_sum(values, C.U32)))

# Raw u64 handling is a reducer test only; native API requires canonical inputs.
for raw in (C.P, C.P + 1, C.U64):
    values = [raw] * 32
    check(C.warp(values, canonical=False)[0] == sum(values) % C.P, 'raw reducer')
    reject(lambda: C.warp(values), 'noncanonical-' + str(raw))

saved_blocks, block_cases = [], 0
for threads in (32, 64, 128, 256, 512, 1024):
    for nv in (1, 3, 5, 6):
        for pattern in range(4):
            def value(t, d, c):
                if pattern == 0:
                    return C.P - 1
                if pattern == 1:
                    return patterns[(t + 3*d + c) % len(patterns)]
                if pattern == 2:
                    return (t + 1) if c == 1 else 0
                return rng.randrange(C.P)
            rows = [[tuple(value(t, d, c) for c in (0, 1))
                     for d in range(nv)] for t in range(threads)]
            expected = R.component_sums(rows)
            actual = C.block(rows)
            check(actual == expected, 'block bigint')
            check(C.baseline_tree(rows) == expected, 'native tree projection')
            check(all(0 <= x < C.P for pair in actual for x in pair), 'block canonical')
            block_cases += 1
            if (threads, nv, pattern) in ((32, 1, 0), (128, 5, 3), (1024, 3, 1)):
                saved_blocks.append(dict(threads=threads, nv=nv, pattern=pattern,
                                         rows=rows, expected=expected))

# Fp2 operations independently evaluated by the oracle with Python big integers.
def mul(a, b):
    ac, bd = a[0]*b[0], a[1]*b[1]
    ad, bc = a[0]*b[1], a[1]*b[0]
    gl = lambda x: C.reduce128(x & C.U64, x >> 64)
    return C.add(gl(ac), gl(gl(bd)*7)), C.add(gl(ad), gl(bc))


def plus(a, b):
    return C.add(a[0], b[0]), C.add(a[1], b[1])


def minus(a, b):
    # Exact native gl_sub, with explicit unsigned wrap.
    def sub(x, y):
        z = (x - y) & C.U64
        return (z - C.EPS) & C.U64 if x < y else z
    return sub(a[0], b[0]), sub(a[1], b[1])


polynomial_cases, saved_poly = 0, []
for degree in (2, 3, 4, 5):
    for half in (1, 17, 31, 32, 33, 127, 128, 257, 1025):
        threads = 128 if half <= 128 else 256
        tables = [[tuple(rng.randrange(C.P) for _ in (0, 1))
                   for _ in range(2 * half)] for _ in range(degree)]
        rows = [[(0, 0) for _ in range(degree + 1)] for _ in range(threads)]
        for i in range(half):
            cur = [tb[i] for tb in tables]
            delta = [minus(tb[i + half], tb[i]) for tb in tables]
            for d in range(degree + 1):
                v = (1, 0)
                for x in cur:
                    v = mul(v, x)
                rows[i % threads][d] = plus(rows[i % threads][d], v)
                cur = [plus(x, y) for x, y in zip(cur, delta)]
        expected = R.polynomial_values(tables, degree)
        check(C.baseline_tree(rows) == expected, 'round baseline vs expanded node')
        check(C.block(rows) == expected, 'round candidate vs expanded node')
        polynomial_cases += 1
        if half == 33 and degree in (2, 5):
            saved_poly.append(dict(degree=degree, half=half, threads=threads,
                                   tables=tables, expected=expected))

# Decisive incorrect alternatives, detected independently of source assertions.
v = [C.P - 1] * 32
ref = R.warp_sum(v, C.U32)
different((sum(v) & C.U64) % C.P, ref, 'u64-wrap-loses-carry')
different(sum(x & C.U32 for x in v) % C.P, ref, 'truncate-input-to-u32')
different(sum(v[:-1]) % C.P, ref, 'missing-last-lane')
different((sum(v) ^ 1) % C.P, ref, 'corrupt-round-output')
v28 = [(1 << 28) - 1] * 32
different((sum(v28) & C.U32) % C.P, R.warp_sum(v28, C.U32), '28bit-digits-overflow')
v = [1 << 27] * 32
different(0, R.warp_sum(v, C.U32), 'omit-middle-digit')
v = [C.P - 1] * 32
_, (digits, lo, hi) = C.warp(v)
different(C.reduce128(lo, 0), ref, 'omit-reconstructed-high')
different(C.reduce128(lo, hi - 1), ref, 'drop-final-add-carry')
different(C.warp(v, 0x7fffffff)[0], ref, 'inconsistent-membermask')
different((sum(v) % (C.P - 2)), ref, 'wrong-modulus')
fixture = saved_blocks[1]
rows = fixture['rows']
refb = R.component_sums(rows)
different([(b, a) for a, b in C.block(rows)], refb, 'swapped-Fp2-limbs')
different(C.block(rows[:32] + rows[:32] + rows[64:]), refb, 'duplicate-warp')
changed = [[tuple(v) for v in row] for row in rows]
changed[1][2] = ((changed[1][2][0] + 1) % C.P, changed[1][2][1])
different(C.block(changed), refb, 'foreign-evaluation-lane')
different(C.block([row[::-1] for row in rows]), refb, 'reversed-evaluation-order')
check(C.block(rows) == refb, 'fresh second call does not retain other fixture')
for bad in ([], [0]*31, [0]*33):
    reject(lambda bad=bad: C.warp(bad), 'bad-warp-length-' + str(len(bad)))
for mask in (0, -1, 1 << 32):
    reject(lambda mask=mask: C.warp([0]*32, mask), 'bad-mask-' + str(mask))
for value in (-1, 1 << 64, True):
    reject(lambda value=value: C.warp([value]*32), 'bad-operand-' + str(value))
reject(lambda: C.block(rows[:-1]), 'bad-CTA')
reject(lambda: C.block([[] for _ in range(32)]), 'zero-evaluations')
reject(lambda: C.block([[(0,)] for _ in range(32)]), 'malformed-Fp2')

costs = [C.counts(t, n) for t in (32, 64, 128, 256, 512, 1024)
         for n in (1, 3, 5, 6)]
(E/'costs.json').write_text(json.dumps(costs, indent=2)+'\n')
(E/'fixtures.json').write_text(json.dumps(dict(warps=saved_warps,
                 blocks=saved_blocks, polynomials=saved_poly), indent=2)+'\n')
(E/'negative-controls.json').write_text(json.dumps(negatives, indent=2)+'\n')
check(32 * ((1 << 27) - 1) < 1 << 32, 'universal independent digit bound')
check(32 * ((1 << 28) - 1) >= 1 << 32, 'maximal digit width boundary')
result = dict(status='PASS', seed=SEED, checks=checks, warp_cases=warp_cases,
              block_cases=block_cases, polynomial_cases=polynomial_cases,
              negative_controls=len(negatives), saved_warps=len(saved_warps),
              saved_blocks=len(saved_blocks), saved_polynomials=len(saved_poly),
              native_execution=False, cuda_sketch_compiled=False,
              proofs=0, complete_model_passes=0, proved_positions=0,
              measured_proving_speedup=None, wall_s=time.monotonic()-started)
(E/'result.json').write_text(json.dumps(result, indent=2)+'\n')
cpu = next((l.split(':', 1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines()
            if l.startswith('model name')), 'unknown')
(E/'hardware.json').write_text(json.dumps(dict(cpu=cpu, affinity=sorted(os.sched_getaffinity(0)),
                threads=1, nice=os.nice(0), python=platform.python_version(), gpu=None), indent=2)+'\n')
print(json.dumps(result))
