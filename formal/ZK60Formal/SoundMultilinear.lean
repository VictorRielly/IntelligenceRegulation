/-
D63, step L3 (soundness of the IOP): the sumcheck on the code's own form, `poly` of multilinear tables.

`zkp_core::sumcheck::prove` proves `Σ_{x ∈ {0,1}^n} poly(tables[0][x], …, tables[k−1][x])`; after the rounds every
table is folded to its multilinear extension at the challenge point (`finals`), and the caller checks the final claim
against `poly(finals)`. This file discharges `SoundSumcheck`'s individual-degree hypothesis for that form:
* `eqPoly_bit`, `mleAt_bit`: on the cube the multilinear extension `T̃(x) = Σ_b eq(x, b)·T(b)` takes the table's values;
* `indDegLE_mleAt`: `T̃` has degree at most `1` in each variable;
* `natDegree_aeval_le`, `eval_aeval_eq`: a polynomial of total degree `≤ d` in affine functions of one variable is a
  polynomial of degree `≤ d` in it;
* `indDegLE_mle_comp`: so `poly(T̃₁(x), …, T̃ₖ(x))` has individual degree at most `poly`'s total degree;
* `sumcheck_sound_tables`: the sumcheck theorem in the code's terms. If the claim `C` differs from
  `Σ_b poly(T₁(b), …, Tₖ(b))` and `poly` has total degree `≤ d`, any prover is accepted with probability at most
  `n·d / |F|`, the terminal check being `poly(T̃₁(r), …, T̃ₖ(r))`.

The code's `poly` is a closure and its `degree` argument is a declaration: the theorem needs `degree ≥` the true degree
of `poly` (otherwise an honest proof fails, and the bound must be read with the true degree).
-/
import ZK60Formal.SoundZeroCheck
import Mathlib.Algebra.MvPolynomial.Degrees

namespace ZK60.Sound

open scoped ENNReal
open Polynomial Finset

variable {F : Type} [Field F]

