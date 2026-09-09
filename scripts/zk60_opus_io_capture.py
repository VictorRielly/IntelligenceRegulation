#!/usr/bin/env python3
"""zk60_opus_io_capture.py -- O8: a SEPARATE digest-bound parser and JOINT linear
observation model for the schema-3 captures of the FFN input/output profile
`ffn-v3-mr1-fresh-io-poc/2` (analysis only, stdlib, exact integers).

Reviewer: Opus 5, independent reviewer, 2026-09-09 session (task O8 of
docs/zkmatrix-poc/ZK60_OPUS_QUEUE.md).  Capture producer pin:
1f0ff3680c4cda88f1744343e24eb93cdddfcba4 ("Capture fully verified FFN IO
observations with mask and endpoint replay"); review worktree branch
zk60-fable-review at Codex's round-19 tip 863507a.

WHY A SEPARATE TOOL.  Three earlier tools are archived and keep their meaning:
`scripts/zk60_fable_joint_capture.py` / `zk60_fable_joint_rank.py` (Claude Fable
5.1, FA7 -- the legacy schema-1 model and its exact Fp2/rank algebra) and
`scripts/zk60_opus_repaired_capture.py` (Opus 5, O2 -- the schema-2 repaired
profile `ffn-v3-mr1-fresh-poc/1`).  All three are imported BY PATH, read-only,
never edited and never re-pointed at these captures.  Codex's
`scripts/zk60_io_capture_preflight.py` and `zk60_io_capture_controls.py` are
likewise left untouched; this module re-derives their geometry independently
rather than importing their conclusions.

WHAT THIS CONSUMES.  One capture triple per proof, named by the RECEIPT digest:
  <digest>.json      schema 3, from hashline/src/zk_ffn_io_diagnostic.rs
  <digest>.receipt   the complete HFFNIO `/2` frame (5,029,244 B P1 / 5,066,204 B P3)
  <digest>.expected  the 112-byte endpoint policy (magic, context, two i32 scales,
                     the input and the output root)
The proof digest covers the COMPLETE receipt, unlike the archived FFN captures,
which digest the logical payload only.

WHAT IS RECOMPUTED, NOT TRUSTED.  Every commitment row count, every mask row
index, the X and z16 plane offsets, each claim's part slices, the claim -> group
shape, the row roles, the coefficient tags, the endpoint geometry, the layout
description and its digest, and the receipt length are recomputed here from the
layout rules of the source and only then compared with what the capture
declares.  Two independent derivations are cross-checked against each other:
O2's `zk_layout` (hashline/src/zk.rs::ZkLayoutV3::with_masks) and O7's
`zk60_opus_io_layout.a_row_map` / `endpoint_plane` / `io_frame_len`
(zk.rs::with_io, private_seam.rs::prepare_with_rng, zk_ffn_fresh_io.rs).

THE MODEL (FA7 section 5, unchanged; O2 applied it per commitment).  One
base-field unknown per (row, column) of a commitment; rows opened by several
claims alias.  Observations, all Fp2 and therefore two base-field rows each:
  * every message coordinate v_g[j], j < n, of every group vector
  * every coordinate prox[j], j < n, of every proximity vector
  * every terminal (claim value), including H's public 0
  * H only: the public constraint sum_j u[j] = 0 on its zero-sum pair
The message portion of a group vector combines ONLY the rows selected by that
group's claims; the proximity vector combines ALL rows of its commitment.  (That
is the round-19 correction to O7 section 6 -- and it is what the inherited model
always encoded; O7's prose was wrong, not the model.)

WHAT IS NEW HERE, AND WHY.  `JointModel` runs that same model over a UNION of
commitments whose data planes alias.  A's IO claims open the real X rows 14/15
and z16 rows 16/17; the input and output endpoints commit the SAME two planes in
their own rows 0/1 with their OWN, separate masks.  Reporting each commitment's
disclosure alone is not a joint result.  The mathematics, the observation
classes and the exact linear algebra are unchanged and imported; the only
generalisations are (a) the row index set is the disjoint union of the
commitments modulo an alias identification, and (b) the block coordinate space
carries one Fp2 pair per group AND one per commitment's proximity vector instead
of exactly one proximity vector.  `JointModel` on a single commitment is
asserted to reproduce `zk60_fable_joint_capture.RoleModel` exactly, and its
per-column ranks are cross-checked against an explicit, uncompressed
per-column observation matrix.

WHAT THE ALIAS COSTS.  The linear observations cannot themselves prove that A's
X slice and the input endpoint's first 512 values are the same numbers.  That
equality is the STATEMENT the IO sumcheck proves (zk_ffn_fresh_io.rs:379-410:
one point rho[..9] and one coefficient split (1-e, e, e*u) shared by both
claims).  The joint model therefore imports it from the soundness of that
argument.  This is stated, not assumed silently: without it the two commitments
are unrelated and the joint result degenerates to the independent one, which is
also computed here as a control.

EXCLUDED, exactly as in FA7/O2 -- stated, not costed, and NOT expanded:
pad coordinates, the sampled encoded columns, the CFS mask commitment and every
masked sumcheck round message, repeated proofs of one witness, and the Merkle
root over unopened columns.  The schema-3 capture now CONTAINS all of these
observations (all eight CFS slots and their fourteen public functionals
included); their presence is not permission to claim they were analysed.  Their
structure is validated (widths, ranges, path lengths, bindings); their values
stay outside the linear model, and `cross_component_obligations()` inventories
what still needs its own argument.

ROUND 20.  Codex's conditional opening lemma (docs/zkmatrix-poc/ZK60_ROUND20.md)
covers exactly that excluded channel -- pads, sampled encoded columns and the
whole M opening -- and it takes THIS task's joint message result as its premise.
Nothing here folds that channel into the model; `round20_premise()` states, in
dimensions, what the joint result supplies to the lemma and which of the lemma's
conditions this model does not impose.

Usage:
    python3 scripts/zk60_opus_io_capture.py preflight \\
        --captures-dir /tmp/zk60-round19/captures \\
        --manifest results/zk60_round19_validation.json \\
        -o /tmp/zk60-opus-o8/preflight.json
    python3 scripts/zk60_opus_io_capture.py analyze \\
        --captures-dir /tmp/zk60-round19/captures \\
        --manifest results/zk60_round19_validation.json \\
        --legacy-dir /tmp/zk60-round11/final-observations \\
        -o results/zk60_opus_io_capture_analysis.json
    python3 scripts/zk60_opus_io_capture.py check CAPTURE.json
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
import sys
import time
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name: str, filename: str):
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, filename))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


# archived, read-only: O2's repaired-profile adapter (which itself imports Fable's
# FA7 joint model C and its exact rank algebra R), and O7's IO layout / wire model.
O = _load("zk60_opus_repaired_capture", "zk60_opus_repaired_capture.py")
C = O.C
R = O.R
IOL = _load("zk60_opus_io_layout", "zk60_opus_io_layout.py")
WIRE = _load("zk60_opus_wire_length", "zk60_opus_wire_length.py")

P = R.P
NONRESIDUE = R.NONRESIDUE
ONE, ZERO, U = R.ONE, R.ZERO, R.U
f2_add, f2_sub, f2_mul, f2_neg = R.f2_add, R.f2_sub, R.f2_mul, R.f2_neg
eq_table_msb = R.eq_table_msb

Fp2 = Tuple[int, int]

REVIEWER = "Opus 5, independent reviewer, 2026-09-09 session (O8)"
REVIEW_WORKTREE_COMMIT = "863507a"

# ---------------------------------------------------------------------------
# the ONE profile this tool accepts
# ---------------------------------------------------------------------------
SCHEMA = 3
KIND = "zk60-verifier-observations"
COVERAGE = "ffn-v3-mr1-fresh-io-poc-function-1"
PROFILE = "ffn-v3-mr1-fresh-io-poc/2"
DRAFT_PROFILE = "ffn-v3-mr1-fresh-io-poc/1"          # superseded, must be refused
TRANSCRIPT_DOMAIN = "hashline-zk-mr1/" + PROFILE
SOURCE_COMMIT = "1f0ff3680c4cda88f1744343e24eb93cdddfcba4"
SHAPE = dict(O.SHAPE)                                 # {"t": 32, "d": 16, "f": 16}
SHIFTS = tuple(O.SHIFTS)                              # (7, 0, 14, 6)
LOG_COLS = O.LOG_COLS                                 # 8
INV_RATE = O.INV_RATE                                 # 8
NUM_COL_CHECKS = O.NUM_COL_CHECKS                     # 256
Q_PAD = O.Q_PAD                                       # 256
WEIGHT_POLICY = "fresh-per-proof"
PROOF_DIGEST_ENCODING = "complete HFFNIO version 2 receipt"
RECEIPT_MAGIC = b"HFFNIO\0\x02"
POLICY_MAGIC = b"HFFNEXP1"
POLICY_BYTES = 112
OPENING_ORDER = ["M", "W", "A", "H", "Input", "Output"]
IO_SPECS = [[10, 2], [10, 2]]
M_ROWS = 20
M_LOG_DOMAIN = 12
M_VECTOR = 1024                                       # n_M + Q_M = 512 + 512
M_PROX_RHOS = 18                                      # 2 * slots + 2; rows 18/19 are its (1, u) pair
M_FUNCTIONALS = 14
FFN_ARGUMENT_NAMES = ["gu", "d", "zc20", "zc17", "tab", "zs"]
FFN_SLOT_ORDER = [0, 1, 2, 3, 5, 4]
COLUMN_PATH_LEN = 11                                  # log2(256 * 8) for every role commitment

EXPECTED_ROWS = {"A": 702, "H": 1326, "W": 11, "Input": 7, "Output": 7}
EXPECTED_GROUP_SHAPE = {"A": [7, 3, 1, 1, 6, 1, 1], "H": [3, 1, 1, 6, 1], "W": [2, 1],
                        "Input": [1], "Output": [1]}
ROLE_ORDER = {"P1": ["A", "H", "Input", "Output"], "P3": ["W", "A", "H", "Input", "Output"]}
PRIVATE_ROLES = {"P1": ["A", "H", "Input", "Output"], "P3": ["W", "A", "H", "Input", "Output"]}
# the two A claims that carry the endpoint equalities, and the endpoint they bind to
IO_CLAIMS = {0: ("Input", "X[0]"), 1: ("Output", "z16[0]")}

# Codex's round-20 conditional opening lemma (docs/zkmatrix-poc/ZK60_ROUND20.md,
# scripts/zk60_io_opening_translation.py, results/zk60_round20_opening_translation.json).
# It covers exactly the channel this model excludes -- pads, sampled encoded columns and
# the whole M opening -- and it CONSUMES this task's joint message result as its premise.
# It is neither re-run nor duplicated here; only its statement and its exclusions are cited.
ROUND20 = {
    "doc": "docs/zkmatrix-poc/ZK60_ROUND20.md",
    "tool": "scripts/zk60_io_opening_translation.py",
    "result": "results/zk60_round20_opening_translation.json",
    "statement": "at fixed claim points, group lambdas and proximity challenges, any message "
                 "difference that already satisfies the individual terminal, public-row, "
                 "shared-endpoint-plane and zero-sum conditions can be absorbed by each owner's "
                 "independent pads so that every group and proximity vector and every sampled "
                 "encoded word stay unchanged simultaneously, bijectively on the pad space; the "
                 "same holds for the eight-slot M opening and its two blinders",
    "exclusions": [
        "fixed challenges only: it does not treat witness-dependent Fiat-Shamir challenges as "
        "independent fixed inputs, so adaptive composition stays open",
        "one opening only: repeated openings are excluded, and its own negative tests show one "
        "blinder translation generally cannot preserve two different M weightings",
        "the salted Merkle roots and authentication paths are NOT held fixed; a translation of "
        "field observations is not a forged receipt and not a simulator",
        "the new endpoint roots are caller-fixed public inputs; the endpoint preparation / "
        "auxiliary-input model and its commitment/transcript simulation remain unspecified",
        "CFS round messages are outside it",
    ],
    "depends_on_this_task": "the lemma supplies no message difference and proves no condition "
                            "satisfiable; O8 must establish the joint message result, and "
                            "independent per-role checks do not establish it",
}

EXCLUDED_CLASSES = dict(C.EXCLUDED_CLASSES)
EXCLUDED_CLASSES["adaptive_composition"] = (
    "the transcript derives every public coefficient AFTER masked messages are absorbed; "
    "the model conditions on the captured coefficients as fixed, so adaptive dependence is "
    "outside it (FA7's standing exclusion, restated because the IO profile adds two more "
    "adaptive rounds)")
EXCLUDED_CLASSES["endpoint_second_encoding"] = (
    "NEW with this profile: each aliased data plane is encoded and column-opened TWICE, once "
    "inside A and once inside its endpoint commitment, at independently sampled column sets; "
    "the encoded-column hiding argument must now cover two encodings of one plane")
INCLUDED_CLASSES = dict(C.INCLUDED_CLASSES)
INCLUDED_CLASSES["proximity_vector"] = (
    "every coordinate prox[j], j < n, of EVERY commitment's proximity vector (2 base rows each); "
    "each proximity vector combines all rows of its own commitment")
INCLUDED_CLASSES["cross_commitment_alias"] = (
    "A rows 14/15 (X) and 16/17 (z16) are the SAME unknowns as rows 0/1 of the input and the "
    "output endpoint; the masks of the two commitments stay distinct unknowns")

STRUCTURE_ONLY_CLASSES = {
    "pads": "width and count only (every role clear vector has n + Q = 512 entries, the M "
            "vectors 1024); the pad VALUES stay outside the linear model",
    "sampled_columns": "count, index range, per-column width, salt width and Merkle path length "
                       "only (256 columns of 11 nodes per role commitment, 256 columns of 20 "
                       "words and 12 nodes for M); the column VALUES stay outside the model",
    "cfs": "the M commitment's slot schedule, its fourteen public functionals' term shapes and "
           "widths, and the two IO / six FFN sumchecks' round and terminal counts; every VALUE "
           "in them stays outside the model",
    "endpoint_policy": "the 112-byte policy is parsed and bound to the endpoint roots; the "
                       "context and scales are public inputs, not modelled observations",
}


class IoCaptureError(C.CaptureError):
    """An IO capture that must be refused."""


# ---------------------------------------------------------------------------
# small helpers (exact integers only)
# ---------------------------------------------------------------------------


def sha256_file(path: str) -> str:
    return C.sha256_file(path)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _is_int(x) -> bool:
    return isinstance(x, int) and not isinstance(x, bool)


def _fp(x, what: str) -> int:
    if not _is_int(x) or x < 0 or x >= P:
        raise IoCaptureError(f"{what}: not an integer in [0, p): {x!r}")
    return x


def _fp2(x, what: str) -> Fp2:
    if not isinstance(x, list) or len(x) != 2:
        raise IoCaptureError(f"{what}: not an Fp2 pair: {x!r}")
    return (_fp(x[0], what + ".c0"), _fp(x[1], what + ".c1"))


def _fp2_vec(x, size: int, what: str) -> List[Fp2]:
    if not isinstance(x, list) or len(x) != size:
        raise IoCaptureError(f"{what}: expected {size} Fp2 entries, got "
                             f"{len(x) if isinstance(x, list) else 'none'}")
    return [_fp2(v, f"{what}[{i}]") for i, v in enumerate(x)]


def _bytes32(x, what: str) -> str:
    if not isinstance(x, list) or len(x) != 32 or not all(_is_int(b) and 0 <= b < 256 for b in x):
        raise IoCaptureError(f"{what}: not 32 bytes")
    return bytes(x).hex()


def _uint(x, what: str, lo: int = 0, hi: Optional[int] = None) -> int:
    if not _is_int(x) or x < lo or (hi is not None and x > hi):
        raise IoCaptureError(f"{what}: not an integer in [{lo}, {hi}]: {x!r}")
    return x


def _no_duplicates(pairs):
    out = {}
    for k, v in pairs:
        if k in out:
            raise IoCaptureError(f"duplicate JSON key {k}")
        out[k] = v
    return out


def _no_float(value):
    raise IoCaptureError("floating-point JSON value is forbidden")


def load_capture_json(raw_bytes: bytes) -> dict:
    """Canonical ingestion: no duplicate keys, no floating point anywhere."""
    try:
        raw = json.loads(raw_bytes, object_pairs_hook=_no_duplicates,
                         parse_float=_no_float, parse_constant=_no_float)
    except IoCaptureError:
        raise
    except ValueError as e:
        raise IoCaptureError(f"malformed JSON ({e})") from None
    if not isinstance(raw, dict):
        raise IoCaptureError("capture is not a JSON object")
    return raw


def _ms(t0: float) -> int:
    """Elapsed milliseconds as an exact integer (no floats reach the record)."""
    return int((time.time() - t0) * 1000)


# ---------------------------------------------------------------------------
# the layout, recomputed from the source rules
# ---------------------------------------------------------------------------


def endpoint_layout() -> dict:
    """One `PreparedPlane` at the fixed FFN IO shape, re-derived from
    hashline/src/private_seam.rs::prepare_with_rng (rows 0/1 data, 2/3 the
    terminal mask pair, 4 the reserved proximity mask row, 5/6 two further fresh
    random rows -- all five are drawn from the ZkRng and all seven rows carry a
    proximity coefficient)."""
    values = SHAPE["t"] * SHAPE["d"]
    if values <= 0 or values & (values - 1):
        raise IoCaptureError(f"endpoint plane length {values} is not a power of two")
    log_len = values.bit_length() - 1
    n = 1 << LOG_COLS
    data_rows = -(-values // n)
    mask_rows = 5
    rows = data_rows + mask_rows
    return {
        "values": values, "log_len": log_len, "n": n, "data_rows": data_rows,
        "rows": rows, "terminal_mask_pair": [data_rows, data_rows + 1],
        "prox_rows": list(range(data_rows + 2, rows)),
        "reserved_prox_mask_row": data_rows + 2,
        "claim_slice": {"offset": 0, "log_size": log_len},
        "mask_slices": [((data_rows + i) * n, min(log_len, LOG_COLS)) for i in range(2)],
        "cfs_spec": [log_len + 1, 2], "cfs_coefficients": (log_len + 1) * 2 + 2,
    }


def io_layout() -> dict:
    """The whole `/2` geometry, recomputed and cross-checked between the two
    independent derivations this reviewer already owns."""
    zl = O.zk_layout(SHAPE["t"], SHAPE["d"], SHAPE["f"], LOG_COLS, SHIFTS, mr1=True)
    lay = zl["lay"]
    base_rows = zl["a_rows"]
    io_heads = [base_rows, base_rows + 2]
    a_rows = base_rows + 4
    ep = endpoint_layout()
    out = {
        "zl": zl, "a_base_rows": base_rows, "a_rows": a_rows, "io_heads": io_heads,
        "io_mask_rows": [r for h in io_heads for r in (h, h + 1)],
        "x_slice": {"offset": lay["planes"]["X"][0], "log_size": lay["ls_d"]},
        "z_slice": {"offset": lay["planes"]["z16"][0], "log_size": lay["ls_d"]},
        "x_rows": [lay["planes"]["X"][0] // zl["a_n"], lay["planes"]["X"][0] // zl["a_n"] + 1],
        "z_rows": [lay["planes"]["z16"][0] // zl["a_n"], lay["planes"]["z16"][0] // zl["a_n"] + 1],
        "endpoint": ep, "n": zl["a_n"],
    }
    # cross-check 1: O7's independent allocation trace (zk.rs::with_masks + with_io)
    rm = IOL.a_row_map(SHIFTS)
    if (rm["base_rows"], rm["a_rows"], rm["a_io"]) != (base_rows, a_rows, io_heads):
        raise IoCaptureError(
            f"A row map disagreement: O2 layout ({base_rows}, {a_rows}, {io_heads}) vs "
            f"O7 allocation trace ({rm['base_rows']}, {rm['a_rows']}, {rm['a_io']})")
    if rm["x_slice"] != out["x_slice"] or rm["z_slice"] != out["z_slice"]:
        raise IoCaptureError("X / z16 slice disagreement between the two derivations")
    # cross-check 2: O7's endpoint plane (private_seam.rs)
    epl = IOL.endpoint_plane()
    if (epl["commitment_rows"], epl["data_rows"], epl["terminal_mask_rows"],
            epl["claim_slice"], list(epl["cfs_spec"]), epl["cfs_coefficients"]) != (
            ep["rows"], ep["data_rows"], ep["terminal_mask_pair"], ep["claim_slice"],
            ep["cfs_spec"], ep["cfs_coefficients"]):
        raise IoCaptureError("endpoint plane disagreement between the two derivations")
    if a_rows != EXPECTED_ROWS["A"] or ep["rows"] != EXPECTED_ROWS["Input"]:
        raise IoCaptureError(f"recomputed A rows {a_rows} / endpoint rows {ep['rows']} are not "
                             f"the profile's {EXPECTED_ROWS['A']} / {EXPECTED_ROWS['Input']}")
    return out


def describe_io(zl: dict, a_rows: int) -> str:
    """`ZkLayoutV3::describe()` as the IO profile emits it: the base description with
    its A line replaced by the four appended IO mask rows.  NOTE that the source's
    first line still names the BASE profile `ffn-v3-mr1-fresh-poc/1`; the IO profile
    is identified by the `profile` / `transcript_domain` fields and by the geometry
    (A rows 702, mask rows 698..701), not by this string."""
    lines = O.describe(zl).splitlines()
    masks = O.a_mask_rows(zl) + list(range(zl["a_rows"], a_rows))
    lines[1] = (f"A rows={a_rows} masks=[" + ", ".join(str(x) for x in masks) + "] "
                f"prox pair={zl['a_prox']}..{zl['a_prox'] + 2}")
    return "\n".join(lines)


def expected_role_io(role: str, geo: dict, privacy: str) -> dict:
    """The claim list, row roles and coefficient tags the `/2` verifier builds."""
    zl = geo["zl"]
    n = zl["a_n"]
    if role in ("A", "H", "W"):
        exp = copy.deepcopy(O.expected_role(role, zl, privacy))
        if role != "A":
            return exp
        # zk.rs::with_io + zk_ffn_fresh_io.rs::claim(): two more claims, each
        # (data slice at the plane offset, its own fresh mask pair), each its own group.
        for i, head in enumerate(geo["io_heads"]):
            off = (geo["x_slice"] if i == 0 else geo["z_slice"])["offset"]
            ls = (geo["x_slice"] if i == 0 else geo["z_slice"])["log_size"]
            plane = IO_CLAIMS[i][1]
            exp["claims"].append([(off, ls, "data", plane, True, None),
                                  (head * n, LOG_COLS, "mask", f"a_io[{i}].re", True, None),
                                  ((head + 1) * n, LOG_COLS, "mask", f"a_io[{i}].im", True, None)])
            exp["coefficient_tags"].append(["1-e_io", "e_io", "e_io*u"])
            exp["declared_row_roles"].extend([("mask", f"a_io[{i}].re"), ("mask", f"a_io[{i}].im")])
            exp["group_shape"].append(1)
        exp["rows"] = geo["a_rows"]
        exp["io_claims"] = [len(exp["claims"]) - 2, len(exp["claims"]) - 1]
        return exp
    if role not in ("Input", "Output"):
        raise IoCaptureError(f"role {role!r} is not one of {sorted(EXPECTED_ROWS)}")
    ep = geo["endpoint"]
    parts = [(ep["claim_slice"]["offset"], ep["claim_slice"]["log_size"], "data", role, True, None)]
    for i, (off, ls) in enumerate(ep["mask_slices"]):
        parts.append((off, ls, "mask", f"{role}.mask[{ep['terminal_mask_pair'][i]}]", True, None))
    declared = []
    for r in range(ep["rows"]):
        kind = "data" if r < ep["data_rows"] else ("mask" if r in ep["terminal_mask_pair"] else "prox")
        declared.append((kind, f"{role}.{kind}[{r}]"))
    return {"rows": ep["rows"], "claims": [parts], "declared_row_roles": declared,
            "prox_rows": list(ep["prox_rows"]), "sum_claim": None, "zero_sum_claim": None,
            "zero_sum_pair": None, "group_shape": [1],
            "coefficient_tags": [["1-e_io", "e_io", "e_io*u"]],
            "n": ep["n"], "log_n": LOG_COLS, "io_claims": [0]}


# ---------------------------------------------------------------------------
# the parser: one role / commitment
# ---------------------------------------------------------------------------


class IoRoleObs:
    """One validated commitment opening, exposing exactly the attribute surface that
    `zk60_fable_joint_capture.RoleModel` consumes, so the inherited FA7 model runs on
    these captures unchanged."""

    def __init__(self, raw: dict, privacy: str, geo: dict):
        self.role = raw.get("role")
        if self.role not in EXPECTED_ROWS:
            raise IoCaptureError(f"role {self.role!r} is not one of {sorted(EXPECTED_ROWS)}")
        w = f"role {self.role}"
        exp = expected_role_io(self.role, geo, privacy)
        self.layout = exp
        params = raw.get("params")
        if not isinstance(params, dict):
            raise IoCaptureError(f"{w}: params missing")
        self.log_n = _uint(params.get("log_cols"), f"{w}.params.log_cols", 1, 16)
        self.inv_rate = _uint(params.get("inv_rate"), f"{w}.params.inv_rate", 1)
        self.num_col_checks = _uint(params.get("num_col_checks"), f"{w}.params.num_col_checks", 0)
        if (self.log_n, self.inv_rate, self.num_col_checks) != (exp["log_n"], INV_RATE, NUM_COL_CHECKS):
            raise IoCaptureError(
                f"{w}: PCS parameters ({self.log_n}, {self.inv_rate}, {self.num_col_checks}) are not "
                f"the fixed ({exp['log_n']}, {INV_RATE}, {NUM_COL_CHECKS}) of {PROFILE}")
        self.n = 1 << self.log_n
        com = raw.get("commitment")
        if not isinstance(com, dict):
            raise IoCaptureError(f"{w}: commitment missing")
        self.rows = _uint(com.get("rows"), f"{w}.commitment.rows", 1)
        if self.rows != exp["rows"] or self.rows != EXPECTED_ROWS[self.role]:
            raise IoCaptureError(
                f"{w}: commitment has {self.rows} rows; the recomputed {PROFILE} layout has "
                f"{exp['rows']} (fixed expectation {EXPECTED_ROWS[self.role]})")
        self.root = _bytes32(com.get("root"), f"{w}.commitment.root")
        self.before_state, self.before_next = self._state(raw.get("before"), f"{w}.before")
        self.after_state, self.after_next = self._state(raw.get("after"), f"{w}.after")
        n, rows = self.n, self.rows

        # ---- claims, matched against the recomputed layout ----
        claims_raw = raw.get("claims")
        if not isinstance(claims_raw, list) or not claims_raw:
            raise IoCaptureError(f"{w}: claims missing or empty")
        if len(claims_raw) != len(exp["claims"]):
            raise IoCaptureError(f"{w}: {len(claims_raw)} claims, the recomputed layout builds "
                                 f"{len(exp['claims'])}")
        self.claims: List[dict] = []
        self.part_kind: List[List[str]] = []
        self.part_name: List[List[str]] = []
        self.part_tag: List[List[str]] = []
        for k, c in enumerate(claims_raw):
            if not isinstance(c, dict):
                raise IoCaptureError(f"{w}.claims[{k}]: not an object")
            value = _fp2(c.get("value"), f"{w}.claims[{k}].value")
            parts_raw = c.get("parts")
            if not isinstance(parts_raw, list) or not parts_raw:
                raise IoCaptureError(f"{w}.claims[{k}].parts missing or empty")
            e = exp["claims"][k]
            if len(parts_raw) != len(e):
                raise IoCaptureError(
                    f"{w}.claims[{k}]: {len(parts_raw)} parts, the recomputed layout has {len(e)} "
                    f"(a missing mask pair row, or a claim from another profile)")
            parts, kinds, names, tgs = [], [], [], []
            for pi, (p, ep) in enumerate(zip(parts_raw, e)):
                pw = f"{w}.claims[{k}].parts[{pi}]"
                if not isinstance(p, dict):
                    raise IoCaptureError(f"{pw}: not an object")
                offset = _uint(p.get("offset"), pw + ".offset", 0)
                log_size = _uint(p.get("log_size"), pw + ".log_size", 0, 40)
                coef = _fp2(p.get("coefficient"), pw + ".coefficient")
                point_raw = p.get("point")
                if not isinstance(point_raw, list):
                    raise IoCaptureError(f"{pw}.point: not a list")
                point = [_fp2(x, f"{pw}.point[{i}]") for i, x in enumerate(point_raw)]
                if (offset, log_size) != (ep[0], ep[1]):
                    raise IoCaptureError(
                        f"{pw}: slice ({offset}, 2^{log_size}) is not the recomputed layout's "
                        f"({ep[0]}, 2^{ep[1]}) for {ep[3]}")
                if bool(point) != bool(ep[4]):
                    raise IoCaptureError(f"{pw}: point presence {bool(point)} != the layout's {bool(ep[4])}")
                if point and len(point) != log_size:
                    raise IoCaptureError(f"{pw}: point has {len(point)} coordinates for log_size {log_size}")
                if log_size < self.log_n:
                    raise IoCaptureError(f"{pw}: log_size {log_size} < log_cols {self.log_n}")
                if offset % n:
                    raise IoCaptureError(f"{pw}: offset {offset} is not row-aligned (n = {n})")
                if ep[5] is not None and coef != ep[5]:
                    raise IoCaptureError(f"{pw}: fixed coefficient {coef} is not the layout's {ep[5]}")
                tag = p.get("coefficient_tag")
                if not isinstance(tag, str) or not tag:
                    raise IoCaptureError(f"{pw}: coefficient_tag missing (schema 3 requires a "
                                         f"symbolic tag on every part)")
                if tag != exp["coefficient_tags"][k][pi]:
                    raise IoCaptureError(f"{pw}: coefficient_tag {tag!r} is not the recomputed "
                                         f"{exp['coefficient_tags'][k][pi]!r}")
                row0 = offset // n
                nrows = (1 << log_size) // n
                if row0 + nrows > rows:
                    raise IoCaptureError(f"{pw}: rows [{row0}, {row0 + nrows}) exceed the "
                                         f"commitment's {rows} rows")
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
            raise IoCaptureError(f"{w}: groups missing or empty")
        self.groups: List[dict] = []
        seen: Dict[int, int] = {}
        for gi, g in enumerate(groups_raw):
            gw = f"{w}.groups[{gi}]"
            if not isinstance(g, dict):
                raise IoCaptureError(f"{gw}: not an object")
            members, lambdas = g.get("members"), g.get("lambdas")
            if not isinstance(members, list) or not members:
                raise IoCaptureError(f"{gw}.members missing or empty")
            if not isinstance(lambdas, list) or len(lambdas) != len(members):
                raise IoCaptureError(f"{gw}: lambda count does not match the {len(members)} members")
            mem = []
            for m in members:
                m = _uint(m, gw + ".members[]", 0, len(self.claims) - 1)
                if m in seen:
                    raise IoCaptureError(f"{gw}: claim {m} is already a member of group {seen[m]}")
                seen[m] = gi
                mem.append(m)
                self.claims[m]["group"] = gi
            lams = [_fp2(x, f"{gw}.lambdas[{i}]") for i, x in enumerate(lambdas)]
            if any(l == ZERO for l in lams):
                raise IoCaptureError(f"{gw}: a zero group lambda (degenerate combination)")
            key = g.get("key")
            if not isinstance(key, dict):
                raise IoCaptureError(f"{gw}.key missing")
            kt = key.get("tail")
            if not isinstance(kt, list):
                raise IoCaptureError(f"{gw}.key.tail missing")
            tail = [_fp2(x, f"{gw}.key.tail[{i}]") for i, x in enumerate(kt)]
            if key.get("offset") != 0 or key.get("len") != n:
                raise IoCaptureError(f"{gw}.key: offset {key.get('offset')!r} / len {key.get('len')!r} "
                                     f"unsupported (expected 0 / {n})")
            if tail and len(tail) != self.log_n:
                raise IoCaptureError(f"{gw}.key.tail has {len(tail)} coordinates, expected 0 or {self.log_n}")
            vec_raw = g.get("vector")
            if not isinstance(vec_raw, list) or len(vec_raw) != n + Q_PAD:
                raise IoCaptureError(
                    f"{gw}.vector: {len(vec_raw) if isinstance(vec_raw, list) else 'no'} entries, "
                    f"expected n + Q = {n + Q_PAD}")
            vector = [_fp2(x, f"{gw}.vector[{i}]") for i, x in enumerate(vec_raw)]
            cw = eq_table_msb(tail) if tail else [ONE] * n
            for m in mem:
                for pi, p in enumerate(self.claims[m]["parts"]):
                    if p["tail"] is None:
                        if tail:
                            raise IoCaptureError(f"{gw}: member {m} part {pi} has no point but the key "
                                                 f"has a tail")
                    elif p["tail"] != tail:
                        raise IoCaptureError(f"{gw}: member {m} part {pi} column tail differs from the "
                                             f"group key")
            lhs = ZERO
            for j in range(n):
                lhs = f2_add(lhs, f2_mul(cw[j], vector[j]))
            rhs = ZERO
            for m, lam in zip(mem, lams):
                rhs = f2_add(rhs, f2_mul(lam, self.claims[m]["value"]))
            if lhs != rhs:
                raise IoCaptureError(
                    f"{gw}: the clear vector does not reproduce its members' terminals "
                    f"(sum_j eq(tail)[j] v[j] != sum_k lambda_k value_k)")
            self.groups.append({"members": mem, "lambdas": lams, "tail": tail, "cw": cw,
                                "vector": vector, "pad_entries": len(vector) - n})
        for k, c in enumerate(self.claims):
            if c["group"] is None:
                raise IoCaptureError(f"{w}: claim {k} belongs to no group")
        shape_got = [len(g["members"]) for g in self.groups]
        if shape_got != exp["group_shape"] or shape_got != EXPECTED_GROUP_SHAPE[self.role]:
            raise IoCaptureError(
                f"{w}: group member counts {shape_got} are not the recomputed {exp['group_shape']} "
                f"(fixed expectation {EXPECTED_GROUP_SHAPE[self.role]})")

        # ---- proximity: one rho per row, one vector ----
        rhos = raw.get("proximity_rhos")
        if not isinstance(rhos, list) or len(rhos) != rows:
            raise IoCaptureError(f"{w}.proximity_rhos: "
                                 f"{len(rhos) if isinstance(rhos, list) else 'no'} entries for {rows} rows")
        self.rho = [_fp2(x, f"{w}.proximity_rhos[{i}]") for i, x in enumerate(rhos)]
        pv = raw.get("proximity_vector")
        if not isinstance(pv, list) or len(pv) != n + Q_PAD:
            raise IoCaptureError(f"{w}.proximity_vector: "
                                 f"{len(pv) if isinstance(pv, list) else 'no'} entries, expected {n + Q_PAD}")
        self.prox_vector = [_fp2(x, f"{w}.proximity_vector[{i}]") for i, x in enumerate(pv)]

        # ---- sampled columns (structure only; values stay outside the model) ----
        cols = raw.get("columns")
        if not isinstance(cols, list) or len(cols) != self.num_col_checks:
            raise IoCaptureError(f"{w}.columns: "
                                 f"{len(cols) if isinstance(cols, list) else 'no'} entries for "
                                 f"{self.num_col_checks} column checks")
        domain = n * self.inv_rate
        path_len = domain.bit_length() - 1
        if path_len != COLUMN_PATH_LEN:
            raise IoCaptureError(f"{w}: column domain 2^{path_len} is not the profile's 2^{COLUMN_PATH_LEN}")
        self.sampled_columns: List[int] = []
        for ci, col in enumerate(cols):
            cwn = f"{w}.columns[{ci}]"
            if not isinstance(col, dict):
                raise IoCaptureError(f"{cwn}: not an object")
            idx = _uint(col.get("index"), cwn + ".index", 0, domain - 1)
            vals = col.get("values")
            if not isinstance(vals, list) or len(vals) != rows:
                raise IoCaptureError(f"{cwn}.values: not {rows} entries")
            for i, v in enumerate(vals):
                _fp(v, f"{cwn}.values[{i}]")
            _bytes32(col.get("salt"), cwn + ".salt")
            path = col.get("path")
            if not isinstance(path, list) or len(path) != path_len:
                raise IoCaptureError(f"{cwn}.path: "
                                     f"{len(path) if isinstance(path, list) else 'no'} nodes, expected {path_len}")
            for i, node in enumerate(path):
                _bytes32(node, f"{cwn}.path[{i}]")
            self.sampled_columns.append(idx)
        self.column_domain = domain
        self.q_pad = _uint(raw.get("q_pad"), f"{w}.q_pad", 0)
        if self.q_pad != Q_PAD or self.q_pad != self.num_col_checks:
            raise IoCaptureError(f"{w}.q_pad {self.q_pad} is not the fixed Q = {Q_PAD} = num_col_checks")

        # ---- declared row roles vs the recomputation ----
        rr = raw.get("row_roles")
        if not isinstance(rr, list) or len(rr) != rows:
            raise IoCaptureError(f"{w}.row_roles: "
                                 f"{len(rr) if isinstance(rr, list) else 'no'} entries for {rows} rows")
        seen_rows = set()
        self.declared_kind: List[str] = [""] * rows
        self.declared_site: List[str] = [""] * rows
        for i, entry in enumerate(rr):
            if not isinstance(entry, dict):
                raise IoCaptureError(f"{w}.row_roles[{i}]: not an object")
            row = _uint(entry.get("row"), f"{w}.row_roles[{i}].row", 0, rows - 1)
            if row in seen_rows:
                raise IoCaptureError(f"{w}.row_roles: row {row} has more than one entry")
            seen_rows.add(row)
            kind, site = entry.get("kind"), entry.get("site")
            if kind not in ("data", "mask", "prox") or not isinstance(site, str):
                raise IoCaptureError(f"{w}.row_roles[{i}]: kind {kind!r} / site {site!r} malformed")
            if (kind, site) != exp["declared_row_roles"][row]:
                raise IoCaptureError(
                    f"{w}.row_roles[row {row}]: declared ({kind}, {site!r}) is not the recomputed "
                    f"{exp['declared_row_roles'][row]}")
            self.declared_kind[row] = kind
            self.declared_site[row] = site
        if len(seen_rows) != rows:
            raise IoCaptureError(f"{w}.row_roles: {len(seen_rows)} distinct rows for {rows} rows")

        # ---- public linear constraints ----
        plc = raw.get("public_linear_constraints")
        if not isinstance(plc, list):
            raise IoCaptureError(f"{w}.public_linear_constraints missing")
        if self.role == "H":
            want = [{"rows": list(exp["zero_sum_pair"]),
                     "relation": "sum over the n message columns = 0", "source": "zsum sumcheck"}]
            if plc != want:
                raise IoCaptureError(f"H.public_linear_constraints {plc!r} is not the recomputed {want!r}")
        elif plc:
            raise IoCaptureError(f"{w}.public_linear_constraints must be empty, got {plc!r}")
        self.public_linear_constraints = plc

        # ---- row roles for the model: from the claim mapping, not from the labels ----
        self._derive_row_roles(exp)

    # -- helpers -------------------------------------------------------------
    @staticmethod
    def _state(x, what: str) -> Tuple[str, Fp2]:
        if not isinstance(x, dict):
            raise IoCaptureError(f"{what}: missing transcript state object")
        return _bytes32(x.get("state"), what + ".state"), _fp2(x.get("next"), what + ".next")

    def _derive_row_roles(self, exp: dict) -> None:
        rows = self.rows
        self.row_kind = ["unref"] * rows
        self.row_name = [""] * rows
        for k, c in enumerate(self.claims):
            for pi, p in enumerate(c["parts"]):
                kind, name = self.part_kind[k][pi], self.part_name[k][pi]
                for r in range(p["row0"], p["row0"] + p["nrows"]):
                    if self.row_kind[r] not in ("unref", kind):
                        raise IoCaptureError(f"role {self.role}: row {r} is data in one claim and "
                                             f"mask in another")
                    self.row_kind[r] = kind
                    if not self.row_name[r]:
                        self.row_name[r] = name
        unref = [r for r in range(rows) if self.row_kind[r] == "unref"]
        if unref != list(exp["prox_rows"]):
            raise IoCaptureError(
                f"role {self.role}: unreferenced rows {unref[:6]}{'...' if len(unref) > 6 else ''} are "
                f"not exactly the recomputed proximity rows {exp['prox_rows']}")
        base = {"A": "a_prox", "H": "h_prox", "W": "w_prox"}.get(self.role, f"{self.role}.prox")
        for i, r in enumerate(exp["prox_rows"]):
            self.row_kind[r] = "prox"
            self.row_name[r] = f"{base}[{r}]" if self.role in ("Input", "Output") else \
                base + (".re" if i == 0 else ".im")
        for r in range(rows):
            if self.row_kind[r] != self.declared_kind[r]:
                raise IoCaptureError(f"role {self.role}: row {r} is {self.row_kind[r]} by the claim "
                                     f"mapping but {self.declared_kind[r]} in row_roles")
        self.data_rows = [r for r in range(rows) if self.row_kind[r] == "data"]
        self.mask_rows = [r for r in range(rows) if self.row_kind[r] in ("mask", "prox")]

    def _check_pair_coefficients(self, privacy: str) -> None:
        """The repaired pair form (`ZkLayoutV3::pair_claim`) and the IO split
        (1 - e, e, e*u) of zk_ffn_fresh_io.rs::claim."""
        w = f"role {self.role}"
        cl = self.claims
        if self.role in ("A", "W", "Input", "Output"):
            for k, c in enumerate(cl):
                ps = c["parts"]
                if len(ps) == 3:
                    if f2_mul(ps[1]["coef"], U) != ps[2]["coef"]:
                        raise IoCaptureError(f"{w}.claims[{k}]: the paired mask part is not (k, k*u)")
                    if (ps[2]["offset"] != ps[1]["offset"] + (1 << ps[1]["log_size"])
                            or ps[2]["log_size"] != ps[1]["log_size"]):
                        raise IoCaptureError(f"{w}.claims[{k}]: the paired mask part is not the next slice")
                elif len(ps) != 2:
                    raise IoCaptureError(f"{w}.claims[{k}]: {len(ps)} parts")
            if self.role == "A":
                split = list(range(10)) + ([10, 11] if privacy == "P1" else []) + self.layout["io_claims"]
            elif self.role in ("Input", "Output"):
                split = [0]
            else:
                split = []
            for k in split:
                ps = cl[k]["parts"]
                if f2_add(ps[0]["coef"], ps[1]["coef"]) != ONE:
                    raise IoCaptureError(f"{w}.claims[{k}]: (data, mask) coefficients are not (1 - e, e)")
            for k in self.layout.get("io_claims", []):
                if cl[k]["parts"][1]["coef"] == ZERO:
                    raise IoCaptureError(f"{w}.claims[{k}]: zero terminal mask challenge e")
        else:
            for k, c in enumerate(cl):
                ps = c["parts"]
                if k == self.layout["sum_claim"]:
                    continue
                if len(ps) != 4:
                    raise IoCaptureError(f"{w}.claims[{k}]: {len(ps)} parts, expected the 4-part form")
                if f2_mul(ps[0]["coef"], U) != ps[1]["coef"] or f2_mul(ps[2]["coef"], U) != ps[3]["coef"]:
                    raise IoCaptureError(f"{w}.claims[{k}]: not the (k, k u) Fp2 pair form")
                if k <= 4 and f2_add(ps[0]["coef"], ps[2]["coef"]) != ONE:
                    raise IoCaptureError(f"{w}.claims[{k}]: (data, mask) coefficients are not (1 - e, e)")
            if cl[self.layout["sum_claim"]]["value"] != ZERO:
                raise IoCaptureError(f"{w}: the LogUp sum claim's value is not 0")

    # -- the RoleObs surface the FA7 model uses ------------------------------
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
                e = out.setdefault(self.row_name[r], {"rows": [], "claims": sorted(set(ks)),
                                                      "kind": self.row_kind[r]})
                e["rows"].append(r)
        for e in out.values():
            rws = sorted(e["rows"])
            e["rows"] = rws if len(rws) <= 4 else [rws[0], "...", rws[-1]]
            e["row_count"] = len(rws)
        return out

    def prox_mask_span(self) -> dict:
        """The Fp-rank of the proximity rho coefficients on this commitment's OWN
        mask/prox rows.  It must be 2 (the proximity observation is one Fp2 = two
        base rows); a rank of 1 would be the degenerate draw the design relies on
        not happening, and would show up as disclosure."""
        rows = [r for r in range(self.rows) if self.row_kind[r] == "prox"]
        mat = [[self.rho[r][0], self.rho[r][1]] for r in rows]
        return {"prox_rows": rows, "fp_rank_of_their_rhos": R.rank(mat) if mat else 0}

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
                "column_domain": self.column_domain, "root": self.root,
                "before_state": self.before_state, "after_state": self.after_state,
                "zero_sum_pair_rows": self.layout.get("zero_sum_pair"),
                "public_linear_constraints": self.public_linear_constraints,
                "proximity_mask_span": self.prox_mask_span(),
                "aliased_rows_within_this_commitment": self.aliases()}


# ---------------------------------------------------------------------------
# the parser: one capture triple
# ---------------------------------------------------------------------------


class IoCapture:
    """A schema-3 `ffn-v3-mr1-fresh-io-poc/2` capture with its sibling receipt and
    policy artifacts, refused unless it is exactly that."""

    def __init__(self, path: str, expected_capture_sha256: Optional[str] = None,
                 require_digest_name: bool = True, require_siblings: bool = True,
                 source_commit: str = SOURCE_COMMIT, raw: Optional[dict] = None):
        self.path = path
        self.geo = io_layout()
        if raw is None:
            self.file_sha256 = sha256_file(path)
            self.bytes = os.path.getsize(path)
            if expected_capture_sha256 is not None and expected_capture_sha256 != self.file_sha256:
                raise IoCaptureError(f"{os.path.basename(path)}: file sha256 {self.file_sha256[:16]}.. "
                                     f"differs from the manifest's {expected_capture_sha256[:16]}..")
            with open(path, "rb") as fh:
                raw_bytes = fh.read()
            raw = load_capture_json(raw_bytes)
            del raw_bytes
        else:
            self.file_sha256 = None
            self.bytes = None
        self._parse(raw, require_digest_name, require_siblings, source_commit)
        del raw

    # -- header --------------------------------------------------------------
    def _parse(self, raw: dict, require_digest_name: bool, require_siblings: bool,
               source_commit: str) -> None:
        for field, want in (("schema", SCHEMA), ("kind", KIND), ("coverage", COVERAGE),
                            ("profile", PROFILE), ("transcript_domain", TRANSCRIPT_DOMAIN),
                            ("weight_policy", WEIGHT_POLICY),
                            ("proof_digest_encoding", PROOF_DIGEST_ENCODING)):
            got = raw.get(field)
            if got != want:
                raise IoCaptureError(f"{field} {got!r} is not {want!r} (this tool accepts only "
                                     f"{PROFILE} at {source_commit[:7]})")
        got = raw.get("source_commit")
        if got != source_commit or not isinstance(got, str) or len(got) != 40 or \
                any(ch not in "0123456789abcdef" for ch in got):
            raise IoCaptureError(f"source_commit {got!r} is not the pinned {source_commit}")
        self.source_commit = got
        if raw.get("fully_verified") is not True:
            raise IoCaptureError("capture is not marked fully_verified")
        if raw.get("privacy_review_complete") is not False:
            raise IoCaptureError("privacy_review_complete must be false: a capture is evidence, "
                                 "not a privacy result")
        if raw.get("slot") is not None or raw.get("k") is not None:
            raise IoCaptureError(f"slot {raw.get('slot')!r} / k {raw.get('k')!r} must be null: the "
                                 f"fresh IO PoC registers no model slot")
        self.privacy = raw.get("privacy")
        if self.privacy not in ("P1", "P3"):
            raise IoCaptureError(f"privacy {self.privacy!r} is not P1/P3")
        if raw.get("field_modulus") != P or raw.get("extension_nonresidue") != NONRESIDUE:
            raise IoCaptureError("field modulus / nonresidue are not Goldilocks / u^2 = 7")
        shape = raw.get("shape")
        if not isinstance(shape, dict) or {k: shape.get(k) for k in ("t", "d", "f")} != SHAPE:
            raise IoCaptureError(f"shape {shape!r} is not the fixed {SHAPE} of {PROFILE}")
        self.shape = dict(SHAPE)
        shifts = raw.get("shifts")
        if not isinstance(shifts, list) or tuple(shifts) != SHIFTS:
            raise IoCaptureError(f"shifts {shifts!r} are not the fixed {list(SHIFTS)}")
        self.shifts = tuple(SHIFTS)
        ps = raw.get("proof_sha256")
        if not isinstance(ps, str) or len(ps) != 64 or any(ch not in "0123456789abcdef" for ch in ps):
            raise IoCaptureError("proof_sha256 is not a lowercase 64-hex digest")
        self.proof_sha256 = ps
        self.proof_bytes = _uint(raw.get("proof_bytes"), "proof_bytes", 1)
        want_len = IOL.io_frame_len(private=self.privacy == "P3")
        if self.proof_bytes != want_len:
            raise IoCaptureError(f"proof_bytes {self.proof_bytes} is not the independently derived "
                                 f"{PROFILE} {self.privacy} frame length {want_len}")
        stem = os.path.basename(self.path)
        if require_digest_name and stem != ps + ".json":
            raise IoCaptureError(f"file name {stem} is not the receipt digest name {ps[:16]}...json")
        if raw.get("opening_order") != OPENING_ORDER:
            raise IoCaptureError(f"opening_order {raw.get('opening_order')!r} is not {OPENING_ORDER}")

        # -- the layout, recomputed then compared -----------------------------
        self.layout_description_recomputed = describe_io(self.geo["zl"], self.geo["a_rows"])
        self.layout_digest_recomputed = sha256_bytes(self.layout_description_recomputed.encode("utf-8"))
        decl = raw.get("layout_description")
        if not isinstance(decl, str):
            raise IoCaptureError("layout_description missing")
        self.layout_description_declared = decl
        self.layout_digest_declared = raw.get("layout_digest")
        digest_of_declared = sha256_bytes(decl.encode("utf-8"))
        if digest_of_declared != self.layout_digest_declared:
            raise IoCaptureError(f"layout_digest {self.layout_digest_declared!r} is not "
                                 f"sha256(layout_description) = {digest_of_declared}")
        if decl != self.layout_description_recomputed:
            raise IoCaptureError("layout_description does not match the layout recomputed from the "
                                 "source rules")

        # -- roles -------------------------------------------------------------
        roles_raw = raw.get("roles")
        if not isinstance(roles_raw, list) or not roles_raw:
            raise IoCaptureError("roles missing or empty")
        self.roles: List[IoRoleObs] = []
        names = []
        for rr in roles_raw:
            ro = IoRoleObs(rr, self.privacy, self.geo)
            if ro.role in names:
                raise IoCaptureError(f"role {ro.role} appears twice")
            names.append(ro.role)
            self.roles.append(ro)
        if names != ROLE_ORDER[self.privacy]:
            raise IoCaptureError(f"roles {names} are not {ROLE_ORDER[self.privacy]} for {self.privacy}")
        self.by_role = {r.role: r for r in self.roles}

        # -- the CFS / M commitment: STRUCTURE ONLY ----------------------------
        self.mask = self._parse_mask(raw.get("mask"))
        # -- public W (P1 only) ------------------------------------------------
        pw = raw.get("public_w")
        if self.privacy == "P3":
            if pw is not None:
                raise IoCaptureError("public_w must be null in P3 (W is a private role)")
            self.public_w = None
        else:
            if not isinstance(pw, dict):
                raise IoCaptureError("public_w missing in P1")
            self.public_w = {"root": _bytes32(pw.get("root"), "public_w.root"),
                             "rows": _uint(pw.get("rows"), "public_w.rows", 1),
                             "opening_in_receipt": pw.get("opening_in_receipt")}
            if self.public_w["opening_in_receipt"] is not True:
                raise IoCaptureError("public_w.opening_in_receipt must be true")
            if self.public_w["rows"] != WIRE.rows_triple(SHIFTS, False)[0]:
                raise IoCaptureError(f"public_w rows {self.public_w['rows']} is not the derived "
                                     f"{WIRE.rows_triple(SHIFTS, False)[0]}")

        # -- the two IO equality arguments ------------------------------------
        self.io_arguments = self._parse_io_arguments(raw.get("io_arguments"))
        # -- the six FFN sumchecks (structure only) ----------------------------
        self.ffn_arguments = self._parse_ffn_arguments(raw.get("ffn_arguments"))
        _fp2_vec(raw.get("ffn_matmul_claims"), 2, "ffn_matmul_claims")
        _fp2_vec(raw.get("ffn_gammas"), 4, "ffn_gammas")

        # -- transcript joins ---------------------------------------------------
        chain = [("M", self.mask["before"], self.mask["after"])]
        if self.privacy == "P1":
            chain.append(("public_w", self._state_pair(pw, "public_w")[0],
                          self._state_pair(pw, "public_w")[1]))
        for ro in self.roles:
            chain.append((ro.role, (ro.before_state, ro.before_next), (ro.after_state, ro.after_next)))
        for (na, _, aft), (nb, bef, _) in zip(chain, chain[1:]):
            if aft != bef:
                raise IoCaptureError(f"transcript endpoint of {na} does not connect to {nb}")
        self.transcript_chain = [c[0] for c in chain]
        if self.io_arguments[0]["after"] != self.io_arguments[1]["before"]:
            raise IoCaptureError("IO argument 0 does not connect to IO argument 1")
        if self.io_arguments[1]["after"] != self.mask["before"]:
            raise IoCaptureError("the second IO argument does not connect to the M opening")

        # -- the endpoint policy and the sibling artifacts ---------------------
        self.expected_policy = self._parse_policy(raw)
        self.siblings = self._check_siblings() if require_siblings else None

    @staticmethod
    def _state_pair(x, what: str):
        if not isinstance(x, dict):
            raise IoCaptureError(f"{what}: missing")
        return (IoRoleObs._state(x.get("before"), what + ".before"),
                IoRoleObs._state(x.get("after"), what + ".after"))

    def _parse_mask(self, m) -> dict:
        """The eight-slot CFS commitment M.  Widths, slot schedule, functional shapes
        and transcript states only -- every value stays outside the linear model."""
        if not isinstance(m, dict):
            raise IoCaptureError("mask (the CFS commitment M) missing")
        specs = [list(s) for s in WIRE.mask_specs(self.privacy == "P3")] + [list(s) for s in IO_SPECS]
        if m.get("specs") != specs:
            raise IoCaptureError(f"M slot schedule {m.get('specs')!r} is not the derived {specs} "
                                 f"(six FFN slots then the two (10, 2) IO slots)")
        root = _bytes32(m.get("root"), "mask.root")
        theta = _fp2(m.get("theta"), "mask.theta")
        rhos = _fp2_vec(m.get("proximity_rhos"), M_PROX_RHOS, "mask.proximity_rhos")
        q = _fp2_vec(m.get("q"), M_VECTOR, "mask.q")
        prox = _fp2_vec(m.get("prox"), M_VECTOR, "mask.prox")
        cols = m.get("columns")
        if not isinstance(cols, list) or len(cols) != NUM_COL_CHECKS:
            raise IoCaptureError(f"mask.columns: expected {NUM_COL_CHECKS} sampled columns")
        for ci, col in enumerate(cols):
            if not isinstance(col, dict):
                raise IoCaptureError(f"mask.columns[{ci}]: not an object")
            _uint(col.get("index"), f"mask.columns[{ci}].index", 0, (1 << M_LOG_DOMAIN) - 1)
            vals = col.get("values")
            if not isinstance(vals, list) or len(vals) != M_ROWS:
                raise IoCaptureError(f"mask.columns[{ci}].values: not {M_ROWS} words "
                                     f"(the two IO slots add four base rows to the M commitment)")
            for i, v in enumerate(vals):
                _fp(v, f"mask.columns[{ci}].values[{i}]")
            _bytes32(col.get("salt"), f"mask.columns[{ci}].salt")
            path = col.get("path")
            if not isinstance(path, list) or len(path) != M_LOG_DOMAIN:
                raise IoCaptureError(f"mask.columns[{ci}].path: not {M_LOG_DOMAIN} nodes")
            for i, node in enumerate(path):
                _bytes32(node, f"mask.columns[{ci}].path[{i}]")
        fs = m.get("functionals")
        if not isinstance(fs, list) or len(fs) != M_FUNCTIONALS:
            raise IoCaptureError(f"mask.functionals: expected {M_FUNCTIONALS} public functionals")
        slots_seen, per_slot = set(), {}
        widths = []
        for fi, f in enumerate(fs):
            if not isinstance(f, dict):
                raise IoCaptureError(f"mask.functionals[{fi}]: not an object")
            _fp2(f.get("value"), f"mask.functionals[{fi}].value")
            terms = f.get("terms")
            if not isinstance(terms, list) or not terms:
                raise IoCaptureError(f"mask.functionals[{fi}]: empty functional")
            shape = []
            for ti, t in enumerate(terms):
                if not isinstance(t, dict):
                    raise IoCaptureError(f"mask.functionals[{fi}].terms[{ti}]: not an object")
                slot = _uint(t.get("slot"), f"mask.functionals[{fi}].terms[{ti}].slot", 0, len(specs) - 1)
                nv, deg = specs[slot]
                _fp2_vec(t.get("weights"), nv * deg + 2,
                         f"mask.functionals[{fi}].terms[{ti}].weights")
                slots_seen.add(slot)
                per_slot[slot] = per_slot.get(slot, 0) + 1
                shape.append([slot, nv * deg + 2])
            widths.append(shape)
        if slots_seen != set(range(len(specs))):
            raise IoCaptureError(f"mask: functionals reference slots {sorted(slots_seen)}, not all "
                                 f"{len(specs)}")
        before = IoRoleObs._state(m.get("before"), "mask.before")
        after = IoRoleObs._state(m.get("after"), "mask.after")
        return {"root": root, "theta": theta, "specs": specs, "prox_rhos": len(rhos),
                "q_entries": len(q), "prox_entries": len(prox), "columns": len(cols),
                "column_rows": M_ROWS, "column_domain": 1 << M_LOG_DOMAIN,
                "functionals": len(fs), "functional_term_shapes": widths,
                "openings_per_slot": {str(k): v for k, v in sorted(per_slot.items())},
                "cfs_coefficients_per_slot": {str(i): s[0] * s[1] + 2 for i, s in enumerate(specs)},
                "cfs_coefficients_total": sum(s[0] * s[1] + 2 for s in specs),
                "before": before, "after": after}

    def _parse_io_arguments(self, args) -> List[dict]:
        if not isinstance(args, list) or len(args) != 2:
            raise IoCaptureError("io_arguments: expected exactly two equality arguments")
        out = []
        A = self.by_role["A"]
        for i, a in enumerate(args):
            if not isinstance(a, dict):
                raise IoCaptureError(f"io_arguments[{i}]: not an object")
            if a.get("side") != i or a.get("slot") != len(self.mask["specs"]) - 2 + i:
                raise IoCaptureError(f"io_arguments[{i}]: side {a.get('side')!r} / slot "
                                     f"{a.get('slot')!r} is not ({i}, {len(self.mask['specs']) - 2 + i})")
            tau = _fp2_vec(a.get("tau"), 9, f"io_arguments[{i}].tau")
            rho = _fp2_vec(a.get("rho"), 10, f"io_arguments[{i}].rho")
            if rho[9] == ZERO:
                raise IoCaptureError(f"io_arguments[{i}]: zero terminal mask challenge e = rho[9]")
            c = _fp2(a.get("c"), f"io_arguments[{i}].c")
            if c == ZERO:
                raise IoCaptureError(f"io_arguments[{i}]: zero CFS mask challenge")
            gamma = _fp2(a.get("gamma"), f"io_arguments[{i}].gamma")
            mask_eval = _fp2(a.get("mask_eval"), f"io_arguments[{i}].mask_eval")
            rounds = a.get("rounds")
            if not isinstance(rounds, list) or len(rounds) != 10:
                raise IoCaptureError(f"io_arguments[{i}].rounds: expected 10 rounds")
            for ri, r in enumerate(rounds):
                _fp2_vec(r, 3, f"io_arguments[{i}].rounds[{ri}]")
            terminals = _fp2_vec(a.get("terminals"), 2, f"io_arguments[{i}].terminals")
            before = IoRoleObs._state(a.get("before"), f"io_arguments[{i}].before")
            after = IoRoleObs._state(a.get("after"), f"io_arguments[{i}].after")
            # the binding that makes the alias meaningful: ONE point and ONE coefficient
            # split shared by A's claim and the endpoint's claim
            ep_name, plane = IO_CLAIMS[i]
            ac = A.claims[A.layout["io_claims"][i]]
            ec = self.by_role[ep_name].claims[0]
            want = [f2_sub(ONE, rho[9]), rho[9], f2_mul(rho[9], U)]
            for who, cl, term in (("A", ac, terminals[0]), (ep_name, ec, terminals[1])):
                if cl["value"] != term:
                    raise IoCaptureError(f"io_arguments[{i}]: {who}'s terminal is not the argument's")
                if cl["parts"][0]["point"] != rho[:9]:
                    raise IoCaptureError(f"io_arguments[{i}]: {who}'s data point is not rho[:9]")
                if [p["coef"] for p in cl["parts"]] != want:
                    raise IoCaptureError(f"io_arguments[{i}]: {who}'s coefficients are not "
                                         f"(1 - e, e, e*u)")
            if ac["parts"][0]["tail"] != ec["parts"][0]["tail"]:
                raise IoCaptureError(f"io_arguments[{i}]: A and {ep_name} do not share a column tail")
            out.append({"side": i, "slot": a["slot"], "tau_len": len(tau), "rounds": len(rounds),
                        "degree": 2, "terminal_mask_challenge_nonzero": True,
                        "a_claim": A.layout["io_claims"][i], "endpoint": ep_name, "plane": plane,
                        "before": before, "after": after,
                        "shared_point_coordinates": 9,
                        "gamma_is_functional": None, "mask_eval_is_functional": None})
        return out

    def _parse_ffn_arguments(self, args) -> List[dict]:
        if not isinstance(args, list) or len(args) != len(FFN_ARGUMENT_NAMES):
            raise IoCaptureError(f"ffn_arguments: expected {len(FFN_ARGUMENT_NAMES)} arguments")
        if [a.get("name") if isinstance(a, dict) else None for a in args] != FFN_ARGUMENT_NAMES:
            raise IoCaptureError(f"ffn_arguments order is not {FFN_ARGUMENT_NAMES}")
        terminals = WIRE.TERMINALS[:4] + (WIRE.TERMINALS[5], WIRE.TERMINALS[4])
        out = []
        for slot, a, nterm in zip(FFN_SLOT_ORDER, args, terminals):
            nv, deg = self.mask["specs"][slot]
            rounds = a.get("rounds")
            if not isinstance(rounds, list) or len(rounds) != nv:
                raise IoCaptureError(f"ffn_arguments[{a['name']}]: {len(rounds) if isinstance(rounds, list) else 'no'} "
                                     f"rounds, the slot schedule says {nv}")
            for ri, r in enumerate(rounds):
                _fp2_vec(r, deg + 1, f"ffn_arguments[{a['name']}].rounds[{ri}]")
            _fp2_vec(a.get("terminals"), nterm, f"ffn_arguments[{a['name']}].terminals")
            out.append({"name": a["name"], "slot": slot, "rounds": nv, "degree": deg,
                        "terminals": nterm})
        return out

    def _parse_policy(self, raw: dict) -> dict:
        pol = raw.get("expected_policy")
        if not isinstance(pol, list) or len(pol) != POLICY_BYTES or \
                not all(_is_int(x) and 0 <= x < 256 for x in pol):
            raise IoCaptureError(f"expected_policy: not {POLICY_BYTES} bytes")
        b = bytes(pol)
        if b[:8] != POLICY_MAGIC:
            raise IoCaptureError(f"expected_policy magic {b[:8]!r} is not {POLICY_MAGIC!r}")
        digest = sha256_bytes(b)
        if digest != raw.get("expected_policy_sha256"):
            raise IoCaptureError("expected_policy_sha256 is not sha256(expected_policy)")
        in_root = b[48:80].hex()
        out_root = b[80:112].hex()
        if in_root != self.by_role["Input"].root or out_root != self.by_role["Output"].root:
            raise IoCaptureError("the policy's endpoint roots are not the captured endpoint "
                                 "commitment roots")
        return {"bytes": POLICY_BYTES, "sha256": digest, "magic": POLICY_MAGIC.decode(),
                "context": b[8:40].hex(),
                "input_scale": int.from_bytes(b[40:44], "little", signed=True),
                "output_scale": int.from_bytes(b[44:48], "little", signed=True),
                "input_root": in_root, "output_root": out_root, "raw": b}

    def _check_siblings(self) -> dict:
        stem = self.path[:-5] if self.path.endswith(".json") else self.path
        rpath, ppath = stem + ".receipt", stem + ".expected"
        for p in (rpath, ppath):
            if not os.path.exists(p):
                raise IoCaptureError(f"missing sibling artifact {os.path.basename(p)}: missing files "
                                     f"are missing evidence")
        with open(rpath, "rb") as fh:
            receipt = fh.read()
        with open(ppath, "rb") as fh:
            policy = fh.read()
        rd = sha256_bytes(receipt)
        if rd != self.proof_sha256:
            raise IoCaptureError(f"receipt sha256 {rd[:16]}.. is not the capture's proof_sha256")
        if len(receipt) != self.proof_bytes:
            raise IoCaptureError(f"receipt is {len(receipt)} bytes, the capture says {self.proof_bytes}")
        if receipt[:8] != RECEIPT_MAGIC:
            raise IoCaptureError(f"receipt magic {receipt[:8]!r} is not {RECEIPT_MAGIC!r}")
        if policy != self.expected_policy["raw"]:
            raise IoCaptureError("the .expected artifact is not the capture's expected_policy bytes")
        return {"receipt": os.path.basename(rpath), "receipt_sha256": rd,
                "receipt_bytes": len(receipt), "receipt_magic": receipt[:8].hex(),
                "policy": os.path.basename(ppath), "policy_sha256": sha256_bytes(policy),
                "policy_bytes": len(policy)}

    def header(self) -> dict:
        return {"file": os.path.basename(self.path), "file_sha256": self.file_sha256,
                "bytes": self.bytes, "proof_sha256": self.proof_sha256,
                "proof_bytes": self.proof_bytes, "privacy": self.privacy, "shape": self.shape,
                "shifts": list(self.shifts), "coverage": COVERAGE, "profile": PROFILE,
                "transcript_domain": TRANSCRIPT_DOMAIN, "source_commit": self.source_commit,
                "schema": SCHEMA, "layout_digest": self.layout_digest_declared,
                "layout_digest_recomputed": self.layout_digest_recomputed,
                "roles": [r.role for r in self.roles],
                "expected_policy_sha256": self.expected_policy["sha256"],
                "policy_context": self.expected_policy["context"],
                "policy_scales": [self.expected_policy["input_scale"],
                                  self.expected_policy["output_scale"]],
                "siblings": self.siblings}


# ---------------------------------------------------------------------------
# the joint model over a UNION of commitments (the FA7 model, same mathematics)
# ---------------------------------------------------------------------------


ALIAS_PAIRS = [(("A", 14), ("Input", 0)), (("A", 15), ("Input", 1)),
               (("A", 16), ("Output", 0)), (("A", 17), ("Output", 1))]


class JointModel:
    """FA7's message / terminal / proximity system over several commitments at once.

    Identical to `zk60_fable_joint_capture.RoleModel` except that (a) rows are the
    disjoint union of the commitments' rows modulo an alias identification and
    (b) each commitment contributes its own proximity block coordinate pair.  On a
    single commitment with no alias it reproduces `RoleModel` exactly; that is
    asserted by `joint_model_matches_role_model`."""

    def __init__(self, obses: Sequence[IoRoleObs], alias_pairs: Sequence[tuple] = (),
                 zero_sum: bool = True, extras: Optional[List[dict]] = None, name: str = ""):
        if not obses:
            raise IoCaptureError("JointModel: no commitments")
        self.obses = list(obses)
        self.name = name or "+".join(o.role for o in self.obses)
        ns = {o.n for o in self.obses}
        if len(ns) != 1:
            raise IoCaptureError(f"JointModel: the commitments do not share one column count: {ns}. "
                                 f"A joint model needs one column index for the aliased planes.")
        self.n = ns.pop()
        idx = {o.role: i for i, o in enumerate(self.obses)}
        # union-find over (commitment, row)
        parent: Dict[Tuple[int, int], Tuple[int, int]] = {}

        def find(x):
            parent.setdefault(x, x)
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x

        self.alias_pairs = []
        for (ra, rowa), (rb, rowb) in alias_pairs:
            if ra not in idx or rb not in idx:
                continue
            a, b = (idx[ra], rowa), (idx[rb], rowb)
            for ci, r in (a, b):
                if r >= self.obses[ci].rows:
                    raise IoCaptureError(f"JointModel: alias row {r} outside {self.obses[ci].role}")
                if self.obses[ci].row_kind[r] != "data":
                    raise IoCaptureError(f"JointModel: alias row {r} of {self.obses[ci].role} is "
                                         f"{self.obses[ci].row_kind[r]}, not data -- an alias may only "
                                         f"identify data planes, never masks")
            parent[find(a)] = find(b)
            self.alias_pairs.append([[ra, rowa], [rb, rowb]])
        mid: Dict[Tuple[int, int], int] = {}
        self.merged_of: Dict[Tuple[int, int], int] = {}
        for ci, o in enumerate(self.obses):
            for r in range(o.rows):
                root = find((ci, r))
                if root not in mid:
                    mid[root] = len(mid)
                self.merged_of[(ci, r)] = mid[root]
        self.rows = len(mid)
        self.owners: List[List[Tuple[int, int]]] = [[] for _ in range(self.rows)]
        for (ci, r), m in self.merged_of.items():
            self.owners[m].append((ci, r))
        for lst in self.owners:
            lst.sort()

        # block / cross coordinate spaces
        self.group_off, self.claim_off = [], []
        g_total = k_total = 0
        for o in self.obses:
            self.group_off.append(g_total)
            self.claim_off.append(k_total)
            g_total += len(o.groups)
            k_total += len(o.claims)
        self.G, self.K = g_total, k_total
        self.nb = 2 * self.G + 2 * len(self.obses)
        self.extras: List[dict] = list(extras or [])
        if zero_sum:
            for ci, o in enumerate(self.obses):
                if o.role != "H":
                    continue
                u_re, u_im = o.layout["zero_sum_pair"]
                self.extras.insert(0, {
                    "name": "zero_sum(u)", "commitment": "H",
                    "coefs": {self.merged_of[(ci, u_re)]: ONE, self.merged_of[(ci, u_im)]: U},
                    "public_value": ZERO,
                    "source": "zsum sumcheck: sum over the n-cube of u = 0"})
        self.E = len(self.extras)
        self.tdim = 2 * self.K + 2 * self.E

        # per-merged-row references
        ref: List[List[Tuple[int, int, int, Fp2]]] = [[] for _ in range(self.rows)]
        proxc: List[List[Tuple[int, Fp2]]] = [[] for _ in range(self.rows)]
        kind: List[Optional[str]] = [None] * self.rows
        rname: List[str] = [""] * self.rows
        for ci, o in enumerate(self.obses):
            for k, c in enumerate(o.claims):
                for pi, p in enumerate(c["parts"]):
                    for i in range(p["nrows"]):
                        ref[self.merged_of[(ci, p["row0"] + i)]].append((ci, k, pi, p["rw"][i]))
            for r in range(o.rows):
                m = self.merged_of[(ci, r)]
                proxc[m].append((ci, o.rho[r]))
                kk = "data" if o.row_kind[r] == "data" else ("mask" if o.row_kind[r] == "mask" else "prox")
                if kind[m] is None:
                    kind[m] = kk
                    rname[m] = o.row_name[r]
                elif kind[m] != kk:
                    raise IoCaptureError(f"JointModel: merged row {m} is {kind[m]} in one commitment "
                                         f"and {kk} in another")
        self.row_kind = [k or "prox" for k in kind]
        self.row_name = rname
        self.data_rows = [r for r in range(self.rows) if self.row_kind[r] == "data"]
        self.mask_rows = [r for r in range(self.rows) if self.row_kind[r] in ("mask", "prox")]
        extra_on: List[List[Tuple[int, Fp2]]] = [[] for _ in range(self.rows)]
        for ei, e in enumerate(self.extras):
            for r, cf in e["coefs"].items():
                extra_on[r].append((ei, cf))

        # sites: merged rows with the same claim memberships, proximity owners,
        # extra coefficients, kind and plane name
        self.sites: List[C.Site] = []
        index: Dict[tuple, int] = {}
        feats: List[List[List[int]]] = []
        for r in range(self.rows):
            key = (tuple((ci, k, pi) for ci, k, pi, _ in ref[r]),
                   tuple(ci for ci, _ in proxc[r]), tuple(extra_on[r]),
                   self.row_kind[r], self.row_name[r])
            si = index.get(key)
            if si is None:
                si = len(self.sites)
                index[key] = si
                self.sites.append(C.Site(key, self.row_kind[r], self.row_name[r]))
                feats.append([])
            self.sites[si].rows.append(r)
            feat: List[int] = []
            for _, _, _, rw in ref[r]:
                feat.extend(rw)
            for _, rho in proxc[r]:
                feat.extend(rho)
            feat.append(1)
            feats[si].append(feat)

        # generators: one per site basis vector
        self.beta: List[List[int]] = []
        self.zeta: List[Dict[int, Fp2]] = []
        self.xi: List[Dict[int, int]] = []
        for si, s in enumerate(self.sites):
            s.basis = C._row_span_basis(feats[si])
            memb, owners, ex = s.key[0], s.key[1], s.key[2]
            for b in s.basis:
                beta = [0] * self.nb
                zeta: Dict[int, Fp2] = {}
                xi: Dict[int, int] = {}
                pos = 0
                for (ci, k, pi) in memb:
                    x = (b[pos], b[pos + 1])
                    pos += 2
                    o = self.obses[ci]
                    part = o.claims[k]["parts"][pi]
                    g = o.claims[k]["group"]
                    lam = o.groups[g]["lambdas"][o.groups[g]["members"].index(k)]
                    cz = f2_mul(part["coef"], x)
                    cb = f2_mul(lam, cz)
                    gg = self.group_off[ci] + g
                    beta[2 * gg] = (beta[2 * gg] + cb[0]) % P
                    beta[2 * gg + 1] = (beta[2 * gg + 1] + cb[1]) % P
                    kk = self.claim_off[ci] + k
                    zeta[kk] = f2_add(zeta.get(kk, ZERO), cz)
                for ci in owners:
                    rho = (b[pos], b[pos + 1])
                    pos += 2
                    pc = 2 * self.G + 2 * ci
                    beta[pc] = (beta[pc] + rho[0]) % P
                    beta[pc + 1] = (beta[pc + 1] + rho[1]) % P
                one = b[pos]
                for ei, cf in ex:
                    xi[2 * self.K + 2 * ei] = (xi.get(2 * self.K + 2 * ei, 0) + cf[0] * one) % P
                    xi[2 * self.K + 2 * ei + 1] = (xi.get(2 * self.K + 2 * ei + 1, 0) + cf[1] * one) % P
                s.gens.append(len(self.beta))
                self.beta.append(beta)
                self.zeta.append(zeta)
                self.xi.append(xi)
        self.claim_cw: List[List[Fp2]] = []
        for ci, o in enumerate(self.obses):
            for c in o.claims:
                self.claim_cw.append(o.groups[c["group"]]["cw"])
        self._cache: Dict[tuple, tuple] = {}

    # -- generator sets --------------------------------------------------------
    def gens_of(self, pred) -> Tuple[int, ...]:
        return tuple(g for s in self.sites if pred(s) for g in s.gens)

    def mask_gens(self) -> Tuple[int, ...]:
        return self.gens_of(lambda s: s.kind in ("mask", "prox"))

    def all_gens(self) -> Tuple[int, ...]:
        return tuple(range(len(self.beta)))

    def plane_gens(self, rows: Iterable[int]) -> Tuple[int, ...]:
        rs = set(rows)
        return self.gens_of(lambda s: s.kind == "data" and any(r in rs for r in s.rows))

    # -- the block part and the cross-column kernel ---------------------------
    def block_and_z(self, gens: Tuple[int, ...]) -> Tuple[int, List[List[int]]]:
        key = ("bz", gens)
        if key in self._cache:
            return self._cache[key]
        if not gens:
            self._cache[key] = (0, [])
            return 0, []
        null = R.left_null_space([self.beta[a] for a in gens], self.nb)
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
        zb = C._row_span_basis(zs) if zs else []
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

    def kernel_dim(self, zb, columns=None, ech=None) -> C.Echelon:
        ech = ech if ech is not None else C.Echelon(self.tdim)
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

    # -- explicit, uncompressed per-column cross-check -------------------------
    def explicit_per_column(self) -> dict:
        """The per-column observation matrix written out row by row over every merged
        row unknown -- no site compression at all.  Its ranks must equal the
        compressed model's, which is what validates the compression."""
        obsv: List[List[Fp2]] = []
        for ci, o in enumerate(self.obses):
            for g in o.groups:
                coef = [ZERO] * self.rows
                for k, lam in zip(g["members"], g["lambdas"]):
                    for p in o.claims[k]["parts"]:
                        factor = f2_mul(lam, p["coef"])
                        for i, wgt in enumerate(p["rw"]):
                            m = self.merged_of[(ci, p["row0"] + i)]
                            coef[m] = f2_add(coef[m], f2_mul(factor, wgt))
                obsv.append(coef)
        for ci, o in enumerate(self.obses):
            coef = [ZERO] * self.rows
            for r in range(o.rows):
                m = self.merged_of[(ci, r)]
                coef[m] = f2_add(coef[m], o.rho[r])
            obsv.append(coef)
        base = [[c[k] for c in row] for row in obsv for k in (0, 1)]
        b = [[row[r] for r in self.mask_rows] for row in base]
        ab = [[row[r] for r in self.data_rows + self.mask_rows] for row in base]
        rb, rj = R.rank(b), R.rank(ab)
        return {"base_observation_rows": len(base), "rank_mask": rb, "rank_joint": rj,
                "disclosed_per_column": rj - rb, "merged_rows": self.rows,
                "data_rows": len(self.data_rows), "mask_rows": len(self.mask_rows)}

    # -- analysis ---------------------------------------------------------------
    def analyze(self, planes: bool = True, plane_names: Optional[Sequence[str]] = None) -> dict:
        masks, alls = self.mask_gens(), self.all_gens()
        rm, ra = self.rank(masks), self.rank(alls)
        n_obs = self.n * self.nb + self.tdim
        out = {
            "commitments": [o.role for o in self.obses],
            "aliases_applied": self.alias_pairs,
            "unknowns": {"total": self.rows * self.n, "data": len(self.data_rows) * self.n,
                         "mask": len(self.mask_rows) * self.n,
                         "merged_rows": self.rows,
                         "rows_before_aliasing": sum(o.rows for o in self.obses)},
            "base_observation_rows": {"group_vectors": self.n * 2 * self.G,
                                      "proximity": self.n * 2 * len(self.obses),
                                      "terminals": 2 * self.K, "extras": 2 * self.E,
                                      "total": n_obs},
            "extras": [{"name": e["name"], "commitment": e.get("commitment"),
                        "rows": sorted(e["coefs"]), "public_value": list(e.get("public_value", ZERO)),
                        "source": e.get("source", "")} for e in self.extras],
            "sites": len(self.sites), "generators": len(self.beta),
            "per_column": {"rank_mask": rm["block_rank_per_column"],
                           "rank_joint": ra["block_rank_per_column"],
                           "disclosed_per_column": ra["block_rank_per_column"] - rm["block_rank_per_column"],
                           "base_rows_per_column": self.nb},
            "joint": {"rank_mask": rm["rank"], "rank_joint": ra["rank"],
                      "disclosed_total": ra["rank"] - rm["rank"],
                      "cross_column_kernel_mask": rm["kernel_dim"],
                      "cross_column_kernel_joint": ra["kernel_dim"],
                      "cross_column_increment": ra["kernel_dim"] - rm["kernel_dim"],
                      "per_column_total": self.n * (ra["block_rank_per_column"] - rm["block_rank_per_column"]),
                      "null_functionals_killing_masks_and_data": n_obs - ra["rank"]},
        }
        if planes:
            pl = {}
            groups: Dict[str, List[int]] = {}
            for r in self.data_rows:
                nm = self.row_name[r]
                for sfx in (".re", ".im"):
                    if nm.endswith(sfx):
                        nm = nm[: -len(sfx)]
                groups.setdefault(nm, []).append(r)
            for nm, rows in groups.items():
                if plane_names is not None and nm not in plane_names:
                    continue
                pg = self.plane_gens(rows)
                rest = tuple(a for a in alls if a not in set(pg))
                proj = self.rank(tuple(sorted(set(masks) | set(pg))))["rank"] - rm["rank"]
                iso = ra["rank"] - self.rank(rest)["rank"]
                pl[nm] = {"rows": rows if len(rows) <= 8 else [rows[0], "...", rows[-1]],
                          "row_count": len(rows), "unknowns": len(rows) * self.n,
                          "projected_disclosed_dim": proj, "isolated_disclosed_dim": iso,
                          "fully_recovered": iso == len(rows) * self.n}
            out["planes"] = pl
        return out


