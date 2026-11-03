#!/usr/bin/env python3
"""FR25-17's exact closing run (gate round 27, the v25 freeze review, section 3
Q5): NL-1 S1-S5 on ALL 23 slots of ONE fork of a registered R13 D55 bundle, so
that the 16 slots R13 does not redefine get S1 (the extension-round premise,
the per-variable bound, the budget) and S4 / S5 at a D55 base shape, not only
at D33's T32 TinyLlama.

    python3 -B fr25_17_nl1_all23.py --bundle <registered R13 D55 bundle> --evidence <dir>
        [--fork 1] [--name N] [--reference-record <merged 18-part record json>] [--modes run,random-1,...]

NOTHING HERE IS A PRIVACY STATEMENT OR AN ACCEPTANCE.  Read-only on the bundle.
Nothing under ops/zkp-mvp/gate-tinyllama/ is edited: the v25 staging modules
are imported from there unchanged (their sha256 are recorded) and every
deviation lives in this file.

WHAT RUNS, in one process:
  1. the gate's own D55Bundle, d55_facts, D55Replay (all forks), and R13-3 on
     the chosen fork only (`d55r13.r13_terminals(..., controls=False,
     forks=[fork])`), which RECOVERS G_fork on SC_FZC as the gate does;
  2. REFERENCE: v25's `d55nl.d55_nl1` UNCHANGED, called with gates = {fork:
     G_fork} so it evaluates exactly that fork's seven slots (its own `ok` is
     then false by design: the other forks are "not evaluated"; only its
     per-instance rows are used);
  3. WIDENED: `nl1_all23` below;
  4. control (a): the widened run's rows for the seven slots NL-1 already
     covers equal the in-process reference AND (when given) the merged
     record's rows for the same fork, row for row, in all four challenge
     modes (S1, S4, T-0 / E-0, S5 per-slot rows, the IR itself);
     control (b): negative controls that make S1 false on a legacy slot.

EXACTLY HOW `nl1_all23` / `fork_contexts_all23` DIFFER FROM v25
`zk60_native_rg_d55nl.d55_nl1` / `fork_contexts` (everything else is the v25
code, called, not copied: load_nl, fork_setup, poly_ops, t0_row, r13_to_ir,
PortSD, stages_for, mode_ok, all_slot_pairs, d55_nl_controls, and tokennl's
fidelity / s1_row / s3_pairs / s4_rows / controls):
  D1  the slot set is all 23 (v25: SLOTS7 = (3, 14..19)), processed in the
      order SLOTS7 then the 16 legacy slots, so the seven slots draw the SAME
      random challenges as v25 (one `random.Random(f"d55-r13nl/{k}/{seed}")`
      stream per fork, consumed in slot order) and their rows can be compared
      byte for byte;
  D2  the bilinear slots' DERIVED group point, set exactly as
      `zk60_native_rg_r13blocks.check_stage` does (lines 237-242:
      `T.BILINEAR_SLOTS`, `group.point(0, s)`, `cx.derived_eq_points`), placed
      inside the slot's refusal `try`; and, fail-closed, a bilinear slot whose
      definition requires a group table but has no derived point is refused
      there (v25 would raise later, outside any `try`);
  D3  the run-mode `gate.vals(cx)` is inside the same `try` (a derived point
      the bundle contradicts is then a refusal of that slot, as in
      check_stage, not a crash);
  D4  the 16 legacy slots are labelled "<port name> (legacy body)"; slot 3
      keeps v25's "(legacy body, R13 Dom::L lookups)" (labels seed nl_check's
      per-slot randomness, so slot 3's must not change);
  D5  `nl_check.Slot` needs the extension-round order of the private tables
      of the two slots with TWO extension rounds (SC_SCORE 8, SC_PV 9); every
      v25 / tokennl call site passes `{}` (none of their slots has two).  It
      is taken from nl_check's OWN `parse_sources` run on the argument.rs /
      layout.rs whose sha256 equal the bundle manifest's pins, and supplied by
      a SCOPED substitution of `nl_check.Slot` by a subclass whose only change
      is to use that order when the caller passes `{}` (restored after, and
      checked); for every other slot nl_check ignores ext_assign;
  D6  NEW, fail-closed: per slot instance, the split nl_check uses (main,
      extension, each private table's extension round) must equal the
      bundle's own record (`arguments[s].main / .extension`, each private
      table's `extension_round`);
  D7  only the requested fork(s) are evaluated; the expected instance count
      is 23 per evaluated fork;
  D8  S5 is ADJUDICATED against predictions: tokennl's N5-1 (strip a public
      factor -> the premise fails) cannot fire on SC_SCORE / SC_PV, whose
      premise has a SECOND mechanism (the two private factors are masked in
      different extension rounds; nl_check's own S5 control C2, "must NOT
      fire"), so there N5-1 is predicted NOT to fire and nl_check's C1 / C2 /
      C3 are run at the real shape instead (C3, group eq dropped AND both
      factors in round 0, must fire: premise false, miniature chain rejects);
  D9  the three D55 NL controls (NL-TAB-GC, NL-TAB-ACT, NL-G; v25's
      `d55_nl_controls` unchanged) run with `d55nl.fork_contexts` rebound, in
      scope, to `fork_contexts_all23`, so each must fail T-0 at its one slot
      out of all 23;
  D10 extra negative controls on S1 (control (b)).
"""

from __future__ import annotations

