#!/usr/bin/env python3
"""D63 lane L53 (2026-11-10): generate formal/ZK60Formal/RunStgTop.lean, the app's top theorem with the six stage
alive premises (`hsl_stg`, `hR0_stg`, `hR1_stg`, `hH0_stg`, `hH1_stg`, `hLU_stg`) DISCHARGED at the stage parts' lists
of RunStgList.lean (finding L50-1), down to the stages' own algebra at each stage's reading of the run.

It reads lane L50's `ra_productionReadyL_epP_exec_alive` (RunAliveTop.lean) and writes
`stg_productionReadyL_epP_exec_lists`:
  * the same statement (the same section header, the same binders), except that
  * new binders before `hsl_stg`: the lists' schedules `P0in`, `P0out` and hosting `hostIn`, `hostOut`; the stage slot
    polynomials `FstI`, `FstO`, define polynomials `ΦI`, `ΦO` with degrees `dgI`, `dgO`, LogUp states `ΛI`, `ΛO` with
    escape counts `eI`, `eO`; THE CHOICE `hb0`, `hbL` (`StgLists (base 0) …`, `StgLists (base (Lb + 1)) …`); the lists'
    schedules having the stages' draws and slot shapes (`hPin`, `hPout`) and hosting (`hhIn`, `hhOut`);
  * `hsl_stg` replaced by `hTI_stg`, `hTO_stg` (each stage's slots' terminal identities at its readings, `StgTermAt`),
    `hR0_stg` by `hDI_stg`, `hDO_stg` (`StgDefAt`), `hLU_stg` by `hLI_stg`, `hLO_stg` (`StgLkAt`), each under the SAME
    hypotheses as the premise it replaces; `hR1_stg`, `hH0_stg`, `hH1_stg` GONE (the stages list nothing there);
  * the proof applies `ra_productionReadyL_epP_exec_alive` with every binder passed by name and the six stage premises
    := the stage assembly (`stg_hal_sl`, `stg_hal_r0`, `stg_hal_nil`, `stg_hal_lu`, `stg_D_lists`).
The script checks that the six premises are found exactly once each, keeps every other binder verbatim, and refuses to
write if any binder name of the original is not passed.

usage: python3 l53_mk_top.py <WT>
"""
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
L = WT + "/formal/ZK60Formal/"
src = open(L + "RunAliveTop.lean").read()

# the file-level options, namespace, opens and the section header (L50's file: everything up to the theorem's doc)
fl_start = src.index("set_option linter.constructorNameAsVariable false\n")
doc_start = src.index("/-- **THE APP'S TOP THEOREM WITH THE SIX REMAINING ALIVE PREMISES DISCHARGED AT THE BLOCKS**")
prefix = src[fl_start:doc_start].replace("section RaTop\n", "section StgTop\n")
assert "namespace ZK60.ProtocolClassify.RunShapeP\n" in prefix and "section StgTop\n" in prefix

th_start = src.index("theorem ra_productionReadyL_epP_exec_alive ")
end_tok = "(classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :="
th_end = src.index(end_tok, th_start) + len(end_tok)
stmt = src[th_start:th_end]


def top_binders(text):
    """The top-level binder groups of a theorem statement: (kind, names, start, end)."""
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
STG = ["hsl_stg", "hR0_stg", "hR1_stg", "hH0_stg", "hH1_stg", "hLU_stg"]
stg_text = {}
for (k, ns, s, e) in binders:
    if ns and ns[0] in STG:
        assert len(ns) == 1
        stg_text[ns[0]] = (s, e, stmt[s:e])
assert sorted(stg_text) == sorted(STG), sorted(stg_text)
for n in ["mIn", "base", "hDe", "Iin", "Oout", "hmIn", "hσ", "hblk", "hdin", "hdout"]:
    assert n in explicit, n

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
    """A premise `(h : ∀ A G, H₁ → … → Hₙ → C)`: its text up to the conclusion, and the conclusion."""
    body = t[1:-1]
    j = body.rindex("→")
    return body[:j + 1], body[j + 1:]


def concl(kind, side):
    pof, bga, hl, p0, m = (POFI, BGAI, HIN, "P0in", "mIn") if side == "I" else (POFO, BGAO, HOUT, "P0out", "2")
    if kind == "T":
        return (f"\n      StgTermAt U key domain {p0} {pof} {m} {hl} {bga} {ABS} Fst{side} G {LG}\n        {TR}")
    if kind == "D":
        return (f"\n      StgDefAt U key domain {p0} {pof} {m} {hl} {bga} {ABS} Φ{side} G {LG}\n        {TR}")
    return f"\n      StgLkAt U key domain {pof} {m} {hl} {bga} {ABS} Λ{side} G {LG}\n        {TR}"


