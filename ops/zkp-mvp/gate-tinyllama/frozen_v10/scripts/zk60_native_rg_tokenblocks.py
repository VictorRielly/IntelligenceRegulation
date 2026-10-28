#!/usr/bin/env python3
"""[GATE, token block terminals adapter, 2026-10-19] The gate's frozen
BLOCK-STAGE TERMINAL IDENTITY (stage 8, `zk60_native_rg_terminals.
check_terminals`) run on the L block stages INSIDE a token-I/O run capture
(schema `hashline-native-capture/6-token-run`), through a shim.  The port is
not changed; this module only presents each block stage in the form the port
reads, with the calibration that stage was proved at, and records how.

    python3 zk60_native_rg_tokenblocks.py --bundle <token capture dir> \
        --evidence <dir> --name <name> [--export <dir>] [--no-controls] \
        [--control-constant sh_z]

The export is taken from the bundle's README (`export `<dir>` (variant V)`);
`--export` only overrides it, and a disagreement is a finding.

WHAT THE PORT DEPENDS ON, AND WHAT THE SHIM MAPS  ([MINE], by reading
`zk60_native_rg_terminals.check_terminals`, `TerminalGate`,
`zk60_native_rg_planes.PlaneIndex` and `zk60_native_rg_gqa.GroupFactors`):

* the STAGE INDEX only as a key: `docs[st.index]`, `replay.stages[st.index]`
  and `GroupFactors.point(st.index, slot)`; and `bundle.blocks` as the stage
  count (`slot_checks_expected = 23 * blocks`).  A token run's block k is
  token stage k + 1 (READ, `token_io/run.rs:725-808`).  The port is run ONCE
  PER BLOCK STAGE on a one-stage shim (block k as stage 0, `blocks = 1`, a
  replay view whose `stages[0]` is the token replay's `stages[k + 1]`),
  because a block stage's calibration may be its LAYER'S OWN (below) and the
  port reads one calibration per bundle.  Nothing in `check_terminals` is
  cross-stage, so this is the same check.  Every record is translated back to
  TOKEN stage numbers.
* EXTERNAL ENDPOINTS and BOUNDARY NUMBERING: nothing.  None of the three
  modules reads `bundle.boundary(...)`, `internal_boundaries` or a
  `commitment_kind`.  Slots 21 / 22 (`SC_IO_IN` / `SC_IO_OUT`) are
  `eq * (A_X - IO)`, the same polynomial whether the IO table is an external
  endpoint or an internal boundary (the port's own `_io` docstring), and
  `PlaneIndex` only requires the IO private tables' roles to be `Input` /
  `Output`, which a token block stage's are.  The shim still maps
  `boundary(j)` to token boundary j + 1 and the IO wiring is checked in token
  numbering (block k opens boundary k, commits k + 1); the port reads neither.
* the TRAINED CALIBRATION: `Calibration(run.json["shape"])`.  A token bundle's
  shape carries NO trained-calibration key (the token tree's `run_capture.rs`
  lacks the gate's capture patch: READ, `zk60_native_rg_tokenio_r7c_pins`),
  and `Calibration` then FALLS BACK TO THE FROZEN CONSTANTS without complaint.
  On a trained run that is the wrong polynomial (control NC-2).  Each stage's
  shim shape therefore carries `trained_calibration: true`, the eleven
  constants of THAT stage, and the `norm_wrho` they derive.
* the SOURCE PINS: `check_source_pins` accepts the token bundle's
  `argument.rs`, `layout.rs`, `protocol.rs`, `plane_index.rs` and `pad.rs`
  but NOT its `shape.rs` `8c62519c` (native R8's bytes).  The gate HAS a
  written reading of exactly that digest (`zk60_native_rg_tokenio_r7c_pins.
  TOKEN_R7C_READINGS`, read against `7b0c9742`, which the port accepts;
  `moves_a_block_stage_byte: False`).  The adapter adds that one digest to
  the port's `PINNED_IF_PRESENT` IN MEMORY, only during its own calls, only
  when the bundle pins it and the reading's base is accepted, and removes it
  afterwards.  NC-0 shows the port refuses every slot without it.

THE CALIBRATION OF EACH BLOCK STAGE (READ, token tree `trained_block.rs`
`run_constants` / `load_layer_mode`, `trained_statement.rs` `OWN_FIELDS`,
`apply_own`; `token_io/run.rs` `TokenRunStatement::new`, `stage_shape`):
a stage is proved at its layer's manifest constants.  Keys the export lists
in `per_layer_constants_differ` (null in `profile_constants`) may differ per
layer; every other key equals the profile's.  The RUN's calibration (the
shape the layout description prints) is the profile's, with each per-layer
field set to the value tuple most of the run's layers carry (ties: the
smallest, fields in `OWN_FIELDS` order); a layer that differs is proved at
`with_layer_calibration` of its own values and its stage line says so.

  source  the export (from the README): profile.json `profile_constants`, and
          the stage's layer `manifest.json` `constants` for the per-layer keys.
  X0  which trained keys the bundle's own shape carries (none: the known gap).
  X1  the bundle's `layout_description` calibration and feed-forward lines
      (block `Layout::describe()`, hashed into the schedule digest) against
      the RUN calibration, its derived `wrho` / `D_max`, and the port's frozen
      literals (`F_P`, `SH_ROPE`, `MASK_SCORE`, residual 0, up 0).
  X2  the token schedule digest RECOMPUTED from run.json's own lines (blake3
      "hashline/token-io-run-schedule/v1" over the parameter line, the block
      layout description, stage IN / OUT layouts and the stage lines, each
      length-framed; READ, `token_io/run.rs` `schedule_digest`) equals
      `run.json["schedule_digest"]`, which the token replay absorbs to
      reproduce `run_binding`: the X1 and X6 lines are transcript-bound.
  X3  the absorbed parameter line's `sh-g{g}-u{u}-h{h}-z{z}`.
  X4  the shape's `f_e`, `tokens`, `norm_wrho`, `wrho_s` against the RUN
      calibration's derivation (`D_max = isqrt(ceps + width * 32768^2)`,
      `wrho = tn + 1 + bits(D_max)`, `wrho_s = clog2(T) + f_e`; READ, token
      tree `shape.rs:238-278`, :644-646) and their window rules.
  X5  every stage's and the run's constants inside their classes
      (`zk60_native_rg_tlcontrols.WINDOWS`).
  X6  each block stage line's "(the layer's own; the run's is b)" clauses
      equal exactly the fields where that stage's layer differs from the run
      calibration (none, when no field is per layer).
  X7  the export constants the port hard-codes: `f_p`, `sh_rope`, `f_ro`,
      `sh_u`, `sh_r2`.
  X8  every export layer's `manifest.json` hashes to profile.json's
      `manifest_sha256`, its arrays to the manifest's digests, and its
      constants equal the profile's on every non-per-layer key.
  X9  (after the identity) the exp and SiLU tables the port RECOVERED from
      each stage's slot 19 equal its layer's `exp.bin` / `act.bin`
      (`zk60_native_rg_exportcheck` E4's rule), `exp[0] = 2^f_e`,
      `act[128] = 0`.
  X10 (BEFORE the identity, it chooses the layer) each block stage's captured
      norm gains (slot 14's `gamma_a`, `gamma_m`) equal exactly one export
      layer's `gamma_a.bin` / `gamma_m.bin`: the stage-to-layer map, from the
      capture, compared with the README's declared layer range.

NOT reproduced: the absorbed `calibration` word, the only place a token
bundle binds the export's profile digest (blake3 over the trained-model
statement identity -- `trained_statement.rs:665-755`, whose encoding includes
`export-profile-sha256` among some forty fields, per-layer word / table /
source-tensor digests among them -- and the token profile digest).  No bundle
or export file carries that statement in a form this module can recompute.

CONTROLS (each perturbs an in-memory copy; no captured byte is touched):

  NC-0  the shape.rs reading NOT added: the port refuses before any slot.
  NC-1  one calibration constant moved by one inside its class (TL-2's rule,
        `_step`), in every stage: exactly the slots `READS[name]` names stop
        matching, in every stage -- predicted from `READS`.
  NC-2  the port's own fallback (the shape as written -> FROZEN): exactly the
        union of `READS` over the constants where frozen and the stage's
        calibration differ, in every stage.
  NC-3  the X-checks on a run calibration with one constant moved: X1 fires.
  NC-4  (L >= 2) TL-4's rule: the first adjacent stage pair whose captured
        lookup tables differ; stage k's carried table (values and digest)
        replaced by stage j's, one table at a time: exactly stage k's slot 19
        stops matching.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import argparse
import collections
import contextlib
import copy
import hashlib
import json
import math
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_terminals as T  # noqa: E402
import zk60_native_rg_tokengate as TG  # noqa: E402
import zk60_native_rg_tokenio_r7c_pins as TP  # noqa: E402
from zk60_native_jv_field import P, f2_from_list  # noqa: E402
from zk60_native_rg_bundle import Shape  # noqa: E402
from zk60_native_rg_planes import PlaneIndex  # noqa: E402
from zk60_native_rg_tlcontrols import READS, WINDOWS, _step  # noqa: E402

SHAPE_RS = "src/private_block/shape.rs"
CAL_KEYS = T.TRAINED_KEYS            # the eleven `Calibration` reads
INT16_ABS = 32768                    # token tree shape.rs:105
LIMBS_ISQRT = 3
GAMMA_SLOT, TAB_SLOT = 14, 19
# `trained_statement.rs:381-393`: (key, stage-line label), canonical order
OWN_FIELDS = (("sh_s", "score shift"), ("norm_tn", "norm tn"),
              ("norm_cn_a", "norm cn_a"), ("norm_cn_m", "norm cn_m"),
              ("norm_ceps", "norm ceps"), ("sh_ao", "ao shift"),
              ("sh_qkv", "qkv shift"), ("sh_o", "o shift"), ("sh_g", "gate shift"),
              ("sh_h", "product shift"), ("sh_z", "down shift"))
OWN_CLAUSE = re.compile(r"; (" + "|".join(re.escape(lab) for _k, lab in OWN_FIELDS)
                        + r") (-?\d+) \(the layer's own; the run's is (-?\d+)\)")

CAL_LINE = re.compile(
    r"^calibration: trained norm tn=(?P<tn>\d+) cn_a=(?P<cn_a>\d+) "
    r"cn_m=(?P<cn_m>\d+) ceps=(?P<ceps>\d+) ao=(?P<ao>\d+) qkv=(?P<qkv>\d+) "
    r"score=(?P<score>\d+) o=(?P<o>\d+) gate=(?P<gate>\d+) "
    r"product=(?P<product>\d+) down=(?P<down>\d+) wrho=(?P<wrho>\d+) "
    r"dmax=(?P<dmax>\d+) int16-endpoint=(?P<i16>\d+); shifts qkv=(?P<s_qkv>\d+) "
    r"rope=(?P<s_rope>\d+) score=(?P<s_score>\d+) o=(?P<s_o>\d+) "
    r"ao=(?P<s_ao>\d+) residual=(?P<s_res>\d+); fE=(?P<fe>\d+) fP=(?P<fp>\d+) "
    r"fRo=(?P<fro>\d+) wrhoS=(?P<wrhos>\d+) mask=(?P<mask>-?\d+);")
FF_LINE = re.compile(
    r"^feed-forward: F=(?P<F>\d+) shifts gate=(?P<gate>\d+) up=(?P<up>\d+) "
    r"product=(?P<product>\d+) down=(?P<down>\d+) residual2=(?P<res2>\d+);")
PARAM_SH = re.compile(r"/sh-g(\d+)-u(\d+)-h(\d+)-z(\d+)/")
README_EXPORT = re.compile(r"export `([^`]+)` \(variant ([^)\s]+)\)")
README_LAYERS = re.compile(r"layers (\d+)\.\.(\d+)")
X1_FIELDS = {"norm_tn": "tn", "norm_cn_a": "cn_a", "norm_cn_m": "cn_m",
             "norm_ceps": "ceps", "sh_ao": "ao", "sh_qkv": "qkv", "sh_s": "score",
             "sh_o": "o", "sh_g": "gate", "sh_h": "product", "sh_z": "down"}


def _sha_file(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def _ints(path, width):
    with open(path, "rb") as fh:
        raw = fh.read()
    return [int.from_bytes(raw[i:i + width], "little", signed=True)
            for i in range(0, len(raw), width)]


def _int64_sha(vals):
    """the E4 digest: entries as int64 little-endian (exportcheck `_table_sha`)"""
    return hashlib.sha256(b"".join(int(v).to_bytes(8, "little", signed=True)
                                   for v in vals)).hexdigest()


def _clog2(n):
    return (n - 1).bit_length()


def derive(values: dict, width: int, tokens: int, f_e: int) -> dict:
    """`NormCalibration::derive_at_width` and `wrho_s` (token tree shape.rs)."""
    d_max = math.isqrt(values["norm_ceps"] + width * INT16_ABS * INT16_ABS)
    wrho = values["norm_tn"] + 1 + d_max.bit_length()
    return {"d_max": d_max, "norm_wrho": wrho, "wrho_s": _clog2(tokens) + f_e,
            "d_max_in_three_limbs": 2 * d_max < (1 << (8 * LIMBS_ISQRT)),
            "wrho_is_four_limbs": 25 <= wrho <= 32}


# =====================================================================
#  the export
# =====================================================================
def readme_facts(tb) -> dict:
    path = os.path.join(tb.dir, "README.md")
    text = open(path).read() if os.path.exists(path) else ""
    me, ml = README_EXPORT.search(text), README_LAYERS.search(text)
    layers = None
    if ml and int(ml.group(2)) - int(ml.group(1)) + 1 == tb.l:
        layers = list(range(int(ml.group(1)), int(ml.group(2)) + 1))
    return {"readme": path, "export": me.group(1) if me else None,
            "variant": me.group(2) if me else None, "layers": layers,
            "what": "the capture writer's README text: not transcript-bound; the "
                    "export it names is checked by X1-X10, the layers by X10"}


def load_export(export_dir: str) -> dict:
    """profile.json, and every layer's manifest, constants and small tables
    (X8)."""
    prof_path = os.path.join(export_dir, "profile.json")
    prof = json.load(open(prof_path))
    pc = prof.get("profile_constants") or {}
    per_layer = list(prof.get("per_layer_constants_differ") or [])
    f, rows, layers = [], [], {}
    for ent in prof.get("layers", []):
        d = os.path.join(export_dir, ent["dir"])
        man_path = os.path.join(d, "manifest.json")
        man = json.load(open(man_path))
        cons = man.get("constants", {})
        row = {"layer": ent["layer"],
               "manifest_sha256_matches_profile": _sha_file(man_path) == ent["manifest_sha256"],
               "non_per_layer_constants_differing": [], "arrays_matching_manifest": True}
        if not row["manifest_sha256_matches_profile"]:
            f.append(f"X8: layer {ent['layer']}'s manifest does not hash to profile.json's")
        if man.get("layer") != ent["layer"]:
            f.append(f"X8: layer {ent['layer']}'s manifest says layer {man.get('layer')}")
        for k in CAL_KEYS + ("f_e",):
            if k in per_layer:
                if not isinstance(cons.get(k), int):
                    f.append(f"X8: layer {ent['layer']} carries no integer per-layer {k}")
            elif cons.get(k) != pc.get(k):
                row["non_per_layer_constants_differing"].append(k)
                f.append(f"X8: layer {ent['layer']}'s {k} is {cons.get(k)}, the "
                         f"profile's {pc.get(k)} (and {k} is not per layer)")
        tab = {}
        for name, width in (("exp", 8), ("act", 2), ("gamma_a", 1), ("gamma_m", 1)):
            spec = man["arrays"][name]
            p = os.path.join(d, spec["file"])
            if _sha_file(p) != spec["sha256"]:
                row["arrays_matching_manifest"] = False
                f.append(f"X8: layer {ent['layer']} {spec['file']} does not hash to its manifest")
            tab[name] = _ints(p, width)
        tab["exp_sha"], tab["act_sha"] = _int64_sha(tab["exp"]), _int64_sha(tab["act"])
        layers[ent["layer"]] = {"constants": cons, "tables": tab}
        rows.append(row)
    return {"dir": export_dir, "profile_path": prof_path,
            "profile_sha256": _sha_file(prof_path), "variant": prof.get("variant"),
            "T": prof.get("T"), "pc": pc, "per_layer": per_layer, "layers": layers,
            "X8": {"per_layer": rows, "per_layer_constants_differ": per_layer,
                   "ok": not f}, "findings": f}


def identify_layers(tb, exp, declared) -> dict:
    """X10: each block stage's captured gains against every export layer."""
    width = tb.run["shape"]["width"]
    rows, f = [], []
    for k, st in enumerate([s for s in tb.stages if s.kind == "BLOCK"]):
        pubs = [t for t in st.doc["arguments"][GAMMA_SLOT]["tables"] if t["kind"] == "public"]
        match = []
        if len(pubs) >= 2 and all("values" in t for t in pubs[:2]):
            ga = [f2_from_list(pubs[0]["values"][i]) for i in range(width)]
            gm = [f2_from_list(pubs[1]["values"][i]) for i in range(width)]
            for layer, L_ in exp["layers"].items():
                tab = L_["tables"]
                if (len(tab["gamma_a"]) == width
                        and all(ga[i] == (tab["gamma_a"][i] % P, 0) for i in range(width))
                        and all(gm[i] == (tab["gamma_m"][i] % P, 0) for i in range(width))):
                    match.append(layer)
        dec = declared[k] if declared else None
        ok = len(match) == 1 and (dec is None or match == [dec])
        if not ok:
            f.append(f"X10: token stage {st.index}: gains match layers {match}, the "
                     f"README declares {dec}")
        rows.append({"token_stage": st.index, "block": k,
                     "layers_whose_gamma_a_and_gamma_m_match": match,
                     "layer_declared_by_the_readme": dec,
                     "layer": match[0] if len(match) == 1 else None, "ok": ok})
    return {"per_stage": rows, "findings": f, "ok": not f}


