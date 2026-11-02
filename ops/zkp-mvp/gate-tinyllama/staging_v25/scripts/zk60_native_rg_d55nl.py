#!/usr/bin/env python3
"""[v25 STAGING, 2026-11-02, NL-1 / PRE lane] NL-1 S1-S5, the non-linear table
checks, on the R13 slots of EVERY FORK of a REGISTERED R13 D55 ("commit, fork,
join") run capture.

    python3 -B zk60_native_rg_d55nl.py --bundle <registered R13 D55 bundle> --evidence <dir> [--name N]

Called from `zk60_native_rg_d55.d55_gate` (part `NL-1 R13 slots, every fork`)
for the R13 family; standalone it runs the D55 loader, the replay and R13-3
first (G_k is recovered there, not read).

WHAT WAS PORTED.  Gate round 22 item 3's `run_r13`
(`ops/zkp-mvp/gate-tinyllama/r22-item3/zk60_r22_classnl.py`, run on the R13
classifier captures, D12a runs, and in gate round 23 on all 26 real blocks;
accepted as the classifier statement's G-R2): NL-1 through the FROZEN
`results/zk60_nonlinear_channel_shaped/nl_check.py` (its digests checked
against `zk60_native_rg_tokennl.NL_PINS` before import; no bytecode written
there), with a slot IR built from the gate's own R13 port
(`zk60_native_rg_r13slots.R13_PORTS`, and SC_LZC's legacy body with R13's
Dom::L lookups) expanded over the `tokenterminals.Poly` ring.  The SLOTS are
r22's seven R13-changed slots: SC_LZC 3 (its Dom::L lookups change at R13) and
the six bodies `argument_accuracy.rs` redefines, SC_DZC 14, SC_QZC 15,
SC_KVZC 16, SC_SZC 17, SC_FZC 18, SC_TAB 19.  SC_DD 23 and the DD softmax twin
exist only at DD profiles, which the D55 R13 port refuses by name.

WHAT CHANGED FROM r22 (the layout, nothing else):
  * the slot contexts are built per FORK through `zk60_native_rg_d55r13`'s
    one-fork shim (`_shim_for`, `_ForkReplayView`, `_ctx`): the fork's own
    calibration (`fork_calibrations`: the line's base and the fork's own
    clauses) and its R13 gate denominator G_k RECOVERED by R13-3 (a D55 stage
    line does not print it: the D60 record's finding 1);
  * every module is the v25 staging one (byte-identical to frozen v23 for
    tokennl, tokenterminals, terminals, r13slots, r13blocks, gqa: checked at
    the port), and the frozen nl_check is found in this repository rather
    than at the laptop path `zk60_native_rg_tokennl.NL_DIR` names;
  * the Fp2 operations of `zk60_native_rg_terminals` / `_r13slots` are
    rebound to the type-dispatching versions INSIDE a context manager and
    restored after (r22 rebound them for the whole process);
  * the bilinear definition is selected under `d55r13.argument_reading`
    (the in-memory reading of this tree's argument.rs `define`), as R13-3.

THE CHAIN OF FIDELITY, before any NL-1 stage (each failing first):
  T-0  the port's NUMERIC value at the fork's terminals, the rebuilt or
       structure-checked public tables and the RE-DERIVED challenges equals
       the fork's recorded terminal polynomial; control: one private terminal
       + 1 -> T-0 fails on that slot instance;
  E-0  the Poly expansion evaluated at those same values equals the port;
  F-0  the IR evaluated by `nl_check.Slot` at random table values equals the
       port evaluated numerically (three seeds); control F-1 (S5).

THE STAGES (nl_check's numbering; `zk60_native_rg_tokennl`'s functions,
unchanged), in four challenge modes (the run's re-derived values and three
random seeds):
  S1  per slot instance: the per-extension-round premise, a public factor in
      every monomial, the degree walk within the declared degree, the
      per-variable bound, the mask budget L + 256 <= 512;
  S2  the per-fork sums;
  S3  Fact 2.1 at every distinct (N, d) of the seven slots, five regimes;
      and ALSO at every distinct (N, d) of ALL 23 slots of every fork, with
      the mask budget of all 23 (round 23's `S3_ALL_PAIRS_REAL` carry for the
      16 unchanged slots);
  S4  per slot instance a MINIATURE honest masked run and the terminal map
      onto Fp2^m;
  S5  N5-1 (a public factor stripped), N5-2 (one degree short, at zero
      slack), N5-3 (the mask one degree short), N5-4 (C7 / C8), F-1 (one IR
      coefficient perturbed).

D55 CONTROLS (new here, each predicted, every one must fire):
  NL-T0      one private terminal + 1, every slot instance (r22's);
  NL-TAB-GC  a doctored TABLE ENTRY that passes the structure checks: fork
             kc's SC_FZC group column, one channel's group id + 1 on every
             token, the digest recomputed -> T-0 fails at slot 18 of that
             fork and ONLY there (the arithmetic catches it);
  NL-TAB-ACT a doctored TABLE ENTRY the structure check refuses: fork kc's
             SC_TAB ACT3 entry 100 + 1, the digest recomputed -> slot 19 of
             that fork refused, and only it;
  NL-G       fork kc evaluated at G_k + 1 -> T-0 fails at SC_FZC only.

WHAT IT DOES NOT SHOW.  S1-S5 on the 16 slots R13 does not redefine (D33's
argument of record carries them; R13-3 checks their terminal identity 23 / 23
on every fork; S3 and the budget at their (N, d) are computed here); nothing
about W16; nothing about the LAW of the masks beyond nl_check's model.
NOTHING HERE IS A PRIVACY STATEMENT OR AN ACCEPTANCE.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import sys
import time

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_r13slots as R  # noqa: E402
import zk60_native_rg_terminals as T  # noqa: E402
import zk60_native_rg_tokennl as TN  # noqa: E402
import zk60_native_rg_tokenterminals as TT  # noqa: E402
from zk60_native_jv_field import f2_add, f2_from_list, f2_mul, f2_mul_base, f2_sub  # noqa: E402

Poly = TT.Poly
P = TT.P
# r22's SLOTS7: SC_LZC 3 and the six R13-redefined bodies (r13slots.R13_SLOTS)
SLOTS7 = (3,) + tuple(R.R13_SLOTS)
SC_FZC, SC_TAB = 18, 19
NL_DIR_NAME = os.path.join("results", "zk60_nonlinear_channel_shaped")
PART = "NL-1 R13 slots, every fork"
NOT_HERE_CLOSED = "NL-1 S1-S5 (the non-linear table checks) on the R13 slots"


# ------------------------------------------------------- the frozen nl_check
def nl_dir() -> str:
    """the frozen NL-1 scripts in THIS repository (`ZK60_NL_CHECK_DIR`
    overrides); `zk60_native_rg_tokennl.NL_DIR` names the laptop's path"""
    env = os.environ.get("ZK60_NL_CHECK_DIR")
    if env:
        return env
    d = HERE
    for _ in range(8):
        cand = os.path.join(d, NL_DIR_NAME)
        if os.path.isfile(os.path.join(cand, "nl_check.py")):
            return cand
        d = os.path.dirname(d)
    return ""


