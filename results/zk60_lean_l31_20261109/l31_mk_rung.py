#!/usr/bin/env python3
"""D63 lane L31 (2026-11-09): write formal/ZK60Formal/BlockInstRung.lean.

The two theorems of that file are L28's `block_knowledge_open_w16r2` and `block_knowledge_open_r13` with the premises
of L28 §3 items 1 to 6 removed (the profile, the fields, `hcnt`, `hRd`, the reading definitions, `hrows`, `hk`, `hkF`).
Their statements are L28's, transformed here line by line, so that no premise is retyped by hand:
  * the three schedule equations become `IsRungW16 P tag rowsOf` / `IsRungR13 P tag rowsOf` and `define`'s commitment
    schedule `DefCm P aC hC` for ANY per-slot split `aC`, `hC` with the profile's totals (the receipts' claim counts);
  * `pr : OProf P` becomes the run's header numbers `hdrLen ≤ 2^19`, `hdrSq ≤ 2^63` (the profile is built from them);
  * `csX`, `msX` become the reading definitions (`Link.csRungW16` / `Link.csRungR13`, `Link.msRung`) with the endpoint
    commitments' semantics `csE` a parameter;
  * the lines from "-- the openings at" to `hms` are dropped.

usage: python3 -I l31_mk_rung.py <formal/ZK60Formal dir>
"""
import re
import sys


def statement(src, fname, thm):
    lines = open(f"{src}/{fname}").read().split("\n")
    start = next(i for i, l in enumerate(lines) if l.startswith(f"theorem {thm} "))
    end = next(i for i in range(start, len(lines)) if lines[i].rstrip().endswith("≤ εsTarget q + εend := by"))
    return lines[start:end + 1]


def wrap(l):
    """Break a statement line longer than 120 characters at spaces (continuation lines indented two more)."""
    if len(l) <= 120:
        return [l]
    ind = len(l) - len(l.lstrip()) + 2
    res = []
    while len(l) > 120:
        cut = l.rfind(" ", 0, 119)
        res.append(l[:cut])
        l = " " * ind + l[cut + 1:]
    return res + [l]


def transform_raw(st, old, new, isname, acnt, hcnt, cs):
    out = []
    skip = False
    for l in st:
        if l.strip().startswith("-- the openings at"):
            skip = True
        if skip:
            if l.strip().startswith("(hms :"):
                skip = False
            continue
        if l.strip().startswith("(hdr : P.draws ="):
            out.append(f"    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.{isname} P tag rowsOf)")
            out.append("    (aC hC : List ℕ) (hdc : Link.DefCm P aC hC)")
            out.append(f"    (hsA : sumFrom (fun k => aC.getD k 0) 0 23 = {acnt})"
                       f" (hsH : sumFrom (fun k => hC.getD k 0) 0 23 + 1 = {hcnt})")
            continue
        if l.strip().startswith("(pr : Link.OProf P)"):
            out.append("    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)")
            continue
        if l.strip().startswith("(csX : Cuts3 L"):
            out.append("    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)")
            continue
        l = l.replace(f"theorem {old} ", f"theorem {new} ")
        l = l.replace("pr.hdrLen", "hdrLen").replace("pr.hdrSq", "hdrSq")
        l = re.sub(r"\bcsX\b", f"(Link.{cs} U tag hL20 csE)", l)
        l = re.sub(r"\bmsX\b", "(Link.msRung U tag hL20)", l)
        out.append(l)
    assert not skip
    return out


def transform(st, old, new, isname, acnt, hcnt, cs):
    return [w for l in transform_raw(st, old, new, isname, acnt, hcnt, cs) for w in wrap(l)]


HEADER = '''/-
D63 lane L31 (2026-11-09), part 3: **one rung block's knowledge statement with L28's bookkeeping premises discharged**
(L28 §3 items 1 to 6), at the W16R2 rung and at the R13 rung.

`block_knowledge_open_w16r2` / `_r13` (L28) take a profile `pr : OProf P`, the opening fields, the claims' counts
`hcnt`, a reader `accRd` with `hRd`, the reading equations `hcsA`, `hcsH`, `hms`, and `hrows`, `hk`, `hkF`. Here:

* the profile is `Link.profW16Rung` / `Link.profR13Rung` (`BlockInstProf.lean`), built from the run's header numbers;
* `P` is a block verifier of the profile (`Link.IsRungW16` / `Link.IsRungR13`: its schedule, group counts, functional
  count and opening fields);
* `hcnt` is `Link.hcnt_of_defCm`, from `define`'s commitment schedule `Link.DefCm`;
* the reader is `tAccRd` and `hRd` is `accRd_slotTrace` (`BlockInstRead.lean`);
* `csX`, `msX` are the reading definitions `Link.csRungW16` / `Link.csRungR13`, `Link.msRung`, the endpoint
  commitments' semantics `csE` a parameter of the run.

* **`block_knowledge_rung_w16r2`**, **`block_knowledge_rung_r13`**: for EVERY `q`,
  `Pr[BlockAcc ∧ sqN header = hdrSq ∧ ¬BlockSat] ≤ εsTarget q + εend`.

What they still take: the profile's definition (`IsRung…`), `define`'s commitment schedule (`DefCm`), the run-level
endpoint term `hEnd`, and L23's premises (the slot polynomials over the extracted data and the per-outcome algebra).

The statements are generated from L28's (results/zk60_lean_l31_20261109/l31_mk_rung.py). Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockInstProf

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

section Rung

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]
'''

