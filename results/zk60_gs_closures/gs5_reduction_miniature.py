"""GS-5: the reduction `disclosed = n*k0 + u_dim` at n != Q, by brute force.

Exact arithmetic over Goldilocks p = 2^64 - 2^32 + 1, Fp2 = Fp[U]/(U^2 - 7).
Nothing is built and no capture is read: this is a MODEL of one hiding
commitment of `zkp-core/src/pcs.rs` (lane `2ea7221`), faithful in the points
the derivation of ZK60_GS4_GS5_GS11_GS12_CLOSURES.md §2 uses:

  * row i = (msg_i in Fp^n, pad_i in Fp^Q); the encoded row is
    f_msg(x) + Z_n(x) * sum_{k<Q} pad_k x^k on the coset 7*<w_nn>
    (`encode_row_zk`, pcs.rs:655-674), so the column functional is
    E_j[msg s] = Z_n(x_j) / (n (x_j w_n^-s - 1)),  E_j[pad k] = Z_n(x_j) x_j^k;
  * pads uniform on EVERY row (pcs.rs:724/777 `rng.fp_vec(rows * q)`);
  * non-data message rows uniform, except the two zero-sum rows `u`, which are
    uniform on {sum_t m[t] = 0} (protocol.rs:1115-1126);
  * claims built as `build_claim` builds them: a data part with coefficient
    cd whose row weights are an eq tensor over its own slice, and a reserved
    pair (cm, cm*U) at the point tail (argument.rs:264-278, pcs.rs:860-900);
    one claim evaluates the u plane with a point-independent weight (SC_ZS);
    the pairless LogUp sum claim has an empty point, weights +-1 / +-U on
    every row of every plane and on the u pair (1, U), value 0 (protocol.rs:
    167-178), and is NOT a published terminal;
  * first-occurrence grouping by column key, one lambda per member, a fresh
    proximity rho on every row (`zk_rhos`).

The whole view -- every published claim value, every group vector's message
AND pad half, the proximity vector, every opened column's value on every row
-- is built as an Fp matrix over (hidden data | randomness), and

    disclosed_brute = rank(view) - rank(view restricted to the randomness)

(= dim_Fp(F intersect T), the check's §1.2 of ZK60_GENERIC_RANK_LEMMA_CHECK.md).
It is compared with the tool's formula `n*k0 + u_dim`
(zk60_native_rg_pcs.py:381-431), computed from the generators alone.

Cases (each at several (n, Q), including n > Q, n = Q and n < Q):
  honest-H     H-like commitment: expect brute = formula = 2 (= u_dim)
  honest-A     A-like (no u rows, no sum claim): expect 0
  u-free       the same H-like commitment with the u rows fully uniform: expect 0
  msg-only-k0  the MESSAGE-HALF system alone with a generator set built to
               have k0 = 1, 2, 3 and the u rows present: expect n*k0 + u_dim
               exactly (the Kronecker step of the derivation, no hypothesis)
  cm0-single   a singleton claim's cm = 0 (H-pair broken): report both
  shared-pair  two claims of different groups on one reserved pair
               (exclusivity broken): the formula must UNDER-count, because
               the individual claim values are no longer absorbed (step 2)
  shared-pair-same-group  two claims of ONE group on one pair: the same
  prox-dep     an Fp-dependent proximity pair (H-prox broken): report
  over-budget  d = Q + 1 distinct opened columns (H-pad broken): brute > formula
"""

from __future__ import annotations

import json
import random
import sys

P = 2**64 - 2**32 + 1
NR = 7  # U^2 = 7


# ------------------------------------------------------------------ fields
def f2(a, b=0):
    return (a % P, b % P)


def f2_add(x, y):
    return ((x[0] + y[0]) % P, (x[1] + y[1]) % P)


def f2_mul(x, y):
    return ((x[0] * y[0] + NR * x[1] * y[1]) % P, (x[0] * y[1] + x[1] * y[0]) % P)


def f2_neg(x):
    return ((-x[0]) % P, (-x[1]) % P)


U = (0, 1)
ONE = (1, 0)
ZERO = (0, 0)


def rnd_f2(rng):
    return (rng.randrange(1, P), rng.randrange(1, P))


def eq_table(point):
    """eq tensor, first coordinate most significant."""
    out = [ONE]
    for r in point:
        one_minus = f2_add(ONE, f2_neg(r))
        nxt = []
        for e in out:
            nxt.append(f2_mul(e, one_minus))
            nxt.append(f2_mul(e, r))
        out = nxt
    return out


