"""Form-E check, item 4: the joint disclosed dimension when ONE hidden plane
lives on TWO commitments under independent masks, tied by a masked-equality
seam.

This is a COPY-AND-EXTEND of the joint-view gate's negative-control model
(`scripts/zk60_native_jv_smallmodel.py` on branch `zk60-native-jointview`,
copied here as `smallmodel_orig.py`).  The original models ONE commitment;
this models TWO, with a plane that is the SAME free variables in both, plus
the seam's published quantities.

    disclosed = rank([M_rand | M_data]) - rank(M_rand)

computed by brute-force dense rank over Fp, exactly as the original.

Faithfulness to source (every structure below is read out of the Rust):

  claim shape           hashline/src/zk_ffn_fresh_io.rs:204-235  `claim()`
                        parts: (data slice, coef 1-e, point rho),
                               (mask row r,   coef e,   point tail),
                               (mask row r+1, coef e*U, point tail)
                        value = the published masked terminal.
  masked terminal       zkp-core/src/sumcheck.rs:312-314
                        masked_terminal(fin, ext, e) = (1-e) fin + e ext
  ext_k                 zk_ffn_fresh_io.rs:201-203 `mask_value` = the mask
                        PAIR evaluated at the column tail, re + U*im.
  seam poly             zk_ffn_fresh_io.rs:198-200  v[0]*(v[1]-v[2])
  batching              zk_ffn_fresh_io.rs / ZK60_PRIVATE_ENDPOINTS_AT_SCALE
                        form 2: nb_d data parts with coefficients mu_c(1-e).
  extension round       zkp-core/src/sumcheck.rs:297-309 + zk.rs:984-997
                        s_k(x) = poly((1-x)fin + x ext) + c*g_k(x)
  CFS mask              zkp-core/src/sumcheck.rs:189-275
  grouping              zkp-core/src/pcs.rs:752-831
  opening view          zkp-core/src/pcs.rs:915-944

NOTHING here establishes a privacy property.  A rank on a small linear model
is evidence about that model.
"""

from __future__ import annotations

import json
import random

from jv_field import (
    F2_ONE,
    F2_ZERO,
    NONRESIDUE,
    P,
    eq_table_msb,
    f2_add,
    f2_mul,
    f2_sub,
    inv,
    rank,
    two_adic_root,
)

N = 4          # message positions per committed row
LOG_N = 2
INV_RATE = 4
NN = N * INV_RATE
COSET = 7
U = (0, 1)     # the Fp2 generator, as in the original model
MINUS1 = (P - 1, 0)


# --------------------------------------------------------------- encoding
def col_functional(j, n=N, nn=NN, q=None):
    """E_j as (msg part, pad part); the toy analogue of encode_row_zk."""
    q = n if q is None else q
    w_nn = two_adic_root(nn.bit_length() - 1)
    w_n = two_adic_root(n.bit_length() - 1)
    xj = COSET * pow(w_nn, j, P) % P
    zn = (pow(xj, n, P) - 1) % P
    ninv = inv(n)
    msg, wns, w_n_inv = [], 1, inv(w_n)
    for _ in range(n):
        msg.append(zn * ninv % P * inv((xj * wns - 1) % P) % P)
        wns = wns * w_n_inv % P
    pad, xp = [], 1
    for _ in range(q):
        pad.append(zn * xp % P)
        xp = xp * xj % P
    return msg, pad


# ------------------------------------------------------------- CFS weights
def cfs_len(n_vars, degree):
    return n_vars * degree + 2


def cfs_sum_weights(n_vars, degree):
    """sumcheck.rs:222-227."""
    w = [(pow(2, n_vars - 1, P), 0) for _ in range(cfs_len(n_vars, degree))]
    w[0] = (pow(2, n_vars, P), 0)
    w[1] = F2_ONE
    return w


def cfs_eval_weights(rho, degree):
    """sumcheck.rs:230-243."""
    w = [F2_ONE]
    prod = F2_ONE
    for r in rho:
        prod = f2_mul(prod, r)
    w.append(prod)
    for r in rho:
        xp = F2_ONE
        for _ in range(degree):
            xp = f2_mul(xp, r)
            w.append(xp)
    return w


