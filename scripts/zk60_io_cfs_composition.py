#!/usr/bin/env python3
"""Conditional IO sumcheck masking checks on the round-19 public captures.

This checks the two CFS round-message fibres and their exact M functionals.
It is not an adaptive transcript simulator or a proof of endpoint privacy.
"""
import argparse
import copy
import json
from pathlib import Path

import zk60_io_opening_translation as opening

C, pre = opening.C, opening.pre
ZERO, ONE, ROOT = C.ZERO, C.ONE, opening.ROOT
require = pre.require


def chain_matrix(rho, degree=2):
    """Homogeneous equations on rounds for fixed claimed sum and final value."""
    n, width = len(rho), len(rho) * (degree + 1)
    matrix = []
    for j in range(n):
        row = [ZERO] * width
        row[j*(degree+1)] = row[j*(degree+1)+1] = ONE
        if j:
            for x, w in enumerate(C.lagrange_weights(degree, rho[j-1])):
                row[(j-1)*(degree+1)+x] = C.f2_neg(w)
        matrix.append(row)
    matrix.append([ZERO] * ((n-1)*(degree+1)) + C.lagrange_weights(degree, rho[-1]))
    return matrix


def fibre_model(rho, c, degree=2):
    n, length = len(rho), C.cfs_len(len(rho), degree)
    # The coefficient fibre fixes the mask total and final evaluation.
    functionals = [C.cfs_sum_weights(n, degree), C.cfs_eval_weights(rho, degree)]
    kernel = C.f2_null_space(functionals, length)
    round_map = [[C.f2_mul(c, w) for w in row]
                 for j in range(n) for row in C.cfs_round_weights(n, degree, j, rho[:j])]
    image = [[C.f2_dot(row, vector) for row in round_map] for vector in kernel]
    equations = chain_matrix(rho, degree)
    inside = all(C.f2_dot(row, vector) == ZERO for row in equations for vector in image)
    rank = C.f2_rank(image)
    dimension = n*(degree+1) - C.f2_rank(equations)
    return {"functionals_rank_fp2": length-len(kernel), "coefficient_fibre_dim_fp2": len(kernel),
            "round_fibre_dim_fp2": dimension, "mask_image_rank_fp2": rank,
            "image_inside_round_fibre": inside, "surjective": inside and rank == dimension}, image


def replay(arg):
    rho = [tuple(x) for x in arg["rho"]]
    c, gamma, mask_eval = (tuple(arg[k]) for k in ("c", "gamma", "mask_eval"))
    require(c != ZERO and rho[-1] != ZERO, "IO refused mask challenge")
    current = gamma
    for j, values in enumerate(arg["rounds"]):
        values = [tuple(x) for x in values]
        require(C.f2_add(values[0], values[1]) == current, "IO round chain equation")
        current = C.interp_eval(values, rho[j])
    eq = ONE
    for tau, r in zip(arg["tau"], rho[:-1]):
        tau = tuple(tau)
        eq = C.f2_mul(eq, C.f2_add(C.f2_mul(tau, r), C.f2_mul(C.f2_sub(ONE, tau), C.f2_sub(ONE, r))))
    eq = C.f2_mul(C.f2_sub(ONE, rho[-1]), eq)
    difference = C.f2_sub(tuple(arg["terminals"][0]), tuple(arg["terminals"][1]))
    want = C.f2_add(C.f2_mul(eq, difference), C.f2_mul(c, mask_eval))
    require(current == want, "IO masked terminal equation")
    return current


def check_slot(arg, mask):
    final = replay(arg)
    rho, c = [tuple(x) for x in arg["rho"]], tuple(arg["c"])
    side, slot = arg["side"], arg["slot"]
    require(slot == side+6 and mask["specs"][slot] == [10, 2], "IO CFS slot geometry")
    expected = [[C.f2_mul(c, w) for w in C.cfs_sum_weights(10, 2)], C.cfs_eval_weights(rho, 2)]
    for i, (weights, key) in enumerate(zip(expected, ("gamma", "mask_eval"))):
        functional = mask["functionals"][10+2*side+i]
        require(functional == {"terms": [{"slot": slot, "weights": [list(w) for w in weights]}], "value": arg[key]}, "IO/M functional binding")
    result, image = fibre_model(rho, c)
    require(result["functionals_rank_fp2"] == 2 and result["round_fibre_dim_fp2"] == 19 and result["surjective"], "IO conditional mask cover")
    # Translate a real round transcript by a nonzero element of the conditional
    # image. All challenges, terminals, gamma and M functionals stay fixed.
    delta = [ZERO] * 30
    for i, vector in enumerate(image):
        delta = [C.f2_add(a, C.f2_mul((i+1, i*i+5), b)) for a, b in zip(delta, vector)]
    require(any(x != ZERO for x in delta), "empty IO round translation")
    changed = copy.deepcopy(arg)
    changed["rounds"] = [[list(C.f2_add(tuple(arg["rounds"][j][x]), delta[3*j+x])) for x in range(3)] for j in range(10)]
    require(replay(changed) == final, "translated IO final value")
    return dict(result, side=side, slot=slot, public_chain_verified=True,
                exact_m_functionals_verified=True, nonzero_round_translation_verified=True)


