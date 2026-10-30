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

[v17, gate round 14] PER-LAYER CONSTANTS.  An export whose layers carry
their own constants lists them in `profile.json["per_layer_constants_differ"]`
and leaves them null in `profile_constants` (`tinyllama_dg_rot1_T128`:
norm_cn_a, norm_cn_m, sh_ao, sh_h, sh_s, sh_z).  Native R8 then proves the run
at a RUN calibration (`trained_block.rs` `run_constants`: each per-layer field
the value tuple most of the run's layers carry, ties the smallest, fields in
OWN_FIELDS order) and each layer that differs at its own (the stage line's
clauses).  Tools v16 compared the run shape's per-layer fields with null and
refused every such bundle.  v17:

  E0  the export's integrity (`zk60_native_rg_tokenblocks.load_export`, X8):
      every layer manifest hashes to profile.json's, every array to its
      manifest, and every non-per-layer constant equals profile_constants;
  E1  a per-layer field of the run shape equals the RUN calibration computed
      from the run's export layers (above); every other field as before;
  E3b (without --statement) each stage's layer IDENTIFIED from its slot-14
      gains (the two public gamma tables, bound by the stage-8 terminal
      identity) against every export layer, exactly one match each; the
      README's declared layer list (not transcript-bound) must agree; with
      --statement, the identification must agree with E3's map;
  E5  each stage's calibration (the run shape plus its stage line's own
      clauses, `zk60_native_rg_stagecal`, bound to the schedule digest)
      equals its export layer's eleven constants.

E1's per-layer part, E4 and E5 need the stage-to-layer map (E3 or E3b); a
missing map is a refusal by name, never a pass.

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

README_LAYERS_LIST = re.compile(r"layers \[([\d, ]*)\]")
GAMMA_SLOT = 14
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


def SCAL_OWN(bundle) -> list:
    """[v17] per stage: does its schedule line carry an own clause"""
    import zk60_native_rg_stagecal as SCAL
    return [bool(SCAL.OWN_CLAUSE.search(ln)) for ln in bundle.run.get("stage_lines") or []]


def _readme_layers(bundle):
    """the README's declared export layers (`layers [a, b, ..]`), or None"""
    p = os.path.join(getattr(bundle, "dir", ""), "README.md")
    if not os.path.exists(p):
        return None
    m = README_LAYERS_LIST.search(open(p).read())
    if not m:
        return None
    return [int(x) for x in m.group(1).replace(" ", "").split(",") if x != ""]