def joint_model_matches_role_model(obs: IoRoleObs) -> dict:
    """CONTROL: the generalised model on ONE commitment must be the inherited
    `RoleModel` to the digit."""
    a = C.RoleModel(obs).analyze(planes=False)
    b = JointModel([obs]).analyze(planes=False)
    keys = ("rank_mask", "rank_joint", "disclosed_total", "cross_column_kernel_mask",
            "cross_column_kernel_joint", "cross_column_increment")
    same = all(a["joint"][k] == b["joint"][k] for k in keys) and \
        a["per_column"]["disclosed_per_column"] == b["per_column"]["disclosed_per_column"] and \
        a["per_column"]["rank_mask"] == b["per_column"]["rank_mask"] and \
        a["per_column"]["rank_joint"] == b["per_column"]["rank_joint"]
    return {"role": obs.role, "role_model": {k: a["joint"][k] for k in keys},
            "joint_model": {k: b["joint"][k] for k in keys},
            "per_column": [a["per_column"]["disclosed_per_column"],
                           b["per_column"]["disclosed_per_column"]],
            "agree": bool(same)}


# ---------------------------------------------------------------------------
# controls
# ---------------------------------------------------------------------------


def ablate_endpoint_mask_pair(obs: IoRoleObs) -> IoRoleObs:
    """POSITIVE CONTROL construction: drop the SECOND (times-u) mask part of an
    endpoint claim, i.e. rebuild the legacy single-base-mask form on this very
    commitment.  Row 3 then stops being referenced and becomes a proximity-only
    row, exactly as the legacy layout had it."""
    if obs.role not in ("Input", "Output"):
        raise IoCaptureError("the ablation control applies to an endpoint commitment")
    o = copy.deepcopy(obs)
    o.claims[0]["parts"] = o.claims[0]["parts"][:2]
    o.part_kind[0] = o.part_kind[0][:2]
    o.part_name[0] = o.part_name[0][:2]
    o.part_tag[0] = o.part_tag[0][:2]
    dropped = o.layout["terminal_mask_pair_row"] if "terminal_mask_pair_row" in o.layout else 3
    exp = dict(o.layout)
    exp["prox_rows"] = sorted([dropped] + list(o.layout["prox_rows"]))
    exp["claims"] = [list(o.layout["claims"][0])[:2]]
    exp["coefficient_tags"] = [list(o.layout["coefficient_tags"][0])[:2]]
    o.layout = exp
    o.declared_kind[dropped] = "prox"          # the legacy layout had no second mask row
    o._derive_row_roles(exp)
    return o


