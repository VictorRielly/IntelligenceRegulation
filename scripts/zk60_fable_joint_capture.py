#!/usr/bin/env python3
"""zk60_fable_joint_capture.py -- FA7: digest-bound capture parser + JOINT linear
observation model of the schema-1 A/H/W verifier captures (analysis only, stdlib).

Reviewer: Claude Fable 5.1, independent reviewer, 2026-09-08 session.
Source pin: cfa46f6 (worktree zk60-fable-review); captures produced at c8a342f by
the ordinary verifier's cfg(test) observer (hashline/src/zk_ffn_observation_json.rs).

WHAT THIS CONSUMES.  One capture file per proof, named <proof_sha256>.json, schema
1: exact integer field coordinates, per role (W under P3, A, H) the PCS parameters,
the commitment, every claim (slices, coefficients, points, value), every group
(members, lambdas, column key, the clear vector: n message entries then Q pad
entries), the proximity coefficients and vector, the sampled columns, and the
transcript endpoints.  The parser checks the schema, the field, the digest name,
the parity record's capture hash, every slice against the commitment, every group
against its members, every part's column tail against its group key, and the
public identity  sum_j eq(tail)[j] v_g[j] = sum_k lambda_k value_k  for every group
(this is how the verifier ties the vector to the terminals, and it pins the
column-weight convention).  Malformed input raises CaptureError; nothing is
guessed.  Row roles (data / mask / prox, plane names) are not in the capture: they
are RECOMPUTED from the layout allocation of hashline/src/layer.rs::LayoutV3::new and
zk.rs::ZkLayoutV3::new / build_claims_zk_v3 / build_w_zclaims_v3 and every claim's
slices must match the recomputed layout exactly, otherwise the capture is refused.

WHAT THE MODEL IS.  One base-field unknown per (row, column) entry of a commitment,
so a row opened by two claims (the X rows at rho_d and p2; h16 at rho_f and p5;
every H helper row in its own claim and in the value-0 LogUp sum claim) aliases
automatically.  Observations (all Fp2, each = two base rows):
  * every message coordinate of every group vector   (2 base rows per group and column)
  * every coordinate of the proximity vector          (2 per column)
  * every terminal (claim value), including the sum claim's public 0  (2 per claim)
  * the public constraint on H's zero-sum row u: sum_j u[j] = 0             (2)
EXCLUDED (stated, not costed): the pad coordinates v[n..n+Q) and the sampled
columns (a different set of unknowns -- the Q fresh pads per row -- whose hiding is
FA2 section 14.6's Vandermonde argument plus the salted-leaf hash assumption), the
CFS mask commitment and sumcheck round messages (nonlinear in the data; FA6), and
repeated proofs of the same witness (FA8).  Nothing here is a simulator or an
upper bound on disclosure.

HOW IT IS COMPUTED EXACTLY AT FULL WIDTH.  The group-vector and proximity
coordinates of column j involve only column j's unknowns and their coefficients
do not depend on j; the terminals are the only cross-column rows and their
coefficient on entry (r, j) is  coef * eq_row(r) * eq_col(j).  Working in the dual
(column-space) picture, rank(observations restricted to an unknown set X) =
n * r_X + dim K_X, where r_X is the per-column block rank (exactly Codex's
per-column number) and K_X = sum over columns j of D_j(Z_X) is the space of
cross-column combinations that vanish on every block; Z_X is computed once from
the block null space and D_j rescales claim k's pair by eq_col_k(j).  Rows with the
same claim memberships form a site; a site's generators are compressed to a basis
of the span of its rows' (row weights, proximity rho) features, which is exact.
disclosed = rank(all) - rank(masks); per data plane P: projected = rank(masks + P)
- rank(masks) (independent functionals of P that appear), isolated = rank(all) -
rank(all - P) (disclosed functionals supported on P alone).

Usage:
    python3 scripts/zk60_fable_joint_capture.py analyze --final-dir DIR [--initial-dir DIR]
        --parity results/zk60_round11_capture_parity.json
        --codex results/zk60_round11_captured_rank.json -o OUT.json
    python3 scripts/zk60_fable_joint_capture.py check CAPTURE.json   # parse + validate + per-column ranks
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
_SPEC = importlib.util.spec_from_file_location("zk60_fable_joint_rank", os.path.join(_HERE, "zk60_fable_joint_rank.py"))
R = importlib.util.module_from_spec(_SPEC)
sys.modules.setdefault("zk60_fable_joint_rank", R)
_SPEC.loader.exec_module(R)

P = R.P
NONRESIDUE = R.NONRESIDUE
ONE, ZERO, U = R.ONE, R.ZERO, R.U
f2_add, f2_sub, f2_mul, f2_neg = R.f2_add, R.f2_sub, R.f2_mul, R.f2_neg
eq_table_msb, det = R.eq_table_msb, R.det

Fp2 = Tuple[int, int]

REVIEWER = "Claude Fable 5.1, independent reviewer, 2026-09-08 session (FA7)"
SOURCE_COMMIT = "cfa46f6"
CAPTURE_SOURCE_COMMIT = "c8a342f"
SCHEMA = 1
KIND = "zk60-verifier-observations"
COVERAGE_F1 = "ffn-v3-function-1"
TAB_SLOTS = 6

EXCLUDED_CLASSES = {
    "pads": "the Q pad coordinates v_g[n..n+Q) of every clear vector: linear in the Q fresh pad unknowns of each row, not in the message unknowns (FA2 section 14.6 argument; not modelled)",
    "sampled_columns": "the Q opened encoded columns (values, salts, paths): (f_row + Z_n g_pad) at coset points, hidden by the pads (Vandermonde) and the salted leaves (hash assumption); not modelled",
    "cfs": "the CFS mask commitment and the masked sumcheck round messages / claimed sums: nonlinear in the data; FA6",
    "repeats": "repeated proofs of the same witness (fresh challenges each): FA8; every capture is analysed alone",
    "unopened_columns": "the Merkle root over unopened columns: computational hiding assumption, outside a linear model",
}
INCLUDED_CLASSES = {
    "group_vectors": "every message coordinate v_g[j], j < n, of every group vector (2 base rows each)",
    "proximity_vector": "every coordinate prox[j], j < n (2 base rows each)",
    "terminals": "every claim value (2 base rows each), including the H sum claim's public value 0",
    "zero_sum": "H only: the public constraint sum_j u[j] = 0 on the zero-sum mask row pair (2 base rows), proven by the zsum sumcheck",
    "aliasing": "one unknown per (row, column): rows opened by several claims are the same unknowns",
}


class CaptureError(ValueError):
    """A capture that must be refused (malformed, mis-hashed, or not the expected layout)."""


# ----------------------------------------------------------------------------
# small helpers
# ----------------------------------------------------------------------------


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_values(values: Iterable[Sequence[int]]) -> str:
    """Digest of a list of field values (Fp2 pairs or ints) in order; the values never leave."""
    h = hashlib.sha256()
    for v in values:
        if isinstance(v, int):
            h.update(str(v).encode() + b",")
        else:
            h.update((str(v[0]) + ":" + str(v[1])).encode() + b",")
    return h.hexdigest()


def _is_int(x) -> bool:
    return isinstance(x, int) and not isinstance(x, bool)


def _fp(x, what: str) -> int:
    if not _is_int(x) or x < 0 or x >= P:
        raise CaptureError(f"{what}: not an integer in [0, p): {x!r}")
    return x


def _fp2(x, what: str) -> Fp2:
    if not isinstance(x, list) or len(x) != 2:
        raise CaptureError(f"{what}: not an Fp2 pair: {x!r}")
    return (_fp(x[0], what + ".c0"), _fp(x[1], what + ".c1"))


def _bytes32(x, what: str) -> str:
    if not isinstance(x, list) or len(x) != 32 or not all(_is_int(b) and 0 <= b < 256 for b in x):
        raise CaptureError(f"{what}: not 32 bytes")
    return bytes(x).hex()


def _uint(x, what: str, lo: int = 0, hi: Optional[int] = None) -> int:
    if not _is_int(x) or x < lo or (hi is not None and x > hi):
        raise CaptureError(f"{what}: not an integer in [{lo}, {hi}]: {x!r}")
    return x


# ----------------------------------------------------------------------------
# the expected layout (LayoutV3::new + ZkLayoutV3::new + the claim builders)
# ----------------------------------------------------------------------------


def _log2_exact(x: int, what: str) -> int:
    if x <= 0 or x & (x - 1):
        raise CaptureError(f"{what}: {x} is not a power of two")
    return x.bit_length() - 1


def layout_dims(shape: dict) -> dict:
    t, d, f = shape["t"], shape["d"], shape["f"]
    log_t = _log2_exact(t, "shape.t")
    log_db = min((d & -d).bit_length() - 1, 12)
    log_fb = min((f & -f).bit_length() - 1, 12)
    if log_db < 4 or log_fb < 4 or d % (1 << log_db) or f % (1 << log_fb):
        raise CaptureError(f"shape d {d} / f {f}: need >= 16 | d, f")
    nb_d, nb_f = d >> log_db, f >> log_fb
    return {"log_t": log_t, "log_db": log_db, "log_fb": log_fb, "nb_d": nb_d, "nb_f": nb_f,
            "tfb": t << log_fb, "tdb": t << log_db, "log_wb": log_db + log_fb, "log_a_min": log_t + min(log_db, log_fb)}


def expected_claims(role: str, shape: dict, log_n: int, table_log_sizes: Sequence[int], privacy: str) -> dict:
    """The claim list the verifier builds (build_claims_zk_v3 / build_w_zclaims_v3) for
    coverage ffn-v3-function-1, as [(offset, log_size, kind, name, sum_coef)] per claim,
    with the commitment row count and the prox row.  kind in data/mask; the H zero-sum
    pair u is a MASK with a public constraint; the sum claim carries fixed coefficients."""
    L = layout_dims(shape)
    nb_d, nb_f, tfb, tdb = L["nb_d"], L["nb_f"], L["tfb"], L["tdb"]
    n = 1 << log_n
    if len(table_log_sizes) != TAB_SLOTS:
        raise CaptureError(f"{role}: {len(table_log_sizes)} table slots, expected {TAB_SLOTS}")
    for i, ls in enumerate(table_log_sizes):
        if ls < log_n:
            raise CaptureError(f"{role}: table slot {i} log_size {ls} < log_n {log_n}")
    if table_log_sizes[0] != max(8, log_n) or table_log_sizes[1] != max(16, log_n):
        raise CaptureError(f"{role}: table slots 0/1 must be the ACT16 (2^8) / INT16 (2^16) classes, got {table_log_sizes[:2]}")
    tab_rows = [(1 << ls) // n for ls in table_log_sizes]
    if role == "A":
        if log_n > L["log_a_min"]:
            raise CaptureError(f"A: log_n {log_n} > log_a_min {L['log_a_min']}")
        ls_f, ls_d = L["log_t"] + L["log_fb"], L["log_t"] + L["log_db"]
        off = 0
        planes = ["g8", "rg", "a16", "u16", "ru", "h16", "rh"]
        offs: Dict[str, List[int]] = {}
        for pl in planes:
            offs[pl] = [off + b * tfb for b in range(nb_f)]
            off += nb_f * tfb
        for pl in ("X", "z16", "rd"):
            offs[pl] = [off + c * tdb for c in range(nb_d)]
            off += nb_d * tdb
        a_len = off
        if a_len % n:
            raise CaptureError("A: data length not a multiple of n")
        r = a_len // n
        a_mf = list(range(r, r + 7 * nb_f)); r += 7 * nb_f
        a_md = list(range(r, r + 3 * nb_d)); r += 3 * nb_d
        a_mgu = list(range(r, r + nb_d)); r += nb_d
        a_mdd = list(range(r, r + nb_f)); r += nb_f
        a_prox = r; r += 1
        tabs = []
        for i in range(TAB_SLOTS):
            a_row = r; r += tab_rows[i]
            a_mask = r; r += tab_rows[i]
            tabs.append((a_row, a_mask))
        claims = []
        for b in range(nb_f):
            for i, pl in enumerate(planes):
                claims.append([(offs[pl][b], ls_f, "data", f"{pl}[{b}]"), (a_mf[7 * b + i] * n, log_n, "mask", f"a_mf[{7 * b + i}]")])
        for c in range(nb_d):
            for i, pl in enumerate(("X", "z16", "rd")):
                claims.append([(offs[pl][c], ls_d, "data", f"{pl}[{c}]"), (a_md[3 * c + i] * n, log_n, "mask", f"a_md[{3 * c + i}]")])
        for c in range(nb_d):
            claims.append([(offs["X"][c], ls_d, "data", f"X[{c}]"), (a_mgu[c] * n, log_n, "mask", f"a_mgu[{c}]")])
        for b in range(nb_f):
            claims.append([(offs["h16"][b], ls_f, "data", f"h16[{b}]"), (a_mdd[b] * n, log_n, "mask", f"a_mdd[{b}]")])
        for i, (a_row, a_mask) in enumerate(tabs):
            claims.append([(a_row * n, table_log_sizes[i], "data", f"tab[{i}]"), (a_mask * n, table_log_sizes[i], "mask", f"tab[{i}].a_mask")])
        return {"rows": r, "prox_row": a_prox, "claims": claims, "sum_claim": None, "zero_sum_pair": None, "parts_per_claim": 2,
                "group_shape": [7 * nb_f, 3 * nb_d, nb_d, nb_f, TAB_SLOTS]}
    if role == "H":
        ls_f, ls_d = L["log_t"] + L["log_fb"], L["log_t"] + L["log_db"]
        hoff = 0
        pairs: Dict[str, List[Tuple[int, int]]] = {}
        for pl in ("hg", "hu", "hh"):
            pairs[pl] = []
            for b in range(nb_f):
                pairs[pl].append((hoff, hoff + tfb)); hoff += 2 * tfb
        pairs["hz"] = []
        for c in range(nb_d):
            pairs["hz"].append((hoff, hoff + tdb)); hoff += 2 * tdb
        h_len = hoff
        if h_len % n:
            raise CaptureError("H: data length not a multiple of n")
        r = h_len // n
        h_mf = []
        for _ in range(3 * nb_f):
            h_mf.append((r, r + 1)); r += 2
        h_md = []
        for _ in range(nb_d):
            h_md.append((r, r + 1)); r += 2
        h_u = (r, r + 1); r += 2
        h_up = (r, r + 1); r += 2
        h_prox = r; r += 1
        tabs = []
        for i in range(TAB_SLOTS):
            h_re = r; r += tab_rows[i]
            h_im = r; r += tab_rows[i]
            h_mre = r; r += tab_rows[i]
            h_mim = r; r += tab_rows[i]
            tabs.append((h_re, h_im, h_mre, h_mim))
        claims = []
        for b in range(nb_f):
            for i, pl in enumerate(("hg", "hu", "hh")):
                re, im = pairs[pl][b]
                m = h_mf[3 * b + i]
                claims.append([(re, ls_f, "data", f"{pl}[{b}].re"), (im, ls_f, "data", f"{pl}[{b}].im"), (m[0] * n, log_n, "mask", f"h_mf[{3 * b + i}].re"), (m[1] * n, log_n, "mask", f"h_mf[{3 * b + i}].im")])
        for c in range(nb_d):
            re, im = pairs["hz"][c]
            m = h_md[c]
            claims.append([(re, ls_d, "data", f"hz[{c}].re"), (im, ls_d, "data", f"hz[{c}].im"), (m[0] * n, log_n, "mask", f"h_md[{c}].re"), (m[1] * n, log_n, "mask", f"h_md[{c}].im")])
        zs_index = len(claims)
        claims.append([(h_u[0] * n, log_n, "mask", "u.re"), (h_u[1] * n, log_n, "mask", "u.im"), (h_up[0] * n, log_n, "mask", "u'.re"), (h_up[1] * n, log_n, "mask", "u'.im")])
        for i, (h_re, h_im, h_mre, h_mim) in enumerate(tabs):
            ls = table_log_sizes[i]
            claims.append([(h_re * n, ls, "data", f"h_t[{i}].re"), (h_im * n, ls, "data", f"h_t[{i}].im"), (h_mre * n, ls, "mask", f"h_t[{i}].mask.re"), (h_mim * n, ls, "mask", f"h_t[{i}].mask.im")])
        sum_parts = []
        for b in range(nb_f):
            for pl in ("hg", "hu", "hh"):
                re, im = pairs[pl][b]
                sum_parts.append((re, ls_f, "data", f"{pl}[{b}].re", ONE))
                sum_parts.append((im, ls_f, "data", f"{pl}[{b}].im", U))
        for c in range(nb_d):
            re, im = pairs["hz"][c]
            sum_parts.append((re, ls_d, "data", f"hz[{c}].re", ONE))
            sum_parts.append((im, ls_d, "data", f"hz[{c}].im", U))
        for i, (h_re, h_im, _, _) in enumerate(tabs):
            ls = table_log_sizes[i]
            sum_parts.append((h_re * n, ls, "data", f"h_t[{i}].re", f2_neg(ONE)))
            sum_parts.append((h_im * n, ls, "data", f"h_t[{i}].im", f2_neg(U)))
        sum_parts.append((h_u[0] * n, log_n, "mask", "u.re", ONE))
        sum_parts.append((h_u[1] * n, log_n, "mask", "u.im", U))
        sum_index = len(claims)
        claims.append(sum_parts)
        return {"rows": r, "prox_row": h_prox, "claims": claims, "sum_claim": sum_index, "zero_sum_claim": zs_index,
                "zero_sum_pair": (h_u[0], h_u[1]), "parts_per_claim": 4, "group_shape": [3 * nb_f, nb_d, 1, TAB_SLOTS, 1]}
    if role == "W":
        if privacy != "P3":
            raise CaptureError("W: only the P3 (hiding) W opening is a privacy role; P1 W is a plain public opening")
        log_wb = L["log_wb"]
        if log_n > log_wb:
            raise CaptureError(f"W: log_n {log_n} > log_wb {log_wb}")
        wb = 1 << log_wb
        k_blocks = nb_d * nb_f
        woff = 0
        wg = [woff + k * wb for k in range(k_blocks)]; woff += k_blocks * wb
        wu = [woff + k * wb for k in range(k_blocks)]; woff += k_blocks * wb
        wd = [woff + k * wb for k in range(k_blocks)]; woff += k_blocks * wb
        r = woff // n
        w_mgu = list(range(r, r + 2 * k_blocks)); r += 2 * k_blocks
        w_mdd = list(range(r, r + k_blocks)); r += k_blocks
        w_prox = r; r += 1
        claims = []
        for ri, (tag, offs) in enumerate((("Wg", wg), ("Wu", wu))):
            for c in range(nb_d):
                for b in range(nb_f):
                    k = ri * k_blocks + c * nb_f + b
                    claims.append([(offs[c * nb_f + b], log_wb, "data", f"{tag}[{c}][{b}]"), (w_mgu[k] * n, log_n, "mask", f"w_mgu[{k}]")])
        for b in range(nb_f):
            for c in range(nb_d):
                k = b * nb_d + c
                claims.append([(wd[k], log_wb, "data", f"Wd[{b}][{c}]"), (w_mdd[k] * n, log_n, "mask", f"w_mdd[{k}]")])
        return {"rows": r, "prox_row": w_prox, "claims": claims, "sum_claim": None, "zero_sum_pair": None, "parts_per_claim": 2,
                "group_shape": [2 * k_blocks, k_blocks]}
    raise CaptureError(f"unknown role {role!r}")


# ----------------------------------------------------------------------------
# the parser
# ----------------------------------------------------------------------------


class RoleObs:
    """One role's validated observation (exact integers), plus the recomputed row roles."""

    def __init__(self, raw: dict, privacy: str, shape: dict):
        self.role = raw.get("role")
        if self.role not in ("W", "A", "H"):
            raise CaptureError(f"role {self.role!r} is not W/A/H")
        w = f"role {self.role}"
        params = raw.get("params")
        if not isinstance(params, dict):
            raise CaptureError(f"{w}: params missing")
        self.log_n = _uint(params.get("log_cols"), f"{w}.params.log_cols", 1, 16)
        self.inv_rate = _uint(params.get("inv_rate"), f"{w}.params.inv_rate", 1)
        self.num_col_checks = _uint(params.get("num_col_checks"), f"{w}.params.num_col_checks", 0)
        self.n = 1 << self.log_n
        com = raw.get("commitment")
        if not isinstance(com, dict):
            raise CaptureError(f"{w}: commitment missing")
        self.rows = _uint(com.get("rows"), f"{w}.commitment.rows", 1)
        self.root = _bytes32(com.get("root"), f"{w}.commitment.root")
        self.before_state = _bytes32(raw.get("before_state"), f"{w}.before_state")
        self.after_state = _bytes32(raw.get("after_state"), f"{w}.after_state")
        self.before_next = _fp2(raw.get("before_next_challenge"), f"{w}.before_next_challenge")
        self.after_next = _fp2(raw.get("after_next_challenge"), f"{w}.after_next_challenge")
        n, rows = self.n, self.rows
        # claims
        claims_raw = raw.get("claims")
        if not isinstance(claims_raw, list) or not claims_raw:
            raise CaptureError(f"{w}: claims missing or empty")
        self.claims: List[dict] = []
        for k, c in enumerate(claims_raw):
            if not isinstance(c, dict):
                raise CaptureError(f"{w}.claims[{k}]: not an object")
            value = _fp2(c.get("value"), f"{w}.claims[{k}].value")
            parts_raw = c.get("parts")
            if not isinstance(parts_raw, list) or not parts_raw:
                raise CaptureError(f"{w}.claims[{k}].parts missing or empty")
            parts = []
            for pi, p in enumerate(parts_raw):
                pw = f"{w}.claims[{k}].parts[{pi}]"
                if not isinstance(p, dict):
                    raise CaptureError(f"{pw}: not an object")
                offset = _uint(p.get("offset"), pw + ".offset", 0)
                log_size = _uint(p.get("log_size"), pw + ".log_size", 0, 40)
                coef = _fp2(p.get("coefficient"), pw + ".coefficient")
                point_raw = p.get("point")
                if not isinstance(point_raw, list):
                    raise CaptureError(f"{pw}.point: not a list")
                point = [_fp2(x, f"{pw}.point[{i}]") for i, x in enumerate(point_raw)]
                if point and len(point) != log_size:
                    raise CaptureError(f"{pw}: point has {len(point)} coordinates for log_size {log_size}")
                if log_size < self.log_n:
                    raise CaptureError(f"{pw}: log_size {log_size} < log_cols {self.log_n} (a slice narrower than a row)")
                if offset % n:
                    raise CaptureError(f"{pw}: offset {offset} is not row-aligned (n = {n})")
                row0 = offset // n
                nrows = (1 << log_size) // n
                if row0 + nrows > rows:
                    raise CaptureError(f"{pw}: rows [{row0}, {row0 + nrows}) exceed the commitment's {rows} rows")
                rb = log_size - self.log_n
                rw = eq_table_msb(point[:rb]) if point else [ONE] * nrows
                tail = point[rb:] if point else None
                parts.append({"offset": offset, "log_size": log_size, "coef": coef, "point": point, "row0": row0, "nrows": nrows, "rw": rw, "tail": tail})
            self.claims.append({"value": value, "parts": parts, "group": None})
        # groups
        groups_raw = raw.get("groups")
        if not isinstance(groups_raw, list) or not groups_raw:
            raise CaptureError(f"{w}: groups missing or empty")
        self.groups: List[dict] = []
        seen: Dict[int, int] = {}
        for gi, g in enumerate(groups_raw):
            gw = f"{w}.groups[{gi}]"
            if not isinstance(g, dict):
                raise CaptureError(f"{gw}: not an object")
            members = g.get("members")
            lambdas = g.get("lambdas")
            if not isinstance(members, list) or not members:
                raise CaptureError(f"{gw}.members missing or empty")
            if not isinstance(lambdas, list) or len(lambdas) != len(members):
                raise CaptureError(f"{gw}: {len(lambdas) if isinstance(lambdas, list) else 'no'} lambdas for {len(members)} members")
            mem = []
            for m in members:
                m = _uint(m, gw + ".members[]", 0, len(self.claims) - 1)
                if m in seen:
                    raise CaptureError(f"{gw}: claim {m} is already a member of group {seen[m]}")
                seen[m] = gi
                mem.append(m)
                self.claims[m]["group"] = gi
            lams = [_fp2(x, f"{gw}.lambdas[{i}]") for i, x in enumerate(lambdas)]
            key = g.get("key")
            if not isinstance(key, dict):
                raise CaptureError(f"{gw}.key missing")
            tail = [_fp2(x, f"{gw}.key.tail[{i}]") for i, x in enumerate(key.get("tail", None) if isinstance(key.get("tail"), list) else [None])]
            if key.get("offset") != 0 or key.get("len") != n:
                raise CaptureError(f"{gw}.key: offset {key.get('offset')!r} / len {key.get('len')!r} unsupported (expected 0 / {n})")
            if tail and len(tail) != self.log_n:
                raise CaptureError(f"{gw}.key.tail has {len(tail)} coordinates, expected 0 or {self.log_n}")
            vec_raw = g.get("vector")
            if not isinstance(vec_raw, list) or len(vec_raw) < n:
                raise CaptureError(f"{gw}.vector: {len(vec_raw) if isinstance(vec_raw, list) else 'no'} entries < n = {n}")
            vector = [_fp2(x, f"{gw}.vector[{i}]") for i, x in enumerate(vec_raw)]
            cw = eq_table_msb(tail) if tail else [ONE] * n
            # every member part must share the key's column tail
            for m in mem:
                for pi, p in enumerate(self.claims[m]["parts"]):
                    if p["tail"] is None:
                        if tail:
                            raise CaptureError(f"{gw}: member {m} part {pi} has no point but the key has a tail")
                    elif p["tail"] != tail:
                        raise CaptureError(f"{gw}: member {m} part {pi} column tail differs from the group key")
            # the public identity sum_j cw[j] v[j] = sum_k lambda_k value_k
            lhs = ZERO
            for j in range(n):
                lhs = f2_add(lhs, f2_mul(cw[j], vector[j]))
            rhs = ZERO
            for m, lam in zip(mem, lams):
                rhs = f2_add(rhs, f2_mul(lam, self.claims[m]["value"]))
            if lhs != rhs:
                raise CaptureError(f"{gw}: the clear vector does not reproduce its members' terminals (sum_j eq(tail)[j] v[j] != sum_k lambda_k value_k)")
            self.groups.append({"members": mem, "lambdas": lams, "tail": tail, "cw": cw, "vector": vector, "pad_entries": len(vector) - n})
        for k, c in enumerate(self.claims):
            if c["group"] is None:
                raise CaptureError(f"{w}: claim {k} belongs to no group")
        # proximity
        rhos = raw.get("proximity_rhos")
        if not isinstance(rhos, list) or len(rhos) != rows:
            raise CaptureError(f"{w}.proximity_rhos: {len(rhos) if isinstance(rhos, list) else 'no'} entries for {rows} rows")
        self.rho = [_fp2(x, f"{w}.proximity_rhos[{i}]") for i, x in enumerate(rhos)]
        pv = raw.get("proximity_vector")
        if not isinstance(pv, list) or len(pv) < n:
            raise CaptureError(f"{w}.proximity_vector: fewer than n entries")
        self.prox_vector = [_fp2(x, f"{w}.proximity_vector[{i}]") for i, x in enumerate(pv)]
        cols = raw.get("columns")
        if not isinstance(cols, list):
            raise CaptureError(f"{w}.columns missing")
        self.sampled_columns = []
        for ci, col in enumerate(cols):
            cwn = f"{w}.columns[{ci}]"
            if not isinstance(col, dict):
                raise CaptureError(f"{cwn}: not an object")
            idx = _uint(col.get("index"), cwn + ".index", 0, n * self.inv_rate - 1)
            vals = col.get("values")
            if not isinstance(vals, list) or len(vals) != rows:
                raise CaptureError(f"{cwn}.values: not {rows} entries")
            for i, v in enumerate(vals):
                _fp(v, f"{cwn}.values[{i}]")
            _bytes32(col.get("salt"), cwn + ".salt")
            if not isinstance(col.get("path"), list):
                raise CaptureError(f"{cwn}.path missing")
            self.sampled_columns.append(idx)
        # the recomputed layout: every claim's slices must match; this yields the row roles
        table_log_sizes = self._observed_table_log_sizes()
        self.layout = expected_claims(self.role, shape, self.log_n, table_log_sizes, privacy)
        exp = self.layout["claims"]
        if self.layout["rows"] != rows:
            raise CaptureError(f"{w}: commitment has {rows} rows, the {COVERAGE_F1} layout has {self.layout['rows']}")
        if len(exp) != len(self.claims):
            raise CaptureError(f"{w}: {len(self.claims)} claims, the layout builds {len(exp)}")
        self.part_kind: List[List[str]] = []
        self.part_name: List[List[str]] = []
        for k, (c, e) in enumerate(zip(self.claims, exp)):
            if len(c["parts"]) != len(e):
                raise CaptureError(f"{w}.claims[{k}]: {len(c['parts'])} parts, the layout has {len(e)}")
            kinds, names = [], []
            for pi, (p, ep) in enumerate(zip(c["parts"], e)):
                if (p["offset"], p["log_size"]) != (ep[0], ep[1]):
                    raise CaptureError(f"{w}.claims[{k}].parts[{pi}]: slice ({p['offset']}, 2^{p['log_size']}) is not the layout's ({ep[0]}, 2^{ep[1]}) for {ep[3]}")
                if len(ep) == 5 and p["coef"] != ep[4]:
                    raise CaptureError(f"{w}.claims[{k}].parts[{pi}]: sum-claim coefficient is not the fixed {ep[4]}")
                if len(ep) == 5 and p["point"]:
                    raise CaptureError(f"{w}.claims[{k}].parts[{pi}]: the sum claim must have no point")
                kinds.append(ep[2])
                names.append(ep[3])
            self.part_kind.append(kinds)
            self.part_name.append(names)
        if self.role == "H":
            for k, c in enumerate(self.claims):
                if k == self.layout["sum_claim"]:
                    if c["value"] != ZERO:
                        raise CaptureError(f"{w}: the LogUp sum claim's value is not 0")
                    continue
                ps = c["parts"]
                if f2_mul(ps[0]["coef"], U) != ps[1]["coef"] or f2_mul(ps[2]["coef"], U) != ps[3]["coef"]:
                    raise CaptureError(f"{w}.claims[{k}]: not the (k, k u) Fp2 pair form on data and mask")
        # group shape (first-occurrence order) must be the layout's
        shape_got = [len(g["members"]) for g in self.groups]
        if shape_got != self.layout["group_shape"]:
            raise CaptureError(f"{w}: group shape {shape_got} is not the layout's {self.layout['group_shape']}")
        # row roles
        self.row_kind = ["unref"] * rows
        self.row_name = [""] * rows
        for k, c in enumerate(self.claims):
            for pi, p in enumerate(c["parts"]):
                kind, name = self.part_kind[k][pi], self.part_name[k][pi]
                for r in range(p["row0"], p["row0"] + p["nrows"]):
                    if self.row_kind[r] not in ("unref", kind):
                        raise CaptureError(f"{w}: row {r} is data in one claim and mask in another")
                    self.row_kind[r] = kind
                    if not self.row_name[r]:
                        self.row_name[r] = name
        unref = [r for r in range(rows) if self.row_kind[r] == "unref"]
        if unref != [self.layout["prox_row"]]:
            raise CaptureError(f"{w}: unreferenced rows {unref[:4]}{'...' if len(unref) > 4 else ''} are not exactly the prox row {self.layout['prox_row']}")
        self.row_kind[self.layout["prox_row"]] = "prox"
        self.row_name[self.layout["prox_row"]] = {"A": "a_prox", "H": "h_prox", "W": "w_prox"}[self.role]
        self.data_rows = [r for r in range(rows) if self.row_kind[r] == "data"]
        self.mask_rows = [r for r in range(rows) if self.row_kind[r] in ("mask", "prox")]

    def _observed_table_log_sizes(self) -> List[int]:
        # the six table claims are the last six pointed claims of A / the six 4-part
        # claims before the sum claim in H; W has none (its layout uses no tables)
        if self.role == "W":
            return [max(8, self.log_n), max(16, self.log_n)] + [self.log_n] * 4
        pointed = [k for k, c in enumerate(self.claims) if c["parts"][0]["point"]]
        if len(pointed) < TAB_SLOTS:
            raise CaptureError(f"role {self.role}: fewer than {TAB_SLOTS} pointed claims")
        return [self.claims[k]["parts"][0]["log_size"] for k in pointed[-TAB_SLOTS:]]

    def planes(self) -> Dict[str, List[int]]:
        """Data planes: name (H re/im rows merged) -> sorted row list."""
        out: Dict[str, List[int]] = {}
        for r in self.data_rows:
            name = self.row_name[r]
            for sfx in (".re", ".im"):
                if name.endswith(sfx):
                    name = name[: -len(sfx)]
            out.setdefault(name, []).append(r)
        return out

    def aliases(self) -> Dict[str, dict]:
        """Rows opened by more than one claim (the shared row identities), by plane name."""
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
            rows = sorted(e["rows"])
            e["rows"] = rows if len(rows) <= 4 else [rows[0], "...", rows[-1]]
            e["row_count"] = len(rows)
        return out

    def summary(self) -> dict:
        return {"role": self.role, "log_cols": self.log_n, "n": self.n, "inv_rate": self.inv_rate, "num_col_checks": self.num_col_checks,
                "rows": self.rows, "data_rows": len(self.data_rows), "mask_rows": len(self.mask_rows), "claims": len(self.claims),
                "groups": [len(g["members"]) for g in self.groups], "pad_entries_per_vector": self.groups[0]["pad_entries"],
                "sampled_columns": len(self.sampled_columns), "root": self.root, "before_state": self.before_state, "after_state": self.after_state,
                "before_next_challenge": list(self.before_next), "after_next_challenge": list(self.after_next),
                "claim_slices": [[(p["offset"], p["log_size"], self.part_kind[k][pi], self.part_name[k][pi]) for pi, p in enumerate(c["parts"])] for k, c in enumerate(self.claims)],
                "prox_row": self.layout["prox_row"], "zero_sum_pair_rows": self.layout.get("zero_sum_pair"), "aliased_rows": self.aliases()}


