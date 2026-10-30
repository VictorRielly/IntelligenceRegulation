#!/usr/bin/env python3
"""S4 design check: exact linear-view rank model of the split-width openings.

Independent of Sol's code. Models the native hiding-PCS view of ONE commitment
(zkp-core pcs.rs: claims grouped by column key, one revealed row combination
per group, one proximity combination; argument.rs build_claim: data part
cd * plane~(point), reserved pair cm * (R_re + u R_im)(tail)).

The revealed view is W . M with M base-field. Writing each revealed Fp2 row
vector as its two base-field rows (Re, Im), the data disclosed by the linear
view is   rank(W) - rank(W restricted to the uniformly random non-data rows).
(0 = the view is uniform and independent of the data.)

This is the per-commitment linear-view lemma only. It is not the CFS / joint
view / NL-1 analysis, and not a privacy acceptance.
Field: Goldilocks p = 2^64 - 2^32 + 1, Fp2 = Fp[u]/(u^2 - 7) (native field.rs).
Public deterministic seed; no production randomness.
"""
import json
import random
import sys

P = (1 << 64) - (1 << 32) + 1
NR = 7
rng = random.Random(20261029)


def f2(a, b=0):
    return (a % P, b % P)


def add(x, y):
    return ((x[0] + y[0]) % P, (x[1] + y[1]) % P)


def sub(x, y):
    return ((x[0] - y[0]) % P, (x[1] - y[1]) % P)


def mul(x, y):
    return ((x[0] * y[0] + NR * x[1] * y[1]) % P, (x[0] * y[1] + x[1] * y[0]) % P)


ONE, ZERO, U = (1, 0), (0, 0), (0, 1)


def rnd():
    while True:
        x = (rng.randrange(P), rng.randrange(P))
        if x not in (ZERO, ONE):
            return x


def vec(n):
    return [rnd() for _ in range(n)]


def eq_table(point):
    """eq(point, x) for x in {0,1}^n, MSB-first (as zkp-core eq_table_msb)."""
    t = [ONE]
    for r in point:
        nt = []
        for v in t:
            nt.append(mul(v, sub(ONE, r)))
            nt.append(mul(v, r))
        t = nt
    return t


def rank_mod_p(rows):
    m = [r[:] for r in rows if any(r)]
    rank, col = 0, 0
    ncols = len(m[0]) if m else 0
    while rank < len(m) and col < ncols:
        piv = next((i for i in range(rank, len(m)) if m[i][col] % P), None)
        if piv is None:
            col += 1
            continue
        m[rank], m[piv] = m[piv], m[rank]
        inv = pow(m[rank][col], P - 2, P)
        m[rank] = [(v * inv) % P for v in m[rank]]
        for i in range(len(m)):
            if i != rank and m[i][col]:
                fct = m[i][col]
                m[i] = [(a - fct * b) % P for a, b in zip(m[i], m[rank])]
        rank += 1
        col += 1
    return rank


class Commitment:
    def __init__(self, name, log_cols):
        self.name, self.log_cols = name, log_cols
        self.planes = {}
        self.data_rows = 0
        self.nondata = []  # list of row indices (uniform masks)
        self.rows = 0
        self.claims = []
        self.openings = 1

    def plane(self, name, log_size):
        assert log_size >= self.log_cols
        self.planes[name] = (self.rows, log_size)
        self.rows += 1 << (log_size - self.log_cols)
        self.data_rows = self.rows

    def mask_rows(self, k):
        r = list(range(self.rows, self.rows + k))
        self.rows += k
        self.nondata += r
        return r

    def claim(self, plane, point, cd, cm, pair):
        self.claims.append((plane, point, cd, cm, pair))

    def view(self, removed=()):
        groups = {}
        for i, (plane, point, cd, cm, pair) in enumerate(self.claims):
            if i in removed:
                continue
            r0, ls = self.planes[plane]
            lr = ls - self.log_cols
            w = [ZERO] * self.rows
            for k, e in enumerate(eq_table(point[:lr])):
                w[r0 + k] = add(w[r0 + k], mul(cd, e))
            if pair is not None:
                w[pair[0]] = add(w[pair[0]], cm)
                w[pair[1]] = add(w[pair[1]], mul(cm, U))
            if all(x == ZERO for x in w):
                raise ValueError("zero functional reached the opening (native open_zk would refuse)")
            key = tuple(point[lr:])
            groups.setdefault(key, []).append(w)
        revealed = []
        for _ in range(self.openings):
            for key, members in groups.items():
                v = [ZERO] * self.rows
                for w in members:
                    lam = rnd()
                    v = [add(a, mul(lam, b)) for a, b in zip(v, w)]
                revealed.append(v)
            revealed.append(vec(self.rows))  # proximity combination over every row
        base = []
        for v in revealed:
            base.append([x[0] for x in v])
            base.append([x[1] for x in v])
        full = rank_mod_p(base)
        masked = rank_mod_p([[r[i] for i in self.nondata] for r in base])
        return dict(groups=len(groups), openings=self.openings, view_dims=len(base),
                    nondata_rows=len(self.nondata), rank_full=full, rank_masks=masked,
                    disclosed=full - masked)