DOC_W = '''/-- **One W16R2 rung block's knowledge error on the real run, with L28's bookkeeping premises discharged** (D63 lane
L31). For a W16R2 rung block verifier `P` (`Link.IsRungW16`) whose `define` has the rung's commitment schedule
(`Link.DefCm`), a run header of `hdrLen ≤ 2^19` operations and `hdrSq ≤ 2^63` squeezes, the reading definitions
`Link.csRungW16`, `Link.msRung`, and L23's remaining premises: the block verifier accepts on a header of `hdrSq`
squeezes while the extracted planes do not satisfy `BlockSat` with probability at most `εsTarget q + εend`. -/'''

DOC_R = '''/-- **One R13 rung block's knowledge error on the real run, with L28's bookkeeping premises discharged** (D63 lane
L31). As `block_knowledge_rung_w16r2`, for an R13 rung block verifier (`Link.IsRungR13`), R13's opening geometry and
the reading definitions `Link.csRungR13`, `Link.msRung`. -/'''


def proof(open_thm, prof, facts, mid, rA, rH, nA, nH, sums_a, sums_h, cs, acnt, hcnt):
    return f'''  have hlen23 : P.geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hd1 : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 := by
    intro k hk
    rw [hlen23] at hk
    have h1 := ({facts} k hk).1
    simp only [slotShape, hP.hsl]
    exact h1
  exact {open_thm} U hU hK2 key domain hs hL hL64 hL20 P hP.hdr hP.hsl hP.htm
    (Link.{prof} P hP.hdr hP.hsl hP.hag hP.hhg tag hdrLen hdrSq hh hq) hh F
    (Link.{cs} U tag hL20 csE) (Link.msRung U tag hL20) hpolyC hEval hdeg {mid} xtE q A hA rfl rowsOf
    hP.hPm hP.hPp hP.hrA hP.hrH
    ⟨by show 8 * {rA} ≤ L; omega, by show 8 * {rH} ≤ L; omega, by show 8 * (2 * 23 + 4) ≤ L; omega⟩
    (by rw [hP.hnf]; norm_num) (by rw [hP.hnf]; norm_num)
    (fun G bga rs acc hacc => Link.hcnt_of_defCm P hdrLen key domain aC hC {nA} {nH} 23 hlen23 hsA hsH hdc G (A.run G)
      bga rs acc hacc.1)
    (tAccRd P hdrLen)
    (fun G bga rs acc hacc _ => by
      rw [accRd_slotTrace P hdrLen key domain hd1 G (A.run G) bga rs acc hacc.1]
      exact ⟨rfl, rfl, rfl⟩)
    (fun _ _ _ => rfl) (fun _ _ _ => rfl) (fun _ _ _ => rfl) εend hEnd spR hdgR hvR hgdR HGd spH hdgH hvH hgdH Alk T
    mlk hN he hbr hhr
'''


def main(src):
    w = transform(statement(src, "LinkW16GlueW16T.lean", "block_knowledge_open_w16r2"), "block_knowledge_open_w16r2",
                  "block_knowledge_rung_w16r2", "IsRungW16", "114", "47", "csRungW16")
    r = transform(statement(src, "LinkW16GlueR13.lean", "block_knowledge_open_r13"), "block_knowledge_open_r13",
                  "block_knowledge_rung_r13", "IsRungR13", "148", "55", "csRungR13")
    body = [HEADER, DOC_W] + w + [proof("block_knowledge_open_w16r2", "profW16Rung", "W16R2.rung_slot_facts",
                                        "Pb Lay B fams hF hW h24", 320, 202, 114, 47, "Link.cnt_sums.1",
                                        "Link.cnt_sums.2.1", "csRungW16", "aCntW16Rung", "hCntW16Rung"), DOC_R] + r + [
        proof("block_knowledge_open_r13", "profR13Rung", "R13.rung_slot_facts", "Pb Lay B hW13 h24", 437, 248, 148, 55,
              "Link.cnt_sums.2.2.1", "Link.cnt_sums.2.2.2.1", "csRungR13", "aCntR13Rung", "hCntR13Rung"), "end Rung\n", "end ZK60.Exec.Block"]
    open(f"{src}/BlockInstRung.lean", "w").write("\n".join(body) + "\n")
    print("wrote BlockInstRung.lean:", sum(len(x.split("\n")) for x in body), "lines")


if __name__ == "__main__":
    main(sys.argv[1])