import argparse
import contextlib
import copy
import hashlib
import json
import os
import random
import resource
import sys
import time

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
V25 = os.path.join(REPO, "ops", "zkp-mvp", "gate-tinyllama", "staging_v25", "scripts")
if V25 not in sys.path:
    sys.path.insert(0, V25)

import zk60_native_rg_d55 as D  # noqa: E402
import zk60_native_rg_d55nl as NLX  # noqa: E402
import zk60_native_rg_d55r13 as X  # noqa: E402
import zk60_native_rg_r13slots as R  # noqa: E402
import zk60_native_rg_terminals as T  # noqa: E402
import zk60_native_rg_tokennl as TN  # noqa: E402
from zk60_native_jv_field import f2_from_list, f2_mul_base  # noqa: E402

ALL23 = tuple(range(23))
SLOTS7 = tuple(NLX.SLOTS7)
LEGACY16 = tuple(s for s in ALL23 if s not in SLOTS7)
SLOT_ORDER = SLOTS7 + LEGACY16                      # D1
BILINEAR = tuple(T.BILINEAR_SLOTS)
MODES = [("run", 0), ("random", 1), ("random", 2), ("random", 3)]
SRC_DIRS = [os.path.join(REPO, "ops", "zkp-mvp", "gpu-metal", "hashline", "src", "private_block"),
            os.path.join(REPO, "hashline", "src", "private_block")]


def _sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def _norm(x):
    return json.loads(json.dumps(x, sort_keys=True, default=str))


def _mode_key(chal, seed):
    return chal if chal == "run" else f"random-{seed}"


# ------------------------------------------------------- D5: the extension-round order, from nl_check's own parser
def ext_assign_from_pinned_source(NL, b) -> dict:
    """nl_check.parse_sources on the argument.rs / layout.rs whose sha256 the
    bundle manifest pins (its SRC dict repointed in scope, restored after)"""
    pins = {p["file"]: p["sha256"] for p in b.manifest.get("source_pins", [])}
    want = {"argument.rs": pins.get("src/private_block/argument.rs"), "layout.rs": pins.get("src/private_block/layout.rs")}
    found = {}
    for n, h in want.items():
        for d in SRC_DIRS:
            p = os.path.join(d, n)
            if h and os.path.isfile(p) and _sha(p) == h:
                found[n] = p
                break
    out = {"pins": want, "files": {n: os.path.relpath(p, REPO) for n, p in found.items()}}
    if set(found) != {"argument.rs", "layout.rs"}:
        out.update({"ok": False, "refused": f"no file in {SRC_DIRS} at the pinned digests {want}"})
        return out
    saved = dict(NL.SRC)
    try:
        NL.SRC["argument.rs"], NL.SRC["layout.rs"] = found["argument.rs"], found["layout.rs"]
        src = NL.parse_sources()
    finally:
        NL.SRC.clear()
        NL.SRC.update(saved)
    ea = {int(k): list(v) for k, v in src["ext_assign"].items()}
    out.update({"ext_assign": ea, "nonzero_ext_pushes": src["nonzero_ext_pushes"], "pushes_parsed": len(src["pushes"]),
                "SC": {k: v for k, v in src["sc"].items() if v in BILINEAR},
                "src_restored": dict(NL.SRC) == saved,
                "ok": set(ea) == set(BILINEAR) and all(len(v) == 2 and sorted(v) == [0, 1] for v in ea.values())})
    return out


class nl_slot_ext:
    """D5: within the block, `nl_check.Slot(js, shape, {})` uses `ext_assign`
    (nl_check reads it only for a slot with two extension rounds); a caller
    passing a non-empty dict is unchanged.  Restored after (and checked)."""

    def __init__(self, NL, ext_assign):
        self.NL, self.ea = NL, dict(ext_assign)

    def __enter__(self):
        self.orig = orig = self.NL.Slot
        ea = self.ea

        class SlotExt(orig):
            def __init__(slf, js, shape, ext_assign):
                super().__init__(js, shape, ext_assign if ext_assign else ea)

        self.NL.Slot = SlotExt
        return self

    def __exit__(self, *exc):
        self.NL.Slot = self.orig
        self.restored = self.NL.Slot is self.orig
        return False


@contextlib.contextmanager
def rebound(mod, name, new):
    old = getattr(mod, name)
    setattr(mod, name, new)
    st = {"restored": None}
    try:
        yield st
    finally:
        setattr(mod, name, old)
        st["restored"] = getattr(mod, name) is old


# ------------------------------------------------------- D6: the split nl_check uses = the bundle's record
def ext_crosscheck(sl, arg) -> dict:
    rec = [t.get("extension_round") for t in arg["tables"] if t["kind"] not in ("eq", "public")]
    used = [sl.ext_round[i] for i in sl.private]
    return {"slot": sl.slot, "name": sl.name, "main": sl.main, "extension": sl.ext,
            "bundle_main": arg["main"], "bundle_extension": arg["extension"],
            "private_ext_rounds_bundle": rec, "private_ext_rounds_used": used,
            "ok": rec == used and sl.ext == arg["extension"] and sl.main == arg["main"]}


