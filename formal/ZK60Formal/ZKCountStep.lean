/-
D63 step L19 (Statement 2, zero knowledge), part 4: ONE Fiat–Shamir receipt, honest on `x` versus honest on a stand-in
`x'`, with every query charged at ITS OWN rate (`ZKW16Step.fs_step` with weighted budgets).

`fs_step` bounds the bad events by `q₁·K` (before the request, `K` the worst hit count of one query) and `q₂·KU` (after
it). Here each query `z` has its own hit counts `Kf z` and `KUf z` (`hKw`, `hUw`), and the context's budgets are
weighted (`ZKCount.WB`): `A₁` within `W₁` (weights `Kf`), `A₂` within `W₂` (weights `KUf`).

* `apBad_card_w`: the chain-programming bad set, at most `Pr_H[F]·(W₁ + Kc)` in counts;
* `hid_card_w`: the hidden hits, at most `Pr_H[F]·|D^k|·W₂` in counts;
* **`fs_step_w`**: honest on `x` versus honest on `x'`, both ways, within
  `Pr_H[F]·(2(W₁ + 2·Kc)/|C × D^k| + 2·W₂/|C|)`;
* `OneStepW`, **`oneStepW_of_fsModel`**: the per-receipt bound of a protocol whose prover is an `FSModel`'s, for every
  context of weighted budgets `(W₁, W₂)`.

With `Kf ≡ K` and `KUf ≡ KU` this is `fs_step` (`WB_of_bounded`); the gain is that a prover's column digests, leaves and
nodes weigh what THEY can hit, not what a transcript query can.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKCount

namespace ZK60.ZKCount

open scoped ENNReal
open Finset ZK60.ZKW16

/-! ## The chain-programming bad set, weighted -/

section Prog

variable {Q D S α : Type} [DecidableEq Q] {k : ℕ}

