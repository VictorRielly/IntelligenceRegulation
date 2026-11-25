/-
D63 lane L69, Milestone B Part 3a (`HonestShieldZKProgHelpers.lean`):
arithmetic, audit, `hdH` / `hab` / `hosted` bridges, `X₁`-claim lookup, and unified per-segment
slot arithmetic helpers for `HonestShieldZKProgInst`.

Only standard Lean/Mathlib foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldZKTraceExtract

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Finset
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound ZK60.Hiding
open ZK60.ZKW16 ZK60.ZKLinks ZK60.ZKHonest ZK60.HonestClassify ZK60.HonestOpen
open ZK60.HonestRun ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP ZK60.TokenRun
open ZK60.Circuit (gP GF)
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifyArithP classifySpecP)
open ZK60.RunShape.Shield (ShieldLayer shieldShape ShieldRun shieldS0)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Hist Acc SlotDef SlotProof SlotRec SlotKind Segment SegGeom Tab)
open ZK60.Exec.Block.Join.R13H (progR13_shield_okP progR13_slot numSlot_fields)
open ZK60.Exec.Block.Join.R13H.Pub (pubsR13L)
open ZK60.Exec.Slot.W16R2 (Kind kindOf hostsOf nSlots)


/-! ## 1. Arithmetic, Audit, `hdH`, `hab`, `hosted`, and `X₁`-Claim-Lookup Bridges -/

section HelpersAndArith

/-- Pure `v`-only choice of an admissible reference input matching `verdict` whenever `AdmAt Rp verdict`
is nonempty, and falling back to `Classical.choice hne` when `AdmAt Rp verdict` is empty. -/
noncomputable def refInput (Rp : ClassifyRunPublicP shieldS0)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) :
    {x // (classifyModelP Rp).admissible x} :=
  open Classical in
  if h : Nonempty (AdmAt Rp verdict) then (Classical.choice h).1 else Classical.choice hne

theorem refInput_verdict_eq (Rp : ClassifyRunPublicP shieldS0)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (y : AdmAt Rp verdict) :
    (classifySpecP Rp (refInput Rp hne verdict).1).getD 0 = (classifySpecP Rp y.1.1).getD 0 := by
  classical
  have hneV : Nonempty (AdmAt Rp verdict) := ⟨y⟩
  unfold refInput
  rw [dite_eq_left hneV, (Classical.choice hneV).2, y.2]

theorem adm_tok_lt {Rp : ClassifyRunPublicP shieldS0} {x : shieldS0.Tok → ℕ}
    (hx : (classifyModelP Rp).admissible x) (t : shieldS0.Tok) : x t < Rp.inp.V := by
  obtain ⟨v, hv⟩ := hx
  change classifySpecP Rp x = some v at hv
  unfold classifySpecP inSpec at hv
  split_ifs at hv with hcond
  · exact hcond.1 t
  · simp at hv

theorem outcWitness_of_adm_v (Rp : ClassifyRunPublicP shieldS0) (hOut : Rp.out.Valid)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) :
    (outcWitness_of_adm Rp hOut x hx).v = (classifySpecP Rp x).getD 0 := by
  rw [(outcWitness_of_adm Rp hOut x hx).hv_spec]
  rfl

/-- Canonical lift of Level-1 coins `ω₁` to full `ShdCoins` (tables `TE`, `B_0..26`, `A_0..27`, `H_0..27`
depend ONLY on `.1`, never on `.2`). -/
noncomputable def cOfL1 (ω₁ : ShdL1Coins GF shdP_L1Spec) : ShdCoins :=
  (ω₁, fun s => Classical.choice (instNonemptySegL2Coins GF shdP_K (shdP_L2Spec s)))

/-- Generic `claimWeights.2` key lemma for any sum claim whose parts all have `point = []` and `logSize ≥ logN`. -/
theorem claimWeights_key_of_empty_parts (R logN : ℕ) (z : Block.ZClaim)
    (hne : z.parts ≠ []) (hpts : ∀ p ∈ z.parts, p.point = [] ∧ logN ≤ p.logSize) :
    (claimWeights (toZClaim z) R logN).2 = ⟨[], 0, 2 ^ logN⟩ := by
  cases hp : z.parts with
  | nil => exact absurd hp hne
  | cons p0 ps =>
    have h0 := hpts p0 (by rw [hp]; exact List.mem_cons_self)
    simp only [claimWeights, toZClaim, hp, List.map_cons, zpartWeights, toZPart, h0.1,
      List.isEmpty_nil, ↓reduceIte, ite_eq_left h0.2]

