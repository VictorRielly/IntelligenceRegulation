/-
D63 lane L42 (2026-11-10), part 3: **the test the ruling exists for**: the gap audit's leaky toy (finding GB-1,
`results/zk60_gap_audit_faithfulness_20261110/GB_Toys.lean`) against the approved statements of D76.

The toy `leaky M` publishes its input in clear in every statement and declares the whole input as its leakage. The gap
audit proved it satisfies the instance-leak gate `ProductionReady` at every error (`leaky_productionReady`, re-proved
here in the library). Against the approved statements, where the allowed leakage `Λ` is named in the statement:

* `readDist`, `readDist_within`: the distinguisher (ONE proof request, no hash query) that asks for a receipt on `x`
  and answers whether a reader of the receipt returns `x`;
* **`zeroKnowledgeL_reader_half`**: if a reader recovers the input from the receipts of two DIFFERENT inputs `x₀`,
  `x₁` with the same allowed leakage and the same public output part, then `ZeroKnowledgeL` at `Λ` needs
  `εzk 0 1 ≥ 1/2`: in the ideal world the simulator is shown the same thing for both, so one of the two
  distinguishers wins with probability at most 1/2 there and with probability 1 in the real world;
* **`leaky_not_zeroKnowledgeL`**, **`leaky_not_productionReadyL`**: so the toy satisfies neither at any error with
  `εzk 0 1 < 1/2`, in particular not at the approved target (`εzkTarget 0 1 = 2^-120`,
  `leaky_not_productionReadyL_target`);
* **`productionReadyL_no_reader`**, **`productionReadyL_ne_leaky`**: a protocol satisfying `ProductionReadyL` at `Λ`
  (with `εzk 0 1 < 1/2`) has no reader of that kind, and is not the leaky toy;
* **`leaky_not_productionReadyL_classify`**: for the media app's own model and `classifyLeak`: two different items with
  the same `classifySpec` result (the same verdict, or both refused) suffice; **`leaky_not_productionReadyL_classify'`**
  needs no such premise (two refused items, ids `p` and `p + 1`, exist whenever `T ≥ 1` and the public data are
  valid).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.StatementsD76Bridge
import ZK60Formal.StatementsD76Leak
import ZK60Formal.ZKHybrid
import ZK60Formal.ProtocolClassify

set_option autoImplicit false
set_option linter.unusedSectionVars false

namespace ZK60.D76

open scoped ENNReal
open ZK60

/-! ## The leaky toy (the gap audit's, unchanged) -/

/-- The toy's public statement: the input, the public output part and the hidden output part, all in the clear. -/
structure LStmt (M : IntModel) where
  x : M.Input
  pub : M.PubOut
  hid : M.HidOut

variable {Q D Coins : Type}

open Classical in
/-- **The leaky toy** (gap audit GB-1). The statement is the input and both output parts in the clear; the receipt is
empty; the verifier recomputes the model; "opens" means "is the value written in the statement"; the declared leakage
is the whole input. Nothing is hidden. -/
noncomputable def leaky (M : IntModel) : Protocol Q D Coins M where
  Stmt := LStmt M
  Receipt := Unit
  Salt := Unit
  Leak := M.Input
  leak := id
  ypub s := s.pub
  opensIn _ s x _ := s.x = x
  opensOut _ s y _ := s.hid = y
  prove _ W x _ := (⟨x, M.publicPart (M.forward W x), M.hiddenPart (M.forward W x)⟩, ())
  verify _ W s _ :=
    decide (M.admissible s.x ∧ s.pub = M.publicPart (M.forward W s.x) ∧ s.hid = M.hiddenPart (M.forward W s.x))

/-- The toy publishes the input: the statement of every receipt carries it. -/
theorem leaky_publishes_input (M : IntModel) (H : Q → D) (W : M.Weights) (x : M.Input) (c : Coins) :
    ((leaky (Q := Q) (D := D) (Coins := Coins) M).prove H W x c).1.x = x := rfl

