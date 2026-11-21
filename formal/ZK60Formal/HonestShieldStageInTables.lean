/-
D63 lane L68c, part 1b-i (`HonestShieldStageInTables.lean`):
concrete Shieldstral T128 R13 Stage IN-C honest witness tables (`TA`, `TH ch`, `TB_in`, `TE := shdP_epTable`, `M`),
`incMult` fiberwise sum identity, admissibility extraction, `incAlpha_ne_tauK`, data-plane Boolean-cube evaluation
lemmas (`claimSem_priv_cube_y0`), and `shdP_inc_logupSumClaim_true`.

Split from `HonestShieldStageInArith.lean` so each file compiles cleanly in ~5 s under `--cap-gib 6`,
and so Block 0 can directly share `shdP_incTB` (`TB_in`).
Only at most `propext`, `Classical.choice`, `Quot.sound`; zero `sorry`s.
-/
import ZK60Formal.HonestShieldMTable
import ZK60Formal.HonestShieldStages
import ZK60Formal.RunStgShieldIncSum
import ZK60Formal.RunStgShieldIncVals
import ZK60Formal.RunStgShieldIncQzc

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Exec.StageCheck ZK60.Sound ZK60.TokenRun ZK60.StageX
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape
open ZK60.RunShape.Shield (shieldS0)
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (BlockParams SlotDef Acc Claims4 Cm Tab)

/-! ## 1. Blinding randomness, multiplicity, admissibility extraction, and `α ≠ τ` -/

section StageInBase

/-- Prover blinding randomness for Stage IN-C (`TA`, `TH`, `TB_in`, `M`); `TE` uses `epBase c : EpxSalt 6`. -/
structure IncRand where
  aMask : Fin 6 → Fin 4096 → GF
  aProx : Fin 2 → Fin 4096 → GF
  aPads : Fin 41 → Fin 256 → Fp
  aSalts : ℕ → Dig
  hMask : Fin 6 → Fin 4096 → GF
  hProx : Fin 2 → Fin 4096 → GF
  hURaw : Fin 4096 → GF × GF
  hPads : Fin 76 → Fin 256 → Fp
  hSalts : ℕ → Dig
  bMask : Fin 4 → Fin 16384 → GF
  bProx : Fin 2 → Fin 16384 → GF
  bPads : Fin 38 → Fin 256 → Fp
  bSalts : ℕ → Dig
  mA : Fin 4 → Fin 512 → Fp2
  mBRe : Fin 1024 → GF
  mBIm : Fin 1024 → GF
  mURe : Fin 1024 → GF
  mUIm : Fin 1024 → GF
  mSalts : ℕ → Dig

/-- Exact token multiplicity in prompt `x : Fin 128 → ℕ`. -/
def incMult (x : shieldS0.Tok → ℕ) (v : ℕ) : ℕ :=
  (Finset.univ.filter (fun t : shieldS0.Tok => x t = v)).card

theorem incMult_le_128 (x : shieldS0.Tok → ℕ) (v : ℕ) : incMult x v ≤ 128 := by
  unfold incMult
  calc (Finset.univ.filter (fun t : shieldS0.Tok => x t = v)).card
      ≤ (Finset.univ : Finset shieldS0.Tok).card := Finset.card_filter_le _ _
    _ = 128 := by rw [Finset.card_univ, Fintype.card_fin]; rfl

theorem incMult_lt_gP (x : shieldS0.Tok → ℕ) (v : ℕ) : incMult x v < gP :=
  lt_of_le_of_lt (incMult_le_128 x v) (by norm_num [gP])

/-- Fiberwise sum identity: `∑_{t < 128} φ(x t) = ∑_{v < 131072} incMult x v * φ(v)`. -/
theorem incMult_sum_fiber {x : shieldS0.Tok → ℕ} (hxV : ∀ t, x t < 131072) (φ : ℕ → shdP_K) :
    ∑ t : shieldS0.Tok, φ (x t) = ∑ v : Fin 131072, (incMult x v.val : shdP_K) * φ v.val := by
  have hmaps : ∀ t ∈ (Finset.univ : Finset shieldS0.Tok), (⟨x t, hxV t⟩ : Fin 131072) ∈ Finset.univ :=
    fun _ _ => Finset.mem_univ _
  rw [← Finset.sum_fiberwise_of_maps_to hmaps (fun t => φ (x t))]
  refine Finset.sum_congr rfl (fun v _ => ?_)
  have hfilt : Finset.univ.filter (fun t : shieldS0.Tok => (⟨x t, hxV t⟩ : Fin 131072) = v)
      = Finset.univ.filter (fun t : shieldS0.Tok => x t = v.val) := by
    ext t
    simp [Fin.ext_iff]
  rw [hfilt]
  have hconst : ∑ t ∈ Finset.univ.filter (fun t : shieldS0.Tok => x t = v.val), φ (x t)
      = ∑ _t ∈ Finset.univ.filter (fun t : shieldS0.Tok => x t = v.val), φ v.val :=
    Finset.sum_congr rfl (fun t ht => by rw [(Finset.mem_filter.mp ht).2])
  rw [hconst, Finset.sum_const, nsmul_eq_mul]
  rfl

/-- Extract prompt validity & control-id agreement from `(classifyModelP Rp).admissible x`. -/
theorem inSpec_of_adm (Rp : ClassifyRunPublicP shieldS0) (hV : Rp.inp.V = 131072)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) :
    (∀ t, x t < 131072)
    ∧ (∀ t : shieldS0.Tok, (t : ℕ) = 0 → x t = Rp.inp.bos)
    ∧ (∀ t, Rp.inp.isT t = true → x t = Rp.inp.kap t)
    ∧ (∀ t, Rp.inp.isT t = false → ¬ x t < Rp.inp.ns)
    ∧ ∀ (embDigest : Dig) (ef : List Fp2 → List Fp2) (t : shieldS0.Tok),
        (shdP_incPub Rp embDigest ef).ctl (x t) = (shdP_incPub Rp embDigest ef).ctlQ t.val := by
  obtain ⟨y, hy⟩ := hx
  change classifySpecP Rp x = some y at hy
  unfold classifySpecP at hy
  cases hin : inSpec Rp.inp x with
  | none => rw [hin] at hy; cases hy
  | some _ =>
    unfold inSpec at hin
    split_ifs at hin with hcond
    obtain ⟨h1, h2, h3, h4⟩ := hcond
    rw [hV] at h1
    refine ⟨h1, h2, h3, h4, fun embDigest ef t => ?_⟩
    unfold IncPub.ctl IncPub.ctlQ shdP_incPub
    dsimp only
    have ht128 : t.val < 128 := t.isLt
    have htEq : (⟨t.val, ht128⟩ : shieldS0.Tok) = t := Fin.ext rfl
    rw [dite_eq_left ht128, htEq]
    cases hT : Rp.inp.isT t with
    | true =>
      rw [h3 t hT, dite_eq_left ht128, htEq]
      simp [IncPub.ctl]
    | false =>
      have hns := h4 t hT
      simp [hns]

