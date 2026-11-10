#!/usr/bin/env python3
"""D63 lane L31 (2026-11-09): write formal/ZK60Formal/BlockInstChainN.lean and formal/ZK60Formal/BlockInstFinal.lean.

Finding L31-1: L16's `SlotEval` cannot be met at a real block. `SlotPolyInstEval.lean` states the interface with the
run's facts (`SlotEvalN`) and proves L16's terminal theorem for it (`blockSlots_terminalN`). The block theorems above
it only pass `hEval` down to that theorem, so their proofs hold word for word for `SlotEvalN`.

BlockInstChainN.lean: the chain from the terminal theorem to the block statements, re-proved for `SlotEvalN`. Each
theorem is the existing one's statement and proof with `SlotEval` replaced by `SlotEvalN` and the theorem it cites
replaced by its `N` twin (the substitutions are listed in CHAIN below; nothing else is changed):
  blockWinT_blockWinN (written here), block_terminal_knowledge_posN (L20), block_knowledge_acc_RN,
  block_knowledge_target_RN (L28), block_knowledge_open_w16r2N, block_knowledge_open_r13N (L28),
  block_knowledge_open_r13_shieldN (this lane's BlockInstShield.lean).

BlockInstFinal.lean: the three block statements with L28's bookkeeping premises discharged (as l31_mk_rung.py) AND
the masked slot polynomial built: `F` is `maskedF` of a table side `Poly`, so `hEval` and `hdeg` become premises on
`Poly` alone.

usage: python3 -I l31_mk_chain.py <formal/ZK60Formal dir> <path of l31_mk_rung.py>
"""
import importlib.util
import re
import sys

sys.dont_write_bytecode = True
src, rung_py = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("l31_mk_rung_lib", rung_py)
rung = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rung)


def theorem_text(fname, thm, stop):
    """The lines of `theorem thm` up to (not including) the first later line that starts with `stop`."""
    lines = open(f"{src}/{fname}").read().split("\n")
    start = next(i for i, l in enumerate(lines) if l.startswith(f"theorem {thm} "))
    end = next(i for i in range(start, len(lines)) if lines[i].startswith(stop))
    return "\n".join(lines[start:end]).rstrip() + "\n"


def sub(text, pairs):
    for a, b in pairs:
        assert re.search(a, text), a
        text = re.sub(a, b, text)
    return text


EVAL = (r"\bSlotEval\b", "SlotEvalN")
CHAIN = [
    ("CountW16Slots.lean", "block_terminal_knowledge_pos", "end SchedPos",
     [(r"\bblock_terminal_knowledge_pos\b", "block_terminal_knowledge_posN"), EVAL,
      (r"\bblockWinT_blockWin\b", "blockWinT_blockWinN")]),
    ("LinkW16Glue.lean", "block_knowledge_acc_R", "end Acc",
     [(r"\bblock_knowledge_acc_R\b", "block_knowledge_acc_RN"), EVAL,
      (r"\bblock_terminal_knowledge_pos\b", "block_terminal_knowledge_posN")]),
    ("LinkW16Glue.lean", "block_knowledge_target_R", "end Target",
     [(r"\bblock_knowledge_target_R\b", "block_knowledge_target_RN"), EVAL,
      (r"\bblock_knowledge_acc_R\b", "block_knowledge_acc_RN")]),
]
OPEN = [
    ("LinkW16GlueW16T.lean", "block_knowledge_open_w16r2", "end Open"),
    ("LinkW16GlueR13.lean", "block_knowledge_open_r13", "end Open"),
    ("BlockInstShield.lean", "block_knowledge_open_r13_shield", "/-- **One Shieldstral T128 R13 block's knowledge error on the real run, with"),
]

