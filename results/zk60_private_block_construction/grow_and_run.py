#!/usr/bin/env python3
"""Build the GROWN (Tier-1) private-block schedule description and run the two
security tools on it.  Adversarial check of ZK60_PRIVATE_BLOCK_CONSTRUCTION.md sections
C.3 / G, 2026-09-19.

NOTHING under scripts/ is modified.  This driver:
  1. imports `scripts/zk60_attention_native_inventory.py` by file path (the same
     `load_tool` mechanism that script uses for the two tools it drives);
  2. parses the REAL layout.rs / argument.rs / protocol.rs into the accepted
     `Layout` + site list, and re-emits the accepted inventory (self-check A: the
     claim list must be byte-identical to the committed accepted record);
  3. patches a COPY of that Layout into the grown Tier-1 layout (norm_m + residual 2)
     and transforms the accepted site list into the grown one;
  4. calls the inventory module's own `build_inventory`, `run_rank_tool` and
     `run_cfs_tool` on the grown description.

The grown layout is a PAPER description.  A tool verdict on it is evidence about
this description, not about code, which does not exist.

Usage: python3 grow_and_run.py [--seed N]
"""
from __future__ import annotations

import argparse
import copy
import importlib.util
import json
import os
import sys

REPO = "/home/victor/wt-zk60-attention-compile"
OUT = os.path.join(REPO, "results", "zk60_private_block_construction")
SCRIPTS = os.path.join(REPO, "scripts")
MOD = os.path.join(REPO, "hashline", "src", "private_attention")


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    sys.modules[name] = m
    spec.loader.exec_module(m)
    return m


INV = load(os.path.join(SCRIPTS, "zk60_attention_native_inventory.py"), "zk60_attention_native_inventory")

# ---------------------------------------------------------------- grown declaration

# (name, domain) in grown plane order.  `None` name = an unnamed plane (A_NR1..3 etc).
A_PLANES = (
    [("A_D", "T"), ("A_DSQ", "T"), ("A_DM", "T"), ("A_DSQM", "T"),
     ("A_MX", "Ht"), ("A_SUM", "Ht"), ("A_LIMB", "L"), ("A_LIMBM", "L"),
     ("A_X", "D"), ("A_XL0", "D"), ("A_XL1", "D"), ("A_Y", "D")]
    + [("A_NR0", "D")] + [(None, "D")] * 3
    + [("A_NS0", "D")] + [(None, "D")] * 3
    + [("A_AO", "D"), ("A_AL0", "D"), ("A_AL1", "D"), ("A_RAL", "D"),
       ("A_X1", "D"), ("A_X1L0", "D"), ("A_X1L1", "D"),
       ("A_YM", "D")]
    + [("A_MR0", "D")] + [(None, "D")] * 3
    + [("A_MS0", "D")] + [(None, "D")] * 3
    + [("A_Z16", "D"), ("A_X2", "D"), ("A_X2L0", "D"), ("A_X2L1", "D")]
    + [("A_Q8", "Q"), ("A_RQL", "Q"), ("A_QR8", "Q"), ("A_RQRL", "Q"),
       ("A_O8", "Q"), ("A_RO0", "Q"), ("A_RO1", "Q"),
       ("A_K8", "Kv"), ("A_RKL", "Kv"), ("A_V8", "Kv"), ("A_RVL", "Kv"),
       ("A_KR8", "Kv"), ("A_RKRL", "Kv"),
       ("A_S8", "S"), ("A_RSL", "S"), ("A_ZSEL", "S"), ("A_E", "S"), ("A_P", "S"),
       ("A_PL0", "S"), ("A_PL1", "S"), ("A_SR0", "S"), ("A_SR1", "S"),
       ("A_SG0", "S"), ("A_SG1", "S"),
       ("A_MU8", "Tab"), ("A_MEXP", "Tab")]
)

H_PLANES = (
    [("H_L", "L"), ("H_D0", "D")] + [(None, "D")] * 16
    + [("H_Q0", "Q")] + [(None, "Q")] * 6
    + [("H_KV0", "Kv")] + [(None, "Kv")] * 5
    + [("H_S0", "S")] + [(None, "S")] * 6
    + [("H_SEXP", "S"), ("H_GU8", "Tab"), ("H_GEXP", "Tab"), ("H_U", "Tab")]
)

