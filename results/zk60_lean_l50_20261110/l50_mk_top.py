#!/usr/bin/env python3
"""D63 lane L50 (2026-11-10): generate formal/ZK60Formal/RunAliveTop.lean, the app's top theorem with the six remaining
ordered alive premises (`hal_slots`, `hal_R0`, `hal_R1`, `hal_H0`, `hal_H1`, `hal_LU`) DISCHARGED at the 26 blocks'
parts to the blocks' own algebra at each block's reading of the run (RunAliveHal.lean), the two stages' parts named.

It reads lane L48's `og_productionReadyL_epP_exec_blk` (RunOpenGeoEP.lean) and writes `ra_productionReadyL_epP_exec_alive`:
  * the same statement (the same section header, the same binders), except that
  * the six premises `hal_X` are each replaced by TWO premises with the SAME hypotheses (acceptance, the run's
    extraction event, the earlier kinds' "no doomed entrant"): `hX_blk` (at every block `k < Lb`, the block-level fact
    at the block's reading: `RaTermAt` for the slots, `RaDefAt` for the four define kinds, `RaLkAt` for LogUp) and
    `hX_stg` (the two stage parts' sub-protocols alive, in `allSt` / `subSt` form);
  * new binders before them: `hL81`, the blocks' slot polynomials `Fsl` (`F` is already the test's field), the block
    parts' slots being L16's schedule
    (`hslB`), and the blocks' LogUp data (`ιL`, `πL`, `κL` with their `Fintype`, `AlkL`, `TL`, `mlkL`); the slots'
    geometry comes from the block contracts `bp k` (`hgeomL`, `hgt`) and `Lq < 2^64`;
  * the proof applies `og_productionReadyL_epP_exec_blk` with every binder passed by name and `hal_X :=` the run-level
    assembly (`ra_hal_sl`, `ra_hal_def`, `ra_hal_lu`).
The script checks that the six `hal_X` premises are found exactly once each, keeps every other binder verbatim, and
refuses to write if any binder name of the original is not passed.

usage: python3 l50_mk_top.py <WT>
"""
import re
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
L = WT + "/formal/ZK60Formal/"
src = open(L + "RunOpenGeoEP.lean").read()

# the file-level options, namespace and opens
fl_start = src.index("set_option linter.constructorNameAsVariable false\n")
fl_end = src.index("section og_productionReadyL_run_epP_some_range\n")
filehdr = src[fl_start:fl_end]
assert "namespace ZK60.ProtocolClassify.RunShapeP\n" in filehdr
# the section header (opens, variables, the local notation)
hdr_start = src.index("section EpBlkTop\n")
doc_start = src.index("/-- **THE APP'S TOP THEOREM AT THE REAL WIDTHS, WITH THE BLOCK COVER")
header = src[hdr_start:doc_start].replace("section EpBlkTop\n", "section RaTop\n")

# the statement
th_start = src.index("theorem og_productionReadyL_epP_exec_blk ")
end_tok = "(classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :="
th_end = src.index(end_tok, th_start) + len(end_tok)
stmt = src[th_start:th_end]


def top_binders(text):
    """The top-level binder groups of a theorem statement: (kind, names, start, end)."""
    i = text.index(" ") + 1
    i = text.index(" ", i)  # after the theorem's name
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
            break  # the conclusion
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
assert "hal_slots" in explicit and "hdin" in explicit, "binders not parsed"

HAL = ["hal_slots", "hal_R0", "hal_R1", "hal_H0", "hal_H1", "hal_LU"]
hal_text = {}
for (k, ns, s, e) in binders:
    if ns and ns[0] in HAL:
        assert len(ns) == 1
        hal_text[ns[0]] = (s, e, stmt[s:e])
assert sorted(hal_text) == sorted(HAL), sorted(hal_text)

TR = "(rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))"
LG = "(A.runLog G).2"
ABS = "(Exec.Block.absOfC (chainEncB key domain hs Lq hL))"
POS = "((RtRun.pf Rn).off (k + 1) + 5)"


def split_concl(t):
    """A hal premise `(hal_X : ∀ A G, H₁ → … → Hₙ → (rtK… …).Al … …)`: its text up to the conclusion, and the
    conclusion. The conclusion is the last arrow's right side."""
    body = t[1:-1]
    j = body.rindex("→")
    return body[:j + 1], body[j + 1:]


KIND = {"hal_slots": "sls", "hal_R0": "r0", "hal_R1": "r1", "hal_H0": "h0", "hal_H1": "h1", "hal_LU": "lu"}
NEWNAME = {"hal_slots": "hsl", "hal_R0": "hR0", "hal_R1": "hR1", "hal_H0": "hH0", "hal_H1": "hH1", "hal_LU": "hLU"}


