/-
D63 lane L68c, final top-level assembly (`HonestShieldTop.lean`):
wires all five honest-prover pillars (`hsegIn`, `hsegBlk`, `hsegOut`, `O.refuse`, `O.zk`) for one
unified concrete honest Shieldstral T128 R13 prover (`shdP_honestRunP`) directly onto L63's
generic-ZK top theorem `RunStgShieldClTopEF.sshC_productionReadyL_epP_blkEF_zg` (ruling `L63-15`)
at `εzk := shdRunErrRes` (`shdRunErrRes_hzk`), staying purely in the ideal-coin Random Oracle Model
(keeping `NativeOsRngIndist` outside all top theorems here; it remains solely in `HonestShieldZK.lean`
as an optional bridge pending explicit ruling).

### Scope & Honesty Notes
1. **Model-to-code boundary**: The Lean prover tables (`shdP_incTables`, `shdP_blkTables`,
   `shdP_outcTables`, `shdP_bndTableAt`) and segment provers (`shdP_honestRunP`) formalize a
   mathematical model of the Rust prover (`stage_in_c`, `protocol`, `stage_out_c`, `classify_run`)
   rather than formally verifying Rust code extraction; correspondence between the Rust binary and
   this Lean model sits outside the Lean kernel.
2. **Remaining open ZK witness premise**: Every completeness, refusal-cover, site-count, commitment,
   width, shape, and block-count field of `ClassifyOpenP` is discharged in full for `shdP_honestRunP`,
   and the numeric ZK budget bound `shdRunErrRes q R' ≤ εzkTarget q R'` (`q, R' ≤ 2^64`) is proved
   by `shdRunErrRes_hzk`. The single remaining structured ZK premise on the top theorems is
   `W_zk : ShdZKProgWitness` until the 28-segment `PProg` instantiation for `shdP_honestRunP` is closed.
