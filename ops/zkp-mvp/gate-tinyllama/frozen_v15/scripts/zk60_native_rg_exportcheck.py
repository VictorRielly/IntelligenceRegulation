#!/usr/bin/env python3
"""[TINYLLAMA PORT, tools v5, 2026-10-17 round 4; independent review finding
P-9] The bundle's trained calibration, checked against the EXPORT it claims
and against an independently written STATEMENT, instead of taken from the
prover-written bundle alone.

    python3 zk60_native_rg_exportcheck.py --bundle <run bundle> \
        --export <calibration export dir> [--statement <statement.json>] \
        [--record <a staged record of the same bundle, for its tables>] \
        --evidence <dir> --name <name>

and, inside the staged driver, `--export DIR [--statement FILE]` adds this as
`stage14_export_crosscheck` (so its `ok` is part of the record's `ok`).

WHAT IS CHECKED, each a refusal by name:

  E1  every trained constant the gate reads from `run.json["shape"]`
      (`norm_tn`, `norm_cn_a`, `norm_cn_m`, `norm_ceps`, the seven shifts
      `sh_ao`, `sh_qkv`, `sh_s`, `sh_o`, `sh_g`, `sh_h`, `sh_z`) and `f_e`
      equal the export's `profile.json["profile_constants"]`, and the token
      count its `T`;
  E2  the absorbed parameter line's `sh-g{g}-u0-h{h}-z{z}` field equals the
      shape's `sh_g`, `sh_h`, `sh_z` (the line is absorbed by the run header;
      the port reads the shape's fields);
  E3  (with --statement, a `statement.json` the trained stack CLI wrote from
      the same export) the statement names this export (`export_variant`,
      `export_profile_sha256` = the SHA-256 of the export's `profile.json`),
      this block and run profile; the bundle's `block_digests` are a
      CONTIGUOUS run of the statement's per-layer block digests, which maps
      every stage to its export layer independently of the writer; and, when
      the bundle covers exactly the statement's layers, the absorbed
      calibration word equals the statement's `trained_statement_identity`;
  E4  for every stage whose public tables the terminal check recovered (stage
      3's per-slot check or stage 8 of a record of this bundle), the SHA-256
      of the recovered exp and SiLU entries (int64 little-endian) equals the
      export layer's `exp.bin` / `act.bin` (act widened to int64), and
      `act[128] = 0`, `exp[0] = 2^f_e`.

WHAT IT DOES NOT SHOW.  That the export is the right calibration of the model
(the D24 review's subject), or anything about a hidden value.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

CONSTANTS = ("norm_tn", "norm_cn_a", "norm_cn_m", "norm_ceps", "sh_ao",
             "sh_qkv", "sh_s", "sh_o", "sh_g", "sh_h", "sh_z", "f_e")
PARAM_SH = re.compile(r"/sh-g(\d+)-u0-h(\d+)-z(\d+)/")


def _sha_file(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def _table_sha(path, width):
    """SHA-256 of a table's entries as int64 little-endian (act is int16)"""
    with open(path, "rb") as fh:
        raw = fh.read()
    vals = [int.from_bytes(raw[i:i + width], "little", signed=True)
            for i in range(0, len(raw), width)]
    return hashlib.sha256(b"".join(v.to_bytes(8, "little", signed=True)
                                   for v in vals)).hexdigest(), vals


def _recovered_tables(record):
    """per-stage recovered (exp, act) details from a staged record, or None"""
    for path in (("stage8_plane_index_and_terminals", "terminal_identity"),
                 ("stage3_per_commitment", "per_slot_terminal_check")):
        node = record or {}
        for k in path:
            node = node.get(k) if isinstance(node, dict) else None
        det = (node or {}).get("public_table_structure_detail") if isinstance(node, dict) else None
        if det and det.get("exp_values") and det.get("act_values"):
            return det["exp_values"], det["act_values"], "/".join(path)
    return None