/-- When `incAlphaBad (incCtx I ch) = false`, `α ≠ τ[v]` in `shdP_K` for every `v < 131072`. -/
theorem incAlpha_ne_tauK (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon)
    (hbad : incAlphaBad (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch) = false)
    (v : ℕ) (hv : v < 131072) :
    let cx := incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch
    cx.alpha.toK shdP_U ≠ (cx.tauTab.getD v Fp2.zero).toK shdP_U := by
  intro cx hEq
  have hvoc : (shdP_incPub Rp embDigest (embFoldL Rp.inp)).vocLog = 17 :=
    (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.1
  have hlen : cx.tauTab.length = 131072 := by
    simp only [cx, incCtx, tauTable, List.length_map, List.length_range, hvoc]
    norm_num
  have hget : cx.tauTab.getD v Fp2.zero = cx.tauTab[v]'(by omega) := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by omega), Option.getD_some]
  have hmem : cx.tauTab.getD v Fp2.zero ∈ cx.tauTab := by
    rw [hget]; exact List.getElem_mem (by omega)
  have hcanA : cx.alpha.Canon := Fp2.canon_getD hch 2
  have hcanT : (cx.tauTab.getD v Fp2.zero).Canon := by
    obtain ⟨_, -, hEqT⟩ := List.mem_map.mp hmem
    rw [← hEqT]
    split_ifs <;> exact Fp2.canon_add _ _
  have hsub0 : (cx.alpha.sub (cx.tauTab.getD v Fp2.zero)).toK shdP_U = 0 := by
    rw [Fp2.toK_sub shdP_U _ _ hcanA hcanT, hEq, sub_self]
  have hsubZ : (cx.alpha.sub (cx.tauTab.getD v Fp2.zero)).isZero = true :=
    (isZero_iff_toK shdP_U shdP_hU _ (Fp2.canon_sub _ _ hcanA hcanT)).mpr hsub0
  have hany : cx.tauTab.any (fun z => (cx.alpha.sub z).isZero) = true :=
    List.any_eq_true.mpr ⟨cx.tauTab.getD v Fp2.zero, hmem, hsubZ⟩
  change cx.tauTab.any (fun z => (cx.alpha.sub z).isZero) = false at hbad
  rw [hany] at hbad
  cases hbad

end StageInBase

/-! ## 2. Concrete Stage IN-C honest tables (`TA`, `TH ch`, `TB_in`, `M`, `SlotData`, `IncTables`) -/

section StageInTables

variable (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)

/-- Base-field data entries of `TA` (41 rows × 4096 cols). -/
noncomputable def shdP_incTAData (x : shieldS0.Tok → ℕ) (rnd : IncRand) : Fin 41 → Fin 4096 → Fp :=
  fun r col =>
    if r.val = 0 then
      if hc : col.val < 128 then Fp.ofGF (x ⟨col.val, hc⟩ : GF) else Fp.zero
    else if r.val < 33 then
      Fp.ofGF (incMult x ((r.val - 1) * 4096 + col.val) : GF)
    else if h : r.val < 39 then
      Fp.ofGF (rnd.aMask ⟨r.val - 33, by omega⟩ col)
    else
      Fp.ofGF (rnd.aProx ⟨r.val - 39, by omega⟩ col)

/-- Honest `TA` table for Stage IN-C (41 rows, `logN = 12`, `lr = 2`, `q = 256`). -/
noncomputable def shdP_incTA (x : shieldS0.Tok → ℕ) (rnd : IncRand) : Table :=
  mkPcsTable 12 2 256 (by norm_num) (mkRows 41 4096 256 (shdP_incTAData x rnd) rnd.aPads) rnd.aSalts

/-- Zero-sum blinding helper `H_U` entry (`col = 0` set to `-∑_{j=1}^{4095} rnd.hURaw j`). -/
def shdP_incHUVal (rnd : IncRand) (col : Fin 4096) : GF × GF :=
  if col.val = 0 then
    (- ∑ j : Fin 4095, (rnd.hURaw ⟨j.val + 1, by omega⟩).1,
     - ∑ j : Fin 4095, (rnd.hURaw ⟨j.val + 1, by omega⟩).2)
  else
    rnd.hURaw col

theorem shdP_incHUVal_sum_re (rnd : IncRand) :
    ∑ col : Fin 4096, (shdP_incHUVal rnd col).1 = 0 := by
  rw [Fin.sum_univ_succ]
  simp only [shdP_incHUVal, Fin.val_zero, ↓reduceIte, Fin.val_succ, Nat.add_eq_zero_iff,
    one_ne_zero, and_false]
  exact neg_add_cancel _

theorem shdP_incHUVal_sum_im (rnd : IncRand) :
    ∑ col : Fin 4096, (shdP_incHUVal rnd col).2 = 0 := by
  rw [Fin.sum_univ_succ]
  simp only [shdP_incHUVal, Fin.val_zero, ↓reduceIte, Fin.val_succ, Nat.add_eq_zero_iff,
    one_ne_zero, and_false]
  exact neg_add_cancel _

/-- Base-field data entries of `TH ch` (76 rows × 4096 cols). -/
noncomputable def shdP_incTHData (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2) :
    Fin 76 → Fin 4096 → Fp :=
  let cx := incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch
  let α := cx.alpha.toK shdP_U
  let τK : ℕ → shdP_K := fun v => (cx.tauTab.getD v Fp2.zero).toK shdP_U
  fun r col =>
    if r.val = 0 then
      (ofK shdP_U shdP_hbij (if hc : col.val < 128 then (α - τK (x ⟨col.val, hc⟩))⁻¹ else 0)).c0
    else if r.val = 1 then
      (ofK shdP_U shdP_hbij (if hc : col.val < 128 then (α - τK (x ⟨col.val, hc⟩))⁻¹ else 0)).c1
    else if r.val < 34 then
      let v := (r.val - 2) * 4096 + col.val
      (ofK shdP_U shdP_hbij ((incMult x v : shdP_K) * (α - τK v)⁻¹)).c0
    else if r.val < 66 then
      let v := (r.val - 34) * 4096 + col.val
      (ofK shdP_U shdP_hbij ((incMult x v : shdP_K) * (α - τK v)⁻¹)).c1
    else if r.val = 66 then
      Fp.ofGF (shdP_incHUVal rnd col).1
    else if r.val = 67 then
      Fp.ofGF (shdP_incHUVal rnd col).2
    else if h : r.val < 74 then
      Fp.ofGF (rnd.hMask ⟨r.val - 68, by omega⟩ col)
    else
      Fp.ofGF (rnd.hProx ⟨r.val - 74, by omega⟩ col)

/-- Honest `TH ch` table for Stage IN-C (76 rows, `logN = 12`, `lr = 2`, `q = 256`). -/
noncomputable def shdP_incTH (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2) : Table :=
  mkPcsTable 12 2 256 (by norm_num) (mkRows 76 4096 256 (shdP_incTHData Rp embDigest x rnd ch) rnd.hPads) rnd.hSalts

/-- Base-field data entries of `TB_in` (38 rows × 16384 cols; shared with Block 0 as `TB_0`). -/
noncomputable def shdP_incTBData (x : shieldS0.Tok → ℕ) (rnd : IncRand) : Fin 38 → Fin 16384 → Fp :=
  fun r col =>
    if h32 : r.val < 32 then
      let idx := r.val * 16384 + col.val
      let t := idx / 4096
      let c := idx % 4096
      if hc : c < 3072 then
        Fp.fromI64 (Rp.inp.emb (x ⟨t, show t < 128 by have := col.isLt; omega⟩) ⟨c, hc⟩)
      else Fp.zero
    else if h36 : r.val < 36 then
      Fp.ofGF (rnd.bMask ⟨r.val - 32, by omega⟩ col)
    else
      Fp.ofGF (rnd.bProx ⟨r.val - 36, by omega⟩ col)

/-- Honest `TB_in` boundary table (38 rows, `logN = 14`, `lr = 2`, `q = 256`; shared with Block 0). -/
noncomputable def shdP_incTB (x : shieldS0.Tok → ℕ) (rnd : IncRand) : Table :=
  mkPcsTable 14 2 256 (by norm_num) (mkRows 38 16384 256 (shdP_incTBData Rp x rnd) rnd.bPads) rnd.bSalts

/-- Honest `M` mask table for Stage IN-C (`S = 4` masks via generic `mkMTable`). -/
noncomputable def shdP_incM (rnd : IncRand) : MTable :=
  mkMTable 4 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts

/-- Four-commitment claim evaluator for Stage IN-C (`TA`, `TH`, `TE`, `TB`). -/
noncomputable def incCs (TA TH TE TB : Table) : Cm → Block.ZClaim → shdP_K
  | .a => Link.claimSem shdP_U 41 12 0 (tabMat 41 12 TA.rows)
  | .h => Link.claimSem shdP_U 76 12 0 (tabMat 76 12 TH.rows)
  | .inp => Link.claimSem shdP_U 6 8 0 (tabMat 6 8 TE.rows)
  | .out => Link.claimSem shdP_U 38 14 0 (tabMat 38 14 TB.rows)

/-- Unified `SlotData` for Stage IN-C via `polySlotData` + `slotPolyK` + `Link.maskPoly`. -/
noncomputable def shdP_incSlotData (ch : List Fp2) (TA TH TE TB : Table) (rnd : IncRand) :
    SlotData ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub ch)) :=
  let V := shdVi tag Rp embDigest bInRow
  let P := V.bp (incCtx V.pub ch)
  let elog := incElog V.pub 14
  let cs := incCs TA TH TE TB
  let mRow := mRowKOf 4 rnd.mA
  polySlotData P shdP_U shdP_hbij
    (fun s _ _ _ c => ofK shdP_U shdP_hbij (c.toK shdP_U * cubeSum (Link.maskPoly mRow s (slotN P s) (slotD P s))))
    (fun s _ _ df c x =>
      slotPolyK P elog cs s df x + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) x)
    (fun s _ _ df _ rhoFull =>
      let n := (Exec.Block.slotShape P s).1
      stgPrivVals shdP_U shdP_hbij (atLog P (elog s)) cs (rhoFull.take n) (rhoFull.drop n) df.tabs)

/-- Complete `IncTables` instantiation for Stage IN-C (`TE := shdP_epTable`). -/
noncomputable def shdP_incTables {Hdr : Type} (H : HIn → Dig) (x : shieldS0.Tok → ℕ)
    (epR : EpxSalt 6) (rnd : IncRand) : IncTables (shdVi tag Rp embDigest bInRow) where
  bRoot := rootOf H tag 16 (shdP_incTB Rp x rnd)
  TA := shdP_incTA x rnd
  M := shdP_incM rnd
  TH ch := shdP_incTH Rp embDigest x rnd ch
  TE := shdP_epTable (Hdr := Hdr) tag x epR
  slot ch := shdP_incSlotData tag Rp embDigest bInRow ch
    (shdP_incTA x rnd) (shdP_incTH Rp embDigest x rnd ch) (shdP_epTable (Hdr := Hdr) tag x epR)
    (shdP_incTB Rp x rnd) rnd

theorem shdP_incTA_rows_len (x : shieldS0.Tok → ℕ) (rnd : IncRand) :
    (shdP_incTA x rnd).rows.length = 41 := mkRows_length 41 4096 256 _ _

theorem shdP_incTH_rows_len (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2) :
    (shdP_incTH Rp embDigest x rnd ch).rows.length = 76 := mkRows_length 76 4096 256 _ _

theorem shdP_incTB_rows_len (x : shieldS0.Tok → ℕ) (rnd : IncRand) :
    (shdP_incTB Rp x rnd).rows.length = 38 := mkRows_length 38 16384 256 _ _

theorem shdP_incTA_colsHonest (x : shieldS0.Tok → ℕ) (rnd : IncRand) :
    ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (shdP_incTA x rnd) :=
  mkPcsTable_colsHonest shdP_U 12 2 256 (by norm_num) _ _

theorem shdP_incTH_colsHonest (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2) :
    ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2)
      (shdP_incTH Rp embDigest x rnd ch) :=
  mkPcsTable_colsHonest shdP_U 12 2 256 (by norm_num) _ _

theorem shdP_incTB_colsHonest (x : shieldS0.Tok → ℕ) (rnd : IncRand) :
    ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 14 * 2 ^ 2) (shdP_incTB Rp x rnd) :=
  mkPcsTable_colsHonest shdP_U 14 2 256 (by norm_num) _ _

end StageInTables

/-! ## 3. Data-plane Boolean-cube evaluation (`y = 0`) & `logupSumClaim` truth -/

section DataPlaneEval

/-- Helper: `eqPoly (bitsK m a) (bitsK m b) = if a = b then 1 else 0` when `a, b < 2^m`. -/
theorem eqPoly_bitsK_eq {K : Type} [Field K] (m a b : ℕ) (ha : a < 2 ^ m) (hb : b < 2 ^ m) :
    eqPoly (Block.bitsK (K := K) m a) (Block.bitsK (K := K) m b) = if a = b then 1 else 0 := by
  have h1 : ∀ i : Fin m, Block.bitsK (K := K) m a i = (bit (msbBits m a i) : K) := fun _ => rfl
  have h2 : ∀ i : Fin m, Block.bitsK (K := K) m b i = (bit (msbBits m b i) : K) := fun _ => rfl
  unfold eqPoly
  have hprod : (∏ i : Fin m, (Block.bitsK (K := K) m a i * Block.bitsK (K := K) m b i
      + (1 - Block.bitsK (K := K) m a i) * (1 - Block.bitsK (K := K) m b i)))
      = ∏ i : Fin m, (if msbBits m a i = msbBits m b i then (1 : K) else 0) :=
    Finset.prod_congr rfl (fun i _ => by rw [h1, h2, bitEq])
  rw [hprod]
  by_cases hab : a = b
  · subst hab
    rw [ite_eq_left rfl]
    exact Finset.prod_eq_one (fun i _ => ite_eq_left rfl)
  · rw [ite_eq_right hab]
    have hne : msbBits m a ≠ msbBits m b := fun h => by
      have := congrArg (msbIndex m) h
      rw [msbIndex_msbBits m a ha, msbIndex_msbBits m b hb] at this
      exact hab this
    have hex : ∃ i : Fin m, msbBits m a i ≠ msbBits m b i := by
      by_contra hall
      push Not at hall
      exact hne (funext hall)
    obtain ⟨i, hi⟩ := hex
    exact Finset.prod_eq_zero (Finset.mem_univ i) (ite_eq_right hi)

