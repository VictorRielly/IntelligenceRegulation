/-
D63 lane L64 (2026-11-17): **concrete Shieldstral R13 block squeeze lists (`BlkLists`), full six-conjunct `RkSqOk`
certificates (`blkLists_rkSqOk`, stated at `eL = 2^26`; not used by the top theorem, `hD` unchanged, side hypothesis
`hhi` open), direct classify-run unmasking (`blk_unmask_at_run`), proof of the five block alive statements
(`hR0_blk`, `hR1_blk`, `hH0_blk`, `hH1_blk`, `hLU_blk`) for the squeeze lists pinned by `hbBlk` (given `hbpRows`,
`hPkC`, and the unchanged `hD`, `hDe`, `hslB`), proof of `hoAK..hoOK` from `hDe`, `hgX*`, and `hPkC`, and reduction of
`hblk` to the extraction-coherence obligation `hblkIO` in `sshC_productionReadyL_epP_blkAlive`**.

Mapping to L62 follow-up items (`L62-2`, `L62-3`, `L62-4`, `L62-5`, `L62-9`):
* **`ShieldBlkAtC`**, **`ShieldRunAtC`** (closes `L62-3` and `L62-9` in the bundle): pins `IsShieldR13`'s `tag` to the
  run's `tag`, sharpens `0 < endpointLogN` to `endpointLogN = 14` (replacing L62's separate `hep14`), and adds
  `kind 21 = .standalone ∧ kind 22 = .standalone`; **`shield*C`** projections close `L62-5` (`shieldLyC`, `shieldPbC`,
  `shieldRowsOfC`, `shieldLayC`, `shieldBC`, `shieldIoInC`, `shieldIoOutC`);
* **`polyS_congr_define`**, **`polyS_congr_ah`**, **`dArgs_sameAH_dXof`**: equates `polyS` across canonical `defineS`
  programs (`shieldRunProg`/`shieldRunPubs` vs `progR13`/`pubsR13L`) and equates `dArgs` with `dXof` on all non-IO
  slots `0..20` (`encGL_14`);
* **`bndPl`**, **`formAt_ioDefSchedB`**, **`ioDefSchedB_indDeg`** (closes `L62-2` and `L62-4` as far as `hblkIO`):
  concrete boundary plane reader on `bndTab` and proof of `FormAt` + `IndDegLE 1` for `ioDefSchedB` (`SC_IO_IN` slot 21,
  `SC_IO_OUT` slot 22);
* **`BlkLists`**, **`blkLists_rkSqOk`**: concrete `r0`, `r1`, `h0`, `h1`, `lu` lists on `base (k + 1)` and full
  six-conjunct `RkSqOk` proofs (`SqCut`, `.Rbr`, `e ≤ emax`, `n·e ≤ ND`, profile window `pf.off (k + 1) ≤ a ≤ pf.off (k + 2)`,
  and `Pairwise (a ≤ a)`) stated at `eL = 2^26` (not used by the top theorem; covers 5 of the 16 `RkPart.Ok` conjunct
  groups; assembling `hD`'s block part awaits deriving `hhi` from the profile and proving the other 11 `RkPart.Ok`
  conjunct groups);
* **`shield_hR0_blk`**, **`shield_hR1_blk`**, **`shield_hH0_blk`**, **`shield_hH1_blk`**, **`shield_hLU_blk`**,
  **`shield_hblk`**: direct classify-run proofs of the five block alive statements for the squeeze lists pinned by
  `hbBlk` (given `hbpRows`, `hPkC`, and the unchanged `hD`, `hDe`, `hslB`) and reduction of `Nonempty (RdBlkR13B ...)`
  to `ShieldBlkIO`;
* **`sshC_productionReadyL_epP_blkAlive`**: `sshC_productionReadyL_epP_dg` on `shieldS0` under `hPkC : ShieldRunAtC`,
  `hL20 : 2 ^ 20 ≤ Lq`, `hbpRows`, and `hbBlk : BlkLists (base (k + 1)) ...` (`hD` unchanged; `eL` remains a free
  parameter), proving `hoAK..hoOK` from `hDe`, `hgX*`, and `hPkC`, proving `hR0_blk..hLU_blk` for the squeeze lists
  pinned by `hbBlk` (given `hbpRows`, `hPkC`, and the unchanged `hD`, `hDe`, `hslB`), instantiating `ιL/πL/κL` and
  `AlkL/TL/mlkL`, and reducing `hblk` to `hblkIO`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunBlkShieldInst
import ZK60Formal.RunStgShieldCTopDg

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic)
open ZK60.Exec.Slot (toK_irEvalW Ir)
open ZK60.Exec.Block (BlockParams Cm Cuts3 RootsO HdrX SlotRec SlotKind SlotS SlotDef PubTabs Seen Hist CmData
  Priv PartK defSqB defSqB_rbr lkSqB lkSqB_rbr defPos defOff w16r2DR w16r2DH w16r2RelKs algHosts algSp algSp_dg
  algSp_van1 algSp_van2 algSp_van3 host_gd_of_sched SchedGd SchedVan FormAt spSum polyS polyS_seenOf polyS_indDeg
  defineS defineS_ok
  histSeen drSeen histSeen_seenOf drSeen_seenOf seenOf histOf rootsAt rootsOf cuts3 cutO absAt hdrX tupK card_K_gt
  dXof rowLog slotShape slotTerms blockSlotXB blockSchedXB tHistD claimK tabK privSpecs specPart ptK xrK
  unmask_slots claimed_unmasked blockSlots_fns mdot swk xOf Sym TabS CoordS)
open ZK60.Exec.Block.Join (cubeSum_split cpt bpt tabK_eq_cpt tabK_eq_off tabK_priv_cpt planeZ baseR
  tabK_eqFull_cpt tabK_rho_cpt castB_rfl aTab_eval)
open ZK60.Exec.Block.Join.W16 (aPl piB hPl planeZ_aPl)
open ZK60.Exec.Block.Join.R13H (CtR CwR CgR CjR CdR CfR nD offR xtR shShieldR geoShield LayR algShapeR shOk_shield
  profR_shield dtR hspecR encR encHtR perRow_shield xcR pwcR formAt_hostsR precR_shield shieldWindows ShieldBlkAt
  ShieldRunAt dXof_base_r13)
open ZK60.Exec.Block.Join.R13H.Help (spHR HGdR hgdR_of_r13 helperR_dg_r13 helperR_formAt_r13 helpProf_shield
  helpCfg_shield hgateL_shield hrest19L hrest20L drH drH_length progR13_slotH)
open ZK60.Exec.Block.Join.R13H.Look (dofARB AlkR13B mlkR13B hcov_shieldB TR13 hTtab_shield SgIx PrIx TbIx hN_shield
  he_shield logupSumR13 lookCfg_shield AlkR13 mlkR13)
open ZK60.Exec.Block.Join.R13H.LookRel (relsR_of hhr_of_relsR relCfg_shield)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Layout (W16Layout W16Pub)
open ZK60.RunShape (ClassifyRunPublicP RunBlock)
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldCal shieldS0 shieldShape shield_shapes_r13)

/-! ## 1. Complete Shieldstral block/run bundle (`ShieldBlkAtC`, `ShieldRunAtC`) and deterministic projections -/

section ShieldBundleC

/-- **`ShieldBlkAt` with `IsShieldR13`'s `tag` pinned to the run's `tag`, `0 < endpointLogN` sharpened to
`endpointLogN = 14` (`L62-3`), and standalone IO-slot kinds `kind 21 = .standalone ∧ kind 22 = .standalone` (`L62-9`).** -/
def ShieldBlkAtC (tag : MTag) (P : BlockParams) (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) : Prop :=
  ∃ (rowsOf : Cm → ℕ)
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay) (ioIn ioOut : ℕ),
    IsShieldR13 P tag rowsOf
      ∧ P.define = defineS (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut)
          (Exec.Block.Join.R13H.Pub.pubsR13L (Exec.Block.DefR13.cfgShieldR13 Ly) Pb Lay B (shieldShape Ly).nG)
      ∧ P.logCols = 14 ∧ P.endpointLogN = 14
      ∧ P.kind 3 = SlotKind.standalone ∧ P.kind 19 = SlotKind.standalone ∧ P.kind 20 = SlotKind.standalone
      ∧ P.kind 21 = SlotKind.standalone ∧ P.kind 22 = SlotKind.standalone
      ∧ P.logupSumClaim = logupSumR13 (Exec.Block.DefR13.cfgShieldR13 Ly)
      ∧ LayR Lay

theorem ShieldBlkAtC.toShieldBlkAt {tag : MTag} {P : BlockParams} {Ly : ShieldLayer}
    {Pb : BlockPublic (shieldShape Ly)} (h : ShieldBlkAtC tag P Ly Pb) : ShieldBlkAt P Ly Pb := by
  obtain ⟨rowsOf, Lay, B, ioIn, ioOut, hP, hdef, hlc, hep14, hk3, hk19, hk20, -, -, hls, hLay⟩ := h
  exact ⟨tag, rowsOf, Lay, B, ioIn, ioOut, hP, hdef, hlc, by omega, hk3, hk19, hk20, hls, hLay⟩

/-- **Run-level Shieldstral bundle (`L62-3`, `L62-5`, `L62-9`).** -/
def ShieldRunAtC (tag : MTag) {S0 : BlockShape} (Pk : ℕ → BlockParams) (blks : List (RunBlock S0)) (Lb : ℕ) : Prop :=
  ∀ k, k < Lb → ∃ (Ly : ShieldLayer) (b : RunBlock S0) (Pb : BlockPublic (shieldShape Ly)),
    shieldExport[k]? = some Ly ∧ blks[k]? = some b ∧ b.cal = shieldCal Ly ∧ HEq Pb b.pub
      ∧ ShieldBlkAtC tag (Pk k) Ly Pb

theorem ShieldRunAtC.toShieldRunAt {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)}
    {Lb : ℕ} (h : ShieldRunAtC tag Pk blks Lb) : ShieldRunAt Pk blks Lb := by
  intro k hk
  obtain ⟨Ly, b, Pb, hLy, hb, hcal, hPb, hc⟩ := h k hk
  exact ⟨Ly, b, Pb, hLy, hb, hcal, hPb, hc.toShieldBlkAt⟩

theorem ShieldRunAtC.ep14 {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)}
    {Lb : ℕ} (h : ShieldRunAtC tag Pk blks Lb) : ∀ k, k < Lb → (Pk k).endpointLogN = 14 := by
  intro k hk
  obtain ⟨_, _, _, -, -, -, -, _, _, _, _, _, -, -, -, hep14, -⟩ := h k hk
  exact hep14

noncomputable def shieldLyC {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtC tag Pk blks Lb) (k : ℕ) (hk : k < Lb) : ShieldLayer :=
  Classical.choose (h k hk)

noncomputable def shieldBlkC {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtC tag Pk blks Lb) (k : ℕ) (hk : k < Lb) : RunBlock S0 :=
  Classical.choose (Classical.choose_spec (h k hk))

noncomputable def shieldPbC {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtC tag Pk blks Lb) (k : ℕ) (hk : k < Lb) : BlockPublic (shieldShape (shieldLyC h k hk)) :=
  Classical.choose (Classical.choose_spec (Classical.choose_spec (h k hk)))

theorem shieldRunAtC_spec {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtC tag Pk blks Lb) (k : ℕ) (hk : k < Lb) :
    shieldExport[k]? = some (shieldLyC h k hk)
      ∧ blks[k]? = some (shieldBlkC h k hk)
      ∧ (shieldBlkC h k hk).cal = shieldCal (shieldLyC h k hk)
      ∧ HEq (shieldPbC h k hk) (shieldBlkC h k hk).pub
      ∧ ShieldBlkAtC tag (Pk k) (shieldLyC h k hk) (shieldPbC h k hk) :=
  Classical.choose_spec (Classical.choose_spec (Classical.choose_spec (h k hk)))

theorem shieldLyC_mem {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtC tag Pk blks Lb) (k : ℕ) (hk : k < Lb) : shieldLyC h k hk ∈ shieldExport :=
  List.mem_of_getElem? (shieldRunAtC_spec h k hk).1

noncomputable def shieldRowsOfC {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)}
    {Lb : ℕ} (h : ShieldRunAtC tag Pk blks Lb) (k : ℕ) (hk : k < Lb) : Cm → ℕ :=
  Classical.choose (shieldRunAtC_spec h k hk).2.2.2.2

noncomputable def shieldLayC {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtC tag Pk blks Lb) (k : ℕ) (hk : k < Lb) :
    W16Layout (shieldShape (shieldLyC h k hk)) (CtR (Exec.Block.DefR13.cfgShieldR13 (shieldLyC h k hk)))
      (CwR (Exec.Block.DefR13.cfgShieldR13 (shieldLyC h k hk))) (CgR (Exec.Block.DefR13.cfgShieldR13 (shieldLyC h k hk)))
      (CjR (Exec.Block.DefR13.cfgShieldR13 (shieldLyC h k hk))) (CdR (Exec.Block.DefR13.cfgShieldR13 (shieldLyC h k hk)))
      (CfR (Exec.Block.DefR13.cfgShieldR13 (shieldLyC h k hk))) :=
  Classical.choose (Classical.choose_spec (shieldRunAtC_spec h k hk).2.2.2.2)

noncomputable def shieldBC {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtC tag Pk blks Lb) (k : ℕ) (hk : k < Lb) :
    W16Pub (shieldShape (shieldLyC h k hk)) (shieldPbC h k hk) (shieldLayC h k hk) :=
  Classical.choose (Classical.choose_spec (Classical.choose_spec (shieldRunAtC_spec h k hk).2.2.2.2))

noncomputable def shieldIoInC {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtC tag Pk blks Lb) (k : ℕ) (hk : k < Lb) : ℕ :=
  Classical.choose (Classical.choose_spec (Classical.choose_spec (Classical.choose_spec (shieldRunAtC_spec h k hk).2.2.2.2)))

noncomputable def shieldIoOutC {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)}
    {Lb : ℕ} (h : ShieldRunAtC tag Pk blks Lb) (k : ℕ) (hk : k < Lb) : ℕ :=
  Classical.choose (Classical.choose_spec (Classical.choose_spec (Classical.choose_spec
    (Classical.choose_spec (shieldRunAtC_spec h k hk).2.2.2.2))))

theorem shieldBlkAtC_spec {tag : MTag} {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtC tag Pk blks Lb) (k : ℕ) (hk : k < Lb) :
    IsShieldR13 (Pk k) tag (shieldRowsOfC h k hk)
      ∧ (Pk k).define = defineS
          (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 (shieldLyC h k hk))
            (shieldIoInC h k hk) (shieldIoOutC h k hk))
          (Exec.Block.Join.R13H.Pub.pubsR13L (Exec.Block.DefR13.cfgShieldR13 (shieldLyC h k hk))
            (shieldPbC h k hk) (shieldLayC h k hk) (shieldBC h k hk) (shieldShape (shieldLyC h k hk)).nG)
      ∧ (Pk k).logCols = 14 ∧ (Pk k).endpointLogN = 14
      ∧ (Pk k).kind 3 = SlotKind.standalone ∧ (Pk k).kind 19 = SlotKind.standalone ∧ (Pk k).kind 20 = SlotKind.standalone
      ∧ (Pk k).kind 21 = SlotKind.standalone ∧ (Pk k).kind 22 = SlotKind.standalone
      ∧ (Pk k).logupSumClaim = logupSumR13 (Exec.Block.DefR13.cfgShieldR13 (shieldLyC h k hk))
      ∧ LayR (shieldLayC h k hk) :=
  Classical.choose_spec (Classical.choose_spec (Classical.choose_spec (Classical.choose_spec
    (Classical.choose_spec (shieldRunAtC_spec h k hk).2.2.2.2))))

def shieldDfltLy : ShieldLayer :=
  ⟨0, 0, 0, 0, 0, 0, 0, 0⟩

end ShieldBundleC

/-! ## 2. `polyS` congruence across `defineS` programs and across `.a`/`.h`-equal `CmData` -/

section PolyEquiv

variable {K : Type} [Field K] [Algebra GF K]

/-- **Two `defineS` representations of `P.define` have identical `polyS` on every accepted slot definition.** -/
theorem polyS_congr_define (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (P : BlockParams) (D : CmData K P)
    (prog1 prog2 : List SlotS) (pubs1 pubs2 : PubTabs)
    (hdef1 : P.define = defineS prog1 pubs1) (hdef2 : P.define = defineS prog2 pubs2)
    (k : ℕ) (sn : Seen) {df : SlotDef}
    (hok : P.define k (histSeen sn k) (drSeen sn k) = .ok df) :
    polyS U P D prog1 pubs1 k sn = polyS U P D prog2 pubs2 k sn := by
  have h1 : defineS prog1 pubs1 k (histSeen sn k) (drSeen sn k) = .ok df := hdef1 ▸ hok
  have h2 : defineS prog2 pubs2 k (histSeen sn k) (drSeen sn k) = .ok df := hdef2 ▸ hok
  obtain ⟨hcan1, hdf1⟩ := defineS_ok h1
  obtain ⟨hcan2, hdf2⟩ := defineS_ok h2
  have htabs : (prog1.getD k SlotS.empty).tabs.map
        (TabS.eval (Sym.eval (histSeen sn k) k (drSeen sn k)) (pubs1 k (histSeen sn k) (drSeen sn k)))
      = (prog2.getD k SlotS.empty).tabs.map
        (TabS.eval (Sym.eval (histSeen sn k) k (drSeen sn k)) (pubs2 k (histSeen sn k) (drSeen sn k))) :=
    (congrArg SlotDef.tabs hdf1).symm.trans (congrArg SlotDef.tabs hdf2)
  have hpoly : Exec.Slot.irEvalW ((prog1.getD k SlotS.empty).ir.map (Sym.eval (histSeen sn k) k (drSeen sn k)))
      = Exec.Slot.irEvalW ((prog2.getD k SlotS.empty).ir.map (Sym.eval (histSeen sn k) k (drSeen sn k))) :=
    (congrArg SlotDef.poly hdf1).symm.trans (congrArg SlotDef.poly hdf2)
  have hirc1 : ((prog1.getD k SlotS.empty).ir.map (Sym.eval (histSeen sn k) k (drSeen sn k))).Canon :=
    Exec.Block.Ir.canon_map _ (fun s => Sym.eval_canon hcan1 s) _
  have hirc2 : ((prog2.getD k SlotS.empty).ir.map (Sym.eval (histSeen sn k) k (drSeen sn k))).Canon :=
    Exec.Block.Ir.canon_map _ (fun s => Sym.eval_canon hcan2 s) _
  funext x
  unfold polyS
  rw [htabs]
  set w := ((prog2.getD k SlotS.empty).tabs.map
    (TabS.eval (Sym.eval (histSeen sn k) k (drSeen sn k)) (pubs2 k (histSeen sn k) (drSeen sn k)))).map
    (tabK U P D (slotShape P k).1 (slotShape P k).2.1 x)
  have hw : (w.map (ZK60.HonestClassify.ofK U hbij)).map (Fp2.toK U) = w := by
    rw [List.map_map]
    exact List.map_id'' (fun v => ZK60.HonestClassify.toK_ofK U hbij v) w
  rw [← hw, ← toK_irEvalW U hU _ hirc1, ← toK_irEvalW U hU _ hirc2, hpoly]

omit [Algebra GF K] in
theorem claimK_congr_cast (logN R1 R2 Q1 Q2 : ℕ) (hr : R1 = R2) (hq : Q1 = Q2)
    (X1 : Fin R1 → Fin (2 ^ logN + Q1) → K) (X2 : Fin R2 → Fin (2 ^ logN + Q2) → K)
    (hX : ∀ i t, X1 i t = X2 (Fin.cast hr i) (Fin.cast (congrArg (fun q => 2 ^ logN + q) hq) t))
    (ps : List (PartK K)) :
    claimK logN R1 Q1 X1 ps = claimK logN R2 Q2 X2 ps := by
  subst hr
  subst hq
  have heq : X1 = X2 := funext fun i => funext fun t => hX i t
  rw [heq]

/-- Two `CmData` bundles whose `.a` and `.h` matrices are identical up to `Fin.cast`. -/
def SameAH {P : BlockParams} (D1 D2 : CmData K P) : Prop :=
  ∀ cm, (cm = .a ∨ cm = .h) →
    ∃ (hr : D1.rows cm = D2.rows cm) (hq : D1.Q cm = D2.Q cm),
      ∀ (i : Fin (D1.rows cm)) (t : Fin (2 ^ rowLog P cm + D1.Q cm)),
        D1.X cm i t = D2.X cm (Fin.cast hr i) (Fin.cast (congrArg (fun q => 2 ^ rowLog P cm + q) hq) t)

theorem planeZ_congr_cast (U : K) (logN R1 R2 Q1 Q2 : ℕ) (hr : R1 = R2) (hq : Q1 = Q2)
    (X1 : Fin R1 → Fin (2 ^ logN + Q1) → K) (X2 : Fin R2 → Fin (2 ^ logN + Q2) → K)
    (hX : ∀ i t, X1 i t = X2 (Fin.cast hr i) (Fin.cast (congrArg (fun q => 2 ^ logN + q) hq) t))
    (p : Priv) (b : Fin p.log → Bool) :
    planeZ U logN R1 Q1 X1 p b = planeZ U logN R2 Q2 X2 p b :=
  claimK_congr_cast logN R1 R2 Q1 Q2 hr hq X1 X2 hX _

theorem aPl_congr_sameAH (U : K) (P : BlockParams) {D1 D2 : CmData K P} (h : SameAH D1 D2)
    (off log : ℕ) (b : Fin log → Bool) :
    aPl U P D1 off log b = aPl U P D2 off log b := by
  obtain ⟨hr, hq, hX⟩ := h .a (Or.inl rfl)
  exact planeZ_congr_cast U (rowLog P .a) _ _ _ _ hr hq _ _ hX ⟨.a, [(off, Fp2.one)], log, [], 0, 0⟩ b

theorem claimSem_congr_cast (U : K) (logN R1 R2 Q1 Q2 : ℕ) (hr : R1 = R2) (hq : Q1 = Q2)
    (X1 : Fin R1 → Fin (2 ^ logN + Q1) → K) (X2 : Fin R2 → Fin (2 ^ logN + Q2) → K)
    (hX : ∀ i t, X1 i t = X2 (Fin.cast hr i) (Fin.cast (congrArg (fun q => 2 ^ logN + q) hq) t))
    (z : Exec.Block.ZClaim) :
    claimSem U R1 logN Q1 X1 z = claimSem U R2 logN Q2 X2 z := by
  subst hr
  subst hq
  have heq : X1 = X2 := funext fun i => funext fun t => hX i t
  rw [heq]

theorem tabK_congr_sameAH (U : K) (P : BlockParams) {D1 D2 : CmData K P} (h : SameAH D1 D2)
    (n e : ℕ) {N : ℕ} (x : Fin N → K) (t : Exec.Block.Tab)
    (ht : ∀ p, t = .priv p → p.cm = .a ∨ p.cm = .h) :
    tabK U P D1 n e x t = tabK U P D2 n e x t := by
  cases t with
  | eq _ _ => rfl
  | pub _ => rfl
  | priv p =>
    obtain ⟨hr, hq, hX⟩ := h p.cm (ht p rfl)
    exact claimK_congr_cast (rowLog P p.cm) _ _ _ _ hr hq _ _ hX _

theorem cmCountS_zero_no_cm (cm : Cm) : ∀ (ts : List TabS),
    Exec.Block.cmCountS cm ts = 0 → ∀ p, TabS.priv p ∈ ts → p.cm ≠ cm
  | [], _, _, hp => by simp at hp
  | .priv p' :: ts, h0, p, hp => by
    simp only [Exec.Block.cmCountS] at h0
    have hne : p'.cm ≠ cm := by
      intro he
      rw [he, ite_eq_left rfl] at h0
      omega
    rcases List.mem_cons.mp hp with hEq | hmem
    · cases hEq; exact hne
    · exact cmCountS_zero_no_cm cm ts (by split_ifs at h0 <;> omega) p hmem
  | .eq _ _ :: ts, h0, p, hp => by
    rcases List.mem_cons.mp hp with hEq | hmem
    · cases hEq
    · exact cmCountS_zero_no_cm cm ts h0 p hmem
  | .pub _ :: ts, h0, p, hp => by
    rcases List.mem_cons.mp hp with hEq | hmem
    · cases hEq
    · exact cmCountS_zero_no_cm cm ts h0 p hmem

theorem progR13_shield_cntInp (ioIn ioOut : ℕ) : ∀ Ly ∈ shieldExport,
    (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).map
      (fun sl => Exec.Block.cmCountS .inp sl.tabs) = List.replicate 21 0 ++ [1, 0] := by
  intro Ly hLy
  rw [Exec.Block.DefR13.progR13_cm]
  revert Ly
  decide +kernel

theorem progR13_shield_cntOut (ioIn ioOut : ℕ) : ∀ Ly ∈ shieldExport,
    (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).map
      (fun sl => Exec.Block.cmCountS .out sl.tabs) = List.replicate 22 0 ++ [1] := by
  intro Ly hLy
  rw [Exec.Block.DefR13.progR13_cm]
  revert Ly
  decide +kernel

theorem getD_replicate_zero_append : ∀ (n : ℕ) (l : List ℕ) (s : ℕ), s < n →
    (List.replicate n 0 ++ l).getD s 0 = 0
  | 0, _, _, hs => absurd hs (Nat.not_lt_zero _)
  | _ + 1, _, 0, _ => rfl
  | n + 1, l, s + 1, hs => getD_replicate_zero_append n l s (Nat.lt_of_succ_lt_succ hs)

theorem progR13_no_io (Ly : ShieldLayer) (hLy : Ly ∈ shieldExport) (ioIn ioOut s : ℕ) (hs : s < 21) :
    Exec.Block.cmCountS .inp
        ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty).tabs = 0
      ∧ Exec.Block.cmCountS .out
        ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty).tabs = 0 := by
  have ei := Exec.Block.getD_map_dflt (fun sl : SlotS => Exec.Block.cmCountS .inp sl.tabs) SlotS.empty
    (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut) s
  have eo := Exec.Block.getD_map_dflt (fun sl : SlotS => Exec.Block.cmCountS .out sl.tabs) SlotS.empty
    (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut) s
  exact ⟨ei.symm.trans ((congrArg (fun l : List ℕ => l.getD s 0) (progR13_shield_cntInp ioIn ioOut Ly hLy)).trans
      (getD_replicate_zero_append 21 [1, 0] s hs)),
    eo.symm.trans ((congrArg (fun l : List ℕ => l.getD s 0) (progR13_shield_cntOut ioIn ioOut Ly hLy)).trans
      (getD_replicate_zero_append 22 [1] s (by omega)))⟩

