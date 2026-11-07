/-
D63 lane L21 (2026-11-07), part 6: **a host slot's identity read off its draw vector, and its individual degree**.

`block_defines_fs_knowledge` takes each slot's polynomial `Φ` as a function of the slot's draw vector
(`Fin (P.draws k) → K`) with an individual degree `dg k`. A host's draws are its batch weights `ζ`, `μ_pad`, `μ`, its point
`τ` and its `ν`, each one coordinate of the vector (L11's `draws` / `segOf` say which). This file reads `hostPhi` at such
coordinates and bounds its degree:

* `indDeg_coord`, `indDeg_pow`, `indDeg_sum`, `indDeg_sel`, `indDeg_eqPoly_bit`: a coordinate has degree `1`; powers,
  sums, and a function read at distinct coordinates (`τ`'s);
* `hostPhiAt`, **`hostPhiAt_deg`**: a host's identity at coordinates `iz`, `ip`, `iμ`, `iτ` (injective), `iν` has
  individual degree at most `m + 2` (`m` its pad planes; the crude product count: `eq(τ)` `1`, `μ_pad` `1`, `ζ^j` up to
  `m`), so at most `66` at W16R2 (`m ≤ 64`): within `sched_le_101`'s `80`;
* **`hostPhiAt_nonzero`**: unless the host's start claim holds, some draw vector makes it nonzero, given that the
  coordinates can be written independently (`hsec`: a vector with the chosen values at them).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RelW16Host
import ZK60Formal.StageInExtractSlots

set_option autoImplicit false

namespace ZK60.Sound.SlotW16

open Finset Polynomial

section Deg

variable {F : Type} [Field F]

/-- A coordinate has degree `1` in itself and `0` in the others. -/
theorem indDeg_coord {N : ℕ} (j : Fin N) : IndDegLE 1 (fun x : Fin N → F => x j) := by
  intro i x
  by_cases h : j = i
  · subst h
    exact ⟨X, natDegree_X_le, fun t => by simp⟩
  · exact ⟨C (x j), by rw [natDegree_C]; exact Nat.zero_le _, fun t => by simp [Function.update_of_ne h]⟩

/-- Powers multiply the degree. -/
theorem indDeg_pow {N d : ℕ} {f : (Fin N → F) → F} (hf : IndDegLE d f) :
    ∀ k : ℕ, IndDegLE (d * k) (fun x => f x ^ k)
  | 0 => by simpa using (ZK60.StageX.IndDegLE.const (n := N) (d := 0) (1 : F))
  | k + 1 => by
    have h := ZK60.StageX.IndDegLE.mul (indDeg_pow hf k) hf
    rw [show d * (k + 1) = d * k + d by ring]
    simpa [pow_succ] using h

/-- A finite sum keeps the degree. -/
theorem indDeg_sum {ι : Type} [Fintype ι] {N d : ℕ} {W : ι → (Fin N → F) → F} (hW : ∀ j, IndDegLE d (W j)) :
    IndDegLE d (fun x => ∑ j, W j x) := by
  have h := ZK60.StageX.IndDegLE.wsum hW (fun _ => 1)
  simpa using h

/-- **A function read at distinct coordinates** keeps its individual degree (the other coordinates enter with degree
`0`). -/
theorem indDeg_sel {n N d : ℕ} {f : (Fin n → F) → F} (hf : IndDegLE d f) (σ : Fin n → Fin N)
    (hσ : Function.Injective σ) : IndDegLE d (fun x : Fin N → F => f (fun i => x (σ i))) := by
  intro j x
  by_cases hj : ∃ i, σ i = j
  · obtain ⟨i, rfl⟩ := hj
    obtain ⟨p, hp, hpe⟩ := hf i (fun i' => x (σ i'))
    refine ⟨p, hp, fun t => ?_⟩
    have e : (fun i' => Function.update x (σ i) t (σ i')) = Function.update (fun i' => x (σ i')) i t := by
      funext i'
      by_cases h : i' = i
      · subst h
        simp
      · rw [Function.update_of_ne (hσ.ne h), Function.update_of_ne h]
    show f (fun i' => Function.update x (σ i) t (σ i')) = _
    rw [e]
    exact hpe t
  · refine ⟨C (f (fun i => x (σ i))), by rw [natDegree_C]; exact Nat.zero_le _, fun t => ?_⟩
    have e : (fun i' => Function.update x j t (σ i')) = fun i' => x (σ i') := by
      funext i'
      exact Function.update_of_ne (fun h => hj ⟨i', h⟩) _ _
    show f (fun i' => Function.update x j t (σ i')) = _
    rw [e, eval_C]

