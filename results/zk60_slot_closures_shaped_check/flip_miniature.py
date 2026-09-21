"""The miniature the memo says it did NOT build (§6.3 item 4): a slot whose
two private tables are the SAME PLANE read at two points, differing in one
FLIPPED coordinate -- `argument.rs:1366-1368`, slots 15 and 16's RoPE partner.

Everything below is ported from the Rust at lane commit 8c5922b:
  `priv_table` / `claim_point` / `table_of`   argument.rs:173-231
  `mask_eval` / `build_claim`                 argument.rs:252-278
  `run_slot`'s prove and verify arms          argument.rs:299-442
  `masked_prove` / `extension`                zk.rs:1077-1102
  `CfsMask` / `extension_round` / `masked_terminal`  sumcheck.rs:196-314
  `sumcheck::prove` / `::verify`              sumcheck.rs:44-160

What is checked, on GENERIC random data, several seeds, and for six values of
the reserved-pair evaluations pi (four random, pi = 0, both pairs equal):

  F1  poly(exts) = 0 at the extension round, for EVERY pi (clause C4 strong)
  F2  the verifier's chain accepts the UNMASKED transcript for every pi
      (T'(w, pi) in C)
  F3  the verifier's g_val equals the mask's own g(rho_full) (clause C2)
  F4  every terminal equals cd * T(point) + cm * P, with the RIGHT pair for
      each of the two claims on the one plane (clause C1)
  F5  the two claims' reserved pairs are disjoint, and their PCS column keys
      differ (`part_key_at`, protocol.rs:186-192) -- the property that decides
      whether the flipped partner collapses an opening group
  F6  the published word count is 1 + N(d+1) + terms (clause C6)
  F7  T'(w,pi) - T'(w',pi') lies in Im R for every pair (disclosed dimension
      0 of the sumcheck channel), and the variations are not all zero
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fp2 import F2, ONE, ZERO, U, Rng, rank, in_span, P, inv  # noqa: E402

HALF = F2(inv(2), 0)

# ---------------------------------------------------------------- mle


def eq_table_msb(r):
    """mle.rs:48-52 -- `eq_table(r.rev())`, so r[0] is the MOST significant
    index bit.  (Dropping the reversal is a real trap: the sum
    `sum_x eq(a)[x] eq(b)[x]` still equals eq_point(a, b) with BOTH tables
    built wrongly, so an eq-vs-eq self-test does not catch it.)"""
    t = [ONE]
    for x in reversed(r):
        t = [a * (ONE - x) for a in t] + [a * x for a in t]
    return t


def eq_point(r, s):
    acc = ONE
    for a, b in zip(r, s):
        acc = acc * (a * b + (ONE - a) * (ONE - b))
    return acc


def eval_mle_ext(v, r):
    t = list(v)
    for x in r:
        h = len(t) // 2
        t = [t[i] + x * (t[i + h] - t[i]) for i in range(h)]
    return t[0]


def interpolate_eval(vals, x):
    n = len(vals)
    acc = ZERO
    for i in range(n):
        num, den = ONE, ONE
        for k in range(n):
            if k == i:
                continue
            num = num * (x - F2(k, 0))
            den = den * F2((i - k) % P, 0)
        acc = acc + vals[i] * num * den.inv()
    return acc


# ---------------------------------------------------------------- CfsMask


class CfsMask:
    def __init__(self, n_vars, degree, coeffs):
        self.n = n_vars
        self.d = degree
        self.c = coeffs

    @staticmethod
    def length(n, d):
        return n * d + 2

    def a(self, j, e):
        return self.c[2 + j * self.d + (e - 1)]

    def u(self, j, x):
        acc, xp = ZERO, ONE
        for e in range(1, self.d + 1):
            xp = xp * x
            acc = acc + self.a(j, e) * xp
        return acc

    @staticmethod
    def sum_weights(n, d):
        w = [F2(pow(2, n - 1, P), 0)] * CfsMask.length(n, d)
        w[0] = F2(pow(2, n, P), 0)
        w[1] = ONE
        return w

    @staticmethod
    def eval_weights(rho, d):
        w = [ONE]
        pr = ONE
        for r in rho:
            pr = pr * r
        w.append(pr)
        for r in rho:
            xp = ONE
            for _ in range(d):
                xp = xp * r
                w.append(xp)
        return w

    def total(self):
        return sum((w * c for w, c in zip(self.sum_weights(self.n, self.d), self.c)), ZERO)

    def eval(self, rho):
        assert len(rho) == self.n
        return sum((w * c for w, c in zip(self.eval_weights(rho, self.d), self.c)), ZERO)

    def round(self, j, prev):
        assert len(prev) == j
        base = self.c[0]
        for i, r in enumerate(prev):
            base = base + self.u(i, r)
        for i in range(j + 1, self.n):
            base = base + self.u(i, ONE) * HALF
        scale = F2(pow(2, self.n - 1 - j, P), 0)
        pp = ONE
        for r in prev:
            pp = pp * r
        out = []
        for x in range(self.d + 1):
            xv = F2(x, 0)
            out.append(scale * (base + self.u(j, xv)) + self.c[1] * pp * xv)
        return out


# ---------------------------------------------------------------- tables


RHO, FLIP, FIXED = 0, 1, 2


class Priv:
    def __init__(self, cm, slices, log, coords, mask_row, ext_round):
        self.cm, self.slices, self.log = cm, slices, log
        self.coords, self.mask_row, self.ext_round = coords, mask_row, ext_round


def claim_point(p, rho):
    out = []
    for kind, val in p.coords:
        if kind == RHO:
            out.append(rho[val])
        elif kind == FLIP:
            out.append(ONE - rho[val])
        else:
            out.append(val)
    return out


def priv_table(p, data, n_vars):
    """argument.rs:186-219, verbatim."""
    fixed = [v for k, v in p.coords if k == FIXED]
    eqf = eq_table_msb(fixed)
    used = 0
    for kind, val in p.coords:
        if kind in (RHO, FLIP):
            used |= 1 << (n_vars - 1 - val)
    out = [ZERO] * (1 << n_vars)
    for idx in range(1 << p.log):
        x, z = 0, 0
        for j, (kind, val) in enumerate(p.coords):
            b = (idx >> (p.log - 1 - j)) & 1
            if kind == RHO:
                x |= b << (n_vars - 1 - val)
            elif kind == FLIP:
                x |= (1 - b) << (n_vars - 1 - val)
            else:
                z = (z << 1) | b
        v = ZERO
        for off, coef in p.slices:
            v = v + coef * F2(data[off + idx], 0)
        out[x] = out[x] + eqf[z] * v
    for x in range(len(out)):
        if x & ~used != 0:
            out[x] = out[x & used]
    return out


def mask_eval(log_n, p, data, point):
    """argument.rs:252-261."""
    n = 1 << log_n
    logm = min(p.log, log_n)
    c0 = (p.slices[0][0] % n) if p.log < log_n else 0
    eq = eq_table_msb(point[p.log - logm:])
    def row(r):
        return sum((e * F2(data[r * n + c0 + i], 0) for i, e in enumerate(eq)), ZERO)
    return row(p.mask_row) + U * row(p.mask_row + 1)


def build_claim(log_n, p, point, cd, cm, value):
    """argument.rs:264-278 -- (parts, value); a part is (offset, log_size, coef, point)."""
    n = 1 << log_n
    logm = min(p.log, log_n)
    c0 = (p.slices[0][0] % n) if p.log < log_n else 0
    tail = point[p.log - logm:]
    parts = [(off, p.log, coef * cd, list(point)) for off, coef in p.slices]
    for k, u in enumerate([ONE, U]):
        parts.append(((p.mask_row + k) * n + c0, logm, cm * u, list(tail)))
    return {"parts": parts, "value": value}


def part_key(part, log_n):
    """protocol.rs:186-192 `part_key_at`."""
    off, ls, _coef, point = part
    n = 1 << log_n
    c0, ln = (0, n) if ls >= log_n else (off % n, 1 << ls)
    tail = [] if not point else point[max(0, ls - log_n):]
    return (tuple((t.a, t.b) for t in tail), c0, ln)


# ---------------------------------------------------------------- the slot


LOG = 4          # the slot's cube: 16 positions
LDH = 2          # log2(head_dim); the partner bit sits at LOG - LDH
LOG_N = 3        # the commitment's row width: 8 columns
A_ROWS = 10      # rows of the A commitment (2 data rows + reserved pairs)
H_ROWS = 8
DEG = 4
EXT = 1


def build_slot(rng, seed_data):
    """The tables of a slot modelled on SC_QZC (`argument.rs:1344-1403`), with
    the flipped RoPE partner reading the SAME plane at a second point."""
    dr = Rng(seed_data)
    a_data = [dr.u64() % P for _ in range(A_ROWS * (1 << LOG_N))]
    h_data = [dr.u64() % P for _ in range(H_ROWS * (1 << LOG_N))]
    # plane offsets inside A: the source plane at 0 (2 rows of 8 = 16 words)
    src_off, rot_off = 0, 0  # both live in the first 2 rows in this miniature
    # site rows: two per claim, disjoint, as `Layout::a_site` lays them out
    p_src = Priv("A", [(src_off, ONE)], LOG, [(RHO, i) for i in range(LOG)], 2, 0)
    p_rot = Priv("A", [(rot_off, ONE)], LOG, [(RHO, i) for i in range(LOG)], 4, 0)
    cf = [(RHO, i) for i in range(LOG)]
    cf[LOG - LDH] = (FLIP, LOG - LDH)          # argument.rs:1367
    p_flip = Priv("A", [(src_off, ONE)], LOG, cf, 6, 0)
    p_help = Priv("H", [(0, ONE), (1 << LOG_N, U)], LOG, [(RHO, i) for i in range(LOG)], 2, 0)
    return a_data, h_data, [p_src, p_rot, p_flip, p_help]


def make_poly(rng, i_eq, i_cos, i_sin, i_src, i_rot, i_flip, i_help, i_supp, pad_planes):
    mu0, mu1, mu_pad = rng.f2(), rng.f2(), rng.f2()
    alpha, cst, kc = rng.f2(), rng.f2(), rng.f2()
    zeta = rng.f2()

    def poly(v):
        rope = v[i_cos] * v[i_src] + v[i_sin] * v[i_flip] - kc * v[i_rot] + cst
        d1 = alpha - (v[i_src] + cst)
        d2 = alpha - (v[i_rot] + cst)
        hs = mu1 * (v[i_help] * d1 * d2 - (d1 + d2))
        # PadTerm::eval -- mu * (1 - supp) * sum_j zeta^j plane_j
        inner, p = ZERO, ONE
        for t in pad_planes:
            inner = inner + p * v[t]
            p = p * zeta
        pz = mu_pad * ((ONE - v[i_supp]) * inner)
        zc = mu0 * v[i_supp] * rope + hs + pz
        return v[i_eq] * zc

    return poly


def run_one(seed):
    rng = Rng(seed)
    a_data, h_data, privs = build_slot(rng, seed ^ 0xA5A5)
    p_src, p_rot, p_flip, p_help = privs
    tau = rng.vec(LOG)
    cos = rng.vec(1 << LOG)
    sin = rng.vec(1 << LOG)
    # the support indicator is a 0/1 public table that tiles the cube
    supp = [ONE if (x % 4) < 3 else ZERO for x in range(1 << LOG)]

    tabs = [("eq", tau, 0), ("pub", cos, None), ("pub", sin, None),
            ("priv", p_src, None), ("priv", p_rot, None), ("priv", p_flip, None),
            ("priv", p_help, None), ("pub", supp, None)]
    i_eq, i_cos, i_sin, i_src, i_rot, i_flip, i_help, i_supp = range(8)
    # the pad-zero group names PLANES, and the flipped partner is not one of
    # them (`B::tab` maps a plane to the table `a_range` pushed): tables 3, 4.
    poly = make_poly(rng, i_eq, i_cos, i_sin, i_src, i_rot, i_flip, i_help,
                     i_supp, [i_src, i_rot])

    data = {"A": a_data, "H": h_data}

    def table_of(t):
        kind = t[0]
        if kind == "eq":
            point, start = t[1], t[2]
            e = eq_table_msb(point)
            shift = LOG - start - len(point)
            return [e[(x >> shift) & (len(e) - 1)] for x in range(1 << LOG)]
        if kind == "pub":
            return list(t[1])
        return priv_table(t[1], data[t[1].cm], LOG)

    tables = [table_of(t) for t in tabs]
    n_priv = sum(1 for t in tabs if t[0] == "priv")

    # ---- the honest UNMASKED transcript T'(w, pi), for several pi ----
    def unmasked(exts):
        """the honest round messages with no mask, at fixed challenges rho."""
        tb = [list(t) for t in tables]
        rounds = []
        for j in range(LOG):
            half = len(tb[0]) // 2
            acc = [ZERO] * (DEG + 1)
            for i in range(half):
                cur = [t[i] for t in tb]
                dif = [t[i + half] - t[i] for t in tb]
                acc[0] = acc[0] + poly(cur)
                for d in range(1, DEG + 1):
                    cur = [c + dd for c, dd in zip(cur, dif)]
                    acc[d] = acc[d] + poly(cur)
            rounds.append(acc)
            r = rho[j]
            tb = [[t[i] + r * (t[i + half] - t[i]) for i in range(half)] for t in tb]
        finals = [t[0] for t in tb]
        # the extension round, `sumcheck::extension_round`
        sk = []
        for x in range(DEG + 1):
            xv = F2(x, 0)
            sk.append(poly([f + xv * (e - f) for f, e in zip(finals, exts)]))
        rounds.append(sk)
        total = sum((poly([t[x] for t in tables]) for x in range(1 << LOG)), ZERO)
        cur = [f + rho_e * (e - f) for f, e in zip(finals, exts)]
        return total, rounds, finals, cur

    rho = rng.vec(LOG)
    rho_e = rng.f2()
    while rho_e.is_zero() or rho_e == ONE:
        rho_e = rng.f2()
    rho_full = rho + [rho_e]
    N = LOG + EXT

    # the honest pi (what the prover actually computes)
    honest_pi = {}
    for t in tabs:
        if t[0] == "priv":
            p = t[1]
            honest_pi[id(p)] = mask_eval(LOG_N if p.cm == "A" else LOG_N, p,
                                         data[p.cm], claim_point(p, rho))

    res = {"seed": seed, "checks": {}}

    # ---- F1 / F2: the premise and the chain, for EVERY pi ----------
    pis = []
    r2 = Rng(seed ^ 0xBEEF)
    for _ in range(4):
        pis.append([r2.f2() for _ in range(n_priv)])
    pis.append([ZERO] * n_priv)
    pis.append([F2(7, 3)] * n_priv)          # all pair values equal
    pis.append([honest_pi[id(t[1])] for t in tabs if t[0] == "priv"])

    f1 = f2 = True
    variations = []
    for pv in pis:
        exts = []
        k = 0
        for t in tabs:
            if t[0] == "priv" and t[1].ext_round == 0:
                exts.append(pv[k])
                k += 1
            else:
                if t[0] == "priv":
                    k += 1
                exts.append(ZERO)
        if not poly(exts).is_zero():
            f1 = False
        total, rounds, finals, cur = unmasked(exts)
        claim = total
        for j, s in enumerate(rounds):
            if not (s[0] + s[1] == claim):
                f2 = False
                break
            claim = interpolate_eval(s, rho_full[j])
        variations.append([total] + [x for r in rounds for x in r])
    res["checks"]["F1_premise_every_pi"] = f1
    res["checks"]["F2_chain_every_pi"] = f2

    # ---- the MASKED run, honest pi ---------------------------------
    exts = []
    for t in tabs:
        if t[0] == "priv":
            exts.append(honest_pi[id(t[1])] if t[1].ext_round == 0 else ZERO)
        else:
            exts.append(ZERO)
    total, rounds_un, finals, cur = unmasked(exts)
    mask = CfsMask(N, DEG, rng.vec(CfsMask.length(N, DEG)))
    c = rng.f2()
    scalar = total + c * mask.total()
    rounds = []
    for j in range(N):
        g = mask.round(j, rho_full[:j])
        rounds.append([s + c * gg for s, gg in zip(rounds_un[j], g)])
    terms = [masked for masked in
             [f + rho_e * (e - f) for f, e in zip(finals, exts)]]
    terms = [t for t, tb in zip(terms, tabs) if tb[0] == "priv"]

    # ---- the VERIFIER (argument.rs:373-399) ------------------------
    claim = scalar
    ok_chain = True
    for j, s in enumerate(rounds):
        if not (s[0] + s[1] == claim):
            ok_chain = False
        claim = interpolate_eval(s, rho_full[j])
    fin = claim
    sel = ONE - rho_e
    vals, k = [], 0
    for t in tabs:
        if t[0] == "eq":
            vals.append(sel * eq_point(t[1], rho[t[2]:t[2] + len(t[1])]))
        elif t[0] == "pub":
            vals.append(sel * eval_mle_ext(t[1], rho))
        else:
            vals.append(terms[k])
            k += 1
    g_val = (fin - poly(vals)) * c.inv()
    res["checks"]["F2b_masked_chain"] = ok_chain
    res["checks"]["F3_g_val_is_mask_eval"] = (g_val == mask.eval(rho_full))

    # ---- F4: terminal = cd * T(point) + cm * P ---------------------
    cd = ONE - rho_e
    f4, claims = True, []
    k = 0
    for t in tabs:
        if t[0] != "priv":
            continue
        p = t[1]
        cm = rho_e          # the single extension round: cm = e_0
        pt = claim_point(p, rho)
        tv = eval_mle_ext(priv_table(p, data[p.cm], LOG), rho)
        pp = mask_eval(LOG_N, p, data[p.cm], pt)
        if not (terms[k] == cd * tv + cm * pp):
            f4 = False
        claims.append(build_claim(LOG_N, p, pt, cd, cm, terms[k]))
        k += 1
    res["checks"]["F4_terminal_decomposition"] = f4
    res["checks"]["cd_nonzero"] = not cd.is_zero()
    res["checks"]["cm_nonzero"] = not rho_e.is_zero()

    # ---- F5: the two claims on the ONE plane ------------------------
    c_src, c_flip = claims[0], claims[2]
    rows_src = {p[0] // (1 << LOG_N) for p in c_src["parts"][1:]}
    rows_flip = {p[0] // (1 << LOG_N) for p in c_flip["parts"][1:]}
    res["checks"]["F5_pairs_disjoint"] = rows_src.isdisjoint(rows_flip)
    res["checks"]["F5_same_plane_same_offset"] = (c_src["parts"][0][0] == c_flip["parts"][0][0])
    ks = {part_key(p, LOG_N) for p in c_src["parts"]}
    kf = {part_key(p, LOG_N) for p in c_flip["parts"]}
    res["checks"]["F5_one_key_per_claim"] = (len(ks) == 1 and len(kf) == 1)
    res["checks"]["F5_keys_differ"] = (ks != kf)

    # ---- F6: the published word count -------------------------------
    words = 1 + len(rounds) * (DEG + 1) + len(terms)
    res["checks"]["F6_words"] = words
    res["checks"]["F6_formula"] = 1 + N * (DEG + 1) + n_priv
    res["checks"]["F6_match"] = (words == 1 + N * (DEG + 1) + n_priv)

    # ---- F7: the disclosed dimension --------------------------------
    L = CfsMask.length(N, DEG)
    Rrows = []
    Rrows.append(CfsMask.sum_weights(N, DEG))
    basis = []
    for i in range(L):
        e = [ZERO] * L
        e[i] = ONE
        m = CfsMask(N, DEG, e)
        col = [m.total()]
        for j in range(N):
            col.extend(m.round(j, rho_full[:j]))
        basis.append(col)
    diffs = [[a - b for a, b in zip(variations[i], variations[0])]
             for i in range(1, len(variations))]
    res["checks"]["F7_rank_R"] = rank(basis)
    res["checks"]["F7_dim_C"] = N * DEG + 1
    res["checks"]["F7_all_diffs_in_im_R"] = all(in_span(basis, d) for d in diffs)
    res["checks"]["F7_diff_rank"] = rank(diffs)
    return res


def main():
    out = []
    for seed in (1, 2, 3, 4, 5):
        out.append(run_one(0xF11B_0000 + seed))
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "flip_miniature.json")
    json.dump(out, open(p, "w"), indent=1)
    keys = list(out[0]["checks"].keys())
    print("[COMPUTED] flipped-partner miniature, 5 generic seeds, 7 values of pi each")
    for k in keys:
        vs = [r["checks"][k] for r in out]
        allsame = all(v == vs[0] for v in vs)
        print(f"  {k:32s} {vs[0]!r:8s} {'(all 5 seeds agree)' if allsame else vs}")


if __name__ == "__main__":
    main()
