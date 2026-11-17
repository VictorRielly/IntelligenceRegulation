#!/usr/bin/env python3
"""D63 lane L58 (2026-11-10): generate the app's top theorem chain with ONE tag-checked extractor at the input
endpoint (the brief's deliverables 1, 2 and 4), from the existing generated chain, so every earlier discharge is kept:

  RunEpXTop.lean   `ex_productionReadyL_epP_code`   from L52's `eb_productionReadyL_epP_code` (RunEpBTop.lean): the
                   input endpoint's extraction event `ebEvIn` REPLACED by the widened `exEvIn` (RunEpXExt.lean; it
                   contains `ebEvIn` and has the same bound `εxRun`, so the gate's budget is the same
                   `55,852,891 ≤ 2^26`); `hopX` at part 0 from `eb_hopX0` through `exEvIn_of_eb`.
  RunEpXTopT.lean  `ex_productionReadyL_epP_codeT`  L52's `l52_mk_topT.py` step on it, with the test's matrix and
                   column set the CHECKED extractor's (`exUx`, `exXx`; `hUc`, `hXc` by `exUx_cut`, `exXx_cut`) and
                   `hBal` by `ex_hopX0C` and `ex_xB_alive` (RunEpXTest.lean); `hread` speaks of `exXx`, `exUx`.
  RunEpXTopW.lean  `ex_productionReadyL_epP_codeW`  L55's `vd_productionReadyL_epP_codeW` (RunVerdictTop.lean),
  RunEpXTopX.lean  `ex_productionReadyL_epP_codeX`  L55's `cb_productionReadyL_epP_codeX` (RunCloseBTop.lean) and
  RunEpXTopF.lean  `ex_productionReadyL_epP_codeF`  L55's `cb_productionReadyL_epP_codeF` (RunCloseBTopF.lean), each
                   with the event and `hread`'s readers substituted and its predecessor renamed.

Every substitution is asserted (exact counts); no old event or reader may remain.
usage: python3 l58_mk_chain.py <WT>
"""
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
L = WT + "/formal/ZK60Formal/"

EV_OLD = "ZK60.ProtocolClassify.ebEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G"
EV_NEW = "ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G"

OPENS = '''open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code ZK60.RunShape
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)
open ZK60.D76 (LeaksAtMost productionReadyL_of_productionReady productionReadyL_of_productionReady_range)
open ZK60.ProtocolClassify (ClsHdrW clsHdrOf clsStart)
'''


def once(text, old, new):
    n = text.count(old)
    assert n == 1, (old[:90], n)
    return text.replace(old, new)


def every(text, old, new, n):
    m = text.count(old)
    assert m == n, (old[:90], m, n)
    return text.replace(old, new)


def section(src, name):
    i = src.index("section %s\n" % name)
    j = src.index("end %s\n" % name, i) + len("end %s\n" % name)
    return src[i:j]


def cut(text, start, stop):
    a = text.index(start)
    assert text.count(start) == 1, start[:60]
    b = text.index(stop, a)
    return text[a:b]


def redoc(sec, theorem_head, doc):
    """Replace the docstring right before `theorem_head` with `doc`."""
    t = sec.index(theorem_head)
    d = sec.rindex("/-- ", 0, t)
    return sec[:d] + doc + "\n" + sec[t:]


def write(fname, header, imports, sec):
    out = header + "".join("import %s\n" % m for m in imports) + (
        "\nset_option autoImplicit false\nset_option linter.constructorNameAsVariable false\n\n"
        "namespace ZK60.ProtocolClassify.RunShapeP\n\n") + OPENS + "\n" + sec + "\nend ZK60.ProtocolClassify.RunShapeP\n"
    open(L + fname, "w").write(out)
    return out


def top_binders(text):
    """The top-level binder groups of a theorem statement: (kind, names, start, end) (lane L50's parser)."""
    i = text.index(" ") + 1
    i = text.index(" ", i)
    out = []
    depth = 0
    start = None
    opener = None
    pairs = {"(": ")", "{": "}", "[": "]", "⦃": "⦄"}
    closers = set(pairs.values())
    while i < len(text):
        c = text[i]
        if depth == 0 and c == ":" and text[i:i + 2] == ":=":
            break
        if depth == 0 and c == ":" and opener is None:
            break
        if c in pairs:
            if depth == 0:
                start = i
                opener = c
            depth += 1
        elif c in closers:
            depth -= 1
            if depth == 0 and opener is not None:
                grp = text[start:i + 1]
                inner = grp[1:-1]
                names = []
                if opener in "({" and ":" in inner:
                    names = inner[:inner.index(":")].split()
                out.append((opener, names, start, i + 1))
                opener = None
        i += 1
    return out


