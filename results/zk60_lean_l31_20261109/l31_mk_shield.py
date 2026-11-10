#!/usr/bin/env python3
"""D63 lane L31 (2026-11-09): write formal/ZK60Formal/BlockInstShield.lean.

L28's `block_knowledge_open_r13` is stated at the R13 development rung's schedule. The media app's classifier blocks
run the Shieldstral T128 R13 schedule (L17's `R13.shieldSlots`, `shieldTerms`, `shieldDraws`). This script writes

  * `block_knowledge_open_r13_shield`: L28's theorem and proof, with the rung's schedule facts replaced by the
    Shieldstral block's (the substitutions are listed in SUBS below; nothing else is changed);
  * `block_knowledge_shield_r13`: that theorem with L28's bookkeeping premises discharged, as
    `l31_mk_rung.py` does at the rungs.

usage: python3 -I l31_mk_shield.py <formal/ZK60Formal dir> <path of l31_mk_rung.py>
"""
import importlib.util
import sys

sys.dont_write_bytecode = True
src, rung_py = sys.argv[1], sys.argv[2]

lines = open(f"{src}/LinkW16GlueR13.lean").read().split("\n")
start = next(i for i, l in enumerate(lines) if l.startswith("theorem block_knowledge_open_r13 "))
end = next(i for i in range(start, len(lines)) if lines[i].startswith("end Open"))
thm = "\n".join(lines[start:end]).rstrip() + "\n"

SUBS = [
    ("theorem block_knowledge_open_r13 ", "theorem block_knowledge_open_r13_shield "),
    ("rw [hsl, R13.rungSlots_eq_w16r2]; exact rung_blockND", "rw [hsl]; exact shield_blockND_r13"),
    ("R13.rungDraws", "R13.shieldDraws"),
    ("R13.rungSlots", "R13.shieldSlots"),
    ("R13.rungTerms", "R13.shieldTerms"),
    ("R13.rung_slot_facts", "R13.shield_slot_facts"),
    ("R13.rung_len", "R13.shield_len"),
    ("rung_defLen_r13 P hdr hsl", "shield_defLen_r13 P hdr hsl"),
    ("blockND P.geom.slots = 924", "blockND P.geom.slots = 1159"),
    ("r13_defND_le P hdr", "shield_defND_le_r13 P hdr"),
    ("80 * 375", "80 * 451"),
    ("exact r13_budget 106 110 126 (by norm_num) (by norm_num) (by norm_num)", "exact shield_budget_r13"),
]
for a, b in SUBS:
    assert a in thm, a
    thm = thm.replace(a, b)
assert "rung" not in thm and "375" not in thm and "924" not in thm

spec = importlib.util.spec_from_file_location("l31_mk_rung_lib", rung_py)