/-- On Boolean points `eq` is the indicator: `eq(b, b') = 1` if `b = b'` and `0` otherwise. -/
theorem eqPoly_bit {n : ℕ} (b b' : Fin n → Bool) :
    eqPoly (fun i => bit (b i)) (fun i => (bit (b' i) : F)) = if b = b' then 1 else 0 := by
  classical
  unfold eqPoly
  split_ifs with h
  · subst h
    refine prod_eq_one (fun i _ => ?_)
    cases h : b i <;> simp [bit, h]
  · have : ∃ i, b i ≠ b' i := by
      by_contra hc
      exact h (funext fun i => by_contra fun hne => hc ⟨i, hne⟩)
    obtain ⟨i, hi⟩ := this
    refine prod_eq_zero (mem_univ i) ?_
    cases hb : b i <;> cases hb' : b' i <;> simp_all [bit]

/-- On the cube the multilinear extension takes the table's values. -/
theorem mleAt_bit {n : ℕ} (P : (Fin n → Bool) → F) (b : Fin n → Bool) :
    mleAt P (fun i => bit (b i)) = P b := by
  classical
  unfold mleAt
  rw [Fintype.sum_eq_single b (fun b' hb' => by simp [eqPoly_bit, Ne.symm hb'])]
  simp [eqPoly_bit]

/-- The multilinear extension has degree at most `1` in each variable. -/
theorem indDegLE_mleAt {n : ℕ} (P : (Fin n → Bool) → F) : IndDegLE 1 (fun x => mleAt P x) := by
  intro i x
  let c : (Fin n → Bool) → F := fun b =>
    ∏ j ∈ ({i}ᶜ : Finset (Fin n)), (x j * bit (b j) + (1 - x j) * (1 - bit (b j)))
  refine ⟨∑ b, C (c b * P b) * (X * C (bit (b i)) + (1 - X) * (1 - C (bit (b i)))), ?_, fun s => ?_⟩
  · refine natDegree_sum_le_of_forall_le _ _ (fun b _ => ?_)
    refine (natDegree_C_mul_le _ _).trans ?_
    compute_degree
  · simp only [mleAt, eval_finsetSum, eval_mul, eval_C, eval_add, eval_X, eval_sub, eval_one]
    refine sum_congr rfl (fun b _ => ?_)
    have h : eqPoly (Function.update x i s) (fun j => bit (b j))
        = (s * bit (b i) + (1 - s) * (1 - bit (b i))) * c b := by
      unfold eqPoly
      rw [Fintype.prod_eq_mul_prod_compl i, Function.update_self]
      congr 1
      refine prod_congr rfl (fun j hj => ?_)
      rw [Function.update_of_ne (by simpa using hj)]
    rw [h]
    ring

/-- A polynomial of total degree `≤ D` in polynomials of degree `≤ 1` has degree `≤ D`. -/
theorem natDegree_aeval_le {k : ℕ} (g : Fin k → F[X]) (hg : ∀ t, (g t).natDegree ≤ 1)
    (p : MvPolynomial (Fin k) F) : (MvPolynomial.aeval g p).natDegree ≤ p.totalDegree := by
  classical
  conv_lhs => rw [p.as_sum]
  rw [map_sum]
  refine natDegree_sum_le_of_forall_le _ _ (fun s hs => ?_)
  rw [MvPolynomial.aeval_monomial, ← Polynomial.C_eq_algebraMap]
  refine (natDegree_C_mul_le _ _).trans ?_
  rw [Finsupp.prod]
  refine (natDegree_prod_le _ _).trans ?_
  refine le_trans (sum_le_sum (fun i _ => natDegree_pow_le.trans (Nat.mul_le_mul_left _ (hg i)))) ?_
  simp only [mul_one]
  exact MvPolynomial.le_totalDegree hs

/-- Evaluating `aeval g p` at `s` is evaluating `p` at the values `g_t(s)`. -/
theorem eval_aeval_eq {k : ℕ} (g : Fin k → F[X]) (p : MvPolynomial (Fin k) F) (s : F) :
    (MvPolynomial.aeval g p).eval s = MvPolynomial.eval (fun t => (g t).eval s) p := by
  have h1 : (Polynomial.evalRingHom s).comp (algebraMap F F[X]) = RingHom.id F := by
    ext a
    simp
  rw [MvPolynomial.aeval_def, ← Polynomial.coe_evalRingHom, MvPolynomial.eval₂_comp_left, h1]
  rfl

/-- **The code's form has the individual degree of `poly`.** For tables `T₁, …, Tₖ` on the cube and `poly` of total
degree at most `d`, `x ↦ poly(T̃₁(x), …, T̃ₖ(x))` has degree at most `d` in each variable. -/
theorem indDegLE_mle_comp {n k d : ℕ} (T : Fin k → (Fin n → Bool) → F) (poly : MvPolynomial (Fin k) F)
    (hp : poly.totalDegree ≤ d) : IndDegLE d (fun x => MvPolynomial.eval (fun t => mleAt (T t) x) poly) := by
  intro i x
  choose L hL hLe using fun t => indDegLE_mleAt (T t) i x
  refine ⟨MvPolynomial.aeval L poly, (natDegree_aeval_le L hL poly).trans hp, fun s => ?_⟩
  show MvPolynomial.eval (fun t => mleAt (T t) (Function.update x i s)) poly = _
  rw [eval_aeval_eq]
  exact congrArg (fun v => MvPolynomial.eval v poly) (funext fun t => hLe t s)

/-- On the cube the claim is about the tables themselves: `Σ_x poly(T̃(x)) = Σ_b poly(T(b))`. -/
theorem cubeSum_mle_comp {n k : ℕ} (T : Fin k → (Fin n → Bool) → F) (poly : MvPolynomial (Fin k) F) :
    cubeSum (fun x => MvPolynomial.eval (fun t => mleAt (T t) x) poly)
      = ∑ b : Fin n → Bool, MvPolynomial.eval (fun t => T t b) poly := by
  simp only [cubeSum, mleAt_bit]

variable [Fintype F] [DecidableEq F]

/-- **Sumcheck soundness in the code's terms.** Let `T₁, …, Tₖ` be tables on `{0,1}^n` and `poly` a polynomial of
total degree at most `d < char F`. If the claim `C` is not `Σ_b poly(T₁(b), …, Tₖ(b))`, then for ANY prover strategy
the verifier, whose terminal check is `poly(T̃₁(r), …, T̃ₖ(r))` (the code's `poly(finals)`), accepts with probability
at most `n·d / |F|`. -/
theorem sumcheck_sound_tables {n k d : ℕ} (hd : d < ringChar F) (T : Fin k → (Fin n → Bool) → F)
    (poly : MvPolynomial (Fin k) F) (hp : poly.totalDegree ≤ d) {C : F}
    (hC : C ≠ ∑ b : Fin n → Bool, MvPolynomial.eval (fun t => T t b) poly) (P : Prover F d n) :
    (PMF.uniformOfFintype (Fin n → F)).toOuterMeasure
        {r | Accepts n (fun x => MvPolynomial.eval (fun t => mleAt (T t) x) poly) C P r}
      ≤ ((n * d : ℕ) : ℝ≥0∞) / Fintype.card F :=
  sumcheck_sound hd (indDegLE_mle_comp T poly hp) (by rwa [cubeSum_mle_comp]) P

end ZK60.Sound
