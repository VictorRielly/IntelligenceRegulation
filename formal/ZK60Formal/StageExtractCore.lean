/-
D63, Lean lane L12 (2026-11-07): the token stages' knowledge-soundness parts (ASSEMBLY §4.2 item e), the GENERIC
core shared by the stage files `StageInExtract.lean` (IN / IN-C) and `StageOutCExtract.lean` (OUT-C).

Every stage slot of `token_io` (`run_stage_slot`, token_io.rs:997-1135) is one of three kinds:
* a STANDALONE zero-check: the sumcheck of `eq(τ, x)·Σ_j μ_j·W_j(x)` on the claim `0`, the `W_j` the slot's clauses
  (a polynomial in the committed tables' multilinear extensions), `μ` fresh nonzero batching coefficients
  (`nonzero(tr.challenge_fp2_vec(k))`, token_io.rs:934-939), and possibly a PAD clause `(1 − supp)·Σ_i ζ^i·P_i` with
  its own fresh `ζ` (`zeta_fold`, token_io.rs:1249-1257);
* a PRIVATE slot: a plain sumcheck of `Σ_x priv(x)` on the prover's published scalar `S`;
* a HOST slot: the zero-check of its own clauses plus `ν·host(x)`, on the claim `ν·S` of the private slot it hosts
  (`claimed = scalar + Σ coef·scalars[hs]`, token_io.rs:1070, the masks cancelling as `sumcheck_sound_masked` shows).

What is proved here, for tables fixed before the slot's challenges (the committed `A`, `H`, `B` planes) and ANY prover
strategy (a function of the challenges drawn before each message), over uniform independent challenges in a finite
field `K` (the code's `Fp2`):
* `pr_mono`, `pr_or_le`, `pr_exists_le`, `pr_prod_le`, `pr_prod_le_right`, `pr_fst_le`, `pr_snd_le`: the uniform
  probability `pr` and its union bound and slicing over product spaces (a bound at every value of one coordinate is a
  bound on the product);
* **`two_phase_sound`**: challenges, then the prover's data (the helpers `H`), then the slots: the two errors add,
  whatever data the prover picks;
* `IndDegLE.wsum`, `IndDegLE.mono`: the batched clause keeps the individual degree;
* `mleAt_sub`, `mle_eq_prob`: two different cube tables have equal extensions at a uniform point with probability at
  most `n/|K|` (stage IN's compressed row, stage OUT's head identity);
* `zetaFold_prob`: a pad fold `Σ_{i<m} ζ^i·P_i` with some `P_i ≠ 0` vanishes everywhere for at most `m − 1` values of
  `ζ`;
* `single_root_prob`: `a + ν·δ = 0` with `δ ≠ 0` for at most one `ν`;
* **`zc_batched_sound`**: if some clause `W_j` is nonzero somewhere on the cube, the batched zero-check accepts with
  probability at most `(1 + n + n·(d + 1))/|K|` (`batch_prob` for `μ`, `zerocheck_sound` for `τ` and the rounds);
* **`zc_pad_sound`**: the same with a pad clause folded by `ζ`: if a clause or a pad plane is nonzero somewhere, at
  most `(m − 1 + 1 + n + n·(d + 1))/|K|`, `m` the pad planes;
* **`host_sound`**: a host slot on the claim `ν·S`: if a clause is nonzero somewhere OR the hosted sum `Σ_x host(x)` is
  not `S`, the host accepts with probability at most `(2 + n + n·(d + 1))/|K|` — the hosting rule `Σ host = S` is
  what the host certifies, and the private slot's own sumcheck (`sumcheck_sound`) certifies `S = Σ priv`;
* **`host_pad_sound`**: a host slot with a pad clause (TZC, VZC): `((m − 1) + (2 + n + n·(d + 1)))/|K|`;
* `cube_sum_of_pad`: a cube sum whose terms vanish off the logical positions is the sum over the logical positions
  (how the pad clauses turn the code's whole-cube LogUp sum claim into the logical one).

Modelling boundary, as in `SoundZeroCheck.lean` / `SoundLogUpBlock.lean`: the terminal values are the true tables'
values at the challenge point (the openings' part, lane L10), the CFS mask and the extension round are
`sumcheck_sound_masked` / `sumcheck_sound_extended` (they leave the round bound, or add one round), and Fiat–Shamir is
the generic L7 / L8 composition. Every statement is for a general finite field `K`: no literal prime is evaluated.
-/
import ZK60Formal.SoundLogUpBlock
import ZK60Formal.SoundMultilinear

namespace ZK60.StageX

open scoped ENNReal
open Polynomial Finset ZK60.Sound

/-! ## The uniform probability and its union bound -/

/-- The uniform probability of an event on a finite space (`PMF.uniformOfFintype`, `toOuterMeasure`, as in
`Statements.lean`). -/
noncomputable def pr {Ω : Type} [Fintype Ω] [Nonempty Ω] (E : Ω → Prop) : ℝ≥0∞ :=
  (PMF.uniformOfFintype Ω).toOuterMeasure {ω | E ω}

section Prob

variable {Ω : Type} [Fintype Ω] [Nonempty Ω]

theorem pr_mono {E E' : Ω → Prop} (h : ∀ ω, E ω → E' ω) : pr E ≤ pr E' := by
  unfold pr
  exact MeasureTheory.measure_mono (fun ω hω => h ω hω)

theorem pr_or_le (E E' : Ω → Prop) : pr (fun ω => E ω ∨ E' ω) ≤ pr E + pr E' := by
  unfold pr
  have hs : {ω | E ω ∨ E' ω} = {ω | E ω} ∪ {ω | E' ω} := rfl
  rw [hs]
  exact MeasureTheory.measure_union_le _ _

theorem pr_exists_le {ι : Type} [Fintype ι] (E : ι → Ω → Prop) :
    pr (fun ω => ∃ i, E i ω) ≤ ∑ i, pr (E i) := by
  unfold pr
  have hs : {ω | ∃ i, E i ω} = ⋃ i, {ω | E i ω} := by
    ext ω
    simp
  rw [hs]
  exact MeasureTheory.measure_iUnion_fintype_le _ _

theorem pr_false : pr (fun _ : Ω => False) = 0 := by
  unfold pr
  simp

theorem pr_le_of_not (E : Ω → Prop) (h : ∀ ω, ¬ E ω) (ε : ℝ≥0∞) : pr E ≤ ε := by
  have : pr E ≤ pr (fun _ : Ω => False) := pr_mono (fun ω hω => h ω hω)
  rw [pr_false] at this
  exact this.trans (by simp)

end Prob

section Product

variable {α β : Type} [Fintype α] [Nonempty α] [Fintype β] [Nonempty β]

/-- **A bound on every slice of the second coordinate is a bound on the product**: if, for every `a`, the event has
probability at most `ε` over `b`, it has probability at most `ε` over `(a, b)`. -/
theorem pr_prod_le (E : α × β → Prop) {ε : ℝ≥0∞} (h : ∀ a, pr (fun b : β => E (a, b)) ≤ ε) : pr E ≤ ε := by
  classical
  unfold pr at h ⊢
  rw [PMF.toOuterMeasure_apply_fintype, Fintype.sum_prod_type]
  have hc : ∀ a : α, ∑ b : β, {p : α × β | E p}.indicator (PMF.uniformOfFintype (α × β)) (a, b) =
      (Fintype.card α : ℝ≥0∞)⁻¹ * (PMF.uniformOfFintype β).toOuterMeasure {b | E (a, b)} := by
    intro a
    rw [PMF.toOuterMeasure_apply_fintype, Finset.mul_sum]
    refine Finset.sum_congr rfl (fun b _ => ?_)
    by_cases hE : E (a, b)
    · have h1 : (a, b) ∈ {p : α × β | E p} := hE
      have h2 : b ∈ {b : β | E (a, b)} := hE
      rw [Set.indicator_of_mem h1, Set.indicator_of_mem h2, PMF.uniformOfFintype_apply,
        PMF.uniformOfFintype_apply, Fintype.card_prod, Nat.cast_mul,
        ENNReal.mul_inv (Or.inr (ENNReal.natCast_ne_top _)) (Or.inl (ENNReal.natCast_ne_top _))]
    · have h1 : (a, b) ∉ {p : α × β | E p} := hE
      have h2 : b ∉ {b : β | E (a, b)} := hE
      rw [Set.indicator_of_notMem h1, Set.indicator_of_notMem h2, mul_zero]
  simp only [hc]
  calc ∑ a : α, (Fintype.card α : ℝ≥0∞)⁻¹ * (PMF.uniformOfFintype β).toOuterMeasure {b | E (a, b)}
      ≤ ∑ _a : α, (Fintype.card α : ℝ≥0∞)⁻¹ * ε :=
        Finset.sum_le_sum (fun a _ => by gcongr; exact h a)
    _ = ε := by
        rw [Finset.sum_const, Finset.card_univ, nsmul_eq_mul, ← mul_assoc,
          ENNReal.mul_inv_cancel (by simp) (ENNReal.natCast_ne_top _), one_mul]

/-- The same with the slices of the FIRST coordinate. -/
theorem pr_prod_le_right (E : α × β → Prop) {ε : ℝ≥0∞} (h : ∀ b, pr (fun a : α => E (a, b)) ≤ ε) :
    pr E ≤ ε := by
  classical
  unfold pr at h ⊢
  rw [PMF.toOuterMeasure_apply_fintype, Fintype.sum_prod_type_right]
  have hc : ∀ b : β, ∑ a : α, {p : α × β | E p}.indicator (PMF.uniformOfFintype (α × β)) (a, b) =
      (Fintype.card β : ℝ≥0∞)⁻¹ * (PMF.uniformOfFintype α).toOuterMeasure {a | E (a, b)} := by
    intro b
    rw [PMF.toOuterMeasure_apply_fintype, Finset.mul_sum]
    refine Finset.sum_congr rfl (fun a _ => ?_)
    by_cases hE : E (a, b)
    · have h1 : (a, b) ∈ {p : α × β | E p} := hE
      have h2 : a ∈ {a : α | E (a, b)} := hE
      rw [Set.indicator_of_mem h1, Set.indicator_of_mem h2, PMF.uniformOfFintype_apply,
        PMF.uniformOfFintype_apply, Fintype.card_prod, Nat.cast_mul,
        ENNReal.mul_inv (Or.inr (ENNReal.natCast_ne_top _)) (Or.inl (ENNReal.natCast_ne_top _)), mul_comm]
    · have h1 : (a, b) ∉ {p : α × β | E p} := hE
      have h2 : a ∉ {a : α | E (a, b)} := hE
      rw [Set.indicator_of_notMem h1, Set.indicator_of_notMem h2, mul_zero]
  simp only [hc]
  calc ∑ b : β, (Fintype.card β : ℝ≥0∞)⁻¹ * (PMF.uniformOfFintype α).toOuterMeasure {a | E (a, b)}
      ≤ ∑ _b : β, (Fintype.card β : ℝ≥0∞)⁻¹ * ε :=
        Finset.sum_le_sum (fun b _ => by gcongr; exact h b)
    _ = ε := by
        rw [Finset.sum_const, Finset.card_univ, nsmul_eq_mul, ← mul_assoc,
          ENNReal.mul_inv_cancel (by simp) (ENNReal.natCast_ne_top _), one_mul]

/-- An event of the first coordinate alone has its own probability on the product. -/
theorem pr_fst_le (E : α → Prop) : pr (fun p : α × β => E p.1) ≤ pr E :=
  pr_prod_le_right _ (fun _ => le_rfl)

/-- An event of the second coordinate alone has its own probability on the product. -/
theorem pr_snd_le (E : β → Prop) : pr (fun p : α × β => E p.2) ≤ pr E :=
  pr_prod_le _ (fun _ => le_rfl)

/-- **Two phases: the challenges before the prover's data, then the slots.** Phase 1 draws `ω₁` (here: the stage's
`β, γ, α, r_emb` or `γ, α`), the prover then chooses its data `h ω₁` (the helpers `H`), phase 2 draws `ω₂` (every
slot's challenges) and the verifier accepts or not. If (1) data satisfying the phase-1 relations `Pre` exist while the
goal fails with probability at most `ε₁` over `ω₁`, and (2) for EVERY `ω₁` and EVERY data violating `Pre` the slots
accept with probability at most `ε₂` over `ω₂`, then acceptance with the goal failing has probability at most
`ε₁ + ε₂`, whatever data function `h` the prover uses. -/
theorem two_phase_sound {Hd : Type} (Pre : α → Hd → Prop) (Good : Prop) (acc : α → Hd → β → Prop) (h : α → Hd)
    {ε₁ ε₂ : ℝ≥0∞} (h₁ : pr (fun a => (∃ hd, Pre a hd) ∧ ¬ Good) ≤ ε₁)
    (h₂ : ∀ a hd, ¬ Pre a hd → pr (fun b => acc a hd b) ≤ ε₂) :
    pr (fun ω : α × β => acc ω.1 (h ω.1) ω.2 ∧ ¬ Good) ≤ ε₁ + ε₂ := by
  have hsub : ∀ ω : α × β, acc ω.1 (h ω.1) ω.2 ∧ ¬ Good →
      ((∃ hd, Pre ω.1 hd) ∧ ¬ Good) ∨ (¬ Pre ω.1 (h ω.1) ∧ acc ω.1 (h ω.1) ω.2) := by
    rintro ω ⟨hacc, hg⟩
    by_cases hp : Pre ω.1 (h ω.1)
    · exact Or.inl ⟨⟨h ω.1, hp⟩, hg⟩
    · exact Or.inr ⟨hp, hacc⟩
  refine (pr_mono hsub).trans ((pr_or_le _ _).trans (add_le_add ((pr_fst_le _).trans h₁) ?_))
  refine pr_prod_le _ (fun a => ?_)
  by_cases hp : Pre a (h a)
  · exact pr_le_of_not _ (fun b hb => hb.1 hp) _
  · exact (pr_mono (E' := fun b => acc a (h a) b) (fun b hb => hb.2)).trans (h₂ a (h a) hp)

end Product

/-! ## Degrees -/

section Deg

variable {K : Type} [Field K]

/-- A batched sum of clauses keeps the clauses' individual degree. -/
theorem IndDegLE.wsum {ι : Type} [Fintype ι] {n d : ℕ} {W : ι → (Fin n → K) → K} (hW : ∀ j, IndDegLE d (W j))
    (μ : ι → K) : IndDegLE d (fun x => ∑ j, μ j * W j x) := by
  intro i x
  choose p hp hpe using fun j => hW j i x
  refine ⟨∑ j, C (μ j) * p j,
    natDegree_sum_le_of_forall_le _ _ (fun j _ => (natDegree_C_mul_le _ _).trans (hp j)), fun t => ?_⟩
  simp only [eval_finsetSum, eval_mul, eval_C, hpe]

theorem IndDegLE.mono {n d d' : ℕ} {f : (Fin n → K) → K} (h : IndDegLE d f) (hd : d ≤ d') : IndDegLE d' f := by
  intro i x
  obtain ⟨p, hp, hpe⟩ := h i x
  exact ⟨p, hp.trans hd, hpe⟩

theorem IndDegLE.add {n d : ℕ} {f g : (Fin n → K) → K} (hf : IndDegLE d f) (hg : IndDegLE d g) :
    IndDegLE d (fun x => f x + g x) := by
  have h := hf.add_smul hg 1
  simpa using h

end Deg

/-! ## One-challenge steps -/

section OneChallenge

variable {K : Type} [Field K]

/-- **The pad fold.** If some pad plane `P_i` is nonzero somewhere, `Σ_{i<m} ζ^i·P_i` vanishes EVERYWHERE for at most
`m − 1` values of `ζ` (at the point where `P_i ≠ 0` it is a nonzero polynomial of degree `≤ m − 1` in `ζ`). The code's
pads: `(1 − supp)·(tok + ζ·h)` (`m = 2`, stage IN / IN-C, the table pads) and DZC's twelve planes (`m = 12`). -/
theorem zetaFold_prob [Fintype K] {β : Type} {m : ℕ} (P : Fin m → β → K) (h : ∃ i b, P i b ≠ 0) :
    pr (fun ζ : K => ∀ b, ∑ i : Fin m, ζ ^ (i : ℕ) * P i b = 0) ≤ ((m - 1 : ℕ) : ℝ≥0∞) / Fintype.card K := by
  classical
  obtain ⟨i₀, b₀, hb₀⟩ := h
  set q : K[X] := ∑ i : Fin m, C (P i b₀) * X ^ (i : ℕ) with hq
  have hcoeff : q.coeff i₀ = P i₀ b₀ := by
    rw [hq, finsetSum_coeff]
    simp only [coeff_C_mul_X_pow]
    rw [Finset.sum_eq_single i₀]
    · simp
    · intro j _ hj
      rw [ite_eq_right_iff]
      intro h'
      exact absurd (Fin.ext h'.symm) hj
    · intro h'
      exact absurd (Finset.mem_univ i₀) h'
  have hq0 : q ≠ 0 := by
    intro h0
    rw [h0, coeff_zero] at hcoeff
    exact hb₀ hcoeff.symm
  have hdeg : q.natDegree ≤ m - 1 := by
    rw [hq]
    refine natDegree_sum_le_of_forall_le _ _ (fun i _ => (natDegree_C_mul_X_pow_le _ _).trans ?_)
    have := i.isLt
    omega
  refine (pr_mono (E' := fun ζ => q.eval ζ = 0) (fun ζ hζ => ?_)).trans (schwartzZippel hq0 hdeg)
  have h0 := hζ b₀
  calc q.eval ζ = ∑ i : Fin m, ζ ^ (i : ℕ) * P i b₀ := by
        rw [hq, eval_finsetSum]
        simp only [eval_mul, eval_C, eval_pow, eval_X]
        exact Finset.sum_congr rfl (fun i _ => mul_comm _ _)
    _ = 0 := h0

/-- `mleAt` is linear: the extension of a difference is the difference of the extensions. -/
theorem mleAt_sub {n : ℕ} (P Q : (Fin n → Bool) → K) (r : Fin n → K) :
    mleAt (fun b => P b - Q b) r = mleAt P r - mleAt Q r := by
  simp only [mleAt, mul_sub, Finset.sum_sub_distrib]

/-- **Schwartz–Zippel for two cube tables.** Two different tables on `{0,1}^n` have equal multilinear extensions at a
uniform point with probability at most `n/|K|` (`mle_zero_prob` on the difference). The compressed embedding row of
stage IN (over `r_emb`) and stage OUT's head identity (over `r_j`) are this step. -/
theorem mle_eq_prob [Fintype K] {n : ℕ} (P Q : (Fin n → Bool) → K) (h : P ≠ Q) :
    pr (fun r : Fin n → K => mleAt P r = mleAt Q r) ≤ (n : ℝ≥0∞) / Fintype.card K := by
  obtain ⟨b, hb⟩ : ∃ b, P b ≠ Q b := by
    by_contra hc
    push Not at hc
    exact h (funext hc)
  have hnz : ∃ b, (fun b => P b - Q b) b ≠ 0 := ⟨b, sub_ne_zero.mpr hb⟩
  refine (pr_mono (E' := fun r => mleAt (fun b => P b - Q b) r = 0) (fun r hr => ?_)).trans
    (mle_zero_prob _ hnz)
  rw [mleAt_sub, hr, sub_self]

/-- `a + ν·δ = 0` with `δ ≠ 0` holds for exactly one `ν`: probability at most `1/|K|`. (The host slot's `ν`
separates a false hosted sum from the zero-check part.) -/
theorem single_root_prob [Fintype K] [DecidableEq K] (a δ : K) (hδ : δ ≠ 0) :
    pr (fun ν : K => a + ν * δ = 0) ≤ (1 : ℝ≥0∞) / Fintype.card K := by
  have hc : (Finset.univ.filter (fun ν : K => a + ν * δ = 0)).card ≤ 1 := by
    refine Finset.card_le_one.mpr (fun x hx y hy => ?_)
    simp only [Finset.mem_filter, Finset.mem_univ, true_and] at hx hy
    have : (x - y) * δ = 0 := by linear_combination hx - hy
    exact sub_eq_zero.mp ((mul_eq_zero.mp this).resolve_right hδ)
  have := prob_le_of_card_filter (fun ν : K => a + ν * δ = 0) 1 hc
  rw [Nat.cast_one] at this
  exact this

end OneChallenge

/-! ## The batched zero-check, the pad fold and the host slot -/

section Slots

variable {K : Type} [Field K] {ι : Type}

/-- The batched clause `Σ_j μ_j·W_j` of a slot. -/
def batched [Fintype ι] {n : ℕ} (W : ι → (Fin n → K) → K) (μ : ι → K) (x : Fin n → K) : K := ∑ j, μ j * W j x

/-- A Boolean point of the cube as a field point. -/
def bitv {n : ℕ} (b : Fin n → Bool) : Fin n → K := fun i => bit (b i)

/-- **The batched zero-check (a standalone slot).** Let the clauses `W_j` (individual degree `≤ d`, fixed before the
slot's challenges) be nonzero at some point of the cube. Over uniform `μ` (the batching), `τ` (the zero-check point)
and the round challenges `ρ`, and for ANY prover (its messages may depend on `μ` and `τ`), the sumcheck of
`eq(τ, x)·Σ_j μ_j·W_j(x)` on the claim `0` accepts with probability at most `(1 + n + n·(d + 1))/|K|`. -/
theorem zc_batched_sound [Fintype K] [DecidableEq K] [Fintype ι] [DecidableEq ι] {n d : ℕ} (hd : d + 1 < ringChar K) (W : ι → (Fin n → K) → K)
    (hW : ∀ j, IndDegLE d (W j)) (hnz : ∃ j, ∃ b : Fin n → Bool, W j (bitv b) ≠ 0)
    (P : (ι → K) → (Fin n → K) → Prover K (d + 1) n) :
    pr (fun ω : (ι → K) × ((Fin n → K) × (Fin n → K)) =>
        Accepts n (fun x => eqPoly ω.2.1 x * batched W ω.1 x) 0 (P ω.1 ω.2.1) ω.2.2)
      ≤ ((1 + (n + n * (d + 1)) : ℕ) : ℝ≥0∞) / Fintype.card K := by
  obtain ⟨j₀, b₀, hb₀⟩ := hnz
  have hsub : ∀ ω : (ι → K) × ((Fin n → K) × (Fin n → K)),
      Accepts n (fun x => eqPoly ω.2.1 x * batched W ω.1 x) 0 (P ω.1 ω.2.1) ω.2.2 →
      (batched W ω.1 (bitv b₀) = 0) ∨
        (batched W ω.1 (bitv b₀) ≠ 0 ∧
          Accepts n (fun x => eqPoly ω.2.1 x * batched W ω.1 x) 0 (P ω.1 ω.2.1) ω.2.2) := by
    intro ω h
    by_cases hz : batched W ω.1 (bitv b₀) = 0
    · exact Or.inl hz
    · exact Or.inr ⟨hz, h⟩
  refine (pr_mono hsub).trans ((pr_or_le _ _).trans ?_)
  have h1 : pr (fun ω : (ι → K) × ((Fin n → K) × (Fin n → K)) => batched W ω.1 (bitv b₀) = 0)
      ≤ (1 : ℝ≥0∞) / Fintype.card K :=
    (pr_fst_le (fun μ : ι → K => batched W μ (bitv b₀) = 0)).trans
      (batch_prob (fun j => W j (bitv b₀)) ⟨j₀, hb₀⟩)
  have h2 : pr (fun ω : (ι → K) × ((Fin n → K) × (Fin n → K)) => batched W ω.1 (bitv b₀) ≠ 0 ∧
        Accepts n (fun x => eqPoly ω.2.1 x * batched W ω.1 x) 0 (P ω.1 ω.2.1) ω.2.2)
      ≤ ((n + n * (d + 1) : ℕ) : ℝ≥0∞) / Fintype.card K := by
    refine pr_prod_le _ (fun μ => ?_)
    by_cases hz : batched W μ (bitv b₀) = 0
    · exact pr_le_of_not _ (fun ω hω => hω.1 hz) _
    · refine (pr_mono (E' := fun ω : (Fin n → K) × (Fin n → K) =>
          Accepts n (fun x => eqPoly ω.1 x * batched W μ x) 0 (P μ ω.1) ω.2) (fun ω hω => hω.2)).trans ?_
      exact zerocheck_sound hd (IndDegLE.wsum hW μ) ⟨b₀, hz⟩ (P μ)
  calc pr (fun ω : (ι → K) × ((Fin n → K) × (Fin n → K)) => batched W ω.1 (bitv b₀) = 0)
        + pr (fun ω : (ι → K) × ((Fin n → K) × (Fin n → K)) => batched W ω.1 (bitv b₀) ≠ 0 ∧
          Accepts n (fun x => eqPoly ω.2.1 x * batched W ω.1 x) 0 (P ω.1 ω.2.1) ω.2.2)
      ≤ (1 : ℝ≥0∞) / Fintype.card K + ((n + n * (d + 1) : ℕ) : ℝ≥0∞) / Fintype.card K := add_le_add h1 h2
    _ = ((1 + (n + n * (d + 1)) : ℕ) : ℝ≥0∞) / Fintype.card K := by
        rw [ENNReal.div_add_div_same]
        norm_cast

/-- The slot's clauses with the pad clause appended: `W_j` for `j : ι`, then `Σ_i ζ^i·P_i` (the code's
`μ_last·(1 − supp)·zeta_fold(planes, ζ)`; the support factor is part of the planes `P_i`). -/
def withPad {n m : ℕ} (W : ι → (Fin n → K) → K) (Pz : Fin m → (Fin n → K) → K) (ζ : K) :
    Option ι → (Fin n → K) → K
  | none => fun x => ∑ i : Fin m, ζ ^ (i : ℕ) * Pz i x
  | some j => W j

theorem withPad_none {n m : ℕ} (W : ι → (Fin n → K) → K) (Pz : Fin m → (Fin n → K) → K) (ζ : K) :
    withPad W Pz ζ none = fun x => ∑ i : Fin m, ζ ^ (i : ℕ) * Pz i x := rfl

theorem withPad_some {n m : ℕ} (W : ι → (Fin n → K) → K) (Pz : Fin m → (Fin n → K) → K) (ζ : K) (j : ι) :
    withPad W Pz ζ (some j) = W j := rfl

theorem withPad_deg {n m d : ℕ} {W : ι → (Fin n → K) → K} {Pz : Fin m → (Fin n → K) → K}
    (hW : ∀ j, IndDegLE d (W j)) (hP : ∀ i, IndDegLE d (Pz i)) (ζ : K) :
    ∀ j, IndDegLE d (withPad W Pz ζ j)
  | none => by rw [withPad_none]; exact IndDegLE.wsum hP (fun i => ζ ^ (i : ℕ))
  | some j => by rw [withPad_some]; exact hW j

/-- **The batched zero-check with a pad clause.** If some clause `W_j`, or some pad plane `P_i`, is nonzero at some
point of the cube, then over uniform `ζ` (the pad fold), `μ` (the batching, one coefficient per clause and one for the
pad), `τ` and the rounds, the slot accepts with probability at most `((m − 1) + (1 + n + n·(d + 1)))/|K|`. -/
theorem zc_pad_sound [Fintype K] [DecidableEq K] [Fintype ι] [DecidableEq ι] {n d m : ℕ} (hd : d + 1 < ringChar K) (W : ι → (Fin n → K) → K)
    (Pz : Fin m → (Fin n → K) → K) (hW : ∀ j, IndDegLE d (W j)) (hP : ∀ i, IndDegLE d (Pz i))
    (hnz : (∃ j, ∃ b : Fin n → Bool, W j (bitv b) ≠ 0) ∨ (∃ i, ∃ b : Fin n → Bool, Pz i (bitv b) ≠ 0))
    (P : K → (Option ι → K) → (Fin n → K) → Prover K (d + 1) n) :
    pr (fun ω : K × ((Option ι → K) × ((Fin n → K) × (Fin n → K))) =>
        Accepts n (fun x => eqPoly ω.2.2.1 x * batched (withPad W Pz ω.1) ω.2.1 x) 0 (P ω.1 ω.2.1 ω.2.2.1)
          ω.2.2.2)
      ≤ (((m - 1) + (1 + (n + n * (d + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K := by
  classical
  -- the bad pad challenges: every clause vanishes on the cube and the fold vanishes everywhere
  let Z : K → Prop := fun ζ => ∀ j, ∀ b : Fin n → Bool, withPad W Pz ζ j (bitv b) = 0
  have hsub : ∀ ω : K × ((Option ι → K) × ((Fin n → K) × (Fin n → K))),
      Accepts n (fun x => eqPoly ω.2.2.1 x * batched (withPad W Pz ω.1) ω.2.1 x) 0 (P ω.1 ω.2.1 ω.2.2.1)
        ω.2.2.2 →
      Z ω.1 ∨ (¬ Z ω.1 ∧ Accepts n (fun x => eqPoly ω.2.2.1 x * batched (withPad W Pz ω.1) ω.2.1 x) 0
        (P ω.1 ω.2.1 ω.2.2.1) ω.2.2.2) := by
    intro ω h
    by_cases hz : Z ω.1
    · exact Or.inl hz
    · exact Or.inr ⟨hz, h⟩
  refine (pr_mono hsub).trans ((pr_or_le _ _).trans ?_)
  have h1 : pr (fun ω : K × ((Option ι → K) × ((Fin n → K) × (Fin n → K))) => Z ω.1)
      ≤ ((m - 1 : ℕ) : ℝ≥0∞) / Fintype.card K := by
    refine (pr_fst_le Z).trans ?_
    rcases hnz with ⟨j, b, hb⟩ | ⟨i, b, hb⟩
    · exact pr_le_of_not _ (fun ζ hζ => hb (by have h' := hζ (some j) b; rwa [withPad_some] at h')) _
    · refine (pr_mono (E' := fun ζ : K => ∀ b' : Fin n → Bool,
          ∑ i' : Fin m, ζ ^ (i' : ℕ) * Pz i' (bitv b') = 0) (fun ζ hζ b' => by have h' := hζ none b'; rwa [withPad_none] at h')).trans ?_
      exact zetaFold_prob (fun i' (b' : Fin n → Bool) => Pz i' (bitv b')) ⟨i, b, hb⟩
  have h2 : pr (fun ω : K × ((Option ι → K) × ((Fin n → K) × (Fin n → K))) => ¬ Z ω.1 ∧
        Accepts n (fun x => eqPoly ω.2.2.1 x * batched (withPad W Pz ω.1) ω.2.1 x) 0 (P ω.1 ω.2.1 ω.2.2.1)
          ω.2.2.2)
      ≤ ((1 + (n + n * (d + 1)) : ℕ) : ℝ≥0∞) / Fintype.card K := by
    refine pr_prod_le _ (fun ζ => ?_)
    by_cases hz : Z ζ
    · exact pr_le_of_not _ (fun ω hω => hω.1 hz) _
    · have hnz' : ∃ j, ∃ b : Fin n → Bool, withPad W Pz ζ j (bitv b) ≠ 0 := by
        by_contra hc
        push Not at hc
        exact hz hc
      refine (pr_mono (E' := fun ω : (Option ι → K) × ((Fin n → K) × (Fin n → K)) =>
          Accepts n (fun x => eqPoly ω.2.1 x * batched (withPad W Pz ζ) ω.1 x) 0 (P ζ ω.1 ω.2.1) ω.2.2)
          (fun ω hω => hω.2)).trans ?_
      exact zc_batched_sound hd (withPad W Pz ζ) (withPad_deg hW hP ζ) hnz' (P ζ)
  calc _ ≤ ((m - 1 : ℕ) : ℝ≥0∞) / Fintype.card K + ((1 + (n + n * (d + 1)) : ℕ) : ℝ≥0∞) / Fintype.card K :=
        add_le_add h1 h2
    _ = (((m - 1) + (1 + (n + n * (d + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K := by
        rw [ENNReal.div_add_div_same, ← Nat.cast_add]

/-- The cube sum of a sum is the sum of the cube sums. -/
theorem cubeSum_add {n : ℕ} (f g : (Fin n → K) → K) :
    cubeSum (fun x => f x + g x) = cubeSum f + cubeSum g := by
  simp only [cubeSum, Finset.sum_add_distrib]

theorem cubeSum_smul {n : ℕ} (c : K) (f : (Fin n → K) → K) : cubeSum (fun x => c * f x) = c * cubeSum f := by
  simp only [cubeSum, Finset.mul_sum]

/-- **The host slot.** Let the host's clauses `W_j` (individual degree `≤ d`) and its host term `Hs` (individual
degree `≤ d + 1`) be fixed before the slot's challenges, and `S` the hosted private slot's published scalar (fixed
before them too). If some clause is nonzero somewhere on the cube, OR the hosted sum `Σ_x Hs(x)` is not `S`, then over
uniform `μ`, `ν`, `τ` and the rounds, for ANY prover, the host's sumcheck of `eq(τ, x)·Σ_j μ_j·W_j(x) + ν·Hs(x)` on the
claim `ν·S` (token_io.rs:1070) accepts with probability at most `(2 + n + n·(d + 1))/|K|`. -/
theorem host_sound [Fintype K] [DecidableEq K] [Fintype ι] [DecidableEq ι] {n d : ℕ} (hd : d + 1 < ringChar K) (W : ι → (Fin n → K) → K) (hW : ∀ j, IndDegLE d (W j))
    (Hs : (Fin n → K) → K) (hHs : IndDegLE (d + 1) Hs) (S : K)
    (hbad : (∃ j, ∃ b : Fin n → Bool, W j (bitv b) ≠ 0) ∨ cubeSum Hs ≠ S)
    (P : ((ι → K) × K) × (Fin n → K) → Prover K (d + 1) n) :
    pr (fun ω : (((ι → K) × K) × (Fin n → K)) × (Fin n → K) =>
        Accepts n (fun x => eqPoly ω.1.2 x * batched W ω.1.1.1 x + ω.1.1.2 * Hs x) (ω.1.1.2 * S) (P ω.1) ω.2)
      ≤ ((2 + (n + n * (d + 1)) : ℕ) : ℝ≥0∞) / Fintype.card K := by
  classical
  have hdeg : ∀ p : ((ι → K) × K) × (Fin n → K),
      IndDegLE (d + 1) (fun x => eqPoly p.2 x * batched W p.1.1 x + p.1.2 * Hs x) := fun p =>
    ((IndDegLE.wsum hW p.1.1).eq_mul p.2).add_smul hHs p.1.2
  have hsum : ∀ p : ((ι → K) × K) × (Fin n → K),
      cubeSum (fun x => eqPoly p.2 x * batched W p.1.1 x + p.1.2 * Hs x)
        = mleAt (fun b => batched W p.1.1 (bitv b)) p.2 + p.1.2 * cubeSum Hs := by
    intro p
    rw [cubeSum_add (fun x => eqPoly p.2 x * batched W p.1.1 x) (fun x => p.1.2 * Hs x), cubeSum_eq_mul,
      cubeSum_smul]
    rfl
  -- the claim is TRUE only on a bad set of `(μ, ν, τ)`
  let G : ((ι → K) × K) × (Fin n → K) → Prop :=
    fun p => p.1.2 * S = mleAt (fun b => batched W p.1.1 (bitv b)) p.2 + p.1.2 * cubeSum Hs
  have hsub : ∀ ω : (((ι → K) × K) × (Fin n → K)) × (Fin n → K),
      Accepts n (fun x => eqPoly ω.1.2 x * batched W ω.1.1.1 x + ω.1.1.2 * Hs x) (ω.1.1.2 * S) (P ω.1) ω.2 →
      G ω.1 ∨ (¬ G ω.1 ∧ Accepts n (fun x => eqPoly ω.1.2 x * batched W ω.1.1.1 x + ω.1.1.2 * Hs x)
        (ω.1.1.2 * S) (P ω.1) ω.2) := by
    intro ω h
    by_cases hg : G ω.1
    · exact Or.inl hg
    · exact Or.inr ⟨hg, h⟩
  refine (pr_mono hsub).trans ((pr_or_le _ _).trans ?_)
  -- a false claim: the sumcheck's bound
  have h2 : pr (fun ω : (((ι → K) × K) × (Fin n → K)) × (Fin n → K) => ¬ G ω.1 ∧
        Accepts n (fun x => eqPoly ω.1.2 x * batched W ω.1.1.1 x + ω.1.1.2 * Hs x) (ω.1.1.2 * S) (P ω.1) ω.2)
      ≤ ((n * (d + 1) : ℕ) : ℝ≥0∞) / Fintype.card K := by
    refine pr_prod_le _ (fun p => ?_)
    by_cases hg : G p
    · exact pr_le_of_not _ (fun ρ hρ => hρ.1 hg) _
    · refine (pr_mono (E' := fun ρ => Accepts n (fun x => eqPoly p.2 x * batched W p.1.1 x + p.1.2 * Hs x)
        (p.1.2 * S) (P p) ρ) (fun ρ hρ => hρ.2)).trans ?_
      refine sumcheck_sound hd (hdeg p) ?_ (P p)
      rw [hsum]
      exact hg
  -- the bad set of `(μ, ν, τ)`
  have h1 : pr G ≤ ((2 + n : ℕ) : ℝ≥0∞) / Fintype.card K := by
    by_cases hS : cubeSum Hs = S
    · -- the hosted sum is right: some clause is nonzero, and the claim is the zero-check's
      obtain ⟨j₀, b₀, hb₀⟩ := hbad.resolve_right (fun h => h hS)
      have hsub' : ∀ p : ((ι → K) × K) × (Fin n → K), G p →
          batched W p.1.1 (bitv b₀) = 0 ∨
            (batched W p.1.1 (bitv b₀) ≠ 0 ∧ mleAt (fun b => batched W p.1.1 (bitv b)) p.2 = 0) := by
        intro p hp
        by_cases hz : batched W p.1.1 (bitv b₀) = 0
        · exact Or.inl hz
        · refine Or.inr ⟨hz, ?_⟩
          have h' : p.1.2 * S = mleAt (fun b => batched W p.1.1 (bitv b)) p.2 + p.1.2 * cubeSum Hs := hp
          rw [hS] at h'
          linear_combination -h'
      refine (pr_mono hsub').trans ((pr_or_le _ _).trans ?_)
      have e1 : pr (fun p : ((ι → K) × K) × (Fin n → K) => batched W p.1.1 (bitv b₀) = 0)
          ≤ (1 : ℝ≥0∞) / Fintype.card K := by
        refine (pr_fst_le (fun c : (ι → K) × K => batched W c.1 (bitv b₀) = 0)).trans ?_
        refine (pr_fst_le (fun μ : ι → K => batched W μ (bitv b₀) = 0)).trans ?_
        exact batch_prob (fun j => W j (bitv b₀)) ⟨j₀, hb₀⟩
      have e2 : pr (fun p : ((ι → K) × K) × (Fin n → K) => batched W p.1.1 (bitv b₀) ≠ 0 ∧
            mleAt (fun b => batched W p.1.1 (bitv b)) p.2 = 0)
          ≤ (n : ℝ≥0∞) / Fintype.card K := by
        refine pr_prod_le _ (fun c => ?_)
        by_cases hz : batched W c.1 (bitv b₀) = 0
        · exact pr_le_of_not _ (fun τ hτ => hτ.1 hz) _
        · refine (pr_mono (E' := fun τ => mleAt (fun b => batched W c.1 (bitv b)) τ = 0)
            (fun τ hτ => hτ.2)).trans ?_
          exact mle_zero_prob _ ⟨b₀, hz⟩
      calc _ ≤ (1 : ℝ≥0∞) / Fintype.card K + (n : ℝ≥0∞) / Fintype.card K := add_le_add e1 e2
        _ ≤ ((2 + n : ℕ) : ℝ≥0∞) / Fintype.card K := by
            rw [ENNReal.div_add_div_same]
            exact ENNReal.div_le_div_right (by exact_mod_cast (show 1 + n ≤ 2 + n by omega)) _
    · -- the hosted sum is wrong: at most one `ν` for each `(μ, τ)`
      have hδ : cubeSum Hs - S ≠ 0 := sub_ne_zero.mpr hS
      have hG1 : pr G ≤ (1 : ℝ≥0∞) / Fintype.card K := by
        refine pr_prod_le_right _ (fun τ => ?_)
        refine pr_prod_le _ (fun μ => ?_)
        refine (pr_mono (E' := fun ν : K =>
          mleAt (fun b => batched W μ (bitv b)) τ + ν * (cubeSum Hs - S) = 0) (fun ν hν => ?_)).trans
          (single_root_prob _ _ hδ)
        have h' : ν * S = mleAt (fun b => batched W μ (bitv b)) τ + ν * cubeSum Hs := hν
        linear_combination -h'
      exact hG1.trans (ENNReal.div_le_div_right (by exact_mod_cast (show 1 ≤ 2 + n by omega)) _)
  calc _ ≤ ((2 + n : ℕ) : ℝ≥0∞) / Fintype.card K + ((n * (d + 1) : ℕ) : ℝ≥0∞) / Fintype.card K :=
        add_le_add ((pr_fst_le G).trans h1) h2
    _ = ((2 + (n + n * (d + 1)) : ℕ) : ℝ≥0∞) / Fintype.card K := by
        rw [ENNReal.div_add_div_same, ← Nat.cast_add, Nat.add_assoc]

/-- **A host slot with a pad clause** (TZC of stage OUT and OUT-C, VZC of stage OUT): if some clause or pad plane is
nonzero somewhere, OR the hosted sum is not `S`, then over uniform `ζ`, `μ`, `ν`, `τ` and the rounds the host accepts
with probability at most `((m − 1) + (2 + n + n·(d + 1)))/|K|`. -/
theorem host_pad_sound [Fintype K] [DecidableEq K] [Fintype ι] [DecidableEq ι] {n d m : ℕ} (hd : d + 1 < ringChar K) (W : ι → (Fin n → K) → K)
    (Pz : Fin m → (Fin n → K) → K) (hW : ∀ j, IndDegLE d (W j)) (hP : ∀ i, IndDegLE d (Pz i))
    (Hs : (Fin n → K) → K) (hHs : IndDegLE (d + 1) Hs) (S : K)
    (hbad : (∃ j, ∃ b : Fin n → Bool, W j (bitv b) ≠ 0) ∨ (∃ i, ∃ b : Fin n → Bool, Pz i (bitv b) ≠ 0) ∨
      cubeSum Hs ≠ S)
    (P : K → ((Option ι → K) × K) × (Fin n → K) → Prover K (d + 1) n) :
    pr (fun ω : K × ((((Option ι → K) × K) × (Fin n → K)) × (Fin n → K)) =>
        Accepts n (fun x => eqPoly ω.2.1.2 x * batched (withPad W Pz ω.1) ω.2.1.1.1 x + ω.2.1.1.2 * Hs x)
          (ω.2.1.1.2 * S) (P ω.1 ω.2.1) ω.2.2)
      ≤ (((m - 1) + (2 + (n + n * (d + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K := by
  classical
  let Z : K → Prop := fun ζ => (∀ j, ∀ b : Fin n → Bool, withPad W Pz ζ j (bitv b) = 0) ∧ cubeSum Hs = S
  have hsub : ∀ ω : K × ((((Option ι → K) × K) × (Fin n → K)) × (Fin n → K)),
      Accepts n (fun x => eqPoly ω.2.1.2 x * batched (withPad W Pz ω.1) ω.2.1.1.1 x + ω.2.1.1.2 * Hs x)
        (ω.2.1.1.2 * S) (P ω.1 ω.2.1) ω.2.2 →
      Z ω.1 ∨ (¬ Z ω.1 ∧ Accepts n (fun x => eqPoly ω.2.1.2 x * batched (withPad W Pz ω.1) ω.2.1.1.1 x +
        ω.2.1.1.2 * Hs x) (ω.2.1.1.2 * S) (P ω.1 ω.2.1) ω.2.2) := by
    intro ω h
    by_cases hz : Z ω.1
    · exact Or.inl hz
    · exact Or.inr ⟨hz, h⟩
  refine (pr_mono hsub).trans ((pr_or_le _ _).trans ?_)
  have h1 : pr (fun ω : K × ((((Option ι → K) × K) × (Fin n → K)) × (Fin n → K)) => Z ω.1)
      ≤ ((m - 1 : ℕ) : ℝ≥0∞) / Fintype.card K := by
    refine (pr_fst_le Z).trans ?_
    rcases hbad with ⟨j, b, hb⟩ | ⟨i, b, hb⟩ | hS
    · exact pr_le_of_not _ (fun ζ hζ => hb (by have h' := hζ.1 (some j) b; rwa [withPad_some] at h')) _
    · refine (pr_mono (E' := fun ζ : K => ∀ b' : Fin n → Bool,
          ∑ i' : Fin m, ζ ^ (i' : ℕ) * Pz i' (bitv b') = 0) (fun ζ hζ b' => by have h' := hζ.1 none b'; rwa [withPad_none] at h')).trans ?_
      exact zetaFold_prob (fun i' (b' : Fin n → Bool) => Pz i' (bitv b')) ⟨i, b, hb⟩
    · exact pr_le_of_not _ (fun ζ hζ => hS hζ.2) _
  have h2 : pr (fun ω : K × ((((Option ι → K) × K) × (Fin n → K)) × (Fin n → K)) => ¬ Z ω.1 ∧
        Accepts n (fun x => eqPoly ω.2.1.2 x * batched (withPad W Pz ω.1) ω.2.1.1.1 x + ω.2.1.1.2 * Hs x)
          (ω.2.1.1.2 * S) (P ω.1 ω.2.1) ω.2.2)
      ≤ ((2 + (n + n * (d + 1)) : ℕ) : ℝ≥0∞) / Fintype.card K := by
    refine pr_prod_le _ (fun ζ => ?_)
    by_cases hz : Z ζ
    · exact pr_le_of_not _ (fun ω hω => hω.1 hz) _
    · have hbad' : (∃ j, ∃ b : Fin n → Bool, withPad W Pz ζ j (bitv b) ≠ 0) ∨ cubeSum Hs ≠ S := by
        by_cases hS : cubeSum Hs = S
        · refine Or.inl ?_
          by_contra hc
          push Not at hc
          exact hz ⟨hc, hS⟩
        · exact Or.inr hS
      refine (pr_mono (E' := fun ω : (((Option ι → K) × K) × (Fin n → K)) × (Fin n → K) =>
          Accepts n (fun x => eqPoly ω.1.2 x * batched (withPad W Pz ζ) ω.1.1.1 x + ω.1.1.2 * Hs x)
            (ω.1.1.2 * S) (P ζ ω.1) ω.2) (fun ω hω => hω.2)).trans ?_
      exact host_sound hd (withPad W Pz ζ) (withPad_deg hW hP ζ) Hs hHs S hbad' (P ζ)
  calc _ ≤ ((m - 1 : ℕ) : ℝ≥0∞) / Fintype.card K + ((2 + (n + n * (d + 1)) : ℕ) : ℝ≥0∞) / Fintype.card K :=
        add_le_add h1 h2
    _ = _ := by rw [ENNReal.div_add_div_same, ← Nat.cast_add]

end Slots

/-! ## Pads and cube sums -/

/-- **A cube sum with zero pads is the logical sum.** If `f` vanishes off the image of an injective layout map
`pos : P → cube`, its sum over the cube is its sum over the logical positions. This is how the pad clauses turn the
code's whole-plane LogUp sum claim (`logup_sum_claim`, token_io.rs:887-896) into the logical one. -/
theorem cube_sum_of_pad {M Cb P : Type} [AddCommMonoid M] [Fintype Cb] [DecidableEq Cb] [Fintype P] (pos : P → Cb)
    (hpos : Function.Injective pos) (f : Cb → M) (hpad : ∀ b, b ∉ Set.range pos → f b = 0) :
    ∑ b, f b = ∑ t, f (pos t) := by
  classical
  rw [← Finset.sum_image (f := f) (s := Finset.univ) (g := pos) hpos.injOn]
  refine (Finset.sum_subset (Finset.subset_univ _) (fun b _ hb => hpad b ?_)).symm
  rintro ⟨t, rfl⟩
  exact hb (Finset.mem_image_of_mem pos (Finset.mem_univ t))

end ZK60.StageX