open Classical in
/-- **The bad set is small, weighted** (`ZKW16.apBad_card` with per-query hit counts): for an `A₁` within the weighted
budget `W₁` (weights `Kf`), if one query `z` is hit by some point for at most `Kf z` of the `(σ, v)` and two points
collide or land in `dep` for at most `Kc`, the flagged bad count is at most the flagged oracle count times
`W₁ + Kc`. -/
theorem apBad_card_w [Fintype Q] [Fintype D] [Fintype S] {y : α → S → (Q → D) → (Fin k → D) → Fin k → Q}
    {dep : α → S → Set Q} (A₁ : OC Q D α) (Kf : Q → ℕ) (W₁ : ℕ) (hA₁ : WB Kf A₁ W₁) (Kc : ℕ)
    (hK : ∀ a (H : Q → D) z, (univ.filter (fun s : S × (Fin k → D) => ∃ i, y a s.1 H s.2 i = z)).card ≤ Kf z)
    (hKc : ∀ a (H : Q → D), (univ.filter (fun s : S × (Fin k → D) =>
      ¬ Function.Injective (y a s.1 H s.2) ∨ ∃ i, y a s.1 H s.2 i ∈ dep a s.1)).card ≤ Kc)
    (F : α → Prop) :
    (univ.filter (fun ω : (Q → D) × (S × (Fin k → D)) => F (A₁.run ω.1) ∧ ¬ apGoodI y A₁ dep ω)).card
      ≤ (univ.filter (fun H : Q → D => F (A₁.run H))).card * (W₁ + Kc) := by
  classical
  rw [card_filter_prod]
  have hfib : ∀ H : Q → D, (univ.filter (fun s : S × (Fin k → D) => F (A₁.run (H, s).1) ∧ ¬ apGoodI y A₁ dep (H, s))).card
      ≤ if F (A₁.run H) then W₁ + Kc else 0 := by
    intro H
    by_cases hF : F (A₁.run H)
    · rw [ite_eq_left hF]
      set L := OC.queries H A₁
      have hLw : ∑ z ∈ L.toFinset, Kf z ≤ W₁ := hA₁.toFinset_sum H
      have hsub : univ.filter (fun s : S × (Fin k → D) => F (A₁.run (H, s).1) ∧ ¬ apGoodI y A₁ dep (H, s))
          ⊆ L.toFinset.biUnion (fun z => univ.filter (fun s : S × (Fin k → D) => ∃ i, y (A₁.run H) s.1 H s.2 i = z))
            ∪ univ.filter (fun s : S × (Fin k → D) => ¬ Function.Injective (y (A₁.run H) s.1 H s.2)
              ∨ ∃ i, y (A₁.run H) s.1 H s.2 i ∈ dep (A₁.run H) s.1) := by
        intro s hs
        simp only [mem_filter, mem_univ, true_and, apGoodI, not_and_or, not_forall, not_not] at hs
        simp only [mem_union, mem_biUnion, List.mem_toFinset, mem_filter, mem_univ, true_and]
        rcases hs.2 with h | ⟨i, hi⟩ | ⟨i, hi⟩
        · exact Or.inr (Or.inl h)
        · exact Or.inl ⟨_, hi, i, rfl⟩
        · exact Or.inr (Or.inr ⟨i, hi⟩)
      calc (univ.filter (fun s : S × (Fin k → D) => F (A₁.run (H, s).1) ∧ ¬ apGoodI y A₁ dep (H, s))).card
          ≤ (L.toFinset.biUnion (fun z => univ.filter (fun s : S × (Fin k → D) =>
                ∃ i, y (A₁.run H) s.1 H s.2 i = z))).card
              + (univ.filter (fun s : S × (Fin k → D) => ¬ Function.Injective (y (A₁.run H) s.1 H s.2)
                ∨ ∃ i, y (A₁.run H) s.1 H s.2 i ∈ dep (A₁.run H) s.1)).card :=
            (card_le_card hsub).trans (card_union_le _ _)
        _ ≤ (∑ z ∈ L.toFinset, Kf z) + Kc :=
            Nat.add_le_add (card_biUnion_le.trans (sum_le_sum (fun z _ => hK _ H z))) (hKc _ H)
        _ ≤ W₁ + Kc := Nat.add_le_add_right hLw _
    · rw [ite_eq_right hF]
      refine Nat.le_zero.mpr (card_eq_zero.mpr (filter_eq_empty_iff.mpr (fun s _ h => hF h.1)))
  calc ∑ H : Q → D, (univ.filter (fun s : S × (Fin k → D) => F (A₁.run (H, s).1) ∧ ¬ apGoodI y A₁ dep (H, s))).card
      ≤ ∑ H : Q → D, (if F (A₁.run H) then W₁ + Kc else 0) := sum_le_sum (fun H _ => hfib H)
    _ = (univ.filter (fun H : Q → D => F (A₁.run H))).card * (W₁ + Kc) := by
        rw [← sum_filter, sum_const, smul_eq_mul]

end Prog

/-! ## One receipt, weighted -/

namespace FSModelW

open FSModel

variable {Q D X C Out : Type} [DecidableEq Q] [Inhabited D] {α : Type}

variable [Fintype Q] [Fintype D] [Fintype C]

