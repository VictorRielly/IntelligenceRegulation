/-
D63 W16R2 Shieldstral port (`BlockW16U1LookBase.lean`):
**the lookup side at `export_u1` (`W16R2_SHIELD_T128_H24`), DEFINED (`AlkU1`, `TU1`, `mlkU1`),
with `hN_u1`, `he_u1`, `tabTupU1_code`, `hTtab_u1`, and `hTtab_shieldU1` PROVED.**

Mirrors `BlockLookBase.lean` at the A29-uniform `export_u1` configuration `c0 = cfgShieldU1 0 0`:
* `dofAU1`, **`dofAU1_aPl`**: the committed data fixed by the `A` cut alone at opening geometry
  `(15, 280, 8052, 2504, 2606)` (reusing `ocNext`, `rootOfCut`, `rootOfCut_cutsOf` from
  `BlockLookBase.lean`): on every outcome its `A` planes are the real ones;
* `LkDomU1`, `SgKindU1`, **`SgIxU1`, `PrIxU1`, `TbIxU1`**: LogUp's index sets at `export_u1`:
  - domain cube logs `L:14, D:19, Q:19, Kv:17, S:19, F:21`;
  - pair helpers `L:1, D:9, Q:3, Kv:3, S:3, F:3` (`Dom::S` has 7 lookups at `wrho = 16`, 1-limb
    `SR`/`SG`, so 3 pair helpers + 1 single at lookup index 6);
  - single lookups: `D` (lookup 18, helper 10), `S` (lookup 6, helper 20), `F` (lookup 6, helper 25),
    `Exp` (helper 21), `Act` (helper 26);
  - 16 table columns (`u8`, `exp`, `act`, 13 range sub-planes) of `2^14` entries;
* `hd12`, `append_splitS_hd12`, `lkTupU1`, `lkAtU1`, `expTupU1`, `actTupU1`, `sgTupU1`:
  the looked-up tuples read off the committed `A` planes at `offU1` (`aOff c0`);
* **`AlkU1`, `TU1`, `mlkU1`**: `block_knowledge_join_w16r2_shieldU1`'s `Alk`, `T`, `mlk`;
* **`card_sgIxU1`, `card_prIxU1`, `card_tbIxU1`, `hN_u1`, `he_u1`**:
  `N = 5,767,168 + 2·14,565,376 = 34,897,920 < gP`, and
  `N + 2·|T| ≤ 34,897,920 + 2·262,144 = 35,422,208 ≤ 2^26 = 67,108,864`;
* **`tabRangeU1_ok`, `tabTupU1_code`, `hTtab_u1`, `hnG_shieldU1`, `hTtab_shieldU1`**: every table
  entry of `TU1` is a tuple of `CodeTable famsLogUpW16U1 Pb.exp Pb.act nG`, given `0 < nG` (and
  unconditionally for every layer `Ly ∈ shieldExportU1`, where `3 ≤ Ly.nG ≤ 4`).

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1TabBase
import ZK60Formal.BlockLookBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl piB piB_alg alg_piB aPl_base aPl_alg remR)
open ZK60.Exec.Block.Join.W16.Look (ocNext ocNext_runLog rootOfCut rootOfCut_cutsOf)
open ZK60.Exec.Block.Join.W16.Tab (tabSubS supW)
open ZK60.Exec.Block.Join.R13H (splitD splitQ splitK splitHt splitS splitF
  splitD_append splitQ_append splitK_append splitHt_append splitS_append splitF_append
  nD nH nQ nK nS nHt nF)
open ZK60.Exec.Block.Join.W16U1
open ZK60.Exec.Block.Join.W16U1.Tab
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Circuit (gP GF tagW tagExp tagAct CodeTable FamsOK)
open ZK60.RunShape.Shield (ShieldLayer shieldShape)
open ZK60.RunShape.ShieldU1 (shieldExportU1 shieldExportU1_uniform famsLogUpW16U1 famsOK_shieldU1)
open ZK60.Layout

