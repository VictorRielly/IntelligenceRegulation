#!/usr/bin/env python3
"""Five follow-ups the first pass left open (same model, same captures).

  A1 the ONE nonzero disclosure found (H, the sum-claim group, 2 Fp): is the
     disclosed functional the PUBLIC LogUp identity, or something else?
  A2 the assembly premises, at full scale: reserved pairs are disjoint ACROSS
     groups, no group combination touches the proximity pair, and the
     proximity pair alone maps ONTO Fp2^256 (so the proximity vector drops
     out of the per-group decomposition).
  A3 control C8 (a pair whose two weights are Fp-dependent) on a SINGLETON
     group, where nothing else can cover the missing direction.
  A4 the same on a shared pair in a singleton-pair situation, and cm = 0 on a
     singleton group -- the shape the earlier check's control used.
  A5 the per-group rank with the group vector's PAD half and the opened
     columns put back in, on the two endpoint commitments (7 rows), where
     the whole system is small enough to build densely: the end-to-end
     instance of the reduction the bigger roles are argued down to.
"""

from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import ts_review as T  # noqa: E402
from ts_field import (  # noqa: E402
    Elim,
    F2_ONE,
    F2_ZERO,
    P,
    f2_add,
    f2_is_zero,
    f2_mul,
    inv,
)

N = T.N_COLS


def rank_of(gens):
    e = Elim()
    for g in gens:
        e.add(dict(g))
    return e.rank


def a1_logup(roles):
    """Is H's 2 Fp of disclosure the public LogUp identity?

    The disclosed space is { phi B : phi A = 0 }.  Here A's left null space
    is spanned by the group identity (2 Fp) plus whatever the zero-sum
    constraint adds; we compute the image on the data coordinates and
    compare its span with the span of the sum claim's OWN data-row weights,
    which are the public identity sum_i (helpers - tables) + u = 0.
    """
    out = []
    for cap, profile, rs in roles:
        H = [r for r in rs if r.name == "H"][0]
        gi = [i for i in range(len(H.groups))
              if any(set(H.rws[c]) & set(H.u_rows) and
                     all(r in H.u_rows for r in H.rws[c] if H.kind[r] != "data")
                     for c in H.groups[i])]
        for g in gi:
            blind, data, m, info, (lam, cw, rws, rho, members) = T.group_system(H, g)
            # left null space of the blinding block, computed over the
            # observation coordinates by transposing the generator list
            cols = sorted({c for gen in blind for c in gen} |
                          {c for gen in data for c in gen})
            idx = {c: k for k, c in enumerate(cols)}
            # build the transpose: one row per observation coordinate
            tr = [dict() for _ in cols]
            for gk, gen in enumerate(blind):
                for c, v in gen.items():
                    tr[idx[c]][gk] = v
            # a basis of the left null space by elimination on the transpose
            e = Elim()
            null = []
            for k, row in enumerate(tr):
                r = dict(row)
                r[10 ** 9 + k] = 1  # track the combination
                c, red = e.reduce(r)
                if c is not None and c < 10 ** 9:
                    e.piv[c] = {kk: vv * inv(red[c]) % P for kk, vv in red.items()}
                else:
                    null.append({cols[kk - 10 ** 9]: vv
                                 for kk, vv in red.items() if kk >= 10 ** 9})
            # the disclosed functionals: phi applied to the data generators
            disclosed = []
            data_rows = sorted({i for i in range(H.rows) if H.kind[i] == "data"})
            for phi in null:
                vec = {}
                for i in data_rows:
                    for j in range(N):
                        gen = T._gen_of(H, g, i, j, lam, cw, rws, rho, members)
                        s = sum(phi.get(c, 0) * v for c, v in gen.items()) % P
                        if s:
                            vec[(i, j)] = s
                if vec:
                    disclosed.append(vec)
            # the public LogUp identity: the sum claim's own data-row weights,
            # with the all-ones column weights (cw), as two Fp functionals
            c_sum = [c for c in members if set(H.rws[c]) & set(H.u_rows)][0]
            pub = [dict(), dict()]
            for i in data_rows:
                w = H.rws[c_sum].get(i)
                if w is None:
                    continue
                for j in range(N):
                    if f2_is_zero(cw[j]):
                        continue
                    t = f2_mul(w, cw[j])
                    if t[0]:
                        pub[0][(i, j)] = t[0]
                    if t[1]:
                        pub[1][(i, j)] = t[1]
            keys = sorted({k for v in disclosed + pub for k in v})
            ki = {k: n for n, k in enumerate(keys)}
            dd = [{ki[k]: v for k, v in x.items()} for x in disclosed]
            pp = [{ki[k]: v for k, v in x.items()} for x in pub if x]
            out.append({
                "capture": cap, "role": "H", "group": g,
                "left_null_dimension": len(null),
                "disclosed_functionals": len(dd),
                "rank_disclosed": rank_of(dd),
                "rank_public_logup_identity": rank_of(pp),
                "rank_together": rank_of(dd + pp),
                "disclosed_equals_public_identity":
                    rank_of(dd) == rank_of(pp) == rank_of(dd + pp) == 2,
            })
    return out


