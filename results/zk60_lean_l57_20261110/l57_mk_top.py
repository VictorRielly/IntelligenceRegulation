#!/usr/bin/env python3
"""D63 lane L57 (2026-11-10): generate formal/ZK60Formal/RunStgAlgTop.lean, the app's top theorem at the VIEW stage
lists (finding L57-1), with the stage hosting discharged.

It reads lane L53's `stg_productionReadyL_epP_exec_lists` (RunStgTop.lean, itself generated from lane L50's
`ra_productionReadyL_epP_exec_alive`) and writes `stgAlg_productionReadyL_epP_exec_view`:
  * the same statement and binders, except that
    - the stage polynomials and LogUp states `FstI`, `FstO`, `ΦI`, `ΦO`, `ΛI`, `ΛO` read the VIEW (`StgVw Lq`: the cuts
      the header shows AND the header) instead of the cuts alone;
    - the stage lists `hb0`, `hbL` are the view lists (`stgSchedV`, `stgDefsV`, `stgLkSqV`, RunStgAlgList.lean) with the
      hosting FIXED to the code's (`stgHostIn`, `stgHostOut P0out`, RunStgAlgHost.lean);
    - the binders `hostIn`, `hostOut`, `hhIn`, `hhOut` are GONE (`stg_hhIn`, `stg_hhOut`: PROVED);
    - the stage-level facts are the view ones (`StgTermAtV`, `StgDefAtV`, `StgLkAtV`), under the SAME hypotheses;
    - `hdin`, `hdout` are replaced by `hdinS`, `hdoutS` under the SAME hypotheses, with the conclusion the stage's view
      doom at the run's reading (`StgDoomAtV`), as lane L53's `stg_productionReadyL_epP_exec_doom` did;
  * the proof applies L50's theorem as L53's did, with the stage terms at the view lists (`stg_hal_slV`,
    `stg_hal_r0V`, `stg_hal_luV`, `stg_hal_doomV`, RunStgAlgRun.lean) and the hosting PROVED.
Every substitution is checked to occur exactly as often as expected; the script refuses to write otherwise.

usage: python3 l57_mk_top.py <WT>
"""
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
L = WT + "/formal/ZK60Formal/"
src = open(L + "RunStgTop.lean").read()

fl_start = src.index("set_option linter.constructorNameAsVariable false\n")
doc_start = src.index("/-- **THE APP'S TOP THEOREM WITH THE STAGE PARTS' LISTS CHOSEN AND THEIR SIX ALIVE PREMISES DISCHARGED**")
prefix = src[fl_start:doc_start].replace("section StgTop\n", "section StgAlgTop\n")
assert "section StgAlgTop\n" in prefix

th_start = src.index("theorem stg_productionReadyL_epP_exec_lists ")
end_tok = "(classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :="
th_end = src.index(end_tok, th_start) + len(end_tok)
stmt = src[th_start:th_end]
pf_end = src.index("\nend StgTop\n", th_end)
proof = src[th_end:pf_end]
assert proof.lstrip().startswith("by"), proof[:40]


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
    assert n == count, (old[:80], n, count)
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
HOSTI = "ZK60.ProtocolClassify.stgHostIn"
HOSTO = "(ZK60.ProtocolClassify.stgHostOut P0out)"

# 1. the binders removed: hostIn, hostOut (the hosting is fixed) and hhIn, hhOut (PROVED)
binders = top_binders(stmt)
explicit = [n for (k, ns, _, _) in binders if k == "(" for n in ns]
assert explicit.count("hostIn") == 1 and explicit.count("hostOut") == 1
GONE = ["hhIn", "hhOut"]
COV = ["hdin", "hdout"]
spans = {}
for (k, ns, s, e) in binders:
    if ns and ns[0] in GONE + COV:
        assert len(ns) == 1
        spans[ns[0]] = (s, e, stmt[s:e])
assert sorted(spans) == sorted(GONE + COV), sorted(spans)


def split_concl(t):
    body = t[1:-1]
    j = body.rindex("→")
    return body[:j + 1], body[j + 1:]


CONC = {"hdin": f"\n      ZK60.ProtocolClassify.StgDoomAtV U key domain P0in {POFI} mIn {HIN} {BGAI} {HOSTI} {ABS} FstI ΦI dgI eI ΛI G"
                f" {LG}\n        {TR}",
        "hdout": f"\n      ZK60.ProtocolClassify.StgDoomAtV U key domain P0out {POFO} 2 {HOUT} {BGAO} {HOSTO} {ABS} FstO ΦO dgO eO ΛO"
                 f" G {LG}\n        {TR}"}