HEAD_CHAIN = '''/-
D63 lane L31 (2026-11-09), part 7: **the block statements for the evaluation interface with the run's facts**
(finding L31-1).

L16's `SlotEval` cannot be met at a real block: it asks its identity for every `rhoFull` extending the slot's point,
of any length. `SlotEvalN` (`SlotPolyInstEval.lean`) asks it at the sumcheck's own `n + e` canonical challenges, and
`blockSlots_terminalN` is L16's terminal theorem for it. The block theorems above only pass `hEval` down to the
terminal theorem, so each holds for `SlotEvalN` with its proof unchanged. This file re-proves that chain:

* `blockWinT_blockWinN`: `BlockWinT` is L9's `BlockWin` (L16's `blockWinT_blockWin`);
* `block_terminal_knowledge_posN`: the slots' per-position bound (L20's `block_terminal_knowledge_pos`);
* `block_knowledge_acc_RN`, **`block_knowledge_target_RN`**: the block statement on `BlockAcc ∧ R` (L28's);
* **`block_knowledge_open_w16r2N`**, **`block_knowledge_open_r13N`**, **`block_knowledge_open_r13_shieldN`**: L28's
  block statements (and this lane's at the Shieldstral schedule) with `hEval : SlotEvalN`.

Every statement and proof but the first is generated from the existing theorem by replacing `SlotEval` with
`SlotEvalN` and the cited theorem with its twin (results/zk60_lean_l31_20261109/l31_mk_chain.py). Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotPolyInstEval
import ZK60Formal.BlockInstShield

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

section ChainN

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The claims' truth discharges the terminal premise, for `SlotEvalN`** (L16's `blockWinT_blockWin`): `BlockWinT`
is L9's `BlockWin`. The slots' acceptance supplies the run's facts `SlotEvalN` asks (`blockSlots_terminalN`). -/
theorem blockWinT_blockWinN (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (P : BlockParams) (hdrLen : ℕ) (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (cs : Cm → ZClaim → K) (ms : List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : SlotEvalN U P cs ms f) (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2)
    (G : QB L → Dig) (out : List Op × Core) (h : BlockWinT U key domain P hdrLen f cs ms G out) :
    BlockWin U key domain L P hdrLen f G out := by
  obtain ⟨bga, rs, acc, ⟨h1, h2, h3, h4, t', hacc⟩, hcl, hm, hfalse⟩ := h
  refine ⟨h1, h2, h3, h4, bga, rs, acc, t', hacc, ?_, hfalse⟩
  exact blockSlots_terminalN U hU _ P _ _ bga rs acc t' hacc h3 h4.1 hgeom cs ms hcl hm hpolyC
    (blockSlots_fin_canon _ P _ _ bga rs acc t' hacc h3 h4 hgeom) f hEval
'''

DOCS = {
    "block_terminal_knowledge_pos": "/-- **The block's slots with the claims' and `M`'s truth, per position, for `SlotEvalN`** (L20's\n`block_terminal_knowledge_pos`, its proof unchanged). -/",
    "block_knowledge_acc_R": "/-- **The block's knowledge statement on `BlockAcc ∧ R`, for `SlotEvalN`** (L28's `block_knowledge_acc_R`, its proof\nunchanged). -/",
    "block_knowledge_target_R": "/-- **One block's knowledge error on `BlockAcc ∧ R` is at most the approved target plus the endpoint term, for\n`SlotEvalN`** (L28's `block_knowledge_target_R`, its proof unchanged). -/",
    "block_knowledge_open_w16r2": "/-- **L28's `block_knowledge_open_w16r2` with `hEval : SlotEvalN`** (its proof unchanged). -/",
    "block_knowledge_open_r13": "/-- **L28's `block_knowledge_open_r13` with `hEval : SlotEvalN`** (its proof unchanged). -/",
    "block_knowledge_open_r13_shield": "/-- **`block_knowledge_open_r13_shield` with `hEval : SlotEvalN`** (its proof unchanged). -/",
}

VARS = '''variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]
'''

parts = [HEAD_CHAIN]
for fname, thm, stop, pairs in CHAIN:
    parts.append(DOCS[thm] + "\n" + sub(theorem_text(fname, thm, stop), pairs))
parts.append("end ChainN\n\nsection OpenN\n\n" + VARS)
open_stmts = {}
for fname, thm, stop in OPEN:
    text = theorem_text(fname, thm, stop)
    open_stmts[thm] = text
    parts.append(DOCS[thm] + "\n" + sub(text, [(rf"\b{thm}\b", thm + "N"), EVAL,
                                               (r"\bblock_knowledge_target_R\b", "block_knowledge_target_RN")]))
parts.append("end OpenN\n\nend ZK60.Exec.Block")
open(f"{src}/BlockInstChainN.lean", "w").write("\n".join(parts) + "\n")
print("wrote BlockInstChainN.lean:", sum(len(x.split("\n")) for x in parts), "lines")

# ---------------------------------------------------------------------------------------------------------------------