# grown slot order: (const, main, ext, degree, kind)
SLOTS = [
    ("SC_SS", 9, 1, 3, "Private"),
    ("SC_SSM", 9, 1, 3, "Private"),
    ("SC_TZC", 5, 1, 3, "Host"),
    ("SC_LZC", 9, 1, 4, "Standalone"),       # degree 3 -> 4 (two-lookup helper branch)
    ("SC_RS", 11, 1, 3, "Private"),
    ("SC_QMM", 4, 1, 2, "Private"),
    ("SC_KMM", 4, 1, 2, "Private"),
    ("SC_VMM", 4, 1, 2, "Private"),
    ("SC_SCORE", 3, 2, 2, "Private"),
    ("SC_PV", 5, 2, 2, "Private"),
    ("SC_WO", 4, 1, 2, "Private"),
    ("SC_DZC", 9, 1, 4, "Host"),
    ("SC_QZC", 9, 1, 4, "Host"),
    ("SC_KVZC", 8, 1, 4, "Host"),
    ("SC_SZC", 11, 1, 4, "Host"),
    ("SC_TAB", 8, 1, 3, "Standalone"),
    ("SC_ZS", 8, 1, 2, "Standalone"),
    ("SC_IO_IN", 9, 1, 2, "Standalone"),
    ("SC_IO_OUT", 9, 1, 2, "Standalone"),
]
SLOT_NAMES = {
    "SC_SS": "01 SS_a row sums (private)",
    "SC_SSM": "01m SS_m row sums (private)",
    "SC_TZC": "02 norm squares zero-check (hosts 01, 01m)",
    "SC_LZC": "08 limb zero-check (A_LIMB + A_LIMBM)",
    "SC_RS": "07 masked row sums + selector (private)",
    "SC_QMM": "09Q matmul (private)",
    "SC_KMM": "09K matmul (private)",
    "SC_VMM": "09V matmul (private)",
    "SC_SCORE": "10 score matmul (private, bilinear)",
    "SC_PV": "11 PV matmul (private, bilinear)",
    "SC_WO": "12 Wo matmul (private)",
    "SC_DZC": "03 D zero-check (hosts 12; norm_m c6/c7 + residual 2 c8/c9)",
    "SC_QZC": "04 Q zero-check (hosts 09Q, 11)",
    "SC_KVZC": "05 KV zero-check (hosts 09K, 09V)",
    "SC_SZC": "06 softmax zero-check (hosts 07, 10)",
    "SC_TAB": "TAB table helper zero-check",
    "SC_ZS": "ZS zero-sum row",
    "SC_IO_IN": "IO-in endpoint equality",
    "SC_IO_OUT": "IO-out endpoint equality",
}
HOSTS = [("SC_TZC", ["SC_SS", "SC_SSM"]), ("SC_DZC", ["SC_WO"]),
         ("SC_QZC", ["SC_QMM", "SC_PV"]), ("SC_KVZC", ["SC_KMM", "SC_VMM"]),
         ("SC_SZC", ["SC_RS", "SC_SCORE"])]
LOOKUP_COUNTS = {"T": 0, "Ht": 0, "L": 2, "D": 34, "Q": 13, "Kv": 12, "S": 13, "Tab": 0}
HELPERS = {"L": ("H_L", 1), "D": ("H_D0", 17), "Q": ("H_Q0", 7), "Kv": ("H_KV0", 6), "S": ("H_S0", 7)}
N_LIMBS = 9


def build_grown_layout(base):
    lay = copy.deepcopy(base)
    n = lay.n
    lay.n_a = len(A_PLANES)
    lay.n_h = len(H_PLANES)
    lay.n_slots = len(SLOTS)
    lay.a_dom = [d for _, d in A_PLANES]
    lay.h_dom = [d for _, d in H_PLANES]
    lay.a_planes = {nm: i for i, (nm, _) in enumerate(A_PLANES) if nm}
    lay.h_planes = {nm: i for i, (nm, _) in enumerate(H_PLANES) if nm}
    lay.slot_const = {c: i for i, (c, *_r) in enumerate(SLOTS)}
    lay.slot_name_of = {i: c for c, i in lay.slot_const.items()}
    lay.slot_names = [SLOT_NAMES[c] for c, *_r in SLOTS]
    lay.slots = [(m, e, d) for _c, m, e, d, _k in SLOTS]
    lay.slot_kinds = [k for *_r, k in SLOTS]
    lay.hosts = [(lay.slot_const[h], [lay.slot_const[x] for x in hs]) for h, hs in HOSTS]
    lay.lookup_counts = dict(LOOKUP_COUNTS)
    lay.helpers = {d: (p, c) for d, (p, c) in HELPERS.items()}
    lay.a_sites = A_SITES
    lay.h_sites = H_SITES
    lay.consts = dict(lay.consts)
    for nm, i in lay.a_planes.items():
        lay.consts[nm] = i
    for nm, i in lay.h_planes.items():
        lay.consts[nm] = i
    for c, i in lay.slot_const.items():
        lay.consts[c] = i
    lay.consts.update({"N_A": lay.n_a, "N_H": lay.n_h, "N_SLOTS": lay.n_slots,
                       "M_ROWS": 2 * lay.n_slots + 4,
                       "N_FUNCTIONALS": lay.n_slots
                       + sum(1 for k in lay.slot_kinds if k == "Standalone") + len(HOSTS),
                       "N_LIMBS": N_LIMBS, "N": n})
    lay._geometry()
    lay.consts["A_GROUPS"] = -1  # derived below
    lay.consts["H_GROUPS"] = -1
    return lay