def calibrations(exp, layer_of_stage) -> dict:
    """Each stage's eleven constants and the RUN calibration (module doc)."""
    pc, per_layer = exp["pc"], exp["per_layer"]
    stage_vals = []
    for layer in layer_of_stage:
        cons = exp["layers"][layer]["constants"]
        stage_vals.append({k: int(cons[k]) if k in per_layer else int(pc[k])
                           for k in CAL_KEYS})
    fields = [k for k, _lab in OWN_FIELDS if k in per_layer]
    base = {k: pc[k] for k in CAL_KEYS if k not in per_layer}
    tally = None
    if fields:
        counts = collections.Counter(tuple(v[k] for k in fields) for v in stage_vals)
        best = max(counts.values())
        choice = min(key for key, n in counts.items() if n == best)
        base.update(dict(zip(fields, choice)))
        tally = {",".join(fields): {str(list(key)): n for key, n in sorted(counts.items())}}
    base = {k: int(base[k]) for k in CAL_KEYS}
    return {"stage_values": stage_vals, "run_values": base, "per_layer_fields": fields,
            "run_value_tally": tally,
            "rule": "the profile's constants; each per-layer field the value tuple most "
                    "of the run's layers carry (ties: the smallest), trained_block.rs "
                    "run_constants"}


# =====================================================================
#  the cross-checks
# =====================================================================
def crosscheck(run_vals: dict, stage_vals: list, exp: dict, tb) -> dict:
    sh, run, pc = tb.run["shape"], tb.run, exp["pc"]
    f: list[str] = []
    out: dict = {}
    carried = [k for k in CAL_KEYS + ("trained_calibration", "d_max") if k in sh]
    for k in carried:
        if k in run_vals and sh[k] != run_vals[k]:
            f.append(f"X0: the bundle's shape says {k} = {sh[k]}, the run calibration {run_vals[k]}")
    out["X0_bundle_shape_keys"] = {
        "bundle_shape_carries": carried, "ok": not any(x.startswith("X0") for x in f),
        "known_gap": "the token tree's run_capture.rs lacks the gate's trained-calibration "
                     "capture patch, so the shape names none of them"}
    dv = derive(run_vals, sh["width"], sh["tokens"], pc.get("f_e"))
    # X1
    cal_lines = [s for s in run.get("layout_description", []) if s.startswith("calibration:")]
    ff_lines = [s for s in run.get("layout_description", []) if s.startswith("feed-forward:")]
    x1 = {"calibration_line": cal_lines[0] if cal_lines else None,
          "feed_forward_line": ff_lines[0] if ff_lines else None, "compared": {}}
    m = CAL_LINE.match(cal_lines[0]) if len(cal_lines) == 1 else None
    mf = FF_LINE.match(ff_lines[0]) if len(ff_lines) == 1 else None
    if m is None or mf is None:
        f.append("X1: the layout description does not carry exactly one trained "
                 "calibration line and one feed-forward line in the trained format")
    else:
        g = {k: int(v) for k, v in m.groupdict().items()}
        gf = {k: int(v) for k, v in mf.groupdict().items()}
        pairs = [(k, g[X1_FIELDS[k]], run_vals[k]) for k in CAL_KEYS]
        pairs += [("shifts.qkv", g["s_qkv"], run_vals["sh_qkv"]),
                  ("shifts.score", g["s_score"], run_vals["sh_s"]),
                  ("shifts.o", g["s_o"], run_vals["sh_o"]),
                  ("shifts.ao", g["s_ao"], run_vals["sh_ao"]),
                  ("ff.gate", gf["gate"], run_vals["sh_g"]),
                  ("ff.product", gf["product"], run_vals["sh_h"]),
                  ("ff.down", gf["down"], run_vals["sh_z"]),
                  ("ff.up (sh_u)", gf["up"], pc.get("sh_u")),
                  ("ff.residual2", gf["res2"], 0),
                  ("ff.F (hidden)", gf["F"], sh["hidden"]),
                  ("wrho (derived)", g["wrho"], dv["norm_wrho"]),
                  ("dmax (derived)", g["dmax"], dv["d_max"]),
                  ("int16-endpoint", g["i16"], INT16_ABS),
                  ("rope (port SH_ROPE)", g["s_rope"], T.SH_ROPE),
                  ("rope (export sh_rope)", g["s_rope"], pc.get("sh_rope")),
                  ("residual", g["s_res"], 0),
                  ("fE (export f_e)", g["fe"], pc.get("f_e")),
                  ("fP (port F_P)", g["fp"], T.F_P),
                  ("fRo (export f_ro)", g["fro"], pc.get("f_ro")),
                  ("wrhoS (derived)", g["wrhos"], dv["wrho_s"]),
                  ("mask (port MASK_SCORE)", g["mask"], T.MASK_SCORE)]
        for name, got, want in pairs:
            x1["compared"][name] = {"line": got, "want": want, "equal": got == want}
            if got != want:
                f.append(f"X1: the layout description's {name} is {got}, expected {want}")
    x1["ok"] = not any(x.startswith("X1") for x in f)
    out["X1_layout_description"] = x1
    # X2
    x2 = {"what": "blake3('hashline/token-io-run-schedule/v1' + length-framed lines: "
          "parameter_line, layout_description, token_io.stage_in_layout, "
          "token_io.stage_out_layout, stage_lines), token_io/run.rs schedule_digest"}
    try:
        import blake3
        h = blake3.blake3()
        h.update(b"hashline/token-io-run-schedule/v1")

        def line(s):
            bs = s.encode()
            h.update(len(bs).to_bytes(8, "little"))
            h.update(bs)
        ti = run["token_io"]
        line(run["parameter_line"])
        for s in run["layout_description"] + ti["stage_in_layout"] + ti["stage_out_layout"] \
                + run["stage_lines"]:
            line(s)
        x2["recomputed"] = h.hexdigest()
        x2["run_json"] = bytes(run["schedule_digest"]).hex()
        x2["equal"] = x2["recomputed"] == x2["run_json"]
        if not x2["equal"]:
            f.append("X2: the schedule digest recomputed from run.json's lines is not "
                     "run.json's schedule_digest")
    except Exception as exc:  # noqa: BLE001
        x2["equal"] = False
        f.append(f"X2: not recomputed ({exc})")
    x2["ok"] = bool(x2.get("equal"))
    out["X2_schedule_digest"] = x2
    # X3
    mp = PARAM_SH.search(run.get("parameter_line", ""))
    if not mp:
        f.append("X3: the parameter line carries no sh-g..-u..-h..-z.. field")
        out["X3_parameter_line"] = {"found": False, "ok": False}
    else:
        got = tuple(int(x) for x in mp.groups())
        want = (run_vals["sh_g"], pc.get("sh_u"), run_vals["sh_h"], run_vals["sh_z"])
        out["X3_parameter_line"] = {"found": True, "sh_g_u_h_z": list(got),
                                    "run_calibration": list(want), "ok": got == want}
        if got != want:
            f.append(f"X3: the parameter line says sh g/u/h/z = {got}, the run calibration {want}")
    # X4
    x4 = {"derived_at_the_run_calibration": dv, "compared": {}}
    for name, got, want in (("f_e", sh.get("f_e"), pc.get("f_e")),
                            ("tokens", sh.get("tokens"), exp["T"]),
                            ("norm_wrho", sh.get("norm_wrho"), dv["norm_wrho"]),
                            ("wrho_s", sh.get("wrho_s"), dv["wrho_s"])):
        x4["compared"][name] = {"shape": got, "want": want, "equal": got == want}
        if got != want:
            f.append(f"X4: the shape's {name} is {got}, the run calibration derives {want}")
    for v in [run_vals] + stage_vals:
        dvi = derive(v, sh["width"], sh["tokens"], pc.get("f_e"))
        for rule in ("d_max_in_three_limbs", "wrho_is_four_limbs"):
            if not dvi[rule]:
                f.append(f"X4: {rule} fails at {v}")
    fe = pc.get("f_e")
    if not (isinstance(fe, int) and 9 <= fe <= 16 and dv["wrho_s"] <= 24):
        f.append(f"X4: f_e {fe} / wrho_s {dv['wrho_s']} outside the trained class")
    x4["ok"] = not any(x.startswith("X4") for x in f)
    out["X4_shape_derivations"] = x4
    # X5
    for who, v in [("run", run_vals)] + [(f"block {k}", sv) for k, sv in enumerate(stage_vals)]:
        for key in CAL_KEYS:
            lo, hi = WINDOWS[key]
            if not lo <= v[key] <= hi:
                f.append(f"X5: {who}'s {key} {v[key]} is outside its class [{lo}, {hi}]")
    out["X5_classes"] = {"windows": {k: list(WINDOWS[k]) for k in CAL_KEYS},
                         "ok": not any(x.startswith("X5") for x in f)}
    # X6: the block stage lines' own clauses
    x6 = []
    lines = run.get("stage_lines", [])
    for k, sv in enumerate(stage_vals):
        ln = lines[k + 1] if k + 1 < len(lines) else ""
        got = sorted((lab, int(v), int(b)) for lab, v, b in OWN_CLAUSE.findall(ln))
        want = sorted((lab, sv[key], run_vals[key]) for key, lab in OWN_FIELDS
                      if sv[key] != run_vals[key])
        ok = (f"(block {k})" in ln) and got == want
        x6.append({"token_stage": k + 1, "own_clauses_in_the_line": got,
                   "expected_from_the_layer": want, "ok": ok})
        if not ok:
            f.append(f"X6: token stage {k + 1}'s line names own constants {got}, the layer "
                     f"implies {want}")
    out["X6_stage_line_own_constants"] = {"per_stage": x6,
                                          "ok": not any(x.startswith("X6") for x in f)}
    # X7
    x7 = {}
    for name, want in (("f_p", T.F_P), ("sh_rope", T.SH_ROPE), ("f_ro", 7),
                       ("sh_u", 0), ("sh_r2", 0)):
        x7[name] = {"export": pc.get(name), "port": want, "equal": pc.get(name) == want}
        if pc.get(name) != want:
            f.append(f"X7: the export's {name} is {pc.get(name)}, the port hard-codes {want}")
    out["X7_port_literals"] = {"per_key": x7, "ok": not any(x.startswith("X7") for x in f)}
    return {"checks": out, "findings": f, "ok": not f}


