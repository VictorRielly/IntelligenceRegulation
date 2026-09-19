#!/usr/bin/env python3
"""zk60_attention_pair_schedule.py -- the attention A / H / W pair schedule and its rank verdict.

Closes the two computations ZK60_OPUS_ATTENTION_INVENTORY.md section 8 left open:
  O-2  the rank verdict of the WHOLE attention A / H / W(P3) under a proposed pair schedule;
  O-1  whether ONE zero-sum construction covers all 19 LogUp helper-sum claims.

Reviewer: Claude Fable 5.1, 2026-09-16 session, worktree zk60-mvp-fable.  Analysis only:
stdlib Python, no Rust, no GPU, no proof executed.  Nothing here changes the P0 status of
attention at the source pin; the schedule is a DESIGN the rank tool evaluates.

INPUT.  Opus 5's machine-readable inventory (`results/zk60_opus_attention_inventory.json`,
`A1_schedule.claims`: 135 claim sites with commitment / symbolic point / group key /
data rows / role; `logup_tables`: the 10 multiplicity tables; `layout`).

WHAT IT BUILDS.
  1. The opening groups per commitment (block and receipt profile) by first occurrence of
     the group key (the last 8 point coordinates; None for sum claims), exactly
     `pcs::group_claims`' rule, and cross-checks them against the inventory's counts and
     member lists (A 39 / 41 groups, W 6, H 6; singletons A 17 / 19, W 6, H 1).
  2. FA3's schedule (ZK60_FABLE_MASK_REPAIR.md sections 2.1-2.4) applied to every site:
       - every plane claim site -> a `pair` (two fresh base rows re / im, claim coefficients
         (1 - e, e, e u)); FA3's rule keys on the MASK site (one row per claim), so a
         2-row or 8-row data plane still gets a pair -- its row bits weight the data rows
         (FA3 2.3 item 2), the pair's two rows are what make it Fp2-effective;
       - the 10 multiplicity histograms become committed A rows (`max(size, n) / n` rows
         each, the FFN's committed-table construction), masked by a `block` when rows >= 2
         and a `pair` when rows = 1 (FA2 U10), never published;
       - one `prox_pair` per commitment;
       - the two internal seam claims SeamXm8[0] / SeamZ16c[0] are their own group (g38)
         with a pair each (+4 A rows), aliasing the xm8 / z16c rows g13 opens at rho_D;
       - the 19 helper-SUM claims are REPLACED by one zero-sum row u in H (sum_j u[j] = 0),
         masked by the zero_sum_pair itself plus one fresh pair u' (FA2 14.5 / FA3 2.2's
         h_u / h_up generalised to 19 helper column pairs and 10 table-side helper pairs);
         the surviving data functional must be exactly the public LogUp identity;
       - the two bind_endpoints receipt claims are modelled both ways (pair-masked, and
         exempt / public by statement) and reported separately;
       - no collapse (the four collapse slots are absent: A03 / no-collapse).
     Two additions from the 2026-09-16 source extraction (coordinator): (a) section 1's three
     pointwise checks on clear claims (a2 = 2D - a1, a1 = l0 + 2^16 l1, a2 = l2 + 2^16 l3,
     attention.rs:2249-2251) become mu-batched terms of the section-2 zero-check, so section 2's
     terminal gains, per site, the sub-rows a1, a2 (packed sm slice) and l0..l3 (packed lm slice)
     at rho_2: 12 more single-row claim sites, a pair each (+24 A rows).  Under pcs::group_claims'
     key rule their tails collide pairwise (the section-1 g0-g7 pattern) into 8 two-member groups
     with the 4 existing rho_2 singletons; the forced-singleton reading is run as well (same
     verdict, same rows).  (b) The table side of the LogUp identity uses committed per-table helper
     rows g_T on H (Fp2-valued: re + im rows; pair if the table is one row at width 256, pair
     block otherwise), proven by the degree-1 relation g_T (alpha - t_T) - m_T = 0 in a TAB
     zero-check with its own terminals; u is the packed column-wise sum of the 19 helper columns
     minus the g_T rows, with its zero-sum pair and fresh pair.
  3. FA2's rank model (`scripts/zk60_fable_joint_rank.py`, imported by path, read-only) in
     repair form at seeded stand-in public coefficients: each group alone (vector + values +
     prox pair, n = 4 columns), each whole commitment per column at the REAL row structure
     (FA2's per-column compression: one column, every group vector entry, the proximity
     entry), and the whole commitment with values at small n (n = 4) with the multi-row
     histogram slots compressed to 2 rows (FA2's tiny-fixture convention).
  4. Negative controls (the tests run them).
  5. Row / byte cost per commitment by FA3 section 8's counting method.

THE MODEL AND ITS ASSUMPTIONS (FA2 sections 13 and 15, unchanged).  Every opening publishes
linear observations of committed base-field rows: group vector entries, the proximity
vector, terminal values.  With the public coefficients fixed (conditioned on), the data
part A and the mask part B are separated and `disclosed_dim = rank([A|B]) - rank(B)` is the
number of independent data functionals a verifier learns.  Assumed: masks and pads are
independent and uniform; challenges are stand-ins drawn from a seeded RNG that avoids the
base field (the 2^-64 degeneracies FA2 excludes); hashing / Merkle / salted leaves and the
CFS-masked sumcheck round messages are OUTSIDE the model (nonlinear); integer-range side
information and transcript conditioning are outside the model.  Numerical rank is not a
simulation proof.  The row-bit coordinates of every claim are taken from the inventory's
symbolic points (constants 0 / 1 and shared symbols map consistently), so the sm / lm
sub-block claims touch exactly the row they touch in source.

Usage:
    python3 scripts/zk60_attention_pair_schedule.py \
        --inventory results/zk60_opus_attention_inventory.json \
        --out results/zk60_private_attention_evidence/zk60_attention_pair_schedule.json \
        --schedule-out docs/zkmatrix-poc/zk60_private_attention_schedule.json [--seed N]
Exit status is nonzero on any expectation failure.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import sys
from typing import Dict, List, Optional, Sequence, Tuple

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name: str, filename: str):
    """Import a sibling script by file path (the `zk60_opus_io_capture.py` pattern)."""
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, filename))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


FA2 = _load("zk60_fable_joint_rank", "zk60_fable_joint_rank.py")
P = FA2.P
ONE, ZERO, U = FA2.ONE, FA2.ZERO, FA2.U
f2_add, f2_sub, f2_mul, f2_neg = FA2.f2_add, FA2.f2_sub, FA2.f2_mul, FA2.f2_neg
Fp2 = Tuple[int, int]

# the fixed A00 / B3 profile (inventory `profile` / `layout`)
N_COLS = 256
LOG_N = 8
Q_PAD = 256
INV_RATE = 8
BYTES_PER_ROW = N_COLS * 8 * (1 + INV_RATE) + Q_PAD * 8  # FA3 section 8: data + full coset encoding + Q host pads
TABLE_SPACE_LOG = 16  # the table slots are embedded in a 2^16 space (FA2: ext_k = 16 - log2(rows * n))
DEFAULT_SEED = 2026
COMMITMENTS = ("A", "H", "W")
ROWS_TODAY = {"A": 108, "H": 106, "W": 4}
EXPECTED_GROUPS = {"block": {"A": 39, "H": 6, "W": 6}, "receipt": {"A": 41, "H": 6, "W": 6}}
EXPECTED_SINGLETONS = {"block": {"A": 17, "H": 1, "W": 6}, "receipt": {"A": 19, "H": 1, "W": 6}}
EXPECTED_CLAIMS = {"block": 133, "receipt": 135}
RECEIPT_SECTION_PREFIX = "E external I/O binding"
SEAM_SECTION_PREFIX = "S internal FFN seam"
# sumcheck sections whose terminal claims multiply TWO private factors already under P1
# (score, PV: eq_g == 1 at KV heads = 1, inventory section 0 finding 3 / R7)
BILINEAR_SECTIONS = ("10 GQA score product", "11 probability value product")
# sections whose terminal claims gain the second extension only when the weights are private (P3)
WEIGHT_MATMUL_SECTIONS = ("9 QKV projections", "12 output projection")


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


# ----------------------------------------------------------------------------
# 1. the inventory and the opening groups
# ----------------------------------------------------------------------------


def load_inventory(path: str) -> dict:
    with open(path) as f:
        inv = json.load(f)
    claims = inv["A1_schedule"]["claims"]
    if len(claims) != EXPECTED_CLAIMS["receipt"]:
        raise ValueError(f"inventory has {len(claims)} claims, expected {EXPECTED_CLAIMS['receipt']}")
    for i, c in enumerate(claims):
        if c["index"] != i:
            raise ValueError(f"claim {i} carries index {c['index']}")
    return inv


def claim_rows(c: dict) -> int:
    """Committed rows a claim's slice spans: 2^(log_size - 8) (inventory section 2.2)."""
    return 1 << (c["log_size"] - LOG_N)


def claims_for_profile(inv: dict, profile: str) -> List[dict]:
    """Block profile: the 133 claims of the block path; receipt: + the 2 bind_endpoints claims."""
    out = []
    for c in inv["A1_schedule"]["claims"]:
        if profile == "block" and c["section"].startswith(RECEIPT_SECTION_PREFIX):
            continue
        d = dict(c)
        d["rows"] = claim_rows(c)
        if d["rows"] != c["data_rows"]:
            raise ValueError(f"claim {c['index']}: data_rows {c['data_rows']} != 2^(log_size-8) = {d['rows']}")
        d["row0"] = c["offset"] // N_COLS
        d["row_bits"] = [] if c["sum_claim"] else list(c["point"][: c["log_size"] - LOG_N])
        d["tail"] = None if c["sum_claim"] else list(c["point"][c["log_size"] - LOG_N:])
        if d["tail"] is not None and d["tail"] != c["group_key"]:
            raise ValueError(f"claim {c['index']}: tail != group_key")
        out.append(d)
    if len(out) != EXPECTED_CLAIMS[profile]:
        raise ValueError(f"{profile}: {len(out)} claims, expected {EXPECTED_CLAIMS[profile]}")
    return out


def build_groups(claims: Sequence[dict]) -> Dict[str, List[dict]]:
    """`pcs::group_claims`: key = the last 8 point coordinates (None for a sum claim), groups in
    first-occurrence order per commitment.  Reproduces the inventory's numbering because the
    inventory lists the claims in transcript order."""
    by_index = {c["index"]: c for c in claims}
    groups: Dict[str, List[dict]] = {cm: [] for cm in COMMITMENTS}
    where: Dict[Tuple[str, Optional[Tuple[str, ...]]], int] = {}
    for c in claims:
        key = None if c["sum_claim"] else tuple(c["group_key"])
        k = (c["commitment"], key)
        if k not in where:
            where[k] = len(groups[c["commitment"]])
            groups[c["commitment"]].append({"group": where[k], "commitment": c["commitment"], "key": None if key is None else list(key), "sum_group": key is None, "members": []})
        groups[c["commitment"]][where[k]]["members"].append(c["index"])
    for cm, gl in groups.items():
        for g in gl:
            mem = [by_index[i] for i in g["members"]]
            g["m"] = len(mem)
            g["sites"] = sorted(c["site"] for c in mem)
            g["data_rows"] = [c["rows"] for c in mem]
            g["singleton"] = g["m"] == 1
            g["sections"] = sorted({c["section"] for c in mem})
            g["seam"] = all(c["section"].startswith(SEAM_SECTION_PREFIX) for c in mem)
            g["receipt_endpoint"] = all(c["section"].startswith(RECEIPT_SECTION_PREFIX) for c in mem)
    return groups


def cross_check_groups(groups: Dict[str, List[dict]], inv: dict, profile: str) -> dict:
    """Group counts, member sets, keys and singleton counts against the inventory's record."""
    ref = inv["A1_schedule"][f"opening_groups_{profile}_profile"]
    checks = {}
    for cm in COMMITMENTS:
        mine = groups[cm]
        checks[f"{cm}_group_count"] = {"got": len(mine), "expected": EXPECTED_GROUPS[profile][cm], "inventory": len(ref[cm]), "pass": len(mine) == EXPECTED_GROUPS[profile][cm] == len(ref[cm])}
        same = len(mine) == len(ref[cm]) and all(sorted(g["members"]) == sorted(r["members"]) and g["key"] == r["key"] and g["sum_group"] == r["sum_group"] for g, r in zip(mine, ref[cm]))
        checks[f"{cm}_members_and_keys_equal_inventory"] = {"pass": same}
        ns = sum(1 for g in mine if g["singleton"])
        checks[f"{cm}_singleton_groups"] = {"got": ns, "expected": EXPECTED_SINGLETONS[profile][cm], "pass": ns == EXPECTED_SINGLETONS[profile][cm]}
    sum_groups = [g for g in groups["H"] if g["sum_group"]]
    checks["H_one_sum_group_of_19"] = {"got": [g["m"] for g in sum_groups], "pass": len(sum_groups) == 1 and sum_groups[0]["m"] == 19}
    counts = inv["A1_schedule"][f"claim_counts_{profile}_profile"]
    got = {"A": sum(g["m"] for g in groups["A"]), "W": sum(g["m"] for g in groups["W"]), "H_eval": sum(g["m"] for g in groups["H"] if not g["sum_group"]), "H_sum": sum(g["m"] for g in groups["H"] if g["sum_group"])}
    got["total"] = got["A"] + got["W"] + got["H_eval"] + got["H_sum"]
    checks["claim_counts"] = {"got": got, "inventory": counts, "pass": all(got[k] == counts[k] for k in got)}
    seam = [g for g in groups["A"] if g["seam"]]
    checks["A_seam_group"] = {"got": [g["sites"] for g in seam], "pass": len(seam) == 1 and seam[0]["m"] == 2 and seam[0]["group"] == 38}
    checks["all_pass"] = all(v["pass"] for k, v in checks.items() if k != "all_pass")
    return checks


# ----------------------------------------------------------------------------
# 2. the schedule (FA3 sections 2.1-2.4 applied to every attention site)
# ----------------------------------------------------------------------------

ADDED_SOURCE = "attention.rs:2249-2251 (coordinator source extraction 2026-09-16: section 1's pointwise checks a2 = 2D - a1, a1 = l0 + 2^16 l1, a2 = l2 + 2^16 l3 become mu-batched terms of the section-2 zero-check on the T-row domain)"
ADDED_SECTION = "2 norm squares (added: section-1 pointwise checks mu-batched)"
SM_OFFSET, LM_OFFSET = 26624, 27136
SUB_BLOCK_BITS = {"D": ("0", "0"), "Dsq": ("0", "1"), "a1": ("1", "0"), "a2": ("1", "1")}