# grown claim sites per slot: filled after the accepted parse (coords are copied verbatim
# wherever the relation is unchanged, so no symbol is invented).
A_SITES = [1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 34, 8, 7, 13, 2, 0, 1, 1]
H_SITES = [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 17, 7, 6, 8, 2, 1, 0, 0]


def rho(slot_const, k):
    return [f"rho_{slot_const}[{i}]" for i in range(k)]


def grow_sites(base, accepted, lay):
    """The grown per-slot site list.  Every accepted site is carried over unchanged except
    for its plane index / element offset (the planes renumber); every NEW site mirrors an
    accepted one plane for plane."""
    S = INV.Site
    ai = {nm: i for i, (nm, _) in enumerate(A_PLANES) if nm}
    hi = {nm: i for i, (nm, _) in enumerate(H_PLANES) if nm}
    aoff = lambda nm: lay.a_off[ai[nm]]
    hoff = lambda nm: lay.h_off[hi[nm]][0]
    # base plane index -> grown plane index (the four T/L insertions and the thirteen new
    # Dom::D planes shift everything after them; nothing is reordered)
    amap = ([0, 1, 4, 5, 6] + list(range(8, 27)) + list(range(40, 66)))
    hmap = ([0] + list(range(1, 11)) + list(range(18, 25)) + list(range(25, 31))
            + list(range(31, 38)) + [38, 39, 40, 41])
    assert len(amap) == base.n_a and len(hmap) == base.n_h, (len(amap), len(hmap))
    out = {}

    def carry(old_slot, new_slot):
        res = []
        for s in accepted[old_slot]:
            if s.cm in ("In", "Out"):
                res.append(S(s.cm, new_slot, -1, None, s.offset, s.log, list(s.coords), s.desc, s.ext_round))
                continue
            if s.cm == "A":
                if s.plane is not None:
                    p = amap[s.plane]
                    res.append(S("A", new_slot, -1, p, lay.a_off[p], s.log, list(s.coords), s.desc, s.ext_round))
                else:  # a sub-row slice: re-base onto the new A_LIMB / A_MX / A_SUM offset
                    if base.a_off[base.consts["A_LIMB"]] <= s.offset < base.a_off[base.consts["A_LIMB"]] + 512:
                        k = (s.offset - base.a_off[base.consts["A_LIMB"]]) // 32
                        off = aoff("A_LIMB") + 32 * k
                        desc = f"A[offset {off}, log 5]"
                    elif s.offset == base.a_off[base.consts["A_D"]]:
                        off, desc = aoff("A_D"), f"A[offset {aoff('A_D')}, log 5]"
                    elif s.offset == base.a_off[base.consts["A_MX"]]:
                        off, desc = aoff("A_MX"), f"A[offset {aoff('A_MX')}, log 6]"
                    elif s.offset == base.a_off[base.consts["A_SUM"]]:
                        off, desc = aoff("A_SUM"), f"A[offset {aoff('A_SUM')}, log 6]"
                    else:
                        raise SystemExit(f"unmapped sub-row slice at {s.offset}")
                    res.append(S("A", new_slot, -1, None, off, s.log, list(s.coords), desc, s.ext_round))
            else:
                p = hmap[s.plane]
                res.append(S("H", new_slot, -1, p, lay.h_off[p][0], s.log,
                             list(s.coords), s.desc, s.ext_round))
        return res

    bc = base.slot_const
    nc = lay.slot_const

    # 00 SS_a  -- unchanged
    out[nc["SC_SS"]] = carry(bc["SC_SS"], nc["SC_SS"])
    # 01 SS_m  -- NEW, the exact mirror of SS_a with A_X1 in place of A_X
    out[nc["SC_SSM"]] = [S("A", nc["SC_SSM"], -1, ai["A_X1"], aoff("A_X1"), 9,
                           rho("SC_SSM", 9), "A[A_X1]")]
    # 02 T zero-check -- the accepted 11 sites, then the 11 norm_m mirrors
    tz = carry(bc["SC_TZC"], nc["SC_TZC"])
    tz.append(S("A", nc["SC_TZC"], -1, ai["A_DM"], aoff("A_DM"), 5, rho("SC_TZC", 5), "A[A_DM]"))
    tz.append(S("A", nc["SC_TZC"], -1, ai["A_DSQM"], aoff("A_DSQM"), 5, rho("SC_TZC", 5), "A[A_DSQM]"))
    for k in range(N_LIMBS):
        off = aoff("A_LIMBM") + 32 * k
        tz.append(S("A", nc["SC_TZC"], -1, None, off, 5, rho("SC_TZC", 5), f"A[offset {off}, log 5]"))
    out[nc["SC_TZC"]] = tz
    # 03 limb zero-check -- a_range(A_LIMB, A_LIMBM) then H_L
    lz = carry(bc["SC_LZC"], nc["SC_LZC"])
    lz.insert(1, S("A", nc["SC_LZC"], -1, ai["A_LIMBM"], aoff("A_LIMBM"), 9,
                   rho("SC_LZC", 9), "A[A_LIMBM]"))
    out[nc["SC_LZC"]] = lz
    for c in ("SC_RS", "SC_QMM", "SC_KMM", "SC_VMM", "SC_SCORE", "SC_PV", "SC_WO",
              "SC_QZC", "SC_KVZC", "SC_SZC", "SC_TAB", "SC_ZS", "SC_IO_IN"):
        out[nc[c]] = carry(bc[c], nc[c])
    # 11 D zero-check -- 13 new Dom::D planes inside a_range, + the A_DM broadcast slice,
    #                    + 7 more Dom::D helpers
    dz = carry(bc["SC_DZC"], nc["SC_DZC"])
    a_part = [s for s in dz if s.cm == "A"]
    h_part = [s for s in dz if s.cm == "H"]
    newd = ["A_YM"] + [f"#MR{k}" for k in range(4)] + [f"#MS{k}" for k in range(4)] \
        + ["A_Z16", "A_X2", "A_X2L0", "A_X2L1"]
    ins = []
    for nm in newd:
        if nm.startswith("#MR"):
            p = ai["A_MR0"] + int(nm[3:])
        elif nm.startswith("#MS"):
            p = ai["A_MS0"] + int(nm[3:])
        else:
            p = ai[nm]
        ins.append(S("A", nc["SC_DZC"], -1, p, lay.a_off[p], 9, rho("SC_DZC", 9), f"A[{nm}]"))
    # a_range(A_X, A_X2L1) order: the 19 accepted planes, the 13 new ones, then the slices
    a_part = a_part[:-1] + ins + [a_part[-1]]
    a_part.append(S("A", nc["SC_DZC"], -1, None, aoff("A_DM"), 5, rho("SC_DZC", 5),
                    f"A[offset {aoff('A_DM')}, log 5]"))
    for j in range(10, 17):
        p = hi["H_D0"] + j
        h_part.append(S("H", nc["SC_DZC"], -1, p, lay.h_off[p][0], 9, rho("SC_DZC", 9), f"H[H_D0+{j}]"))
    out[nc["SC_DZC"]] = a_part + h_part
    # 18 IO-out -- the output endpoint now binds A_X2
    io = carry(bc["SC_IO_OUT"], nc["SC_IO_OUT"])
    io[0] = S("A", nc["SC_IO_OUT"], -1, ai["A_X2"], aoff("A_X2"), 9, list(io[0].coords), "A[A_X2]")
    out[nc["SC_IO_OUT"]] = io

    for s in range(lay.n_slots):
        ak = hk = 0
        for site in out[s]:
            if site.cm == "A":
                site.k, ak = ak, ak + 1
            elif site.cm == "H":
                site.k, hk = hk, hk + 1
        if ak != lay.a_sites[s] or hk != lay.h_sites[s]:
            raise SystemExit(f"slot {s} {lay.slot_name_of[s]}: built {ak}/{hk} sites, "
                             f"declared {lay.a_sites[s]}/{lay.h_sites[s]}")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=INV.DEFAULT_SEED)
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    report = {}

    with open(os.path.join(MOD, "layout.rs")) as f:
        base = INV.Layout(f.read())
    with open(os.path.join(MOD, "argument.rs")) as f:
        accepted = INV.DefineParser(base, f.read()).parse()
    with open(os.path.join(MOD, "protocol.rs")) as f:
        protocol_src = f.read()
    sha = {p: INV.sha256_file(os.path.join(REPO, p)) for p in (
        "hashline/src/private_attention/layout.rs",
        "hashline/src/private_attention/argument.rs",
        "hashline/src/private_attention/protocol.rs")}

    # ---- self-check A: re-emit the ACCEPTED inventory and compare with the record ----
    acc_inv = INV.build_inventory(base, accepted, sha, REPO, protocol_src=protocol_src)
    with open(os.path.join(OUT, "accepted_rerun", "zk60_attention_native_inventory.json")) as f:
        rec = json.load(f)
    same = acc_inv["A1_schedule"]["claims"] == rec["A1_schedule"]["claims"]
    report["self_check_accepted_claims_identical"] = same
    report["accepted"] = {"A_sites": acc_inv["A1_schedule"]["claim_counts"]["A"],
                          "H_sites": acc_inv["A1_schedule"]["claim_counts"]["H_eval"],
                          "A_groups": acc_inv["A1_schedule"]["group_counts"]["A"],
                          "H_groups": acc_inv["A1_schedule"]["group_counts"]["H"],
                          "a_rows": base.a_rows, "h_rows": base.h_rows}
    if not same:
        raise SystemExit("self-check A failed: the re-emitted accepted claim list differs")

    # ---- the grown Tier-1 description ----
    lay = build_grown_layout(base)
    sites = grow_sites(base, accepted, lay)
    inv = INV.build_inventory(lay, sites, sha, REPO, protocol_src=protocol_src)
    ag = inv["A1_schedule"]["group_counts"]["A"]
    hg = inv["A1_schedule"]["group_counts"]["H"]
    lay.consts["A_GROUPS"] = ag
    lay.consts["H_GROUPS"] = hg
    inv["layout"]["A_GROUPS_declared"] = ag
    inv["layout"]["H_GROUPS_declared"] = hg
    inv["task"] = ("GROWN Tier-1 private-block schedule (norm_m + residual 2) -- PAPER DESCRIPTION, "
                   "no Rust exists; adversarial check of ZK60_PRIVATE_BLOCK_CONSTRUCTION.md sections C.3 / G")
    inv["tool"] = "results/zk60_private_block_construction/grow_and_run.py"
    inv["profile"] = {"name": "hashline-zk-mr1/private-block-t32-poc/1 (PROPOSED, not implemented)",
                      "geometry": inv["profile"]["geometry"],
                      "privacy": inv["profile"]["privacy"]}
    with open(os.path.join(OUT, "zk60_private_block_grown_inventory.json"), "w") as f:
        json.dump(inv, f, indent=1, sort_keys=True, default=str)
        f.write("\n")
    with open(os.path.join(OUT, "zk60_private_block_grown_hosts.json"), "w") as f:
        json.dump({"variant": "grown Tier-1 HOSTS", "hosts": inv["A2_cfs_slots"]["hosts"],
                   "extra_slots": {}}, f, indent=1)
        f.write("\n")

    report["grown_counts"] = {
        "a_rows": lay.a_rows, "a_data_rows": lay.a_data_rows, "a_site_pair_rows": 2 * sum(lay.a_sites),
        "h_rows": lay.h_rows, "h_data_rows": lay.h_data_rows, "h_site_pair_rows": 2 * sum(lay.h_sites),
        "A_sites": sum(lay.a_sites), "H_sites": sum(lay.h_sites),
        "A_groups_derived": ag, "H_groups_derived": hg,
        "M_ROWS": lay.consts["M_ROWS"], "N_FUNCTIONALS": lay.consts["N_FUNCTIONALS"],
        "largest_L": max((m + e) * d + 2 for m, e, d in lay.slots),
        "U8_lookups": INV.lookup_total(lay)["U8"], "exp_lookups": INV.lookup_total(lay)["exp"],
        "main_rounds_total": sum(m for m, _e, _d in lay.slots),
        "ext_rounds_total": sum(e for _m, e, _d in lay.slots),
        "slot_L": {lay.slot_name_of[s]: (m + e) * d + 2 for s, (m, e, d) in enumerate(lay.slots)},
        "hosts_by_index": {h: list(hs) for h, hs in lay.hosts},
    }
    report["grown_A_opening_groups"] = [
        {"group": g["group"], "c0": g["c0"], "len": g["len"], "m": g["m"]}
        for g in inv["A1_schedule"]["opening_groups"]["A"]]

    # ---- the two tools on the grown description ----
    rank, sched, rank_fail = INV.run_rank_tool(inv, lay, SCRIPTS, args.seed, n_values=4)
    cfs, cfs_fail = INV.run_cfs_tool(inv, lay, SCRIPTS, OUT, args.seed)
    for nm, obj in (("zk60_private_block_grown_pair_schedule.json", rank),
                    ("zk60_private_block_grown_schedule.json", sched),
                    ("zk60_private_block_grown_cfs_slots.json", cfs)):
        with open(os.path.join(OUT, nm), "w") as f:
            json.dump(obj, f, indent=1, sort_keys=True, default=str)
            f.write("\n")

    rv = rank["rank_verdicts"]
    report["rank"] = {
        "whole_A_per_column": rv["whole_A_per_column"]["disclosed_dim"],
        "whole_A_with_values_n4": rv["whole_A_with_values_n4"]["disclosed_dim"],
        "whole_H_per_column": rv["whole_H_per_column"]["disclosed_dim"],
        "whole_H_with_values": {k: v["disclosed_dim"] for k, v in rv.items()
                                if k.startswith("whole_H_with_values")},
        "H_residual_is_exactly_the_public_identity": all(
            v.get("residual_is_exactly_the_public_identity")
            for k, v in rv.items() if k.startswith("whole_H_with_values")),
        "endpoints": {k: v["disclosed_dim"] for k, v in rv.items() if k.startswith("endpoint_")},
        "groups_with_nonzero_disclosure": {k: v["disclosed_dim"] for k, v in rv.items()
                                           if k.startswith("group_") and v.get("disclosed_dim")},
        "n_groups_checked": {"A": sum(1 for k in rv if k.startswith("group_A_")),
                             "H": sum(1 for k in rv if k.startswith("group_H_"))},
        "negative_controls": {k: {"disclosed_dim": v["disclosed_dim"], "verdict": v["verdict"]}
                              for k, v in rv["negative_controls"].items()},
        "failures": rank_fail,
    }
    report["cfs"] = {
        "n_slots": len(cfs["slot_table"]),
        "largest_slot": cfs["largest_slot"],
        "standalone": {k: {"rank": v["rank_map"], "dim_S": v["dim_consistency_subspace"],
                           "kernel": v["kernel_dim_fp2"], "leaked": v["leaked_dim_fp2"],
                           "pass": v["pass"]} for k, v in cfs["standalone"].items()},
        "hosts": {k: {"hosted": v["hosted"], "sum_L": v["sum_L"], "rank": v["rank_map"],
                      "dim_S": v["dim_consistency_subspace"], "kernel": v["kernel_dim_fp2"],
                      "expected_kernel": v["expected_kernel_k_plus_1"],
                      "leaked": v["leaked_dim_fp2"], "pass": v["pass"]}
                  for k, v in cfs["host_groups"].items()},
        "m_rows": cfs["m_layout"]["n_rows"], "n_functionals": cfs["m_layout"]["n_functionals"],
        "negative_controls": {k: v.get("pass") for k, v in cfs["negative_controls"].items()
                              if isinstance(v, dict) and "pass" in v},
        "all_checks_pass": cfs["all_checks_pass"], "failures": cfs_fail,
    }
    report["failures"] = [f"rank/{x}" for x in rank_fail] + [f"cfs/{x}" for x in cfs_fail]
    report["caveat"] = ("These verdicts are about a PAPER schedule description, not about code. "
                        "No Rust implements the grown layout; the tools' models exclude the sampled "
                        "columns, the salted Merkle paths, the CFS channel, transcript conditioning "
                        "and A<->H correlation, exactly as on the accepted layout.")
    with open(os.path.join(OUT, "zk60_private_block_grown_summary.json"), "w") as f:
        json.dump(report, f, indent=1, sort_keys=True, default=str)
        f.write("\n")
    print(json.dumps(report, indent=1, sort_keys=True, default=str))
    return 0 if not report["failures"] else 1


if __name__ == "__main__":
    sys.exit(main())