class Capture:
    def __init__(self, path: str, expected_capture_sha256: Optional[str] = None, require_digest_name: bool = True):
        self.path = path
        self.file_sha256 = sha256_file(path)
        if expected_capture_sha256 is not None and expected_capture_sha256 != self.file_sha256:
            raise CaptureError(f"{os.path.basename(path)}: file sha256 {self.file_sha256[:16]}.. differs from the expected {expected_capture_sha256[:16]}..")
        with open(path, "rb") as fh:
            raw_bytes = fh.read()
        try:
            raw = json.loads(raw_bytes)
        except ValueError as e:
            raise CaptureError(f"{os.path.basename(path)}: malformed JSON ({e})") from None
        if not isinstance(raw, dict):
            raise CaptureError("capture is not a JSON object")
        if raw.get("schema") != SCHEMA:
            raise CaptureError(f"schema {raw.get('schema')!r} is not {SCHEMA}")
        if raw.get("kind") != KIND:
            raise CaptureError(f"kind {raw.get('kind')!r} is not {KIND!r}")
        self.coverage = raw.get("coverage")
        if self.coverage != COVERAGE_F1:
            raise CaptureError(f"coverage {self.coverage!r} is not {COVERAGE_F1!r} (function-2 / repaired-profile captures need the handoff schema)")
        if raw.get("fully_verified") is not True:
            raise CaptureError("capture is not marked fully_verified")
        self.privacy = raw.get("privacy")
        if self.privacy not in ("P1", "P3"):
            raise CaptureError(f"privacy {self.privacy!r}")
        if raw.get("field_modulus") != P or raw.get("extension_nonresidue") != NONRESIDUE:
            raise CaptureError("field modulus / nonresidue are not Goldilocks / u^2 = 7")
        shape = raw.get("shape")
        if not isinstance(shape, dict) or any(not _is_int(shape.get(k)) or shape.get(k) <= 0 for k in ("t", "d", "f")):
            raise CaptureError("shape must give positive integers t, d, f")
        self.shape = {k: shape[k] for k in ("t", "d", "f")}
        ps = raw.get("proof_sha256")
        if not isinstance(ps, str) or len(ps) != 64 or any(ch not in "0123456789abcdef" for ch in ps):
            raise CaptureError("proof_sha256 is not a lowercase 64-hex digest")
        self.proof_sha256 = ps
        stem = os.path.basename(path)
        if require_digest_name and stem != ps + ".json":
            raise CaptureError(f"file name {stem} is not the digest name {ps[:16]}...json")
        roles_raw = raw.get("roles")
        if not isinstance(roles_raw, list) or not roles_raw:
            raise CaptureError("roles missing or empty")
        self.roles: List[RoleObs] = []
        names = []
        for rr in roles_raw:
            ro = RoleObs(rr, self.privacy, self.shape)
            if ro.role in names:
                raise CaptureError(f"role {ro.role} appears twice")
            names.append(ro.role)
            self.roles.append(ro)
        want = ["W", "A", "H"] if self.privacy == "P3" else ["A", "H"]
        if names != want:
            raise CaptureError(f"roles {names} are not {want} for {self.privacy}")
        # transcript endpoints must chain W -> A -> H
        for a, b in zip(self.roles, self.roles[1:]):
            if a.after_state != b.before_state or a.after_next != b.before_next:
                raise CaptureError(f"transcript endpoint of {a.role} does not connect to {b.role}")
        del raw, raw_bytes

    def header(self) -> dict:
        return {"file": os.path.basename(self.path), "file_sha256": self.file_sha256, "proof_sha256": self.proof_sha256, "privacy": self.privacy,
                "shape": self.shape, "coverage": self.coverage, "roles": [r.role for r in self.roles]}


