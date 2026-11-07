/-
D63 step L14 (Statement 2, zero knowledge), part 2: ONE Fiat–Shamir receipt, honest on `x` versus honest on a stand-in
`x'`, in the random-oracle model, for any distinguisher context.

The receipt model (`FSModel`). A receipt is computed from the input `x`, the prover's coins `c` and the values `v` the
oracle returns at `k` PROGRAMMED-KIND points `pts x c H v` (the salted leaves, the Merkle nodes, the transcript's
absorbs and squeezes; `ZKW16Prog.lean`): `prove H x c = out x c (chainVals (pts x c H) H)`. The points are causal in
the values and may read the oracle at a dependency set `dep` (the column hashes, the public header's chain points). A
point is VISIBLE when the receipt
determines it (`vis v i`, `vp`: an opened column's leaf, every node, every transcript point); the others are HIDDEN
(the leaves of the unopened columns, whose salts the receipt never shows).

The context is the hybrid's: `A₁` (everything before the request: a query-bounded computation choosing the input),
`A₂` (the receipt and everything after), and a flag `F` of `A₁`'s result.

* `progVis`, `progVis_agree`: the oracle programmed at the VISIBLE points only, a function of the receipt, `H` and the
  values; it agrees with the fully programmed oracle except at hidden points (when the points are distinct).
* `unprog_count` (Lemma U): un-programming the hidden points costs at most the collisions and the probability that
  `A₂` asks a hidden point (`hU`: for any query set computed from the receipt, few coins put a hidden point in it).
* `unprog_law_eq` (Lemma W): in the visible-only world the success depends on the coins only through the receipt, so
  an honest-verifier law equality at every value vector (`hHV`, the composed L4 lemmas, `ZKW16View.lean`) makes the
  inputs `x` and `x'` give EXACTLY the same success.
* **`fs_step`**: honest on `x` versus honest on `x'` (any `x'` with `Rel x x'`, the same public data): in both
  directions at most `Pr_H[F]·(2(q₁·K + 2·Kc)/|C × D^k| + 2·q₂·KU/|C|)`. The two `K`-terms are the chain programming of
  `ZKW16Prog.lean` (before the request), the `KU`-term is the hidden points (after it).

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.ZKW16Prog

namespace ZK60.ZKW16

open scoped ENNReal
open Finset

/-! ## Two counting facts -/

/-- A count on a product, summed over the SECOND component's fibres. -/
theorem card_filter_prod_right {β γ : Type} [Fintype β] [Fintype γ] (p : β × γ → Prop) [DecidablePred p] :
    (univ.filter p).card = ∑ c : γ, (univ.filter (fun b : β => p (b, c))).card := by
  rw [card_filter, Fintype.sum_prod_type_right]
  refine sum_congr rfl (fun c _ => ?_)
  rw [card_filter]

/-- **Equal laws, equal counts**: two maps with the same law under the uniform coins put the same number of coins in
every set. -/
theorem card_preimage_eq_of_map_eq {C O : Type} [Fintype C] [Nonempty C] {f g : C → O}
    (h : (PMF.uniformOfFintype C).map f = (PMF.uniformOfFintype C).map g) (S : Set O) [DecidablePred (· ∈ S)] :
    (univ.filter (fun c => f c ∈ S)).card = (univ.filter (fun c => g c ∈ S)).card := by
  classical
  have e : ∀ u : C → O, ((PMF.uniformOfFintype C).map u).toOuterMeasure S
      = ((univ.filter (fun c => u c ∈ S)).card : ℝ≥0∞) / Fintype.card C := by
    intro u
    rw [PMF.toOuterMeasure_map_apply]
    exact prob_filter (fun c => u c ∈ S)
  have h2 := e f
  rw [h, e g] at h2
  have hC0 : (Fintype.card C : ℝ≥0∞) ≠ 0 := by simp
  have hCt : (Fintype.card C : ℝ≥0∞) ≠ ∞ := ENNReal.natCast_ne_top _
  have h3 : ((univ.filter (fun c => g c ∈ S)).card : ℝ≥0∞) = (univ.filter (fun c => f c ∈ S)).card := by
    have h4 := congrArg (fun t => t * (Fintype.card C : ℝ≥0∞)) h2
    simpa only [ENNReal.div_mul_cancel hC0 hCt] using h4
  exact_mod_cast h3.symm

/-- **Equal laws, equal counts, any presentation**: if `p c ↔ E (f c)` and `p' c ↔ E (g c)`, the two counts agree
(the decidability instances are the caller's). -/
theorem card_eq_of_map_eq {C O : Type} [Fintype C] [Nonempty C] {f g : C → O}
    (h : (PMF.uniformOfFintype C).map f = (PMF.uniformOfFintype C).map g) (E : O → Prop)
    {p p' : C → Prop} {ip : DecidablePred p} {ip' : DecidablePred p'}
    (hp : ∀ c, p c ↔ E (f c)) (hp' : ∀ c, p' c ↔ E (g c)) :
    (univ.filter p).card = (univ.filter p').card := by
  classical
  have h1 := card_preimage_eq_of_map_eq h {o | E o}
  have e1 : univ.filter p = univ.filter (fun c => f c ∈ {o | E o}) := filter_congr (fun c _ => hp c)
  have e2 : univ.filter p' = univ.filter (fun c => g c ∈ {o | E o}) := filter_congr (fun c _ => hp' c)
  rw [e1, e2]
  convert h1 using 3

/-! ## The receipt model -/

/-- **A Fiat–Shamir receipt model** (see the header). -/
structure FSModel (Q D X C Out : Type) where
  /-- the number of programmed-kind points of one receipt -/
  k : ℕ
  /-- the points of the oracle the points read (the column hashes, the public header's chain points) -/
  dep : X → C → Set Q
  /-- the points, from the input, the coins, the oracle (at `dep`) and the values so far -/
  pts : X → C → (Q → D) → (Fin k → D) → Fin k → Q
  /-- the receipt, from the input, the coins and the values -/
  out : X → C → (Fin k → D) → Out
  /-- the visible points (an opened column's leaf, the nodes, the transcript), as a function of the values -/
  vis : (Fin k → D) → Fin k → Prop
  /-- the visible points, read off the receipt -/
  vp : Out → (Q → D) → (Fin k → D) → Fin k → Q
  causal : ∀ x c H, Causal (pts x c H)
  sep : ∀ x c (H H' : Q → D) v, (∀ z ∈ dep x c, H z = H' z) → pts x c H v = pts x c H' v
  vis_pts : ∀ x c H v i, vis v i → pts x c H v i = vp (out x c v) H v i

namespace FSModel

variable {Q D X C Out : Type} [DecidableEq Q] [Inhabited D]

/-- **The honest prover of the model**: ask the oracle at every point in order. -/
def prove (M : FSModel Q D X C Out) (H : Q → D) (x : X) (c : C) : Out :=
  M.out x c (chainVals (M.pts x c H) H)

open Classical in
/-- The oracle programmed at the VISIBLE points only: a function of the receipt, the oracle and the values. -/
noncomputable def progVis (M : FSModel Q D X C Out) (o : Out) (H : Q → D) (v : Fin M.k → D) (z : Q) : D :=
  if h : ∃ i, M.vis v i ∧ M.vp o H v i = z then v h.choose else H z

omit [Inhabited D] in
/-- **Away from the hidden points the two programmed oracles agree** (the points being distinct). -/
theorem progVis_agree (M : FSModel Q D X C Out) (x : X) (c : C) (H : Q → D) (v : Fin M.k → D)
    (hinj : Function.Injective (M.pts x c H v)) (z : Q) (hz : ∀ i, ¬ M.vis v i → M.pts x c H v i ≠ z) :
    M.progVis (M.out x c v) H v z = ZKHybrid.program (M.pts x c H v) v H z := by
  classical
  unfold progVis
  by_cases hr : ∃ i, M.pts x c H v i = z
  · obtain ⟨i, rfl⟩ := hr
    have hvi : M.vis v i := by
      by_contra hn
      exact hz i hn rfl
    have hex : ∃ i', M.vis v i' ∧ M.vp (M.out x c v) H v i' = M.pts x c H v i :=
      ⟨i, hvi, (M.vis_pts x c H v i hvi).symm⟩
    rw [dite_eq_left hex, ZKHybrid.program_at hinj]
    have hs := hex.choose_spec
    congr 1
    apply hinj
    rw [M.vis_pts x c H v _ hs.1]
    exact hs.2
  · have hr' : ∀ i, M.pts x c H v i ≠ z := fun i hi => hr ⟨i, hi⟩
    have hex : ¬ ∃ i', M.vis v i' ∧ M.vp (M.out x c v) H v i' = z := by
      rintro ⟨i', hv', he⟩
      exact hr' i' ((M.vis_pts x c H v i' hv').trans he)
    rw [dite_eq_right hex, ZKHybrid.program_off _ _ _ z hr']

/-! ### The worlds of one receipt, on `(H, (c, v))` -/

variable {α : Type}

/-- The programmed world (`apIdeal` of `ZKW16Prog.lean` for this receipt). -/
def progEv (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x : α → X) (A₂ : α → Out → OC Q D Bool) (F : α → Prop)
    (ω : (Q → D) × (C × (Fin M.k → D))) : Prop :=
  F (A₁.run ω.1) ∧ (A₂ (A₁.run ω.1) (M.out (x (A₁.run ω.1)) ω.2.1 ω.2.2)).run
    (ZKHybrid.program (M.pts (x (A₁.run ω.1)) ω.2.1 ω.1 ω.2.2) ω.2.2 ω.1) = true

/-- The visible-only world: the hidden points are not programmed. -/
def unprogEv (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x : α → X) (A₂ : α → Out → OC Q D Bool) (F : α → Prop)
    (ω : (Q → D) × (C × (Fin M.k → D))) : Prop :=
  F (A₁.run ω.1) ∧ (A₂ (A₁.run ω.1) (M.out (x (A₁.run ω.1)) ω.2.1 ω.2.2)).run
    (M.progVis (M.out (x (A₁.run ω.1)) ω.2.1 ω.2.2) ω.1 ω.2.2) = true

/-- Two points collide, or one lands in the dependency set. -/
def collEv (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x : α → X) (F : α → Prop)
    (ω : (Q → D) × (C × (Fin M.k → D))) : Prop :=
  F (A₁.run ω.1) ∧ (¬ Function.Injective (M.pts (x (A₁.run ω.1)) ω.2.1 ω.1 ω.2.2)
    ∨ ∃ i, M.pts (x (A₁.run ω.1)) ω.2.1 ω.1 ω.2.2 i ∈ M.dep (x (A₁.run ω.1)) ω.2.1)

/-- In the visible-only world, `A₂` asks a hidden point. -/
def hidEv (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x : α → X) (A₂ : α → Out → OC Q D Bool) (F : α → Prop)
    (ω : (Q → D) × (C × (Fin M.k → D))) : Prop :=
  F (A₁.run ω.1) ∧ ∃ z ∈ OC.queries (M.progVis (M.out (x (A₁.run ω.1)) ω.2.1 ω.2.2) ω.1 ω.2.2)
      (A₂ (A₁.run ω.1) (M.out (x (A₁.run ω.1)) ω.2.1 ω.2.2)),
    ∃ i, ¬ M.vis ω.2.2 i ∧ M.pts (x (A₁.run ω.1)) ω.2.1 ω.1 ω.2.2 i = z

variable [Fintype Q] [Fintype D] [Fintype C]

omit [Inhabited D] in
open Classical in
/-- **Lemma U, counted**: the programmed and the visible-only worlds differ by at most the collisions and the hidden
hits. -/
theorem unprog_count (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x : α → X) (A₂ : α → Out → OC Q D Bool)
    (F : α → Prop) :
    (univ.filter (M.progEv A₁ x A₂ F)).card
        ≤ (univ.filter (M.unprogEv A₁ x A₂ F)).card + (univ.filter (M.collEv A₁ x F)).card
          + (univ.filter (M.hidEv A₁ x A₂ F)).card
      ∧ (univ.filter (M.unprogEv A₁ x A₂ F)).card
        ≤ (univ.filter (M.progEv A₁ x A₂ F)).card + (univ.filter (M.collEv A₁ x F)).card
          + (univ.filter (M.hidEv A₁ x A₂ F)).card := by
  classical
  have hrun : ∀ ω : (Q → D) × (C × (Fin M.k → D)), F (A₁.run ω.1) → ¬ M.collEv A₁ x F ω →
      ¬ M.hidEv A₁ x A₂ F ω →
      (A₂ (A₁.run ω.1) (M.out (x (A₁.run ω.1)) ω.2.1 ω.2.2)).run
          (M.progVis (M.out (x (A₁.run ω.1)) ω.2.1 ω.2.2) ω.1 ω.2.2)
        = (A₂ (A₁.run ω.1) (M.out (x (A₁.run ω.1)) ω.2.1 ω.2.2)).run
          (ZKHybrid.program (M.pts (x (A₁.run ω.1)) ω.2.1 ω.1 ω.2.2) ω.2.2 ω.1) := by
    intro ω hF hc hh
    have hinj : Function.Injective (M.pts (x (A₁.run ω.1)) ω.2.1 ω.1 ω.2.2) := by
      by_contra hn
      exact hc ⟨hF, Or.inl hn⟩
    refine OC.run_eq_of_agree _ (fun z hz => M.progVis_agree _ _ _ _ hinj z (fun i hi hpi => hh ⟨hF, z, hz, i, hi, hpi⟩))
  constructor
  · refine (card_le_card (s := univ.filter (M.progEv A₁ x A₂ F))
      (t := (univ.filter (M.unprogEv A₁ x A₂ F) ∪ univ.filter (M.collEv A₁ x F)) ∪ univ.filter (M.hidEv A₁ x A₂ F))
      ?_).trans ((card_union_le _ _).trans (Nat.add_le_add_right (card_union_le _ _) _))
    intro ω hω
    simp only [mem_filter, mem_univ, true_and, mem_union] at hω ⊢
    by_cases hc : M.collEv A₁ x F ω
    · exact Or.inl (Or.inr hc)
    · by_cases hh : M.hidEv A₁ x A₂ F ω
      · exact Or.inr hh
      · refine Or.inl (Or.inl ⟨hω.1, ?_⟩)
        rw [hrun ω hω.1 hc hh]
        exact hω.2
  · refine (card_le_card (s := univ.filter (M.unprogEv A₁ x A₂ F))
      (t := (univ.filter (M.progEv A₁ x A₂ F) ∪ univ.filter (M.collEv A₁ x F)) ∪ univ.filter (M.hidEv A₁ x A₂ F))
      ?_).trans ((card_union_le _ _).trans (Nat.add_le_add_right (card_union_le _ _) _))
    intro ω hω
    simp only [mem_filter, mem_univ, true_and, mem_union] at hω ⊢
    by_cases hc : M.collEv A₁ x F ω
    · exact Or.inl (Or.inr hc)
    · by_cases hh : M.hidEv A₁ x A₂ F ω
      · exact Or.inr hh
      · refine Or.inl (Or.inl ⟨hω.1, ?_⟩)
        rw [← hrun ω hω.1 hc hh]
        exact hω.2

omit [Inhabited D] in
open Classical in
/-- **Lemma W, counted**: in the visible-only world the success depends on the coins only through the receipt, so an
honest-verifier law equality of the receipts at every value vector gives the same count for `x` and `x'`. -/
theorem unprog_law_eq [Nonempty C] (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x x' : α → X)
    (hHV : ∀ a (v : Fin M.k → D), (PMF.uniformOfFintype C).map (fun c => M.out (x a) c v)
      = (PMF.uniformOfFintype C).map (fun c => M.out (x' a) c v))
    (A₂ : α → Out → OC Q D Bool) (F : α → Prop) :
    (univ.filter (M.unprogEv A₁ x A₂ F)).card = (univ.filter (M.unprogEv A₁ x' A₂ F)).card := by
  classical
  rw [card_filter_prod, card_filter_prod]
  refine sum_congr rfl (fun H _ => ?_)
  rw [card_filter_prod_right, card_filter_prod_right]
  refine sum_congr rfl (fun v _ => ?_)
  exact card_eq_of_map_eq (hHV (A₁.run H) v)
    (fun o => F (A₁.run H) ∧ (A₂ (A₁.run H) o).run (M.progVis o H v) = true) (fun _ => Iff.rfl) (fun _ => Iff.rfl)

omit [Inhabited D] in
open Classical in
/-- The collisions, counted fibre by fibre. -/
theorem coll_card (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x : α → X) (F : α → Prop) (Kc : ℕ)
    (hKc : ∀ x (H : Q → D), (univ.filter (fun s : C × (Fin M.k → D) =>
      ¬ Function.Injective (M.pts x s.1 H s.2) ∨ ∃ i, M.pts x s.1 H s.2 i ∈ M.dep x s.1)).card ≤ Kc) :
    (univ.filter (M.collEv A₁ x F)).card ≤ (univ.filter (fun H : Q → D => F (A₁.run H))).card * Kc := by
  classical
  rw [card_filter_prod]
  calc ∑ H : Q → D, (univ.filter (fun s : C × (Fin M.k → D) => M.collEv A₁ x F (H, s))).card
      ≤ ∑ H : Q → D, (if F (A₁.run H) then Kc else 0) := by
        refine sum_le_sum (fun H _ => ?_)
        by_cases hF : F (A₁.run H)
        · rw [ite_eq_left hF]
          have hsub : univ.filter (fun s : C × (Fin M.k → D) => M.collEv A₁ x F (H, s))
              ⊆ univ.filter (fun s : C × (Fin M.k → D) => ¬ Function.Injective (M.pts (x (A₁.run H)) s.1 H s.2)
                ∨ ∃ i, M.pts (x (A₁.run H)) s.1 H s.2 i ∈ M.dep (x (A₁.run H)) s.1) := by
            intro s hs
            exact mem_filter.mpr ⟨mem_univ _, (mem_filter.mp hs).2.2⟩
          exact (card_le_card hsub).trans (hKc (x (A₁.run H)) H)
        · rw [ite_eq_right hF]
          exact Nat.le_zero.mpr (card_eq_zero.mpr (filter_eq_empty_iff.mpr (fun s _ h => hF h.1)))
    _ = (univ.filter (fun H : Q → D => F (A₁.run H))).card * Kc := by
        rw [← sum_filter, sum_const, smul_eq_mul]

omit [Inhabited D] in
open Classical in
/-- The hidden hits, counted fibre by fibre: for each oracle and value vector, `hU` bounds the coins. -/
theorem hid_card (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x : α → X) (A₂ : α → Out → OC Q D Bool)
    (F : α → Prop) (q₂ : ℕ) (hA₂ : ∀ a o, (A₂ a o).Bounded q₂) (KU : ℕ)
    (hU : ∀ x (H : Q → D) (v : Fin M.k → D) (Z : Out → Finset Q), (∀ o, (Z o).card ≤ q₂) →
      (univ.filter (fun c => ∃ i, ¬ M.vis v i ∧ M.pts x c H v i ∈ Z (M.out x c v))).card ≤ q₂ * KU) :
    (univ.filter (M.hidEv A₁ x A₂ F)).card
      ≤ (univ.filter (fun H : Q → D => F (A₁.run H))).card * (Fintype.card (Fin M.k → D) * (q₂ * KU)) := by
  classical
  rw [card_filter_prod]
  calc ∑ H : Q → D, (univ.filter (fun s : C × (Fin M.k → D) => M.hidEv A₁ x A₂ F (H, s))).card
      ≤ ∑ H : Q → D, (if F (A₁.run H) then Fintype.card (Fin M.k → D) * (q₂ * KU) else 0) := by
        refine sum_le_sum (fun H _ => ?_)
        by_cases hF : F (A₁.run H)
        · rw [ite_eq_left hF, card_filter_prod_right]
          calc ∑ v : Fin M.k → D, (univ.filter (fun c : C => M.hidEv A₁ x A₂ F (H, (c, v)))).card
              ≤ ∑ _v : Fin M.k → D, q₂ * KU := by
                refine sum_le_sum (fun v _ => ?_)
                let Z : Out → Finset Q := fun o =>
                  (OC.queries (M.progVis o H v) (A₂ (A₁.run H) o)).toFinset
                have hZ : ∀ o, (Z o).card ≤ q₂ := fun o =>
                  (List.toFinset_card_le _).trans (OC.length_queries_le _ _ q₂ (hA₂ _ o))
                have hsub : univ.filter (fun c : C => M.hidEv A₁ x A₂ F (H, (c, v)))
                    ⊆ univ.filter (fun c : C => ∃ i, ¬ M.vis v i
                      ∧ M.pts (x (A₁.run H)) c H v i ∈ Z (M.out (x (A₁.run H)) c v)) := by
                  intro c hc
                  obtain ⟨-, z, hz, i, hi, hpi⟩ := (mem_filter.mp hc).2
                  exact mem_filter.mpr ⟨mem_univ _, i, hi, by rw [hpi]; exact List.mem_toFinset.mpr hz⟩
                exact (card_le_card hsub).trans (hU (x (A₁.run H)) H v Z hZ)
            _ = Fintype.card (Fin M.k → D) * (q₂ * KU) := by rw [sum_const, card_univ, smul_eq_mul]
        · rw [ite_eq_right hF]
          exact Nat.le_zero.mpr (card_eq_zero.mpr (filter_eq_empty_iff.mpr (fun s _ h => hF h.1)))
    _ = (univ.filter (fun H : Q → D => F (A₁.run H))).card * (Fintype.card (Fin M.k → D) * (q₂ * KU)) := by
        rw [← sum_filter, sum_const, smul_eq_mul]

/-! ### The step -/

/-- The honest world of one receipt on `(H, c)`. -/
def realEv (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x : α → X) (A₂ : α → Out → OC Q D Bool) (F : α → Prop)
    (p : (Q → D) × C) : Prop :=
  F (A₁.run p.1) ∧ (A₂ (A₁.run p.1) (M.prove p.1 (x (A₁.run p.1)) p.2)).run p.1 = true

/-- The honest world, counted on the space with the (unused) values. -/
theorem real_count_eq [Nonempty D] [Nonempty C] (M : FSModel Q D X C Out) (A₁ : OC Q D α) (x : α → X)
    (A₂ : α → Out → OC Q D Bool) (F : α → Prop) :
    (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x A₂ F p}
      = (PMF.uniformOfFintype ((Q → D) × (C × (Fin M.k → D)))).toOuterMeasure
          {ω | F (A₁.run ω.1) ∧ apReal (fun a c H v => M.pts (x a) c H v) A₁
            (fun a c v => A₂ a (M.out (x a) c v)) ω} :=
  (apReal_marginal (y := fun a c H v => M.pts (x a) c H v) (fun a c v => A₂ a (M.out (x a) c v)) F).symm

open Classical in
/-- **One receipt, honest on `x` versus honest on `x'`** (the per-receipt step of a stand-in simulator). In the
context of the hybrid (`A₁` before the request with at most `q₁` queries, choosing `x` and `x'`; `A₂` after it with at
most `q₂`; a flag `F` of `A₁`'s result), if the receipts have the same honest-verifier law at every value vector
(`hHV`), one query is hit by some point for at most `K` of the `(c, v)` (`hK`), two points collide for at most `Kc`
(`hKc`), and a query set read off the receipt catches a hidden point for at most `q₂·KU` coins (`hU`), then the two
success probabilities differ, in both directions, by at most
`Pr_H[F]·(2(q₁·K + 2·Kc)/|C × D^k| + 2·q₂·KU/|C|)`. -/
theorem fs_step [Nonempty D] [Nonempty C] (M : FSModel Q D X C Out) (A₁ : OC Q D α) (q₁ : ℕ)
    (hA₁ : A₁.Bounded q₁) (x x' : α → X)
    (hHV : ∀ a (v : Fin M.k → D), (PMF.uniformOfFintype C).map (fun c => M.out (x a) c v)
      = (PMF.uniformOfFintype C).map (fun c => M.out (x' a) c v))
    (K Kc KU q₂ : ℕ)
    (hK : ∀ x (H : Q → D) z, (univ.filter (fun s : C × (Fin M.k → D) => ∃ i, M.pts x s.1 H s.2 i = z)).card ≤ K)
    (hKc : ∀ x (H : Q → D), (univ.filter (fun s : C × (Fin M.k → D) =>
      ¬ Function.Injective (M.pts x s.1 H s.2) ∨ ∃ i, M.pts x s.1 H s.2 i ∈ M.dep x s.1)).card ≤ Kc)
    (hU : ∀ x (H : Q → D) (v : Fin M.k → D) (Z : Out → Finset Q), (∀ o, (Z o).card ≤ q₂) →
      (univ.filter (fun c => ∃ i, ¬ M.vis v i ∧ M.pts x c H v i ∈ Z (M.out x c v))).card ≤ q₂ * KU)
    (A₂ : α → Out → OC Q D Bool) (hA₂ : ∀ a o, (A₂ a o).Bounded q₂) (F : α → Prop) :
    (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x A₂ F p}
        ≤ (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x' A₂ F p}
          + (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | F (A₁.run H)}
            * ((((2 * (q₁ * K + 2 * Kc)) : ℕ) : ℝ≥0∞) / Fintype.card (C × (Fin M.k → D))
              + (((2 * (q₂ * KU)) : ℕ) : ℝ≥0∞) / Fintype.card C)
      ∧ (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x' A₂ F p}
        ≤ (PMF.uniformOfFintype ((Q → D) × C)).toOuterMeasure {p | M.realEv A₁ x A₂ F p}
          + (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | F (A₁.run H)}
            * ((((2 * (q₁ * K + 2 * Kc)) : ℕ) : ℝ≥0∞) / Fintype.card (C × (Fin M.k → D))
              + (((2 * (q₂ * KU)) : ℕ) : ℝ≥0∞) / Fintype.card C) := by
  classical
  -- the chain-programming step for an input choice `u`
  have hprogStep : ∀ u : α → X,
      (univ.filter (fun ω : (Q → D) × (C × (Fin M.k → D)) => F (A₁.run ω.1) ∧ apReal
          (fun a c H v => M.pts (u a) c H v) A₁ (fun a c v => A₂ a (M.out (u a) c v)) ω)).card
        ≤ (univ.filter (M.progEv A₁ u A₂ F)).card
          + (univ.filter (fun H : Q → D => F (A₁.run H))).card * (q₁ * K + Kc)
      ∧ (univ.filter (M.progEv A₁ u A₂ F)).card
        ≤ (univ.filter (fun ω : (Q → D) × (C × (Fin M.k → D)) => F (A₁.run ω.1) ∧ apReal
            (fun a c H v => M.pts (u a) c H v) A₁ (fun a c v => A₂ a (M.out (u a) c v)) ω)).card
          + (univ.filter (fun H : Q → D => F (A₁.run H))).card * (q₁ * K + Kc) := by
    intro u
    have hy : ∀ a c H, Causal (M.pts (u a) c H) := fun a c H => M.causal _ c H
    have hse : ∀ a c (H H' : Q → D) v, (∀ z ∈ M.dep (u a) c, H z = H' z) → M.pts (u a) c H v = M.pts (u a) c H' v :=
      fun a c H H' v h => M.sep _ c H H' v h
    obtain ⟨c1, c2⟩ := apCount (y := fun a c H v => M.pts (u a) c H v) (A₁ := A₁)
      (dep := fun a c => M.dep (u a) c) hy hse (fun a c v => A₂ a (M.out (u a) c v)) F
    have hb := apBad_card (y := fun a c H v => M.pts (u a) c H v) (dep := fun a c => M.dep (u a) c) A₁ q₁ hA₁ K Kc
      (fun a H z => hK (u a) H z) (fun a H => hKc (u a) H) F
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
  have hx := hid_card M A₁ x A₂ F q₂ hA₂ KU hU
  have hy' := hid_card M A₁ x' A₂ F q₂ hA₂ KU hU
  set NF := (univ.filter (fun H : Q → D => F (A₁.run H))).card with hNF
  set NV := Fintype.card (Fin M.k → D) with hNV
  -- the counts of the honest worlds
  set Rx := (univ.filter (fun ω : (Q → D) × (C × (Fin M.k → D)) => F (A₁.run ω.1) ∧ apReal
      (fun a c H v => M.pts (x a) c H v) A₁ (fun a c v => A₂ a (M.out (x a) c v)) ω)).card
  set Ry := (univ.filter (fun ω : (Q → D) × (C × (Fin M.k → D)) => F (A₁.run ω.1) ∧ apReal
      (fun a c H v => M.pts (x' a) c H v) A₁ (fun a c v => A₂ a (M.out (x' a) c v)) ω)).card
  have hB : NF * (q₁ * K + Kc) + (NF * Kc + NF * (NV * (q₂ * KU)))
      + (NF * Kc + NF * (NV * (q₂ * KU))) + NF * (q₁ * K + Kc)
      = NF * (2 * (q₁ * K + 2 * Kc) + NV * (2 * (q₂ * KU))) := by ring
  have hxy : Rx ≤ Ry + NF * (2 * (q₁ * K + 2 * Kc) + NV * (2 * (q₂ * KU))) := by
    rw [← hB]
    omega
  have hyx : Ry ≤ Rx + NF * (2 * (q₁ * K + 2 * Kc) + NV * (2 * (q₂ * KU))) := by
    rw [← hB]
    omega
  -- to probabilities
  have hΩ : Fintype.card ((Q → D) × (C × (Fin M.k → D))) = Fintype.card (Q → D) * (Fintype.card C * NV) := by
    rw [Fintype.card_prod, Fintype.card_prod]
  have hNH0 : (Fintype.card (Q → D) : ℝ≥0∞) ≠ 0 := by simp
  have hNHt : (Fintype.card (Q → D) : ℝ≥0∞) ≠ ∞ := ENNReal.natCast_ne_top _
  have hNC0 : (Fintype.card C : ℝ≥0∞) ≠ 0 := by simp
  have hNCt : (Fintype.card C : ℝ≥0∞) ≠ ∞ := ENNReal.natCast_ne_top _
  have hNV0 : (NV : ℝ≥0∞) ≠ 0 := by simp [NV]
  have hNVt : (NV : ℝ≥0∞) ≠ ∞ := ENNReal.natCast_ne_top _
  have hconv : ∀ R R' : ℕ, R ≤ R' + NF * (2 * (q₁ * K + 2 * Kc) + NV * (2 * (q₂ * KU))) →
      (R : ℝ≥0∞) / Fintype.card ((Q → D) × (C × (Fin M.k → D)))
        ≤ (R' : ℝ≥0∞) / Fintype.card ((Q → D) × (C × (Fin M.k → D)))
          + (NF : ℝ≥0∞) / Fintype.card (Q → D)
            * ((((2 * (q₁ * K + 2 * Kc)) : ℕ) : ℝ≥0∞) / Fintype.card (C × (Fin M.k → D))
              + (((2 * (q₂ * KU)) : ℕ) : ℝ≥0∞) / Fintype.card C) := by
    intro R R' h
    rw [hΩ, Fintype.card_prod]
    calc (R : ℝ≥0∞) / ((Fintype.card (Q → D) * (Fintype.card C * NV) : ℕ) : ℝ≥0∞)
        ≤ ((R' + NF * (2 * (q₁ * K + 2 * Kc) + NV * (2 * (q₂ * KU))) : ℕ) : ℝ≥0∞)
            / ((Fintype.card (Q → D) * (Fintype.card C * NV) : ℕ) : ℝ≥0∞) := by
          gcongr
      _ = _ := by
          simp only [Nat.cast_add, Nat.cast_mul, Nat.cast_ofNat]
          rw [div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv,
            ENNReal.mul_inv (Or.inl hNH0) (Or.inl hNHt), ENNReal.mul_inv (Or.inl hNC0) (Or.inl hNCt)]
          have hvv : (NV : ℝ≥0∞) * (NV : ℝ≥0∞)⁻¹ = 1 := ENNReal.mul_inv_cancel hNV0 hNVt
          calc ((R' : ℝ≥0∞) + NF * (2 * (q₁ * K + 2 * Kc) + NV * (2 * (q₂ * KU))))
                * ((Fintype.card (Q → D) : ℝ≥0∞)⁻¹ * ((Fintype.card C : ℝ≥0∞)⁻¹ * (NV : ℝ≥0∞)⁻¹))
              = (R' : ℝ≥0∞) * ((Fintype.card (Q → D) : ℝ≥0∞)⁻¹ * ((Fintype.card C : ℝ≥0∞)⁻¹ * (NV : ℝ≥0∞)⁻¹))
                + NF * (Fintype.card (Q → D) : ℝ≥0∞)⁻¹
                  * ((2 * (q₁ * K + 2 * Kc)) * ((Fintype.card C : ℝ≥0∞)⁻¹ * (NV : ℝ≥0∞)⁻¹)
                    + 2 * (q₂ * KU) * (Fintype.card C : ℝ≥0∞)⁻¹ * ((NV : ℝ≥0∞) * (NV : ℝ≥0∞)⁻¹)) := by ring
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

end FSModel

end ZK60.ZKW16
