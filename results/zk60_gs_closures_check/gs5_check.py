"""GS-5 adversarial check: brute force of one hiding commitment's whole linear
view against `n*k0 + u` -- written from scratch (the drafter's
gs5_reduction_miniature.py is NOT imported or copied), exact Goldilocks.

What is modelled (zkp-core/src/pcs.rs at lane 2ea7221):
  * row i = (m_i in Fp^n, pi_i in Fp^Q); encoded row
    f_msg(x) + (x^n - 1) * sum_k pi_k x^k  (encode_row_zk, pcs.rs:655-674,
    re-derived here: out[i] -= pad[i]; out[n+i] = pad[i] gives exactly this
    polynomial for every Q <= nn - n, including Q > n), evaluated on the coset
    7 * <w_nn>: column j is  sum_s m[s] L_s(x_j) + sum_k pi[k] (x_j^n - 1) x_j^k;
  * pads uniform on EVERY row (pcs.rs:724 / :777); non-data message rows
    uniform; the two zero-sum rows uniform on {sum_t m[t] = 0}
    (protocol.rs:1118-1126);
  * claims: row weights = data part + optional u-row part + the reserved pair
    (cm, cm*U); groups by column key (pcs.rs:916-939), one lambda per member,
    rho_g = sum lambda_c rw_c; rho_prox fresh on every row (zk_rhos,
    pcs.rs:943-964);
  * the view: every published claim value, both halves of every group
    vector and of the proximity vector, every opened column on every row.

disclosed = rank(L) - rank(L restricted to the randomness columns).

Compared with
  k0      = rank G - rank G_N                        (G = realified rhos)
  u_exact = rank G_{D u N'} - rank G_{N'} - k0       (derived in the check)
  u_tool  = the gate's per-indicator u term (zk60_native_rg_pcs.py:394-431)
and with the values' own contribution  brute(with values) - brute(without).

Case families (see CASES at the bottom): the drafter's grid extended to
n = Q, n < Q (up to Q = 3n, the encoder's limit), odd n (3, 5, 15), d < Q;
the REAL group structures of A / H / endpoints / boundary at 125M and rung-G
(sizes read from the captures) at reduced data-row counts; the real endpoint
row geometry (37 rows at 125M, 9 at rung-G) at n/Q = 64 and 4; dependent
proximity pairs on all of them (step 2(c)); the counterexample family
(dependent proximity pair + a multi-member group whose column weights are
Fp-collinear); and the u-term admissibility family.
"""

from __future__ import annotations

import json
import random
import sys
import time

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from gf import (P, ONE, U, ZERO, eq_table, f2_add, f2_inv, f2_mul, f2_scale, f2_sub, f2_tr,  # noqa: E402
                inv, left_kernel, rank, rank_split, rnd_f2, rnd_fp, solve_left)


