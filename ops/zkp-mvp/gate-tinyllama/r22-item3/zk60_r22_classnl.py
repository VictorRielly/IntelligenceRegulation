#!/usr/bin/env python3
"""[gate round 22, item 3, 2026-10-29] NL-1 S1-S5 on the CLASSIFIER slots
(IN-C 4, OUT-C 8) and on the R13-REDEFINED BLOCK slots (SC_DZC 14, SC_QZC 15,
SC_KVZC 16, SC_SZC 17, SC_FZC 18, SC_TAB 19) of an R13 classifier capture,
through the FROZEN `results/zk60_nonlinear_channel_shaped/nl_check.py`
(digests checked by the frozen v23 `zk60_native_rg_tokennl.load_nl`), with a
slot IR built from the gate's OWN transcriptions expanded in the
`tokenterminals.Poly` ring.  NOT a privacy result.

    python3 zk60_r22_classnl.py --bundle <classifier capture> --evidence <dir> --name <name>
                                [--parts classifier,r13] [--real-pairs <real capture dir>]

Everything is IMPORTED read-only from `ops/zkp-mvp/gate-tinyllama/frozen_v23/scripts/`
(tools v23, manifest 64f4b757...): the stage routines S1 / S3 / S4 / S5 / F-0
of `zk60_native_rg_tokennl` (unchanged functions, called with this module's
IRs), the classifier transcription `zk60_native_rg_classterminals.define`
(already Poly-capable), the R13 ports `zk60_native_rg_r13slots.R13_PORTS`
and the block-stage setup of `zk60_native_rg_r13blocks.check_stage`
(restated here, line for line, so the port can be called on Poly values).

THE R13 PORTS OVER Poly.  The ports use the module-level Fp2 operations
`add / sub / mul / mulb` of `zk60_native_rg_terminals` and of
`zk60_native_rg_r13slots` (bound at import).  This process REBINDS those four
names in both module namespaces to type-dispatching versions: a Poly operand
goes to the Poly ring, two Fp2 tuples to the frozen field functions, so every
numeric path computes exactly what it computed before.  Fidelity, before any
NL-1 stage (failing-first: a perturbed IR coefficient must fail F-0):
  T-0  the port's NUMERIC value at the capture's terminals, the rebuilt public
       tables and the RE-DERIVED challenges equals the capture's recorded
       terminal polynomial (round 20's identity, recomputed here);
  E-0  the Poly expansion evaluated at those same values equals the port's
       numeric value;
  F-0  the IR evaluated by `nl_check.Slot` at random table values equals the
       port evaluated numerically at the same values (three seeds).
SC_DD 23 and the DD softmax twin are DD-profile slots: no classifier profile
is DD (a DD bundle is refused by name), so they are NOT APPLICABLE here.

`--real-pairs`: S3 (Fact 2.1, five regimes) also at every distinct (N, d) of
the classifier and R13 block slots of a REAL capture, read from its stage
files' slot records only (no store, no tables, no checkpoint).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import resource
import sys
import time

sys.dont_write_bytecode = True
FROZEN = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v23/scripts"
if FROZEN not in sys.path:
    sys.path.insert(0, FROZEN)

import zk60_native_rg_tokennl as TN  # noqa: E402
import zk60_native_rg_tokenterminals as TT  # noqa: E402
import zk60_native_rg_classterminals as CT  # noqa: E402
import zk60_native_rg_classgate as CG  # noqa: E402
import zk60_native_rg_terminals as T  # noqa: E402
import zk60_native_rg_r13slots as R  # noqa: E402
import zk60_native_rg_r13blocks as RB  # noqa: E402
from zk60_native_jv_field import f2_add, f2_from_list, f2_mul, f2_mul_base, f2_sub  # noqa: E402

Poly = TT.Poly
P = TT.P
# the seven R13-changed block slots at a NON-DD R13 profile: the six bodies argument_accuracy.rs REDEFINES
# (SC_DZC 14, SC_QZC 15, SC_KVZC 16, SC_SZC 17, SC_FZC 18, SC_TAB 19 = r13slots.R13_SLOTS) and SC_LZC 3, the one
# legacy body whose POLYNOMIAL changes at R13 (its Dom::L lookups are AccuracyIds::lookups, with the R13 limb
# counts and top-bit pins); SC_DD 23 and the DD softmax twin exist only at DD profiles (none for the classifier)
SLOTS7 = (3,) + tuple(R.R13_SLOTS)


# ------------------------------------------------------- polymorphic field ops
def _isp(x):
    return isinstance(x, Poly)


def padd(a, b):
    return (Poly._co(a) + Poly._co(b)) if (_isp(a) or _isp(b)) else f2_add(a, b)


def psub(a, b):
    return (Poly._co(a) - Poly._co(b)) if (_isp(a) or _isp(b)) else f2_sub(a, b)


def pmul(a, b):
    return (Poly._co(a) * Poly._co(b)) if (_isp(a) or _isp(b)) else f2_mul(a, b)


def pmulb(a, c):
    return (Poly._co(a) * Poly._co(T.k(int(c)))) if _isp(a) else f2_mul_base(a, c)


for _mod in (T, R):
    _mod.add, _mod.sub, _mod.mul, _mod.mulb = padd, psub, pmul, pmulb


def _fpow(x, e):
    out = (1, 0)
    for _ in range(e):
        out = f2_mul(out, x)
    return out


def eval_poly(Pl, assign):
    acc = (0, 0)
    for mono, c in Pl.t.items():
        term = c
        for (n, e) in mono:
            term = f2_mul(term, _fpow(assign[n], e))
        acc = f2_add(acc, term)
    return acc


def _fstr(v):
    return f"{v[0]}+{v[1]}u"


def _rand_f2(rng):
    return (rng.randrange(P), rng.randrange(P))


def _sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


# ------------------------------------------------------- the classifier slots
def class_table_kind(t):
    if t["kind"] == "eq":
        return f"eq(start={t['start']},|point|={len(t['point'])})", f"eq({t.get('label')})"
    if t["kind"] == "public":
        desc = CT.describe_c(t["desc"])
        cl = CT.table_class_c(t["desc"])
        if cl == "indicator" or any(h in desc.lower() for h in TN.SUPPORT_HINTS):
            return f"supp({desc})", desc
        return "pub", desc
    role = t["role"]
    if role.startswith("A-"):
        return "A", t["plane"]
    if role.startswith("H-"):
        return "H", t["plane"]
    return "EP", t["plane"]


def class_slot_defs(b, rp, chal="run", seed=0):
    out = []
    facts = CT.facts_from_bundle(b)
    if facts.get("w_delta") is None:
        facts["w_delta"] = [1] * b.geom.d          # a placeholder: the IR's public tables are variables
    for st in (b.stages[0], b.stages[-1]):
        kind = st.kind
        doc = st.doc
        logup, r_emb, dcf, _rho, _cc = TT._new_stage_challenges(b, rp, st, doc)
        rng = random.Random(f"r22-classnl/{kind}/{seed}")
        if chal == "random":
            logup = [_rand_f2(rng) for _ in logup]
            r_emb = [_rand_f2(rng) for _ in r_emb]
        for s in range(len(doc["arguments"])):
            arg = doc["arguments"][s]
            cx = CT.ClassCtx(b.geom, kind, logup, r_emb, "numeric", facts)
            vals = dcf(s)
            if chal == "random":
                vals = [_rand_f2(rng) for _ in vals]
            sd = CT.define(s, cx, TT.Draws(vals, "numeric"))
            out.append((kind, s, arg, sd))
    return out


def class_to_ir(kind, s, arg, sd):
    names = [f"T{i:02d}" for i in range(len(sd.tabs))]
    Pl = Poly._co(sd.poly([Poly.var(n) for n in names]))
    idx = {n: i for i, n in enumerate(names)}
    tables = []
    for t in sd.tabs:
        kk, lab = class_table_kind(t)
        tables.append({"kind": kk, "label": lab, "prov": "classifier transcription (classterminals.define)"})
    return _ir(f"{kind}-{s:02d} {arg['name']}", s, arg, Pl, idx, tables)


def _ir(name, s, arg, Pl, idx, tables):
    terms = []
    for mono, c in sorted(Pl.t.items()):
        inner = []
        for n, e in mono:
            inner.extend([{"table": idx[n]}] * e)
        terms.append({"coef": {"value": _fstr(c)}, "wrapper": [], "inner": inner, "degree": len(inner)})
    maxdeg = max((t["degree"] for t in terms), default=0)
    return {"slot": s, "name": name, "kind": arg["kind"], "main_rounds": arg["main"],
            "extension_rounds": arg["extension"], "declared_degree": arg["degree"], "max_product_degree": maxdeg,
            "pad_on": None, "group_bits": 0, "tables": tables, "nodes": [], "terms": terms}


# ------------------------------------------------------- the R13 block slots
class PortSD:
    """`sd.poly(vals)` for TN.fidelity / TN.controls: the R13 port evaluated
    NUMERICALLY at the given table values (F2 or tuples)"""

    def __init__(self, fn, cx, rc):
        self.fn, self.cx, self.rc = fn, cx, rc

    def poly(self, vals):
        v = [x.v if isinstance(x, TT.F2) else x for x in vals]
        return self.fn(v, self.cx, self.rc)


R13_BLOCKS = None          # --r13-blocks: evaluate only these block indices (a bounded real-capture run)
SKIP_CLASS_T0 = False      # --skip-classifier-t0: the classifier T-0 needs B-3, i.e. a checkpoint stream


def lazy_store():
    """the parent's round-22 census trick (round22/census/hash_census.py `lazy_store`): resolve array references
    without re-hashing or scanning them, so a values capture's 2.25 GB store is not made resident (O20-1);
    the bytes were SHA-256-checked by gate round 20 (every reference) and round 21 (the whole store)"""
    import numpy as np
    import zk60_native_rg_arrays as AR

    def resolve(self, ref, where):
        elem, n, off, nb = self.check_reference(ref, where)
        a = np.frombuffer(self._buf[off: off + nb], dtype="<u8")
        self.resolutions += 1
        return AR.FpArray(a, ref, where) if elem == "fp" else AR.Fp2Array(a.reshape(n, 2), ref, where)
    AR.ArrayStore.resolve = resolve


def no_b3():
    """no checkpoint stream: B-3's derivation from the 7.7 GB checkpoint is refused in this process, so the
    classifier facts carry no derived margin row / embedding (the IR treats public tables as variables)"""
    import zk60_native_rg_classtied as TD

    def refuse(*_a, **_k):
        raise ValueError("B-3 disabled in this process (gate round 22 item 3: no checkpoint stream)")
    TD.derive_for_profile = refuse


def r13_stage_contexts(b, rp, chal="run", seed=0):
    """per R13 block stage, per R13 slot: (stage, block, G, slot, name, arg, cx, fn, rc, vals); the setup is
    `r13blocks.r13_block_terminals` + `check_stage`, restated (frozen v23)"""
    import zk60_native_rg_tokenblocks as TB
    import zk60_native_rg_gqa as GQ
    from zk60_native_rg_planes import PlaneIndex
    sh = b.run["shape"]
    if not R.is_r13_shape(sh):
        raise ValueError("not an R13 block shape")
    facts = RB.stage_facts(b)
    h24 = facts["stack"] == "LowH24"
    product_shift = 16 if h24 else 24
    full = TB.TokenBlockShim(b, None)
    index = PlaneIndex(full)
    pir = R.check_plane_index(index, sh)
    ls = pir.get("sigma_limbs", 0)
    counts = {"ls": ls, "h24": h24, "dd": int(sh.get("dd_cap", 0)) > 0}
    if counts["dd"]:
        raise ValueError("an R13 DD block profile: not applicable")
    out = []
    for p in facts["per_stage"]:
        kb = p["block"]
        if R13_BLOCKS is not None and kb not in R13_BLOCKS:
            continue
        base = p["base"]
        cal_values = {RB.SHAPE_KEY_OF_BASE[kk]: int(v) for kk, v in base.items()}
        shim = TB.TokenBlockShim(b, cal_values, blocks=[kb], extra={"norm_wrho": sh["norm_wrho"]})
        view = TB._ReplayView(rp, [kb])
        rc = R.R13Ctx(facts["stack"], p["precision"], p["gate_shift"], sh["wrho_s"], counts, product_shift)
        rc.base = base
        gate = T.TerminalGate(shim, index)
        gate.set_stage(0)
        doc = shim.stages[0].doc
        rng = random.Random(f"r22-r13nl/{kb}/{seed}")
        # the public tables are always built (and digest / structure checked) at the RUN's challenges; a random
        # mode then replaces the challenges the PORT reads (cx.dc, cx.alpha / beta / g_*), which is all the
        # symbolic expansion depends on (the table VALUES are variables of the IR)
        gate.set_logup(doc["logup_challenges"])
        gate._lk_cache["L"] = R.r13_lookups("L", rc.prec, rc.gate_shift, rc.wrho_s, rc.counts)
        lam_z = T.lam_z_of(doc)
        planes = [[pl.name for pl in row] for row in index.slot_planes]
        group = GQ.GroupFactors(shim, replay=view, stage_docs=[doc], definition=None)
        legacy_ports = {s_: (nm_, fn_) for s_, nm_, fn_, _r in T.PORTS}
        for s in SLOTS7:
            arg = doc["arguments"][s]
            dc = [f2_from_list(x) for x in arg["definition_challenges"]]
            if s in R.R13_PORTS:
                nm, fn = R.R13_PORTS[s]
                names = planes[s]
            else:
                # SC_LZC: the legacy body whose Dom::L lookups ARE R13's (AccuracyIds::lookups(Dom::L), the
                # gate's `_lk_cache["L"]` above), addressed by the legacy plane names (check_stage's rule)
                nm0, fn0 = legacy_ports[s]
                nm, fn = f"{nm0} (legacy body, R13 Dom::L lookups)", (lambda v, cx_, rc_, f=fn0: f(v, cx_))
                names = [R.LEGACY_NAME_OF_R13.get(n, n) for n in planes[s]]
            cx = T.SlotCtx(gate, arg, names, dc, lam_z, structural=True)
            cx.bilinear_definition = group.definition
            cx.group_table_required = group.group_table_required()
            cx.rho_full = view.stages[0]["rho"][s]
            if s in R.R13_PORTS:
                R.build_public_r13(gate, cx, check_digests=True)
            else:
                gate.build_public(cx, check_digests=True)
            vals = gate.vals(cx) if chal == "run" else None
            cx.public_values = {}      # the table VALUES are not needed past `vals` (the IR's tables are variables)
            if chal == "random":
                cx.dc = [_rand_f2(rng) for _ in dc]
                cx.alpha, cx.beta = _rand_f2(rng), _rand_f2(rng)
                gm = _rand_f2(rng)
                cx.g_u8, cx.g_exp, cx.g_act = (f2_mul_base(gm, 133), f2_mul_base(gm, 129), f2_mul_base(gm, 134))
                cx.g_dd = f2_mul_base(gm, 135)
            out.append({"stage": p["stage"], "block": kb, "G": p["gate_shift"], "slot": s, "name": nm,
                        "arg": arg, "cx": cx, "fn": fn, "rc": rc, "vals": vals})
    return out, pir


def r13_table_kinds(ent):
    cx, arg = ent["cx"], ent["arg"]
    supp_idx = {i for key, i in cx.pub_of.items() if key[0] == "supp" or key == ("captured", "act_support")}
    tables = []
    for i, t in enumerate(arg["tables"]):
        if t["kind"] == "eq":
            kk, lab = f"eq(start={t['start']},|point|={len(t['point'])})", "eq"
        elif t["kind"] == "public":
            what = next((f"{key[0]}:{key[1]}" for key, j in cx.pub_of.items() if j == i), "public")
            kk, lab = (f"supp({what})", what) if i in supp_idx else ("pub", what)
        else:
            role = t.get("role", "")
            kk, lab = ("A" if role == "A" else "H" if role == "H" else "EP"), f"{role} claim {t.get('claim')}"
        tables.append({"kind": kk, "label": lab, "prov": "R13 port (r13slots) over Poly"})
    return tables


def r13_to_ir(ent):
    arg = ent["arg"]
    names = [f"T{i:02d}" for i in range(len(arg["tables"]))]
    Pl = Poly._co(ent["fn"]([Poly.var(n) for n in names], ent["cx"], ent["rc"]))
    idx = {n: i for i, n in enumerate(names)}
    ir = _ir(f"stage {ent['stage']} (G {ent['G']}) slot {ent['slot']} {ent['name']}", ent["slot"], arg, Pl, idx,
             r13_table_kinds(ent))
    return ir, Pl, names


# ------------------------------------------------------- the stages, per part
def stages_for(NL, NF, irs, sds, label):
    slots = [NL.Slot(ir, "token", {}) for ir in irs]
    fid = [TN.fidelity(NL, NF, ir, sd) for ir, sd in zip(irs, sds)]
    s1 = [TN.s1_row(NL, NF, sl) for sl in slots]
    s4 = TN.s4_rows(NL, NF, slots)
    groups = {}
    for ir, r in zip(irs, s1):
        groups.setdefault(ir["name"].split(" slot ")[0] if " slot " in ir["name"] else ir["name"].split("-")[0], []).append(r)
    s2 = {g: {"slots": len(rows), "sum_L": sum(r["L"] for r in rows), "sum_dimC": sum(r["dimC"] for r in rows),
              "sum_ker": sum(r["L"] - r["dimC"] for r in rows), "worst_L": max(r["L"] for r in rows),
              "budget_all_ok": all(r["budget_ok"] for r in rows)} for g, rows in groups.items()}
    return {"label": label, "F0_fidelity": f"{sum(fid)}/{len(fid)}", "fidelity_all": all(fid), "S2": s2,
            "S1": s1, "S1_summary": {
                "premise_holds": sum(1 for r in s1 if r["premise_holds"]),
                "public_factor_every_monomial": sum(1 for r in s1 if r["public_factor_in_every_monomial_exact"]),
                "degree_fits": sum(1 for r in s1 if r["degree_fits"]),
                "budget_ok": sum(1 for r in s1 if r["budget_ok"]), "of": len(s1)},
            "S4": s4, "S4_summary": {"miniatures_pass": sum(1 for r in s4 if r["passes"]),
                                     "terminal_map_onto": sum(1 for r in s4 if r["terminal_map"]["onto_Fp2^m"]),
                                     "of": len(s4)}}, slots


def mode_ok(pm, n):
    return (pm["fidelity_all"] and pm["S1_summary"]["premise_holds"] == n
            and pm["S1_summary"]["public_factor_every_monomial"] == n and pm["S1_summary"]["degree_fits"] == n
            and pm["S1_summary"]["budget_ok"] == n and pm["S4_summary"]["miniatures_pass"] == n
            and pm["S4_summary"]["terminal_map_onto"] == n)


def run_classifier(NL, NF, b, rp):
    rec = {}
    if SKIP_CLASS_T0:
        tt = {"slots_equal": None, "slots_checked": 0, "ok": True,
              "skipped": "needs B-3 (a checkpoint stream); gate round 20 measured it 12 / 12 on this capture"}
    else:
        tt = CT.check_classify_terminals(b, rp)
    rec["T0_terminal_identity"] = {k_: tt.get(k_) for k_ in ("slots_equal", "slots_checked", "ok", "skipped")}
    per_mode, keep = {}, None
    for chal, seed in [("run", 0), ("random", 1), ("random", 2), ("random", 3)]:
        key = chal if chal == "run" else f"random-{seed}"
        defs = class_slot_defs(b, rp, chal, seed)
        irs = [class_to_ir(*d) for d in defs]
        sds = [d[3] for d in defs]
        pm, slots = stages_for(NL, NF, irs, sds, key)
        per_mode[key] = pm
        if chal == "run":
            keep = (irs, slots, sds)
    irs, slots, sds = keep
    rec["per_challenge_mode"] = per_mode
    rec["S3_pairs"] = sorted({(sl.main + sl.ext, sl.d) for sl in slots})
    rec["S3_fact21"] = TN.s3_pairs(NL, NF, rec["S3_pairs"])
    rec["S5_controls"] = TN.controls(NL, NF, irs, slots, sds)
    rec["ir_run_challenges"] = {"schema": "zk60-slot-ir/1-classify", "slots": irs}
    n = len(irs)
    rec["slots"] = n
    rec["ok"] = bool(all(mode_ok(pm, n) for pm in per_mode.values()) and tt["ok"]
                     and rec["S3_fact21"]["tight"] == rec["S3_fact21"]["checks"] and rec["S5_controls"]["ok"])
    return rec


def run_r13(NL, NF, b, rp):
    rec = {"slots_used": list(SLOTS7), "not_applicable": {"23 SC_DD and the DD softmax twin":
                                                                 "DD-profile only; no classifier profile is DD"}}
    per_mode, keep = {}, None
    for chal, seed in [("run", 0), ("random", 1), ("random", 2), ("random", 3)]:
        key = chal if chal == "run" else f"random-{seed}"
        ents, pir = r13_stage_contexts(b, rp, chal, seed)
        irs, sds, fid_rows = [], [], []
        for e in ents:
            ir, Pl, names = r13_to_ir(e)
            irs.append(ir)
            sds.append(PortSD(e["fn"], e["cx"], e["rc"]))
            if chal == "run":
                num = e["fn"](e["vals"], e["cx"], e["rc"])
                rec_tp = f2_from_list(e["arg"]["terminal_polynomial"])
                e0 = eval_poly(Pl, dict(zip(names, e["vals"]))) == num
                pi = e["cx"].priv_idx[0] if e["cx"].priv_idx else None
                t0_ctl = None
                if pi is not None:
                    v2 = list(e["vals"])
                    v2[pi] = f2_add(v2[pi], (1, 0))
                    t0_ctl = e["fn"](v2, e["cx"], e["rc"]) != rec_tp
                fid_rows.append({"T0_control_one_terminal_plus_1_fires": t0_ctl, "stage": e["stage"], "block": e["block"], "G": e["G"], "slot": e["slot"],
                                 "name": e["name"], "T0_port_equals_recorded_terminal_polynomial": num == rec_tp,
                                 "E0_expansion_equals_port": e0, "monomials": len(Pl.t),
                                 "tables": len(e["arg"]["tables"]), "declared_degree": e["arg"]["degree"],
                                 "max_product_degree": ir["max_product_degree"]})
        pm, slots = stages_for(NL, NF, irs, sds, key)
        per_mode[key] = pm
        if chal == "run":
            keep = (irs, slots, sds)
            rec["T0_E0"] = fid_rows
            rec["plane_index_r13_ok"] = pir.get("ok")
    irs, slots, sds = keep
    rec["per_challenge_mode"] = per_mode
    rec["S3_pairs"] = sorted({(sl.main + sl.ext, sl.d) for sl in slots})
    rec["S3_fact21"] = TN.s3_pairs(NL, NF, rec["S3_pairs"])
    rec["S5_controls"] = TN.controls(NL, NF, irs, slots, sds)
    rec["ir_run_challenges"] = {"schema": "zk60-slot-ir/1-r13-block", "slots": irs}
    n = len(irs)
    rec["slots"] = n
    t0e0 = all(r["T0_port_equals_recorded_terminal_polynomial"] and r["E0_expansion_equals_port"]
               and r["T0_control_one_terminal_plus_1_fires"] for r in rec["T0_E0"])
    rec["T0_E0_all"] = t0e0
    rec["ok"] = bool(all(mode_ok(pm, n) for pm in per_mode.values()) and t0e0
                     and rec["S3_fact21"]["tight"] == rec["S3_fact21"]["checks"] and rec["S5_controls"]["ok"])
    return rec


def real_pairs(NL, NF, real_dir):
    """S3 at every distinct (N, d) of a REAL capture's classifier and R13 block slots (stage files only)"""
    run = json.load(open(os.path.join(real_dir, "run.json")))
    n_st = run["stages"]
    pairs = {"classifier": set(), "r13_block": set()}
    for k in range(n_st):
        if 0 < k < n_st - 1 and k not in (1, n_st - 2):
            continue
        s = json.load(open(os.path.join(real_dir, f"stage-{k:02d}.json")))
        for a in s["arguments"]:
            if s["stage_kind"] in ("IN-C", "OUT-C"):
                pairs["classifier"].add((a["main"] + a["extension"], a["degree"]))
            elif a["slot"] in R.R13_SLOTS:
                pairs["r13_block"].add((a["main"] + a["extension"], a["degree"]))
    # every block stage shares the block shape: confirm on the stage list of run.json
    allp = sorted(pairs["classifier"] | pairs["r13_block"])
    return {"real_capture": os.path.basename(real_dir), "pairs_classifier": sorted(pairs["classifier"]),
            "pairs_r13_block": sorted(pairs["r13_block"]), "S3_fact21": TN.s3_pairs(NL, NF, allp)}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--parts", default="classifier,r13")
    ap.add_argument("--real-pairs", default="")
    ap.add_argument("--lazy-store", action="store_true")
    ap.add_argument("--no-b3", action="store_true")
    ap.add_argument("--skip-classifier-t0", action="store_true")
    ap.add_argument("--r13-blocks", default="")
    a = ap.parse_args(argv)
    global R13_BLOCKS, SKIP_CLASS_T0
    if a.lazy_store:
        lazy_store()
    if a.no_b3:
        no_b3()
    SKIP_CLASS_T0 = a.skip_classifier_t0
    if a.r13_blocks:
        R13_BLOCKS = [int(x) for x in a.r13_blocks.split(",") if x]
    NL, NF = TN.load_nl()
    t0 = time.time()
    b = CG.load(a.bundle)
    rp = CG.ClassRunReplay(b).run()
    rec = {"what": "gate round 22 item 3: NL-1 S1-S5 through the frozen nl_check on the classifier slots and the "
                   "R13-redefined block slots, IR from the gate's own transcriptions over Poly; NOT a privacy result",
           "privacy_acceptance": False, "bundle": b.name, "bundle_dir": b.dir, "profile": b.profile,
           "nl_check_pins": TN.NL_PINS, "replay_ok": rp.summary()["ok"], "parts": {},
           "flags": {"lazy_store": a.lazy_store, "no_b3": a.no_b3, "skip_classifier_t0": a.skip_classifier_t0,
                     "r13_blocks": R13_BLOCKS}}
    parts = [x for x in a.parts.split(",") if x]
    if "classifier" in parts:
        ts = time.time()
        rec["parts"]["classifier"] = run_classifier(NL, NF, b, rp)
        rec["parts"]["classifier"]["seconds"] = round(time.time() - ts, 1)
        print(f"classifier: ok {rec['parts']['classifier']['ok']} ({time.time() - t0:.1f} s)", flush=True)
    if "r13" in parts:
        ts = time.time()
        rec["parts"]["r13"] = run_r13(NL, NF, b, rp)
        rec["parts"]["r13"]["seconds"] = round(time.time() - ts, 1)
        print(f"r13: ok {rec['parts']['r13']['ok']} ({time.time() - t0:.1f} s)", flush=True)
    if a.real_pairs:
        rec["real_pairs"] = real_pairs(NL, NF, a.real_pairs)
    rec["summary"] = {}
    for nm, p in rec["parts"].items():
        rec["summary"][nm] = {
            "slots": p["slots"], "ok": p["ok"],
            "T0": p.get("T0_terminal_identity") or f"{sum(1 for r in p['T0_E0'] if r['T0_port_equals_recorded_terminal_polynomial'])}/{len(p['T0_E0'])}",
            "E0": None if nm == "classifier" else f"{sum(1 for r in p['T0_E0'] if r['E0_expansion_equals_port'])}/{len(p['T0_E0'])}",
            "per_mode": {k: {"F0": v["F0_fidelity"], "S1": v["S1_summary"], "S4": v["S4_summary"]}
                         for k, v in p["per_challenge_mode"].items()},
            "S3": f"{p['S3_fact21']['tight']}/{p['S3_fact21']['checks']} at {p['S3_pairs']}",
            "S5": p["S5_controls"]["summary"], "S5_ok": p["S5_controls"]["ok"]}
    if "real_pairs" in rec:
        rp_ = rec["real_pairs"]
        rec["summary"]["real_pairs_S3"] = (f"{rp_['S3_fact21']['tight']}/{rp_['S3_fact21']['checks']} at "
                                           f"classifier {rp_['pairs_classifier']} r13 {rp_['pairs_r13_block']}")
    rec["ok"] = bool(rec["replay_ok"] and all(p["ok"] for p in rec["parts"].values())
                     and ("real_pairs" not in rec
                          or rec["real_pairs"]["S3_fact21"]["tight"] == rec["real_pairs"]["S3_fact21"]["checks"]))
    rec["status"] = "PASS" if rec["ok"] else "NOT-OK"
    rec["seconds"] = round(time.time() - t0, 1)
    rec["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
    rec["tool_sha256"] = {os.path.basename(p): _sha(p) for p in (
        os.path.abspath(__file__), TN.__file__, TT.__file__, CT.__file__, R.__file__, RB.__file__, T.__file__)}
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"{a.name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
        fh.write("\n")
    print(json.dumps(rec["summary"], indent=1, default=str))
    print(f"record: {path}  status {rec['status']}")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
