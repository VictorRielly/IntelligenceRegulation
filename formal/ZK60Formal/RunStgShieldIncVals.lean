/-
D63 lane L63 (2026-11-18), part 59: **from the clause equations on the table values to `QzcHolds` / `TzcHolds`, and
the small readers the identification needs** (item 4b, step 4).

* **`qzcHolds_of_vals`**, **`tzcHolds_of_vals`**: if the slot's table values at every cube point are the layout's
  fields (and the helpers'), the clause equations of `inc_qzc_clauses` / `inc_tzc_clauses` are `QzcHolds` /
  `TzcHolds` of `incQ` / `incT`;
* `supp_getD_toK`, `rangeMap_getD`: the public tables' entries;
* `kI_nat_toK`: `kI n` is `n` in `K` (for `n < 2^63`);
* `bits7_low`: the low seven bits of a position's twelve are its token row's seven (`msbBits 7 (index mod 128)`);
* `shdIncHd`: the helpers `h_q`, `h_tab`, `u` read as the `H_in` planes at a view.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncTab

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

/-! ## 1. From the table values to the slots' conclusions -/

section Hold

variable {B K : Type} [Field B] [Field K] {ι κ : Type} {k : ℕ}

/-- **SIC_QZC's clause equations at the layout's fields are `QzcHolds`.** -/
theorem qzcHolds_of_vals {φ : B →+* K} {D : InData B ι κ k} {n nv nu : ℕ} (L : IncLayout φ D n nv)
    (ω : InChal K k) (hd : IncHelpers K n nv nu) (r : (Fin n → Bool) → ℕ → K) (bosK gK : K)
    (h0 : ∀ b, r b 0 = L.supp b) (h1 : ∀ b, r b 1 = L.u0 b) (h2 : ∀ b, r b 2 = L.pt b)
    (h3 : ∀ b, r b 3 = L.kap b) (h4 : ∀ b, r b 4 = L.cq ω b) (h5 : ∀ b, r b 5 = L.tok b)
    (h6 : ∀ b, r b 6 = hd.1 b) (h7 : ∀ b, r b 7 = L.bq ω b) (hbos : bosK = L.bos) (hg : gK = L.g ω)
    (hcl : ∀ b, r b 6 * (ω.1.2 - (((r b 5 + ω.1.1.1 * r b 7) + r b 4) + gK)) - r b 0 = 0
      ∧ r b 1 * (r b 5 - bosK) = 0 ∧ r b 2 * (r b 5 - r b 3) = 0
      ∧ (1 - r b 0) * r b 5 = 0 ∧ (1 - r b 0) * r b 6 = 0) :
    QzcHolds (incQ L ω hd) ω.1.2 ω.1.1.1 (L.g ω) L.bos := by
  refine ⟨fun j b => ?_, fun i b => ?_⟩
  · obtain ⟨e1, e2, e3, -, -⟩ := hcl b
    rw [h0, h1, h2, h3, h4, h5, h6, h7, hbos, hg] at *
    cases j with
    | logup =>
      simp only [qzcW, qzcQ, incQ, mleAt_bitv]
      exact e1
    | bos =>
      simp only [qzcW, incQ, mleAt_bitv]
      exact e2
    | tmpl =>
      simp only [qzcW, incQ, mleAt_bitv]
      exact e3
  · obtain ⟨-, -, -, e4, e5⟩ := hcl b
    simp only [h0, h5, h6] at e4 e5
    simp only [qzcPz, incQ, mleAt_bitv]
    by_cases hi : (i : ℕ) = 0
    · rw [ite_eq_left hi]; exact e4
    · rw [ite_eq_right hi]; exact e5

/-- **SIC_TZC's clause equations at the layout's fields are `TzcHolds`.** -/
theorem tzcHolds_of_vals {φ : B →+* K} {D : InData B ι κ k} {n nv nu : ℕ} (L : IncLayout φ D n nv)
    (ω : InChal K k) (hd : IncHelpers K n nv nu) (r : (Fin nv → Bool) → ℕ → K)
    (h0 : ∀ c, r c 0 = L.suppv c) (h1 : ∀ c, r c 1 = L.tau ω c) (h2 : ∀ c, r c 2 = L.m c)
    (h3 : ∀ c, r c 3 = hd.2.1 c)
    (hcl : ∀ c, r c 3 * (ω.1.2 - r c 1) - r c 2 = 0 ∧ (1 - r c 0) * r c 2 = 0 ∧ (1 - r c 0) * r c 3 = 0) :
    TzcHolds (incT L ω hd) ω.1.2 := by
  refine ⟨fun j c => ?_, fun i c => ?_⟩
  · obtain ⟨e1, -, -⟩ := hcl c
    rw [h1, h2, h3] at e1
    simp only [tzcW, incT, mleAt_bitv]
    exact e1
  · obtain ⟨-, e4, e5⟩ := hcl c
    simp only [h0, h2, h3] at e4 e5
    simp only [tzcPz, incT, mleAt_bitv]
    by_cases hi : (i : ℕ) = 0
    · rw [ite_eq_left hi]; exact e4
    · rw [ite_eq_right hi]; exact e5

end Hold

/-! ## 2. Readers -/

section Read

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- A support table's entry. -/
theorem supp_getD_toK (len size idx : ℕ) (h : idx < size) :
    ((supp len size).getD idx Fp2.zero).toK U = if idx < len then 1 else 0 := by
  unfold supp
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range h]
  simp only [Option.map_some, Option.getD_some]
  by_cases hl : idx < len
  · rw [ite_eq_left hl, ite_eq_left hl, Fp2.toK_one]
  · rw [ite_eq_right hl, ite_eq_right hl, Fp2.toK_zero]

