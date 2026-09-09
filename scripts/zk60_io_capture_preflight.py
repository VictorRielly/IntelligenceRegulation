#!/usr/bin/env python3
"""Check schema-3 IO capture integrity/geometry, not zero knowledge.

Uses Opus's archived layout arithmetic read-only. It never relabels an old
capture or invokes the old linear analyzer. Rust has replayed the full PCS/M
openings; this tool checks artifact digests, the new schema, claim geometry,
row aliases, transcript joins and public-vector equations. CFS/pads/columns
are captured, but their privacy and joint transcript composition remain open.
"""
import argparse
import hashlib
import json
from pathlib import Path

import zk60_opus_repaired_capture as old
import zk60_opus_io_layout as io
import zk60_opus_wire_length as wire

PROFILE = "ffn-v3-mr1-fresh-io-poc/2"
COVERAGE = "ffn-v3-mr1-fresh-io-poc-function-1"


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def no_duplicates(pairs):
    out = {}
    for key, value in pairs:
        require(key not in out, f"duplicate JSON key {key}")
        out[key] = value
    return out


def no_float(value):
    raise ValueError("floating-point JSON value is forbidden")


def vec(value, size):
    require(isinstance(value, list) and len(value) == size, f"expected {size} Fp2 entries")
    return [old._fp2(x, "coordinate") for x in value]


def state(s):
    old._bytes32(s["state"], "transcript state")
    old._fp2(s["next"], "next challenge")


def columns(cols, rows, log_domain):
    require(len(cols) == 256, "sample count")
    for c in cols:
        old._uint(c["index"], "column index", 0, (1 << log_domain) - 1)
        require(len(c["values"]) == rows, "column width")
        for x in c["values"]:
            old._fp(x, "column word")
        old._bytes32(c["salt"], "salt")
        require(len(c["path"]) == log_domain, "path length")
        for node in c["path"]:
            old._bytes32(node, "path node")


def expected_layouts(privacy):
    zl = old.zk_layout(32, 16, 16, 8, old.SHIFTS)
    result = {role: old.expected_role(role, zl, privacy) for role in (["W"] if privacy == "P3" else []) + ["A", "H"]}
    a = result["A"]
    row_map = io.a_row_map(old.SHIFTS)
    for i, offset in enumerate([row_map["x_slice"]["offset"], row_map["z_slice"]["offset"]]):
        row = row_map["a_io"][i]
        parts = [(offset, 9, "data", ["X[0]", "z16[0]"][i], True, None),
                 (row * 256, 8, "mask", f"a_io[{i}].re", True, None),
                 ((row + 1) * 256, 8, "mask", f"a_io[{i}].im", True, None)]
        a["claims"].append(parts)
        a["coefficient_tags"].append(["1-e_io", "e_io", "e_io*u"])
        a["declared_row_roles"].extend([("mask", f"a_io[{i}].re"), ("mask", f"a_io[{i}].im")])
        a["group_shape"].append(1)
    a["rows"] = row_map["a_rows"]
    for role in ["Input", "Output"]:
        declared = [("data" if r < 2 else "mask" if r < 4 else "prox") for r in range(7)]
        result[role] = {"rows": 7, "claims": [[(0, 9, "data", role, True, None), (512, 8, "mask", role+".mask.re", True, None), (768, 8, "mask", role+".mask.im", True, None)]],
            "coefficient_tags": [["1-e_io", "e_io", "e_io*u"]], "group_shape": [1],
            "declared_row_roles": [(kind, f"{role}.{kind}[{r}]") for r, kind in enumerate(declared)], "prox_rows": [4, 5, 6], "zero_sum_pair": None}
    description = old.describe(zl).splitlines()
    description[1] = f"A rows={a['rows']} masks={old.a_mask_rows(zl) + list(range(zl['a_rows'], a['rows']))} prox pair={zl['a_prox']}..{zl['a_prox'] + 2}"
    return result, "\n".join(description)