# ----------------------------------------------------------------------------
# exact incremental echelon basis (dual / column-space elimination)
# ----------------------------------------------------------------------------


class Echelon:
    def __init__(self, dim: int):
        self.dim = dim
        self.piv: Dict[int, List[int]] = {}

    def insert(self, v: Sequence[int]) -> bool:
        v = [x % P for x in v]
        piv = self.piv
        for c in range(self.dim):
            x = v[c]
            if not x:
                continue
            row = piv.get(c)
            if row is None:
                inv = pow(x, P - 2, P)
                piv[c] = [(y * inv) % P for y in v]
                return True
            v = [(y - x * z) % P for y, z in zip(v, row)]
        return False

    @property
    def rank(self) -> int:
        return len(self.piv)

    def copy(self) -> "Echelon":
        e = Echelon(self.dim)
        e.piv = {c: list(r) for c, r in self.piv.items()}
        return e


def _row_span_basis(vectors: List[List[int]]) -> List[List[int]]:
    red, _ = R.rref(vectors)
    return red


# ----------------------------------------------------------------------------
# the joint model
# ----------------------------------------------------------------------------


class Site:
    __slots__ = ("key", "rows", "kind", "name", "basis", "gens")

    def __init__(self, key, kind, name):
        self.key = key
        self.rows: List[int] = []
        self.kind = kind
        self.name = name
        self.basis: List[List[int]] = []
        self.gens: List[int] = []


