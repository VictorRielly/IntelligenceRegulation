/-
D63 step L13, part 4: **the W16R2 layout facts the slot builders read, as Lean functions of the precision**, and the
layout facts `blockSat_of_slots` assumes, PROVED at every W16 precision (so at the 8B and Shieldstral W16R2 profiles,
whatever their trained calibration).

Ported (read 2026-11-07; nothing changed), under `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`:
* `accuracy_layout.rs::new_w16` (113-185, the non-DD branch): the `A` plane list, its words and limb groups in plane
  order (`aPlanes`), and `lookups_w16` (289-344): every lookup of a domain (`lookupsW`);
* `range16.rs`: `limbs_of`, `rem_lookups`, `word16`, `word24`, `direct`, `widths`, `families`, `full`;
* `layout.rs::HIds::new` (622-654): the helper planes (`hIds`); `pad.rs::a_rule` / `zero_rule_a_planes` (294-392): the
  zero-rule planes (`zeroPlanes`);
* `accuracy_aligned.rs::derive_aligned_for` (25-29): the product fold's shift by stack (`foldShift`), and
  `accuracy_layout.rs:324`: the product remainder's lookup width (`rhWidth`).
`SlotW16BuildCheck.lean` compares every one of these with the code's at the rung, Shieldstral T128 and 8B T128 shapes
(`lean_l13_export_tests.rs`), and builds every slot's tables and IR from them.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* **`rhWidth_eq_foldShift`** (finding L11-1's latent hazard, checked): at both stacks the product remainder's lookup
  width is the product fold's shift (`16` at LowH24, the stack of both W16R2 profiles; `24` at Low), so the literal
  at accuracy_layout.rs:324 is safe today;
* **`famsOK_famsOf`**: the LogUp family list of a W16 precision (`U8` and the range widths) has distinct tags below
  `p`, distinct from `TAG_EXP` and `TAG_ACT` (CircuitRopeAct's `FamsOK`);
* **`w16Widths_of`**: for every block shape whose shifts are a W16 precision's (`S.sprod` the fold's shift), the widths
  `blockSat_of_slots` needs are families of that list (`W16Widths`): the premise of the layout theorem, discharged for
  every W16R2 shape, without evaluating any table;
* **`stdLayout`**: the code's layout map is a `W16Layout` at every shape (axes padded by `Fin.castLE`, the head-slot
  order C-1 `h ↦ (h / hpg, h % hpg)` injective, the RoPE flip of the head dimension's top bit).
-/
import ZK60Formal.SlotW16R2
import ZK60Formal.LayoutW16

namespace ZK60.Exec.Slot.Build.Lay

open ZK60.Exec.Slot.W16R2 (Dom)

/-! ## The precision -/

/-- **A W16 shape's derived precision and constants** (`accuracy_precision::derive`, the shape's norm constants, its
gate shift and softmax window, `SH_ROPE`, the product fold's shift). -/
structure PrecW where
  h24 : Bool
  tn : ℕ
  cnA : ℤ
  cnM : ℤ
  ceps : ℤ
  q : ℕ
  k : ℕ
  v : ℕ
  score : ℕ
  pv : ℕ
  ao : ℕ
  gate : ℕ
  up : ℕ
  prodbits : ℕ
  down : ℕ
  fp : ℕ
  wrho : ℕ
  rope : ℕ
  fold : ℕ

/-- `derive_aligned_for`'s product shift: `16` at LowH24, `24` at Low. -/
def foldShift (h24 : Bool) : ℕ := if h24 then 16 else 24

/-- The product remainder's lookup width (accuracy_layout.rs:324 and range16.rs:187): `16` at LowH24, `24` at Low. -/
def rhWidth (h24 : Bool) : ℕ := if h24 then 16 else 24

/-- **L11-1, checked**: the literal width is the fold's shift at both stacks. -/
theorem rhWidth_eq_foldShift (h24 : Bool) : rhWidth h24 = foldShift h24 := by cases h24 <;> rfl