def load_nl():
    """`zk60_native_rg_tokennl.load_nl` at this repository's copy: the same
    digests (TN.NL_PINS) are required before import"""
    d = nl_dir()
    if not d:
        raise RuntimeError(f"the frozen NL-1 scripts ({NL_DIR_NAME}) are not found above {HERE}")
    got = {n: _sha(os.path.join(d, n)) for n in TN.NL_PINS}
    if got != TN.NL_PINS:
        raise RuntimeError(f"the frozen NL-1 scripts moved: {got} != {TN.NL_PINS}")
    if d not in sys.path:
        sys.path.insert(0, d)
    import nl_check as NL  # noqa: E402
    import nl_field as NF  # noqa: E402
    for m, n in ((NL, "nl_check.py"), (NF, "nl_field.py")):
        if os.path.realpath(m.__file__) != os.path.realpath(os.path.join(d, n)):
            raise RuntimeError(f"{n} was imported from {m.__file__}, not from the pinned {d}")
    return NL, NF, d


def _sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


# ------------------------------------------------------- polymorphic field ops (r22, scoped)
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


class poly_ops:
    """r22's rebinding of `add / sub / mul / mulb` in the terminals and r13slots
    namespaces to type-dispatching versions (a Poly operand goes to the Poly
    ring, two Fp2 tuples to the frozen field functions, so every numeric path
    computes exactly what it computed before), for the duration of the block
    only; the originals are restored after (and checked)"""
    NAMES = ("add", "sub", "mul", "mulb")

    def __enter__(self):
        self.saved = {m.__name__: {n: getattr(m, n) for n in self.NAMES} for m in (T, R)}
        for m in (T, R):
            m.add, m.sub, m.mul, m.mulb = padd, psub, pmul, pmulb
        return self

    def __exit__(self, *exc):
        for m in (T, R):
            for n, f in self.saved[m.__name__].items():
                setattr(m, n, f)
        self.restored = all(getattr(m, n) is self.saved[m.__name__][n] for m in (T, R) for n in self.NAMES)
        return False