def a2_assembly(roles):
    out = []
    for cap, profile, rs in roles:
        for role in rs:
            # (i) the non-data support of each group's rho, and disjointness
            support = {}
            overlap = 0
            for gi in range(len(role.groups)):
                s = {i for i in role.rho[gi] if role.kind[i] != "data"}
                for gj, t in support.items():
                    if s & t:
                        overlap += 1
                support[gi] = s
            # (ii) no group rho touches a proximity row
            prox_hit = sum(1 for gi in range(len(role.groups))
                           for i in role.rho[gi] if role.kind[i] == "prox")
            # (iii) the proximity pair alone is onto Fp2^256
            p0, p1 = role.prox_rows[0], role.prox_rows[1]
            gens = []
            for i in (p0, p1):
                a = role.prox_rho[i]
                for j in range(N):
                    g = {}
                    if a[0]:
                        g[2 * j] = a[0]
                    if a[1]:
                        g[2 * j + 1] = a[1]
                    gens.append(g)
            out.append({
                "capture": cap, "role": role.name,
                "group_rho_nondata_supports_pairwise_disjoint": overlap == 0,
                "group_rho_touching_a_proximity_row": prox_hit,
                "prox_pair_alone_rank_on_the_proximity_vector": rank_of(gens),
                "prox_pair_onto_Fp2_256": rank_of(gens) == 512,
                "claims_touching_a_proximity_row": sum(
                    1 for rw in role.rws for i in rw if role.kind[i] == "prox"),
            })
    return out


def a3_a4_singleton_controls(roles):
    cap, profile, rs = roles[0]
    A = [r for r in rs if r.name == "A"][0]
    singles = [gi for gi in range(len(A.groups)) if len(A.groups[gi]) == 1]
    two = [gi for gi in range(len(A.groups)) if len(A.groups[gi]) == 2]
    out = []
    gi = singles[0]
    c0 = A.groups[gi][0]
    pair = sorted(r for r in A.rws[c0] if A.kind[r] != "data")

    honest = T.analyse_group(A, gi)
    out.append({"control": "A3 singleton group, honest", "group": gi,
                "rank_blinding": honest["rank_blinding"],
                "disclosed_Fp": honest["disclosed_Fp"]})

    rw = dict(A.rws[c0])
    rw[pair[1]] = rw[pair[0]]
    r = T.analyse_group(A, gi, {"rws": {c0: rw}})
    out.append({"control": "A3 singleton, pair weights Fp-dependent (not (cm, cm U))",
                "group": gi, "rank_blinding": r["rank_blinding"],
                "disclosed_Fp": r["disclosed_Fp"], "fires": r["disclosed_Fp"] > 0})

    rw = {i: v for i, v in A.rws[c0].items() if i not in pair}
    r = T.analyse_group(A, gi, {"rws": {c0: rw}})
    out.append({"control": "A4 singleton, cm = 0 (pair removed)", "group": gi,
                "rank_blinding": r["rank_blinding"],
                "disclosed_Fp": r["disclosed_Fp"], "fires": r["disclosed_Fp"] > 0})

    r = T.analyse_group(A, gi, {"lambdas": [F2_ZERO]})
    out.append({"control": "A4 singleton, lambda = 0", "group": gi,
                "rank_blinding": r["rank_blinding"],
                "disclosed_Fp": r["disclosed_Fp"], "fires": r["disclosed_Fp"] > 0})

    # a two-member group with the pair shared, as a minimal version of the
    # project's counterexample
    gj = two[0]
    c1, c2 = A.groups[gj]
    p1 = sorted(r for r in A.rws[c1] if A.kind[r] != "data")
    p2 = sorted(r for r in A.rws[c2] if A.kind[r] != "data")
    rw2 = {i: v for i, v in A.rws[c2].items() if i not in p2}
    rw2[p1[0]] = f2_add(rw2.get(p1[0], F2_ZERO), A.rws[c2][p2[0]])
    rw2[p1[1]] = f2_add(rw2.get(p1[1], F2_ZERO), A.rws[c2][p2[1]])
    r = T.analyse_group(A, gj, {"rws": {c2: rw2}})
    out.append({"control": "A4 two-member group, one shared pair", "group": gj,
                "rank_blinding": r["rank_blinding"],
                "disclosed_Fp": r["disclosed_Fp"], "fires": r["disclosed_Fp"] > 0})
    return out