/-- **Slots `0..20` of Shieldstral `progR13` read only `.a` and `.h`, so `polyS` agrees across `SameAH D1 D2`.** -/
theorem polyS_congr_ah (U : K) (P : BlockParams) {D1 D2 : CmData K P} (h : SameAH D1 D2)
    (Ly : ShieldLayer) (hLy : Ly ∈ shieldExport) (ioIn ioOut : ℕ) (pubs : PubTabs) (s : ℕ) (hs : s < 21)
    (sn : Seen) :
    polyS U P D1 (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs s sn
      = polyS U P D2 (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs s sn := by
  obtain ⟨hinp, hout⟩ := progR13_no_io Ly hLy ioIn ioOut s hs
  funext x
  unfold polyS
  congr 1
  rw [List.map_map, List.map_map]
  refine List.map_congr_left (fun ts hts => ?_)
  simp only [Function.comp_apply]
  refine tabK_congr_sameAH U P h _ _ x _ (fun p hp => ?_)
  cases ts with
  | eq _ _ => cases hp
  | pub _ => cases hp
  | priv ps =>
    simp only [TabS.eval, Exec.Block.Tab.priv.injEq] at hp
    have hcm : p.cm = ps.cm := by rw [← hp]; rfl
    have hni := cmCountS_zero_no_cm .inp _ hinp ps hts
    have hno := cmCountS_zero_no_cm .out _ hout ps hts
    rw [hcm]
    cases hps : ps.cm with
    | a => exact Or.inl rfl
    | h => exact Or.inr rfl
    | inp => exact absurd hps hni
    | out => exact absurd hps hno

/-- **`dArgs` at R13 `A`/`H` openings (`rkR13 4577`, `rkR13 4390`) satisfies `SameAH` with `dXof` (`encGL_14`).** -/
theorem dArgs_sameAH_dXof (U : K) (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq)
    (P : BlockParams) (hlc : P.logCols = 14)
    (iposA nA vposA iposH nH vposH : ℕ)
    (clrA clrH : List (TItem × Dig) → List Exec.Block.ZClaim)
    (oI oO : RtOpen K Lq)
    (hoA : (rkOpen U tag Lq h64 key domain hs hL (rkR13 4577 iposA) nA clrA vposA).lc = rowLog P .a)
    (hoH : (rkOpen U tag Lq h64 key domain hs hL (rkR13 4390 iposH) nH clrH vposH).lc = rowLog P .h)
    (hoI : oI.lc = rowLog P .inp) (hoO : oO.lc = rowLog P .out)
    (rE QE : Cm → ℕ) (XE : Cuts3 Lq → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (cu : Cuts3 Lq) (rt : RootsO) (hx : HdrX Lq) (pi po : ℕ) :
    SameAH (dArgs tag Lq h64 P
        (rkOpen U tag Lq h64 key domain hs hL (rkR13 4577 iposA) nA clrA vposA)
        (rkOpen U tag Lq h64 key domain hs hL (rkR13 4390 iposH) nH clrH vposH)
        oI oO hoA hoH hoI hoO cu rt hx pi po)
      (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) := by
  intro cm hcm
  rcases hcm with rfl | rfl
  · refine ⟨rfl, rfl, fun i t => ?_⟩
    dsimp only [dArgs, rowsOfArgs, qOfArgs, bndTab, rkOpen, rkR13, ogR13, Exec.Block.dXof, Exec.Block.rowsOfX,
      Exec.Block.qOfX, Exec.Block.xOfX, Link.xAof, Exec.Block.colCast]
    rw [encGL_14 16 256]
    exact congrArg₂ _ (Fin.ext rfl) (Fin.ext rfl)
  · refine ⟨rfl, rfl, fun i t => ?_⟩
    dsimp only [dArgs, rowsOfArgs, qOfArgs, bndTab, rkOpen, rkR13, ogR13, Exec.Block.dXof, Exec.Block.rowsOfX,
      Exec.Block.qOfX, Exec.Block.xOfX, Link.xHof, Exec.Block.colCast]
    rw [encGL_14 16 256]
    exact congrArg₂ _ (Fin.ext rfl) (Fin.ext rfl)

end PolyEquiv

/-! ## 3. Concrete boundary plane reader (`bndPl`, `L62-2`) and `formAt_ioDefSchedB` (`L62-4`) + `ioDefSchedB_indDeg` -/

section BoundaryIO

variable {K : Type} [Field K] [Algebra GF K]

/-- **Concrete boundary plane reader (`L62-2`)**: reads the `(0, 1)` data slice of log size `n` from `bndTab` at header
position `p`. Note: the `Priv` record carries `.inp` for both incoming and outgoing reads because `privZ` inside `planeZ`
ignores `p.cm` (`BlockJoinCube.lean:193`), while `ShieldBlkIO` supplies the respective opening `D.opX (k + 1)` or
`D.opX (k + 2)`. -/
noncomputable def bndPl (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (o : RtOpen K Lq) (p n : ℕ)
    (hx : HdrX Lq) (b : Fin n → Bool) : K :=
  planeZ U o.lc o.rows o.Q (bndTab tag Lq h64 o (hx p)) ⟨.inp, [(0, Fp2.one)], n, [], 0, 0⟩ b

omit [Algebra GF K] in
theorem eqPoly_eq_eqB {n : ℕ} (τ : Fin n → K) (b : Fin n → Bool) :
    eqPoly τ (fun a => bit (b a)) = eqB τ b := by
  unfold eqPoly eqB
  refine Finset.prod_congr rfl (fun a _ => ?_)
  dsimp only
  cases b a <;> simp [eq1, bit]

omit [Algebra GF K] in
theorem eq1_affAt {N : ℕ} (j : Fin N) (i : Fin N) (bit : Bool) :
    Exec.Block.AffAt j (fun y : Fin N → K => eq1 (y i) bit) := by
  cases bit
  · exact (Exec.Block.constAt_const j (1 : K)).affAt.sub (Exec.Block.affAt_coord j i)
  · exact Exec.Block.affAt_coord j i

omit [Algebra GF K] in
theorem eq1_constAt {N : ℕ} (j : Fin N) (i : Fin N) (hne : j ≠ i) (bit : Bool) :
    Exec.Block.ConstAt j (fun y : Fin N → K => eq1 (y i) bit) := by
  cases bit
  · exact (Exec.Block.constAt_const j (1 : K)).sub (Exec.Block.constAt_coord j i hne.symm)
  · exact Exec.Block.constAt_coord j i hne.symm

omit [Algebra GF K] in
theorem eqB_indDeg {N n : ℕ} (hn : n ≤ N) (b : Fin n → Bool) (c : K) :
    IndDegLE 1 (fun y : Fin N → K => eqB (fun a : Fin n => y ⟨a.1, Nat.lt_of_lt_of_le a.2 hn⟩) b * c) := by
  refine IndDegLE_mulc ?_ c
  refine Exec.Block.indDegLE_one_of_affAt (fun j => ?_)
  unfold eqB
  by_cases hj : j.1 < n
  · refine Exec.Block.AffAt.prod_one
      (fun (a : Fin n) (y : Fin N → K) => eq1 (y ⟨a.1, Nat.lt_of_lt_of_le a.2 hn⟩) (b a))
      ⟨j.1, hj⟩ (eq1_affAt j _ (b ⟨j.1, hj⟩)) (fun a hne => ?_)
    refine eq1_constAt j _ ?_ (b a)
    intro he
    exact hne (Fin.ext (congrArg Fin.val he).symm)
  · exact (Exec.Block.ConstAt.prod _ (fun a => eq1_constAt j _ (by
      intro he
      have hv := congrArg Fin.val he
      dsimp only at hv
      omega) (b a))).affAt

omit [Algebra GF K] in
/-- **`ioDefSchedB.Φ` has individual degree at most `1` (`defSqB_rbr`).** -/
theorem ioDefSchedB_indDeg {Lq : ℕ} (P : BlockParams) (n : ℕ) (h21 : n ≤ P.draws 21) (h22 : n ≤ P.draws 22)
    (aIn aOut : Cuts3 Lq → RootsO → (Fin n → Bool) → K)
    (bIn bOut : HdrX Lq → (Fin n → Bool) → K)
    (cu : Cuts3 Lq) (rt : RootsO) (hx : HdrX Lq) (s : ℕ) (h : Hist) :
    IndDegLE 1 ((ioDefSchedB P n h21 h22 aIn aOut bIn bOut).Φ cu rt hx s h) := by
  unfold ioDefSchedB
  dsimp only
  split_ifs with hs21 hs22
  · exact indDegLE_finset_sum Finset.univ _ (fun b _ => eqB_indDeg (hs21 ▸ h21) b _)
  · exact indDegLE_finset_sum Finset.univ _ (fun b _ => eqB_indDeg (hs22 ▸ h22) b _)
  · exact IndDegLE.const 0

theorem tabK_ep_cpt (U : K) (P : BlockParams) (D : CmData K P) (cm : Cm) (n e m : ℕ) (hn : 0 < n)
    (hrl : 0 < rowLog P cm) (b : Fin n → Bool) :
    tabK U P D n e (cpt n e b) (.priv ⟨cm, [(0, Fp2.one)], n, (Exec.Block.DefW16.rhoC 0 n).map (CoordS.eval
      (fun _ => Fp2.zero)), m, 0⟩)
      = planeZ U (rowLog P cm) (D.rows cm) (D.Q cm) (D.X cm) ⟨.inp, [(0, Fp2.one)], n, [], 0, 0⟩ b := by
  have hsl : ([(0, Fp2.one)] : List (ℕ × Fp2)) ≠ [] := List.cons_ne_nil _ _
  rw [tabK_priv_cpt U P D n e b _ hsl hn hrl]
  have hpt : (fun a : Fin n => ptK U (xrK n (cpt (K := K) n e b))
      ((Exec.Block.DefW16.rhoC 0 n).map (CoordS.eval (fun _ => Fp2.zero))) a)
      = (fun a : Fin n => bit (b a)) := by
    funext a
    unfold Exec.Block.DefW16.rhoC ptK
    rw [Nat.sub_zero, List.map_map, List.getElem?_map, List.getElem?_range' a.isLt]
    simp only [Nat.zero_add, Nat.one_mul, Function.comp_apply, CoordS.eval, Exec.Block.coordK, Option.map_some,
      Option.getD_some, Exec.Block.Join.xrK_cpt, dite_eq_left a.isLt]
  rw [hpt, mleAt_bit]
  rfl

theorem planeZ_congr_lc (U : K) {lc1 lc2 R Q : ℕ} (hlc : lc1 = lc2)
    (hcast : 2 ^ lc2 + Q = 2 ^ lc1 + Q)
    (X : Fin R → Fin (2 ^ lc1 + Q) → K) (p : Priv) (b : Fin p.log → Bool) :
    planeZ U lc2 R Q (fun i t => X i (Fin.cast hcast t)) p b
      = planeZ U lc1 R Q X p b := by
  subst hlc
  rfl

theorem planeZ_dArgs_inp (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (P : BlockParams)
    (oA oH oI oO : RtOpen K Lq)
    (hoA : oA.lc = rowLog P .a) (hoH : oH.lc = rowLog P .h)
    (hoI : oI.lc = rowLog P .inp) (hoO : oO.lc = rowLog P .out)
    (cu : Cuts3 Lq) (rt : RootsO) (hx : HdrX Lq) (pi po n : ℕ) (b : Fin n → Bool) :
    planeZ U (rowLog P .inp)
        ((dArgs tag Lq h64 P oA oH oI oO hoA hoH hoI hoO cu rt hx pi po).rows .inp)
        ((dArgs tag Lq h64 P oA oH oI oO hoA hoH hoI hoO cu rt hx pi po).Q .inp)
        ((dArgs tag Lq h64 P oA oH oI oO hoA hoH hoI hoO cu rt hx pi po).X .inp)
        ⟨.inp, [(0, Fp2.one)], n, [], 0, 0⟩ b
      = bndPl U tag Lq h64 oI pi n hx b := by
  unfold bndPl dArgs rowsOfArgs qOfArgs
  dsimp only
  exact planeZ_congr_lc U hoI _ _ ⟨.inp, [(0, Fp2.one)], n, [], 0, 0⟩ b

theorem planeZ_dArgs_out (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (P : BlockParams)
    (oA oH oI oO : RtOpen K Lq)
    (hoA : oA.lc = rowLog P .a) (hoH : oH.lc = rowLog P .h)
    (hoI : oI.lc = rowLog P .inp) (hoO : oO.lc = rowLog P .out)
    (cu : Cuts3 Lq) (rt : RootsO) (hx : HdrX Lq) (pi po n : ℕ) (b : Fin n → Bool) :
    planeZ U (rowLog P .out)
        ((dArgs tag Lq h64 P oA oH oI oO hoA hoH hoI hoO cu rt hx pi po).rows .out)
        ((dArgs tag Lq h64 P oA oH oI oO hoA hoH hoI hoO cu rt hx pi po).Q .out)
        ((dArgs tag Lq h64 P oA oH oI oO hoA hoH hoI hoO cu rt hx pi po).X .out)
        ⟨.inp, [(0, Fp2.one)], n, [], 0, 0⟩ b
      = bndPl U tag Lq h64 oO po n hx b := by
  unfold bndPl dArgs rowsOfArgs qOfArgs
  dsimp only
  exact planeZ_congr_lc U hoO _ _ ⟨.inp, [(0, Fp2.one)], n, [], 0, 0⟩ b

theorem ioR_cube (U : K) (P : BlockParams) (D : CmData K P) (cm : Cm)
    (hrlA : 0 < rowLog P .a) (hrlE : 0 < rowLog P cm)
    (s n e off mA mE : ℕ) (hn : 0 < n) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = Exec.Slot.irEval
      (((Exec.Slot.Build.ioIr Exec.Block.DefW16.cstS 0 1 2).map (Sym.eval hist s dr)).map (Fp2.toK U))
      (([TabS.eq (drH s 0 n) 0,
          TabS.priv ⟨.a, [(off, false)], n, Exec.Block.DefW16.rhoC 0 n, mA, 0⟩,
          TabS.priv ⟨cm, [(0, false)], n, Exec.Block.DefW16.rhoC 0 n, mE, 0⟩].map
        (TabS.eval (Sym.eval hist s dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin n → Bool,
      eqB (fun a : Fin n => (dr.getD a.1 Fp2.zero).toK U) b
        * (aPl U P D off n b
            - planeZ U (rowLog P cm) (D.rows cm) (D.Q cm) (D.X cm) ⟨.inp, [(0, Fp2.one)], n, [], 0, 0⟩ b) := by
  have hir : ∀ v : List K, Exec.Slot.irEval
      (((Exec.Slot.Build.ioIr Exec.Block.DefW16.cstS 0 1 2).map (Sym.eval hist s dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * (v.getD 1 0 - v.getD 2 0) := by
    intro v
    rw [Exec.Slot.Compose.ioIr_map, Exec.Slot.Compose.ioIr_map, Exec.Block.Join.W16.cstS_map,
      Exec.Slot.Build.ioIr_eval _ (Exec.Slot.Compose.cstW_map_std U)]
  have heqDr : eqPoly (fun a : Fin n => (((drH s 0 n).map (Sym.eval hist s dr)).getD a.1 Fp2.zero).toK U)
      = eqPoly (fun a : Fin n => (dr.getD a.1 Fp2.zero).toK U) := by
    congr 1
    funext a
    rw [List.getD_eq_getElem?_getD, List.getElem?_map]
    unfold drH
    rw [List.getElem?_map, List.getElem?_range a.isLt]
    simp [Sym.eval, Exec.Block.drawAt, List.getD_eq_getElem?_getD]
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt n e b) = _
    rw [hf, hir]
    have hlen : ((drH s 0 n).map (Sym.eval hist s dr)).length = n := drH_length (Sym.eval hist s dr) s 0 n
    have heqT : tabK U P D n e (cpt n e b) (TabS.eval (Sym.eval hist s dr) pub (TabS.eq (drH s 0 n) 0))
        = eqB (fun a : Fin n => (dr.getD a.1 Fp2.zero).toK U) b := by
      show tabK U P D n e (cpt n e b) (.eq ((drH s 0 n).map (Sym.eval hist s dr)) 0) = _
      rw [tabK_eqFull_cpt U P D n e b _ hlen, heqDr, eqPoly_eq_eqB]
    have haT : tabK U P D n e (cpt n e b)
        (TabS.eval (Sym.eval hist s dr) pub (TabS.priv ⟨.a, [(off, false)], n, Exec.Block.DefW16.rhoC 0 n, mA, 0⟩))
        = aPl U P D off n b := by
      rw [aTab_eval, tabK_rho_cpt U P D n e b _ (List.cons_ne_nil _ _) hn hrlA rfl le_rfl, planeZ_aPl]
    have heT : tabK U P D n e (cpt n e b)
        (TabS.eval (Sym.eval hist s dr) pub (TabS.priv ⟨cm, [(0, false)], n, Exec.Block.DefW16.rhoC 0 n, mE, 0⟩))
        = planeZ U (rowLog P cm) (D.rows cm) (D.Q cm) (D.X cm) ⟨.inp, [(0, Fp2.one)], n, [], 0, 0⟩ b := by
      have hcoord : (Exec.Block.DefW16.rhoC 0 n).map (CoordS.eval (Sym.eval hist s dr))
          = (Exec.Block.DefW16.rhoC 0 n).map (CoordS.eval (fun _ => Fp2.zero)) := by
        unfold Exec.Block.DefW16.rhoC
        rw [List.map_map, List.map_map]
        rfl
      simp only [TabS.eval, Exec.Block.PrivS.eval, List.map_cons, List.map_nil, Bool.false_eq_true, ↓reduceIte]
      rw [hcoord, tabK_ep_cpt U P D cm n e mE hn hrlE b]
    simp only [List.map_cons, List.map_nil, List.getD_cons_zero, List.getD_cons_succ]
    rw [heqT, haT, heT]
  · show f (bpt n e b y) = 0
    rw [hf, hir]
    simp only [List.map_cons, TabS.eval, List.getD_cons_zero]
    rw [tabK_eq_off U P D n e b y hy, zero_mul]

theorem rawSlot21_shield (Ly : ShieldLayer) :
    Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) 21
      = ⟨[TabS.eq (drH 21 0 19) 0,
          TabS.priv ⟨.a, [(offR (Exec.Block.DefR13.cfgShieldR13 Ly) 8, false)], 19,
            Exec.Block.DefW16.rhoC 0 19, 0, 0⟩,
          TabS.priv ⟨.inp, [(0, false)], 19, Exec.Block.DefW16.rhoC 0 19, 0, 0⟩],
        Exec.Slot.Build.ioIr Exec.Block.DefW16.cstS 0 1 2, [], []⟩ := rfl

theorem rawSlot22_shield (Ly : ShieldLayer) :
    Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) 22
      = ⟨[TabS.eq (drH 22 0 19) 0,
          TabS.priv ⟨.a, [(offR (Exec.Block.DefR13.cfgShieldR13 Ly) 44, false)], 19,
            Exec.Block.DefW16.rhoC 0 19, 0, 0⟩,
          TabS.priv ⟨.out, [(0, false)], 19, Exec.Block.DefW16.rhoC 0 19, 0, 0⟩],
        Exec.Slot.Build.ioIr Exec.Block.DefW16.cstS 0 1 2, [], []⟩ := rfl

theorem shieldSlots_21_22 (P : BlockParams) (hsl : P.geom.slots = Exec.Block.R13.shieldSlots) :
    (slotShape P 21).1 = 19 ∧ (slotShape P 22).1 = 19 := by
  simp only [slotShape, hsl]
  decide

/-- **`FormAt` for `ioDefSchedB` (`L62-4`)**: on `dArgs` with R13 `A`/`H` openings, slots `21` (`SC_IO_IN`) and `22`
(`SC_IO_OUT`) have `ioDefSchedB`'s polynomial (over `dXof`'s `A` planes and `bndPl`) as their standalone unmasked sum. -/
theorem formAt_ioDefSchedB {Lq : ℕ} (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq)
    (Ly : ShieldLayer) (P : BlockParams) (rowsOf : Cm → ℕ) (hP : IsShieldR13 P tag rowsOf)
    (hlc : P.logCols = 14) (hep14 : P.endpointLogN = 14)
    (hk21 : P.kind 21 = SlotKind.standalone) (hk22 : P.kind 22 = SlotKind.standalone)
    (ioIn ioOut : ℕ) (pubs : PubTabs)
    (iposA nA vposA iposH nH vposH : ℕ) (clrA clrH : List (TItem × Dig) → List Exec.Block.ZClaim)
    (oI oO : RtOpen K Lq)
    (hoA : (rkOpen U tag Lq h64 key domain hs hL (rkR13 4577 iposA) nA clrA vposA).lc = rowLog P .a)
    (hoH : (rkOpen U tag Lq h64 key domain hs hL (rkR13 4390 iposH) nH clrH vposH).lc = rowLog P .h)
    (hoI : oI.lc = rowLog P .inp) (hoO : oO.lc = rowLog P .out)
    (rE QE : Cm → ℕ) (XE : Cuts3 Lq → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (cu : Cuts3 Lq) (rt : RootsO) (hx : HdrX Lq) (pi po : ℕ)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    ∀ s ∈ [21, 22],
      FormAt U P
        (polyS U P (dArgs tag Lq h64 P
            (rkOpen U tag Lq h64 key domain hs hL (rkR13 4577 iposA) nA clrA vposA)
            (rkOpen U tag Lq h64 key domain hs hL (rkR13 4390 iposH) nH clrH vposH)
            oI oO hoA hoH hoI hoO cu rt hx pi po)
          (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs)
        (fun s' h => (ioDefSchedB P (nD (Exec.Block.DefR13.cfgShieldR13 Ly))
          (shield_draws_21 Ly P hP.hdr) (shield_draws_22 Ly P hP.hdr)
          (fun cu' rt' b => aPl U P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt')
            (offR (Exec.Block.DefR13.cfgShieldR13 Ly) 8) (nD (Exec.Block.DefR13.cfgShieldR13 Ly)) b)
          (fun cu' rt' b => aPl U P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt')
            (offR (Exec.Block.DefR13.cfgShieldR13 Ly) 44) (nD (Exec.Block.DefR13.cfgShieldR13 Ly)) b)
          (bndPl U tag Lq h64 oI pi (nD (Exec.Block.DefR13.cfgShieldR13 Ly)))
          (bndPl U tag Lq h64 oO po (nD (Exec.Block.DefR13.cfgShieldR13 Ly)))).Φ cu rt hx s' h)
        bga rs s := by
  have hsame := dArgs_sameAH_dXof U tag h64 hL20 key domain hs hL P hlc iposA nA vposA iposH nH vposH clrA clrH
    oI oO hoA hoH hoI hoO rE QE XE cu rt hx pi po
  have hrlA : 0 < rowLog P .a := by show 0 < P.logCols; rw [hlc]; norm_num
  have hrlI : 0 < rowLog P .inp := by show 0 < P.endpointLogN; rw [hep14]; norm_num
  have hrlO : 0 < rowLog P .out := by show 0 < P.endpointLogN; rw [hep14]; norm_num
  have hn19 : nD (Exec.Block.DefR13.cfgShieldR13 Ly) = 19 := rfl
  obtain ⟨hs21, hs22⟩ := shieldSlots_21_22 P hP.hsl
  intro s hs
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hs
  rcases hs with rfl | rfl
  · intro r df hr _
    refine Or.inl ⟨hk21, ?_⟩
    obtain ⟨ak, hk, hslot⟩ := progR13_slotH (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut 21 (by norm_num)
    unfold spSum
    have hc := ioR_cube U P
      (dArgs tag Lq h64 P
        (rkOpen U tag Lq h64 key domain hs hL (rkR13 4577 iposA) nA clrA vposA)
        (rkOpen U tag Lq h64 key domain hs hL (rkR13 4390 iposH) nH clrH vposH)
        oI oO hoA hoH hoI hoO cu rt hx pi po)
      .inp hrlA hrlI 21 (slotShape P 21).1 (slotShape P 21).2.1
      (offR (Exec.Block.DefR13.cfgShieldR13 Ly) 8)
      (Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 Ly) + 2 * ak) ioIn
      (by omega) (histOf bga.1 bga.2.1 bga.2.2 (rs.take 21)) r.draws
      (pubs 21 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 21)) r.draws)
      (polyS U P _ (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs 21
        (seenOf bga rs 21))
      (fun x => by
        rw [polyS_seenOf U P _ _ _ bga rs 21 r hr x, hslot, rawSlot21_shield]
        congr 2
        rw [hs21]
        rfl)
    rw [hc, hs21]
    unfold ioDefSchedB
    simp only [↓reduceDIte]
    rw [hn19]
    refine Finset.sum_congr rfl (fun b _ => ?_)
    rw [aPl_congr_sameAH U P hsame, planeZ_dArgs_inp]
  · intro r df hr _
    refine Or.inl ⟨hk22, ?_⟩
    obtain ⟨ak, hk, hslot⟩ := progR13_slotH (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut 22 (by norm_num)
    unfold spSum
    have hc := ioR_cube U P
      (dArgs tag Lq h64 P
        (rkOpen U tag Lq h64 key domain hs hL (rkR13 4577 iposA) nA clrA vposA)
        (rkOpen U tag Lq h64 key domain hs hL (rkR13 4390 iposH) nH clrH vposH)
        oI oO hoA hoH hoI hoO cu rt hx pi po)
      .out hrlA hrlO 22 (slotShape P 22).1 (slotShape P 22).2.1
      (offR (Exec.Block.DefR13.cfgShieldR13 Ly) 44)
      (Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 Ly) + 2 * ak) ioOut
      (by omega) (histOf bga.1 bga.2.1 bga.2.2 (rs.take 22)) r.draws
      (pubs 22 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 22)) r.draws)
      (polyS U P _ (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs 22
        (seenOf bga rs 22))
      (fun x => by
        rw [polyS_seenOf U P _ _ _ bga rs 22 r hr x, hslot, rawSlot22_shield]
        congr 2
        rw [hs22]
        rfl)
    rw [hc, hs22]
    have hne : ¬ (22 = 21) := by decide
    unfold ioDefSchedB
    simp only [hne, ↓reduceDIte]
    rw [hn19]
    refine Finset.sum_congr rfl (fun b _ => ?_)
    rw [aPl_congr_sameAH U P hsame, planeZ_dArgs_out]

end BoundaryIO

/-! ## 4. Concrete block squeeze lists (`BlkLists`) and full 6-conjunct `RkSqOk` certificates -/

section BlkSqueezeLists

def rE0 : Cm → ℕ := fun _ => 0
def QE0 : Cm → ℕ := fun _ => 0
def XE0 {K : Type} {L : ℕ} {P : BlockParams} :
    Cuts3 L → RootsO → (cm : Cm) → Fin (rE0 cm) → Fin (2 ^ rowLog P cm + QE0 cm) → K :=
  fun _ _ _ i => Fin.elim0 i

section FixedLayer

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}

noncomputable def blkDof (tag : MTag) (hL20 : 2 ^ 20 ≤ Lq) (P : BlockParams) (hlc : P.logCols = 14) :
    Cuts3 Lq → RootsO → CmData K P :=
  fun cu rt => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE0 QE0 XE0 cu rt

noncomputable def blkAlgDt (U : K) (tag : MTag) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws) (hlc : P.logCols = 14)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay) :
    Exec.Block.AlgData K Lq (algShapeR (Exec.Block.DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hdr)) :=
  dtR (geoShield Ly) Pb Lay B P (shOk_shield Ly P hdr)
    (fun cu' rt' => xtR U (Exec.Block.DefR13.cfgShieldR13 Ly) P (blkDof tag hL20 P hlc cu' rt') 1)
    (perRow_shield Ly)
    (xcR U (geoShield Ly) P (blkDof tag hL20 P hlc) Pb Lay B)
    (pwcR U (geoShield Ly) P (blkDof tag hL20 P hlc) Pb Lay B)

noncomputable def blkRelSq (U : K) (tag : MTag) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws) (hlc : P.logCols = 14)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay)
    (hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8)) (i s : ℕ) : SqX K Lq :=
  defSqB P hdrLen absOf
    (fun cu rt _ s' h =>
      (w16r2DR P (algSp U
        (algShapeR (Exec.Block.DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hdr))
        (blkAlgDt U tag hL20 Ly P hdr hlc Pb Lay B) (card_K_gt K)) i).Φ cu rt s' h)
    (fun _ => 80) s

noncomputable def blkHelpSq (U : K) (tag : MTag) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws)
    (hsl : P.geom.slots = Exec.Block.R13.shieldSlots) (hlc : P.logCols = 14)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay)
    (hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8)) (s : ℕ) : SqX K Lq :=
  defSqB P hdrLen absOf
    (fun cu rt _ s' h =>
      (w16r2DH P (spHR U (card_K_gt K) (Exec.Block.DefR13.cfgShieldR13 Ly) P (helpProf_shield P hdr hsl)
        (algShapeR (Exec.Block.DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hdr))
        (blkAlgDt U tag hL20 Ly P hdr hlc Pb Lay B) (blkDof tag hL20 P hlc)
        (Exec.Block.Join.R13H.Pub.gateLS (Exec.Block.DefR13.cfgShieldR13 Ly).sh)
        Pb.exp Pb.act (shieldShape Ly).nG) 0).Φ cu rt s' h)
    (fun _ => 80) s

noncomputable def blkIoSq (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws) (hlc : P.logCols = 14)
    (oI oO : RtOpen K Lq) (pi po hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8)) (s : ℕ) : SqX K Lq :=
  defSqB P hdrLen absOf
    (ioDefSchedB P (nD (Exec.Block.DefR13.cfgShieldR13 Ly))
      (shield_draws_21 Ly P hdr) (shield_draws_22 Ly P hdr)
      (fun cu' rt' b => aPl U P (blkDof tag hL20 P hlc cu' rt')
        (offR (Exec.Block.DefR13.cfgShieldR13 Ly) 8) (nD (Exec.Block.DefR13.cfgShieldR13 Ly)) b)
      (fun cu' rt' b => aPl U P (blkDof tag hL20 P hlc cu' rt')
        (offR (Exec.Block.DefR13.cfgShieldR13 Ly) 44) (nD (Exec.Block.DefR13.cfgShieldR13 Ly)) b)
      (bndPl U tag Lq h64 oI pi (nD (Exec.Block.DefR13.cfgShieldR13 Ly)))
      (bndPl U tag Lq h64 oO po (nD (Exec.Block.DefR13.cfgShieldR13 Ly)))).Φ
    (fun _ => 1) s

/-- **Concrete `r0` list for block `k + 1`**: `w16r2RelKs 0` (`[2, 3, 14..20]`) followed by `[21, 22]` (`ioDefSchedB`). -/
noncomputable def blkR0 (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws) (hlc : P.logCols = 14)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay)
    (oI oO : RtOpen K Lq) (pi po hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8)) : List (SqX K Lq) :=
  (w16r2RelKs 0).map (blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf 0)
    ++ [21, 22].map (blkIoSq U tag h64 hL20 Ly P hdr hlc oI oO pi po hdrLen absOf)