END_TOK = "(classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :="
report = []

# ---------------------------------------------------------------- RunEpXTop.lean (the event swapped)
src = open(L + "RunEpBTop.lean").read()
sec = section(src, "EbCodeTop")
sec = once(sec, "section EbCodeTop\n", "section ExCodeTop\n")
sec = once(sec, "end EbCodeTop\n", "end ExCodeTop\n")
sec = once(sec, "theorem eb_productionReadyL_epP_code ", "theorem ex_productionReadyL_epP_code ")
sec = once(sec, "ZK60.ProtocolClassify.ebEvIn_le tag Lq h64 key domain hs hL incG outcG sgeom Lb q A hA",
           "ZK60.ProtocolClassify.exEvIn_le tag Lq h64 key domain hs hL incG outcG sgeom Lb q A hA")
sec = once(sec, "sgeom A rfl (fun h => hx (Or.inr h)) hfitX",
           "sgeom A rfl\n        (fun h => hx (Or.inr (ZK60.ProtocolClassify.exEvIn_of_eb tag Lq h64 key domain hs hL incG outcG\n"
           "          sgeom Lb A G h))) hfitX")
n_ev = sec.count(EV_OLD)
sec = sec.replace(EV_OLD, EV_NEW)
sec = redoc(sec, "theorem ex_productionReadyL_epP_code ",
            "/-- **THE APP'S TOP THEOREM WITH THE INPUT ENDPOINT'S WIDENED EXTRACTION EVENT** (D63 lane L58). Lane L52's\n"
            "`eb_productionReadyL_epP_code` (repair B at the code's header; L50's alive discharges kept) with its extra\n"
            "extraction event `ebEvIn` REPLACED by `exEvIn` (RunEpXExt.lean: the unchecked OR the tag-checked extraction\n"
            "misses an opened column at the input root), which contains it and has the same bound `εxRun`, so the joint\n"
            "budget is the same (`55,525,211 + 327,680 = 55,852,891 ≤ 2^26`, PROVED in the gate); `hopX` at part `0` from\n"
            "`eb_hopX0` (outside `exEvIn` is outside `ebEvIn`: `exEvIn_of_eb`). Generated by\n"
            "`results/zk60_lean_l58_20261110/l58_mk_chain.py`. -/")
assert "ebEvIn" not in sec[sec.index("theorem ex_productionReadyL_epP_code "):], "ebEvIn left"
hdr = '''/-
D63 lane L58 (2026-11-10), part 5: **the app's top theorem with the input endpoint's widened extraction event** (the
brief's deliverable 1, in the top theorem). GENERATED by `results/zk60_lean_l58_20261110/l58_mk_chain.py` from lane
L52's `eb_productionReadyL_epP_code` (RunEpBTop.lean), so L50's and L52's discharges are kept.

* **`ex_productionReadyL_epP_code`**: the event `EvXR ∨ exEvIn` (RunEpXExt.lean), counted in the joint budget with the
  same constant as L52's `ebEvIn` (`55,852,891 ≤ 2^26`, PROVED).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
'''
write("RunEpXTop.lean", hdr, ["ZK60Formal.RunEpBTop", "ZK60Formal.RunEpXExt"], sec)
report.append(("RunEpXTop.lean", n_ev))

