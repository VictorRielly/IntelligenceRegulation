"""GS-5: the gate's recorded figures against `disclosed = n*k0 + u_dim`.

READ-ONLY over the joint-view lane's committed records
(`/home/victor/wt-zk60-jointview`, tip `adcd831`).  For every per-commitment
view at rung-G (row width n = 2^10) and at 125M (n = 2^14), with Q = q_pad =
256 at both, it re-derives from the recorded leaves:

  k0_recomputed = rank_P1 - rank_P1_on_non_data_rows          (the definition)
  u_dim         = u_row_term.extra_dimension_beyond_k0 (0 when absent)
  predicted     = n * k0_recomputed + u_dim
  exact_u_solve = u_row_indicators_admissible == len(u_rows)

and compares `predicted` with `disclosed_dimension`, checks `k0` against its
definition, and records that Q != n.  It also reads the whole-block joint
figures of round 9k's control C3c, the only recorded place at a shaped layout
where k0 > 0: the pair and the whole block at rung-G and at 125M.

This is a CONSISTENCY check of the recorded arithmetic, not an independent
computation of any rank: the independent computation is the brute force in
gs5_reduction_miniature.py.  Nothing here is a privacy property.
"""

from __future__ import annotations

import json
import os
import sys

JV = "/home/victor/wt-zk60-jointview/results"
RECORDS = [
    ("rung-G", 1 << 10, "zk60_native_run_gate/run-a-tame.json"),
    ("rung-G", 1 << 10, "zk60_native_run_gate/run-b-zero.json"),
    ("rung-G", 1 << 10, "zk60_native_run_gate_s20/run-g-dense-s20.json"),
    ("rung-G", 1 << 10, "zk60_native_run_gate_block/block-rung-g-dense.json"),
    ("rung-G", 1 << 10, "zk60_native_run_gate_block/block-rung-g-zero.json"),
    ("125M", 1 << 14, "zk60_native_run_gate_m125/m125-dense.json"),
    ("125M", 1 << 14, "zk60_native_run_gate_m125/m125-zero.json"),
    ("125M", 1 << 14, "zk60_native_run_gate_m125/m125-dense-everything.json"),
    ("125M", 1 << 14, "zk60_native_run_gate_block/block-m125-dense.json"),
    ("125M", 1 << 14, "zk60_native_run_gate_block/block-m125-zero.json"),
    ("125M", 1 << 14, "zk60_native_run_gate_block/block-m125-dense-everything.json"),
    ("125M", 1 << 14, "zk60_native_run_gate_9k/block-m125-dense-c3c.json"),
    ("125M", 1 << 14, "zk60_native_run_gate_9k/block-m125-zero-c3c.json"),
]
C3C = [
    ("rung-G", 1 << 10, "zk60_native_run_gate_block/block-rung-g-dense.json"),
    ("rung-G", 1 << 10, "zk60_native_run_gate_block/block-rung-g-zero.json"),
    ("125M", 1 << 14, "zk60_native_run_gate_9k/block-m125-dense-c3c.json"),
    ("125M", 1 << 14, "zk60_native_run_gate_9k/block-m125-zero-c3c.json"),
]


def main():
    rows = []
    for shape, n, rel in RECORDS:
        rec = json.load(open(os.path.join(JV, rel)))
        # the record's own shape figure, where it carries one
        pred = rec.get("prediction") or {}
        n_rec = pred.get("cols")
        for pc in rec["stage3_per_commitment"]["per_commitment"]:
            k0 = pc["rank_P1"] - pc["rank_P1_on_non_data_rows"]
            ut = pc.get("u_row_term") or {}
            u_dim = ut.get("extra_dimension_beyond_k0", 0)
            rows.append(
                {
                    "shape": shape,
                    "record": rel,
                    "role": pc["role"],
                    "n": n,
                    "n_in_record": n_rec,
                    "Q": pc["q_pad"],
                    "n_ne_Q": n != pc["q_pad"],
                    "rank_P1": pc["rank_P1"],
                    "rank_P1_on_non_data_rows": pc["rank_P1_on_non_data_rows"],
                    "k0_recorded": pc["k0"],
                    "k0_recomputed": k0,
                    "u_dim": u_dim,
                    "u_rows": len(pc.get("u_rows") or []),
                    "u_admissible": ut.get("u_row_indicators_admissible"),
                    "exact_u_solve": (not pc.get("u_rows")) or ut.get("u_row_indicators_admissible") == len(pc["u_rows"]),
                    "equals_public_logup_identity": ut.get("equals_public_logup_identity"),
                    "disclosed_recorded": pc["disclosed_dimension"],
                    "predicted": n * k0 + u_dim,
                    "agree": pc["disclosed_dimension"] == n * k0 + u_dim and pc["k0"] == k0,
                }
            )
    c3c = []
    for shape, n, rel in C3C:
        rec = json.load(open(os.path.join(JV, rel)))
        s6 = rec["stage6_negative_controls"]
        fam = s6["run_controls"] if "run_controls" in s6 else s6  # the staged driver nests it
        ctl = fam["C3c_a_blinding_row_shared_between_the_two_external_endpoints"]
        for system in ("pair", "whole_block"):
            for side in ("honest", "perturbed"):
                f = ctl[system][side]
                k0 = f["rank_all"] - f["rank_on_non_data"]
                u = 2 if system == "whole_block" else 0  # H@0's u-row term is inside the whole block only
                c3c.append(
                    {
                        "shape": shape,
                        "record": rel,
                        "system": system,
                        "side": side,
                        "n": n,
                        "k0": k0,
                        "u_dim_assumed": u,
                        "joint_recorded": f["joint_fp"],
                        "predicted": n * k0 + u,
                        "agree": f["joint_fp"] == n * k0 + u,
                    }
                )
    out = {
        "per_commitment": rows,
        "c3c_joint": c3c,
        "summary": {
            "views": len(rows),
            "all_agree": all(r["agree"] for r in rows),
            "all_n_ne_Q": all(r["n_ne_Q"] for r in rows),
            "all_u_solves_exact": all(r["exact_u_solve"] for r in rows),
            "k0_values": sorted({r["k0_recomputed"] for r in rows}),
            "u_dim_values": sorted({r["u_dim"] for r in rows}),
            "c3c_all_agree": all(c["agree"] for c in c3c),
            "c3c_perturbed_k0": sorted({c["k0"] for c in c3c if c["side"] == "perturbed"}),
        },
    }
    json.dump(out, sys.stdout, indent=1)
    print()
    print(json.dumps(out["summary"]), file=sys.stderr)
    for c in c3c:
        print(f"C3c {c['shape']:6s} {os.path.basename(c['record']):28s} {c['system']:11s} {c['side']:9s} "
              f"k0 {c['k0']} joint {c['joint_recorded']} = {c['n']}*{c['k0']} + {c['u_dim_assumed']} -> {c['agree']}",
              file=sys.stderr)


if __name__ == "__main__":
    main()
