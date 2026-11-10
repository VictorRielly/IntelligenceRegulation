/-
Gap audit (premise register, 2026-11-10), scratch file B: small PROVED probes of the top theorems' premises.
Never imported by the root; run with `lake env lean`. No sorry, axiom or native_decide.

* `gap_o11_top`: `ClassifyOpen`'s O11 fields (`extIn`, `extBlocks`, `extOut`, `extEp`) are met by `le_top` once the
  implicit errors `εin … εep` are `⊤`; the top theorems leave those errors free, so O11 is not an obligation there.
* `gap_zk_passthrough`: the `zk` and `semantic` conjuncts of the top theorems' conclusion follow from `O.zk` (O12) and
  `hzk` ALONE: Statement 2 is assumed, not derived.
* `gap_segComplete_refuser`: a segment prover that always refuses meets `SegComplete` against ANY verifier (O8 alone
  does not tie the Lean prover to anything; its content is O8 with O9 and O10).
* `gap_circuitIff_free`: `CircuitIff` holds for the classifier model with the trivial `Arith` (Statements.lean's own
  `trivialArith_circuitIff`): the `circuit` conjunct constrains nothing on its own.
* `gap_epsC_lt_one`, `gap_epsS_lt_one`, `gap_epsZk_top`: the targets are below 1 where they should be (`εcTarget`;
  `εsTarget q` for `q ≤ 2^98`), and `εzkTarget q R ≥ 1` once `R ≥ 2^120` (beyond that the ZK statement is empty).
* `gap_block_end_free`: a bound of the form `X ≤ εsTarget q + εend` says nothing at `εend = ⊤`, the value at which the
  block theorems' only constraint on `εend` (`hEnd`) holds for every adversary.
-/
import ZK60Formal

set_option autoImplicit false

namespace GapAudit

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.ProtocolClassify

variable {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [Algebra ZK60.Circuit.GF K]

/-- **O11 is not an obligation of the top theorems.** From the fields O1 to O10 and O12 alone, a `ClassifyOpen` exists
at `εin = εblk = εout = εep = ⊤`. The top theorems (`rt_productionReady_r13`, `classifyU_productionReady_run_r13_token`,
`classifyUExec_productionReady_run_r13`) take these four errors as free implicit arguments and conclude at the approved
targets whatever they are. -/
theorem gap_o11_top (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (hon : HonestIn Coins Cin) (U : K) {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K)
    (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞) (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    (εzk : ℕ → ℕ → ℝ≥0∞)
    (shape : S.Valid) (weights : ∀ B ∈ R.Ps, B.Valid) (inPub : R.inp.Valid) (outPub : R.out.Valid)
    (blocks : 0 < R.Ps.length ∧ V.L = R.Ps.length)
    (commit : (∀ x : S.Tok → ℕ, (∀ t, x t < ZK60.Circuit.gP) → Cin.ok x) ∧ Cin.N ≤ 2 ^ Cin.depth
      ∧ (∀ s : ClsStmt Hdr, Cin.root s = s.inRoot) ∧ Cin.depth ≤ 64)
    (policy : V.preA P.hdr = .ok () ∧ V.preB P.hdr = .ok ())
    (parts : List.Forall₂ (SegComplete (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr hon.base))
      (P.parts V.L) V.parts)
    (refuse : ∀ x, (classifyModel S R).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires U G c) →
      ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpec R x).getD 0) x c = .ok r)
    (counts : (∀ x i, (site x i).k ≤ kOf i) ∧ (∀ x i, (site x i).δ ≤ δOf i) ∧ ∑ i, kOf i ≤ 2 ^ 85
      ∧ ∑ i, δOf i ≤ (2⁻¹ : ℝ≥0∞) ^ 41)
    (zk : ZeroKnowledge (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base) εzk) :
    ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E (fun _ => ⊤) (fun _ => ⊤) (fun _ => ⊤) (fun _ => ⊤) εzk :=
  ⟨shape, weights, inPub, outPub, blocks, commit, policy, parts, refuse, counts,
    fun _ _ _ => le_top, fun _ _ _ => le_top, fun _ _ _ => le_top, fun _ _ _ => le_top, zk⟩

