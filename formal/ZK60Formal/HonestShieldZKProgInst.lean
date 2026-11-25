/-
D63 lane L69, Milestone B Part 3 (`HonestShieldZKProgInst.lean`):
closes the final Track-1 ZK witness (`shdP_zkProgWitness : ShdZKProgWitness`) and the
complete unconditional concrete-hook `ProductionReadyL` theorem
(`shdP_honest_productionReadyL_complete`) for the 28-segment Shieldstral T128 R13 honest prover
(`shdP_honestRunP_zk` / `shdP_runFixedProg`) over `ShdCoins`:

1. **Arithmetic, audit, & `hdH` / `hab` / `codeFuns` bridges**:
   - Generic `hdH_of_audit_logupSum` discharging `hdH` for `IN-C`, all `26` R13 blocks, and `OUT-C`
     directly from `auditClaims_h_bijection` + `shdP_inc_logupSumClaim_true` / `blk_logupSumClaim_true`
     / `shdP_outc_logupSumClaim_true`.
   - `inc_te_hab`: proves `TE` site-pair linear independence from `incDefIO` + `tokenEpHdrOk` + `shdP_sitePair_linInd`.
   - Unified per-segment slot arithmetic (`incSlot_arith`, `blkSlot_arith`, `outcSlot_arith`) and
     pure `ShdL1View` claim-value lookup (`lookupClaimVal`, `slotPolyK_at_vecK_eq_fromView`,
     `blkSlotPolyK_at_vecK_eq_fromView`).
2. **Whole-run active trace extraction (`IncSegTrace`, `BlkSegTrace`, `OutcSegTrace`, `RunTrace`)**:
   - Extracts all 84 PCS opening audits, all 28 `M` openings, and all 28 segment slot traces at any
     active `(y : AdmAt Rp verdict, c : ShdCoins)`, proving all `dfs`, claim `.parts`, and
     `MaskFunctional.terms` agree with the `(verdict, v)`-only reference `xRef`.
3. **Concrete Level-1 (`shdP_D1`), Level-2 (`shdP_D2`), and Receipt Reconstruction (`shdP_Rc`, `shdP_hout`)**:
   - Instantiates all 84 PCS tables in `ShdL1Data`, all 28 segments in `ShdSegL2Data`, and proves
     exact byte-level equality `PProg.outOf (shdP_runFixedProg ...) v = shdP_Rc ... (D1.view, D2.view)`.
4. **Master `shdP_zkProgWitness` & `shdP_honest_productionReadyL_complete`**:
   - Assembles `ShdZKProgWitness` on `shdP_honestRunP_zk` (`π := id`, `hπ := shdCoins_hpi`, wrapping
     `shdP_zkCountWitness`) and discharges `ProductionReadyL` via `shdP_honest_productionReadyL_hooks_zk`
     with ZERO open `W_zk` or hook premises.

Only standard Lean/Mathlib foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldZKProgSegExt

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


/-! ## 3. Concrete Level-1 (`shdP_D1`), Level-2 (`shdP_D2`), and Receipt Reconstruction (`shdP_Rc`, `shdP_hout`) -/

section Level1AndLevel2Inst

attribute [local irreducible] blkBase outcBase blkSegFixedLen outcSegFixedLen incSegFixedLen levelsOfV posTagOfV

/-- Pure `vf`-only squeeze vector (`64` digests) at `base`. -/
def sqOf (vf : ℕ → Dig) (base : ℕ) : List Dig :=
  (List.range 64).map (fun j => vf (base + j))

/-- Pure `vf`-only PCS / `M`-table column index list (`256` entries in `[0, 2^depth)`). -/
def idxsOf (depth : ℕ) (vf : ℕ → Dig) (base : ℕ) : List ℕ :=
  idxOf (2 ^ depth) 256 (sqOf vf base)

theorem idxsOf_length (depth : ℕ) (vf : ℕ → Dig) (base : ℕ) :
    (idxsOf depth vf base).length = 256 := by
  simp [idxsOf, sqOf, idxOf_length]

theorem idxsOf_lt (depth : ℕ) (vf : ℕ → Dig) (base : ℕ) :
    ∀ j ∈ idxsOf depth vf base, j < 2 ^ depth :=
  idxOf_lt (2 ^ depth) 256 (Nat.two_pow_pos depth) _

theorem idxsOf_def (depth : ℕ) (vf : ℕ → Dig) (base : ℕ) :
    idxsOf depth vf base = idxOf (2 ^ depth) 256 ((List.range 64).map (fun j => vf (base + j))) := rfl

theorem idxsOf_mDom (vf : ℕ → Dig) (base : ℕ) :
    idxOf mDom mQ ((List.range 64).map (fun j => vf (base + j))) = idxsOf 12 vf base := rfl

theorem idxsOf_stgPrm (vf : ℕ → Dig) (base : ℕ) :
    idxOf shdP_stgPrm.nn shdP_stgPrm.nQ ((List.range 64).map (fun j => vf (base + j))) = idxsOf 14 vf base := rfl

theorem idxsOf_epPrm (vf : ℕ → Dig) (base : ℕ) :
    idxOf shdP_epPrm.nn shdP_epPrm.nQ ((List.range 64).map (fun j => vf (base + j))) = idxsOf 11 vf base := rfl

theorem idxsOf_r13Prm (vf : ℕ → Dig) (base : ℕ) :
    idxOf Exec.R13.r13Prm.nn Exec.R13.r13Prm.nQ ((List.range 64).map (fun j => vf (base + j))) = idxsOf 16 vf base := rfl

attribute [irreducible] idxsOf

/-- Named pure-`vf` base indices for all opening audits and `M`-openings across all 28 segments. -/
def incSlBase : ℕ := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3
def incMoBase : ℕ := incSlBase + 167
def incAoBase : ℕ := incMoBase + 77
def incHoBase : ℕ := incAoBase + 112
def incEoBase : ℕ := incHoBase + 149

def blkSlBase (k : Fin 26) : ℕ := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
def blkMoBase (k : Fin 26) : ℕ := blkSlBase k + 1283
def blkAoBase (k : Fin 26) : ℕ := blkMoBase k + 115
def blkHoBase (k : Fin 26) : ℕ := blkAoBase k + 4824
def blkBoBase (k : Fin 26) : ℕ := blkHoBase k + 4518

noncomputable def outcSlBase : ℕ := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
noncomputable def outcMoBase : ℕ := outcSlBase + 290
noncomputable def outcAoBase : ℕ := outcMoBase + 85
noncomputable def outcHoBase : ℕ := outcAoBase + 186
noncomputable def outcBoBase : ℕ := outcHoBase + 118

/-- Pure `vf`-only deduplicated column opening counts across all 84 PCS tables. -/
noncomputable def shdP_ks (vf : ℕ → Dig) : ShdL1OpenK where
  te := (nodupCols (idxsOf 11 vf (incEoBase + 9))).length
  bnd k :=
    if h : k.val < 26 then (nodupCols (idxsOf 16 vf (blkBoBase ⟨k.val, h⟩ + 43))).length
    else (nodupCols (idxsOf 16 vf (outcBoBase + 43))).length
  kA s :=
    if h0 : s.val = 0 then (nodupCols (idxsOf 14 vf (incAoBase + 48))).length
    else if h27 : s.val = 27 then (nodupCols (idxsOf 14 vf (outcAoBase + 122))).length
    else (nodupCols (idxsOf 16 vf (blkAoBase ⟨s.val - 1, by omega⟩ + 4760))).length
  kH s :=
    if h0 : s.val = 0 then (nodupCols (idxsOf 14 vf (incHoBase + 85))).length
    else if h27 : s.val = 27 then (nodupCols (idxsOf 14 vf (outcHoBase + 54))).length
    else (nodupCols (idxsOf 16 vf (blkHoBase ⟨s.val - 1, by omega⟩ + 4454))).length

/-- Pure `vf`-only deduplicated column opening counts across all 28 `M` tables. -/
noncomputable def shdP_qs (vf : ℕ → Dig) (s : Fin 28) : ℕ :=
  if h0 : s.val = 0 then (nodupCols (idxsOf 12 vf (incMoBase + 13))).length
  else if h27 : s.val = 27 then (nodupCols (idxsOf 12 vf (outcMoBase + 21))).length
  else (nodupCols (idxsOf 12 vf (blkMoBase ⟨s.val - 1, by omega⟩ + 51))).length

private theorem shdP_L1Spec_ah_blk (k : Fin 26) :
    shdP_L1Spec.ah ⟨k.val + 1, by omega⟩ = ⟨shdP_blkASpec, shdP_blkHSpec⟩ := by
  dsimp only [shdP_L1Spec]
  rw [ite_eq_right (by omega), ite_eq_right (by omega)]

private theorem shdP_ks_te (vf : ℕ → Dig) :
    (shdP_ks vf).te = (nodupCols (idxsOf 11 vf (incEoBase + 9))).length := by
  unfold shdP_ks; rfl

private theorem shdP_ks_kA_zero (vf : ℕ → Dig) :
    (shdP_ks vf).kA ⟨0, by decide⟩ = (nodupCols (idxsOf 14 vf (incAoBase + 48))).length := by
  unfold shdP_ks; dsimp only; exact dite_eq_left rfl

private theorem shdP_ks_kH_zero (vf : ℕ → Dig) :
    (shdP_ks vf).kH ⟨0, by decide⟩ = (nodupCols (idxsOf 14 vf (incHoBase + 85))).length := by
  unfold shdP_ks; dsimp only; exact dite_eq_left rfl

private theorem shdP_ks_kA_outc (vf : ℕ → Dig) :
    (shdP_ks vf).kA ⟨27, by decide⟩ = (nodupCols (idxsOf 14 vf (outcAoBase + 122))).length := by
  unfold shdP_ks; dsimp only; rw [dite_eq_right (by decide), dite_eq_left rfl]

private theorem shdP_ks_kH_outc (vf : ℕ → Dig) :
    (shdP_ks vf).kH ⟨27, by decide⟩ = (nodupCols (idxsOf 14 vf (outcHoBase + 54))).length := by
  unfold shdP_ks; dsimp only; rw [dite_eq_right (by decide), dite_eq_left rfl]

private theorem shdP_ks_kA_blk (vf : ℕ → Dig) (k : Fin 26) :
    (shdP_ks vf).kA ⟨k.val + 1, by omega⟩ = (nodupCols (idxsOf 16 vf (blkAoBase k + 4760))).length := by
  unfold shdP_ks; dsimp only; rw [dite_eq_right (by omega), dite_eq_right (by omega)]
  exact congrArg (fun j : Fin 26 => (nodupCols (idxsOf 16 vf (blkAoBase j + 4760))).length) (Fin.ext (Nat.add_sub_cancel k.val 1))

private theorem shdP_ks_kH_blk (vf : ℕ → Dig) (k : Fin 26) :
    (shdP_ks vf).kH ⟨k.val + 1, by omega⟩ = (nodupCols (idxsOf 16 vf (blkHoBase k + 4454))).length := by
  unfold shdP_ks; dsimp only; rw [dite_eq_right (by omega), dite_eq_right (by omega)]
  exact congrArg (fun j : Fin 26 => (nodupCols (idxsOf 16 vf (blkHoBase j + 4454))).length) (Fin.ext (Nat.add_sub_cancel k.val 1))

private theorem shdP_qs_zero (vf : ℕ → Dig) :
    shdP_qs vf ⟨0, by decide⟩ = (nodupCols (idxsOf 12 vf (incMoBase + 13))).length := by
  unfold shdP_qs; dsimp only; exact dite_eq_left rfl

private theorem shdP_qs_outc (vf : ℕ → Dig) :
    shdP_qs vf ⟨27, by decide⟩ = (nodupCols (idxsOf 12 vf (outcMoBase + 21))).length := by
  unfold shdP_qs; dsimp only; rw [dite_eq_right (by decide), dite_eq_left rfl]

private theorem shdP_qs_blk (vf : ℕ → Dig) (k : Fin 26) :
    shdP_qs vf ⟨k.val + 1, by omega⟩ = (nodupCols (idxsOf 12 vf (blkMoBase k + 51))).length := by
  unfold shdP_qs; dsimp only; rw [dite_eq_right (by omega), dite_eq_right (by omega)]
  exact congrArg (fun j : Fin 26 => (nodupCols (idxsOf 12 vf (blkMoBase j + 51))).length) (Fin.ext (Nat.add_sub_cancel k.val 1))

private theorem rowAt_inl {K : Type} [Zero K] {n Q : ℕ} (v : Hiding.Row K n Q) (col : Fin n) :
    rowAt v col.val = v (.inl col) := by
  unfold rowAt; exact dite_eq_left col.isLt

private theorem rowAt_mkStdSpec_inl {d lr m₀ g : ℕ}
    (v : Hiding.Row shdP_K (mkStdSpec d lr m₀ g).n (mkStdSpec d lr m₀ g).Q) (col : Fin (2 ^ d)) :
    rowAt v col.val = v (.inl col) := by
  unfold rowAt; exact dite_eq_left col.isLt

private theorem rowAt_teSpec_inl
    (v : Hiding.Row shdP_K shdP_teSpec.n shdP_teSpec.Q) (col : Fin (2 ^ 8)) :
    rowAt v col.val = v (.inl col) := by
  unfold rowAt; exact dite_eq_left col.isLt

private theorem shdSegKind_inc (t : Fin (shdSegNS ⟨0, by decide⟩)) :
    shdSegKind ⟨0, by decide⟩ t = incKind t := by
  unfold shdSegKind; rw [dite_eq_left rfl]; rfl

private theorem shdSegKind_outc (t : Fin (shdSegNS ⟨27, by decide⟩)) :
    shdSegKind ⟨27, by decide⟩ t = outcKind t := by
  unfold shdSegKind; rw [dite_eq_right (by decide), dite_eq_left rfl]; rfl

private theorem shdSegHosts_outc (hc : ShdHostCoeffs shdP_K) (t : Fin (shdSegNS ⟨27, by decide⟩)) :
    shdSegHosts hc ⟨27, by decide⟩ t = outcHosts hc.νOut₂ hc.νOut₄ t := by
  unfold shdSegHosts; rw [dite_eq_right (by decide), dite_eq_left rfl]
  exact List.map_id _

private def shdSegL2DataCast {Dt C V : Type} {view : Dt → C → V} {ns : ℕ}
    {kind : Fin ns → Kind} {hosts : Fin ns → List (Fin ns × shdP_K)}
    {S : SegL2Spec ns} {q₁ q₂ : ℕ} (hq : q₁ = q₂)
    (D : ShdSegL2Data GF shdP_K Dt C V view kind hosts shdP_U (7 : GF) S q₁) :
    ShdSegL2Data GF shdP_K Dt C V view kind hosts shdP_U (7 : GF) S q₂ := by
  subst hq; exact D

private theorem shdSegL2DataCast_view_fst {Dt C V : Type} {view : Dt → C → V} {ns : ℕ}
    {kind : Fin ns → Kind} {hosts : Fin ns → List (Fin ns × shdP_K)}
    {S : SegL2Spec ns} {q₁ q₂ : ℕ} (hq : q₁ = q₂)
    (D : ShdSegL2Data GF shdP_K Dt C V view kind hosts shdP_U (7 : GF) S q₁)
    (y : Dt) (c1 : C) (c2 : SegL2Coins GF shdP_K S) :
    ((shdSegL2DataCast hq D).view y c1 c2).1.1 = (D.view y c1 c2).1.1 := by
  subst hq; rfl

