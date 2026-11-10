/-
D63 lane L42 (2026-11-10): DRAFT of the D76 block of `Statements.lean` (iterated here so that an iteration does not
rebuild the library; moved into `Statements.lean` verbatim, and this file deleted, before the lane's final commit).
-/
import ZK60Formal.Statements

namespace ZK60

open scoped ENNReal

variable {Q D Coins : Type}
  [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
  [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-! ## D76: THE APPROVED zero-knowledge statements, with the allowed leakage named in the statement

Victor's ruling D76 (2026-11-10) amends the approved statements in two ways.
1. The allowed leakage is an explicit argument `Λ : M.Input → L` of the statements, not a field of the protocol
   instance: the simulator sees each request only through the public output part and `Λ x`. The production theorem
   names `Λ`. For the media classifier `Λ x` is (the token count `T`, the width `d`, the layer count `L`, whether the
   request is served); the verdict is the model's public output part.
2. Zero knowledge is asked for distinguishers making at most `q ≤ 2^64` hash queries and at most `R ≤ 2^64` proof
   requests (it was every `q` and `R`); semantic hiding for adversaries making at most `q ≤ 2^64` hash queries. The
   error target `εzkTarget q R = q·2^-128 + R·2^-120` is unchanged. -/

/-- **A simulator for the allowed leakage `L`** (D76): it answers hash queries itself (it may program the oracle) and
produces receipts from the public output part and the allowed leakage only — never from the input, and never from
anything the protocol instance chooses. -/
structure SimulatorL (M : IntModel) (P : Protocol Q D Coins M) (L : Type) where
  State : Type
  SCoins : Type
  [fin : Fintype SCoins]
  [ne : Nonempty SCoins]
  [inh : Inhabited SCoins]
  init : M.Weights → State
  step : State → Q ⊕ (M.PubOut × L) → SCoins → (D ⊕ (P.Stmt × P.Receipt)) × State

/-- The distinguisher's view in the ideal world for the allowed leakage `Λ` (D76): everything comes from the
simulator, which sees each request only through `(publicPart (forward W x), Λ x)`. -/
noncomputable def idealProbL (M : IntModel) (P : Protocol Q D Coins M) {L : Type} (Λ : M.Input → L)
    (S : SimulatorL M P L) (W : M.Weights) (n : ℕ)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) : ℝ≥0∞ :=
  haveI := S.fin; haveI := S.ne; haveI := S.inh
  (PMF.uniformOfFintype (Fin n → S.SCoins)).toOuterMeasure
    {sc | Dist.runState
          (fun (s : S.State) (i : Q ⊕ M.Input) (c : S.SCoins) =>
            S.step s (Sum.map id (fun x => (M.publicPart (M.forward W x), Λ x)) i) c)
          (extend sc) 0 (S.init W) = true}

/-- **T2, zero knowledge in the random-oracle model, THE APPROVED STATEMENT (D76).** One simulator, shown each request
only through the public output part and the allowed leakage `Λ x`, such that no distinguisher making at most
`q ≤ 2^64` hash queries and `R ≤ 2^64` proof requests tells the two worlds apart with advantage above `εzk q R`. -/
def ZeroKnowledgeL (M : IntModel) (P : Protocol Q D Coins M) {L : Type} (Λ : M.Input → L)
    (εzk : ℕ → ℕ → ℝ≥0∞) : Prop :=
  ∃ S : SimulatorL M P L, ∀ (W : M.Weights) (q R : ℕ)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool), q ≤ 2 ^ 64 → R ≤ 2 ^ 64 → Dist.Within q R →
      realProb M P W (q + R) Dist ≤ idealProbL M P Λ S W (q + R) Dist + εzk q R
      ∧ idealProbL M P Λ S W (q + R) Dist ≤ realProb M P W (q + R) Dist + εzk q R

/-- **T2′, the form in D63's own words, THE APPROVED STATEMENT (D76).** For ANY property `g` of the hidden input and
any distribution `μ` of inputs, an adversary that sees a receipt and makes at most `q ≤ 2^64` hash queries guesses `g`
no better than the best guess from the public part and the allowed leakage `Λ` alone, plus `ε q`. -/
def SemanticHidingL (M : IntModel) (P : Protocol Q D Coins M) {L : Type} (Λ : M.Input → L)
    (ε : ℕ → ℝ≥0∞) : Prop :=
  ∀ (W : M.Weights) (μ : PMF M.Input) (β : Type) (g : M.Input → β) (q : ℕ)
    (A : P.Stmt × P.Receipt → OC Q D β), q ≤ 2 ^ 64 → (∀ sr, (A sr).Bounded q) →
    (μ.bind fun X => (PMF.uniformOfFintype ((Q → D) × Coins)).map fun p => (X, p)).toOuterMeasure
        {t | (A (P.prove t.2.1 W t.1 t.2.2)).run t.2.1 = g t.1}
      ≤ (⨆ B : M.PubOut × L → β,
          μ.toOuterMeasure {X | B (M.publicPart (M.forward W X), Λ X) = g X}) + ε q

/-- **The production gate, THE APPROVED STATEMENT (D63, as amended by D76).** A profile goes into production only when
all of these are PROVED for its instance, with the allowed leakage `Λ` named here, at the approved error targets
(`εcTarget`, `εsTarget` for `εs` and `εb`, `εzkTarget`). -/
structure ProductionReadyL (M : IntModel) (A : Arith M) (P : Protocol Q D Coins M) {L : Type} (Λ : M.Input → L)
    (εc : ℝ≥0∞) (εs εb : ℕ → ℝ≥0∞) (εzk : ℕ → ℕ → ℝ≥0∞) : Prop where
  circuit : CircuitIff M A
  complete : Complete M P εc
  sound : KnowledgeSound M P εs
  binding : Binding M P εb
  zk : ZeroKnowledgeL M P Λ εzk
  semantic : SemanticHidingL M P Λ (fun q => εzk q 1)

end ZK60