NEWN = {"hdin": "hdinS", "hdout": "hdoutS"}

out = ""
pos = 0
for (k, ns, s, e) in binders:
    if not (ns and ns[0] in GONE + COV):
        continue
    h = ns[0]
    out += stmt[pos:s]
    if h in GONE:
        # drop the binder and the line break and indentation before it
        out = out.rstrip(" \n")
        out += "\n    " if not out.endswith("\n    ") else ""
        pos = e
        while pos < len(stmt) and stmt[pos] in " \n":
            pos += 1
        continue
    pre, c = split_concl(spans[h][2])
    assert "∃ K' ∈ rtKo" in c, (h, c)
    out += f"({NEWN[h]} : " + pre[len(h) + 3:] + CONC[h] + ")"
    pos = e
out += stmt[pos:]
new = out

# 2. the types of the stage polynomials and states: the view
new = rep(new, "(P0in P0out : Exec.Block.BlockParams) (hostIn hostOut : ℕ → List (ℕ × ℕ))",
          "(P0in P0out : Exec.Block.BlockParams)", 1)
new = rep(new, "(FstI : (ℕ → List (QB Lq × Dig)) → (k : ℕ)", "(FstI : StgVw Lq → (k : ℕ)", 1)
new = rep(new, "(FstO : (ℕ → List (QB Lq × Dig)) → (k : ℕ)", "(FstO : StgVw Lq → (k : ℕ)", 1)
new = rep(new, "(ΦI : (ℕ → List (QB Lq × Dig)) → (k : ℕ)", "(ΦI : StgVw Lq → (k : ℕ)", 1)
new = rep(new, "(ΦO : (ℕ → List (QB Lq × Dig)) → (k : ℕ)", "(ΦO : StgVw Lq → (k : ℕ)", 1)
new = rep(new, "(ΛI ΛO : (ℕ → List (QB Lq × Dig)) → List (List UInt8 × K) → Prop)",
          "(ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)", 1)
# 3. the lists: the view lists, the hosting fixed
new = rep(new, f"(stgSchedX P0in mIn {HIN} hostIn ", f"(stgSchedV P0in mIn {HIN} {HOSTI} ", 1)
new = rep(new, f"(stgSchedX P0out 2 {HOUT} hostOut ", f"(stgSchedV P0out 2 {HOUT} {HOSTO} ", 1)
new = rep(new, "(stgDefs P0in ", "(stgDefsV P0in ", 1)
new = rep(new, "(stgDefs P0out ", "(stgDefsV P0out ", 1)
new = rep(new, "(stgLkSq mIn ", "(stgLkSqV mIn ", 1)
new = rep(new, "(stgLkSq 2 ", "(stgLkSqV 2 ", 1)
# 4. the stage-level facts over the view
new = rep(new, "StgTermAt U key domain", "StgTermAtV U key domain", 2)
new = rep(new, "StgDefAt U key domain", "StgDefAtV U key domain", 2)
new = rep(new, "StgLkAt U key domain", "StgLkAtV U key domain", 2)
new = rep(new, "theorem stg_productionReadyL_epP_exec_lists ", "theorem stgAlg_productionReadyL_epP_exec_view ", 1)
assert "hostIn" not in new and "hostOut" not in new and "hhIn" not in new and "hhOut" not in new
assert "stgSchedX" not in new and "stgDefs " not in new and "stgLkSq " not in new

# the proof
HE = ("(by have h := rc_uexecP_E Rp Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows "
      "bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768 G _ _ hv'; rw [OC.runLog_fst] at h; exact h)")
LISTS = (f"(ZK60.ProtocolClassify.stg_D_lists U tag Lq h64 key domain hs hL (RtRun.pf Rn) base Lb _ _ _ _ _ eL D hDe "
         f"_ _ _ _ _ _ hb0 hbL)")
