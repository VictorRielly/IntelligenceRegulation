/-
D63, obligation 5 (`ZeroKnowledge`), GENERIC: the random-oracle programming lemma and the `R`-receipt hybrid, in the
framework of `Statements.lean` (`OC`, `OC.runState`, `realProb`, `idealProb`, `Simulator`). Nothing here is about one
profile; the per-profile simulator is not built.

(A) **Programming the random oracle** (`program`, `progReal`, `progIdeal`, `program_coupling`, `progBad_le`,
`program_real_ideal`, `program_real_ideal_inj`). One receipt's Fiat–Shamir challenges are the oracle's answers at `k`
points `y a σ`, which depend on everything before the proof request (`a`, the result of `A₁`) and on the receipt's
fresh salt `σ` (uniform in `S`). A simulator instead draws the challenges `v` fresh and PROGRAMS the oracle to answer
them at those points. `A₂` is everything after (the rest of the receipt, which may use the challenges, and the
distinguisher's later queries); it runs against the real oracle in one world and the programmed one in the other.
* `program_coupling` (exact): the two worlds differ by at most the probability that `A₁` asked one of the points
  BEFORE they were programmed (`progBad`). The proof is a coupling, as in `HidingMerkle.lean`: swap the oracle's
  answers at the points with the fresh values; it is an involution of the coins (`progSwap_involutive`), and outside
  the bad event it maps one world's event onto the other's (`real_swap_iff`). `A₂`'s queries cost nothing: after the
  swap every answer it gets is consistent.
* `progBad_le`: if each point determines the salt up to `K` values, the bad event has probability at most
  `k·q₁·K/|S|` for an `A₁` of `q₁` queries; `program_real_ideal`, and with points injective in the salt
  (`program_real_ideal_inj`) the advantage is at most `k·q₁/|S|`: the `q·(number of points)/|space|` term.

(B) **The `R`-receipt hybrid** (`ProgSim`, `hybStep`, `hybProb`, `ProgSim.toSim`, `hybProb_zero`, `hybProb_ge`,
`zeroKnowledge_of_hybrid`). A *programming simulator* (`ProgSim`) produces one receipt from the weights, the CURRENT
oracle (a uniform base oracle `H` with the points programmed so far on top, `ovr`), the public data
`(publicPart (forward W x), leak x)` and its coins, and names the points it programs. A simulator that programs nothing
(for instance the honest prover run on a stand-in input with the same public data) is a special case.
* `ovr_append`, `ovr_ofFn_program`: a receipt that programs its `k` distinct points `y i` to `v i` turns the current
  oracle `H` into exactly `program y v H`, the programmed oracle of (A), so (A) is the tool for the programming part of
  each hybrid step.
* `ProgSim.toSim`: every programming simulator is a `Simulator` of `Statements.lean`: it takes its base oracle from its
  first coin and keeps the programmed table in its state.
* Hybrid `j` (`hybProb … j`): one probability space (a uniform `H` and per-position coins); the first `j` proof
  requests are simulated, the others answered by the honest prover against the current oracle, and hash queries by
  the current oracle.
* The endpoints are EXACTLY the approved worlds: hybrid `0` is `realProb` (`hybProb_zero`), and hybrid `R` is
  `idealProb` of `ProgSim.toSim` for every distinguisher with at most `R` proof requests (`hybProb_ge`).
* `zeroKnowledge_of_hybrid`: if each step `j < R` (receipt `j` real versus simulated, the others fixed by the
  hybrid) moves the probability by at most `ε q j` for every `Within q R` distinguisher, then
  `ZeroKnowledge M P (fun q R => Σ_{j<R} ε q j)`; with one bound per receipt, `R·ε₁ q`
  (`zeroKnowledge_of_hybrid_uniform`). The per-receipt bound is the hypothesis; the programming term of each step is
  what (A) bounds.
* `zeroKnowledge_min_one` (an error above `1` says nothing) and `zeroKnowledge_target_of_hybrid`: a per-receipt bound
  `εhv + q·δ` with `εhv ≤ 2^-120` and `δ ≤ 2^-248` gives `ZeroKnowledge M P εzkTarget`, the approved target. The
  condition on `δ` is the point of finding A5 in `ZK60_LEAN_ASSEMBLY_20261106.md`: a per-query, per-receipt term adds
  up to `R·q·δ`, a cross term the target has no slot for.

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.CompleteSub

namespace ZK60.ZKHybrid

open scoped ENNReal
open Finset

/-! ## Uniform laws through an equivalence -/

/-- **A marginal through an equivalence.** If `e : α ≃ β × γ`, an event about the first component of `e a` has, under
the uniform law of `α`, its uniform probability on `β`. -/
theorem prob_marginal {α β γ : Type} [Fintype α] [Nonempty α] [Fintype β] [Nonempty β] [Fintype γ] [Nonempty γ]
    (e : α ≃ β × γ) (E : Set β) :
    (PMF.uniformOfFintype α).toOuterMeasure {a | (e a).1 ∈ E} = (PMF.uniformOfFintype β).toOuterMeasure E := by
  have hset : {a | (e a).1 ∈ E} = e ⁻¹' (Prod.fst ⁻¹' E) := rfl
  rw [hset, ← PMF.toOuterMeasure_map_apply, Hiding.map_uniform_equiv, Hiding.prob_fst]

/-- A constant event has probability `1` or `0`. -/
theorem prob_const {α : Type} (p : PMF α) (b : Bool) :
    p.toOuterMeasure {_a | b = true} = if b = true then 1 else 0 := by
  by_cases hb : b = true
  · rw [ite_eq_left hb]
    exact (PMF.toOuterMeasure_apply_eq_one_iff _ _).mpr (fun _ _ => hb)
  · rw [ite_eq_right hb]
    have : {_a : α | b = true} = ∅ := Set.eq_empty_of_forall_notMem (fun _ h => hb h)
    rw [this, MeasureTheory.measure_empty]

/-! ## (A) Programming the random oracle -/

section Program

variable {Q D S α : Type} [DecidableEq Q] {k : ℕ}

/-- **The oracle `H` programmed** to answer `v i` at the point `y i` (the `k` Fiat–Shamir points of one simulated
receipt). -/
noncomputable def program (y : Fin k → Q) (v : Fin k → D) (H : Q → D) (z : Q) : D :=
  if h : ∃ i, y i = z then v h.choose else H z

/-- At a programmed point the programmed oracle answers the programmed value (the points are distinct). -/
theorem program_at {y : Fin k → Q} (hy : Function.Injective y) (v : Fin k → D) (H : Q → D) (i : Fin k) :
    program y v H (y i) = v i := by
  have h : ∃ i', y i' = y i := ⟨i, rfl⟩
  unfold program
  rw [dite_eq_left h]
  exact congrArg v (hy h.choose_spec)

