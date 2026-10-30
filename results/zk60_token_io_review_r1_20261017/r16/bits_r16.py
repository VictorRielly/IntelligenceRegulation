#!/usr/bin/env python3
"""Reviewer's independent recompute of the round-16 whole-run figure [COUNTED].

Reads the RV16-S2-SHAPE / RV16-S2-TERMS lines the reviewer's test printed
(r16/logs/rvtk16-tests.log): the shape's PCS parameters and the stage
lookup counts. Recomputes, from first principles and NOT from the lane's
WholeRun numbers:
  * the column term: per opening q * log2(1 - delta/3), delta = 1 - msg/enc,
    hiding openings RS(n + q, n * inv_rate), the mask RS(MASK_VEC, MASK_DOM);
    openings = 2 stages x (A, H, M) + the token endpoint + L x (A, H, M) +
    (L + 1) boundaries;
  * the LogUp term with REVIEW_R13 §6's N per block (the native reviewer's own
    census: 66,879,488 / 154,730,496), T_d = 256 + 256 + 4096 * 4 (G charged at
    the class maximum 4 groups), per block (N + 4 T_d - 1) / p^2; stage OUT-C
    (N + 3 R - 1); stage IN-C n + r (3 + lg) + T lg, lg = ceil(log2 d_pad);
  * the PCS-field and sumcheck bound (2^-113 per opening, 2^-117.2 per stage);
and compares the total, the floor and the lane's printed figures. Also
recomputes N from the printed U8 / S / F counts (a cross-check of the
reviewer's census against the code's domain sizes).
Writes r16/bits_r16.json.
"""
import json, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "logs", "rvtk16-tests.log")
P = 0xFFFF_FFFF_0000_0001
L = 26
REVIEW_R13_N = {"t128": 66_879_488, "t256": 154_730_496}
REVIEW_R13_PER_BLOCK = {"t128": 102.00, "t256": 100.79}
LANE_CLAIM = {"t128": (96.86, 96), "t256": (95.91, 95)}

shapes, terms = {}, []
for line in open(LOG):
    m = re.search(r"RV16-S2-SHAPE (\{.*\})", line)
    if m:
        d = json.loads(m.group(1))
        shapes[d["profile"]] = d
    m = re.search(r"RV16-S2-TERMS (\{.*\})", line)
    if m:
        terms.append(json.loads(m.group(1)))


def col(msg, enc, q):
    delta = 1.0 - msg / enc
    return q * math.log2(1.0 - delta / 3.0)


def hiding(log_n, inv_rate, q):
    n = 1 << log_n
    return col(n + q, n * inv_rate, q)


def clog2(x):
    return (x - 1).bit_length()


out = {"log": LOG, "rows": []}
for t in terms:
    s = shapes[t["profile"]]
    key = "t128" if "t128" in t["profile"] else "t256"
    q = s["opened_cols"]
    stage = hiding(s["tier_stage_log_n"], s["tier_stage_inv_rate"], s["tier_q"])
    ep = hiding(s["tier_ep_log_n"], s["tier_ep_inv_rate"], s["tier_q"])
    mask = col(s["mask_vec"], s["mask_dom"], s["mask_q"])
    blk = hiding(s["log_cols"], s["inv_rate"], q)
    bnd = hiding(s["endpoint_log_n"], s["endpoint_inv_rate"], q)
    cols = [stage, stage, mask] * 2 + [ep] + [blk, blk, mask] * L + [bnd] * (L + 1)
    column = sum(2.0 ** c for c in cols)
    t_d = 256 + 256 + 4096 * 4
    n_review = REVIEW_R13_N[key]
    n_code = s["u8_lookups"] + s["S"] + s["F"]
    per_block_num = n_review + 4 * t_d - 1
    lg = clog2(t["cp_d_pad"])
    num = L * per_block_num + (t["out_c_n"] + 3 * t["out_c_r"] - 1) + (t["in_c_n"] + t["in_c_r"] * (3 + lg) + t["cp_tokens"] * lg)
    logup = num / (P * P)
    omitted = len(cols) * 2.0 ** -113.0 + (L + 2) * 2.0 ** -117.2
    total = column + logup + omitted
    bits = -math.log2(total)
    row = {
        "profile": t["profile"], "policy": t["policy"], "openings": len(cols),
        "per_opening": {"stage": round(stage, 4), "token_endpoint": round(ep, 4), "mask": round(mask, 4), "block": round(blk, 4), "boundary": round(bnd, 4)},
        "N_review_r13": n_review, "N_from_code_counts": n_code, "N_equal": n_review == n_code,
        "code_r13_numerator": s["r13_numerator"], "numerator_equal": s["r13_numerator"] == per_block_num,
        "per_block_bits": round(2 * math.log2(P) - math.log2(per_block_num), 3),
        "stage_terms_log2": {"out_c": round(math.log2(t["out_c_n"] + 3 * t["out_c_r"] - 1) - 2 * math.log2(P), 2), "in_c": round(math.log2(t["in_c_n"] + t["in_c_r"] * (3 + lg) + t["cp_tokens"] * lg) - 2 * math.log2(P), 2)},
        "column_log2": round(math.log2(column), 4), "logup_log2": round(math.log2(logup), 4), "omitted_log2": round(math.log2(omitted), 4),
        "whole_run_bits": round(bits, 4), "floor": math.floor(bits),
        "lane_printed": {"column": t["column_log2"], "logup": t["logup_log2"], "omitted": t["omitted_log2"], "total": t["total_log2"], "floor": t["floor"]},
        "agrees_with_code": abs(bits + t["total_log2"]) < 1e-3 and math.floor(bits) == t["floor"],
        "lane_claim": LANE_CLAIM[key], "agrees_with_claim": abs(bits - LANE_CLAIM[key][0]) < 0.01 and math.floor(bits) == LANE_CLAIM[key][1],
        "passes_min_bits_95": math.floor(bits) >= 95, "margin_over_95": round(bits - 95, 3),
    }
    out["rows"].append(row)
    print(f"{key} {t['policy']}: column 2^-{-row['column_log2']:.2f}, LogUp 2^-{-row['logup_log2']:.2f} (per block 2^-{row['per_block_bits']:.2f}; N review {n_review} = code {n_code}: {row['N_equal']}), "
          f"PCS+sumcheck 2^-{-row['omitted_log2']:.2f}, whole run 2^-{bits:.2f} -> floor {math.floor(bits)}; code {t['total_log2']:.2f}/{t['floor']} agree {row['agrees_with_code']}; lane claim {LANE_CLAIM[key]} agree {row['agrees_with_claim']}")
json.dump(out, open(os.path.join(HERE, "bits_r16.json"), "w"), indent=1)
