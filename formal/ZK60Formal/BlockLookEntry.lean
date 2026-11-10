/-
D63 lane L47 (2026-11-10), part 3 (fork B): **a committed plane at a Boolean point is the matrix entry at its flat
index** (what the lookup cover needs to identify the isqrt limbs' 32-entry sub-slices of `Dom::L` with the code's
14-bit `Dom::L` lookups).

* `eqPoly_congr_left`, `eqPoly_bitsK`: the `eq` table of a Boolean point against an index's bits;
* **`planeZ_one`**: a one-slice plane (coefficient `1`) at a Boolean point `c` of `log` bits is
  `Σ_i Σ_t [i = off / 2^logN ∧ t = off mod 2^logN + idx(c)]·X i t`, for a slice that does not cross a row
  (`off mod 2^logN + 2^log ≤ 2^logN`);
* **`aPl_entry`**, **`aPl_flat`**: the same for the `A` planes `aPl`; two planes read at Boolean points with the same
  row and the same column are equal.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLookBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Circuit (gP GF)

section Entry

variable {K : Type} [Field K] [Algebra GF K] (U : K)

omit [Algebra GF K] in
theorem eqPoly_congr_left {n : ℕ} (τ τ' x : Fin n → K) (h : ∀ a, τ a = τ' a) : eqPoly τ x = eqPoly τ' x := by
  rw [funext h]

omit [Algebra GF K] in
/-- The Boolean point's `eq` against an index's bits: `1` exactly at the point's own index. -/
theorem eqPoly_bitsK (n : ℕ) (c : Fin n → Bool) (t : ℕ) (ht : t < 2 ^ n) :
    eqPoly (fun a : Fin n => (bit (c a) : K)) (bitsK n t) = if t = msbIndex n c then 1 else 0 := by
  show eqPoly (fun a : Fin n => (bit (c a) : K)) (fun a => bit (msbBits n t a)) = _
  rw [ZK60.Sound.SlotW16.eqPoly_bit_bit]
  by_cases h : t = msbIndex n c
  · rw [ite_eq_left h, ite_eq_left (by rw [h, msbBits_msbIndex])]
  · rw [ite_eq_right h, ite_eq_right (fun hc => h (by rw [hc, msbIndex_msbBits n t ht]))]