# ---------------------------------------------------------------- RunEpXTopT.lean (L52's l52_mk_topT step)
src = open(L + "RunEpXTop.lean").read()
sec = section(src, "ExCodeTop")
th0 = sec.index("theorem ex_productionReadyL_epP_code ")
th1 = sec.index(END_TOK, th0) + len(END_TOK)
stmt0 = sec[th0:th1]
explicit0 = [n for (k, ns, _, _) in top_binders(stmt0) if k == "(" for n in ns]
assert "hBal" in explicit0 and "T" in explicit0 and "Ux" in explicit0, explicit0
sec = once(sec, "section ExCodeTop\n", "section ExCodeTTop\n")
sec = once(sec, "end ExCodeTop\n", "end ExCodeTTop\n")
sec = once(sec, "theorem ex_productionReadyL_epP_code ", "theorem ex_productionReadyL_epP_codeT ")
sec = redoc(sec, "theorem ex_productionReadyL_epP_codeT ",
            "/-- **THE APP'S TOP THEOREM WITH ONE TAG-CHECKED EXTRACTOR AT THE INPUT ENDPOINT, THE TEST'S HALF** (D63 lane\n"
            "L58; L52 §5.3). `ex_productionReadyL_epP_code` with the test `T := ebT …` (part `0`'s closing opening at the\n"
            "endpoint geometry `ogEp`, as L52's), `Ux`, `Xx` the matrix and columns the CHECKED extractor returns at the root\n"
            "the header shows at position `1` (`exUx`, `exXx`: the ones `ops := epxOps` reads, so `hread` can hold), and\n"
            "`hTenc`, `hTwA`, `hTwB`, `hp1`, `hp2`, `hF`, `hw0`, `hβLR`, `hTe`, `hTQ`, `hβJ`, `hUc`, `hXc`, `hBal` PROVED\n"
            "(`hBal` by `ex_hopX0C` and `ex_xB_alive`). One new premise, `hRr` (L52's). Generated by\n"
            "`results/zk60_lean_l58_20261110/l58_mk_chain.py`.\n-/")
TBLOCK = cut(sec, "    {F Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Algebra GF F] [Fintype Cl] [DecidableEq Cl]\n",
             "    (tag : MTag)\n")
assert "(hβJ : T.βJ = 1)" in TBLOCK and "(Ux :" in TBLOCK and "(hUc :" in TBLOCK, TBLOCK
sec = once(sec, TBLOCK, "")
sec = once(sec, "(hXep : RkPcsAt U tag ogEp Iin.pX) (hfitX : 8 * Iin.pX.rows ≤ Lq)\n",
           "(hXep : RkPcsAt U tag ogEp Iin.pX) (hfitX : 8 * Iin.pX.rows ≤ Lq)\n    (hRr : Iin.pX.rows = Rr)\n")
bal = cut(sec, "    (hBal : ∀ (A : OC", "    (hdzero : ∀ (A : OC")
sec = once(sec, bal, "")
AA = "((RtRun.pf Rn).off 0 + ((RtRun.pf Rn).part 0).oX)"
BB = "((RtRun.pf Rn).off 0 + ((RtRun.pf Rn).part 0).oBX)"
HAB = "(ZK60.ProtocolClassify.eb_ab_le (RtRun.pf Rn) 0)"
TT = f"(ZK60.ProtocolClassify.ebT U hbij Rr Iin.nIn {AA} {BB} {HAB})"
UX = "(fun P hdr => ZK60.ProtocolClassify.exUx tag Lq h64 key domain hs hL abRdIn 11 1 Rr (N := 2 ^ 11) P hdr)"
XX = "(fun P hdr => ZK60.ProtocolClassify.exXx tag Lq h64 key domain hs hL abRdIn 11 1 Rr (N := 2 ^ 11) P hdr)"
rd = cut(sec, "    (hread : ∀ (A : OC", "    (hdzero : ∀ (A : OC")
rd2 = once(rd, "      Xx (A.runLog G).2 ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take T.aA)",
           "      ZK60.ProtocolClassify.exXx tag Lq h64 key domain hs hL abRdIn 11 1 Rr (A.runLog G).2\n"
           f"          ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take {AA})")
rd2 = once(rd2, "        ∧ Ux (A.runLog G).2 ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take T.aA)",
           "        ∧ ZK60.ProtocolClassify.exUx tag Lq h64 key domain hs hL abRdIn 11 1 Rr (A.runLog G).2\n"
           f"          ((rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)).take {AA})")
rd2 = once(rd2, "algebraMap GF F", "algebraMap GF K")
sec = once(sec, rd, rd2)
st1 = sec[sec.index("theorem ex_productionReadyL_epP_codeT "):sec.index(END_TOK)]
for bad in ["T.", " Ux ", " Xx ", "GF F", "(T :", "hTenc", "hBal"]:
    assert bad not in st1, bad
bal_type = bal[len("    (hBal : "):].rstrip()
assert bal_type.endswith(")")
bal_type = bal_type[:-1]
bal_type = once(bal_type, "(T.cB (rtRC2 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv).W Ux Xx (A.runLog G).2)",
                f"({TT}.cB\n          (rtRC2 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv).W {UX}\n          {XX}\n"
                "          (A.runLog G).2)")