/-- **Statement 2 is assumed, not derived.** The `zk` and `semantic` conjuncts of the top theorems' conclusion (at
`classifyProtocolU … e`, `εzkTarget`) follow from `O.zk` and `hzk` alone, with no other premise. -/
theorem gap_zk_passthrough (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (hon : HonestIn Coins Cin) (U : K) {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K)
    (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞) (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk)
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') (e : ℕ) :
    ZeroKnowledge (classifyModel S R) (classifyProtocolU S R Lq V P Cin h64 hr hon.base e) εzkTarget
      ∧ SemanticHiding (classifyModel S R) (classifyProtocolU S R Lq V P Cin h64 hr hon.base e)
          (fun q => εzkTarget q 1) := by
  have h := zkU_of_zk (R := R) (Lq := Lq) (V := V) (P := P) (Cin := Cin) (h64 := h64) (hr := hr)
    (base := hon.base) (e := e) O.zk
  have h' := ZK60.Assembly.zeroKnowledge_mono (h := h) (hle := hzk)
  exact ⟨h', ZK60.Assembly.semanticHiding_of_zeroKnowledge _ h'⟩

/-- **O8 alone pins nothing**: a segment prover that always refuses meets `SegComplete` against any segment verifier. -/
theorem gap_segComplete_refuser {St X Cn Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Cn → St)
    (v : SegV St) : SegComplete adm hOf stOf (⟨fun _ _ _ _ _ _ _ _ => .error ()⟩ : SegP St X Cn) v := by
  intro g x c bnd cr t enc cr' t' _ h
  exact absurd h (by simp)

/-- **`CircuitIff` constrains nothing on its own**: the classifier model has a `CircuitIff` arithmetization, the trivial
one (Statements.lean's `trivialArith_circuitIff`). The relation that matters is `M.forward`, which `KnowledgeSound` and
`Complete` read directly. -/
theorem gap_circuitIff_free (R : ClassifyRunPublic S) :
    CircuitIff (classifyModel S R) (trivialArith (classifyModel S R)) :=
  trivialArith_circuitIff _

/-- The model's weights and hidden output are `Unit`: the `∀ W` of the approved statements ranges over one point; the
weights live in the public run data `R`, a parameter of the instance. -/
theorem gap_units (R : ClassifyRunPublic S) :
    (classifyModel S R).Weights = Unit ∧ (classifyModel S R).HidOut = Unit := ⟨rfl, rfl⟩

/-! ## The targets' values -/

theorem gap_half_lt_one : (2⁻¹ : ℝ≥0∞) < 1 := ENNReal.inv_lt_one.mpr ENNReal.one_lt_two

/-- `εcTarget < 1`. -/
theorem gap_epsC_lt_one : εcTarget < 1 := by
  unfold εcTarget
  exact lt_of_le_of_lt (pow_le_of_le_one (by positivity) gap_half_lt_one.le (by norm_num)) gap_half_lt_one

/-- `εsTarget q = (q + 1)·2^-100`, below `1` for `q ≤ 2^98`. -/
theorem gap_epsS_lt_one (q : ℕ) (hq : q ≤ 2 ^ 98) : εsTarget q < 1 := by
  unfold εsTarget
  have h1 : (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 100 ≤ (2⁻¹ : ℝ≥0∞) ^ 2 := by
    calc (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 100 ≤ ((2 ^ 98 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 100 :=
          mul_le_mul' (by exact_mod_cast hq) le_rfl
      _ = (2⁻¹ : ℝ≥0∞) ^ 2 := by
          rw [show (100 : ℕ) = 98 + 2 by norm_num, pow_add, ← mul_assoc, Nat.cast_pow, Nat.cast_ofNat,
            ← mul_pow, ENNReal.mul_inv_cancel two_ne_zero ENNReal.ofNat_ne_top, one_pow, one_mul]
  have h2 : (2⁻¹ : ℝ≥0∞) ^ 100 ≤ (2⁻¹ : ℝ≥0∞) ^ 2 :=
    pow_le_pow_right_of_le_one' gap_half_lt_one.le (by norm_num)
  have h3 : (2⁻¹ : ℝ≥0∞) ^ 2 + (2⁻¹ : ℝ≥0∞) ^ 2 = 2⁻¹ := by
    rw [← two_mul, pow_two, ← mul_assoc, ENNReal.mul_inv_cancel two_ne_zero ENNReal.ofNat_ne_top, one_mul]
  calc (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 100 + (2⁻¹ : ℝ≥0∞) ^ 100 ≤ (2⁻¹ : ℝ≥0∞) ^ 2 + (2⁻¹ : ℝ≥0∞) ^ 2 :=
        add_le_add h1 h2
    _ = 2⁻¹ := h3
    _ < 1 := gap_half_lt_one

/-- `εzkTarget q R ≥ 1` once `R ≥ 2^120`: the zero-knowledge statement is empty beyond `2^120` receipts. -/
theorem gap_epsZk_top (q R : ℕ) (hR : 2 ^ 120 ≤ R) : 1 ≤ εzkTarget q R := by
  unfold εzkTarget
  have h : (1 : ℝ≥0∞) = ((2 ^ 120 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120 := by
    rw [Nat.cast_pow, Nat.cast_ofNat, ← mul_pow, ENNReal.mul_inv_cancel two_ne_zero ENNReal.ofNat_ne_top, one_pow]
  calc (1 : ℝ≥0∞) = ((2 ^ 120 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120 := h
    _ ≤ (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120 := mul_le_mul' (by exact_mod_cast hR) le_rfl
    _ ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 128 + (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120 := le_add_self

/-- **A bound `≤ εsTarget q + εend` is empty at `εend = ⊤`**, and `hEnd` (the block theorems' only constraint on
`εend`) holds at `⊤` for every adversary (`prH _ ≤ ⊤`). -/
theorem gap_block_end_free {Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] (Ev : (Q → D) → Prop)
    (q : ℕ) : prH Ev ≤ ⊤ ∧ ∀ X : ℝ≥0∞, X ≤ εsTarget q + ⊤ :=
  ⟨le_top, fun X => by simp⟩

end GapAudit

#print axioms GapAudit.gap_o11_top
#print axioms GapAudit.gap_zk_passthrough
#print axioms GapAudit.gap_segComplete_refuser
#print axioms GapAudit.gap_circuitIff_free
#print axioms GapAudit.gap_units
#print axioms GapAudit.gap_epsC_lt_one
#print axioms GapAudit.gap_epsS_lt_one
#print axioms GapAudit.gap_epsZk_top
#print axioms GapAudit.gap_block_end_free
