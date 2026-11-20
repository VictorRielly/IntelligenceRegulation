/-
D63 lane L66 (2026-11-17): **concrete `base` and `D` (`eL = 2^26`) eliminating all 16 structural schedule/list pins,
full 16-conjunct block `RkPart.Ok` (`hhi` derived from the profile, `(bp k).S = 23` via `maskField_inj_S`), stage
`RkPart.Ok` wired through `stgDefsV_valid_inC`/`stgDefsV_valid_out`, and `hblkIO` proved via oracle-independent
`bndPlanes` / `epxBndE` under cross-block carrier layout coherence (`ShieldRunAtD`)**.

What is constructed and proved here (closing `L64_REVIEW.md` `M1`, `M2`, `M3`, `N9`):
1. **Cross-block carrier layout bundle (`ShieldBlkAtD`, `ShieldRunAtD`, `shieldDPos0`):**
   * `shieldDPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)` (`(msbBits 7 p.1.val, msbBits 12 p.2.val)`), with
     `shieldDPos0_injective` proved from `ExecMle.msbIndex_msbBits`;
   * `ShieldBlkAtD tag dPos0 P Ly Pb` and `ShieldRunAtD tag dPos0 Pk blks Lb` strengthen `ShieldBlkAtC` / `ShieldRunAtC`
     by placing `Lay.dPos = dPos0` **inside** `ShieldBlkAtD`'s existential (so `(shieldLayD hPkD k hk).dPos = dPos0`
     follows directly from `Classical.choose_spec` with no `Classical.choose` non-uniqueness hazard even on zero public
     weights);
   * `shieldAlkLD`, `shieldTLD`, `shieldMlkLD` and `shield_hR0_blkD .. shield_hLU_blkD`, `shield_hblkD`: the `ShieldRunAtD`
     counterparts of `RunBlkAliveR13.lean`'s five block alive theorems and `hblk` reduction (`RunBlkAliveR13.lean`
     itself is untouched).
2. **Oracle-independent header reads (`absAt_opTrace_indep`, `absAt_rtTr_indep`) and `epxBndE` (`shd_hblkIO`):**
   * `absAt (opTrace H t ops) i` depends only on `ops` and `i` (independent of `H` and `t`), hence
     `absAt (rtTr key domain Lq pf rd G o) i = absAt (rtTr key domain Lq pf rd (fun _ => zeroDig) o) i` for every
     oracle `G`;
   * `bndPlanes` and `epxBndE` wrap `E0`'s `.planes` (`j = 0 .. Lb`) as `piB K (bndPl ... (D.opX (j + 1)) (pf.off j + 2)
     19 (hdrX absOf lg (pf.off j + 3) (rtTr ... (fun _ => zeroDig) (s, rc))) (Fin.append (dPos0 p).1 (dPos0 p).2))`,
     leaving `epW`, `r`, `tokW`, `xC`, `r'` unchanged and **proving `ShieldBlkIO_D` outright** (`shd_hblkIO`) while
     sharing the exact extracted boundary planes `B_0 .. B_Lb` across `InOkP` (`hdinS`), `BlocksOkP`, and `OutOkP`
     (`hdoutS`).
3. **Concrete `base` and `D` (`shdRkBaseX → shdRkD0 → shdRkBase → shdRkD` at `eL = 2^26`):**
   * Non-circular two-step construction: `shdRkBaseX` sets only `gX, nX` (empty lists), `shdRkD0` builds `ebData` on
     `shdRkBaseX`, `shdRkBase` populates the stage lists (`0`, `Lb + 1`) and block slot/squeeze lists (`1 .. Lb`) reading
     `shdRkD0.opA/opH/opX` (which equal `shdRkD.opA/opH/opX` by `shdRkD_ops_eq_D0` because `opA, opH, opX` ignore
     `sls, r0..lu`), and `shdRkD` builds `ebData` on `shdRkBase` at `eL = 2^26`;
   * Eliminates 16 binders from the top theorem by construction: `base`, `D`, `eL`, `hDe`, `hb0`, `hbBlk`, `hbL`,
     `hslB`, `hgX0`, `hnX0`, `hgX1`, `hnX1`, `hgXk`, `hnXk`, `hgXo`, `hnXo`.
4. **Full 16-conjunct block `RkPart.Ok` (`shd_blk_rkPartOk`) and stage `RkPart.Ok` (`shdRkD_valid`):**
   * `maskField_inj_S`: `maskField tag1 S1 = maskField tag2 S2 → S1 = S2` (via the `.colIndex`/`.colLen` vs `.pathLen`
     refusal-message distinction on empty Merkle paths), proving `(bp k).S = 23` at every block `k < Lb`;
   * `blk_hhi_of_rtRun`: derives `blkLists_rkSqOk`'s `hhi` from `RtProf.off_succ` and `hσ`;
   * **`shd_blk_rkPartOk`**: proves **all 16 conjuncts of `(ps (k + 1)).Ok`** for every `k < Lb` with **zero** new
     block premises;
   * **`shd_stg0_rkPartOk`**, **`shd_stgOut_rkPartOk`**, **`shdRkD_valid`**: proves all 13 unconditional stage
     conjuncts of `RkPart.Ok` at `0` and `Lb + 1` (deriving the 64-bit log bounds of `stgDefsV_valid_inC`/`out` from
     existing `hN64I`/`hN64O` at `P.refused.hdr`, plus the stage `r0` window/`Pairwise` and `lu` `SqCut`/window/`Pairwise`
     conjuncts), and wires `stgDefsV_valid_inC` and `stgDefsV_valid_out` through `ebData_valid`, replacing the
     monolithic `hD : D.Valid ...` with:
     - `hSm : 2 * pin.S + 2 ≤ 2 ^ 20 ∧ 2 * pout.S + 2 ≤ 2 ^ 20` (stage mask-spec bound; `4, 8` in `rcIncPart`/`rcOutcPart`),
     - `hlcStg : Vi.pub.lt ≤ ogStage.lc ∧ ∀ b, (F b).pub.lt ≤ ogStage.lc` (stage column log bound; `12 ≤ 12`),
     - `hCsIO` (the three `StgCsIODeg` links on `csIOI` and `csIOO` for `L65b`), and
     - `hLuStg` (the `.Rbr` and `≤ 2^26` escape bounds on the stage LogUp parameters `ΛI, eI` and `ΛO, eO`).
5. **Top theorem (`sshC_productionReadyL_epP_pinsHd`):**
   * Exact binder diff relative to `sshC_productionReadyL_epP_blkAlive`:
     - **Removed (18 binders):** `D`, `hD`, `base`, `eL`, `hDe`, `hgXk`, `hnXk`, `hgX1`, `hnX1`, `hgXo`, `hnXo`,
       `hgX0`, `hnX0`, `hslB`, `hbBlk`, `hb0`, `hbL`, `hblkIO`;
     - **Strengthened (1 binder + 1 section parameter):** `hPkC : ShieldRunAtC tag Pk Rp.blks Lb` →
       `hPkD : ShieldRunAtD tag dPos0 Pk Rp.blks Lb` (adds `Lay.dPos = dPos0` inside the existential for cross-block
       boundary-plane coordinate coherence, parameterized by `dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)`);
     - **Substituted in `hTrIIO, hTrOIO, hLI_stg, hLO_stg, hdinS, hdoutS`:** `D`/`hD` instantiated to `shdRkD`/`shdRkD_valid`,
       and `E0` wrapped by `epxBndE ... E0` in `hdinS` and `hdoutS`;
     - **Added in place of `hD` (4 focused stage premises):** `hSm`, `hlcStg`, `hCsIO`, `hLuStg`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunBlkAliveR13

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open Code
open ZK60.Exec.StageV ZK60.Exec.StageCheck
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

/-! ## 1. Cross-block carrier layout bundle (`shieldDPos0`, `ShieldBlkAtD`, `ShieldRunAtD`) -/

section ShieldBundleD

/-- **Canonical MSB carrier coordinate map for `shieldS0` (`T = 128 = 2^7`, `d = 3072 < 2^12`)**:
token row `t` at `msbBits 7 t.val`, channel `i` at `msbBits 12 i.val`. -/
def shieldDPos0 (p : shieldS0.Pos) : (Fin 7 → Bool) × (Fin 12 → Bool) :=
  (Exec.msbBits 7 p.1.val, Exec.msbBits 12 p.2.val)

theorem shieldDPos0_injective : Function.Injective shieldDPos0 := by
  intro p1 p2 h
  have h1 := congrArg (fun x => Exec.msbIndex 7 x.1) h
  have h2 := congrArg (fun x => Exec.msbIndex 12 x.2) h
  dsimp only [shieldDPos0] at h1 h2
  have ht1 : p1.1.val < 2 ^ 7 := by have hlt : p1.1.val < 128 := p1.1.isLt; omega
  have ht2 : p2.1.val < 2 ^ 7 := by have hlt : p2.1.val < 128 := p2.1.isLt; omega
  have hw1 : p1.2.val < 2 ^ 12 := by have hlt : p1.2.val < 3072 := p1.2.isLt; omega
  have hw2 : p2.2.val < 2 ^ 12 := by have hlt : p2.2.val < 3072 := p2.2.isLt; omega
  rw [Exec.msbIndex_msbBits 7 p1.1.val ht1, Exec.msbIndex_msbBits 7 p2.1.val ht2] at h1
  rw [Exec.msbIndex_msbBits 12 p1.2.val hw1, Exec.msbIndex_msbBits 12 p2.2.val hw2] at h2
  exact Prod.ext (Fin.ext h1) (Fin.ext h2)

/-- **`ShieldBlkAtC` strengthened with `Lay.dPos = dPos0` inside the existential** so `Classical.choose` witnesses
share the run's boundary-plane coordinate map `dPos0` across all blocks `0 .. Lb - 1`. -/
def ShieldBlkAtD (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (P : BlockParams) (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) : Prop :=
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
      ∧ Lay.dPos = dPos0

theorem ShieldBlkAtD.toShieldBlkAtC {tag : MTag} {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {P : BlockParams} {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    (h : ShieldBlkAtD tag dPos0 P Ly Pb) : ShieldBlkAtC tag P Ly Pb := by
  obtain ⟨rowsOf, Lay, B, ioIn, ioOut, hP, hdef, hlc, hep14, hk3, hk19, hk20, hk21, hk22, hls, hLay, -⟩ := h
  exact ⟨rowsOf, Lay, B, ioIn, ioOut, hP, hdef, hlc, hep14, hk3, hk19, hk20, hk21, hk22, hls, hLay⟩

/-- **Run-level Shieldstral bundle with shared carrier coordinate map `dPos0`.** -/
def ShieldRunAtD (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    {S0 : BlockShape} (Pk : ℕ → BlockParams) (blks : List (RunBlock S0)) (Lb : ℕ) : Prop :=
  ∀ k, k < Lb → ∃ (Ly : ShieldLayer) (b : RunBlock S0) (Pb : BlockPublic (shieldShape Ly)),
    shieldExport[k]? = some Ly ∧ blks[k]? = some b ∧ b.cal = shieldCal Ly ∧ HEq Pb b.pub
      ∧ ShieldBlkAtD tag dPos0 (Pk k) Ly Pb

theorem ShieldRunAtD.toShieldRunAtC {tag : MTag} {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtD tag dPos0 Pk blks Lb) : ShieldRunAtC tag Pk blks Lb := by
  intro k hk
  obtain ⟨Ly, b, Pb, hLy, hb, hcal, hPb, hd⟩ := h k hk
  exact ⟨Ly, b, Pb, hLy, hb, hcal, hPb, hd.toShieldBlkAtC⟩

theorem ShieldRunAtD.toShieldRunAt {tag : MTag} {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtD tag dPos0 Pk blks Lb) : ShieldRunAt Pk blks Lb :=
  h.toShieldRunAtC.toShieldRunAt

theorem ShieldRunAtD.ep14 {tag : MTag} {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
    {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}
    (h : ShieldRunAtD tag dPos0 Pk blks Lb) : ∀ k, k < Lb → (Pk k).endpointLogN = 14 :=
  h.toShieldRunAtC.ep14

section Proj
variable {tag : MTag} {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
  {S0 : BlockShape} {Pk : ℕ → BlockParams} {blks : List (RunBlock S0)} {Lb : ℕ}

noncomputable def shieldLyD (h : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) (hk : k < Lb) : ShieldLayer :=
  Classical.choose (h k hk)

noncomputable def shieldBlkD (h : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) (hk : k < Lb) : RunBlock S0 :=
  Classical.choose (Classical.choose_spec (h k hk))

noncomputable def shieldPbD (h : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) (hk : k < Lb) :
    BlockPublic (shieldShape (shieldLyD h k hk)) :=
  Classical.choose (Classical.choose_spec (Classical.choose_spec (h k hk)))

theorem shieldRunAtD_spec (h : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) (hk : k < Lb) :
    shieldExport[k]? = some (shieldLyD h k hk)
      ∧ blks[k]? = some (shieldBlkD h k hk)
      ∧ (shieldBlkD h k hk).cal = shieldCal (shieldLyD h k hk)
      ∧ HEq (shieldPbD h k hk) (shieldBlkD h k hk).pub
      ∧ ShieldBlkAtD tag dPos0 (Pk k) (shieldLyD h k hk) (shieldPbD h k hk) :=
  Classical.choose_spec (Classical.choose_spec (Classical.choose_spec (h k hk)))

theorem shieldLyD_mem (h : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) (hk : k < Lb) :
    shieldLyD h k hk ∈ shieldExport :=
  List.mem_of_getElem? (shieldRunAtD_spec h k hk).1

noncomputable def shieldRowsOfD (h : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) (hk : k < Lb) : Cm → ℕ :=
  Classical.choose (shieldRunAtD_spec h k hk).2.2.2.2

noncomputable def shieldLayD (h : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) (hk : k < Lb) :
    W16Layout (shieldShape (shieldLyD h k hk)) (CtR (Exec.Block.DefR13.cfgShieldR13 (shieldLyD h k hk)))
      (CwR (Exec.Block.DefR13.cfgShieldR13 (shieldLyD h k hk))) (CgR (Exec.Block.DefR13.cfgShieldR13 (shieldLyD h k hk)))
      (CjR (Exec.Block.DefR13.cfgShieldR13 (shieldLyD h k hk))) (CdR (Exec.Block.DefR13.cfgShieldR13 (shieldLyD h k hk)))
      (CfR (Exec.Block.DefR13.cfgShieldR13 (shieldLyD h k hk))) :=
  Classical.choose (Classical.choose_spec (shieldRunAtD_spec h k hk).2.2.2.2)

noncomputable def shieldBD (h : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) (hk : k < Lb) :
    W16Pub (shieldShape (shieldLyD h k hk)) (shieldPbD h k hk) (shieldLayD h k hk) :=
  Classical.choose (Classical.choose_spec (Classical.choose_spec (shieldRunAtD_spec h k hk).2.2.2.2))

noncomputable def shieldIoInD (h : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) (hk : k < Lb) : ℕ :=
  Classical.choose (Classical.choose_spec (Classical.choose_spec (Classical.choose_spec (shieldRunAtD_spec h k hk).2.2.2.2)))

noncomputable def shieldIoOutD (h : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) (hk : k < Lb) : ℕ :=
  Classical.choose (Classical.choose_spec (Classical.choose_spec (Classical.choose_spec
    (Classical.choose_spec (shieldRunAtD_spec h k hk).2.2.2.2))))

theorem shieldBlkAtD_spec (h : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) (hk : k < Lb) :
    IsShieldR13 (Pk k) tag (shieldRowsOfD h k hk)
      ∧ (Pk k).define = defineS
          (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 (shieldLyD h k hk))
            (shieldIoInD h k hk) (shieldIoOutD h k hk))
          (Exec.Block.Join.R13H.Pub.pubsR13L (Exec.Block.DefR13.cfgShieldR13 (shieldLyD h k hk))
            (shieldPbD h k hk) (shieldLayD h k hk) (shieldBD h k hk) (shieldShape (shieldLyD h k hk)).nG)
      ∧ (Pk k).logCols = 14 ∧ (Pk k).endpointLogN = 14
      ∧ (Pk k).kind 3 = SlotKind.standalone ∧ (Pk k).kind 19 = SlotKind.standalone ∧ (Pk k).kind 20 = SlotKind.standalone
      ∧ (Pk k).kind 21 = SlotKind.standalone ∧ (Pk k).kind 22 = SlotKind.standalone
      ∧ (Pk k).logupSumClaim = logupSumR13 (Exec.Block.DefR13.cfgShieldR13 (shieldLyD h k hk))
      ∧ LayR (shieldLayD h k hk)
      ∧ (shieldLayD h k hk).dPos = dPos0 :=
  Classical.choose_spec (Classical.choose_spec (Classical.choose_spec (Classical.choose_spec
    (Classical.choose_spec (shieldRunAtD_spec h k hk).2.2.2.2))))

end Proj

end ShieldBundleD

/-! ## 2. Oracle-independent `absAt`, `bndPlanes`, `epxBndE`, and `shd_hblkIO` -/

section BoundaryExt

/-- **`absAt (opTrace H t ops) i` is independent of the oracle `H` and initial state `t`.** -/
theorem absAt_opTrace_indep (H1 H2 : HIn → Dig) :
    ∀ (t1 t2 : Tr) (ops : List Op) (i : ℕ),
      absAt (opTrace H1 t1 ops) i = absAt (opTrace H2 t2 ops) i
  | _, _, [], _ => rfl
  | _, _, .absorb _ _ :: _, 0 => rfl
  | _, _, .squeeze :: _, 0 => rfl
  | t1, t2, .absorb l x :: ops, i + 1 =>
      absAt_opTrace_indep H1 H2 (t1.absorb H1 l x) (t2.absorb H2 l x) ops i
  | t1, t2, .squeeze :: ops, i + 1 =>
      absAt_opTrace_indep H1 H2 (t1.squeeze H1).2 (t2.squeeze H2).2 ops i

/-- **`absAt` on `rtTr` is oracle-independent** (`stpsOps (rtS Lq pf rd o)` does not read `G`). -/
theorem absAt_rtTr_indep (key : Option Dig) (domain : List UInt8) (Lq : ℕ) {α : Type}
    (pf : RtProf) (rd : α → List Op × List RtData) (G1 G2 : QB Lq → Dig) (o : α) (i : ℕ) :
    absAt (rtTr key domain Lq pf rd G1 o) i = absAt (rtTr key domain Lq pf rd G2 o) i :=
  absAt_opTrace_indep (liftH G1) (liftH G2) _ _ (stpsOps (rtS Lq pf rd o)) i

/-- **`hdrX` on `rtTr` at any index `i` below both `hdrLen1` and `hdrLen2` is independent of `hdrLen` and `G`.** -/
theorem hdrX_rtTr_at_lt (key : Option Dig) (domain : List UInt8) (Lq : ℕ)
    (absOf : QB Lq → Option (List UInt8)) (lg : List (QB Lq × Dig))
    {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
    (G1 G2 : QB Lq → Dig) (o : α) (hdrLen1 hdrLen2 i : ℕ)
    (hi1 : i < hdrLen1) (hi2 : i < hdrLen2) :
    hdrX absOf lg hdrLen1 (rtTr key domain Lq pf rd G1 o) i
      = hdrX absOf lg hdrLen2 (rtTr key domain Lq pf rd G2 o) i := by
  simp only [hdrX, ite_eq_left hi1, ite_eq_left hi2, absAt_rtTr_indep key domain Lq pf rd G1 G2 o i]

theorem bndPl_congr_at {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq)
    (o : RtOpen K Lq) (p : ℕ) {n1 n2 : ℕ} (hn : n1 = n2) {hx1 hx2 : HdrX Lq} (hhx : hx1 p = hx2 p)
    (b1 : Fin n1 → Bool) (b2 : Fin n2 → Bool) (hb : HEq b1 b2) :
    bndPl U tag Lq h64 o p n1 hx1 b1 = bndPl U tag Lq h64 o p n2 hx2 b2 := by
  subst hn
  cases eq_of_heq hb
  unfold bndPl
  rw [hhx]

/-- **Oracle-free extracted boundary planes `0 .. Lb`**: plane `j` is `piB K (bndPl ... (D.opX (j + 1)) (pf.off j + 2) 19
...)` read from `rtTr` against the dummy oracle `fun _ => zeroDig`. -/
noncomputable def bndPlanes {K : Type} [Field K] [Algebra GF K]
    (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
    (D : RtKData K Lq) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (lg : List (QB Lq × Dig)) (o : α) (j : ℕ) (p : shieldS0.Pos) : GF :=
  piB K (bndPl U tag Lq h64 (D.opX (j + 1)) (pf.off j + 2) 19
    (hdrX (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg (pf.off j + 3)
      (rtTr key domain Lq pf rd (fun _ => zeroDig) o))
    (Fin.append (dPos0 p).1 (dPos0 p).2))

/-- **Run extractor wrapper setting `.planes := bndPlanes ...`** while keeping `tokW`, `epW`, `xC`, `r`, `r'`
unchanged (`epxE` then overwrites `epW` and `r`, preserving `.planes = bndPlanes ...`). -/
noncomputable def epxBndE {K : Type} [Field K] [Algebra GF K] {Hdr Salt : Type}
    (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (pf : RtProf)
    (rd : ClsStmt Hdr × ClsReceipt → List Op × List RtData)
    (D : RtKData K Lq) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 Salt) :
    List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 Salt :=
  fun lg s rc =>
    { E0 lg s rc with
      planes := bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg (s, rc) }

theorem epxE_epxBndE_planes {K : Type} [Field K] [Algebra GF K] {Hdr Salt : Type} {Lq : ℕ}
    (C : PlaneCommit (shieldS0.Tok → ℕ) (ClsStmt Hdr) Salt) (mk : C.SaltMk)
    (pos : shieldS0.Tok → Fin C.dR × Fin C.n)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R)))
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (pf : RtProf)
    (rd : ClsStmt Hdr × ClsReceipt → List Op × List RtData)
    (D : RtKData K Lq) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 Salt)
    (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (epxE C mk pos ops (epxBndE U tag Lq h64 key domain hs hL pf rd D dPos0 E0) lg s rc).planes
      = bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg (s, rc) :=
  rfl

/-- **`ShieldBlkIO` counterpart for `ShieldRunAtD`.** -/
def ShieldBlkIO_D {K : Type} [Field K] [Algebra GF K] {Lq : ℕ} (h64 : 64 ≤ Lq) (U : K) (tag : MTag)
    (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)) (Lb : ℕ)
    {Pk : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb) (D : RtKData K Lq) (pf : RtProf)
    (k : ℕ) (hk : k < Lb) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (absOf : QB Lq → Option (List UInt8)) (Xin Xout : shieldS0.Pos → GF) : Prop :=
  (∀ p, Xin p = piB K (bndPl U tag Lq h64 (D.opX (k + 1)) (pf.off k + 2)
    (nD (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)))
    (hdrX absOf lg (pf.off (k + 1) + 5) τ)
    (Fin.append ((shieldLayD hPkD k hk).dPos p).1 ((shieldLayD hPkD k hk).dPos p).2)))
  ∧ (∀ p, Xout p = piB K (bndPl U tag Lq h64 (D.opX (k + 1 + 1)) (pf.off (k + 1) + 2)
    (nD (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)))
    (hdrX absOf lg (pf.off (k + 1) + 5) τ)
    (Fin.append ((shieldLayD hPkD k hk).dPos p).1 ((shieldLayD hPkD k hk).dPos p).2)))

/-- **`hblkIO` PROVED OUTRIGHT on `bndPlanes` (`epxBndE`)**: for every block `k < Lb` and every oracle `G`,
`bndPlanes ... k` and `bndPlanes ... (k + 1)` satisfy `ShieldBlkIO_D`. -/
theorem shd_hblkIO {K : Type} [Field K] [Algebra GF K] {Lq : ℕ} (h64 : 64 ≤ Lq) (U : K) (tag : MTag)
    (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)) (Lb : ℕ)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
    {Pk : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
    (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb) (D : RtKData K Lq)
    (k : ℕ) (hk : k < Lb) (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (o : α) :
    ShieldBlkIO_D h64 U tag dPos0 Lb hPkD D pf k hk lg (rtTr key domain Lq pf rd G o)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg o k)
      (bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg o (k + 1)) := by
  have hdPos : (shieldLayD hPkD k hk).dPos = dPos0 := (shieldBlkAtD_spec hPkD k hk).2.2.2.2.2.2.2.2.2.2.2
  have hnD : nD (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) = 19 := rfl
  have hoff_k : pf.off k ≤ pf.off (k + 1) := pf.off_le k
  refine ⟨fun p => ?_, fun p => ?_⟩
  · unfold bndPlanes
    refine congrArg (piB K) (bndPl_congr_at U tag Lq h64 (D.opX (k + 1)) (pf.off k + 2) hnD.symm ?_ _ _ ?_)
    · exact hdrX_rtTr_at_lt key domain Lq _ lg pf rd (fun _ => zeroDig) G o
        (pf.off k + 3) (pf.off (k + 1) + 5) (pf.off k + 2) (by omega) (by omega)
    · rw [hdPos]; exact HEq.rfl
  · unfold bndPlanes
    refine congrArg (piB K) (bndPl_congr_at U tag Lq h64 (D.opX (k + 1 + 1)) (pf.off (k + 1) + 2) hnD.symm ?_ _ _ ?_)
    · exact hdrX_rtTr_at_lt key domain Lq _ lg pf rd (fun _ => zeroDig) G o
        (pf.off (k + 1) + 3) (pf.off (k + 1) + 5) (pf.off (k + 1) + 2) (by omega) (by omega)
    · rw [hdPos]; exact HEq.rfl

end BoundaryExt

/-! ## 3. `maskField_inj_S`, concrete `base` and `D` (`shdRkBase`, `shdRkD`), and `RkPart.Ok` assembly (`shdRkD_valid`) -/

section MaskInj

private theorem zero_sum_mMsg :
    ((Fp2.zero.add Fp2.zero).mulBase (Fp.new (UInt64.ofNat Exec.mMsg))) = Fp2.zero := by
  decide

private theorem getD_replicate_zero (n i : ℕ) : (List.replicate n Fp2.zero).getD i Fp2.zero = Fp2.zero := by
  by_cases hi : i < n
  · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by simpa using hi), List.getElem_replicate]
    rfl
  · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none (by simp; omega)]
    rfl

