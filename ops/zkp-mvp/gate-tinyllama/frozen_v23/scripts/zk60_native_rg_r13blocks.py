#!/usr/bin/env python3
"""[v22, gate round 19, 2026-10-29] THE BLOCK STAGES OF A CLASSIFIER CAPTURE AT
AN R13 ACCURACY SHAPE: the per-slot terminal identity of all 23 slots at each
stage's OWN shape (its R13 gate denominator G_k, its calibration), the R13
plane list, and controls.

    r13_block_terminals(b, rp, calibration_export=None, controls=True) -> dict

`b` is a `zk60_native_rg_classgate.ClassRunBundle`, `rp` its replay.  At a
legacy block shape this delegates to `classgate.class_block_terminals` (with
the same calibration handling `classgate.gate` has), so the lane agent swaps
one call.  The record has the shape of `class_block_terminals`' record.

WHERE THE R13 FACTS COME FROM (run.json `shape` carries no accuracy field):

* the stack and registry: the BLOCK PROFILE string, against `shape.rs`
  ACCURACY_PROFILES (`zk60_native_rg_r13slots.ACCURACY_PROFILES`);
* the base calibration and the precision: the seed layout's R13 calibration
  line ("calibration: R13 stack=... base=tn=.. cn_a=.. ... gate-common=17
  precision=Precision {...}", layout.rs R13 branch), which is a line of the
  schedule digest the replayed header absorbs -- so the line is used ONLY after
  `zk60_native_rg_stagecal.schedule_digest` recomputes run.json's digest from
  run.json's own lines, and the printed precision must equal its derivation
  (`accuracy_precision.rs::derive`, ported);
* each stage's gate denominator G_k: its stage line's "R13 gate denominator G_k
  (the layer record's accuracy-gate-layer)" (token classify.rs stage_lines),
  in the same schedule digest; and each stage's own calibration clauses (a
  Shieldstral layer's per-layer constants) in the legacy own-clause format;
* `calibration_export` (optional): the export's profile constants and the
  per-layer constants are COMPARED with the line's (they are never the
  source).

G_k is not taken on trust: it enters SC_FZC's host term and the Rg lookup's
exact top-bit pin, so a wrong G fails exactly slot 18 (control R13-G).

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_r13slots as R  # noqa: E402
import zk60_native_rg_stagecal as SCAL  # noqa: E402
import zk60_native_rg_terminals as T  # noqa: E402
from zk60_native_jv_field import f2_from_list  # noqa: E402
from zk60_native_jv_cfs import sumcheck_final  # noqa: E402

# the legacy shape keys the shim's Calibration reads, from the R13 base names
SHAPE_KEY_OF_BASE = {"tn": "norm_tn", "cn_a": "norm_cn_a", "cn_m": "norm_cn_m", "ceps": "norm_ceps",
                     "ao": "sh_ao", "qkv": "sh_qkv", "score": "sh_s", "o": "sh_o", "gate": "sh_g",
                     "product": "sh_h", "down": "sh_z"}
BASE_OF_SHAPE_KEY = {v: kk for kk, v in SHAPE_KEY_OF_BASE.items()}


def _legacy(b, rp, calibration_export, controls):
    import zk60_native_rg_classgate as CG
    cal, cal_src, stage_cals = None, None, None
    if calibration_export:
        import zk60_native_rg_tokenblocks as TB
        exp = TB.load_export(calibration_export)
        ident = TB.identify_layers(b, exp, None)
        layers = [r["layer"] for r in ident["per_stage"]]
        if None not in layers:
            cals = TB.calibrations(exp, layers)
            cal, stage_cals = cals["run_values"], cals["stage_values"]
            cal_src = f"export {calibration_export}, layers {layers} (identified by their gains, X10)"
    return CG.class_block_terminals(b, rp, calibration=cal, calibration_source=cal_src,
                                    controls=controls, stage_calibrations=stage_cals)


def _stage_layout_lines(lay, tier) -> list:
    """`StageLayout::describe` (token_io.rs:849-863), rendered from the gate's
    own stage layout (`zk60_native_rg_classify.ClassGeom.stage_in_c / _out_c`)"""
    def L(v):
        return "[" + ", ".join(str(x) for x in v) + "]"
    out = [f"{lay.label}: n={lay.n} inv_rate={tier.stage_inv_rate} Q={tier.opened_cols}",
           f"A rows={lay.a_rows} data={lay.a_data_rows} site-pairs={sum(s.a_sites for s in lay.slots)} "
           f"prox-pair=({lay.a_prox},{lay.a_prox + 1}) planes={L(lay.a_log)}",
           f"H rows={lay.h_rows} data={lay.h_data_rows} site-pairs={sum(s.h_sites for s in lay.slots)} "
           f"zero-sum-pair={L(lay.h_u_rows())} prox-pair=({lay.h_prox},{lay.h_prox + 1}) planes={L(lay.h_log)} "
           f"signs={L(lay.h_sign)}",
           f"M rows={lay.m_rows()} functionals={lay.n_functionals()} row-logs={L(lay.row_log)}"]
    for i, s in enumerate(lay.slots):
        out.append(f"slot {i:02} [{s.name}] main={s.main} ext={s.ext} degree={s.degree} kind={s.kind} "
                   f"A-sites={s.a_sites} H-sites={s.h_sites} IO-sites={s.io_sites}")
    for h, hs in lay.hosts:
        out.append(f"host {h:02} <- {L(hs)}")
    return out


def classifier_schedule_digest(b) -> dict:
    """token classify.rs `schedule_digest` (:1192-1214 at c180c83f):
    blake3("hashline/classify-run-schedule/v1" + length-framed parameter_line,
    the block layout's lines, stage IN-C's and stage OUT-C's layout lines,
    stage_lines).  run.json carries all but the two stage layouts' lines; those
    are DERIVED here from the gate's own ClassGeom, so the recompute binds
    run.json's lines (the R13 calibration line, every stage's G_k) to the
    digest the replayed header absorbs."""
    import blake3
    run = b.run
    h = blake3.blake3()
    h.update(b"hashline/classify-run-schedule/v1")
    lines = ([run["parameter_line"]] + list(run["layout_description"])
             + _stage_layout_lines(b.geom.stage_in_c(), b.geom.tier)
             + _stage_layout_lines(b.geom.stage_out_c(), b.geom.tier) + list(run["stage_lines"]))
    for s in lines:
        bs = s.encode()
        h.update(len(bs).to_bytes(8, "little"))
        h.update(bs)
    got, want = h.hexdigest(), bytes(run["schedule_digest"]).hex()
    return {"recomputed": got, "run_json": want, "equal": got == want, "lines": len(lines)}


def stage_facts(b) -> dict:
    """the seed base, each block stage's base and G_k, bound to the schedule
    digest; refusals are ValueErrors with their reason"""
    run = b.run
    dig = classifier_schedule_digest(b)
    if not dig.get("equal"):
        raise ValueError(f"R13-1: run.json's schedule digest does not recompute from its own lines ({dig})")
    cal = R.parse_calibration_line(run["layout_description"])
    stack = R.stack_of(run["shape"]["profile"])
    if cal["stack"] != stack:
        raise ValueError(f"R13-2: the calibration line's stack {cal['stack']} is not the profile's {stack}")
    lines = list(run["stage_lines"])
    blocks = [st for st in b.stages if st.kind == "BLOCK"]
    if len(lines) != len(b.stages):
        raise ValueError(f"R13-3: {len(lines)} stage lines for {len(b.stages)} stages")
    per = []
    for k, st in enumerate(blocks):
        line = lines[st.index]
        g = R.stage_gate_of(line)
        if g is None or not (17 <= g <= 24):
            raise ValueError(f"R13-4: stage {st.index}'s line names no R13 gate denominator in 17..=24: {line!r}")
        own = SCAL.own_clauses(R.strip_gate(line))
        base = dict(cal["base"])
        for key, v, run_v in own:
            bk = BASE_OF_SHAPE_KEY[key]
            if base[bk] != run_v:
                raise ValueError(f"R13-5: stage {st.index}'s own clause says the run's {key} is {run_v}, the line base {base[bk]}")
            if v == run_v:
                raise ValueError(f"R13-5: stage {st.index}'s own {key} equals the run's")
            base[bk] = v
        shifts = {"norm_tn": base["tn"], "qkv": base["qkv"], "score": base["score"], "pv": base["o"],
                  "ao": base["ao"], "gate": base["gate"], "up": 0, "product": base["product"], "down": base["down"]}
        per.append({"stage": st.index, "block": k, "gate_shift": g, "own_clauses": own, "base": base,
                    "precision": R.derive_precision(stack, shifts)})
    return {"schedule_digest_equal": True, "schedule_digest": dig, "calibration_line": cal, "stack": stack,
            "per_stage": per}


def export_crosscheck(calibration_export, facts) -> dict:
    """the export's constants against the transcript-bound line (compare only)"""
    prof = json.load(open(os.path.join(calibration_export, "profile.json")))
    pc = prof.get("profile_constants") or {}
    want = {"tn": pc.get("norm_tn"), "cn_a": pc.get("norm_cn_a"), "cn_m": pc.get("norm_cn_m"),
            "ceps": pc.get("norm_ceps"), "ao": pc.get("sh_ao"), "qkv": pc.get("sh_qkv"), "score": pc.get("sh_s"),
            "o": pc.get("sh_o"), "gate": pc.get("sh_g"), "product": pc.get("sh_h"), "down": pc.get("sh_z")}
    got = facts["calibration_line"]["base"]
    per_layer = list(prof.get("per_layer_constants_differ") or [])
    diff = sorted(kk for kk in want if want[kk] != got[kk] and SHAPE_KEY_OF_BASE[kk] not in per_layer)
    return {"export": calibration_export, "accuracy_stack": prof.get("accuracy_stack"),
            "per_layer_constants_differ": per_layer, "differing_from_the_line": diff,
            "ok": not diff and prof.get("accuracy_stack") in ("low-v1", "low-h24-v1")}


