#!/usr/bin/env python3
"""zk60_opus_repaired_capture.py -- O1/O2: a SEPARATE digest-bound parser and joint
linear observation model for the schema-2 captures of the experimental repaired
profile `ffn-v3-mr1-fresh-poc/1` (analysis only, stdlib, exact integers).

Reviewer: Opus 5, independent reviewer, 2026-09-08 session (tasks O1 and O2 of
docs/zkmatrix-poc/ZK60_OPUS_QUEUE.md).  Implementation pin:
b41d036c4c1eb1ed9272494815d742d0ccf29934 ("Implement fresh paired-mask FFN proof of
concept"); review worktree a8a1bc7 (branch zk60-fable-review).

WHY A SEPARATE TOOL.  `scripts/zk60_fable_joint_capture.py` (Claude Fable 5.1, FA7) is
archived: its digest-bound results describe the LEGACY schema-1 `ffn-v3-function-1`
captures and must keep that meaning, so it is neither edited nor re-pointed.  This
module imports it by path and REUSES its finite-field routines, its exact rank /
null-space algebra (`zk60_fable_joint_rank.py`) and, unchanged, its joint model class
`RoleModel` -- the same mathematics, the same included/excluded observation classes.
Only the parser and the recomputed layout are new, because the repaired profile has a
different claim shape.  Fable's legacy results and their attribution are untouched.

WHAT THIS CONSUMES.  One capture per proof, named <proof_sha256>.json, schema 2, from
hashline/src/zk_ffn_observation_json.rs::export_repaired_if_requested.  The profile,
transcript domain, source commit, coverage, shape, shifts, PCS parameters and pad width
are FIXED CONSTANTS here: this tool accepts the experimental fresh-PoC function-1
profile at T32/d16/f16, log_cols 8, inverse rate 8, Q = 256 and NOTHING else.

WHAT IS RECOMPUTED, NOT TRUSTED.  The expected commitment row counts, every mask/data
row index, every claim's part slices, the claim -> group shape, the row roles and site
names, and the prover's own `ZkLayoutV3::describe()` text are all recomputed here from
the layout rules of the source (zkp-core/src/ffn_v3/statement.rs::Layout::new,
hashline/src/zk.rs::ZkLayoutV3::with_masks / build_claims_zk_v3 / build_w_zclaims_v3,
hashline/src/zk_ffn_observation_json.rs::write_row_roles / coefficient_tag).  The
capture's declared `layout_description`, `layout_digest`, `row_roles`, `q_pad` and
`coefficient_tag`s are then COMPARED to the recomputation; a disagreement refuses the
capture.  A legacy schema-1 capture relabelled with the repaired coverage is refused by
these checks, not by its label.

WHAT THE MODEL IS (unchanged from FA7 section 5; see that document).  One base-field
unknown per (row, column) of a commitment, so rows opened by several claims alias.
Observations, all Fp2 (each = two base-field rows):
  * every message coordinate v_g[j], j < n, of every group vector
  * every coordinate prox[j], j < n, of the proximity vector
  * every terminal (claim value), including the H sum claim's public 0
  * H only: the public constraint sum_j u[j] = 0 on the zero-sum pair
EXCLUDED, exactly as in FA7 (stated, not costed, and NOT expanded here): the pad
coordinates v[n .. n+Q), the Q sampled encoded columns (values, salts, Merkle paths),
the CFS mask commitment and masked sumcheck round messages, repeated proofs of the
same witness, and the Merkle root over unopened columns.  This tool validates the
STRUCTURE of the pads and sampled columns (widths, ranges, path lengths) without
putting them in the linear model.

WHAT CHANGED IN THE PROFILE (round 16).  Scalar A/W mask sites and the A/H/W proximity
sites now hold two independent base-field rows: a claim's mask part is followed by a
second part on the next row with coefficient multiplied by u (`ZkLayoutV3::pair_claim`).
Singleton multiplicity tables get mask pairs; the two larger table blocks (2^16 and
2^14 here) keep their block masks and stay 2-part claims.  H's helper pairs and its
zero-sum pair are unchanged; H's proximity site became a pair.

Usage:
    python3 scripts/zk60_opus_repaired_capture.py preflight \\
        --captures-dir /tmp/zk60-round16/captures \\
        --manifest results/zk60_round16_validation.json \\
        --cross-manifest /tmp/zk60-round16/summary.json \\
        -o results/zk60_opus_capture_preflight.json
    python3 scripts/zk60_opus_repaired_capture.py analyze \\
        --captures-dir /tmp/zk60-round16/captures \\
        --manifest results/zk60_round16_validation.json \\
        --cross-manifest /tmp/zk60-round16/summary.json \\
        --legacy-dir /tmp/zk60-round11/final-observations \\
        -o results/zk60_opus_repaired_capture_analysis.json
    python3 scripts/zk60_opus_repaired_capture.py check CAPTURE.json
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import sys
import time
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, filename))
    mod = importlib.util.module_from_spec(spec)
    sys.modules.setdefault(name, mod)
    spec.loader.exec_module(mod)
    return mod


# Fable's archived FA7 tool: imported read-only for its field/rank routines and its
# joint model.  Never edited, never re-pointed at these captures.
C = _load("zk60_fable_joint_capture", "zk60_fable_joint_capture.py")
R = C.R

P = R.P
NONRESIDUE = R.NONRESIDUE
ONE, ZERO, U = R.ONE, R.ZERO, R.U
f2_add, f2_sub, f2_mul, f2_neg = R.f2_add, R.f2_sub, R.f2_mul, R.f2_neg
eq_table_msb = R.eq_table_msb

Fp2 = Tuple[int, int]

REVIEWER = "Opus 5, independent reviewer, 2026-09-08 session (O1/O2)"
REVIEW_WORKTREE_COMMIT = "a8a1bc7"

# ---------------------------------------------------------------------------
# the ONE profile this tool accepts (hashline/src/zk_ffn_fresh_poc.rs)
# ---------------------------------------------------------------------------
SCHEMA = 2
KIND = "zk60-verifier-observations"
COVERAGE = "ffn-v3-mr1-fresh-poc-function-1"
PROFILE = "ffn-v3-mr1-fresh-poc/1"
TRANSCRIPT_DOMAIN = "hashline-zk-mr1/ffn-v3-mr1-fresh-poc/1"
SOURCE_COMMIT = "b41d036c4c1eb1ed9272494815d742d0ccf29934"
SHAPE = {"t": 32, "d": 16, "f": 16}
SHIFTS = (7, 0, 14, 6)
LOG_COLS = 8
INV_RATE = 8
NUM_COL_CHECKS = 256
Q_PAD = 256
WEIGHT_POLICY = "fresh-per-proof"
PROOF_DIGEST_ENCODING = "legacy logical payload; experimental profile is bound in transcript"
PREDICATE = False  # function 1: no predicate rows are allocated
TAB_SLOTS = 6
TAG_ACT16 = 3
TAG_INT16 = 4

EXPECTED_ROWS = {"A": 698, "H": 1326, "W": 11}
EXPECTED_GROUP_SHAPE = {"A": [7, 3, 1, 1, 6], "H": [3, 1, 1, 6, 1], "W": [2, 1]}
ROLE_ORDER = {"P1": ["A", "H"], "P3": ["W", "A", "H"]}

EXCLUDED_CLASSES = dict(C.EXCLUDED_CLASSES)
INCLUDED_CLASSES = dict(C.INCLUDED_CLASSES)

STRUCTURE_ONLY_CLASSES = {
    "pads": "width and count only (every clear vector has exactly n + Q entries); the pad VALUES stay outside the linear model",
    "sampled_columns": "count, index range, per-column value width, salt width and Merkle path length only; the column VALUES stay outside the linear model",
}


class RepairedCaptureError(C.CaptureError):
    """A repaired-profile capture that must be refused."""


# ---------------------------------------------------------------------------
# small helpers (exact integers only)
# ---------------------------------------------------------------------------


def sha256_file(path: str) -> str:
    return C.sha256_file(path)


def _is_int(x) -> bool:
    return isinstance(x, int) and not isinstance(x, bool)


def _fp(x, what: str) -> int:
    if not _is_int(x) or x < 0 or x >= P:
        raise RepairedCaptureError(f"{what}: not an integer in [0, p): {x!r}")
    return x


def _fp2(x, what: str) -> Fp2:
    if not isinstance(x, list) or len(x) != 2:
        raise RepairedCaptureError(f"{what}: not an Fp2 pair: {x!r}")
    return (_fp(x[0], what + ".c0"), _fp(x[1], what + ".c1"))


def _bytes32(x, what: str) -> str:
    if not isinstance(x, list) or len(x) != 32 or not all(_is_int(b) and 0 <= b < 256 for b in x):
        raise RepairedCaptureError(f"{what}: not 32 bytes")
    return bytes(x).hex()


def _uint(x, what: str, lo: int = 0, hi: Optional[int] = None) -> int:
    if not _is_int(x) or x < lo or (hi is not None and x > hi):
        raise RepairedCaptureError(f"{what}: not an integer in [{lo}, {hi}]: {x!r}")
    return x


def _v2(x: int) -> int:
    return (x & -x).bit_length() - 1


# ---------------------------------------------------------------------------
# the layout, recomputed from the source rules
#   zkp-core/src/ffn_v3/statement.rs :: Layout::new, table tags/rows
#   hashline/src/zk.rs               :: ZkLayoutV3::with_masks (mr1 = true)
# ---------------------------------------------------------------------------


def base_layout(t: int, d: int, f: int) -> dict:
    """zkp-core Layout::new: the element offsets of every plane."""
    if t <= 0 or t & (t - 1):
        raise RepairedCaptureError(f"t_rows {t} is not a power of two")
    log_t = _v2(t)
    log_db, log_fb = min(_v2(d), 12), min(_v2(f), 12)
    db, fb = 1 << log_db, 1 << log_fb
    if log_db < 4 or log_fb < 4 or d % db or f % fb:
        raise RepairedCaptureError(f"shape d {d} / f {f}: need >= 16 | d, f")
    nb_d, nb_f = d // db, f // fb
    tfb, tdb = t * fb, t * db
    off = 0
    planes: Dict[str, List[int]] = {}
    for pl in ("g8", "rg", "a16", "u16", "ru", "h16", "rh"):
        planes[pl] = [off + b * tfb for b in range(nb_f)]
        off += nb_f * tfb
    for pl in ("X", "z16", "rd"):
        planes[pl] = [off + c * tdb for c in range(nb_d)]
        off += nb_d * tdb
    a_len = off
    wb, log_wb = db * fb, log_db + log_fb
    woff = 0
    wblocks: Dict[str, List[int]] = {}
    for pl in ("Wg", "Wu", "Wd"):
        wblocks[pl] = [woff + k * wb for k in range(nb_d * nb_f)]
        woff += nb_d * nb_f * wb
    w_len = woff
    hoff = 0
    hpairs: Dict[str, List[Tuple[int, int]]] = {}
    for pl, sz in (("hg", tfb), ("hu", tfb), ("hh", tfb), ("hz", tdb)):
        cnt = nb_f if pl != "hz" else nb_d
        hpairs[pl] = []
        for _ in range(cnt):
            hpairs[pl].append((hoff, hoff + sz))
            hoff += 2 * sz
    h_len = hoff
    return {"t": t, "d": d, "f": f, "log_t": log_t, "log_db": log_db, "log_fb": log_fb, "nb_d": nb_d, "nb_f": nb_f,
            "tfb": tfb, "tdb": tdb, "wb": wb, "log_wb": log_wb, "log_a_min": log_t + min(log_db, log_fb),
            "planes": planes, "a_len": a_len, "wblocks": wblocks, "w_len": w_len, "hpairs": hpairs, "h_len": h_len,
            "ls_f": log_t + log_fb, "ls_d": log_t + log_db}


def table_specs(shifts: Sequence[int]) -> List[Tuple[int, int]]:
    """zk.rs::table_specs_v3 with tag_rem_v3 / rem_rows of zkp-core."""
    out = [(TAG_ACT16, 256), (TAG_INT16, 1 << 16)]
    for sh in shifts:
        if sh < -8 or sh > 16:
            raise RepairedCaptureError(f"shift {sh} outside the supported window -8..=16")
        out.append((64 + sh + 8, 1 if sh <= 0 else 1 << sh))
    return out


def zk_layout(t: int, d: int, f: int, log_cols: int, shifts: Sequence[int], mr1: bool = True) -> dict:
    """hashline/src/zk.rs::ZkLayoutV3::with_masks, mr1 = the repaired schedule."""
    lay = base_layout(t, d, f)
    width = 2 if mr1 else 1
    log_n = min(log_cols, lay["log_a_min"])
    a_n = 1 << log_n
    log_s = max(log_n, 16)
    nb_d, nb_f = lay["nb_d"], lay["nb_f"]
    specs = table_specs(shifts)
    if len(specs) != TAB_SLOTS:
        raise RepairedCaptureError(f"{len(specs)} table slots, expected {TAB_SLOTS}")

    r = lay["a_len"] // a_n

    def nxt(k: int) -> int:
        nonlocal r
        v = r
        r += k
        return v

    a_mf = [nxt(width) for _ in range(7 * nb_f)]
    a_md = [nxt(width) for _ in range(3 * nb_d)]
    a_mgu = [nxt(width) for _ in range(nb_d)]
    a_mdd = [nxt(width) for _ in range(nb_f)]
    a_prox = nxt(width)
    tabs = []
    for tag, size in specs:
        if size <= 0 or size & (size - 1):
            raise RepairedCaptureError(f"table size {size} is not a power of two")
        log_size = max(_v2(size), log_n)
        rows = (1 << log_size) // a_n
        a_row = nxt(rows)
        a_mask = nxt(2 if (mr1 and rows == 1) else rows)
        tabs.append({"tag": tag, "size": size, "log_size": log_size, "rows": rows, "a_row": a_row, "a_mask": a_mask})
    a_rows = r

    r = lay["h_len"] // a_n
    h_mf = [(nxt(1), nxt(1)) for _ in range(3 * nb_f)]
    h_md = [(nxt(1), nxt(1)) for _ in range(nb_d)]
    h_u = (nxt(1), nxt(1))
    h_up = (nxt(1), nxt(1))
    h_prox = nxt(width)
    for tb in tabs:
        tb["h_re"] = nxt(tb["rows"])
        tb["h_im"] = nxt(tb["rows"])
        tb["h_mre"] = nxt(tb["rows"])
        tb["h_mim"] = nxt(tb["rows"])
    h_rows = r

    log_wn = min(log_cols, lay["log_wb"])
    w_n = 1 << log_wn
    r = lay["w_len"] // w_n
    w_mgu = [nxt(width) for _ in range(2 * nb_d * nb_f)]
    w_mdd = [nxt(width) for _ in range(nb_f * nb_d)]
    w_prox = nxt(width)
    w_rows = r

    return {"lay": lay, "mr1": mr1, "width": width, "log_n": log_n, "a_n": a_n, "log_s": log_s,
            "a_mf": a_mf, "a_md": a_md, "a_mgu": a_mgu, "a_mdd": a_mdd, "a_prox": a_prox, "a_rows": a_rows,
            "h_mf": h_mf, "h_md": h_md, "h_u": h_u, "h_up": h_up, "h_prox": h_prox, "h_rows": h_rows,
            "tabs": tabs, "log_wn": log_wn, "w_n": w_n, "w_mgu": w_mgu, "w_mdd": w_mdd, "w_prox": w_prox,
            "w_rows": w_rows}


def _mask_range(zl: dict, row: int) -> List[int]:
    return list(range(row, row + zl["width"]))


def a_mask_rows(zl: dict) -> List[int]:
    v: List[int] = []
    for r in zl["a_mf"] + zl["a_md"] + zl["a_mgu"] + zl["a_mdd"]:
        v.extend(_mask_range(zl, r))
    for tb in zl["tabs"]:
        v.extend(range(tb["a_mask"], tb["a_mask"] + (2 if (zl["mr1"] and tb["rows"] == 1) else tb["rows"])))
    return v


def h_mask_rows(zl: dict) -> List[int]:
    v: List[int] = []
    for a, b in zl["h_mf"] + zl["h_md"]:
        v.extend([a, b])
    v.extend([zl["h_u"][0], zl["h_u"][1], zl["h_up"][0], zl["h_up"][1]])
    for tb in zl["tabs"]:
        v.extend(range(tb["h_mre"], tb["h_mre"] + tb["rows"]))
        v.extend(range(tb["h_mim"], tb["h_mim"] + tb["rows"]))
    return v


def w_mask_rows(zl: dict) -> List[int]:
    v: List[int] = []
    for r in zl["w_mgu"] + zl["w_mdd"]:
        v.extend(_mask_range(zl, r))
    return v


def describe(zl: dict) -> str:
    """hashline/src/zk.rs::ZkLayoutV3::describe (the mr1 branch), byte for byte.
    Rust {:?} renders Vec<usize> as `[a, b]`, Range as `a..b`, (a, b) as `(a, b)`."""
    def vec(v: Sequence[int]) -> str:
        return "[" + ", ".join(str(x) for x in v) + "]"

    def rng(row: int) -> str:
        return f"{row}..{row + zl['width']}"

    out = [
        f"{PROFILE}: n={zl['a_n']} wn={zl['w_n']} pred={'true' if PREDICATE else 'false'}",
        f"A rows={zl['a_rows']} masks={vec(a_mask_rows(zl))} prox pair={rng(zl['a_prox'])}",
        f"H rows={zl['h_rows']} masks={vec(h_mask_rows(zl))} prox pair={rng(zl['h_prox'])} "
        f"zero-sum pair=({zl['h_u'][0]}, {zl['h_u'][1]})",
        f"fresh P3 W rows={zl['w_rows']} masks={vec(w_mask_rows(zl))} prox pair={rng(zl['w_prox'])}",
    ]
    for tb in zl["tabs"]:
        out.append(f"table tag={tb['tag']} size={tb['size']} rows={tb['rows']} data={tb['a_row']} "
                   f"mask={tb['a_mask']} kind={'pair' if tb['rows'] == 1 else 'block'}")
    return "\n".join(out)


# ---------------------------------------------------------------------------
# the expected claims and row roles, recomputed from the claim builders
#   zk.rs::build_claims_zk_v3 / build_w_zclaims_v3 (+ ZkLayoutV3::pair_claim)
#   zk_ffn_observation_json.rs::write_row_roles / coefficient_tag
# ---------------------------------------------------------------------------


def coefficient_tag(role: str, claim: int, part: int, p3: bool) -> str:
    """zk_ffn_observation_json.rs::coefficient_tag, reproduced exactly."""
    def pair(data: str, mask: str, i: int) -> str:
        return data if i == 0 else (mask if i == 1 else f"({mask})*u")

    if role == "A":
        if claim <= 6:
            return pair("1-e_f", "e_f", part)
        if claim <= 9:
            return pair("1-e_dz", "e_dz", part)
        if claim == 10:
            return pair("(1-e_gu2)*(1-e_gu)" if p3 else "1-e_gu", "(1-e_gu2)*e_gu" if p3 else "e_gu", part)
        if claim == 11:
            return pair("(1-e_d2)*(1-e_d)" if p3 else "1-e_d", "(1-e_d2)*e_d" if p3 else "e_d", part)
        return pair(f"(1-e_tab)*ext_{claim - 12}", f"e_tab*ext_{claim - 12}", part)
    if role == "W":
        if claim < 2:
            return pair("(1-e_gu2)*(1-e_gu)", "e_gu2", part)
        return pair("(1-e_d2)*(1-e_d)", "e_d2", part)
    if claim == 11:
        return "public LogUp sum coefficient"
    e = "e_f" if claim <= 2 else ("e_dz" if claim == 3 else ("e_zs" if claim == 4 else "e_tab"))
    base = f"1-{e}" if part < 2 else e
    ext = f"*ext_{claim - 5}" if claim >= 5 else ""
    return f"({base}){ext}" + ("*u" if part % 2 == 1 else "")


def expected_role(role: str, zl: dict, privacy: str) -> dict:
    """The claim list, the row roles (kind + declared site name) and the plane names
    the repaired verifier builds for this role.  `claims[k]` is a list of parts
    (offset, log_size, kind, plane_name, has_point, fixed_coef|None)."""
    lay = zl["lay"]
    n, log_n = zl["a_n"], zl["log_n"]
    nb_d, nb_f = lay["nb_d"], lay["nb_f"]
    ls_f, ls_d = lay["ls_f"], lay["ls_d"]
    p3 = privacy == "P3"
    tabs = zl["tabs"]

    # declared row roles: zk_ffn_observation_json.rs::write_row_roles
    if role == "A":
        rows = zl["a_rows"]
    elif role == "H":
        rows = zl["h_rows"]
    else:
        rows = zl["w_rows"]
    declared = [("data", f"{role}.data[{r}]") for r in range(rows)]

    def setrow(row: int, kind: str, site: str) -> None:
        if row < 0 or row >= rows:
            raise RepairedCaptureError(f"{role}: recomputed row {row} outside {rows} rows")
        declared[row] = (kind, site)

    claims: List[List[tuple]] = []
    sum_claim = None
    zero_sum_claim = None
    zero_sum_pair = None
    prox_rows: List[int] = []

    if role == "A":
        for site, rowsv in (("a_mf", zl["a_mf"]), ("a_md", zl["a_md"]), ("a_mgu", zl["a_mgu"]), ("a_mdd", zl["a_mdd"])):
            for i, rr in enumerate(rowsv):
                setrow(rr, "mask", f"{site}[{i}].re")
                setrow(rr + 1, "mask", f"{site}[{i}].im")
        for i, tb in enumerate(tabs):
            for j in range(tb["rows"]):
                setrow(tb["a_row"] + j, "data", f"tab[{i}].multiplicity[{j}]")
            for j in range(2 if tb["rows"] == 1 else tb["rows"]):
                setrow(tb["a_mask"] + j, "mask", f"tab[{i}].a_mask[{j}]")
        setrow(zl["a_prox"], "prox", "a_prox.re")
        setrow(zl["a_prox"] + 1, "prox", "a_prox.im")
        prox_rows = [zl["a_prox"], zl["a_prox"] + 1]
        pl = lay["planes"]
        for b in range(nb_f):
            for i, name in enumerate(("g8", "rg", "a16", "u16", "ru", "h16", "rh")):
                m = zl["a_mf"][7 * b + i]
                claims.append([(pl[name][b], ls_f, "data", f"{name}[{b}]", True, None),
                               (m * n, log_n, "mask", f"a_mf[{7 * b + i}].re", True, None),
                               ((m + 1) * n, log_n, "mask", f"a_mf[{7 * b + i}].im", True, None)])
        for c in range(nb_d):
            for i, name in enumerate(("X", "z16", "rd")):
                m = zl["a_md"][3 * c + i]
                claims.append([(pl[name][c], ls_d, "data", f"{name}[{c}]", True, None),
                               (m * n, log_n, "mask", f"a_md[{3 * c + i}].re", True, None),
                               ((m + 1) * n, log_n, "mask", f"a_md[{3 * c + i}].im", True, None)])
        for c in range(nb_d):
            m = zl["a_mgu"][c]
            claims.append([(pl["X"][c], ls_d, "data", f"X[{c}]", True, None),
                           (m * n, log_n, "mask", f"a_mgu[{c}].re", True, None),
                           ((m + 1) * n, log_n, "mask", f"a_mgu[{c}].im", True, None)])
        for b in range(nb_f):
            m = zl["a_mdd"][b]
            claims.append([(pl["h16"][b], ls_f, "data", f"h16[{b}]", True, None),
                           (m * n, log_n, "mask", f"a_mdd[{b}].re", True, None),
                           ((m + 1) * n, log_n, "mask", f"a_mdd[{b}].im", True, None)])
        for i, tb in enumerate(tabs):
            ls = tb["log_size"]
            parts = [(tb["a_row"] * n, ls, "data", f"tab[{i}]", True, None),
                     (tb["a_mask"] * n, ls, "mask", f"tab[{i}].a_mask", True, None)]
            if tb["rows"] == 1:  # pair_claim: the mask part repeats one slice higher, coef * u
                parts.append((tb["a_mask"] * n + (1 << ls), ls, "mask", f"tab[{i}].a_mask", True, None))
            claims.append(parts)
        group_shape = [7 * nb_f, 3 * nb_d, nb_d, nb_f, TAB_SLOTS]

    elif role == "H":
        for site, rowsv in (("h_mf", zl["h_mf"]), ("h_md", zl["h_md"])):
            for i, (re, im) in enumerate(rowsv):
                setrow(re, "mask", f"{site}[{i}].re")
                setrow(im, "mask", f"{site}[{i}].im")
        for site, (re, im) in (("h_u", zl["h_u"]), ("h_up", zl["h_up"])):
            setrow(re, "mask", f"{site}.re")
            setrow(im, "mask", f"{site}.im")
        for i, tb in enumerate(tabs):
            for site, row, kind in (("h_re", tb["h_re"], "data"), ("h_im", tb["h_im"], "data"),
                                    ("h_mre", tb["h_mre"], "mask"), ("h_mim", tb["h_mim"], "mask")):
                for j in range(tb["rows"]):
                    setrow(row + j, kind, f"tab[{i}].{site}[{j}]")
        setrow(zl["h_prox"], "prox", "h_prox.re")
        setrow(zl["h_prox"] + 1, "prox", "h_prox.im")
        prox_rows = [zl["h_prox"], zl["h_prox"] + 1]
        hp = lay["hpairs"]
        for b in range(nb_f):
            for i, name in enumerate(("hg", "hu", "hh")):
                re, im = hp[name][b]
                m = zl["h_mf"][3 * b + i]
                claims.append([(re, ls_f, "data", f"{name}[{b}].re", True, None),
                               (im, ls_f, "data", f"{name}[{b}].im", True, None),
                               (m[0] * n, log_n, "mask", f"h_mf[{3 * b + i}].re", True, None),
                               (m[1] * n, log_n, "mask", f"h_mf[{3 * b + i}].im", True, None)])
        for c in range(nb_d):
            re, im = hp["hz"][c]
            m = zl["h_md"][c]
            claims.append([(re, ls_d, "data", f"hz[{c}].re", True, None),
                           (im, ls_d, "data", f"hz[{c}].im", True, None),
                           (m[0] * n, log_n, "mask", f"h_md[{c}].re", True, None),
                           (m[1] * n, log_n, "mask", f"h_md[{c}].im", True, None)])
        zero_sum_claim = len(claims)
        zero_sum_pair = (zl["h_u"][0], zl["h_u"][1])
        claims.append([(zl["h_u"][0] * n, log_n, "mask", "u.re", True, None),
                       (zl["h_u"][1] * n, log_n, "mask", "u.im", True, None),
                       (zl["h_up"][0] * n, log_n, "mask", "u'.re", True, None),
                       (zl["h_up"][1] * n, log_n, "mask", "u'.im", True, None)])
        for i, tb in enumerate(tabs):
            ls = tb["log_size"]
            claims.append([(tb["h_re"] * n, ls, "data", f"h_t[{i}].re", True, None),
                           (tb["h_im"] * n, ls, "data", f"h_t[{i}].im", True, None),
                           (tb["h_mre"] * n, ls, "mask", f"h_t[{i}].mask.re", True, None),
                           (tb["h_mim"] * n, ls, "mask", f"h_t[{i}].mask.im", True, None)])
        sum_parts: List[tuple] = []
        for b in range(nb_f):
            for name in ("hg", "hu", "hh"):
                re, im = hp[name][b]
                sum_parts.append((re, ls_f, "data", f"{name}[{b}].re", False, ONE))
                sum_parts.append((im, ls_f, "data", f"{name}[{b}].im", False, U))
        for c in range(nb_d):
            re, im = hp["hz"][c]
            sum_parts.append((re, ls_d, "data", f"hz[{c}].re", False, ONE))
            sum_parts.append((im, ls_d, "data", f"hz[{c}].im", False, U))
        for i, tb in enumerate(tabs):
            ls = tb["log_size"]
            sum_parts.append((tb["h_re"] * n, ls, "data", f"h_t[{i}].re", False, f2_neg(ONE)))
            sum_parts.append((tb["h_im"] * n, ls, "data", f"h_t[{i}].im", False, f2_neg(U)))
        sum_parts.append((zl["h_u"][0] * n, log_n, "mask", "u.re", False, ONE))
        sum_parts.append((zl["h_u"][1] * n, log_n, "mask", "u.im", False, U))
        sum_claim = len(claims)
        claims.append(sum_parts)
        group_shape = [3 * nb_f, nb_d, 1, TAB_SLOTS, 1]

    else:  # W, mode P3 only
        if not p3:
            raise RepairedCaptureError("W: only the P3 fresh-private W opening is a privacy role")
        wn, log_wn, log_wb = zl["w_n"], zl["log_wn"], lay["log_wb"]
        for site, rowsv in (("w_mgu", zl["w_mgu"]), ("w_mdd", zl["w_mdd"])):
            for i, rr in enumerate(rowsv):
                setrow(rr, "mask", f"{site}[{i}].re")
                setrow(rr + 1, "mask", f"{site}[{i}].im")
        setrow(zl["w_prox"], "prox", "w_prox.re")
        setrow(zl["w_prox"] + 1, "prox", "w_prox.im")
        prox_rows = [zl["w_prox"], zl["w_prox"] + 1]
        wbk = lay["wblocks"]
        for ri, tag in enumerate(("Wg", "Wu")):
            for c in range(nb_d):
                for b in range(nb_f):
                    k = ri * nb_d * nb_f + c * nb_f + b
                    m = zl["w_mgu"][k]
                    claims.append([(wbk[tag][c * nb_f + b], log_wb, "data", f"{tag}[{c}][{b}]", True, None),
                                   (m * wn, log_wn, "mask", f"w_mgu[{k}].re", True, None),
                                   ((m + 1) * wn, log_wn, "mask", f"w_mgu[{k}].im", True, None)])
        for b in range(nb_f):
            for c in range(nb_d):
                k = b * nb_d + c
                m = zl["w_mdd"][k]
                claims.append([(wbk["Wd"][k], log_wb, "data", f"Wd[{b}][{c}]", True, None),
                               (m * wn, log_wn, "mask", f"w_mdd[{k}].re", True, None),
                               ((m + 1) * wn, log_wn, "mask", f"w_mdd[{k}].im", True, None)])
        group_shape = [2 * nb_d * nb_f, nb_f * nb_d]

    tags = [[coefficient_tag(role, k, pi, p3) for pi in range(len(c))] for k, c in enumerate(claims)]
    return {"rows": rows, "claims": claims, "declared_row_roles": declared, "prox_rows": prox_rows,
            "sum_claim": sum_claim, "zero_sum_claim": zero_sum_claim, "zero_sum_pair": zero_sum_pair,
            "group_shape": group_shape, "coefficient_tags": tags,
            "n": zl["w_n"] if role == "W" else zl["a_n"],
            "log_n": zl["log_wn"] if role == "W" else zl["log_n"]}


# ---------------------------------------------------------------------------
# the parser
# ---------------------------------------------------------------------------


class RepairedRoleObs:
    """One role's validated observation, exposing exactly the attribute surface
    `zk60_fable_joint_capture.RoleModel` consumes, so the FA7 joint model runs on
    these captures unchanged."""

    def __init__(self, raw: dict, privacy: str, zl: dict):
        self.role = raw.get("role")
        if self.role not in ("W", "A", "H"):
            raise RepairedCaptureError(f"role {self.role!r} is not W/A/H")
        w = f"role {self.role}"
        exp = expected_role(self.role, zl, privacy)
        self.layout = exp
        params = raw.get("params")
        if not isinstance(params, dict):
            raise RepairedCaptureError(f"{w}: params missing")
        self.log_n = _uint(params.get("log_cols"), f"{w}.params.log_cols", 1, 16)
        self.inv_rate = _uint(params.get("inv_rate"), f"{w}.params.inv_rate", 1)
        self.num_col_checks = _uint(params.get("num_col_checks"), f"{w}.params.num_col_checks", 0)
        if (self.log_n, self.inv_rate, self.num_col_checks) != (exp["log_n"], INV_RATE, NUM_COL_CHECKS):
            raise RepairedCaptureError(
                f"{w}: PCS parameters (log_cols {self.log_n}, inv_rate {self.inv_rate}, "
                f"num_col_checks {self.num_col_checks}) are not the fixed "
                f"({exp['log_n']}, {INV_RATE}, {NUM_COL_CHECKS}) of {PROFILE}")
        self.n = 1 << self.log_n
        com = raw.get("commitment")
        if not isinstance(com, dict):
            raise RepairedCaptureError(f"{w}: commitment missing")
        self.rows = _uint(com.get("rows"), f"{w}.commitment.rows", 1)
        if self.rows != exp["rows"] or self.rows != EXPECTED_ROWS[self.role]:
            raise RepairedCaptureError(
                f"{w}: commitment has {self.rows} rows; the recomputed {PROFILE} layout has "
                f"{exp['rows']} (fixed expectation {EXPECTED_ROWS[self.role]})")
        self.root = _bytes32(com.get("root"), f"{w}.commitment.root")
        self.before_state = _bytes32(raw.get("before_state"), f"{w}.before_state")
        self.after_state = _bytes32(raw.get("after_state"), f"{w}.after_state")
        self.before_next = _fp2(raw.get("before_next_challenge"), f"{w}.before_next_challenge")
        self.after_next = _fp2(raw.get("after_next_challenge"), f"{w}.after_next_challenge")
        n, rows = self.n, self.rows

        # ---- claims: parsed, then matched against the recomputed layout ----
        claims_raw = raw.get("claims")
        if not isinstance(claims_raw, list) or not claims_raw:
            raise RepairedCaptureError(f"{w}: claims missing or empty")
        if len(claims_raw) != len(exp["claims"]):
            raise RepairedCaptureError(f"{w}: {len(claims_raw)} claims, the recomputed layout builds {len(exp['claims'])}")
        self.claims: List[dict] = []
        self.part_kind: List[List[str]] = []
        self.part_name: List[List[str]] = []
        self.part_tag: List[List[str]] = []
        for k, c in enumerate(claims_raw):
            if not isinstance(c, dict):
                raise RepairedCaptureError(f"{w}.claims[{k}]: not an object")
            value = _fp2(c.get("value"), f"{w}.claims[{k}].value")
            parts_raw = c.get("parts")
            if not isinstance(parts_raw, list) or not parts_raw:
                raise RepairedCaptureError(f"{w}.claims[{k}].parts missing or empty")
            e = exp["claims"][k]
            if len(parts_raw) != len(e):
                raise RepairedCaptureError(
                    f"{w}.claims[{k}]: {len(parts_raw)} parts, the recomputed repaired layout has {len(e)} "
                    f"(a missing pair row, or a legacy single-mask claim)")
            parts = []
            kinds, names, tgs = [], [], []
            for pi, (p, ep) in enumerate(zip(parts_raw, e)):
                pw = f"{w}.claims[{k}].parts[{pi}]"
                if not isinstance(p, dict):
                    raise RepairedCaptureError(f"{pw}: not an object")
                offset = _uint(p.get("offset"), pw + ".offset", 0)
                log_size = _uint(p.get("log_size"), pw + ".log_size", 0, 40)
                coef = _fp2(p.get("coefficient"), pw + ".coefficient")
                point_raw = p.get("point")
                if not isinstance(point_raw, list):
                    raise RepairedCaptureError(f"{pw}.point: not a list")
                point = [_fp2(x, f"{pw}.point[{i}]") for i, x in enumerate(point_raw)]
                if (offset, log_size) != (ep[0], ep[1]):
                    raise RepairedCaptureError(
                        f"{pw}: slice ({offset}, 2^{log_size}) is not the recomputed layout's "
                        f"({ep[0]}, 2^{ep[1]}) for {ep[3]}")
                if bool(point) != bool(ep[4]):
                    raise RepairedCaptureError(f"{pw}: point presence {bool(point)} != the layout's {bool(ep[4])}")
                if point and len(point) != log_size:
                    raise RepairedCaptureError(f"{pw}: point has {len(point)} coordinates for log_size {log_size}")
                if log_size < self.log_n:
                    raise RepairedCaptureError(f"{pw}: log_size {log_size} < log_cols {self.log_n}")
                if offset % n:
                    raise RepairedCaptureError(f"{pw}: offset {offset} is not row-aligned (n = {n})")
                if ep[5] is not None and coef != ep[5]:
                    raise RepairedCaptureError(f"{pw}: fixed sum-claim coefficient {coef} is not the layout's {ep[5]}")
                tag = p.get("coefficient_tag")
                if not isinstance(tag, str) or not tag:
                    raise RepairedCaptureError(f"{pw}: coefficient_tag missing (schema 2 requires a symbolic tag on every part)")
                if tag != exp["coefficient_tags"][k][pi]:
                    raise RepairedCaptureError(f"{pw}: coefficient_tag {tag!r} is not the recomputed {exp['coefficient_tags'][k][pi]!r}")
                row0 = offset // n
                nrows = (1 << log_size) // n
                if row0 + nrows > rows:
                    raise RepairedCaptureError(f"{pw}: rows [{row0}, {row0 + nrows}) exceed the commitment's {rows} rows")
                rb = log_size - self.log_n
                rw = eq_table_msb(point[:rb]) if point else [ONE] * nrows
                tail = point[rb:] if point else None
                parts.append({"offset": offset, "log_size": log_size, "coef": coef, "point": point,
                              "row0": row0, "nrows": nrows, "rw": rw, "tail": tail})
                kinds.append(ep[2])
                names.append(ep[3])
                tgs.append(tag)
            self.claims.append({"value": value, "parts": parts, "group": None})
            self.part_kind.append(kinds)
            self.part_name.append(names)
            self.part_tag.append(tgs)
        self._check_pair_coefficients(privacy)

        # ---- groups ----
        groups_raw = raw.get("groups")
        if not isinstance(groups_raw, list) or not groups_raw:
            raise RepairedCaptureError(f"{w}: groups missing or empty")
        self.groups: List[dict] = []
        seen: Dict[int, int] = {}
        for gi, g in enumerate(groups_raw):
            gw = f"{w}.groups[{gi}]"
            if not isinstance(g, dict):
                raise RepairedCaptureError(f"{gw}: not an object")
            members = g.get("members")
            lambdas = g.get("lambdas")
            if not isinstance(members, list) or not members:
                raise RepairedCaptureError(f"{gw}.members missing or empty")
            if not isinstance(lambdas, list) or len(lambdas) != len(members):
                raise RepairedCaptureError(f"{gw}: lambda count does not match the {len(members)} members")
            mem = []
            for m in members:
                m = _uint(m, gw + ".members[]", 0, len(self.claims) - 1)
                if m in seen:
                    raise RepairedCaptureError(f"{gw}: claim {m} is already a member of group {seen[m]}")
                seen[m] = gi
                mem.append(m)
                self.claims[m]["group"] = gi
            lams = [_fp2(x, f"{gw}.lambdas[{i}]") for i, x in enumerate(lambdas)]
            key = g.get("key")
            if not isinstance(key, dict):
                raise RepairedCaptureError(f"{gw}.key missing")
            kt = key.get("tail")
            if not isinstance(kt, list):
                raise RepairedCaptureError(f"{gw}.key.tail missing")
            tail = [_fp2(x, f"{gw}.key.tail[{i}]") for i, x in enumerate(kt)]
            if key.get("offset") != 0 or key.get("len") != n:
                raise RepairedCaptureError(f"{gw}.key: offset {key.get('offset')!r} / len {key.get('len')!r} unsupported (expected 0 / {n})")
            if tail and len(tail) != self.log_n:
                raise RepairedCaptureError(f"{gw}.key.tail has {len(tail)} coordinates, expected 0 or {self.log_n}")
            vec_raw = g.get("vector")
            if not isinstance(vec_raw, list) or len(vec_raw) != n + Q_PAD:
                raise RepairedCaptureError(
                    f"{gw}.vector: {len(vec_raw) if isinstance(vec_raw, list) else 'no'} entries, expected n + Q = {n + Q_PAD}")
            vector = [_fp2(x, f"{gw}.vector[{i}]") for i, x in enumerate(vec_raw)]
            cw = eq_table_msb(tail) if tail else [ONE] * n
            for m in mem:
                for pi, p in enumerate(self.claims[m]["parts"]):
                    if p["tail"] is None:
                        if tail:
                            raise RepairedCaptureError(f"{gw}: member {m} part {pi} has no point but the key has a tail")
                    elif p["tail"] != tail:
                        raise RepairedCaptureError(f"{gw}: member {m} part {pi} column tail differs from the group key")
            lhs = ZERO
            for j in range(n):
                lhs = f2_add(lhs, f2_mul(cw[j], vector[j]))
            rhs = ZERO
            for m, lam in zip(mem, lams):
                rhs = f2_add(rhs, f2_mul(lam, self.claims[m]["value"]))
            if lhs != rhs:
                raise RepairedCaptureError(
                    f"{gw}: the clear vector does not reproduce its members' terminals "
                    f"(sum_j eq(tail)[j] v[j] != sum_k lambda_k value_k)")
            self.groups.append({"members": mem, "lambdas": lams, "tail": tail, "cw": cw, "vector": vector,
                                "pad_entries": len(vector) - n})
        for k, c in enumerate(self.claims):
            if c["group"] is None:
                raise RepairedCaptureError(f"{w}: claim {k} belongs to no group")
        shape_got = [len(g["members"]) for g in self.groups]
        if shape_got != exp["group_shape"] or shape_got != EXPECTED_GROUP_SHAPE[self.role]:
            raise RepairedCaptureError(
                f"{w}: group member counts {shape_got} are not the recomputed {exp['group_shape']} "
                f"(fixed expectation {EXPECTED_GROUP_SHAPE[self.role]})")

        # ---- proximity ----
        rhos = raw.get("proximity_rhos")
        if not isinstance(rhos, list) or len(rhos) != rows:
            raise RepairedCaptureError(f"{w}.proximity_rhos: {len(rhos) if isinstance(rhos, list) else 'no'} entries for {rows} rows")
        self.rho = [_fp2(x, f"{w}.proximity_rhos[{i}]") for i, x in enumerate(rhos)]
        pv = raw.get("proximity_vector")
        if not isinstance(pv, list) or len(pv) != n + Q_PAD:
            raise RepairedCaptureError(
                f"{w}.proximity_vector: {len(pv) if isinstance(pv, list) else 'no'} entries, expected n + Q = {n + Q_PAD}")
        self.prox_vector = [_fp2(x, f"{w}.proximity_vector[{i}]") for i, x in enumerate(pv)]

        # ---- sampled columns (structure only; values stay outside the model) ----
        cols = raw.get("columns")
        if not isinstance(cols, list) or len(cols) != self.num_col_checks:
            raise RepairedCaptureError(f"{w}.columns: {len(cols) if isinstance(cols, list) else 'no'} entries for {self.num_col_checks} column checks")
        domain = n * self.inv_rate
        path_len = domain.bit_length() - 1
        self.sampled_columns: List[int] = []
        for ci, col in enumerate(cols):
            cwn = f"{w}.columns[{ci}]"
            if not isinstance(col, dict):
                raise RepairedCaptureError(f"{cwn}: not an object")
            idx = _uint(col.get("index"), cwn + ".index", 0, domain - 1)
            vals = col.get("values")
            if not isinstance(vals, list) or len(vals) != rows:
                raise RepairedCaptureError(f"{cwn}.values: not {rows} entries")
            for i, v in enumerate(vals):
                _fp(v, f"{cwn}.values[{i}]")
            _bytes32(col.get("salt"), cwn + ".salt")
            path = col.get("path")
            if not isinstance(path, list) or len(path) != path_len:
                raise RepairedCaptureError(f"{cwn}.path: {len(path) if isinstance(path, list) else 'no'} nodes, expected {path_len} for a 2^{path_len} leaf domain")
            for i, node in enumerate(path):
                _bytes32(node, f"{cwn}.path[{i}]")
            self.sampled_columns.append(idx)
        self.column_domain = domain
        self.q_pad = _uint(raw.get("q_pad"), f"{w}.q_pad", 0)
        if self.q_pad != Q_PAD or self.q_pad != self.num_col_checks:
            raise RepairedCaptureError(f"{w}.q_pad {self.q_pad} is not the fixed Q = {Q_PAD} = num_col_checks")

        # ---- declared row roles vs the recomputation ----
        rr = raw.get("row_roles")
        if not isinstance(rr, list) or len(rr) != rows:
            raise RepairedCaptureError(f"{w}.row_roles: {len(rr) if isinstance(rr, list) else 'no'} entries for {rows} rows")
        seen_rows = set()
        self.declared_kind: List[str] = [""] * rows
        self.declared_site: List[str] = [""] * rows
        for i, entry in enumerate(rr):
            if not isinstance(entry, dict):
                raise RepairedCaptureError(f"{w}.row_roles[{i}]: not an object")
            row = _uint(entry.get("row"), f"{w}.row_roles[{i}].row", 0, rows - 1)
            if row in seen_rows:
                raise RepairedCaptureError(f"{w}.row_roles: row {row} has more than one entry")
            seen_rows.add(row)
            kind, site = entry.get("kind"), entry.get("site")
            if kind not in ("data", "mask", "prox") or not isinstance(site, str):
                raise RepairedCaptureError(f"{w}.row_roles[{i}]: kind {kind!r} / site {site!r} malformed")
            if (kind, site) != exp["declared_row_roles"][row]:
                raise RepairedCaptureError(
                    f"{w}.row_roles[row {row}]: declared ({kind}, {site!r}) is not the recomputed "
                    f"{exp['declared_row_roles'][row]}")
            self.declared_kind[row] = kind
            self.declared_site[row] = site
        if len(seen_rows) != rows:
            raise RepairedCaptureError(f"{w}.row_roles: {len(seen_rows)} distinct rows for {rows} commitment rows")

        # ---- public linear constraints ----
        plc = raw.get("public_linear_constraints")
        if not isinstance(plc, list):
            raise RepairedCaptureError(f"{w}.public_linear_constraints missing")
        if self.role == "H":
            want = [{"rows": list(exp["zero_sum_pair"]), "relation": "sum over the n message columns = 0",
                     "source": "zsum sumcheck"}]
            if plc != want:
                raise RepairedCaptureError(f"H.public_linear_constraints {plc!r} is not the recomputed {want!r}")
        elif plc:
            raise RepairedCaptureError(f"{w}.public_linear_constraints must be empty, got {plc!r}")
        self.public_linear_constraints = plc

        # ---- row roles for the model: plane names from the claim mapping (FA7) ----
        self.row_kind = ["unref"] * rows
        self.row_name = [""] * rows
        for k, c in enumerate(self.claims):
            for pi, p in enumerate(c["parts"]):
                kind, name = self.part_kind[k][pi], self.part_name[k][pi]
                for r in range(p["row0"], p["row0"] + p["nrows"]):
                    if self.row_kind[r] not in ("unref", kind):
                        raise RepairedCaptureError(f"{w}: row {r} is data in one claim and mask in another")
                    self.row_kind[r] = kind
                    if not self.row_name[r]:
                        self.row_name[r] = name
        unref = [r for r in range(rows) if self.row_kind[r] == "unref"]
        if unref != exp["prox_rows"]:
            raise RepairedCaptureError(
                f"{w}: unreferenced rows {unref[:6]}{'...' if len(unref) > 6 else ''} are not exactly the "
                f"proximity PAIR {exp['prox_rows']}")
        for i, r in enumerate(exp["prox_rows"]):
            self.row_kind[r] = "prox"
            self.row_name[r] = {"A": "a_prox", "H": "h_prox", "W": "w_prox"}[self.role] + (".re" if i == 0 else ".im")
        for r in range(rows):
            if self.row_kind[r] != self.declared_kind[r]:
                raise RepairedCaptureError(
                    f"{w}: row {r} is {self.row_kind[r]} by the claim mapping but {self.declared_kind[r]} in row_roles")
        self.data_rows = [r for r in range(rows) if self.row_kind[r] == "data"]
        self.mask_rows = [r for r in range(rows) if self.row_kind[r] in ("mask", "prox")]

    # -- coefficient-form checks derived from build_claims_zk_v3 ---------------
    def _check_pair_coefficients(self, privacy: str) -> None:
        """The repaired pair form: the appended part is the previous one times u
        (`ZkLayoutV3::pair_claim`), H's (re, im) parts are (k, k u), and the masked
        claims of the f/d/zero-sum sumchecks split unity as (1 - e, e)."""
        w = f"role {self.role}"
        cl = self.claims
        if self.role in ("A", "W"):
            for k, c in enumerate(cl):
                ps = c["parts"]
                if len(ps) == 3:
                    if f2_mul(ps[1]["coef"], U) != ps[2]["coef"]:
                        raise RepairedCaptureError(f"{w}.claims[{k}]: the paired mask part is not (k, k*u)")
                    if ps[2]["offset"] != ps[1]["offset"] + (1 << ps[1]["log_size"]) or ps[2]["log_size"] != ps[1]["log_size"]:
                        raise RepairedCaptureError(f"{w}.claims[{k}]: the paired mask part is not the next slice")
                elif len(ps) != 2:
                    raise RepairedCaptureError(f"{w}.claims[{k}]: {len(ps)} parts")
            if self.role == "A":
                for k in list(range(10)) + ([10, 11] if privacy == "P1" else []):
                    ps = cl[k]["parts"]
                    if f2_add(ps[0]["coef"], ps[1]["coef"]) != ONE:
                        raise RepairedCaptureError(f"{w}.claims[{k}]: (data, mask) coefficients are not (1 - e, e)")
        else:
            for k, c in enumerate(cl):
                ps = c["parts"]
                if k == self.layout["sum_claim"]:
                    continue
                if len(ps) != 4:
                    raise RepairedCaptureError(f"{w}.claims[{k}]: {len(ps)} parts, expected the 4-part (re, im) pair form")
                if f2_mul(ps[0]["coef"], U) != ps[1]["coef"] or f2_mul(ps[2]["coef"], U) != ps[3]["coef"]:
                    raise RepairedCaptureError(f"{w}.claims[{k}]: not the (k, k u) Fp2 pair form on data and mask")
                if k <= 4 and f2_add(ps[0]["coef"], ps[2]["coef"]) != ONE:
                    raise RepairedCaptureError(f"{w}.claims[{k}]: (data, mask) coefficients are not (1 - e, e)")
            if cl[self.layout["sum_claim"]]["value"] != ZERO:
                raise RepairedCaptureError(f"{w}: the LogUp sum claim's value is not 0")

    # -- the RoleObs surface the FA7 model uses -------------------------------
    def planes(self) -> Dict[str, List[int]]:
        out: Dict[str, List[int]] = {}
        for r in self.data_rows:
            name = self.row_name[r]
            for sfx in (".re", ".im"):
                if name.endswith(sfx):
                    name = name[: -len(sfx)]
            out.setdefault(name, []).append(r)
        return out

    def aliases(self) -> Dict[str, dict]:
        by_row: Dict[int, List[int]] = {}
        for k, c in enumerate(self.claims):
            for p in c["parts"]:
                for r in range(p["row0"], p["row0"] + p["nrows"]):
                    by_row.setdefault(r, []).append(k)
        out: Dict[str, dict] = {}
        for r, ks in by_row.items():
            if len(ks) > 1:
                e = out.setdefault(self.row_name[r], {"rows": [], "claims": sorted(set(ks)), "kind": self.row_kind[r]})
                e["rows"].append(r)
        for e in out.values():
            rws = sorted(e["rows"])
            e["rows"] = rws if len(rws) <= 4 else [rws[0], "...", rws[-1]]
            e["row_count"] = len(rws)
        return out

    def summary(self) -> dict:
        return {"role": self.role, "log_cols": self.log_n, "n": self.n, "inv_rate": self.inv_rate,
                "num_col_checks": self.num_col_checks, "q_pad": self.q_pad, "rows": self.rows,
                "data_rows": len(self.data_rows), "mask_rows": len(self.mask_rows),
                "prox_rows": self.layout["prox_rows"], "claims": len(self.claims),
                "parts_per_claim": [len(c["parts"]) for c in self.claims],
                "groups": [len(g["members"]) for g in self.groups],
                "pad_entries_per_vector": self.groups[0]["pad_entries"],
                "sampled_columns": len(self.sampled_columns),
                "distinct_sampled_columns": len(set(self.sampled_columns)),
                "column_domain": self.column_domain,
                "root": self.root, "before_state": self.before_state, "after_state": self.after_state,
                "before_next_challenge": list(self.before_next), "after_next_challenge": list(self.after_next),
                "zero_sum_pair_rows": self.layout.get("zero_sum_pair"),
                "public_linear_constraints": self.public_linear_constraints,
                "aliased_rows": self.aliases()}


class RepairedCapture:
    """A schema-2 `ffn-v3-mr1-fresh-poc/1` capture, refused unless it is exactly that."""

    def __init__(self, path: str, expected_capture_sha256: Optional[str] = None, require_digest_name: bool = True):
        self.path = path
        self.file_sha256 = sha256_file(path)
        self.bytes = os.path.getsize(path)
        if expected_capture_sha256 is not None and expected_capture_sha256 != self.file_sha256:
            raise RepairedCaptureError(
                f"{os.path.basename(path)}: file sha256 {self.file_sha256[:16]}.. differs from the manifest's {expected_capture_sha256[:16]}..")
        with open(path, "rb") as fh:
            raw_bytes = fh.read()
        try:
            raw = json.loads(raw_bytes)
        except ValueError as e:
            raise RepairedCaptureError(f"{os.path.basename(path)}: malformed JSON ({e})") from None
        del raw_bytes
        if not isinstance(raw, dict):
            raise RepairedCaptureError("capture is not a JSON object")
        for field, want in (("schema", SCHEMA), ("kind", KIND), ("coverage", COVERAGE), ("profile", PROFILE),
                            ("transcript_domain", TRANSCRIPT_DOMAIN), ("source_commit", SOURCE_COMMIT),
                            ("weight_policy", WEIGHT_POLICY), ("proof_digest_encoding", PROOF_DIGEST_ENCODING)):
            got = raw.get(field)
            if got != want:
                raise RepairedCaptureError(f"{field} {got!r} is not {want!r} (this tool accepts only {PROFILE} at {SOURCE_COMMIT[:7]})")
        if raw.get("fully_verified") is not True:
            raise RepairedCaptureError("capture is not marked fully_verified")
        if raw.get("slot") is not None or raw.get("k") is not None:
            raise RepairedCaptureError(f"slot {raw.get('slot')!r} / k {raw.get('k')!r} must be null: the fresh PoC registers no model slot")
        self.privacy = raw.get("privacy")
        if self.privacy not in ("P1", "P3"):
            raise RepairedCaptureError(f"privacy {self.privacy!r} is not P1/P3")
        if raw.get("field_modulus") != P or raw.get("extension_nonresidue") != NONRESIDUE:
            raise RepairedCaptureError("field modulus / nonresidue are not Goldilocks / u^2 = 7")
        shape = raw.get("shape")
        if not isinstance(shape, dict) or {k: shape.get(k) for k in ("t", "d", "f")} != SHAPE:
            raise RepairedCaptureError(f"shape {shape!r} is not the fixed {SHAPE} of {PROFILE}")
        self.shape = dict(SHAPE)
        shifts = raw.get("shifts")
        if not isinstance(shifts, list) or tuple(shifts) != SHIFTS:
            raise RepairedCaptureError(f"shifts {shifts!r} are not the fixed {list(SHIFTS)}")
        self.shifts = tuple(SHIFTS)
        ps = raw.get("proof_sha256")
        if not isinstance(ps, str) or len(ps) != 64 or any(ch not in "0123456789abcdef" for ch in ps):
            raise RepairedCaptureError("proof_sha256 is not a lowercase 64-hex digest")
        self.proof_sha256 = ps
        stem = os.path.basename(path)
        if require_digest_name and stem != ps + ".json":
            raise RepairedCaptureError(f"file name {stem} is not the digest name {ps[:16]}...json")

        # the layout: recomputed here, then compared to the prover's own description
        self.zl = zk_layout(SHAPE["t"], SHAPE["d"], SHAPE["f"], LOG_COLS, SHIFTS, mr1=True)
        self.layout_description_recomputed = describe(self.zl)
        self.layout_digest_recomputed = hashlib.sha256(self.layout_description_recomputed.encode("utf-8")).hexdigest()
        decl = raw.get("layout_description")
        if not isinstance(decl, str):
            raise RepairedCaptureError("layout_description missing")
        self.layout_description_declared = decl
        self.layout_digest_declared = raw.get("layout_digest")
        digest_of_declared = hashlib.sha256(decl.encode("utf-8")).hexdigest()
        if digest_of_declared != self.layout_digest_declared:
            raise RepairedCaptureError(
                f"layout_digest {self.layout_digest_declared!r} is not sha256(layout_description) = {digest_of_declared}")
        if decl != self.layout_description_recomputed:
            raise RepairedCaptureError(
                "layout_description does not match the layout recomputed from the source rules "
                f"(declared digest {digest_of_declared[:16]}.., recomputed {self.layout_digest_recomputed[:16]}..)")

        roles_raw = raw.get("roles")
        if not isinstance(roles_raw, list) or not roles_raw:
            raise RepairedCaptureError("roles missing or empty")
        self.roles: List[RepairedRoleObs] = []
        names = []
        for rr in roles_raw:
            ro = RepairedRoleObs(rr, self.privacy, self.zl)
            if ro.role in names:
                raise RepairedCaptureError(f"role {ro.role} appears twice")
            names.append(ro.role)
            self.roles.append(ro)
        if names != ROLE_ORDER[self.privacy]:
            raise RepairedCaptureError(f"roles {names} are not {ROLE_ORDER[self.privacy]} for {self.privacy}")
        for a, b in zip(self.roles, self.roles[1:]):
            if a.after_state != b.before_state or a.after_next != b.before_next:
                raise RepairedCaptureError(f"transcript endpoint of {a.role} does not connect to {b.role}")
        del raw

    def header(self) -> dict:
        return {"file": os.path.basename(self.path), "file_sha256": self.file_sha256, "bytes": self.bytes,
                "proof_sha256": self.proof_sha256, "privacy": self.privacy, "shape": self.shape,
                "shifts": list(self.shifts), "coverage": COVERAGE, "profile": PROFILE,
                "transcript_domain": TRANSCRIPT_DOMAIN, "source_commit": SOURCE_COMMIT, "schema": SCHEMA,
                "layout_digest": self.layout_digest_declared, "layout_digest_recomputed": self.layout_digest_recomputed,
                "roles": [r.role for r in self.roles]}


# ---------------------------------------------------------------------------
# the manifest (interim /tmp record, or results/zk60_round16_validation.json)
# ---------------------------------------------------------------------------


def load_manifest(path: str) -> dict:
    """Accepts the interim worker record (/tmp/zk60-round16/summary.json) or the
    published results/zk60_round16_validation.json.  The published record's own
    `source_commit` is the head the validation ran at, which is LATER than the
    implementation the captures came from: `capture_source_commit` is the field that
    must equal the pin, so it is preferred when present and both are reported."""
    with open(path) as fh:
        rec = json.load(fh)
    caps = rec.get("captures")
    if not isinstance(caps, list) or not caps:
        raise RepairedCaptureError(f"{path}: no `captures` list")
    entries = {}
    for e in caps:
        for k in ("path", "sha256", "bytes", "proof_sha256", "privacy", "layout_digest"):
            if k not in e:
                raise RepairedCaptureError(f"{path}: capture entry missing {k!r}")
        entries[e["proof_sha256"]] = e
    interim = os.path.basename(path) == "summary.json"
    return {"path": os.path.abspath(path), "sha256": sha256_file(path),
            "capture_source_commit": rec.get("capture_source_commit", rec.get("source_commit")),
            "record_head_commit": rec.get("source_commit"),
            "status": rec.get("status"), "schema": rec.get("schema"), "entries": entries,
            "is_interim": interim,
            "note": (f"INTERIM worker record, status {rec.get('status')!r}; the published "
                     "results/zk60_round16_validation.json supersedes it."
                     if interim else
                     f"published validation record, status {rec.get('status')!r}; its own source_commit is the "
                     "head the validation ran at, capture_source_commit is the captures' implementation pin")}


def cross_check_manifests(primary: dict, other: dict) -> dict:
    """Entry-by-entry agreement between two records over the same four captures."""
    keys = ("sha256", "bytes", "privacy", "layout_digest", "path")
    rows = []
    for stem in sorted(set(primary["entries"]) | set(other["entries"])):
        a, b = primary["entries"].get(stem), other["entries"].get(stem)
        if a is None or b is None:
            rows.append({"proof_sha256": stem, "in_primary": a is not None, "in_other": b is not None,
                         "agree": False})
            continue
        diffs = {k: [a.get(k), b.get(k)] for k in keys if a.get(k) != b.get(k)}
        rows.append({"proof_sha256": stem, "in_primary": True, "in_other": True, "agree": not diffs,
                     **({"differences": diffs} if diffs else {})})
    return {"primary": {k: primary[k] for k in ("path", "sha256", "status", "capture_source_commit",
                                                "record_head_commit", "is_interim")},
            "other": {k: other[k] for k in ("path", "sha256", "status", "capture_source_commit",
                                            "record_head_commit", "is_interim")},
            "same_capture_set": set(primary["entries"]) == set(other["entries"]),
            "same_capture_source_commit": primary["capture_source_commit"] == other["capture_source_commit"],
            "entries": rows,
            "all_entries_agree": all(r["agree"] for r in rows) and set(primary["entries"]) == set(other["entries"])}


# ---------------------------------------------------------------------------
# O1 -- capture integrity preflight
# ---------------------------------------------------------------------------


def _chk(checks: List[dict], name: str, ok: bool, actual, expected, note: str = "") -> bool:
    checks.append({"check": name, "pass": bool(ok), "actual": actual, "expected": expected, **({"note": note} if note else {})})
    return bool(ok)


def preflight(captures_dir: str, manifest_path: str, out_path: Optional[str],
              cross_manifest: Optional[str] = None, log=print) -> dict:
    man = load_manifest(manifest_path)
    files = sorted(f for f in os.listdir(captures_dir) if f.endswith(".json"))
    report: dict = {
        "schema_version": 1,
        "task": "O1 -- repaired-profile capture integrity preflight",
        "verdict_scope": "This is a CAPTURE-INTEGRITY check of the four exported observation files. "
                         "It is NOT a privacy verdict: no disclosure claim, and no zero-knowledge property, follows from it.",
        "reviewer": REVIEWER,
        "source_commit": SOURCE_COMMIT,
        "review_worktree_commit": REVIEW_WORKTREE_COMMIT,
        "profile": PROFILE, "coverage": COVERAGE, "schema": SCHEMA,
        "tool_sha256": {
            "zk60_opus_repaired_capture.py": sha256_file(os.path.abspath(__file__)),
            "zk60_fable_joint_capture.py": sha256_file(os.path.join(_HERE, "zk60_fable_joint_capture.py")),
            "zk60_fable_joint_rank.py": sha256_file(os.path.join(_HERE, "zk60_fable_joint_rank.py")),
        },
        "manifest": {k: man[k] for k in ("path", "sha256", "capture_source_commit", "record_head_commit",
                                         "status", "schema", "is_interim", "note")},
        "manifest_cross_check": cross_check_manifests(man, load_manifest(cross_manifest)) if cross_manifest else None,
        "captures_directory": os.path.abspath(captures_dir),
        "recomputed_layout": {
            "description": describe(zk_layout(SHAPE["t"], SHAPE["d"], SHAPE["f"], LOG_COLS, SHIFTS)),
            "sha256": hashlib.sha256(describe(zk_layout(SHAPE["t"], SHAPE["d"], SHAPE["f"], LOG_COLS, SHIFTS)).encode("utf-8")).hexdigest(),
        },
        "checks": [], "files": [], "refused": [],
    }
    checks = report["checks"]
    _chk(checks, "exactly four capture files in the directory", len(files) == 4, len(files), 4)
    _chk(checks, "manifest lists exactly four captures", len(man["entries"]) == 4, len(man["entries"]), 4)
    _chk(checks, "manifest capture_source_commit is the pinned implementation",
         man["capture_source_commit"] == SOURCE_COMMIT, man["capture_source_commit"], SOURCE_COMMIT,
         f"the record's own head commit is {man['record_head_commit']}")
    if report["manifest_cross_check"] is not None:
        x = report["manifest_cross_check"]
        _chk(checks, "the two records agree on all four captures entry by entry", x["all_entries_agree"],
             {"same_capture_set": x["same_capture_set"], "same_capture_source_commit": x["same_capture_source_commit"],
              "disagreeing": [r["proof_sha256"][:12] for r in x["entries"] if not r["agree"]]},
             "identical sha256, bytes, privacy, layout_digest and path for every proof digest")

    privacies: List[str] = []
    layout_digests: List[str] = []
    for name in files:
        path = os.path.join(captures_dir, name)
        fchecks: List[dict] = []
        entry = {"file": name, "path": path, "checks": fchecks}
        try:
            cap = RepairedCapture(path)
        except C.CaptureError as err:
            entry["parsed"] = False
            entry["refusal"] = str(err)
            report["files"].append(entry)
            report["refused"].append({"file": name, "reason": str(err)})
            log(f"REFUSED {name}: {err}")
            continue
        entry["parsed"] = True
        entry.update(cap.header())
        m = man["entries"].get(cap.proof_sha256)
        _chk(fchecks, "proof digest is listed in the manifest", m is not None, cap.proof_sha256, "listed")
        if m is not None:
            _chk(fchecks, "file sha256 matches the manifest", cap.file_sha256 == m["sha256"], cap.file_sha256, m["sha256"])
            _chk(fchecks, "byte length matches the manifest", cap.bytes == m["bytes"], cap.bytes, m["bytes"])
            _chk(fchecks, "privacy mode matches the manifest", cap.privacy == m["privacy"], cap.privacy, m["privacy"])
            _chk(fchecks, "layout_digest matches the manifest", cap.layout_digest_declared == m["layout_digest"],
                 cap.layout_digest_declared, m["layout_digest"])
            _chk(fchecks, "manifest path is this file", os.path.abspath(m["path"]) == os.path.abspath(path),
                 m["path"], os.path.abspath(path))
        _chk(fchecks, "file name is the proof digest", name == cap.proof_sha256 + ".json", name, cap.proof_sha256 + ".json")
        _chk(fchecks, "schema is 2", True, SCHEMA, SCHEMA)
        _chk(fchecks, "coverage", True, COVERAGE, COVERAGE)
        _chk(fchecks, "source_commit", True, SOURCE_COMMIT, SOURCE_COMMIT)
        _chk(fchecks, "sha256(layout_description) == declared layout_digest",
             hashlib.sha256(cap.layout_description_declared.encode("utf-8")).hexdigest() == cap.layout_digest_declared,
             hashlib.sha256(cap.layout_description_declared.encode("utf-8")).hexdigest(), cap.layout_digest_declared)
        _chk(fchecks, "layout_description equals the layout recomputed from the source rules",
             cap.layout_description_declared == cap.layout_description_recomputed, cap.layout_digest_recomputed,
             cap.layout_digest_declared, "byte-identical describe() reproduction, not a digest comparison alone")
        _chk(fchecks, "shape T/d/f", True, cap.shape, SHAPE)
        _chk(fchecks, "shifts", True, list(cap.shifts), list(SHIFTS))
        _chk(fchecks, "role order for the privacy mode", True, [r.role for r in cap.roles], ROLE_ORDER[cap.privacy])
        for ro in cap.roles:
            rn = ro.role
            _chk(fchecks, f"{rn}: log_cols / inv_rate / Q", True,
                 [ro.log_n, ro.inv_rate, ro.num_col_checks], [LOG_COLS, INV_RATE, NUM_COL_CHECKS])
            _chk(fchecks, f"{rn}: commitment rows", ro.rows == EXPECTED_ROWS[rn], ro.rows, EXPECTED_ROWS[rn])
            _chk(fchecks, f"{rn}: q_pad", ro.q_pad == Q_PAD, ro.q_pad, Q_PAD)
            _chk(fchecks, f"{rn}: one row-role entry per row, kinds agree with the recomputation",
                 True, {"rows": ro.rows, "data": len(ro.data_rows),
                        "mask": sum(1 for r in range(ro.rows) if ro.row_kind[r] == "mask"),
                        "prox": sum(1 for r in range(ro.rows) if ro.row_kind[r] == "prox")},
                 "exactly one entry per row 0..rows-1, each equal to the recomputed (kind, site)")
            nprox = sum(1 for r in range(ro.rows) if ro.row_kind[r] == "prox")
            _chk(fchecks, f"{rn}: two proximity rows", nprox == 2, {"count": nprox, "rows": ro.layout["prox_rows"]}, 2)
            _chk(fchecks, f"{rn}: group member counts", [len(g["members"]) for g in ro.groups] == EXPECTED_GROUP_SHAPE[rn],
                 [len(g["members"]) for g in ro.groups], EXPECTED_GROUP_SHAPE[rn])
            vl = sorted({len(g["vector"]) for g in ro.groups} | {len(ro.prox_vector)})
            _chk(fchecks, f"{rn}: every group and proximity vector has n + Q entries", vl == [ro.n + Q_PAD], vl, [ro.n + Q_PAD])
            _chk(fchecks, f"{rn}: every claim part carries a symbolic coefficient tag equal to the recomputed one",
                 True, {"claims": len(ro.claims), "parts": sum(len(c["parts"]) for c in ro.claims),
                        "distinct_tags": len({t for tt in ro.part_tag for t in tt})},
                 "one tag per part, all reproduced from zk_ffn_observation_json.rs::coefficient_tag")
            _chk(fchecks, f"{rn}: sampled-column structure", True,
                 {"columns": len(ro.sampled_columns), "distinct": len(set(ro.sampled_columns)),
                  "domain": ro.column_domain, "path_nodes": ro.column_domain.bit_length() - 1,
                  "values_per_column": ro.rows},
                 {"columns": NUM_COL_CHECKS, "domain": ro.n * INV_RATE, "path_nodes": (ro.n * INV_RATE).bit_length() - 1},
                 "indices are sampled with replacement, so distinct < 256 is expected")
            if rn == "H":
                _chk(fchecks, "H records its zero-sum constraint",
                     ro.public_linear_constraints == [{"rows": list(ro.layout["zero_sum_pair"]),
                                                       "relation": "sum over the n message columns = 0",
                                                       "source": "zsum sumcheck"}],
                     ro.public_linear_constraints, [{"rows": list(ro.layout["zero_sum_pair"]),
                                                     "relation": "sum over the n message columns = 0",
                                                     "source": "zsum sumcheck"}])
            else:
                _chk(fchecks, f"{rn}: no public linear constraint", ro.public_linear_constraints == [],
                     ro.public_linear_constraints, [])
        entry["roles"] = [r.summary() for r in cap.roles]
        entry["all_checks_pass"] = all(c["pass"] for c in fchecks)
        privacies.append(cap.privacy)
        layout_digests.append(cap.layout_digest_declared)
        report["files"].append(entry)
        log(f"{name[:12]} {cap.privacy} roles {[r.role for r in cap.roles]}: "
            f"{sum(1 for c in fchecks if c['pass'])}/{len(fchecks)} checks pass")
        del cap
    _chk(checks, "two P1 and two P3 captures", sorted(privacies) == ["P1", "P1", "P3", "P3"], sorted(privacies),
         ["P1", "P1", "P3", "P3"])
    _chk(checks, "all four captures share one layout_digest", len(set(layout_digests)) == 1 and len(layout_digests) == 4,
         sorted(set(layout_digests)), "a single digest across four files")
    _chk(checks, "no capture refused", not report["refused"], len(report["refused"]), 0)
    report["summary"] = {
        "files_parsed": sum(1 for f in report["files"] if f.get("parsed")),
        "files_refused": len(report["refused"]),
        "checks_total": len(checks) + sum(len(f["checks"]) for f in report["files"]),
        "checks_failed": sum(1 for c in checks if not c["pass"]) + sum(1 for f in report["files"] for c in f["checks"] if not c["pass"]),
    }
    report["summary"]["all_pass"] = report["summary"]["checks_failed"] == 0 and report["summary"]["files_parsed"] == 4
    report["limits"] = [
        "Capture integrity only: schema, digests, manifest binding, recomputed layout, claim mapping, row roles, group and pad structure.",
        "No privacy, disclosure, soundness or zero-knowledge property is asserted or tested here; O2 runs the linear disclosure model.",
        "The manifest used is the interim /tmp record while Codex's round-16 worker is unfinished; re-check against results/zk60_round16_validation.json when it is published.",
        "The captures hold no witness values; nothing here compares any recovered quantity to a truth.",
    ]
    if out_path:
        with open(out_path, "w") as fh:
            json.dump(report, fh, indent=1)
        log(f"wrote {out_path}")
    return report


# ---------------------------------------------------------------------------
# O2 -- the joint linear observation model (FA7's RoleModel, unchanged)
# ---------------------------------------------------------------------------


def analyze_role(obs: RepairedRoleObs, planes: bool = True, plane_columns: Sequence[int] = (0, -1)) -> dict:
    t0 = time.time()
    rec: dict = {"role": obs.role, "role_summary": obs.summary()}
    rec["included_observation_classes"] = sorted(k for k in INCLUDED_CLASSES if k != "zero_sum" or obs.role == "H")
    rec["excluded_observation_classes"] = sorted(EXCLUDED_CLASSES)
    model = C.RoleModel(obs)
    rec["analysis"] = model.analyze(planes=planes, plane_columns=plane_columns)
    # the legacy single-mask elimination, attempted and expected to be inapplicable
    rec["legacy_singleton_attack"] = []
    for gi, g in enumerate(obs.groups):
        if len(g["members"]) == 1 and obs.claims[g["members"][0]]["parts"][0]["point"]:
            try:
                rec["legacy_singleton_attack"].append(C.singleton_functionals(obs, gi))
            except C.CaptureError as err:
                k = g["members"][0]
                rec["legacy_singleton_attack"].append({
                    "group": gi, "claim": k, "applicable": False, "reason": str(err),
                    "mask_parts": sum(1 for pi in range(len(obs.claims[k]["parts"])) if obs.part_kind[k][pi] == "mask"),
                    "meaning": "FA7 section 7's L_b elimination needs exactly one single-row base mask in the claim; "
                               "the repaired site has an independent pair, so the projection that recovered X / h16 / Wd "
                               "from the legacy captures has no mask-free form here.",
                })
    if obs.role == "H":
        no_zs = C.RoleModel(obs, zero_sum=False).analyze(planes=False)
        with_id = C.RoleModel(obs, extras=[C.h_identity_extra(obs)])
        ra = with_id.rank(with_id.all_gens())["rank"]
        rec["h_zero_sum"] = {
            "disclosed_without_zero_sum_constraint": no_zs["joint"]["disclosed_total"],
            "disclosed_with_zero_sum_constraint": rec["analysis"]["joint"]["disclosed_total"],
            "identity_rows_in_observation_row_space": ra == rec["analysis"]["joint"]["rank_joint"],
            "residual_equals_public_logup_identity": (ra == rec["analysis"]["joint"]["rank_joint"]
                                                      and rec["analysis"]["joint"]["disclosed_total"] == 2),
            "meaning": "the surviving functionals are exactly the public LogUp identity "
                       "sum_j (helpers - table helpers) whose value the proof itself fixes to 0; a known constant, "
                       "not a witness functional -- and this is a rank statement under fixed coefficients, not H privacy",
        }
    try:
        C.codex_per_column(obs)
        rec["legacy_per_column_subset"] = {"applicable": True}
    except C.CaptureError as err:
        rec["legacy_per_column_subset"] = {
            "applicable": False, "reason": str(err),
            "meaning": "Codex's round-11 per-column classifier assumes a single unreferenced (proximity) row; "
                       "the repaired layout has a proximity PAIR. The same quantity is reported here as "
                       "analysis.per_column.disclosed_per_column, which FA7 section 6 showed equals that subset.",
        }
    rec["seconds"] = round(time.time() - t0, 2)
    return rec


def analyze(captures_dir: str, manifest_path: str, out_path: Optional[str], legacy_dir: Optional[str] = None,
            runs_file: Optional[str] = None, cross_manifest: Optional[str] = None, planes: bool = True,
            plane_columns: Sequence[int] = (0, -1), log=print) -> dict:
    man = load_manifest(manifest_path)
    report: dict = {
        "schema_version": 1,
        "task": "O2 -- repaired-profile captures analysed jointly with the FA7 linear observation model",
        "reviewer": REVIEWER,
        "source_commit": SOURCE_COMMIT,
        "review_worktree_commit": REVIEW_WORKTREE_COMMIT,
        "profile": PROFILE, "coverage": COVERAGE, "schema": SCHEMA,
        "model_provenance": "the joint model, its exact Fp2/rank algebra and its included/excluded observation "
                            "classes are Claude Fable 5.1's FA7 work (scripts/zk60_fable_joint_capture.py, "
                            "scripts/zk60_fable_joint_rank.py), imported unchanged; only the parser and the "
                            "recomputed repaired layout are Opus 5's.",
        "tool_sha256": {
            "zk60_opus_repaired_capture.py": sha256_file(os.path.abspath(__file__)),
            "zk60_fable_joint_capture.py": sha256_file(os.path.join(_HERE, "zk60_fable_joint_capture.py")),
            "zk60_fable_joint_rank.py": sha256_file(os.path.join(_HERE, "zk60_fable_joint_rank.py")),
        },
        "manifest": {k: man[k] for k in ("path", "sha256", "capture_source_commit", "record_head_commit",
                                         "status", "schema", "is_interim", "note")},
        "manifest_cross_check": cross_check_manifests(man, load_manifest(cross_manifest)) if cross_manifest else None,
        "captures_directory": os.path.abspath(captures_dir),
        "included_observation_classes": INCLUDED_CLASSES,
        "excluded_observation_classes": EXCLUDED_CLASSES,
        "structure_validated_only": STRUCTURE_ONLY_CLASSES,
        "captures": [], "cases": [], "refused": [],
    }
    if runs_file:
        with open(runs_file) as fh:
            report["commands"] = json.load(fh)
        # this invocation itself: the record is only written on the successful path,
        # so the exit code below is the one this process is about to return.
        report["commands"].append({"command": "python3 " + " ".join(sys.argv), "exit_code": 0,
                                   "result": "this analysis record"})
    for name in sorted(f for f in os.listdir(captures_dir) if f.endswith(".json")):
        path = os.path.join(captures_dir, name)
        h = sha256_file(path)
        entry = man["entries"].get(name[:-5])
        try:
            cap = RepairedCapture(path, expected_capture_sha256=entry["sha256"] if entry else None)
        except C.CaptureError as err:
            report["refused"].append({"file": name, "reason": str(err)})
            log(f"REFUSED {name}: {err}")
            continue
        report["captures"].append({**cap.header(), "manifest_entry": entry})
        log(f"{name[:12]} {cap.privacy} roles {[r.role for r in cap.roles]}")
        for ro in cap.roles:
            rec = {**cap.header(), **analyze_role(ro, planes=planes, plane_columns=plane_columns)}
            log(f"  {cap.proof_sha256[:12]} {cap.privacy} {ro.role}: per-column "
                f"{rec['analysis']['per_column']['disclosed_per_column']}, joint "
                f"{rec['analysis']['joint']['disclosed_total']} ({rec['seconds']} s)")
            report["cases"].append(rec)
        del cap
    report["summary"] = summarize(report["cases"])
    report["expected_target"] = {
        "source": "docs/zkmatrix-poc/ZK60_OPUS_QUEUE.md O2 and ZK60_ROUND16.md",
        "A": {"disclosed_total": 0}, "W": {"disclosed_total": 0},
        "H": {"disclosed_total": 2, "residual_equals_public_logup_identity": True,
              "disclosed_without_zero_sum_constraint": 0},
    }
    report["target_met"] = _target_met(report["cases"])
    if legacy_dir:
        report["legacy_positive_control"] = legacy_control(legacy_dir)
    report["limits"] = [
        "A linear-model rank result on four fresh-PoC captures under the captured (fixed) public coefficients. "
        "It is not a simulator, not a conditioning argument and not an upper bound on disclosure.",
        "Excluded by construction and unchanged from FA7: pad coordinates, sampled encoded columns, the CFS mask "
        "commitment and masked sumcheck round messages, repeated proofs of one witness, and the Merkle root over "
        "unopened columns. Each needs its own argument.",
        "This is NOT whole-protocol zero knowledge. It covers only the experimental ffn-v3-mr1-fresh-poc/1 profile at "
        "T32/d16/f16, function 1, with fresh per-proof weights: no registered/seamed profile, no function 2, no stable "
        "private model identity, no attention, no wire decoder, no transport envelope.",
        "The captures hold no witness values; nothing here is compared to a ground truth.",
        "No private-block, deployment or throughput acceptance follows.",
    ]
    if out_path:
        with open(out_path, "w") as fh:
            json.dump(report, fh, indent=1)
        log(f"wrote {out_path}")
    return report


def _target_met(cases: List[dict]) -> dict:
    out: Dict[str, dict] = {}
    for c in cases:
        role = c["role"]
        j = c["analysis"]["joint"]["disclosed_total"]
        e = out.setdefault(role, {"cases": 0, "disclosed_total": set(), "per_column": set(), "ok": True})
        e["cases"] += 1
        e["disclosed_total"].add(j)
        e["per_column"].add(c["analysis"]["per_column"]["disclosed_per_column"])
        want = 2 if role == "H" else 0
        if j != want:
            e["ok"] = False
        if role == "H" and not c["h_zero_sum"]["residual_equals_public_logup_identity"]:
            e["ok"] = False
    for role, e in out.items():
        e["disclosed_total"] = sorted(e["disclosed_total"])
        e["per_column"] = sorted(e["per_column"])
    out["all_roles_meet_the_expected_target"] = all(e["ok"] for e in out.values() if isinstance(e, dict))
    return out


def summarize(cases: List[dict]) -> dict:
    table: Dict[str, dict] = {}
    for c in cases:
        key = f"{c['privacy']}/T{c['shape']['t']}/{c['role']}"
        a = c["analysis"]
        row = table.setdefault(key, {"cases": 0, "n": c["role_summary"]["n"], "per_column_disclosed": set(),
                                     "joint_disclosed": set(), "cross_column_increment": set(), "planes": {}})
        row["cases"] += 1
        row["per_column_disclosed"].add(a["per_column"]["disclosed_per_column"])
        row["joint_disclosed"].add(a["joint"]["disclosed_total"])
        row["cross_column_increment"].add(a["joint"]["cross_column_increment"])
        for name, pe in a.get("planes", {}).items():
            pr = row["planes"].setdefault(name, {"projected": set(), "isolated": set(), "rows": pe["row_count"]})
            pr["projected"].add(pe["projected_disclosed_dim"])
            pr["isolated"].add(pe["isolated_disclosed_dim"])
    out = {}
    for key, row in table.items():
        out[key] = {"cases": row["cases"], "n": row["n"], "per_column_disclosed": sorted(row["per_column_disclosed"]),
                    "joint_disclosed": sorted(row["joint_disclosed"]),
                    "cross_column_increment": sorted(row["cross_column_increment"]),
                    "planes": {nm: {"rows": p["rows"], "projected": sorted(p["projected"]), "isolated": sorted(p["isolated"])}
                               for nm, p in row["planes"].items()}}
    return out


def legacy_control(legacy_dir: str, log=print) -> dict:
    """POSITIVE CONTROL.  (a) this adapter must REFUSE every legacy schema-1 capture;
    (b) Fable's archived legacy tool must still reproduce its numbers on them.
    Only the T32 legacy captures are re-run (the shape the repaired PoC uses)."""
    out: dict = {"directory": os.path.abspath(legacy_dir), "adapter_refusals": [], "legacy_tool_cases": [],
                 "expected_legacy": {"A": "2n + 4 = 516", "W(P3)": "2n + 2 = 514", "H": "2 (the public LogUp identity)",
                                     "T32 Wd": "fully recovered"}}
    files = sorted(f for f in os.listdir(legacy_dir) if f.endswith(".json"))
    for name in files:
        path = os.path.join(legacy_dir, name)
        try:
            RepairedCapture(path)
            out["adapter_refusals"].append({"file": name, "refused": False,
                                            "PROBLEM": "the repaired adapter accepted a legacy capture"})
        except C.CaptureError as err:
            out["adapter_refusals"].append({"file": name, "refused": True, "reason": str(err)})
    out["all_legacy_captures_refused_by_the_adapter"] = all(e["refused"] for e in out["adapter_refusals"])
    for name in files:
        path = os.path.join(legacy_dir, name)
        try:
            cap = C.Capture(path)
        except C.CaptureError as err:
            out["legacy_tool_cases"].append({"file": name, "error": str(err)})
            continue
        if cap.shape["t"] != 32:
            del cap
            continue
        for obs in cap.roles:
            model = C.RoleModel(obs)
            a = model.analyze(planes=True, plane_columns=())
            case = {"file": name, "file_sha256": cap.file_sha256, "privacy": cap.privacy, "shape": cap.shape,
                    "role": obs.role, "n": obs.n,
                    "per_column_disclosed": a["per_column"]["disclosed_per_column"],
                    "joint_disclosed_total": a["joint"]["disclosed_total"]}
            for pname, pe in a["planes"].items():
                if pe.get("fully_recovered"):
                    case.setdefault("fully_recovered_planes", []).append({"plane": pname, "rows": pe["row_count"],
                                                                         "isolated": pe["isolated_disclosed_dim"]})
            out["legacy_tool_cases"].append(case)
            log(f"  legacy {name[:12]} {cap.privacy} {obs.role}: per-column {case['per_column_disclosed']}, "
                f"joint {case['joint_disclosed_total']}")
        del cap
    got = {}
    for c in out["legacy_tool_cases"]:
        if "role" in c:
            got.setdefault(c["role"], set()).add(c["joint_disclosed_total"])
    out["legacy_tool_reproduces_fa7"] = {r: sorted(v) for r, v in got.items()}
    return out


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    pf = sub.add_parser("preflight")
    pf.add_argument("--captures-dir", required=True)
    pf.add_argument("--manifest", required=True)
    pf.add_argument("--cross-manifest", help="a second record (e.g. the interim worker summary) to compare entry by entry")
    pf.add_argument("-o", "--out")
    an = sub.add_parser("analyze")
    an.add_argument("--captures-dir", required=True)
    an.add_argument("--manifest", required=True)
    an.add_argument("--cross-manifest")
    an.add_argument("--legacy-dir")
    an.add_argument("--runs-file")
    an.add_argument("-o", "--out")
    an.add_argument("--no-planes", action="store_true")
    an.add_argument("--plane-columns", default="0,-1")
    ck = sub.add_parser("check")
    ck.add_argument("capture")
    ck.add_argument("--expected-sha256")
    args = ap.parse_args(argv)
    if args.cmd == "preflight":
        rep = preflight(args.captures_dir, args.manifest, args.out, cross_manifest=args.cross_manifest)
        print(json.dumps(rep["summary"], indent=1))
        return 0 if rep["summary"]["all_pass"] else 1
    if args.cmd == "analyze":
        cols = [int(x) for x in args.plane_columns.split(",") if x != ""]
        rep = analyze(args.captures_dir, args.manifest, args.out, legacy_dir=args.legacy_dir,
                      runs_file=args.runs_file, cross_manifest=args.cross_manifest,
                      planes=not args.no_planes, plane_columns=cols)
        print(json.dumps({"summary": rep["summary"], "target_met": rep["target_met"]}, indent=1))
        return 0
    cap = RepairedCapture(args.capture, expected_capture_sha256=args.expected_sha256)
    print(json.dumps({"header": cap.header(), "roles": [r.summary() for r in cap.roles]}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