/-- Helper: `eqPoly (fun a => bit (c a)) (bitsK m k) = if k = msbIndex m c then 1 else 0` when `k < 2^m`. -/
theorem eqPoly_bit_bitsK {K : Type} [Field K] (m : ℕ) (c : Fin m → Bool) (k : ℕ) (hk : k < 2 ^ m) :
    eqPoly (fun a : Fin m => (bit (c a) : K)) (Block.bitsK (K := K) m k)
      = if k = msbIndex m c then 1 else 0 := by
  have hc : (fun a : Fin m => (bit (c a) : K)) = Block.bitsK (K := K) m (msbIndex m c) := by
    funext a
    show (bit (c a) : K) = bit (msbBits m (msbIndex m c) a)
    rw [msbBits_msbIndex]
  rw [hc, eqPoly_bitsK_eq m (msbIndex m c) k (msbIndex_lt m c) hk]
  by_cases h : k = msbIndex m c
  · rw [ite_eq_left h.symm, ite_eq_left h]
  · rw [ite_eq_right (fun h' => h h'.symm), ite_eq_right h]

/-- At the Boolean cube point `cptS n b` (`y = 0`), `claimSem` of any `.priv` claim drops all mask rows (`cmK = 0`)
and keeps ONLY the data-plane sum (`selK = 1`). -/
theorem claimSem_priv_cube_y0 (P : BlockParams) (R lc : ℕ) (X : Fin R → Fin (2 ^ lc + 0) → shdP_K)
    {N : ℕ} (n : ℕ) (hN : N = n + 1) (b : Fin n → Bool)
    (p : Block.Priv) (sc0 : ℕ × Fp2) (rest : List (ℕ × Fp2)) (hs : p.slices = sc0 :: rest)
    (hmin : min p.log (Block.rowLog P p.cm) ≤ lc)
    (hcan : ∀ c ∈ p.coords, ∀ w, c = Block.Coord.fixed w → w.Canon) :
    let x : Fin N → shdP_K := fun i => (bit (cptS n b i) : shdP_K)
    let rho := (stgWords shdP_U shdP_hbij x).take n
    let es := (stgWords shdP_U shdP_hbij x).drop n
    Link.claimSem shdP_U R lc 0 X (Block.buildClaim P p (Block.claimPoint p rho)
      (Block.oneMinusProd es) (Block.maskCoef es p.extRound) Fp2.zero) =
    ∑ row : Fin R,
      (p.slices.map fun sc => sc.2.toK shdP_U *
        dataRowK sc.1 p.log lc p.coords.length (Block.ptK shdP_U (Block.xrK n x) p.coords) row).sum
      * ∑ t : Fin (2 ^ lc + 0), X row t *
        dataKeyColK sc0.1 p.log lc p.coords.length (Block.ptK shdP_U (Block.xrK n x) p.coords) t := by
  intro x rho es
  have hrho : rho.length = n := by simp [rho, stgWords_length, hN]
  have hes : es.length = 1 := by simp [es, stgWords_length, hN]
  have hleN : (rho ++ es).length ≤ N := by rw [List.take_append_drop, stgWords_length]
  have hrc : ∀ a ∈ rho, a.Canon := fun a ha => stgWords_canon shdP_U shdP_hbij x a (List.mem_of_mem_take ha)
  have hec : ∀ a ∈ es, a.Canon := fun a ha => stgWords_canon shdP_U shdP_hbij x a (List.mem_of_mem_drop ha)
  have h1 := claimSem_priv_words shdP_U shdP_hU P R lc 0 X (N := N) n 1 rho es hrho hes hleN hrc hec
    p sc0 rest hs hmin hcan
  dsimp only at h1
  rw [xOf_take_drop_stgWords shdP_U shdP_hbij n x] at h1
  rw [h1, selK_cptS n b hN, cmK_cptS n b hN p.extRound]
  refine Finset.sum_congr rfl (fun row _ => ?_)
  simp only [mul_one, zero_mul, add_zero]
  congr 1
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have ht : (t : ℕ) < 2 ^ lc := t.isLt
  rw [ite_eq_left ht]