class RoleModel:
    """The full observation system of one role, compressed exactly (see the module docstring).
    `extras`: additional cross-column Fp2 observations with column-independent coefficients
    {row: Fp2}; by default H gets its zero-sum constraint on the u pair."""

    def __init__(self, obs: RoleObs, extras: Optional[List[dict]] = None, zero_sum: bool = True):
        self.obs = obs
        self.n = obs.n
        self.rows = obs.rows
        G = len(obs.groups)
        K = len(obs.claims)
        self.nb = 2 * G + 2          # block coords: 2 per group + 2 prox
        self.extras: List[dict] = list(extras or [])
        if zero_sum and obs.role == "H":
            u_re, u_im = obs.layout["zero_sum_pair"]
            self.extras.insert(0, {"name": "zero_sum(u)", "coefs": {u_re: ONE, u_im: U}, "public_value": ZERO,
                                   "source": "zsum sumcheck: sum over the n-cube of u = 0 (zk.rs prove/verify 'zero-sum sumcheck'; claimed sum Gamma_zs = c_zs * sum g)"})
        E = len(self.extras)
        self.K, self.E = K, E
        self.tdim = 2 * K + 2 * E    # cross coords: 2 per claim terminal + 2 per extra
        # the coefficient on (row, column j) of claim k part p is coef * rw[r] * cw_g[j]:
        # per-row references
        ref: List[List[Tuple[int, int, Fp2]]] = [[] for _ in range(self.rows)]
        for k, c in enumerate(obs.claims):
            for pi, p in enumerate(c["parts"]):
                for i in range(p["nrows"]):
                    ref[p["row0"] + i].append((k, pi, p["rw"][i]))
        extra_on: List[List[Tuple[int, Fp2]]] = [[] for _ in range(self.rows)]
        for ei, e in enumerate(self.extras):
            for r, cf in e["coefs"].items():
                if r < 0 or r >= self.rows:
                    raise CaptureError(f"extra observation {e['name']}: row {r} outside the commitment")
                extra_on[r].append((ei, cf))
        # sites
        self.sites: List[Site] = []
        index: Dict[tuple, int] = {}
        feats: List[List[List[int]]] = []
        for r in range(self.rows):
            # rows with the same claim memberships, extra-observation coefficients, kind
            # and plane form one site (its generators are compressed to a feature basis)
            key = (tuple((k, pi) for k, pi, _ in ref[r]), tuple(extra_on[r]), obs.row_kind[r], obs.row_name[r])
            si = index.get(key)
            if si is None:
                si = len(self.sites)
                index[key] = si
                self.sites.append(Site(key, obs.row_kind[r], obs.row_name[r]))
                feats.append([])
            self.sites[si].rows.append(r)
            feat: List[int] = []
            for _, _, rw in ref[r]:
                feat.extend(rw)
            feat.extend(obs.rho[r])
            feat.append(1)
            feats[si].append(feat)
        # generators: one per site basis vector
        self.beta: List[List[int]] = []      # block coords
        self.zeta: List[Dict[int, Fp2]] = []  # claim -> Fp2 (before column scaling)
        self.xi: List[Dict[int, int]] = []    # extra coord -> Fp
        self.gen_site: List[int] = []
        for si, s in enumerate(self.sites):
            s.basis = _row_span_basis(feats[si])
            memb, ex = s.key[0], s.key[1]
            for b in s.basis:
                beta = [0] * self.nb
                zeta: Dict[int, Fp2] = {}
                xi: Dict[int, int] = {}
                for t_, (k, pi) in enumerate(memb):
                    x = (b[2 * t_], b[2 * t_ + 1])
                    part = obs.claims[k]["parts"][pi]
                    g = obs.claims[k]["group"]
                    lam = obs.groups[g]["lambdas"][obs.groups[g]["members"].index(k)]
                    cz = f2_mul(part["coef"], x)
                    cb = f2_mul(lam, cz)
                    beta[2 * g] = (beta[2 * g] + cb[0]) % P
                    beta[2 * g + 1] = (beta[2 * g + 1] + cb[1]) % P
                    zeta[k] = f2_add(zeta.get(k, ZERO), cz)
                m = len(memb)
                rho = (b[2 * m], b[2 * m + 1])
                beta[2 * G] = (beta[2 * G] + rho[0]) % P
                beta[2 * G + 1] = (beta[2 * G + 1] + rho[1]) % P
                one = b[2 * m + 2]
                for ei, cf in ex:
                    xi[2 * K + 2 * ei] = (xi.get(2 * K + 2 * ei, 0) + cf[0] * one) % P
                    xi[2 * K + 2 * ei + 1] = (xi.get(2 * K + 2 * ei + 1, 0) + cf[1] * one) % P
                s.gens.append(len(self.beta))
                self.beta.append(beta)
                self.zeta.append(zeta)
                self.xi.append(xi)
                self.gen_site.append(si)
        self.claim_cw = [obs.groups[c["group"]]["cw"] for c in obs.claims]
        self._cache: Dict[tuple, tuple] = {}

    # generator sets ----------------------------------------------------------
    def gens_of(self, pred) -> Tuple[int, ...]:
        return tuple(g for si, s in enumerate(self.sites) if pred(s) for g in s.gens)

    def mask_gens(self) -> Tuple[int, ...]:
        return self.gens_of(lambda s: s.kind in ("mask", "prox"))

    def all_gens(self) -> Tuple[int, ...]:
        return tuple(range(len(self.beta)))

    def plane_gens(self, rows: Iterable[int]) -> Tuple[int, ...]:
        rs = set(rows)
        return self.gens_of(lambda s: s.kind == "data" and any(r in rs for r in s.rows))

    # the block part and the cross-column kernel ------------------------------
    def block_and_z(self, gens: Tuple[int, ...]) -> Tuple[int, List[List[int]]]:
        """(per-column block rank r_X, basis of Z_X) for a generator set."""
        key = ("bz", gens)
        if key in self._cache:
            return self._cache[key]
        if not gens:
            self._cache[key] = (0, [])
            return 0, []
        beta_rows = [self.beta[a] for a in gens]
        null = R.left_null_space(beta_rows, self.nb)
        r = len(gens) - len(null)
        zs: List[List[int]] = []
        for c in null:
            z = [0] * self.tdim
            for ca, a in zip(c, gens):
                if not ca:
                    continue
                for k, v in self.zeta[a].items():
                    z[2 * k] = (z[2 * k] + ca * v[0]) % P
                    z[2 * k + 1] = (z[2 * k + 1] + ca * v[1]) % P
                for t_, v in self.xi[a].items():
                    z[t_] = (z[t_] + ca * v) % P
            if any(z):
                zs.append(z)
        zb = _row_span_basis(zs) if zs else []
        self._cache[key] = (r, zb)
        return r, zb

    def _scaled(self, z: List[int], j: int) -> List[int]:
        w = list(z)
        for k in range(self.K):
            a, b = z[2 * k], z[2 * k + 1]
            if a or b:
                s = f2_mul((a, b), self.claim_cw[k][j])
                w[2 * k], w[2 * k + 1] = s
        return w

    def kernel_dim(self, zb: List[List[int]], columns: Optional[Iterable[int]] = None, ech: Optional[Echelon] = None) -> Echelon:
        ech = ech if ech is not None else Echelon(self.tdim)
        if not zb:
            return ech
        for j in (range(self.n) if columns is None else columns):
            if ech.rank == self.tdim:
                break
            for z in zb:
                ech.insert(self._scaled(z, j))
        return ech

    def rank(self, gens: Tuple[int, ...]) -> dict:
        key = ("rank", gens)
        if key in self._cache:
            return self._cache[key]
        r, zb = self.block_and_z(gens)
        kd = self.kernel_dim(zb).rank
        out = {"block_rank_per_column": r, "kernel_dim": kd, "rank": self.n * r + kd}
        self._cache[key] = out
        return out

    def rank_with_column_exception(self, gens: Tuple[int, ...], j0: int, gens_at_j0: Tuple[int, ...]) -> int:
        r, zb = self.block_and_z(gens)
        r0, zb0 = self.block_and_z(gens_at_j0)
        ech = self.kernel_dim(zb, columns=[j for j in range(self.n) if j != j0])
        ech = self.kernel_dim(zb0, columns=[j0], ech=ech)
        return (self.n - 1) * r + r0 + ech.rank

    # analysis -----------------------------------------------------------------
    def analyze(self, planes: bool = True, plane_columns: Sequence[int] = ()) -> dict:
        obs = self.obs
        masks, alls = self.mask_gens(), self.all_gens()
        rm, ra = self.rank(masks), self.rank(alls)
        n_obs = self.n * self.nb + self.tdim
        out = {
            "unknowns": {"total": self.rows * self.n, "data": len(obs.data_rows) * self.n, "mask": len(obs.mask_rows) * self.n},
            "base_observation_rows": {"group_vectors": self.n * 2 * len(obs.groups), "proximity": 2 * self.n, "terminals": 2 * self.K, "extras": 2 * self.E, "total": n_obs},
            "extras": [{"name": e["name"], "rows": sorted(e["coefs"]), "public_value": list(e.get("public_value", ZERO)), "source": e.get("source", "")} for e in self.extras],
            "sites": len(self.sites), "generators": len(self.beta),
            "per_column": {"rank_mask": rm["block_rank_per_column"], "rank_joint": ra["block_rank_per_column"], "disclosed_per_column": ra["block_rank_per_column"] - rm["block_rank_per_column"], "base_rows_per_column": self.nb},
            "joint": {"rank_mask": rm["rank"], "rank_joint": ra["rank"], "disclosed_total": ra["rank"] - rm["rank"],
                      "cross_column_kernel_mask": rm["kernel_dim"], "cross_column_kernel_joint": ra["kernel_dim"],
                      "cross_column_increment": (ra["kernel_dim"] - rm["kernel_dim"]),
                      "per_column_total": self.n * (ra["block_rank_per_column"] - rm["block_rank_per_column"]),
                      "null_functionals_killing_masks_and_data": n_obs - ra["rank"]},
        }
        if planes:
            pl = {}
            for name, rows in obs.planes().items():
                pg = self.plane_gens(rows)
                rest = tuple(a for a in alls if a not in set(pg))
                proj = self.rank(tuple(sorted(set(masks) | set(pg))))["rank"] - rm["rank"]
                iso = ra["rank"] - self.rank(rest)["rank"]
                entry = {"rows": rows if len(rows) <= 8 else [rows[0], "...", rows[-1]], "row_count": len(rows), "unknowns": len(rows) * self.n,
                         "projected_disclosed_dim": proj, "isolated_disclosed_dim": iso,
                         "fully_recovered": iso == len(rows) * self.n}
                if plane_columns:
                    at = {}
                    for j0 in plane_columns:
                        j0 = j0 % self.n  # -1 = the last column
                        at[str(j0)] = ra["rank"] - self.rank_with_column_exception(alls, j0, rest)
                    entry["isolated_disclosed_dim_at_column"] = at
                pl[name] = entry
            out["planes"] = pl
        return out