BLK = "(d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen)"
SECVARS = ["Rr", "dR", "hpos", "place", "msg", "msg_place", "pad", "salt", "path", "tagc"]
fixed = {"T": TT, "hTenc": "ZK60.ProtocolClassify.eb_enc_ep", "hTwA": "rfl", "hTwB": "rfl", "Ux": UX, "Xx": XX,
         "hUc": "(ZK60.ProtocolClassify.exUx_cut tag Lq h64 key domain hs hL abRdIn 11 1 Rr (2 ^ 11))",
         "hXc": "(ZK60.ProtocolClassify.exXx_cut tag Lq h64 key domain hs hL abRdIn 11 1 Rr (2 ^ 11))",
         "pr": "gP", "hp1": "(by norm_num)", "hp2": "(by norm_num)", "hF": "hD.hK", "hw0": "hw0'",
         "hβLR": "rfl", "hTe": "rfl", "hTQ": "rfl", "hβJ": "rfl", "hBal": "hBal"}
args = [f"({n} := {n})" for n in SECVARS] + ["(F := K)", "(Cl := Fin Iin.nIn)"]
for n in explicit0:
    args.append(f"({n} := {fixed.get(n, n)})")
lines = []
cur = "  exact ex_productionReadyL_epP_code"
for a in args:
    if len(cur) + 1 + len(a) > 118:
        lines.append(cur)
        cur = "    " + a
    else:
        cur += " " + a
lines.append(cur)
proof = (
    "  by\n"
    "  have hσ0 : (RtRun.σs Rn)[0]? = some (rtIncSeg inc incG cx0 pin) := by\n"
    "    rw [hσ]\n"
    "    rfl\n"
    "  have hw0' : Iin.nIn + Rr ≤ 2 ^ 61 := by\n"
    "    have h0 : 0 < (RtRun.pf Rn).parts.length := by\n"
    "      rw [RtRun.parts_length Rn]\n"
    "      omega\n"
    "    have hv0 := (hD.opV 0 h0).2.2.hw\n"
    "    rw [hDe] at hv0\n"
    "    change (base 0).nX + (base 0).gX.rows ≤ 2 ^ 61 at hv0\n"
    "    rw [hgX0] at hv0\n"
    "    rw [← hRr, ← hnX0]\n"
    "    exact hv0\n"
    "  have hBal : " + bal_type + " := by\n"
    "    intro A G hacc hx\n"
    "    have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG " + BLK + "\n"
    "      outc outcG P (CinR) h64 hr hon.base 768 G _ _ hacc\n"
    "    rw [OC.runLog_fst] at hE0\n"
    "    have w := ZK60.ProtocolClassify.ex_hopX0C U tag h64 hs hL hw Rn hRn hv G (A.run G).1 (A.run G).2 hE0 pin inc\n"
    "      incG cx0 Iin hσ0 Win (hW A G hacc).1 ogEp ogEp_ok (by decide) hXep outcG sgeom Lb A rfl\n"
    "      (fun h => hx (Or.inr h)) hfitX\n"
    "    rw [hRr] at w\n"
    "    exact ZK60.ProtocolClassify.ex_xB_alive U hU hbij tag Lq h64 key domain hs hL abRdIn _ Rr Iin.nIn 1 _ _ _ _ _ G\n"
    "      _ w " + HAB + "\n"
    + "\n".join(lines) + "\n")
p0 = sec.index("  by\n  have hσ0 :")
p1 = sec.index("\nend ExCodeTTop\n")
sec = sec[:p0] + proof + sec[p1:]
hdr = '''/-
D63 lane L58 (2026-11-10), part 6: **the app's top theorem with the column test read from the checked extractor**
(the brief's deliverables 2 and 4). GENERATED by `results/zk60_lean_l58_20261110/l58_mk_chain.py` from
`ex_productionReadyL_epP_code` (RunEpXTop.lean), by lane L52's `l52_mk_topT.py` step with the extraction changed.

* **`ex_productionReadyL_epP_codeT`**: `T := ebT …`, `Ux`, `Xx` the CHECKED extractor's at the root the header shows at
  position `1` (`exUx`, `exXx`), and `hTenc`, `hTwA`, `hTwB`, `hp1`, `hp2`, `hF`, `hw0`, `hβLR`, `hTe`, `hTQ`, `hβJ`,
  `hUc`, `hXc`, `hBal` PROVED; one new premise, `hRr`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
'''
write("RunEpXTopT.lean", hdr, ["ZK60Formal.RunEpXTop", "ZK60Formal.RunEpXTest"], sec)
report.append(("RunEpXTopT.lean", len(explicit0)))

