/-
D63 lane L33 (2026-11-09), part 2: **one Fiat–Shamir receipt, honest on an input versus honest on its stand-in, for a
prover that REFUSES** (finding L33-1), and zero knowledge from it.

L14's `fs_step` and L19's `fs_step_w` ask two things of the receipt model that a refusing prover cannot give together:
`vis_pts` (a visible point is computable from the receipt, the oracle and the values) and `hU` / `hUw` (at EVERY value
vector, a query set read off the receipt catches a hidden point for few coins). At a value vector where a challenge
refusal fires (`c = 0`, a degenerate `e`, a LogUp `α` in the table, …) the receipt is the constant refusal (D65(2)):
it shows nothing, so the transcript points before the refusal are not computable from it (they absorbed masked
scalars), and as hidden points they have too little freshness in the coins alone (a `pb-slot` absorb has none). The
refusals happen with probability about `2^-57` per receipt (L25), far above the zero-knowledge target, so they cannot be
charged as a bad event either. Here the step is re-proved with a refusal GUARD:

* `G v`: at the values `v` the receipt is the constant refusal `o₀` for every input and coin (`hrefG`: the refusal is
  a function of the challenges and public data alone, L4's class (C)), and nothing is visible there (`hvisG`);
* `progVis_of_no_vis`: with nothing visible the oracle the distinguisher sees is the plain one;
* **`hid_card_ref`**: the hidden hits. Where the guard does not fire: L19's count, value vector by value vector
  (`hUw`, now needed only there). Where it fires: the distinguisher's questions are those it asks of the PLAIN oracle
  on the constant refusal, a set that does not depend on the values or the coins, so the count over coins AND values
  is the one `hKw` already gives (each point is fresh in the values), turned into the after-request weights by
  `hKG : Kf z ≤ |D^k|·KUf z`;
* `fs_step_of_hid`, **`fs_step_ref`**: L19's `fs_step_w` from any bound on the hidden hits; with the guard the
  after-request term doubles: `Pr_H[F]·(2(W₁ + 2·Kc)/|C × D^k| + 2·(2·W₂)/|C|)`;
* **`oneStepW_ref`**: L19's `OneStepW` for a protocol whose prover (i) answers the constant refusal on an inadmissible
  input (class (B), `hun`), with admissibility a function of the leakage (`hstd`), and (ii) on admissible inputs is the
  honest prover of a receipt model with a guard. The model is needed on ADMISSIBLE inputs only (its input type is the
  subtype), and its honest-verifier law only where the guard does not fire;
* **`zk_of_refModel`**: `ZeroKnowledge` (Statements.lean's, the stand-in simulator) with the error
  `Σ_{j<R} wStep δp ωp δh ωh εc q R j`; **`zk_ref_cap`**: with a receipt's counts by kind `Z` (L19's `ZKKinds`), that
  error is within the approved `εzkTarget q R` for every `q` and every `R ≤ 2^r` (L19's `ZKKinds.cap_R`).

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKHonestProg

set_option autoImplicit false

namespace ZK60.ZKHonest

open scoped ENNReal
open Finset ZK60 ZK60.ZKW16 ZK60.ZKCount ZK60.ZKHybrid

/-! ## The hidden hits with a refusal guard -/

/-- **With nothing visible, the oracle programmed at the visible points is the plain oracle.** -/
theorem progVis_of_no_vis {Q D X C Out : Type} [DecidableEq Q] (M : FSModel Q D X C Out) (o : Out) (H : Q → D)
    (v : Fin M.k → D) (hv : ∀ i, ¬ M.vis v i) : M.progVis o H v = H := by
  classical
  funext z
  have hex : ¬ ∃ i, M.vis v i ∧ M.vp o H v i = z := fun ⟨i, hi, _⟩ => hv i hi
  unfold FSModel.progVis
  rw [dite_eq_right hex]

open Classical in
/-- **The hidden hits of a refusing prover.** Let `G v` say that at the values `v` the receipt is the constant refusal
`o₀` whatever the input and the coin (`hrefG`) and no point is visible (`hvisG`). If L19's hidden bound holds at every
value vector where the guard does not fire (`hU`), every question is hit by some point for at most `Kf z` of the
`(c, v)` (`hKw`), and `Kf z ≤ |D^k|·KUf z` (`hKG`), then for an `A₂` within the weighted budget `W₂` (weights `KUf`)
the flagged hidden count is at most `Pr_H[F]·|D^k|·(2·W₂)` in counts. -/
theorem hid_card_ref {Q D X C Out α : Type} [DecidableEq Q] [Fintype Q] [Fintype D] [Fintype C]
    (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x : α → X) (A₂ : α → Out → OC Q D Bool) (F : α → Prop)
    (Kf KUf : Q → ℕ) (W₂ : ℕ) (hA₂ : ∀ a o, WB KUf (A₂ a o) W₂) (G : (Fin M.k → D) → Prop) (o₀ : Out)
    (hvisG : ∀ v i, G v → ¬ M.vis v i) (hrefG : ∀ x c v, G v → M.out x c v = o₀)
    (hKw : ∀ x (H : Q → D) z, (univ.filter (fun s : C × (Fin M.k → D) => ∃ i, M.pts x s.1 H s.2 i = z)).card
      ≤ Kf z)
    (hKG : ∀ z, Kf z ≤ Fintype.card (Fin M.k → D) * KUf z)
    (hU : ∀ x (H : Q → D) (v : Fin M.k → D), ¬ G v → ∀ (Z : Out → Finset Q) (W : ℕ),
      (∀ o, ∑ z ∈ Z o, KUf z ≤ W) →
      (univ.filter (fun c => ∃ i, ¬ M.vis v i ∧ M.pts x c H v i ∈ Z (M.out x c v))).card ≤ W) :
    (univ.filter (M.hidEv A₁ x A₂ F)).card
      ≤ (univ.filter (fun H : Q → D => F (A₁.run H))).card * (Fintype.card (Fin M.k → D) * (2 * W₂)) := by
  classical
  rw [card_filter_prod]
  calc ∑ H : Q → D, (univ.filter (fun s : C × (Fin M.k → D) => M.hidEv A₁ x A₂ F (H, s))).card
      ≤ ∑ H : Q → D, (if F (A₁.run H) then Fintype.card (Fin M.k → D) * (2 * W₂) else 0) := by
        refine sum_le_sum (fun H _ => ?_)
        by_cases hF : F (A₁.run H)
        · rw [ite_eq_left hF]
          -- split the fibre by the guard
          have hsplit : (univ.filter (fun s : C × (Fin M.k → D) => M.hidEv A₁ x A₂ F (H, s))).card
              ≤ (univ.filter (fun s : C × (Fin M.k → D) => ¬ G s.2 ∧ M.hidEv A₁ x A₂ F (H, s))).card
                + (univ.filter (fun s : C × (Fin M.k → D) => G s.2 ∧ M.hidEv A₁ x A₂ F (H, s))).card := by
            refine (card_le_card ?_).trans (card_union_le _ _)
            intro s hs
            have h := (mem_filter.mp hs).2
            by_cases hg : G s.2
            · exact mem_union.mpr (Or.inr (mem_filter.mpr ⟨mem_univ _, hg, h⟩))
            · exact mem_union.mpr (Or.inl (mem_filter.mpr ⟨mem_univ _, hg, h⟩))
          -- where the guard does not fire: L19's count, value vector by value vector
          have hno : (univ.filter (fun s : C × (Fin M.k → D) => ¬ G s.2 ∧ M.hidEv A₁ x A₂ F (H, s))).card
              ≤ Fintype.card (Fin M.k → D) * W₂ := by
            rw [card_filter_prod_right]
            calc ∑ v : Fin M.k → D, (univ.filter (fun c : C => ¬ G v ∧ M.hidEv A₁ x A₂ F (H, (c, v)))).card
                ≤ ∑ _v : Fin M.k → D, W₂ := by
                  refine sum_le_sum (fun v _ => ?_)
                  by_cases hg : G v
                  · have he : univ.filter (fun c : C => ¬ G v ∧ M.hidEv A₁ x A₂ F (H, (c, v))) = ∅ :=
                      filter_eq_empty_iff.mpr (fun c _ h => h.1 hg)
                    rw [he, card_empty]
                    exact Nat.zero_le _
                  · let Z : Out → Finset Q := fun o =>
                      (OC.queries (M.progVis o H v) (A₂ (A₁.run H) o)).toFinset
                    have hZ : ∀ o, ∑ z ∈ Z o, KUf z ≤ W₂ := fun o =>
                      (hA₂ (A₁.run H) o).toFinset_sum (M.progVis o H v)
                    have hsub : univ.filter (fun c : C => ¬ G v ∧ M.hidEv A₁ x A₂ F (H, (c, v)))
                        ⊆ univ.filter (fun c : C => ∃ i, ¬ M.vis v i
                          ∧ M.pts (x (A₁.run H)) c H v i ∈ Z (M.out (x (A₁.run H)) c v)) := by
                      intro c hc
                      obtain ⟨-, -, z, hz, i, hi, hpi⟩ := (mem_filter.mp hc).2
                      exact mem_filter.mpr ⟨mem_univ _, i, hi, by rw [hpi]; exact List.mem_toFinset.mpr hz⟩
                    exact (card_le_card hsub).trans (hU (x (A₁.run H)) H v hg Z W₂ hZ)
              _ = Fintype.card (Fin M.k → D) * W₂ := by rw [sum_const, card_univ, smul_eq_mul]
          -- where it fires: nothing is programmed and the receipt is the constant refusal
          have hyes : (univ.filter (fun s : C × (Fin M.k → D) => G s.2 ∧ M.hidEv A₁ x A₂ F (H, s))).card
              ≤ Fintype.card (Fin M.k → D) * W₂ := by
            have hLw : ∑ z ∈ (OC.queries H (A₂ (A₁.run H) o₀)).toFinset, KUf z ≤ W₂ :=
              (hA₂ (A₁.run H) o₀).toFinset_sum H
            have hsub : univ.filter (fun s : C × (Fin M.k → D) => G s.2 ∧ M.hidEv A₁ x A₂ F (H, s))
                ⊆ (OC.queries H (A₂ (A₁.run H) o₀)).toFinset.biUnion (fun z =>
                  univ.filter (fun s : C × (Fin M.k → D) => ∃ i, M.pts (x (A₁.run H)) s.1 H s.2 i = z)) := by
              intro s hs
              obtain ⟨hg, -, z, hz, i, -, hpi⟩ := (mem_filter.mp hs).2
              have hz' : z ∈ OC.queries (M.progVis (M.out (x (A₁.run H)) s.1 s.2) H s.2)
                  (A₂ (A₁.run H) (M.out (x (A₁.run H)) s.1 s.2)) := hz
              have hout : M.out (x (A₁.run H)) s.1 s.2 = o₀ := hrefG _ _ _ hg
              have hpv : M.progVis o₀ H s.2 = H := progVis_of_no_vis M o₀ H s.2 (fun i => hvisG s.2 i hg)
              rw [hout, hpv] at hz'
              have hpi' : M.pts (x (A₁.run H)) s.1 H s.2 i = z := hpi
              exact mem_biUnion.mpr ⟨z, List.mem_toFinset.mpr hz', mem_filter.mpr ⟨mem_univ _, i, hpi'⟩⟩
            calc (univ.filter (fun s : C × (Fin M.k → D) => G s.2 ∧ M.hidEv A₁ x A₂ F (H, s))).card
                ≤ ((OC.queries H (A₂ (A₁.run H) o₀)).toFinset.biUnion (fun z =>
                    univ.filter (fun s : C × (Fin M.k → D) => ∃ i, M.pts (x (A₁.run H)) s.1 H s.2 i = z))).card :=
                  card_le_card hsub
              _ ≤ ∑ z ∈ (OC.queries H (A₂ (A₁.run H) o₀)).toFinset, Kf z :=
                  card_biUnion_le.trans (sum_le_sum (fun z _ => hKw _ H z))
              _ ≤ ∑ z ∈ (OC.queries H (A₂ (A₁.run H) o₀)).toFinset, Fintype.card (Fin M.k → D) * KUf z :=
                  sum_le_sum (fun z _ => hKG z)
              _ = Fintype.card (Fin M.k → D) * ∑ z ∈ (OC.queries H (A₂ (A₁.run H) o₀)).toFinset, KUf z := by
                  rw [mul_sum]
              _ ≤ Fintype.card (Fin M.k → D) * W₂ := Nat.mul_le_mul_left _ hLw
          exact hsplit.trans ((Nat.add_le_add hno hyes).trans_eq (by ring))
        · rw [ite_eq_right hF]
          exact Nat.le_zero.mpr (card_eq_zero.mpr (filter_eq_empty_iff.mpr (fun s _ h => hF h.1)))
    _ = (univ.filter (fun H : Q → D => F (A₁.run H))).card * (Fintype.card (Fin M.k → D) * (2 * W₂)) := by
        rw [← sum_filter, sum_const, smul_eq_mul]

/-! ## The step from any bound on the hidden hits -/

open Classical in
/-- **One receipt, honest on `x` versus honest on `x'`, from a bound on the hidden hits** (L19's `fs_step_w`, with its
hidden-hit count `hid_card_w` as the hypothesis `hhid`): the two success probabilities differ, both ways, by at most
`Pr_H[F]·(2(W₁ + 2·Kc)/|C × D^k| + 2·W₂/|C|)`. -/
theorem fs_step_of_hid {Q D X C Out α : Type} [DecidableEq Q] [Inhabited D] [Fintype Q] [Fintype D] [Fintype C]
    [Nonempty D] [Nonempty C] (M : FSModel Q D X C Out) (A₁ : OC Q D α) (Kf : Q → ℕ) (W₁ W₂ : ℕ)
    (hA₁ : WB Kf A₁ W₁) (x x' : α → X)
    (hHV : ∀ a (v : Fin M.k → D), (PMF.uniformOfFintype C).map (fun c => M.out (x a) c v)
      = (PMF.uniformOfFintype C).map (fun c => M.out (x' a) c v))
    (Kc : ℕ)
    (hKw : ∀ x (H : Q → D) z, (univ.filter (fun s : C × (Fin M.k → D) => ∃ i, M.pts x s.1 H s.2 i = z)).card
      ≤ Kf z)
    (hKc : ∀ x (H : Q → D), (univ.filter (fun s : C × (Fin M.k → D) =>
      ¬ Function.Injective (M.pts x s.1 H s.2) ∨ ∃ i, M.pts x s.1 H s.2 i ∈ M.dep x s.1)).card ≤ Kc)
    (A₂ : α → Out → OC Q D Bool) (F : α → Prop)
    (hhid : ∀ u : α → X, (univ.filter (M.hidEv A₁ u A₂ F)).card
      ≤ (univ.filter (fun H : Q → D => F (A₁.run H))).card * (Fintype.card (Fin M.k → D) * W₂)) :
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
  -- the chain-programming step for an input choice `u` (as in L19's `fs_step_w`)
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
  obtain ⟨ux1, ux2⟩ := FSModel.unprog_count M A₁ x A₂ F
  obtain ⟨uy1, uy2⟩ := FSModel.unprog_count M A₁ x' A₂ F
  have hW := FSModel.unprog_law_eq M A₁ x x' hHV A₂ F
  have cx := FSModel.coll_card M A₁ x F Kc hKc
  have cy := FSModel.coll_card M A₁ x' F Kc hKc
  have hx := hhid x
  have hy' := hhid x'
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
    rw [FSModel.real_count_eq M A₁ u A₂ F]
    exact prob_filter _
  have hF : (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | F (A₁.run H)}
      = (NF : ℝ≥0∞) / Fintype.card (Q → D) := prob_filter _
  rw [hreal x, hreal x', hF]
  exact ⟨hconv Rx Ry hxy, hconv Ry Rx hyx⟩

open Classical in
/-- **One receipt, honest on `x` versus honest on `x'`, for a refusing prover** (finding L33-1). As L19's `fs_step_w`,
with the refusal guard `G` of `hid_card_ref` and the hidden bound `hUw` asked only where the guard does not fire; the
after-request term doubles. -/
theorem fs_step_ref {Q D X C Out α : Type} [DecidableEq Q] [Inhabited D] [Fintype Q] [Fintype D] [Fintype C]
    [Nonempty D] [Nonempty C] (M : FSModel Q D X C Out) (A₁ : OC Q D α) (Kf KUf : Q → ℕ) (W₁ W₂ : ℕ)
    (hA₁ : WB Kf A₁ W₁) (x x' : α → X)
    (hHV : ∀ a (v : Fin M.k → D), (PMF.uniformOfFintype C).map (fun c => M.out (x a) c v)
      = (PMF.uniformOfFintype C).map (fun c => M.out (x' a) c v))
    (Kc : ℕ) (G : (Fin M.k → D) → Prop) (o₀ : Out)
    (hvisG : ∀ v i, G v → ¬ M.vis v i) (hrefG : ∀ x c v, G v → M.out x c v = o₀)
    (hKw : ∀ x (H : Q → D) z, (univ.filter (fun s : C × (Fin M.k → D) => ∃ i, M.pts x s.1 H s.2 i = z)).card
      ≤ Kf z)
    (hKc : ∀ x (H : Q → D), (univ.filter (fun s : C × (Fin M.k → D) =>
      ¬ Function.Injective (M.pts x s.1 H s.2) ∨ ∃ i, M.pts x s.1 H s.2 i ∈ M.dep x s.1)).card ≤ Kc)
    (hKG : ∀ z, Kf z ≤ Fintype.card (Fin M.k → D) * KUf z)
    (hUw : ∀ x (H : Q → D) (v : Fin M.k → D), ¬ G v → ∀ (Z : Out → Finset Q) (W : ℕ),
      (∀ o, ∑ z ∈ Z o, KUf z ≤ W) →
      (univ.filter (fun c => ∃ i, ¬ M.vis v i ∧ M.pts x c H v i ∈ Z (M.out x c v))).card ≤ W)
    (A₂ : α → Out → OC Q D Bool) (hA₂ : ∀ a o, WB KUf (A₂ a o) W₂) (F : α → Prop) :
    (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x A₂ F p}
        ≤ (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x' A₂ F p}
          + (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | F (A₁.run H)}
            * ((((2 * (W₁ + 2 * Kc)) : ℕ) : ℝ≥0∞) / Fintype.card (C × (Fin M.k → D))
              + (((2 * (2 * W₂)) : ℕ) : ℝ≥0∞) / Fintype.card C)
      ∧ (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x' A₂ F p}
        ≤ (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x A₂ F p}
          + (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | F (A₁.run H)}
            * ((((2 * (W₁ + 2 * Kc)) : ℕ) : ℝ≥0∞) / Fintype.card (C × (Fin M.k → D))
              + (((2 * (2 * W₂)) : ℕ) : ℝ≥0∞) / Fintype.card C) :=
  fs_step_of_hid M A₁ Kf W₁ (2 * W₂) hA₁ x x' hHV Kc hKw hKc A₂ F
    (fun u => hid_card_ref M A₁ u A₂ F Kf KUf W₂ hA₂ G o₀ hvisG hrefG hKw hKG hUw)

/-! ## The per-receipt bound of a refusing protocol -/

open Classical in
/-- **`OneStepW` for a protocol whose prover refuses** (L19's `oneStepW_of_fsModel`, with class (B) and class (C)
refusals). Let the prover answer the constant `o₀` on every inadmissible input (`hun`), let admissibility be
preserved by the stand-in (`hstd`: it is a function of the leakage), and on ADMISSIBLE inputs let the prover be the
honest prover of a receipt model `FM` (`hP`) with a refusal guard `G` (`hvisG`, `hrefG`), the honest-verifier law
(`hHV`) and the hidden bound (`hUw`) where the guard does not fire, and the counts `hKw`, `hKc`, `hKG`. Then one receipt
on an input and on its stand-in differ, in every context of weighted budgets `(W₁, W₂)`, by at most
`2(W₁ + 2·Kc)/|C × D^k| + 2·(2·W₂)/|C|`. -/
theorem oneStepW_ref {Q D Coins : Type} [DecidableEq Q] [Inhabited D] [Fintype Q] [Fintype D] [Nonempty D]
    [Fintype Coins] [Nonempty Coins] {M : IntModel} (P : Protocol Q D Coins M) [Inhabited M.Input] (W : M.Weights)
    (adm : M.Input → Prop) (o₀ : P.Stmt × P.Receipt) (hun : ∀ H x c, ¬ adm x → P.prove H W x c = o₀)
    (hstd : ∀ x, adm (standin P W (M.publicPart (M.forward W x), P.leak x)) ↔ adm x)
    (FM : FSModel Q D {x // adm x} Coins (P.Stmt × P.Receipt))
    (hP : ∀ H (x : {x // adm x}) c, P.prove H W x.1 c = FM.prove H x c)
    (G : (Fin FM.k → D) → Prop) (hvisG : ∀ v i, G v → ¬ FM.vis v i)
    (hrefG : ∀ x c v, G v → FM.out x c v = o₀)
    (hHV : ∀ x x' : {x // adm x}, x'.1 = standin P W (M.publicPart (M.forward W x.1), P.leak x.1) →
      ∀ v : Fin FM.k → D, ¬ G v → (PMF.uniformOfFintype Coins).map (fun c => FM.out x c v)
        = (PMF.uniformOfFintype Coins).map (fun c => FM.out x' c v))
    (Kf KUf : Q → ℕ) (Kc : ℕ)
    (hKw : ∀ x (H : Q → D) z, (univ.filter (fun s : Coins × (Fin FM.k → D) =>
      ∃ i, FM.pts x s.1 H s.2 i = z)).card ≤ Kf z)
    (hKc : ∀ x (H : Q → D), (univ.filter (fun s : Coins × (Fin FM.k → D) =>
      ¬ Function.Injective (FM.pts x s.1 H s.2) ∨ ∃ i, FM.pts x s.1 H s.2 i ∈ FM.dep x s.1)).card ≤ Kc)
    (hKG : ∀ z, Kf z ≤ Fintype.card (Fin FM.k → D) * KUf z)
    (hUw : ∀ x (H : Q → D) (v : Fin FM.k → D), ¬ G v → ∀ (Z : (P.Stmt × P.Receipt) → Finset Q) (Wt : ℕ),
      (∀ o, ∑ z ∈ Z o, KUf z ≤ Wt) →
      (univ.filter (fun c => ∃ i, ¬ FM.vis v i ∧ FM.pts x c H v i ∈ Z (FM.out x c v))).card ≤ Wt) :
    OneStepW P W Kf KUf (fun W₁ W₂ => (((2 * (W₁ + 2 * Kc)) : ℕ) : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → D))
      + (((2 * (2 * W₂)) : ℕ) : ℝ≥0∞) / Fintype.card Coins) := by
  intro α A₁ W₁ hA₁ x A₂ W₂ hA₂
  by_cases hne : Nonempty {x // adm x}
  · obtain ⟨x₁⟩ := hne
    -- the inputs, made admissible (an inadmissible request is answered `o₀` in both worlds)
    obtain ⟨u, hu⟩ : ∃ u : α → {x // adm x}, ∀ a, u a = if h : adm (x a) then ⟨x a, h⟩ else x₁ :=
      ⟨_, fun _ => rfl⟩
    obtain ⟨u', hu'⟩ : ∃ u' : α → {x // adm x}, ∀ a, u' a = if h : adm (x a) then
        ⟨standin P W (M.publicPart (M.forward W (x a)), P.leak (x a)), (hstd (x a)).mpr h⟩ else x₁ :=
      ⟨_, fun _ => rfl⟩
    obtain ⟨A₂', hA₂'⟩ : ∃ A₂' : α → P.Stmt × P.Receipt → OC Q D Bool,
        ∀ a o, A₂' a o = if adm (x a) then A₂ a o else A₂ a o₀ := ⟨_, fun _ _ => rfl⟩
    have hu_pos : ∀ a (h : adm (x a)), u a = ⟨x a, h⟩ := fun a h => (hu a).trans (dite_eq_left h)
    have hu_neg : ∀ a, ¬ adm (x a) → u a = x₁ := fun a h => (hu a).trans (dite_eq_right h)
    have hu'_pos : ∀ a (h : adm (x a)), u' a
        = ⟨standin P W (M.publicPart (M.forward W (x a)), P.leak (x a)), (hstd (x a)).mpr h⟩ :=
      fun a h => (hu' a).trans (dite_eq_left h)
    have hu'_neg : ∀ a, ¬ adm (x a) → u' a = x₁ := fun a h => (hu' a).trans (dite_eq_right h)
    have hA₂W : ∀ a o, WB KUf (A₂' a o) W₂ := by
      intro a o
      rw [hA₂']
      by_cases h : adm (x a)
      · rw [ite_eq_left h]
        exact hA₂ a o
      · rw [ite_eq_right h]
        exact hA₂ a o₀
    have hHV' : ∀ a (v : Fin FM.k → D), (PMF.uniformOfFintype Coins).map (fun c => FM.out (u a) c v)
        = (PMF.uniformOfFintype Coins).map (fun c => FM.out (u' a) c v) := by
      intro a v
      by_cases h : adm (x a)
      · by_cases hg : G v
        · have e : (fun c => FM.out (u a) c v) = (fun c => FM.out (u' a) c v) :=
            funext fun c => (hrefG (u a) c v hg).trans (hrefG (u' a) c v hg).symm
          rw [e]
        · have key : ∀ y y' : {x // adm x}, y = ⟨x a, h⟩ →
              y' = ⟨standin P W (M.publicPart (M.forward W (x a)), P.leak (x a)), (hstd (x a)).mpr h⟩ →
              y'.1 = standin P W (M.publicPart (M.forward W y.1), P.leak y.1) := by
            intro y y' hy hy'
            subst hy
            subst hy'
            rfl
          exact hHV (u a) (u' a) (key _ _ (hu_pos a h) (hu'_pos a h)) v hg
      · have e : u a = u' a := (hu_neg a h).trans (hu'_neg a h).symm
        rw [e]
    have hstep := fs_step_ref FM A₁ Kf KUf W₁ W₂ hA₁ u u' hHV' Kc G o₀ hvisG hrefG hKw hKc hKG hUw A₂' hA₂W
      (fun _ => True)
    beta_reduce at hstep
    have hset : {p : (Q → D) × Coins | FM.realEv A₁ u A₂' (fun _ => True) p}
        = {p | (A₂ (A₁.run p.1) (P.prove p.1 W (x (A₁.run p.1)) p.2)).run p.1 = true} := by
      ext p
      show (True ∧ (A₂' (A₁.run p.1) (FM.prove p.1 (u (A₁.run p.1)) p.2)).run p.1 = true)
        ↔ (A₂ (A₁.run p.1) (P.prove p.1 W (x (A₁.run p.1)) p.2)).run p.1 = true
      rw [true_and]
      by_cases h : adm (x (A₁.run p.1))
      · have key : ∀ y : {x // adm x}, y = ⟨x (A₁.run p.1), h⟩ →
            FM.prove p.1 y p.2 = P.prove p.1 W (x (A₁.run p.1)) p.2 := by
          intro y hy
          subst hy
          exact (hP p.1 _ p.2).symm
        rw [hA₂', ite_eq_left h, key _ (hu_pos _ h)]
      · rw [hA₂', ite_eq_right h, hun p.1 (x (A₁.run p.1)) p.2 h]
    have hset' : {p : (Q → D) × Coins | FM.realEv A₁ u' A₂' (fun _ => True) p}
        = {p | (A₂ (A₁.run p.1) (P.prove p.1 W (standin P W (M.publicPart (M.forward W (x (A₁.run p.1))),
            P.leak (x (A₁.run p.1)))) p.2)).run p.1 = true} := by
      ext p
      show (True ∧ (A₂' (A₁.run p.1) (FM.prove p.1 (u' (A₁.run p.1)) p.2)).run p.1 = true)
        ↔ (A₂ (A₁.run p.1) (P.prove p.1 W (standin P W (M.publicPart (M.forward W (x (A₁.run p.1))),
            P.leak (x (A₁.run p.1)))) p.2)).run p.1 = true
      rw [true_and]
      by_cases h : adm (x (A₁.run p.1))
      · have key : ∀ y : {x // adm x},
            y = ⟨standin P W (M.publicPart (M.forward W (x (A₁.run p.1))), P.leak (x (A₁.run p.1))),
              (hstd (x (A₁.run p.1))).mpr h⟩ →
            FM.prove p.1 y p.2 = P.prove p.1 W (standin P W (M.publicPart (M.forward W (x (A₁.run p.1))),
              P.leak (x (A₁.run p.1)))) p.2 := by
          intro y hy
          subst hy
          exact (hP p.1 _ p.2).symm
        rw [hA₂', ite_eq_left h, key _ (hu'_pos _ h)]
      · have h' :¬ adm (standin P W (M.publicPart (M.forward W (x (A₁.run p.1))), P.leak (x (A₁.run p.1)))) :=
          fun hs => h ((hstd (x (A₁.run p.1))).mp hs)
        rw [hA₂', ite_eq_right h, hun p.1 _ p.2 h']
    have hone : (PMF.uniformOfFintype (Q → D)).toOuterMeasure {_H : Q → D | True} = 1 :=
      (PMF.toOuterMeasure_apply_eq_one_iff _ _).mpr (fun _ _ => trivial)
    rw [hset, hset', hone] at hstep
    simp only [one_mul] at hstep
    exact hstep
  · -- no admissible input at all: both worlds answer `o₀`
    have hall : ∀ y, ¬ adm y := fun y hy => hne ⟨⟨y, hy⟩⟩
    have e : ∀ p : (Q → D) × Coins, P.prove p.1 W (x (A₁.run p.1)) p.2
        = P.prove p.1 W (standin P W (M.publicPart (M.forward W (x (A₁.run p.1))), P.leak (x (A₁.run p.1)))) p.2 :=
      fun p => (hun p.1 _ p.2 (hall _)).trans (hun p.1 _ p.2 (hall _)).symm
    have eset : {p : (Q → D) × Coins | (A₂ (A₁.run p.1) (P.prove p.1 W (x (A₁.run p.1)) p.2)).run p.1 = true}
        = {p | (A₂ (A₁.run p.1) (P.prove p.1 W (standin P W (M.publicPart (M.forward W (x (A₁.run p.1))),
            P.leak (x (A₁.run p.1)))) p.2)).run p.1 = true} := by
      ext p
      show (A₂ (A₁.run p.1) (P.prove p.1 W (x (A₁.run p.1)) p.2)).run p.1 = true
        ↔ (A₂ (A₁.run p.1) (P.prove p.1 W (standin P W (M.publicPart (M.forward W (x (A₁.run p.1))),
            P.leak (x (A₁.run p.1)))) p.2)).run p.1 = true
      rw [e p]
    rw [eset]
    exact ⟨le_self_add, le_self_add⟩

/-! ## Zero knowledge from a receipt model with a refusal guard -/

open Classical in
/-- **Zero knowledge of a refusing protocol** (D63 Statement 2; L19's `zk_every_R` without its budget, for a prover with
class (B) and class (C) refusals). Per weight set `W`: the prover answers `o₀ W` on every inadmissible input and the
stand-in preserves admissibility; on admissible inputs it is the honest prover of a receipt model `FM W` with a refusal
guard `G W`; the prover is also a `qp`-question computation `pOC` within the weighted budgets `Wp W` and `Wpa W`; the
counts are as in `oneStepW_ref`. If the rates are as stated (the two after-request rates carry the factor `2` of the
guard), the protocol is zero knowledge with the stand-in simulator and error `Σ_{j<R} wStep δp ωp δh ωh εc q R j`. -/
theorem zk_of_refModel {Q D Coins : Type} [DecidableEq Q] [Inhabited D] [Fintype Q] [Fintype D] [Nonempty D]
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins] {M : IntModel} {P : Protocol Q D Coins M} [Inhabited M.Input]
    (pOC : M.Weights → M.Input → Coins → OC Q D (P.Stmt × P.Receipt)) (qp : ℕ)
    (hrun : ∀ W H x c, (pOC W x c).run H = P.prove H W x c) (hbd : ∀ W x c, (pOC W x c).Bounded qp)
    (adm : M.Weights → M.Input → Prop) (o₀ : M.Weights → P.Stmt × P.Receipt)
    (hun : ∀ W H x c, ¬ adm W x → P.prove H W x c = o₀ W)
    (hstd : ∀ W x, adm W (standin P W (M.publicPart (M.forward W x), P.leak x)) ↔ adm W x)
    (FM : (W : M.Weights) → FSModel Q D {x // adm W x} Coins (P.Stmt × P.Receipt))
    (hP : ∀ W H (x : {x // adm W x}) c, P.prove H W x.1 c = (FM W).prove H x c)
    (G : (W : M.Weights) → (Fin (FM W).k → D) → Prop) (hvisG : ∀ W v i, G W v → ¬ (FM W).vis v i)
    (hrefG : ∀ W x c v, G W v → (FM W).out x c v = o₀ W)
    (hHV : ∀ W (x x' : {x // adm W x}), x'.1 = standin P W (M.publicPart (M.forward W x.1), P.leak x.1) →
      ∀ v : Fin (FM W).k → D, ¬ G W v → (PMF.uniformOfFintype Coins).map (fun c => (FM W).out x c v)
        = (PMF.uniformOfFintype Coins).map (fun c => (FM W).out x' c v))
    (Kf KUf : M.Weights → Q → ℕ) (Km KUm Wp Wpa Kc : M.Weights → ℕ)
    (hKm : ∀ W z, Kf W z ≤ Km W) (hKUm : ∀ W z, KUf W z ≤ KUm W)
    (hwb : ∀ W x c, WB (Kf W) (pOC W x c) (Wp W)) (hwba : ∀ W x c, WB (KUf W) (pOC W x c) (Wpa W))
    (hKw : ∀ W x (H : Q → D) z, (univ.filter (fun s : Coins × (Fin (FM W).k → D) =>
      ∃ i, (FM W).pts x s.1 H s.2 i = z)).card ≤ Kf W z)
    (hKc : ∀ W x (H : Q → D), (univ.filter (fun s : Coins × (Fin (FM W).k → D) =>
      ¬ Function.Injective ((FM W).pts x s.1 H s.2) ∨ ∃ i, (FM W).pts x s.1 H s.2 i ∈ (FM W).dep x s.1)).card
        ≤ Kc W)
    (hKG : ∀ W z, Kf W z ≤ Fintype.card (Fin (FM W).k → D) * KUf W z)
    (hUw : ∀ W x (H : Q → D) (v : Fin (FM W).k → D), ¬ G W v →
      ∀ (Z : (P.Stmt × P.Receipt) → Finset Q) (Wt : ℕ), (∀ o, ∑ z ∈ Z o, KUf W z ≤ Wt) →
      (univ.filter (fun c => ∃ i, ¬ (FM W).vis v i ∧ (FM W).pts x c H v i ∈ Z ((FM W).out x c v))).card ≤ Wt)
    (δp ωp δh ωh εc : ℝ≥0∞)
    (hrδp : ∀ W, (Km W : ℝ≥0∞) / Fintype.card (Coins × (Fin (FM W).k → D)) ≤ δp)
    (hrωp : ∀ W, (Wp W : ℝ≥0∞) / Fintype.card (Coins × (Fin (FM W).k → D)) ≤ ωp)
    (hrεc : ∀ W, (Kc W : ℝ≥0∞) / Fintype.card (Coins × (Fin (FM W).k → D)) ≤ εc)
    (hrδh : ∀ W, ((2 * KUm W : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ δh)
    (hrωh : ∀ W, ((2 * Wpa W : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ ωh) :
    ZeroKnowledge M P (fun q R => ∑ j ∈ range R, wStep δp ωp δh ωh εc q R j) := by
  refine zeroKnowledge_of_oneStepW pOC qp hrun hbd Kf KUf Km KUm Wp Wpa hKm hKUm hwb hwba
    (fun W W₁ W₂ => (((2 * (W₁ + 2 * Kc W)) : ℕ) : ℝ≥0∞) / Fintype.card (Coins × (Fin (FM W).k → D))
      + (((2 * (2 * W₂)) : ℕ) : ℝ≥0∞) / Fintype.card Coins)
    (fun W => oneStepW_ref P W (adm W) (o₀ W) (hun W) (hstd W) (FM W) (hP W) (G W) (hvisG W) (hrefG W) (hHV W)
      (Kf W) (KUf W) (Kc W) (hKw W) (hKc W) (hKG W) (hUw W))
    (fun q R j => wStep δp ωp δh ωh εc q R j) (fun W q R j _ => ?_)
  have e : 2 * (2 * (q * KUm W + R * Wpa W)) = 2 * (q * (2 * KUm W) + R * (2 * Wpa W)) := by ring
  show (((2 * ((q * Km W + j * Wp W) + 2 * Kc W)) : ℕ) : ℝ≥0∞) / Fintype.card (Coins × (Fin (FM W).k → D))
      + (((2 * (2 * (q * KUm W + R * Wpa W))) : ℕ) : ℝ≥0∞) / Fintype.card Coins
    ≤ wStep δp ωp δh ωh εc q R j
  rw [e]
  exact fsStepW_le_wStep q R j (Km W) (Wp W) (Kc W) (2 * KUm W) (2 * Wpa W) _ _ δp ωp δh ωh εc
    (hrδp W) (hrωp W) (hrεc W) (hrδh W) (hrωh W)

/-- **Within the approved target up to a receipt cap** (L19's `ZKKinds.cap_R`, the form `RunK.cap_112` instantiates):
for a receipt's counts by kind `Z` with `mT ≤ 2^a`, `qpT·mT ≤ 2^b`, the other counts at most `2^c` with `2c + 252` bits
of column freshness, `pts ≤ 2^p`, and `r + b ≤ 133`, `a + r + 132 ≤ 256`, `r ≤ 120`: zero knowledge of the refusing
protocol whose rates are `Z`'s, with an error within `εzkTarget q R` for every `q` and every `R ≤ 2^r`. -/
theorem zk_ref_cap {Q D Coins : Type} [DecidableEq Q] [Fintype Q] [Fintype D] [Nonempty D]
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins] {M : IntModel} {P : Protocol Q D Coins M}
    (Z : ZKKinds) (hzk : ZeroKnowledge M P (fun q R => ∑ j ∈ range R, wStep Z.δp Z.ωp Z.δh Z.ωh Z.εc q R j))
    (c p a b r : ℕ) (hm : Z.mT ≤ 2 ^ a) (hb : Z.qpT * Z.mT ≤ 2 ^ b) (hb13 : 13 ≤ b)
    (hC : Z.cols ≤ 2 ^ c) (hLN : Z.leaves + Z.nodes ≤ 2 ^ c)
    (hqC : Z.qpC ≤ 2 ^ c) (hqL : Z.qpL ≤ 2 ^ c) (hqN : Z.qpN ≤ 2 ^ c)
    (hcol : 2 * c + 252 ≤ Z.hcol) (hcond : 2 * c + 252 ≤ Z.hcond) (h512 : 2 * c + 252 ≤ 512)
    (hp : Z.pts ≤ 2 ^ p) (hp' : 2 * p + 124 ≤ 256) (hrb : r + b ≤ 133) (har : a + r + 132 ≤ 256) (hr : r ≤ 120) :
    ZeroKnowledge M P (fun q R => ∑ j ∈ range R, wStep Z.δp Z.ωp Z.δh Z.ωh Z.εc q R j)
      ∧ ∀ q R, R ≤ 2 ^ r → ∑ j ∈ range R, wStep Z.δp Z.ωp Z.δh Z.ωh Z.εc q R j ≤ εzkTarget q R :=
  ⟨hzk, fun q R hR => ZKKinds.cap_R Z c p a b r hm hb hb13 hC hLN hqC hqL hqN hcol hcond h512 hp hp' hrb har hr q R hR⟩

end ZK60.ZKHonest