def blk_concl(h):
    if h == "hal_slots":
        return (f"\n      ∀ k, k < Lb → RaTermAt U key domain (Pk k) {POS} {ABS} (Fsl k) G {LG}\n        {TR}")
    if h == "hal_LU":
        return (f"\n      ∀ k, k < Lb → ∀ sx ∈ D.lu (k + 1), RaLkAt U key domain (Pk k) {POS} {ABS} (AlkL k) (TL k)"
                f" (mlkL k) G {LG}\n        {TR} sx")
    return (f"\n      ∀ k, k < Lb → ∀ sx ∈ D.{KIND[h]} (k + 1), RaDefAt U key domain (Pk k) {POS} {ABS} G {LG}\n"
            f"        {TR} sx")


def stg_concl(h):
    if h == "hal_slots":
        return (f"\n      allSt W1 (slotSubs U (slotsAt (D.sls 0) {LG})) {TR}\n"
                f"        ∧ allSt W1 (slotSubs U (slotsAt (D.sls (Lb + 1)) {LG})) {TR}")
    return (f"\n      (∀ sx ∈ D.{KIND[h]} 0, subSt W1 (sqSub U sx {LG}) {TR})\n"
            f"        ∧ (∀ sx ∈ D.{KIND[h]} (Lb + 1), subSt W1 (sqSub U sx {LG}) {TR})")


NEWBIND = """(hL81 : 81 ≤ Lq)
    (Fsl : (k : ℕ) → Exec.Block.Cuts3 Lq → Exec.Block.RootsO → (j : ℕ) → Exec.Block.Seen →
      (Fin ((Exec.Block.slotShape (Pk k) j).1 + (Exec.Block.slotShape (Pk k) j).2.1) → K) → K)
    (hslB : ∀ k, k < Lb → D.sls (k + 1) = Exec.Block.blockSchedX (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (Fsl k))
    {ιL πL κL : ℕ → Type} [∀ k, Fintype (ιL k)] [∀ k, Fintype (πL k)] [∀ k, Fintype (κL k)]
    (AlkL : (k : ℕ) → List (QB Lq × Dig) → ιL k ⊕ (πL k ⊕ πL k) → Tup K) (TL : (k : ℕ) → κL k → Tup K)
    (mlkL : (k : ℕ) → List (QB Lq × Dig) → κL k → K)
    """

# rebuild the statement: new binders before hal_slots, each hal_X replaced by its two premises
first_s = hal_text["hal_slots"][0]
out = stmt[:first_s] + NEWBIND
pos = first_s
for h in HAL:
    s, e, t = hal_text[h]
    out += stmt[pos:s] if pos < s else ""
    pre, concl = split_concl(t)
    assert ".Al (Rp.blks.length + 2) (A.runLog G).2" in concl, (h, concl)
    out += f"({NEWNAME[h]}_blk : " + pre[len(h) + 3:] + blk_concl(h) + ")\n    "
    out += f"({NEWNAME[h]}_stg : " + pre[len(h) + 3:] + stg_concl(h) + ")"
    pos = e
out += stmt[pos:]
out = out.replace("theorem og_productionReadyL_epP_exec_blk ", "theorem ra_productionReadyL_epP_exec_alive ", 1)

# the proof
SECVARS = ["Rr", "dR", "hpos", "place", "msg", "msg_place", "pad", "salt", "path", "tagc"]
HE = ("(by have h := rc_uexecP_E Rp Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows "
      "bLogN bndCheck bndOpen) outc outcG P (CinR) h64 hr hon.base 768 G _ _ hv'; rw [OC.runLog_fst] at h; exact h)")
COMMON = ("(U := U) (hbij := hbij) (hs := hs) (hL := hL) (hL64 := hL64) (Lb := Lb) (preA := preA) (preB := preB) "
          "(start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG) (Pk := Pk) (sgeom := sgeom) "
          "(check := check) (paths := paths) (digest := digest) (bRows := bRows) (bLogN := bLogN) "
          "(bndCheck := bndCheck) (bndOpen := bndOpen) (R := Rn) (hv := hv) (cx0 := cx0) (pin := pin) (pout := pout) "
          "(bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ) (hgeo := hgeo) "
          f"(absOf := {ABS}) (n := Rp.blks.length + 2) (lg := (A.runLog G).2) (G := G) "
          "(s := (A.run G).1) (segs := (A.run G).2) (hE := " + HE + ")")
NHYP = {"hal_slots": 3, "hal_R0": 4, "hal_R1": 5, "hal_H0": 6, "hal_H1": 7, "hal_LU": 8}
SXS = {"hal_R0": ("80", "(80 * 451)", "D.r0", "hD.r0"), "hal_R1": ("80", "(80 * 451)", "D.r1", "hD.r1"),
       "hal_H0": ("80", "(80 * 451)", "D.h0", "hD.h0"), "hal_H1": ("80", "(80 * 451)", "D.h1", "hD.h1"),
       "hal_LU": ("D.eL", "(3 * D.eL)", "D.lu", "hD.lu")}