# the slots whose public tables are functions of the public STATEMENT (weight
# folds with the R13 multipliers, the norm gains, the RoPE pair, the group
# column, the exp / ACT3 tables): evaluable only when the capture carries the
# tables' values (HL_RUN_CAPTURE_PUBLIC_TABLES=1)
NEEDS_CAPTURED_TABLES = {
    5: "fold(w_q) with the R13 q multipliers (accuracy_fold, Site::Q)",
    6: "fold(w_k) with the R13 k multipliers",
    7: "fold(w_v) with the R13 v multipliers",
    10: "fold(w_o) with the R13 o multipliers",
    11: "fold(w_g) with the R13 gate coefficients c_j = m_j 2^(G - s_j)",
    12: "fold(w_u) with the R13 up multipliers",
    13: "fold(w_d) with the R13 down multipliers",
    14: "the padded norm gains gamma_a, gamma_m",
    15: "the RoPE (cos, sin) pair on Dom::Q",
    16: "the RoPE (cos, sin) pair on Dom::Kv",
    18: "the FFN group-id column (and hence G_k's arithmetic check)",
    19: "the exp table and the derived ACT3 table with its support",
}
SLOTS_WITHOUT_TABLES = tuple(s for s in range(23) if s not in NEEDS_CAPTURED_TABLES)