# ---------------------------------------------------------------- W, X, F: L55's restatements, substituted
CHAIN = [
    ("RunVerdictTop.lean", "VdCodeWTop", "vd_productionReadyL_epP_codeW", "eb_productionReadyL_epP_codeT",
     "RunEpXTopW.lean", "ExCodeWTop", "ex_productionReadyL_epP_codeW", "ex_productionReadyL_epP_codeT",
     ["ZK60Formal.RunEpXTopT", "ZK60Formal.RunVerdictW"],
     "`hW` PROVED at the code's header (L55's `vd_hW`)", "7"),
    ("RunCloseBTop.lean", "CbCodeXTop", "cb_productionReadyL_epP_codeX", "vd_productionReadyL_epP_codeW",
     "RunEpXTopX.lean", "ExCodeXTop", "ex_productionReadyL_epP_codeX", "ex_productionReadyL_epP_codeW",
     ["ZK60Formal.RunEpXTopW", "ZK60Formal.RunCloseBMid"],
     "`hopX1` PROVED at the parts `2 … Lb` (L55's `cb_hopX1_mid`)", "8"),
    ("RunCloseBTopF.lean", "CbCodeFTop", "cb_productionReadyL_epP_codeF", "cb_productionReadyL_epP_codeX",
     "RunEpXTopF.lean", "ExCodeFTop", "ex_productionReadyL_epP_codeF", "ex_productionReadyL_epP_codeX",
     ["ZK60Formal.RunEpXTopX", "ZK60Formal.RunCloseBEnds"],
     "`hopX1` PROVED at parts `1` and `Lb + 1` too (L55's `cb_hopX1_one`, `cb_hopX1_last`)", "9"),
]
for (fsrc, secname, thname, pred, fout, newsec, newth, newpred, imports, what, part) in CHAIN:
    src = open(L + fsrc).read()
    sec = section(src, secname)
    sec = once(sec, "section %s\n" % secname, "section %s\n" % newsec)
    sec = once(sec, "end %s\n" % secname, "end %s\n" % newsec)
    sec = once(sec, "theorem %s " % thname, "theorem %s " % newth)
    sec = once(sec, "  exact %s " % pred, "  exact %s " % newpred)
    n_ev = sec.count(EV_OLD)
    sec = sec.replace(EV_OLD, EV_NEW)
    sec = once(sec, "ZK60.ProtocolClassify.ebXxW tag Lq h64 key domain hs hL abRdIn 11 1 Rr (A.runLog G).2",
               "ZK60.ProtocolClassify.exXx tag Lq h64 key domain hs hL abRdIn 11 1 Rr (A.runLog G).2")
    sec = once(sec, "ZK60.ProtocolClassify.ebUxW tag Lq h64 key domain hs hL abRdIn 11 1 Rr (A.runLog G).2",
               "ZK60.ProtocolClassify.exUx tag Lq h64 key domain hs hL abRdIn 11 1 Rr (A.runLog G).2")
    sec = redoc(sec, "theorem %s " % newth,
                "/-- **THE APP'S TOP THEOREM WITH ONE TAG-CHECKED EXTRACTOR AT THE INPUT ENDPOINT** (D63 lane L58): lane L55's\n"
                "`%s` restated on `%s` (the widened event `exEvIn`, the column test read from the checked\n"
                "extractor), with %s. Generated by `results/zk60_lean_l58_20261110/l58_mk_chain.py`. -/"
                % (thname, newpred, what))
    body = sec[sec.index("theorem %s " % newth):]
    for bad in ["ebEvIn", "ebXxW", "ebUxW", thname, pred]:
        assert bad not in body, (fout, bad)
    hdr = '''/-
D63 lane L58 (2026-11-10), part %s: **lane L55's `%s` on the checked extractor**. GENERATED by
`results/zk60_lean_l58_20261110/l58_mk_chain.py` from %s (the event `ebEvIn` replaced by `exEvIn`, `hread`'s readers
`ebXxW`, `ebUxW` by `exXx`, `exUx`, the predecessor `%s` by `%s`).

* **`%s`**: %s.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
''' % (part, thname, fsrc, pred, newpred, newth, what)
    write(fout, hdr, imports, sec)
    report.append((fout, n_ev))

for r in report:
    print(*r)
