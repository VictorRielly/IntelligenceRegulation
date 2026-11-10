/-
D63 lane L40 (2026-11-10), part 6: **the per-block gates' obligations AT THE APP'S REAL MODEL**: O1 (the width and
every block's own shape) and O5's block count are discharged for any run carrying the app's 26 calibrations
(`ShieldRun`, RunShapeShield.lean), so `ClassifyOpenP` at the app is built from the remaining fields alone, and every
per-block gate (`RunShapeProtocol.lean`, `RunShapeGate.lean`, among them L34's top gate `rt_productionReady_r13P`) can be
instantiated at the app's model (which L2's one-shape gates cannot: `shield_not_one_shape`).

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `shieldRun_length`: a run carrying the app's calibrations has 26 blocks;
* **`shield_classifyOpenP`**: `ClassifyOpenP` at such a run from the fields O2 (the blocks' public data), O3, O4,
  O5's verifier count `V.L = 26`, O6 to O10 and O12; O1 and O5's model count are PROVED.
-/
import ZK60Formal.RunShapeShield
import ZK60Formal.RunShapeProtocol

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify.RunShapeP

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.RunShape ZK60.RunShape.Shield
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape)

variable {Hdr Salt Coins : Type}

/-- **A run carrying the app's calibrations has 26 blocks.** -/
theorem shieldRun_length (R : ClassifyRunPublicP shieldS0) (hR : ShieldRun R) : R.blks.length = 26 := by
  have h := congrArg List.length hR
  rw [List.length_map, List.length_map] at h
  rw [h]
  exact shieldExport_l17.1

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

omit [DecidableEq K] in
/-- **The open obligations at the app's model, O1 and O5's model count PROVED**: for a run carrying the app's 26
calibrations, `ClassifyOpenP` follows from the blocks' public data (O2), the stages' (O3, O4), the verifier's block
count `V.L = 26` (O5), and O6 to O10 and O12. -/
theorem shield_classifyOpenP (R : ClassifyRunPublicP shieldS0) (hR : ShieldRun R) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (Cin : PlaneCommit (shieldS0.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) {ι : Type} [Fintype ι]
    (site : (shieldS0.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞) {εzk : ℕ → ℕ → ℝ≥0∞}
    (weights : ∀ b ∈ R.blks, b.pub.Valid) (inPub : R.inp.Valid) (outPub : R.out.Valid) (hL : V.L = 26)
    (commit : (∀ x, (∀ t, x t < gP) → Cin.ok x) ∧ Cin.N ≤ 2 ^ Cin.depth ∧ (∀ s, Cin.root s = s.inRoot) ∧
      Cin.depth ≤ 64)
    (policy : V.preA P.hdr = .ok () ∧ V.preB P.hdr = .ok ())
    (parts : List.Forall₂ (SegComplete (classifyModelP R).admissible liftH (clsStmtOfP R Lq P Cin h64 hr hon.base))
      (P.parts V.L) V.parts)
    (refuse : ∀ x, (classifyModelP R).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires U G c) →
      ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpecP R x).getD 0) x c
        = .ok r)
    (counts : (∀ x i, (site x i).k ≤ kOf i) ∧ (∀ x i, (site x i).δ ≤ δOf i) ∧ ∑ i, kOf i ≤ 2 ^ 85
      ∧ ∑ i, δOf i ≤ (2⁻¹ : ℝ≥0∞) ^ 41)
    (zk : ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr hon.base) εzk) :
    ClassifyOpenP R Lq V P Cin h64 hr hon U site kOf δOf εzk := by
  have hv := shieldRun_valid R hR inPub outPub weights
  exact
    { width := hv.d_le
      shapes := fun b hb => (hv.blks b hb).shape
      weights := weights
      inPub := inPub
      outPub := outPub
      blocks := ⟨by rw [shieldRun_length R hR]; norm_num, by rw [hL, shieldRun_length R hR]⟩
      commit := commit
      policy := policy
      parts := parts
      refuse := refuse
      counts := counts
      zk := zk }

end ZK60.ProtocolClassify.RunShapeP
