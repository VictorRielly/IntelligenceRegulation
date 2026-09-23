"""GS-4 adversarial check: the theorem-level hypotheses read straight off the
verifier-side claim lists of the captures, with code of my own (nothing from
results/zk60_gs_closures/ or the gate is imported).

For every commitment view of the four 125M captures and the two rung-G block
captures it recomputes each claim's weights on the NON-DATA rows (the rule of
zkp-core/src/pcs.rs:860-900 at lane 2ea7221, re-implemented) and checks:

  X1  every non-sum claim's non-data support is exactly one adjacent pair
      (r, r+1) of the declared site rows, at even offset from the first site row;
  X2  the pair's two weights are (cm, cm*U) with cm != 0  (the Fp-basis leg,
      which audit_claims does NOT check -- it holds by build_claim's construction);
  X3  pairs are pairwise DISJOINT and their union is EVERY site row
      (the gate's H-pair checks neither; see gate_overlap.py);
  X4  nothing touches the proximity rows (prox, prox+1) or any row above;
  X5  the sum claim (H only) touches no site row and carries (c, c*U) on the
      two zero-sum rows;
  PI  the proximity rho's two coefficients at (prox, prox+1), read from the
      capture's array store (bytes checked against the array's sha256 id),
      have nonzero Fp-wedge  (H-prox; ENFORCED by check_opening_challenges,
      protocol.rs:305-310);
  LAM every group member's lambda != 0 (ENFORCED, protocol.rs:296-301);
  G1  no multi-member group has Fp-collinear column weights (the condition
      under which the check's proof of step 2(c) applies; the counterexample
      family needs a violation of it).

Read-only; writes only its own .json next to itself.
"""

from __future__ import annotations

import hashlib
import json
import os
import struct
import sys

P = 2**64 - 2**32 + 1
NR = 7
ART = "/home/victor/zk60-artifacts"
LANE = "/home/victor/wt-zk60-block125m/results/zk60_block_captures_20260923/rung-g"
CAPTURES = [
    ("125M run dense stage 0", f"{ART}/m125-capture-dense-l2", "stage-00.json"),
    ("125M run dense stage 1", f"{ART}/m125-capture-dense-l2", "stage-01.json"),
    ("125M run zero stage 0", f"{ART}/m125-capture-zero-l2", "stage-00.json"),
    ("125M run zero stage 1", f"{ART}/m125-capture-zero-l2", "stage-01.json"),
    ("125M block dense", f"{ART}/block-captures-20260923/m125-dense", "observations.json"),
    ("125M block zero", f"{ART}/block-captures-20260923/m125-zero", "observations.json"),
    ("rung-G block dense", f"{LANE}/rung-g-dense", "observations.json"),
    ("rung-G block zero", f"{LANE}/rung-g-zero", "observations.json"),
]


def mul(x, y):
    return ((x[0] * y[0] + NR * x[1] * y[1]) % P, (x[0] * y[1] + x[1] * y[0]) % P)


def add(x, y):
    return ((x[0] + y[0]) % P, (x[1] + y[1]) % P)


def inv2(x):
    nrm = (x[0] * x[0] - NR * x[1] * x[1]) % P
    i = pow(nrm, P - 2, P)
    return (x[0] * i % P, (-x[1]) * i % P)


def eq_msb(point):
    out = [(1, 0)]
    for r in point:
        om = ((1 - r[0]) % P, (-r[1]) % P)
        out = [v for e in out for v in (mul(e, om), mul(e, r))]
    return out


def nondata_weights(claim, n, log_cols, first_nondata):
    """{row: Fp2 weight} over rows >= first_nondata (pcs.rs:860-900's rule)."""
    w = {}
    for p in claim["parts"]:
        ls = p["log_size"]
        coef = tuple(p["coefficient"])
        r0 = p["offset"] // n
        pt = [tuple(x) for x in p["point"]]
        if ls >= log_cols:
            assert p["offset"] % n == 0
            lr = ls - log_cols
            rw = eq_msb(pt[:lr]) if pt else [(1, 0)] * (1 << lr)
            for i, e in enumerate(rw):
                r = r0 + i
                if r >= first_nondata:
                    w[r] = add(w.get(r, (0, 0)), mul(coef, e))
        else:
            if r0 >= first_nondata:
                w[r0] = add(w.get(r0, (0, 0)), coef)
    return {r: v for r, v in w.items() if v != (0, 0)}