/-- Unified `hdH` discharge from `auditClaims ... (some (d, d+1)) ... = .ok ()` + `ClaimTrue` on `clH[g]`. -/
theorem hdH_of_audit_logupSum {logN d g : ℕ}
    (dat : Fin d → Fin (2 ^ logN) → GF) (c : Hiding.CoinsH GF (2 ^ logN) 256 (Fin d) (Fin g))
    (rows : List (List Fp)) (hrowsLen : rows.length = d + 2 + 2 * g + 2)
    (hrowsEq : ∀ (r : Fin (d + 2 + 2 * g + 2)) (k : ℕ), k < 2 ^ logN + 256 →
      ((rows.getD r.val []).getD k Fp.zero).toGF = rowAt (hRowOf dat c r) k)
    (clH : List Block.ZClaim) (hLen : clH.length = g + 1)
    (haud : auditClaims clH (2 ^ logN) (d + 2 + 2 * g + 2) (List.range' (d + 2) (2 * g))
      (some (d, d + 1)) (d + 2 + 2 * g) = .ok ())
    (hzVal : clH[g].value = Fp2.zero)
    (hzNe : clH[g].parts ≠ [])
    (hzPts : ∀ p ∈ clH[g].parts, p.point = [] ∧ logN ≤ p.logSize)
    (htrue : ClaimTrue shdP_U (2 ^ logN) logN rows (toZClaim clH[g])) :
    ∑ col : Fin (2 ^ logN), ∑ i : Fin d,
      (claimWeight logN clH[g] i.val).toK shdP_U * algebraMap GF shdP_K (dat i col) = 0 := by
  have hbij := (auditClaims_h_bijection logN d (d + 1) (d + 2) g (d + 2 + 2 * g) (d + 2 + 2 * g + 2)
    le_rfl rfl clH hLen haud).choose_spec.1
  refine hdH_of_logupSumClaim_true dat c rows hrowsLen hrowsEq clH[g] hzVal
    (claimWeights_key_of_empty_parts (d + 2 + 2 * g + 2) logN clH[g] hzNe hzPts) ?_ htrue
  intro r hr1 hr2
  by_cases hltP : r < d + 2 + 2 * g
  · have hmemSite : r ∈ List.range' (d + 2) (2 * g) :=
      List.mem_range'.mpr ⟨r - (d + 2), by omega, by omega⟩
    have hnotMem : r ∉ clH[g].parts.flatMap (partSiteRows (2 ^ logN) (List.range' (d + 2) (2 * g))) := by
      rw [hbij.2.1]; simp
    exact claimWeight_zero_of_not_mem_touched logN (List.range' (d + 2) (2 * g)) clH[g] r hmemSite hnotMem
  · exact claimWeight_zero_of_ge_prox logN (d + 2 + 2 * g) clH[g] r hbij.1 (by omega)

/-- Stage IN-C `logupSumClaim` parts have `value = 0`, nonempty parts, `point = []`, and `logSize ≥ 12`. -/
theorem shdP_inc_logupSumClaim_shape (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) :
    let z := (shdVi tag Rp embDigest bInRow).lay.logupSumClaim
    z.value = Fp2.zero ∧ z.parts ≠ [] ∧ ∀ p ∈ z.parts, p.point = [] ∧ 12 ≤ p.logSize := by
  intro z
  have hlogs := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
  have hL : (shdVi tag Rp embDigest bInRow).lay = incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14 := rfl
  refine ⟨rfl, ?_, ?_⟩
  · intro hnil
    have hmem : (⟨((shdVi tag Rp embDigest bInRow).lay.hOff 0).1,
        (shdVi tag Rp embDigest bInRow).lay.hLog.getD 0 0,
        StageCheck.kI ((shdVi tag Rp embDigest bInRow).lay.hSign.getD 0 0), []⟩ : Block.ZPart) ∈ z.parts := by
      unfold z Lay.logupSumClaim
      refine List.mem_flatMap.mpr ⟨0, ?_, List.mem_cons_self⟩
      rw [hL]
      simp [incLay, hlogs.1, hlogs.2.1]
    rw [hnil] at hmem; cases hmem
  · intro p hp
    unfold z Lay.logupSumClaim at hp
    obtain ⟨i, hi, hpMem⟩ := List.mem_flatMap.mp hp
    rw [hL] at hi hpMem
    have hiLt : i < 3 := by
      simp only [incLay, List.mem_range, List.length_cons, List.length_nil] at hi
      exact hi
    have hlogGe : 12 ≤ (incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).hLog.getD i 0 := by
      have hlt : (shdP_incPub Rp embDigest (embFoldL Rp.inp)).lt = 12 := rfl
      have hhLog : (incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).hLog = [12, 17, 12] := by
        simp [incLay, hlogs.1, hlogs.2.1, hlt]
      rw [hhLog]
      interval_cases i <;> decide
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hpMem
    rcases hpMem with rfl | rfl <;> exact ⟨rfl, hlogGe⟩

theorem shdP_Pk0_eq_blkParams (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : Fin 26) :
    ∃ Pb : BlockPublic (shieldShape (shdP_layer k.val k.isLt)),
      shdP_Pk0 tag ioIn ioOut checkOpening Rp k.val =
        shdP_blkParams tag ioIn ioOut checkOpening (shdP_layer k.val k.isLt) Pb := by
  unfold shdP_Pk0
  have hmin : min k.val 25 = k.val := by omega
  have hL : RunShape.Shield.shieldExport[min k.val 25]? = some (shdP_layer k.val k.isLt) := by
    rw [hmin, List.getElem?_eq_getElem (by rw [RunShape.Shield.shieldExport_l17.1]; exact k.isLt)]; rfl
  have hB : Rp.blks[min k.val 25]? = some (Rp.blks[k.val]'(by rw [shdP_blks_length hR]; exact k.isLt)) := by
    rw [hmin, List.getElem?_eq_getElem (by rw [shdP_blks_length hR]; exact k.isLt)]
  rw [hL, hB]
  dsimp only
  split_ifs <;> exact ⟨_, rfl⟩

/-- R13 block `logupSumClaim` parts have `value = 0`, nonempty parts, `point = []`, and `logSize ≥ 14`. -/
theorem shdP_blk_logupSumClaim_shape (tag : MTag) (ioIn ioOut : ℕ)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : Fin 26) :
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    P.logupSumClaim.value = Fp2.zero ∧ P.logupSumClaim.parts ≠ []
      ∧ ∀ p ∈ P.logupSumClaim.parts, p.point = [] ∧ 14 ≤ p.logSize := by
  intro P
  have hPeq : P.logupSumClaim = Exec.Block.Join.R13H.Look.logupSumR13
      (Exec.Block.DefR13.cfgShieldR13 (shdP_layer k.val k.isLt)) := by
    obtain ⟨Pb, hPb⟩ := shdP_Pk0_eq_blkParams tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR k
    change (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).logupSumClaim = _
    rw [hPb]; rfl
  rw [hPeq]
  have hind : Exec.Block.Join.R13H.Look.logupSumR13 (Exec.Block.DefR13.cfgShieldR13 (shdP_layer k.val k.isLt))
      = Exec.Block.Join.R13H.Look.logupSumR13 (Exec.Block.DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) := by
    have hnh : ∀ d, Exec.Block.DefR13.nHelp (Exec.Block.DefR13.cfgShieldR13 (shdP_layer k.val k.isLt)) d
        = Exec.Block.DefR13.nHelp (Exec.Block.DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) d := fun d => by
      cases d <;> simp [Exec.Block.DefR13.nHelp, Exec.Block.DefR13.lookups, Exec.Block.DefR13.ids,
        Exec.Block.DefR13.idsR13, Exec.Block.DefR13.lsOf, Exec.Block.DefR13.cfgShieldR13,
        Exec.Block.DefR13.precShieldR13, Exec.Block.DefR13.bytes]
    have hDoms : Exec.Block.DefR13.hDoms (Exec.Block.DefR13.cfgShieldR13 (shdP_layer k.val k.isLt))
        = Exec.Block.DefR13.hDoms (Exec.Block.DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) := by
      unfold Exec.Block.DefR13.hDoms; simp only [hnh]
    have hfh : ∀ j, Exec.Block.DefR13.fh (Exec.Block.DefR13.cfgShieldR13 (shdP_layer k.val k.isLt)) j
        = Exec.Block.DefR13.fh (Exec.Block.DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) j := fun j => by
      unfold Exec.Block.DefR13.fh Exec.Block.DefR13.hIdsN; simp only [hnh]
    have hOff : ∀ hp, Exec.Block.DefR13.hOff (Exec.Block.DefR13.cfgShieldR13 (shdP_layer k.val k.isLt)) hp
        = Exec.Block.DefR13.hOff (Exec.Block.DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) hp := fun hp => by
      unfold Exec.Block.DefR13.hOff; simp only [hDoms]; rfl
    unfold Exec.Block.Join.R13H.Look.logupSumR13
    simp only [hDoms, hfh, hOff]; rfl
  rw [hind]
  refine ⟨rfl, by decide +kernel, ?_⟩
  have hall : (Exec.Block.Join.R13H.Look.logupSumR13
      (Exec.Block.DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩)).parts.all
        (fun p => p.point.isEmpty && decide (14 ≤ p.logSize)) = true := by decide +kernel
  intro p hp
  have hb := List.all_eq_true.mp hall p hp
  simp only [Bool.and_eq_true, List.isEmpty_iff, decide_eq_true_eq] at hb
  exact hb

/-- Stage OUT-C `logupSumClaim` parts have `value = 0`, nonempty parts, `point = []`, and `logSize ≥ 12`. -/
theorem shdP_outc_logupSumClaim_shape (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow : ℕ) (v : ℕ) :
    let z := (shdVo tag Rp wDigest bOutRow v).lay.logupSumClaim
    z.value = Fp2.zero ∧ z.parts ≠ [] ∧ ∀ p ∈ z.parts, p.point = [] ∧ 12 ≤ p.logSize := by
  intro z
  have hlogs := shdP_outcPub_logs Rp wDigest
  have hL : (shdVo tag Rp wDigest bOutRow v).lay = outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14 := rfl
  have hhLog : (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hLog = List.replicate 9 12 := by
    have h1 : (rcVerdict (shdP_outcPub Rp wDigest) v).llo = 12 := hlogs.1
    have h2 : (rcVerdict (shdP_outcPub Rp wDigest) v).ldo = 12 := hlogs.2.1
    have h3 : (rcVerdict (shdP_outcPub Rp wDigest) v).ltab = 12 := hlogs.2.2.1
    have h4 : (rcVerdict (shdP_outcPub Rp wDigest) v).lt = 12 := rfl
    simp [outcLay, h1, h2, h3, h4]
  refine ⟨rfl, ?_, ?_⟩
  · intro hnil
    have hmem : (⟨((shdVo tag Rp wDigest bOutRow v).lay.hOff 0).1,
        (shdVo tag Rp wDigest bOutRow v).lay.hLog.getD 0 0,
        StageCheck.kI ((shdVo tag Rp wDigest bOutRow v).lay.hSign.getD 0 0), []⟩ : Block.ZPart) ∈ z.parts := by
      unfold z Lay.logupSumClaim
      refine List.mem_flatMap.mpr ⟨0, ?_, List.mem_cons_self⟩
      rw [hL, hhLog]; simp
    rw [hnil] at hmem; cases hmem
  · intro p hp
    unfold z Lay.logupSumClaim at hp
    obtain ⟨i, hi, hpMem⟩ := List.mem_flatMap.mp hp
    rw [hL, hhLog] at hi hpMem
    have hiLt : i < 9 := by simpa using hi
    have hlog12 : (List.replicate 9 12).getD i 0 = 12 := by
      rw [List.getD_eq_getElem?_getD, List.getElem?_replicate, ite_eq_left hiLt]; rfl
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hpMem
    rcases hpMem with rfl | rfl
    · exact ⟨rfl, by dsimp only; rw [hlog12]⟩
    · exact ⟨rfl, by dsimp only; rw [hlog12]⟩

/-- Stage IN-C `OpenGeom` numbers (`A` and `H`). -/
theorem shdP_incOpenGeom_eq (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) :
    let V := shdVi tag Rp embDigest bInRow
    V.lay.aRows = 41 ∧ V.lay.aSiteRows = List.range' 33 6 ∧ V.lay.aProx = 39
      ∧ V.lay.hRows = 76 ∧ V.lay.hSiteRows = List.range' 68 6 ∧ V.lay.hURows = (66, 67) ∧ V.lay.hProx = 74 := by
  intro V
  obtain ⟨haR, hhR, _, _⟩ := shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)
  obtain ⟨hti, hvoc, hep, _, _⟩ := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
  have hlt : (shdP_incPub Rp embDigest (embFoldL Rp.inp)).lt = 12 := rfl
  have hV_aR : V.lay.aRows = 41 := haR
  have hV_hR : V.lay.hRows = 76 := hhR
  have haM : V.lay.aMaskBase = 33 := by
    unfold V shdVi shdP_incV; change (incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).aMaskBase = 33
    simp only [incLay, incSched, Lay.aMaskBase, Lay.aDataRows, Lay.aRowsL, rowsOf, hti, hvoc, hlt]; norm_num
  have hhM : V.lay.hMaskBase = 68 := by
    unfold V shdVi shdP_incV; change (incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).hMaskBase = 68
    simp only [incLay, incSched, Lay.hMaskBase, Lay.hDataRows, Lay.hRowsL, rowsOf, hti, hvoc, hlt]; norm_num
  have haP : V.lay.aProx = 39 := by change V.lay.aRows - 2 = 39; omega
  have hhP : V.lay.hProx = 74 := by change V.lay.hRows - 2 = 74; omega
  have hhU : V.lay.hURows = (66, 67) := by
    unfold V shdVi shdP_incV
    change (incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).hURows = (66, 67)
    unfold Lay.hURows Lay.hOff Lay.hRowsL
    simp only [incLay, Lay.n, rowsOf, hti, hvoc, hlt, incH_U]; norm_num
  exact ⟨hV_aR, by unfold Lay.aSiteRows; rw [haM, haP], haP,
    hV_hR, by unfold Lay.hSiteRows; rw [hhM, hhP], hhU, hhP⟩

/-- Stage OUT-C `OpenGeom` numbers (`A` and `H`). -/
theorem shdP_outcOpenGeom_eq (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow : ℕ) (v : ℕ) :
    let V := shdVo tag Rp wDigest bOutRow v
    V.lay.aRows = 76 ∧ V.lay.aSiteRows = List.range' 16 58 ∧ V.lay.aProx = 74
      ∧ V.lay.hRows = 38 ∧ V.lay.hSiteRows = List.range' 18 18 ∧ V.lay.hURows = (16, 17) ∧ V.lay.hProx = 36 := by
  intro V
  obtain ⟨haR, hhR, _, _⟩ := shdP_outcLay_nums Rp wDigest
  obtain ⟨hllo, hldo, hltab, _⟩ := shdP_outcPub_logs Rp wDigest
  have hlt : (shdP_outcPub Rp wDigest).lt = 12 := rfl
  have hV_aR : V.lay.aRows = 76 := by
    change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).aRows = 76; rw [rc_outcLay_verdict]; exact haR
  have hV_hR : V.lay.hRows = 38 := by
    change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hRows = 38; rw [rc_outcLay_verdict]; exact hhR
  have haM : V.lay.aMaskBase = 16 := by
    change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).aMaskBase = 16; rw [rc_outcLay_verdict]
    simp only [outcLay, outcSched, OutcPub.toLog, Lay.aMaskBase, Lay.aDataRows, Lay.aRowsL, rowsOf,
      hllo, hldo, hltab, hlt, List.replicate]; norm_num
  have hhM : V.lay.hMaskBase = 18 := by
    change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hMaskBase = 18; rw [rc_outcLay_verdict]
    simp only [outcLay, outcSched, OutcPub.toLog, Lay.hMaskBase, Lay.hDataRows, Lay.hRowsL, rowsOf,
      hllo, hldo, hltab, hlt, List.replicate]; norm_num
  have haP : V.lay.aProx = 74 := by change V.lay.aRows - 2 = 74; omega
  have hhP : V.lay.hProx = 36 := by change V.lay.hRows - 2 = 36; omega
  have hhU : V.lay.hURows = (16, 17) := by
    change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hURows = (16, 17)
    rw [rc_outcLay_verdict]
    unfold Lay.hURows Lay.hOff Lay.hRowsL
    simp only [outcLay, Lay.n, rowsOf, hllo, hldo, hltab, hlt, ocH_U, List.replicate]; norm_num
  exact ⟨hV_aR, by unfold Lay.aSiteRows; rw [haM, haP], haP,
    hV_hR, by unfold Lay.hSiteRows; rw [hhM, hhP], hhU, hhP⟩

/-- **`TE` site-pair linear independence (`hab`)**: from `incDefIO`, the single `TE` claim has parts
`[⟨0, 8, cd, rho⟩, ⟨256, 8, cm * 1, rho⟩, ⟨512, 8, cm * fp2U, rho⟩]`; when `tokenEpHdrOk [c0] 1 256 = true`,
`cm ≠ 0`, so `(claimWeight 8 c0 1, claimWeight 8 c0 2) = (cm, cm * shdP_U)` is `GF`-linearly independent! -/
theorem inc_te_hab (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (ch dr rho es : List Fp2) (df0 : SlotDef) (c0 : Block.ZClaim)
    (hdef : incDefIO (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow) dr = .ok df0)
    (hparts : c0.parts =
      (Exec.Block.buildClaim (atLog ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub ch))
          (incElog (shdVi tag Rp embDigest bInRow).pub 14 0))
        ⟨.inp, [(0, Fp2.one)], clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords,
          Exec.StageV.rhoC 0 (clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords), 1, 0⟩
        (Exec.Block.claimPoint ⟨.inp, [(0, Fp2.one)], clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords,
          Exec.StageV.rhoC 0 (clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords), 1, 0⟩ rho)
        (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es 0) Fp2.zero).parts)
    (hhdr : tokenEpHdrOk [c0] 1 256 = true) :
    LinearIndependent GF ![(claimWeight 8 c0 1).toK shdP_U, (claimWeight 8 c0 2).toK shdP_U] := by
  have hep : (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords = 256 :=
    (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.2.1
  have hlw : clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords = 8 := by rw [hep]; exact shdP_clog2_256
  have hrowIn : Exec.Block.rowLog (atLog ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub ch))
      (incElog (shdVi tag Rp embDigest bInRow).pub 14 0)) .inp = 8 := by
    show (shdVi tag Rp embDigest bInRow).pub.epLogN = 8; rfl
  set cm := Exec.Block.maskCoef es 0
  set cd := Exec.Block.oneMinusProd es
  set pt := Exec.Block.claimPoint ⟨.inp, [(0, Fp2.one)], clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords,
    Exec.StageV.rhoC 0 (clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords), 1, 0⟩ rho
  have hpEq : c0.parts =
      [⟨0, 8, Fp2.one.mul cd, pt⟩,
       ⟨256, 8, cm.mul Fp2.one, pt.drop 0⟩,
       ⟨512, 8, cm.mul Exec.Block.fp2U, pt.drop 0⟩] := by
    rw [hparts]; unfold Exec.Block.buildClaim; simp only [hrowIn, hlw]; rfl
  have hcmNz : (cm.mul Fp2.one).isZero = false := by
    unfold tokenEpHdrOk at hhdr
    dsimp only at hhdr
    rw [hpEq] at hhdr
    dsimp only at hhdr
    have hd := (of_decide_eq_true hhdr).2.2.2
    simp only [List.all_cons, Bool.and_eq_true, Bool.not_eq_true'] at hd
    exact hd.2.1
  have hcmCan : (cm.mul Fp2.one).Canon := Fp2.canon_mul _ _
  have hcmKNe : cm.toK shdP_U ≠ 0 := by
    intro h0
    have hmul0 : (cm.mul Fp2.one).toK shdP_U = 0 := by
      rw [Fp2.toK_mul shdP_U shdP_hU, h0, zero_mul]
    have hfp0 : cm.mul Fp2.one = Fp2.zero :=
      Fp2.toK_injective shdP_U shdP_hU hcmCan Fp2.canon_zero (hmul0.trans (Fp2.toK_zero shdP_U).symm)
    rw [hfp0] at hcmNz; cases hcmNz
  have hzHit : ∀ (off r : ℕ) (coef : Fp2) (pts : List Fp2),
      off / 2 ^ 8 = r → coef.Canon →
      (zpartRowWeight ⟨off, 8, coef, pts⟩ 8 r).Canon
        ∧ (zpartRowWeight ⟨off, 8, coef, pts⟩ 8 r).toK shdP_U = coef.toK shdP_U := by
    intro off r coef pts hr hcan
    unfold zpartRowWeight
    dsimp only
    have h1 : 2 ^ (8 - 8) = 1 := rfl
    rw [hr, ite_eq_right (by omega : ¬ 8 < 8), ite_eq_right (by rw [h1]; omega : ¬ (r < r ∨ r + 2 ^ (8 - 8) ≤ r))]
    have heq0 : (eqTableMsb (pts.take (8 - 8))).getD (r - r) Fp2.zero = Fp2.one := by
      rw [Nat.sub_self, Nat.sub_self, List.take_zero]; rfl
    rw [heq0]
    cases he : pts.isEmpty
    · rw [ite_eq_right Bool.false_ne_true]
      exact ⟨Fp2.canon_mul _ _, by rw [Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_one, mul_one]⟩
    · rw [ite_eq_left rfl]; exact ⟨hcan, rfl⟩
  have hzMiss : ∀ (off r : ℕ) (coef : Fp2) (pts : List Fp2),
      off / 2 ^ 8 ≠ r → zpartRowWeight ⟨off, 8, coef, pts⟩ 8 r = Fp2.zero := by
    intro off r coef pts hne
    unfold zpartRowWeight
    dsimp only
    have h1 : 2 ^ (8 - 8) = 1 := rfl
    rw [ite_eq_right (by omega : ¬ 8 < 8),
        ite_eq_left (by rw [h1]; omega : r < off / 2 ^ 8 ∨ off / 2 ^ 8 + 2 ^ (8 - 8) ≤ r)]
  have hw1 : (claimWeight 8 c0 1).toK shdP_U = cm.toK shdP_U := by
    unfold claimWeight
    rw [hpEq]
    simp only [List.foldl_cons, List.foldl_nil]
    rw [hzMiss 0 1 _ _ (by decide), hzMiss 512 1 _ _ (by decide)]
    have ⟨hcan1, hval1⟩ := hzHit 256 1 (cm.mul Fp2.one) (pt.drop 0) (by decide) hcmCan
    rw [Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) Fp2.canon_zero,
        Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) hcan1,
        Fp2.toK_add shdP_U _ _ Fp2.canon_zero Fp2.canon_zero,
        Fp2.toK_zero shdP_U, hval1, Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_one]
    ring
  have hw2 : (claimWeight 8 c0 2).toK shdP_U = cm.toK shdP_U * shdP_U := by
    unfold claimWeight
    rw [hpEq]
    simp only [List.foldl_cons, List.foldl_nil]
    rw [hzMiss 0 2 _ _ (by decide), hzMiss 256 2 _ _ (by decide)]
    have ⟨hcan2, hval2⟩ := hzHit 512 2 (cm.mul Exec.Block.fp2U) (pt.drop 0) (by decide) (Fp2.canon_mul _ _)
    rw [Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) hcan2,
        Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) Fp2.canon_zero,
        Fp2.toK_add shdP_U _ _ Fp2.canon_zero Fp2.canon_zero,
        Fp2.toK_zero shdP_U, hval2, Fp2.toK_mul shdP_U shdP_hU, Block.toK_fp2U shdP_U]
    ring
  rw [hw1, hw2]
  exact shdP_sitePair_linInd hcmKNe