private theorem append_left_char6 {a b : String} (h : a.toList[6]? = some 'M') :
    (a ++ b).toList[6]? = some 'M' := by
  have h6 : 6 < a.toList.length := (List.getElem?_eq_some_iff.mp h).1
  rw [String.toList_append, List.getElem?_append_left h6]
  exact h

private theorem mErrMsg_pathLen_char6 (mo : Exec.Block.MaskOpening) (j : ℕ) :
    (Exec.mErrMsg mo (.pathLen j)).toList[6]? = some 'M' := by
  unfold Exec.mErrMsg
  repeat apply append_left_char6
  decide

private theorem combinedWeights_nil (S : ℕ) (θ : Fp2) :
    Exec.combinedWeights S [] θ = (List.replicate S (List.replicate Exec.mMsg Fp2.zero), Fp2.zero) := rfl

private theorem maskVerify_eval_empty (H : HIn → Dig) (tag : MTag) (S : ℕ) (t0 : Tr)
    (q0 prox0 : List Fp2) (hq : q0.length = 2 * Exec.mMsg) (hp : prox0.length = 2 * Exec.mMsg)
    (hsum : ((q0.getD 0 Fp2.zero).add (q0.getD Exec.mMsg Fp2.zero)).mulBase (Fp.new (UInt64.ofNat Exec.mMsg))
      = Fp2.zero)
    (wj : ℕ) (wjs : List ℕ) (t5 : Tr)
    (hidx : ((((t0.challengeFp2 H).2.absorbFp2 H Exec.maskQLabel q0).challengeFp2Vec H
      (2 * S + 2)).2.absorbFp2 H Exec.maskProxLabel prox0).challengeIndices H Exec.mQ Exec.mDom
        = some (wj :: wjs, t5))
    (j2 : ℕ) (col2 : List Fp) (cs : List Exec.OCol)
    (hclen : ((j2, col2, zeroDig, ([] : List Dig)) :: cs).length = (wj :: wjs).length) :
    Exec.maskVerify H tag (rootFp 9) (rootFp 12) zeroDig S []
        ⟨q0, prox0, (j2, col2, zeroDig, ([] : List Dig)) :: cs⟩ t0
      = if j2 ≠ wj then .error (.colIndex j2)
        else if col2.length ≠ 2 * S + 4 then .error (.colLen j2)
        else .error (.pathLen j2) := by
  unfold Exec.maskVerify
  dsimp only
  rw [combinedWeights_nil]
  dsimp only
  have hnq : ¬ (q0.length ≠ 2 * Exec.mMsg) := not_not.mpr hq
  have hns : ¬ (((q0.getD 0 Fp2.zero).add (q0.getD Exec.mMsg Fp2.zero)).mulBase (Fp.new (UInt64.ofNat Exec.mMsg))
      ≠ Fp2.zero) := not_not.mpr hsum
  have hnp : ¬ (prox0.length ≠ 2 * Exec.mMsg) := not_not.mpr hp
  have hnc : ¬ (((j2, col2, zeroDig, ([] : List Dig)) :: cs).length ≠ (wj :: wjs).length) := not_not.mpr hclen
  rw [ite_eq_right hnq, ite_eq_right hns, ite_eq_right hnp, hidx]
  dsimp only
  rw [ite_eq_right hnc, Exec.mColsCheck_cons]
  by_cases h1 : j2 = wj
  · rw [ite_eq_right (not_not.mpr h1), ite_eq_right (not_not.mpr h1)]
    by_cases h2 : col2.length = 2 * S + 4
    · rw [ite_eq_right (not_not.mpr h2), ite_eq_right (not_not.mpr h2)]
      have hp12 : ([] : List Dig).length ≠ 12 := by decide
      rw [ite_eq_left hp12]
    · rw [ite_eq_left h2, ite_eq_left h2]
  · rw [ite_eq_left h1, ite_eq_left h1]

/-- **`maskField` determines `S`**: at empty Merkle paths and column length `2 * S2 + 4`, `maskField tag2 S2` refuses at
`.pathLen` (`'M'` at byte 6) while any `S1 ≠ S2` refuses earlier at `.colIndex` or `.colLen` (`'c'` at byte 6). -/
theorem maskField_inj_S {tag1 tag2 : MTag} {S1 S2 : ℕ}
    (h : Exec.maskField tag1 S1 = Exec.maskField tag2 S2) : S1 = S2 := by
  by_contra hne
  set H0 : HIn → Dig := fun _ => zeroDig
  set t0 : Tr := Tr.newKeyed H0 [] none
  set q0 : List Fp2 := List.replicate (2 * Exec.mMsg) Fp2.zero
  set prox0 : List Fp2 := List.replicate (2 * Exec.mMsg) Fp2.zero
  have hq : q0.length = 2 * Exec.mMsg := List.length_replicate
  have hp : prox0.length = 2 * Exec.mMsg := List.length_replicate
  have hsum : ((q0.getD 0 Fp2.zero).add (q0.getD Exec.mMsg Fp2.zero)).mulBase (Fp.new (UInt64.ofNat Exec.mMsg))
      = Fp2.zero := by
    rw [getD_replicate_zero, getD_replicate_zero]
    exact zero_sum_mMsg
  obtain ⟨idx2, t5_2, hidx2, hlen2, -⟩ :=
    HonestOpen.challengeIndices_some H0 Exec.mQ Exec.mDom
      ((((t0.challengeFp2 H0).2.absorbFp2 H0 Exec.maskQLabel q0).challengeFp2Vec H0
        (2 * S2 + 2)).2.absorbFp2 H0 Exec.maskProxLabel prox0) (by decide) (by decide) (by decide)
  obtain ⟨idx1, t5_1, hidx1, hlen1, -⟩ :=
    HonestOpen.challengeIndices_some H0 Exec.mQ Exec.mDom
      ((((t0.challengeFp2 H0).2.absorbFp2 H0 Exec.maskQLabel q0).challengeFp2Vec H0
        (2 * S1 + 2)).2.absorbFp2 H0 Exec.maskProxLabel prox0) (by decide) (by decide) (by decide)
  cases idx2 with
  | nil => simp [Exec.mQ] at hlen2
  | cons j2 rest2 =>
    cases idx1 with
    | nil => simp [Exec.mQ] at hlen1
    | cons j1 rest1 =>
      set col2 : List Fp := List.replicate (2 * S2 + 4) Fp.zero
      have hcol2_len : col2.length = 2 * S2 + 4 := List.length_replicate
      set mo : Exec.Block.MaskOpening :=
        ⟨q0, prox0, (j2 :: rest2).map (fun j => ⟨j, col2, zeroDig, []⟩)⟩
      have heval := congrFun (congrFun (congrFun (congrFun (congrFun h H0) zeroDig) []) mo) t0
      have htoMO : Exec.toMO mo
          = ⟨q0, prox0, (j2, col2, zeroDig, ([] : List Dig))
              :: rest2.map (fun j => (j, col2, zeroDig, ([] : List Dig)))⟩ := by
        simp [Exec.toMO, mo, List.map_map, Exec.toOCol]
      have hclen2 : ((j2, col2, zeroDig, ([] : List Dig))
          :: rest2.map (fun j => (j, col2, zeroDig, ([] : List Dig)))).length = (j2 :: rest2).length := by
        simp
      have hclen1 : ((j2, col2, zeroDig, ([] : List Dig))
          :: rest2.map (fun j => (j, col2, zeroDig, ([] : List Dig)))).length = (j1 :: rest1).length := by
        simp only [List.length_cons, List.length_map] at hlen2 hlen1 ⊢
        omega
      have hrhs : Exec.maskField tag2 S2 H0 zeroDig [] mo t0 = .error (Exec.mErrMsg mo (.pathLen j2)) := by
        unfold Exec.maskField Exec.w16r2MCheck
        rw [List.map_nil, htoMO, maskVerify_eval_empty H0 tag2 S2 t0 q0 prox0 hq hp hsum j2 rest2 _ hidx2 j2 col2 _ hclen2]
        rw [ite_eq_right (not_not.mpr rfl), ite_eq_right (not_not.mpr hcol2_len)]
        rfl
      have hlhs : ∃ err, (err = Exec.MErr.colIndex j2 ∨ err = Exec.MErr.colLen j2)
          ∧ Exec.maskField tag1 S1 H0 zeroDig [] mo t0 = .error (Exec.mErrMsg mo err) := by
        unfold Exec.maskField Exec.w16r2MCheck
        rw [List.map_nil, htoMO, maskVerify_eval_empty H0 tag1 S1 t0 q0 prox0 hq hp hsum j1 rest1 _ hidx1 j2 col2 _ hclen1]
        by_cases hj : j2 = j1
        · rw [ite_eq_right (not_not.mpr hj)]
          have hcol_ne : col2.length ≠ 2 * S1 + 4 := by omega
          rw [ite_eq_left hcol_ne]
          exact ⟨.colLen j2, Or.inr rfl, rfl⟩
        · rw [ite_eq_left hj]
          exact ⟨.colIndex j2, Or.inl rfl, rfl⟩
      obtain ⟨err, herr, hlhs_eq⟩ := hlhs
      rw [hlhs_eq, hrhs] at heval
      injection heval with hstr
      have hc6 := congrArg (fun s : String => s.toList[6]?) hstr
      rw [mErrMsg_pathLen_char6 mo j2] at hc6
      rcases herr with rfl | rfl
      · change ("mask: column index").toList[6]? = some 'M' at hc6
        revert hc6; decide
      · change ("mask: column length").toList[6]? = some 'M' at hc6
        revert hc6; decide

end MaskInj

section ConcretePinsAndValid

