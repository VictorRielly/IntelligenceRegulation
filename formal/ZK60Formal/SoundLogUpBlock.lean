/-
D63, step L3 (soundness of the IOP): LogUp as the code runs it, with helper columns, pair helpers, table helpers and
the `(β, γ)` tuple fold; the per-block LogUp term of our count, proved.

The code (`private_block::protocol`, `argument::helper_sum`, the `SC_TAB` table relation, `logup_sum_claim`):
* every lookup is a TUPLE, folded with two challenges into one field element: `x + γ·tag + β·y + β²·z` (the value, the
  family tag `γ·TAG`, and the extra coordinates of the exp, ACT and dictionary tuples);
* the looked-up values come as SINGLES, each with its own helper `h` and the relation `h·(α − a) = 1`, and as PAIRS,
  two lookups sharing one helper with the relation `h·(α − a)(α − b) = (α − a) + (α − b)`;
* each table position `j` has a table helper `g_j` with the relation `g_j·(α − t_j) = m_j`, `m_j` the committed
  multiplicity (in `A`, before `β, γ, α`);
* one sum claim: every helper minus every table helper sums to zero (plus the zero-sum mask row `u`, whose own sum is
  zero by its own sumcheck, `SC_ZS`; it is left out here).

What is proved, for fixed lookups, table and multiplicities (the prover commits them before the challenges) and ANY
helpers the prover chooses after `α`:
* `helperRel_forces`: off the poles, the relations force the helpers, and the sum claim IS the LogUp identity at `α`;
* `helperRel_none`: at a pole that is not BAD, no helpers satisfy the relations. The bad poles (`badPoles`) are a table
  value with multiplicity `0` (its relation `g·0 = 0` leaves `g` free) and a pair pole `a = b` (`h·0 = 0`);
* `logup_helpers_bound`: if the LogUp identity fails, `Pr_α[some helpers pass every relation] ≤ (N + 2M − 1)/|F|`, with
  `N` lookups (singles + 2 × pairs) and `M` DISTINCT table values (`card_badPoles_add_poles_le`:
  `|bad| + |S| ≤ N + 2M`);
* `fold_collision_card`: two different tuples fold to the same element for at most `2|F|` of the `|F|²` pairs `(β, γ)`;
* `logup_block_bound`: if some looked-up TUPLE is not a table tuple and `N < char F`, then
  `Pr_{β, γ, α}[some helpers pass every relation] ≤ (N + 4M − 1)/|F|`, `M` the number of distinct table tuples. This is
  the count's per-block LogUp term `(N_lk + 4·T_d − 1)/|Fp2|` (`count.py`, REVIEW_R13 §3: B1 `2·T_d`, B2 + B3
  `N + 2·T_d − 1`), now a theorem, with `T_d` read as the number of distinct table entries (padded copies of an entry
  are positions, not entries, and do not count).

What it does not cover: that the relations hold on the whole cube is checked by the zero-check sumchecks (their own
terms, `SoundZeroCheck.lean`), the sum claim by the PCS, the zero-sum row `u` by its own sumcheck, and Fiat–Shamir.
The helpers are modelled as field values per lookup and per table position, i.e. the relations are taken pointwise
on the cube; the code's batching of several helper relations into one zero-check is `batch_prob`.
-/
import ZK60Formal.SoundLogUp

namespace ZK60.Sound

open scoped ENNReal
open Polynomial Finset

variable {F : Type} [Field F] [DecidableEq F]
variable {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]

/-! ## Helper columns -/

/-- The helper values of one block: one per single lookup, one per pair, one per table position. -/
structure Helpers (ι π κ F : Type) where
  single : ι → F
  pair : π → F
  table : κ → F

/-- The first and second lookup of pair `k`. -/
def pairFst (look : ι ⊕ (π ⊕ π) → F) (k : π) : F := look (.inr (.inl k))
/-- The second lookup of pair `k`. -/
def pairSnd (look : ι ⊕ (π ⊕ π) → F) (k : π) : F := look (.inr (.inr k))