/-- **Concrete `r1` list for block `k + 1`**: `w16r2RelKs 1` (`[0, 1, 4..13]`). -/
noncomputable def blkR1 (U : K) (tag : MTag) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws) (hlc : P.logCols = 14)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay)
    (hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8)) : List (SqX K Lq) :=
  (w16r2RelKs 1).map (blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf 1)

/-- **Concrete `h0` list for block `k + 1`**: `w16r2RelKs 2` (`[5, 11]`) and `w16r2RelKs 3` (`[5]`), ordered by window
`[5 (layer 2), 5 (layer 3), 11 (layer 2)]` so `Pairwise (a ≤ a)` holds. -/
noncomputable def blkH0 (U : K) (tag : MTag) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws) (hlc : P.logCols = 14)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay)
    (hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8)) : List (SqX K Lq) :=
  [blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf 2 5,
    blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf 3 5,
    blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf 2 11]

/-- **Concrete `h1` list for block `k + 1`**: `w16r2DH` (`w16r2RelKs 0` on `spHR`). -/
noncomputable def blkH1 (U : K) (tag : MTag) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws)
    (hsl : P.geom.slots = Exec.Block.R13.shieldSlots) (hlc : P.logCols = 14)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay)
    (hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8)) : List (SqX K Lq) :=
  (w16r2RelKs 0).map (blkHelpSq U tag hL20 Ly P hdr hsl hlc Pb Lay B hdrLen absOf)

/-- **Concrete `lu` list for block `k + 1`**: `[lkSqB hdrLen absOf AlkR13B TR13 mlkR13B]`. -/
noncomputable def blkLU (U : K) (tag : MTag) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hlc : P.logCols = 14)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay)
    (hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8)) : List (SqX K Lq) :=
  [lkSqB hdrLen absOf
    (AlkR13B U (Exec.Block.DefR13.cfgShieldR13 Ly) P Pb Lay B (geoShield Ly)
      (dofARB tag hL20 P hlc 16 256 24448 4577 4390 rE0 QE0 XE0))
    (TR13 (K := K) Pb.exp Pb.act (shieldShape Ly).nG)
    (mlkR13B U (Exec.Block.DefR13.cfgShieldR13 Ly) P
      (dofARB tag hL20 P hlc 16 256 24448 4577 4390 rE0 QE0 XE0))]

/-- **`StgLists` counterpart for a Shieldstral block part `base (k + 1)`**: pins `r0`, `r1`, `h0`, `h1`, `lu`. -/
structure BlkLists (b : RkPart K Lq) (r0 r1 h0 h1 lu : List (SqX K Lq)) : Prop where
  hr0 : b.r0 = r0
  hr1 : b.r1 = r1
  hh0 : b.h0 = h0
  hh1 : b.h1 = h1
  hlu : b.lu = lu

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem shieldDraws_le_451 : ∀ s, s < 23 → Exec.Block.R13.shieldDraws s ≤ 451 := by decide

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem defOff_mono (P : BlockParams) (j : ℕ) : ∀ {m1 m2 : ℕ}, m1 ≤ m2 → defOff P j m1 ≤ defOff P j m2
  | 0, _, _ => Nat.zero_le _
  | m1 + 1, 0, h => by omega
  | m1 + 1, m2 + 1, h => by
    unfold defOff
    exact Nat.add_le_add_left (defOff_mono P (j + 1) (by omega)) _

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem defPos_mono (P : BlockParams) (hdrLen : ℕ) {s1 s2 : ℕ} (h : s1 ≤ s2) :
    defPos P hdrLen s1 ≤ defPos P hdrLen s2 :=
  Nat.add_le_add_left (defOff_mono P 0 h) (hdrLen + 10)

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem defOff_eq_shapeLenW (P : BlockParams) :
    ∀ (j : ℕ) (ss : List (ℕ × ℕ × ℕ)),
      (∀ i, i < ss.length → slotShape P (j + i) = ss.getD i (0, 0, 0)) →
      defOff P j ss.length = shapeLenW P.draws j ss
  | _, [], _ => rfl
  | j, s :: ss, h => by
    have h0 : slotShape P j = s := by simpa using h 0 (by simp)
    have ih := defOff_eq_shapeLenW P (j + 1) ss (fun i hi => by
      have h1 := h (i + 1) (by simp; omega)
      rwa [show j + (i + 1) = j + 1 + i by omega] at h1)
    simp only [List.length_cons, defOff, shapeLenW, h0, ih]

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem defOff_le_shapeLen (P : BlockParams) (s : ℕ) (hs : s ≤ P.geom.slots.length) :
    defOff P 0 s ≤ shapeLen P 0 P.geom.slots := by
  have h1 : defOff P 0 s ≤ defOff P 0 P.geom.slots.length := defOff_mono P 0 hs
  have h2 : defOff P 0 P.geom.slots.length = shapeLenW P.draws 0 P.geom.slots :=
    defOff_eq_shapeLenW P 0 P.geom.slots (fun i _ => by simp [slotShape])
  rw [shapeLen_eq, ← h2]
  exact h1

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem pairwise_map_defPos (P : BlockParams) (hdrLen : ℕ) (ks : List ℕ) (f : ℕ → SqX K Lq)
    (ha : ∀ s, (f s).a = defPos P hdrLen s) (hks : ks.Pairwise (· ≤ ·)) :
    (ks.map f).Pairwise (fun a b => a.a ≤ b.a) := by
  rw [List.pairwise_map]
  exact hks.imp (fun {s1 s2} hle => by rw [ha s1, ha s2]; exact defPos_mono P hdrLen hle)

theorem blkRelSq_valid (U : K) (tag : MTag) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws)
    (hsl : P.geom.slots = Exec.Block.R13.shieldSlots) (hlc : P.logCols = 14)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay)
    (lo hi hdrLen : ℕ) (hlo : lo + 5 = hdrLen) (hhi : hdrLen + 10 + shapeLen P 0 P.geom.slots ≤ hi)
    (absOf : QB Lq → Option (List UInt8)) (i : ℕ) (hi4 : i < 4) (s : ℕ) (hs : s ∈ w16r2RelKs i) :
    SqCut absOf (blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf i s)
      ∧ (blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf i s).Rbr
      ∧ (blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf i s).e ≤ 80
      ∧ (blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf i s).n
          * (blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf i s).e ≤ 80 * 451
      ∧ lo ≤ (blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf i s).a
      ∧ (blkRelSq U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf i s).a ≤ hi := by
  have hs23 : s < 23 := (Exec.Block.w16r2RelKs_facts i hi4).2 s hs
  have hslen : P.geom.slots.length = 23 := by rw [hsl]; rfl
  have hoff := defOff_le_shapeLen P s (by omega)
  refine ⟨defSqB_cut P hdrLen absOf _ _ s, defSqB_rbr P hdrLen absOf _ _ s (fun cu rt _ h => ?_),
    le_rfl, ?_, ?_, ?_⟩
  · show IndDegLE 80 ((algSp U _ _ (card_K_gt K) i cu rt s h).Φ)
    exact IndDegLE.mono (algSp U _ _ (card_K_gt K) i cu rt s h).hdeg (algSp_dg U _ _ (card_K_gt K) i hi4 cu rt s h hs)
  · show P.draws s * 80 ≤ 80 * 451
    have hd : P.draws s ≤ 451 := by rw [hdr]; exact shieldDraws_le_451 s hs23
    omega
  · show lo ≤ hdrLen + 10 + defOff P 0 s
    omega
  · show hdrLen + 10 + defOff P 0 s ≤ hi
    omega

theorem blkIoSq_valid (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws)
    (hsl : P.geom.slots = Exec.Block.R13.shieldSlots) (hlc : P.logCols = 14)
    (oI oO : RtOpen K Lq) (pi po lo hi hdrLen : ℕ) (hlo : lo + 5 = hdrLen)
    (hhi : hdrLen + 10 + shapeLen P 0 P.geom.slots ≤ hi)
    (absOf : QB Lq → Option (List UInt8)) (s : ℕ) (hs : s ∈ [21, 22]) :
    SqCut absOf (blkIoSq U tag h64 hL20 Ly P hdr hlc oI oO pi po hdrLen absOf s)
      ∧ (blkIoSq U tag h64 hL20 Ly P hdr hlc oI oO pi po hdrLen absOf s).Rbr
      ∧ (blkIoSq U tag h64 hL20 Ly P hdr hlc oI oO pi po hdrLen absOf s).e ≤ 80
      ∧ (blkIoSq U tag h64 hL20 Ly P hdr hlc oI oO pi po hdrLen absOf s).n
          * (blkIoSq U tag h64 hL20 Ly P hdr hlc oI oO pi po hdrLen absOf s).e ≤ 80 * 451
      ∧ lo ≤ (blkIoSq U tag h64 hL20 Ly P hdr hlc oI oO pi po hdrLen absOf s).a
      ∧ (blkIoSq U tag h64 hL20 Ly P hdr hlc oI oO pi po hdrLen absOf s).a ≤ hi := by
  have hs23 : s < 23 := by simp only [List.mem_cons, List.not_mem_nil, or_false] at hs; omega
  have hslen : P.geom.slots.length = 23 := by rw [hsl]; rfl
  have hoff := defOff_le_shapeLen P s (by omega)
  refine ⟨defSqB_cut P hdrLen absOf _ _ s,
    defSqB_rbr P hdrLen absOf _ _ s (fun cu rt hx h => ioDefSchedB_indDeg P _ _ _ _ _ _ _ cu rt hx s h),
    show 1 ≤ 80 by norm_num, ?_, by show lo ≤ hdrLen + 10 + defOff P 0 s; omega,
    by show hdrLen + 10 + defOff P 0 s ≤ hi; omega⟩
  show P.draws s * 1 ≤ 80 * 451
  have hd : P.draws s ≤ 451 := by rw [hdr]; exact shieldDraws_le_451 s hs23
  omega

theorem blkHelpSq_valid (U : K) (tag : MTag) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws)
    (hsl : P.geom.slots = Exec.Block.R13.shieldSlots) (hlc : P.logCols = 14)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay)
    (lo hi hdrLen : ℕ) (hlo : lo + 5 = hdrLen) (hhi : hdrLen + 10 + shapeLen P 0 P.geom.slots ≤ hi)
    (absOf : QB Lq → Option (List UInt8)) (s : ℕ) (hs : s ∈ w16r2RelKs 0) :
    SqCut absOf (blkHelpSq U tag hL20 Ly P hdr hsl hlc Pb Lay B hdrLen absOf s)
      ∧ (blkHelpSq U tag hL20 Ly P hdr hsl hlc Pb Lay B hdrLen absOf s).Rbr
      ∧ (blkHelpSq U tag hL20 Ly P hdr hsl hlc Pb Lay B hdrLen absOf s).e ≤ 80
      ∧ (blkHelpSq U tag hL20 Ly P hdr hsl hlc Pb Lay B hdrLen absOf s).n
          * (blkHelpSq U tag hL20 Ly P hdr hsl hlc Pb Lay B hdrLen absOf s).e ≤ 80 * 451
      ∧ lo ≤ (blkHelpSq U tag hL20 Ly P hdr hsl hlc Pb Lay B hdrLen absOf s).a
      ∧ (blkHelpSq U tag hL20 Ly P hdr hsl hlc Pb Lay B hdrLen absOf s).a ≤ hi := by
  have hs23 : s < 23 := (Exec.Block.w16r2RelKs_facts 0 (by norm_num)).2 s hs
  have hslen : P.geom.slots.length = 23 := by rw [hsl]; rfl
  have hoff := defOff_le_shapeLen P s (by omega)
  refine ⟨defSqB_cut P hdrLen absOf _ _ s, defSqB_rbr P hdrLen absOf _ _ s (fun cu rt _ h => ?_),
    le_rfl, ?_, by show lo ≤ hdrLen + 10 + defOff P 0 s; omega,
    by show hdrLen + 10 + defOff P 0 s ≤ hi; omega⟩
  · show IndDegLE 80 ((spHR U (card_K_gt K) (Exec.Block.DefR13.cfgShieldR13 Ly) P (helpProf_shield P hdr hsl)
      (algShapeR (Exec.Block.DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hdr))
      (blkAlgDt U tag hL20 Ly P hdr hlc Pb Lay B) (blkDof tag hL20 P hlc)
      (Exec.Block.Join.R13H.Pub.gateLS (Exec.Block.DefR13.cfgShieldR13 Ly).sh)
      Pb.exp Pb.act (shieldShape Ly).nG cu rt s h).Φ)
    exact IndDegLE.mono (spHR U (card_K_gt K) _ P _ _ _ _ _ Pb.exp Pb.act _ cu rt s h).hdeg
      (helperR_dg_r13 U (card_K_gt K) (Exec.Block.DefR13.cfgShieldR13 Ly) P (helpProf_shield P hdr hsl)
        (shOk_shield Ly P hdr) _ _ _ Pb.exp Pb.act _ cu rt s h hs)
  · show P.draws s * 80 ≤ 80 * 451
    have hd : P.draws s ≤ 451 := by rw [hdr]; exact shieldDraws_le_451 s hs23
    omega

/-- **Full six-conjunct `RkSqOk` certificates for the five block squeeze lists (`r0`, `r1`, `h0`, `h1`, `lu`) stated at
`eL = 2^26`** (not used by `sshC_productionReadyL_epP_blkAlive`, where `hD` is unchanged and `eL` is a free parameter;
covers 5 of the 16 `RkPart.Ok` conjunct groups; side hypothesis `hhi` remains to be derived from the profile). -/
theorem blkLists_rkSqOk (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq) (Ly : ShieldLayer)
    (P : BlockParams) (hdr : P.draws = Exec.Block.R13.shieldDraws)
    (hsl : P.geom.slots = Exec.Block.R13.shieldSlots) (hlc : P.logCols = 14)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay)
    (oI oO : RtOpen K Lq) (pi po lo hi hdrLen : ℕ) (hlo : lo + 5 = hdrLen)
    (hhi : hdrLen + 10 + shapeLen P 0 P.geom.slots ≤ hi)
    (absOf : QB Lq → Option (List UInt8)) :
    RkSqOk absOf lo hi 80 (80 * 451) (blkR0 U tag h64 hL20 Ly P hdr hlc Pb Lay B oI oO pi po hdrLen absOf)
      ∧ RkSqOk absOf lo hi 80 (80 * 451) (blkR1 U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf)
      ∧ RkSqOk absOf lo hi 80 (80 * 451) (blkH0 U tag hL20 Ly P hdr hlc Pb Lay B hdrLen absOf)
      ∧ RkSqOk absOf lo hi 80 (80 * 451) (blkH1 U tag hL20 Ly P hdr hsl hlc Pb Lay B hdrLen absOf)
      ∧ RkSqOk absOf lo hi (2 ^ 26) (3 * 2 ^ 26) (blkLU U tag hL20 Ly P hlc Pb Lay B hdrLen absOf) := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · refine ⟨fun sx hsx => ?_, ?_⟩
    · rcases List.mem_append.mp hsx with h0 | hio
      · obtain ⟨s, hs, rfl⟩ := List.mem_map.mp h0
        exact blkRelSq_valid U tag hL20 Ly P hdr hsl hlc Pb Lay B lo hi hdrLen hlo hhi absOf 0 (by norm_num) s hs
      · obtain ⟨s, hs, rfl⟩ := List.mem_map.mp hio
        exact blkIoSq_valid U tag h64 hL20 Ly P hdr hsl hlc oI oO pi po lo hi hdrLen hlo hhi absOf s hs
    · unfold blkR0
      rw [List.pairwise_append]
      refine ⟨pairwise_map_defPos P hdrLen (w16r2RelKs 0) _ (fun _ => rfl) (by decide),
        pairwise_map_defPos P hdrLen [21, 22] _ (fun _ => rfl) (by decide), fun a ha b hb => ?_⟩
      obtain ⟨s1, hs1, rfl⟩ := List.mem_map.mp ha
      obtain ⟨s2, hs2, rfl⟩ := List.mem_map.mp hb
      have h1 : s1 ≤ 20 := by
        simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hs1
        omega
      have h2 : 21 ≤ s2 := by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at hs2
        omega
      exact defPos_mono P hdrLen (by omega)
  · refine ⟨fun sx hsx => ?_,
      pairwise_map_defPos P hdrLen (w16r2RelKs 1) _ (fun _ => rfl) (by decide)⟩
    obtain ⟨s, hs, rfl⟩ := List.mem_map.mp hsx
    exact blkRelSq_valid U tag hL20 Ly P hdr hsl hlc Pb Lay B lo hi hdrLen hlo hhi absOf 1 (by norm_num) s hs
  · refine ⟨fun sx hsx => ?_, ?_⟩
    · simp only [blkH0, List.mem_cons, List.not_mem_nil, or_false] at hsx
      rcases hsx with rfl | rfl | rfl
      · exact blkRelSq_valid U tag hL20 Ly P hdr hsl hlc Pb Lay B lo hi hdrLen hlo hhi absOf 2 (by norm_num) 5 (by decide)
      · exact blkRelSq_valid U tag hL20 Ly P hdr hsl hlc Pb Lay B lo hi hdrLen hlo hhi absOf 3 (by norm_num) 5 (by decide)
      · exact blkRelSq_valid U tag hL20 Ly P hdr hsl hlc Pb Lay B lo hi hdrLen hlo hhi absOf 2 (by norm_num) 11 (by decide)
    · unfold blkH0
      have h5_11 : defPos P hdrLen 5 ≤ defPos P hdrLen 11 := defPos_mono P hdrLen (by omega)
      simp only [List.pairwise_cons, List.mem_cons, List.not_mem_nil, or_false]
      refine ⟨?_, ?_, fun _ h => False.elim h, List.Pairwise.nil⟩
      · rintro _ (rfl | rfl)
        · exact le_rfl
        · exact h5_11
      · rintro _ rfl
        exact h5_11
  · refine ⟨fun sx hsx => ?_,
      pairwise_map_defPos P hdrLen (w16r2RelKs 0) _ (fun _ => rfl) (by decide)⟩
    obtain ⟨s, hs, rfl⟩ := List.mem_map.mp hsx
    exact blkHelpSq_valid U tag hL20 Ly P hdr hsl hlc Pb Lay B lo hi hdrLen hlo hhi absOf s hs
  · refine ⟨fun sx hsx => ?_, List.pairwise_singleton _ _⟩
    simp only [blkLU, List.mem_singleton] at hsx
    subst hsx
    have he := he_shield (K := K) Ly (TR13 (K := K) Pb.exp Pb.act (shieldShape Ly).nG)
    refine ⟨lkSqB_cut hdrLen absOf _ _ _, lkSqB_rbr hdrLen absOf _ _ _ (hN_shield (K := K) Ly),
      he, Nat.mul_le_mul_left 3 he, ?_, ?_⟩
    · show lo ≤ hdrLen + 4
      omega
    · show hdrLen + 4 ≤ hi
      omega

end FixedLayer

end BlkSqueezeLists

/-! ## 5. Direct classify-run unmasking, define-draw entry, and block alive soundness (`hR0_blk..hLU_blk`, `hblk`) -/

section BlkAliveRun

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem defOff_succ_right (P : BlockParams) : ∀ (i m : ℕ),
    defOff P i (m + 1) = defOff P i m + (P.draws (i + m) + 4 + 2 * ((slotShape P (i + m)).1 + (slotShape P (i + m)).2.1))
  | i, 0 => by simp [defOff]
  | i, m + 1 => by
    rw [defOff, defOff_succ_right P (i + 1) m, defOff, show i + (m + 1) = i + 1 + m by omega]
    omega

