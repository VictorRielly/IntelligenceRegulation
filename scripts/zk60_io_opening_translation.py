#!/usr/bin/env python3
"""Exact, fixed-challenge opening algebra for round-19 IO captures.

Checks the public PCS/M equations and constructs nonzero translations that
preserve their field-valued observations. This is NOT a proof simulator: roots,
Merkle paths, adaptive challenges, CFS round messages and repeated openings are
outside this tool. See ZK60_ROUND20.md for the universal algebra and its limits.
No private witness, pad, mask coefficient or proving seed is read.
"""
import argparse
import copy
import json
from pathlib import Path

import zk60_fable_cfs_channel as C
import zk60_io_capture_preflight as pre

P, ZERO, ONE = C.P, C.ZERO, C.ONE
ROOT = Path(__file__).resolve().parents[1]
SOURCE = "1f0ff3680c4cda88f1744343e24eb93cdddfcba4"
require = pre.require


def fft(values, inverse=False):
    """Natural-order radix-2 transform, base field, generator 7 as in field.rs."""
    n = len(values)
    require(n > 0 and n & (n - 1) == 0, "FFT length")
    a = list(values)
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i < j:
            a[i], a[j] = a[j], a[i]
    size = 2
    while size <= n:
        root = pow(7, (P - 1) // size, P)
        if inverse:
            root = pow(root, P - 2, P)
        for start in range(0, n, size):
            w = 1
            for k in range(start, start + size // 2):
                u, v = a[k], a[k + size // 2] * w % P
                a[k], a[k + size // 2] = (u + v) % P, (u - v) % P
                w = w * root % P
        size *= 2
    if inverse:
        inv = pow(n, P - 2, P)
        a = [x * inv % P for x in a]
    return a


def transform(values, inverse=False):
    return list(zip(fft([x[0] for x in values], inverse),
                    fft([x[1] for x in values], inverse)))


def evaluate(poly, x):
    acc = ZERO
    for c in reversed(poly):
        acc = C.f2_add(C.f2_mul_base(acc, x), c)
    return acc


def mul(a, b):
    width = len(a) + len(b) - 1
    n = 1 << (width - 1).bit_length()
    fa = transform(a + [ZERO] * (n - len(a)))
    fb = transform(b + [ZERO] * (n - len(b)))
    return transform([C.f2_mul(x, y) for x, y in zip(fa, fb)], True)[:width]


def roots_poly(xs):
    poly = [ONE]
    for x in xs:
        out = [ZERO] * (len(poly) + 1)
        for j, c in enumerate(poly):
            out[j] = C.f2_sub(out[j], C.f2_mul_base(c, x))
            out[j + 1] = C.f2_add(out[j + 1], c)
        poly = out
    return poly


def interpolate(xs, ys):
    require(len(xs) == len(ys) and len(set(xs)) == len(xs), "interpolation nodes")
    # Newton's incremental basis; all nodes are in Fp, values may be Fp2.
    out, basis = [ZERO] * len(xs), [ONE]
    for x, y in zip(xs, ys):
        den = evaluate(basis, x)
        require(den[1] == 0 and den[0] != 0, "interpolation denominator")
        scale = C.f2_mul_base(C.f2_sub(y, evaluate(out, x)), pow(den[0], P - 2, P))
        for i, c in enumerate(basis):
            out[i] = C.f2_add(out[i], C.f2_mul(scale, c))
        next_basis = [ZERO] * (len(basis) + 1)
        for i, c in enumerate(basis):
            next_basis[i] = C.f2_sub(next_basis[i], C.f2_mul_base(c, x))
            next_basis[i + 1] = C.f2_add(next_basis[i + 1], c)
        basis = next_basis
    return out


def subgroup(n):
    root = pow(7, (P - 1) // n, P)
    return [pow(root, j, P) for j in range(n)]


def coset_evals(poly, domain):
    require(len(poly) <= domain, "polynomial exceeds domain")
    scaled = [C.f2_mul_base(c, pow(7, j, P)) for j, c in enumerate(poly)]
    return transform(scaled + [ZERO] * (domain - len(scaled)))


def pcs_poly(message, pad):
    n = len(message)
    coeffs = transform(message, True) + [ZERO] * len(pad)
    for j, x in enumerate(pad):
        coeffs[j] = C.f2_sub(coeffs[j], x)
        coeffs[n + j] = C.f2_add(coeffs[n + j], x)
    return coeffs


def pcs_pad(message, indices, domain, budget):
    nodes = subgroup(domain)
    xs = [7 * nodes[j] % P for j in sorted(set(indices))]
    require(len(xs) <= budget, "PCS distinct columns exceed pad budget")
    f = transform(message, True)
    ys = []
    for x in xs:
        z = (pow(x, len(message), P) - 1) % P
        require(z != 0, "PCS sample intersects message subgroup")
        ys.append(C.f2_mul_base(C.f2_neg(evaluate(f, x)), pow(z, P - 2, P)))
    g = interpolate(xs, ys)
    return g + [ZERO] * (budget - len(g))


def mask_lift(prefix, indices, m=512, budget=256, domain=4096):
    """Extend a prescribed CFS coefficient delta using only the pad positions."""
    length = len(prefix)
    require(length + budget <= m, "M coefficient/pad geometry")
    nodes = subgroup(m)
    coset = [7 * x % P for x in subgroup(domain)]
    samples = [coset[j] for j in sorted(set(indices))]
    require(len(samples) <= budget, "M distinct columns exceed pad budget")
    require(not set(samples).intersection(nodes), "M sample intersects message subgroup")
    vanish = roots_poly(nodes[length + budget:] + samples)
    vals = []
    for x, y in zip(nodes, prefix):
        den = evaluate(vanish, x)
        require(den[1] == 0 and den[0] != 0, "M prefix intersects vanishing nodes")
        vals.append(C.f2_mul_base(y, pow(den[0], P - 2, P)))
    out = mul(vanish, interpolate(nodes[:length], vals))
    require(len(out) <= m, "M lift degree")
    return out + [ZERO] * (m - len(out))


def mask_weights(mask):
    lengths = [n * d + 2 for n, d in mask["specs"]]
    offsets = [sum(lengths[:i]) for i in range(len(lengths))]
    fs, weights, v, theta = [], [[ZERO] * 512 for _ in lengths], ZERO, ONE
    for f in mask["functionals"]:
        row = [ZERO] * sum(lengths)
        for term in f["terms"]:
            s = term["slot"]
            for j, w in enumerate(term["weights"]):
                row[offsets[s] + j] = C.f2_add(row[offsets[s] + j], tuple(w))
                weights[s][j] = C.f2_add(weights[s][j], C.f2_mul(theta, tuple(w)))
        fs.append(row)
        v = C.f2_add(v, C.f2_mul(theta, tuple(f["value"])))
        theta = C.f2_mul(theta, tuple(mask["theta"]))
    return lengths, offsets, fs, [transform(w, True) for w in weights], v


def mask_blinders(a, weights, rhos):
    width = 2 * len(a[0])
    require(len(a) == len(weights) and len(rhos) == 2 * len(a) + 2, "M blinder geometry")
    b = [ZERO] * width
    for x, w in zip(a, weights):
        for j, value in enumerate(mul(x, w)):
            b[j] = C.f2_sub(b[j], value)
    rows = []
    for poly in a + [b]:
        for part in (0, 1):
            rows.append([x[part] for x in poly] + [0] * (width - len(poly)))
    u = [ZERO] * width
    for r, rho in zip(rows, rhos):
        u = [C.f2_sub(x, C.f2_mul_base(tuple(rho), y)) for x, y in zip(u, r)]
    return b, u


def check_mask_public(mask, weights, v):
    q, prox = [tuple(x) for x in mask["q"]], [tuple(x) for x in mask["prox"]]
    require(C.f2_mul_base(C.f2_add(q[0], q[512]), 512) == v, "M public sum equation")
    we = [coset_evals(w, 4096) for w in weights]
    qe, pe = coset_evals(q, 4096), coset_evals(prox, 4096)
    for col in mask["columns"]:
        j, values = col["index"], col["values"]
        acc = tuple(values[16:18])
        for s in range(8):
            acc = C.f2_add(acc, C.f2_mul(tuple(values[2*s:2*s+2]), we[s][j]))
        require(acc == qe[j], "M public product/column equation")
        acc = tuple(values[18:20])
        for rho, value in zip(mask["proximity_rhos"], values[:18]):
            acc = C.f2_add(acc, C.f2_mul_base(tuple(rho), value))
        require(acc == pe[j], "M public proximity/column equation")


def analyze_mask(mask):
    lengths, offsets, fs, weights, v = mask_weights(mask)
    check_mask_public(mask, weights, v)
    basis = C.f2_null_space(fs, sum(lengths))
    # Exercise all slots together, both Fp coordinates, deterministically.
    delta = [ZERO] * sum(lengths)
    for i, vector in enumerate(basis):
        scalar = (i + 1, i * i + 3)
        delta = [C.f2_add(a, C.f2_mul(scalar, b)) for a, b in zip(delta, vector)]
    require(any(x != ZERO for x in delta), "empty M translation")
    require(all(C.f2_dot(row, delta) == ZERO for row in fs), "M functional delta")
    indices = [c["index"] for c in mask["columns"]]
    prefixes = [delta[o:o+l] for o, l in zip(offsets, lengths)]
    require(all(any(x != ZERO for x in p) for p in prefixes), "unexercised M slot")
    a = [mask_lift(p, indices) for p in prefixes]
    for poly, prefix in zip(a, prefixes):
        msg = transform(poly)
        require(msg[:len(prefix)] == prefix, "M lifted prefix")
        require(all(x == ZERO for x in msg[len(prefix)+256:]), "M fixed trailing messages")
    b, u = mask_blinders(a, weights, mask["proximity_rhos"])
    require(C.f2_add(b[0], b[512]) == ZERO, "M b zero-sum subspace")
    # Independent evaluation checks of the constructed q/prox deltas.
    ae = [coset_evals(x, 4096) for x in a]
    be, ue = coset_evals(b, 4096), coset_evals(u, 4096)
    we = [coset_evals(w, 4096) for w in weights]
    for j in range(4096):
        qd, pd = be[j], ue[j]
        for s in range(8):
            qd = C.f2_add(qd, C.f2_mul(ae[s][j], we[s][j]))
        base = [v for x in ae + [be] for v in x[j]]
        for rho, value in zip(mask["proximity_rhos"], base):
            pd = C.f2_add(pd, C.f2_mul_base(tuple(rho), value))
        require(qd == pd == ZERO, "M translated full polynomial equation")
    require(all(e[j] == ZERO for e in ae + [be, ue] for j in indices), "M sampled column delta")
    return {"public_equations_checked": True, "slots": 8, "rows": 20,
            "functionals": len(fs), "functional_rank_fp2": sum(lengths) - len(basis),
            "coefficient_kernel_dim_fp2": len(basis), "distinct_columns": len(set(indices)),
            "joint_translation_checked": True, "all_slots_nonzero": True,
            "full_q_prox_and_sampled_columns_unchanged": True}


def pcs_matrices(role):
    rows, n = role["commitment"]["rows"], 256
    claims = []
    for claim in role["claims"]:
        row = [ZERO] * rows
        for part in claim["parts"]:
            require(part["offset"] % n == 0 and part["log_size"] >= 8, "PCS full-row claim")
            count = 1 << (part["log_size"] - 8)
            head = [tuple(x) for x in part["point"][:-8]] if part["point"] else []
            rw = pre.old.eq_table_msb(head) if part["point"] else [ONE] * count
            require(len(rw) == count, "PCS row weights")
            for i, w in enumerate(rw):
                r = part["offset"] // n + i
                row[r] = C.f2_add(row[r], C.f2_mul(tuple(part["coefficient"]), w))
        claims.append(row)
    folds = []
    for group in role["groups"]:
        row = [ZERO] * rows
        for k, lam in zip(group["members"], group["lambdas"]):
            row = [C.f2_add(x, C.f2_mul(tuple(lam), y)) for x, y in zip(row, claims[k])]
        folds.append(row)
    folds.append([tuple(x) for x in role["proximity_rhos"]])
    constraints = claims + folds[-1:]
    for extra in role["public_linear_constraints"]:
        row = [ZERO] * rows
        row[extra["rows"][0]], row[extra["rows"][1]] = ONE, C.U
        constraints.append(row)
    return folds, constraints


def pcs_direction(role, constraints):
    # Mask/proximity columns first; pick a free data coordinate when available.
    kinds = role["row_roles"]
    order = sorted(range(len(kinds)), key=lambda i: (kinds[i]["kind"] == "data", i))
    matrix = [[row[i][part] for i in order] for row in constraints for part in (0, 1)]
    red, pivots = C.R.rref(matrix)
    free = [i for i in range(len(order)) if i not in pivots]
    require(free, "PCS translation kernel empty")
    chosen = next((i for i in free if kinds[order[i]]["kind"] == "data"), free[0])
    x = [0] * len(order)
    x[chosen] = 1
    for row, pivot in zip(red, pivots):
        x[pivot] = -row[chosen] % P
    delta = [0] * len(order)
    for i, value in zip(order, x):
        delta[i] = value
    return delta, order[chosen]


def check_pcs_public(role):
    folds, constraints = pcs_matrices(role)
    vectors = [g["vector"] for g in role["groups"]] + [role["proximity_vector"]]
    for fold, vector in zip(folds, vectors):
        v = [tuple(x) for x in vector]
        enc = coset_evals(pcs_poly(v[:256], v[256:]), 2048)
        for col in role["columns"]:
            acc = ZERO
            for w, x in zip(fold, col["values"]):
                acc = C.f2_add(acc, C.f2_mul_base(w, x))
            require(acc == enc[col["index"]], "PCS public vector/column equation")
    return folds, constraints


def analyze_pcs(role):
    folds, constraints = check_pcs_public(role)
    direction, chosen = pcs_direction(role, constraints)
    for row in folds + constraints:
        acc = ZERO
        for w, d in zip(row, direction):
            acc = C.f2_add(acc, C.f2_mul_base(w, d))
        require(acc == ZERO, "PCS message/terminal/constraint kernel")
    # A nonconstant row polynomial; tensor with the checked row direction.
    message = [((j*j + 3*j + 17) % P, 0) for j in range(256)]
    indices = [c["index"] for c in role["columns"]]
    pad = pcs_pad(message, indices, 2048, role["q_pad"])
    enc = coset_evals(pcs_poly(message, pad), 2048)
    require(all(x[1] == 0 for x in pad), "PCS base-field pad translation")
    require(any(x != ZERO for x in pad), "PCS zero pad translation")
    require(all(enc[j] == ZERO for j in indices), "PCS sampled column delta")
    # Every row uses direction[r] * message and direction[r] * pad: the same
    # checked kernel identity preserves all 512 entries of every full vector.
    return {"role": role["role"], "rows": len(direction), "groups": len(folds)-1,
            "distinct_columns": len(set(indices)), "pad_budget": role["q_pad"],
            "public_equations_checked": True, "translation_free_row": chosen,
            "translation_free_row_kind": role["row_roles"][chosen]["kind"],
            "nonzero_translation_rows": sum(x != 0 for x in direction),
            "full_vectors_terminals_constraints_and_sampled_columns_unchanged": True}


def public_controls(capture):
    """Corrupt numerical observations; geometry alone would accept these."""
    mask = capture["mask"]
    endpoint = next(r for r in capture["roles"] if r["role"] == "Input")
    cases = [("M q coefficient", "mask", ("q", 7, 0)),
             ("M prox coefficient", "mask", ("prox", 7, 1)),
             ("M sampled a word", "mask", ("columns", 0, "values", 0)),
             ("M sampled b word", "mask", ("columns", 0, "values", 16)),
             ("M sampled u word", "mask", ("columns", 0, "values", 18)),
             ("M theta", "mask", ("theta", 0)),
             ("M functional weight", "mask", ("functionals", 0, "terms", 0, "weights", 0, 0)),
             ("PCS group pad", "pcs", ("groups", 0, "vector", 256, 0)),
             ("PCS proximity pad", "pcs", ("proximity_vector", 300, 1)),
             ("PCS sampled word", "pcs", ("columns", 0, "values", 0)),
             ("PCS group lambda", "pcs", ("groups", 0, "lambdas", 0, 0))]
    out = []
    for label, kind, path in cases:
        obj = copy.deepcopy(mask if kind == "mask" else endpoint)
        target = obj
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = (target[path[-1]] + 1) % P
        try:
            if kind == "mask":
                _, _, _, weights, v = mask_weights(obj)
                check_mask_public(obj, weights, v)
            else:
                check_pcs_public(obj)
        except ValueError as err:
            require("equation" in str(err), "control failed outside numerical check")
            out.append({"name": label, "rejected": True, "reason": str(err)})
        else:
            raise ValueError("accepted numerical corruption: " + label)
    return out


def run(directory, manifest_path):
    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
    require(manifest["source_commit"] == SOURCE, "round-19 manifest source")
    for path, digest in manifest["source_sha256"].items():
        require(pre.digest((ROOT / path).read_bytes()) == digest, "reviewed source changed: " + path)
    preflight = pre.run(directory, SOURCE)
    recorded = {c["proof_sha256"]: c for c in manifest["captures"]["cases"]}
    cases, controls = [], {}
    for item in preflight["cases"]:
        record = recorded[item["proof_sha256"]]
        for key in ("capture_sha256", "capture_bytes", "proof_sha256", "proof_bytes", "expected_policy_sha256"):
            require(item[key] == record[key], "round-19 artifact manifest mismatch: " + key)
        c = json.loads(Path(item["path"]).read_bytes())
        cases.append(dict(item, mask=analyze_mask(c["mask"]), pcs=[analyze_pcs(r) for r in c["roles"]]))
        if c["privacy"] not in controls:
            controls[c["privacy"]] = {"proof_sha256": c["proof_sha256"], "cases": public_controls(c)}
    paths = [Path(__file__), Path(C.__file__), Path(C.R.__file__), Path(pre.__file__),
             Path(pre.old.__file__), Path(pre.old.C.__file__), Path(pre.io.__file__), Path(pre.wire.__file__)]
    return {"schema": 1, "source_commit": SOURCE, "manifest_sha256": pre.digest(manifest_bytes),
            "source_sha256": manifest["source_sha256"],
            "status": "passed", "scope": "fixed-challenge field-valued opening translations",
            "full_privacy_review_complete": False, "merkle_or_transcript_simulation_performed": False,
            "cases": cases, "numerical_controls": controls,
            "tools": {str(p.relative_to(ROOT)): pre.digest(p.read_bytes()) for p in paths}}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--captures", type=Path, required=True)
    ap.add_argument("--manifest", type=Path, default=ROOT / "results/zk60_round19_validation.json")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    result = run(args.captures, args.manifest)
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print("PASS: four captures; exact PCS/M opening translations (conditional scope)")


if __name__ == "__main__":
    main()