def added_sites(first_index: int = 200, force_singletons: bool = False) -> List[dict]:
    """The 12 sub-row claim sites section 2 gains at rho_2 (= rho_Dsq): per site s the length-T
    sub-rows a1, a2 (packed sm slice) and l0..l3 (packed lm slice).  Point convention mirrors the
    inventory's sm / lm claims: sm[X site s] -> row bit s, tail (1 - s, x1, x0, rho_Dsq[0..4]);
    lm[limb k site s] -> row bit 0, tail (s, k1, k0, rho_Dsq[0..4]).  Under pcs::group_claims'
    key rule these tails COLLIDE pairwise (the section-1 g0-g7 pattern); `force_singletons`
    appends a synthetic marker so each site is its own group (the coordinator's reading)."""
    out = []
    idx = first_index
    rho = [f"rho_Dsq[{i}]" for i in range(5)]
    for s in ("0", "1"):
        one_minus_s = "1" if s == "0" else "0"
        for x in ("a1", "a2"):
            x1, x0 = SUB_BLOCK_BITS[x]
            tail = [one_minus_s, x1, x0] + rho
            out.append({"index": idx, "commitment": "A", "site": f"sm[{x} site {s}] @ rho_2", "offset": SM_OFFSET, "log_size": 9, "data_rows": 2, "parts": 1, "sum_claim": False,
                        "point": [s] + tail, "group_key": tail + ([f"#added{idx}"] if force_singletons else []), "role": "terminal (added sub-row site)", "section": ADDED_SECTION, "source": ADDED_SOURCE, "added": True})
            idx += 1
        for k in range(4):
            k1, k0 = str(k >> 1), str(k & 1)
            tail = [s, k1, k0] + rho
            out.append({"index": idx, "commitment": "A", "site": f"lm[limb {k} site {s}] @ rho_2", "offset": LM_OFFSET, "log_size": 9, "data_rows": 2, "parts": 1, "sum_claim": False,
                        "point": ["0"] + tail, "group_key": tail + ([f"#added{idx}"] if force_singletons else []), "role": "terminal (added sub-row site)", "section": ADDED_SECTION, "source": ADDED_SOURCE, "added": True})
            idx += 1
    assert len(out) == 12
    return out


def with_added(claims: Sequence[dict], force_singletons: bool = False) -> List[dict]:
    out = [dict(c) for c in claims]
    for c in added_sites(force_singletons=force_singletons):
        d = dict(c)
        d["rows"] = claim_rows(c)
        d["row0"] = c["offset"] // N_COLS
        d["row_bits"] = list(c["point"][: c["log_size"] - LOG_N])
        d["tail"] = list(c["point"][c["log_size"] - LOG_N:])
        out.append(d)
    return out


def tables_from_inventory(inv: dict) -> List[dict]:
    """The 10 multiplicity tables in the inventory's order: rows = max(size, n) / n (the
    inventory's `mask_block_rows_if_hidden`), FA3 kind pair iff rows = 1, and the shared-rho_tab
    extension prefix ext_k = 16 - log2(rows * n) (FA2's convention)."""
    out = []
    for t in inv["A1_schedule"]["logup_tables"]:
        rows = int(t["mask_block_rows_if_hidden"])
        expect = max(int(t["table_rows"]), N_COLS) // N_COLS
        if rows != expect:
            raise ValueError(f"table {t['table']}: rows {rows} != max(size, n)/n = {expect}")
        if rows & (rows - 1):
            raise ValueError(f"table {t['table']}: rows {rows} not a power of two")
        kind = "pair" if rows == 1 else "block"
        if not t["mask_kind_under_FA3_rule"].startswith(kind):
            raise ValueError(f"table {t['table']}: inventory kind {t['mask_kind_under_FA3_rule']} vs {kind}")
        out.append({"table": t["table"], "size": int(t["table_rows"]), "required_total": int(t["required_total"]), "rows": rows, "kind": kind, "ext_k": TABLE_SPACE_LOG - (rows * N_COLS).bit_length() + 1})
    if len(out) != 10:
        raise ValueError(f"{len(out)} tables, expected 10")
    return out


def h_row_ranges(c: dict) -> Tuple[List[int], List[int]]:
    """An H helper pair occupies re rows then im rows (inventory offsets: h_d[k] at k * 1024 =
    4 rows, h_kv at 512 = 2 rows, h_s at 4096 = 16 rows, h_lm at 512 = 2 rows)."""
    re = list(range(c["row0"], c["row0"] + c["rows"]))
    im = list(range(c["row0"] + c["rows"], c["row0"] + 2 * c["rows"]))
    return re, im


def coefficient_forms(section: str, is_w: bool) -> Dict[str, str]:
    """The claim coefficient pair per privacy mode (FA2 `masked_coefs`; FA3 2.1 pair form)."""
    pair_p1 = "(k0, k1, k1 u) = ((1 - e), e, e u) on (data slice at p, R_re at tail p, R_im at tail p)"
    pair_p3 = "((1 - e2)(1 - e), (1 - e2) e, (1 - e2) e u): second extension round (private x private)"
    if section.startswith(BILINEAR_SECTIONS):
        return {"P1": pair_p3 + " -- needed already under P1 (eq_g == 1 at KV heads = 1, inventory R7)", "P3": pair_p3}
    if section.startswith(WEIGHT_MATMUL_SECTIONS):
        if is_w:
            return {"P1": "public weights: plain opening, no mask (approved root, FA4 section 2)", "P3": pair_p3}
        return {"P1": pair_p1, "P3": pair_p3}
    if is_w:
        return {"P1": "public weights: plain opening, no mask (approved root, FA4 section 2)", "P3": pair_p1}
    return {"P1": pair_p1, "P3": pair_p1}


def e_kind(section: str, p3: bool) -> str:
    if section.startswith(BILINEAR_SECTIONS):
        return "p3"
    if p3 and section.startswith(WEIGHT_MATMUL_SECTIONS):
        return "p3"
    return "p1"


def build_schedule(inv: dict, profile: str, endpoints: str = "pair", force_singletons: bool = False) -> dict:
    """The schedule for one profile ('block' | 'receipt') and, on the receipt path, one
    endpoints mode ('pair' | 'exempt').  Returns the site tables per commitment with the mask
    row indices appended after the data rows, the groups, the extra roles and the row counts."""
    assert profile in ("block", "receipt") and endpoints in ("pair", "exempt")
    inv_claims = claims_for_profile(inv, profile)
    claims = with_added(inv_claims, force_singletons=force_singletons)
    groups = build_groups(claims)
    tables = tables_from_inventory(inv)
    by_index = {c["index"]: c for c in claims}
    gid = {}
    for cm in COMMITMENTS:
        for g in groups[cm]:
            for i in g["members"]:
                gid[i] = g
    # data rows opened by more than one site (aliasing; FA2 U12)
    rows_of = {}
    for c in claims:
        if c["sum_claim"]:
            continue
        key = (c["commitment"], c["row0"], c["rows"])
        rows_of.setdefault(key, []).append(c["index"])
    sched = {"profile": profile, "endpoints_mode": endpoints, "added_sites_forced_singleton_groups": force_singletons, "tables": tables, "commitments": {}}
    # ---- A ---------------------------------------------------------------------
    a_sites = []
    next_row = ROWS_TODAY["A"]
    hist_data = []
    for t in tables:
        hist_data.append({"table": t["table"], "data_rows": list(range(next_row, next_row + t["rows"]))})
        next_row += t["rows"]
    a_hist_data_end = next_row
    a_claims = [c for c in claims if c["commitment"] == "A" and not c["section"].startswith(RECEIPT_SECTION_PREFIX)]
    a_endpoints = [c for c in claims if c["commitment"] == "A" and c["section"].startswith(RECEIPT_SECTION_PREFIX)]
    for c in a_claims:
        g = gid[c["index"]]
        a_sites.append({"role": f"A#{c['index']}", "claim_index": c["index"], "commitment": "A", "site": c["site"], "group": g["group"], "group_key": g["key"], "m": g["m"],
                        "data_rows": c["rows"], "data_row_range": [c["row0"], c["row0"] + c["rows"]], "row_bits": c["row_bits"], "single_row": c["rows"] == 1,
                        "mask_kind": "pair", "mask_rows": [next_row, next_row + 1], "coefficients": coefficient_forms(c["section"], False),
                        "proof_field": f"AttnProof.vals[{c['index']}] today (clear) -> masked terminal (1 - e) fin + e (R_re~ + u R_im~) via MaskPoint::eval2" if not c.get("added") else "new masked terminal of the section-2 zero-check (added site)",
                        "section": c["section"], "source": c["source"], "seam": c["section"].startswith(SEAM_SECTION_PREFIX), "added": bool(c.get("added")),
                        "aliases": [f"A#{i}" for i in rows_of[("A", c["row0"], c["rows"])] if i != c["index"]]})
        next_row += 2
    a_pairs_end = next_row
    hist_masks = []
    for t, hd in zip(tables, hist_data):
        n_mask = 2 if t["kind"] == "pair" else t["rows"]
        hist_masks.append({"role": f"tab[{t['table']}].a_mult", "table": t["table"], "commitment": "A", "group": "tab", "group_key": f"tail(rho_tab) (one group for all 10 slots; slot point rho_tab[{t['ext_k']}..])", "m": 10,
                           "data_rows": t["rows"], "data_row_range": [hd["data_rows"][0], hd["data_rows"][-1] + 1], "single_row": t["rows"] == 1, "mask_kind": t["kind"],
                           "mask_rows": list(range(next_row, next_row + n_mask)),
                           "coefficients": {"P1": "((1 - e_tab) ext_i, e_tab ext_i) on (slot rows, mask rows) at rho_tab[k_i..]" if t["kind"] == "block" else "((1 - e_tab) ext_i, e_tab ext_i, e_tab ext_i u): pair with the same point and ext factor", "P3": "unchanged"},
                           "proof_field": f"tab_term[2 i] (masked); the histogram itself is NEVER published (today AttnProof.mults, {t['required_total']} lookups)", "size": t["size"], "ext_k": t["ext_k"]})
        next_row += n_mask
    a_hist_masks_end = next_row
    a_prox = {"role": "a_prox", "commitment": "A", "mask_kind": "prox_pair", "mask_rows": [next_row, next_row + 1], "group_key": "(proximity vector)", "coefficients": {"P1": "rho_prox[re], rho_prox[im] drawn by zk_rhos, Fp-independent", "P3": "unchanged"}, "proof_field": "a_open.prox_vec"}
    next_row += 2
    a_block_rows = next_row
    endpoint_sites = []
    for c in a_endpoints:
        g = gid[c["index"]]
        site = {"role": f"A#{c['index']}", "claim_index": c["index"], "commitment": "A", "site": c["site"], "group": g["group"], "group_key": g["key"], "m": g["m"], "data_rows": c["rows"], "data_row_range": [c["row0"], c["row0"] + c["rows"]], "row_bits": c["row_bits"], "single_row": c["rows"] == 1,
                "section": c["section"], "source": c["source"], "receipt_only": True, "aliases": [f"A#{i}" for i in rows_of[("A", c["row0"], c["rows"])] if i != c["index"]]}
        if endpoints == "pair":
            site.update({"mask_kind": "pair", "mask_rows": [next_row, next_row + 1], "coefficients": coefficient_forms(c["section"], False), "proof_field": f"AttnProof.vals[{c['index']}] -> masked terminal"})
            next_row += 2
        else:
            site.update({"mask_kind": "none (exempt: binds a PUBLIC boundary tensor declared by the statement; inventory O-6, product ruling)", "mask_rows": [], "coefficients": {"P1": "(1) plain evaluation", "P3": "(1) plain evaluation"}, "proof_field": f"AttnProof.vals[{c['index']}] (clear, public by statement)"})
        endpoint_sites.append(site)
    sched["commitments"]["A"] = {"data_rows_today": ROWS_TODAY["A"], "histogram_data_rows": hist_data, "histogram_data_rows_total": a_hist_data_end - ROWS_TODAY["A"], "sites": a_sites + endpoint_sites, "histogram_masks": hist_masks, "prox": a_prox,
                                 "groups": groups["A"], "rows_block": a_block_rows, "rows_total": next_row, "seam_sites": [s["role"] for s in a_sites if s["seam"]], "added_sites": [s["role"] for s in a_sites if s["added"]],
                                 "regions": {"data_today": [0, ROWS_TODAY["A"]], "histogram_data": [ROWS_TODAY["A"], a_hist_data_end], "claim_pairs": [a_hist_data_end, a_pairs_end], "histogram_masks": [a_pairs_end, a_hist_masks_end], "prox_pair": a_prox["mask_rows"], "receipt_endpoint_pairs": [a_block_rows, next_row]}}
    # ---- H ---------------------------------------------------------------------
    h_sites = []
    next_row = ROWS_TODAY["H"]
    gt = []
    for t in tables:
        gt.append({"table": t["table"], "re_rows": list(range(next_row, next_row + t["rows"])), "im_rows": list(range(next_row + t["rows"], next_row + 2 * t["rows"]))})
        next_row += 2 * t["rows"]
    h_gt_data_end = next_row
    h_eval = [c for c in claims if c["commitment"] == "H" and not c["sum_claim"]]
    h_sums = [c for c in claims if c["commitment"] == "H" and c["sum_claim"]]
    for c in h_eval:
        g = gid[c["index"]]
        re, im = h_row_ranges(c)
        h_sites.append({"role": f"H#{c['index']}", "claim_index": c["index"], "commitment": "H", "site": c["site"], "group": g["group"], "group_key": g["key"], "m": g["m"], "data_rows": c["rows"], "data_row_range_re": [re[0], re[-1] + 1], "data_row_range_im": [im[0], im[-1] + 1], "row_bits": c["row_bits"], "single_row": c["rows"] == 1,
                        "mask_kind": "pair (Fp2 helper plane: data (re, im) with an Fp2 mask pair; FA3 h_mf / h_md, unchanged form)", "mask_rows": [next_row, next_row + 1], "coefficients": {"P1": "(1 - e, e): parts (h_re, (1-e), p), (h_im, (1-e) u, p), (R_re, e, tail p), (R_im, e u, tail p)", "P3": "unchanged"},
                        "proof_field": f"AttnProof.vals[{c['index']}] today -> masked helper terminal", "section": c["section"], "source": c["source"]})
        next_row += 2
    h_pairs_end = next_row
    h_u = {"role": "h_u", "commitment": "H", "mask_kind": "zero_sum_pair", "mask_rows": [next_row, next_row + 1], "group_key": "rho_zs (the zsum claim) and the value-0 LogUp sum claim (empty point, all-ones column weights)",
           "coefficients": {"P1": "LogUp sum vector v_sum[j] = sum_h h[j] - sum_T g_T[j] + u[j] (all-ones weights; public value 0); zsum: ((1 - e_zs), e_zs, e_zs u) on (u, u'_re, u'_im)", "P3": "unchanged"},
           "proof_field": "the constant 0 (LogUp identity) and zs_term", "replaces": [f"H#{c['index']}" for c in h_sums],
           "construction": "u = (u_re, u_im) fresh with sum_j u_re[j] = sum_j u_im[j] = 0, added to the packed column-wise sum of the 19 helper columns minus the 10 g_T rows (the FFN's h_u packing); its zero sum is proven by the zsum claim at rho_zs masked by the fresh pair h_up (FA2 14.5 / FA3 2.2 generalised to 19 + 10 planes)"}
    next_row += 2
    h_up = {"role": "h_up", "commitment": "H", "mask_kind": "pair", "mask_rows": [next_row, next_row + 1], "group_key": "rho_zs", "coefficients": {"P1": "(e_zs, e_zs u) on the zsum claim", "P3": "unchanged"}, "proof_field": "zs_term"}
    next_row += 2
    gt_sites = []
    for t, g_ in zip(tables, gt):
        n_mask = 2 * t["rows"]
        gt_sites.append({"role": f"tab[{t['table']}].g_T", "table": t["table"], "commitment": "H", "group": "TAB", "group_key": f"tail(rho_tab) (the TAB zero-check terminal; slot point rho_tab[{t['ext_k']}..])", "m": 10, "data_rows": t["rows"], "data_row_range_re": [g_["re_rows"][0], g_["re_rows"][-1] + 1], "data_row_range_im": [g_["im_rows"][0], g_["im_rows"][-1] + 1], "single_row": t["rows"] == 1,
                         "mask_kind": "pair" if t["kind"] == "pair" else "pair block (2 rows_T: re block + im block, eq row weights of rho_tab's row bits)", "mask_rows": list(range(next_row, next_row + n_mask)),
                         "coefficients": {"P1": "((1 - e_tab) ext_T, e_tab ext_T) with the u factor on the im parts", "P3": "unchanged"}, "proof_field": "tab_term[2 T + 1]: the TAB zero-check terminal of the degree-1 relation g_T (alpha - t_T) - m_T = 0", "ext_k": t["ext_k"]})
        next_row += n_mask
    h_gt_masks_end = next_row
    h_prox = {"role": "h_prox", "commitment": "H", "mask_kind": "prox_pair", "mask_rows": [next_row, next_row + 1], "group_key": "(proximity vector)", "proof_field": "h_open.prox_vec"}
    next_row += 2
    sched["commitments"]["H"] = {"data_rows_today": ROWS_TODAY["H"], "g_T_data_rows": gt, "g_T_data_rows_total": h_gt_data_end - ROWS_TODAY["H"], "sites": h_sites, "h_u": h_u, "h_up": h_up, "g_T_sites": gt_sites, "prox": h_prox, "groups": groups["H"],
                                 "replaced_sum_claims": [{"role": f"H#{c['index']}", "site": c["site"], "claim_index": c["index"]} for c in h_sums], "rows_total": next_row,
                                 "regions": {"data_today": [0, ROWS_TODAY["H"]], "g_T_data": [ROWS_TODAY["H"], h_gt_data_end], "helper_pairs": [h_gt_data_end, h_pairs_end], "h_u": h_u["mask_rows"], "h_up": h_up["mask_rows"], "g_T_masks": [h_up["mask_rows"][1] + 1, h_gt_masks_end], "prox_pair": h_prox["mask_rows"]}}
    # ---- W ---------------------------------------------------------------------
    w_sites = []
    next_row = ROWS_TODAY["W"]
    for c in [c for c in claims if c["commitment"] == "W"]:
        g = gid[c["index"]]
        w_sites.append({"role": f"W#{c['index']}", "claim_index": c["index"], "commitment": "W", "site": c["site"], "group": g["group"], "group_key": g["key"], "m": g["m"], "data_rows": c["rows"], "data_row_range": [c["row0"], c["row0"] + c["rows"]], "row_bits": c["row_bits"], "single_row": True,
                        "mask_kind": "pair (P3 only; P1 opens W plain)", "mask_rows": [next_row, next_row + 1], "coefficients": coefficient_forms(c["section"], True), "proof_field": f"AttnProof.vals[{c['index']}] today -> masked terminal under P3", "section": c["section"], "source": c["source"]})
        next_row += 2
    w_prox = {"role": "w_prox", "commitment": "W", "mask_kind": "prox_pair (P3 only)", "mask_rows": [next_row, next_row + 1], "group_key": "(proximity vector)", "proof_field": "w_open_zk.prox_vec"}
    next_row += 2
    sched["commitments"]["W"] = {"data_rows_today": ROWS_TODAY["W"], "sites": w_sites, "prox": w_prox, "groups": groups["W"], "rows_total_P3": next_row, "rows_total_P1": ROWS_TODAY["W"]}
    sched["groups"] = groups
    sched["claims"] = claims
    sched["inventory_claims"] = inv_claims
    return sched