COMMON = ("(U := U) (hbij := hbij) (hs := hs) (hL := hL) (hL64 := hL64) (Lb := Lb) (preA := preA) (preB := preB) "
          "(start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG) (Pk := Pk) (sgeom := sgeom) "
          "(check := check) (paths := paths) (digest := digest) (bRows := bRows) (bLogN := bLogN) "
          "(bndCheck := bndCheck) (bndOpen := bndOpen) (R := Rn) (hv := hv) (cx0 := cx0) (pin := pin) (pout := pout) "
          "(bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ) (Iin := Iin) (Oout := Oout) (mIn := mIn) "
          f"(hmIn := hmIn) (D := D) (hD := hD) (P0in := P0in) (P0out := P0out) (hostIn := {HOSTI}) (hostOut := {HOSTO}) "
          "(FI := FstI) (FO := FstO) (ΦI := ΦI) (ΦO := ΦO) (dgI := dgI) (dgO := dgO) (eI := eI) (eO := eO) (ΛI := ΛI) "
          "(ΛO := ΛO) (hPin := hPin) (hPout := hPout) "
          f"(hS0 := {LISTS}.1.1) (hR0 := {LISTS}.1.2.1) (hL0 := {LISTS}.1.2.2.2.2.2) "
          f"(hS1 := {LISTS}.2.1) (hR1 := {LISTS}.2.2.1) (hL1 := {LISTS}.2.2.2.2.2.2) "
          "(n := Rp.blks.length + 2) (hn := congrArg (fun x => x + 2) O.blocks.2) (lg := (A.runLog G).2) (G := G) "
          "(s := (A.run G).1) (segs := (A.run G).2) (hE := " + HE + ")")


def cov_term(h):
    side = "Or.inl" if h == "hdin" else "Or.inr"
    return (f"({h} := fun A G hv' hx' hn' => ZK60.ProtocolClassify.stg_hal_doomV {COMMON} "
            f"(hdoom := {side} ({NEWN[h]} A G hv' hx' hn')))")


pf = proof
pf = rep(pf, "(hdin := hdin)", cov_term("hdin"), 1)
pf = rep(pf, "(hdout := hdout)", cov_term("hdout"), 1)
pf = rep(pf, "ZK60.ProtocolClassify.stg_hal_sl ", "ZK60.ProtocolClassify.stg_hal_slV ", 1)
pf = rep(pf, "ZK60.ProtocolClassify.stg_hal_r0 ", "ZK60.ProtocolClassify.stg_hal_r0V ", 1)
pf = rep(pf, "ZK60.ProtocolClassify.stg_hal_lu ", "ZK60.ProtocolClassify.stg_hal_luV ", 1)
pf = rep(pf, "(hostIn := hostIn) (hostOut := hostOut)", f"(hostIn := {HOSTI}) (hostOut := {HOSTO})", 1)
pf = rep(pf, "(hhIn := hhIn) (hhOut := hhOut)",
         "(hhIn := ZK60.ProtocolClassify.stg_hhIn inc) (hhOut := ZK60.ProtocolClassify.stg_hhOut outc P0out hPout)", 1)
assert "hostIn :=" in pf

doc = '''/-- **THE APP'S TOP THEOREM AT THE VIEW STAGE LISTS, THE HOSTING PROVED** (D63 lane L57, finding L57-1). Lane L53's
`stg_productionReadyL_epP_exec_lists` and `stg_productionReadyL_epP_exec_doom` with the stage polynomials and LogUp
states reading the VIEW (the cuts the header shows AND the header, so that they can read the committed roots and the
statement the extraction and the stages' `define`s read), the hosting fixed to the code's and its premises `hhIn`,
`hhOut` PROVED (`stg_hhIn`, `stg_hhOut`), the stage-level facts and dooms over the view (`StgTermAtV`, `StgDefAtV`,
`StgLkAtV`, `StgDoomAtV`), under the SAME hypotheses. Generated by results/zk60_lean_l57_20261110/l57_mk_top.py. -/
'''

head = '''/-
D63 lane L57 (2026-11-10), part 4: **the app's top theorem at the view stage lists, the hosting proved** (finding
L57-1; deliverables 1 and 4). GENERATED by results/zk60_lean_l57_20261110/l57_mk_top.py from lane L53's
`stg_productionReadyL_epP_exec_lists` (RunStgTop.lean): the same section header and binders, the stage polynomials'
types the view, the lists the view lists with the code's hosting, `hostIn`, `hostOut`, `hhIn`, `hhOut` removed,
`hdin`, `hdout` replaced by the stages' view dooms; the proof applies lane L50's theorem with the stage terms of
RunStgAlgRun.lean and RunStgAlgHost.lean.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgTop
import ZK60Formal.RunStgAlgRun

set_option autoImplicit false
'''

text = head + prefix + doc + new + pf + "\nend StgAlgTop\n\nend ZK60.ProtocolClassify.RunShapeP\n"
open(L + "RunStgAlgTop.lean", "w").write(text)
nb = len([n for (k, ns, _, _) in top_binders(new) if k == "(" for n in ns])
print("wrote RunStgAlgTop.lean:", len(text.splitlines()), "lines;", len(explicit), "explicit binders in L53's,", nb,
      "in the new; removed hostIn, hostOut, hhIn, hhOut; hdin, hdout replaced by hdinS, hdoutS")