/-- Align any R13 block slot's `df.hosted` list (whose `.map Prod.fst = hostsOf t.val`) with `w16Hosts`. -/
theorem hosted_map_eq_w16Hosts (l : List (ℕ × Fp2)) (t : Fin nSlots) (hfst : l.map Prod.fst = hostsOf t.val) :
    let ν : Fin nSlots → ℕ → shdP_K := fun _ u => ((l.find? (fun p => p.1 == u)).map (fun p => p.2.toK shdP_U)).getD 0
    l.map (fun hk => (hk.1, hk.2.toK shdP_U)) = (w16Hosts ν t).map (fun p => (p.1.val, p.2)) := by
  intro ν
  have h2 : ∀ {a b : ℕ}, l.map Prod.fst = [a, b] → a ≠ b → a < nSlots → b < nSlots →
      l.map (fun hk => (hk.1, hk.2.toK shdP_U)) = [(a, ν t a), (b, ν t b)] := by
    intro a b hm hab ha hb
    cases l with
    | nil => simp at hm
    | cons p0 tl =>
      cases tl with
      | nil => simp at hm
      | cons p1 tl2 =>
        cases tl2 with
        | cons _ _ => simp at hm
        | nil =>
          simp only [List.map_cons, List.map_nil, List.cons.injEq] at hm ⊢
          obtain ⟨rfl, rfl, _⟩ := hm
          refine ⟨by simp [ν], by simp [ν, show (p0.1 == p1.1) = false from beq_false_of_ne hab], trivial⟩
  fin_cases t <;> (
    unfold hostsOf at hfst
    unfold w16Hosts hostsOf
    dsimp only at hfst ⊢)
  all_goals first
    | (cases l with | nil => rfl | cons _ _ => simp at hfst)
    | ((try dsimp only [List.filterMap, List.map]); exact h2 hfst (by dsimp; decide) (by dsimp; decide) (by dsimp; decide))