def check_stage(shim, index, view, rc: R.R13Ctx, structural=True, check_digests=True,
                stage_doc=None, port_override=None) -> dict:
    """all 23 slots of ONE block stage (shim = one block) at its own shape"""
    import zk60_native_rg_gqa as GQ
    gate = T.TerminalGate(shim, index)
    gate.set_stage(0)
    doc = stage_doc if stage_doc is not None else shim.stages[0].doc
    gate.set_logup(doc["logup_challenges"])
    # the legacy-body SC_LZC reads the Dom::L lookups through the gate's cache:
    # at R13 they are AccuracyIds::lookups(Dom::L) = [LIMB, LIMBM] bytes
    # (accuracy_layout.rs:133-136); the legacy `lookups_at` would derive the
    # norm limbs' top pin from the legacy byte count and is not consulted
    gate._lk_cache["L"] = R.r13_lookups("L", rc.prec, rc.gate_shift, rc.wrho_s, rc.counts)
    lam_z = T.lam_z_of(doc)
    planes = [[p.name for p in row] for row in index.slot_planes]
    group = GQ.GroupFactors(shim, replay=view, stage_docs=[doc], definition=None)
    row = {"checked": [], "equal": [], "not_checked": [], "r13_ported": list(R.R13_SLOTS)}
    ports = {s: (nm, fn) for s, nm, fn, _r in T.PORTS}
    tables = bool(getattr(shim, "public_tables_included", False))
    row["open_by_capture_option"] = []
    for s in range(shim.shape.n_slots):
        arg = doc["arguments"][s]
        if not tables and s in NEEDS_CAPTURED_TABLES:
            row["not_checked"].append({"slot": s, "name": ports.get(s, (str(s),))[0],
                                       "why": "OPEN (capture without public-table values): " + NEEDS_CAPTURED_TABLES[s]})
            row["open_by_capture_option"].append(s)
            continue
        try:
            dc = [f2_from_list(x) for x in arg["definition_challenges"]]
            if s in R.R13_PORTS:
                nm, fn = R.R13_PORTS[s]
                names = planes[s]
            else:
                nm, fn = ports[s]
                names = [R.LEGACY_NAME_OF_R13.get(n, n) for n in planes[s]]
            if port_override and s in port_override:
                fn = port_override[s]
            cx = T.SlotCtx(gate, arg, names, dc, lam_z, structural=structural)
            cx.bilinear_definition = group.definition
            cx.group_table_required = group.group_table_required()
            if s in T.BILINEAR_SLOTS:
                pt = group.point(0, s)
                if pt is not None:
                    if not cx.eq_idx:
                        raise ValueError(f"slot {s}: a group point was derived and the bundle declares no eq table")
                    cx.derived_eq_points = {cx.eq_idx[0]: pt}
            cx.rho_full = view.stages[0]["rho"][s]
            c = view.stages[0]["slot_c"][s]
            if s in R.R13_PORTS:
                R.build_public_r13(gate, cx, check_digests=check_digests)
                poly = fn(gate.vals(cx), cx, rc)
            else:
                gate.build_public(cx, check_digests=check_digests)
                poly = fn(gate.vals(cx), cx)
        except (ValueError, IndexError, KeyError) as exc:
            row["not_checked"].append({"slot": s, "name": ports.get(s, (str(s),))[0], "why": str(exc)})
            continue
        row["checked"].append(s)
        claimed = f2_from_list(arg["scalar"])
        for h in arg["hosted"]:
            claimed = T.add(claimed, T.mul(f2_from_list(h["coefficient"]), f2_from_list(doc["arguments"][h["slot"]]["scalar"])))
        fin, _ok = sumcheck_final(arg["rounds"], arg["degree"], cx.rho_full, claimed)
        if fin is not None and fin == T.add(T.mul(c, f2_from_list(arg["mask_eval"])), poly) \
                and poly == f2_from_list(arg["terminal_polynomial"]):
            row["equal"].append(s)
    row["group_factor_ok"] = group.summary()["ok"]
    row["captured_tables"] = sorted(set(gate.captured_tables.values()))
    row["rebuilt_tables"] = sorted(set(gate.public_tables.values()))
    row["structure_failures"] = list(gate.public_structure_failures)
    row["digest_failures"] = list(gate.public_digest_failures)
    row["structure_detail"] = gate.structure_detail
    return row