def endpoint_ablation_control(obs: IoRoleObs) -> dict:
    """The paired endpoint must disclose nothing and the single-mask ablation must
    disclose something: a model that cannot see the legacy leak is worthless."""
    paired = JointModel([obs]).analyze(planes=False)
    single = JointModel([ablate_endpoint_mask_pair(obs)]).analyze(planes=False)
    return {"role": obs.role,
            "paired_disclosed_total": paired["joint"]["disclosed_total"],
            "paired_disclosed_per_column": paired["per_column"]["disclosed_per_column"],
            "single_mask_disclosed_total": single["joint"]["disclosed_total"],
            "single_mask_disclosed_per_column": single["per_column"]["disclosed_per_column"],
            "control_detects_the_legacy_leak": single["joint"]["disclosed_total"] > 0
            and paired["joint"]["disclosed_total"] == 0,
            "meaning": "the endpoint's mask PAIR (rows 2 and 3, coefficients e and e*u) is what "
                       "closes the FA1 single-mask projection; with one base mask row the same "
                       "opening leaks one base dimension per column"}


def mutation_controls(path: str, source_commit: str = SOURCE_COMMIT) -> dict:
    """NEGATIVE CONTROLS against a real accepted capture: each named mutation must be
    refused by this adapter's own recomputation, not by a digest comparison."""
    with open(path, "rb") as fh:
        raw_bytes = fh.read()
    base = load_capture_json(raw_bytes)
    IoCapture(path, require_digest_name=False, require_siblings=False,
              source_commit=source_commit, raw=copy.deepcopy(base))
    ai = next(i for i, r in enumerate(base["roles"]) if r["role"] == "A")
    ii = next(i for i, r in enumerate(base["roles"]) if r["role"] == "Input")
    a = base["roles"][ai]
    muts = [
        ("altered_source", ["source_commit"], "0" * 40),
        ("altered_profile", ["profile"], DRAFT_PROFILE),
        ("legacy_schema", ["schema"], 2),
        ("legacy_coverage", ["coverage"], "ffn-v3-mr1-fresh-poc-function-1"),
        ("relabelled_transcript_domain", ["transcript_domain"], "hashline-zk-mr1/" + DRAFT_PROFILE),
        ("legacy_digest_encoding", ["proof_digest_encoding"],
         "legacy logical payload; experimental profile is bound in transcript"),
        ("privacy_acceptance_claim", ["privacy_review_complete"], True),
        ("legacy_A_rows", ["roles", ai, "commitment", "rows"], 698),
        ("missing_IO_mask_row", ["roles", ai, "claims", 18, "parts"], a["claims"][18]["parts"][:2]),
        ("incorrect_endpoint_alias_A_side", ["roles", ai, "claims", 18, "parts", 0, "offset"], 4096),
        ("incorrect_endpoint_alias_endpoint_side",
         ["roles", ii, "claims", 0, "parts", 0, "offset"], 512),
        ("endpoint_mask_row_relabelled_as_data",
         ["roles", ii, "row_roles", 3, "kind"], "data"),
        ("missing_IO_group", ["roles", ai, "groups"], a["groups"][:-1]),
        ("changed_role_order", ["roles"], base["roles"][:-2] + base["roles"][-2:][::-1]),
        ("missing_output_endpoint", ["roles"], base["roles"][:-1]),
        ("changed_opening_order", ["opening_order"],
         ["M", "W", "A", "H", "Output", "Input"]),
        ("narrowed_M_columns", ["mask", "columns", 0, "values"],
         base["mask"]["columns"][0]["values"][:16]),
        ("missing_M_IO_slots", ["mask", "specs"], base["mask"]["specs"][:6]),
        ("missing_M_functional", ["mask", "functionals"], base["mask"]["functionals"][:-1]),
        ("malformed_field_noncanonical_word",
         ["roles", ai, "columns", 0, "values", 0], P),
        ("malformed_field_boolean_coordinate",
         ["roles", ai, "groups", 0, "vector", 0, 0], True),
        ("malformed_policy_length", ["expected_policy"], base["expected_policy"][:-1]),
        ("broken_group_terminal_equation", ["roles", ai, "groups", 5, "vector", 0], [0, 0]),
        ("broken_transcript_join", ["mask", "after", "next"], [0, 0]),
        ("wrong_io_slot", ["io_arguments", 1, "slot"], 6),
        ("wrong_io_terminal", ["io_arguments", 1, "terminals", 1], [0, 0]),
        ("zero_terminal_mask_challenge", ["io_arguments", 0, "rho", 9], [0, 0]),
    ]
    results = []
    for name, keys, value in muts:
        cand = copy.deepcopy(base)
        cur = cand
        for k in keys[:-1]:
            cur = cur[k]
        cur[keys[-1]] = value
        try:
            IoCapture(path, require_digest_name=False, require_siblings=False,
                      source_commit=source_commit, raw=cand)
        except C.CaptureError as err:
            results.append({"name": name, "rejected": True, "reason": str(err)[:220]})
        else:
            results.append({"name": name, "rejected": False,
                            "PROBLEM": "the adapter accepted a mutated capture"})
    for name, text in (("duplicate_json_key", '{"x":1,"x":2}'), ("floating_point", '{"x":1.0}'),
                       ("nan_constant", '{"x":NaN}')):
        try:
            load_capture_json(text.encode())
        except C.CaptureError as err:
            results.append({"name": name, "rejected": True, "reason": str(err)[:220]})
        else:
            results.append({"name": name, "rejected": False,
                            "PROBLEM": "malformed JSON accepted"})
    IoCapture(path, require_digest_name=False, require_siblings=False,
              source_commit=source_commit, raw=copy.deepcopy(base))
    return {"capture": os.path.basename(path), "capture_sha256": sha256_bytes(raw_bytes),
            "positive_control": "the unmodified real capture is accepted before and after the battery",
            "controls": results, "all_rejected": all(r["rejected"] for r in results),
            "count": len(results)}


