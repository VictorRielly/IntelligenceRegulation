/-
D63 lane L49 (2026-11-10), sub-agent `look`, part 2: **the R13 block's lookup side, DEFINED, generic in the
configuration** (lane L36's `Alk`, `T`, `mlk` at R13; `hN`, `he`, `hTtab` PROVED at the R13 rung and at every
Shieldstral layer), by lane L47's W16R2 pattern (`BlockLookBase.lean`).

* `dofAR`, **`dofAR_aPl`**: the committed data the `A` cut fixes at any opening geometry (L47-2's `rootOfCut_cutsOf`
  is generic): on every outcome its `A` planes are the real ones;
* `lkTupR`, `lkAtR`: a code lookup's tuple at a point of its domain's cube, read off `A` at `DefR13.aOff c`;
* `expTupR`, `actTupR`: the exp tuple at a `Dom::S` point (`MX` on the point's `Dom::Ht` part) and the ACT tuple at a
  `Dom::F` point (finding L47-4), `sgTupR`;
* **`AlkR13`, `TR13`, `mlkR13`**: the singles (the last `Dom::S` lookup, the exp and ACT tuples), each pair's first and
  second lookup (`2j`, `2j + 1`), the table `tabTupE exp act nG k` for `k < 3` over `2^14` positions, the multiplicity
  planes `t0 + k`;
* **`hN_rung`, `he_rung`, `hN_shield`, `he_shield`**: `N = 2,064,384` at the rung (bound `35,153,256`) and
  `N = 66,879,488`, `N + 2·|T| ≤ 66,977,792 ≤ 2^26` at Shieldstral (L47-4's estimate, now PROVED);
* `tabTupE_code`, **`hTtab_r13`**: every table entry is a tuple of `CodeTable r13Fams`, given `0 < nG`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13LookLk
import ZK60Formal.BlockR13HostBase
import ZK60Formal.BlockLookEntry
import ZK60Formal.BlockR13JoinTab
import ZK60Formal.BlockAlgLkR13

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl piB)
open ZK60.Exec.Block.Join.W16.Tab (tabTupE)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Exec.Slot.W16R2 (Dom)
open ZK60.Circuit (gP GF tagW tagExp tagAct CodeTable)
open ZK60.Layout

/-! ## The committed data the `A` cut fixes -/

section Dof

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The committed data read off an `A` cut alone**, at an opening geometry `(h, Q, e, rA, rH)`: the `A` matrix
extracted from the cut for the root the cut determines (lane L47's `dofA` at any geometry). -/
noncomputable def dofAR (tag : MTag) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14) (h Q e rA rH : ℕ)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (absOf : QB L → Option (List UInt8)) {β : Type} (A : OC (QB L) Dig (β × Core)) (cut : List (QB L × Dig)) :
    CmData K P :=
  dXof tag hL20 P hlc h Q e rA rH rE QE XE (cut, [], []) (W16.Look.rootOfCut absOf A cut, none, none)

/-- **On every outcome, the `A` planes of the cut's data are the real ones** (finding L47-2, at any geometry). -/
theorem dofAR_aPl (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (tag : MTag) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14)
    (h Q e rA rH : ℕ) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (A : OC (QB L) Dig (List Op × Core)) (G : QB L → Dig) (off log : ℕ) (b : Fin log → Bool) :
    aPl U P (dofAR tag hL20 P hlc h Q e rA rH rE QE XE (absOfC (chainEncB key domain hs L hL)) A
        (cutsOf key domain hs hL A G).1) off log b
      = aPl U P (dXof tag hL20 P hlc h Q e rA rH rE QE XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) off
          log b := by
  unfold dofAR
  rw [W16.Look.rootOfCut_cutsOf key domain hs hL A G]
  rfl

end Dof

/-! ## The looked-up tuples -/

section Tuples

variable {K : Type} [Field K] [Algebra GF K] (U : K) (c : W16Cfg) (P : BlockParams) (D : CmData K P)

/-- **A code lookup's tuple at a cube point**: `(Σ coef·plane + cst, TAG(width), 0, 0)`, the planes read off `A` at
`DefR13.aOff c` (`lookups`, `logup_subterms`). -/
noncomputable def lkTupR (log : ℕ) (l : LkW) (b : Fin log → Bool) : Tup K :=
  ⟨(l.terms.map fun t => (t.2 : K) * aPl U P D (DefR13.aOff c t.1) log b).sum + (l.cst : K), ((tagW l.tag : ℕ) : K),
    0, 0⟩

/-- Lookup `i` of a domain at a point of the domain's cube. -/
noncomputable def lkAtR (d : Dm) (i : ℕ) (b : Fin (d.log c) → Bool) : Tup K :=
  lkTupR U c P D (d.log c) ((DefR13.lookups c d.dom).getD i ⟨[], 0, 0⟩) b

variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) {ls : ℕ} (G : GeoR c ls)