open Classical in
theorem leaky_verify_iff (M : IntModel) (H : Q → D) (W : M.Weights) (s : LStmt M) (r : Unit) :
    (leaky (Q := Q) (D := D) (Coins := Coins) M).verify H W s r = true
      ↔ (M.admissible s.x ∧ s.pub = M.publicPart (M.forward W s.x) ∧ s.hid = M.hiddenPart (M.forward W s.x)) :=
  decide_eq_true_iff

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-! ## It passes the instance-leak gate (the gap audit's `leaky_productionReady`, re-proved in the library) -/

theorem leaky_complete (M : IntModel) (εc : ℝ≥0∞) : Complete M (leaky (Q := Q) (D := D) (Coins := Coins) M) εc := by
  intro W x hx
  have h1 : prHC (Q := Q) (D := D) (Coins := Coins) (fun H c =>
      let sr := (leaky (Q := Q) (D := D) (Coins := Coins) M).prove H W x c
      (leaky M).verify H W sr.1 sr.2 = true
      ∧ (leaky M).ypub sr.1 = M.publicPart (M.forward W x)
      ∧ (∃ r, (leaky M).opensIn H sr.1 x r)
      ∧ (∃ r, (leaky M).opensOut H sr.1 (M.hiddenPart (M.forward W x)) r)) = 1 := by
    unfold prHC
    rw [PMF.toOuterMeasure_apply_eq_one_iff]
    intro p _
    exact ⟨(leaky_verify_iff M p.1 W _ ()).mpr ⟨hx, rfl, rfl⟩, rfl, ⟨(), rfl⟩, ⟨(), rfl⟩⟩
  rw [h1]
  exact tsub_le_self

theorem leaky_sound (M : IntModel) (εs : ℕ → ℝ≥0∞) :
    KnowledgeSound M (leaky (Q := Q) (D := D) (Coins := Coins) M) εs := by
  refine ⟨fun _ s _ => (s.x, (), ()), fun W q A _ => ?_⟩
  have h0 : prH (Q := Q) (D := D) (fun H =>
      let out := A.runLog H
      let s := out.1.1
      let pf := out.1.2
      let e := (fun (_ : List (Q × D)) (s : (leaky (Q := Q) (D := D) (Coins := Coins) M).Stmt)
        (_ : (leaky (Q := Q) (D := D) (Coins := Coins) M).Receipt) => (s.x, (), ())) out.2 s pf
      (leaky (Q := Q) (D := D) (Coins := Coins) M).verify H W s pf = true
      ∧ ¬ (M.admissible e.1
            ∧ (leaky (Q := Q) (D := D) (Coins := Coins) M).opensIn H s e.1 e.2.1
            ∧ (leaky (Q := Q) (D := D) (Coins := Coins) M).ypub s = M.publicPart (M.forward W e.1)
            ∧ (leaky (Q := Q) (D := D) (Coins := Coins) M).opensOut H s (M.hiddenPart (M.forward W e.1)) e.2.2))
      = 0 := by
    unfold prH
    rw [PMF.toOuterMeasure_apply_eq_zero_iff]
    refine Set.disjoint_right.mpr fun H hH _ => ?_
    obtain ⟨hv, hn⟩ := hH
    have hv' := (leaky_verify_iff M H W _ _).mp hv
    exact hn ⟨hv'.1, rfl, hv'.2.1, hv'.2.2⟩
  rw [h0]
  exact zero_le