def schedule_coverage_checks(sched: dict) -> dict:
    """Every claim covered exactly once; mask rows pairwise disjoint and above the data rows;
    every mask row index below the commitment's row total."""
    checks = {}
    claims = sched["claims"]
    covered = {}
    for cm in COMMITMENTS:
        for s in sched["commitments"][cm]["sites"]:
            covered[s["claim_index"]] = covered.get(s["claim_index"], 0) + 1
    for r in sched["commitments"]["H"]["replaced_sum_claims"]:
        covered[r["claim_index"]] = covered.get(r["claim_index"], 0) + 1
    checks["every_claim_covered_exactly_once"] = {"pass": all(covered.get(c["index"], 0) == 1 for c in claims) and len(covered) == len(claims), "claims": len(claims), "covered": len(covered)}
    for cm in COMMITMENTS:
        entry = sched["commitments"][cm]
        rows = []
        for s in entry["sites"]:
            rows += s["mask_rows"]
        for key in ("histogram_masks", "g_T_sites"):
            for s in entry.get(key, []):
                rows += s["mask_rows"]
        for key in ("prox", "h_u", "h_up"):
            if key in entry:
                rows += entry[key]["mask_rows"]
        data_end = {"A": ROWS_TODAY["A"] + entry.get("histogram_data_rows_total", 0), "H": ROWS_TODAY["H"] + entry.get("g_T_data_rows_total", 0), "W": ROWS_TODAY["W"]}[cm]
        total = entry.get("rows_total", entry.get("rows_total_P3"))
        checks[f"{cm}_mask_rows_disjoint_and_after_data"] = {"pass": len(rows) == len(set(rows)) and all(data_end <= r < total for r in rows), "mask_rows": len(rows), "data_rows": data_end, "rows_total": total}
    checks["all_pass"] = all(v["pass"] for k, v in checks.items() if k != "all_pass")
    return checks


def row_cost(sched: dict) -> dict:
    """FA3 section 8's counting: rows per commitment today vs under the schedule, bytes per extra row
    = n * 8 * (1 + inv_rate) + Q * 8 at this profile (256 columns, rate 8, Q = 256)."""
    A, H, W = (sched["commitments"][k] for k in COMMITMENTS)
    a_sites = [s for s in A["sites"] if not s.get("receipt_only")]
    a_ep = [s for s in A["sites"] if s.get("receipt_only")]
    a = {"today": ROWS_TODAY["A"],
         "claim_pairs_inventory": 2 * sum(1 for s in a_sites if not s["added"] and not s["seam"]),
         "claim_pairs_added_sub_row_sites": 2 * sum(1 for s in a_sites if s["added"]),
         "seam_pairs": 2 * sum(1 for s in a_sites if s["seam"]),
         "receipt_endpoint_pairs": 2 * sum(1 for s in a_ep if s["mask_kind"] == "pair"),
         "prox_pair": 2,
         "histogram_data_rows": A["histogram_data_rows_total"],
         "histogram_mask_rows": sum(len(s["mask_rows"]) for s in A["histogram_masks"]),
         "histogram_single_row_slots_paired": sum(1 for s in A["histogram_masks"] if s["mask_kind"] == "pair")}
    a["extra_rows"] = a["claim_pairs_inventory"] + a["claim_pairs_added_sub_row_sites"] + a["seam_pairs"] + a["receipt_endpoint_pairs"] + a["prox_pair"] + a["histogram_data_rows"] + a["histogram_mask_rows"]
    a["rows"] = a["today"] + a["extra_rows"]
    assert a["rows"] == A["rows_total"], (a, A["rows_total"])
    h = {"today": ROWS_TODAY["H"], "today_has_masks": False,
         "helper_pairs": 2 * len(H["sites"]), "h_u_zero_sum_pair": 2, "h_up_fresh_pair": 2, "prox_pair": 2,
         "g_T_data_rows": H["g_T_data_rows_total"], "g_T_mask_rows": sum(len(s["mask_rows"]) for s in H["g_T_sites"]),
         "sum_claims_replaced": len(H["replaced_sum_claims"])}
    h["extra_rows"] = h["helper_pairs"] + h["h_u_zero_sum_pair"] + h["h_up_fresh_pair"] + h["prox_pair"] + h["g_T_data_rows"] + h["g_T_mask_rows"]
    h["rows"] = h["today"] + h["extra_rows"]
    assert h["rows"] == H["rows_total"]
    w = {"today": ROWS_TODAY["W"], "P1_rows": ROWS_TODAY["W"], "P1_extra_rows": 0, "P3_claim_pairs": 2 * len(W["sites"]), "P3_prox_pair": 2}
    w["P3_extra_rows"] = w["P3_claim_pairs"] + w["P3_prox_pair"]
    w["P3_rows"] = w["today"] + w["P3_extra_rows"]
    assert w["P3_rows"] == W["rows_total_P3"]
    for d in (a, h):
        d["extra_bytes"] = d["extra_rows"] * BYTES_PER_ROW
    w["P3_extra_bytes"] = w["P3_extra_rows"] * BYTES_PER_ROW
    return {"profile": sched["profile"], "endpoints_mode": sched["endpoints_mode"], "bytes_per_row": BYTES_PER_ROW, "A": a, "H": h, "W": w,
            "A_plus_H_extra_bytes": a["extra_bytes"] + h["extra_bytes"],
            "method": "FA3 section 8: rows counted from the schedule; bytes per extra row = n * 8 * (1 + inv_rate) + Q * 8 (data + full coset encoding + host pads); salts and Merkle trees are per column and unchanged; proof size grows per GROUP (group vectors), not per row",
            "alternative_tables_all_pairs_extra_A_rows": sum(t["rows"] for t in sched["tables"] if t["kind"] == "block"),
            "alternative_multi_row_planes_as_base_blocks_extra_A_rows": sum(s["data_rows"] - 2 for s in a_sites if s["data_rows"] > 2)}


# ----------------------------------------------------------------------------
# 3. the rank model: FA2's Model with the schedule's structure
# ----------------------------------------------------------------------------


class Symbols:
    """Symbolic point coordinates -> stand-in Fp2 values, consistent per symbol ('rho_Q[6]' and
    '1-rho_Q[6]' are tied; '0' / '1' are the constants)."""

    def __init__(self, rng: "FA2.Rng"):
        self.rng = rng
        self.cache: Dict[str, Fp2] = {}

    def val(self, s: str) -> Fp2:
        if s == "0":
            return ZERO
        if s == "1":
            return ONE
        if s.startswith("1-"):
            return f2_sub(ONE, self.val(s[2:]))
        if s not in self.cache:
            self.cache[s] = self.rng.fp2()
        return self.cache[s]


