#!/usr/bin/env python3
"""D63 lane L36 (2026-11-09): write formal/ZK60Formal/BlockAlgLk26.lean, the repair of finding L36-1.

Finding L36-1: every block statement since L21 takes `he : card ι + 2·card π + 2·|T| ≤ 35,153,256` (the 8B T128 W16R2
block's lookup count). The Shieldstral T128 R13 block looks up 64,258,048 tuples over its padded cubes
(`lkCount_r13_shield`), so `he` cannot be met at the app's block with the code's lookup list. The run-level chain
already charges LogUp at `e ≤ 2^26` (L24's `lk_main_le_u126_r13`: `50,331,700` units). This script re-states the
Shieldstral block chain at that bound. Each theorem is the existing one's statement and proof with ONLY these changes
(listed per theorem in CHAIN below; nothing else is changed):
  * the lookup bound `35153256` -> `2 ^ 26` in `he`;
  * LogUp's constant `26370000` -> `50331700` in the budget (the target theorem's `hbud` and the open theorem's);
  * the cited theorems -> their `26` twins (`lk_pos_le_u126` -> `lk_pos_le_u126_26`, `block_knowledge_target_RN` ->
    `block_knowledge_target_RN26`, `shield_budget_r13` -> `shield_budget_r13_26`, ...).
The chain: block_knowledge_target_RN (L31, BlockInstChainN.lean) -> block_knowledge_open_r13_shieldN (L31) ->
block_knowledge_final_r13_shield (L31, BlockInstFinal.lean) -> block_knowledge_alg_r13_shield (L36, BlockAlgFinal.lean)
-> block_knowledge_alg_r13_shield_spec (L36, BlockAlgR13.lean). The numbers (`lk_main_le_u126_26`, a copy of L24's
`lk_main_le_u126_r13` in this namespace; `lk_pos_le_u126_26`; `shield_budget_r13_26`) are written by hand below.

usage: python3 -I l36_mk_lk26.py <formal/ZK60Formal dir>
"""
import re
import sys
import textwrap

src = sys.argv[1]


def theorem_text(fname, thm, stop):
    """The lines of `theorem thm` up to (not including) the first later line that starts with `stop`."""
    lines = open(f"{src}/{fname}").read().split("\n")
    start = next(i for i, l in enumerate(lines) if l.startswith(f"theorem {thm} "))
    end = next(i for i in range(start + 1, len(lines)) if lines[i].startswith(stop))
    return "\n".join(lines[start:end]).rstrip() + "\n"


def sub(text, pairs):
    for a, b, n in pairs:
        found = len(re.findall(a, text))
        assert found == n, (a, found, n)
        text = re.sub(a, b, text)
    return text