# ------------------------------------------------------- v25 fork_contexts with D1-D4
def fork_contexts_all23(b, rp, facts, index, counts, cal, k, g, chal="run", seed=0, stage_doc=None, slots=None):
    """v25 `d55nl.fork_contexts` (lines 292-348) for all 23 slots; the
    differences are marked D1-D4 (module docstring)"""
    import zk60_native_rg_gqa as GQ
    sh = b.run["shape"]
    shim = X._shim_for(b, k, cal)
    view = X._ForkReplayView(rp, [k])
    rc = X._ctx(facts, cal, g, sh["wrho_s"], counts)
    gate = T.TerminalGate(shim, index)
    gate.set_stage(0)
    doc = stage_doc if stage_doc is not None else shim.stages[0].doc
    rng = random.Random(f"d55-r13nl/{k}/{seed}")
    gate.set_logup(doc["logup_challenges"])
    gate._lk_cache["L"] = R.r13_lookups("L", rc.prec, rc.gate_shift, rc.wrho_s, rc.counts)
    lam_z = T.lam_z_of(doc)
    planes = [[pl.name for pl in row] for row in index.slot_planes]
    group = GQ.GroupFactors(shim, replay=view, stage_docs=[doc], definition=None)
    legacy_ports = {s_: (nm_, fn_) for s_, nm_, fn_, _r in T.PORTS}
    out = []
    for s in (slots if slots is not None else SLOT_ORDER):                       # D1
        arg = doc["arguments"][s]
        dc = [f2_from_list(x) for x in arg["definition_challenges"]]
        if s in R.R13_PORTS:
            nm, fn = R.R13_PORTS[s]
            names = planes[s]
        else:
            nm0, fn0 = legacy_ports[s]
            label = f"{nm0} (legacy body, R13 Dom::L lookups)" if s == 3 else f"{nm0} (legacy body)"   # D4
            nm, fn = label, (lambda v, cx_, rc_, f=fn0: f(v, cx_))
            names = [R.LEGACY_NAME_OF_R13.get(n, n) for n in planes[s]]
        cx = T.SlotCtx(gate, arg, names, dc, lam_z, structural=True)
        cx.bilinear_definition = group.definition
        cx.group_table_required = group.group_table_required()
        cx.rho_full = view.stages[0]["rho"][s]
        try:
            if s in T.BILINEAR_SLOTS:                                             # D2 (r13blocks.py:237-242)
                pt = group.point(0, s)
                if pt is not None:
                    if not cx.eq_idx:
                        raise ValueError(f"slot {s}: a group point was derived and the bundle declares no eq table")
                    cx.derived_eq_points = {cx.eq_idx[0]: pt}
                if cx.group_table_required and not (cx.eq_idx and cx.eq_idx[0] in cx.derived_eq_points):
                    raise ValueError(f"slot {s}: the definition in force needs a group table and no point was derived")
            if s in R.R13_PORTS:
                R.build_public_r13(gate, cx, check_digests=True)
            else:
                gate.build_public(cx, check_digests=True)
            vals = gate.vals(cx) if chal == "run" else None                       # D3
        except (ValueError, IndexError, KeyError) as exc:
            out.append({"fork": k, "G": g, "slot": s, "name": nm, "refused": str(exc)[:300]})
            continue
        cx.public_values = {}
        if chal == "random":
            cx.dc = [NLX._rand_f2(rng) for _ in dc]
            cx.alpha, cx.beta = NLX._rand_f2(rng), NLX._rand_f2(rng)
            gm = NLX._rand_f2(rng)
            cx.g_u8, cx.g_exp, cx.g_act = (f2_mul_base(gm, 133), f2_mul_base(gm, 129), f2_mul_base(gm, 134))
            cx.g_dd = f2_mul_base(gm, 135)
        out.append({"fork": k, "G": g, "slot": s, "name": nm, "arg": arg, "cx": cx, "fn": fn, "rc": rc, "vals": vals,
                    "derived_group_point": bool(cx.derived_eq_points), "group_factor_ok": group.summary().get("ok")})
    return out


# ------------------------------------------------------- D8: bilinear C1 / C2 / C3 at the real shape
def _premise(NL, NF, sl):
    return TN.s1_row(NL, NF, sl)["premise_holds"]


def bilinear_split_controls(NL, NF, ir, sl) -> dict:
    """nl_check's S5 C1 / C2 / C3 (nl_check.py:1073-1097) at this slot
    instance's real IR: the group eq factor kept or dropped, the two private
    factors in rounds (0, 1) (the bundle's) or both in round 0"""
    eq_ix = [i for i, t in enumerate(ir["tables"]) if t["kind"].startswith("eq(")]
    q_id, k_id = sl.private
    js_nogeq = copy.deepcopy(ir)
    moved = 0
    for t in js_nogeq["terms"]:
        keep = [fc for fc in t["inner"] if fc.get("table") not in eq_ix]
        moved += len(t["inner"]) - len(keep)
        t["inner"] = keep
        t["degree"] = len(keep)
    js_nogeq["max_product_degree"] = max(t["degree"] for t in js_nogeq["terms"])
    same = {sl.slot: [0, 0]}
    honest = {sl.slot: [sl.ext_round[q_id], sl.ext_round[k_id]]}
    base_same = NL.Slot(ir, "token", same)
    nogeq = NL.Slot(js_nogeq, "token", honest)
    nogeq_same = NL.Slot(js_nogeq, "token", same)
    c1 = _premise(NL, NF, base_same)
    c2 = _premise(NL, NF, nogeq)
    c3 = _premise(NL, NF, nogeq_same)
    mini = NL.miniature(nogeq_same, NF.Rng(NL.sd("fr25-17-C3", sl.name)))
    c3_s1 = TN.s1_row(NL, NF, nogeq_same)
    return {"slot": sl.slot, "name": sl.name, "group_eq_tables": eq_ix, "eq_factors_dropped": moved,
            "honest_rounds": honest[sl.slot],
            "C1_group_eq_kept_both_round0": {"premise_holds": c1, "expect": True, "as_predicted": c1 is True},
            "C2_group_eq_dropped_rounds_0_1": {"premise_holds": c2, "expect": True, "as_predicted": c2 is True,
                                               "public_factor_in_every_monomial": TN.s1_row(NL, NF, nogeq)[
                                                   "public_factor_in_every_monomial_exact"]},
            "C3_group_eq_dropped_both_round0": {"premise_holds": c3, "S1_row": c3_s1,
                                                "miniature_chain_accepts": mini["chain_accepts"],
                                                "miniature_offset_in_ImR": mini.get("offset_in_ImR"),
                                                "expect": "premise false, chain rejects",
                                                "fires": bool(moved) and c3 is False and not mini["chain_accepts"]},
            "ok": bool(moved) and c1 is True and c2 is True and c3 is False and not mini["chain_accepts"]}