HEAD_FINAL = '''/-
D63 lane L31 (2026-11-09), part 8: **the block's statement at the three profiles, with every premise this lane
discharges gone**: L28's bookkeeping premises (the profile, the fields, `hcnt`, `hRd`, the reading definitions; as
`BlockInstRung.lean`), the corrected evaluation interface (`SlotEvalN`, finding L31-1), and the mask half of the slot
polynomials (`F` is `maskedF` of a table side `Poly`, `SlotPolyInstEval.lean`).

* `maskedFX`: the masked slot polynomial over the mask table extracted for the statement's `M` root;
* `w16r2_rung_mask_facts`, `r13_rung_mask_facts`, `r13_shield_mask_facts`: every slot has a degree in `[1, 5]`, at
  least one variable, and its `(n + e)·d + 2` mask coefficients fit a mask row of 512;
* **`block_knowledge_final_w16r2`**, **`block_knowledge_final_r13`**, **`block_knowledge_final_r13_shield`**: for EVERY
  `q`, `Pr[BlockAcc ∧ sqN header = hdrSq ∧ ¬BlockSat] ≤ εsTarget q + εend`, at the W16R2 rung, the R13 rung and the
  Shieldstral T128 R13 block (the media app's classifier block).

**The premises that are left**, by name:
* the profile's definition: `hP : Link.IsRungW16 / IsRungR13 / IsShieldR13 P tag rowsOf` (the schedule, the group
  counts, the functional count, the opening fields);
* `define`'s commitment schedule `hdc : Link.DefCm P aC hC`, for any per-slot split `aC`, `hC` with the profile's totals
  `hsA`, `hsH` (`Link.aCntW16Rung` … with `Link.cnt_sums` are the splits the layouts give); and `hpolyC` (its
  polynomials return canonical words; `hpolyC_of_ir` for an IR-defined `define`);
* the table side `Poly` of the slot polynomials: `hPoly` (`SlotEvalN` with the zero `M` semantics: at an accepting
  slot whose claims are true, `Poly(ρ) = poly(vals)`) and `hdegP` (its individual degree is the slot's);
* the run level: the header's numbers `hh`, `hq`, the endpoint commitments' semantics `csE` and `hEnd`;
* public data: `Pb`, `Lay`, `B` (with `fams`, `hF`, `hW` at W16R2; `hW13` at R13), `h24`;
* L23's per-outcome algebra over the extracted planes `xtE`: the certified slot polynomials `spR`, `spH` with `hdgR`,
  `hdgH`; `hvR`, `hgdR`, `hvH`, `hgdH`; the lookup list `Alk`, `T`, `mlk` with `hN`, `he`, `hbr`, `hhr`.

The statements are generated from L28's (results/zk60_lean_l31_20261109/l31_mk_chain.py). Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockInstChainN
import ZK60Formal.BlockInstRung

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-- **The masked slot polynomial over the mask table extracted for the statement's `M` root** (23 mask specs): `F` of
the block statements, from a table side `Poly`. -/
noncomputable abbrev maskedFX {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {L : ℕ} (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) :
    Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K :=
  fun cu rt => maskedF U (Link.mRowX U 23 (Link.colsC tag L (Link.le64_of_le20 hL20) cu.2.1 rt.2.1)) P (Poly cu rt)

/-- The W16R2 rung's slots: degree at least `1`, at least one variable, the mask coefficients within a row of 512. -/
theorem w16r2_rung_mask_facts : ∀ k, k < 23 → 1 ≤ (W16R2.rungSlots.getD k (0, 0, 0)).2.2
    ∧ 0 < (W16R2.rungSlots.getD k (0, 0, 0)).1 + (W16R2.rungSlots.getD k (0, 0, 0)).2.1
    ∧ ((W16R2.rungSlots.getD k (0, 0, 0)).1 + (W16R2.rungSlots.getD k (0, 0, 0)).2.1)
        * (W16R2.rungSlots.getD k (0, 0, 0)).2.2 + 2 ≤ 512 := by
  decide

/-- The R13 rung's slots, likewise. -/
theorem r13_rung_mask_facts : ∀ k, k < 23 → 1 ≤ (R13.rungSlots.getD k (0, 0, 0)).2.2
    ∧ 0 < (R13.rungSlots.getD k (0, 0, 0)).1 + (R13.rungSlots.getD k (0, 0, 0)).2.1
    ∧ ((R13.rungSlots.getD k (0, 0, 0)).1 + (R13.rungSlots.getD k (0, 0, 0)).2.1)
        * (R13.rungSlots.getD k (0, 0, 0)).2.2 + 2 ≤ 512 := by
  decide

/-- The Shieldstral T128 R13 block's slots, likewise (at most `22·5 + 2 = 112` coefficients). -/
theorem r13_shield_mask_facts : ∀ k, k < 23 → 1 ≤ (R13.shieldSlots.getD k (0, 0, 0)).2.2
    ∧ 0 < (R13.shieldSlots.getD k (0, 0, 0)).1 + (R13.shieldSlots.getD k (0, 0, 0)).2.1
    ∧ ((R13.shieldSlots.getD k (0, 0, 0)).1 + (R13.shieldSlots.getD k (0, 0, 0)).2.1)
        * (R13.shieldSlots.getD k (0, 0, 0)).2.2 + 2 ≤ 512 := by
  decide

section Final

''' + VARS


