#!/usr/bin/env python3
"""D63 lane L57 (2026-11-10): generate formal/ZK60Formal/RunStgAlgTopR.lean, the app's top theorem with the stage slot
polynomials SET TO THE REAL ONES and their terminal identities reduced to the run-level facts.

It reads this lane's `stgAlg_productionReadyL_epP_exec_view` (RunStgAlgTop.lean) and writes
`stgAlg_productionReadyL_epP_exec_real`:
  * the same statement, except that
    - the binders `FstI`, `FstO` are GONE: every occurrence is the real polynomial (`stgFstI`, `stgFstO`,
      RunStgAlgPoly.lean) at the stage's opening geometry (`ogStage`), the stage parts' rows (`Iin.pA.rows`, …),
      `M`'s spec count (`pin.S`, `pout.S`), the header readers `Win`, `Wout` at the positions of the top theorem's `hW`,
      and new binders `csIOI`, `csIOO` (the IO commitments' claims' semantics: lanes L55, L56);
    - `hTI_stg`, `hTO_stg` (`StgTermAtV`) are replaced by `hTrI`, `hTrO` under the SAME hypotheses, with the conclusion
      the run-level facts at the stage (`StgTrueAt`: the reader reads the schedule, the claims and `M`'s functionals
      true of the extracted data);
    - new side premises: `hIOI`, `hIOO` (the IO semantics reads a claim's functional only), `hNin`, `hNout` (every slot
      has a variable and its mask coefficients fit `M`'s 512 columns), `hpolyIn`, `hpolyOut` (the definitions'
      polynomials return canonical words);
  * the proof applies `stgAlg_productionReadyL_epP_exec_view` with every binder passed by name, `FstI`, `FstO` := the
    real polynomials and `hTI_stg`, `hTO_stg` := `stgFR_termAt` (with `stgCsv_value`, `stgMsv_mlin`).
usage: python3 l57_mk_topr.py <WT>
"""
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
L = WT + "/formal/ZK60Formal/"
src = open(L + "RunStgAlgTop.lean").read()

fl_start = src.index("set_option linter.constructorNameAsVariable false\n")
doc_start = src.index("/-- **THE APP'S TOP THEOREM AT THE VIEW STAGE LISTS, THE HOSTING PROVED**")
prefix = src[fl_start:doc_start].replace("section StgAlgTop\n", "section StgAlgTopR\n")
assert "section StgAlgTopR\n" in prefix

th_start = src.index("theorem stgAlg_productionReadyL_epP_exec_view ")
end_tok = "(classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :="
th_end = src.index(end_tok, th_start) + len(end_tok)
stmt = src[th_start:th_end]


def top_binders(text):
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


def rep(text, old, new, count):
    n = text.count(old)
    assert n == count, (old[:90], n, count)
    return text.replace(old, new)


TR = "(rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))"
LG = "(A.runLog G).2"
ABS = "(Exec.Block.absOfC (chainEncB key domain hs Lq hL))"
HIN = "((RtRun.pf Rn).off 0 + 5)"
HOUT = "((RtRun.pf Rn).off (Lb + 1) + 2)"
POFI = "(fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch))"
POFO = "(fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp)"
BGAI = "(fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))"
BGAO = "OutcV.bga"
N0I = "((RtRun.pf Rn).off 0 + pin.pre)"
N0O = "((RtRun.pf Rn).off (Lb + 1) + pout.pre)"
GEO = "ogStage.lc ogStage.h ogStage.Q ogStage.e"
P = "ZK60.ProtocolClassify."
FRI = (f"({P}stgFstI U hbij tag h64 P0in Win {N0I} ((RtRun.pf Rn).off 0 + 5) mIn {GEO} Iin.pA.rows Iin.pH.rows pin.S "
       f"csIOI)")
FRO = (f"({P}stgFstO U hbij tag h64 P0out Wout {N0O} ((RtRun.pf Rn).off (Lb + 1) + 2) {GEO} Oout.pA.rows Oout.pH.rows "
       f"pout.S csIOO)")
PVI = f"(fun v ch => (Win (v.2.take {N0I})).bp (ZK60.Exec.StageV.incCtx (Win (v.2.take {N0I})).pub ch))"
PVO = f"(fun v _ => (Wout (v.2.take {N0O})).bp)"
CSI = (f"({P}stgCsv U tag h64 {GEO} Iin.pA.rows Iin.pH.rows ((RtRun.pf Rn).off 0 + 5) "
       f"((RtRun.pf Rn).off 0 + 5 + 4 + mIn) csIOI)")