def check_role(o, expected):
    name = o["role"]
    require(o["params"] == {"log_cols": 8, "inv_rate": 8, "num_col_checks": 256}, "PCS parameters")
    require(o["commitment"]["rows"] == expected["rows"], "commitment rows")
    old._bytes32(o["commitment"]["root"], "commitment root")
    state(o["before"]); state(o["after"])
    require(o["q_pad"] == 256, "pad budget")
    require(o["row_roles"] == [{"row": r, "kind": kind, "site": site} for r, (kind, site) in enumerate(expected["declared_row_roles"])], "row-role map")
    want_constraints = [{"rows": list(expected["zero_sum_pair"]), "relation": "sum over the n message columns = 0", "source": "zsum sumcheck"}] if name == "H" else []
    require(o["public_linear_constraints"] == want_constraints, "public constraints")
    require(len(o["claims"]) == len(expected["claims"]), "claim count")
    for k, (c, want) in enumerate(zip(o["claims"], expected["claims"])):
        old._fp2(c["value"], "claim value")
        require(len(c["parts"]) == len(want), "claim parts")
        for j, (part, ep) in enumerate(zip(c["parts"], want)):
            require((part["offset"], part["log_size"]) == ep[:2], "claim slice/alias")
            coef = old._fp2(part["coefficient"], "claim coefficient")
            vec(part["point"], ep[1] if ep[4] else 0)
            require(ep[5] is None or coef == ep[5], "fixed coefficient")
            require(part["coefficient_tag"] == expected["coefficient_tags"][k][j], "coefficient tag")
        if len(c["parts"]) == 3:
            ps = c["parts"]
            require(old.f2_mul(tuple(ps[1]["coefficient"]), old.U) == tuple(ps[2]["coefficient"]), "mask pair coefficient")
    require([len(g["members"]) for g in o["groups"]] == expected["group_shape"], "group shape")
    seen = []
    for g in o["groups"]:
        require(g["key"]["offset"] == 0 and g["key"]["len"] == 256, "column key")
        tail = vec(g["key"]["tail"], 8 if g["key"]["tail"] else 0)
        cw = old.eq_table_msb(tail) if tail else [old.ONE] * 256
        lams = vec(g["lambdas"], len(g["members"]))
        values = vec(g["vector"], 512)
        lhs, rhs = old.ZERO, old.ZERO
        for coeff, value in zip(cw, values):
            lhs = old.f2_add(lhs, old.f2_mul(coeff, value))
        for k, lam in zip(g["members"], lams):
            old._uint(k, "claim member", 0, len(o["claims"]) - 1)
            seen.append(k)
            c = o["claims"][k]
            require(all(p["point"][-8:] == g["key"]["tail"] for p in c["parts"]), "claim column tail")
            rhs = old.f2_add(rhs, old.f2_mul(lam, tuple(c["value"])))
        require(lhs == rhs, "group vector/terminal equation")
    require(sorted(seen) == list(range(len(o["claims"]))), "group membership")
    vec(o["proximity_rhos"], expected["rows"])
    vec(o["proximity_vector"], 512)
    columns(o["columns"], expected["rows"], 11)