HEADER = '''/-
D63 lane L31 (2026-11-09), part 4: **one Shieldstral T128 R13 block's knowledge statement** (the media app's classifier
block), with the openings' premises discharged (L28's proof at the Shieldstral schedule) and then L28's bookkeeping
premises discharged (this lane).

L28's `block_knowledge_open_r13` is stated at the R13 development rung's schedule (375 draws, 296 rounds). The app's
classifier blocks run L17's Shieldstral T128 R13 schedule (`R13.shieldSlots`, `shieldTerms`, `shieldDraws`: 451 draws,
370 rounds, degrees in `[1, 5]`). The proof is L28's with the schedule's facts replaced:

* `shield_defLen_r13` (`defLen = hdrLen + 1,293`), `shield_draws_sum_r13` (451), `shield_defND_le_r13`,
  `shield_blockND_r13` (1,159), `shield_budget_r13` (the block's budget at the proved opening exponents:
  `30,353,054` units, under `2^25`);
* **`block_knowledge_open_r13_shield`**: L28's statement at the Shieldstral schedule (generated from L28's theorem and
  proof, results/zk60_lean_l31_20261109/l31_mk_shield.py);
* **`block_knowledge_shield_r13`**: the same with the profile (`Link.profR13Shield`), the fields, `hcnt`, `hRd` and the
  reading definitions discharged, as `block_knowledge_rung_r13`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockInstProf

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The Shieldstral T128 R13 schedule's numbers -/

/-- **At the Shieldstral T128 R13 block** the verifier's operations up to the end of the slot loop number
`hdrLen + 1293`. -/
theorem shield_defLen_r13 (P : BlockParams) (hdr : P.draws = R13.shieldDraws) (hsl : P.geom.slots = R13.shieldSlots)
    (h : ℕ) : defLen P h = h + 1293 := by
  have e : defOffW R13.shieldDraws R13.shieldSlots 0 R13.shieldSlots.length = 1283 := by decide
  rw [defLen, defOff_eq, hdr, hsl, e]

/-- The Shieldstral T128 R13 block's define draws: `451` in all. -/
theorem shield_draws_sum_r13 : ∑ k ∈ Finset.range 23, R13.shieldDraws k = 451 := by decide

/-- **At the Shieldstral T128 R13 block** a relation layer's draws weigh at most `dd·451`. -/
theorem shield_defND_le_r13 (P : BlockParams) (hdr : P.draws = R13.shieldDraws) (i : ℕ) (hi : i < 4) (dg : ℕ → ℕ)
    (dd : ℕ) (hdg : ∀ k ∈ w16r2RelKs i, dg k ≤ dd) : defND P (w16r2RelKs i) dg ≤ dd * 451 := by
  have h := defND_le P _ dg dd 23 hdg (w16r2RelKs_facts i hi).1 (w16r2RelKs_facts i hi).2
  rw [hdr, shield_draws_sum_r13] at h
  exact h

/-- The Shieldstral T128 R13 schedule's slot numerators: `Σ (n + e)·d = 1159`. -/
theorem shield_blockND_r13 : blockND R13.shieldSlots = 1159 := by decide

/-- **The Shieldstral T128 R13 block's budget at the proved opening exponents** (`M` `2^-106`, `opA` `2^-110`, `opB`
`2^-126`), four relation layers and one helper layer: `30,353,054` units of `2^-126` per query, under `2^26`. -/
theorem shield_budget_r13 :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 110) + 2 ^ (126 - 126)) + 2 ^ 18 + 2 ^ 16 + 5 + 1159
        + 4 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14))
      ≤ 2 ^ 26 := by
  norm_num

theorem shield_budget_r13_val :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 110) + 2 ^ (126 - 126)) + 2 ^ 18 + 2 ^ 16 + 5 + 1159
        + 4 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14))
      = 30353054 ∧ 30353054 ≤ 2 ^ 25 := by
  constructor <;> norm_num

section Shield

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One Shieldstral T128 R13 block's knowledge error on the real run is at most the approved target plus the endpoint
term, for EVERY `q`, with the openings' and `M`'s premises discharged** (L28's `block_knowledge_open_r13` at the media
app's classifier block's schedule; the proof is L28's with the schedule's facts replaced). -/
'''

DOC_S = '''/-- **One Shieldstral T128 R13 block's knowledge error on the real run, with L28's bookkeeping premises discharged**
(D63 lane L31; the media app's classifier block). As `block_knowledge_rung_r13`, for a Shieldstral T128 R13 block
verifier (`Link.IsShieldR13`) and the reading definitions `Link.csShieldR13`, `Link.msRung`. -/'''

rung = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rung)

stmt = thm.split("\n")
send = next(i for i, l in enumerate(stmt) if l.rstrip().endswith("≤ εsTarget q + εend := by"))
w = rung.transform(stmt[:send + 1], "block_knowledge_open_r13_shield", "block_knowledge_shield_r13", "IsShieldR13",
                   "aCntR13Shield", "hCntR13Shield", "csShieldR13")
pf = rung.proof("block_knowledge_open_r13_shield", "profR13Shield", "R13.shield_slot_facts", "Pb Lay B hW13 h24", 4577,
                4390, 146, 54, "Link.cnt_sums.2.2.2.2.1", "Link.cnt_sums.2.2.2.2.2", "csShieldR13", "aCntR13Shield",
                "hCntR13Shield")
body = [HEADER.rstrip("\n"), thm.rstrip("\n"), "", DOC_S] + w + [pf, "end Shield\n", "end ZK60.Exec.Block"]
open(f"{src}/BlockInstShield.lean", "w").write("\n".join(body) + "\n")
print("wrote BlockInstShield.lean:", sum(len(x.split("\n")) for x in body), "lines")