CSO = (f"({P}stgCsv U tag h64 {GEO} Oout.pA.rows Oout.pH.rows ((RtRun.pf Rn).off (Lb + 1) + 2) "
       f"((RtRun.pf Rn).off (Lb + 1) + 2 + 4 + 2) csIOO)")
MSI = f"({P}stgMsv U tag h64 pin.S ((RtRun.pf Rn).off 0 + 5 + 3))"
MSO = f"({P}stgMsv U tag h64 pout.S ((RtRun.pf Rn).off (Lb + 1) + 2 + 3))"
RVI = f"({P}stgRv U tag h64 pin.S ((RtRun.pf Rn).off 0 + 5 + 3))"
RVO = f"({P}stgRv U tag h64 pout.S ((RtRun.pf Rn).off (Lb + 1) + 2 + 3))"

binders = top_binders(stmt)
explicit = [n for (k, ns, _, _) in binders if k == "(" for n in ns]
GONE = ["FstI", "FstO"]
NEWC = ["hTI_stg", "hTO_stg"]
spans = {}
for (k, ns, s, e) in binders:
    if ns and ns[0] in GONE + NEWC:
        assert len(ns) == 1, ns
        spans[ns[0]] = (s, e, stmt[s:e])
assert sorted(spans) == sorted(GONE + NEWC), sorted(spans)


def split_concl(t):
    body = t[1:-1]
    j = body.rindex("→")
    return body[:j + 1], body[j + 1:]


CONC = {"hTI_stg": f"\n      {P}StgTrueAt U key domain {POFI} mIn {HIN} {BGAI} {ABS} {PVI} {CSI} {MSI} G {LG}\n        {TR}",
        "hTO_stg": f"\n      {P}StgTrueAt U key domain {POFO} 2 {HOUT} {BGAO} {ABS} {PVO} {CSO} {MSO} G {LG}\n        {TR}"}
NEWN = {"hTI_stg": "hTrI", "hTO_stg": "hTrO"}
NEWB = ("(csIOI csIOO : StgVw Lq → Exec.Block.Cm → Exec.Block.ZClaim → K)\n"
        "    (hIOI : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOI v cm { z with value := a } = csIOI v cm z)\n"
        "    (hIOO : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOO v cm { z with value := a } = csIOO v cm z)\n"
        "    (hNin : ∀ k, k < P0in.geom.slots.length → 0 < stgN P0in k ∧ stgN P0in k * (Exec.Block.slotShape P0in k).2.2 + 2 ≤ 512)\n"
        "    (hNout : ∀ k, k < P0out.geom.slots.length → 0 < stgN P0out k ∧ stgN P0out k * (Exec.Block.slotShape P0out k).2.2 + 2 ≤ 512)\n"
        "    (hpolyIn : ∀ hd cx k hist dr df, ((inc hd).bp cx).define k hist dr = .ok df → ∀ vs, (Exec.Block.SlotDef.poly df vs).Canon)\n"
        "    (hpolyOut : ∀ hd v k hist dr df, (outc hd v).bp.define k hist dr = .ok df → ∀ vs, (Exec.Block.SlotDef.poly df vs).Canon)")

out = ""
pos = 0
for (k, ns, s, e) in binders:
    if not (ns and ns[0] in GONE + NEWC):
        continue
    h = ns[0]
    out += stmt[pos:s]
    if h == "FstI":
        out += NEWB
        pos = e
        while pos < len(stmt) and stmt[pos] in " \n":
            pos += 1
        out += "\n    "
        continue
    if h == "FstO":
        out = out.rstrip(" \n") + "\n    "
        pos = e
        while pos < len(stmt) and stmt[pos] in " \n":
            pos += 1
        continue
    pre, c = split_concl(spans[h][2])
    assert "StgTermAtV" in c, (h, c)
    out += f"({NEWN[h]} : " + pre[len(h) + 3:] + CONC[h] + ")"
    pos = e
out += stmt[pos:]
new = out
nI = new.count("FstI")
nO = new.count("FstO")
new = new.replace("FstI", FRI).replace("FstO", FRO)
new = rep(new, "theorem stgAlg_productionReadyL_epP_exec_view ", "theorem stgAlg_productionReadyL_epP_exec_real ", 1)

HE = ("(by have h := rc_uexecP_E Rp Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows "
      "bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768 G _ _ hv'; rw [OC.runLog_fst] at h; exact h)")


