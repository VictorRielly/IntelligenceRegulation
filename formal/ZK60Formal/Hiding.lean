/-
D63, step L4 (zero knowledge), first lemma: the opened columns of one masked row reveal nothing.

In our hiding commitment each committed row is `f = d + Z_n · g`, where `d` carries the message, `Z_n` vanishes on the
message domain, and the pad `g` has `Q` uniformly random coefficients (Q = q_pad). The verifier opens `f` at `Q`
distinct points `x_j` outside the message domain, so `Z_n(x_j) ≠ 0`. This file proves that the `Q` opened values
are then EXACTLY uniform on `F^Q`, whatever the message: their distribution does not depend on `d` at all.

This is the property the D59 privacy check measures numerically ("the pad block is full rank on any Q distinct
opened points"); here it is a theorem. It is one ingredient of `ZeroKnowledge` in `Statements.lean`, not the
whole of it: the combined rows of the proximity test, the masked sumcheck, the salted Merkle layer and the
composition over runs are further lemmas (plan L4). Opening FEWER distinct points than `Q` (repeated draws) follows
from this square case by taking a marginal; opening MORE than `Q` breaks it, which is why `Q` must never exceed the
pad count.
-/
import Mathlib.LinearAlgebra.Vandermonde
import Mathlib.LinearAlgebra.Matrix.NonsingularInverse
import Mathlib.Probability.ProbabilityMassFunction.Constructions
import Mathlib.Probability.Distributions.Uniform

namespace ZK60.Hiding

open scoped ENNReal

/-- Pushing a uniform distribution through a bijection gives the uniform distribution. -/
theorem map_uniform_of_bijective {α : Type} [Fintype α] [Nonempty α] (f : α → α)
    (hf : Function.Bijective f) :
    (PMF.uniformOfFintype α).map f = PMF.uniformOfFintype α := by
  classical
  ext b
  simp only [PMF.map_apply, PMF.uniformOfFintype_apply]
  obtain ⟨a, rfl⟩ := hf.2 b
  rw [tsum_eq_single a]
  · simp
  · intro a' ha'
    have hne : f a ≠ f a' := fun h => ha' (hf.1 h).symm
    simp [hne]

variable {F : Type} [Field F] [Fintype F] {Q : ℕ}

/-- The values of one committed row at the `Q` opened points `x`: the message part `m j = d(x_j)` plus
`Z_n(x_j) · g(x_j)`, where `z j = Z_n(x_j)` and the pad `g` is given by its `Q` coefficients. -/
def openedValues (x z m : Fin Q → F) (g : Fin Q → F) : Fin Q → F :=
  fun j => m j + z j * ∑ i : Fin Q, g i * x j ^ (i : ℕ)

/-- The pad block: a diagonal of `Z_n` values times the Vandermonde matrix of the opened points. -/
def padMatrix (x z : Fin Q → F) : Matrix (Fin Q) (Fin Q) F :=
  Matrix.diagonal z * Matrix.vandermonde x

omit [Fintype F] in
theorem openedValues_eq (x z m g : Fin Q → F) :
    openedValues x z m g = m + (padMatrix x z).mulVec g := by
  funext j
  simp only [openedValues, padMatrix, Pi.add_apply, Matrix.mulVec, dotProduct, Matrix.diagonal_mul,
    Matrix.vandermonde_apply, Finset.mul_sum]
  congr 1
  refine Finset.sum_congr rfl (fun i _ => ?_)
  ring

omit [Fintype F] in
/-- The pad block is invertible when the opened points are distinct and lie outside the message domain. -/
theorem padMatrix_isUnit (x z : Fin Q → F) (hx : Function.Injective x) (hz : ∀ j, z j ≠ 0) :
    IsUnit (padMatrix x z) := by
  rw [Matrix.isUnit_iff_isUnit_det, padMatrix, Matrix.det_mul, Matrix.det_diagonal]
  apply IsUnit.mul
  · exact (Finset.prod_ne_zero_iff.mpr (fun j _ => hz j)).isUnit
  · exact (Matrix.det_vandermonde_ne_zero_iff.mpr hx).isUnit

/-- **The opened values of a masked row are exactly uniform, for every message.** -/
theorem openedValues_uniform (x z m : Fin Q → F) (hx : Function.Injective x) (hz : ∀ j, z j ≠ 0) :
    (PMF.uniformOfFintype (Fin Q → F)).map (openedValues x z m) = PMF.uniformOfFintype (Fin Q → F) := by
  apply map_uniform_of_bijective
  have hinj : Function.Injective (openedValues x z m) := by
    intro g g' h
    simp only [openedValues_eq] at h
    exact (Matrix.mulVec_injective_iff_isUnit.mpr (padMatrix_isUnit x z hx hz)) (add_left_cancel h)
  exact Finite.injective_iff_bijective.mp hinj

/-- Hence the distribution of what the verifier sees does not depend on the message. -/
theorem openedValues_independent_of_message (x z : Fin Q → F) (hx : Function.Injective x)
    (hz : ∀ j, z j ≠ 0) (m m' : Fin Q → F) :
    (PMF.uniformOfFintype (Fin Q → F)).map (openedValues x z m)
      = (PMF.uniformOfFintype (Fin Q → F)).map (openedValues x z m') := by
  rw [openedValues_uniform x z m hx hz, openedValues_uniform x z m' hx hz]

end ZK60.Hiding