def a_commitment(style, zero_slot=None, T_bits=7, log_cols=14):
    """One A-like commitment at Shieldstral T128 row geometry (N = 2^14).

    Planes: X (norm input, moving token) and Y (norm output, matmul input),
    each as D0 (T x 2048) and D1 (T x 1024) pieces. Claims: one batched norm
    sum (moving token), Q/K/V batched matmuls (fixed token r_q shared, as in
    argument.rs), per-piece zero checks and IO slots (no lift).
    style: native (padded R13 reference), whole, indep, gate, maskonly_bug.
    zero_slot: 'ssm' or 'q' forces rho_b = 1 in that slot (sigma = 0).
    """
    c = Commitment("A", log_cols)
    if style == "native":
        for p in ("X", "Y"):
            c.plane(p, T_bits + 12)
    else:
        for p in ("X", "Y"):
            c.plane(p + "0", T_bits + 11)
            c.plane(p + "1", T_bits + 10)
    removed = []
    r_q = vec(T_bits)

    def slot(name, plane, token, lifted):
        e = rnd()
        rho_b = ONE if zero_slot == name else rnd()
        rho_j = vec(10)
        sigma = sub(ONE, rho_b)
        if style == "native":
            pt = token + vec(12)  # R13: one padded 4096-wide plane, 12 feature bits
            c.claim(plane, pt, sub(ONE, e), e, c.mask_rows(2))
            return
        # D0 piece: full point, never lifted
        c.claim(plane + "0", token + [rho_b] + rho_j, sub(ONE, e), e, c.mask_rows(2))
        if not lifted:
            return
        pt = token + rho_j  # projected: the leading feature bit removed after the token bits
        one_m_e = sub(ONE, e)
        if style == "whole":
            cd, cm = mul(one_m_e, sigma), mul(e, sigma)
        elif style == "indep":
            cd, cm = mul(one_m_e, sigma), e
        elif style == "gate":
            cd, cm = one_m_e, e
        elif style == "maskonly_bug":
            cd, cm = one_m_e, mul(e, sigma)
        else:
            raise ValueError(style)
        pair = c.mask_rows(2)
        if style == "whole" and sigma == ZERO:
            removed.append(len(c.claims))  # checked-zero normalization: claim omitted
        c.claim(plane + "1", pt, cd, cm, pair)

    slot("ssm", "X", vec(T_bits), True)
    for s in ("q", "k", "v"):
        slot(s, "Y", r_q, True)
    if style != "native":
        for piece, nbits in (("0", 11), ("1", 10)):
            for p in ("X", "Y"):  # per-piece zero checks and the IO slot: plain claims
                e = rnd()
                c.claim(p + piece, vec(T_bits + nbits), sub(ONE, e), e, c.mask_rows(2))
            e = rnd()
            c.claim("X" + piece, vec(T_bits + nbits), sub(ONE, e), e, c.mask_rows(2))
    else:
        for p in ("X", "Y"):
            e = rnd()
            c.claim(p, vec(T_bits + 12), sub(ONE, e), e, c.mask_rows(2))
        e = rnd()
        c.claim("X", vec(T_bits + 12), sub(ONE, e), e, c.mask_rows(2))
    c.mask_rows(2)  # A's proximity pair (A rows = data + 2 * sites + 2)
    return c, removed