class Builder:
    """Builds an FA2 `Model` of one commitment over `n_cols` columns (n_cols = 1: FA2's
    per-column compression -- every group vector entry and the proximity entry, no values;
    n_cols = 4 / 8 with `with_values`: + every terminal value with random column weights).
    Member kinds: 'pair' (base data rows, Fp2 mask pair), 'block' (base data rows, base mask
    block with the same row weights), 'base1' (legacy: one base mask row), 'none' (no mask),
    'fp2pair' / 'fp2block' (Fp2-valued H planes with an Fp2 mask pair / pair block)."""

    def __init__(self, name: str, n_cols: int, rng: "FA2.Rng", symbols: Symbols, with_values: bool, notes: Optional[List[str]] = None):
        self.model = FA2.Model(name, notes or [])
        self.n = n_cols
        self.log_n = n_cols.bit_length() - 1
        assert 1 << self.log_n == n_cols
        self.rng, self.sym, self.with_values = rng, symbols, with_values
        self.rows: List[str] = []
        self.is_data: Dict[str, bool] = {}
        self.u_rows: Optional[Tuple[str, str]] = None  # the zero-sum pair (substituted last column)
        self.groups_added = 0

    # unknowns ---------------------------------------------------------------
    def unk(self, row: str, is_data: bool) -> None:
        if row in self.is_data:
            assert self.is_data[row] == is_data, row
            return
        self.is_data[row] = is_data
        self.rows.append(row)
        for j in range(self.n):
            (self.model.data_unknown if is_data else self.model.mask_unknown)(f"{row}[{j}]")

    def eq(self, row_bits: Optional[Sequence[str]], nrows: int) -> List[Fp2]:
        rb = nrows.bit_length() - 1
        assert 1 << rb == nrows, nrows
        if row_bits is None:
            return FA2.eq_table_msb(self.rng.point(rb))
        assert len(row_bits) == rb, (row_bits, nrows)
        return FA2.eq_table_msb([self.sym.val(s) for s in row_bits])

    def member_terms(self, mem: dict, a: Fp2, c: Fp2) -> List[Tuple[str, Fp2]]:
        """(row, per-column coefficient without lambda) for one member."""
        kind = mem["kind"]
        terms: List[Tuple[str, Fp2]] = []
        if "data" in mem:
            assert kind in ("pair", "block", "pairblock", "base1", "none"), kind
            eqw = self.eq(mem.get("row_bits"), len(mem["data"]))
            for r, row in enumerate(mem["data"]):
                self.unk(row, True)
                terms.append((row, f2_mul(a, eqw[r])))
            if kind == "pair":
                rre, rim = mem["mask"]
                self.unk(rre, False)
                self.unk(rim, False)
                terms += [(rre, c), (rim, f2_mul(c, U))]
            elif kind == "block":
                assert len(mem["mask"]) == len(mem["data"]), mem["name"]
                for r, row in enumerate(mem["mask"]):
                    self.unk(row, False)
                    terms.append((row, f2_mul(c, eqw[r])))
            elif kind == "pairblock":  # the uniform alternative: an Fp2 pair block (2 rows_i) on a base slot
                mre_rows, mim_rows = mem["mask"]
                assert len(mre_rows) == len(mem["data"]) == len(mim_rows), mem["name"]
                for r, (mre, mim) in enumerate(zip(mre_rows, mim_rows)):
                    self.unk(mre, False)
                    self.unk(mim, False)
                    terms += [(mre, f2_mul(c, eqw[r])), (mim, f2_mul(f2_mul(c, eqw[r]), U))]
            elif kind == "base1":
                (r1,) = mem["mask"]
                self.unk(r1, False)
                terms.append((r1, c))
        elif kind in ("fp2pair", "fp2block", "none"):
            eqw = self.eq(mem.get("row_bits"), len(mem["data_re"]))
            for r, (rre, rim) in enumerate(zip(mem["data_re"], mem["data_im"])):
                self.unk(rre, True)
                self.unk(rim, True)
                terms += [(rre, f2_mul(a, eqw[r])), (rim, f2_mul(f2_mul(a, eqw[r]), U))]
            if kind == "none":
                pass
            elif kind == "fp2pair":
                mre, mim = mem["mask"]
                self.unk(mre, False)
                self.unk(mim, False)
                terms += [(mre, c), (mim, f2_mul(c, U))]
            else:
                mre_rows, mim_rows = mem["mask"]
                assert len(mre_rows) == len(mem["data_re"]) == len(mim_rows)
                for r, (mre, mim) in enumerate(zip(mre_rows, mim_rows)):
                    self.unk(mre, False)
                    self.unk(mim, False)
                    terms += [(mre, f2_mul(c, eqw[r])), (mim, f2_mul(f2_mul(c, eqw[r]), U))]
        else:
            raise ValueError(kind)
        return terms

    def add_group(self, g: dict) -> None:
        e = self.rng.fp2()
        if g.get("e_kind") == "p3":
            s = f2_sub(ONE, self.rng.fp2())
            a0, c0 = f2_mul(s, f2_sub(ONE, e)), f2_mul(s, e)
        else:
            a0, c0 = f2_sub(ONE, e), e
        rho = self.rng.point(20)
        cw = FA2.eq_table_msb(self.rng.point(self.log_n)) if self.with_values else None
        vec: List[Dict[str, Fp2]] = [dict() for _ in range(self.n)]
        for mem in g["members"]:
            lam = self.rng.fp2()
            ext = FA2.ext_coef(rho, mem.get("ext_k", 0))
            a, c = f2_mul(a0, ext), f2_mul(c0, ext)
            value: Dict[str, Fp2] = {}
            for row, coef in self.member_terms(mem, a, c):
                for j in range(self.n):
                    nm = f"{row}[{j}]"
                    vec[j][nm] = f2_add(vec[j].get(nm, ZERO), f2_mul(lam, coef))
                    if cw is not None:
                        value[nm] = f2_add(value.get(nm, ZERO), f2_mul(coef, cw[j]))
            if cw is not None:
                self.model.observe(f"value[{g['name']}/{mem['name']}]", value, role="terminal (claim value)")
        for j in range(self.n):
            self.model.observe(f"v[{g['name']}][{j}]", vec[j], role=f"group vector entry, {len(g['members'])} member(s)")
        self.groups_added += 1

    # H specials -------------------------------------------------------------
    def _plane_sum_terms(self, mem: dict, scale: Fp2) -> Dict[str, Fp2]:
        """All-ones weights over every row of an Fp2 plane member (per column template)."""
        out: Dict[str, Fp2] = {}
        for rre, rim in zip(mem["data_re"], mem["data_im"]):
            self.unk(rre, True)
            self.unk(rim, True)
            out[rre] = f2_add(out.get(rre, ZERO), scale)
            out[rim] = f2_add(out.get(rim, ZERO), f2_mul(scale, U))
        return out

    def u_terms(self, j: int, scale: Fp2) -> Dict[str, Fp2]:
        """The zero-sum pair u at column j with u[n-1] = -sum_{j<n-1} u[j] substituted (FA2's
        `fixture_logup_sum`); at n = 1 the per-column view has no zero-sum constraint (u free)."""
        ure, uim = self.u_rows
        out: Dict[str, Fp2] = {}
        if self.n == 1:
            out[f"{ure}[0]"] = scale
            out[f"{uim}[0]"] = f2_mul(scale, U)
        elif j < self.n - 1:
            out[f"{ure}[{j}]"] = scale
            out[f"{uim}[{j}]"] = f2_mul(scale, U)
        else:
            for jj in range(self.n - 1):
                out[f"{ure}[{jj}]"] = f2_neg(scale)
                out[f"{uim}[{jj}]"] = f2_neg(f2_mul(scale, U))
        return out

    def declare_u(self, ure: str = "H/u_re", uim: str = "H/u_im") -> None:
        self.u_rows = (ure, uim)
        cols = range(self.n) if self.n == 1 else range(self.n - 1)
        for j in cols:
            self.model.mask_unknown(f"{ure}[{j}]")
            self.model.mask_unknown(f"{uim}[{j}]")

    def add_logup_sum(self, helper_members: Sequence[dict], table_members: Sequence[dict], with_u: bool = True) -> List[Dict[str, int]]:
        """The value-0 LogUp sum claim: v_sum[j] = sum_h h[j] - sum_T g_T[j] (+ u[j]); returns the
        two base rows of the public identity sum_j v_sum[j] restricted to the data."""
        ident: List[Dict[str, int]] = [dict(), dict()]
        for j in range(self.n):
            coeffs: Dict[str, Fp2] = {}
            for mem, sign in [(m, ONE) for m in helper_members] + [(m, f2_neg(ONE)) for m in table_members]:
                for row, v in self._plane_sum_terms(mem, sign).items():
                    nm = f"{row}[{j}]"
                    coeffs[nm] = f2_add(coeffs.get(nm, ZERO), v)
                    for ci in (0, 1):
                        ident[ci][nm] = (ident[ci].get(nm, 0) + v[ci]) % P
            if with_u:
                for k, v in self.u_terms(j, ONE).items():
                    coeffs[k] = f2_add(coeffs.get(k, ZERO), v)
            self.model.observe(f"v_sum[{j}]", coeffs, role="LogUp sum vector entry (all-ones column weights; public value 0)")
        return ident

    def add_public_sums(self, helper_members: Sequence[dict]) -> List[Dict[str, int]]:
        """Today's construction: the 19 helper sums each a public claim value (empty point, all-ones
        weights) sharing ONE opening group; returns the 2 x 19 base rows of those sums."""
        lam = [self.rng.fp2() for _ in helper_members]
        vec: List[Dict[str, Fp2]] = [dict() for _ in range(self.n)]
        sums: List[Dict[str, int]] = []
        for k, mem in enumerate(helper_members):
            value: Dict[str, Fp2] = {}
            for j in range(self.n):
                for row, v in self._plane_sum_terms(mem, ONE).items():
                    nm = f"{row}[{j}]"
                    vec[j][nm] = f2_add(vec[j].get(nm, ZERO), f2_mul(lam[k], v))
                    value[nm] = f2_add(value.get(nm, ZERO), v)
            self.model.observe(f"hsum[{mem['name']}]", value, role="published helper sum (Cc::hsum)")
            for ci in (0, 1):
                sums.append({k_: v_[ci] for k_, v_ in value.items() if v_[ci] % P})
        for j in range(self.n):
            self.model.observe(f"v[hsum][{j}]", vec[j], role="the 19-member sum group's vector entry")
        return sums

    def add_zsum(self, fresh_pair: bool = True, up: Tuple[str, str] = ("H/up_re", "H/up_im")) -> None:
        """The zsum claim: u at rho_zs masked by the fresh pair u' (or unmasked: the control)."""
        lam, e = self.rng.fp2(), self.rng.fp2()
        a, c = (f2_sub(ONE, e), e) if fresh_pair else (ONE, ZERO)
        if fresh_pair:
            self.unk(up[0], False)
            self.unk(up[1], False)
        cw = FA2.eq_table_msb(self.rng.point(self.log_n)) if self.with_values else None
        value: Dict[str, Fp2] = {}
        for j in range(self.n):
            coeffs: Dict[str, Fp2] = {}
            for k, v in self.u_terms(j, f2_mul(lam, a)).items():
                coeffs[k] = f2_add(coeffs.get(k, ZERO), v)
            if fresh_pair:
                coeffs[f"{up[0]}[{j}]"] = f2_mul(lam, c)
                coeffs[f"{up[1]}[{j}]"] = f2_mul(f2_mul(lam, c), U)
            self.model.observe(f"v_zs[{j}]", coeffs, role="zsum group vector entry")
            if cw is not None:
                for k, v in self.u_terms(j, f2_mul(a, cw[j])).items():
                    value[k] = f2_add(value.get(k, ZERO), v)
                if fresh_pair:
                    value[f"{up[0]}[{j}]"] = f2_mul(c, cw[j])
                    value[f"{up[1]}[{j}]"] = f2_mul(f2_mul(c, cw[j]), U)
        if cw is not None:
            self.model.observe("zs_term", value, role="zsum terminal value")

    # the proximity vector ---------------------------------------------------
    def add_prox(self, kind: str = "pair") -> None:
        """kind: 'pair' (FA3 prox_pair), 'single' (one base prox row), 'none' (legacy: no prox mask)."""
        if kind in ("pair", "single"):
            self.unk("prox/R_prox", False)
        if kind == "pair":
            self.unk("prox/R_prox_im", False)
        for j in range(self.n):
            coeffs = {f"{row}[{j}]": self.rng.fp2() for row in self.rows}
            if self.u_rows is not None:
                if self.n == 1 or j < self.n - 1:
                    for k, v in self.u_terms(j, ONE).items():
                        coeffs[k] = f2_mul(v, self.rng.fp2())
                else:
                    ru = (self.rng.fp2(), self.rng.fp2())
                    for jj in range(self.n - 1):
                        coeffs[f"{self.u_rows[0]}[{jj}]"] = f2_neg(ru[0])
                        coeffs[f"{self.u_rows[1]}[{jj}]"] = f2_neg(ru[1])
            self.model.observe(f"v_prox[{j}]", coeffs, role="proximity vector entry (fresh Fp2 coefficient on every row)")


# ---- the exact rank engine (sparse; same semantics as FA2.analyze) -----------


def _sparse_rref(rows: List[Dict[int, int]]) -> Dict[int, Dict[int, int]]:
    """Incremental reduced row echelon form over Fp on sparse rows: pivot column -> reduced row
    (unit pivot, zero in every other pivot column).  Columns are processed in increasing index."""
    piv: Dict[int, Dict[int, int]] = {}
    for r0 in rows:
        r = {k: v % P for k, v in r0.items() if v % P}
        for c in sorted(r):
            if c in piv and r.get(c):
                f = r[c]
                for k, v in piv[c].items():
                    nv = (r.get(k, 0) - f * v) % P
                    if nv:
                        r[k] = nv
                    else:
                        r.pop(k, None)
        if not r:
            continue
        c = min(r)
        inv = FA2.fp_inv(r[c])
        r = {k: (v * inv) % P for k, v in r.items()}
        for pc, prow in piv.items():
            if c in prow:
                f = prow[c]
                for k, v in r.items():
                    nv = (prow.get(k, 0) - f * v) % P
                    if nv:
                        prow[k] = nv
                    else:
                        prow.pop(k, None)
        piv[c] = r
    return piv


def analyze_fast(model: "FA2.Model") -> dict:
    """rank(B), rank([A|B]), the surviving data functionals F and the per-unknown status, by
    sparse elimination with the mask columns ordered first (rows whose pivot lands in the data
    block are exactly a basis of N . A).  Same result keys as FA2.analyze for the fields used."""
    nd, nm = len(model.data), len(model.masks)
    col = {x: i for i, x in enumerate(model.masks)}
    col.update({x: nm + i for i, x in enumerate(model.data)})
    rows: List[Dict[int, int]] = []
    data_only: List[Dict[int, int]] = []
    for o in model.obs:
        parts = (("re", 0), ("im", 1)) if o["domain"] == "Fp2" else (("", None),)
        for _, ci in parts:
            r = {}
            for k, v in o["coeffs"].items():
                x = (v[ci] if ci is not None else v) % P
                if x:
                    r[col[k]] = x
            rows.append(r)
            data_only.append({k - nm: v for k, v in r.items() if k >= nm})
    piv = _sparse_rref(rows)
    rank_joint = len(piv)
    rank_mask = sum(1 for c in piv if c < nm)
    f_rows = [{k - nm: v for k, v in piv[c].items()} for c in sorted(piv) if c >= nm]
    disclosed = len(f_rows)
    assert disclosed == rank_joint - rank_mask
    rank_data = len(_sparse_rref(data_only)) if nd else 0
    status = {}
    touched = set()
    recovered = set()
    for fr in f_rows:
        touched.update(fr.keys())
        if len(fr) == 1:
            recovered.add(next(iter(fr)))
    for i, name in enumerate(model.data):
        status[name] = "recovered" if i in recovered else ("disclosed" if i in touched else "protected")
    return {
        "model": model.name, "notes": model.notes, "engine": "sparse (this tool); semantics of FA2.analyze",
        "counts": {"data_unknowns": nd, "mask_unknowns": nm, "observations_fp2_or_fp": len(model.obs), "base_observation_rows": len(rows)},
        "rank_mask": rank_mask, "rank_data": rank_data, "rank_joint": rank_joint, "disclosed_dim": disclosed,
        "mask_null_dim": len(rows) - rank_mask, "observation_functionals_killing_masks_but_not_data": len(rows) - rank_mask - disclosed,
        "surviving_data_functionals": [{model.data[i]: v for i, v in fr.items()} for fr in f_rows],
        "status": status,
        "summary": {"recovered": [k for k, v in status.items() if v == "recovered"], "disclosed": [k for k, v in status.items() if v == "disclosed"], "protected": [k for k, v in status.items() if v == "protected"]},
        "caveat": "numerical rank of linear observations under fixed public coefficients; not a simulation proof",
    }


def engines_agree(model: "FA2.Model") -> dict:
    """FA2's dense `analyze` against the sparse engine on the same model: the four ranks and the
    row space of the surviving functionals must coincide."""
    dense = FA2.analyze(model)
    fast = analyze_fast(model)
    same = all(dense[k] == fast[k] for k in ("rank_mask", "rank_data", "rank_joint", "disclosed_dim"))
    f1 = [[f.get(x, 0) for x in model.data] for f in dense["surviving_data_functionals"]]
    f2 = [[f.get(x, 0) for x in model.data] for f in fast["surviving_data_functionals"]]
    same_space = (not f1 and not f2) or (FA2.rank(f1) == FA2.rank(f2) == FA2.rank(f1 + f2))
    return {"agree": same and same_space, "dense": {k: dense[k] for k in ("rank_mask", "rank_data", "rank_joint", "disclosed_dim")}, "sparse": {k: fast[k] for k in ("rank_mask", "rank_data", "rank_joint", "disclosed_dim")}, "same_functional_space": same_space}


def rank_of(functionals: Sequence[Dict[str, int]], unknowns: Sequence[str]) -> int:
    return len(_sparse_rref([{i: f.get(x, 0) for i, x in enumerate(unknowns) if f.get(x, 0) % P} for f in functionals]))


def summ(res: dict) -> dict:
    return {"disclosed_dim": res["disclosed_dim"], "rank_mask": res["rank_mask"], "rank_joint": res["rank_joint"], "base_obs_rows": res["counts"]["base_observation_rows"], "mask_unknowns": res["counts"]["mask_unknowns"], "data_unknowns": res["counts"]["data_unknowns"],
            "disclosed_or_recovered": sorted(res["summary"]["recovered"] + res["summary"]["disclosed"])[:64], "n_disclosed_or_recovered": len(res["summary"]["recovered"]) + len(res["summary"]["disclosed"])}


# ----------------------------------------------------------------------------
# 4. model groups from the schedule, model factories, verdicts, controls
# ----------------------------------------------------------------------------


def seed_for(base: int, name: str) -> int:
    return int(hashlib.sha256(f"{base}:{name}".encode()).hexdigest()[:12], 16)


def _a_row(r: int) -> str:
    return f"A/r{r}"


def _a_mask(r: int) -> str:
    return f"A/m{r}"


def group_e_kind(sections: Sequence[str], p3: bool) -> str:
    return "p3" if any(e_kind(s, p3) == "p3" for s in sections) else "p1"