# ----------------------------------------------------------------------------
# the singleton reproduction (the actual L_b projection on the captured vector)
# ----------------------------------------------------------------------------


def singleton_functionals(obs: RoleObs, gi: int) -> dict:
    """For a singleton group [k] whose claim is (data slice, ONE single-row base mask):
    L_b(v[j]) = det(v[j], b), b = lambda * coef_mask, is a mask-free combination
    sum_r w_r D[r][j] with public weights w_r = det(lambda coef_data rw[r], b).
    Returns the rows, the weights and DIGESTS of the functional values (and of the
    recovered row when the plane is one row).  The values themselves never leave."""
    g = obs.groups[gi]
    if len(g["members"]) != 1:
        raise CaptureError(f"group {gi} is not a singleton")
    k = g["members"][0]
    lam = g["lambdas"][0]
    c = obs.claims[k]
    parts = c["parts"]
    data = [(pi, p) for pi, p in enumerate(parts) if obs.part_kind[k][pi] == "data"]
    mask = [(pi, p) for pi, p in enumerate(parts) if obs.part_kind[k][pi] == "mask"]
    if len(mask) != 1 or mask[0][1]["nrows"] != 1 or len(data) != 1:
        raise CaptureError(f"claim {k}: not (one data slice + one single-row mask)")
    (dpi, dp), (mpi, mp) = data[0], mask[0]
    b = f2_mul(lam, f2_mul(mp["coef"], mp["rw"][0]))
    if b == ZERO:
        raise CaptureError(f"claim {k}: zero mask coefficient")
    la = f2_mul(lam, dp["coef"])
    rows = list(range(dp["row0"], dp["row0"] + dp["nrows"]))
    weights = [det(f2_mul(la, rw), b) for rw in dp["rw"]]
    if not any(weights):
        raise CaptureError(f"claim {k}: all-zero weights (degenerate coefficients)")
    values = [det(g["vector"][j], b) for j in range(obs.n)]
    out = {"group": gi, "claim": k, "plane": obs.part_name[k][dpi], "mask_row": mp["row0"], "mask_name": obs.part_name[k][mpi],
           "data_rows": rows, "row_weights_eq": [list(x) for x in dp["rw"]], "base_weights_w_r": weights,
           "functional_values_sha256": sha256_values(values), "functionals": obs.n, "rows_per_functional": len(rows)}
    if len(rows) == 1:
        inv = pow(weights[0], P - 2, P)
        rec = [(v * inv) % P for v in values]
        out["recovered_row_sha256"] = sha256_values(rec)
        out["recovered_entries"] = obs.n
    # cross-check: the terminal is implied by the vector (trivial identity)
    lhs = ZERO
    for j in range(obs.n):
        lhs = f2_add(lhs, f2_mul(g["cw"][j], g["vector"][j]))
    out["terminal_identity_holds"] = lhs == f2_mul(lam, c["value"])
    return out


