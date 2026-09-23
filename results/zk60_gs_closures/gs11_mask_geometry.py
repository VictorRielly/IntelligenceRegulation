"""GS-11: is the masking commitment M's geometry the same at every shape?

READ-ONLY.  Three sources, each independent of the others:

 (1) the CODE at lane tip `2ea7221` (`/home/victor/wt-zk60-block125m`):
     the toy `SLOTS` literal (hashline/src/private_block/layout.rs:850-874),
     the constants MASK_LOG_MSG / MASK_LOG_DOM / MASK_Q (hashline/src/zk.rs:
     373-375), N_SLOTS / N_FUNCTIONALS / M_ROWS (layout.rs:798, 930-931),
     read as text, never built;
 (2) the CAPTURES' declared shapes and M openings: the rung-G standalone
     block bundle (lane repo, results/zk60_block_captures_20260923/rung-g/),
     the two 125M two-block runs and the two 125M standalone blocks
     (/home/victor/zk60-artifacts/, outside every repository) -- JSON only,
     the array store is never opened (a reference's declared `len` is read);
 (3) the joint-view gate's M arm at the shaped layouts (round 8 at rung-G,
     rounds 9 / 9j at 125M), whose preimage construction IS M-q and M-prox
     made concrete: `b` recovered from q and admissible (b[m] = -b[0]), `u`
     recovered from prox with coefficient 1, every opened column reproduced.

It prints, per shape: the 23 (rounds, degree) specs, L_s = rounds*degree + 2
(zkp-core/src/sumcheck.rs:197-199), sum L_s, max L_s, the budget check
L_s + MASK_Q <= 2^MASK_LOG_MSG (zk.rs:442 / :493), and the M geometry the
capture declares (rows, q / prox lengths, proximity rhos, opened columns and
their height, functional count).  Nothing here is a privacy property.
"""

from __future__ import annotations

import json
import os
import re
import sys

LANE = "/home/victor/wt-zk60-block125m"
ART = "/home/victor/zk60-artifacts"
JV = "/home/victor/wt-zk60-jointview/results"


def code_constants():
    lay = open(os.path.join(LANE, "hashline/src/private_block/layout.rs")).read()
    zk = open(os.path.join(LANE, "hashline/src/zk.rs")).read()
    sc = open(os.path.join(LANE, "zkp-core/src/sumcheck.rs")).read()
    m = re.search(r"pub\(crate\) const SLOTS: \[\(usize, usize, usize\); N_SLOTS\] = \[(.*?)\];", lay, re.S)
    toy = [tuple(int(x) for x in t) for t in re.findall(r"\((\d+), (\d+), (\d+)\)", m.group(1))]
    consts = {
        "N_SLOTS": int(re.search(r"pub\(crate\) const N_SLOTS: usize = (\d+);", lay).group(1)),
        "N_FUNCTIONALS": int(re.search(r"pub\(crate\) const N_FUNCTIONALS: usize = (\d+);", lay).group(1)),
        "M_ROWS_rule": re.search(r"pub\(crate\) const M_ROWS: usize = ([^;]+);", lay).group(1),
        "MASK_LOG_MSG": int(re.search(r"pub const MASK_LOG_MSG: u32 = (\d+);", zk).group(1)),
        "MASK_LOG_DOM": int(re.search(r"pub const MASK_LOG_DOM: u32 = (\d+);", zk).group(1)),
        "MASK_Q": int(re.search(r"pub const MASK_Q: usize = (\d+);", zk).group(1)),
        "CfsMask_len_rule": re.search(r"pub fn len\(n_vars: usize, degree: usize\) -> usize \{\s*([^}]+?)\s*\}", sc).group(1),
        # the b and u rows (zk.rs:452-457 and the tagged twin :503-508)
        "b_rows_pinned": "b_re[m] = b_re[0].neg();" in zk and "b_im[m] = b_im[0].neg();" in zk,
        "u_rows_fresh_2m": "let u_re = rng.fp_vec(2 * m);" in zk and "let u_im = rng.fp_vec(2 * m);" in zk,
        "prox_starts_from_u_coefficient_1": "let mut prox: Vec<Fp2> = (0..2 * m).map(|i| Fp2::new(mc.u.0[i], mc.u.1[i])).collect();" in zk,
        "prox_rows_2S_plus_2": "let n_rows = 2 * mc.masks.len() + 2;" in zk,
        "n_base_2S_plus_4": zk.count("let n_base = 2 * masks.len() + 4;") == 2,
        "budget_assert_count": zk.count("assert!(part.len() + MASK_Q <= m"),
    }
    return toy, consts


def lens(slots):
    return [(n + e) * d + 2 for (n, e, d) in slots]


def shape_row(name, slots, consts, declared=None):
    L = lens(slots)
    m = 1 << consts["MASK_LOG_MSG"]
    row = {
        "shape": name,
        "slots": len(slots),
        "specs_rounds_degree": [(n + e, d) for (n, e, d) in slots],
        "L_s": L,
        "sum_L": sum(L),
        "max_L": max(L),
        "max_L_slot": L.index(max(L)),
        "budget_headroom": m - consts["MASK_Q"] - max(L),
        "every_L_within_budget": all(x + consts["MASK_Q"] <= m for x in L),
        "coefficient_unknowns_fp": 2 * sum(L),
        "M_rows_by_rule": 2 * len(slots) + 4,
    }
    if declared:
        row["declared"] = declared
    return row