def _layers_by_gamma(bundle, exp) -> dict:
    """[v17] E3b: each stage's slot-14 gains against every export layer"""
    from zk60_native_jv_field import P, f2_from_list
    width = int(bundle.run["shape"]["width"])
    rows, f, lay = [], [], []
    for st in bundle.stages:
        pubs = [t for t in st.doc["arguments"][GAMMA_SLOT]["tables"] if t["kind"] == "public"]
        match = []
        if len(pubs) >= 2 and all("values" in t for t in pubs[:2]):
            v0, v1 = pubs[0]["values"], pubs[1]["values"]
            ga = [f2_from_list(v0[i]) for i in range(width)]
            gm = [f2_from_list(v1[i]) for i in range(width)]
            for layer, L_ in sorted(exp["layers"].items()):
                tab = L_["tables"]
                if (len(tab["gamma_a"]) == width
                        and all(ga[i] == (tab["gamma_a"][i] % P, 0) for i in range(width))
                        and all(gm[i] == (tab["gamma_m"][i] % P, 0) for i in range(width))):
                    match.append(layer)
        else:
            f.append(f"stage {st.index}: slot {GAMMA_SLOT} carries no two public gain tables "
                     "with values (a capture without public tables)")
        if len(match) != 1:
            f.append(f"stage {st.index}: the gains match export layers {match}, not exactly one")
        rows.append({"stage": st.index, "layers_matching": match})
        lay.append(match[0] if len(match) == 1 else None)
    return {"per_stage": rows, "findings": f,
            "layer_of_stage": lay if not f else None, "ok": not f}


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
    # [v17] E0: the export's integrity and every layer's constants
    per_layer = list(prof.get("per_layer_constants_differ") or [])
    exp = None
    try:
        import zk60_native_rg_tokenblocks as TB
        exp = TB.load_export(export_dir)
        out["E0_export_integrity"] = {"ok": exp["X8"]["ok"], "layers": len(exp["layers"]),
                                      "per_layer_constants_differ": per_layer}
        f.extend(f"E0: {x}" for x in exp["findings"])
    except Exception as exc:  # noqa: BLE001
        out["E0_export_integrity"] = {"ok": False, "error": f"{type(exc).__name__}: {exc}"}
        f.append(f"E0: the export does not load ({type(exc).__name__}: {exc})")
    # E1
    e1 = {}
    deferred = []
    for key in CONSTANTS:
        got, want = sh.get(key), pc.get(key)
        if key in per_layer:
            # [v17] compared below with the run calibration of the run's layers
            deferred.append(key)
            e1[key] = {"bundle": got, "export": want, "per_layer": True}
            continue
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
    # [v17] E3b: each stage's layer identified from its gains
    gm = _layers_by_gamma(bundle, exp) if exp is not None else None
    declared = _readme_layers(bundle)
    e3b = {"identified": gm, "readme_declared_layers": declared,
           "what": "slot 14's two public gamma tables of each stage against every "
                   "export layer's gamma_a / gamma_m; the README list is not "
                   "transcript-bound and is only compared"}
    map_source = "E3 (the statement)" if layer_of_stage is not None else None
    if gm is not None and gm.get("layer_of_stage") is not None:
        if layer_of_stage is None:
            layer_of_stage, map_source = gm["layer_of_stage"], "E3b (the gains)"
        elif gm["layer_of_stage"] != layer_of_stage:
            f.append(f"E3b: the gains identify layers {gm['layer_of_stage']}, the "
                     f"statement {layer_of_stage}")
    elif gm is not None and layer_of_stage is None and (
            deferred or any(SCAL_OWN(bundle)) or _recovered_tables(record) is not None):
        # a refusal only where a check below needs the map
        f.extend(f"E3b: {x}" for x in gm["findings"])
    if declared is not None and layer_of_stage is not None and declared != layer_of_stage:
        f.append(f"E3b: the README declares layers {declared}, the stages are layers "
                 f"{layer_of_stage}")
    e3b["layer_of_stage"], e3b["map_source"] = layer_of_stage, map_source
    out["E3b_layers_by_gamma"] = e3b
    # [v17] E1 (per-layer fields) and E5 (each stage's calibration)
    if deferred or any(SCAL_OWN(bundle)):
        if layer_of_stage is None or exp is None:
            f.append(f"E1: per-layer constant(s) {deferred} cannot be checked: no "
                     "stage-to-layer map (E3 / E3b)")
        else:
            cals = TB.calibrations(exp, layer_of_stage)
            out["E1_run_calibration"] = {"layers": layer_of_stage,
                                         "run_values": cals["run_values"],
                                         "per_layer_fields": cals["per_layer_fields"],
                                         "tally": cals["run_value_tally"],
                                         "rule": cals["rule"]}
            for key in deferred:
                got, want = sh.get(key), cals["run_values"].get(key)
                e1[key].update({"run_calibration": want, "equal": got == want})
                if got != want:
                    f.append(f"E1: {key} is {got} in the bundle and {want} in the run "
                             f"calibration of export layers {layer_of_stage}")
            e5 = {"per_stage": []}
            try:
                import zk60_native_rg_stagecal as SCAL
                shapes, srec = SCAL.stage_shapes(bundle.run)
                e5["stage_lines"] = srec
                for k, layer in enumerate(layer_of_stage):
                    want = cals["stage_values"][k]
                    got = {key: int(shapes[k][key]) for key in want}
                    diff = sorted(key for key in want if got[key] != int(want[key]))
                    e5["per_stage"].append({"stage": k, "layer": layer,
                                            "at_its_own_calibration": shapes[k] is not sh,
                                            "differing": diff, "ok": not diff})
                    for key in diff:
                        f.append(f"E5: stage {k} (layer {layer}) is proved at {key} "
                                 f"{got[key]}, the export layer's is {want[key]}")
            except ValueError as exc:
                f.append(f"E5: the stage lines do not give each stage's calibration ({exc})")
            out["E5_stage_calibration"] = e5
    # E4
    tabs = _recovered_tables(record)
    if tabs is None:
        out["E4_tables"] = {"checked": False, "why": "no recovered tables in "
                            "this pass (stage 3 or 8 of this bundle needed)"}
    elif layer_of_stage is None:
        out["E4_tables"] = {"checked": False, "why": "no stage-to-layer map "
                            "(needs --statement or E3b's identification)"}
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
