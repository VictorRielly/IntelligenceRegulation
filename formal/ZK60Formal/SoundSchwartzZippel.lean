/-
D63, step L3 (soundness of the IOP), first lemma: the univariate Schwartz–Zippel bound.

A nonzero polynomial of degree at most `d` over a finite field `F` has at most `d` roots, so a uniformly random point
is one of them with probability at most `d / |F|`. Every interactive soundness term of our count is a sum of such
fractions: one per sumcheck round (the round polynomial's degree over `|Fp2|`), the LogUp challenge (the cleared
LogUp polynomial's degree over `|Fp2|`), the zero-check point. This file states the bound in the form the other
`Sound*` files use: probabilities are `ENNReal`-valued, through `PMF.uniformOfFintype` and `toOuterMeasure`, as in
`Statements.lean`.

What is here:
* `prob_le_of_card`, `prob_le_of_card_filter`: a uniform probability is at most a count over the size of the space;
* `prob_le_of_card_mul`: the same with the count scaled (`|E|·q ≤ k·|Ω|` gives `Pr[E] ≤ k/q`), and
  `card_filter_prod`: counting pairs by their first entry;
* `card_roots_le`: a nonzero polynomial vanishes at most at `natDegree` points of a finite field;
* `schwartzZippel`: `Pr_r[p(r) = 0] ≤ d / |F|` for nonzero `p` of degree `≤ d`;
* `schwartzZippel_ne`: two different polynomials of degree `≤ d` agree at a random point with probability `≤ d / |F|`.
-/
import Mathlib.Algebra.Polynomial.Roots
import Mathlib.Probability.ProbabilityMassFunction.Constructions
import Mathlib.Probability.Distributions.Uniform

namespace ZK60.Sound

open scoped ENNReal
open Polynomial

/-- A uniform probability is at most a count over the size of the space: if the event `S` has at most `k` elements,
its probability under the uniform distribution is at most `k / |α|`. -/
theorem prob_le_of_card {α : Type} [Fintype α] [Nonempty α] (S : Set α) (k : ℕ)
    (h : Nat.card S ≤ k) :
    (PMF.uniformOfFintype α).toOuterMeasure S ≤ (k : ℝ≥0∞) / Fintype.card α := by
  classical
  rw [PMF.toOuterMeasure_uniformOfFintype_apply]
  rw [Nat.card_eq_fintype_card] at h
  exact ENNReal.div_le_div_right (by exact_mod_cast h) _

/-- The same with the count written as a filtered `Finset`, the form most counting proofs produce. -/
theorem prob_le_of_card_filter {α : Type} [Fintype α] [Nonempty α] (E : α → Prop) [DecidablePred E] (k : ℕ)
    (h : (Finset.univ.filter E).card ≤ k) :
    (PMF.uniformOfFintype α).toOuterMeasure {a | E a} ≤ (k : ℝ≥0∞) / Fintype.card α := by
  refine prob_le_of_card _ k ?_
  rw [Nat.card_eq_fintype_card, Fintype.card_ofFinset]
  simpa using h

/-- A count scaled by `q`: if `|E| · q ≤ k · |Ω|`, then `Pr[E] ≤ k / q`. With `Ω = F^n` and `q = |F|` this turns a count
of `k·|F|^(n−1)` bad points into the probability `k / |F|` without a subtraction in the exponent. -/
theorem prob_le_of_card_mul {Ω : Type} [Fintype Ω] [Nonempty Ω] (E : Ω → Prop) [DecidablePred E] (k q : ℕ)
    (hq : q ≠ 0) (h : (Finset.univ.filter E).card * q ≤ k * Fintype.card Ω) :
    (PMF.uniformOfFintype Ω).toOuterMeasure {ω | E ω} ≤ (k : ℝ≥0∞) / q := by
  rw [PMF.toOuterMeasure_uniformOfFintype_apply, Fintype.card_ofFinset]
  have hq0 : (q : ℝ≥0∞) ≠ 0 := by exact_mod_cast hq
  have hqt : (q : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
  have hΩ0 : (Fintype.card Ω : ℝ≥0∞) ≠ 0 := by exact_mod_cast Fintype.card_ne_zero
  have hΩt : (Fintype.card Ω : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
  have hfilt : (Finset.univ.filter (fun ω => ω ∈ {ω | E ω})) = Finset.univ.filter E := by
    ext ω
    simp
  rw [hfilt]
  calc ((Finset.univ.filter E).card : ℝ≥0∞) / Fintype.card Ω
      = ((Finset.univ.filter E).card * q : ℝ≥0∞) / (Fintype.card Ω * q) :=
        (ENNReal.mul_div_mul_right _ _ hq0 hqt).symm
    _ ≤ ((k * Fintype.card Ω : ℕ) : ℝ≥0∞) / (Fintype.card Ω * q) := by
        gcongr
        exact_mod_cast h
    _ = (k : ℝ≥0∞) / q := by
        rw [Nat.cast_mul, mul_comm (Fintype.card Ω : ℝ≥0∞) (q : ℝ≥0∞)]
        exact ENNReal.mul_div_mul_right _ _ hΩ0 hΩt

/-- Counting pairs by their first entry. -/
theorem card_filter_prod {α β : Type} [Fintype α] [Fintype β] (E : α × β → Prop) [DecidablePred E] :
    (Finset.univ.filter E).card = ∑ a : α, (Finset.univ.filter (fun b : β => E (a, b))).card := by
  rw [Finset.card_filter, Fintype.sum_prod_type]
  refine Finset.sum_congr rfl (fun a _ => ?_)
  rw [Finset.card_filter]

variable {F : Type} [Field F] [Fintype F] [DecidableEq F]

/-- A nonzero polynomial over a finite field vanishes at no more points than its degree. -/
theorem card_roots_le (p : F[X]) (hp : p ≠ 0) :
    (Finset.univ.filter (fun r => p.eval r = 0)).card ≤ p.natDegree := by
  refine le_trans ?_ (card_roots' p)
  refine le_trans (Finset.card_le_card ?_) (Multiset.toFinset_card_le p.roots)
  intro r hr
  simp only [Finset.mem_filter, Finset.mem_univ, true_and] at hr
  simp only [Multiset.mem_toFinset, mem_roots hp, IsRoot.def, hr]

omit [DecidableEq F] in
/-- **Schwartz–Zippel, univariate.** For a nonzero polynomial `p` of degree at most `d` over a finite field `F`, a
uniformly random `r` is a root of `p` with probability at most `d / |F|`. -/
theorem schwartzZippel {p : F[X]} (hp : p ≠ 0) {d : ℕ} (hd : p.natDegree ≤ d) :
    (PMF.uniformOfFintype F).toOuterMeasure {r | p.eval r = 0} ≤ (d : ℝ≥0∞) / Fintype.card F := by
  classical
  exact prob_le_of_card_filter _ d ((card_roots_le p hp).trans hd)

omit [DecidableEq F] in
/-- Two different polynomials of degree at most `d` agree at a uniformly random point with probability at most
`d / |F|`. This is the form a sumcheck round uses: a false round polynomial and the true one are both of degree
`≤ d`, so the next claim stays false except with probability `d / |F|`. -/
theorem schwartzZippel_ne {p q : F[X]} (hpq : p ≠ q) {d : ℕ} (hp : p.natDegree ≤ d) (hq : q.natDegree ≤ d) :
    (PMF.uniformOfFintype F).toOuterMeasure {r | p.eval r = q.eval r} ≤ (d : ℝ≥0∞) / Fintype.card F := by
  have hne : p - q ≠ 0 := sub_ne_zero.mpr hpq
  have hdeg : (p - q).natDegree ≤ d := (natDegree_sub_le p q).trans (max_le hp hq)
  have hset : {r | p.eval r = q.eval r} = {r | (p - q).eval r = 0} := by
    ext r
    simp [sub_eq_zero]
  rw [hset]
  exact schwartzZippel hne hdeg

end ZK60.Sound
