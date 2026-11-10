/-
Gap audit (premise register, 2026-11-10), scratch file D: a vacuity probe of L34's stage contracts `RtInc` and
`RtOutc` (RunTrStages.lean), the premises `rtRunClassify` (the run's schedule at the code's verifier, the route L34
names for `Rn`) takes for stage IN-C and stage OUT-C.

`RtInc.hcnt` asks the claim counts of EVERY core whose slot phase the stage accepts to be the constants `nA`, `nH`,
`nIn`, `nOut`. Unlike `RtBlk.hcnt` (RunTrParts.lean), it has no guard on the core's slot count. A core with NO slots
passes the slot phase (`stSlotsLoop` on `[]` is `.ok`) with the empty accumulator. So:

* `gap_rtInc_counts`: any `RtInc` forces `nA = 0`, `nH = 1`, `nIn = 0`, `nOut = 0`;
* `gap_rtInc_never_accepts`: with any `RtInc`, stage IN-C's verifier NEVER accepts (it requires exactly one claim on the
  input token endpoint, `checkTokenEp`);
* `gap_rtRunClassify_never_accepts`: so the run verifier `classifyRunV … inc incG …` never accepts anything, for every
  header, oracle and receipt: an `Rn` built by `rtRunClassify` exists only for a verifier that rejects everything;
* `gap_rtOutc_counts`: any `RtOutc` forces `nA = 0`, `nH = 1`, `nIn = 0` likewise.

Never imported by the root. No sorry, axiom or native_decide.
-/
import ZK60Formal

set_option autoImplicit false

namespace GapAudit

open ZK60 ZK60.Exec ZK60.ProtocolClassify
open ZK60.Exec.StageV (IncV OutcV StageGeom StageSeg classifyRunV checkTokenEp incVerify_ok_iff)

variable {Hdr : Type} {Lq : ℕ}

/-- **`RtInc` forces stage IN-C's claim counts to zero**: the core with no slots is accepted by the slot phase with the
empty accumulator. -/
theorem gap_rtInc_counts {V : Hdr → IncV} {G : Hdr → StageGeom} {p : RtPart} (I : RtInc Lq V G p) (hd : Hdr)
    (H : HIn → Dig) (t : Tr) (core0 : ZK60.Exec.Block.Core) :
    I.nA = 0 ∧ I.nH = 1 ∧ I.nIn = 0 ∧ I.nOut = 0 := by
  obtain ⟨h1, h2, h3, h4⟩ := I.hcnt hd H { core0 with slots := [] } t [] {}
    ((V hd).slotT H { core0 with slots := [] } t) rfl
  simp only [List.length_nil, List.nil_append, List.length_singleton] at h1 h2 h3 h4
  omega