/-- Helper: evaluate a single-row data slice (`p.log = lc`, `off = r0 * 2^lc`, `r0 < R`) at a Boolean point `c : Fin lc → Bool`. -/
theorem data_slice_single_row (R lc r0 : ℕ) (hr0 : r0 < R) (X : Fin R → Fin (2 ^ lc + 0) → shdP_K)
    (c : Fin lc → Bool) (pt : ℕ → shdP_K) (hpt : ∀ a : Fin lc, pt a.val = (bit (c a) : shdP_K)) :
    ∑ row : Fin R, dataRowK (r0 * 2 ^ lc) lc lc lc pt row
      * ∑ t : Fin (2 ^ lc + 0), X row t * dataKeyColK (r0 * 2 ^ lc) lc lc lc pt t
    = X ⟨r0, hr0⟩ ⟨msbIndex lc c, by have := msbIndex_lt lc c; omega⟩ := by
  have hdiv : r0 * 2 ^ lc / 2 ^ lc = r0 := Nat.mul_div_cancel r0 (Nat.two_pow_pos lc)
  have hrow : ∀ row : Fin R, dataRowK (r0 * 2 ^ lc) lc lc lc pt row = if row.val = r0 then 1 else 0 := by
    intro row
    unfold dataRowK
    by_cases hlc0 : lc = 0
    · subst hlc0
      simp only [↓reduceIte, le_rfl, Nat.sub_self, pow_zero, mul_one, Nat.div_one]
      by_cases h : row.val = r0
      · rw [ite_eq_left (by omega), ite_eq_left h]
      · rw [ite_eq_right (by omega), ite_eq_right h]
    · simp only [hlc0, ↓reduceIte, le_rfl, Nat.sub_self, Nat.zero_min, pow_zero, hdiv]
      by_cases h : row.val = r0
      · rw [ite_eq_left (by omega), ite_eq_left h]
        unfold eqPoly
        simp
      · rw [ite_eq_right (by omega), ite_eq_right h]
  have hcol : ∀ t : Fin (2 ^ lc + 0), dataKeyColK (r0 * 2 ^ lc) lc lc lc pt t
      = if t.val = msbIndex lc c then 1 else 0 := by
    intro t
    unfold dataKeyColK
    have ht : t.val < 2 ^ lc := t.isLt
    simp only [le_rfl, ↓reduceIte, Nat.sub_self, Nat.sub_zero, Nat.zero_le, true_and, Nat.zero_add, ht]
    by_cases hlc0 : lc = 0
    · subst hlc0
      have ht0 : t.val = 0 := by have := t.isLt; omega
      have hm0 : msbIndex 0 c = 0 := by have := msbIndex_lt 0 c; omega
      rw [ite_eq_left rfl, ite_eq_left (by omega)]
    · rw [ite_eq_right hlc0]
      have hlcEq : lc - (if lc ≤ lc then lc - lc else 0) = lc := by simp
      have hcast : eqPoly (fun a : Fin (lc - (if lc ≤ lc then lc - lc else 0)) => pt a.val)
            (Block.bitsK (lc - (if lc ≤ lc then lc - lc else 0)) t.val)
          = eqPoly (fun a : Fin lc => (bit (c a) : shdP_K)) (Block.bitsK lc t.val) := by
        unfold eqPoly
        rw [← Fin.prod_congr' _ hlcEq.symm]
        refine Finset.prod_congr rfl (fun a _ => ?_)
        dsimp only
        have h1 : pt (Fin.cast hlcEq.symm a).val = (bit (c a) : shdP_K) := hpt a
        have h2 : Block.bitsK (K := shdP_K) (lc - (if lc ≤ lc then lc - lc else 0)) t.val (Fin.cast hlcEq.symm a)
            = Block.bitsK (K := shdP_K) lc t.val a := by
          unfold Block.bitsK msbBits
          simp
        rw [h1, h2]
      rw [hcast, eqPoly_bit_bitsK lc c t.val t.isLt]
  rw [Finset.sum_eq_single_of_mem (⟨r0, hr0⟩ : Fin R) (Finset.mem_univ _)]
  · rw [hrow ⟨r0, hr0⟩, ite_eq_left rfl, one_mul]
    rw [Finset.sum_eq_single_of_mem (⟨msbIndex lc c, by have := msbIndex_lt lc c; omega⟩ : Fin (2 ^ lc + 0)) (Finset.mem_univ _)]
    · rw [hcol, ite_eq_left rfl, mul_one]
    · intro t _ hne
      rw [hcol, ite_eq_right (fun h => hne (Fin.ext h)), mul_zero]
  · intro row _ hne
    rw [hrow row, ite_eq_right (fun h => hne (Fin.ext h)), zero_mul]

/-- Helper: evaluate a multi-row data slice (`p.log = lc + hi`, `off = r0 * 2^lc`, `r0 + 2^hi ≤ R`)
at a Boolean point `c : Fin (lc + hi) → Bool` (splits MSB `hi` bits into row offset and LSB `lc` bits into col). -/
theorem data_slice_multi_row (R lc hi r0 : ℕ) (hr : r0 + 2 ^ hi ≤ R) (hhi : 0 < hi) (hlc : 0 < lc)
    (X : Fin R → Fin (2 ^ lc + 0) → shdP_K)
    (c : Fin (hi + lc) → Bool) (pt : ℕ → shdP_K)
    (hpt : ∀ a : Fin (hi + lc), pt a.val = (bit (c a) : shdP_K)) :
    let cHi : Fin hi → Bool := fun a => c ⟨a.val, by omega⟩
    let cLo : Fin lc → Bool := fun a => c ⟨hi + a.val, by omega⟩
    ∑ row : Fin R, dataRowK (r0 * 2 ^ lc) (hi + lc) lc (hi + lc) pt row
      * ∑ t : Fin (2 ^ lc + 0), X row t * dataKeyColK (r0 * 2 ^ lc) (hi + lc) lc (hi + lc) pt t
    = X ⟨r0 + msbIndex hi cHi, by have := msbIndex_lt hi cHi; omega⟩
        ⟨msbIndex lc cLo, by have := msbIndex_lt lc cLo; omega⟩ := by
  intro cHi cLo
  have hdiv : r0 * 2 ^ lc / 2 ^ lc = r0 := Nat.mul_div_cancel r0 (Nat.two_pow_pos lc)
  have hmin : min (hi + lc - lc) (hi + lc) = hi := by omega
  have hrow : ∀ row : Fin R, dataRowK (r0 * 2 ^ lc) (hi + lc) lc (hi + lc) pt row
      = if row.val = r0 + msbIndex hi cHi then 1 else 0 := by
    intro row
    unfold dataRowK
    rw [ite_eq_right (by omega), ite_eq_left (by omega), hdiv]
    by_cases hlt : r0 ≤ row.val ∧ row.val < r0 + 2 ^ min (hi + lc - lc) (hi + lc)
    · rw [ite_eq_left hlt]
      have hlt' : row.val - r0 < 2 ^ hi := by rw [hmin] at hlt; omega
      have hcast : eqPoly (fun a : Fin (min (hi + lc - lc) (hi + lc)) => pt a.val)
            (Block.bitsK (min (hi + lc - lc) (hi + lc)) (row.val - r0))
          = eqPoly (fun a : Fin hi => (bit (cHi a) : shdP_K)) (Block.bitsK hi (row.val - r0)) := by
        unfold eqPoly
        rw [← Fin.prod_congr' _ hmin.symm]
        refine Finset.prod_congr rfl (fun a _ => ?_)
        have h1 : pt (Fin.cast hmin.symm a).val = (bit (cHi a) : shdP_K) := hpt ⟨a.val, by omega⟩
        have h2 : Block.bitsK (K := shdP_K) (min (hi + lc - lc) (hi + lc)) (row.val - r0) (Fin.cast hmin.symm a)
            = Block.bitsK (K := shdP_K) hi (row.val - r0) a := by
          unfold Block.bitsK msbBits
          simp
        dsimp only
        rw [h1, h2]
      rw [hcast, eqPoly_bit_bitsK hi cHi (row.val - r0) hlt']
      by_cases heq : row.val = r0 + msbIndex hi cHi
      · rw [ite_eq_left (by omega), ite_eq_left heq]
      · rw [ite_eq_right (by omega), ite_eq_right heq]
    · rw [ite_eq_right hlt]
      have hne : row.val ≠ r0 + msbIndex hi cHi := by
        intro heq
        apply hlt
        have := msbIndex_lt hi cHi
        rw [hmin]; omega
      rw [ite_eq_right hne]
  have hcol : ∀ t : Fin (2 ^ lc + 0), dataKeyColK (r0 * 2 ^ lc) (hi + lc) lc (hi + lc) pt t
      = if t.val = msbIndex lc cLo then 1 else 0 := by
    intro t
    unfold dataKeyColK
    have ht : t.val < 2 ^ lc := t.isLt
    simp only [show lc ≤ hi + lc by omega, ↓reduceIte, Nat.zero_le, true_and, Nat.zero_add,
      Nat.sub_zero, ht]
    have hmK : hi + lc - (if lc ≤ hi + lc then hi + lc - lc else 0) = lc := by
      rw [ite_eq_left (by omega)]; omega
    rw [ite_eq_right (by omega), ite_eq_left (by rw [show hi + lc - (hi + lc - lc) = lc by omega]; exact ht)]
    have hcast : eqPoly (fun a : Fin (hi + lc - (if lc ≤ hi + lc then hi + lc - lc else 0)) => pt ((hi + lc - lc) + a.val))
          (Block.bitsK (hi + lc - (if lc ≤ hi + lc then hi + lc - lc else 0)) t.val)
        = eqPoly (fun a : Fin lc => (bit (cLo a) : shdP_K)) (Block.bitsK lc t.val) := by
      unfold eqPoly
      rw [← Fin.prod_congr' _ hmK.symm]
      refine Finset.prod_congr rfl (fun a _ => ?_)
      have h1 : pt ((hi + lc - lc) + (Fin.cast hmK.symm a).val) = (bit (cLo a) : shdP_K) := by
        have hidx : (hi + lc - lc) + a.val = hi + a.val := by omega
        show pt ((hi + lc - lc) + a.val) = _
        rw [hidx]
        exact hpt ⟨hi + a.val, by omega⟩
      have h2 : Block.bitsK (K := shdP_K) (hi + lc - (if lc ≤ hi + lc then hi + lc - lc else 0)) t.val (Fin.cast hmK.symm a)
          = Block.bitsK (K := shdP_K) lc t.val a := by
        unfold Block.bitsK msbBits
        simp
      dsimp only
      rw [h1, h2]
    rw [hcast, eqPoly_bit_bitsK lc cLo t.val t.isLt]
  rw [Finset.sum_eq_single_of_mem (⟨r0 + msbIndex hi cHi, by have := msbIndex_lt hi cHi; omega⟩ : Fin R) (Finset.mem_univ _)]
  · rw [hrow, ite_eq_left rfl, one_mul]
    rw [Finset.sum_eq_single_of_mem (⟨msbIndex lc cLo, by have := msbIndex_lt lc cLo; omega⟩ : Fin (2 ^ lc + 0)) (Finset.mem_univ _)]
    · rw [hcol, ite_eq_left rfl, mul_one]
    · intro t _ hne
      rw [hcol, ite_eq_right (fun h => hne (Fin.ext h)), mul_zero]
  · intro row _ hne
    rw [hrow row, ite_eq_right (fun h => hne (Fin.ext h)), zero_mul]

/-- Splitting `msbIndex (hi + lc) c` into `msbIndex hi cHi * 2^lc + msbIndex lc cLo`. -/
theorem msbIndex_split (hi lc : ℕ) (c : Fin (hi + lc) → Bool) :
    msbIndex (hi + lc) c
      = msbIndex hi (fun a => c ⟨a.val, by omega⟩) * 2 ^ lc
        + msbIndex lc (fun a => c ⟨hi + a.val, by omega⟩) := by
  have hlt1 := msbIndex_lt hi (fun a => c ⟨a.val, by omega⟩)
  have hlt2 := msbIndex_lt lc (fun a => c ⟨hi + a.val, by omega⟩)
  have hsumLt : msbIndex hi (fun a => c ⟨a.val, by omega⟩) * 2 ^ lc
      + msbIndex lc (fun a => c ⟨hi + a.val, by omega⟩) < 2 ^ (hi + lc) := by
    rw [pow_add]
    nlinarith [Nat.two_pow_pos lc]
  have hbits : msbBits (hi + lc)
      (msbIndex hi (fun a => c ⟨a.val, by omega⟩) * 2 ^ lc
        + msbIndex lc (fun a => c ⟨hi + a.val, by omega⟩)) = c := by
    funext i
    unfold msbBits
    by_cases hlt : i.val < hi
    · have hexp : hi + lc - 1 - i.val = lc + (hi - 1 - i.val) := by omega
      rw [hexp, pow_add, ← Nat.div_div_eq_div_mul]
      have hdiv : (msbIndex hi (fun a => c ⟨a.val, by omega⟩) * 2 ^ lc
          + msbIndex lc (fun a => c ⟨hi + a.val, by omega⟩)) / 2 ^ lc
          = msbIndex hi (fun a => c ⟨a.val, by omega⟩) := by
        rw [Nat.add_comm, Nat.add_mul_div_right _ _ (Nat.two_pow_pos lc),
          Nat.div_eq_of_lt hlt2, Nat.zero_add]
      rw [hdiv]
      exact congrFun (msbBits_msbIndex hi (fun a => c ⟨a.val, by omega⟩)) ⟨i.val, hlt⟩
    · have hexp : hi + lc - 1 - i.val = lc - 1 - (i.val - hi) := by omega
      rw [hexp]
      have hdiv2 : 2 ^ lc = 2 ^ (lc - 1 - (i.val - hi)) * 2 ^ (i.val - hi + 1) := by
        rw [← pow_add]; congr 1; omega
      have hq : (msbIndex hi (fun a => c ⟨a.val, by omega⟩) * 2 ^ lc
          + msbIndex lc (fun a => c ⟨hi + a.val, by omega⟩)) / 2 ^ (lc - 1 - (i.val - hi))
          = msbIndex hi (fun a => c ⟨a.val, by omega⟩) * 2 ^ (i.val - hi + 1)
            + msbIndex lc (fun a => c ⟨hi + a.val, by omega⟩) / 2 ^ (lc - 1 - (i.val - hi)) := by
        rw [hdiv2, mul_left_comm, Nat.mul_add_div (Nat.two_pow_pos _)]
      rw [hq]
      have heven : (msbIndex hi (fun a => c ⟨a.val, by omega⟩) * 2 ^ (i.val - hi + 1)) % 2 = 0 := by
        rw [pow_succ, ← mul_assoc, Nat.mul_mod_left]
      rw [Nat.add_mod, heven, Nat.zero_add, Nat.mod_mod]
      have hiLt : i.val < hi + lc := i.isLt
      have hres := congrFun (msbBits_msbIndex lc (fun a => c ⟨hi + a.val, by omega⟩)) ⟨i.val - hi, by omega⟩
      have hidx : (⟨hi + (i.val - hi), by omega⟩ : Fin (hi + lc)) = i := Fin.ext (by dsimp only; omega)
      simpa [msbBits, hidx] using hres
  have hfinal := congrArg (msbIndex (hi + lc)) hbits
  rw [msbIndex_msbBits (hi + lc) _ hsumLt] at hfinal
  exact hfinal.symm

/-- Prepending 4 leading zeros to an 8-bit vector preserves `msbIndex`. -/
theorem msbIndex_pad4 (b : Fin 8 → Bool) :
    msbIndex 12 (fun i : Fin 12 => if h : i.val < 4 then false else b ⟨i.val - 4, by omega⟩)
      = msbIndex 8 b := by
  have h := msbIndex_split 4 8 (fun i : Fin 12 => if h : i.val < 4 then false else b ⟨i.val - 4, by omega⟩)
  have hhi : (fun a : Fin 4 => (if h : a.val < 4 then false else b ⟨a.val - 4, by omega⟩)) = fun _ => false := by
    funext a; exact dite_eq_left a.isLt
  have hlo : (fun a : Fin 8 => (if h : 4 + a.val < 4 then false else b ⟨4 + a.val - 4, by omega⟩)) = b := by
    funext a
    rw [dite_eq_right (by omega)]
    exact congrArg b (Fin.ext (by dsimp only; omega))
  have h0 : msbIndex 4 (fun _ : Fin 4 => false) = 0 := by
    have hbit : msbBits 4 0 = fun _ => false := by
      funext a; simp [msbBits]
    rw [← hbit, msbIndex_msbBits 4 0 (by norm_num)]
  rw [h, hhi, hlo, h0, zero_mul, zero_add]

/-- **`shdP_epTable` row 0 at `col < 256`**: reads `[col < 128] · x(col)` in `shdP_K`. -/
theorem shdP_epTable_row0_val {Hdr : Type} (tag : MTag) (x : shieldS0.Tok → ℕ) (epR : EpxSalt 6)
    (col : Fin 256) :
    tabMat (K := shdP_K) 6 8 (shdP_epTable (Hdr := Hdr) tag x epR).rows ⟨0, by norm_num⟩ ⟨col.val, col.isLt⟩
      = if h : col.val < 128 then (x ⟨col.val, h⟩ : shdP_K) else 0 := by
  unfold tabMat shdP_epTable
  have hrow : (List.ofFn (fun i : Fin 6 =>
        List.ofFn (fun t : Fin (2 ^ 8) => Fp.ofGF (epxMsg 6 1 shdP_epPlace shdP_epPos x epR i t))
          ++ List.ofFn (fun k : Fin 256 => Fp.ofGF (epR.pads i k)))).getD 0 []
      = List.ofFn (fun t : Fin (2 ^ 8) => Fp.ofGF (epxMsg 6 1 shdP_epPlace shdP_epPos x epR ⟨0, by norm_num⟩ t))
          ++ List.ofFn (fun k : Fin 256 => Fp.ofGF (epR.pads ⟨0, by norm_num⟩ k)) :=
    ofFn_getD _ 0 (by norm_num) []
  have hc8 : col.val < 2 ^ 8 := col.isLt
  rw [hrow, List.getD_eq_getElem?_getD,
    List.getElem?_append_left (by rw [List.length_ofFn]; exact col.isLt),
    List.getElem?_ofFn, dite_eq_left hc8, Option.getD_some, Fp.toGF_ofGF]
  have hplace := epxMsg_place 6 1 shdP_epPlace shdP_epPos shdP_epPlace_injective x epR ⟨0, Nat.zero_lt_one⟩
  change algebraMap GF shdP_K (epxMsg 6 1 shdP_epPlace shdP_epPos x epR (shdP_epPlace ⟨0, Nat.zero_lt_one⟩) col) = _
  rw [hplace]
  unfold posPlane
  by_cases h128 : col.val < 128
  · rw [dite_eq_left h128]
    have hex : ∃ t : shieldS0.Tok, shdP_epPos t = (⟨0, Nat.zero_lt_one⟩, col) :=
      ⟨⟨col.val, h128⟩, Prod.ext rfl (Fin.ext rfl)⟩
    rw [dite_eq_left hex]
    have hch : hex.choose = ⟨col.val, h128⟩ :=
      shdP_epPos_injective hex.choose_spec
    rw [hch, map_natCast]
  · rw [dite_eq_right h128]
    have hnex : ¬ ∃ t : shieldS0.Tok, shdP_epPos t = (⟨0, Nat.zero_lt_one⟩, col) := by
      rintro ⟨t, ht⟩
      have heq : t.val = col.val := congrArg (fun p => p.2.val) ht
      exact h128 (heq ▸ t.isLt)
    rw [dite_eq_right hnex, map_zero]

/-- **Stage IN-C `TB_in` data plane evaluation at `(tok_bits, rEmb)`**: for `t : Fin 128`,
evaluating `TB_in` at `msbBits 7 t ++ rEmb` gives `((embFoldL Rp.inp rEmb).getD (x t) Fp2.zero).toK shdP_U`! -/
theorem shdP_incTB_eval_rEmb (Rp : ClassifyRunPublicP shieldS0) (hP : Rp.inp.Valid) (hV : Rp.inp.V = 131072)
    (x : shieldS0.Tok → ℕ) (hxV : ∀ t, x t < 131072) (rnd : IncRand)
    (rEmb : List Fp2) (hrLen : rEmb.length = 12) (hrCan : ∀ a ∈ rEmb, a.Canon)
    (t : shieldS0.Tok) (pt : ℕ → shdP_K)
    (hptLo : ∀ a : Fin 7, pt a.val = (bit (msbBits 7 t.val a) : shdP_K))
    (hptHi : ∀ a : Fin 12, pt (7 + a.val) = (rEmb.getD a.val Fp2.zero).toK shdP_U) :
    ∑ row : Fin 38, dataRowK 0 19 14 19 pt row
      * ∑ col : Fin (2 ^ 14 + 0), tabMat 38 14 (shdP_incTB Rp x rnd).rows row col
          * dataKeyColK 0 19 14 19 pt col
      = ((embFoldL Rp.inp rEmb).getD (x t) Fp2.zero).toK shdP_U := by
  -- Split `t.val < 128` into top 5 bits (`r0 = t / 4 < 32`) and bottom 2 bits (`b2 = t % 4 < 4`).
  let r0 : ℕ := t.val / 4
  let b2 : ℕ := t.val % 4
  have hr0 : r0 < 32 := by have ht : t.val < 128 := t.isLt; omega
  have hb2 : b2 < 4 := Nat.mod_lt _ (by norm_num)
  have hrow : ∀ row : Fin 38, dataRowK 0 19 14 19 pt row = if row.val = r0 then 1 else 0 := by
    intro row
    unfold dataRowK
    have hmin : min (19 - 14) 19 = 5 := by norm_num
    simp only [show (19 : ℕ) ≠ 0 by norm_num, ↓reduceIte, show 14 ≤ 19 by norm_num, Nat.zero_div,
      Nat.zero_le, true_and, Nat.zero_add, Nat.sub_zero, hmin]
    by_cases hlt : row.val < 2 ^ 5
    · rw [ite_eq_left hlt]
      have hpt5 : (fun a : Fin 5 => pt a.val) = Block.bitsK 5 r0 := by
        funext a
        rw [hptLo ⟨a.val, by omega⟩]
        show (bit (msbBits 7 t.val ⟨a.val, by omega⟩) : shdP_K) = bit (msbBits 5 (t.val / 4) a)
        unfold msbBits
        congr 3
        have hexp : 7 - 1 - a.val = 2 + (5 - 1 - a.val) := by omega
        rw [hexp, pow_add, ← Nat.div_div_eq_div_mul]
        norm_num
      change eqPoly (fun a : Fin 5 => pt a.val) (Block.bitsK 5 row.val) = _
      rw [hpt5, eqPoly_bitsK_eq 5 r0 row.val hr0 hlt]
      by_cases heq : row.val = r0
      · rw [ite_eq_left heq.symm, ite_eq_left heq]
      · rw [ite_eq_right (fun h => heq h.symm), ite_eq_right heq]
    · rw [ite_eq_right hlt, ite_eq_right (by omega)]
  rw [Finset.sum_eq_single_of_mem (⟨r0, by omega⟩ : Fin 38) (Finset.mem_univ _)]
  · rw [hrow ⟨r0, by omega⟩, ite_eq_left rfl, one_mul]
    -- Column sum over `col : Fin 16384`: `dataKeyColK` splits `col` into `q = col / 4096` (2 bits = b2) and `c = col % 4096` (12 bits = rEmb).
    have hcol : ∀ col : Fin (2 ^ 14 + 0),
        dataKeyColK 0 19 14 19 pt col
          = (if col.val / 4096 = b2 then 1 else 0)
            * eqPoly (fun a : Fin 12 => (rEmb.getD a.val Fp2.zero).toK shdP_U) (Block.bitsK 12 (col.val % 4096)) := by
      intro col
      unfold dataKeyColK
      have hcolLt : col.val < 2 ^ 14 := col.isLt
      simp only [show 14 ≤ 19 by norm_num, ↓reduceIte, Nat.zero_le, true_and, Nat.zero_add,
        Nat.sub_zero, hcolLt, show 19 - 14 = 5 by norm_num, show 19 - 5 = 14 by norm_num,
        show (14 : ℕ) ≠ 0 by norm_num]
      -- Split `eqPoly` over `Fin 14` into `Fin 2` (high) × `Fin 12` (low)
      unfold eqPoly
      change (∏ i : Fin (2 + 12), ((fun a : Fin 14 => pt (5 + a.val)) i * Block.bitsK 14 col.val i
          + (1 - (fun a : Fin 14 => pt (5 + a.val)) i) * (1 - Block.bitsK 14 col.val i))) = _
      rw [Fin.prod_univ_add (a := 2) (b := 12)]
      congr 1
      · have h2 : (∏ i : Fin 2, (pt (5 + i.val) * Block.bitsK 14 col.val (Fin.castAdd 12 i)
            + (1 - pt (5 + i.val)) * (1 - Block.bitsK 14 col.val (Fin.castAdd 12 i))))
            = eqPoly (Block.bitsK 2 b2) (Block.bitsK 2 (col.val / 4096)) := by
          unfold eqPoly
          refine Finset.prod_congr rfl (fun i _ => ?_)
          have hp1 : pt (5 + i.val) = Block.bitsK (K := shdP_K) 2 b2 i := by
            rw [hptLo ⟨5 + i.val, by omega⟩]
            show (bit (msbBits 7 t.val ⟨5 + i.val, by omega⟩) : shdP_K) = bit (msbBits 2 (t.val % 4) i)
            unfold msbBits
            congr 3
            obtain ⟨iv, hiv⟩ := i
            dsimp only
            interval_cases iv <;> norm_num <;> omega
          have hp2 : Block.bitsK (K := shdP_K) 14 col.val (Fin.castAdd 12 i)
              = Block.bitsK (K := shdP_K) 2 (col.val / 4096) i := by
            unfold Block.bitsK msbBits
            congr 3
            have hexp : 14 - 1 - i.val = 12 + (2 - 1 - i.val) := by omega
            show (col.val / 2 ^ (14 - 1 - i.val)) % 2 = ((col.val / 4096) / 2 ^ (2 - 1 - i.val)) % 2
            rw [hexp, pow_add, ← Nat.div_div_eq_div_mul]
            norm_num
          rw [hp1, hp2]
        dsimp only [Fin.val_castAdd]
        rw [h2, eqPoly_bitsK_eq 2 b2 (col.val / 4096) hb2 (by have := col.isLt; omega)]
        by_cases hq : col.val / 4096 = b2
        · rw [ite_eq_left hq.symm, ite_eq_left hq]
        · rw [ite_eq_right (fun h => hq h.symm), ite_eq_right hq]
      · refine Finset.prod_congr rfl (fun i _ => ?_)
        have hp1 : pt (5 + (Fin.natAdd 2 i).val) = (rEmb.getD i.val Fp2.zero).toK shdP_U := by
          show pt (5 + (2 + i.val)) = _
          rw [show 5 + (2 + i.val) = 7 + i.val by omega]
          exact hptHi i
        have hp2 : Block.bitsK (K := shdP_K) 14 col.val (Fin.natAdd 2 i)
            = Block.bitsK (K := shdP_K) 12 (col.val % 4096) i := by
          unfold Block.bitsK msbBits
          congr 3
          show (col.val / 2 ^ (14 - 1 - (2 + i.val))) % 2 = ((col.val % 4096) / 2 ^ (12 - 1 - i.val)) % 2
          have hexp : 14 - 1 - (2 + i.val) = 12 - 1 - i.val := by omega
          rw [hexp]
          have hdiv4 : 4096 = 2 ^ (12 - 1 - i.val) * 2 ^ (i.val + 1) := by
            rw [← pow_add, show 12 - 1 - i.val + (i.val + 1) = 12 by omega]; norm_num
          have hmod := Nat.div_add_mod col.val 4096
          have hq : col.val / 2 ^ (12 - 1 - i.val)
              = 2 ^ (i.val + 1) * (col.val / 4096) + (col.val % 4096) / 2 ^ (12 - 1 - i.val) := by
            conv_lhs => rw [← hmod]
            rw [show 4096 * (col.val / 4096) = 2 ^ (12 - 1 - i.val) * (2 ^ (i.val + 1) * (col.val / 4096)) by
              rw [hdiv4]; ring]
            exact Nat.mul_add_div (Nat.two_pow_pos _) _ _
          have hev : (2 ^ (i.val + 1) * (col.val / 4096)) % 2 = 0 := by
            rw [pow_succ, mul_right_comm, Nat.mul_mod_left]
          rw [hq, Nat.add_mod, hev, Nat.zero_add, Nat.mod_mod]
        dsimp only
        rw [hp1, hp2]
    -- Reindex `col : Fin 16384` as `(q : Fin 4, c : Fin 4096)` via `finProdFinEquiv` and pick `q = b2`.
    have hreidx :
        ∑ col : Fin (2 ^ 14 + 0), tabMat 38 14 (shdP_incTB Rp x rnd).rows ⟨r0, by omega⟩ col
            * dataKeyColK 0 19 14 19 pt col
        = ∑ c : Fin 4096,
            tabMat 38 14 (shdP_incTB Rp x rnd).rows ⟨r0, by omega⟩ ⟨b2 * 4096 + c.val, by omega⟩
              * eqPoly (fun a : Fin 12 => (rEmb.getD a.val Fp2.zero).toK shdP_U) (Block.bitsK 12 c.val) := by
      have hsum_eq := Equiv.sum_comp (finProdFinEquiv (m := 4) (n := 4096))
        (fun col : Fin (4 * 4096) =>
          tabMat 38 14 (shdP_incTB Rp x rnd).rows ⟨r0, by omega⟩ ⟨col.val, by have := col.isLt; omega⟩
            * dataKeyColK 0 19 14 19 pt col.val)
      have hcastSum : (∑ col : Fin (2 ^ 14 + 0),
          tabMat 38 14 (shdP_incTB Rp x rnd).rows ⟨r0, by omega⟩ col * dataKeyColK 0 19 14 19 pt col)
        = ∑ col : Fin (4 * 4096),
          tabMat 38 14 (shdP_incTB Rp x rnd).rows ⟨r0, by omega⟩ ⟨col.val, by have := col.isLt; omega⟩
            * dataKeyColK 0 19 14 19 pt col.val := by
        rfl
      rw [hcastSum, ← hsum_eq, Fintype.sum_prod_type]
      rw [Finset.sum_eq_single_of_mem (⟨b2, hb2⟩ : Fin 4) (Finset.mem_univ _)]
      · refine Finset.sum_congr rfl (fun c _ => ?_)
        have hval : (finProdFinEquiv (⟨b2, hb2⟩, c)).val = b2 * 4096 + c.val := by
          simp [finProdFinEquiv]; omega
        have hcol' := hcol ⟨b2 * 4096 + c.val, by have := c.isLt; omega⟩
        have hq' : (b2 * 4096 + c.val) / 4096 = b2 := by
          rw [Nat.add_comm, Nat.add_mul_div_right _ _ (by norm_num), Nat.div_eq_of_lt c.isLt, Nat.zero_add]
        have hm' : (b2 * 4096 + c.val) % 4096 = c.val := by
          rw [Nat.add_comm, Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt c.isLt]
        simp only [hval, hcol', hq', hm', ↓reduceIte, one_mul]
      · intro q _ hne
        refine Finset.sum_eq_zero (fun c _ => ?_)
        have hval : (finProdFinEquiv (q, c)).val = q.val * 4096 + c.val := by
          simp [finProdFinEquiv]; omega
        have hcol' := hcol ⟨q.val * 4096 + c.val, by have := q.isLt; have := c.isLt; omega⟩
        have hq' : (q.val * 4096 + c.val) / 4096 = q.val := by
          rw [Nat.add_comm, Nat.add_mul_div_right _ _ (by norm_num), Nat.div_eq_of_lt c.isLt, Nat.zero_add]
        have hqne : q.val ≠ b2 := fun h => hne (Fin.ext h)
        simp only [hval, hcol', hq', hqne, ↓reduceIte, zero_mul, mul_zero]
    rw [hreidx]
    -- Reindex `c : Fin 4096` to `b : Fin 12 → Bool` via `msbIndex` / `msbBits`, matching `embFoldL_hEmb`!
    have hemb := embFoldL_hEmb shdP_U shdP_hU Rp.inp hP rEmb hrLen hrCan ⟨x t, by rw [hV]; exact hxV t⟩
    rw [hemb]
    unfold mleAt
    let eBits : (Fin 12 → Bool) ≃ Fin 4096 :=
      { toFun := fun b => ⟨msbIndex 12 b, msbIndex_lt 12 b⟩
        invFun := fun c => msbBits 12 c.val
        left_inv := fun b => msbBits_msbIndex 12 b
        right_inv := fun c => Fin.ext (msbIndex_msbBits 12 c.val c.isLt) }
    rw [← Equiv.sum_comp eBits]
    refine Finset.sum_congr rfl (fun b _ => ?_)
    have hidx : r0 * 16384 + (b2 * 4096 + msbIndex 12 b) = t.val * 4096 + msbIndex 12 b := by
      have : r0 * 4 + b2 = t.val := by
        dsimp only [r0, b2]; omega
      omega
    have htab : tabMat (K := shdP_K) 38 14 (shdP_incTB Rp x rnd).rows ⟨r0, by omega⟩
        ⟨b2 * 4096 + msbIndex 12 b, by have := msbIndex_lt 12 b; omega⟩
        = algebraMap GF shdP_K (shdEpad Rp.inp ⟨x t, by rw [hV]; exact hxV t⟩ b) := by
      unfold shdP_incTB mkPcsTable
      dsimp only
      have htm := tabMat_mkRows (K := shdP_K) 38 14 256 (shdP_incTBData Rp x rnd) rnd.bPads
        ⟨r0, by omega⟩ ⟨b2 * 4096 + msbIndex 12 b, by have := msbIndex_lt 12 b; omega⟩
      refine htm.trans ?_
      have hmb : msbIndex 12 b < 4096 := by have := msbIndex_lt 12 b; omega
      have hdivT : (r0 * 16384 + (b2 * 4096 + msbIndex 12 b)) / 4096 = t.val := by
        rw [hidx, Nat.add_comm, Nat.add_mul_div_right _ _ (by norm_num),
          Nat.div_eq_of_lt hmb, Nat.zero_add]
      have hmodC : (r0 * 16384 + (b2 * 4096 + msbIndex 12 b)) % 4096 = msbIndex 12 b := by
        rw [hidx, Nat.add_comm, Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt hmb]
      have hval : shdP_incTBData Rp x rnd ⟨r0, by omega⟩ ⟨b2 * 4096 + msbIndex 12 b, by omega⟩
          = if hc : msbIndex 12 b < 3072 then Fp.fromI64 (Rp.inp.emb (x t) ⟨msbIndex 12 b, hc⟩) else Fp.zero := by
        unfold shdP_incTBData
        dsimp only
        rw [dite_eq_left hr0]
        change (if hc : (r0 * 16384 + (b2 * 4096 + msbIndex 12 b)) % 4096 < 3072 then
          Fp.fromI64 (Rp.inp.emb (x ⟨(r0 * 16384 + (b2 * 4096 + msbIndex 12 b)) / 4096, by omega⟩)
            ⟨(r0 * 16384 + (b2 * 4096 + msbIndex 12 b)) % 4096, hc⟩) else Fp.zero) = _
        have htEq : (⟨(r0 * 16384 + (b2 * 4096 + msbIndex 12 b)) / 4096, by omega⟩ : shieldS0.Tok) = t :=
          Fin.ext hdivT
        by_cases hc : msbIndex 12 b < 3072
        · have hc' : (r0 * 16384 + (b2 * 4096 + msbIndex 12 b)) % 4096 < 3072 := by omega
          rw [dite_eq_left hc', dite_eq_left hc, htEq]
          exact congrArg Fp.fromI64 (congrArg (Rp.inp.emb (x t)) (Fin.ext hmodC))
        · have hc' : ¬ (r0 * 16384 + (b2 * 4096 + msbIndex 12 b)) % 4096 < 3072 := by omega
          rw [dite_eq_right hc', dite_eq_right hc]
      have harg : (⟨(⟨b2 * 4096 + msbIndex 12 b, by omega⟩ : Fin (2 ^ 14)).val, by omega⟩ : Fin 16384)
          = ⟨b2 * 4096 + msbIndex 12 b, by omega⟩ := Fin.ext rfl
      rw [harg, hval]
      unfold shdEpad
      by_cases hc : msbIndex 12 b < 3072
      · rw [dite_eq_left hc, dite_eq_left hc]
        obtain ⟨h1, h2⟩ := hP.emb (x t) ⟨msbIndex 12 b, hc⟩
        exact congrArg (algebraMap GF shdP_K) (Fp.toGF_fromI64 _ (by linarith) (by linarith))
      · rw [dite_eq_right hc, dite_eq_right hc]
        simp [Fp.toGF, Fp.zero]
    have heqP : eqPoly (fun a : Fin 12 => (rEmb.getD a.val Fp2.zero).toK shdP_U) (Block.bitsK 12 (msbIndex 12 b))
        = eqPoly (fun a : Fin 12 => (rEmb.getD a.val Fp2.zero).toK shdP_U) (fun a => (bit (b a) : shdP_K)) :=
      congrArg (eqPoly _) (funext fun a => by
        show (bit (msbBits 12 (msbIndex 12 b) a) : shdP_K) = bit (b a)
        rw [msbBits_msbIndex])
    dsimp only [eBits, Equiv.coe_fn_mk]
    rw [htab, heqP, mul_comm]
  · intro row _ hne
    rw [hrow row, ite_eq_right (fun h => hne (Fin.ext h)), zero_mul]

private theorem incLay_hOffs (I : IncPub) (bLogN : ℕ) (hti : I.tiLog = 12) (hvoc : I.vocLog = 17) (hlt : I.lt = 12) :
    (incLay I bLogN).hOff 0 = (0, 4096)
      ∧ (incLay I bLogN).hOff 1 = (8192, 139264)
      ∧ (incLay I bLogN).hOff 2 = (270336, 274432) := by
  refine ⟨?_, ?_, ?_⟩ <;> simp [incLay, Lay.hOff, Lay.hRowsL, Lay.n, rowsOf, hti, hvoc, hlt]

private theorem shdP_incTHData_0 (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2) (col : Fin 4096) :
    let cx := incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch
    shdP_incTHData Rp embDigest x rnd ch ⟨0, by norm_num⟩ col
      = (ofK shdP_U shdP_hbij (if hc : col.val < 128
          then (cx.alpha.toK shdP_U - (cx.tauTab.getD (x ⟨col.val, hc⟩) Fp2.zero).toK shdP_U)⁻¹ else 0)).c0 := by
  unfold shdP_incTHData; dsimp only; rw [ite_eq_left rfl]

private theorem shdP_incTHData_1 (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2) (col : Fin 4096) :
    let cx := incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch
    shdP_incTHData Rp embDigest x rnd ch ⟨1, by norm_num⟩ col
      = (ofK shdP_U shdP_hbij (if hc : col.val < 128
          then (cx.alpha.toK shdP_U - (cx.tauTab.getD (x ⟨col.val, hc⟩) Fp2.zero).toK shdP_U)⁻¹ else 0)).c1 := by
  unfold shdP_incTHData; dsimp only; rw [ite_eq_right (by omega), ite_eq_left rfl]

private theorem shdP_incTHData_66 (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2) (col : Fin 4096) :
    shdP_incTHData Rp embDigest x rnd ch ⟨66, by norm_num⟩ col = Fp.ofGF (shdP_incHUVal rnd col).1 := by
  unfold shdP_incTHData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left rfl]

private theorem shdP_incTHData_67 (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2) (col : Fin 4096) :
    shdP_incTHData Rp embDigest x rnd ch ⟨67, by norm_num⟩ col = Fp.ofGF (shdP_incHUVal rnd col).2 := by
  unfold shdP_incTHData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_left rfl]

private theorem incLay_logupSumClaim_parts (I : IncPub) (bLogN : ℕ) :
    (incLay I bLogN).logupSumClaim.parts =
      [⟨((incLay I bLogN).hOff 0).1, I.tiLog, kI 1, []⟩, ⟨((incLay I bLogN).hOff 0).2, I.tiLog, (kI 1).mul Block.fp2U, []⟩,
       ⟨((incLay I bLogN).hOff 1).1, I.vocLog, kI (-1), []⟩,
       ⟨((incLay I bLogN).hOff 1).2, I.vocLog, (kI (-1)).mul Block.fp2U, []⟩,
       ⟨((incLay I bLogN).hOff 2).1, I.lt, kI 1, []⟩, ⟨((incLay I bLogN).hOff 2).2, I.lt, (kI 1).mul Block.fp2U, []⟩] := rfl

private theorem shdP_incTHData_tabRe (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2) (k : Fin 32) (col : Fin 4096) :
    let cx := incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch
    shdP_incTHData Rp embDigest x rnd ch ⟨2 + k.val, by omega⟩ col
      = (ofK shdP_U shdP_hbij ((incMult x (k.val * 4096 + col.val) : shdP_K)
          * (cx.alpha.toK shdP_U - (cx.tauTab.getD (k.val * 4096 + col.val) Fp2.zero).toK shdP_U)⁻¹)).c0 := by
  unfold shdP_incTHData; dsimp only
  have hk := k.isLt
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
  have hsub : 2 + k.val - 2 = k.val := by omega
  rw [hsub]

private theorem shdP_incTHData_tabIm (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2) (k : Fin 32) (col : Fin 4096) :
    let cx := incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch
    shdP_incTHData Rp embDigest x rnd ch ⟨34 + k.val, by omega⟩ col
      = (ofK shdP_U shdP_hbij ((incMult x (k.val * 4096 + col.val) : shdP_K)
          * (cx.alpha.toK shdP_U - (cx.tauTab.getD (k.val * 4096 + col.val) Fp2.zero).toK shdP_U)⁻¹)).c1 := by
  unfold shdP_incTHData; dsimp only
  have hk := k.isLt
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
  have hsub : 34 + k.val - 34 = k.val := by omega
  rw [hsub]

private theorem inc_inRows_sum_one (r0 : ℕ) (hr0 : r0 < 76) (f : Fin 76 → shdP_K) :
    ∑ i : Fin 76, Block.Join.W16.Look.inRows (K := shdP_K) 12 (r0 * 4096) 12 i * f i = f ⟨r0, hr0⟩ := by
  rw [Finset.sum_eq_single_of_mem ⟨r0, hr0⟩ (Finset.mem_univ _)]
  · unfold Block.Join.W16.Look.inRows
    have hdiv : r0 * 4096 / 2 ^ 12 = r0 := by omega
    rw [hdiv, Nat.sub_self, pow_zero, ite_eq_left (by dsimp only; omega), one_mul]
  · intro i _ hne
    unfold Block.Join.W16.Look.inRows
    have hdiv : r0 * 4096 / 2 ^ 12 = r0 := by omega
    rw [hdiv, Nat.sub_self, pow_zero, ite_eq_right (by intro h; exact hne (Fin.ext (by dsimp only at h ⊢; omega))), zero_mul]

private theorem inc_inRows_sum_32 (r0 : ℕ) (hr0 : r0 + 32 ≤ 76) (f : Fin 76 → shdP_K) :
    ∑ i : Fin 76, Block.Join.W16.Look.inRows (K := shdP_K) 12 (r0 * 4096) 17 i * f i
      = ∑ k : Fin 32, f ⟨r0 + k.val, by omega⟩ := by
  have hfilt : ∑ i : Fin 76, Block.Join.W16.Look.inRows (K := shdP_K) 12 (r0 * 4096) 17 i * f i
      = ∑ i ∈ Finset.univ.filter (fun i : Fin 76 => r0 ≤ i.val ∧ i.val < r0 + 32), f i := by
    rw [← Finset.sum_filter_add_sum_filter_not Finset.univ (fun i : Fin 76 => r0 ≤ i.val ∧ i.val < r0 + 32)]
    have h1 : ∑ i ∈ Finset.univ.filter (fun i : Fin 76 => r0 ≤ i.val ∧ i.val < r0 + 32),
          Block.Join.W16.Look.inRows (K := shdP_K) 12 (r0 * 4096) 17 i * f i
        = ∑ i ∈ Finset.univ.filter (fun i : Fin 76 => r0 ≤ i.val ∧ i.val < r0 + 32), f i := by
      refine Finset.sum_congr rfl (fun i hi => ?_)
      obtain ⟨hlo, hhi⟩ := (Finset.mem_filter.mp hi).2
      unfold Block.Join.W16.Look.inRows
      have hdiv : r0 * 4096 / 2 ^ 12 = r0 := by omega
      rw [hdiv, ite_eq_left (by omega), one_mul]
    have h2 : ∑ i ∈ Finset.univ.filter (fun i : Fin 76 => ¬ (r0 ≤ i.val ∧ i.val < r0 + 32)),
          Block.Join.W16.Look.inRows (K := shdP_K) 12 (r0 * 4096) 17 i * f i = 0 := by
      refine Finset.sum_eq_zero (fun i hi => ?_)
      have hn := (Finset.mem_filter.mp hi).2
      unfold Block.Join.W16.Look.inRows
      have hdiv : r0 * 4096 / 2 ^ 12 = r0 := by omega
      rw [hdiv, ite_eq_right (by omega), zero_mul]
    rw [h1, h2, add_zero]
  rw [hfilt]
  refine Finset.sum_bij (fun (i : Fin 76) (hi : i ∈ Finset.univ.filter _) =>
      (⟨i.val - r0, by have := (Finset.mem_filter.mp hi).2; omega⟩ : Fin 32))
    (fun _ _ => Finset.mem_univ _)
    (fun i₁ hi₁ i₂ hi₂ h => by
      have h1 := (Finset.mem_filter.mp hi₁).2
      have h2 := (Finset.mem_filter.mp hi₂).2
      have hv : i₁.val - r0 = i₂.val - r0 := congrArg Fin.val h
      exact Fin.ext (by omega))
    (fun k _ => ⟨⟨r0 + k.val, by omega⟩, Finset.mem_filter.mpr ⟨Finset.mem_univ _, by dsimp only; omega⟩,
      Fin.ext (by dsimp only; omega)⟩)
    (fun i hi => by
      have h1 := (Finset.mem_filter.mp hi).2
      exact congrArg f (Fin.ext (by dsimp only; omega)))

private theorem incLay_logupSumClaim_empty (I : IncPub) (hti : I.tiLog = 12) (hvoc : I.vocLog = 17)
    (hlt : I.lt = 12) :
    Block.Join.W16.Look.EmptyParts 12 (incLay I 14).logupSumClaim := by
  intro q hq
  rw [incLay_logupSumClaim_parts I 14, hti, hvoc, hlt] at hq
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hq
  rcases hq with rfl | rfl | rfl | rfl | rfl | rfl
  · exact ⟨rfl, by dsimp only; omega, kI_canon _⟩
  · exact ⟨rfl, by dsimp only; omega, Fp2.canon_mul _ _⟩
  · exact ⟨rfl, by dsimp only; omega, kI_canon _⟩
  · exact ⟨rfl, by dsimp only; omega, Fp2.canon_mul _ _⟩
  · exact ⟨rfl, by dsimp only; omega, kI_canon _⟩
  · exact ⟨rfl, by dsimp only; omega, Fp2.canon_mul _ _⟩

private theorem inc_logupSumClaim_sum_eq (I : IncPub) (hti : I.tiLog = 12) (hvoc : I.vocLog = 17)
    (hlt : I.lt = 12) (f : Fin 76 → shdP_K) :
    (((incLay I 14).logupSumClaim.parts.map fun q =>
        q.coef.toK shdP_U * ∑ i : Fin 76, Block.Join.W16.Look.inRows (K := shdP_K) 12 q.offset q.logSize i * f i).sum)
      = (1 * f ⟨0, by norm_num⟩ + shdP_U * f ⟨1, by norm_num⟩)
        + (-1 * (∑ k : Fin 32, f ⟨2 + k.val, by omega⟩)
          + -shdP_U * (∑ k : Fin 32, f ⟨34 + k.val, by omega⟩))
        + (1 * f ⟨66, by norm_num⟩ + shdP_U * f ⟨67, by norm_num⟩) := by
  rw [incLay_logupSumClaim_parts I 14]
  obtain ⟨hoff0, hoff1, hoff2⟩ := incLay_hOffs I 14 hti hvoc hlt
  have hk1 : (kI 1).toK shdP_U = 1 := kI_one_toK shdP_U
  have hkm1 : (kI (-1)).toK shdP_U = -1 := kI_negOne_toK shdP_U
  have hk1U : ((kI 1).mul Block.fp2U).toK shdP_U = shdP_U := by
    rw [Fp2.toK_mul shdP_U shdP_hU, hk1, Block.toK_fp2U, one_mul]
  have hkm1U : ((kI (-1)).mul Block.fp2U).toK shdP_U = -shdP_U := by
    rw [Fp2.toK_mul shdP_U shdP_hU, hkm1, Block.toK_fp2U, neg_one_mul]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
    hoff0, hoff1, hoff2, hti, hvoc, hlt, hk1, hkm1, hk1U, hkm1U]
  have s0 : ∑ i : Fin 76, Block.Join.W16.Look.inRows (K := shdP_K) 12 0 12 i.val * f i = f ⟨0, by norm_num⟩ := by
    simpa only [Nat.zero_mul] using inc_inRows_sum_one 0 (by norm_num) f
  have s1 : ∑ i : Fin 76, Block.Join.W16.Look.inRows (K := shdP_K) 12 4096 12 i.val * f i = f ⟨1, by norm_num⟩ := by
    simpa only [one_mul] using inc_inRows_sum_one 1 (by norm_num) f
  have s2 : ∑ i : Fin 76, Block.Join.W16.Look.inRows (K := shdP_K) 12 8192 17 i.val * f i
      = ∑ k : Fin 32, f ⟨2 + k.val, by omega⟩ := by
    have h := inc_inRows_sum_32 2 (by norm_num) f
    simpa only [show (2 : ℕ) * 4096 = 8192 by norm_num] using h
  have s34 : ∑ i : Fin 76, Block.Join.W16.Look.inRows (K := shdP_K) 12 139264 17 i.val * f i
      = ∑ k : Fin 32, f ⟨34 + k.val, by omega⟩ := by
    have h := inc_inRows_sum_32 34 (by norm_num) f
    simpa only [show (34 : ℕ) * 4096 = 139264 by norm_num] using h
  have s66 : ∑ i : Fin 76, Block.Join.W16.Look.inRows (K := shdP_K) 12 270336 12 i.val * f i = f ⟨66, by norm_num⟩ := by
    have h := inc_inRows_sum_one 66 (by norm_num) f
    simpa only [show (66 : ℕ) * 4096 = 270336 by norm_num] using h
  have s67 : ∑ i : Fin 76, Block.Join.W16.Look.inRows (K := shdP_K) 12 274432 12 i.val * f i = f ⟨67, by norm_num⟩ := by
    have h := inc_inRows_sum_one 67 (by norm_num) f
    simpa only [show (67 : ℕ) * 4096 = 274432 by norm_num] using h
  rw [s0, s1, s2, s34, s66, s67]
  simp only [add_assoc]

private theorem inc_logupSumClaim_true_abs (I : IncPub) (hti : I.tiLog = 12) (hvoc : I.vocLog = 17)
    (hlt : I.lt = 12) (TH_rows : List (List Fp)) (hlen : TH_rows.length = 76)
    (hZero :
      (1 * Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH_rows) ⟨0, by norm_num⟩
          + shdP_U * Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH_rows) ⟨1, by norm_num⟩)
      + (-1 * (∑ k : Fin 32, Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH_rows) ⟨2 + k.val, by omega⟩)
          + -shdP_U * (∑ k : Fin 32, Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH_rows) ⟨34 + k.val, by omega⟩))
      + (1 * Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH_rows) ⟨66, by norm_num⟩
          + shdP_U * Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH_rows) ⟨67, by norm_num⟩) = 0) :
    ClaimTrue shdP_U (2 ^ 12) 12 TH_rows (toZClaim (incLay I 14).logupSumClaim) := by
  rw [claimTrue_iff_claimSem shdP_U 76 12 TH_rows hlen]
  have hz := incLay_logupSumClaim_parts I 14
  have he := incLay_logupSumClaim_empty I hti hvoc hlt
  change Fp2.zero.toK shdP_U = Link.claimSem shdP_U 76 12 0 (tabMat 76 12 TH_rows) (incLay I 14).logupSumClaim
  rw [Fp2.toK_zero, Block.Join.W16.Look.claimSem_empty shdP_U 76 12 0 (tabMat 76 12 TH_rows) _ _ _ hz he,
    inc_logupSumClaim_sum_eq I hti hvoc hlt, hZero]