theorem leaky_binding (M : IntModel) (εb : ℕ → ℝ≥0∞) :
    Binding M (leaky (Q := Q) (D := D) (Coins := Coins) M) εb := by
  refine ⟨fun q A _ => ?_, fun q A _ => ?_⟩
  · have h0 : prH (Q := Q) (D := D) (fun H =>
        let o := A.run H
        o.2.1 ≠ o.2.2.2.1 ∧ (leaky (Q := Q) (D := D) (Coins := Coins) M).opensIn H o.1 o.2.1 o.2.2.1
          ∧ (leaky (Q := Q) (D := D) (Coins := Coins) M).opensIn H o.1 o.2.2.2.1 o.2.2.2.2) = 0 := by
      unfold prH
      rw [PMF.toOuterMeasure_apply_eq_zero_iff]
      refine Set.disjoint_right.mpr fun H hH _ => ?_
      obtain ⟨hne, h1, h2⟩ := hH
      exact hne (h1.symm.trans h2)
    rw [h0]
    exact zero_le
  · have h0 : prH (Q := Q) (D := D) (fun H =>
        let o := A.run H
        o.2.1 ≠ o.2.2.2.1 ∧ (leaky (Q := Q) (D := D) (Coins := Coins) M).opensOut H o.1 o.2.1 o.2.2.1
          ∧ (leaky (Q := Q) (D := D) (Coins := Coins) M).opensOut H o.1 o.2.2.2.1 o.2.2.2.2) = 0 := by
      unfold prH
      rw [PMF.toOuterMeasure_apply_eq_zero_iff]
      refine Set.disjoint_right.mpr fun H hH _ => ?_
      obtain ⟨hne, h1, h2⟩ := hH
      exact hne (h1.symm.trans h2)
    rw [h0]
    exact zero_le

/-- The leaky toy's programming simulator: it is HANDED the input as the declared leakage, so it runs the honest
prover (which ignores the oracle and the coins) and programs nothing. -/
noncomputable def leakySim (M : IntModel) : ZKHybrid.ProgSim M (leaky (Q := Q) (D := D) (Coins := Coins) M) Unit where
  sim W H z _ := ((leaky (Q := Q) (D := D) (Coins := Coins) M).prove H W z.2 default, [])

theorem leaky_hybStep_eq (M : IntModel) (W : M.Weights) (H : Q → D) (j : ℕ) :
    ZKHybrid.hybStep (leakySim (Q := Q) (D := D) (Coins := Coins) M) W H j
      = ZKHybrid.hybStep (leakySim (Q := Q) (D := D) (Coins := Coins) M) W H 0 := by
  funext st i c
  cases i with
  | inl qq => rfl
  | inr x =>
    by_cases h : st.1 < j
    · simp [ZKHybrid.hybStep, h, leakySim, leaky]
    · simp [ZKHybrid.hybStep, h, leaky]

theorem leaky_zk (M : IntModel) (εzk : ℕ → ℕ → ℝ≥0∞) :
    ZeroKnowledge M (leaky (Q := Q) (D := D) (Coins := Coins) M) εzk := by
  have h := ZKHybrid.zeroKnowledge_of_hybrid (leakySim (Q := Q) (D := D) (Coins := Coins) M) (fun _ _ => 0)
    (fun W q R Dist _ j _ => by
      have e : ZKHybrid.hybProb (leakySim (Q := Q) (D := D) (Coins := Coins) M) W (q + R) Dist j
          = ZKHybrid.hybProb (leakySim (Q := Q) (D := D) (Coins := Coins) M) W (q + R) Dist (j + 1) := by
        unfold ZKHybrid.hybProb
        congr 1
        ext p
        simp only [Set.mem_ofPred_eq]
        rw [leaky_hybStep_eq M W p.1 j, leaky_hybStep_eq M W p.1 (j + 1)]
      exact ⟨by rw [e, add_zero], by rw [e, add_zero]⟩)
  exact Assembly.zeroKnowledge_mono h (fun q R => by simp)

