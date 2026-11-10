/-
D63 lane L42 (2026-11-10), part 1: **the bridges from the instance-leak forms to the approved statements of D76.**

Victor's ruling D76 amended the approved statements (`Statements.lean`): the allowed leakage is an explicit argument
`Λ : M.Input → L` of `ZeroKnowledgeL`, `SemanticHidingL` and `ProductionReadyL`, and zero knowledge (and semantic
hiding) is asked for at most `2^64` hash queries and `2^64` receipts. Every result proved so far is about the
instance-leak forms `ZeroKnowledge`, `SemanticHiding`, `ProductionReady` (the simulator sees the instance's own
`P.leak x`, for every `q` and `R`). They carry over when the instance leaks no more than `Λ`:

* `LeaksAtMost P Λ`: the instance's leakage factors through `Λ` (`∃ f, P.leak = f ∘ Λ`);
* `SimulatorL.ofSim`, `idealProbL_ofSim`: a simulator for the instance's leakage is one for `Λ`, with the same view;
* **`zeroKnowledgeL_of_zeroKnowledge`**: the every-`q`-and-`R` form with the instance's leakage gives the range form
  with `Λ`; **`zeroKnowledgeL_of_zeroKnowledge_le`**: the same with any error that is within `εzk` on the range only
  (a CAPPED form, as lane L33 proved it); **`zeroKnowledgeL_target_of_cap`**: a capped form within `εzkTarget` for
  every `R ≤ 2^r` (`r ≥ 64`) gives the approved target; `zeroKnowledgeL_target_of_cap_or`: the same for L33's shape
  `R ≤ 2^r ∨ 2^120 ≤ R`;
* **`semanticHidingL_of_semanticHiding`**: the same for semantic hiding (the best guess from the instance's leakage is
  no better than the best guess from `Λ`);
* `withLeak`, `zeroKnowledge_withLeak`: the range form IS the instance-leak form of the instance with its
  leakage replaced by `Λ`, at the error cut to `⊤` outside the range (`rangeCut`);
* **`semanticHidingL_of_zeroKnowledgeL`**: T2 ⇒ T2′ for the approved forms (L4's `semanticHiding_of_zeroKnowledge`
  through `withLeak`);
* **`productionReadyL_of_productionReady`**: `ProductionReady` plus `LeaksAtMost P Λ` gives `ProductionReadyL` at the
  same errors; `productionReadyL_of_productionReady_range`: with larger errors, the zero-knowledge one compared on the
  range only; `productionReadyL_of_parts`: from the four statement-1 parts and `ZeroKnowledgeL` (semantic hiding
  derived); `productionReadyL_mono`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.Assembly

set_option autoImplicit false

namespace ZK60.D76

open scoped ENNReal
open ZK60

/-! ## The factoring condition -/

/-- **The instance leaks no more than `Λ`**: its declared leakage is a function of `Λ`. -/
def LeaksAtMost {Q D Coins : Type} {M : IntModel} (P : Protocol Q D Coins M) {L : Type} (Λ : M.Input → L) : Prop :=
  ∃ f : L → P.Leak, P.leak = f ∘ Λ

/-! ## Simulators and the ideal world -/

section Sim

variable {Q D Coins : Type} {M : IntModel} {P : Protocol Q D Coins M} {L : Type}

/-- A simulator for the instance's leakage, read through `f : L → P.Leak`, is a simulator for `L`. -/
def SimulatorL.ofSim (S : Simulator M P) (f : L → P.Leak) : SimulatorL M P L where
  State := S.State
  SCoins := S.SCoins
  fin := S.fin
  ne := S.ne
  inh := S.inh
  init := S.init
  step s i c := S.step s (Sum.map id (fun z => (z.1, f z.2)) i) c

/-- **The same ideal world**: when `P.leak = f ∘ Λ`, the simulator `ofSim S f` shown `Λ x` behaves as `S` shown
`P.leak x`. -/
theorem idealProbL_ofSim (S : Simulator M P) (Λ : M.Input → L) (f : L → P.Leak) (hf : P.leak = f ∘ Λ)
    (W : M.Weights) (n : ℕ) (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) :
    idealProbL M P Λ (SimulatorL.ofSim S f) W n Dist = idealProb M P S W n Dist := by
  unfold idealProbL idealProb
  have e : (fun (s : (SimulatorL.ofSim S f).State) (i : Q ⊕ M.Input) (c : (SimulatorL.ofSim S f).SCoins) =>
        (SimulatorL.ofSim S f).step s (Sum.map id (fun x => (M.publicPart (M.forward W x), Λ x)) i) c)
      = (fun (s : S.State) (i : Q ⊕ M.Input) (c : S.SCoins) =>
        S.step s (Sum.map id (fun x => (M.publicPart (M.forward W x), P.leak x)) i) c) := by
    funext s i c
    cases i with
    | inl qq => rfl
    | inr x => simp [SimulatorL.ofSim, hf]
  rw [e]
  rfl