/-- For any accepted R13 block `df`, `df.hosted.map Prod.fst = hostsOf s`. -/
theorem shdP_blk_hosted_fst (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (s : ℕ) (hs : s < 23) (hist : Hist) (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define s hist dr = .ok df) :
    df.hosted.map Prod.fst = hostsOf s := by
  obtain ⟨_, hdfEq⟩ := Exec.Block.defineS_ok hdf
  obtain ⟨ak, hk', hslot⟩ := progR13_slot (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut s hs
  have h1 : df.hosted.map Prod.fst = (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).hosted.map Prod.fst := by
    have hhosted : df.hosted =
        ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s Exec.Block.SlotS.empty).hosted.map
          fun h => (h.1, h.2.eval hist s dr) := congrArg SlotDef.hosted hdfEq
    rw [hhosted, hslot, (numSlot_fields _ _ _ _ _ _ _).2.1, List.map_map]
    rfl
  rw [h1]
  interval_cases s <;> rfl

/-- Pure `parts`-lookup claim evaluation from a `Fin clRef.length → Hiding.Row` family. -/
noncomputable def lookupClaimVal (R lc : ℕ) (clRef : List Block.ZClaim)
    (vecOf : Fin clRef.length → Hiding.Row shdP_K (2 ^ lc) 256) (ps : List Block.ZPart) : shdP_K :=
  open Classical in
  if h : ∃ i : Fin clRef.length, clRef[i.val].parts = ps then
    let i := Classical.choose h
    claimValFromVec R lc clRef[i.val] (vecOf i)
  else 0

