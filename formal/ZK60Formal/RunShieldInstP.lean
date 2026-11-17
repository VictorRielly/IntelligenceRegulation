/-
D63 lane L67 (2026-11-17): **concrete Shieldstral T128 R13 verifier, run schedule (`RtRun` / `RtProf.Valid`),
opening contracts (`RtInc`, `RtOutc`, `RtBlk`, `cbBndPcs`, `RkPcsAt`, `RkPcsR13`), endpoint layout (`shdP_epPos`,
`shdP_epPlace`, `shdP_honestIn`, `shdP_stgInLay`), stage shape (`shdP_P0in`, `shdP_P0out`, `hSm`, `hlcStg`,
`hNin..hN64O`, `hPin`, `hPout`), and profile domain (`shdP_runDomain`) instantiated on top of
`sshC_productionReadyL_epP_pinsHd`**.

Design & lane disjointness:
1. **Strictly disjoint from `L63` (`RunStgShield*`) and `ZK60Formal.lean` (+1 import line):** imports
   `ZK60Formal.RunBlkPinsHd` and `ZK60Formal.RunStgAlgCount` only; discharges `hLay` outright via `shdP_stgInLay` and
   leaves the 19 stage semantic / IO / doom / LogUp obligations (`csIOI`, `csIOO`, `hIOI`, `hIOO`, `hIOlI`, `hIOlO`,
   `eI`, `eO`, `ΛI`, `ΛO`, `hCsIO`, `hLuStg`, `hTrIIO`, `hTrOIO`, `hLI_stg`, `hLO_stg`, `hdinS`, `hdoutS`, `hdzW`)
   untouched in `sshC_productionReadyL_epP_shieldInst` (while exporting ready-made helpers `shdP_stgInLay_incPub`,
   `shdP_epPlace_val`, `shdP_hVi`, `shdP_hwO`, `shdP_hwB` for the `L63` join), so `L67` and `L63` merge cleanly with
   zero conflict.
2. **Definitional `RtBlk` trick (`shdP_rtBlk` on `shdP_clampPk Pk0`) + `@[irreducible] shdP_rtRun` / `shdP_wDelta`:**
   clamps `Pk0` outside `[0, 26)` via `min k 25 < 26`, extracts all `Prop` proofs into standalone `private theorem`s so
   data fields (`S = 23`, `pA.rows = 4577`, `pH.rows = 4390`, `nA = 146`, `nH = 54`, `nIn = 1`, `nOut = 1`) stay
   judgmentally `rfl` for all `k : ℕ`, and marks `shdP_wDelta` and `shdP_rtRun` `@[irreducible]` after proving their
   accessor equations so the top theorem elaborates in `< 5 GiB` RSS.
3. **Zero `GF`/`Fp2`/`Nat.log2` kernel-reduction blowups:** proves `clog2` at `{18, 128, 256, 4096, 131072}` via
   `Nat.log2_eq_iff` + `norm_num`, keeps `logupSumClaim` symbolic (`rc_outcLay_verdict` is `rfl`), and discharges
   `(shdP_rtRun ...).pf.Valid` (`270,492` squeezes, `283,822` operations `≤ 2^21`) by elementary arithmetic.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunBlkPinsHd
import ZK60Formal.RunStgAlgCount

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX ZK60.RunShape
open Code
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Cuts3 RootsO HdrX SlotRec SlotKind SlotS SlotDef PubTabs
  defineS defineS_ok cmCount cmCountS cmCount_eval blockSlots_claims sumFrom slotShape slotTerms)
open ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldCal shieldS0 shieldShape)

/-! ## 1. Concrete Shieldstral R1_MVP input token endpoint layout (`Rr = 6`, `dR = 1`, `epLogN = 8`) -/

section EpLayout

/-- Token `t : Fin 128` sits at row `0`, column `t.val < 256 = 2^8`. -/
def shdP_epPos (t : shieldS0.Tok) : Fin 1 × Fin (2 ^ 8) :=
  (⟨0, by omega⟩, ⟨t.val, by have h : t.val < 128 := t.isLt; omega⟩)

theorem shdP_epPos_injective : Function.Injective shdP_epPos := by
  intro a b h
  exact Fin.ext (congrArg (fun x => x.2.val) h)

/-- Single data row placed at row `0` (`(shdP_epPlace k).val = k.val` holds by `rfl`). -/
def shdP_epPlace (k : Fin 1) : Fin 6 := ⟨k.val, by omega⟩

theorem shdP_epPlace_val (k : Fin 1) : (shdP_epPlace k).val = k.val := rfl

theorem shdP_epPlace_injective : Function.Injective shdP_epPlace :=
  fun a b _ => Subsingleton.elim a b

/-- Concrete proof of `StgInLay` at `(tokens, inEpWords) = (128, 256)`. -/
theorem shdP_stgInLay : StgInLay shdP_epPos 128 256 := by
  refine ⟨by norm_num, fun k i => ⟨?_, ?_⟩⟩
  · rintro ⟨t, ht⟩
    have hk : k.val = 0 := by omega
    have hi : i.val = t.val := (congrArg (fun x => x.2.val) ht).symm
    have hlt : t.val < 128 := t.isLt
    omega
  · intro hlt
    have hk : k = ⟨0, Nat.zero_lt_one⟩ := Subsingleton.elim _ _
    have hi128 : i.val < 128 := by omega
    exact ⟨⟨i.val, hi128⟩, Prod.ext hk.symm (Fin.ext rfl)⟩

/-- Concrete input token commitment `epTokenCommit` at `Rr = 6`, `dR = 1`, `shdP_epPos`, `shdP_epPlace`. -/
noncomputable abbrev shdP_cin (Hdr : Type) (tag : MTag) :=
  epTokenCommit (St := ClsStmt Hdr) 6 1 shdP_epPos_injective shdP_epPlace
    (epxMsg 6 1 shdP_epPlace shdP_epPos) (epxMsg_place 6 1 shdP_epPlace shdP_epPos shdP_epPlace_injective)
    EpxSalt.pads EpxSalt.salts EpxSalt.paths ClsStmt.inRoot tag

theorem shdP_hr {Hdr : Type} (tag : MTag) {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) :
    8 * (shdP_cin Hdr tag).R ≤ Lq := by
  change 8 * 6 ≤ Lq
  omega

/-- Concrete `HonestIn` wrapper on `EpxSalt 6` (without unfolding `epForm` / `encWord`). -/
noncomputable def shdP_honestIn {Hdr Coins : Type} (tag : MTag) (epBase : Coins → EpxSalt 6) :
    HonestIn Coins (shdP_cin Hdr tag) where
  base := epBase
  withPaths r ps := { r with paths := ps }
  column_wp v r ps j := by
    have hm : (shdP_cin Hdr tag).msg v { r with paths := ps } = (shdP_cin Hdr tag).msg v r := rfl
    have hp : (shdP_cin Hdr tag).pad { r with paths := ps } = (shdP_cin Hdr tag).pad r := rfl
    simp only [PlaneCommit.column, PlaneCommit.word, hm, hp]
  salt_wp _ _ _ := rfl
  path_wp _ _ _ := rfl

end EpLayout

/-! ## 2. Concrete Shieldstral stage IN-C and OUT-C verifiers, layouts, and `P0` shapes -/

section StageInst

theorem shdP_clog2_18 : clog2 18 = 5 := by
  have h : Nat.log2 17 = 4 := (Nat.log2_eq_iff (by norm_num)).mpr ⟨by norm_num, by norm_num⟩
  simp [clog2, h]

theorem shdP_clog2_128 : clog2 128 = 7 := by
  have h : Nat.log2 127 = 6 := (Nat.log2_eq_iff (by norm_num)).mpr ⟨by norm_num, by norm_num⟩
  simp [clog2, h]

theorem shdP_clog2_256 : clog2 256 = 8 := by
  have h : Nat.log2 255 = 7 := (Nat.log2_eq_iff (by norm_num)).mpr ⟨by norm_num, by norm_num⟩
  simp [clog2, h]

theorem shdP_clog2_4096 : clog2 4096 = 12 := stgClog2_4096

theorem shdP_clog2_131072 : clog2 131072 = 17 := by
  have h : Nat.log2 131071 = 16 := (Nat.log2_eq_iff (by norm_num)).mpr ⟨by norm_num, by norm_num⟩
  simp [clog2, h]

/-- Stage regular `Dim` (`log_cols = 12`, rate `1/4`, `Q = 256`, `N = 2^14`). -/
def shdP_stgDim : Exec.Block.Dim := ⟨256, 2 ^ 12 + 256, 2 ^ 14, 14⟩

/-- Input token endpoint `Dim` (`ep_log_n = 8`, rate `1/8`, `Q = 256`, `N = 2^11`). -/
def shdP_epDim : Exec.Block.Dim := ⟨256, 2 ^ 8 + 256, 2 ^ 11, 11⟩