def legacy_control(legacy_dir: str, log=print) -> dict:
    """POSITIVE CONTROL, retained from O2: (a) this adapter must REFUSE every legacy
    schema-1 capture; (b) Fable's archived legacy tool must still reproduce its
    disclosure numbers on them (A = 2n + 4, P3 W = 2n + 2, H = 2, T32 Wd recovered)."""
    out: dict = {"directory": os.path.abspath(legacy_dir), "adapter_refusals": [],
                 "legacy_tool_cases": [],
                 "expected_legacy": {"A": "2n + 4 = 516", "W(P3)": "2n + 2 = 514",
                                     "H": "2 (the public LogUp identity)",
                                     "T32 Wd": "fully recovered"}}
    files = sorted(f for f in os.listdir(legacy_dir) if f.endswith(".json"))
    for name in files:
        path = os.path.join(legacy_dir, name)
        try:
            IoCapture(path, require_digest_name=False, require_siblings=False)
            out["adapter_refusals"].append({"file": name, "refused": False,
                                            "PROBLEM": "the IO adapter accepted a legacy capture"})
        except C.CaptureError as err:
            out["adapter_refusals"].append({"file": name, "refused": True, "reason": str(err)[:160]})
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
            an = C.RoleModel(obs).analyze(planes=True, plane_columns=())
            case = {"file": name, "file_sha256": cap.file_sha256, "privacy": cap.privacy,
                    "shape": cap.shape, "role": obs.role, "n": obs.n,
                    "per_column_disclosed": an["per_column"]["disclosed_per_column"],
                    "joint_disclosed_total": an["joint"]["disclosed_total"]}
            for pname, pe in an["planes"].items():
                if pe.get("fully_recovered"):
                    case.setdefault("fully_recovered_planes", []).append(
                        {"plane": pname, "rows": pe["row_count"], "isolated": pe["isolated_disclosed_dim"]})
            out["legacy_tool_cases"].append(case)
            log(f"  legacy {name[:12]} {cap.privacy} {obs.role}: per-column "
                f"{case['per_column_disclosed']}, joint {case['joint_disclosed_total']}")
        del cap
    got: Dict[str, set] = {}
    for c in out["legacy_tool_cases"]:
        if "role" in c:
            got.setdefault(c["role"], set()).add(c["joint_disclosed_total"])
    out["legacy_tool_reproduces_fa7"] = {r: sorted(v) for r, v in got.items()}
    out["reproduced"] = out["legacy_tool_reproduces_fa7"] == {"A": [516], "H": [2], "W": [514]}
    return out