theorem lookupClaimVal_eq_claimSem (R lc : ℕ) (rows : List (List Fp)) (hR : rows.length = R)
    (cl clRef : List Block.ZClaim) (hparts : cl.map Block.ZClaim.parts = clRef.map Block.ZClaim.parts)
    (vecOf : Fin clRef.length → Hiding.Row shdP_K (2 ^ lc) 256)
    (hvec : ∀ (i : Fin clRef.length) (t : Fin (2 ^ lc)),
      (combAt (claimWeights (toZClaim clRef[i.val]) R lc).1 rows t.val).toK shdP_U = vecOf i (Sum.inl t))
    (z : Block.ZClaim) (hmem : ∃ z' ∈ cl, z'.parts = z.parts) :
    Link.claimSem shdP_U R lc 0 (tabMat R lc rows) z = lookupClaimVal R lc clRef vecOf z.parts := by
  classical
  obtain ⟨z', hz'Mem, hz'Parts⟩ := hmem
  have hpMem : z.parts ∈ clRef.map Block.ZClaim.parts := by
    rw [← hparts]; exact List.mem_map.mpr ⟨z', hz'Mem, hz'Parts⟩
  obtain ⟨zRef, hzRefMem, hzRefParts⟩ := List.mem_map.mp hpMem
  obtain ⟨idx, hidx, rfl⟩ := List.getElem_of_mem hzRefMem
  have hex : ∃ i : Fin clRef.length, clRef[i.val].parts = z.parts := ⟨⟨idx, hidx⟩, hzRefParts⟩
  unfold lookupClaimVal
  rw [dite_eq_left hex]
  exact claimSem_of_vec rows hR z clRef[(Classical.choose hex).val]
    (Classical.choose_spec hex).symm (vecOf (Classical.choose hex)) (hvec (Classical.choose hex))

