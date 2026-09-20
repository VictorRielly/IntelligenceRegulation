#!/usr/bin/env python3
"""INDEPENDENT CHECK, attack 3: H's u-row term -- what the two disclosed
functionals actually are, at FRESH challenges on the real H schedule.

For each u row, solve  c . gens|non-data = e_u  and map the solution onto the
data rows (the tool's `_disclosed`, re-implemented here).  Then compare the
resulting span with the span of the LogUp SUM CLAIM's own data-row weights,
i.e. the real and imaginary parts of the value-0 identity that
`protocol.rs::logup_sum_claim` declares with value Fp2::ZERO.
"""

import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_pair_factorisation import (  # noqa: E402
    P, U, ZERO, add, mul, rank, zpart_weights, CAPDIR)

rng = random.Random(0xF00D)


def solve(rows, target, ncols):
    """least-structure solve: x . rows = target (rows indexed by generator)."""
    m = len(rows)
    aug = [[rows[k][c] for k in range(m)] + [target[c]] for c in range(ncols)]
    piv = []
    r = 0
    for c in range(m):
        p = None
        for i in range(r, len(aug)):
            if aug[i][c] % P:
                p = i
                break
        if p is None:
            continue
        aug[r], aug[p] = aug[p], aug[r]
        iv = pow(aug[r][c], P - 2, P)
        aug[r] = [x * iv % P for x in aug[r]]
        for i in range(len(aug)):
            if i != r and aug[i][c] % P:
                f = aug[i][c]
                aug[i] = [(a - f * b) % P for a, b in zip(aug[i], aug[r])]
        piv.append(c)
        r += 1
    for i in range(r, len(aug)):
        if aug[i][m] % P:
            return None                     # inconsistent
    x = [0] * m
    for i, c in enumerate(piv):
        x[c] = aug[i][m]
    return x


def main():
    for fn in sorted(os.listdir(CAPDIR)):
        if not fn.endswith(".json"):
            continue
        cap = json.load(open(os.path.join(CAPDIR, fn)))
        prof = "block" if "block" in cap["profile"] else "attention"
        role = [r for r in cap["roles"] if r["role"] == "H"][0]
        rows = role["commitment"]["rows"]
        kinds = {r["row"]: r["kind"] for r in role["row_roles"]}
        data_rows = [r for r in range(rows) if kinds[r] == "data"]
        other = [r for r in range(rows) if kinds[r] != "data"]
        u_rows = sorted(x for plc in role["public_linear_constraints"]
                        for x in plc["rows"])

        rws, keys = [], []
        for cl in role["claims"]:
            rw = [ZERO] * rows
            k = None
            for pt in cl["parts"]:
                w, kk, _ = zpart_weights(pt, rows)
                k = kk if k is None else k
                rw = [add(a, b) for a, b in zip(rw, w)]
            rws.append(rw)
            keys.append(k)
        order, seen = [], set()
        for k in keys:
            if k not in seen:
                seen.add(k)
                order.append(k)
        members = [[ci for ci, k in enumerate(keys) if k == kk] for kk in order]
        sum_gi = [gi for gi, g in enumerate(members)
                  if any(not role["claims"][ci]["parts"][0]["point"] for ci in g)]
        sum_ci = [ci for ci in range(len(rws))
                  if all(not p["point"] for p in role["claims"][ci]["parts"])]

        # the sum claim's own data-row weights: the public LogUp identity
        logup = [[rws[sum_ci[0]][i][0] for i in data_rows],
                 [rws[sum_ci[0]][i][1] for i in data_rows]]

        for trial in range(3):
            lams = [[(rng.randrange(P), rng.randrange(P)) for _ in g] for g in members]
            rhos = []
            for gi, g in enumerate(members):
                rho = [ZERO] * rows
                for k, ci in enumerate(g):
                    for i in range(rows):
                        if rws[ci][i] != ZERO:
                            rho[i] = add(rho[i], mul(lams[gi][k], rws[ci][i]))
                rhos.append(rho)
            prox = [(rng.randrange(P), rng.randrange(P)) for _ in range(rows)]
            gens = []
            for rho in rhos + [prox]:
                gens.append([v[0] for v in rho])
                gens.append([v[1] for v in rho])
            gnd = [[g[i] for i in other] for g in gens]

            xis, admissible, used_gen = [], 0, set()
            for u in u_rows:
                t = [1 if i == u else 0 for i in other]
                x = solve(gnd, t, len(other))
                if x is None:
                    continue
                admissible += 1
                used_gen |= {k for k, c in enumerate(x) if c}
                xi = [0] * len(data_rows)
                for k, c in enumerate(x):
                    if c:
                        for a, i in enumerate(data_rows):
                            xi[a] = (xi[a] + c * gens[k][i]) % P
                xis.append(xi)
            r_xi = rank(xis, len(data_rows)) if xis else 0
            r_lg = rank(logup, len(data_rows))
            r_both = rank(xis + logup, len(data_rows))
            if trial == 0:
                print(f"=== {fn[:8]} {prof} H: {rows} rows, u rows {u_rows}, "
                      f"sum claim index {sum_ci}, its group {sum_gi} "
                      f"(size {[len(members[g]) for g in sum_gi]})")
                # is the sum claim alone in its group?
                print(f"    groups: {len(members)}; the sum claim's group has "
                      f"{len(members[sum_gi[0]])} member(s)")
            print(f"    trial {trial}: admissible u indicators {admissible}/2, "
                  f"generators used {sorted(used_gen)}, "
                  f"rank(xi) {r_xi}, rank(logup) {r_lg}, rank(xi+logup) {r_both}, "
                  f"SPANS EQUAL {r_xi == r_lg == r_both == 2}")
        print(f"    sum-claim declared value (must be public 0): "
              f"{role['claims'][sum_ci[0]]['value']}")
        print()


if __name__ == "__main__":
    main()
