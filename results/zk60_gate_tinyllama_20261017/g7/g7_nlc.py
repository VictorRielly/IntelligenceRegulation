#!/usr/bin/env python3
"""G-7 sub-lane, supplementary to g7_nl.py: the parts of NL-1's ADVERSARIAL
check (results/zk60_nonlinear_channel_shaped_check/nlc_check.py, frozen,
digests checked, no bytecode written there) that NL-1's acceptance rests on,
run at the trained slot-IR export by calling the frozen functions directly:

  K3  the source parse (balanced-parenthesis `define` parse, SLOT_KINDS,
      HOSTS) of the gate-owned R5b copy the trained export was built from;
  K1  the SYMBOLIC monomial expansion of every slot (premise per extension
      round, a public TABLE in every monomial, product degree) — a verdict
      for every coefficient value, not a sample;
  K2  the per-shape counts (sum L, dim C, worst L, budget, terminals);
  K5  the host coupling with the protocol's real kinds, all six hosts.

At m125 the same calls are made and compared with the frozen
nlc_check.json (a fidelity anchor). Nothing here is a privacy result.

    python3 g7_nlc.py --out <dir> --ir <slot_ir_*.json> [--ir ...]
"""

import argparse
import hashlib
import json
import os
import sys

sys.dont_write_bytecode = True
FROZEN = "/home/victor/IntelligenceRegulation/results/zk60_nonlinear_channel_shaped_check"
PINS = {"nlc_check.py": "486ecfbdc0c896e733057f4a92ffa3246341524aa38265fdccc414992731aca6", "nlc_field.py": "3168dcc6981ba7452ada00c0681f6ad88fa838e5654a19e3dbc10b835185cb15"}
G7 = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-g7"


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--ir", action="append", default=[])
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for f, d in PINS.items():
        assert sha(os.path.join(FROZEN, f)) == d, f"{f} moved"
    sys.path.insert(0, FROZEN)
    import nlc_check as C  # noqa: E402

    lane_src = dict(C.SRC)
    out = {"pins": PINS, "inputs": {}, "K3": {}, "K1": {}, "K2": {}, "K5": {}}
    lines = []

    def log(*x):
        s = " ".join(str(v) for v in x)
        lines.append(s)
        print(s, flush=True)

    # K3 under both source sets
    parses = {}
    for name, src in (("lane", lane_src), ("g7", {**lane_src, "argument.rs": G7 + "/hashline/src/private_block/argument.rs", "layout.rs": G7 + "/hashline/src/private_block/layout.rs"})):
        C.SRC = src
        dfn, lay = C.parse_define(), C.parse_layout()
        bil = {}
        for arm, slot in (("SC_SCORE", lay["sc"]["SC_SCORE"]), ("SC_PV", lay["sc"]["SC_PV"])):
            bil[slot] = [p["ext_round"] for p in dfn["pushes"] if p["arm"] == arm]
        parses[name] = {
            "pushes": len(dfn["pushes"]),
            "nonzero": [(p["arm"], p["ext_round"]) for p in dfn["pushes"] if p["ext_round"] != "0"],
            "other_private_push_calls": dfn["other_private_push_calls"],
            "helpers": dfn["helpers"],
            "kinds": lay["kinds"],
            "hosts": lay["hosts"],
            "bilinear": {str(k): v for k, v in bil.items()},
            "argument.rs": src["argument.rs"],
            "argument.rs sha256": sha(src["argument.rs"]),
        }
        if name == "g7":
            g7_bil = bil
    out["K3"] = parses
    same = {k: parses["lane"][k] == parses["g7"][k] for k in ("pushes", "nonzero", "other_private_push_calls", "helpers", "kinds", "hosts", "bilinear")}
    out["K3"]["lane_vs_g7_equal"] = same
    log("K3 g7 (R5b) parse:", {k: parses["g7"][k] for k in ("pushes", "nonzero", "other_private_push_calls", "helpers", "bilinear")}, "; kinds/hosts equal to the lane's:", same)

    def ext_map(sj):
        privs = [t["id"] for t in sj["tables"] if C.kind_of(t) in C.PRIVATE]
        if sj["slot"] in g7_bil:
            rs = [int(x) for x in g7_bil[sj["slot"]]]
            assert len(rs) == len(privs)
            return dict(zip(privs, rs))
        return {i: 0 for i in privs}

    shapes = [("m125", C.IR_DIR + "/slot_ir_m125.json")] + [(json.load(open(p))["shape"], p) for p in a.ir]
    frozen = json.load(open(os.path.join(FROZEN, "nlc_check.json")))
    for key, p in shapes:
        js = json.load(open(p))
        assert js["schema"] == "zk60-slot-ir/1" and len(js["slots"]) == 23
        out["inputs"][key] = {"path": p, "sha256": sha(p)}
        rows = [C.k1_slot(sj, ext_map(sj)) for sj in js["slots"]]
        out["K1"][key] = rows
        L = [C.mask_len(r["main"] + r["ext"], r["d"]) for r in rows]
        Cd = [(r["main"] + r["ext"]) * r["d"] + 1 for r in rows]
        term = {k: sum(r["private_by_commitment"].get(k, 0) for r in rows) for k in ("A", "H", "EP")}
        k2 = {"sum_L": sum(L), "sum_dimC": sum(Cd), "kernel": sum(L) - sum(Cd), "worst_L": max(L), "worst_L_slots": [i for i, x in enumerate(L) if x == max(L)], "budget_ok": all(x + C.MASK_PADS <= C.MASK_MSG for x in L), "terminals": term, "terminals_total": sum(term.values()), "degree5_slots": [r["slot"] for r in rows if r["d"] == 5], "supp_slots": [r["slot"] for r in rows if r["has_supp"]], "group_eq_slots": [r["slot"] for r in rows if r["has_group_eq"]]}
        out["K2"][key] = k2
        log(
            f"K1 [{key}] premise (symbolic, every round) {sum(r['premise_holds_all_rounds'] for r in rows)}/23; public TABLE in every monomial {sum(r['public_table_in_every_monomial'] for r in rows)}/23; "
            f"top-level public factor {sum(r['top_level_public_factor_every_term'] for r in rows)}/23; product degree <= declared {sum(r['degree_fits'] for r in rows)}/23; = export's figure {sum(r['product_degree'] == r['export_max_product_degree'] for r in rows)}/23; "
            f"monomials {sum(r['n_monomials'] for r in rows)}; constant monomial at {[r['slot'] for r in rows if r['constant_monomial_present']]}; supp monomials without an eq table {[(r['slot'], r['supp_monomials_without_eq']) for r in rows if r['supp_monomials_without_eq']]}"
        )
        log(f"K2 [{key}] {k2}")
        if key == "m125":
            fk1 = frozen["stages"]["K1_symbolic"]["m125"]
            out["K1_m125_equal_to_frozen"] = fk1 == json.loads(json.dumps(rows))
            log("K1 m125 rows equal to the frozen nlc_check.json:", out["K1_m125_equal_to_frozen"])
        hosts = []
        for host in sorted(C.HOSTED):
            try:
                r = C.host_coupling(js["slots"], ext_map, host=host, shape=key)
            except Exception as e:  # recorded, not hidden
                r = {"label": f"host {host} at {key}", "error": repr(e), "pass": False}
            hosts.append(r)
            log("K5", r.get("label"), "->", "PASS" if r.get("pass") else "FAIL", {k: v for k, v in r.items() if k not in ("label", "host", "shape")})
        out["K5"][key] = {"pass": sum(bool(r.get("pass")) for r in hosts), "of": len(hosts), "rows": hosts}
        log(f"K5 [{key}] host coupling: {out['K5'][key]['pass']}/{len(hosts)} pass")
        if key == "m125":
            fk5 = [r for r in frozen["stages"]["K5_fibre"] if r.get("shape") == "m125" and "host" in r and not str(r["label"]).startswith("CONTROL") and "inadmissible" not in str(r["label"])]
            out["K5_m125_equal_to_frozen"] = [json.loads(json.dumps(r, default=str)) for r in hosts] == fk5
            log("K5 m125 host rows equal to the frozen nlc_check.json:", out["K5_m125_equal_to_frozen"], f"({len(fk5)} frozen rows)")
    with open(os.path.join(a.out, "g7_nlc.json"), "w") as fh:
        json.dump(out, fh, indent=1, default=str)
    with open(os.path.join(a.out, "g7_nlc.log"), "w") as fh:
        fh.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