omit [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem blockSchedXB_win {L : ℕ} (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → HdrX L → (j : ℕ) → Seen → (Fin ((slotShape P j).1 + (slotShape P j).2.1) → K) → K) :
    ∀ j, j ≤ P.geom.slots.length →
      slotsLenX ((blockSchedXB P hdrLen absOf F).take j) + (blockSlotXB P hdrLen absOf F j).s
        = defPos P hdrLen j + (P.draws j + 3)
  | 0, _ => by
    simp [slotsLenX, blockSlotXB, defPos, defOff]
  | j + 1, hj => by
    have htake : (blockSchedXB P hdrLen absOf F).take (j + 1)
        = (blockSchedXB P hdrLen absOf F).take j ++ [blockSlotXB P hdrLen absOf F j] := by
      have hlen : j < (blockSchedXB P hdrLen absOf F).length := by
        simp [blockSchedXB]; omega
      rw [List.take_succ_eq_append_getElem hlen]
      simp [blockSchedXB, List.getElem_map, List.getElem_range]
    have ih := blockSchedXB_win P hdrLen absOf F j (by omega)
    rw [htake]
    simp only [slotsLenX, List.map_append, List.sum_append, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
      Nat.add_zero]
    change slotsLenX ((blockSchedXB P hdrLen absOf F).take j)
      + ((blockSlotXB P hdrLen absOf F j).s + 2 * (blockSlotXB P hdrLen absOf F j).n)
      + (blockSlotXB P hdrLen absOf F (j + 1)).s = _
    have hs1 : (blockSlotXB P hdrLen absOf F (j + 1)).s = 1 + (P.draws (j + 1) + 3) := rfl
    have hn0 : (blockSlotXB P hdrLen absOf F j).n = (slotShape P j).1 + (slotShape P j).2.1 := rfl
    rw [hs1, hn0, ← Nat.add_assoc (slotsLenX _), ih]
    unfold defPos
    rw [defOff_succ_right P 0 j, Nat.zero_add]
    omega

omit [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem blockSchedXB_getElem? {L : ℕ} (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → HdrX L → (j : ℕ) → Seen → (Fin ((slotShape P j).1 + (slotShape P j).2.1) → K) → K)
    (j : ℕ) (hj : j < P.geom.slots.length) :
    (blockSchedXB P hdrLen absOf F)[j]? = some (blockSlotXB P hdrLen absOf F j) := by
  unfold blockSchedXB
  rw [List.getElem?_map, List.getElem?_range hj]
  rfl

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem rxPs_r0_blk {Lq : ℕ} (base : ℕ → RkPart K Lq) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
    {k : ℕ} (hk : k < Lb) : (rxPs base Lb din dblk dout (k + 1)).r0 = (base (k + 1)).r0 := by
  rw [rxPs_blk base Lb din dblk dout k hk]; rfl

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem rxPs_r1_blk {Lq : ℕ} (base : ℕ → RkPart K Lq) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
    {k : ℕ} (hk : k < Lb) : (rxPs base Lb din dblk dout (k + 1)).r1 = (base (k + 1)).r1 := by
  rw [rxPs_blk base Lb din dblk dout k hk]; rfl

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem rxPs_h0_blk {Lq : ℕ} (base : ℕ → RkPart K Lq) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
    {k : ℕ} (hk : k < Lb) : (rxPs base Lb din dblk dout (k + 1)).h0 = (base (k + 1)).h0 := by
  rw [rxPs_blk base Lb din dblk dout k hk]; rfl

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem rxPs_h1_blk {Lq : ℕ} (base : ℕ → RkPart K Lq) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
    {k : ℕ} (hk : k < Lb) : (rxPs base Lb din dblk dout (k + 1)).h1 = (base (k + 1)).h1 := by
  rw [rxPs_blk base Lb din dblk dout k hk]; rfl

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem rxPs_lu_blk {Lq : ℕ} (base : ℕ → RkPart K Lq) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
    {k : ℕ} (hk : k < Lb) : (rxPs base Lb din dblk dout (k + 1)).lu = (base (k + 1)).lu := by
  rw [rxPs_blk base Lb din dblk dout k hk]; rfl

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
/-- **Trace facts at an accepted block slot phase**: slot `s`'s define window lies inside `τ`, `tHistD` returns the
canonical history `histOf bga (rs.take s)`, `rootsAt` returns `rootsOf core`, and `hdrLen + 4 ≤ τ.length`. -/
theorem blk_trace_at_slot {Lq : ℕ} (key : Option Dig) (domain : List UInt8) (P : BlockParams) (hdrLen : ℕ)
    (G : QB Lq → Dig) (hgt : P.geom.slots.length = P.geom.terms.length)
    (hd1 : ∀ j, j < P.geom.slots.length → 1 ≤ (slotShape P j).2.2)
    (hdr : List Op) (core : Exec.Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Exec.Block.Acc)
    (T' : List Op) (hsa : Exec.Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc)
    (τ : List (TItem × Dig))
    (htr : τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Exec.Block.allOps P (hdr, core) ++ T')) :
    hdrLen + 4 ≤ τ.length
      ∧ rootsAt hdrLen τ = rootsOf core
      ∧ rs.length = P.geom.slots.length
      ∧ ∀ s, s < P.geom.slots.length →
          (∃ r, rs[s]? = some r)
          ∧ defPos P hdrLen s ≤ τ.length
          ∧ tHistD P hdrLen s (τ.take (defPos P hdrLen s)) = some (histOf bga.1 bga.2.1 bga.2.2 (rs.take s), []) := by
  obtain ⟨hhl, -, -, hsh, t', hbs⟩ := hsa
  simp only at hhl hsh hbs
  have hslen : core.slots.length = P.geom.slots.length := hsh.1
  rw [Exec.Block.blockSlots_eq] at hbs
  simp only [← runOps_append] at hbs
  split at hbs
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hbs
    obtain ⟨hbga, hres⟩ := hbs
    subst hres
    have hd1' : ∀ i, i < core.slots.length → 1 ≤ (slotShape P (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]; exact hd1 i (by omega)
    obtain ⟨rs', hrs', hlen, hall⟩ := Exec.Block.slotsLoop_ok (liftH G) P _ _ _ core.slots [] 0 {} _ rs acc t' hd1' hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    have hround : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1 := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨ss, hs'⟩ : ∃ ss, P.geom.slots[i]? = some ss := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2.1 i q ss tt hq hs' htt).1
      rw [this, slotShape, List.getD_eq_getElem?_getD, hs', Option.getD_some]
    have hv : ∀ i q r, core.slots[i]? = some q → rs[i]? = some r →
        r.draws = (Exec.Block.preVals (liftH G) P (Exec.Block.slotTr (liftH G) P
          (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Exec.Block.rootOps P core)) 0 core.slots i) i q).1 := by
      intro i q r hq hr
      have h1 := congrArg Prod.fst (hall i q r hq hr).1
      rw [Nat.zero_add] at h1
      exact h1
    have hτlen : hdrLen + 10 ≤ τ.length := by
      rw [htr, Exec.Block.opTrace_length, List.length_append, Exec.Block.allOps, List.length_append, List.length_append,
        hhl, Exec.Block.rootOps_length]
      omega
    have hrt : rootsAt hdrLen τ = rootsOf core := by
      rw [htr]
      have he : Exec.Block.allOps P (hdr, core) ++ T'
          = hdr ++ Exec.Block.rootOps P core ++ (Exec.Block.fullOps P 0 core.slots ++ T') := by
        simp [Exec.Block.allOps, List.append_assoc]
      rw [he, ← hhl]
      exact Exec.Block.rootsAt_trace (liftH G) P core hdr _ (Tr.newKeyed (liftH G) domain key)
    refine ⟨by omega, hrt, by omega, fun s hs => ?_⟩
    have hsc : s < core.slots.length := by omega
    obtain ⟨q, hq⟩ : ∃ q, core.slots[s]? = some q := ⟨_, List.getElem?_eq_getElem hsc⟩
    obtain ⟨r, hr⟩ : ∃ r, rs[s]? = some r := ⟨_, List.getElem?_eq_getElem (by omega)⟩
    obtain ⟨hw1, -, hw3⟩ := Exec.Block.def_window (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) s q hq hround
    rw [hhl] at hw1 hw3
    have hhist := Exec.Block.tHistD_trace (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) s hsc.le hround rs
      (by omega) hv
    have hbga1 := congrArg Prod.fst hbga
    have hbga2 := congrArg (fun x => x.2.1) hbga
    have hbga3 := congrArg (fun x => x.2.2) hbga
    dsimp only at hbga1 hbga2 hbga3
    rw [hhl, hbga1, hbga2, hbga3] at hhist
    have hext : τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ Exec.Block.rootOps P core ++ Exec.Block.fullOps P 0 core.slots)
        ++ opTrace (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ Exec.Block.rootOps P core ++ Exec.Block.fullOps P 0 core.slots)) T' := by
      rw [htr]
      exact Exec.Block.opTrace_append (liftH G) _ _ _
    have hlen_le : defPos P hdrLen s ≤ τ.length := by
      rw [hext, List.length_append]
      omega
    refine ⟨⟨r, hr⟩, hlen_le, ?_⟩
    rw [hext, List.take_append_of_le_length hw3, hw1]
    exact hhist
  · cases hbs

/-- **From `¬ rtKsq.Dm` at a block reading, a `defSqB` entry vanishes identically at `(cuts3, rootsOf, hdrX, histOf)`.** -/
theorem blk_defSqB_ent {Lq : ℕ} (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    {α : Type} (pf : RtProf) (rd : α → List Op × List RtData) (hL64 : Lq < 2 ^ 64) (hv : pf.Valid)
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (emax ND : ℕ) (sxs : ℕ → List (SqX K Lq))
    (hsx : RtSqOk (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf emax ND sxs)
    (n i : ℕ) (hin : i < n) (hi : i < pf.parts.length)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hnd : ¬ (rtKsq key domain hs Lq hL pf rd hL64 hv U hbij emax ND sxs hsx).Dm n lg τ)
    (P : BlockParams) (hdrLen : ℕ)
    (G : QB Lq → Dig) (hgt : P.geom.slots.length = P.geom.terms.length)
    (hd1 : ∀ j, j < P.geom.slots.length → 1 ≤ (slotShape P j).2.2)
    (hdr : List Op) (core : Exec.Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Exec.Block.Acc)
    (T' : List Op) (hsa : Exec.Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc)
    (htr : τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Exec.Block.allOps P (hdr, core) ++ T'))
    (Φ : Cuts3 Lq → RootsO → HdrX Lq → (j : ℕ) → Hist → (Fin (P.draws j) → K) → K) (dg : ℕ → ℕ) (s : ℕ)
    (hs_lt : s < P.geom.slots.length)
    (hmem : defSqB P hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) Φ dg s ∈ sxs i) :
    ∀ y, Φ (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg (rootsOf core)) (rootsOf core)
      (hdrX (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg hdrLen τ) s
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take s)) y = 0 := by
  obtain ⟨-, hrt, -, hslots⟩ := blk_trace_at_slot key domain P hdrLen G hgt hd1 hdr core bga rs acc T' hsa τ htr
  obtain ⟨-, hpos, hhist⟩ := hslots s hs_lt
  have hst := ra_Ksq_ent key domain hs Lq hL pf rd hL64 hv U hbij emax ND sxs hsx n lg τ hnd i hin hi _ hmem hpos
  have hr_take : rootsAt hdrLen (τ.take (defPos P hdrLen s)) = rootsOf core := by
    rw [rd_rootsAt_take τ hdrLen _ (by unfold defPos; omega), hrt]
  have hhx_take : hdrX (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg hdrLen (τ.take (defPos P hdrLen s))
      = hdrX (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg hdrLen τ :=
    rd_hdrX_take _ lg τ hdrLen _ (by unfold defPos; omega)
  simp only [defSqB, hhist, hr_take, hhx_take] at hst
  exact (szSt_nil _).mp hst

/-- **Direct unmasking at an accepted Shieldstral block reading on the classify run** (from `¬ EvXR`, `¬ rtKM.Dm`,
`¬ rtKsl.Dm`; no boundary opening premise needed). -/
theorem blk_unmask_at_run
    {Hdr : Type} {Lq : ℕ} (h64 : 64 ≤ Lq) (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (Lb : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (Pk : ℕ → BlockParams) (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom)
    (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →
      Except String Tr)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid) (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k))
    (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (htB : ∀ k, (bp k).tag = tag) (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (IinA_rows IinH_rows Iin_nA Iin_nH OoutA_rows OoutH_rows Oout_nA Oout_nH : ℕ)
    (base : ℕ → RkPart K Lq) (eL : ℕ) (D : RtKData K Lq)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn))
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)
      (rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn IinA_rows IinH_rows Iin_nA Iin_nH mIn)
        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA
          (bp k).nH)
        (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut OoutA_rows OoutH_rows Oout_nA Oout_nH))
      (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) eL)
    {S0 : BlockShape} {blks : List (RunBlock S0)}
    (hPk : ShieldRunAt Pk blks Lb)
    (hoAK : ∀ k, k < Lb → (D.opA (k + 1)).lc = rowLog (Pk k) .a)
    (hoHK : ∀ k, k < Lb → (D.opH (k + 1)).lc = rowLog (Pk k) .h)
    (hoIK : ∀ k, k < Lb → (D.opX (k + 1)).lc = rowLog (Pk k) .inp)
    (hoOK : ∀ k, k < Lb → (D.opX (k + 1 + 1)).lc = rowLog (Pk k) .out)
    (hslB : ∀ k, k < Lb → D.sls (k + 1) = blockSchedXB (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (bwFslRun U tag Lq h64 Lb Pk (fun k => (bp k).S) D (RtRun.pf Rn) hoAK hoHK hoIK hoOK
        (shieldRunProg hPk) (shieldRunPubs hPk) k))
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (liftH G) (A.run G).1 (A.run G).2 = .ok ())
    (hnoX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (n : ℕ) (hn : Lb + 2 ≤ n)
    (hM : ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm n (A.runLog G).2
      (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hsl : ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm n (A.runLog G).2
      (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (k : ℕ) (hk : k < Lb)
    (prog2 : List SlotS) (pubs2 : PubTabs) (hdef2 : (Pk k).define = defineS prog2 pubs2)
    (hdr : List Op) (core : Exec.Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Exec.Block.Acc)
    (T' : List Op)
    (hsa : Exec.Block.SlotsAcc key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G (hdr, core) bga rs acc)
    (htr : rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)
      = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Exec.Block.allOps (Pk k) (hdr, core) ++ T'))
    (j : ℕ) (r : SlotRec) (hr : rs[j]? = some r) :
    ∃ df, (Pk k).define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ bga.2.2.Canon ∧ bga.1.Canon
      ∧ ((Pk k).kind j = SlotKind.standalone →
          spSum (Pk k) (polyS U (Pk k)
            (dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
              (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
              (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
              (rootsOf core)
              (hdrX (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2
                ((RtRun.pf Rn).off (k + 1) + 5) (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
              ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2))
            prog2 pubs2) bga rs j = 0)
      ∧ ((Pk k).kind j = SlotKind.host → (∀ hk' ∈ df.hosted, (Pk k).kind hk'.1 ≠ SlotKind.host) →
          spSum (Pk k) (polyS U (Pk k)
            (dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
              (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
              (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
              (rootsOf core)
              (hdrX (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2
                ((RtRun.pf Rn).off (k + 1) + 5) (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
              ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2))
            prog2 pubs2) bga rs j
          = (df.hosted.map (fun hk' => hk'.2.toK U * spSum (Pk k) (polyS U (Pk k)
              (dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
                (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
                (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
                (rootsOf core)
                (hdrX (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2
                  ((RtRun.pf Rn).off (k + 1) + 5) (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
                ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2))
              prog2 pubs2) bga rs hk'.1)).sum) := by
  set τ := rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)
  set lg := (A.runLog G).2
  set absOf := Exec.Block.absOfC (chainEncB key domain hs Lq hL)
  set hdrLen := (RtRun.pf Rn).off (k + 1) + 5
  have hLb26 : Lb ≤ 26 := hPk.lb_le
  have hk26 : k < 26 := by omega
  have hparts : (RtRun.pf Rn).parts.length = Lb + 2 := RtRun.parts_length Rn
  have hi1 : k + 1 < (RtRun.pf Rn).parts.length := by omega
  have hin1 : k + 1 < n := by omega
  -- 1. Extract `MTrue` on `acc.fs ++ acc.hostFs` from `rx_blk_M` + `wr_ndM` + `wr_rkMask_sem`
  have hσb := ra_blk_seg Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck
    bndOpen Rn cx0 pin pout bp wXk gXk mXk hσ k hk
  have hpart : (RtRun.pf Rn).part (k + 1) = rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m
      ((bp k).nH + (bp k).pH.rows) (bp k).pH.m (wXk k) (gXk k) (mXk k) := rx_part_of Rn (k + 1) _ hσb
  have hpre_eq : ((RtRun.pf Rn).part (k + 1)).pre = 15 + shapeLen (Pk k) 0 (Pk k).geom.slots := by
    rw [hpart]; rfl
  have hacc_rd := wr_acc_rd key domain (Pk k) hdrLen G (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1)
    hdr core bga rs acc T' hsa τ htr
  obtain ⟨oM⟩ := rx_blk_M tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Rn hv G
    (A.run G).1 (A.run G).2 hE k hk26 (bp k) (wXk k) (gXk k) (mXk k) hσb (hgeo k) (htB k) incG outcG Lb A
    (Prod.eta (A.run G)).symm hnoX (hfBM k)
  have hndM : ¬ EntD (rtW (RtRun.pf Rn).sqs) ((D.msk (k + 1)).sub U hbij ((RtRun.pf Rn).off (k + 1)
      + ((RtRun.pf Rn).part (k + 1)).pre) lg) τ :=
    wr_ndM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD n lg τ hM (k + 1) hi1 (by omega)
  have hmsk_eq : D.msk (k + 1) = rkMask U tag Lq h64 key domain hs hL (bp k).S (Pk k).nFunctionals
      ((RtRun.pf Rn).off (k + 1) + (5 + 3))
      (fun hdr' => (rkAccBlk (Pk k) hdrLen ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).pre) hdr').fs
        ++ (rkAccBlk (Pk k) hdrLen ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).pre) hdr').hostFs) := by
    rw [hDe]
    show rkMask U tag Lq h64 key domain hs hL _ _ _ _ = _
    rw [rxPs_blk _ Lb _ _ _ k hk, rxAcc_blk _ _ _ _ _ k hk]
    rfl
  rw [hmsk_eq] at hndM
  have hlen_m : (RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).pre ≤ τ.length := by
    have h : (τ.take ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).pre)).length = _ := oM.hpl
    rw [List.length_take] at h
    omega
  have sM := wr_rkMask_sem U hbij tag Lq h64 key domain hs hL (bp k).S (Pk k).nFunctionals
    ((RtRun.pf Rn).off (k + 1) + (5 + 3)) _ (rtW (RtRun.pf Rn).sqs) _ lg τ hndM hlen_m oM.hpre
    (by
      have h := oM.hk
      rw [← oM.hrd, ← hpart] at h
      exact h)
  have hrd_pre : rkAccBlk (Pk k) hdrLen ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).pre)
      (τ.take ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).pre)) = acc := by
    show Exec.Block.tAccRd (Pk k) hdrLen ((τ.take _).take _) = acc
    rw [List.take_take, min_self, hpre_eq,
      show (RtRun.pf Rn).off (k + 1) + (15 + shapeLen (Pk k) 0 (Pk k).geom.slots)
        = hdrLen + (10 + shapeLen (Pk k) 0 (Pk k).geom.slots) by unfold hdrLen; omega]
    exact hacc_rd
  obtain ⟨-, hrt_τ, hrslen, _⟩ := blk_trace_at_slot key domain (Pk k) hdrLen G (bp k).hgt
    (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa τ htr
  have hMTrue : Exec.Block.MTrue U (msOfTab U (bp k).S (colsC tag Lq h64
      (cuts3 absOf lg (rootsOf core)).2.1 (rootsOf core).2.1)) (acc.fs ++ acc.hostFs) := by
    intro mf hmf
    have h1 := sM mf (by rw [hrd_pre]; exact hmf)
    have hcol : rkColsM tag Lq h64 key domain hs hL ((RtRun.pf Rn).off (k + 1) + (5 + 3)) lg
        (τ.take ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).pre))
        = colsC tag Lq h64 (cuts3 absOf lg (rootsOf core)).2.1 (rootsOf core).2.1 := by
      funext idx
      simp only [rkColsM, colsC]
      have hmp : (RtRun.pf Rn).off (k + 1) + (5 + 3)
          < (RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).pre := by rw [hpre_eq]; omega
      have eM : absAt τ ((RtRun.pf Rn).off (k + 1) + (5 + 3)) = (rootsOf core).2.1 := by
        rw [show (RtRun.pf Rn).off (k + 1) + (5 + 3) = hdrLen + 3 by unfold hdrLen; omega, ← hrt_τ]; rfl
      rw [colX_eq_cut tag Lq h64 key domain hs hL, absAt_take, ite_eq_left hmp, eM]
      rfl
    rwa [hcol] at h1
  -- 2. Extract `claimed = spSum + c * mdot` for every slot `i` from `¬ rtKsl.Dm` + `claimed_unmasked` + `polyS_congr_define`
  obtain ⟨hhl, -, hcan, hsh, t', hbs⟩ := hsa
  simp only at hhl hcan hsh hbs
  obtain ⟨hlen_c, hall_fns⟩ := blockSlots_fns (liftH G) (Pk k) core _ bga rs acc t' hbs
  have hdef1 := shieldRun_hdef hPk k hk
  have hprog1 := shieldRun_hprog hPk k hk
  have hN1 := shieldRun_hN hPk k hk
  obtain ⟨Ly_k, _, Pb_k, hLyOpt_k, -, -, -, hb_k⟩ := hPk k hk
  obtain ⟨_, _, _, _, _, _, hP_k, -, -, -⟩ := hb_k
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP_k.hsl]; rfl
  have hN64 : ∀ i, i < (Pk k).geom.slots.length → (slotShape (Pk k) i).1 + (slotShape (Pk k) i).2.1 < 64 := by
    intro i hi
    rw [hsl23] at hi
    simp only [slotShape, hP_k.hsl]
    revert i hi; decide
  have hbga_can : bga.2.2.Canon ∧ bga.1.Canon := by
    have h0 : 0 < rs.length := by omega
    obtain ⟨r0, hr0⟩ : ∃ r0, rs[0]? = some r0 := ⟨_, List.getElem?_eq_getElem h0⟩
    obtain ⟨sp0, hsp0⟩ : ∃ sp0, core.slots[0]? = some sp0 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
    obtain ⟨df0, hdf0, -⟩ := hall_fns 0 sp0 r0 hsp0 hr0
    rw [hdef2] at hdf0
    have hc0 := (defineS_ok hdf0).1
    exact ⟨hc0.1, hc0.2.1⟩
  -- Slot loop shape facts for `tSeen_trace`
  have hbs' := hbs
  rw [Exec.Block.blockSlots_eq] at hbs'
  simp only [← runOps_append] at hbs'
  cases hloop_eq : Exec.Block.slotsLoop (liftH G) (Pk k)
      ((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Exec.Block.rootOpsA (Pk k) core)).challengeFp2
        (liftH G)).1
      (((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Exec.Block.rootOpsA (Pk k) core)).challengeFp2
        (liftH G)).2.challengeFp2 (liftH G)).1
      ((((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Exec.Block.rootOpsA (Pk k) core)).challengeFp2
        (liftH G)).2.challengeFp2 (liftH G)).2.challengeFp2 (liftH G)).1
      [] 0 core.slots {}
      (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Exec.Block.rootOps (Pk k) core)) with
  | error e => rw [hloop_eq] at hbs'; cases hbs'
  | ok res =>
    rw [hloop_eq] at hbs'
    simp only [Except.ok.injEq, Prod.mk.injEq] at hbs'
    obtain ⟨hbga_eq, hres_eq⟩ := hbs'
    have hd1_loop : ∀ i, i < core.slots.length → 1 ≤ (slotShape (Pk k) (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]; exact ((bp k).hgeomL i (by omega)).1
    obtain ⟨rs', hrs', hlen_loop, hall_loop⟩ := Exec.Block.slotsLoop_ok (liftH G) (Pk k) _ _ _ core.slots [] 0 {} _
      rs acc t' hd1_loop (hres_eq ▸ hloop_eq)
    simp only [List.nil_append] at hrs'
    subst hrs'
    have hround : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape (Pk k) i).1 + (slotShape (Pk k) i).2.1 := by
      intro i q hq
      have hi : i < (Pk k).geom.slots.length := by rw [← hsh.1]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨ss, hs'⟩ : ∃ ss, (Pk k).geom.slots[i]? = some ss := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, (Pk k).geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by rw [← (bp k).hgt]; exact hi)⟩
      have := (hsh.2.1 i q ss tt hq hs' htt).1
      rw [this, slotShape, List.getD_eq_getElem?_getD, hs', Option.getD_some]
    have hscal : ∀ r' ∈ rs, r'.scalar.Canon := by
      intro r' hr'
      obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp hr'
      obtain ⟨q, hq⟩ : ∃ q, core.slots[i]? = some q :=
        ⟨_, List.getElem?_eq_getElem (by rw [← hlen_loop]; exact (List.getElem?_eq_some_iff.mp hi).1)⟩
      rw [(hall_loop i q r' hq hi).2.1]
      exact (hcan.1 q (List.mem_of_getElem? hq)).1
    set Fk := bwFslRun U tag Lq h64 Lb Pk (fun k => (bp k).S) D (RtRun.pf Rn) hoAK hoHK hoIK hoOK
      (shieldRunProg hPk) (shieldRunPubs hPk) k
    have hFk : Fk = bwFsl U tag Lq h64 (bp k).S (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1))
        (D.opX (k + 1 + 1)) (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
        ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        (shieldRunProg hPk k) (shieldRunPubs hPk k) := by
      funext c3 rt hx i sn pt
      simp only [Fk, bwFslRun, dite_eq_left hk]
    have hclS : ∀ i r', rs[i]? = some r' → r'.claimed.toK U
        = spSum (Pk k) (polyS U (Pk k)
            (dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
              (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
              (cuts3 absOf lg (rootsOf core)) (rootsOf core) (hdrX absOf lg hdrLen τ)
              ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2))
            prog2 pubs2) bga rs i
          + r'.c.toK U * mdot U (mRowX U (bp k).S (colsC tag Lq h64 (cuts3 absOf lg (rootsOf core)).2.1
              (rootsOf core).2.1)) 512 (i, swk (Pk k) i) := by
      intro i r' hr'
      have hi_lt : i < (Pk k).geom.slots.length := by
        rw [← hrslen]; exact (List.getElem?_eq_some_iff.mp hr').1
      have hic : i < core.slots.length := by rw [hsh.1]; exact hi_lt
      obtain ⟨q, hq⟩ : ∃ q, core.slots[i]? = some q := ⟨_, List.getElem?_eq_getElem hic⟩
      obtain ⟨df_i, hdf_i, hcl_i⟩ := (hall_loop i q r' hq hr').2.2.1
      set sl := blockSlotXB (Pk k) hdrLen absOf Fk i
      have hsl_get : (D.sls (k + 1))[i]? = some sl := by
        rw [hslB k hk]; exact blockSchedXB_getElem? (Pk k) hdrLen absOf Fk i hi_lt
      have hwin_eq : slotsLenX ((D.sls (k + 1)).take i) + sl.s = defPos (Pk k) hdrLen i + ((Pk k).draws i + 3) := by
        rw [hslB k hk]; exact blockSchedXB_win (Pk k) hdrLen absOf Fk i hi_lt.le
      -- Compute `τ.take (defPos + draws + 3)`
      have hsplit_slots : core.slots = core.slots.take i ++ (q :: core.slots.drop (i + 1)) := by
        have hq' : core.slots[i] = q := (List.getElem?_eq_some_iff.mp hq).2
        conv_lhs => rw [← List.take_append_drop i core.slots, List.drop_eq_getElem_cons hic, hq']
      have hfull_split : Exec.Block.fullOps (Pk k) 0 core.slots
          = Exec.Block.fullOps (Pk k) 0 (core.slots.take i)
            ++ Exec.Block.slotPreOps (Pk k) i q
            ++ (scOps q.rounds ++ [Exec.Block.termOp q] ++ Exec.Block.fullOps (Pk k) (i + 1) (core.slots.drop (i + 1))) := by
        conv_lhs => rw [hsplit_slots]
        rw [Exec.Block.fullOps_append, List.length_take_of_le hic.le, Nat.zero_add, Exec.Block.fullOps]
        simp only [List.append_assoc]
      set preOps := hdr ++ Exec.Block.rootOps (Pk k) core ++ Exec.Block.fullOps (Pk k) 0 (core.slots.take i)
        ++ Exec.Block.slotPreOps (Pk k) i q
      have hpre_len : preOps.length = defPos (Pk k) hdrLen i + ((Pk k).draws i + 3) := by
        have hf_take : (Exec.Block.fullOps (Pk k) 0 (core.slots.take i)).length = defOff (Pk k) 0 i := by
          have h := Exec.Block.fullOps_length (Pk k) 0 (core.slots.take i) (fun m qm hqm => by
            rw [Nat.zero_add]
            rw [List.getElem?_take] at hqm
            split_ifs at hqm with hm
            exact hround m qm hqm)
          rw [List.length_take_of_le hic.le] at h
          exact h
        simp only [preOps, List.length_append, hhl, Exec.Block.rootOps_length, hf_take, Exec.Block.slotPreOps_length,
          defPos]
      have hτ_split : τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) preOps
          ++ opTrace (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) preOps)
            (scOps q.rounds ++ [Exec.Block.termOp q] ++ Exec.Block.fullOps (Pk k) (i + 1) (core.slots.drop (i + 1)) ++ T') := by
        rw [htr]
        have hall_eq : Exec.Block.allOps (Pk k) (hdr, core) ++ T'
            = preOps ++ (scOps q.rounds ++ [Exec.Block.termOp q]
                ++ Exec.Block.fullOps (Pk k) (i + 1) (core.slots.drop (i + 1)) ++ T') := by
          simp only [Exec.Block.allOps, hfull_split, preOps, List.append_assoc]
        rw [hall_eq, Exec.Block.opTrace_append]
      have hwin_le : slotsLenX ((D.sls (k + 1)).take i) + sl.s ≤ τ.length := by
        rw [hwin_eq, hτ_split, List.length_append, Exec.Block.opTrace_length, hpre_len]
        omega
      have hτ_take : τ.take (slotsLenX ((D.sls (k + 1)).take i) + sl.s)
          = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) preOps := by
        rw [hwin_eq, ← hpre_len, hτ_split, List.take_left' (Exec.Block.opTrace_length _ _ _)]
      have hst_ent := ra_Ksl_ent key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD n lg τ hsl
        (k + 1) hin1 hi1 i sl hsl_get hwin_le
      rw [ra_slot_ent_iff, hτ_take] at hst_ent
      -- Evaluate `sl.stmt` on `opTrace preOps`
      have hseen_tr := Exec.Block.tSeen_trace (liftH G) (Pk k) core hdr (Tr.newKeyed (liftH G) domain key) i q hq
        hround bga rs hbga_eq.symm hlen_loop (fun m q' r'' h1 h2 => by simpa using (hall_loop m q' r'' h1 h2).1)
      have hrt_pre : rootsAt hdr.length (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) preOps) = rootsOf core := by
        simp only [preOps, List.append_assoc (hdr ++ Exec.Block.rootOps (Pk k) core)]
        exact Exec.Block.rootsAt_trace _ _ _ _ _ _
      have hhx_pre : hdrX absOf lg hdr.length (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) preOps)
          = hdrX absOf lg hdrLen τ := by
        have h1 : hdrX absOf lg hdr.length (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) preOps)
            = hdrX absOf lg hdr.length (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) := by
          simp only [preOps, List.append_assoc (hdr ++ Exec.Block.rootOps (Pk k) core), List.append_assoc hdr]
          exact Exec.Block.hdrX_opTrace_pre absOf lg (liftH G) _ hdr _ hdr.length rfl
        have h2 : hdrX absOf lg hdrLen τ
            = hdrX absOf lg hdrLen (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) := by
          rw [htr]
          exact Exec.Block.hdrX_allOps absOf lg (liftH G) _ (Pk k) hdr core T' hdrLen hhl
        rw [h1, h2, hhl]
      have hsc_i := (hall_loop i q r' hq hr').2.1
      have hstmt_eq : (sl.at lg).stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) preOps)
          = (Fk (cuts3 absOf lg (rootsOf core)) (rootsOf core) (hdrX absOf lg hdrLen τ) i (seenOf bga rs i),
              r'.claimed) := by
        simp only [sl, SlotX.at, blockSlotXB]
        rw [← hhl, hseen_tr]
        simp only
        rw [hrt_pre, hhx_pre, hhl]
        rw [Exec.Block.claimOf_seenOf (Pk k) bga rs i r' hr' hscal df_i
          (by rw [← hbga_eq]; simpa [histOf] using hdf_i) (by rw [hsc_i]; simpa using hcl_i)]
      rw [hstmt_eq] at hst_ent
      have hdeg_Fk : IndDegLE (sl.at lg).d
          (Fk (cuts3 absOf lg (rootsOf core)) (rootsOf core) (hdrX absOf lg hdrLen τ) i (seenOf bga rs i)) := by
        rw [hFk]
        exact bwFsl_indDeg U tag Lq h64 (bp k).S (Pk k) _ _ _ _ (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
          _ _ _ _ (fun m hm => ((bp k).hgeomL m hm).1) hprog1 _ _ _ i (seenOf bga rs i)
      have hcl_cube : r'.claimed.toK U
          = cubeSum (Fk (cuts3 absOf lg (rootsOf core)) (rootsOf core) (hdrX absOf lg hdrLen τ) i (seenOf bga rs i)) := by
        rcases hst_ent with hndeg | hcube
        · exact absurd hdeg_Fk hndeg
        · exact hcube
      rw [hFk] at hcl_cube
      have hcu := claimed_unmasked U hU hbij
        (mRowX U (bp k).S (colsC tag Lq h64 (cuts3 absOf lg (rootsOf core)).2.1 (rootsOf core).2.1))
        512 (Pk k)
        (polyS U (Pk k)
          (dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
            (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
            (cuts3 absOf lg (rootsOf core)) (rootsOf core) (hdrX absOf lg hdrLen τ)
            ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2))
          (shieldRunProg hPk k) (shieldRunPubs hPk k))
        bga rs i r' hr' (hN1 i hi_lt).1 (hN64 i hi_lt) (hN1 i hi_lt).2 hcl_cube
      have hdf_i' : (Pk k).define i (histSeen (seenOf bga rs i) i) (drSeen (seenOf bga rs i) i) = .ok df_i := by
        rw [histSeen_seenOf, drSeen_seenOf bga rs i r' hr', ← hbga_eq]
        simpa [histOf] using hdf_i
      have hcongr := polyS_congr_define U hU hbij (Pk k)
        (dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
          (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
          (cuts3 absOf lg (rootsOf core)) (rootsOf core) (hdrX absOf lg hdrLen τ)
          ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2))
        (shieldRunProg hPk k) prog2 (shieldRunPubs hPk k) pubs2 hdef1 hdef2 i (seenOf bga rs i) hdf_i'
      unfold spSum at hcu ⊢
      rwa [hcongr] at hcu
    -- 3. Apply `unmask_slots` directly
    have hj_c : j < core.slots.length := by
      rw [hsh.1, ← hrslen]; exact (List.getElem?_eq_some_iff.mp hr).1
    obtain ⟨sp_j, hsp_j⟩ : ∃ sp_j, core.slots[j]? = some sp_j := ⟨_, List.getElem?_eq_getElem hj_c⟩
    obtain ⟨df_j, hdf_j, -⟩ := hall_fns j sp_j r hsp_j hr
    have hum := unmask_slots U hU (liftH G) (Pk k) core _ bga rs acc t' hbs hcan _ _ 512
      (msOfTab_mlin U (bp k).S (colsC tag Lq h64 (cuts3 absOf lg (rootsOf core)).2.1 (rootsOf core).2.1))
      hMTrue
      (fun i => spSum (Pk k) (polyS U (Pk k)
        (dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
          (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
          (cuts3 absOf lg (rootsOf core)) (rootsOf core) (hdrX absOf lg hdrLen τ)
          ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2))
        prog2 pubs2) bga rs i)
      hclS j r hr df_j hdf_j
    exact ⟨df_j, hdf_j, hbga_can.1, hbga_can.2, hum.1, hum.2⟩

omit [Fintype K] [DecidableEq K] in
/-- **`FormAt` + `blk_unmask_at_run`'s conclusion implies vanishing of `Φ` at `r.draws`.** -/
theorem formAt_vanish (U : K) (P : BlockParams)
    (Poly : (j : ℕ) → Seen → (Fin ((slotShape P j).1 + (slotShape P j).2.1) → K) → K)
    (Φ : (j : ℕ) → Hist → (Fin (P.draws j) → K) → K)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (j : ℕ) (r : SlotRec) (df : SlotDef)
    (hr : rs[j]? = some r) (hdf : P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df)
    (hst : P.kind j = SlotKind.standalone → spSum P Poly bga rs j = 0)
    (hho : P.kind j = SlotKind.host → (∀ hk ∈ df.hosted, P.kind hk.1 ≠ SlotKind.host) →
      spSum P Poly bga rs j = (df.hosted.map (fun hk => hk.2.toK U * spSum P Poly bga rs hk.1)).sum)
    (hf : FormAt U P Poly Φ bga rs j) :
    Φ j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) (fun i => (r.draws.getD i.val Fp2.zero).toK U) = 0 := by
  rcases hf r df hr hdf with ⟨hks, hΦ⟩ | ⟨hkh, hpriv, hΦ⟩
  · rw [hΦ]; exact hst hks
  · rw [hΦ, hho hkh hpriv, sub_self]

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem formAt_congr_poly {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams)
    (Poly1 Poly2 : (j : ℕ) → Seen → (Fin ((slotShape P j).1 + (slotShape P j).2.1) → K) → K)
    (Φ : (j : ℕ) → Hist → (Fin (P.draws j) → K) → K)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (j : ℕ)
    (h1 : Poly1 j (seenOf bga rs j) = Poly2 j (seenOf bga rs j))
    (h2 : ∀ r df, rs[j]? = some r → P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df →
      ∀ hk ∈ df.hosted, Poly1 hk.1 (seenOf bga rs hk.1) = Poly2 hk.1 (seenOf bga rs hk.1))
    (hf : FormAt U P Poly2 Φ bga rs j) :
    FormAt U P Poly1 Φ bga rs j := by
  intro r df hr hdf
  have hsp1 : spSum P Poly1 bga rs j = spSum P Poly2 bga rs j := by unfold spSum; rw [h1]
  have hsp2 : (df.hosted.map (fun hk => hk.2.toK U * spSum P Poly1 bga rs hk.1)).sum
      = (df.hosted.map (fun hk => hk.2.toK U * spSum P Poly2 bga rs hk.1)).sum := by
    refine congrArg List.sum (List.map_congr_left (fun hk hmem => ?_))
    unfold spSum
    rw [h2 r df hr hdf hk hmem]
  rcases hf r df hr hdf with ⟨hks, hΦ⟩ | ⟨hkh, hpriv, hΦ⟩
  · exact Or.inl ⟨hks, hΦ.trans hsp1.symm⟩
  · exact Or.inr ⟨hkh, hpriv, by rw [hΦ, hsp1, hsp2]⟩

set_option linter.unusedSimpArgs false in
/-- **Every hosted slot in `progR13` has index `< 21`.** -/
theorem progR13_hosted_lt21 (c : W16Cfg) (ioIn ioOut s : ℕ) (hist : Hist) (dr : List Fp2) (pubs : PubTabs)
    (df : SlotDef) (hok : defineS (Exec.Block.DefR13.progR13 c ioIn ioOut) pubs s hist dr = .ok df) :
    ∀ hk ∈ df.hosted, hk.1 < 21 := by
  obtain ⟨-, hdf⟩ := defineS_ok hok
  intro hk hmem
  rw [hdf] at hmem
  obtain ⟨p, hp, rfl⟩ := List.mem_map.mp hmem
  by_cases hs23 : s < 23
  · obtain ⟨ak, hk', hslot⟩ := progR13_slotH c ioIn ioOut s hs23
    rw [hslot] at hp
    change p ∈ (Exec.Block.DefR13.rawSlot c s).hosted at hp
    have hs' : s = 0 ∨ s = 1 ∨ s = 2 ∨ s = 3 ∨ s = 4 ∨ s = 5 ∨ s = 6 ∨ s = 7 ∨ s = 8 ∨ s = 9 ∨ s = 10 ∨ s = 11
        ∨ s = 12 ∨ s = 13 ∨ s = 14 ∨ s = 15 ∨ s = 16 ∨ s = 17 ∨ s = 18 ∨ s = 19 ∨ s = 20 ∨ s = 21 ∨ s = 22 := by
      omega
    rcases hs' with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
      | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
    all_goals
      dsimp only [Exec.Block.DefR13.rawSlot, Exec.Slot.W16R2.scSS, Exec.Slot.W16R2.scSSM, Exec.Slot.W16R2.scTZC,
        Exec.Slot.W16R2.scLZC, Exec.Slot.W16R2.scRS, Exec.Slot.W16R2.scQMM, Exec.Slot.W16R2.scKMM,
        Exec.Slot.W16R2.scVMM, Exec.Slot.W16R2.scSCORE, Exec.Slot.W16R2.scPV, Exec.Slot.W16R2.scWO,
        Exec.Slot.W16R2.scGMM, Exec.Slot.W16R2.scUMM, Exec.Slot.W16R2.scDMM, Exec.Slot.W16R2.scDZC,
        Exec.Slot.W16R2.scQZC, Exec.Slot.W16R2.scKVZC, Exec.Slot.W16R2.scSZC, Exec.Slot.W16R2.scFZC,
        Exec.Slot.W16R2.scTAB, Exec.Slot.W16R2.scZS, Exec.Slot.W16R2.scIOIN, Exec.Slot.W16R2.scIOOUT] at hp
      simp +decide only [↓reduceIte] at hp
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp;
      try (rcases hp with rfl | rfl <;> (dsimp only; decide))
  · have hge : (Exec.Block.DefR13.progR13 c ioIn ioOut).length ≤ s := by
      unfold Exec.Block.DefR13.progR13
      have hrp : (Exec.Block.DefR13.rawProg c).length = 23 := by
        unfold Exec.Block.DefR13.rawProg; simp [Exec.Slot.W16R2.nSlots]
      have hnp : ∀ a h (l : List SlotS), (Exec.Block.DefW16.numProg (Exec.Block.DefR13.aDataRows c)
          (Exec.Block.DefR13.hDataRows c) ioIn ioOut a h l).length = l.length := by
        intro a h l; induction l generalizing a h with
        | nil => rfl
        | cons x xs ih => simp [Exec.Block.DefW16.numProg, ih]
      rw [hnp, hrp]; omega
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none hge] at hp
    simp [SlotS.empty] at hp

section FiveBlockTheorems

variable {Hdr : Type} {Lq : ℕ} (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
  (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq) (hL64 : Lq < 2 ^ 64)
  (Lb : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → BlockParams) (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →
    Except String Tr)

include hU in
/-- **`hR0_blk` PROVED at all 26 Shieldstral layers**: every `sx ∈ D.r0 (k + 1)` (`w16r2RelKs 0` and `[21, 22]`)
meets `RaDefAtB` once `¬ EvXR`, `¬ rtKM.Dm`, `¬ rtKsl.Dm`. -/
theorem shield_hR0_blk
    {S0 : BlockShape} (Rp : ClassifyRunPublicP S0)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid) (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k))
    (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (htB : ∀ k, (bp k).tag = tag) (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (hbpRows : ∀ k, k < Lb → (bp k).pA.rows = 4577 ∧ (bp k).pH.rows = 4390)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (IinA_rows IinH_rows Iin_nA Iin_nH OoutA_rows OoutH_rows Oout_nA Oout_nH : ℕ)
    (base : ℕ → RkPart K Lq) (eL : ℕ) (D : RtKData K Lq)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn))
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)
      (rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn IinA_rows IinH_rows Iin_nA Iin_nH mIn)
        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA
          (bp k).nH)
        (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut OoutA_rows OoutH_rows Oout_nA Oout_nH))
      (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) eL)
    (hPkC : ShieldRunAtC tag Pk Rp.blks Lb)
    (hoAK : ∀ k, k < Lb → (D.opA (k + 1)).lc = rowLog (Pk k) .a)
    (hoHK : ∀ k, k < Lb → (D.opH (k + 1)).lc = rowLog (Pk k) .h)
    (hoIK : ∀ k, k < Lb → (D.opX (k + 1)).lc = rowLog (Pk k) .inp)
    (hoOK : ∀ k, k < Lb → (D.opX (k + 1 + 1)).lc = rowLog (Pk k) .out)
    (hslB : ∀ k, k < Lb → D.sls (k + 1) = blockSchedXB (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (bwFslRun U tag Lq h64 Lb Pk (fun k => (bp k).S) D (RtRun.pf Rn) hoAK hoHK hoIK hoOK
        (shieldRunProg hPkC.toShieldRunAt) (shieldRunPubs hPkC.toShieldRunAt) k))
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).1.hsl (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))))
    (hLb_eq : Lb = Rp.blks.length)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (liftH G) (A.run G).1 (A.run G).2 = .ok ())
    (hnoX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hM : ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2)
      (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hsl : ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2)
      (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))) :
    ∀ k, k < Lb → ∀ sx ∈ D.r0 (k + 1),
      RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx := by
  intro k hk sx hsx
  have hr0_eq : D.r0 (k + 1) = (base (k + 1)).r0 := by
    rw [hDe]; exact rxPs_r0_blk base Lb _ _ _ hk
  rw [hr0_eq, (hbBlk k hk).hr0] at hsx
  obtain ⟨hP, hdef, hlc, hep14, hk3, hk19, hk20, hk21, hk22, hls, hLay⟩ := shieldBlkAtC_spec hPkC k hk
  have hLy := shieldLyC_mem hPkC k hk
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  obtain ⟨hrA, hrH⟩ := hbpRows k hk
  -- Express `D.opA (k + 1)` and `D.opH (k + 1)` as `rkOpen` at `4577` and `4390`
  have hopA_eq : D.opA (k + 1) = rkOpen U tag Lq h64 key domain hs hL
      (rkR13 4577 ((RtRun.pf Rn).off (k + 1) + 5)) (bp k).nA
      (fun hdr' => (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb (k + 1) hdr').claims.a)
      ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oA + ((bp k).nA + 4577)) := by
    rw [hDe]
    show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = _
    rw [rxPs_blk base Lb _ _ _ k hk]
    simp only [rxSet, rxDblk, hrA]
    rfl
  have hopH_eq : D.opH (k + 1) = rkOpen U tag Lq h64 key domain hs hL
      (rkR13 4390 ((RtRun.pf Rn).off (k + 1) + (5 + 7))) (bp k).nH
      (fun hdr' => (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb (k + 1) hdr').claims.h
        ++ [rxLsc lscIn lscOut Pk Lb (k + 1)])
      ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH + ((bp k).nH + 4390)) := by
    rw [hDe]
    show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = _
    rw [rxPs_blk base Lb _ _ _ k hk]
    simp only [rxSet, rxDblk, hrH]
    rfl
  rcases List.mem_append.mp hsx with hrel | hio
  · obtain ⟨s, hs0, rfl⟩ := List.mem_map.mp hrel
    refine ⟨_, _, s, rfl, fun hdr core bga rs acc T' hsa _ htr => ?_⟩
    have hs23 : s < (Pk k).geom.slots.length := by
      rw [hsl23]; exact (Exec.Block.w16r2RelKs_facts 0 (by norm_num)).2 s hs0
    obtain ⟨-, -, -, hslots_tr⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
      (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
    obtain ⟨⟨r, hr⟩, -, -⟩ := hslots_tr s hs23
    refine ⟨r, hr, ?_⟩
    by_cases hhost : s ∈ algHosts
    · have hum_all := fun i r' (hr' : rs[i]? = some r') =>
        blk_unmask_at_run h64 U hU hbij tag key domain hs hL hL64 Lb preA preB start inc incG outc outcG
          Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Rn hv cx0 pin pout bp wXk gXk mXk hσ hgeo
          htB hfBM Vi F lscIn lscOut mIn kIn kOut _ _ _ _ _ _ _ _ base eL D hD hDe hPkC.toShieldRunAt
          hoAK hoHK hoIK hoOK hslB A G hE hnoX (Rp.blks.length + 2) (by omega) hM hsl k hk _ _ hdef
          hdr core bga rs acc T' hsa htr i r' hr'
      obtain ⟨df, hdf, -, -, hst_s, hho_s⟩ := hum_all s r hr
      -- Slot kind <-> hosted nonempty from `blockSlots_fns`
      rcases hsa.2.2.2 with ⟨hsh', t'', hbs''⟩
      obtain ⟨-, hall_fns⟩ := blockSlots_fns (liftH G) (Pk k) core _ bga rs acc t'' hbs''
      have hslots_kind : ∀ j r', rs[j]? = some r' →
          ∃ df', (Pk k).define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r'.draws = .ok df'
            ∧ ((Pk k).kind j = SlotKind.host ↔ df'.hosted ≠ []) := by
        intro j r' hr'
        have hjc : j < core.slots.length := by
          obtain ⟨-, -, hrslen, -⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
            (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
          rw [hsh'.1, ← hrslen]
          exact (List.getElem?_eq_some_iff.mp hr').1
        obtain ⟨sp', hsp'⟩ : ∃ sp', core.slots[j]? = some sp' := ⟨_, List.getElem?_eq_getElem hjc⟩
        obtain ⟨df', hdf', -, -, -, hkind', -⟩ := hall_fns j sp' r' hsp' hr'
        exact ⟨df', hdf', hkind'⟩
      have hf_dXof := formAt_hostsR U hU (card_K_gt K) (shieldPbC hPkC k hk) (geoShield (shieldLyC hPkC k hk))
        (shieldLayC hPkC k hk) (shieldBC hPkC k hk) (Pk k) (shOk_shield _ (Pk k) hP.hdr)
        (profR_shield _ (Pk k) hP.hdr hP.hsl)
        (Exec.Block.Join.R13H.Tzc.tzcCfg_shield _) (Exec.Block.Join.R13H.Dzc.dzcCfg_shield _ hLy)
        (Exec.Block.Join.R13H.Qkv.qkvCfg_shieldExport _ hLy) (Exec.Block.Join.R13H.Szc.szcCfg_shield _ hLy)
        (Exec.Block.Join.R13H.Fzc.fzcCfg_shield _ hLy)
        (shieldIoInC hPkC k hk) (shieldIoOutC hPkC k hk) _ hdef
        (blkDof tag hL20 (Pk k) hlc)
        (fun cu' rt' => dXof_base_r13 tag hL20 (Pk k) hlc 4577 4390 rE0 QE0 XE0 cu' rt')
        (by show 0 < (Pk k).logCols; rw [hlc]; norm_num)
        (by show 0 < (Pk k).logCols; rw [hlc]; norm_num)
        (precR_shield _) (shieldWindows _ hLy) hLay
        (Exec.Block.Join.R13H.Pub.pubR_of_L _ _ _ _ _ U hU)
        (perRow_shield _)
        (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
        (rootsOf core) bga rs hslots_kind s hhost
      -- Transfer `FormAt` from `blkDof` to `dArgs` via `SameAH`
      have hsame_k : SameAH
          (dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
            (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
            (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
            (rootsOf core)
            (hdrX (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2
              ((RtRun.pf Rn).off (k + 1) + 5) (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
            ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2))
          (blkDof tag hL20 (Pk k) hlc
            (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
            (rootsOf core)) := by
        have hoA' := hoAK k hk; rw [hopA_eq] at hoA'
        have hoH' := hoHK k hk; rw [hopH_eq] at hoH'
        have hd_eq : dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
              (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
            = dArgs tag Lq h64 (Pk k) _ _ (D.opX (k + 1)) (D.opX (k + 1 + 1)) hoA' hoH' (hoIK k hk) (hoOK k hk) := by
          congr 1
        rw [hd_eq]
        exact dArgs_sameAH_dXof U tag h64 hL20 key domain hs hL (Pk k) hlc _ _ _ _ _ _ _ _ _ _
          hoA' hoH' (hoIK k hk) (hoOK k hk) rE0 QE0 XE0 _ _ _ _ _
      have hs21 : s < 21 := by
        simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hhost
        omega
      have hf_dArgs := formAt_congr_poly U (Pk k) _ _ _ bga rs s
        (polyS_congr_ah U (Pk k) hsame_k (shieldLyC hPkC k hk) hLy _ _ _ s hs21 _)
        (fun r' df' _ hdf' hk' hmem' =>
          polyS_congr_ah U (Pk k) hsame_k (shieldLyC hPkC k hk) hLy _ _ _ hk'.1
            (progR13_hosted_lt21 _ _ _ s _ _ _ df' (hdef ▸ hdf') hk' hmem') _)
        hf_dXof
      have hΦ_eq : (w16r2DR (Pk k) (algSp U
            (algShapeR (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k) (shOk_shield _ (Pk k) hP.hdr))
            (blkAlgDt U tag hL20 (shieldLyC hPkC k hk) (Pk k) hP.hdr hlc
              (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk))
            (card_K_gt K)) 0).Φ
            (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
            (rootsOf core) s (histOf bga.1 bga.2.1 bga.2.2 (rs.take s))
          = (algSp U
            (algShapeR (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k) (shOk_shield _ (Pk k) hP.hdr))
            (blkAlgDt U tag hL20 (shieldLyC hPkC k hk) (Pk k) hP.hdr hlc
              (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk))
            (card_K_gt K) 0
            (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
            (rootsOf core) s (histOf bga.1 bga.2.1 bga.2.2 (rs.take s))).Φ := rfl
      rw [hΦ_eq]
      exact formAt_vanish U (Pk k) _ _ bga rs s r df hr hdf hst_s hho_s hf_dArgs
    · -- Non-host slots of `w16r2RelKs 0` (`3, 19, 20`) have `SlotPoly.triv` (`Φ = 0`) in `algSp ... 0`!
      rcases Exec.Block.Join.W16.Lk.relKs0_rest s hs0 hhost with rfl | rfl | rfl <;> rfl
  · obtain ⟨s, hsio, rfl⟩ := List.mem_map.mp hio
    refine ⟨_, _, s, rfl, fun hdr core bga rs acc T' hsa _ htr => ?_⟩
    have hs23 : s < (Pk k).geom.slots.length := by
      rw [hsl23]; simp only [List.mem_cons, List.not_mem_nil, or_false] at hsio; omega
    obtain ⟨-, -, -, hslots_tr⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
      (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
    obtain ⟨⟨r, hr⟩, -, -⟩ := hslots_tr s hs23
    obtain ⟨df, hdf, -, -, hst_s, hho_s⟩ :=
      blk_unmask_at_run h64 U hU hbij tag key domain hs hL hL64 Lb preA preB start inc incG outc outcG
        Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Rn hv cx0 pin pout bp wXk gXk mXk hσ hgeo
        htB hfBM Vi F lscIn lscOut mIn kIn kOut _ _ _ _ _ _ _ _ base eL D hD hDe hPkC.toShieldRunAt
        hoAK hoHK hoIK hoOK hslB A G hE hnoX (Rp.blks.length + 2) (by omega) hM hsl k hk _ _ hdef
        hdr core bga rs acc T' hsa htr s r hr
    refine ⟨r, hr, ?_⟩
    have hoA' := hoAK k hk; rw [hopA_eq] at hoA'
    have hoH' := hoHK k hk; rw [hopH_eq] at hoH'
    have hd_eq : dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
          (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
        = dArgs tag Lq h64 (Pk k) _ _ (D.opX (k + 1)) (D.opX (k + 1 + 1)) hoA' hoH' (hoIK k hk) (hoOK k hk) := by
      congr 1
    rw [hd_eq] at hst_s hho_s
    have hf_io := formAt_ioDefSchedB U tag h64 hL20 key domain hs hL (shieldLyC hPkC k hk) (Pk k) _ hP
      hlc hep14 hk21 hk22 (shieldIoInC hPkC k hk) (shieldIoOutC hPkC k hk)
      (Exec.Block.Join.R13H.Pub.pubsR13L (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk))
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk) (shieldShape (shieldLyC hPkC k hk)).nG)
      _ _ _ _ _ _ _ _
      (D.opX (k + 1)) (D.opX (k + 1 + 1)) hoA' hoH' (hoIK k hk) (hoOK k hk) rE0 QE0 XE0
      (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
      (rootsOf core)
      (hdrX (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2
        ((RtRun.pf Rn).off (k + 1) + 5) (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
      ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2) bga rs s hsio
    exact formAt_vanish U (Pk k) _ _ bga rs s r df hr hdf hst_s hho_s hf_io

/-- **`hR1_blk` PROVED at all 26 Shieldstral layers**: every `sx ∈ D.r1 (k + 1)` (`w16r2RelKs 1`) meets `RaDefAtB`
once `¬ rtKR0.Dm` holds (`algSp_van1`). -/
theorem shield_hR1_blk
    {S0 : BlockShape} (Rp : ClassifyRunPublicP S0)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid) (bp : ∀ k, RtBlk Lq (Pk k))
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (IinA_rows IinH_rows Iin_nA Iin_nH OoutA_rows OoutH_rows Oout_nA Oout_nH : ℕ)
    (pin pout : RtPart)
    (base : ℕ → RkPart K Lq) (eL : ℕ) (D : RtKData K Lq)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn))
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)
      (rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn IinA_rows IinH_rows Iin_nA Iin_nH mIn)
        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA
          (bp k).nH)
        (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut OoutA_rows OoutH_rows Oout_nA Oout_nH))
      (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) eL)
    (hPkC : ShieldRunAtC tag Pk Rp.blks Lb)
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).1.hsl (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))))
    (hLb_eq : Lb = Rp.blks.length)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hR0 : ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2)
      (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))) :
    ∀ k, k < Lb → ∀ sx ∈ D.r1 (k + 1),
      RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx := by
  intro k hk sx hsx
  have hr1_eq : D.r1 (k + 1) = (base (k + 1)).r1 := by
    rw [hDe]; exact rxPs_r1_blk base Lb _ _ _ hk
  rw [hr1_eq, (hbBlk k hk).hr1] at hsx
  obtain ⟨s, hs1, rfl⟩ := List.mem_map.mp hsx
  obtain ⟨hP, -, hlc, -⟩ := shieldBlkAtC_spec hPkC k hk
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hparts : (RtRun.pf Rn).parts.length = Lb + 2 := RtRun.parts_length Rn
  refine ⟨_, _, s, rfl, fun hdr core bga rs acc T' hsa _ htr => ?_⟩
  have hs23 : s < (Pk k).geom.slots.length := by
    rw [hsl23]; exact (Exec.Block.w16r2RelKs_facts 1 (by norm_num)).2 s hs1
  obtain ⟨-, -, -, hslots_tr⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
    (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
  obtain ⟨⟨r, hr⟩, -, -⟩ := hslots_tr s hs23
  refine ⟨r, hr, ?_⟩
  have hgd0 : SchedGd (w16r2DR (Pk k) (algSp U
      (algShapeR (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k) (shOk_shield _ (Pk k) hP.hdr))
      (blkAlgDt U tag hL20 (shieldLyC hPkC k hk) (Pk k) hP.hdr hlc
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk))
      (card_K_gt K)) 0)
      (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
      (rootsOf core) bga rs := by
    intro s0 hs0
    have hs0_23 : s0 < (Pk k).geom.slots.length := by
      rw [hsl23]; exact (Exec.Block.w16r2RelKs_facts 0 (by norm_num)).2 s0 hs0
    have hmem0 : blkRelSq U tag hL20 (shieldLyC hPkC k hk) (Pk k) hP.hdr hlc
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) 0 s0 ∈ D.r0 (k + 1) := by
      have hr0_eq : D.r0 (k + 1) = (base (k + 1)).r0 := by rw [hDe]; exact rxPs_r0_blk base Lb _ _ _ hk
      rw [hr0_eq, (hbBlk k hk).hr0]
      exact List.mem_append_left _ (List.mem_map_of_mem hs0)
    have hvan0 := blk_defSqB_ent key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij 80 (80 * 451) D.r0 hD.r0
      (Rp.blks.length + 2) (k + 1) (by omega) (by omega) (A.runLog G).2 _ hR0 (Pk k)
      ((RtRun.pf Rn).off (k + 1) + 5) G (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1)
      hdr core bga rs acc T' hsa htr _ _ s0 hs0_23 hmem0
    exact (algSp U _ _ (card_K_gt K) 0 _ _ s0 _).hΦ hvan0
  exact algSp_van1 U _ _ (card_K_gt K) _ _ bga rs hgd0 s hs1 r hr

/-- **`hH0_blk` PROVED at all 26 Shieldstral layers**: every `sx ∈ D.h0 (k + 1)` (`w16r2RelKs 2` and `w16r2RelKs 3`)
meets `RaDefAtB` once `¬ rtKR1.Dm` holds (`algSp_van2`, `algSp_van3`). -/
theorem shield_hH0_blk
    {S0 : BlockShape} (Rp : ClassifyRunPublicP S0)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid) (bp : ∀ k, RtBlk Lq (Pk k))
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (IinA_rows IinH_rows Iin_nA Iin_nH OoutA_rows OoutH_rows Oout_nA Oout_nH : ℕ)
    (pin pout : RtPart)
    (base : ℕ → RkPart K Lq) (eL : ℕ) (D : RtKData K Lq)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn))
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)
      (rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn IinA_rows IinH_rows Iin_nA Iin_nH mIn)
        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA
          (bp k).nH)
        (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut OoutA_rows OoutH_rows Oout_nA Oout_nH))
      (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) eL)
    (hPkC : ShieldRunAtC tag Pk Rp.blks Lb)
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).1.hsl (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))))
    (hLb_eq : Lb = Rp.blks.length)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hR1 : ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2)
      (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))) :
    ∀ k, k < Lb → ∀ sx ∈ D.h0 (k + 1),
      RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx := by
  intro k hk sx hsx
  have hh0_eq : D.h0 (k + 1) = (base (k + 1)).h0 := by
    rw [hDe]; exact rxPs_h0_blk base Lb _ _ _ hk
  rw [hh0_eq, (hbBlk k hk).hh0] at hsx
  obtain ⟨hP, -, hlc, -⟩ := shieldBlkAtC_spec hPkC k hk
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hparts : (RtRun.pf Rn).parts.length = Lb + 2 := RtRun.parts_length Rn
  have hgd1_of : ∀ hdr core bga rs acc T',
      Exec.Block.SlotsAcc key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G (hdr, core) bga rs acc →
      rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)
        = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Exec.Block.allOps (Pk k) (hdr, core) ++ T') →
      SchedGd (w16r2DR (Pk k) (algSp U
        (algShapeR (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k) (shOk_shield _ (Pk k) hP.hdr))
        (blkAlgDt U tag hL20 (shieldLyC hPkC k hk) (Pk k) hP.hdr hlc
          (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk))
        (card_K_gt K)) 1)
        (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
        (rootsOf core) bga rs := by
    intro hdr core bga rs acc T' hsa htr s1 hs1
    have hs1_23 : s1 < (Pk k).geom.slots.length := by
      rw [hsl23]; exact (Exec.Block.w16r2RelKs_facts 1 (by norm_num)).2 s1 hs1
    have hmem1 : blkRelSq U tag hL20 (shieldLyC hPkC k hk) (Pk k) hP.hdr hlc
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) 1 s1 ∈ D.r1 (k + 1) := by
      have hr1_eq : D.r1 (k + 1) = (base (k + 1)).r1 := by rw [hDe]; exact rxPs_r1_blk base Lb _ _ _ hk
      rw [hr1_eq, (hbBlk k hk).hr1]
      exact List.mem_map_of_mem hs1
    have hvan1 := blk_defSqB_ent key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij 80 (80 * 451) D.r1 hD.r1
      (Rp.blks.length + 2) (k + 1) (by omega) (by omega) (A.runLog G).2 _ hR1 (Pk k)
      ((RtRun.pf Rn).off (k + 1) + 5) G (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1)
      hdr core bga rs acc T' hsa htr _ _ s1 hs1_23 hmem1
    exact (algSp U _ _ (card_K_gt K) 1 _ _ s1 _).hΦ hvan1
  simp only [blkH0, List.mem_cons, List.not_mem_nil, or_false] at hsx
  rcases hsx with rfl | rfl | rfl
  · refine ⟨_, _, 5, rfl, fun hdr core bga rs acc T' hsa _ htr => ?_⟩
    obtain ⟨-, -, -, hslots_tr⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
      (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
    obtain ⟨⟨r, hr⟩, -, -⟩ := hslots_tr 5 (by rw [hsl23]; norm_num)
    exact ⟨r, hr, algSp_van2 U _ _ (card_K_gt K) _ _ bga rs (hgd1_of hdr core bga rs acc T' hsa htr) 5
      (show 5 ∈ w16r2RelKs 2 by decide) r hr⟩
  · refine ⟨_, _, 5, rfl, fun hdr core bga rs acc T' hsa _ htr => ?_⟩
    obtain ⟨-, -, -, hslots_tr⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
      (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
    obtain ⟨⟨r, hr⟩, -, -⟩ := hslots_tr 5 (by rw [hsl23]; norm_num)
    exact ⟨r, hr, algSp_van3 U _ _ (card_K_gt K) _ _ bga rs (hgd1_of hdr core bga rs acc T' hsa htr) 5
      (show 5 ∈ w16r2RelKs 3 by decide) r hr⟩
  · refine ⟨_, _, 11, rfl, fun hdr core bga rs acc T' hsa _ htr => ?_⟩
    obtain ⟨-, -, -, hslots_tr⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
      (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
    obtain ⟨⟨r, hr⟩, -, -⟩ := hslots_tr 11 (by rw [hsl23]; norm_num)
    exact ⟨r, hr, algSp_van2 U _ _ (card_K_gt K) _ _ bga rs (hgd1_of hdr core bga rs acc T' hsa htr) 11
      (show 11 ∈ w16r2RelKs 2 by decide) r hr⟩

include hU in
/-- **`hH1_blk` PROVED at all 26 Shieldstral layers**: every `sx ∈ D.h1 (k + 1)` (`w16r2RelKs 0` on `spHR`) meets
`RaDefAtB` once `¬ EvXR`, `¬ rtKM.Dm`, `¬ rtKsl.Dm` (`helperR_formAt_r13`). -/
theorem shield_hH1_blk
    {S0 : BlockShape} (Rp : ClassifyRunPublicP S0)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid) (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k))
    (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (htB : ∀ k, (bp k).tag = tag) (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (hbpRows : ∀ k, k < Lb → (bp k).pA.rows = 4577 ∧ (bp k).pH.rows = 4390)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (IinA_rows IinH_rows Iin_nA Iin_nH OoutA_rows OoutH_rows Oout_nA Oout_nH : ℕ)
    (base : ℕ → RkPart K Lq) (eL : ℕ) (D : RtKData K Lq)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn))
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)
      (rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn IinA_rows IinH_rows Iin_nA Iin_nH mIn)
        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA
          (bp k).nH)
        (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut OoutA_rows OoutH_rows Oout_nA Oout_nH))
      (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) eL)
    (hPkC : ShieldRunAtC tag Pk Rp.blks Lb)
    (hoAK : ∀ k, k < Lb → (D.opA (k + 1)).lc = rowLog (Pk k) .a)
    (hoHK : ∀ k, k < Lb → (D.opH (k + 1)).lc = rowLog (Pk k) .h)
    (hoIK : ∀ k, k < Lb → (D.opX (k + 1)).lc = rowLog (Pk k) .inp)
    (hoOK : ∀ k, k < Lb → (D.opX (k + 1 + 1)).lc = rowLog (Pk k) .out)
    (hslB : ∀ k, k < Lb → D.sls (k + 1) = blockSchedXB (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (bwFslRun U tag Lq h64 Lb Pk (fun k => (bp k).S) D (RtRun.pf Rn) hoAK hoHK hoIK hoOK
        (shieldRunProg hPkC.toShieldRunAt) (shieldRunPubs hPkC.toShieldRunAt) k))
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).1.hsl (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))))
    (hLb_eq : Lb = Rp.blks.length)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (liftH G) (A.run G).1 (A.run G).2 = .ok ())
    (hnoX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hM : ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2)
      (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hsl : ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2)
      (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))) :
    ∀ k, k < Lb → ∀ sx ∈ D.h1 (k + 1),
      RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx := by
  intro k hk sx hsx
  have hh1_eq : D.h1 (k + 1) = (base (k + 1)).h1 := by
    rw [hDe]; exact rxPs_h1_blk base Lb _ _ _ hk
  rw [hh1_eq, (hbBlk k hk).hh1] at hsx
  obtain ⟨s, hs0, rfl⟩ := List.mem_map.mp hsx
  obtain ⟨hP, hdef, hlc, -, hk3, hk19, hk20, -, -, -, hLay⟩ := shieldBlkAtC_spec hPkC k hk
  have hLy := shieldLyC_mem hPkC k hk
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  obtain ⟨hrA, hrH⟩ := hbpRows k hk
  have hopA_eq : D.opA (k + 1) = rkOpen U tag Lq h64 key domain hs hL
      (rkR13 4577 ((RtRun.pf Rn).off (k + 1) + 5)) (bp k).nA
      (fun hdr' => (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb (k + 1) hdr').claims.a)
      ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oA + ((bp k).nA + 4577)) := by
    rw [hDe]
    show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = _
    rw [rxPs_blk base Lb _ _ _ k hk]
    simp only [rxSet, rxDblk, hrA]
    rfl
  have hopH_eq : D.opH (k + 1) = rkOpen U tag Lq h64 key domain hs hL
      (rkR13 4390 ((RtRun.pf Rn).off (k + 1) + (5 + 7))) (bp k).nH
      (fun hdr' => (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb (k + 1) hdr').claims.h
        ++ [rxLsc lscIn lscOut Pk Lb (k + 1)])
      ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH + ((bp k).nH + 4390)) := by
    rw [hDe]
    show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = _
    rw [rxPs_blk base Lb _ _ _ k hk]
    simp only [rxSet, rxDblk, hrH]
    rfl
  refine ⟨_, _, s, rfl, fun hdr core bga rs acc T' hsa _ htr => ?_⟩
  have hs23 : s < (Pk k).geom.slots.length := by
    rw [hsl23]; exact (Exec.Block.w16r2RelKs_facts 0 (by norm_num)).2 s hs0
  obtain ⟨-, -, -, hslots_tr⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
    (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
  obtain ⟨⟨r, hr⟩, -, -⟩ := hslots_tr s hs23
  obtain ⟨df, hdf, -, -, hst_s, hho_s⟩ :=
    blk_unmask_at_run h64 U hU hbij tag key domain hs hL hL64 Lb preA preB start inc incG outc outcG
      Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Rn hv cx0 pin pout bp wXk gXk mXk hσ hgeo
      htB hfBM Vi F lscIn lscOut mIn kIn kOut _ _ _ _ _ _ _ _ base eL D hD hDe hPkC.toShieldRunAt
      hoAK hoHK hoIK hoOK hslB A G hE hnoX (Rp.blks.length + 2) (by omega) hM hsl k hk _ _ hdef
      hdr core bga rs acc T' hsa htr s r hr
  refine ⟨r, hr, ?_⟩
  rcases hsa.2.2.2 with ⟨hsh', t'', hbs''⟩
  obtain ⟨-, hall_fns⟩ := blockSlots_fns (liftH G) (Pk k) core _ bga rs acc t'' hbs''
  have hslots_kind : ∀ j r', rs[j]? = some r' →
      ∃ df', (Pk k).define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r'.draws = .ok df'
        ∧ ((Pk k).kind j = SlotKind.host ↔ df'.hosted ≠ []) := by
    intro j r' hr'
    have hjc : j < core.slots.length := by
      obtain ⟨-, -, hrslen, -⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
        (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
      rw [hsh'.1, ← hrslen]
      exact (List.getElem?_eq_some_iff.mp hr').1
    obtain ⟨sp', hsp'⟩ : ∃ sp', core.slots[j]? = some sp' := ⟨_, List.getElem?_eq_getElem hjc⟩
    obtain ⟨df', hdf', -, -, -, hkind', -⟩ := hall_fns j sp' r' hsp' hr'
    exact ⟨df', hdf', hkind'⟩
  have hhosts_dXof := formAt_hostsR U hU (card_K_gt K) (shieldPbC hPkC k hk) (geoShield (shieldLyC hPkC k hk))
    (shieldLayC hPkC k hk) (shieldBC hPkC k hk) (Pk k) (shOk_shield _ (Pk k) hP.hdr)
    (profR_shield _ (Pk k) hP.hdr hP.hsl)
    (Exec.Block.Join.R13H.Tzc.tzcCfg_shield _) (Exec.Block.Join.R13H.Dzc.dzcCfg_shield _ hLy)
    (Exec.Block.Join.R13H.Qkv.qkvCfg_shieldExport _ hLy) (Exec.Block.Join.R13H.Szc.szcCfg_shield _ hLy)
    (Exec.Block.Join.R13H.Fzc.fzcCfg_shield _ hLy)
    (shieldIoInC hPkC k hk) (shieldIoOutC hPkC k hk) _ hdef
    (blkDof tag hL20 (Pk k) hlc)
    (fun cu' rt' => dXof_base_r13 tag hL20 (Pk k) hlc 4577 4390 rE0 QE0 XE0 cu' rt')
    (by show 0 < (Pk k).logCols; rw [hlc]; norm_num)
    (by show 0 < (Pk k).logCols; rw [hlc]; norm_num)
    (precR_shield _) (shieldWindows _ hLy) hLay
    (Exec.Block.Join.R13H.Pub.pubR_of_L _ _ _ _ _ U hU)
    (perRow_shield _)
    (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
    (rootsOf core) bga rs hslots_kind
  have hf_help := helperR_formAt_r13 U (card_K_gt K) (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k)
    (helpProf_shield (Pk k) hP.hdr hP.hsl) (shOk_shield _ (Pk k) hP.hdr)
    (blkAlgDt U tag hL20 (shieldLyC hPkC k hk) (Pk k) hP.hdr hlc
      (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk))
    (blkDof tag hL20 (Pk k) hlc)
    (Exec.Block.Join.R13H.Pub.gateLS (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)).sh)
    (shieldPbC hPkC k hk).exp (shieldPbC hPkC k hk).act (shieldShape (shieldLyC hPkC k hk)).nG
    hU (helpCfg_shield (shieldLyC hPkC k hk) hLy) (shieldIoInC hPkC k hk) (shieldIoOutC hPkC k hk)
    (Exec.Block.Join.R13H.Pub.pubsR13L (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk))
      (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk) (shieldShape (shieldLyC hPkC k hk)).nG)
    (by show 0 < (Pk k).logCols; rw [hlc]; norm_num) hk3 hk19 hk20
    (hgateL_shield U (shieldPbC hPkC k hk) (shieldShape (shieldLyC hPkC k hk)).nG (shieldLyC hPkC k hk)
      (shieldLayC hPkC k hk) (shieldBC hPkC k hk))
    (hrest19L (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk))
      (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk) (shieldShape (shieldLyC hPkC k hk)).nG)
    (hrest20L (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk))
      (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk) (shieldShape (shieldLyC hPkC k hk)).nG)
    (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
    (rootsOf core) bga rs hhosts_dXof s hs0
  have hsame_k : SameAH
      (dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
        (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
        (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
        (rootsOf core)
        (hdrX (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2
          ((RtRun.pf Rn).off (k + 1) + 5) (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
        ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2))
      (blkDof tag hL20 (Pk k) hlc
        (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
        (rootsOf core)) := by
    have hoA' := hoAK k hk; rw [hopA_eq] at hoA'
    have hoH' := hoHK k hk; rw [hopH_eq] at hoH'
    have hd_eq : dArgs tag Lq h64 (Pk k) (D.opA (k + 1)) (D.opH (k + 1)) (D.opX (k + 1)) (D.opX (k + 1 + 1))
          (hoAK k hk) (hoHK k hk) (hoIK k hk) (hoOK k hk)
        = dArgs tag Lq h64 (Pk k) _ _ (D.opX (k + 1)) (D.opX (k + 1 + 1)) hoA' hoH' (hoIK k hk) (hoOK k hk) := by
      congr 1
    rw [hd_eq]
    exact dArgs_sameAH_dXof U tag h64 hL20 key domain hs hL (Pk k) hlc _ _ _ _ _ _ _ _ _ _
      hoA' hoH' (hoIK k hk) (hoOK k hk) rE0 QE0 XE0 _ _ _ _ _
  have hs21 : s < 21 := by
    simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hs0
    omega
  have hf_dArgs := formAt_congr_poly U (Pk k) _ _ _ bga rs s
    (polyS_congr_ah U (Pk k) hsame_k (shieldLyC hPkC k hk) hLy _ _ _ s hs21 _)
    (fun r' df' _ hdf' hk' hmem' =>
      polyS_congr_ah U (Pk k) hsame_k (shieldLyC hPkC k hk) hLy _ _ _ hk'.1
        (progR13_hosted_lt21 _ _ _ s _ _ _ df' (hdef ▸ hdf') hk' hmem') _)
    hf_help
  exact formAt_vanish U (Pk k) _ _ bga rs s r df hr hdf hst_s hho_s hf_dArgs

/-- **Run-level `AlkL`, `TL`, `mlkL` across `k : ℕ`** (`SgIx (cfgShieldR13 Ly)` and `PrIx (cfgShieldR13 Ly) 1` are
definitionally independent of `Ly` because `(cfgShieldR13 Ly).sh = shShieldR13` by `rfl`). -/
noncomputable def shieldAlkL {S0 : BlockShape} {blks : List (RunBlock S0)}
    (hPkC : ShieldRunAtC tag Pk blks Lb) (k : ℕ)
    (cr : List (QB Lq × Dig) × Option (List UInt8)) :
    SgIx (Exec.Block.DefR13.cfgShieldR13 shieldDfltLy)
      ⊕ (PrIx (Exec.Block.DefR13.cfgShieldR13 shieldDfltLy) 1
        ⊕ PrIx (Exec.Block.DefR13.cfgShieldR13 shieldDfltLy) 1) → Tup K :=
  if hk : k < Lb then
    AlkR13B U (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k)
      (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk) (geoShield (shieldLyC hPkC k hk))
      (dofARB tag hL20 (Pk k) (shieldBlkAtC_spec hPkC k hk).2.2.1 16 256 24448 4577 4390 rE0 QE0 XE0) cr
  else fun _ => ⟨0, 0, 0, 0⟩

noncomputable def shieldTL {S0 : BlockShape} {blks : List (RunBlock S0)}
    (hPkC : ShieldRunAtC tag Pk blks Lb) (k : ℕ) : TbIx → Tup K :=
  if hk : k < Lb then
    TR13 (K := K) (shieldPbC hPkC k hk).exp (shieldPbC hPkC k hk).act (shieldShape (shieldLyC hPkC k hk)).nG
  else fun _ => ⟨0, 0, 0, 0⟩

noncomputable def shieldMlkL {S0 : BlockShape} {blks : List (RunBlock S0)}
    (hPkC : ShieldRunAtC tag Pk blks Lb) (k : ℕ)
    (cr : List (QB Lq × Dig) × Option (List UInt8)) : TbIx → K :=
  if hk : k < Lb then
    mlkR13B U (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k)
      (dofARB tag hL20 (Pk k) (shieldBlkAtC_spec hPkC k hk).2.2.1 16 256 24448 4577 4390 rE0 QE0 XE0) cr
  else fun _ => 0

include hU in
/-- **`hLU_blk` PROVED at all 26 Shieldstral layers**: every `sx ∈ D.lu (k + 1)` meets `RaLkAtB` once `¬ EvXR`,
`¬ rtKA.Dm`, `¬ rtKH1.Dm` (`hgdR_of_r13`, `rx_blk_opH`, `wr_rkOpen_sem`, `relsR_of`, `hhr_of_relsR`). -/
theorem shield_hLU_blk
    {S0 : BlockShape} (Rp : ClassifyRunPublicP S0)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid) (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k))
    (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (hBH : ∀ k, RkPcsR13 U tag (bp k).pH) (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (hbpRows : ∀ k, k < Lb → (bp k).pA.rows = 4577 ∧ (bp k).pH.rows = 4390)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (IinA_rows IinH_rows Iin_nA Iin_nH OoutA_rows OoutH_rows Oout_nA Oout_nH : ℕ)
    (base : ℕ → RkPart K Lq) (eL : ℕ) (D : RtKData K Lq)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn))
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)
      (rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn IinA_rows IinH_rows Iin_nA Iin_nH mIn)
        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA
          (bp k).nH)
        (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut OoutA_rows OoutH_rows Oout_nA Oout_nH))
      (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) eL)
    (hPkC : ShieldRunAtC tag Pk Rp.blks Lb)
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).1.hsl (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))))
    (hLb_eq : Lb = Rp.blks.length)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (liftH G) (A.run G).1 (A.run G).2 = .ok ())
    (hnoX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hA : ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2)
      (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hH1 : ¬ (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2)
      (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))) :
    ∀ k, k < Lb → ∀ sx ∈ D.lu (k + 1),
      RaLkAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (shieldAlkL hL20 U tag Lb Pk hPkC k)
        (shieldTL tag Lb Pk hPkC k)
        (shieldMlkL hL20 U tag Lb Pk hPkC k)
        G (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx := by
  intro k hk sx hsx
  have hlu_eq : D.lu (k + 1) = (base (k + 1)).lu := by
    rw [hDe]; exact rxPs_lu_blk base Lb _ _ _ hk
  rw [hlu_eq, (hbBlk k hk).hlu] at hsx
  simp only [blkLU, List.mem_singleton] at hsx
  have hAlk_eq : shieldAlkL hL20 U tag Lb Pk hPkC k
      = AlkR13B U (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k)
          (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk) (geoShield (shieldLyC hPkC k hk))
          (dofARB tag hL20 (Pk k) (shieldBlkAtC_spec hPkC k hk).2.2.1 16 256 24448 4577 4390 rE0 QE0 XE0) := by
    funext cr; exact dite_eq_left hk
  have hT_eq : shieldTL (K := K) tag Lb Pk hPkC k
      = TR13 (K := K) (shieldPbC hPkC k hk).exp (shieldPbC hPkC k hk).act (shieldShape (shieldLyC hPkC k hk)).nG :=
    dite_eq_left hk
  have hMlk_eq : shieldMlkL hL20 U tag Lb Pk hPkC k
      = mlkR13B U (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k)
          (dofARB tag hL20 (Pk k) (shieldBlkAtC_spec hPkC k hk).2.2.1 16 256 24448 4577 4390 rE0 QE0 XE0) := by
    funext cr; exact dite_eq_left hk
  rw [hAlk_eq, hT_eq, hMlk_eq]
  refine ⟨hsx, fun hdr core bga rs acc T' hsa _ htr => ?_⟩
  set τ := rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)
  set lg := (A.runLog G).2
  set absOf := Exec.Block.absOfC (chainEncB key domain hs Lq hL)
  set hdrLen := (RtRun.pf Rn).off (k + 1) + 5
  obtain ⟨hP, hdef, hlc, -, -, -, -, -, -, hls, -⟩ := shieldBlkAtC_spec hPkC k hk
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hLb26 : Lb ≤ 26 := hPkC.toShieldRunAt.lb_le
  have hk26 : k < 26 := by omega
  have hparts : (RtRun.pf Rn).parts.length = Lb + 2 := RtRun.parts_length Rn
  have hi1 : k + 1 < (RtRun.pf Rn).parts.length := by omega
  obtain ⟨_, hrH⟩ := hbpRows k hk
  -- 1. Canonical `(α, β)` from slot 0's `defineS`
  obtain ⟨-, hrt_τ, hrslen, _⟩ := blk_trace_at_slot key domain (Pk k) hdrLen G (bp k).hgt
    (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa τ htr
  rcases hsa.2.2.2 with ⟨hsh_c, t'', hbs''⟩
  obtain ⟨-, hall_fns⟩ := blockSlots_fns (liftH G) (Pk k) core _ bga rs acc t'' hbs''
  have hbga_can : bga.2.2.Canon ∧ bga.1.Canon := by
    have h0 : 0 < rs.length := by omega
    obtain ⟨r0, hr0⟩ : ∃ r0, rs[0]? = some r0 := ⟨_, List.getElem?_eq_getElem h0⟩
    obtain ⟨sp0, hsp0⟩ : ∃ sp0, core.slots[0]? = some sp0 := ⟨_, List.getElem?_eq_getElem (by rw [hsh_c.1]; omega)⟩
    obtain ⟨df0, hdf0, -⟩ := hall_fns 0 sp0 r0 hsp0 hr0
    rw [hdef] at hdf0
    have hc0 := (defineS_ok hdf0).1
    exact ⟨hc0.1, hc0.2.1⟩
  -- 2. `HGdR` from `¬ rtKH1.Dm`
  have hgdH : SchedGd (w16r2DH (Pk k) (spHR U (card_K_gt K)
      (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k) (helpProf_shield (Pk k) hP.hdr hP.hsl)
      (algShapeR (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k) (shOk_shield _ (Pk k) hP.hdr))
      (blkAlgDt U tag hL20 (shieldLyC hPkC k hk) (Pk k) hP.hdr hlc
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk))
      (blkDof tag hL20 (Pk k) hlc)
      (Exec.Block.Join.R13H.Pub.gateLS (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)).sh)
      (shieldPbC hPkC k hk).exp (shieldPbC hPkC k hk).act (shieldShape (shieldLyC hPkC k hk)).nG) 0)
      (cuts3 absOf lg (rootsOf core)) (rootsOf core) bga rs := by
    intro s0 hs0
    have hs0_23 : s0 < (Pk k).geom.slots.length := by
      rw [hsl23]; exact (Exec.Block.w16r2RelKs_facts 0 (by norm_num)).2 s0 hs0
    have hmemH1 : blkHelpSq U tag hL20 (shieldLyC hPkC k hk) (Pk k) hP.hdr hP.hsl hlc
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        hdrLen absOf s0 ∈ D.h1 (k + 1) := by
      have hh1_eq : D.h1 (k + 1) = (base (k + 1)).h1 := by rw [hDe]; exact rxPs_h1_blk base Lb _ _ _ hk
      rw [hh1_eq, (hbBlk k hk).hh1]
      exact List.mem_map_of_mem hs0
    have hvan := blk_defSqB_ent key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij 80 (80 * 451) D.h1 hD.h1
      (Rp.blks.length + 2) (k + 1) (by omega) hi1 lg τ hH1 (Pk k) hdrLen G (bp k).hgt
      (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa htr _ _ s0 hs0_23 hmemH1
    exact (spHR U (card_K_gt K) _ (Pk k) _ _ _ _ _ _ _ _ _ _ s0 _).hΦ hvan
  have hG := hgdR_of_r13 U (card_K_gt K) (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) (Pk k)
    (helpProf_shield (Pk k) hP.hdr hP.hsl) (shOk_shield _ (Pk k) hP.hdr)
    (blkAlgDt U tag hL20 (shieldLyC hPkC k hk) (Pk k) hP.hdr hlc
      (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk))
    (blkDof tag hL20 (Pk k) hlc)
    (Exec.Block.Join.R13H.Pub.gateLS (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)).sh)
    (shieldPbC hPkC k hk).exp (shieldPbC hPkC k hk).act (shieldShape (shieldLyC hPkC k hk)).nG
    (cuts3 absOf lg (rootsOf core)) (rootsOf core) bga rs hgdH
  obtain ⟨hHost, ⟨hLz, -⟩, ⟨hTab, -⟩, hzs⟩ := hG
  have hr_cfg := relCfg_shield (shieldLyC hPkC k hk)
  have hx : ∀ kh, kh ∈ algHosts → ∀ κ (hκ : κ < Exec.Slot.W16R2.segLn
      (Exec.Slot.R13.draws (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)).sh kh) .mu
      - Exec.Slot.W16R2.segLn (Exec.Slot.R13.draws (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)).sh kh) .zeta),
      Exec.Block.r13Count kh ≤ κ →
      ∀ b : Fin (Exec.Block.Join.R13H.tauLen (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)) kh) → Bool,
      xcR U (geoShield (shieldLyC hPkC k hk)) (Pk k) (blkDof tag hL20 (Pk k) hlc)
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk) kh
        (cuts3 absOf lg (rootsOf core)) (rootsOf core) bga κ b = 0 := by
    intro kh hkh κ hκ hrk b
    have e := (hHost kh hkh).1 ⟨κ, hκ⟩ b
    have e2 : (blkAlgDt U tag hL20 (shieldLyC hPkC k hk) (Pk k) hP.hdr hlc
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)).cl kh
        (cuts3 absOf lg (rootsOf core)) (rootsOf core) bga ⟨κ, hκ⟩ b
        = xcR U (geoShield (shieldLyC hPkC k hk)) (Pk k) (blkDof tag hL20 (Pk k) hlc)
            (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk) kh
            (cuts3 absOf lg (rootsOf core)) (rootsOf core) bga κ b := by
      show (if κ < Exec.Block.r13Count kh then _ else _) = _
      rw [ite_eq_right (by omega)]
    rwa [e2] at e
  -- 3. `claimSem ... (logupSumR13 c) = 0` from `rx_blk_opH` + `wr_ndA` + `wr_rkOpen_sem`
  have hσb := ra_blk_seg Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck
    bndOpen Rn cx0 pin pout bp wXk gXk mXk hσ k hk
  have hpart : (RtRun.pf Rn).part (k + 1) = rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m
      ((bp k).nH + (bp k).pH.rows) (bp k).pH.m (wXk k) (gXk k) (mXk k) := rx_part_of Rn (k + 1) _ hσb
  obtain ⟨oH⟩ := rx_blk_opH U tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Rn hv G
    (A.run G).1 (A.run G).2 hE k hk26 (bp k) (wXk k) (gXk k) (mXk k) hσb (hgeo k) (hBH k) incG outcG Lb A
    (Prod.eta (A.run G)).symm hnoX (hfBH k)
  have ndA := wr_ndA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD (Rp.blks.length + 2)
    lg τ hA (k + 1) hi1 (by omega)
  have hndH := ndA _ (List.mem_cons_of_mem _ List.mem_cons_self)
  have hopH_eq : D.opH (k + 1) = rkOpen U tag Lq h64 key domain hs hL
      (rkR13 (bp k).pH.rows ((RtRun.pf Rn).off (k + 1) + (5 + 7))) (bp k).nH
      (fun hdr' => (rkAccBlk (Pk k) hdrLen
        ((RtRun.pf Rn).off (k + 1) + (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m
          ((bp k).nH + (bp k).pH.rows) (bp k).pH.m (wXk k) (gXk k) (mXk k)).pre) hdr').claims.h
        ++ [(Pk k).logupSumClaim])
      ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH + ((bp k).nH + (bp k).pH.rows)) := by
    rw [hDe]
    show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = _
    rw [rxPs_blk base Lb _ _ _ k hk]
    simp only [rxSet, rxDblk, rxAcc_blk _ _ _ _ _ k hk, rxLsc_blk _ _ _ _ k hk, hpart]
    rfl
  rw [hopH_eq] at hndH
  have hlen_oH : (RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH ≤ τ.length := by
    have h : (τ.take ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH)).length = _ := oH.hpl
    rw [List.length_take] at h
    omega
  have sH := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL
    (rkR13 (bp k).pH.rows ((RtRun.pf Rn).off (k + 1) + (5 + 7))) (bp k).nH _ _ (rtW (RtRun.pf Rn).sqs) _ lg τ
    hndH hlen_oH oH.hpre (by have h := oH.hcnt; rw [← oH.hrd] at h; exact h)
  have hcl_wr := sH ((Pk k).logupSumClaim) (List.mem_append_right _ (List.mem_singleton_self _))
  rw [hls] at hcl_wr
  have hval0 : (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk))).value.toK U = 0 := by
    show Fp2.zero.toK U = 0
    exact Fp2.toK_zero U
  rw [hval0] at hcl_wr
  have hcl : Link.claimSem U
      ((blkDof tag hL20 (Pk k) hlc (cuts3 absOf lg (rootsOf core)) (rootsOf core)).rows .h)
      (rowLog (Pk k) .h)
      ((blkDof tag hL20 (Pk k) hlc (cuts3 absOf lg (rootsOf core)) (rootsOf core)).Q .h)
      ((blkDof tag hL20 (Pk k) hlc (cuts3 absOf lg (rootsOf core)) (rootsOf core)).X .h)
      (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk))) = 0 := by
    -- Relate `blkDof` `.h` to `wrOSem` at `oH`'s window via `claimSem_cast_lc` + `claimSem_congr_cast`
    have hpos_lt : (RtRun.pf Rn).off (k + 1) + (5 + 7)
        < (RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH := by
      have hp_pre : ((RtRun.pf Rn).part (k + 1)).pre = 15 + shapeLen (Pk k) 0 (Pk k).geom.slots := by
        rw [hpart]; rfl
      simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
      omega
    have habs_H : absAt (τ.take ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH))
        ((RtRun.pf Rn).off (k + 1) + (5 + 7)) = (rootsOf core).2.2 := by
      rw [absAt_take, ite_eq_left hpos_lt,
        show (RtRun.pf Rn).off (k + 1) + (5 + 7) = hdrLen + 7 by unfold hdrLen; omega, ← hrt_τ]
      rfl
    have henc : encGL (K := K) 14 16 256 = encG (K := K) 16 256 := encGL_14 16 256
    dsimp only [blkDof, rowLog, Exec.Block.dXof, Exec.Block.rowsOfX, Exec.Block.qOfX, Exec.Block.xOfX,
      Exec.Block.colCast]
    rw [claimSem_cast_lc U 4390 256 14 (Pk k).logCols hlc.symm
      (Link.xHof tag Lq (le64_of_le20 hL20) 16 256 24448 4390 (cuts3 absOf lg (rootsOf core)) (rootsOf core))]
    rw [hrH] at hcl_wr
    rw [← hcl_wr]
    unfold wrOSem
    dsimp only [rkOpen, rkR13, ogR13]
    refine claimSem_congr_cast U 14 4390 4390 256 256 rfl rfl _ _ (fun i t => ?_) _
    dsimp only [Link.xHof]
    rw [henc, UxW_eq_cut tag Lq h64 key domain hs hL, habs_H]
    exact congrArg₂ _ (Fin.ext rfl) (Fin.ext rfl)
  -- 4. Assemble `RelsR` and `HelperRel`
  have hrels := relsR_of U hU (geoShield (shieldLyC hPkC k hk)) (lookCfg_shield (shieldLyC hPkC k hk)) hr_cfg (Pk k)
    (blkDof tag hL20 (Pk k) hlc (cuts3 absOf lg (rootsOf core)) (rootsOf core))
    (dXof_base_r13 tag hL20 (Pk k) hlc 4577 4390 rE0 QE0 XE0 (cuts3 absOf lg (rootsOf core)) (rootsOf core))
    (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
    (Exec.Block.Join.R13H.Pub.gateLS (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)).sh)
    (shieldPbC hPkC k hk).exp (shieldPbC hPkC k hk).act (shieldShape (shieldLyC hPkC k hk)).nG
    bga hbga_can.1 hbga_can.2 hLz
    (fun j hj b => hx 14 (by decide) (13 + j) (by have := hr_cfg.bD; omega) (by show 13 ≤ 13 + j; omega) b)
    (fun j hj b => hx 15 (by decide) (4 + j) (by have := hr_cfg.bQ; omega) (by show 4 ≤ 4 + j; omega) b)
    (fun j hj b => hx 16 (by decide) (4 + j) (by have := hr_cfg.bK; omega) (by show 4 ≤ 4 + j; omega) b)
    (fun j hj b => hx 17 (by decide) (5 + j) (by have := hr_cfg.bS; omega) (by show 5 ≤ 5 + j; omega) b)
    (fun κ h1 h2 b => hx 18 (by decide) κ (by have := hr_cfg.bF; omega) h1 b)
    hTab
  refine hhr_of_relsR U hU (geoShield (shieldLyC hPkC k hk)) (lookCfg_shield (shieldLyC hPkC k hk)) (Pk k)
    (blkDof tag hL20 (Pk k) hlc (cuts3 absOf lg (rootsOf core)) (rootsOf core))
    hlc (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
    (shieldPbC hPkC k hk).exp (shieldPbC hPkC k hk).act (shieldShape (shieldLyC hPkC k hk)).nG
    bga hrels hcl hzs _ (fun l => ?_) _ (fun _ => rfl)
  rcases l with ⟨s, b⟩ | ⟨d, j, b⟩ | ⟨d, j, b⟩ <;> rfl

/-- **Extraction-coherence obligation for block `k`'s boundary planes (`hblkIO`)**: ties `epxE`'s extracted endpoint
planes `Xin`, `Xout` (`.planes k`, `.planes (k + 1)`) to `piB ∘ bndPl` read from the block's own boundary openings
`D.opX (k + 1)`, `D.opX (k + 2)` via `(shieldLayC hPkC k hk).dPos` (the residual obligation of `hblk` after
`shield_hblk` proves all R13 define-draw, helper, layout, and LogUp fields of `ShieldBlkRunData`; to be established by
the follow-up `hD`/pins/`hblkIO` lane against `epxE`'s endpoint layout). -/
def ShieldBlkIO {Pk : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPkC : ShieldRunAtC tag Pk blks Lb) (D : RtKData K Lq) (pf : RtProf)
    (k : ℕ) (hk : k < Lb) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (absOf : QB Lq → Option (List UInt8)) (Xin Xout : shieldS0.Pos → GF) : Prop :=
  (∀ p, Xin p = piB K (bndPl U tag Lq h64 (D.opX (k + 1)) (pf.off k + 2)
    (nD (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)))
    (hdrX absOf lg (pf.off (k + 1) + 5) τ)
    (Fin.append ((shieldLayC hPkC k hk).dPos p).1 ((shieldLayC hPkC k hk).dPos p).2)))
  ∧ (∀ p, Xout p = piB K (bndPl U tag Lq h64 (D.opX (k + 1 + 1)) (pf.off (k + 1) + 2)
    (nD (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hk)))
    (hdrX absOf lg (pf.off (k + 1) + 5) τ)
    (Fin.append ((shieldLayC hPkC k hk).dPos p).1 ((shieldLayC hPkC k hk).dPos p).2)))