def rank_split(rows, ncols, first):
    """Row-reduce with the columns [0, first) eliminated first.

    Returns (rank of the whole matrix, rank restricted to columns [0, first)).
    Exact, mod P.  Rows are dicts {col: value} (sparse).
    """
    pivots = {}  # col -> reduced row
    r_first = 0
    r_all = 0
    order = list(range(ncols))
    for row in rows:
        v = {c: x % P for c, x in row.items() if x % P}
        # reduce against existing pivots, in column order
        while v:
            c = min(v, key=lambda k: k)
            if c in pivots:
                pr = pivots[c]
                f = v[c]
                for cc, xx in pr.items():
                    nv = (v.get(cc, 0) - f * xx) % P
                    if nv:
                        v[cc] = nv
                    else:
                        v.pop(cc, None)
            else:
                inv = pow(v[c], P - 2, P)
                v = {cc: xx * inv % P for cc, xx in v.items()}
                pivots[c] = v
                r_all += 1
                if c < first:
                    r_first += 1
                break
    # the rank restricted to columns [0, first): pivots with c < first form an
    # echelon basis of the projection only if we eliminated those columns
    # first, which the column order guarantees (pivot = smallest column)
    return r_all, r_first


def rank_dense(mat, ncols):
    rows = [{c: x for c, x in enumerate(r) if x % P} for r in mat]
    return rank_split(rows, ncols, ncols)[0]