/-- Away from the programmed points the programmed oracle is the original one. -/
theorem program_off (y : Fin k → Q) (v : Fin k → D) (H : Q → D) (z : Q) (hz : ∀ i, y i ≠ z) :
    program y v H z = H z := by
  unfold program
  exact dite_eq_right (fun h => hz h.choose h.choose_spec)

/-- A computation that asked none of the points runs (and logs) the same against the programmed oracle. -/
theorem runLog_program (y : Fin k → Q) (v : Fin k → D) (H : Q → D) (A₁ : OC Q D α)
    (h : ∀ i, y i ∉ OC.queries H A₁) : A₁.runLog (program y v H) = A₁.runLog H :=
  OC.runLog_eq_of_agree H (program y v H) A₁
    (fun z hz => program_off y v H z (fun i hi => h i (by rw [hi]; exact hz)))

/-- **The bad event**: `A₁`, run before the proof request, asked one of the receipt's points. -/
def progBad (y : α → S → Fin k → Q) (A₁ : OC Q D α) (ω : ((Q → D) × S) × (Fin k → D)) : Prop :=
  ∃ i, y (A₁.run ω.1.1) ω.1.2 i ∈ OC.queries ω.1.1 A₁

open Classical in
/-- **The coupling**: outside the bad event, program the oracle at the points with the fresh values and hand the old
answers back as the fresh values. -/
noncomputable def progSwap (y : α → S → Fin k → Q) (A₁ : OC Q D α) (ω : ((Q → D) × S) × (Fin k → D)) :
    ((Q → D) × S) × (Fin k → D) :=
  if progBad y A₁ ω then ω
  else ((program (y (A₁.run ω.1.1) ω.1.2) ω.2 ω.1.1, ω.1.2), fun i => ω.1.1 (y (A₁.run ω.1.1) ω.1.2 i))

theorem progSwap_bad {y : α → S → Fin k → Q} {A₁ : OC Q D α} {ω : ((Q → D) × S) × (Fin k → D)}
    (hb : progBad y A₁ ω) : progSwap y A₁ ω = ω := by
  unfold progSwap
  exact ite_eq_left hb

theorem progSwap_good {y : α → S → Fin k → Q} {A₁ : OC Q D α} {H : Q → D} {σ : S} {v : Fin k → D}
    (hb : ¬ progBad y A₁ ((H, σ), v)) :
    progSwap y A₁ ((H, σ), v) = ((program (y (A₁.run H) σ) v H, σ), fun i => H (y (A₁.run H) σ i)) := by
  unfold progSwap
  exact ite_eq_right hb

/-- Outside the bad event `A₁` runs, and asks, the same against the programmed oracle. -/
theorem run_program_good {y : α → S → Fin k → Q} {A₁ : OC Q D α} {H : Q → D} {σ : S} {v : Fin k → D}
    (hb : ¬ progBad y A₁ ((H, σ), v)) :
    A₁.run (program (y (A₁.run H) σ) v H) = A₁.run H
      ∧ OC.queries (program (y (A₁.run H) σ) v H) A₁ = OC.queries H A₁ := by
  have hq : ∀ i, y (A₁.run H) σ i ∉ OC.queries H A₁ := fun i hi => hb ⟨i, hi⟩
  have hlog := runLog_program (y (A₁.run H) σ) v H A₁ hq
  refine ⟨?_, ?_⟩
  · rw [← OC.runLog_fst, hlog, OC.runLog_fst]
  · simp only [OC.queries, hlog]