HE = (r"≤ 35153256\)", "≤ 2 ^ 26)", 1)
CHAIN = [
    ("BlockInstChainN.lean", "block_knowledge_target_RN", "end ChainN", "Chain26",
     "**`block_knowledge_target_RN` at LogUp's bound `e ≤ 2^26`** (finding L36-1; its proof unchanged but for the "
     "LogUp term `lk_pos_le_u126_26`).",
     [(r"\bblock_knowledge_target_RN\b", "block_knowledge_target_RN26", 1), HE,
      (r"\b26370000\b", "50331700", 2), (r"\blk_pos_le_u126\b", "lk_pos_le_u126_26", 1)]),
    ("BlockInstChainN.lean", "block_knowledge_open_r13_shieldN", "end OpenN", "Open26",
     "**`block_knowledge_open_r13_shieldN` at LogUp's bound `e ≤ 2^26`** (finding L36-1; its proof unchanged but for "
     "the budget `shield_budget_r13_26` and `block_knowledge_target_RN26`).",
     [(r"\bblock_knowledge_open_r13_shieldN\b", "block_knowledge_open_r13_shieldN26", 1), HE,
      (r"\b26370000\b", "50331700", 1), (r"\bshield_budget_r13\b", "shield_budget_r13_26", 1),
      (r"\bblock_knowledge_target_RN\b", "block_knowledge_target_RN26", 1)]),
    ("BlockInstFinal.lean", "block_knowledge_final_r13_shield", "end Final", "Open26",
     "**`block_knowledge_final_r13_shield` at LogUp's bound `e ≤ 2^26`** (finding L36-1; its proof unchanged but for "
     "`block_knowledge_open_r13_shieldN26`).",
     [(r"\bblock_knowledge_final_r13_shield\b", "block_knowledge_final_r13_shield26", 1), HE,
      (r"\bblock_knowledge_open_r13_shieldN\b", "block_knowledge_open_r13_shieldN26", 1)]),
    ("BlockAlgFinal.lean", "block_knowledge_alg_r13_shield", "end Final", "Open26",
     "**One Shieldstral T128 R13 block's knowledge statement with the relation layers' algebra discharged, at LogUp's "
     "bound `e ≤ 2^26`** (the media app's classifier block; `block_knowledge_alg_r13_shield` with the lookup bound the "
     "block's lookup list can meet: `64,258,048 ≤ 2^26`, finding L36-1).",
     [(r"\bblock_knowledge_alg_r13_shield\b", "block_knowledge_alg_r13_shield26", 1), HE,
      (r"\bblock_knowledge_final_r13_shield\b", "block_knowledge_final_r13_shield26", 1)]),
    ("BlockAlgR13.lean", "block_knowledge_alg_r13_shield_spec", "end Final", "Spec26",
     "**The Shieldstral T128 R13 block's statement with the reindexing included, at LogUp's bound `e ≤ 2^26`** "
     "(`block_knowledge_alg_r13_shield_spec` with finding L36-1 repaired).",
     [(r"\bblock_knowledge_alg_r13_shield_spec\b", "block_knowledge_alg_r13_shield_spec26", 1), HE,
      (r"\bblock_knowledge_alg_r13_shield\b", "block_knowledge_alg_r13_shield26", 1)]),
]

