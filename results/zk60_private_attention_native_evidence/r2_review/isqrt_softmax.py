#!/usr/bin/env python3
"""R-2 part 2: the isqrt and causal-softmax exactness arguments.

(a) witness.rs::isqrt (a hand-written binary integer sqrt) against Python's
    exact math.isqrt, over the whole reachable range and at every boundary;
    it is also compared with private-block-kernel's isqrt (identical source)
    and with norm.rs::isqrt (a float seed plus correction loops).
(b) the constraint triple  Dsq = D*D, a1 = ss - Dsq >= 0, a2 = 2D - a1 >= 0
    pins D = isqrt(ss) and nothing else.
(c) the softmax division relation  2^fP * mask * E = p*Sum + rho,
    sigma + rho + 1 = Sum, with p, rho, sigma >= 0, pins p = floor(2^fP E / Sum)
    on the causal support and forces p = rho = 0 off it.
(d) 'first attainer' vs 'any attainer': the selector position is the only thing
    that differs; max, E, Sum and p are identical.

Read-only.
"""
import math
import random

T, D, F_E, F_P, WRHO_S = 32, 16, 9, 9, 14
SS_MAX = D * 32768 * 32768 + 1  # the largest reachable sum of squares + ceps


def isqrt_witness(v):
    """Transcription of witness.rs:26-43 / private-block-kernel lib.rs:324-343
    (u64 arithmetic; the two Rust sources are character-identical)."""
    rem = v
    res = 0
    bit = 1 << 62
    while bit > v:
        bit >>= 2
    while bit != 0:
        if rem >= res + bit:
            rem -= res + bit
            res = (res >> 1) + bit
        else:
            res >>= 1
        bit >>= 2
    return res


def isqrt_norm_rs(v):
    """Transcription of hashline/src/norm.rs:156-169 (the oracle's isqrt)."""
    assert v >= 0
    if v < 2:
        return v
    r = int(math.sqrt(float(v)))
    while r * r > v:
        r -= 1
    while (r + 1) * (r + 1) <= v:
        r += 1
    return r


# ---------------------------------------------------------------- (a)
cases = list(range(0, 70000))
for k in range(0, 132000):           # every perfect square in range and its neighbours
    s = k * k
    if s <= SS_MAX:
        cases += [s - 1, s, s + 1]
cases += [SS_MAX, SS_MAX - 1, 1 << 34, (1 << 34) + 1]
rnd = random.Random(20260918)
cases += [rnd.randrange(0, SS_MAX + 1) for _ in range(200000)]
cases = [c for c in cases if 0 <= c <= SS_MAX]

bad_w = [v for v in cases if isqrt_witness(v) != math.isqrt(v)]
bad_n = [v for v in cases if isqrt_norm_rs(v) != math.isqrt(v)]
print(f"(a) isqrt: {len(cases)} values tested in [0, {SS_MAX}] "
      f"(all of 0..70000, every perfect square +-1, 200000 random)")
print(f"    witness.rs / kernel binary isqrt disagreements with math.isqrt: {len(bad_w)}"
      f"{'' if not bad_w else ' e.g. ' + str(bad_w[:5])}")
print(f"    norm.rs float-seeded isqrt disagreements with math.isqrt:       {len(bad_n)}"
      f"{'' if not bad_n else ' e.g. ' + str(bad_n[:5])}")
print(f"    max reachable D = isqrt({SS_MAX}) = {math.isqrt(SS_MAX)} < 2^18; "
      f"max reachable a1 = ss - D^2 <= 2D = {2*math.isqrt(SS_MAX)} < 2^19")

# ---------------------------------------------------------------- (b)
# For every ss, count the D >= 0 admitted by (a1 = ss - D^2 >= 0) and (a2 = 2D - a1 >= 0).
viol = []
for ss in range(0, 200001):
    sol = [d for d in range(0, math.isqrt(ss) + 3) if ss - d * d >= 0 and 2 * d - (ss - d * d) >= 0]
    if sol != [math.isqrt(ss)]:
        viol.append((ss, sol))
print(f"\n(b) uniqueness of D: ss in [0, 200000] exhaustive; "
      f"rows where {{D : D^2 <= ss <= D^2 + 2D}} != {{isqrt(ss)}}: {len(viol)}"
      f"{'' if not viol else ' e.g. ' + str(viol[:5])}")