# ------------------------------------------------------- D10: control (b), S1 made false on a legacy slot
def _s1_ok(r):
    return bool(r["premise_holds"] and r["public_factor_in_every_monomial_exact"] and r["degree_fits"] and r["budget_ok"])


def s1_negative_controls(NL, NF, irs, slots, args_, s1_rows) -> dict:
    out = {}
    honest_fail = {sl.slot for sl, r in zip(slots, s1_rows) if not _s1_ok(r)}
    # NC-DEG: the declared (per-variable) degree bound one short on the first
    # zero-slack legacy slot -> degree_fits false there and only there
    j = next((i for i, (sl, r) in enumerate(zip(slots, s1_rows)) if sl.slot in LEGACY16 and r["slack"] == 0), None)
    if j is None:
        out["NC-DEG"] = {"fires": False, "nothing_to_act_on": "no zero-slack legacy slot"}
    else:
        js = copy.deepcopy(irs[j])
        js["declared_degree"] -= 1
        row = TN.s1_row(NL, NF, NL.Slot(js, "token", {}))
        rows = [row if i == j else r for i, r in enumerate(s1_rows)]
        failing = sorted({sl.slot for sl, r in zip(slots, rows) if not _s1_ok(r)} - honest_fail)
        out["NC-DEG"] = {"what": f"slot {slots[j].slot} ({slots[j].name}): declared degree {irs[j]['declared_degree']} -> "
                                 f"{js['declared_degree']} (walked max product degree {row['max_product_degree_walked']}, "
                                 f"per-variable bound {row['per_variable_degree_bound_max']})",
                         "acted_on": slots[j].slot, "S1_row": row, "predicted_failing": [slots[j].slot],
                         "failing": failing, "fires": failing == [slots[j].slot] and not row["degree_fits"]}
    # NC-SPLIT: the bilinear split controls' C3 enters the full S1 summary
    j = next((i for i, sl in enumerate(slots) if sl.slot == 8), None)
    if j is None:
        out["NC-SPLIT"] = {"fires": False, "nothing_to_act_on": "no SC_SCORE instance"}
    else:
        c = bilinear_split_controls(NL, NF, irs[j], slots[j])
        rows = [c["C3_group_eq_dropped_both_round0"]["S1_row"] if i == j else r for i, r in enumerate(s1_rows)]
        failing = sorted({sl.slot for sl, r in zip(slots, rows) if not _s1_ok(r)} - honest_fail)
        out["NC-SPLIT"] = {"what": f"slot 8 ({slots[j].name}): group eq factor dropped and both private factors put in "
                                   f"extension round 0 (the bundle's split is {c['honest_rounds']})",
                           "acted_on": 8 if c["eq_factors_dropped"] else None, "predicted_failing": [8],
                           "failing": failing, "fires": bool(c["eq_factors_dropped"]) and failing == [8]}
    # NC-EXTREC: the bundle's recorded split moved (slot 8's second private
    # table to round 0) -> the D6 cross-check refuses that instance
    j = next((i for i, sl in enumerate(slots) if sl.slot == 8), None)
    if j is None:
        out["NC-EXTREC"] = {"fires": False, "nothing_to_act_on": "no SC_SCORE instance"}
    else:
        a2 = copy.deepcopy(args_[j])
        privs = [t for t in a2["tables"] if t["kind"] not in ("eq", "public")]
        before = privs[-1].get("extension_round")
        privs[-1]["extension_round"] = 0
        got = [ext_crosscheck(sl, a2 if i == j else a)["ok"] for i, (sl, a) in enumerate(zip(slots, args_))]
        failing = [slots[i].slot for i, g_ in enumerate(got) if not g_]
        out["NC-EXTREC"] = {"what": f"slot 8's recorded extension_round of its second private table {before} -> 0",
                            "acted_on": 8 if before != 0 else None, "predicted_failing": [8], "failing": failing,
                            "fires": before != 0 and failing == [8]}
    out["ok"] = all(v.get("fires") for v in out.values() if isinstance(v, dict))
    return out


