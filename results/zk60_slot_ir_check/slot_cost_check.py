#!/usr/bin/env python3
"""Independent re-derivation of the private block's sumcheck multiplication
counts, for the adversarial check of ZK60_SLOT_EXPRESSION_IR_DESIGN.md.

METHOD (deliberately different from the drafter's script, which counts
`.mul(` tokens in the Rust and adds hand-declared adjustments):

  * every slot's closure is TRANSLITERATED from
    `hashline/src/private_block/argument.rs` at `226f3b2` into Python;
  * each value is a UNIVARIATE POLYNOMIAL IN THE ROUND VARIABLE `t` with
    exact F_{p^2} coefficients (p = 2^64 - 2^32 + 1, u^2 = 7).  A table
    contributes `v0 + t (v1 - v0)`, which is what `sumcheck::prove`'s
    `cur[t] = cur[t] + dif[t]` walk computes;
  * the multiplication count is therefore an EXECUTION count, and the
    degree of every intermediate is the TRUE degree after cancellation,
    not a structural bound;
  * whether a value is base-field is read off its actual coefficients,
    so the round-0 classification is computed and not declared.

Outputs a JSON blob and a text table.  No Rust is built and no proof is run.
"""

import json
import random
import sys

P = (1 << 64) - (1 << 32) + 1
NONRESIDUE = 7

# ---------------------------------------------------------------- F_{p^2}


def f2mul(a, b):
    ac = a[0] * b[0] % P
    bd = a[1] * b[1] % P
    ad = a[0] * b[1] % P
    bc = a[1] * b[0] % P
    return ((ac + bd * NONRESIDUE) % P, (ad + bc) % P)


def f2add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def f2sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


ZERO = (0, 0)
ONE = (1, 0)

# ---------------------------------------------------------------- counters


class Counter:
    """One slot's operation tally, per evaluation point of one pair index."""

    def __init__(self):
        # (kind, result_degree, n_base_operands) -> count
        self.ops = {}

    def note(self, kind, deg, nbase):
        key = (kind, deg, nbase)
        self.ops[key] = self.ops.get(key, 0) + 1

    def n_mul(self):
        return sum(c for (k, _, _), c in self.ops.items() if k == "mul")

    def n_mulbase(self):
        return sum(c for (k, _, _), c in self.ops.items() if k == "mulbase")

    # ---- the four cost models, in Fp multiplications per PAIR INDEX ----
    def baseline(self, d):
        """every mul re-run at all d+1 evaluation points, always full width"""
        return (d + 1) * (5 * self.n_mul() + 2 * self.n_mulbase())

    def with_a(self, d):
        """round 0 only: narrow each product by how many operands are base"""
        tot = 0
        for (kind, _deg, nbase), c in self.ops.items():
            if kind == "mul":
                w = {0: 5, 1: 2, 2: 1}[nbase]
            else:  # mulbase: Fp2 x Fp
                w = 1 if nbase >= 1 else 2
            tot += c * w
        return (d + 1) * tot

    def with_c(self, d, narrow=False):
        """each mul run (deg(result)+1) times instead of (d+1)"""
        tot = 0
        for (kind, deg, nbase), c in self.ops.items():
            if kind == "mul":
                w = {0: 5, 1: 2, 2: 1}[nbase] if narrow else 5
            else:
                w = (1 if nbase >= 1 else 2) if narrow else 2
            tot += c * w * min(deg + 1, d + 1)
        return tot

    def fd_additions(self, d):
        """Fp2 additions the finite-difference extension costs, per pair index:
        a node of degree dd extended to d+1 points needs dd*(d-dd) additions."""
        tot = 0
        for (_kind, deg, _nb), c in self.ops.items():
            dd = min(deg, d)
            tot += c * dd * (d - dd)
        return tot


# ---------------------------------------------------------------- values

rng = random.Random(20260921)


def rnd_fp():
    return rng.randrange(P)


class V:
    """a univariate polynomial in t with F_{p^2} coefficients"""

    __slots__ = ("c", "ctr")

    def __init__(self, coeffs, ctr):
        # trim exact zero leading coefficients: the TRUE degree
        while len(coeffs) > 1 and coeffs[-1] == ZERO:
            coeffs = coeffs[:-1]
        self.c = coeffs
        self.ctr = ctr

    @property
    def deg(self):
        return len(self.c) - 1

    @property
    def is_base(self):
        return all(x[1] == 0 for x in self.c)

    def mul(self, o):
        out = [ZERO] * (len(self.c) + len(o.c) - 1)
        for i, a in enumerate(self.c):
            if a == ZERO:
                continue
            for j, b in enumerate(o.c):
                if b == ZERO:
                    continue
                out[i + j] = f2add(out[i + j], f2mul(a, b))
        r = V(out, self.ctr)
        nbase = int(self.is_base) + int(o.is_base)
        self.ctr.note("mul", r.deg, nbase)
        return r

    def mul_base(self, fp):
        """Fp2 * Fp, the `mul_base` of field.rs (2 Fp muls)"""
        out = [((x[0] * fp) % P, (x[1] * fp) % P) for x in self.c]
        r = V(out, self.ctr)
        self.ctr.note("mulbase", r.deg, int(self.is_base))
        return r

    def add(self, o):
        n = max(len(self.c), len(o.c))
        out = []
        for i in range(n):
            a = self.c[i] if i < len(self.c) else ZERO
            b = o.c[i] if i < len(o.c) else ZERO
            out.append(f2add(a, b))
        return V(out, self.ctr)

    def sub(self, o):
        n = max(len(self.c), len(o.c))
        out = []
        for i in range(n):
            a = self.c[i] if i < len(self.c) else ZERO
            b = o.c[i] if i < len(o.c) else ZERO
            out.append(f2sub(a, b))
        return V(out, self.ctr)

    def double(self):
        return self.add(self)