def export_check(bundle, export_dir, statement_path=None, record=None) -> dict:
    f: list[str] = []
    out = {"what": "the bundle's trained calibration against the export it "
           "claims and an independent statement (finding P-9)",
           "bundle": bundle.name, "export": export_dir,
           "privacy_property_established": False, "privacy_acceptance": False}
    prof_path = os.path.join(export_dir, "profile.json")
    prof = json.load(open(prof_path))
    prof_sha = _sha_file(prof_path)
    pc = prof.get("profile_constants") or {}
    sh = bundle.run["shape"]
    out["export_variant"] = prof.get("variant")
    out["export_profile_sha256"] = prof_sha
    if sh.get("trained_calibration") is not True:
        f.append("E1: the bundle declares no trained calibration")
    # E1
    e1 = {}
    for key in CONSTANTS:
        got, want = sh.get(key), pc.get(key)
        e1[key] = {"bundle": got, "export": want, "equal": got == want}
        if got != want:
            f.append(f"E1: {key} is {got} in the bundle and {want} in the export")
    if sh.get("tokens") != prof.get("T"):
        f.append(f"E1: the bundle has T = {sh.get('tokens')}, the export {prof.get('T')}")
    out["E1_constants"] = e1
    # E2
    m = PARAM_SH.search(bundle.run.get("parameter_line", ""))
    if not m:
        f.append("E2: the parameter line carries no sh-g..-u0-h..-z.. field")
        out["E2_parameter_line"] = {"found": False}
    else:
        g, h, z = (int(x) for x in m.groups())
        ok2 = (g, h, z) == (sh.get("sh_g"), sh.get("sh_h"), sh.get("sh_z"))
        out["E2_parameter_line"] = {"found": True, "sh_g_h_z": [g, h, z],
                                    "equal_to_the_shape": ok2}
        if not ok2:
            f.append(f"E2: the absorbed parameter line says sh g/h/z = {g}/{h}/{z}, "
                     f"the shape {sh.get('sh_g')}/{sh.get('sh_h')}/{sh.get('sh_z')}")
    # E3
    layer_of_stage = None
    if statement_path:
        st = json.load(open(statement_path))
        e3 = {"statement": statement_path,
              "statement_sha256": _sha_file(statement_path)}
        for key, want in (("export_variant", prof.get("variant")),
                          ("export_profile_sha256", prof_sha),
                          ("block_profile", bundle.run.get("block_profile")),
                          ("run_profile", bundle.profile)):
            if st.get(key) != want:
                f.append(f"E3: the statement's {key} is {st.get(key)!r}, expected {want!r}")
        digests = [bytes(d).hex() for d in bundle.run["block_digests"]]
        layers = st.get("layers") or []
        sd = [x.get("block_digest") for x in layers]
        start = sd.index(digests[0]) if digests and digests[0] in sd else None
        if start is None or sd[start:start + len(digests)] != digests:
            f.append("E3: the bundle's block digests are not a contiguous run of "
                     "the statement's per-layer block digests")
        else:
            layer_of_stage = [layers[start + k]["layer"] for k in range(len(digests))]
        e3["layer_of_stage"] = layer_of_stage
        ident = bytes(bundle.run["calibration"]).hex()
        if layer_of_stage is not None and len(digests) == len(layers):
            e3["identity_compared"] = True
            e3["identity_equal"] = ident == st.get("trained_statement_identity")
            if not e3["identity_equal"]:
                f.append("E3: the absorbed calibration word is not the statement's "
                         "trained_statement_identity")
        else:
            e3["identity_compared"] = False
            e3["why_not"] = ("the bundle covers layers "
                             f"{layer_of_stage}, the statement {len(layers)} layers: "
                             "a different trained-model statement")
        out["E3_statement"] = e3
    else:
        out["E3_statement"] = {"checked": False,
                               "why": "no --statement given (stage-to-layer map "
                               "and identity not checked)"}
    # E4
    tabs = _recovered_tables(record)
    if tabs is None:
        out["E4_tables"] = {"checked": False, "why": "no recovered tables in "
                            "this pass (stage 3 or 8 of this bundle needed)"}
    elif layer_of_stage is None:
        out["E4_tables"] = {"checked": False, "why": "no stage-to-layer map "
                            "(needs --statement)"}
        f.append("E4: recovered tables present but no stage-to-layer map to "
                 "compare them with")
    else:
        exps, acts, src = tabs
        f_e = sh.get("f_e")
        rows = []
        for k, layer in enumerate(layer_of_stage):
            d = os.path.join(export_dir, f"layer_{layer:02d}")
            want_e, ev = _table_sha(os.path.join(d, "exp.bin"), 8)
            want_a, av = _table_sha(os.path.join(d, "act.bin"), 2)
            ge, ga = exps[k], acts[k]
            row = {"stage": k, "layer": layer,
                   "exp_equal": ge.get("recovered_sha256") == want_e,
                   "act_equal": ga.get("recovered_sha256") == want_a,
                   "act_128_is_zero": ga.get("act_128") == 0 and av[128] == 0,
                   "exp_0_is_2_to_f_e": ge.get("exp_0") == (1 << f_e) and ev[0] == (1 << f_e)}
            rows.append(row)
            for key in ("exp_equal", "act_equal", "act_128_is_zero", "exp_0_is_2_to_f_e"):
                if not row[key]:
                    f.append(f"E4: stage {k} (layer {layer}): {key} is false")
        out["E4_tables"] = {"checked": True, "from": src, "stages": len(rows),
                            "per_stage": rows}
    out["findings"] = f
    out["ok"] = not f
    return out


