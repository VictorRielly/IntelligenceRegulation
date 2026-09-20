#!/usr/bin/env python3
"""The per-group decomposition is not valid everywhere: on H two opening
groups SHARE the zero-sum pair (the zsum slot's claim evaluates the u rows,
and the LogUp sum claim is masked by them).  Addendum A2 found this.

So: split each role's groups into the connected components of the relation
"two groups touch a common non-data row", and rank each COMPONENT as one
system -- every member group's vector (message half), every one of the
component's individual claim values, against every blinding coordinate the
component touches (with the u rows' zero-sum constraint).  A component of
size one reproduces the per-group number; a bigger one is the honest
version of it.
"""

from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import ts_review as T  # noqa: E402
from ts_field import Elim, F2_ZERO, P, f2_add, f2_is_zero, f2_mul, f2_neg  # noqa: E402

N = T.N_COLS


def components(role):
    nd = []
    for gi in range(len(role.groups)):
        s = {i for i in role.rho[gi] if role.kind[i] != "data"}
        for c in role.groups[gi]:
            s |= {i for i in role.rws[c] if role.kind[i] != "data"}
        nd.append(s)
    parent = list(range(len(nd)))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for a in range(len(nd)):
        for b in range(a + 1, len(nd)):
            if nd[a] & nd[b]:
                parent[find(a)] = find(b)
    comp = {}
    for a in range(len(nd)):
        comp.setdefault(find(a), []).append(a)
    return sorted(comp.values())


def analyse_component(role, gs):
    """One system over all the component's groups."""
    slot = {}          # (kind, key) -> observation column base

    def col(name):
        if name not in slot:
            slot[name] = len(slot) * 2
        return slot[name]

    members, cw, rho = {}, {}, {}
    for gi in gs:
        members[gi] = role.groups[gi]
        cw[gi] = role.cw[gi]
        rho[gi] = role.rho[gi]
    touched = set()
    for gi in gs:
        touched |= set(rho[gi])
        for c in members[gi]:
            touched |= set(role.rws[c])

    def gen(i, j):
        g = {}
        for gi in gs:
            a = rho[gi].get(i)
            if a is not None:
                b = col(("v", gi, j))
                if a[0]:
                    g[b] = a[0]
                if a[1]:
                    g[b + 1] = a[1]
            if f2_is_zero(cw[gi][j]):
                continue
            for c in members[gi]:
                w = role.rws[c].get(i)
                if w is None:
                    continue
                x = f2_mul(w, cw[gi][j])
                b = col(("y", c))
                if x[0]:
                    g[b] = (g.get(b, 0) + x[0]) % P
                if x[1]:
                    g[b + 1] = (g.get(b + 1, 0) + x[1]) % P
        return {k: v for k, v in g.items() if v}

    blind, data = [], []
    for i in sorted(touched):
        if role.kind[i] == "data":
            for j in range(N):
                data.append(gen(i, j))
        elif i in role.u_rows:
            for j in range(N - 1):
                a, b = gen(i, j), gen(i, N - 1)
                d = dict(a)
                for k, v in b.items():
                    nv = (d.get(k, 0) - v) % P
                    if nv:
                        d[k] = nv
                    elif k in d:
                        del d[k]
                blind.append(d)
        else:
            for j in range(N):
                blind.append(gen(i, j))
    e = Elim()
    for g in blind:
        e.add(dict(g))
    rb = e.rank
    for g in data:
        e.add(dict(g))
    n_claims = sum(len(members[gi]) for gi in gs)
    return {
        "groups": gs,
        "claims": n_claims,
        "blinding_rows": len([i for i in touched if role.kind[i] != "data"]),
        "u_rows": sorted(i for i in touched if i in role.u_rows),
        "data_rows": len([i for i in touched if role.kind[i] == "data"]),
        "observation_Fp": 2 * (N * len(gs) + n_claims),
        "rank_blinding": rb,
        "rank_blinding_plus_data": e.rank,
        "disclosed_Fp": e.rank - rb,
    }


def main():
    roles = T.load_captures()
    out = []
    for cap, profile, rs in roles:
        for role in rs:
            comps = components(role)
            per = [analyse_component(role, gs) for gs in comps if len(gs) > 1]
            out.append({
                "capture": cap, "profile": profile.split("/")[1], "role": role.name,
                "components": len(comps),
                "multi_group_components": [c["groups"] for c in comps if len(c) > 1]
                if False else [gs for gs in comps if len(gs) > 1],
                "multi_group_detail": per,
                "disclosed_from_multi_group_components": sum(c["disclosed_Fp"] for c in per),
            })
    path = os.path.join(HERE, "ts_components.json")
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
    for o in out:
        print(json.dumps(o))
    print("wrote", path)


if __name__ == "__main__":
    main()