/-- The code's LogUp relations at the challenge `α`, for the looked-up values `look` (singles `inl i`, pairs
`inr (inl k)`, `inr (inr k)`), the table `t` and the multiplicities `m`:
single helpers `h·(α − a) = 1`, pair helpers `h·(α − a)(α − b) = (α − a) + (α − b)` (`argument::helper_sum`), table
helpers `g·(α − t) = m` (the `SC_TAB` relation), and the value-0 sum claim (`logup_sum_claim`). -/
def HelperRel (look : ι ⊕ (π ⊕ π) → F) (t m : κ → F) (α : F) (H : Helpers ι π κ F) : Prop :=
  (∀ i, H.single i * (α - look (.inl i)) = 1) ∧
  (∀ k, H.pair k * ((α - pairFst look k) * (α - pairSnd look k)) = (α - pairFst look k) + (α - pairSnd look k)) ∧
  (∀ j, H.table j * (α - t j) = m j) ∧
  (∑ i, H.single i + ∑ k, H.pair k - ∑ j, H.table j = 0)

/-- The poles at which the relations do NOT pin the helpers down: a table value whose multiplicity is zero, and a
pair whose two lookups are equal. -/
def badPoles (look : ι ⊕ (π ⊕ π) → F) (t m : κ → F) : Finset F :=
  (univ.filter (fun j => m j = 0)).image t ∪
    (univ.filter (fun k => pairFst look k = pairSnd look k)).image (pairFst look)

/-- The bad poles are poles. -/
theorem badPoles_subset (look : ι ⊕ (π ⊕ π) → F) (t m : κ → F) : badPoles look t m ⊆ poles look t := by
  intro v hv
  simp only [badPoles, mem_union, mem_image, mem_filter, mem_univ, true_and] at hv
  rcases hv with ⟨j, -, rfl⟩ | ⟨k, -, rfl⟩
  · exact mem_poles_right look t j
  · exact mem_poles_left look t (.inr (.inl k))

/-- **Off the poles the relations force the helpers**, `h_i = 1/(α − a_i)`, `h_k = 1/(α − a_k) + 1/(α − b_k)`,
`g_j = m_j/(α − t_j)`, so the sum claim is exactly the LogUp identity at `α`. -/
theorem helperRel_forces {look : ι ⊕ (π ⊕ π) → F} {t m : κ → F} {α : F} {H : Helpers ι π κ F}
    (hα : α ∉ poles look t) (h : HelperRel look t m α H) : logupLhsAt look α = logupRhsAt t m α := by
  obtain ⟨hs, hp, ht, hsum⟩ := h
  have hne : ∀ v ∈ poles look t, α - v ≠ 0 := fun v hv => sub_ne_zero.mpr (fun h => hα (h ▸ hv))
  have es : ∀ i, H.single i = (α - look (.inl i))⁻¹ := fun i =>
    eq_inv_of_mul_eq_one_left (hs i)
  have ep : ∀ k, H.pair k = (α - pairFst look k)⁻¹ + (α - pairSnd look k)⁻¹ := by
    intro k
    have h1 := hne _ (mem_poles_left look t (.inr (.inl k)))
    have h2 := hne _ (mem_poles_left look t (.inr (.inr k)))
    have := hp k
    unfold pairFst pairSnd at this ⊢
    field_simp
    linear_combination this
  have et : ∀ j, H.table j = m j * (α - t j)⁻¹ := by
    intro j
    have h1 := hne _ (mem_poles_right look t j)
    rw [← ht j, mul_assoc, mul_inv_cancel₀ h1, mul_one]
  simp only [es, ep, et, sum_add_distrib] at hsum
  simp only [logupLhsAt, logupRhsAt, Fintype.sum_sum_type]
  unfold pairFst pairSnd at hsum
  linear_combination hsum