def export_controls(bundle, export_dir, statement_path, record) -> dict:
    """[v5, P-9] each check above must REFUSE one in-memory perturbation; the
    honest bundle must pass.  Nothing on disk is touched."""
    import copy
    honest = export_check(bundle, export_dir, statement_path, record)
    ctl = []

    def run(name, what, mutate_bundle=None, mutate_record=None, want="E1"):
        run_b, saved = bundle.run, None
        rec = copy.deepcopy(record) if mutate_record else record
        if mutate_bundle:
            saved = copy.deepcopy(bundle.run)
            mutate_bundle(bundle.run)
        try:
            if mutate_record:
                mutate_record(rec)
            r = export_check(bundle, export_dir, statement_path, rec)
        finally:
            if saved is not None:
                bundle.run.clear()
                bundle.run.update(saved)
        named = [x for x in r["findings"] if x.startswith(want)]
        ctl.append({"control": name, "what": what, "ok_under_perturbation": r["ok"],
                    "findings_naming_it": named[:3], "fires": (not r["ok"]) and bool(named)})
        _ = run_b

    run("EX-1", "sh_qkv moved by one in run.json's shape",
        mutate_bundle=lambda r: r["shape"].__setitem__("sh_qkv", r["shape"]["sh_qkv"] - 1),
        want="E1")
    run("EX-2", "norm_ceps moved by one in run.json's shape",
        mutate_bundle=lambda r: r["shape"].__setitem__("norm_ceps", r["shape"]["norm_ceps"] + 1),
        want="E1")
    run("EX-3", "the parameter line's sh-g field moved by one",
        mutate_bundle=lambda r: r.__setitem__("parameter_line", PARAM_SH.sub(
            lambda m: f"/sh-g{int(m.group(1)) + 1}-u0-h{m.group(2)}-z{m.group(3)}/",
            r["parameter_line"], count=1)),
        want="E2")
    if statement_path:
        def swap_digest(r):
            d = list(r["block_digests"][0])
            d[0] ^= 1
            r["block_digests"][0] = d
        run("EX-4", "stage 0's block digest flipped (no longer a statement layer)",
            mutate_bundle=swap_digest, want="E3")

        def flip_ident(r):
            c = list(r["calibration"])
            c[0] ^= 1
            r["calibration"] = c
        if honest.get("E3_statement", {}).get("identity_compared"):
            run("EX-5", "the absorbed calibration word flipped",
                mutate_bundle=flip_ident, want="E3")
    if (honest.get("E4_tables") or {}).get("checked"):
        def flip_tab(rec):
            src = honest["E4_tables"]["from"].split("/")
            node = rec
            for k in src:
                node = node[k]
            det = node["public_table_structure_detail"]["act_values"][0]
            det["recovered_sha256"] = "0" * 64
        run("EX-6", "stage 0's recovered SiLU table digest replaced",
            mutate_record=flip_tab, want="E4")
    applicable = [c for c in ctl]
    return {"honest_ok": honest["ok"], "controls": ctl,
            "all_fire": bool(applicable) and all(c["fires"] for c in applicable),
            "ok": honest["ok"] and bool(applicable) and all(c["fires"] for c in applicable)}


def main(argv=None):
    from zk60_native_rg_block import load_bundle
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--export", required=True)
    ap.add_argument("--statement")
    ap.add_argument("--record")
    ap.add_argument("--controls", action="store_true")
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    a = ap.parse_args(argv)
    rec = json.load(open(a.record)) if a.record else None
    b = load_bundle(a.bundle)
    out = export_check(b, a.export, a.statement, rec)
    if a.controls:
        out["controls"] = export_controls(b, a.export, a.statement, rec)
        out["ok"] = out["ok"] and out["controls"]["ok"]
    out["tool_sha256"] = _sha_file(os.path.abspath(__file__))
    os.makedirs(a.evidence, exist_ok=True)
    p = os.path.join(a.evidence, f"{a.name}.json")
    with open(p, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(f"record: {p}   ok={out['ok']}   findings {len(out['findings'])}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
