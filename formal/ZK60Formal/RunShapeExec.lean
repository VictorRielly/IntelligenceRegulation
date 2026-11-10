/-
D63 lane L40 (2026-11-10), part 5: **a COMPUTABLE TWIN of the approved integer model, PROVED equal to it** (the gap
audit's finding GB-8: "the approved `forward` is noncomputable and has never been run").

The approved model's pieces are noncomputable only through L2's plane lift `liftO` (a choice, CircuitStage.lean:32)
and through `if`s on propositions without a decision procedure in scope (`NormOK`). Here:
* `Tab`, `memo`, **`memo_eq`**: a finite domain tabulated into an array (so a plane is computed once and read in
  constant time), equal to the function it tabulates;
* `liftOC`, **`liftOC_eq`**, `liftOM`, **`liftOM_eq`**: the plane lift decided over a finite domain, then tabulated,
  EQUAL to `liftO`;
* `normTokC`, `softmaxFC`, `normAC`, `normMC`, `smSpecC`, **`blockSpecC`**: the block's stages with the twin lift;
  **`blockSpecC_eq`**: `blockSpecC P x = blockSpec P x` for every shape, public data and input;
* `runSpecPC`, **`runSpecPC_eq`**: the per-block-shape run (`RunShape.lean`);
* `inSpecC`, `fnormTokC`, `outCSpecC`, **`classifySpecPC`**, **`classifySpecPC_eq`**: the per-block-shape classifier
  model, so running `classifySpecPC` IS running the approved `forward` of `classifyModelP R` (`forward_eq_twin`).
`RunShapeCheck.lean` (not imported) runs `blockSpecC` on the committed R13 trace fixture and compares every stage with
the Rust witness builder's words.
-/
import ZK60Formal.RunShape

set_option autoImplicit false

namespace ZK60.RunShape.Exec

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Out ZK60.TokenRun ZK60.RunShape

/-! ## Tabulating a finite domain -/

/-- An explicit enumeration of a finite domain: an index in `Fin n` for every point, and back. -/
class Tab (α : Type) where
  n : ℕ
  enc : α → Fin n
  dec : Fin n → α
  dec_enc : ∀ a, dec (enc a) = a

instance tabFin (k : ℕ) : Tab (Fin k) := ⟨k, id, id, fun _ => rfl⟩

instance tabBool : Tab Bool where
  n := 2
  enc b := if b then 1 else 0
  dec i := decide (i.val = 1)
  dec_enc b := by cases b <;> rfl

instance tabProd {α β : Type} [Tab α] [Tab β] : Tab (α × β) where
  n := Tab.n (α := α) * Tab.n (α := β)
  enc p := finProdFinEquiv (Tab.enc p.1, Tab.enc p.2)
  dec i := (Tab.dec (finProdFinEquiv.symm i).1, Tab.dec (finProdFinEquiv.symm i).2)
  dec_enc p := by simp [Tab.dec_enc]

/-- **A function tabulated once** into an array and read back by index. -/
def memo {α β : Type} [Tab α] (f : α → β) : α → β :=
  let arr := Array.ofFn (fun i : Fin (Tab.n (α := α)) => f (Tab.dec i))
  have hs : arr.size = Tab.n (α := α) := Array.size_ofFn
  fun a => arr[(Tab.enc a).val]'(by rw [hs]; exact (Tab.enc a).isLt)

/-- **The tabulated function is the function.** -/
theorem memo_eq {α β : Type} [Tab α] (f : α → β) : memo f = f := by
  funext a
  simp only [memo, Array.getElem_ofFn, Fin.eta, Tab.dec_enc]

/-! ## The plane lift, decided and tabulated -/

/-- L2's plane lift decided over a finite domain. -/
def liftOC {P α : Type} [Fintype P] (f : P → Option α) : Option (P → α) :=
  if h : ∀ p, (f p).isSome = true then some (fun p => (f p).get (h p)) else none

theorem liftOC_eq {P α : Type} [Fintype P] (f : P → Option α) : liftOC f = liftO f := by
  unfold liftOC
  split_ifs with h
  · symm
    rw [liftO_eq_some]
    intro p
    exact (Option.some_get (h p)).symm
  · symm
    cases hl : liftO f with
    | none => rfl
    | some v =>
      exact absurd (fun p => by rw [liftO_eq_some.mp hl p]; rfl) h

/-- **The twin lift**: decided, then tabulated. -/
def liftOM {P α : Type} [Fintype P] [Tab P] (f : P → Option α) : Option (P → α) := (liftOC f).map memo

/-- **The twin lift IS L2's `liftO`.** -/
theorem liftOM_eq {P α : Type} [Fintype P] [Tab P] (f : P → Option α) : liftOM f = liftO f := by
  unfold liftOM
  rw [liftOC_eq]
  cases liftO f with
  | none => rfl
  | some v => simp only [Option.map_some, memo_eq]

/-! ## The block's stages -/

instance decNormOK (ss : ℤ) : Decidable (NormOK ss) := by unfold NormOK; infer_instance

/-- One RMSNorm row, computable (L2's `normTok`). -/
def normTokC {n : ℕ} (ceps cn : ℤ) (tn : ℕ) (gam x : Fin n → ℤ) : Option (ℤ × (Fin n → ℤ)) :=
  if NormOK (ssOf ceps x) then
    (liftOM fun i => (normElem tn cn (isqrtWitness (ssOf ceps x)).1 (x i) (gam i)).map Prod.fst).map
      fun y => ((isqrtWitness (ssOf ceps x)).1, y)
  else none

theorem normTokC_eq {n : ℕ} (ceps cn : ℤ) (tn : ℕ) (gam x : Fin n → ℤ) :
    normTokC ceps cn tn gam x = normTok ceps cn tn gam x := by
  unfold normTokC normTok
  split_ifs <;> simp only [liftOM_eq]

/-- One softmax row, computable (L2's `softmaxF`). -/
def softmaxFC {T : ℕ} (fp wrho : ℕ) (exp : ℤ → ℤ) (t : Fin T) (s : Fin T → ℤ) : Option (Fin T → ℤ) :=
  if 0 < totalOf exp t s ∧ ∀ j, 0 ≤ bestOf t s - smOf t s j ∧ bestOf t s - smOf t s j < 256 then
    liftOM fun j => if totalOf exp t s - 1 - numOf fp exp t s j % totalOf exp t s < 2 ^ wrho
      then some (numOf fp exp t s j / totalOf exp t s) else none
  else none

theorem softmaxFC_eq {T : ℕ} (fp wrho : ℕ) (exp : ℤ → ℤ) (t : Fin T) (s : Fin T → ℤ) :
    softmaxFC fp wrho exp t s = softmaxF fp wrho exp t s := by
  unfold softmaxFC softmaxF
  split_ifs <;> simp only [liftOM_eq]

variable {S : BlockShape}

def normAC (P : BlockPublic S) (x : S.Pos → ℤ) (t : S.Tok) : Option (ℤ × (S.Wid → ℤ)) :=
  normTokC S.ceps S.cnA S.tn P.gA fun i => x (t, i)

def normMC (P : BlockPublic S) (x1 : S.Pos → ℤ) (t : S.Tok) : Option (ℤ × (S.Wid → ℤ)) :=
  normTokC S.ceps S.cnM S.tn P.gM fun i => x1 (t, i)

def smSpecC (P : BlockPublic S) (sc : Fin S.H × S.Tok × S.Tok → ℤ) (r : Fin S.H × S.Tok) : Option (S.Tok → ℤ) :=
  softmaxFC S.fp S.wrho P.exp r.2 fun j => sc (r.1, r.2, j)

theorem normAC_eq (P : BlockPublic S) (x : S.Pos → ℤ) : normAC P x = normA P x :=
  funext fun _ => normTokC_eq _ _ _ _ _

theorem normMC_eq (P : BlockPublic S) (x1 : S.Pos → ℤ) : normMC P x1 = normM P x1 :=
  funext fun _ => normTokC_eq _ _ _ _ _

theorem smSpecC_eq (P : BlockPublic S) (sc : Fin S.H × S.Tok × S.Tok → ℤ) : smSpecC P sc = smSpec P sc :=
  funext fun _ => softmaxFC_eq _ _ _ _ _

/-- **The integer block, computable**: L2's `blockSpec` stage by stage, every plane tabulated once. -/
def blockSpecC (P : BlockPublic S) (x : S.Pos → ℤ) : Option (S.Pos → ℤ) :=
  (liftOM (normAC P x)).bind fun na =>
  (liftOM (qSpec P (rowY na))).bind fun q =>
  (liftOM (kSpec P (rowY na))).bind fun k =>
  (liftOM (vSpec P (rowY na))).bind fun v =>
  (liftOM (qrSpec P q)).bind fun qr =>
  (liftOM (krSpec P k)).bind fun kr =>
  (liftOM (sSpec qr kr)).bind fun sc =>
  (liftOM (smSpecC P sc)).bind fun pr =>
  (liftOM (oSpec pr v)).bind fun o =>
  (liftOM (aoSpec P o)).bind fun ao =>
  (liftOM (x1Spec x ao)).bind fun x1 =>
  (liftOM (normMC P x1)).bind fun nm =>
  (liftOM (gSpec P (rowY nm))).bind fun g =>
  (liftOM (uSpec P (rowY nm))).bind fun u =>
  (liftOM (hSpec P g u)).bind fun h =>
  (liftOM (zSpec P h)).bind fun z =>
  liftOM (x2Spec x1 z)

/-- **The computable block IS the approved integer block** (`blockSpec`, CircuitBlock.lean), for every shape, public
data and input. -/
theorem blockSpecC_eq (P : BlockPublic S) (x : S.Pos → ℤ) : blockSpecC P x = blockSpec P x := by
  unfold blockSpecC blockSpec
  simp only [liftOM_eq, normAC_eq, normMC_eq, smSpecC_eq]

/-! ## The per-block-shape run and the classifier -/

variable {S0 : BlockShape}

/-- The per-block-shape run, computable. -/
def runSpecPC : List (RunBlock S0) → (S0.Pos → ℤ) → Option (S0.Pos → ℤ)
  | [], x => some x
  | b :: bs, x => (blockSpecC b.pub x).bind fun y => runSpecPC bs y

theorem runSpecPC_eq : ∀ (bs : List (RunBlock S0)) (x : S0.Pos → ℤ), runSpecPC bs x = runSpecP bs x
  | [], _ => rfl
  | b :: bs, x => by
    show (blockSpecC b.pub x).bind (runSpecPC (S0 := S0) bs) = (blockSpec b.pub x).bind (runSpecP (S0 := S0) bs)
    rw [blockSpecC_eq, funext (runSpecPC_eq bs)]

/-- Stage IN-C's integer semantics, computable (L2's `inSpec`). -/
def inSpecC (P : InPublic S0) (toks : S0.Tok → ℕ) : Option (S0.Pos → ℤ) :=
  if (∀ t, toks t < P.V) ∧ (∀ t : S0.Tok, (t : ℕ) = 0 → toks t = P.bos) ∧ (∀ t, P.isT t = true → toks t = P.kap t) ∧
      (∀ t, P.isT t = false → ¬ toks t < P.ns)
  then some (fun p => P.emb (toks p.1) p.2) else none

theorem inSpecC_eq (P : InPublic S0) (toks : S0.Tok → ℕ) : inSpecC P toks = inSpec P toks := by
  unfold inSpecC inSpec
  split_ifs <;> rfl

/-- The final norm of stage OUT-C, computable (L4's `fnormTok`). -/
def fnormTokC {n : ℕ} (ceps cn g0 : ℤ) (tn : ℕ) (x : Fin n → ℤ) : Option (ℤ × (Fin n → ℤ)) :=
  if (∀ i, i16 (x i)) ∧ NormOK (ssOf ceps x) then
    (liftOM fun i => (fnormElem tn cn g0 32 (isqrtWitness (ssOf ceps x)).1 (x i)).map Prod.fst).map
      fun y => ((isqrtWitness (ssOf ceps x)).1, y)
  else none

theorem fnormTokC_eq {n : ℕ} (ceps cn g0 : ℤ) (tn : ℕ) (x : Fin n → ℤ) :
    fnormTokC ceps cn g0 tn x = fnormTok ceps cn g0 tn x := by
  unfold fnormTokC fnormTok
  split_ifs <;> simp only [liftOM_eq]

/-- Stage OUT-C's integer semantics on one row, computable (L4's `outCSpec`). -/
def outCSpecC {n : ℕ} (P : OutCPublic n) (x : Fin n → ℤ) : Option ℕ :=
  (fnormTokC P.ceps P.cn P.g0 P.tn x).map fun dy => verdictOf (margin P dy.2) P.c

theorem outCSpecC_eq {n : ℕ} (P : OutCPublic n) (x : Fin n → ℤ) : outCSpecC P x = outCSpec P x := by
  unfold outCSpecC outCSpec
  rw [fnormTokC_eq]

/-- **The per-block-shape classifier model, computable.** -/
def classifySpecPC (R : ClassifyRunPublicP S0) (toks : S0.Tok → ℕ) : Option ℕ :=
  (inSpecC R.inp toks).bind fun x => (runSpecPC R.blks x).bind fun y => outCSpecC R.out fun i => y (R.row, i)

/-- **The computable classifier IS the approved per-block-shape model** (`classifySpecP`). -/
theorem classifySpecPC_eq (R : ClassifyRunPublicP S0) (toks : S0.Tok → ℕ) :
    classifySpecPC R toks = classifySpecP R toks := by
  unfold classifySpecPC classifySpecP
  simp only [inSpecC_eq, runSpecPC_eq, outCSpecC_eq]

/-- **Running the twin IS running the approved `forward`** of the per-block-shape classifier's `IntModel`. -/
theorem forward_eq_twin (R : ClassifyRunPublicP S0) (toks : S0.Tok → ℕ) :
    (classifyModelP R).forward () toks = (classifySpecPC R toks).getD 0 := by
  show (classifySpecP R toks).getD 0 = _
  rw [classifySpecPC_eq]

end ZK60.RunShape.Exec