/-- **At a pole that is not bad, no helpers pass.** `α = a_i` for a single makes `h·0 = 1`; `α` equal to one lookup of
a pair with two different lookups makes `h·0 = (α − b) ≠ 0`; `α = t_j` with `m_j ≠ 0` makes `g·0 = m_j ≠ 0`. -/
theorem helperRel_none {look : ι ⊕ (π ⊕ π) → F} {t m : κ → F} {α : F} (hα : α ∈ poles look t)
    (hb : α ∉ badPoles look t m) (H : Helpers ι π κ F) : ¬ HelperRel look t m α H := by
  rintro ⟨hs, hp, ht, -⟩
  simp only [poles, mem_union, mem_image, mem_univ, true_and] at hα
  simp only [badPoles, mem_union, mem_image, mem_filter, mem_univ, true_and, not_or, not_exists,
    not_and] at hb
  rcases hα with ⟨l, rfl⟩ | ⟨j, rfl⟩
  · rcases l with i | k | k
    · have := hs i
      simp at this
    · have hk : pairFst look k ≠ pairSnd look k := fun h => hb.2 k h rfl
      have := hp k
      rw [show look (.inr (.inl k)) = pairFst look k from rfl, sub_self, zero_mul, mul_zero, zero_add] at this
      exact sub_ne_zero.mpr hk this.symm
    · have hk : pairFst look k ≠ pairSnd look k := fun h => hb.2 k h h
      have := hp k
      rw [show look (.inr (.inr k)) = pairSnd look k from rfl, sub_self, mul_zero, mul_zero, add_zero] at this
      exact sub_ne_zero.mpr (Ne.symm hk) this.symm
  · have hm : m j ≠ 0 := fun h => hb.1 j h rfl
    have := ht j
    rw [sub_self, mul_zero] at this
    exact hm this.symm

/-- The bad poles and the distinct values together number at most `N + 2M`: `N = |ι| + 2|π|` lookups and `M` the
number of DISTINCT table values (padded copies of a table entry count once). A value that is a pair pole is looked up
twice, which pays for its second count. -/
theorem card_badPoles_add_poles_le (look : ι ⊕ (π ⊕ π) → F) (t m : κ → F) :
    (badPoles look t m).card + (poles look t).card
      ≤ (Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image t).card := by
  classical
  set E := univ.filter (fun k => pairFst look k = pairSnd look k) with hE
  set D := univ.filter (fun k => ¬ pairFst look k = pairSnd look k) with hD
  have hED : E.card + D.card = Fintype.card π := by
    rw [hE, hD, card_filter_add_card_filter_not, card_univ]
  have hlook : univ.image look ⊆
      univ.image (fun i => look (.inl i)) ∪ univ.image (pairFst look) ∪ D.image (pairSnd look) := by
    intro v hv
    simp only [mem_image, mem_univ, true_and] at hv
    obtain ⟨l, rfl⟩ := hv
    rcases l with i | k | k
    · exact mem_union_left _ (mem_union_left _ (mem_image_of_mem _ (mem_univ i)))
    · exact mem_union_left _ (mem_union_right _ (mem_image_of_mem _ (mem_univ k)))
    · by_cases hk : pairFst look k = pairSnd look k
      · refine mem_union_left _ (mem_union_right _ ?_)
        rw [show look (.inr (.inr k)) = pairSnd look k from rfl, ← hk]
        exact mem_image_of_mem _ (mem_univ k)
      · exact mem_union_right _ (mem_image_of_mem _ (by simp [hD, hk]))
  have hS : (poles look t).card ≤ Fintype.card ι + Fintype.card π + D.card + (univ.image t).card := by
    refine (card_union_le _ _).trans (Nat.add_le_add ?_ le_rfl)
    refine (card_le_card hlook).trans ((card_union_le _ _).trans (Nat.add_le_add ?_ card_image_le))
    exact (card_union_le _ _).trans (Nat.add_le_add (card_image_le.trans (by simp))
      (card_image_le.trans (by simp)))
  have hB : (badPoles look t m).card ≤ (univ.image t).card + E.card := by
    refine (card_union_le _ _).trans (Nat.add_le_add ?_ card_image_le)
    exact card_le_card (image_subset_image (filter_subset _ _))
  omega

variable [Fintype F]

open Classical in
/-- Counting the challenges at which some helpers pass: if the identity fails, at most `|bad| + |S| − 1`. -/
theorem card_helperRel_le (look : ι ⊕ (π ⊕ π) → F) (t m : κ → F) (hne : logupLhs look ≠ logupRhs t m) :
    (univ.filter (fun α => ∃ H, HelperRel look t m α H)).card
      ≤ (badPoles look t m).card + ((poles look t).card - 1) := by
  have hsub : univ.filter (fun α => ∃ H, HelperRel look t m α H) ⊆ badPoles look t m ∪
      univ.filter (fun x => x ∉ poles look t ∧ logupLhsAt look x = logupRhsAt t m x) := by
    intro α hα
    simp only [mem_filter, mem_univ, true_and] at hα
    obtain ⟨H, hH⟩ := hα
    by_cases hp : α ∈ poles look t
    · by_cases hb : α ∈ badPoles look t m
      · exact mem_union_left _ hb
      · exact absurd hH (helperRel_none hp hb H)
    · exact mem_union_right _ (by simpa [hp] using helperRel_forces hp hH)
  exact (card_le_card hsub).trans
    ((card_union_le _ _).trans (Nat.add_le_add_left (card_logup_agree_le look t m hne) _))