/-- A table built over `range size`. -/
theorem rangeMap_getD (size idx : ℕ) (h : idx < size) (f : ℕ → Fp2) :
    ((List.range size).map f).getD idx Fp2.zero = f idx := by
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range h]
  rfl

/-- **`kI n` is `n` in `K`.** -/
theorem kI_nat_toK (n : ℕ) (hn : n < 2 ^ 63) : (kI (n : ℤ)).toK U = (n : K) := by
  unfold kI
  rw [Fp2.toK_fromBase, Fp.toGF_fromI64 _ (by omega) (by omega)]
  simp

end Read

/-- **The low seven bits of a position's twelve are its token row's seven.** -/
theorem bits7_low (b : Fin 12 → Bool) (j : Fin 7) :
    msbBits 7 (msbIndex 12 b % 128) j = b ⟨5 + j.val, by omega⟩ := by
  have hb : b ⟨5 + j.val, by omega⟩ = msbBits 12 (msbIndex 12 b) ⟨5 + j.val, by omega⟩ := by
    rw [msbBits_msbIndex]
  rw [hb]
  unfold msbBits
  obtain ⟨j, hj⟩ := j
  simp only
  have hM := msbIndex_lt 12 b
  generalize msbIndex 12 b = M at hM ⊢
  rw [decide_eq_decide]
  interval_cases j <;> norm_num <;> omega

/-! ## 3. The helpers committed in `H_in` -/

section Hd

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}

/-- **The helpers `h_q`, `h_tab`, `u` as the `H_in` planes at the view `w`** (each the pair `(1, u)` of planes at the
layout's `H` offsets, as SIC_QZC, SIC_TZC and SIC_ZS read them). -/
noncomputable def shdIncHd (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (I : IncPub) (lc h Q e rH iH : ℕ)
    (w : StgVw Lq) : IncHelpers K 12 17 12 :=
  (fun b => Block.Join.planeZ U lc rH Q (stgIOX tag h64 lc h Q e rH iH w)
      ⟨.h, [(((incLay I 14).hOff incH_Q).1, Fp2.one), (((incLay I 14).hOff incH_Q).2, Block.fp2U)], 12, [], 0, 0⟩ b,
   fun c => Block.Join.planeZ U lc rH Q (stgIOX tag h64 lc h Q e rH iH w)
      ⟨.h, [(((incLay I 14).hOff incH_TAB).1, Fp2.one), (((incLay I 14).hOff incH_TAB).2, Block.fp2U)], 17, [], 0,
        0⟩ c,
   fun j => Block.Join.planeZ U lc rH Q (stgIOX tag h64 lc h Q e rH iH w)
      ⟨.h, [(((incLay I 14).hOff incH_U).1, Fp2.one), (((incLay I 14).hOff incH_U).2, Block.fp2U)], 12, [], 0, 0⟩ j)

end Hd

end ZK60.ProtocolClassify