def _fpow(x, e):
    out = (1, 0)
    for _ in range(e):
        out = f2_mul(out, x)
    return out


def eval_poly(pl, assign):
    acc = (0, 0)
    for mono, c in pl.t.items():
        term = c
        for (n, e) in mono:
            term = f2_mul(term, _fpow(assign[n], e))
        acc = f2_add(acc, term)
    return acc


def _fstr(v):
    return f"{v[0]}+{v[1]}u"


def _rand_f2(rng):
    return (rng.randrange(P), rng.randrange(P))


# ------------------------------------------------------- the IR (r22's, unchanged)
class PortSD:
    """`sd.poly(vals)` for TN.fidelity / TN.controls: the R13 port evaluated
    NUMERICALLY at the given table values (F2 or tuples)"""

    def __init__(self, fn, cx, rc):
        self.fn, self.cx, self.rc = fn, cx, rc

    def poly(self, vals):
        v = [x.v if isinstance(x, TT.F2) else x for x in vals]
        return self.fn(v, self.cx, self.rc)


def _ir(name, s, arg, pl, idx, tables):
    terms = []
    for mono, c in sorted(pl.t.items()):
        inner = []
        for n, e in mono:
            inner.extend([{"table": idx[n]}] * e)
        terms.append({"coef": {"value": _fstr(c)}, "wrapper": [], "inner": inner, "degree": len(inner)})
    maxdeg = max((t["degree"] for t in terms), default=0)
    return {"slot": s, "name": name, "kind": arg["kind"], "main_rounds": arg["main"],
            "extension_rounds": arg["extension"], "declared_degree": arg["degree"], "max_product_degree": maxdeg,
            "pad_on": None, "group_bits": 0, "tables": tables, "nodes": [], "terms": terms}


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
        tables.append({"kind": kk, "label": lab, "prov": "R13 port (r13slots) over Poly, D55 fork"})
    return tables


def r13_to_ir(ent):
    arg = ent["arg"]
    names = [f"T{i:02d}" for i in range(len(arg["tables"]))]
    pl = Poly._co(ent["fn"]([Poly.var(n) for n in names], ent["cx"], ent["rc"]))
    idx = {n: i for i, n in enumerate(names)}
    ir = _ir(f"fork {ent['fork']} (G {ent['G']}) slot {ent['slot']} {ent['name']}", ent["slot"], arg, pl, idx,
             r13_table_kinds(ent))
    return ir, pl, names


# ------------------------------------------------------- the contexts, per fork
def fork_setup(b, facts):
    """(index, counts, calibrations) shared by every fork"""
    import zk60_native_rg_d55r13 as X
    from zk60_native_rg_planes import PlaneIndex
    sh = b.run["shape"]
    index = PlaneIndex(X.D55BlockShim(b, None))
    ls = sum(1 for p in index.a_planes if p.name.startswith("A_SR") and p.name[4:].isdigit())
    counts = {"ls": ls, "h24": facts["stack"] == "LowH24", "dd": int(sh.get("dd_cap", 0)) > 0}
    if counts["dd"]:
        raise ValueError("an R13 DD block profile: SC_DD and the DD softmax twin are not ported")
    return index, counts, {c["fork"]: c for c in X.fork_calibrations(b, facts)}