def term_term(h):
    if h == "hTI_stg":
        return (f"(hTI_stg := fun A G hv' hx' h1 h2 h3 => {P}stgFR_termAt U hbij hU key domain P0in {POFI} mIn {HIN} "
                f"{BGAI} {ABS} {PVI} {CSI} {MSI} {RVI} 512 G {LG} {TR} (fun _ => hPin (A.run G).1.hdr _) "
                f"(fun _ k hk => (Iin.hgeomL (A.run G).1.hdr _ k hk).1) hNin (fun _ => hpolyIn (A.run G).1.hdr _) "
                f"({P}stgCsv_value U tag h64 {GEO} Iin.pA.rows Iin.pH.rows ((RtRun.pf Rn).off 0 + 5) "
                f"((RtRun.pf Rn).off 0 + 5 + 4 + mIn) csIOI hIOI) "
                f"(fun v => {P}stgMsv_mlin U tag h64 pin.S ((RtRun.pf Rn).off 0 + 5 + 3) v) (hTrI A G hv' hx' h1 h2 h3))")
    return (f"(hTO_stg := fun A G hv' hx' h1 h2 h3 => {P}stgFR_termAt U hbij hU key domain P0out {POFO} 2 {HOUT} "
            f"{BGAO} {ABS} {PVO} {CSO} {MSO} {RVO} 512 G {LG} {TR} (fun _ => hPout (A.run G).1.hdr (A.run G).1.verdict) "
            f"(fun _ k hk => (Oout.hgeomL (A.run G).1.hdr (A.run G).1.verdict k hk).1) hNout "
            f"(fun _ => hpolyOut (A.run G).1.hdr (A.run G).1.verdict) "
            f"({P}stgCsv_value U tag h64 {GEO} Oout.pA.rows Oout.pH.rows ((RtRun.pf Rn).off (Lb + 1) + 2) "
            f"((RtRun.pf Rn).off (Lb + 1) + 2 + 4 + 2) csIOO hIOO) "
            f"(fun v => {P}stgMsv_mlin U tag h64 pout.S ((RtRun.pf Rn).off (Lb + 1) + 2 + 3) v) "
            f"(hTrO A G hv' hx' h1 h2 h3))")


SECVARS = ["Rr", "dR", "hpos", "place", "msg", "msg_place", "pad", "salt", "path", "tagc"]
args = [f"({n} := {n})" for n in SECVARS]
passed = set(SECVARS)
for n in explicit:
    if n in GONE + NEWC:
        continue
    args.append(f"({n} := {n})")
    passed.add(n)
args.append(f"(FstI := {FRI})")
args.append(f"(FstO := {FRO})")
args.append(term_term("hTI_stg"))
args.append(term_term("hTO_stg"))
passed.update(GONE + NEWC)
missing = [n for n in explicit if n not in passed]
assert not missing, missing

lines = []
cur = "  exact stgAlg_productionReadyL_epP_exec_view"
for a in args:
    if len(cur) + 1 + len(a) > 118:
        lines.append(cur)
        cur = "    " + a
    else:
        cur += " " + a
lines.append(cur)
proof = "\n  by\n" + "\n".join(lines) + "\n"

doc = '''/-- **THE APP'S TOP THEOREM WITH THE STAGE SLOT POLYNOMIALS SET TO THE REAL ONES** (D63 lane L57, deliverables 1 and
2). This lane's `stgAlg_productionReadyL_epP_exec_view` with `FstI`, `FstO` the stages' own slot polynomials over the
data extracted at the stages' roots (`stgFstI`, `stgFstO`: the code's `define` and tables, the private tables' values
the decoded extracted matrices', the mask term the extracted mask table's), and `hTI_stg`, `hTO_stg` replaced by the
run-level facts at the stages (`StgTrueAt`), under the SAME hypotheses (`stgFR_termAt`). Generated by
results/zk60_lean_l57_20261110/l57_mk_topr.py. -/
'''

head = '''/-
D63 lane L57 (2026-11-10), part 7: **the app's top theorem with the stage slot polynomials set to the real ones**
(deliverables 1 and 2). GENERATED by results/zk60_lean_l57_20261110/l57_mk_topr.py from this lane's
`stgAlg_productionReadyL_epP_exec_view` (RunStgAlgTop.lean): the same section header and binders, `FstI`, `FstO` the
real polynomials of RunStgAlgPoly.lean, `hTI_stg`, `hTO_stg` replaced by `StgTrueAt`; the proof applies that theorem.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgAlgTop
import ZK60Formal.RunStgAlgPoly
import ZK60Formal.RunOpenGeoTier

set_option autoImplicit false
'''

text = head + prefix + doc + new + proof + "\nend StgAlgTopR\n\nend ZK60.ProtocolClassify.RunShapeP\n"
open(L + "RunStgAlgTopR.lean", "w").write(text)
print("wrote RunStgAlgTopR.lean:", len(text.splitlines()), "lines;", len(explicit), "explicit binders in the view theorem;",
      f"FstI replaced {nI} times, FstO {nO} times; hTI_stg, hTO_stg replaced by hTrI, hTrO")