def s5_adjudicate(s5, slots) -> dict:
    """D8: tokennl's controls against per-slot predictions"""
    slot_of = {sl.name: sl.slot for sl in slots}
    n51 = []
    for r in s5["N5_1"]:
        s = slot_of[r["name"]]
        if s in BILINEAR:
            pred = "NOT fire (second mechanism: rounds 0 / 1; nl_check C2)"
            ok = r["moved"] and r["premise_holds"] and not r["fires"]
        else:
            pred = "fire"
            ok = bool(r["fires"])
        n51.append({"slot": s, "name": r["name"], "predicted": pred, "fires": r["fires"], "as_predicted": ok})
    live = [x for x in s5["N5_2"] if x["fires"] is not None]
    return {"N5_1": n51, "N5_1_as_predicted": f"{sum(1 for x in n51 if x['as_predicted'])}/{len(n51)}",
            "N5_2_live_fire": f"{sum(1 for x in live if x['fires'])}/{len(live)}",
            "N5_3_fires": s5["N5_3"]["fires"], "N5_4_fires": s5["N5_4"]["fires"],
            "F_1_fire": f"{sum(1 for x in s5['F_1'] if x['fires'])}/{len(s5['F_1'])}",
            "tokennl_controls_ok_unadjudicated": s5["ok"],
            "ok": (all(x["as_predicted"] for x in n51) and bool(live) and all(x["fires"] for x in live)
                   and s5["N5_3"]["fires"] and s5["N5_4"]["fires"] and all(x["fires"] for x in s5["F_1"]))}


# ------------------------------------------------------- the widened part
def nl1_all23(b, rp, facts, gates, forks, controls=True, modes=None) -> dict:
    t0 = time.time()
    NL, NF, nld = NLX.load_nl()
    ea = ext_assign_from_pinned_source(NL, b)
    rec = {"what": "FR25-17 closing run: NL-1 S1-S5 through the frozen nl_check on ALL 23 slots of the given fork(s) of a "
                   "registered R13 D55 run (v25 d55_nl1 with the differences D1-D10 of fr25_17_nl1_all23.py); NOT a privacy result",
           "privacy_acceptance": False, "privacy_property_established": False,
           "nl_check_dir": nld, "nl_check_pins": TN.NL_PINS, "slot_order": list(SLOT_ORDER),
           "slots_r13_redefined_or_lzc": list(SLOTS7), "slots_legacy_16": list(LEGACY16),
           "ext_assign_source": ea, "gates": {str(kk): v for kk, v in sorted(gates.items())},
           "forks_evaluated": list(forks)}
    if not ea["ok"]:
        rec.update({"ok": False, "refused": ea.get("refused", "the extension-round order is not the expected one")})
        return rec
    index, counts, cals = NLX.fork_setup(b, facts)
    per_mode, keep, t0e0_rows, xcheck, gf = {}, None, [], {}, {}
    modes = modes or MODES
    with X.argument_reading() as rd, NLX.poly_ops() as po, nl_slot_ext(NL, ea["ext_assign"]) as se:
        for chal, seed in modes:
            key = _mode_key(chal, seed)
            tm = time.time()
            irs, sds, args_ = [], [], []
            for kk in forks:
                ents = fork_contexts_all23(b, rp, facts, index, counts, cals[kk], kk, gates[kk], chal, seed)
                for e in ents:
                    if "refused" in e:
                        if chal == "run":
                            t0e0_rows.append(NLX.t0_row(e))
                        continue
                    gf[(kk, e["slot"])] = {"derived_group_point": e["derived_group_point"], "group_factor_ok": e["group_factor_ok"]}
                    if chal == "run":
                        row, ir = NLX.t0_row(e)
                        t0e0_rows.append(row)
                    else:
                        ir, _pl, _names = NLX.r13_to_ir(e)
                    irs.append(ir)
                    sds.append(NLX.PortSD(e["fn"], e["cx"], e["rc"]))
                    args_.append(e["arg"])
            pm, slots = NLX.stages_for(NL, NF, irs, sds, key)
            pm["instances"] = len(irs)
            xc = [ext_crosscheck(sl, a) for sl, a in zip(slots, args_)]
            xcheck[key] = {"rows": xc, "ok": all(x["ok"] for x in xc) and len(xc) == len(irs)}
            pm["seconds"] = round(time.time() - tm, 1)
            per_mode[key] = pm
            if chal == "run":
                keep = (irs, slots, sds, args_)
        irs, slots, sds, args_ = keep
        rec["T0_E0"] = t0e0_rows
        rec["per_challenge_mode"] = per_mode
        rec["extension_split_crosscheck"] = xcheck
        rec["bilinear_group_point"] = [{"fork": kk, "slot": s, **v} for (kk, s), v in sorted(gf.items()) if s in BILINEAR]
        rec["S3_pairs"] = sorted({(sl.main + sl.ext, sl.d) for sl in slots})
        rec["S3_fact21"] = TN.s3_pairs(NL, NF, rec["S3_pairs"])
        rec["S5_controls"] = TN.controls(NL, NF, irs, slots, sds)
        rec["S5_adjudicated"] = s5_adjudicate(rec["S5_controls"], slots)
        rec["bilinear_split_controls"] = [bilinear_split_controls(NL, NF, ir, sl)
                                          for ir, sl in zip(irs, slots) if sl.slot in BILINEAR]
        rec["S1_negative_controls"] = s1_negative_controls(NL, NF, irs, slots, args_, per_mode["run"]["S1"])
        rec["ir_run_challenges"] = {"schema": "zk60-slot-ir/1-r13-block-d55-fork", "slots": irs}
        if controls:
            kc = forks[0]
            with rebound(NLX, "fork_contexts", fork_contexts_all23) as rb:                    # D9
                rec["D55_controls"] = NLX.d55_nl_controls(b, rp, facts, index, counts, cals, gates, kc)
            rec["D55_controls"]["fork_contexts_restored_after"] = rb["restored"]
            rec["D55_controls"]["slots_per_context"] = len(SLOT_ORDER)
    rec["poly_ops_restored_after"] = po.restored
    rec["nl_check_Slot_restored_after"] = se.restored
    rec["argument_rs_reading"] = {"added_in_memory": rd.added, "removed_after": rd.removed}
    rec["all_23_slots_S3_and_budget"] = NLX.all_slot_pairs(NL, NF, b)
    n = len(irs)
    expected = len(SLOT_ORDER) * len(forks)
    rec["slot_instances"], rec["slot_instances_expected"] = n, expected
    t0e0 = (len(t0e0_rows) == expected and all(
        r["T0_port_equals_recorded_terminal_polynomial"] and r["E0_expansion_equals_port"]
        and r["T0_control_one_terminal_plus_1_fires"] for r in t0e0_rows))
    rec["T0_E0_all"] = t0e0
    ctl_ok = (rec.get("D55_controls", {}).get("ok", False) and rec["D55_controls"].get("fork_contexts_restored_after")) if controls else True
    bil_ok = len(rec["bilinear_split_controls"]) == len(BILINEAR) * len(forks) and all(c["ok"] for c in rec["bilinear_split_controls"])
    rec["per_slot"] = per_slot_table(rec, slots)
    rec["summary"] = {
        "forks": list(forks), "slot_instances": f"{n}/{expected}", "gates": rec["gates"],
        "T0": f"{sum(1 for r in t0e0_rows if r['T0_port_equals_recorded_terminal_polynomial'])}/{len(t0e0_rows)}",
        "E0": f"{sum(1 for r in t0e0_rows if r['E0_expansion_equals_port'])}/{len(t0e0_rows)}",
        "T0_control_fires": f"{sum(1 for r in t0e0_rows if r['T0_control_one_terminal_plus_1_fires'])}/{len(t0e0_rows)}",
        "per_mode": {kk: {"F0": v["F0_fidelity"], "S1": v["S1_summary"], "S4": v["S4_summary"], "seconds": v["seconds"]}
                     for kk, v in per_mode.items()},
        "extension_split_crosscheck": {kk: v["ok"] for kk, v in xcheck.items()},
        "S3": f"{rec['S3_fact21']['tight']}/{rec['S3_fact21']['checks']} at {rec['S3_pairs']}",
        "S3_all_23_slots_every_fork": f"{rec['all_23_slots_S3_and_budget']['S3_fact21']['tight']}/"
                                      f"{rec['all_23_slots_S3_and_budget']['S3_fact21']['checks']}",
        "budget_all_23_slots_every_fork": rec["all_23_slots_S3_and_budget"]["budget_all_ok"],
        "S5_tokennl_raw": rec["S5_controls"]["summary"], "S5_tokennl_raw_ok": rec["S5_controls"]["ok"],
        "S5_adjudicated_ok": rec["S5_adjudicated"]["ok"], "S5_N5_1_as_predicted": rec["S5_adjudicated"]["N5_1_as_predicted"],
        "bilinear_C1_C2_C3_ok": bil_ok,
        "S1_negative_controls": {kk: v.get("fires") for kk, v in rec["S1_negative_controls"].items() if isinstance(v, dict)},
        "D55_controls": {kk: v.get("fires") for kk, v in rec.get("D55_controls", {}).items() if isinstance(v, dict)}}
    rec["ok"] = bool(n == expected and all(NLX.mode_ok(pm, n) for pm in per_mode.values()) and t0e0
                     and all(v["ok"] for v in xcheck.values())
                     and rec["S3_fact21"]["tight"] == rec["S3_fact21"]["checks"] and rec["S5_adjudicated"]["ok"] and bil_ok
                     and rec["S1_negative_controls"]["ok"] and rec["all_23_slots_S3_and_budget"]["ok"] and ctl_ok
                     and po.restored and se.restored and rd.removed and len(per_mode) == len(MODES))
    rec["seconds"] = round(time.time() - t0, 1)
    return rec