/-! ## 1. The committed data the `A` cut fixes at `export_u1` -/

section Dof

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The committed data read off an `A` cut alone** at `export_u1` (`(15, 280, 8052, 2504, 2606)`):
the `A` matrix extracted from the cut for the root the cut determines (the other commitments empty). -/
noncomputable def dofAU1 (tag : MTag) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (absOf : QB L → Option (List UInt8)) {β : Type} (A : OC (QB L) Dig (β × Core)) (cut : List (QB L × Dig)) :
    CmData K P :=
  dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cut, [], []) (rootOfCut absOf A cut, none, none)

/-- **On every outcome, the `A` planes of the cut's data are the real ones.** -/
theorem dofAU1_aPl (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (tag : MTag) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (A : OC (QB L) Dig (List Op × Core)) (G : QB L → Dig) (off log : ℕ) (b : Fin log → Bool) :
    aPl U P (dofAU1 tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A (cutsOf key domain hs hL A G).1)
        off log b
      = aPl U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G)
          (rootsOf (A.run G).2)) off log b := by
  unfold dofAU1
  rw [rootOfCut_cutsOf key domain hs hL A G]
  rfl

end Dof

/-! ## 2. The index sets at `export_u1` -/

/-- The domains whose lookups are paired by LogUp's helpers at `export_u1`. -/
inductive LkDomU1
  | L | D | Q | Kv | S | F
  deriving DecidableEq

instance : Fintype LkDomU1 :=
  Fintype.ofList [.L, .D, .Q, .Kv, .S, .F] (fun d => by cases d <;> decide)

/-- The code's domain. -/
def LkDomU1.dom : LkDomU1 → ZK60.Exec.Slot.W16R2.Dom
  | .L => .L | .D => .D | .Q => .Q | .Kv => .Kv | .S => .S | .F => .F

/-- The domain's cube bits at `export_u1` (`shShieldW16U1.logs`). -/
def LkDomU1.log : LkDomU1 → ℕ
  | .L => 14 | .D => 19 | .Q => 19 | .Kv => 17 | .S => 19 | .F => 21

/-- The domain's pair helpers at `export_u1` (half its lookup count, rounded down).
At `wrho = 16`, `Dom::S` has 7 lookups (1-limb `sr` and `sg`), so 3 pair helpers + 1 single. -/
def LkDomU1.np : LkDomU1 → ℕ
  | .L => 1 | .D => 9 | .Q => 3 | .Kv => 3 | .S => 3 | .F => 3

/-- The domain's first helper plane at `export_u1` (`hIdsN c0`). -/
def LkDomU1.fh : LkDomU1 → ℕ
  | .L => 0 | .D => 1 | .Q => 11 | .Kv => 14 | .S => 17 | .F => 22

/-- The single lookups at `export_u1`: the odd last lookup of `Dom::D` (18), `Dom::S` (6), `Dom::F` (6),
the exp tuple, and the ACT tuple. -/
inductive SgKindU1
  | D | S | F | Exp | Act
  deriving DecidableEq

instance : Fintype SgKindU1 :=
  Fintype.ofList [.D, .S, .F, .Exp, .Act] (fun s => by cases s <;> decide)

/-- A single lookup's cube bits at `export_u1`. -/
def SgKindU1.log : SgKindU1 → ℕ
  | .D => 19 | .S => 19 | .F => 21 | .Exp => 19 | .Act => 21

/-- A single lookup's helper plane at `export_u1` (`D: 10`, `S: 20`, `Exp: 21`, `F: 25`, `Act: 26`). -/
def SgKindU1.hp : SgKindU1 → ℕ
  | .D => 10 | .S => 20 | .F => 25 | .Exp => 21 | .Act => 26

/-- **The single lookups' positions at `export_u1`.** -/
abbrev SgIxU1 := Σ s : SgKindU1, (Fin s.log → Bool)

/-- **The pairs' positions at `export_u1`.** -/
abbrev PrIxU1 := Σ d : LkDomU1, Fin d.np × (Fin d.log → Bool)