private theorem shdVi_lay_eq (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) :
    (shdVi tag Rp embDigest bInRow).lay = incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14 := rfl

/-- **Stage IN-C `logupSumClaim` is `ClaimTrue` on `shdP_incTH`** (given `incAlphaBad = false`). -/
theorem shdP_inc_logupSumClaim_true (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (x : shieldS0.Tok → ℕ) (hxV : ∀ t, x t < 131072) (rnd : IncRand) (ch : List Fp2) :
    ClaimTrue shdP_U (2 ^ 12) 12 (shdP_incTH Rp embDigest x rnd ch).rows
      (toZClaim (shdVi tag Rp embDigest bInRow).lay.logupSumClaim) := by
  rw [shdVi_lay_eq]
  have hlogs := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
  refine inc_logupSumClaim_true_abs (shdP_incPub Rp embDigest (embFoldL Rp.inp)) hlogs.1 hlogs.2.1 rfl
    (shdP_incTH Rp embDigest x rnd ch).rows (shdP_incTH_rows_len Rp embDigest x rnd ch) ?_
  let cx := incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch
  let α := cx.alpha.toK shdP_U
  let τK : ℕ → shdP_K := fun v => (cx.tauTab.getD v Fp2.zero).toK shdP_U
  let TH := shdP_incTH Rp embDigest x rnd ch
  have hrowS : ∀ i : Fin 76, Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) i
      = ∑ col : Fin 4096, algebraMap GF shdP_K (shdP_incTHData Rp embDigest x rnd ch i col).toGF := by
    intro i
    unfold Block.Join.W16.Look.rowS
    refine Finset.sum_congr rfl (fun col _ => ?_)
    have hcol : (col : ℕ) < 2 ^ 12 := col.isLt
    rw [ite_eq_left hcol, mul_one]
    exact tabMat_mkRows 76 12 256 _ _ i col
  have hQ : 1 * Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨0, by norm_num⟩
      + shdP_U * Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨1, by norm_num⟩
      = ∑ t : shieldS0.Tok, (α - τK (x t))⁻¹ := by
    rw [one_mul, hrowS, hrowS, Finset.mul_sum, ← Finset.sum_add_distrib]
    have hpt : ∀ col : Fin 4096,
        algebraMap GF shdP_K (shdP_incTHData Rp embDigest x rnd ch ⟨0, by norm_num⟩ col).toGF
          + shdP_U * algebraMap GF shdP_K (shdP_incTHData Rp embDigest x rnd ch ⟨1, by norm_num⟩ col).toGF
        = if hc : col.val < 128 then (α - τK (x ⟨col.val, hc⟩))⁻¹ else 0 := by
      intro col
      rw [shdP_incTHData_0 Rp embDigest x rnd ch col, shdP_incTHData_1 Rp embDigest x rnd ch col]
      exact toK_ofK shdP_U shdP_hbij _
    simp_rw [hpt]
    rw [← Finset.sum_filter_add_sum_filter_not Finset.univ (fun col : Fin 4096 => col.val < 128)]
    have hzero : ∑ col ∈ Finset.univ.filter (fun col : Fin 4096 => ¬ col.val < 128),
        (if hc : col.val < 128 then (α - τK (x ⟨col.val, hc⟩))⁻¹ else 0) = 0 :=
      Finset.sum_eq_zero (fun col hcol => dite_eq_right (Finset.mem_filter.mp hcol).2)
    rw [hzero, add_zero]
    refine Finset.sum_bij (fun (col : Fin 4096) (hcol : col ∈ Finset.univ.filter _) =>
        (⟨col.val, (Finset.mem_filter.mp hcol).2⟩ : shieldS0.Tok))
      (fun _ _ => Finset.mem_univ _)
      (fun a _ b _ h => Fin.ext (by simpa using congrArg Fin.val h))
      (fun t _ => ⟨⟨t.val, by have ht : t.val < 128 := t.isLt; omega⟩,
        Finset.mem_filter.mpr ⟨Finset.mem_univ _, t.isLt⟩, Fin.ext rfl⟩)
      (fun col hcol => dite_eq_left (Finset.mem_filter.mp hcol).2)
  have hTab : -1 * (∑ k : Fin 32, Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨2 + k.val, by omega⟩)
      + -shdP_U * (∑ k : Fin 32, Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨34 + k.val, by omega⟩)
      = - ∑ v : Fin 131072, (incMult x v.val : shdP_K) * (α - τK v.val)⁻¹ := by
    have hsum : (∑ k : Fin 32, Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨2 + k.val, by omega⟩)
        + shdP_U * (∑ k : Fin 32, Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨34 + k.val, by omega⟩)
        = ∑ v : Fin 131072, (incMult x v.val : shdP_K) * (α - τK v.val)⁻¹ := by
      rw [Finset.mul_sum, ← Finset.sum_add_distrib]
      have hpair : ∀ k : Fin 32,
          Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨2 + k.val, by omega⟩
            + shdP_U * Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨34 + k.val, by omega⟩
          = ∑ col : Fin 4096, (incMult x (k.val * 4096 + col.val) : shdP_K) * (α - τK (k.val * 4096 + col.val))⁻¹ := by
        intro k
        rw [hrowS, hrowS, Finset.mul_sum, ← Finset.sum_add_distrib]
        refine Finset.sum_congr rfl (fun col _ => ?_)
        rw [shdP_incTHData_tabRe Rp embDigest x rnd ch k col, shdP_incTHData_tabIm Rp embDigest x rnd ch k col]
        exact toK_ofK shdP_U shdP_hbij _
      simp_rw [hpair]
      rw [← Fintype.sum_prod_type']
      refine Finset.sum_bij
        (fun (p : Fin 32 × Fin 4096) (_ : p ∈ Finset.univ) =>
          (⟨p.1.val * 4096 + p.2.val, by have := p.1.isLt; have := p.2.isLt; omega⟩ : Fin 131072))
        (fun _ _ => Finset.mem_univ _)
        (fun p₁ _ p₂ _ h => by
          have hv : p₁.1.val * 4096 + p₁.2.val = p₂.1.val * 4096 + p₂.2.val := congrArg Fin.val h
          have h1 := p₁.2.isLt; have h2 := p₂.2.isLt
          exact Prod.ext (Fin.ext (by omega)) (Fin.ext (by omega)))
        (fun v _ => ⟨(⟨v.val / 4096, by have := v.isLt; omega⟩, ⟨v.val % 4096, by omega⟩),
          Finset.mem_univ _, Fin.ext (by dsimp only; omega)⟩)
        (fun _ _ => rfl)
    calc -1 * (∑ k : Fin 32, Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨2 + k.val, by omega⟩)
          + -shdP_U * (∑ k : Fin 32, Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨34 + k.val, by omega⟩)
        = - ((∑ k : Fin 32, Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨2 + k.val, by omega⟩)
            + shdP_U * (∑ k : Fin 32, Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨34 + k.val, by omega⟩)) := by ring
      _ = - ∑ v : Fin 131072, (incMult x v.val : shdP_K) * (α - τK v.val)⁻¹ := by rw [hsum]
  have hU0 : 1 * Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨66, by norm_num⟩
      + shdP_U * Block.Join.W16.Look.rowS 12 76 0 (tabMat 76 12 TH.rows) ⟨67, by norm_num⟩ = 0 := by
    rw [one_mul, hrowS, hrowS]
    have h66 : (∑ col : Fin 4096, algebraMap GF shdP_K (shdP_incTHData Rp embDigest x rnd ch ⟨66, by norm_num⟩ col).toGF)
        = 0 := by
      have heq : ∀ col : Fin 4096,
          algebraMap GF shdP_K (shdP_incTHData Rp embDigest x rnd ch ⟨66, by norm_num⟩ col).toGF
            = algebraMap GF shdP_K (shdP_incHUVal rnd col).1 := fun col => by
        rw [shdP_incTHData_66 Rp embDigest x rnd ch col, Fp.toGF_ofGF]
      simp_rw [heq]
      rw [← map_sum, shdP_incHUVal_sum_re, map_zero]
    have h67 : (∑ col : Fin 4096, algebraMap GF shdP_K (shdP_incTHData Rp embDigest x rnd ch ⟨67, by norm_num⟩ col).toGF)
        = 0 := by
      have heq : ∀ col : Fin 4096,
          algebraMap GF shdP_K (shdP_incTHData Rp embDigest x rnd ch ⟨67, by norm_num⟩ col).toGF
            = algebraMap GF shdP_K (shdP_incHUVal rnd col).2 := fun col => by
        rw [shdP_incTHData_67 Rp embDigest x rnd ch col, Fp.toGF_ofGF]
      simp_rw [heq]
      rw [← map_sum, shdP_incHUVal_sum_im, map_zero]
    rw [h66, h67, mul_zero, add_zero]
  rw [hQ, hTab, hU0, incMult_sum_fiber hxV (fun v => (α - τK v)⁻¹)]
  ring

end DataPlaneEval

end ZK60.HonestShield