def per_slot_table(rec, slots) -> list:
    """one row per slot instance: the split, S1 / S4 in every mode, T-0, S5"""
    out = []
    t0 = {(r["fork"], r["slot"]): r for r in rec["T0_E0"]}
    s5 = {kk: {r["name"]: r for r in rec["S5_controls"][kk]} for kk in ("N5_1", "N5_2", "F_1")}
    adj = {r["name"]: r for r in rec["S5_adjudicated"]["N5_1"]}
    for sl in sorted(slots, key=lambda x: (x.name.split(" slot ")[0], x.slot)):
        fork = int(sl.name.split()[1])
        row = {"fork": fork, "slot": sl.slot, "name": sl.name.split(" slot ", 1)[1],
               "set": "R13-redefined / SC_LZC (NL-1 v25)" if sl.slot in SLOTS7 else "legacy-16 (new here)",
               "main": sl.main, "extension": sl.ext, "declared_degree": sl.d}
        for mode, pm in rec["per_challenge_mode"].items():
            r1 = next(r for r in pm["S1"] if r["name"] == sl.name)
            r4 = next(r for r in pm["S4"] if r["name"] == sl.name)
            row[mode] = {"S1": {"premise": r1["premise_holds"], "public_factor_every_monomial": r1["public_factor_in_every_monomial_exact"],
                                "degree_fits": r1["degree_fits"], "max_product_degree": r1["max_product_degree_walked"],
                                "per_variable_bound": r1["per_variable_degree_bound_max"], "slack": r1["slack"],
                                "L": r1["L"], "dimC": r1["dimC"], "budget_ok": r1["budget_ok"]},
                         "S4": {"miniature_passes": r4["passes"], "terminal_map_onto": r4["terminal_map"]["onto_Fp2^m"],
                                "m": r4["terminal_map"]["m"]}}
        tr = t0.get((fork, sl.slot), {})
        row["T0"] = tr.get("T0_port_equals_recorded_terminal_polynomial")
        row["E0"] = tr.get("E0_expansion_equals_port")
        row["T0_control_fires"] = tr.get("T0_control_one_terminal_plus_1_fires")
        row["S5"] = {"N5_1_fires": s5["N5_1"][sl.name]["fires"], "N5_1_as_predicted": adj[sl.name]["as_predicted"],
                     "N5_2_fires": s5["N5_2"][sl.name]["fires"], "F_1_fires": s5["F_1"][sl.name]["fires"]}
        out.append(row)
    return out