def stage_tables_x9(rec_detail_by_stage, layer_of_stage, exp, f_e) -> dict:
    rows, f = [], []
    for k, det in enumerate(rec_detail_by_stage):
        exps, acts = det.get("exp_values") or [], det.get("act_values") or []
        layer = layer_of_stage[k]
        row = {"token_stage": k + 1, "layer": layer}
        if len(exps) == 1 and len(acts) == 1:
            ge, ga = exps[0], acts[0]
            row.update({
                "recovered_exp_sha256": ge.get("recovered_sha256"),
                "recovered_act_sha256": ga.get("recovered_sha256"),
                "exp_0": ge.get("exp_0"), "act_128": ga.get("act_128"),
                "layers_whose_exp_and_act_match": [
                    ly for ly, L_ in exp["layers"].items()
                    if L_["tables"]["exp_sha"] == ge.get("recovered_sha256")
                    and L_["tables"]["act_sha"] == ga.get("recovered_sha256")]})
            row["ok"] = (layer in row["layers_whose_exp_and_act_match"]
                         and ge.get("exp_0") == (1 << f_e) and ga.get("act_128") == 0)
        else:
            row["ok"] = False
            row["why"] = "the port recovered no exp / SiLU table for this stage"
        if not row["ok"]:
            f.append(f"X9: token stage {k + 1}: recovered tables do not match layer {layer}")
        rows.append(row)
    return {"per_stage": rows, "findings": f, "ok": not f}