def h_identity_extra(obs: RoleObs) -> dict:
    """The LogUp identity restricted to the DATA rows: the sum claim's parts without u."""
    k = obs.layout["sum_claim"]
    coefs: Dict[int, Fp2] = {}
    for pi, p in enumerate(obs.claims[k]["parts"]):
        if obs.part_kind[k][pi] != "data":
            continue
        for r in range(p["row0"], p["row0"] + p["nrows"]):
            coefs[r] = f2_add(coefs.get(r, ZERO), p["coef"])
    return {"name": "logup_identity_on_data", "coefs": coefs, "public_value": ZERO, "source": "the sum claim's data parts: sum_j (helpers - table helpers) = -sum_j u = 0"}


# ----------------------------------------------------------------------------
# Codex's per-column subset, reproduced literally (results/zk60_round11_evidence/captured_rank.py)
# ----------------------------------------------------------------------------


def codex_per_column(obs: RoleObs) -> dict:
    """The 2*groups + 2 base rows of ONE column over all row unknowns, Codex's row
    classification (part index < 1 (A/W) / < 2 (H) is data; H claim 4 all mask; the
    sole unreferenced row mask), rank over masks and over data + masks."""
    n, rows = obs.n, obs.rows
    kinds: Dict[int, str] = {}
    for ci, c in enumerate(obs.claims):
        if not c["parts"][0]["point"]:
            continue
        for pi, p in enumerate(c["parts"]):
            kind = "data" if pi < (2 if obs.role == "H" else 1) else "mask"
            if obs.role == "H" and ci == 4:
                kind = "mask"
            for r in range(p["row0"], p["row0"] + p["nrows"]):
                if r in kinds and kinds[r] != kind:
                    raise CaptureError("codex classification conflict")
                kinds[r] = kind
    unused = set(range(rows)) - set(kinds)
    if len(unused) != 1:
        raise CaptureError("codex: not exactly one unreferenced row")
    for r in unused:
        kinds[r] = "mask"
    data = [r for r in range(rows) if kinds[r] == "data"]
    masks = [r for r in range(rows) if kinds[r] == "mask"]
    observations: List[List[Fp2]] = []
    for g in obs.groups:
        coefficients = [ZERO] * rows
        for ci, lam in zip(g["members"], g["lambdas"]):
            for p in obs.claims[ci]["parts"]:
                factor = f2_mul(lam, p["coef"])
                for i, w in enumerate(p["rw"]):
                    r = p["row0"] + i
                    coefficients[r] = f2_add(coefficients[r], f2_mul(factor, w))
        observations.append(coefficients)
    observations.append(list(obs.rho))
    base = [[c[k] for c in o] for o in observations for k in (0, 1)]
    b = [[row[r] for r in masks] for row in base]
    ab = [[row[r] for r in data + masks] for row in base]
    rank_b, rank_j = R.rank(b), R.rank(ab)
    same = (data == obs.data_rows) and (masks == obs.mask_rows)
    return {"data_rows": len(data), "mask_rows": len(masks), "base_observation_rows": len(base), "rank_mask": rank_b, "rank_joint": rank_j,
            "disclosed_base_functionals_per_column": rank_j - rank_b, "classification_equals_layout_recomputation": same}


