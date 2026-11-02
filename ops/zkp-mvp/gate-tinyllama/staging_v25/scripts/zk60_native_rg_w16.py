#!/usr/bin/env python3
"""[v25 STAGING, 2026-11-01] W16 (D54): the privacy gate's first items on a
W16 capture -- ONE-BLOCK PLAIN-RUN bundles at a W16 block profile.

    python3 -B zk60_native_rg_w16.py --bundle <dir> --evidence <dir> [--name N] [--no-controls]

WHY A NEW MODULE.  v24 has no path for a W16 capture.  The R13 block port
(`zk60_native_rg_r13blocks`) runs only inside a classifier capture (schema 7,
`classifier_schedule_digest`, `TokenBlockShim`), and W16 registers no
classifier run yet; the plain run gate (`zk60_native_run_gate`) has no
accuracy-stack dispatch and suspends every stage on the run-layer pins of any
post-R9 tree.  A W16 capture today is a test-only one-block run
(`hashline/src/private_block/w16_privacy_gate_tests.rs`,
`w16_privacy_gate_write_the_w16_bundles`), schema `5-run`.  This module is
ADDITIVE: it imports v24's GENERIC machinery unchanged and adds a W16 port of
what is new.  No v24 module, table or test is edited, so no R13 / R14 record
moves.

WHAT IT RUNS (one record part each):

  W16-0  load and integrity: `rg_bundle.integrity` (manifest hashes and byte
         lengths, schema strings, sizes against `run.json["shape"]`)
  W16-1  the profiles: the block profile is a W16 profile (`shape.rs`
         W16_PROFILES) and the run profile is one of the TEST-ONLY W16 run
         identities (no production W16 run profile exists).  [2026-11-02,
         D59 condition (5)] Also a W16R2 profile (`W16R2_PROFILES`: W16 at
         code rate 1/2), and the PCS geometry fact: the shape, every regular
         opening (params, q_pad, columns, clear-vector lengths) and M carry
         the family's rate and Q (W16 1/4 and 256, W16R2 1/2 and 260) and M's
         own constants (2^12, 256).  The rank parts (W16-6) read the rate and
         Q from the bundle, so they run at W16R2 unchanged.
  W16-2  the calibration, bound: `stagecal.schedule_digest` recomputed from
         run.json's own lines (the replayed header absorbs that digest), the
         R13-format calibration line parsed and its printed precision
         re-derived (`r13slots.parse_calibration_line`); the gate shift G is
         the line's `gate-common`
  W16-3  the draw replay: `rg_replay.RunReplay` re-derives every challenge,
         the run binding and the segment position tags
  W16-4  the W16 layout census against this module's independent port: the
         A plane list (`accuracy_layout.rs::new_w16`), the range widths
         (`range16.rs::widths`) and their families / sub-planes, the H plane
         list (`layout.rs::HIds::new`) with each lookup domain's helper
         count = ceil(lookups / 2) from the ported lookups (review F2), and
         SC_TAB's (histogram, helper) pairs, each read by SC_TAB alone
  W16-5  SC_TAB's public tables: the byte column, every range column
         `s 2^lc + (i mod min(2^w, 2^lc)) + gamma (200 + w)` and every narrow
         family's support column rebuilt from the shape and the REPLAYED
         gamma, digest-equal to the capture's (the order and the count too)
  W16-6  PER COMMITMENT (rank): `run_gate.stage3` unchanged -- every
         commitment's disclosed dimension by exact rank (A 0, H 2, external
         endpoints 0, M 0), the pad block's exact rank, the exclusivity
         clauses and their negative controls
  W16-7  MASK / CFS: `rg_mask.mask_cfs_stage` on every stage and
         `rg_mcontrols.mask_controls_at_shape` (its six controls), unchanged
  PINS   every source pin the bundle declares, classified: at the r19b
         frozen tree's digest (the tree v24 last read, manifest
         `manifest_final_r19b.sha256`); moved and READ here (the reading is
         in W16_READINGS); or moved and UNREAD.  v24's own mask-layer and
         run-layer pin tables are run and REPORTED (both refuse a post-R9
         tree); they are not applied as a suspension, and the record's
         status says so.

STATUS.  "W16-DEV-PASS" when every part is true but some pin is unread or a
v24 pin table refuses: the figures were computed on the bundle as given and
are NOT admissible evidence until the pins are read.  "W16-PASS" only when
every part is true and every pin is at an r19b digest or read here (not
reachable at this tree: twelve private_block files are unread).  "NOT-OK"
otherwise.  NOTHING HERE IS A PRIVACY STATEMENT OR AN ACCEPTANCE.

NOT HERE (owed before a W16 statement): the terminal identity (T-0) of the
seven W16-redefined slots (SC_LZC 3 with W16's Dom::L lookups, SC_DZC 14,
SC_QZC 15, SC_KVZC 16, SC_SZC 17, SC_FZC 18, SC_TAB 19; `argument_accuracy.rs`
dzc_w16 .. tab_w16), NL-1 S1-S5 on them, the joint checks, TS-1 and the claim
census, the full preimage, the hash census, the reading of the twelve moved
private_block pins, and the recorder pinning `range16.rs` (it does not: it is
in neither `OWN_SOURCE_FILES` nor `SHARED_SOURCE_FILES`).  [2026-11-02] That
last item is closed in the Rust tree since M26 (`OWN_SOURCE_FILES` lists
`range16.rs`): a bundle written now pins it, as one more UNREAD pin.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_r13slots as R  # noqa: E402
import zk60_native_rg_stagecal as SCAL  # noqa: E402
import zk60_native_rg_terminals as T  # noqa: E402
from zk60_native_jv_field import P, f2_from_list  # noqa: E402

# ---------------------------------------------------------------- the profiles
# shape.rs:234-244 (W16_PROFILES; the T256 / T512 rows are registered as block
# profiles but no W16 capture of them exists)
W16_BLOCK_PROFILES = {
    "hashline-zk-mr1/private-block-rung-lh-t32-w16-dev/1": ("W16_RUNG_H24", "LowH24", "standard"),
    "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-w16/1": ("W16_SHIELD_T128_H24", "LowH24", "shieldstral"),
    "hashline-zk-mr1/private-block-llama-3-8b-t128-lh24-w16/1": ("W16_8B_T128_H24", "LowH24", "standard"),
    "hashline-zk-mr1/private-block-shieldstral-3b-t256-lowh24-w16/1": ("W16_SHIELD_T256_H24", "LowH24", "shieldstral"),
    "hashline-zk-mr1/private-block-llama-3-8b-t256-lh24-w16/1": ("W16_8B_T256_H24", "LowH24", "standard"),
    "hashline-zk-mr1/private-block-llama-3-8b-t512-lh24-w16/1": ("W16_8B_T512_H24", "LowH24", "standard"),
    # [2026-11-02, D59 condition (5)] shape.rs W16R2_PROFILES: W16 at code rate
    # 1/2 (A, H, the boundaries and both endpoints at rate 1/2 with Q = 260
    # opened columns and 260 pads per row; M unchanged).  The same geometry,
    # planes, lookups and SC_TAB tables as the W16 sibling, so every W16 part
    # below reads them unchanged; `W16R2_GEOMETRY` is what differs.
    "hashline-zk-mr1/private-block-rung-lh-t32-w16r2-d/1": ("W16R2_RUNG_H24", "LowH24", "standard"),
    "hashline-zk-mr1/private-block-shieldstral-3b-t128-lh24-w16r2/1": ("W16R2_SHIELD_T128_H24", "LowH24", "shieldstral"),
    "hashline-zk-mr1/private-block-llama-3-8b-t128-lh-w16r2/1": ("W16R2_8B_T128_H24", "LowH24", "standard"),
}
# w16_privacy_gate_tests.rs W16_TEST_RUN_PROFILES: TEST-ONLY run identities
# (run.rs admits them under #[cfg(test)] only; no production build has them)
W16_TEST_RUN_PROFILES = {
    "hashline-zk-mr1/private-run-rung-lh-t32-w16-tst/1": "hashline-zk-mr1/private-block-rung-lh-t32-w16-dev/1",
    "hashline-zk-mr1/private-run-shieldstral-3b-t128-lowh24-w16-tst/1": "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-w16/1",
    "hashline-zk-mr1/private-run-llama-3-8b-t128-lh24-w16-tst/1": "hashline-zk-mr1/private-block-llama-3-8b-t128-lh24-w16/1",
    # [2026-11-02, D59] the W16R2 rung and 8B (W16R2 Shieldstral has none)
    "hashline-zk-mr1/private-run-rung-lh-t32-w16r2-t/1": "hashline-zk-mr1/private-block-rung-lh-t32-w16r2-d/1",
    "hashline-zk-mr1/private-run-llama-3-8b-t128-lh-w16r2-tst/1": "hashline-zk-mr1/private-block-llama-3-8b-t128-lh-w16r2/1",
}
# [2026-11-02, D59] the PCS geometry of a W16-family profile's REGULAR
# commitments (A, H, every boundary, both endpoints): (inv_rate, Q = pads).
# shape.rs: W16 keeps COL_CHECKS = 256 at rate 1/4; W16R2_INV_RATE = 2 and
# W16R2_OPENED_COLS = 260.  The masking commitment M keeps zk.rs's own
# constants at every profile (MASK_LOG_DOM 12, MASK_Q 256).
W16_GEOMETRY = (4, 256)
W16R2_GEOMETRY = (2, 260)
MASK_GEOMETRY = (12, 256)


def is_w16r2_block_profile(profile: str) -> bool:
    return profile in W16_BLOCK_PROFILES and W16_BLOCK_PROFILES[profile][0].startswith("W16R2_")


def pcs_geometry_of(profile: str) -> tuple:
    return W16R2_GEOMETRY if is_w16r2_block_profile(profile) else W16_GEOMETRY

TAG_U8 = 133        # tables_attn.rs TAG_U8 (= zk60_native_rg_terminals.TAG_U8)
TAG_RANGE0 = 200    # range16.rs:31
SH_ROPE = 7         # layout.rs:67
U8_LEN = 256
SC_TAB = 19


def is_w16_block_profile(profile: str) -> bool:
    return profile in W16_BLOCK_PROFILES


# ---------------------------------------------------------------- range16.rs
def limbs_of(bits: int) -> int:
    """range16.rs:100-107"""
    if not (1 <= bits <= 24):
        raise ValueError("W16: a remainder window outside 1..=24 bits")
    return 1 if bits <= 16 else 2


def widths(stack: str, p: dict, gate_shift: int, wrho_s: int) -> list:
    """range16.rs:150-182: the range widths, the byte width excluded, ascending"""
    h24 = stack == "LowH24"
    w = [16]

    def rem(bits):
        if bits <= 16:
            w.append(bits)
        else:
            w.extend([16, bits - 16])
    rem(24)
    rem(p["ao"])
    rem(p["down"])
    for bits in (p["q"], SH_ROPE, p["pv"], p["k"], p["v"], SH_ROPE):
        rem(bits)
    rem(gate_shift)
    rem(p["up"])
    rem(16 if h24 else 24)
    rem(p["score"])
    rem(p["f_p"] + 1)
    rem(wrho_s)
    return sorted(set(x for x in w if x != 8))


def families(ws: list, log_cols: int) -> list:
    """range16.rs:193-195: [(width, sub-planes)]"""
    return [(w, max((1 << w) >> log_cols, 1)) for w in ws]


def sub_planes(fams: list) -> list:
    """range16.rs:198-200: [(width, sub-plane)] in plane order"""
    return [(w, s) for (w, n) in fams for s in range(n)]


def support(w: int, log_cols: int) -> int:
    return min(1 << w, 1 << log_cols)


def is_full(w: int, log_cols: int) -> bool:
    return support(w, log_cols) == 1 << log_cols


def g_range(gamma, width: int):
    """`range16::g_range` (range16.rs:51-56) from g_u8 = gamma TAG_U8: gamma (200 + w)"""
    return T.mulb(gamma, (TAG_RANGE0 + width) % P)


def range_column(w: int, s: int, log_cols: int, gamma) -> list:
    """`range16::table_column` (range16.rs:215-222), entry by entry"""
    n, sup = 1 << log_cols, support(w, log_cols)
    g = g_range(gamma, w)
    return [T.add(T.k(s * n + i % sup), g) for i in range(n)]


def support_column(w: int, log_cols: int) -> list:
    """`range16::support_column` (range16.rs:225-228)"""
    n, sup = 1 << log_cols, support(w, log_cols)
    return [T.ONE if i < sup else T.ZERO for i in range(n)]


# ---------------------------------------------------------------- accuracy_layout.rs (W16)
def _names(prefix: str, n: int) -> list:
    return [prefix if n == 1 else f"{prefix}{j}" for j in range(n)]


def w16_plane_list(stack: str, dd: bool, p: dict, gate_shift: int, wrho_s: int, log_cols: int) -> list:
    """`AccuracyIds::new_w16` (accuracy_layout.rs:113-185): [(A name, domain)]"""
    if stack not in ("Low", "LowH24") or not (9 <= wrho_s <= 24) or not (17 <= gate_shift <= 24):
        raise ValueError("W16 planes require an explicit LOW stack, a softmax window in 9..=24 and a gate shift in 17..=24")
    if dd:
        raise ValueError("W16: a DD profile is not ported (no W16 DD profile is registered)")
    h24 = stack == "LowH24"
    out = []

    def word(dom, name):
        out.append((f"A_{name}", dom))

    def group(dom, name, n):
        for nm in _names(name, n):
            out.append((f"A_{nm}", dom))
    for nm in ("D", "DSQ", "DM", "DSQM"):
        word("T", nm)
    word("Ht", "MX"); word("Ht", "SUM")
    word("L", "LIMB"); word("L", "LIMBM")
    word("D", "X"); word("D", "Y")
    group("D", "NR", 2); group("D", "NS", 2)
    word("D", "AO"); group("D", "RAL", limbs_of(p["ao"]))
    word("D", "X1"); word("D", "YM")
    group("D", "MR", 2); group("D", "MS", 2)
    word("D", "Z"); group("D", "RDL", limbs_of(p["down"]))
    word("D", "X2")
    word("Q", "Q"); group("Q", "RQL", limbs_of(p["q"]))
    word("Q", "QR"); group("Q", "RQRL", limbs_of(SH_ROPE))
    word("Q", "O"); group("Q", "RO", limbs_of(p["pv"]))
    word("Kv", "K"); group("Kv", "RKL", limbs_of(p["k"]))
    word("Kv", "V"); group("Kv", "RVL", limbs_of(p["v"]))
    word("Kv", "KR"); group("Kv", "RKRL", limbs_of(SH_ROPE))
    word("S", "S"); group("S", "RSL", limbs_of(p["score"]))
    word("S", "ZSEL"); word("S", "E"); word("S", "P")
    group("S", "SR", limbs_of(wrho_s)); group("S", "SG", limbs_of(wrho_s))
    word("F", "G"); group("F", "RGL", limbs_of(gate_shift))
    word("F", "A_SCALED"); word("F", "U"); group("F", "RU", limbs_of(p["up"]))
    word("F", "H"); group("F", "HT", 1 if h24 else 0)
    group("F", "RH", limbs_of(16 if h24 else 24))
    word("Tab", "MU8"); word("Tab", "MEXP"); word("Tab", "MACT")
    for (w, s) in sub_planes(families(widths(stack, p, gate_shift, wrho_s), log_cols)):
        word("Tab", f"R{w}_{s}")
    return out


def w16_lookups(dom: str, stack: str, p: dict, gate_shift: int, wrho_s: int) -> list:
    """`AccuracyIds::lookups_w16` (accuracy_layout.rs:289-343):
    [(terms [(A name, coeff)], constant, width)], width 8 = the U8 family"""
    if p["f_p"] != 12 or p["product_bits"] != (24 if stack == "LowH24" else 16):
        raise ValueError("W16 lookups: a W16 precision is required")
    h24 = stack == "LowH24"
    v = []

    def w(name, bias=32768):
        v.append(([(f"A_{name}", 1)], bias, 16))

    def rem(prefix, bits):
        names = [f"A_{nm}" for nm in _names(prefix, limbs_of(bits))]
        if bits <= 16:
            v.append(([(names[0], 1)], 0, bits))
        else:
            v.append(([(names[0], 1)], 0, 16))
            v.append(([(names[1], 1)], 0, bits - 16))
    if dom == "L":
        v += [([("A_LIMB", 1)], 0, 8), ([("A_LIMBM", 1)], 0, 8)]
    elif dom == "D":
        w("X"); w("Y"); rem("NR", 24); rem("NS", 24)
        w("AO"); rem("RAL", p["ao"]); w("X1")
        w("YM"); rem("MR", 24); rem("MS", 24)
        w("Z"); rem("RDL", p["down"]); w("X2")
    elif dom == "Q":
        w("Q"); rem("RQL", p["q"]); w("QR"); rem("RQRL", SH_ROPE); w("O"); rem("RO", p["pv"])
    elif dom == "Kv":
        w("K"); rem("RKL", p["k"]); w("V"); rem("RVL", p["v"]); w("KR"); rem("RKRL", SH_ROPE)
    elif dom == "F":
        rem("RGL", gate_shift); w("U"); rem("RU", p["up"])
        bias = 1 << (p["product_bits"] - 1)
        if h24:   # range16::word24 (range16.rs:131-133)
            v.append(([("A_H", 1), ("A_HT", -(1 << 16))], bias & 0xFFFF, 16))
            v.append(([("A_HT", 1)], bias >> 16, 8))
        else:
            w("H", bias)
        rem("RH", 16 if h24 else 24)
    elif dom == "S":
        v += [([("A_S", 1)], 127, 8), ([("A_S", -1)], 127, 8)]
        rem("RSL", p["score"])
        bits = p["f_p"] + 1          # range16::direct (range16.rs:141-144)
        if bits > 16:
            raise ValueError("W16: a direct word wider than 16 bits")
        v.append(([("A_P", 1)], 0, bits))
        rem("SR", wrho_s); rem("SG", wrho_s)
    elif dom not in ("T", "Ht", "Tab"):
        raise ValueError(f"W16 lookups: no domain {dom}")
    return v


LOOKUP_DOMS = ("L", "D", "Q", "Kv", "S", "F")


def helper_counts(stack, p, gate_shift, wrho_s) -> dict:
    """ceil(lookups / 2) per domain (helper k covers lookups 2k, 2k + 1)"""
    return {d: (len(w16_lookups(d, stack, p, gate_shift, wrho_s)) + 1) // 2 for d in LOOKUP_DOMS}


def w16_h_list(stack, p, gate_shift, wrho_s, log_cols) -> list:
    """`HIds::new` (layout.rs:623-653) at a non-DD W16 shape, named as
    plane_index.rs names them: [(H name, domain)]"""
    hc = helper_counts(stack, p, gate_shift, wrho_s)
    out = []
    for dom, prefix in (("L", "H_L"), ("D", "H_D"), ("Q", "H_Q"), ("Kv", "H_KV"), ("S", "H_S")):
        out += [(f"{prefix}{j}", dom) for j in range(hc[dom])]
    out.append(("H_SEXP", "S"))
    out += [(f"H_F{j}", "F") for j in range(hc["F"])]
    out.append(("H_FACT", "F"))
    out += [("H_GU8", "Tab"), ("H_GEXP", "Tab"), ("H_GACT", "Tab")]
    out += [(f"H_GR{w}_{s}", "Tab") for (w, s) in sub_planes(families(widths(stack, p, gate_shift, wrho_s), log_cols))]
    out.append(("H_U", "Tab"))
    return out


# ---------------------------------------------------------------- W16-1 / W16-2: the facts
def w16_facts(bundle) -> dict:
    """the profiles, the calibration bound to the schedule digest, the shape
    facts every later part reads; refusals are ValueErrors"""
    run = bundle.run
    sh = run["shape"]
    block = sh.get("profile") or run.get("block_profile")
    if not is_w16_block_profile(block):
        raise ValueError(f"W16-1: the block profile {block!r} is not a W16 profile (shape.rs W16_PROFILES)")
    if W16_TEST_RUN_PROFILES.get(bundle.profile) != block:
        raise ValueError(f"W16-1: the run profile {bundle.profile!r} is not the test-only W16 run identity of {block!r}")
    if int(sh.get("dd_cap", 0)) > 0:
        raise ValueError("W16-1: a DD shape (no W16 DD profile is registered or ported)")
    dig = SCAL.schedule_digest(run)
    if not dig.get("equal"):
        raise ValueError(f"W16-2: run.json's schedule digest does not recompute from its own lines ({dig})")
    cal = R.parse_calibration_line(run["layout_description"])
    stack = W16_BLOCK_PROFILES[block][1]
    if cal["stack"] != stack:
        raise ValueError(f"W16-2: the calibration line's stack {cal['stack']} is not the profile's {stack}")
    g = cal["gate_common"]
    if not (17 <= g <= 24):
        raise ValueError(f"W16-2: the gate shift {g} is outside 17..=24")
    geom = pcs_geometry(bundle, block)
    return {"block_profile": block, "name": W16_BLOCK_PROFILES[block][0], "run_profile": bundle.profile,
            "run_profile_is_test_only": True, "stack": stack, "registry": cal["registry"], "base": cal["base"],
            "gate_shift": g, "precision": cal["precision"], "wrho_s": int(sh["wrho_s"]),
            "log_cols": int(sh["log_cols"]), "schedule_digest_recomputed_equal": True, "pcs_geometry": geom}


def pcs_geometry(bundle, block: str) -> dict:
    """[2026-11-02, D59] W16-1's geometry fact: the shape run.json declares
    carries its family's rate and Q for the regular commitments (the endpoint
    rate follows the core rate), and M carries its own constants; every
    regular opening of every stage file declares the same (its `params`,
    `q_pad`, column count and clear-vector lengths).  A ValueError otherwise."""
    sh = bundle.run["shape"]
    inv_rate, q = pcs_geometry_of(block)
    if (int(sh["inv_rate"]), int(sh["opened_cols"]), int(sh["endpoint_inv_rate"])) != (inv_rate, q, inv_rate):
        raise ValueError(f"W16-1: the shape declares rate 1/{sh['inv_rate']}, Q {sh['opened_cols']}, endpoint rate "
                         f"1/{sh['endpoint_inv_rate']}; the profile family fixes rate 1/{inv_rate}, Q {q} for both")
    md = bundle.run["mask_domain"]
    if (int(md["log_dom"]), int(md["columns"])) != MASK_GEOMETRY:
        raise ValueError(f"W16-1: the mask domain is {md}, M's own constants are log_dom {MASK_GEOMETRY[0]}, "
                         f"columns {MASK_GEOMETRY[1]} at every profile")
    openings = 0
    for st in bundle.stages:
        for r in st.roles:
            check_opening_geometry(sh, st.name, r, inv_rate, q)
            openings += 1
        m = st.mask
        if len(m["columns"]) != MASK_GEOMETRY[1] or any(c["index"] >= 1 << MASK_GEOMETRY[0] for c in m["columns"]):
            raise ValueError(f"W16-1: {st.name} M opens {len(m['columns'])} columns, not its own {MASK_GEOMETRY[1]} "
                             f"over 2^{MASK_GEOMETRY[0]}")
    return {"family": "W16R2" if is_w16r2_block_profile(block) else "W16", "inv_rate": inv_rate, "q": q,
            "pads": q, "endpoint_inv_rate": inv_rate, "mask_log_dom": MASK_GEOMETRY[0], "mask_columns": MASK_GEOMETRY[1],
            "regular_openings_checked": openings}


def check_opening_geometry(sh: dict, where: str, r: dict, inv_rate: int, q: int) -> None:
    """[2026-11-02, D59] one regular opening against its family's geometry:
    log n (the block's for A / H, the endpoint geometry's for a boundary or an
    endpoint), rate, checks = pads = Q, Q columns inside the n * inv_rate
    encoded columns, and every clear vector n + Q long.  A ValueError otherwise."""
    p = r["params"]
    log_n = int(sh["log_cols"]) if r["commitment_kind"] == "block" else int(sh["endpoint_log_n"])
    n = 1 << log_n
    if (p["log_cols"], p["inv_rate"], p["num_col_checks"], r["q_pad"], len(r["columns"])) != (log_n, inv_rate, q, q, q):
        raise ValueError(f"W16-1: {where} {r['role']} opens at log {p['log_cols']} rate 1/{p['inv_rate']} "
                         f"checks {p['num_col_checks']} pads {r['q_pad']} ({len(r['columns'])} columns), "
                         f"not log {log_n} rate 1/{inv_rate} Q = pads = {q}")
    lens = [len(g["vector"]) for g in r["groups"]] + [len(r["proximity_vector"])]
    if any(x != n + q for x in lens):
        raise ValueError(f"W16-1: {where} {r['role']}: clear vectors of {sorted(set(lens))} entries, not n + Q = {n + q}")
    if any(c["index"] >= n * inv_rate for c in r["columns"]):
        raise ValueError(f"W16-1: {where} {r['role']}: an opened column outside the {n * inv_rate} encoded columns")


# ---------------------------------------------------------------- W16-4: the layout census
def check_layout(bundle, facts) -> dict:
    pi = bundle.run["plane_index"]
    st, p, g, ws, lc = facts["stack"], facts["precision"], facts["gate_shift"], facts["wrho_s"], facts["log_cols"]
    f = []
    want_a = w16_plane_list(st, False, p, g, ws, lc)
    got_a = [(x["name"], x["domain"]) for x in pi["a_planes"]]
    if got_a != want_a:
        diff = [i for i, (x, y) in enumerate(zip(got_a, want_a)) if x != y]
        f.append(f"A planes: the capture's list differs from the port at {len(diff) or 'its length'} positions "
                 f"(first {diff[:3]}; {len(got_a)} vs {len(want_a)})")
    want_h = w16_h_list(st, p, g, ws, lc)
    got_h = [(x["name"], x["domain"]) for x in pi["h_planes"]]
    if got_h != want_h:
        diff = [i for i, (x, y) in enumerate(zip(got_h, want_h)) if x != y]
        f.append(f"H planes: the capture's list differs from the port at {len(diff) or 'its length'} positions "
                 f"(first {diff[:3]}; {len(got_h)} vs {len(want_h)})")
    fams = families(widths(st, p, g, ws), lc)
    subs = sub_planes(fams)
    # SC_TAB's private reads: the three pairs, then one (histogram, helper) pair per sub-plane
    tab = [(x["role"], x["name"]) for x in pi["slot_planes"][SC_TAB]["planes"]]
    want_tab = [("A", "A_MU8"), ("H", "H_GU8"), ("A", "A_MEXP"), ("H", "H_GEXP"), ("A", "A_MACT"), ("H", "H_GACT")]
    for (w, s) in subs:
        want_tab += [("A", f"A_R{w}_{s}"), ("H", f"H_GR{w}_{s}")]
    if tab != want_tab:
        f.append(f"SC_TAB reads {len(tab)} planes that are not the (histogram, helper) pairs of the port ({len(want_tab)})")
    new = {f"A_R{w}_{s}" for (w, s) in subs} | {f"H_GR{w}_{s}" for (w, s) in subs}
    elsewhere = sorted({x["name"] for row in pi["slot_planes"] if row["slot"] != SC_TAB for x in row["planes"]} & new)
    if elsewhere:
        f.append(f"a W16 plane is read outside SC_TAB: {elsewhere}")
    hc = helper_counts(st, p, g, ws)
    return {"what": "the capture's plane index against this module's port of new_w16 / lookups_w16 / HIds::new",
            "a_planes": len(got_a), "h_planes": len(got_h), "families": [{"width": w, "sub_planes": n} for (w, n) in fams],
            "range_sub_planes": len(subs), "narrow_families": [w for (w, _n) in fams if not is_full(w, lc)],
            "helpers_per_domain": hc, "lookups_per_domain": {d: len(w16_lookups(d, st, p, g, ws)) for d in LOOKUP_DOMS},
            "a_equal": got_a == want_a, "h_equal": got_h == want_h, "tab_pairs_equal": tab == want_tab,
            "w16_planes_read_only_by_sc_tab": not elsewhere, "findings": f, "ok": not f}


# ---------------------------------------------------------------- W16-5: SC_TAB's public tables
def check_tab_tables(bundle, facts, stage=0) -> dict:
    doc = bundle.stages[stage].doc
    gamma = f2_from_list(doc["logup_challenges"][1])       # (beta, gamma, alpha)
    lc, st, p, g, ws = facts["log_cols"], facts["stack"], facts["precision"], facts["gate_shift"], facts["wrho_s"]
    fams = families(widths(st, p, g, ws), lc)
    subs = sub_planes(fams)
    narrow = [w for (w, _n) in fams if not is_full(w, lc)]
    pub = [t for t in doc["arguments"][SC_TAB]["tables"] if t["kind"] == "public"]
    f = []
    padded = len(pub) == 3 + len(subs) + 2 + len(narrow)
    if not padded and len(pub) != 3 + len(subs):
        return {"ok": False, "findings": [f"SC_TAB carries {len(pub)} public tables; W16 has 3 + {len(subs)} (+ 2 + {len(narrow)} when Dom::Tab pads)"]}
    n = 1 << lc
    rebuilt = 0
    u8 = [T.add(T.k(i % U8_LEN), T.mulb(gamma, TAG_U8)) for i in range(n)]
    if pub[0]["len"] != n or pub[0]["sha256"] != T.table_digest(u8):
        f.append("SC_TAB public table 0 is not the byte column (i mod 256) + gamma 133")
    else:
        rebuilt += 1
    for j, (w, s) in enumerate(subs):
        t = pub[3 + j]
        if t["len"] != n or t["sha256"] != T.table_digest(range_column(w, s, lc, gamma)):
            f.append(f"SC_TAB public table {3 + j} is not the {w}-bit range column (sub-plane {s}) rebuilt from the shape and gamma")
        else:
            rebuilt += 1
    if padded:
        for kk, w in enumerate(narrow):
            t = pub[5 + len(subs) + kk]
            if t["len"] != n or t["sha256"] != T.table_digest(support_column(w, lc)):
                f.append(f"SC_TAB public table {5 + len(subs) + kk} is not the {w}-bit support column")
            else:
                rebuilt += 1
    return {"what": "SC_TAB's byte column, range columns and narrow support columns, rebuilt by the gate from the "
                    "shape and the replayed gamma (range16.rs table_column / support_column; g_range = gamma (200 + w))",
            "public_tables": len(pub), "padded": padded, "range_columns": len(subs),
            "support_columns": len(narrow) if padded else 0, "rebuilt_and_equal": rebuilt,
            "not_rebuilt_here": ["exp values (statement)", "ACT3 values (statement)", "supp(Tab)", "ACT support (statement)"],
            "findings": f, "ok": not f}


def tab_control(bundle, facts) -> dict:
    """the rebuild under one collapsed tag (every width folded at 216) must fail"""
    doc = bundle.stages[0].doc
    gamma = f2_from_list(doc["logup_challenges"][1])
    lc, st, p, g, ws = facts["log_cols"], facts["stack"], facts["precision"], facts["gate_shift"], facts["wrho_s"]
    subs = sub_planes(families(widths(st, p, g, ws), lc))
    pub = [t for t in doc["arguments"][SC_TAB]["tables"] if t["kind"] == "public"]
    n = 1 << lc
    w0, s0 = subs[0]
    col = [T.add(T.k(s0 * n + i % support(w0, lc)), T.mulb(gamma, TAG_RANGE0 + 16)) for i in range(n)]
    fires = w0 != 16 and pub[3]["sha256"] != T.table_digest(col)
    return {"what": f"the {w0}-bit range column rebuilt with the width-16 tag", "fires": fires, "ok": fires}


# ---------------------------------------------------------------- PINS
# moved since r19b and READ in this session (diff r19b -> this tree, hunk by
# hunk; `capture-tree-r19b` = frozen-r19b against the gpu-metal tree of
# 2026-11-01).  A digest here is the bundle's declared one.
W16_READINGS = {
    "src/private_block/run.rs": ("b9b40cadef4a",
        "+7 / -0, one hunk: inside `registered_block_shape`, a `#[cfg(test)]` arm that admits the three TEST-ONLY "
        "W16 run identities (w16_privacy_gate_tests::W16_TEST_RUN_PROFILES); production text unchanged"),
    "src/private_block/run_capture.rs": ("d10d33e3e04f",
        "+24 / -2: `statement_table_at(sh, slot, nth, n_pub)` replaces `r13_statement_table` at the one call site; "
        "it returns R13's label everywhere except SC_TAB at a W16 shape, where only the ACT support (index 4 + #sub, "
        "of 5 + #sub + #narrow) is a statement table; the export replay treats that table as R13's fifth. "
        "No field added, none removed; the writer's key set and order are unchanged"),
    "../zkp-core/src/transcript.rs": ("e766e9e14304",
        "+14 / -0: two read-only accessors, `counter()` and `fs_key()`, for the Metal device rounds; absorb, "
        "squeeze, challenge_* and the keyed form byte-identical"),
    "../zkp-core/src/pcs.rs": ("856929b34333",
        "+1 / -1: the hiding opening's row folds hand `dc.fold_batch()` vectors per device call instead of 4; "
        "the same linear map in a different batching, prover side"),
    "../zkp-core/src/merkle.rs": ("6b66c0bcf200",
        "+50 / -0: `with_min_len(merkle_min_pairs())` on the two parallel level maps (the same hashes in the same "
        "order, only the task split) and an ignored bench test"),
    "../zkp-core/src/rng.rs": ("f6728bd2d520",
        "+107 / -6: `refill` factored into `block_bytes(key, counter)` (the same blake3(key || counter_le) XOF), "
        "a parallel `fill_fp` that `fp_vec` now calls, tested equal word for word and state for state to the "
        "`fp()` loop (`fill_fp_equals_the_draw_loop_and_leaves_the_same_state`); `new`, `from_os` unchanged"),
    "../zkp-core/src/pcs/backend.rs": ("4f03047ac467",
        "+8 / -0: `EncodedStore::fold_batch()` defaulting to 4 (the batching hint pcs.rs reads)"),
    "../zkp-core/src/mle.rs": ("ed7f8849f48d",
        "+132 / -2: the eq-table parallel threshold as a constant, and a deferred column fold that accumulates "
        "exact i128 sums before one reduction (the same field values), prover side"),
    "src/gpu/mod.rs": ("d7812f7d9404",
        "+106 / -5 in 5 hunks (corrected by gate round 26, F-B4; was '+111 / -?'): the Metal backend seam "
        "(`MetalBackend`, `MetalCommit` as an `EncodedStore`, its `try_commit*`), "
        "all behind `feature = \"gpu-metal\"`; the CPU build's seam is the core's `Cpu` backend as before"),
}


def classify_pins(bundle, r19b_manifest: str) -> dict:
    """[2026-11-02, gate round 26] a moved pin is read by the R26 readings
    (`zk60_native_rg_r26readings.R26_READINGS`: the FULL digest must equal the
    reading's; a CPU-PATH reading only on a bundle whose manifest says
    `proved_on_gpu: false`) or by W16_READINGS (as before); any other digest is
    UNREAD.  F-B1: the bundle's prover backend must be admissible
    (`zk60_native_rg_r26readings.gpu_backend`: a bundle that does not record
    `proved_on_gpu` is refused as UNKNOWN, a GPU-made one while the Metal
    backend has no full reading); `ok` needs both."""
    import zk60_native_rg_r26readings as R26
    want = {}
    if r19b_manifest and os.path.exists(r19b_manifest):
        with open(r19b_manifest) as fh:
            for line in fh:
                parts = line.split()
                if len(parts) == 2:     # "<sha256>  hashline/src/..." or "<sha256>  zkp-core/src/..."
                    want[parts[1]] = parts[0]
    pins = bundle.manifest.get("source_pins", [])
    backend = R26.gpu_backend(bundle.manifest)
    at_r19b, read_here, unread, r26 = [], [], [], {}
    for pin in pins:
        f, d = pin["file"], pin["sha256"]
        key = os.path.normpath(os.path.join("hashline", f))
        r = R26.reading_for(f, d, backend["proved_on_gpu"])
        if want.get(key) == d:
            at_r19b.append(f)
        elif r is not None:
            read_here.append(f)
            r26[f] = r
        elif f in W16_READINGS and d.startswith(W16_READINGS[f][0]):
            read_here.append(f)
        else:
            u = {"file": f, "sha256": d[:12], "r19b": (want.get(key) or "absent")[:12]}
            if R26.cpu_path_only(f, d):
                u["why"] = ("only a CPU-PATH reading (F-B1) exists at this digest, and this bundle's manifest does not "
                            "say it proved off the GPU")
            unread.append(u)
    self_read = sorted(f for f, r in r26.items() if r["self_read"])
    return {"what": "every source pin the bundle declares: at the r19b frozen tree's digest (the tree v24 last "
                    "read), moved and read here (the gate round 26 readings by full digest, or W16_READINGS), or moved "
                    "and UNREAD; and the prover backend (F-B1)",
            "r19b_manifest": r19b_manifest, "r19b_manifest_found": bool(want), "pins": len(pins),
            "at_r19b": len(at_r19b), "at_r19b_files": at_r19b, "read_here": read_here, "unread": unread,
            "readings": {k: v[1] for k, v in W16_READINGS.items() if k in read_here and k not in r26},
            "readings_r26": r26,
            "self_read_pending_independent_check": self_read,
            "backend": backend,
            "range16_rs_pinned": any(p["file"] == "src/private_block/range16.rs" for p in pins),
            "ok": bool(want) and not unread and backend["admissible"]}


# ---------------------------------------------------------------- the driver
def _sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def tool_hashes() -> dict:
    out = {}
    for nm in sorted(os.listdir(HERE)):
        if nm.endswith(".py"):
            out[nm] = _sha(os.path.join(HERE, nm))
    return out


def default_r19b_manifest() -> str:
    d = HERE
    for _ in range(8):
        cand = os.path.join(d, "results", "zk60_token_io_r1_20261017", "manifest_final_r19b.sha256")
        if os.path.exists(cand):
            return cand
        d = os.path.dirname(d)
    return ""


def w16_gate(bundle_dir: str, controls=True, r19b_manifest=None) -> dict:
    from zk60_native_rg_block import load_bundle
    import zk60_native_rg_bundle as RB
    from zk60_native_rg_replay import RunReplay
    import zk60_native_rg_mask as M
    from zk60_native_rg_mcontrols import mask_controls_at_shape
    import zk60_native_rg_runpins as RP
    import zk60_native_run_gate as RG
    t0 = time.time()
    b = load_bundle(bundle_dir)
    rec = {"gate": "zk60-native-w16-gate", "version": 1, "staging": "v25", "privacy_property_established": False,
           "privacy_acceptance": False, "bundle": b.name, "bundle_dir": b.dir, "profile": b.profile,
           "what_this_is": "the first W16 items of the privacy gate on ONE one-block W16 run capture (test-only run "
                           "identity, synthetic public weights), at that run's real challenges; NOT a privacy statement"}
    parts = {}
    rec["W16-0 integrity"] = RB.integrity(b)
    parts["W16-0 integrity"] = bool(rec["W16-0 integrity"].get("ok"))
    try:
        facts = w16_facts(b)
        rec["W16-1/2 facts"] = facts
        parts["W16-1/2 facts"] = True
    except ValueError as exc:
        rec["W16-1/2 facts"] = {"refused": str(exc), "ok": False}
        rec.update({"status": "REFUSED", "parts": {"W16-1/2 facts": False}, "seconds": round(time.time() - t0, 1)})
        return rec
    rp = RunReplay(b).run()
    rec["W16-3 replay"] = rp.summary()
    parts["W16-3 replay"] = bool(rec["W16-3 replay"].get("ok"))
    rec["W16-4 layout"] = check_layout(b, facts)
    parts["W16-4 layout"] = rec["W16-4 layout"]["ok"]
    tabs = [check_tab_tables(b, facts, k) for k in range(b.blocks)]
    rec["W16-5 tab tables"] = {"per_stage": tabs, "ok": all(t["ok"] for t in tabs)}
    if controls:
        rec["W16-5 tab tables"]["control"] = tab_control(b, facts)
        rec["W16-5 tab tables"]["ok"] = rec["W16-5 tab tables"]["ok"] and rec["W16-5 tab tables"]["control"]["ok"]
    parts["W16-5 tab tables"] = rec["W16-5 tab tables"]["ok"]
    if parts["W16-3 replay"]:
        s3, _views = RG.stage3(b, rp, pad_rank=True, do_controls=controls,
                               terminal_note={"status": "the W16 slots' terminal identity is not ported (owed)"})
        rec["W16-6 per commitment"] = s3
        parts["W16-6 per commitment"] = bool(s3.get("ok"))
        stages = [M.mask_cfs_stage(b, rp, k) for k in range(b.blocks)]
        mc = {"per_stage": stages, "ok": all(s.get("ok") for s in stages),
              "entries_recomputed": sum((s.get("entries_recomputed") or {}).get("total", 0) for s in stages),
              "entries_differing": sum((s.get("entries_recomputed") or {}).get("differing", 0) for s in stages),
              "salted_leaves_authenticated": sum((s.get("entries_recomputed") or {}).get("salted_leaves_authenticated", 0) for s in stages)}
        if controls:
            mc["controls"] = mask_controls_at_shape(b, rp, k=0)
            mc["ok"] = bool(mc["ok"] and mc["controls"].get("ok", False))
        rec["W16-7 mask and CFS"] = mc
        parts["W16-7 mask and CFS"] = mc["ok"]
    else:
        parts["W16-6 per commitment"] = parts["W16-7 mask and CFS"] = False
    pins = classify_pins(b, r19b_manifest if r19b_manifest is not None else default_r19b_manifest())
    rec["PINS"] = pins
    rec["v24 pin tables (reported, not applied)"] = {
        "mask_layer": {kk: v for kk, v in M.check_mask_layer_pins(b).items() if kk in ("ok", "refusals", "accepted")},
        "run_layer": {kk: v for kk, v in RP.check_run_layer_pins(b).items() if kk in ("ok", "pins_that_moved")}}
    rec["parts"] = parts
    all_true = all(parts.values())
    v24_ok = all(v["ok"] for v in rec["v24 pin tables (reported, not applied)"].values())
    rec["status"] = ("W16-PASS" if all_true and pins["ok"] and v24_ok else "W16-DEV-PASS" if all_true else "NOT-OK")
    rec["status_means"] = {
        "W16-PASS": "every part true and every pin at an r19b digest or read here",
        "W16-DEV-PASS": "every part true, but some pin is unread or a v24 pin table refuses: computed figures, NOT "
                        "admissible evidence until the pins are read",
        "NOT-OK": "some part is false"}[rec["status"]]
    rec["not_here"] = ["T-0 terminal identity of the seven W16-redefined slots", "NL-1 S1-S5 on them",
                       "joint checks", "TS-1 and the claim census", "full preimage", "hash census",
                       "the reading of the unread pins"]
    # [2026-11-02] closed in the Rust tree by M26 (OWN_SOURCE_FILES gained
    # range16.rs); owed only for a bundle written before it
    if not pins["range16_rs_pinned"]:
        rec["not_here"].append("the recorder pinning range16.rs")
    rec["tool_sha256"] = tool_hashes()
    rec["seconds"] = round(time.time() - t0, 1)
    return rec


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name")
    ap.add_argument("--no-controls", action="store_true")
    ap.add_argument("--r19b-manifest")
    a = ap.parse_args(argv)
    rec = w16_gate(a.bundle, controls=not a.no_controls, r19b_manifest=a.r19b_manifest)
    os.makedirs(a.evidence, exist_ok=True)
    name = a.name or os.path.basename(os.path.normpath(a.bundle))
    path = os.path.join(a.evidence, f"w16-{name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
    for kk, v in rec.get("parts", {}).items():
        print(f"{kk}: {'PASS' if v else 'FAIL'}")
    pins = rec.get("PINS", {})
    print(f"pins: {pins.get('pins')} declared, {pins.get('at_r19b')} at r19b, {len(pins.get('read_here', []))} read here, "
          f"{len(pins.get('unread', []))} UNREAD: {[u['file'] for u in pins.get('unread', [])]}")
    print(f"status: {rec.get('status')} ({rec.get('seconds')} s) -> {path}")
    return 0 if rec.get("status") in ("W16-PASS", "W16-DEV-PASS") else 1


if __name__ == "__main__":
    raise SystemExit(main())