def fork_contexts(b, rp, facts, index, counts, cal, k, g, chal="run", seed=0, stage_doc=None):
    """r22 `r13_stage_contexts` for ONE fork through the D55 one-fork shim:
    per R13 slot, {fork, G, slot, name, arg, cx, fn, rc, vals} -- or
    {fork, slot, refused} when the slot's public tables are refused (a
    structure / digest failure: the T-0 of that slot instance fails).  The
    public tables are built (and digest / structure checked) at the RUN's
    challenges; a random mode replaces the challenges the PORT reads (cx.dc,
    alpha / beta / g_*), which is all the symbolic expansion depends on"""
    import zk60_native_rg_d55r13 as X
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
    for s in SLOTS7:
        arg = doc["arguments"][s]
        dc = [f2_from_list(x) for x in arg["definition_challenges"]]
        if s in R.R13_PORTS:
            nm, fn = R.R13_PORTS[s]
            names = planes[s]
        else:
            nm0, fn0 = legacy_ports[s]
            nm, fn = f"{nm0} (legacy body, R13 Dom::L lookups)", (lambda v, cx_, rc_, f=fn0: f(v, cx_))
            names = [R.LEGACY_NAME_OF_R13.get(n, n) for n in planes[s]]
        cx = T.SlotCtx(gate, arg, names, dc, lam_z, structural=True)
        cx.bilinear_definition = group.definition
        cx.group_table_required = group.group_table_required()
        cx.rho_full = view.stages[0]["rho"][s]
        try:
            if s in R.R13_PORTS:
                R.build_public_r13(gate, cx, check_digests=True)
            else:
                gate.build_public(cx, check_digests=True)
        except (ValueError, IndexError, KeyError) as exc:
            out.append({"fork": k, "G": g, "slot": s, "name": nm, "refused": str(exc)[:300]})
            continue
        vals = gate.vals(cx) if chal == "run" else None
        cx.public_values = {}      # the table VALUES are not needed past `vals` (the IR's tables are variables)
        if chal == "random":
            cx.dc = [_rand_f2(rng) for _ in dc]
            cx.alpha, cx.beta = _rand_f2(rng), _rand_f2(rng)
            gm = _rand_f2(rng)
            cx.g_u8, cx.g_exp, cx.g_act = (f2_mul_base(gm, 133), f2_mul_base(gm, 129), f2_mul_base(gm, 134))
            cx.g_dd = f2_mul_base(gm, 135)
        out.append({"fork": k, "G": g, "slot": s, "name": nm, "arg": arg, "cx": cx, "fn": fn, "rc": rc, "vals": vals})
    return out


def t0_row(e):
    """T-0 / E-0 and the one-terminal control for one run-mode slot instance"""
    if "refused" in e:
        return {"fork": e["fork"], "G": e["G"], "slot": e["slot"], "name": e["name"], "refused": e["refused"],
                "T0_port_equals_recorded_terminal_polynomial": False, "E0_expansion_equals_port": False,
                "T0_control_one_terminal_plus_1_fires": None}
    ir, pl, names = r13_to_ir(e)
    num = e["fn"](e["vals"], e["cx"], e["rc"])
    rec_tp = f2_from_list(e["arg"]["terminal_polynomial"])
    e0 = eval_poly(pl, dict(zip(names, e["vals"]))) == num
    pi = e["cx"].priv_idx[0] if e["cx"].priv_idx else None
    t0_ctl = None
    if pi is not None:
        v2 = list(e["vals"])
        v2[pi] = f2_add(v2[pi], (1, 0))
        t0_ctl = e["fn"](v2, e["cx"], e["rc"]) != rec_tp
    return {"fork": e["fork"], "G": e["G"], "slot": e["slot"], "name": e["name"],
            "T0_port_equals_recorded_terminal_polynomial": num == rec_tp, "E0_expansion_equals_port": e0,
            "T0_control_one_terminal_plus_1_fires": t0_ctl, "monomials": len(pl.t),
            "tables": len(e["arg"]["tables"]), "declared_degree": e["arg"]["degree"],
            "max_product_degree": ir["max_product_degree"]}, ir


def _t0_failing(ents) -> set:
    """the slots of a run-mode context list whose T-0 does not hold"""
    bad = set()
    for e in ents:
        if "refused" in e:
            bad.add(e["slot"])
            continue
        if e["fn"](e["vals"], e["cx"], e["rc"]) != f2_from_list(e["arg"]["terminal_polynomial"]):
            bad.add(e["slot"])
    return bad