/-- **The coupling is an involution**, hence a bijection of the coins. -/
theorem progSwap_involutive (y : α → S → Fin k → Q) (hinj : ∀ a σ, Function.Injective (y a σ))
    (A₁ : OC Q D α) : Function.Involutive (progSwap y A₁) := by
  rintro ⟨⟨H, σ⟩, v⟩
  by_cases hb : progBad y A₁ ((H, σ), v)
  · rw [progSwap_bad hb, progSwap_bad hb]
  · obtain ⟨hrun, hqs⟩ := run_program_good hb
    have hq : ∀ i, y (A₁.run H) σ i ∉ OC.queries H A₁ := fun i hi => hb ⟨i, hi⟩
    have hb' : ¬ progBad y A₁ ((program (y (A₁.run H) σ) v H, σ), fun i => H (y (A₁.run H) σ i)) := by
      rintro ⟨i, hi⟩
      simp only at hi
      rw [hrun, hqs] at hi
      exact hq i hi
    rw [progSwap_good hb, progSwap_good hb', hrun]
    refine Prod.ext (Prod.ext ?_ rfl) ?_
    · funext z
      dsimp only
      by_cases hz : ∃ i, y (A₁.run H) σ i = z
      · obtain ⟨i, rfl⟩ := hz
        rw [program_at (hinj _ σ)]
      · have hz' : ∀ i, y (A₁.run H) σ i ≠ z := fun i hi => hz ⟨i, hi⟩
        rw [program_off _ _ _ z hz', program_off _ _ _ z hz']
    · funext i
      exact program_at (hinj _ σ) v H i

/-- **Outside the bad event, the swapped real world is the programmed world.** -/
theorem real_swap_iff (y : α → S → Fin k → Q) (hinj : ∀ a σ, Function.Injective (y a σ)) (A₁ : OC Q D α)
    (A₂ : α → S → (Fin k → D) → OC Q D Bool) (ω : ((Q → D) × S) × (Fin k → D)) (hb : ¬ progBad y A₁ ω) :
    ((A₂ (A₁.run (progSwap y A₁ ω).1.1) (progSwap y A₁ ω).1.2
        (fun i => (progSwap y A₁ ω).1.1 (y (A₁.run (progSwap y A₁ ω).1.1) (progSwap y A₁ ω).1.2 i))).run
          (progSwap y A₁ ω).1.1 = true)
      ↔ (A₂ (A₁.run ω.1.1) ω.1.2 ω.2).run (program (y (A₁.run ω.1.1) ω.1.2) ω.2 ω.1.1) = true := by
  obtain ⟨⟨H, σ⟩, v⟩ := ω
  obtain ⟨hrun, -⟩ := run_program_good hb
  rw [progSwap_good hb]
  dsimp only
  rw [hrun]
  have hv : (fun i => program (y (A₁.run H) σ) v H (y (A₁.run H) σ i)) = v := by
    funext i
    exact program_at (hinj _ σ) v H i
  rw [hv]

variable [Fintype Q] [Fintype D] [Nonempty D] [Fintype S] [Nonempty S]

/-- **The real world**: the receipt's challenges are the oracle's answers at its points. -/
noncomputable def progReal (y : α → S → Fin k → Q) (A₁ : OC Q D α) (A₂ : α → S → (Fin k → D) → OC Q D Bool) :
    ℝ≥0∞ :=
  (PMF.uniformOfFintype ((Q → D) × S)).toOuterMeasure
    {p | (A₂ (A₁.run p.1) p.2 (fun i => p.1 (y (A₁.run p.1) p.2 i))).run p.1 = true}

/-- **The programmed world**: fresh uniform challenges `v`, and after `A₁` the oracle is programmed to them at the
points. -/
noncomputable def progIdeal (y : α → S → Fin k → Q) (A₁ : OC Q D α) (A₂ : α → S → (Fin k → D) → OC Q D Bool) :
    ℝ≥0∞ :=
  (PMF.uniformOfFintype (((Q → D) × S) × (Fin k → D))).toOuterMeasure
    {ω | (A₂ (A₁.run ω.1.1) ω.1.2 ω.2).run (program (y (A₁.run ω.1.1) ω.1.2) ω.2 ω.1.1) = true}

/-- **The programming coupling.** The real and the programmed world differ, in both directions, by at most the
probability of the bad event (`A₁` asked a point before it was programmed). No budget is needed for `A₂`. -/
theorem program_coupling (y : α → S → Fin k → Q) (hinj : ∀ a σ, Function.Injective (y a σ)) (A₁ : OC Q D α)
    (A₂ : α → S → (Fin k → D) → OC Q D Bool) :
    progReal y A₁ A₂ ≤ progIdeal y A₁ A₂
        + (PMF.uniformOfFintype (((Q → D) × S) × (Fin k → D))).toOuterMeasure {ω | progBad y A₁ ω}
      ∧ progIdeal y A₁ A₂ ≤ progReal y A₁ A₂
        + (PMF.uniformOfFintype (((Q → D) × S) × (Fin k → D))).toOuterMeasure {ω | progBad y A₁ ω} := by
  set μ := (PMF.uniformOfFintype (((Q → D) × S) × (Fin k → D))).toOuterMeasure with hμ
  let realEv : ((Q → D) × S) × (Fin k → D) → Prop := fun ω =>
    (A₂ (A₁.run ω.1.1) ω.1.2 (fun i => ω.1.1 (y (A₁.run ω.1.1) ω.1.2 i))).run ω.1.1 = true
  let idealEv : ((Q → D) × S) × (Fin k → D) → Prop := fun ω =>
    (A₂ (A₁.run ω.1.1) ω.1.2 ω.2).run (program (y (A₁.run ω.1.1) ω.1.2) ω.2 ω.1.1) = true
  have hreal : progReal y A₁ A₂ = μ {ω | realEv ω} := by
    rw [hμ, progReal]
    exact (Hiding.prob_fst _).symm
  have hideal : progIdeal y A₁ A₂ = μ {ω | idealEv ω} := rfl
  have hΨ : μ (progSwap y A₁ ⁻¹' {ω | realEv ω}) = μ {ω | realEv ω} :=
    Hiding.prob_preimage_bijective _ (progSwap_involutive y hinj A₁).bijective _
  have h1 : progSwap y A₁ ⁻¹' {ω | realEv ω} ⊆ {ω | idealEv ω} ∪ {ω | progBad y A₁ ω} := by
    intro ω hω
    by_cases hb : progBad y A₁ ω
    · exact Or.inr hb
    · exact Or.inl ((real_swap_iff y hinj A₁ A₂ ω hb).mp hω)
  have h2 : {ω | idealEv ω} ⊆ progSwap y A₁ ⁻¹' {ω | realEv ω} ∪ {ω | progBad y A₁ ω} := by
    intro ω hω
    by_cases hb : progBad y A₁ ω
    · exact Or.inr hb
    · exact Or.inl ((real_swap_iff y hinj A₁ A₂ ω hb).mpr hω)
  constructor
  · calc progReal y A₁ A₂ = μ (progSwap y A₁ ⁻¹' {ω | realEv ω}) := by rw [hΨ, hreal]
      _ ≤ μ ({ω | idealEv ω} ∪ {ω | progBad y A₁ ω}) := MeasureTheory.measure_mono h1
      _ ≤ μ {ω | idealEv ω} + μ {ω | progBad y A₁ ω} := MeasureTheory.measure_union_le _ _
      _ = progIdeal y A₁ A₂ + μ {ω | progBad y A₁ ω} := by rw [hideal]
  · calc progIdeal y A₁ A₂ = μ {ω | idealEv ω} := hideal
      _ ≤ μ (progSwap y A₁ ⁻¹' {ω | realEv ω} ∪ {ω | progBad y A₁ ω}) := MeasureTheory.measure_mono h2
      _ ≤ μ (progSwap y A₁ ⁻¹' {ω | realEv ω}) + μ {ω | progBad y A₁ ω} := MeasureTheory.measure_union_le _ _
      _ = progReal y A₁ A₂ + μ {ω | progBad y A₁ ω} := by rw [hΨ, ← hreal]

/-- **The bad event is unlikely.** If each point determines the fresh salt up to `K` values, an `A₁` making at most
`q₁` queries asked one of the `k` points with probability at most `k·q₁·K/|S|`: its queries do not depend on the salt,
which is drawn after it. -/
theorem progBad_le (y : α → S → Fin k → Q) (K : ℕ)
    (hK : ∀ a i z, (univ.filter (fun σ => y a σ i = z)).card ≤ K) (A₁ : OC Q D α) (q₁ : ℕ)
    (hA₁ : A₁.Bounded q₁) :
    (PMF.uniformOfFintype (((Q → D) × S) × (Fin k → D))).toOuterMeasure {ω | progBad y A₁ ω}
      ≤ ((k * q₁ * K : ℕ) : ℝ≥0∞) / Fintype.card S := by
  classical
  let Tb : (Q → D) → Finset S := fun H => univ.filter (fun σ => ∃ i, y (A₁.run H) σ i ∈ OC.queries H A₁)
  have hset : {ω : ((Q → D) × S) × (Fin k → D) | progBad y A₁ ω}
      = Prod.fst ⁻¹' {p : (Q → D) × S | p.2 ∈ Tb p.1} := by
    ext ω
    simp [progBad, Tb]
  rw [hset, Hiding.prob_fst]
  refine Complete.prob_snd_mem_le Tb _ (fun H => ?_)
  set L := OC.queries H A₁
  have hLlen : L.toFinset.card ≤ q₁ := (List.toFinset_card_le _).trans (OC.length_queries_le H A₁ q₁ hA₁)
  have hsub : Tb H ⊆ (univ : Finset (Fin k)).biUnion
      (fun i => L.toFinset.biUnion (fun z => univ.filter (fun σ => y (A₁.run H) σ i = z))) := by
    intro σ hσ
    simp only [Tb, mem_filter, mem_univ, true_and] at hσ
    obtain ⟨i, hi⟩ := hσ
    simp only [mem_biUnion, mem_univ, true_and, List.mem_toFinset, mem_filter]
    exact ⟨i, _, hi, rfl⟩
  calc (Tb H).card
      ≤ ((univ : Finset (Fin k)).biUnion
          (fun i => L.toFinset.biUnion (fun z => univ.filter (fun σ => y (A₁.run H) σ i = z)))).card :=
        card_le_card hsub
    _ ≤ ∑ i : Fin k, (L.toFinset.biUnion (fun z => univ.filter (fun σ => y (A₁.run H) σ i = z))).card :=
        card_biUnion_le
    _ ≤ ∑ _i : Fin k, ∑ _z ∈ L.toFinset, K :=
        sum_le_sum (fun i _ => card_biUnion_le.trans (sum_le_sum (fun z _ => hK _ _ _)))
    _ = k * (L.toFinset.card * K) := by simp [sum_const, card_univ]
    _ ≤ k * q₁ * K := by
        rw [mul_assoc]
        exact Nat.mul_le_mul_left _ (Nat.mul_le_mul_right _ hLlen)

/-- **The random-oracle programming lemma.** A simulator that programs the oracle at `k` distinct points derived from
a fresh salt (each point fixing the salt up to `K` values) is told apart from the real oracle by a distinguisher whose
part before the proof request makes `q₁` queries with advantage at most `k·q₁·K/|S|`, in both directions, whatever the
rest of the distinguisher does. -/
theorem program_real_ideal (y : α → S → Fin k → Q) (hinj : ∀ a σ, Function.Injective (y a σ)) (K : ℕ)
    (hK : ∀ a i z, (univ.filter (fun σ => y a σ i = z)).card ≤ K) (A₁ : OC Q D α) (q₁ : ℕ) (hA₁ : A₁.Bounded q₁)
    (A₂ : α → S → (Fin k → D) → OC Q D Bool) :
    progReal y A₁ A₂ ≤ progIdeal y A₁ A₂ + ((k * q₁ * K : ℕ) : ℝ≥0∞) / Fintype.card S
      ∧ progIdeal y A₁ A₂ ≤ progReal y A₁ A₂ + ((k * q₁ * K : ℕ) : ℝ≥0∞) / Fintype.card S := by
  obtain ⟨h1, h2⟩ := program_coupling y hinj A₁ A₂
  have hb := progBad_le y K hK A₁ q₁ hA₁
  exact ⟨h1.trans (add_le_add le_rfl hb), h2.trans (add_le_add le_rfl hb)⟩

/-- **The programming lemma with points injective in the salt** (each point names one salt): advantage at most
`k·q₁/|S|`, `q₁` queries times `k` programmed points over the salt space. -/
theorem program_real_ideal_inj (y : α → S → Fin k → Q) (hinj : ∀ a σ, Function.Injective (y a σ))
    (hsalt : ∀ a i, Function.Injective (fun σ => y a σ i)) (A₁ : OC Q D α) (q₁ : ℕ) (hA₁ : A₁.Bounded q₁)
    (A₂ : α → S → (Fin k → D) → OC Q D Bool) :
    progReal y A₁ A₂ ≤ progIdeal y A₁ A₂ + ((k * q₁ : ℕ) : ℝ≥0∞) / Fintype.card S
      ∧ progIdeal y A₁ A₂ ≤ progReal y A₁ A₂ + ((k * q₁ : ℕ) : ℝ≥0∞) / Fintype.card S := by
  classical
  have hK : ∀ a i z, (univ.filter (fun σ => y a σ i = z)).card ≤ 1 := by
    intro a i z
    refine card_le_one.mpr (fun σ hσ σ' hσ' => hsalt a i ?_)
    simp only [mem_filter, mem_univ, true_and] at hσ hσ'
    exact hσ.trans hσ'.symm
  have h := program_real_ideal y hinj 1 hK A₁ q₁ hA₁ A₂
  rwa [mul_one] at h

end Program

/-! ## (B) The `R`-receipt hybrid -/

/-! ### Two generic facts: one question of a run, and telescoping -/

/-- One question of a run against a stateful responder. -/
theorem runState_ask {I O α σ R : Type} (step : σ → I → R → O × σ) (rand : ℕ → R) (pos : ℕ) (s : σ) (i : I)
    (k : O → OC I O α) :
    (OC.ask i k).runState step rand pos s
      = (k (step s i (rand pos)).1).runState step rand (pos + 1) (step s i (rand pos)).2 := rfl

/-- A distinguisher that asks something has a positive budget. -/
theorem within_ask_pos {I X O α : Type} {i : I ⊕ X} {k : O → OC (I ⊕ X) O α} {q r : ℕ}
    (h : (OC.ask i k).Within q r) : 1 ≤ q + r := by
  cases i with
  | inl x =>
    cases q with
    | zero => simp [OC.Within] at h
    | succ q => omega
  | inr x =>
    cases r with
    | zero => simp [OC.Within] at h
    | succ r => omega

/-- **Telescoping, one direction**: steps of at most `e j` add up. -/
theorem telescope_le {p e : ℕ → ℝ≥0∞} :
    ∀ R : ℕ, (∀ j < R, p j ≤ p (j + 1) + e j) → p 0 ≤ p R + ∑ j ∈ range R, e j
  | 0, _ => by simp
  | R + 1, h => by
    have ih := telescope_le R (fun j hj => h j (by omega))
    calc p 0 ≤ p R + ∑ j ∈ range R, e j := ih
      _ ≤ (p (R + 1) + e R) + ∑ j ∈ range R, e j := by
          gcongr
          exact h R (by omega)
      _ = p (R + 1) + ∑ j ∈ range (R + 1), e j := by
          rw [sum_range_succ]
          ring

/-- **Telescoping, the other direction.** -/
theorem telescope_ge {p e : ℕ → ℝ≥0∞} :
    ∀ R : ℕ, (∀ j < R, p (j + 1) ≤ p j + e j) → p R ≤ p 0 + ∑ j ∈ range R, e j
  | 0, _ => by simp
  | R + 1, h => by
    have ih := telescope_ge R (fun j hj => h j (by omega))
    calc p (R + 1) ≤ p R + e R := h R (by omega)
      _ ≤ (p 0 + ∑ j ∈ range R, e j) + e R := by gcongr
      _ = p 0 + ∑ j ∈ range (R + 1), e j := by
          rw [sum_range_succ]
          ring

/-- Splitting per-position coin pairs: the prover's coins first. -/
def splitFst {A B C : Type} {n : ℕ} : A × (Fin n → B × C) ≃ (A × (Fin n → B)) × (Fin n → C) where
  toFun p := ((p.1, fun i => (p.2 i).1), fun i => (p.2 i).2)
  invFun p := (p.1.1, fun i => (p.1.2 i, p.2 i))
  left_inv _ := rfl
  right_inv _ := rfl

/-- Splitting per-position coin pairs: the simulator's coins first. -/
def splitSnd {A B C : Type} {n : ℕ} : A × (Fin n → B × C) ≃ (A × (Fin n → C)) × (Fin n → B) where
  toFun p := ((p.1, fun i => (p.2 i).2), fun i => (p.2 i).1)
  invFun p := (p.1.1, fun i => (p.2 i, p.1.2 i))
  left_inv _ := rfl
  right_inv _ := rfl

/-- The simulator's coins: the base oracle of the first position, every position's own coin, and the unused base
oracles of the later positions. -/
def splitHead {A C : Type} {m : ℕ} : (Fin (m + 1) → A × C) ≃ (A × (Fin (m + 1) → C)) × (Fin m → A) where
  toFun f := (((f 0).1, fun i => (f i).2), fun i => (f i.succ).1)
  invFun p := fun i => (Fin.cons (α := fun _ => A) p.1.1 p.2 i, p.1.2 i)
  left_inv f := by
    funext i
    cases i using Fin.cases with
    | zero => simp
    | succ i => simp
  right_inv p := by simp

/-- `extend` of a vector of pairs, first components. -/
theorem extend_fst {B C : Type} [Inhabited B] [Inhabited C] {n : ℕ} (f : Fin n → B × C) :
    (fun p => (extend f p).1) = extend (fun i => (f i).1) := by
  funext p
  unfold extend
  split_ifs <;> rfl

/-- `extend` of a vector of pairs, second components. -/
theorem extend_snd {B C : Type} [Inhabited B] [Inhabited C] {n : ℕ} (f : Fin n → B × C) :
    (fun p => (extend f p).2) = extend (fun i => (f i).2) := by
  funext p
  unfold extend
  split_ifs <;> rfl

section Hybrid

variable {Q D Coins : Type}

/-- The oracle `H` with the table `T` of programmed points on top, the most recent entry first. -/
def ovr [DecidableEq Q] : List (Q × D) → (Q → D) → Q → D
  | [], H => H
  | e :: T, H => Function.update (ovr T H) e.1 e.2

/-- New points on top of a table: the oracle of the old table, programmed with the new points. -/
theorem ovr_append [DecidableEq Q] (T' T : List (Q × D)) (H : Q → D) : ovr (T' ++ T) H = ovr T' (ovr T H) := by
  induction T' with
  | nil => rfl
  | cons e T' ih => simp only [List.cons_append, ovr, ih]

/-- **The hybrid's table realizes the programming lemma's oracle**: a receipt that programs its `k` distinct points
`y i` to `v i` (the table `List.ofFn (fun i => (y i, v i))`) turns the current oracle `H` into `program y v H`. -/
theorem ovr_ofFn_program [DecidableEq Q] {k : ℕ} (y : Fin k → Q) (hy : Function.Injective y) (v : Fin k → D)
    (H : Q → D) : ovr (List.ofFn (fun i => (y i, v i))) H = program y v H := by
  induction k with
  | zero =>
    funext z
    rw [List.ofFn_zero]
    exact (program_off y v H z (fun i => i.elim0)).symm
  | succ k ih =>
    have hy' : Function.Injective (fun i : Fin k => y i.succ) := fun a b h => Fin.succ_injective _ (hy h)
    have e : ovr (List.ofFn (fun i => (y i, v i))) H
        = Function.update (ovr (List.ofFn (fun i : Fin k => (y i.succ, v i.succ))) H) (y 0) (v 0) :=
      (congrArg (fun L => ovr L H) (List.ofFn_succ (f := fun i => (y i, v i)))).trans rfl
    rw [e, ih _ hy' _]
    funext z
    by_cases h0 : y 0 = z
    · subst h0
      rw [Function.update_self, program_at hy]
    · rw [Function.update_of_ne (Ne.symm h0)]
      by_cases hz : ∃ i : Fin k, y i.succ = z
      · obtain ⟨i, rfl⟩ := hz
        rw [program_at hy' (fun i => v i.succ) H i, program_at hy]
      · have hz' : ∀ i, y i ≠ z := by
          intro i hi
          cases i using Fin.cases with
          | zero => exact h0 hi
          | succ i => exact hz ⟨i, hi⟩
        rw [program_off _ _ _ z (fun i hi => hz ⟨i, hi⟩), program_off _ _ _ z hz']

/-- **A programming simulator**: one receipt from the weights (public under P1), the CURRENT oracle, the public data
`(publicPart (forward W x), leak x)` of the request and its coins `SC`, together with the points it programs. It never
sees the input. -/
structure ProgSim (M : IntModel) (P : Protocol Q D Coins M) (SC : Type) where
  sim : M.Weights → (Q → D) → M.PubOut × P.Leak → SC → (P.Stmt × P.Receipt) × List (Q × D)

variable [DecidableEq Q] {M : IntModel} {P : Protocol Q D Coins M} {SC : Type}

/-- **Hybrid `j`'s responder.** The state is (the number of proof requests so far, the programmed table). Hash queries
are answered by the current oracle `ovr T H`; the first `j` proof requests by the simulator (its points are added to
the table), the others by the honest prover against the current oracle. -/
def hybStep (PS : ProgSim M P SC) (W : M.Weights) (H : Q → D) (j : ℕ) :
    ℕ × List (Q × D) → Q ⊕ M.Input → Coins × SC → (D ⊕ (P.Stmt × P.Receipt)) × (ℕ × List (Q × D)) :=
  fun st i c => match i with
    | .inl qq => (.inl (ovr st.2 H qq), st)
    | .inr x =>
      if st.1 < j then
        (.inr (PS.sim W (ovr st.2 H) (M.publicPart (M.forward W x), P.leak x) c.2).1,
          (st.1 + 1, (PS.sim W (ovr st.2 H) (M.publicPart (M.forward W x), P.leak x) c.2).2 ++ st.2))
      else (.inr (P.prove (ovr st.2 H) W x c.1), (st.1 + 1, st.2))

/-- The all-simulated responder: every proof request is simulated. -/
def simStep (PS : ProgSim M P SC) (W : M.Weights) (H : Q → D) :
    List (Q × D) → Q ⊕ M.Input → SC → (D ⊕ (P.Stmt × P.Receipt)) × List (Q × D) :=
  fun T i c => match i with
    | .inl qq => (.inl (ovr T H qq), T)
    | .inr x =>
      (.inr (PS.sim W (ovr T H) (M.publicPart (M.forward W x), P.leak x) c).1,
        (PS.sim W (ovr T H) (M.publicPart (M.forward W x), P.leak x) c).2 ++ T)

/-- **Hybrid `0` is the real world, run by run**: no request is simulated, the table stays empty, so every answer is
the real oracle's or the honest prover's on the real oracle. -/
theorem hyb_run_real (PS : ProgSim M P SC) (W : M.Weights) (H : Q → D) (rand : ℕ → Coins × SC) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (pos cnt : ℕ),
      Dist.runState (hybStep PS W H 0) rand pos (cnt, [])
        = Dist.runState (Assembly.realStep P H W) (fun p => (rand p).1) pos () := by
  intro Dist
  induction Dist with
  | ret b => intro pos cnt; rfl
  | ask i k ih =>
    intro pos cnt
    rw [runState_ask, runState_ask]
    cases i with
    | inl qq => exact ih _ (pos + 1) cnt
    | inr x =>
      have e : hybStep PS W H 0 (cnt, []) (.inr x) (rand pos)
          = (.inr (P.prove H W x (rand pos).1), (cnt + 1, [])) := by
        simp [hybStep, ovr]
      rw [e]
      exact ih _ (pos + 1) (cnt + 1)

/-- **Hybrid `j` simulates every request** of a distinguisher with at most `j` of them (counted with the ones so far). -/
theorem hyb_run_sim (PS : ProgSim M P SC) (W : M.Weights) (H : Q → D) (j : ℕ) (rand : ℕ → Coins × SC) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (q r : ℕ), Dist.Within q r →
      ∀ (pos cnt : ℕ) (T : List (Q × D)), cnt + r ≤ j →
        Dist.runState (hybStep PS W H j) rand pos (cnt, T)
          = Dist.runState (simStep PS W H) (fun p => (rand p).2) pos T := by
  intro Dist
  induction Dist with
  | ret b => intro q r _ pos cnt T _; rfl
  | ask i k ih =>
    intro q r hW pos cnt T hcnt
    rw [runState_ask, runState_ask]
    cases i with
    | inl qq =>
      cases q with
      | zero => simp [OC.Within] at hW
      | succ q =>
        simp only [OC.Within] at hW
        exact ih _ q r (hW _) (pos + 1) cnt T hcnt
    | inr x =>
      cases r with
      | zero => simp [OC.Within] at hW
      | succ r =>
        simp only [OC.Within] at hW
        have hlt : cnt < j := by omega
        have e : hybStep PS W H j (cnt, T) (.inr x) (rand pos)
            = (.inr (PS.sim W (ovr T H) (M.publicPart (M.forward W x), P.leak x) (rand pos).2).1,
                (cnt + 1, (PS.sim W (ovr T H) (M.publicPart (M.forward W x), P.leak x) (rand pos).2).2 ++ T)) := by
          simp [hybStep, hlt]
        rw [e]
        exact ih _ q r (hW _) (pos + 1) (cnt + 1) _ (by omega)

variable [Fintype Q] [Fintype D] [Nonempty D] [Inhabited D] [Fintype SC] [Nonempty SC] [Inhabited SC]

/-- **A programming simulator is a `Simulator`** of `Statements.lean`: its coins are a base oracle and its own coins;
it takes the base oracle from its first coin and keeps the weights and the programmed table in its state. -/
@[reducible] noncomputable def ProgSim.toSim (PS : ProgSim M P SC) : Simulator M P where
  State := M.Weights × Option (Q → D) × List (Q × D)
  SCoins := (Q → D) × SC
  fin := inferInstance
  ne := inferInstance
  inh := inferInstance
  init W := (W, none, [])
  step s i c := match i with
    | .inl qq => (.inl (ovr s.2.2 (s.2.1.getD c.1) qq), (s.1, some (s.2.1.getD c.1), s.2.2))
    | .inr z =>
      (.inr (PS.sim s.1 (ovr s.2.2 (s.2.1.getD c.1)) z c.2).1,
        (s.1, some (s.2.1.getD c.1), (PS.sim s.1 (ovr s.2.2 (s.2.1.getD c.1)) z c.2).2 ++ s.2.2))

/-- `ProgSim.toSim`'s run, once it holds its base oracle `H`, is the all-simulated run on `H`. -/
theorem toSim_run (PS : ProgSim M P SC) (W : M.Weights) (H : Q → D) (rand : ℕ → (Q → D) × SC) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (pos : ℕ) (T : List (Q × D)),
      Dist.runState (fun s z c => PS.toSim.step s
          (Sum.map id (fun x => (M.publicPart (M.forward W x), P.leak x)) z) c) rand pos (W, some H, T)
        = Dist.runState (simStep PS W H) (fun p => (rand p).2) pos T := by
  intro Dist
  induction Dist with
  | ret b => intro pos T; rfl
  | ask i k ih =>
    intro pos T
    rw [runState_ask, runState_ask]
    cases i with
    | inl qq => exact ih _ (pos + 1) T
    | inr x => exact ih _ (pos + 1) _

/-- **`ProgSim.toSim`'s run from its initial state** is the all-simulated run on the base oracle of its first coin. -/
theorem toSim_run_init (PS : ProgSim M P SC) (W : M.Weights) (rand : ℕ → (Q → D) × SC)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) :
    Dist.runState (fun s z c => PS.toSim.step s
        (Sum.map id (fun x => (M.publicPart (M.forward W x), P.leak x)) z) c) rand 0 (W, none, [])
      = Dist.runState (simStep PS W (rand 0).1) (fun p => (rand p).2) 0 [] := by
  cases Dist with
  | ret b => rfl
  | ask i k =>
    rw [runState_ask, runState_ask]
    cases i with
    | inl qq => exact toSim_run PS W (rand 0).1 rand _ 1 []
    | inr x => exact toSim_run PS W (rand 0).1 rand _ 1 _

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-- **Hybrid `j`**: the probability that the distinguisher outputs `true`, over a uniform base oracle and uniform
per-position coins (the prover's and the simulator's), with `n` positions. -/
noncomputable def hybProb (PS : ProgSim M P SC) (W : M.Weights) (n : ℕ)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (j : ℕ) : ℝ≥0∞ :=
  (PMF.uniformOfFintype ((Q → D) × (Fin n → Coins × SC))).toOuterMeasure
    {p | Dist.runState (hybStep PS W p.1 j) (extend p.2) 0 (0, []) = true}

omit [Inhabited D] in
/-- **Hybrid `0` is `realProb`**, exactly. -/
theorem hybProb_zero (PS : ProgSim M P SC) (W : M.Weights) (n : ℕ)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) :
    hybProb PS W n Dist 0 = realProb M P W n Dist := by
  rw [Assembly.realProb_eq]
  calc hybProb PS W n Dist 0
      = (PMF.uniformOfFintype ((Q → D) × (Fin n → Coins × SC))).toOuterMeasure
          {a | (splitFst a).1 ∈ {p : (Q → D) × (Fin n → Coins) |
            Dist.runState (Assembly.realStep P p.1 W) (extend p.2) 0 () = true}} := by
        unfold hybProb
        congr 1
        ext p
        show Dist.runState (hybStep PS W p.1 0) (extend p.2) 0 (0, []) = true
          ↔ Dist.runState (Assembly.realStep P p.1 W) (extend (fun i => (p.2 i).1)) 0 () = true
        rw [hyb_run_real PS W p.1 (extend p.2) Dist 0 0, extend_fst]
    _ = _ := prob_marginal splitFst _

/-- **Hybrid `j ≥ R` is `idealProb` of `ProgSim.toSim`**, exactly, for every distinguisher with at most `R` proof
requests (and `q` hash queries; `q + R` positions, as `ZeroKnowledge` counts them). -/
theorem hybProb_ge (PS : ProgSim M P SC) (W : M.Weights) (q R : ℕ)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (hD : Dist.Within q R) (j : ℕ) (hj : R ≤ j) :
    hybProb PS W (q + R) Dist j = idealProb M P PS.toSim W (q + R) Dist := by
  cases Dist with
  | ret b =>
    have h1 : hybProb PS W (q + R) (OC.ret b) j = if b = true then 1 else 0 := by
      unfold hybProb
      exact prob_const _ b
    have h2 : idealProb M P PS.toSim W (q + R) (OC.ret b) = if b = true then 1 else 0 := by
      unfold idealProb
      exact prob_const _ b
    rw [h1, h2]
  | ask i k =>
    obtain ⟨m, hm⟩ : ∃ m, q + R = m + 1 := ⟨q + R - 1, by have := within_ask_pos hD; omega⟩
    have hrun : ∀ (H : Q → D) (rand : ℕ → Coins × SC),
        (OC.ask i k).runState (hybStep PS W H j) rand 0 (0, [])
          = (OC.ask i k).runState (simStep PS W H) (fun p => (rand p).2) 0 [] :=
      fun H rand => hyb_run_sim PS W H j rand (OC.ask i k) q R hD 0 0 [] (by omega)
    rw [hm]
    let E : Set ((Q → D) × (Fin (m + 1) → SC)) :=
      {p | (OC.ask i k).runState (simStep PS W p.1) (extend p.2) 0 [] = true}
    have h1 : hybProb PS W (m + 1) (OC.ask i k) j
        = (PMF.uniformOfFintype ((Q → D) × (Fin (m + 1) → Coins × SC))).toOuterMeasure
            {a | (splitSnd a).1 ∈ E} := by
      unfold hybProb
      congr 1
      ext p
      show (OC.ask i k).runState (hybStep PS W p.1 j) (extend p.2) 0 (0, []) = true
        ↔ (OC.ask i k).runState (simStep PS W p.1) (extend (fun i => (p.2 i).2)) 0 [] = true
      rw [hrun, extend_snd]
    have h2 : idealProb M P PS.toSim W (m + 1) (OC.ask i k)
        = (PMF.uniformOfFintype (Fin (m + 1) → (Q → D) × SC)).toOuterMeasure {a | (splitHead a).1 ∈ E} := by
      show (PMF.uniformOfFintype (Fin (m + 1) → (Q → D) × SC)).toOuterMeasure
          {sc | (OC.ask i k).runState (fun s z c => PS.toSim.step s
            (Sum.map id (fun x => (M.publicPart (M.forward W x), P.leak x)) z) c) (extend sc) 0 (W, none, [])
              = true}
        = _
      congr 1
      ext sc
      show (OC.ask i k).runState (fun s z c => PS.toSim.step s
            (Sum.map id (fun x => (M.publicPart (M.forward W x), P.leak x)) z) c) (extend sc) 0 (W, none, [])
              = true
        ↔ (OC.ask i k).runState (simStep PS W (sc 0).1) (extend (fun i => (sc i).2)) 0 [] = true
      have h0 : extend sc 0 = sc 0 := by simp [extend]
      rw [toSim_run_init PS W (extend sc) (OC.ask i k), extend_snd, h0]
    rw [h1, h2, prob_marginal splitSnd E, prob_marginal splitHead E]

/-! ### The hybrid argument -/

omit [Inhabited D] in
/-- **The `R`-receipt hybrid.** Let `PS` be a programming simulator. If, for every distinguisher with at most `q` hash
queries and `R` proof requests, each hybrid step `j < R` (receipt `j` honest versus simulated, the earlier ones
simulated and the later ones honest) moves the probability by at most `ε q j` in both directions, then the protocol is
zero knowledge with error `Σ_{j<R} ε q j`, with the simulator `PS.toSim`. -/
theorem zeroKnowledge_of_hybrid (PS : ProgSim M P SC) (ε : ℕ → ℕ → ℝ≥0∞)
    (hstep : ∀ (W : M.Weights) (q R : ℕ) (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool),
      Dist.Within q R → ∀ j < R,
        hybProb PS W (q + R) Dist j ≤ hybProb PS W (q + R) Dist (j + 1) + ε q j
        ∧ hybProb PS W (q + R) Dist (j + 1) ≤ hybProb PS W (q + R) Dist j + ε q j) :
    ZeroKnowledge M P (fun q R => ∑ j ∈ range R, ε q j) := by
  have _inst : Inhabited D := ⟨Classical.arbitrary D⟩
  refine ⟨PS.toSim, fun W q R Dist hD => ?_⟩
  rw [← hybProb_zero PS W (q + R) Dist, ← hybProb_ge PS W q R Dist hD R le_rfl]
  exact ⟨telescope_le (p := fun j => hybProb PS W (q + R) Dist j) (e := fun j => ε q j) R
      (fun j hj => (hstep W q R Dist hD j hj).1),
    telescope_ge (p := fun j => hybProb PS W (q + R) Dist j) (e := fun j => ε q j) R
      (fun j hj => (hstep W q R Dist hD j hj).2)⟩

omit [Inhabited D] in
/-- **The `R`-receipt hybrid with one bound per receipt**: `R·ε₁ q`. -/
theorem zeroKnowledge_of_hybrid_uniform (PS : ProgSim M P SC) (ε₁ : ℕ → ℝ≥0∞)
    (hstep : ∀ (W : M.Weights) (q R : ℕ) (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool),
      Dist.Within q R → ∀ j < R,
        hybProb PS W (q + R) Dist j ≤ hybProb PS W (q + R) Dist (j + 1) + ε₁ q
        ∧ hybProb PS W (q + R) Dist (j + 1) ≤ hybProb PS W (q + R) Dist j + ε₁ q) :
    ZeroKnowledge M P (fun q R => (R : ℝ≥0∞) * ε₁ q) := by
  refine Assembly.zeroKnowledge_mono (zeroKnowledge_of_hybrid PS (fun q _ => ε₁ q) hstep)
    (fun q R => le_of_eq ?_)
  simp only [sum_const, card_range, nsmul_eq_mul]

omit [Inhabited D] in
/-- **An error above `1` says nothing**: zero knowledge with `εzk` gives zero knowledge with `min εzk 1`, because every
probability is at most `1`. -/
theorem zeroKnowledge_min_one {εzk : ℕ → ℕ → ℝ≥0∞} (h : ZeroKnowledge M P εzk) :
    ZeroKnowledge M P (fun q R => min (εzk q R) 1) := by
  obtain ⟨S, hS⟩ := h
  refine ⟨S, fun W q R Dist hD => ?_⟩
  obtain ⟨h1, h2⟩ := hS W q R Dist hD
  dsimp only
  have hr : realProb M P W (q + R) Dist ≤ 1 := Hiding.toOuterMeasure_le_one _ _
  have hi : idealProb M P S W (q + R) Dist ≤ 1 := by
    unfold idealProb
    exact Hiding.toOuterMeasure_le_one _ _
  rcases le_total (εzk q R) 1 with hle | hle
  · rw [min_eq_left hle]
    exact ⟨h1, h2⟩
  · rw [min_eq_right hle]
    exact ⟨hr.trans le_add_self, hi.trans le_add_self⟩

omit [Inhabited D] in
/-- **The approved target from per-receipt bounds.** If each hybrid step costs at most `εhv + q·δ`, with the
query-free part `εhv ≤ 2^-120` and the per-query part `δ ≤ 2^-248`, the protocol meets the approved
`εzkTarget q R = q·2^-128 + R·2^-120`. For `R < 2^120` the sum `R·εhv + q·(R·δ)` is below the target; for
`R ≥ 2^120` the target is at least `1`. -/
theorem zeroKnowledge_target_of_hybrid (PS : ProgSim M P SC) (εhv δ : ℝ≥0∞) (hhv : εhv ≤ (2⁻¹ : ℝ≥0∞) ^ 120)
    (hδ : δ ≤ (2⁻¹ : ℝ≥0∞) ^ 248)
    (hstep : ∀ (W : M.Weights) (q R : ℕ) (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool),
      Dist.Within q R → ∀ j < R,
        hybProb PS W (q + R) Dist j ≤ hybProb PS W (q + R) Dist (j + 1) + (εhv + (q : ℝ≥0∞) * δ)
        ∧ hybProb PS W (q + R) Dist (j + 1) ≤ hybProb PS W (q + R) Dist j + (εhv + (q : ℝ≥0∞) * δ)) :
    ZeroKnowledge M P εzkTarget := by
  have h := zeroKnowledge_min_one (zeroKnowledge_of_hybrid_uniform PS (fun q => εhv + (q : ℝ≥0∞) * δ) hstep)
  refine Assembly.zeroKnowledge_mono h (fun q R => ?_)
  have key : (2 : ℝ≥0∞) ^ 120 * (2⁻¹ : ℝ≥0∞) ^ 120 = 1 := by
    rw [← mul_pow, ENNReal.mul_inv_cancel two_ne_zero ENNReal.ofNat_ne_top, one_pow]
  have h248 : (2⁻¹ : ℝ≥0∞) ^ 248 = (2⁻¹ : ℝ≥0∞) ^ 120 * (2⁻¹ : ℝ≥0∞) ^ 128 := pow_add (2⁻¹ : ℝ≥0∞) 120 128
  show min ((R : ℝ≥0∞) * (εhv + (q : ℝ≥0∞) * δ)) 1
    ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 128 + (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120
  rcases lt_or_ge R (2 ^ 120) with hR | hR
  · have hR' : (R : ℝ≥0∞) ≤ 2 ^ 120 := by exact_mod_cast hR.le
    have hRδ : (R : ℝ≥0∞) * δ ≤ (2⁻¹ : ℝ≥0∞) ^ 128 := by
      calc (R : ℝ≥0∞) * δ ≤ 2 ^ 120 * (2⁻¹ : ℝ≥0∞) ^ 248 := mul_le_mul' hR' hδ
        _ = (2 ^ 120 * (2⁻¹ : ℝ≥0∞) ^ 120) * (2⁻¹ : ℝ≥0∞) ^ 128 := by rw [h248, mul_assoc]
        _ = (2⁻¹ : ℝ≥0∞) ^ 128 := by rw [key, one_mul]
    calc min ((R : ℝ≥0∞) * (εhv + (q : ℝ≥0∞) * δ)) 1 ≤ (R : ℝ≥0∞) * (εhv + (q : ℝ≥0∞) * δ) :=
          min_le_left _ _
      _ = (q : ℝ≥0∞) * ((R : ℝ≥0∞) * δ) + (R : ℝ≥0∞) * εhv := by ring
      _ ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 128 + (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120 := by gcongr
  · have hR' : (2 : ℝ≥0∞) ^ 120 ≤ R := by exact_mod_cast hR
    calc min ((R : ℝ≥0∞) * (εhv + (q : ℝ≥0∞) * δ)) 1 ≤ 1 := min_le_right _ _
      _ = 2 ^ 120 * (2⁻¹ : ℝ≥0∞) ^ 120 := key.symm
      _ ≤ (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120 := by gcongr
      _ ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 128 + (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120 := le_add_self

end Hybrid

end ZK60.ZKHybrid
