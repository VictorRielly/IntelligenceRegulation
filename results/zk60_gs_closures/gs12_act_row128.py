"""GS-12: the activation table's row 128 on real captures, and Dom::F's pads.

GS-12 asks whether every activation lookup argument at a PADDED position is a
row of the activation table for every admitted statement and witness.  The
code argument is in ZK60_GS4_GS5_GS11_GS12_CLOSURES.md §4: at a padded Dom::F
position every admitted witness carries (g8, a16) = (0, 0), so the argument is
the pair (128, 0), a table row iff act[128] == 0, which ruling S38-F1(a)
requires at every shape whose Dom::F pads (private_block.rs:678-680, lane
`2ea7221`), re-checked by ruling CS-1 wherever a statement meets a shape.

This script MEASURES the two public facts that argument turns on, on the four
standalone block captures (READ-ONLY; the lane repo's rung-G bundles and the
125M bundles under /home/victor/zk60-artifacts):

 (1) how many Dom::F positions are padded at the capture's shape:
     t_pad * f_pad - tokens * hidden (Dom::F is the (t_pad, f_pad) cube);
 (2) act[128], recovered from the PUBLIC activation table the TAB slot (slot
     19) carries: each row is  i + beta * act[i] + TAG_ACT * gamma
     (argument.rs:1067-1069, protocol.rs:1029-1034, TAG_ACT = 134 at
     hashline/src/tables_attn.rs:77), with (beta, gamma) the first two of the
     capture's three replayed LogUp challenges.  The table is identified as
     the one public table of slot 19 whose every row inverts to an integer
     in the i16 range; its rows 256..len must repeat rows 0..255 (the padded
     copy of the table, the P-3 lift).

Only the public table bytes are read (by offset and length from the array
store, checked against the reference's declared sha256).  Nothing here is a
privacy property.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys

P = 2**64 - 2**32 + 1
NR = 7
TAG_ACT = 134
LANE = "/home/victor/wt-zk60-block125m"
ART = "/home/victor/zk60-artifacts"
BUNDLES = [
    ("rung-G block, dense", f"{LANE}/results/zk60_block_captures_20260923/rung-g/rung-g-dense"),
    ("rung-G block, zero", f"{LANE}/results/zk60_block_captures_20260923/rung-g/rung-g-zero"),
    ("125M block, dense", f"{ART}/block-captures-20260923/m125-dense"),
    ("125M block, zero", f"{ART}/block-captures-20260923/m125-zero"),
]


def f2_mul(x, y):
    return ((x[0] * y[0] + NR * x[1] * y[1]) % P, (x[0] * y[1] + x[1] * y[0]) % P)


def f2_sub(x, y):
    return ((x[0] - y[0]) % P, (x[1] - y[1]) % P)


def f2_inv(x):
    n = (x[0] * x[0] - NR * x[1] * x[1]) % P
    ni = pow(n, P - 2, P)
    return (x[0] * ni % P, (-x[1]) * ni % P)


def as_i16(v):
    """An Fp element as a signed integer, or None if it is not in i16 range."""
    s = v if v <= P // 2 else v - P
    return s if -32768 <= s <= 32767 else None


def read_fp2_array(bundle_dir, ref):
    with open(os.path.join(bundle_dir, "arrays.bin"), "rb") as fh:
        fh.seek(ref["offset"])
        raw = fh.read(ref["bytes"])
    if hashlib.sha256(raw).hexdigest() != ref["array"]:
        raise ValueError("array bytes do not match the reference's digest")
    out = []
    for k in range(ref["len"]):
        c0 = int.from_bytes(raw[16 * k : 16 * k + 8], "little")
        c1 = int.from_bytes(raw[16 * k + 8 : 16 * k + 16], "little")
        out.append((c0, c1))
    return out


def main():
    report = []
    for label, d in BUNDLES:
        blk = json.load(open(os.path.join(d, "block.json")))
        obs = json.load(open(os.path.join(d, "observations.json")))
        sh = blk["shape"]
        padded_F = sh["t_pad"] * sh["f_pad"] - sh["tokens"] * sh["hidden"]
        beta, gamma = (tuple(obs["logup_challenges"][0]), tuple(obs["logup_challenges"][1]))
        g_act = f2_mul(gamma, (TAG_ACT, 0))
        binv = f2_inv(beta)
        tab_slot = [a for a in obs["arguments"] if a["slot"] == 19][0]
        pubs = [t for t in tab_slot["tables"] if t.get("kind") == "public"]
        found = None
        for ti, t in enumerate(pubs):
            vals = read_fp2_array(d, t["values"])
            act = []
            ok = True
            for i, v in enumerate(vals):
                a = f2_mul(f2_sub(f2_sub(v, (i % 256, 0)), g_act), binv)
                if a[1] != 0 or as_i16(a[0]) is None:
                    ok = False
                    break
                act.append(as_i16(a[0]))
            if ok:
                found = {
                    "public_table_index_in_slot_19": ti,
                    "rows": len(vals),
                    "act_128": act[128],
                    "padded_rows_repeat_true_rows": all(act[i] == act[i % 256] for i in range(len(act))),
                    "act_127_128_129": act[127:130],
                    "sha256": t["sha256"],
                }
                break
        report.append(
            {
                "bundle": label,
                "profile": sh["profile"],
                "Dom_F_cube": [sh["t_pad"], sh["f_pad"]],
                "Dom_F_true": [sh["tokens"], sh["hidden"]],
                "Dom_F_padded_positions": padded_F,
                "Dom_F_pads": padded_F > 0,
                "activation_table": found,
                "S38_F1a_condition_holds": (padded_F == 0) or (found is not None and found["act_128"] == 0),
            }
        )
    json.dump(report, sys.stdout, indent=1)
    print()
    for r in report:
        a = r["activation_table"]
        print(f"{r['bundle']:22s} Dom::F cube {r['Dom_F_cube']} true {r['Dom_F_true']} padded {r['Dom_F_padded_positions']:5d} "
              f"act[128] {a and a['act_128']} (rows {a and a['rows']}, padded rows repeat {a and a['padded_rows_repeat_true_rows']}) "
              f"S38-F1(a) holds {r['S38_F1a_condition_holds']}", file=sys.stderr)


if __name__ == "__main__":
    main()