/-- **With any `RtInc`, stage IN-C never accepts**: an accepted step needs exactly one claim on the input token
endpoint (`checkTokenEp`), while `RtInc` forces that count to `0` (`gap_rtInc_counts`). -/
theorem gap_rtInc_never_accepts {V : Hdr → IncV} {G : Hdr → StageGeom} {p : RtPart} (I : RtInc Lq V G p)
    (core0 : ZK60.Exec.Block.Core) (hd : Hdr) (H : HIn → Dig) (epRoot : Dig) (seg : StageSeg) (t : Tr)
    (pending : List ZK60.Exec.Block.ZClaim) (root : Dig) (t' : Tr) :
    (V hd).verify H epRoot seg t ≠ .ok ((pending, root), t') := by
  intro hv
  obtain ⟨-, -, -, -, -, -, recs, acc, t4, t5, t6, t7, hs, -, -, -, -, -, -, hep, -, -⟩ :=
    (incVerify_ok_iff H (V hd) epRoot seg t pending root t').mp hv
  have hz : I.nIn = 0 := (gap_rtInc_counts I hd H t core0).2.2.1
  have hc := (I.hcnt hd H seg.core _ recs acc t4 hs).2.2.1
  rw [hz] at hc
  have hnil : acc.claims.inp = [] := List.eq_nil_of_length_eq_zero hc
  rw [hnil] at hep
  exact absurd hep (by simp [checkTokenEp])

/-- **So the run verifier at those stages never accepts**: for every header, oracle, statement and receipt,
`verify_classify_run_with` (as `classifyVerifyE` at `classifyRunV … inc incG …`) refuses. Every `Rn` built by
`rtRunClassify` carries an `RtInc` for exactly these `inc`, `incG`. -/
theorem gap_rtRunClassify_never_accepts (L : ℕ) (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
    (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom) {p : RtPart}
    (I : RtInc Lq inc incG p) (core0 : ZK60.Exec.Block.Core) (H : HIn → Dig) (s : ClsStmt Hdr)
    (segs : List (List UInt8)) :
    classifyVerifyE (classifyRunV L preA preB start inc incG blk outc outcG) H s segs ≠ .ok () := by
  intro hacc
  obtain ⟨-, -, -, cr₁, -, -, t₁, -, -, h1, -, -⟩ :=
    (classifyVerifyE_ok_iff (classifyRunV L preA preB start inc incG blk outc outcG) H s segs).mp hacc
  obtain ⟨seg, e, broot, pending, -, hver, -, -⟩ :=
    (ZK60.Exec.StageV.inSegExec_step_ok_iff inc incG H s _ _ _ _ cr₁ t₁).mp h1
  exact gap_rtInc_never_accepts I core0 s.hdr H s.inRoot seg _ pending broot t₁ hver

/-- **`RtOutc` forces stage OUT-C's claim counts likewise** (`nA = 0`, `nH = 1`, `nIn = 0`). -/
theorem gap_rtOutc_counts {V : Hdr → ℕ → OutcV} {G : Hdr → StageGeom} {p : RtPart} (O : RtOutc Lq V G p) (hd : Hdr)
    (v : ℕ) (H : HIn → Dig) (t : Tr) (core0 : ZK60.Exec.Block.Core) :
    O.nA = 0 ∧ O.nH = 1 ∧ O.nIn = 0 := by
  obtain ⟨h1, h2, h3⟩ := O.hcnt hd v H { core0 with slots := [] } t _ [] {} _ rfl
  simp only [List.length_nil, List.nil_append, List.length_singleton] at h1 h2 h3
  omega

/-- A core exists (the probes above hold unconditionally). -/
def gapCore0 : ZK60.Exec.Block.Core :=
  ⟨zeroDig, zeroDig, zeroDig, [], ⟨[], [], []⟩, ⟨[], [], []⟩, ⟨[], [], []⟩⟩

open scoped ENNReal in
theorem gap_epsC_lt_one' : εcTarget < 1 := by
  unfold εcTarget
  have h : (2⁻¹ : ℝ≥0∞) < 1 := ENNReal.inv_lt_one.mpr ENNReal.one_lt_two
  exact lt_of_le_of_lt (pow_le_of_le_one (by positivity) h.le (by norm_num)) h

open scoped ENNReal in
/-- **The top theorem's premises at the code's verifier, with the schedule from `rtRunClassify`, are jointly
unsatisfiable.** `ClassifyOpen` at `classifyRunV … inc incG …` gives `Complete` at `2^-40` (L18's
`classify_complete_target`, from its fields O1 to O10), so some honest receipt is accepted; an `RtInc` for the same
`inc`, `incG` (every `Rn := rtRunClassify …` carries one) makes the verifier reject everything. So, given any admissible
input: `False`. -/
theorem gap_route_inconsistent {S : ZK60.Block.BlockShape} {Salt Coins : Type} [Fintype Coins] [Nonempty Coins]
    [Inhabited Coins] {K : Type} [Field K] [DecidableEq K] [Algebra ZK60.Circuit.GF K]
    (R : ZK60.TokenRun.ClassifyRunPublic S) (L : ℕ) (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
    (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := ZK60.Circuit.GF) U)) {ι : Type} [Fintype ι]
    (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt) {εin εblk εout εep : ℕ → ℝ≥0∞}
    {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq (classifyRunV L preA preB start inc incG blk outc outcG) P Cin h64 hr hon U site kOf δOf E
      εin εblk εout εep εzk)
    {pin : RtPart} (I : RtInc Lq inc incG pin) (x : S.Tok → ℕ)
    (hx : (ZK60.TokenRun.classifyModel S R).admissible x) : False := by
  obtain ⟨hokC, hN, hroot, -⟩ := O.commit
  have hc := classify_complete_target R ⟨O.inPub, O.weights, O.outPub⟩ Lq _ P Cin h64 hr hon hokC hN hroot
    O.policy.1 O.policy.2 O.parts U hbij site kOf O.counts.1 δOf O.counts.2.1 O.counts.2.2.1 O.counts.2.2.2 O.refuse
  have h := hc () x hx
  have h0 : (1 : ℝ≥0∞) - εcTarget ≤ 0 := by
    refine h.trans (le_of_eq ?_)
    unfold prHC
    refine MeasureTheory.measure_mono_null (t := (∅ : Set ((QB Lq → Dig) × Coins))) (fun p hp => ?_)
      MeasureTheory.measure_empty
    obtain ⟨hv, -⟩ := hp
    obtain ⟨u, hu⟩ := (okB_eq_true _).mp hv
    cases u
    exact absurd hu (gap_rtRunClassify_never_accepts L preA preB start inc incG blk outc outcG I gapCore0 _ _ _)
  have h1 : (1 : ℝ≥0∞) ≤ εcTarget := tsub_eq_zero_iff_le.mp (nonpos_iff_eq_zero.mp h0)
  exact absurd h1 (not_le.mpr gap_epsC_lt_one')

end GapAudit

#print axioms GapAudit.gap_rtInc_counts
#print axioms GapAudit.gap_rtInc_never_accepts
#print axioms GapAudit.gap_rtRunClassify_never_accepts
#print axioms GapAudit.gap_rtOutc_counts
#print axioms GapAudit.gap_route_inconsistent
