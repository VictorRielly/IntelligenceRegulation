/-
D63, step L3 (soundness of the IOP): the zero-check and the batching of relations.

The code proves that a relation `R` vanishes on the whole Boolean cube (the LogUp helper relations, the range and
norm relations of every zero-check slot) by drawing a point `τ` (`tr.challenge_fp2_vec(log n)`) and running the
sumcheck on `eq(τ, x)·R(x)` with the claim `0` (`b.eq(&tau, 0)`; `eq_point`, `eq_table_msb`). Several relations of
one slot are first batched with independent coefficients `μ` (`tr.challenge_fp2_vec(k)`).

What is proved (interactive, challenges uniform and independent):
* `mle_zero_card_le`, `mle_zero_prob`: if `R` is nonzero somewhere on the cube, `Σ_b eq(τ, b)·R(b)` (the multilinear
  extension of `R`'s cube values at `τ`) vanishes with probability at most `n / |F|`;
* `zerocheck_sound`: the zero-check composed with the sumcheck. If `R` (individual degree `≤ d`) is nonzero somewhere
  on the cube, then for ANY prover strategy, which may depend on `τ`, the verifier accepts the claim
  `Σ_x eq(τ, x)·R(x) = 0` with probability at most `(n + n·(d + 1)) / |F|` over `τ` and the sumcheck challenges;
* `batch_prob`: a nonzero vector of relation values is killed by independent uniform batching coefficients with
  probability at most `1 / |F|`.
-/
import ZK60Formal.SoundSumcheck

namespace ZK60.Sound

open scoped ENNReal
open Polynomial Finset

variable {F : Type} [Field F]

/-- The equality polynomial `eq(τ, x) = Π_i (τ_i x_i + (1 − τ_i)(1 − x_i))` (`mle::eq_point`). -/
def eqPoly {n : ℕ} (τ x : Fin n → F) : F := ∏ i, (τ i * x i + (1 - τ i) * (1 - x i))

/-- The multilinear extension at `τ` of the cube values `P`: `Σ_b eq(τ, b)·P(b)`. -/
def mleAt {n : ℕ} (P : (Fin n → Bool) → F) (τ : Fin n → F) : F :=
  ∑ b : Fin n → Bool, eqPoly τ (fun i => bit (b i)) * P b

/-- The zero-check's claim IS the multilinear extension of `R`'s cube values at `τ`. -/
theorem cubeSum_eq_mul {n : ℕ} (τ : Fin n → F) (R : (Fin n → F) → F) :
    cubeSum (fun x => eqPoly τ x * R x) = mleAt (fun b => R (fun i => bit (b i))) τ := rfl

/-- Splitting a sum over `{0,1}^(n+1)` on the first bit. -/
theorem sum_bool_cons {M : Type} [AddCommMonoid M] {n : ℕ} (g : (Fin (n + 1) → Bool) → M) :
    ∑ b, g b = ∑ b : Fin n → Bool, g (Fin.cons false b) + ∑ b : Fin n → Bool, g (Fin.cons true b) := by
  rw [← Fintype.sum_equiv (Fin.consEquiv (fun _ => Bool)) (fun p => g (Fin.cons p.1 p.2)) g (fun _ => rfl),
    Fintype.sum_prod_type, Fintype.sum_bool, add_comm]

/-- Peeling the first coordinate of `τ`: `mle(t, τ') = (1 − t)·mle₀(τ') + t·mle₁(τ')`. -/
theorem mleAt_cons {n : ℕ} (P : (Fin (n + 1) → Bool) → F) (t : F) (τ : Fin n → F) :
    mleAt P (Fin.cons t τ) = (1 - t) * mleAt (fun b => P (Fin.cons false b)) τ
      + t * mleAt (fun b => P (Fin.cons true b)) τ := by
  simp only [mleAt]
  rw [sum_bool_cons, mul_sum, mul_sum]
  congr 1 <;> refine sum_congr rfl (fun b _ => ?_) <;> simp [eqPoly, Fin.prod_univ_succ, bit] <;> ring

variable [Fintype F] [DecidableEq F]

/-- Counting tuples of length `n + 1` by their tail. -/
theorem card_filter_cons_tail {α : Type} [Fintype α] [DecidableEq α] {n : ℕ} (E : (Fin (n + 1) → α) → Prop)
    [DecidablePred E] :
    (univ.filter E).card = ∑ x : Fin n → α, (univ.filter (fun a : α => E (Fin.cons a x))).card := by
  rw [card_filter, ← Fintype.sum_equiv (Fin.consEquiv (fun _ => α))
    (fun p => if E (Fin.cons p.1 p.2) then 1 else 0) _ (fun _ => rfl), Fintype.sum_prod_type_right]
  refine sum_congr rfl (fun x _ => ?_)
  rw [card_filter]

/-- A line `t ↦ (1 − t)·A + t·B` vanishes at no more than one point unless `A = B = 0`. -/
theorem card_line_zero_le (A B : F) :
    (univ.filter (fun t : F => (1 - t) * A + t * B = 0)).card ≤ if A = 0 ∧ B = 0 then Fintype.card F else 1 := by
  split_ifs with h
  · exact (card_filter_le _ _).trans (by simp)
  · refine card_le_one.mpr (fun t₁ h₁ t₂ h₂ => ?_)
    simp only [mem_filter, mem_univ, true_and] at h₁ h₂
    have : (t₁ - t₂) * (B - A) = 0 := by linear_combination h₁ - h₂
    rcases mul_eq_zero.mp this with h3 | h3
    · exact sub_eq_zero.mp h3
    · exfalso
      have hBA : B = A := sub_eq_zero.mp h3
      have hA : A = 0 := by
        have := h₁
        rw [hBA] at this
        linear_combination this
      exact h ⟨hA, hBA.trans hA⟩

open Classical in
/-- **Schwartz–Zippel for the multilinear extension, counted.** If `P` is nonzero somewhere on the cube, at most
`n·|F|^(n−1)` points `τ` make its multilinear extension vanish (written: times `|F|`, at most `n·|F|^n`). -/
theorem mle_zero_card_le : ∀ (n : ℕ) (P : (Fin n → Bool) → F), (∃ b, P b ≠ 0) →
    (univ.filter (fun τ : Fin n → F => mleAt P τ = 0)).card * Fintype.card F ≤ n * Fintype.card F ^ n := by
  intro n
  induction n with
  | zero =>
    intro P ⟨b, hb⟩
    have : ∀ τ : Fin 0 → F, mleAt P τ = P b := by
      intro τ
      rw [mleAt, Fintype.sum_eq_single b (fun b' hb' => absurd (Subsingleton.elim b' b) hb')]
      simp [eqPoly]
    simp [this, hb]
  | succ n ih =>
    intro P hP
    set P0 : (Fin n → Bool) → F := fun b => P (Fin.cons false b)
    set P1 : (Fin n → Bool) → F := fun b => P (Fin.cons true b)
    have hP01 : (∃ b, P0 b ≠ 0) ∨ (∃ b, P1 b ≠ 0) := by
      obtain ⟨b, hb⟩ := hP
      have hb' : P (Fin.cons (b 0) (Fin.tail b)) ≠ 0 := by rwa [Fin.cons_self_tail]
      cases h0 : b 0
      · exact Or.inl ⟨Fin.tail b, by simpa [P0, h0] using hb'⟩
      · exact Or.inr ⟨Fin.tail b, by simpa [P1, h0] using hb'⟩
    -- the τ' at which both halves vanish are counted by the induction hypothesis
    have hboth : (univ.filter (fun τ : Fin n → F => mleAt P0 τ = 0 ∧ mleAt P1 τ = 0)).card * Fintype.card F
        ≤ n * Fintype.card F ^ n := by
      rcases hP01 with h | h
      · refine le_trans (Nat.mul_le_mul_right _ (card_le_card ?_)) (ih P0 h)
        intro τ hτ
        simp only [mem_filter, mem_univ, true_and] at hτ ⊢
        exact hτ.1
      · refine le_trans (Nat.mul_le_mul_right _ (card_le_card ?_)) (ih P1 h)
        intro τ hτ
        simp only [mem_filter, mem_univ, true_and] at hτ ⊢
        exact hτ.2
    rw [card_filter_cons_tail, sum_mul]
    have hslice : ∀ τ : Fin n → F,
        (univ.filter (fun t : F => mleAt P (Fin.cons t τ) = 0)).card * Fintype.card F
          ≤ Fintype.card F + (if mleAt P0 τ = 0 ∧ mleAt P1 τ = 0 then Fintype.card F * Fintype.card F else 0) := by
      intro τ
      have hc := card_line_zero_le (mleAt P0 τ) (mleAt P1 τ)
      have hset : univ.filter (fun t : F => mleAt P (Fin.cons t τ) = 0)
          = univ.filter (fun t : F => (1 - t) * mleAt P0 τ + t * mleAt P1 τ = 0) := by
        refine filter_congr (fun t _ => ?_)
        rw [mleAt_cons]
      rw [hset]
      split_ifs at hc ⊢ with h
      · exact le_trans (Nat.mul_le_mul_right _ hc) (Nat.le_add_left _ _)
      · rw [add_zero]
        exact le_trans (Nat.mul_le_mul_right _ hc) (by simp)
    refine (sum_le_sum (fun τ _ => hslice τ)).trans ?_
    rw [sum_add_distrib, ← sum_filter, sum_const, sum_const, card_univ, smul_eq_mul, smul_eq_mul,
      Fintype.card_fun, Fintype.card_fin]
    have h2 := Nat.mul_le_mul_right (Fintype.card F) hboth
    calc Fintype.card F ^ n * Fintype.card F
          + (univ.filter (fun τ : Fin n → F => mleAt P0 τ = 0 ∧ mleAt P1 τ = 0)).card
            * (Fintype.card F * Fintype.card F)
        = Fintype.card F ^ n * Fintype.card F
          + (univ.filter (fun τ : Fin n → F => mleAt P0 τ = 0 ∧ mleAt P1 τ = 0)).card * Fintype.card F
            * Fintype.card F := by ring
      _ ≤ Fintype.card F ^ n * Fintype.card F + n * Fintype.card F ^ n * Fintype.card F :=
          Nat.add_le_add_left h2 _
      _ = (n + 1) * Fintype.card F ^ (n + 1) := by ring

omit [DecidableEq F] in
/-- **Schwartz–Zippel for the multilinear extension.** If `P` is nonzero somewhere on the cube, a uniform `τ` makes
`Σ_b eq(τ, b)·P(b)` vanish with probability at most `n / |F|`. -/
theorem mle_zero_prob {n : ℕ} (P : (Fin n → Bool) → F) (hP : ∃ b, P b ≠ 0) :
    (PMF.uniformOfFintype (Fin n → F)).toOuterMeasure {τ | mleAt P τ = 0} ≤ (n : ℝ≥0∞) / Fintype.card F := by
  classical
  refine prob_of_count _ n ?_
  intro _
  convert mle_zero_card_le n P hP

omit [Fintype F] [DecidableEq F] in
/-- `eq(τ, ·)·R` has individual degree `≤ d + 1` when `R` has individual degree `≤ d`: `eq` is multilinear. -/
theorem IndDegLE.eq_mul {n d : ℕ} {R : (Fin n → F) → F} (hR : IndDegLE d R) (τ : Fin n → F) :
    IndDegLE (d + 1) (fun x => eqPoly τ x * R x) := by
  intro i x
  obtain ⟨p, hp, hpe⟩ := hR i x
  set c := ∏ j ∈ ({i}ᶜ : Finset (Fin n)), (τ j * x j + (1 - τ j) * (1 - x j))
  refine ⟨(C (τ i) * X + C (1 - τ i) * (1 - X)) * C c * p, ?_, fun t => ?_⟩
  · refine (natDegree_mul_le).trans ?_
    have h1 : ((C (τ i) * X + C (1 - τ i) * (1 - X)) * C c).natDegree ≤ 1 := by compute_degree
    omega
  · have hprod : eqPoly τ (Function.update x i t) = (τ i * t + (1 - τ i) * (1 - t)) * c := by
      unfold eqPoly
      rw [Fintype.prod_eq_mul_prod_compl i, Function.update_self]
      congr 1
      refine prod_congr rfl (fun j hj => ?_)
      rw [Function.update_of_ne (by simpa using hj)]
    show eqPoly τ (Function.update x i t) * R (Function.update x i t) = _
    rw [hpe t, hprod]
    simp only [eval_mul, eval_add, eval_C, eval_X, eval_sub, eval_one]

/-- **The zero-check, end to end (interactive).** Let `R` have individual degree `≤ d` and be nonzero somewhere on
the cube. The verifier draws `τ`, then runs the sumcheck of `eq(τ, x)·R(x)` (round degree `d + 1`) on the claim `0`
against a prover that may choose its strategy after seeing `τ`. It accepts with probability at most
`(n + n·(d + 1)) / |F|`: `n/|F|` for a `τ` at which the multilinear extension vanishes, `n·(d + 1)/|F|` for the
sumcheck of the then-false claim. -/
theorem zerocheck_sound {n d : ℕ} (hd : d + 1 < ringChar F) {R : (Fin n → F) → F} (hR : IndDegLE d R)
    (hnz : ∃ b : Fin n → Bool, R (fun i => bit (b i)) ≠ 0) (P : (Fin n → F) → Prover F (d + 1) n) :
    (PMF.uniformOfFintype ((Fin n → F) × (Fin n → F))).toOuterMeasure
        {ω | Accepts n (fun x => eqPoly ω.1 x * R x) 0 (P ω.1) ω.2}
      ≤ ((n + n * (d + 1) : ℕ) : ℝ≥0∞) / Fintype.card F := by
  classical
  refine prob_le_of_card_mul _ _ (Fintype.card F) Fintype.card_ne_zero ?_
  rw [card_filter_prod, sum_mul]
  have hslice : ∀ τ : Fin n → F,
      (univ.filter (fun ρ : Fin n → F => Accepts n (fun x => eqPoly τ x * R x) 0 (P τ) ρ)).card * Fintype.card F
        ≤ (if mleAt (fun b => R (fun i => bit (b i))) τ = 0 then Fintype.card F ^ n * Fintype.card F else 0)
          + n * (d + 1) * Fintype.card F ^ n := by
    intro τ
    split_ifs with h
    · refine le_trans (Nat.mul_le_mul_right _ ((card_filter_le _ _).trans ?_)) (Nat.le_add_right _ _)
      simp
    · rw [zero_add]
      have hC : (0 : F) ≠ cubeSum (fun x => eqPoly τ x * R x) := by
        rw [cubeSum_eq_mul]
        exact Ne.symm h
      convert card_accepts_le hd n _ (hR.eq_mul τ) 0 hC (P τ) using 2
  refine (sum_le_sum (fun τ _ => hslice τ)).trans ?_
  rw [sum_add_distrib, ← sum_filter, sum_const, sum_const, card_univ, smul_eq_mul, smul_eq_mul,
    Fintype.card_prod, Fintype.card_fun, Fintype.card_fin]
  have hz := Nat.mul_le_mul_right (Fintype.card F ^ n)
    (mle_zero_card_le n (fun b => R (fun i => bit (b i))) hnz)
  calc (univ.filter (fun τ : Fin n → F => mleAt (fun b => R (fun i => bit (b i))) τ = 0)).card
          * (Fintype.card F ^ n * Fintype.card F)
        + Fintype.card F ^ n * (n * (d + 1) * Fintype.card F ^ n)
      = (univ.filter (fun τ : Fin n → F => mleAt (fun b => R (fun i => bit (b i))) τ = 0)).card
          * Fintype.card F * Fintype.card F ^ n
        + Fintype.card F ^ n * (n * (d + 1) * Fintype.card F ^ n) := by ring
    _ ≤ n * Fintype.card F ^ n * Fintype.card F ^ n + Fintype.card F ^ n * (n * (d + 1) * Fintype.card F ^ n) :=
        Nat.add_le_add_right hz _
    _ = (n + n * (d + 1)) * (Fintype.card F ^ n * Fintype.card F ^ n) := by ring

/-- **Batching.** If the relation values `v` are not all zero, independent uniform coefficients `μ` give
`Σ_k μ_k v_k = 0` with probability at most `1 / |F|`. (The code draws `μ` with `tr.challenge_fp2_vec`, independent
coefficients, at every batched slot but one; see the findings for `SC_LZC`.) -/
theorem batch_prob {K : Type} [Fintype K] [DecidableEq K] (v : K → F) (hv : ∃ k, v k ≠ 0) :
    (PMF.uniformOfFintype (K → F)).toOuterMeasure {μ | ∑ k, μ k * v k = 0} ≤ (1 : ℝ≥0∞) / Fintype.card F := by
  classical
  obtain ⟨k₀, hk₀⟩ := hv
  rw [show (1 : ℝ≥0∞) = ((1 : ℕ) : ℝ≥0∞) from Nat.cast_one.symm]
  refine prob_le_of_card_mul (fun μ : K → F => ∑ k, μ k * v k = 0) 1 (Fintype.card F) Fintype.card_ne_zero ?_
  -- for each choice of the other coefficients, exactly one value of `μ k₀` solves the equation
  let e := Equiv.piSplitAt k₀ (fun _ : K => F)
  have hcard : (univ.filter (fun μ : K → F => ∑ k, μ k * v k = 0)).card
      ≤ (univ : Finset ({k // k ≠ k₀} → F)).card := by
    refine card_le_card_of_injOn (fun μ => (e μ).2) (fun _ _ => mem_univ _) ?_
    intro μ₁ h₁' μ₂ h₂' h12
    have h₁ : ∑ k, μ₁ k * v k = 0 := by simpa using h₁'
    have h₂ : ∑ k, μ₂ k * v k = 0 := by simpa using h₂'
    have hrest : ∀ k, k ≠ k₀ → μ₁ k = μ₂ k := fun k hk => congrFun h12 ⟨k, hk⟩
    have hsplit : ∀ μ : K → F, ∑ k, μ k * v k = μ k₀ * v k₀ + ∑ k ∈ ({k₀}ᶜ : Finset K), μ k * v k :=
      fun μ => Fintype.sum_eq_add_sum_compl k₀ _
    have hsum : ∑ k ∈ ({k₀}ᶜ : Finset K), μ₁ k * v k = ∑ k ∈ ({k₀}ᶜ : Finset K), μ₂ k * v k :=
      sum_congr rfl (fun k hk => by rw [hrest k (by simpa using hk)])
    have h0 : μ₁ k₀ = μ₂ k₀ := by
      have := h₁.trans h₂.symm
      rw [hsplit, hsplit, hsum] at this
      exact mul_right_cancel₀ hk₀ (add_right_cancel this)
    funext k
    by_cases hk : k = k₀
    · subst hk; exact h0
    · exact hrest k hk
  have hsize : Fintype.card ({k // k ≠ k₀} → F) * Fintype.card F = Fintype.card (K → F) := by
    rw [Fintype.card_congr e, Fintype.card_prod, mul_comm]
  calc (univ.filter (fun μ : K → F => ∑ k, μ k * v k = 0)).card * Fintype.card F
      ≤ (univ : Finset ({k // k ≠ k₀} → F)).card * Fintype.card F := Nat.mul_le_mul_right _ hcard
    _ = 1 * Fintype.card (K → F) := by rw [card_univ, hsize, one_mul]

end ZK60.Sound