# ----------------------------------------------------------------------------
# the driver
# ----------------------------------------------------------------------------


def load_parity(path: str) -> dict:
    with open(path) as fh:
        rec = json.load(fh)
    if rec.get("schema_version") != 1:
        raise CaptureError("parity record: schema_version != 1")
    pairs = {}
    for e in rec.get("seeded_captures_identical", []):
        pairs[e["proof_sha256"]] = e["capture_sha256"]
    return {"path": path, "sha256": sha256_file(path), "seeded": pairs, "initial_directory": rec.get("initial_directory"), "final_directory": rec.get("final_directory"),
            "fresh_capture_hashes_differ": rec.get("fresh_capture_hashes_differ")}


def analyze_capture(cap: Capture, planes: bool = True, plane_columns: Sequence[int] = (), log=None) -> List[dict]:
    cases = []
    for obs in cap.roles:
        t0 = time.time()
        rec = {**cap.header(), **{"role": obs.role, "role_summary": obs.summary()}}
        rec["included_observation_classes"] = sorted(k for k in INCLUDED_CLASSES if k != "zero_sum" or obs.role == "H")
        rec["excluded_observation_classes"] = sorted(EXCLUDED_CLASSES)
        rec["codex_subset_reproduction"] = codex_per_column(obs)
        model = RoleModel(obs)
        rec["analysis"] = model.analyze(planes=planes, plane_columns=plane_columns)
        # the singleton reproductions
        rec["singleton_reproductions"] = []
        for gi, g in enumerate(obs.groups):
            if len(g["members"]) == 1 and obs.claims[g["members"][0]]["parts"][0]["point"]:
                k = g["members"][0]
                if sum(1 for pi in range(len(obs.claims[k]["parts"])) if obs.part_kind[k][pi] == "mask") == 1:
                    rec["singleton_reproductions"].append(singleton_functionals(obs, gi))
        if obs.role == "H":
            # (i) without the zero-sum constraint; (ii) is the residual exactly the public identity?
            no_zs = RoleModel(obs, zero_sum=False).analyze(planes=False)
            with_id = RoleModel(obs, extras=[h_identity_extra(obs)])
            ra = with_id.rank(with_id.all_gens())["rank"]
            rec["h_zero_sum"] = {
                "disclosed_without_zero_sum_constraint": no_zs["joint"]["disclosed_total"],
                "disclosed_with_zero_sum_constraint": rec["analysis"]["joint"]["disclosed_total"],
                "identity_rows_in_observation_row_space": ra == rec["analysis"]["joint"]["rank_joint"],
                "residual_equals_public_logup_identity": (ra == rec["analysis"]["joint"]["rank_joint"] and rec["analysis"]["joint"]["disclosed_total"] == 2),
                "meaning": "the surviving functionals are exactly the LogUp identity sum_j(helpers - table helpers) whose value the proof fixes to 0; a known constant, not a witness functional -- and this is a rank statement under fixed coefficients, not H privacy",
            }
        rec["seconds"] = round(time.time() - t0, 2)
        if log:
            log(f"  {cap.proof_sha256[:12]} {cap.privacy} T{cap.shape['t']} {obs.role}: per-column {rec['analysis']['per_column']['disclosed_per_column']}, joint {rec['analysis']['joint']['disclosed_total']} ({rec['seconds']} s)")
        cases.append(rec)
    return cases


