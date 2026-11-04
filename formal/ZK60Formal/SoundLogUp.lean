/-
D63, step L3 (soundness of the IOP): LogUp, the algebraic identity and the random-challenge bound.

LogUp proves that every looked-up value `a_i` (`i` over the lookups) lies in a table `t_j` (`j` over the table
positions, which may repeat a value: the code's padded copies) by the identity of rational functions

  `Σ_i 1/(X − a_i) = Σ_j m_j/(X − t_j)`,

with multiplicities `m_j` that the prover commits (in `A`) before the challenge `α` is drawn. The verifier never sees
the rational functions: it checks the identity at `X = α` through committed helper columns
(`private_block::protocol::logup_sum_claim`, one value-0 sum claim over every helper of every lookup domain).

What is proved (no Fiat–Shamir; `α` uniform):
* `logup_iff_counts`: the identity holds iff, for every field element `v`, the number of lookups equal to `v`, AS A
  FIELD ELEMENT, equals the table's multiplicity mass at `v`, `Σ_{j : t_j = v} m_j`. No hypothesis on `F`.
* `logup_mem_of_eq` (THE SOUNDNESS DIRECTION): if the identity holds and the number of lookups is below `char F`,
  every looked-up value is in the table. The multiplicities may be ANY field elements: nothing about them needs
  checking. The characteristic condition is real: in characteristic `p`, `p` equal lookups of a value outside the
  table cancel (`p · 1/(X − v) = 0`).
* `logup_iff_multiset`: with natural multiplicities `μ_j`, `|A| < char F` and `Σ μ_j < char F`, the identity holds
  iff the multiset of lookups equals the multiset `Σ_j μ_j • {t_j}`.
* `logup_challenge_bound`: if the identity FAILS, a uniform `α` that is not a pole satisfies the identity at `α` with
  probability at most `(|S| − 1)/|F|`, `S` the set of distinct values among lookups and table entries
  (`logup_challenge_bound'`: `≤ (N + M − 1)/|F|` for `N` lookups and `M` table positions).

The proofs go through one polynomial, the cleared identity `Σ_i Π_{w ∈ S∖{a_i}} (X − w) − Σ_j m_j Π_{w ∈ S∖{t_j}} (X − w)`,
of degree `≤ |S| − 1` (`cleared`, `algebraMap_cleared`, `eval_cleared_mem`, `eval_cleared_not_mem`).
-/
import ZK60Formal.SoundSchwartzZippel
import Mathlib.FieldTheory.RatFunc.AsPolynomial

namespace ZK60.Sound

open scoped ENNReal
open Polynomial Finset

variable {F : Type} [Field F] [DecidableEq F]
variable {ι κ : Type} [Fintype ι] [Fintype κ]

/-! ## The objects -/

/-- The poles: the distinct looked-up values and table values. -/
def poles (a : ι → F) (t : κ → F) : Finset F := univ.image a ∪ univ.image t

/-- The looked-up side as a rational function: `Σ_i 1/(X − a_i)`. -/
noncomputable def logupLhs (a : ι → F) : RatFunc F := ∑ i, (RatFunc.X - RatFunc.C (a i))⁻¹

/-- The table side as a rational function: `Σ_j m_j/(X − t_j)`. -/
noncomputable def logupRhs (t : κ → F) (m : κ → F) : RatFunc F :=
  ∑ j, RatFunc.C (m j) * (RatFunc.X - RatFunc.C (t j))⁻¹

/-- The looked-up side at a point `x`: `Σ_i (x − a_i)⁻¹`, what the helper columns sum to at `α = x`. -/
def logupLhsAt (a : ι → F) (x : F) : F := ∑ i, (x - a i)⁻¹

/-- The table side at a point `x`: `Σ_j m_j (x − t_j)⁻¹`, what the table helpers sum to at `α = x`. -/
def logupRhsAt (t : κ → F) (m : κ → F) (x : F) : F := ∑ j, m j * (x - t j)⁻¹

/-- How many lookups equal `v`, as a field element. -/
def lookCount (a : ι → F) (v : F) : F := ((univ.filter (fun i => a i = v)).card : F)

/-- The table's multiplicity mass at `v`: `Σ_{j : t_j = v} m_j` (padded copies of a value add up). -/
def tableMass (t : κ → F) (m : κ → F) (v : F) : F := ∑ j ∈ univ.filter (fun j => t j = v), m j

/-- `Π_{w ∈ S, w ≠ u} (X − w)`. -/
noncomputable def prodOmit (S : Finset F) (u : F) : F[X] := ∏ w ∈ S.erase u, (X - C w)

/-- The cleared identity: the LogUp difference times `Π_{w ∈ S} (X − w)`, a polynomial. -/
noncomputable def cleared (a : ι → F) (t : κ → F) (m : κ → F) : F[X] :=
  ∑ i, prodOmit (poles a t) (a i) - ∑ j, C (m j) * prodOmit (poles a t) (t j)

/-! ## The cleared polynomial -/

omit [Field F] in
theorem mem_poles_left (a : ι → F) (t : κ → F) (i : ι) : a i ∈ poles a t :=
  mem_union_left _ (mem_image_of_mem a (mem_univ i))

omit [Field F] in
theorem mem_poles_right (a : ι → F) (t : κ → F) (j : κ) : t j ∈ poles a t :=
  mem_union_right _ (mem_image_of_mem t (mem_univ j))

/-- `Π_{w ∈ S} (X − w) = (X − u) · Π_{w ∈ S∖{u}} (X − w)` for `u ∈ S`. -/
theorem prod_eq_mul_prodOmit {S : Finset F} {u : F} (hu : u ∈ S) :
    ∏ w ∈ S, (X - C w) = (X - C u) * prodOmit S u :=
  (mul_prod_erase S (fun w => X - C w) hu).symm

/-- In the rational functions, `Π_{w ∈ S∖{u}} (X − w) = Π_{w ∈ S} (X − w) · (X − u)⁻¹`. -/
theorem algebraMap_prodOmit {S : Finset F} {u : F} (hu : u ∈ S) :
    algebraMap F[X] (RatFunc F) (prodOmit S u)
      = algebraMap F[X] (RatFunc F) (∏ w ∈ S, (X - C w)) * (RatFunc.X - RatFunc.C u)⁻¹ := by
  have hne : (RatFunc.X - RatFunc.C u : RatFunc F) ≠ 0 := by
    rw [← RatFunc.algebraMap_X, ← RatFunc.algebraMap_C, ← map_sub]
    exact RatFunc.algebraMap_ne_zero (X_sub_C_ne_zero u)
  rw [prod_eq_mul_prodOmit hu, map_mul, map_sub, RatFunc.algebraMap_X, RatFunc.algebraMap_C,
    mul_comm (RatFunc.X - RatFunc.C u), mul_assoc, mul_inv_cancel₀ hne, mul_one]

/-- The cleared polynomial IS the LogUp difference times `Π_{w ∈ S} (X − w)`. -/
theorem algebraMap_cleared (a : ι → F) (t : κ → F) (m : κ → F) :
    algebraMap F[X] (RatFunc F) (cleared a t m)
      = algebraMap F[X] (RatFunc F) (∏ w ∈ poles a t, (X - C w)) * (logupLhs a - logupRhs t m) := by
  simp only [cleared, map_sub, map_sum, map_mul, RatFunc.algebraMap_C,
    algebraMap_prodOmit (mem_poles_left a t _), algebraMap_prodOmit (mem_poles_right a t _), logupLhs,
    logupRhs, mul_sub, mul_sum]
  congr 1
  refine sum_congr rfl (fun j _ => ?_)
  ring

/-- `prodOmit S w` at a point `u ∈ S`: nonzero exactly at `w = u`. -/
theorem eval_prodOmit_mem {S : Finset F} {u : F} (hu : u ∈ S) (w : F) :
    (prodOmit S w).eval u = if w = u then ∏ v ∈ S.erase u, (u - v) else 0 := by
  unfold prodOmit
  rw [eval_prod]
  split_ifs with h
  · subst h
    simp
  · apply prod_eq_zero (mem_erase.mpr ⟨Ne.symm h, hu⟩)
    simp

/-- The product `Π_{v ∈ S∖{u}} (u − v)` is nonzero. -/
theorem prod_erase_sub_ne_zero (S : Finset F) (u : F) : ∏ v ∈ S.erase u, (u - v) ≠ 0 := by
  rw [prod_ne_zero_iff]
  intro v hv
  exact sub_ne_zero.mpr (Ne.symm (mem_erase.mp hv).1)

/-- At a pole `u`, the cleared polynomial is `(count(u) − mass(u)) · Π_{v ≠ u} (u − v)`. -/
theorem eval_cleared_mem (a : ι → F) (t : κ → F) (m : κ → F) {u : F} (hu : u ∈ poles a t) :
    (cleared a t m).eval u = (lookCount a u - tableMass t m u) * ∏ v ∈ (poles a t).erase u, (u - v) := by
  simp only [cleared, eval_sub, eval_finsetSum, eval_mul, eval_C, eval_prodOmit_mem hu, lookCount,
    tableMass, mul_ite, mul_zero, sub_mul]
  rw [sum_ite, sum_const_zero, add_zero, sum_const, nsmul_eq_mul, sum_ite, sum_const_zero, add_zero,
    sum_mul]

/-- Off the poles, the cleared polynomial is `Π_{w ∈ S} (x − w) · (lhs(x) − rhs(x))`. -/
theorem eval_cleared_not_mem (a : ι → F) (t : κ → F) (m : κ → F) {x : F} (hx : x ∉ poles a t) :
    (cleared a t m).eval x
      = (∏ w ∈ poles a t, (x - w)) * (logupLhsAt a x - logupRhsAt t m x) := by
  have key : ∀ u ∈ poles a t, (prodOmit (poles a t) u).eval x = (∏ w ∈ poles a t, (x - w)) * (x - u)⁻¹ := by
    intro u hu
    have hxu : x - u ≠ 0 := sub_ne_zero.mpr (fun h => hx (h ▸ hu))
    have h := congrArg (eval x) (prod_eq_mul_prodOmit (S := poles a t) hu)
    rw [eval_prod, eval_mul] at h
    simp only [eval_sub, eval_X, eval_C] at h
    rw [h, mul_comm (x - u), mul_assoc, mul_inv_cancel₀ hxu, mul_one]
  simp only [cleared, eval_sub, eval_finsetSum, eval_mul, eval_C, key _ (mem_poles_left a t _),
    key _ (mem_poles_right a t _), logupLhsAt, logupRhsAt, mul_sub, mul_sum]
  congr 1
  refine sum_congr rfl (fun j _ => ?_)
  ring

/-- The cleared polynomial has degree at most `|S| − 1`. -/
theorem natDegree_cleared_le (a : ι → F) (t : κ → F) (m : κ → F) :
    (cleared a t m).natDegree ≤ (poles a t).card - 1 := by
  have hom : ∀ u ∈ poles a t, (prodOmit (poles a t) u).natDegree ≤ (poles a t).card - 1 := by
    intro u hu
    unfold prodOmit
    refine (natDegree_prod_le _ _).trans ?_
    simp only [natDegree_X_sub_C, sum_const, smul_eq_mul, mul_one]
    rw [card_erase_of_mem hu]
  refine (natDegree_sub_le _ _).trans (max_le ?_ ?_)
  · exact natDegree_sum_le_of_forall_le _ _ (fun i _ => hom _ (mem_poles_left a t i))
  · exact natDegree_sum_le_of_forall_le _ _
      (fun j _ => (natDegree_C_mul_le _ _).trans (hom _ (mem_poles_right a t j)))

/-- The identity holds iff the cleared polynomial is zero. -/
theorem logup_eq_iff_cleared_eq_zero (a : ι → F) (t : κ → F) (m : κ → F) :
    logupLhs a = logupRhs t m ↔ cleared a t m = 0 := by
  have hD : algebraMap F[X] (RatFunc F) (∏ w ∈ poles a t, (X - C w)) ≠ 0 :=
    RatFunc.algebraMap_ne_zero (prod_ne_zero_iff.mpr (fun w _ => X_sub_C_ne_zero w))
  rw [← (RatFunc.algebraMap_injective F).eq_iff, map_zero, algebraMap_cleared, mul_eq_zero, sub_eq_zero]
  exact ⟨fun h => Or.inr h, fun h => h.resolve_left hD⟩

/-! ## (a) The identity -/

/-- **The LogUp identity, exactly.** `Σ_i 1/(X − a_i) = Σ_j m_j/(X − t_j)` as rational functions iff, for every
`v`, the number of lookups equal to `v` (as a field element) is the table's multiplicity mass at `v`. -/
theorem logup_iff_counts (a : ι → F) (t : κ → F) (m : κ → F) :
    logupLhs a = logupRhs t m ↔ ∀ v, lookCount a v = tableMass t m v := by
  rw [logup_eq_iff_cleared_eq_zero]
  constructor
  · intro h v
    by_cases hv : v ∈ poles a t
    · have := eval_cleared_mem a t m hv
      rw [h, eval_zero] at this
      exact sub_eq_zero.mp ((mul_eq_zero.mp this.symm).resolve_right (prod_erase_sub_ne_zero _ _))
    · have h1 : univ.filter (fun i => a i = v) = ∅ :=
        filter_false_of_mem (fun i _ hi => hv (hi ▸ mem_poles_left a t i))
      have h2 : univ.filter (fun j => t j = v) = ∅ :=
        filter_false_of_mem (fun j _ hj => hv (hj ▸ mem_poles_right a t j))
      simp [lookCount, tableMass, h1, h2]
  · intro h
    rcases (poles a t).eq_empty_or_nonempty with hS | hS
    · have hι : IsEmpty ι := ⟨fun i => by simpa [hS] using mem_poles_left a t i⟩
      have hκ : IsEmpty κ := ⟨fun j => by simpa [hS] using mem_poles_right a t j⟩
      simp [cleared]
    · refine eq_zero_of_natDegree_lt_card_of_eval_eq_zero' _ (poles a t) (fun u hu => ?_) ?_
      · rw [eval_cleared_mem a t m hu, h u, sub_self, zero_mul]
      · exact lt_of_le_of_lt (natDegree_cleared_le a t m) (Nat.sub_lt hS.card_pos one_pos)

omit [DecidableEq F] in
/-- A count of at most `N` lookups, nonzero, is nonzero in `F` when `N < char F`. -/
theorem natCast_ne_zero_of_lt {k : ℕ} (hk0 : k ≠ 0) (hk : k < ringChar F) : (k : F) ≠ 0 := by
  intro h
  rw [CharP.cast_eq_zero_iff F (ringChar F)] at h
  exact hk0 (Nat.eq_zero_of_dvd_of_lt h hk)

/-- **LogUp soundness, algebraic.** If the identity holds and there are fewer lookups than the characteristic, every
looked-up value is a table value, WHATEVER the multiplicities are (they are free field elements chosen by the
prover). -/
theorem logup_mem_of_eq (a : ι → F) (t : κ → F) (m : κ → F) (hN : Fintype.card ι < ringChar F)
    (h : logupLhs a = logupRhs t m) (i : ι) : ∃ j, t j = a i := by
  by_contra hno'
  have hno : ∀ j, t j ≠ a i := fun j hj => hno' ⟨j, hj⟩
  have hc := (logup_iff_counts a t m).mp h (a i)
  have hmass : tableMass t m (a i) = 0 := by
    have : univ.filter (fun j => t j = a i) = ∅ := filter_false_of_mem (fun j _ => hno j)
    simp [tableMass, this]
  rw [hmass, lookCount] at hc
  refine natCast_ne_zero_of_lt ?_ ?_ hc
  · exact (card_pos.mpr ⟨i, by simp⟩).ne'
  · exact lt_of_le_of_lt (card_le_univ _) hN

/-- The same, contrapositive: a value outside the table makes the identity FAIL. -/
theorem logup_ne_of_not_mem (a : ι → F) (t : κ → F) (m : κ → F) (hN : Fintype.card ι < ringChar F)
    {i : ι} (hi : ∀ j, t j ≠ a i) : logupLhs a ≠ logupRhs t m := by
  intro h
  obtain ⟨j, hj⟩ := logup_mem_of_eq a t m hN h i
  exact hi j hj

/-- **The identity as multisets.** With natural multiplicities `μ`, fewer lookups than `char F` and total
multiplicity below `char F`, the identity holds iff the multiset of lookups is the table's multiset with
multiplicities `μ`, `Σ_j μ_j • {t_j}`. -/
theorem logup_iff_multiset (a : ι → F) (t : κ → F) (μ : κ → ℕ) (hN : Fintype.card ι < ringChar F)
    (hμ : ∑ j, μ j < ringChar F) :
    logupLhs a = logupRhs t (fun j => (μ j : F)) ↔ univ.val.map a = ∑ j, μ j • ({t j} : Multiset F) := by
  rw [logup_iff_counts, Multiset.ext]
  have hcountA : ∀ v, Multiset.count v (univ.val.map a) = (univ.filter (fun i => a i = v)).card := by
    intro v
    rw [Multiset.count_map]
    simp only [eq_comm, Finset.card, Finset.filter_val]
  have hcountT : ∀ v, Multiset.count v (∑ j, μ j • ({t j} : Multiset F))
      = ∑ j ∈ univ.filter (fun j => t j = v), μ j := by
    intro v
    rw [Multiset.count_sum', sum_filter]
    refine sum_congr rfl (fun j _ => ?_)
    rw [Multiset.count_nsmul, Multiset.count_singleton]
    split_ifs with h1 h2 h2 <;> simp_all [eq_comm]
  have hinj := CharP.natCast_injOn_Iio F (ringChar F)
  refine forall_congr' (fun v => ?_)
  rw [hcountA, hcountT, lookCount, tableMass, ← Nat.cast_sum]
  constructor
  · intro h
    exact hinj (lt_of_le_of_lt (card_le_univ _) hN)
      (lt_of_le_of_lt (sum_le_sum_of_subset (filter_subset _ _)) hμ) h
  · intro h
    rw [h]

/-! ## (b) The random challenge -/

variable [Fintype F]

/-- **The LogUp challenge, counted.** If the identity fails, at most `|S| − 1` points `x` off the poles satisfy it at
`x` (`S` = the distinct lookup and table values). -/
theorem card_logup_agree_le (a : ι → F) (t : κ → F) (m : κ → F) (h : logupLhs a ≠ logupRhs t m) :
    (univ.filter (fun x => x ∉ poles a t ∧ logupLhsAt a x = logupRhsAt t m x)).card ≤ (poles a t).card - 1 := by
  have hne : cleared a t m ≠ 0 := fun h0 => h ((logup_eq_iff_cleared_eq_zero a t m).mpr h0)
  refine le_trans (card_le_card ?_) ((card_roots_le _ hne).trans (natDegree_cleared_le a t m))
  intro x hx
  simp only [mem_filter, mem_univ, true_and] at hx ⊢
  rw [eval_cleared_not_mem a t m hx.1, hx.2, sub_self, mul_zero]

/-- **LogUp, the random-challenge bound.** If `Σ_i 1/(X − a_i) ≠ Σ_j m_j/(X − t_j)` (for instance because some
looked-up value is not in the table, `logup_ne_of_not_mem`), a uniformly random `α` avoids the poles and still
satisfies `Σ_i 1/(α − a_i) = Σ_j m_j/(α − t_j)` with probability at most `(|S| − 1)/|F|`, `S` the set of distinct
lookup and table values. -/
theorem logup_challenge_bound (a : ι → F) (t : κ → F) (m : κ → F) (h : logupLhs a ≠ logupRhs t m) :
    (PMF.uniformOfFintype F).toOuterMeasure {x | x ∉ poles a t ∧ logupLhsAt a x = logupRhsAt t m x}
      ≤ (((poles a t).card - 1 : ℕ) : ℝ≥0∞) / Fintype.card F :=
  prob_le_of_card_filter _ _ (card_logup_agree_le a t m h)

omit [Field F] [Fintype F] in
/-- The distinct values number at most `N + M`. -/
theorem card_poles_le (a : ι → F) (t : κ → F) : (poles a t).card ≤ Fintype.card ι + Fintype.card κ :=
  (card_union_le _ _).trans (Nat.add_le_add (card_image_le.trans (by simp)) (card_image_le.trans (by simp)))

/-- **LogUp, the bound in the lookup and table sizes.** With `N` lookups and `M` table positions, the probability is at
most `(N + M − 1)/|F|`. -/
theorem logup_challenge_bound' (a : ι → F) (t : κ → F) (m : κ → F) (h : logupLhs a ≠ logupRhs t m) :
    (PMF.uniformOfFintype F).toOuterMeasure {x | x ∉ poles a t ∧ logupLhsAt a x = logupRhsAt t m x}
      ≤ ((Fintype.card ι + Fintype.card κ - 1 : ℕ) : ℝ≥0∞) / Fintype.card F := by
  refine (logup_challenge_bound a t m h).trans (ENNReal.div_le_div_right ?_ _)
  exact_mod_cast Nat.sub_le_sub_right (card_poles_le a t) 1

end ZK60.Sound