# ------------------------------------------------------- control (a)
def _sub_rows(nl, fork, slots):
    """the rows of one NL-1 record (v25 or this one) for `fork`'s instances of `slots`"""
    pref = f"fork {fork} "

    def mine(name):
        if not name.startswith(pref):
            return False
        return int(name.split(" slot ", 1)[1].split()[0]) in slots

    out = {"modes": {}}
    for mode, pm in nl["per_challenge_mode"].items():
        out["modes"][mode] = {"S1": {r["name"]: r for r in pm["S1"] if mine(r["name"])},
                              "S4": {r["name"]: r for r in pm["S4"] if mine(r["name"])}}
    out["T0_E0"] = {str(r["slot"]): r for r in nl["T0_E0"] if r["fork"] == fork and r["slot"] in slots}
    out["S5"] = {kk: {r["name"]: r for r in nl["S5_controls"][kk] if mine(r["name"])} for kk in ("N5_1", "N5_2", "F_1")}
    out["IR"] = {s["name"]: s for s in nl["ir_run_challenges"]["slots"] if mine(s["name"])}
    return _norm(out)


def compare_seven(wide, ref, fork, label) -> dict:
    a, b = _sub_rows(wide, fork, SLOTS7), _sub_rows(ref, fork, SLOTS7)
    diffs = []
    for mode in sorted(set(a["modes"]) | set(b["modes"])):
        for st in ("S1", "S4"):
            x, y = a["modes"].get(mode, {}).get(st, {}), b["modes"].get(mode, {}).get(st, {})
            if set(x) != set(y):
                diffs.append(f"{mode} {st}: instances {sorted(set(x) ^ set(y))}")
            for nm in sorted(set(x) & set(y)):
                if x[nm] != y[nm]:
                    diffs.append(f"{mode} {st}: {nm}")
    for part in ("T0_E0", "IR"):
        if a[part] != b[part]:
            diffs.append(f"{part}: {sorted(k for k in set(a[part]) | set(b[part]) if a[part].get(k) != b[part].get(k))}")
    for kk in ("N5_1", "N5_2", "F_1"):
        if a["S5"][kk] != b["S5"][kk]:
            diffs.append(f"S5 {kk}")
    counts = {mode: {st: len(v[st]) for st in ("S1", "S4")} for mode, v in b["modes"].items()}
    n_ref = sum(len(v["S1"]) for v in b["modes"].values())
    return {"against": label, "fork": fork, "slots": list(SLOTS7), "reference_instance_counts": counts,
            "reference_T0_rows": len(b["T0_E0"]), "reference_IR": len(b["IR"]),
            "differences": diffs, "acted_on": n_ref > 0,
            "reproduces": n_ref == 7 * len(b["modes"]) and len(b["modes"]) == 4 and len(b["IR"]) == 7 and not diffs}