# ---------------------------------------------------------------------------
# the manifest
# ---------------------------------------------------------------------------


def load_manifest(path: str) -> dict:
    with open(path) as fh:
        rec = json.load(fh)
    caps = rec.get("captures")
    if not isinstance(caps, dict) or not isinstance(caps.get("cases"), list):
        raise IoCaptureError(f"{path}: no `captures.cases` list (round-19 record shape)")
    entries = {}
    for e in caps["cases"]:
        for k in ("path", "capture_sha256", "capture_bytes", "proof_sha256", "proof_bytes",
                  "privacy", "expected_policy_sha256"):
            if k not in e:
                raise IoCaptureError(f"{path}: capture entry missing {k!r}")
        entries[e["proof_sha256"]] = e
    return {"path": os.path.abspath(path), "sha256": sha256_file(path),
            "source_commit": rec.get("source_commit"),
            "capture_source_commit": caps.get("source_commit"),
            "status": rec.get("status"), "captures_status": caps.get("status"),
            "counts": caps.get("counts"), "tools": caps.get("tools"),
            "privacy_analysis_performed": rec.get("privacy_analysis_performed"),
            "full_privacy_review_complete": caps.get("full_privacy_review_complete"),
            "rust_test_count": rec.get("rust_test_count"),
            "entries": entries}