/-- `range16::limbs_of`. -/
def limbsOf (b : ℕ) : ℕ := if b ≤ 16 then 1 else 2

/-! ## The range widths and families (`range16::widths`, `families`) -/

/-- `rem`'s pushes: `b` below 17 bits, else `16` and `b − 16`. -/
def remW (b : ℕ) : List ℕ := if b ≤ 16 then [b] else [16, b - 16]

/-- The widths pushed, in the code's order, before the byte width is dropped and the list sorted. -/
def widthsRaw (p : PrecW) : List ℕ :=
  [16] ++ remW 24 ++ remW p.ao ++ remW p.down ++ remW p.q ++ remW p.rope ++ remW p.pv ++ remW p.k ++ remW p.v
    ++ remW p.rope ++ remW p.gate ++ remW p.up ++ remW (rhWidth p.h24) ++ remW p.score ++ remW (p.fp + 1)
    ++ remW p.wrho

/-- **`range16::widths`**: the byte width dropped, sorted, deduplicated. -/
def widthsW (p : PrecW) : List ℕ := (((widthsRaw p).filter (· ≠ 8)).dedup).mergeSort (· ≤ ·)

/-- `range16::families`: `(width, sub)` with `sub = max(1, 2^width >> log_cols)`. -/
def famsW (ws : List ℕ) (logCols : ℕ) : List (ℕ × ℕ) := ws.map fun w => (w, max 1 (2 ^ w / 2 ^ logCols))

/-- `range16::full`: every entry of the family's sub-planes is a true row. -/
def fullW (w logCols : ℕ) : Bool := decide (logCols ≤ w)

/-- **The block's LogUp family list** (`CircuitRopeAct.CodeTable`'s `fams`): `U8` and the range widths. -/
def famsOf (ws : List ℕ) : List (ℕ × ℕ) := (8 :: ws).map fun w => (ZK60.Circuit.tagW w, w)

theorem mem_famsOf (ws : List ℕ) (b : ℕ) : (ZK60.Circuit.tagW b, b) ∈ famsOf ws ↔ b = 8 ∨ b ∈ ws := by
  unfold famsOf
  rw [List.mem_map]
  constructor
  · rintro ⟨w, hw, he⟩
    rw [Prod.mk.injEq] at he
    rw [← he.2]
    exact List.mem_cons.mp hw
  · intro h
    exact ⟨b, List.mem_cons.mpr h, rfl⟩

theorem mem_widthsW (p : PrecW) (b : ℕ) : b ∈ widthsW p ↔ b ∈ widthsRaw p ∧ b ≠ 8 := by
  unfold widthsW
  rw [List.mem_mergeSort, List.mem_dedup, List.mem_filter]
  simp

theorem mem_remW_self (b : ℕ) (hb : b ≤ 16) : b ∈ remW b := by simp [remW, hb]

theorem mem_remW_hi (b : ℕ) (hb : 16 < b) : b - 16 ∈ remW b := by
  simp [remW, show ¬ b ≤ 16 by omega]

/-- A width the precision `rem`s is a family (or the byte family), and so is its top limb's above 16 bits. -/
theorem fam_of_rem (p : PrecW) (b : ℕ) (hb : ∀ x ∈ remW b, x ∈ widthsRaw p) :
    ((ZK60.Circuit.tagW b, b) ∈ famsOf (widthsW p) ∨ 16 < b) ∧
      (16 < b → (ZK60.Circuit.tagW (b - 16), b - 16) ∈ famsOf (widthsW p)) := by
  refine ⟨?_, fun h => ?_⟩
  · by_cases h : b ≤ 16
    · refine Or.inl ((mem_famsOf _ _).mpr ?_)
      by_cases h8 : b = 8
      · exact Or.inl h8
      · exact Or.inr ((mem_widthsW p b).mpr ⟨hb b (mem_remW_self b h), h8⟩)
    · exact Or.inr (by omega)
  · refine (mem_famsOf _ _).mpr ?_
    by_cases h8 : b - 16 = 8
    · exact Or.inl h8
    · exact Or.inr ((mem_widthsW p _).mpr ⟨hb _ (mem_remW_hi b h), h8⟩)