def final_stmt(st, old, new, isname, acnt, hcnt, cs):
    out = []
    for l in rung.transform_raw(st, old, new, isname, acnt, hcnt, cs):
        s = l.strip()
        if s.startswith("(F : Cuts3 L"):
            out.append("    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)")
            continue
        if s.startswith("(hEval : "):
            out.append(f"    (hPoly : ∀ cu rt, SlotEvalN U P (Link.{cs} U tag hL20 csE cu rt) (fun _ => 0) (Poly cu rt))")
            continue
        if s.startswith("(hdeg : "):
            out.append("    (hdegP : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (Poly cu rt k sn))")
            continue
        out.append(re.sub(r"\bF\b", "(maskedFX U tag hL20 P Poly)", l))
    return [w for l in out for w in rung.wrap(l)]


def final_proof(open_thm, prof, facts, mid, rA, rH, nA, nH, sums_a, sums_h, cs, acnt, hcnt):
    return f'''  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hlen23 : P.geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hfacts : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2
      ∧ 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ 512 := by
    intro k hk
    rw [hlen23] at hk
    have h1 := {facts} k hk
    simp only [slotShape, hP.hsl]
    exact h1
  have hd1 : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 := fun k hk => (hfacts k hk).1
  exact {open_thm} U hU hK2 key domain hs hL hL64 hL20 P hP.hdr hP.hsl hP.htm
    (Link.{prof} P hP.hdr hP.hsl hP.hag hP.hhg tag hdrLen hdrSq hh hq) hh (maskedFX U tag hL20 P Poly)
    (Link.{cs} U tag hL20 csE) (Link.msRung U tag hL20) hpolyC
    (fun cu rt => maskedF_slotEvalN U hU hbij P _ _ _ 512 (Link.msXof_mlin U tag L (Link.le64_of_le20 hL20) 23 cu rt)
      (fun k hk => (hfacts k hk).2) (Poly cu rt) (hPoly cu rt))
    (fun cu rt k sn => maskedF_indDeg_all U _ P (Poly cu rt) hd1 (hdegP cu rt) k sn)
    {mid} xtE q A hA rfl rowsOf hP.hPm hP.hPp hP.hrA hP.hrH
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


def stmt_of(thm):
    st = open_stmts[thm].split("\n")
    send = next(i for i, l in enumerate(st) if l.rstrip().endswith("≤ εsTarget q + εend := by"))
    return st[:send + 1]


FINALS = [
    ("block_knowledge_open_w16r2", "block_knowledge_final_w16r2", "IsRungW16", "114", "47", "csRungW16",
     "profW16Rung", "w16r2_rung_mask_facts", "Pb Lay B fams hF hW h24", 320, 202, 114, 47, "Link.cnt_sums.1",
     "Link.cnt_sums.2.1",
     "/-- **One W16R2 rung block's knowledge statement, with this lane's premises discharged** (D63 lane L31): L28's\nbookkeeping premises, the corrected evaluation interface and the mask half of the slot polynomials. The premises left\nare listed in this file's header. -/"),
    ("block_knowledge_open_r13", "block_knowledge_final_r13", "IsRungR13", "148", "55", "csRungR13",
     "profR13Rung", "r13_rung_mask_facts", "Pb Lay B hW13 h24", 437, 248, 148, 55, "Link.cnt_sums.2.2.1",
     "Link.cnt_sums.2.2.2.1",
     "/-- **One R13 rung block's knowledge statement, with this lane's premises discharged** (as\n`block_knowledge_final_w16r2`, at R13). -/"),
    ("block_knowledge_open_r13_shield", "block_knowledge_final_r13_shield", "IsShieldR13", "146",
     "54", "csShieldR13", "profR13Shield", "r13_shield_mask_facts", "Pb Lay B hW13 h24", 4577, 4390, 146, 54,
     "Link.cnt_sums.2.2.2.2.1", "Link.cnt_sums.2.2.2.2.2",
     "/-- **One Shieldstral T128 R13 block's knowledge statement, with this lane's premises discharged** (the media app's\nclassifier block; as `block_knowledge_final_r13`, at the Shieldstral schedule). -/"),
]
body = [HEAD_FINAL]
for (thm, new, isname, acnt, hcnt, cs, prof, facts, mid, rA, rH, nA, nH, sa, sh, doc) in FINALS:
    body.append(doc)
    body += final_stmt(stmt_of(thm), thm, new, isname, acnt, hcnt, cs)
    body.append(final_proof(thm + "N", prof, facts, mid, rA, rH, nA, nH, sa, sh, cs, acnt, hcnt))
body.append("end Final\n\nend ZK60.Exec.Block")
open(f"{src}/BlockInstFinal.lean", "w").write("\n".join(body) + "\n")
print("wrote BlockInstFinal.lean:", sum(len(x.split("\n")) for x in body), "lines")
