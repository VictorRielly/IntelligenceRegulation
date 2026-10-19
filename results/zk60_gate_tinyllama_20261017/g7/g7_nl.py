#!/usr/bin/env python3
"""G-7 sub-lane: NL-1's machine check (nl_check.py, stages S0-S5) with the
TRAINED slot-IR export added, by a thin wrapper that reuses the frozen
script's functions WITHOUT editing it.

    python3 g7_nl.py --out <dir> [--ir <slot_ir_*.json> ...] [--src lane|g7]

What the wrapper changes, and nothing else (all by attribute assignment on
the imported module; the frozen file's bytes are checked against the digest
of record before import, and no bytecode is written next to it):

  * `load_shapes`: the nine lane exports of record PLUS every `--ir` file
    (same schema / slot-count assertions as the original);
  * `SRC`: the Rust sources S2 parses (SLOT_KINDS, HOSTS, the extension-round
    pushes of `define`) — `g7` = the gate-owned R5b copy the trained export
    was built from (default), `lane` = the original lane paths;
  * `SHAPES_OF_RECORD`: the three of record plus the `--ir` shapes, so the
    per-slot terminal-map stage (S4 terminal pairs) runs at them too;
  * `HERE`: nl_check.json / nl_check.log are written into `--out`, never next
    to the frozen script.

After `main()` it writes `g7_nl_probes.json`: the duplicate-lookup structure of
every `--ir` export read off the IR (repeated tables, repeated denominator
nodes, the logup relations that carry them, repeated coordinates of each
slot's terminal map), the trained-vs-twin structural diff, and the S2 source
parse under both source sets. Nothing here is a privacy result.
"""

import argparse
import glob
import hashlib
import json
import os
import sys