# =====================================================================
#  the shim
# =====================================================================
class _BlockStageView:
    """A token BLOCK stage, renumbered as stage `k` of the shim."""

    def __init__(self, st, k):
        self._st = st
        self.index = k
        self.token_index = st.index
        self.doc = st.doc
        self.name = st.name
        self.path = st.path

    @property
    def slots(self):
        return self.doc["arguments"]

    @property
    def mask(self):
        return self.doc["mask"]

    @property
    def roles(self):
        return self.doc["roles"]

    def role(self, name):
        return self._st.role(name)

    def role_or_none(self, name):
        return self._st.role_or_none(name)

    def key(self, role_name):
        return self._st.key(role_name)


class TokenBlockShim:
    """Block stages of a token run as `check_terminals` reads a run bundle:
    the chosen blocks renumbered 0.., `blocks` = their count, the token run
    header with the shape carrying `trained_calibration`, the eleven
    constants `cal_values` and `extra` (e.g. the derived `norm_wrho`).
    `cal_values=None` leaves the shape exactly as the token bundle wrote it."""

    def __init__(self, tb, cal_values, blocks=None, extra=None):
        self.token_bundle = tb
        self.dir = tb.dir
        self.schema = tb.schema
        self.profile = tb.run.get("block_profile")
        self.manifest = tb.manifest
        self.hash_rule = tb.hash_rule
        self.hash_rule_record = tb.hash_rule_record
        self.public_tables_included = tb.public_tables_included
        all_blocks = [st for st in tb.stages if st.kind == "BLOCK"]
        if [st.index for st in all_blocks] != list(range(1, tb.l + 1)):
            raise ValueError(f"block stages at token indices "
                             f"{[st.index for st in all_blocks]}, not 1..{tb.l}")
        self.block_ids = list(range(tb.l)) if blocks is None else list(blocks)
        self.blocks = len(self.block_ids)
        self.stages = [_BlockStageView(all_blocks[b], i) for i, b in enumerate(self.block_ids)]
        self.run = dict(tb.run)
        shape = dict(tb.run["shape"])
        if cal_values is not None:
            shape.update({"trained_calibration": True, **cal_values, **(extra or {})})
        self.run["shape"] = shape
        self.shape = Shape(shape, tb.run["mask_domain"])

    @property
    def name(self):
        return f"{self.token_bundle.name} [token stages {[b + 1 for b in self.block_ids]}]"

    def with_shape(self, shape):
        s = copy.copy(self)
        s.run = dict(self.run)
        s.run["shape"] = shape
        s.shape = Shape(shape, self.run["mask_domain"])
        return s

    def boundary(self, j):
        """A native run's internal boundary j (between blocks j and j + 1) is
        token boundary j + 1; B_in / B_out stand where a native run has its
        external endpoints.  The port never calls this."""
        if not 0 <= j < self.token_bundle.l - 1:
            raise IndexError(f"internal boundary {j} of a {self.token_bundle.l}-block run")
        fa = dict(self.token_bundle.boundary(j + 1))
        fa["token_boundary"] = j + 1
        return fa