/-- **The widths `blockSat_of_slots` needs are families**, at every block shape whose shifts are the precision's
(`S.sprod` the product fold's shift, `f_p + 1 ≤ 16`: the code's `f_p = 12`, accuracy_precision.rs:102). -/
theorem w16Widths_of (p : PrecW) (S : ZK60.Block.BlockShape) (hq : S.sq = p.q) (hk : S.sk = p.k) (hv : S.sv = p.v)
    (hs : S.ss = p.score) (hpv : S.spv = p.pv) (hao : S.sao = p.ao) (hg : S.sgate = p.gate) (hu : S.sup = p.up)
    (hpr : S.sprod = foldShift p.h24) (hd : S.sdown = p.down) (hfp : S.fp = p.fp) (hw : S.wrho = p.wrho)
    (hrope : p.rope = 7) (hfp16 : p.fp + 1 ≤ 16) :
    ZK60.Layout.W16Widths S (famsOf (widthsW p)) := by
  have hrh := rhWidth_eq_foldShift p.h24
  refine ⟨(mem_famsOf _ _).mpr (Or.inl rfl), (mem_famsOf _ _).mpr (Or.inr ((mem_widthsW p 16).mpr ⟨?_, by norm_num⟩)),
    (mem_famsOf _ _).mpr (Or.inr ((mem_widthsW p 7).mpr ⟨?_, by norm_num⟩)), ?_, ?_⟩
  · simp [widthsRaw]
  · simp [widthsRaw, hrope, remW]
  · rw [hfp]
    by_cases h8 : p.fp + 1 = 8
    · exact (mem_famsOf _ _).mpr (Or.inl h8)
    · exact (mem_famsOf _ _).mpr (Or.inr ((mem_widthsW p _).mpr ⟨by simp [widthsRaw, remW, hfp16], h8⟩))
  · intro b hb
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hb
    rcases hb with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
      refine fam_of_rem p _ (fun x hx => ?_) <;> simp_all [widthsRaw]

