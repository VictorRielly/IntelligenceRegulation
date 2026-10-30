#!/usr/bin/env python3
"""[gate round 21, 2026-10-29] The per-run distance figure of ONE Shieldstral-1.0-3B
T128 classifier run (stage IN-C, 26 R13 blocks, stage OUT-C, one input token
endpoint, no output endpoint), counted.  NOT a privacy result.

    python3 classify_run_counts.py <out.json> <classifier capture dir> [<round-9 L22 json>]

Method: D33 section 4 / D36 section 4 (the round-9 script
`round9/token_run_counts.py`, whose figures are in force for D36), applied to
the classifier run's OWN geometry, read from the capture's files:

* a hiding PCS commitment draws (rows - data) * n + rows * Q `fp()` values
  (the mask rows from the mask base, then the PCS pads); READ for the
  classifier stages at token frozen-r17 `stage_in_c.rs:310-316, 347-360` and
  `stage_out_c.rs:562-568, 603-616` (the same pattern as the token stages),
  and for the R13 block stage at `protocol.rs` (the commit path is the
  legacy block's; R13 changes the row counts, not the draw sites);
* an H commitment re-draws its zero-sum pair: 2 (n - 1);
* a masking commitment (`zk::mask_commit_tagged`, unchanged): 2 sum L_s +
  2 N_slots Q + 4 * 1024 with L_s = rounds_s * d_s + 2;
* a boundary (`boundary::prepare`) or the input token endpoint
  (`endpoint_g::prepare`): (rows - data) * n + rows * Q;
* salts: one per encoded column of every commitment (2^log_n * inv_rate;
  the masking commitment 4,096);
* the input-dependent LogUp refusal: the round-19 recount at R13 (2^-108.25:
  2 (sum over blocks of T_d + T + 256) / p^2, T_d = 256 + 256 + 4096 * 4);
* the transcript queries A: NOT measured on this capture (its replay needs
  the 2.25 GB store resident); BOUNDED by 2^20 = 1,048,576, i.e. four times
  the 263,324 challenges gate round 20's replay re-derived on this bundle
  (the TinyLlama L22 run's measured absorbs + squeezes were 1.09 x its
  re-derived challenges' order); the terms that use A are reported at that
  bound and are below 2^-107.

Control K-0: the same residual function, given the round-9 L22 geometry
and its measured transcript counts, must reproduce D36's 2^-70.35.
Control K-1: a boundary of 38 rows / 32 data / 2^14 columns draws 108,032
(the frozen counting script's 125M boundary, control C3).
"""

import json
import math
import os
import sys
from fractions import Fraction

P = (1 << 64) - (1 << 32) + 1          # zkp-core field.rs
P2 = P * P
Q = 256                                # opened columns per commitment
MASK_DOM = 4096                        # wire.rs:18 (masking commitment columns)
MASK_VEC = 1024                        # wire.rs:17
REFUSAL_COUNT = 879_360                # round19/refusal/R19_REFUSAL_RECOUNT.json statement_figure.count
A_BOUND = 1 << 20


def hiding(rows, data, n, q=Q):
    return (rows - data) * n + rows * q


def mask_draws(specs, q=Q):
    sl = sum(r * d + 2 for r, d in specs)
    return 2 * sl + 2 * len(specs) * q + 4 * MASK_VEC, sl


def lg(x):
    return math.log2(x.numerator) - math.log2(x.denominator) if isinstance(x, Fraction) else math.log2(x)


def load(p):
    with open(p) as fh:
        return json.load(fh)


def role(stage, name):
    return next(r for r in stage["roles"] if r["role"] == name)


def geometry(cap):
    run = load(os.path.join(cap, "run.json"))
    cl = run["classify"]
    tier = cl["tier"]
    out = {"stages": [], "boundaries": [], "endpoints": [], "L": run["blocks"], "T": cl["T"]}
    for k in range(run["stages"]):
        s = load(os.path.join(cap, f"stage-{k:02d}.json"))
        kind = s["stage_kind"]
        n = 1 << s["log_cols"]
        inv = tier["stage_inv_rate"] if kind != "BLOCK" else run["shape"]["inv_rate"]
        a_name, h_name = {"IN-C": ("A-in", "H-in"), "BLOCK": ("A", "H"), "OUT-C": ("A-out", "H-out")}[kind]
        a_data, h_data = role(s, a_name)["data_rows"], role(s, h_name)["data_rows"]
        md, sl = mask_draws(s["mask"]["specs"])
        rec = {"stage": k, "kind": kind, "n": n, "inv_rate": inv,
               "A": {"rows": s["a_rows"], "data": a_data, "draws": hiding(s["a_rows"], a_data, n)},
               "H": {"rows": s["h_rows"], "data": h_data, "draws": hiding(s["h_rows"], h_data, n) + 2 * (n - 1)},
               "M": {"slots": len(s["mask"]["specs"]), "sum_L": sl, "draws": md}}
        rec["draws"] = rec["A"]["draws"] + rec["H"]["draws"] + rec["M"]["draws"]
        rec["salts"] = 2 * n * inv + MASK_DOM
        out["stages"].append(rec)
    for b in run["token_boundaries"]:
        f = b["facts"]
        n = 1 << f["log_n"]
        out["boundaries"].append({"name": b["name"], "rows": f["rows"], "data": f["data_rows"], "n": n,
                                  "draws": hiding(f["rows"], f["data_rows"], n, f["checks"]),
                                  "salts": n * f["inv_rate"]})
    e = cl["input_endpoint"]
    n = 1 << e["log_n"]
    out["endpoints"].append({"name": "input_endpoint", "rows": e["rows"], "data": e["data_rows"], "n": n,
                             "draws": hiding(e["rows"], e["data_rows"], n, e["checks"]), "salts": n * e["inv_rate"]})
    if cl.get("output_endpoint") is not None:
        raise ValueError("a classifier run has no output endpoint")
    return out