def a_model_groups(sched: dict, p3: bool = False, kind_for=None, table_cap: Optional[int] = None, only_groups: Optional[Sequence[int]] = None, include_tab: bool = True, tables_kind: Optional[str] = None, planes_as_blocks: bool = False, share_mask: Optional[Dict[str, str]] = None) -> List[dict]:
    """The A commitment's opening groups in Builder form.  `kind_for(site) -> kind` overrides the
    scheduled mask kind (controls); `table_cap` compresses multi-row histogram slots (with-values
    models); `tables_kind` overrides the slot kinds ('none' legacy, 'pairblock' the uniform
    alternative); `planes_as_blocks`: the alternative reading (multi-row planes under a base mask
    block of `rows` rows); `share_mask`: role -> role whose pair it re-uses (control)."""
    A = sched["commitments"]["A"]
    order: List[int] = []
    members: Dict[int, List[dict]] = {}
    sections: Dict[int, List[str]] = {}
    for s in A["sites"]:
        g = s["group"]
        if only_groups is not None and g not in only_groups:
            continue
        kind = "pair" if s["mask_kind"] == "pair" else "none"
        if kind_for is not None:
            kind = kind_for(s)
        rows = list(range(*s["data_row_range"]))
        mem = {"name": s["role"], "kind": kind, "data": [_a_row(r) for r in rows], "row_bits": s["row_bits"]}
        src = s if share_mask is None or s["role"] not in share_mask else next(x for x in A["sites"] if x["role"] == share_mask[s["role"]])
        if kind == "pair":
            mem["mask"] = [_a_mask(src["mask_rows"][0]), _a_mask(src["mask_rows"][1])]
        elif kind == "base1":
            mem["mask"] = [_a_mask(src["mask_rows"][0])]
        elif kind == "block":
            mem["mask"] = [f"A/altblock/{s['role']}/R{r}" for r in range(len(rows))]
        if planes_as_blocks and kind == "pair" and len(rows) > 1:
            mem["kind"] = "block"
            mem["mask"] = [f"A/altblock/{s['role']}/R{r}" for r in range(len(rows))]
        if g not in members:
            order.append(g)
            members[g], sections[g] = [], []
        members[g].append(mem)
        sections[g].append(s["section"])
    groups = [{"name": f"g{g}", "e_kind": group_e_kind(sections[g], p3), "members": members[g]} for g in order]
    if include_tab and (only_groups is None or "tab" in only_groups):
        tab = []
        for t, hd, hm in zip(sched["tables"], A["histogram_data_rows"], A["histogram_masks"]):
            rows = t["rows"] if table_cap is None else min(t["rows"], table_cap)
            kind = tables_kind or t["kind"]
            mem = {"name": hm["role"], "kind": kind, "data": [_a_row(r) for r in hd["data_rows"][:rows]], "row_bits": None, "ext_k": t["ext_k"]}
            if kind == "pair":
                mem["mask"] = [_a_mask(hm["mask_rows"][0]), _a_mask(hm["mask_rows"][1])]
            elif kind == "block":
                mem["mask"] = [_a_mask(r) for r in hm["mask_rows"][:rows]]
            elif kind == "pairblock":
                mem["mask"] = ([f"A/altpair/{hm['role']}/R{r}_re" for r in range(rows)], [f"A/altpair/{hm['role']}/R{r}_im" for r in range(rows)])
            elif kind == "base1":
                mem["mask"] = [_a_mask(hm["mask_rows"][0])]
            tab.append(mem)
        groups.append({"name": "tab", "e_kind": "p1", "members": tab})
    return groups


def _h_row(r: int) -> str:
    return f"H/r{r}"


def _h_mask(r: int) -> str:
    return f"H/m{r}"


def h_model_groups(sched: dict, table_cap: Optional[int] = None, helper_kind: str = "fp2pair", tab_kind: Optional[str] = None, only_groups: Optional[Sequence] = None, include_tab: bool = True) -> Tuple[List[dict], List[dict], List[dict]]:
    """(groups, helper members, table members) of the H commitment: the 5 helper evaluation
    groups (19 Fp2 planes, mask pairs) and the TAB group (10 g_T planes, pair / pair block)."""
    H = sched["commitments"]["H"]
    order: List[int] = []
    members: Dict[int, List[dict]] = {}
    helpers: List[dict] = []
    for s in H["sites"]:
        g = s["group"]
        mem = {"name": s["role"], "kind": helper_kind, "data_re": [_h_row(r) for r in range(*s["data_row_range_re"])], "data_im": [_h_row(r) for r in range(*s["data_row_range_im"])], "row_bits": s["row_bits"], "mask": [_h_mask(s["mask_rows"][0]), _h_mask(s["mask_rows"][1])]}
        helpers.append(mem)
        if only_groups is not None and g not in only_groups:
            continue
        if g not in members:
            order.append(g)
            members[g] = []
        members[g].append(mem)
    groups = [{"name": f"h{g}", "e_kind": "p1", "members": members[g]} for g in order]
    tables: List[dict] = []
    for t, gd, gs in zip(sched["tables"], H["g_T_data_rows"], H["g_T_sites"]):
        rows = t["rows"] if table_cap is None else min(t["rows"], table_cap)
        kind = tab_kind or ("fp2pair" if t["kind"] == "pair" else "fp2block")
        mem = {"name": gs["role"], "kind": kind, "data_re": [_h_row(r) for r in gd["re_rows"][:rows]], "data_im": [_h_row(r) for r in gd["im_rows"][:rows]], "row_bits": None, "ext_k": t["ext_k"]}
        mre = [_h_mask(r) for r in gs["mask_rows"][:t["rows"]]][:rows]
        mim = [_h_mask(r) for r in gs["mask_rows"][t["rows"]:]][:rows]
        mem["mask"] = (mre[0], mim[0]) if kind == "fp2pair" else (mre, mim)
        tables.append(mem)
    if include_tab and (only_groups is None or "TAB" in only_groups):
        groups.append({"name": "TAB", "e_kind": "p1", "members": tables})
    return groups, helpers, tables


def _w_row(r: int) -> str:
    return f"W/r{r}"


def w_model_groups(sched: dict, p3: bool = True, kind_for=None, only_groups: Optional[Sequence[int]] = None) -> List[dict]:
    W = sched["commitments"]["W"]
    groups = []
    for s in W["sites"]:
        if only_groups is not None and s["group"] not in only_groups:
            continue
        kind = "pair" if p3 else "none"
        if kind_for is not None:
            kind = kind_for(s)
        mem = {"name": s["role"], "kind": kind, "data": [_w_row(r) for r in range(*s["data_row_range"])], "row_bits": s["row_bits"]}
        if kind == "pair":
            mem["mask"] = [f"W/m{s['mask_rows'][0]}", f"W/m{s['mask_rows'][1]}"]
        elif kind == "base1":
            mem["mask"] = [f"W/m{s['mask_rows'][0]}"]
        groups.append({"name": f"w{s['group']}", "e_kind": e_kind(s["section"], p3), "members": [mem]})
    return groups


def build_model(name: str, groups: Sequence[dict], n_cols: int, seed: int, with_values: bool, prox: str = "pair", h_special: Optional[dict] = None, notes: Optional[List[str]] = None) -> Tuple["FA2.Model", dict]:
    """One commitment model.  `h_special` (H only): {'helpers', 'tables', 'u': bool,
    'zsum_fresh_pair': bool, 'public_sums': bool}.  Returns (model, extras) with the identity
    rows / published-sum rows the LogUp checks need."""
    rng = FA2.Rng(seed)
    b = Builder(name, n_cols, rng, Symbols(rng), with_values, notes)
    for g in groups:
        b.add_group(g)
    extras: dict = {}
    if h_special:
        if h_special.get("u", False):
            b.declare_u()
            extras["identity_rows"] = b.add_logup_sum(h_special["helpers"], h_special["tables"], with_u=True)
            b.add_zsum(fresh_pair=h_special.get("zsum_fresh_pair", True))
        elif h_special.get("public_sums", False):
            extras["sum_rows"] = b.add_public_sums(h_special["helpers"])
        elif h_special.get("sum_without_u", False):
            extras["identity_rows"] = b.add_logup_sum(h_special["helpers"], h_special["tables"], with_u=False)
    b.add_prox(prox)
    extras["rows"] = list(b.rows)
    return b.model, extras


def fa2_groups(groups: Sequence[dict]) -> List[dict]:
    """Translate Builder groups into FA2's `per_column_commitment` / `commitment_with_values`
    schema (kinds base / pair / pairmask) for the cross-check.  Aliased data rows become
    `data_alias` names built from the row set; members must be pair / block / base1 / fp2pair /
    fp2block (the controls' 'none' and shared masks have no FA2 form)."""
    out = []
    for g in groups:
        mems = []
        for m in g["members"]:
            k = m["kind"]
            if k == "pair":
                fm = {"kind": "pairmask", "data_rows": len(m["data"]), "mask_rows": 1}
            elif k == "block":
                fm = {"kind": "base", "data_rows": len(m["data"]), "mask_rows": len(m["data"])}
            elif k == "base1":
                fm = {"kind": "base", "data_rows": len(m["data"]), "mask_rows": 1}
            elif k == "fp2pair":
                fm = {"kind": "pair", "data_rows": len(m["data_re"]), "mask_rows": 1}
            elif k == "fp2block":
                fm = {"kind": "pair", "data_rows": len(m["data_re"]), "mask_rows": len(m["data_re"])}
            else:
                raise ValueError(f"no FA2 form for kind {k}")
            data = m.get("data") or m["data_re"]
            fm.update({"name": m["name"].replace("/", "_"), "ext_k": m.get("ext_k", 0), "data_alias": "rows:" + ",".join(data)})
            mems.append(fm)
        out.append({"name": g["name"], "e_kind": g.get("e_kind", "p1"), "members": mems})
    return out


def verdict(res: dict, expect: Optional[int], argument: str, **extra) -> dict:
    v = {**summ(res), "expected_disclosed_dim": expect, "argument": argument, **extra}
    v["verdict"] = "PASS" if expect is None or res["disclosed_dim"] == expect else "FAIL"
    return v


def identity_check(res: dict, model: "FA2.Model", identity_rows: Sequence[Dict[str, int]]) -> dict:
    """rank F = rank I = rank(F u I) = 2: the surviving functionals are exactly the public LogUp identity."""
    F = res["surviving_data_functionals"]
    I = list(identity_rows)
    rf, ri, rfi = rank_of(F, model.data), rank_of(I, model.data), rank_of(list(F) + I, model.data)
    return {"rank_F": rf, "rank_I": ri, "rank_F_union_I": rfi, "residual_is_exactly_the_public_identity": rf == ri == rfi == 2}