def a5_small_full_view(seeds=(1, 2, 3, 4, 5, 6, 7, 8)):
    """My own small model, where the FULL view is ranked by brute force.

    The real roles are too large to rank with the pad halves and the opened
    columns in place, so the argument reduces them to the per-group
    MESSAGE-half system.  This is the validation of that reduction, on a toy
    of the same shape (n = 4 message columns, q = 4 pads, nn = 16 encoded
    positions, d <= q opened) -- and, unlike the project's own small model
    (`zk60_native_jv_smallmodel`, one group per claim), it carries a group
    with SEVERAL members, which is the case the step under review is about.

    Reported per instance:
      disclosed_full        rank(all observations) - rank(the same restricted
                            to the non-data coordinates), the definition
      disclosed_reduction   the per-group message-half computation this
                            review runs on the real captures
    They must agree, honestly and under every control.
    """
    import random

    n, nn, q = 4, 16, 4
    coset = 7

    def col_fun(j):
        w_nn = T.two_adic_root(nn.bit_length() - 1)
        w_n = T.two_adic_root(n.bit_length() - 1)
        xj = coset * pow(w_nn, j, P) % P
        zn = (pow(xj, n, P) - 1) % P
        ninv = inv(n)
        msg, wns, wninv = [], 1, inv(w_n)
        for _ in range(n):
            msg.append(zn * ninv % P * inv((xj * wns - 1) % P) % P)
            wns = wns * wninv % P
        pad, xp = [], 1
        for _ in range(q):
            pad.append(zn * xp % P)
            xp = xp * xj % P
        return msg, pad

    out = []
    for seed in seeds:
        for mode in ("honest", "shared_pair", "cm_zero", "lambda_zero", "one_pad_short"):
            rnd = random.Random(seed * 1000 + hash(mode) % 97)
            n_data = 2
            # group 0: three members; group 1: one member
            sizes = [3, 1]
            pairs, row = [], n_data
            for g in sizes:
                for _ in range(g):
                    pairs.append((row, row + 1))
                    row += 2
            if mode == "shared_pair":
                pairs[1] = pairs[0]
            prox = (row, row + 1)
            rows = row + 2
            kinds = ["data"] * n_data + ["mask"] * (row - n_data) + ["prox", "prox"]

            def f2r(nonzero=True):
                return (rnd.randrange(1 if nonzero else 0, P), rnd.randrange(P))

            cws = []
            for g in sizes:
                tail = [f2r() for _ in range(2)]
                e = [F2_ONE]
                for r in reversed(tail):
                    om = (1 - r[0]) % P, (-r[1]) % P
                    e = [f2_mul(x, om) for x in e] + [f2_mul(x, r) for x in e]
                cws.append(e)
            rws, gof, k = [], [], 0
            for gi, g in enumerate(sizes):
                for _ in range(g):
                    w = {i: f2r(False) for i in range(n_data)}
                    cm = f2r()
                    if mode == "cm_zero" and k == 0:
                        pass
                    else:
                        w[pairs[k][0]] = f2_add(w.get(pairs[k][0], F2_ZERO), cm)
                        w[pairs[k][1]] = f2_add(w.get(pairs[k][1], F2_ZERO),
                                                f2_mul(cm, (0, 1)))
                    rws.append(w)
                    gof.append(gi)
                    k += 1
            lams = []
            for gi, g in enumerate(sizes):
                lam = [f2r() for _ in range(g)]
                if mode == "lambda_zero" and gi == 0:
                    lam[0] = F2_ZERO
                lams.append(lam)
            rhos = []
            for gi, g in enumerate(sizes):
                rho = {}
                for c in [i for i in range(len(rws)) if gof[i] == gi]:
                    l = lams[gi][[i for i in range(len(rws)) if gof[i] == gi].index(c)]
                    for i, v in rws[c].items():
                        rho[i] = f2_add(rho.get(i, F2_ZERO), f2_mul(l, v))
                rhos.append({i: v for i, v in rho.items() if not f2_is_zero(v)})
            prho = {i: f2r() for i in range(rows)}
            opened = sorted(rnd.sample(range(nn), q if mode != "one_pad_short" else q + 1))
            efun = {j: col_fun(j) for j in opened}

            width = 2 * n
            total = rows * width

            def uidx(i, t, is_pad):
                return i * width + (n + t if is_pad else t)

            obs = []
            # claim values
            for c, w in enumerate(rws):
                re, im = [0] * total, [0] * total
                for i, a in w.items():
                    for t in range(n):
                        x = f2_mul(a, cws[gof[c]][t])
                        re[uidx(i, t, False)] = (re[uidx(i, t, False)] + x[0]) % P
                        im[uidx(i, t, False)] = (im[uidx(i, t, False)] + x[1]) % P
                obs += [re, im]
            # group and proximity vectors, both halves
            for rr in rhos + [prho]:
                for is_pad in (False, True):
                    for t in range(n):
                        re, im = [0] * total, [0] * total
                        for i, a in rr.items():
                            re[uidx(i, t, is_pad)] = a[0]
                            im[uidx(i, t, is_pad)] = a[1]
                        obs += [re, im]
            # opened columns
            for j in opened:
                msg, pad = efun[j]
                for i in range(rows):
                    v = [0] * total
                    for t in range(n):
                        v[uidx(i, t, False)] = msg[t]
                    for t in range(q):
                        v[uidx(i, t, True)] = pad[t]
                    obs.append(v)
            dcols = {uidx(i, t, False) for i in range(rows) if kinds[i] == "data"
                     for t in range(n)}
            keep = [c for c in range(total) if c not in dcols]
            full = T.dense_rank(obs, total)
            ronly = T.dense_rank([[r[c] for c in keep] for r in obs], len(keep))
            disclosed_full = full - ronly

            # the reduction: per group, message half only
            disclosed_red = 0
            for gi, g in enumerate(sizes):
                mem = [i for i in range(len(rws)) if gof[i] == gi]
                blind, data = [], []
                touched = set(rhos[gi]) | {i for c in mem for i in rws[c]}
                for i in sorted(touched):
                    for t in range(n):
                        gen = {}
                        a = rhos[gi].get(i)
                        if a is not None:
                            if a[0]:
                                gen[2 * t] = a[0]
                            if a[1]:
                                gen[2 * t + 1] = a[1]
                        if not f2_is_zero(cws[gi][t]):
                            for kk, c in enumerate(mem):
                                w = rws[c].get(i)
                                if w is None:
                                    continue
                                x = f2_mul(w, cws[gi][t])
                                if x[0]:
                                    gen[1000 + 2 * kk] = x[0]
                                if x[1]:
                                    gen[1000 + 2 * kk + 1] = x[1]
                        (data if kinds[i] == "data" else blind).append(gen)
                rb = rank_of(blind)
                e = Elim()
                for gg in blind:
                    e.add(dict(gg))
                for gg in data:
                    e.add(dict(gg))
                disclosed_red += e.rank - rb
            out.append({
                "seed": seed, "mode": mode, "rows": rows, "opened": len(opened),
                "pads": q, "disclosed_full_bruteforce": disclosed_full,
                "disclosed_per_group_reduction": disclosed_red,
                "agree": disclosed_full == disclosed_red,
            })
    return out


def main():
    roles = T.load_captures()
    res = {}
    res["A1_H_disclosure_is_the_public_identity"] = a1_logup(roles)
    print("A1 done", flush=True)
    res["A2_assembly_premises"] = a2_assembly(roles)
    print("A2 done", flush=True)
    res["A3_A4_singleton_controls"] = a3_a4_singleton_controls(roles)
    print("A3/A4 done", flush=True)
    res["A5_small_full_view_vs_reduction"] = a5_small_full_view()
    print("A5 done", flush=True)
    path = os.path.join(HERE, "ts_addendum.json")
    with open(path, "w") as fh:
        json.dump(res, fh, indent=1, sort_keys=True)
    print("wrote", path)


if __name__ == "__main__":
    main()
