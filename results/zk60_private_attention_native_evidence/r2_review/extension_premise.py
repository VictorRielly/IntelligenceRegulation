#!/usr/bin/env python3
"""R-2 part 3: the extension-round premise of
hashline/src/private_attention/argument.rs.

MECHANISM (zkp-core/src/sumcheck.rs:297-314, zk.rs:984-999).  After the n main
rounds the prover appends `ext` rounds.  Round m sends
    s(X) = poly( (1-X)*finals + X*exts ) + c*g(X)
where exts[t] = the mask-pair evaluation for a private table with
ext_round == m and ZERO for EVERY other table (public tables included).  The
sumcheck verifier checks s(0) + s(1) = (previous round at its challenge), and
the mask g is defined over n+ext variables so its half is consistent by
construction.  The data half therefore requires

        poly(exts) = 0                                    (the premise)

i.e. every monomial of the slot polynomial must contain at least one table
that is ZERO in the round-m extension vector: a public table (Eq / Pub), or a
private table belonging to a DIFFERENT extension round.  A monomial that is a
product of round-m private tables only - or a bare constant - breaks it.

This script transcribes all eighteen slot polynomials of argument.rs::define
into an exact multivariate polynomial over the table indices (every scalar
challenge and constant gets its own random field value so nothing cancels by
accident), expands them, and checks the premise monomial by monomial for every
extension round of every slot.

Read-only.
"""
import random

FP = (1 << 61) - 1
rnd = random.Random(20260918)
SC = {}


def sc(name):
    """a distinct random nonzero scalar per challenge/constant symbol"""
    if name not in SC:
        SC[name] = rnd.randrange(2, FP - 1)
    return SC[name]


class Poly(dict):
    """monomial (sorted tuple of table indices) -> coefficient mod FP"""

    def __add__(self, o):
        r = Poly(self)
        for m, c in o.items():
            r[m] = (r.get(m, 0) + c) % FP
            if r[m] == 0:
                del r[m]
        return r

    def __sub__(self, o):
        return self + o.neg()

    def neg(self):
        return Poly({m: (-c) % FP for m, c in self.items()})

    def __mul__(self, o):
        r = Poly()
        for m1, c1 in self.items():
            for m2, c2 in o.items():
                m = tuple(sorted(m1 + m2))
                r[m] = (r.get(m, 0) + c1 * c2) % FP
                if r[m] == 0:
                    del r[m]
        return r


def K(name):
    return Poly({(): sc(name)})


def V(i):
    return Poly({(i,): 1})


ONE = Poly({(): 1})


