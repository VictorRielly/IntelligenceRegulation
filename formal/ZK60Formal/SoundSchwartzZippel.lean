/-
D63, step L3 (soundness of the IOP), first lemma: the univariate Schwartz–Zippel bound.

A nonzero polynomial of degree at most `d` over a finite field `F` has at most `d` roots, so a uniformly random point
is one of them with probability at most `d / |F|`. Every interactive soundness term of our count is a sum of such
fractions: one per sumcheck round (the round polynomial's degree over `|Fp2|`), the LogUp challenge (the cleared
LogUp polynomial's degree over `|Fp2|`), the zero-check point. This file states the bound in the form the other
`Sound*` files use: probabilities are `ENNReal`-valued, through `PMF.uniformOfFintype` and `toOuterMeasure`, as in
`Statements.lean`.

What is here:
* `prob_le_of_card`: a uniform probability is at most a count over the size of the space;
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