3. **Foundations**: Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`);
   every proof is complete.

### Main Declarations
1. **Helper bridges**:
   - `blkAlphaBad_true_implies_blkAlphaBadP`
   - `shdP_blk_outClaims_true_uncond`
   - `shdP_bndCheckPure_err_implies_checkOpeningExec`
2. **Unified concrete honest prover**:
   - `shdP_bndTableLast_total`
   - `shdP_honestRunP`
3. **Per-segment & whole-run completeness (`O.parts`)**:
   - `shdP_honestRun_hsegIn`, `shdP_honestRun_hsegBlk`, `shdP_honestRun_hsegOut`, `shdP_honestRun_parts`
4. **Whole-run witness, guarded prover match, & refusal cover (`O.refuse`)**:
   - `shdP_honestRunWitness` (+ projection equations `shdP_honestRunWitness_TB`, `_TB0`, `_incTables`,
     `_blkTables`, `_blkTables_total`, `_outcTables`)
   - `shdP_honestRun_proverMatch`, `shdP_honestRun_hcover`
5. **Top-level `ProductionReadyL` assembly (pure ROM, `εzk := shdRunErrRes`)**:
   - `shdP_openShell_res`
   - `shdP_honest_classifyOpenP`
   - `shdP_honest_productionReadyL`
   - `shdP_honest_productionReadyL_okPre`
   - `shdP_honest_productionReadyL_concrete`
-/
import ZK60Formal.HonestShieldStageInArith
import ZK60Formal.HonestShieldStageOutArith
import ZK60Formal.HonestShieldBlockArith
import ZK60Formal.HonestShieldRunRefusal
import ZK60Formal.HonestShieldZK

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound ZK60.TokenRun
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP classifyArithP)
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldExport_l17 shieldCal shieldS0 shieldShape
  shield_layers_ok ShieldRun)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Hist Acc SlotDef SlotProof SlotRec Segment)
open ZK60.Exec.Block.Join.W16.Tab (tabTupE foldWd toK_foldWd)
open ZK60.Exec.Block.Join.R13H.Look (TbIx TR13)

/-! ## 1. Helper Bridges (`blkAlphaBad → blkAlphaBadP`, Unconditional Block Outgoing Claims, Concrete Checks) -/

section HelperBridges

private theorem except_cases {ε α : Type} (x : Except ε α) :
    (∃ e, x = .error e) ∨ (∃ a, x = .ok a) := by
  cases x with
  | error e => exact Or.inl ⟨e, rfl⟩
  | ok a => exact Or.inr ⟨a, rfl⟩

/-- Whenever the computable pole guard `blkAlphaBad Ly Pb (b, g, a)` returns `true` on a registered
Shieldstral layer with canonical `a`, the propositional refusal event `blkAlphaBadP Ly Pb b g a` holds. -/
theorem blkAlphaBad_true_implies_blkAlphaBadP (Ly : ShieldLayer) (hLy : Ly ∈ shieldExport)
    (Pb : BlockPublic (shieldShape Ly)) (b g a : Fp2) (ha : a.Canon)
    (hbad : blkAlphaBad Ly Pb (b, g, a) = true) :
    blkAlphaBadP Ly Pb b g a := by
  unfold blkAlphaBad at hbad
  obtain ⟨k, hkMem, hinner⟩ := List.any_eq_true.mp hbad
  have hk : k < 3 := List.mem_range.mp hkMem
  obtain ⟨i, hiMem, hzero⟩ := List.any_eq_true.mp hinner
  have hi : i < blkTabActiveLen Ly.nG k := List.mem_range.mp hiMem
  obtain ⟨-, -, -, -, -, -, -, -, -, -, hnG, -⟩ := shield_layers_ok Ly hLy
  have hi14 : i < 2 ^ 14 := by
    unfold blkTabActiveLen at hi
    by_cases hk2 : k < 2
    · rw [ite_eq_left hk2] at hi; omega
    · rw [ite_eq_right hk2] at hi; omega
  have hcanF : (foldWd b g (tabTupE Pb.exp Pb.act Ly.nG k i)).Canon := Fp2.canon_add _ _
  have hsub0 : (a.sub (foldWd b g (tabTupE Pb.exp Pb.act Ly.nG k i))).toK shdP_U = 0 :=
    (isZero_iff_toK shdP_U shdP_hU _ (Fp2.canon_sub _ _ ha hcanF)).mp hzero
  rw [Fp2.toK_sub shdP_U _ _ ha hcanF, toK_foldWd shdP_U shdP_hU, sub_eq_zero] at hsub0
  refine ⟨(⟨k, hk⟩, msbBits 14 i), ?_⟩
  change a.toK shdP_U =
    fold (b.toK shdP_U) (g.toK shdP_U) (Exec.Block.tupK (tabTupE Pb.exp Pb.act Ly.nG k (msbIndex 14 (msbBits 14 i))))
  rw [msbIndex_msbBits 14 i hi14]
  exact hsub0

private theorem blk_slotProve_outClaims_true {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ}
    (H : HIn → Dig) (P : BlockParams) (w : BlkWitness Ly Pb xIn xOut)
    (TB_prev TB_next : Table) (hTB_next : TB_next.rows.length = 38) (rnd : BlkRand)
    (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (sp : SlotProof) (r : SlotRec) (acc' : Acc) (t' : Tr)
    (hacc : ∀ cl ∈ acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 TB_next.rows (toZClaim cl))
    (hsp : slotProve H P (blkSlotData P w (blkTA w rnd) TB_prev TB_next rnd) s hist acc t = .ok (sp, r, acc', t')) :
    ∀ cl ∈ acc'.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 TB_next.rows (toZClaim cl) := by
  let D := blkSlotData P w (blkTA w rnd) TB_prev TB_next rnd
  change slotProve H P D s hist acc t = .ok (sp, r, acc', t') at hsp
  unfold slotProve at hsp
  rcases except_cases (P.define s hist (t.challengeFp2Vec H (P.draws s)).1) with ⟨_, hdef⟩ | ⟨df, hdef⟩
  · rw [hdef] at hsp; dsimp only at hsp; cases hsp
  · rw [hdef] at hsp
    dsimp only at hsp
    by_cases hc : (slotC H P s t).isZero = true
    · rw [ite_eq_left hc] at hsp; cases hsp
    · rw [ite_eq_right hc] at hsp
      by_cases hes : ((slotRho H P D s hist acc t df).drop (Exec.Block.slotShape P s).1).any
          (fun x => x.isZero || decide (x = Fp2.one)) = true
      · rw [ite_eq_left hes] at hsp; cases hsp
      · rw [ite_eq_right hes] at hsp
        rcases except_cases (Exec.Block.slotDefChecks P s acc df) with ⟨_, hchk⟩ | ⟨_, hchk⟩
        · rw [hchk] at hsp; dsimp only at hsp; cases hsp
        · rw [hchk] at hsp
          dsimp only at hsp
          rcases except_cases (Exec.Block.hostedSum acc.scalars (slotSP H P D s hist acc t df).scalar df.hosted) with
            ⟨_, hhost⟩ | ⟨claimed, hhost⟩
          · rw [hhost] at hsp; dsimp only at hsp; cases hsp
          · rw [hhost] at hsp
            dsimp only at hsp
            rcases except_cases (Exec.Block.tabVals
                (Exec.Block.oneMinusProd ((slotRho H P D s hist acc t df).drop (Exec.Block.slotShape P s).1))
                ((slotRho H P D s hist acc t df).take (Exec.Block.slotShape P s).1)
                (slotSP H P D s hist acc t df).terms df.tabs 0) with ⟨_, htab⟩ | ⟨vals, htab⟩
            · rw [htab] at hsp; dsimp only at hsp; cases hsp
            · rw [htab] at hsp
              dsimp only at hsp
              simp only [Except.ok.injEq, Prod.mk.injEq] at hsp
              obtain ⟨-, -, rfl, -⟩ := hsp
              let Q : Cm → Exec.Block.ZClaim → Prop :=
                fun cm cl => cm = .out → ClaimTrue shdP_U (2 ^ 14) 14 TB_next.rows (toZClaim cl)
              have hcl := slotClaims_claimTrue P
                (blkCs (blkTA w rnd) (blkTH w rnd (hist.beta, hist.gamma, hist.alpha)) TB_prev TB_next)
                ((slotRho H P D s hist acc t df).take (Exec.Block.slotShape P s).1)
                ((slotRho H P D s hist acc t df).drop (Exec.Block.slotShape P s).1)
                df.tabs acc.claims Q
                (fun cm ps v hv hcm => by
                  subst hcm
                  exact (claimTrue_iff_claimSem shdP_U 38 14 TB_next.rows hTB_next ⟨ps, v⟩).mpr hv)
                ⟨(fun _ _ h => by cases h), (fun _ _ h => by cases h), (fun _ _ h => by cases h),
                  fun cl hmem _ => hacc cl hmem⟩
              intro cl hmem
              exact hcl.2.2.2 cl hmem rfl

private theorem blk_slotsProve_outClaims_true {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ}
    (H : HIn → Dig) (P : BlockParams) (w : BlkWitness Ly Pb xIn xOut)
    (TB_prev TB_next : Table) (hTB_next : TB_next.rows.length = 38) (rnd : BlkRand)
    (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr)
      (sps : List SlotProof) (recs' : List SlotRec) (acc' : Acc) (t' : Tr),
      (∀ cl ∈ acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 TB_next.rows (toZClaim cl)) →
      slotsProve H P (blkSlotData P w (blkTA w rnd) TB_prev TB_next rnd) b g a m recs s acc t
        = .ok (sps, recs', acc', t') →
      ∀ cl ∈ acc'.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 TB_next.rows (toZClaim cl)
  | 0, _, _, _, _, _, _, _, _, hacc, h => by
    simp only [slotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, -, rfl, -⟩ := h
    exact hacc
  | m + 1, recs, s, acc, t, sps, recs', acc', t', hacc, h => by
    simp only [slotsProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨-, -, rfl, -⟩ := h
        exact blk_slotsProve_outClaims_true H P w TB_prev TB_next hTB_next rnd b g a m
          (recs ++ [r]) (s + 1) acc₁ t₁ sps₁ recs₁ acc₂ t₂
          (blk_slotProve_outClaims_true H P w TB_prev TB_next hTB_next rnd s
            (Exec.Block.histOf b g a recs) acc t sp r acc₁ t₁ hacc hsp)
          hrest

/-- **Unconditional outgoing boundary-claim truth for `coreProve`**: because `blkSlotData.terms`
always evaluates `stgPrivVals` against `blkCs`, every claim pushed into `R.acc.claims.out` satisfies
`ClaimTrue` on `TB_next.rows` whenever `coreProve = .ok R` (without needing `blkAlphaBad = false`
or `bndCheck = .ok ()`), discharging `hBlkOutTrue` of `shdP_refuse_hcover` directly. -/
theorem shdP_blk_outClaims_true_uncond {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ}
    (H : HIn → Dig) (tag : MTag) (P : BlockParams) (w : BlkWitness Ly Pb xIn xOut)
    (TB_prev TB_next : Table) (hTB_next : TB_next.rows.length = 38) (rnd : BlkRand)
    (tFrame : Tr) (R : CoreRun)
    (hR : coreProve H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P
      (blkCoreTables P w TB_prev TB_next rnd) tFrame) tFrame = .ok R) :
    ∀ cl ∈ R.acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 TB_next.rows (toZClaim cl) := by
  obtain ⟨hslots, -, -, -, -, -, -, -, -, -, -⟩ :=
    coreProve_ok H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P
      (blkCoreTables P w TB_prev TB_next rnd) tFrame) tFrame R hR
  exact blk_slotsProve_outClaims_true H P w TB_prev TB_next hTB_next rnd _ _ _
    P.geom.slots.length [] 0 {} _ R.core.slots R.recs R.acc R.t4
    (fun _ h => by cases h) hslots

/-- Whenever the pure boundary check `shdP_bndCheckPure` refuses, `checkOpeningExec` at
`shdP_bndOpenGeom` refuses on any oracle `H` and transcript `t` (discharging `hbnd` for `_okPre`). -/
theorem shdP_bndCheckPure_err_implies_checkOpeningExec (H : HIn → Dig)
    (cl : List Exec.Block.ZClaim) (t : Tr) (e : String)
    (herr : shdP_bndCheckPure cl = .error e) :
    ∃ e', checkOpeningExec H shdP_bndOpenGeom 14 cl t = .error e' := by
  unfold shdP_bndCheckPure at herr
  unfold checkOpeningExec shdP_bndOpenGeom
  dsimp only
  rcases except_cases (auditClaims cl (2 ^ 14) 38 [32, 33, 34, 35] none 36) with ⟨e1, ha⟩ | ⟨u, ha⟩
  · exact ⟨e1, by rw [ha]; rfl⟩
  · cases u
    simp only [ha, Bind.bind, Except.bind] at herr ⊢
    rcases except_cases (openingGroupsAt cl 14) with ⟨e2, hg⟩ | ⟨gs, hg⟩
    · exact ⟨e2, by rw [hg]⟩
    · simp only [hg] at herr ⊢
      by_cases hne : gs.length ≠ 2
      · rw [ite_eq_left hne]
        simp only [throw, throwThe, MonadExceptOf.throw]
        exact ⟨_, rfl⟩
      · rw [ite_eq_right hne] at herr
        simp only [pure, Except.pure] at herr
        cases herr

end HelperBridges

/-! ## 2. Unified Concrete Honest Prover (`shdP_honestRunP`) -/

section HonestRunProver

open Classical in
/-- Total wrapper returning Block 25's outgoing boundary table `TB_26` on admissible inputs
(with an empty fallback on inadmissible inputs), connecting Block 25 to Stage OUT-C. -/
noncomputable def shdP_bndTableLast_total {Hdr Coins : Type}
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand)
    (_H : HIn → Dig) (_s : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (c : Coins) : Table :=
  if hx : (classifyModelP Rp).admissible x then
    shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨26, by omega⟩
  else
    mkPcsTable 14 2 256 (by norm_num) [] (fun _ => zeroDig)

/-- **Unified concrete honest Shieldstral T128 R13 prover (`RunP`)**: wires Stage IN-C (`shdP_incP`),
all 26 `blkAlphaBad`-guarded R13 blocks (`shdP_blkSegP_run`, deriving `act0` from `hweights`),
and Stage OUT-C (`shdP_outcP` / `shdP_outcTables_total`) onto ONE shared boundary-table sequence
`TB_0, …, TB_26` (`shdP_bndTableAt`) and ONE coin decomposition `(epBase, incRndOf, blkRndOf, outcRndOf)`.
All five pillars (`hsegIn`, `hsegBlk`, `hsegOut`, `hcover`, `hzk`) speak about this exact `RunP`. -/
noncomputable def shdP_honestRunP {Hdr Coins : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hdr : Hdr) (refused : ClsStmt Hdr)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand) :
    RunP Hdr (shieldS0.Tok → ℕ) Coins where
  hdr := hdr
  inC := inSegP _ (shdP_incP tag Rp embDigest bInRow
    (fun H _ x c => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x (epBase c) (incRndOf c)))
  blk := shdP_blkSegP_run tag ioIn ioOut checkOpening Rp hR hweights hinPub
    (fun b hb => (hweights b hb).act0) check0 digest bndCheck incRndOf blkRndOf
  outC := outSegP _ (shdP_outcP tag Rp wDigest bOutRow
    (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
      (shdP_bndTableLast_total Rp hR hweights hinPub incRndOf blkRndOf) outcRndOf))
  refused := refused

end HonestRunProver

/-! ## 3. Per-Segment & Whole-Run Completeness (`O.parts`) for `shdP_honestRunP` -/

section HonestRunParts

/-- **Stage IN-C `SegComplete` (`hsegIn`)** for `shdP_honestRunP`. -/
theorem shdP_honestRun_hsegIn {Hdr Coins : Type}
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hdr : Hdr) (refused : ClsStmt Hdr)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand) :
    let P := shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf
    SegComplete (classifyModelP Rp).admissible liftH
      (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      P.inC
      (inSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck).inC) :=
  shdP_inc_segComplete_of_adm tag Lq hL20 Rp hinPub hV131072 embDigest bInRow epBase incRndOf
    (clsStmtOfP Rp Lq
      (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
      (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base)
    (fun _ _ _ _ => rfl)

/-- **26-Block `SegComplete` (`hsegBlk`)** for `shdP_honestRunP` (zero extra `hAct0` premise). -/
theorem shdP_honestRun_hsegBlk {Hdr Coins : Type}
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hdr : Hdr) (refused : ClsStmt Hdr)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (hCheck0 : ∀ k, k < 26 → ∀ G x c, (classifyModelP Rp).admissible x →
      check0 (clsStmtOfP Rp Lq
        (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
          embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
        (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base G x c) k = .ok ())
    (hgrpA : ∀ H cl t, checkOpening H .a cl t = .ok () → (groupZclaims (cl.map toZClaim) 4577 14).length = 36)
    (hgrpH : ∀ H cl t, checkOpening H .h cl t = .ok () → (groupZclaims (cl.map toZClaim) 4390 14).length = 9)
    (hgrpB : ∀ k, k < 26 → ∀ st cl t, bndCheck st k cl t = .ok () →
      (groupZclaims (cl.map toZClaim) 38 14).length = 2) :
    let P := shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf
    ∀ k, k < 26 →
      SegComplete (classifyModelP Rp).admissible liftH
        (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
          (shdP_honestIn (Hdr := Hdr) tag epBase).base)
        (P.blk k)
        (blockSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 shdP_segPaths digest bndCheck).blk k) :=
  shdP_blk_segComplete_runV_valid tag Lq hL20 key Rp hR hw preA preB check0 digest bndCheck
    ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow hweights hinPub houtPub
    incRndOf blkRndOf
    (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
    epBase (fun _ _ => rfl) hCheck0 hgrpA hgrpH hgrpB

/-- **Stage OUT-C `SegComplete` (`hsegOut`)** for `shdP_honestRunP`, connecting Block 25's outgoing
boundary table `shdP_bndTableAt ... ⟨26, _⟩` via `shdP_bndTableAt_last_outcSpec`. -/
theorem shdP_honestRun_hsegOut {Hdr Coins : Type}
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hdr : Hdr) (refused : ClsStmt Hdr)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand) :
    let P := shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf
    SegComplete (classifyModelP Rp).admissible liftH
      (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      P.outC
      (outSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck).outC) :=
  shdP_outc_segComplete_of_adm tag Lq Rp houtPub wDigest bOutRow
    (shdP_bndTableLast_total Rp hR hweights hinPub incRndOf blkRndOf)
    outcRndOf
    (clsStmtOfP Rp Lq
      (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
      (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base)
    (fun _ _ _ _ => rfl)
    (fun _ x c hx => by
      unfold shdP_bndTableLast_total
      rw [dite_eq_left hx]
      exact shdP_bndTableAt_last_outcSpec Rp hR hweights hinPub houtPub (incRndOf c) (blkRndOf c) x hx)

/-- **Whole-run `O.parts` discharge** for `shdP_honestRunP` across all 28 segments (`1` IN-C + `26` R13
blocks + `1` OUT-C) via `classifyP_parts_of_segs`. -/
theorem shdP_honestRun_parts {Hdr Coins : Type}
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hdr : Hdr) (refused : ClsStmt Hdr)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (hCheck0 : ∀ k, k < 26 → ∀ G x c, (classifyModelP Rp).admissible x →
      check0 (clsStmtOfP Rp Lq
        (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
          embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
        (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base G x c) k = .ok ())
    (hgrpA : ∀ H cl t, checkOpening H .a cl t = .ok () → (groupZclaims (cl.map toZClaim) 4577 14).length = 36)
    (hgrpH : ∀ H cl t, checkOpening H .h cl t = .ok () → (groupZclaims (cl.map toZClaim) 4390 14).length = 9)
    (hgrpB : ∀ k, k < 26 → ∀ st cl t, bndCheck st k cl t = .ok () →
      (groupZclaims (cl.map toZClaim) 38 14).length = 2) :
    let P := shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf
    List.Forall₂
      (SegComplete (classifyModelP Rp).admissible liftH
        (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
          (shdP_honestIn (Hdr := Hdr) tag epBase).base))
      (P.parts 26)
      (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 shdP_segPaths digest bndCheck).parts :=
  classifyP_parts_of_segs Rp Lq
    (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
      (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 shdP_segPaths digest bndCheck)
    (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
    (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
    (shdP_honestIn (Hdr := Hdr) tag epBase).base
    (shdP_honestRun_hsegIn tag Lq hL20 key Rp hR hw preA preB check0 shdP_segPaths digest bndCheck
      ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow hdr refused hV131072 hweights hinPub houtPub
      epBase incRndOf blkRndOf outcRndOf)
    (shdP_honestRun_hsegBlk tag Lq hL20 key Rp hR hw preA preB check0 digest bndCheck
      ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow hdr refused hweights hinPub houtPub
      epBase incRndOf blkRndOf outcRndOf hCheck0 hgrpA hgrpH hgrpB)
    (shdP_honestRun_hsegOut tag Lq hL20 key Rp hR hw preA preB check0 shdP_segPaths digest bndCheck
      ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow hdr refused hweights hinPub houtPub
      epBase incRndOf blkRndOf outcRndOf)

end HonestRunParts

/-! ## 4. Whole-Run Witness, Guarded Prover Match, & Refusal Cover (`O.refuse`) for `shdP_honestRunP` -/

section HonestRunRefusal

open Classical in
/-- **Oracle-independent honest 28-segment `ShdRunWitness`** constructed directly from
`(epBase, incRndOf, blkRndOf, outcRndOf)` for `shdP_honestRunP` (with empty fallbacks outside
admissible inputs / `k < 26`). -/
noncomputable def shdP_honestRunWitness {Hdr Coins : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (x : shieldS0.Tok → ℕ) :
    ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x :=
  if hx : (classifyModelP Rp).admissible x then
    { TB := fun k c =>
        if hk : k < 27 then
          shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, hk⟩
        else mkPcsTable 14 2 256 (by norm_num) [] (fun _ => zeroDig)
      hrB := fun k hk c => by
        rw [dite_eq_left (by omega : k < 27)]
        exact (shdP_bndTableAt_spec Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, by omega⟩).rows_len.le
      incTA := fun c => shdP_incTA x (incRndOf c)
      incM := fun c => shdP_incM (incRndOf c)
      incTH := fun c ch => shdP_incTH Rp embDigest x (incRndOf c) ch
      incSlot := fun c ch =>
        shdP_incSlotData tag Rp embDigest bInRow ch
          (shdP_incTA x (incRndOf c)) (shdP_incTH Rp embDigest x (incRndOf c) ch)
          (shdP_epTable (Hdr := Hdr) tag x (epBase c)) (shdP_incTB Rp x (incRndOf c)) (incRndOf c)
      hrIncA := fun c => (shdP_incTA_rows_len x (incRndOf c)).le
      hrIncH := fun c ch => (shdP_incTH_rows_len Rp embDigest x (incRndOf c) ch).le
      blkTA := fun k c =>
        if hk : k < 26 then
          blkTA (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k hk)
            (blkRndOf c ⟨k, hk⟩)
        else mkPcsTable 14 2 256 (by norm_num) [] (fun _ => zeroDig)
      blkM := fun k c =>
        if hk : k < 26 then blkTM (blkRndOf c ⟨k, hk⟩) else blkTM (blkRndOf c ⟨0, by norm_num⟩)
      blkTH := fun k c =>
        if hk : k < 26 then
          fun b g a =>
            blkTH (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k hk)
              (blkRndOf c ⟨k, hk⟩) (b, g, a)
        else fun _ _ _ => mkPcsTable 14 2 256 (by norm_num) [] (fun _ => zeroDig)
      blkSlot := fun k c =>
        if hk : k < 26 then
          blkSlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
            (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k hk)
            (blkTA (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k hk)
              (blkRndOf c ⟨k, hk⟩))
            (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, Nat.lt_succ_of_lt hk⟩)
            (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k + 1, Nat.succ_lt_succ hk⟩)
            (blkRndOf c ⟨k, hk⟩)
        else
          polySlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) shdP_U shdP_hbij
            (fun _ _ _ _ _ => Fp2.zero) (fun _ _ _ _ _ _ => 0) (fun _ _ _ _ _ _ => [])
      hrBlkA := fun k hk c => by
        rw [dite_eq_left hk]
        exact (blkTA_rows_len _ _).le
      hrBlkH := fun k hk c b g a => by
        rw [dite_eq_left hk]
        exact (blkTH_rows_len _ _ _).le
      outcTA := fun c => shdP_outcTA Rp (outcWitness_of_adm Rp houtPub x hx) (outcRndOf c)
      outcM := fun c => shdP_outcM (outcRndOf c)
      outcTH := fun c ch =>
        shdP_outcTH Rp (outcWitness_of_adm Rp houtPub x hx) (outcRndOf c) (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero)
      outcSlot := fun c =>
        shdP_outcSlotData tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0) (outcWitness_of_adm Rp houtPub x hx)
          (shdP_outcTA Rp (outcWitness_of_adm Rp houtPub x hx) (outcRndOf c))
          (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨26, by omega⟩)
          (outcRndOf c)
      hrOutcA := fun c => (shdP_outcTA_rows_len Rp (outcWitness_of_adm Rp houtPub x hx) (outcRndOf c)).le
      hrOutcH := fun c ch => (shdP_outcTH_rows_len Rp (outcWitness_of_adm Rp houtPub x hx) (outcRndOf c) _ _).le }
  else
    { TB := fun _ _ => mkPcsTable 14 2 256 (by norm_num) [] (fun _ => zeroDig)
      hrB := fun _ _ _ => Nat.zero_le 38
      incTA := fun _ => mkPcsTable 12 2 256 (by norm_num) [] (fun _ => zeroDig)
      incM := fun c => shdP_incM (incRndOf c)
      incTH := fun _ _ => mkPcsTable 12 2 256 (by norm_num) [] (fun _ => zeroDig)
      incSlot := fun _ ch =>
        polySlotData ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub ch))
          shdP_U shdP_hbij (fun _ _ _ _ _ => Fp2.zero) (fun _ _ _ _ _ _ => 0) (fun _ _ _ _ _ _ => [])
      hrIncA := fun _ => Nat.zero_le 41
      hrIncH := fun _ _ => Nat.zero_le 76
      blkTA := fun _ _ => mkPcsTable 14 2 256 (by norm_num) [] (fun _ => zeroDig)
      blkM := fun _ c => blkTM (blkRndOf c ⟨0, by norm_num⟩)
      blkTH := fun _ _ _ _ _ => mkPcsTable 14 2 256 (by norm_num) [] (fun _ => zeroDig)
      blkSlot := fun k _ =>
        polySlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) shdP_U shdP_hbij
          (fun _ _ _ _ _ => Fp2.zero) (fun _ _ _ _ _ _ => 0) (fun _ _ _ _ _ _ => [])
      hrBlkA := fun _ _ _ => Nat.zero_le 4577
      hrBlkH := fun _ _ _ _ _ _ => Nat.zero_le 4390
      outcTA := fun _ => mkPcsTable 12 2 256 (by norm_num) [] (fun _ => zeroDig)
      outcM := fun c => shdP_outcM (outcRndOf c)
      outcTH := fun _ _ => mkPcsTable 12 2 256 (by norm_num) [] (fun _ => zeroDig)
      outcSlot := fun _ =>
        polySlotData (shdVo tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0)).bp
          shdP_U shdP_hbij (fun _ _ _ _ _ => Fp2.zero) (fun _ _ _ _ _ _ => 0) (fun _ _ _ _ _ _ => [])
      hrOutcA := fun _ => Nat.zero_le 76
      hrOutcH := fun _ _ => Nat.zero_le 38 }

open Classical in
theorem shdP_honestRunWitness_TB {Hdr Coins : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : Coins) (k : ℕ) (hk : k < 27) :
    (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x).TB k c
      = shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, hk⟩ := by
  unfold shdP_honestRunWitness
  rw [dite_eq_left hx]
  dsimp only
  exact dite_eq_left hk

theorem shdP_honestRunWitness_TB0 {Hdr Coins : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : Coins) :
    (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x).TB 0 c
      = shdP_incTB Rp x (incRndOf c) :=
  shdP_honestRunWitness_TB (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
    embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x hx c 0 (by omega)

open Classical in
theorem shdP_honestRunWitness_incTables {Hdr Coins : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (H : HIn → Dig) (c : Coins) :
    (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x).incTables H c
      = shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x (epBase c) (incRndOf c) := by
  have h0 : shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨0, by omega⟩
      = shdP_incTB Rp x (incRndOf c) := rfl
  unfold ShdRunWitness.incTables shdP_honestRunWitness shdP_incTables
  rw [dite_eq_left hx]
  dsimp only
  rw [dite_eq_left (by omega : 0 < 27), h0]

open Classical in
theorem shdP_honestRunWitness_blkTables {Hdr Coins : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : Coins) (k : ℕ) (hk : k < 26) :
    (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x).blkTables k c
      = shdP_blkTables (shdP_Pk0 tag ioIn ioOut checkOpening Rp) k
          (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k hk)
          (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, Nat.lt_succ_of_lt hk⟩)
          (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k + 1, Nat.succ_lt_succ hk⟩)
          (blkRndOf c ⟨k, hk⟩) := by
  have hk27 : k < 27 := by omega
  have hk127 : k + 1 < 27 := by omega
  unfold ShdRunWitness.blkTables shdP_honestRunWitness
  rw [dite_eq_left hx]
  dsimp only
  simp only [dite_eq_left hk27, dite_eq_left hk127, dite_eq_left hk]
  rfl

open Classical in
theorem shdP_honestRunWitness_blkTables_total {Hdr Coins : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (H : HIn → Dig) (st : ClsStmt Hdr) (c : Coins) (k : ℕ) (hk : k < 26) :
    (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x).blkTables k c
      = shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub
          (fun b hb => (hweights b hb).act0) incRndOf blkRndOf H st x c k := by
  rw [shdP_honestRunWitness_blkTables (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
    embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x hx c k hk]
  unfold shdP_blkTables_total
  rw [dite_eq_left (And.intro hx hk)]

open Classical in
theorem shdP_honestRunWitness_outcTables {Hdr Coins : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (H : HIn → Dig) (hdr : Hdr) (r : Dig) (c : Coins) :
    (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x).outcTables c
      = shdP_outcTables_total tag Rp houtPub wDigest bOutRow
          (shdP_bndTableLast_total Rp hR hweights hinPub incRndOf blkRndOf) outcRndOf
          H (honestStmt hdr r ((classifySpecP Rp x).getD 0)) x c := by
  have h1 :
      (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
          embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x).outcTables c
        = shdP_outcTables tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0)
            (outcWitness_of_adm Rp houtPub x hx)
            (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨26, by omega⟩)
            (outcRndOf c) := by
    unfold ShdRunWitness.outcTables shdP_honestRunWitness
    rw [dite_eq_left hx]
    dsimp only
    rw [dite_eq_left (by omega : 26 < 27)]
    rfl
  have hlast :
      shdP_bndTableLast_total Rp hR hweights hinPub incRndOf blkRndOf H
          (honestStmt hdr r ((classifySpecP Rp x).getD 0)) x c
        = shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨26, by omega⟩ := by
    unfold shdP_bndTableLast_total
    exact dite_eq_left hx
  have h2 :
      shdP_outcTables_total tag Rp houtPub wDigest bOutRow
          (shdP_bndTableLast_total Rp hR hweights hinPub incRndOf blkRndOf) outcRndOf
          H (honestStmt hdr r ((classifySpecP Rp x).getD 0)) x c
        = shdP_outcTables tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0)
            (outcWitness_of_adm Rp houtPub x hx)
            (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨26, by omega⟩)
            (outcRndOf c) := by
    unfold shdP_outcTables_total
    rw [dite_eq_left hx, hlast]
    rfl
  exact h1.trans h2.symm

private theorem top_incP_abs_run_decomp {Hdr Coins : Type} (tag : MTag) (V : IncV)
    (C : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables V)
    (H : HIn → Dig) (s : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr) :
    (∀ enc cr' t',
      (inSegP _ (incP_abs tag V C)).run H s x c bnd start cr t = .ok (enc, cr', t') →
      ∃ R, incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H s x c) t) t = .ok R
        ∧ cr' = ⟨R.acc.claims.out, (C H s x c).bRoot⟩ ∧ t' = R.t8)
    ∧ ((inSegP _ (incP_abs tag V C)).run H s x c bnd start cr t = .error () →
      incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H s x c) t) t = .error ()) := by
  refine ⟨fun enc cr' t' h => ?_, fun h => ?_⟩
  · dsimp only [inSegP, incP_abs] at h
    cases hpr : incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H s x c) t) t with
    | error e => rw [hpr] at h; cases h
    | ok R =>
      rw [hpr] at h; dsimp only [Bind.bind, Except.bind] at h
      simp only [Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨-, rfl, rfl⟩ := h; exact ⟨R, rfl, rfl, rfl⟩
  · dsimp only [inSegP, incP_abs] at h
    cases hpr : incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H s x c) t) t with
    | error e => cases e; rfl
    | ok R => rw [hpr] at h; dsimp only [Bind.bind, Except.bind] at h; cases h

private theorem top_outcP_abs_run_decomp {Hdr Coins : Type} (tag : MTag) (V : ℕ → OutcV)
    (C : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins → OutcTables (V s.verdict))
    (H : HIn → Dig) (s : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr) :
    (outSegP _ (outcP_abs tag V C)).run H s x c bnd start cr t = .error () →
    outcProve H (V s.verdict) (outcDataAt_abs tag H (V s.verdict) (C H s x c) t) cr t = .error () := by
  intro h; dsimp only [outSegP, outcP_abs] at h
  cases hpr : outcProve H (V s.verdict) (outcDataAt_abs tag H (V s.verdict) (C H s x c) t) cr t with
  | error e => cases e; rfl
  | ok R => rw [hpr] at h; dsimp only [Bind.bind, Except.bind] at h; cases h

open Classical in
private theorem top_blkSegP_guarded_run_decomp {St X Coins : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → Exec.Block.SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Exec.Block.Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndCheck : St → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr → Except String Tr)
    (Ly : ShieldLayer) (hLy : Ly ∈ shieldExport) (Pb : BlockPublic (shieldShape Ly))
    (W : (HIn → Dig) → St → X → Coins → (k : ℕ) → ShdBlkTables Pk k)
    (k : ℕ) (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr) :
    let w := W H s x c k
    let bRoot := rootOf H tag 16 w.TB_next
    let tFrame := blockFrame (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) H s k bRoot t
    let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (Pk k) w.coreT tFrame
    (∀ enc cr' t',
      (shdP_blkSegP_guarded tag Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Ly Pb W k).run
        H s x c bnd start cr t = .ok (enc, cr', t') →
      ∃ R, coreProve H (Pk k) D tFrame = .ok R
        ∧ cr' = ⟨R.acc.claims.out, bRoot⟩
        ∧ t' = (bOpen H tag Exec.R13.r13Prm 16 w.TB_prev (cr.pending ++ R.acc.claims.inp) R.t7).2)
    ∧ (cr.root = rootOf H tag 16 w.TB_prev →
       (∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 w.TB_prev.rows (toZClaim cl)) →
       (shdP_blkSegP_guarded tag Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Ly Pb W k).run
         H s x c bnd start cr t = .error () →
       blkAlphaBadP Ly Pb (coreB H (Pk k) D tFrame).1 (coreG H (Pk k) D tFrame).1 (coreA H (Pk k) D tFrame).1
         ∨ coreProve H (Pk k) D tFrame = .error ()
         ∨ ∃ R e, coreProve H (Pk k) D tFrame = .ok R
             ∧ bndCheck s k (cr.pending ++ R.acc.claims.inp) R.t7 = .error e) := by
  intro w bRoot tFrame D
  refine ⟨fun enc cr' t' h => ?_, fun hroot htrue h => ?_⟩
  · obtain ⟨-, hrunU⟩ := shdP_blkSegP_guarded_run_ok tag Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
      Ly Pb W k H s x c bnd start cr t (enc, cr', t') h
    unfold shdP_blkSegP at hrunU
    dsimp only at hrunU
    by_cases hown : decide (cr.root = rootOf H tag 16 w.TB_prev
        ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 w.TB_prev.rows (toZClaim cl)) = true
    · rw [ite_eq_left hown] at hrunU
      cases hcp : coreProve H (Pk k) D tFrame with
      | error e => rw [hcp] at hrunU; cases hrunU
      | ok R =>
        rw [hcp] at hrunU; dsimp only at hrunU
        cases hbc : bndCheck s k (cr.pending ++ R.acc.claims.inp) R.t7 with
        | error e => rw [hbc] at hrunU; cases hrunU
        | ok u =>
          rw [hbc] at hrunU; dsimp only at hrunU
          simp only [Except.ok.injEq, Prod.mk.injEq] at hrunU
          obtain ⟨-, rfl, rfl⟩ := hrunU
          exact ⟨R, rfl, rfl, rfl⟩
    · rw [ite_eq_right hown] at hrunU; cases hrunU
  · unfold shdP_blkSegP_guarded at h
    dsimp only at h
    by_cases hbad : blkAlphaBad Ly Pb
        (bgaOf H (Pk k) (rootOf H tag 16 w.coreT.TA)
          (rootOf H tag 12 (mTab 23 (cosetPt (rootFp 12)) w.coreT.M)) tFrame) = true
    · rw [bgaOf_core H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (Pk k) w.coreT tFrame] at hbad
      exact Or.inl (blkAlphaBad_true_implies_blkAlphaBadP Ly hLy Pb
        (coreB H (Pk k) D tFrame).1 (coreG H (Pk k) D tFrame).1 (coreA H (Pk k) D tFrame).1
        (canon_challengeFp2Of _) hbad)
    · rw [ite_eq_right hbad] at h
      unfold shdP_blkSegP at h
      dsimp only at h
      rw [decide_eq_true ⟨hroot, htrue⟩, ite_eq_left rfl] at h
      cases hcp : coreProve H (Pk k) D tFrame with
      | error e => cases e; exact Or.inr (Or.inl rfl)
      | ok R =>
        rw [hcp] at h; dsimp only at h
        cases hbc : bndCheck s k (cr.pending ++ R.acc.claims.inp) R.t7 with
        | error e => exact Or.inr (Or.inr ⟨R, e, rfl, hbc⟩)
        | ok u => rw [hbc] at h; dsimp only at h; cases h

private theorem blockFrame_d12aBlockProf {St : Type} (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → Exec.Block.SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Exec.Block.Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndCheck : St → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr → Except String Tr)
    (H : HIn → Dig) (s : St) (k : ℕ) (bRoot : Dig) (t : Tr) :
    blockFrame (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) H s k bRoot t
      = Exec.Block.absorbRoot H
          (Tr.absorb H (Tr.absorbU64 H t labRunStage (UInt64.ofNat (k + 1))) labRunBlock (digest s k).toList)
          labB bRoot (bRows (k + 1)) (bLogN (k + 1)) := rfl

open Classical in
/-- Generic `ShdRunProverMatch` for any prover whose block segments use `shdP_blkSegP_guarded`
(parametric over opaque `P`, `W`, `C_in`, `W_blk`, `C_out` so `isDefEq` never unfolds `rootOf` or
concrete tables). -/
private theorem shdP_guardedProverMatch {Hdr Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (hR : ShieldRun Rp) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (check : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (C_in : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables (shdVi tag Rp embDigest bInRow))
    (W_blk : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → (k : ℕ) → ShdBlkTables (shdP_Pk0 tag ioIn ioOut checkOpening Rp) k)
    (C_out : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins → OutcTables (shdVo tag Rp wDigest bOutRow s.verdict))
    (hdig : ∀ r v k, k < 26 → digest (honestStmt P.hdr r v) k = blkDig k)
    (hPin : P.inC = inSegP _ (shdP_incP tag Rp embDigest bInRow C_in))
    (hPblk : ∀ k (hk : k < 26), P.blk k = shdP_blkSegP_guarded tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) check paths digest (fun _ => 38) (fun _ => 14)
      bndCheck (cbBndOpen tag 38) (shdP_layer k hk) (shdP_blkPub Rp hR k hk) W_blk k)
    (hPout : P.outC = outSegP _ (shdP_outcP tag Rp wDigest bOutRow C_out))
    (hCin : ∀ H r c, C_in H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c = W.incTables H c)
    (hWblk : ∀ H r c k, k < 26 → W_blk H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c k = W.blkTables k c)
    (hCout : ∀ H r c, C_out H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c = W.outcTables c) :
    ShdRunProverMatch tag Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening bndCheck blkDig epBase P x W where
  inC_ok H r c bnd start cr t enc cr' t' h := by
    rw [hPin] at h
    have hd := (top_incP_abs_run_decomp tag (shdVi tag Rp embDigest bInRow) C_in H
      (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t).1 enc cr' t' h
    rw [hCin H r c] at hd
    have hbRoot : (W.incTables H c).bRoot = rootOf H tag 16 (W.TB 0 c) := rfl
    rw [hbRoot] at hd
    exact hd
  inC_err H r c bnd start cr t h := by
    rw [hPin] at h
    have hd := (top_incP_abs_run_decomp tag (shdVi tag Rp embDigest bInRow) C_in H
      (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t).2 h
    rw [hCin H r c] at hd
    exact hd
  blk_ok k hk H r c bnd start cr t enc cr' t' h := by
    rw [hPblk k hk] at h
    have hd := (top_blkSegP_guarded_run_decomp tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) check paths digest (fun _ => 38) (fun _ => 14)
      bndCheck (cbBndOpen tag 38) (shdP_layer k hk) (shdP_layer_mem k hk) (shdP_blkPub Rp hR k hk) W_blk k H
      (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t).1 enc cr' t' h
    rw [hWblk H r c k hk] at hd
    have hTBprev : (W.blkTables k c).TB_prev = W.TB k c := rfl
    have hTBnext : (W.blkTables k c).TB_next = W.TB (k + 1) c := rfl
    rw [hTBprev, hTBnext] at hd
    have hfr : blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) check paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) k (rootOf H tag 16 (W.TB (k + 1) c)) t
        = ((blkFrameProg k (blkDig k) (TProg.done ()) (rootOfP tag 16 (W.TB (k + 1) c))).final H t).1 := by
      rw [final_blkFrameProg, final_done_fst, blockFrame_d12aBlockProf, hdig r _ k hk]
    rw [hfr] at hd
    exact hd
  blk_err k hk H r c bnd start cr t hroot htrue h := by
    rw [hPblk k hk] at h
    have hd := (top_blkSegP_guarded_run_decomp tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) check paths digest (fun _ => 38) (fun _ => 14)
      bndCheck (cbBndOpen tag 38) (shdP_layer k hk) (shdP_layer_mem k hk) (shdP_blkPub Rp hR k hk) W_blk k H
      (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t).2
    rw [hWblk H r c k hk] at hd
    have hTBprev : (W.blkTables k c).TB_prev = W.TB k c := rfl
    have hTBnext : (W.blkTables k c).TB_next = W.TB (k + 1) c := rfl
    rw [hTBprev, hTBnext] at hd
    have hd' := hd hroot htrue h
    have hfr : blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) check paths digest (fun _ => 38) (fun _ => 14)
          bndCheck (cbBndOpen tag 38))
        H (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) k (rootOf H tag 16 (W.TB (k + 1) c)) t
        = ((blkFrameProg k (blkDig k) (TProg.done ()) (rootOfP tag 16 (W.TB (k + 1) c))).final H t).1 := by
      rw [final_blkFrameProg, final_done_fst, blockFrame_d12aBlockProf, hdig r _ k hk]
    rw [hfr] at hd'
    exact hd'
  outC_err H r c bnd start cr t h := by
    rw [hPout] at h
    have hd := top_outcP_abs_run_decomp tag (shdVo tag Rp wDigest bOutRow) C_out H
      (honestStmt P.hdr r ((classifySpecP Rp x).getD 0)) x c bnd start cr t h
    rw [hCout H r c] at hd
    exact hd

open Classical in
/-- **`ShdRunProverMatch` for the `blkAlphaBad`-guarded unified prover `shdP_honestRunP`** against
`shdP_honestRunWitness` on every admissible input `x`. -/
theorem shdP_honestRun_proverMatch {Hdr Coins : Type}
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hdr : Hdr) (refused : ClsStmt Hdr)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig)
    (hdig : ∀ r v k, k < 26 → digest (honestStmt hdr r v) k = blkDig k)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) :
    ShdRunProverMatch tag Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening bndCheck blkDig epBase
      (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
      x
      (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x) :=
  shdP_guardedProverMatch tag Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening
    (vdChk check0) shdP_segPaths digest bndCheck blkDig epBase
    (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
    x
    (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x)
    (fun H _ x c => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x (epBase c) (incRndOf c))
    (shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub
      (fun b hb => (hweights b hb).act0) incRndOf blkRndOf)
    (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
      (shdP_bndTableLast_total Rp hR hweights hinPub incRndOf blkRndOf) outcRndOf)
    hdig rfl
    (fun k hk => by
      change (if hk' : k < 26 then _ else _) = _
      exact dite_eq_left hk)
    rfl
    (fun H _ c => (shdP_honestRunWitness_incTables (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut
      checkOpening embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x hx H c).symm)
    (fun H r c k hk => (shdP_honestRunWitness_blkTables_total (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut
      checkOpening embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x hx
      H (honestStmt hdr r ((classifySpecP Rp x).getD 0)) c k hk).symm)
    (fun H r c => (shdP_honestRunWitness_outcTables (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut
      checkOpening embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x hx H hdr r c).symm)

/-- **Whole-run refusal cover (`hcover`) for `shdP_honestRunP`** across all 28 segments (`1` IN-C +
`26` guarded R13 blocks + `1` OUT-C), discharging `hIncOutTrue` via `(shdP_inc_arith ...).2` and
`hBlkOutTrue` unconditionally via `shdP_blk_outClaims_true_uncond`. -/
theorem shdP_honestRun_hcover {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hB0 : (bInRow = 32 ∧ ioIn = 34) ∨ (bInRow = 34 ∧ ioIn = 32))
    (hBk : (ioOut = 32 ∧ ioIn = 34) ∨ (ioOut = 34 ∧ ioIn = 32))
    (hB26 : (ioOut = 32 ∧ bOutRow = 34) ∨ (ioOut = 34 ∧ bOutRow = 32))
    (hdr : Hdr) (refused : ClsStmt Hdr) (blkDig : ℕ → Dig)
    (hdig : ∀ r v k, k < 26 → digest (honestStmt hdr r v) k = blkDig k)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (hchkA : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .a cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomA 14 cl t = .error e')
    (hchkH : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .h cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 cl t = .error e')
    (hbnd : ∀ (G : QB Lq → Dig) s k cl t e, k < 26 → bndCheck s k cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t = .error e') :
    let P := shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf
    let W := shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf
    ∀ x, (classifyModelP Rp).admissible x → ∀ G c,
      honestSegs
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag epBase).base c))
        ((classifySpecP Rp x).getD 0) x c = .error () →
      ∃ i, (shdP_runSite tag Lq hL20 key Rp hR hV131072 hw hdr ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow blkDig epBase W x i).fires shdP_U G c :=
  shdP_refuse_hcover tag Lq hL20 key Rp hR hV131072 hinPub hw preA preB check0 paths digest bndCheck
    ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow hB0 hBk hB26 blkDig epBase
    (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
    hdig
    (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf)
    (fun x hx => shdP_honestRun_proverMatch tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut
      checkOpening embDigest bInRow wDigest bOutRow check0 digest bndCheck blkDig hdig
      epBase incRndOf blkRndOf outcRndOf x hx)
    hchkA hchkH hbnd
    (fun x hx G c t R hR_inc => by
      rw [shdP_honestRunWitness_incTables (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut
        checkOpening embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x hx (liftH G) c] at hR_inc
      rw [shdP_honestRunWitness_TB0 (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut
        checkOpening embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x hx c]
      exact (shdP_inc_arith (Hdr := Hdr) (liftH G) tag Rp hinPub hV131072 embDigest bInRow x hx
        (epBase c) (incRndOf c) t R hR_inc).2)
    (fun x hx G c k hk t R hR_blk => by
      have hblk := shdP_honestRunWitness_blkTables (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut
        checkOpening embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x hx c k hk
      rw [hblk] at hR_blk
      rw [shdP_honestRunWitness_TB (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut
        checkOpening embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf x hx c (k + 1) (by omega)]
      exact shdP_blk_outClaims_true_uncond (liftH G) tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
        (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k hk)
        (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, Nat.lt_succ_of_lt hk⟩)
        (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k + 1, Nat.succ_lt_succ hk⟩)
        (shdP_bndTableAt_spec Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k + 1, Nat.succ_lt_succ hk⟩).rows_len
        (blkRndOf c ⟨k, hk⟩) t R hR_blk)

end HonestRunRefusal

/-! ## 5. Top-Level `ProductionReadyL` Assembly (Pure ROM, `εzk := shdRunErrRes`, No `NativeOsRngIndist`) -/

section TopAssembly

/-- **Open shell at `εzk := shdRunErrRes`**: wires any prover `P`, site family `site`, and
`ZeroKnowledge ... shdRunErrRes` directly into `RunStgShieldClTopEF.sshC_productionReadyL_epP_blkEF_zg`
via `shdRunErrRes_hzk` (ruling `L63-15`). -/
theorem shdP_openShell_res {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
    (epBase : Coins → EpxSalt 6)
    (site : (shieldS0.Tok → ℕ) → shdP_SiteIdx → ProtocolClassify.Site (QB Lq) Coins shdP_K)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid)
    (hinPub : Rp.inp.Valid)
    (houtPub : Rp.out.Valid)
    (hpol : preA P.hdr = .ok () ∧ preB P.hdr = .ok ())
    (hsegIn : SegComplete (classifyModelP Rp).admissible liftH
      (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      P.inC
      (inSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck).inC))
    (hsegBlk : ∀ k, k < 26 →
      SegComplete (classifyModelP Rp).admissible liftH
        (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
          (shdP_honestIn (Hdr := Hdr) tag epBase).base)
        (P.blk k)
        (blockSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck).blk k))
    (hsegOut : SegComplete (classifyModelP Rp).admissible liftH
      (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      P.outC
      (outSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck).outC))
    (hk : ∀ x i, (site x i).k ≤ shdP_kOf i)
    (hδ : ∀ x i, (site x i).δ = 0)
    (hcover : ∀ x, (classifyModelP Rp).admissible x → ∀ G c,
      honestSegs
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x
          ((shdP_honestIn (Hdr := Hdr) tag epBase).base c))
        ((classifySpecP Rp x).getD 0) x c = .error ()
        → ∃ i, (site x i).fires shdP_U G c)
    (hzk : ZeroKnowledge (classifyModelP Rp)
      (classifyProtocolP Rp Lq
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base)
      shdRunErrRes) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart shdP_runDomain key hw)
        (fun _ => shdP_incV tag Rp embDigest (embFoldL Rp.inp) bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest (embFoldL Rp.inp) bInRow) 28)
        (d12aBlockProf (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp))
          (vdChk check0) paths digest (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  sshC_productionReadyL_epP_blkEF_zg
    (Hdr := Hdr) (Coins := Coins) (tag := tag) (Lq := Lq) (hL20 := hL20) (hL64 := hL64)
    (key := key) (Rp := Rp) (hR := hR) (hw := hw) (hhdrFit := hhdrFit)
    (preA := preA) (preB := preB) (check0 := check0) (paths := paths) (digest := digest) (bndCheck := bndCheck)
    (ioIn := ioIn) (ioOut := ioOut) (checkOpening := checkOpening)
    (embDigest := embDigest) (bInRow := bInRow) (wDigest := wDigest) (bOutRow := bOutRow)
    (P := P) (epBase := epBase) (site := site) (kOf := shdP_kOf) (δOf := shdP_δOf)
    (εzk := shdRunErrRes)
    (O := shdP_classifyOpenP_shell tag Lq hL20 key shdP_runDomain hw preA preB Rp hR
      embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      check0 paths digest bndCheck P epBase site hweights hinPub houtPub hpol
      (classifyP_parts_of_segs Rp Lq
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 paths digest bndCheck)
        P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base hsegIn hsegBlk hsegOut)
      hk hδ hcover hzk)
    (hzkB := shdRunErrRes_hzk)
    (E0b := fun _ _ _ => shdP_zeroRunExt)
    (hV131072 := hV131072)

/-- **Complete `ClassifyOpenP ... shdRunErrRes` for `shdP_honestRunP`**: discharges ALL fields
(`width`, `shapes`, `blocks`, `commit`, `policy`, `parts`, `refuse`, `counts`, and `zk` from
`W_zk : ShdZKProgWitness`) on ONE unified prover `shdP_honestRunP`. -/
theorem shdP_honest_classifyOpenP {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (shape : List UInt8)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hB0 : (bInRow = 32 ∧ ioIn = 34) ∨ (bInRow = 34 ∧ ioIn = 32))
    (hBk : (ioOut = 32 ∧ ioIn = 34) ∨ (ioOut = 34 ∧ ioIn = 32))
    (hB26 : (ioOut = 32 ∧ bOutRow = 34) ∨ (ioOut = 34 ∧ bOutRow = 32))
    (hdr : Hdr) (refused : ClsStmt Hdr) (blkDig : ℕ → Dig)
    (hdig : ∀ r v k, k < 26 → digest (honestStmt hdr r v) k = blkDig k)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hpol : preA hdr = .ok () ∧ preB hdr = .ok ())
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (hCheck0 : ∀ k, k < 26 → ∀ G x c, (classifyModelP Rp).admissible x →
      check0 (clsStmtOfP Rp Lq
        (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
          embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
        (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base G x c) k = .ok ())
    (hgrpA : ∀ H cl t, checkOpening H .a cl t = .ok () → (groupZclaims (cl.map toZClaim) 4577 14).length = 36)
    (hgrpH : ∀ H cl t, checkOpening H .h cl t = .ok () → (groupZclaims (cl.map toZClaim) 4390 14).length = 9)
    (hgrpB : ∀ k, k < 26 → ∀ st cl t, bndCheck st k cl t = .ok () →
      (groupZclaims (cl.map toZClaim) 38 14).length = 2)
    (hchkA : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .a cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomA 14 cl t = .error e')
    (hchkH : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .h cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 cl t = .error e')
    (hbnd : ∀ (G : QB Lq → Dig) s k cl t e, k < 26 → bndCheck s k cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t = .error e')
    (W_zk : ShdZKProgWitness Rp Lq hL20 tag key shdP_runDomain shape
      (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 shdP_segPaths digest bndCheck)
      (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
      (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base) :
    let P := shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf
    let W := shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf
    let site := shdP_runSite tag Lq hL20 key Rp hR hV131072 hw hdr ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow blkDig epBase W
    ClassifyOpenP Rp Lq
      (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 shdP_segPaths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn tag epBase) shdP_U site shdP_kOf shdP_δOf shdRunErrRes :=
  shdP_classifyOpenP_shell_zk tag Lq hL20 key shdP_runDomain shape hw preA preB Rp hR
    embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
    check0 shdP_segPaths digest bndCheck
    (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
    epBase
    (shdP_runSite tag Lq hL20 key Rp hR hV131072 hw hdr ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow blkDig epBase
      (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf))
    hweights hinPub houtPub hpol
    (shdP_honestRun_parts tag Lq hL20 key Rp hR hw preA preB check0 digest bndCheck
      ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow hdr refused hV131072
      hweights hinPub houtPub epBase incRndOf blkRndOf outcRndOf hCheck0 hgrpA hgrpH hgrpB)
    (shdP_refuse_hk tag Lq hL20 key Rp hR hV131072 hw hdr ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow blkDig epBase
      (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf))
    (shdP_refuse_hδ tag Lq hL20 key Rp hR hV131072 hw hdr ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow blkDig epBase
      (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf))
    (shdP_honestRun_hcover tag Lq hL20 key Rp hR hV131072 hweights hinPub houtPub hw preA preB
      check0 shdP_segPaths digest bndCheck ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow
      hB0 hBk hB26 hdr refused blkDig hdig epBase incRndOf blkRndOf outcRndOf hchkA hchkH hbnd)
    W_zk

/-- **TOP-LEVEL SHIELDSTRAL T128 R13 `ProductionReadyL` THEOREM (`L68c`, pure ROM)**:
wires the unified concrete honest prover `shdP_honestRunP` (all 5 pillars: Stage IN-C, 26 R13 blocks,
Stage OUT-C, whole-run refusal cover, and `O.zk` at `shdRunErrRes`) directly onto L63's
`sshC_productionReadyL_epP_blkEF_zg` + `shdRunErrRes_hzk`. Zero open `ClassifyOpenP` fields remain;
only setting, model-validity, policy/check-hook, and `W_zk : ShdZKProgWitness` premises remain. -/
theorem shdP_honest_productionReadyL {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (key : Option Dig) (shape : List UInt8)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hB0 : (bInRow = 32 ∧ ioIn = 34) ∨ (bInRow = 34 ∧ ioIn = 32))
    (hBk : (ioOut = 32 ∧ ioIn = 34) ∨ (ioOut = 34 ∧ ioIn = 32))
    (hB26 : (ioOut = 32 ∧ bOutRow = 34) ∨ (ioOut = 34 ∧ bOutRow = 32))
    (hdr : Hdr) (refused : ClsStmt Hdr) (blkDig : ℕ → Dig)
    (hdig : ∀ r v k, k < 26 → digest (honestStmt hdr r v) k = blkDig k)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hpol : preA hdr = .ok () ∧ preB hdr = .ok ())
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (hCheck0 : ∀ k, k < 26 → ∀ G x c, (classifyModelP Rp).admissible x →
      check0 (clsStmtOfP Rp Lq
        (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
          embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
        (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base G x c) k = .ok ())
    (hgrpA : ∀ H cl t, checkOpening H .a cl t = .ok () → (groupZclaims (cl.map toZClaim) 4577 14).length = 36)
    (hgrpH : ∀ H cl t, checkOpening H .h cl t = .ok () → (groupZclaims (cl.map toZClaim) 4390 14).length = 9)
    (hgrpB : ∀ k, k < 26 → ∀ st cl t, bndCheck st k cl t = .ok () →
      (groupZclaims (cl.map toZClaim) 38 14).length = 2)
    (hchkA : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .a cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomA 14 cl t = .error e')
    (hchkH : ∀ (G : QB Lq → Dig) cl t e, checkOpening (liftH G) .h cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 cl t = .error e')
    (hbnd : ∀ (G : QB Lq → Dig) s k cl t e, k < 26 → bndCheck s k cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t = .error e')
    (W_zk : ShdZKProgWitness Rp Lq hL20 tag key shdP_runDomain shape
      (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 shdP_segPaths digest bndCheck)
      (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
      (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
      (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart shdP_runDomain key hw)
        (fun _ => shdP_incV tag Rp embDigest (embFoldL Rp.inp) bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest (embFoldL Rp.inp) bInRow) 28)
        (d12aBlockProf (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp))
          (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
          embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
        (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  sshC_productionReadyL_epP_blkEF_zg
    (Hdr := Hdr) (Coins := Coins) (tag := tag) (Lq := Lq) (hL20 := hL20) (hL64 := hL64)
    (key := key) (Rp := Rp) (hR := hR) (hw := hw) (hhdrFit := hhdrFit)
    (preA := preA) (preB := preB) (check0 := check0) (paths := shdP_segPaths)
    (digest := digest) (bndCheck := bndCheck)
    (ioIn := ioIn) (ioOut := ioOut) (checkOpening := checkOpening)
    (embDigest := embDigest) (bInRow := bInRow) (wDigest := wDigest) (bOutRow := bOutRow)
    (P := shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow check0 digest bndCheck epBase incRndOf blkRndOf outcRndOf)
    (epBase := epBase)
    (site := shdP_runSite tag Lq hL20 key Rp hR hV131072 hw hdr ioIn ioOut checkOpening
      embDigest bInRow wDigest bOutRow blkDig epBase
      (shdP_honestRunWitness (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut checkOpening
        embDigest bInRow wDigest bOutRow epBase incRndOf blkRndOf outcRndOf))
    (kOf := shdP_kOf) (δOf := shdP_δOf) (εzk := shdRunErrRes)
    (O := shdP_honest_classifyOpenP tag Lq hL20 key shape Rp hR hw preA preB check0 digest bndCheck
      ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow hB0 hBk hB26 hdr refused blkDig hdig
      hV131072 hweights hinPub houtPub hpol epBase incRndOf blkRndOf outcRndOf
      hCheck0 hgrpA hgrpH hgrpB hchkA hchkH hbnd W_zk)
    (hzkB := shdRunErrRes_hzk)
    (E0b := fun _ _ _ => shdP_zeroRunExt)
    (hV131072 := hV131072)

/-- **Clean concrete-hooks corollary (`shdP_honest_productionReadyL_okPre`)**:
specializes `preA = preB = fun _ => .ok ()`, `check0 = fun _ _ => .ok ()`, `paths = shdP_segPaths`,
`checkOpening = checkField shdP_blkOpenGeom`, and `bndCheck = fun _ _ cl _ => shdP_bndCheckPure cl`,
discharging ALL eight policy/check/group-count/opening-refusal hypotheses
(`hpol`, `hCheck0`, `hgrpA`, `hgrpH`, `hgrpB`, `hchkA`, `hchkH`, `hbnd`) in one shot. -/
theorem shdP_honest_productionReadyL_okPre {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (key : Option Dig) (shape : List UInt8)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (ioIn ioOut : ℕ)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hB0 : (bInRow = 32 ∧ ioIn = 34) ∨ (bInRow = 34 ∧ ioIn = 32))
    (hBk : (ioOut = 32 ∧ ioIn = 34) ∨ (ioOut = 34 ∧ ioIn = 32))
    (hB26 : (ioOut = 32 ∧ bOutRow = 34) ∨ (ioOut = 34 ∧ bOutRow = 32))
    (hdr : Hdr) (refused : ClsStmt Hdr) (blkDig : ℕ → Dig)
    (hdig : ∀ r v k, k < 26 → digest (honestStmt hdr r v) k = blkDig k)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (W_zk : ShdZKProgWitness Rp Lq hL20 tag key shdP_runDomain shape
      (shdP_runV tag key shdP_runDomain hw (fun _ => .ok ()) (fun _ => .ok ()) Rp embDigest
        (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp)
        (fun _ _ => .ok ()) shdP_segPaths digest (fun _ _ cl _ => shdP_bndCheckPure cl))
      (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut
        (checkField shdP_blkOpenGeom) embDigest bInRow wDigest bOutRow
        (fun _ _ => .ok ()) digest (fun _ _ cl _ => shdP_bndCheckPure cl)
        epBase incRndOf blkRndOf outcRndOf)
      (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
      (classifyProtocolUExecP Rp Lq 26 (fun _ => .ok ()) (fun _ => .ok ()) (clsStart shdP_runDomain key hw)
        (fun _ => shdP_incV tag Rp embDigest (embFoldL Rp.inp) bInRow)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest (embFoldL Rp.inp) bInRow) 28)
        (d12aBlockProf (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp))
          (vdChk (fun _ _ => .ok ())) shdP_segPaths digest (fun _ => 38) (fun _ => 14)
          (fun _ _ cl _ => shdP_bndCheckPure cl) (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest bOutRow v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest bOutRow 0) 28)
        (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut
          (checkField shdP_blkOpenGeom) embDigest bInRow wDigest bOutRow
          (fun _ _ => .ok ()) digest (fun _ _ cl _ => shdP_bndCheckPure cl)
          epBase incRndOf blkRndOf outcRndOf)
        (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  shdP_honest_productionReadyL tag Lq hL20 hL64 key shape Rp hR hw hhdrFit
    (fun _ => .ok ()) (fun _ => .ok ()) (fun _ _ => .ok ()) digest
    (fun _ _ cl _ => shdP_bndCheckPure cl) ioIn ioOut (checkField shdP_blkOpenGeom)
    embDigest bInRow wDigest bOutRow hB0 hBk hB26 hdr refused blkDig hdig
    hV131072 hweights hinPub houtPub ⟨rfl, rfl⟩ epBase incRndOf blkRndOf outcRndOf
    (fun _ _ _ _ _ _ => rfl)
    shdP_blk_hgrpA_of_checkOpeningExec
    shdP_blk_hgrpH_of_checkOpeningExec
    (fun _ _ _ cl _ h => shdP_blk_hgrpB_of_pure cl h)
    (fun _ _ _ e h => ⟨e, h⟩)
    (fun _ _ _ e h => ⟨e, h⟩)
    (fun G _ _ cl t e _ herr => shdP_bndCheckPure_err_implies_checkOpeningExec (liftH G) cl t e herr)
    W_zk

/-- **Fully specialized concrete-row corollary (`shdP_honest_productionReadyL_concrete`)**:
further fixes the alternating boundary mask-row indices `(bInRow := 32, ioIn := 34, ioOut := 32,
bOutRow := 34)` and `digest := fun _ k => blkDig k`, discharging `hB0`, `hBk`, `hB26`, and `hdig`
and leaving only setting/model validity (`hL20`, `hL64`, `hR`, `hhdrFit`, `hV131072`, `hweights`,
`hinPub`, `houtPub`) plus the single ZK program witness `W_zk : ShdZKProgWitness`. -/
theorem shdP_honest_productionReadyL_concrete {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (key : Option Dig) (shape : List UInt8)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW)
    (hhdrFit : ∀ hd : Hdr,
      64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
    (embDigest wDigest : Dig)
    (hdr : Hdr) (refused : ClsStmt Hdr) (blkDig : ℕ → Dig)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (epBase : Coins → EpxSalt 6)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand) (outcRndOf : Coins → OutcRand)
    (W_zk : ShdZKProgWitness Rp Lq hL20 tag key shdP_runDomain shape
      (shdP_runV tag key shdP_runDomain hw (fun _ => .ok ()) (fun _ => .ok ()) Rp embDigest
        (embFoldL Rp.inp) 32 wDigest 34
        (shdP_Pk0 tag 34 32 (checkField shdP_blkOpenGeom) Rp)
        (fun _ _ => .ok ()) shdP_segPaths (fun _ k => blkDig k) (fun _ _ cl _ => shdP_bndCheckPure cl))
      (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused 34 32
        (checkField shdP_blkOpenGeom) embDigest 32 wDigest 34
        (fun _ _ => .ok ()) (fun _ k => blkDig k) (fun _ _ cl _ => shdP_bndCheckPure cl)
        epBase incRndOf blkRndOf outcRndOf)
      (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
      (classifyProtocolUExecP Rp Lq 26 (fun _ => .ok ()) (fun _ => .ok ()) (clsStart shdP_runDomain key hw)
        (fun _ => shdP_incV tag Rp embDigest (embFoldL Rp.inp) 32)
        (fun _ => rcIncGeom (shdP_incV tag Rp embDigest (embFoldL Rp.inp) 32) 28)
        (d12aBlockProf (shdP_Pk0 tag 34 32 (checkField shdP_blkOpenGeom) Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag 34 32 (checkField shdP_blkOpenGeom) Rp))
          (vdChk (fun _ _ => .ok ())) shdP_segPaths (fun _ k => blkDig k) (fun _ => 38) (fun _ => 14)
          (fun _ _ cl _ => shdP_bndCheckPure cl) (cbBndOpen tag 38))
        (fun _ v => shdP_outcV tag Rp wDigest 34 v)
        (fun _ => rcOutcGeom (shdP_outcV tag Rp wDigest 34 0) 28)
        (shdP_honestRunP tag Rp hR hweights hinPub houtPub hdr refused 34 32
          (checkField shdP_blkOpenGeom) embDigest 32 wDigest 34
          (fun _ _ => .ok ()) (fun _ k => blkDig k) (fun _ _ cl _ => shdP_bndCheckPure cl)
          epBase incRndOf blkRndOf outcRndOf)
        (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  shdP_honest_productionReadyL_okPre tag Lq hL20 hL64 key shape Rp hR hw hhdrFit
    (fun _ k => blkDig k) 34 32 embDigest 32 wDigest 34
    (Or.inl ⟨rfl, rfl⟩) (Or.inl ⟨rfl, rfl⟩) (Or.inl ⟨rfl, rfl⟩)
    hdr refused blkDig (fun _ _ _ _ => rfl)
    hV131072 hweights hinPub houtPub epBase incRndOf blkRndOf outcRndOf W_zk

end TopAssembly

end ZK60.HonestShield