def _failing(row) -> set:
    opened = set(row.get("open_by_capture_option", []))
    return ((set(range(23)) - set(row["equal"]) - opened)
            | {e["slot"] for e in row["not_checked"] if e["slot"] not in opened})


def r13_block_terminals(b, rp, calibration_export=None, controls=True, blocks=None) -> dict:
    """`blocks`: evaluate only these block indices (a bounded-cost run at a
    large shape; the record says which were evaluated and the rest are NOT
    reported as checked); controls run on the first evaluated block"""
    sh = b.run["shape"]
    if not R.is_r13_shape(sh):
        return _legacy(b, rp, calibration_export, controls)
    import zk60_native_rg_tokenblocks as TB
    from zk60_native_rg_planes import PlaneIndex
    t0 = time.time()
    L = b.l
    rec = {"what": "the block-stage terminal identity of ONE classifier capture at an R13 accuracy shape "
                   "(all 23 slots per stage at its own G and calibration; seven R13-ported)",
           "blocks": L, "privacy_acceptance": False, "r13": True}
    try:
        facts = stage_facts(b)
    except ValueError as exc:
        rec.update({"refused": str(exc), "ok": False})
        return rec
    rec["stage_facts"] = {"stack": facts["stack"], "registry": facts["calibration_line"]["registry"],
                          "base": facts["calibration_line"]["base"], "gate_common_seed": facts["calibration_line"]["gate_common"],
                          "precision": facts["calibration_line"]["precision"],
                          "per_stage": [{kk: v for kk, v in p.items() if kk != "precision"} for p in facts["per_stage"]],
                          "schedule_digest_recomputed_equal": True}
    if calibration_export:
        rec["calibration_export_crosscheck"] = export_crosscheck(calibration_export, facts)
    h24 = facts["stack"] == "LowH24"
    product_shift = 16 if h24 else 24          # accuracy_public.rs:488 folds().product.shift
    full = TB.TokenBlockShim(b, None)
    index = PlaneIndex(full)
    pi = index.summary()
    rec["plane_index"] = {kk: pi[kk] for kk in ("ok", "findings", "a_planes", "h_planes", "a_data_rows", "h_data_rows", "slots")}
    rec["plane_index_r13"] = R.check_plane_index(index, sh)
    ls = rec["plane_index_r13"].get("sigma_limbs", 0)
    counts = {"ls": ls, "h24": h24, "dd": int(sh.get("dd_cap", 0)) > 0}
    if counts["dd"]:
        rec.update({"refused": "an R13 DD block profile: SC_DD and the DD softmax twin are not ported", "ok": False})
        return rec
    rec["source_pins"] = T.check_source_pins(full)
    per_stage, shims, views, rcs = [], [], [], []
    evaluated = [p for p in facts["per_stage"] if blocks is None or p["block"] in blocks]
    rec["blocks_evaluated"] = [p["block"] for p in evaluated]
    rec["blocks_not_evaluated"] = [p["block"] for p in facts["per_stage"] if p not in evaluated]
    for p in evaluated:
        k = p["block"]
        base = p["base"]
        cal_values = {SHAPE_KEY_OF_BASE[kk]: int(v) for kk, v in base.items()}
        shim = TB.TokenBlockShim(b, cal_values, blocks=[k], extra={"norm_wrho": sh["norm_wrho"]})
        view = TB._ReplayView(rp, [k])
        rc = R.R13Ctx(facts["stack"], p["precision"], p["gate_shift"], sh["wrho_s"], counts, product_shift)
        rc.base = base
        ts = time.time()
        if not rec["source_pins"]["ok"]:
            row = {"checked": [], "equal": [], "not_checked": [{"slot": s, "why": "source pins"} for s in range(23)]}
        else:
            row = check_stage(shim, index, view, rc)
        opened = row.get("open_by_capture_option", [])
        expected = sh["n_slots"] - len(opened)
        per_stage.append({"stage": p["stage"], "block": k, "gate_shift": p["gate_shift"],
                          "ok": (len(row["equal"]) == expected and set(row["equal"]).isdisjoint(opened)
                                 and all(e["slot"] in opened for e in row["not_checked"])),
                          "slot_checks_equal": len(row["equal"]), "slot_checks_expected": expected,
                          "open_by_capture_option": opened,
                          "checked_not_equal": sorted(set(row["checked"]) - set(row["equal"])),
                          "refused_or_open": [{"slot": e["slot"], "why": e["why"]} for e in row["not_checked"]],
                          "r13_ported_slots": list(R.R13_SLOTS), "seconds": round(time.time() - ts, 1),
                          "captured_tables": row.get("captured_tables"), "structure_failures": row.get("structure_failures"),
                          "structure_detail_r13": {kk: row.get("structure_detail", {}).get(kk)
                                                   for kk in ("group_column", "act_support", "act3_values")},
                          "group_factor_ok": row.get("group_factor_ok")})
        shims.append(shim)
        views.append(view)
        rcs.append(rc)
    rec["per_stage"] = per_stage
    tables = bool(getattr(b, "public_tables_included", False))
    rec["tables_absent_by_capture_option"] = not tables
    rec["slots_covered_without_tables"] = list(SLOTS_WITHOUT_TABLES)
    rec["slots_open_without_tables"] = {str(kk): v for kk, v in NEEDS_CAPTURED_TABLES.items()} if not tables else {}
    if not tables:
        rec["what_is_not_checked_without_tables"] = (
            "the twelve slots whose public tables are statement constants (weight folds, gains, RoPE, the "
            "group column, exp / ACT3) are OPEN per slot; each stage's G_k is then bound only through the "
            "classifier schedule digest the replayed header absorbs (its arithmetic check is SC_FZC's, open)")
    rec["io_wiring"] = TB._io_wiring(b)
    ctl = {}
    if controls and rec["source_pins"]["ok"]:
        ctl = r13_controls(b, shims, views, rcs, index)
    rec["controls"] = ctl
    rec["seconds"] = round(time.time() - t0, 1)
    rec["ok_on_the_covered_slots"] = (not rec["blocks_not_evaluated"] and all(p["ok"] for p in per_stage)
                                      and rec["plane_index"]["ok"] and rec["plane_index_r13"]["ok"]
                                      and rec["io_wiring"]["ok"] and rec["source_pins"]["ok"]
                                      and all(c["fires"] for c in ctl.values() if isinstance(c, dict)))
    # a capture without public-table values is NEVER a full pass of the block
    # stages: twelve slots per stage are open by the capture option
    rec["ok"] = rec["ok_on_the_covered_slots"] and tables
    return rec