end Sim

/-! ## Zero knowledge -/

section ZK

variable {Q D Coins : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
  [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
  {M : IntModel} {P : Protocol Q D Coins M} {L : Type}

/-- **The range form with `Λ` from the every-`q`-and-`R` form with the instance's leakage, at a capped error**: if
the instance is zero knowledge with error `ε` (every `q`, `R`) and leaks no more than `Λ`, it meets the approved
statement at any `εzk` that bounds `ε` on the range `q, R ≤ 2^64` only. -/
theorem zeroKnowledgeL_of_zeroKnowledge_le (Λ : M.Input → L) (hf : LeaksAtMost P Λ) {ε εzk : ℕ → ℕ → ℝ≥0∞}
    (h : ZeroKnowledge M P ε) (hle : ∀ q R, q ≤ 2 ^ 64 → R ≤ 2 ^ 64 → ε q R ≤ εzk q R) :
    ZeroKnowledgeL M P Λ εzk := by
  obtain ⟨f, hf⟩ := hf
  obtain ⟨S, hS⟩ := h
  refine ⟨SimulatorL.ofSim S f, fun W q R Dist hq hR hD => ?_⟩
  rw [idealProbL_ofSim S Λ f hf]
  exact ⟨(hS W q R Dist hD).1.trans (add_le_add le_rfl (hle q R hq hR)),
    (hS W q R Dist hD).2.trans (add_le_add le_rfl (hle q R hq hR))⟩

/-- **The range form with `Λ` from the every-`q`-and-`R` form with the instance's leakage**, at the same error. -/
theorem zeroKnowledgeL_of_zeroKnowledge (Λ : M.Input → L) (hf : LeaksAtMost P Λ) {εzk : ℕ → ℕ → ℝ≥0∞}
    (h : ZeroKnowledge M P εzk) : ZeroKnowledgeL M P Λ εzk :=
  zeroKnowledgeL_of_zeroKnowledge_le Λ hf h fun _ _ _ _ => le_rfl

/-- The approved zero-knowledge statement is monotone in its error, compared on the range only. -/
theorem zeroKnowledgeL_mono (Λ : M.Input → L) {εzk εzk' : ℕ → ℕ → ℝ≥0∞} (h : ZeroKnowledgeL M P Λ εzk)
    (hle : ∀ q R, q ≤ 2 ^ 64 → R ≤ 2 ^ 64 → εzk q R ≤ εzk' q R) : ZeroKnowledgeL M P Λ εzk' := by
  obtain ⟨S, hS⟩ := h
  exact ⟨S, fun W q R Dist hq hR hD =>
    ⟨(hS W q R Dist hq hR hD).1.trans (add_le_add le_rfl (hle q R hq hR)),
      (hS W q R Dist hq hR hD).2.trans (add_le_add le_rfl (hle q R hq hR))⟩⟩

/-- `2^64 ≤ 2^r` for `r ≥ 64`. -/
theorem pow64_le {r : ℕ} (hr : 64 ≤ r) : 2 ^ 64 ≤ 2 ^ r := Nat.pow_le_pow_right (by norm_num) hr

/-- **The approved target from a receipt cap** (lane L33's form, `ref_cap_R`): an error within `εzkTarget q R` for
every `q` and every `R ≤ 2^r`, with `r ≥ 64`, meets the approved statement at the target. -/
theorem zeroKnowledgeL_target_of_cap (Λ : M.Input → L) (hf : LeaksAtMost P Λ) {ε : ℕ → ℕ → ℝ≥0∞}
    (h : ZeroKnowledge M P ε) (r : ℕ) (hr : 64 ≤ r) (hcap : ∀ q R, R ≤ 2 ^ r → ε q R ≤ εzkTarget q R) :
    ZeroKnowledgeL M P Λ εzkTarget :=
  zeroKnowledgeL_of_zeroKnowledge_le Λ hf h fun q R _ hR => hcap q R (hR.trans (pow64_le hr))

/-- The same for lane L33's shape of the cap (`classify_zk_cap110`: `R ≤ 2^r ∨ 2^120 ≤ R`). -/
theorem zeroKnowledgeL_target_of_cap_or (Λ : M.Input → L) (hf : LeaksAtMost P Λ) {ε : ℕ → ℕ → ℝ≥0∞}
    (h : ZeroKnowledge M P ε) (r : ℕ) (hr : 64 ≤ r)
    (hcap : ∀ q R, (R ≤ 2 ^ r ∨ 2 ^ 120 ≤ R) → ε q R ≤ εzkTarget q R) :
    ZeroKnowledgeL M P Λ εzkTarget :=
  zeroKnowledgeL_target_of_cap Λ hf h r hr fun q R hR => hcap q R (Or.inl hR)

end ZK

/-! ## Semantic hiding -/

section Sem

variable {Q D Coins : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
  [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
  {M : IntModel} {P : Protocol Q D Coins M} {L : Type}

omit [Inhabited Coins] in
/-- **Semantic hiding with `Λ` from semantic hiding with the instance's leakage**: a guess from the public part and
`P.leak X = f (Λ X)` is a guess from the public part and `Λ X`. -/
theorem semanticHidingL_of_semanticHiding (Λ : M.Input → L) (hf : LeaksAtMost P Λ) {ε : ℕ → ℝ≥0∞}
    (h : SemanticHiding M P ε) : SemanticHidingL M P Λ ε := by
  obtain ⟨f, hf⟩ := hf
  intro W μ β g q A _ hA
  refine (h W μ β g q A hA).trans (add_le_add ?_ le_rfl)
  refine iSup_le fun B => le_iSup_of_le (fun z => B (z.1, f z.2)) (le_of_eq ?_)
  congr 1
  ext X
  simp only [Set.mem_ofPred_eq, hf, Function.comp_apply]

end Sem

/-! ## The range form is the instance-leak form of the instance with its leakage replaced -/

section WithLeak

variable {Q D Coins : Type} {M : IntModel}

/-- The instance with its declared leakage replaced by `Λ` (every other field the same). -/
def withLeak (P : Protocol Q D Coins M) {L : Type} (Λ : M.Input → L) : Protocol Q D Coins M where
  Stmt := P.Stmt
  Receipt := P.Receipt
  Salt := P.Salt
  Leak := L
  leak := Λ
  ypub := P.ypub
  opensIn := P.opensIn
  opensOut := P.opensOut
  prove := P.prove
  verify := P.verify

/-- The error cut to `⊤` outside the range `q, R ≤ 2^64`. -/
noncomputable def rangeCut (ε : ℕ → ℕ → ℝ≥0∞) (q R : ℕ) : ℝ≥0∞ :=
  if q ≤ 2 ^ 64 ∧ R ≤ 2 ^ 64 then ε q R else ⊤

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-- **The approved zero-knowledge statement as an instance-leak statement**: `ZeroKnowledgeL M P Λ ε` gives
`ZeroKnowledge M (withLeak P Λ) (rangeCut ε)` (outside the range the bound is `⊤`). -/
theorem zeroKnowledge_withLeak (P : Protocol Q D Coins M) {L : Type} (Λ : M.Input → L) {ε : ℕ → ℕ → ℝ≥0∞}
    (h : ZeroKnowledgeL M P Λ ε) : ZeroKnowledge M (withLeak P Λ) (rangeCut ε) := by
  obtain ⟨S, hS⟩ := h
  refine ⟨Simulator.mk (State := S.State) (SCoins := S.SCoins) (fin := S.fin) (ne := S.ne) (inh := S.inh)
    S.init S.step, fun W q R Dist hD => ?_⟩
  by_cases hr : q ≤ 2 ^ 64 ∧ R ≤ 2 ^ 64
  · have e : rangeCut ε q R = ε q R := ite_eq_left hr
    rw [e]
    exact hS W q R Dist hr.1 hr.2 hD
  · have e : rangeCut ε q R = ⊤ := ite_eq_right hr
    rw [e, add_top, add_top]
    exact ⟨le_top, le_top⟩

/-- **T2 ⇒ T2′ for the approved forms**: `ZeroKnowledgeL M P Λ εzk` gives `SemanticHidingL M P Λ (fun q => εzk q 1)`
(L4's `semanticHiding_of_zeroKnowledge` at `withLeak P Λ`; one receipt is within the range). -/
theorem semanticHidingL_of_zeroKnowledgeL (P : Protocol Q D Coins M) {L : Type} (Λ : M.Input → L)
    {εzk : ℕ → ℕ → ℝ≥0∞} (h : ZeroKnowledgeL M P Λ εzk) : SemanticHidingL M P Λ (fun q => εzk q 1) := by
  have hs := Assembly.semanticHiding_of_zeroKnowledge (withLeak P Λ) (zeroKnowledge_withLeak P Λ h)
  intro W μ β g q A hq hA
  have e : rangeCut εzk q 1 = εzk q 1 := ite_eq_left ⟨hq, Nat.one_le_two_pow⟩
  have h1 : _ ≤ (⨆ B : M.PubOut × L → β,
      μ.toOuterMeasure {X | B (M.publicPart (M.forward W X), Λ X) = g X}) + rangeCut εzk q 1 :=
    hs W μ β g q A hA
  rw [e] at h1
  exact h1

end WithLeak

/-! ## The production gate -/

section Gate

variable {Q D Coins : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
  [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
  {M : IntModel} {A : Arith M} {P : Protocol Q D Coins M} {L : Type}

/-- **The approved gate from its parts**: the four statement-1 parts and the approved zero-knowledge statement (the
semantic-hiding field is derived, `semanticHidingL_of_zeroKnowledgeL`). -/
theorem productionReadyL_of_parts (Λ : M.Input → L) {εc : ℝ≥0∞} {εs εb : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (hC : CircuitIff M A) (hc : Complete M P εc) (hs : KnowledgeSound M P εs) (hb : Binding M P εb)
    (hzk : ZeroKnowledgeL M P Λ εzk) : ProductionReadyL M A P Λ εc εs εb εzk where
  circuit := hC
  complete := hc
  sound := hs
  binding := hb
  zk := hzk
  semantic := semanticHidingL_of_zeroKnowledgeL P Λ hzk

/-- **The approved gate (D76) from the instance-leak gate**: `ProductionReady` for an instance that leaks no more than
`Λ` is `ProductionReadyL` at `Λ`, at the same errors. -/
theorem productionReadyL_of_productionReady (Λ : M.Input → L) (hf : LeaksAtMost P Λ) {εc : ℝ≥0∞}
    {εs εb : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞} (h : ProductionReady M A P εc εs εb εzk) :
    ProductionReadyL M A P Λ εc εs εb εzk where
  circuit := h.circuit
  complete := h.complete
  sound := h.sound
  binding := h.binding
  zk := zeroKnowledgeL_of_zeroKnowledge Λ hf h.zk
  semantic := semanticHidingL_of_semanticHiding Λ hf h.semantic

/-- **The approved gate's errors are monotone**, the zero-knowledge error compared on the range only. -/
theorem productionReadyL_mono (Λ : M.Input → L) {εc εc' : ℝ≥0∞} {εs εs' εb εb' : ℕ → ℝ≥0∞}
    {εzk εzk' : ℕ → ℕ → ℝ≥0∞} (h : ProductionReadyL M A P Λ εc εs εb εzk) (hc : εc ≤ εc')
    (hs : ∀ q, εs q ≤ εs' q) (hb : ∀ q, εb q ≤ εb' q)
    (hzk : ∀ q R, q ≤ 2 ^ 64 → R ≤ 2 ^ 64 → εzk q R ≤ εzk' q R) : ProductionReadyL M A P Λ εc' εs' εb' εzk' :=
  productionReadyL_of_parts Λ h.circuit (Assembly.complete_mono h.complete hc) (Assembly.knowledgeSound_mono h.sound hs)
    (Assembly.binding_mono h.binding hb) (zeroKnowledgeL_mono Λ h.zk hzk)

/-- **The approved gate from the instance-leak gate at its own errors, the zero-knowledge error within the new one on
the range only**: what a gate proved with an error that meets the target only up to a receipt cap (lane L33) needs. -/
theorem productionReadyL_of_productionReady_range (Λ : M.Input → L) (hf : LeaksAtMost P Λ) {εc εc' : ℝ≥0∞}
    {εs εs' εb εb' : ℕ → ℝ≥0∞} {εzk εzk' : ℕ → ℕ → ℝ≥0∞} (h : ProductionReady M A P εc εs εb εzk)
    (hc : εc ≤ εc') (hs : ∀ q, εs q ≤ εs' q) (hb : ∀ q, εb q ≤ εb' q)
    (hzk : ∀ q R, q ≤ 2 ^ 64 → R ≤ 2 ^ 64 → εzk q R ≤ εzk' q R) : ProductionReadyL M A P Λ εc' εs' εb' εzk' :=
  productionReadyL_mono Λ (productionReadyL_of_productionReady Λ hf h) hc hs hb hzk

end Gate

end ZK60.D76