def table(ctr, base):
    """a folded table entry: v0 + t (v1 - v0). `base` means both words real."""
    if base:
        v0 = (rnd_fp(), 0)
        v1 = (rnd_fp(), 0)
    else:
        v0 = (rnd_fp(), rnd_fp())
        v1 = (rnd_fp(), rnd_fp())
    return V([v0, f2sub(v1, v0)], ctr)


def chal(ctr):
    """a challenge: constant in t, extension-valued"""
    return V([(rnd_fp(), rnd_fp())], ctr)


def konst(ctr, n):
    """`k(v)` / `pow256(k)`: constant in t, BASE-valued"""
    return V([(n % P, 0)], ctr)


def chalv(ctr, n):
    return [chal(ctr) for _ in range(n)]


# ---------------------------------------------------------------- shapes


def clog2(v):
    return max(0, (v - 1).bit_length())


class Shape:
    def __init__(self, name, tokens, width, hidden, q_heads, head_dim, kv_heads, log_cols, f_e):
        self.name = name
        self.tokens, self.width, self.hidden = tokens, width, hidden
        self.q_heads, self.head_dim, self.kv_heads = q_heads, head_dim, kv_heads
        self.log_cols, self.f_e = log_cols, f_e
        self.t_pad = 1 << clog2(tokens)
        self.d_pad = 1 << clog2(width)
        self.h_pad = 1 << clog2(q_heads)
        self.f_pad = 1 << clog2(hidden)
        # shape.rs:196  d_max = isqrt(NORM_CEPS + width * INT16_MAX^2)
        import math

        self.d_max = math.isqrt(1 + width * 32767 * 32767)
        self.norm_wrho = 11 + 1 + self.d_max.bit_length()
        self.wrho_s = clog2(tokens) + f_e

    # ---- shape.rs
    def limbs_norm(self):
        return -(-self.norm_wrho // 8)

    def norm_top_is_full_byte(self):
        return self.norm_wrho == 8 * self.limbs_norm()

    def limbs_sigma_s(self):
        return -(-self.wrho_s // 8)

    def limbs_p(self):
        return -(-(9 + 1) // 8)

    def natural_log(self, dom):
        return {
            "T": clog2(self.t_pad),
            "Ht": clog2(self.h_pad * self.t_pad),
            "L": clog2(16 * self.t_pad),
            "D": clog2(self.t_pad * self.d_pad),
            "Q": clog2(self.t_pad * self.h_pad * self.head_dim),
            "Kv": clog2(self.t_pad * self.kv_heads * self.head_dim),
            "S": clog2(self.h_pad * self.t_pad * self.t_pad),
            "F": clog2(self.t_pad * self.f_pad),
            "Tab": clog2(256),
        }[dom]

    def true_size(self, dom):
        return {
            "T": self.tokens,
            "Ht": self.q_heads * self.tokens,
            "L": 3 * 3 * self.tokens,
            "D": self.tokens * self.width,
            "Q": self.tokens * self.q_heads * self.head_dim,
            "Kv": self.tokens * self.kv_heads * self.head_dim,
            "S": self.q_heads * self.tokens * self.tokens,
            "F": self.tokens * self.hidden,
            "Tab": 256,
        }[dom]

    def carries_h(self, dom):
        return dom not in ("T", "Ht")

    def log(self, dom):
        nat = self.natural_log(dom)
        return self.log_cols if (self.carries_h(dom) and nat < self.log_cols) else nat

    def size(self, dom):
        return 1 << self.log(dom)

    def pads(self, dom):
        return self.size(dom) != self.true_size(dom)

    def lookups_per_position(self, dom):
        ln = self.limbs_norm()
        top = 0 if self.norm_top_is_full_byte() else 1
        per_norm = 2 + 2 * (ln + top)
        return {
            "L": 2,
            "D": 2 + per_norm + 6 + per_norm + 2 + 4,
            "F": 9,
            "Q": 13,
            "Kv": 12,
            "S": 2 + 2 + (self.limbs_p() + 1) + 2 * (self.limbs_sigma_s() + 1),
            "T": 0,
            "Ht": 0,
            "Tab": 0,
        }[dom]

    def helpers(self, dom):
        return -(-self.lookups_per_position(dom) // 2)

    def a_planes_on(self, dom):
        ln = self.limbs_norm()
        return {
            "T": 4,
            "Ht": 2,
            "L": 2,
            "D": 4 + 2 * ln + 8 + 2 * ln + 7,
            "Q": 7,
            "Kv": 6,
            "S": 5 + self.limbs_p() + 2 * self.limbs_sigma_s(),
            "F": 11,
            "Tab": 3,
        }[dom]

    def zero_rule_a(self, dom):
        """pad.rs a_rule: every A plane on a padded domain is ZERO but A_E"""
        if not self.pads(dom):
            return 0
        n = self.a_planes_on(dom)
        return n - 1 if dom == "S" else n  # A_E is the one EXEMPT plane

    def lkv(self):
        return clog2(self.kv_heads)

    def slots(self):
        """(main rounds, ext rounds, declared degree) per slot -- shape.rs:1139"""
        BASE = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2]
        IND = {0: "D", 1: "D", 4: "S", 14: "D", 15: "Q", 16: "Kv", 17: "S", 18: "F"}
        cube = {0: "D", 1: "D", 2: "T", 3: "L", 4: "S", 14: "D", 15: "Q", 16: "Kv",
                17: "S", 18: "F", 19: "Tab", 20: "Tab", 21: "D", 22: "D"}
        lkv = self.lkv()
        inner = {5: clog2(self.d_pad), 6: clog2(self.d_pad), 7: clog2(self.d_pad),
                 10: clog2(self.d_pad), 11: clog2(self.d_pad), 12: clog2(self.d_pad),
                 8: lkv + clog2(self.head_dim), 9: lkv + clog2(self.t_pad),
                 13: clog2(self.f_pad)}
        out = []
        for s in range(23):
            main = self.log(cube[s]) if s in cube else inner[s]
            ind = s in IND and self.pads(IND[s])
            ext = 2 if s in (8, 9) else 1
            grp = s in (8, 9) and lkv > 0
            out.append((main, ext, BASE[s] + int(ind) + int(grp)))
        return out

    def pad_on(self, slot):
        """argument.rs:1115 -- the domains whose pad-zero term THIS slot hosts"""
        host = {"T": 2, "Ht": 17, "L": 3, "D": 14, "Q": 15, "Kv": 16, "S": 17,
                "F": 18, "Tab": 19}
        return [d for d, h in host.items() if h == slot and self.zero_rule_a(d) > 0]


W14 = Shape("rung-W14", 64, 768, 1024, 12, 64, 4, 14, 12)
M125 = Shape("125M", 512, 768, 2048, 12, 64, 4, 14, 9)

SLOT_KIND = ["Private", "Private", "Host", "Standalone", "Private", "Private",
             "Private", "Private", "Private", "Private", "Private", "Private",
             "Private", "Private", "Host", "Host", "Host", "Host", "Host",
             "Standalone", "Standalone", "Standalone", "Standalone"]

SLOT_NAME = ["SC_SS", "SC_SSM", "SC_TZC", "SC_LZC", "SC_RS", "SC_QMM", "SC_KMM",
             "SC_VMM", "SC_SCORE", "SC_PV", "SC_WO", "SC_GMM", "SC_UMM", "SC_DMM",
             "SC_DZC", "SC_QZC", "SC_KVZC", "SC_SZC", "SC_FZC", "SC_TAB", "SC_ZS",
             "SC_IO_IN", "SC_IO_OUT"]

# ---------------------------------------------------------------- helpers
# the three shared functions of argument.rs, transliterated


def limbs(vals, ctr, opt=False):
    """argument.rs:825  sum_k v[ix[k]] * pow256(k)  -- k STARTS AT ZERO, so the
    first term is a full Fp2::mul by ONE.  Under (b) the k=0 coefficient is
    typed `Coef::One` (free) and the rest are `Coef::Base` (mul_base)."""
    acc = V([ZERO], ctr)
    for kk, v in enumerate(vals):
        c = pow(256, kk, P)
        if opt:
            acc = acc.add(v if c == 1 else v.mul_base(c))
        else:
            acc = acc.add(v.mul(konst(ctr, c)))
    return acc


def helper_sum(hs, dens_tables, alpha, mu, ctr, opt=False):
    """argument.rs:854.  `dens_tables[i]` is the ONE table term of lookup i;
    `den(l) = alpha - (cst + v*c)` with c a base coefficient (mul_base)."""
    n_lk = len(dens_tables)
    acc = V([ZERO], ctr)
    dens = []
    for i in range(n_lk):
        cst = chal(ctr)  # Fp2::from_i64(cst) + g_u8 : challenge-tagged
        dens.append(alpha.sub(cst.add(dens_tables[i].mul_base(rnd_fp()))))
    for kk in range(-(-n_lk // 2)):
        h = hs[kk]
        d1 = dens[2 * kk]
        if 2 * kk + 1 < n_lk:
            d2 = dens[2 * kk + 1]
            rel = h.mul(d1).mul(d2).sub(d1.add(d2))
        else:
            rel = h.mul(d1).sub(V([ONE], ctr))
        if opt and mu[kk] == "one":
            acc = acc.add(rel)
        else:
            acc = acc.add(mu[kk].mul(rel))
    return acc


def pad_term(groups, mu, ctr, opt=False):
    """argument.rs:916 PadTerm::eval.  `groups` is a list of (supp, [planes]).
    NOTE: with no group at all the closure still runs `self.mu.mul(acc)`."""
    acc = V([ZERO], ctr)
    first = True
    for supp, planes in groups:
        anti = V([ONE], ctr).sub(supp)
        inner = V([ZERO], ctr)
        for pl in planes:
            if opt and first:
                inner = inner.add(pl)  # zeta^0 == ONE
            else:
                inner = inner.add(chal(ctr).mul(pl))
            first = False
        acc = acc.add(anti.mul(inner))
    if opt and not groups:
        return acc
    return mu.mul(acc)


# ---------------------------------------------------------------- the slots
# Each builder returns (counter, value).  `opt` turns on lever (b):
#   * the support gate hoisted out of the clause loop
#   * public BASE constants multiplied with mul_base
#   * common sub-products named once
#   * coefficients that are literally ONE costed at nothing


def kmul(x, n, ctr, opt):
    """x * k(n): a PUBLIC BASE constant"""
    if opt:
        if n % P == 1:
            return x
        return x.mul_base(n % P)
    return x.mul(konst(ctr, n))


def build(slot, sh, opt=False):
    ctr = Counter()
    pads = sh.pad_on(slot)
    pad_on = len(pads) > 0
    ln, ls, lp = sh.limbs_norm(), sh.limbs_sigma_s(), sh.limbs_p()

    def T(base=True):
        return table(ctr, base)

    def gate(dom):
        """B::supp -> Gate: a base-valued public indicator, or the constant ONE"""
        return T(True) if sh.pads(dom) else None

    def gat(g):
        return g if g is not None else V([ONE], ctr)

    alpha = chal(ctr)
    beta = chal(ctr)

    if slot in (0, 1):  # SC_SS / SC_SSM
        eq, a = T(False), T(True)
        g = gate("D")
        val = gat(g).mul(eq).mul(a).mul(a)
        return ctr, val

    if slot == 2:  # SC_TZC
        mu = chalv(ctr, 6 + int(pad_on))
        nu = chalv(ctr, 2)
        i_tau, i_rt, i_rt2 = T(False), T(False), T(False)
        d, dsq = T(True), T(True)
        limb = [T(True) for _ in range(9)]
        dm, dsqm = T(True), T(True)
        limbm = [T(True) for _ in range(9)]
        gt = gate("T")

        def l3(v3):
            # `l3` is HAND-WRITTEN in the closure and skips the k=0 multiply
            return v3[0].add(kmul(v3[1], 256, ctr, opt)).add(kmul(v3[2], 65536, ctr, opt))

        dl, a1, a2 = l3(limb[0:3]), l3(limb[3:6]), l3(limb[6:9])
        dlm, a1m, a2m = l3(limbm[0:3]), l3(limbm[3:6]), l3(limbm[6:9])
        zc = mu[0].mul(dsq.sub(d.mul(d))).add(mu[1].mul(d.sub(dl))).add(mu[2].mul(d.double().sub(a1).sub(a2)))
        zc = zc.add(mu[3].mul(dsqm.sub(dm.mul(dm)))).add(mu[4].mul(dm.sub(dlm))).add(mu[5].mul(dm.double().sub(a1m).sub(a2m)))
        g = gat(gt)
        groups = []
        if pad_on:
            groups = [(gt, [d, dsq, dm, dsqm])]
        pz = pad_term(groups, mu[6] if pad_on else V([ZERO], ctr), ctr, opt)
        if opt and gt is None:
            host0 = nu[0].mul(i_rt).mul(dsq.add(a1).sub(konst(ctr, 1)))
            host1 = nu[1].mul(i_rt2).mul(dsqm.add(a1m).sub(konst(ctr, 1)))
        else:
            host0 = nu[0].mul(i_rt).mul(g).mul(dsq.add(a1).sub(konst(ctr, 1)))
            host1 = nu[1].mul(i_rt2).mul(g).mul(dsqm.add(a1m).sub(konst(ctr, 1)))
        val = i_tau.mul(zc.add(pz)).add(host0).add(host1)
        return ctr, val

    if slot == 3:  # SC_LZC
        eq = T(False)
        a_limb, a_limbm = T(True), T(True)
        h0 = T(False)
        n_lk = sh.lookups_per_position("L")
        mu = ["one"] * sh.helpers("L") if opt else [V([ONE], ctr) for _ in range(sh.helpers("L"))]
        hs = [h0]
        hsum = helper_sum(hs, [a_limb, a_limbm][:n_lk], alpha, mu, ctr, opt)
        groups = []
        mu_pad = chal(ctr)
        if pad_on:
            si = gate("L")
            groups = [(si, [a_limb, a_limbm])]
        pz = pad_term(groups, mu_pad, ctr, opt)
        val = eq.mul(hsum.add(pz))
        return ctr, val

    if slot == 4:  # SC_RS
        lam = chal(ctr)
        eq, mask, e, zsel = T(False), T(True), T(True), T(True)
        g = gate("S")
        val = gat(g).mul(eq).mul(mask.mul(e).add(lam.mul(zsel)))
        return ctr, val

    if slot in (5, 6, 7, 10, 11, 12, 13):  # the seven matmuls
        # FINDING: the committed plane is read at a FIXED claim point
        # (`coords = fixed(&r_row) ++ rho(..)`), so `priv_table` weights it by
        # eq(r_row) and its words are EXTENSION-valued, not base.
        plane = T(False)
        w = T(False)  # fold_rows/cols_i8 against eq(r_j): extension
        return ctr, plane.mul(w)

    if slot in (8, 9):  # SC_SCORE / SC_PV
        # both private factors are read at fixed coordinates -> extension
        f1, f2 = T(False), T(False)
        if sh.lkv() > 0:
            geq = T(False)
            return ctr, geq.mul(f1).mul(f2)
        return ctr, f1.mul(f2)

    if slot == 14:  # SC_DZC
        n_help = sh.helpers("D")
        n_lk = sh.lookups_per_position("D")
        mu = chalv(ctr, 11 + n_help + int(pad_on))
        nu = chalv(ctr, 2)
        eq_tau, eq_pa, eq_pz = T(False), T(False), T(False)
        ig, igm = T(True), T(True)          # the two padded norm gains (base)
        n_a = sh.a_planes_on("D")
        A = [T(True) for _ in range(n_a)]   # a_range: all on rho, base
        i_nr, i_ns = A[0:ln], A[ln:2 * ln]
        i_mr, i_ms = A[2 * ln:3 * ln], A[3 * ln:4 * ln]
        x, y, ao, x1 = A[0], A[1], A[2], A[3]
        nm, x2, z16 = A[4], A[5], A[6]
        xl, al, x1l, x2l, zl = A[7], A[8], A[9], A[10], A[11]
        xl2, al2, x1l2, x2l2, zl2 = A[12], A[13], A[14], A[15], A[16]
        ral, rdl = A[17], A[18]
        d, dm = T(True), T(True)            # the two Dom::T slices
        hs = [T(False) for _ in range(n_help)]
        gd = gate("D")
        g = gat(gd)

        def l2(a, b):
            return a.add(kmul(b, 256, ctr, opt))

        nr, ns = limbs(i_nr, ctr, opt), limbs(i_ns, ctr, opt)
        mr, ms = limbs(i_mr, ctr, opt), limbs(i_ms, ctr, opt)
        k_num, k_dv, k_den = 2 * 1, 1 << 11, 1 << 12
        if opt:
            kd, kdm = kmul(d, k_den, ctr, opt), kmul(dm, k_den, ctr, opt)
            c0 = kmul(ig.mul(x), k_num, ctr, opt).add(kmul(d, k_dv, ctr, opt)).sub(y.mul(kd)).sub(nr)
            c1 = ns.add(nr).add(V([ONE], ctr)).sub(kd)
            c6 = kmul(igm.mul(x1), k_num, ctr, opt).add(kmul(dm, k_dv, ctr, opt)).sub(nm.mul(kdm)).sub(mr)
            c7 = ms.add(mr).add(V([ONE], ctr)).sub(kdm)
        else:
            c0 = konst(ctr, k_num).mul(ig).mul(x).add(konst(ctr, k_dv).mul(d)).sub(konst(ctr, k_den).mul(y).mul(d)).sub(nr)
            c1 = ns.add(nr).add(V([ONE], ctr)).sub(konst(ctr, k_den).mul(d))
            c6 = konst(ctr, k_num).mul(igm).mul(x1).add(konst(ctr, k_dv).mul(dm)).sub(konst(ctr, k_den).mul(nm).mul(dm)).sub(mr)
            c7 = ms.add(mr).add(V([ONE], ctr)).sub(konst(ctr, k_den).mul(dm))
        c2 = x.add(konst(ctr, 32768)).sub(l2(xl, xl2))
        c3 = ao.add(konst(ctr, 32768)).sub(l2(al, al2))
        c4 = x1.add(konst(ctr, 32768)).sub(l2(x1l, x1l2))
        c5 = x1.sub(x).sub(ao)
        c8 = x2.add(konst(ctr, 32768)).sub(l2(x2l, x2l2))
        c9 = x2.sub(x1).sub(z16)
        c10 = z16.add(konst(ctr, 32768)).sub(l2(zl, zl2))
        hsum = helper_sum(hs, [A[i % n_a] for i in range(n_lk)], alpha, mu[11:], ctr, opt)
        groups = [(gd, A)] if pad_on else []
        pz = pad_term(groups, mu[11 + n_help] if pad_on else V([ZERO], ctr), ctr, opt)
        zc = hsum.add(pz)
        cs = [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10]
        if opt:
            inner = V([ZERO], ctr)
            for m, c in zip(mu, cs):
                inner = inner.add(m.mul(c))
            zc = zc.add(g.mul(inner) if gd is not None else inner)
        else:
            for m, c in zip(mu, cs):
                zc = zc.add(m.mul(g).mul(c))
        host_wo = kmul(ao, 1 << 8, ctr, opt).add(ral).sub(konst(ctr, 1 << 7))
        host_dmm = kmul(z16, 1 << 8, ctr, opt).add(rdl).sub(konst(ctr, 1 << 7))
        if opt and gd is None:
            val = eq_tau.mul(zc).add(nu[0].mul(eq_pa).mul(host_wo)).add(nu[1].mul(eq_pz).mul(host_dmm))
        else:
            val = eq_tau.mul(zc).add(nu[0].mul(eq_pa).mul(g).mul(host_wo)).add(nu[1].mul(eq_pz).mul(g).mul(host_dmm))
        return ctr, val

    if slot == 18:  # SC_FZC
        n_help = sh.helpers("F")
        n_lk = sh.lookups_per_position("F")
        mu = chalv(ctr, 4 + n_help + int(pad_on))
        nu = chalv(ctr, 2)
        eq_tau, eq_g, eq_u = T(False), T(False), T(False)
        n_a = sh.a_planes_on("F")
        A = [T(True) for _ in range(n_a)]
        g8, a16, u16, h16 = A[0], A[1], A[2], A[3]
        ul, ul2, hl, hl2, rh0, rh1, rgl = A[4], A[5], A[6], A[7], A[8], A[9], A[10]
        hs = [T(False) for _ in range(n_help)]
        i_fact = T(False)
        gf = gate("F")
        g = gat(gf)

        def l2(a, b):
            return a.add(kmul(b, 256, ctr, opt))

        f0 = a16.mul(u16).sub(kmul(h16, 1 << 8, ctr, opt)).sub(l2(rh0, rh1)).add(konst(ctr, 1 << 7))
        f1 = u16.add(konst(ctr, 32768)).sub(l2(ul, ul2))
        f2 = h16.add(konst(ctr, 32768)).sub(l2(hl, hl2))
        f_act = i_fact.mul(alpha.sub(g8.add(konst(ctr, 128)).add(beta.mul(a16)).add(chal(ctr)))).sub(V([ONE], ctr))
        hsum = helper_sum(hs, [A[i % n_a] for i in range(n_lk)], alpha, mu[4:], ctr, opt)
        groups = [(gf, A)] if pad_on else []
        pz = pad_term(groups, mu[4 + n_help] if pad_on else V([ZERO], ctr), ctr, opt)
        zc = hsum.add(mu[3].mul(f_act)).add(pz)
        cs = [f0, f1, f2]
        if opt:
            inner = V([ZERO], ctr)
            for m, c in zip(mu, cs):
                inner = inner.add(m.mul(c))
            zc = zc.add(g.mul(inner) if gf is not None else inner)
        else:
            for m, c in zip(mu, cs):
                zc = zc.add(m.mul(g).mul(c))
        host_g = kmul(g8, 1 << 8, ctr, opt).add(rgl).sub(konst(ctr, 1 << 7))
        host_u = u16
        if opt and gf is None:
            val = eq_tau.mul(zc).add(nu[0].mul(eq_g).mul(host_g)).add(nu[1].mul(eq_u).mul(host_u))
        else:
            val = eq_tau.mul(zc).add(nu[0].mul(eq_g).mul(g).mul(host_g)).add(nu[1].mul(eq_u).mul(g).mul(host_u))
        return ctr, val

    if slot in (15, 16):  # SC_QZC / SC_KVZC
        dom = "Q" if slot == 15 else "Kv"
        n_help = sh.helpers(dom)
        n_lk = sh.lookups_per_position(dom)
        mu = chalv(ctr, 1 + n_help + int(pad_on))
        nu = chalv(ctr, 2)
        eq_tau, eq_1, eq_2 = T(False), T(False), T(False)
        ct, st = T(True), T(True)            # the two RoPE tables (base)
        n_a = sh.a_planes_on(dom)
        A = [T(True) for _ in range(n_a)]
        src, rot, rot_rem = A[0], A[1], A[2]
        iflip = T(True)
        hs = [T(False) for _ in range(n_help)]
        gq = gate(dom)
        g = gat(gq)
        rope = ct.mul(src).add(st.mul(iflip)).sub(kmul(rot, 1 << 12, ctr, opt)).sub(rot_rem).add(konst(ctr, 1 << 11))
        hsum = helper_sum(hs, [A[i % n_a] for i in range(n_lk)], alpha, mu[1:], ctr, opt)
        groups = [(gq, A)] if pad_on else []
        pz = pad_term(groups, mu[1 + n_help] if pad_on else V([ZERO], ctr), ctr, opt)
        if opt and gq is None:
            zc = mu[0].mul(rope).add(hsum).add(pz)
        else:
            zc = mu[0].mul(g).mul(rope).add(hsum).add(pz)
        host1 = kmul(A[3], 1 << 8, ctr, opt).add(A[4]).sub(konst(ctr, 1 << 7))
        if slot == 15:
            host2 = kmul(A[5], 1 << 8, ctr, opt).add(A[6]).add(kmul(A[0], 256, ctr, opt)).sub(konst(ctr, 1 << 7))
        else:
            host2 = kmul(A[5], 1 << 8, ctr, opt).add(A[0]).sub(konst(ctr, 1 << 7))
        if opt and gq is None:
            val = eq_tau.mul(zc).add(nu[0].mul(eq_1).mul(host1)).add(nu[1].mul(eq_2).mul(host2))
        else:
            val = eq_tau.mul(zc).add(nu[0].mul(eq_1).mul(g).mul(host1)).add(nu[1].mul(eq_2).mul(g).mul(host2))
        return ctr, val

    if slot == 17:  # SC_SZC
        n_help = sh.helpers("S")
        n_lk = sh.lookups_per_position("S")
        mu = chalv(ctr, 5 + n_help + 1 + int(pad_on))
        nu = chalv(ctr, 2)
        lam = chal(ctr)
        eq_tau, eq_ht, eq_s = T(False), T(False), T(False)
        mask = T(True)
        n_a = sh.a_planes_on("S")
        A = [T(True) for _ in range(n_a)]
        s8, rsl, zsel, e, p = A[0], A[1], A[2], A[3], A[4]
        i_pl = A[5:5 + lp]
        i_sr = A[5 + lp:5 + lp + ls]
        i_sg = A[5 + lp + ls:5 + lp + 2 * ls]
        mx, ssum = T(True), T(True)
        hs = [T(False) for _ in range(n_help)]
        ihx = T(False)
        ght, gs = gate("Ht"), gate("S")
        g = gat(gs)
        sr = limbs(i_sr, ctr, opt)
        delta = mx.sub(mask.mul(s8.add(konst(ctr, 127)))).add(konst(ctr, 127))
        c0 = zsel.mul(zsel).sub(zsel)
        c1 = zsel.mul(delta)
        c2 = kmul(mask, 1 << 9, ctr, opt).mul(e).sub(p.mul(ssum)).sub(sr)
        c3 = limbs(i_sg, ctr, opt).add(sr).add(V([ONE], ctr)).sub(ssum)
        c4 = p.sub(limbs(i_pl, ctr, opt))
        cx = ihx.mul(alpha.sub(delta.add(beta.mul(e)).add(chal(ctr)))).sub(V([ONE], ctr))
        hsum = helper_sum(hs, [A[i % n_a] for i in range(n_lk)], alpha, mu[5:5 + n_help], ctr, opt)
        groups = []
        if pad_on:
            groups = [(ght, [mx, ssum]), (gs, A[:n_a - 1])]  # A_E is EXEMPT
        pz = pad_term(groups, mu[5 + n_help + 1] if pad_on else V([ZERO], ctr), ctr, opt)
        zc = hsum.add(mu[5 + n_help].mul(cx)).add(pz)
        cs = [c0, c1, c2, c3, c4]
        if opt:
            inner = V([ZERO], ctr)
            for m, c in zip(mu, cs):
                inner = inner.add(m.mul(c))
            zc = zc.add(g.mul(inner) if gs is not None else inner)
        else:
            for m, c in zip(mu, cs):
                zc = zc.add(m.mul(g).mul(c))
        host_rs = ssum.add(lam)
        host_s = kmul(s8, 1 << 8, ctr, opt).add(rsl).sub(konst(ctr, 1 << 7))
        val = eq_tau.mul(zc).add(nu[0].mul(eq_ht).mul(gat(ght)).mul(host_rs)).add(nu[1].mul(eq_s).mul(g).mul(host_s))
        return ctr, val

    if slot == 19:  # SC_TAB
        mu = chalv(ctr, 3 + int(pad_on))
        eq = T(False)
        m0, h0, v0 = T(True), T(False), T(True)    # U8 values: see FINDING
        m1, h1, v1 = T(True), T(False), T(False)   # exp values: extension
        m2, h2, v2 = T(True), T(False), T(False)   # act values: extension
        r0 = h0.mul(alpha.sub(v0)).sub(m0)
        r1 = h1.mul(alpha.sub(v1)).sub(m1)
        r2 = h2.mul(alpha.sub(v2)).sub(m2)
        groups = []
        if pad_on:
            si = gate("Tab")
            groups = [(si, [m0, m1, m2]), (si, [h0, h1, h2])]
        pz = pad_term(groups, mu[3] if pad_on else V([ZERO], ctr), ctr, opt)
        val = eq.mul(mu[0].mul(r0).add(mu[1].mul(r1)).add(mu[2].mul(r2)).add(pz))
        return ctr, val

    if slot == 20:  # SC_ZS
        ones, hu = T(True), T(False)
        return ctr, ones.mul(hu)

    if slot in (21, 22):  # SC_IO_IN / SC_IO_OUT
        eq, a, ep = T(False), T(True), T(True)
        return ctr, eq.mul(a.sub(ep))

    raise AssertionError(slot)


# ---------------------------------------------------------------- the model


def table_count(sh, slot):
    """the slot's table count, from shape.rs + argument.rs::define"""
    ln, ls, lp = sh.limbs_norm(), sh.limbs_sigma_s(), sh.limbs_p()
    eq = {0: 1, 1: 1, 2: 3, 3: 1, 4: 1, 14: 3, 15: 3, 16: 3, 17: 3, 18: 3,
          19: 1, 21: 1, 22: 1}.get(slot, 0)
    grp = 1 if slot in (8, 9) and sh.lkv() > 0 else 0
    pub = {4: 1, 5: 1, 6: 1, 7: 1, 10: 1, 11: 1, 12: 1, 13: 1, 14: 2, 15: 2,
           16: 2, 17: 1, 19: 3, 20: 1}.get(slot, 0)
    supp_dom = {0: ["D"], 1: ["D"], 2: ["T"], 3: ["L"], 4: ["S"], 14: ["D"],
                15: ["Q"], 16: ["Kv"], 17: ["Ht", "S"], 18: ["F"], 19: ["Tab"]}
    supp = sum(1 for d in supp_dom.get(slot, []) if sh.pads(d))
    a = {0: 1, 1: 1, 2: 4 + 2 * 9, 3: sh.a_planes_on("L"), 4: 2, 5: 1, 6: 1,
         7: 1, 8: 2, 9: 2, 10: 1, 11: 1, 12: 1, 13: 1,
         14: sh.a_planes_on("D") + 2, 15: sh.a_planes_on("Q") + 1,
         16: sh.a_planes_on("Kv") + 1, 17: sh.a_planes_on("S") + 2,
         18: sh.a_planes_on("F"), 19: 3, 21: 1, 22: 1}.get(slot, 0)
    h = {3: sh.helpers("L"), 14: sh.helpers("D"), 15: sh.helpers("Q"),
         16: sh.helpers("Kv"), 17: sh.helpers("S") + 1,
         18: sh.helpers("F") + 1, 19: 3, 20: 1}.get(slot, 0)
    ep = 1 if slot in (21, 22) else 0
    return dict(eq=eq, grp=grp, pub=pub, supp=supp, a=a, h=h, ep=ep,
                total=eq + grp + pub + supp + a + h + ep)


def base_field_tables(sh, slot):
    """how many of the slot's tables are WHOLLY BASE-FIELD, computed the way
    `priv_table` actually builds them (a plane read at a FIXED coordinate is
    eq-weighted and therefore extension-valued)."""
    tc = table_count(sh, slot)
    # A planes read at a fixed claim point: the seven matmuls and the four
    # bilinear factors
    fixed_a = {5: 1, 6: 1, 7: 1, 8: 2, 9: 2, 10: 1, 11: 1, 12: 1, 13: 1}.get(slot, 0)
    base_pub = {4: 1, 14: 2, 15: 2, 16: 2, 17: 1, 20: 1}.get(slot, 0)  # masks, gains, RoPE, ones
    return tc["a"] - fixed_a + tc["supp"] + tc["ep"] + base_pub


def run(sh):
    sl = sh.slots()
    rows = []
    for s in range(23):
        main, ext, deg = sl[s]
        ctr_b, val_b = build(s, sh, opt=False)
        ctr_o, val_o = build(s, sh, opt=True)
        pairs = (1 << main) - 1
        cube = 1 << main
        tc = table_count(sh, s)
        k = tc["total"]
        # baseline
        loop0 = pairs * ctr_b.baseline(deg)
        fold0 = pairs * k * 5
        tot0 = cube * ctr_b.baseline(deg) // (deg + 1) if SLOT_KIND[s] == "Private" else 0
        # (b)
        loop_b = pairs * ctr_o.baseline(deg)
        # (a) on top of (b): round 0 is 2^(main-1) of the pair indices
        r0 = 1 << (main - 1)
        loop_a = (pairs - r0) * ctr_o.baseline(deg) + r0 * ctr_o.with_a(deg)
        nbase = base_field_tables(sh, s)
        fold_a = (pairs - r0) * k * 5 + r0 * ((k - nbase) * 5 + nbase * 2)
        # (c) on top of (a) and (b)
        loop_c = (pairs - r0) * ctr_o.with_c(deg, narrow=False) + r0 * ctr_o.with_c(deg, narrow=True)
        adds_c = pairs * ctr_o.fd_additions(deg)
        rows.append(dict(
            slot=s, name=SLOT_NAME[s], kind=SLOT_KIND[s], main=main, ext=ext,
            degree=deg, true_degree=val_b.deg, tables=k, base_tables=nbase,
            mul=ctr_b.n_mul(), mulbase=ctr_b.n_mulbase(),
            mul_opt=ctr_o.n_mul(), mulbase_opt=ctr_o.n_mulbase(),
            fp_per_eval=5 * ctr_b.n_mul() + 2 * ctr_b.n_mulbase(),
            loop0=loop0, fold0=fold0, total0=tot0,
            loop_b=loop_b, loop_a=loop_a, fold_a=fold_a, loop_c=loop_c,
            adds_c=adds_c, tc=tc))
    return rows


def report(sh):
    rows = run(sh)
    out = []
    out.append(f"=== {sh.name} ===")
    out.append(f"  t_pad {sh.t_pad} d_pad {sh.d_pad} h_pad {sh.h_pad} f_pad {sh.f_pad} "
               f"log_cols {sh.log_cols} f_e {sh.f_e}")
    out.append(f"  limbs_norm {sh.limbs_norm()} full_top {sh.norm_top_is_full_byte()} "
               f"limbs_sigma_s {sh.limbs_sigma_s()} limbs_p {sh.limbs_p()} lkv {sh.lkv()}")
    out.append("  pads: " + ", ".join(f"{d}={sh.pads(d)}" for d in
               ["T", "Ht", "L", "D", "Q", "Kv", "S", "F", "Tab"]))
    out.append("  helpers: " + ", ".join(f"{d}={sh.helpers(d)}" for d in
               ["L", "D", "Q", "Kv", "S", "F"]))
    hdr = ("slot name        main ext deg TRUEdeg tab base  mul mb  mul' mb'   "
           "Fp/eval        loop0         fold0        total0")
    out.append(hdr)
    for r in rows:
        out.append(f"{r['slot']:4d} {r['name']:<11s} {r['main']:4d} {r['ext']:3d} "
                   f"{r['degree']:3d} {r['true_degree']:7d} {r['tables']:4d} "
                   f"{r['base_tables']:4d} {r['mul']:4d} {r['mulbase']:2d} "
                   f"{r['mul_opt']:5d} {r['mulbase_opt']:3d} {r['fp_per_eval']:9d} "
                   f"{r['loop0']:12d} {r['fold0']:13d} {r['total0']:13d}")
    L0 = sum(r["loop0"] for r in rows)
    F0 = sum(r["fold0"] for r in rows)
    T0 = sum(r["total0"] for r in rows)
    Lb = sum(r["loop_b"] for r in rows)
    La = sum(r["loop_a"] for r in rows)
    Fa = sum(r["fold_a"] for r in rows)
    Lc = sum(r["loop_c"] for r in rows)
    Ac = sum(r["adds_c"] for r in rows)
    base = L0 + F0 + T0
    out.append("")
    out.append(f"  tables total {sum(r['tables'] for r in rows)}, "
               f"wholly base-field {sum(r['base_tables'] for r in rows)}")
    out.append(f"  main rounds {sum(r['main'] for r in rows)}, "
               f"extension rounds {sum(r['ext'] for r in rows)}")
    out.append("")
    out.append("  form                       round loop           fold   claimed sum          total   marginal")
    out.append(f"  baseline            {L0:16d} {F0:14d} {T0:13d} {base:14d}          -")
    b = Lb + F0 + T0
    out.append(f"  + (b)               {Lb:16d} {F0:14d} {T0:13d} {b:14d}   {100*(base-b)/base:7.1f}%")
    a = La + Fa + T0
    out.append(f"  + (a)               {La:16d} {Fa:14d} {T0:13d} {a:14d}   {100*(b-a)/base:7.1f}%")
    c = Lc + Fa + T0
    out.append(f"  + (c)               {Lc:16d} {Fa:14d} {T0:13d} {c:14d}   {100*(a-c)/base:7.1f}%")
    out.append(f"  all three: {100*(base-c)/base:.1f}% of the baseline removed")
    out.append("")
    out.append("  the same rows, with the marginal read as a share of the PREVIOUS ROW")
    out.append("  (the memo's convention -- its three figures do NOT sum to the total):")
    out.append(f"    (b) {100*(base-b)/base:5.1f}%   (a) {100*(b-a)/b:5.1f}%   (c) {100*(a-c)/a:5.1f}%"
               f"   -- sum {100*((base-b)/base+(b-a)/b+(a-c)/a):.1f}%, total removed {100*(base-c)/base:.1f}%")
    out.append("  and as a share of the BASELINE (these do sum to the total):")
    out.append(f"    (b) {100*(base-b)/base:5.1f}%   (a) {100*(b-a)/base:5.1f}%   (c) {100*(a-c)/base:5.1f}%")
    # each lever ALONE against the baseline
    only_b = Lb + F0 + T0
    onlyA_loop = sum((((1 << r["main"]) - 1) - (1 << (r["main"] - 1))) * 0 for r in rows)
    out.append("")
    out.append("  each lever ALONE, against the baseline:")
    out.append(f"    (b) alone      {only_b:14d}   {100*(base-only_b)/base:5.1f}% removed")
    out.append(f"  finite-difference additions (c) introduces: {Ac} Fp2 adds "
               f"= {2*Ac} Fp adds per proof")
    for ratio in (0.25, 0.5, 1.0):
        pen = int(ratio * 2 * Ac)
        out.append(f"    with an Fp add priced at {ratio:g} of an Fp mul: "
                   f"(c) net {c + pen:d}, total saving {100*(base-c-pen)/base:.1f}%")
    return "\n".join(out), rows, dict(base=base, b=b, a=a, c=c, L0=L0, F0=F0,
                                      T0=T0, Lb=Lb, La=La, Fa=Fa, Lc=Lc, Ac=Ac)


if __name__ == "__main__":
    blobs = {}
    texts = []
    for sh in (W14, M125):
        txt, rows, tot = report(sh)
        texts.append(txt)
        blobs[sh.name] = dict(totals=tot, rows=[{k: v for k, v in r.items() if k != "tc"} for r in rows],
                              tables=[r["tc"] for r in rows])
    text = "\n\n".join(texts)
    print(text)
    with open(sys.argv[1] if len(sys.argv) > 1 else "/dev/null", "w") as f:
        f.write(text + "\n")
    if len(sys.argv) > 2:
        with open(sys.argv[2], "w") as f:
            json.dump(blobs, f, indent=1)