# ------------------------------------------------------------------ model
def column_weights(rng, kind, n):
    if kind == "eq":
        ln = n.bit_length() - 1
        assert 1 << ln == n
        return eq_table([rnd_f2(rng) for _ in range(ln)])
    if kind == "rand":
        return [rnd_f2(rng) for _ in range(n)]
    if kind == "fp":  # every entry in Fp: Fp-collinear
        return [(rnd_fp(rng), 0) for _ in range(n)]
    if kind == "fpscaled":  # an Fp2 scalar times an Fp vector: Fp-collinear, not in Fp
        z = rnd_f2(rng)
        return [f2_scale(z, rnd_fp(rng)) for _ in range(n)]
    if kind == "ones":  # the sum key (pcs.rs:902-914, empty tail)
        return [ONE] * n
    if kind == "range":  # empty tail on a sub-range [c0, c0+len): an indicator
        return [ONE if t < max(1, n // 2) else ZERO for t in range(n)]
    raise ValueError(kind)


def build(rng, spec):
    """spec -> a concrete commitment view model."""
    n, Q = spec["n"], spec["Q"]
    nd = spec["nd"]
    claims_spec = spec["claims"]
    groups_spec = spec["groups"]
    u_mode = spec.get("u")  # None | "constrained" | "free"
    rows = list(range(nd))
    D = list(range(nd))
    nxt = nd
    Urows = []
    if u_mode:
        Urows = [nxt, nxt + 1]
        nxt += 2
    pair_of = {}
    for ci, c in enumerate(claims_spec):
        if c.get("pair", True):
            if c.get("share_pair_with") is not None:
                pair_of[ci] = pair_of[c["share_pair_with"]]
            else:
                pair_of[ci] = (nxt, nxt + 1)
                nxt += 2
    spare = list(range(nxt, nxt + spec.get("spare", 0)))
    nxt += len(spare)
    prox = (nxt, nxt + 1)
    nxt += 2
    R = nxt
    Nprime = [i for i in range(R) if i not in D and i not in Urows]
    if u_mode == "free":
        Nprime = sorted(Nprime + Urows)

    # claims' row weights
    rws = []
    for ci, c in enumerate(claims_spec):
        rw = [ZERO] * R
        for (i, w) in c.get("data", []):
            rw[i] = f2_add(rw[i], w)
        if c.get("u_w"):
            rw[Urows[0]] = f2_add(rw[Urows[0]], c["u_w"][0])
            rw[Urows[1]] = f2_add(rw[Urows[1]], c["u_w"][1])
        if ci in pair_of:
            cm = c.get("cm", "rand")
            cm = rnd_f2(rng) if cm == "rand" else cm
            a, b = pair_of[ci]
            rw[a] = f2_add(rw[a], cm)
            rw[b] = f2_add(rw[b], f2_mul(cm, U))
        rws.append(rw)
    lam = [ZERO if c.get("lambda_zero") else rnd_f2(rng) for c in claims_spec]
    cws = [column_weights(rng, g["key"], n) for g in groups_spec]
    members = [[ci for ci, c in enumerate(claims_spec) if c["group"] == gi] for gi in range(len(groups_spec))]
    rhos = []
    for gi, mem in enumerate(members):
        rho = [ZERO] * R
        for ci in mem:
            for i in range(R):
                if rws[ci][i] != ZERO:
                    rho[i] = f2_add(rho[i], f2_mul(lam[ci], rws[ci][i]))
        rhos.append(rho)
    prho = [rnd_f2(rng) for _ in range(R)]
    if spec.get("prox_dep"):
        s = rnd_fp(rng)
        prho[prox[1]] = f2_scale(prho[prox[0]], s)
    # opened columns
    inv_rate = spec.get("inv_rate", 4)
    nn = inv_rate * n
    assert (P - 1) % nn == 0, f"no {nn}-th root of unity"
    assert n + Q <= nn, "encode_row_zk needs n + Q <= nn"
    d = spec.get("d", Q)
    w_nn = pow(7, (P - 1) // nn, P)
    w_n = pow(7, (P - 1) // n, P)
    idx = rng.sample(range(nn), d)
    E = []
    ninv = inv(n)
    for j in idx:
        x = 7 * pow(w_nn, j, P) % P
        zn = (pow(x, n, P) - 1) % P
        assert zn, "coset meets the subgroup"
        msg = [zn * ninv % P * inv((x * pow(w_n, (P - 1 - s) % (P - 1), P) - 1) % P) % P for s in range(n)]
        pad = [zn * pow(x, k, P) % P for k in range(Q)]
        E.append((msg, pad))
    return dict(n=n, Q=Q, d=d, R=R, D=D, U=Urows if u_mode == "constrained" else [], u_mode=u_mode,
                Nprime=Nprime, prox=prox, spare=spare, rws=rws, lam=lam, cws=cws, members=members,
                rhos=rhos, prho=prho, E=E, published=[c.get("published", True) for c in claims_spec],
                pair_of=pair_of)


def unknowns(m):
    """randomness first (N' messages, U free words, every pad), then data."""
    n, Q, R = m["n"], m["Q"], m["R"]
    col = 0
    msg = {}
    for i in m["Nprime"]:
        for t in range(n):
            msg[(i, t)] = {col: 1}
            col += 1
    for i in m["U"]:
        free = list(range(col, col + n - 1))
        col += n - 1
        for t in range(n - 1):
            msg[(i, t)] = {free[t]: 1}
        msg[(i, n - 1)] = {c: P - 1 for c in free}
    pad = {}
    for i in range(R):
        for k in range(Q):
            pad[(i, k)] = col
            col += 1
    first = col
    for i in m["D"]:
        for t in range(n):
            msg[(i, t)] = {col: 1}
            col += 1
    return col, first, msg, pad


def view(m, with_values=True):
    n, Q, R = m["n"], m["Q"], m["R"]
    ncols, first, msg, pad = unknowns(m)
    out = []

    def emit(cm, cp):
        for part in (0, 1):
            row = {}
            for key, c in cm.items():
                if c[part]:
                    for col, s in msg[key].items():
                        row[col] = (row.get(col, 0) + c[part] * s) % P
            for key, c in cp.items():
                if c[part]:
                    col = pad[key]
                    row[col] = (row.get(col, 0) + c[part]) % P
            out.append(row)

    for rho in m["rhos"] + [m["prho"]]:
        nzr = [i for i in range(R) if rho[i] != ZERO]
        for t in range(n):
            emit({(i, t): rho[i] for i in nzr}, {})
        for k in range(Q):
            emit({}, {(i, k): rho[i] for i in nzr})
    if with_values:
        for gi, mem in enumerate(m["members"]):
            cw = m["cws"][gi]
            for ci in mem:
                if not m["published"][ci]:
                    continue
                rw = m["rws"][ci]
                coefs = {}
                for i in range(R):
                    if rw[i] == ZERO:
                        continue
                    for t in range(n):
                        if cw[t] != ZERO:
                            coefs[(i, t)] = f2_mul(rw[i], cw[t])
                emit(coefs, {})
    for emsg, epad in m["E"]:
        for i in range(R):
            row = {}
            for t in range(n):
                for col, s in msg[(i, t)].items():
                    row[col] = (row.get(col, 0) + emsg[t] * s) % P
            for k in range(Q):
                row[pad[(i, k)]] = (row.get(pad[(i, k)], 0) + epad[k]) % P
            out.append(row)
    return out, ncols, first


def brute(m, with_values=True):
    rows, ncols, first = view(m, with_values)
    r_all, r_rand = rank_split(rows, ncols, first)
    return r_all - r_rand


def formula(m):
    R, n = m["R"], m["n"]
    G = []
    for rho in m["rhos"] + [m["prho"]]:
        G.append([rho[i][0] for i in range(R)])
        G.append([rho[i][1] for i in range(R)])
    D, Np, Ur = m["D"], m["Nprime"], m["U"]
    N = sorted(Np + Ur)

    def sub(cols):
        return [[g[i] for i in cols] for g in G]

    rG = rank(G, R)
    rN = rank(sub(N), len(N))
    k0 = rG - rN
    rDNp = rank(sub(sorted(D + Np)), len(D) + len(Np))
    rNp = rank(sub(Np), len(Np)) if Np else 0
    u_exact = rDNp - rNp - k0
    # the gate's per-indicator term
    u_tool, adm = 0, 0
    if Ur:
        GN = sub(N)
        xis = []
        for u in Ur:
            x = solve_left(GN, [1 if i == u else 0 for i in N])
            if x is None:
                continue
            adm += 1
            xis.append([sum(x[k] * G[k][i] for k in range(len(G))) % P for i in D])
        kb = [[sum(c[k] * G[k][i] for k in range(len(G))) % P for i in D] for c in left_kernel(GN, len(N))]
        u_tool = rank(xis + kb, len(D)) - (rank(kb, len(D)) if kb else 0)
    return dict(k0=k0, u_exact=u_exact, u_tool=u_tool, admissible=adm,
                formula_tool=n * k0 + u_tool, formula_exact=n * k0 + u_exact)


# ------------------------------------------------------ 2(c) diagnostics
def diagnostics(m):
    """The quantities of the check's proof of step 2(c)."""
    prho, (p0, p1) = m["prho"], m["prox"]
    # H-prox: rho_prox[p0], rho_prox[p1] Fp-independent  <=> wedge != 0
    wedge = (prho[p0][0] * prho[p1][1] - prho[p0][1] * prho[p1][0]) % P
    out = {"H_prox": wedge != 0, "multi": []}
    if wedge != 0:
        return out
    # theta_prox[t] in the line {w : Tr(w rho_prox[p0]) = 0}; w = U * conj-ish:
    a = prho[p0]
    # Tr(w a) = 2 * Re(w a); w = (x, y): Re(w a) = x a0 + 7 y a1 -> w = (7 a1, -a0)
    w = ((7 * a[1]) % P, (-a[0]) % P)
    assert f2_tr(f2_mul(w, a)) == 0

    def gamma(ci):
        # cm*x = s*gamma with Tr(gamma z_k) = -Tr(w rho_prox[r_c + k]), z = (1, U)
        r0, r1 = m["pair_of"][ci]
        t0 = (-f2_tr(f2_mul(w, prho[r0]))) % P
        t1 = (-f2_tr(f2_mul(w, prho[r1]))) % P
        # gamma = (g0, g1): Tr(gamma) = 2 g0 ; Tr(gamma U) = Tr(7 g1 + g0 U) = 14 g1
        return (t0 * inv(2) % P, t1 * inv(14) % P)

    for gi, mem in enumerate(m["members"]):
        owners = [ci for ci in mem if ci in m["pair_of"] and m["lam"][ci] != ZERO]
        if len(mem) < 2:
            continue
        cw = m["cws"][gi]
        nzt = [t for t in range(len(cw)) if cw[t] != ZERO]
        coll = True
        for t in nzt[1:]:
            r = f2_mul(cw[t], f2_inv(cw[nzt[0]]))
            if r[1] != 0:
                coll = False
                break
        beta_nz = False
        if len(owners) >= 2:
            c1, c2 = owners[0], owners[1]
            rw1 = m["rws"][c1][m["pair_of"][c1][0]]
            rw2 = m["rws"][c2][m["pair_of"][c2][0]]
            al1 = f2_mul(gamma(c1), f2_inv(f2_mul(rw1, m["lam"][c1])))
            al2 = f2_mul(gamma(c2), f2_inv(f2_mul(rw2, m["lam"][c2])))
            beta_nz = f2_sub(al2, al1) != ZERO
        out["multi"].append({"group": gi, "members": len(mem), "pair_owners": len(owners),
                             "cw_Fp_collinear": coll, "beta_nonzero": beta_nz,
                             "G1_and_G2": (not coll) and beta_nz})
    return out


# ------------------------------------------------------------- specs
def data_part(rng, nd, width=2):
    r0 = rng.randrange(0, max(1, nd - width + 1))
    cd = rnd_f2(rng)
    x = rnd_f2(rng)
    return [(r0, f2_mul(cd, f2_sub(ONE, x))), (r0 + 1, f2_mul(cd, x))] if width == 2 and r0 + 1 < nd else [(r0, cd)]


def spec_from_sizes(rng, n, Q, nd, sizes, *, key="auto", H=False, spare=0, prox_dep=False,
                    fp_groups=(), d=None, u_mode="constrained", sum_u=(ONE, U)):
    """A commitment with eval-claim groups of the given sizes (each claim owns
    a pair); on H also SC_ZS (own pair, (cd, cd*U) on the u rows, singleton)
    and the pairless LogUp sum claim ((1, U) on the u rows, +-1 / +-U on data
    plane rows, all-ones key, value not published)."""
    kind = key if key != "auto" else ("eq" if n & (n - 1) == 0 else "rand")
    groups, claims = [], []
    for gi, sz in enumerate(sizes):
        groups.append({"key": ("fp" if gi in fp_groups else kind)})
        for _ in range(sz):
            claims.append({"group": gi, "data": data_part(rng, nd)})
    if H:
        gi = len(groups)
        groups.append({"key": kind})
        cd = rnd_f2(rng)
        claims.append({"group": gi, "data": [], "u_w": (cd, f2_mul(cd, U))})
        gi += 1
        groups.append({"key": "ones"})
        data = []
        for k in range(0, nd - 1, 2):
            sg = ONE if rng.random() < 0.5 else (P - 1, 0)
            data += [(k, sg), (k + 1, f2_mul(sg, U))]
        claims.append({"group": gi, "data": data, "u_w": sum_u, "pair": False, "published": False})
    sp = {"n": n, "Q": Q, "nd": nd, "claims": claims, "groups": groups, "spare": spare,
          "prox_dep": prox_dep, "u": (u_mode if H else None)}
    if d is not None:
        sp["d"] = d
    return sp


A_SIZES = [35, 13, 11, 7, 6, 6, 3] + [2] * 12 + [1] * 17  # 36 groups, 122 claims (both shapes)
H_SIZES_125 = [17, 9, 7, 6, 6, 3, 1]  # + SC_ZS singleton + sum singleton = 9 groups, 51 claims
H_SIZES_G = [19, 9, 7, 6, 6, 3, 1]


def run(rng, spec, label, extra=None):
    t0 = time.time()
    m = build(rng, spec)
    b = brute(m, True)
    b_nov = b if label.startswith("EXACT ") else brute(m, False)  # the exact geometry: one pass only
    f = formula(m)
    dg = diagnostics(m)
    rec = {"case": label, "n": m["n"], "Q": m["Q"], "d": m["d"], "rows": m["R"], "data_rows": len(m["D"]),
           "groups": len(m["members"]), "claims": len(m["rws"]), "brute": b, "brute_without_values": b_nov,
           "values_contribution": b - b_nov, **f,
           "agree_tool": b == f["formula_tool"], "agree_exact": b == f["formula_exact"],
           "H_prox": dg["H_prox"], "multi": dg["multi"], "secs": round(time.time() - t0, 2)}
    if extra:
        rec.update(extra)
    return rec


def cases():
    """(label, spec-maker) pairs; spec-maker(rng) -> spec."""
    C = []
    # ---- the drafter's families on an extended grid (n = Q, n < Q to Q = 3n, odd n, d < Q)
    grid = [(4, 4), (4, 8), (4, 12), (8, 8), (8, 2), (3, 3), (3, 9), (5, 5), (5, 2), (15, 4), (16, 1), (6, 6)]
    for (n, Q) in grid:
        C.append((f"toy-H honest n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 1], H=True)))
        C.append((f"toy-A honest n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 1])))
        C.append((f"toy-H prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 1], H=True, prox_dep=True)))
        C.append((f"toy-A prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 1], prox_dep=True)))
        C.append((f"toy-A d<Q n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 1], d=max(1, Q // 2))))
        # zero slack: two singleton claims, no spare, dependent prox pair -> k0 = 1 -> n
        C.append((f"boundary prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [1, 1], prox_dep=True)))
        # ---- COUNTEREXAMPLE family for step 2(c): prox-dep + the only multi-member group Fp-collinear
        C.append((f"CE fp-group prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 1], prox_dep=True, fp_groups=(0,))))
        C.append((f"CE-control fp-group honest-prox n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 1], fp_groups=(0,))))
        C.append((f"CE-control fp-group + generic multi prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 2], prox_dep=True, fp_groups=(0,))))
        C.append((f"CE-control fp-group prox-dep + spare n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 1], prox_dep=True, fp_groups=(0,), spare=1)))
        # ---- u-term admissibility: the sum claim's u weights (1, a), a in Fp -> only a
        #      non-axis combination of the indicators is reachable
        C.append((f"U-adm sum-u=(1,a) n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 1], H=True, sum_u=(ONE, (5, 0)))))
    # ---- real group structures (sizes from the 125M / rung-G captures), reduced data rows
    for (n, Q) in [(4, 2), (2, 1)]:
        C.append((f"real-A-125M sizes n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 8, A_SIZES)))
        C.append((f"real-A-125M sizes prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 8, A_SIZES, prox_dep=True)))
        C.append((f"real-H-125M sizes n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 8, H_SIZES_125, H=True)))
        C.append((f"real-H-125M sizes prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 8, H_SIZES_125, H=True, prox_dep=True)))
        C.append((f"real-H-rungG sizes n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 8, H_SIZES_G, H=True)))
    # ---- real endpoint / boundary row geometry at the real n/Q ratios
    C.append(("real endpoint 125M rows=37 n=128 Q=2 (n/Q=64)", lambda r: spec_from_sizes(r, 128, 2, 32, [1], spare=1)))
    C.append(("real endpoint 125M rows=37 n=128 Q=2 prox-dep", lambda r: spec_from_sizes(r, 128, 2, 32, [1], spare=1, prox_dep=True)))
    C.append(("real boundary 125M rows=38 n=128 Q=2 (n/Q=64)", lambda r: spec_from_sizes(r, 128, 2, 32, [1, 1])))
    C.append(("real boundary 125M rows=38 n=128 Q=2 prox-dep", lambda r: spec_from_sizes(r, 128, 2, 32, [1, 1], prox_dep=True)))
    C.append(("real endpoint rung-G rows=9 n=64 Q=16 (n/Q=4)", lambda r: spec_from_sizes(r, 64, 16, 4, [1], spare=1)))
    C.append(("real endpoint rung-G rows=9 n=256 Q=4 (n/Q=64)", lambda r: spec_from_sizes(r, 256, 4, 4, [1], spare=1)))
    # ---- CE2: the counterexample's exact scope (run with the filter "CE2")
    for (n, Q) in [(4, 4), (8, 2), (3, 6), (5, 5)]:
        C.append((f"CE2 ones-group prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: _with_key(spec_from_sizes(r, n, Q, 4, [2, 1], prox_dep=True), 0, "ones")))
        C.append((f"CE2 range-group prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: _with_key(spec_from_sizes(r, n, Q, 4, [2, 1], prox_dep=True), 0, "range")))
        C.append((f"CE2 fpscaled-group prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: _with_key(spec_from_sizes(r, n, Q, 4, [2, 1], prox_dep=True), 0, "fpscaled")))
        C.append((f"CE2 three-member fp-group prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [3, 1], prox_dep=True, fp_groups=(0,))))
        C.append((f"CE2 two ones-groups prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: _with_key(_with_key(spec_from_sizes(r, n, Q, 4, [2, 2], prox_dep=True), 0, "ones"), 1, "ones")))
        C.append((f"CE2 two fp-groups prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 2], prox_dep=True, fp_groups=(0, 1))))
        C.append((f"CE2 H-like fp-group prox-dep n={n} Q={Q}", lambda r, n=n, Q=Q: spec_from_sizes(r, n, Q, 4, [2, 1], H=True, prox_dep=True, fp_groups=(0,))))
    # ---- REAL (n, Q, rows): the rung-G endpoint commitment exactly (9 rows, 4 data,
    #      n = 1024, Q = d = 256).  Heavy (~0.7 GB matrix): run alone, filter "EXACT".
    C.append(("EXACT rung-G endpoint rows=9 n=1024 Q=256", lambda r: spec_from_sizes(r, 1024, 256, 4, [1], spare=1)))
    C.append(("EXACTsmall rung-G endpoint geometry rows=9 n=256 Q=64", lambda r: spec_from_sizes(r, 256, 64, 4, [1], spare=1)))
    return C


def _with_key(spec, gi, key):
    spec["groups"][gi]["key"] = key
    return spec


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    seeds = [101] if only and only.startswith("EXACT ") else [101, 202, 303]
    out = []
    for ci, (label, mk) in enumerate(cases()):
        if only and only not in label:
            continue
        if not only and (label.startswith("CE2") or label.startswith("EXACT")):
            continue  # separate invocations (filters "CE2", "EXACT")
        for s in seeds:
            rng = random.Random(s * 1000003 + ci)
            spec = mk(rng)
            rec = run(rng, spec, label, {"seed": s})
            out.append(rec)
            print(json.dumps({k: rec[k] for k in ("case", "seed", "brute", "brute_without_values", "k0", "u_exact", "u_tool",
                                                  "admissible", "formula_tool", "formula_exact", "agree_tool", "agree_exact",
                                                  "H_prox", "secs")}), flush=True)
            if rec["multi"] and not rec["H_prox"]:
                print("   multi:", json.dumps(rec["multi"]), flush=True)
    json.dump(out, open(__file__.rsplit("/", 1)[0] + "/gs5_check" + ("_" + only.replace(" ", "_") if only else "") + ".json", "w"), indent=1)


if __name__ == "__main__":
    main()
