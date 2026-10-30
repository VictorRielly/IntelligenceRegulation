#!/usr/bin/env python3
"""[v17, gate round 14] EACH STAGE'S CALIBRATION in a native run bundle.

Native R8 (R6 for sh_s) lets a layer carry its own calibration constants: the
run proves that block's stage at `Shape::with_layer_calibration(apply_own(
base, own))` (R9 `run.rs` `stage_shape`, :547-554), and says so in that
stage's schedule line, one clause per constant in the canonical order of
`trained_statement.rs` `OWN_FIELDS` (:381-393):

    "; {label} {v} (the layer's own; the run's is {b})"    (run.rs :525-541)

The schedule digest the run header absorbs is

    blake3("hashline/private-run-schedule/1" + length-framed lines:
           parameter_line, layout_description..., stage_lines...)
                                                       (run.rs :572-587)

and the gate's replay absorbs `run.json["schedule_digest"]` as bytes, so the
replayed challenges bind the DIGEST.  This module binds the LINES to it:
before any stage is evaluated at a calibration other than the run shape's,
the digest is recomputed from run.json's own lines and must equal
run.json's `schedule_digest`.

`stage_shapes(run)` returns one shape dict per stage: the run shape itself
(the same object) where the stage's line carries no own clause, else a copy
with the clause's values and `d_max` / `norm_wrho` re-derived exactly as
`NormCalibration::derive_at_width` (shape.rs :273-311).  Each refusal is a
`ValueError` with its reason:

  SC-1  a clause whose run value is not the run shape's value;
  SC-2  a clause whose own value equals the run's (one encoding per
        statement, trained_statement.rs :367);
  SC-3  clauses out of the canonical order, or one field twice;
  SC-4  text after "data rows N" that is not exactly the parsed clauses;
  SC-5  an own clause in a bundle whose recomputed schedule digest is not
        run.json's (or cannot be recomputed);
  SC-6  a clause in a bundle that declares no trained calibration;
  SC-7  a re-derived window outside the plane list's four norm limbs
        (25..=32 bits), or D_max outside the three isqrt limbs.

At a bundle whose lines carry no own clause nothing here changes any figure:
every stage is the run shape.  A token-I/O run (`"token_io"` in run.json) is
not read here: its block stages reach the port through tokenblocks' per-block
shim, each at its block's calibration, and `stage_shapes` returns no shape.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import math
import re

# `trained_statement.rs:381-393` (R9 tree): (shape key, stage-line label)
OWN_FIELDS = (("sh_s", "score shift"), ("norm_tn", "norm tn"),
              ("norm_cn_a", "norm cn_a"), ("norm_cn_m", "norm cn_m"),
              ("norm_ceps", "norm ceps"), ("sh_ao", "ao shift"),
              ("sh_qkv", "qkv shift"), ("sh_o", "o shift"), ("sh_g", "gate shift"),
              ("sh_h", "product shift"), ("sh_z", "down shift"))
LABEL_KEY = {lab: k for k, lab in OWN_FIELDS}
ORDER = {k: i for i, (k, _lab) in enumerate(OWN_FIELDS)}
OWN_CLAUSE = re.compile(r"; (" + "|".join(re.escape(lab) for _k, lab in OWN_FIELDS)
                        + r") (-?\d+) \(the layer's own; the run's is (-?\d+)\)")
DATA_ROWS = re.compile(r"; data rows \d+")
SCHEDULE_DOMAIN = b"hashline/private-run-schedule/1"
INT16_ABS = 32768
LIMBS_ISQRT = 3


def schedule_digest(run: dict) -> dict:
    """run.rs `schedule_digest`, recomputed from run.json's own lines"""
    out = {"what": "blake3('hashline/private-run-schedule/1' + length-framed "
           "parameter_line, layout_description, stage_lines), run.rs:572-587"}
    try:
        import blake3
        h = blake3.blake3()
        h.update(SCHEDULE_DOMAIN)
        for s in [run["parameter_line"]] + list(run["layout_description"]) + list(run["stage_lines"]):
            bs = s.encode()
            h.update(len(bs).to_bytes(8, "little"))
            h.update(bs)
        out["recomputed"] = h.hexdigest()
        out["run_json"] = bytes(run["schedule_digest"]).hex()
        out["equal"] = out["recomputed"] == out["run_json"]
    except Exception as exc:  # noqa: BLE001
        out["equal"] = False
        out["error"] = f"{type(exc).__name__}: {exc}"
    return out