/-- **`hblk` reduced to `ShieldBlkIO`**: on an accepted run (`classifyVerifyE = .ok ()`), `BlkLists` + `ra_blk_acc` +
`blk_trace_at_slot` + `ShieldBlkIO` produce `Nonempty (RdBlkR13B ... Rp.blks[k].pub Xin Xout)` at every `k < Rp.blks.length`. -/
theorem shield_hblk
    (Rp : ClassifyRunPublicP shieldS0)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid) (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k))
    (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (IinA_rows IinH_rows Iin_nA Iin_nH OoutA_rows OoutH_rows Oout_nA Oout_nH : ℕ)
    (base : ℕ → RkPart K Lq) (eL : ℕ) (D : RtKData K Lq)
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)
      (rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn IinA_rows IinH_rows Iin_nA Iin_nH mIn)
        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA
          (bp k).nH)
        (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut OoutA_rows OoutH_rows Oout_nA Oout_nH))
      (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) eL)
    (hPkC : ShieldRunAtC tag Pk Rp.blks Lb)
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).1.hsl (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))))
    (hLb_eq : Lb = Rp.blks.length)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (k : ℕ) (hk : k < Rp.blks.length)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (liftH G) (A.run G).1 (A.run G).2 = .ok ())
    (Xin Xout : shieldS0.Pos → GF)
    (hio : ShieldBlkIO h64 U tag Lb hPkC D (RtRun.pf Rn) k (hLb_eq.symm ▸ hk) (A.runLog G).2
      (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) Xin Xout) :
    Nonempty (RdBlkR13B U D k (A.runLog G).2
      (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (card_K_gt K) Rp.blks[k].pub Xin Xout) := by
  have hkLb : k < Lb := hLb_eq.symm ▸ hk
  have hσb := ra_blk_seg Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck
    bndOpen Rn cx0 pin pout bp wXk gXk mXk hσ k hkLb
  obtain ⟨hdr, core, bga, rs, acc, T', hsa, -, htr⟩ := ra_blk_acc Pk sgeom check paths digest bRows bLogN bndCheck
    bndOpen Rn hv G (A.run G).1 (A.run G).2 hE (k + 1) k _ hσb (bp k) (hgeo k)
  obtain ⟨hlen_τ, -, -, hslots_tr⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
    (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
  obtain ⟨hLyOpt, hblkOpt, hcal, hPb_heq, _⟩ := shieldRunAtC_spec hPkC k hkLb
  obtain ⟨hP, -, hlc, -, -, -, -, -, -, -, hLay⟩ := shieldBlkAtC_spec hPkC k hkLb
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hblk_eq : Rp.blks[k] = shieldBlkC hPkC k hkLb := (List.getElem?_eq_some_iff.mp hblkOpt).2
  refine nonempty_rdBlkR13B_of_shieldBlkRunData hL20 Rp Pk U D k hk (A.runLog G).2 _ _ Xin Xout ⟨?_⟩
  refine ⟨shieldLyC hPkC k hkLb, shieldPbC hPkC k hkLb, tag, shieldRowsOfC hPkC k hkLb,
    shieldLayC hPkC k hkLb, shieldBC hPkC k hkLb, hP, hlc, (RtRun.pf Rn).off (k + 1) + 5, rE0, QE0, XE0,
    bndPl U tag Lq h64 (D.opX (k + 1)) ((RtRun.pf Rn).off k + 2)
      (nD (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hkLb))),
    bndPl U tag Lq h64 (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off (k + 1) + 2)
      (nD (Exec.Block.DefR13.cfgShieldR13 (shieldLyC hPkC k hkLb))),
    bga, rs, List.mem_of_getElem? hLyOpt, by rw [hblk_eq]; exact hcal, by rw [hblk_eq]; exact hPb_heq,
    hLay, hio.1, hio.2, ?_, ?_, ?_, hlen_τ⟩
  · intro i hi4 s hs_rel
    have hs23 : s < (Pk k).geom.slots.length := by
      rw [hsl23]; exact (Exec.Block.w16r2RelKs_facts i hi4).2 s hs_rel
    obtain ⟨-, hpos, hhist⟩ := hslots_tr s hs23
    refine ⟨?_, hpos, [], hhist⟩
    have hi' : i = 0 ∨ i = 1 ∨ i = 2 ∨ i = 3 := by omega
    rcases hi' with rfl | rfl | rfl | rfl
    · refine Or.inl ?_
      have hr0_eq : D.r0 (k + 1) = (base (k + 1)).r0 := by rw [hDe]; exact rxPs_r0_blk base Lb _ _ _ hkLb
      rw [hr0_eq, (hbBlk k hkLb).hr0]
      exact List.mem_append_left _ (List.mem_map_of_mem hs_rel)
    · refine Or.inr (Or.inl ?_)
      have hr1_eq : D.r1 (k + 1) = (base (k + 1)).r1 := by rw [hDe]; exact rxPs_r1_blk base Lb _ _ _ hkLb
      rw [hr1_eq, (hbBlk k hkLb).hr1]
      exact List.mem_map_of_mem hs_rel
    · refine Or.inr (Or.inr (Or.inl ?_))
      have hh0_eq : D.h0 (k + 1) = (base (k + 1)).h0 := by rw [hDe]; exact rxPs_h0_blk base Lb _ _ _ hkLb
      rw [hh0_eq, (hbBlk k hkLb).hh0]
      simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hs_rel
      rcases hs_rel with rfl | rfl
      · exact List.mem_cons.mpr (Or.inl rfl)
      · exact List.mem_cons.mpr (Or.inr (List.mem_cons.mpr (Or.inr (List.mem_singleton.mpr rfl))))
    · refine Or.inr (Or.inr (Or.inl ?_))
      have hh0_eq : D.h0 (k + 1) = (base (k + 1)).h0 := by rw [hDe]; exact rxPs_h0_blk base Lb _ _ _ hkLb
      rw [hh0_eq, (hbBlk k hkLb).hh0]
      simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hs_rel
      subst hs_rel
      exact List.mem_cons.mpr (Or.inr (List.mem_cons.mpr (Or.inl rfl)))
  · intro s hs_io
    have hs23 : s < (Pk k).geom.slots.length := by
      rw [hsl23]; simp only [List.mem_cons, List.not_mem_nil, or_false] at hs_io; omega
    obtain ⟨-, hpos, hhist⟩ := hslots_tr s hs23
    refine ⟨Or.inl ?_, hpos, [], hhist⟩
    have hr0_eq : D.r0 (k + 1) = (base (k + 1)).r0 := by rw [hDe]; exact rxPs_r0_blk base Lb _ _ _ hkLb
    rw [hr0_eq, (hbBlk k hkLb).hr0]
    exact List.mem_append_right _ (List.mem_map_of_mem hs_io)
  · have hlu_eq : D.lu (k + 1) = (base (k + 1)).lu := by rw [hDe]; exact rxPs_lu_blk base Lb _ _ _ hkLb
    rw [hlu_eq, (hbBlk k hkLb).hlu]
    exact List.mem_singleton_self _

end FiveBlockTheorems

end BlkAliveRun

/-! ## 6. Top theorem on `shieldS0` (`sshC_productionReadyL_epP_blkAlive`) -/

namespace RunShapeP

section SshTopBlkAlive

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code ZK60.RunShape
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)
open ZK60.D76 (classifyLeak LeaksAtMost productionReadyL_of_productionReady productionReadyL_of_productionReady_range)
open ZK60.ProtocolClassify (ClsHdrW clsHdrOf clsStart ShieldRunAtC BlkLists blkR0 blkR1 blkH0 blkH1 blkLU
  shieldLyC shieldPbC shieldLayC shieldBC shieldBlkAtC_spec shieldDfltLy shieldAlkL shieldTL shieldMlkL ShieldBlkIO
  shield_hoAK shield_hoHK shield_hoIK shield_hoOK shield_hR0_blk shield_hR1_blk shield_hH0_blk shield_hH1_blk
  shield_hLU_blk shield_hblk)
