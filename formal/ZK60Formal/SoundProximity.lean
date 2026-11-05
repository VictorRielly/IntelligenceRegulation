/-
D63, step L3 (soundness of the IOP): the proximity test of the polynomial commitment, for any linear code.

The commitment holds an `m × N` matrix `U` whose rows should be codewords (`pcs.rs`: each row Reed–Solomon encoded).
The verifier draws INDEPENDENT uniform row weights `ρ ∈ E^m` (`prox_rho = tr.challenge_fp2_vec(rows)`) and
receives the combination `Σ_i ρ_i·U_i` in the clear (the proximity vector, re-encoded by the verifier). The question
this file answers: if `U` is far from the interleaved code, how likely is the combination to be close to the code?

Vocabulary (from the ported FlashProve files, `ThirdParty/FlashProve/Code/`):
* a code is a subspace `D` of `ι → E`, with `MinDist D d`: every nonzero codeword has at least `d` nonzero symbols;
* `Close D e f` for an interleaved word `f : R → ι → E`: on one common set of all but at most `e` columns, every
  row agrees with a codeword. For one word `w` it is `Close D e (fun _ : Unit => w)`;
* `CAOn Unit D e A`, correlated agreement on lines with at most `A` exceptions: for two words `f₀, f₁` that are not
  close TOGETHER, `f₀ + z·f₁` is close for at most `A` values `z`.

What is proved here (all for any linear code, any finite field, any number `m` of rows):
* `comb_close_cnt_mul`, `comb_close_prob`: **from lines to independent weights, with no loss.** If the code has
  minimum distance `d`, `2e < d`, lines have at most `A ≥ e + 1` exceptions, and `U` is not `e`-close to the
  interleaved code, then `Pr_ρ[Σ_i ρ_i·U_i is e-close] ≤ A/|E|`. The proof: if some combination `Σ b_i U_i` is far,
  every line `a + z·b` of weights meets the close set at most `A` times, and the lines in direction `b` partition the
  weight space; if every combination is close, the decoding map is linear (unique decoding) and a counting argument
  gives `|E| ≤ e + 1 ≤ A`, in which case the bound is trivial. This is the form BCIKS20 Thm 1.7 / Thm 3.1 state
  (the same error as for lines), here derived for every code from the line bound.
* `caOn_third`, `proximity_third`: **the δ/3 regime, elementary** (Ligero, Ames–Hazay–Ishai–Venkitasubramaniam,
  Lemma 4.2 style). For `3e < d` lines have at most `e + 1` exceptions (`Code.cnt_close_le`, the Roth–Zémor argument,
  ported), so `Pr_ρ[Σ_i ρ_i·U_i is e-close] ≤ (e + 1)/|E|` for every `U` that is `e`-far.
* `affine_close_prob`, `affine_proximity_third`: the AFFINE form `u + Σ_i r_i·U_i` of the mask commitment `M`
  (`zk::mask_verify_tagged`: the proximity mask rows carry the fixed coefficient 1), by homogenizing, at the cost of
  a factor `|E|/(|E| − 1)`: `(e + 1)/(|E| − 1)` at δ/3.

The Reed–Solomon instances (`d = N − K` for degree `≤ K`, i.e. `d = N − k + 1` for `k = K + 1` message symbols), the
extension-field reading (rows over `F_p`, weights over `F_p²`) and the unique-decoding radius are in
`SoundProximityRS.lean`.

Interactive: `ρ` exactly uniform; `U` fixed before `ρ` (the Merkle root precedes the challenges).
-/
import ZK60Formal.SoundSchwartzZippel
import ZK60Formal.ThirdParty.FlashProve.Code.Mutual

namespace ZK60.Sound

open scoped ENNReal
open Finset Prob Code

variable {E ι κ : Type} [Field E] [Fintype ι] [Fintype κ]