/-- Pure `X₁`-view terminal evaluation of `slotPolyK` at canonical `rhoFull`. -/
noncomputable def slotPolyFromView (P : BlockParams) (elog : ℕ → ℕ)
    (csView : Cm → List Block.ZPart → shdP_K) (s : ℕ) (df : SlotDef) (rhoFull : List Fp2) : shdP_K :=
  let Ps := atLog P (elog s)
  let n := (Exec.Block.slotShape P s).1
  let rho := rhoFull.take n
  let es := rhoFull.drop n
  match Exec.Block.tabVals (Exec.Block.oneMinusProd es) rho
      (stgPrivValsFromView Ps csView rho es df.tabs) df.tabs 0 with
  | .ok vals => (df.poly vals).toK shdP_U
  | .error _ => 0

theorem slotPolyK_at_vecK_eq_fromView (P : BlockParams) (elog : ℕ → ℕ)
    (cs : Cm → Block.ZClaim → shdP_K) (csView : Cm → List Block.ZPart → shdP_K)
    (s : ℕ) (df : SlotDef) (rhoFull : List Fp2)
    (hlen : rhoFull.length = slotN P s) (hcan : ∀ a ∈ rhoFull, a.Canon)
    (hcs : ∀ p, Tab.priv p ∈ df.tabs →
      let n := (Exec.Block.slotShape P s).1
      let rho := rhoFull.take n
      let es := rhoFull.drop n
      let z := Exec.Block.buildClaim (atLog P (elog s)) p (Exec.Block.claimPoint p rho)
        (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
      cs p.cm z = csView p.cm z.parts) :
    slotPolyK P elog cs s df (vecK shdP_U (slotN P s) rhoFull)
      = slotPolyFromView P elog csView s df rhoFull := by
  unfold slotPolyK slotPolyFromView
  have hw : stgWords shdP_U shdP_hbij (vecK shdP_U (slotN P s) rhoFull) = rhoFull :=
    stgWords_toK shdP_U shdP_hbij shdP_hU rhoFull hcan (slotN P s) hlen
  dsimp only
  rw [hw, stgPrivVals_eq_fromView (atLog P (elog s)) cs csView _ _ df.tabs hcs]
  rfl

/-- Pure `X₁`-view terminal evaluation of `blkSlotPolyK` at canonical `rhoFull`. -/
noncomputable def blkSlotPolyFromView (P : BlockParams)
    (csView : Cm → List Block.ZPart → shdP_K) (s : ℕ) (df : SlotDef) (rhoFull : List Fp2) : shdP_K :=
  let n := (Exec.Block.slotShape P s).1
  let rho := rhoFull.take n
  let es := rhoFull.drop n
  match Exec.Block.tabVals (Exec.Block.oneMinusProd es) rho
      (stgPrivValsFromView P csView rho es df.tabs) df.tabs 0 with
  | .ok vals => (df.poly vals).toK shdP_U
  | .error _ => 0

theorem blkSlotPolyK_at_vecK_eq_fromView (P : BlockParams)
    (cs : Cm → Block.ZClaim → shdP_K) (csView : Cm → List Block.ZPart → shdP_K)
    (s : ℕ) (df : SlotDef) (rhoFull : List Fp2)
    (hlen : rhoFull.length = slotN P s) (hcan : ∀ a ∈ rhoFull, a.Canon)
    (hcs : ∀ p, Tab.priv p ∈ df.tabs →
      let n := (Exec.Block.slotShape P s).1
      let rho := rhoFull.take n
      let es := rhoFull.drop n
      let z := Exec.Block.buildClaim P p (Exec.Block.claimPoint p rho)
        (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
      cs p.cm z = csView p.cm z.parts) :
    blkSlotPolyK P cs s df (vecK shdP_U (slotN P s) rhoFull)
      = blkSlotPolyFromView P csView s df rhoFull := by
  unfold blkSlotPolyK blkSlotPolyFromView
  have hw : stgWords shdP_U shdP_hbij (vecK shdP_U (slotN P s) rhoFull) = rhoFull :=
    stgWords_toK shdP_U shdP_hbij shdP_hU rhoFull hcan (slotN P s) hlen
  dsimp only
  rw [hw, stgPrivVals_eq_fromView P cs csView _ _ df.tabs hcs]
  rfl

/-- Slot shape alignment between `shdVi.bp`, `shdP_Pk0`, `shdVo.bp` and `shdP_L2Spec`. -/
theorem inc_slotShape_eq_L2 (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (ch : List Fp2) (t : Fin 4) :
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    (Exec.Block.slotShape P t.val).1 + (Exec.Block.slotShape P t.val).2.1 = (shdP_L2Spec 0).n t + 1
      ∧ (Exec.Block.slotShape P t.val).2.2 = (shdP_L2Spec 0).d t
      ∧ P.kind t.val = SlotKind.standalone := by
  intro V P
  obtain ⟨hti, hvoc, hep, _, _⟩ := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
  have hlt : (shdP_incPub Rp embDigest (embFoldL Rp.inp)).lt = 12 := rfl
  have hepc : clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords = 8 := by rw [hep, shdP_clog2_256]
  have hsl : P.geom.slots = shdP_incSlots := by
    show (incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).geomSlots = shdP_incSlots
    simp [incLay, Lay.geomSlots, incSched, shdP_incSlots, hti, hvoc, hlt, hepc]
  have hk : P.kind t.val = SlotKind.standalone := by
    show ((incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).spec t.val).kind = SlotKind.standalone
    fin_cases t <;> rfl
  rw [hk]
  fin_cases t <;> simp [Exec.Block.slotShape, hsl, shdP_L2Spec, shdP_segSlotShape, shdP_incSlots]

theorem blk_slotShape_eq_L2 (tag : MTag) (ioIn ioOut : ℕ)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : Fin 26) (t : Fin 23) :
    let s : Fin 28 := ⟨k.val + 1, by omega⟩
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    (Exec.Block.slotShape P t.val).1 + (Exec.Block.slotShape P t.val).2.1
        = (shdP_L2Spec s).n ⟨t.val, by dsimp [shdSegNS, s, nSlots]; split_ifs <;> omega⟩ + 1
      ∧ (Exec.Block.slotShape P t.val).2.2
        = (shdP_L2Spec s).d ⟨t.val, by dsimp [shdSegNS, s, nSlots]; split_ifs <;> omega⟩
      ∧ P.kind t.val = match kindOf t.val with
          | .standalone => SlotKind.standalone | .priv => SlotKind.priv | .host => SlotKind.host := by
  intro s P
  obtain ⟨Pb, hPb⟩ := shdP_Pk0_eq_blkParams tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR k
  have hPgeom : P.geom.slots = Exec.Block.R13.shieldSlots := by
    change (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).geom.slots = _; rw [hPb]; rfl
  have hPkind : P.kind t.val = shdP_slotKind t.val := by
    change (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).kind t.val = _; rw [hPb]; rfl
  have hs0 : s.val ≠ 0 := by dsimp [s]; omega
  have hs27 : s.val ≠ 27 := by dsimp [s]; omega
  have hL2 : shdP_segSlotShape s ⟨t.val, by dsimp [shdSegNS, s, nSlots]; split_ifs <;> omega⟩
      = Exec.Block.R13.shieldSlots.getD t.val (0, 0, 0) := by
    unfold shdP_segSlotShape; rw [ite_eq_right hs0, ite_eq_right hs27]
  rw [hPkind]
  fin_cases t <;> simp [Exec.Block.slotShape, hPgeom, shdP_L2Spec, hL2, Exec.Block.R13.shieldSlots, shdP_slotKind, kindOf]

theorem outc_slotShape_eq_L2 (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow : ℕ) (v : ℕ) (t : Fin 8) :
    let P := (shdVo tag Rp wDigest bOutRow v).bp
    (Exec.Block.slotShape P t.val).1 + (Exec.Block.slotShape P t.val).2.1 = (shdP_L2Spec ⟨27, by decide⟩).n t + 1
      ∧ (Exec.Block.slotShape P t.val).2.2 = (shdP_L2Spec ⟨27, by decide⟩).d t
      ∧ P.kind t.val = match outcKind t with
          | .standalone => SlotKind.standalone | .priv => SlotKind.priv | .host => SlotKind.host := by
  dsimp only
  have hsh := shdP_outc_slotShape tag Rp wDigest bOutRow v t.val
  have hk : (shdVo tag Rp wDigest bOutRow v).bp.kind t.val =
      ((outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).spec t.val).kind := rfl
  rw [hk]
  fin_cases t <;> (simp [hsh, shdP_L2Spec, shdP_segSlotShape, Exec.StageFS.outcSlotsR1, outcLay, Lay.spec, outcSched, outcKind]; try rfl)

/-- Unified Stage IN-C slot arithmetic (`IndDegLE` + `cubeSum = 0`) across `t : Fin 4`. -/
theorem incSlot_arith {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (hinPub : Rp.inp.Valid) (hV131072 : Rp.inp.V = 131072) (embDigest : Dig) (bInRow : ℕ)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (epR : EpxSalt 6) (rnd : IncRand)
    (ch : List Fp2) (hchLen : ch.length = 15) (hchCan : ∀ a ∈ ch, a.Canon)
    (hbad : incAlphaBad (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch) = false)
    (t : Fin 4) (hist : Hist) (dr : List Fp2) (hdrCan : ∀ a ∈ dr, a.Canon)
    (hdrLen : dr.length = ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub ch)).draws t.val)
    (df : SlotDef)
    (hdef : ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub ch)).define t.val hist dr = .ok df) :
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    let elog := incElog V.pub 14
    let cs := incCs (shdP_incTA x rnd) (shdP_incTH Rp embDigest x rnd ch)
      (shdP_epTable (Hdr := Hdr) tag x epR) (shdP_incTB Rp x rnd)
    IndDegLE ((shdP_L2Spec 0).d t) (slotPolyK P elog cs t.val df)
      ∧ cubeSum (slotPolyK P elog cs t.val df) = 0 := by
  dsimp only
  obtain ⟨hti, hvoc, _, _, _⟩ := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
  fin_cases t
  · have h := inc_slot0_arith (Hdr := Hdr) tag Rp embDigest bInRow x epR rnd ch dr hdrCan df hdef
    exact ⟨h.1, h.2.1⟩
  · have hlen17 : dr.length = 17 := by
      rw [hdrLen]; show incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 1 = 17
      simp [incDraws, hti]
    have h := inc_slot1_arith (Hdr := Hdr) tag Rp hinPub hV131072 embDigest bInRow x hx epR rnd ch hchLen hchCan hbad dr hlen17 hdrCan df hdef
    exact ⟨h.1, h.2.1⟩
  · have hlen20 : dr.length = 20 := by
      rw [hdrLen]; show incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 2 = 20
      simp [incDraws, hvoc]
    have h := inc_slot2_arith (Hdr := Hdr) tag Rp embDigest bInRow x epR rnd ch hchCan hbad dr hlen20 hdrCan df hdef
    exact ⟨h.1, h.2.1⟩
  · have h := inc_slot3_arith (Hdr := Hdr) tag Rp embDigest bInRow x epR rnd ch df hdef
    exact ⟨h.1, h.2.1⟩