open ZK60.RunShape.Shield (shieldS0)

variable {Hdr Coins : Type}
variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (Rr dR : ℕ) {pos : shieldS0.Tok → Fin dR × Fin (2 ^ 8)} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (hplace : Function.Injective place) (tag : MTag)
local notation "CinS" =>
  epTokenCommit (St := ClsStmt Hdr) Rr dR hpos place (ZK60.ProtocolClassify.epxMsg Rr dR place pos)
    (ZK60.ProtocolClassify.epxMsg_place Rr dR place pos hplace) ZK60.ProtocolClassify.EpxSalt.pads
    ZK60.ProtocolClassify.EpxSalt.salts ZK60.ProtocolClassify.EpxSalt.paths ClsStmt.inRoot tag

/-- **THE SHIELDSTRAL T128 R13 CLASSIFIER TOP THEOREM WITH THE FIVE BLOCK ALIVE STATEMENTS PROVED FOR `hbBlk`** (D63
lane L64): `sshC_productionReadyL_epP_dg` specialized to `S := shieldS0` under `hPkC : ShieldRunAtC`,
`hL20 : 2 ^ 20 ≤ Lq`, `hbpRows`, and `hbBlk : BlkLists (base (k + 1)) ...` (`hD` unchanged; `eL` remains a free
parameter; `blkLists_rkSqOk` is stated separately at `eL = 2^26` and not used here, pending deriving `hhi` from the
profile and proving the other 11 `RkPart.Ok` conjunct groups), proving:
* `hoAK`, `hoHK`, `hoIK`, `hoOK` from `hDe`, `hgX*`, and `hPkC` (whose `endpointLogN = 14` replaces L62's separate
  `hep14`),