def residuals(draws, salts, A, refusal, q_log2=128, openings=None):
    q = Fraction(1 << q_log2)
    two256 = Fraction(1, 1 << 256)
    terms = {
        "sampler bias (D9): draws x 2^-96": Fraction(draws, 1 << 96),
        "input-dependent refusal, two-world (D34 / D40, R13 recount)": refusal,
        "salt guessing: q x N_leaf x 2^-256": q * salts * two256,
        "leaf-input collision: C(N_leaf,2) x 2^-256": Fraction(salts * (salts - 1) // 2) * two256,
        "transcript pre-query: q x A x 2^-256": q * A * two256,
        "transcript-input collision: C(A,2) x 2^-256": Fraction(A * (A - 1) // 2) * two256,
        "generator, in-model alternative: 6q x 2^-256 (ASSUMED)": 6 * q * two256,
        "generator-key row: 3 x 4 x 2^-256": Fraction(12) * two256,
        "constructor vs absorb (B10): (A + q) x 2^-256": (A + q) * two256,
    }
    total = sum(terms.values())
    out = {"terms_log2": {kk: round(lg(v), 2) for kk, v in terms.items()},
           "total_distance": str(total), "total_distance_log2": round(lg(total), 4),
           "share_of_sampler_bias": float(terms["sampler bias (D9): draws x 2^-96"] / total),
           "runs_10^6_linear_log2": round(lg(total * 10 ** 6), 2), "runs_10^9_linear_log2": round(lg(total * 10 ** 9), 2)}
    if openings is not None:
        out["liveness_degenerate_challenges_log2 (not a distance)"] = round(lg(Fraction(openings, P)), 2)
    return out


def main(argv):
    out_path, cap = argv[0], argv[1]
    r9 = argv[2] if len(argv) > 2 else None
    g = geometry(cap)
    L, T = g["L"], g["T"]
    draws = sum(s["draws"] for s in g["stages"]) + sum(b["draws"] for b in g["boundaries"]) \
        + sum(e["draws"] for e in g["endpoints"])
    salts = sum(s["salts"] for s in g["stages"]) + sum(b["salts"] for b in g["boundaries"]) \
        + sum(e["salts"] for e in g["endpoints"])
    refusal = Fraction(REFUSAL_COUNT, P2)
    if REFUSAL_COUNT != 2 * (L * (256 + 256 + 4096 * 4) + T + 256):
        raise ValueError("the refusal count is not the round-19 formula at this L and T")
    openings = 3 * L + 6        # per block A, H, incoming boundary; IN-C A, H, E-in; OUT-C A, H, B_out
    res = residuals(draws, salts, A_BOUND, refusal, openings=openings)
    blocks = [s for s in g["stages"] if s["kind"] == "BLOCK"]
    rec = {"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False, "capture": cap,
           "geometry": g,
           "counts": {"draws": draws, "draws_log2": round(math.log2(draws), 3),
                      "of_which": {"IN-C": g["stages"][0]["draws"], "blocks (26)": sum(s["draws"] for s in blocks),
                                   "per block (each)": sorted({s["draws"] for s in blocks}),
                                   "OUT-C": g["stages"][-1]["draws"],
                                   "boundaries (27)": sum(b["draws"] for b in g["boundaries"]),
                                   "input endpoint": g["endpoints"][0]["draws"]},
                      "salts_N_leaf": salts, "transcript_queries_A_bound": A_BOUND,
                      "refusal_count": REFUSAL_COUNT, "openings": openings},
           "residuals": res, "controls": {}}
    rec["controls"]["K-1 boundary 38/32/2^14 draws 108,032"] = hiding(38, 32, 1 << 14) == 108032 \
        and all(b["draws"] == 108032 for b in g["boundaries"])
    rec["controls"]["K-1b every block stage has the same geometry"] = len({s["draws"] for s in blocks}) == 1
    if r9:
        d = load(r9)
        run = d["runs"]["tinyllama-t32-L22-dense-pt1"]
        rr = run["residuals"]
        k0 = residuals(rr["draws"], rr["salts"], rr["transcript_queries_A"],
                       Fraction(2 * (768 * 22 + 32 + 256), P2))
        rec["controls"]["K-0 D36's L22 figure reproduced (2^-70.35)"] = {
            "got": round(k0["total_distance_log2"], 2), "want": -70.35,
            "ok": round(k0["total_distance_log2"], 2) == -70.35}
    with open(out_path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(json.dumps({"draws": draws, "salts": salts, "total_log2": res["total_distance_log2"],
                      "terms": res["terms_log2"], "controls": rec["controls"]}, indent=1))


if __name__ == "__main__":
    main(sys.argv[1:])