/-- **The leaky toy passes the instance-leak gate `ProductionReady` at every error** (the gap audit's
`leaky_productionReady`, GB-1), for every integer model, with `Statements.lean`'s own `trivialArith`. -/
theorem leaky_productionReady (M : IntModel) (εc : ℝ≥0∞) (εs εb : ℕ → ℝ≥0∞) (εzk : ℕ → ℕ → ℝ≥0∞) :
    ProductionReady M (trivialArith M) (leaky (Q := Q) (D := D) (Coins := Coins) M) εc εs εb εzk where
  circuit := trivialArith_circuitIff M
  complete := leaky_complete M εc
  sound := leaky_sound M εs
  binding := leaky_binding M εb
  zk := leaky_zk M εzk
  semantic := Assembly.semanticHiding_of_zeroKnowledge _ (leaky_zk M εzk)

/-! ## The distinguisher -/

section Dist

variable {M : IntModel} (P : Protocol Q D Coins M)

open Classical in
/-- The distinguisher's verdict on the answer it gets: `true` exactly when it is a receipt on which `read` returns
`x`. -/
noncomputable def readOut (read : P.Stmt × P.Receipt → M.Input) (x : M.Input) :
    D ⊕ (P.Stmt × P.Receipt) → Bool
  | .inl _ => false
  | .inr sr => decide (read sr = x)

/-- **The test's distinguisher**: ONE proof request, on `x`, no hash query; it answers `true` exactly when `read`
returns `x` on the receipt it gets. -/
noncomputable def readDist (read : P.Stmt × P.Receipt → M.Input) (x : M.Input) :
    OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool :=
  .ask (.inr x) fun o => .ret (readOut P read x o)

theorem readDist_within (read : P.Stmt × P.Receipt → M.Input) (x : M.Input) :
    (readDist P read x).Within 0 1 :=
  fun _ => trivial

/-- Its run against any responder: the answer to the one request decides. -/
theorem readDist_runState {σ ρ : Type} (read : P.Stmt × P.Receipt → M.Input) (x : M.Input)
    (step : σ → Q ⊕ M.Input → ρ → (D ⊕ (P.Stmt × P.Receipt)) × σ) (rand : ℕ → ρ) (s : σ) :
    (readDist P read x).runState step rand 0 s = readOut P read x (step s (.inr x) (rand 0)).1 := rfl

/-- The verdict on a receipt is `true` exactly when `read` returns `x`. -/
theorem readOut_inr (read : P.Stmt × P.Receipt → M.Input) (x : M.Input) (sr : P.Stmt × P.Receipt) :
    readOut P read x (.inr sr) = true ↔ read sr = x := by
  classical
  simp [readOut]

/-- ONE answer cannot win for two different inputs. -/
theorem readOut_eq (read : P.Stmt × P.Receipt → M.Input) {x₀ x₁ : M.Input} (o : D ⊕ (P.Stmt × P.Receipt))
    (h0 : readOut P read x₀ o = true) (h1 : readOut P read x₁ o = true) : x₀ = x₁ := by
  cases o with
  | inl _ => exact absurd h0 (by simp [readOut])
  | inr sr => exact ((readOut_inr P read x₀ sr).mp h0).symm.trans ((readOut_inr P read x₁ sr).mp h1)

/-- Two disjoint events of a `PMF` have total probability at most `1`. -/
theorem pmf_add_le_one_of_disjoint {α : Type} (p : PMF α) (s t : Set α) (h : Disjoint s t) :
    p.toOuterMeasure s + p.toOuterMeasure t ≤ 1 := by
  rw [PMF.toOuterMeasure_apply, PMF.toOuterMeasure_apply, ← ENNReal.tsum_add]
  calc ∑' a, (s.indicator p a + t.indicator p a) = ∑' a, (s ∪ t).indicator p a := by
        rw [Set.indicator_union_of_disjoint h]
    _ = p.toOuterMeasure (s ∪ t) := (PMF.toOuterMeasure_apply p _).symm
    _ ≤ p.toOuterMeasure Set.univ := MeasureTheory.measure_mono (Set.subset_univ _)
    _ = 1 := (PMF.toOuterMeasure_apply_eq_one_iff p _).mpr (Set.subset_univ _)