def hal_term(h):
    hs_ = " ".join(f"h{i}" for i in range(1, NHYP[h] + 1))
    app = f"A G hv' hx' {hs_}"
    nm = NEWNAME[h]
    if h == "hal_slots":
        return (f"(hal_slots := fun A G hv' hx' {hs_} => ZK60.ProtocolClassify.ra_hal_sl {COMMON} (hU := hU) "
                f"(hL81 := hL81) (D := D) (hD := hD) (F := Fsl) (hslB := hslB) "
                f"(hterm := {nm}_blk {app}) (hS0 := ({nm}_stg {app}).1) (hS1 := ({nm}_stg {app}).2))")
    em, nd, sx, hsx = SXS[h]
    if h == "hal_LU":
        return (f"(hal_LU := fun A G hv' hx' {hs_} => ZK60.ProtocolClassify.ra_hal_lu {COMMON} (emax := {em}) "
                f"(ND := {nd}) (sxs := {sx}) (hsx := {hsx}) (Alk := AlkL) (T := TL) (mlk := mlkL) "
                f"(hB := {nm}_blk {app}) (hS0 := ({nm}_stg {app}).1) (hS1 := ({nm}_stg {app}).2))")
    return (f"({h} := fun A G hv' hx' {hs_} => ZK60.ProtocolClassify.ra_hal_def {COMMON} (emax := {em}) "
            f"(ND := {nd}) (sxs := {sx}) (hsx := {hsx}) "
            f"(hB := {nm}_blk {app}) (hS0 := ({nm}_stg {app}).1) (hS1 := ({nm}_stg {app}).2))")


args = [f"({n} := {n})" for n in SECVARS]
passed = set(SECVARS)
for n in explicit:
    if n in HAL:
        continue
    args.append(f"({n} := {n})")
    passed.add(n)
for h in HAL:
    args.append(hal_term(h))
    passed.add(h)
missing = [n for n in explicit if n not in passed]
assert not missing, missing

lines = []
cur = "  exact og_productionReadyL_epP_exec_blk"
for a in args:
    if len(cur) + 1 + len(a) > 118:
        lines.append(cur)
        cur = "    " + a
    else:
        cur += " " + a
lines.append(cur)
proof = "\n  by\n" + "\n".join(lines) + "\n"

doc = '''/-- **THE APP'S TOP THEOREM WITH THE SIX REMAINING ALIVE PREMISES DISCHARGED AT THE BLOCKS** (D63 lane L50).
L48's `og_productionReadyL_epP_exec_blk` (stages `2^12`, blocks `2^14`, input `2^8` / rate `1/8` / radius `768`, the
run's own Merkle work, L46's block cover) with `hal_slots`, `hal_R0`, `hal_R1`, `hal_H0`, `hal_H1`, `hal_LU` each
replaced by two premises under the SAME hypotheses (acceptance, outside the run's extraction event, no doomed entrant of
an earlier kind): at the 26 blocks' parts, the block-level fact at the block's reading of the run (every slot's terminal
identity `RaTermAt`; every define draw's polynomial vanishing at the drawn challenges `RaDefAt`; LogUp's helpers
`RaLkAt`), from which the run's transcript carries the aliveness (`ra_blk_acc`, `ra_blk_slots_alive`, `ra_def_blk`,
`ra_lk_blk`); at the two stages' parts, the sub-protocols' aliveness itself. Generated by
results/zk60_lean_l50_20261110/l50_mk_top.py. -/
'''

head = '''/-
D63 lane L50 (2026-11-10), part 6: **the app's top theorem with the six remaining ordered alive premises discharged at
the 26 blocks' parts** (deliverable 4). GENERATED by results/zk60_lean_l50_20261110/l50_mk_top.py from lane L48's
`og_productionReadyL_epP_exec_blk` (RunOpenGeoEP.lean): the same section header and binders; `hal_X` replaced by
`hX_blk` (the blocks' own algebra at their readings of the run) and `hX_stg` (the stages' parts); the proof applies
L48's theorem with `hal_X :=` lane L50's run-level assembly (RunAliveHal.lean).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunOpenGeoEP
import ZK60Formal.RunAliveHal

set_option autoImplicit false
'''

text = head + filehdr + header + doc + out + proof + "\nend RaTop\n\nend ZK60.ProtocolClassify.RunShapeP\n"
open(L + "RunAliveTop.lean", "w").write(text)
print("wrote RunAliveTop.lean:", len(text.splitlines()), "lines;", len(explicit), "explicit binders of L48's theorem;",
      len(args), "named arguments; six hal premises replaced by twelve")