open Classical in
/-- The same count in the block's sizes: at most `N + 2M − 1` challenges, `N = |ι| + 2|π|` lookups, `M` distinct
table values. -/
theorem card_helperRel_le' (look : ι ⊕ (π ⊕ π) → F) (t m : κ → F) (hne : logupLhs look ≠ logupRhs t m) :
    (univ.filter (fun α => ∃ H, HelperRel look t m α H)).card
      ≤ (Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image t).card - 1 := by
  have h1 := card_helperRel_le look t m hne
  have h2 := card_badPoles_add_poles_le look t m
  have h3 := card_le_card (badPoles_subset look t m)
  omega

/-- **LogUp with the code's helpers, one challenge.** If the LogUp identity fails (e.g. a looked-up value is not in the
table, `logup_ne_of_not_mem`), the probability over `α` that SOME helper values satisfy every relation and the sum
claim is at most `(N + 2M − 1)/|F|`, `N = |ι| + 2|π|` lookups, `M` distinct table values (at most the number of table
positions `|κ|`). -/
theorem logup_helpers_bound (look : ι ⊕ (π ⊕ π) → F) (t m : κ → F) (hne : logupLhs look ≠ logupRhs t m) :
    (PMF.uniformOfFintype F).toOuterMeasure {α | ∃ H, HelperRel look t m α H}
      ≤ (((Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image t).card - 1 : ℕ) : ℝ≥0∞) / Fintype.card F := by
  classical
  exact prob_le_of_card_filter _ _ (card_helperRel_le' look t m hne)

/-! ## The tuple fold -/

/-- A lookup tuple as the code folds it: the value `x`, the family tag, and up to two further coordinates (exp:
`(δ, e)`; ACT: `(index, a)`; the dictionary: `(s, e, P)`). -/
structure Tup (F : Type) where
  x : F
  tag : F
  y : F
  z : F
  deriving DecidableEq

/-- The fold `x + γ·tag + β·y + β²·z` (`g_u8 = γ·TAG_U8`, `g_range`, `g_exp`, `g_act`, `dd_tuples`). -/
def fold (β γ : F) (u : Tup F) : F := u.x + γ * u.tag + β * u.y + β ^ 2 * u.z

omit [Field F] [DecidableEq F] [Fintype F] in
theorem Tup.ext' {u w : Tup F} (hx : u.x = w.x) (ht : u.tag = w.tag) (hy : u.y = w.y) (hz : u.z = w.z) : u = w := by
  cases u; cases w; simp_all

open Classical in
/-- **Two different tuples collide under the fold for at most `2|F|` of the `|F|²` pairs `(β, γ)`**, i.e. with
probability at most `2/|F|`: the difference is `dx + γ·dt + β·dy + β²·dz`, nonzero, of degree `≤ 2`. -/
theorem fold_collision_card {u w : Tup F} (huw : u ≠ w) :
    (univ.filter (fun p : F × F => fold p.1 p.2 u = fold p.1 p.2 w)).card ≤ 2 * Fintype.card F := by
  rw [card_filter_prod]
  set dx := u.x - w.x
  set dt := u.tag - w.tag
  set dy := u.y - w.y
  set dz := u.z - w.z
  have hdiff : ∀ β γ, fold β γ u = fold β γ w ↔ (dx + β * dy + β ^ 2 * dz) + γ * dt = 0 := by
    intro β γ
    simp only [fold, dx, dt, dy, dz]
    constructor <;> intro h <;> linear_combination h
  by_cases hdt : dt = 0
  · -- the tag coordinate agrees: the collision is a degree-2 condition on β alone
    set q : F[X] := C dz * X ^ 2 + C dy * X + C dx with hq
    have hq0 : q ≠ 0 := by
      intro h0
      have c0 := congrArg (fun p => p.coeff 0) h0
      have c1 := congrArg (fun p => p.coeff 1) h0
      have c2 := congrArg (fun p => p.coeff 2) h0
      simp [hq, coeff_X, coeff_C] at c0 c1 c2
      exact huw (Tup.ext' (sub_eq_zero.mp c0) (sub_eq_zero.mp hdt) (sub_eq_zero.mp c1) (sub_eq_zero.mp c2))
    have hqdeg : q.natDegree ≤ 2 := by
      rw [hq]
      compute_degree
    have hroots := (card_roots_le q hq0).trans hqdeg
    have hslice : ∀ β : F, (univ.filter (fun γ : F => fold β γ u = fold β γ w)).card
        ≤ (if q.eval β = 0 then Fintype.card F else 0) := by
      intro β
      split_ifs with hβ
      · exact (card_filter_le _ _).trans (by simp)
      · rw [Nat.le_zero, card_eq_zero, filter_eq_empty_iff]
        intro γ _ hγ
        rw [hdiff, hdt, mul_zero, add_zero] at hγ
        apply hβ
        simp only [hq, eval_add, eval_mul, eval_C, eval_pow, eval_X]
        linear_combination hγ
    refine (sum_le_sum (fun β _ => hslice β)).trans ?_
    rw [← sum_filter, sum_const, smul_eq_mul]
    exact Nat.mul_le_mul_right _ hroots
  · -- the tags differ: for each β exactly one γ collides
    have hslice : ∀ β : F, (univ.filter (fun γ : F => fold β γ u = fold β γ w)).card ≤ 1 := by
      intro β
      refine card_le_one.mpr (fun γ₁ h₁ γ₂ h₂ => ?_)
      simp only [mem_filter, mem_univ, true_and, hdiff] at h₁ h₂
      have : (γ₁ - γ₂) * dt = 0 := by linear_combination h₁ - h₂
      exact sub_eq_zero.mp ((mul_eq_zero.mp this).resolve_right hdt)
    refine (sum_le_sum (fun β _ => hslice β)).trans ?_
    simp only [sum_const, card_univ, smul_eq_mul, mul_one]
    omega

open Classical in
/-- A fixed tuple outside the table collides with SOME table tuple for at most `2M·|F|` pairs `(β, γ)`, `M` the
number of distinct table tuples. -/
theorem fold_hits_table_card (q : Tup F) (T : κ → Tup F) (hq : ∀ j, T j ≠ q) :
    (univ.filter (fun p : F × F => ∃ j, fold p.1 p.2 q = fold p.1 p.2 (T j))).card
      ≤ (univ.image T).card * (2 * Fintype.card F) := by
  have hsub : univ.filter (fun p : F × F => ∃ j, fold p.1 p.2 q = fold p.1 p.2 (T j)) ⊆ (univ.image T).biUnion
      (fun τ => univ.filter (fun p : F × F => fold p.1 p.2 q = fold p.1 p.2 τ)) := by
    intro p hp
    simp only [mem_filter, mem_univ, true_and] at hp
    obtain ⟨j, hj⟩ := hp
    exact mem_biUnion.mpr ⟨T j, mem_image_of_mem T (mem_univ j), by simp [hj]⟩
  refine (card_le_card hsub).trans (card_biUnion_le.trans ?_)
  calc ∑ τ ∈ univ.image T, (univ.filter (fun p : F × F => fold p.1 p.2 q = fold p.1 p.2 τ)).card
      ≤ ∑ _τ ∈ univ.image T, 2 * Fintype.card F := by
        refine sum_le_sum (fun τ hτ => fold_collision_card ?_)
        obtain ⟨j, -, rfl⟩ := mem_image.mp hτ
        exact Ne.symm (hq j)
    _ = (univ.image T).card * (2 * Fintype.card F) := by rw [sum_const, smul_eq_mul]

/-- **The per-block LogUp term.** Let the block's lookups be the tuples `A` (singles and pairs, `N = |ι| + 2|π|` of
them, `N < char F`), the table the tuples `T` (`M = |κ|` positions), and the committed multiplicities `m`; all fixed
before the challenges; `M` the number of DISTINCT table tuples (the count's `T_d`; padded copies of an entry count
once). If SOME looked-up tuple is not a table tuple, then over uniform independent `β, γ, α` the probability that some
helper values (chosen after `α`) satisfy every relation and the sum claim is at most `(N + 4M − 1)/|F|`: the count's
`(N_lk + 4·T_d − 1)/|Fp2|`. -/
theorem logup_block_bound (A : ι ⊕ (π ⊕ π) → Tup F) (T : κ → Tup F) (m : κ → F)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar F) (l : ι ⊕ (π ⊕ π)) (hl : ∀ j, T j ≠ A l) :
    (PMF.uniformOfFintype ((F × F) × F)).toOuterMeasure
        {ω | ∃ H, HelperRel (fun l => fold ω.1.1 ω.1.2 (A l)) (fun j => fold ω.1.1 ω.1.2 (T j)) m ω.2 H}
      ≤ (((Fintype.card ι + 2 * Fintype.card π) + 4 * (univ.image T).card - 1 : ℕ) : ℝ≥0∞) / Fintype.card F := by
  classical
  have hcardL : Fintype.card (ι ⊕ (π ⊕ π)) = Fintype.card ι + 2 * Fintype.card π := by
    rw [Fintype.card_sum, Fintype.card_sum]
    ring
  refine prob_le_of_card_mul _ _ (Fintype.card F) Fintype.card_ne_zero ?_
  rw [card_filter_prod, sum_mul]
  -- the α-slice at a pair (β, γ): at most |F| if the fold collides, else at most N + 2M − 1
  have hslice : ∀ p : F × F,
      (univ.filter (fun α : F => ∃ H, HelperRel (fun l => fold p.1 p.2 (A l)) (fun j => fold p.1 p.2 (T j))
          m α H)).card * Fintype.card F
        ≤ (if ∃ j, fold p.1 p.2 (A l) = fold p.1 p.2 (T j) then Fintype.card F * Fintype.card F else 0)
          + ((Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image T).card - 1) * Fintype.card F := by
    intro p
    split_ifs with hc
    · refine le_trans ?_ (Nat.le_add_right _ _)
      exact Nat.mul_le_mul_right _ ((card_filter_le _ _).trans (by simp))
    · rw [zero_add]
      refine Nat.mul_le_mul_right _ ?_
      have hne : logupLhs (fun l => fold p.1 p.2 (A l)) ≠ logupRhs (fun j => fold p.1 p.2 (T j)) m :=
        logup_ne_of_not_mem _ _ _ (by rw [hcardL]; exact hN) (i := l) (fun j hj => hc ⟨j, hj.symm⟩)
      have himg : (univ.image (fun j => fold p.1 p.2 (T j))).card ≤ (univ.image T).card := by
        rw [show (univ.image (fun j => fold p.1 p.2 (T j))) = (univ.image T).image (fold p.1 p.2) by
          rw [image_image]; rfl]
        exact card_image_le
      have hc' := card_helperRel_le' (fun l => fold p.1 p.2 (A l)) (fun j => fold p.1 p.2 (T j)) m hne
      have h2 : (Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image (fun j => fold p.1 p.2 (T j))).card - 1
          ≤ (Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image T).card - 1 := by omega
      refine le_trans ?_ h2
      convert hc' using 2
  refine (sum_le_sum (fun p _ => hslice p)).trans ?_
  rw [sum_add_distrib, ← sum_filter, sum_const, sum_const, smul_eq_mul, smul_eq_mul, card_univ]
  simp only [Fintype.card_prod]
  have hhit := Nat.mul_le_mul_right (Fintype.card F * Fintype.card F) (fold_hits_table_card (A l) T hl)
  calc (univ.filter (fun p : F × F => ∃ j, fold p.1 p.2 (A l) = fold p.1 p.2 (T j))).card
          * (Fintype.card F * Fintype.card F)
        + Fintype.card F * Fintype.card F
          * (((Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image T).card - 1) * Fintype.card F)
      ≤ (univ.image T).card * (2 * Fintype.card F) * (Fintype.card F * Fintype.card F)
        + Fintype.card F * Fintype.card F
          * (((Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image T).card - 1) * Fintype.card F) :=
        Nat.add_le_add_right hhit _
    _ = (2 * (univ.image T).card + ((Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image T).card - 1))
          * (Fintype.card F * Fintype.card F * Fintype.card F) := by ring
    _ ≤ ((Fintype.card ι + 2 * Fintype.card π) + 4 * (univ.image T).card - 1)
          * (Fintype.card F * Fintype.card F * Fintype.card F) := by
        apply Nat.mul_le_mul_right
        omega

end ZK60.Sound