/-- **A one-slice plane at a Boolean point is the matrix entry at its flat index** (a slice within one row). -/
theorem planeZ_one (logN R Q : ℕ) (X : Fin R → Fin (2 ^ logN + Q) → K) (cm : Cm) (off log : ℕ) (cs : List Coord)
    (mr er : ℕ) (hal : off % 2 ^ logN + 2 ^ log ≤ 2 ^ logN) (c : Fin log → Bool) :
    planeZ U logN R Q X ⟨cm, [(off, Fp2.one)], log, cs, mr, er⟩ c
      = ∑ i : Fin R, ∑ t : Fin (2 ^ logN + Q),
          if (i : ℕ) = off / 2 ^ logN ∧ (t : ℕ) = off % 2 ^ logN + msbIndex log c then X i t else 0 := by
  have hle : log ≤ logN := by
    have h1 : 2 ^ log ≤ 2 ^ logN := le_trans (Nat.le_add_left _ _) hal
    exact (Nat.pow_le_pow_iff_right (by norm_num)).mp h1
  -- the row weight (it does not read the point)
  have hrow : ∀ (pt : ℕ → K) (i : ℕ), partRowK logN off log pt i = if i = off / 2 ^ logN then 1 else 0 := by
    intro pt i
    unfold partRowK
    by_cases hl : logN ≤ log
    · have he : log = logN := le_antisymm hle hl
      rw [ite_eq_left hl]
      have : IsEmpty (Fin (log - logN)) := by rw [he, Nat.sub_self]; infer_instance
      have h1 : ∀ f g : Fin (log - logN) → K, eqPoly f g = 1 := fun f g => by
        unfold eqPoly
        exact Finset.prod_of_isEmpty _
      rw [h1]
      have h2 : 2 ^ (log - logN) = 1 := by rw [he, Nat.sub_self, pow_zero]
      rw [h2]
      by_cases hi : i = off / 2 ^ logN
      · rw [ite_eq_left ⟨by omega, by omega⟩, ite_eq_left hi]
      · rw [ite_eq_right (by omega), ite_eq_right hi]
    · rw [ite_eq_right hl]
  -- the column weight, at the Boolean point
  have hcol : ∀ (pt : ℕ → K), (∀ a (h : a < log), pt a = bit (c ⟨a, h⟩)) → ∀ t : ℕ, t < 2 ^ logN →
      keyColK logN off log pt t = if t = off % 2 ^ logN + msbIndex log c then 1 else 0 := by
    intro pt hpt t ht
    unfold keyColK
    by_cases hl : logN ≤ log
    · have he : log = logN := le_antisymm hle hl
      subst he
      rw [ite_eq_left hl]
      have hm : off % 2 ^ log = 0 := by omega
      rw [hm, Nat.zero_add]
      refine Eq.trans (eqPoly_congr_left _ (fun a => (bit (c a) : K)) _ (fun a => ?_)) (eqPoly_bitsK log c t ht)
      have ha := a.isLt
      rw [hpt (log - log + (a : ℕ)) (by omega)]
      congr 2
      exact Fin.ext (by simp)
    · rw [ite_eq_right hl]
      by_cases hr : off % 2 ^ logN ≤ t ∧ t < off % 2 ^ logN + 2 ^ log
      · rw [ite_eq_left hr]
        refine Eq.trans (eqPoly_congr_left _ (fun a => (bit (c a) : K)) _ (fun a => hpt a a.isLt)) ?_
        rw [eqPoly_bitsK log c _ (by omega)]
        by_cases he : t - off % 2 ^ logN = msbIndex log c
        · rw [ite_eq_left he, ite_eq_left (by omega)]
        · rw [ite_eq_right he, ite_eq_right (by omega)]
      · rw [ite_eq_right hr]
        have := msbIndex_lt log c
        rw [ite_eq_right (by omega)]
  unfold planeZ privZ
  simp only [List.map_cons, List.map_nil, claimK, List.sum_cons, List.sum_nil, add_zero, Fp2.toK_one, one_mul, hrow]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  rw [Finset.mul_sum]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  by_cases ht : (t : ℕ) < 2 ^ logN
  · rw [ite_eq_left ht, hcol (fun q => if h : q < log then (bit (c ⟨q, h⟩) : K) else 0)
      (fun a h => by simp only [h, ↓reduceDIte]) t ht]
    by_cases hi : (i : ℕ) = off / 2 ^ logN
    · by_cases hc : (t : ℕ) = off % 2 ^ logN + msbIndex log c
      · rw [ite_eq_left hi, ite_eq_left hc, ite_eq_left ⟨hi, hc⟩]
        ring
      · rw [ite_eq_left hi, ite_eq_right hc, ite_eq_right (fun h => hc h.2)]
        ring
    · rw [ite_eq_right hi, zero_mul,
        ite_eq_right (fun h : (i : ℕ) = off / 2 ^ logN ∧ (t : ℕ) = off % 2 ^ logN + msbIndex log c => hi h.1)]
  · have := msbIndex_lt log c
    rw [ite_eq_right ht, mul_zero, mul_zero,
      ite_eq_right (fun h : (i : ℕ) = off / 2 ^ logN ∧ (t : ℕ) = off % 2 ^ logN + msbIndex log c => ht (by omega))]

variable (P : BlockParams) (D : CmData K P)

/-- **An `A` plane at a Boolean point is the matrix entry at its flat index.** -/
theorem aPl_entry (off log : ℕ) (b : Fin log → Bool)
    (hal : off % 2 ^ rowLog P .a + 2 ^ log ≤ 2 ^ rowLog P .a) :
    aPl U P D off log b = ∑ i : Fin (D.rows .a), ∑ t : Fin (2 ^ rowLog P .a + D.Q .a),
      if (i : ℕ) = off / 2 ^ rowLog P .a ∧ (t : ℕ) = off % 2 ^ rowLog P .a + msbIndex log b then D.X .a i t else 0 :=
  planeZ_one U (rowLog P .a) (D.rows .a) (D.Q .a) (D.X .a) .a off log [] 0 0 hal b

/-- **Two `A` planes read at Boolean points of the same flat index are equal.** -/
theorem aPl_flat (off log off' log' : ℕ) (b : Fin log → Bool) (b' : Fin log' → Bool)
    (h1 : off % 2 ^ rowLog P .a + 2 ^ log ≤ 2 ^ rowLog P .a)
    (h2 : off' % 2 ^ rowLog P .a + 2 ^ log' ≤ 2 ^ rowLog P .a)
    (hr : off / 2 ^ rowLog P .a = off' / 2 ^ rowLog P .a)
    (hc : off % 2 ^ rowLog P .a + msbIndex log b = off' % 2 ^ rowLog P .a + msbIndex log' b') :
    aPl U P D off log b = aPl U P D off' log' b' := by
  rw [aPl_entry U P D off log b h1, aPl_entry U P D off' log' b' h2, hr, hc]

end Entry

end ZK60.Exec.Block.Join.W16.Look