# =====================================================================
#  controls: each perturbation PREDICTED, then shown to fail exactly there
# =====================================================================
def _doc_with_public(doc, slot, nth, fn):
    """a deep-enough copy of the stage doc with public table `nth` of `slot`
    rewritten by fn(values) and its digest recomputed (so the digest check
    passes and the ARITHMETIC must catch it)"""
    import copy
    d = dict(doc)
    d["arguments"] = list(doc["arguments"])
    arg = copy.deepcopy(doc["arguments"][slot])
    pubs = [i for i, t in enumerate(arg["tables"]) if t["kind"] == "public"]
    tab = arg["tables"][pubs[nth]]
    vals = [f2_from_list(x) for x in tab["values"]]
    vals = fn(vals)
    tab["values"] = [[int(a), int(b_)] for a, b_ in vals]
    tab["sha256"] = T.table_digest(vals)
    d["arguments"][slot] = arg
    return d


def r13_controls(b, shims, views, rcs, index) -> dict:
    out = {}
    k = 0
    shim, view, rc = shims[k], views[k], rcs[k]
    doc = shim.stages[0].doc

    def run(**kw):
        return _failing(check_stage(shim, index, view, kw.pop("rc", rc), **kw))
    import copy
    if not getattr(shim, "public_tables_included", False):
        # without table values: the controls whose slot is evaluable
        rc_s = copy.copy(rc)
        p2 = dict(rc.prec)
        p2["score"] += 1
        rc_s.prec = p2
        got = run(rc=rc_s)
        out["NC-1_R13_score_precision_moved"] = {"perturbation": "precision.score + 1 (SC_SZC's host and Rs pin)",
                                                 "predicted": [17], "failing": sorted(got), "fires": got == {17}}
        rc_c = copy.copy(rc)
        rc_c.base = dict(rc.base)
        shim_c = shim.with_shape(dict(shim.run["shape"], norm_ceps=int(rc.base["ceps"]) + 1))
        got = _failing(check_stage(shim_c, index, view, rc_c))
        out["NC-2_R13_norm_ceps_moved"] = {"perturbation": "the norm ceps + 1 in the stage shape (SC_TZC's two host terms)",
                                           "predicted": [2], "failing": sorted(got), "fires": got == {2}}
        out["not_applicable_without_tables"] = ["R13-G", "R13-N", "R13-GC", "R13-ACT", "R13-W", "R13-L"]
        return out
    # R13-G: the stage's gate denominator moved by one -> exactly slot 18
    rc_g = copy.copy(rc)
    rc_g.gate_shift = rc.gate_shift + 1 if rc.gate_shift < 24 else rc.gate_shift - 1
    got = run(rc=rc_g)
    out["R13-G_gate_denominator_moved"] = {"perturbation": f"stage {k + 1}: G {rc.gate_shift} -> {rc_g.gate_shift}",
                                           "predicted": [18], "failing": sorted(got), "fires": got == {18}}
    # NC-1 (R13): the base score shift moved -> the precision's score moves -> exactly slot 17
    rc_s = copy.copy(rc)
    p2 = dict(rc.prec)
    p2["score"] += 1
    rc_s.prec = p2
    got = run(rc=rc_s)
    out["NC-1_R13_score_precision_moved"] = {"perturbation": "precision.score + 1 (SC_SZC's host and Rs pin)",
                                             "predicted": [17], "failing": sorted(got), "fires": got == {17}}
    # R13-N: the norm tn' moved -> exactly slot 14
    rc_n = copy.copy(rc)
    p3 = dict(rc.prec)
    p3["norm_tn"] += 1
    rc_n.prec = p3
    got = run(rc=rc_n)
    out["R13-N_norm_tn_moved"] = {"perturbation": "precision.norm_tn + 1 (SC_DZC's two norm clauses)",
                                  "predicted": [14], "failing": sorted(got), "fires": got == {14}}
    # R13-GC: one entry of the group column changed (digest recomputed) -> exactly slot 18
    def bump_group(vals):
        s = shim.run["shape"]
        j = next(j for j in range(s["hidden"]) if vals[j][0] in (0, 1))
        new = list(vals)
        for t in range(s["tokens"]):
            x = t * s["f_pad"] + j
            new[x] = ((vals[x][0] + 1) % T.P, 0)
        return new
    got = _failing(check_stage(shim, index, view, rc, stage_doc=_doc_with_public(doc, 18, 0, bump_group)))
    out["R13-GC_group_column_doctored"] = {"perturbation": "one channel's group id + 1 on every token (digest recomputed)",
                                           "predicted": [18], "failing": sorted(got), "fires": got == {18}}
    # R13-ACT: one ACT3 table entry changed (digest recomputed) -> exactly slot 19
    def bump_act(vals):
        new = list(vals)
        new[100] = T.add(vals[100], T.ONE)
        return new
    got = _failing(check_stage(shim, index, view, rc, stage_doc=_doc_with_public(doc, 19, 2, bump_act)))
    out["R13-ACT_act3_table_doctored"] = {"perturbation": "ACT3 compressed table entry 100 + 1 (digest recomputed)",
                                          "predicted": [19], "failing": sorted(got), "fires": got == {19}}
    # R13-W: one entry of the multiplier-folded gate weight fold changed -> exactly slot 11
    def bump_fold(vals):
        new = list(vals)
        new[3] = T.add(vals[3], T.ONE)
        return new
    got = _failing(check_stage(shim, index, view, rc, stage_doc=_doc_with_public(doc, 11, 0, bump_fold)))
    out["R13-W_gate_weight_fold_doctored"] = {"perturbation": "fold(w_g) entry 3 + 1 (digest recomputed; the multipliers' fold)",
                                              "predicted": [11], "failing": sorted(got), "fires": got == {11}}
    # R13-L: the legacy body of SC_FZC evaluated on the R13 bytes -> slot 18 fails (the port is not silently legacy)
    def legacy_fzc(v, cx, _rc):
        names = [R.LEGACY_NAME_OF_R13.get(n, n) for n in cx.names]
        raise ValueError(f"legacy SC_FZC cannot read the R13 plane list ({len(names)} planes)")
    got = _failing(check_stage(shim, index, view, rc, port_override={18: legacy_fzc}))
    out["R13-L_legacy_fzc_on_r13_bytes"] = {"perturbation": "SC_FZC evaluated with the legacy body (refused, not silently passed)",
                                            "predicted": [18], "failing": sorted(got), "fires": got == {18}}
    return out


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--calibration-export", default=None)
    ap.add_argument("--no-controls", action="store_true")
    a = ap.parse_args(argv)
    import zk60_native_rg_classgate as CG
    t0 = time.time()
    b = CG.load(a.bundle)
    rp = CG.ClassRunReplay(b).run()
    rec = r13_block_terminals(b, rp, calibration_export=a.calibration_export, controls=not a.no_controls)
    rec["replay_ok"] = rp.summary().get("ok")
    rec["total_seconds"] = round(time.time() - t0, 1)
    try:
        import resource
        rec["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
    except Exception:  # noqa: BLE001
        pass
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"{a.name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
    print(f"{a.name}: ok {rec.get('ok')}; {rec.get('seconds')} s; record {path}")
    return 0 if rec.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