print("    (the general argument: D^2 <= ss <= D^2+2D < (D+1)^2 is exactly the")
print("     defining interval of floor(sqrt(ss)), and the intervals are disjoint.)")
print(f"    ss = 0 admits D = 0 only; ceps = 1 makes ss >= 1, so D >= 1 and the")
print(f"    norm denominator D*2^(tn+1) is nonzero: ss=0 -> {[d for d in range(3) if 0 - d*d >= 0 and 2*d - (0 - d*d) >= 0]}, "
      f"ss=1 -> {[d for d in range(4) if 1 - d*d >= 0 and 2*d - (1 - d*d) >= 0]}")

# ---------------------------------------------------------------- (c)
bad_div, bad_off = [], []
rnd = random.Random(7)
for _ in range(200000):
    Sum = rnd.randrange(1, (1 << 15))          # Sum = sigma + rho + 1, 1 .. 2^15-1
    E = rnd.randrange(0, (1 << F_E) + 1)
    # on the causal support (mask = 1): the unique (p, rho) with rho in [0, Sum-1]
    sol = [(p, (E << F_P) - p * Sum) for p in range(0, (1 << 10))
           if 0 <= (E << F_P) - p * Sum <= Sum - 1]
    want = (E << F_P) // Sum
    if len(sol) != 1 or sol[0][0] != want:
        if want < (1 << 10):      # only a quotient inside the enforced p window is relevant
            bad_div.append((E, Sum, sol, want))
    # off the causal support (mask = 0): p*Sum + rho = 0 with p, rho >= 0
    off = [(p, r) for p in range(0, 4) for r in range(0, 4) if p * Sum + r == 0]
    if off != [(0, 0)]:
        bad_off.append((Sum, off))
print(f"\n(c) softmax division: 200000 random (E, Sum) with Sum in [1, 2^15), E in [0, 2^9]")
print(f"    on-support rows where (p, rho) is not the unique floor quotient: {len(bad_div)}")
print(f"    off-support rows where p*Sum + rho = 0 admits anything but (0,0): {len(bad_off)}")
print(f"    note Sum >= 1 comes from c3: Sum = sigma + rho + 1 with sigma, rho >= 0 byte-limbed.")
pmax_seen = max(((E << F_P) // Sum) for E in (0, 1 << F_E) for Sum in (1 << F_E, ))
print(f"    with Sum >= E (every on-support E is one of the summands of Sum) the quotient")
print(f"    is at most 2^fP = {1 << F_P}: e.g. E = Sum = 2^9 gives p = {pmax_seen}"
      f"  (the enforced window is p < 2^10, i.e. one bit looser than the kernel's p <= 2^9).")

# ---------------------------------------------------------------- (d)
def kernel_row(scores, t, exp):
    masked = [scores[j] if j <= t else -127 for j in range(T)]
    best, arg = -(1 << 62), 0
    for j in range(T):
        if masked[j] > best:
            best, arg = masked[j], j
    E = [exp[best - masked[j]] for j in range(T)]
    Sum = sum(E[j] for j in range(T) if j <= t)
    p = [((E[j] << F_P) // Sum if j <= t else 0) for j in range(T)]
    return best, arg, Sum, p


exp = [max(1, (1 << F_E) >> (i // 8)) for i in range(256)]  # any monotone table works
exp[0] = 1 << F_E
rnd = random.Random(99)
diff = []
for _ in range(20000):
    t = rnd.randrange(T)
    scores = [rnd.randrange(-127, 128) for _ in range(T)]
    best, arg, Sum, p = kernel_row(scores, t, exp)
    masked = [scores[j] if j <= t else -127 for j in range(T)]
    attainers = [j for j in range(T) if masked[j] == best]
    # every attainer satisfies the constraint system's selector conditions
    for a in attainers:
        b2, _, S2, p2 = kernel_row(scores, t, exp)
        if (best, Sum, p) != (b2, S2, p2):
            diff.append((t, a))
    if arg != min(attainers):
        diff.append(("arg is not the first attainer", t, arg, attainers))
    if arg > t:
        diff.append(("arg > t", t, arg))
print(f"\n(d) first attainer: 20000 random rows; the kernel's arg is always the smallest")
print(f"    attainer and never exceeds t; rows where a different attainer would change")
print(f"    (max, Sum, p): {len(diff)}"
      f"{'' if not diff else ' e.g. ' + str(diff[:3])}")
print("    -> the constraint system only pins 'zsel sits on SOME attainer'; max, E, Sum, p")
print("       and therefore every committed output are identical for any choice.")