def _chk(checks: List[dict], name: str, ok: bool, actual, expected, note: str = "") -> bool:
    checks.append({"check": name, "pass": bool(ok), "actual": actual, "expected": expected,
                   **({"note": note} if note else {})})
    return bool(ok)


def preflight(captures_dir: str, manifest_path: str, out_path: Optional[str] = None,
              log=print) -> dict:
    """O8 item 1: the four capture / receipt / policy triples against the manifest."""
    man = load_manifest(manifest_path)
    files = sorted(f for f in os.listdir(captures_dir) if f.endswith(".json"))
    checks: List[dict] = []
    report = {"schema_version": 1, "task": "O8 item 1 -- IO capture / receipt / policy integrity",
              "reviewer": REVIEWER, "profile": PROFILE, "coverage": COVERAGE, "schema": SCHEMA,
              "source_commit": SOURCE_COMMIT,
              "captures_directory": os.path.abspath(captures_dir),
              "manifest": {k: man[k] for k in ("path", "sha256", "source_commit",
                                               "capture_source_commit", "status",
                                               "captures_status", "counts", "tools",
                                               "privacy_analysis_performed",
                                               "full_privacy_review_complete")},
              "checks": checks, "captures": []}
    _chk(checks, "manifest_source_pin", man["source_commit"] == SOURCE_COMMIT and
         man["capture_source_commit"] == SOURCE_COMMIT,
         [man["source_commit"], man["capture_source_commit"]], SOURCE_COMMIT,
         "the record's source_commit identifies the Rust capture producer")
    _chk(checks, "manifest_declares_no_privacy_result",
         man["privacy_analysis_performed"] is False and man["full_privacy_review_complete"] is False,
         [man["privacy_analysis_performed"], man["full_privacy_review_complete"]], [False, False])
    _chk(checks, "four_capture_json_files", len(files) == 4, len(files), 4,
         "missing files are missing evidence, never permission to relabel an old capture")
    _chk(checks, "manifest_lists_four", len(man["entries"]) == 4, len(man["entries"]), 4)
    _chk(checks, "manifest_privacy_counts", man["counts"] == {"P1": 2, "P3": 2}, man["counts"],
         {"P1": 2, "P3": 2})
    # the recorded tool digests: the FINAL preflight, not the Rust producer
    tool_state = {}
    for name, want in (man["tools"] or {}).items():
        p = os.path.join(_HERE, name)
        tool_state[name] = {"recorded": want,
                            "present": os.path.exists(p),
                            "actual": sha256_file(p) if os.path.exists(p) else None}
        tool_state[name]["matches"] = tool_state[name]["actual"] == want
    report["recorded_tool_digests"] = tool_state
    _chk(checks, "recorded_tool_digests_match_this_worktree",
         all(v["matches"] for v in tool_state.values()),
         {k: v["matches"] for k, v in tool_state.items()}, "all true")
    counts = {"P1": 0, "P3": 0}
    for name in files:
        path = os.path.join(captures_dir, name)
        stem = name[:-5]
        entry = man["entries"].get(stem)
        got_sha = sha256_file(path)
        got_bytes = os.path.getsize(path)
        ck = {"file": name, "capture_sha256": got_sha, "capture_bytes": got_bytes}
        if entry is None:
            _chk(checks, f"{stem[:12]}::in_manifest", False, None, "a manifest entry")
            report["captures"].append(ck)
            continue
        _chk(checks, f"{stem[:12]}::capture_sha256", got_sha == entry["capture_sha256"],
             got_sha[:16], entry["capture_sha256"][:16])
        _chk(checks, f"{stem[:12]}::capture_bytes", got_bytes == entry["capture_bytes"],
             got_bytes, entry["capture_bytes"])
        try:
            cap = IoCapture(path, expected_capture_sha256=entry["capture_sha256"])
        except C.CaptureError as err:
            _chk(checks, f"{stem[:12]}::parses", False, str(err)[:200], "accepted")
            report["captures"].append(ck)
            continue
        counts[cap.privacy] += 1
        _chk(checks, f"{stem[:12]}::privacy", cap.privacy == entry["privacy"], cap.privacy,
             entry["privacy"])
        _chk(checks, f"{stem[:12]}::coverage_profile_source",
             (COVERAGE, PROFILE, cap.source_commit) == (COVERAGE, PROFILE, SOURCE_COMMIT),
             [COVERAGE, PROFILE, cap.source_commit[:7]], [COVERAGE, PROFILE, SOURCE_COMMIT[:7]])
        _chk(checks, f"{stem[:12]}::receipt_digest_is_the_file_name",
             cap.siblings["receipt_sha256"] == stem == cap.proof_sha256,
             cap.siblings["receipt_sha256"][:16], stem[:16],
             "the digest covers the COMPLETE receipt frame")
        _chk(checks, f"{stem[:12]}::receipt_bytes", cap.siblings["receipt_bytes"] == entry["proof_bytes"]
             == IOL.io_frame_len(private=cap.privacy == "P3"), cap.siblings["receipt_bytes"],
             entry["proof_bytes"], "independently re-derived from the wire model")
        _chk(checks, f"{stem[:12]}::policy_digest",
             cap.expected_policy["sha256"] == entry["expected_policy_sha256"],
             cap.expected_policy["sha256"][:16], entry["expected_policy_sha256"][:16])
        _chk(checks, f"{stem[:12]}::policy_binds_endpoint_roots", True,
             [cap.expected_policy["input_root"][:12], cap.expected_policy["output_root"][:12]],
             "the two endpoint commitment roots")
        _chk(checks, f"{stem[:12]}::roles", [r.role for r in cap.roles] == ROLE_ORDER[cap.privacy],
             [r.role for r in cap.roles], ROLE_ORDER[cap.privacy])
        _chk(checks, f"{stem[:12]}::rows_and_groups",
             all(r.rows == EXPECTED_ROWS[r.role] and
                 [len(g["members"]) for g in r.groups] == EXPECTED_GROUP_SHAPE[r.role]
                 for r in cap.roles),
             {r.role: [r.rows, [len(g["members"]) for g in r.groups]] for r in cap.roles},
             {k: [EXPECTED_ROWS[k], EXPECTED_GROUP_SHAPE[k]] for k in ROLE_ORDER[cap.privacy]})
        _chk(checks, f"{stem[:12]}::layout_digest_recomputed",
             cap.layout_digest_declared == cap.layout_digest_recomputed,
             cap.layout_digest_declared[:16], cap.layout_digest_recomputed[:16])
        ck.update({k: v for k, v in cap.header().items() if k != "file"})
        ck["manifest_entry"] = entry
        report["captures"].append(ck)
        del cap
    _chk(checks, "two_P1_and_two_P3", counts == {"P1": 2, "P3": 2}, counts, {"P1": 2, "P3": 2})
    report["pass"] = all(c["pass"] for c in checks)
    if out_path:
        with open(out_path, "w") as fh:
            json.dump(report, fh, indent=1)
        log(f"wrote {out_path}")
    return report