/-- Stage IN-C public data wired to `Rp : ClassifyRunPublicP shieldS0` (`tokens = 128, tPad = 128, dPad = 4096,
v = 131072, lt = 12, epLogN = 8`). -/
def shdP_incPub (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (embFold : List Fp2 → List Fp2) : IncPub where
  tokens := 128
  tPad := 128
  dPad := 4096
  v := 131072
  bos := Rp.inp.bos
  numSpecial := Rp.inp.ns
  isTemplate t := if h : t < 128 then Rp.inp.isT ⟨t, h⟩ else false
  kappa t := if h : t < 128 then Rp.inp.kap ⟨t, h⟩ else 0
  lt := 12
  epLogN := 8
  embDigest := embDigest
  embFold := embFold

/-- Stage IN-C geometry (`bLogN = 14, bRows = 38, epDataRows = 1, epRows = 6`). -/
def shdP_incGeo (bInRow : ℕ) : IncGeo := ⟨14, 38, bInRow, 1, 6⟩

/-- Stage IN-C verifier (`incVAt` at `lr = 2, elr = 3, q = 256, eq = 256`). -/
def shdP_incV (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (embFold : List Fp2 → List Fp2)
    (bInRow : ℕ) : IncV :=
  incVAt tag (shdP_incPub Rp embDigest embFold) (shdP_incGeo bInRow) shdP_stgDim shdP_epDim 2 3 256 256

/-- Irreducible 3072-element weight-delta list wrapper so `List.ofFn` never unfolds during `whnf` / `simp`. -/
def shdP_wDelta (wΔ : shieldS0.Wid → ℤ) : List ℤ := List.ofFn wΔ

theorem shdP_wDelta_eq (wΔ : shieldS0.Wid → ℤ) : shdP_wDelta wΔ = List.ofFn wΔ := rfl

theorem shdP_wDelta_length (wΔ : shieldS0.Wid → ℤ) : (shdP_wDelta wΔ).length = 3072 :=
  List.length_ofFn

theorem shdP_wDelta_getD (wΔ : shieldS0.Wid → ℤ) (i : ℕ) (hi : i < 3072) :
    (shdP_wDelta wΔ).getD i 0 = wΔ ⟨i, hi⟩ := by
  unfold shdP_wDelta
  have hi' : i < shieldS0.d := hi
  rw [List.getD_eq_getElem?_getD, List.getElem?_ofFn, dite_eq_left hi']
  rfl

attribute [irreducible] shdP_wDelta

/-- Stage OUT-C public data wired to `Rp : ClassifyRunPublicP shieldS0` (`d = 3072, dPad = 4096, tPad = 128,
lt = 12`). -/
def shdP_outcPub (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) : OutcPub where
  d := 3072
  dPad := 4096
  tPad := 128
  lt := 12
  limbs := Rp.out.limbs
  c := Rp.out.c
  ceps := Rp.out.ceps
  g0 := Rp.out.g0
  cn := Rp.out.cn
  tn := Rp.out.tn
  wDelta := shdP_wDelta Rp.out.wΔ
  wDigest := wDigest
  verdictRow := Rp.row.val
  verdict := 0

/-- Stage OUT-C geometry (`bLogN = 14, bRows = 38, bDataRows = 32, bSites = 2`). -/
def shdP_outcGeo (bOutRow : ℕ) : OutcGeo := ⟨14, 38, 32, 2, bOutRow⟩

/-- Stage OUT-C verifier family (`outcVAt` at `stageIndex = 27, lr = 2, blr = 2, q = 256, bq = 256`). -/
def shdP_outcV (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ) : OutcV :=
  outcVAt tag (rcVerdict (shdP_outcPub Rp wDigest) v) (shdP_outcGeo bOutRow)
    shdP_stgDim Exec.Block.R13.blkDim 27 2 2 256 256

theorem shdP_incPub_logs (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (embFold : List Fp2 → List Fp2) :
    (shdP_incPub Rp embDigest embFold).tiLog = 12
    ∧ (shdP_incPub Rp embDigest embFold).vocLog = 17
    ∧ (shdP_incPub Rp embDigest embFold).inEpWords = 256
    ∧ (shdP_incPub Rp embDigest embFold).rBits = 12
    ∧ incHeadDraws (shdP_incPub Rp embDigest embFold) = 15 := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · simp only [IncPub.tiLog, shdP_incPub, shdP_clog2_128]; omega
  · simp only [IncPub.vocLog, shdP_incPub, shdP_clog2_131072]; omega
  · simp only [IncPub.inEpWords, IncPub.epN, shdP_incPub]; omega
  · simp only [IncPub.rBits, shdP_incPub, shdP_clog2_4096]
  · exact stgShield_m _ rfl

theorem shdP_stgInLay_incPub (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (embFold : List Fp2 → List Fp2) :
    StgInLay shdP_epPos (shdP_incPub Rp embDigest embFold).tokens (shdP_incPub Rp embDigest embFold).inEpWords := by
  show StgInLay shdP_epPos 128 (shdP_incPub Rp embDigest embFold).inEpWords
  rw [(shdP_incPub_logs Rp embDigest embFold).2.2.1]
  exact shdP_stgInLay

theorem shdP_incLay_nums (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (embFold : List Fp2 → List Fp2) :
    (incLay (shdP_incPub Rp embDigest embFold) 14).aRows = 41
    ∧ (incLay (shdP_incPub Rp embDigest embFold) 14).hRows = 76
    ∧ (incLay (shdP_incPub Rp embDigest embFold) 14).nFunctionals = 8
    ∧ (incLay (shdP_incPub Rp embDigest embFold) 14).geomSlots = [(8, 1, 3), (12, 1, 4), (17, 1, 4), (12, 1, 2)] := by
  obtain ⟨hti, hvoc, hep, -, -⟩ := shdP_incPub_logs Rp embDigest embFold
  have hepc : clog2 (shdP_incPub Rp embDigest embFold).inEpWords = 8 := by rw [hep, shdP_clog2_256]
  have hlt : (shdP_incPub Rp embDigest embFold).lt = 12 := rfl
  simp only [incLay, incSched, Lay.aRows, Lay.aProx, Lay.aMaskBase, Lay.aDataRows, Lay.aRowsL,
    Lay.hRows, Lay.hProx, Lay.hMaskBase, Lay.hDataRows, Lay.hRowsL,
    Lay.prefixA, Lay.prefixH, Lay.ns, Lay.nFunctionals, Lay.geomSlots, rowsOf,
    hti, hvoc, hepc, hlt]
  norm_num

theorem shdP_outcPub_logs (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) :
    (shdP_outcPub Rp wDigest).llo = 12
    ∧ (shdP_outcPub Rp wDigest).ldo = 12
    ∧ (shdP_outcPub Rp wDigest).ltab = 12
    ∧ (shdP_outcPub Rp wDigest).dBits = 12 := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · simp only [OutcPub.llo, OutcPub.limbsIsqrt, shdP_outcPub]
    rw [show 2 * 3 * 3 = 18 by rfl, shdP_clog2_18]; omega
  · simp only [OutcPub.ldo, shdP_outcPub, shdP_clog2_4096]; omega
  · simp only [OutcPub.ltab, OutcPub.u8Len, shdP_outcPub, shdP_clog2_256]; omega
  · simp only [OutcPub.dBits, shdP_outcPub, shdP_clog2_4096]

theorem shdP_outcLay_nums (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) :
    (outcLay (shdP_outcPub Rp wDigest) 14).aRows = 76
    ∧ (outcLay (shdP_outcPub Rp wDigest) 14).hRows = 38
    ∧ (outcLay (shdP_outcPub Rp wDigest) 14).nFunctionals = 14
    ∧ (outcLay (shdP_outcPub Rp wDigest) 14).geomSlots =
        [(12, 1, 2), (12, 1, 4), (1, 1, 3), (12, 1, 2), (12, 1, 4), (12, 1, 5), (12, 1, 3), (12, 1, 2)] := by
  obtain ⟨hllo, hldo, hltab, hdb⟩ := shdP_outcPub_logs Rp wDigest
  have hlt : (shdP_outcPub Rp wDigest).lt = 12 := rfl
  simp only [outcLay, outcSched, OutcPub.toLog, Lay.aRows, Lay.aProx, Lay.aMaskBase, Lay.aDataRows, Lay.aRowsL,
    Lay.hRows, Lay.hProx, Lay.hMaskBase, Lay.hDataRows, Lay.hRowsL,
    Lay.prefixA, Lay.prefixH, Lay.ns, Lay.nFunctionals, Lay.geomSlots, rowsOf,
    hllo, hldo, hltab, hdb, hlt, List.replicate]
  norm_num

/-- Reference `BlockParams` for stage IN-C (`P0in := Vi.bp rcCx0`) and OUT-C (`P0out := (F 0).bp`). -/
def shdP_P0in (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (embFold : List Fp2 → List Fp2)
    (bInRow : ℕ) : BlockParams :=
  (shdP_incV tag Rp embDigest embFold bInRow).bp rcCx0

def shdP_P0out (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ) : BlockParams :=
  (shdP_outcV tag Rp wDigest bOutRow 0).bp

private theorem rt_incBp_geom (V : IncV) (cx : IncCtx) : (V.bp cx).geom = V.geom := rfl

private theorem stgSame_incBp (V : IncV) (cx0 cx : IncCtx) : StgSame (V.bp cx0) (V.bp cx) :=
  ⟨(rt_incBp_draws V cx0).trans (rt_incBp_draws V cx).symm,
   congrArg Exec.Block.Geom.slots ((rt_incBp_geom V cx0).trans (rt_incBp_geom V cx).symm)⟩

theorem shdP_hPin {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (embFold : List Fp2 → List Fp2) (bInRow : ℕ) :
    ∀ (_ : Hdr) cx, StgSame (shdP_P0in tag Rp embDigest embFold bInRow)
      ((shdP_incV tag Rp embDigest embFold bInRow).bp cx) :=
  fun _ cx => stgSame_incBp (shdP_incV tag Rp embDigest embFold bInRow) rcCx0 cx

theorem shdP_hPout {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ) :
    ∀ (_ : Hdr) v, StgSame (shdP_P0out tag Rp wDigest bOutRow) (shdP_outcV tag Rp wDigest bOutRow v).bp := by
  intro _ v
  refine ⟨(rc_outcV_draws tag (shdP_outcPub Rp wDigest) (shdP_outcGeo bOutRow)
      shdP_stgDim Exec.Block.R13.blkDim 27 2 2 256 256 v).symm, ?_⟩
  exact congrArg Exec.Block.Geom.slots
    (rc_outcV_geom tag (shdP_outcPub Rp wDigest) (shdP_outcGeo bOutRow)
      shdP_stgDim Exec.Block.R13.blkDim 27 2 2 256 256 v).symm

theorem shdP_P0in_slots (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (embFold : List Fp2 → List Fp2) (bInRow : ℕ) :
    (shdP_P0in tag Rp embDigest embFold bInRow).geom.slots
      = [(8, 1, 3), (12, 1, 4), (17, 1, 4), (12, 1, 2)] :=
  (shdP_incLay_nums Rp embDigest embFold).2.2.2

theorem shdP_P0out_slots (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ) :
    (shdP_P0out tag Rp wDigest bOutRow).geom.slots
      = [(12, 1, 2), (12, 1, 4), (1, 1, 3), (12, 1, 2), (12, 1, 4), (12, 1, 5), (12, 1, 3), (12, 1, 2)] :=
  (shdP_outcLay_nums Rp wDigest).2.2.2

theorem shdP_hNin (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (embFold : List Fp2 → List Fp2) (bInRow : ℕ) :
    ∀ k, k < (shdP_P0in tag Rp embDigest embFold bInRow).geom.slots.length →
      0 < stgN (shdP_P0in tag Rp embDigest embFold bInRow) k
        ∧ stgN (shdP_P0in tag Rp embDigest embFold bInRow) k
          * (slotShape (shdP_P0in tag Rp embDigest embFold bInRow) k).2.2 + 2 ≤ 512 := by
  have hsl := shdP_P0in_slots tag Rp embDigest embFold bInRow
  intro k hk
  rw [hsl] at hk
  simp only [stgN, slotShape, hsl]
  revert k hk
  decide

theorem shdP_hN64I (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (embFold : List Fp2 → List Fp2) (bInRow : ℕ) :
    ∀ k, k < (shdP_P0in tag Rp embDigest embFold bInRow).geom.slots.length →
      stgN (shdP_P0in tag Rp embDigest embFold bInRow) k < 64 := by
  have hsl := shdP_P0in_slots tag Rp embDigest embFold bInRow
  intro k hk
  rw [hsl] at hk
  simp only [stgN, slotShape, hsl]
  revert k hk
  decide

theorem shdP_hNout (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ) :
    ∀ k, k < (shdP_P0out tag Rp wDigest bOutRow).geom.slots.length →
      0 < stgN (shdP_P0out tag Rp wDigest bOutRow) k
        ∧ stgN (shdP_P0out tag Rp wDigest bOutRow) k
          * (slotShape (shdP_P0out tag Rp wDigest bOutRow) k).2.2 + 2 ≤ 512 := by
  have hsl := shdP_P0out_slots tag Rp wDigest bOutRow
  intro k hk
  rw [hsl] at hk
  simp only [stgN, slotShape, hsl]
  revert k hk
  decide

theorem shdP_hN64O (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ) :
    ∀ k, k < (shdP_P0out tag Rp wDigest bOutRow).geom.slots.length →
      stgN (shdP_P0out tag Rp wDigest bOutRow) k < 64 := by
  have hsl := shdP_P0out_slots tag Rp wDigest bOutRow
  intro k hk
  rw [hsl] at hk
  simp only [stgN, slotShape, hsl]
  revert k hk
  decide

/-- Concrete `hVi`, `hwO`, `hwB` lemmas ready for `L63`'s `sshC_productionReadyL_epP_pdz`. -/
theorem shdP_hVi (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (embFold : List Fp2 → List Fp2) (bInRow : ℕ) :
    (shdP_incV tag Rp embDigest embFold bInRow).pub.lt ≤ ogStage.lc
      ∧ (shdP_incV tag Rp embDigest embFold bInRow).pub.epLogN = 8
      ∧ 2 ^ clog2 (shdP_incV tag Rp embDigest embFold bInRow).pub.inEpWords
        = (shdP_incV tag Rp embDigest embFold bInRow).pub.inEpWords
      ∧ 0 < (shdP_P0in tag Rp embDigest embFold bInRow).geom.slots.length := by
  refine ⟨by show 12 ≤ 12; omega, rfl, ?_, ?_⟩
  · show 2 ^ clog2 (shdP_incPub Rp embDigest embFold).inEpWords = (shdP_incPub Rp embDigest embFold).inEpWords
    rw [(shdP_incPub_logs Rp embDigest embFold).2.2.1, shdP_clog2_256]
    norm_num
  · rw [shdP_P0in_slots tag Rp embDigest embFold bInRow]
    decide

theorem shdP_hwO (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (embFold : List Fp2 → List Fp2) (bInRow : ℕ) :
    (shdP_incV tag Rp embDigest embFold bInRow).geo.bLogN ≤ 14 :=
  le_refl 14

theorem shdP_hwB (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ) :
    ∀ b, (shdP_outcV tag Rp wDigest bOutRow b).geo.bLogN ≤ 14 :=
  fun _ => le_refl 14

/-- Concrete `RtInc` and `RtOutc` instances at `L + 2 = 28` segments. -/
def shdP_Iin {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ) :
    RtInc Lq (fun _ : Hdr => shdP_incV tag Rp embDigest embFold bInRow)
      (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
      (rcIncPart (shdP_incV tag Rp embDigest embFold bInRow) 256 256) :=
  rcIncAt Lq hL20 tag (shdP_incPub Rp embDigest embFold) (shdP_incGeo bInRow) shdP_stgDim shdP_epDim
    2 3 256 256 28 (by norm_num) (by norm_num) (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num)
    (by show 2 ^ 8 + 256 ≤ 2 ^ 15; norm_num)

def shdP_Oout {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow : ℕ) :
    RtOutc Lq (fun (_ : Hdr) v => shdP_outcV tag Rp wDigest bOutRow v)
      (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
      (rcOutcPart (shdP_outcV tag Rp wDigest bOutRow 0) 256 256 1) :=
  rcOutcAt Lq hL20 tag (shdP_outcPub Rp wDigest) (shdP_outcGeo bOutRow)
    shdP_stgDim Exec.Block.R13.blkDim 27 2 2 256 256 28 1
    (by norm_num) (by norm_num) (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num)
    (by show 2 ^ 14 + 256 ≤ 2 ^ 15; norm_num)

end StageInst

/-! ## 3. Concrete Shieldstral 26-block `RtBlk` & `RkPcsR13` bundle (`shdP_clampPk`, `shdP_rtBlk`) -/

section BlockInst

/-- Clamp `Pk0` outside `[0, 26)` so `shdP_clampPk Pk0 k` satisfies `ShieldBlkAtD` for **every** `k : ℕ`. -/
def shdP_clampPk (Pk0 : ℕ → BlockParams) (k : ℕ) : BlockParams := Pk0 (min k 25)

theorem shdP_clampPk_lt (Pk0 : ℕ → BlockParams) {k : ℕ} (hk : k < 26) :
    shdP_clampPk Pk0 k = Pk0 k := by
  simp [shdP_clampPk, Nat.min_eq_left (Nat.le_of_lt_succ hk)]

theorem shdP_shieldRunAtD_clamp {tag : MTag} {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) :
    ShieldRunAtD tag dPos0 (shdP_clampPk Pk0) blks 26 := by
  intro k hk
  rw [shdP_clampPk_lt Pk0 hk]
  exact hPk0 k hk

private theorem shdP_shieldGeom_bounds :
    ∀ j, j < Exec.Block.R13.shieldSlots.length →
      1 ≤ (Exec.Block.R13.shieldSlots.getD j (0, 0, 0)).2.2
        ∧ 56 + 16 * ((Exec.Block.R13.shieldSlots.getD j (0, 0, 0)).2.2 + 1) ≤ 2 ^ 20
        ∧ 55 + 16 * Exec.Block.R13.shieldTerms.getD j 0 ≤ 2 ^ 20 := by
  decide

private theorem shdP_cnt_io_sums :
    sumFrom (fun k => (List.replicate 21 0 ++ [1, 0]).getD k 0) 0 23 = 1
      ∧ sumFrom (fun k => (List.replicate 22 0 ++ [1]).getD k 0) 0 23 = 1 := by
  decide

private theorem shdP_map_getD_cmCountS (cm : Cm) (prog : List SlotS) (k : ℕ) :
    cmCountS cm (prog.getD k SlotS.empty).tabs = (prog.map (fun s => cmCountS cm s.tabs)).getD k 0 := by
  by_cases hk : k < prog.length
  · rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map,
      List.getElem?_eq_getElem hk]
    rfl
  · have hk' : prog.length ≤ k := Nat.le_of_not_lt hk
    rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD,
      List.getElem?_eq_none hk', List.getElem?_eq_none (by simp [hk'])]
    rfl

private theorem shdP_rtBlk_hokA {tag : MTag}
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) (k : ℕ) :
    ∀ (H : HIn → Dig) root cl o t t', (shdP_clampPk Pk0 k).pcsVerify H .a root cl o t = .ok t' →
      PcsOk H tag ZK60.Exec.R13.r13Prm (cosetPt (rootFp 16))
        (colEncLag (rootFp 14) (2 ^ 14) 256) root 4577 14 (cl.map toZClaim) (toOZ o) t t' := by
  intro H root cl o t t' h
  have hm : min k 25 < 26 := by omega
  obtain ⟨_, _, _, _, _, _, _, rowsOf, _, _, _, _, hP, _⟩ := hPk0 (min k 25) hm
  change (Pk0 (min k 25)).pcsVerify H .a root cl o t = .ok t' at h
  rw [hP.hPp, ZK60.Exec.R13.pcsFieldR13, hP.hrA, mapErr_ok, ZK60.Exec.R13.r13OpenCheck_ok_iff] at h
  exact h

private theorem shdP_rtBlk_hokH {tag : MTag}
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) (k : ℕ) :
    ∀ (H : HIn → Dig) root cl o t t', (shdP_clampPk Pk0 k).pcsVerify H .h root cl o t = .ok t' →
      PcsOk H tag ZK60.Exec.R13.r13Prm (cosetPt (rootFp 16))
        (colEncLag (rootFp 14) (2 ^ 14) 256) root 4390 14 (cl.map toZClaim) (toOZ o) t t' := by
  intro H root cl o t t' h
  have hm : min k 25 < 26 := by omega
  obtain ⟨_, _, _, _, _, _, _, rowsOf, _, _, _, _, hP, _⟩ := hPk0 (min k 25) hm
  change (Pk0 (min k 25)).pcsVerify H .h root cl o t = .ok t' at h
  rw [hP.hPp, ZK60.Exec.R13.pcsFieldR13, hP.hrH, mapErr_ok, ZK60.Exec.R13.r13OpenCheck_ok_iff] at h
  exact h

private theorem shdP_rtBlk_hgt {tag : MTag}
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) (k : ℕ) :
    (shdP_clampPk Pk0 k).geom.slots.length = (shdP_clampPk Pk0 k).geom.terms.length := by
  have hm : min k 25 < 26 := by omega
  obtain ⟨_, _, _, _, _, _, _, _, _, _, _, _, hP, _⟩ := hPk0 (min k 25) hm
  change (Pk0 (min k 25)).geom.slots.length = (Pk0 (min k 25)).geom.terms.length
  rw [hP.hsl, hP.htm]
  decide

private theorem shdP_rtBlk_hgeomL (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag}
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) (k j : ℕ)
    (hj : j < (shdP_clampPk Pk0 k).geom.slots.length) :
    1 ≤ (slotShape (shdP_clampPk Pk0 k) j).2.2
      ∧ 56 + 16 * ((slotShape (shdP_clampPk Pk0 k) j).2.2 + 1) ≤ Lq
      ∧ 55 + 16 * slotTerms (shdP_clampPk Pk0 k) j ≤ Lq := by
  have hm : min k 25 < 26 := by omega
  obtain ⟨_, _, _, _, _, _, _, _, _, _, _, _, hP, _⟩ := hPk0 (min k 25) hm
  change j < (Pk0 (min k 25)).geom.slots.length at hj
  rw [hP.hsl] at hj
  obtain ⟨h1, h2, h3⟩ := shdP_shieldGeom_bounds j hj
  show 1 ≤ (slotShape (Pk0 (min k 25)) j).2.2
    ∧ 56 + 16 * ((slotShape (Pk0 (min k 25)) j).2.2 + 1) ≤ Lq
    ∧ 55 + 16 * slotTerms (Pk0 (min k 25)) j ≤ Lq
  simp only [slotShape, slotTerms, hP.hsl, hP.htm]
  exact ⟨h1, le_trans h2 hL20, le_trans h3 hL20⟩

private theorem shdP_rtBlk_hPm {tag : MTag}
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) (k : ℕ) :
    (shdP_clampPk Pk0 k).maskVerify = maskField tag 23 := by
  have hm : min k 25 < 26 := by omega
  obtain ⟨_, _, _, _, _, _, _, _, _, _, _, _, hP, _⟩ := hPk0 (min k 25) hm
  exact hP.hPm

private theorem shdP_rtBlk_hcnt {tag : MTag}
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) (k : ℕ) :
    ∀ H core t bga rs acc t',
      Exec.Block.blockSlots H (shdP_clampPk Pk0 k) core t = .ok (bga, rs, acc, t') →
      core.slots.length = (shdP_clampPk Pk0 k).geom.slots.length →
      acc.claims.a.length = 146
        ∧ (acc.claims.h ++ [(shdP_clampPk Pk0 k).logupSumClaim]).length = 54
        ∧ acc.claims.inp.length = 1
        ∧ acc.claims.out.length = 1 := by
  intro H core t bga rs acc t' h hsh
  have hm : min k 25 < 26 := by omega
  obtain ⟨Ly, _, _, hLy_some, _, _, _, _, _, _, ioIn, ioOut, hP, hdef, _⟩ := hPk0 (min k 25) hm
  have hLy : Ly ∈ shieldExport := List.mem_of_getElem? hLy_some
  have hsl23 : (shdP_clampPk Pk0 k).geom.slots.length = 23 := by
    change (Pk0 (min k 25)).geom.slots.length = 23
    rw [hP.hsl]; decide
  have hdef_cm : ∀ (cm : Cm) (j : ℕ) (hist : Exec.Block.Hist) (dr : List Fp2) (df : SlotDef),
      (shdP_clampPk Pk0 k).define j hist dr = .ok df →
      cmCount cm df.tabs
        = ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).map
            (fun s => cmCountS cm s.tabs)).getD j 0 := by
    intro cm j hist dr df hdf
    change (Pk0 (min k 25)).define j hist dr = .ok df at hdf
    rw [hdef] at hdf
    obtain ⟨-, rfl⟩ := defineS_ok hdf
    rw [cmCount_eval, shdP_map_getD_cmCountS]
  have hcA := blockSlots_claims H (shdP_clampPk Pk0 k) core t bga rs acc t' .a _ (hdef_cm .a) hsh h
  have hcH := blockSlots_claims H (shdP_clampPk Pk0 k) core t bga rs acc t' .h _ (hdef_cm .h) hsh h
  have hcI := blockSlots_claims H (shdP_clampPk Pk0 k) core t bga rs acc t' .inp _ (hdef_cm .inp) hsh h
  have hcO := blockSlots_claims H (shdP_clampPk Pk0 k) core t bga rs acc t' .out _ (hdef_cm .out) hsh h
  rw [hsl23, Exec.Block.DefR13.progR13_shield_cntA ioIn ioOut Ly hLy] at hcA
  rw [hsl23, Exec.Block.DefR13.progR13_shield_cntH ioIn ioOut Ly hLy] at hcH
  rw [hsl23, progR13_shield_cntInp ioIn ioOut Ly hLy] at hcI
  rw [hsl23, progR13_shield_cntOut ioIn ioOut Ly hLy] at hcO
  refine ⟨?_, ?_, ?_, ?_⟩
  · exact hcA.trans cnt_sums.2.2.2.2.1
  · rw [List.length_append, List.length_singleton]
    change (acc.claims.get .h).length + 1 = 54
    rw [hcH]
    exact cnt_sums.2.2.2.2.2
  · exact hcI.trans shdP_cnt_io_sums.1
  · exact hcO.trans shdP_cnt_io_sums.2

/-- Concrete `RtPcs` for a block's `A` (`rows = 4577`) or `H` (`rows = 4390`) commitment at `R13`. -/
def shdP_blkPcs (tag : MTag) (P : BlockParams) (cm : Cm) (rows : ℕ)
    (hok_p : ∀ (H : HIn → Dig) root cl o t t', P.pcsVerify H cm root cl o t = .ok t' →
      PcsOk H tag ZK60.Exec.R13.r13Prm (cosetPt (rootFp 16))
        (colEncLag (rootFp 14) (2 ^ 14) 256) root rows 14 (cl.map toZClaim) (toOZ o) t t') :
    RtPcs (fun (_ : Unit) H root cl o t => P.pcsVerify H cm root cl o t) where
  tag := tag
  prm := ZK60.Exec.R13.r13Prm
  pt := cosetPt (rootFp 16)
  ev := colEncLag (rootFp 14) (2 ^ 14) 256
  rows := rows
  lc := 14
  Q := 256
  N := 2 ^ 16
  m := 64
  hok _ H root cl o t t' h := hok_p H root cl o t t' h
  hqp := rfl
  hnQ := rfl
  hnn := rfl
  hpow := rfl
  hQ0 := by norm_num
  hm := rfl
  hv15 := by norm_num

/-- **Concrete `RtBlk` for every `k : ℕ` on `shdP_clampPk Pk0`**, with judgmentally constant data fields
(`S = 23`, `nA = 146`, `nH = 54`, `nIn = 1`, `nOut = 1`, `pA.rows = 4577`, `pH.rows = 4390`, `m = 64`). -/
def shdP_rtBlk (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) (k : ℕ) :
    RtBlk Lq (shdP_clampPk Pk0 k) where
  tag := tag
  S := 23
  nA := 146
  nH := 54
  nIn := 1
  nOut := 1
  pA := shdP_blkPcs tag (shdP_clampPk Pk0 k) .a 4577 (shdP_rtBlk_hokA hPk0 k)
  pH := shdP_blkPcs tag (shdP_clampPk Pk0 k) .h 4390 (shdP_rtBlk_hokH hPk0 k)
  hgt := shdP_rtBlk_hgt hPk0 k
  hgeomL := shdP_rtBlk_hgeomL Lq hL20 hPk0 k
  hPm := shdP_rtBlk_hPm hPk0 k
  hcnt := shdP_rtBlk_hcnt hPk0 k

theorem shdP_rtBlk_pA_r13 {K : Type} [Field K] [Algebra GF K] (U : K)
    (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) (k : ℕ) :
    RkPcsR13 U tag (shdP_rtBlk Lq hL20 tag hPk0 k).pA :=
  ⟨rfl, rfl, rfl, rfl, rfl, ZK60.Exec.R13.r13_colEnc_spec U, rfl⟩

theorem shdP_rtBlk_pH_r13 {K : Type} [Field K] [Algebra GF K] (U : K)
    (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) (k : ℕ) :
    RkPcsR13 U tag (shdP_rtBlk Lq hL20 tag hPk0 k).pH :=
  ⟨rfl, rfl, rfl, rfl, rfl, ZK60.Exec.R13.r13_colEnc_spec U, rfl⟩

/-- Concrete segment geometry for block `k` (`l = 28 = 26 + 2`, segment index `k + 1`, boundary `38` rows, `2` sites). -/
def shdP_sgeom (Hdr : Type) (Pk : ℕ → BlockParams) (_ : ClsStmt Hdr) (k : ℕ) : Exec.Block.SegGeom :=
  Exec.Block.R13.segGeom (Pk k).geom 0 28 (k + 1) 38 2

/-- Concrete D12a block profile at `vdChk check0` and `cbBndOpen tag 38`. -/
def shdP_blockProf {Hdr : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit) :=
  d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
    bndCheck (cbBndOpen tag 38)

end BlockInst

/-! ## 4. Concrete Shieldstral 26-block `RunV`, `RtRun`, and `RtProf.Valid` (`270,492` squeezes, `283,822` ops) -/

section RunInst

/-- Concrete 26-layer `RunV` built from `clsStart`, `shdP_incV`, `shdP_blockProf`, and `shdP_outcV`. -/
def shdP_runV {Hdr : Type} (tag : MTag) (key : Option Dig) (domain : List UInt8) (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ)
    (Pk : ℕ → BlockParams)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit) : RunV Hdr :=
  classifyRunV 26 preA preB (clsStart domain key hw)
    (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
    (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
    (shdP_blockProf tag Pk check0 paths digest bndCheck)
    (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
    (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)

/-- Concrete `RtRun` built via `rcRunClassifyAt 26` (marked `@[irreducible]` below after proving its equations). -/
noncomputable def shdP_rtRun {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
    (key : Option Dig) (domain : List UInt8) (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ)
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 Rp.blks 26)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit) :
    RtRun (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow
      (shdP_clampPk Pk0) check0 paths digest bndCheck) key domain Lq :=
  rcRunClassifyAt 26 preA preB (clsStart domain key hw) (shdP_clampPk Pk0)
    (shdP_sgeom Hdr (shdP_clampPk Pk0)) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
    bndCheck (cbBndOpen tag 38) key domain Lq hL20
    (clsHdrOf hw) 8 0 (ab_hstart domain key hw) (ab_hhdr preA preB hw Lq hhdrFit)
    tag (shdP_incPub Rp embDigest embFold) (shdP_incGeo bInRow) shdP_stgDim shdP_epDim 2 3 256 256
    (by norm_num) (by norm_num) (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num) (by show 2 ^ 8 + 256 ≤ 2 ^ 15; norm_num)
    (shdP_outcPub Rp wDigest) (shdP_outcGeo bOutRow) shdP_stgDim Exec.Block.R13.blkDim 27 2 2 256 256
    (by norm_num) (by norm_num) (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num) (by show 2 ^ 14 + 256 ≤ 2 ^ 15; norm_num)
    rcCx0 (fun _ => 1) rfl (shdP_rtBlk Lq hL20 tag hPk0) (cbBndPcs tag 38) (fun _ => 2)
    (fun _ _ => rfl) (fun _ _ => rfl) (fun _ => rfl)

theorem shdP_rtRun_hdr {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
    (key : Option Dig) (domain : List UInt8) (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ)
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 Rp.blks 26)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit) :
    ∀ s, RtRun.hdr
      (shdP_rtRun Lq hL20 tag key domain hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
        hPk0 check0 paths digest bndCheck) s = clsHdrOf hw s :=
  fun _ => rfl

theorem shdP_rtRun_σs {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
    (key : Option Dig) (domain : List UInt8) (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ)
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 Rp.blks 26)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit) :
    RtRun.σs
      (shdP_rtRun Lq hL20 tag key domain hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
        hPk0 check0 paths digest bndCheck)
      = rtParts
        (classifyRunV 26 preA preB (clsStart domain key hw)
          (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
          (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28)
          (d12aBlockProf (shdP_clampPk Pk0) (shdP_sgeom Hdr (shdP_clampPk Pk0)) (vdChk check0) paths digest
            (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38))
          (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
          (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28))
        (rtIncSeg (fun _ => shdP_incV tag Rp embDigest embFold bInRow)
          (fun _ => rcIncGeom (shdP_incV tag Rp embDigest embFold bInRow) 28) rcCx0
          (rcIncPart (shdP_incV tag Rp embDigest embFold bInRow) 256 256))
        (fun k => rtBlockSeg (shdP_clampPk Pk0) (shdP_sgeom Hdr (shdP_clampPk Pk0)) (vdChk check0) paths digest
          (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38) k
          (rtBlockPart (shdP_clampPk Pk0 k) 23 (146 + 4577) 64 (54 + 4390) 64 (1 + 1 + 38) 2 64))
        (rtOutcSeg (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
          (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
          (rcOutcPart (shdP_outcV tag Rp wDigest bOutRow 0) 256 256 1)) :=
  rfl

theorem shdP_rtRun_pf {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
    (key : Option Dig) (domain : List UInt8) (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ)
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 Rp.blks 26)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit) :
    (shdP_rtRun Lq hL20 tag key domain hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
      hPk0 check0 paths digest bndCheck).pf
      = ⟨8, 0, [rcIncPart (shdP_incV tag Rp embDigest embFold bInRow) 256 256]
          ++ (List.range 26).map (fun k =>
            rtBlockPart (shdP_clampPk Pk0 k) 23 (146 + 4577) 64 (54 + 4390) 64 (1 + 1 + 38) 2 64)
          ++ [rcOutcPart (shdP_outcV tag Rp wDigest bOutRow 0) 256 256 1]⟩ :=
  rfl

theorem shdP_rtRun_rd {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
    (key : Option Dig) (domain : List UInt8) (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ)
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 Rp.blks 26)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit) :
    (shdP_rtRun Lq hL20 tag key domain hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
      hPk0 check0 paths digest bndCheck).rd
      = (rcRunClassifyAt 26 preA preB (clsStart domain key hw) (shdP_clampPk Pk0)
          (shdP_sgeom Hdr (shdP_clampPk Pk0)) (vdChk check0) paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38) key domain Lq hL20
          (clsHdrOf hw) 8 0 (ab_hstart domain key hw) (ab_hhdr preA preB hw Lq hhdrFit)
          tag (shdP_incPub Rp embDigest embFold) (shdP_incGeo bInRow) shdP_stgDim shdP_epDim 2 3 256 256
          (by norm_num) (by norm_num) (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num)
          (by show 2 ^ 8 + 256 ≤ 2 ^ 15; norm_num)
          (shdP_outcPub Rp wDigest) (shdP_outcGeo bOutRow) shdP_stgDim Exec.Block.R13.blkDim 27 2 2 256 256
          (by norm_num) (by norm_num) (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num)
          (by show 2 ^ 14 + 256 ≤ 2 ^ 15; norm_num)
          rcCx0 (fun _ => 1) rfl (shdP_rtBlk Lq hL20 tag hPk0) (cbBndPcs tag 38) (fun _ => 2)
          (fun _ _ => rfl) (fun _ _ => rfl) (fun _ => rfl)).rd :=
  rfl

private theorem shdP_rtPart_sqs_bounds (p : RtPart)
    (hS : p.S ≤ 64)
    (hA : 0 < p.wA ∧ p.wA ≤ 2 ^ 20) (hmA : 0 < p.mA ∧ p.mA ≤ 2 ^ 20)
    (hH : 0 < p.wH ∧ p.wH ≤ 2 ^ 20) (hmH : 0 < p.mH ∧ p.mH ≤ 2 ^ 20)
    (hX : 0 < p.wX ∧ p.wX ≤ 2 ^ 20) (hmX : 0 < p.mX ∧ p.mX ≤ 2 ^ 20) :
    ∀ n ∈ p.sqs, 0 < n ∧ n ≤ 2 ^ 61 := by
  intro n hn
  simp only [RtPart.sqs, List.mem_append, List.mem_replicate, List.mem_cons, List.not_mem_nil, or_false] at hn
  rcases hn with ⟨_, rfl⟩ | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> omega

private theorem shdP_incPart_nums (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (embFold : List Fp2 → List Fp2) (bInRow : ℕ) :
    let pin := rcIncPart (shdP_incV tag Rp embDigest embFold bInRow) 256 256
    pin.len = 605 ∧ pin.sq = 515 ∧ (∀ n ∈ pin.sqs, 0 < n ∧ n ≤ 2 ^ 61) := by
  intro pin
  obtain ⟨hti, hvoc, hep, _, hm⟩ := shdP_incPub_logs Rp embDigest embFold
  obtain ⟨ha, hh, _, hsl⟩ := shdP_incLay_nums Rp embDigest embFold
  have hepc : clog2 (shdP_incPub Rp embDigest embFold).inEpWords = 8 := by rw [hep, shdP_clog2_256]
  have hsl_len : shapeLen ((shdP_incV tag Rp embDigest embFold bInRow).bp rcCx0) 0
      (shdP_incV tag Rp embDigest embFold bInRow).geom.slots = 167 := by
    rw [shapeLen_eq]
    change shapeLenW (incDraws (shdP_incPub Rp embDigest embFold)) 0
      (incLay (shdP_incPub Rp embDigest embFold) 14).geomSlots = 167
    rw [hsl]
    simp only [shapeLenW, incDraws, hepc, hti, hvoc]
  have hsl_sq : shapeSq ((shdP_incV tag Rp embDigest embFold bInRow).bp rcCx0) 0
      (shdP_incV tag Rp embDigest embFold bInRow).geom.slots = 102 := by
    rw [shapeSq_eq]
    change shapeSqW (incDraws (shdP_incPub Rp embDigest embFold)) 0
      (incLay (shdP_incPub Rp embDigest embFold) 14).geomSlots = 102
    rw [hsl]
    simp only [shapeSqW, incDraws, hepc, hti, hvoc]
  have hlen : pin.len = 605 := by
    dsimp only [pin, rcIncPart, RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA,
      incAGroups, incHGroups]
    rw [hsl_len]
    dsimp only [shdP_incV, incVAt, IncV.lay, shdP_incGeo]
    rw [hm, ha, hh]
  have hsq : pin.sq = 515 := by
    dsimp only [pin, rcIncPart, RtPart.sq]
    rw [hsl_sq]
    dsimp only [shdP_incV, incVAt, IncV.lay, shdP_incGeo]
    rw [hm, ha, hh]
  refine ⟨hlen, hsq, shdP_rtPart_sqs_bounds pin ?_ ?_ ?_ ?_ ?_ ?_ ?_⟩ <;>
    · dsimp only [pin, rcIncPart, shdP_incV, incVAt, IncV.lay, shdP_incGeo, incAGroups, incHGroups]
      try rw [ha]
      try rw [hh]
      norm_num

private theorem shdP_outcPart_nums (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ) :
    let pout := rcOutcPart (shdP_outcV tag Rp wDigest bOutRow 0) 256 256 1
    pout.len = 797 ∧ pout.sq = 643 ∧ (∀ n ∈ pout.sqs, 0 < n ∧ n ≤ 2 ^ 61) := by
  intro pout
  obtain ⟨hllo, hldo, hltab, hdb⟩ := shdP_outcPub_logs Rp wDigest
  obtain ⟨ha, hh, _, hsl⟩ := shdP_outcLay_nums Rp wDigest
  have hsl_len : shapeLen (shdP_outcV tag Rp wDigest bOutRow 0).bp 0
      (shdP_outcV tag Rp wDigest bOutRow 0).geom.slots = 290 := by
    rw [shapeLen_eq]
    change shapeLenW (outcDraws (rcVerdict (shdP_outcPub Rp wDigest) 0)) 0
      (outcLay (rcVerdict (shdP_outcPub Rp wDigest) 0) 14).geomSlots = 290
    rw [rc_outcDraws_verdict, rc_outcLay_verdict, hsl]
    simp only [shapeLenW, outcDraws, OutcPub.toLog, hdb, hllo, hldo, hltab]
  have hsl_sq : shapeSq (shdP_outcV tag Rp wDigest bOutRow 0).bp 0
      (shdP_outcV tag Rp wDigest bOutRow 0).geom.slots = 173 := by
    rw [shapeSq_eq]
    change shapeSqW (outcDraws (rcVerdict (shdP_outcPub Rp wDigest) 0)) 0
      (outcLay (rcVerdict (shdP_outcPub Rp wDigest) 0) 14).geomSlots = 173
    rw [rc_outcDraws_verdict, rc_outcLay_verdict, hsl]
    simp only [shapeSqW, outcDraws, OutcPub.toLog, hdb, hllo, hldo, hltab]
  have hlen : pout.len = 797 := by
    dsimp only [pout, rcOutcPart, RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA,
      outcAGroups, outcHGroups]
    rw [hsl_len]
    dsimp only [shdP_outcV, outcVAt, OutcV.lay, shdP_outcGeo]
    rw [rc_outcLay_verdict, ha, hh]
  have hsq : pout.sq = 643 := by
    dsimp only [pout, rcOutcPart, RtPart.sq]
    rw [hsl_sq]
    dsimp only [shdP_outcV, outcVAt, OutcV.lay, shdP_outcGeo]
    rw [rc_outcLay_verdict, ha, hh]
  refine ⟨hlen, hsq, shdP_rtPart_sqs_bounds pout ?_ ?_ ?_ ?_ ?_ ?_ ?_⟩ <;>
    · dsimp only [pout, rcOutcPart, shdP_outcV, outcVAt, OutcV.lay, shdP_outcGeo, outcAGroups, outcHGroups]
      try rw [rc_outcLay_verdict]
      try rw [ha]
      try rw [hh]
      norm_num

private theorem shdP_blkPart_nums {tag : MTag}
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) (k : ℕ) :
    let pb := rtBlockPart (shdP_clampPk Pk0 k) 23 (146 + 4577) 64 (54 + 4390) 64 (1 + 1 + 38) 2 64
    pb.len = 10862 ∧ pb.sq = 10359 ∧ (∀ n ∈ pb.sqs, 0 < n ∧ n ≤ 2 ^ 61) := by
  intro pb
  have hm : min k 25 < 26 := by omega
  obtain ⟨_, _, _, _, _, _, _, _, _, _, _, _, hP, _⟩ := hPk0 (min k 25) hm
  have hsl_len : shapeLen (shdP_clampPk Pk0 k) 0 (shdP_clampPk Pk0 k).geom.slots = 1283 := by
    rw [shapeLen_eq]
    change shapeLenW (Pk0 (min k 25)).draws 0 (Pk0 (min k 25)).geom.slots = 1283
    rw [hP.hdr, hP.hsl]
    exact r13_shield_counts.1
  have hsl_sq : shapeSq (shdP_clampPk Pk0 k) 0 (shdP_clampPk Pk0 k).geom.slots = 844 := by
    rw [shapeSq_eq]
    change shapeSqW (Pk0 (min k 25)).draws 0 (Pk0 (min k 25)).geom.slots = 844
    rw [hP.hdr, hP.hsl]
    exact r13_shield_counts.2
  have hag : (shdP_clampPk Pk0 k).geom.aGroups = 36 := hP.hag
  have hhg : (shdP_clampPk Pk0 k).geom.hGroups = 9 := hP.hhg
  have hlen : pb.len = 10862 := by
    simp only [pb, rtBlockPart, RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA,
      hsl_len, hag, hhg]
  have hsq : pb.sq = 10359 := by
    simp only [pb, rtBlockPart, RtPart.sq, hsl_sq]
  refine ⟨hlen, hsq, shdP_rtPart_sqs_bounds pb ?_ ?_ ?_ ?_ ?_ ?_ ?_⟩ <;>
    · dsimp only [pb, rtBlockPart]
      norm_num

private theorem map_const_range_sum (n c : ℕ) :
    ((List.range n).map (fun _ => c)).sum = n * c := by
  induction n with
  | zero => simp
  | succ m ih =>
    rw [List.range_succ, List.map_append, List.sum_append, ih]
    simp [Nat.succ_mul]

private theorem flatMap_sqs_sum : ∀ ps : List RtPart, (ps.flatMap RtPart.sqs).sum = (ps.map RtPart.sq).sum
  | [] => rfl
  | p :: ps => by
    simp only [List.flatMap_cons, List.sum_append, RtPart.sqs_sum, List.map_cons, List.sum_cons, flatMap_sqs_sum ps]

/-- **`hv : (RtRun.pf Rn).Valid` PROVED OUTRIGHT** for the 26-block Shieldstral `shdP_rtRun` (`hdrLen = 8`,
`270,492` squeezes `< 2^64`, `283,822` operations `≤ 2^21`). -/
theorem shdP_rtProf_valid {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
    (key : Option Dig) (domain : List UInt8) (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (preA preB : Hdr → Except String Unit) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ)
    {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {Pk0 : ℕ → BlockParams}
    (hPk0 : ShieldRunAtD tag dPos0 Pk0 Rp.blks 26)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit) :
    (shdP_rtRun Lq hL20 tag key domain hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
      hPk0 check0 paths digest bndCheck).pf.Valid := by
  have hpf := shdP_rtRun_pf Lq hL20 tag key domain hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
    hPk0 check0 paths digest bndCheck
  rw [hpf]
  obtain ⟨hin_len, hin_sq, hin_b⟩ := shdP_incPart_nums tag Rp embDigest embFold bInRow
  obtain ⟨hout_len, hout_sq, hout_b⟩ := shdP_outcPart_nums tag Rp wDigest bOutRow
  set pin := rcIncPart (shdP_incV tag Rp embDigest embFold bInRow) 256 256
  set pout := rcOutcPart (shdP_outcV tag Rp wDigest bOutRow 0) 256 256 1
  set pblk : ℕ → RtPart := fun k =>
    rtBlockPart (shdP_clampPk Pk0 k) 23 (146 + 4577) 64 (54 + 4390) 64 (1 + 1 + 38) 2 64
  have hblk_len : ∀ k, (pblk k).len = 10862 := fun k => (shdP_blkPart_nums hPk0 k).1
  have hblk_sq : ∀ k, (pblk k).sq = 10359 := fun k => (shdP_blkPart_nums hPk0 k).2.1
  have hblk_b : ∀ k, ∀ n ∈ (pblk k).sqs, 0 < n ∧ n ≤ 2 ^ 61 := fun k => (shdP_blkPart_nums hPk0 k).2.2
  have hmemb : ∀ n ∈ (⟨8, 0, [pin] ++ (List.range 26).map pblk ++ [pout]⟩ : RtProf).sqs, 0 < n ∧ n ≤ 2 ^ 61 := by
    intro n hn
    unfold RtProf.sqs at hn
    dsimp only at hn
    rw [List.replicate_zero, List.nil_append, List.mem_flatMap] at hn
    obtain ⟨p, hp, hnp⟩ := hn
    simp only [List.mem_append, List.mem_singleton, List.mem_map] at hp
    rcases hp with (rfl | ⟨k, _, rfl⟩) | rfl
    · exact hin_b n hnp
    · exact hblk_b k n hnp
    · exact hout_b n hnp
  refine
    { hdr := by dsimp only; norm_num
      pos := fun n hn => (hmemb n hn).1
      le := fun n hn => (hmemb n hn).2
      sq := ?_
      len := ?_ }
  · show (([pin] ++ (List.range 26).map pblk ++ [pout]).flatMap RtPart.sqs).sum < 2 ^ 64
    rw [flatMap_sqs_sum]
    simp only [List.map_append, List.map_cons, List.map_nil, List.map_map, List.sum_append, List.sum_cons,
      List.sum_nil, Function.comp_def, hin_sq, hout_sq, hblk_sq, map_const_range_sum]
    norm_num
  · show 8 + (([pin] ++ (List.range 26).map pblk ++ [pout]).map RtPart.len).sum ≤ 2 ^ 21
    simp only [List.map_append, List.map_cons, List.map_nil, List.map_map, List.sum_append, List.sum_cons,
      List.sum_nil, Function.comp_def, hin_len, hout_len, hblk_len, map_const_range_sum]
    norm_num

attribute [irreducible] shdP_rtRun

end RunInst

/-! ## 5. Concrete Shieldstral profile domain (`shdP_runDomain`) and instantiated top theorems -/

section TopInst

/-- The Shieldstral-1.0-3B T128 R13 public-row classify-run domain string
(`"hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/2"`, `73` bytes; `startMsg` `85` bytes). -/
def shdP_runDomain : List UInt8 :=
  [104, 97, 115, 104, 108, 105, 110, 101, 45, 122, 107, 45, 109, 114, 49, 47, 112, 114, 105, 118, 97, 116, 101, 45,
    99, 108, 97, 115, 115, 105, 102, 121, 45, 114, 117, 110, 45, 115, 104, 105, 101, 108, 100, 115, 116, 114, 97,
    108, 45, 51, 98, 45, 116, 49, 50, 56, 45, 114, 49, 51, 45, 112, 117, 98, 108, 105, 99, 45, 114, 111, 119, 47, 50]

theorem shdP_runDomain_start_none : decodeLink (startMsg shdP_runDomain) = none :=
  decodeLink_none_of_long _ (by decide) (by decide)

theorem shdP_runDomain_start_le {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) :
    (startMsg shdP_runDomain).length ≤ Lq :=
  le_trans (by decide : (startMsg shdP_runDomain).length ≤ 100) (by omega)

/-- Convenience wrapper for `Function.Bijective (fp2 U)` from `finrank GF K = 2` and `U ^ 2 = 7`. -/
theorem shdP_fp2_bijective {K : Type} [Field K] [Algebra GF K] (U : K)
    (hK2 : Module.finrank GF K = 2) (hU : U ^ 2 = algebraMap GF K 7) :
    Function.Bijective (ZK60.Hiding.fp2 (F := GF) U) :=
  ZK60.Hiding.fp2_bijective hK2 hU Exec.seven_not_square

theorem shdP_incPart_S (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (embFold : List Fp2 → List Fp2) (bInRow : ℕ) :
    (rcIncPart (shdP_incV tag Rp embDigest embFold bInRow) 256 256).S = 4 := by
  show (incLay (shdP_incPub Rp embDigest embFold) 14).geomSlots.length = 4
  rw [(shdP_incLay_nums Rp embDigest embFold).2.2.2]
  rfl

theorem shdP_outcPart_S (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ) :
    (rcOutcPart (shdP_outcV tag Rp wDigest bOutRow 0) 256 256 1).S = 8 := by
  show (outcLay (rcVerdict (shdP_outcPub Rp wDigest) 0) 14).geomSlots.length = 8
  rw [rc_outcLay_verdict, (shdP_outcLay_nums Rp wDigest).2.2.2]
  rfl

section ShieldTop

variable {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
  {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
  (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag)
  (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
  (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (hL64 : Lq < 2 ^ 64)
  (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (Rp : ClassifyRunPublicP shieldS0)
  (hw : Hdr → ClsHdrW)
  (hhdrFit : ∀ hd : Hdr,
    64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
  (preA preB : Hdr → Except String Unit)
  (check0 : ClsStmt Hdr → ℕ → Except String Unit)
  (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig)
  (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
  (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
  (wDigest : Dig) (bOutRow : ℕ)
  (Pk0 : ℕ → BlockParams)
  (hPk0 : ShieldRunAtD tag dPos0 Pk0 Rp.blks 26)
  (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
  (epBase : Coins → EpxSalt 6)
  (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 (EpxSalt 6))
  (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
  (eI eO : ℕ)
  (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)

set_option quotPrecheck false

local notation "RnS" =>
  shdP_rtRun Lq hL20 tag key domain hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
    hPk0 check0 paths digest bndCheck

local notation "ViS" => shdP_incV tag Rp embDigest embFold bInRow
local notation "FoS" => shdP_outcV tag Rp wDigest bOutRow
local notation "IinS" => shdP_Iin (Hdr := Hdr) Lq hL20 tag Rp embDigest embFold bInRow
local notation "OoutS" => shdP_Oout (Hdr := Hdr) Lq hL20 tag Rp wDigest bOutRow
local notation "P0inS" => shdP_P0in tag Rp embDigest embFold bInRow
local notation "P0outS" => shdP_P0out tag Rp wDigest bOutRow
local notation "AbsS" => Exec.Block.absOfC (chainEncB key domain hs Lq hL)
local notation "HvS" =>
  shdP_rtProf_valid Lq hL20 tag key domain hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
    hPk0 check0 paths digest bndCheck

private theorem zero_lt_26 : 0 < 26 := by decide

local notation "BpS" => shdP_rtBlk Lq hL20 tag hPk0
local notation "PXkS" => cbBndPcs (St := ClsStmt Hdr) tag 38
local notation "CinS" =>
  epTokenCommit (St := ClsStmt Hdr) 6 1 shdP_epPos_injective shdP_epPlace
    (epxMsg 6 1 shdP_epPlace shdP_epPos) (epxMsg_place 6 1 shdP_epPlace shdP_epPos shdP_epPlace_injective)
    EpxSalt.pads EpxSalt.salts EpxSalt.paths ClsStmt.inRoot tag

local notation "RkDS" =>
  shdRkD U hbij tag dPos0 Lq (le64_of_le20 hL20) hL20 key domain hs hL 26 zero_lt_26
    (RnS).pf (shdP_clampPk Pk0) (shdP_shieldRunAtD_clamp hPk0) ViS FoS
    (ViS).lay.logupSumClaim (FoS 0).lay.logupSumClaim
    (rcIncPart ViS 256 256) (rcOutcPart (FoS 0) 256 256 1)
    15 8 14 (IinS).pA.rows (IinS).pH.rows (IinS).pX.rows (IinS).nA (IinS).nH (IinS).nIn (IinS).nOut
    (OoutS).pA.rows (OoutS).pH.rows (OoutS).pX.rows (OoutS).nA (OoutS).nH (OoutS).nIn
    (fun j => (BpS j).S) (fun j => (BpS j).pA.rows) (fun j => (BpS j).pH.rows)
    (fun j => (BpS j).nA) (fun j => (BpS j).nH) (fun j => (BpS j).nIn) (fun j => (BpS j).nOut)
    (fun j => (PXkS j).rows) P0inS P0outS csIOI csIOO eI eO ΛI ΛO

local notation "ProtoS" =>
  classifyProtocolUExecP Rp Lq 26 preA preB (clsStart domain key hw)
    (fun _ => ViS) (fun _ => rcIncGeom ViS 28)
    (d12aBlockProf (shdP_clampPk Pk0) (shdP_sgeom Hdr (shdP_clampPk Pk0)) (vdChk check0) paths digest
      (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38))
    (fun _ v => FoS v) (fun _ => rcOutcGeom (FoS 0) 28)
    P (CinS) (le64_of_le20 hL20) (shdP_hr tag hL20) (shdP_honestIn (Hdr := Hdr) tag epBase).base 768

local notation "BadEvS" => fun A G =>
  EvXR tag Lq (le64_of_le20 hL20) (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26
    (rxCoreOf (shdP_sgeom Hdr (shdP_clampPk Pk0)))
    (rxVx tag Lq (le64_of_le20 hL20) (fun _ => rcIncGeom ViS 28) (fun _ => rcOutcGeom (FoS 0) 28)
      (shdP_sgeom Hdr (shdP_clampPk Pk0)) 26)
    (rxRoots (fun _ => rcIncGeom ViS 28) (fun _ => rcOutcGeom (FoS 0) 28)
      (shdP_sgeom Hdr (shdP_clampPk Pk0)) 26) A G
  ∨ exEvIn tag Lq (le64_of_le20 hL20) key domain hs hL
      (fun _ => rcIncGeom ViS 28) (fun _ => rcOutcGeom (FoS 0) 28)
      (shdP_sgeom Hdr (shdP_clampPk Pk0)) 26 A G

/-- **CONCRETE SHIELDSTRAL T128 R13 VERIFIER & SCHEDULE INSTANTIATION (`L67`)** on top of
`sshC_productionReadyL_epP_pinsHd`:
eliminates 96 structural/verifier/schedule/opening/stage-shape/layout binders (including `hLay`) while leaving the 19
stage semantic / IO / doom / LogUp obligations untouched for clean composition with `L63` + `hLuStg`. -/
theorem sshC_productionReadyL_epP_shieldInst
    (hU : U ^ 2 = algebraMap GF K 7)
    {ι : Type} [Fintype ι]
    (site : (shieldS0.Tok → ℕ) → ι → Site (QB Lq) Coins K)
    (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpenP Rp Lq
      (shdP_runV tag key domain hw preA preB Rp embDigest embFold bInRow wDigest bOutRow
        (shdP_clampPk Pk0) check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn tag epBase) U site kOf δOf εzk)
    (hzk : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 → εzk q R' ≤ εzkTarget q R')
    (hIOI : ∀ v (cm : Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOI v cm { z with value := a } = csIOI v cm z)
    (hIOO : ∀ v (cm : Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOO v cm { z with value := a } = csIOO v cm z)
    (hIOlI : VwLoc ((RnS).pf.off 0 + 5 + (7 + 15)) csIOI)
    (hIOlO : VwLoc ((RnS).pf.off 27 + 2 + (7 + 2)) csIOO)
    (hCsIO : StgCsIODeg U hbij 8 (IncPrivIO0 (shdP_incPub Rp embDigest embFold)) csIOI
      ∧ StgCsIODeg U hbij 14 (IncPrivIO1 (shdP_incPub Rp embDigest embFold)) csIOI
      ∧ ∀ b, StgCsIODeg U hbij 14 (OutcPrivIO (rcVerdict (shdP_outcPub Rp wDigest) b)) csIOO)
    (hLuStg : (stgLkSqV 15 ((RnS).pf.off 0 + 5) eI AbsS ΛI).Rbr
      ∧ eI ≤ 2 ^ 26 ∧ 15 * eI ≤ 3 * 2 ^ 26
      ∧ (stgLkSqV 2 ((RnS).pf.off 27 + 2) eO AbsS ΛO).Rbr
      ∧ eO ≤ 2 ^ 26)
    (hTrIIO : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
      (hDV : (RkDS).Valid AbsS (RnS).pf),
      (ProtoS).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BadEvS A G →
      ¬ (rtKB key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      StgClaimsIOC U key domain ViS 15 ((RnS).pf.off 0 + 5) ((RnS).pf.off 0 + (rcIncPart ViS 256 256).pre) AbsS
        (stgCsv U tag (le64_of_le20 hL20) ogStage.lc ogStage.h ogStage.Q ogStage.e (IinS).pA.rows (IinS).pH.rows
          ((RnS).pf.off 0 + 5) ((RnS).pf.off 0 + 5 + 4 + 15) csIOI)
        G (A.runLog G).2 (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)))
    (hTrOIO : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
      (hDV : (RkDS).Valid AbsS (RnS).pf),
      (ProtoS).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BadEvS A G →
      ¬ (rtKB key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      StgClaimsIOCO U key domain (FoS (A.run G).1.verdict).bp ((RnS).pf.off 27 + 2)
        ((RnS).pf.off 27 + (rcOutcPart (FoS 0) 256 256 1).pre) AbsS
        (stgCsv U tag (le64_of_le20 hL20) ogStage.lc ogStage.h ogStage.Q ogStage.e (OoutS).pA.rows (OoutS).pH.rows
          ((RnS).pf.off 27 + 2) ((RnS).pf.off 27 + 2 + 4 + 2) csIOO)
        G (A.runLog G).2 (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)))
    (hLI_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
      (hDV : (RkDS).Valid AbsS (RnS).pf),
      (ProtoS).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BadEvS A G →
      ¬ (rtKB key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      StgLkAtV U key domain (fun ch => (ViS).bp (incCtx (ViS).pub ch)) 15
        ((RnS).pf.off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) AbsS ΛI G (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)))
    (hLO_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
      (hDV : (RkDS).Valid AbsS (RnS).pf),
      (ProtoS).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BadEvS A G →
      ¬ (rtKB key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RnS).pf (RnS).rd hL64 HvS U hbij RkDS hDV).Dm (Rp.blks.length + 2) (A.runLog G).2
        (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)) →
      StgLkAtV U key domain (fun _ => (FoS (A.run G).1.verdict).bp) 2 ((RnS).pf.off 27 + 2) OutcV.bga AbsS ΛO G
        (A.runLog G).2 (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)))
    (hdinS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (ProtoS).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BadEvS A G →
      ¬ InOkP Rp ((epxE (CinS)
        (epxMk 6 1 shdP_epPlace shdP_epPos_injective shdP_epPlace_injective ClsStmt.inRoot tag) shdP_epPos
        (epxOps tag Lq (le64_of_le20 hL20) key domain hs hL abRdIn 11 6 (N := 2 ^ 11))
        (epxBndE U tag Lq (le64_of_le20 hL20) key domain hs hL (RnS).pf (RnS).rd RkDS dPos0 E0))
        (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      StgDoomAtV U key domain P0inS (fun ch => (ViS).bp (incCtx (ViS).pub ch)) 15
        ((RnS).pf.off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) stgHostIn AbsS
        (stgFstIC U hbij tag (le64_of_le20 hL20) P0inS (vdWin ViS)
          ((RnS).pf.off 0 + (rcIncPart ViS 256 256).pre) ((RnS).pf.off 0 + 5)
          15 ogStage.lc ogStage.h ogStage.Q ogStage.e (IinS).pA.rows (IinS).pH.rows (rcIncPart ViS 256 256).S csIOI)
        (sshΦIC U hbij tag (le64_of_le20 hL20) P0inS ViS
          ((RnS).pf.off 0 + (rcIncPart ViS 256 256).pre) ((RnS).pf.off 0 + 5)
          15 ogStage.lc ogStage.h ogStage.Q ogStage.e (IinS).pA.rows (IinS).pH.rows csIOI)
        sshDgI eI ΛI G (A.runLog G).2 (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)))
    (hdoutS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (ProtoS).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BadEvS A G →
      ¬ OutOkP Rp ((ProtoS).ypub (A.runLog G).1.1)
        ((epxE (CinS)
          (epxMk 6 1 shdP_epPlace shdP_epPos_injective shdP_epPlace_injective ClsStmt.inRoot tag) shdP_epPos
          (epxOps tag Lq (le64_of_le20 hL20) key domain hs hL abRdIn 11 6 (N := 2 ^ 11))
          (epxBndE U tag Lq (le64_of_le20 hL20) key domain hs hL (RnS).pf (RnS).rd RkDS dPos0 E0))
          (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      StgDoomAtV U key domain P0outS (fun _ => (FoS (A.run G).1.verdict).bp) 2 ((RnS).pf.off 27 + 2) OutcV.bga
        (stgHostOut P0outS) AbsS
        (stgFstO U hbij tag (le64_of_le20 hL20) P0outS (vdWout FoS)
          ((RnS).pf.off 27 + (rcOutcPart (FoS 0) 256 256 1).pre) ((RnS).pf.off 27 + 2)
          ogStage.lc ogStage.h ogStage.Q ogStage.e (OoutS).pA.rows (OoutS).pH.rows (rcOutcPart (FoS 0) 256 256 1).S csIOO)
        (sshΦO U hbij tag (le64_of_le20 hL20) P0outS FoS
          ((RnS).pf.off 27 + (rcOutcPart (FoS 0) 256 256 1).pre) ((RnS).pf.off 27 + 2)
          ogStage.lc ogStage.h ogStage.Q ogStage.e (OoutS).pA.rows (OoutS).pH.rows csIOO)
        sshDgO eO ΛO G (A.runLog G).2 (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G)))
    (hdzW : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (ProtoS).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BadEvS A G →
      (∃ (k : Fin 1) (i : Fin (2 ^ 8)), (ViS).pub.tokens ≤ k.val * 2 ^ 8 + i.val
        ∧ k.val * 2 ^ 8 + i.val < (ViS).pub.inEpWords
        ∧ ((CinS).decodeIn
          ((epxOps tag Lq (le64_of_le20 hL20) key domain hs hL abRdIn 11 6 (N := 2 ^ 11))
            (A.runLog G).2 (A.runLog G).1.1) 768).1 ((CinS).place k) i ≠ 0) →
      StgDoomAtV U key domain P0inS (fun ch => (ViS).bp (incCtx (ViS).pub ch)) 15
        ((RnS).pf.off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) stgHostIn AbsS
        (stgFstIC U hbij tag (le64_of_le20 hL20) P0inS (vdWin ViS)
          ((RnS).pf.off 0 + (rcIncPart ViS 256 256).pre) ((RnS).pf.off 0 + 5)
          15 ogStage.lc ogStage.h ogStage.Q ogStage.e (IinS).pA.rows (IinS).pH.rows (rcIncPart ViS 256 256).S csIOI)
        (sshΦIC U hbij tag (le64_of_le20 hL20) P0inS ViS
          ((RnS).pf.off 0 + (rcIncPart ViS 256 256).pre) ((RnS).pf.off 0 + 5)
          15 ogStage.lc ogStage.h ogStage.Q ogStage.e (IinS).pA.rows (IinS).pH.rows csIOI)
        sshDgI eI ΛI G (A.runLog G).2 (rtTr key domain Lq (RnS).pf (RnS).rd G (A.run G))) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp) ProtoS
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget := by
  have hin_lay := shdP_incLay_nums Rp embDigest embFold
  have hout_lay := shdP_outcLay_nums Rp wDigest
  have hin_logs := shdP_incPub_logs Rp embDigest embFold
  have hin_S := shdP_incPart_S tag Rp embDigest embFold bInRow
  have hout_S := shdP_outcPart_S tag Rp wDigest bOutRow
  have hfIA : 8 * (IinS).pA.rows ≤ Lq := by
    change 8 * (incLay (shdP_incPub Rp embDigest embFold) 14).aRows ≤ Lq
    rw [hin_lay.1]; omega
  have hfIH : 8 * (IinS).pH.rows ≤ Lq := by
    change 8 * (incLay (shdP_incPub Rp embDigest embFold) 14).hRows ≤ Lq
    rw [hin_lay.2.1]; omega
  have hfOA : 8 * (OoutS).pA.rows ≤ Lq := by
    change 8 * (outcLay (shdP_outcPub Rp wDigest) 14).aRows ≤ Lq
    rw [hout_lay.1]; omega
  have hfOH : 8 * (OoutS).pH.rows ≤ Lq := by
    change 8 * (outcLay (shdP_outcPub Rp wDigest) 14).hRows ≤ Lq
    rw [hout_lay.2.1]; omega
  have hfIM : 8 * (2 * (rcIncPart ViS 256 256).S + 4) ≤ Lq := by
    rw [hin_S]; omega
  have hfOM : 8 * (2 * (rcOutcPart (FoS 0) 256 256 1).S + 4) ≤ Lq := by
    rw [hout_S]; omega
  exact RunShapeP.sshC_productionReadyL_epP_pinsHd
    (Hdr := Hdr) (Coins := Coins) (K := K)
    (Rr := 6) (dR := 1) (pos := shdP_epPos) (hpos := shdP_epPos_injective)
    (place := shdP_epPlace) (hplace := shdP_epPlace_injective)
    (tag := tag) (dPos0 := dPos0)
    (Rp := Rp) (Lq := Lq) (Lb := 26) (hL20 := hL20)
    (preA := preA) (preB := preB) (start := clsStart domain key hw)
    (inc := fun _ => ViS) (incG := fun _ => rcIncGeom ViS 28)
    (Pk := shdP_clampPk Pk0) (sgeom := shdP_sgeom Hdr (shdP_clampPk Pk0))
    (check := vdChk check0) (paths := paths) (digest := digest)
    (bRows := fun _ => 38) (bLogN := fun _ => 14)
    (bndCheck := bndCheck) (bndOpen := cbBndOpen tag 38)
    (outc := fun _ v => FoS v) (outcG := fun _ => rcOutcGeom (FoS 0) 28)
    (P := P) (h64 := le64_of_le20 hL20) (hr := shdP_hr tag hL20)
    (hon := shdP_honestIn tag epBase) (U := U) (hbij := hbij)
    (key := key) (domain := domain) (hs := hs) (hL := hL) (hL64 := hL64)
    (Rn := RnS) (hv := HvS)
    (hw := hw)
    (hRn := shdP_rtRun_hdr Lq hL20 tag key domain hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
      hPk0 check0 paths digest bndCheck)
    (site := site) (kOf := kOf) (δOf := δOf) (E0 := E0)
    (O := O) (hU := hU)
    (cx0 := rcCx0)
    (pin := rcIncPart ViS 256 256)
    (pout := rcOutcPart (FoS 0) 256 256 1)
    (Iin := IinS) (Oout := OoutS)
    (bp := shdP_rtBlk Lq hL20 tag hPk0)
    (wXk := fun _ => 1 + 1 + 38) (gXk := fun _ => 2) (mXk := fun _ => 64)
    (hσ := shdP_rtRun_σs Lq hL20 tag key domain hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
      hPk0 check0 paths digest bndCheck)
    (hgeo := fun _ _ => rfl)
    (hIA := rcIncAt_pA_stage U tag Lq hL20 (shdP_incPub Rp embDigest embFold) (shdP_incGeo bInRow)
      shdP_stgDim shdP_epDim 3 256 28 (by norm_num) (by norm_num) (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num)
      (by show 2 ^ 8 + 256 ≤ 2 ^ 15; norm_num) rfl)
    (hIH := rcIncAt_pH_stage U tag Lq hL20 (shdP_incPub Rp embDigest embFold) (shdP_incGeo bInRow)
      shdP_stgDim shdP_epDim 3 256 28 (by norm_num) (by norm_num) (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num)
      (by show 2 ^ 8 + 256 ≤ 2 ^ 15; norm_num) rfl)
    (hOA := rcOutcAt_pA_stage U tag Lq hL20 (shdP_outcPub Rp wDigest) (shdP_outcGeo bOutRow)
      shdP_stgDim Exec.Block.R13.blkDim 27 2 256 28 1 (by norm_num) (by norm_num)
      (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num) (by show 2 ^ 14 + 256 ≤ 2 ^ 15; norm_num) rfl)
    (hOH := rcOutcAt_pH_stage U tag Lq hL20 (shdP_outcPub Rp wDigest) (shdP_outcGeo bOutRow)
      shdP_stgDim Exec.Block.R13.blkDim 27 2 256 28 1 (by norm_num) (by norm_num)
      (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num) (by show 2 ^ 14 + 256 ≤ 2 ^ 15; norm_num) rfl)
    (hBA := shdP_rtBlk_pA_r13 U Lq hL20 tag hPk0)
    (hBH := shdP_rtBlk_pH_r13 U Lq hL20 tag hPk0)
    (htI := rfl) (htO := rfl) (htB := fun _ => rfl)
    (hfIA := hfIA) (hfIH := hfIH) (hfOA := hfOA) (hfOH := hfOH)
    (hfBA := fun _ => by change 8 * 4577 ≤ Lq; omega)
    (hfBH := fun _ => by change 8 * 4390 ≤ Lq; omega)
    (hfIM := hfIM)
    (hfOM := hfOM)
    (hfBM := fun _ => by change 8 * (2 * 23 + 4) ≤ Lq; omega)
    (hbpRows := fun _ _ => ⟨rfl, rfl⟩)
    (Vi := ViS) (F := FoS)
    (hinc := fun _ => rfl) (houtc := fun _ _ => rfl)
    (hchk := vdChk_le check0)
    (hLb1 := zero_lt_26)
    (lscIn := (ViS).lay.logupSumClaim)
    (lscOut := (FoS 0).lay.logupSumClaim)
    (mIn := 15) (kIn := 8) (kOut := 14)
    (hlscIn := fun _ => rfl)
    (hlscOut := fun _ v => by
      show (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).logupSumClaim
        = (outcLay (rcVerdict (shdP_outcPub Rp wDigest) 0) 14).logupSumClaim
      rw [rc_outcLay_verdict, rc_outcLay_verdict])
    (hmIn := fun _ => hin_logs.2.2.2.2)
    (hkIn := fun _ => hin_lay.2.2.1)
    (hkOut := fun _ v => by
      show (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).nFunctionals = 14
      rw [rc_outcLay_verdict]
      exact hout_lay.2.2.1)
    (pXk := cbBndPcs tag 38)
    (hXk := cbBndPcs_r13 U tag 38)
    (hwXk := fun _ _ => rfl) (hmXk := fun _ _ => rfl)
    (hfitXk := fun _ => by change 8 * 38 ≤ Lq; omega)
    (hwX0 := rfl) (hmX0 := rfl)
    (hOX := rcOutcAt_pX_bnd_r13 U tag Lq hL20 (shdP_outcPub Rp wDigest) (shdP_outcGeo bOutRow)
      shdP_stgDim Exec.Block.R13.blkDim 27 2 256 28 1 (by norm_num) (by norm_num)
      (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num) (by show 2 ^ 14 + 256 ≤ 2 ^ 15; norm_num) rfl)
    (hwXo := fun _ _ => rfl)
    (hfitXo := by change 8 * 38 ≤ Lq; omega)
    (hXep := rcIncAt_pX_ep U tag Lq hL20 (shdP_incPub Rp embDigest embFold) (shdP_incGeo bInRow)
      shdP_stgDim shdP_epDim 2 256 28 (by norm_num) (by norm_num)
      (by show 2 ^ 12 + 256 ≤ 2 ^ 15; norm_num) (by show 2 ^ 8 + 256 ≤ 2 ^ 15; norm_num) rfl)
    (hfitX := by change 8 * 6 ≤ Lq; omega)
    (hRr := rfl)
    (hL81 := by omega)
    (hPkD := shdP_shieldRunAtD_clamp hPk0)
    (P0in := P0inS) (P0out := P0outS)
    (csIOI := csIOI) (csIOO := csIOO)
    (hIOI := hIOI) (hIOO := hIOO)
    (hNin := shdP_hNin tag Rp embDigest embFold bInRow)
    (hNout := shdP_hNout tag Rp wDigest bOutRow)
    (hN64I := shdP_hN64I tag Rp embDigest embFold bInRow)
    (hN64O := shdP_hN64O tag Rp wDigest bOutRow)
    (hIOlI := hIOlI) (hIOlO := hIOlO)
    (eI := eI) (eO := eO) (ΛI := ΛI) (ΛO := ΛO)
    (hPin := shdP_hPin tag Rp embDigest embFold bInRow)
    (hPout := shdP_hPout tag Rp wDigest bOutRow)
    (hSm := ⟨by rw [hin_S]; norm_num, by rw [hout_S]; norm_num⟩)
    (hlcStg := ⟨by show 12 ≤ 12; omega, fun _ => by show 12 ≤ 12; omega⟩)
    (hCsIO := hCsIO) (hLuStg := hLuStg)
    (hTrIIO := hTrIIO) (hTrOIO := hTrOIO)
    (hLI_stg := hLI_stg) (hLO_stg := hLO_stg)
    (hdinS := hdinS) (hdoutS := hdoutS)
    (hLay := shdP_stgInLay_incPub Rp embDigest embFold) (hdzW := hdzW) (hzk := hzk)

end ShieldTop

end TopInst

end ZK60.ProtocolClassify