def run_positive(sched: dict, seed: int, n_values: int = 4, table_cap: int = 2, p3_modes: Sequence[bool] = (False, True)) -> dict:
    """Every group alone (with values), every whole commitment per column (real rows) and with
    values (small n), plus the FA2-engine cross-checks and the two alternatives."""
    out: Dict[str, dict] = {}
    prof = f"{sched['profile']}/{sched['endpoints_mode']}"
    # (1) each group alone, vector + values + prox pair
    exempt_sites = [s for s in sched["commitments"]["A"]["sites"] if s.get("receipt_only") and s["mask_kind"].startswith("none")]
    boundary_col = {f"A/r{r}[0]" for s in exempt_sites for r in range(*s["data_row_range"])}
    for g in a_model_groups(sched, table_cap=table_cap):
        model, _ = build_model(f"A {g['name']} alone {prof}", [g], n_values, seed_for(seed, f"A-{g['name']}"), True)
        res = analyze_fast(model)
        if g["members"] and all(m["kind"] == "none" for m in g["members"]):
            allowed = {f"A/r{r}[{j}]" for s in exempt_sites for r in range(*s["data_row_range"]) for j in range(n_values)}
            leaked = set(res["summary"]["disclosed"] + res["summary"]["recovered"])
            out[f"group_A_{g['name']}"] = verdict(res, None, "exempt bind_endpoints claim, unmasked by ruling: it discloses its own public boundary rows and nothing else", members=[m["name"] for m in g["members"]], disclosed_confined_to_public_boundary_rows=leaked <= allowed)
            out[f"group_A_{g['name']}"]["verdict"] = "PASS" if leaked <= allowed else "FAIL"
            continue
        out[f"group_A_{g['name']}"] = verdict(res, 0, f"all-pair group of m = {len(g['members'])} + prox pair: rank(B) = 2m + 2n - 2 + 2n (FA2 14.3)", members=[m["name"] for m in g["members"]])
        if all(m["kind"] == "pair" for m in g["members"]):
            m_ = len(g["members"])
            out[f"group_A_{g['name']}"]["rank_mask_formula_2m+2n-2+2n"] = res["rank_mask"] == 2 * m_ + 2 * n_values - 2 + 2 * n_values
    hg, helpers, tables = h_model_groups(sched, table_cap=table_cap)
    for g in hg:
        model, _ = build_model(f"H {g['name']} alone", [g], n_values, seed_for(seed, f"H-{g['name']}"), True)
        out[f"group_H_{g['name']}"] = verdict(analyze_fast(model), 0, "Fp2 planes with Fp2 mask pairs / pair blocks (FA2 14.3, H rows)", members=[m["name"] for m in g["members"]])
    for g in w_model_groups(sched, p3=True):
        model, _ = build_model(f"W(P3) {g['name']} alone", [g], n_values, seed_for(seed, f"W-{g['name']}"), True)
        out[f"group_W_P3_{g['name']}"] = verdict(analyze_fast(model), 0, "singleton with a pair + prox pair (FA2 U11: the Wd singleton shape)", members=[m["name"] for m in g["members"]])
    # (2) whole commitments per column at the real row structure
    for p3 in p3_modes:
        tag = "P3" if p3 else "P1"
        groups = a_model_groups(sched, p3=p3)
        model, ex = build_model(f"whole A per column {prof} {tag}", groups, 1, seed_for(seed, f"A-col-{tag}"), False)
        res = analyze_fast(model)
        if sched["endpoints_mode"] == "exempt":
            allowed = {f"A/r{r}[0]" for s in sched["commitments"]["A"]["sites"] if s.get("receipt_only") for r in range(*s["data_row_range"])}
            leaked = set(res["summary"]["disclosed"] + res["summary"]["recovered"])
            out[f"whole_A_per_column_{tag}"] = verdict(res, None, "exempt endpoints: the two unmasked bind_endpoints claims disclose functionals of x_in / xres2 ONLY (public boundary tensors by statement, inventory O-6)", disclosed_confined_to_public_boundary_rows=leaked <= allowed, boundary_rows=sorted(allowed))
            out[f"whole_A_per_column_{tag}"]["verdict"] = "PASS" if leaked <= allowed else "FAIL"
        else:
            out[f"whole_A_per_column_{tag}"] = verdict(res, 0, f"{len(groups)} groups (incl. tab, seams, added rho_2 sites) + prox pair, every site its own pair / block: joint rank full per column", groups=len(groups), rows_modelled=len(ex["rows"]))
        agree = engines_agree(model)
        out[f"whole_A_per_column_{tag}"]["sparse_engine_equals_FA2_analyze"] = agree["agree"]
        if sched["endpoints_mode"] != "exempt":
            fa2m = FA2.per_column_commitment(f"FA2 whole A {prof} {tag}", fa2_groups(groups), seed=seed_for(seed, f"A-fa2-{tag}") % (2**31), prox_pair=True)
            fres = FA2.analyze(fa2m)
            out[f"whole_A_per_column_{tag}"]["FA2_per_column_commitment_disclosed_dim"] = fres["disclosed_dim"]
            out[f"whole_A_per_column_{tag}"]["FA2_builder_agrees"] = fres["disclosed_dim"] == res["disclosed_dim"] == 0 and fres["rank_mask"] == res["rank_mask"]
    hgroups, helpers, tables = h_model_groups(sched)
    model, ex = build_model("whole H per column", hgroups, 1, seed_for(seed, "H-col"), False, h_special={"helpers": helpers, "tables": tables, "u": True})
    res = analyze_fast(model)
    out["whole_H_per_column"] = verdict(res, 0, "5 helper groups (19 Fp2 pairs) + TAB (10 g_T pair / pair blocks) + zsum (u masked by u') + the LogUp sum vector (u free per column; its zero sum is a cross-column constraint, see whole_H_with_values) + prox pair", groups=len(hgroups), rows_modelled=len(ex["rows"]))
    out["whole_H_per_column"]["sparse_engine_equals_FA2_analyze"] = engines_agree(model)["agree"]
    fa2m = FA2.per_column_commitment("FA2 whole H", fa2_groups(hgroups), seed=seed_for(seed, "H-fa2") % (2**31), prox_pair=True)
    out["whole_H_per_column"]["FA2_per_column_commitment_disclosed_dim_without_sum_claim"] = FA2.analyze(fa2m)["disclosed_dim"]
    wg = w_model_groups(sched, p3=True)
    model, _ = build_model("whole W(P3) per column", wg, 1, seed_for(seed, "W-col"), False)
    res = analyze_fast(model)
    out["whole_W_P3_per_column"] = verdict(res, 0, "6 singleton pairs + prox pair: 14 mask unknowns against 14 base observation dims (the tiny-W starvation of FA2 14.4 closed, U11)")
    out["whole_W_P3_per_column"]["sparse_engine_equals_FA2_analyze"] = engines_agree(model)["agree"]
    fres = FA2.analyze(FA2.per_column_commitment("FA2 whole W(P3)", fa2_groups(wg), seed=seed_for(seed, "W-fa2") % (2**31), prox_pair=True))
    out["whole_W_P3_per_column"]["FA2_per_column_commitment_disclosed_dim"] = fres["disclosed_dim"]
    out["whole_W_P3_per_column"]["FA2_builder_agrees"] = fres["disclosed_dim"] == 0
    out["W_P1"] = {"verdict": "PASS", "note": "public weights: plain opening, no privacy claim, no mask (FA3 2.2 W(P1) row); not modelled"}
    # (3) whole commitments with values at small n (multi-row histogram slots compressed to table_cap rows)
    for p3 in p3_modes:
        tag = "P3" if p3 else "P1"
        groups = a_model_groups(sched, p3=p3, table_cap=table_cap)
        model, ex = build_model(f"whole A with values n{n_values} {prof} {tag}", groups, n_values, seed_for(seed, f"A-val-{tag}"), True)
        res = analyze_fast(model)
        key = f"whole_A_with_values_n{n_values}_{tag}"
        if sched["endpoints_mode"] == "exempt":
            allowed = {f"A/r{r}[{j}]" for s in sched["commitments"]["A"]["sites"] if s.get("receipt_only") for r in range(*s["data_row_range"]) for j in range(n_values)}
            leaked = set(res["summary"]["disclosed"] + res["summary"]["recovered"])
            out[key] = verdict(res, None, "exempt endpoints: disclosed functionals confined to the x_in / xres2 rows", disclosed_confined_to_public_boundary_rows=leaked <= allowed)
            out[key]["verdict"] = "PASS" if leaked <= allowed else "FAIL"
        else:
            out[key] = verdict(res, 0, "every group vector, every terminal value and the prox vector jointly: xm8 / z16c under two pairs (rho_D, seam), q8 / k8 under three (rho_Q or rho_KV, flipped, QKV), sm / lm rows under the section-1 / -2 / -3 / -6 / -7 / -8 tails: joint rank full", groups=len(groups), rows_modelled=len(ex["rows"]), trivial_identities=res["observation_functionals_killing_masks_but_not_data"])
            if n_values <= 4:
                fa2m = FA2.commitment_with_values(f"FA2 whole A values {tag}", fa2_groups(groups), n_values, seed=seed_for(seed, f"A-fa2val-{tag}") % (2**31), prox_pair=True)
                fres = analyze_fast(fa2m)
                out[key]["FA2_commitment_with_values_disclosed_dim"] = fres["disclosed_dim"]
                out[key]["FA2_builder_agrees"] = fres["disclosed_dim"] == res["disclosed_dim"] == 0 and fres["rank_mask"] == res["rank_mask"]
    for n in sorted({n_values, 8}):
        hgroups, helpers, tables = h_model_groups(sched, table_cap=table_cap)
        model, ex = build_model(f"whole H with values n{n}", hgroups, n, seed_for(seed, f"H-val-{n}"), True, h_special={"helpers": helpers, "tables": tables, "u": True})
        res = analyze_fast(model)
        ic = identity_check(res, model, ex["identity_rows"])
        out[f"whole_H_with_values_n{n}"] = verdict(res, 2, "the ONE zero-sum construction over all 19 helper columns and the 10 g_T rows: the two surviving base functionals span exactly the public LogUp identity sum_j v_sum[j] = 0 (FA2 14.5 generalised; O-1 answered)", **ic)
        out[f"whole_H_with_values_n{n}"]["verdict"] = "PASS" if res["disclosed_dim"] == 2 and ic["residual_is_exactly_the_public_identity"] else "FAIL"
        if n <= 4:
            out[f"whole_H_with_values_n{n}"]["sparse_engine_equals_FA2_analyze"] = engines_agree(model)["agree"]
    model, _ = build_model(f"whole W(P3) with values n{n_values}", w_model_groups(sched, p3=True), n_values, seed_for(seed, "W-val"), True)
    out[f"whole_W_P3_with_values_n{n_values}"] = verdict(analyze_fast(model), 0, "six pair-masked singletons with their values + prox pair")
    # (4) FA2's own single-row LogUp fixture at 19 helper pairs and 10 table pairs (the reference form)
    for n in (4, 8):
        fm, ident = FA2.fixture_logup_sum(n, 19, 10, seed=seed_for(seed, f"fa2-logup-{n}") % (2**31), prox_pair=True)
        fres = analyze_fast(fm)
        ic = identity_check(fres, fm, ident)
        out[f"FA2_fixture_logup_sum_19_helpers_10_tables_n{n}"] = verdict(fres, 2, "FA2's own single-row fixture with n_helper_pairs = 19, n_table_pairs = 10: the residual is the public identity", **ic)
        out[f"FA2_fixture_logup_sum_19_helpers_10_tables_n{n}"]["verdict"] = "PASS" if fres["disclosed_dim"] == 2 and ic["residual_is_exactly_the_public_identity"] else "FAIL"
    # (5) alternatives (documented, not proposed first)
    model, _ = build_model("A per column, multi-row planes as base blocks", a_model_groups(sched, planes_as_blocks=True), 1, seed_for(seed, "A-alt-blocks"), False)
    res = analyze_fast(model)
    sm_rows = {f"A/r{SM_OFFSET // N_COLS}[0]", f"A/r{SM_OFFSET // N_COLS + 1}[0]"}
    leaked = set(res["summary"]["disclosed"] + res["summary"]["recovered"])
    n_bound = len(boundary_col)  # exempt endpoints recover their own boundary rows per column (0 unless receipt / exempt)
    out["alternative_multi_row_planes_as_base_blocks_per_column"] = verdict(res, 2 + n_bound, "the other reading of 'multi-row site -> block' (a 2- or 8-row plane under a base mask block of `rows` rows) FAILS on attention: the sm sub-block claims (bcast rows, sm[m], sm[Sum]) select ONE row by a CONSTANT row bit, so their block mask degenerates to a single base row (FA3 2.1's row-bit-in-Fp degeneracy, here structural, not 2^-64) and both sm rows are recovered per column; planes with symbolic row bits are covered. The schedule's pair rule has no such case.", leaked_rows=sorted(leaked), leaked_rows_are_exactly_the_sm_rows=(leaked - boundary_col) == sm_rows, exempt_boundary_rows=n_bound)
    out["alternative_multi_row_planes_as_base_blocks_per_column"]["verdict"] = "PASS" if res["disclosed_dim"] == 2 + n_bound and (leaked - boundary_col) == sm_rows else "FAIL"
    model, _ = build_model("A per column, all-pair table blocks", a_model_groups(sched, tables_kind="pairblock"), 1, seed_for(seed, "A-alt-pairtab"), False)
    res = analyze_fast(model)
    leaked = set(res["summary"]["disclosed"] + res["summary"]["recovered"])
    out["alternative_tables_all_pairs_per_column"] = verdict(res, n_bound, "FA3 2.1's uniform alternative (every histogram block an Fp2 pair block, +580 A rows here)", exempt_boundary_rows=n_bound)
    out["alternative_tables_all_pairs_per_column"]["verdict"] = "PASS" if res["disclosed_dim"] == n_bound and leaked <= boundary_col else "FAIL"
    # (6) the added rho_2 sites forced into singleton groups (the coordinator's reading of the key)
    return out


def singleton_leak_expectation(sched: dict) -> dict:
    """Under one base mask row per claim, a singleton group leaks one functional per column of its
    effective data rows: the single row a constant row bit selects, or the eq-weighted rows of a
    symbolic row point.  Singletons with the same effective (rows, symbols) key yield the same
    functional, so the expected disclosed_dim is the number of DISTINCT keys."""
    keys = set()
    rows = set()
    for g in sched["groups"]["A"]:
        if not g["singleton"]:
            continue
        s = next(x for x in sched["commitments"]["A"]["sites"] if x["claim_index"] == g["members"][0])
        r0, r1 = s["data_row_range"]
        bits = s["row_bits"]
        if all(b in ("0", "1") for b in bits):
            sel = r0 + int("".join(bits) or "0", 2)
            keys.add((sel,))
            rows.add(f"A/r{sel}")
        else:
            keys.add((tuple(range(r0, r1)), tuple(bits)))
            rows.update(f"A/r{r}" for r in range(r0, r1))
    return {"singleton_groups": sum(1 for g in sched["groups"]["A"] if g["singleton"]), "distinct_functionals": len(keys), "rows": sorted(rows)}