def read_fp2_array(bundle, ref):
    if isinstance(ref, list):  # small arrays are inline in the JSON
        return [tuple(x) for x in ref], True
    with open(os.path.join(bundle, "arrays.bin"), "rb") as f:
        f.seek(ref["offset"])
        raw = f.read(ref["bytes"])
    ok_sha = hashlib.sha256(raw).hexdigest() == ref["array"]
    vals = struct.unpack("<" + "Q" * (2 * ref["len"]), raw)
    return [(vals[2 * i], vals[2 * i + 1]) for i in range(ref["len"])], ok_sha


def check_role(bundle, role):
    lc = role["params"]["log_cols"]
    n = 1 << lc
    rows = role["commitment"]["rows"]
    sites = sorted(role["site_rows"])
    prox = role["prox_row"]
    sums = role["sum_rows"] or []
    first_nd = min(sites + sums + [prox])
    res = {"role": role["role"], "kind": role["commitment_kind"], "rows": rows, "claims": len(role["claims"]),
           "site_rows": len(sites), "failures": []}
    fail = res["failures"].append
    pairs = []
    for ci, c in enumerate(role["claims"]):
        w = nondata_weights(c, n, lc, first_nd)
        is_sum = all(len(p["point"]) == 0 for p in c["parts"])
        if any(r >= prox for r in w):
            fail(f"X4 claim {ci} touches row >= prox")
        if is_sum:
            if set(w) != set(sums) or any(r in sites for r in w):
                fail(f"X5 sum claim {ci} support {sorted(w)}")
            elif mul(w[sums[0]], (0, 1)) != w[sums[1]]:
                fail(f"X5 sum claim {ci} weights not (c, cU)")
            continue
        sup = sorted(r for r in w if r not in sums)
        if len(sup) != 2 or sup[1] != sup[0] + 1 or sup[0] not in sites or sup[1] not in sites or (sup[0] - sites[0]) % 2:
            fail(f"X1 claim {ci} non-data support {sup}")
            continue
        cm = w[sup[0]]
        if cm == (0, 0) or mul(cm, (0, 1)) != w[sup[1]]:
            fail(f"X2 claim {ci} pair weights not (cm, cm*U)")
        pairs.append((sup[0], sup[1]))
    used = [r for pr in pairs for r in pr]
    if len(used) != len(set(used)):
        fail("X3 pairs overlap")
    if set(used) != set(sites):
        fail(f"X3 site rows unused: {sorted(set(sites) - set(used))}")
    res["pairs"] = len(pairs)
    res["sites_each_used_once"] = len(used) == len(set(used)) and set(used) == set(sites)
    # H-prox from the array store
    rho, ok_sha = read_fp2_array(bundle, role["proximity_rhos"])
    a, b = rho[prox], rho[prox + 1]
    wedge = (a[0] * b[1] - a[1] * b[0]) % P
    res["prox_rhos_sha_ok"] = ok_sha
    res["H_prox_wedge_nonzero"] = wedge != 0
    if not ok_sha or wedge == 0:
        fail("PI")
    lam_ok = all(tuple(l) != (0, 0) for g in role["groups"] for l in g["lambdas"])
    res["lambdas_nonzero"] = lam_ok
    if not lam_ok:
        fail("LAM")
    coll = []
    for g in role["groups"]:
        if len(g["members"]) < 2:
            continue
        tail = [tuple(x) for x in g["key"]["tail"]]
        # eq_msb(tail) is Fp-collinear iff every tail coordinate is in Fp (or the tail is empty)
        if all(t[1] == 0 for t in tail):
            coll.append(len(g["members"]))
    res["multi_member_groups"] = sum(1 for g in role["groups"] if len(g["members"]) >= 2)
    res["multi_member_groups_Fp_collinear"] = len(coll)
    return res


def main():
    out = []
    for label, bundle, fname in CAPTURES:
        d = json.load(open(os.path.join(bundle, fname)))
        for role in d["roles"]:
            r = check_role(bundle, role)
            r["capture"] = label
            out.append(r)
            print(f"{label:24s} {r['role']:7s} {r['kind']:18s} rows {r['rows']:5d} claims {r['claims']:3d} pairs {r['pairs']:3d} "
                  f"sites-once {r['sites_each_used_once']!s:5s} prox-wedge!=0 {r['H_prox_wedge_nonzero']!s:5s} sha {r['prox_rhos_sha_ok']!s:5s} "
                  f"lam!=0 {r['lambdas_nonzero']!s:5s} multi {r['multi_member_groups']:2d} Fp-collinear {r['multi_member_groups_Fp_collinear']} "
                  f"failures {r['failures']}")
    summary = {"views": len(out), "views_with_failures": sum(1 for r in out if r["failures"])}
    print(json.dumps(summary))
    json.dump({"summary": summary, "views": out}, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gs4_check.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
