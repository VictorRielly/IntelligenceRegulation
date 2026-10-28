#!/usr/bin/env python3
"""[GATE ROUND 14, tools v17, 2026-10-20] NL-1's machine check, stages S1-S5,
on the DD slots of a native R9 DD capture (D30): slot 17, the softmax
zero-check's DD arm (no division clause, one tuple lookup into the row's
dictionary), and slot 23, `SC_DD`, the dictionary zero-check (Standalone,
appended last).  The FROZEN `nl_check.py` (results/zk60_nonlinear_channel_shaped/,
digests checked before import, no bytecode written there) is fed a slot IR of
each DD slot built from the gate's own SYMBOLIC transcription of `argument.rs`
R9, as a flat monomial expansion -- the token stages' method
(`zk60_native_rg_tokennl.py`), whose S1-S5 functions this module calls.

    python3 zk60_native_rg_ddnl.py --bundle <DD capture> --evidence <dir> --name <name>

NOTHING HERE IS A PRIVACY RESULT OR A PRIVACY ACCEPTANCE.

THE CHAIN OF FIDELITY (each a check, failing first where it could pass
vacuously):
  T-0  the terminals port (`zk60_native_rg_terminals.sc_szc_dd` / `sc_dd`)
       equals the Rust terminal polynomial on THIS capture, every stage
       (`check_terminals`);
  X-0  this module's symbolic transcription, evaluated numerically, equals
       the terminals port at random table values (three seeds per slot and
       stage) -- two independent transcriptions of the same Rust;
  F-0  the IR evaluated by `nl_check.Slot` equals the symbolic transcription
       at random table values (three seeds);
  F-1  (control) one IR coefficient perturbed: F-0 fails; X-1 (control) one
       sign of the tuple's beta^2 term flipped in the symbolic transcription:
       X-0 fails.

Challenge modes: the run's re-derived values (the replay) and three random
seeds.  S1 / S3 / S4 / S5 exactly as `zk60_native_rg_tokennl` runs them.
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
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_terminals as T  # noqa: E402
import zk60_native_rg_tokenterminals as TT  # noqa: E402
import zk60_native_rg_tokennl as TN  # noqa: E402
from zk60_native_rg_block import load_bundle  # noqa: E402
from zk60_native_rg_planes import plane_index_of  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402

DD_SLOTS = (T.SC_SZC, T.SC_DD)


def _sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def F(c):
    """a challenge or constant as the ring element both rings accept"""
    return c if isinstance(c, TT.F2) else TT.F2(c)


# ---------------------------------------------------------------------------
#  the SYMBOLIC transcription (operator arithmetic: TT.F2 numeric or TT.Poly)
# ---------------------------------------------------------------------------
def _helper_sum(v, lks, h0, alpha, mu):
    """`helper_sum` (argument.rs), in operator form"""
    def den(l):
        terms, cst = l
        a = F(cst)
        for (i, c) in terms:
            a = a + v[i] * F(T.k(c))
        return F(alpha) - a

    acc = None
    for j in range((len(lks) + 1) // 2):
        h = v[h0 + j]
        d1 = den(lks[2 * j])
        if 2 * j + 1 < len(lks):
            d2 = den(lks[2 * j + 1])
            rel = h * d1 * d2 - (d1 + d2)
        else:
            rel = h * d1 - F(T.ONE)
        term = F(mu[j]) * rel
        acc = term if acc is None else acc + term
    return acc if acc is not None else F(T.ZERO)


def _limbs(v, ix):
    acc = None
    for j, i in enumerate(ix):
        t = v[i] * F(T.POW256[j])
        acc = t if acc is None else acc + t
    return acc


def szc_dd_sym(v, cx, mu, nu, flip=False):
    """argument.rs R9 `SC_SZC if sh.dd_cap > 0`, symbolic"""
    n_help = cx.g.n_helpers("S")
    im = cx.p("causal", None)
    ght, gs = cx.p("supp", "Ht"), cx.p("supp", "S")
    lks = cx.g.lk_tables(cx, "S")
    one = F(T.ONE)
    mask, s8 = v[im], v[cx.t("A_S8")]
    zsel, e, pp = v[cx.t("A_ZSEL")], v[cx.t("A_E")], v[cx.t("A_P")]
    sm, mx = v[cx.t("A_SUM")], v[cx.t("A_MX")]
    k127 = F(T.k(-T.MASK_SCORE))
    delta = mx - mask * (s8 + k127) + k127
    c0 = zsel * zsel - zsel
    c1 = zsel * delta
    alpha, beta = F(cx.alpha), F(cx.beta)
    cxx = v[cx.t("H_SEXP")] * (alpha - (delta + beta * e + F(cx.g_exp))) - one
    beta2 = beta * beta
    if flip:
        beta2 = F(T.ZERO) - beta2
    ct = v[cx.t("H_STUPLE")] * (alpha - (F(cx.g_dd) + sm + beta * (mask * e) + beta2 * pp)) - one
    clauses = F(mu[0]) * c0 + F(mu[1]) * c1
    g = v[gs] if gs is not None else one
    zc = (_helper_sum(v, lks, cx.t("H_S0"), cx.alpha, mu[2:2 + n_help])
          + F(mu[2 + n_help]) * cxx + F(mu[3 + n_help]) * ct + g * clauses)
    gh = v[ght] if ght is not None else one
    host_rs = F(nu[0]) * gh * (sm + F(cx.lam_z))
    cal = cx.g.cal
    host_s = F(nu[1]) * g * (F(T.k(1 << cal.sh_s)) * s8 + v[cx.t("A_RSL")] - F(T.k(T.Calibration.half(cal.sh_s))))
    return v[cx.eq(0)] * zc + v[cx.eq(1)] * host_rs + v[cx.eq(2)] * host_s


def dd_sym(v, cx, mu, flip=False):
    """argument.rs R9 `SC_DD`, symbolic"""
    ls, lp = cx.g.counts["ls"], cx.g.counts["lp"]
    n_help = cx.g.n_helpers("Dd")
    one = F(T.ONE)
    ie = cx.c("dd_e_column")
    pd, md, sm, e = v[cx.t("A_PDICT")], v[cx.t("A_MDD")], v[cx.t("A_SUM")], v[ie]
    sr = _limbs(v, [cx.t(f"A_SR{j}") for j in range(ls)])
    sg = _limbs(v, [cx.t(f"A_SG{j}") for j in range(ls)])
    pl = _limbs(v, [cx.t(f"A_PL{j}") for j in range(lp)])
    c2 = F(T.k(1 << T.F_P)) * e - pd * sm - sr
    c3 = sg + sr + one - sm
    c4 = pd - pl
    alpha, beta = F(cx.alpha), F(cx.beta)
    beta2 = beta * beta
    if flip:
        beta2 = F(T.ZERO) - beta2
    ctab = v[cx.t("H_GDD")] * (alpha - (F(cx.g_dd) + sm + beta * e + beta2 * pd)) - md
    division = F(mu[0]) * c2 + F(mu[1]) * c3 + F(mu[2]) * c4
    lks = cx.g.lk_tables(cx, "Dd")
    inner = division + _helper_sum(v, lks, cx.t("H_DD0"), cx.alpha, mu[3:3 + n_help]) + F(mu[3 + n_help]) * ctab
    return v[cx.eq(0)] * inner


class SlotDefDD:
    """the minimal SlotDef shape `zk60_native_rg_tokennl` expects"""

    def __init__(self, fn, tabs):
        self.poly = fn
        self.tabs = tabs


def _draw_split(slot, cx, dc):
    if slot == T.SC_SZC:
        n_help = cx.g.n_helpers("S")
        lt = cx.g.log("S")
        n_mu = 2 + n_help + 2
        return dc[lt:lt + n_mu], dc[lt + n_mu:lt + n_mu + 2]
    n_help = cx.g.n_helpers("Dd")
    lt = cx.g.log("Dd")
    return dc[lt:lt + 3 + n_help + 1], []


def slot_def(slot, cx, dc, flip=False):
    mu, nu = _draw_split(slot, cx, dc)
    if slot == T.SC_SZC:
        return SlotDefDD(lambda v: szc_dd_sym(v, cx, mu, nu, flip), cx.arg["tables"])
    return SlotDefDD(lambda v: dd_sym(v, cx, mu, flip), cx.arg["tables"])


def _table_kind(i, tab, cx):
    if tab["kind"] == "eq":
        return f"eq(start={tab['start']},|point|={len(tab['point'])})", f"eq{i}"
    if tab["kind"] == "public":
        for key, j in cx.pub_of.items():
            if j == i:
                if key[0] == "supp":
                    return f"supp({key[1]})", f"supp({key[1]})"
                return "pub", key[1] if key[0] == "captured" else key[0]
        return "pub", f"public{i}"
    role = tab["role"]
    if role == "A":
        return "A", cx.names[cx.priv_idx.index(i)]
    if role == "H":
        return "H", cx.names[cx.priv_idx.index(i)]
    return "EP", role


def to_ir(stage, slot, arg, sd, cx):
    names = [f"T{i:02d}" for i in range(len(sd.tabs))]
    P = TT.Poly._co(sd.poly([TT.Poly.var(n) for n in names]))
    idx = {n: i for i, n in enumerate(names)}
    tables = []
    for i, t in enumerate(sd.tabs):
        k_, lab = _table_kind(i, t, cx)
        tables.append({"kind": k_, "label": lab, "prov": "DD transcription (argument.rs R9)"})
    terms = []
    for mono, c in sorted(P.t.items()):
        inner = []
        for n, e in mono:
            inner.extend([{"table": idx[n]}] * e)
        terms.append({"coef": {"value": TN._fstr(c)}, "wrapper": [], "inner": inner, "degree": len(inner)})
    maxdeg = max((t["degree"] for t in terms), default=0)
    return {"slot": slot, "name": f"stage{stage:02d}-{slot:02d} {arg['name']}", "kind": arg["kind"],
            "main_rounds": arg["main"], "extension_rounds": arg["extension"],
            "declared_degree": arg["degree"], "max_product_degree": maxdeg,
            "pad_on": False, "group_bits": 0, "tables": tables, "nodes": [], "terms": terms}


def contexts(bundle, index, replay, chal="run", seed=0):
    """(stage, slot, arg, SlotCtx, dc) for every DD slot of every stage"""
    gate = T.TerminalGate(bundle, index)
    out = []
    for st in bundle.stages:
        doc = st.doc
        gate.set_stage(st.index)       # [v17] the stage's own calibration
        logup = doc["logup_challenges"]
        rng = random.Random(f"ddnl/{st.index}/{seed}")
        if chal == "random":
            logup = [[rng.randrange(T.P), rng.randrange(T.P)] for _ in logup]
        gate.set_logup(logup)
        lam_z = T.lam_z_of(doc)
        if chal == "random":
            lam_z = (rng.randrange(T.P), rng.randrange(T.P))
        for s in DD_SLOTS:
            arg = doc["arguments"][s]
            dc = [T.f2_from_list(x) for x in arg["definition_challenges"]]
            if chal == "random":
                dc = [(rng.randrange(T.P), rng.randrange(T.P)) for _ in dc]
            cx = T.SlotCtx(gate, arg, [p.name for p in index.slot_planes[s]], dc, lam_z)
            gate.build_public(cx)
            # freeze this stage's challenges into the context (the gate's are per stage)
            cx.alpha, cx.beta = gate.alpha, gate.beta
            cx.g_u8, cx.g_exp, cx.g_act, cx.g_dd = gate.g_u8, gate.g_exp, gate.g_act, gate.g_dd
            out.append((st.index, s, arg, cx, dc))
    return out


def cross_check(cx, s, dc, seeds=(1, 2, 3), flip=False):
    """X-0: the symbolic transcription at random table values equals the
    terminals port's numeric polynomial"""
    sd = slot_def(s, cx, dc, flip)
    port = T.sc_szc_dd if s == T.SC_SZC else T.sc_dd
    ok = []
    for sd_ in seeds:
        rng = random.Random(f"x0/{s}/{sd_}")
        vals = [(rng.randrange(T.P), rng.randrange(T.P)) for _ in cx.arg["tables"]]
        a = TT.F2._co(sd.poly([TT.F2(x) for x in vals]))
        b = port(vals, cx)
        ok.append(a == b)
    return all(ok)


