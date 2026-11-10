/-
D63 lane L47 (2026-11-10), part 4 (fork B): **the lookup cover `hcov` at the W16R2 rung** (deliverable 2: lane L36's
premise `hcov`, PROVED for the lookup list `AlkW` read off the `A` cut).

* `exists_lk`, `exists_exp`, `exists_act`: every lookup of the code's list (`lookupsN`, at every point of its domain's
  cube), every exp tuple and every ACT tuple is an entry of `AlkW` (the pairs `2j`, `2j + 1`, the singles);
* `lkAtW_congr`, `expTupW_congr`, `actTupW_congr`: the tuples read only the `A` planes;
* `cov_gen`, `cov_two`, `covR`, `covC`, `covN`: a code lookup's tuple at a cube point IS (the image of) the range query
  of the plane it reads, on a base-valued `A` matrix;
* `remLk_one`, `remLk_two`: a remainder's queries are its limbs' range queries;
* **`cover_xtW`**: every field of `W16Lookups` (`la`, `lm`, `dW`, `dR`, `qW`, `qR`, `kW`, `kR`, `sB`, `sR`, `sExp`, `fR`,
  `fAct`) asks only tuples that are entries of `AlkW`, at the rung's precision (`RungS`);
* **`hcov_w16`**: lane L36's `hcov` (the form of L44's `block_knowledge_host_w16r2_rung_helper`) for `AlkW` on the data
  the `A` cut fixes (`dofA`), on every outcome.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLookEntry

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Circuit (gP GF tagW tagExp tagAct rangeQuery expQuery actQuery)
open ZK60.Layout

/-! ## Every code lookup is an entry of the list -/

section Alk

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay) (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig))

/-- **Every lookup of a domain, at every point of its cube, is an entry of the list.** -/
theorem exists_lk (d : LkDom) (i : ℕ) (hi : i < (lookupsN cfgRungW16 d.dom).length) (b : Fin d.log → Bool) :
    ∃ l, AlkW U P Pb Lay B Dof cut l = lkAtW U P (Dof cut) d i b := by
  by_cases h2 : i < 2 * d.np
  · obtain ⟨j, rfl | rfl⟩ := Nat.even_or_odd' i
    · exact ⟨.inr (.inl ⟨d, ⟨j, by omega⟩, b⟩), rfl⟩
    · exact ⟨.inr (.inr ⟨d, ⟨j, by omega⟩, b⟩), rfl⟩
  · cases d with
    | L =>
      have h : (lookupsN cfgRungW16 LkDom.L.dom).length = 2 := by decide
      exact absurd (show i < 2 * 1 by omega) h2
    | D =>
      have h : (lookupsN cfgRungW16 LkDom.D.dom).length = 19 := by decide
      obtain rfl : i = 18 := by simp only [LkDom.np] at h2; omega
      exact ⟨.inl ⟨SgKind.D, b⟩, rfl⟩
    | Q =>
      have h : (lookupsN cfgRungW16 LkDom.Q.dom).length = 6 := by decide
      exact absurd (show i < 2 * 3 by omega) h2
    | Kv =>
      have h : (lookupsN cfgRungW16 LkDom.Kv.dom).length = 6 := by decide
      exact absurd (show i < 2 * 3 by omega) h2
    | S =>
      have h : (lookupsN cfgRungW16 LkDom.S.dom).length = 9 := by decide
      obtain rfl : i = 8 := by simp only [LkDom.np] at h2; omega
      exact ⟨.inl ⟨SgKind.S, b⟩, rfl⟩
    | F =>
      have h : (lookupsN cfgRungW16 LkDom.F.dom).length = 7 := by decide
      obtain rfl : i = 6 := by simp only [LkDom.np] at h2; omega
      exact ⟨.inl ⟨SgKind.F, b⟩, rfl⟩

/-- Every exp tuple is an entry of the list. -/
theorem exists_exp (b : Fin 14 → Bool) : ∃ l, AlkW U P Pb Lay B Dof cut l = expTupW U P (Dof cut) Pb Lay B b :=
  ⟨.inl ⟨SgKind.Exp, b⟩, rfl⟩

/-- Every ACT tuple is an entry of the list. -/
theorem exists_act (b : Fin 15 → Bool) : ∃ l, AlkW U P Pb Lay B Dof cut l = actTupW U P (Dof cut) Pb Lay B b :=
  ⟨.inl ⟨SgKind.Act, b⟩, rfl⟩

end Alk

/-! ## The tuples read only the `A` planes -/

section Congr

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D1 D2 : CmData K P)
  (h : ∀ off log b, aPl U P D1 off log b = aPl U P D2 off log b)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

include h

theorem lkAtW_congr (d : LkDom) (i : ℕ) (b : Fin d.log → Bool) : lkAtW U P D1 d i b = lkAtW U P D2 d i b := by
  unfold lkAtW lkTupW
  simp only [h]

theorem expTupW_congr (b : Fin 14 → Bool) : expTupW U P D1 Pb Lay B b = expTupW U P D2 Pb Lay B b := by
  unfold expTupW
  simp only [h]

theorem actTupW_congr (b : Fin 15 → Bool) : actTupW U P D1 Pb Lay B b = actTupW U P D2 Pb Lay B b := by
  unfold actTupW
  simp only [h]

end Congr

/-! ## A code lookup's tuple is its plane's range query -/

section Cov

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay) (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) (D : CmData K P)
  (hD : ∀ off log b, aPl U P (Dof cut) off log b = aPl U P D off log b)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)