# ------------------------------------------------------- main
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--fork", type=int, default=1)
    ap.add_argument("--name")
    ap.add_argument("--reference-record", help="a merged 18-part gate record of the SAME bundle (control (a))")
    ap.add_argument("--modes", help="development only: a subset of run,random-1,random-2,random-3")
    ap.add_argument("--no-controls", action="store_true", help="development only")
    ap.add_argument("--no-v25-reference", action="store_true", help="development only")
    a = ap.parse_args(argv)
    t0 = time.time()
    times = {}
    rec = {"tool": "fr25_17_nl1_all23.py", "tool_sha256": _sha(os.path.abspath(__file__)),
           "v25_scripts_dir": os.path.relpath(V25, REPO),
           "v25_modules_sha256": {os.path.basename(m.__file__): _sha(m.__file__) for m in (D, NLX, X, R, T, TN)},
           "bundle_dir": os.path.abspath(a.bundle), "fork": a.fork, "privacy_acceptance": False,
           "privacy_property_established": False, "development_flags": {
               "modes": a.modes, "no_controls": a.no_controls, "no_v25_reference": a.no_v25_reference}}
    import zk60_native_rg_gqa as GQ
    import zk60_native_rg_r13blocks as RBK
    rec["v25_modules_sha256"].update({os.path.basename(m.__file__): _sha(m.__file__) for m in (GQ, RBK)})
    b = D.D55Bundle(a.bundle)
    facts = D.d55_facts(b)
    rec["bundle"], rec["profile"], rec["family"] = b.name, b.profile, facts.get("family")
    rec["manifest"] = {kk: b.manifest.get(kk) for kk in ("source_commit", "writer", "proved_on_gpu", "blocks")}
    rec["shape"] = {kk: b.run["shape"].get(kk) for kk in ("tokens", "hidden", "heads", "kv_heads", "f_pad", "n_slots")
                    if kk in b.run["shape"]}
    if facts.get("family") != "R13":
        raise SystemExit("not an R13-family D55 bundle")
    times["load"] = round(time.time() - t0, 1)
    ts = time.time()
    rp = D.D55Replay(b).run()
    rec["replay"] = {kk: v for kk, v in rp.summary().items() if not isinstance(v, (list, dict)) or kk == "ok"}
    times["replay"] = round(time.time() - ts, 1)
    if not rp.summary()["ok"]:
        raise SystemExit("the D55 replay failed")
    ts = time.time()
    t3 = X.r13_terminals(b, rp, facts, controls=False, forks=[a.fork])
    pf = [p for p in t3["per_fork"] if p["fork"] == a.fork]
    rec["R13-3_on_fork"] = {kk: pf[0].get(kk) for kk in ("fork", "gate_shift_recovered", "gate_values_closing_sc_fzc",
                                                          "slot_checks_equal", "slot_checks_expected", "equal",
                                                          "checked_not_equal", "refused_or_open", "group_factor_ok", "ok",
                                                          "seconds")} if pf else None
    times["R13-3_fork"] = round(time.time() - ts, 1)
    gates = {kk: v for kk, v in NLX.gates_from_r13_3(t3).items() if kk == a.fork}
    if gates.get(a.fork) is None or not (pf and pf[0]["ok"]):
        rec["refused"] = f"R13-3 did not close fork {a.fork} (G {gates.get(a.fork)})"
        rec["ok"] = False
    else:
        modes = None
        if a.modes:
            want = a.modes.split(",")
            modes = [(c, s) for c, s in MODES if _mode_key(c, s) in want]
        ref = None
        if not a.no_v25_reference:
            ts = time.time()
            ref = NLX.d55_nl1(b, rp, facts, gates, controls=False)
            times["v25_reference_fork_only"] = round(time.time() - ts, 1)
            rec["v25_reference_summary"] = {"slot_instances": ref["slot_instances"], "forks_evaluated": ref["forks_evaluated"],
                                            "forks_not_evaluated": ref["forks_not_evaluated"],
                                            "ok_note": "false by design here (only one fork evaluated)", "ok": ref["ok"],
                                            "summary": ref["summary"]}
        ts = time.time()
        wide = nl1_all23(b, rp, facts, gates, [a.fork], controls=not a.no_controls, modes=modes)
        times["widened_all23"] = round(time.time() - ts, 1)
        rec["NL-1 all 23 slots"] = wide
        ctl = {}
        if ref is not None:
            ctl["v25_in_process"] = compare_seven(wide, ref, a.fork, "v25 d55_nl1 unchanged, this process")
            # the comparison's own negative control: one fork-`fork` S1 row of the
            # reference moved (its L + 1) must show up as a difference
            bad = copy.deepcopy(ref)
            row = next((r for r in bad["per_challenge_mode"]["run"]["S1"] if r["name"].startswith(f"fork {a.fork} ")), None)
            if row is not None:
                row["L"] += 1
            st = compare_seven(wide, bad, a.fork, "self-test")
            rec["control_a_comparison_self_test"] = {"what": "the in-process reference with one S1 row's L + 1",
                                                     "acted_on": row is not None, "differences": st["differences"],
                                                     "fires": row is not None and not st["reproduces"] and bool(st["differences"])}
        if a.reference_record:
            mr = json.load(open(a.reference_record))
            nl = mr.get(NLX.PART)
            if nl is None or os.path.basename(os.path.normpath(mr.get("bundle_dir", ""))) != b.name:
                ctl["record_file"] = {"against": a.reference_record, "reproduces": False, "acted_on": False,
                                      "refused": "no NL-1 part, or the record is of another bundle"}
            else:
                c = compare_seven(wide, nl, a.fork, os.path.relpath(a.reference_record, REPO)
                                  if a.reference_record.startswith(REPO) else a.reference_record)
                c["record_sha256"] = _sha(a.reference_record)
                c["record_G"] = nl.get("gates", {}).get(str(a.fork))
                c["G_equal"] = c["record_G"] == gates[a.fork]
                c["reproduces"] = c["reproduces"] and c["G_equal"]
                ctl["record_file"] = c
        rec["control_a_seven_slots_reproduce"] = ctl
        rec["ok"] = bool(wide["ok"] and ctl and all(v.get("reproduces") for v in ctl.values())
                         and rec.get("control_a_comparison_self_test", {}).get("fires"))
    rec["seconds"] = times
    rec["total_seconds"] = round(time.time() - t0, 1)
    ru = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    rec["peak_rss_mib"] = round(ru / (1 << 20) if sys.platform == "darwin" else ru / 1024, 1)
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"fr25_17-{a.name or b.name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
    w = rec.get("NL-1 all 23 slots", {})
    print(json.dumps({"bundle": b.name, "fork": a.fork, "G": gates.get(a.fork), "summary": w.get("summary"),
                      "control_a": {kk: {"reproduces": v.get("reproduces"), "differences": v.get("differences")}
                                    for kk, v in rec.get("control_a_seven_slots_reproduce", {}).items()},
                      "control_a_self_test_fires": rec.get("control_a_comparison_self_test", {}).get("fires"),
                      "R13-3_fork": {kk: (rec.get("R13-3_on_fork") or {}).get(kk) for kk in ("slot_checks_equal", "ok")},
                      "seconds": times, "peak_rss_mib": rec["peak_rss_mib"]}, indent=1, default=str))
    print(f"status: {'PASS' if rec['ok'] else 'NOT-OK'} ({rec['total_seconds']} s) -> {path}")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