/-- `1 ≤ ε + ε` gives `1/2 ≤ ε`. -/
theorem half_le_of_one_le_two {ε : ℝ≥0∞} (h : 1 ≤ ε + ε) : 2⁻¹ ≤ ε := by
  rw [← two_mul] at h
  have := ENNReal.div_le_of_le_mul' h
  rwa [one_div] at this

open Classical in
/-- **A reader of the input defeats the approved zero-knowledge statement.** If, for two DIFFERENT inputs `x₀`, `x₁`
with the same allowed leakage `Λ` and the same public output part (at weights `W`), a function `read` of the receipt
returns the input on every honest receipt of `x₀` and of `x₁`, then `ZeroKnowledgeL M P Λ εzk` forces
`εzk 0 1 ≥ 1/2`. The two distinguishers `readDist P read x₀` and `readDist P read x₁` each win with probability `1`
in the real world; in the ideal world the simulator is shown the same `(public part, Λ)` for both requests, so their
wins are disjoint events of ONE run, of total probability at most `1`. -/
theorem zeroKnowledgeL_reader_half {L : Type} (Λ : M.Input → L) {εzk : ℕ → ℕ → ℝ≥0∞}
    (h : ZeroKnowledgeL M P Λ εzk) (W : M.Weights) (x₀ x₁ : M.Input) (hne : x₀ ≠ x₁) (hΛ : Λ x₀ = Λ x₁)
    (hpub : M.publicPart (M.forward W x₀) = M.publicPart (M.forward W x₁))
    (read : P.Stmt × P.Receipt → M.Input)
    (hread : ∀ H c, read (P.prove H W x₀ c) = x₀ ∧ read (P.prove H W x₁ c) = x₁) : 2⁻¹ ≤ εzk 0 1 := by
  obtain ⟨S, hS⟩ := h
  have h64 : (1 : ℕ) ≤ 2 ^ 64 := Nat.one_le_two_pow
  have hA := (hS W 0 1 (readDist P read x₀) (Nat.zero_le _) h64 (readDist_within P read x₀)).1
  have hB := (hS W 0 1 (readDist P read x₁) (Nat.zero_le _) h64 (readDist_within P read x₁)).1
  -- the real world: each distinguisher wins with probability 1
  have hrA : realProb M P W (0 + 1) (readDist P read x₀) = 1 := by
    unfold realProb
    rw [PMF.toOuterMeasure_apply_eq_one_iff]
    intro p _
    show (readDist P read x₀).runState _ _ 0 () = true
    rw [readDist_runState]
    exact (readOut_inr P read x₀ _).mpr (hread p.1 _).1
  have hrB : realProb M P W (0 + 1) (readDist P read x₁) = 1 := by
    unfold realProb
    rw [PMF.toOuterMeasure_apply_eq_one_iff]
    intro p _
    show (readDist P read x₁).runState _ _ 0 () = true
    rw [readDist_runState]
    exact (readOut_inr P read x₁ _).mpr (hread p.1 _).2
  -- the ideal world: the two wins are disjoint events of one run
  have hid : idealProbL M P Λ S W (0 + 1) (readDist P read x₀) + idealProbL M P Λ S W (0 + 1) (readDist P read x₁)
      ≤ 1 := by
    unfold idealProbL
    refine pmf_add_le_one_of_disjoint _ _ _ (Set.disjoint_left.mpr fun sc h0 h1 => hne ?_)
    simp only [Set.mem_ofPred_eq, readDist_runState, Sum.map_inr, hpub, hΛ] at h0 h1
    exact readOut_eq P read _ h0 h1
  rw [hrA] at hA
  rw [hrB] at hB
  apply half_le_of_one_le_two
  have h2 : 1 + 1 ≤ 1 + (εzk 0 1 + εzk 0 1) :=
    calc 1 + 1 ≤ (idealProbL M P Λ S W (0 + 1) (readDist P read x₀) + εzk 0 1)
          + (idealProbL M P Λ S W (0 + 1) (readDist P read x₁) + εzk 0 1) := add_le_add hA hB
      _ = (idealProbL M P Λ S W (0 + 1) (readDist P read x₀) + idealProbL M P Λ S W (0 + 1) (readDist P read x₁))
          + (εzk 0 1 + εzk 0 1) := by ring
      _ ≤ 1 + (εzk 0 1 + εzk 0 1) := add_le_add hid le_rfl
  exact (ENNReal.add_le_add_iff_left ENNReal.one_ne_top).mp h2