class _ReplayView:
    """The token replay with `stages[i]` = token stage `block_ids[i] + 1`'s."""

    def __init__(self, rp, block_ids):
        self._rp = rp
        self.stages = [rp.stages[b + 1] for b in block_ids]
        self.failures = rp.failures

    def summary(self):
        return self._rp.summary()


@contextlib.contextmanager
def token_shape_reading(manifest):
    """Add the gate's written reading of the token bundle's `shape.rs` to the
    port's `PINNED_IF_PRESENT`, IN MEMORY, for this block only."""
    pins = {p["file"]: p["sha256"] for p in manifest.get("source_pins", [])}
    got = pins.get(SHAPE_RS)
    table = T.PINNED_IF_PRESENT[SHAPE_RS]
    rec = {"file": SHAPE_RS, "bundle_pins": got, "added_in_memory": None,
           "already_accepted_by_the_port": got in table if got else None}
    added = None
    if got is not None and got not in table:
        reading = TP.TOKEN_R7C_READINGS.get(SHAPE_RS, {}).get(got)
        if reading is None:
            rec["refused"] = "the gate has no written reading of this digest"
        elif reading.get("moves_a_block_stage_byte") is not False:
            rec["refused"] = "the reading does not say that no block-stage byte moves"
        elif reading.get("base") not in table:
            rec["refused"] = (f"the reading's base {str(reading.get('base'))[:12]} is not "
                              "a digest the port accepts")
        else:
            table[got] = ("[TOKEN BLOCK ADAPTER, in memory for this call only] "
                          + reading["reading"])
            added = got
            rec.update({"added_in_memory": got,
                        "reading_from": "zk60_native_rg_tokenio_r7c_pins.TOKEN_R7C_READINGS"
                                        f"[{SHAPE_RS!r}][{got[:12]}...]",
                        "reading_base_accepted_by_the_port": reading["base"],
                        "reading_diff_stat": reading.get("diff_stat")})
    try:
        yield rec
    finally:
        if added is not None:
            table.pop(added, None)
        rec["removed_after"] = added is not None and added not in table


