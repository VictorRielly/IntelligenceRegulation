#!/usr/bin/env python3
"""D63 lane L53 (2026-11-10): generate formal/ZK60Formal/RunStgTopD.lean, the app's top theorem with the stage doom
covers `hdin`, `hdout` DISCHARGED at the stage parts' lists (RunStgDoom.lean) down to each stage's own doom at its
reading of the run.

It reads this lane's `stg_productionReadyL_epP_exec_lists` (RunStgTop.lean) and writes
`stg_productionReadyL_epP_exec_doom`:
  * the same statement (the same section header, the same binders), except that
  * `hdin` is replaced by `hdinS` and `hdout` by `hdoutS`, under the SAME hypotheses (acceptance, outside the run's
    extraction event, the stage's conclusion failing), with the conclusion the stage's doom at the run's reading
    (`StgDoomAt` of stage IN-C, resp. OUT-C, at the lists' polynomials);
  * the proof applies `stg_productionReadyL_epP_exec_lists` with every binder passed by name and `hdin`, `hdout` :=
    `stg_hal_doom` (the part count `Lb + 2 = Rp.blks.length + 2` from `O.blocks`, the lists from `stg_D_lists`).
The script checks that `hdin` and `hdout` are found exactly once each, keeps every other binder verbatim, and refuses
to write if any binder name of the original is not passed.

usage: python3 l53_mk_topd.py <WT>
"""
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
L = WT + "/formal/ZK60Formal/"
src = open(L + "RunStgTop.lean").read()

fl_start = src.index("set_option linter.constructorNameAsVariable false\n")
doc_start = src.index("/-- **THE APP'S TOP THEOREM WITH THE STAGE PARTS' LISTS CHOSEN AND THEIR SIX ALIVE PREMISES DISCHARGED**")
prefix = src[fl_start:doc_start].replace("section StgTop\n", "section StgTopD\n")
assert "section StgTopD\n" in prefix

th_start = src.index("theorem stg_productionReadyL_epP_exec_lists ")
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


binders = top_binders(stmt)
explicit = [n for (k, ns, _, _) in binders if k == "(" for n in ns]
COV = ["hdin", "hdout"]
cov = {}
for (k, ns, s, e) in binders:
    if ns and ns[0] in COV:
        assert len(ns) == 1
        cov[ns[0]] = (s, e, stmt[s:e])
assert sorted(cov) == sorted(COV), sorted(cov)

TR = "(rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))"
LG = "(A.runLog G).2"
ABS = "(Exec.Block.absOfC (chainEncB key domain hs Lq hL))"
HIN = "((RtRun.pf Rn).off 0 + 5)"
HOUT = "((RtRun.pf Rn).off (Lb + 1) + 2)"
POFI = "(fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch))"
POFO = "(fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp)"
BGAI = "(fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))"
BGAO = "OutcV.bga"


def split_concl(t):
    body = t[1:-1]
    j = body.rindex("→")
    return body[:j + 1], body[j + 1:]


CONC = {"hdin": f"\n      StgDoomAt U key domain P0in {POFI} mIn {HIN} {BGAI} hostIn {ABS} FstI ΦI dgI eI ΛI G {LG}\n        {TR}",
        "hdout": f"\n      StgDoomAt U key domain P0out {POFO} 2 {HOUT} {BGAO} hostOut {ABS} FstO ΦO dgO eO ΛO G {LG}\n        {TR}"}
NEWN = {"hdin": "hdinS", "hdout": "hdoutS"}

out = ""
pos = 0
for h in ["hdin", "hdout"]:
    s, e, t = cov[h]
    out += stmt[pos:s]
    pre, c = split_concl(t)
    assert "∃ K' ∈ rtKo" in c, (h, c)
    out += f"({NEWN[h]} : " + pre[len(h) + 3:] + CONC[h] + ")"
    pos = e
out += stmt[pos:]
out = out.replace("theorem stg_productionReadyL_epP_exec_lists ", "theorem stg_productionReadyL_epP_exec_doom ", 1)

SECVARS = ["Rr", "dR", "hpos", "place", "msg", "msg_place", "pad", "salt", "path", "tagc"]
HE = ("(by have h := rc_uexecP_E Rp Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows "
      "bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768 G _ _ hv'; rw [OC.runLog_fst] at h; exact h)")
LISTS = (f"(ZK60.ProtocolClassify.stg_D_lists U tag Lq h64 key domain hs hL (RtRun.pf Rn) base Lb _ _ _ _ _ eL D hDe "
         f"_ _ _ _ _ _ hb0 hbL)")