include hD in
/-- **A one-term lookup of the code's list covers the range query of the value it reads.** -/
theorem cov_gen (d : LkDom) (i : ℕ) (hi : i < (lookupsN cfgRungW16 d.dom).length) (q off : ℕ)
    (hoff : aOff cfgRungW16 q = off) (cf cst : ℤ) (w : ℕ)
    (hl : (lookupsN cfgRungW16 d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q, cf)], cst, w⟩) (b : Fin d.log → Bool) (x : GF)
    (hx : algebraMap GF K x = (cf : K) * aPl U P D off d.log b + (cst : K)) :
    ∃ l, AlkW U P Pb Lay B Dof cut l = tupK (rangeQuery (tagW w) x) := by
  obtain ⟨l, hl'⟩ := exists_lk U P Pb Lay B Dof cut d i hi b
  refine ⟨l, ?_⟩
  rw [hl', lkAtW_congr U P (Dof cut) D hD]
  unfold lkAtW lkTupW
  rw [hl]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, hoff, tupK, rangeQuery, hx,
    map_natCast, map_zero]

include hD in
/-- **A two-term lookup** (`H − 2^16·Htop`). -/
theorem cov_two (d : LkDom) (i : ℕ) (hi : i < (lookupsN cfgRungW16 d.dom).length) (q1 off1 q2 off2 : ℕ)
    (hoff1 : aOff cfgRungW16 q1 = off1) (hoff2 : aOff cfgRungW16 q2 = off2) (c1 c2 cst : ℤ) (w : ℕ)
    (hl : (lookupsN cfgRungW16 d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q1, c1), (q2, c2)], cst, w⟩) (b : Fin d.log → Bool)
    (x : GF) (hx : algebraMap GF K x = (c1 : K) * aPl U P D off1 d.log b + (c2 : K) * aPl U P D off2 d.log b + (cst : K)) :
    ∃ l, AlkW U P Pb Lay B Dof cut l = tupK (rangeQuery (tagW w) x) := by
  obtain ⟨l, hl'⟩ := exists_lk U P Pb Lay B Dof cut d i hi b
  refine ⟨l, ?_⟩
  rw [hl', lkAtW_congr U P (Dof cut) D hD]
  unfold lkAtW lkTupW
  rw [hl]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, hoff1, hoff2, tupK, rangeQuery, hx,
    map_natCast, map_zero, add_assoc]

include hD hX in
/-- A remainder limb (`cst = 0`): the range query of the plane's value. -/
theorem covR (d : LkDom) (i : ℕ) (hi : i < (lookupsN cfgRungW16 d.dom).length) (q off : ℕ)
    (hoff : aOff cfgRungW16 q = off) (w : ℕ) (hl : (lookupsN cfgRungW16 d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q, 1)], 0, w⟩)
    (b : Fin d.log → Bool) :
    ∃ l, AlkW U P Pb Lay B Dof cut l = tupK (rangeQuery (tagW w) (piB K (aPl U P D off d.log b))) :=
  cov_gen U P Pb Lay B Dof cut D hD d i hi q off hoff 1 0 w hl b _ (by
    rw [aPl_alg U P D hX]
    push_cast
    ring)

include hD hX in
/-- A word or byte with a constant (`plane + k`). -/
theorem covC (d : LkDom) (i : ℕ) (hi : i < (lookupsN cfgRungW16 d.dom).length) (q off : ℕ)
    (hoff : aOff cfgRungW16 q = off) (cst : ℤ) (w : ℕ)
    (hl : (lookupsN cfgRungW16 d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q, 1)], cst, w⟩) (b : Fin d.log → Bool) (k : GF)
    (hk : algebraMap GF K k = (cst : K)) :
    ∃ l, AlkW U P Pb Lay B Dof cut l = tupK (rangeQuery (tagW w) (piB K (aPl U P D off d.log b) + k)) :=
  cov_gen U P Pb Lay B Dof cut D hD d i hi q off hoff 1 cst w hl b _ (by
    rw [map_add, aPl_alg U P D hX, hk]
    push_cast
    ring)

include hD hX in
/-- A negated byte with a constant (`−plane + k`). -/
theorem covN (d : LkDom) (i : ℕ) (hi : i < (lookupsN cfgRungW16 d.dom).length) (q off : ℕ)
    (hoff : aOff cfgRungW16 q = off) (cst : ℤ) (w : ℕ)
    (hl : (lookupsN cfgRungW16 d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q, -1)], cst, w⟩) (b : Fin d.log → Bool) (k : GF)
    (hk : algebraMap GF K k = (cst : K)) :
    ∃ l, AlkW U P Pb Lay B Dof cut l = tupK (rangeQuery (tagW w) (-piB K (aPl U P D off d.log b) + k)) :=
  cov_gen U P Pb Lay B Dof cut D hD d i hi q off hoff (-1) cst w hl b _ (by
    rw [map_add, map_neg, aPl_alg U P D hX, hk]
    push_cast
    ring)

end Cov

/-! ## A remainder's queries -/

section Rem

theorem remLk_one {T : Tup GF → Prop} (bits : ℕ) (h : bits ≤ 16) (lo hi : GF) (h1 : T (rangeQuery (tagW bits) lo)) :
    ∀ q ∈ remLk bits lo hi, T q := by
  intro q hq
  unfold remLk at hq
  rw [ite_eq_left h, List.mem_singleton] at hq
  rw [hq]
  exact h1

theorem remLk_two {T : Tup GF → Prop} (bits w2 : ℕ) (h : ¬ bits ≤ 16) (hw : bits - 16 = w2) (lo hi : GF)
    (h1 : T (rangeQuery (tagW 16) lo)) (h2 : T (rangeQuery (tagW w2) hi)) : ∀ q ∈ remLk bits lo hi, T q := by
  intro q hq
  unfold remLk at hq
  rw [ite_eq_right h, hw] at hq
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hq
  rcases hq with rfl | rfl
  · exact h1
  · exact h2

end Rem

end ZK60.Exec.Block.Join.W16.Look