HEAD = '''/-
D63 lane L36 (2026-11-09), part 5b: **the Shieldstral T128 R13 block's statement at LogUp's bound `e ≤ 2^26`** (the
repair of finding L36-1).

Every block statement since L21 takes the lookup bound `he : card ι + 2·card π + 2·|T| ≤ 35,153,256`, the 8B T128
W16R2 block's count. The Shieldstral T128 R13 block (the media app's classifier block) looks up `64,258,048` tuples
over its padded cubes (`lkCount_r13_shield`, `BlockAlgShapes.lean`), so `he` cannot be met there with the code's lookup
list. The run-level chain already charges LogUp at `e ≤ 2^26` (L24's `lk_main_le_u126_r13`, `50,331,700` units). This
file re-states the Shieldstral block chain at that bound:

* `lk_main_le_u126_26` (L24's `lk_main_le_u126_r13`, copied into this namespace), `lk_pos_le_u126_26`: LogUp's term
  per position for `e ≤ 2^26`: `(q + 1)·(50,331,700 + 2^15)/2^126`;
* `shield_budget_r13_26`, `shield_budget_r13_26_val`: the block's budget with that term, `54,314,754 ≤ 2^26`;
* `block_knowledge_target_RN26`, `block_knowledge_open_r13_shieldN26`, `block_knowledge_final_r13_shield26`,
  **`block_knowledge_alg_r13_shield26`**, **`block_knowledge_alg_r13_shield_spec26`**: the chain with `he ≤ 2^26`
  (the block's lookups, `64,258,048`, are within it: `lkCount_r13_shield_gt`).

Generated by results/zk60_lean_l36_20261109/l36_mk_lk26.py from the existing theorems (statement and proof), with only
the bound, LogUp's constant and the cited theorems' names changed. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockAlgR13

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The numbers at `e ≤ 2^26` -/

/-- **LogUp's first term, per position, at `e = N + 2M ≤ 2^26`** (L24's `lk_main_le_u126_r13`, its proof, in this
namespace): `(q·e + 3·e)/p²·(1 + p/2^128)² ≤ (q + 1)·50,331,700/2^126`. -/
theorem lk_main_le_u126_26 (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q e : ℕ) (he : e ≤ 2 ^ 26) :
    ((q * e + 3 * e : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ u126 q 50331700 := by
  have hp0 : p ≠ 0 := by omega
  rw [bias_frac, natFrac_mul _ _ _ _ (pow_ne_zero 2 hp0)]
  unfold u126
  refine natFrac_le (mul_ne_zero (pow_ne_zero 2 hp0) (by positivity)) (by positivity) ?_
  have h1 : q * e + 3 * e ≤ 3 * (q + 1) * 2 ^ 26 := by
    calc q * e + 3 * e = (q + 3) * e := by ring
      _ ≤ (q + 3) * 2 ^ 26 := Nat.mul_le_mul_left _ he
      _ ≤ 3 * (q + 1) * 2 ^ 26 := Nat.mul_le_mul_right _ (by omega)
  calc (q * e + 3 * e) * ((2 ^ 128 + p) * (2 ^ 128 + p)) * 2 ^ 126
      ≤ (3 * (q + 1) * 2 ^ 26) * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 126 := by gcongr
    _ = (q + 1) * (3 * 2 ^ 26 * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 126) := by ring
    _ ≤ (q + 1) * (50331700 * ((2 ^ 64 - 2 ^ 32) ^ 2 * (2 ^ 128 * 2 ^ 128))) := Nat.mul_le_mul_left _ (by norm_num)
    _ ≤ (q + 1) * (50331700 * (p ^ 2 * (2 ^ 128 * 2 ^ 128))) := by gcongr
    _ = (q + 1) * 50331700 * (p ^ 2 * (2 ^ 128 * 2 ^ 128)) := by ring

/-- **LogUp's whole term, per position, at `e ≤ 2^26`**: at most `(q + 1)·(50,331,700 + 2^15)/2^126` for a chain of
at most `2^20` items and `q < 2^100` (L21's `lk_pos_le_u126` at the larger bound). -/
theorem lk_pos_le_u126_26 (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q : ℕ) (hq : q < 2 ^ 100)
    (ℓ : ℕ) (hℓ : ℓ ≤ 2 ^ 20) (e : ℕ) (he : e ≤ 2 ^ 26) :
    ((q * e + 3 * e : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig ≤ u126 q (50331700 + 2 ^ 14 + 2 ^ 14) := by
  calc _ ≤ u126 q 50331700 + u126 q (2 ^ 14) + u126 q (2 ^ 14) :=
        add_le_add (add_le_add (lk_main_le_u126_26 p hp1 hp2 q e he) (coll_le_u126 q _ hq (by omega)))
          (coll_le_u126 q _ hq (by omega))
    _ = _ := by rw [u126_add, u126_add]

/-- **The Shieldstral T128 R13 block's budget with LogUp at `e ≤ 2^26`** (`shield_budget_r13` with LogUp's constant
`50,331,700`): within `2^26`. -/
theorem shield_budget_r13_26 :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 110) + 2 ^ (126 - 126)) + 2 ^ 18 + 2 ^ 16 + 5 + 1159
        + 4 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (50331700 + 2 ^ 14 + 2 ^ 14))
      ≤ 2 ^ 26 := by
  norm_num

/-- The budget's value: `54,314,754` units of `2^-126` per query, against `2^26 = 67,108,864`. -/
theorem shield_budget_r13_26_val :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 110) + 2 ^ (126 - 126)) + 2 ^ 18 + 2 ^ 16 + 5 + 1159
        + 4 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (50331700 + 2 ^ 14 + 2 ^ 14))
      = 54314754 ∧ 54314754 ≤ 2 ^ 26 := by
  constructor <;> norm_num

'''

SECTIONS = {
    "Chain26": '''section Chain26

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
''',
    "Open26": '''section Open26

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]
''',
    "Spec26": '''section Spec26

open ZK60.Exec.Slot.W16R2 (segLn)

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]
''',
}

out = [HEAD]
cur = None
for fname, thm, stop, sec, doc, pairs in CHAIN:
    if sec != cur:
        if cur is not None:
            out.append(f"end {cur}\n\n")
        out.append(SECTIONS[sec] + "\n")
        cur = sec
    body = sub(theorem_text(fname, thm, stop), pairs)
    out.append(textwrap.fill(f"/-- {doc} -/", width=118, break_long_words=False, break_on_hyphens=False) + "\n"
               + body + "\n")
out.append(f"end {cur}\n\nend ZK60.Exec.Block\n")
open(f"{src}/BlockAlgLk26.lean", "w").write("".join(out))
print("wrote", f"{src}/BlockAlgLk26.lean")