COMMON = ("(U := U) (hbij := hbij) (hs := hs) (hL := hL) (hL64 := hL64) (Lb := Lb) (preA := preA) (preB := preB) "
          "(start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG) (Pk := Pk) (sgeom := sgeom) "
          "(check := check) (paths := paths) (digest := digest) (bRows := bRows) (bLogN := bLogN) "
          "(bndCheck := bndCheck) (bndOpen := bndOpen) (R := Rn) (hv := hv) (cx0 := cx0) (pin := pin) (pout := pout) "
          "(bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ) (Iin := Iin) (Oout := Oout) (mIn := mIn) "
          "(hmIn := hmIn) (D := D) (hD := hD) (P0in := P0in) (P0out := P0out) (hostIn := hostIn) (hostOut := hostOut) "
          "(FI := FstI) (FO := FstO) (ΦI := ΦI) (ΦO := ΦO) (dgI := dgI) (dgO := dgO) (eI := eI) (eO := eO) (ΛI := ΛI) "
          "(ΛO := ΛO) (hPin := hPin) (hPout := hPout) "
          f"(hS0 := {LISTS}.1.1) (hR0 := {LISTS}.1.2.1) (hL0 := {LISTS}.1.2.2.2.2.2) "
          f"(hS1 := {LISTS}.2.1) (hR1 := {LISTS}.2.2.1) (hL1 := {LISTS}.2.2.2.2.2.2) "
          "(n := Rp.blks.length + 2) (hn := congrArg (fun x => x + 2) O.blocks.2) (lg := (A.runLog G).2) (G := G) "
          "(s := (A.run G).1) (segs := (A.run G).2) (hE := " + HE + ")")


def cov_term(h):
    side = "Or.inl" if h == "hdin" else "Or.inr"
    return (f"({h} := fun A G hv' hx' hn' => ZK60.ProtocolClassify.stg_hal_doom {COMMON} "
            f"(hdoom := {side} ({NEWN[h]} A G hv' hx' hn')))")


args = [f"({n} := {n})" for n in SECVARS]
passed = set(SECVARS)
for n in explicit:
    if n in COV:
        continue
    args.append(f"({n} := {n})")
    passed.add(n)
for h in COV:
    args.append(cov_term(h))
    passed.add(h)
missing = [n for n in explicit if n not in passed]
assert not missing, missing

lines = []
cur = "  exact stg_productionReadyL_epP_exec_lists"
for a in args:
    if len(cur) + 1 + len(a) > 118:
        lines.append(cur)
        cur = "    " + a
    else:
        cur += " " + a
lines.append(cur)
proof = "\n  by\n" + "\n".join(lines) + "\n"

doc = '''/-- **THE APP'S TOP THEOREM WITH THE STAGE DOOM COVERS DISCHARGED AT THE STAGE LISTS** (D63 lane L53, deliverable 3).
This lane's `stg_productionReadyL_epP_exec_lists` with `hdin` and `hdout` replaced by `hdinS`, `hdoutS` under the SAME
hypotheses: when stage IN-C's (OUT-C's) conclusion fails on the extracted data, the stage's doom at the run's reading of
the stage (`StgDoomAt`: one of the stage list's entries starts from a false claim on the stage's own trace), from which
the run's kinds carry a doomed entrant (`stg_hal_doom`: `stg_inc_rd`, `stg_outc_rd`, `stg_cover_rd`). Generated by
results/zk60_lean_l53_20261110/l53_mk_topd.py. -/
'''

head = '''/-
D63 lane L53 (2026-11-10), part 7: **the app's top theorem with the stage doom covers discharged at the stage lists**
(deliverable 3, assembled). GENERATED by results/zk60_lean_l53_20261110/l53_mk_topd.py from this lane's
`stg_productionReadyL_epP_exec_lists` (RunStgTop.lean): the same section header and binders; `hdin`, `hdout` replaced
by the stages' dooms at their readings; the proof applies that theorem with `hdin`, `hdout` := `stg_hal_doom`
(RunStgDoom.lean).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgTop
import ZK60Formal.RunStgDoom

set_option autoImplicit false
'''

text = head + prefix + doc + out + proof + "\nend StgTopD\n\nend ZK60.ProtocolClassify.RunShapeP\n"
open(L + "RunStgTopD.lean", "w").write(text)
print("wrote RunStgTopD.lean:", len(text.splitlines()), "lines;", len(explicit), "explicit binders;", len(args),
      "named arguments; hdin, hdout replaced by hdinS, hdoutS")