def run(final_dir: str, initial_dir: Optional[str], parity_path: Optional[str], codex_path: Optional[str], out_path: Optional[str],
        planes: bool = True, plane_columns: Sequence[int] = (0, -1), only: Optional[Sequence[str]] = None, log=print) -> dict:
    report: dict = {"schema_version": 1, "task": "FA7 -- captured joint observations", "reviewer": REVIEWER, "source_commit": SOURCE_COMMIT,
                    "capture_source_commit": CAPTURE_SOURCE_COMMIT,
                    "tool_sha256": {"zk60_fable_joint_capture.py": sha256_file(os.path.abspath(__file__)), "zk60_fable_joint_rank.py": sha256_file(os.path.join(_HERE, "zk60_fable_joint_rank.py"))},
                    "included_observation_classes": INCLUDED_CLASSES, "excluded_observation_classes": EXCLUDED_CLASSES,
                    "directories": {"final": final_dir, "initial": initial_dir}, "captures": [], "cases": [], "refused": []}
    parity = load_parity(parity_path) if parity_path else None
    report["parity_record"] = parity
    codex = None
    if codex_path:
        with open(codex_path) as fh:
            codex = json.load(fh)
        report["codex_subset"] = {"path": codex_path, "sha256": sha256_file(codex_path), "tool_sha256_recorded": codex.get("tool_sha256"), "cases": len(codex.get("cases", []))}
    # hash every file in both directories first (streaming, no parse)
    files: Dict[str, dict] = {}
    for tag, d in (("initial", initial_dir), ("final", final_dir)):
        if not d:
            continue
        for name in sorted(os.listdir(d)):
            if not name.endswith(".json"):
                continue
            h = sha256_file(os.path.join(d, name))
            e = files.setdefault(name, {"file": name, "sha256_by_directory": {}, "paths": {}})
            e["sha256_by_directory"][tag] = h
            e["paths"][tag] = os.path.join(d, name)
    for name, e in files.items():
        stem = name[:-5]
        hs = set(e["sha256_by_directory"].values())
        e["identical_in_both_directories"] = (len(e["sha256_by_directory"]) == 2 and len(hs) == 1)
        e["in_parity_record"] = bool(parity and stem in parity["seeded"])
        e["parity_record_matches"] = bool(parity and stem in parity["seeded"] and hs == {parity["seeded"][stem]}) if e["in_parity_record"] else None
        e["in_codex_subset"] = bool(codex and any(c["proof_sha256"] == stem for c in codex["cases"]))
        if codex and e["in_codex_subset"]:
            want = {c["capture_sha256"] for c in codex["cases"] if c["proof_sha256"] == stem}
            e["codex_capture_sha256_matches"] = want == {e["sha256_by_directory"].get("initial", e["sha256_by_directory"].get("final"))}
    report["captures"] = list(files.values())
    if parity:
        report["parity_check"] = {"seeded_pairs": len(parity["seeded"]), "verified": sorted(n for n, e in files.items() if e["parity_record_matches"]),
                                  "mismatched": sorted(n for n, e in files.items() if e["in_parity_record"] and not e["parity_record_matches"]),
                                  "not_in_record": sorted(n for n, e in files.items() if not e["in_parity_record"])}
    # analyse one file at a time (both directories; identical files once)
    done_hashes = set()
    codex_matches = []
    for name, e in files.items():
        for tag in ("initial", "final"):
            path = e["paths"].get(tag)
            if not path:
                continue
            h = e["sha256_by_directory"][tag]
            if h in done_hashes:
                continue
            if only and not any(name.startswith(o) for o in only):
                continue
            expected = parity["seeded"].get(name[:-5]) if parity else None
            try:
                cap = Capture(path, expected_capture_sha256=expected)
            except CaptureError as err:
                report["refused"].append({"file": name, "directory": tag, "reason": str(err)})
                log(f"REFUSED {name} ({tag}): {err}")
                continue
            done_hashes.add(h)
            log(f"{name[:12]} [{tag}] {cap.privacy} T{cap.shape['t']} roles {[r.role for r in cap.roles]}")
            cases = analyze_capture(cap, planes=planes, plane_columns=plane_columns, log=log)
            for c in cases:
                c["directories"] = sorted(t for t, hh in e["sha256_by_directory"].items() if hh == h)
                if codex:
                    ref = [x for x in codex["cases"] if x["proof_sha256"] == cap.proof_sha256 and x["role"] == c["role"]]
                    if ref:
                        ref = ref[0]
                        mine = c["codex_subset_reproduction"]
                        ok = all(ref[k] == mine[k] for k in ("data_rows", "mask_rows", "base_observation_rows", "rank_mask", "rank_joint", "disclosed_base_functionals_per_column")) and ref["capture_sha256"] == h
                        ok = ok and c["analysis"]["per_column"]["rank_mask"] == ref["rank_mask"] and c["analysis"]["per_column"]["rank_joint"] == ref["rank_joint"]
                        c["codex_reference"] = {k: ref[k] for k in ("rank_mask", "rank_joint", "disclosed_base_functionals_per_column", "capture_sha256")}
                        c["codex_reproduced_exactly"] = ok
                        codex_matches.append(ok)
                report["cases"].append(c)
            del cap
    if codex:
        report["codex_subset"]["reproduced_exactly"] = sum(1 for x in codex_matches if x)
        report["codex_subset"]["compared"] = len(codex_matches)
    report["summary"] = summarize(report["cases"])
    report["recovered_row_agreement"] = recovered_row_agreement(report["cases"])
    report["limits"] = [
        "Numerical rank of linear observations under the captured (fixed) public coefficients; not a simulator and not an upper bound on disclosure.",
        "Pads, sampled columns, the CFS channel and repeated proofs are excluded (stated classes); FA6 and FA8 own those channels.",
        "Every capture holds no witness: the recovered vectors are digested, never compared to truth here; truth comparison lives only in the in-process Rust harness (zk_ffn_mask_diagnostic).",
        "Coverage ffn-v3-function-1 only (legacy profile); repaired-profile (ffn-v3-mr1) and function-2 captures need the handoff schema and are not analysed.",
        "No private-block, deployment or throughput acceptance follows from this analysis.",
    ]
    if out_path:
        with open(out_path, "w") as fh:
            json.dump(report, fh, indent=1)
        log(f"wrote {out_path}")
    return report


def recovered_row_agreement(cases: List[dict]) -> dict:
    """Digests of fully recovered rows, grouped by (shape, role, plane): independent
    proofs of the same fixture must agree (a witness-free consistency check of the
    recovery; different fixtures must not).  Repeated proofs are NOT combined here."""
    out: Dict[str, dict] = {}
    for c in cases:
        for s in c.get("singleton_reproductions", []):
            if "recovered_row_sha256" not in s:
                continue
            key = f"T{c['shape']['t']}/{c['role']}/{s['plane']}"
            e = out.setdefault(key, {"digests": {}, "proofs": 0})
            e["proofs"] += 1
            e["digests"].setdefault(s["recovered_row_sha256"], []).append({"proof_sha256": c["proof_sha256"], "privacy": c["privacy"]})
    for e in out.values():
        e["distinct_recovered_rows"] = len(e["digests"])
    return out


def summarize(cases: List[dict]) -> dict:
    table: Dict[str, dict] = {}
    for c in cases:
        key = f"{c['privacy']}/T{c['shape']['t']}/{c['role']}"
        a = c["analysis"]
        row = table.setdefault(key, {"cases": 0, "n": c["role_summary"]["n"], "per_column_disclosed": set(), "joint_disclosed": set(), "cross_column_increment": set(), "planes": {}})
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
        out[key] = {"cases": row["cases"], "n": row["n"], "per_column_disclosed": sorted(row["per_column_disclosed"]), "joint_disclosed": sorted(row["joint_disclosed"]),
                    "cross_column_increment": sorted(row["cross_column_increment"]),
                    "planes": {nm: {"rows": p["rows"], "projected": sorted(p["projected"]), "isolated": sorted(p["isolated"])} for nm, p in row["planes"].items()}}
    return out


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("analyze")
    a.add_argument("--final-dir", required=True)
    a.add_argument("--initial-dir")
    a.add_argument("--parity")
    a.add_argument("--codex")
    a.add_argument("-o", "--out")
    a.add_argument("--no-planes", action="store_true")
    a.add_argument("--plane-columns", default="0,-1", help="comma-separated columns for the per-column isolated measure (-1 = last)")
    a.add_argument("--only", help="comma-separated file-name prefixes")
    c = sub.add_parser("check")
    c.add_argument("capture")
    c.add_argument("--expected-sha256")
    args = ap.parse_args(argv)
    if args.cmd == "check":
        cap = Capture(args.capture, expected_capture_sha256=args.expected_sha256)
        print(json.dumps({"header": cap.header(), "roles": [r.summary() for r in cap.roles], "codex_per_column": {r.role: codex_per_column(r) for r in cap.roles}}, indent=1))
        return 0
    cols = [int(x) for x in args.plane_columns.split(",") if x != ""]
    run(args.final_dir, args.initial_dir, args.parity, args.codex, args.out, planes=not args.no_planes, plane_columns=cols, only=(args.only.split(",") if args.only else None))
    return 0


if __name__ == "__main__":
    sys.exit(main())