def run(bundle_dir):
    NL, NF = TN.load_nl()
    t0 = time.time()
    b = load_bundle(bundle_dir)
    index, reason = plane_index_of(b)
    if index is None:
        raise SystemExit(f"no plane index: {reason}")
    if int(b.run["shape"].get("dd_cap", 0)) <= 0:
        raise SystemExit("not a DD bundle (run.json shape declares no dd_cap)")
    rp = RunReplay(b).run()
    rec = {"what": "NL-1 S1-S5 on the DD slots (17: SC_SZC's DD arm; 23: SC_DD), through the frozen "
                   "nl_check with a slot IR built from the gate's symbolic transcription of argument.rs R9; "
                   "NOT a privacy result",
           "privacy_acceptance": False, "privacy_property_established": False,
           "bundle": b.name, "bundle_dir": bundle_dir, "nl_check_pins": TN.NL_PINS}
    tt = T.check_terminals(b, index, replay=rp)
    per = [(r["stage"], s, s in r["equal"]) for r in tt["per_stage"] for s in DD_SLOTS]
    rec["T0_terminal_identity_dd_slots"] = {
        "checked": [f"stage {st} slot {s}" for st, s, _ in per],
        "equal": sum(1 for *_x, e in per if e), "of": len(per),
        "whole_terminal_check_ok": tt["ok"], "findings": tt["findings"][:10]}
    modes = [("run", 0), ("random", 1), ("random", 2), ("random", 3)]
    per_mode = {}
    keep = {}
    for chal, seed in modes:
        key = chal if chal == "run" else f"random-{seed}"
        cxs = contexts(b, index, rp, chal, seed)
        sds = [slot_def(s, cx, dc) for (_st, s, _a, cx, dc) in cxs]
        irs = [to_ir(st, s, arg, sd, cx) for (st, s, arg, cx, _dc), sd in zip(cxs, sds)]
        slots = [NL.Slot(ir, "token", {}) for ir in irs]
        x0 = [cross_check(cx, s, dc) for (_st, s, _a, cx, dc) in cxs]
        fid = [TN.fidelity(NL, NF, ir, sd) for ir, sd in zip(irs, sds)]
        s1 = [TN.s1_row(NL, NF, sl) for sl in slots]
        s4 = TN.s4_rows(NL, NF, slots)
        per_mode[key] = {
            "X0_symbolic_equals_port": f"{sum(x0)}/{len(x0)}",
            "F0_fidelity": f"{sum(fid)}/{len(fid)}",
            "S1": s1,
            "S1_summary": {"premise_holds": sum(1 for r in s1 if r["premise_holds"]),
                           "public_factor_every_monomial": sum(1 for r in s1 if r["public_factor_in_every_monomial_exact"]),
                           "degree_fits": sum(1 for r in s1 if r["degree_fits"]),
                           "budget_ok": sum(1 for r in s1 if r["budget_ok"]), "of": len(s1)},
            "S2": {"slots": len(s1), "sum_L": sum(r["L"] for r in s1), "sum_dimC": sum(r["dimC"] for r in s1),
                   "worst_L": max(r["L"] for r in s1), "budget_all_ok": all(r["budget_ok"] for r in s1)},
            "S4": s4,
            "S4_summary": {"miniatures_pass": sum(1 for r in s4 if r["passes"]),
                           "terminal_map_onto": sum(1 for r in s4 if r["terminal_map"]["onto_Fp2^m"]),
                           "of": len(s4)},
            "all_ok": all(x0) and all(fid)}
        keep[key] = (cxs, irs, slots, sds)
    cxs, irs, slots, sds = keep["run"]
    pairs = sorted({(sl.main + sl.ext, sl.d) for sl in slots})
    rec["S3_fact21"] = TN.s3_pairs(NL, NF, pairs)
    ctl = TN.controls(NL, NF, irs, slots, sds)
    # X-1: the symbolic transcription with the tuple's beta^2 sign flipped no
    # longer equals the port (X-0 is not vacuous)
    x1 = [{"stage": st, "slot": s, "fires": not cross_check(cx, s, dc, flip=True)} for (st, s, _a, cx, dc) in cxs]
    ctl["X_1"] = x1
    ctl["summary"]["X_1_fires"] = f"{sum(1 for x in x1 if x['fires'])}/{len(x1)}"
    ctl["ok"] = bool(ctl["ok"] and all(x["fires"] for x in x1))
    rec["S5_controls"] = ctl
    rec["per_challenge_mode"] = per_mode
    rec["ir_run_challenges"] = {"schema": "zk60-slot-ir/1-dd", "profile": b.run.get("profile"),
                                "slot_count": len(irs), "slots": irs}
    n = len(irs)
    good = all(pm["all_ok"] and pm["S1_summary"]["premise_holds"] == n
               and pm["S1_summary"]["public_factor_every_monomial"] == n
               and pm["S1_summary"]["degree_fits"] == n and pm["S1_summary"]["budget_ok"] == n
               and pm["S4_summary"]["miniatures_pass"] == n and pm["S4_summary"]["terminal_map_onto"] == n
               for pm in per_mode.values())
    t0ok = rec["T0_terminal_identity_dd_slots"]["equal"] == rec["T0_terminal_identity_dd_slots"]["of"] > 0
    rec["summary"] = {
        "dd_slot_instances": n,
        "T0": f"{rec['T0_terminal_identity_dd_slots']['equal']}/{rec['T0_terminal_identity_dd_slots']['of']}",
        "per_mode": {k: {"X0": v["X0_symbolic_equals_port"], "F0": v["F0_fidelity"], "S1": v["S1_summary"],
                         "S4": v["S4_summary"]} for k, v in per_mode.items()},
        "S3_tight": f"{rec['S3_fact21']['tight']}/{rec['S3_fact21']['checks']}",
        "S5": ctl["summary"]}
    rec["ok"] = bool(good and t0ok and rec["S3_fact21"]["tight"] == rec["S3_fact21"]["checks"] and ctl["ok"])
    rec["status"] = "PASS" if rec["ok"] else "NOT-OK"
    rec["seconds"] = round(time.time() - t0, 1)
    rec["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
    rec["tool_sha256"] = {os.path.basename(p): _sha(p) for p in (
        os.path.abspath(__file__), T.__file__, TT.__file__, TN.__file__)}
    return rec


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    a = ap.parse_args(argv)
    rec = run(a.bundle)
    os.makedirs(a.evidence, exist_ok=True)
    out = os.path.join(a.evidence, a.name + ".json")
    with open(out, "w") as fh:
        json.dump(rec, fh, indent=1, default=str)
    print(json.dumps(rec["summary"], indent=1))
    print(f"record: {out}  status {rec['status']}")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