private theorem shdSegL2DataCast_view_mOpen {Dt C V : Type} {view : Dt → C → V} {ns : ℕ}
    {kind : Fin ns → Kind} {hosts : Fin ns → List (Fin ns × shdP_K)}
    {S : SegL2Spec ns} {q₁ q₂ : ℕ} (hq : q₁ = q₂) (hq' : q₂ = q₁)
    (D : ShdSegL2Data GF shdP_K Dt C V view kind hosts shdP_U (7 : GF) S q₁)
    (y : Dt) (c1 : C) (c2 : SegL2Coins GF shdP_K S) :
    (hq' ▸ ((shdSegL2DataCast hq D).view y c1 c2).1.2) = (D.view y c1 c2).1.2 := by
  subst hq; cases hq'; rfl

private theorem shdSegL2DataCast_view_snd {Dt C V : Type} {view : Dt → C → V} {ns : ℕ}
    {kind : Fin ns → Kind} {hosts : Fin ns → List (Fin ns × shdP_K)}
    {S : SegL2Spec ns} {q₁ q₂ : ℕ} (hq : q₁ = q₂)
    (D : ShdSegL2Data GF shdP_K Dt C V view kind hosts shdP_U (7 : GF) S q₁)
    (y : Dt) (c1 : C) (c2 : SegL2Coins GF shdP_K S) :
    ((shdSegL2DataCast hq D).view y c1 c2).2 = (D.view y c1 c2).2 := by
  subst hq; rfl

/-- Pure `(verdict, vf)`-only host-slot coefficients extracted from `FRef`. -/
noncomputable def shdP_hc {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) : ShdHostCoeffs shdP_K where
  νBlk k t u := ((((FRef.blkT k).dfs t).hosted.find? (fun p => p.1 == u)).map (fun p => p.2.toK shdP_U)).getD 0
  νOut₂ := ((FRef.outcT.recs[2]'(by rw [FRef.outcT.recs_len]; omega)).draws.getD 5 Fp2.zero).toK shdP_U
  νOut₄ := ((FRef.outcT.recs[4]'(by rw [FRef.outcT.recs_len]; omega)).draws.getD 14 Fp2.zero).toK shdP_U

/-- Helper: extract the unique `TE` claim `c0` and its `hab` linear independence from an active `IncSegTrace`. -/
theorem incTeClaim_of_trace {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (x : shieldS0.Tok → ℕ) (c : ShdCoins) (vf : ℕ → Dig)
    (T : IncSegTrace (Hdr := Hdr) tag Rp embDigest bInRow x c vf) :
    ∃ c0 : Block.ZClaim, T.acc.claims.inp = [c0]
      ∧ tokenEpHdrOk [c0] 1 256 = true
      ∧ LinearIndependent GF ![(claimWeight 8 c0 1).toK shdP_U, (claimWeight 8 c0 2).toK shdP_U] := by
  have hhdr := T.hhdrE
  cases hcl : T.acc.claims.inp with
  | nil => rw [hcl] at hhdr; cases hhdr
  | cons c0 rest =>
    cases rest with
    | cons _ _ => rw [hcl] at hhdr; cases hhdr
    | nil =>
      rw [hcl] at hhdr
      refine ⟨c0, rfl, hhdr, ?_⟩
      have hs0 := T.slot_spec ⟨0, by decide⟩
      dsimp only at hs0
      set V := shdVi tag Rp embDigest bInRow
      set P := V.bp (incCtx V.pub T.ch)
      set dr0 := (List.range (P.draws 0)).map (fun k => challengeFp2Of (vf (incSlBase + slotsFixedLen P 0 0 + k)))
      have hdef0 : incDefIO (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow) dr0 = .ok (T.dfs ⟨0, by decide⟩) :=
        hs0.2.1
      have hok := incDefIO_ok (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow) dr0
      dsimp only at hok
      have hdfEq : T.dfs ⟨0, by decide⟩ = _ := (Except.ok.inj (hdef0.symm.trans hok))
      have hmemP : Tab.priv ⟨.inp, [(0, Fp2.one)], clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords,
          rhoC 0 (clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords), 1, 0⟩
          ∈ (T.dfs ⟨0, by decide⟩).tabs := by
        rw [hdfEq]; exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self))
      have hclMem := hs0.2.2.2.2.2.2 _ hmemP
      dsimp only at hclMem
      rw [hcl] at hclMem
      obtain ⟨z, hz, hzParts⟩ := hclMem
      have hzc : z = c0 := List.mem_singleton.mp hz
      rw [hzc] at hzParts
      exact inc_te_hab tag Rp embDigest bInRow T.ch dr0 _ _ (T.dfs ⟨0, by decide⟩) c0 hdef0 hzParts hhdr

/-- Helper: canonical `Fp2` nonzero check from `isZero = false` + `Canon`. -/
theorem fp2_toK_ne_zero_of_isZero_false {a : Fp2} (hcan : a.Canon) (hnz : a.isZero = false) :
    a.toK shdP_U ≠ 0 := by
  intro h0
  have ha0 : a = Fp2.zero :=
    Fp2.toK_injective shdP_U shdP_hU hcan Fp2.canon_zero (h0.trans (Fp2.toK_zero shdP_U).symm)
  rw [ha0] at hnz; cases hnz

/-- Helper: every entry of `shdP_incTA`, `shdP_incTH`, `shdP_outcTA`, `shdP_outcTH` columns is canonical. -/
theorem shdP_incTA_cols_canon (x : shieldS0.Tok → ℕ) (rnd : IncRand) :
    ∀ j, ∀ w ∈ (shdP_incTA x rnd).cols j, w.Canon :=
  mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _

theorem shdP_incTH_cols_canon (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2) :
    ∀ j, ∀ w ∈ (shdP_incTH Rp embDigest x rnd ch).cols j, w.Canon :=
  mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _

theorem shdP_outcTA_cols_canon (Rp : ClassifyRunPublicP shieldS0) {x : shieldS0.Tok → ℕ}
    (w : OutcWitness Rp x) (rnd : OutcRand) :
    ∀ j, ∀ v ∈ (shdP_outcTA Rp w rnd).cols j, v.Canon :=
  mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _

theorem shdP_outcTH_cols_canon (Rp : ClassifyRunPublicP shieldS0) {x : shieldS0.Tok → ℕ}
    (w : OutcWitness Rp x) (rnd : OutcRand) (g a : Fp2) :
    ∀ j, ∀ v ∈ (shdP_outcTH Rp w rnd g a).cols j, v.Canon :=
  mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _

/-- Helper: `shdP_epTable` / `shdP_incTA` / `shdP_incTH` / `shdP_bndTableAt` / `blkTA` / `blkTH` / `shdP_outcTA` / `shdP_outcTH` salts equal `c.1` projections! -/
theorem shdP_epTable_salts_eq {Hdr : Type} (tag : MTag) (x : shieldS0.Tok → ℕ) (c : ShdCoins)
    (j : ℕ) (hj : j < 2 ^ 11) :
    (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)).salts j = c.1.1.2 ⟨j, hj⟩ := by
  change extSalt c.1.1.2 j = c.1.1.2 ⟨j, hj⟩
  exact extSalt_lt c.1.1.2 hj

theorem shdP_bndTableAt_salts_eq (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (idx : Fin 27)
    (j : ℕ) (hj : j < 2 ^ 16) :
    (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 idx).salts j
      = (c.1.2.1 idx).2 ⟨j, hj⟩ := by
  rcases idx with ⟨i, hi⟩
  cases i with
  | zero => exact extSalt_lt _ hj
  | succ m => exact extSalt_lt _ hj

theorem shdP_incTA_salts_eq (x : shieldS0.Tok → ℕ) (c : ShdCoins) (j : ℕ) (hj : j < 2 ^ 14) :
    (shdP_incTA x (shdIncRndOf c)).salts j = (c.1.2.2 ⟨0, by decide⟩).2.1 ⟨j, hj⟩ :=
  extSalt_lt _ hj

theorem shdP_incTH_salts_eq (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (x : shieldS0.Tok → ℕ) (c : ShdCoins) (ch : List Fp2) (j : ℕ) (hj : j < 2 ^ 14) :
    (shdP_incTH Rp embDigest x (shdIncRndOf c) ch).salts j = (c.1.2.2 ⟨0, by decide⟩).2.2 ⟨j, hj⟩ :=
  extSalt_lt _ hj

theorem blkTA_salts_eq (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (k : Fin 26)
    (j : ℕ) (hj : j < 2 ^ 16) :
    (blkTA (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt)
      (shdBlkRndOf c k)).salts j = (blkAHCoins c k).2.1 ⟨j, hj⟩ :=
  extSalt_lt _ hj

theorem blkTH_salts_eq (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (k : Fin 26)
    (bga : Fp2 × Fp2 × Fp2) (j : ℕ) (hj : j < 2 ^ 16) :
    (blkTH (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt)
      (shdBlkRndOf c k) bga).salts j = (blkAHCoins c k).2.2 ⟨j, hj⟩ :=
  extSalt_lt _ hj

theorem shdP_outcTA_salts_eq (Rp : ClassifyRunPublicP shieldS0) (houtPub : Rp.out.Valid)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (j : ℕ) (hj : j < 2 ^ 14) :
    (shdP_outcTA Rp (outcWitness_of_adm Rp houtPub x.1 x.2) (shdOutcRndOf c)).salts j
      = (c.1.2.2 ⟨27, by decide⟩).2.1 ⟨j, hj⟩ :=
  extSalt_lt _ hj

theorem shdP_outcTH_salts_eq (Rp : ClassifyRunPublicP shieldS0) (houtPub : Rp.out.Valid)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (g a : Fp2) (j : ℕ) (hj : j < 2 ^ 14) :
    (shdP_outcTH Rp (outcWitness_of_adm Rp houtPub x.1 x.2) (shdOutcRndOf c) g a).salts j
      = (c.1.2.2 ⟨27, by decide⟩).2.2 ⟨j, hj⟩ :=
  extSalt_lt _ hj

/-- Cast helper for `PcsStdData` along opening-count equality. -/
def pcsStdDataCast {Dt : Type} {S : PcsTableSpec} {n₁ n₂ : ℕ}
    (h : n₁ = n₂) (D : PcsStdData GF shdP_K Dt S n₁) : PcsStdData GF shdP_K Dt S n₂ := by
  subst h; exact D

theorem pcsStdDataCast_view {Dt : Type} {S : PcsTableSpec} {n₁ n₂ : ℕ}
    (h₁ : n₁ = n₂) (h₂ : n₂ = n₁) (D : PcsStdData GF shdP_K Dt S n₁)
    (y : Dt) (c : PcsStdCoins GF S) :
    (h₂ ▸ ((pcsStdDataCast h₁ D).view y c)) = D.view y c := by
  subst h₁; cases h₂; rfl

theorem pcsStdDataCast_view_fst {Dt : Type} {S : PcsTableSpec} {n₁ n₂ : ℕ}
    (h : n₁ = n₂) (D : PcsStdData GF shdP_K Dt S n₁)
    (y : Dt) (c : PcsStdCoins GF S) :
    ((pcsStdDataCast h D).view y c).1.1 = (D.view y c).1.1 := by
  subst h; rfl

private theorem pcsAHData_of_audit_view_A {Dt : Type} (logN lr dA gA dH gH : ℕ) (hkl : logN + lr ≤ 31)
    (idxsA : List ℕ) (hIdxsALen : idxsA.length = 256) (hIdxsALt : ∀ j ∈ idxsA, j < 2 ^ (logN + lr))
    (clA : List Block.ZClaim) (haudA : auditClaims clA (2 ^ logN) (dA + 2 * gA + 2) (List.range' dA (2 * gA)) none (dA + 2 * gA) = .ok ())
    (proxRA : List Fp2) (hDetA : (Exec.Block.det (proxRA.getD (dA + 2 * gA) Fp2.zero) (proxRA.getD (dA + 2 * gA + 1) Fp2.zero)).v ≠ 0)
    (datA : Dt → Fin dA → Fin (2 ^ logN) → GF)
    (idxsH : List ℕ) (hIdxsHLen : idxsH.length = 256) (hIdxsHLt : ∀ j ∈ idxsH, j < 2 ^ (logN + lr))
    (clH : List Block.ZClaim) (hLenH : clH.length = gH + 1)
    (haudH : auditClaims clH (2 ^ logN) (dH + 2 + 2 * gH + 2) (List.range' (dH + 2) (2 * gH)) (some (dH, dH + 1)) (dH + 2 + 2 * gH) = .ok ())
    (proxRH : List Fp2) (hDetH : (Exec.Block.det (proxRH.getD (dH + 2 + 2 * gH) Fp2.zero) (proxRH.getD (dH + 2 + 2 * gH + 1) Fp2.zero)).v ≠ 0)
    (datH : Dt → Fin dH → Fin (2 ^ logN) → GF)
    (hdH : ∀ y, ∑ col : Fin (2 ^ logN), ∑ i : Fin dH, (claimWeight logN clH[gH] i.val).toK shdP_U * algebraMap GF shdP_K (datH y i col) = 0)
    (y : Dt) (cAH : PcsAHCoins GF ⟨mkStdSpec logN lr dA gA, mkStdSpec logN lr dH gH⟩) :
    (((pcsAHData_of_audit logN lr dA gA dH gH hkl idxsA hIdxsALen hIdxsALt clA haudA proxRA hDetA datA
      idxsH hIdxsHLen hIdxsHLt clH hLenH haudH proxRH hDetH datH hdH).view y cAH).1.1,
     ((pcsAHData_of_audit logN lr dA gA dH gH hkl idxsA hIdxsALen hIdxsALt clA haudA proxRA hDetA datA
      idxsH hIdxsHLen hIdxsHLt clH hLenH haudH proxRH hDetH datH hdH).view y cAH).2.1)
    = (stdPcsData_of_audit logN lr dA gA hkl idxsA hIdxsALen hIdxsALt clA haudA proxRA hDetA datA).view
        y (cAH.1.1, cAH.2.1) := rfl

/-- Concrete Level-1 `PcsStdData` for `TE`. -/
noncomputable def shdP_D1_te {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) :
    PcsStdData GF shdP_K (AdmAt Rp verdict) shdP_teSpec (shdP_ks vf).te :=
  let hc0 := incTeClaim_of_trace tag Rp embDigest bInRow _ default vf FRef.incT
  pcsStdDataCast (shdP_ks_te vf).symm
    (tePcsData_of_audit (idxsOf 11 vf (incEoBase + 9)) (idxsOf_length 11 vf _) (idxsOf_lt 11 vf _)
      hc0.choose hc0.choose_spec.2.2
      ((List.range 6).map fun j => challengeFp2Of (vf (incEoBase + 1 + j)))
      FRef.incT.hDetE (fun y => teDatOf y.1.1))

/-- Concrete Level-1 `PcsStdData` for boundary `k : Fin 27`. -/
noncomputable def shdP_D1_bnd {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) (k : Fin 27) :
    PcsStdData GF shdP_K (AdmAt Rp verdict) shdP_bndSpec ((shdP_ks vf).bnd k) :=
  if h : k.val < 26 then
    have hks : (shdP_ks vf).bnd k = (nodupCols (idxsOf 16 vf (blkBoBase ⟨k.val, h⟩ + 43))).length := by
      unfold shdP_ks; dsimp only; exact dite_eq_left h
    pcsStdDataCast hks.symm
      (stdPcsData_of_audit 14 2 32 2 (by norm_num)
        (idxsOf 16 vf (blkBoBase ⟨k.val, h⟩ + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
        ((FRef.crAt ⟨k.val, Nat.lt_succ_of_lt h⟩).pending ++ (FRef.blkT ⟨k.val, h⟩).acc.claims.inp)
        (FRef.blkT ⟨k.val, h⟩).haudB
        ((List.range 38).map fun j => challengeFp2Of (vf (blkBoBase ⟨k.val, h⟩ + 2 + j)))
        (FRef.blkT ⟨k.val, h⟩).hDetB
        (fun y => bndDatAt Rp hR hweights hinPub k y.1))
  else
    have hks : (shdP_ks vf).bnd k = (nodupCols (idxsOf 16 vf (outcBoBase + 43))).length := by
      unfold shdP_ks; dsimp only; exact dite_eq_right h
    pcsStdDataCast hks.symm
      (stdPcsData_of_audit 14 2 32 2 (by norm_num)
        (idxsOf 16 vf (outcBoBase + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
        ((FRef.crAt ⟨26, by omega⟩).pending ++ FRef.outcT.acc.claims.inp)
        FRef.outcT.haudB
        ((List.range 38).map fun j => challengeFp2Of (vf (outcBoBase + 2 + j)))
        FRef.outcT.hDetB
        (fun y => bndDatAt Rp hR hweights hinPub k y.1))

/-- Concrete Level-1 `PcsAHData` for Stage IN-C (`s = 0`). -/
noncomputable def shdP_D1_ah_inc {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) :
    PcsAHData GF shdP_K (AdmAt Rp verdict) ⟨shdP_incASpec, shdP_incHSpec⟩
      (nodupCols (idxsOf 14 vf (incAoBase + 48))).length (nodupCols (idxsOf 14 vf (incHoBase + 85))).length :=
  let clH := FRef.incT.acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim]
  have hclH3 : clH[3]'(by rw [FRef.incT.hLenH]; omega) = (shdVi tag Rp embDigest bInRow).lay.logupSumClaim := by
    have hlen : FRef.incT.acc.claims.h.length = 3 := by
      have := FRef.incT.hLenH; simp at this; omega
    simp only [clH, List.getElem_append_right (by omega : FRef.incT.acc.claims.h.length ≤ 3), hlen, Nat.sub_self,
      List.getElem_cons_zero]
  pcsAHData_of_audit 12 2 33 3 66 3 (by norm_num)
    (idxsOf 14 vf (incAoBase + 48)) (idxsOf_length 14 vf _) (idxsOf_lt 14 vf _)
    FRef.incT.acc.claims.a FRef.incT.haudA
    ((List.range 41).map fun j => challengeFp2Of (vf (incAoBase + 3 + j)))
    FRef.incT.hDetA (fun y => incADat y.1.1)
    (idxsOf 14 vf (incHoBase + 85)) (idxsOf_length 14 vf _) (idxsOf_lt 14 vf _)
    clH FRef.incT.hLenH FRef.incT.haudH
    ((List.range 76).map fun j => challengeFp2Of (vf (incHoBase + 4 + j)))
    FRef.incT.hDetH (fun y => incHDat Rp embDigest FRef.incT.ch y.1.1)
    (fun y => (fun c0 : ShdCoins => by
      have hshape := shdP_inc_logupSumClaim_shape tag Rp embDigest bInRow
      have hxV : ∀ t, y.1.1 t < 131072 := fun t => hV131072 ▸ adm_tok_lt y.1.2 t
      refine hdH_of_audit_logupSum (logN := 12) (incHDat Rp embDigest FRef.incT.ch y.1.1)
        (c0.1.2.2 ⟨0, by decide⟩).1.2
        (shdP_incTH Rp embDigest y.1.1 (shdIncRndOf c0) FRef.incT.ch).rows
        (shdP_incTH_rows_len Rp embDigest y.1.1 (shdIncRndOf c0) FRef.incT.ch)
        (fun r k hk => shdP_incTH_rows_eq Rp embDigest FRef.incT.ch y.1.1 c0 r k (by omega))
        clH FRef.incT.hLenH FRef.incT.haudH ?_ ?_ ?_ ?_
      · rw [hclH3]; exact hshape.1
      · rw [hclH3]; exact hshape.2.1
      · rw [hclH3]; exact hshape.2.2
      · rw [hclH3]; exact shdP_inc_logupSumClaim_true tag Rp embDigest bInRow y.1.1 hxV (shdIncRndOf c0) FRef.incT.ch) default)

/-- Concrete Level-1 `PcsAHData` for interior block `k : Fin 26` (`s = k + 1`). -/
noncomputable def shdP_D1_ah_blk {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) (k : Fin 26) :
    PcsAHData GF shdP_K (AdmAt Rp verdict) ⟨shdP_blkASpec, shdP_blkHSpec⟩
      (nodupCols (idxsOf 16 vf (blkAoBase k + 4760))).length (nodupCols (idxsOf 16 vf (blkHoBase k + 4454))).length :=
  let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
  let clH := (FRef.blkT k).acc.claims.h ++ [P.logupSumClaim]
  have hclH53 : clH[53]'(by rw [(FRef.blkT k).hLenH]; omega) = P.logupSumClaim := by
    have hlen : (FRef.blkT k).acc.claims.h.length = 53 := by
      have := (FRef.blkT k).hLenH; simp at this; omega
    simp only [clH, List.getElem_append_right (by omega : (FRef.blkT k).acc.claims.h.length ≤ 53), hlen, Nat.sub_self,
      List.getElem_cons_zero]
  pcsAHData_of_audit 14 2 4283 146 4280 53 (by norm_num)
    (idxsOf 16 vf (blkAoBase k + 4760)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
    (FRef.blkT k).acc.claims.a (FRef.blkT k).haudA
    ((List.range 4577).map fun j => challengeFp2Of (vf (blkAoBase k + 146 + j)))
    (FRef.blkT k).hDetA (fun y => blkADat Rp hR hweights hinPub k y.1)
    (idxsOf 16 vf (blkHoBase k + 4454)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
    clH (FRef.blkT k).hLenH (FRef.blkT k).haudH
    ((List.range 4390).map fun j => challengeFp2Of (vf (blkHoBase k + 54 + j)))
    (FRef.blkT k).hDetH (fun y => blkHDat Rp hR hweights hinPub k (FRef.blkT k).bga y.1)
    (fun y => (fun c0 : ShdCoins => by
      have hshape := shdP_blk_logupSumClaim_shape tag ioIn ioOut Rp hR k
      have hPeq : P.logupSumClaim = Exec.Block.Join.R13H.Look.logupSumR13 (Exec.Block.DefR13.cfgShieldR13 (shdP_layer k.val k.isLt)) :=
        congrArg BlockParams.logupSumClaim
          (ZK60.ProtocolClassify.shdP_Pk0_eq_blkParams tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR k.val k.isLt)
      have hrows := blkTH_rows_eq Rp hR hweights hinPub y.1 c0 k (FRef.blkT k).bga
      dsimp only at hrows
      refine hdH_of_audit_logupSum (logN := 14) (blkHDat Rp hR hweights hinPub k (FRef.blkT k).bga y.1)
        (blkAHCoins c0 k).1.2
        (blkTH (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt)
          (shdBlkRndOf c0 k) (FRef.blkT k).bga).rows
        (blkTH_rows_len _ (shdBlkRndOf c0 k) (FRef.blkT k).bga)
        (fun r col hcol => hrows r col (by omega))
        clH (FRef.blkT k).hLenH (FRef.blkT k).haudH ?_ ?_ ?_ ?_
      · rw [hclH53]; exact hshape.1
      · rw [hclH53]; exact hshape.2.1
      · rw [hclH53]; exact hshape.2.2
      · rw [hclH53, hPeq]; exact blk_logupSumClaim_true _ (shdBlkRndOf c0 k) (FRef.blkT k).bga) default)

/-- Concrete Level-1 `PcsAHData` for Stage OUT-C (`s = 27`). -/
noncomputable def shdP_D1_ah_outc {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) :
    PcsAHData GF shdP_K (AdmAt Rp verdict) ⟨shdP_outcASpec, shdP_outcHSpec⟩
      (nodupCols (idxsOf 14 vf (outcAoBase + 122))).length (nodupCols (idxsOf 14 vf (outcHoBase + 54))).length :=
  let vRef := (classifySpecP Rp (refInput Rp hne verdict).1).getD 0
  let clH := FRef.outcT.acc.claims.h ++ [(shdVo tag Rp wDigest bOutRow vRef).lay.logupSumClaim]
  have hclH9 : clH[9]'(by rw [FRef.outcT.hLenH]; omega) = (shdVo tag Rp wDigest bOutRow vRef).lay.logupSumClaim := by
    have hlen : FRef.outcT.acc.claims.h.length = 9 := by
      have := FRef.outcT.hLenH; simp at this; omega
    simp only [clH, List.getElem_append_right (by omega : FRef.outcT.acc.claims.h.length ≤ 9), hlen, Nat.sub_self,
      List.getElem_cons_zero]
  pcsAHData_of_audit 12 2 16 29 16 9 (by norm_num)
    (idxsOf 14 vf (outcAoBase + 122)) (idxsOf_length 14 vf _) (idxsOf_lt 14 vf _)
    FRef.outcT.acc.claims.a FRef.outcT.haudA
    ((List.range 76).map fun j => challengeFp2Of (vf (outcAoBase + 29 + j)))
    FRef.outcT.hDetA (fun y => outcADat Rp houtPub y.1)
    (idxsOf 14 vf (outcHoBase + 54)) (idxsOf_length 14 vf _) (idxsOf_lt 14 vf _)
    clH FRef.outcT.hLenH FRef.outcT.haudH
    ((List.range 38).map fun j => challengeFp2Of (vf (outcHoBase + 10 + j)))
    FRef.outcT.hDetH (fun y => outcHDat Rp houtPub (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero) y.1)
    (fun y => (fun c0 : ShdCoins => by
      have hshape := shdP_outc_logupSumClaim_shape tag Rp wDigest bOutRow vRef
      let w := outcWitness_of_adm Rp houtPub y.1.1 y.1.2
      refine hdH_of_audit_logupSum (logN := 12) (outcHDat Rp houtPub (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero) y.1)
        (c0.1.2.2 ⟨27, by decide⟩).1.2
        (shdP_outcTH Rp w (shdOutcRndOf c0) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero)).rows
        (shdP_outcTH_rows_len Rp w (shdOutcRndOf c0) _ _)
        (fun r col hcol => shdP_outcTH_rows_eq Rp houtPub (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero) y.1 c0 r col (by omega))
        clH FRef.outcT.hLenH FRef.outcT.haudH ?_ ?_ ?_ ?_
      · rw [hclH9]; exact hshape.1
      · rw [hclH9]; exact hshape.2.1
      · rw [hclH9]; exact hshape.2.2
      · rw [hclH9]; exact shdP_outc_logupSumClaim_true tag Rp wDigest bOutRow vRef w (shdOutcRndOf c0) FRef.outcT.ch) default)

/-- Cast helper for `PcsAHData` along `shdP_L1Spec.ah s` and `(shdP_ks vf).kA/kH s`. -/
def pcsAHDataCast {Dt : Type} {S₁ S₂ : PcsAHSpec} {kA₁ kA₂ kH₁ kH₂ : ℕ}
    (hS : S₁ = S₂) (hA : kA₁ = kA₂) (hH : kH₁ = kH₂) (D : PcsAHData GF shdP_K Dt S₁ kA₁ kH₁) :
    PcsAHData GF shdP_K Dt S₂ kA₂ kH₂ := by
  subst hS; subst hA; subst hH; exact D

/-- Cast helper for `PcsAHView` along `shdP_L1Spec.ah s` and `(shdP_ks vf).kA/kH s`. -/
def pcsAHViewCast {S₁ S₂ : PcsAHSpec} {kA₁ kA₂ kH₁ kH₂ : ℕ}
    (hS : S₁ = S₂) (hA : kA₁ = kA₂) (hH : kH₁ = kH₂) (v : PcsAHView GF shdP_K S₁ kA₁ kH₁) :
    PcsAHView GF shdP_K S₂ kA₂ kH₂ := by
  subst hS; subst hA; subst hH; exact v

theorem pcsAHDataCast_view {Dt : Type} {S₁ S₂ : PcsAHSpec} {kA₁ kA₂ kH₁ kH₂ : ℕ}
    (hS : S₁ = S₂) (hS' : S₂ = S₁) (hA : kA₁ = kA₂) (hA' : kA₂ = kA₁) (hH : kH₁ = kH₂) (hH' : kH₂ = kH₁)
    (D : PcsAHData GF shdP_K Dt S₁ kA₁ kH₁)
    (e : Dt) (c : PcsAHCoins GF S₂) :
    pcsAHViewCast hS' hA' hH' ((pcsAHDataCast hS hA hH D).view e c)
      = D.view e (hS' ▸ c) := by
  subst hS; subst hA; subst hH; rfl

theorem pcsAHDataCast_view_self {Dt : Type} {S : PcsAHSpec} {kA kH : ℕ}
    (hS : S = S) (hA : kA = kA) (hH : kH = kH) (D : PcsAHData GF shdP_K Dt S kA kH)
    (e : Dt) (c : PcsAHCoins GF S) :
    (pcsAHDataCast hS hA hH D).view e c = D.view e c := by
  cases hS; cases hA; cases hH; rfl

theorem pcsAHViewCast_self {S : PcsAHSpec} {kA kH : ℕ}
    (hS : S = S) (hA : kA = kA) (hH : kH = kH) (v : PcsAHView GF shdP_K S kA kH) :
    pcsAHViewCast hS hA hH v = v := by
  cases hS; cases hA; cases hH; rfl

/-- **Complete Level-1 `ShdL1Data` across all 84 PCS tables** (`TE`, `B_0..26`, `A_0..27`, `H_0..27`). -/
noncomputable def shdP_D1 {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) :
    ShdL1Data GF shdP_K (AdmAt Rp verdict) shdP_L1Spec (shdP_ks vf) where
  te := shdP_D1_te tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  bnd := shdP_D1_bnd tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  ah s :=
    if h0 : s.val = 0 then
      pcsAHDataCast
        (by dsimp only [shdP_L1Spec]; rw [ite_eq_left h0])
        (by unfold shdP_ks; dsimp only; rw [dite_eq_left h0])
        (by unfold shdP_ks; dsimp only; rw [dite_eq_left h0])
        (shdP_D1_ah_inc tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef)
    else if h27 : s.val = 27 then
      pcsAHDataCast
        (by dsimp only [shdP_L1Spec]; rw [ite_eq_right h0, ite_eq_left h27])
        (by unfold shdP_ks; dsimp only; rw [dite_eq_right h0, dite_eq_left h27])
        (by unfold shdP_ks; dsimp only; rw [dite_eq_right h0, dite_eq_left h27])
        (shdP_D1_ah_outc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef)
    else
      let k : Fin 26 := ⟨s.val - 1, by omega⟩
      pcsAHDataCast
        (by dsimp only [shdP_L1Spec]; rw [ite_eq_right h0, ite_eq_right h27])
        (by unfold shdP_ks; dsimp only; rw [dite_eq_right h0, dite_eq_right h27])
        (by unfold shdP_ks; dsimp only; rw [dite_eq_right h0, dite_eq_right h27])
        (shdP_D1_ah_blk tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef k)

/-- Cast helpers for projecting concrete PCS views out of `ShdL1View`. -/
noncomputable def bndViewAt (vf : ℕ → Dig) (v1 : ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf)) (k : Fin 27) :
    PcsStdView GF shdP_K shdP_bndSpec
      (if h : k.val < 26 then (nodupCols (idxsOf 16 vf (blkBoBase ⟨k.val, h⟩ + 43))).length
       else (nodupCols (idxsOf 16 vf (outcBoBase + 43))).length) :=
  v1.2.1 k

noncomputable def incAHViewOf (vf : ℕ → Dig) (v1 : ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf)) :
    PcsAHView GF shdP_K ⟨shdP_incASpec, shdP_incHSpec⟩
      (nodupCols (idxsOf 14 vf (incAoBase + 48))).length (nodupCols (idxsOf 14 vf (incHoBase + 85))).length :=
  pcsAHViewCast rfl (shdP_ks_kA_zero vf) (shdP_ks_kH_zero vf) (v1.2.2 ⟨0, by decide⟩)

noncomputable def blkAHViewOf (vf : ℕ → Dig) (v1 : ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf)) (k : Fin 26) :
    PcsAHView GF shdP_K ⟨shdP_blkASpec, shdP_blkHSpec⟩
      (nodupCols (idxsOf 16 vf (blkAoBase k + 4760))).length (nodupCols (idxsOf 16 vf (blkHoBase k + 4454))).length :=
  pcsAHViewCast (shdP_L1Spec_ah_blk k) (shdP_ks_kA_blk vf k) (shdP_ks_kH_blk vf k) (v1.2.2 ⟨k.val + 1, by omega⟩)

noncomputable def outcAHViewOf (vf : ℕ → Dig) (v1 : ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf)) :
    PcsAHView GF shdP_K ⟨shdP_outcASpec, shdP_outcHSpec⟩
      (nodupCols (idxsOf 14 vf (outcAoBase + 122))).length (nodupCols (idxsOf 14 vf (outcHoBase + 54))).length :=
  pcsAHViewCast rfl (shdP_ks_kA_outc vf) (shdP_ks_kH_outc vf) (v1.2.2 ⟨27, by decide⟩)

theorem shdP_D1_view_te {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) :
    let hc0 := incTeClaim_of_trace tag Rp embDigest bInRow _ default vf FRef.incT
    (shdP_ks_te vf ▸ ((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef).view y c.1).1)
      = (tePcsData_of_audit (idxsOf 11 vf (incEoBase + 9)) (idxsOf_length 11 vf _) (idxsOf_lt 11 vf _)
          hc0.choose hc0.choose_spec.2.2
          ((List.range 6).map fun j => challengeFp2Of (vf (incEoBase + 1 + j)))
          FRef.incT.hDetE (fun y' : AdmAt Rp verdict => teDatOf y'.1.1)).view y c.1.1 := by
  delta ShdL1Data.view shdP_D1 shdP_D1_te; dsimp only
  exact pcsStdDataCast_view (shdP_ks_te vf).symm (shdP_ks_te vf) _ y c.1.1

theorem shdP_D1_view_te_fst {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) :
    let hc0 := incTeClaim_of_trace tag Rp embDigest bInRow _ default vf FRef.incT
    (((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef).view y c.1).1).1.1
      = ((tePcsData_of_audit (idxsOf 11 vf (incEoBase + 9)) (idxsOf_length 11 vf _) (idxsOf_lt 11 vf _)
          hc0.choose hc0.choose_spec.2.2
          ((List.range 6).map fun j => challengeFp2Of (vf (incEoBase + 1 + j)))
          FRef.incT.hDetE (fun y' : AdmAt Rp verdict => teDatOf y'.1.1)).view y c.1.1).1.1 := by
  delta ShdL1Data.view shdP_D1 shdP_D1_te; dsimp only
  exact pcsStdDataCast_view_fst (shdP_ks_te vf).symm _ y c.1.1

theorem shdP_D1_view_bnd_blk {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) (k : Fin 26)
    (hks : (shdP_ks vf).bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩ = (nodupCols (idxsOf 16 vf (blkBoBase k + 43))).length) :
    (hks ▸ ((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef).view y c.1).2.1 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
      = (stdPcsData_of_audit 14 2 32 2 (by norm_num)
          (idxsOf 16 vf (blkBoBase k + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
          ((FRef.crAt ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).pending ++ (FRef.blkT k).acc.claims.inp)
          (FRef.blkT k).haudB
          ((List.range 38).map fun j => challengeFp2Of (vf (blkBoBase k + 2 + j)))
          (FRef.blkT k).hDetB
          (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩ y'.1)).view
          y (c.1.2.1 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩) := by
  delta ShdL1Data.view shdP_D1 shdP_D1_bnd; dsimp only
  rw [dite_eq_left k.isLt]
  exact pcsStdDataCast_view _ hks _ y _

theorem shdP_D1_view_bnd_blk_fst {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) (k : Fin 26) :
    (((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef).view y c.1).2.1 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).1.1
      = ((stdPcsData_of_audit 14 2 32 2 (by norm_num)
          (idxsOf 16 vf (blkBoBase k + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
          ((FRef.crAt ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).pending ++ (FRef.blkT k).acc.claims.inp)
          (FRef.blkT k).haudB
          ((List.range 38).map fun j => challengeFp2Of (vf (blkBoBase k + 2 + j)))
          (FRef.blkT k).hDetB
          (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩ y'.1)).view
          y (c.1.2.1 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)).1.1 := by
  delta ShdL1Data.view shdP_D1 shdP_D1_bnd; dsimp only
  rw [dite_eq_left k.isLt]
  exact pcsStdDataCast_view_fst _ _ y _

theorem shdP_D1_view_bnd_outc {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins)
    (hks : (shdP_ks vf).bnd ⟨26, by decide⟩ = (nodupCols (idxsOf 16 vf (outcBoBase + 43))).length) :
    (hks ▸ ((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef).view y c.1).2.1 ⟨26, by decide⟩)
      = (stdPcsData_of_audit 14 2 32 2 (by norm_num)
          (idxsOf 16 vf (outcBoBase + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
          ((FRef.crAt ⟨26, by decide⟩).pending ++ FRef.outcT.acc.claims.inp)
          FRef.outcT.haudB
          ((List.range 38).map fun j => challengeFp2Of (vf (outcBoBase + 2 + j)))
          FRef.outcT.hDetB
          (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨26, by decide⟩ y'.1)).view
          y (c.1.2.1 ⟨26, by decide⟩) := by
  have hBnd : (shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef).bnd ⟨26, by decide⟩
      = pcsStdDataCast (by unfold shdP_ks; dsimp only; rw [dite_eq_right (by decide : ¬ (26 < 26))])
          (stdPcsData_of_audit 14 2 32 2 (by norm_num)
            (idxsOf 16 vf (outcBoBase + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
            ((FRef.crAt ⟨26, by decide⟩).pending ++ FRef.outcT.acc.claims.inp)
            FRef.outcT.haudB
            ((List.range 38).map fun j => challengeFp2Of (vf (outcBoBase + 2 + j)))
            FRef.outcT.hDetB
            (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨26, by decide⟩ y'.1)) := by
    delta shdP_D1 shdP_D1_bnd; dsimp only
    exact dite_eq_right (by decide : ¬ (26 < 26))
  delta ShdL1Data.view; dsimp only
  exact (congrArg (fun d : PcsStdData GF shdP_K (AdmAt Rp verdict) shdP_bndSpec ((shdP_ks vf).bnd ⟨26, by decide⟩) =>
      (hks ▸ d.view y (c.1.2.1 ⟨26, by decide⟩))) hBnd).trans
    (pcsStdDataCast_view _ hks _ y _)

theorem shdP_D1_view_bnd_outc_fst {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) :
    (((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef).view y c.1).2.1 ⟨26, by decide⟩).1.1
      = ((stdPcsData_of_audit 14 2 32 2 (by norm_num)
          (idxsOf 16 vf (outcBoBase + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
          ((FRef.crAt ⟨26, by decide⟩).pending ++ FRef.outcT.acc.claims.inp)
          FRef.outcT.haudB
          ((List.range 38).map fun j => challengeFp2Of (vf (outcBoBase + 2 + j)))
          FRef.outcT.hDetB
          (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨26, by decide⟩ y'.1)).view
          y (c.1.2.1 ⟨26, by decide⟩)).1.1 := by
  delta ShdL1Data.view shdP_D1 shdP_D1_bnd; dsimp only
  rw [dite_eq_right (by decide : ¬ (26 < 26))]
  exact pcsStdDataCast_view_fst _ _ y _

theorem shdP_D1_view_incAH {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) :
    incAHViewOf vf ((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef).view y c.1)
      = (shdP_D1_ah_inc tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef).view y (c.1.2.2 ⟨0, by decide⟩) := by
  unfold incAHViewOf ShdL1Data.view shdP_D1
  dsimp only
  rw [dite_eq_left rfl]
  exact pcsAHDataCast_view _ rfl _ (shdP_ks_kA_zero vf) _ (shdP_ks_kH_zero vf) _ y (c.1.2.2 ⟨0, by decide⟩)

theorem shdP_D1_view_blkAH {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) (k : Fin 26) :
    blkAHViewOf vf ((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef).view y c.1) k
      = (shdP_D1_ah_blk tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef k).view y (blkAHCoins c k) := by
  unfold blkAHViewOf ShdL1Data.view shdP_D1
  dsimp only
  rw [dite_eq_right (by omega : ¬ (k.val + 1 = 0)), dite_eq_right (by omega : ¬ (k.val + 1 = 27))]
  have hgen : ∀ (k' : Fin 26) (hk' : k' = k)
      (hS : (⟨shdP_blkASpec, shdP_blkHSpec⟩ : PcsAHSpec) = shdP_L1Spec.ah ⟨k.val + 1, by omega⟩)
      (hA : (nodupCols (idxsOf 16 vf (blkAoBase k' + 4760))).length = (shdP_ks vf).kA ⟨k.val + 1, by omega⟩)
      (hH : (nodupCols (idxsOf 16 vf (blkHoBase k' + 4454))).length = (shdP_ks vf).kH ⟨k.val + 1, by omega⟩),
      pcsAHViewCast (shdP_L1Spec_ah_blk k) (shdP_ks_kA_blk vf k) (shdP_ks_kH_blk vf k)
        ((pcsAHDataCast hS hA hH (shdP_D1_ah_blk tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef k')).view y (c.1.2.2 ⟨k.val + 1, by omega⟩))
      = (shdP_D1_ah_blk tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef k).view y (blkAHCoins c k) := by
    rintro k' hk' hS hA hH; subst k'
    exact pcsAHDataCast_view hS (shdP_L1Spec_ah_blk k) hA (shdP_ks_kA_blk vf k) hH (shdP_ks_kH_blk vf k) _ y _
  exact hgen ⟨(k.val + 1) - 1, by omega⟩ (Fin.ext (Nat.add_sub_cancel k.val 1)) _ _ _

theorem shdP_D1_view_outcAH {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) :
    outcAHViewOf vf ((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef).view y c.1)
      = (shdP_D1_ah_outc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef).view y (c.1.2.2 ⟨27, by decide⟩) := by
  unfold outcAHViewOf ShdL1Data.view shdP_D1
  dsimp only
  rw [dite_eq_right (by decide : ¬ (27 = 0)), dite_eq_left rfl]
  exact pcsAHDataCast_view _ rfl _ (shdP_ks_kA_outc vf) _ (shdP_ks_kH_outc vf) _ y (c.1.2.2 ⟨27, by decide⟩)

/-- Pure `ShdL1View` claim-value lookup for Stage IN-C (`s = 0`). -/
noncomputable def incCsViewOf {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (v1 : ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf)) : Cm → List Block.ZPart → shdP_K
  | .a =>
      let permA := stdAuditPerm 12 33 3 FRef.incT.acc.claims.a FRef.incT.haudA
      lookupClaimVal 41 12 FRef.incT.acc.claims.a (fun i => (incAHViewOf vf v1).1.1.1 (permA.symm i))
  | .h =>
      let clH := FRef.incT.acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim]
      let permH := hAuditPerm 12 66 3 clH FRef.incT.hLenH FRef.incT.haudH
      lookupClaimVal 76 12 clH (hClaimVecOfView clH FRef.incT.hLenH permH (incAHViewOf vf v1).1.2)
  | .inp =>
      let c0 := (incTeClaim_of_trace tag Rp embDigest bInRow _ default vf FRef.incT).choose
      lookupClaimVal 6 8 [c0] (fun _ => v1.1.1.1 (⟨0, by decide⟩ : Fin 1))
  | .out =>
      let clB := (FRef.crAt ⟨0, by decide⟩).pending ++ (FRef.blkT ⟨0, by decide⟩).acc.claims.inp
      let permB := stdAuditPerm 14 32 2 clB (FRef.blkT ⟨0, by decide⟩).haudB
      lookupClaimVal 38 14 clB (fun i => (v1.2.1 ⟨0, by decide⟩).1.1 (permB.symm i))

/-- Pure `ShdL1View` claim-value lookup for interior block `k : Fin 26`. -/
noncomputable def blkCsViewOf {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (k : Fin 26) (v1 : ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf)) : Cm → List Block.ZPart → shdP_K
  | .a =>
      let permA := stdAuditPerm 14 4283 146 (FRef.blkT k).acc.claims.a (FRef.blkT k).haudA
      lookupClaimVal 4577 14 (FRef.blkT k).acc.claims.a (fun i => (blkAHViewOf vf v1 k).1.1.1 (permA.symm i))
  | .h =>
      let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
      let clH := (FRef.blkT k).acc.claims.h ++ [P.logupSumClaim]
      let permH := hAuditPerm 14 4280 53 clH (FRef.blkT k).hLenH (FRef.blkT k).haudH
      lookupClaimVal 4390 14 clH (hClaimVecOfView clH (FRef.blkT k).hLenH permH (blkAHViewOf vf v1 k).1.2)
  | .inp =>
      let clB := (FRef.crAt ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).pending ++ (FRef.blkT k).acc.claims.inp
      let permB := stdAuditPerm 14 32 2 clB (FRef.blkT k).haudB
      lookupClaimVal 38 14 clB (fun i => (v1.2.1 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).1.1 (permB.symm i))
  | .out =>
      if h : k.val + 1 < 26 then
        let clB := (FRef.crAt ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).pending ++ (FRef.blkT ⟨k.val + 1, h⟩).acc.claims.inp
        let permB := stdAuditPerm 14 32 2 clB (FRef.blkT ⟨k.val + 1, h⟩).haudB
        lookupClaimVal 38 14 clB (fun i => (v1.2.1 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).1.1 (permB.symm i))
      else
        let clB := (FRef.crAt ⟨26, by decide⟩).pending ++ FRef.outcT.acc.claims.inp
        let permB := stdAuditPerm 14 32 2 clB FRef.outcT.haudB
        lookupClaimVal 38 14 clB (fun i => (v1.2.1 ⟨26, by decide⟩).1.1 (permB.symm i))

/-- Pure `ShdL1View` claim-value lookup for Stage OUT-C (`s = 27`). -/
noncomputable def outcCsViewOf {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (v1 : ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf)) : Cm → List Block.ZPart → shdP_K
  | .a =>
      let permA := stdAuditPerm 12 16 29 FRef.outcT.acc.claims.a FRef.outcT.haudA
      lookupClaimVal 76 12 FRef.outcT.acc.claims.a (fun i => (outcAHViewOf vf v1).1.1.1 (permA.symm i))
  | .h =>
      let vRef := (classifySpecP Rp (refInput Rp hne verdict).1).getD 0
      let clH := FRef.outcT.acc.claims.h ++ [(shdVo tag Rp wDigest bOutRow vRef).lay.logupSumClaim]
      let permH := hAuditPerm 12 16 9 clH FRef.outcT.hLenH FRef.outcT.haudH
      lookupClaimVal 38 12 clH (hClaimVecOfView clH FRef.outcT.hLenH permH (outcAHViewOf vf v1).1.2)
  | .inp =>
      let clB := (FRef.crAt ⟨26, by decide⟩).pending ++ FRef.outcT.acc.claims.inp
      let permB := stdAuditPerm 14 32 2 clB FRef.outcT.haudB
      lookupClaimVal 38 14 clB (fun i => (v1.2.1 ⟨26, by decide⟩).1.1 (permB.symm i))
  | .out => fun _ => 0

/-- Exact `incCs = incCsViewOf (D1.view y ω₁)` on every private claim emitted by Stage IN-C! -/
theorem incCs_eq_incCsViewOf {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (ω₁ : ShdL1Coins GF shdP_L1Spec) (t : Fin 4) (p : Exec.Block.Priv)
    (hp : Tab.priv p ∈ (FRef.incT.dfs t).tabs) :
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub FRef.incT.ch)
    let elog := incElog V.pub 14
    let bj := incSlBase + slotsFixedLen P 0 t.val
    let rhoFull := (List.range (slotN P t.val)).map (fun r => challengeFp2Of (vf (bj + P.draws t.val + 3 + 2 * r + 1)))
    let n := (Exec.Block.slotShape P t.val).1
    let rho := rhoFull.take n
    let es := rhoFull.drop n
    let z0 := Exec.Block.buildClaim (atLog P (elog t.val)) p (Exec.Block.claimPoint p rho)
      (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
    let c := cOfL1 ω₁
    let cs := incCs (shdP_incTA y.1.1 (shdIncRndOf c)) (shdP_incTH Rp embDigest y.1.1 (shdIncRndOf c) FRef.incT.ch)
      (shdP_epTable (Hdr := Hdr) tag y.1.1 (shdEpBase c)) (shdP_incTB Rp y.1.1 (shdIncRndOf c))
    let D1 := shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
    cs p.cm z0 = incCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
      (D1.view y ω₁) p.cm z0.parts := by
  intro V P elog bj rhoFull n rho es z0 c cs D1
  have hclMem := (FRef.incT.slot_spec t).2.2.2.2.2.2 p hp
  dsimp only at hclMem
  have hVinc := shdP_D1_view_incAH tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c
  cases hcm : p.cm with
  | a =>
    rw [hcm] at hclMem
    unfold incCsViewOf; dsimp only
    change Link.claimSem shdP_U 41 12 0 (tabMat 41 12 (shdP_incTA y.1.1 (shdIncRndOf c)).rows) z0 = _
    refine lookupClaimVal_eq_claimSem 41 12 _ (shdP_incTA_rows_len _ _) _ _ rfl _ (fun i col => ?_) z0 hclMem
    have h := stdClaim_combAt_eq_of_audit 12 2 33 3 (by norm_num)
      (idxsOf 14 vf (incAoBase + 48)) (idxsOf_length 14 vf _) (idxsOf_lt 14 vf _)
      FRef.incT.acc.claims.a FRef.incT.haudA
      ((List.range 41).map fun j => challengeFp2Of (vf (incAoBase + 3 + j)))
      FRef.incT.hDetA (fun y' : AdmAt Rp verdict => incADat y'.1.1) y
      ((c.1.2.2 ⟨0, by decide⟩).1.1, (c.1.2.2 ⟨0, by decide⟩).2.1)
      (shdP_incTA y.1.1 (shdIncRndOf c)).rows (shdP_incTA_rows_len _ _)
      (fun r k hk => shdP_incTA_rows_eq y.1.1 c r k (by omega)) i col.val (by omega)
    dsimp only at h; rw [rowAt_mkStdSpec_inl] at h
    rw [show incAHViewOf vf (D1.view y ω₁) = _ from hVinc]
    exact h
  | h =>
    rw [hcm] at hclMem
    unfold incCsViewOf; dsimp only
    let clH := FRef.incT.acc.claims.h ++ [V.lay.logupSumClaim]
    have hmemH : ∃ z ∈ clH, z.parts = z0.parts := by
      obtain ⟨z, hz, hzp⟩ := hclMem
      exact ⟨z, List.mem_append_left _ hz, hzp⟩
    change Link.claimSem shdP_U 76 12 0 (tabMat 76 12 (shdP_incTH Rp embDigest y.1.1 (shdIncRndOf c) FRef.incT.ch).rows) z0 = _
    refine lookupClaimVal_eq_claimSem 76 12 _ (shdP_incTH_rows_len _ _ _ _ _) _ _ rfl _ (fun i col => ?_) z0 hmemH
    have h := hClaim_combAt_eq_of_audit (lr := 2)
      (E := pcsEvalMat 12 2 (by norm_num) (dedupIdx (idxsOf 14 vf (incHoBase + 85)) (idxsOf_lt 14 vf _)))
      clH FRef.incT.hLenH FRef.incT.haudH
      ((List.range 76).map fun j => challengeFp2Of (vf (incHoBase + 4 + j)))
      (incHDat Rp embDigest FRef.incT.ch y.1.1) (c.1.2.2 ⟨0, by decide⟩).1.2
      (shdP_incTH Rp embDigest y.1.1 (shdIncRndOf c) FRef.incT.ch).rows (shdP_incTH_rows_len _ _ _ _ _)
      (fun r k hk => shdP_incTH_rows_eq Rp embDigest FRef.incT.ch y.1.1 c r k (by omega)) i col.val (by omega)
    dsimp only at h; rw [rowAt_inl] at h
    rw [show incAHViewOf vf (D1.view y ω₁) = _ from hVinc]
    exact h
  | inp =>
    rw [hcm] at hclMem
    unfold incCsViewOf; dsimp only
    have hc0 := incTeClaim_of_trace tag Rp embDigest bInRow _ default vf FRef.incT
    rw [hc0.choose_spec.1] at hclMem
    change Link.claimSem shdP_U 6 8 0 (tabMat 6 8 (shdP_epTable (Hdr := Hdr) tag y.1.1 (shdEpBase c)).rows) z0 = _
    refine lookupClaimVal_eq_claimSem 6 8 _ (shdP_epTable_rows_length _ _ _) _ _ rfl _ (fun i col => ?_) z0 hclMem
    have hi0 : i.val = 0 := Nat.lt_one_iff.mp i.isLt
    simp only [hi0, List.getElem_cons_zero]
    have h := teClaim_combAt_eq_of_hdr (idxsOf 11 vf (incEoBase + 9)) (idxsOf_length 11 vf _) (idxsOf_lt 11 vf _)
      hc0.choose hc0.choose_spec.2.1 hc0.choose_spec.2.2
      ((List.range 6).map fun j => challengeFp2Of (vf (incEoBase + 1 + j)))
      FRef.incT.hDetE (fun y' : AdmAt Rp verdict => teDatOf y'.1.1) y c.1.1
      (shdP_epTable (Hdr := Hdr) tag y.1.1 (shdEpBase c)).rows (shdP_epTable_rows_length _ _ _)
      (shdP_epTable_rows_eq tag y.1.1 c) col.val (by omega)
    rw [rowAt_teSpec_inl] at h
    rw [show (D1.view y ω₁).1.1.1 = _ from shdP_D1_view_te_fst tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c]
    exact h
  | out =>
    rw [hcm] at hclMem
    unfold incCsViewOf; dsimp only
    let clB := (FRef.crAt ⟨0, by decide⟩).pending ++ (FRef.blkT ⟨0, by decide⟩).acc.claims.inp
    have hmemB : ∃ z ∈ clB, z.parts = z0.parts := by
      obtain ⟨z, hz, hzp⟩ := hclMem
      exact ⟨z, List.mem_append_left _ (by change z ∈ (FRef.crAt 0).pending; rw [FRef.crAt_zero]; exact hz), hzp⟩
    have hTB0 : shdP_incTB Rp y.1.1 (shdIncRndOf c) = shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨0, by decide⟩ := rfl
    change Link.claimSem shdP_U 38 14 0 (tabMat 38 14 (shdP_incTB Rp y.1.1 (shdIncRndOf c)).rows) z0 = _
    rw [hTB0]
    refine lookupClaimVal_eq_claimSem 38 14 _ (shdP_bndTableAt_spec _ _ _ _ _ _ _ _ _).rows_len _ _ rfl _ (fun i col => ?_) z0 hmemB
    have h := stdClaim_combAt_eq_of_audit 14 2 32 2 (by norm_num)
      (idxsOf 16 vf (blkBoBase ⟨0, by decide⟩ + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
      clB (FRef.blkT ⟨0, by decide⟩).haudB
      ((List.range 38).map fun j => challengeFp2Of (vf (blkBoBase ⟨0, by decide⟩ + 2 + j)))
      (FRef.blkT ⟨0, by decide⟩).hDetB
      (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨0, by decide⟩ y'.1) y (c.1.2.1 ⟨0, by decide⟩)
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨0, by decide⟩).rows
      (shdP_bndTableAt_spec _ _ _ _ _ _ _ _ _).rows_len
      (fun r k hk => shdP_bndTableAt_rows_eq Rp hR hweights hinPub y.1 c ⟨0, by decide⟩ r k (by omega)) i col.val (by omega)
    dsimp only at h; rw [rowAt_mkStdSpec_inl] at h
    rw [show ((D1.view y ω₁).2.1 ⟨0, by decide⟩).1.1 = _ from
      shdP_D1_view_bnd_blk_fst tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c ⟨0, by decide⟩]
    exact h

/-- Exact `blkCs = blkCsViewOf (D1.view y ω₁)` on every private claim emitted by block `k : Fin 26`! -/
theorem blkCs_eq_blkCsViewOf {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (k : Fin 26) (y : AdmAt Rp verdict) (ω₁ : ShdL1Coins GF shdP_L1Spec) (t : Fin 23) (p : Exec.Block.Priv)
    (hp : Tab.priv p ∈ ((FRef.blkT k).dfs t).tabs) :
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    let bj := blkSlBase k + slotsFixedLen P 0 t.val
    let rhoFull := (List.range (slotN P t.val)).map (fun r => challengeFp2Of (vf (bj + P.draws t.val + 3 + 2 * r + 1)))
    let n := (Exec.Block.slotShape P t.val).1
    let rho := rhoFull.take n
    let es := rhoFull.drop n
    let z0 := Exec.Block.buildClaim P p (Exec.Block.claimPoint p rho)
      (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
    let c := cOfL1 ω₁
    let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt
    let cs := blkCs (blkTA w (shdBlkRndOf c k)) (blkTH w (shdBlkRndOf c k) (FRef.blkT k).bga)
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
    let D1 := shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
    cs p.cm z0 = blkCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
      k (D1.view y ω₁) p.cm z0.parts := by
  intro P bj rhoFull n rho es z0 c
  dsimp only
  have hclMem := ((FRef.blkT k).slot_spec t).2.2.2.2.2.2.2.2 p hp
  dsimp only at hclMem
  have hVblk := shdP_D1_view_blkAH tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c k
  cases hcm : p.cm with
  | a =>
    rw [hcm] at hclMem
    unfold blkCsViewOf; dsimp only
    change Link.claimSem shdP_U 4577 14 0 (tabMat 4577 14 (blkTA (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf c k)).rows) z0 = _
    refine lookupClaimVal_eq_claimSem 4577 14 _ (blkTA_rows_len _ _) _ _ rfl _ (fun i col => ?_) z0 hclMem
    have hrows := blkTA_rows_eq Rp hR hweights hinPub y.1 c k
    dsimp only at hrows
    have h := stdClaim_combAt_eq_of_audit 14 2 4283 146 (by norm_num)
      (idxsOf 16 vf (blkAoBase k + 4760)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
      (FRef.blkT k).acc.claims.a (FRef.blkT k).haudA
      ((List.range 4577).map fun j => challengeFp2Of (vf (blkAoBase k + 146 + j)))
      (FRef.blkT k).hDetA (fun y' : AdmAt Rp verdict => blkADat Rp hR hweights hinPub k y'.1) y
      ((blkAHCoins c k).1.1, (blkAHCoins c k).2.1)
      (blkTA (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf c k)).rows (blkTA_rows_len _ _)
      (fun r j hj => hrows r j (by omega)) i col.val (by omega)
    dsimp only at h; rw [rowAt_mkStdSpec_inl] at h
    rw [show blkAHViewOf vf ((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view y ω₁) k = _ from hVblk]
    exact h
  | h =>
    rw [hcm] at hclMem
    unfold blkCsViewOf; dsimp only
    let clH := (FRef.blkT k).acc.claims.h ++ [P.logupSumClaim]
    have hmemH : ∃ z ∈ clH, z.parts = z0.parts := by
      obtain ⟨z, hz, hzp⟩ := hclMem
      exact ⟨z, List.mem_append_left _ hz, hzp⟩
    change Link.claimSem shdP_U 4390 14 0 (tabMat 4390 14 (blkTH (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf c k) (FRef.blkT k).bga).rows) z0 = _
    refine lookupClaimVal_eq_claimSem 4390 14 _ (blkTH_rows_len _ _ _) _ _ rfl _ (fun i col => ?_) z0 hmemH
    have hrows := blkTH_rows_eq Rp hR hweights hinPub y.1 c k (FRef.blkT k).bga
    dsimp only at hrows
    have h := hClaim_combAt_eq_of_audit (lr := 2)
      (E := pcsEvalMat 14 2 (by norm_num) (dedupIdx (idxsOf 16 vf (blkHoBase k + 4454)) (idxsOf_lt 16 vf _)))
      clH (FRef.blkT k).hLenH (FRef.blkT k).haudH
      ((List.range 4390).map fun j => challengeFp2Of (vf (blkHoBase k + 54 + j)))
      (blkHDat Rp hR hweights hinPub k (FRef.blkT k).bga y.1) (blkAHCoins c k).1.2
      (blkTH (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf c k) (FRef.blkT k).bga).rows (blkTH_rows_len _ _ _)
      (fun r j hj => hrows r j (by omega)) i col.val (by omega)
    dsimp only at h; rw [rowAt_inl] at h
    rw [show blkAHViewOf vf ((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view y ω₁) k = _ from hVblk]
    exact h
  | inp =>
    rw [hcm] at hclMem
    unfold blkCsViewOf; dsimp only
    let clB := (FRef.crAt ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).pending ++ (FRef.blkT k).acc.claims.inp
    have hmemB : ∃ z ∈ clB, z.parts = z0.parts := by
      obtain ⟨z, hz, hzp⟩ := hclMem
      exact ⟨z, List.mem_append_right _ hz, hzp⟩
    change Link.claimSem shdP_U 38 14 0 (tabMat 38 14 (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).rows) z0 = _
    refine lookupClaimVal_eq_claimSem 38 14 _ (shdP_bndTableAt_spec _ _ _ _ _ _ _ _ _).rows_len _ _ rfl _ (fun i col => ?_) z0 hmemB
    have h := stdClaim_combAt_eq_of_audit 14 2 32 2 (by norm_num)
      (idxsOf 16 vf (blkBoBase k + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
      clB (FRef.blkT k).haudB
      ((List.range 38).map fun j => challengeFp2Of (vf (blkBoBase k + 2 + j)))
      (FRef.blkT k).hDetB
      (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩ y'.1)
      y (c.1.2.1 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).rows
      (shdP_bndTableAt_spec _ _ _ _ _ _ _ _ _).rows_len
      (fun r j hj => shdP_bndTableAt_rows_eq Rp hR hweights hinPub y.1 c ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩ r j (by omega)) i col.val (by omega)
    dsimp only at h; rw [rowAt_mkStdSpec_inl] at h
    rw [show (((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view y ω₁).2.1 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).1.1 = _ from
      shdP_D1_view_bnd_blk_fst tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c k]
    exact h
  | out =>
    rw [hcm] at hclMem
    change Link.claimSem shdP_U 38 14 0 (tabMat 38 14 (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).rows) z0 = _
    unfold blkCsViewOf; dsimp only
    by_cases hlt : k.val + 1 < 26
    · rw [dite_eq_left hlt]
      let clB := (FRef.crAt ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).pending ++ (FRef.blkT ⟨k.val + 1, hlt⟩).acc.claims.inp
      have hmemB : ∃ z ∈ clB, z.parts = z0.parts := by
        obtain ⟨z, hz, hzp⟩ := hclMem
        exact ⟨z, List.mem_append_left _ (by rw [FRef.crAt_succ k]; exact hz), hzp⟩
      refine lookupClaimVal_eq_claimSem 38 14 _ (shdP_bndTableAt_spec _ _ _ _ _ _ _ _ _).rows_len _ _ rfl _ (fun i col => ?_) z0 hmemB
      have h := stdClaim_combAt_eq_of_audit 14 2 32 2 (by norm_num)
        (idxsOf 16 vf (blkBoBase ⟨k.val + 1, hlt⟩ + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
        clB (FRef.blkT ⟨k.val + 1, hlt⟩).haudB
        ((List.range 38).map fun j => challengeFp2Of (vf (blkBoBase ⟨k.val + 1, hlt⟩ + 2 + j)))
        (FRef.blkT ⟨k.val + 1, hlt⟩).hDetB
        (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩ y'.1)
        y (c.1.2.1 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).rows
        (shdP_bndTableAt_spec _ _ _ _ _ _ _ _ _).rows_len
        (fun r j hj => shdP_bndTableAt_rows_eq Rp hR hweights hinPub y.1 c ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩ r j (by omega)) i col.val (by omega)
      dsimp only at h; rw [rowAt_mkStdSpec_inl] at h
      rw [show (((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view y ω₁).2.1 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).1.1 = _ from
        shdP_D1_view_bnd_blk_fst tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c ⟨k.val + 1, hlt⟩]
      exact h
    · rw [dite_eq_right hlt]
      have hk25 : k.val + 1 = 26 := by omega
      have hfin : (⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩ : Fin 27) = ⟨26, by decide⟩ := Fin.ext hk25
      let clB := (FRef.crAt ⟨26, by decide⟩).pending ++ FRef.outcT.acc.claims.inp
      have hmemB : ∃ z ∈ clB, z.parts = z0.parts := by
        obtain ⟨z, hz, hzp⟩ := hclMem
        exact ⟨z, List.mem_append_left _ (by rw [← hfin, FRef.crAt_succ k]; exact hz), hzp⟩
      rw [hfin]
      refine lookupClaimVal_eq_claimSem 38 14 _ (shdP_bndTableAt_spec _ _ _ _ _ _ _ _ _).rows_len _ _ rfl _ (fun i col => ?_) z0 hmemB
      have h := stdClaim_combAt_eq_of_audit 14 2 32 2 (by norm_num)
        (idxsOf 16 vf (outcBoBase + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
        clB FRef.outcT.haudB
        ((List.range 38).map fun j => challengeFp2Of (vf (outcBoBase + 2 + j)))
        FRef.outcT.hDetB
        (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨26, by decide⟩ y'.1)
        y (c.1.2.1 ⟨26, by decide⟩)
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩).rows
        (shdP_bndTableAt_spec _ _ _ _ _ _ _ _ _).rows_len
        (fun r j hj => shdP_bndTableAt_rows_eq Rp hR hweights hinPub y.1 c ⟨26, by decide⟩ r j (by omega)) i col.val (by omega)
      dsimp only at h; rw [rowAt_mkStdSpec_inl] at h
      rw [show (((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view y ω₁).2.1 ⟨26, by decide⟩).1.1 = _ from
        shdP_D1_view_bnd_outc_fst tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c]
      exact h

/-- Exact `outcCs = outcCsViewOf (D1.view y ω₁)` on every private claim emitted by Stage OUT-C! -/
theorem outcCs_eq_outcCsViewOf {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (ω₁ : ShdL1Coins GF shdP_L1Spec) (t : Fin 8) (p : Exec.Block.Priv)
    (hp : Tab.priv p ∈ (FRef.outcT.dfs t).tabs) :
    let vRef := (classifySpecP Rp (refInput Rp hne verdict).1).getD 0
    let P := (shdVo tag Rp wDigest bOutRow vRef).bp
    let bj := outcSlBase + slotsFixedLen P 0 t.val
    let rhoFull := (List.range (slotN P t.val)).map (fun r => challengeFp2Of (vf (bj + P.draws t.val + 3 + 2 * r + 1)))
    let n := (Exec.Block.slotShape P t.val).1
    let rho := rhoFull.take n
    let es := rhoFull.drop n
    let z0 := Exec.Block.buildClaim P p (Exec.Block.claimPoint p rho)
      (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
    let c := cOfL1 ω₁
    let w := outcWitness_of_adm Rp houtPub y.1.1 y.1.2
    let cs := outcCs (shdP_outcTA Rp w (shdOutcRndOf c))
      (shdP_outcTH Rp w (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero))
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩)
    let D1 := shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
    cs p.cm z0 = outcCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
      (D1.view y ω₁) p.cm z0.parts := by
  intro vRef P bj rhoFull n rho es z0 c
  dsimp only
  have hclMem := (FRef.outcT.slot_spec t).2.2.2.2.2.2.2.2 p hp
  dsimp only at hclMem
  have hVout := shdP_D1_view_outcAH tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c
  cases hcm : p.cm with
  | a =>
    rw [hcm] at hclMem
    unfold outcCsViewOf; dsimp only
    change Link.claimSem shdP_U 76 12 0 (tabMat 76 12 (shdP_outcTA Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c)).rows) z0 = _
    refine lookupClaimVal_eq_claimSem 76 12 _ (shdP_outcTA_rows_len _ _ _) _ _ rfl _ (fun i col => ?_) z0 hclMem
    have h := stdClaim_combAt_eq_of_audit 12 2 16 29 (by norm_num)
      (idxsOf 14 vf (outcAoBase + 122)) (idxsOf_length 14 vf _) (idxsOf_lt 14 vf _)
      FRef.outcT.acc.claims.a FRef.outcT.haudA
      ((List.range 76).map fun j => challengeFp2Of (vf (outcAoBase + 29 + j)))
      FRef.outcT.hDetA (fun y' : AdmAt Rp verdict => outcADat Rp houtPub y'.1) y
      ((c.1.2.2 ⟨27, by decide⟩).1.1, (c.1.2.2 ⟨27, by decide⟩).2.1)
      (shdP_outcTA Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c)).rows (shdP_outcTA_rows_len _ _ _)
      (fun r j hj => shdP_outcTA_rows_eq Rp houtPub y.1 c r j (by omega)) i col.val (by omega)
    dsimp only at h; rw [rowAt_mkStdSpec_inl] at h
    rw [show outcAHViewOf vf ((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view y ω₁) = _ from hVout]
    exact h
  | h =>
    rw [hcm] at hclMem
    unfold outcCsViewOf; dsimp only
    let clH := FRef.outcT.acc.claims.h ++ [(shdVo tag Rp wDigest bOutRow vRef).lay.logupSumClaim]
    have hmemH : ∃ z ∈ clH, z.parts = z0.parts := by
      obtain ⟨z, hz, hzp⟩ := hclMem
      exact ⟨z, List.mem_append_left _ hz, hzp⟩
    change Link.claimSem shdP_U 38 12 0 (tabMat 38 12 (shdP_outcTH Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero)).rows) z0 = _
    refine lookupClaimVal_eq_claimSem 38 12 _ (shdP_outcTH_rows_len _ _ _ _ _) _ _ rfl _ (fun i col => ?_) z0 hmemH
    have h := hClaim_combAt_eq_of_audit (lr := 2)
      (E := pcsEvalMat 12 2 (by norm_num) (dedupIdx (idxsOf 14 vf (outcHoBase + 54)) (idxsOf_lt 14 vf _)))
      clH FRef.outcT.hLenH FRef.outcT.haudH
      ((List.range 38).map fun j => challengeFp2Of (vf (outcHoBase + 10 + j)))
      (outcHDat Rp houtPub (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero) y.1)
      (c.1.2.2 ⟨27, by decide⟩).1.2
      (shdP_outcTH Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero)).rows
      (shdP_outcTH_rows_len _ _ _ _ _)
      (fun r j hj => shdP_outcTH_rows_eq Rp houtPub (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero) y.1 c r j (by omega))
      i col.val (by omega)
    dsimp only at h; rw [rowAt_inl] at h
    rw [show outcAHViewOf vf ((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view y ω₁) = _ from hVout]
    exact h
  | inp =>
    rw [hcm] at hclMem
    unfold outcCsViewOf; dsimp only
    let clB := (FRef.crAt ⟨26, by decide⟩).pending ++ FRef.outcT.acc.claims.inp
    have hmemB : ∃ z ∈ clB, z.parts = z0.parts := by
      obtain ⟨z, hz, hzp⟩ := hclMem
      exact ⟨z, List.mem_append_right _ hz, hzp⟩
    change Link.claimSem shdP_U 38 14 0 (tabMat 38 14 (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩).rows) z0 = _
    refine lookupClaimVal_eq_claimSem 38 14 _ (shdP_bndTableAt_spec _ _ _ _ _ _ _ _ _).rows_len _ _ rfl _ (fun i col => ?_) z0 hmemB
    have h := stdClaim_combAt_eq_of_audit 14 2 32 2 (by norm_num)
      (idxsOf 16 vf (outcBoBase + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
      clB FRef.outcT.haudB
      ((List.range 38).map fun j => challengeFp2Of (vf (outcBoBase + 2 + j)))
      FRef.outcT.hDetB
      (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨26, by decide⟩ y'.1)
      y (c.1.2.1 ⟨26, by decide⟩)
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩).rows
      (shdP_bndTableAt_spec _ _ _ _ _ _ _ _ _).rows_len
      (fun r j hj => shdP_bndTableAt_rows_eq Rp hR hweights hinPub y.1 c ⟨26, by decide⟩ r j (by omega)) i col.val (by omega)
    dsimp only at h; rw [rowAt_mkStdSpec_inl] at h
    rw [show (((shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view y ω₁).2.1 ⟨26, by decide⟩).1.1 = _ from
      shdP_D1_view_bnd_outc_fst tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c]
    exact h
  | out =>
    rfl

/-- Helper: `Fin (shdSegNS ⟨k.val + 1, _⟩)` cast to `Fin 23`. -/
def blkFin (k : Fin 26) (t : Fin (shdSegNS ⟨k.val + 1, by omega⟩)) : Fin 23 :=
  ⟨t.val, by
    have hns : shdSegNS ⟨k.val + 1, by omega⟩ = 23 := by
      unfold shdSegNS; dsimp only; rw [ite_eq_right (by omega), ite_eq_right (by omega)]
    omega⟩

/-- Helper: `slotN P t.val = (shdP_L2Spec s).n t + 1` and `slotD P t.val = (shdP_L2Spec s).d t` for IN-C, Blk, OUT-C. -/
theorem inc_slotND_eq (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (ch : List Fp2) (t : Fin 4) :
    let P := (shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub ch)
    slotN P t.val = (shdP_L2Spec ⟨0, by decide⟩).n t + 1 ∧ slotD P t.val = (shdP_L2Spec ⟨0, by decide⟩).d t :=
  let h := inc_slotShape_eq_L2 tag Rp embDigest bInRow ch t
  ⟨h.1, h.2.1⟩

theorem blk_slotND_eq (tag : MTag) (ioIn ioOut : ℕ) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (k : Fin 26) (t : Fin (shdSegNS ⟨k.val + 1, by omega⟩)) :
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    slotN P t.val = (shdP_L2Spec ⟨k.val + 1, by omega⟩).n t + 1
      ∧ slotD P t.val = (shdP_L2Spec ⟨k.val + 1, by omega⟩).d t := by
  have h := blk_slotShape_eq_L2 tag ioIn ioOut Rp hR k (blkFin k t)
  exact ⟨h.1, h.2.1⟩

theorem outc_slotND_eq (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ)
    (v : ℕ) (t : Fin 8) :
    let P := (shdVo tag Rp wDigest bOutRow v).bp
    slotN P t.val = (shdP_L2Spec ⟨27, by decide⟩).n t + 1 ∧ slotD P t.val = (shdP_L2Spec ⟨27, by decide⟩).d t :=
  let h := outc_slotShape_eq_L2 tag Rp wDigest bOutRow v t
  ⟨h.1, h.2.1⟩

/-- Uniform slot-variable bound `(shdP_L2Spec s).n t + 1 < 64` across all 28 segments (`max = 22`). -/
theorem shdP_L2_slotN_lt_64 (s : Fin 28) (t : Fin (shdSegNS s)) :
    (shdP_L2Spec s).n t + 1 < 64 := by
  have hInc : ∀ u : Fin 4,
      let sh := shdP_incSlots.getD u.val (0, 0, 0)
      sh.1 + sh.2.1 - 1 + 1 < 64 := by decide
  have hOut : ∀ u : Fin 8,
      let sh := Exec.StageFS.outcSlotsR1.getD u.val (0, 0, 0)
      sh.1 + sh.2.1 - 1 + 1 < 64 := by decide
  have hBlk : ∀ u : Fin nSlots,
      let sh := Exec.Block.R13.shieldSlots.getD u.val (0, 0, 0)
      sh.1 + sh.2.1 - 1 + 1 < 64 := by decide
  by_cases h0 : s.val = 0
  · have hns : shdSegNS s = 4 := by unfold shdSegNS; exact ite_eq_left h0
    have ht : t.val < 4 := hns ▸ t.isLt
    simpa only [shdP_L2Spec, shdP_segSlotShape, ite_eq_left h0] using hInc ⟨t.val, ht⟩
  · by_cases h27 : s.val = 27
    · have hns : shdSegNS s = 8 := by unfold shdSegNS; rw [ite_eq_right h0]; exact ite_eq_left h27
      have ht : t.val < 8 := hns ▸ t.isLt
      simpa only [shdP_L2Spec, shdP_segSlotShape, ite_eq_right h0, ite_eq_left h27] using hOut ⟨t.val, ht⟩
    · have hns : shdSegNS s = nSlots := by unfold shdSegNS; rw [ite_eq_right h0]; exact ite_eq_right h27
      have ht : t.val < nSlots := hns ▸ t.isLt
      simpa only [shdP_L2Spec, shdP_segSlotShape, ite_eq_right h0, ite_eq_right h27] using hBlk ⟨t.val, ht⟩

/-- Raw concrete Level-2 `ShdSegL2Data` for Stage IN-C (`s = 0`) at exact opening count `(nodupCols ...).length`. -/
noncomputable def shdP_D2_inc_raw {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) :
    ShdSegL2Data GF shdP_K (AdmAt Rp verdict) (ShdL1Coins GF shdP_L1Spec)
      (ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf))
      (shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view
      (shdSegKind ⟨0, by decide⟩)
      (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) ⟨0, by decide⟩)
      shdP_U (7 : GF) (shdP_L2Spec ⟨0, by decide⟩) (nodupCols (idxsOf 12 vf (incMoBase + 13))).length :=
  let V := shdVi tag Rp embDigest bInRow
  let P0 := V.bp (incCtx V.pub FRef.incT.ch)
  let elog := incElog V.pub 14
  let bjOf : Fin 4 → ℕ := fun t => incSlBase + slotsFixedLen P0 0 t.val
  let ch0Of : Fin 4 → Fp2 := fun t => challengeFp2Of (vf (bjOf t + P0.draws t.val + 1))
  let rhoFullOf : Fin 4 → List Fp2 := fun t =>
    (List.range (slotN P0 t.val)).map (fun r => challengeFp2Of (vf (bjOf t + P0.draws t.val + 3 + 2 * r + 1)))
  let hc0 := shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  let fs0 := FRef.incT.acc.fs ++ FRef.incT.acc.hostFs
  let θ0 := challengeFp2Of (vf incMoBase)
  let rs0 := (List.range (2 * 4 + 2)).map (fun j => challengeFp2Of (vf (incMoBase + 2 + j)))
  let idxs0 := idxsOf 12 vf (incMoBase + 13)
  have hFsCode := slotAcc_codeFuns_hW_hlay ⟨0, by decide⟩ P0 hc0
    (fun t => (inc_slotShape_eq_L2 tag Rp embDigest bInRow FRef.incT.ch t).2.2)
    (fun t => ⟨(inc_slotShape_eq_L2 tag Rp embDigest bInRow FRef.incT.ch t).1,
               (inc_slotShape_eq_L2 tag Rp embDigest bInRow FRef.incT.ch t).2.1⟩)
    (shdP_L2_slotN_lt_64 ⟨0, by decide⟩)
    ch0Of rhoFullOf
    (fun t => by simp only [rhoFullOf, List.length_map, List.length_range]; exact (inc_slotND_eq tag Rp embDigest bInRow FRef.incT.ch t).1)
    FRef.incT.dfs
    (fun t ht => by rw [shdSegKind_inc] at ht; fin_cases t <;> cases ht)
    fs0
    (by
      rw [FRef.incT.fs_terms]
      refine congrArg₂ List.append (List.flatMap_congr fun _ _ => rfl) (List.filterMap_congr fun t _ => ?_)
      rw [(inc_slotShape_eq_L2 tag Rp embDigest bInRow FRef.incT.ch t).2.2])
  have hPub := segMOpenPub_facts ⟨0, by decide⟩ fs0 θ0 rs0 idxs0 (idxsOf_length 12 vf _) (idxsOf_lt 12 vf _)
  have hArith : ∀ (y : AdmAt Rp verdict) (ω₁ : ShdL1Coins GF shdP_L1Spec) (t : Fin 4),
      let c := cOfL1 ω₁
      let cs := incCs (shdP_incTA y.1.1 (shdIncRndOf c)) (shdP_incTH Rp embDigest y.1.1 (shdIncRndOf c) FRef.incT.ch)
        (shdP_epTable (Hdr := Hdr) tag y.1.1 (shdEpBase c)) (shdP_incTB Rp y.1.1 (shdIncRndOf c))
      IndDegLE ((shdP_L2Spec ⟨0, by decide⟩).d t) (slotPolyK P0 elog cs t.val (FRef.incT.dfs t))
        ∧ cubeSum (slotPolyK P0 elog cs t.val (FRef.incT.dfs t)) = 0 := fun y ω₁ t => by
    have hs := FRef.incT.slot_spec t
    dsimp only at hs
    refine incSlot_arith (Hdr := Hdr) tag Rp hinPub hV131072 embDigest bInRow y.1.1 y.1.2
      (shdEpBase (cOfL1 ω₁)) (shdIncRndOf (cOfL1 ω₁)) FRef.incT.ch
      (by rw [FRef.incT.ch_eq]; simp)
      (fun a ha => by rw [FRef.incT.ch_eq] at ha; obtain ⟨_, _, rfl⟩ := List.mem_map.mp ha; exact challengeFp2Of_canon _)
      FRef.incT.hbad t
      (Exec.Block.histOf Fp2.zero Fp2.zero Fp2.zero (FRef.incT.recs.take t.val))
      ((List.range (P0.draws t.val)).map (fun k => challengeFp2Of (vf (bjOf t + k))))
      (fun a ha => by obtain ⟨_, _, rfl⟩ := List.mem_map.mp ha; exact challengeFp2Of_canon _)
      (by simp only [List.length_map, List.length_range]; rfl) (FRef.incT.dfs t) hs.2.1
  { hd := fun t => (shdP_L2_slot_bounds ⟨0, by decide⟩ t).1
    hdc := fun t => (shdP_L2_slot_bounds ⟨0, by decide⟩ t).2.2.1
    c := fun t => (ch0Of t).toK shdP_U
    hc := fun t => fp2_toK_ne_zero_of_isZero_false (challengeFp2Of_canon _) (FRef.incT.slot_spec t).1
    ρ := fun t => vecK shdP_U ((shdP_L2Spec ⟨0, by decide⟩).n t + 1) (rhoFullOf t)
    f := fun y ω₁ t x =>
      let c := cOfL1 ω₁
      let cs := incCs (shdP_incTA y.1.1 (shdIncRndOf c)) (shdP_incTH Rp embDigest y.1.1 (shdIncRndOf c) FRef.incT.ch)
        (shdP_epTable (Hdr := Hdr) tag y.1.1 (shdEpBase c)) (shdP_incTB Rp y.1.1 (shdIncRndOf c))
      slotPolyK P0 elog cs t.val (FRef.incT.dfs t)
        (fun i => x (i.cast (inc_slotND_eq tag Rp embDigest bInRow FRef.incT.ch t).1))
    hf := fun y ω₁ t => by
      have hnd := (inc_slotND_eq tag Rp embDigest bInRow FRef.incT.ch t).1
      exact indDegLE_cast hnd.symm _ (hArith y ω₁ t).1
    hstd := fun y ω₁ t _ => by
      have hnd := (inc_slotND_eq tag Rp embDigest bInRow FRef.incT.ch t).1
      exact (cubeSum_cast hnd.symm _).trans (hArith y ω₁ t).2
    T := fun t v1 =>
      slotPolyFromView P0 elog
        (incCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef v1)
        t.val (FRef.incT.dfs t) (rhoFullOf t)
    hterm := fun y ω₁ t => by
      have hnd := (inc_slotND_eq tag Rp embDigest bInRow FRef.incT.ch t).1
      have hvec : (fun i : Fin (slotN P0 t.val) =>
          vecK shdP_U ((shdP_L2Spec ⟨0, by decide⟩).n t + 1) (rhoFullOf t) (i.cast hnd))
          = vecK shdP_U (slotN P0 t.val) (rhoFullOf t) := by
        funext i; rfl
      dsimp only
      rw [hvec]
      refine slotPolyK_at_vecK_eq_fromView P0 elog _ _ t.val (FRef.incT.dfs t) (rhoFullOf t) (by simp [rhoFullOf])
        (fun a ha => by obtain ⟨_, _, rfl⟩ := List.mem_map.mp ha; exact challengeFp2Of_canon _)
        (fun p hp => incCs_eq_incCsViewOf tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow
          wDigest bOutRow hne verdict vf FRef y ω₁ t p hp)
    hsumH := fun _ _ t ht => by rw [shdSegKind_inc] at ht; fin_cases t <;> cases ht
    θ := θ0.toK shdP_U
    P := segMOpenPub ⟨0, by decide⟩ fs0 θ0 rs0 idxs0 (idxsOf_lt 12 vf _)
    hm := hPub.1
    hmF := hPub.2.1
    hy := hPub.2.2.1
    hsum := hPub.2.2.2.1
    hW := segMOpenPub_hW ⟨0, by decide⟩ fs0 (fun f hf tm htm _ => (hFsCode.1 f hf tm htm).elim fun _ h => h) θ0 rs0 idxs0 (idxsOf_lt 12 vf _)
    hpad := hPub.2.2.2.2
    w := segMaskW ⟨0, by decide⟩
    hlay := segMOpenPub_hlay ⟨0, by decide⟩ hc0 (fun t => (ch0Of t).toK shdP_U)
      (fun t => vecK shdP_U ((shdP_L2Spec ⟨0, by decide⟩).n t + 1) (rhoFullOf t))
      fs0 hFsCode.2.1 (fun f hf tm htm => (hFsCode.1 f hf tm htm).elim fun h _ => h) hFsCode.2.2 θ0 rs0 idxs0 (idxsOf_lt 12 vf _) }

/-- Concrete Level-2 `ShdSegL2Data` for Stage IN-C (`s = 0`). -/
noncomputable def shdP_D2_inc {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) :
    ShdSegL2Data GF shdP_K (AdmAt Rp verdict) (ShdL1Coins GF shdP_L1Spec)
      (ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf))
      (shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view
      (shdSegKind ⟨0, by decide⟩)
      (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) ⟨0, by decide⟩)
      shdP_U (7 : GF) (shdP_L2Spec ⟨0, by decide⟩) (shdP_qs vf ⟨0, by decide⟩) :=
  shdSegL2DataCast (shdP_qs_zero vf).symm
    (shdP_D2_inc_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef)

/-- Raw concrete Level-2 `ShdSegL2Data` for interior block `k : Fin 26` (`s = k + 1`) at exact opening count `(nodupCols ...).length`. -/
noncomputable def shdP_D2_blk_raw {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) (k : Fin 26) :
    ShdSegL2Data GF shdP_K (AdmAt Rp verdict) (ShdL1Coins GF shdP_L1Spec)
      (ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf))
      (shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view
      (shdSegKind ⟨k.val + 1, by omega⟩)
      (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) ⟨k.val + 1, by omega⟩)
      shdP_U (7 : GF) (shdP_L2Spec ⟨k.val + 1, by omega⟩) (nodupCols (idxsOf 12 vf (blkMoBase k + 51))).length :=
  let s : Fin 28 := ⟨k.val + 1, by omega⟩
  let P0 := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
  have hP0eq : shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
      = shdP_blkParams tag ioIn ioOut (checkField shdP_blkOpenGeom) (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) :=
    ZK60.ProtocolClassify.shdP_Pk0_eq_blkParams tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR k.val k.isLt
  let bjOf : Fin (shdSegNS s) → ℕ := fun t => blkSlBase k + slotsFixedLen P0 0 t.val
  let ch0Of : Fin (shdSegNS s) → Fp2 := fun t => challengeFp2Of (vf (bjOf t + P0.draws t.val + 1))
  let rhoFullOf : Fin (shdSegNS s) → List Fp2 := fun t =>
    (List.range (slotN P0 t.val)).map (fun r => challengeFp2Of (vf (bjOf t + P0.draws t.val + 3 + 2 * r + 1)))
  let hc0 := shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  let fs0 := (FRef.blkT k).acc.fs ++ (FRef.blkT k).acc.hostFs
  let θ0 := challengeFp2Of (vf (blkMoBase k))
  let rs0 := (List.range (2 * 23 + 2)).map (fun j => challengeFp2Of (vf (blkMoBase k + 2 + j)))
  let idxs0 := idxsOf 12 vf (blkMoBase k + 51)
  have hns : shdSegNS s = 23 := by unfold shdSegNS s; dsimp only; rw [ite_eq_right (by omega), ite_eq_right (by omega)]
  have hHostedBlk : ∀ t : Fin (shdSegNS s),
      ((FRef.blkT k).dfs (blkFin k t)).hosted.map Prod.fst = hostsOf t.val := fun t => by
    have hdef := ((FRef.blkT k).slot_spec (blkFin k t)).2.1
    rw [hP0eq] at hdef
    exact shdP_blk_hosted_fst tag ioIn ioOut (checkField shdP_blkOpenGeom) (shdP_layer k.val k.isLt)
      (shdP_blkPub Rp hR k.val k.isLt) t.val (blkFin k t).isLt _ _ _ hdef
  have hHostAlign : ∀ t : Fin (shdSegNS s),
      ((FRef.blkT k).dfs (blkFin k t)).hosted.map (fun hk => (hk.1, hk.2.toK shdP_U))
        = (shdSegHosts hc0 s t).map (fun p => (p.1.val, p.2))
      ∧ ∀ hk ∈ ((FRef.blkT k).dfs (blkFin k t)).hosted, hk.1 < t.val := fun t => by
    refine ⟨?_, ?_⟩
    · have hm := hosted_map_eq_w16Hosts ((FRef.blkT k).dfs (blkFin k t)).hosted (blkFin k t) (hHostedBlk t)
      unfold shdSegHosts
      rw [dite_eq_right (by dsimp [s]; omega), dite_eq_right (by dsimp [s]; omega), List.map_map]
      have hkSub : (⟨s.val - 1, by dsimp [s]; omega⟩ : Fin 26) = k := Fin.ext (Nat.add_sub_cancel k.val 1)
      have htCast : (t.cast (by dsimp only [shdSegNS, s]; rw [ite_eq_right (by omega), ite_eq_right (by omega)]) : Fin nSlots) = blkFin k t :=
        Fin.ext rfl
      rw [hkSub, htCast]
      have hcomp : ((fun p : Fin (shdSegNS s) × shdP_K => (p.1.val, p.2)) ∘
          fun p : Fin nSlots × shdP_K => (p.1.cast hns.symm, p.2)) = fun p : Fin nSlots × shdP_K => (p.1.val, p.2) := rfl
      simpa only [hcomp, w16Hosts, hc0, shdP_hc] using hm
    · intro hk hmem
      have hfst : hk.1 ∈ hostsOf t.val := by
        rw [← hHostedBlk t]; exact List.mem_map.mpr ⟨hk, hmem, rfl⟩
      have hltHosts : ∀ u < 23, ∀ v ∈ hostsOf u, v < u := by decide
      exact hltHosts t.val (blkFin k t).isLt hk.1 hfst
  have hKindEq : ∀ t : Fin (shdSegNS s), P0.kind t.val = match shdSegKind s t with
      | .standalone => SlotKind.standalone | .priv => SlotKind.priv | .host => SlotKind.host := fun t => by
    have h := (blk_slotShape_eq_L2 tag ioIn ioOut Rp hR k (blkFin k t)).2.2
    have hsk : shdSegKind s t = kindOf (blkFin k t).val := by
      unfold shdSegKind; rw [dite_eq_right (by dsimp [s]; omega), dite_eq_right (by dsimp [s]; omega)]; rfl
    rw [hsk]; exact h
  have hFsCode := slotAcc_codeFuns_hW_hlay s P0 hc0 hKindEq
    (fun t => blk_slotND_eq tag ioIn ioOut Rp hR k t)
    (shdP_L2_slotN_lt_64 s)
    ch0Of rhoFullOf
    (fun t => by simp only [rhoFullOf, List.length_map, List.length_range]; exact (blk_slotND_eq tag ioIn ioOut Rp hR k t).1)
    (fun t => (FRef.blkT k).dfs (blkFin k t))
    (fun t _ => hHostAlign t)
    fs0
    (by
      rw [(FRef.blkT k).fs_terms]
      have hfinEq : ∀ {α : Type} (f : Fin (shdSegNS s) → α) (g : Fin 23 → α),
          (∀ t : Fin (shdSegNS s), f t = g (blkFin k t)) →
          (List.finRange (shdSegNS s)).map f = (List.finRange 23).map g := fun f g hfg => by
        refine List.ext_getElem (by simp [hns]) fun i hi1 hi2 => ?_
        simp only [List.getElem_map, List.getElem_finRange]
        exact hfg ⟨i, by simpa using hi1⟩
      have h1 : (List.finRange 23).flatMap (fun t : Fin 23 =>
          let bj := blkSlBase k + slotsFixedLen P0 0 t.val
          let ch0 := challengeFp2Of (vf (bj + P0.draws t.val + 1))
          let rhoFull := (List.range (slotN P0 t.val)).map (fun r => challengeFp2Of (vf (bj + P0.draws t.val + 3 + 2 * r + 1)))
          let nd := Exec.Block.slotShape P0 t.val
          let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch0)
          let ev := [(t.val, Cfs.evalWeights rhoFull nd.2.2)]
          match P0.kind t.val with | .standalone => [[(t.val, sw)], ev] | _ => [ev])
        = (List.finRange (shdSegNS s)).flatMap (fun t =>
          let nd := Exec.Block.slotShape P0 t.val
          let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul (ch0Of t))
          let ev := [(t.val, Cfs.evalWeights (rhoFullOf t) nd.2.2)]
          match P0.kind t.val with | .standalone => [[(t.val, sw)], ev] | _ => [ev]) := by
        have hfm : ∀ {α β : Type} (f : α → List β) (l : List α), l.flatMap f = (l.map f).flatten := fun f l => by
          induction l with | nil => rfl | cons a as ih => simp [ih]
        rw [hfm, hfm]
        exact congrArg List.flatten (hfinEq _ _ fun _ => rfl).symm
      have h2 : (List.finRange 23).filterMap (fun t : Fin 23 =>
          let bj := blkSlBase k + slotsFixedLen P0 0 t.val
          let ch0 := challengeFp2Of (vf (bj + P0.draws t.val + 1))
          let nd := Exec.Block.slotShape P0 t.val
          let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch0)
          match P0.kind t.val with
          | .host =>
            some ((t.val, sw) :: ((FRef.blkT k).dfs t).hosted.map fun hk =>
              (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P0 hk.1).1 + (Exec.Block.slotShape P0 hk.1).2.1)
                (Exec.Block.slotShape P0 hk.1).2.2).map
                  (fun w => w.mul (hk.2.mul (((FRef.blkT k).accs t).cs.getD hk.1 Fp2.zero)).neg)))
          | _ => none)
        = (List.finRange (shdSegNS s)).filterMap (fun t =>
          let nd := Exec.Block.slotShape P0 t.val
          let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul (ch0Of t))
          match P0.kind t.val with
          | .host =>
            some ((t.val, sw) :: ((FRef.blkT k).dfs (blkFin k t)).hosted.map fun hk =>
              (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P0 hk.1).1 + (Exec.Block.slotShape P0 hk.1).2.1)
                (Exec.Block.slotShape P0 hk.1).2.2).map
                  (fun w => w.mul (hk.2.mul (if h : hk.1 < shdSegNS s then ch0Of ⟨hk.1, h⟩ else Fp2.zero)).neg)))
          | _ => none) := by
        have hfm2 : ∀ {α β : Type} (f : α → Option β) (l : List α), l.filterMap f = (l.map f).filterMap id := fun f l => by
          simp [List.filterMap_map]
        rw [hfm2 (l := List.finRange 23), hfm2 (l := List.finRange (shdSegNS s))]
        refine congrArg (List.filterMap id) (hfinEq _ _ fun t => ?_).symm
        dsimp only [blkFin, ch0Of, bjOf, blkSlBase]
        cases hkP : P0.kind t.val with
        | standalone => rfl
        | priv => rfl
        | host =>
          refine congrArg Option.some (congrArg ((t.val, _) :: ·) (List.map_congr_left fun hk hmem => ?_))
          have hlt := (hHostAlign t).2 hk hmem
          have hltS : hk.1 < shdSegNS s := lt_trans hlt t.isLt
          rw [dite_eq_left hltS]
          have hcsAcc : ((FRef.blkT k).accs (blkFin k t)).cs = (FRef.blkT k).acc.cs.take t.val :=
            ((FRef.blkT k).slot_spec (blkFin k t)).2.2.1
          have hcsGet : ((FRef.blkT k).accs (blkFin k t)).cs.getD hk.1 Fp2.zero = ch0Of ⟨hk.1, hltS⟩ := by
            rw [hcsAcc, List.getD_eq_getElem?_getD, List.getElem?_take_of_lt hlt,
              List.getElem?_eq_getElem (by rw [(FRef.blkT k).cs_len]; omega), Option.getD_some]
            exact ((FRef.blkT k).slot_spec ⟨hk.1, by omega⟩).2.2.2.2.1
          dsimp only [blkFin, ch0Of, bjOf, blkSlBase] at hcsGet
          rw [hcsGet]
      dsimp only [blkSlBase] at h1 h2 ⊢
      exact congrArg₂ List.append h1 h2)
  have hPub := segMOpenPub_facts s fs0 θ0 rs0 idxs0 (idxsOf_length 12 vf _) (idxsOf_lt 12 vf _)
  { hd := fun t => (shdP_L2_slot_bounds s t).1
    hdc := fun t => (shdP_L2_slot_bounds s t).2.2.1
    c := fun t => (ch0Of t).toK shdP_U
    hc := fun t => fp2_toK_ne_zero_of_isZero_false (challengeFp2Of_canon _) ((FRef.blkT k).slot_spec (blkFin k t)).1
    ρ := fun t => vecK shdP_U ((shdP_L2Spec s).n t + 1) (rhoFullOf t)
    f := fun y ω₁ t x =>
      let c := cOfL1 ω₁
      let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt
      let cs := blkCs (blkTA w (shdBlkRndOf c k)) (blkTH w (shdBlkRndOf c k) (FRef.blkT k).bga)
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
      blkSlotPolyK P0 cs t.val ((FRef.blkT k).dfs (blkFin k t))
        (fun i => x (i.cast (blk_slotND_eq tag ioIn ioOut Rp hR k t).1))
    hf := fun y ω₁ t => by
      have hnd := blk_slotND_eq tag ioIn ioOut Rp hR k t
      have hdef := ((FRef.blkT k).slot_spec (blkFin k t)).2.1
      rw [hP0eq] at hdef
      have hind := blk_slot_indDeg tag ioIn ioOut (checkField shdP_blkOpenGeom)
        (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt)
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf (cOfL1 ω₁)) (shdBlkRndOf (cOfL1 ω₁)) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf (cOfL1 ω₁)) (shdBlkRndOf (cOfL1 ω₁)) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
        (shdBlkRndOf (cOfL1 ω₁) k) (FRef.blkT k).bga t.val (blkFin k t).isLt _ _ _ hdef
      dsimp only at hind
      rw [← hP0eq, hnd.2] at hind
      exact indDegLE_cast hnd.1.symm _ hind
    hstd := fun y ω₁ t hkind => by
      have hnd := (blk_slotND_eq tag ioIn ioOut Rp hR k t).1
      have hdef := ((FRef.blkT k).slot_spec (blkFin k t)).2.1
      have hkSa : (shdP_blkParams tag ioIn ioOut (checkField shdP_blkOpenGeom) (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt)).kind t.val = SlotKind.standalone := by
        rw [← hP0eq]; exact (hKindEq t).trans (by rw [hkind])
      rw [hP0eq] at hdef
      have hαCan : (FRef.blkT k).bga.2.2.Canon := by rw [(FRef.blkT k).bga_eq]; exact challengeFp2Of_canon _
      have h0 := blk_standalone_cubeSum_eq_zero tag ioIn ioOut (checkField shdP_blkOpenGeom)
        (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt)
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf (cOfL1 ω₁)) (shdBlkRndOf (cOfL1 ω₁)) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf (cOfL1 ω₁)) (shdBlkRndOf (cOfL1 ω₁)) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
        (shdBlkRndOf (cOfL1 ω₁) k) (FRef.blkT k).bga
        (shdP_bndTableAt_spec Rp hR hweights hinPub _ _ y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
        (shdP_bndTableAt_spec Rp hR hweights hinPub _ _ y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
        (shdP_blkState_i16 Rp hR hweights hinPub y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
        (shdP_blkState_i16 Rp hR hweights hinPub y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
        hαCan (FRef.blkT k).hbad t.val (blkFin k t).isLt hkSa _ rfl _ _ hdef
      dsimp only at h0
      rw [← hP0eq] at h0
      exact (cubeSum_cast hnd.symm _).trans h0
    T := fun t v1 =>
      blkSlotPolyFromView P0
        (blkCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef k v1)
        t.val ((FRef.blkT k).dfs (blkFin k t)) (rhoFullOf t)
    hterm := fun y ω₁ t => by
      have hnd := (blk_slotND_eq tag ioIn ioOut Rp hR k t).1
      have hvec : (fun i : Fin (slotN P0 t.val) =>
          vecK shdP_U ((shdP_L2Spec s).n t + 1) (rhoFullOf t) (i.cast hnd))
          = vecK shdP_U (slotN P0 t.val) (rhoFullOf t) := by
        funext i; rfl
      dsimp only
      rw [hvec]
      refine blkSlotPolyK_at_vecK_eq_fromView P0 _ _ t.val ((FRef.blkT k).dfs (blkFin k t)) (rhoFullOf t) (by simp [rhoFullOf])
        (fun a ha => by obtain ⟨_, _, rfl⟩ := List.mem_map.mp ha; exact challengeFp2Of_canon _)
        (fun p hp => blkCs_eq_blkCsViewOf tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow
          wDigest bOutRow hne verdict vf FRef k y ω₁ (blkFin k t) p hp)
    hsumH := fun y ω₁ t hkind => by
      have hnd := (blk_slotND_eq tag ioIn ioOut Rp hR k t).1
      have hdef := ((FRef.blkT k).slot_spec (blkFin k t)).2.1
      let Pblk := shdP_blkParams tag ioIn ioOut (checkField shdP_blkOpenGeom) (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt)
      have hkH : Pblk.kind t.val = SlotKind.host := by
        dsimp only [Pblk]; rw [← hP0eq]; exact (hKindEq t).trans (by rw [hkind])
      rw [hP0eq] at hdef
      have hβCan : (FRef.blkT k).bga.1.Canon := by rw [(FRef.blkT k).bga_eq]; exact challengeFp2Of_canon _
      have hαCan : (FRef.blkT k).bga.2.2.Canon := by rw [(FRef.blkT k).bga_eq]; exact challengeFp2Of_canon _
      have hrecsLen : ((FRef.blkT k).recs.take t.val).length = t.val := by
        rw [List.length_take, (FRef.blkT k).recs_len]; have : t.val < 23 := (blkFin k t).isLt; omega
      have hrecsDef : ∀ j r, ((FRef.blkT k).recs.take t.val)[j]? = some r →
          ∃ df', Pblk.define j
            (Exec.Block.histOf (FRef.blkT k).bga.1 (FRef.blkT k).bga.2.1 (FRef.blkT k).bga.2.2 (((FRef.blkT k).recs.take t.val).take j)) r.draws = .ok df'
            ∧ (Pblk.kind j = SlotKind.host ↔ df'.hosted ≠ []) := by
        intro j r hjr
        have hjlt : j < t.val := by
          by_contra hge
          rw [List.getElem?_eq_none (by rw [hrecsLen]; omega)] at hjr; cases hjr
        have hj23 : j < 23 := lt_trans hjlt (blkFin k t).isLt
        rw [List.getElem?_take_of_lt hjlt, List.getElem?_eq_getElem (by rw [(FRef.blkT k).recs_len]; exact hj23)] at hjr
        have hrEq : r = (FRef.blkT k).recs[j]'(by rw [(FRef.blkT k).recs_len]; exact hj23) := (Option.some.inj hjr).symm
        have hspJ := (FRef.blkT k).slot_spec ⟨j, hj23⟩
        have htake : ((FRef.blkT k).recs.take t.val).take j = (FRef.blkT k).recs.take j := by
          rw [List.take_take, Nat.min_eq_left (Nat.le_of_lt hjlt)]
        refine ⟨(FRef.blkT k).dfs ⟨j, hj23⟩, ?_, ?_⟩
        · dsimp only [Pblk]; rw [htake, hrEq, hspJ.2.2.2.1, ← hP0eq]; exact hspJ.2.1
        · have hfstJ : ((FRef.blkT k).dfs ⟨j, hj23⟩).hosted.map Prod.fst = hostsOf j := by
            have hd := hspJ.2.1; rw [hP0eq] at hd
            exact shdP_blk_hosted_fst tag ioIn ioOut (checkField shdP_blkOpenGeom) (shdP_layer k.val k.isLt)
              (shdP_blkPub Rp hR k.val k.isLt) j hj23 _ _ _ hd
          change shdP_slotKind j = SlotKind.host ↔ ((FRef.blkT k).dfs ⟨j, hj23⟩).hosted ≠ []
          constructor
          · intro hkh hnil; rw [hnil] at hfstJ; interval_cases j <;> simp [shdP_slotKind, hostsOf] at hkh hfstJ
          · intro hneL; by_contra hnh
            have : hostsOf j = [] := by interval_cases j <;> simp [shdP_slotKind, hostsOf] at hnh ⊢
            rw [this] at hfstJ; exact hneL (List.map_eq_nil_iff.mp hfstJ)
      let c := cOfL1 ω₁
      let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt
      let TBp := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
      let TBn := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
      let cs := blkCs (blkTA w (shdBlkRndOf c k)) (blkTH w (shdBlkRndOf c k) (FRef.blkT k).bga) TBp TBn
      let polyBlk := Exec.Block.polyS shdP_U Pblk (blkCmData Pblk rfl rfl (blkTA w (shdBlkRndOf c k)) (blkTH w (shdBlkRndOf c k) (FRef.blkT k).bga) TBp TBn)
        (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 (shdP_layer k.val k.isLt)) ioIn ioOut)
        (pubsR13L (Exec.Block.DefR13.cfgShieldR13 (shdP_layer k.val k.isLt)) (shdP_blkPub Rp hR k.val k.isLt)
          (shdP_bitLay (shdP_layer k.val k.isLt)) (shdP_w16Pub (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt))
          (shieldShape (shdP_layer k.val k.isLt)).nG)
      have hH := blk_host_cubeSum_eq_hosted tag ioIn ioOut (checkField shdP_blkOpenGeom) w TBp TBn
        (shdBlkRndOf c k) (FRef.blkT k).bga hβCan hαCan (FRef.blkT k).hbad t.val (blkFin k t).isLt hkH
        ((FRef.blkT k).recs.take t.val) hrecsLen hrecsDef _ _ hdef
      dsimp only at hH
      have hL : cubeSum (fun x => blkSlotPolyK P0 cs t.val ((FRef.blkT k).dfs (blkFin k t)) (fun i => x (i.cast hnd)))
          = cubeSum (blkSlotPolyK P0 cs t.val ((FRef.blkT k).dfs (blkFin k t))) :=
        cubeSum_cast hnd.symm (blkSlotPolyK P0 cs t.val ((FRef.blkT k).dfs (blkFin k t)))
      have hH' : cubeSum (blkSlotPolyK P0 cs t.val ((FRef.blkT k).dfs (blkFin k t)))
          = (((FRef.blkT k).dfs (blkFin k t)).hosted.map fun hk =>
              hk.2.toK shdP_U * Exec.Block.spSum Pblk polyBlk (FRef.blkT k).bga ((FRef.blkT k).recs.take t.val) hk.1).sum := by
        dsimp only [P0]; rw [hP0eq]; exact hH
      have hspMatch : ∀ (hk : ℕ × Fp2) (hmem : hk ∈ ((FRef.blkT k).dfs (blkFin k t)).hosted),
          Exec.Block.spSum Pblk polyBlk (FRef.blkT k).bga ((FRef.blkT k).recs.take t.val) hk.1
          = cubeSum (fun x => blkSlotPolyK P0 cs hk.1 ((FRef.blkT k).dfs ⟨hk.1, lt_trans ((hHostAlign t).2 hk hmem) (blkFin k t).isLt⟩)
              (fun i => x (i.cast (blk_slotND_eq tag ioIn ioOut Rp hR k ⟨hk.1, lt_trans ((hHostAlign t).2 hk hmem) t.isLt⟩).1))) := by
        intro hk hmem
        have hlt := (hHostAlign t).2 hk hmem
        have hj23 : hk.1 < 23 := lt_trans hlt (blkFin k t).isLt
        have hndU := (blk_slotND_eq tag ioIn ioOut Rp hR k ⟨hk.1, lt_trans hlt t.isLt⟩).1
        have hR_sum : cubeSum (fun x => blkSlotPolyK P0 cs hk.1 ((FRef.blkT k).dfs ⟨hk.1, hj23⟩) (fun i => x (i.cast hndU)))
            = cubeSum (blkSlotPolyK P0 cs hk.1 ((FRef.blkT k).dfs ⟨hk.1, hj23⟩)) :=
          cubeSum_cast hndU.symm (blkSlotPolyK P0 cs hk.1 ((FRef.blkT k).dfs ⟨hk.1, hj23⟩))
        rw [hR_sum]; dsimp only [P0]; rw [hP0eq]
        unfold Exec.Block.spSum
        congr 1; funext x
        have hprogOK : Exec.Block.progOKb (Exec.Block.rowLog Pblk)
            (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 (shdP_layer k.val k.isLt)) ioIn ioOut)
            Pblk.geom.slots = true :=
          progR13_shield_okP (shdP_layer k.val k.isLt) w.hLy Pblk rfl (by show 0 < 14; norm_num) (by show 0 < 14; norm_num) ioIn ioOut
        have hspJ := (FRef.blkT k).slot_spec ⟨hk.1, hj23⟩
        have hdefJ := hspJ.2.1; rw [hP0eq] at hdefJ
        have hAt : ((FRef.blkT k).recs.take t.val)[hk.1]? = some ((FRef.blkT k).recs[hk.1]'(by rw [(FRef.blkT k).recs_len]; exact hj23)) := by
          rw [List.getElem?_take_of_lt hlt, List.getElem?_eq_getElem (by rw [(FRef.blkT k).recs_len]; exact hj23)]
        have hTake : ((FRef.blkT k).recs.take t.val).take hk.1 = (FRef.blkT k).recs.take hk.1 := by
          rw [List.take_take, Nat.min_eq_left (Nat.le_of_lt hlt)]
        exact (blkSlotPolyK_eq_polyS Pblk (blkCmData Pblk rfl rfl (blkTA w (shdBlkRndOf c k)) (blkTH w (shdBlkRndOf c k) (FRef.blkT k).bga) TBp TBn)
          cs (blkCs_eq_claimSem Pblk rfl rfl _ _ _ _) _ _ rfl hprogOK hk.1
          (Exec.Block.seenOf (FRef.blkT k).bga ((FRef.blkT k).recs.take t.val) hk.1)
          ((FRef.blkT k).dfs ⟨hk.1, hj23⟩)
          (by rw [Exec.Block.histSeen_seenOf, hTake, Exec.Block.drSeen_seenOf _ _ _ _ hAt, hspJ.2.2.2.1]; dsimp only [Pblk]; rw [← hP0eq]; exact hspJ.2.1)
          (shdP_blk_tabsLenOk tag ioIn ioOut (checkField shdP_blkOpenGeom) (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt)
            hk.1 hj23 _ _ _ hdefJ) x).symm
      have hmapEq :
          (((FRef.blkT k).dfs (blkFin k t)).hosted.map fun hk =>
            hk.2.toK shdP_U * Exec.Block.spSum Pblk polyBlk (FRef.blkT k).bga ((FRef.blkT k).recs.take t.val) hk.1)
          = (shdSegHosts hc0 s t).map fun p =>
              p.2 * cubeSum (fun x => blkSlotPolyK P0 cs p.1.val ((FRef.blkT k).dfs (blkFin k p.1))
                (fun i => x (i.cast (blk_slotND_eq tag ioIn ioOut Rp hR k p.1).1))) := by
        let Gfn : ℕ × shdP_K → shdP_K := fun p =>
          if h : p.1 < shdSegNS s then
            p.2 * cubeSum (fun x => blkSlotPolyK P0 cs p.1 ((FRef.blkT k).dfs (blkFin k ⟨p.1, h⟩))
              (fun i => x (i.cast (blk_slotND_eq tag ioIn ioOut Rp hR k ⟨p.1, h⟩).1)))
          else 0
        have hL1 : (((FRef.blkT k).dfs (blkFin k t)).hosted.map fun hk =>
              hk.2.toK shdP_U * Exec.Block.spSum Pblk polyBlk (FRef.blkT k).bga ((FRef.blkT k).recs.take t.val) hk.1)
            = (((FRef.blkT k).dfs (blkFin k t)).hosted.map (fun hk => (hk.1, hk.2.toK shdP_U))).map Gfn := by
          rw [List.map_map]
          refine List.map_congr_left fun hk hmem => ?_
          have hltS : hk.1 < shdSegNS s := lt_trans ((hHostAlign t).2 hk hmem) t.isLt
          simp only [Function.comp_apply, Gfn, dite_eq_left hltS]
          rw [hspMatch hk hmem]; rfl
        have hR1 : ((shdSegHosts hc0 s t).map (fun p => (p.1.val, p.2))).map Gfn
            = (shdSegHosts hc0 s t).map fun p =>
                p.2 * cubeSum (fun x => blkSlotPolyK P0 cs p.1.val ((FRef.blkT k).dfs (blkFin k p.1))
                  (fun i => x (i.cast (blk_slotND_eq tag ioIn ioOut Rp hR k p.1).1))) := by
          rw [List.map_map]
          refine List.map_congr_left fun p _ => by simp [Gfn, p.1.isLt]
        rw [hL1, (hHostAlign t).1, hR1]
      rw [hL, hH', hmapEq]
    θ := θ0.toK shdP_U
    P := segMOpenPub s fs0 θ0 rs0 idxs0 (idxsOf_lt 12 vf _)
    hm := hPub.1
    hmF := hPub.2.1
    hy := hPub.2.2.1
    hsum := hPub.2.2.2.1
    hW := segMOpenPub_hW s fs0 (fun f hf tm htm _ => (hFsCode.1 f hf tm htm).elim fun _ h => h) θ0 rs0 idxs0 (idxsOf_lt 12 vf _)
    hpad := hPub.2.2.2.2
    w := segMaskW s
    hlay := segMOpenPub_hlay s hc0 (fun t => (ch0Of t).toK shdP_U)
      (fun t => vecK shdP_U ((shdP_L2Spec s).n t + 1) (rhoFullOf t))
      fs0 hFsCode.2.1 (fun f hf tm htm => (hFsCode.1 f hf tm htm).elim fun h _ => h) hFsCode.2.2 θ0 rs0 idxs0 (idxsOf_lt 12 vf _) }

/-- Concrete Level-2 `ShdSegL2Data` for interior block `k : Fin 26` (`s = k + 1`). -/
noncomputable def shdP_D2_blk {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) (k : Fin 26) :
    ShdSegL2Data GF shdP_K (AdmAt Rp verdict) (ShdL1Coins GF shdP_L1Spec)
      (ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf))
      (shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view
      (shdSegKind ⟨k.val + 1, by omega⟩)
      (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) ⟨k.val + 1, by omega⟩)
      shdP_U (7 : GF) (shdP_L2Spec ⟨k.val + 1, by omega⟩) (shdP_qs vf ⟨k.val + 1, by omega⟩) :=
  shdSegL2DataCast (shdP_qs_blk vf k).symm
    (shdP_D2_blk_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef k)

/-- Raw concrete Level-2 `ShdSegL2Data` for Stage OUT-C (`s = 27`) at exact opening count `(nodupCols ...).length`. -/
noncomputable def shdP_D2_outc_raw {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) :
    ShdSegL2Data GF shdP_K (AdmAt Rp verdict) (ShdL1Coins GF shdP_L1Spec)
      (ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf))
      (shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view
      (shdSegKind ⟨27, by decide⟩)
      (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) ⟨27, by decide⟩)
      shdP_U (7 : GF) (shdP_L2Spec ⟨27, by decide⟩) (nodupCols (idxsOf 12 vf (outcMoBase + 21))).length :=
  let s : Fin 28 := ⟨27, by decide⟩
  let vRef := (classifySpecP Rp (refInput Rp hne verdict).1).getD 0
  let P0 := (shdVo tag Rp wDigest bOutRow vRef).bp
  let bjOf : Fin 8 → ℕ := fun t => outcSlBase + slotsFixedLen P0 0 t.val
  let ch0Of : Fin 8 → Fp2 := fun t => challengeFp2Of (vf (bjOf t + P0.draws t.val + 1))
  let rhoFullOf : Fin 8 → List Fp2 := fun t =>
    (List.range (slotN P0 t.val)).map (fun r => challengeFp2Of (vf (bjOf t + P0.draws t.val + 3 + 2 * r + 1)))
  let hc0 := shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  let fs0 := FRef.outcT.acc.fs ++ FRef.outcT.acc.hostFs
  let θ0 := challengeFp2Of (vf outcMoBase)
  let rs0 := (List.range (2 * 8 + 2)).map (fun j => challengeFp2Of (vf (outcMoBase + 2 + j)))
  let idxs0 := idxsOf 12 vf (outcMoBase + 21)
  have hArith : ∀ (y : AdmAt Rp verdict) (ω₁ : ShdL1Coins GF shdP_L1Spec) (t : Fin 8),
      let c := cOfL1 ω₁
      let w := outcWitness_of_adm Rp houtPub y.1.1 y.1.2
      let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩
      let cs := outcCs (shdP_outcTA Rp w (shdOutcRndOf c))
        (shdP_outcTH Rp w (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero)) TB26
      IndDegLE ((shdP_L2Spec s).d t) (slotPolyK P0 (fun _ => 14) cs t.val (FRef.outcT.dfs t))
        ∧ (outcKind t = .standalone → cubeSum (slotPolyK P0 (fun _ => 14) cs t.val (FRef.outcT.dfs t)) = 0)
        ∧ (outcKind t = .priv → cubeSum (slotPolyK P0 (fun _ => 14) cs t.val (FRef.outcT.dfs t)) = outcPrivSum Rp w t.val)
        ∧ (t.val = 2 → cubeSum (slotPolyK P0 (fun _ => 14) cs t.val (FRef.outcT.dfs t)) = ((FRef.outcT.recs[2]'(by rw [FRef.outcT.recs_len]; omega)).draws.getD 5 Fp2.zero).toK shdP_U * outcPrivSum Rp w 1
            ∧ (FRef.outcT.dfs t).hosted = [(1, (FRef.outcT.recs[2]'(by rw [FRef.outcT.recs_len]; omega)).draws.getD 5 Fp2.zero)])
        ∧ (t.val = 4 → cubeSum (slotPolyK P0 (fun _ => 14) cs t.val (FRef.outcT.dfs t)) = ((FRef.outcT.recs[4]'(by rw [FRef.outcT.recs_len]; omega)).draws.getD 14 Fp2.zero).toK shdP_U * outcPrivSum Rp w 3
            ∧ (FRef.outcT.dfs t).hosted = [(3, (FRef.outcT.recs[4]'(by rw [FRef.outcT.recs_len]; omega)).draws.getD 14 Fp2.zero)]) := fun y ω₁ t => by
    have hvEq : (outcWitness_of_adm Rp houtPub y.1.1 y.1.2).v = vRef := by
      have h1 := outcWitness_of_adm_v Rp houtPub y.1.1 y.1.2
      have h2 := refInput_verdict_eq Rp hne verdict y
      exact h1.trans h2.symm
    have hsp := FRef.outcT.slot_spec t
    dsimp only at hsp
    let dr := (List.range (P0.draws t.val)).map (fun j => challengeFp2Of (vf (bjOf t + j)))
    have hdefW : (shdVo tag Rp wDigest bOutRow (outcWitness_of_adm Rp houtPub y.1.1 y.1.2).v).bp.define t.val
        (Exec.Block.histOf (OutcV.bga FRef.outcT.ch).1 (OutcV.bga FRef.outcT.ch).2.1 (OutcV.bga FRef.outcT.ch).2.2 (FRef.outcT.recs.take t.val))
        dr = .ok (FRef.outcT.dfs t) := by
      rw [hvEq]; exact hsp.2.1
    have hOA := outcSlot_arith tag Rp houtPub wDigest bOutRow (outcWitness_of_adm Rp houtPub y.1.1 y.1.2)
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf (cOfL1 ω₁)) (shdBlkRndOf (cOfL1 ω₁)) y.1.1 y.1.2 ⟨26, by decide⟩)
      (shdP_bndTableAt_last_outcSpec Rp hR hweights hinPub houtPub _ _ y.1.1 y.1.2)
      (shdOutcRndOf (cOfL1 ω₁)) FRef.outcT.ch
      (fun a ha => by rw [FRef.outcT.ch_eq] at ha; obtain ⟨_, _, rfl⟩ := List.mem_map.mp ha; exact challengeFp2Of_canon _)
      FRef.outcT.hbad t (FRef.outcT.recs.take t.val) dr
      (fun a ha => by obtain ⟨_, _, rfl⟩ := List.mem_map.mp ha; exact challengeFp2Of_canon _)
      (by simp only [dr, P0, List.length_map, List.length_range]; rw [hvEq]) (FRef.outcT.dfs t) hdefW
    rw [hvEq] at hOA
    refine ⟨hOA.1, hOA.2.1, hOA.2.2.1, ?_, ?_⟩
    · intro ht2
      have hdr2 : (FRef.outcT.recs[2]'(by rw [FRef.outcT.recs_len]; omega)).draws = dr := by
        have htEq : t = ⟨2, by decide⟩ := Fin.ext ht2
        subst htEq; exact hsp.2.2.2.1
      rw [hdr2]; exact hOA.2.2.2.1 ht2
    · intro ht4
      have hdr4 : (FRef.outcT.recs[4]'(by rw [FRef.outcT.recs_len]; omega)).draws = dr := by
        have htEq : t = ⟨4, by decide⟩ := Fin.ext ht4
        subst htEq; exact hsp.2.2.2.1
      rw [hdr4]; exact hOA.2.2.2.2 ht4
  have hHostOutc : ∀ t : Fin (shdSegNS s), shdSegKind s t = .host →
      (FRef.outcT.dfs t).hosted.map (fun hk => (hk.1, hk.2.toK shdP_U))
        = (shdSegHosts hc0 s t).map (fun p => (p.1.val, p.2))
      ∧ ∀ hk ∈ (FRef.outcT.dfs t).hosted, hk.1 < t.val := fun t ht => by
    let dr := (List.range (P0.draws t.val)).map (fun j => challengeFp2Of (vf (bjOf t + j)))
    have hvRefEq : (outcWitness_of_adm Rp houtPub (refInput Rp hne verdict).1 (refInput Rp hne verdict).2).v = vRef :=
      outcWitness_of_adm_v Rp houtPub (refInput Rp hne verdict).1 (refInput Rp hne verdict).2
    have hOA := outcSlot_arith tag Rp houtPub wDigest bOutRow (outcWitness_of_adm Rp houtPub (refInput Rp hne verdict).1 (refInput Rp hne verdict).2)
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf default) (shdBlkRndOf default) (refInput Rp hne verdict).1 (refInput Rp hne verdict).2 ⟨26, by decide⟩)
      (shdP_bndTableAt_last_outcSpec Rp hR hweights hinPub houtPub _ _ (refInput Rp hne verdict).1 (refInput Rp hne verdict).2)
      (shdOutcRndOf default) FRef.outcT.ch
      (fun a ha => by rw [FRef.outcT.ch_eq] at ha; obtain ⟨_, _, rfl⟩ := List.mem_map.mp ha; exact challengeFp2Of_canon _)
      FRef.outcT.hbad t (FRef.outcT.recs.take t.val) dr
      (fun a ha => by obtain ⟨_, _, rfl⟩ := List.mem_map.mp ha; exact challengeFp2Of_canon _)
      (by simp only [dr, P0, List.length_map, List.length_range]; rw [hvRefEq]) (FRef.outcT.dfs t)
      (by rw [hvRefEq]; exact (FRef.outcT.slot_spec t).2.1)
    dsimp only [s] at ht ⊢
    rw [shdSegKind_outc] at ht
    rw [shdSegHosts_outc]
    fin_cases t <;> simp [outcKind] at ht
    · have h2 := (hOA.2.2.2.1 rfl).2
      have hdr2 : (FRef.outcT.recs[2]'(by rw [FRef.outcT.recs_len]; omega)).draws
          = (List.range (P0.draws 2)).map (fun j => challengeFp2Of (vf (bjOf ⟨2, by decide⟩ + j))) :=
        (FRef.outcT.slot_spec ⟨2, by decide⟩).2.2.2.1
      rw [h2]; dsimp only [dr]; rw [← hdr2]
      exact ⟨by dsimp only [outcHosts, hc0, shdP_hc]; rfl,
        fun hk hmem => by rw [List.mem_singleton.mp hmem]; dsimp only; decide⟩
    · have h4 := (hOA.2.2.2.2 rfl).2
      have hdr4 : (FRef.outcT.recs[4]'(by rw [FRef.outcT.recs_len]; omega)).draws
          = (List.range (P0.draws 4)).map (fun j => challengeFp2Of (vf (bjOf ⟨4, by decide⟩ + j))) :=
        (FRef.outcT.slot_spec ⟨4, by decide⟩).2.2.2.1
      rw [h4]; dsimp only [dr]; rw [← hdr4]
      exact ⟨by dsimp only [outcHosts, hc0, shdP_hc]; rfl,
        fun hk hmem => by rw [List.mem_singleton.mp hmem]; dsimp only; decide⟩
  have hFsCode := slotAcc_codeFuns_hW_hlay s P0 hc0
    (fun t => (outc_slotShape_eq_L2 tag Rp wDigest bOutRow vRef t).2.2)
    (fun t => outc_slotND_eq tag Rp wDigest bOutRow vRef t)
    (shdP_L2_slotN_lt_64 s)
    ch0Of rhoFullOf
    (fun t => by simp only [rhoFullOf, List.length_map, List.length_range]; exact (outc_slotND_eq tag Rp wDigest bOutRow vRef t).1)
    FRef.outcT.dfs hHostOutc fs0
    (by
      rw [FRef.outcT.fs_terms]
      refine congrArg₂ List.append (List.flatMap_congr fun t _ => ?_) (List.filterMap_congr fun t _ => ?_)
      · dsimp only [P0, vRef, ch0Of, rhoFullOf, bjOf, outcSlBase]; rfl
      · dsimp only [P0, vRef, ch0Of, bjOf, outcSlBase]
        cases hkP : (shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).bp.kind t.val with
        | standalone => rfl
        | priv => rfl
        | host =>
          have hkindH : shdSegKind s t = .host := by
            have hk := (outc_slotShape_eq_L2 tag Rp wDigest bOutRow vRef t).2.2
            dsimp only [s, vRef] at hk ⊢
            exact (shdSegKind_outc ⟨t.val, t.isLt⟩).trans (by rw [hkP] at hk; fin_cases t <;> (simp [outcKind] at hk ⊢; try rfl))
          refine congrArg Option.some (congrArg ((t.val, _) :: ·) (List.map_congr_left fun hk hmem => ?_))
          have hlt := (hHostOutc t hkindH).2 hk hmem
          have hltS : hk.1 < shdSegNS s := lt_trans hlt t.isLt
          have hlt8 : hk.1 < 8 := lt_trans hlt t.isLt
          rw [dite_eq_left hltS]
          have hcsAcc : (FRef.outcT.accs t).cs = FRef.outcT.acc.cs.take t.val := (FRef.outcT.slot_spec t).2.2.1
          have hcsGet : (FRef.outcT.accs t).cs.getD hk.1 Fp2.zero = ch0Of ⟨hk.1, hlt8⟩ := by
            rw [hcsAcc, List.getD_eq_getElem?_getD, List.getElem?_take_of_lt hlt,
              List.getElem?_eq_getElem (by rw [FRef.outcT.cs_len]; exact hlt8), Option.getD_some]
            exact (FRef.outcT.slot_spec ⟨hk.1, hlt8⟩).2.2.2.2.1
          dsimp only [ch0Of, bjOf, outcSlBase, P0, vRef] at hcsGet
          rw [hcsGet])
  have hPub := segMOpenPub_facts s fs0 θ0 rs0 idxs0 (idxsOf_length 12 vf _) (idxsOf_lt 12 vf _)
  { hd := fun t => (shdP_L2_slot_bounds s t).1
    hdc := fun t => (shdP_L2_slot_bounds s t).2.2.1
    c := fun t => (ch0Of t).toK shdP_U
    hc := fun t => fp2_toK_ne_zero_of_isZero_false (challengeFp2Of_canon _) (FRef.outcT.slot_spec t).1
    ρ := fun t => vecK shdP_U ((shdP_L2Spec s).n t + 1) (rhoFullOf t)
    f := fun y ω₁ t x =>
      let c := cOfL1 ω₁
      let w := outcWitness_of_adm Rp houtPub y.1.1 y.1.2
      let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩
      let cs := outcCs (shdP_outcTA Rp w (shdOutcRndOf c))
        (shdP_outcTH Rp w (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero)) TB26
      slotPolyK P0 (fun _ => 14) cs t.val (FRef.outcT.dfs t)
        (fun i => x (i.cast (outc_slotND_eq tag Rp wDigest bOutRow vRef t).1))
    hf := fun y ω₁ t => by
      have hnd := (outc_slotND_eq tag Rp wDigest bOutRow vRef t).1
      exact indDegLE_cast hnd.symm _ (hArith y ω₁ t).1
    hstd := fun y ω₁ t hkind => by
      have hnd := (outc_slotND_eq tag Rp wDigest bOutRow vRef t).1
      have hk' : outcKind t = .standalone := by rwa [shdSegKind_outc] at hkind
      exact (cubeSum_cast hnd.symm _).trans ((hArith y ω₁ t).2.1 hk')
    T := fun t v1 =>
      slotPolyFromView P0 (fun _ => 14)
        (outcCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef v1)
        t.val (FRef.outcT.dfs t) (rhoFullOf t)
    hterm := fun y ω₁ t => by
      have hnd := (outc_slotND_eq tag Rp wDigest bOutRow vRef t).1
      have hvec : (fun i : Fin (slotN P0 t.val) =>
          vecK shdP_U ((shdP_L2Spec s).n t + 1) (rhoFullOf t) (i.cast hnd))
          = vecK shdP_U (slotN P0 t.val) (rhoFullOf t) := by
        funext i; rfl
      dsimp only
      rw [hvec]
      refine slotPolyK_at_vecK_eq_fromView P0 (fun _ => 14) _ _ t.val (FRef.outcT.dfs t) (rhoFullOf t) (by simp [rhoFullOf])
        (fun a ha => by obtain ⟨_, _, rfl⟩ := List.mem_map.mp ha; exact challengeFp2Of_canon _)
        (fun p hp => outcCs_eq_outcCsViewOf tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow
          wDigest bOutRow hne verdict vf FRef y ω₁ t p hp)
    hsumH := fun y ω₁ t hkind => by
      let c := cOfL1 ω₁
      let w := outcWitness_of_adm Rp houtPub y.1.1 y.1.2
      let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩
      let cs := outcCs (shdP_outcTA Rp w (shdOutcRndOf c))
        (shdP_outcTH Rp w (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero)) TB26
      dsimp only [s] at hkind ⊢
      have ht24 : t = ⟨2, by decide⟩ ∨ t = ⟨4, by decide⟩ := by
        rw [shdSegKind_outc] at hkind
        have hlt8 : t.val < 8 := t.isLt
        match ht : t.val with
        | 2 => exact Or.inl (Fin.ext ht)
        | 4 => exact Or.inr (Fin.ext ht)
        | 0 => exfalso; have : t = ⟨0, by decide⟩ := Fin.ext ht; subst this; cases hkind
        | 1 => exfalso; have : t = ⟨1, by decide⟩ := Fin.ext ht; subst this; cases hkind
        | 3 => exfalso; have : t = ⟨3, by decide⟩ := Fin.ext ht; subst this; cases hkind
        | 5 => exfalso; have : t = ⟨5, by decide⟩ := Fin.ext ht; subst this; cases hkind
        | 6 => exfalso; have : t = ⟨6, by decide⟩ := Fin.ext ht; subst this; cases hkind
        | 7 => exfalso; have : t = ⟨7, by decide⟩ := Fin.ext ht; subst this; cases hkind
        | n + 8 => omega
      rcases ht24 with rfl | rfl
      · have h2 := ((hArith y ω₁ ⟨2, by decide⟩).2.2.2.1 rfl).1
        have h1 := (hArith y ω₁ ⟨1, by decide⟩).2.2.1 rfl
        have hnd2 := (outc_slotND_eq tag Rp wDigest bOutRow vRef ⟨2, by decide⟩).1
        have hnd1 := (outc_slotND_eq tag Rp wDigest bOutRow vRef ⟨1, by decide⟩).1
        rw [shdSegHosts_outc]
        change _ = hc0.νOut₂ * cubeSum (fun x => slotPolyK P0 (fun _ => 14) cs 1 (FRef.outcT.dfs ⟨1, by decide⟩) (fun i => x (i.cast hnd1))) + 0
        rw [add_zero]
        have hL : cubeSum (fun x => slotPolyK P0 (fun _ => 14) cs 2 (FRef.outcT.dfs ⟨2, by decide⟩) (fun i => x (i.cast hnd2)))
            = cubeSum (slotPolyK P0 (fun _ => 14) cs 2 (FRef.outcT.dfs ⟨2, by decide⟩)) :=
          cubeSum_cast hnd2.symm _
        have hR_sum : cubeSum (fun x => slotPolyK P0 (fun _ => 14) cs 1 (FRef.outcT.dfs ⟨1, by decide⟩) (fun i => x (i.cast hnd1)))
            = cubeSum (slotPolyK P0 (fun _ => 14) cs 1 (FRef.outcT.dfs ⟨1, by decide⟩)) :=
          cubeSum_cast hnd1.symm _
        dsimp only [cs, w, c, TB26] at hL hR_sum h2 h1 ⊢
        exact (hL.trans h2).trans ((congrArg (· * _) (show _ = hc0.νOut₂ from rfl)).trans (congrArg (hc0.νOut₂ * ·) (h1.symm.trans hR_sum.symm)))
      · have h4 := ((hArith y ω₁ ⟨4, by decide⟩).2.2.2.2 rfl).1
        have h3 := (hArith y ω₁ ⟨3, by decide⟩).2.2.1 rfl
        have hnd4 := (outc_slotND_eq tag Rp wDigest bOutRow vRef ⟨4, by decide⟩).1
        have hnd3 := (outc_slotND_eq tag Rp wDigest bOutRow vRef ⟨3, by decide⟩).1
        rw [shdSegHosts_outc]
        change _ = hc0.νOut₄ * cubeSum (fun x => slotPolyK P0 (fun _ => 14) cs 3 (FRef.outcT.dfs ⟨3, by decide⟩) (fun i => x (i.cast hnd3))) + 0
        rw [add_zero]
        have hL : cubeSum (fun x => slotPolyK P0 (fun _ => 14) cs 4 (FRef.outcT.dfs ⟨4, by decide⟩) (fun i => x (i.cast hnd4)))
            = cubeSum (slotPolyK P0 (fun _ => 14) cs 4 (FRef.outcT.dfs ⟨4, by decide⟩)) :=
          cubeSum_cast hnd4.symm _
        have hR_sum : cubeSum (fun x => slotPolyK P0 (fun _ => 14) cs 3 (FRef.outcT.dfs ⟨3, by decide⟩) (fun i => x (i.cast hnd3)))
            = cubeSum (slotPolyK P0 (fun _ => 14) cs 3 (FRef.outcT.dfs ⟨3, by decide⟩)) :=
          cubeSum_cast hnd3.symm _
        dsimp only [cs, w, c, TB26] at hL hR_sum h4 h3 ⊢
        exact (hL.trans h4).trans ((congrArg (· * _) (show _ = hc0.νOut₄ from rfl)).trans (congrArg (hc0.νOut₄ * ·) (h3.symm.trans hR_sum.symm)))
    θ := θ0.toK shdP_U
    P := segMOpenPub s fs0 θ0 rs0 idxs0 (idxsOf_lt 12 vf _)
    hm := hPub.1
    hmF := hPub.2.1
    hy := hPub.2.2.1
    hsum := hPub.2.2.2.1
    hW := segMOpenPub_hW s fs0 (fun f hf tm htm _ => (hFsCode.1 f hf tm htm).elim fun _ h => h) θ0 rs0 idxs0 (idxsOf_lt 12 vf _)
    hpad := hPub.2.2.2.2
    w := segMaskW s
    hlay := segMOpenPub_hlay s hc0 (fun t => (ch0Of t).toK shdP_U)
      (fun t => vecK shdP_U ((shdP_L2Spec s).n t + 1) (rhoFullOf t))
      fs0 hFsCode.2.1 (fun f hf tm htm => (hFsCode.1 f hf tm htm).elim fun h _ => h) hFsCode.2.2 θ0 rs0 idxs0 (idxsOf_lt 12 vf _) }

/-- Concrete Level-2 `ShdSegL2Data` for Stage OUT-C (`s = 27`). -/
noncomputable def shdP_D2_outc {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) :
    ShdSegL2Data GF shdP_K (AdmAt Rp verdict) (ShdL1Coins GF shdP_L1Spec)
      (ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf))
      (shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view
      (shdSegKind ⟨27, by decide⟩)
      (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) ⟨27, by decide⟩)
      shdP_U (7 : GF) (shdP_L2Spec ⟨27, by decide⟩) (shdP_qs vf ⟨27, by decide⟩) :=
  shdSegL2DataCast (shdP_qs_outc vf).symm
    (shdP_D2_outc_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef)

/-- **Complete Level-2 `ShdSegL2Data` across all 28 segments (`IN-C`, 26× `Blk`, `OUT-C`)**. -/
noncomputable def shdP_D2 {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf) (s : Fin 28) :
    ShdSegL2Data GF shdP_K (AdmAt Rp verdict) (ShdL1Coins GF shdP_L1Spec)
      (ShdL1View GF shdP_K shdP_L1Spec (shdP_ks vf))
      (shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).view
      (shdSegKind s)
      (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) s)
      shdP_U (7 : GF) (shdP_L2Spec s) (shdP_qs vf s) :=
  if h0 : s.val = 0 then
    (Fin.ext h0.symm : (⟨0, by decide⟩ : Fin 28) = s) ▸
      shdP_D2_inc tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  else if h27 : s.val = 27 then
    (Fin.ext h27.symm : (⟨27, by decide⟩ : Fin 28) = s) ▸
      shdP_D2_outc tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  else
    (Fin.ext (by dsimp; omega) : (⟨(s.val - 1) + 1, by omega⟩ : Fin 28) = s) ▸
      shdP_D2_blk tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef ⟨s.val - 1, by omega⟩

private noncomputable def shdP_Rc_inc {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (vw : ShdView GF shdP_K shdP_L1Spec shdP_L2Spec (shdP_ks vf) (shdP_qs vf)) : List UInt8 :=
  let v1 := vw.1
  let v2 := vw.2
  let hc0 := shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  let V0 := shdVi tag Rp embDigest bInRow
  let P0 := V0.bp (incCtx V0.pub FRef.incT.ch)
  let elog0 := incElog V0.pub 14
  let incCsV := incCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef v1
  let sps0 : List SlotProof := List.ofFn fun t : Fin 4 =>
    let bj := incSlBase + slotsFixedLen P0 0 t.val
    let rhoFull := (List.range (slotN P0 t.val)).map (fun r => challengeFp2Of (vf (bj + P0.draws t.val + 3 + 2 * r + 1)))
    let n := (Exec.Block.slotShape P0 t.val).1
    let tms := stgPrivValsFromView (atLog P0 (elog0 t.val)) incCsV (rhoFull.take n) (rhoFull.drop n) (FRef.incT.dfs t).tabs
    slotProofRecon (shdSegKind ⟨0, by decide⟩) (shdSegHosts hc0 ⟨0, by decide⟩)
      (fun u => (challengeFp2Of (vf (incSlBase + slotsFixedLen P0 0 u.val + P0.draws u.val + 1))).toK shdP_U)
      (v2 ⟨0, by decide⟩).1.1 t tms
  let hqs0 : shdP_qs vf ⟨0, by decide⟩ = (nodupCols (idxsOf 12 vf (incMoBase + 13))).length := shdP_qs_zero vf
  let mO0 := segMOpenRecon ⟨0, by decide⟩ (idxsOf 12 vf (incMoBase + 13)) (idxsOf_lt 12 vf _)
    (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3)) (hqs0 ▸ (v2 ⟨0, by decide⟩).1.2) (v2 ⟨0, by decide⟩).2
  let aO0 := stdOpenRecon 12 2 33 3 (idxsOf 14 vf (incAoBase + 48)) (idxsOf_lt 14 vf _)
    FRef.incT.acc.claims.a FRef.incT.haudA
    ((List.range 3).map fun j => challengeFp2Of (vf (incAoBase + j)))
    (levelsOfV vf 14 (4104 + 131071 + 5)) ((incAHViewOf vf v1).1.1, (incAHViewOf vf v1).2.1)
  let clH0 := FRef.incT.acc.claims.h ++ [V0.lay.logupSumClaim]
  let hO0 := hOpenRecon 12 2 66 3 (idxsOf 14 vf (incHoBase + 85)) (idxsOf_lt 14 vf _)
    clH0 FRef.incT.hLenH FRef.incT.haudH
    ((List.range 4).map fun j => challengeFp2Of (vf (incHoBase + j)))
    (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15))
    (incAHViewOf vf v1).1.2 (incAHViewOf vf v1).2.2
  let c0 := (incTeClaim_of_trace tag Rp embDigest bInRow _ default vf FRef.incT).choose
  let eO0 := teOpenRecon (idxsOf 11 vf (incEoBase + 9)) (idxsOf_lt 11 vf _) c0
    ((List.range 1).map fun j => challengeFp2Of (vf (incEoBase + j))) (levelsOfV vf 11 0) (shdP_ks_te vf ▸ v1.1)
  let seg0 : StageSeg := ⟨some (levelsOfV vf 16 4104).getRoot,
    ⟨(levelsOfV vf 14 (4104 + 131071 + 5)).getRoot,
     (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15)).getRoot,
     (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3)).getRoot, sps0, mO0, aO0, hO0⟩, [eO0]⟩
  encStage (rcIncGeom V0 28) (vf 4101) (posTagOfV vf 4102) seg0 (posTagOfV vf (4104 + incSegFixedLen))

private noncomputable def shdP_Rc_blk {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (vw : ShdView GF shdP_K shdP_L1Spec shdP_L2Spec (shdP_ks vf) (shdP_qs vf)) (k : Fin 26) : List UInt8 :=
  let v1 := vw.1
  let v2 := vw.2
  let hc0 := shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  let s : Fin 28 := ⟨k.val + 1, by omega⟩
  let Pk := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
  let blkCsV := blkCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef k v1
  let hqs : shdP_qs vf s = (nodupCols (idxsOf 12 vf (blkMoBase k + 51))).length := shdP_qs_blk vf k
  let spsK : List SlotProof := List.ofFn fun t : Fin (shdSegNS s) =>
    let bj := blkSlBase k + slotsFixedLen Pk 0 t.val
    let rhoFull := (List.range (slotN Pk t.val)).map (fun r => challengeFp2Of (vf (bj + Pk.draws t.val + 3 + 2 * r + 1)))
    let n := (Exec.Block.slotShape Pk t.val).1
    let tms := stgPrivValsFromView Pk blkCsV (rhoFull.take n) (rhoFull.drop n) ((FRef.blkT k).dfs (blkFin k t)).tabs
    slotProofRecon (shdSegKind s) (shdSegHosts hc0 s)
      (fun u => (challengeFp2Of (vf (blkSlBase k + slotsFixedLen Pk 0 u.val + Pk.draws u.val + 1))).toK shdP_U)
      (v2 s).1.1 t tms
  let mOk := segMOpenRecon s (idxsOf 12 vf (blkMoBase k + 51)) (idxsOf_lt 12 vf _)
    (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)) (hqs ▸ (v2 s).1.2) (v2 s).2
  let aOk := stdOpenRecon 14 2 4283 146 (idxsOf 16 vf (blkAoBase k + 4760)) (idxsOf_lt 16 vf _)
    (FRef.blkT k).acc.claims.a (FRef.blkT k).haudA
    ((List.range 146).map fun j => challengeFp2Of (vf (blkAoBase k + j)))
    (levelsOfV vf 16 (blkBase k + 131071 + 5)) ((blkAHViewOf vf v1 k).1.1, (blkAHViewOf vf v1 k).2.1)
  let clHk := (FRef.blkT k).acc.claims.h ++ [Pk.logupSumClaim]
  let hOk := hOpenRecon 14 2 4280 53 (idxsOf 16 vf (blkHoBase k + 4454)) (idxsOf_lt 16 vf _)
    clHk (FRef.blkT k).hLenH (FRef.blkT k).haudH
    ((List.range 54).map fun j => challengeFp2Of (vf (blkHoBase k + j)))
    (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3))
    (blkAHViewOf vf v1 k).1.2 (blkAHViewOf vf v1 k).2.2
  let clBk := (FRef.crAt ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).pending ++ (FRef.blkT k).acc.claims.inp
  let hksB : (shdP_ks vf).bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩ = (nodupCols (idxsOf 16 vf (blkBoBase k + 43))).length := by
    unfold shdP_ks; dsimp only; exact dite_eq_left k.isLt
  let bOk := stdOpenRecon 14 2 32 2 (idxsOf 16 vf (blkBoBase k + 43)) (idxsOf_lt 16 vf _)
    clBk (FRef.blkT k).haudB
    ((List.range 2).map fun j => challengeFp2Of (vf (blkBoBase k + j)))
    (levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)))
    (hksB ▸ v1.2.1 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
  let sg := Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2
  let stTag := if h0 : k.val = 0 then posTagOfV vf (4104 + incSegFixedLen)
    else posTagOfV vf (blkBase ⟨k.val - 1, by omega⟩ + blkSegFixedLen)
  let endTag := posTagOfV vf (blkBase k + blkSegFixedLen)
  let core : Exec.Block.Core := ⟨(levelsOfV vf 16 (blkBase k + 131071 + 5)).getRoot,
    (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)).getRoot,
    (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)).getRoot, spsK, mOk, aOk, hOk⟩
  let seg : Segment := ⟨some (levelsOfV vf 16 (blkBase k)).getRoot, core, bOk, none⟩
  Exec.Block.encSeg (vf 4101) sg.l sg.k stTag seg endTag

private noncomputable def shdP_Rc_outc {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (vw : ShdView GF shdP_K shdP_L1Spec shdP_L2Spec (shdP_ks vf) (shdP_qs vf)) : List UInt8 :=
  let v1 := vw.1
  let v2 := vw.2
  let hc0 := shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  let vRef := (classifySpecP Rp (refInput Rp hne verdict).1).getD 0
  let P27 := (shdVo tag Rp wDigest bOutRow vRef).bp
  let outcCsV := outcCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef v1
  let sps27 : List SlotProof := List.ofFn fun t : Fin 8 =>
    let bj := outcSlBase + slotsFixedLen P27 0 t.val
    let rhoFull := (List.range (slotN P27 t.val)).map (fun r => challengeFp2Of (vf (bj + P27.draws t.val + 3 + 2 * r + 1)))
    let n := (Exec.Block.slotShape P27 t.val).1
    let tms := stgPrivValsFromView P27 outcCsV (rhoFull.take n) (rhoFull.drop n) (FRef.outcT.dfs t).tabs
    slotProofRecon (shdSegKind ⟨27, by decide⟩) (shdSegHosts hc0 ⟨27, by decide⟩)
      (fun u => (challengeFp2Of (vf (outcSlBase + slotsFixedLen P27 0 u.val + P27.draws u.val + 1))).toK shdP_U)
      (v2 ⟨27, by decide⟩).1.1 t tms
  let hqs27 : shdP_qs vf ⟨27, by decide⟩ = (nodupCols (idxsOf 12 vf (outcMoBase + 21))).length := shdP_qs_outc vf
  let mO27 := segMOpenRecon ⟨27, by decide⟩ (idxsOf 12 vf (outcMoBase + 21)) (idxsOf_lt 12 vf _)
    (levelsOfV vf 12 (outcBase + 2 + 32767 + 3)) (hqs27 ▸ (v2 ⟨27, by decide⟩).1.2) (v2 ⟨27, by decide⟩).2
  let aO27 := stdOpenRecon 12 2 16 29 (idxsOf 14 vf (outcAoBase + 122)) (idxsOf_lt 14 vf _)
    FRef.outcT.acc.claims.a FRef.outcT.haudA
    ((List.range 29).map fun j => challengeFp2Of (vf (outcAoBase + j)))
    (levelsOfV vf 14 (outcBase + 2)) ((outcAHViewOf vf v1).1.1, (outcAHViewOf vf v1).2.1)
  let clH27 := FRef.outcT.acc.claims.h ++ [(shdVo tag Rp wDigest bOutRow vRef).lay.logupSumClaim]
  let hO27 := hOpenRecon 12 2 16 9 (idxsOf 14 vf (outcHoBase + 54)) (idxsOf_lt 14 vf _)
    clH27 FRef.outcT.hLenH FRef.outcT.haudH
    ((List.range 10).map fun j => challengeFp2Of (vf (outcHoBase + j)))
    (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2))
    (outcAHViewOf vf v1).1.2 (outcAHViewOf vf v1).2.2
  let clB26 := (FRef.crAt ⟨26, by decide⟩).pending ++ FRef.outcT.acc.claims.inp
  let hksB26 : (shdP_ks vf).bnd ⟨26, by decide⟩ = (nodupCols (idxsOf 16 vf (outcBoBase + 43))).length := by
    unfold shdP_ks; dsimp only; exact dite_eq_right (by decide : ¬ (26 < 26))
  let bO26 := stdOpenRecon 14 2 32 2 (idxsOf 16 vf (outcBoBase + 43)) (idxsOf_lt 16 vf _)
    clB26 FRef.outcT.haudB
    ((List.range 2).map fun j => challengeFp2Of (vf (outcBoBase + j)))
    (levelsOfV vf 16 (shdTreeBase (.bnd ⟨26, by decide⟩)))
    (hksB26 ▸ v1.2.1 ⟨26, by decide⟩)
  let seg27 : StageSeg := ⟨none,
    ⟨(levelsOfV vf 14 (outcBase + 2)).getRoot,
     (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2)).getRoot,
     (levelsOfV vf 12 (outcBase + 2 + 32767 + 3)).getRoot, sps27, mO27, aO27, hO27⟩, [bO26]⟩
  encStage (rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28) (vf 4101)
    (posTagOfV vf (blkBase ⟨25, by decide⟩ + blkSegFixedLen)) seg27 (posTagOfV vf (outcBase + outcSegFixedLen))

/-- **Pure view-and-`(verdict, vf)` receipt reconstruction `shdP_Rc`**: reconstructs the exact
statement `honestStmt hdr root verdict` and all 28 encoded segment byte vectors solely from
`(verdict, vf, FRef)` and `vw : ShdView`! -/
noncomputable def shdP_Rc {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hdr : Hdr) (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (vw : ShdView GF shdP_K shdP_L1Spec shdP_L2Spec (shdP_ks vf) (shdP_qs vf)) : ClsStmt Hdr × ClsReceipt :=
  (honestStmt hdr (levelsOfV vf 11 0).getRoot verdict,
   shdP_Rc_inc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef vw ::
     List.ofFn (shdP_Rc_blk tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef vw) ++
     [shdP_Rc_outc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef vw])

/-- Helper: transport `scProve_honestW_eq_of_slotView` along `hN : N = n + 1` and `hD : D = d`
so all 3 segment families (`IN-C`, `Blk`, `OUT-C`) discharge `sps[t].rounds` in one call. -/
theorem scProve_honestW_cast_eq {N D n d : ℕ} (hN : N = n + 1) (hD : D = d)
    (hd1 : 1 ≤ d) (hdc : d < ringChar shdP_K) (masked : Bool)
    (f : (Fin N → shdP_K) → shdP_K) (hf : IndDegLE d (fun x : Fin (n + 1) → shdP_K => f (fun i => x (i.cast hN))))
    (mRow : ℕ → ℕ → shdP_K) (slotIdx : ℕ) (c : shdP_K) (a : Hiding.CfsCoeffs shdP_K n d)
    (hmEq : (fun x : Fin (n + 1) → shdP_K => Link.maskPoly mRow slotIdx N D (fun i => x (i.cast hN)))
      = Hiding.cfsEval a)
    (vf : ℕ → Dig) (t0 : Tr) (scBase : ℕ) :
    let ρ : Fin (n + 1) → shdP_K := fun j => (challengeFp2Of (vf (scBase + 2 * j.val + 1))).toK shdP_U
    let f' : (Fin (n + 1) → shdP_K) → shdP_K := fun x => f (fun i => x (i.cast hN))
    let sv := slotView masked (honestCo d n f' ρ) c ρ a
    ((scProveFixedProg (2 ^ 20) le_rfl none N true
      (honestW shdP_U shdP_hbij D N (fun x => f x + c * Link.maskPoly mRow slotIdx N D x)) t0).res
        (fun _ => default) vf scBase).1
    = List.ofFn fun j : Fin (n + 1) =>
        List.ofFn fun u : Fin (d + 1) => ofK shdP_U shdP_hbij (Hiding.peval (sv.2.1 j) (u.val : shdP_K)) := by
  subst hN; subst hD
  have hfn : (fun x : Fin (n + 1) → shdP_K => f x + c * Link.maskPoly mRow slotIdx (n + 1) D x)
      = (fun x : Fin (n + 1) → shdP_K => f (fun i => x (i.cast rfl)) + c * Hiding.cfsEval a x) := by
    funext x
    have hm := congrFun hmEq x
    rw [← hm]; rfl
  rw [hfn]
  exact scProve_honestW_eq_of_slotView hd1 hdc masked (fun x => f (fun i => x (i.cast rfl))) hf c a
    (2 ^ 20) le_rfl none (fun _ => default) vf t0 scBase

/-- Helper: `Fin (n + 1) → shdP_K` cast of `vecK` equals `fun j => (challengeFp2Of ...).toK shdP_U`. -/
theorem vecK_range_eq (n : ℕ) (vf : ℕ → Dig) (scBase : ℕ) :
    vecK shdP_U (n + 1) ((List.range (n + 1)).map (fun r => challengeFp2Of (vf (scBase + 2 * r + 1))))
      = fun j : Fin (n + 1) => (challengeFp2Of (vf (scBase + 2 * j.val + 1))).toK shdP_U := by
  funext j
  unfold vecK
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range j.isLt]
  rfl

/-- Helpers: `shdP_D2` view projections for `s = 0`, `s = k + 1`, `s = 27`, stripping all `q` casts. -/
theorem shdP_D2_view_inc_fst {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) :
    ((shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨0, by decide⟩).view y c.1 (c.2 ⟨0, by decide⟩)).1.1
      = ((shdP_D2_inc_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef).view y c.1 (c.2 ⟨0, by decide⟩)).1.1 := by
  delta shdP_D2 shdP_D2_inc; dsimp only
  rw [dite_eq_left rfl]
  exact shdSegL2DataCast_view_fst (shdP_qs_zero vf).symm _ y c.1 _

theorem shdP_D2_view_inc_mOpen {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) :
    (shdP_qs_zero vf ▸ ((shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨0, by decide⟩).view y c.1 (c.2 ⟨0, by decide⟩)).1.2)
      = ((shdP_D2_inc_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef).view y c.1 (c.2 ⟨0, by decide⟩)).1.2 := by
  have hD : shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨0, by decide⟩
      = shdP_D2_inc tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef := by
    unfold shdP_D2; exact dite_eq_left rfl
  rw [hD]; delta shdP_D2_inc
  exact shdSegL2DataCast_view_mOpen (shdP_qs_zero vf).symm (shdP_qs_zero vf) _ y c.1 _

theorem shdP_D2_view_inc_snd {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) :
    ((shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨0, by decide⟩).view y c.1 (c.2 ⟨0, by decide⟩)).2
      = ((shdP_D2_inc_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef).view y c.1 (c.2 ⟨0, by decide⟩)).2 := by
  delta shdP_D2 shdP_D2_inc; dsimp only
  rw [dite_eq_left rfl]
  exact shdSegL2DataCast_view_snd (shdP_qs_zero vf).symm _ y c.1 _

theorem shdP_D2_view_blk {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) (k : Fin 26) :
    (shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨k.val + 1, by omega⟩).view y c.1 (c.2 ⟨k.val + 1, by omega⟩)
      = (shdP_D2_blk tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef k).view y c.1 (c.2 ⟨k.val + 1, by omega⟩) := by
  unfold shdP_D2
  rw [dite_eq_right (by omega : ¬ (k.val + 1 = 0)), dite_eq_right (by omega : ¬ (k.val + 1 = 27))]
  have hkEq : (⟨(k.val + 1) - 1, by omega⟩ : Fin 26) = k := Fin.ext (Nat.add_sub_cancel k.val 1)
  have hfinEq : (⟨((k.val + 1) - 1) + 1, by omega⟩ : Fin 28) = ⟨k.val + 1, by omega⟩ := Fin.ext (by dsimp only; omega)
  have hgen : ∀ (k' : Fin 26) (hk' : k' = k) (hs : (⟨k'.val + 1, by omega⟩ : Fin 28) = ⟨k.val + 1, by omega⟩),
      (hs ▸ shdP_D2_blk tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
        hne verdict vf FRef k').view y c.1 (c.2 ⟨k.val + 1, by omega⟩)
        = (shdP_D2_blk tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef k).view y c.1 (c.2 ⟨k.val + 1, by omega⟩) := by
    rintro k' hk' hs; subst hk'; cases hs; rfl
  exact hgen _ hkEq hfinEq

theorem shdP_D2_view_blk_fst {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) (k : Fin 26) :
    ((shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨k.val + 1, by omega⟩).view y c.1 (c.2 ⟨k.val + 1, by omega⟩)).1.1
      = ((shdP_D2_blk_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef k).view y c.1 (c.2 ⟨k.val + 1, by omega⟩)).1.1 := by
  rw [shdP_D2_view_blk]
  delta shdP_D2_blk
  exact shdSegL2DataCast_view_fst (shdP_qs_blk vf k).symm _ y c.1 _

theorem shdP_D2_view_blk_mOpen {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) (k : Fin 26) :
    (shdP_qs_blk vf k ▸ ((shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨k.val + 1, by omega⟩).view y c.1 (c.2 ⟨k.val + 1, by omega⟩)).1.2)
      = ((shdP_D2_blk_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef k).view y c.1 (c.2 ⟨k.val + 1, by omega⟩)).1.2 := by
  rw [shdP_D2_view_blk]
  delta shdP_D2_blk
  exact shdSegL2DataCast_view_mOpen (shdP_qs_blk vf k).symm (shdP_qs_blk vf k) _ y c.1 _

theorem shdP_D2_view_blk_snd {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) (k : Fin 26) :
    ((shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨k.val + 1, by omega⟩).view y c.1 (c.2 ⟨k.val + 1, by omega⟩)).2
      = ((shdP_D2_blk_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef k).view y c.1 (c.2 ⟨k.val + 1, by omega⟩)).2 := by
  rw [shdP_D2_view_blk]
  delta shdP_D2_blk
  exact shdSegL2DataCast_view_snd (shdP_qs_blk vf k).symm _ y c.1 _

theorem shdP_D2_view_outc_fst {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) :
    ((shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨27, by decide⟩).view y c.1 (c.2 ⟨27, by decide⟩)).1.1
      = ((shdP_D2_outc_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef).view y c.1 (c.2 ⟨27, by decide⟩)).1.1 := by
  delta shdP_D2 shdP_D2_outc; dsimp only
  rw [dite_eq_right (by decide : ¬ (27 = 0)), dite_eq_left rfl]
  exact shdSegL2DataCast_view_fst (shdP_qs_outc vf).symm _ y c.1 _

theorem shdP_D2_view_outc_mOpen {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) :
    (shdP_qs_outc vf ▸ ((shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨27, by decide⟩).view y c.1 (c.2 ⟨27, by decide⟩)).1.2)
      = ((shdP_D2_outc_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef).view y c.1 (c.2 ⟨27, by decide⟩)).1.2 := by
  have hD : shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨27, by decide⟩
      = shdP_D2_outc tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef := by
    unfold shdP_D2; rw [dite_eq_right (by decide : ¬ (27 = 0)), dite_eq_left rfl]
  rw [hD]; delta shdP_D2_outc
  exact shdSegL2DataCast_view_mOpen (shdP_qs_outc vf).symm (shdP_qs_outc vf) _ y c.1 _

theorem shdP_D2_view_outc_snd {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (y : AdmAt Rp verdict) (c : ShdCoins) :
    ((shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      hne verdict vf FRef ⟨27, by decide⟩).view y c.1 (c.2 ⟨27, by decide⟩)).2
      = ((shdP_D2_outc_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict vf FRef).view y c.1 (c.2 ⟨27, by decide⟩)).2 := by
  delta shdP_D2 shdP_D2_outc; dsimp only
  rw [dite_eq_right (by decide : ¬ (27 = 0)), dite_eq_left rfl]
  exact shdSegL2DataCast_view_snd (shdP_qs_outc vf).symm _ y c.1 _

private theorem core_mk_congr {rA rH rM : Dig} {sps₁ sps₂ mO₁ mO₂ aO₁ aO₂ hO₁ hO₂}
    (hsps : sps₁ = sps₂) (hmO : mO₁ = mO₂) (haO : aO₁ = aO₂) (hhO : hO₁ = hO₂) :
    Exec.Block.Core.mk rA rH rM sps₁ mO₁ aO₁ hO₁ = Exec.Block.Core.mk rA rH rM sps₂ mO₂ aO₂ hO₂ := by
  subst hsps; subst hmO; subst haO; subst hhO; rfl

private theorem mkMTable_congr {S₁ S₂ : ℕ} (hS : S₁ = S₂)
    (a₁ : Fin S₁ → Fin 512 → Fp2) (a₂ : Fin S₂ → Fin 512 → Fp2)
    (ha : ∀ (i : ℕ) (h1 : i < S₁) (h2 : i < S₂), a₁ ⟨i, h1⟩ = a₂ ⟨i, h2⟩)
    (bRe bIm uRe uIm : Fin 1024 → GF) (salts : ℕ → Dig) :
    mkMTable S₁ a₁ bRe bIm uRe uIm salts = mkMTable S₂ a₂ bRe bIm uRe uIm salts := by
  subst hS
  have hfun : a₁ = a₂ := funext fun i => ha i.val i.isLt i.isLt
  subst hfun; rfl

private theorem inc_mRowKOf_eq (c : ShdCoins) :
    mRowKOf 4 (shdIncRndOf c).mA = mRowKOf (shdSegNS ⟨0, by decide⟩) (packSegMA ⟨0, by decide⟩ (c.2 ⟨0, by decide⟩)) := rfl

private theorem blk_mRowKOf_eq (c : ShdCoins) (k : Fin 26) :
    let s : Fin 28 := ⟨k.val + 1, by omega⟩
    mRowKOf 23 (shdBlkRndOf c k).mA = mRowKOf (shdSegNS s) (packSegMA s (c.2 s)) := by
  intro s
  have hns : shdSegNS s = 23 := by unfold shdSegNS s; dsimp only; rw [ite_eq_right (by omega), ite_eq_right (by omega)]
  funext i j; unfold mRowKOf; dsimp only [shdBlkRndOf]
  by_cases hj : j < 512
  · by_cases hi : i < 23
    · rw [dite_eq_left ⟨hi, hj⟩, dite_eq_left ⟨by omega, hj⟩]
    · rw [dite_eq_right (fun h => hi h.1), dite_eq_right (fun h => hi (by omega))]
  · rw [dite_eq_right (fun h => hj h.2), dite_eq_right (fun h => hj h.2)]

private theorem outc_mRowKOf_eq (c : ShdCoins) :
    mRowKOf 8 (shdOutcRndOf c).mA = mRowKOf (shdSegNS ⟨27, by decide⟩) (packSegMA ⟨27, by decide⟩ (c.2 ⟨27, by decide⟩)) := rfl

private theorem maskPoly_cast_eq {mRow₁ mRow₂ : ℕ → ℕ → shdP_K} {slotIdx N n D d : ℕ}
    (hmRow : mRow₁ = mRow₂) (hN : N = n + 1) (hD : D = d) :
    (fun x : Fin (n + 1) → shdP_K => Link.maskPoly mRow₁ slotIdx N D (fun i => x (i.cast hN)))
      = Link.maskPoly mRow₂ slotIdx (n + 1) d := by
  subst hmRow; subst hN; subst hD; rfl

private theorem shdSegL2Data_view_mOpen {Dt Ω₁ V₁ : Type} {X₁ : Dt → Ω₁ → V₁}
    {ns : ℕ} {kind : Fin ns → Kind} {hosts : Fin ns → List (Fin ns × shdP_K)}
    {S : SegL2Spec ns} {q : ℕ}
    (D : ShdSegL2Data GF shdP_K Dt Ω₁ V₁ X₁ kind hosts shdP_U (7 : GF) S q)
    (y : Dt) (ω₁ : Ω₁) (c2 : SegL2Coins GF shdP_K S) :
    (D.view y ω₁ c2).1.2 = Hiding.mOpenView (7 : GF) D.P D.hm (D.w c2.1.1) c2.1.2 := rfl

private theorem slotProof_ext {a b : Exec.Block.SlotProof}
    (h1 : a.scalar = b.scalar) (h2 : a.rounds = b.rounds) (h3 : a.terms = b.terms) : a = b := by
  cases a; cases b; cases h1; cases h2; cases h3; rfl

private theorem shdSegL2Data_mOpen_eq {Dt Ω₁ V₁ : Type} {X₁ : Dt → Ω₁ → V₁}
    {ns : ℕ} {kind : Fin ns → Kind} {hosts : Fin ns → List (Fin ns × shdP_K)}
    {S : SegL2Spec ns} {q : ℕ}
    (D : ShdSegL2Data GF shdP_K Dt Ω₁ V₁ X₁ kind hosts shdP_U (7 : GF) S q)
    (y : Dt) (ω₁ : Ω₁) (c2 : SegL2Coins GF shdP_K S)
    {P : Hiding.MOpenPub GF S.mm S.r S.Q q}
    {w : ((t : Fin ns) → Hiding.CfsCoeffs shdP_K (S.n t) (S.d t)) → Fin S.r → Bool → Fin S.mm → GF}
    {h0 : 0 < S.mm} (hP : D.P = P) (hw : D.w = w) :
    Hiding.mOpenView (7 : GF) P h0 (w c2.1.1) c2.1.2 = (D.view y ω₁ c2).1.2 := by
  subst hP; subst hw; rfl

private theorem pcsAHData_of_audit_view_A' {Dt : Type} {logN lr dA gA dH gH : ℕ} {hkl : logN + lr ≤ 31}
    {idxsA : List ℕ} {hIdxsALen : idxsA.length = 256} {hIdxsALt : ∀ j ∈ idxsA, j < 2 ^ (logN + lr)}
    {clA : List Block.ZClaim}
    {haudA : auditClaims clA (2 ^ logN) (dA + 2 * gA + 2) (List.range' dA (2 * gA)) none (dA + 2 * gA) = .ok ()}
    {proxRA : List Fp2}
    {hDetA : (Exec.Block.det (proxRA.getD (dA + 2 * gA) Fp2.zero) (proxRA.getD (dA + 2 * gA + 1) Fp2.zero)).v ≠ 0}
    {datA : Dt → Fin dA → Fin (2 ^ logN) → GF}
    {idxsH : List ℕ} {hIdxsHLen : idxsH.length = 256} {hIdxsHLt : ∀ j ∈ idxsH, j < 2 ^ (logN + lr)}
    {clH : List Block.ZClaim} {hLenH : clH.length = gH + 1}
    {haudH : auditClaims clH (2 ^ logN) (dH + 2 + 2 * gH + 2) (List.range' (dH + 2) (2 * gH))
      (some (dH, dH + 1)) (dH + 2 + 2 * gH) = .ok ()}
    {proxRH : List Fp2}
    {hDetH : (Exec.Block.det (proxRH.getD (dH + 2 + 2 * gH) Fp2.zero) (proxRH.getD (dH + 2 + 2 * gH + 1) Fp2.zero)).v ≠ 0}
    {datH : Dt → Fin dH → Fin (2 ^ logN) → GF}
    {hdH : ∀ y, ∑ col : Fin (2 ^ logN), ∑ i : Fin dH,
      (claimWeight logN clH[gH] i.val).toK shdP_U * algebraMap GF shdP_K (datH y i col) = 0}
    {y : Dt} {cAH : PcsAHCoins GF ⟨mkStdSpec logN lr dA gA, mkStdSpec logN lr dH gH⟩} :
    let D := pcsAHData_of_audit logN lr dA gA dH gH hkl idxsA hIdxsALen hIdxsALt clA haudA proxRA hDetA datA
      idxsH hIdxsHLen hIdxsHLt clH hLenH haudH proxRH hDetH datH hdH
    let DA := stdPcsData_of_audit logN lr dA gA hkl idxsA hIdxsALen hIdxsALt clA haudA proxRA hDetA datA
    ((D.view y cAH).1.1, (D.view y cAH).2.1) = DA.view y (cAH.1.1, cAH.2.1) := rfl

private theorem pcsAHData_of_audit_view_H' {Dt : Type} {logN lr dA gA dH gH : ℕ} {hkl : logN + lr ≤ 31}
    {idxsA : List ℕ} {hIdxsALen : idxsA.length = 256} {hIdxsALt : ∀ j ∈ idxsA, j < 2 ^ (logN + lr)}
    {clA : List Block.ZClaim}
    {haudA : auditClaims clA (2 ^ logN) (dA + 2 * gA + 2) (List.range' dA (2 * gA)) none (dA + 2 * gA) = .ok ()}
    {proxRA : List Fp2}
    {hDetA : (Exec.Block.det (proxRA.getD (dA + 2 * gA) Fp2.zero) (proxRA.getD (dA + 2 * gA + 1) Fp2.zero)).v ≠ 0}
    {datA : Dt → Fin dA → Fin (2 ^ logN) → GF}
    {idxsH : List ℕ} {hIdxsHLen : idxsH.length = 256} {hIdxsHLt : ∀ j ∈ idxsH, j < 2 ^ (logN + lr)}
    {clH : List Block.ZClaim} {hLenH : clH.length = gH + 1}
    {haudH : auditClaims clH (2 ^ logN) (dH + 2 + 2 * gH + 2) (List.range' (dH + 2) (2 * gH))
      (some (dH, dH + 1)) (dH + 2 + 2 * gH) = .ok ()}
    {proxRH : List Fp2}
    {hDetH : (Exec.Block.det (proxRH.getD (dH + 2 + 2 * gH) Fp2.zero) (proxRH.getD (dH + 2 + 2 * gH + 1) Fp2.zero)).v ≠ 0}
    {datH : Dt → Fin dH → Fin (2 ^ logN) → GF}
    {hdH : ∀ y, ∑ col : Fin (2 ^ logN), ∑ i : Fin dH,
      (claimWeight logN clH[gH] i.val).toK shdP_U * algebraMap GF shdP_K (datH y i col) = 0}
    {y : Dt} {cAH : PcsAHCoins GF ⟨mkStdSpec logN lr dA gA, mkStdSpec logN lr dH gH⟩} :
    let D := pcsAHData_of_audit logN lr dA gA dH gH hkl idxsA hIdxsALen hIdxsALt clA haudA proxRA hDetA datA
      idxsH hIdxsHLen hIdxsHLt clH hLenH haudH proxRH hDetH datH hdH
    let permH := hAuditPerm logN dH gH clH hLenH haudH
    let ωH : Hiding.WeightsH shdP_K (Fin dH) (Fin gH) :=
      { sD := fun j => (claimWeight logN clH[gH] j.val).toK shdP_U
        sa := (claimWeight logN clH[gH] dH).toK shdP_U
        sb := (claimWeight logN clH[gH] (dH + 1)).toK shdP_U
        wD := fun p j => (claimWeight logN clH[(permH p).val] j.val).toK shdP_U
        wU := fun p b => (claimWeight logN clH[(permH p).val] (if b then dH else dH + 1)).toK shdP_U
        a := fun p => (claimWeight logN clH[(permH p).val] (dH + 2 + 2 * p.val)).toK shdP_U
        b := fun p => (claimWeight logN clH[(permH p).val] (dH + 2 + 2 * p.val + 1)).toK shdP_U
        pD := fun j => (proxRH.getD j.val Fp2.zero).toK shdP_U
        pU := fun b => (proxRH.getD (if b then dH else dH + 1) Fp2.zero).toK shdP_U
        pG := fun gs => (proxRH.getD (dH + 2 + 2 * gs.1.val + if gs.2 then 0 else 1) Fp2.zero).toK shdP_U
        pa := (proxRH.getD (dH + 2 + 2 * gH) Fp2.zero).toK shdP_U
        pb := (proxRH.getD (dH + 2 + 2 * gH + 1) Fp2.zero).toK shdP_U }
    (D.view y cAH).1.2 = Hiding.openingViewH (pcsEvalMat logN lr hkl (dedupIdx idxsH hIdxsHLt)) shdP_zsGen ωH (datH y) cAH.1.2 := rfl

private theorem shdP_hout_inc_eq {Hdr : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ)
    (y : AdmAt Rp verdict) (c : ShdCoins) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (Fy : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      y.1 c vf)
    (hIncInv : Fy.incT.ch = FRef.incT.ch ∧ Fy.incT.dfs = FRef.incT.dfs
      ∧ Fy.incT.acc.claims.a.map Block.ZClaim.parts = FRef.incT.acc.claims.a.map Block.ZClaim.parts
      ∧ Fy.incT.acc.claims.h.map Block.ZClaim.parts = FRef.incT.acc.claims.h.map Block.ZClaim.parts
      ∧ Fy.incT.acc.claims.inp.map Block.ZClaim.parts = FRef.incT.acc.claims.inp.map Block.ZClaim.parts
      ∧ (Fy.incT.acc.fs ++ Fy.incT.acc.hostFs).map Exec.Block.MaskFunctional.terms
        = (FRef.incT.acc.fs ++ FRef.incT.acc.hostFs).map Exec.Block.MaskFunctional.terms) :
    let D1 := shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
    let D2 := shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
    let G_in := rcIncGeom (shdVi tag Rp embDigest bInRow) 28
    let incSeg : StageSeg := ⟨some (levelsOfV vf 16 4104).getRoot,
      ⟨(levelsOfV vf 14 (4104 + 131071 + 5)).getRoot,
       (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15)).getRoot,
       (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3)).getRoot,
       Fy.incT.sps, Fy.incT.mO, Fy.incT.aO, Fy.incT.hO⟩, [Fy.incT.eO]⟩
    encStage G_in (vf 4101) (posTagOfV vf 4102) incSeg (posTagOfV vf (4104 + incSegFixedLen))
      = shdP_Rc_inc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
          (D1.view y c.1, fun s => (D2 s).view y c.1 (c.2 s)) := by
  intro D1 D2 G_in incSeg
  unfold shdP_Rc_inc
  dsimp only [G_in, incSeg]
  have hVinc := shdP_D1_view_incAH tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c
  have hVD2_0_fst := shdP_D2_view_inc_fst tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c
  have hVD2_0_mO := shdP_D2_view_inc_mOpen tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c
  have hVD2_0_snd := shdP_D2_view_inc_snd tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c
  let D2r := shdP_D2_inc_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  refine congrArg (fun sg => encStage _ _ _ sg _) (congrArg₂ (StageSeg.mk _) ?_ (congrArg (fun e => [e]) ?_))
  · -- Core of IN-C (`sps`, `mO`, `aO`, `hO`)
    refine core_mk_congr ?_ ?_ ?_ ?_
    · -- `sps`: 4 slots
      refine List.ext_getElem (by rw [Fy.incT.sps_len, List.length_ofFn]) fun i hi1 hi2 => ?_
      rw [Fy.incT.sps_len] at hi1
      let t : Fin 4 := ⟨i, hi1⟩
      simp only [List.getElem_ofFn]
      have hspY := Fy.incT.slot_spec t
      dsimp only at hspY
      have hchEq := hIncInv.1
      have hdfEq : Fy.incT.dfs t = FRef.incT.dfs t := congrFun hIncInv.2.1 t
      let P0 := (shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub FRef.incT.ch)
      let bj0 := incSlBase + slotsFixedLen P0 0 t.val
      let rhoFull0 := (List.range (slotN P0 t.val)).map (fun r => challengeFp2Of (vf (bj0 + P0.draws t.val + 3 + 2 * r + 1)))
      let n0 := (Exec.Block.slotShape P0 t.val).1
      let tms0 := stgPrivValsFromView (atLog P0 (incElog (shdVi tag Rp embDigest bInRow).pub 14 t.val))
        (incCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef (D1.view y c.1))
        (rhoFull0.take n0) (rhoFull0.drop n0) (FRef.incT.dfs t).tabs
      have hscEq : (Fy.incT.sps[t.val]'(by rw [Fy.incT.sps_len]; exact t.isLt)).scalar
          = (slotProofRecon (shdSegKind ⟨0, by decide⟩)
              (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) ⟨0, by decide⟩)
              (fun u => (challengeFp2Of (vf (incSlBase + slotsFixedLen P0 0 u.val + P0.draws u.val + 1))).toK shdP_U)
              ((D2 ⟨0, by decide⟩).view y c.1 (c.2 ⟨0, by decide⟩)).1.1 t tms0).scalar := by
        rw [hspY.2.2.2.1, show ((D2 ⟨0, by decide⟩).view y c.1 (c.2 ⟨0, by decide⟩)).1.1 = (D2r.view y c.1 (c.2 ⟨0, by decide⟩)).1.1 from hVD2_0_fst]
        dsimp only [shdP_incSlotData, polySlotData, slotProofRecon, ShdSegL2Data.view]
        rw [hchEq]
        have hnd := inc_slotND_eq tag Rp embDigest bInRow FRef.incT.ch t
        rw [hnd.1, hnd.2, inc_mRowKOf_eq c, cubeSum_maskPoly_packSegMA_eq_cfsTotal ⟨0, by decide⟩ (c.2 ⟨0, by decide⟩) t]
        congr 1
      have hrdEq : (Fy.incT.sps[t.val]'(by rw [Fy.incT.sps_len]; exact t.isLt)).rounds
          = (slotProofRecon (shdSegKind ⟨0, by decide⟩)
              (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) ⟨0, by decide⟩)
              (fun u => (challengeFp2Of (vf (incSlBase + slotsFixedLen P0 0 u.val + P0.draws u.val + 1))).toK shdP_U)
              ((D2 ⟨0, by decide⟩).view y c.1 (c.2 ⟨0, by decide⟩)).1.1 t tms0).rounds := by
        rw [hspY.2.2.2.2.1, show ((D2 ⟨0, by decide⟩).view y c.1 (c.2 ⟨0, by decide⟩)).1.1 = (D2r.view y c.1 (c.2 ⟨0, by decide⟩)).1.1 from hVD2_0_fst]
        dsimp only [shdP_incSlotData, polySlotData, slotProofRecon, ShdSegL2Data.view]
        rw [hchEq, hdfEq]
        have hnd := inc_slotND_eq tag Rp embDigest bInRow FRef.incT.ch t
        have hsc := scProve_honestW_cast_eq hnd.1 hnd.2
          (shdP_L2_slot_bounds ⟨0, by decide⟩ t).1
          (shdP_L2_slot_bounds ⟨0, by decide⟩ t).2.2.1
          (maskedOfKind (shdSegKind ⟨0, by decide⟩ t))
          (slotPolyK ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub FRef.incT.ch))
            (incElog (shdVi tag Rp embDigest bInRow).pub 14)
            (incCs (shdP_incTA y.1.1 (shdIncRndOf c)) (shdP_incTH Rp embDigest y.1.1 (shdIncRndOf c) FRef.incT.ch)
              (shdP_epTable (Hdr := Hdr) tag y.1.1 (shdEpBase c)) (shdP_incTB Rp y.1.1 (shdIncRndOf c)))
            t.val (FRef.incT.dfs t))
          (D2r.hf y c.1 t)
          (mRowKOf 4 (shdIncRndOf c).mA) t.val (D2r.c t) ((c.2 ⟨0, by decide⟩).1.1 t)
          ((maskPoly_cast_eq (inc_mRowKOf_eq c) hnd.1 hnd.2).trans
            (maskPoly_packSegMA_eq_cfsEval ⟨0, by decide⟩ (c.2 ⟨0, by decide⟩) t))
          vf ⟨vf (bj0 + P0.draws t.val + 2), 0, none⟩ (bj0 + P0.draws t.val + 3)
        have hD2c : D2r.c t = (challengeFp2Of (vf (incSlBase + slotsFixedLen ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub FRef.incT.ch)) 0 t.val
            + ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub FRef.incT.ch)).draws t.val + 1))).toK shdP_U := rfl
        have hD2rho : D2r.ρ t = vecK shdP_U ((shdP_L2Spec ⟨0, by decide⟩).n t + 1)
            ((List.range (slotN ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub FRef.incT.ch)) t.val)).map
              (fun r => challengeFp2Of (vf (incSlBase + slotsFixedLen ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub FRef.incT.ch)) 0 t.val
                + ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub FRef.incT.ch)).draws t.val + 3 + 2 * r + 1)))) := rfl
        have hvec' : D2r.ρ t = fun j : Fin ((shdP_L2Spec ⟨0, by decide⟩).n t + 1) =>
            (challengeFp2Of (vf (bj0 + P0.draws t.val + 3 + 2 * j.val + 1))).toK shdP_U := by
          rw [hD2rho, hnd.1]; exact vecK_range_eq _ _ _
        have hD2f : D2r.f y c.1 t = fun x => slotPolyK ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub FRef.incT.ch))
            (incElog (shdVi tag Rp embDigest bInRow).pub 14)
            (incCs (shdP_incTA y.1.1 (shdIncRndOf c)) (shdP_incTH Rp embDigest y.1.1 (shdIncRndOf c) FRef.incT.ch)
              (shdP_epTable (Hdr := Hdr) tag y.1.1 (shdEpBase c)) (shdP_incTB Rp y.1.1 (shdIncRndOf c)))
            t.val (FRef.incT.dfs t) (fun i => x (i.cast hnd.1)) := rfl
        rw [hvec', hD2f]
        simpa only [hD2c, bj0, P0, incSlBase] using hsc
      have htmEq : (Fy.incT.sps[t.val]'(by rw [Fy.incT.sps_len]; exact t.isLt)).terms = tms0 := by
        rw [hspY.2.2.2.2.2.1]
        dsimp only [shdP_incSlotData, polySlotData]
        rw [hchEq, hdfEq]
        exact stgPrivVals_eq_fromView _ _ _ _ _ _ fun p hp =>
          incCs_eq_incCsViewOf tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
            hne verdict vf FRef y c.1 t p hp
      exact slotProof_ext hscEq hrdEq htmEq
    · -- `mO` of IN-C
      have hqEq := qPoly_eq_of_terms (shdP_incM (shdIncRndOf c)) 4 (Fy.incT.acc.fs ++ Fy.incT.acc.hostFs)
        (FRef.incT.acc.fs ++ FRef.incT.acc.hostFs) hIncInv.2.2.2.2.2 ((challengeFp2Of (vf incMoBase)).toK shdP_U)
      have hm := segMOpen_of_mOpenView ⟨0, by decide⟩ (c.2 ⟨0, by decide⟩)
        (FRef.incT.acc.fs ++ FRef.incT.acc.hostFs) (challengeFp2Of (vf incMoBase))
        ((List.range (2 * 4 + 2)).map fun j => challengeFp2Of (vf (incMoBase + 2 + j)))
        (idxsOf 12 vf (incMoBase + 13)) (idxsOf_lt 12 vf _)
        (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3))
      refine (Fy.incT.mO_eq.trans ?_).trans
        (hm.trans (congrArg₂ (segMOpenRecon ⟨0, by decide⟩ (idxsOf 12 vf (incMoBase + 13)) (idxsOf_lt 12 vf _)
          (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3))) ?_ hVD2_0_snd.symm))
      · rw [show (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3 + 167) = incMoBase from rfl, hqEq, idxsOf_mDom]; rfl
      · exact (shdSegL2Data_mOpen_eq D2r y c.1 (c.2 ⟨0, by decide⟩) rfl rfl).trans hVD2_0_mO.symm
    · -- `aO` of IN-C
      have ha := stdOpen_of_view 12 2 33 3 (by norm_num) shdP_stgPrm rfl rfl rfl
        (idxsOf 14 vf (incAoBase + 48)) (idxsOf_length 14 vf _) (idxsOf_lt 14 vf _)
        Fy.incT.acc.claims.a FRef.incT.acc.claims.a hIncInv.2.2.1 FRef.incT.haudA
        ((List.range 3).map fun j => challengeFp2Of (vf (incAoBase + j)))
        ((List.range 41).map fun j => challengeFp2Of (vf (incAoBase + 3 + j)))
        (by rw [FRef.incT.hSumA]; simp) (by simp) FRef.incT.hDetA
        (fun y' : AdmAt Rp verdict => incADat y'.1.1) y
        ((c.1.2.2 ⟨0, by decide⟩).1.1, (c.1.2.2 ⟨0, by decide⟩).2.1)
        (shdP_incTA y.1.1 (shdIncRndOf c)) (shdP_incTA_rows_len _ _)
        (shdP_incTA_rows_eq y.1.1 c) (shdP_incTA_colsHonest _ _) (shdP_incTA_cols_canon _ _)
        (shdP_incTA_salts_eq y.1.1 c) (levelsOfV vf 14 (4104 + 131071 + 5))
      refine (Fy.incT.aO_eq.trans ?_).trans
        (ha.trans (congrArg (stdOpenRecon 12 2 33 3 (idxsOf 14 vf (incAoBase + 48)) (idxsOf_lt 14 vf _)
          FRef.incT.acc.claims.a FRef.incT.haudA
          ((List.range 3).map fun j => challengeFp2Of (vf (incAoBase + j)))
          (levelsOfV vf 14 (4104 + 131071 + 5))) ?_))
      · rw [idxsOf_stgPrm]; rfl
      · refine Eq.trans ?_ (congrArg (fun v : PcsAHView GF shdP_K ⟨shdP_incASpec, shdP_incHSpec⟩ _ _ => (v.1.1, v.2.1)) hVinc.symm)
        unfold shdP_D1_ah_inc
        exact pcsAHData_of_audit_view_A'.symm
    · -- `hO` of IN-C
      have hh := hOpen_of_view 12 2 66 3 (by norm_num) shdP_stgPrm rfl rfl rfl
        (idxsOf 14 vf (incHoBase + 85)) (idxsOf_lt 14 vf _)
        (Fy.incT.acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim])
        (FRef.incT.acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim])
        (by rw [List.map_append, List.map_append, hIncInv.2.2.2.1])
        FRef.incT.hLenH FRef.incT.haudH
        ((List.range 4).map fun j => challengeFp2Of (vf (incHoBase + j)))
        ((List.range 76).map fun j => challengeFp2Of (vf (incHoBase + 4 + j)))
        (by rw [FRef.incT.hSumH]; simp) (by simp)
        (incHDat Rp embDigest FRef.incT.ch y.1.1) (c.1.2.2 ⟨0, by decide⟩).1.2 (c.1.2.2 ⟨0, by decide⟩).2.2
        (shdP_incTH Rp embDigest y.1.1 (shdIncRndOf c) FRef.incT.ch) (shdP_incTH_rows_len _ _ _ _ _)
        (shdP_incTH_rows_eq Rp embDigest FRef.incT.ch y.1.1 c) (shdP_incTH_colsHonest _ _ _ _ _)
        (shdP_incTH_cols_canon _ _ _ _ _) (shdP_incTH_salts_eq Rp embDigest y.1.1 c FRef.incT.ch)
        (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15))
      refine (Fy.incT.hO_eq.trans ?_).trans
        (hh.trans (congrArg₂ (hOpenRecon 12 2 66 3 (idxsOf 14 vf (incHoBase + 85)) (idxsOf_lt 14 vf _)
          (FRef.incT.acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim])
          FRef.incT.hLenH FRef.incT.haudH
          ((List.range 4).map fun j => challengeFp2Of (vf (incHoBase + j)))
          (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15))) ?_ ?_))
      · rw [hIncInv.1, idxsOf_stgPrm]; rfl
      · refine Eq.trans ?_ (congrArg (fun v : PcsAHView GF shdP_K ⟨shdP_incASpec, shdP_incHSpec⟩ _ _ => v.1.2) hVinc.symm)
        symm
        unfold shdP_D1_ah_inc
        dsimp only
        exact pcsAHData_of_audit_view_H'
      · refine Eq.trans ?_ (congrArg (fun v : PcsAHView GF shdP_K ⟨shdP_incASpec, shdP_incHSpec⟩ _ _ => v.2.2) hVinc.symm)
        rfl
  · -- `eO` of IN-C (`TE`)
    have hc0 := incTeClaim_of_trace tag Rp embDigest bInRow _ default vf FRef.incT
    have he := teOpen_of_view (idxsOf 11 vf (incEoBase + 9)) (idxsOf_length 11 vf _) (idxsOf_lt 11 vf _)
      Fy.incT.acc.claims.inp hc0.choose (by rw [← hc0.choose_spec.1]; exact hIncInv.2.2.2.2.1)
      hc0.choose_spec.2.1 hc0.choose_spec.2.2
      ((List.range 1).map fun j => challengeFp2Of (vf (incEoBase + j)))
      ((List.range 6).map fun j => challengeFp2Of (vf (incEoBase + 1 + j)))
      (by simp) (by simp) FRef.incT.hDetE
      (fun y' : AdmAt Rp verdict => teDatOf y'.1.1) y c.1.1
      (shdP_epTable (Hdr := Hdr) tag y.1.1 (shdEpBase c)) (shdP_epTable_rows_length _ _ _)
      (shdP_epTable_rows_eq tag y.1.1 c) (shdP_epTable_colsHonest _ _ _) (shdP_epTable_cols_canon _ _ _)
      (shdP_epTable_salts_eq tag y.1.1 c) (levelsOfV vf 11 0)
    have hVte := shdP_D1_view_te tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c
    refine (Fy.incT.eO_eq.trans ?_).trans
      (he.trans (congrArg (teOpenRecon (idxsOf 11 vf (incEoBase + 9)) (idxsOf_lt 11 vf _) hc0.choose
        ((List.range 1).map fun j => challengeFp2Of (vf (incEoBase + j))) (levelsOfV vf 11 0)) hVte.symm))
    rw [idxsOf_epPrm]; rfl

private theorem blkTM_eq_segMTable (c : ShdCoins) (k : Fin 26) :
    let s : Fin 28 := ⟨k.val + 1, by omega⟩
    blkTM (shdBlkRndOf c k) = mkMTable (shdSegNS s) (packSegMA s (c.2 s))
      ((c.2 s).1.2.2.1 true) ((c.2 s).1.2.2.1 false)
      ((c.2 s).1.2.2.2 true) ((c.2 s).1.2.2.2 false) (extSalt (c.2 s).2) := by
  intro s
  have hns : shdSegNS s = 23 := by unfold shdSegNS s; dsimp only; rw [ite_eq_right (by omega), ite_eq_right (by omega)]
  exact mkMTable_congr hns.symm _ _ (fun _ _ _ => rfl) _ _ _ _ _

private theorem shdP_hout_blk_eq {Hdr : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ)
    (y : AdmAt Rp verdict) (c : ShdCoins) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (Fy : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      y.1 c vf)
    (k : Fin 26)
    (hCrInvK : (Fy.crAt ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).pending.map Block.ZClaim.parts
      = (FRef.crAt ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).pending.map Block.ZClaim.parts)
    (hBInv : (Fy.blkT k).bga = (FRef.blkT k).bga ∧ (Fy.blkT k).dfs = (FRef.blkT k).dfs
      ∧ (Fy.blkT k).acc.claims.a.map Block.ZClaim.parts = (FRef.blkT k).acc.claims.a.map Block.ZClaim.parts
      ∧ (Fy.blkT k).acc.claims.h.map Block.ZClaim.parts = (FRef.blkT k).acc.claims.h.map Block.ZClaim.parts
      ∧ (Fy.blkT k).acc.claims.inp.map Block.ZClaim.parts = (FRef.blkT k).acc.claims.inp.map Block.ZClaim.parts
      ∧ ((Fy.blkT k).acc.fs ++ (Fy.blkT k).acc.hostFs).map Exec.Block.MaskFunctional.terms
        = ((FRef.blkT k).acc.fs ++ (FRef.blkT k).acc.hostFs).map Exec.Block.MaskFunctional.terms) :
    let D1 := shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
    let D2 := shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
    let sg := Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2
    let stTag := if k.val = 0 then posTagOfV vf (4104 + incSegFixedLen) else posTagOfV vf (blkBase ⟨k.val - 1, by omega⟩ + blkSegFixedLen)
    let eTag := posTagOfV vf (blkBase k + blkSegFixedLen)
    let seg : Segment := ⟨some (levelsOfV vf 16 (blkBase k)).getRoot,
      ⟨(levelsOfV vf 16 (blkBase k + 131071 + 5)).getRoot,
       (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)).getRoot,
       (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)).getRoot,
       (Fy.blkT k).sps, (Fy.blkT k).mO, (Fy.blkT k).aO, (Fy.blkT k).hO⟩, (Fy.blkT k).bO, none⟩
    Exec.Block.encSeg (vf 4101) sg.l sg.k stTag seg eTag
      = shdP_Rc_blk tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
          (D1.view y c.1, fun s => (D2 s).view y c.1 (c.2 s)) k := by
  intro D1 D2 sg stTag eTag seg
  unfold shdP_Rc_blk
  dsimp only [sg, stTag, eTag, seg]
  let s : Fin 28 := ⟨k.val + 1, by omega⟩
  have hVD2_fst := shdP_D2_view_blk_fst tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c k
  have hVD2_mO := shdP_D2_view_blk_mOpen tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c k
  have hVD2_snd := shdP_D2_view_blk_snd tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c k
  have hVblk := shdP_D1_view_blkAH tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c k
  let D2r := shdP_D2_blk_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef k
  refine congrArg (fun sg => Exec.Block.encSeg _ _ _ _ sg _) (congrArg₂ (fun cr bO => Segment.mk _ cr bO none) ?_ ?_)
  · -- Core of block `k` (`sps`, `mO`, `aO`, `hO`)
    refine core_mk_congr ?_ ?_ ?_ ?_
    · -- `sps` (23 slots)
      have hns : shdSegNS s = 23 := by unfold shdSegNS s; dsimp only; rw [ite_eq_right (by omega), ite_eq_right (by omega)]
      refine List.ext_getElem (by rw [(Fy.blkT k).sps_len, List.length_ofFn, hns]) fun ti hti1 hti2 => ?_
      rw [(Fy.blkT k).sps_len] at hti1
      let t : Fin (shdSegNS s) := ⟨ti, by omega⟩
      let t23 : Fin 23 := ⟨ti, hti1⟩
      simp only [List.getElem_ofFn]
      have hspY := (Fy.blkT k).slot_spec t23
      dsimp only at hspY
      have hbgaEq := hBInv.1
      have hdfEq : (Fy.blkT k).dfs t23 = (FRef.blkT k).dfs t23 := congrFun hBInv.2.1 t23
      let Pk := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
      let bjK := blkSlBase k + slotsFixedLen Pk 0 t.val
      let rhoFullK := (List.range (slotN Pk t.val)).map (fun r => challengeFp2Of (vf (bjK + Pk.draws t.val + 3 + 2 * r + 1)))
      let nK := (Exec.Block.slotShape Pk t.val).1
      let tmsK := stgPrivValsFromView Pk
        (blkCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef k (D1.view y c.1))
        (rhoFullK.take nK) (rhoFullK.drop nK) ((FRef.blkT k).dfs (blkFin k t)).tabs
      have hscEq : ((Fy.blkT k).sps[ti]'((Fy.blkT k).sps_len ▸ hti1)).scalar
          = (slotProofRecon (shdSegKind s) (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) s)
              (fun u => (challengeFp2Of (vf (blkSlBase k + slotsFixedLen Pk 0 u.val + Pk.draws u.val + 1))).toK shdP_U)
              ((D2 s).view y c.1 (c.2 s)).1.1 t tmsK).scalar := by
        rw [hspY.2.2.2.2.2.1, show ((D2 s).view y c.1 (c.2 s)).1.1 = (D2r.view y c.1 (c.2 s)).1.1 from hVD2_fst]
        dsimp only [blkSlotData, polySlotData, slotProofRecon, ShdSegL2Data.view]
        rw [hbgaEq, hdfEq]
        have hnd := blk_slotND_eq tag ioIn ioOut Rp hR k t
        have hKindEq : (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).kind t.val = match shdSegKind s t with
            | .standalone => SlotKind.standalone | .priv => SlotKind.priv | .host => SlotKind.host := by
          have h := (blk_slotShape_eq_L2 tag ioIn ioOut Rp hR k t23).2.2
          have hsk : shdSegKind s t = kindOf t23.val := by
            unfold shdSegKind; rw [dite_eq_right (by dsimp [s]; omega), dite_eq_right (by dsimp [s]; omega)]; rfl
          rw [hsk]; exact h
        have hsc := slotScalar_eq_slotProofRecon (shdSegKind s)
          (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) s)
          D2r.hdc (shdSeg_hhosted _ s) D2r.c D2r.ρ (D2r.f y c.1) (D2r.hf y c.1) (D2r.hsumH y c.1)
          (c.2 s).1.1 t
        have hD2c : D2r.c = fun u => (challengeFp2Of (vf (blkSlBase k + slotsFixedLen (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) 0 u.val
            + (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).draws u.val + 1))).toK shdP_U := rfl
        have hD2f : D2r.f y c.1 t = fun x =>
            let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt
            let cs := blkCs (blkTA w (shdBlkRndOf c k)) (blkTH w (shdBlkRndOf c k) (FRef.blkT k).bga)
              (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
              (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
            blkSlotPolyK (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) cs t.val ((FRef.blkT k).dfs (blkFin k t))
              (fun i => x (i.cast hnd.1)) := rfl
        rw [hD2c] at hsc
        rw [hKindEq]
        cases hkS : shdSegKind s t with
        | standalone =>
          dsimp only; rw [hkS] at hsc; dsimp only at hsc
          rw [hnd.1, hnd.2, blk_mRowKOf_eq c k, cubeSum_maskPoly_packSegMA_eq_cfsTotal s (c.2 s) t]; rfl
        | priv =>
          dsimp only; dsimp only at hsc; rw [hkS, hD2f] at hsc
          have hcsC := cubeSum_cast hnd.1.symm
            (blkSlotPolyK (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val)
              (blkCs (blkTA (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf c k))
                (blkTH (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf c k) (FRef.blkT k).bga)
                (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
                (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩))
              t.val ((FRef.blkT k).dfs t23))
          have hMsum : cubeSum (Link.maskPoly (mRowKOf 23 (shdBlkRndOf c k).mA) t23.val (slotN Pk t23.val) (slotD Pk t23.val))
              = Hiding.cfsTotal ((c.2 s).1.1 t) := by
            rw [hnd.1, hnd.2, blk_mRowKOf_eq c k]; exact cubeSum_maskPoly_packSegMA_eq_cfsTotal s (c.2 s) t
          rw [hMsum]
          exact congrArg (ofK shdP_U shdP_hbij) (by dsimp only [Exec.Block.histOf]; rw [← hcsC, hD2f, hD2c]; exact hsc)
        | host =>
          dsimp only; dsimp only at hsc; rw [hkS] at hsc
          rw [hnd.1, hnd.2, blk_mRowKOf_eq c k, cubeSum_maskPoly_packSegMA_eq_cfsTotal s (c.2 s) t]
          congr 1
          have hP0eq : shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val = shdP_blkParams tag ioIn ioOut (checkField shdP_blkOpenGeom) (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) :=
            ZK60.ProtocolClassify.shdP_Pk0_eq_blkParams tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR k.val k.isLt
          have hfst : ((FRef.blkT k).dfs t23).hosted.map Prod.fst = hostsOf t23.val := by
            have hd := ((FRef.blkT k).slot_spec t23).2.1; rw [hP0eq] at hd
            exact shdP_blk_hosted_fst tag ioIn ioOut (checkField shdP_blkOpenGeom) (shdP_layer k.val k.isLt)
              (shdP_blkPub Rp hR k.val k.isLt) t23.val t23.isLt _ _ _ hd
          have hltH : ∀ hk ∈ ((FRef.blkT k).dfs t23).hosted, hk.1 < t.val := fun hk hmem => by
            have hm : hk.1 ∈ hostsOf t23.val := by rw [← hfst]; exact List.mem_map.mpr ⟨hk, hmem, rfl⟩
            have hltHosts : ∀ u < 23, ∀ v ∈ hostsOf u, v < u := by decide
            exact hltHosts t23.val t23.isLt hk.1 hm
          have hmapH : (((FRef.blkT k).dfs t23).hosted.map fun hk =>
              hk.2.toK shdP_U * (((Fy.blkT k).accs t23).cs.getD hk.1 Fp2.zero).toK shdP_U
                * cubeSum (Link.maskPoly (mRowKOf 23 (shdBlkRndOf c k).mA) hk.1 (slotN Pk hk.1) (slotD Pk hk.1)))
            = (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) s t).map fun p =>
                p.2 * ((challengeFp2Of (vf (blkSlBase k + slotsFixedLen Pk 0 p.1.val + Pk.draws p.1.val + 1))).toK shdP_U * Hiding.cfsTotal ((c.2 s).1.1 p.1)) := by
            let Gfn : ℕ × shdP_K → shdP_K := fun p =>
              if h : p.1 < shdSegNS s then
                p.2 * ((challengeFp2Of (vf (blkSlBase k + slotsFixedLen Pk 0 p.1 + Pk.draws p.1 + 1))).toK shdP_U * Hiding.cfsTotal ((c.2 s).1.1 ⟨p.1, h⟩))
              else 0
            have hL1 : (((FRef.blkT k).dfs t23).hosted.map fun hk =>
                hk.2.toK shdP_U * (((Fy.blkT k).accs t23).cs.getD hk.1 Fp2.zero).toK shdP_U
                  * cubeSum (Link.maskPoly (mRowKOf 23 (shdBlkRndOf c k).mA) hk.1 (slotN Pk hk.1) (slotD Pk hk.1)))
                = (((FRef.blkT k).dfs t23).hosted.map (fun hk => (hk.1, hk.2.toK shdP_U))).map Gfn := by
              rw [List.map_map]
              refine List.map_congr_left fun hk hmem => ?_
              have hlt := hltH hk hmem
              have hltS : hk.1 < shdSegNS s := lt_trans hlt t.isLt
              simp only [Function.comp_apply, Gfn, dite_eq_left hltS]
              have hcsAcc : ((Fy.blkT k).accs t23).cs = (Fy.blkT k).acc.cs.take t.val := hspY.2.2.1
              have hcsGet : ((Fy.blkT k).accs t23).cs.getD hk.1 Fp2.zero
                  = challengeFp2Of (vf (blkSlBase k + slotsFixedLen Pk 0 hk.1 + Pk.draws hk.1 + 1)) := by
                rw [hcsAcc, List.getD_eq_getElem?_getD, List.getElem?_take_of_lt hlt,
                  List.getElem?_eq_getElem (by rw [(Fy.blkT k).cs_len]; omega), Option.getD_some]
                exact ((Fy.blkT k).slot_spec ⟨hk.1, by omega⟩).2.2.2.2.1
              have hndU := blk_slotND_eq tag ioIn ioOut Rp hR k ⟨hk.1, hltS⟩
              rw [hcsGet, hndU.1, hndU.2, blk_mRowKOf_eq c k, cubeSum_maskPoly_packSegMA_eq_cfsTotal s (c.2 s) ⟨hk.1, hltS⟩, mul_assoc]
            have hAlign : ((FRef.blkT k).dfs t23).hosted.map (fun hk => (hk.1, hk.2.toK shdP_U))
                = (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) s t).map (fun p => (p.1.val, p.2)) := by
              have hm := hosted_map_eq_w16Hosts ((FRef.blkT k).dfs t23).hosted t23 hfst
              unfold shdSegHosts; rw [dite_eq_right (by dsimp [s]; omega), dite_eq_right (by dsimp [s]; omega), List.map_map]
              have hkSub : (⟨s.val - 1, by dsimp [s]; omega⟩ : Fin 26) = k := Fin.ext (Nat.add_sub_cancel k.val 1)
              have htCast : (t.cast (by dsimp only [shdSegNS, s]; rw [ite_eq_right (by omega), ite_eq_right (by omega)]) : Fin nSlots) = t23 := Fin.ext rfl
              rw [hkSub, htCast]
              rw [show ((fun p : Fin (shdSegNS s) × shdP_K => (p.1.val, p.2)) ∘ fun p : Fin nSlots × shdP_K => (p.1.cast _, p.2))
                  = (fun p : Fin nSlots × shdP_K => (p.1.val, p.2)) from funext fun _ => rfl]
              simpa only [w16Hosts, shdP_hc] using hm
            rw [hL1, hAlign, List.map_map]
            refine List.map_congr_left fun p _ => by simp [Gfn, p.1.isLt]
          rw [blk_mRowKOf_eq c k] at hmapH
          dsimp only [Pk] at hmapH
          rw [hmapH, hD2c]; exact hsc
      have hrdEq : ((Fy.blkT k).sps[ti]'((Fy.blkT k).sps_len ▸ hti1)).rounds
          = (slotProofRecon (shdSegKind s) (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) s)
              (fun u => (challengeFp2Of (vf (blkSlBase k + slotsFixedLen Pk 0 u.val + Pk.draws u.val + 1))).toK shdP_U)
              ((D2 s).view y c.1 (c.2 s)).1.1 t tmsK).rounds := by
        rw [hspY.2.2.2.2.2.2.1, show ((D2 s).view y c.1 (c.2 s)).1.1 = (D2r.view y c.1 (c.2 s)).1.1 from hVD2_fst]
        dsimp only [blkSlotData, polySlotData, slotProofRecon, ShdSegL2Data.view, Exec.Block.histOf]
        rw [hbgaEq, hdfEq, show ((FRef.blkT k).bga.1, (FRef.blkT k).bga.2.1, (FRef.blkT k).bga.2.2) = (FRef.blkT k).bga from rfl]
        have hnd := blk_slotND_eq tag ioIn ioOut Rp hR k t
        let wK := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt
        let csK := blkCs (blkTA wK (shdBlkRndOf c k)) (blkTH wK (shdBlkRndOf c k) (FRef.blkT k).bga)
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
        have hsc := scProve_honestW_cast_eq hnd.1 hnd.2
          (shdP_L2_slot_bounds s t).1 (shdP_L2_slot_bounds s t).2.2.1
          (maskedOfKind (shdSegKind s t))
          (blkSlotPolyK (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) csK t.val ((FRef.blkT k).dfs (blkFin k t)))
          (D2r.hf y c.1 t)
          (mRowKOf 23 (shdBlkRndOf c k).mA) t.val (D2r.c t) ((c.2 s).1.1 t)
          ((maskPoly_cast_eq (blk_mRowKOf_eq c k) hnd.1 hnd.2).trans
            (maskPoly_packSegMA_eq_cfsEval s (c.2 s) t))
          vf ⟨vf (bjK + Pk.draws t.val + 2), 0, none⟩ (bjK + Pk.draws t.val + 3)
        have hD2c : D2r.c t = (challengeFp2Of (vf (blkSlBase k + slotsFixedLen (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) 0 t.val
            + (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).draws t.val + 1))).toK shdP_U := rfl
        have hD2rho : D2r.ρ t = vecK shdP_U ((shdP_L2Spec s).n t + 1)
            ((List.range (slotN (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) t.val)).map
              (fun r => challengeFp2Of (vf (blkSlBase k + slotsFixedLen (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) 0 t.val
                + (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).draws t.val + 3 + 2 * r + 1)))) := rfl
        have hvec' : D2r.ρ t = fun j : Fin ((shdP_L2Spec s).n t + 1) =>
            (challengeFp2Of (vf (bjK + Pk.draws t.val + 3 + 2 * j.val + 1))).toK shdP_U := by
          rw [hD2rho, hnd.1]; exact vecK_range_eq _ _ _
        have hD2f : D2r.f y c.1 t = fun x =>
            blkSlotPolyK (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) csK t.val ((FRef.blkT k).dfs (blkFin k t))
              (fun i => x (i.cast hnd.1)) := rfl
        have ht23 : blkFin k t = t23 := Fin.ext rfl
        rw [hvec', hD2f]
        rw [ht23, hD2c] at hsc ⊢
        dsimp only [bjK, Pk, blkSlBase, csK, wK, s, t, t23] at hsc ⊢
        exact hsc
      have htmEq : ((Fy.blkT k).sps[ti]'((Fy.blkT k).sps_len ▸ hti1)).terms = tmsK := by
        rw [hspY.2.2.2.2.2.2.2.1]
        dsimp only [blkSlotData, polySlotData, Exec.Block.histOf, tmsK, rhoFullK, bjK, nK, Pk]
        rw [hbgaEq, hdfEq,
          show ((FRef.blkT k).bga.1, (FRef.blkT k).bga.2.1, (FRef.blkT k).bga.2.2) = (FRef.blkT k).bga from rfl,
          show blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 = blkSlBase k from rfl,
          show blkFin k t = t23 from Fin.ext rfl, show t.val = t23.val from rfl]
        have hCs : blkCs (blkTA (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf c k))
            (blkTH (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf c k) (FRef.blkT k).bga)
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
          = blkCs (blkTA (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf (cOfL1 c.1) k))
            (blkTH (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf (cOfL1 c.1) k) (FRef.blkT k).bga)
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf (cOfL1 c.1)) (shdBlkRndOf (cOfL1 c.1)) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf (cOfL1 c.1)) (shdBlkRndOf (cOfL1 c.1)) y.1.1 y.1.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩) := by
          congr 1
        refine (congrArg (fun cs => stgPrivVals shdP_U shdP_hbij _ cs _ _ _) hCs).trans ?_
        exact stgPrivVals_eq_fromView _ _ _ _ _ _ fun p hp =>
          blkCs_eq_blkCsViewOf tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
            hne verdict vf FRef k y c.1 t23 p hp
      exact slotProof_ext hscEq hrdEq htmEq
    · -- `mO` of block `k`
      have hns : shdSegNS s = 23 := by unfold shdSegNS s; dsimp only; rw [ite_eq_right (by omega), ite_eq_right (by omega)]
      have hM := blkTM_eq_segMTable c k
      have hqEq := qPoly_eq_of_terms (blkTM (shdBlkRndOf c k)) 23
        ((Fy.blkT k).acc.fs ++ (Fy.blkT k).acc.hostFs) ((FRef.blkT k).acc.fs ++ (FRef.blkT k).acc.hostFs)
        hBInv.2.2.2.2.2 ((challengeFp2Of (vf (blkMoBase k))).toK shdP_U)
      have hm := segMOpen_of_mOpenView s (c.2 s)
        ((FRef.blkT k).acc.fs ++ (FRef.blkT k).acc.hostFs) (challengeFp2Of (vf (blkMoBase k)))
        ((List.range (2 * 23 + 2)).map fun j => challengeFp2Of (vf (blkMoBase k + 2 + j)))
        (idxsOf 12 vf (blkMoBase k + 51)) (idxsOf_lt 12 vf _)
        (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3))
      refine ((Fy.blkT k).mO_eq.trans ?_).trans
        (hm.trans (congrArg₂ (segMOpenRecon s (idxsOf 12 vf (blkMoBase k + 51)) (idxsOf_lt 12 vf _)
          (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3))) ?_ hVD2_snd.symm))
      · have hOff : blkMoBase k + 2 + (2 * 23 + 2) + 1 = blkMoBase k + 51 := by omega
        rw [show blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 + 1283 = blkMoBase k from rfl, hqEq, hOff, idxsOf_mDom, ← hM, hns]
      · exact (shdSegL2Data_mOpen_eq D2r y c.1 (c.2 s) rfl rfl).trans hVD2_mO.symm
    · -- `aO` of block `k`
      have ha := stdOpen_of_view 14 2 4283 146 (by norm_num) Exec.R13.r13Prm rfl rfl rfl
        (idxsOf 16 vf (blkAoBase k + 4760)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
        (Fy.blkT k).acc.claims.a (FRef.blkT k).acc.claims.a hBInv.2.2.1 (FRef.blkT k).haudA
        ((List.range 146).map fun j => challengeFp2Of (vf (blkAoBase k + j)))
        ((List.range 4577).map fun j => challengeFp2Of (vf (blkAoBase k + 146 + j)))
        (by rw [(FRef.blkT k).hSumA]; simp) (by simp) (FRef.blkT k).hDetA
        (fun y' : AdmAt Rp verdict => blkADat Rp hR hweights hinPub k y'.1) y
        ((blkAHCoins c k).1.1, (blkAHCoins c k).2.1)
        (blkTA (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf c k))
        (blkTA_rows_len _ _) (blkTA_rows_eq Rp hR hweights hinPub y.1 c k)
        (blkTA_colsHonest _ _) (blkTA_cols_canon _ _) (blkTA_salts_eq Rp hR hweights hinPub y.1 c k)
        (levelsOfV vf 16 (blkBase k + 131071 + 5))
      refine ((Fy.blkT k).aO_eq.trans ?_).trans
        (ha.trans (congrArg (stdOpenRecon 14 2 4283 146 (idxsOf 16 vf (blkAoBase k + 4760)) (idxsOf_lt 16 vf _)
          (FRef.blkT k).acc.claims.a (FRef.blkT k).haudA
          ((List.range 146).map fun j => challengeFp2Of (vf (blkAoBase k + j)))
          (levelsOfV vf 16 (blkBase k + 131071 + 5))) ?_))
      · have hOff : blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 + 1283 + 115 + 146 + 4577 + 36 + 1 = blkAoBase k + 4760 := by
          unfold blkAoBase blkMoBase blkSlBase; omega
        rw [hOff, idxsOf_r13Prm]; rfl
      · refine Eq.trans ?_ (congrArg (fun v : PcsAHView GF shdP_K ⟨shdP_blkASpec, shdP_blkHSpec⟩ _ _ => (v.1.1, v.2.1)) hVblk.symm)
        unfold shdP_D1_ah_blk
        exact pcsAHData_of_audit_view_A'.symm
    · -- `hO` of block `k`
      have hh := hOpen_of_view 14 2 4280 53 (by norm_num) Exec.R13.r13Prm rfl rfl rfl
        (idxsOf 16 vf (blkHoBase k + 4454)) (idxsOf_lt 16 vf _)
        ((Fy.blkT k).acc.claims.h ++ [(shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).logupSumClaim])
        ((FRef.blkT k).acc.claims.h ++ [(shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).logupSumClaim])
        (by rw [List.map_append, List.map_append, hBInv.2.2.2.1])
        (FRef.blkT k).hLenH (FRef.blkT k).haudH
        ((List.range 54).map fun j => challengeFp2Of (vf (blkHoBase k + j)))
        ((List.range 4390).map fun j => challengeFp2Of (vf (blkHoBase k + 54 + j)))
        (by rw [(FRef.blkT k).hSumH]; simp) (by simp)
        (blkHDat Rp hR hweights hinPub k (FRef.blkT k).bga y.1) (blkAHCoins c k).1.2 (blkAHCoins c k).2.2
        (blkTH (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) y.1.1 y.1.2 k.val k.isLt) (shdBlkRndOf c k) (FRef.blkT k).bga)
        (blkTH_rows_len _ _ _) (blkTH_rows_eq Rp hR hweights hinPub y.1 c k (FRef.blkT k).bga)
        (blkTH_colsHonest _ _ _) (blkTH_cols_canon _ _ _) (blkTH_salts_eq Rp hR hweights hinPub y.1 c k (FRef.blkT k).bga)
        (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3))
      refine ((Fy.blkT k).hO_eq.trans ?_).trans
        (hh.trans (congrArg₂ (hOpenRecon 14 2 4280 53 (idxsOf 16 vf (blkHoBase k + 4454)) (idxsOf_lt 16 vf _)
          ((FRef.blkT k).acc.claims.h ++ [(shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).logupSumClaim])
          (FRef.blkT k).hLenH (FRef.blkT k).haudH
          ((List.range 54).map fun j => challengeFp2Of (vf (blkHoBase k + j)))
          (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3))) ?_ ?_))
      · have hOff : blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 + 1283 + 115 + 4824 + 54 + 4390 + 9 + 1 = blkHoBase k + 4454 := by
          unfold blkHoBase blkAoBase blkMoBase blkSlBase; omega
        rw [hBInv.1, hOff, idxsOf_r13Prm]; rfl
      · refine Eq.trans ?_ (congrArg (fun v : PcsAHView GF shdP_K ⟨shdP_blkASpec, shdP_blkHSpec⟩ _ _ => v.1.2) hVblk.symm)
        symm
        unfold shdP_D1_ah_blk
        dsimp only
        exact pcsAHData_of_audit_view_H'
      · refine Eq.trans ?_ (congrArg (fun v : PcsAHView GF shdP_K ⟨shdP_blkASpec, shdP_blkHSpec⟩ _ _ => v.2.2) hVblk.symm)
        rfl
  · -- `bO` of block `k` (boundary `k`)
    have hspecB := shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
    have hb := stdOpen_of_view 14 2 32 2 (by norm_num) Exec.R13.r13Prm rfl rfl rfl
      (idxsOf 16 vf (blkBoBase k + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
      ((Fy.crAt ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).pending ++ (Fy.blkT k).acc.claims.inp)
      ((FRef.crAt ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).pending ++ (FRef.blkT k).acc.claims.inp)
      (by rw [List.map_append, List.map_append, hCrInvK, hBInv.2.2.2.2.1])
      (FRef.blkT k).haudB
      ((List.range 2).map fun j => challengeFp2Of (vf (blkBoBase k + j)))
      ((List.range 38).map fun j => challengeFp2Of (vf (blkBoBase k + 2 + j)))
      (by rw [(FRef.blkT k).hSumB]; simp) (by simp) (FRef.blkT k).hDetB
      (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩ y'.1)
      y (c.1.2.1 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
      hspecB.rows_len (shdP_bndTableAt_rows_eq Rp hR hweights hinPub y.1 c ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
      hspecB.cols_honest hspecB.cols_canon (shdP_bndTableAt_salts_eq Rp hR hweights hinPub y.1 c ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
      (levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)))
    have hksB : (shdP_ks vf).bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩ = (nodupCols (idxsOf 16 vf (blkBoBase k + 43))).length := by
      unfold shdP_ks; dsimp only; exact dite_eq_left k.isLt
    have hVbnd := shdP_D1_view_bnd_blk tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c k hksB
    refine ((Fy.blkT k).bO_eq.trans ?_).trans
      (hb.trans (congrArg (stdOpenRecon 14 2 32 2 (idxsOf 16 vf (blkBoBase k + 43)) (idxsOf_lt 16 vf _)
        ((FRef.crAt ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).pending ++ (FRef.blkT k).acc.claims.inp) (FRef.blkT k).haudB
        ((List.range 2).map fun j => challengeFp2Of (vf (blkBoBase k + j)))
        (levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)))) hVbnd.symm))
    have hOff : blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 + 1283 + 115 + 4824 + 4518 + 2 + 38 + 2 + 1 = blkBoBase k + 43 := by
      unfold blkBoBase blkHoBase blkAoBase blkMoBase blkSlBase; omega
    rw [hOff, idxsOf_r13Prm]; rfl

private theorem shdP_hout_outc_eq {Hdr : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ)
    (y : AdmAt Rp verdict) (c : ShdCoins) (vf : ℕ → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default vf)
    (Fy : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      y.1 c vf)
    (hVerdRef : (classifySpecP Rp (refInput Rp hne verdict).1).getD 0 = (classifySpecP Rp y.1.1).getD 0)
    (hCrInv26 : (Fy.crAt ⟨26, by decide⟩).pending.map Block.ZClaim.parts
      = (FRef.crAt ⟨26, by decide⟩).pending.map Block.ZClaim.parts)
    (hOutInv : Fy.outcT.ch = FRef.outcT.ch ∧ Fy.outcT.dfs = FRef.outcT.dfs
      ∧ Fy.outcT.acc.claims.a.map Block.ZClaim.parts = FRef.outcT.acc.claims.a.map Block.ZClaim.parts
      ∧ Fy.outcT.acc.claims.h.map Block.ZClaim.parts = FRef.outcT.acc.claims.h.map Block.ZClaim.parts
      ∧ Fy.outcT.acc.claims.inp.map Block.ZClaim.parts = FRef.outcT.acc.claims.inp.map Block.ZClaim.parts
      ∧ (Fy.outcT.acc.fs ++ Fy.outcT.acc.hostFs).map Exec.Block.MaskFunctional.terms
        = (FRef.outcT.acc.fs ++ FRef.outcT.acc.hostFs).map Exec.Block.MaskFunctional.terms) :
    let D1 := shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
    let D2 := shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
    let G_out := rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28
    let outSeg : StageSeg := ⟨none,
      ⟨(levelsOfV vf 14 (outcBase + 2)).getRoot,
       (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2)).getRoot,
       (levelsOfV vf 12 (outcBase + 2 + 32767 + 3)).getRoot,
       Fy.outcT.sps, Fy.outcT.mO, Fy.outcT.aO, Fy.outcT.hO⟩, [Fy.outcT.bO]⟩
    encStage G_out (vf 4101) (posTagOfV vf (blkBase ⟨25, by decide⟩ + blkSegFixedLen))
        outSeg (posTagOfV vf (outcBase + outcSegFixedLen))
      = shdP_Rc_outc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
          (D1.view y c.1, fun s => (D2 s).view y c.1 (c.2 s)) := by
  intro D1 D2 G_out outSeg
  unfold shdP_Rc_outc
  dsimp only [G_out, outSeg]
  have hVout := shdP_D1_view_outcAH tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c
  have hVD2_27_fst := shdP_D2_view_outc_fst tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c
  have hVD2_27_mO := shdP_D2_view_outc_mOpen tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c
  have hVD2_27_snd := shdP_D2_view_outc_snd tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c
  let D2r := shdP_D2_outc_raw tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
  refine congrArg (fun sg => encStage _ _ _ sg _) (congrArg₂ (StageSeg.mk _) ?_ (congrArg (fun e => [e]) ?_))
  · -- Core of OUT-C (`sps`, `mO`, `aO`, `hO`)
    refine core_mk_congr ?_ ?_ ?_ ?_
    · -- `sps` (8 slots)
      refine List.ext_getElem (by rw [Fy.outcT.sps_len, List.length_ofFn]) fun ti hti1 hti2 => ?_
      rw [Fy.outcT.sps_len] at hti1
      obtain ⟨t, rfl⟩ : ∃ t : Fin 8, t.val = ti := ⟨⟨ti, hti1⟩, rfl⟩
      simp only [List.getElem_ofFn]
      have hspY := Fy.outcT.slot_spec t
      dsimp only at hspY
      have hchEq := hOutInv.1
      have hdfEq : Fy.outcT.dfs t = FRef.outcT.dfs t := congrFun hOutInv.2.1 t
      have hvY : (classifySpecP Rp y.1.1).getD 0 = (classifySpecP Rp (refInput Rp hne verdict).1).getD 0 := hVerdRef.symm
      have hvYEq : (outcWitness_of_adm Rp houtPub y.1.1 y.1.2).v = (classifySpecP Rp (refInput Rp hne verdict).1).getD 0 :=
        (outcWitness_of_adm_v Rp houtPub y.1.1 y.1.2).trans hvY
      let P27 := (shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).bp
      let bj27 := outcSlBase + slotsFixedLen P27 0 t.val
      let rhoFull27 := (List.range (slotN P27 t.val)).map (fun r => challengeFp2Of (vf (bj27 + P27.draws t.val + 3 + 2 * r + 1)))
      let n27 := (Exec.Block.slotShape P27 t.val).1
      let tms27 := stgPrivValsFromView P27
        (outcCsViewOf tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef (D1.view y c.1))
        (rhoFull27.take n27) (rhoFull27.drop n27) (FRef.outcT.dfs t).tabs
      have hscEq : (Fy.outcT.sps[t.val]'(by rw [Fy.outcT.sps_len]; exact t.isLt)).scalar
          = (slotProofRecon (shdSegKind ⟨27, by decide⟩)
              (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) ⟨27, by decide⟩)
              (fun u => (challengeFp2Of (vf (outcSlBase + slotsFixedLen P27 0 u.val + P27.draws u.val + 1))).toK shdP_U)
              ((D2 ⟨27, by decide⟩).view y c.1 (c.2 ⟨27, by decide⟩)).1.1 t tms27).scalar := by
        rw [hspY.2.2.2.2.2.1, show ((D2 ⟨27, by decide⟩).view y c.1 (c.2 ⟨27, by decide⟩)).1.1 = (D2r.view y c.1 (c.2 ⟨27, by decide⟩)).1.1 from hVD2_27_fst]
        dsimp only [shdP_outcSlotData, polySlotData, slotProofRecon, ShdSegL2Data.view]
        rw [hvY, hdfEq]
        have hnd := outc_slotND_eq tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0) t
        have hsc := slotScalar_eq_slotProofRecon (shdSegKind ⟨27, by decide⟩)
          (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) ⟨27, by decide⟩)
          D2r.hdc (shdSeg_hhosted _ ⟨27, by decide⟩) D2r.c D2r.ρ (D2r.f y c.1) (D2r.hf y c.1) (D2r.hsumH y c.1)
          (c.2 ⟨27, by decide⟩).1.1 t
        have hD2c : D2r.c = fun u => (challengeFp2Of (vf (outcSlBase + slotsFixedLen ((shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).bp) 0 u.val
            + ((shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).bp).draws u.val + 1))).toK shdP_U := rfl
        have hD2f : D2r.f y c.1 t = fun x =>
            let w := outcWitness_of_adm Rp houtPub y.1.1 y.1.2
            let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩
            let cs := outcCs (shdP_outcTA Rp w (shdOutcRndOf c))
              (shdP_outcTH Rp w (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero)) TB26
            slotPolyK (shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).bp (fun _ => 14) cs t.val (FRef.outcT.dfs t)
              (fun i => x (i.cast hnd.1)) := rfl
        rw [hD2c, hD2f] at hsc
        have hOA := outcSlot_arith tag Rp houtPub wDigest bOutRow (outcWitness_of_adm Rp houtPub y.1.1 y.1.2)
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩)
          (shdP_bndTableAt_last_outcSpec Rp hR hweights hinPub houtPub _ _ y.1.1 y.1.2)
          (shdOutcRndOf c) FRef.outcT.ch
          (fun a ha => by rw [FRef.outcT.ch_eq] at ha; obtain ⟨_, _, rfl⟩ := List.mem_map.mp ha; exact challengeFp2Of_canon _)
          FRef.outcT.hbad t (FRef.outcT.recs.take t.val)
          ((List.range (P27.draws t.val)).map fun j => challengeFp2Of (vf (bj27 + j)))
          (fun a ha => by obtain ⟨_, _, rfl⟩ := List.mem_map.mp ha; exact challengeFp2Of_canon _)
          (by simp only [List.length_map, List.length_range]; rw [hvYEq]) (FRef.outcT.dfs t)
          (by rw [hvYEq]; exact (FRef.outcT.slot_spec t).2.1)
        rw [hvYEq] at hOA
        dsimp only [bj27] at hOA
        have hKindEq : P27.kind t.val = match outcKind t with
            | .standalone => SlotKind.standalone | .priv => SlotKind.priv | .host => SlotKind.host :=
          (outc_slotShape_eq_L2 tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0) t).2.2
        have hMsum : cubeSum (Link.maskPoly (mRowKOf 8 (shdOutcRndOf c).mA) t.val (slotN P27 t.val) (slotD P27 t.val))
            = Hiding.cfsTotal ((c.2 ⟨27, by decide⟩).1.1 t) := by
          rw [hnd.1, hnd.2, outc_mRowKOf_eq c]
          exact cubeSum_maskPoly_packSegMA_eq_cfsTotal ⟨27, by decide⟩ (c.2 ⟨27, by decide⟩) t
        dsimp only at hsc
        rw [shdSegKind_outc t, shdSegHosts_outc _ t] at hsc ⊢
        rw [hKindEq, hMsum]
        clear tms27 n27 rhoFull27 bj27 hMsum
        fin_cases t <;> dsimp only at hnd hsc hOA hspY ⊢
        · -- t = 0 standalone
          rfl
        · -- t = 1 priv
          have hcsC := cubeSum_cast hnd.1.symm
            (slotPolyK P27 (fun _ => 14)
              (outcCs (shdP_outcTA Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c))
                (shdP_outcTH Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero))
                (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩))
              1 (FRef.outcT.dfs ⟨1, by decide⟩))
          have hp1 := hOA.2.2.1 rfl
          dsimp only [OutcV.bga] at hp1
          dsimp only [P27] at hcsC
          have hk1 : outcKind ⟨1, by decide⟩ = .priv := rfl
          rw [hk1] at hsc ⊢; dsimp only at hsc ⊢
          rw [hcsC, hp1] at hsc
          exact congrArg (ofK shdP_U shdP_hbij) hsc
        · -- t = 2 host [(1, ν2)]
          have h2 := (hOA.2.2.2.1 rfl).2
          have hcsAcc : (Fy.outcT.accs ⟨2, by decide⟩).cs = Fy.outcT.acc.cs.take 2 := hspY.2.2.1
          have hcs1 : (Fy.outcT.accs ⟨2, by decide⟩).cs.getD 1 Fp2.zero
              = challengeFp2Of (vf (outcSlBase + slotsFixedLen P27 0 1 + P27.draws 1 + 1)) := by
            rw [hcsAcc, List.getD_eq_getElem?_getD, List.getElem?_take_of_lt (by decide),
              List.getElem?_eq_getElem (by rw [Fy.outcT.cs_len]; decide), Option.getD_some]
            have hsp1 := (Fy.outcT.slot_spec ⟨1, by decide⟩).2.2.2.2.1
            rw [hvY] at hsp1; exact hsp1
          have hdr2 : (FRef.outcT.recs[2]'(by rw [FRef.outcT.recs_len]; omega)).draws
              = (List.range (P27.draws 2)).map (fun j => challengeFp2Of (vf (outcSlBase + slotsFixedLen P27 0 2 + j))) :=
            (FRef.outcT.slot_spec ⟨2, by decide⟩).2.2.2.1
          have hnd1 := outc_slotND_eq tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0) ⟨1, by decide⟩
          have hMsum1 : cubeSum (Link.maskPoly (mRowKOf 8 (shdOutcRndOf c).mA) 1 (slotN P27 1) (slotD P27 1))
              = Hiding.cfsTotal ((c.2 ⟨27, by decide⟩).1.1 ⟨1, by decide⟩) := by
            rw [hnd1.1, hnd1.2, outc_mRowKOf_eq c]
            exact cubeSum_maskPoly_packSegMA_eq_cfsTotal ⟨27, by decide⟩ (c.2 ⟨27, by decide⟩) ⟨1, by decide⟩
          dsimp only [P27] at hcs1 hMsum1 hdr2
          have hk2 : outcKind ⟨2, by decide⟩ = .host := rfl
          have hh2 : outcHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).νOut₂
              (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).νOut₄ ⟨2, by decide⟩
              = [(⟨1, by decide⟩, (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).νOut₂)] := rfl
          rw [hk2, hh2] at hsc ⊢; dsimp only at hsc ⊢
          rw [show outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 = outcSlBase from rfl, h2]
          simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, hcs1, hMsum1, mul_assoc]
          rw [← hdr2, hD2c]
          simp only [shdP_hc] at hsc ⊢
          dsimp only [List.map, List.sum, List.foldr] at hsc ⊢
          simp only [add_zero] at hsc ⊢
          exact congrArg (ofK shdP_U shdP_hbij) hsc
        · -- t = 3 priv
          have hcsC := cubeSum_cast hnd.1.symm
            (slotPolyK P27 (fun _ => 14)
              (outcCs (shdP_outcTA Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c))
                (shdP_outcTH Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero))
                (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩))
              3 (FRef.outcT.dfs ⟨3, by decide⟩))
          have hp3 := hOA.2.2.1 rfl
          dsimp only [OutcV.bga] at hp3
          dsimp only [P27] at hcsC
          have hk3 : outcKind ⟨3, by decide⟩ = .priv := rfl
          rw [hk3] at hsc ⊢; dsimp only at hsc ⊢
          rw [hcsC, hp3] at hsc
          exact congrArg (ofK shdP_U shdP_hbij) hsc
        · -- t = 4 host [(3, ν4)]
          have h4 := (hOA.2.2.2.2 rfl).2
          have hcsAcc : (Fy.outcT.accs ⟨4, by decide⟩).cs = Fy.outcT.acc.cs.take 4 := hspY.2.2.1
          have hcs3 : (Fy.outcT.accs ⟨4, by decide⟩).cs.getD 3 Fp2.zero
              = challengeFp2Of (vf (outcSlBase + slotsFixedLen P27 0 3 + P27.draws 3 + 1)) := by
            rw [hcsAcc, List.getD_eq_getElem?_getD, List.getElem?_take_of_lt (by decide),
              List.getElem?_eq_getElem (by rw [Fy.outcT.cs_len]; decide), Option.getD_some]
            have hsp3 := (Fy.outcT.slot_spec ⟨3, by decide⟩).2.2.2.2.1
            rw [hvY] at hsp3; exact hsp3
          have hdr4 : (FRef.outcT.recs[4]'(by rw [FRef.outcT.recs_len]; omega)).draws
              = (List.range (P27.draws 4)).map (fun j => challengeFp2Of (vf (outcSlBase + slotsFixedLen P27 0 4 + j))) :=
            (FRef.outcT.slot_spec ⟨4, by decide⟩).2.2.2.1
          have hnd3 := outc_slotND_eq tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0) ⟨3, by decide⟩
          have hMsum3 : cubeSum (Link.maskPoly (mRowKOf 8 (shdOutcRndOf c).mA) 3 (slotN P27 3) (slotD P27 3))
              = Hiding.cfsTotal ((c.2 ⟨27, by decide⟩).1.1 ⟨3, by decide⟩) := by
            rw [hnd3.1, hnd3.2, outc_mRowKOf_eq c]
            exact cubeSum_maskPoly_packSegMA_eq_cfsTotal ⟨27, by decide⟩ (c.2 ⟨27, by decide⟩) ⟨3, by decide⟩
          dsimp only [P27] at hcs3 hMsum3 hdr4
          have hk4 : outcKind ⟨4, by decide⟩ = .host := rfl
          have hh4 : outcHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).νOut₂
              (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).νOut₄ ⟨4, by decide⟩
              = [(⟨3, by decide⟩, (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef).νOut₄)] := rfl
          rw [hk4, hh4] at hsc ⊢; dsimp only at hsc ⊢
          rw [show outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 = outcSlBase from rfl, h4]
          simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, hcs3, hMsum3, mul_assoc]
          rw [← hdr4, hD2c]
          simp only [shdP_hc] at hsc ⊢
          dsimp only [List.map, List.sum, List.foldr] at hsc ⊢
          simp only [add_zero] at hsc ⊢
          exact congrArg (ofK shdP_U shdP_hbij) hsc
        · -- t = 5 standalone
          rfl
        · -- t = 6 standalone
          rfl
        · -- t = 7 standalone
          rfl
      have hrdEq : (Fy.outcT.sps[t.val]'(by rw [Fy.outcT.sps_len]; exact t.isLt)).rounds
          = (slotProofRecon (shdSegKind ⟨27, by decide⟩)
              (shdSegHosts (shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef) ⟨27, by decide⟩)
              (fun u => (challengeFp2Of (vf (outcSlBase + slotsFixedLen P27 0 u.val + P27.draws u.val + 1))).toK shdP_U)
              ((D2 ⟨27, by decide⟩).view y c.1 (c.2 ⟨27, by decide⟩)).1.1 t tms27).rounds := by
        rw [hspY.2.2.2.2.2.2.1, show ((D2 ⟨27, by decide⟩).view y c.1 (c.2 ⟨27, by decide⟩)).1.1 = (D2r.view y c.1 (c.2 ⟨27, by decide⟩)).1.1 from hVD2_27_fst]
        dsimp only [shdP_outcSlotData, polySlotData, slotProofRecon, ShdSegL2Data.view, OutcV.bga, Exec.Block.histOf]
        rw [hvY, hchEq, hdfEq]
        have hnd := outc_slotND_eq tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0) t
        let w27 := outcWitness_of_adm Rp houtPub y.1.1 y.1.2
        let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩
        let cs27 := outcCs (shdP_outcTA Rp w27 (shdOutcRndOf c))
          (shdP_outcTH Rp w27 (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero)) TB26
        have hsc := scProve_honestW_cast_eq hnd.1 hnd.2
          (shdP_L2_slot_bounds ⟨27, by decide⟩ t).1 (shdP_L2_slot_bounds ⟨27, by decide⟩ t).2.2.1
          (maskedOfKind (shdSegKind ⟨27, by decide⟩ t))
          (slotPolyK P27 (fun _ => 14) cs27 t.val (FRef.outcT.dfs t))
          (D2r.hf y c.1 t)
          (mRowKOf 8 (shdOutcRndOf c).mA) t.val (D2r.c t) ((c.2 ⟨27, by decide⟩).1.1 t)
          ((maskPoly_cast_eq (outc_mRowKOf_eq c) hnd.1 hnd.2).trans
            (maskPoly_packSegMA_eq_cfsEval ⟨27, by decide⟩ (c.2 ⟨27, by decide⟩) t))
          vf ⟨vf (bj27 + P27.draws t.val + 2), 0, none⟩ (bj27 + P27.draws t.val + 3)
        have hD2c : D2r.c t = (challengeFp2Of (vf (outcSlBase + slotsFixedLen ((shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).bp) 0 t.val
            + ((shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).bp).draws t.val + 1))).toK shdP_U := rfl
        have hD2rho : D2r.ρ t = vecK shdP_U ((shdP_L2Spec ⟨27, by decide⟩).n t + 1)
            ((List.range (slotN ((shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).bp) t.val)).map
              (fun r => challengeFp2Of (vf (outcSlBase + slotsFixedLen ((shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).bp) 0 t.val
                + ((shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).bp).draws t.val + 3 + 2 * r + 1)))) := rfl
        have hvec' : D2r.ρ t = fun j : Fin ((shdP_L2Spec ⟨27, by decide⟩).n t + 1) =>
            (challengeFp2Of (vf (bj27 + P27.draws t.val + 3 + 2 * j.val + 1))).toK shdP_U := by
          rw [hD2rho, hnd.1]; exact vecK_range_eq _ _ _
        have hD2f : D2r.f y c.1 t = fun x =>
            slotPolyK P27 (fun _ => 14) cs27 t.val (FRef.outcT.dfs t)
              (fun i => x (i.cast hnd.1)) := rfl
        rw [hvec', hD2f]
        rw [hD2c] at hsc ⊢
        dsimp only [bj27, P27, outcSlBase, cs27, TB26, w27] at hsc ⊢
        exact hsc
      have htmEq : (Fy.outcT.sps[t.val]'(by rw [Fy.outcT.sps_len]; exact t.isLt)).terms = tms27 := by
        rw [hspY.2.2.2.2.2.2.2.1]
        dsimp only [shdP_outcSlotData, polySlotData, OutcV.bga, Exec.Block.histOf, tms27, rhoFull27, bj27, n27, P27]
        rw [hvY, hchEq, hdfEq,
          show outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 = outcSlBase from rfl]
        have hCs : outcCs (shdP_outcTA Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c))
            (shdP_outcTH Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero))
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩)
          = outcCs (shdP_outcTA Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf (cOfL1 c.1)))
            (shdP_outcTH Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf (cOfL1 c.1)) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero))
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf (cOfL1 c.1)) (shdBlkRndOf (cOfL1 c.1)) y.1.1 y.1.2 ⟨26, by decide⟩) := by
          congr 1
        refine (congrArg (fun cs => stgPrivVals shdP_U shdP_hbij _ cs _ _ _) hCs).trans ?_
        exact stgPrivVals_eq_fromView _ _ _ _ _ _ fun p hp =>
          outcCs_eq_outcCsViewOf tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
            hne verdict vf FRef y c.1 t p hp
      exact slotProof_ext hscEq hrdEq htmEq
    · -- `mO` of OUT-C
      have hqEq := qPoly_eq_of_terms (shdP_outcM (shdOutcRndOf c)) 8
        (Fy.outcT.acc.fs ++ Fy.outcT.acc.hostFs) (FRef.outcT.acc.fs ++ FRef.outcT.acc.hostFs)
        hOutInv.2.2.2.2.2 ((challengeFp2Of (vf outcMoBase)).toK shdP_U)
      have hm := segMOpen_of_mOpenView ⟨27, by decide⟩ (c.2 ⟨27, by decide⟩)
        (FRef.outcT.acc.fs ++ FRef.outcT.acc.hostFs) (challengeFp2Of (vf outcMoBase))
        ((List.range (2 * 8 + 2)).map fun j => challengeFp2Of (vf (outcMoBase + 2 + j)))
        (idxsOf 12 vf (outcMoBase + 21)) (idxsOf_lt 12 vf _)
        (levelsOfV vf 12 (outcBase + 2 + 32767 + 3))
      refine (Fy.outcT.mO_eq.trans ?_).trans
        (hm.trans (congrArg₂ (segMOpenRecon ⟨27, by decide⟩ (idxsOf 12 vf (outcMoBase + 21)) (idxsOf_lt 12 vf _)
          (levelsOfV vf 12 (outcBase + 2 + 32767 + 3))) ?_ hVD2_27_snd.symm))
      · have hOff : outcMoBase + 2 + (2 * 8 + 2) + 1 = outcMoBase + 21 := by omega
        rw [show outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 + 290 = outcMoBase from rfl, hqEq, hOff, idxsOf_mDom]; rfl
      · exact (shdSegL2Data_mOpen_eq D2r y c.1 (c.2 ⟨27, by decide⟩) rfl rfl).trans hVD2_27_mO.symm
    · -- `aO` of OUT-C
      have ha := stdOpen_of_view 12 2 16 29 (by norm_num) shdP_stgPrm rfl rfl rfl
        (idxsOf 14 vf (outcAoBase + 122)) (idxsOf_length 14 vf _) (idxsOf_lt 14 vf _)
        Fy.outcT.acc.claims.a FRef.outcT.acc.claims.a hOutInv.2.2.1 FRef.outcT.haudA
        ((List.range 29).map fun j => challengeFp2Of (vf (outcAoBase + j)))
        ((List.range 76).map fun j => challengeFp2Of (vf (outcAoBase + 29 + j)))
        (by rw [FRef.outcT.hSumA]; simp) (by simp) FRef.outcT.hDetA
        (fun y' : AdmAt Rp verdict => outcADat Rp houtPub y'.1) y
        ((c.1.2.2 ⟨27, by decide⟩).1.1, (c.1.2.2 ⟨27, by decide⟩).2.1)
        (shdP_outcTA Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c))
        (shdP_outcTA_rows_len _ _ _) (shdP_outcTA_rows_eq Rp houtPub y.1 c)
        (shdP_outcTA_colsHonest _ _ _) (shdP_outcTA_cols_canon _ _ _) (shdP_outcTA_salts_eq Rp houtPub y.1 c)
        (levelsOfV vf 14 (outcBase + 2))
      refine (Fy.outcT.aO_eq.trans ?_).trans
        (ha.trans (congrArg (stdOpenRecon 12 2 16 29 (idxsOf 14 vf (outcAoBase + 122)) (idxsOf_lt 14 vf _)
          FRef.outcT.acc.claims.a FRef.outcT.haudA
          ((List.range 29).map fun j => challengeFp2Of (vf (outcAoBase + j)))
          (levelsOfV vf 14 (outcBase + 2))) ?_))
      · have hOff : outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 + 290 + 85 + 29 + 76 + 16 + 1 = outcAoBase + 122 := by
          unfold outcAoBase outcMoBase outcSlBase; omega
        rw [hOff, idxsOf_stgPrm]; rfl
      · refine Eq.trans ?_ (congrArg (fun v : PcsAHView GF shdP_K ⟨shdP_outcASpec, shdP_outcHSpec⟩ _ _ => (v.1.1, v.2.1)) hVout.symm)
        unfold shdP_D1_ah_outc
        exact pcsAHData_of_audit_view_A'.symm
    · -- `hO` of OUT-C
      have hh := hOpen_of_view 12 2 16 9 (by norm_num) shdP_stgPrm rfl rfl rfl
        (idxsOf 14 vf (outcHoBase + 54)) (idxsOf_lt 14 vf _)
        (Fy.outcT.acc.claims.h ++ [(shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).lay.logupSumClaim])
        (FRef.outcT.acc.claims.h ++ [(shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).lay.logupSumClaim])
        (by rw [List.map_append, List.map_append, hOutInv.2.2.2.1])
        FRef.outcT.hLenH FRef.outcT.haudH
        ((List.range 10).map fun j => challengeFp2Of (vf (outcHoBase + j)))
        ((List.range 38).map fun j => challengeFp2Of (vf (outcHoBase + 10 + j)))
        (by rw [FRef.outcT.hSumH]; simp) (by simp)
        (outcHDat Rp houtPub (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero) y.1)
        (c.1.2.2 ⟨27, by decide⟩).1.2 (c.1.2.2 ⟨27, by decide⟩).2.2
        (shdP_outcTH Rp (outcWitness_of_adm Rp houtPub y.1.1 y.1.2) (shdOutcRndOf c) (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero))
        (shdP_outcTH_rows_len _ _ _ _ _)
        (shdP_outcTH_rows_eq Rp houtPub (FRef.outcT.ch.getD 0 Fp2.zero) (FRef.outcT.ch.getD 1 Fp2.zero) y.1 c)
        (shdP_outcTH_colsHonest _ _ _ _ _) (shdP_outcTH_cols_canon _ _ _ _ _)
        (shdP_outcTH_salts_eq Rp houtPub y.1 c _ _)
        (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2))
      refine (Fy.outcT.hO_eq.trans ?_).trans
        (hh.trans (congrArg₂ (hOpenRecon 12 2 16 9 (idxsOf 14 vf (outcHoBase + 54)) (idxsOf_lt 14 vf _)
          (FRef.outcT.acc.claims.h ++ [(shdVo tag Rp wDigest bOutRow ((classifySpecP Rp (refInput Rp hne verdict).1).getD 0)).lay.logupSumClaim])
          FRef.outcT.hLenH FRef.outcT.haudH
          ((List.range 10).map fun j => challengeFp2Of (vf (outcHoBase + j)))
          (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2))) ?_ ?_))
      · have hOff : outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 + 290 + 85 + 186 + 10 + 38 + 5 + 1 = outcHoBase + 54 := by
          unfold outcHoBase outcAoBase outcMoBase outcSlBase; omega
        rw [hOutInv.1, hVerdRef.symm, hOff, idxsOf_stgPrm]; rfl
      · refine Eq.trans ?_ (congrArg (fun v : PcsAHView GF shdP_K ⟨shdP_outcASpec, shdP_outcHSpec⟩ _ _ => v.1.2) hVout.symm)
        symm
        unfold shdP_D1_ah_outc
        dsimp only
        exact pcsAHData_of_audit_view_H'
      · refine Eq.trans ?_ (congrArg (fun v : PcsAHView GF shdP_K ⟨shdP_outcASpec, shdP_outcHSpec⟩ _ _ => v.2.2) hVout.symm)
        rfl
  · -- `bO` of OUT-C (boundary `26`)
    have hspecB := shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩
    have hb := stdOpen_of_view 14 2 32 2 (by norm_num) Exec.R13.r13Prm rfl rfl rfl
      (idxsOf 16 vf (outcBoBase + 43)) (idxsOf_length 16 vf _) (idxsOf_lt 16 vf _)
      ((Fy.crAt ⟨26, by decide⟩).pending ++ Fy.outcT.acc.claims.inp)
      ((FRef.crAt ⟨26, by decide⟩).pending ++ FRef.outcT.acc.claims.inp)
      (by rw [List.map_append, List.map_append, hCrInv26, hOutInv.2.2.2.2.1])
      FRef.outcT.haudB
      ((List.range 2).map fun j => challengeFp2Of (vf (outcBoBase + j)))
      ((List.range 38).map fun j => challengeFp2Of (vf (outcBoBase + 2 + j)))
      (by rw [FRef.outcT.hSumB]; simp) (by simp) FRef.outcT.hDetB
      (fun y' : AdmAt Rp verdict => bndDatAt Rp hR hweights hinPub ⟨26, by decide⟩ y'.1)
      y (c.1.2.1 ⟨26, by decide⟩)
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) y.1.1 y.1.2 ⟨26, by decide⟩)
      hspecB.rows_len (shdP_bndTableAt_rows_eq Rp hR hweights hinPub y.1 c ⟨26, by decide⟩)
      hspecB.cols_honest hspecB.cols_canon (shdP_bndTableAt_salts_eq Rp hR hweights hinPub y.1 c ⟨26, by decide⟩)
      (levelsOfV vf 16 (shdTreeBase (.bnd ⟨26, by decide⟩)))
    have hksB : (shdP_ks vf).bnd ⟨26, by decide⟩ = (nodupCols (idxsOf 16 vf (outcBoBase + 43))).length := by
      unfold shdP_ks; dsimp only; exact dite_eq_right (by decide : ¬ (26 < 26))
    have hVbnd := shdP_D1_view_bnd_outc tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef y c hksB
    refine (Fy.outcT.bO_eq.trans ?_).trans
      (hb.trans (congrArg (stdOpenRecon 14 2 32 2 (idxsOf 16 vf (outcBoBase + 43)) (idxsOf_lt 16 vf _)
        ((FRef.crAt ⟨26, by decide⟩).pending ++ FRef.outcT.acc.claims.inp) FRef.outcT.haudB
        ((List.range 2).map fun j => challengeFp2Of (vf (outcBoBase + j)))
        (levelsOfV vf 16 (shdTreeBase (.bnd ⟨26, by decide⟩)))) hVbnd.symm))
    have hOff : outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 + 290 + 85 + 186 + 118 + 2 + 38 + 2 + 1 = outcBoBase + 43 := by
      unfold outcBoBase outcHoBase outcAoBase outcMoBase outcSlBase; omega
    rw [hOff, idxsOf_r13Prm]; rfl

/-- **Exact byte-level receipt equality `shdP_hout_of_traces`** at any active `(y, c)` and `vf`! -/
theorem shdP_hout_of_traces {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (refused : ClsStmt Hdr) (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (hne : Nonempty {x // (classifyModelP Rp).admissible x}) (verdict : ℕ)
    (y : AdmAt Rp verdict) (c : ShdCoins) (v : Fin shdP_zkResPts → Dig)
    (FRef : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      (refInput Rp hne verdict) default (shdExtV v))
    (Fy : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
      y.1 c (shdExtV v)) :
    let vf := shdExtV v
    let D1 := shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
    let D2 := shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict vf FRef
    PProg.outOf (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig y.1 c) v
      = shdP_Rc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hdr hne verdict vf FRef
          (D1.view y c.1, fun s => (D2 s).view y c.1 (c.2 s)) := by
  intro vf D1 D2
  have hVerdRef : (classifySpecP Rp (refInput Rp hne verdict).1).getD 0 = (classifySpecP Rp y.1.1).getD 0 :=
    refInput_verdict_eq Rp hne verdict y
  have hInv := fullRunTrace_invar tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
    y.1 (refInput Rp hne verdict) hVerdRef.symm c default vf Fy FRef
  obtain ⟨hIncInv, hCrInv, hBlkInv, hOutInv⟩ := hInv
  rw [Fy.outOf_eq hL20 key hw hdr hfit refused blkDig v rfl]
  unfold shdP_Rc
  refine Prod.ext (by rw [y.2]) ?_
  refine congrArg₂ List.cons
    (shdP_hout_inc_eq tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict y c vf FRef Fy hIncInv)
    (congrArg₂ List.append
      (List.ext_getElem (by simp) fun ki hki1 hki2 => by
        simp only [List.getElem_ofFn]
        let k : Fin 26 := ⟨ki, by simpa using hki1⟩
        exact shdP_hout_blk_eq tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict y c vf FRef Fy k (hCrInv ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩) (hBlkInv k))
      (congrArg (fun b => [b])
        (shdP_hout_outc_eq tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          hne verdict y c vf FRef Fy hVerdRef (hCrInv ⟨26, by decide⟩) hOutInv)))

end Level1AndLevel2Inst

/-! ## 4. Master `shdP_zkProgWitness` & Complete Concrete-Hook `ProductionReadyL` -/

section MasterWitnessAndProductionReadyL

open Classical in
/-- **MASTER `ShdZKProgWitness` FOR `shdP_honestRunP_zk` (`shdP_zkProgWitness`)**:
extends `shdP_zkCountWitness` with `π := id`, `hπ := shdCoins_hpi`, the concrete 84-PCS Level-1
view decomposition (`shdP_D1`), the 28-segment Level-2 conditional decomposition (`shdP_D2`),
and exact byte-level receipt reconstruction (`shdP_Rc`, `shdP_hout`)! -/
noncomputable def shdP_zkProgWitness {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (hsep : KeySep tag key)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheckV : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (refused : ClsStmt Hdr) (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (hdig : ∀ r v (k : Fin 26), digest (honestStmt hdr r v) k.val = blkDig k) :
    ShdZKProgWitness Rp Lq hL20 tag key shdP_runDomain (hw hdr).shape
      (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp) check0 paths digest bndCheckV)
      (shdP_honestRunP_zk tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut
        (checkField shdP_blkOpenGeom) embDigest bInRow wDigest bOutRow check0 digest
        shdEpBase shdIncRndOf shdBlkRndOf shdOutcRndOf)
      (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag shdEpBase).base :=
  let Wc := shdP_zkCountWitness Lq hL20 tag key hsep Rp hR hV131072 hweights hinPub houtPub
    hw preA preB check0 paths digest bndCheckV hdr hfit refused ioIn ioOut embDigest bInRow
    wDigest bOutRow blkDig hdig
  if hne : Nonempty {x // (classifyModelP Rp).admissible x} then
    let mkFRef : (verdict : ℕ) → (v : Fin shdP_zkResPts → Dig) → ¬ Wc.visSpec.G v →
        FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow
          (refInput Rp hne verdict) default (shdExtV v) := fun verdict v hg => by
      have hGeq : Wc.visSpec.G v = shdRunRefused (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub
          ioIn ioOut embDigest bInRow wDigest bOutRow blkDig v := by
        unfold Wc shdP_zkCountWitness; rw [dite_eq_left hne]; rfl
      rw [hGeq] at hg
      exact fullRunTrace_of_active Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow
        wDigest bOutRow blkDig (refInput Rp hne verdict) default v hg
    { toShdZKCountWitness := Wc
      π := id
      hπ := shdCoins_hpi
      ks := fun _ v _ => shdP_ks (shdExtV v)
      qs := fun _ v _ => shdP_qs (shdExtV v)
      hc := fun verdict v hg =>
        shdP_hc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict (shdExtV v) (mkFRef verdict v hg)
      D1 := fun verdict v hg =>
        shdP_D1 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict (shdExtV v) (mkFRef verdict v hg)
      D2 := fun verdict v hg s =>
        shdP_D2 tag Rp hR hV131072 hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hne verdict (shdExtV v) (mkFRef verdict v hg) s
      Rc := fun verdict v hg vw =>
        shdP_Rc tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow hdr hne verdict (shdExtV v) (mkFRef verdict v hg) vw
      hout := fun verdict y c v hg => by
        have hProgEq : Wc.prog = shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
            ioIn ioOut embDigest bInRow wDigest bOutRow blkDig := by
          unfold Wc shdP_zkCountWitness; rw [dite_eq_left hne]; rfl
        have hGeq : Wc.visSpec.G v = shdRunRefused (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub
            ioIn ioOut embDigest bInRow wDigest bOutRow blkDig v := by
          unfold Wc shdP_zkCountWitness; rw [dite_eq_left hne]; rfl
        rw [hProgEq]
        have hg' : ¬ shdRunRefused (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub
            ioIn ioOut embDigest bInRow wDigest bOutRow blkDig v := hGeq ▸ hg
        let Fy := fullRunTrace_of_active Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow
          wDigest bOutRow blkDig y.1 c v hg'
        exact shdP_hout_of_traces Lq hL20 tag key Rp hR hV131072 hweights hinPub houtPub hw hdr hfit refused
          ioIn ioOut embDigest bInRow wDigest bOutRow blkDig hne verdict y c v (mkFRef verdict v hg) Fy }
  else
    have hnotG : ∀ v, ¬ Wc.visSpec.G v → False := fun v hg => by
      have hG : Wc.visSpec.G v = True := by
        unfold Wc shdP_zkCountWitness; rw [dite_eq_right hne]
      exact hg (hG ▸ trivial)
    { toShdZKCountWitness := Wc
      π := id
      hπ := shdCoins_hpi
      ks := fun _ v hg => absurd hg (hnotG v)
      qs := fun _ v hg => absurd hg (hnotG v)
      hc := fun _ v hg => absurd hg (hnotG v)
      D1 := fun _ v hg => absurd hg (hnotG v)
      D2 := fun _ v hg _ => absurd hg (hnotG v)
      Rc := fun _ v hg _ => absurd hg (hnotG v)
      hout := fun _ _ _ v hg => absurd hg (hnotG v) }

/-- **COMPLETE UNCONDITIONAL CONCRETE-HOOK `ProductionReadyL` THEOREM FOR SHIELDSTRAL T128 R13
(`shdP_honest_productionReadyL_complete`)**:
assembles `shdP_honest_productionReadyL_hooks_zk` with `shdP_zkProgWitness` over `ShdCoins`
and concrete verifier hooks (`shdPreA`, `shdPreB`, `shdCheck0`, `shdDigest`, `ShieldRunReg`),
closing ALL completeness, soundness, binding, refusal-cover, concrete-hook, and zero-knowledge
obligations at `(εcTarget, εsTarget, εsTarget, εzkTarget)` with ZERO open `W_zk` or hook premises! -/
theorem shdP_honest_productionReadyL_complete
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (key : Option Dig) (hsep : KeySep tag key)
    (policy : ShdPolicy) (reg : ShdRegTables) (regBlkDig : Fin 26 → Dig)
    (w : ClsHdrW) (hwFit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (wholeRunBits : ℕ) (hfloor : policy.minWholeRunBits ≤ wholeRunBits)
    (Rp : ClassifyRunPublicP shieldS0) (hReg : ShieldRunReg Rp)
    (refused : ClsStmt (ShdHdr Lq))
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
      (classifyProtocolUExecP Rp Lq 26 (shdPreA policy reg) (shdPreB regBlkDig)
        (clsStart shdP_runDomain key shdHdrW)
        (fun _ => shdP_incV tag Rp reg.embDigest (embFoldL Rp.inp) 32)
        (fun _ => rcIncGeom (shdP_incV tag Rp reg.embDigest (embFoldL Rp.inp) 32) 28)
        (d12aBlockProf (shdP_Pk0 tag 34 32 (checkField shdP_blkOpenGeom) Rp)
          (shdP_sgeom (ShdHdr Lq) (shdP_Pk0 tag 34 32 (checkField shdP_blkOpenGeom) Rp))
          (vdChk (shdCheck0 regBlkDig)) shdP_segPaths shdDigest (fun _ => 38) (fun _ => 14)
          (fun _ _ cl _ => shdP_bndCheckPure cl) (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp reg.wDigest 34 v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp reg.wDigest 34 0) 28)
        (shdP_honestRunP_zk tag Rp hReg.1 hweights hinPub houtPub
          (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) refused 34 32
          (checkField shdP_blkOpenGeom) reg.embDigest 32 reg.wDigest 34
          (shdCheck0 regBlkDig) shdDigest
          shdEpBase shdIncRndOf shdBlkRndOf shdOutcRndOf)
        (shdP_cin (ShdHdr Lq) tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := ShdHdr Lq) tag shdEpBase).base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  shdP_honest_productionReadyL_hooks_zk tag Lq hL20 hL64 key policy reg regBlkDig w hwFit
    wholeRunBits hfloor Rp hReg refused hweights hinPub houtPub
    shdEpBase shdIncRndOf shdBlkRndOf shdOutcRndOf
    (shdP_zkProgWitness Lq hL20 tag key hsep Rp hReg.1 hReg.2 hweights hinPub houtPub
      shdHdrW (shdPreA policy reg) (shdPreB regBlkDig) (shdCheck0 regBlkDig) shdP_segPaths
      shdDigest (fun _ _ cl _ => shdP_bndCheckPure cl)
      (shdHonestHdr reg regBlkDig w hwFit wholeRunBits) hwFit refused 34 32
      reg.embDigest 32 reg.wDigest 34 regBlkDig
      (fun r v k => (shdDigest_honest reg regBlkDig w hwFit wholeRunBits r v k.val k.isLt).trans
        (by unfold shdBlkDigFn; exact dite_eq_left k.isLt)))

end MasterWitnessAndProductionReadyL

end ZK60.HonestShield