/-- **The table's positions at `export_u1`**: 16 columns of `2^14` entries. -/
abbrev TbIxU1 := Fin 16 × (Fin 14 → Bool)

/-- Every domain's cube log matches `c0.sh.logs`. -/
theorem lkDomU1_log : ∀ d : LkDomU1, d.log = c0.sh.logs d.dom := by
  intro d
  cases d <;> decide

/-- The domain's lookup count is the code's: twice its pairs, plus one where it has a single. -/
theorem lkDomU1_len : ∀ d : LkDomU1, (lookupsN c0 d.dom).length
    = 2 * d.np + (if d = .D ∨ d = .S ∨ d = .F then 1 else 0) := by
  intro d
  cases d <;> decide

/-- Every domain's first helper plane matches the code's `hIdsN c0`. -/
theorem lkDomU1_fh : ∀ d : LkDomU1, d.fh = (hIdsN c0).getD
    (match d with | .L => 0 | .D => 1 | .Q => 2 | .Kv => 3 | .S => 4 | .F => 6) 0 := by
  intro d
  cases d <;> decide

/-- Every single lookup's helper plane matches `hIdsN c0`. -/
theorem sgKindU1_hp : SgKindU1.D.hp = LkDomU1.D.fh + LkDomU1.D.np
    ∧ SgKindU1.S.hp = LkDomU1.S.fh + LkDomU1.S.np
    ∧ SgKindU1.F.hp = LkDomU1.F.fh + LkDomU1.F.np
    ∧ SgKindU1.Exp.hp = (hIdsN c0).getD 5 0
    ∧ SgKindU1.Act.hp = (hIdsN c0).getD 7 0 := by
  decide

theorem sum_sgKindU1 {M : Type} [AddCommMonoid M] (f : SgKindU1 → M) :
    ∑ s, f s = f .D + (f .S + (f .F + (f .Exp + f .Act))) := by
  rw [show (Finset.univ : Finset SgKindU1) = [SgKindU1.D, .S, .F, .Exp, .Act].toFinset from rfl,
    List.sum_toFinset _ (by decide)]
  simp

theorem sum_lkDomU1 {M : Type} [AddCommMonoid M] (f : LkDomU1 → M) :
    ∑ d, f d = f .L + (f .D + (f .Q + (f .Kv + (f .S + f .F)))) := by
  rw [show (Finset.univ : Finset LkDomU1) = [LkDomU1.L, .D, .Q, .Kv, .S, .F].toFinset from rfl,
    List.sum_toFinset _ (by decide)]
  simp

/-! ## 3. The looked-up tuples at `export_u1` -/