# ------------------------------------------------------- the stages (r22's stages_for / mode_ok)
def stages_for(NL, NF, irs, sds, label):
    slots = [NL.Slot(ir, "token", {}) for ir in irs]
    fid = [TN.fidelity(NL, NF, ir, sd) for ir, sd in zip(irs, sds)]
    s1 = [TN.s1_row(NL, NF, sl) for sl in slots]
    s4 = TN.s4_rows(NL, NF, slots)
    groups = {}
    for ir, r in zip(irs, s1):
        groups.setdefault(ir["name"].split(" slot ")[0], []).append(r)
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


def all_slot_pairs(NL, NF, b):
    """S3 (Fact 2.1, five regimes) at every distinct (rounds, degree) pair of
    ALL 23 slots of every fork, and the mask budget L + 256 <= 512 of every
    slot -- round 23's carry for the 16 slots R13 does not redefine (the stage
    files' slot records only)"""
    pairs, budget = set(), []
    for st in b.stages:
        for a in st.doc["arguments"]:
            n_, d_ = a["main"] + a["extension"], a["degree"]
            pairs.add((n_, d_))
            L = NL.mask_len(n_, d_)
            budget.append({"fork": st.index, "slot": a["slot"], "N": n_, "d": d_, "L": L, "ok": L + NL.MASK_Q <= NL.MASK_MSG})
    pairs = sorted(pairs)
    s3 = TN.s3_pairs(NL, NF, pairs)
    return {"pairs": [list(p) for p in pairs], "S3_fact21": {kk: s3[kk] for kk in ("checks", "tight")},
            "S3_rows": s3["rows"], "slot_instances": len(budget), "worst_L": max(r["L"] for r in budget),
            "budget_all_ok": all(r["ok"] for r in budget),
            "budget_failures": [r for r in budget if not r["ok"]],
            "ok": s3["tight"] == s3["checks"] and all(r["ok"] for r in budget)}


# ------------------------------------------------------- the D55 controls
def d55_nl_controls(b, rp, facts, index, counts, cals, gates, kc) -> dict:
    """NL-TAB-GC, NL-TAB-ACT, NL-G on fork kc; each predicted to fail exactly
    its slot's T-0 on that fork"""
    from zk60_native_rg_r13blocks import _doc_with_public
    doc = b.stages[kc].doc
    sh = b.run["shape"]
    out = {}

    def bump_group(vals):                 # r13blocks R13-GC's perturbation, verbatim
        j = next(j for j in range(sh["hidden"]) if vals[j][0] in (0, 1))
        new = list(vals)
        for t in range(sh["tokens"]):
            x = t * sh["f_pad"] + j
            new[x] = ((vals[x][0] + 1) % T.P, 0)
        return new

    def bump_act(vals):                   # r13blocks R13-ACT's perturbation, verbatim
        new = list(vals)
        new[100] = T.add(vals[100], T.ONE)
        return new

    for name, what, slot, nth, fn in (
            ("NL-TAB-GC a doctored group-column entry", "one channel's group id + 1 on every token (digest recomputed; "
             "the structure check passes, so the ARITHMETIC must catch it)", SC_FZC, 0, bump_group),
            ("NL-TAB-ACT a doctored ACT3 table entry", "ACT3 compressed table entry 100 + 1 (digest recomputed; the "
             "structure check refuses it)", SC_TAB, 2, bump_act)):
        ents = fork_contexts(b, rp, facts, index, counts, cals[kc], kc, gates[kc], "run", 0,
                             stage_doc=_doc_with_public(doc, slot, nth, fn))
        got = _t0_failing(ents)
        out[name] = {"what": f"fork {kc}: {what}", "predicted": [slot], "failing": sorted(got),
                     "refusals": [e["refused"][:160] for e in ents if "refused" in e],
                     "fires": got == {slot}}
    g2 = gates[kc] + 1 if gates[kc] < 24 else gates[kc] - 1
    got = _t0_failing(fork_contexts(b, rp, facts, index, counts, cals[kc], kc, g2, "run", 0))
    out["NL-G the gate denominator moved"] = {"what": f"fork {kc} evaluated at G {gates[kc]} -> {g2}", "predicted": [SC_FZC],
                                             "failing": sorted(got), "fires": got == {SC_FZC}}
    out["on_fork"] = kc
    out["ok"] = all(v["fires"] for v in out.values() if isinstance(v, dict))
    return out


