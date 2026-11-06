/-
D63, the ASSEMBLY of the two approved production statements (`Statements.lean`), generic over any `IntModel`,
`Arith` and `Protocol`. Nothing here is about one profile: it shows how the per-profile pieces meet the approved
bundle `ProductionReady`, and it proves the one implication between the approved statements.

(a) **T2 ⇒ T2′** (`semanticHiding_of_zeroKnowledge`):
`ZeroKnowledge M P εzk → SemanticHiding M P (fun q => εzk q 1)`, exactly as approved, with no further premise.
* From a semantic adversary `A` (one receipt, at most `q` hash queries on every path) and the property `g`, for each
  input `X` the distinguisher `semDist P A g X` makes ONE proof request (of `X`), runs `A` on the answer with its hash
  queries forwarded, and outputs whether `A`'s guess is `g X`. It is `Within q 1` (`semDist_within`), so
  `ZeroKnowledge` applies to it with `R = 1`, at `q + 1` coin positions.
* Real world: its success is `A`'s success on `X` (`realProb_semDist`). The prover's coin is the coin at position 0,
  and one coordinate of a uniform coin vector is uniform (`prob_coin0`).
* Ideal world: the simulator sees the request only through `z = (publicPart (forward W X), leak X)`, so the success is
  `Pr_ω[Φ z ω = some (g X)]` for ONE function `Φ` that does not depend on `X` (`idealProb_semDist`).
* Averaging over `μ` (`avg_le`): for each simulator coin vector `ω`, `B_ω z := (Φ z ω).getD _` is a guess from the
  public part and the leakage alone, so the average ideal success is at most the supremum over `B`.

(b) **Statement 1 from an IOP-level extraction.**
* `IOPExtract`: an extractor that reads the prover's hash-query log and recovers `(x, y, w)` with
  `A.Satisfies W x y w`, the statement's commitments opening to `x` and to `hiddenPart y`, and `ypub s = publicPart y`,
  except with probability `εiop q`.