def run_negative(sched: dict, seed: int, n_values: int = 4, table_cap: int = 2) -> dict:
    """The controls: each shows which rule carries which part of the repair."""
    out: Dict[str, dict] = {}
    A = sched["commitments"]["A"]
    groups_of = {g["group"]: g for g in sched["groups"]["A"]}
    singletons = [g["group"] for g in sched["groups"]["A"] if g["singleton"]]
    n_single = len(singletons)
    # 1. legacy: no mask at all (P0 today)
    model, _ = build_model("legacy A per column, no masks", a_model_groups(sched, kind_for=lambda s: "none", tables_kind="none"), 1, seed_for(seed, "nc-nomask-A"), False, prox="none")
    res = analyze_fast(model)
    out["legacy_no_mask_A_per_column"] = verdict(res, None, "P0: every group vector entry is a public data functional; disclosed = rank of the data observations per column (capped structurally: the 24 sm / lm sub-block claims read only rows 104-106, each multi-member group contributes 2)", expected_at_least=40, data_rows_disclosed_or_recovered=len(res["summary"]["recovered"]) + len(res["summary"]["disclosed"]))
    out["legacy_no_mask_A_per_column"]["verdict"] = "PASS" if res["disclosed_dim"] >= 40 else "FAIL"
    model, _ = build_model("legacy A with values, no masks", a_model_groups(sched, kind_for=lambda s: "none", tables_kind="none", table_cap=table_cap), n_values, seed_for(seed, "nc-nomask-Aval"), True, prox="none")
    res = analyze_fast(model)
    out[f"legacy_no_mask_A_with_values_n{n_values}"] = verdict(res, None, "P0 with the terminal values: large disclosure", expected_at_least=2 * len(A["sites"]))
    out[f"legacy_no_mask_A_with_values_n{n_values}"]["verdict"] = "PASS" if res["disclosed_dim"] >= 2 * len(A["sites"]) else "FAIL"
    hg, helpers, tables = h_model_groups(sched, table_cap=table_cap, helper_kind="none", tab_kind="none")
    model, ex = build_model("legacy H with values, no masks, 19 public sums", hg, n_values, seed_for(seed, "nc-nomask-H"), True, prox="none", h_special={"helpers": helpers, "public_sums": True})
    res = analyze_fast(model)
    out[f"legacy_no_mask_H_with_values_n{n_values}"] = verdict(res, None, "P0 H: helpers, g_T rows and the 19 sums all public", expected_at_least=38)
    out[f"legacy_no_mask_H_with_values_n{n_values}"]["verdict"] = "PASS" if res["disclosed_dim"] >= 38 else "FAIL"
    # 2. the naive width-1 port: ONE base mask row per claim (FA2 14.1: every singleton leaks a functional per column)
    model, _ = build_model("naive port A per column: one base row per claim", a_model_groups(sched, kind_for=lambda s: "base1"), 1, seed_for(seed, "nc-base1-A"), False, prox="pair")
    res = analyze_fast(model)
    exp = singleton_leak_expectation(sched)
    leaked = set(res["summary"]["recovered"] + res["summary"]["disclosed"])
    out["single_base_row_per_claim_A_per_column"] = verdict(res, exp["distinct_functionals"], f"FA2 14.1: each of the {n_single} singleton groups leaks one functional per column (n per proof: the whole plane); functionals of singletons that read the SAME single row under a constant row bit coincide (rows 104 / 105: the bcast, sm[m], sm[Sum] sites), so {exp['distinct_functionals']} independent functionals survive; multi-member groups are covered per column (their leak is in the values, FA2 14.2). Prox pair kept so only the singleton rule is measured.", singleton_groups=singletons, every_singleton_row_disclosed=set(exp["rows"]) <= {x[:-3] for x in leaked}, expectation=exp)
    for gidx in [g for g in singletons if groups_of[g]["data_rows"] == [1]][:1] + [g for g in singletons if groups_of[g]["data_rows"] == [2]][:1]:
        rows = groups_of[gidx]["data_rows"][0]
        model, _ = build_model(f"singleton g{gidx} base1 with values", a_model_groups(sched, kind_for=lambda s: "base1", only_groups=[gidx], include_tab=False), n_values, seed_for(seed, f"nc-base1-g{gidx}"), True, prox="pair")
        res = analyze_fast(model)
        out[f"single_base_row_singleton_g{gidx}_with_values_n{n_values}"] = verdict(res, n_values, f"FA2 14.1: one functional per column = n = {n_values} functionals of a {rows}-row plane" + (" (the WHOLE plane from one proof)" if rows == 1 else " (FA2 fixture c: coefficients (1, kappa) per column)"), sites=groups_of[gidx]["sites"], full_plane_from_one_proof=rows == 1)
        model, _ = build_model(f"singleton g{gidx} pair with values", a_model_groups(sched, only_groups=[gidx], include_tab=False), n_values, seed_for(seed, f"nc-pair-g{gidx}"), True)
        out[f"same_singleton_g{gidx}_with_pair"] = verdict(analyze_fast(model), 0, "the pair closes it")
    model, _ = build_model("naive port W(P3) per column", w_model_groups(sched, kind_for=lambda s: "base1"), 1, seed_for(seed, "nc-base1-W"), False, prox="pair")
    res = analyze_fast(model)
    out["single_base_row_per_claim_W_P3_per_column"] = verdict(res, ROWS_TODAY["W"], "six singleton W groups under one base row each: six functionals per column of only four W rows (Wk / Wv share row 1, gpack[gamma_A] / [gamma_M] share row 3) -> every W row RECOVERED per column (FA1 item 5's Wd shape six times)", w_rows_recovered=sorted(res["summary"]["recovered"]))
    out["single_base_row_per_claim_W_P3_per_column"]["verdict"] = "PASS" if res["disclosed_dim"] == ROWS_TODAY["W"] and len(res["summary"]["recovered"]) == ROWS_TODAY["W"] else "FAIL"
    # 3. a single proximity row instead of the pair
    g1 = [g for g in singletons if groups_of[g]["data_rows"] == [1]][0]
    model, _ = build_model("one pair claim + single prox row", a_model_groups(sched, only_groups=[g1], include_tab=False), 1, seed_for(seed, "nc-prox1"), False, prox="single")
    out["single_prox_row_singleton_pair_claim_per_column"] = verdict(analyze_fast(model), 1, "FA3 9 / FA2 14.4: 3 mask unknowns against 4 base dims (vector 2 + prox 2): the prox row borrows nothing and leaks one functional", group=g1)
    model, _ = build_model("one pair claim + prox pair", a_model_groups(sched, only_groups=[g1], include_tab=False), 1, seed_for(seed, "nc-prox1"), False, prox="pair")
    out["prox_pair_singleton_pair_claim_per_column"] = verdict(analyze_fast(model), 0, "4 against 4: the prox pair covers the prox vector by itself")
    model, _ = build_model("W(P3) pairs + single prox row", w_model_groups(sched, p3=True), 1, seed_for(seed, "nc-proxW"), False, prox="single")
    out["single_prox_row_W_P3_per_column"] = verdict(analyze_fast(model), 1, "13 mask unknowns against 14 dims on the attention W: the starved-prox shape (FA2 14.4) on a real layout")
    model, _ = build_model("whole A pairs + single prox row", a_model_groups(sched), 1, seed_for(seed, "nc-proxA"), False, prox="single")
    res = analyze_fast(model)
    out["single_prox_row_whole_A_per_column"] = verdict(res, None, "reported, not required: on the whole A the multi-member groups' pairs cover the prox entry by COMPOSITION (FA2 14.3) -- the coverage FA3 2.4 / U4 refuses to rely on; the schedule keeps the prox pair", composition_covers=res["disclosed_dim"] == 0)
    # 4. one seam pair dropped (z16c's), with the aliased rho_D opening in the model
    seam_group = next(g["group"] for g in sched["groups"]["A"] if g["seam"])
    z_role = next(s["role"] for s in A["sites"] if s["seam"] and s["site"].startswith("z16c"))
    rho_d_group = next(g["group"] for g in sched["groups"]["A"] if g["m"] == 18)
    model, _ = build_model("seam group + rho_D group, z16c seam pair dropped", a_model_groups(sched, kind_for=lambda s: "none" if s["role"] == z_role else "pair", only_groups=[seam_group, rho_d_group], include_tab=False), n_values, seed_for(seed, "nc-seam"), True)
    res = analyze_fast(model)
    out[f"seam_pair_dropped_with_values_n{n_values}"] = verdict(res, None, "SeamZ16c[0] unmasked: its terminal value is a public evaluation of z16c at the seam point (2 base functionals = 1 Fp2 value); per column the group vector is still covered by SeamXm8's pair, so the leak is in the VALUES channel", expected_at_least=2, dropped=z_role)
    out[f"seam_pair_dropped_with_values_n{n_values}"]["verdict"] = "PASS" if res["disclosed_dim"] >= 2 else "FAIL"
    model, _ = build_model("seam group + rho_D group, both seam pairs", a_model_groups(sched, only_groups=[seam_group, rho_d_group], include_tab=False), n_values, seed_for(seed, "nc-seam"), True)
    out[f"seam_pairs_both_with_values_n{n_values}"] = verdict(analyze_fast(model), 0, "both seam pairs present: xm8 / z16c under two pairs each")
    # 5. the 19 helper sums published individually (today's section 13), no u
    hg, helpers, tables = h_model_groups(sched, table_cap=table_cap)
    model, ex = build_model("H: pairs everywhere but the 19 sums published", hg, n_values, seed_for(seed, "nc-19sums"), True, h_special={"helpers": helpers, "public_sums": True})
    res = analyze_fast(model)
    S = ex["sum_rows"]
    rs, rf, rfs = rank_of(S, model.data), res["disclosed_dim"], rank_of(list(res["surviving_data_functionals"]) + S, model.data)
    out[f"nineteen_helper_sums_published_n{n_values}"] = verdict(res, None, "today's Cc::hsum: the 19 sums are 19 public Fp2 values = 38 base functionals of the helper columns, all of them surviving (they lie in F)", rank_of_the_19_sums=rs, rank_F=rf, rank_F_union_sums=rfs, nineteen_sums_disclosed=(rs == 38 and rfs == rf))
    out[f"nineteen_helper_sums_published_n{n_values}"]["verdict"] = "PASS" if rs == 38 and rfs == rf and rf >= 38 else "FAIL"
    # 6. the zero-sum row without its fresh pair
    hg, helpers, tables = h_model_groups(sched, table_cap=table_cap)
    model, ex = build_model("H: u zero-sum pair but no fresh pair u'", hg, n_values, seed_for(seed, "nc-nofresh"), True, h_special={"helpers": helpers, "tables": tables, "u": True, "zsum_fresh_pair": False})
    res = analyze_fast(model)
    out[f"zero_sum_row_without_fresh_pair_n{n_values}"] = verdict(res, None, "the zsum claim exposes u at rho_zs unmasked; u's columns are then partly determined and the LogUp sum vector discloses helper data beyond the identity", expected_more_than=2)
    out[f"zero_sum_row_without_fresh_pair_n{n_values}"]["verdict"] = "PASS" if res["disclosed_dim"] > 2 else "FAIL"
    # 7. a flipped-point RoPE claim sharing its pair with the unflipped claim
    for plane in ("q8", "k8"):
        flipped = next(s for s in A["sites"] if s["site"].startswith(plane + " @ FLIPPED"))
        base_site = next(s for s in A["sites"] if s["site"] == plane and s["group"] != flipped["group"] and s["m"] == 6)
        gs = [base_site["group"], flipped["group"]]
        model, _ = build_model(f"{plane}: flipped claim re-uses the unflipped pair", a_model_groups(sched, only_groups=gs, include_tab=False, share_mask={flipped["role"]: base_site["role"]}), n_values, seed_for(seed, f"nc-rope-{plane}"), True)
        res = analyze_fast(model)
        out[f"flipped_rope_{plane}_sharing_pair_with_values_n{n_values}"] = verdict(res, None, f"the flipped-point group's vector exposes the shared pair per column, which unmasks the unflipped terminal value of {plane} (1 Fp2 evaluation = 2 base functionals); FA3 2.3 item 6: a flipped-point claim needs its OWN reserved pair", expected_at_least=2, groups=gs)
        out[f"flipped_rope_{plane}_sharing_pair_with_values_n{n_values}"]["verdict"] = "PASS" if res["disclosed_dim"] >= 2 else "FAIL"
        model, _ = build_model(f"{plane}: flipped claim with its own pair", a_model_groups(sched, only_groups=gs, include_tab=False), n_values, seed_for(seed, f"nc-rope-{plane}"), True)
        out[f"flipped_rope_{plane}_own_pair_with_values_n{n_values}"] = verdict(analyze_fast(model), 0, "own pair: covered")
    return out


# ---- a tiny hand-checkable geometry, brute-forced over F_11^2 ---------------------

TINY_P, TINY_NR = 11, 7  # 7 is a non-residue mod 11 (squares: 1, 3, 4, 5, 9)


def t_mul(a: Tuple[int, int], b: Tuple[int, int]) -> Tuple[int, int]:
    return ((a[0] * b[0] + TINY_NR * a[1] * b[1]) % TINY_P, (a[0] * b[1] + a[1] * b[0]) % TINY_P)


def t_add(a: Tuple[int, int], b: Tuple[int, int]) -> Tuple[int, int]:
    return ((a[0] + b[0]) % TINY_P, (a[1] + b[1]) % TINY_P)


def brute_force_hiding(kinds: Sequence[str], n_cols: int = 2, with_values: bool = True, seed: int = 0, data_rows: int = 1) -> dict:
    """One group of len(kinds) single-plane members over n_cols columns in F_11^2; every mask
    assignment is enumerated and the multisets of the observation tuples (vector entries, and the
    terminal values when `with_values`) for two different data vectors are compared.  Identical
    multisets = perfect hiding in the linear model (the engine's disclosed_dim = 0); different =
    a distinguisher exists (disclosed_dim > 0).  Coefficients: lambda_k, a = 1 - e, c = e with e
    outside the base field, eq row weights of a random point, column weights of a random tail."""
    import itertools
    import random
    rnd = random.Random(seed)

    def fp2_nonbase() -> Tuple[int, int]:
        return (rnd.randrange(TINY_P), rnd.randrange(1, TINY_P))

    e = fp2_nonbase()
    a, c = ((1 - e[0]) % TINY_P, (-e[1]) % TINY_P), e
    lam = [fp2_nonbase() for _ in kinds]
    rb = data_rows.bit_length() - 1
    eqw = [(1, 0)]
    for _ in range(rb):
        r = fp2_nonbase()
        one_minus = ((1 - r[0]) % TINY_P, (-r[1]) % TINY_P)
        eqw = [t_mul(w, x) for w in eqw for x in (one_minus, r)]
    cw = [(1, 0)]
    for _ in range(n_cols.bit_length() - 1):
        r = fp2_nonbase()
        one_minus = ((1 - r[0]) % TINY_P, (-r[1]) % TINY_P)
        cw = [t_mul(w, x) for w in cw for x in (one_minus, r)]
    mask_slots = []  # (member, column, part) base scalars to enumerate
    for k, kind in enumerate(kinds):
        for j in range(n_cols):
            if kind == "pair":
                mask_slots += [(k, j, "re"), (k, j, "im")]
            elif kind == "base1":
                mask_slots += [(k, j, "re")]
            elif kind != "none":
                raise ValueError(kind)
    u_ = (0, 1)

    def observations(data: List[List[List[int]]], masks: Sequence[int]) -> Tuple:
        mv = {}
        for slot, val in zip(mask_slots, masks):
            mv[slot] = val
        vec = [(0, 0)] * n_cols
        per = [[(0, 0)] * n_cols for _ in kinds]
        for k in range(len(kinds)):
            for j in range(n_cols):
                d = (0, 0)
                for r in range(data_rows):
                    d = t_add(d, t_mul(eqw[r], (data[k][r][j], 0)))
                term = t_mul(a, d)
                m = (mv.get((k, j, "re"), 0), 0)
                if (k, j, "im") in mv:
                    m = t_add(m, t_mul(u_, (mv[(k, j, "im")], 0)))
                term = t_add(term, t_mul(c, m))
                per[k][j] = term
                vec[j] = t_add(vec[j], t_mul(lam[k], term))
        obs = list(vec)
        if with_values:
            for k in range(len(kinds)):
                v = (0, 0)
                for j in range(n_cols):
                    v = t_add(v, t_mul(cw[j], per[k][j]))
                obs.append(v)
        return tuple(obs)

    d1 = [[[rnd.randrange(TINY_P) for _ in range(n_cols)] for _ in range(data_rows)] for _ in kinds]
    d2 = [[[(x + 1 + rnd.randrange(TINY_P - 1)) % TINY_P for x in row] for row in mem] for mem in d1]
    assignments = list(itertools.product(range(TINY_P), repeat=len(mask_slots)))
    o1 = sorted(observations(d1, m) for m in assignments)
    o2 = sorted(observations(d2, m) for m in assignments)
    return {"kinds": list(kinds), "n_cols": n_cols, "with_values": with_values, "data_rows": data_rows, "assignments": len(assignments), "distinguishable": o1 != o2, "coefficients_p11": {"e": e, "lambda": lam}}


def engine_on_tiny_geometry(kinds: Sequence[str], n_cols: int = 2, with_values: bool = True, seed: int = 0, data_rows: int = 1) -> dict:
    """The same geometry in the engine (mod P, no prox: the brute force has none)."""
    rng = FA2.Rng(seed)
    b = Builder("tiny geometry", n_cols, rng, Symbols(rng), with_values)
    members = []
    for k, kind in enumerate(kinds):
        m = {"name": f"m{k}", "kind": kind, "data": [f"D{k}/r{r}" for r in range(data_rows)], "row_bits": None}
        if kind == "pair":
            m["mask"] = [f"R{k}_re", f"R{k}_im"]
        elif kind == "base1":
            m["mask"] = [f"R{k}"]
        members.append(m)
    b.add_group({"name": "g", "members": members})
    res = analyze_fast(b.model)
    return {"disclosed_dim": res["disclosed_dim"], "engines_agree": engines_agree(b.model)["agree"]}


# ----------------------------------------------------------------------------
# 5. the report, the machine-readable schedule, the CLI
# ----------------------------------------------------------------------------

RULE = ("every single-row mask site is an Fp2 pair (re, im) carried in the claim as (k1, k1 u); every plane claim of the attention A / W is such a site whatever its data-row count "
        "(the row bits weight the data rows, the pair's two rows make it Fp2-effective); every multi-row histogram slot keeps the block form (rows_i >= 2) and a single-row slot is a pair; "
        "every proximity row is a pair; the two internal seam terminals are pair-masked claims on the attention A's own xm8 / z16c rows; the 19 helper sums become ONE zero-sum row u "
        "(sum_j u[j] = 0) added to the packed column-wise sum of the 19 helper columns minus the 10 g_T rows, masked by u itself (zero-sum pair) and the fresh pair u' at rho_zs; "
        "no collapse; every mask row drawn once before its commitment exists and consumed by exactly one opening (FA3 sections 1-4)")

ASSUMPTIONS = [
    "linear model (FA2 sections 13, 15): the verifier's view is the set of group vector entries, proximity entries and terminal values, each a public-coefficient linear form in base-field rows",
    "masks and pads independent and uniform; challenges are seeded stand-ins avoiding the base field (the 2^-64 degeneracies FA2 excludes: e in Fp, lambda = 0, Fp-dependent prox rhos, a row-bit coordinate in Fp)",
    "hashing, Merkle paths, salted leaves, the sampled columns / folded pads and the CFS-masked sumcheck round messages are outside the model (nonlinear); transcript conditioning (a simulator) is outside the model",
    "integer-range side information and cross-proof correlation are outside the model",
    "row bits are taken from the inventory's symbolic points (constants and shared symbols consistent); column tails are per-group stand-ins in the with-values models (n = 4 / 8 columns), which cannot represent the 8-coordinate tails",
    "multi-row histogram slots (256 / 64 / 2 rows) are compressed to 2 rows in the with-values models (FA2's tiny-fixture convention); the per-column models use the real row counts",
    "the two bilinear matmul terminals (score, PV) and, under P3, the QKV / Wo terminals carry the second-extension coefficient form ((1 - e2)(1 - e), (1 - e2) e); it changes no rank (FA3 section 9)",
    "the six private claimed sums (inventory finding 2 / R6) and the CFS slot list (R5) are protocol items outside this linear model; nothing here settles them",
    "numerical rank is not a simulation proof",
]

