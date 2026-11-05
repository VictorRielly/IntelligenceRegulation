/-
D63, step L3 (soundness of the IOP): one opening of the polynomial commitment, the proximity test and the column test
composed.

The model of one opening (`pcs::verify_zk_tagged`, one claim group):
* the committed matrix `U : κ → ι → E` is fixed (the Merkle root precedes every challenge; that the opened columns
  ARE columns of one fixed `U` is Merkle binding, a separate random-oracle step);
* the claim is about the combination of the rows with fixed row weights `a` (the group's row weights) and is checked
  by a predicate `ok` on the re-encoded group vector (the code's `⟨v[..n], c⟩ = Σ λ·value`, read on the codeword:
  the verifier's encoder is injective, so a predicate on the clear vector is a predicate on its codeword);
* the verifier draws uniform independent proximity weights `ρ : κ → E`; the prover answers, as ANY functions of `ρ`,
  the group vector and the proximity vector; the verifier re-encodes them, so they are codewords `g ρ, w ρ ∈ D`;
* the verifier draws `Q` column indices uniformly with replacement, after the vectors, and checks at each one
  `g ρ (j) = (Σ_i a_i·U_i)(j)` and `w ρ (j) = (Σ_i ρ_i·U_i)(j)`.

What is proved (`opening_sound`): for any linear code of minimum distance `d` with `2e < d` and correlated agreement
on lines with `A ≥ e + 1` exceptions,

  `Pr_{ρ, J}[the verifier accepts ∧ ¬ (U is e-close to codewords V whose a-combination satisfies the claim)]`
    `≤ A/|E| + ((N − (e + 1))/N)^Q.`

The two cases are decided by `U` alone, before any challenge (the δ/2 lemma check's refinement 1: the far half and
the close half do not add):
* far: `ρ` gives an `e`-close combination with probability `≤ A/|E|` (`comb_close_cnt_mul`); otherwise the proximity
  vector's codeword differs from `Σ ρ_i·U_i` in `≥ e + 1` columns and the column test passes with probability
  `≤ ((N − (e + 1))/N)^Q` (`card_miss`);
* close, with a false claim about the decoded `V`: the group vector's codeword is a DIFFERENT codeword from
  `Σ a_i·V_i`, so it differs from `Σ a_i·U_i` in `≥ d − e ≥ e + 1` columns, for every `ρ`.

Instances: `opening_sound_rs_third` (rate 1/4, δ/3, `A = e + 1`), `opening_sound_rs_half` (rate 1/2, δ/2, `A = N`),
and `opening_sound_rs_third_counted`, the δ/3 bound written in `count.py`'s own terms:
`((2N + K')/(3N))^Q + (⌊(N − K')/3⌋ + 1 + 4096)/|E|` with `K' = K + 1` message symbols.

Not modelled here: the batching of several claims of one group by `λ` (a false member claim survives it with
probability `≤ 1/|E|`, `batch_prob`; in the close case only, so it is absorbed by `A/|E|` exactly as the lemma check
says), several groups (each group's vector is checked at the same columns; the close-case argument applies to each),
the extension-field split inside the opening (proved separately: `close_of_close_lift`), Merkle binding,
Fiat–Shamir.
-/
import ZK60Formal.SoundColumnTest
import ZK60Formal.SoundProximityRS

namespace ZK60.Sound

open scoped ENNReal
open Finset Prob Code

/-! ## Two counting facts about a pair of independent uniform draws -/

/-- If, for every first draw `a`, at most `M` second draws `b` satisfy `P (a, b)`, then `P` has probability at most
`M / |Ω₂|` under the uniform law on pairs. -/
theorem prob_prod_le_of_slices {Ω₁ Ω₂ : Type} [Fintype Ω₁] [Nonempty Ω₁] [Fintype Ω₂] [Nonempty Ω₂]
    (P : Ω₁ × Ω₂ → Prop) (M : ℕ) (h : ∀ a, cnt (fun b => P (a, b)) ≤ M) :
    (PMF.uniformOfFintype (Ω₁ × Ω₂)).toOuterMeasure {ω | P ω} ≤ (M : ℝ≥0∞) / Fintype.card Ω₂ := by
  classical
  refine prob_le_of_card_mul P M (Fintype.card Ω₂) Fintype.card_ne_zero ?_
  rw [card_filter_prod, Fintype.card_prod, sum_mul]
  calc ∑ a : Ω₁, (univ.filter (fun b => P (a, b))).card * Fintype.card Ω₂
      ≤ ∑ _a : Ω₁, M * Fintype.card Ω₂ := sum_le_sum fun a _ =>
        Nat.mul_le_mul_right _ (by rw [← cnt_eq_card_filter]; exact h a)
    _ = M * (Fintype.card Ω₁ * Fintype.card Ω₂) := by rw [sum_const, card_univ, smul_eq_mul]; ring

/-- An event of the first draw alone has, under the uniform law on pairs, the probability it has under the first
draw's uniform law: a count `|P|·q ≤ k·|Ω₁|` gives `Pr ≤ k / q`. -/
theorem prob_prod_fst_le {Ω₁ Ω₂ : Type} [Fintype Ω₁] [Nonempty Ω₁] [Fintype Ω₂] [Nonempty Ω₂]
    (P : Ω₁ → Prop) (k q : ℕ) (hq : q ≠ 0) (h : cnt P * q ≤ k * Fintype.card Ω₁) :
    (PMF.uniformOfFintype (Ω₁ × Ω₂)).toOuterMeasure {ω | P ω.1} ≤ (k : ℝ≥0∞) / q := by
  classical
  refine prob_le_of_card_mul (fun ω : Ω₁ × Ω₂ => P ω.1) k q hq ?_
  have hset : (univ.filter (fun ω : Ω₁ × Ω₂ => P ω.1)) = (univ.filter P) ×ˢ (univ : Finset Ω₂) := by
    ext ⟨a, b⟩
    simp
  rw [cnt_eq_card_filter] at h
  rw [hset, card_product, card_univ, Fintype.card_prod]
  calc (univ.filter P).card * Fintype.card Ω₂ * q = (univ.filter P).card * q * Fintype.card Ω₂ := by ring
    _ ≤ k * Fintype.card Ω₁ * Fintype.card Ω₂ := Nat.mul_le_mul_right _ h
    _ = k * (Fintype.card Ω₁ * Fintype.card Ω₂) := by ring

/-- The column factor as a count: if `x` and `y` differ in at least `t` columns, at most `(N − t)^Q` of the `N^Q`
index tuples pass all `Q` checks `x (J k) = y (J k)`. -/
theorem card_pass_le {ι F : Type} [Fintype ι] [DecidableEq ι] [DecidableEq F] (x y : ι → F) {t : ℕ} (Q : ℕ)
    (ht : t ≤ (univ.filter (fun j => x j ≠ y j)).card) :
    (univ.filter (fun J : Fin Q → ι => ∀ k, x (J k) = y (J k))).card ≤ (Fintype.card ι - t) ^ Q := by
  have hset : univ.filter (fun J : Fin Q → ι => ∀ k, x (J k) = y (J k))
      = univ.filter (fun J : Fin Q → ι => ∀ k, J k ∉ univ.filter (fun j => x j ≠ y j)) := by
    ext J
    simp
  rw [hset, card_miss]
  exact Nat.pow_le_pow_left (by omega) Q

/-- The column factor as a probability: `(N − t)^Q / N^Q = ((N − t)/N)^Q`. -/
theorem col_term_eq {ι : Type} [Fintype ι] [DecidableEq ι] (t Q : ℕ) :
    (((Fintype.card ι - t) ^ Q : ℕ) : ℝ≥0∞) / Fintype.card (Fin Q → ι)
      = (((Fintype.card ι - t : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  rw [Fintype.card_fun, Fintype.card_fin, Nat.cast_pow, Nat.cast_pow, ennreal_div_pow]

variable {E ι κ : Type} [Field E]

/-- A word that disagrees with some codeword in at most `e` columns is `e`-close. -/
theorem close_of_card_ne_le [Fintype ι] [DecidableEq ι] [DecidableEq E] {D : Submodule E (ι → E)} {e : ℕ}
    {c x : ι → E} (hc : c ∈ D) (h : (univ.filter (fun j => c j ≠ x j)).card ≤ e) :
    Close D e (fun _ : Unit => x) := by
  refine ⟨(univ.filter (fun j => c j ≠ x j))ᶜ, ?_, fun _ => mem_agreeOn.mpr ⟨c, hc, fun j hj => ?_⟩⟩
  · rw [card_compl]
    have := card_le_univ (univ.filter (fun j => c j ≠ x j))
    omega
  · have hj' : ¬ (c j ≠ x j) := fun hne => (mem_compl.mp hj) (mem_filter.mpr ⟨mem_univ j, hne⟩)
    exact (not_not.mp hj').symm

/-- The verifier's checks in one opening: the claim check on the group vector's codeword `g ρ`, and at each of the
`Q` sampled columns the group vector against `Σ_i a_i·U_i` and the proximity vector `w ρ` against `Σ_i ρ_i·U_i`. -/
abbrev OpeningAccepts [Fintype κ] (U : κ → ι → E) (a : κ → E) (ok : (ι → E) → Prop)
    (g w : (κ → E) → ι → E) {Q : ℕ} (ρ : κ → E) (J : Fin Q → ι) : Prop :=
  ok (g ρ) ∧ (∀ k, g ρ (J k) = comb U a (J k)) ∧ ∀ k, w ρ (J k) = comb U ρ (J k)

/-- The good case: `U` agrees, outside at most `e` columns, with rows `V` of the code, and the claim is TRUE of
`Σ_i a_i·V_i`. In the close case `V` is unique (`Close.unique`), so this says that the extracted data satisfies the
claim. -/
abbrev OpeningGood [Fintype ι] [Fintype κ] (D : Submodule E (ι → E)) (e : ℕ) (U : κ → ι → E) (a : κ → E)
    (ok : (ι → E) → Prop) : Prop :=
  ∃ V : κ → ι → E, (∀ i, V i ∈ D) ∧
    (∃ S : Finset ι, Fintype.card ι ≤ S.card + e ∧ ∀ j ∈ S, ∀ i, U i j = V i j) ∧ ok (comb V a)

/-- **One opening is sound (task 4).** Let the code `D` have minimum distance `d`, `2e < d`, and correlated
agreement on lines with at most `A ≥ e + 1` exceptions. For any committed matrix `U`, any claim, and any prover
(the vectors `g ρ`, `w ρ` may depend on `ρ` arbitrarily), the verifier accepts while `U` does not decode to rows that
satisfy the claim with probability at most `A/|E| + ((N − (e + 1))/N)^Q`, over uniform `ρ` and `Q` uniform column
indices drawn with replacement. -/
theorem opening_sound [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype κ]
    [DecidableEq κ] {D : Submodule E (ι → E)} {d e A : ℕ} (hd : MinDist D d) (h2 : 2 * e < d)
    (hA : e + 1 ≤ A) (hca : CAOn Unit D e A) (U : κ → ι → E) (a : κ → E) (ok : (ι → E) → Prop)
    (g w : (κ → E) → ι → E) (hg : ∀ ρ, g ρ ∈ D) (hw : ∀ ρ, w ρ ∈ D) (Q : ℕ) :
    (PMF.uniformOfFintype ((κ → E) × (Fin Q → ι))).toOuterMeasure
        {ω | OpeningAccepts U a ok g w ω.1 ω.2 ∧ ¬ OpeningGood D e U a ok}
      ≤ (A : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  classical
  by_cases hc : Close D e U
  · -- close: decode `U`
    obtain ⟨V, S, hV, hS, hUV⟩ := hc.exists_table
    by_cases hok : ok (comb V a)
    · -- the claim is true of the decoded rows: the event is empty
      have hempty : {ω : (κ → E) × (Fin Q → ι) | OpeningAccepts U a ok g w ω.1 ω.2 ∧ ¬ OpeningGood D e U a ok}
          = ∅ := by
        ext ω
        simp only [Set.mem_ofPred_eq, Set.mem_empty_iff_false, iff_false, not_and, not_not]
        exact fun _ => Exists.intro V ⟨hV, ⟨S, hS, hUV⟩, hok⟩
      rw [hempty, MeasureTheory.measure_empty]
      exact zero_le
    · -- a false claim: the group vector's codeword differs from `Σ a_i U_i` in at least `d − e ≥ e + 1` columns
      have hslice : ∀ ρ : κ → E,
          cnt (fun J : Fin Q → ι => OpeningAccepts U a ok g w ρ J ∧ ¬ OpeningGood D e U a ok)
            ≤ (Fintype.card ι - (e + 1)) ^ Q := by
        intro ρ
        rw [cnt_eq_card_filter]
        by_cases hgρ : ok (g ρ)
        · have hne : g ρ ≠ comb V a := fun h => hok (h ▸ hgρ)
          have hcomb : comb V a ∈ D := D.sum_mem fun i _ => D.smul_mem _ (hV i)
          have hdist := hd _ (D.sub_mem (hg ρ) hcomb) (sub_ne_zero.mpr hne)
          rw [cnt_eq_card_filter] at hdist
          -- on `S`, `Σ a_i U_i = Σ a_i V_i`
          have hagree : ∀ j ∈ S, comb U a j = comb V a j := by
            intro j hj
            rw [comb_apply, comb_apply]
            exact sum_congr rfl fun i _ => by rw [hUV j hj i]
          have hsub : (univ.filter (fun j => (g ρ - comb V a) j ≠ 0))
              ⊆ (univ.filter (fun j => g ρ j ≠ comb U a j)) ∪ Sᶜ := by
            intro j hj
            by_cases hjS : j ∈ S
            · refine mem_union_left _ (mem_filter.mpr ⟨mem_univ j, ?_⟩)
              rw [hagree j hjS]
              have := (mem_filter.mp hj).2
              rwa [Pi.sub_apply, sub_ne_zero] at this
            · exact mem_union_right _ (mem_compl.mpr hjS)
          have h1 := (card_le_card hsub).trans (card_union_le _ _)
          rw [card_compl] at h1
          have ht : e + 1 ≤ (univ.filter (fun j => g ρ j ≠ comb U a j)).card := by omega
          refine le_trans (card_le_card fun J hJ => ?_) (card_pass_le (g ρ) (comb U a) Q ht)
          exact mem_filter.mpr ⟨mem_univ J, ((mem_filter.mp hJ).2.1).2.1⟩
        · refine le_trans (le_of_eq (card_eq_zero.mpr (filter_eq_empty_iff.mpr fun J _ hJ => ?_)))
            (Nat.zero_le _)
          exact hgρ hJ.1.1
      refine le_trans (prob_prod_le_of_slices _ _ hslice) ?_
      rw [col_term_eq]
      exact le_add_self
  · -- far
    have hsplit : {ω : (κ → E) × (Fin Q → ι) | OpeningAccepts U a ok g w ω.1 ω.2 ∧ ¬ OpeningGood D e U a ok}
        ⊆ {ω | Close D e (fun _ : Unit => comb U ω.1)}
          ∪ {ω | ¬ Close D e (fun _ : Unit => comb U ω.1) ∧ ∀ k, w ω.1 (ω.2 k) = comb U ω.1 (ω.2 k)} := by
      intro ω hω
      by_cases hω1 : Close D e (fun _ : Unit => comb U ω.1)
      · exact Or.inl hω1
      · exact Or.inr ⟨hω1, hω.1.2.2⟩
    refine le_trans (MeasureTheory.measure_mono hsplit) (le_trans (MeasureTheory.measure_union_le _ _) ?_)
    refine add_le_add ?_ ?_
    · -- the proximity test
      exact prob_prod_fst_le (fun ρ : κ → E => Close D e (fun _ : Unit => comb U ρ)) A (Fintype.card E)
        Fintype.card_ne_zero (comb_close_cnt_mul hd h2 hA hca U hc)
    · -- the column test against the proximity vector
      have hslice : ∀ ρ : κ → E,
          cnt (fun J : Fin Q → ι => ¬ Close D e (fun _ : Unit => comb U ρ) ∧ ∀ k, w ρ (J k) = comb U ρ (J k))
            ≤ (Fintype.card ι - (e + 1)) ^ Q := by
        intro ρ
        rw [cnt_eq_card_filter]
        by_cases hρ : Close D e (fun _ : Unit => comb U ρ)
        · refine le_trans (le_of_eq (card_eq_zero.mpr (filter_eq_empty_iff.mpr fun J _ hJ => ?_)))
            (Nat.zero_le _)
          exact hJ.1 hρ
        · have ht : e + 1 ≤ (univ.filter (fun j => w ρ j ≠ comb U ρ j)).card := by
            by_contra hlt
            exact hρ (close_of_card_ne_le (hw ρ) (by omega))
          refine le_trans (card_le_card fun J hJ => ?_) (card_pass_le (w ρ) (comb U ρ) Q ht)
          exact mem_filter.mpr ⟨mem_univ J, (mem_filter.mp hJ).2.2⟩
      refine le_trans (prob_prod_le_of_slices
        (fun ω : (κ → E) × (Fin Q → ι) => ¬ Close D e (fun _ : Unit => comb U ω.1)
          ∧ ∀ k, w ω.1 (ω.2 k) = comb U ω.1 (ω.2 k)) _ hslice) ?_
      rw [col_term_eq]

/-! ## Our Reed–Solomon code -/

/-- **One opening at rate 1/4 (δ/3, D15).** The RS code of degree `≤ K` at `N` distinct points with
`3e + K + 1 ≤ N`: a false claim, or a far matrix, passes with probability at most
`(e + 1)/|E| + ((N − (e + 1))/N)^Q`. -/
theorem opening_sound_rs_third [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype κ]
    [DecidableEq κ] (dom : ι ↪ E) {e K : ℕ} (hn : 3 * e + K + 1 ≤ Fintype.card ι)
    (U : κ → ι → E) (a : κ → E) (ok : (ι → E) → Prop)
    (g w : (κ → E) → ι → E) (hg : ∀ ρ, g ρ ∈ rsCode dom K) (hw : ∀ ρ, w ρ ∈ rsCode dom K) (Q : ℕ) :
    (PMF.uniformOfFintype ((κ → E) × (Fin Q → ι))).toOuterMeasure
        {ω | OpeningAccepts U a ok g w ω.1 ω.2 ∧ ¬ OpeningGood (rsCode dom K) e U a ok}
      ≤ ((e + 1 : ℕ) : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q :=
  opening_sound (minDist_rsCode dom K) (by omega) le_rfl (caOn_third (minDist_rsCode dom K) (by omega))
    U a ok g w hg hw Q

/-- **One opening at rate 1/2 (δ/2, D59; BCIKS20 Thm 3.1).** The RS code of degree `≤ K` at `N` distinct points
with `2e + K + 1 ≤ N`: a false claim, or a far matrix, passes with probability at most
`N/|E| + ((N − (e + 1))/N)^Q`: the lemma check's per-opening bound, in `count.py`'s exact integer form. -/
theorem opening_sound_rs_half [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype κ]
    [DecidableEq κ] (dom : ι ↪ E) {e K : ℕ} (hn : 2 * e + K + 1 ≤ Fintype.card ι)
    (U : κ → ι → E) (a : κ → E) (ok : (ι → E) → Prop)
    (g w : (κ → E) → ι → E) (hg : ∀ ρ, g ρ ∈ rsCode dom K) (hw : ∀ ρ, w ρ ∈ rsCode dom K) (Q : ℕ) :
    (PMF.uniformOfFintype ((κ → E) × (Fin Q → ι))).toOuterMeasure
        {ω | OpeningAccepts U a ok g w ω.1 ω.2 ∧ ¬ OpeningGood (rsCode dom K) e U a ok}
      ≤ (Fintype.card ι : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q :=
  opening_sound (minDist_rsCode dom K) (by omega) (by omega) (caOn_rsCode dom hn) U a ok g w hg hw Q

/-- **The rate-1/4 opening in `count.py`'s own terms.** With `K' = K + 1` message symbols (`n + q_pad`) and
`e = ⌊(N − K')/3⌋` (any `e` with `3e + K' ≤ N < 3(e + 1) + K'`), one opening is accepted with a far matrix or a false
claim with probability at most `((2N + K')/(3N))^Q + (e + 1 + 4096)/|E|`: `count.py`'s
`regular("delta/3", n, inv_rate, Q)` column and field terms (with the R14 counter's carried ceiling 4096). -/
theorem opening_sound_rs_third_counted [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι]
    [Fintype κ] [DecidableEq κ] (dom : ι ↪ E) {e K : ℕ} (hn : 3 * e + K + 1 ≤ Fintype.card ι)
    (he : Fintype.card ι - (K + 1) ≤ 3 * (e + 1))
    (U : κ → ι → E) (a : κ → E) (ok : (ι → E) → Prop)
    (g w : (κ → E) → ι → E) (hg : ∀ ρ, g ρ ∈ rsCode dom K) (hw : ∀ ρ, w ρ ∈ rsCode dom K) (Q : ℕ) :
    (PMF.uniformOfFintype ((κ → E) × (Fin Q → ι))).toOuterMeasure
        {ω | OpeningAccepts U a ok g w ω.1 ω.2 ∧ ¬ OpeningGood (rsCode dom K) e U a ok}
      ≤ (((2 * Fintype.card ι + (K + 1) : ℕ) : ℝ≥0∞) / (3 * Fintype.card ι : ℕ)) ^ Q
        + ((e + 1 + 4096 : ℕ) : ℝ≥0∞) / Fintype.card E := by
  calc _ ≤ ((e + 1 : ℕ) : ℝ≥0∞) / Fintype.card E
          + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q :=
        opening_sound_rs_third dom hn U a ok g w hg hw Q
    _ ≤ ((e + 1 + 4096 : ℕ) : ℝ≥0∞) / Fintype.card E
          + (((2 * Fintype.card ι + (K + 1) : ℕ) : ℝ≥0∞) / (3 * Fintype.card ι : ℕ)) ^ Q :=
        add_le_add (ENNReal.div_le_div_right (by exact_mod_cast (by omega : e + 1 ≤ e + 1 + 4096)) _)
          (third_column_le Fintype.card_pos he Q)
    _ = _ := add_comm _ _

end ZK60.Sound
