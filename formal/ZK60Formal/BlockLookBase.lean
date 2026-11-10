/-
D63 lane L47 (2026-11-10), part 2: **the lookup side at the W16R2 rung, DEFINED** (deliverable 2: lane L36's `Alk`, `T`,
`mlk`; `hN`, `he`, `hTtab` PROVED).

The code: `accuracy_layout.rs::lookups_w16` (here `DefW16.lookupsN`, L35, checked against the code by L35's
`BlockDefineCheck` and L44's `BlockHelperExportCheck`), `HIds::new` (the helper planes `DefW16.hIdsN`: `Dom::L` plane
`0`, `Dom::D` `1 … 10`, `Dom::Q` `11 … 13`, `Dom::Kv` `14 … 16`, `Dom::S` `17 … 21`, the exp tuple's `22`, `Dom::F`
`23 … 26`, the ACT tuple's `27`, `SC_TAB`'s `28 … 44`, `H_U` `45`), `argument::helper_sum` (two lookups per helper, an odd
last one alone), `szc_w16`'s exp tuple and `fzc_w16`'s ACT tuple (argument_accuracy.rs).

* `ocNext`, **`ocNext_runLog`**: what an oracle computation does next after a prefix of its own log (its next question,
  or its result when the log is all of it);
* `rootOfCut`, **`rootOfCut_cutsOf`**: the `A` root the extraction reads is a function of the `A` cut alone (for the
  fixed prover `A`): the prover's next question after the cut absorbs it, or the cut is the whole log and the prover's
  output shows it. So the lookups and multiplicities, read off the `A` matrix the cut and that root determine, are FIXED
  before `β, γ, α` (LogUp's premise), and are the real ones on every outcome (`dofA_aPl`);
* `LkDom`, `SgKind`, **`SgIx`, `PrIx`, `TbIx`**: the lookups' index sets: a single lookup per point of its domain
  (`Dom::D`'s 19th, `Dom::S`'s 9th, `Dom::F`'s 7th, the exp and the ACT tuple), a pair per helper and point (`Dom::L` 1,
  `Dom::D` 9, `Dom::Q` 3, `Dom::Kv` 3, `Dom::S` 4, `Dom::F` 3), and the table's 17 columns of `2^14` entries;
* `lkTupW`, `lkAtW`, `expTupW`, `actTupW`, `sgTupW`: the looked-up tuples, read off the committed `A` planes (and the
  public mask and group column);
* **`AlkW`, `TW`, `mlkW`**: lane L36's `Alk`, `T`, `mlk`;
* **`card_sgIx`, `card_prIx`, `hN_w16`, `he_w16`**: `N = 114,688 + 2·475,136 = 1,064,960` lookups, `17·2^14` table entries;
  `hN`, `he` PROVED;
* `famsW`, **`famsW_ok`** (`FamsOK`), **`w16Widths_famsW`** (`W16Widths` from `RungS`), **`tabTupW_code`**, **`hTtab_w16`**:
  every table entry is a tuple of the block's table (`hTtab`), given one to four ACT groups.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockTabBase
import ZK60Formal.BlockHostFinal

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.Join.W16.Tab
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Circuit (gP GF tagW tagExp tagAct CodeTable FamsOK)
open ZK60.Layout
open Finset

/-! ## The `A` root is a function of the `A` cut -/

section Cut

/-- **What an oracle computation does next after a log prefix**: its next question, or its result when the prefix is
its whole log (`none` past the end). -/
def ocNext {I O α : Type} : OC I O α → List (I × O) → Option (I ⊕ α)
  | .ret a, [] => some (.inr a)
  | .ask i _, [] => some (.inl i)
  | .ret _, _ :: _ => none
  | .ask _ k, e :: es => ocNext (k e.2) es

/-- On a prefix of its own log, the computation's next step is the log's next question, or its result. -/
theorem ocNext_runLog {I O α : Type} (f : I → O) :
    ∀ (A : OC I O α) (P R : List (I × O)), (A.runLog f).2 = P ++ R →
      ocNext A P = (match R with
        | [] => some (.inr (A.run f))
        | e :: _ => some (.inl e.1))
  | .ret a, P, R, h => by
    have h' : P ++ R = [] := h.symm
    obtain ⟨rfl, rfl⟩ := List.append_eq_nil_iff.mp h'
    rfl
  | .ask i k, [], R, h => by
    have h' : R = (i, f i) :: ((k (f i)).runLog f).2 := by simpa [OC.runLog] using h.symm
    subst h'
    rfl
  | .ask i k, e :: P, R, h => by
    have h' : (i, f i) :: ((k (f i)).runLog f).2 = e :: (P ++ R) := by simpa [OC.runLog] using h
    obtain ⟨he, hl⟩ := List.cons.inj h'
    subst he
    show ocNext (k (f i)) P = _
    rw [ocNext_runLog f (k (f i)) P R hl]
    rfl

/-- **The root a cut shows**: the bytes the prover's next question absorbs, or, when the cut is the prover's whole
log, the `A` root of its output. -/
def rootOfCut {I O : Type} {β : Type} (absOf : I → Option (List UInt8)) (A : OC I O (β × Core))
    (cut : List (I × O)) : Option (List UInt8) :=
  match ocNext A cut with
  | some (.inl i) => absOf i
  | some (.inr out) => (rootsOf out.2).1
  | none => none

variable {L : ℕ}

/-- **The `A` root the extraction reads is the one the `A` cut determines** (for the fixed prover `A`). -/
theorem rootOfCut_cutsOf (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) {β : Type} (A : OC (QB L) Dig (β × Core)) (G : QB L → Dig) :
    rootOfCut (absOfC (chainEncB key domain hs L hL)) A (cutsOf key domain hs hL A G).1
      = (rootsOf (A.run G).2).1 := by
  set absOf := absOfC (chainEncB key domain hs L hL) with habs
  set Lg := (A.runLog G).2 with hLg
  set r := (A.run G).2.aRoot.toList with hr
  have hcut : (cutsOf key domain hs hL A G).1 = Lg.take (Lg.findIdx (isAbsAt absOf r)) := rfl
  rw [hcut]
  have hsplit : Lg = Lg.take (Lg.findIdx (isAbsAt absOf r)) ++ Lg.drop (Lg.findIdx (isAbsAt absOf r)) :=
    (List.take_append_drop _ _).symm
  have hn := ocNext_runLog G A _ _ hsplit
  unfold rootOfCut
  rw [hn]
  by_cases hlt : Lg.findIdx (isAbsAt absOf r) < Lg.length
  · rw [List.drop_eq_getElem_cons hlt]
    show absOf (Lg[Lg.findIdx (isAbsAt absOf r)]'hlt).1 = _
    have hp : isAbsAt absOf r (Lg[Lg.findIdx (isAbsAt absOf r)]'hlt) = true := List.findIdx_getElem (w := hlt)
    have hp' : absOf (Lg[Lg.findIdx (isAbsAt absOf r)]'hlt).1 = some r := of_decide_eq_true hp
    rw [hp']
    rfl
  · rw [List.drop_eq_nil_of_le (by omega)]

end Cut

/-! ## The committed data the `A` cut fixes -/

section Dof

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The committed data read off an `A` cut alone**: the `A` matrix extracted from the cut for the root the cut
determines (the other commitments empty). -/
noncomputable def dofA (tag : MTag) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (absOf : QB L → Option (List UInt8)) {β : Type} (A : OC (QB L) Dig (β × Core)) (cut : List (QB L × Dig)) :
    CmData K P :=
  dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cut, [], []) (rootOfCut absOf A cut, none, none)

/-- **On every outcome, the `A` planes of the cut's data are the real ones.** -/
theorem dofA_aPl (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (tag : MTag) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (A : OC (QB L) Dig (List Op × Core)) (G : QB L → Dig) (off log : ℕ) (b : Fin log → Bool) :
    aPl U P (dofA tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A (cutsOf key domain hs hL A G).1)
        off log b
      = aPl U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
          (rootsOf (A.run G).2)) off log b := by
  unfold dofA
  rw [rootOfCut_cutsOf key domain hs hL A G]
  rfl

end Dof

/-! ## The index sets -/

/-- The domains whose lookups are paired by LogUp's helpers. -/
inductive LkDom
  | L | D | Q | Kv | S | F
  deriving DecidableEq

instance : Fintype LkDom :=
  Fintype.ofList [.L, .D, .Q, .Kv, .S, .F] (fun d => by cases d <;> decide)

/-- The code's domain. -/
def LkDom.dom : LkDom → ZK60.Exec.Slot.W16R2.Dom
  | .L => .L | .D => .D | .Q => .Q | .Kv => .Kv | .S => .S | .F => .F

/-- The domain's cube bits at the rung. -/
def LkDom.log : LkDom → ℕ
  | .L => 14 | .D => 14 | .Q => 15 | .Kv => 14 | .S => 14 | .F => 15

/-- The domain's pair helpers (half its lookup count, rounded down). -/
def LkDom.np : LkDom → ℕ
  | .L => 1 | .D => 9 | .Q => 3 | .Kv => 3 | .S => 4 | .F => 3

/-- The domain's first helper plane (`HIds`). -/
def LkDom.fh : LkDom → ℕ
  | .L => 0 | .D => 1 | .Q => 11 | .Kv => 14 | .S => 17 | .F => 23

/-- The single lookups: the odd last lookup of `Dom::D`, `Dom::S`, `Dom::F`, the exp tuple, the ACT tuple. -/
inductive SgKind
  | D | S | F | Exp | Act
  deriving DecidableEq

instance : Fintype SgKind :=
  Fintype.ofList [.D, .S, .F, .Exp, .Act] (fun s => by cases s <;> decide)

/-- A single lookup's cube bits. -/
def SgKind.log : SgKind → ℕ
  | .D => 14 | .S => 14 | .F => 15 | .Exp => 14 | .Act => 15

/-- A single lookup's helper plane. -/
def SgKind.hp : SgKind → ℕ
  | .D => 10 | .S => 21 | .F => 26 | .Exp => 22 | .Act => 27

/-- **The single lookups' positions.** -/
abbrev SgIx := Σ s : SgKind, (Fin s.log → Bool)

/-- **The pairs' positions.** -/
abbrev PrIx := Σ d : LkDom, Fin d.np × (Fin d.log → Bool)

/-- **The table's positions**: 17 columns of `2^14` entries. -/
abbrev TbIx := Fin 17 × (Fin 14 → Bool)

/-- The domain's lookup count is the code's: twice its pairs, plus one where it has a single. -/
theorem lkDom_len : ∀ d : LkDom, (lookupsN cfgRungW16 d.dom).length
    = 2 * d.np + (if d = .D ∨ d = .S ∨ d = .F then 1 else 0) := by
  intro d
  cases d <;> decide

/-- Every domain's helpers, as the code's `HIds` lists them. -/
theorem lkDom_fh : ∀ d : LkDom, d.fh = (hIdsN cfgRungW16).getD
    (match d with | .L => 0 | .D => 1 | .Q => 2 | .Kv => 3 | .S => 4 | .F => 6) 0 := by
  intro d
  cases d <;> decide

/-! ## The looked-up tuples -/

section Tuples

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)

/-- **A lookup's tuple at a cube point**: `(Σ coef·plane + cst, TAG(width), 0, 0)`, the planes read off `A` at the
code's offsets (`lookups_w16`, `logup_subterms`). -/
noncomputable def lkTupW (log : ℕ) (l : LkW) (b : Fin log → Bool) : Tup K :=
  ⟨(l.terms.map fun t => (t.2 : K) * aPl U P D (aOff cfgRungW16 t.1) log b).sum + (l.cst : K), ((tagW l.tag : ℕ) : K),
    0, 0⟩

/-- Lookup `i` of a domain at a point of the domain's cube. -/
noncomputable def lkAtW (d : LkDom) (i : ℕ) (b : Fin d.log → Bool) : Tup K :=
  lkTupW U P D d.log ((lookupsN cfgRungW16 d.dom).getD i ⟨[], 0, 0⟩) b

variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- **The exp tuple** at a point of `Dom::S` (`szc_w16`): `(MX − mask·(S8 + 127) + 127, TAG_EXP, E, 0)`, `MX` read on
the point's first nine bits (`Dom::Ht`). -/
noncomputable def expTupW (b : Fin 14 → Bool) : Tup K :=
  ⟨aPl U P D 65536 9 (Szc.hd9 b) - algebraMap GF K (B.mask (splitS b)) * aPl U P D 737280 14 b
      + (-127 : K) * algebraMap GF K (B.mask (splitS b)) + 127, ((tagExp : ℕ) : K), aPl U P D 802816 14 b, 0⟩

/-- **The ACT tuple** at a point of `Dom::F` (`fzc_w16`): `(G + 2048, TAG_ACT, A, group)`. -/
noncomputable def actTupW (b : Fin 15 → Bool) : Tup K :=
  ⟨aPl U P D 901120 15 b + 2048, ((tagAct : ℕ) : K), aPl U P D 999424 15 b, algebraMap GF K (B.grpCol (splitF b))⟩

/-- **A single lookup's tuple.** -/
noncomputable def sgTupW : (s : SgKind) → (Fin s.log → Bool) → Tup K
  | .D, b => lkAtW U P D .D 18 b
  | .S, b => lkAtW U P D .S 8 b
  | .F, b => lkAtW U P D .F 6 b
  | .Exp, b => expTupW U P D Pb Lay B b
  | .Act, b => actTupW U P D Pb Lay B b

end Tuples

/-! ## Lane L36's `Alk`, `T`, `mlk` -/

section Lk

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- **The lookup list** (lane L36's `Alk`), read off the committed data `Dof cut` the `A` cut fixes: the singles, then
each pair's first and second lookup. -/
noncomputable def AlkW (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) :
    SgIx ⊕ (PrIx ⊕ PrIx) → Tup K
  | .inl ⟨s, b⟩ => sgTupW U P (Dof cut) Pb Lay B s b
  | .inr (.inl ⟨d, j, b⟩) => lkAtW U P (Dof cut) d (2 * (j : ℕ)) b
  | .inr (.inr ⟨d, j, b⟩) => lkAtW U P (Dof cut) d (2 * (j : ℕ) + 1) b

/-- **The table** (lane L36's `T`): column `k`'s tuple at its position, as `SC_TAB`'s public value column folds it. -/
noncomputable def TW (nG : ℕ) : TbIx → Tup K := fun j => tupK (tabTupW Pb nG j.1 (msbIndex 14 j.2))

/-- **The multiplicities** (lane L36's `mlk`): `SC_TAB`'s multiplicity planes, read off the committed data the `A` cut
fixes. -/
noncomputable def mlkW (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) : TbIx → K :=
  fun j => multTabW U P (Dof cut) j.1 j.2

end Lk

/-! ## The counts: `hN`, `he` -/

theorem card_sgIx : Fintype.card SgIx = 114688 := by
  rw [Fintype.card_sigma]
  simp only [Fintype.card_fun, Fintype.card_bool, Fintype.card_fin]
  rfl

theorem card_prIx : Fintype.card PrIx = 475136 := by
  rw [Fintype.card_sigma]
  simp only [Fintype.card_prod, Fintype.card_fun, Fintype.card_bool, Fintype.card_fin]
  rfl

theorem card_tbIx : Fintype.card TbIx = 278528 := by
  simp only [Fintype.card_prod, Fintype.card_fun, Fintype.card_bool, Fintype.card_fin]
  norm_num

section Counts

variable {K : Type} [Field K] [Algebra GF K]

/-- **`hN`**: the lookups number `1,064,960 < p`. -/
theorem hN_w16 : Fintype.card SgIx + 2 * Fintype.card PrIx < ringChar K := by
  rw [ZK60.Exec.ringChar_eq_gP, card_sgIx, card_prIx]
  unfold gP
  norm_num

/-- **`he`**: lookups and twice the table's distinct entries, at most `1,064,960 + 2·278,528 = 1,622,016`, within
`35,153,256`. -/
omit [Field K] [Algebra GF K] in
theorem he_w16 [DecidableEq K] (T : TbIx → Tup K) :
    Fintype.card SgIx + 2 * Fintype.card PrIx + 2 * (Finset.univ.image T).card ≤ 35153256 := by
  have h := Finset.card_image_le (s := (Finset.univ : Finset TbIx)) (f := T)
  rw [Finset.card_univ, card_tbIx] at h
  rw [card_sgIx, card_prIx]
  omega

end Counts

/-! ## `hTtab` -/

/-- **The block's range families as the table's `(tag, width)` list**: bytes, then the rung's families. -/
def famsW : List (ℕ × ℕ) := (tagW 8, 8) :: famsRungW16.map fun f => (tagW f.1, f.1)

/-- `FamsOK` of the families: tags below `p`, distinct, and not `TAG_EXP` or `TAG_ACT`. -/
theorem famsW_ok : FamsOK famsW where
  lt := by
    intro f hf
    have h : f.1 ≤ 216 := by
      revert f
      decide
    have h2 : (216 : ℕ) < gP := by unfold gP; norm_num
    omega
  dist := by decide
  ne_exp := by decide
  ne_act := by decide

/-- **`W16Widths` of the families** at a shape with the rung's precision. -/
theorem w16Widths_famsW {S : ZK60.Block.BlockShape} (hS : RungS S) : W16Widths S famsW where
  w8 := by decide
  w16 := by decide
  w7 := by decide
  wP := by rw [hS.fp]; decide
  rem := by
    rw [hS.sao, hS.sdown, hS.sq, hS.spv, hS.sk, hS.sv, hS.ss, hS.wrho, hS.sgate, hS.sup, hS.sprod]
    decide

/-- The range sub-planes' widths, indices and families at the rung, checked. -/
theorem tabRange_ok : ∀ j < 14, (tagW ((subW cfgRungW16).getD j 0), (subW cfgRungW16).getD j 0) ∈ famsW
    ∧ (tabSubS cfgRungW16).getD j 0 * 2 ^ 14 + supW ((subW cfgRungW16).getD j 0) ≤ 2 ^ ((subW cfgRungW16).getD j 0)
    ∧ 0 < supW ((subW cfgRungW16).getD j 0) := by
  decide

/-- **Every table entry is a tuple of the block's table** (`CodeTable famsW exp act nG`), given one ACT group at least
(the padding rows of the ACT column are group `0`'s row at `2048`). -/
theorem tabTupW_code {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) (hnG : 0 < nG) (k : ℕ)
    (hk : k < 17) (i : ℕ) : CodeTable famsW Pb.exp Pb.act nG (tabTupW Pb nG k i) := by
  unfold tabTupW tabTupE
  by_cases h0 : k = 0
  · rw [ite_eq_left h0]
    refine Or.inl ⟨(tagW 8, 8), List.mem_cons.mpr (Or.inl rfl), ((i % 256 : ℕ) : ℤ), by positivity, ?_, ?_⟩
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
  obtain ⟨hmem, hlt, hpos⟩ := tabRange_ok (k - 3) (by omega)
  refine Or.inl ⟨_, hmem, ((((tabSubS cfgRungW16).getD (k - 3) 0 * 2 ^ 14
    + i % supW ((subW cfgRungW16).getD (k - 3) 0)) : ℕ) : ℤ), by positivity, ?_, ?_⟩
  · have := Nat.mod_lt i hpos
    have h' : (tabSubS cfgRungW16).getD (k - 3) 0 * 2 ^ 14 + i % supW ((subW cfgRungW16).getD (k - 3) 0)
        < 2 ^ ((subW cfgRungW16).getD (k - 3) 0) := by omega
    exact_mod_cast h'
  · simp only [ZK60.Circuit.rangeTup, Int.cast_natCast]

/-- **`hTtab`**: every entry of the table enumeration `TW` is (the image of) a tuple of the block's table. -/
theorem hTtab_w16 {K : Type} [Field K] [Algebra GF K] {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (hnG : 0 < S.nG) :
    ∀ j : TbIx, ∃ t0, CodeTable famsW Pb.exp Pb.act S.nG t0 ∧ TW (K := K) Pb S.nG j = tupK t0 :=
  fun j => ⟨_, tabTupW_code Pb S.nG hnG j.1 j.1.isLt (msbIndex 14 j.2), rfl⟩

end ZK60.Exec.Block.Join.W16.Look