/-- **A protocol meeting the approved gate (D76) at an error `εzk 0 1 < 1/2` has no reader** of two different inputs
with the same allowed leakage and the same public output part. -/
theorem productionReadyL_no_reader {A : Arith M} {L : Type} (Λ : M.Input → L) {εc : ℝ≥0∞} {εs εb : ℕ → ℝ≥0∞}
    {εzk : ℕ → ℕ → ℝ≥0∞} (h : ProductionReadyL M A P Λ εc εs εb εzk) (hε : εzk 0 1 < 2⁻¹) (W : M.Weights)
    (x₀ x₁ : M.Input) (hne : x₀ ≠ x₁) (hΛ : Λ x₀ = Λ x₁)
    (hpub : M.publicPart (M.forward W x₀) = M.publicPart (M.forward W x₁)) :
    ¬ ∃ read : P.Stmt × P.Receipt → M.Input,
      ∀ H c, read (P.prove H W x₀ c) = x₀ ∧ read (P.prove H W x₁ c) = x₁ := by
  rintro ⟨read, hread⟩
  exact absurd (zeroKnowledgeL_reader_half P Λ h.zk W x₀ x₁ hne hΛ hpub read hread) (not_le.mpr hε)

end Dist

/-! ## The leaky toy fails the approved statements -/

section Leaky

variable {M : IntModel}