/-- `eq(y, b)` at a Boolean point is multilinear in `y` (the extension of `b`'s indicator). -/
theorem indDeg_eqPoly_bit {n : ℕ} (b : Fin n → Bool) :
    IndDegLE 1 (fun y : Fin n → F => eqPoly y (fun i => bit (b i))) := by
  classical
  have e : (fun y : Fin n → F => eqPoly y (fun i => bit (b i)))
      = fun y => mleAt (fun b' => if b' = b then (1 : F) else 0) y := by
    funext y
    unfold mleAt
    rw [Fintype.sum_eq_single b (fun b' hb' => by simp [hb'])]
    simp
  rw [e]
  exact indDegLE_mleAt _

/-- **A host's identity read at coordinates of its draw vector**: `ζ` at `iz`, `μ_pad` at `ip`, `μ_k` at `iμ k`, `τ_i`
at `iτ i`, `ν_i` at `iν i`. -/
def hostPhiAt {n m D : ℕ} {ι : Type} [Fintype ι] (c : ι → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (g : (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F) (iz ip : Fin D)
    (iμ : ι → Fin D) (iτ : Fin n → Fin D) (iν : Fin 2 → Fin D) (x : Fin D → F) : F :=
  hostPhi c w g h M P ((x iz, x ip), fun k => x (iμ k)) (fun i => x (iτ i)) (fun i => x (iν i))

/-- **Its individual degree is at most `m + 2`** (`τ` read at distinct coordinates). -/
theorem hostPhiAt_deg {n m D : ℕ} {ι : Type} [Fintype ι] (c : ι → (Fin n → Bool) → F)
    (w : Fin m → (Fin n → Bool) → F) (g : (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F)
    (P : Fin 2 → Fin n → F) (iz ip : Fin D) (iμ : ι → Fin D) (iτ : Fin n → Fin D) (iν : Fin 2 → Fin D)
    (hτ : Function.Injective iτ) : IndDegLE (m + 2) (hostPhiAt c w g h M P iz ip iμ iτ iν) := by
  have hb : ∀ b, IndDegLE (m + 1)
      (fun x : Fin D → F => batched c w ((x iz, x ip), fun k => x (iμ k)) b) := by
    intro b
    have h1 : IndDegLE (m + 1) (fun x : Fin D → F => ∑ k, x (iμ k) * c k b) := by
      refine indDeg_sum (fun k => ?_)
      exact ZK60.StageX.IndDegLE.mono
        (ZK60.StageX.IndDegLE.mul (indDeg_coord (iμ k)) (ZK60.StageX.IndDegLE.const (d := 0) (c k b))) (by omega)
    have h2 : IndDegLE m (fun x : Fin D → F => ∑ j : Fin m, x iz ^ (j : ℕ) * w j b) := by
      refine indDeg_sum (fun j => ?_)
      refine ZK60.StageX.IndDegLE.mono (ZK60.StageX.IndDegLE.mul (indDeg_pow (indDeg_coord iz) (j : ℕ))
        (ZK60.StageX.IndDegLE.const (d := 0) (w j b))) ?_
      have := j.isLt
      omega
    have h3 : IndDegLE (m + 1) (fun x : Fin D → F => x ip * ∑ j : Fin m, x iz ^ (j : ℕ) * w j b) :=
      ZK60.StageX.IndDegLE.mono (ZK60.StageX.IndDegLE.mul (indDeg_coord ip) h2) (by omega)
    exact ZK60.StageX.IndDegLE.add h1 h3
  have heq : ∀ b : Fin n → Bool, IndDegLE 1 (fun x : Fin D → F => eqPoly (fun i => x (iτ i)) (fun i => bit (b i))) :=
    fun b => indDeg_sel (indDeg_eqPoly_bit b) iτ hτ
  have e : hostPhiAt c w g h M P iz ip iμ iτ iν = fun x => (∑ b : Fin n → Bool, eqPoly (fun i => x (iτ i)) (fun i => bit (b i))
      * batched c w ((x iz, x ip), fun k => x (iμ k)) b)
      + ∑ i, x (iν i) * (mleAt (fun b => g b * h i b) (P i) - mleAt (M i) (P i)) := by
    funext x
    simp only [hostPhiAt, hostPhi_eq, mleAt]
  rw [e]
  refine ZK60.StageX.IndDegLE.add ?_ ?_
  · refine indDeg_sum (fun b => ?_)
    have := ZK60.StageX.IndDegLE.mul (heq b) (hb b)
    rw [show 1 + (m + 1) = m + 2 by omega] at this
    exact this
  · refine indDeg_sum (fun i => ?_)
    exact ZK60.StageX.IndDegLE.mono (ZK60.StageX.IndDegLE.mul (indDeg_coord (iν i))
      (ZK60.StageX.IndDegLE.const (d := 0) (mleAt (fun b => g b * h i b) (P i) - mleAt (M i) (P i)))) (by omega)

/-- **Unless the host's start claim holds, some draw vector makes its identity nonzero**, given that any values can be
written at its coordinates (`hsec`). -/
theorem hostPhiAt_nonzero [Fintype F] [DecidableEq F] {n m D : ℕ} {ι : Type} [Fintype ι] [DecidableEq ι]
    (c : ι → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F) (g : (Fin n → Bool) → F)
    (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F) (iz ip : Fin D) (iμ : ι → Fin D)
    (iτ : Fin n → Fin D) (iν : Fin 2 → Fin D) (hm : m < Fintype.card F)
    (hsec : ∀ (ω : (F × F) × (ι → F)) (τ : Fin n → F) (ν : Fin 2 → F), ∃ x : Fin D → F,
      ((x iz, x ip), fun k => x (iμ k)) = ω ∧ (fun i => x (iτ i)) = τ ∧ (fun i => x (iν i)) = ν)
    (hG : ¬ hostGd c w g h M P) : ∃ x, hostPhiAt c w g h M P iz ip iμ iτ iν x ≠ 0 := by
  obtain ⟨ω, τ, ν, hne⟩ := hostPhi_nonzero c w g h M P hm hG
  obtain ⟨x, h1, h2, h3⟩ := hsec ω τ ν
  refine ⟨x, ?_⟩
  rw [hostPhiAt, h1, h2, h3]
  exact hne

end Deg

end ZK60.Sound.SlotW16