/-- **The exp tuple** at a point of `Dom::S` (`szc`, slot_ir_accuracy.rs:396): `(MX − mask·(S8 + 127) + 127, TAG_EXP,
E, 0)`, `MX` read at the point's `Dom::Ht` part `(g ++ j) ++ t`. -/
noncomputable def expTupR (b : Fin (c.sh.logs .S) → Bool) : Tup K :=
  ⟨aPl U P D (DefR13.aOff c 4) (nHt c) (Fin.append (Fin.append (splitS c (castB G.logS b)).1.1
        (splitS c (castB G.logS b)).1.2) (splitS c (castB G.logS b)).2.1)
      - algebraMap GF K (B.mask (splitS c (castB G.logS b))) * aPl U P D (DefR13.aOff c 75) (c.sh.logs .S) b
      + (-127 : K) * algebraMap GF K (B.mask (splitS c (castB G.logS b))) + 127,
    ((tagExp : ℕ) : K), aPl U P D (DefR13.aOff c 80) (c.sh.logs .S) b, 0⟩

/-- **The ACT tuple** at a point of `Dom::F` (`fzc`, slot_ir_accuracy.rs:233): `(G + 2048, TAG_ACT, A, group)`. -/
noncomputable def actTupR (b : Fin (c.sh.logs .F) → Bool) : Tup K :=
  ⟨aPl U P D (DefR13.aOff c (86 + 2 * ls)) (c.sh.logs .F) b + 2048, ((tagAct : ℕ) : K),
    aPl U P D (DefR13.aOff c (86 + 2 * ls + 4)) (c.sh.logs .F) b,
    algebraMap GF K (B.grpCol (splitF c (castB G.logF b)))⟩

/-- **A single lookup's tuple**: `Dom::S`'s last lookup (`2·(6 + ls)`), the exp tuple, the ACT tuple. -/
noncomputable def sgTupR : (s : Sg) → (Fin (s.log c) → Bool) → Tup K
  | .S, b => lkAtR U c P D .S (2 * Dm.np ls .S) b
  | .Exp, b => expTupR U c P D Pb Lay B G b
  | .Act, b => actTupR U c P D Pb Lay B G b

end Tuples

/-! ## Lane L36's `Alk`, `T`, `mlk` at R13 -/

section Lk

variable {K : Type} [Field K] [Algebra GF K] (U : K) (c : W16Cfg) (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) {ls : ℕ} (G : GeoR c ls)