def cfs_round_weights(j, prev, n_vars, degree, x):
    """<coeffs, w> = g.round(j, prev)[x]; from sumcheck.rs:255-274."""
    L = cfs_len(n_vars, degree)
    w = [F2_ZERO] * L
    half = (inv(2), 0)
    scale = (pow(2, n_vars - 1 - j, P), 0)
    prod_prev = F2_ONE
    for r in prev:
        prod_prev = f2_mul(prod_prev, r)
    xv = (x % P, 0)
    w[0] = f2_add(w[0], scale)
    for i, r in enumerate(prev):
        xp = F2_ONE
        for e in range(1, degree + 1):
            xp = f2_mul(xp, r)
            k = 2 + i * degree + (e - 1)
            w[k] = f2_add(w[k], f2_mul(scale, xp))
    for i in range(j + 1, n_vars):
        for e in range(1, degree + 1):
            k = 2 + i * degree + (e - 1)
            w[k] = f2_add(w[k], f2_mul(scale, half))
    xp = F2_ONE
    for e in range(1, degree + 1):
        xp = f2_mul(xp, xv)
        k = 2 + j * degree + (e - 1)
        w[k] = f2_add(w[k], f2_mul(scale, xp))
    w[1] = f2_add(w[1], f2_mul(prod_prev, xv))
    return w


# ------------------------------------------------------ coordinate algebra
class Coords:
    def __init__(self):
        self.n = 0

    def alloc(self, k):
        i = self.n
        self.n += k
        return i


def add_fp(re, im, coord, w):
    """unknown z in Fp, coefficient w in Fp2."""
    re[coord] = (re[coord] + w[0]) % P
    im[coord] = (im[coord] + w[1]) % P


def add_f2(re, im, c_re, c_im, w):
    """unknown a in Fp2: (w a).re = w0 a_re + 7 w1 a_im, .im = w1 a_re + w0 a_im."""
    re[c_re] = (re[c_re] + w[0]) % P
    re[c_im] = (re[c_im] + NONRESIDUE * w[1]) % P
    im[c_re] = (im[c_re] + w[1]) % P
    im[c_im] = (im[c_im] + w[0]) % P


