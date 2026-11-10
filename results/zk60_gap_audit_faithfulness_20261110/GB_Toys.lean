/-
Gap audit (faithfulness), 2026-11-10: SCRATCH, not a library file. Toy instances of the approved statements
(`formal/ZK60Formal/Statements.lean`, unchanged) that test what `ProductionReady` certifies by itself.

1. `leaky`: a protocol whose public statement carries the hidden input IN THE CLEAR, and whose declared leakage is the
   whole input (`Leak := M.Input`, `leak := id`). `leaky_productionReady` proves `ProductionReady` for it at EVERY
   error (in particular at errors 0, and at the approved targets), for EVERY integer model `M`;
   `leaky_productionReady_classify` does it for the media app's own `classifyModel S R` with its own `classifyArith`.
   `leaky_publishes_input`: its published statement contains the input. So `ProductionReady` alone does not say that
   anything is hidden; the hiding is in the instance's choice of `Leak` / `leak` (and `PubOut` / `publicPart`).
2. `circuit_field_free`: the `circuit` field constrains nothing about the protocol: any `ProductionReady M A P …`
   gives `ProductionReady M (trivialArith M) P …` (the field is about an `Arith` that no other field mentions).

Only `propext`, `Classical.choice`, `Quot.sound` are expected (checked by `#print axioms` at the end).
-/
import ZK60Formal.ZKHybrid
import ZK60Formal.CircuitTokenRun

set_option autoImplicit false
set_option linter.unusedSectionVars false

namespace ZK60.GapAudit

open scoped ENNReal
open ZK60

/-! ## 1. A protocol that publishes the input -/

/-- The toy's public statement: the input, the public output part and the hidden output part, all in the clear. -/
structure LStmt (M : IntModel) where
  x : M.Input
  pub : M.PubOut
  hid : M.HidOut

variable {Q D Coins : Type}

open Classical in
/-- **The leaky toy.** The statement is the input and both output parts in the clear; the receipt is empty; the
verifier recomputes the model; "opens" means "is the value written in the statement"; the declared leakage is the
whole input. Nothing is hidden. -/
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
/-- The toy's verifier accepts exactly when the statement's input is admissible and its two output parts are the
model's. -/
theorem leaky_verify_iff (M : IntModel) (H : Q → D) (W : M.Weights) (s : LStmt M) (r : Unit) :
    (leaky (Q := Q) (D := D) (Coins := Coins) M).verify H W s r = true
      ↔ (M.admissible s.x ∧ s.pub = M.publicPart (M.forward W s.x) ∧ s.hid = M.hiddenPart (M.forward W s.x)) :=
  decide_eq_true_iff

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

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

/-- Every hybrid responder of the toy is the same function: a simulated receipt IS the honest one. -/
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

/-- **`ProductionReady` holds for the leaky toy, at every error** (so at errors `0` and at the approved targets), for
every integer model, with Statements.lean's own `trivialArith`. -/
theorem leaky_productionReady (M : IntModel) (εc : ℝ≥0∞) (εs εb : ℕ → ℝ≥0∞) (εzk : ℕ → ℕ → ℝ≥0∞) :
    ProductionReady M (trivialArith M) (leaky (Q := Q) (D := D) (Coins := Coins) M) εc εs εb εzk where
  circuit := trivialArith_circuitIff M
  complete := leaky_complete M εc
  sound := leaky_sound M εs
  binding := leaky_binding M εb
  zk := leaky_zk M εzk
  semantic := Assembly.semanticHiding_of_zeroKnowledge _ (leaky_zk M εzk)

/-- At the approved targets and errors `0` side by side. -/
theorem leaky_productionReady_targets (M : IntModel) :
    ProductionReady M (trivialArith M) (leaky (Q := Q) (D := D) (Coins := Coins) M)
      εcTarget εsTarget εsTarget εzkTarget
    ∧ ProductionReady M (trivialArith M) (leaky (Q := Q) (D := D) (Coins := Coins) M) 0 (fun _ => 0) (fun _ => 0)
      (fun _ _ => 0) :=
  ⟨leaky_productionReady M _ _ _ _, leaky_productionReady M _ _ _ _⟩

/-- **The same for the media app's own integer model and constraint system** (`classifyModel S R`,
`classifyArith S R`, under the same validity premises the real gate takes for `CircuitIff`): a protocol that publishes
the item's token ids passes the approved gate at the approved targets. -/
theorem leaky_productionReady_classify {S : Block.BlockShape} (hS : S.Valid) (R : TokenRun.ClassifyRunPublic S)
    (hR : R.Valid) :
    ProductionReady (TokenRun.classifyModel S R) (TokenRun.classifyArith S R)
      (leaky (Q := Q) (D := D) (Coins := Coins) (TokenRun.classifyModel S R)) εcTarget εsTarget εsTarget εzkTarget where
  circuit := TokenRun.classifyRun_circuitIff hS R hR
  complete := leaky_complete _ _
  sound := leaky_sound _ _
  binding := leaky_binding _ _
  zk := leaky_zk _ _
  semantic := Assembly.semanticHiding_of_zeroKnowledge _ (leaky_zk _ _)

/-! ## 2. The `circuit` field constrains nothing about the protocol -/

/-- Any bundle with any constraint system `A` gives the bundle with Statements.lean's `trivialArith`, which satisfies
`CircuitIff` for every model by definition. The `Arith` is mentioned by no other field. -/
theorem circuit_field_free (M : IntModel) (A : Arith M) (P : Protocol Q D Coins M) {εc : ℝ≥0∞}
    {εs εb : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞} (h : ProductionReady M A P εc εs εb εzk) :
    ProductionReady M (trivialArith M) P εc εs εb εzk :=
  { h with circuit := trivialArith_circuitIff M }

end ZK60.GapAudit

#print axioms ZK60.GapAudit.leaky_publishes_input
#print axioms ZK60.GapAudit.leaky_productionReady
#print axioms ZK60.GapAudit.leaky_productionReady_targets
#print axioms ZK60.GapAudit.leaky_productionReady_classify
#print axioms ZK60.GapAudit.circuit_field_free