/-- Unified Stage OUT-C slot arithmetic (`IndDegLE`, `cubeSum`, `df.hosted`) across `t : Fin 8`. -/
theorem outcSlot_arith (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hOut : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ) {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x)
    (TB : Table) (hTB : BndTableSpec w.y25 Rp.row TB) (rnd : OutcRand)
    (ch : List Fp2) (hchCan : ∀ a ∈ ch, a.Canon) (hbad : outcAlphaBad ch = false)
    (t : Fin 8) (recs : List SlotRec) (dr : List Fp2) (hdrCan : ∀ a ∈ dr, a.Canon)
    (hdrLen : dr.length = (shdVo tag Rp wDigest bOutRow w.v).bp.draws t.val)
    (df : SlotDef)
    (hdef : (shdVo tag Rp wDigest bOutRow w.v).bp.define t.val
      (Exec.Block.histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 recs) dr = .ok df) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let P := V.bp
    let cs := outcCs (shdP_outcTA Rp w rnd) (shdP_outcTH Rp w rnd (OutcV.bga ch).2.1 (OutcV.bga ch).2.2) TB
    IndDegLE ((shdP_L2Spec ⟨27, by decide⟩).d t) (slotPolyK P (fun _ => 14) cs t.val df)
      ∧ (outcKind t = .standalone → cubeSum (slotPolyK P (fun _ => 14) cs t.val df) = 0)
      ∧ (outcKind t = .priv → cubeSum (slotPolyK P (fun _ => 14) cs t.val df) = outcPrivSum Rp w t.val)
      ∧ (t.val = 2 → cubeSum (slotPolyK P (fun _ => 14) cs t.val df) = (dr.getD 5 Fp2.zero).toK shdP_U * outcPrivSum Rp w 1
            ∧ df.hosted = [(1, dr.getD 5 Fp2.zero)])
      ∧ (t.val = 4 → cubeSum (slotPolyK P (fun _ => 14) cs t.val df) = (dr.getD 14 Fp2.zero).toK shdP_U * outcPrivSum Rp w 3
            ∧ df.hosted = [(3, dr.getD 14 Fp2.zero)]) := by
  dsimp only
  have hlogs := shdP_outcPub_logs Rp wDigest
  let hist := Exec.Block.histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 recs
  have halphaCan : hist.alpha.Canon := by
    change (OutcV.bga ch).2.2.Canon
    unfold OutcV.bga
    cases h : ch[1]? with
    | none => simp [List.getD_eq_getElem?_getD, h, Fp2.canon_zero]
    | some a =>
      have ha : a ∈ ch := List.mem_of_getElem? h
      simp [List.getD_eq_getElem?_getD, h, hchCan a ha]
  have halphaNe : ∀ z : ℕ, z < 256 →
      hist.alpha.toK shdP_U ≠ (z : shdP_K) + (hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))).toK shdP_U :=
    fun z hz => outcAlpha_ne_u8K ch hchCan hbad z hz
  fin_cases t
  · have h := outc_slot0_arith tag Rp wDigest bOutRow w TB hTB rnd (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 dr hdrCan df hdef
    exact ⟨h.1, fun _ => h.2.1, fun hk => (by cases hk), fun ht => (by dsimp at ht; omega), fun ht => (by dsimp at ht; omega)⟩
  · have h := outc_slot1_arith tag Rp wDigest bOutRow w TB rnd (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 df hdef
    exact ⟨h.1, fun hk => (by cases hk), fun _ => h.2.1, fun ht => (by dsimp at ht; omega), fun ht => (by dsimp at ht; omega)⟩
  · have hlen7 : dr.length = 7 := by rw [hdrLen]; rfl
    have h := outc_slot2_arith tag Rp hOut wDigest bOutRow w TB rnd (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 dr hlen7 hdrCan df hdef
    exact ⟨h.1, fun hk => (by cases hk), fun hk => (by cases hk), fun _ => ⟨h.2.1, h.2.2.1⟩, fun ht => (by dsimp at ht; omega)⟩
  · have h := outc_slot3_arith tag Rp hOut wDigest bOutRow w TB rnd (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 df hdef
    exact ⟨h.1, fun hk => (by cases hk), fun _ => h.2.1, fun ht => (by dsimp at ht; omega), fun ht => (by dsimp at ht; omega)⟩
  · have hlen15 : dr.length = 15 := by
      rw [hdrLen]; show outcDraws (rcVerdict (shdP_outcPub Rp wDigest) w.v) 4 = 15
      unfold outcDraws; rw [show (rcVerdict (shdP_outcPub Rp wDigest) w.v).llo = 12 from hlogs.1]; rfl
    have h := outc_slot4_arith tag Rp hOut wDigest bOutRow w TB rnd hist halphaCan halphaNe dr hlen15 hdrCan df hdef
    exact ⟨h.1, fun hk => (by cases hk), fun hk => (by cases hk), fun ht => (by dsimp at ht; omega), fun _ => ⟨h.2.1, h.2.2.1⟩⟩
  · have hlen23 : dr.length = 23 := by
      rw [hdrLen]; show outcDraws (rcVerdict (shdP_outcPub Rp wDigest) w.v) 5 = 23
      unfold outcDraws; rw [show (rcVerdict (shdP_outcPub Rp wDigest) w.v).ldo = 12 from hlogs.2.1]; rfl
    have h := outc_slot5_arith tag Rp hOut wDigest bOutRow w TB rnd hist halphaCan halphaNe dr hlen23 hdrCan df hdef
    exact ⟨h.1, fun _ => h.2.1, fun hk => (by cases hk), fun ht => (by dsimp at ht; omega), fun ht => (by dsimp at ht; omega)⟩
  · have hlen15 : dr.length = 15 := by
      rw [hdrLen]; show outcDraws (rcVerdict (shdP_outcPub Rp wDigest) w.v) 6 = 15
      unfold outcDraws; rw [show (rcVerdict (shdP_outcPub Rp wDigest) w.v).ltab = 12 from hlogs.2.2.1]; rfl
    have h := outc_slot6_arith tag Rp wDigest bOutRow w TB rnd hist halphaCan halphaNe dr hlen15 hdrCan df hdef
    exact ⟨h.1, fun _ => h.2.1, fun hk => (by cases hk), fun ht => (by dsimp at ht; omega), fun ht => (by dsimp at ht; omega)⟩
  · have h := outc_slot7_arith tag Rp wDigest bOutRow w TB rnd (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 df hdef
    exact ⟨h.1, fun _ => h.2.1, fun hk => (by cases hk), fun ht => (by dsimp at ht; omega), fun ht => (by dsimp at ht; omega)⟩

end HelpersAndArith


end ZK60.HonestShield