# ------------------------------------------------------- the part
def d55_nl1(b, rp, facts, gates, controls=True, control_fork=None) -> dict:
    """NL-1 S1-S5 on the seven R13 slots of every fork.  `gates`: {fork: G_k}
    recovered by R13-3 (a fork whose G is None is not evaluated, and the part
    is then false)"""
    import zk60_native_rg_d55r13 as X
    t0 = time.time()
    NL, NF, nld = load_nl()
    rec = {"what": "NL-1 S1-S5 through the frozen nl_check on the seven R13 slots (SC_LZC 3, SC_DZC 14, SC_QZC 15, "
                   "SC_KVZC 16, SC_SZC 17, SC_FZC 18, SC_TAB 19) of EVERY fork of a registered R13 D55 run, at each fork's "
                   "own calibration and its recovered R13 gate denominator; IR from the gate's own R13 port over Poly "
                   "(gate round 22 item 3's run_r13, ported to the D55 fork layout); NOT a privacy result",
           "privacy_acceptance": False, "privacy_property_established": False,
           "ported_from": "ops/zkp-mvp/gate-tinyllama/r22-item3/zk60_r22_classnl.py run_r13 / r13_stage_contexts",
           "nl_check_dir": nld, "nl_check_pins": TN.NL_PINS, "slots_used": list(SLOTS7),
           "not_applicable": {"23 SC_DD and the DD softmax twin": "DD-profile only; the D55 R13 port refuses a DD profile by name"},
           "not_run_here": "S1-S5 on the 16 slots R13 does not redefine: D33's argument of record (their terminal identity is "
                           "R13-3's, 23 / 23 per fork; S3 and the mask budget at their (N, d) are below)",
           "gates": {str(kk): v for kk, v in sorted(gates.items())}}
    forks = [st.index for st in b.stages]
    missing = [kk for kk in forks if gates.get(kk) is None]
    rec["forks_evaluated"] = [kk for kk in forks if kk not in missing]
    rec["forks_not_evaluated"] = missing
    index, counts, cals = fork_setup(b, facts)
    per_mode, keep, t0e0_rows = {}, None, []
    with X.argument_reading() as rd, poly_ops() as po:
        for chal, seed in [("run", 0), ("random", 1), ("random", 2), ("random", 3)]:
            key = chal if chal == "run" else f"random-{seed}"
            irs, sds = [], []
            for kk in rec["forks_evaluated"]:
                ents = fork_contexts(b, rp, facts, index, counts, cals[kk], kk, gates[kk], chal, seed)
                for e in ents:
                    if "refused" in e:
                        if chal == "run":
                            t0e0_rows.append(t0_row(e))
                        continue
                    if chal == "run":
                        row, ir = t0_row(e)
                        t0e0_rows.append(row)
                    else:
                        ir, _pl, _names = r13_to_ir(e)
                    irs.append(ir)
                    sds.append(PortSD(e["fn"], e["cx"], e["rc"]))
            pm, slots = stages_for(NL, NF, irs, sds, key)
            pm["instances"] = len(irs)
            per_mode[key] = pm
            if chal == "run":
                keep = (irs, slots, sds)
        irs, slots, sds = keep
        rec["T0_E0"] = t0e0_rows
        rec["per_challenge_mode"] = per_mode
        rec["S3_pairs"] = sorted({(sl.main + sl.ext, sl.d) for sl in slots})
        rec["S3_fact21"] = TN.s3_pairs(NL, NF, rec["S3_pairs"])
        rec["S5_controls"] = TN.controls(NL, NF, irs, slots, sds)
        rec["ir_run_challenges"] = {"schema": "zk60-slot-ir/1-r13-block-d55-fork", "slots": irs}
        kc = control_fork if control_fork is not None else (1 if 1 in rec["forks_evaluated"] else
                                                            (min(rec["forks_evaluated"]) if rec["forks_evaluated"] else None))
        if controls and kc is not None:
            rec["D55_controls"] = d55_nl_controls(b, rp, facts, index, counts, cals, gates, kc)
        elif controls:
            rec["D55_controls"] = {"skipped": "no fork evaluated", "ok": False}
    rec["poly_ops_restored_after"] = po.restored
    rec["argument_rs_reading"] = {"added_in_memory": rd.added, "removed_after": rd.removed}
    rec["all_23_slots_S3_and_budget"] = all_slot_pairs(NL, NF, b)
    n = len(irs)
    expected = 7 * len(forks)
    rec["slot_instances"] = n
    rec["slot_instances_expected"] = expected
    t0e0 = (len(t0e0_rows) == expected and all(
        r["T0_port_equals_recorded_terminal_polynomial"] and r["E0_expansion_equals_port"]
        and r["T0_control_one_terminal_plus_1_fires"] for r in t0e0_rows))
    rec["T0_E0_all"] = t0e0
    ctl_ok = rec.get("D55_controls", {}).get("ok", False) if controls else True
    rec["summary"] = {
        "forks": len(forks), "slot_instances": f"{n}/{expected}", "gates": rec["gates"],
        "T0": f"{sum(1 for r in t0e0_rows if r['T0_port_equals_recorded_terminal_polynomial'])}/{len(t0e0_rows)}",
        "E0": f"{sum(1 for r in t0e0_rows if r['E0_expansion_equals_port'])}/{len(t0e0_rows)}",
        "T0_control_fires": f"{sum(1 for r in t0e0_rows if r['T0_control_one_terminal_plus_1_fires'])}/{len(t0e0_rows)}",
        "per_mode": {kk: {"F0": v["F0_fidelity"], "S1": v["S1_summary"], "S4": v["S4_summary"]} for kk, v in per_mode.items()},
        "S3": f"{rec['S3_fact21']['tight']}/{rec['S3_fact21']['checks']} at {rec['S3_pairs']}",
        "S3_all_23_slots": f"{rec['all_23_slots_S3_and_budget']['S3_fact21']['tight']}/{rec['all_23_slots_S3_and_budget']['S3_fact21']['checks']}",
        "budget_all_23_slots": rec["all_23_slots_S3_and_budget"]["budget_all_ok"],
        "S5": rec["S5_controls"]["summary"], "S5_ok": rec["S5_controls"]["ok"],
        "D55_controls": {kk: v.get("fires") for kk, v in rec.get("D55_controls", {}).items() if isinstance(v, dict)}}
    rec["ok"] = bool(not missing and n == expected and all(mode_ok(pm, n) for pm in per_mode.values()) and t0e0
                     and rec["S3_fact21"]["tight"] == rec["S3_fact21"]["checks"] and rec["S5_controls"]["ok"]
                     and rec["all_23_slots_S3_and_budget"]["ok"] and ctl_ok and po.restored and rd.removed)
    rec["seconds"] = round(time.time() - t0, 1)
    return rec