omit [Inhabited D] in
open Classical in
/-- **The hidden hits, weighted** (`FSModel.hid_card` with per-query hit counts): for an `A₂` within the weighted
budget `W₂` (weights `KUf`), if every query set read off the receipt whose weights add up to at most `W` catches a
hidden point for at most `W` coins (`hU`), the flagged hidden count is at most `Pr_H[F]·|D^k|·W₂` in counts. -/
theorem hid_card_w (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x : α → X) (A₂ : α → Out → OC Q D Bool)
    (F : α → Prop) (KUf : Q → ℕ) (W₂ : ℕ) (hA₂ : ∀ a o, WB KUf (A₂ a o) W₂)
    (hU : ∀ x (H : Q → D) (v : Fin M.k → D) (Z : Out → Finset Q) (W : ℕ), (∀ o, ∑ z ∈ Z o, KUf z ≤ W) →
      (univ.filter (fun c => ∃ i, ¬ M.vis v i ∧ M.pts x c H v i ∈ Z (M.out x c v))).card ≤ W) :
    (univ.filter (M.hidEv A₁ x A₂ F)).card
      ≤ (univ.filter (fun H : Q → D => F (A₁.run H))).card * (Fintype.card (Fin M.k → D) * W₂) := by
  classical
  rw [card_filter_prod]
  calc ∑ H : Q → D, (univ.filter (fun s : C × (Fin M.k → D) => M.hidEv A₁ x A₂ F (H, s))).card
      ≤ ∑ H : Q → D, (if F (A₁.run H) then Fintype.card (Fin M.k → D) * W₂ else 0) := by
        refine sum_le_sum (fun H _ => ?_)
        by_cases hF : F (A₁.run H)
        · rw [ite_eq_left hF, card_filter_prod_right]
          calc ∑ v : Fin M.k → D, (univ.filter (fun c : C => M.hidEv A₁ x A₂ F (H, (c, v)))).card
              ≤ ∑ _v : Fin M.k → D, W₂ := by
                refine sum_le_sum (fun v _ => ?_)
                let Z : Out → Finset Q := fun o =>
                  (OC.queries (M.progVis o H v) (A₂ (A₁.run H) o)).toFinset
                have hZ : ∀ o, ∑ z ∈ Z o, KUf z ≤ W₂ := fun o =>
                  (hA₂ (A₁.run H) o).toFinset_sum (M.progVis o H v)
                have hsub : univ.filter (fun c : C => M.hidEv A₁ x A₂ F (H, (c, v)))
                    ⊆ univ.filter (fun c : C => ∃ i, ¬ M.vis v i
                      ∧ M.pts (x (A₁.run H)) c H v i ∈ Z (M.out (x (A₁.run H)) c v)) := by
                  intro c hc
                  obtain ⟨-, z, hz, i, hi, hpi⟩ := (mem_filter.mp hc).2
                  exact mem_filter.mpr ⟨mem_univ _, i, hi, by rw [hpi]; exact List.mem_toFinset.mpr hz⟩
                exact (card_le_card hsub).trans (hU (x (A₁.run H)) H v Z W₂ hZ)
            _ = Fintype.card (Fin M.k → D) * W₂ := by rw [sum_const, card_univ, smul_eq_mul]
        · rw [ite_eq_right hF]
          exact Nat.le_zero.mpr (card_eq_zero.mpr (filter_eq_empty_iff.mpr (fun s _ h => hF h.1)))
    _ = (univ.filter (fun H : Q → D => F (A₁.run H))).card * (Fintype.card (Fin M.k → D) * W₂) := by
        rw [← sum_filter, sum_const, smul_eq_mul]