# --------------------------------------------------- the commitment model
def build_model(rng, ln, q, *, nd=4, kind="H", u_constrained=True, n_eval=3,
                shared_key=True, cm_zero_singleton=False, shared_pair=False,
                prox_dependent=False, d_extra=0, inv_rate=4):
    n = 1 << ln
    nn = n * inv_rate
    # --- rows: data | u pair (H only) | reserved pairs | proximity pair
    has_u = kind == "H"
    n_pairs = n_eval + (1 if has_u else 0)  # + SC_ZS's own pair
    data_rows = list(range(nd))
    u_rows = [nd, nd + 1] if has_u else []
    base = nd + len(u_rows)
    pair_rows = [(base + 2 * k, base + 2 * k + 1) for k in range(n_pairs)]
    prox = base + 2 * n_pairs
    R = prox + 2
    nondata = [r for r in range(R) if r not in data_rows]

    # --- claims: (row weights over Fp2 of length R, column key, published?)
    claims = []
    # evaluation claims on data planes of 2 rows each (ls = ln + 1)
    tails = []
    for k in range(n_eval):
        ls = ln + 1
        point = [rnd_f2(rng) for _ in range(ls)]
        if shared_key and k == 1:
            point[1:] = tails[0]  # claim 1 shares claim 0's column key
        tails.append(point[1:])
        r0 = (2 * k) % nd
        cd = rnd_f2(rng)
        cm = rnd_f2(rng)
        if cm_zero_singleton and k == n_eval - 1:
            cm = ZERO
        rw = [ZERO] * R
        for i, e in enumerate(eq_table(point[:1])):
            rw[r0 + i] = f2_add(rw[r0 + i], f2_mul(cd, e))
        pr = pair_rows[k]
        if shared_pair == "other-group" and k == n_eval - 1:
            pr = pair_rows[0]  # onto claim 0's pair (claim 0 is in another group)
        if shared_pair == "same-group" and k == 1:
            pr = pair_rows[0]  # claim 1 shares claim 0's key AND now its pair
        rw[pr[0]] = f2_add(rw[pr[0]], cm)
        rw[pr[1]] = f2_add(rw[pr[1]], f2_mul(cm, U))
        claims.append({"rw": rw, "key": ("eval", tuple(point[1:])), "published": True})
    if has_u:
        # SC_ZS: evaluates the u plane (re row u0, im row u1), point-independent
        # weights (cd, cd*U) because log(Dom::Tab) == log_cols; own pair
        point = [rnd_f2(rng) for _ in range(ln)]
        cd = rnd_f2(rng)
        cm = rnd_f2(rng)
        rw = [ZERO] * R
        rw[u_rows[0]] = cd
        rw[u_rows[1]] = f2_mul(cd, U)
        pr = pair_rows[n_eval]
        rw[pr[0]] = cm
        rw[pr[1]] = f2_mul(cm, U)
        claims.append({"rw": rw, "key": ("eval", tuple(point)), "published": True})
        # the LogUp sum claim: empty point, all-ones columns, +-1/+-U per row
        # every H plane has a re row (sign) and an im row (sign * U), as
        # logup_sum_claim writes them (protocol.rs:170-176); data rows come
        # in (re, im) pairs here
        rw = [ZERO] * R
        for k in range(0, nd, 2):
            sign = rng.choice([ONE, f2_neg(ONE)])
            rw[data_rows[k]] = sign
            rw[data_rows[k + 1]] = f2_mul(sign, U)
        rw[u_rows[0]] = ONE
        rw[u_rows[1]] = U
        claims.append({"rw": rw, "key": ("sum",), "published": False})

    # --- groups: first occurrence by key; lambdas; rho_g
    keys, groups = [], []
    for ci, c in enumerate(claims):
        if c["key"] in keys:
            groups[keys.index(c["key"])].append(ci)
        else:
            keys.append(c["key"])
            groups.append([ci])
    lam = {ci: rnd_f2(rng) for ci in range(len(claims))}
    rhos = []
    for g in groups:
        rho = [ZERO] * R
        for ci in g:
            for i in range(R):
                rho[i] = f2_add(rho[i], f2_mul(lam[ci], claims[ci]["rw"][i]))
        rhos.append(rho)
    prox_rho = [rnd_f2(rng) for _ in range(R)]
    if prox_dependent:
        a = rnd_f2(rng)
        s = rng.randrange(1, P)
        prox_rho[prox] = a
        prox_rho[prox + 1] = (a[0] * s % P, a[1] * s % P)  # Fp-multiple: wedge = 0

    # --- column weights per group key
    def cw_of(key):
        if key[0] == "sum":
            return [ONE] * n
        return eq_table(list(key[1]))

    cws = [cw_of(k) for k in keys]

    # --- opened columns: d distinct positions of the coset
    d = min(q, nn) + d_extra if d_extra else q
    cols = rng.sample(range(nn), d)
    w_nn = pow(7, (P - 1) // nn, P)
    w_n = pow(7, (P - 1) // n, P)
    w_n_inv = pow(w_n, P - 2, P)
    n_inv = pow(n, P - 2, P)
    E = []
    for j in cols:
        xj = 7 * pow(w_nn, j, P) % P
        zn = (pow(xj, n, P) - 1) % P
        msg = []
        ws = 1
        for _ in range(n):
            msg.append(zn * n_inv % P * pow((xj * ws - 1) % P, P - 2, P) % P)
            ws = ws * w_n_inv % P
        pad = []
        xp = 1
        for _ in range(q):
            pad.append(zn * xp % P)
            xp = xp * xj % P
        E.append((msg, pad))

    return {
        "n": n, "q": q, "R": R, "data_rows": data_rows, "u_rows": u_rows,
        "u_constrained": u_constrained and has_u, "nondata": nondata, "prox": prox,
        "claims": claims, "groups": groups, "keys": keys, "cws": cws,
        "rhos": rhos, "prox_rho": prox_rho, "E": E, "d": d,
    }


def unknown_index(m):
    """Column layout: randomness first, then the hidden data.

    randomness: msg of non-data non-u rows (n each); u rows (n-1 free each if
    constrained, else n); pads of every row (q each).  data: msg of data rows.
    Returns (ncols, first, msg_col(i, t) -> {col: coef}, pad_col(i, k) -> col).
    """
    n, q, R = m["n"], m["q"], m["R"]
    col = 0
    msg_map = {}
    for i in range(R):
        if i in m["data_rows"]:
            continue
        if i in m["u_rows"] and m["u_constrained"]:
            free = list(range(col, col + n - 1))
            col += n - 1
            for t in range(n - 1):
                msg_map[(i, t)] = {free[t]: 1}
            msg_map[(i, n - 1)] = {c: P - 1 for c in free}  # m[n-1] = -sum
        else:
            for t in range(n):
                msg_map[(i, t)] = {col: 1}
                col += 1
    pad_map = {}
    for i in range(R):
        for k in range(q):
            pad_map[(i, k)] = col
            col += 1
    first = col
    for i in m["data_rows"]:
        for t in range(n):
            msg_map[(i, t)] = {col: 1}
            col += 1
    return col, first, msg_map, pad_map


def view_rows(m, *, msg_only=False, gens=None):
    """The realified view as sparse Fp rows over the unknowns."""
    n, q, R = m["n"], m["q"], m["R"]
    ncols, first, msg_map, pad_map = unknown_index(m)
    rows = []

    def add_fp2_row(coefs_msg, coefs_pad):
        # coefs_msg: {(i, t): Fp2}, coefs_pad: {(i, k): Fp2}; emit Re and Im rows
        for part in (0, 1):
            row = {}
            for (i, t), c in coefs_msg.items():
                if c[part]:
                    for col, s in msg_map[(i, t)].items():
                        row[col] = (row.get(col, 0) + c[part] * s) % P
            for (i, k), c in coefs_pad.items():
                if c[part]:
                    col = pad_map[(i, k)]
                    row[col] = (row.get(col, 0) + c[part]) % P
            rows.append(row)

    vectors = gens if gens is not None else (m["rhos"] + [m["prox_rho"]])
    # group vectors and the proximity vector: message half, pad half
    for rho in vectors:
        for t in range(n):
            add_fp2_row({(i, t): rho[i] for i in range(R) if rho[i] != ZERO}, {})
        if not msg_only:
            for k in range(q):
                add_fp2_row({}, {(i, k): rho[i] for i in range(R) if rho[i] != ZERO})
    if msg_only:
        return rows, ncols, first
    # published claim values
    for gi, g in enumerate(m["groups"]):
        cw = m["cws"][gi]
        for ci in g:
            c = m["claims"][ci]
            if not c["published"]:
                continue
            coefs = {}
            for i in range(R):
                if c["rw"][i] == ZERO:
                    continue
                for t in range(n):
                    coefs[(i, t)] = f2_mul(c["rw"][i], cw[t])
            add_fp2_row(coefs, {})
    # opened columns: one Fp value per (column, row)
    for msg, pad in m["E"]:
        for i in range(R):
            row = {}
            for t in range(n):
                for col, s in msg_map[(i, t)].items():
                    row[col] = (row.get(col, 0) + msg[t] * s) % P
            for k in range(q):
                col = pad_map[(i, k)]
                row[col] = (row.get(col, 0) + pad[k]) % P
            rows.append(row)
    return rows, ncols, first


def brute(m, **kw):
    rows, ncols, first = view_rows(m, **kw)
    r_all, r_rand = rank_split(rows, ncols, first)
    return r_all - r_rand


# ------------------------------------------------ the tool's formula
def realified(vectors):
    out = []
    for rho in vectors:
        out.append([v[0] for v in rho])
        out.append([v[1] for v in rho])
    return out


def solve_left(gN, target):
    """c with c . gN == target (gN: list of rows), or None."""
    k = len(gN)
    m = len(target)
    # columns of the augmented system: unknown c (k), equations over m coords
    aug = [[gN[r][j] for r in range(k)] + [target[j] % P] for j in range(m)]
    piv_cols = []
    r = 0
    for c in range(k):
        p = next((i for i in range(r, m) if aug[i][c] % P), None)
        if p is None:
            continue
        aug[r], aug[p] = aug[p], aug[r]
        inv = pow(aug[r][c], P - 2, P)
        aug[r] = [x * inv % P for x in aug[r]]
        for i in range(m):
            if i != r and aug[i][c]:
                f = aug[i][c]
                aug[i] = [(a - f * b) % P for a, b in zip(aug[i], aug[r])]
        piv_cols.append(c)
        r += 1
    for i in range(r, m):
        if aug[i][k] % P:
            return None
    sol = [0] * k
    for i, c in enumerate(piv_cols):
        sol[c] = aug[i][k]
    return sol


def left_kernel(gN):
    k = len(gN)
    m = len(gN[0]) if gN else 0
    mat = [[gN[r][j] for r in range(k)] for j in range(m)]
    piv, r = [], 0
    for c in range(k):
        p = next((i for i in range(r, m) if mat[i][c] % P), None)
        if p is None:
            continue
        mat[r], mat[p] = mat[p], mat[r]
        inv = pow(mat[r][c], P - 2, P)
        mat[r] = [x * inv % P for x in mat[r]]
        for i in range(m):
            if i != r and mat[i][c]:
                f = mat[i][c]
                mat[i] = [(a - f * b) % P for a, b in zip(mat[i], mat[r])]
        piv.append(c)
        r += 1
    out = []
    for fc in [c for c in range(k) if c not in piv]:
        v = [0] * k
        v[fc] = 1
        for i, pc in enumerate(piv):
            v[pc] = (-mat[i][fc]) % P
        out.append(v)
    return out


def formula(m, gens_fp2=None, u_declared=None):
    """The tool's n*k0 + u_dim, from the generators alone."""
    vectors = gens_fp2 if gens_fp2 is not None else (m["rhos"] + [m["prox_rho"]])
    G = realified(vectors)
    R = m["R"]
    N = m["nondata"]
    D = m["data_rows"]
    U_ = m["u_rows"] if u_declared is None else u_declared
    r1 = rank_dense(G, R)
    GN = [[g[i] for i in N] for g in G]
    rN = rank_dense(GN, len(N))
    k0 = r1 - rN
    u_dim = 0
    admissible = 0
    if U_:
        xis = []
        for u in U_:
            t = [1 if i == u else 0 for i in N]
            c = solve_left(GN, t)
            if c is None:
                continue
            admissible += 1
            xis.append([sum(c[k] * G[k][i] for k in range(len(G))) % P for i in D])
        kb = [[sum(c[k] * G[k][i] for k in range(len(G))) % P for i in D] for c in left_kernel(GN)]
        u_dim = rank_dense(xis + kb, len(D)) - rank_dense(kb, len(D))
    return {"k0": k0, "u_dim": u_dim, "u_admissible": admissible, "formula": m["n"] * k0 + u_dim}


def msg_only_generators(rng, m, k0_target):
    """A generator set (Fp2 vectors over rows) with a chosen k0 on the model's
    geometry: the honest rhos plus `k0_target` Fp2 generators... realified, so
    each added Fp2 generator supported on DATA rows only adds up to 2 to k0.
    We add Fp-real generators instead (imaginary part zero) to hit odd k0."""
    gens = [list(r) for r in m["rhos"]] + [list(m["prox_rho"])]
    for _ in range(k0_target):
        v = [ZERO] * m["R"]
        for i in m["data_rows"]:
            v[i] = (rng.randrange(1, P), 0)
        gens.append(v)
    return gens


def run_case(rng, ln, q, case):
    kw = {}
    if case == "honest-A":
        kw = {"kind": "A"}
    elif case == "u-free":
        kw = {"u_constrained": False}
    elif case == "cm0-single":
        kw = {"cm_zero_singleton": True}
    elif case == "shared-pair":
        kw = {"shared_pair": "other-group"}
    elif case == "shared-pair-same-group":
        kw = {"shared_pair": "same-group"}
    elif case == "prox-dep":
        kw = {"prox_dependent": True}
    elif case == "over-budget":
        kw = {"d_extra": 1}
    m = build_model(rng, ln, q, **kw)
    out = {"case": case, "n": m["n"], "Q": q, "rows": m["R"], "groups": len(m["groups"]),
           "distinct_columns": m["d"]}
    if case.startswith("msg-only-k0"):
        k0t = int(case.split("=")[1])
        gens = msg_only_generators(rng, m, k0t)
        b = brute_msg_only(m, gens)
        f = formula(m, gens_fp2=gens)
        out.update({"brute": b, **f, "agree": b == f["formula"]})
        return out
    b = brute(m)
    u_decl = m["u_rows"] if m["u_constrained"] else []
    f = formula(m, u_declared=u_decl)
    out.update({"brute": b, **f, "agree": b == f["formula"]})
    return out


def brute_msg_only(m, gens):
    rows, ncols, first = view_rows(m, msg_only=True, gens=gens)
    r_all, r_rand = rank_split(rows, ncols, first)
    return r_all - r_rand


def main():
    grid = [(3, 8), (3, 4), (3, 2), (4, 4), (4, 2), (5, 4), (2, 8)]  # (log n, Q): n=8/Q=8 is n = Q
    cases = ["honest-H", "honest-A", "u-free", "msg-only-k0=1", "msg-only-k0=2", "msg-only-k0=3",
             "cm0-single", "shared-pair", "shared-pair-same-group", "prox-dep", "over-budget"]
    seeds = [1, 2, 3, 4, 5]
    results = []
    for ln, q in grid:
        for case in cases:
            for s in seeds:
                rng = random.Random(1000 * ln + 10 * q + s + 7919 * cases.index(case))
                r = run_case(rng, ln, q, case)
                r["seed"] = s
                results.append(r)
                print(json.dumps(r), file=sys.stderr, flush=True)
    summary = {}
    for r in results:
        key = r["case"]
        s = summary.setdefault(key, {"instances": 0, "agree": 0, "brute_values": set(), "formula_values": set()})
        s["instances"] += 1
        s["agree"] += int(r["agree"])
        s["brute_values"].add((r["n"], r["Q"], r["brute"]))
        s["formula_values"].add((r["n"], r["Q"], r["formula"]))
    for s in summary.values():
        s["brute_values"] = sorted(s["brute_values"])
        s["formula_values"] = sorted(s["formula_values"])
    json.dump({"results": results, "summary": summary}, sys.stdout, indent=1)
    print()


if __name__ == "__main__":
    main()