/-- The combination of the rows `U` with the weights `r`: `Σ_i r_i·U_i` (the code's `ρᵀ·M` on the encoded rows). -/
def comb (U : κ → ι → E) (r : κ → E) : ι → E := ∑ i, r i • U i

omit [Fintype ι] in
/-- One symbol of a combination: `(Σ_i r_i·U_i)_j = Σ_i r_i·U_{i,j}`, what the verifier computes from an opened
column. -/
theorem comb_apply (U : κ → ι → E) (r : κ → E) (j : ι) : comb U r j = ∑ i, r i * U i j := by
  simp [comb, Finset.sum_apply, smul_eq_mul]

omit [Fintype ι] in
/-- Combinations are additive in the weights. -/
theorem comb_add (U : κ → ι → E) (a b : κ → E) : comb U (a + b) = comb U a + comb U b := by
  simp [comb, add_smul, sum_add_distrib]

omit [Fintype ι] in
/-- Combinations are homogeneous in the weights. -/
theorem comb_smul (U : κ → ι → E) (c : E) (a : κ → E) : comb U (c • a) = c • comb U a := by
  simp [comb, smul_sum, mul_smul]

omit [Fintype ι] in
/-- The weights on the line `a + z·b` give the point `comb a + z·comb b` of the line of combinations. -/
theorem comb_add_smul (U : κ → ι → E) (a b : κ → E) (z : E) :
    comb U (a + z • b) = comb U a + z • comb U b := by
  rw [comb_add, comb_smul]

/-- If the second word of a pair is not close, the pair is not close together. -/
theorem not_close_pair_of_right {D : Submodule E (ι → E)} {e : ℕ} {f₀ f₁ : Unit → ι → E}
    (h : ¬ Close D e f₁) : ¬ Close D e (Sum.elim f₀ f₁) := by
  intro hc
  have h1 := hc.comp Sum.inr
  rw [Sum.elim_comp_inr] at h1
  exact h h1

/-- Counting the pairs `(a, b)` with a property by rows or by columns. -/
theorem sum_cnt_swap {α β : Type} [Fintype α] [Fintype β] (P : α → β → Prop) :
    ∑ a, cnt (fun b => P a b) = ∑ b, cnt (fun a => P a b) := by
  classical
  simp only [cnt_eq_card_filter, card_filter]
  exact sum_comm

/-- **A far direction.** If some combination `comb U b` is not close, then along every line `a + z·b` of weights at
most `A` points give a close combination (correlated agreement for the pair `comb U a`, `comb U b`, which is not
close together). The `|E|^(m−1)` parallel lines in direction `b` cover the weight space, so
`(number of weights with a close combination)·|E| ≤ A·|E|^m`. -/
theorem comb_close_cnt_of_far_dir [Fintype E] [DecidableEq κ] {D : Submodule E (ι → E)} {e A : ℕ}
    (hca : CAOn Unit D e A)
    (U : κ → ι → E) (b : κ → E) (hb : ¬ Close D e (fun _ : Unit => comb U b)) :
    cnt (fun r : κ → E => Close D e (fun _ : Unit => comb U r)) * Fintype.card E
      ≤ A * Fintype.card (κ → E) := by
  have hline : ∀ a : κ → E, cnt (fun z : E => Close D e (fun _ : Unit => comb U (a + z • b))) ≤ A := by
    intro a
    have h := hca (fun _ => comb U a) (fun _ => comb U b) (not_close_pair_of_right hb)
    refine le_trans (le_of_eq (cnt_congr fun z => ?_)) h
    rw [comb_add_smul]
  have htrans : ∀ z : E, cnt (fun a : κ → E => Close D e (fun _ : Unit => comb U (a + z • b)))
      = cnt (fun r : κ → E => Close D e (fun _ : Unit => comb U r)) := fun z =>
    cnt_equiv (Equiv.addRight (z • b)) (fun r => Close D e (fun _ : Unit => comb U r))
  calc cnt (fun r : κ → E => Close D e (fun _ : Unit => comb U r)) * Fintype.card E
      = ∑ z : E, cnt (fun a : κ → E => Close D e (fun _ : Unit => comb U (a + z • b))) := by
        rw [sum_congr rfl (fun z _ => htrans z), sum_const, card_univ, smul_eq_mul, mul_comm]
    _ = ∑ a : κ → E, cnt (fun z : E => Close D e (fun _ : Unit => comb U (a + z • b))) :=
        (sum_cnt_swap (fun a z => Close D e (fun _ : Unit => comb U (a + z • b)))).symm
    _ ≤ ∑ _a : κ → E, A := sum_le_sum fun a _ => hline a
    _ = A * Fintype.card (κ → E) := by rw [sum_const, card_univ, smul_eq_mul, mul_comm]

/-- A nonzero linear form `r ↦ Σ_i r_i·h_i` vanishes on at most `|E|^(m−1)` weight vectors (written: times `|E|`, at
most `|E|^m`). -/
theorem cnt_dot_zero_mul_le [Fintype E] [DecidableEq κ] (h : κ → E) (hh : ∃ k, h k ≠ 0) :
    cnt (fun r : κ → E => ∑ i, r i * h i = 0) * Fintype.card E ≤ Fintype.card (κ → E) := by
  classical
  obtain ⟨k₀, hk₀⟩ := hh
  rw [cnt_eq_card_filter]
  let eqv := Equiv.piSplitAt k₀ (fun _ : κ => E)
  have hcard : (univ.filter (fun r : κ → E => ∑ i, r i * h i = 0)).card
      ≤ (univ : Finset ({k // k ≠ k₀} → E)).card := by
    refine card_le_card_of_injOn (fun r => (eqv r).2) (fun _ _ => mem_univ _) ?_
    intro r₁ h₁' r₂ h₂' h12
    have h₁ : ∑ i, r₁ i * h i = 0 := by simpa using h₁'
    have h₂ : ∑ i, r₂ i * h i = 0 := by simpa using h₂'
    have hrest : ∀ k, k ≠ k₀ → r₁ k = r₂ k := fun k hk => congrFun h12 ⟨k, hk⟩
    have hsplit : ∀ r : κ → E, ∑ i, r i * h i = r k₀ * h k₀ + ∑ i ∈ ({k₀}ᶜ : Finset κ), r i * h i :=
      fun r => Fintype.sum_eq_add_sum_compl k₀ _
    have hsum : ∑ i ∈ ({k₀}ᶜ : Finset κ), r₁ i * h i = ∑ i ∈ ({k₀}ᶜ : Finset κ), r₂ i * h i :=
      sum_congr rfl (fun k hk => by rw [hrest k (by simpa using hk)])
    have h0 : r₁ k₀ = r₂ k₀ := by
      have := h₁.trans h₂.symm
      rw [hsplit, hsplit, hsum] at this
      exact mul_right_cancel₀ hk₀ (add_right_cancel this)
    funext k
    by_cases hk : k = k₀
    · subst hk; exact h0
    · exact hrest k hk
  have hsize : Fintype.card ({k // k ≠ k₀} → E) * Fintype.card E = Fintype.card (κ → E) := by
    rw [Fintype.card_congr eqv, Fintype.card_prod, mul_comm]
  calc (univ.filter (fun r : κ → E => ∑ i, r i * h i = 0)).card * Fintype.card E
      ≤ (univ : Finset ({k // k ≠ k₀} → E)).card * Fintype.card E := Nat.mul_le_mul_right _ hcard
    _ = Fintype.card (κ → E) := by rw [card_univ, hsize]

/-- **Every combination close is impossible for a far matrix over a large field.** Let `2e < d` and let lines have at
most `A ≥ e + 1` exceptions. If every combination of the rows of `U` is `e`-close and `|E| > A`, then `U` is `e`-close.
(Every pair of combinations is then close together, so the unique decoding `v` of combinations is linear,
`v(r) = Σ_i r_i·V_i` with codewords `V_i`; if `U` and `V` differed in `e + 1` columns, some weight vector would be
nonzero on all of them, since `(e + 1)·|E|^(m−1) < |E|^m`, and its combination would be `(e + 1)`-far from its own
decoding.) -/
theorem all_close_absurd [Fintype E] [DecidableEq κ] {D : Submodule E (ι → E)} {d e A : ℕ}
    (hd : MinDist D d) (h2 : 2 * e < d) (hA : e + 1 ≤ A) (hca : CAOn Unit D e A)
    (U : κ → ι → E) (hfar : ¬ Close D e U)
    (hall : ∀ r : κ → E, Close D e (fun _ : Unit => comb U r)) (hq : A < Fintype.card E) : False := by
  classical
  -- (1) every pair of combinations is close together: the whole line is close and `|E| > A`
  have hpair : ∀ a b : κ → E,
      Close D e (Sum.elim (fun _ : Unit => comb U a) (fun _ : Unit => comb U b)) := by
    intro a b
    by_contra hab
    have h1 := hca _ _ hab
    have h3 : Fintype.card E ≤ A :=
      calc Fintype.card E = cnt (fun _ : E => True) := cnt_true.symm
        _ ≤ cnt (fun θ : E => Close D e (fun _ : Unit => comb U a + θ • comb U b)) :=
            cnt_mono fun z _ => by rw [← comb_add_smul]; exact hall _
        _ ≤ A := h1
    omega
  -- (2) decode every combination
  have hex : ∀ r : κ → E, ∃ c : ι → E, ∃ S : Finset ι,
      c ∈ D ∧ Fintype.card ι ≤ S.card + e ∧ ∀ j ∈ S, comb U r j = c j := by
    intro r
    obtain ⟨g, S, hg, hS, hgS⟩ := (hall r).exists_table
    exact ⟨g (), S, hg (), hS, fun j hj => hgS j hj ()⟩
  choose v S hv hS hvS using hex
  -- (3) the decoding is unique
  have huniq : ∀ (r : κ → E) (c : ι → E) (T : Finset ι), c ∈ D → Fintype.card ι ≤ T.card + e →
      (∀ j ∈ T, comb U r j = c j) → c = v r := fun r c T hc hT hcT =>
    hd.decode_unique h2 hc (hv r) hT (hS r) hcT (hvS r)
  -- (4) it is additive
  have hadd : ∀ a b : κ → E, v (a + b) = v a + v b := by
    intro a b
    obtain ⟨T, hT, h0, h1⟩ := close_sumElim_iff.mp (hpair a b)
    obtain ⟨c₀, hc₀, hT₀⟩ := mem_agreeOn.mp (h0 ())
    obtain ⟨c₁, hc₁, hT₁⟩ := mem_agreeOn.mp (h1 ())
    have hT₀' : ∀ j ∈ T, comb U a j = c₀ j := hT₀
    have hT₁' : ∀ j ∈ T, comb U b j = c₁ j := hT₁
    have e₀ := huniq a c₀ T hc₀ hT hT₀'
    have e₁ := huniq b c₁ T hc₁ hT hT₁'
    refine (huniq (a + b) (v a + v b) T (D.add_mem (hv a) (hv b)) hT fun j hj => ?_).symm
    rw [comb_add, Pi.add_apply, Pi.add_apply, hT₀' j hj, hT₁' j hj, e₀, e₁]
  -- (5) and homogeneous
  have hsmul : ∀ (c : E) (a : κ → E), v (c • a) = c • v a := by
    intro c a
    refine (huniq (c • a) (c • v a) (S a) (D.smul_mem c (hv a)) (hS a) fun j hj => ?_).symm
    rw [comb_smul, Pi.smul_apply, Pi.smul_apply, hvS a j hj]
  -- (6) so it is the combination of the decoded basis vectors
  let vL : (κ → E) →ₗ[E] (ι → E) :=
    { toFun := v
      map_add' := hadd
      map_smul' := fun c a => by simp only [RingHom.id_apply]; exact hsmul c a }
  obtain ⟨V, hVdef⟩ : ∃ V : κ → ι → E, V = fun i => v (fun j => if i = j then 1 else 0) := ⟨_, rfl⟩
  have hVD : ∀ i, V i ∈ D := fun i => by rw [hVdef]; exact hv _
  have hvL : ∀ x, vL x = v x := fun _ => rfl
  have hvlin : ∀ r, v r = comb V r := by
    intro r
    rw [← hvL r, vL.pi_apply_eq_sum_univ r, hVdef]
    simp only [hvL, comb]
  -- (7) `U` is far, so it differs from `V` in at least `e + 1` columns
  obtain ⟨W, hWdef⟩ : ∃ W : Finset ι, W = univ.filter (fun j : ι => ∃ i, U i j ≠ V i j) := ⟨_, rfl⟩
  have hW : e + 1 ≤ W.card := by
    by_contra hlt
    apply hfar
    refine ⟨Wᶜ, ?_, fun i => mem_agreeOn.mpr ⟨V i, hVD i, fun j hj => ?_⟩⟩
    · rw [card_compl]
      have := card_le_univ W
      omega
    · by_contra hne
      rw [hWdef] at hj
      exact (mem_compl.mp hj) (mem_filter.mpr ⟨mem_univ j, i, hne⟩)
  -- (8) some weight vector is nonzero on `e + 1` of those columns
  obtain ⟨W', hW'sub, hW'card⟩ := Finset.exists_subset_card_eq hW
  have hnz : ∀ j ∈ W', ∃ i, (fun i => U i j - V i j) i ≠ 0 := by
    intro j hj
    have hj' := hW'sub hj
    rw [hWdef] at hj'
    obtain ⟨i, hi⟩ := (mem_filter.mp hj').2
    exact ⟨i, sub_ne_zero.mpr hi⟩
  have hker : ∀ j ∈ W', (univ.filter (fun r : κ → E => ∑ i, r i * (U i j - V i j) = 0)).card
      * Fintype.card E ≤ Fintype.card (κ → E) := by
    intro j hj
    have h := cnt_dot_zero_mul_le (fun i => U i j - V i j) (hnz j hj)
    rwa [cnt_eq_card_filter] at h
  have hexr : ∃ r : κ → E, ∀ j ∈ W', ∑ i, r i * (U i j - V i j) ≠ 0 := by
    by_contra hnone
    push Not at hnone
    have hcov : (univ : Finset (κ → E)) ⊆ W'.biUnion
        (fun j => univ.filter (fun r : κ → E => ∑ i, r i * (U i j - V i j) = 0)) := by
      intro r _
      obtain ⟨j, hj, hr⟩ := hnone r
      exact mem_biUnion.mpr ⟨j, hj, mem_filter.mpr ⟨mem_univ r, hr⟩⟩
    have h1 := card_univ.symm.trans_le ((card_le_card hcov).trans card_biUnion_le)
    have h2 : Fintype.card (κ → E) * Fintype.card E ≤ (e + 1) * Fintype.card (κ → E) :=
      calc Fintype.card (κ → E) * Fintype.card E
          ≤ (∑ j ∈ W', (univ.filter (fun r : κ → E => ∑ i, r i * (U i j - V i j) = 0)).card)
              * Fintype.card E := Nat.mul_le_mul_right _ h1
        _ = ∑ j ∈ W', (univ.filter (fun r : κ → E => ∑ i, r i * (U i j - V i j) = 0)).card
              * Fintype.card E := sum_mul ..
        _ ≤ ∑ _j ∈ W', Fintype.card (κ → E) := sum_le_sum hker
        _ = (e + 1) * Fintype.card (κ → E) := by rw [sum_const, hW'card, smul_eq_mul]
    have hpos : 0 < Fintype.card (κ → E) := Fintype.card_pos
    have hle : Fintype.card E ≤ e + 1 :=
      Nat.le_of_mul_le_mul_left (h2.trans_eq (mul_comm _ _)) hpos
    omega
  -- (9) its combination differs from its decoding on `e + 1` columns: a contradiction
  obtain ⟨r, hr⟩ := hexr
  have hsub : W' ⊆ (S r)ᶜ := by
    intro j hj
    rw [mem_compl]
    intro hjS
    apply hr j hj
    have h1 := hvS r j hjS
    rw [hvlin r, comb_apply, comb_apply] at h1
    simp only [mul_sub, sum_sub_distrib]
    rw [h1, sub_self]
  have h5 := card_le_card hsub
  rw [card_compl] at h5
  have h6 := hS r
  omega

/-- **From lines to independent uniform weights, counted.** Let the code have minimum distance `d`, `2e < d`, and let
correlated agreement on lines hold with at most `A ≥ e + 1` exceptions. If `U` (any number of rows) is not `e`-close
to the interleaved code, then at most `A·|E|^(m−1)` of the `|E|^m` weight vectors give an `e`-close combination. -/
theorem comb_close_cnt_mul [Fintype E] [DecidableEq κ] {D : Submodule E (ι → E)} {d e A : ℕ}
    (hd : MinDist D d) (h2 : 2 * e < d) (hA : e + 1 ≤ A) (hca : CAOn Unit D e A)
    (U : κ → ι → E) (hfar : ¬ Close D e U) :
    cnt (fun r : κ → E => Close D e (fun _ : Unit => comb U r)) * Fintype.card E
      ≤ A * Fintype.card (κ → E) := by
  by_cases hB : ∃ b : κ → E, ¬ Close D e (fun _ : Unit => comb U b)
  · obtain ⟨b, hb⟩ := hB
    exact comb_close_cnt_of_far_dir hca U b hb
  · push Not at hB
    have hq : Fintype.card E ≤ A := by
      by_contra hlt
      exact all_close_absurd hd h2 hA hca U hfar hB (not_le.mp hlt)
    calc cnt (fun r : κ → E => Close D e (fun _ : Unit => comb U r)) * Fintype.card E
        ≤ Fintype.card (κ → E) * A := Nat.mul_le_mul (cnt_le_card _) hq
      _ = A * Fintype.card (κ → E) := mul_comm _ _

/-- **From lines to independent uniform weights (the proximity test).** Under the hypotheses of `comb_close_cnt_mul`,
a uniformly random weight vector `ρ` gives an `e`-close combination `Σ_i ρ_i·U_i` with probability at most
`A / |E|`: the same error as for lines, whatever the number of rows. -/
theorem comb_close_prob [Fintype E] [DecidableEq κ] {D : Submodule E (ι → E)} {d e A : ℕ}
    (hd : MinDist D d) (h2 : 2 * e < d) (hA : e + 1 ≤ A) (hca : CAOn Unit D e A)
    (U : κ → ι → E) (hfar : ¬ Close D e U) :
    (PMF.uniformOfFintype (κ → E)).toOuterMeasure {r | Close D e (fun _ : Unit => comb U r)}
      ≤ (A : ℝ≥0∞) / Fintype.card E := by
  classical
  refine prob_le_of_card_mul (fun r : κ → E => Close D e (fun _ : Unit => comb U r)) A (Fintype.card E)
    Fintype.card_ne_zero ?_
  rw [← cnt_eq_card_filter]
  exact comb_close_cnt_mul hd h2 hA hca U hfar

/-- **Lines up to a third of the distance** (Roth–Zémor; Ames–Hazay–Ishai–Venkitasubramaniam, Appendix A): for any
linear code of minimum distance `d` and `3e < d`, two words that are not `e`-close together have at most `e + 1`
values `z` with `f₀ + z·f₁` `e`-close. This is FlashProve's `Code.cnt_close_le`, read as `CAOn`. -/
theorem caOn_third [Finite E] {D : Submodule E (ι → E)} {d e : ℕ} (hd : MinDist D d) (h3 : 3 * e < d) :
    CAOn Unit D e (e + 1) := fun f₀ f₁ h => cnt_close_le hd h3 f₀ f₁ h

/-- **The proximity lemma at δ/3, for any linear code (task 2).** Let the code have minimum distance `d` and
`3e < d`. If the committed rows `U` are `e`-far from the interleaved code, a uniformly random weight vector `ρ` makes
`Σ_i ρ_i·U_i` `e`-close to the code with probability at most `(e + 1)/|E|`. With `|E| = |F_p²|` this is the count's
δ/3 field term without its carried ceiling: `(⌊δN/3⌋ + 1)/p²` (`count.py`, `regular`, `"delta/3"`). -/
theorem proximity_third [Fintype E] [DecidableEq κ] {D : Submodule E (ι → E)} {d e : ℕ}
    (hd : MinDist D d) (h3 : 3 * e < d) (U : κ → ι → E) (hfar : ¬ Close D e U) :
    (PMF.uniformOfFintype (κ → E)).toOuterMeasure {r | Close D e (fun _ : Unit => comb U r)}
      ≤ ((e + 1 : ℕ) : ℝ≥0∞) / Fintype.card E :=
  comb_close_prob hd (by omega) le_rfl (caOn_third hd h3) U hfar

/-! ## Affine combinations (the mask commitment `M`)

`zk::mask_verify_tagged` combines the rows as `u + Σ_i r_i·row_i`: the proximity mask rows `u` (as one `F_p²` row
`u_re + i·u_im`) carry the fixed coefficient 1 and only the other rows get uniform weights (`zk.rs:594-600`). The
bound for that form follows from the linear one by homogenizing: the weights `(c, c·r)`, `c ≠ 0`, of the table
`(u, U)` give `c·(u + Σ r_i U_i)`, which is close exactly when `u + Σ r_i U_i` is. This costs a factor
`|E| / (|E| − 1)`. -/

/-- The table `(u, U)`: the row `u` first (index `none`), then the rows of `U`. -/
def withFirst (u : ι → E) (U : κ → ι → E) : Option κ → ι → E := fun o => o.elim u U

omit [Fintype ι] in
/-- The weights `(c, c·r)` on the table `(u, U)` give `c·(u + Σ_i r_i·U_i)`. -/
theorem comb_withFirst (u : ι → E) (U : κ → ι → E) (c : E) (r : κ → E) :
    comb (withFirst u U) (fun o => o.elim c (c • r)) = c • (u + comb U r) := by
  simp only [comb, withFirst, Fintype.sum_option, Option.elim, Pi.smul_apply, smul_eq_mul, mul_smul, smul_add,
    smul_sum]

/-- A multiple of a close word is close. -/
theorem close_smul {D : Submodule E (ι → E)} {e : ℕ} {w : ι → E} (c : E)
    (h : Close D e (fun _ : Unit => w)) : Close D e (fun _ : Unit => c • w) := by
  obtain ⟨S, hS, hw⟩ := h
  exact ⟨S, hS, fun x => (agreeOn D S).smul_mem c (hw x)⟩

/-- **Affine combinations, counted.** Under the hypotheses of `comb_close_cnt_mul`, if the table `(u, U)` is not
`e`-close, then `(number of weights r with u + Σ r_i U_i e-close)·(|E| − 1) ≤ A·|E|^m`. -/
theorem affine_close_cnt_mul [Fintype E] [DecidableEq κ] {D : Submodule E (ι → E)} {d e A : ℕ}
    (hd : MinDist D d) (h2 : 2 * e < d) (hA : e + 1 ≤ A) (hca : CAOn Unit D e A)
    (u : ι → E) (U : κ → ι → E) (hfar : ¬ Close D e (withFirst u U)) :
    cnt (fun r : κ → E => Close D e (fun _ : Unit => u + comb U r)) * (Fintype.card E - 1)
      ≤ A * Fintype.card (κ → E) := by
  classical
  have hlin := comb_close_cnt_mul hd h2 hA hca (withFirst u U) hfar
  let Φ : {c : E // c ≠ 0} × {r : κ → E // Close D e (fun _ : Unit => u + comb U r)} →
      {r' : Option κ → E // Close D e (fun _ : Unit => comb (withFirst u U) r')} :=
    fun p => ⟨fun o => o.elim p.1.1 (p.1.1 • p.2.1), by rw [comb_withFirst]; exact close_smul _ p.2.2⟩
  have hΦ : Function.Injective Φ := by
    rintro ⟨⟨c, hc⟩, ⟨r, hr⟩⟩ ⟨⟨c', hc'⟩, ⟨r', hr'⟩⟩ h
    have h1 : (fun o : Option κ => o.elim c (c • r)) = fun o => o.elim c' (c' • r') :=
      congrArg Subtype.val h
    have hcc : c = c' := congrFun h1 none
    subst hcc
    have hrr : r = r' := by
      funext i
      have h3 := congrFun h1 (some i)
      simp only [Option.elim, Pi.smul_apply, smul_eq_mul] at h3
      exact mul_left_cancel₀ hc h3
    subst hrr
    rfl
  have hcard := Nat.card_le_card_of_injective Φ hΦ
  rw [Nat.card_prod] at hcard
  have hne : cnt (fun c : E => c ≠ 0) = Fintype.card E - 1 := by
    have h0 := cnt_add_cnt_not (fun c : E => c = 0)
    rw [cnt_eq_const] at h0
    have h4 : cnt (fun c : E => c ≠ 0) = cnt (fun c : E => ¬ c = 0) := rfl
    omega
  have hq : 0 < Fintype.card E := Fintype.card_pos
  have hsize : Fintype.card (Option κ → E) = Fintype.card (κ → E) * Fintype.card E := by
    rw [Fintype.card_fun, Fintype.card_fun, Fintype.card_option, pow_succ]
  -- `cnt (≠ 0) · cnt (affine close) ≤ cnt (linear close)`, then scale by `|E|`
  have hkey : cnt (fun c : E => c ≠ 0) * cnt (fun r : κ → E => Close D e (fun _ : Unit => u + comb U r))
      ≤ cnt (fun r' : Option κ → E => Close D e (fun _ : Unit => comb (withFirst u U) r')) := hcard
  rw [hne] at hkey
  refine Nat.le_of_mul_le_mul_right ?_ hq
  calc cnt (fun r : κ → E => Close D e (fun _ : Unit => u + comb U r)) * (Fintype.card E - 1)
        * Fintype.card E
      = (Fintype.card E - 1) * cnt (fun r : κ → E => Close D e (fun _ : Unit => u + comb U r))
        * Fintype.card E := by ring
    _ ≤ cnt (fun r' : Option κ → E => Close D e (fun _ : Unit => comb (withFirst u U) r'))
        * Fintype.card E := Nat.mul_le_mul_right _ hkey
    _ ≤ A * Fintype.card (Option κ → E) := hlin
    _ = A * Fintype.card (κ → E) * Fintype.card E := by rw [hsize, mul_assoc]

/-- **Affine combinations (the mask commitment's proximity form).** Under the hypotheses of `comb_close_prob`, if
the table `(u, U)` is `e`-far, uniform weights `r` make `u + Σ_i r_i·U_i` `e`-close with probability at most
`A/(|E| − 1)`. -/
theorem affine_close_prob [Fintype E] [DecidableEq κ] {D : Submodule E (ι → E)} {d e A : ℕ}
    (hd : MinDist D d) (h2 : 2 * e < d) (hA : e + 1 ≤ A) (hca : CAOn Unit D e A)
    (u : ι → E) (U : κ → ι → E) (hfar : ¬ Close D e (withFirst u U)) :
    (PMF.uniformOfFintype (κ → E)).toOuterMeasure {r | Close D e (fun _ : Unit => u + comb U r)}
      ≤ (A : ℝ≥0∞) / (Fintype.card E - 1 : ℕ) := by
  classical
  have hq : Fintype.card E - 1 ≠ 0 := by
    have := Fintype.one_lt_card (α := E)
    omega
  refine prob_le_of_card_mul (fun r : κ → E => Close D e (fun _ : Unit => u + comb U r)) A
    (Fintype.card E - 1) hq ?_
  rw [← cnt_eq_card_filter]
  exact affine_close_cnt_mul hd h2 hA hca u U hfar

/-- **The mask commitment's proximity test at δ/3.** For any linear code of minimum distance `d` with `3e < d`, if
the table `(u, U)` is `e`-far, `u + Σ_i r_i·U_i` is `e`-close with probability at most `(e + 1)/(|E| − 1)`. For `M`
(`RS(1024, 4096)`, `e = 1024`) that is `1025/(p² − 1)`, inside the count's `(2·512 + 1 + 4096)/p²`. -/
theorem affine_proximity_third [Fintype E] [DecidableEq κ] {D : Submodule E (ι → E)} {d e : ℕ}
    (hd : MinDist D d) (h3 : 3 * e < d) (u : ι → E) (U : κ → ι → E) (hfar : ¬ Close D e (withFirst u U)) :
    (PMF.uniformOfFintype (κ → E)).toOuterMeasure {r | Close D e (fun _ : Unit => u + comb U r)}
      ≤ ((e + 1 : ℕ) : ℝ≥0∞) / (Fintype.card E - 1 : ℕ) :=
  affine_close_prob hd (by omega) le_rfl (caOn_third hd h3) u U hfar

end ZK60.Sound