variable {Hdr : Type}
variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- **Step 1 of `base`: closing geometries `gX` and claim counts `nX` for all parts `0 .. Lb + 1`** (empty lists;
`opA`, `opH`, `opX` in `ebData` read only `gX`, `nX` and the `RxMAH` fields). -/
def shdRkBaseX (Lq Lb : ℕ) (pf : RtProf) (Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn : ℕ)
    (bp_nIn bp_nOut pXk_rows : ℕ → ℕ) : ℕ → RkPart K Lq
  | 0 =>
    { S := 0, k := 0, mpos := 0
      gA := rkAt ogStage 0 0, gH := rkAt ogStage 0 0
      gX := rkAt ogEp Iin_rows 1
      nA := 0, nH := 0, nX := Iin_nIn
      sls := [], r0 := [], r1 := [], h0 := [], h1 := [], lu := [] }
  | 1 =>
    if 0 < Lb then
      { S := 0, k := 0, mpos := 0
        gA := rkR13 0 0, gH := rkR13 0 0
        gX := rkR13 (pXk_rows 0) (pf.off 0 + 2)
        nA := 0, nH := 0, nX := Iin_nOut + bp_nIn 0
        sls := [], r0 := [], r1 := [], h0 := [], h1 := [], lu := [] }
    else
      { S := 0, k := 0, mpos := 0
        gA := rkAt ogStage 0 0, gH := rkAt ogStage 0 0
        gX := rkR13 Oout_rows (pf.off 0 + 2)
        nA := 0, nH := 0, nX := bp_nOut 0 + Oout_nIn
        sls := [], r0 := [], r1 := [], h0 := [], h1 := [], lu := [] }
  | j + 2 =>
    if j + 1 < Lb then
      { S := 0, k := 0, mpos := 0
        gA := rkR13 0 0, gH := rkR13 0 0
        gX := rkR13 (pXk_rows (j + 1)) (pf.off (j + 1) + 2)
        nA := 0, nH := 0, nX := bp_nOut j + bp_nIn (j + 1)
        sls := [], r0 := [], r1 := [], h0 := [], h1 := [], lu := [] }
    else
      { S := 0, k := 0, mpos := 0
        gA := rkAt ogStage 0 0, gH := rkAt ogStage 0 0
        gX := rkR13 Oout_rows (pf.off (j + 1) + 2)
        nA := 0, nH := 0, nX := bp_nOut j + Oout_nIn
        sls := [], r0 := [], r1 := [], h0 := [], h1 := [], lu := [] }

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem shdRkBaseX_0_gX (Lq Lb : ℕ) (pf : RtProf) (Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn : ℕ)
    (bp_nIn bp_nOut pXk_rows : ℕ → ℕ) :
    (shdRkBaseX (K := K) Lq Lb pf Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn bp_nIn bp_nOut pXk_rows 0).gX
      = rkAt ogEp Iin_rows 1
    ∧ (shdRkBaseX (K := K) Lq Lb pf Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn bp_nIn bp_nOut pXk_rows 0).nX
      = Iin_nIn :=
  ⟨rfl, rfl⟩

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem shdRkBaseX_1_gX (Lq Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf)
    (Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn : ℕ) (bp_nIn bp_nOut pXk_rows : ℕ → ℕ) :
    (shdRkBaseX (K := K) Lq Lb pf Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn bp_nIn bp_nOut pXk_rows 1).gX
      = rkR13 (pXk_rows 0) (pf.off 0 + 2)
    ∧ (shdRkBaseX (K := K) Lq Lb pf Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn bp_nIn bp_nOut pXk_rows 1).nX
      = Iin_nOut + bp_nIn 0 := by
  simp [shdRkBaseX, hLb1]

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem shdRkBaseX_blk_gX (Lq Lb : ℕ) (pf : RtProf)
    (Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn : ℕ) (bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (k : ℕ) (hk : k + 1 < Lb) :
    (shdRkBaseX (K := K) Lq Lb pf Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn bp_nIn bp_nOut pXk_rows (k + 1 + 1)).gX
      = rkR13 (pXk_rows (k + 1)) (pf.off (k + 1) + 2)
    ∧ (shdRkBaseX (K := K) Lq Lb pf Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn bp_nIn bp_nOut pXk_rows (k + 1 + 1)).nX
      = bp_nOut k + bp_nIn (k + 1) := by
  unfold shdRkBaseX
  simp [hk]

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem shdRkBaseX_out_gX (Lq Lb : ℕ) (pf : RtProf)
    (Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn : ℕ) (bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (k : ℕ) (hk : k + 1 = Lb) :
    (shdRkBaseX (K := K) Lq Lb pf Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn bp_nIn bp_nOut pXk_rows (k + 1 + 1)).gX
      = rkR13 Oout_rows (pf.off (k + 1) + 2)
    ∧ (shdRkBaseX (K := K) Lq Lb pf Iin_rows Iin_nIn Iin_nOut Oout_rows Oout_nIn bp_nIn bp_nOut pXk_rows (k + 1 + 1)).nX
      = bp_nOut k + Oout_nIn := by
  have hnot : ¬ (k + 1 < Lb) := by omega
  unfold shdRkBaseX
  simp [hnot]

/-- **Step 2 (`shdRkD0`): `ebData` on `shdRkBaseX` at `eL = 2^26`** (fixes `opA`, `opH`, `opX` before building the
slot and squeeze lists). -/
noncomputable def shdRkD0
    (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (pf : RtProf) (Pk : ℕ → BlockParams)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ) : RtKData K Lq :=
  ebData U tag Lq h64 key domain hs hL abRdIn pf
    (rxPs (shdRkBaseX Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut pXk_rows) Lb
      (rxDinG ogStage pf pin.S kIn Iin_rA Iin_rH Iin_nA Iin_nH mIn)
      (fun k => rxDblk pf k (bp_S k) (Pk k).nFunctionals (bp_rA k) (bp_rH k) (bp_nA k) (bp_nH k))
      (rxDoutG ogStage pf Lb pout.S kOut Oout_rA Oout_rH Oout_nA Oout_nH))
    (rxAcc (vdWin Vi) (vdWout F) Pk pf Lb)
    (rxLsc lscIn lscOut Pk Lb)
    (2 ^ 26)

/-- **Step 3 (`shdRkBase`): concrete `base : ℕ → RkPart K Lq`** keeping `shdRkBaseX`'s closing geometries `gX, nX` and
populating stage `0` (`stgPart`), blocks `1 .. Lb` (`blockSchedXB` + `blkR0..blkLU`), and stage `Lb + 1` (`stgPart`). -/
noncomputable def shdRkBase
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → BlockParams)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop) : ℕ → RkPart K Lq :=
  let bx := shdRkBaseX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut pXk_rows
  let D0 := shdRkD0 U tag Lq h64 key domain hs hL Lb pf Pk Vi F lscIn lscOut pin pout mIn kIn kOut
    Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows
  let hoAK0 : ∀ k, k < Lb → (D0.opA (k + 1)).lc = rowLog (Pk k) .a :=
    shield_hoAK rfl (fun _ _ => rfl) hPkD.toShieldRunAt
  let hoHK0 : ∀ k, k < Lb → (D0.opH (k + 1)).lc = rowLog (Pk k) .h :=
    shield_hoHK rfl (fun _ _ => rfl) hPkD.toShieldRunAt
  let hoIK0 : ∀ k, k < Lb → (D0.opX (k + 1)).lc = rowLog (Pk k) .inp :=
    shield_hoIK rfl
      (by rw [(shdRkBaseX_1_gX (K := K) Lq Lb hLb1 pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut pXk_rows).1]; rfl)
      (fun j hj => by rw [(shdRkBaseX_blk_gX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut pXk_rows j hj).1]; rfl)
      hPkD.ep14
  let hoOK0 : ∀ k, k < Lb → (D0.opX (k + 1 + 1)).lc = rowLog (Pk k) .out :=
    shield_hoOK rfl
      (fun j hj => by rw [(shdRkBaseX_blk_gX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut pXk_rows j hj).1]; rfl)
      (fun j hj => by rw [(shdRkBaseX_out_gX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut pXk_rows j hj).1]; rfl)
      hPkD.ep14
  let absOf := Exec.Block.absOfC (chainEncB key domain hs Lq hL)
  fun i =>
    match i with
    | 0 =>
      stgPart (bx 0)
        (stgSchedV P0in mIn (pf.off 0 + 5) stgHostIn absOf
          (stgFstIC U hbij tag h64 P0in (vdWin Vi) (pf.off 0 + pin.pre) (pf.off 0 + 5) mIn
            ogStage.lc ogStage.h ogStage.Q ogStage.e Iin_rA Iin_rH pin.S csIOI))
        (stgDefsV P0in mIn (pf.off 0 + 5) absOf
          (sshΦIC U hbij tag h64 P0in Vi (pf.off 0 + pin.pre) (pf.off 0 + 5) mIn
            ogStage.lc ogStage.h ogStage.Q ogStage.e Iin_rA Iin_rH csIOI) sshDgI)
        (stgLkSqV mIn (pf.off 0 + 5) eI absOf ΛI)
    | k + 1 =>
      if hk : k < Lb then
        { bx (k + 1) with
          sls := blockSchedXB (Pk k) (pf.off (k + 1) + 5) absOf
            (bwFslRun U tag Lq h64 Lb Pk bp_S D0 pf hoAK0 hoHK0 hoIK0 hoOK0
              (shieldRunProg hPkD.toShieldRunAt) (shieldRunPubs hPkD.toShieldRunAt) k)
          r0 := blkR0 U tag h64 hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
            (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
            (D0.opX (k + 1)) (D0.opX (k + 1 + 1)) (pf.off k + 2) (pf.off (k + 1) + 2) (pf.off (k + 1) + 5) absOf
          r1 := blkR1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
            (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
            (pf.off (k + 1) + 5) absOf
          h0 := blkH0 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
            (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
            (pf.off (k + 1) + 5) absOf
          h1 := blkH1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
            (shieldBlkAtD_spec hPkD k hk).1.hsl (shieldBlkAtD_spec hPkD k hk).2.2.1
            (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (pf.off (k + 1) + 5) absOf
          lu := blkLU U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1
            (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (pf.off (k + 1) + 5) absOf }
      else
        stgPart (bx (k + 1))
          (stgSchedV P0out 2 (pf.off (Lb + 1) + 2) (stgHostOut P0out) absOf
            (stgFstO U hbij tag h64 P0out (vdWout F) (pf.off (Lb + 1) + pout.pre) (pf.off (Lb + 1) + 2)
              ogStage.lc ogStage.h ogStage.Q ogStage.e Oout_rA Oout_rH pout.S csIOO))
          (stgDefsV P0out 2 (pf.off (Lb + 1) + 2) absOf
            (sshΦO U hbij tag h64 P0out F (pf.off (Lb + 1) + pout.pre) (pf.off (Lb + 1) + 2)
              ogStage.lc ogStage.h ogStage.Q ogStage.e Oout_rA Oout_rH csIOO) sshDgO)
          (stgLkSqV 2 (pf.off (Lb + 1) + 2) eO absOf ΛO)

/-- **Step 4 (`shdRkD`): concrete `D : RtKData K Lq` built by `ebData` on `shdRkBase` at `eL = 2^26`.** -/
noncomputable def shdRkD
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → BlockParams)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop) : RtKData K Lq :=
  ebData U tag Lq h64 key domain hs hL abRdIn pf
    (rxPs (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
        Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
        bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO) Lb
      (rxDinG ogStage pf pin.S kIn Iin_rA Iin_rH Iin_nA Iin_nH mIn)
      (fun k => rxDblk pf k (bp_S k) (Pk k).nFunctionals (bp_rA k) (bp_rH k) (bp_nA k) (bp_nH k))
      (rxDoutG ogStage pf Lb pout.S kOut Oout_rA Oout_rH Oout_nA Oout_nH))
    (rxAcc (vdWin Vi) (vdWout F) Pk pf Lb)
    (rxLsc lscIn lscOut Pk Lb)
    (2 ^ 26)

/-- `shdRkBase` preserves `shdRkBaseX`'s `gX` and `nX` at every index `i : ℕ`. -/
theorem shdRkBase_gX_nX
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → BlockParams)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (i : ℕ) :
    (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO i).gX
      = (shdRkBaseX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut pXk_rows i).gX
    ∧ (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO i).nX
      = (shdRkBaseX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut pXk_rows i).nX := by
  rcases i with _ | k
  · exact ⟨rfl, rfl⟩
  · dsimp only [shdRkBase]
    split_ifs <;> exact ⟨rfl, rfl⟩

/-- **`shdRkD` and `shdRkD0` have identical `opA`, `opH`, `opX` at every part `i : ℕ`** (resolving `M1`'s apparent
mutual dependence between `D.opX` and `base (k + 1)`). -/
theorem shdRkD_ops_eq_D0
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → BlockParams)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (i : ℕ) :
    (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).opA i
      = (shdRkD0 U tag Lq h64 key domain hs hL Lb pf Pk Vi F lscIn lscOut pin pout mIn kIn kOut
          Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
          bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows).opA i
    ∧ (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).opH i
      = (shdRkD0 U tag Lq h64 key domain hs hL Lb pf Pk Vi F lscIn lscOut pin pout mIn kIn kOut
          Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
          bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows).opH i
    ∧ (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).opX i
      = (shdRkD0 U tag Lq h64 key domain hs hL Lb pf Pk Vi F lscIn lscOut pin pout mIn kIn kOut
          Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
          bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows).opX i := by
  have hg := shdRkBase_gX_nX U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO i
  rcases i with _ | j
  · refine ⟨rfl, rfl, ?_⟩
    show ebOpen U tag Lq h64 key domain hs hL abRdIn _ _ _ _ = ebOpen U tag Lq h64 key domain hs hL abRdIn _ _ _ _
    simp only [rxPs, rxSet, hg.1, hg.2]
  · refine ⟨?_, ?_, ?_⟩
    · show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = rkOpen U tag Lq h64 key domain hs hL _ _ _ _
      dsimp only [rxPs]; split_ifs <;> rfl
    · show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = rkOpen U tag Lq h64 key domain hs hL _ _ _ _
      dsimp only [rxPs]; split_ifs <;> rfl
    · show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = rkOpen U tag Lq h64 key domain hs hL _ _ _ _
      dsimp only [rxPs]; split_ifs <;> simp only [rxSet, hg.1, hg.2]

/-- **`hb0` proved by construction for `shdRkBase 0`.** -/
theorem shd_hb0
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → BlockParams)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop) :
    StgLists
      (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
        Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
        bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO 0)
      (stgSchedV P0in mIn (pf.off 0 + 5) stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (stgFstIC U hbij tag h64 P0in (vdWin Vi) (pf.off 0 + pin.pre) (pf.off 0 + 5) mIn
          ogStage.lc ogStage.h ogStage.Q ogStage.e Iin_rA Iin_rH pin.S csIOI))
      (stgDefsV P0in mIn (pf.off 0 + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (sshΦIC U hbij tag h64 P0in Vi (pf.off 0 + pin.pre) (pf.off 0 + 5) mIn
          ogStage.lc ogStage.h ogStage.Q ogStage.e Iin_rA Iin_rH csIOI) sshDgI)
      (stgLkSqV mIn (pf.off 0 + 5) eI (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI) :=
  stgPart_lists _ _ _ _

/-- **`hbL` proved by construction for `shdRkBase (Lb + 1)`.** -/
theorem shd_hbL
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → BlockParams)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop) :
    StgLists
      (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
        Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
        bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (Lb + 1))
      (stgSchedV P0out 2 (pf.off (Lb + 1) + 2) (stgHostOut P0out) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (stgFstO U hbij tag h64 P0out (vdWout F) (pf.off (Lb + 1) + pout.pre) (pf.off (Lb + 1) + 2)
          ogStage.lc ogStage.h ogStage.Q ogStage.e Oout_rA Oout_rH pout.S csIOO))
      (stgDefsV P0out 2 (pf.off (Lb + 1) + 2) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (sshΦO U hbij tag h64 P0out F (pf.off (Lb + 1) + pout.pre) (pf.off (Lb + 1) + 2)
          ogStage.lc ogStage.h ogStage.Q ogStage.e Oout_rA Oout_rH csIOO) sshDgO)
      (stgLkSqV 2 (pf.off (Lb + 1) + 2) eO (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO) := by
  have heq : shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (Lb + 1)
      = stgPart _ _ _ _ := dite_eq_right (lt_irrefl Lb)
  rw [heq]
  exact stgPart_lists _ _ _ _

/-- **`hbBlk` proved by construction for `shdRkBase (k + 1)` against `shdRkD.opX`!** -/
theorem shd_hbBlk
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → BlockParams)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (k : ℕ) (hk : k < Lb) :
    let D := shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO
    let absOf := Exec.Block.absOfC (chainEncB key domain hs Lq hL)
    BlkLists
      (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
        Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
        bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) (pf.off k + 2) (pf.off (k + 1) + 2) (pf.off (k + 1) + 5) absOf)
      (blkR1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        (pf.off (k + 1) + 5) absOf)
      (blkH0 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        (pf.off (k + 1) + 5) absOf)
      (blkH1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).1.hsl (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (pf.off (k + 1) + 5) absOf)
      (blkLU U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (pf.off (k + 1) + 5) absOf) := by
  intro D absOf
  have hx1 := (shdRkD_ops_eq_D0 U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (k + 1)).2.2
  have hx2 := (shdRkD_ops_eq_D0 U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (k + 1 + 1)).2.2
  have hb : shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (k + 1)
      = _ := dite_eq_left hk
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · rw [hb]; dsimp only; rw [← hx1, ← hx2]
  · rw [hb]
  · rw [hb]
  · rw [hb]
  · rw [hb]

/-- **`hslB` proved by construction for `shdRkD.sls (k + 1)`!** -/
theorem shd_hslB
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → BlockParams)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (hoAK : ∀ k, k < Lb →
      ((shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
        Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
        bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).opA (k + 1)).lc
      = rowLog (Pk k) .a)
    (hoHK : ∀ k, k < Lb →
      ((shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
        Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
        bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).opH (k + 1)).lc
      = rowLog (Pk k) .h)
    (hoIK : ∀ k, k < Lb →
      ((shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
        Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
        bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).opX (k + 1)).lc
      = rowLog (Pk k) .inp)
    (hoOK : ∀ k, k < Lb →
      ((shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
        Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
        bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).opX (k + 1 + 1)).lc
      = rowLog (Pk k) .out)
    (k : ℕ) (hk : k < Lb) :
    (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).sls (k + 1)
    = blockSchedXB (Pk k) (pf.off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (bwFslRun U tag Lq h64 Lb Pk bp_S
          (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
            pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
            Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
            bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO)
          pf hoAK hoHK hoIK hoOK (shieldRunProg hPkD.toShieldRunAt) (shieldRunPubs hPkD.toShieldRunAt) k) := by
  have hsls : (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).sls (k + 1)
    = (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
        Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
        bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (k + 1)).sls := by
    show (rxPs _ Lb _ _ _ (k + 1)).sls = _
    rw [rxPs_blk _ Lb _ _ _ k hk]; rfl
  rw [hsls]
  have hb : shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (k + 1)
      = _ := dite_eq_left hk
  rw [hb]; dsimp only
  congr 1
  funext c3 rt hx j sn pt
  unfold bwFslRun
  rw [dite_eq_left hk, dite_eq_left hk]
  have heq1 := shdRkD_ops_eq_D0 U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (k + 1)
  have heq2 := shdRkD_ops_eq_D0 U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (k + 1 + 1)
  have hbw : ∀ (oA1 oA2 oH1 oH2 oI1 oI2 oO1 oO2 : RtOpen K Lq)
      (ea : oA1 = oA2) (eh : oH1 = oH2) (ei : oI1 = oI2) (eo : oO1 = oO2)
      (la1 : oA1.lc = rowLog (Pk k) .a) (la2 : oA2.lc = rowLog (Pk k) .a)
      (lh1 : oH1.lc = rowLog (Pk k) .h) (lh2 : oH2.lc = rowLog (Pk k) .h)
      (li1 : oI1.lc = rowLog (Pk k) .inp) (li2 : oI2.lc = rowLog (Pk k) .inp)
      (lo1 : oO1.lc = rowLog (Pk k) .out) (lo2 : oO2.lc = rowLog (Pk k) .out),
      bwFsl U tag Lq h64 (bp_S k) (Pk k) oA1 oH1 oI1 oO1 la1 lh1 li1 lo1
        (pf.off k + 2) (pf.off (k + 1) + 2) (shieldRunProg hPkD.toShieldRunAt k)
        (shieldRunPubs hPkD.toShieldRunAt k) c3 rt hx j sn pt
      = bwFsl U tag Lq h64 (bp_S k) (Pk k) oA2 oH2 oI2 oO2 la2 lh2 li2 lo2
        (pf.off k + 2) (pf.off (k + 1) + 2) (shieldRunProg hPkD.toShieldRunAt k)
        (shieldRunPubs hPkD.toShieldRunAt k) c3 rt hx j sn pt := by
    intro oA1 oA2 oH1 oH2 oI1 oI2 oO1 oO2 ea eh ei eo la1 la2 lh1 lh2 li1 li2 lo1 lo2
    subst ea eh ei eo
    rfl
  exact (hbw _ _ _ _ _ _ _ _ heq1.1 heq1.2.1 heq1.2.2 heq2.2.2 (hoAK k hk) _ (hoHK k hk) _ (hoIK k hk) _ (hoOK k hk) _).symm

/-- **`hDe` proved as an explicit equation lemma before sealing `shdRkBase` and `shdRkD` irreducible.** -/
theorem shdRkD_eq_ebData
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → BlockParams)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop) :
    shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO
    = ebData U tag Lq h64 key domain hs hL abRdIn pf
        (rxPs (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
            pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
            Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
            bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO) Lb
          (rxDinG ogStage pf pin.S kIn Iin_rA Iin_rH Iin_nA Iin_nH mIn)
          (fun k => rxDblk pf k (bp_S k) (Pk k).nFunctionals (bp_rA k) (bp_rH k) (bp_nA k) (bp_nH k))
          (rxDoutG ogStage pf Lb pout.S kOut Oout_rA Oout_rH Oout_nA Oout_nH))
        (rxAcc (vdWin Vi) (vdWout F) Pk pf Lb)
        (rxLsc lscIn lscOut Pk Lb)
        (2 ^ 26) := rfl

theorem shd_blk_sls
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → BlockParams)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (k : ℕ) (hk : k < Lb) :
    ∃ Fsl,
      (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
        Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
        bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (k + 1)).sls
      = blockSchedXB (Pk k) (pf.off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) Fsl := by
  have hb : (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (k + 1)).sls
      = _ := congrArg RkPart.sls (dite_eq_left hk)
  exact ⟨_, hb⟩

attribute [irreducible] shdRkBase shdRkD