def controls(arg, mask):
    paths = [("gamma", 0), ("rounds", 3, 2, 0), ("mask_eval", 0),
             ("terminals", 0, 0), ("tau", 0, 0), ("rho", 2, 1)]
    out = []
    for path in paths:
        obj = copy.deepcopy(arg)
        part = obj
        for key in path[:-1]:
            part = part[key]
        part[path[-1]] = (part[path[-1]]+1) % C.P
        try:
            replay(obj)
        except ValueError as err:
            out.append({"path": list(path), "rejected": True, "reason": str(err)})
        else:
            raise ValueError("accepted corrupted IO equation: " + str(path))
    for kind in ("weight", "value", "slot"):
        changed = copy.deepcopy(mask)
        f = changed["functionals"][10+2*arg["side"]]
        if kind == "weight":
            f["terms"][0]["weights"][0][0] = (f["terms"][0]["weights"][0][0]+1) % C.P
        elif kind == "value":
            f["value"][0] = (f["value"][0]+1) % C.P
        else:
            f["terms"][0]["slot"] = 0
        try:
            check_slot(arg, changed)
        except ValueError as err:
            require(str(err) == "IO/M functional binding", "wrong functional control boundary")
            out.append({"M corruption": kind, "rejected": True, "reason": str(err)})
        else:
            raise ValueError("accepted corrupted M functional: " + kind)
    return out


def run(directory):
    # Bind to the accepted opening result, its validation and every dependency.
    previous_path = ROOT / "results/zk60_round20_opening_translation.json"
    validation = json.loads((ROOT / "results/zk60_round20_validation.json").read_bytes())
    require(pre.digest(previous_path.read_bytes()) == validation["analysis_sha256"], "round-20 result digest")
    previous = json.loads(previous_path.read_bytes())
    for path, digest in {**previous["tools"], **previous["source_sha256"]}.items():
        require(pre.digest((ROOT/path).read_bytes()) == digest, "round-20 dependency changed: " + path)
    require(previous["manifest_sha256"] == pre.digest((ROOT/"results/zk60_round19_validation.json").read_bytes()), "round-19 manifest digest")
    checked = pre.run(directory, opening.SOURCE)
    recorded = {c["proof_sha256"]: c for c in previous["cases"]}
    cases = []
    for item in checked["cases"]:
        old = recorded[item["proof_sha256"]]
        for key in ("capture_sha256", "proof_sha256", "expected_policy_sha256"):
            require(item[key] == old[key], "round-20 capture digest")
        capture = json.loads(Path(item["path"]).read_bytes())
        slots = [check_slot(arg, capture["mask"]) for arg in capture["io_arguments"]]
        # No IO coefficient occurs in a base-FFN functional; the two IO pairs
        # have disjoint slot support, so the conditional map is block diagonal.
        require(all(t["slot"] < 6 for f in capture["mask"]["functionals"][:10] for t in f["terms"]), "FFN functional aliases IO slot")
        cases.append(dict(item, io_slots=slots, joint_round_fibre_dim_fp2=sum(s["round_fibre_dim_fp2"] for s in slots),
                          independent_slot_support_verified=True,
                          controls=[controls(arg, capture["mask"]) for arg in capture["io_arguments"]]))
    return {"schema": 1, "status": "passed", "source_commit": opening.SOURCE,
            "scope": "IO CFS round-message fibres at fixed challenges, gamma and masked terminals",
            "full_privacy_review_complete": False, "adaptive_transcript_simulation_performed": False,
            "round20_result_sha256": validation["analysis_sha256"], "cases": cases,
            "tools": dict(previous["tools"], **{str(Path(__file__).relative_to(ROOT)): pre.digest(Path(__file__).read_bytes())})}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--captures", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    result = run(args.captures)
    args.out.write_text(json.dumps(result, indent=2)+"\n")
    print("PASS: eight IO CFS fibres; 72 real-capture corruption controls; conditional scope")


if __name__ == "__main__":
    main()