def gates_from_r13_3(t3) -> dict:
    """{fork: G_k} from an R13-3 record (`zk60_native_rg_d55r13.r13_terminals`)"""
    return {p["fork"]: p["gate_shift_recovered"] for p in (t3 or {}).get("per_fork", [])}


def main(argv=None):
    import zk60_native_rg_d55 as D
    import zk60_native_rg_d55r13 as X
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name")
    ap.add_argument("--no-controls", action="store_true")
    a = ap.parse_args(argv)
    t0 = time.time()
    b = D.D55Bundle(a.bundle)
    facts = D.d55_facts(b)
    if facts.get("family") != "R13":
        raise SystemExit("not an R13-family D55 bundle")
    rp = D.D55Replay(b).run()
    if not rp.summary()["ok"]:
        raise SystemExit("the D55 replay failed")
    t3 = X.r13_terminals(b, rp, facts, controls=False)
    rec = d55_nl1(b, rp, facts, gates_from_r13_3(t3), controls=not a.no_controls)
    rec["R13-3_ok_used_for_the_gates"] = t3["ok"]
    rec["total_seconds"] = round(time.time() - t0, 1)
    try:
        import resource
        rec["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (1 << 20))
    except Exception:  # noqa: BLE001
        pass
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"d55nl-{a.name or os.path.basename(os.path.normpath(a.bundle))}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
    print(json.dumps(rec["summary"], indent=1, default=str))
    print(f"status: {'PASS' if rec['ok'] else 'NOT-OK'} ({rec['total_seconds']} s) -> {path}")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