NEWBIND = f"""(P0in P0out : Exec.Block.BlockParams) (hostIn hostOut : ℕ → List (ℕ × ℕ))
    (FstI : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0in k) → K) → K)
    (FstO : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0out k) → K) → K)
    (ΦI : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0in.draws k) → K) → K)
    (ΦO : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0out.draws k) → K) → K)
    (dgI dgO : ℕ → ℕ) (eI eO : ℕ) (ΛI ΛO : (ℕ → List (QB Lq × Dig)) → List (List UInt8 × K) → Prop)
    (hb0 : StgLists (base 0) (stgSchedX P0in mIn {HIN} hostIn {ABS} FstI)
      (stgDefs P0in mIn {HIN} {ABS} ΦI dgI) (stgLkSq mIn {HIN} eI {ABS} ΛI))
    (hbL : StgLists (base (Lb + 1)) (stgSchedX P0out 2 {HOUT} hostOut {ABS} FstO)
      (stgDefs P0out 2 {HOUT} {ABS} ΦO dgO) (stgLkSq 2 {HOUT} eO {ABS} ΛO))
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx)) (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (hhIn : ∀ hd cx k hist dr df, ((inc hd).bp cx).define k hist dr = .ok df →
      df.hosted = (hostIn k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hhOut : ∀ hd v k hist dr df, (outc hd v).bp.define k hist dr = .ok df →
      df.hosted = (hostOut k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    """

REPL = {"hsl_stg": [("hTI_stg", "T", "I"), ("hTO_stg", "T", "O")], "hR0_stg": [("hDI_stg", "D", "I"), ("hDO_stg", "D", "O")],
        "hR1_stg": [], "hH0_stg": [], "hH1_stg": [], "hLU_stg": [("hLI_stg", "L", "I"), ("hLO_stg", "L", "O")]}

first_s = stg_text["hsl_stg"][0]
out = stmt[:first_s] + NEWBIND
pos = first_s
for h in STG:
    s, e, t = stg_text[h]
    gap = stmt[pos:s] if pos < s else ""
    pre, c = split_concl(t)
    reps = REPL[h]
    if reps:
        out += gap
        parts = []
        for (nm, kind, side) in reps:
            parts.append(f"({nm} : " + pre[len(h) + 3:] + concl(kind, side) + ")")
        out += "\n    ".join(parts)
    else:
        # drop the premise and the whitespace before it
        out = out.rstrip() + gap.rstrip() if gap.strip() else out.rstrip()
    pos = e
out += stmt[pos:]
out = out.replace("theorem ra_productionReadyL_epP_exec_alive ", "theorem stg_productionReadyL_epP_exec_lists ", 1)

# the proof
SECVARS = ["Rr", "dR", "hpos", "place", "msg", "msg_place", "pad", "salt", "path", "tagc"]
HE = ("(by have h := rc_uexecP_E Rp Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows "
      "bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768 G _ _ hv'; rw [OC.runLog_fst] at h; exact h)")
COMMON = ("(U := U) (Lb := Lb) (preA := preA) (preB := preB) "
          "(start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG) (Pk := Pk) (sgeom := sgeom) "
          "(check := check) (paths := paths) (digest := digest) (bRows := bRows) (bLogN := bLogN) "
          "(bndCheck := bndCheck) (bndOpen := bndOpen) (R := Rn) (hv := hv) (cx0 := cx0) (pin := pin) (pout := pout) "
          "(bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ) (Iin := Iin) (Oout := Oout) (mIn := mIn) "
          f"(hmIn := hmIn) (absOf := {ABS}) (D := D) (lg := (A.runLog G).2) (G := G) "
          "(s := (A.run G).1) (segs := (A.run G).2) (hE := " + HE + ")")
LISTS = (f"(ZK60.ProtocolClassify.stg_D_lists U tag Lq h64 key domain hs hL (RtRun.pf Rn) base Lb _ _ _ _ _ eL D hDe "
         f"_ _ _ _ _ _ hb0 hbL)")
NHYP = {"hsl_stg": 3, "hR0_stg": 4, "hR1_stg": 5, "hH0_stg": 6, "hH1_stg": 7, "hLU_stg": 8}