MASK_KINDS = {
    "pair": {"rows": 2, "claim_form": "[(DATA slice, k0 = 1 - e, p), (R_re, k1 = e, tail p), (R_im, k1 u, tail p)]; masked terminal (1 - e) fin + e (R_re~ + u R_im~)", "hiding": "per column k1 (R_re + u R_im) ranges over Fp2 whenever k1 != 0"},
    "block": {"rows": "rows_i = max(size_i, n) / n >= 2", "claim_form": "[(slot rows, (1 - e_tab) ext_i, rho_tab[k_i..]), (mask rows, e_tab ext_i, rho_tab[k_i..])]", "hiding": "per column e_tab ext_i sum_r eq_r R[r] ranges over Fp2 when two eq_r are Fp-independent (row bit outside Fp)"},
    "zero_sum_pair": {"rows": 2, "claim_form": "u = (u_re, u_im), sum_j u_re[j] = sum_j u_im[j] = 0, added to the LogUp sum vector; zsum claim at rho_zs masked by the fresh pair u'", "hiding": "the surviving space is exactly the public LogUp identity (FA2 14.5, re-verified here at 19 + 10 planes)"},
    "prox_pair": {"rows": 2, "claim_form": "no claim: the two rows enter only the proximity combination with two independent challenges", "hiding": "per column Fp-span{rho_re, rho_im} = Fp2"},
}


def site_row(s: dict) -> dict:
    """FA3 section 2.2's columns for one site."""
    return {"role": s["role"], "site": s.get("site", s.get("table")), "commitment": s["commitment"], "group": s["group"], "group_key": s["group_key"], "m": s["m"],
            "data_rows": s["data_rows"], "data_row_range": s.get("data_row_range", [s.get("data_row_range_re"), s.get("data_row_range_im")]), "single_row": s.get("single_row"),
            "mask_kind": s["mask_kind"], "mask_rows": s["mask_rows"], "coefficients": s["coefficients"], "proof_field": s["proof_field"],
            "section": s.get("section"), "source": s.get("source"), "claim_index": s.get("claim_index"), "aliases": s.get("aliases"), "added": s.get("added", False), "seam": s.get("seam", False), "receipt_only": s.get("receipt_only", False)}


def schedule_record(inv_path: str, tool_sha: str, scheds: Dict[str, dict], costs: Dict[str, dict], group_counts: dict) -> dict:
    """The machine-readable schedule (docs/zkmatrix-poc/zk60_private_attention_schedule.json)."""
    blk, rp, rx = scheds["block"], scheds["receipt_pair"], scheds["receipt_exempt"]
    A, H, W = blk["commitments"]["A"], blk["commitments"]["H"], blk["commitments"]["W"]
    ep_pair = [s for s in rp["commitments"]["A"]["sites"] if s.get("receipt_only")]
    ep_exempt = [s for s in rx["commitments"]["A"]["sites"] if s.get("receipt_only")]
    rec = {
        "tool": "scripts/zk60_attention_pair_schedule.py", "tool_sha256": tool_sha, "inventory": inv_path, "inventory_sha256": sha256_file(inv_path),
        "profile": {"shape": "A00/B3: T = 32, d = 16, f = 16, H = 2, KV heads = 1, head_dim = 8, INT16, 256 columns, inverse rate 8, Q = 256", "commitment_rows_today": ROWS_TODAY, "no_collapse": True, "P1": "inputs, outputs, activations hidden; weights public (W plain)", "P3": "weights hidden too (W pair-masked)"},
        "rule": RULE, "mask_kinds": MASK_KINDS, "assumptions": ASSUMPTIONS,
        "columns": ["role", "site", "commitment", "group", "group_key", "m", "data_rows", "data_row_range", "single_row", "mask_kind", "mask_rows (indices appended after the data rows)", "coefficients per privacy mode", "proof_field"],
        "tables": blk["tables"],
        "added_sites": {"count": 12, "source": ADDED_SOURCE, "grouping": "under pcs::group_claims' key rule the 12 rho_2 sub-row tails collide pairwise with each other and with the 4 existing rho_Dsq singletons (the section-1 g0-g7 pattern): 8 two-member groups; forced-singleton grouping (12 + 4 singletons) gives the same verdict and the same row cost", "group_counts": group_counts},
        "commitments": {
            "A": {"regions": A["regions"], "rows_block": A["rows_block"], "rows_receipt_endpoints_paired": rp["commitments"]["A"]["rows_total"], "rows_receipt_endpoints_exempt": rx["commitments"]["A"]["rows_total"],
                  "sites": [site_row(s) for s in A["sites"]], "histogram_slots": [site_row(s) for s in A["histogram_masks"]], "prox": A["prox"],
                  "receipt_endpoints": {"pair_masked": [site_row(s) for s in ep_pair], "exempt_public": [site_row(s) for s in ep_exempt], "ruling_needed": "inventory O-6 / FA4 M13: whether the declared boundary discloses x_in / xres2 is a product ruling; both forms are rank-verified"},
                  "groups": [{"group": g["group"], "key": g["key"], "m": g["m"], "sites": g["sites"], "data_rows": g["data_rows"], "singleton": g["singleton"], "seam": g["seam"]} for g in A["groups"]]},
            "H": {"regions": H["regions"], "rows": H["rows_total"], "sites": [site_row(s) for s in H["sites"]], "g_T_sites": [site_row(s) for s in H["g_T_sites"]], "h_u": H["h_u"], "h_up": H["h_up"], "prox": H["prox"], "replaced_sum_claims": H["replaced_sum_claims"],
                  "groups": [{"group": g["group"], "key": g["key"], "m": g["m"], "sites": g["sites"], "sum_group": g["sum_group"]} for g in H["groups"]]},
            "W": {"rows_P1": W["rows_total_P1"], "rows_P3": W["rows_total_P3"], "sites": [site_row(s) for s in W["sites"]], "prox": W["prox"], "groups": [{"group": g["group"], "key": g["key"], "m": g["m"], "sites": g["sites"]} for g in W["groups"]]},
        },
        "row_cost": costs,
    }
    return rec


def run_all(inv_path: str, seed: int = DEFAULT_SEED, n_values: int = 4, brute_force: bool = True) -> Tuple[dict, dict]:
    """Everything: returns (results, schedule record).  results['failures'] lists every FAIL."""
    inv = load_inventory(inv_path)
    tool_sha = sha256_file(os.path.abspath(__file__))
    results: dict = {"tool": "scripts/zk60_attention_pair_schedule.py", "tool_sha256": tool_sha, "fa2_engine": "scripts/zk60_fable_joint_rank.py", "fa2_engine_sha256": sha256_file(os.path.join(_HERE, "zk60_fable_joint_rank.py")),
                     "inventory": inv_path, "inventory_sha256": sha256_file(inv_path), "seed": seed, "n_values": n_values, "assumptions": ASSUMPTIONS, "rule": RULE, "profiles": {}, "failures": []}
    scheds, costs, gcounts = {}, {}, {}
    for key, profile, ep in (("block", "block", "pair"), ("receipt_pair", "receipt", "pair"), ("receipt_exempt", "receipt", "exempt")):
        inv_claims = claims_for_profile(inv, profile)
        inv_groups = build_groups(inv_claims)
        xc = cross_check_groups(inv_groups, inv, profile)
        sched = build_schedule(inv, profile, endpoints=ep)
        cov = schedule_coverage_checks(sched)
        cost = row_cost(sched)
        pos = run_positive(sched, seed, n_values=n_values)
        entry = {"profile": profile, "endpoints_mode": ep, "inventory_group_cross_checks": xc, "schedule_coverage_checks": cov, "row_cost": cost,
                 "group_counts": {cm: len(sched["groups"][cm]) for cm in COMMITMENTS}, "singleton_groups": {cm: sum(1 for g in sched["groups"][cm] if g["singleton"]) for cm in COMMITMENTS},
                 "rank_verdicts": pos}
        if key == "block":
            entry["negative_controls"] = run_negative(sched, seed, n_values=n_values)
            forced = build_schedule(inv, profile, endpoints=ep, force_singletons=True)
            model, _ = build_model("whole A per column, added sites forced singleton", a_model_groups(forced), 1, seed_for(seed, "A-col-forced"), False)
            entry["added_sites_forced_singletons"] = {"group_counts": {cm: len(forced["groups"][cm]) for cm in COMMITMENTS}, "singleton_groups_A": sum(1 for g in forced["groups"]["A"] if g["singleton"]), "whole_A_per_column": verdict(analyze_fast(model), 0, "the 12 added rho_2 sites as their own singleton groups (the coordinator's reading): same verdict"), "row_cost_A_rows": row_cost(forced)["A"]["rows"]}
            gcounts = {"key_rule": entry["group_counts"], "key_rule_singletons_A": entry["singleton_groups"]["A"], "forced_singletons": entry["added_sites_forced_singletons"]["group_counts"], "forced_singletons_A": entry["added_sites_forced_singletons"]["singleton_groups_A"]}
        results["profiles"][key] = entry
        scheds[key], costs[key] = sched, cost
        for name, v in list(pos.items()) + list(entry.get("negative_controls", {}).items()) + ([("added_sites_forced_singletons", entry["added_sites_forced_singletons"]["whole_A_per_column"])] if key == "block" else []):
            if v.get("verdict") == "FAIL":
                results["failures"].append(f"{key}/{name}")
        if not xc["all_pass"]:
            results["failures"].append(f"{key}/inventory_group_cross_checks")
        if not cov["all_pass"]:
            results["failures"].append(f"{key}/schedule_coverage_checks")
    if brute_force:
        bf = {}
        for kinds, dr, wv in ((["pair"], 1, True), (["base1"], 1, True), (["none"], 1, True), (["base1"], 2, True), (["base1", "base1"], 1, False), (["base1", "base1"], 1, True)):
            b = brute_force_hiding(kinds, 2, wv, seed=3, data_rows=dr)
            e = engine_on_tiny_geometry(kinds, 2, wv, seed=3, data_rows=dr)
            ok = b["distinguishable"] == (e["disclosed_dim"] > 0) and e["engines_agree"]
            name = f"{'+'.join(kinds)}_rows{dr}_{'values' if wv else 'vector_only'}"
            bf[name] = {**b, "engine_disclosed_dim": e["disclosed_dim"], "engines_agree": e["engines_agree"], "verdict": "PASS" if ok else "FAIL", "reading": "identical multisets <=> disclosed 0" if not b["distinguishable"] else "distinguishable <=> disclosed > 0"}
            if not ok:
                results["failures"].append(f"brute_force/{name}")
        results["brute_force_tiny_field_p11"] = bf
    results["summary"] = summarize(results)
    record = schedule_record(inv_path, tool_sha, scheds, costs, gcounts)
    record["rank_summary"] = results["summary"]
    return results, record


def summarize(results: dict) -> dict:
    blk = results["profiles"]["block"]
    rv = blk["rank_verdicts"]
    nonzero_groups = {k: v["disclosed_dim"] for k, v in rv.items() if k.startswith("group_") and v["disclosed_dim"] != 0}
    return {
        "disclosed_dim_per_commitment_per_column": {"A_block_P1": rv["whole_A_per_column_P1"]["disclosed_dim"], "A_block_P3": rv["whole_A_per_column_P3"]["disclosed_dim"],
                                                    "A_receipt_endpoints_paired_P1": results["profiles"]["receipt_pair"]["rank_verdicts"]["whole_A_per_column_P1"]["disclosed_dim"],
                                                    "A_receipt_endpoints_exempt_P1": results["profiles"]["receipt_exempt"]["rank_verdicts"]["whole_A_per_column_P1"]["disclosed_dim"],
                                                    "H": rv["whole_H_per_column"]["disclosed_dim"], "W_P3": rv["whole_W_P3_per_column"]["disclosed_dim"]},
        "disclosed_dim_per_commitment_with_values": {f"A_block_n{results['n_values']}": rv[f"whole_A_with_values_n{results['n_values']}_P1"]["disclosed_dim"], f"H_n{results['n_values']}": rv[f"whole_H_with_values_n{results['n_values']}"]["disclosed_dim"], "H_n8": rv["whole_H_with_values_n8"]["disclosed_dim"], f"W_P3_n{results['n_values']}": rv[f"whole_W_P3_with_values_n{results['n_values']}"]["disclosed_dim"]},
        "H_residual_is_exactly_the_public_LogUp_identity": rv["whole_H_with_values_n8"]["residual_is_exactly_the_public_identity"] and rv[f"whole_H_with_values_n{results['n_values']}"]["residual_is_exactly_the_public_identity"],
        "groups_with_nonzero_disclosure": nonzero_groups,
        "negative_controls": {k: v["disclosed_dim"] for k, v in blk["negative_controls"].items()},
        "row_cost": {k: {"A_rows": results["profiles"][k]["row_cost"]["A"]["rows"], "H_rows": results["profiles"][k]["row_cost"]["H"]["rows"], "W_P3_rows": results["profiles"][k]["row_cost"]["W"]["P3_rows"], "A_plus_H_extra_bytes": results["profiles"][k]["row_cost"]["A_plus_H_extra_bytes"]} for k in results["profiles"]},
        "failures": results["failures"],
    }


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="the attention A / H / W pair schedule and its rank verdict (O-1, O-2)")
    ap.add_argument("--inventory", required=True)
    ap.add_argument("--out", required=True, help="results JSON (rank verdicts, controls, row cost)")
    ap.add_argument("--schedule-out", required=True, help="the machine-readable schedule JSON")
    ap.add_argument("--seed", type=int, default=DEFAULT_SEED)
    ap.add_argument("--n-values", type=int, default=4, help="columns of the with-values models (power of two)")
    ap.add_argument("--no-brute-force", action="store_true")
    args = ap.parse_args(argv)
    results, record = run_all(args.inventory, seed=args.seed, n_values=args.n_values, brute_force=not args.no_brute_force)
    for path, obj in ((args.out, results), (args.schedule_out, record)):
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        with open(path, "w") as f:
            json.dump(obj, f, indent=1, sort_keys=True)
            f.write("\n")
    s = results["summary"]
    print("disclosed_dim per column:", s["disclosed_dim_per_commitment_per_column"])
    print("disclosed_dim with values:", s["disclosed_dim_per_commitment_with_values"], "| H residual = public identity:", s["H_residual_is_exactly_the_public_LogUp_identity"])
    print("groups with nonzero disclosure:", s["groups_with_nonzero_disclosure"] or "none")
    print("row cost:", s["row_cost"])
    print("negative controls:", s["negative_controls"])
    print("failures:", results["failures"] or "none")
    return 1 if results["failures"] else 0


if __name__ == "__main__":
    sys.exit(main())