/-- **The leaky toy fails the approved zero-knowledge statement**: for two different inputs with the same allowed
leakage and the same public output part, `ZeroKnowledgeL M (leaky M) Λ εzk` forces `εzk 0 1 ≥ 1/2` (the reader is the
statement's input field). -/
theorem leaky_not_zeroKnowledgeL {L : Type} (Λ : M.Input → L) {εzk : ℕ → ℕ → ℝ≥0∞} (W : M.Weights)
    (x₀ x₁ : M.Input) (hne : x₀ ≠ x₁) (hΛ : Λ x₀ = Λ x₁)
    (hpub : M.publicPart (M.forward W x₀) = M.publicPart (M.forward W x₁))
    (h : ZeroKnowledgeL M (leaky (Q := Q) (D := D) (Coins := Coins) M) Λ εzk) : 2⁻¹ ≤ εzk 0 1 :=
  zeroKnowledgeL_reader_half _ Λ h W x₀ x₁ hne hΛ hpub (fun sr => sr.1.x) fun _ _ => ⟨rfl, rfl⟩

/-- **The leaky toy fails the approved gate (D76)** at every error with `εzk 0 1 < 1/2`, whatever the constraint
system and the other errors. -/
theorem leaky_not_productionReadyL {A : Arith M} {L : Type} (Λ : M.Input → L) {εc : ℝ≥0∞} {εs εb : ℕ → ℝ≥0∞}
    {εzk : ℕ → ℕ → ℝ≥0∞} (hε : εzk 0 1 < 2⁻¹) (W : M.Weights) (x₀ x₁ : M.Input) (hne : x₀ ≠ x₁)
    (hΛ : Λ x₀ = Λ x₁) (hpub : M.publicPart (M.forward W x₀) = M.publicPart (M.forward W x₁)) :
    ¬ ProductionReadyL M A (leaky (Q := Q) (D := D) (Coins := Coins) M) Λ εc εs εb εzk := fun h =>
  absurd (leaky_not_zeroKnowledgeL Λ W x₀ x₁ hne hΛ hpub h.zk) (not_le.mpr hε)

/-- The approved zero-knowledge target at no hash query and one receipt is `2^-120 < 1/2`. -/
theorem εzkTarget_zero_one_lt_half : εzkTarget 0 1 < 2⁻¹ := by
  unfold εzkTarget
  simp only [Nat.cast_zero, zero_mul, Nat.cast_one, one_mul, zero_add]
  have h1 : (2⁻¹ : ℝ≥0∞) ^ 120 ≤ 2⁻¹ * 2⁻¹ := by
    rw [show (120 : ℕ) = 2 + 118 by norm_num, pow_add, pow_two]
    calc (2⁻¹ : ℝ≥0∞) * 2⁻¹ * (2⁻¹ : ℝ≥0∞) ^ 118 ≤ 2⁻¹ * 2⁻¹ * 1 :=
          mul_le_mul_right (pow_le_one₀ zero_le (ENNReal.inv_le_one.mpr one_le_two)) _
      _ = 2⁻¹ * 2⁻¹ := mul_one _
  have h2 : (2⁻¹ : ℝ≥0∞) * 2⁻¹ < 1 * 2⁻¹ :=
    ENNReal.mul_lt_mul_left (by simp) (by simp) (ENNReal.inv_lt_one.mpr ENNReal.one_lt_two)
  calc (2⁻¹ : ℝ≥0∞) ^ 120 ≤ 2⁻¹ * 2⁻¹ := h1
    _ < 1 * 2⁻¹ := h2
    _ = 2⁻¹ := one_mul _

/-- **The leaky toy fails the approved gate at the approved targets.** -/
theorem leaky_not_productionReadyL_target {A : Arith M} {L : Type} (Λ : M.Input → L) (W : M.Weights)
    (x₀ x₁ : M.Input) (hne : x₀ ≠ x₁) (hΛ : Λ x₀ = Λ x₁)
    (hpub : M.publicPart (M.forward W x₀) = M.publicPart (M.forward W x₁)) :
    ¬ ProductionReadyL M A (leaky (Q := Q) (D := D) (Coins := Coins) M) Λ εcTarget εsTarget εsTarget εzkTarget :=
  leaky_not_productionReadyL Λ εzkTarget_zero_one_lt_half W x₀ x₁ hne hΛ hpub

/-- **A protocol meeting the approved gate (D76) at an error `εzk 0 1 < 1/2` is not the leaky toy**, as soon as the
model has two different inputs with the same allowed leakage and the same public output part. -/
theorem productionReadyL_ne_leaky {A : Arith M} {L : Type} (Λ : M.Input → L) (P : Protocol Q D Coins M)
    {εc : ℝ≥0∞} {εs εb : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞} (h : ProductionReadyL M A P Λ εc εs εb εzk)
    (hε : εzk 0 1 < 2⁻¹) (W : M.Weights) (x₀ x₁ : M.Input) (hne : x₀ ≠ x₁) (hΛ : Λ x₀ = Λ x₁)
    (hpub : M.publicPart (M.forward W x₀) = M.publicPart (M.forward W x₁)) : P ≠ leaky M := by
  rintro rfl
  exact leaky_not_productionReadyL Λ hε W x₀ x₁ hne hΛ hpub h

/-- **Old gate passed, approved gate failed, side by side**: the same protocol satisfies the instance-leak gate at
errors `0` and fails the approved gate at the approved targets. -/
theorem leaky_old_passes_new_fails {L : Type} (Λ : M.Input → L) (W : M.Weights) (x₀ x₁ : M.Input) (hne : x₀ ≠ x₁)
    (hΛ : Λ x₀ = Λ x₁) (hpub : M.publicPart (M.forward W x₀) = M.publicPart (M.forward W x₁)) :
    ProductionReady M (trivialArith M) (leaky (Q := Q) (D := D) (Coins := Coins) M) 0 (fun _ => 0) (fun _ => 0)
        (fun _ _ => 0)
      ∧ ¬ ProductionReadyL M (trivialArith M) (leaky (Q := Q) (D := D) (Coins := Coins) M) Λ εcTarget εsTarget
          εsTarget εzkTarget :=
  ⟨leaky_productionReady M _ _ _ _, leaky_not_productionReadyL_target Λ W x₀ x₁ hne hΛ hpub⟩

end Leaky

/-! ## The media classifier -/

section Classify

open ZK60.TokenRun ZK60.ProtocolClassify
open ZK60.Block (BlockShape)

variable {S : BlockShape}

/-- Two items with the same `classifySpec` result have the same allowed leakage. -/
theorem classifyLeak_eq_of_spec (R : ClassifyRunPublic S) {x₀ x₁ : S.Tok → ℕ}
    (h : classifySpec R x₀ = classifySpec R x₁) : classifyLeak S R x₀ = classifyLeak S R x₁ := by
  unfold classifyLeak
  rw [h]

/-- **The leaky toy fails the approved gate for the media app's own model, constraint system and allowed leakage**
(`classifyModel`, `classifyArith`, `classifyLeak`), at the approved targets: two different items with the same
`classifySpec` result (the same verdict, or both refused) suffice. Compare `leaky_productionReady_classify` (gap
audit): it passes the instance-leak gate. -/
theorem leaky_not_productionReadyL_classify (R : ClassifyRunPublic S) (x₀ x₁ : S.Tok → ℕ) (hne : x₀ ≠ x₁)
    (h : classifySpec R x₀ = classifySpec R x₁) :
    ¬ ProductionReadyL (classifyModel S R) (classifyArith S R)
      (leaky (Q := Q) (D := D) (Coins := Coins) (classifyModel S R)) (classifyLeak S R)
      εcTarget εsTarget εsTarget εzkTarget :=
  leaky_not_productionReadyL_target (M := classifyModel S R) (A := classifyArith S R) (classifyLeak S R) () x₀ x₁
    hne (classifyLeak_eq_of_spec R h) (congrArg (fun o => o.getD 0) h)

/-- An item with an id at or above `p` (the Goldilocks prime) is refused by the integer model. -/
theorem classifySpec_none_of_ge (R : ClassifyRunPublic S) (hR : R.Valid) (x : S.Tok → ℕ) (t : S.Tok)
    (ht : Circuit.gP ≤ x t) : classifySpec R x = none := by
  cases hs : classifySpec R x with
  | none => rfl
  | some b =>
    exact absurd ht (not_le.mpr (admissible_canon R hR x ⟨b, hs⟩ t))

/-- **The same with no premise on the items**: whenever the token count is at least one and the public data are
valid, the two items with every id `p`, and every id `p + 1`, are different and both refused, so they have the same
`classifySpec` result. -/
theorem leaky_not_productionReadyL_classify' (R : ClassifyRunPublic S) (hR : R.Valid) (hT : 0 < S.T) :
    ¬ ProductionReadyL (classifyModel S R) (classifyArith S R)
      (leaky (Q := Q) (D := D) (Coins := Coins) (classifyModel S R)) (classifyLeak S R)
      εcTarget εsTarget εsTarget εzkTarget := by
  have t : S.Tok := ⟨0, hT⟩
  refine leaky_not_productionReadyL_classify R (fun _ => Circuit.gP) (fun _ => Circuit.gP + 1)
    (fun he => ?_) ?_
  · have := congrFun he t
    omega
  · rw [classifySpec_none_of_ge R hR _ t le_rfl, classifySpec_none_of_ge R hR _ t (Nat.le_succ _)]

end Classify

end ZK60.D76