/-- The first 12 coordinates of a `Dom::S` bit vector at `export_u1` (`Dom::Ht`'s `(g ++ j) ++ t`). -/
def hd12 (b : Fin 19 → Bool) : Fin 12 → Bool := fun a => b (Fin.castAdd 7 a)

theorem hd12_append (r : Fin 12 → Bool) (j : Fin 7 → Bool) : hd12 (Fin.append r j) = r := by
  funext a
  exact Fin.append_left r j a

theorem append_splitS_hd12 (b : Fin 19 → Bool) :
    Fin.append (Fin.append (splitS c0 b).1.1 (splitS c0 b).1.2) (splitS c0 b).2.1 = hd12 b := by
  funext i
  refine Fin.addCases (fun i5 => ?_) (fun i7 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (fun i3 => ?_) (fun i2 => ?_) i5
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl
  · rw [Fin.append_right]; rfl

section Tuples

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)

/-- **A lookup's tuple at a cube point** at `export_u1`: `(Σ coef·plane + cst, TAG(width), 0, 0)`,
the planes read off `A` at `offU1` (`aOff c0`). -/
noncomputable def lkTupU1 (log : ℕ) (l : LkW) (b : Fin log → Bool) : Tup K :=
  ⟨(l.terms.map fun t => (t.2 : K) * aPl U P D (offU1 t.1) log b).sum + (l.cst : K), ((tagW l.tag : ℕ) : K),
    0, 0⟩

/-- Lookup `i` of a domain at a point of the domain's cube at `export_u1`. -/
noncomputable def lkAtU1 (d : LkDomU1) (i : ℕ) (b : Fin d.log → Bool) : Tup K :=
  lkTupU1 U P D d.log ((lookupsN c0 d.dom).getD i ⟨[], 0, 0⟩) b

variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

/-- **The exp tuple at `export_u1`** at a point of `Dom::S` (`szc_w16`):
`(MX − mask·(S8 + 127) + 127, TAG_EXP, E, 0)`, `MX` (`offU1 4`) read on the point's first 12 bits (`Dom::Ht`),
`S8` at `offU1 39`, `E` at `offU1 43`. -/
noncomputable def expTupU1 (b : Fin 19 → Bool) : Tup K :=
  ⟨aPl U P D (offU1 4) 12 (hd12 b) - algebraMap GF K (B.mask (splitS c0 b)) * aPl U P D (offU1 39) 19 b
      + (-127 : K) * algebraMap GF K (B.mask (splitS c0 b)) + 127,
    ((tagExp : ℕ) : K), aPl U P D (offU1 43) 19 b, 0⟩

/-- **The ACT tuple at `export_u1`** at a point of `Dom::F` (`fzc_w16`):
`(G + 2048, TAG_ACT, A, group)`, `G` at `offU1 47`, `A` at `offU1 50`. -/
noncomputable def actTupU1 (b : Fin 21 → Bool) : Tup K :=
  ⟨aPl U P D (offU1 47) 21 b + 2048, ((tagAct : ℕ) : K), aPl U P D (offU1 50) 21 b,
    algebraMap GF K (B.grpCol (splitF c0 b))⟩

/-- **A single lookup's tuple at `export_u1`**: `Dom::D` lookup 18 (`X2`), `Dom::S` lookup 6 (`sg[0]`),
`Dom::F` lookup 6 (`rh[0]`), the exp tuple, and the ACT tuple. -/
noncomputable def sgTupU1 : (s : SgKindU1) → (Fin s.log → Bool) → Tup K
  | .D, b => lkAtU1 U P D .D 18 b
  | .S, b => lkAtU1 U P D .S 6 b
  | .F, b => lkAtU1 U P D .F 6 b
  | .Exp, b => expTupU1 U P D Pb Lay B b
  | .Act, b => actTupU1 U P D Pb Lay B b

end Tuples

/-! ## 4. `AlkU1`, `TU1`, `mlkU1` -/

section Lk

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

/-- **The lookup list at `export_u1`** (`block_knowledge_join_w16r2_shieldU1`'s `Alk`), read off the
committed data `Dof cut` the `A` cut fixes: the singles, then each pair's first and second lookup. -/
noncomputable def AlkU1 (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) :
    SgIxU1 ⊕ (PrIxU1 ⊕ PrIxU1) → Tup K
  | .inl ⟨s, b⟩ => sgTupU1 U P (Dof cut) Pb Lay B s b
  | .inr (.inl ⟨d, j, b⟩) => lkAtU1 U P (Dof cut) d (2 * (j : ℕ)) b
  | .inr (.inr ⟨d, j, b⟩) => lkAtU1 U P (Dof cut) d (2 * (j : ℕ) + 1) b

/-- **The table at `export_u1`** (`block_knowledge_join_w16r2_shieldU1`'s `T`): column `k < 16`'s
tuple at its position, as `SC_TAB`'s public value column folds it. -/
noncomputable def TU1 (nG : ℕ) : TbIxU1 → Tup K := fun j => tupK (tabTupU1 Pb nG j.1 (msbIndex 14 j.2))

/-- **The multiplicities at `export_u1`** (`block_knowledge_join_w16r2_shieldU1`'s `mlk`): `SC_TAB`'s
16 multiplicity planes (`56 + k`), read off the committed data the `A` cut fixes. -/
noncomputable def mlkU1 (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) : TbIxU1 → K :=
  fun j => multTabU1 U P (Dof cut) j.1 j.2

end Lk

/-! ## 5. Cardinalities and bounds (`hN_u1`, `he_u1`) -/

/-- `2^19 + 2^19 + 2^21 + 2^19 + 2^21 = 5,767,168` single lookups at `export_u1`. -/
theorem card_sgIxU1 : Fintype.card SgIxU1 = 5767168 := by
  rw [Fintype.card_sigma]
  simp only [Fintype.card_fun, Fintype.card_bool, Fintype.card_fin]
  rw [sum_sgKindU1]
  simp only [SgKindU1.log]
  norm_num

/-- `1·2^14 + 9·2^19 + 3·2^19 + 3·2^17 + 3·2^19 + 3·2^21 = 14,565,376` lookup pairs at `export_u1`. -/
theorem card_prIxU1 : Fintype.card PrIxU1 = 14565376 := by
  rw [Fintype.card_sigma]
  simp only [Fintype.card_prod, Fintype.card_fun, Fintype.card_bool, Fintype.card_fin]
  rw [sum_lkDomU1]
  simp only [LkDomU1.np, LkDomU1.log]
  norm_num

/-- `16·2^14 = 262,144` table entries at `export_u1`. -/
theorem card_tbIxU1 : Fintype.card TbIxU1 = 262144 := by
  simp only [Fintype.card_prod, Fintype.card_fun, Fintype.card_bool, Fintype.card_fin]
  norm_num

section Counts

variable {K : Type} [Field K] [Algebra GF K]

/-- **`hN` at `export_u1`**: `5,767,168 + 2·14,565,376 = 34,897,920 < gP`. -/
theorem hN_u1 : Fintype.card SgIxU1 + 2 * Fintype.card PrIxU1 < ringChar K := by
  rw [ZK60.Exec.ringChar_eq_gP, card_sgIxU1, card_prIxU1]
  unfold gP
  norm_num

omit [Field K] [Algebra GF K] in
/-- **`he` at `export_u1`**: lookups and twice the table's distinct entries, at most
`34,897,920 + 2·262,144 = 35,422,208 ≤ 2^26 = 67,108,864`. -/
theorem he_u1 [DecidableEq K] (T : TbIxU1 → Tup K) :
    Fintype.card SgIxU1 + 2 * Fintype.card PrIxU1 + 2 * (Finset.univ.image T).card ≤ 2 ^ 26 := by
  have h := Finset.card_image_le (s := (Finset.univ : Finset TbIxU1)) (f := T)
  rw [Finset.card_univ, card_tbIxU1] at h
  rw [card_sgIxU1, card_prIxU1, show (2 : ℕ) ^ 26 = 67108864 by norm_num]
  omega

end Counts

/-! ## 6. `hTtab` at `export_u1` -/

/-- The 13 range sub-planes' widths, indices and families at `export_u1`, checked against `famsLogUpW16U1`. -/
theorem tabRangeU1_ok : ∀ j < 13, (tagW ((subW c0).getD j 0), (subW c0).getD j 0) ∈ famsLogUpW16U1
    ∧ (tabSubS c0).getD j 0 * 2 ^ 14 + supW ((subW c0).getD j 0) ≤ 2 ^ ((subW c0).getD j 0)
    ∧ 0 < supW ((subW c0).getD j 0) := by
  decide

/-- **Every table entry at `export_u1` is a tuple of the block's table**
(`CodeTable famsLogUpW16U1 Pb.exp Pb.act nG`), given `0 < nG` (the ACT column's padding rows
are group `0`'s row at `2048`). -/
theorem tabTupU1_code {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) (hnG : 0 < nG) (k : ℕ)
    (hk : k < 16) (i : ℕ) : CodeTable famsLogUpW16U1 Pb.exp Pb.act nG (tabTupU1 Pb nG k i) := by
  unfold tabTupU1 tabTupEU1
  by_cases h0 : k = 0
  · rw [ite_eq_left h0]
    refine Or.inl ⟨(tagW 8, 8), (by decide : (tagW 8, 8) ∈ famsLogUpW16U1), ((i % 256 : ℕ) : ℤ),
      by positivity, ?_, ?_⟩
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
  by_cases h2 : k = 2
  · rw [ite_eq_left h2]
    by_cases hi : i < nG * 4096
    · rw [ite_eq_left hi]
      refine Or.inr (Or.inr ⟨i / 4096, (Nat.div_lt_iff_lt_mul (by norm_num)).mpr hi, ((i % 4096 : ℕ) : ℤ),
        by positivity, ?_, ?_⟩)
      · have := Nat.mod_lt i (show 0 < 4096 by norm_num)
        omega
      · simp only [Int.cast_natCast]
    · rw [ite_eq_right hi]
      exact Or.inr (Or.inr ⟨0, hnG, ((2048 : ℕ) : ℤ), by norm_num, by norm_num, by simp only [Int.cast_natCast]⟩)
  rw [ite_eq_right h2]
  obtain ⟨hmem, hlt, hpos⟩ := tabRangeU1_ok (k - 3) (by omega)
  refine Or.inl ⟨_, hmem, ((((tabSubS c0).getD (k - 3) 0 * 2 ^ 14
    + i % supW ((subW c0).getD (k - 3) 0)) : ℕ) : ℤ), by positivity, ?_, ?_⟩
  · have := Nat.mod_lt i hpos
    have h' : (tabSubS c0).getD (k - 3) 0 * 2 ^ 14 + i % supW ((subW c0).getD (k - 3) 0)
        < 2 ^ ((subW c0).getD (k - 3) 0) := by omega
    exact_mod_cast h'
  · simp only [ZK60.Circuit.rangeTup, Int.cast_natCast]

/-- **`hTtab` at `export_u1`**: every entry of `TU1` is (the image of) a tuple of
`CodeTable famsLogUpW16U1 Pb.exp Pb.act S.nG`, given `0 < S.nG`. -/
theorem hTtab_u1 {K : Type} [Field K] [Algebra GF K] {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (hnG : 0 < S.nG) :
    ∀ j : TbIxU1, ∃ t0, CodeTable famsLogUpW16U1 Pb.exp Pb.act S.nG t0 ∧ TU1 (K := K) Pb S.nG j = tupK t0 :=
  fun j => ⟨_, tabTupU1_code Pb S.nG hnG j.1 j.1.isLt (msbIndex 14 j.2), rfl⟩

/-- **Every `export_u1` layer has at least one ACT group** (`3 ≤ Ly.nG ≤ 4`). -/
theorem hnG_shieldU1 (Ly : ShieldLayer) (hLy : Ly ∈ shieldExportU1) : 0 < (shieldShape Ly).nG := by
  obtain ⟨-, -, -, -, -, -, h3, -⟩ := shieldExportU1_uniform Ly hLy
  show 0 < Ly.nG
  omega

/-- **`hTtab` at any `export_u1` layer `Ly ∈ shieldExportU1`**, directly matching
`block_knowledge_join_w16r2_shieldU1`'s premise with no `nG` hypothesis. -/
theorem hTtab_shieldU1 {K : Type} [Field K] [Algebra GF K] (Ly : ShieldLayer) (hLy : Ly ∈ shieldExportU1)
    (Pb : ZK60.Block.BlockPublic (shieldShape Ly)) :
    ∀ j : TbIxU1, ∃ t0, CodeTable famsLogUpW16U1 Pb.exp Pb.act (shieldShape Ly).nG t0
      ∧ TU1 (K := K) Pb (shieldShape Ly).nG j = tupK t0 :=
  hTtab_u1 Pb (hnG_shieldU1 Ly hLy)

end ZK60.Exec.Block.Join.W16U1.Look
