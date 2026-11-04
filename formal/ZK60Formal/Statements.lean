/-
ZK60 — the D63 production statements, formalized (STATEMENTS ONLY; nothing here is proved about our protocol yet).

Ruling D63 (Victor, 2026-11-04): before any ZKP goes into production, two statements must be formalized and
proved in Lean. (1) The proof is accepted for a forward pass if and only if it attests the same output as the
forward pass of the associated discretized model. (2) It is sufficiently hard to learn any useful information
about the hidden data.

This file states them precisely, for one abstract registered profile: `IntModel` (the discretized model),
`Arith` (its constraint system), `Protocol` (prover, verifier, commitments). A real profile (e.g. R13 8B T128
with D55) is an INSTANCE of these structures; writing the instances and proving `ProductionReady` for them is
the formalization work (plan L1–L5 in docs/zkmatrix-poc/ZK60_LEAN_PRODUCTION_STATEMENTS.md).

Status: wording APPROVED by Victor, 2026-11-04, with the §6 choices of that document (error targets below,
production acceptance by the Lean verifier, reuse of FlashProve's Lean library and ArkLib where they fit).

Modelling choices (each is a statement-level choice a reader must accept):
* The hash is a random oracle: a uniformly random function `Q → D` on a finite query space `Q`
  (bounded-length messages) and digest space `D`.
* Adversaries are deterministic oracle computations (`OC`); this loses nothing for upper bounds that hold for
  every adversary, since a randomized adversary is an average of deterministic ones.
* Query budgets are counted on every path of the computation (`OC.Bounded`, `OC.Within`).
* Probabilities are `ENNReal`-valued, via `PMF.toOuterMeasure`.
-/
import Mathlib.Probability.ProbabilityMassFunction.Constructions
import Mathlib.Probability.Distributions.Uniform

namespace ZK60

open scoped ENNReal

/-! ## Oracle computations -/

/-- A deterministic computation that may ask questions `i : I` and receives answers `o : O`. -/
inductive OC (I O α : Type) : Type where
  | ret : α → OC I O α
  | ask : I → (O → OC I O α) → OC I O α

namespace OC

variable {I O α σ R : Type}

/-- Run against a fixed oracle `f`. -/
def run (f : I → O) : OC I O α → α
  | .ret a => a
  | .ask i k => run f (k (f i))

/-- Run against `f`, also returning the log of (question, answer) pairs, in order. -/
def runLog (f : I → O) : OC I O α → α × List (I × O)
  | .ret a => (a, [])
  | .ask i k =>
      let r := runLog f (k (f i))
      (r.1, (i, f i) :: r.2)

/-- At most `n` questions on every path. -/
def Bounded : OC I O α → ℕ → Prop
  | .ret _, _ => True
  | .ask _ _, 0 => False
  | .ask _ k, n + 1 => ∀ o, Bounded (k o) n

/-- Run against a stateful responder; the question at position `pos` uses randomness `rand pos`. -/
def runState (step : σ → I → R → O × σ) (rand : ℕ → R) : ℕ → σ → OC I O α → α
  | _, _, .ret a => a
  | pos, s, .ask i k =>
      let r := step s i (rand pos)
      runState step rand (pos + 1) r.2 (k r.1)

/-- For computations asking two kinds of questions: at most `q` of the first kind (hash queries) and at most
`r` of the second kind (proof requests) on every path. -/
def Within {Q X : Type} : OC (Q ⊕ X) O α → ℕ → ℕ → Prop
  | .ret _, _, _ => True
  | .ask (.inl _) _, 0, _ => False
  | .ask (.inl _) k, q + 1, r => ∀ o, Within (k o) q r
  | .ask (.inr _) _, _, 0 => False
  | .ask (.inr _) k, q, r + 1 => ∀ o, Within (k o) q r

end OC

/-- Extend finite randomness `Fin n → R` to all positions (positions `≥ n` get a default). -/
def extend {R : Type} [Inhabited R] {n : ℕ} (c : Fin n → R) : ℕ → R :=
  fun k => if h : k < n then c ⟨k, h⟩ else default

/-! ## The discretized model, its constraint system, and the protocol -/

/-- The discretized (integer) model of one registered profile: exact integer weights, matrix products,
rounding, lookup tables, norms, softmax and the final decision (greedy token, or classifier verdict). -/
structure IntModel where
  Weights : Type
  Input : Type
  Output : Type
  /-- the part of the output that the receipt publishes (nothing, or e.g. the classifier verdict) -/
  PubOut : Type
  /-- the part of the output that stays hidden behind a commitment -/
  HidOut : Type
  admissible : Input → Prop
  forward : Weights → Input → Output
  publicPart : Output → PubOut
  hiddenPart : Output → HidOut

/-- The profile's constraint system (slots, lookups, range checks, sumcheck relations), as a relation. -/
structure Arith (M : IntModel) where
  Witness : Type
  Satisfies : M.Weights → M.Input → M.Output → Witness → Prop

section Protocol

variable (Q D Coins : Type)

/-- The proof protocol of one profile under P1 (weights public): hash queries `Q`, digests `D`,
prover randomness `Coins` (masks and salts). -/
structure Protocol (M : IntModel) where
  Stmt : Type
  Receipt : Type
  Salt : Type
  /-- declared leakage of an input: the profile's shapes and token count, and whether it is served -/
  Leak : Type
  leak : M.Input → Leak
  /-- the public output part carried by a statement -/
  ypub : Stmt → M.PubOut
  /-- `opensIn H s x r`: the statement's input commitment opens to `x` with salt `r` -/
  opensIn : (Q → D) → Stmt → M.Input → Salt → Prop
  /-- `opensOut H s y r`: the statement's hidden-output commitment opens to `y` with salt `r` -/
  opensOut : (Q → D) → Stmt → M.HidOut → Salt → Prop
  prove : (Q → D) → M.Weights → M.Input → Coins → Stmt × Receipt
  /-- THE verifier; D63 proposes that production acceptance is this function's verdict -/
  verify : (Q → D) → M.Weights → Stmt → Receipt → Bool

end Protocol

variable {Q D Coins : Type}
  [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
  [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-- Probability, over a uniformly random oracle, of an event. -/
noncomputable def prH (E : (Q → D) → Prop) : ℝ≥0∞ :=
  (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | E H}

/-- Probability, over a uniformly random oracle and uniform prover coins, of an event. -/
noncomputable def prHC (E : (Q → D) → Coins → Prop) : ℝ≥0∞ :=
  (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure {p | E p.1 p.2}

/-! ## Statement 1: accepted exactly when the output is the model's output -/

/-- The deterministic lemma that carries the model: the constraints are satisfiable for endpoints `(x, y)`
exactly when `x` is admissible and `y` is the discretized model's output on `x`. -/
def CircuitIff (M : IntModel) (A : Arith M) : Prop :=
  ∀ (W : M.Weights) (x : M.Input) (y : M.Output),
    (∃ w, A.Satisfies W x y w) ↔ (M.admissible x ∧ y = M.forward W x)

/-- T1a, completeness ("if"): for every admissible input the honest receipt is accepted, its statement carries
the model's public output part, and its commitments open to the input and the hidden output part — except with
probability at most `εc` (the prover's own refusals). -/
def Complete (M : IntModel) (P : Protocol Q D Coins M) (εc : ℝ≥0∞) : Prop :=
  ∀ (W : M.Weights) (x : M.Input), M.admissible x →
    1 - εc ≤ prHC (fun H c =>
      let sr := P.prove H W x c
      P.verify H W sr.1 sr.2 = true
      ∧ P.ypub sr.1 = M.publicPart (M.forward W x)
      ∧ (∃ r, P.opensIn H sr.1 x r)
      ∧ (∃ r, P.opensOut H sr.1 (M.hiddenPart (M.forward W x)) r))

/-- T1b, knowledge soundness ("only if"): an extractor reading a cheating prover's hash-query log recovers an
admissible input behind the input commitment whose model output is the one the statement attests; any prover
making at most `q` hash queries defeats it with probability at most `εs q`. -/
def KnowledgeSound (M : IntModel) (P : Protocol Q D Coins M) (εs : ℕ → ℝ≥0∞) : Prop :=
  ∃ E : List (Q × D) → P.Stmt → P.Receipt → M.Input × P.Salt × P.Salt,
    ∀ (W : M.Weights) (q : ℕ) (A : OC Q D (P.Stmt × P.Receipt)), A.Bounded q →
      prH (fun H =>
        let out := A.runLog H
        let s := out.1.1
        let pf := out.1.2
        let e := E out.2 s pf
        P.verify H W s pf = true
        ∧ ¬ (M.admissible e.1
              ∧ P.opensIn H s e.1 e.2.1
              ∧ P.ypub s = M.publicPart (M.forward W e.1)
              ∧ P.opensOut H s (M.hiddenPart (M.forward W e.1)) e.2.2))
      ≤ εs q

/-- Binding of both commitments: no one making at most `q` hash queries opens one statement's input
commitment, or its hidden-output commitment, to two different values, except with probability `εb q`. -/
def Binding (M : IntModel) (P : Protocol Q D Coins M) (εb : ℕ → ℝ≥0∞) : Prop :=
  (∀ (q : ℕ) (A : OC Q D (P.Stmt × M.Input × P.Salt × M.Input × P.Salt)), A.Bounded q →
    prH (fun H =>
      let o := A.run H
      o.2.1 ≠ o.2.2.2.1 ∧ P.opensIn H o.1 o.2.1 o.2.2.1 ∧ P.opensIn H o.1 o.2.2.2.1 o.2.2.2.2) ≤ εb q)
  ∧ (∀ (q : ℕ) (A : OC Q D (P.Stmt × M.HidOut × P.Salt × M.HidOut × P.Salt)), A.Bounded q →
    prH (fun H =>
      let o := A.run H
      o.2.1 ≠ o.2.2.2.1 ∧ P.opensOut H o.1 o.2.1 o.2.2.1 ∧ P.opensOut H o.1 o.2.2.2.1 o.2.2.2.2) ≤ εb q)

/-! ## Statement 2: the receipts teach nothing about the hidden data -/

/-- A simulator: it answers hash queries itself (it may program the oracle) and produces receipts from the
public output part and the declared leakage only — never from the input. -/
structure Simulator (M : IntModel) (P : Protocol Q D Coins M) where
  State : Type
  SCoins : Type
  [fin : Fintype SCoins]
  [ne : Nonempty SCoins]
  [inh : Inhabited SCoins]
  init : M.Weights → State
  step : State → Q ⊕ (M.PubOut × P.Leak) → SCoins → (D ⊕ (P.Stmt × P.Receipt)) × State

/-- The distinguisher's view in the real world: a random oracle, and honest receipts with fresh coins for each
request it makes (on inputs of its choice). It may ask at most `n` questions in all. -/
noncomputable def realProb (M : IntModel) (P : Protocol Q D Coins M) (W : M.Weights) (n : ℕ)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) : ℝ≥0∞ :=
  (PMF.uniformOfFintype ((Q → D) × (Fin n → Coins))).toOuterMeasure
    {p | Dist.runState
          (fun (_ : Unit) (i : Q ⊕ M.Input) (c : Coins) =>
            match i with
            | .inl qq => (.inl (p.1 qq), ())
            | .inr x => (.inr (P.prove p.1 W x c), ()))
          (extend p.2) 0 () = true}

/-- The distinguisher's view in the ideal world: everything comes from the simulator, which sees each request
only through `(publicPart (forward W x), leak x)`. -/
noncomputable def idealProb (M : IntModel) (P : Protocol Q D Coins M) (S : Simulator M P) (W : M.Weights)
    (n : ℕ) (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) : ℝ≥0∞ :=
  haveI := S.fin; haveI := S.ne; haveI := S.inh
  (PMF.uniformOfFintype (Fin n → S.SCoins)).toOuterMeasure
    {sc | Dist.runState
          (fun (s : S.State) (i : Q ⊕ M.Input) (c : S.SCoins) =>
            S.step s (Sum.map id (fun x => (M.publicPart (M.forward W x), P.leak x)) i) c)
          (extend sc) 0 (S.init W) = true}

/-- T2, zero knowledge in the random-oracle model: one simulator such that no distinguisher making at most `q`
hash queries and `R` proof requests tells the two worlds apart with advantage above `εzk q R`. -/
def ZeroKnowledge (M : IntModel) (P : Protocol Q D Coins M) (εzk : ℕ → ℕ → ℝ≥0∞) : Prop :=
  ∃ S : Simulator M P, ∀ (W : M.Weights) (q R : ℕ)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool), Dist.Within q R →
      realProb M P W (q + R) Dist ≤ idealProb M P S W (q + R) Dist + εzk q R
      ∧ idealProb M P S W (q + R) Dist ≤ realProb M P W (q + R) Dist + εzk q R

/-- T2′, the form in D63's own words: for ANY property `g` of the hidden input (one bit, one token, anything)
and any distribution `μ` of inputs, an adversary that sees a receipt and makes at most `q` hash queries guesses
`g` no better than the best guess from the public part and the declared leakage alone, plus `ε q`. -/
def SemanticHiding (M : IntModel) (P : Protocol Q D Coins M) (ε : ℕ → ℝ≥0∞) : Prop :=
  ∀ (W : M.Weights) (μ : PMF M.Input) (β : Type) (g : M.Input → β) (q : ℕ)
    (A : P.Stmt × P.Receipt → OC Q D β), (∀ sr, (A sr).Bounded q) →
    (μ.bind fun X => (PMF.uniformOfFintype ((Q → D) × Coins)).map fun p => (X, p)).toOuterMeasure
        {t | (A (P.prove t.2.1 W t.1 t.2.2)).run t.2.1 = g t.1}
      ≤ (⨆ B : M.PubOut × P.Leak → β,
          μ.toOuterMeasure {X | B (M.publicPart (M.forward W X), P.leak X) = g X}) + ε q

/-! ## The production gate -/

/-- D63: a profile goes into production only when all of these are PROVED for its instance, with the error
targets Victor rules on (proposed: `εc = 2^-40`, `εs q = q·2^-100 + 2^-100`, `εb q = q·2^-100 + 2^-100`,
`εzk q R = q·2^-128 + R·2^-120`). -/
structure ProductionReady (M : IntModel) (A : Arith M) (P : Protocol Q D Coins M)
    (εc : ℝ≥0∞) (εs εb : ℕ → ℝ≥0∞) (εzk : ℕ → ℕ → ℝ≥0∞) : Prop where
  circuit : CircuitIff M A
  complete : Complete M P εc
  sound : KnowledgeSound M P εs
  binding : Binding M P εb
  zk : ZeroKnowledge M P εzk
  semantic : SemanticHiding M P (fun q => εzk q 1)

/-- The proposed error targets, as values. -/
noncomputable def εcTarget : ℝ≥0∞ := (2⁻¹ : ℝ≥0∞) ^ 40
noncomputable def εsTarget (q : ℕ) : ℝ≥0∞ := (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 100 + (2⁻¹ : ℝ≥0∞) ^ 100
noncomputable def εzkTarget (q R : ℕ) : ℝ≥0∞ :=
  (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 128 + (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120

/-! ## A sanity check that the definitions are usable (not a result about our protocol) -/

/-- The trivial arithmetization (the relation is the model itself) satisfies `CircuitIff`. Real profiles have a
constraint system of slots, lookups and sumchecks instead, and proving `CircuitIff` for it is the L2 work. -/
def trivialArith (M : IntModel) : Arith M where
  Witness := Unit
  Satisfies W x y _ := M.admissible x ∧ y = M.forward W x

theorem trivialArith_circuitIff (M : IntModel) : CircuitIff M (trivialArith M) := by
  unfold CircuitIff
  intro W x y
  exact ⟨fun ⟨_, h⟩ => h, fun h => ⟨(), h⟩⟩

end ZK60