def check_raw(c, source):
    require(c["schema"] == 3 and c["kind"] == old.KIND and c["profile"] == PROFILE and c["coverage"] == COVERAGE, "IO capture profile/schema")
    require(c["source_commit"] == source and len(source) == 40 and all(x in "0123456789abcdef" for x in source), "source pin")
    require(c["transcript_domain"] == "hashline-zk-mr1/" + PROFILE, "transcript domain")
    require(c["fully_verified"] is True and c["privacy_review_complete"] is False, "capture scope")
    require(c["shape"] == old.SHAPE and c["shifts"] == list(old.SHIFTS), "shape/shifts")
    require((c["field_modulus"], c["extension_nonresidue"]) == (old.P, old.NONRESIDUE), "field")
    require(c["privacy"] in ("P1", "P3") and c["weight_policy"] == "fresh-per-proof" and c["slot"] is None and c["k"] is None, "weight policy")
    require(c["proof_digest_encoding"] == "complete HFFNIO version 2 receipt", "receipt digest encoding")
    expected, description = expected_layouts(c["privacy"])
    require(c["layout_description"] == description and c["layout_digest"] == digest(description.encode()), "IO layout description")
    require([o["role"] for o in c["roles"]] == list(expected), "role order")
    require(c["opening_order"] == ["M", "W", "A", "H", "Input", "Output"], "opening schedule")
    for o in c["roles"]:
        check_role(o, expected[o["role"]])
    policy = c["expected_policy"]
    require(len(policy) == 112 and all(type(x) is int and 0 <= x < 256 for x in policy), "expected policy width")
    policy = bytes(policy)
    require(policy[:8] == b"HFFNEXP1" and digest(policy) == c["expected_policy_sha256"], "expected policy digest")
    roles = {o["role"]: o for o in c["roles"]}
    require(bytes(roles["Input"]["commitment"]["root"]) == policy[48:80] and bytes(roles["Output"]["commitment"]["root"]) == policy[80:112], "endpoint policy roots")
    specs = [list(s) for s in wire.mask_specs(c["privacy"] == "P3")] + [[10, 2], [10, 2]]
    m = c["mask"]
    require(m["specs"] == specs, "M slot schedule")
    old._bytes32(m["root"], "M root")
    old._fp2(m["theta"], "M theta")
    vec(m["proximity_rhos"], 18); vec(m["q"], 1024); vec(m["prox"], 1024)
    columns(m["columns"], 20, 12)
    require(len(m["functionals"]) == 14, "M functional count")
    slots = set()
    for f in m["functionals"]:
        old._fp2(f["value"], "functional value")
        require(bool(f["terms"]), "empty functional")
        for term in f["terms"]:
            slot = old._uint(term["slot"], "slot", 0, 7)
            slots.add(slot)
            nv, degree = specs[slot]
            vec(term["weights"], nv * degree + 2)
    require(slots == set(range(8)), "missing functional slot")
    state(m["before"]); state(m["after"])
    chain = [m] + ([c["public_w"]] if c["privacy"] == "P1" else []) + c["roles"]
    require(c["public_w"] is None if c["privacy"] == "P3" else isinstance(c["public_w"], dict), "public W mode")
    for left, right in zip(chain, chain[1:]):
        state(right["before"]); state(right["after"])
        require(left["after"] == right["before"], "opening transcript join")
    require(len(c["io_arguments"]) == 2, "IO argument count")
    for i, arg in enumerate(c["io_arguments"]):
        require(arg["side"] == i and arg["slot"] == i + 6, "IO slot/side")
        vec(arg["tau"], 9); rho = vec(arg["rho"], 10)
        require(rho[9] != old.ZERO, "IO terminal mask challenge")
        for key in ("c", "gamma", "mask_eval"):
            old._fp2(arg[key], key)
        require(tuple(arg["c"]) != old.ZERO, "IO CFS mask challenge")
        require(len(arg["rounds"]) == 10, "IO round count")
        for r in arg["rounds"]: vec(r, 3)
        vec(arg["terminals"], 2)
        left = roles["A"]["claims"][18 + i]
        right = roles[["Input", "Output"][i]]["claims"][0]
        for claim, terminal in zip((left, right), arg["terminals"]):
            require(claim["value"] == terminal and claim["parts"][0]["point"] == arg["rho"][:9], "IO terminal/point binding")
            require([tuple(p["coefficient"]) for p in claim["parts"]] == [old.f2_sub(old.ONE, rho[9]), rho[9], old.f2_mul(rho[9], old.U)], "IO coefficient binding")
        state(arg["before"]); state(arg["after"])
    require(c["io_arguments"][0]["after"] == c["io_arguments"][1]["before"] and c["io_arguments"][1]["after"] == m["before"], "IO/M transcript join")
    names = ["gu", "d", "zc20", "zc17", "tab", "zs"]
    require([a["name"] for a in c["ffn_arguments"]] == names, "FFN argument order")
    for slot, a, count in zip([0, 1, 2, 3, 5, 4], c["ffn_arguments"], wire.TERMINALS[:4] + (wire.TERMINALS[5], wire.TERMINALS[4])):
        nv, degree = specs[slot]
        require(len(a["rounds"]) == nv, "FFN round count")
        for r in a["rounds"]: vec(r, degree + 1)
        vec(a["terminals"], count)
    vec(c["ffn_matmul_claims"], 2); vec(c["ffn_gammas"], 4)
    return {"privacy": c["privacy"], "roles": {name: {"rows": e["rows"], "claims": len(e["claims"]), "groups": e["group_shape"]} for name, e in expected.items()}, "mask_slots": 8, "mask_rows": 20, "transcript_joins_checked": True}


def run(directory, source):
    cases = []
    counts = {"P1": 0, "P3": 0}
    paths = sorted(directory.glob("*.json"))
    require(len(paths) == 4, "expected two P1 and two P3 captures")
    for path in paths:
        raw = path.read_bytes()
        c = json.loads(raw, object_pairs_hook=no_duplicates, parse_float=no_float, parse_constant=no_float)
        result = check_raw(c, source)
        receipt, policy = path.with_suffix(".receipt").read_bytes(), path.with_suffix(".expected").read_bytes()
        require(digest(receipt) == c["proof_sha256"] == path.stem and len(receipt) == c["proof_bytes"] and receipt[:8] == b"HFFNIO\0\x02", "receipt digest/frame")
        require(len(receipt) == io.io_frame_len(private=c["privacy"] == "P3"), "independent receipt length")
        require(policy == bytes(c["expected_policy"]), "policy artifact")
        counts[c["privacy"]] += 1
        cases.append(dict(result, path=str(path), capture_sha256=digest(raw), capture_bytes=len(raw), proof_sha256=digest(receipt), proof_bytes=len(receipt), expected_policy_sha256=digest(policy)))
    require(counts == {"P1": 2, "P3": 2}, "capture privacy counts")
    return {"schema": 1, "source_commit": source, "status": "passed", "cases": cases, "counts": counts, "privacy_analysis_performed": False, "full_privacy_review_complete": False,
            "tools": {p.name: digest(p.read_bytes()) for p in [Path(__file__), Path(old.__file__), Path(io.__file__), Path(wire.__file__)]}}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--captures", type=Path, required=True)
    ap.add_argument("--source-commit", required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    result = run(args.captures, args.source_commit)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Four IO capture/receipt pairs passed preflight; privacy analysis remains open. {args.output}")


if __name__ == "__main__":
    main()