# ------------------------------------------------------------------- model
class Model:
    """Two commitments (L = the attention side, R = the feed-forward side).

    Row order per side: [plane rows | side-private data rows |
    one reserved pair per claim | proximity pair]."""

    def __init__(self, cfg):
        self.cfg = cfg
        self.rng = random.Random(cfg.get("seed", 1))
        self.co = Coords()
        self.obs = []

    def f2(self):
        return (self.rng.randrange(1, P), self.rng.randrange(P))

    # ------------------------------------------------------------- build
    def build(self):
        c = self.cfg
        self.blocks = c.get("blocks", 1)
        self.rpb = c.get("rows_per_block", 2)
        self.n_plane = self.blocks * self.rpb
        self.n_priv = c.get("n_priv", 1)
        self.n_ord = c.get("n_ord", 2)
        self.n_seams = c.get("n_seams", 1)
        self.q_pad = c.get("q_pad", 4)
        self.n_cols = c.get("n_cols", 3)
        self.aliased = c.get("aliased", True)
        self.nd = self.n_plane + self.n_priv
        self.n_pairs = self.n_ord + self.n_seams
        self.rows = self.nd + 2 * self.n_pairs + 2

        # -------- message-row coordinate bases, per side per row
        self.row_msg = [[None] * self.rows for _ in range(2)]
        if self.aliased:
            for r in range(self.n_plane):
                b = self.co.alloc(N)
                self.row_msg[0][r] = b
                self.row_msg[1][r] = b
        else:
            for k in range(2):
                for r in range(self.n_plane):
                    self.row_msg[k][r] = self.co.alloc(N)
        self.plane_coords = set()
        for r in range(self.n_plane):
            for k in range(2):
                self.plane_coords.update(
                    range(self.row_msg[k][r], self.row_msg[k][r] + N))
        self.data_coords = set(self.plane_coords)
        for k in range(2):
            for r in range(self.n_plane, self.nd):
                self.row_msg[k][r] = self.co.alloc(N)
                self.data_coords.update(range(self.row_msg[k][r],
                                              self.row_msg[k][r] + N))
        for k in range(2):
            for r in range(self.nd, self.rows):
                self.row_msg[k][r] = self.co.alloc(N)
        # -------- pads
        self.pad_base = [self.co.alloc(self.rows * self.q_pad) for _ in range(2)]
        # -------- CFS slots (one per seam, on the feed-forward's M)
        self.slot_vars = (self.rpb.bit_length() - 1) + LOG_N + 1
        self.m_vars = self.slot_vars - 1
        self.slot_deg = 2
        self.cfs_base = [self.co.alloc(2 * cfs_len(self.slot_vars, self.slot_deg))
                         for _ in range(self.n_seams)]
        # -------- a SECOND masking commitment (the attention side's M)
        self.cfs2_base = [self.co.alloc(2 * cfs_len(self.slot_vars, self.slot_deg))
                          for _ in range(c.get("n_slots_m2", 0))]

        # -------- ordinary claims
        self.claims = [[], []]
        self.next_pair = [self.nd, self.nd]
        for k in range(2):
            for _ in range(self.n_ord):
                rw = [F2_ZERO] * self.rows
                for r in range(self.nd):
                    rw[r] = (self.rng.randrange(P), self.rng.randrange(P))
                pr = (self.next_pair[k], self.next_pair[k] + 1)
                self.next_pair[k] += 2
                kap = self.f2()
                rw[pr[0]] = f2_add(rw[pr[0]], kap)
                rw[pr[1]] = f2_add(rw[pr[1]], f2_mul(kap, U))
                self.claims[k].append({"rw": rw, "cw": [self.f2() for _ in range(N)],
                                       "pair": pr, "kind": "ord"})
        self.ord_pairs = [[cl["pair"] for cl in self.claims[k]] for k in range(2)]

        # -------- seams
        self.seams = []
        for i in range(self.n_seams):
            self.add_seam(i)

        # -------- groups (one per claim; merged when the points coincide)
        self.groups = [[[j] for j in range(len(self.claims[k]))] for k in range(2)]
        if c.get("same_terminal_point") and self.n_seams == 2:
            for k in range(2):
                a, b = len(self.claims[k]) - 2, len(self.claims[k]) - 1
                self.groups[k] = [g for g in self.groups[k] if g not in ([a], [b])]
                self.groups[k].append([a, b])
        return self

    def add_seam(self, i):
        c = self.cfg
        if c.get("same_terminal_point") and i == 1:
            rho, e = self.seams[0]["rho"], self.seams[0]["e"]
        else:
            rho = [self.f2() for _ in range(self.m_vars)]
            e = F2_ZERO if c.get("zero_e") else self.f2()
        lrb = self.rpb.bit_length() - 1
        eq_rows = eq_table_msb(rho[:lrb])
        tail = rho[lrb:]
        eq_cols = eq_table_msb(tail)
        mu = [self.f2() for _ in range(self.blocks)] if self.blocks > 1 else [F2_ONE]
        ome = f2_sub(F2_ONE, e)
        seam = {"rho": rho, "e": e, "eq_cols": eq_cols, "mu": mu,
                "c": F2_ZERO if c.get("zero_c") else self.f2(),
                "eqfin": self.f2(), "pairs": []}
        for k in range(2):
            rw = [F2_ZERO] * self.rows
            for b in range(self.blocks):
                for r in range(self.rpb):
                    rw[b * self.rpb + r] = f2_add(
                        rw[b * self.rpb + r],
                        f2_mul(f2_mul(mu[b], eq_rows[r]), ome))
            if c.get("share_pair_with_ordinary") and k == 0:
                pr = self.ord_pairs[0][0]
            elif c.get("two_seams_share_pair") and i == 1:
                pr = self.seams[0]["pairs"][k]
            else:
                pr = (self.next_pair[k], self.next_pair[k] + 1)
                self.next_pair[k] += 2
            if not (c.get("no_pair_on_side") == k):
                rw[pr[0]] = f2_add(rw[pr[0]], e)
                rw[pr[1]] = f2_add(rw[pr[1]], f2_mul(e, U))
            self.claims[k].append({"rw": rw, "cw": eq_cols, "pair": pr,
                                   "kind": "seam"})
            seam["pairs"].append(pr)
        if c.get("shared_terminal_mask"):
            # ONE uniform source blinds BOTH terminals: side 1's seam mask pair
            # holds the same values as side 0's (the zk.rs:1971-1974 hazard,
            # here across two commitments).
            p0, p1 = seam["pairs"]
            self.row_msg[1][p1[0]] = self.row_msg[0][p0[0]]
            self.row_msg[1][p1[1]] = self.row_msg[0][p0[1]]
        self.seams.append(seam)

    # -------------------------------------------- coordinate lookups
    def msgcoord(self, k, row, t):
        return self.row_msg[k][row] + t

    def padcoord(self, k, row, t):
        return self.pad_base[k] + row * self.q_pad + t

    def zero(self):
        return [0] * self.co.n

    # ---------------------------------------------------- observations
    def observe(self):
        c = self.cfg
        self.obs = []
        self.side_obs = [[], []]
        width = N + self.q_pad
        for k in range(2):
            out = self.side_obs[k]
            # (a) claim values
            for cl in self.claims[k]:
                re, im = self.zero(), self.zero()
                for i in range(self.rows):
                    if cl["rw"][i] == F2_ZERO:
                        continue
                    for t in range(N):
                        add_fp(re, im, self.msgcoord(k, i, t),
                               f2_mul(cl["rw"][i], cl["cw"][t]))
                out += [re, im]
            # (b) group vectors and (c) the proximity vector
            rhos = []
            for g in self.groups[k]:
                rho = [F2_ZERO] * self.rows
                for j in g:
                    lam = self.f2() if len(g) > 1 else F2_ONE
                    for i in range(self.rows):
                        rho[i] = f2_add(rho[i], f2_mul(lam, self.claims[k][j]["rw"][i]))
                rhos.append(rho)
            rhos.append([self.f2() for _ in range(self.rows)])
            if c.get("opened_twice") and k == 0:
                rhos.append([self.f2() for _ in range(self.rows)])
            for rho in rhos:
                for t in range(width):
                    re, im = self.zero(), self.zero()
                    for i in range(self.rows):
                        if rho[i] == F2_ZERO:
                            continue
                        coord = (self.msgcoord(k, i, t) if t < N
                                 else self.padcoord(k, i, t - N))
                        add_fp(re, im, coord, rho[i])
                    out += [re, im]
            # (d) the sampled columns: one Fp functional per (row, column)
            pool = list(range(NN))
            self.rng.shuffle(pool)
            colsets = [sorted(pool[: self.n_cols])]
            if c.get("opened_twice") and k == 0:
                rest = [j for j in pool if j not in colsets[0]]
                colsets.append(sorted(rest[: self.n_cols]))
            for cs in colsets:
                for j in cs:
                    msg, pad = col_functional(j, q=self.q_pad)
                    for i in range(self.rows):
                        v = self.zero()
                        for t in range(N):
                            v[self.msgcoord(k, i, t)] = msg[t]
                        for t in range(self.q_pad):
                            v[self.padcoord(k, i, t)] = pad[t]
                        out.append(v)
            self.obs += out
        # ---- the seam arguments (a JOINT channel: neither side alone)
        self.seam_obs = []
        if c.get("include_seam_argument", True):
            for i, sm in enumerate(self.seams):
                self.observe_seam(i, sm)
        self.obs += self.seam_obs
        # ---- the second masking commitment's independently published functional
        for b in self.cfs2_base:
            re, im = self.zero(), self.zero()
            for j, wj in enumerate(cfs_sum_weights(self.slot_vars, self.slot_deg)):
                add_f2(re, im, b + 2 * j, b + 2 * j + 1, wj)
            self.obs += [re, im]
        return self.obs

    def observe_seam(self, i, sm):
        c = self.cfg
        base = self.cfs_base[i]
        cc = sm["c"]

        short = c.get("short_slot", 0)   # this many trailing coefficients FIXED

        def cfs_obs(weights):
            re, im = self.zero(), self.zero()
            for j, wj in enumerate(weights):
                if wj == F2_ZERO:
                    continue
                if short and j >= cfs_len(self.slot_vars, self.slot_deg) - short:
                    continue   # not free randomness any more
                add_f2(re, im, base + 2 * j, base + 2 * j + 1, wj)
            return [re, im]

        # gamma = c * g.total()
        self.seam_obs += cfs_obs(
            [f2_mul(cc, x) for x in cfs_sum_weights(self.slot_vars, self.slot_deg)])
        if not c.get("include_rounds", True):
            return
        # the m masked rounds.  The DATA part of every round message is
        # identically zero on the honest (aliased) manifold: the two tables are
        # the same function of the same variables and the seam polynomial is
        # v0*(v1-v2).  Cases where the plane is NOT aliased set include_rounds
        # False, because then the data part is quadratic and outside this model.
        prev = []
        for r in range(self.m_vars):
            for x in range(self.slot_deg + 1):
                self.seam_obs += cfs_obs(
                    [f2_mul(cc, y) for y in cfs_round_weights(
                        r, prev, self.slot_vars, self.slot_deg, x)])
            prev.append(sm["rho"][r])
        # the extension round:
        #   s_k(x) = (1-x) eqfin [ (1-x)(fin_L - fin_R) + x (ext_L - ext_R) ]
        #            + c g_k(x),        fin_L == fin_R identically under aliasing
        for x in range(self.slot_deg + 1):
            re, im = self.zero(), self.zero()
            xv = (x % P, 0)
            coef = f2_mul(f2_mul(f2_sub(F2_ONE, xv), xv), sm["eqfin"])
            for k, sgn in ((0, coef), (1, f2_mul(coef, MINUS1))):
                pr = sm["pairs"][k]
                for t in range(N):
                    add_fp(re, im, self.msgcoord(k, pr[0], t),
                           f2_mul(sgn, sm["eq_cols"][t]))
                    add_fp(re, im, self.msgcoord(k, pr[1], t),
                           f2_mul(f2_mul(sgn, U), sm["eq_cols"][t]))
            for j, wj in enumerate(
                    [f2_mul(cc, y) for y in cfs_round_weights(
                        self.m_vars, sm["rho"], self.slot_vars, self.slot_deg, x)]):
                if wj == F2_ZERO:
                    continue
                if short and j >= cfs_len(self.slot_vars, self.slot_deg) - short:
                    continue
                add_f2(re, im, base + 2 * j, base + 2 * j + 1, wj)
            self.seam_obs += [re, im]
        # mask_eval = g(rho ++ [e])
        self.seam_obs += cfs_obs(
            cfs_eval_weights(list(sm["rho"]) + [sm["e"]], self.slot_deg))

    # ------------------------------------------------------- the ranks
    def _disclosed(self, obs, dcols):
        keep = [x for x in range(self.co.n) if x not in dcols]
        full = rank(obs, self.co.n)
        ronly = rank([[r[x] for x in keep] for r in obs], len(keep))
        return full - ronly

    def joint(self):
        return self._disclosed(self.obs, self.data_coords)

    def part(self, k):
        """Side k's own PCS channel alone, about side k's own data."""
        dcols = set()
        for r in range(self.nd):
            dcols.update(range(self.row_msg[k][r], self.row_msg[k][r] + N))
        return self._disclosed(self.side_obs[k], dcols)

    def about_plane(self):
        """The joint view's disclosure about the SHARED plane only."""
        return self._disclosed(self.obs, self.plane_coords)