sys.dont_write_bytecode = True
FROZEN = "/home/victor/IntelligenceRegulation/results/zk60_nonlinear_channel_shaped"
NL_SHA = "e4db99a251ddde4f432675a53bd7e9149cdeb7c9edd61bbac87f50b87d0727c7"
FIELD_SHA = "ea8ca39263213d88ef92c3f5d18fb8f86ed73471da027bf57348f94087dbb7e4"
G7 = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-g7"
G7_SRC = {
    "layout.rs": G7 + "/hashline/src/private_block/layout.rs",
    "argument.rs": G7 + "/hashline/src/private_block/argument.rs",
    "shape.rs": G7 + "/hashline/src/private_block/shape.rs",
    "zk.rs": G7 + "/hashline/src/zk.rs",
    "sumcheck.rs(zkp-core)": G7 + "/zkp-core/src/sumcheck.rs",
    "slot_ir.rs": G7 + "/hashline/src/private_block/slot_ir.rs",
}


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--ir", action="append", default=[])
    ap.add_argument("--src", choices=("g7", "lane"), default="g7")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    got = {"nl_check.py": sha(os.path.join(FROZEN, "nl_check.py")), "nl_field.py": sha(os.path.join(FROZEN, "nl_field.py"))}
    assert got == {"nl_check.py": NL_SHA, "nl_field.py": FIELD_SHA}, f"the frozen NL-1 scripts moved: {got}"
    sys.path.insert(0, FROZEN)
    import nl_check as NL  # noqa: E402

    lane_src = dict(NL.SRC)
    extra = []
    for p in a.ir:
        js = json.load(open(p))
        assert js["schema"] == "zk60-slot-ir/1", p
        assert js["slot_count"] == 23 and len(js["slots"]) == 23, p
        extra.append((js["shape"], p, js))
    lane_dir = NL.IR_DIR

    def load_shapes():
        shapes = {}
        for p in sorted(glob.glob(lane_dir + "/slot_ir_*.json")):
            js = json.load(open(p))
            assert js["schema"] == "zk60-slot-ir/1", p
            assert js["slot_count"] == 23 and len(js["slots"]) == 23, p
            shapes[js["shape"]] = (p, js)
        for k, p, js in extra:
            assert k not in shapes, f"shape key {k} collides with a lane export"
            shapes[k] = (p, js)
        return shapes

    NL.load_shapes = load_shapes
    if a.src == "g7":
        NL.SRC = dict(G7_SRC)
    NL.SHAPES_OF_RECORD = list(NL.SHAPES_OF_RECORD) + [k for k, _, _ in extra]
    NL.HERE = os.path.abspath(a.out)
    NL.main()

    # ---------------------------------------------------------------- probes
    probes = {"wrapper": {"frozen_nl_check_sha256": NL_SHA, "frozen_nl_field_sha256": FIELD_SHA, "src": a.src, "SRC": NL.SRC, "extra_ir": {k: {"path": p, "sha256": sha(p)} for k, p, _ in extra}}}
    # the S2 source parse under both source sets
    NL.SRC = lane_src
    lane_parse = NL.parse_sources()
    NL.SRC = dict(G7_SRC)
    g7_parse = NL.parse_sources()

    def strip(pz):
        return {
            "kinds": pz["kinds"],
            "hosts": pz["hosts"],
            "ext_assign": {str(k): v for k, v in pz["ext_assign"].items()},
            "nonzero_ext_pushes": [(p["arm"], p["ext_round"]) for p in pz["nonzero_ext_pushes"]],
            "pushes": len(pz["pushes"]),
            "helpers_found": sorted(pz["helpers"]),
        }

    probes["S2_source_parse"] = {"lane": strip(lane_parse), "g7": strip(g7_parse), "equal_except_line_numbers": strip(lane_parse) == strip(g7_parse)}

    def node_sig(sj, n):
        if n["body"] == "affine":
            return ("affine", json.dumps(n["konst"], sort_keys=True), tuple((json.dumps(t["coef"], sort_keys=True), t["table"]) for t in n["terms"]))
        return ("sum", tuple((json.dumps(st["coef"], sort_keys=True), tuple(json.dumps(f, sort_keys=True) for f in st["factors"])) for st in n["subterms"]))

    def dup_structure(js):
        rows = []
        for sj in js["slots"]:
            tabs = sj["tables"]
            by_label = {}
            for t in tabs:
                by_label.setdefault(t["label"], []).append(t["id"])
            dup_tables = {k: v for k, v in by_label.items() if len(v) > 1}
            sigs = {}
            for n in sj["nodes"]:
                sigs.setdefault(node_sig(sj, n), []).append(n["id"])
            dup_nodes = [v for v in sigs.values() if len(v) > 1]
            # the logup relations whose two denominators are the same node signature
            id_of = {n["id"]: n for n in sj["nodes"]}
            sig_of = {n["id"]: node_sig(sj, n) for n in sj["nodes"]}
            rel = []
            for n in sj["nodes"]:
                if n["body"] == "sum" and n["label"].startswith("logup["):
                    dens = [f["node"] for st in n["subterms"] for f in st["factors"] if "node" in f]
                    uniq = sorted(set(dens))
                    if len(uniq) == 2 and sig_of[uniq[0]] == sig_of[uniq[1]]:
                        d = id_of[uniq[0]]
                        rel.append({
                            "relation": n["label"],
                            "dens": [id_of[u]["label"] for u in uniq],
                            "den_terms": [(t["coef"].get("value"), tabs[t["table"]]["label"]) for t in d["terms"]],
                            "helper_tables": [tabs[f["table"]]["label"] for st in n["subterms"] for f in st["factors"] if "table" in f],
                        })
            private = [t for t in tabs if t["kind"] in ("A", "H", "EP")]
            plab = [t["label"] for t in private]
            rows.append({
                "slot": sj["slot"],
                "name": sj["name"],
                "kind": sj["kind"],
                "tables": len(tabs),
                "terminal_coordinates": len(private),
                "terminal_coordinates_repeated": sorted({l for l in plab if plab.count(l) > 1}),
                "tables_with_repeated_label": dup_tables,
                "repeated_node_signatures": [[id_of[i]["label"] for i in v] for v in dup_nodes],
                "logup_relations_with_two_identical_denominators": rel,
            })
        return rows

    shapes = load_shapes()
    probes["duplicate_structure"] = {}
    for k, p, js in extra:
        rows = dup_structure(js)
        probes["duplicate_structure"][k] = {
            "slots_with_identical_denominator_pairs": [r["slot"] for r in rows if r["logup_relations_with_two_identical_denominators"]],
            "slots_with_repeated_terminal_coordinate": [r["slot"] for r in rows if r["terminal_coordinates_repeated"]],
            "slots_with_repeated_table_label": [r["slot"] for r in rows if r["tables_with_repeated_label"]],
            "rows": rows,
        }
    # the same census at the nine lane exports, for the record
    probes["duplicate_structure_lane"] = {}
    for k in sorted(shapes):
        if any(k == e[0] for e in extra):
            continue
        rows = dup_structure(shapes[k][1])
        probes["duplicate_structure_lane"][k] = {
            "slots_with_identical_denominator_pairs": [r["slot"] for r in rows if r["logup_relations_with_two_identical_denominators"]],
            "slots_with_repeated_terminal_coordinate": [r["slot"] for r in rows if r["terminal_coordinates_repeated"]],
        }

    # trained vs twin: structure equal, coefficient values that differ
    keys = [k for k, _, _ in extra]
    if len(keys) >= 2:
        A_, B_ = shapes[keys[0]][1], shapes[keys[1]][1]
        diffs = []
        for sa, sb in zip(A_["slots"], B_["slots"]):
            d = {"slot": sa["slot"]}
            for f in ("kind", "main_rounds", "extension_rounds", "declared_degree", "max_product_degree", "pad_on", "group_bits"):
                if sa[f] != sb[f]:
                    d[f] = (sa[f], sb[f])
            ta = [(t["kind"], t["field"], t["prov"], t["label"]) for t in sa["tables"]]
            tb = [(t["kind"], t["field"], t["prov"], t["label"]) for t in sb["tables"]]
            if ta != tb:
                d["tables"] = {"a": len(ta), "b": len(tb), "first_difference": next((i for i, (x, y) in enumerate(zip(ta, tb)) if x != y), min(len(ta), len(tb)))}

            def coefs(sj):
                out = []
                for n in sj["nodes"]:
                    if n["body"] == "affine":
                        out.append((n["label"], n["konst"]))
                        out.extend((n["label"], t["coef"]) for t in n["terms"])
                    else:
                        out.extend((n["label"], st["coef"]) for st in n["subterms"])
                out.extend(("term:" + t["note"], t["coef"]) for t in sj["terms"])
                return out

            ca, cb = coefs(sa), coefs(sb)
            if len(ca) != len(cb) or any(x[1].get("prov") != y[1].get("prov") for x, y in zip(ca, cb)):
                d["coefficient_structure_differs"] = True
            else:
                vd = sorted({(x[0], x[1]["prov"], x[1].get("value"), y[1].get("value")) for x, y in zip(ca, cb) if x[1].get("value") != y[1].get("value")})
                if vd:
                    d["coefficient_values_differ"] = [list(v) for v in vd]
            if len(d) > 1:
                diffs.append(d)
        probes["trained_vs_twin"] = {"a": keys[0], "b": keys[1], "slots_that_differ": diffs}

    out = os.path.join(a.out, "g7_nl_probes.json")
    with open(out, "w") as fh:
        json.dump(probes, fh, indent=1, default=str)
    print("G7 probes written", out)
    for k in probes["duplicate_structure"]:
        ds = probes["duplicate_structure"][k]
        print(f"G7 [{k}] slots with a logup relation of two identical denominators: {ds['slots_with_identical_denominator_pairs']}; repeated terminal coordinate: {ds['slots_with_repeated_terminal_coordinate']}; repeated table label: {ds['slots_with_repeated_table_label']}")
        for r in ds["rows"]:
            for rel in r["logup_relations_with_two_identical_denominators"]:
                print(f"G7 [{k}]   slot {r['slot']:02d} {rel['relation']}: dens {rel['dens']} = {rel['den_terms']}; helper {rel['helper_tables']}")
    print("G7 S2 source parse equal (lane vs g7, line numbers aside):", probes["S2_source_parse"]["equal_except_line_numbers"])
    if "trained_vs_twin" in probes:
        print("G7 trained vs twin: slots that differ", [(d["slot"], sorted(k for k in d if k != "slot")) for d in probes["trained_vs_twin"]["slots_that_differ"]])


if __name__ == "__main__":
    main()