def stg_term(h):
    hs_ = " ".join(f"h{i}" for i in range(1, NHYP[h] + 1))
    app = f"A G hv' hx' {hs_}"
    if h == "hsl_stg":
        return (f"(hsl_stg := fun A G hv' hx' {hs_} => ZK60.ProtocolClassify.stg_hal_sl {COMMON} (hs := hs) (hL := hL) "
                f"(hL64 := hL64) (hU := hU) (hL81 := hL81) (P0in := P0in) (P0out := P0out) (hostIn := hostIn) "
                f"(hostOut := hostOut) (FI := FstI) (FO := FstO) (hPin := hPin) (hPout := hPout) (hhIn := hhIn) "
                f"(hhOut := hhOut) (hS0 := {LISTS}.1.1) (hS1 := {LISTS}.2.1) "
                f"(hTI := hTI_stg {app}) (hTO := hTO_stg {app}))")
    if h == "hR0_stg":
        return (f"(hR0_stg := fun A G hv' hx' {hs_} => ZK60.ProtocolClassify.stg_hal_r0 {COMMON} (P0in := P0in) "
                f"(P0out := P0out) (ΦI := ΦI) (ΦO := ΦO) (dgI := dgI) (dgO := dgO) (hPin := hPin) (hPout := hPout) "
                f"(hR0 := {LISTS}.1.2.1) (hR1 := {LISTS}.2.2.1) "
                f"(hDI := hDI_stg {app}) (hDO := hDO_stg {app}))")
    if h == "hLU_stg":
        return (f"(hLU_stg := fun A G hv' hx' {hs_} => ZK60.ProtocolClassify.stg_hal_lu {COMMON} (eI := eI) (eO := eO) "
                f"(ΛI := ΛI) (ΛO := ΛO) (hL0 := {LISTS}.1.2.2.2.2.2) (hL1 := {LISTS}.2.2.2.2.2.2) "
                f"(hLI := hLI_stg {app}) (hLO := hLO_stg {app}))")
    sel = {"hR1_stg": ("D.r1", ".2.2.1", ".2.2.1"), "hH0_stg": ("D.h0", ".2.2.2.1", ".2.2.2.1"),
           "hH1_stg": ("D.h1", ".2.2.2.2.1", ".2.2.2.2.1")}[h]
    return (f"({h} := fun A G hv' hx' {hs_} => ZK60.ProtocolClassify.stg_hal_nil U {sel[0]} Lb {LISTS}.1{sel[1]} "
            f"{LISTS}.2{sel[2]} (A.runLog G).2 {TR})")


args = [f"({n} := {n})" for n in SECVARS]
passed = set(SECVARS)
for n in explicit:
    if n in STG:
        continue
    args.append(f"({n} := {n})")
    passed.add(n)
for h in STG:
    args.append(stg_term(h))
    passed.add(h)
missing = [n for n in explicit if n not in passed]
assert not missing, missing

lines = []
cur = "  exact ra_productionReadyL_epP_exec_alive"
for a in args:
    if len(cur) + 1 + len(a) > 118:
        lines.append(cur)
        cur = "    " + a
    else:
        cur += " " + a
lines.append(cur)
proof = "\n  by\n" + "\n".join(lines) + "\n"

doc = '''/-- **THE APP'S TOP THEOREM WITH THE STAGE PARTS' LISTS CHOSEN AND THEIR SIX ALIVE PREMISES DISCHARGED** (D63 lane
L53, finding L50-1). L50's `ra_productionReadyL_epP_exec_alive` with the stage parts' lists fixed to the code's stage
verifiers (`hb0`, `hbL`: every stage slot, the define draws of the slots that draw in `r0`, the head's challenges as the
one LogUp run, nothing in `r1`, `h0`, `h1`; RunStgList.lean, CHECKED by RunStgCheck.lean) and `hsl_stg`, `hR0_stg`,
`hLU_stg` each replaced by the two stages' stage-level facts at their readings of the run, under the SAME hypotheses
(`StgTermAt`: the slots' terminal identities; `StgDefAt`: the define polynomials vanishing at the drawn challenges;
`StgLkAt`: LogUp's state at the head's challenges), from which the run's transcript carries the aliveness
(`stg_inc_rd`, `stg_outc_rd`, `stg_slots_alive`, `stg_def_alive`, `stg_lk_alive`); `hR1_stg`, `hH0_stg`, `hH1_stg`
discharged outright (`stg_hal_nil`). Generated by results/zk60_lean_l53_20261110/l53_mk_top.py. -/
'''

head = '''/-
D63 lane L53 (2026-11-10), part 5: **the app's top theorem with the stage parts' lists chosen and their alive premises
discharged** (deliverable 4). GENERATED by results/zk60_lean_l53_20261110/l53_mk_top.py from lane L50's
`ra_productionReadyL_epP_exec_alive` (RunAliveTop.lean): the same section header and binders; the stage lists' choice
and its side facts added; `hsl_stg`, `hR0_stg`, `hLU_stg` replaced by the stages' stage-level facts; `hR1_stg`,
`hH0_stg`, `hH1_stg` removed; the proof applies L50's theorem with the six premises := lane L53's assembly
(RunStgHal.lean).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunAliveTop
import ZK60Formal.RunStgHal

set_option autoImplicit false
'''

text = head + prefix + doc + out + proof + "\nend StgTop\n\nend ZK60.ProtocolClassify.RunShapeP\n"
open(L + "RunStgTop.lean", "w").write(text)
print("wrote RunStgTop.lean:", len(text.splitlines()), "lines;", len(explicit), "explicit binders of L50's theorem;",
      len(args), "named arguments; six stage premises replaced by six stage-level facts (three removed)")