def helper_sum(lks, h0, nmu, tag):
    """argument.rs:453-471: sum_k mu_k * (h_k d1 d2 - (d1 + d2)) (or h d - 1)."""
    def den(planes, cst_tag):
        d = K("alpha") + K(cst_tag)
        for p in planes:
            d = d - K(f"coef{tag}{p}") * V(p)
        return d
    acc = Poly()
    for k in range((len(lks) + 1) // 2):
        h = V(h0 + k)
        d1 = den(lks[2 * k], f"cst{tag}{2*k}")
        if 2 * k + 1 < len(lks):
            d2 = den(lks[2 * k + 1], f"cst{tag}{2*k+1}")
            rel = h * d1 * d2 - (d1 + d2)
        else:
            rel = h * d1 - ONE
        acc = acc + K(f"mu{tag}{k}") * rel
    assert (len(lks) + 1) // 2 == nmu, (tag, len(lks), nmu)
    return acc


SLOTS = []   # (index, name, [(table name, kind, ext_round)], poly, main_rounds, ext, degree)


def slot(i, name, tabs, poly, n, ext, deg):
    SLOTS.append((i, name, tabs, poly, n, ext, deg))


PUB, PRV = "public", "private"

# ---------------------------------------------------------------- 00 SS
t = [("eq(r_t)", PUB, None), ("A_X", PRV, 0)]
slot(0, "01 SS row sums", t, V(0) * V(1) * V(1), 9, 1, 3)

# ---------------------------------------------------------------- 01 TZC
t = [("eq(tau)", PUB, None), ("eq(r_t)", PUB, None), ("A_D", PRV, 0), ("A_DSQ", PRV, 0)]
t += [(f"A_LIMB[{k}]", PRV, 0) for k in range(9)]
l3 = lambda o: V(o) + K("p1") * V(o + 1) + K("p2") * V(o + 2)
d, dsq, dl, a1, a2 = V(2), V(3), l3(4), l3(7), l3(10)
zc = K("mu0") * (dsq - d * d) + K("mu1") * (d - dl) + K("mu2") * ((K("two") * d) - a1 - a2)
slot(1, "02 norm squares zero-check", t,
     V(0) * zc + K("nu") * V(1) * (dsq + a1 - K("ceps")), 5, 1, 3)

# ---------------------------------------------------------------- 02 LZC
t = [("eq(tau)", PUB, None), ("A_LIMB", PRV, 0), ("H_L", PRV, 0)]
slot(2, "08 limb zero-check", t, V(0) * helper_sum([[1]], 2, 1, "L"), 9, 1, 3)

# ---------------------------------------------------------------- 03 RS
t = [("eq(p_ht)", PUB, None), ("causal mask", PUB, None), ("A_E", PRV, 0), ("A_ZSEL", PRV, 0)]
slot(3, "07 masked row sums + selector", t,
     V(0) * (V(1) * V(2) + K("lam") * V(3)), 11, 1, 3)

# ---------------------------------------------------------------- 04-06, 09 matmuls
for i, nm, pl in [(4, "09Q matmul", "A_Y"), (5, "09K matmul", "A_Y"),
                  (6, "09V matmul", "A_Y"), (9, "12 Wo matmul", "A_O8")]:
    slot(i, nm, [(pl, PRV, 0), ("folded W", PUB, None)], V(0) * V(1), 4, 1, 2)

# ---------------------------------------------------------------- 07 score, 08 PV
slot(7, "10 score matmul (bilinear)",
     [("A_QR8", PRV, 0), ("A_KR8", PRV, 1)], V(0) * V(1), 3, 2, 2)
slot(8, "11 PV matmul (bilinear)",
     [("A_P", PRV, 0), ("A_V8", PRV, 1)], V(0) * V(1), 5, 2, 2)

# ---------------------------------------------------------------- 10 DZC
names_d = ["A_X", "A_XL0", "A_XL1", "A_Y", "A_NR0", "A_NR1", "A_NR2", "A_NR3",
           "A_NS0", "A_NS1", "A_NS2", "A_NS3", "A_AO", "A_AL0", "A_AL1", "A_RAL",
           "A_X1", "A_X1L0", "A_X1L1"]           # planes A_X ..= A_X1L1, in order
t = [("eq(tau)", PUB, None), ("eq(p_a)", PUB, None), ("gamma table", PUB, None)]
t += [(n, PRV, 0) for n in names_d]
t += [("A_D@5", PRV, 0)]
t += [(f"H_D{k}", PRV, 0) for k in range(10)]
ix = {n: 3 + k for k, n in enumerate(names_d)}
ID = 3 + len(names_d)          # the A_D slice
H0 = ID + 1
lk_d = [[ix["A_XL0"]], [ix["A_XL1"]], [ix["A_Y"]], [ix["A_Y"]],
        [ix["A_NR0"]], [ix["A_NR1"]], [ix["A_NR2"]], [ix["A_NR3"]], [ix["A_NR3"]],
        [ix["A_NS0"]], [ix["A_NS1"]], [ix["A_NS2"]], [ix["A_NS3"]], [ix["A_NS3"]],
        [ix["A_AL0"]], [ix["A_AL1"]], [ix["A_RAL"]], [ix["A_RAL"]],
        [ix["A_X1L0"]], [ix["A_X1L1"]]]
l4 = lambda a, b, c, dd: V(a) + K("p1") * V(b) + K("p2") * V(c) + K("p3") * V(dd)
l2 = lambda a, b: V(a) + K("p1") * V(b)
x, y, ao, x1, dv = V(ix["A_X"]), V(ix["A_Y"]), V(ix["A_AO"]), V(ix["A_X1"]), V(ID)
nr = l4(ix["A_NR0"], ix["A_NR1"], ix["A_NR2"], ix["A_NR3"])
ns = l4(ix["A_NS0"], ix["A_NS1"], ix["A_NS2"], ix["A_NS3"])
c0 = K("knum") * V(2) * x + K("kdv") * dv - K("kden") * y * dv - nr
c1 = ns + nr + ONE - K("kden") * dv
c2 = x + K("32768") - l2(ix["A_XL0"], ix["A_XL1"])
c3 = ao + K("32768") - l2(ix["A_AL0"], ix["A_AL1"])
c4 = x1 + K("32768") - l2(ix["A_X1L0"], ix["A_X1L1"])
c5 = x1 - x - ao
zc = helper_sum(lk_d, H0, 10, "D")
for j, cc in enumerate([c0, c1, c2, c3, c4, c5]):
    zc = zc + K(f"muD{j}") * cc
host = K("shao") * ao + V(ix["A_RAL"]) - K("halfao")
slot(10, "03 D zero-check (hosts 12)", t, V(0) * zc + K("nuD") * V(1) * host, 9, 1, 4)

# ---------------------------------------------------------------- 11 QZC / 12 KVZC
for si, nm, planes, hn, lkspec, n in [
    (11, "04 Q zero-check (hosts 09Q, 11)",
     ["A_Q8", "A_RQL", "A_QR8", "A_RQRL", "A_O8", "A_RO0", "A_RO1"], 7,
     [("A_Q8",), ("A_Q8",), ("A_RQL",), ("A_RQL",), ("A_QR8",), ("A_QR8",),
      ("A_RQRL",), ("A_RQRL",), ("A_O8",), ("A_O8",), ("A_RO0",), ("A_RO1",), ("A_RO1",)], 9),
    (12, "05 KV zero-check (hosts 09K, 09V)",
     ["A_K8", "A_RKL", "A_V8", "A_RVL", "A_KR8", "A_RKRL"], 6,
     [("A_K8",), ("A_K8",), ("A_RKL",), ("A_RKL",), ("A_V8",), ("A_V8",),
      ("A_RVL",), ("A_RVL",), ("A_KR8",), ("A_KR8",), ("A_RKRL",), ("A_RKRL",)], 8)]:
    t = [("eq(tau)", PUB, None), ("eq(p_mm)", PUB, None), ("eq(p_rope)", PUB, None),
         ("C table", PUB, None), ("S' table", PUB, None)]
    t += [(p, PRV, 0) for p in planes]
    t += [("flip partner", PRV, 0)]
    t += [(f"H_{si}_{k}", PRV, 0) for k in range(hn)]
    ix = {p: 5 + k for k, p in enumerate(planes)}
    IFLIP = 5 + len(planes)
    H0 = IFLIP + 1
    lk = [[ix[p] for p in row] for row in lkspec]
    src = planes[0]
    rot, rrem = (("A_QR8", "A_RQRL") if si == 11 else ("A_KR8", "A_RKRL"))
    rope = (V(3) * V(ix[src]) + V(4) * V(IFLIP) - K("shrope") * V(ix[rot])
            - V(ix[rrem]) + K("halfrope"))
    zc = K("mu0") * rope + helper_sum(lk, H0, hn, f"Z{si}")
    if si == 11:
        h1 = K("shq") * V(ix["A_Q8"]) + V(ix["A_RQL"]) - K("half7")
        h2 = (K("sho") * V(ix["A_O8"]) + V(ix["A_RO0"]) + K("p1") * V(ix["A_RO1"])
              - K("half9"))
    else:
        h1 = K("shq") * V(ix["A_K8"]) + V(ix["A_RKL"]) - K("half7")
        h2 = K("shv") * V(ix["A_V8"]) + V(ix["A_RVL"]) - K("half7")
    slot(si, nm, t, V(0) * zc + K("nu0") * V(1) * h1 + K("nu1") * V(2) * h2, n, 1, 4)

# ---------------------------------------------------------------- 13 SZC
names_s = ["A_S8", "A_RSL", "A_ZSEL", "A_E", "A_P", "A_PL0", "A_PL1",
           "A_SR0", "A_SR1", "A_SG0", "A_SG1"]     # planes A_S8 ..= A_SG1
t = [("eq(tau)", PUB, None), ("eq(p_ht)", PUB, None), ("eq(p_s)", PUB, None),
     ("causal mask", PUB, None)]
t += [(n, PRV, 0) for n in names_s]
t += [("A_MX@6", PRV, 0), ("A_SUM@6", PRV, 0)]
t += [(f"H_S{k}", PRV, 0) for k in range(7)] + [("H_SEXP", PRV, 0)]
ix = {n: 4 + k for k, n in enumerate(names_s)}
IMX, ISUM = 4 + len(names_s), 5 + len(names_s)
H0, IHX = ISUM + 1, ISUM + 8
lk_s = [[ix["A_S8"]], [ix["A_S8"]], [ix["A_RSL"]], [ix["A_RSL"]],
        [ix["A_PL0"]], [ix["A_PL1"]], [ix["A_PL1"]],
        [ix["A_SR0"]], [ix["A_SR1"]], [ix["A_SR1"]],
        [ix["A_SG0"]], [ix["A_SG1"]], [ix["A_SG1"]]]
mask, s8, zsel, e, p, summ = V(3), V(ix["A_S8"]), V(ix["A_ZSEL"]), V(ix["A_E"]), V(ix["A_P"]), V(ISUM)
sr = V(ix["A_SR0"]) + K("p1") * V(ix["A_SR1"])
delta = V(IMX) - mask * (s8 + K("127")) + K("127")
c0 = zsel * zsel - zsel
c1 = zsel * delta
c2 = K("shfp") * mask * e - p * summ - sr
c3 = V(ix["A_SG0"]) + K("p1") * V(ix["A_SG1"]) + sr + ONE - summ
c4 = p - V(ix["A_PL0"]) - K("p1") * V(ix["A_PL1"])
cx = V(IHX) * (K("alpha") - (delta + K("beta") * e + K("gexp"))) - ONE
zc = helper_sum(lk_s, H0, 7, "S") + K("muX") * cx
for j, cc in enumerate([c0, c1, c2, c3, c4]):
    zc = zc + K(f"muS{j}") * cc
host_rs = summ + K("lam")
host_s = K("shs") * s8 + V(ix["A_RSL"]) - K("half6")
slot(13, "06 softmax zero-check (hosts 07, 10)", t,
     V(0) * zc + K("nu0") * V(1) * host_rs + K("nu1") * V(2) * host_s, 11, 1, 4)

# ---------------------------------------------------------------- 14 TAB
t = [("eq(tau)", PUB, None), ("A_MU8", PRV, 0), ("H_GU8", PRV, 0), ("U8 table", PUB, None),
     ("A_MEXP", PRV, 0), ("H_GEXP", PRV, 0), ("exp table", PUB, None)]
r0 = V(2) * (K("alpha") - V(3)) - V(1)
r1 = V(5) * (K("alpha") - V(6)) - V(4)
slot(14, "TAB table helper zero-check", t,
     V(0) * (K("mu0") * r0 + K("mu1") * r1), 8, 1, 3)

# ---------------------------------------------------------------- 15 ZS
slot(15, "ZS zero-sum row", [("all-ones", PUB, None), ("H_U", PRV, 0)], V(0) * V(1), 8, 1, 2)

# ---------------------------------------------------------------- 16/17 IO
for i, nm, pl, ep in [(16, "IO-in endpoint equality", "A_X", "input endpoint"),
                      (17, "IO-out endpoint equality", "A_X1", "output endpoint")]:
    slot(i, nm, [("eq(tau)", PUB, None), (pl, PRV, 0), (ep, PRV, 0)],
         V(0) * (V(1) - V(2)), 9, 1, 2)

# ---------------------------------------------------------------- the check
DECLARED = [(9, 1, 3), (5, 1, 3), (9, 1, 3), (11, 1, 3), (4, 1, 2), (4, 1, 2), (4, 1, 2),
            (3, 2, 2), (5, 2, 2), (4, 1, 2), (9, 1, 4), (9, 1, 4), (8, 1, 4), (11, 1, 4),
            (8, 1, 3), (8, 1, 2), (9, 1, 2), (9, 1, 2)]
A_SITES = [1, 11, 1, 2, 1, 1, 1, 2, 2, 1, 20, 8, 7, 13, 2, 0, 1, 1]
H_SITES = [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 10, 7, 6, 8, 2, 1, 0, 0]

SLOTS.sort()
ok = True
print("slot                                    monomials  maxdeg  decl  privtabs  premise")
for i, name, tabs, poly, n, ext, deg in SLOTS:
    maxdeg = max(len(m) for m in poly)
    npriv = sum(1 for _, k, _ in tabs if k == PRV)
    verdict = []
    for m in range(ext):
        zero_tabs = {j for j, (_, k, r) in enumerate(tabs) if not (k == PRV and r == m)}
        bad = [mon for mon in poly if not any(v in zero_tabs for v in mon)]
        verdict.append((m, bad))
        if bad:
            ok = False
    decl_ok = (n, ext, deg) == DECLARED[i] and maxdeg == deg
    sites_ok = npriv == A_SITES[i] + H_SITES[i] + (1 if i >= 16 else 0)
    ok &= decl_ok and sites_ok
    flag = "VANISHES" if all(not b for _, b in verdict) else "BREAKS"
    print(f"{i:02} {name:<36} {len(poly):>7}  {maxdeg:>5}"
          f"  {'ok' if decl_ok else 'MISMATCH':>8}  {'ok' if sites_ok else 'MISMATCH':>8}"
          f"  {flag}")
    for m, bad in verdict:
        if bad:
            print(f"     round {m}: monomials with no zeroed factor: "
                  f"{[tuple(tabs[v][0] for v in mon) for mon in bad[:6]]}")

print()
print("per-slot detail (top-level factored structure and the zeroing factor):")
for i, name, tabs, poly, n, ext, deg in SLOTS:
    pubs = [t[0] for t in tabs if t[1] == PUB]
    r0 = [t[0] for t in tabs if t[1] == PRV and t[2] == 0]
    r1 = [t[0] for t in tabs if t[1] == PRV and t[2] == 1]
    print(f"  {i:02} {name}")
    print(f"      public tables : {pubs if pubs else 'NONE'}")
    print(f"      ext round 0   : {len(r0)} private tables{'' if not r1 else ''}")
    if r1:
        print(f"      ext round 1   : {r1}")
print()
print("PREMISE HOLDS FOR ALL 18 SLOTS" if ok else "PREMISE BROKEN OR A DECLARATION MISMATCH")