/-! ### `hhi`, `shd_blk_rkPartOk`, `shd_stg0_rkPartOk`, `shd_stgOut_rkPartOk`, and `shdRkD_valid` -/

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem rtPart_pre_le_len (p : RtPart) : p.pre ≤ p.len := by
  simp only [RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
  omega

/-- **`hhi` derived from `RtRun` and `hσ`** (`L64_REVIEW.md` `M2`). -/
theorem blk_hhi_of_rtRun
    {Lq : ℕ} {key : Option Dig} {domain : List UInt8}
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
    (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (k : ℕ) (hk : k < Lb) :
    ((RtRun.pf Rn).off (k + 1) + 5) + 10 + shapeLen (Pk k) 0 (Pk k).geom.slots
      ≤ (RtRun.pf Rn).off (k + 1 + 1) := by
  have hparts : (RtRun.pf Rn).parts.length = Lb + 2 := RtRun.parts_length Rn
  have hσb := ra_blk_seg Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck
    bndOpen Rn cx0 pin pout bp wXk gXk mXk hσ k hk
  have hpart := rx_part_of Rn (k + 1) _ hσb
  have hoff := RtProf.off_succ (RtRun.pf Rn) (k + 1) (by omega)
  have hpre_le := rtPart_pre_le_len ((RtRun.pf Rn).part (k + 1))
  have hpre_eq : ((RtRun.pf Rn).part (k + 1)).pre = 15 + shapeLen (Pk k) 0 (Pk k).geom.slots := by
    rw [hpart]; rfl
  omega

/-- **ALL 16 CONJUNCTS OF `RkPart.Ok` PROVED FOR EVERY SHIELDSTRAL BLOCK PART `k + 1` (`k < Lb`)**, with zero new
block premises. -/
theorem shd_blk_rkPartOk
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb)
    (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (Pk : ℕ → BlockParams) (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom)
    (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →
      Except String Tr)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (cx0 : IncCtx) (pin pout : RtPart)
    (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hBA : ∀ k, RkPcsR13 U tag (bp k).pA)
    (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (hXk : ∀ k, RkPcsR13 U tag (pXk k))
    (hwXk : ∀ k, k + 1 < Lb → wXk (k + 1) = (bp k).nOut + (bp (k + 1)).nIn + (pXk (k + 1)).rows)
    (hmXk : ∀ k, k + 1 < Lb → mXk (k + 1) = (pXk (k + 1)).m)
    (hwX0 : wXk 0 = Iin.nOut + (bp 0).nIn + (pXk 0).rows)
    (hmX0 : mXk 0 = (pXk 0).m)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (k : ℕ) (hk : k < Lb) :
    (rxPs
      (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
        Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
        (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
        (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
        (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO) Lb
      (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)
      (fun j => rxDblk (RtRun.pf Rn) j (bp j).S (Pk j).nFunctionals (bp j).pA.rows (bp j).pH.rows (bp j).nA (bp j).nH)
      (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH)
      (k + 1)).Ok (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn) (2 ^ 26) (k + 1) := by
  set base := shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO
  set absOf := Exec.Block.absOfC (chainEncB key domain hs Lq hL)
  rw [rxPs_blk base Lb _ _ _ k hk]
  obtain ⟨hP, -, hlc, -⟩ := shieldBlkAtD_spec hPkD k hk
  have hS23 : (bp k).S = 23 := maskField_inj_S ((bp k).hPm.symm.trans hP.hPm)
  have hσb := ra_blk_seg Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck
    bndOpen Rn cx0 pin pout bp wXk gXk mXk hσ k hk
  have hpart := rx_part_of Rn (k + 1) _ hσb
  have hhi := blk_hhi_of_rtRun Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck
    bndOpen Rn cx0 pin pout bp wXk gXk mXk hσ k hk
  obtain ⟨Fsl, hb_eq⟩ := shd_blk_sls U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F
    lscIn lscOut pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO k hk
  change (base (k + 1)).sls = blockSchedXB (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) absOf Fsl at hb_eq
  have hlists := shd_hbBlk U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO k hk
  set D := shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO
  have hsq := blkLists_rkSqOk U tag h64 hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hP.hsl hlc
    (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
    (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
    ((RtRun.pf Rn).off (k + 1)) ((RtRun.pf Rn).off (k + 1 + 1)) ((RtRun.pf Rn).off (k + 1) + 5) rfl hhi absOf
  have hg_base := shdRkBase_gX_nX U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F
    lscIn lscOut pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO (k + 1)
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  refine
    { slCut := fun sl hsl => by
        change sl ∈ (base (k + 1)).sls at hsl
        rw [hb_eq] at hsl
        exact Exec.Block.blockSchedXB_cut (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) absOf Fsl sl hsl
      slDeg := fun sl hsl => by
        change sl ∈ (base (k + 1)).sls at hsl
        rw [hb_eq] at hsl
        obtain ⟨j, hj_r, rfl⟩ := List.mem_map.mp hsl
        have hj23 : j < 23 := by simpa [hsl23] using List.mem_range.mp hj_r
        have hsc := ra_shield_slot_conds j hj23
        have hsh_eq : slotShape (Pk k) j = Exec.Block.R13.shieldSlots.getD j (0, 0, 0) := by
          unfold slotShape; rw [hP.hsl]
        dsimp only [blockSlotXB]
        rw [hsh_eq]
        refine ⟨?_, hsc.2.1, hsc.2.2⟩
        show (Exec.Block.R13.shieldSlots.getD j (0, 0, 0)).2.2 < 18446744069414584321
        have := hsc.2.1; omega
      slWin := fun j sl hget => by
        change (base (k + 1)).sls[j]? = some sl at hget
        change _ ≤ slotsLenX ((base (k + 1)).sls.take j) + sl.s ∧ slotsLenX ((base (k + 1)).sls.take j) + sl.s ≤ _
        rw [hb_eq] at hget ⊢
        have hj_lt : j < (Pk k).geom.slots.length := by
          have h := List.getElem?_eq_some_iff.mp hget
          simpa [blockSchedXB] using h.1
        have hsl_eq : sl = blockSlotXB (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) absOf Fsl j := by
          rw [blockSchedXB_getElem? (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) absOf Fsl j hj_lt] at hget
          exact Option.some.inj hget.symm
        subst hsl_eq
        rw [blockSchedXB_win (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) absOf Fsl j (Nat.le_of_lt hj_lt)]
        have hoff_le := defOff_le_shapeLen (Pk k) (j + 1) (by omega)
        rw [defOff_succ_right (Pk k) 0 j, Nat.zero_add] at hoff_le
        unfold defPos
        exact ⟨by omega, by omega⟩
      mK := by
        dsimp only [rxSet, rxDblk]
        rw [hP.hnf, hS23]
        norm_num
      mS := by
        dsimp only [rxSet, rxDblk]
        rw [hpart]; rfl
      gA := rkR13_ok _ _
      gH := rkR13_ok _ _
      gX := by
        dsimp only [rxSet]
        rw [hg_base.1]
        rcases k with _ | j
        · rw [(shdRkBaseX_1_gX (K := K) Lq Lb hLb1 (RtRun.pf Rn) _ _ _ _ _ _ _ _).1]
          exact rkR13_ok _ _
        · rw [(shdRkBaseX_blk_gX (K := K) Lq Lb (RtRun.pf Rn) _ _ _ _ _ _ _ _ j hk).1]
          exact rkR13_ok _ _
      wA := by
        dsimp only [rxSet, rxDblk, rkR13]
        rw [hpart, ← (hBA k).hm]
        exact ⟨rfl, rfl⟩
      wH := by
        dsimp only [rxSet, rxDblk, rkR13]
        rw [hpart, ← (hBH k).hm]
        exact ⟨rfl, rfl⟩
      wX := by
        dsimp only [rxSet]
        rw [hg_base.1, hg_base.2, hpart]
        rcases k with _ | j
        · obtain ⟨eg, en⟩ := shdRkBaseX_1_gX (K := K) Lq Lb hLb1 (RtRun.pf Rn)
            Iin.pX.rows Iin.nIn Iin.nOut Oout.pX.rows Oout.nIn
            (fun i => (bp i).nIn) (fun i => (bp i).nOut) (fun i => (pXk i).rows)
          rw [eg, en]
          dsimp only [rkR13, rtBlockPart]
          exact ⟨hwX0.symm, (hXk 0).hm.symm.trans hmX0.symm⟩
        · obtain ⟨eg, en⟩ := shdRkBaseX_blk_gX (K := K) Lq Lb (RtRun.pf Rn)
            Iin.pX.rows Iin.nIn Iin.nOut Oout.pX.rows Oout.nIn
            (fun i => (bp i).nIn) (fun i => (bp i).nOut) (fun i => (pXk i).rows) j hk
          rw [eg, en]
          dsimp only [rkR13, rtBlockPart]
          exact ⟨(hwXk j hk).symm, (hXk (j + 1)).hm.symm.trans (hmXk j hk).symm⟩
      r0 := by dsimp only [rxSet]; rw [hlists.hr0]; exact hsq.1
      r1 := by dsimp only [rxSet]; rw [hlists.hr1]; exact hsq.2.1
      h0 := by dsimp only [rxSet]; rw [hlists.hh0]; exact hsq.2.2.1
      h1 := by dsimp only [rxSet]; rw [hlists.hh1]; exact hsq.2.2.2.1
      lu := by dsimp only [rxSet]; rw [hlists.hlu]; exact hsq.2.2.2.2 }

/-! ### Stage `RkPart.Ok` (`0` and `Lb + 1`) and `shdRkD_valid` -/

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem stgDefPos_mono (P : BlockParams) (m hdrLen : ℕ) {s1 s2 : ℕ} (h : s1 ≤ s2) :
    stgDefPos P m hdrLen s1 ≤ stgDefPos P m hdrLen s2 :=
  Nat.add_le_add_left (defOff_mono P 0 h) (hdrLen + (7 + m))

omit [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem stgDefsV_pairwise {Lq : ℕ} (P : BlockParams) (m hdrLen : ℕ) (absOf : QB Lq → Option (List UInt8))
    (Φ : StgVw Lq → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ) :
    (stgDefsV P m hdrLen absOf Φ dg).Pairwise (fun a b => a.a ≤ b.a) := by
  unfold stgDefsV stgDrawing
  rw [List.pairwise_map]
  exact ((List.pairwise_lt_range).filter _).imp (fun {k1 k2} hlt =>
    stgDefPos_mono P m hdrLen (Nat.le_of_lt hlt))

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem stg_inc_log_le64 (P0in : BlockParams) (Vi : IncV)
    (hPin0 : StgSame P0in (Vi.bp rcCx0))
    (hN64I : ∀ k, k < P0in.geom.slots.length → stgN P0in k < 64) :
    clog2 Vi.pub.inEpWords ≤ 64 ∧ Vi.pub.tiLog ≤ 64 ∧ Vi.pub.vocLog ≤ 64 := by
  have hlen4 : P0in.geom.slots.length = 4 := by rw [hPin0.2]; rfl
  have h0 := hN64I 0 (by omega)
  have h1 := hN64I 1 (by omega)
  have h2 := hN64I 2 (by omega)
  rw [stg_stgN hPin0 0] at h0
  rw [stg_stgN hPin0 1] at h1
  rw [stg_stgN hPin0 2] at h2
  change clog2 Vi.pub.inEpWords + 1 < 64 at h0
  change Vi.pub.tiLog + 1 < 64 at h1
  change Vi.pub.vocLog + 1 < 64 at h2
  exact ⟨by omega, by omega, by omega⟩

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem stg_outc_log_le64 (P0out : BlockParams) (V0 : OutcV)
    (hPout0 : StgSame P0out V0.bp)
    (hN64O : ∀ k, k < P0out.geom.slots.length → stgN P0out k < 64) :
    V0.pub.dBits ≤ 64 ∧ V0.pub.llo ≤ 64 ∧ V0.pub.ldo ≤ 64 ∧ V0.pub.ltab ≤ 64 := by
  have hlen8 : P0out.geom.slots.length = 8 := by rw [hPout0.2]; rfl
  have h0 := hN64O 0 (by omega)
  have h4 := hN64O 4 (by omega)
  have h5 := hN64O 5 (by omega)
  have h6 := hN64O 6 (by omega)
  rw [stg_stgN hPout0 0] at h0
  rw [stg_stgN hPout0 4] at h4
  rw [stg_stgN hPout0 5] at h5
  rw [stg_stgN hPout0 6] at h6
  change V0.pub.dBits + 1 < 64 at h0
  change V0.pub.llo + 1 < 64 at h4
  change V0.pub.ldo + 1 < 64 at h5
  change V0.pub.ltab + 1 < 64 at h6
  exact ⟨by omega, by omega, by omega, by omega⟩

/-- **Stage IN-C (`i = 0`) `RkPart.Ok`**, deriving the 64-bit log bounds from `hN64I` (`P.refused.hdr`) and wiring
`stgDefsV_valid_inC` for `r0`. -/
theorem shd_stg0_rkPartOk
    (hd0 : Hdr) (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb)
    (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (Pk : ℕ → BlockParams) (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom)
    (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →
      Except String Tr)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (cx0 : IncCtx) (pin pout : RtPart)
    (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hIA : RkPcsAt U tag ogStage Iin.pA) (hIH : RkPcsAt U tag ogStage Iin.pH) (hXep : RkPcsAt U tag ogEp Iin.pX)
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (Vi : IncV) (F : ℕ → OutcV) (hinc : ∀ hd, inc hd = Vi)
    (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (hNin : ∀ k, k < P0in.geom.slots.length → 0 < stgN P0in k ∧ stgN P0in k * (slotShape P0in k).2.2 + 2 ≤ 512)
    (hN64I : ∀ k, k < P0in.geom.slots.length → stgN P0in k < 64)
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx))
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (hSmI : 2 * pin.S + 2 ≤ 2 ^ 20)
    (hlcI : Vi.pub.lt ≤ ogStage.lc)
    (hIO0 : StgCsIODeg U hbij Vi.pub.epLogN (IncPrivIO0 Vi.pub) csIOI)
    (hIO1 : StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) csIOI)
    (hLuI : (stgLkSqV mIn ((RtRun.pf Rn).off 0 + 5) eI
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI).Rbr
      ∧ eI ≤ 2 ^ 26 ∧ mIn * eI ≤ 3 * 2 ^ 26) :
    (rxPs
      (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
        Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
        (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
        (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
        (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO) Lb
      (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)
      (fun j => rxDblk (RtRun.pf Rn) j (bp j).S (Pk j).nFunctionals (bp j).pA.rows (bp j).pH.rows (bp j).nA (bp j).nH)
      (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH)
      0).Ok (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn) (2 ^ 26) 0 := by
  set base := shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO
  set absOf := Exec.Block.absOfC (chainEncB key domain hs Lq hL)
  have hrx0 : rxPs base Lb
      (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)
      (fun j => rxDblk (RtRun.pf Rn) j (bp j).S (Pk j).nFunctionals (bp j).pA.rows (bp j).pH.rows (bp j).nA (bp j).nH)
      (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH) 0
    = rxSet (base 0) (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn) := rfl
  rw [hrx0]
  have hb0_lists := shd_hb0 U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO
  have hg_base := shdRkBase_gX_nX U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F
    lscIn lscOut pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO 0
  have hgX0 : (base 0).gX = rkAt ogEp Iin.pX.rows 1 ∧ (base 0).nX = Iin.nIn := hg_base
  have hPinV : ∀ cx, StgSame P0in (Vi.bp cx) := fun cx => by have h := hPin hd0 cx; rwa [hinc hd0] at h
  have hσ0 : (RtRun.σs Rn)[0]? = some (rtIncSeg inc incG cx0 pin) := by
    rw [hσ]; exact rx_get0 _ _ _ _
  have hpart0 : (RtRun.pf Rn).part 0 = pin := rx_part_of Rn 0 _ hσ0
  have hparts : (RtRun.pf Rn).parts.length = Lb + 2 := RtRun.parts_length Rn
  have hoff1 : (RtRun.pf Rn).off (0 + 1) = (RtRun.pf Rn).off 0 + pin.len := by
    rw [RtProf.off_succ (RtRun.pf Rn) 0 (by omega), hpart0]
  have hpre_le : pin.pre ≤ pin.len := rtPart_pre_le_len pin
  have hsh_eq : shapeLen P0in 0 P0in.geom.slots = shapeLen ((inc hd0).bp rcCx0) 0 (inc hd0).geom.slots := by
    have hps := hPin hd0 rcCx0
    have hg_eq : (inc hd0).geom.slots = ((inc hd0).bp rcCx0).geom.slots := rfl
    rw [hg_eq, ← hps.2]
    exact rc_shapeLen_congr P0in ((inc hd0).bp rcCx0) hps.1 0 P0in.geom.slots
  have hpre_val : 12 + mIn + shapeLen P0in 0 P0in.geom.slots = pin.pre := by
    rw [hsh_eq, ← hmIn hd0]
    exact Iin.hpre hd0 rcCx0
  have hkIn8 : kIn = 8 := by
    have hk := hkIn hd0
    rw [hinc hd0] at hk
    exact hk.symm.trans rfl
  obtain ⟨hc0, hc1, hc2⟩ := stg_inc_log_le64 P0in Vi (hPinV rcCx0) hN64I
  have hr0_ent := stgDefsV_valid_inC U hbij tag h64 hU P0in Vi ((RtRun.pf Rn).off 0 + pin.pre)
    ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows csIOI absOf
    hPinV hlcI hIO0 hIO1 hc0 hc1 hc2
  refine
    { slCut := fun sl hsl => by
        change sl ∈ (base 0).sls at hsl
        rw [hb0_lists.hsls] at hsl
        obtain ⟨j, _, rfl⟩ := List.mem_map.mp hsl
        exact stgSlotV_cut P0in mIn _ _ absOf _ j
      slDeg := fun sl hsl => by
        change sl ∈ (base 0).sls at hsl
        rw [hb0_lists.hsls] at hsl
        obtain ⟨j, hj_r, rfl⟩ := List.mem_map.mp hsl
        have hj_lt : j < P0in.geom.slots.length := List.mem_range.mp hj_r
        have hj_v : j < Vi.geom.slots.length := by
          have hg_eq : Vi.geom.slots = (Vi.bp rcCx0).geom.slots := rfl
          rw [hg_eq, ← (hPinV rcCx0).2]; exact hj_lt
        have hbnd := rc_incBounds Vi rcCx0 j hj_v
        rw [← stg_slotShape (hPinV rcCx0) j] at hbnd
        have hnj := (hNin j hj_lt).2
        dsimp only [stgSlotV]
        refine ⟨?_, by omega, by omega⟩
        show (slotShape P0in j).2.2 < 18446744069414584321
        omega
      slWin := fun j sl hget => by
        change (base 0).sls[j]? = some sl at hget
        change _ ≤ slotsLenX ((base 0).sls.take j) + sl.s ∧ slotsLenX ((base 0).sls.take j) + sl.s ≤ _
        rw [hb0_lists.hsls] at hget ⊢
        obtain ⟨hj_lt, rfl⟩ := (stgSchedV_get P0in mIn _ _ absOf _ j sl).mp hget
        rw [stgV_win P0in mIn _ _ absOf _ j (Nat.le_of_lt hj_lt)]
        have hoff_d := defOff_le_shapeLen P0in (j + 1) (by omega)
        rw [defOff_succ_right P0in 0 j, Nat.zero_add] at hoff_d
        unfold stgDefPos
        exact ⟨by omega, by omega⟩
      mK := by
        dsimp only [rxSet, rxDinG]
        rw [hkIn8]
        exact ⟨by norm_num, by norm_num, hSmI⟩
      mS := by
        dsimp only [rxSet, rxDinG]
        rw [hpart0]
      gA := rkAt_ok ogStage ogStage_ok _ _
      gH := rkAt_ok ogStage ogStage_ok _ _
      gX := by dsimp only [rxSet]; rw [hgX0.1]; exact rkAt_ok ogEp ogEp_ok _ _
      wA := by
        dsimp only [rxSet, rxDinG, rkAt]
        rw [hpart0]
        exact ⟨Iin.hwA, (RkPcsAt.hm U tag hIA (by decide)).symm.trans Iin.hmA⟩
      wH := by
        dsimp only [rxSet, rxDinG, rkAt]
        rw [hpart0]
        exact ⟨Iin.hwH, (RkPcsAt.hm U tag hIH (by decide)).symm.trans Iin.hmH⟩
      wX := by
        dsimp only [rxSet]
        rw [hgX0.1, hgX0.2, hpart0]
        dsimp only [rkAt]
        exact ⟨Iin.hwX, (RkPcsAt.hm U tag hXep (by decide)).symm.trans Iin.hmX⟩
      r0 := by
        dsimp only [rxSet]; rw [hb0_lists.hr0]
        refine ⟨fun sx hsx => ?_, stgDefsV_pairwise P0in mIn _ absOf _ sshDgI⟩
        obtain ⟨h1, h2, h3, h4⟩ := hr0_ent sx hsx
        obtain ⟨j, hj_mem, rfl⟩ := List.mem_map.mp hsx
        have hj_lt : j < P0in.geom.slots.length := List.mem_range.mp (List.mem_filter.mp hj_mem).1
        have hoff_d := defOff_le_shapeLen P0in j (Nat.le_of_lt hj_lt)
        dsimp only [stgDefSqV, stgDefPos]
        exact ⟨h1, h2, h3, h4, by omega, by omega⟩
      r1 := by dsimp only [rxSet]; rw [hb0_lists.hr1]; exact ⟨fun _ h => absurd h List.not_mem_nil, List.Pairwise.nil⟩
      h0 := by dsimp only [rxSet]; rw [hb0_lists.hh0]; exact ⟨fun _ h => absurd h List.not_mem_nil, List.Pairwise.nil⟩
      h1 := by dsimp only [rxSet]; rw [hb0_lists.hh1]; exact ⟨fun _ h => absurd h List.not_mem_nil, List.Pairwise.nil⟩
      lu := by
        dsimp only [rxSet]; rw [hb0_lists.hlu]
        refine ⟨fun sx hsx => ?_, List.pairwise_singleton _ _⟩
        simp only [List.mem_singleton] at hsx
        subst hsx
        refine ⟨stgLkSqV_cut mIn _ eI absOf ΛI, hLuI.1, hLuI.2.1, hLuI.2.2, ?_, ?_⟩
        · dsimp only [stgLkSqV]; omega
        · dsimp only [stgLkSqV]; omega }

/-- **Stage OUT-C (`i = Lb + 1`) `RkPart.Ok`**, deriving the 64-bit log bounds from `hN64O` (`P.refused.hdr`) and wiring
`stgDefsV_valid_out` for `r0`. -/
theorem shd_stgOut_rkPartOk
    (hd0 : Hdr) (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb)
    (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (Pk : ℕ → BlockParams) (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom)
    (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →
      Except String Tr)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (cx0 : IncCtx) (pin pout : RtPart)
    (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hOA : RkPcsAt U tag ogStage Oout.pA) (hOH : RkPcsAt U tag ogStage Oout.pH) (hOX : RkPcsR13 U tag Oout.pX)
    (hwXo : ∀ k, k + 1 = Lb → pout.wX = (bp k).nOut + Oout.nIn + Oout.pX.rows)
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (Vi : IncV) (F : ℕ → OutcV) (houtc : ∀ hd v, outc hd v = F v)
    (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (hNout : ∀ k, k < P0out.geom.slots.length → 0 < stgN P0out k ∧ stgN P0out k * (slotShape P0out k).2.2 + 2 ≤ 512)
    (hN64O : ∀ k, k < P0out.geom.slots.length → stgN P0out k < 64)
    (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (hSmO : 2 * pout.S + 2 ≤ 2 ^ 20)
    (hlcO : ∀ b, (F b).pub.lt ≤ ogStage.lc)
    (hIOO_deg : ∀ b, StgCsIODeg U hbij (F b).geo.bLogN (OutcPrivIO (F b).pub) csIOO)
    (hLuO : (stgLkSqV 2 ((RtRun.pf Rn).off (Lb + 1) + 2) eO
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO).Rbr ∧ eO ≤ 2 ^ 26) :
    (rxPs
      (shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
        Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
        (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
        (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
        (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO) Lb
      (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)
      (fun j => rxDblk (RtRun.pf Rn) j (bp j).S (Pk j).nFunctionals (bp j).pA.rows (bp j).pH.rows (bp j).nA (bp j).nH)
      (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH)
      (Lb + 1)).Ok (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn) (2 ^ 26) (Lb + 1) := by
  set base := shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO
  set absOf := Exec.Block.absOfC (chainEncB key domain hs Lq hL)
  rw [rxPs_out base Lb _ _ _]
  have hbL_lists := shd_hbL U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO
  have hg_base := shdRkBase_gX_nX U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F
    lscIn lscOut pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO (Lb + 1)
  have hPoutF : ∀ b, StgSame P0out (F b).bp := fun b => by have h := hPout hd0 b; rwa [houtc hd0 b] at h
  have hσL : (RtRun.σs Rn)[Lb + 1]? = some (rtOutcSeg outc outcG pout) := by
    rw [hσ]; exact rx_getOut _ _ _ _
  have hpartL : (RtRun.pf Rn).part (Lb + 1) = pout := rx_part_of Rn (Lb + 1) _ hσL
  have hparts : (RtRun.pf Rn).parts.length = Lb + 2 := RtRun.parts_length Rn
  have hoffL : (RtRun.pf Rn).off (Lb + 1 + 1) = (RtRun.pf Rn).off (Lb + 1) + pout.len := by
    rw [RtProf.off_succ (RtRun.pf Rn) (Lb + 1) (by omega), hpartL]
  have hpre_le : pout.pre ≤ pout.len := rtPart_pre_le_len pout
  have hsh_eq : shapeLen P0out 0 P0out.geom.slots = shapeLen (outc hd0 0).bp 0 (outc hd0 0).geom.slots := by
    have hps := hPout hd0 0
    have hg_eq : (outc hd0 0).geom.slots = (outc hd0 0).bp.geom.slots := rfl
    rw [hg_eq, ← hps.2]
    exact rc_shapeLen_congr P0out (outc hd0 0).bp hps.1 0 P0out.geom.slots
  have hpre_val : 11 + shapeLen P0out 0 P0out.geom.slots = pout.pre := by
    rw [hsh_eq]; exact Oout.hpre hd0 0
  have hkOut14 : kOut = 14 := by
    have hk := hkOut hd0 0
    rw [houtc hd0 0] at hk
    exact hk.symm.trans rfl
  obtain ⟨hc0, hc1, hc2, hc3⟩ := stg_outc_log_le64 P0out (F 0) (hPoutF 0) hN64O
  have hr0_ent := stgDefsV_valid_out U hbij tag h64 hU P0out F ((RtRun.pf Rn).off (Lb + 1) + pout.pre)
    ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows csIOO absOf
    hPoutF hlcO hIOO_deg hc0 hc1 hc2 hc3
  obtain ⟨mPred, hmPred⟩ : ∃ mPred, mPred + 1 = Lb := ⟨Lb - 1, by omega⟩
  have hgX_out : (base (Lb + 1)).gX = rkR13 Oout.pX.rows ((RtRun.pf Rn).off Lb + 2)
      ∧ (base (Lb + 1)).nX = (bp mPred).nOut + Oout.nIn := by
    rw [hg_base.1, hg_base.2]
    have hout := shdRkBaseX_out_gX (K := K) Lq Lb (RtRun.pf Rn)
      Iin.pX.rows Iin.nIn Iin.nOut Oout.pX.rows Oout.nIn
      (fun j => (bp j).nIn) (fun j => (bp j).nOut) (fun j => (pXk j).rows) mPred hmPred
    rwa [hmPred] at hout
  refine
    { slCut := fun sl hsl => by
        change sl ∈ (base (Lb + 1)).sls at hsl
        rw [hbL_lists.hsls] at hsl
        obtain ⟨j, _, rfl⟩ := List.mem_map.mp hsl
        exact stgSlotV_cut P0out 2 _ _ absOf _ j
      slDeg := fun sl hsl => by
        change sl ∈ (base (Lb + 1)).sls at hsl
        rw [hbL_lists.hsls] at hsl
        obtain ⟨j, hj_r, rfl⟩ := List.mem_map.mp hsl
        have hj_lt : j < P0out.geom.slots.length := List.mem_range.mp hj_r
        have hj_v : j < (F 0).geom.slots.length := by
          have hg_eq : (F 0).geom.slots = (F 0).bp.geom.slots := rfl
          rw [hg_eq, ← (hPoutF 0).2]; exact hj_lt
        have hbnd := rc_outcBounds (F 0) j hj_v
        rw [← stg_slotShape (hPoutF 0) j] at hbnd
        have hnj := (hNout j hj_lt).2
        dsimp only [stgSlotV]
        refine ⟨?_, by omega, by omega⟩
        show (slotShape P0out j).2.2 < 18446744069414584321
        omega
      slWin := fun j sl hget => by
        change (base (Lb + 1)).sls[j]? = some sl at hget
        change _ ≤ slotsLenX ((base (Lb + 1)).sls.take j) + sl.s ∧ slotsLenX ((base (Lb + 1)).sls.take j) + sl.s ≤ _
        rw [hbL_lists.hsls] at hget ⊢
        obtain ⟨hj_lt, rfl⟩ := (stgSchedV_get P0out 2 _ _ absOf _ j sl).mp hget
        rw [stgV_win P0out 2 _ _ absOf _ j (Nat.le_of_lt hj_lt)]
        have hoff_d := defOff_le_shapeLen P0out (j + 1) (by omega)
        rw [defOff_succ_right P0out 0 j, Nat.zero_add] at hoff_d
        unfold stgDefPos
        exact ⟨by omega, by omega⟩
      mK := by
        dsimp only [rxSet, rxDoutG]
        rw [hkOut14]
        exact ⟨by norm_num, by norm_num, hSmO⟩
      mS := by
        dsimp only [rxSet, rxDoutG]
        rw [hpartL]
      gA := rkAt_ok ogStage ogStage_ok _ _
      gH := rkAt_ok ogStage ogStage_ok _ _
      gX := by
        dsimp only [rxSet]; rw [hgX_out.1]; exact rkR13_ok _ _
      wA := by
        dsimp only [rxSet, rxDoutG, rkAt]
        rw [hpartL]
        exact ⟨Oout.hwA, (RkPcsAt.hm U tag hOA (by decide)).symm.trans Oout.hmA⟩
      wH := by
        dsimp only [rxSet, rxDoutG, rkAt]
        rw [hpartL]
        exact ⟨Oout.hwH, (RkPcsAt.hm U tag hOH (by decide)).symm.trans Oout.hmH⟩
      wX := by
        dsimp only [rxSet]
        rw [hgX_out.1, hgX_out.2, hpartL]
        dsimp only [rkR13]
        exact ⟨(hwXo mPred hmPred).symm, hOX.hm.symm.trans Oout.hmX⟩
      r0 := by
        dsimp only [rxSet]; rw [hbL_lists.hr0]
        refine ⟨fun sx hsx => ?_, stgDefsV_pairwise P0out 2 _ absOf _ sshDgO⟩
        obtain ⟨h1, h2, h3, h4⟩ := hr0_ent sx hsx
        obtain ⟨j, hj_mem, rfl⟩ := List.mem_map.mp hsx
        have hj_lt : j < P0out.geom.slots.length := List.mem_range.mp (List.mem_filter.mp hj_mem).1
        have hoff_d := defOff_le_shapeLen P0out j (Nat.le_of_lt hj_lt)
        dsimp only [stgDefSqV, stgDefPos]
        exact ⟨h1, h2, h3, h4, by omega, by omega⟩
      r1 := by dsimp only [rxSet]; rw [hbL_lists.hr1]; exact ⟨fun _ h => absurd h List.not_mem_nil, List.Pairwise.nil⟩
      h0 := by dsimp only [rxSet]; rw [hbL_lists.hh0]; exact ⟨fun _ h => absurd h List.not_mem_nil, List.Pairwise.nil⟩
      h1 := by dsimp only [rxSet]; rw [hbL_lists.hh1]; exact ⟨fun _ h => absurd h List.not_mem_nil, List.Pairwise.nil⟩
      lu := by
        dsimp only [rxSet]; rw [hbL_lists.hlu]
        refine ⟨fun sx hsx => ?_, List.pairwise_singleton _ _⟩
        simp only [List.mem_singleton] at hsx
        subst hsx
        refine ⟨stgLkSqV_cut 2 _ eO absOf ΛO, hLuO.1, hLuO.2, ?_, ?_, ?_⟩
        · dsimp only [stgLkSqV]; have := hLuO.2; omega
        · dsimp only [stgLkSqV]; omega
        · dsimp only [stgLkSqV]; omega }

/-- **`shdRkD.Valid` assembled across all `Lb + 2` parts via `ebData_valid` (`M2` closed).** -/
theorem shdRkD_valid
    (hd0 : Hdr) (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb)
    (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (Pk : ℕ → BlockParams) (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom)
    (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →
      Except String Tr)
    {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid)
    (cx0 : IncCtx) (pin pout : RtPart)
    (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hIA : RkPcsAt U tag ogStage Iin.pA) (hIH : RkPcsAt U tag ogStage Iin.pH)
    (hOA : RkPcsAt U tag ogStage Oout.pA) (hOH : RkPcsAt U tag ogStage Oout.pH)
    (hBA : ∀ k, RkPcsR13 U tag (bp k).pA) (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (hXk : ∀ k, RkPcsR13 U tag (pXk k))
    (hwXk : ∀ k, k + 1 < Lb → wXk (k + 1) = (bp k).nOut + (bp (k + 1)).nIn + (pXk (k + 1)).rows)
    (hmXk : ∀ k, k + 1 < Lb → mXk (k + 1) = (pXk (k + 1)).m)
    (hwX0 : wXk 0 = Iin.nOut + (bp 0).nIn + (pXk 0).rows) (hmX0 : mXk 0 = (pXk 0).m)
    (hOX : RkPcsR13 U tag Oout.pX)
    (hwXo : ∀ k, k + 1 = Lb → pout.wX = (bp k).nOut + Oout.nIn + Oout.pX.rows)
    (hXep : RkPcsAt U tag ogEp Iin.pX)
    (Vi : IncV) (F : ℕ → OutcV) (hinc : ∀ hd, inc hd = Vi) (houtc : ∀ hd v, outc hd v = F v)
    (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn)
    (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
    (P0in P0out : BlockParams)
    (csIOI csIOO : StgVw Lq → Cm → Exec.Block.ZClaim → K)
    (hNin : ∀ k, k < P0in.geom.slots.length → 0 < stgN P0in k ∧ stgN P0in k * (slotShape P0in k).2.2 + 2 ≤ 512)
    (hNout : ∀ k, k < P0out.geom.slots.length → 0 < stgN P0out k ∧ stgN P0out k * (slotShape P0out k).2.2 + 2 ≤ 512)
    (hN64I : ∀ k, k < P0in.geom.slots.length → stgN P0in k < 64)
    (hN64O : ∀ k, k < P0out.geom.slots.length → stgN P0out k < 64)
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx))
    (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (hSm : 2 * pin.S + 2 ≤ 2 ^ 20 ∧ 2 * pout.S + 2 ≤ 2 ^ 20)
    (hlcStg : Vi.pub.lt ≤ ogStage.lc ∧ ∀ b, (F b).pub.lt ≤ ogStage.lc)
    (hCsIO : StgCsIODeg U hbij Vi.pub.epLogN (IncPrivIO0 Vi.pub) csIOI
      ∧ StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) csIOI
      ∧ ∀ b, StgCsIODeg U hbij (F b).geo.bLogN (OutcPrivIO (F b).pub) csIOO)
    (hLuStg : (stgLkSqV mIn ((RtRun.pf Rn).off 0 + 5) eI
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI).Rbr
      ∧ eI ≤ 2 ^ 26 ∧ mIn * eI ≤ 3 * 2 ^ 26
      ∧ (stgLkSqV 2 ((RtRun.pf Rn).off (Lb + 1) + 2) eO
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO).Rbr
      ∧ eO ≤ 2 ^ 26) :
    (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
      Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
      (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
      (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
      (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn) := by
  have hK : Fintype.card K = gP ^ 2 := card_of_pairs gP (Equiv.ofBijective _ hbij)
  have hparts : (RtRun.pf Rn).parts.length = Lb + 2 := RtRun.parts_length Rn
  rw [shdRkD_eq_ebData U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
    Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
    (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
    (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
    (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO]
  refine ebData_valid U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn) hv _ _ _ (2 ^ 26) hK (fun i hi => ?_) le_rfl
  rcases i with _ | k
  · exact shd_stg0_rkPartOk hd0 U hU hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1
      preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen hPkD Rn
      cx0 pin pout Iin Oout bp wXk gXk mXk hσ hIA hIH hXep pXk Vi F hinc lscIn lscOut mIn kIn kOut
      hmIn hkIn P0in P0out csIOI csIOO hNin hN64I hPin eI eO ΛI ΛO hSm.1 hlcStg.1 hCsIO.1 hCsIO.2.1
      ⟨hLuStg.1, hLuStg.2.1, hLuStg.2.2.1⟩
  · by_cases hk : k < Lb
    · exact shd_blk_rkPartOk U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1
        preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen hPkD Rn
        cx0 pin pout Iin Oout bp wXk gXk mXk hσ hBA hBH pXk hXk hwXk hmXk hwX0 hmX0
        Vi F lscIn lscOut mIn kIn kOut P0in P0out csIOI csIOO eI eO ΛI ΛO k hk
    · have hk_eq : k = Lb := by omega
      subst k
      exact shd_stgOut_rkPartOk hd0 U hU hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1
        preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen hPkD Rn
        cx0 pin pout Iin Oout bp wXk gXk mXk hσ hOA hOH hOX hwXo pXk Vi F houtc lscIn lscOut mIn kIn kOut
        hkOut P0in P0out csIOI csIOO hNout hN64O hPout eI eO ΛI ΛO hSm.2 hlcStg.2 hCsIO.2.2
        ⟨hLuStg.2.2.2.1, hLuStg.2.2.2.2⟩

end ConcretePinsAndValid

/-! ## 4. `ShieldRunAtD` block alive theorems (`shield_hR0_blkD .. shield_hLU_blkD`, `shield_hblkD`) -/

section BlkAliveRunD

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable {Hdr : Type} {Lq : ℕ} (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
  (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
  (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq) (hL64 : Lq < 2 ^ 64)
  (Lb : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → BlockParams) (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →
    Except String Tr)

noncomputable def shieldAlkLD {S0 : BlockShape} {blks : List (RunBlock S0)}
    (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ)
    (cr : List (QB Lq × Dig) × Option (List UInt8)) :
    SgIx (Exec.Block.DefR13.cfgShieldR13 shieldDfltLy)
      ⊕ (PrIx (Exec.Block.DefR13.cfgShieldR13 shieldDfltLy) 1
        ⊕ PrIx (Exec.Block.DefR13.cfgShieldR13 shieldDfltLy) 1) → Tup K :=
  if hk : k < Lb then
    AlkR13B U (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k)
      (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (geoShield (shieldLyD hPkD k hk))
      (dofARB tag hL20 (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1 16 256 24448 4577 4390 rE0 QE0 XE0) cr
  else fun _ => ⟨0, 0, 0, 0⟩

noncomputable def shieldTLD {S0 : BlockShape} {blks : List (RunBlock S0)}
    (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ) : TbIx → Tup K :=
  if hk : k < Lb then
    TR13 (K := K) (shieldPbD hPkD k hk).exp (shieldPbD hPkD k hk).act (shieldShape (shieldLyD hPkD k hk)).nG
  else fun _ => ⟨0, 0, 0, 0⟩

noncomputable def shieldMlkLD {S0 : BlockShape} {blks : List (RunBlock S0)}
    (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb) (k : ℕ)
    (cr : List (QB Lq × Dig) × Option (List UInt8)) : TbIx → K :=
  if hk : k < Lb then
    mlkR13B U (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k)
      (dofARB tag hL20 (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1 16 256 24448 4577 4390 rE0 QE0 XE0) cr
  else fun _ => 0

include hU in
theorem shield_hR0_blkD
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
    (hPkD : ShieldRunAtD tag dPos0 Pk Rp.blks Lb)
    (hoAK : ∀ k, k < Lb → (D.opA (k + 1)).lc = rowLog (Pk k) .a)
    (hoHK : ∀ k, k < Lb → (D.opH (k + 1)).lc = rowLog (Pk k) .h)
    (hoIK : ∀ k, k < Lb → (D.opX (k + 1)).lc = rowLog (Pk k) .inp)
    (hoOK : ∀ k, k < Lb → (D.opX (k + 1 + 1)).lc = rowLog (Pk k) .out)
    (hslB : ∀ k, k < Lb → D.sls (k + 1) = blockSchedXB (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (bwFslRun U tag Lq h64 Lb Pk (fun k => (bp k).S) D (RtRun.pf Rn) hoAK hoHK hoIK hoOK
        (shieldRunProg hPkD.toShieldRunAt) (shieldRunPubs hPkD.toShieldRunAt) k))
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).1.hsl (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
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
  have hr0_eq : D.r0 (k + 1) = (base (k + 1)).r0 := by rw [hDe]; exact rxPs_r0_blk base Lb _ _ _ hk
  rw [hr0_eq, (hbBlk k hk).hr0] at hsx
  obtain ⟨hP, hdef, hlc, hep14, hk3, hk19, hk20, hk21, hk22, hls, hLay, -⟩ := shieldBlkAtD_spec hPkD k hk
  have hLy := shieldLyD_mem hPkD k hk
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  obtain ⟨hrA, hrH⟩ := hbpRows k hk
  have hopA_eq : D.opA (k + 1) = rkOpen U tag Lq h64 key domain hs hL
      (rkR13 4577 ((RtRun.pf Rn).off (k + 1) + 5)) (bp k).nA
      (fun hdr' => (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb (k + 1) hdr').claims.a)
      ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oA + ((bp k).nA + 4577)) := by
    rw [hDe]; show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = _
    rw [rxPs_blk base Lb _ _ _ k hk]; simp only [rxSet, rxDblk, hrA]; rfl
  have hopH_eq : D.opH (k + 1) = rkOpen U tag Lq h64 key domain hs hL
      (rkR13 4390 ((RtRun.pf Rn).off (k + 1) + (5 + 7))) (bp k).nH
      (fun hdr' => (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb (k + 1) hdr').claims.h
        ++ [rxLsc lscIn lscOut Pk Lb (k + 1)])
      ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH + ((bp k).nH + 4390)) := by
    rw [hDe]; show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = _
    rw [rxPs_blk base Lb _ _ _ k hk]; simp only [rxSet, rxDblk, hrH]; rfl
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
          htB hfBM Vi F lscIn lscOut mIn kIn kOut _ _ _ _ _ _ _ _ base eL D hD hDe hPkD.toShieldRunAt
          hoAK hoHK hoIK hoOK hslB A G hE hnoX (Rp.blks.length + 2) (by omega) hM hsl k hk _ _ hdef
          hdr core bga rs acc T' hsa htr i r' hr'
      obtain ⟨df, hdf, -, -, hst_s, hho_s⟩ := hum_all s r hr
      rcases hsa.2.2.2 with ⟨hsh', t'', hbs''⟩
      obtain ⟨-, hall_fns⟩ := blockSlots_fns (liftH G) (Pk k) core _ bga rs acc t'' hbs''
      have hslots_kind : ∀ j r', rs[j]? = some r' →
          ∃ df', (Pk k).define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r'.draws = .ok df'
            ∧ ((Pk k).kind j = SlotKind.host ↔ df'.hosted ≠ []) := by
        intro j r' hr'
        have hjc : j < core.slots.length := by
          obtain ⟨-, -, hrslen, -⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
            (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
          rw [hsh'.1, ← hrslen]; exact (List.getElem?_eq_some_iff.mp hr').1
        obtain ⟨sp', hsp'⟩ : ∃ sp', core.slots[j]? = some sp' := ⟨_, List.getElem?_eq_getElem hjc⟩
        obtain ⟨df', hdf', -, -, -, hkind', -⟩ := hall_fns j sp' r' hsp' hr'
        exact ⟨df', hdf', hkind'⟩
      have hf_dXof := formAt_hostsR U hU (card_K_gt K) (shieldPbD hPkD k hk) (geoShield (shieldLyD hPkD k hk))
        (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (Pk k) (shOk_shield _ (Pk k) hP.hdr)
        (profR_shield _ (Pk k) hP.hdr hP.hsl)
        (Exec.Block.Join.R13H.Tzc.tzcCfg_shield _) (Exec.Block.Join.R13H.Dzc.dzcCfg_shield _ hLy)
        (Exec.Block.Join.R13H.Qkv.qkvCfg_shieldExport _ hLy) (Exec.Block.Join.R13H.Szc.szcCfg_shield _ hLy)
        (Exec.Block.Join.R13H.Fzc.fzcCfg_shield _ hLy)
        (shieldIoInD hPkD k hk) (shieldIoOutD hPkD k hk) _ hdef
        (blkDof tag hL20 (Pk k) hlc)
        (fun cu' rt' => dXof_base_r13 tag hL20 (Pk k) hlc 4577 4390 rE0 QE0 XE0 cu' rt')
        (by show 0 < (Pk k).logCols; rw [hlc]; norm_num)
        (by show 0 < (Pk k).logCols; rw [hlc]; norm_num)
        (precR_shield _) (shieldWindows _ hLy) hLay
        (Exec.Block.Join.R13H.Pub.pubR_of_L _ _ _ _ _ U hU)
        (perRow_shield _)
        (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
        (rootsOf core) bga rs hslots_kind s hhost
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
        simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hhost; omega
      have hf_dArgs := formAt_congr_poly U (Pk k) _ _ _ bga rs s
        (polyS_congr_ah U (Pk k) hsame_k (shieldLyD hPkD k hk) hLy _ _ _ s hs21 _)
        (fun r' df' _ hdf' hk' hmem' =>
          polyS_congr_ah U (Pk k) hsame_k (shieldLyD hPkD k hk) hLy _ _ _ hk'.1
            (progR13_hosted_lt21 _ _ _ s _ _ _ df' (hdef ▸ hdf') hk' hmem') _)
        hf_dXof
      have hΦ_eq : (w16r2DR (Pk k) (algSp U
            (algShapeR (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k) (shOk_shield _ (Pk k) hP.hdr))
            (blkAlgDt U tag hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hlc
              (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk))
            (card_K_gt K)) 0).Φ
            (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
            (rootsOf core) s (histOf bga.1 bga.2.1 bga.2.2 (rs.take s))
          = (algSp U
            (algShapeR (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k) (shOk_shield _ (Pk k) hP.hdr))
            (blkAlgDt U tag hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hlc
              (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk))
            (card_K_gt K) 0
            (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
            (rootsOf core) s (histOf bga.1 bga.2.1 bga.2.2 (rs.take s))).Φ := rfl
      rw [hΦ_eq]
      exact formAt_vanish U (Pk k) _ _ bga rs s r df hr hdf hst_s hho_s hf_dArgs
    · rcases Exec.Block.Join.W16.Lk.relKs0_rest s hs0 hhost with rfl | rfl | rfl <;> rfl
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
        htB hfBM Vi F lscIn lscOut mIn kIn kOut _ _ _ _ _ _ _ _ base eL D hD hDe hPkD.toShieldRunAt
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
    have hf_io := formAt_ioDefSchedB U tag h64 hL20 key domain hs hL (shieldLyD hPkD k hk) (Pk k) _ hP
      hlc hep14 hk21 hk22 (shieldIoInD hPkD k hk) (shieldIoOutD hPkD k hk)
      (Exec.Block.Join.R13H.Pub.pubsR13L (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk))
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (shieldShape (shieldLyD hPkD k hk)).nG)
      _ _ _ _ _ _ _ _
      (D.opX (k + 1)) (D.opX (k + 1 + 1)) hoA' hoH' (hoIK k hk) (hoOK k hk) rE0 QE0 XE0
      (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
      (rootsOf core)
      (hdrX (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2
        ((RtRun.pf Rn).off (k + 1) + 5) (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
      ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2) bga rs s hsio
    exact formAt_vanish U (Pk k) _ _ bga rs s r df hr hdf hst_s hho_s hf_io

theorem shield_hR1_blkD
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
    (hPkD : ShieldRunAtD tag dPos0 Pk Rp.blks Lb)
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).1.hsl (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
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
  have hr1_eq : D.r1 (k + 1) = (base (k + 1)).r1 := by rw [hDe]; exact rxPs_r1_blk base Lb _ _ _ hk
  rw [hr1_eq, (hbBlk k hk).hr1] at hsx
  obtain ⟨s, hs1, rfl⟩ := List.mem_map.mp hsx
  obtain ⟨hP, -, hlc, -⟩ := shieldBlkAtD_spec hPkD k hk
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
      (algShapeR (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k) (shOk_shield _ (Pk k) hP.hdr))
      (blkAlgDt U tag hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hlc
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk))
      (card_K_gt K)) 0)
      (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
      (rootsOf core) bga rs := by
    intro s0 hs0
    have hs0_23 : s0 < (Pk k).geom.slots.length := by
      rw [hsl23]; exact (Exec.Block.w16r2RelKs_facts 0 (by norm_num)).2 s0 hs0
    have hmem0 : blkRelSq U tag hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hlc
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
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

theorem shield_hH0_blkD
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
    (hPkD : ShieldRunAtD tag dPos0 Pk Rp.blks Lb)
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).1.hsl (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
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
  have hh0_eq : D.h0 (k + 1) = (base (k + 1)).h0 := by rw [hDe]; exact rxPs_h0_blk base Lb _ _ _ hk
  rw [hh0_eq, (hbBlk k hk).hh0] at hsx
  obtain ⟨hP, -, hlc, -⟩ := shieldBlkAtD_spec hPkD k hk
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hparts : (RtRun.pf Rn).parts.length = Lb + 2 := RtRun.parts_length Rn
  have hgd1_of : ∀ hdr core bga rs acc T',
      Exec.Block.SlotsAcc key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G (hdr, core) bga rs acc →
      rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)
        = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Exec.Block.allOps (Pk k) (hdr, core) ++ T') →
      SchedGd (w16r2DR (Pk k) (algSp U
        (algShapeR (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k) (shOk_shield _ (Pk k) hP.hdr))
        (blkAlgDt U tag hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hlc
          (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk))
        (card_K_gt K)) 1)
        (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
        (rootsOf core) bga rs := by
    intro hdr core bga rs acc T' hsa htr s1 hs1
    have hs1_23 : s1 < (Pk k).geom.slots.length := by
      rw [hsl23]; exact (Exec.Block.w16r2RelKs_facts 1 (by norm_num)).2 s1 hs1
    have hmem1 : blkRelSq U tag hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hlc
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) 1 s1 ∈ D.r1 (k + 1) := by
      have hr1_eq : D.r1 (k + 1) = (base (k + 1)).r1 := by rw [hDe]; exact rxPs_r1_blk base Lb _ _ _ hk
      rw [hr1_eq, (hbBlk k hk).hr1]; exact List.mem_map_of_mem hs1
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
theorem shield_hH1_blkD
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
    (hPkD : ShieldRunAtD tag dPos0 Pk Rp.blks Lb)
    (hoAK : ∀ k, k < Lb → (D.opA (k + 1)).lc = rowLog (Pk k) .a)
    (hoHK : ∀ k, k < Lb → (D.opH (k + 1)).lc = rowLog (Pk k) .h)
    (hoIK : ∀ k, k < Lb → (D.opX (k + 1)).lc = rowLog (Pk k) .inp)
    (hoOK : ∀ k, k < Lb → (D.opX (k + 1 + 1)).lc = rowLog (Pk k) .out)
    (hslB : ∀ k, k < Lb → D.sls (k + 1) = blockSchedXB (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (bwFslRun U tag Lq h64 Lb Pk (fun k => (bp k).S) D (RtRun.pf Rn) hoAK hoHK hoIK hoOK
        (shieldRunProg hPkD.toShieldRunAt) (shieldRunPubs hPkD.toShieldRunAt) k))
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).1.hsl (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
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
  have hh1_eq : D.h1 (k + 1) = (base (k + 1)).h1 := by rw [hDe]; exact rxPs_h1_blk base Lb _ _ _ hk
  rw [hh1_eq, (hbBlk k hk).hh1] at hsx
  obtain ⟨s, hs0, rfl⟩ := List.mem_map.mp hsx
  obtain ⟨hP, hdef, hlc, -, hk3, hk19, hk20, -, -, -, hLay, -⟩ := shieldBlkAtD_spec hPkD k hk
  have hLy := shieldLyD_mem hPkD k hk
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  obtain ⟨hrA, hrH⟩ := hbpRows k hk
  have hopA_eq : D.opA (k + 1) = rkOpen U tag Lq h64 key domain hs hL
      (rkR13 4577 ((RtRun.pf Rn).off (k + 1) + 5)) (bp k).nA
      (fun hdr' => (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb (k + 1) hdr').claims.a)
      ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oA + ((bp k).nA + 4577)) := by
    rw [hDe]; show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = _
    rw [rxPs_blk base Lb _ _ _ k hk]; simp only [rxSet, rxDblk, hrA]; rfl
  have hopH_eq : D.opH (k + 1) = rkOpen U tag Lq h64 key domain hs hL
      (rkR13 4390 ((RtRun.pf Rn).off (k + 1) + (5 + 7))) (bp k).nH
      (fun hdr' => (rxAcc (vdWin Vi) (vdWout F) Pk (RtRun.pf Rn) Lb (k + 1) hdr').claims.h
        ++ [rxLsc lscIn lscOut Pk Lb (k + 1)])
      ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH + ((bp k).nH + 4390)) := by
    rw [hDe]; show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = _
    rw [rxPs_blk base Lb _ _ _ k hk]; simp only [rxSet, rxDblk, hrH]; rfl
  refine ⟨_, _, s, rfl, fun hdr core bga rs acc T' hsa _ htr => ?_⟩
  have hs23 : s < (Pk k).geom.slots.length := by
    rw [hsl23]; exact (Exec.Block.w16r2RelKs_facts 0 (by norm_num)).2 s hs0
  obtain ⟨-, -, -, hslots_tr⟩ := blk_trace_at_slot key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) G
    (bp k).hgt (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa _ htr
  obtain ⟨⟨r, hr⟩, -, -⟩ := hslots_tr s hs23
  obtain ⟨df, hdf, -, -, hst_s, hho_s⟩ :=
    blk_unmask_at_run h64 U hU hbij tag key domain hs hL hL64 Lb preA preB start inc incG outc outcG
      Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Rn hv cx0 pin pout bp wXk gXk mXk hσ hgeo
      htB hfBM Vi F lscIn lscOut mIn kIn kOut _ _ _ _ _ _ _ _ base eL D hD hDe hPkD.toShieldRunAt
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
      rw [hsh'.1, ← hrslen]; exact (List.getElem?_eq_some_iff.mp hr').1
    obtain ⟨sp', hsp'⟩ : ∃ sp', core.slots[j]? = some sp' := ⟨_, List.getElem?_eq_getElem hjc⟩
    obtain ⟨df', hdf', -, -, -, hkind', -⟩ := hall_fns j sp' r' hsp' hr'
    exact ⟨df', hdf', hkind'⟩
  have hhosts_dXof := formAt_hostsR U hU (card_K_gt K) (shieldPbD hPkD k hk) (geoShield (shieldLyD hPkD k hk))
    (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (Pk k) (shOk_shield _ (Pk k) hP.hdr)
    (profR_shield _ (Pk k) hP.hdr hP.hsl)
    (Exec.Block.Join.R13H.Tzc.tzcCfg_shield _) (Exec.Block.Join.R13H.Dzc.dzcCfg_shield _ hLy)
    (Exec.Block.Join.R13H.Qkv.qkvCfg_shieldExport _ hLy) (Exec.Block.Join.R13H.Szc.szcCfg_shield _ hLy)
    (Exec.Block.Join.R13H.Fzc.fzcCfg_shield _ hLy)
    (shieldIoInD hPkD k hk) (shieldIoOutD hPkD k hk) _ hdef
    (blkDof tag hL20 (Pk k) hlc)
    (fun cu' rt' => dXof_base_r13 tag hL20 (Pk k) hlc 4577 4390 rE0 QE0 XE0 cu' rt')
    (by show 0 < (Pk k).logCols; rw [hlc]; norm_num)
    (by show 0 < (Pk k).logCols; rw [hlc]; norm_num)
    (precR_shield _) (shieldWindows _ hLy) hLay
    (Exec.Block.Join.R13H.Pub.pubR_of_L _ _ _ _ _ U hU)
    (perRow_shield _)
    (cuts3 (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 (rootsOf core))
    (rootsOf core) bga rs hslots_kind
  have hf_help := helperR_formAt_r13 U (card_K_gt K) (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k)
    (helpProf_shield (Pk k) hP.hdr hP.hsl) (shOk_shield _ (Pk k) hP.hdr)
    (blkAlgDt U tag hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hlc
      (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk))
    (blkDof tag hL20 (Pk k) hlc)
    (Exec.Block.Join.R13H.Pub.gateLS (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)).sh)
    (shieldPbD hPkD k hk).exp (shieldPbD hPkD k hk).act (shieldShape (shieldLyD hPkD k hk)).nG
    hU (helpCfg_shield (shieldLyD hPkD k hk) hLy) (shieldIoInD hPkD k hk) (shieldIoOutD hPkD k hk)
    (Exec.Block.Join.R13H.Pub.pubsR13L (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk))
      (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (shieldShape (shieldLyD hPkD k hk)).nG)
    (by show 0 < (Pk k).logCols; rw [hlc]; norm_num) hk3 hk19 hk20
    (hgateL_shield U (shieldPbD hPkD k hk) (shieldShape (shieldLyD hPkD k hk)).nG (shieldLyD hPkD k hk)
      (shieldLayD hPkD k hk) (shieldBD hPkD k hk))
    (hrest19L (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk))
      (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (shieldShape (shieldLyD hPkD k hk)).nG)
    (hrest20L (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk))
      (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (shieldShape (shieldLyD hPkD k hk)).nG)
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
    simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hs0; omega
  have hf_dArgs := formAt_congr_poly U (Pk k) _ _ _ bga rs s
    (polyS_congr_ah U (Pk k) hsame_k (shieldLyD hPkD k hk) hLy _ _ _ s hs21 _)
    (fun r' df' _ hdf' hk' hmem' =>
      polyS_congr_ah U (Pk k) hsame_k (shieldLyD hPkD k hk) hLy _ _ _ hk'.1
        (progR13_hosted_lt21 _ _ _ s _ _ _ df' (hdef ▸ hdf') hk' hmem') _)
    hf_help
  exact formAt_vanish U (Pk k) _ _ bga rs s r df hr hdf hst_s hho_s hf_dArgs

include hU in
theorem shield_hLU_blkD
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
    (hPkD : ShieldRunAtD tag dPos0 Pk Rp.blks Lb)
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).1.hsl (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
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
        (shieldAlkLD hL20 U tag dPos0 Lb Pk hPkD k)
        (shieldTLD tag dPos0 Lb Pk hPkD k)
        (shieldMlkLD hL20 U tag dPos0 Lb Pk hPkD k)
        G (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx := by
  intro k hk sx hsx
  have hlu_eq : D.lu (k + 1) = (base (k + 1)).lu := by rw [hDe]; exact rxPs_lu_blk base Lb _ _ _ hk
  rw [hlu_eq, (hbBlk k hk).hlu] at hsx
  simp only [blkLU, List.mem_singleton] at hsx
  have hAlk_eq : shieldAlkLD hL20 U tag dPos0 Lb Pk hPkD k
      = AlkR13B U (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k)
          (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) (geoShield (shieldLyD hPkD k hk))
          (dofARB tag hL20 (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1 16 256 24448 4577 4390 rE0 QE0 XE0) := by
    funext cr; exact dite_eq_left hk
  have hT_eq : shieldTLD (K := K) tag dPos0 Lb Pk hPkD k
      = TR13 (K := K) (shieldPbD hPkD k hk).exp (shieldPbD hPkD k hk).act (shieldShape (shieldLyD hPkD k hk)).nG :=
    dite_eq_left hk
  have hMlk_eq : shieldMlkLD hL20 U tag dPos0 Lb Pk hPkD k
      = mlkR13B U (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k)
          (dofARB tag hL20 (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1 16 256 24448 4577 4390 rE0 QE0 XE0) := by
    funext cr; exact dite_eq_left hk
  rw [hAlk_eq, hT_eq, hMlk_eq]
  refine ⟨hsx, fun hdr core bga rs acc T' hsa _ htr => ?_⟩
  set τ := rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)
  set lg := (A.runLog G).2
  set absOf := Exec.Block.absOfC (chainEncB key domain hs Lq hL)
  set hdrLen := (RtRun.pf Rn).off (k + 1) + 5
  obtain ⟨hP, hdef, hlc, -, -, -, -, -, -, hls, -, -⟩ := shieldBlkAtD_spec hPkD k hk
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hLb26 : Lb ≤ 26 := hPkD.toShieldRunAt.lb_le
  have hk26 : k < 26 := by omega
  have hparts : (RtRun.pf Rn).parts.length = Lb + 2 := RtRun.parts_length Rn
  have hi1 : k + 1 < (RtRun.pf Rn).parts.length := by omega
  obtain ⟨_, hrH⟩ := hbpRows k hk
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
  have hgdH : SchedGd (w16r2DH (Pk k) (spHR U (card_K_gt K)
      (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k) (helpProf_shield (Pk k) hP.hdr hP.hsl)
      (algShapeR (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k) (shOk_shield _ (Pk k) hP.hdr))
      (blkAlgDt U tag hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hlc
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk))
      (blkDof tag hL20 (Pk k) hlc)
      (Exec.Block.Join.R13H.Pub.gateLS (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)).sh)
      (shieldPbD hPkD k hk).exp (shieldPbD hPkD k hk).act (shieldShape (shieldLyD hPkD k hk)).nG) 0)
      (cuts3 absOf lg (rootsOf core)) (rootsOf core) bga rs := by
    intro s0 hs0
    have hs0_23 : s0 < (Pk k).geom.slots.length := by
      rw [hsl23]; exact (Exec.Block.w16r2RelKs_facts 0 (by norm_num)).2 s0 hs0
    have hmemH1 : blkHelpSq U tag hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hP.hsl hlc
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        hdrLen absOf s0 ∈ D.h1 (k + 1) := by
      have hh1_eq : D.h1 (k + 1) = (base (k + 1)).h1 := by rw [hDe]; exact rxPs_h1_blk base Lb _ _ _ hk
      rw [hh1_eq, (hbBlk k hk).hh1]; exact List.mem_map_of_mem hs0
    have hvan := blk_defSqB_ent key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij 80 (80 * 451) D.h1 hD.h1
      (Rp.blks.length + 2) (k + 1) (by omega) hi1 lg τ hH1 (Pk k) hdrLen G (bp k).hgt
      (fun i hi => ((bp k).hgeomL i hi).1) hdr core bga rs acc T' hsa htr _ _ s0 hs0_23 hmemH1
    exact (spHR U (card_K_gt K) _ (Pk k) _ _ _ _ _ _ _ _ _ _ s0 _).hΦ hvan
  have hG := hgdR_of_r13 U (card_K_gt K) (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) (Pk k)
    (helpProf_shield (Pk k) hP.hdr hP.hsl) (shOk_shield _ (Pk k) hP.hdr)
    (blkAlgDt U tag hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hlc
      (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk))
    (blkDof tag hL20 (Pk k) hlc)
    (Exec.Block.Join.R13H.Pub.gateLS (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)).sh)
    (shieldPbD hPkD k hk).exp (shieldPbD hPkD k hk).act (shieldShape (shieldLyD hPkD k hk)).nG
    (cuts3 absOf lg (rootsOf core)) (rootsOf core) bga rs hgdH
  obtain ⟨hHost, ⟨hLz, -⟩, ⟨hTab, -⟩, hzs⟩ := hG
  have hr_cfg := relCfg_shield (shieldLyD hPkD k hk)
  have hx : ∀ kh, kh ∈ algHosts → ∀ κ (hκ : κ < Exec.Slot.W16R2.segLn
      (Exec.Slot.R13.draws (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)).sh kh) .mu
      - Exec.Slot.W16R2.segLn (Exec.Slot.R13.draws (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)).sh kh) .zeta),
      Exec.Block.r13Count kh ≤ κ →
      ∀ b : Fin (Exec.Block.Join.R13H.tauLen (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)) kh) → Bool,
      xcR U (geoShield (shieldLyD hPkD k hk)) (Pk k) (blkDof tag hL20 (Pk k) hlc)
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) kh
        (cuts3 absOf lg (rootsOf core)) (rootsOf core) bga κ b = 0 := by
    intro kh hkh κ hκ hrk b
    have e := (hHost kh hkh).1 ⟨κ, hκ⟩ b
    have e2 : (blkAlgDt U tag hL20 (shieldLyD hPkD k hk) (Pk k) hP.hdr hlc
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)).cl kh
        (cuts3 absOf lg (rootsOf core)) (rootsOf core) bga ⟨κ, hκ⟩ b
        = xcR U (geoShield (shieldLyD hPkD k hk)) (Pk k) (blkDof tag hL20 (Pk k) hlc)
            (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk) kh
            (cuts3 absOf lg (rootsOf core)) (rootsOf core) bga κ b := by
      show (if κ < Exec.Block.r13Count kh then _ else _) = _
      rw [ite_eq_right (by omega)]
    rwa [e2] at e
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
    rw [hDe]; show rkOpen U tag Lq h64 key domain hs hL _ _ _ _ = _
    rw [rxPs_blk base Lb _ _ _ k hk]
    simp only [rxSet, rxDblk, rxAcc_blk _ _ _ _ _ k hk, rxLsc_blk _ _ _ _ k hk, hpart]; rfl
  rw [hopH_eq] at hndH
  have hlen_oH : (RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH ≤ τ.length := by
    have h : (τ.take ((RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH)).length = _ := oH.hpl
    rw [List.length_take] at h; omega
  have sH := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL
    (rkR13 (bp k).pH.rows ((RtRun.pf Rn).off (k + 1) + (5 + 7))) (bp k).nH _ _ (rtW (RtRun.pf Rn).sqs) _ lg τ
    hndH hlen_oH oH.hpre (by have h := oH.hcnt; rw [← oH.hrd] at h; exact h)
  have hcl_wr := sH ((Pk k).logupSumClaim) (List.mem_append_right _ (List.mem_singleton_self _))
  rw [hls] at hcl_wr
  have hval0 : (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk))).value.toK U = 0 :=
    Fp2.toK_zero U
  rw [hval0] at hcl_wr
  have hcl : Link.claimSem U
      ((blkDof tag hL20 (Pk k) hlc (cuts3 absOf lg (rootsOf core)) (rootsOf core)).rows .h)
      (rowLog (Pk k) .h)
      ((blkDof tag hL20 (Pk k) hlc (cuts3 absOf lg (rootsOf core)) (rootsOf core)).Q .h)
      ((blkDof tag hL20 (Pk k) hlc (cuts3 absOf lg (rootsOf core)) (rootsOf core)).X .h)
      (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk))) = 0 := by
    have hpos_lt : (RtRun.pf Rn).off (k + 1) + (5 + 7)
        < (RtRun.pf Rn).off (k + 1) + ((RtRun.pf Rn).part (k + 1)).oH := by
      have hp_pre : ((RtRun.pf Rn).part (k + 1)).pre = 15 + shapeLen (Pk k) 0 (Pk k).geom.slots := by
        rw [hpart]; rfl
      simp only [RtPart.oH, RtPart.oBA, RtPart.oA]; omega
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
  have hrels := relsR_of U hU (geoShield (shieldLyD hPkD k hk)) (lookCfg_shield (shieldLyD hPkD k hk)) hr_cfg (Pk k)
    (blkDof tag hL20 (Pk k) hlc (cuts3 absOf lg (rootsOf core)) (rootsOf core))
    (dXof_base_r13 tag hL20 (Pk k) hlc 4577 4390 rE0 QE0 XE0 (cuts3 absOf lg (rootsOf core)) (rootsOf core))
    (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
    (Exec.Block.Join.R13H.Pub.gateLS (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hk)).sh)
    (shieldPbD hPkD k hk).exp (shieldPbD hPkD k hk).act (shieldShape (shieldLyD hPkD k hk)).nG
    bga hbga_can.1 hbga_can.2 hLz
    (fun j hj b => hx 14 (by decide) (13 + j) (by have := hr_cfg.bD; omega) (by show 13 ≤ 13 + j; omega) b)
    (fun j hj b => hx 15 (by decide) (4 + j) (by have := hr_cfg.bQ; omega) (by show 4 ≤ 4 + j; omega) b)
    (fun j hj b => hx 16 (by decide) (4 + j) (by have := hr_cfg.bK; omega) (by show 4 ≤ 4 + j; omega) b)
    (fun j hj b => hx 17 (by decide) (5 + j) (by have := hr_cfg.bS; omega) (by show 5 ≤ 5 + j; omega) b)
    (fun κ h1 h2 b => hx 18 (by decide) κ (by have := hr_cfg.bF; omega) h1 b)
    hTab
  refine hhr_of_relsR U hU (geoShield (shieldLyD hPkD k hk)) (lookCfg_shield (shieldLyD hPkD k hk)) (Pk k)
    (blkDof tag hL20 (Pk k) hlc (cuts3 absOf lg (rootsOf core)) (rootsOf core))
    hlc (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
    (shieldPbD hPkD k hk).exp (shieldPbD hPkD k hk).act (shieldShape (shieldLyD hPkD k hk)).nG
    bga hrels hcl hzs _ (fun l => ?_) _ (fun _ => rfl)
  rcases l with ⟨s, b⟩ | ⟨d, j, b⟩ | ⟨d, j, b⟩ <;> rfl

theorem shield_hblkD
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
    (hPkD : ShieldRunAtD tag dPos0 Pk Rp.blks Lb)
    (hbBlk : ∀ k (hk : k < Lb), BlkLists (base (k + 1))
      (blkR0 U tag h64 hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkR1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH0 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).2.2.1 (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkH1 U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).1.hdr
        (shieldBlkAtD_spec hPkD k hk).1.hsl (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (blkLU U tag hL20 (shieldLyD hPkD k hk) (Pk k) (shieldBlkAtD_spec hPkD k hk).2.2.1
        (shieldPbD hPkD k hk) (shieldLayD hPkD k hk) (shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))))
    (hLb_eq : Lb = Rp.blks.length)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (k : ℕ) (hk : k < Rp.blks.length)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (liftH G) (A.run G).1 (A.run G).2 = .ok ())
    (Xin Xout : shieldS0.Pos → GF)
    (hio : ShieldBlkIO_D h64 U tag dPos0 Lb hPkD D (RtRun.pf Rn) k (hLb_eq.symm ▸ hk) (A.runLog G).2
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
  obtain ⟨hLyOpt, hblkOpt, hcal, hPb_heq, _⟩ := shieldRunAtD_spec hPkD k hkLb
  obtain ⟨hP, -, hlc, -, -, -, -, -, -, -, hLay, -⟩ := shieldBlkAtD_spec hPkD k hkLb
  have hsl23 : (Pk k).geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hblk_eq : Rp.blks[k] = shieldBlkD hPkD k hkLb := (List.getElem?_eq_some_iff.mp hblkOpt).2
  refine nonempty_rdBlkR13B_of_shieldBlkRunData hL20 Rp Pk U D k hk (A.runLog G).2 _ _ Xin Xout ⟨?_⟩
  refine ⟨shieldLyD hPkD k hkLb, shieldPbD hPkD k hkLb, tag, shieldRowsOfD hPkD k hkLb,
    shieldLayD hPkD k hkLb, shieldBD hPkD k hkLb, hP, hlc, (RtRun.pf Rn).off (k + 1) + 5, rE0, QE0, XE0,
    bndPl U tag Lq h64 (D.opX (k + 1)) ((RtRun.pf Rn).off k + 2)
      (nD (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hkLb))),
    bndPl U tag Lq h64 (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off (k + 1) + 2)
      (nD (Exec.Block.DefR13.cfgShieldR13 (shieldLyD hPkD k hkLb))),
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

end BlkAliveRunD

/-! ## 5. Top theorem (`sshC_productionReadyL_epP_pinsHd`) -/

namespace RunShapeP

section SshTopPinsHd

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code ZK60.RunShape
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)
open ZK60.D76 (classifyLeak LeaksAtMost productionReadyL_of_productionReady productionReadyL_of_productionReady_range)
open ZK60.ProtocolClassify (ClsHdrW clsHdrOf clsStart ShieldRunAtD shieldDfltLy shdRkBase shdRkD shdRkD_eq_ebData
  shdRkD_valid shdRkBase_gX_nX shdRkBaseX_0_gX shdRkBaseX_1_gX shdRkBaseX_blk_gX shdRkBaseX_out_gX
  shd_hb0 shd_hbL shd_hbBlk shd_hslB epxBndE epxE_epxBndE_planes shd_hblkIO
  shieldAlkLD shieldTLD shieldMlkLD shield_hoAK shield_hoHK shield_hoIK shield_hoOK
  shield_hR0_blkD shield_hR1_blkD shield_hH0_blkD shield_hH1_blkD shield_hLU_blkD shield_hblkD)
open ZK60.RunShape.Shield (shieldS0)

variable {Hdr Coins : Type}
variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (Rr dR : ℕ) {pos : shieldS0.Tok → Fin dR × Fin (2 ^ 8)} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (hplace : Function.Injective place) (tag : MTag)
  (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
local notation "CinS" =>
  epTokenCommit (St := ClsStmt Hdr) Rr dR hpos place (ZK60.ProtocolClassify.epxMsg Rr dR place pos)
    (ZK60.ProtocolClassify.epxMsg_place Rr dR place pos hplace) ZK60.ProtocolClassify.EpxSalt.pads
    ZK60.ProtocolClassify.EpxSalt.salts ZK60.ProtocolClassify.EpxSalt.paths ClsStmt.inRoot tag

private theorem sshC_productionReadyL_epP_pinsHd_aux
    (Rp : ClassifyRunPublicP shieldS0) (Lq Lb : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (Pk : ℕ → Exec.Block.BlockParams)
    (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom) (check : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit) (digest : ClsStmt Hdr → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ) (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →
      Except String Tr)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom) (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
    (h64 : 64 ≤ Lq) (hr : 8 * (CinS).R ≤ Lq) (hon : HonestIn Coins (CinS))
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid) (hw : Hdr → ClsHdrW) (hRn : ∀ s, RtRun.hdr Rn s = clsHdrOf hw s)
    {ι : Type} [Fintype ι] (site : (shieldS0.Tok → ℕ) → ι → Site (QB Lq) Coins K)
    (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 (ZK60.ProtocolClassify.EpxSalt Rr))
    {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpenP Rp Lq (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      P (CinS) h64 hr hon U site kOf δOf εzk)
    (hU : U ^ 2 = algebraMap GF K 7) (cx0 : IncCtx) (pin pout : RtPart)
    (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout) (bp : ∀ k, RtBlk Lq (Pk k))
    (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (hIA : RkPcsAt U tag ogStage Iin.pA) (hIH : RkPcsAt U tag ogStage Iin.pH)
    (hOA : RkPcsAt U tag ogStage Oout.pA) (hOH : RkPcsAt U tag ogStage Oout.pH)
    (hBA : ∀ k, RkPcsR13 U tag (bp k).pA) (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (htI : Iin.tag = tag) (htO : Oout.tag = tag) (htB : ∀ k, (bp k).tag = tag)
    (hfIA : 8 * Iin.pA.rows ≤ Lq) (hfIH : 8 * Iin.pH.rows ≤ Lq)
    (hfOA : 8 * Oout.pA.rows ≤ Lq) (hfOH : 8 * Oout.pH.rows ≤ Lq)
    (hfBA : ∀ k, 8 * (bp k).pA.rows ≤ Lq) (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (hfIM : 8 * (2 * pin.S + 4) ≤ Lq) (hfOM : 8 * (2 * pout.S + 4) ≤ Lq)
    (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (hbpRows : ∀ k, k < Lb → (bp k).pA.rows = 4577 ∧ (bp k).pH.rows = 4390)
    (Vi : IncV) (F : ℕ → OutcV) (hinc : ∀ hd, inc hd = Vi) (houtc : ∀ hd v, outc hd v = F v)
    (hchk : ∀ s : ClsStmt Hdr, check s 0 = .ok () → s.verdict ≤ 1) (hLb1 : 0 < Lb)
    (lscIn lscOut : Exec.Block.ZClaim) (mIn kIn kOut : ℕ)
    (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut)
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn) (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (hXk : ∀ k, ZK60.ProtocolClassify.RkPcsR13 U tag (pXk k))
    (hwXk : ∀ k, k + 1 < Lb → wXk (k + 1) = (bp k).nOut + (bp (k + 1)).nIn + (pXk (k + 1)).rows)
    (hmXk : ∀ k, k + 1 < Lb → mXk (k + 1) = (pXk (k + 1)).m)
    (hfitXk : ∀ k, 8 * (pXk k).rows ≤ Lq)
    (hwX0 : wXk 0 = Iin.nOut + (bp 0).nIn + (pXk 0).rows) (hmX0 : mXk 0 = (pXk 0).m)
    (hOX : ZK60.ProtocolClassify.RkPcsR13 U tag Oout.pX)
    (hwXo : ∀ k, k + 1 = Lb → pout.wX = (bp k).nOut + Oout.nIn + Oout.pX.rows)
    (hfitXo : 8 * Oout.pX.rows ≤ Lq)
    (hXep : RkPcsAt U tag ogEp Iin.pX) (hfitX : 8 * Iin.pX.rows ≤ Lq)
    (hRr : Iin.pX.rows = Rr) (hL81 : 81 ≤ Lq)
    (hPkD : ShieldRunAtD tag dPos0 Pk Rp.blks Lb)
    (P0in P0out : Exec.Block.BlockParams)
    (csIOI csIOO : ZK60.ProtocolClassify.StgVw Lq → Exec.Block.Cm → Exec.Block.ZClaim → K)
    (hIOI : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOI v cm { z with value := a } = csIOI v cm z)
    (hIOO : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOO v cm { z with value := a } = csIOO v cm z)
    (hNin : ∀ k, k < P0in.geom.slots.length → 0 < ZK60.ProtocolClassify.stgN P0in k
      ∧ ZK60.ProtocolClassify.stgN P0in k * (Exec.Block.slotShape P0in k).2.2 + 2 ≤ 512)
    (hNout : ∀ k, k < P0out.geom.slots.length → 0 < ZK60.ProtocolClassify.stgN P0out k
      ∧ ZK60.ProtocolClassify.stgN P0out k * (Exec.Block.slotShape P0out k).2.2 + 2 ≤ 512)
    (hN64I : ∀ k, k < P0in.geom.slots.length → ZK60.ProtocolClassify.stgN P0in k < 64)
    (hN64O : ∀ k, k < P0out.geom.slots.length → ZK60.ProtocolClassify.stgN P0out k < 64)
    (hIOlI : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off 0 + 5 + (7 + mIn)) csIOI)
    (hIOlO : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off (Lb + 1) + 2 + (7 + 2)) csIOO)
    (eI eO : ℕ) (ΛI ΛO : ZK60.ProtocolClassify.StgVw Lq → List (List UInt8 × K) → Prop)
    (hPin : ∀ hd cx, ZK60.ProtocolClassify.StgSame P0in ((inc hd).bp cx))
    (hPout : ∀ hd v, ZK60.ProtocolClassify.StgSame P0out (outc hd v).bp)
    (base : ℕ → RkPart K Lq) (D : RtKData K Lq)
    (hbase : base = shdRkBase U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn
      lscOut pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
      Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
      (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
      (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
      (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO)
    (hD_eq : D = shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
      Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
      (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
      (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
      (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO)
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)
      (rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)
        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA
          (bp k).nH)
        (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH))
      (rxAcc (ZK60.ProtocolClassify.vdWin Vi) (ZK60.ProtocolClassify.vdWout F) Pk (RtRun.pf Rn) Lb)
      (rxLsc lscIn lscOut Pk Lb) (2 ^ 26))
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn))
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
      ZK60.ProtocolClassify.StgLkAtV U key domain (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI G (A.runLog G).2
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
      ZK60.ProtocolClassify.StgLkAtV U key domain (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 ((RtRun.pf Rn).off (Lb + 1) + 2) OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdinS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ InOkP Rp ((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11))
          (epxBndE U tag Lq h64 key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn) D dPos0 E0))
          (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ZK60.ProtocolClassify.StgDoomAtV U key domain P0in (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) ZK60.ProtocolClassify.stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstIC U hbij tag h64 P0in (ZK60.ProtocolClassify.vdWin Vi) ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows pin.S csIOI) (ZK60.ProtocolClassify.sshΦIC U hbij tag h64 P0in Vi ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows csIOI) ZK60.ProtocolClassify.sshDgI eI ΛI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdoutS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ OutOkP Rp ((classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).ypub (A.runLog G).1.1)
        ((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11))
          (epxBndE U tag Lq h64 key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn) D dPos0 E0))
          (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
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
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget := by
  have hgX_of : ∀ i,
      (base i).gX = (ZK60.ProtocolClassify.shdRkBaseX (K := K) Lq Lb (RtRun.pf Rn)
        Iin.pX.rows Iin.nIn Iin.nOut Oout.pX.rows Oout.nIn
        (fun j => (bp j).nIn) (fun j => (bp j).nOut) (fun j => (pXk j).rows) i).gX
      ∧ (base i).nX = (ZK60.ProtocolClassify.shdRkBaseX (K := K) Lq Lb (RtRun.pf Rn)
        Iin.pX.rows Iin.nIn Iin.nOut Oout.pX.rows Oout.nIn
        (fun j => (bp j).nIn) (fun j => (bp j).nOut) (fun j => (pXk j).rows) i).nX := by
    intro i; rw [hbase]
    exact shdRkBase_gX_nX U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD
      Vi F lscIn lscOut pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
      Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
      (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
      (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
      (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO i
  have hgX0 : (base 0).gX = rkAt ogEp Iin.pX.rows 1 := (hgX_of 0).1
  have hnX0 : (base 0).nX = Iin.nIn := (hgX_of 0).2
  have hgX1 : (base 1).gX = ZK60.ProtocolClassify.rkR13 (pXk 0).rows ((RtRun.pf Rn).off 0 + 2) :=
    (hgX_of 1).1.trans (shdRkBaseX_1_gX (K := K) Lq Lb hLb1 (RtRun.pf Rn) _ _ _ _ _ _ _ _).1
  have hnX1 : (base 1).nX = Iin.nOut + (bp 0).nIn :=
    (hgX_of 1).2.trans (shdRkBaseX_1_gX (K := K) Lq Lb hLb1 (RtRun.pf Rn) _ _ _ _ _ _ _ _).2
  have hgXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).gX
      = ZK60.ProtocolClassify.rkR13 (pXk (k + 1)).rows ((RtRun.pf Rn).off (k + 1) + 2) :=
    fun k hk => (hgX_of (k + 1 + 1)).1.trans (shdRkBaseX_blk_gX (K := K) Lq Lb (RtRun.pf Rn) _ _ _ _ _ _ _ _ k hk).1
  have hnXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).nX = (bp k).nOut + (bp (k + 1)).nIn :=
    fun k hk => (hgX_of (k + 1 + 1)).2.trans (shdRkBaseX_blk_gX (K := K) Lq Lb (RtRun.pf Rn) _ _ _ _ _ _ _ _ k hk).2
  have hgXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).gX
      = ZK60.ProtocolClassify.rkR13 Oout.pX.rows ((RtRun.pf Rn).off (k + 1) + 2) :=
    fun k hk => (hgX_of (k + 1 + 1)).1.trans (shdRkBaseX_out_gX (K := K) Lq Lb (RtRun.pf Rn) _ _ _ _ _ _ _ _ k hk).1
  have hnXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).nX = (bp k).nOut + Oout.nIn :=
    fun k hk => (hgX_of (k + 1 + 1)).2.trans (shdRkBaseX_out_gX (K := K) Lq Lb (RtRun.pf Rn) _ _ _ _ _ _ _ _ k hk).2
  have hoAK := shield_hoAK hDe (fun _ _ => rfl) hPkD.toShieldRunAt
  have hoHK := shield_hoHK hDe (fun _ _ => rfl) hPkD.toShieldRunAt
  have hoIK := shield_hoIK hDe (by rw [hgX1]; rfl) (fun j hj => by rw [hgXk j hj]; rfl) hPkD.ep14
  have hoOK := shield_hoOK hDe (fun j hj => by rw [hgXk j hj]; rfl) (fun j hj => by rw [hgXo j hj]; rfl) hPkD.ep14
  have hslB : ∀ k, k < Lb → D.sls (k + 1) = Exec.Block.blockSchedXB (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (ZK60.ProtocolClassify.bwFslRun U tag Lq h64 Lb Pk (fun k => (bp k).S) D (RtRun.pf Rn) hoAK hoHK hoIK hoOK
        (ZK60.ProtocolClassify.shieldRunProg hPkD.toShieldRunAt)
        (ZK60.ProtocolClassify.shieldRunPubs hPkD.toShieldRunAt) k) := by
    subst hD_eq
    exact shd_hslB U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
      Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
      (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
      (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
      (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO hoAK hoHK hoIK hoOK
  have hbBlk : ∀ k (hk : k < Lb), ZK60.ProtocolClassify.BlkLists (base (k + 1))
      (ZK60.ProtocolClassify.blkR0 U tag h64 hL20 (ZK60.ProtocolClassify.shieldLyD hPkD k hk) (Pk k)
        (ZK60.ProtocolClassify.shieldBlkAtD_spec hPkD k hk).1.hdr
        (ZK60.ProtocolClassify.shieldBlkAtD_spec hPkD k hk).2.2.1
        (ZK60.ProtocolClassify.shieldPbD hPkD k hk) (ZK60.ProtocolClassify.shieldLayD hPkD k hk)
        (ZK60.ProtocolClassify.shieldBD hPkD k hk)
        (D.opX (k + 1)) (D.opX (k + 1 + 1)) ((RtRun.pf Rn).off k + 2) ((RtRun.pf Rn).off (k + 1) + 2)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (ZK60.ProtocolClassify.blkR1 U tag hL20 (ZK60.ProtocolClassify.shieldLyD hPkD k hk) (Pk k)
        (ZK60.ProtocolClassify.shieldBlkAtD_spec hPkD k hk).1.hdr
        (ZK60.ProtocolClassify.shieldBlkAtD_spec hPkD k hk).2.2.1
        (ZK60.ProtocolClassify.shieldPbD hPkD k hk) (ZK60.ProtocolClassify.shieldLayD hPkD k hk)
        (ZK60.ProtocolClassify.shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (ZK60.ProtocolClassify.blkH0 U tag hL20 (ZK60.ProtocolClassify.shieldLyD hPkD k hk) (Pk k)
        (ZK60.ProtocolClassify.shieldBlkAtD_spec hPkD k hk).1.hdr
        (ZK60.ProtocolClassify.shieldBlkAtD_spec hPkD k hk).2.2.1
        (ZK60.ProtocolClassify.shieldPbD hPkD k hk) (ZK60.ProtocolClassify.shieldLayD hPkD k hk)
        (ZK60.ProtocolClassify.shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (ZK60.ProtocolClassify.blkH1 U tag hL20 (ZK60.ProtocolClassify.shieldLyD hPkD k hk) (Pk k)
        (ZK60.ProtocolClassify.shieldBlkAtD_spec hPkD k hk).1.hdr
        (ZK60.ProtocolClassify.shieldBlkAtD_spec hPkD k hk).1.hsl
        (ZK60.ProtocolClassify.shieldBlkAtD_spec hPkD k hk).2.2.1
        (ZK60.ProtocolClassify.shieldPbD hPkD k hk) (ZK60.ProtocolClassify.shieldLayD hPkD k hk)
        (ZK60.ProtocolClassify.shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)))
      (ZK60.ProtocolClassify.blkLU U tag hL20 (ZK60.ProtocolClassify.shieldLyD hPkD k hk) (Pk k)
        (ZK60.ProtocolClassify.shieldBlkAtD_spec hPkD k hk).2.2.1
        (ZK60.ProtocolClassify.shieldPbD hPkD k hk) (ZK60.ProtocolClassify.shieldLayD hPkD k hk)
        (ZK60.ProtocolClassify.shieldBD hPkD k hk)
        ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))) := by
    intro k hk; rw [hbase, hD_eq]
    exact shd_hbBlk U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
      Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
      (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
      (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
      (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO k hk
  have hb0 : ZK60.ProtocolClassify.StgLists (base 0)
      (ZK60.ProtocolClassify.stgSchedV P0in mIn ((RtRun.pf Rn).off 0 + 5) ZK60.ProtocolClassify.stgHostIn
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (ZK60.ProtocolClassify.stgFstIC U hbij tag h64 P0in (ZK60.ProtocolClassify.vdWin Vi)
          ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn
          ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows pin.S csIOI))
      (ZK60.ProtocolClassify.stgDefsV P0in mIn ((RtRun.pf Rn).off 0 + 5)
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (ZK60.ProtocolClassify.sshΦIC U hbij tag h64 P0in Vi ((RtRun.pf Rn).off 0 + pin.pre)
          ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows csIOI)
        ZK60.ProtocolClassify.sshDgI)
      (ZK60.ProtocolClassify.stgLkSqV mIn ((RtRun.pf Rn).off 0 + 5) eI
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI) := by
    rw [hbase]
    exact shd_hb0 U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
      Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
      (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
      (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
      (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO
  have hbL : ZK60.ProtocolClassify.StgLists (base (Lb + 1))
      (ZK60.ProtocolClassify.stgSchedV P0out 2 ((RtRun.pf Rn).off (Lb + 1) + 2) (ZK60.ProtocolClassify.stgHostOut P0out)
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (ZK60.ProtocolClassify.stgFstO U hbij tag h64 P0out (ZK60.ProtocolClassify.vdWout F)
          ((RtRun.pf Rn).off (Lb + 1) + pout.pre) ((RtRun.pf Rn).off (Lb + 1) + 2)
          ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows pout.S csIOO))
      (ZK60.ProtocolClassify.stgDefsV P0out 2 ((RtRun.pf Rn).off (Lb + 1) + 2)
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (ZK60.ProtocolClassify.sshΦO U hbij tag h64 P0out F ((RtRun.pf Rn).off (Lb + 1) + pout.pre)
          ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows csIOO)
        ZK60.ProtocolClassify.sshDgO)
      (ZK60.ProtocolClassify.stgLkSqV 2 ((RtRun.pf Rn).off (Lb + 1) + 2) eO
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO) := by
    rw [hbase]
    exact shd_hbL U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
      Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
      (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
      (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
      (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO
  exact sshC_productionReadyL_epP_dg (Rr := Rr) (dR := dR) (hpos := hpos) (place := place) (hplace := hplace)
    (tag := tag) (Rp := Rp) (Lq := Lq) (Lb := Lb) (preA := preA) (preB := preB) (start := start)
    (inc := inc) (incG := incG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths)
    (digest := digest) (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (outc := outc)
    (outcG := outcG) (P := P) (h64 := h64) (hr := hr) (hon := hon) (U := U)
    (hbij := hbij) (key := key) (domain := domain) (hs := hs) (hL := hL) (hL64 := hL64)
    (Rn := Rn) (hv := hv) (hw := hw) (hRn := hRn) (D := D) (hD := hD)
    (ι := ι) (site := site) (kOf := kOf) (δOf := δOf)
    (E0 := epxBndE U tag Lq h64 key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn) D dPos0 E0) (εzk := εzk)
    (O := O) (hU := hU) (cx0 := cx0) (pin := pin) (pout := pout) (Iin := Iin)
    (Oout := Oout) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ)
    (hgeo := hgeo) (hIA := hIA) (hIH := hIH) (hOA := hOA) (hOH := hOH) (hBA := hBA)
    (hBH := hBH) (htI := htI) (htO := htO) (htB := htB) (hfIA := hfIA) (hfIH := hfIH)
    (hfOA := hfOA) (hfOH := hfOH) (hfBA := hfBA) (hfBH := hfBH) (hfIM := hfIM) (hfOM := hfOM)
    (hfBM := hfBM) (Vi := Vi) (F := F) (hinc := hinc) (houtc := houtc) (hchk := hchk)
    (hLb1 := hLb1) (lscIn := lscIn) (lscOut := lscOut) (mIn := mIn) (kIn := kIn) (kOut := kOut)
    (hlscIn := hlscIn) (hlscOut := hlscOut) (hmIn := hmIn) (hkIn := hkIn) (hkOut := hkOut)
    (base := base) (eL := 2 ^ 26) (hDe := hDe) (pXk := pXk) (hXk := hXk) (hwXk := hwXk) (hmXk := hmXk)
    (hfitXk := hfitXk) (hgXk := hgXk) (hnXk := hnXk) (hwX0 := hwX0) (hmX0 := hmX0) (hgX1 := hgX1)
    (hnX1 := hnX1) (hOX := hOX) (hwXo := hwXo) (hfitXo := hfitXo) (hgXo := hgXo) (hnXo := hnXo)
    (hgX0 := hgX0) (hnX0 := hnX0) (hXep := hXep) (hfitX := hfitX) (hRr := hRr) (hL81 := hL81)
    (hPk := hPkD.toShieldRunAt) (hoAK := hoAK) (hoHK := hoHK) (hoIK := hoIK) (hoOK := hoOK) (hslB := hslB)
    (ιL := fun _ => ZK60.Exec.Block.Join.R13H.Look.SgIx (Exec.Block.DefR13.cfgShieldR13 shieldDfltLy))
    (πL := fun _ => ZK60.Exec.Block.Join.R13H.Look.PrIx (Exec.Block.DefR13.cfgShieldR13 shieldDfltLy) 1)
    (κL := fun _ => ZK60.Exec.Block.Join.R13H.Look.TbIx)
    (AlkL := shieldAlkLD hL20 U tag dPos0 Lb Pk hPkD)
    (TL := shieldTLD tag dPos0 Lb Pk hPkD)
    (mlkL := shieldMlkLD hL20 U tag dPos0 Lb Pk hPkD)
    (P0in := P0in) (P0out := P0out) (csIOI := csIOI) (csIOO := csIOO) (hIOI := hIOI) (hIOO := hIOO)
    (hNin := hNin) (hNout := hNout) (hN64I := hN64I) (hN64O := hN64O) (hIOlI := hIOlI) (hIOlO := hIOlO)
    (eI := eI) (eO := eO) (ΛI := ΛI) (ΛO := ΛO)
    (hb0 := hb0) (hbL := hbL) (hPin := hPin) (hPout := hPout)
    (hTrIIO := hTrIIO) (hTrOIO := hTrOIO)
    (hR0_blk := fun A G hv' hx' _ hM _ hsl => by
      have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG
        (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768 G _ _ hv'
      rw [OC.runLog_fst] at hE0
      exact shield_hR0_blkD h64 hL20 U hU hbij tag dPos0 key domain hs hL hL64 Lb
        preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
        Rp Rn hv cx0 pin pout bp wXk gXk mXk hσ hgeo htB hfBM hbpRows Vi F lscIn lscOut mIn kIn kOut
        _ _ _ _ _ _ _ _ base (2 ^ 26) D hD hDe hPkD hoAK hoHK hoIK hoOK hslB hbBlk
        (O.blocks.2 : Lb = Rp.blks.length) A G hE0 (fun h => hx' (Or.inl h)) hM hsl)
    (hR1_blk := fun A G _ _ _ _ _ _ hR0 =>
      shield_hR1_blkD h64 hL20 U hbij tag dPos0 key domain hs hL hL64 Lb
        preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
        Rp Rn hv bp Vi F lscIn lscOut mIn kIn kOut _ _ _ _ _ _ _ _ pin pout base (2 ^ 26) D hD hDe hPkD hbBlk
        (O.blocks.2 : Lb = Rp.blks.length) A G hR0)
    (hH0_blk := fun A G _ _ _ _ _ _ _ hR1 =>
      shield_hH0_blkD h64 hL20 U hbij tag dPos0 key domain hs hL hL64 Lb
        preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
        Rp Rn hv bp Vi F lscIn lscOut mIn kIn kOut _ _ _ _ _ _ _ _ pin pout base (2 ^ 26) D hD hDe hPkD hbBlk
        (O.blocks.2 : Lb = Rp.blks.length) A G hR1)
    (hH1_blk := fun A G hv' hx' _ hM _ hsl _ _ _ => by
      have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG
        (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768 G _ _ hv'
      rw [OC.runLog_fst] at hE0
      exact shield_hH1_blkD h64 hL20 U hU hbij tag dPos0 key domain hs hL hL64 Lb
        preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
        Rp Rn hv cx0 pin pout bp wXk gXk mXk hσ hgeo htB hfBM hbpRows Vi F lscIn lscOut mIn kIn kOut
        _ _ _ _ _ _ _ _ base (2 ^ 26) D hD hDe hPkD hoAK hoHK hoIK hoOK hslB hbBlk
        (O.blocks.2 : Lb = Rp.blks.length) A G hE0 (fun h => hx' (Or.inl h)) hM hsl)
    (hLU_blk := fun A G hv' hx' _ _ hA _ _ _ _ hH1 => by
      have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG
        (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768 G _ _ hv'
      rw [OC.runLog_fst] at hE0
      exact shield_hLU_blkD h64 hL20 U hU hbij tag dPos0 key domain hs hL hL64 Lb
        preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
        Rp Rn hv cx0 pin pout bp wXk gXk mXk hσ hgeo hBH hfBH hbpRows Vi F lscIn lscOut mIn kIn kOut
        _ _ _ _ _ _ _ _ base (2 ^ 26) D hD hDe hPkD hbBlk
        (O.blocks.2 : Lb = Rp.blks.length) A G hE0 (fun h => hx' (Or.inl h)) hA hH1)
    (hLI_stg := hLI_stg) (hLO_stg := hLO_stg) (hdinS := hdinS)
    (hblk := fun A G k hk hv' _ => by
      have hE0 := rc_uexecP_E Rp Lb preA preB start inc incG
        (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768 G _ _ hv'
      rw [OC.runLog_fst] at hE0
      have hkLb : k < Lb := Nat.lt_of_lt_of_eq hk (O.blocks.2.symm : Rp.blks.length = Lb)
      have hio0 := shd_hblkIO h64 U tag dPos0 Lb key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn)
        hPkD D k hkLb G (A.runLog G).2 (A.run G)
      have heq_run : ((A.runLog G).1.1, (A.runLog G).1.2) = A.run G := by
        rw [OC.runLog_fst]
      refine shield_hblkD h64 hL20 U tag dPos0 key domain hs hL Lb
        preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
        Rp Rn hv cx0 pin pout bp wXk gXk mXk hσ hgeo Vi F lscIn lscOut mIn kIn kOut
        _ _ _ _ _ _ _ _ base (2 ^ 26) D hDe hPkD hbBlk
        (O.blocks.2 : Lb = Rp.blks.length) A G k hk hE0 _ _ ?_
      change ZK60.ProtocolClassify.ShieldBlkIO_D h64 U tag dPos0 Lb hPkD D (RtRun.pf Rn) k hkLb (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (ZK60.ProtocolClassify.bndPlanes U tag Lq h64 key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn) D dPos0
          (A.runLog G).2 ((A.runLog G).1.1, (A.runLog G).1.2) k)
        (ZK60.ProtocolClassify.bndPlanes U tag Lq h64 key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn) D dPos0
          (A.runLog G).2 ((A.runLog G).1.1, (A.runLog G).1.2) (k + 1))
      rw [heq_run]
      exact hio0)
    (hdoutS := hdoutS) (hLay := hLay) (hdzW := hdzW) (hzk := hzk)

/-- **THE SHIELDSTRAL T128 R13 CLASSIFIER TOP THEOREM WITH CONCRETE `base`/`D`, BLOCK `hD` PROVED, STAGE `hD` WIRED
THROUGH `stgDefsV_valid_inC`/`out`, AND `hblkIO` PROVED (`epxBndE`)** (D63 lane L66):
* constructs `base := shdRkBase ...` and `D := shdRkD ...` at `eL := 2^26`, eliminating `base`, `D`, `eL`, `hDe`,
  `hb0`, `hbBlk`, `hbL`, `hslB`, `hgX0`, `hnX0`, `hgX1`, `hnX1`, `hgXk`, `hnXk`, `hgXo`, `hnXo` (closing `L64_REVIEW.md`
  `M1` and `N9` by construction);
* proves all 16 `RkPart.Ok` conjuncts for every block `k < Lb` with zero new block premises (`shd_blk_rkPartOk`,
  `blk_hhi_of_rtRun`, `maskField_inj_S`; closing `M2`), and replaces the monolithic `hD` by the four stage premises
  `hSm`, `hlcStg`, `hCsIO` (`StgCsIODeg` for `L65b`), and `hLuStg`;
* proves `hblkIO` outright (`shd_hblkIO`; closing `M3`) by wrapping `E0`'s `.planes` via `epxBndE` under cross-block
  carrier layout coherence `hPkD : ShieldRunAtD tag dPos0 Pk Rp.blks Lb`. -/
theorem sshC_productionReadyL_epP_pinsHd
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
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (hXk : ∀ k, ZK60.ProtocolClassify.RkPcsR13 U tag (pXk k))
    (hwXk : ∀ k, k + 1 < Lb → wXk (k + 1) = (bp k).nOut + (bp (k + 1)).nIn + (pXk (k + 1)).rows)
    (hmXk : ∀ k, k + 1 < Lb → mXk (k + 1) = (pXk (k + 1)).m)
    (hfitXk : ∀ k, 8 * (pXk k).rows ≤ Lq)
    (hwX0 : wXk 0 = Iin.nOut + (bp 0).nIn + (pXk 0).rows)
    (hmX0 : mXk 0 = (pXk 0).m)
    (hOX : ZK60.ProtocolClassify.RkPcsR13 U tag Oout.pX)
    (hwXo : ∀ k, k + 1 = Lb → pout.wX = (bp k).nOut + Oout.nIn + Oout.pX.rows)
    (hfitXo : 8 * Oout.pX.rows ≤ Lq)
    (hXep : RkPcsAt U tag ogEp Iin.pX)
    (hfitX : 8 * Iin.pX.rows ≤ Lq)
    (hRr : Iin.pX.rows = Rr)
    (hL81 : 81 ≤ Lq)
    (hPkD : ShieldRunAtD tag dPos0 Pk Rp.blks Lb)
    (P0in P0out : Exec.Block.BlockParams)
    (csIOI csIOO : ZK60.ProtocolClassify.StgVw Lq → Exec.Block.Cm → Exec.Block.ZClaim → K)
    (hIOI : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOI v cm { z with value := a } = csIOI v cm z)
    (hIOO : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOO v cm { z with value := a } = csIOO v cm z)
    (hNin : ∀ k, k < P0in.geom.slots.length → 0 < ZK60.ProtocolClassify.stgN P0in k
      ∧ ZK60.ProtocolClassify.stgN P0in k * (Exec.Block.slotShape P0in k).2.2 + 2 ≤ 512)
    (hNout : ∀ k, k < P0out.geom.slots.length → 0 < ZK60.ProtocolClassify.stgN P0out k
      ∧ ZK60.ProtocolClassify.stgN P0out k * (Exec.Block.slotShape P0out k).2.2 + 2 ≤ 512)
    (hN64I : ∀ k, k < P0in.geom.slots.length → ZK60.ProtocolClassify.stgN P0in k < 64)
    (hN64O : ∀ k, k < P0out.geom.slots.length → ZK60.ProtocolClassify.stgN P0out k < 64)
    (hIOlI : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off 0 + 5 + (7 + mIn)) csIOI)
    (hIOlO : ZK60.ProtocolClassify.VwLoc ((RtRun.pf Rn).off (Lb + 1) + 2 + (7 + 2)) csIOO)
    (eI eO : ℕ)
    (ΛI ΛO : ZK60.ProtocolClassify.StgVw Lq → List (List UInt8 × K) → Prop)
    (hPin : ∀ hd cx, ZK60.ProtocolClassify.StgSame P0in ((inc hd).bp cx))
    (hPout : ∀ hd v, ZK60.ProtocolClassify.StgSame P0out (outc hd v).bp)
    (hSm : 2 * pin.S + 2 ≤ 2 ^ 20 ∧ 2 * pout.S + 2 ≤ 2 ^ 20)
    (hlcStg : Vi.pub.lt ≤ ogStage.lc ∧ ∀ b, (F b).pub.lt ≤ ogStage.lc)
    (hCsIO : ZK60.ProtocolClassify.StgCsIODeg U hbij Vi.pub.epLogN (ZK60.ProtocolClassify.IncPrivIO0 Vi.pub) csIOI
      ∧ ZK60.ProtocolClassify.StgCsIODeg U hbij Vi.geo.bLogN (ZK60.ProtocolClassify.IncPrivIO1 Vi.pub) csIOI
      ∧ ∀ b, ZK60.ProtocolClassify.StgCsIODeg U hbij (F b).geo.bLogN (ZK60.ProtocolClassify.OutcPrivIO (F b).pub) csIOO)
    (hLuStg : (ZK60.ProtocolClassify.stgLkSqV mIn ((RtRun.pf Rn).off 0 + 5) eI
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI).Rbr
      ∧ eI ≤ 2 ^ 26 ∧ mIn * eI ≤ 3 * 2 ^ 26
      ∧ (ZK60.ProtocolClassify.stgLkSqV 2 ((RtRun.pf Rn).off (Lb + 1) + 2) eO
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO).Rbr
      ∧ eO ≤ 2 ^ 26)
    (hTrIIO : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
      (hDV : (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
        Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
        (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
        (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
        (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO).Valid
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn)),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ZK60.ProtocolClassify.StgClaimsIOC U key domain (inc (A.run G).1.hdr) mIn ((RtRun.pf Rn).off 0 + 5) ((RtRun.pf Rn).off 0 + pin.pre) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows ((RtRun.pf Rn).off 0 + 5) ((RtRun.pf Rn).off 0 + 5 + 4 + mIn) csIOI) G (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hTrOIO : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
      (hDV : (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
        Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
        (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
        (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
        (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO).Valid
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn)),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ZK60.ProtocolClassify.StgClaimsIOCO U key domain (outc (A.run G).1.hdr (A.run G).1.verdict).bp ((RtRun.pf Rn).off (Lb + 1) + 2) ((RtRun.pf Rn).off (Lb + 1) + pout.pre) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows ((RtRun.pf Rn).off (Lb + 1) + 2) ((RtRun.pf Rn).off (Lb + 1) + 2 + 4 + 2) csIOO) G (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hLI_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
      (hDV : (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
        Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
        (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
        (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
        (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO).Valid
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn)),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ZK60.ProtocolClassify.StgLkAtV U key domain (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hLO_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
      (hDV : (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
        pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
        Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
        (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
        (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
        (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO).Valid
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn)),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij _ hDV).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ZK60.ProtocolClassify.StgLkAtV U key domain (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 ((RtRun.pf Rn).off (Lb + 1) + 2) OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdinS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ InOkP Rp ((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11))
          (epxBndE U tag Lq h64 key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn)
            (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
              pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
              Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
              (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
              (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
              (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO) dPos0 E0))
          (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ZK60.ProtocolClassify.StgDoomAtV U key domain P0in (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) ZK60.ProtocolClassify.stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstIC U hbij tag h64 P0in (ZK60.ProtocolClassify.vdWin Vi) ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows pin.S csIOI) (ZK60.ProtocolClassify.sshΦIC U hbij tag h64 P0in Vi ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows csIOI) ZK60.ProtocolClassify.sshDgI eI ΛI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdoutS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ OutOkP Rp ((classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).ypub (A.runLog G).1.1)
        ((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11))
          (epxBndE U tag Lq h64 key domain hs hL (RtRun.pf Rn) (RtRun.rd Rn)
            (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
              pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
              Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
              (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
              (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
              (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO) dPos0 E0))
          (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
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
  sshC_productionReadyL_epP_pinsHd_aux Rr dR hpos place hplace tag dPos0 Rp Lq Lb hL20
    preA preB start inc incG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen outc outcG P h64 hr hon U hbij
    key domain hs hL hL64 Rn hv hw hRn site kOf δOf E0 O hU cx0 pin pout Iin Oout bp wXk gXk mXk hσ hgeo
    hIA hIH hOA hOH hBA hBH htI htO htB hfIA hfIH hfOA hfOH hfBA hfBH hfIM hfOM hfBM hbpRows
    Vi F hinc houtc hchk hLb1 lscIn lscOut mIn kIn kOut hlscIn hlscOut hmIn hkIn hkOut
    pXk hXk hwXk hmXk hfitXk hwX0 hmX0 hOX hwXo hfitXo hXep hfitX hRr hL81 hPkD
    P0in P0out csIOI csIOO hIOI hIOO hNin hNout hN64I hN64O hIOlI hIOlO eI eO ΛI ΛO hPin hPout
    _ _ rfl rfl
    (shdRkD_eq_ebData U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 (RtRun.pf Rn) Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin.pA.rows Iin.pH.rows Iin.pX.rows Iin.nA Iin.nH Iin.nIn Iin.nOut
      Oout.pA.rows Oout.pH.rows Oout.pX.rows Oout.nA Oout.nH Oout.nIn
      (fun j => (bp j).S) (fun j => (bp j).pA.rows) (fun j => (bp j).pH.rows)
      (fun j => (bp j).nA) (fun j => (bp j).nH) (fun j => (bp j).nIn) (fun j => (bp j).nOut)
      (fun j => (pXk j).rows) P0in P0out csIOI csIOO eI eO ΛI ΛO)
    (shdRkD_valid P.refused.hdr U hU hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1
      preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen hPkD Rn hv
      cx0 pin pout Iin Oout bp wXk gXk mXk hσ hIA hIH hOA hOH hBA hBH pXk hXk hwXk hmXk hwX0 hmX0
      hOX hwXo hXep Vi F hinc houtc lscIn lscOut mIn kIn kOut hmIn hkIn hkOut P0in P0out csIOI csIOO
      hNin hNout hN64I hN64O hPin hPout eI eO ΛI ΛO hSm hlcStg hCsIO hLuStg)
    (fun A G => hTrIIO A G _)
    (fun A G => hTrOIO A G _)
    (fun A G => hLI_stg A G _)
    (fun A G => hLO_stg A G _)
    hdinS hdoutS hLay hdzW hzk

end SshTopPinsHd

end RunShapeP


-- REVIEW APPENDIX (reviewer-generated; not in the original file): binder dump and use analysis
section ReviewMeta
open Lean Meta Elab Command

def dumpSig (n : Name) (file : String) : MetaM Unit := do
  let ci ← getConstInfo n
  forallTelescope ci.type fun xs concl => do
    let mut s := s!"THEOREM {n} binders={xs.size}\n"
    for x in xs do
      let d ← x.fvarId!.getDecl
      let t ← ppExpr d.type
      s := s ++ s!"BINDER {d.userName} [{repr d.binderInfo}] :: {(toString t).replace "\n" " "}\n"
    let c ← ppExpr concl
    s := s ++ s!"CONCLUSION :: {(toString c).replace "\n" " "}\n"
    IO.FS.writeFile file s

def useAnalysis (n : Name) (file : String) : MetaM Unit := do
  let ci ← getConstInfo n
  let v := ci.value!
  lambdaTelescope v fun xs b => do
    let mut s := s!"USES {n} binders={xs.size}\n"
    for x in xs do
      let d ← x.fvarId!.getDecl
      let inBody := b.containsFVar x.fvarId!
      let mut inTypes := false
      for y in xs do
        if y != x then
          let dy ← y.fvarId!.getDecl
          if dy.type.containsFVar x.fvarId! then inTypes := true
      let isP ← isProp d.type
      s := s ++ s!"USE {d.userName} prop={isP} inBody={inBody} inOtherBinderTypes={inTypes}\n"
    IO.FS.writeFile file s

run_cmd liftTermElabM do
  let D := "/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l66_review/"
  dumpSig `ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_blkAlive (D ++ "sig_blkAlive.txt")
  dumpSig `ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_pinsHd (D ++ "sig_pinsHd.txt")
  useAnalysis `ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_pinsHd (D ++ "use_top.txt")
  let env ← getEnv
  let mut auxN : Option Name := none
  for (n, _) in env.constants.map₂.toList do
    if (toString n).endsWith "sshC_productionReadyL_epP_pinsHd_aux" then auxN := some n
  match auxN with
  | some n => useAnalysis n (D ++ "use_aux.txt")
  | none => IO.FS.writeFile (D ++ "use_aux.txt") "aux not found\n"

end ReviewMeta

end ZK60.ProtocolClassify