def derive(sh: dict) -> tuple[int, int]:
    """`NormCalibration::derive_at_width` (shape.rs:296-311): (d_max, wrho)"""
    d_max = math.isqrt(int(sh["norm_ceps"]) + int(sh["width"]) * INT16_ABS * INT16_ABS)
    wrho = int(sh["norm_tn"]) + 1 + d_max.bit_length()
    return d_max, wrho


def own_clauses(line: str) -> list[tuple[str, int, int]]:
    """(key, own value, run value) per clause, after SC-3 / SC-4"""
    m = DATA_ROWS.search(line)
    if not m:
        raise ValueError(f"SC-4: the stage line has no 'data rows' field: {line!r}")
    tail = line[m.end():]
    got = OWN_CLAUSE.findall(tail)
    rebuilt = "".join(f"; {lab} {v} (the layer's own; the run's is {b})" for lab, v, b in got)
    if rebuilt != tail:
        raise ValueError(f"SC-4: the stage line's text after 'data rows' is not exactly "
                         f"its own clauses: {tail!r}")
    keys = [LABEL_KEY[lab] for lab, _v, _b in got]
    if len(set(keys)) != len(keys) or keys != sorted(keys, key=ORDER.get):
        raise ValueError(f"SC-3: own clauses out of the canonical OWN_FIELDS order or "
                         f"repeated: {keys}")
    return [(LABEL_KEY[lab], int(v), int(b)) for lab, v, b in got]


def stage_shapes(run: dict) -> tuple[list, dict]:
    """(one shape dict per stage, a record of what was read)"""
    sh = run["shape"]
    lines = list(run.get("stage_lines") or [])
    rec = {"stage_lines": len(lines), "stages_at_their_own_calibration": [],
           "own_clauses": {}, "schedule_digest": None}
    if "token_io" in run or "classify" in run:
        # a token-I/O run: its block stages reach the terminals port through
        # `zk60_native_rg_tokenblocks.TokenBlockShim`, one shim per block at
        # that block's calibration (X6 reads the clauses); nothing here
        rec["not_applied"] = ("a token-I/O or classifier run [v20]: each block stage's calibration "
                              "is carried by the per-block shim (tokenblocks / classgate)")
        return [], rec
    parsed = [own_clauses(ln) for ln in lines]
    any_own = any(parsed)
    dig = schedule_digest(run) if lines else {"equal": None, "why": "no stage lines"}
    rec["schedule_digest"] = dig
    if any_own:
        if sh.get("trained_calibration") is not True:
            raise ValueError("SC-6: own calibration clauses in a bundle that declares "
                             "no trained calibration")
        if not dig.get("equal"):
            raise ValueError("SC-5: a stage line carries own calibration clauses and the "
                             "schedule digest recomputed from run.json's lines is not "
                             f"run.json's schedule_digest ({dig})")
    shapes = []
    for k, cl in enumerate(parsed):
        if not cl:
            shapes.append(sh)
            continue
        s = dict(sh)
        for key, v, b in cl:
            if int(sh[key]) != b:
                raise ValueError(f"SC-1: stage {k}'s line says the run's {key} is {b}, "
                                 f"the run shape {sh[key]}")
            if v == b:
                raise ValueError(f"SC-2: stage {k}'s own {key} equals the run's ({v})")
            s[key] = v
        d_max, wrho = derive(s)
        if not (25 <= wrho <= 32) or 2 * d_max >= (1 << (8 * LIMBS_ISQRT)):
            raise ValueError(f"SC-7: stage {k}'s calibration derives window {wrho} bits / "
                             f"D_max {d_max}, outside the plane list's limbs")
        s["d_max"], s["norm_wrho"] = d_max, wrho
        shapes.append(s)
        rec["stages_at_their_own_calibration"].append(k)
        rec["own_clauses"][str(k)] = {key: {"own": v, "run": b} for key, v, b in cl}
    if lines:
        d0, w0 = derive(sh) if sh.get("trained_calibration") is True else (None, None)
        rec["run_shape_derivation_equal"] = (d0 is None or (d0 == sh.get("d_max") and w0 == sh.get("norm_wrho")))
    return shapes, rec