open Classical in
/-- **One receipt, honest on `x` versus honest on `x'`, every query at its own rate.** As `FSModel.fs_step`, with `A₁`
within the weighted budget `W₁` (one query `z` hit by some point for at most `Kf z` of the `(c, v)`, `hKw`) and `A₂`
within `W₂` (a query set of weight `W` catches a hidden point for at most `W` coins, `hUw`): the two success
probabilities differ, both ways, by at most `Pr_H[F]·(2(W₁ + 2·Kc)/|C × D^k| + 2·W₂/|C|)`. -/
theorem fs_step_w [Nonempty D] [Nonempty C] (M : FSModel Q D X C Out) (A₁ : OC Q D α) (Kf KUf : Q → ℕ) (W₁ W₂ : ℕ)
    (hA₁ : WB Kf A₁ W₁) (x x' : α → X)
    (hHV : ∀ a (v : Fin M.k → D), (PMF.uniformOfFintype C).map (fun c => M.out (x a) c v)
      = (PMF.uniformOfFintype C).map (fun c => M.out (x' a) c v))
    (Kc : ℕ)
    (hKw : ∀ x (H : Q → D) z, (univ.filter (fun s : C × (Fin M.k → D) => ∃ i, M.pts x s.1 H s.2 i = z)).card
      ≤ Kf z)
    (hKc : ∀ x (H : Q → D), (univ.filter (fun s : C × (Fin M.k → D) =>
      ¬ Function.Injective (M.pts x s.1 H s.2) ∨ ∃ i, M.pts x s.1 H s.2 i ∈ M.dep x s.1)).card ≤ Kc)
    (hUw : ∀ x (H : Q → D) (v : Fin M.k → D) (Z : Out → Finset Q) (W : ℕ), (∀ o, ∑ z ∈ Z o, KUf z ≤ W) →
      (univ.filter (fun c => ∃ i, ¬ M.vis v i ∧ M.pts x c H v i ∈ Z (M.out x c v))).card ≤ W)
    (A₂ : α → Out → OC Q D Bool) (hA₂ : ∀ a o, WB KUf (A₂ a o) W₂) (F : α → Prop) :
    (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x A₂ F p}
        ≤ (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x' A₂ F p}
          + (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | F (A₁.run H)}
            * ((((2 * (W₁ + 2 * Kc)) : ℕ) : ℝ≥0∞) / Fintype.card (C × (Fin M.k → D))
              + (((2 * W₂) : ℕ) : ℝ≥0∞) / Fintype.card C)
      ∧ (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x' A₂ F p}
        ≤ (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x A₂ F p}
          + (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | F (A₁.run H)}
            * ((((2 * (W₁ + 2 * Kc)) : ℕ) : ℝ≥0∞) / Fintype.card (C × (Fin M.k → D))
              + (((2 * W₂) : ℕ) : ℝ≥0∞) / Fintype.card C) := by
  classical
  -- the chain-programming step for an input choice `u`
  have hprogStep : ∀ u : α → X,
      (univ.filter (fun ω : (Q → D) × (C × (Fin M.k → D)) => F (A₁.run ω.1) ∧ apReal
          (fun a c H v => M.pts (u a) c H v) A₁ (fun a c v => A₂ a (M.out (u a) c v)) ω)).card
        ≤ (univ.filter (M.progEv A₁ u A₂ F)).card
          + (univ.filter (fun H : Q → D => F (A₁.run H))).card * (W₁ + Kc)
      ∧ (univ.filter (M.progEv A₁ u A₂ F)).card
        ≤ (univ.filter (fun ω : (Q → D) × (C × (Fin M.k → D)) => F (A₁.run ω.1) ∧ apReal
            (fun a c H v => M.pts (u a) c H v) A₁ (fun a c v => A₂ a (M.out (u a) c v)) ω)).card
          + (univ.filter (fun H : Q → D => F (A₁.run H))).card * (W₁ + Kc) := by
    intro u
    have hy : ∀ a c H, Causal (M.pts (u a) c H) := fun a c H => M.causal _ c H
    have hse : ∀ a c (H H' : Q → D) v, (∀ z ∈ M.dep (u a) c, H z = H' z) → M.pts (u a) c H v = M.pts (u a) c H' v :=
      fun a c H H' v h => M.sep _ c H H' v h
    obtain ⟨c1, c2⟩ := apCount (y := fun a c H v => M.pts (u a) c H v) (A₁ := A₁)
      (dep := fun a c => M.dep (u a) c) hy hse (fun a c v => A₂ a (M.out (u a) c v)) F
    have hb := apBad_card_w (y := fun a c H v => M.pts (u a) c H v) (dep := fun a c => M.dep (u a) c) A₁ Kf W₁ hA₁ Kc
      (fun a H z => hKw (u a) H z) (fun a H => hKc (u a) H) F
    have e : univ.filter (fun ω : (Q → D) × (C × (Fin M.k → D)) => F (A₁.run ω.1) ∧ apIdeal
        (fun a c H v => M.pts (u a) c H v) A₁ (fun a c v => A₂ a (M.out (u a) c v)) ω)
        = univ.filter (M.progEv A₁ u A₂ F) := by
      ext ω
      simp only [mem_filter, mem_univ, true_and]
      rfl
    rw [e] at c1 c2
    exact ⟨c1.trans (Nat.add_le_add_left hb _), c2.trans (Nat.add_le_add_left hb _)⟩
  obtain ⟨px1, px2⟩ := hprogStep x
  obtain ⟨py1, py2⟩ := hprogStep x'
  obtain ⟨ux1, ux2⟩ := unprog_count M A₁ x A₂ F
  obtain ⟨uy1, uy2⟩ := unprog_count M A₁ x' A₂ F
  have hW := unprog_law_eq M A₁ x x' hHV A₂ F
  have cx := coll_card M A₁ x F Kc hKc
  have cy := coll_card M A₁ x' F Kc hKc
  have hx := hid_card_w M A₁ x A₂ F KUf W₂ hA₂ hUw
  have hy' := hid_card_w M A₁ x' A₂ F KUf W₂ hA₂ hUw
  set NF := (univ.filter (fun H : Q → D => F (A₁.run H))).card with hNF
  set NV := Fintype.card (Fin M.k → D) with hNV
  set Rx := (univ.filter (fun ω : (Q → D) × (C × (Fin M.k → D)) => F (A₁.run ω.1) ∧ apReal
      (fun a c H v => M.pts (x a) c H v) A₁ (fun a c v => A₂ a (M.out (x a) c v)) ω)).card
  set Ry := (univ.filter (fun ω : (Q → D) × (C × (Fin M.k → D)) => F (A₁.run ω.1) ∧ apReal
      (fun a c H v => M.pts (x' a) c H v) A₁ (fun a c v => A₂ a (M.out (x' a) c v)) ω)).card
  have hB : NF * (W₁ + Kc) + (NF * Kc + NF * (NV * W₂))
      + (NF * Kc + NF * (NV * W₂)) + NF * (W₁ + Kc)
      = NF * (2 * (W₁ + 2 * Kc) + NV * (2 * W₂)) := by ring
  have hxy : Rx ≤ Ry + NF * (2 * (W₁ + 2 * Kc) + NV * (2 * W₂)) := by
    rw [← hB]
    omega
  have hyx : Ry ≤ Rx + NF * (2 * (W₁ + 2 * Kc) + NV * (2 * W₂)) := by
    rw [← hB]
    omega
  have hΩ : Fintype.card ((Q → D) × (C × (Fin M.k → D))) = Fintype.card (Q → D) * (Fintype.card C * NV) := by
    rw [Fintype.card_prod, Fintype.card_prod]
  have hNH0 : (Fintype.card (Q → D) : ℝ≥0∞) ≠ 0 := by simp
  have hNHt : (Fintype.card (Q → D) : ℝ≥0∞) ≠ ∞ := ENNReal.natCast_ne_top _
  have hNC0 : (Fintype.card C : ℝ≥0∞) ≠ 0 := by simp
  have hNCt : (Fintype.card C : ℝ≥0∞) ≠ ∞ := ENNReal.natCast_ne_top _
  have hNV0 : (NV : ℝ≥0∞) ≠ 0 := by simp [NV]
  have hNVt : (NV : ℝ≥0∞) ≠ ∞ := ENNReal.natCast_ne_top _
  have hconv : ∀ R R' : ℕ, R ≤ R' + NF * (2 * (W₁ + 2 * Kc) + NV * (2 * W₂)) →
      (R : ℝ≥0∞) / Fintype.card ((Q → D) × (C × (Fin M.k → D)))
        ≤ (R' : ℝ≥0∞) / Fintype.card ((Q → D) × (C × (Fin M.k → D)))
          + (NF : ℝ≥0∞) / Fintype.card (Q → D)
            * ((((2 * (W₁ + 2 * Kc)) : ℕ) : ℝ≥0∞) / Fintype.card (C × (Fin M.k → D))
              + (((2 * W₂) : ℕ) : ℝ≥0∞) / Fintype.card C) := by
    intro R R' h
    rw [hΩ, Fintype.card_prod]
    calc (R : ℝ≥0∞) / ((Fintype.card (Q → D) * (Fintype.card C * NV) : ℕ) : ℝ≥0∞)
        ≤ ((R' + NF * (2 * (W₁ + 2 * Kc) + NV * (2 * W₂)) : ℕ) : ℝ≥0∞)
            / ((Fintype.card (Q → D) * (Fintype.card C * NV) : ℕ) : ℝ≥0∞) := by
          gcongr
      _ = _ := by
          simp only [Nat.cast_add, Nat.cast_mul, Nat.cast_ofNat]
          rw [div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv,
            ENNReal.mul_inv (Or.inl hNH0) (Or.inl hNHt), ENNReal.mul_inv (Or.inl hNC0) (Or.inl hNCt)]
          have hvv : (NV : ℝ≥0∞) * (NV : ℝ≥0∞)⁻¹ = 1 := ENNReal.mul_inv_cancel hNV0 hNVt
          calc ((R' : ℝ≥0∞) + NF * (2 * (W₁ + 2 * Kc) + NV * (2 * W₂)))
                * ((Fintype.card (Q → D) : ℝ≥0∞)⁻¹ * ((Fintype.card C : ℝ≥0∞)⁻¹ * (NV : ℝ≥0∞)⁻¹))
              = (R' : ℝ≥0∞) * ((Fintype.card (Q → D) : ℝ≥0∞)⁻¹ * ((Fintype.card C : ℝ≥0∞)⁻¹ * (NV : ℝ≥0∞)⁻¹))
                + NF * (Fintype.card (Q → D) : ℝ≥0∞)⁻¹
                  * ((2 * (W₁ + 2 * Kc)) * ((Fintype.card C : ℝ≥0∞)⁻¹ * (NV : ℝ≥0∞)⁻¹)
                    + 2 * W₂ * (Fintype.card C : ℝ≥0∞)⁻¹ * ((NV : ℝ≥0∞) * (NV : ℝ≥0∞)⁻¹)) := by ring
            _ = _ := by rw [hvv, mul_one]
  have hreal : ∀ u : α → X,
      (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ u A₂ F p}
        = ((univ.filter (fun ω : (Q → D) × (C × (Fin M.k → D)) => F (A₁.run ω.1) ∧ apReal
            (fun a c H v => M.pts (u a) c H v) A₁ (fun a c v => A₂ a (M.out (u a) c v)) ω)).card : ℝ≥0∞)
          / Fintype.card ((Q → D) × (C × (Fin M.k → D))) := by
    intro u
    rw [real_count_eq M A₁ u A₂ F]
    exact prob_filter _
  have hF : (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | F (A₁.run H)}
      = (NF : ℝ≥0∞) / Fintype.card (Q → D) := prob_filter _
  rw [hreal x, hreal x', hF]
  exact ⟨hconv Rx Ry hxy, hconv Ry Rx hyx⟩

end FSModelW

/-! ## The per-receipt bound, weighted -/

section OneStepW

variable {Q D Coins : Type} [DecidableEq Q] {M : IntModel} (P : Protocol Q D Coins M) [Inhabited M.Input]
  (W : M.Weights) [Fintype Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins]

/-- **One receipt, honest versus stand-in, in any context of weighted budgets** (`ZKW16Hyb.OneStep` with `A₁` within
`W₁` under the weights `Kf` and `A₂` within `W₂` under `KUf`). -/
def OneStepW (Kf KUf : Q → ℕ) (ε : ℕ → ℕ → ℝ≥0∞) : Prop :=
  ∀ (α : Type) (A₁ : OC Q D α) (W₁ : ℕ), WB Kf A₁ W₁ → ∀ (x : α → M.Input)
    (A₂ : α → P.Stmt × P.Receipt → OC Q D Bool) (W₂ : ℕ), (∀ a o, WB KUf (A₂ a o) W₂) →
    (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
        {p | (A₂ (A₁.run p.1) (P.prove p.1 W (x (A₁.run p.1)) p.2)).run p.1 = true}
      ≤ (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
        {p | (A₂ (A₁.run p.1) (P.prove p.1 W (standin P W (M.publicPart (M.forward W (x (A₁.run p.1))),
          P.leak (x (A₁.run p.1)))) p.2)).run p.1 = true} + ε W₁ W₂
    ∧ (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
        {p | (A₂ (A₁.run p.1) (P.prove p.1 W (standin P W (M.publicPart (M.forward W (x (A₁.run p.1))),
          P.leak (x (A₁.run p.1)))) p.2)).run p.1 = true}
      ≤ (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
        {p | (A₂ (A₁.run p.1) (P.prove p.1 W (x (A₁.run p.1)) p.2)).run p.1 = true} + ε W₁ W₂

open Classical in
/-- **`OneStepW` from a Fiat–Shamir receipt model** (`fs_step_w` with the flag `true`). -/
theorem oneStepW_of_fsModel [Inhabited D] (FM : FSModel Q D M.Input Coins (P.Stmt × P.Receipt))
    (hP : ∀ H x c, P.prove H W x c = FM.prove H x c)
    (hHV : ∀ x (v : Fin FM.k → D), (PMF.uniformOfFintype Coins).map (fun c => FM.out x c v)
      = (PMF.uniformOfFintype Coins).map
          (fun c => FM.out (standin P W (M.publicPart (M.forward W x), P.leak x)) c v))
    (Kf KUf : Q → ℕ) (Kc : ℕ)
    (hKw : ∀ x (H : Q → D) z, (univ.filter (fun s : Coins × (Fin FM.k → D) =>
      ∃ i, FM.pts x s.1 H s.2 i = z)).card ≤ Kf z)
    (hKc : ∀ x (H : Q → D), (univ.filter (fun s : Coins × (Fin FM.k → D) =>
      ¬ Function.Injective (FM.pts x s.1 H s.2) ∨ ∃ i, FM.pts x s.1 H s.2 i ∈ FM.dep x s.1)).card ≤ Kc)
    (hUw : ∀ x (H : Q → D) (v : Fin FM.k → D) (Z : (P.Stmt × P.Receipt) → Finset Q) (Wt : ℕ),
      (∀ o, ∑ z ∈ Z o, KUf z ≤ Wt) →
      (univ.filter (fun c => ∃ i, ¬ FM.vis v i ∧ FM.pts x c H v i ∈ Z (FM.out x c v))).card ≤ Wt) :
    OneStepW P W Kf KUf (fun W₁ W₂ => (((2 * (W₁ + 2 * Kc)) : ℕ) : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → D))
      + (((2 * W₂) : ℕ) : ℝ≥0∞) / Fintype.card Coins) := by
  intro α A₁ W₁ hA₁ x A₂ W₂ hA₂
  have hstd := FSModelW.fs_step_w FM A₁ Kf KUf W₁ W₂ hA₁ x
    (fun a => standin P W (M.publicPart (M.forward W (x a)), P.leak (x a)))
    (fun a v => hHV (x a) v) Kc hKw hKc hUw A₂ hA₂ (fun _ => True)
  beta_reduce at hstd
  have hset : ∀ u : α → M.Input, {p : (Q → D) × Coins | FM.realEv A₁ u A₂ (fun _ => True) p}
      = {p | (A₂ (A₁.run p.1) (P.prove p.1 W (u (A₁.run p.1)) p.2)).run p.1 = true} := by
    intro u
    ext p
    simp only [Set.mem_ofPred_eq, FSModel.realEv, true_and, hP]
  have hone : (PMF.uniformOfFintype (Q → D)).toOuterMeasure {_H : Q → D | True} = 1 :=
    (PMF.toOuterMeasure_apply_eq_one_iff _ _).mpr (fun _ _ => trivial)
  rw [hset, hset, hone] at hstd
  simp only [one_mul] at hstd
  exact hstd

/-- `OneStepW` holds for any larger error. -/
theorem oneStepW_mono {Kf KUf : Q → ℕ} {ε ε' : ℕ → ℕ → ℝ≥0∞} (h : OneStepW P W Kf KUf ε)
    (hle : ∀ W₁ W₂, ε W₁ W₂ ≤ ε' W₁ W₂) : OneStepW P W Kf KUf ε' := by
  intro α A₁ W₁ hA₁ x A₂ W₂ hA₂
  obtain ⟨h1, h2⟩ := h α A₁ W₁ hA₁ x A₂ W₂ hA₂
  exact ⟨h1.trans (add_le_add le_rfl (hle W₁ W₂)), h2.trans (add_le_add le_rfl (hle W₁ W₂))⟩

end OneStepW

end ZK60.ZKCount