def _failing(rec) -> set:
    bad = set()
    for row in rec["per_stage"]:
        bad |= set(row["checked"]) - set(row["equal"])
        bad |= {e["slot"] for e in row["not_checked"]}
    return bad


def _io_wiring(tb) -> dict:
    f, rows = [], []
    for k, st in enumerate([s for s in tb.stages if s.kind == "BLOCK"]):
        inp = st.role_or_none("Input")
        bc = st.doc.get("boundary_committed") or {}
        r21 = [t.get("role") for t in st.doc["arguments"][21]["tables"] if t["kind"] == "private"]
        r22 = [t.get("role") for t in st.doc["arguments"][22]["tables"] if t["kind"] == "private"]
        row = {"token_stage": st.index, "block": k,
               "opens_token_boundary": inp.get("boundary") if inp else None,
               "opened_commitment_kind": inp.get("commitment_kind") if inp else None,
               "commits_token_boundary": bc.get("boundary"),
               "slot21_private_roles": r21, "slot22_private_roles": r22}
        if row["opens_token_boundary"] != k or row["commits_token_boundary"] != k + 1:
            f.append(f"token stage {st.index}: opens {row['opens_token_boundary']}, commits "
                     f"{row['commits_token_boundary']}, not {k} / {k + 1}")
        if r21 != ["A", "Input"] or r22 != ["A", "Output"]:
            f.append(f"token stage {st.index}: IO slot roles {r21} / {r22}")
        rows.append(row)
    return {"per_stage": rows, "findings": f, "ok": not f,
            "mapping": {"block k": "token stage k + 1",
                        "block k's Input (slot 21's IO table)": "token boundary k (B_in at k = 0)",
                        "block k's Output (slot 22's IO table)": "token boundary k + 1 (B_out at k = L - 1)",
                        "native internal boundary j": "token boundary j + 1",
                        "external endpoints": "none in a block stage (the token endpoints are "
                        "opened at stages IN and OUT, which no shim exposes)"}}