/-- **The family list is `FamsOK`** (distinct tags below `p`, none `TAG_EXP` or `TAG_ACT`) when every width is at most
24 bits (`limbs_of`'s window). -/
theorem famsOK_famsOf (ws : List ℕ) (hb : ∀ w ∈ ws, w ≤ 24) : ZK60.Circuit.FamsOK (famsOf ws) := by
  have htag : ∀ w : ℕ, ZK60.Circuit.tagW w = if w = 8 then 133 else 200 + w := fun _ => rfl
  have hmem : ∀ f ∈ famsOf ws, ∃ w, w ≤ 24 ∧ f = (ZK60.Circuit.tagW w, w) := by
    intro f hf
    unfold famsOf at hf
    obtain ⟨w, hw, rfl⟩ := List.mem_map.mp hf
    rcases List.mem_cons.mp hw with h | h
    · exact ⟨w, by omega, rfl⟩
    · exact ⟨w, hb w h, rfl⟩
  refine ⟨fun f hf => ?_, fun f hf g hg he => ?_, fun f hf => ?_, fun f hf => ?_⟩
  · obtain ⟨w, hw, rfl⟩ := hmem f hf
    show ZK60.Circuit.tagW w < 18446744069414584321
    rw [htag]
    split <;> omega
  · obtain ⟨w, -, rfl⟩ := hmem f hf
    obtain ⟨w', -, rfl⟩ := hmem g hg
    have : w = w' := by
      simp only [htag] at he
      split_ifs at he <;> omega
    rw [this]
  · obtain ⟨w, -, rfl⟩ := hmem f hf
    show ZK60.Circuit.tagW w ≠ 129
    rw [htag]
    split <;> omega
  · obtain ⟨w, -, rfl⟩ := hmem f hf
    show ZK60.Circuit.tagW w ≠ 134
    rw [htag]
    split <;> omega

/-! ## The layout map of a registered shape (the code's axes) -/

/-- An axis of `n` logical indices padded to `np` (`Fin.castLE`: the logical indices are the first ones, as every
padded axis of the code is laid out, `shape.rs::natural_log`). -/
def axPad {n np : ℕ} (h : n ≤ np) : ZK60.Layout.Ax (Fin n) (Fin np) := ⟨Fin.castLE h, Fin.castLE_injective h⟩

/-- **The code's W16R2 layout map, for every shape**: tokens, width, key-value groups and hidden padded at their axes;
a query head `h`'s slot is `(h / hpg, h % hpg)`, its key-value group's bits on top of its index within the group
(C-1, argument.rs:2192-2230, with the code's grouping `grp h = h / hpg` of consecutive heads); the head dimension is
`(top bit, index)` and the RoPE partner flips the top bit (`Coord::Flip`). -/
def stdLayout (S : ZK60.Block.BlockShape) (Tp dp Gp hpg hp fp : ℕ) (hT : S.T ≤ Tp) (hd : S.d ≤ dp) (hG : S.G ≤ Gp)
    (hh : S.half ≤ hp) (hf : S.f ≤ fp) (hpos : 0 < hpg) (hgrp : ∀ h : Fin S.H, (S.grp h : ℕ) = h / hpg) :
    ZK60.Layout.W16Layout S (Fin Tp) (Fin dp) (Fin Gp) (Fin hpg) (Bool × Fin hp) (Fin fp) where
  tok := axPad hT
  wid := axPad hd
  grp := axPad hG
  within h := ⟨h % hpg, Nat.mod_lt _ hpos⟩
  hd := ⟨fun x => (x.1, Fin.castLE hh x.2), fun x y hxy => by
    simp only [Prod.mk.injEq] at hxy
    exact Prod.ext hxy.1 (Fin.castLE_injective hh hxy.2)⟩
  hid := axPad hf
  slot_inj := by
    intro h₁ h₂ he
    simp only [Prod.mk.injEq] at he
    obtain ⟨hg, hw⟩ := he
    have hg' : (S.grp h₁ : ℕ) = S.grp h₂ := by
      have := congrArg Fin.val hg
      simpa [axPad] using this
    have hw' : (h₁ : ℕ) % hpg = h₂ % hpg := congrArg Fin.val hw
    rw [hgrp, hgrp] at hg'
    apply Fin.ext
    rw [← Nat.div_add_mod (h₁ : ℕ) hpg, ← Nat.div_add_mod (h₂ : ℕ) hpg, hg', hw']
  flip x := (!x.1, x.2)
  hd_flip _ _ := rfl

/-! ## The plane allocation (`AccuracyIds::new_w16`, non-DD) -/

/-- A limb group's planes: its name alone for one plane, `name0 …` for more. -/
def grpN (d : Dom) (name : String) (n : ℕ) : List (Dom × String) :=
  if n = 1 then [(d, name)] else (List.range n).map fun k => (d, name ++ toString k)

/-- **The `A` plane list in plane order**: words and limb groups per domain, then the range sub-planes. -/
def aPlanes (p : PrecW) (fams : List (ℕ × ℕ)) : List (Dom × String) :=
  [(.T, "D"), (.T, "DSQ"), (.T, "DM"), (.T, "DSQM"), (.Ht, "MX"), (.Ht, "SUM"), (.L, "LIMB"), (.L, "LIMBM"),
    (.D, "X"), (.D, "Y")] ++ grpN .D "NR" 2 ++ grpN .D "NS" 2 ++ [(.D, "AO")] ++ grpN .D "RAL" (limbsOf p.ao)
    ++ [(.D, "X1"), (.D, "YM")] ++ grpN .D "MR" 2 ++ grpN .D "MS" 2 ++ [(.D, "Z")] ++ grpN .D "RDL" (limbsOf p.down)
    ++ [(.D, "X2"), (.Q, "Q")] ++ grpN .Q "RQL" (limbsOf p.q) ++ [(.Q, "QR")] ++ grpN .Q "RQRL" (limbsOf p.rope)
    ++ [(.Q, "O")] ++ grpN .Q "RO" (limbsOf p.pv) ++ [(.Kv, "K")] ++ grpN .Kv "RKL" (limbsOf p.k) ++ [(.Kv, "V")]
    ++ grpN .Kv "RVL" (limbsOf p.v) ++ [(.Kv, "KR")] ++ grpN .Kv "RKRL" (limbsOf p.rope) ++ [(.S, "S")]
    ++ grpN .S "RSL" (limbsOf p.score) ++ [(.S, "ZSEL"), (.S, "E"), (.S, "P")] ++ grpN .S "SR" (limbsOf p.wrho)
    ++ grpN .S "SG" (limbsOf p.wrho) ++ [(.F, "G")] ++ grpN .F "RGL" (limbsOf p.gate) ++ [(.F, "A_SCALED"), (.F, "U")]
    ++ grpN .F "RU" (limbsOf p.up) ++ [(.F, "H")] ++ grpN .F "HT" (if p.h24 then 1 else 0)
    ++ grpN .F "RH" (limbsOf (rhWidth p.h24)) ++ [(.Tab, "MU8"), (.Tab, "MEXP"), (.Tab, "MACT")]
    ++ fams.flatMap fun f => (List.range f.2).map fun s => (.Tab, "R" ++ toString f.1 ++ "_" ++ toString s)

/-- A plane's id by name. -/
def pIx (pl : List (Dom × String)) (name : String) : ℕ := pl.findIdx fun e => e.2 == name

/-- A limb group's plane ids. -/
def gIx (pl : List (Dom × String)) (name : String) (n : ℕ) : List ℕ :=
  if n = 1 then [pIx pl name] else (List.range n).map fun k => pIx pl (name ++ toString k)

/-- A domain's planes, in plane order. -/
def domPlanes (pl : List (Dom × String)) (d : Dom) : List ℕ :=
  (List.range pl.length).filter fun i => (pl.getD i (.T, "")).1 == d

/-! ## The lookups (`lookups_w16`) -/

/-- A lookup: its terms `(plane, coef)`, its constant, its family width (`8` is `U8`). -/
structure LkW where
  terms : List (ℕ × ℤ)
  cst : ℤ
  tag : ℕ

/-- `range16::rem_lookups`. -/
def remLks (planes : List ℕ) (bits : ℕ) : List LkW :=
  if bits ≤ 16 then [⟨[(planes.getD 0 0, 1)], 0, bits⟩]
  else [⟨[(planes.getD 0 0, 1)], 0, 16⟩, ⟨[(planes.getD 1 0, 1)], 0, bits - 16⟩]

/-- **The lookups of a domain** (accuracy_layout.rs:297-339), in order. -/
def lookupsW (p : PrecW) (pl : List (Dom × String)) : Dom → List LkW
  | .L => [⟨[(pIx pl "LIMB", 1)], 0, 8⟩, ⟨[(pIx pl "LIMBM", 1)], 0, 8⟩]
  | .D =>
    let w := fun (n : String) => [(⟨[(pIx pl n, 1)], 32768, 16⟩ : LkW)]
    w "X" ++ w "Y" ++ remLks (gIx pl "NR" 2) 24 ++ remLks (gIx pl "NS" 2) 24 ++ w "AO"
      ++ remLks (gIx pl "RAL" (limbsOf p.ao)) p.ao ++ w "X1" ++ w "YM" ++ remLks (gIx pl "MR" 2) 24
      ++ remLks (gIx pl "MS" 2) 24 ++ w "Z" ++ remLks (gIx pl "RDL" (limbsOf p.down)) p.down ++ w "X2"
  | .Q =>
    let w := fun (n : String) => [(⟨[(pIx pl n, 1)], 32768, 16⟩ : LkW)]
    w "Q" ++ remLks (gIx pl "RQL" (limbsOf p.q)) p.q ++ w "QR" ++ remLks (gIx pl "RQRL" (limbsOf p.rope)) p.rope
      ++ w "O" ++ remLks (gIx pl "RO" (limbsOf p.pv)) p.pv
  | .Kv =>
    let w := fun (n : String) => [(⟨[(pIx pl n, 1)], 32768, 16⟩ : LkW)]
    w "K" ++ remLks (gIx pl "RKL" (limbsOf p.k)) p.k ++ w "V" ++ remLks (gIx pl "RVL" (limbsOf p.v)) p.v
      ++ w "KR" ++ remLks (gIx pl "RKRL" (limbsOf p.rope)) p.rope
  | .F =>
    let bias : ℤ := 2 ^ (p.prodbits - 1)
    remLks (gIx pl "RGL" (limbsOf p.gate)) p.gate ++ [⟨[(pIx pl "U", 1)], 32768, 16⟩]
      ++ remLks (gIx pl "RU" (limbsOf p.up)) p.up
      ++ (if p.h24 then [⟨[(pIx pl "H", 1), (pIx pl "HT", -65536)], bias % 65536, 16⟩, ⟨[(pIx pl "HT", 1)], bias / 65536, 8⟩]
          else [⟨[(pIx pl "H", 1)], bias, 16⟩])
      ++ remLks (gIx pl "RH" (limbsOf (rhWidth p.h24))) (rhWidth p.h24)
  | .S =>
    [⟨[(pIx pl "S", 1)], 127, 8⟩, ⟨[(pIx pl "S", -1)], 127, 8⟩] ++ remLks (gIx pl "RSL" (limbsOf p.score)) p.score
      ++ [⟨[(pIx pl "P", 1)], 0, p.fp + 1⟩] ++ remLks (gIx pl "SR" (limbsOf p.wrho)) p.wrho
      ++ remLks (gIx pl "SG" (limbsOf p.wrho)) p.wrho
  | _ => []

/-- `Shape::helpers`: a domain's helpers, one per pair of lookups. -/
def nHelp (p : PrecW) (pl : List (Dom × String)) (d : Dom) : ℕ := ((lookupsW p pl d).length + 1) / 2

/-! ## The helper planes (`HIds::new`) and the zero-rule planes (`pad::zero_rule_a_planes`) -/

/-- `(first_l, first_d, first_q, first_kv, first_s, sexp, first_f, fact, gu8, n_range, u)`. -/
def hIds (p : PrecW) (pl : List (Dom × String)) (nRange : ℕ) : List ℕ :=
  let h := nHelp p pl
  let fd := h .L
  let fq := fd + h .D
  let fkv := fq + h .Q
  let fs := fkv + h .Kv
  let sexp := fs + h .S
  let ff := sexp + 1
  let fact := ff + h .F
  let gu8 := fact + 1
  [0, fd, fq, fkv, fs, sexp, ff, fact, gu8, nRange, gu8 + 3 + nRange]

/-- The `H` planes' domains, in plane order. -/
def hPlanes (p : PrecW) (pl : List (Dom × String)) (nRange : ℕ) : List Dom :=
  let h := nHelp p pl
  List.replicate (h .L) .L ++ List.replicate (h .D) .D ++ List.replicate (h .Q) .Q ++ List.replicate (h .Kv) .Kv
    ++ List.replicate (h .S) .S ++ [.S] ++ List.replicate (h .F) .F ++ [.F] ++ List.replicate (3 + nRange) .Tab ++ [.Tab]

/-- **The zero-rule planes of a domain**: every plane of a padded domain except `E` (exempt: its genuine row) and the
range sub-planes of a FULL family (no padded copy). -/
def zeroPlanes (pl : List (Dom × String)) (fams : List (ℕ × ℕ)) (logCols : ℕ) (padRule : Bool) (pads : Dom → Bool)
    (d : Dom) : List ℕ :=
  if padRule && pads d then
    (domPlanes pl d).filter fun i =>
      let nm := (pl.getD i (.T, "")).2
      !(nm == "E") && !((fams.any fun f => fullW f.1 logCols &&
        ((List.range f.2).any fun s => nm == "R" ++ toString f.1 ++ "_" ++ toString s)))
  else []

end ZK60.Exec.Slot.Build.Lay