def declared_m(obs_mask):
    def ln(v):
        return v["len"] if isinstance(v, dict) else len(v)

    cols = obs_mask["columns"]
    return {
        "rows": obs_mask["rows"],
        "specs": obs_mask["specs"],
        "q_len": ln(obs_mask["q"]),
        "prox_len": ln(obs_mask["prox"]),
        "proximity_rhos": len(obs_mask["proximity_rhos"]),
        "opened_columns": len(cols),
        "column_heights": sorted({len(c["values"]) for c in cols}),
        "functionals": len(obs_mask["functionals"]),
    }


def gate_m_arm(path):
    rec = json.load(open(os.path.join(JV, path)))
    s = rec.get("stage12_mask_and_cfs")
    if not s:
        return None
    out = []
    for ps in s["per_stage"]:
        v = ps["preimage"]["verification"]
        out.append(
            {
                "stage": ps["stage"],
                "rows": ps["shape"]["rows"],
                "q_len": ps["shape"]["q_len"],
                "prox_len": ps["shape"]["prox_len"],
                "proximity_rhos": ps["shape"]["proximity_rhos"],
                "pads_per_a_row": ps["shape"]["pads_per_a_row"],
                "coefficients_plus_pads_fit": ps["shape"]["coefficients_plus_pads_fit"],
                "b_admissible": v["b_admissible"],
                "q_sum_identity_holds": v["q_sum_identity_holds"],
                "q_mismatches": v["q_mismatches"],
                "prox_mismatches": v["prox_mismatches"],
                "column_entries": v["column_entries"],
                "column_mismatches": v["column_mismatches"],
                "disclosed": ps.get("disclosed"),
            }
        )
    return {"record": path, "mask_lengths": s.get("mask_lengths"), "per_stage": out}


def main():
    toy, consts = code_constants()
    rows = [shape_row("toy (layout.rs SLOTS)", toy, consts)]
    # rung-G: the standalone block bundle in the lane repo
    rg = os.path.join(LANE, "results/zk60_block_captures_20260923/rung-g/rung-g-dense")
    blk = json.load(open(os.path.join(rg, "block.json")))
    obs = json.load(open(os.path.join(rg, "observations.json")))
    rows.append(shape_row("rung-G (block bundle)", [tuple(s) for s in blk["shape"]["slots"]], consts, declared_m(obs["mask"])))
    # 125M: the two-block run (both stages) and the standalone block
    run = json.load(open(os.path.join(ART, "m125-capture-dense-l2/run.json")))
    st = [json.load(open(os.path.join(ART, "m125-capture-dense-l2", f))) for f in run["stage_files"]]
    rows.append(shape_row("125M (two-block run, stage 0)", [tuple(s) for s in run["shape"]["slots"]], consts, declared_m(st[0]["mask"])))
    rows.append(shape_row("125M (two-block run, stage 1)", [tuple(s) for s in run["shape"]["slots"]], consts, declared_m(st[1]["mask"])))
    b125 = os.path.join(ART, "block-captures-20260923/m125-dense")
    blk = json.load(open(os.path.join(b125, "block.json")))
    obs = json.load(open(os.path.join(b125, "observations.json")))
    rows.append(shape_row("125M (standalone block)", [tuple(s) for s in blk["shape"]["slots"]], consts, declared_m(obs["mask"])))
    # every declared M geometry against the shape-free constants
    m = 1 << consts["MASK_LOG_MSG"]
    for r in rows:
        d = r.get("declared")
        if not d:
            continue
        r["declared_equals_the_constants"] = (
            d["rows"] == 2 * consts["N_SLOTS"] + 4
            and d["q_len"] == 2 * m
            and d["prox_len"] == 2 * m
            and d["proximity_rhos"] == 2 * consts["N_SLOTS"] + 2
            and d["opened_columns"] == consts["MASK_Q"]
            and d["column_heights"] == [2 * consts["N_SLOTS"] + 4]
            and d["functionals"] == consts["N_FUNCTIONALS"]
            and [tuple(x) for x in d["specs"]] == [tuple(x) for x in r["specs_rounds_degree"]]
        )
    arms = [a for a in (
        gate_m_arm("zk60_native_run_gate_mask/run-g-dense-s20.json"),
        gate_m_arm("zk60_native_run_gate_block/block-rung-g-dense.json"),
        gate_m_arm("zk60_native_run_gate_m125/m125-dense-full.json"),
        gate_m_arm("zk60_native_run_gate_m125/m125-zero-full.json"),
        gate_m_arm("zk60_native_run_gate_block/block-m125-dense-everything.json"),
        gate_m_arm("zk60_native_run_gate_block/block-m125-zero-arms.json"),
    ) if a]
    out = {"code_constants": consts, "shapes": rows, "gate_m_arm": arms}
    json.dump(out, sys.stdout, indent=1, default=list)
    print()
    print("# constants", json.dumps(consts), file=sys.stderr)
    for r in rows:
        print(f"{r['shape']:34s} slots {r['slots']} sum_L {r['sum_L']:5d} max_L {r['max_L']:3d} (slot {r['max_L_slot']}) "
              f"headroom {r['budget_headroom']:3d} within_budget {r['every_L_within_budget']} M_rows {r['M_rows_by_rule']} "
              f"declared==constants {r.get('declared_equals_the_constants')}", file=sys.stderr)
    for a in arms:
        for p in a["per_stage"]:
            print(f"  gate M arm {a['record']:55s} stage {p['stage']} b_admissible {p['b_admissible']} q_sum {p['q_sum_identity_holds']} "
                  f"q/prox/col mismatches {p['q_mismatches']}/{p['prox_mismatches']}/{p['column_mismatches']} of {p['column_entries']} cols",
                  file=sys.stderr)


if __name__ == "__main__":
    main()