def run(name, cfg, prediction):
    m = Model(cfg).build()
    m.observe()
    j = m.joint()
    pl, pr = m.part(0), m.part(1)
    out = {
        "case": name,
        "prediction": prediction,
        "joint_disclosed_Fp": j,
        "about_shared_plane_only": m.about_plane(),
        "part_L_alone": pl,
        "part_R_alone": pr,
        "sum_of_parts": pl + pr,
        "coords": m.co.n,
        "observations": len(m.obs),
    }
    if prediction == 0:
        out["as_predicted"] = j == 0
    elif prediction == "> 0":
        out["as_predicted"] = j > 0
    else:
        out["as_predicted"] = None
    return out


CASES = [
    ("0_honest_aliased_seam", dict(seed=11), 0),
    ("1_not_aliased_no_seam",
     dict(seed=12, aliased=False, n_seams=0, include_seam_argument=False), 0),
    ("2_batched_three_blocks", dict(seed=13, blocks=3), 0),
    ("3a_shared_terminal_mask_ALIASED",
     dict(seed=14, shared_terminal_mask=True), "?"),
    ("3b_shared_terminal_mask_NOT_aliased",
     dict(seed=15, shared_terminal_mask=True, aliased=False,
          include_rounds=False), "?"),
    ("4_seam_pair_shared_with_ordinary_claim",
     dict(seed=16, share_pair_with_ordinary=True), "> 0"),
    ("5_zero_mask_challenge_c", dict(seed=17, zero_c=True), "?"),
    ("6_zero_extension_challenge_e", dict(seed=18, zero_e=True), "> 0"),
    ("8_two_masking_commitments", dict(seed=20, n_slots_m2=2), 0),
    ("9_one_side_opened_twice", dict(seed=21, opened_twice=True), "> 0"),
    ("10_qpad_equals_distinct_columns", dict(seed=22, q_pad=3, n_cols=3), 0),
    ("11_two_seams_same_terminal_point",
     dict(seed=23, n_seams=2, same_terminal_point=True), 0),
    ("12_two_seams_independent_points", dict(seed=24, n_seams=2), 0),
    ("13_qpad_one_fewer_than_columns", dict(seed=25, q_pad=2, n_cols=3), "> 0"),
    ("14_seam_slot_too_short", dict(seed=26, short_slot=3), "?"),
    ("15_counterparty_seam_claim_has_NO_reserved_pair",
     dict(seed=27, no_pair_on_side=0), "> 0"),
    ("16_two_seams_share_one_pair_on_each_side",
     dict(seed=28, n_seams=2, two_seams_share_pair=True), "> 0"),
]


def main():
    out = []
    for name, cfg, pred in CASES:
        r = run(name, cfg, pred)
        out.append(r)
        print(json.dumps(r), flush=True)
    with open("seam_smallmodel_out.json", "w") as f:
        json.dump(out, f, indent=1)


if __name__ == "__main__":
    main()