/-- **The lookup list** (lane L36's `Alk`), read off the committed data `Dof cut` the `A` cut fixes: the singles, then
each pair's first and second lookup. -/
noncomputable def AlkR13 (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) :
    SgIx c ⊕ (PrIx c ls ⊕ PrIx c ls) → Tup K
  | .inl ⟨s, b⟩ => sgTupR U c P (Dof cut) Pb Lay B G s b
  | .inr (.inl ⟨d, j, b⟩) => lkAtR U c P (Dof cut) d (2 * (j : ℕ)) b
  | .inr (.inr ⟨d, j, b⟩) => lkAtR U c P (Dof cut) d (2 * (j : ℕ) + 1) b

/-- **The multiplicities** (lane L36's `mlk`): `SC_TAB`'s multiplicity planes `MU8`, `MEXP`, `MACT` (`A` planes
`t0 + k`), read off the committed data the `A` cut fixes. -/
noncomputable def mlkR13 (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) : TbIx → K :=
  fun j => R13T.multTabR U c P (Dof cut) j.1 j.2

end Lk

/-- **The table** (lane L36's `T`): column `k < 3` (bytes, exp, ACT) at position `i`, as `SC_TAB`'s public value column
folds it (`restR13`). -/
noncomputable def TR13 {K : Type} [Field K] [Algebra GF K] (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) : TbIx → Tup K :=
  fun j => tupK (tabTupE exp act nG j.1 (msbIndex 14 j.2))

/-! ## The counts: `hN`, `he` -/

section Counts

variable {K : Type} [Field K] [Algebra GF K]

/-- **`hN` at the R13 rung**: `2,064,384 < p`. -/
theorem hN_rung : Fintype.card (SgIx DefR13.cfgRungR13) + 2 * Fintype.card (PrIx DefR13.cfgRungR13 2) < ringChar K := by
  rw [ZK60.Exec.ringChar_eq_gP, lkN_rung]
  unfold gP
  norm_num

/-- **`hN` at a Shieldstral layer**: `66,879,488 < p`. -/
theorem hN_shield (Ly : ZK60.RunShape.Shield.ShieldLayer) :
    Fintype.card (SgIx (DefR13.cfgShieldR13 Ly)) + 2 * Fintype.card (PrIx (DefR13.cfgShieldR13 Ly) 1) < ringChar K := by
  rw [ZK60.Exec.ringChar_eq_gP, lkN_shield]
  unfold gP
  norm_num

omit [Field K] [Algebra GF K] in
/-- **`he` at the R13 rung**: at most `2,064,384 + 2·49,152 = 2,162,688 ≤ 35,153,256`. -/
theorem he_rung [DecidableEq K] (T : TbIx → Tup K) :
    Fintype.card (SgIx DefR13.cfgRungR13) + 2 * Fintype.card (PrIx DefR13.cfgRungR13 2)
      + 2 * (Finset.univ.image T).card ≤ 35153256 := by
  have h := Finset.card_image_le (s := (Finset.univ : Finset TbIx)) (f := T)
  rw [Finset.card_univ, card_tbIx] at h
  rw [lkN_rung]
  omega

omit [Field K] [Algebra GF K] in
/-- **`he` at a Shieldstral layer**: at most `66,879,488 + 2·49,152 = 66,977,792 ≤ 2^26 = 67,108,864` (margin
`131,072`; finding L47-4's estimate, PROVED). -/
theorem he_shield [DecidableEq K] (Ly : ZK60.RunShape.Shield.ShieldLayer) (T : TbIx → Tup K) :
    Fintype.card (SgIx (DefR13.cfgShieldR13 Ly)) + 2 * Fintype.card (PrIx (DefR13.cfgShieldR13 Ly) 1)
      + 2 * (Finset.univ.image T).card ≤ 2 ^ 26 := by
  have h := Finset.card_image_le (s := (Finset.univ : Finset TbIx)) (f := T)
  rw [Finset.card_univ, card_tbIx] at h
  rw [lkN_shield, show (2 : ℕ) ^ 26 = 67108864 by norm_num]
  omega

end Counts

/-! ## `hTtab` -/

/-- **Every entry of R13's three table columns is a tuple of the R13 table** (`CodeTable r13Fams exp act nG`), given
one ACT group at least (the ACT column's padding rows are group `0`'s row at `2048`, finding L47-3). -/
theorem tabTupE_code (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (hnG : 0 < nG) (k : ℕ) (hk : k < 3) (i : ℕ) :
    CodeTable ZK60.Layout.R13.r13Fams exp act nG (tabTupE exp act nG k i) := by
  unfold tabTupE
  by_cases h0 : k = 0
  · rw [ite_eq_left h0]
    refine Or.inl ⟨(tagW 8, 8), List.mem_singleton.mpr rfl, ((i % 256 : ℕ) : ℤ), by positivity, ?_, ?_⟩
    · have := Nat.mod_lt i (show 0 < 256 by norm_num)
      show ((i % 256 : ℕ) : ℤ) < 2 ^ 8
      omega
    · simp only [ZK60.Circuit.rangeTup, Int.cast_natCast]
  rw [ite_eq_right h0]
  by_cases h1 : k = 1
  · rw [ite_eq_left h1]
    refine Or.inr (Or.inl ⟨((i % 256 : ℕ) : ℤ), by positivity, ?_, ?_⟩)
    · have := Nat.mod_lt i (show 0 < 256 by norm_num)
      omega
    · simp only [Int.cast_natCast]
  rw [ite_eq_right h1]
  have h2 : k = 2 := by omega
  rw [ite_eq_left h2]
  by_cases hi : i < nG * 4096
  · rw [ite_eq_left hi]
    refine Or.inr (Or.inr ⟨i / 4096, (Nat.div_lt_iff_lt_mul (by norm_num)).mpr hi, ((i % 4096 : ℕ) : ℤ),
      by positivity, ?_, ?_⟩)
    · have := Nat.mod_lt i (show 0 < 4096 by norm_num)
      omega
    · simp only [Int.cast_natCast]
  · rw [ite_eq_right hi]
    exact Or.inr (Or.inr ⟨0, hnG, ((2048 : ℕ) : ℤ), by norm_num, by norm_num, by simp only [Int.cast_natCast]⟩)

/-- **`hTtab` at R13**: every entry of the table enumeration `TR13` is (the image of) a tuple of the block's table,
given `0 < nG` (the Shieldstral layers have 3 or 4 ACT groups; the code refuses fewer than one, accuracy_act.rs:15). -/
theorem hTtab_r13 {K : Type} [Field K] [Algebra GF K] {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (hnG : 0 < S.nG) :
    ∀ j : TbIx, ∃ t0, CodeTable ZK60.Layout.R13.r13Fams Pb.exp Pb.act S.nG t0 ∧ TR13 (K := K) Pb.exp Pb.act S.nG j
      = tupK t0 :=
  fun j => ⟨_, tabTupE_code Pb.exp Pb.act S.nG hnG j.1 j.1.isLt (msbIndex 14 j.2), rfl⟩

/-- **Every Shieldstral layer has an ACT group** (3 or 4, from the export): `hTtab`'s `0 < nG` at every layer. -/
theorem hnG_shield : ∀ Ly ∈ ZK60.RunShape.Shield.shieldExport, 0 < (ZK60.RunShape.Shield.shieldShape Ly).nG := by
  decide +kernel

/-- **`hTtab` at a Shieldstral layer**, with no premise. -/
theorem hTtab_shield {K : Type} [Field K] [Algebra GF K] (Ly : ZK60.RunShape.Shield.ShieldLayer)
    (hLy : Ly ∈ ZK60.RunShape.Shield.shieldExport) (Pb : ZK60.Block.BlockPublic (ZK60.RunShape.Shield.shieldShape Ly)) :
    ∀ j : TbIx, ∃ t0, CodeTable ZK60.Layout.R13.r13Fams Pb.exp Pb.act (ZK60.RunShape.Shield.shieldShape Ly).nG t0
      ∧ TR13 (K := K) Pb.exp Pb.act (ZK60.RunShape.Shield.shieldShape Ly).nG j = tupK t0 :=
  hTtab_r13 Pb (hnG_shield Ly hLy)

end ZK60.Exec.Block.Join.R13H.Look