# =====================================================================
#  the driver
# =====================================================================
def token_block_terminals(token_bundle, token_replay, export_dir=None, controls=True,
                          control_constant="sh_z", frozen_control=True) -> dict:
    t0 = time.time()
    tb, L = token_bundle, token_bundle.l
    timings = collections.defaultdict(float)

    def tick(name, t):
        timings[name] = round(timings[name] + time.time() - t, 1)
    rec = {"what": "the gate's frozen block-stage terminal identity (stage 8, "
           "check_terminals) on each block stage of ONE token-I/O run capture, through "
           "a one-stage shim per block; NOT a privacy result", "privacy_acceptance": False,
           "privacy_property_established": False,
           "bundle": tb.name, "bundle_dir": tb.dir, "profile": tb.profile,
           "block_profile": tb.run.get("block_profile"), "blocks": L,
           "shape_name": tb.run["shape"].get("name"),
           "block_stages_token_indices": list(range(1, L + 1)), "timings": timings}
    rs = token_replay.summary()
    rec["token_replay"] = {k: rs[k] for k in ("ok", "run_binding_reproduced",
                                               "challenges_checked", "failures")}
    pins = TG.token_pins(tb.manifest)
    rec["token_pins"] = {k: pins[k] for k in ("pins", "read_as_R7", "read_as_token_r7c",
                                              "refusals", "ok")}
    t = time.time()
    integ = TG.token_integrity(tb)
    rec["token_integrity"] = {"ok": integ["ok"], "findings": integ["findings"]}
    tick("token_integrity", t)
    if not rs["ok"] or not pins["ok"]:
        rec.update({"refused": "the token replay failed or a token pin has no reading: "
                    "no block stage is read", "ok": False, "status": "REFUSED"})
        return rec
    # ---- the export, from the bundle
    t = time.time()
    rd = readme_facts(tb)
    src = {"readme": rd, "override": export_dir}
    exp_dir = export_dir or rd["export"]
    pre_f = []
    if export_dir and rd["export"] and os.path.realpath(export_dir) != os.path.realpath(rd["export"]):
        pre_f.append(f"--export {export_dir} is not the README's {rd['export']}")
    if not exp_dir or not os.path.exists(os.path.join(exp_dir, "profile.json")):
        rec.update({"export_source": src, "refused": "no export: the README names none "
                    "that exists and none was given", "ok": False, "status": "REFUSED"})
        return rec
    exp = load_export(exp_dir)
    if rd["variant"] and exp["variant"] != rd["variant"]:
        pre_f.append(f"the export's variant {exp['variant']} is not the README's {rd['variant']}")
    src.update({"used": exp_dir, "variant": exp["variant"],
                "profile_sha256": exp["profile_sha256"],
                "profile_digest_bound_by_the_bundle": "NOT FOUND as a word: the bundle "
                "binds the export's profile digest only inside the absorbed `calibration` "
                "word (trained-model statement identity v3), which is not recomputed here"})
    rec["export_source"] = src
    ident = identify_layers(tb, exp, rd["layers"])
    layer_of_stage = [r["layer"] for r in ident["per_stage"]]
    tick("export_and_layers", t)
    if any(ly is None for ly in layer_of_stage):
        rec.update({"calibration": {"X10_stage_layers": ident, "export_X8": exp["X8"],
                                    "findings": pre_f + exp["findings"] + ident["findings"]},
                    "refused": "a block stage's layer could not be identified, so its "
                    "calibration is unknown", "ok": False, "status": "REFUSED"})
        return rec
    cals = calibrations(exp, layer_of_stage)
    x = crosscheck(cals["run_values"], cals["stage_values"], exp, tb)
    width, tokens, f_e = tb.run["shape"]["width"], tb.run["shape"]["tokens"], exp["pc"]["f_e"]
    stage_extra = [{"norm_wrho": derive(v, width, tokens, f_e)["norm_wrho"]}
                   for v in cals["stage_values"]]
    rec["calibration"] = {
        "how": "per block stage: the eleven constants Calibration reads, the profile's "
               "profile_constants with the per-layer keys from the stage's LAYER manifest "
               "(layer identified by X10), injected into that stage's shim shape with "
               "trained_calibration: true and the derived norm_wrho; the token bundle's "
               "own shape names none",
        "export": exp_dir, "export_variant": exp["variant"],
        "export_profile_sha256": exp["profile_sha256"],
        "per_layer_constants_differ": exp["per_layer"],
        "per_layer_calibration_fields": cals["per_layer_fields"],
        "run_values": cals["run_values"], "run_value_rule": cals["rule"],
        "run_value_tally": cals["run_value_tally"],
        "stage_values": [{"token_stage": k + 1, "layer": layer_of_stage[k],
                          "values": v, "derived_norm_wrho": stage_extra[k]["norm_wrho"],
                          "differs_from_the_run_on": [kk for kk in CAL_KEYS
                                                      if v[kk] != cals["run_values"][kk]]}
                         for k, v in enumerate(cals["stage_values"])],
        "cross_checks": dict(x["checks"], X8_export_layers=exp["X8"],
                             X10_stage_layers=ident),
        "findings": pre_f + exp["findings"] + ident["findings"] + x["findings"],
    }
    rec["shim"] = {
        "per_stage": "one shim per block stage: block k as stage 0, blocks = 1, replay view "
                     "stages[0] = token stage k + 1's",
        "shape_keys_added": ["trained_calibration"] + list(CAL_KEYS) + ["norm_wrho (derived)"],
        "port_reads_of_the_stage_index": [
            "docs[st.index] and replay.stages[st.index] (check_terminals)",
            "GroupFactors.point(st.index, slot) and its docs / replay lookups",
            "bundle.blocks as the stage count (slot_checks_expected)"],
        "port_reads_of_endpoints_or_boundary_numbering": "none (no boundary(), "
        "internal_boundaries or commitment_kind in terminals / planes / gqa)",
    }
    rec["io_wiring"] = _io_wiring(tb)
    per_stage, details = [], []
    ctl = {}
    with token_shape_reading(tb.manifest) as pin_rec:
        rec["source_pin_adaptation"] = pin_rec
        t = time.time()
        full = TokenBlockShim(tb, cals["run_values"],
                              extra={"norm_wrho": tb.run["shape"]["norm_wrho"]})
        index = PlaneIndex(full)
        pi = index.summary()
        rec["plane_index"] = {k: pi[k] for k in ("ok", "findings", "a_planes", "h_planes",
                                                 "a_data_rows", "h_data_rows", "slots")}
        rec["plane_index"]["checked_over"] = f"all {L} block stages"
        tick("plane_index", t)
        shims = [TokenBlockShim(tb, cals["stage_values"][k], blocks=[k], extra=stage_extra[k])
                 for k in range(L)]
        views = [_ReplayView(token_replay, [k]) for k in range(L)]
        honest = []
        t = time.time()
        for k in range(L):
            r = T.check_terminals(shims[k], index, replay=views[k])
            honest.append(r)
            row = r["per_stage"][0] if r["per_stage"] else {"checked": [], "equal": [],
                                                           "not_checked": []}
            per_stage.append({
                "token_stage": k + 1, "block": k, "layer": layer_of_stage[k],
                "ok": r["ok"], "slot_checks_equal": len(row["equal"]),
                "slot_checks_expected": r["slot_checks_expected"],
                "slot_checks_matching_the_stored_terminal_polynomial":
                    r["slot_checks_matching_the_stored_terminal_polynomial"],
                "checked_not_equal": sorted(set(row["checked"]) - set(row["equal"])),
                "refused_or_open": [{"slot": e["slot"], "name": e["name"], "why": e["why"]}
                                    for e in row["not_checked"]],
                "open_slots": r["open_slots"],
                "public_tables_rebuilt": r["public_tables_rebuilt_and_digest_matched"],
                "public_tables_taken_from_the_capture": r["public_tables_taken_from_the_capture"],
                "public_table_structure_checks": r["public_table_structure_checks"],
                "public_table_failures": r["public_table_digest_failures"]
                + r["public_table_structure_failures"],
                "derived_group_points_used_and_compared": r["derived_group_points_used_and_compared"],
                "bilinear_group_factor_ok": r["bilinear_group_factor"]["ok"],
                "source_pins_ok": r["source_pins"]["ok"],
                "port_findings": r["findings"],
                "refused_before_any_slot_was_evaluated":
                    r.get("refused_before_any_slot_was_evaluated")})
            details.append(r.get("public_table_structure_detail") or {})
        tick("terminal_identity", t)
        x9 = stage_tables_x9(details, layer_of_stage, exp, f_e)
        rec["calibration"]["cross_checks"]["X9_recovered_tables"] = x9
        rec["calibration"]["findings"] += x9["findings"]
        rec["calibration"]["ok"] = not rec["calibration"]["findings"]
        if controls:
            name = control_constant
            # NC-1
            t = time.time()
            got, want = set(), set()
            for k in range(L):
                moved = dict(shims[k].run["shape"])
                moved[name] = _step(name, int(moved[name]))
                r1 = T.check_terminals(shims[k].with_shape(moved), index, replay=views[k])
                got |= {(k + 1, s) for s in _failing(r1)}
                want |= {(k + 1, s) for s in READS[name]}
            ctl["NC-1_constant_moved"] = {
                "perturbation": f"{name} moved by one inside its class (tlcontrols._step) in "
                                "every stage's shim shape",
                "predicted_from": "zk60_native_rg_tlcontrols.READS",
                "predicted_failing_token_stage_slot": sorted(list(p) for p in want),
                "failing_token_stage_slot": sorted(list(p) for p in got),
                "exactly_as_predicted": got == want, "ok": bool(got) and got == want}
            tick("NC-1", t)
            if frozen_control:
                t = time.time()
                got, want, differs_all = set(), set(), {}
                for k in range(L):
                    differs = [kk for kk in CAL_KEYS
                               if T.FROZEN_CALIBRATION[kk] != cals["stage_values"][k][kk]]
                    differs_all[k + 1] = differs
                    for kk in differs:
                        want |= {(k + 1, s) for s in READS[kk]}
                    r2 = T.check_terminals(TokenBlockShim(tb, None, blocks=[k]), index,
                                           replay=views[k])
                    got |= {(k + 1, s) for s in _failing(r2)}
                ctl["NC-2_port_fallback_frozen"] = {
                    "perturbation": "each stage's shim with the token bundle's shape as written "
                                    "(no trained keys): Calibration falls back to FROZEN",
                    "constants_that_differ_from_frozen_per_token_stage": differs_all,
                    "predicted_failing_slots": sorted({s for _k, s in want}),
                    "failing_slots": sorted({s for _k, s in got}),
                    "exactly_as_predicted_in_every_stage": got == want,
                    "ok": bool(got) and got == want}
                tick("NC-2", t)
            # NC-3
            mv = dict(cals["run_values"])
            mv[name] = _step(name, mv[name])
            x3 = crosscheck(mv, cals["stage_values"], exp, tb)
            fired = sorted({fd.split(":")[0] for fd in x3["findings"]})
            ctl["NC-3_crosscheck_on_a_moved_run_constant"] = {
                "perturbation": f"the run calibration's {name} moved to {mv[name]}",
                "checks_that_fired": fired, "first_findings": x3["findings"][:3],
                "ok": (not x3["ok"]) and "X1" in fired}
            # NC-4
            t = time.time()
            pair = None
            blocks = [st for st in tb.stages if st.kind == "BLOCK"]
            for j in range(L - 1):
                a = blocks[j].doc["arguments"][TAB_SLOT]["tables"]
                b = blocks[j + 1].doc["arguments"][TAB_SLOT]["tables"]
                diff = [i for i in range(min(len(a), len(b)))
                        if "values" in a[i] and "values" in b[i]
                        and a[i].get("sha256") != b[i].get("sha256")]
                if diff:
                    pair = (j, j + 1, diff)
                    break
            if pair is None:
                ctl["NC-4_table_swap"] = {"skipped": "no adjacent block-stage pair carries "
                                          "different lookup tables (L = 1, or equal tables)",
                                          "ok": None}
            else:
                j, k, diff = pair
                runs = []
                for i in diff:
                    d2 = dict(blocks[k].doc)
                    d2["arguments"] = list(d2["arguments"])
                    a19 = dict(d2["arguments"][TAB_SLOT])
                    a19["tables"] = list(a19["tables"])
                    a19["tables"][i] = blocks[j].doc["arguments"][TAB_SLOT]["tables"][i]
                    d2["arguments"][TAB_SLOT] = a19
                    r4 = T.check_terminals(shims[k], index, replay=views[k], stage_docs=[d2])
                    g4 = {(k + 1, s) for s in _failing(r4)}
                    runs.append({"table": i, "failing_token_stage_slot": sorted(list(p) for p in g4),
                                 "exactly_as_predicted": g4 == {(k + 1, TAB_SLOT)}})
                ctl["NC-4_table_swap"] = {
                    "perturbation": f"token stage {k + 1}'s SC_TAB carried tables {diff} replaced "
                                    f"by token stage {j + 1}'s (values and digest), one at a time",
                    "predicted_failing_token_stage_slot": [[k + 1, TAB_SLOT]],
                    "runs": runs, "ok": bool(runs) and all(r["exactly_as_predicted"] for r in runs)}
            tick("NC-4", t)
    if controls:
        t = time.time()
        r0 = T.check_terminals(shims[0], index, replay=views[0])
        ctl["NC-0_shape_rs_reading_not_added"] = {
            "perturbation": "the port's PINNED_IF_PRESENT as frozen (the token reading not "
                            "added), token stage 1",
            "pins_that_moved": r0["source_pins"]["pins_that_moved"],
            "slot_checks_attempted": r0["slot_checks_attempted"],
            "refused_before_any_slot_was_evaluated":
                "refused_before_any_slot_was_evaluated" in r0,
            "ok": (not r0["ok"]) and r0["slot_checks_attempted"] == 0
            and "refused_before_any_slot_was_evaluated" in r0}
        tick("NC-0", t)
        live = {kk: v for kk, v in ctl.items() if v.get("ok") is not None}
        rec["controls"] = {"controls": ctl, "not_applicable": [kk for kk, v in ctl.items()
                                                               if v.get("ok") is None],
                           "ok": bool(live) and all(v["ok"] for v in live.values())}
    else:
        rec["controls"] = {"skipped": "controls not requested", "ok": None}
    tot_eq = sum(r["slot_checks_equal"] for r in per_stage)
    tot_ex = sum(r["slot_checks_expected"] for r in per_stage)
    rec["terminal_identity"] = {
        "per_stage": per_stage, "slot_checks_equal": tot_eq, "slot_checks_expected": tot_ex,
        "slot_checks_matching_the_stored_terminal_polynomial": sum(
            r["slot_checks_matching_the_stored_terminal_polynomial"] for r in per_stage),
        "every_stage_ok": all(r["ok"] for r in per_stage),
        "numbering": "TOKEN stage numbers; each port call's own strings say 'stage 0'"}
    rec["every_block_slot_equal"] = bool(per_stage) and all(
        r["ok"] and r["slot_checks_equal"] == r["slot_checks_expected"] == 23 for r in per_stage)
    parts = {"token_integrity": rec["token_integrity"]["ok"],
             "calibration_cross_checks": rec["calibration"]["ok"],
             "io_wiring": rec["io_wiring"]["ok"], "plane_index": rec["plane_index"]["ok"],
             "terminal_identity": rec["every_block_slot_equal"],
             "source_pin_reading_removed": bool(pin_rec.get("removed_after")
                                                or pin_rec.get("added_in_memory") is None)}
    rec["parts"] = parts
    rec["false_parts"] = [kk for kk, v in parts.items() if not v]
    rec["ok"] = not rec["false_parts"] and (rec["controls"]["ok"] is True if controls else True)
    rec["status"] = ("PASS" if rec["ok"] and controls else
                     "PASS-NO-CONTROLS" if rec["ok"] else "NOT-OK")
    rec["total_seconds"] = round(time.time() - t0, 1)
    try:
        import resource
        rec["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
    except Exception:  # noqa: BLE001
        pass
    rec["tool_sha256"] = {os.path.basename(p): _sha_file(p) for p in (
        os.path.abspath(__file__), T.__file__, TG.__file__, TP.__file__,
        sys.modules["zk60_native_rg_planes"].__file__,
        sys.modules["zk60_native_rg_gqa"].__file__,
        sys.modules["zk60_native_rg_bundle"].__file__,
        sys.modules["zk60_native_rg_tlcontrols"].__file__)}
    return rec


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--export", default=None, help="override the README's export")
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--no-controls", action="store_true")
    ap.add_argument("--no-frozen-control", action="store_true")
    ap.add_argument("--control-constant", default="sh_z", choices=sorted(CAL_KEYS))
    a = ap.parse_args(argv)
    t = time.time()
    b = TG.load(a.bundle)
    t_load = round(time.time() - t, 1)
    t = time.time()
    rp = TG.TokenRunReplay(b).run()
    t_rep = round(time.time() - t, 1)
    rec = token_block_terminals(b, rp, export_dir=a.export, controls=not a.no_controls,
                                control_constant=a.control_constant,
                                frozen_control=not a.no_frozen_control)
    rec["timings"]["load"], rec["timings"]["token_replay"] = t_load, t_rep
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"{a.name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
        fh.write("\n")
    per = [(r["token_stage"], r["slot_checks_equal"], r["slot_checks_expected"])
           for r in (rec.get("terminal_identity") or {}).get("per_stage", [])]
    print(f"{a.name}: status {rec.get('status')}; false parts {rec.get('false_parts')}; "
          f"equal {(rec.get('terminal_identity') or {}).get('slot_checks_equal')} of "
          f"{(rec.get('terminal_identity') or {}).get('slot_checks_expected')}; per stage "
          f"{per if len(per) <= 4 else str(per[:2]) + '...'}; controls "
          f"{(rec.get('controls') or {}).get('ok')}; {rec.get('total_seconds')} s; peak "
          f"{rec.get('peak_rss_mb')} MB; record {path}")
    return 0 if rec.get("status") in ("PASS", "PASS-NO-CONTROLS") else 1


if __name__ == "__main__":
    raise SystemExit(main())