* **`hR0_blk`**, **`hR1_blk`**, **`hH0_blk`**, **`hH1_blk`**, **`hLU_blk`** (`shield_hR0_blk..shield_hLU_blk`) for the
  squeeze lists pinned by `hbBlk`, given `hbpRows`, `hPkC`, and the unchanged `hD`, `hDe`, `hslB`,
instantiating `ιL`, `πL`, `κL` and `AlkL`, `TL`, `mlkL` (`shieldAlkL`, `shieldTL`, `shieldMlkL`),
and reducing **`hblk`** (`Nonempty (RdBlkR13B ...)`) to the extraction-coherence obligation **`hblkIO`**
(`ShieldBlkIO`). -/
theorem sshC_productionReadyL_epP_blkAlive
    (Rp : ClassifyRunPublicP shieldS0)
    (Lq : ℕ)
    (Lb : ℕ)
    (hL20 : 2 ^ 20 ≤ Lq)
    (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr)
    (inc : Hdr → IncV)
    (incG : Hdr → StageGeom)
    (Pk : ℕ → Exec.Block.BlockParams)
    (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom)
    (check : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →
      Except String Tr)
    (outc : Hdr → ℕ → OutcV)
    (outcG : Hdr → StageGeom)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
    (h64 : 64 ≤ Lq)
    (hr : 8 * (CinS).R ≤ Lq)
    (hon : HonestIn Coins (CinS))
    (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (key : Option Dig)
    (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq)
    (hL64 : Lq < 2 ^ 64)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid)
    (hw : Hdr → ClsHdrW)
    (hRn : ∀ s, RtRun.hdr Rn s = clsHdrOf hw s)
    (D : RtKData K Lq)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn))
    {ι : Type}
    [Fintype ι]
    (site : (shieldS0.Tok → ℕ) → ι → Site (QB Lq) Coins K)
    (kOf : ι → ℕ)
    (δOf : ι → ℝ≥0∞)
    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 (ZK60.ProtocolClassify.EpxSalt Rr))
    {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpenP Rp Lq (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      P (CinS) h64 hr hon U site kOf δOf εzk)
    (hU : U ^ 2 = algebraMap GF K 7)
    (cx0 : IncCtx)
    (pin pout : RtPart)
    (Iin : RtInc Lq inc incG pin)
    (Oout : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k))
    (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (hIA : RkPcsAt U tag ogStage Iin.pA)
    (hIH : RkPcsAt U tag ogStage Iin.pH)
    (hOA : RkPcsAt U tag ogStage Oout.pA)
    (hOH : RkPcsAt U tag ogStage Oout.pH)
    (hBA : ∀ k, RkPcsR13 U tag (bp k).pA)
    (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (htI : Iin.tag = tag)
    (htO : Oout.tag = tag)
    (htB : ∀ k, (bp k).tag = tag)
    (hfIA : 8 * Iin.pA.rows ≤ Lq)
    (hfIH : 8 * Iin.pH.rows ≤ Lq)
    (hfOA : 8 * Oout.pA.rows ≤ Lq)
    (hfOH : 8 * Oout.pH.rows ≤ Lq)
    (hfBA : ∀ k, 8 * (bp k).pA.rows ≤ Lq)
    (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (hfIM : 8 * (2 * pin.S + 4) ≤ Lq)
    (hfOM : 8 * (2 * pout.S + 4) ≤ Lq)
    (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (hbpRows : ∀ k, k < Lb → (bp k).pA.rows = 4577 ∧ (bp k).pH.rows = 4390)
    (Vi : IncV)
    (F : ℕ → OutcV)
    (hinc : ∀ hd, inc hd = Vi)
    (houtc : ∀ hd v, outc hd v = F v)
    (hchk : ∀ s : ClsStmt Hdr, check s 0 = .ok () → s.verdict ≤ 1)
    (hLb1 : 0 < Lb)
    (lscIn lscOut : Exec.Block.ZClaim)
    (mIn kIn kOut : ℕ)
    (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut)
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn)
    (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
    (base : ℕ → RkPart K Lq)
    (eL : ℕ)
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)
      (rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)
        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA
          (bp k).nH)
        (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH))
      (rxAcc (ZK60.ProtocolClassify.vdWin Vi) (ZK60.ProtocolClassify.vdWout F) Pk (RtRun.pf Rn) Lb)
      (rxLsc lscIn lscOut Pk Lb) eL)
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (hXk : ∀ k, ZK60.ProtocolClassify.RkPcsR13 U tag (pXk k))
    (hwXk : ∀ k, k + 1 < Lb → wXk (k + 1) = (bp k).nOut + (bp (k + 1)).nIn + (pXk (k + 1)).rows)
    (hmXk : ∀ k, k + 1 < Lb → mXk (k + 1) = (pXk (k + 1)).m)
    (hfitXk : ∀ k, 8 * (pXk k).rows ≤ Lq)
    (hgXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).gX
      = ZK60.ProtocolClassify.rkR13 (pXk (k + 1)).rows ((RtRun.pf Rn).off (k + 1) + 2))
    (hnXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).nX = (bp k).nOut + (bp (k + 1)).nIn)
    (hwX0 : wXk 0 = Iin.nOut + (bp 0).nIn + (pXk 0).rows)
    (hmX0 : mXk 0 = (pXk 0).m)
    (hgX1 : (base 1).gX = ZK60.ProtocolClassify.rkR13 (pXk 0).rows ((RtRun.pf Rn).off 0 + 2))
    (hnX1 : (base 1).nX = Iin.nOut + (bp 0).nIn)
    (hOX : ZK60.ProtocolClassify.RkPcsR13 U tag Oout.pX)
    (hwXo : ∀ k, k + 1 = Lb → pout.wX = (bp k).nOut + Oout.nIn + Oout.pX.rows)
    (hfitXo : 8 * Oout.pX.rows ≤ Lq)
    (hgXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).gX
      = ZK60.ProtocolClassify.rkR13 Oout.pX.rows ((RtRun.pf Rn).off (k + 1) + 2))
    (hnXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).nX = (bp k).nOut + Oout.nIn)
    (hgX0 : (base 0).gX = rkAt ogEp Iin.pX.rows 1)
    (hnX0 : (base 0).nX = Iin.nIn)
    (hXep : RkPcsAt U tag ogEp Iin.pX)
    (hfitX : 8 * Iin.pX.rows ≤ Lq)
    (hRr : Iin.pX.rows = Rr)
    (hL81 : 81 ≤ Lq)
    (hPkC : ShieldRunAtC tag Pk Rp.blks Lb)
    (hslB : ∀ k, k < Lb → D.sls (k + 1) = Exec.Block.blockSchedXB (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      ((ZK60.ProtocolClassify.bwFslRun U tag Lq h64 Lb Pk (fun k => (bp k).S) D (RtRun.pf Rn)
        (shield_hoAK hDe (fun _ _ => rfl) hPkC.toShieldRunAt)
        (shield_hoHK hDe (fun _ _ => rfl) hPkC.toShieldRunAt)
        (shield_hoIK hDe (by rw [hgX1]; rfl) (fun j hj => by rw [hgXk j hj]; rfl) hPkC.ep14)
        (shield_hoOK hDe (fun j hj => by rw [hgXk j hj]; rfl) (fun j hj => by rw [hgXo j hj]; rfl) hPkC.ep14)
        (ZK60.ProtocolClassify.shieldRunProg hPkC.toShieldRunAt)
        (ZK60.ProtocolClassify.shieldRunPubs hPkC.toShieldRunAt)) k))
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).2.2.1 (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).1.hdr
        (shieldBlkAtC_spec hPkC k hk).1.hsl (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyC hPkC k hk) (Pk k) (shieldBlkAtC_spec hPkC k hk).2.2.1
        (shieldPbC hPkC k hk) (shieldLayC hPkC k hk) (shieldBC hPkC k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))))
    (P0in P0out : Exec.Block.BlockParams)
    (csIOI csIOO : StgVw Lq → Exec.Block.Cm → Exec.Block.ZClaim → K)
    (hIOI : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOI v cm { z with value := a } = csIOI v cm z)
    (hIOO : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOO v cm { z with value := a } = csIOO v cm z)
    (hNin : ∀ k, k < P0in.geom.slots.length → 0 < stgN P0in k ∧ stgN P0in k * (Exec.Block.slotShape P0in k).2.2 + 2 ≤ 512)
    (hNout : ∀ k, k < P0out.geom.slots.length → 0 < stgN P0out k ∧ stgN P0out k * (Exec.Block.slotShape P0out k).2.2 + 2 ≤ 512)
    (hN64I : ∀ k, k < P0in.geom.slots.length → stgN P0in k < 64)
    (hN64O : ∀ k, k < P0out.geom.slots.length → stgN P0out k < 64)
    (hIOlI : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off 0 + 5 + (7 + mIn)) csIOI)
    (hIOlO : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off (Lb + 1) + 2 + (7 + 2)) csIOO)
    (eI eO : ℕ)
    (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (hb0 : StgLists (base 0) (stgSchedV P0in mIn ((RtRun.pf Rn).off 0 + 5) ZK60.ProtocolClassify.stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstIC U hbij tag h64 P0in (ZK60.ProtocolClassify.vdWin Vi) ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows pin.S csIOI))
      (stgDefsV P0in mIn ((RtRun.pf Rn).off 0 + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.sshΦIC U hbij tag h64 P0in Vi ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows csIOI) ZK60.ProtocolClassify.sshDgI) (stgLkSqV mIn ((RtRun.pf Rn).off 0 + 5) eI (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI))
    (hbL : StgLists (base (Lb + 1)) (stgSchedV P0out 2 ((RtRun.pf Rn).off (Lb + 1) + 2) (ZK60.ProtocolClassify.stgHostOut P0out) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstO U hbij tag h64 P0out (ZK60.ProtocolClassify.vdWout F) ((RtRun.pf Rn).off (Lb + 1) + pout.pre) ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows pout.S csIOO))
      (stgDefsV P0out 2 ((RtRun.pf Rn).off (Lb + 1) + 2) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.sshΦO U hbij tag h64 P0out F ((RtRun.pf Rn).off (Lb + 1) + pout.pre) ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows csIOO) ZK60.ProtocolClassify.sshDgO) (stgLkSqV 2 ((RtRun.pf Rn).off (Lb + 1) + 2) eO (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO))
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx))
    (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (hTrIIO : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ZK60.ProtocolClassify.StgClaimsIOC U key domain (inc (A.run G).1.hdr) mIn ((RtRun.pf Rn).off 0 + 5) ((RtRun.pf Rn).off 0 + pin.pre) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows ((RtRun.pf Rn).off 0 + 5) ((RtRun.pf Rn).off 0 + 5 + 4 + mIn) csIOI) G (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hTrOIO : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ZK60.ProtocolClassify.StgClaimsIOCO U key domain (outc (A.run G).1.hdr (A.run G).1.verdict).bp ((RtRun.pf Rn).off (Lb + 1) + 2) ((RtRun.pf Rn).off (Lb + 1) + pout.pre) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows ((RtRun.pf Rn).off (Lb + 1) + 2) ((RtRun.pf Rn).off (Lb + 1) + 2 + 4 + 2) csIOO) G (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hLI_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      StgLkAtV U key domain (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hLO_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      StgLkAtV U key domain (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 ((RtRun.pf Rn).off (Lb + 1) + 2) OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdinS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ InOkP Rp ((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ZK60.ProtocolClassify.StgDoomAtV U key domain P0in (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) ZK60.ProtocolClassify.stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstIC U hbij tag h64 P0in (ZK60.ProtocolClassify.vdWin Vi) ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows pin.S csIOI) (ZK60.ProtocolClassify.sshΦIC U hbij tag h64 P0in Vi ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows csIOI) ZK60.ProtocolClassify.sshDgI eI ΛI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hblkIO : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < Rp.blks.length),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ShieldBlkIO h64 U tag Lb hPkC D (RtRun.pf Rn) k
        (Nat.lt_of_lt_of_eq hk (O.blocks.2.symm : Rp.blks.length = Lb)) (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        (((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)))
    (hdoutS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ OutOkP Rp ((classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).ypub (A.runLog G).1.1)
        ((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ZK60.ProtocolClassify.StgDoomAtV U key domain P0out (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 ((RtRun.pf Rn).off (Lb + 1) + 2) OutcV.bga (ZK60.ProtocolClassify.stgHostOut P0out) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstO U hbij tag h64 P0out (ZK60.ProtocolClassify.vdWout F) ((RtRun.pf Rn).off (Lb + 1) + pout.pre) ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows pout.S csIOO) (ZK60.ProtocolClassify.sshΦO U hbij tag h64 P0out F ((RtRun.pf Rn).off (Lb + 1) + pout.pre) ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows csIOO) ZK60.ProtocolClassify.sshDgO eO ΛO G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hLay : ZK60.ProtocolClassify.StgInLay pos Vi.pub.tokens Vi.pub.inEpWords)
    (hdzW : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      (∃ (k : Fin dR) (i : Fin (2 ^ 8)), Vi.pub.tokens ≤ k.val * 2 ^ 8 + i.val
        ∧ k.val * 2 ^ 8 + i.val < Vi.pub.inEpWords ∧ ((CinS).decodeIn ((ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) (A.runLog G).2 (A.runLog G).1.1) 768).1 ((CinS).place k) i ≠ 0)
  →
      ZK60.ProtocolClassify.StgDoomAtV U key domain P0in (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) ZK60.ProtocolClassify.stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstIC U hbij tag h64 P0in (ZK60.ProtocolClassify.vdWin Vi) ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows pin.S csIOI) (ZK60.ProtocolClassify.sshΦIC U hbij tag h64 P0in Vi ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows csIOI) ZK60.ProtocolClassify.sshDgI eI ΛI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hzk : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 → εzk q R' ≤ εzkTarget q R') :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG
        (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  sshC_productionReadyL_epP_dg (Rr := Rr) (dR := dR) (hpos := hpos) (place := place) (hplace := hplace) (tag := tag)
    (Rp := Rp) (Lq := Lq) (Lb := Lb) (preA := preA) (preB := preB) (start := start)
    (inc := inc) (incG := incG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths)
    (digest := digest) (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (outc := outc)
    (outcG := outcG) (P := P) (h64 := h64) (hr := hr) (hon := hon) (U := U)
    (hbij := hbij) (key := key) (domain := domain) (hs := hs) (hL := hL) (hL64 := hL64)
    (Rn := Rn) (hv := hv) (hw := hw) (hRn := hRn) (D := D) (hD := hD)
    (ι := ι) (site := site) (kOf := kOf) (δOf := δOf) (E0 := E0) (εzk := εzk)
    (O := O) (hU := hU) (cx0 := cx0) (pin := pin) (pout := pout) (Iin := Iin)
    (Oout := Oout) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ)
    (hgeo := hgeo) (hIA := hIA) (hIH := hIH) (hOA := hOA) (hOH := hOH) (hBA := hBA)
    (hBH := hBH) (htI := htI) (htO := htO) (htB := htB) (hfIA := hfIA) (hfIH := hfIH)
    (hfOA := hfOA) (hfOH := hfOH) (hfBA := hfBA) (hfBH := hfBH) (hfIM := hfIM) (hfOM := hfOM)
    (hfBM := hfBM) (Vi := Vi) (F := F) (hinc := hinc) (houtc := houtc) (hchk := hchk)
    (hLb1 := hLb1) (lscIn := lscIn) (lscOut := lscOut) (mIn := mIn) (kIn := kIn) (kOut := kOut)
    (hlscIn := hlscIn) (hlscOut := hlscOut) (hmIn := hmIn) (hkIn := hkIn) (hkOut := hkOut) (base := base)
    (eL := eL) (hDe := hDe) (pXk := pXk) (hXk := hXk) (hwXk := hwXk) (hmXk := hmXk)
    (hfitXk := hfitXk) (hgXk := hgXk) (hnXk := hnXk) (hwX0 := hwX0) (hmX0 := hmX0) (hgX1 := hgX1)
    (hnX1 := hnX1) (hOX := hOX) (hwXo := hwXo) (hfitXo := hfitXo) (hgXo := hgXo) (hnXo := hnXo)
    (hgX0 := hgX0) (hnX0 := hnX0) (hXep := hXep) (hfitX := hfitX) (hRr := hRr) (hL81 := hL81)
    (hPk := hPkC.toShieldRunAt)
    (hoAK := shield_hoAK hDe (fun _ _ => rfl) hPkC.toShieldRunAt)
    (hoHK := shield_hoHK hDe (fun _ _ => rfl) hPkC.toShieldRunAt)
    (hoIK := shield_hoIK hDe (by rw [hgX1]; rfl) (fun j hj => by rw [hgXk j hj]; rfl) hPkC.ep14)
    (hoOK := shield_hoOK hDe (fun j hj => by rw [hgXk j hj]; rfl) (fun j hj => by rw [hgXo j hj]; rfl) hPkC.ep14)
    (hslB := hslB)
    (ιL := fun _ => ZK60.Exec.Block.Join.R13H.Look.SgIx (Exec.Block.DefR13.cfgShieldR13 shieldDfltLy))
    (πL := fun _ => ZK60.Exec.Block.Join.R13H.Look.PrIx (Exec.Block.DefR13.cfgShieldR13 shieldDfltLy) 1)
    (κL := fun _ => ZK60.Exec.Block.Join.R13H.Look.TbIx)
    (AlkL := shieldAlkL hL20 U tag Lb Pk hPkC)
    (TL := shieldTL tag Lb Pk hPkC)
    (mlkL := shieldMlkL hL20 U tag Lb Pk hPkC)
    (P0in := P0in) (P0out := P0out) (csIOI := csIOI) (csIOO := csIOO) (hIOI := hIOI) (hIOO := hIOO)
    (hNin := hNin) (hNout := hNout) (hN64I := hN64I) (hN64O := hN64O) (hIOlI := hIOlI) (hIOlO := hIOlO)
    (eI := eI) (eO := eO) (ΛI := ΛI) (ΛO := ΛO)
    (hb0 := hb0) (hbL := hbL) (hPin := hPin) (hPout := hPout)
    (hTrIIO := hTrIIO) (hTrOIO := hTrOIO)
    (hR0_blk := fun A G hv' hx' _ hM _ hsl => by
      have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG
        (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768 G _ _ hv'
      rw [OC.runLog_fst] at hE0
      exact shield_hR0_blk (h64 := h64) (hL20 := hL20) (U := U) (hU := hU) (hbij := hbij) (tag := tag)
        (key := key) (domain := domain) (hs := hs) (hL := hL) (hL64 := hL64) (Lb := Lb)
        (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG)
        (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
        (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen)
        (Rp := Rp) (Rn := Rn) (hv := hv) (cx0 := cx0) (pin := pin) (pout := pout) (bp := bp)
        (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ) (hgeo := hgeo) (htB := htB) (hfBM := hfBM)
        (hbpRows := hbpRows) (Vi := Vi) (F := F) (lscIn := lscIn) (lscOut := lscOut)
        (mIn := mIn) (kIn := kIn) (kOut := kOut)
        (IinA_rows := _) (IinH_rows := _) (Iin_nA := _) (Iin_nH := _)
        (OoutA_rows := _) (OoutH_rows := _) (Oout_nA := _) (Oout_nH := _)
        (base := base) (eL := eL) (D := D) (hD := hD) (hDe := hDe) (hPkC := hPkC)
        (hoAK := _) (hoHK := _) (hoIK := _) (hoOK := _) (hslB := hslB) (hbBlk := hbBlk)
        (hLb_eq := (O.blocks.2 : Lb = Rp.blks.length)) (A := A) (G := G)
        (hE := hE0) (hnoX := fun h => hx' (Or.inl h)) (hM := hM) (hsl := hsl))
    (hR1_blk := fun A G _ _ _ _ _ _ hR0 =>
      shield_hR1_blk (h64 := h64) (hL20 := hL20) (U := U) (hbij := hbij) (tag := tag)
        (key := key) (domain := domain) (hs := hs) (hL := hL) (hL64 := hL64) (Lb := Lb)
        (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG)
        (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
        (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen)
        (Rp := Rp) (Rn := Rn) (hv := hv) (bp := bp) (Vi := Vi) (F := F) (lscIn := lscIn) (lscOut := lscOut)
        (mIn := mIn) (kIn := kIn) (kOut := kOut)
        (IinA_rows := _) (IinH_rows := _) (Iin_nA := _) (Iin_nH := _)
        (OoutA_rows := _) (OoutH_rows := _) (Oout_nA := _) (Oout_nH := _)
        (pin := pin) (pout := pout) (base := base) (eL := eL) (D := D) (hD := hD) (hDe := hDe) (hPkC := hPkC)
        (hbBlk := hbBlk) (hLb_eq := (O.blocks.2 : Lb = Rp.blks.length)) (A := A) (G := G) (hR0 := hR0))
    (hH0_blk := fun A G _ _ _ _ _ _ _ hR1 =>
      shield_hH0_blk (h64 := h64) (hL20 := hL20) (U := U) (hbij := hbij) (tag := tag)
        (key := key) (domain := domain) (hs := hs) (hL := hL) (hL64 := hL64) (Lb := Lb)
        (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG)
        (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
        (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen)
        (Rp := Rp) (Rn := Rn) (hv := hv) (bp := bp) (Vi := Vi) (F := F) (lscIn := lscIn) (lscOut := lscOut)
        (mIn := mIn) (kIn := kIn) (kOut := kOut)
        (IinA_rows := _) (IinH_rows := _) (Iin_nA := _) (Iin_nH := _)
        (OoutA_rows := _) (OoutH_rows := _) (Oout_nA := _) (Oout_nH := _)
        (pin := pin) (pout := pout) (base := base) (eL := eL) (D := D) (hD := hD) (hDe := hDe) (hPkC := hPkC)
        (hbBlk := hbBlk) (hLb_eq := (O.blocks.2 : Lb = Rp.blks.length)) (A := A) (G := G) (hR1 := hR1))
    (hH1_blk := fun A G hv' hx' _ hM _ hsl _ _ _ => by
      have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG
        (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768 G _ _ hv'
      rw [OC.runLog_fst] at hE0
      exact shield_hH1_blk (h64 := h64) (hL20 := hL20) (U := U) (hU := hU) (hbij := hbij) (tag := tag)
        (key := key) (domain := domain) (hs := hs) (hL := hL) (hL64 := hL64) (Lb := Lb)
        (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG)
        (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
        (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen)
        (Rp := Rp) (Rn := Rn) (hv := hv) (cx0 := cx0) (pin := pin) (pout := pout) (bp := bp)
        (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ) (hgeo := hgeo) (htB := htB) (hfBM := hfBM)
        (hbpRows := hbpRows) (Vi := Vi) (F := F) (lscIn := lscIn) (lscOut := lscOut)
        (mIn := mIn) (kIn := kIn) (kOut := kOut)
        (IinA_rows := _) (IinH_rows := _) (Iin_nA := _) (Iin_nH := _)
        (OoutA_rows := _) (OoutH_rows := _) (Oout_nA := _) (Oout_nH := _)
        (base := base) (eL := eL) (D := D) (hD := hD) (hDe := hDe) (hPkC := hPkC)
        (hoAK := _) (hoHK := _) (hoIK := _) (hoOK := _) (hslB := hslB) (hbBlk := hbBlk)
        (hLb_eq := (O.blocks.2 : Lb = Rp.blks.length)) (A := A) (G := G)
        (hE := hE0) (hnoX := fun h => hx' (Or.inl h)) (hM := hM) (hsl := hsl))
    (hLU_blk := fun A G hv' hx' _ _ hA _ _ _ _ hH1 => by
      have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG
        (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768 G _ _ hv'
      rw [OC.runLog_fst] at hE0
      exact shield_hLU_blk (h64 := h64) (hL20 := hL20) (U := U) (hU := hU) (hbij := hbij) (tag := tag)
        (key := key) (domain := domain) (hs := hs) (hL := hL) (hL64 := hL64) (Lb := Lb)
        (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG)
        (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
        (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen)
        (Rp := Rp) (Rn := Rn) (hv := hv) (cx0 := cx0) (pin := pin) (pout := pout) (bp := bp)
        (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ) (hgeo := hgeo) (hBH := hBH) (hfBH := hfBH)
        (hbpRows := hbpRows) (Vi := Vi) (F := F) (lscIn := lscIn) (lscOut := lscOut)
        (mIn := mIn) (kIn := kIn) (kOut := kOut)
        (IinA_rows := _) (IinH_rows := _) (Iin_nA := _) (Iin_nH := _)
        (OoutA_rows := _) (OoutH_rows := _) (Oout_nA := _) (Oout_nH := _)
        (base := base) (eL := eL) (D := D) (hD := hD) (hDe := hDe) (hPkC := hPkC)
        (hbBlk := hbBlk) (hLb_eq := (O.blocks.2 : Lb = Rp.blks.length)) (A := A) (G := G)
        (hE := hE0) (hnoX := fun h => hx' (Or.inl h)) (hA := hA) (hH1 := hH1))
    (hLI_stg := hLI_stg) (hLO_stg := hLO_stg)
    (hdinS := hdinS)
    (hblk := fun A G k hk hv' hx' => by
      have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG
        (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768 G _ _ hv'
      rw [OC.runLog_fst] at hE0
      exact shield_hblk (h64 := h64) (hL20 := hL20) (U := U) (tag := tag)
        (key := key) (domain := domain) (hs := hs) (hL := hL) (Lb := Lb)
        (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG)
        (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
        (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen)
        (Rp := Rp) (Rn := Rn) (hv := hv) (cx0 := cx0) (pin := pin) (pout := pout) (bp := bp)
        (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ) (hgeo := hgeo)
        (Vi := Vi) (F := F) (lscIn := lscIn) (lscOut := lscOut)
        (mIn := mIn) (kIn := kIn) (kOut := kOut)
        (IinA_rows := _) (IinH_rows := _) (Iin_nA := _) (Iin_nH := _)
        (OoutA_rows := _) (OoutH_rows := _) (Oout_nA := _) (Oout_nH := _)
        (base := base) (eL := eL) (D := D) (hDe := hDe) (hPkC := hPkC) (hbBlk := hbBlk)
        (hLb_eq := (O.blocks.2 : Lb = Rp.blks.length)) (A := A) (G := G) (k := k) (hk := hk)
        (hE := hE0) (Xin := _) (Xout := _) (hio := hblkIO A G k hk hv' hx'))
    (hdoutS := hdoutS) (hLay := hLay) (hdzW := hdzW) (hzk := hzk)

end SshTopBlkAlive

end RunShapeP

end ZK60.ProtocolClassify