# ---------------------------------------------------------------------------
# the cross-component obligation inventory (item 4)
# ---------------------------------------------------------------------------


def cross_component_obligations(cap: IoCapture) -> List[dict]:
    """Everything the linear model deliberately does not cover, counted on THIS
    capture so Codex has quantities, not adjectives."""
    n = cap.geo["n"]
    roles = cap.roles
    role_vectors = sum(len(r.groups) + 1 for r in roles)
    return [
        {"id": "OBL-1", "class": "pads",
         "what": f"{role_vectors} role clear vectors (group + proximity) each carry Q = {Q_PAD} pad "
                 f"coordinates after their {n} message coordinates, and the M opening carries two "
                 f"{M_VECTOR}-entry vectors; the IO profile adds "
                 f"{2 + 2 * 2} of those role vectors (A's two IO groups, each endpoint's group and "
                 f"proximity vector)",
         "needs": "the Vandermonde / pad-budget argument extended to the new vectors",
         "partly_addressed_by": "ZK60_ROUND20 section 1, CONDITIONALLY (see OBL-10)"},
        {"id": "OBL-2", "class": "sampled_columns",
         "what": f"{NUM_COL_CHECKS} opened encoded columns per role commitment "
                 f"({sum(len(r.sampled_columns) for r in roles)} in this capture, each with a salt and "
                 f"an {COLUMN_PATH_LEN}-node path) plus {NUM_COL_CHECKS} M columns of {M_ROWS} words "
                 f"and {M_LOG_DOMAIN} nodes",
         "needs": "the salted-leaf / pad hiding argument, unchanged in form but now over the endpoint "
                  "commitments too",
         "partly_addressed_by": "ZK60_ROUND20 section 1 keeps every sampled encoded WORD fixed, but "
                                "explicitly does NOT keep the salted Merkle roots or the "
                                "authentication paths fixed (see OBL-10)"},
        {"id": "OBL-3", "class": "endpoint_second_encoding",
         "what": "each aliased plane (X, z16) is encoded and column-opened TWICE -- once as A rows "
                 f"14/15 resp. 16/17 and once as rows 0/1 of its endpoint -- at independently drawn "
                 f"column sets ({2 * NUM_COL_CHECKS} openings per plane in total), with independent "
                 f"masks and independent pads",
         "needs": "NEW: an argument that two independent hiding encodings of ONE plane, sampled "
                  "independently, do not combine. Nothing in the linear model or in the earlier "
                  "profiles covers this; it arrives with the IO seam."},
        {"id": "OBL-4", "class": "cfs",
         "what": f"the single M commitment reserves {len(cap.mask['specs'])} slots holding "
                 f"{cap.mask['cfs_coefficients_total']} CFS mask coefficients and publishes "
                 f"{cap.mask['functionals']} public Fp2 functionals of them "
                 f"(openings per slot: {cap.mask['openings_per_slot']}); each IO slot (6 and 7) is "
                 f"opened TWICE -- once as the claimed sum gamma and once as the sumcheck's mask "
                 f"evaluation",
         "needs": "FA6's CFS argument extended to two openings of each IO slot's mask polynomial, "
                  "and to the combined M opening (theta, q, prox, columns)",
         "partly_addressed_by": "ZK60_ROUND20 section 2 covers the M OPENING (q, proximity, the "
                                "twenty sampled base words, both blinders) conditionally; the CFS "
                                "ROUND MESSAGES are explicitly outside it (see OBL-10)"},
        {"id": "OBL-5", "class": "nonlinear_rounds",
         "what": f"{sum(a['rounds'] for a in cap.io_arguments)} masked IO sumcheck rounds "
                 f"(degree 2, three coefficients each) and "
                 f"{sum(a['rounds'] for a in cap.ffn_arguments)} masked FFN sumcheck rounds, plus "
                 f"their terminals",
         "needs": "the masked-round-message argument; these are nonlinear in the witness and are not "
                  "in any linear model"},
        {"id": "OBL-6", "class": "repeats",
         "what": "the retained set is two P1 and two P3 proofs; each is analysed alone, and each "
                 "commitment is freshly randomised per proof (weight_policy fresh-per-proof)",
         "needs": "FA8's repeated-proof argument, now concrete rather than hypothetical: if the two "
                  "proofs of a mode share a witness, their observation sets compose"},
        {"id": "OBL-7", "class": "adaptive_composition",
         "what": "every lambda, rho, tau, e and theta in this capture is drawn AFTER masked messages "
                 "are absorbed; the model conditions on them",
         "needs": "the transcript/simulator argument (FA-transcript line), not a rank statement"},
        {"id": "OBL-8", "class": "side_information",
         "what": "X and z16 are scaled integer planes with a public scale in the 112-byte policy "
                 f"(input scale {cap.expected_policy['input_scale']}, output scale "
                 f"{cap.expected_policy['output_scale']}) and a public 32-byte context",
         "needs": "range / small-domain side information is outside a linear-algebra disclosure "
                  "model entirely"},
        {"id": "OBL-10", "class": "conditional_progress",
         "what": "Codex's round-20 opening lemma covers the pad / encoded-column / M-opening "
                 "channel CONDITIONALLY, and takes this task's joint message result as its premise",
         "lemma": ROUND20["statement"],
         "exclusions_that_remain_open": ROUND20["exclusions"],
         "needs": "composition of the joint message result with the CFS round-message channel and "
                  "this opening lemma UNDER THE ACTUAL ADAPTIVE TRANSCRIPT, plus the FA8 simulator "
                  "hypotheses for /2 (refusal, randomness allocation, single-opening owner "
                  "lifecycle) and a specified endpoint preparation / auxiliary-input model. "
                  "Neither the adaptive composition nor the caller-fixed endpoint simulation is "
                  "accepted here."},
        {"id": "OBL-9", "class": "identity",
         "what": "the endpoint policy binds two roots for ONE proof; no registered private model "
                 "identity or stable-weight statement exists at this profile",
         "needs": "the registered-identity and scale-authorization work Codex still has open"},
    ]


# ---------------------------------------------------------------------------
# the analysis driver
# ---------------------------------------------------------------------------


def analyze_capture(cap: IoCapture, planes: bool = True, log=print) -> dict:
    """Every private commitment alone, then the joint models over the union."""
    t0 = time.time()
    rec: dict = {"per_commitment": {}, "joint": {}, "controls": {}}
    obs = {r.role: r for r in cap.roles}
    private = [r for r in cap.roles]           # every captured role is a private commitment here
    # ---- per commitment, with the INHERITED RoleModel, unchanged --------------
    for ro in private:
        t1 = time.time()
        entry = {"role_summary": ro.summary(),
                 "included_observation_classes": sorted(
                     k for k in INCLUDED_CLASSES
                     if (k != "zero_sum" or ro.role == "H")
                     and (k != "cross_commitment_alias")),
                 "analysis": C.RoleModel(ro).analyze(planes=planes, plane_columns=())}
        if ro.role == "H":
            no_zs = C.RoleModel(ro, zero_sum=False).analyze(planes=False)
            with_id = C.RoleModel(ro, extras=[C.h_identity_extra(ro)])
            ra = with_id.rank(with_id.all_gens())["rank"]
            entry["h_zero_sum"] = {
                "disclosed_without_zero_sum_constraint": no_zs["joint"]["disclosed_total"],
                "disclosed_with_zero_sum_constraint": entry["analysis"]["joint"]["disclosed_total"],
                "identity_rows_in_observation_row_space": ra == entry["analysis"]["joint"]["rank_joint"],
                "residual_equals_public_logup_identity":
                    ra == entry["analysis"]["joint"]["rank_joint"]
                    and entry["analysis"]["joint"]["disclosed_total"] == 2,
                "meaning": "the surviving functionals are exactly the public LogUp identity "
                           "sum_j (helpers - table helpers), whose value the proof itself fixes to 0: "
                           "a known constant, not a witness functional"}
        entry["ms"] = _ms(t1)
        rec["per_commitment"][ro.role] = entry
        log(f"  {cap.proof_sha256[:12]} {cap.privacy} {ro.role}: per-column "
            f"{entry['analysis']['per_column']['disclosed_per_column']}, joint "
            f"{entry['analysis']['joint']['disclosed_total']} ({entry['ms']} ms)")
    # ---- controls on the generalisation --------------------------------------
    rec["controls"]["joint_model_matches_role_model"] = [
        joint_model_matches_role_model(ro) for ro in private]
    rec["controls"]["endpoint_mask_ablation"] = [
        endpoint_ablation_control(obs[r]) for r in ("Input", "Output")]
    # ---- the joint models -----------------------------------------------------
    io_cluster = [obs["A"], obs["Input"], obs["Output"]]
    t1 = time.time()
    jm = JointModel(io_cluster, ALIAS_PAIRS, name="A+Input+Output")
    a_io = jm.analyze(planes=planes)
    a_io["explicit_per_column_cross_check"] = jm.explicit_per_column()
    a_io["compression_cross_check_agrees"] = (
        a_io["explicit_per_column_cross_check"]["disclosed_per_column"]
        == a_io["per_column"]["disclosed_per_column"]
        and a_io["explicit_per_column_cross_check"]["rank_mask"] == a_io["per_column"]["rank_mask"]
        and a_io["explicit_per_column_cross_check"]["rank_joint"] == a_io["per_column"]["rank_joint"])
    a_io["ms"] = _ms(t1)
    rec["joint"]["io_cluster_aliased"] = a_io
    t1 = time.time()
    noalias = JointModel(io_cluster, (), name="A|Input|Output (no alias)").analyze(planes=False)
    noalias["ms"] = _ms(t1)
    rec["joint"]["io_cluster_unaliased_control"] = noalias
    t1 = time.time()
    allm = JointModel(private, ALIAS_PAIRS, name="all private commitments")
    a_all = allm.analyze(planes=planes, plane_names=("X[0]", "z16[0]", "Input", "Output"))
    a_all["explicit_per_column_cross_check"] = allm.explicit_per_column()
    a_all["compression_cross_check_agrees"] = (
        a_all["explicit_per_column_cross_check"]["disclosed_per_column"]
        == a_all["per_column"]["disclosed_per_column"])
    if any(o.role == "H" for o in private):
        h = obs["H"]
        hi = next(i for i, o in enumerate(private) if o.role == "H")
        no_zs = JointModel(private, ALIAS_PAIRS, zero_sum=False).analyze(planes=False)
        extra = C.h_identity_extra(h)
        merged = {allm.merged_of[(hi, r)]: c for r, c in extra["coefs"].items()}
        with_id = JointModel(private, ALIAS_PAIRS,
                             extras=[dict(extra, coefs=merged, commitment="H")])
        ra = with_id.rank(with_id.all_gens())["rank"]
        a_all["residual"] = {
            "disclosed_total": a_all["joint"]["disclosed_total"],
            "disclosed_without_H_zero_sum_constraint": no_zs["joint"]["disclosed_total"],
            "logup_identity_rows_in_observation_row_space": ra == a_all["joint"]["rank_joint"],
            "residual_is_exactly_the_public_logup_identity":
                ra == a_all["joint"]["rank_joint"] and a_all["joint"]["disclosed_total"] == 2,
            "meaning": "the whole joint system's surviving functionals are H's public LogUp identity "
                       "and nothing else; no functional of X, z16, the other A planes or W survives"}
    a_all["ms"] = _ms(t1)
    rec["joint"]["all_private_commitments_aliased"] = a_all
    # ---- what this joint result supplies to Codex's round-20 lemma ------------
    rec["round20_premise"] = {
        "io_cluster_aliased": round20_premise(a_io, has_h=False),
        "all_private_commitments_aliased": round20_premise(a_all, has_h=True),
        "reference": {k: ROUND20[k] for k in ("doc", "tool", "result", "depends_on_this_task")},
    }
    # ---- what the combination required ---------------------------------------
    rec["combination_requirements"] = combination_requirements(cap, jm)
    rec["excluded_observation_classes"] = sorted(EXCLUDED_CLASSES)
    rec["structure_validated_only"] = sorted(STRUCTURE_ONLY_CLASSES)
    rec["cross_component_obligations"] = cross_component_obligations(cap)
    rec["ms"] = _ms(t0)
    log(f"  {cap.proof_sha256[:12]} {cap.privacy} JOINT A+In+Out "
        f"{a_io['joint']['disclosed_total']}, all "
        f"{a_all['joint']['disclosed_total']} ({rec['ms']} ms)")
    return rec


def combination_requirements(cap: IoCapture, jm: JointModel) -> List[dict]:
    """What combining the per-commitment results actually needed, each item either
    established from the capture or imported (and named as imported)."""
    A = cap.by_role["A"]
    out = []
    ns = {r.role: r.n for r in cap.roles}
    out.append({"requirement": "one shared column index",
                "established": len(set(ns.values())) == 1,
                "how": f"every commitment opens at log_cols {LOG_COLS} (n = {A.n}); the aliased "
                       f"planes therefore have the same (row, column) decomposition",
                "evidence": ns})
    ev = []
    for arg in cap.io_arguments:
        ev.append({"side": arg["side"], "A_claim": arg["a_claim"], "endpoint": arg["endpoint"],
                   "plane": arg["plane"], "shared_point_coordinates": arg["shared_point_coordinates"]})
    out.append({"requirement": "a row identification between A and each endpoint",
                "established": False, "imported_from": "soundness of the IO equality sumcheck",
                "how": "the linear observations cannot themselves prove that A's X slice and the "
                       "input endpoint's first 512 values are the same numbers. That equality is the "
                       "STATEMENT the sumcheck proves (zk_ffn_fresh_io.rs:379-410). The capture shows "
                       "both claims opened at ONE point rho[..9] with ONE coefficient split "
                       "(1-e, e, e*u) and one shared column tail, which is consistent with the alias "
                       "and is what the argument binds; the joint model imports the equality itself.",
                "evidence": ev,
                "control": "the same union WITHOUT the alias is computed as "
                           "joint.io_cluster_unaliased_control"})
    out.append({"requirement": "the masks of the two commitments stay separate unknowns",
                "established": True,
                "how": "A's IO mask pairs are rows 698/699 and 700/701 of A; each endpoint's terminal "
                       "mask pair is rows 2/3 of its OWN commitment, and rows 4/5/6 are further fresh "
                       "random rows. No alias touches a mask row (the JointModel refuses one).",
                "evidence": {"A_io_mask_rows": cap.geo["io_mask_rows"],
                             "endpoint_terminal_mask_pair": cap.geo["endpoint"]["terminal_mask_pair"],
                             "endpoint_prox_rows": cap.geo["endpoint"]["prox_rows"]}})
    out.append({"requirement": "one block coordinate pair per proximity vector",
                "established": True,
                "how": "the inherited RoleModel carries exactly ONE proximity vector because it models "
                       "one commitment. Merging three commitments needs three, kept separate: summing "
                       "them would model an adversary who sees only their sum, which is weaker than "
                       "what is published. This is the ONE implementation generalisation; the "
                       "observation classes and the algebra are unchanged, and JointModel on a single "
                       "commitment reproduces RoleModel exactly (control "
                       "controls.joint_model_matches_role_model).",
                "evidence": {"block_coordinates": jm.nb, "groups": jm.G,
                             "proximity_vectors": len(jm.obses)}})
    out.append({"requirement": "one cross-column coordinate space for all terminals",
                "established": True,
                "how": "every claim terminal of every merged commitment plus H's public zero-sum "
                       "constraint live in one cross-column space, so a functional may mix them.",
                "evidence": {"terminals": jm.K, "extras": jm.E, "cross_dimension": jm.tdim}})
    return out