* `knowledgeSound_of_extract`: `CircuitIff M A → IOPExtract M A P εiop → KnowledgeSound M P εiop`, by `CircuitIff`'s ⇒
  direction (a satisfying assignment has an admissible input and the model's output).
* The completeness analogue: `ArithComplete` (the honest receipt is accepted, with the satisfying output, for every
  satisfiable input) gives `Complete` by `CircuitIff`'s ⇐ direction (`complete_of_arithComplete`), and the two are
  equivalent under `CircuitIff` (`arithComplete_iff_complete`).

(c) **The assembly**: `productionReady_of` (and `productionReady_of_arith`): `CircuitIff`, `IOPExtract`, `Complete`,
`Binding` and `ZeroKnowledge` give `ProductionReady M A P εc εiop εb εzk`. The error terms are monotone
(`productionReady_mono`), so a profile's proved bounds meet any larger targets.

(d) **`Binding` from Merkle binding** (`ColCommit`, `ColCommit.binding`, `binding_of_colCommit`): if a profile's
`opensIn` / `opensOut` are column-by-column salted Merkle openings whose columns determine the value, `Binding` holds
with the sum of two `merkle_binding` bounds (`SoundMerkle.lean`).

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`. The per-profile obligations that remain
(the instances of `CircuitIff`, `IOPExtract`, `Complete`, `Binding` and `ZeroKnowledge`, and the `IntModel`, `Arith`
and `Protocol` instances themselves) are listed in `docs/zkmatrix-poc/ZK60_LEAN_ASSEMBLY_20261106.md` §4.
-/
import ZK60Formal.SoundMerkle

namespace ZK60.Assembly

open scoped ENNReal

/-! ## Oracle computations: post-processing and relabelling -/

section OCx

variable {I O α β : Type}

/-- Post-process the result of a computation: the same questions, then `f` of the result. -/
def mapOut (f : α → β) : OC I O α → OC I O β
  | .ret a => .ret (f a)
  | .ask i k => .ask i (fun o => mapOut f (k o))

/-- Running a post-processed computation against any responder post-processes the result. -/
theorem runState_mapOut {σ R : Type} (f : α → β) (step : σ → I → R → O × σ) (rand : ℕ → R) (A : OC I O α) :
    ∀ (pos : ℕ) (s : σ), (mapOut f A).runState step rand pos s = f (A.runState step rand pos s) := by
  induction A with
  | ret a => intro pos s; rfl
  | ask i k ih =>
    intro pos s
    simp only [mapOut, OC.runState]
    exact ih _ _ _

/-- Post-processing asks the same questions, so it keeps both budgets. -/
theorem within_mapOut {Qh X : Type} (f : α → β) (A : OC (Qh ⊕ X) O α) :
    ∀ (q r : ℕ), A.Within q r → (mapOut f A).Within q r := by
  induction A with
  | ret a => intro q r _; trivial
  | ask i k ih =>
    intro q r h
    cases i with
    | inl x =>
      cases q with
      | zero => simp [OC.Within] at h
      | succ q =>
        simp only [OC.Within] at h
        intro o
        exact ih o q r (h o)
    | inr x =>
      cases r with
      | zero => simp [OC.Within] at h
      | succ r =>
        simp only [OC.Within] at h
        intro o
        exact ih o q r (h o)

/-- A hash-only computation run inside a computation with two kinds of questions: its hash question `qq` is asked as
`.inl qq`. An answer of the other kind (which no responder of `Statements.lean` gives to a hash question) ends it with
`none`. -/
def liftHash {Qh Dh X Y : Type} : OC Qh Dh β → OC (Qh ⊕ X) (Dh ⊕ Y) (Option β)
  | .ret b => .ret (some b)
  | .ask qq k => .ask (.inl qq) (Sum.elim (fun d => liftHash (k d)) (fun _ => .ret none))

/-- At most `q` hash queries on every path, and no proof request. -/
theorem within_liftHash {Qh Dh X Y : Type} (A : OC Qh Dh β) :
    ∀ q, A.Bounded q → (liftHash (X := X) (Y := Y) A).Within q 0 := by
  induction A with
  | ret b => intro q _; trivial
  | ask qq k ih =>
    intro q h
    cases q with
    | zero => simp [OC.Bounded] at h
    | succ q =>
      simp only [OC.Bounded] at h
      intro a
      cases a with
      | inl d => exact ih d q (h d)
      | inr y => trivial

/-- Against a responder that answers every hash question `qq` with `H qq`, the lifted computation returns the
computation's own result against `H`. -/
theorem runState_liftHash {Qh Dh X Y C : Type} (H : Qh → Dh) (step : Unit → Qh ⊕ X → C → (Dh ⊕ Y) × Unit)
    (hstep : ∀ qq c, step () (.inl qq) c = (.inl (H qq), ())) (rand : ℕ → C) (A : OC Qh Dh β) :
    ∀ pos, (liftHash A).runState step rand pos () = some (A.run H) := by
  induction A with
  | ret b => intro pos; rfl
  | ask qq k ih =>
    intro pos
    simp only [liftHash, OC.runState, hstep, Sum.elim_inl, OC.run]
    exact ih (H qq) (pos + 1)

end OCx

/-! ## Uniform laws: one coordinate of a uniform vector, and averaging -/

/-- **The coin at position 0 of a uniform coin vector is uniform**, jointly with an independent uniform first
component. -/
theorem prob_coin0 {A C : Type} [Fintype A] [Nonempty A] [Fintype C] [Nonempty C] (n : ℕ) (E : Set (A × C)) :
    (PMF.uniformOfFintype (A × (Fin (n + 1) → C))).toOuterMeasure {p | (p.1, p.2 0) ∈ E}
      = (PMF.uniformOfFintype (A × C)).toOuterMeasure E := by
  let e : A × (Fin (n + 1) → C) ≃ (A × C) × (Fin n → C) :=
    (Equiv.prodCongr (Equiv.refl A) (Fin.consEquiv fun _ : Fin (n + 1) => C).symm).trans
      (Equiv.prodAssoc A C (Fin n → C)).symm
  have hset : {p : A × (Fin (n + 1) → C) | (p.1, p.2 0) ∈ E} = e ⁻¹' (Prod.fst ⁻¹' E) := rfl
  rw [hset, ← PMF.toOuterMeasure_map_apply, Hiding.map_uniform_equiv, Hiding.prob_fst]

/-- **Averaging a guess that depends on the input only through `z`.** If, for every input `x`, the success event is
"`Φ (fz x) ω` is `some (g x)`" for one function `Φ` of `z = fz x` and the coins `ω`, the average success over `μ` is
at most the best success over `μ` of a deterministic guess `B` from `z` alone. (For each `ω`, `B_ω z :=
(Φ z ω).getD b₀` is such a guess.) -/
theorem avg_le {Ω X Z β : Type} (u : PMF Ω) (μ : PMF X) (fz : X → Z) (g : X → β) (Φ : Z → Ω → Option β) :
    ∑' x, μ x * u.toOuterMeasure {ω | Φ (fz x) ω = some (g x)}
      ≤ ⨆ B : Z → β, μ.toOuterMeasure {x | B (fz x) = g x} := by
  obtain ⟨x₀, -⟩ := μ.support_nonempty
  set sup := ⨆ B : Z → β, μ.toOuterMeasure {x | B (fz x) = g x} with hsup
  have hω : ∀ ω, ∑' x, μ x * {ω' | Φ (fz x) ω' = some (g x)}.indicator u ω ≤ u ω * sup := by
    intro ω
    let B : Z → β := fun z => (Φ z ω).getD (g x₀)
    calc ∑' x, μ x * {ω' | Φ (fz x) ω' = some (g x)}.indicator u ω
        ≤ ∑' x, u ω * {x' | B (fz x') = g x'}.indicator μ x := by
          refine ENNReal.tsum_le_tsum fun x => ?_
          by_cases h1 : Φ (fz x) ω = some (g x)
          · have h2 : B (fz x) = g x := by simp [B, h1]
            rw [Set.indicator_of_mem (show ω ∈ {ω' | Φ (fz x) ω' = some (g x)} from h1),
              Set.indicator_of_mem (show x ∈ {x' | B (fz x') = g x'} from h2), mul_comm]
          · rw [Set.indicator_of_notMem (show ω ∉ {ω' | Φ (fz x) ω' = some (g x)} from h1), mul_zero]
            exact zero_le
      _ = u ω * μ.toOuterMeasure {x | B (fz x) = g x} := by
          rw [ENNReal.tsum_mul_left, PMF.toOuterMeasure_apply]
      _ ≤ u ω * sup := by
          gcongr
          exact le_iSup (fun B : Z → β => μ.toOuterMeasure {x | B (fz x) = g x}) B
  calc ∑' x, μ x * u.toOuterMeasure {ω | Φ (fz x) ω = some (g x)}
      = ∑' x, ∑' ω, μ x * {ω' | Φ (fz x) ω' = some (g x)}.indicator u ω := by
        refine tsum_congr fun x => ?_
        rw [PMF.toOuterMeasure_apply, ENNReal.tsum_mul_left]
    _ = ∑' ω, ∑' x, μ x * {ω' | Φ (fz x) ω' = some (g x)}.indicator u ω := ENNReal.tsum_comm
    _ ≤ ∑' ω, u ω * sup := ENNReal.tsum_le_tsum hω
    _ = sup := by rw [ENNReal.tsum_mul_right, u.tsum_coe, one_mul]

/-! ## (a) The distinguisher built from a semantic adversary, and T2 ⇒ T2′ -/

section Semantic

variable {Q D Coins : Type} {M : IntModel} (P : Protocol Q D Coins M) {β : Type}

/-- After the one proof request: a receipt is handed to the semantic adversary `A`, whose hash queries are
forwarded; any other answer ends the run with `none`. -/
def semCont (A : P.Stmt × P.Receipt → OC Q D β) :
    D ⊕ (P.Stmt × P.Receipt) → OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) (Option β) :=
  Sum.elim (fun _ => .ret none) (fun sr => liftHash (A sr))

/-- Request one proof of `X`, then run `A` on it; the result is `A`'s guess (or `none`). -/
def semRun (A : P.Stmt × P.Receipt → OC Q D β) (X : M.Input) :
    OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) (Option β) :=
  .ask (.inr X) (semCont P A)

open Classical in
/-- **The distinguisher built from a semantic adversary** `A` and a property `g`, for one input `X`: request one proof
of `X`, run `A` on it, output whether `A`'s guess is `g X`. -/
noncomputable def semDist (A : P.Stmt × P.Receipt → OC Q D β) (g : M.Input → β) (X : M.Input) :
    OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool :=
  mapOut (fun o => decide (o = some (g X))) (semRun P A X)

/-- It makes one proof request and at most `A`'s `q` hash queries, on every path. -/
theorem semDist_within (A : P.Stmt × P.Receipt → OC Q D β) (g : M.Input → β) (X : M.Input) {q : ℕ}
    (hA : ∀ sr, (A sr).Bounded q) : (semDist P A g X).Within q 1 := by
  refine within_mapOut _ _ q 1 ?_
  intro a
  cases a with
  | inl d => trivial
  | inr sr => exact within_liftHash (A sr) q (hA sr)

/-- The real world's responder, as `realProb` writes it: hash questions to `H`, proof requests to the honest prover
with the coin of their position. -/
def realStep (H : Q → D) (W : M.Weights) : Unit → Q ⊕ M.Input → Coins → (D ⊕ (P.Stmt × P.Receipt)) × Unit :=
  fun _ i c => match i with
    | .inl qq => (.inl (H qq), ())
    | .inr x => (.inr (P.prove H W x c), ())

/-- **Ideal world**: the simulator sees the request only through `(publicPart (forward W X), leak X)`. There is ONE
function `Φ` of that pair and of the simulator's coins (it does not depend on `X` otherwise) such that, for every `X`,
the distinguisher succeeds exactly when `Φ` returns `some (g X)`. -/
theorem idealProb_semDist (S : Simulator M P) (W : M.Weights) (n : ℕ) (A : P.Stmt × P.Receipt → OC Q D β)
    (g : M.Input → β) :
    ∃ (Ω : Type) (u : PMF Ω) (Φ : M.PubOut × P.Leak → Ω → Option β), ∀ X,
      idealProb M P S W n (semDist P A g X)
        = u.toOuterMeasure {ω | Φ (M.publicPart (M.forward W X), P.leak X) ω = some (g X)} := by
  refine ⟨Fin n → S.SCoins, (haveI := S.fin; haveI := S.ne; PMF.uniformOfFintype (Fin n → S.SCoins)),
    fun z sc => haveI := S.inh
      (semCont P A (S.step (S.init W) (.inr z) (extend sc 0)).1).runState
        (fun s i c => S.step s (Sum.map id (fun x => (M.publicPart (M.forward W x), P.leak x)) i) c)
        (extend sc) 1 (S.step (S.init W) (.inr z) (extend sc 0)).2, fun X => ?_⟩
  unfold idealProb
  congr 1
  ext sc
  simp only [Set.mem_ofPred_eq, semDist, runState_mapOut, decide_eq_true_eq]
  rfl

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-- `realProb` with its responder named. -/
theorem realProb_eq (W : M.Weights) (n : ℕ) (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) :
    realProb M P W n Dist = (PMF.uniformOfFintype ((Q → D) × (Fin n → Coins))).toOuterMeasure
      {p | Dist.runState (realStep P p.1 W) (extend p.2) 0 () = true} := rfl

/-- **Real world**: the distinguisher succeeds exactly when `A`, given an honest receipt of `X` with a uniform coin,
guesses `g X`, i.e. with the probability on the left side of `SemanticHiding` for this `X`. -/
theorem realProb_semDist (W : M.Weights) (q : ℕ) (A : P.Stmt × P.Receipt → OC Q D β) (g : M.Input → β)
    (X : M.Input) :
    realProb M P W (q + 1) (semDist P A g X)
      = (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
          {p | (A (P.prove p.1 W X p.2)).run p.1 = g X} := by
  rw [realProb_eq]
  refine Eq.trans ?_ (prob_coin0 q _)
  congr 1
  ext p
  simp only [Set.mem_ofPred_eq, semDist, runState_mapOut, decide_eq_true_eq]
  have h0 : extend p.2 0 = p.2 0 := by simp [extend]
  have hrun : (semRun P A X).runState (realStep P p.1 W) (extend p.2) 0 ()
      = some ((A (P.prove p.1 W X (p.2 0))).run p.1) := by
    show (semCont P A (.inr (P.prove p.1 W X (extend p.2 0)))).runState (realStep P p.1 W) (extend p.2) (0 + 1) ()
      = _
    rw [h0]
    exact runState_liftHash p.1 (realStep P p.1 W) (fun _ _ => rfl) (extend p.2) _ _
  rw [hrun, Option.some.injEq]

/-- **T2 ⇒ T2′, as approved.** Zero knowledge with error `εzk` gives semantic hiding with error `εzk q 1`, the form
`ProductionReady.semantic` asks for. -/
theorem semanticHiding_of_zeroKnowledge {εzk : ℕ → ℕ → ℝ≥0∞} (h : ZeroKnowledge M P εzk) :
    SemanticHiding M P (fun q => εzk q 1) := by
  obtain ⟨S, hS⟩ := h
  intro W μ β g q A hA
  obtain ⟨Ω, u, Φ, hΦ⟩ := idealProb_semDist P S W (q + 1) A g
  have hX : ∀ X, (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
        {p | (A (P.prove p.1 W X p.2)).run p.1 = g X}
      ≤ u.toOuterMeasure {ω | Φ (M.publicPart (M.forward W X), P.leak X) ω = some (g X)} + εzk q 1 := by
    intro X
    have h1 := (hS W q 1 (semDist P A g X) (semDist_within P A g X hA)).1
    rwa [realProb_semDist, hΦ] at h1
  rw [PMF.toOuterMeasure_bind_apply]
  calc ∑' X, μ X * ((PMF.uniformOfFintype ((Q → D) × Coins)).map fun p => (X, p)).toOuterMeasure
          {t | (A (P.prove t.2.1 W t.1 t.2.2)).run t.2.1 = g t.1}
      = ∑' X, μ X * (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
          {p | (A (P.prove p.1 W X p.2)).run p.1 = g X} := by
        refine tsum_congr fun X => ?_
        rw [PMF.toOuterMeasure_map_apply]
        rfl
    _ ≤ ∑' X, μ X * (u.toOuterMeasure {ω | Φ (M.publicPart (M.forward W X), P.leak X) ω = some (g X)}
          + εzk q 1) := ENNReal.tsum_le_tsum fun X => by gcongr; exact hX X
    _ = ∑' X, μ X * u.toOuterMeasure {ω | Φ (M.publicPart (M.forward W X), P.leak X) ω = some (g X)}
          + εzk q 1 := by
        simp_rw [mul_add]
        rw [ENNReal.tsum_add, ENNReal.tsum_mul_right, μ.tsum_coe, one_mul]
    _ ≤ (⨆ B : M.PubOut × P.Leak → β, μ.toOuterMeasure {X | B (M.publicPart (M.forward W X), P.leak X) = g X})
          + εzk q 1 := by
        gcongr
        exact avg_le u μ (fun X => (M.publicPart (M.forward W X), P.leak X)) g Φ

end Semantic

/-! ## (b) Statement 1 from an IOP-level extraction, and the completeness analogue -/

section Sound

variable {Q D Coins : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **The IOP-level extraction**, the per-profile obligation for Statement 1's "only if". One extractor reads the
prover's hash-query log, the statement and the receipt, and returns an input `x`, an output `y`, a witness `w` and the
two salts. A prover making at most `q` hash queries gets a receipt accepted while the extraction fails (`w` does not
satisfy the constraint system at `(x, y)`, or the input commitment does not open to `x`, or the statement's public
output part is not `publicPart y`, or the hidden-output commitment does not open to `hiddenPart y`) with probability
at most `εiop q`. As in `KnowledgeSound`, the extractor does not take the weights.

For a profile this is L3's knowledge version (the committed matrices extracted from the log at each root's absorption,
the path-wise Fiat–Shamir bound with its hand-offs), read through the layout map: what it extracts must be a witness
of THIS `Arith`, at the logical positions `Satisfies` speaks of. -/
def IOPExtract (M : IntModel) (A : Arith M) (P : Protocol Q D Coins M) (εiop : ℕ → ℝ≥0∞) : Prop :=
  ∃ E : List (Q × D) → P.Stmt → P.Receipt → M.Input × M.Output × A.Witness × P.Salt × P.Salt,
    ∀ (W : M.Weights) (q : ℕ) (Adv : OC Q D (P.Stmt × P.Receipt)), Adv.Bounded q →
      prH (fun H =>
        let out := Adv.runLog H
        let s := out.1.1
        let pf := out.1.2
        let e := E out.2 s pf
        P.verify H W s pf = true
        ∧ ¬ (A.Satisfies W e.1 e.2.1 e.2.2.1
              ∧ P.opensIn H s e.1 e.2.2.2.1
              ∧ P.ypub s = M.publicPart e.2.1
              ∧ P.opensOut H s (M.hiddenPart e.2.1) e.2.2.2.2))
      ≤ εiop q

/-- **Statement 1's "only if" from the IOP-level extraction and `CircuitIff`.** The extractor of `KnowledgeSound` is
the IOP extractor with the output and the witness dropped. `CircuitIff`'s ⇒ direction turns "`w` satisfies the
constraints at `(x, y)`" into "`x` is admissible and `y = forward W x`"; so every run where `KnowledgeSound`'s
extraction fails is a run where the IOP extraction fails, and the error is the same `εiop`. -/
theorem knowledgeSound_of_extract {M : IntModel} {A : Arith M} {P : Protocol Q D Coins M} {εiop : ℕ → ℝ≥0∞}
    (hC : CircuitIff M A) (hE : IOPExtract M A P εiop) : KnowledgeSound M P εiop := by
  obtain ⟨E, hE⟩ := hE
  refine ⟨fun L s pf => ((E L s pf).1, (E L s pf).2.2.2.1, (E L s pf).2.2.2.2), fun W q Adv hAdv => ?_⟩
  refine le_trans (MeasureTheory.measure_mono ?_) (hE W q Adv hAdv)
  rintro H ⟨hv, hn⟩
  refine ⟨hv, fun ⟨hsat, hin, hpub, hout⟩ => hn ?_⟩
  obtain ⟨hadm, hy⟩ := (hC W _ _).1 ⟨_, hsat⟩
  rw [hy] at hpub hout
  exact ⟨hadm, hin, hpub, hout⟩

variable [Fintype Coins] [Nonempty Coins]

/-- **The completeness analogue at the constraint system's level**: for every input that has a satisfying assignment
`(y, w)`, the honest receipt is accepted, carries `publicPart y`, and its commitments open to the input and to
`hiddenPart y`, except with probability `εc`. -/
def ArithComplete (M : IntModel) (A : Arith M) (P : Protocol Q D Coins M) (εc : ℝ≥0∞) : Prop :=
  ∀ (W : M.Weights) (x : M.Input) (y : M.Output) (w : A.Witness), A.Satisfies W x y w →
    1 - εc ≤ prHC (fun H c =>
      let sr := P.prove H W x c
      P.verify H W sr.1 sr.2 = true
      ∧ P.ypub sr.1 = M.publicPart y
      ∧ (∃ r, P.opensIn H sr.1 x r)
      ∧ (∃ r, P.opensOut H sr.1 (M.hiddenPart y) r))

/-- **Statement 1's "if" from the completeness analogue and `CircuitIff`**: `CircuitIff`'s ⇐ direction gives an
admissible input a satisfying assignment with the model's output. -/
theorem complete_of_arithComplete {M : IntModel} {A : Arith M} {P : Protocol Q D Coins M} {εc : ℝ≥0∞}
    (hC : CircuitIff M A) (h : ArithComplete M A P εc) : Complete M P εc := by
  intro W x hx
  obtain ⟨w, hw⟩ := (hC W x (M.forward W x)).2 ⟨hx, rfl⟩
  exact h W x _ w hw

/-- Under `CircuitIff` the two completeness forms are the same statement. -/
theorem arithComplete_iff_complete {M : IntModel} {A : Arith M} {P : Protocol Q D Coins M} {εc : ℝ≥0∞}
    (hC : CircuitIff M A) : ArithComplete M A P εc ↔ Complete M P εc := by
  refine ⟨complete_of_arithComplete hC, fun h W x y w hw => ?_⟩
  obtain ⟨hx, hy⟩ := (hC W x y).1 ⟨w, hw⟩
  subst hy
  exact h W x hx

end Sound

/-! ## (c) The assembly, and monotonicity in the error terms -/

section Assemble

variable {Q D Coins : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
  {M : IntModel} {A : Arith M} {P : Protocol Q D Coins M}

theorem knowledgeSound_mono {εs εs' : ℕ → ℝ≥0∞} (h : KnowledgeSound M P εs) (hle : ∀ q, εs q ≤ εs' q) :
    KnowledgeSound M P εs' := by
  obtain ⟨E, hE⟩ := h
  exact ⟨E, fun W q Adv hAdv => le_trans (hE W q Adv hAdv) (hle q)⟩

theorem iopExtract_mono {εiop εiop' : ℕ → ℝ≥0∞} (h : IOPExtract M A P εiop) (hle : ∀ q, εiop q ≤ εiop' q) :
    IOPExtract M A P εiop' := by
  obtain ⟨E, hE⟩ := h
  exact ⟨E, fun W q Adv hAdv => le_trans (hE W q Adv hAdv) (hle q)⟩

theorem binding_mono {εb εb' : ℕ → ℝ≥0∞} (h : Binding M P εb) (hle : ∀ q, εb q ≤ εb' q) : Binding M P εb' :=
  ⟨fun q Adv hAdv => le_trans (h.1 q Adv hAdv) (hle q), fun q Adv hAdv => le_trans (h.2 q Adv hAdv) (hle q)⟩

variable [Fintype Coins] [Nonempty Coins]

theorem complete_mono {εc εc' : ℝ≥0∞} (h : Complete M P εc) (hle : εc ≤ εc') : Complete M P εc' :=
  fun W x hx => le_trans (tsub_le_tsub_left hle 1) (h W x hx)

variable [Inhabited Coins]

/-- **The production gate from its per-profile parts.** `CircuitIff` (L2), the IOP-level extraction (L3 with the
layout map), completeness, binding and zero knowledge (L4) give `ProductionReady`: the soundness field by
`knowledgeSound_of_extract`, the semantic-hiding field by `semanticHiding_of_zeroKnowledge`. -/
theorem productionReady_of {εc : ℝ≥0∞} {εiop εb : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (hC : CircuitIff M A) (hE : IOPExtract M A P εiop) (hc : Complete M P εc) (hb : Binding M P εb)
    (hzk : ZeroKnowledge M P εzk) : ProductionReady M A P εc εiop εb εzk where
  circuit := hC
  complete := hc
  sound := knowledgeSound_of_extract hC hE
  binding := hb
  zk := hzk
  semantic := semanticHiding_of_zeroKnowledge P hzk

/-- The same with completeness at the constraint system's level. -/
theorem productionReady_of_arith {εc : ℝ≥0∞} {εiop εb : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (hC : CircuitIff M A) (hE : IOPExtract M A P εiop) (hc : ArithComplete M A P εc) (hb : Binding M P εb)
    (hzk : ZeroKnowledge M P εzk) : ProductionReady M A P εc εiop εb εzk :=
  productionReady_of hC hE (complete_of_arithComplete hC hc) hb hzk

theorem zeroKnowledge_mono {εzk εzk' : ℕ → ℕ → ℝ≥0∞} (h : ZeroKnowledge M P εzk)
    (hle : ∀ q R, εzk q R ≤ εzk' q R) : ZeroKnowledge M P εzk' := by
  obtain ⟨S, hS⟩ := h
  exact ⟨S, fun W q R Dist hD =>
    ⟨le_trans (hS W q R Dist hD).1 (add_le_add le_rfl (hle q R)),
      le_trans (hS W q R Dist hD).2 (add_le_add le_rfl (hle q R))⟩⟩

/-- **The error terms are monotone**: a profile proved `ProductionReady` with its own bounds is `ProductionReady` with
any larger ones (for example the approved targets `εcTarget`, `εsTarget`, `εzkTarget`). -/
theorem productionReady_mono {εc εc' : ℝ≥0∞} {εs εs' εb εb' : ℕ → ℝ≥0∞} {εzk εzk' : ℕ → ℕ → ℝ≥0∞}
    (h : ProductionReady M A P εc εs εb εzk) (hc : εc ≤ εc') (hs : ∀ q, εs q ≤ εs' q) (hb : ∀ q, εb q ≤ εb' q)
    (hzk : ∀ q R, εzk q R ≤ εzk' q R) : ProductionReady M A P εc' εs' εb' εzk' where
  circuit := h.circuit
  complete := complete_mono h.complete hc
  sound := knowledgeSound_mono h.sound hs
  binding := binding_mono h.binding hb
  zk := zeroKnowledge_mono h.zk hzk
  semantic := semanticHiding_of_zeroKnowledge P (zeroKnowledge_mono h.zk hzk)

end Assemble

/-! ## (d) `Binding` from Merkle binding, for commitments opened column by column -/

section MerkleBind

open Sound

variable {Q D S Col St V Salt : Type}

/-- **A commitment opened column by column.** The statement names a root (`root`). A value `v` with opening data `r`
has the column `col v r j` at each of the `N` positions, with its salt `salt r j` and its authentication path
`path r j`. The columns determine the value (`col_inj`): for an encoded plane with mask rows, the data rows' code words
are part of the columns, and the code is injective. -/
structure ColCommit (Q D S Col St V Salt : Type) where
  enc : MerkleEnc Q D S Col
  h : ℕ
  N : ℕ
  root : St → D
  col : V → Salt → Fin N → Col
  salt : Salt → Fin N → S
  path : Salt → Fin N → List D
  col_inj : ∀ v r v' r', (∀ j, col v r j = col v' r' j) → v = v'

namespace ColCommit

/-- The statement's commitment opens to `v` with `r`: every column verifies at its position against the statement's
root (`MerkleEnc.Opens`: the depth check and the climb, as `pcs::verify_zk_tagged` checks one column). -/
def Opens (C : ColCommit Q D S Col St V Salt) (H : Q → D) (s : St) (v : V) (r : Salt) : Prop :=
  ∀ j : Fin C.N, C.enc.Opens H C.h (C.root s) j.val ⟨C.col v r j, C.salt r j, C.path r j⟩

open Classical in
/-- The reduction's choice: a position where the two values' columns differ, and the two openings there. -/
noncomputable def diffCol [Inhabited S] [Inhabited Col] (C : ColCommit Q D S Col St V Salt) (v : V) (r : Salt)
    (v' : V) (r' : Salt) : ℕ × MerkleOpening D S Col × MerkleOpening D S Col :=
  if hj : ∃ j, C.col v r j ≠ C.col v' r' j then
    (hj.choose.val, ⟨C.col v r hj.choose, C.salt r hj.choose, C.path r hj.choose⟩,
      ⟨C.col v' r' hj.choose, C.salt r' hj.choose, C.path r' hj.choose⟩)
  else (0, ⟨default, default, []⟩, ⟨default, default, []⟩)

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **Binding of a column-by-column commitment.** An adversary making at most `q` hash queries opens one statement's
commitment to two different values with probability at most `collBound (q + 2(h + 2)) D`, the bound of
`merkle_binding`. The reduction runs the adversary, picks a position where the two values' columns differ (one exists
by `col_inj`) and outputs the two openings there; it makes no further query. -/
theorem binding [Inhabited S] [Inhabited Col] (C : ColCommit Q D S Col St V Salt) (q : ℕ)
    (A : OC Q D (St × V × Salt × V × Salt)) (hA : A.Bounded q) :
    prH (fun H =>
      let o := A.run H
      o.2.1 ≠ o.2.2.2.1 ∧ C.Opens H o.1 o.2.1 o.2.2.1 ∧ C.Opens H o.1 o.2.2.2.1 o.2.2.2.2)
      ≤ collBound (q + 2 * (C.h + 2)) D := by
  classical
  let B : OC Q D (D × ℕ × MerkleOpening D S Col × MerkleOpening D S Col) :=
    A.bind (fun o => .ret (C.root o.1, C.diffCol o.2.1 o.2.2.1 o.2.2.2.1 o.2.2.2.2))
  have hB : B.Bounded q :=
    OC.Bounded.bind (q := 0) hA (fun o =>
      (trivial : (OC.ret (C.root o.1, C.diffCol o.2.1 o.2.2.1 o.2.2.2.1 o.2.2.2.2) : OC Q D _).Bounded 0))
  refine le_trans (MeasureTheory.measure_mono ?_) (C.enc.merkle_binding C.h q B hB)
  intro H hH
  obtain ⟨hne, h1, h2⟩ := hH
  have hj : ∃ j, C.col (A.run H).2.1 (A.run H).2.2.1 j ≠ C.col (A.run H).2.2.2.1 (A.run H).2.2.2.2 j := by
    by_contra hall
    exact hne (C.col_inj _ _ _ _ fun j => Classical.byContradiction fun h => hall ⟨j, h⟩)
  have hBrun : B.run H
      = (C.root (A.run H).1, C.diffCol (A.run H).2.1 (A.run H).2.2.1 (A.run H).2.2.2.1 (A.run H).2.2.2.2) := by
    simp only [B, OC.run_bind]
    rfl
  have hd : C.diffCol (A.run H).2.1 (A.run H).2.2.1 (A.run H).2.2.2.1 (A.run H).2.2.2.2
      = (hj.choose.val, ⟨C.col (A.run H).2.1 (A.run H).2.2.1 hj.choose, C.salt (A.run H).2.2.1 hj.choose,
          C.path (A.run H).2.2.1 hj.choose⟩,
        ⟨C.col (A.run H).2.2.2.1 (A.run H).2.2.2.2 hj.choose, C.salt (A.run H).2.2.2.2 hj.choose,
          C.path (A.run H).2.2.2.2 hj.choose⟩) := by
    unfold diffCol
    rw [dite_eq_left hj]
  show (B.run H).2.2.1.col ≠ (B.run H).2.2.2.col
    ∧ C.enc.Opens H C.h (B.run H).1 (B.run H).2.1 (B.run H).2.2.1
    ∧ C.enc.Opens H C.h (B.run H).1 (B.run H).2.1 (B.run H).2.2.2
  rw [hBrun, hd]
  exact ⟨hj.choose_spec, h1 hj.choose, h2 hj.choose⟩

end ColCommit

/-- **`Binding` of a protocol whose two commitments are opened column by column.** If the statement's input
commitment opens exactly as `Cin` and its hidden-output commitment exactly as `Cout`, `Binding` holds with the sum of
the two Merkle collision bounds. What stays per profile: that the profile's `opensIn` / `opensOut` ARE such openings,
and `col_inj` for its encodings. -/
theorem binding_of_colCommit [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] {Coins : Type} {M : IntModel}
    (P : Protocol Q D Coins M) {S₁ Col₁ S₂ Col₂ : Type} [Inhabited S₁] [Inhabited Col₁] [Inhabited S₂]
    [Inhabited Col₂] (Cin : ColCommit Q D S₁ Col₁ P.Stmt M.Input P.Salt)
    (Cout : ColCommit Q D S₂ Col₂ P.Stmt M.HidOut P.Salt)
    (hin : ∀ H s x r, P.opensIn H s x r ↔ Cin.Opens H s x r)
    (hout : ∀ H s y r, P.opensOut H s y r ↔ Cout.Opens H s y r) :
    Binding M P (fun q => collBound (q + 2 * (Cin.h + 2)) D + collBound (q + 2 * (Cout.h + 2)) D) := by
  refine ⟨fun q A hA => ?_, fun q A hA => ?_⟩
  · refine le_trans (le_trans (MeasureTheory.measure_mono ?_) (Cin.binding q A hA)) le_self_add
    rintro H ⟨hne, h1, h2⟩
    exact ⟨hne, (hin _ _ _ _).1 h1, (hin _ _ _ _).1 h2⟩
  · refine le_trans (le_trans (MeasureTheory.measure_mono ?_) (Cout.binding q A hA)) le_add_self
    rintro H ⟨hne, h1, h2⟩
    exact ⟨hne, (hout _ _ _ _).1 h1, (hout _ _ _ _).1 h2⟩

end MerkleBind

end ZK60.Assembly