def endpoint_piece(data_log, sites, geometry, log_cols=14, openings=1):
    c = Commitment("E", log_cols)
    c.plane("P", data_log)
    if geometry == "external":  # endpoint_g: pair, proximity row, two further random rows
        pairs = [c.mask_rows(2)]
        c.mask_rows(3)
        if sites == 2:  # a second site would have to take the two further rows
            pairs.append([pairs[0][1] + 2, pairs[0][1] + 3])
    elif geometry == "internal":  # boundary.rs: data + 2*sites + 2
        pairs = [c.mask_rows(2) for _ in range(sites)]
        c.mask_rows(2)
    elif geometry == "internal_single_prox":  # the M-1 / U-1 negative control
        pairs = [c.mask_rows(2) for _ in range(sites)]
        c.mask_rows(1)
    for s in range(sites):
        e = rnd()
        c.claim("P", vec(data_log), sub(ONE, e), e, pairs[s])
    c.openings = openings
    return c


def main():
    out = {"scope": "S4 design check rank model: per-commitment linear view only; not CFS/joint view; not a privacy acceptance",
           "field": "Goldilocks Fp2 (u^2 = 7)", "geometry": "Shieldstral T128 rows, N = 2^14 (D0 = 16 rows, D1 = 8 rows per plane)"}
    a = {}
    for style in ("native", "whole", "indep", "gate"):
        c, removed = a_commitment(style)
        a[style] = c.view(removed)
    for style in ("whole", "indep", "gate", "maskonly_bug"):
        for z in ("ssm", "q"):
            c, removed = a_commitment(style, zero_slot=z)
            try:
                a[f"{style}_sigma0_{z}"] = c.view(removed)
            except ValueError as err:
                a[f"{style}_sigma0_{z}"] = {"refused": str(err)}
    out["A_commitment"] = a
    e = {}
    for name, (dl, sites, geo, op) in {
        "external_D0_piece": (18, 1, "external", 1),
        "external_D1_piece": (17, 1, "external", 1),
        "external_R13_unsplit": (19, 1, "external", 1),
        "internal_D0_piece_2sites": (18, 2, "internal", 1),
        "internal_D1_piece_2sites": (17, 2, "internal", 1),
        "NEG_internal_single_prox_row": (17, 2, "internal_single_prox", 1),
        "NEG_external_two_sites_one_commitment": (17, 2, "external", 1),
        "NEG_external_piece_opened_twice": (17, 1, "external", 2),
    }.items():
        e[name] = endpoint_piece(dl, sites, geo, openings=op).view()
    # Option: ONE commitment per logical boundary holding both pieces as row
    # blocks (D12a's literal "one boundary commitment"), geometry by the
    # boundary rule data + 2*sites + 2 (sites = claims across both pieces).
    for name, sites_per_piece in (("joint_external_2sites", 1), ("joint_internal_4sites", 2)):
        c = Commitment("J", 14)
        c.plane("P0", 18)
        c.plane("P1", 17)
        pairs = [c.mask_rows(2) for _ in range(2 * sites_per_piece)]
        c.mask_rows(2)
        k = 0
        for piece, dl in (("P0", 18), ("P1", 17)):
            for _ in range(sites_per_piece):
                ee = rnd()
                c.claim(piece, vec(dl), sub(ONE, ee), ee, pairs[k])
                k += 1
        e[name] = dict(c.view(), rows=c.rows, data_rows=c.data_rows)
    out["endpoint_pieces"] = e
    # sigma = 0 probability: one event per lifted slot per omitted coordinate.
    k_per_block = {"QKV (k=1 each)": 3, "gate,up out-pieces x D1 input (k=1)": 4,
                   "down out-pieces x F1 input (k=3)": 6, "two norm sums (k=1)": 2}
    events = sum(k_per_block.values())
    import math
    out["sigma_zero"] = {"coordinate_events_per_block": k_per_block, "events_per_block": events,
                         "blocks": 26, "union_bound": f"{26 * events}/p^2",
                         "log2_union_bound": math.log2(26 * events) - 2 * math.log2(P)}
    ok = (all(v.get("disclosed") == 0 for k, v in a.items() if not k.startswith("maskonly"))
          and all(a[k].get("disclosed", 0) > 0 for k in a if k.startswith("maskonly"))
          and all(v["disclosed"] == 0 for k, v in e.items() if not k.startswith("NEG"))
          and all(v["disclosed"] > 0 for k, v in e.items() if k.startswith("NEG")))
    out["expectations_hold"] = ok
    print(json.dumps(out, indent=1))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