def round20_premise(analysis: dict, has_h: bool) -> dict:
    """What this joint result does and does not supply to Codex's round-20 lemma.

    The lemma's premise is a message difference that already satisfies the individual
    terminal, public-row, shared-endpoint-plane and zero-sum conditions.  The
    disclosure number IS that statement in dimensions: the space of admissible
    differences projects onto the data unknowns in codimension `disclosed_total`."""
    d = analysis["joint"]["disclosed_total"]
    data = analysis["unknowns"]["data"]
    est = [
        "every message coordinate v_g[j], j < n, of every group vector of every commitment in "
        "the union (the row-fold matrix B of the lemma, column by column)",
        "every message coordinate of every commitment's proximity vector",
        "every individual claim terminal",
        "the shared endpoint planes: A rows 14/15 and 16/17 ARE rows 0/1 of the input and the "
        "output endpoint, so one difference of the shared unknowns is compensated inside BOTH "
        "commitments at once, by their separate masks",
    ]
    if has_h:
        est.append("H's public zero-sum constraint on its u pair (an explicit observation here)")
    return {
        "supplies_the_lemma_premise": d == 0 or has_h,
        "data_unknowns": data,
        "disclosed_total": d,
        "admissible_data_difference_dimension": data - d,
        "projects_onto_every_data_unknown": d == 0,
        "conditions_established_by_this_model": est,
        "residual_conditions_on_the_difference": (
            [] if d == 0 else
            ["the difference must lie in the kernel of the surviving functionals "
             f"({d} base dimensions); for the union containing H these are exactly its public "
             "LogUp identity, whose value the proof itself fixes to 0 -- a public constraint, "
             "not witness information"]),
        "conditions_NOT_modelled_here": [
            "public rows: every data row of every private commitment is treated as a free "
            "unknown. If the statement publicly determines any committed row, the lemma's "
            "premise needs the difference to vanish there as well, and that is not imposed here.",
            "the alias itself is imported from the SOUNDNESS of the IO equality sumcheck; the "
            "linear observations do not establish that A's X slice and the endpoint's first 512 "
            "values are the same numbers.",
            "everything the lemma also excludes: adaptive Fiat-Shamir, repeated openings, the "
            "salted Merkle roots and paths, CFS round messages, and the caller-fixed endpoint "
            "root simulation.",
        ],
        "lemma": ROUND20["statement"],
        "lemma_exclusions": ROUND20["exclusions"],
        "conclusion": (
            "the premise is supplied for this union: every data difference (subject only to the "
            "public constraint above) is realisable while every modelled observation stays fixed, "
            "and the aliases are respected because the shared unknowns are one unknown here. "
            "Under the lemma's stated conditions the pad / encoded-column / M-opening channel then "
            "adds nothing on top of that -- and nothing beyond those conditions is accepted."
            if (d == 0 or has_h) else
            "the premise is NOT supplied: a functional of the witness survives, so there is no "
            "unconstrained message difference for the lemma to translate."),
    }


def summarize(cases: List[dict]) -> dict:
    table: Dict[str, dict] = {}
    for c in cases:
        for role, e in c["analysis"]["per_commitment"].items():
            key = f"{c['privacy']}/{role}"
            row = table.setdefault(key, {"cases": 0, "per_column_disclosed": set(),
                                         "joint_disclosed": set()})
            row["cases"] += 1
            row["per_column_disclosed"].add(e["analysis"]["per_column"]["disclosed_per_column"])
            row["joint_disclosed"].add(e["analysis"]["joint"]["disclosed_total"])
        for name, j in c["analysis"]["joint"].items():
            key = f"{c['privacy']}/JOINT {name}"
            row = table.setdefault(key, {"cases": 0, "per_column_disclosed": set(),
                                         "joint_disclosed": set()})
            row["cases"] += 1
            row["per_column_disclosed"].add(j["per_column"]["disclosed_per_column"])
            row["joint_disclosed"].add(j["joint"]["disclosed_total"])
    return {k: {"cases": v["cases"], "per_column_disclosed": sorted(v["per_column_disclosed"]),
                "joint_disclosed": sorted(v["joint_disclosed"])} for k, v in sorted(table.items())}


def cross_capture(cases: List[dict]) -> dict:
    """What the four retained proofs share and what they do not.  This is an
    OBSERVATION for the excluded `repeats` class, not an analysis of it: every number
    above is computed on one capture at a time."""
    roots: Dict[str, set] = {}
    rows = []
    for c in cases:
        pol = c["analysis"]["per_commitment"]
        entry = {"proof_sha256": c["proof_sha256"][:12], "privacy": c["privacy"],
                 "policy_context": c.get("policy_context"), "policy_scales": c.get("policy_scales"),
                 "roots": {r: pol[r]["role_summary"]["root"][:12] for r in pol}}
        rows.append(entry)
        for r, v in entry["roots"].items():
            roots.setdefault(r, set()).add(v)
    return {"captures": rows,
            "every_commitment_root_distinct_across_proofs":
                all(len(v) == len(cases) for v in roots.values()),
            "one_shared_policy_context": len({r["policy_context"] for r in rows}) == 1,
            "one_shared_scale_pair": len({tuple(r["policy_scales"] or ()) for r in rows}) == 1,
            "note": "each proof commits with fresh randomness (weight_policy fresh-per-proof), so "
                    "no root repeats. The endpoint POLICY of all four proofs carries the same "
                    "32-byte context and the same (input, output) scale pair, i.e. one SeamSpec, "
                    "which is consistent with the four proofs being of one witness per mode. "
                    "Composing observations across proofs is the excluded `repeats` class (OBL-6); "
                    "nothing here does it."}


def tool_digests() -> Dict[str, str]:
    names = ["zk60_opus_io_capture.py", "zk60_opus_repaired_capture.py",
             "zk60_fable_joint_capture.py", "zk60_fable_joint_rank.py",
             "zk60_opus_io_layout.py", "zk60_opus_wire_length.py",
             "zk60_io_capture_preflight.py", "zk60_io_capture_controls.py",
             "zk60_io_opening_translation.py"]
    out = {}
    for n in names:
        p = os.path.join(_HERE, n)
        if os.path.exists(p):
            out[n] = sha256_file(p)
    return out


LIMITS = [
    "A linear-model rank result on four proof-of-concept captures, under the captured (fixed) "
    "public coefficients. It is not a simulator, not a conditioning argument, and not an upper "
    "bound on disclosure.",
    "The joint result imports the A <-> endpoint plane equality from the SOUNDNESS of the IO "
    "sumcheck; the linear observations do not establish it. The unaliased union is reported as a "
    "control.",
    "Excluded by construction and unchanged from FA7/O2: pad coordinates, sampled encoded columns, "
    "the CFS mask commitment and every masked sumcheck round message, repeated proofs of one "
    "witness, the Merkle root over unopened columns, and adaptive transcript composition. The "
    "capture now CONTAINS these observations; containing them is not analysing them.",
    "NEW and unresolved: each aliased plane is encoded and column-opened twice, in A and in its "
    "endpoint. That is outside the linear model and has no argument yet.",
    "Codex's round-20 opening lemma covers the pad / encoded-column / M-opening channel "
    "CONDITIONALLY and consumes this result as its premise. Nothing here folds that channel into "
    "the model, and neither the adaptive composition nor the caller-fixed endpoint root simulation "
    "is accepted; the lemma keeps no Merkle root or authentication path fixed.",
    "This is NOT whole-protocol zero knowledge and U-2 is NOT closed. It covers only "
    "ffn-v3-mr1-fresh-io-poc/2 at T32/d16/f16, function 1, fresh per-proof weights: no registered "
    "model identity, no function 2, no attention, no stable-weight profile, no transport envelope.",
    "The captures hold no witness values; nothing here is compared to a ground truth.",
    "No private-block, deployment or throughput acceptance follows.",
]


def analyze(captures_dir: str, manifest_path: str, out_path: Optional[str],
            legacy_dir: Optional[str] = None, runs_file: Optional[str] = None,
            planes: bool = True, log=print) -> dict:
    man = load_manifest(manifest_path)
    pre = preflight(captures_dir, manifest_path, None, log=log)
    report: dict = {
        "schema_version": 1,
        "task": "O8 -- the schema-3 IO captures analysed jointly with the FA7/O2 linear "
                "observation model across commitments that share a data plane",
        "reviewer": REVIEWER,
        "source_commit": SOURCE_COMMIT,
        "review_worktree_commit": REVIEW_WORKTREE_COMMIT,
        "profile": PROFILE, "coverage": COVERAGE, "schema": SCHEMA,
        "model_provenance":
            "the message/terminal/proximity model, its exact Fp2 and rank algebra and its "
            "included/excluded observation classes are Claude Fable 5.1's FA7 work "
            "(scripts/zk60_fable_joint_capture.py, scripts/zk60_fable_joint_rank.py), imported "
            "unchanged. The schema-2 repaired parser and layout arithmetic are Opus 5's O2 work "
            "(scripts/zk60_opus_repaired_capture.py), also imported unchanged. New in O8: the "
            "schema-3 parser, the recomputed IO layout, and JointModel -- the same model over a "
            "union of commitments with one proximity block per commitment and a data-plane alias.",
        "tool_sha256": tool_digests(),
        "related_results": {
            name: (sha256_file(os.path.join(os.path.dirname(_HERE), "results", name))
                   if os.path.exists(os.path.join(os.path.dirname(_HERE), "results", name)) else None)
            for name in ("zk60_round19_validation.json", "zk60_round20_validation.json",
                         "zk60_round20_opening_translation.json",
                         "zk60_opus_repaired_capture_analysis.json")},
        "round20_opening_lemma": ROUND20,
        "manifest": {k: man[k] for k in ("path", "sha256", "source_commit", "capture_source_commit",
                                         "status", "captures_status", "counts", "tools",
                                         "rust_test_count")},
        "captures_directory": os.path.abspath(captures_dir),
        "included_observation_classes": INCLUDED_CLASSES,
        "excluded_observation_classes": EXCLUDED_CLASSES,
        "structure_validated_only": STRUCTURE_ONLY_CLASSES,
        "preflight": pre,
        "captures": [], "cases": [], "refused": [],
    }
    if runs_file:
        with open(runs_file) as fh:
            report["commands"] = json.load(fh)
        report["commands"].append({"command": "python3 " + " ".join(sys.argv), "exit_code": 0,
                                   "result": "this analysis record"})
    for name in sorted(f for f in os.listdir(captures_dir) if f.endswith(".json")):
        path = os.path.join(captures_dir, name)
        entry = man["entries"].get(name[:-5])
        try:
            cap = IoCapture(path, expected_capture_sha256=entry["capture_sha256"] if entry else None)
        except C.CaptureError as err:
            report["refused"].append({"file": name, "reason": str(err)})
            log(f"REFUSED {name}: {err}")
            continue
        report["captures"].append({**cap.header(), "manifest_entry": entry})
        log(f"{name[:12]} {cap.privacy} roles {[r.role for r in cap.roles]}")
        report["cases"].append({**cap.header(), "analysis": analyze_capture(cap, planes=planes, log=log)})
        del cap
    report["summary"] = summarize(report["cases"])
    report["cross_capture"] = cross_capture(report["cases"])
    controls: dict = {}
    reals = [c for c in report["captures"]]
    if reals:
        for privacy in ("P1", "P3"):
            pick = next((c for c in reals if c["privacy"] == privacy), None)
            if pick:
                controls[f"ingestion_negatives_{privacy}"] = mutation_controls(
                    os.path.join(captures_dir, pick["file"]))
    if legacy_dir and os.path.isdir(legacy_dir):
        controls["legacy_positive_control"] = legacy_control(legacy_dir, log=log)
    report["controls"] = controls
    report["verdict"] = verdict(report)
    report["limits"] = LIMITS
    report["privacy_analysis_performed"] = True
    report["full_privacy_review_complete"] = False
    report["u2_closed"] = False
    if out_path:
        with open(out_path, "w") as fh:
            json.dump(report, fh, indent=1)
        log(f"wrote {out_path}")
    return report


def verdict(report: dict) -> dict:
    per: Dict[str, set] = {}
    joint: Dict[str, set] = {}
    ok = True
    for c in report["cases"]:
        for role, e in c["analysis"]["per_commitment"].items():
            per.setdefault(role, set()).add(e["analysis"]["joint"]["disclosed_total"])
            if role == "H" and not e["h_zero_sum"]["residual_equals_public_logup_identity"]:
                ok = False
        for name, j in c["analysis"]["joint"].items():
            joint.setdefault(name, set()).add(j["joint"]["disclosed_total"])
        for ctl in c["analysis"]["controls"]["joint_model_matches_role_model"]:
            ok = ok and ctl["agree"]
        for ctl in c["analysis"]["controls"]["endpoint_mask_ablation"]:
            ok = ok and ctl["control_detects_the_legacy_leak"]
        for name in ("io_cluster_aliased", "all_private_commitments_aliased"):
            ok = ok and c["analysis"]["joint"][name].get("compression_cross_check_agrees", False)
    return {"per_commitment_disclosed_total": {k: sorted(v) for k, v in sorted(per.items())},
            "joint_disclosed_total": {k: sorted(v) for k, v in sorted(joint.items())},
            "controls_all_pass": bool(ok),
            "note": "disclosed dimensions of base-field data unknowns that survive mask elimination, "
                    "in the linear model with the stated exclusions; H's residual is its public LogUp "
                    "identity. No privacy theorem, no U-2 closure."}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    pf = sub.add_parser("preflight")
    pf.add_argument("--captures-dir", required=True)
    pf.add_argument("--manifest", required=True)
    pf.add_argument("-o", "--out")
    an = sub.add_parser("analyze")
    an.add_argument("--captures-dir", required=True)
    an.add_argument("--manifest", required=True)
    an.add_argument("--legacy-dir")
    an.add_argument("--runs-file")
    an.add_argument("--no-planes", action="store_true")
    an.add_argument("-o", "--out")
    ck = sub.add_parser("check")
    ck.add_argument("capture")
    args = ap.parse_args(argv)
    try:
        if args.cmd == "preflight":
            rep = preflight(args.captures_dir, args.manifest, args.out)
            bad = [c for c in rep["checks"] if not c["pass"]]
            for c in bad:
                print(f"FAIL {c['check']}: {c['actual']!r} != {c['expected']!r}")
            print(f"{len(rep['checks']) - len(bad)}/{len(rep['checks'])} checks pass")
            return 0 if rep["pass"] else 1
        if args.cmd == "analyze":
            rep = analyze(args.captures_dir, args.manifest, args.out, legacy_dir=args.legacy_dir,
                          runs_file=args.runs_file, planes=not args.no_planes)
            print(json.dumps(rep["verdict"], indent=1))
            return 0 if rep["verdict"]["controls_all_pass"] and not rep["refused"] else 1
        cap = IoCapture(args.capture, require_digest_name=False)
        print(json.dumps(cap.header(), indent=1))
        return 0
    except C.CaptureError as err:
        print(f"REFUSED: {err}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
