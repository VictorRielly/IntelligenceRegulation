/-
D63 lane L68c, part 2b-iii (`HonestShieldBlockArith.lean`):
Part 3 of the 3-file Shieldstral T128 R13 block completeness lane
(`HonestShieldBlockWitness.lean` → `HonestShieldBlockTables.lean` → `HonestShieldBlockArith.lean`).

Proves complete Shieldstral T128 R13 per-block arithmetic and `SegComplete` for all 26 blocks `k < 26`,
discharging `hsegBlk k` of `RunShieldOpenShell.sshC_productionReadyL_epP_openShell`:
1. **Generic R13 block slot helpers (`Section 1`):**
   - `shdP_blk_slot_bounds`: uniform round/degree/mask-width bounds for all 23 slots (`s < 23`).
   - `shdP_blk_tabsLenOk`: `TabsLenOk (slotShape P s).1 df.tabs` for all 23 slots (`s < 23`).
   - `shdP_blk_hosted_spec`: exact hosted-slot lists, `P.kind s = .host ↔ df.hosted ≠ []`,
     and `∀ hk ∈ df.hosted, hk.1 < s ∧ hk.1 < 23 ∧ P.kind hk.1 = .priv ∧ hk.2.Canon`.
   - `hostedSum_ok_val`: general canonicity and field-value identity for `Exec.Block.hostedSum`.
   - `hostPhi_eq_zero`, `r13Cl_eq_zero_of_rels`, `r13Gh_eq_r13Mm_of_rels`, `blk_dtR_good`:
     all 6 R13 host identities vanish identically on `blkCmData` under `w.hRels` and `blkAlphaBad = false`.
2. **Per-slot arithmetic for ALL 23 slots `0..22` (`Section 2`):**
   - Uniform `IndDegLE (slotD P s) (blkSlotPolyK ...)` and `(df.poly vals).Canon` via `blkSlotPolyK_indDeg`
     and `defineS_polyC`.
   - 12 `.priv` slots (`0, 1, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13`): `df.hosted = []`, `claimed = scalar`.
   - 6 `.host` slots (`2, 14, 15, 16, 17, 18`): `blk_host_cubeSum_eq_hosted` via
     `BlockR13StmtHosts.formAt_hostsR` + `hostSp_Φ` + `hostPhi_eq_zero`.
   - 5 `.standalone` slots (`3` LZC, `19` TAB, `20` ZS, `21` IOIN, `22` IOOUT):
     `blk_standalone_cubeSum_eq_zero` via `lzcR_cube`, `tabR_cube`, `zsR_cube`, `ioR_cube`.
3. **Accumulator invariant and abstract-`m` slot-loop induction (`Section 3`):**
   - `BlkAccInv`: tracks `recs.length = s`, `recs_def`, `acc.cs`/`acc.scalars` lengths & canonicity,
     prior `.priv` slot scalar identities, `ClaimTrue` on all 4 tables (`TA`, `TH`, `TB_prev`, `TB_next`),
     and `mTrue` across `acc.fs ++ acc.hostFs` (`S = 23`, `mRows = 50`).
   - `blk_slot_step` and `shdP_blk_slots_ok` (induction over abstract `m` with `s + m ≤ 23`).
4. **Main block arithmetic theorem (`Section 4`):**
   - `shdP_blk_arith`: discharges all 23 conjuncts of `hArith` AND proves `ClaimTrue` on `R.acc.claims.out`
     against `TB_next` (carrying boundary continuity to block `k + 1` / Stage OUT-C).
5. **Guarded block `SegComplete` bridge & top-level discharge (`Section 5`):**
   - `shdP_blk_segComplete_guarded`: `blkAlphaBad`-guarded completeness bridge for `shdP_blkSegP_guarded`.
   - `shdP_bndTableAt`, `shdP_blkPub_act0`, `shdP_blkTables_total`, `shdP_blkSegP_run`,
     `shdP_blkSegP_run_outClaims_true`, **`shdP_blk_segComplete_of_adm`**, and
     **`shdP_blk_segComplete_runV`** matching `RunShieldOpenShell.sshC_productionReadyL_epP_openShell`'s
     `hsegBlk k` signature for every `k < 26` with explicit `hAct0 : ∀ b ∈ Rp.blks, b.pub.act 0 2048 = 0`.
-/
import ZK60Formal.HonestShieldBlockTables

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound ZK60.TokenRun ZK60.StageX
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldS0 shieldShape ShieldRun)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic blockSpec i16)
open ZK60.Layout (W16Layout W16Pub)
open ZK60.Layout.R13 (R13Data R13Rels)
open ZK60.Exec.Block (BlockParams Hist SlotDef Acc Claims4 Cm CmData Tab TabS SlotS SlotRec Seen
  Segment SegGeom SlotKind SlotProof Core CoreCanon CoreShape HidingCanon HidingShape
  SlotCanon encSeg decodeSegment pathsDepth slotShape slotTerms posTag polyS histSeen drSeen
  defineS defineS_ok defineS_polyC)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Block.Join (castB planeZ baseR)
open ZK60.Exec.Block.Join.W16 (aPl hPl cubeTab foldTab)
open ZK60.Exec.Block.Join.R13H (CtR CwR CgR CjR CdR CfR nD nH nQ nK nS nHt nF
  geoShield offR xtR tauLen mpadR xcR pwcR encR encHtR clIx dtR algShapeR
  shOk_shield profR_shield precR_shield shieldWindows perRow_shield progR13_shield_okP
  progR13_slot numSlot_fields formAt_hostsR)
open ZK60.Exec.Block.Join.R13H.Look (logupSumR13)
open ZK60.Exec.Block.Join.R13H.Pub (pubsR13L pubsR13 pubR_of_L pubsR13L_three_getD pubsR13L_tab gateLS)
open ZK60.Exec.Block.Join.R13H.Help (helpCfg_shield lzcR_cube zsR_cube numTabs3 numTabs20 drH rawSlot3R rawSlot20R)
open ZK60.Exec.Block.Join.R13T (restR13 rest20R13_getD tabR_cube rawSlotR)

/-! ## 1. Generic R13 Block Slot Helpers & Vanishing of `hostPhi` on `blkCmData` -/

section BlkSlotHelpers

private theorem shieldSlots_bounds : ∀ s : Fin 23,
    let sh := Exec.Block.R13.shieldSlots.getD s.val (0, 0, 0)
    0 < sh.1 + sh.2.1 ∧ sh.1 + sh.2.1 < 64 ∧ 1 ≤ sh.2.2 ∧ sh.2.2 ≤ 5
      ∧ (sh.1 + sh.2.1) * sh.2.2 + 2 ≤ 512 := by
  decide

/-- Uniform round, degree, and mask-polynomial width bounds across all 23 Shieldstral R13 block slots. -/
theorem shdP_blk_slot_bounds (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) (s : ℕ) (hs : s < 23) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    0 < slotN P s ∧ slotN P s < 64 ∧ 1 ≤ slotD P s ∧ slotD P s ≤ 5
      ∧ slotN P s * slotD P s + 2 ≤ 512 :=
  shieldSlots_bounds ⟨s, hs⟩

/-! ### 1a. `TabsLenOk` for all 23 Shieldstral R13 block slots -/

private def blkMaxPub : ℕ → ℕ
  | 0 | 1 | 3 | 4 | 5 | 6 | 7 | 10 | 11 | 12 | 13 | 17 | 20 => 1
  | 14 => 3
  | 15 | 16 | 18 => 2
  | 19 => 5
  | _ => 0

private def shdLy0 : ShieldLayer := ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩

private def pubCountS : List TabS → ℕ
  | [] => 0
  | .pub _ :: ts => 1 + pubCountS ts
  | _ :: ts => pubCountS ts

private def tabLenOKb (main : ℕ) : TabS → Bool
  | .eq pt st => decide (st + pt.length ≤ main)
  | _ => true

private def tabsLenOKb (main maxPub : ℕ) (ts : List TabS) : Bool :=
  decide (pubCountS ts ≤ maxPub) && ts.all (tabLenOKb main)

private theorem bytes_length (g : List ℕ) (b : Option ℕ) :
    (Exec.Block.DefR13.bytes g b).length = g.length + (if b.isSome then 1 else 0) := by
  cases b <;> simp [Exec.Block.DefR13.bytes]

private theorem nHelp_cfgShieldR13 (Ly : ShieldLayer) (d : Exec.Slot.W16R2.Dom) :
    Exec.Block.DefR13.nHelp (Exec.Block.DefR13.cfgShieldR13 Ly) d
      = Exec.Block.DefR13.nHelp (Exec.Block.DefR13.cfgShieldR13 shdLy0) d := by
  cases d <;> simp [Exec.Block.DefR13.nHelp, Exec.Block.DefR13.lookups, Exec.Block.DefR13.ids,
    Exec.Block.DefR13.lsOf, Exec.Block.DefR13.cfgShieldR13, Exec.Block.DefR13.precShieldR13, shdLy0, bytes_length]

private theorem rawSlot_tabs_congr (c₁ c₂ : W16Cfg)
    (hsh : c₁.sh = c₂.sh) (hlc : c₁.logCols = c₂.logCols)
    (hh24 : c₁.p.h24 = c₂.p.h24) (hwrho : c₁.p.wrho = c₂.p.wrho)
    (hnh : ∀ d, Exec.Block.DefR13.nHelp c₁ d = Exec.Block.DefR13.nHelp c₂ d) (s : ℕ) :
    (Exec.Block.DefR13.rawSlot c₁ s).tabs = (Exec.Block.DefR13.rawSlot c₂ s).tabs := by
  have hids : Exec.Block.DefR13.ids c₁ = Exec.Block.DefR13.ids c₂ := by
    unfold Exec.Block.DefR13.ids Exec.Block.DefR13.lsOf; rw [hh24, hwrho]
  have hdomS : ∀ d, Exec.Block.DefR13.domStart c₁ d = Exec.Block.DefR13.domStart c₂ d := fun d => by
    unfold Exec.Block.DefR13.domStart; simp only [hids]
  have hdomE : ∀ d, Exec.Block.DefR13.domEnd c₁ d = Exec.Block.DefR13.domEnd c₂ d := fun d => by
    unfold Exec.Block.DefR13.domEnd; simp only [hids]
  have hdomPl : ∀ d, Exec.Block.DefR13.domPl c₁ d = Exec.Block.DefR13.domPl c₂ d := fun d => by
    unfold Exec.Block.DefR13.domPl; rw [hdomS, hdomE]
  have hplaneDom : ∀ q, Exec.Block.DefR13.planeDom c₁ q = Exec.Block.DefR13.planeDom c₂ q := fun q => by
    unfold Exec.Block.DefR13.planeDom; simp only [hdomE]
  have hrowsOf : ∀ d, Exec.Block.DefW16.rowsOf c₁ d = Exec.Block.DefW16.rowsOf c₂ d := fun d => by
    unfold Exec.Block.DefW16.rowsOf; rw [hsh, hlc]
  have hdomRow : ∀ d, Exec.Block.DefR13.domRow c₁ d = Exec.Block.DefR13.domRow c₂ d := fun d => by
    unfold Exec.Block.DefR13.domRow; simp only [hdomS, hdomE, hrowsOf]
  have haOff : ∀ q, Exec.Block.DefR13.aOff c₁ q = Exec.Block.DefR13.aOff c₂ q := fun q => by
    unfold Exec.Block.DefR13.aOff; rw [hdomRow, hplaneDom, hdomS, hrowsOf, hlc]
  have hlogOf : ∀ q, Exec.Block.DefR13.logOf c₁ q = Exec.Block.DefR13.logOf c₂ q := fun q => by
    unfold Exec.Block.DefR13.logOf; rw [hsh, hplaneDom]
  have haPlane : Exec.Block.DefR13.aPlane c₁ = Exec.Block.DefR13.aPlane c₂ := funext fun q => by
    unfold Exec.Block.DefR13.aPlane; rw [haOff, hlogOf]
  have hsupp : ∀ d, Exec.Block.DefW16.supp c₁ d = Exec.Block.DefW16.supp c₂ d := fun d => by
    unfold Exec.Block.DefW16.supp; rw [hsh]
  have hzeroPl : ∀ d, Exec.Block.DefR13.zeroPl c₁ d = Exec.Block.DefR13.zeroPl c₂ d := fun d => by
    unfold Exec.Block.DefR13.zeroPl; rw [hsh, hdomPl, hids]
  have hseg : ∀ s' j, Exec.Block.DefR13.seg c₁ s' j = Exec.Block.DefR13.seg c₂ s' j := fun s' j => by
    unfold Exec.Block.DefR13.seg; rw [hsh]
  have hclaimPt : ∀ s', Exec.Block.DefR13.claimPt c₁ s' = Exec.Block.DefR13.claimPt c₂ s' := fun s' => by
    unfold Exec.Block.DefR13.claimPt; simp only [hseg]
  have hfh : ∀ k, Exec.Block.DefR13.fh c₁ k = Exec.Block.DefR13.fh c₂ k := fun k => by
    unfold Exec.Block.DefR13.fh Exec.Block.DefR13.hIdsN; simp only [hnh]
  have hhDoms : Exec.Block.DefR13.hDoms c₁ = Exec.Block.DefR13.hDoms c₂ := by
    unfold Exec.Block.DefR13.hDoms; simp only [hnh]
  have hhOff : ∀ hp, Exec.Block.DefR13.hOff c₁ hp = Exec.Block.DefR13.hOff c₂ hp := fun hp => by
    unfold Exec.Block.DefR13.hOff; simp only [hhDoms, hrowsOf, hlc]
  have hhTab : ∀ hp, Exec.Block.DefR13.hTab c₁ hp = Exec.Block.DefR13.hTab c₂ hp := fun hp => by
    unfold Exec.Block.DefR13.hTab; simp only [hhOff, hhDoms, hsh]
  have hepTab : ∀ cm, Exec.Block.DefW16.epTab c₁ cm = Exec.Block.DefW16.epTab c₂ cm := fun cm => by
    unfold Exec.Block.DefW16.epTab; rw [hsh]
  unfold Exec.Block.DefR13.rawSlot
  dsimp only
  simp only [apply_ite SlotS.tabs, hids, hsh, hsupp, hseg, haPlane, haOff, hlogOf, hclaimPt,
    hzeroPl, hhTab, hfh, hdomPl, hnh, hepTab]

private theorem rawSlot_tabs_indep (Ly : ShieldLayer) (s : ℕ) :
    (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).tabs
      = (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdLy0) s).tabs :=
  rawSlot_tabs_congr (Exec.Block.DefR13.cfgShieldR13 Ly) (Exec.Block.DefR13.cfgShieldR13 shdLy0)
    rfl rfl rfl rfl (nHelp_cfgShieldR13 Ly) s

private theorem rawSlot_tabs_lenOk :
    ∀ s : Fin 23,
      tabsLenOKb (Exec.Block.R13.shieldSlots.getD s.val (0, 0, 0)).1 (blkMaxPub s.val)
        (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdLy0) s.val).tabs = true := by
  decide +kernel

private theorem rawSlot_tabs_lenOk_at (s : ℕ) (hs : s < 23) :
    tabsLenOKb (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).1 (blkMaxPub s)
      (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdLy0) s).tabs = true := by
  have h : ∀ (k : Fin 23) (n : ℕ), k.val = n →
      tabsLenOKb (Exec.Block.R13.shieldSlots.getD n (0, 0, 0)).1 (blkMaxPub n)
        (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdLy0) n).tabs = true := by
    intro k n hkn; subst hkn; exact rawSlot_tabs_lenOk k
  exact h ⟨s, hs⟩ s rfl

private theorem numTabs_lenOk (aB hB ioIn ioOut main : ℕ) :
    ∀ (ts : List TabS) (ak hk pk : ℕ), ts.all (tabLenOKb main) = true →
      (Exec.Block.DefW16.numTabs aB hB ioIn ioOut ak hk pk ts).all (tabLenOKb main) = true
  | [], _, _, _, _ => rfl
  | .priv _ :: ts, ak, hk, pk, h => by
    simp only [List.all_cons, Bool.and_eq_true] at h
    simp only [Exec.Block.DefW16.numTabs, List.all_cons, Bool.and_eq_true]
    exact ⟨rfl, numTabs_lenOk aB hB ioIn ioOut main ts _ _ pk h.2⟩
  | .pub _ :: ts, ak, hk, pk, h => by
    simp only [List.all_cons, Bool.and_eq_true] at h
    simp only [Exec.Block.DefW16.numTabs, List.all_cons, Bool.and_eq_true]
    exact ⟨rfl, numTabs_lenOk aB hB ioIn ioOut main ts ak hk (pk + 1) h.2⟩
  | .eq _ _ :: ts, ak, hk, pk, h => by
    simp only [List.all_cons, Bool.and_eq_true] at h
    simp only [Exec.Block.DefW16.numTabs, List.all_cons, Bool.and_eq_true]
    exact ⟨h.1, numTabs_lenOk aB hB ioIn ioOut main ts ak hk pk h.2⟩

private theorem numTabs_pub_lt (aB hB ioIn ioOut : ℕ) :
    ∀ (ts : List TabS) (ak hk pk i : ℕ),
      TabS.pub i ∈ Exec.Block.DefW16.numTabs aB hB ioIn ioOut ak hk pk ts → i < pk + pubCountS ts
  | [], _, _, _, _, h => by cases h
  | .priv _ :: ts, ak, hk, pk, i, h => by
    rcases List.mem_cons.mp h with h1 | h2
    · cases h1
    · exact numTabs_pub_lt aB hB ioIn ioOut ts _ _ pk i h2
  | .pub _ :: ts, ak, hk, pk, i, h => by
    rcases List.mem_cons.mp h with h1 | h2
    · cases h1; simp only [pubCountS]; omega
    · have ih := numTabs_pub_lt aB hB ioIn ioOut ts ak hk (pk + 1) i h2
      simp only [pubCountS]; omega
  | .eq _ _ :: ts, ak, hk, pk, i, h => by
    rcases List.mem_cons.mp h with h1 | h2
    · cases h1
    · exact numTabs_pub_lt aB hB ioIn ioOut ts ak hk pk i h2

private theorem cubeTab_len (n : ℕ) (g : (Fin n → Bool) → GF) : (cubeTab n g).length = 2 ^ n := by
  simp [cubeTab]

private theorem foldTab_len (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) :
    (foldTab m n W r).length = 2 ^ m := by
  simp [foldTab]

private theorem pubsR13L_len (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (s : ℕ) (hs : s < 23) (hist : Hist) (dr : List Fp2) (i : ℕ) (hi : i < blkMaxPub s) :
    (pubsR13L (Exec.Block.DefR13.cfgShieldR13 Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb)
      (shieldShape Ly).nG s hist dr i).length = 2 ^ (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).1 := by
  interval_cases s <;> simp only [blkMaxPub] at hi
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; rw [ite_eq_left (Or.inl rfl), hi0, ite_eq_left rfl, cubeTab_len]
    refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; rw [ite_eq_left (Or.inr rfl), hi0, ite_eq_left rfl, cubeTab_len]
    refine congrArg (2 ^ ·) ?_; rfl
  · omega
  · have hi0 : i = 0 := by omega
    unfold pubsR13L; rw [Exec.Block.Join.R13H.Pub.pubsR13_rest _ _ _ _ _ 3 (Or.inl rfl)]
    rw [Exec.Block.Join.R13H.Pub.restR13L_three, hi0, ite_eq_left rfl, cubeTab_len]
    refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · omega
  · omega
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl]; interval_cases i
    · rw [ite_eq_left rfl, cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by decide), ite_eq_left rfl, cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by decide), ite_eq_right (by decide), ite_eq_left rfl, cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl]; interval_cases i
    · rw [ite_eq_left rfl, cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by decide), ite_eq_left rfl, cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl]; interval_cases i
    · rw [ite_eq_left rfl, cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by decide), ite_eq_left rfl, cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl]; interval_cases i
    · rw [ite_eq_left rfl, cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by decide), ite_eq_left rfl, cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · rw [pubsR13L_tab _ _ _ _ _ 19 (Or.inl rfl)]
    unfold restR13; dsimp only; rw [ite_eq_left rfl]; interval_cases i
    · rw [ite_eq_left (by omega), List.length_map, List.length_range]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_left (by omega), List.length_map, List.length_range]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_left (by omega), List.length_map, List.length_range]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by omega), ite_eq_left (by omega), cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by omega), ite_eq_left (by omega), cubeTab_len]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    rw [pubsR13L_tab _ _ _ _ _ 20 (Or.inr rfl)]
    unfold restR13; dsimp only; rw [ite_eq_right (by decide), ite_eq_left rfl, hi0, ite_eq_left rfl, cubeTab_len]
    refine congrArg (2 ^ ·) ?_; rfl
  · omega
  · omega

/-- Every accepted Shieldstral R13 block slot definition (`s < 23`) satisfies `TabsLenOk`. -/
theorem shdP_blk_tabsLenOk (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (s : ℕ) (hs : s < 23) (hist : Hist) (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define s hist dr = .ok df) :
    TabsLenOk (slotShape (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb) s).1 df.tabs := by
  obtain ⟨-, hdfEq⟩ := defineS_ok hdf
  obtain ⟨ak, hk', hslot⟩ := progR13_slot (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut s hs
  have hshOK := rawSlot_tabs_lenOk_at s hs
  rw [← rawSlot_tabs_indep Ly s] at hshOK
  simp only [tabsLenOKb, Bool.and_eq_true, decide_eq_true_eq] at hshOK
  obtain ⟨hpubS, hallS⟩ := hshOK
  have hnumAll := numTabs_lenOk (Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 Ly))
    (Exec.Block.DefR13.hDataRows (Exec.Block.DefR13.cfgShieldR13 Ly)) ioIn ioOut
    (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).1
    (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).tabs ak hk' 0 hallS
  have htabs : df.tabs =
      (Exec.Block.DefW16.numTabs (Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 Ly))
        (Exec.Block.DefR13.hDataRows (Exec.Block.DefR13.cfgShieldR13 Ly)) ioIn ioOut ak hk' 0
        (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).tabs).map
        (TabS.eval (Exec.Block.Sym.eval hist s dr)
          (pubsR13L (Exec.Block.DefR13.cfgShieldR13 Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG s hist dr)) :=
    (congrArg SlotDef.tabs hdfEq).trans (congrArg (fun sl : SlotS => sl.tabs.map _) hslot)
  intro t ht
  rw [htabs] at ht
  obtain ⟨tb, htbMem, rfl⟩ := List.mem_map.mp ht
  refine ⟨fun pt st heq => ?_, fun pv heq => ?_⟩
  · cases tb with
    | eq pts st' =>
      have hok := List.all_eq_true.mp hnumAll (TabS.eq pts st') htbMem
      cases heq
      simp only [tabLenOKb, decide_eq_true_eq] at hok
      rw [List.length_map]
      exact hok
    | pub _ => cases heq
    | priv _ => cases heq
  · cases tb with
    | eq _ _ => cases heq
    | priv _ => cases heq
    | pub i =>
      cases heq
      have hilt : i < blkMaxPub s :=
        lt_of_lt_of_le (by simpa using numTabs_pub_lt _ _ _ _ _ ak hk' 0 i htbMem) hpubS
      exact pubsR13L_len Ly Pb s hs hist dr i hilt

/-! ### 1b. Hosted-slot specification & `hostedSum_ok_val` -/

private def blkHostedFst : ℕ → List ℕ
  | 2 => [0, 1] | 14 => [10, 13] | 15 => [5, 9] | 16 => [6, 7] | 17 => [4, 8] | 18 => [11, 12] | _ => []

private theorem blkRawSlot_hosted_fst (Ly : ShieldLayer) (s : ℕ) (hs : s < 23) :
    (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).hosted.map Prod.fst = blkHostedFst s := by
  interval_cases s <;> rfl

private theorem blkHostedFst_host_iff :
    ∀ k : Fin 23, shdP_slotKind k.val = SlotKind.host ↔ blkHostedFst k.val ≠ [] := by
  decide

private theorem blkHostedFst_mem_spec :
    ∀ k : Fin 23, ∀ x ∈ blkHostedFst k.val, x < k.val ∧ x < 23 ∧ shdP_slotKind x = SlotKind.priv := by
  decide

private theorem list_map_fst_pair {α β : Type} (f : α → β) :
    ∀ l : List (ℕ × α), (l.map fun h => (h.1, f h.2)).map Prod.fst = l.map Prod.fst
  | [] => rfl
  | hd :: tl => congrArg (hd.1 :: ·) (list_map_fst_pair f tl)

/-- Exact hosted-slot structure for every accepted Shieldstral R13 block slot definition (`s < 23`). -/
theorem shdP_blk_hosted_spec (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (s : ℕ) (hs : s < 23) (hist : Hist) (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define s hist dr = .ok df) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    (P.kind s = SlotKind.host ↔ df.hosted ≠ [])
      ∧ (P.kind s ≠ SlotKind.host → df.hosted = [])
      ∧ (∀ hk ∈ df.hosted, hk.1 < s ∧ hk.1 < 23 ∧ P.kind hk.1 = SlotKind.priv ∧ hk.2.Canon) := by
  intro P
  obtain ⟨hcan, hdfEq⟩ := defineS_ok hdf
  obtain ⟨ak, hk', hslot⟩ := progR13_slot (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut s hs
  have hhosted : df.hosted =
      ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty).hosted.map
        fun h => (h.1, h.2.eval hist s dr) :=
    congrArg SlotDef.hosted hdfEq
  have hfst : df.hosted.map Prod.fst = blkHostedFst s :=
    calc
      df.hosted.map Prod.fst
          = (((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty).hosted.map
              fun h => (h.1, h.2.eval hist s dr)).map Prod.fst :=
            congrArg (List.map Prod.fst) hhosted
      _ = (((Exec.Block.DefW16.numSlot
              (Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 Ly))
              (Exec.Block.DefR13.hDataRows (Exec.Block.DefR13.cfgShieldR13 Ly)) ioIn ioOut ak hk'
              (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s)).hosted.map
              fun h => (h.1, h.2.eval hist s dr)).map Prod.fst) :=
            congrArg (fun sl : SlotS => (sl.hosted.map fun h => (h.1, h.2.eval hist s dr)).map Prod.fst) hslot
      _ = (((Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).hosted.map
              fun h => (h.1, h.2.eval hist s dr)).map Prod.fst) :=
            congrArg (fun l => (l.map fun h => (h.1, h.2.eval hist s dr)).map Prod.fst)
              (numSlot_fields _ _ _ _ _ _ _).2.1
      _ = (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).hosted.map Prod.fst :=
            list_map_fst_pair (fun sym : Exec.Block.Sym => sym.eval hist s dr) _
      _ = blkHostedFst s := blkRawSlot_hosted_fst Ly s hs
  have hne_iff : df.hosted ≠ [] ↔ df.hosted.map Prod.fst ≠ [] := by
    cases df.hosted <;> simp
  have hiff : P.kind s = SlotKind.host ↔ df.hosted ≠ [] := by
    rw [hne_iff, hfst]
    exact blkHostedFst_host_iff ⟨s, hs⟩
  refine ⟨hiff, fun hnh => ?_, fun hk hhk => ?_⟩
  · cases hlist : df.hosted with
    | nil => rfl
    | cons _ _ =>
      have hne : df.hosted ≠ [] := by rw [hlist]; simp
      have hf : False := hnh (hiff.mpr hne)
      cases hf
  · have hmem1 : hk.1 ∈ df.hosted.map Prod.fst := List.mem_map.mpr ⟨hk, hhk, rfl⟩
    rw [hfst] at hmem1
    have hcanon : hk.2.Canon := by
      rw [hhosted] at hhk
      obtain ⟨p, -, hpEq⟩ := List.mem_map.mp hhk
      rw [← hpEq]
      exact Exec.Block.Sym.eval_canon hcan p.2
    obtain ⟨hlt, h23, hpriv⟩ := blkHostedFst_mem_spec ⟨s, hs⟩ hk.1 hmem1
    exact ⟨hlt, h23, hpriv, hcanon⟩

/-- General canonicity and field-value formula for `Exec.Block.hostedSum`. -/
theorem hostedSum_ok_val (scalars : List Fp2) :
    ∀ (hs : List (ℕ × Fp2)) (sc : Fp2), sc.Canon →
      (∀ hk ∈ hs, hk.1 < scalars.length ∧ hk.2.Canon) →
      ∀ claimed, Exec.Block.hostedSum scalars sc hs = .ok claimed →
        claimed.Canon
          ∧ claimed.toK shdP_U = sc.toK shdP_U
              + (hs.map (fun hk => hk.2.toK shdP_U * (scalars.getD hk.1 Fp2.zero).toK shdP_U)).sum
  | [], sc, hscCan, _, claimed, hcl => by
    simp only [Exec.Block.hostedSum, Except.ok.injEq] at hcl
    subst hcl
    exact ⟨hscCan, by simp⟩
  | (h, coef) :: rest, sc, hscCan, hhs, claimed, hcl => by
    have h0 := hhs (h, coef) List.mem_cons_self
    simp only [Exec.Block.hostedSum] at hcl
    rw [ite_eq_left h0.1] at hcl
    have hrest : ∀ hk ∈ rest, hk.1 < scalars.length ∧ hk.2.Canon :=
      fun hk hhk => hhs hk (List.mem_cons_of_mem _ hhk)
    obtain ⟨hclCan, hclVal⟩ := hostedSum_ok_val scalars rest
      (sc.add (coef.mul (scalars.getD h Fp2.zero))) (Fp2.canon_add _ _) hrest claimed hcl
    refine ⟨hclCan, ?_⟩
    rw [hclVal, Fp2.toK_add shdP_U _ _ hscCan (Fp2.canon_mul _ _), Fp2.toK_mul shdP_U shdP_hU,
      List.map_cons, List.sum_cons]
    ring

private theorem list_map_sum_add {K : Type} [CommRing K] {α : Type} (f g : α → K) :
    ∀ l : List α, (l.map (fun a => f a + g a)).sum = (l.map f).sum + (l.map g).sum
  | [] => by simp
  | a :: l => by
    simp only [List.map_cons, List.sum_cons, list_map_sum_add f g l]
    ring

private theorem list_map_sum_neg {K : Type} [CommRing K] {α : Type} (f : α → K) :
    ∀ l : List α, (l.map (fun a => - f a)).sum = - (l.map f).sum
  | [] => by simp
  | a :: l => by
    simp only [List.map_cons, List.sum_cons, list_map_sum_neg f l]
    ring

/-! ### 1c. Vanishing of `hostPhi` and `dtR` on `blkCmData` -/

/-- Whenever every clause vanishes, every pad plane vanishes, and `g * h_i = M_i` pointwise,
`hostPhi` vanishes identically at all draws `(ω, τ, ν)`. -/
theorem hostPhi_eq_zero {F : Type} [Field F] {n m : ℕ} {ι : Type} [Fintype ι]
    (c : ι → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (g : (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F)
    (ω : (F × F) × (ι → F)) (τ : Fin n → F) (ν : Fin 2 → F)
    (hc : ∀ κ b, c κ b = 0) (hw : ∀ j b, w j b = 0) (hM : ∀ i b, g b * h i b = M i b) :
    ZK60.Sound.SlotW16.hostPhi c w g h M P ω τ ν = 0 := by
  rw [ZK60.Sound.SlotW16.hostPhi_eq]
  have hb : ∀ b, ZK60.Sound.SlotW16.batched c w ω b = 0 := fun b => by
    unfold ZK60.Sound.SlotW16.batched
    simp only [hc, hw, mul_zero, Finset.sum_const_zero, add_zero]
  have hmle : ZK60.Sound.mleAt (ZK60.Sound.SlotW16.batched c w ω) τ = 0 := by
    unfold ZK60.Sound.mleAt
    exact Finset.sum_eq_zero (fun b _ => by rw [hb b, mul_zero])
  have hdiff : ∀ i : Fin 2,
      ZK60.Sound.mleAt (fun b => g b * h i b) (P i) - ZK60.Sound.mleAt (M i) (P i) = 0 := fun i => by
    have heq : (fun b => g b * h i b) = M i := funext (hM i)
    rw [heq, sub_self]
  rw [hmle, zero_add]
  exact Finset.sum_eq_zero (fun i _ => by rw [hdiff i, mul_zero])

private theorem clIx_lt : ∀ k ∈ Exec.Block.algHosts, ∀ κ, κ < Exec.Block.r13Count k →
    clIx k κ < Exec.Block.r13Count k := by
  decide

private theorem r13Cl_eq_zero_of_rels {S : BlockShape} {c : W16Cfg} {ls : ℕ} (G : Exec.Block.Join.R13H.GeoR c ls)
    {Pb : BlockPublic S} {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)}
    {B : W16Pub S Pb Lay} {E : R13Data (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c) ls}
    (hRels : R13Rels S Pb Lay B E)
    (k : ℕ) (hk : k ∈ Exec.Block.algHosts) (j : ℕ) (hj : j < Exec.Block.r13Count k)
    (b : Fin (tauLen c k) → Bool) :
    Exec.Block.r13Cl Pb Lay B E k j (encR G k b) = 0 := by
  simp only [Exec.Block.algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk
  rcases hk with rfl | rfl | rfl | rfl | rfl | rfl
  · change j < 6 at hj
    interval_cases j
    · exact hRels.tzc_sq _
    · exact hRels.tzc_d _
    · exact hRels.tzc_a _
    · exact hRels.tzc_sqm _
    · exact hRels.tzc_dm _
    · exact hRels.tzc_am _
  · change j < 13 at hj
    interval_cases j
    · exact hRels.d0 _
    · exact hRels.d1 _
    · exact hRels.d2 _
    · exact hRels.d3 _
    · exact hRels.d4 _
    · exact hRels.d5 _
    · exact hRels.wX _
    · exact hRels.wY _
    · exact hRels.wAO _
    · exact hRels.wX1 _
    · exact hRels.wYM _
    · exact hRels.wZ _
    · exact hRels.wX2 _
  · change j < 4 at hj
    interval_cases j
    · exact hRels.qrope _
    · exact hRels.wQ _
    · exact hRels.wQR _
    · exact hRels.wO _
  · change j < 4 at hj
    interval_cases j
    · exact hRels.krope _
    · exact hRels.wK _
    · exact hRels.wKR _
    · exact hRels.wV _
  · change j < 5 at hj
    interval_cases j
    · exact hRels.s0 _
    · exact hRels.s1 _
    · exact hRels.s2 _
    · exact hRels.s3 _
    · exact hRels.s4 _
  · change j < 3 at hj
    interval_cases j
    · exact hRels.f0 _
    · exact hRels.f1 _
    · exact hRels.f2 _

private theorem r13Gh_eq_r13Mm_of_rels {S : BlockShape} {c : W16Cfg} {ls : ℕ} (G : Exec.Block.Join.R13H.GeoR c ls)
    {Pb : BlockPublic S} {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)}
    {B : W16Pub S Pb Lay} {E : R13Data (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c) ls}
    (hRels : R13Rels S Pb Lay B E)
    (k : ℕ) (hk : k ∈ Exec.Block.algHosts) (i : Fin 2) (h17 : ¬ (k = 17 ∧ i = 0))
    (b : Fin (tauLen c k) → Bool) :
    Exec.Block.r13Gh Pb Lay B E k i (encR G k b) = Exec.Block.r13Mm Pb Lay B E k i (encR G k b) := by
  simp only [Exec.Block.algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk
  rcases i with ⟨iv, hiv⟩
  rcases hk with rfl | rfl | rfl | rfl | rfl | rfl
  · interval_cases iv
    · exact hRels.ss _
    · exact hRels.ssm _
  · interval_cases iv
    · exact hRels.wo _
    · exact hRels.dmm _
  · interval_cases iv
    · exact hRels.qmm _
    · exact hRels.pv _
  · interval_cases iv
    · exact hRels.kmm _
    · exact hRels.vmm _
  · interval_cases iv
    · have hf : False := h17 ⟨rfl, Fin.ext rfl⟩
      cases hf
    · exact hRels.score _
  · interval_cases iv
    · exact hRels.gmm _
    · exact hRels.umm _

private theorem algSp_zero_eq_hostSp {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]
    {L : ℕ} {P : BlockParams} (U : K) (sh : Exec.Block.AlgShape P) (dt : Exec.Block.AlgData K L sh)
    (hcard : 78 < Fintype.card K) (cu : Exec.Block.Cuts3 L) (rt : Exec.Block.RootsO) (hist : Hist)
    (k : ℕ) (hk : k ∈ Exec.Block.algHosts) :
    Exec.Block.algSp U sh dt hcard 0 cu rt k hist = Exec.Block.hostSp U sh dt hcard k hk cu rt hist := by
  simp only [Exec.Block.algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk
  rcases hk with rfl | rfl | rfl | rfl | rfl | rfl <;> rfl

private theorem seenOf_append_lt (bga : Fp2 × Fp2 × Fp2) (recs : List SlotRec) (r : SlotRec)
    (j : ℕ) (hj : j < recs.length) :
    Exec.Block.seenOf bga (recs ++ [r]) j = Exec.Block.seenOf bga recs j := by
  unfold Exec.Block.seenOf
  rw [List.take_append_of_le_length (by omega)]

end BlkSlotHelpers

/-! ## 2. Per-Slot Arithmetic for ALL 23 Slots (`0..22`) -/

section PerSlotArith

variable (tag : MTag) (ioIn ioOut : ℕ)
  (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
  {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
  {xIn xOut : shieldS0.Pos → ℤ}
  (w : BlkWitness Ly Pb xIn xOut)
  (TB_prev TB_next : Table) (rnd : BlkRand) (bga : Fp2 × Fp2 × Fp2)

/-- Uniform individual degree bound `IndDegLE (slotD P s) (blkSlotPolyK ...)` across all 23 slots `s < 23`. -/
theorem blk_slot_indDeg (s : ℕ) (hs : s < 23) (hist : Hist) (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define s hist dr = .ok df) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    let cs := blkCs (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
    IndDegLE (slotD P s) (blkSlotPolyK P cs s df) := by
  let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
  let cS := Exec.Block.DefR13.cfgShieldR13 Ly
  let prog := Exec.Block.DefR13.progR13 cS ioIn ioOut
  let pubs := pubsR13L cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG
  let DS := blkCmData P rfl rfl (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
  let cs := blkCs (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
  have hprogOK : Exec.Block.progOKb (Exec.Block.rowLog P) prog P.geom.slots = true :=
    progR13_shield_okP Ly w.hLy P rfl (by show 0 < 14; norm_num) (by show 0 < 14; norm_num) ioIn ioOut
  exact blkSlotPolyK_indDeg P DS cs (blkCs_eq_claimSem P rfl rfl _ _ _ _) prog pubs rfl hprogOK
    s hist dr df hdf (shdP_blk_tabsLenOk tag ioIn ioOut checkOpening Ly Pb s hs hist dr df hdf)

/-- **All 6 `.host` slots (`{2, 14, 15, 16, 17, 18}`)**: on `blkCmData` with `w.hRels` and `blkAlphaBad = false`,
the unmasked cube sum of `blkSlotPolyK` equals the weighted sum of the hosted private slots' `spSum`s! -/
theorem blk_host_cubeSum_eq_hosted (hβ : bga.1.Canon) (hα : bga.2.2.Canon)
    (hbad : blkAlphaBad Ly Pb bga = false)
    (s : ℕ) (hs : s < 23) (hkHost : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).kind s = SlotKind.host)
    (recs : List SlotRec) (hrecsLen : recs.length = s)
    (hrecsDef : ∀ j r, recs[j]? = some r →
      ∃ df', (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define j
        (Exec.Block.histOf bga.1 bga.2.1 bga.2.2 (recs.take j)) r.draws = .ok df'
        ∧ ((shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).kind j = SlotKind.host ↔ df'.hosted ≠ []))
    (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define s
      (Exec.Block.histOf bga.1 bga.2.1 bga.2.2 recs) dr = .ok df) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    let cS := Exec.Block.DefR13.cfgShieldR13 Ly
    let prog := Exec.Block.DefR13.progR13 cS ioIn ioOut
    let pubs := pubsR13L cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG
    let DS := blkCmData P rfl rfl (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
    let cs := blkCs (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
    cubeSum (blkSlotPolyK P cs s df)
      = (df.hosted.map (fun hk => hk.2.toK shdP_U
          * Exec.Block.spSum P (polyS shdP_U P DS prog pubs) bga recs hk.1)).sum := by
  intro P cS prog pubs DS cs
  have hsMem : s ∈ Exec.Block.algHosts := by
    change shdP_slotKind s = SlotKind.host at hkHost
    interval_cases s <;> simp [shdP_slotKind, Exec.Block.algHosts] at hkHost ⊢
  let r0 : SlotRec := ⟨dr, Fp2.zero, Fp2.zero, Fp2.zero, [], [], [], Fp2.zero⟩
  let rs' : List SlotRec := recs ++ [r0]
  have hrs'_at : rs'[s]? = some r0 := by
    show (recs ++ [r0])[s]? = some r0
    rw [List.getElem?_append_right (by omega), hrecsLen, Nat.sub_self]
    rfl
  have hrs'_take : rs'.take s = recs := by
    show (recs ++ [r0]).take s = recs
    rw [← hrecsLen, List.take_append_of_le_length le_rfl, List.take_length]
  have hslots : ∀ j r, rs'[j]? = some r →
      ∃ df', P.define j (Exec.Block.histOf bga.1 bga.2.1 bga.2.2 (rs'.take j)) r.draws = .ok df'
        ∧ (P.kind j = SlotKind.host ↔ df'.hosted ≠ []) := by
    intro j r hr
    by_cases hlt : j < s
    · rw [show rs'[j]? = recs[j]? from List.getElem?_append_left (by omega)] at hr
      rw [show rs'.take j = recs.take j from List.take_append_of_le_length (by omega)]
      exact hrecsDef j r hr
    · by_cases heq : j = s
      · subst heq
        rw [hrs'_at, Option.some.injEq] at hr
        subst hr
        rw [hrs'_take]
        exact ⟨df, hdf, (shdP_blk_hosted_spec tag ioIn ioOut checkOpening Ly Pb j hs _ dr df hdf).1⟩
      · have hgt : rs'.length ≤ j := by
          show (recs ++ [r0]).length ≤ j
          rw [List.length_append, List.length_singleton, hrecsLen]; omega
        rw [List.getElem?_eq_none hgt] at hr
        cases hr
  let hc : Exec.Block.Join.R13H.ShOkR cS.sh P := shOk_shield Ly P rfl
  let Dof : Exec.Block.Cuts3 0 → Exec.Block.RootsO → CmData shdP_K P := fun _ _ => DS
  let cu : Exec.Block.Cuts3 0 := ([], [], [])
  let rt : Exec.Block.RootsO := (none, none, none)
  let dt := dtR (geoShield Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) P hc
    (fun cu' rt' => xtR shdP_U cS P (Dof cu' rt') 1) (perRow_shield Ly)
    (xcR shdP_U (geoShield Ly) P Dof Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb))
    (pwcR shdP_U (geoShield Ly) P Dof Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb))
  have hform := formAt_hostsR shdP_U shdP_hU (Exec.Block.card_K_gt shdP_K) Pb (geoShield Ly)
    (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) P hc (profR_shield Ly P rfl rfl)
    (Exec.Block.Join.R13H.Tzc.tzcCfg_shield Ly)
    (Exec.Block.Join.R13H.Dzc.dzcCfg_shield Ly w.hLy)
    (Exec.Block.Join.R13H.Qkv.qkvCfg_shieldExport Ly w.hLy)
    (Exec.Block.Join.R13H.Szc.szcCfg_shield Ly w.hLy)
    (Exec.Block.Join.R13H.Fzc.fzcCfg_shield Ly w.hLy)
    ioIn ioOut pubs rfl Dof
    (fun _ _ => blkCmData_base P rfl rfl (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next)
    (by show 0 < 14; norm_num) (by show 0 < 14; norm_num)
    (precR_shield Ly) (shieldWindows Ly w.hLy) (shdP_bitLay_layR Ly)
    (pubR_of_L cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG shdP_U shdP_hU)
    (perRow_shield Ly) cu rt bga rs' hslots s hsMem r0 df hrs'_at (by rw [hrs'_take]; exact hdf)
  have hPhiEq :
      (Exec.Block.algSp shdP_U (algShapeR cS P hc) dt (Exec.Block.card_K_gt shdP_K) 0 cu rt s
          (Exec.Block.histOf bga.1 bga.2.1 bga.2.2 (rs'.take s))).Φ
        (fun i => (r0.draws.getD i.val Fp2.zero).toK shdP_U)
      = Exec.Block.spSum P (polyS shdP_U P DS prog pubs) bga rs' s
        - (df.hosted.map (fun hk => hk.2.toK shdP_U
            * Exec.Block.spSum P (polyS shdP_U P DS prog pubs) bga rs' hk.1)).sum := by
    rcases hform with ⟨hsa, _⟩ | ⟨_, _, heq⟩
    · rw [hkHost] at hsa; cases hsa
    · exact heq
  have hxt : xtR shdP_U cS P DS 1 = w.E := blk_xtR_eq_E P rfl rfl w rnd bga TB_prev TB_next
  have hPhiZero :
      (Exec.Block.algSp shdP_U (algShapeR cS P hc) dt (Exec.Block.card_K_gt shdP_K) 0 cu rt s
          (Exec.Block.histOf bga.1 bga.2.1 bga.2.2 (rs'.take s))).Φ
        (fun i => (r0.draws.getD i.val Fp2.zero).toK shdP_U) = 0 := by
    rw [algSp_zero_eq_hostSp shdP_U (algShapeR cS P hc) dt (Exec.Block.card_K_gt shdP_K) cu rt _ s hsMem,
      Exec.Block.hostSp_Φ]
    refine hostPhi_eq_zero _ _ _ _ _ _ _ _ _ ?_ ?_ ?_
    · intro κ b
      change (if (κ : ℕ) < Exec.Block.r13Count s then
        algebraMap GF shdP_K (Exec.Block.r13Cl Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb)
          (xtR shdP_U cS P DS 1) s (clIx s κ) (encR (geoShield Ly) s b))
        else xcR shdP_U (geoShield Ly) P Dof Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) s cu rt bga κ b) = 0
      by_cases hκ : (κ : ℕ) < Exec.Block.r13Count s
      · rw [ite_eq_left hκ, hxt,
          r13Cl_eq_zero_of_rels (geoShield Ly) w.hRels s hsMem (clIx s κ) (clIx_lt s hsMem κ hκ) b,
          map_zero]
      · rw [ite_eq_right hκ]
        exact blk_xcR_eq_zero P rfl rfl w rnd bga TB_prev TB_next Dof cu rt rfl hβ hα hbad s κ.val b
    · intro j b
      exact blk_pwcR_eq_zero P rfl rfl w rnd bga TB_prev TB_next Dof cu rt rfl s j b
    · intro i b
      rw [one_mul]
      by_cases h17 : s = 17 ∧ i = 0
      · unfold Exec.Block.algH Exec.Block.algM
        rw [dite_eq_left h17, ite_eq_left h17]
        have hA0 : ∀ b', dt.rsA cu rt b' = 0 := fun b' => by
          change algebraMap GF shdP_K (Exec.Block.r13RsA Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb)
            (xtR shdP_U cS P DS 1) (encHtR (geoShield Ly) b')) = 0
          rw [hxt]
          change algebraMap GF shdP_K (Exec.Block.r13RsA Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) w.E (.ht _)) = 0
          simp only [Exec.Block.r13RsA]
          rw [sub_eq_zero.mpr (w.hRels.rsE _), map_zero]
        have hB0 : ∀ b', dt.rsB cu rt b' = 0 := fun b' => by
          change algebraMap GF shdP_K (Exec.Block.r13RsB Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb)
            (xtR shdP_U cS P DS 1) (encHtR (geoShield Ly) b')) = 0
          rw [hxt]
          change algebraMap GF shdP_K (Exec.Block.r13RsB Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) w.E (.ht _)) = 0
          simp only [Exec.Block.r13RsB]
          rw [sub_eq_zero.mpr (w.hRels.rsZ _), map_zero]
        rw [hA0, hB0]
        ring
      · rw [Exec.Block.algH_gh _ _ _ _ _ _ _ _ h17, Exec.Block.algM_mm _ _ _ _ _ _ h17]
        change algebraMap GF shdP_K (Exec.Block.r13Gh Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb)
            (xtR shdP_U cS P DS 1) s i (encR (geoShield Ly) s b))
          = algebraMap GF shdP_K (Exec.Block.r13Mm Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb)
            (xtR shdP_U cS P DS 1) s i (encR (geoShield Ly) s b))
        rw [hxt, r13Gh_eq_r13Mm_of_rels (geoShield Ly) w.hRels s hsMem i h17 b]
  have hspEq : Exec.Block.spSum P (polyS shdP_U P DS prog pubs) bga rs' s
      = (df.hosted.map (fun hk => hk.2.toK shdP_U
          * Exec.Block.spSum P (polyS shdP_U P DS prog pubs) bga rs' hk.1)).sum :=
    sub_eq_zero.mp (hPhiEq.symm.trans hPhiZero)
  have hprogOK : Exec.Block.progOKb (Exec.Block.rowLog P) prog P.geom.slots = true :=
    progR13_shield_okP Ly w.hLy P rfl (by show 0 < 14; norm_num) (by show 0 < 14; norm_num) ioIn ioOut
  have hpolyEq : blkSlotPolyK P cs s df = polyS shdP_U P DS prog pubs s (Exec.Block.seenOf bga rs' s) := by
    funext x
    refine blkSlotPolyK_eq_polyS P DS cs (blkCs_eq_claimSem P rfl rfl _ _ _ _) prog pubs rfl hprogOK
      s (Exec.Block.seenOf bga rs' s) df ?_
      (shdP_blk_tabsLenOk tag ioIn ioOut checkOpening Ly Pb s hs _ dr df hdf) x
    rw [Exec.Block.histSeen_seenOf, hrs'_take, Exec.Block.drSeen_seenOf bga rs' s r0 hrs'_at]
    exact hdf
  have hmapEq : df.hosted.map (fun hk => hk.2.toK shdP_U * Exec.Block.spSum P (polyS shdP_U P DS prog pubs) bga rs' hk.1)
      = df.hosted.map (fun hk => hk.2.toK shdP_U * Exec.Block.spSum P (polyS shdP_U P DS prog pubs) bga recs hk.1) := by
    refine List.map_congr_left (fun hk hhk => ?_)
    have hlt := ((shdP_blk_hosted_spec tag ioIn ioOut checkOpening Ly Pb s hs _ dr df hdf).2.2 hk hhk).1
    unfold Exec.Block.spSum
    rw [seenOf_append_lt bga recs r0 hk.1 (by omega)]
  rw [hpolyEq]
  exact hspEq.trans (congrArg List.sum hmapEq)

/-- **Slot 3 (`SC_LZC`, `.standalone`)**: `cubeSum (blkSlotPolyK ... 3 df) = 0`. -/
theorem blk_slot3_cubeSum (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (hist : Hist) (hbga : (hist.beta, hist.gamma, hist.alpha) = bga)
    (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define 3 hist dr = .ok df) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    let cs := blkCs (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
    cubeSum (blkSlotPolyK P cs 3 df) = 0 := by
  intro P cs
  let cS := Exec.Block.DefR13.cfgShieldR13 Ly
  let prog := Exec.Block.DefR13.progR13 cS ioIn ioOut
  let pubs := pubsR13L cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG
  let DS := blkCmData P rfl rfl (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
  obtain ⟨-, hdfEq⟩ := defineS_ok hdf
  obtain ⟨ak, hk, hslot⟩ := progR13_slot cS ioIn ioOut 3 (by norm_num)
  have hraw3 : Exec.Block.DefR13.rawSlot cS 3 = rawSlot3R cS := (helpCfg_shield Ly w.hLy).raw3
  have hprogOK : Exec.Block.progOKb (Exec.Block.rowLog P) prog P.geom.slots = true :=
    progR13_shield_okP Ly w.hLy P rfl (by show 0 < 14; norm_num) (by show 0 < 14; norm_num) ioIn ioOut
  have hlen := shdP_blk_tabsLenOk tag ioIn ioOut checkOpening Ly Pb 3 (by norm_num) hist dr df hdf
  have hcube := lzcR_cube shdP_U shdP_hU cS P DS (by show 0 < 14; norm_num) (gateLS cS.sh) hist dr (pubs 3 hist dr)
    (fun b => pubsR13L_three_getD cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG shdP_U hist dr b)
    (Exec.Block.DefR13.aDataRows cS + 2 * ak) (Exec.Block.DefR13.aDataRows cS + 2 * (ak + 1))
    (Exec.Block.DefR13.hDataRows cS + 2 * hk) (slotShape P 3).1 (slotShape P 3).2.1 rfl
    (blkSlotPolyK P cs 3 df) (fun x => by
      rw [blkSlotPolyK_eq_irEval P DS cs (blkCs_eq_claimSem P rfl rfl _ _ _ _) prog pubs rfl hprogOK 3 hist dr df hdf hlen x,
        hdfEq]
      dsimp only
      rw [hslot, hraw3]
      rfl)
  rw [hcube, hbga]
  refine Finset.sum_eq_zero (fun b _ => ?_)
  rw [show Exec.Block.Join.R13H.Help.cLzcR shdP_U cS P DS (gateLS cS.sh) bga b = 0 from
    blk_cLzcR_eq_zero P rfl rfl w rnd bga TB_prev TB_next (gateLS cS.sh) hα hbad b]
  have hw0 : ∑ j : Fin 2, ((dr.getD 15 Fp2.zero).toK shdP_U) ^ (j : ℕ)
      * Exec.Block.Join.R13H.Help.wLzcR shdP_U cS P DS (gateLS cS.sh) j b = 0 :=
    Finset.sum_eq_zero (fun j _ => by
      rw [show Exec.Block.Join.R13H.Help.wLzcR shdP_U cS P DS (gateLS cS.sh) j b = 0 from
        blk_wLzcR_eq_zero P rfl rfl w rnd bga TB_prev TB_next j b, mul_zero])
  rw [hw0, mul_zero, add_zero, mul_zero]

/-- **Slot 19 (`SC_TAB`, `.standalone`)**: `cubeSum (blkSlotPolyK ... 19 df) = 0`. -/
theorem blk_slot19_cubeSum (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (hist : Hist) (hbga : (hist.beta, hist.gamma, hist.alpha) = bga)
    (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define 19 hist dr = .ok df) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    let cs := blkCs (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
    cubeSum (blkSlotPolyK P cs 19 df) = 0 := by
  intro P cs
  let cS := Exec.Block.DefR13.cfgShieldR13 Ly
  let prog := Exec.Block.DefR13.progR13 cS ioIn ioOut
  let pubs := pubsR13L cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG
  let DS := blkCmData P rfl rfl (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
  obtain ⟨-, hdfEq⟩ := defineS_ok hdf
  obtain ⟨ak, hk, hslot⟩ := progR13_slot cS ioIn ioOut 19 (by norm_num)
  have hraw19 : Exec.Block.DefR13.rawSlot cS 19 = rawSlotR cS := (helpCfg_shield Ly w.hLy).raw19
  have hprogOK : Exec.Block.progOKb (Exec.Block.rowLog P) prog P.geom.slots = true :=
    progR13_shield_okP Ly w.hLy P rfl (by show 0 < 14; norm_num) (by show 0 < 14; norm_num) ioIn ioOut
  have hlen := shdP_blk_tabsLenOk tag ioIn ioOut checkOpening Ly Pb 19 (by norm_num) hist dr df hdf
  have hcube := tabR_cube shdP_U shdP_hU cS P DS (by show 0 < 14; norm_num) (by show 0 < 14; norm_num)
    Pb.exp Pb.act Ly.nG (Exec.Block.DefR13.aDataRows cS) (Exec.Block.DefR13.hDataRows cS) ioIn ioOut ak hk
    hist dr (pubs 19 hist dr)
    (fun i => pubsR13L_tab cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG 19 (Or.inl rfl) hist dr i)
    (slotShape P 19).1 (slotShape P 19).2.1 rfl
    (blkSlotPolyK P cs 19 df) (fun x => by
      rw [blkSlotPolyK_eq_irEval P DS cs (blkCs_eq_claimSem P rfl rfl _ _ _ _) prog pubs rfl hprogOK 19 hist dr df hdf hlen x,
        hdfEq]
      dsimp only
      rw [hslot, hraw19]
      rfl)
  rw [hcube, hbga]
  refine Finset.sum_eq_zero (fun b _ => ?_)
  have hc0 : ∑ k : Fin 3, (dr.getD (14 + (k : ℕ)) Fp2.zero).toK shdP_U
      * Exec.Block.Join.R13T.cTabR shdP_U cS P DS Pb.exp Pb.act Ly.nG bga k b = 0 :=
    Finset.sum_eq_zero (fun k _ => by
      rw [show Exec.Block.Join.R13T.cTabR shdP_U cS P DS Pb.exp Pb.act Ly.nG bga k b = 0 from
        blk_cTabR_eq_zero P rfl rfl w rnd bga TB_prev TB_next hα hbad k b, mul_zero])
  have hw0 : ∑ j : Fin 6, ((dr.getD 18 Fp2.zero).toK shdP_U) ^ (j : ℕ)
      * Exec.Block.Join.R13T.wTabR shdP_U cS P DS Ly.nG j b = 0 :=
    Finset.sum_eq_zero (fun j _ => by
      rw [show Exec.Block.Join.R13T.wTabR shdP_U cS P DS Ly.nG j b = 0 from
        blk_wTabR_eq_zero P rfl rfl w rnd bga TB_prev TB_next j b, mul_zero])
  rw [hc0, hw0, mul_zero, add_zero, mul_zero]

/-- **Slot 20 (`SC_ZS`, `.standalone`)**: `cubeSum (blkSlotPolyK ... 20 df) = 0`. -/
theorem blk_slot20_cubeSum (hist : Hist) (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define 20 hist dr = .ok df) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    let cs := blkCs (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
    cubeSum (blkSlotPolyK P cs 20 df) = 0 := by
  intro P cs
  let cS := Exec.Block.DefR13.cfgShieldR13 Ly
  let prog := Exec.Block.DefR13.progR13 cS ioIn ioOut
  let pubs := pubsR13L cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG
  let DS := blkCmData P rfl rfl (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
  obtain ⟨-, hdfEq⟩ := defineS_ok hdf
  obtain ⟨_, hk, hslot⟩ := progR13_slot cS ioIn ioOut 20 (by norm_num)
  have hraw20 : Exec.Block.DefR13.rawSlot cS 20 = rawSlot20R cS := (helpCfg_shield Ly w.hLy).raw20
  have hprogOK : Exec.Block.progOKb (Exec.Block.rowLog P) prog P.geom.slots = true :=
    progR13_shield_okP Ly w.hLy P rfl (by show 0 < 14; norm_num) (by show 0 < 14; norm_num) ioIn ioOut
  have hlen := shdP_blk_tabsLenOk tag ioIn ioOut checkOpening Ly Pb 20 (by norm_num) hist dr df hdf
  have hcube := zsR_cube shdP_U P DS (by show 0 < 14; norm_num) hist dr (pubs 20 hist dr)
    (Exec.Block.DefR13.hOff cS (Exec.Block.DefR13.fh cS 10)).1
    (Exec.Block.DefR13.hOff cS (Exec.Block.DefR13.fh cS 10)).2
    (Exec.Block.DefR13.hDataRows cS + 2 * hk) (slotShape P 20).1 (slotShape P 20).2.1 rfl
    (blkSlotPolyK P cs 20 df) (fun x => by
      rw [blkSlotPolyK_eq_irEval P DS cs (blkCs_eq_claimSem P rfl rfl _ _ _ _) prog pubs rfl hprogOK 20 hist dr df hdf hlen x,
        hdfEq]
      dsimp only
      rw [hslot, hraw20]
      rfl)
  rw [hcube]
  have hones : ∀ b : Fin 14 → Bool,
      ((pubs 20 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK shdP_U
        * hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (Exec.Block.DefR13.fh cS 10)).1
            (Exec.Block.DefR13.hOff cS (Exec.Block.DefR13.fh cS 10)).2 14 b
      = hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (Exec.Block.DefR13.fh cS 10)).1
          (Exec.Block.DefR13.hOff cS (Exec.Block.DefR13.fh cS 10)).2 14 b := fun b => by
    dsimp only [pubs]
    rw [pubsR13L_tab cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG 20 (Or.inr rfl) hist dr 0,
      rest20R13_getD shdP_U Pb.exp Pb.act (shieldShape Ly).nG hist dr b, one_mul]
  rw [Finset.sum_congr rfl (fun b _ => hones b)]
  exact blk_hU_sum_eq_zero P rfl rfl w rnd bga TB_prev TB_next

/-- **Slot 21 (`SC_IOIN`, `.standalone`)**: `cubeSum (blkSlotPolyK ... 21 df) = 0`. -/
theorem blk_slot21_cubeSum (hTB_prev : FullBndTableSpec xIn TB_prev) (hxIn : ∀ p, i16 (xIn p))
    (hist : Hist) (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define 21 hist dr = .ok df) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    let cs := blkCs (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
    cubeSum (blkSlotPolyK P cs 21 df) = 0 := by
  intro P cs
  let cS := Exec.Block.DefR13.cfgShieldR13 Ly
  let prog := Exec.Block.DefR13.progR13 cS ioIn ioOut
  let pubs := pubsR13L cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG
  let DS := blkCmData P rfl rfl (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
  obtain ⟨-, hdfEq⟩ := defineS_ok hdf
  obtain ⟨ak, _, hslot⟩ := progR13_slot cS ioIn ioOut 21 (by norm_num)
  have hprogOK : Exec.Block.progOKb (Exec.Block.rowLog P) prog P.geom.slots = true :=
    progR13_shield_okP Ly w.hLy P rfl (by show 0 < 14; norm_num) (by show 0 < 14; norm_num) ioIn ioOut
  have hlen := shdP_blk_tabsLenOk tag ioIn ioOut checkOpening Ly Pb 21 (by norm_num) hist dr df hdf
  have hcube := ioR_cube shdP_U P DS .inp (by show 0 < 14; norm_num) (by show 0 < 14; norm_num)
    21 19 (slotShape P 21).2.1 (offR cS 8) (Exec.Block.DefR13.aDataRows cS + 2 * ak) ioIn (by norm_num)
    hist dr (pubs 21 hist dr) (blkSlotPolyK P cs 21 df) (fun x => by
      rw [blkSlotPolyK_eq_irEval P DS cs (blkCs_eq_claimSem P rfl rfl _ _ _ _) prog pubs rfl hprogOK 21 hist dr df hdf hlen x,
        hdfEq]
      dsimp only
      rw [hslot, rawSlot21_shield Ly]
      rfl)
  refine hcube.trans (Finset.sum_eq_zero (fun b _ => ?_))
  have hio : planeZ shdP_U (Exec.Block.rowLog P .inp) (DS.rows .inp) (DS.Q .inp) (DS.X .inp)
      ⟨.inp, [(0, Fp2.one)], 19, [], 0, 0⟩ b = aPl shdP_U P DS (offR cS 8) 19 b :=
    blk_ioIn_eq P rfl rfl w rnd bga TB_prev TB_next hTB_prev hxIn b
  rw [hio, sub_self, mul_zero]

/-- **Slot 22 (`SC_IOOUT`, `.standalone`)**: `cubeSum (blkSlotPolyK ... 22 df) = 0`. -/
theorem blk_slot22_cubeSum (hTB_next : FullBndTableSpec xOut TB_next) (hxOut : ∀ p, i16 (xOut p))
    (hist : Hist) (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define 22 hist dr = .ok df) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    let cs := blkCs (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
    cubeSum (blkSlotPolyK P cs 22 df) = 0 := by
  intro P cs
  let cS := Exec.Block.DefR13.cfgShieldR13 Ly
  let prog := Exec.Block.DefR13.progR13 cS ioIn ioOut
  let pubs := pubsR13L cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG
  let DS := blkCmData P rfl rfl (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
  obtain ⟨-, hdfEq⟩ := defineS_ok hdf
  obtain ⟨ak, _, hslot⟩ := progR13_slot cS ioIn ioOut 22 (by norm_num)
  have hprogOK : Exec.Block.progOKb (Exec.Block.rowLog P) prog P.geom.slots = true :=
    progR13_shield_okP Ly w.hLy P rfl (by show 0 < 14; norm_num) (by show 0 < 14; norm_num) ioIn ioOut
  have hlen := shdP_blk_tabsLenOk tag ioIn ioOut checkOpening Ly Pb 22 (by norm_num) hist dr df hdf
  have hcube := ioR_cube shdP_U P DS .out (by show 0 < 14; norm_num) (by show 0 < 14; norm_num)
    22 19 (slotShape P 22).2.1 (offR cS 44) (Exec.Block.DefR13.aDataRows cS + 2 * ak) ioOut (by norm_num)
    hist dr (pubs 22 hist dr) (blkSlotPolyK P cs 22 df) (fun x => by
      rw [blkSlotPolyK_eq_irEval P DS cs (blkCs_eq_claimSem P rfl rfl _ _ _ _) prog pubs rfl hprogOK 22 hist dr df hdf hlen x,
        hdfEq]
      dsimp only
      rw [hslot, rawSlot22_shield Ly]
      rfl)
  refine hcube.trans (Finset.sum_eq_zero (fun b _ => ?_))
  have hio : planeZ shdP_U (Exec.Block.rowLog P .out) (DS.rows .out) (DS.Q .out) (DS.X .out)
      ⟨.inp, [(0, Fp2.one)], 19, [], 0, 0⟩ b = aPl shdP_U P DS (offR cS 44) 19 b :=
    blk_ioOut_eq P rfl rfl w rnd bga TB_prev TB_next hTB_next hxOut b
  rw [hio, sub_self, mul_zero]

/-- **All 5 `.standalone` slots (`3, 19, 20, 21, 22`)**: `cubeSum (blkSlotPolyK ... s df) = 0`. -/
theorem blk_standalone_cubeSum_eq_zero (hTB_prev : FullBndTableSpec xIn TB_prev)
    (hTB_next : FullBndTableSpec xOut TB_next) (hxIn : ∀ p, i16 (xIn p)) (hxOut : ∀ p, i16 (xOut p))
    (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (s : ℕ) (hs : s < 23) (hkSa : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).kind s = SlotKind.standalone)
    (hist : Hist) (hbga : (hist.beta, hist.gamma, hist.alpha) = bga)
    (dr : List Fp2) (df : SlotDef)
    (hdf : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define s hist dr = .ok df) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    let cs := blkCs (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next
    cubeSum (blkSlotPolyK P cs s df) = 0 := by
  have hsCases : s = 3 ∨ s = 19 ∨ s = 20 ∨ s = 21 ∨ s = 22 := by
    change shdP_slotKind s = SlotKind.standalone at hkSa
    interval_cases s <;> simp [shdP_slotKind] at hkSa ⊢
  rcases hsCases with rfl | rfl | rfl | rfl | rfl
  · exact blk_slot3_cubeSum tag ioIn ioOut checkOpening w TB_prev TB_next rnd bga hα hbad hist hbga dr df hdf
  · exact blk_slot19_cubeSum tag ioIn ioOut checkOpening w TB_prev TB_next rnd bga hα hbad hist hbga dr df hdf
  · exact blk_slot20_cubeSum tag ioIn ioOut checkOpening w TB_prev TB_next rnd bga hist dr df hdf
  · exact blk_slot21_cubeSum tag ioIn ioOut checkOpening w TB_prev TB_next rnd bga hTB_prev hxIn hist dr df hdf
  · exact blk_slot22_cubeSum tag ioIn ioOut checkOpening w TB_prev TB_next rnd bga hTB_next hxOut hist dr df hdf

end PerSlotArith

/-! ## 3. `BlkAccInv`, `blk_slot_step`, and `shdP_blk_slots_ok` (`0..23`) -/

section BlockSlotLoop

/-- Accumulator invariant carried across all 23 Shieldstral R13 block slots (`s = 0..23`). -/
structure BlkAccInv (P : BlockParams) (DS : CmData shdP_K P) (prog : List SlotS) (pubs : Exec.Block.PubTabs)
    (TA TH TB_prev TB_next : Table) (M : MTable) (rnd : BlkRand) (bga : Fp2 × Fp2 × Fp2)
    (s : ℕ) (recs : List SlotRec) (acc : Acc) : Prop where
  recs_len : recs.length = s
  recs_def : ∀ j r, recs[j]? = some r →
    ∃ df, P.define j (Exec.Block.histOf bga.1 bga.2.1 bga.2.2 (recs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])
  cs_len : acc.cs.length = s
  cs_canon : ∀ c ∈ acc.cs, c.Canon
  sc_len : acc.scalars.length = s
  sc_canon : ∀ sc ∈ acc.scalars, sc.Canon
  priv_ok : ∀ j, j < s → P.kind j = SlotKind.priv →
    (acc.scalars.getD j Fp2.zero).toK shdP_U
      = Exec.Block.spSum P (polyS shdP_U P DS prog pubs) bga recs j
        + (acc.cs.getD j Fp2.zero).toK shdP_U
          * cubeSum (Link.maskPoly (mRowKOf 23 rnd.mA) j (slotN P j) (slotD P j))
  claims_a : ∀ cl ∈ acc.claims.a, ClaimTrue shdP_U (2 ^ 14) 14 TA.rows (toZClaim cl)
  claims_h : ∀ cl ∈ acc.claims.h, ClaimTrue shdP_U (2 ^ 14) 14 TH.rows (toZClaim cl)
  claims_inp : ∀ cl ∈ acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 TB_prev.rows (toZClaim cl)
  claims_out : ∀ cl ∈ acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 TB_next.rows (toZClaim cl)
  fs_ok : ∀ mf ∈ acc.fs ++ acc.hostFs,
    (toMF mf).value.toK shdP_U
      = ∑ s' : Fin 23, ∑ j : Fin 512,
          fwt shdP_U (toMF mf) s' j
            * (mA shdP_U M 23 s').eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j)

/-- Single-slot induction step across all 23 slots (`0..22`): establishes both `SlotSum` and
`BlkAccInv` preservation from `s` to `s + 1`. -/
theorem blk_slot_step (H : HIn → Dig) (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (hxIn : ∀ p, i16 (xIn p)) (hxOut : ∀ p, i16 (xOut p))
    (w : BlkWitness Ly Pb xIn xOut)
    (TB_prev TB_next : Table) (hTB_prev : FullBndTableSpec xIn TB_prev) (hTB_next : FullBndTableSpec xOut TB_next)
    (rnd : BlkRand) (bga : Fp2 × Fp2 × Fp2)
    (hβ : bga.1.Canon) (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (s : ℕ) (hs : s < 23) (recs : List SlotRec) (acc : Acc) (t : Tr) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    let cS := Exec.Block.DefR13.cfgShieldR13 Ly
    let prog := Exec.Block.DefR13.progR13 cS ioIn ioOut
    let pubs := pubsR13L cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG
    let TA := blkTA w rnd
    let TH := blkTH w rnd bga
    let M := blkTM rnd
    let DS := blkCmData P rfl rfl TA TH TB_prev TB_next
    let D := blkSlotData P w TA TB_prev TB_next rnd
    BlkAccInv P DS prog pubs TA TH TB_prev TB_next M rnd bga s recs acc →
      (∀ df, P.define s (Exec.Block.histOf bga.1 bga.2.1 bga.2.2 recs) (t.challengeFp2Vec H (P.draws s)).1 = .ok df →
        SlotSum P shdP_U D s (Exec.Block.histOf bga.1 bga.2.1 bga.2.2 recs) acc df (slotC H P s t))
      ∧ ∀ sp r acc' t',
          slotProve H P D s (Exec.Block.histOf bga.1 bga.2.1 bga.2.2 recs) acc t = .ok (sp, r, acc', t') →
          BlkAccInv P DS prog pubs TA TH TB_prev TB_next M rnd bga (s + 1) (recs ++ [r]) acc' := by
  intro P cS prog pubs TA TH M DS D hinv
  let cs := blkCs TA TH TB_prev TB_next
  let mRow := mRowKOf 23 rnd.mA
  let G : ℕ → shdP_K := fun j => cubeSum (Link.maskPoly mRow j (slotN P j) (slotD P j))
  let hist := Exec.Block.histOf bga.1 bga.2.1 bga.2.2 recs
  obtain ⟨hNpos, hN64, hd1, hd5, hW512⟩ := shdP_blk_slot_bounds tag ioIn ioOut checkOpening Ly Pb s hs
  have hprogOK : Exec.Block.progOKb (Exec.Block.rowLog P) prog P.geom.slots = true :=
    progR13_shield_okP Ly w.hLy P rfl (by show 0 < 14; norm_num) (by show 0 < 14; norm_num) ioIn ioOut
  -- Common `SlotSum` witness for any accepted `df` at `(hist, dr)`
  have hslot_ok : ∀ (dr : List Fp2) (df : SlotDef) (c : Fp2),
      P.define s hist dr = .ok df →
      IndDegLE (slotD P s) (fun z => blkSlotPolyK P cs s df z + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z)
        ∧ (∀ claimed, Exec.Block.hostedSum acc.scalars (D.scalar s hist acc df c) df.hosted = .ok claimed →
            claimed.Canon
              ∧ claimed.toK shdP_U = cubeSum (fun z => blkSlotPolyK P cs s df z
                  + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z)) := by
    intro dr df c hdf
    have hdeg0 := blk_slot_indDeg tag ioIn ioOut checkOpening w TB_prev TB_next rnd bga s hs hist dr df hdf
    have hdegM : IndDegLE (slotD P s)
        (fun z => blkSlotPolyK P cs s df z + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z) :=
      IndDegLE.add_smul hdeg0 (Link.maskPoly_indDeg mRow s (slotN P s) (slotD P s) hd1) _
    refine ⟨hdegM, fun claimed hcl => ?_⟩
    obtain ⟨_, hnonHostNil, hhkSpec⟩ := shdP_blk_hosted_spec tag ioIn ioOut checkOpening Ly Pb s hs hist dr df hdf
    have hscCan : (D.scalar s hist acc df c).Canon := blkSlotData_scalar_canon P w TA TB_prev TB_next rnd s hist acc df c
    cases hk : P.kind s with
    | standalone =>
      have hnil : df.hosted = [] := hnonHostNil (by rw [hk]; decide)
      rw [hnil] at hcl
      simp only [Exec.Block.hostedSum, Except.ok.injEq] at hcl
      subst hcl
      have hcube0 := blk_standalone_cubeSum_eq_zero tag ioIn ioOut checkOpening w TB_prev TB_next rnd bga
        hTB_prev hTB_next hxIn hxOut hα hbad s hs hk hist rfl dr df hdf
      refine ⟨hscCan, ?_⟩
      have hscVal : (D.scalar s hist acc df c).toK shdP_U = c.toK shdP_U * G s := by
        dsimp only [D, blkSlotData, polySlotData]
        rw [hk]
        exact toK_ofK shdP_U shdP_hbij _
      rw [hscVal, cubeSum_add_smul, hcube0, zero_add]
    | priv =>
      have hnil : df.hosted = [] := hnonHostNil (by rw [hk]; decide)
      rw [hnil] at hcl
      simp only [Exec.Block.hostedSum, Except.ok.injEq] at hcl
      subst hcl
      refine ⟨hscCan, ?_⟩
      have hscVal : (D.scalar s hist acc df c).toK shdP_U = cubeSum (blkSlotPolyK P cs s df) + c.toK shdP_U * G s := by
        dsimp only [D, blkSlotData, polySlotData]
        rw [hk]
        exact toK_ofK shdP_U shdP_hbij _
      rw [hscVal, cubeSum_add_smul]
    | host =>
      obtain ⟨hclCan, hclVal⟩ := hostedSum_ok_val acc.scalars df.hosted (D.scalar s hist acc df c) hscCan
        (fun hk' hhk' => ⟨by rw [hinv.sc_len]; exact (hhkSpec hk' hhk').1, (hhkSpec hk' hhk').2.2.2⟩)
        claimed hcl
      refine ⟨hclCan, ?_⟩
      have hscVal : (D.scalar s hist acc df c).toK shdP_U = c.toK shdP_U * G s
          - (df.hosted.map fun hk' => hk'.2.toK shdP_U * (acc.cs.getD hk'.1 Fp2.zero).toK shdP_U * G hk'.1).sum := by
        dsimp only [D, blkSlotData, polySlotData]
        rw [hk]
        exact toK_ofK shdP_U shdP_hbij _
      have hsumSplit :
          (df.hosted.map (fun hk' => hk'.2.toK shdP_U * (acc.scalars.getD hk'.1 Fp2.zero).toK shdP_U)).sum
          = (df.hosted.map (fun hk' => hk'.2.toK shdP_U * Exec.Block.spSum P (polyS shdP_U P DS prog pubs) bga recs hk'.1)).sum
            + (df.hosted.map (fun hk' => hk'.2.toK shdP_U * (acc.cs.getD hk'.1 Fp2.zero).toK shdP_U * G hk'.1)).sum := by
        rw [← list_map_sum_add]
        refine congrArg List.sum (List.map_congr_left (fun hk' hhk' => ?_))
        obtain ⟨hlt, _, hpriv, _⟩ := hhkSpec hk' hhk'
        rw [hinv.priv_ok hk'.1 hlt hpriv]
        ring
      have hhostCube := blk_host_cubeSum_eq_hosted tag ioIn ioOut checkOpening w TB_prev TB_next rnd bga
        hβ hα hbad s hs hk recs hinv.recs_len hinv.recs_def dr df hdf
      rw [hclVal, hscVal, hsumSplit, cubeSum_add_smul, hhostCube]
      dsimp only [G, mRow]
      ring
  refine ⟨?_, ?_⟩
  · -- Part 1: `SlotSum`
    intro df hdf
    obtain ⟨hdegM, hclM⟩ := hslot_ok (t.challengeFp2Vec H (P.draws s)).1 df (slotC H P s t) hdf
    exact ⟨fun z => blkSlotPolyK P cs s df z
        + (slotC H P s t).toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z,
      hdegM,
      honestW_honest shdP_U shdP_hbij (slotD P s) (slotN P s) _,
      hclM,
      fun rho => blkSlotData_terms_length P w TA TB_prev TB_next rnd s hist acc df (slotC H P s t) rho⟩
  · -- Part 2: `BlkAccInv` preservation
    intro sp r acc' t' hprove
    unfold slotProve at hprove
    cases hdf : P.define s hist (t.challengeFp2Vec H (P.draws s)).1 with
    | error _ => rw [hdf] at hprove; cases hprove
    | ok df =>
      rw [hdf] at hprove
      dsimp only at hprove
      by_cases hcZ : (slotC H P s t).isZero = true
      · rw [ite_eq_left hcZ] at hprove; cases hprove
      · rw [ite_eq_right hcZ] at hprove
        by_cases hesZ : ((slotRho H P D s hist acc t df).drop (slotShape P s).1).any
            (fun x => x.isZero || decide (x = Fp2.one)) = true
        · rw [ite_eq_left hesZ] at hprove; cases hprove
        · rw [ite_eq_right hesZ] at hprove
          cases hchk : Exec.Block.slotDefChecks P s acc df with
          | error _ => rw [hchk] at hprove; cases hprove
          | ok _ =>
            rw [hchk] at hprove
            dsimp only at hprove
            cases hhost : Exec.Block.hostedSum acc.scalars (slotSP H P D s hist acc t df).scalar df.hosted with
            | error _ => rw [hhost] at hprove; cases hprove
            | ok claimed =>
              rw [hhost] at hprove
              dsimp only at hprove
              cases htab : Exec.Block.tabVals
                  (Exec.Block.oneMinusProd ((slotRho H P D s hist acc t df).drop (slotShape P s).1))
                  ((slotRho H P D s hist acc t df).take (slotShape P s).1)
                  (slotSP H P D s hist acc t df).terms df.tabs 0 with
              | error _ => rw [htab] at hprove; cases hprove
              | ok vals =>
                rw [htab] at hprove
                dsimp only at hprove
                simp only [Except.ok.injEq, Prod.mk.injEq] at hprove
                obtain ⟨rfl, rfl, rfl, rfl⟩ := hprove
                set c := slotC H P s t
                set sc := (slotSP H P D s hist acc t df).scalar
                set rhoFull := slotRho H P D s hist acc t df
                set fin := scFinalExec (slotSP H P D s hist acc t df).rounds rhoFull claimed
                set gVal := (fin.sub (df.poly vals)).mul c.inv
                set rNew : SlotRec := ⟨(t.challengeFp2Vec H (P.draws s)).1, c, sc, claimed,
                  rhoFull.take (slotShape P s).1, rhoFull.drop (slotShape P s).1,
                  (slotSP H P D s hist acc t df).terms, fin⟩
                obtain ⟨hdegM, hclM⟩ := hslot_ok (t.challengeFp2Vec H (P.draws s)).1 df c hdf
                obtain ⟨hclCan, hclVal⟩ := hclM claimed hhost
                obtain ⟨hhostIff, _, hhkSpec⟩ := shdP_blk_hosted_spec tag ioIn ioOut checkOpening Ly Pb s hs hist _ df hdf
                -- 1. Claims preservation across all 4 tables (`TA`, `TH`, `TB_prev`, `TB_next`)
                let Q : Cm → Exec.Block.ZClaim → Prop
                  | .a, cl => ClaimTrue shdP_U (2 ^ 14) 14 TA.rows (toZClaim cl)
                  | .h, cl => ClaimTrue shdP_U (2 ^ 14) 14 TH.rows (toZClaim cl)
                  | .inp, cl => ClaimTrue shdP_U (2 ^ 14) 14 TB_prev.rows (toZClaim cl)
                  | .out, cl => ClaimTrue shdP_U (2 ^ 14) 14 TB_next.rows (toZClaim cl)
                have hQ : ∀ (cm : Cm) (ps : List Exec.Block.ZPart) (v' : Fp2),
                    v'.toK shdP_U = cs cm ⟨ps, Fp2.zero⟩ → Q cm ⟨ps, v'⟩ := by
                  intro cm ps v' hv'
                  cases cm with
                  | a => exact (claimTrue_iff_claimSem shdP_U 4577 14 TA.rows (blkTA_rows_len w rnd) ⟨ps, v'⟩).mpr hv'
                  | h => exact (claimTrue_iff_claimSem shdP_U 4390 14 TH.rows (blkTH_rows_len w rnd bga) ⟨ps, v'⟩).mpr hv'
                  | inp => exact (claimTrue_iff_claimSem shdP_U 38 14 TB_prev.rows hTB_prev.rows_len ⟨ps, v'⟩).mpr hv'
                  | out => exact (claimTrue_iff_claimSem shdP_U 38 14 TB_next.rows hTB_next.rows_len ⟨ps, v'⟩).mpr hv'
                have hcl' := slotClaims_claimTrue P cs (rhoFull.take (slotShape P s).1)
                  (rhoFull.drop (slotShape P s).1) df.tabs acc.claims Q hQ
                  ⟨hinv.claims_a, hinv.claims_h, hinv.claims_inp, hinv.claims_out⟩
                -- 2. Terminal mask evaluation `gVal.toK = maskPoly mRow s (slotN P s) (slotD P s) (vecK rhoFull)`
                have hcCan : c.Canon := canon_challengeFp2Of _
                have hcNe : c ≠ Fp2.zero := fun h0 => hcZ (by rw [h0]; rfl)
                obtain ⟨fin', hscV, hfin'Val, _⟩ := scVerify_honest shdP_U H shdP_hU hd1
                  (lt_of_le_of_lt hd5 (by norm_num [gP])) (slotN P s)
                  (honestW shdP_U shdP_hbij (slotD P s) (slotN P s) _) _ hdegM
                  (honestW_honest shdP_U shdP_hbij _ _ _) claimed hclCan hclVal (slotT4 H P s t sc)
                have hfinEq : fin' = fin := (scVerify_fin_eq H claimed (slotD P s) (slotN P s) hd1 _ _ fin' _ hscV).1
                have hrhoLen : rhoFull.length = slotN P s := by
                  show (scChal H (scProve H (slotN P s) _ _).1 _).1.length = slotN P s
                  rw [scChal_length]
                  exact scProve_length H _ _ _
                have hrhoCan : ∀ a ∈ rhoFull, a.Canon := scChal_canon H _ _
                have hfinToK : fin.toK shdP_U = (df.poly vals).toK shdP_U
                    + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) (vecK shdP_U (slotN P s) rhoFull) := by
                  rw [← hfinEq, hfin'Val]
                  have hspEq := blkSlotPolyK_vecK_eq P cs s df rhoFull vals hrhoLen hrhoCan htab
                  change blkSlotPolyK P cs s df (vecK shdP_U (slotN P s) rhoFull)
                    + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) (vecK shdP_U (slotN P s) rhoFull) = _
                  rw [hspEq]
                have hpolyCan : (df.poly vals).Canon := defineS_polyC P prog pubs rfl s hist _ df hdf vals
                have hgValToK : gVal.toK shdP_U
                    = Link.maskPoly mRow s (slotN P s) (slotD P s) (vecK shdP_U (slotN P s) rhoFull) :=
                  (Exec.Slot.terminal_iff shdP_U shdP_hU fin (df.poly vals) c
                    (canon_scFinalExec _ _ _ hclCan) hpolyCan hcCan hcNe _).mpr hfinToK
                have hscCan : sc.Canon := blkSlotData_scalar_canon P w TA TB_prev TB_next rnd s hist acc df c
                -- 3. Assemble `BlkAccInv` at `s + 1`
                have hrecsLen := hinv.recs_len
                have hcsLen := hinv.cs_len
                have hscLen := hinv.sc_len
                refine
                  { recs_len := by rw [List.length_append, List.length_singleton, hrecsLen]
                    recs_def := fun j r' hr' => by
                      by_cases hlt : j < s
                      · rw [List.getElem?_append_left (by omega)] at hr'
                        rw [List.take_append_of_le_length (by omega)]
                        exact hinv.recs_def j r' hr'
                      · by_cases heq : j = s
                        · subst heq
                          rw [List.getElem?_append_right (by omega), hrecsLen, Nat.sub_self,
                            List.getElem?_cons_zero, Option.some.injEq] at hr'
                          subst hr'
                          have htake : (recs ++ [rNew]).take j = recs := by
                            rw [← hrecsLen, List.take_append_of_le_length le_rfl, List.take_length]
                          rw [htake]
                          exact ⟨df, hdf, hhostIff⟩
                        · have hgt : (recs ++ [rNew]).length ≤ j := by
                            rw [List.length_append, List.length_singleton, hrecsLen]; omega
                          rw [List.getElem?_eq_none hgt] at hr'
                          cases hr'
                    cs_len := by simp [Exec.Block.slotAcc, hcsLen]
                    cs_canon := fun c' hc' => by
                      simp only [Exec.Block.slotAcc, List.mem_append, List.mem_singleton] at hc'
                      rcases hc' with h1 | rfl
                      · exact hinv.cs_canon c' h1
                      · exact hcCan
                    sc_len := by simp [Exec.Block.slotAcc, hscLen]
                    sc_canon := fun sc' hsc' => by
                      simp only [Exec.Block.slotAcc, List.mem_append, List.mem_singleton] at hsc'
                      rcases hsc' with h1 | rfl
                      · exact hinv.sc_canon sc' h1
                      · exact hscCan
                    priv_ok := fun j hj hkj => by
                      by_cases hlt : j < s
                      · simp only [Exec.Block.slotAcc, List.getD_eq_getElem?_getD]
                        rw [List.getElem?_append_left (by omega), List.getElem?_append_left (by omega)]
                        simp only [← List.getD_eq_getElem?_getD]
                        unfold Exec.Block.spSum
                        rw [seenOf_append_lt bga recs rNew j (by omega)]
                        exact hinv.priv_ok j hlt hkj
                      · have hjs : j = s := by omega
                        subst hjs
                        simp only [Exec.Block.slotAcc, List.getD_eq_getElem?_getD]
                        rw [List.getElem?_append_right (by omega), hscLen, Nat.sub_self,
                          List.getElem?_cons_zero, Option.getD_some,
                          List.getElem?_append_right (by omega), hcsLen, Nat.sub_self,
                          List.getElem?_cons_zero, Option.getD_some]
                        have hscPriv : sc.toK shdP_U = cubeSum (blkSlotPolyK P cs j df) + c.toK shdP_U * G j := by
                          dsimp only [sc, slotSP, D, blkSlotData, polySlotData]
                          rw [hkj]
                          exact toK_ofK shdP_U shdP_hbij _
                        have hrsAt : (recs ++ [rNew])[j]? = some rNew := by
                          rw [List.getElem?_append_right (by omega), hrecsLen, Nat.sub_self]; rfl
                        have hrsTake : (recs ++ [rNew]).take j = recs := by
                          rw [← hrecsLen, List.take_append_of_le_length le_rfl, List.take_length]
                        have hpolyEq : blkSlotPolyK P cs j df
                            = polyS shdP_U P DS prog pubs j (Exec.Block.seenOf bga (recs ++ [rNew]) j) := by
                          funext x
                          refine blkSlotPolyK_eq_polyS P DS cs (blkCs_eq_claimSem P rfl rfl _ _ _ _) prog pubs rfl hprogOK
                            j (Exec.Block.seenOf bga (recs ++ [rNew]) j) df ?_
                            (shdP_blk_tabsLenOk tag ioIn ioOut checkOpening Ly Pb j hs hist _ df hdf) x
                          rw [Exec.Block.histSeen_seenOf, hrsTake, Exec.Block.drSeen_seenOf bga (recs ++ [rNew]) j rNew hrsAt]
                          exact hdf
                        rw [hscPriv, hpolyEq]
                        rfl
                    claims_a := hcl'.1
                    claims_h := hcl'.2.1
                    claims_inp := hcl'.2.2.1
                    claims_out := hcl'.2.2.2
                    fs_ok := fun mf hmf => by
                      have heval_ok : (toMF ⟨[(s, Cfs.evalWeights rhoFull (slotD P s))], gVal⟩).value.toK shdP_U
                          = ∑ s' : Fin 23, ∑ j : Fin 512,
                              fwt shdP_U (toMF ⟨[(s, Cfs.evalWeights rhoFull (slotD P s))], gVal⟩) s' j
                                * (mA shdP_U M 23 s').eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j) := by
                        unfold M blkTM
                        rw [mTrue_singleton_mdot 23 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts s hs _ _,
                          mTrue_evalWeights_eq 23 rnd.mA s (slotN P s) (slotD P s) hNpos rhoFull hrhoLen hW512]
                        exact hgValToK
                      cases hk : P.kind s with
                      | standalone =>
                        simp only [Exec.Block.slotAcc, hk, List.mem_append, List.mem_singleton] at hmf
                        rcases hmf with ((hold | rfl) | rfl) | hhostOld
                        · exact hinv.fs_ok mf (List.mem_append_left _ hold)
                        · unfold M blkTM
                          rw [mTrue_singleton_mdot 23 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts s hs _ _]
                          have hscSa : (toMF ⟨[(s, (Cfs.sumWeights ((slotShape P s).1 + (slotShape P s).2.1)
                              (slotShape P s).2.2).map (fun w' => w'.mul c))], sc⟩).value.toK shdP_U
                              = c.toK shdP_U * cubeSum (Link.maskPoly (mRowKOf 23 rnd.mA) s (slotN P s) (slotD P s)) := by
                            dsimp only [sc, slotSP, D, blkSlotData, polySlotData, toMF]
                            rw [hk]
                            exact toK_ofK shdP_U shdP_hbij _
                          exact hscSa.trans (mTrue_sumWeights_eq 23 rnd.mA s (slotN P s) (slotD P s) hNpos hN64 hW512 c).symm
                        · exact heval_ok
                        · exact hinv.fs_ok mf (List.mem_append_right _ hhostOld)
                      | priv =>
                        simp only [Exec.Block.slotAcc, hk, List.mem_append, List.mem_singleton] at hmf
                        rcases hmf with (hold | rfl) | hhostOld
                        · exact hinv.fs_ok mf (List.mem_append_left _ hold)
                        · exact heval_ok
                        · exact hinv.fs_ok mf (List.mem_append_right _ hhostOld)
                      | host =>
                        simp only [Exec.Block.slotAcc, hk, List.mem_append, List.mem_singleton] at hmf
                        rcases hmf with (hold | rfl) | (hhostOld | rfl)
                        · exact hinv.fs_ok mf (List.mem_append_left _ hold)
                        · exact heval_ok
                        · exact hinv.fs_ok mf (List.mem_append_right _ hhostOld)
                        · unfold M blkTM
                          rw [mTrue_terms_mdot 23 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts _ _
                            (by
                              intro tm htm
                              rcases List.mem_cons.mp htm with rfl | htm
                              · exact hs
                              · obtain ⟨hk', hhk', rfl⟩ := List.mem_map.mp htm
                                exact (hhkSpec hk' hhk').2.1)]
                          rw [List.map_cons, List.sum_cons, List.map_map]
                          have hhead : Exec.Block.mdot shdP_U (mRowKOf 23 rnd.mA) 512
                              (s, (Cfs.sumWeights ((slotShape P s).1 + (slotShape P s).2.1)
                                (slotShape P s).2.2).map (fun w' => w'.mul c))
                              = c.toK shdP_U * G s :=
                            mTrue_sumWeights_eq 23 rnd.mA s (slotN P s) (slotD P s) hNpos hN64 hW512 c
                          have hmap : List.map (Exec.Block.mdot shdP_U (mRowKOf 23 rnd.mA) 512 ∘ fun hk' =>
                                (hk'.1, (Cfs.sumWeights ((slotShape P hk'.1).1 + (slotShape P hk'.1).2.1)
                                  (slotShape P hk'.1).2.2).map (fun w' => w'.mul (hk'.2.mul (acc.cs.getD hk'.1 Fp2.zero)).neg)))
                                df.hosted
                              = List.map (fun hk' => -(hk'.2.toK shdP_U * (acc.cs.getD hk'.1 Fp2.zero).toK shdP_U * G hk'.1))
                                  df.hosted := by
                            refine List.map_congr_left (fun hk' hhk' => ?_)
                            have h23' := (hhkSpec hk' hhk').2.1
                            obtain ⟨hNpos', hN64', _, _, hW512'⟩ := shdP_blk_slot_bounds tag ioIn ioOut checkOpening Ly Pb hk'.1 h23'
                            have hsw : Exec.Block.mdot shdP_U (mRowKOf 23 rnd.mA) 512
                                (hk'.1, (Cfs.sumWeights ((slotShape P hk'.1).1 + (slotShape P hk'.1).2.1)
                                  (slotShape P hk'.1).2.2).map (fun w' => w'.mul (hk'.2.mul (acc.cs.getD hk'.1 Fp2.zero)).neg))
                                = (hk'.2.mul (acc.cs.getD hk'.1 Fp2.zero)).neg.toK shdP_U * G hk'.1 :=
                              mTrue_sumWeights_eq 23 rnd.mA hk'.1 (slotN P hk'.1) (slotD P hk'.1) hNpos' hN64' hW512' _
                            dsimp only [Function.comp_apply]
                            rw [hsw, Fp2.toK_neg shdP_U _ (Fp2.canon_mul _ _), Fp2.toK_mul shdP_U shdP_hU]
                            ring
                          rw [hhead, hmap, list_map_sum_neg, ← sub_eq_add_neg]
                          dsimp only [sc, slotSP, D, blkSlotData, polySlotData, toMF]
                          rw [hk]
                          exact toK_ofK shdP_U shdP_hbij _ }

/-- Abstract-`m` induction over `slotsProve` (`s + m ≤ 23`), never unrolling concrete `23` in `whnf`. -/
theorem shdP_blk_slots_ok (H : HIn → Dig) (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (hxIn : ∀ p, i16 (xIn p)) (hxOut : ∀ p, i16 (xOut p))
    (w : BlkWitness Ly Pb xIn xOut)
    (TB_prev TB_next : Table) (hTB_prev : FullBndTableSpec xIn TB_prev) (hTB_next : FullBndTableSpec xOut TB_next)
    (rnd : BlkRand) (bga : Fp2 × Fp2 × Fp2)
    (hβ : bga.1.Canon) (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    let cS := Exec.Block.DefR13.cfgShieldR13 Ly
    let prog := Exec.Block.DefR13.progR13 cS ioIn ioOut
    let pubs := pubsR13L cS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG
    let TA := blkTA w rnd
    let TH := blkTH w rnd bga
    let M := blkTM rnd
    let DS := blkCmData P rfl rfl TA TH TB_prev TB_next
    let D := blkSlotData P w TA TB_prev TB_next rnd
    ∀ (m s : ℕ), s + m ≤ 23 →
      ∀ (recs : List SlotRec) (acc : Acc) (t : Tr),
        BlkAccInv P DS prog pubs TA TH TB_prev TB_next M rnd bga s recs acc →
          SlotsSum H P shdP_U D bga.1 bga.2.1 bga.2.2 m recs s acc t
          ∧ ∀ sps recs' acc' t',
              slotsProve H P D bga.1 bga.2.1 bga.2.2 m recs s acc t = .ok (sps, recs', acc', t') →
              BlkAccInv P DS prog pubs TA TH TB_prev TB_next M rnd bga (s + m) recs' acc' := by
  intro P cS prog pubs TA TH M DS D m
  induction m with
  | zero =>
    intro s _ recs acc t hinv
    refine ⟨trivial, fun sps recs' acc' t' h => ?_⟩
    simp only [slotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨_, rfl, rfl, _⟩ := h
    simpa only [Nat.add_zero] using hinv
  | succ m' ih =>
    intro s hsm recs acc t hinv
    have hstep := blk_slot_step H tag ioIn ioOut checkOpening hxIn hxOut w TB_prev TB_next hTB_prev hTB_next
      rnd bga hβ hα hbad s (by omega) recs acc t hinv
    refine ⟨⟨hstep.1, fun sp r acc₁ t₁ hsp =>
        (ih (s + 1) (by omega) (recs ++ [r]) acc₁ t₁ (hstep.2 sp r acc₁ t₁ hsp)).1⟩,
      fun sps recs' acc' t' h => ?_⟩
    simp only [slotsProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨_, rfl, rfl, _⟩ := h
        have hres := (ih (s + 1) (by omega) (recs ++ [r]) acc₁ t₁ (hstep.2 sp r acc₁ t₁ hsp)).2
          sps₁ recs₁ acc₂ t₂ hrest
        rwa [show s + 1 + m' = s + (m' + 1) by omega] at hres

end BlockSlotLoop

/-! ## 4. Main Block Arithmetic Theorem (`shdP_blk_arith`) -/

section BlockArithMain

/-- **Main Shieldstral R13 block arithmetic theorem**: for any `P = shdP_blkParams ... Ly Pb`,
valid witness `w : BlkWitness Ly Pb xIn xOut`, honest boundary tables `(TB_prev, TB_next)`,
and accepting `coreProve` / `bndCheck` / `blkAlphaBad = false`:
1. Discharges ALL 23 conjuncts of `hArith`; AND
2. Proves `ClaimTrue` on every outgoing claim `cl ∈ R.acc.claims.out` against `TB_next`! -/
theorem shdP_blk_arith (H : HIn → Dig) (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (P : BlockParams) (hP : P = shdP_blkParams tag ioIn ioOut checkOpening Ly Pb)
    (xIn xOut : shieldS0.Pos → ℤ) (hxIn : ∀ p, i16 (xIn p)) (hxOut : ∀ p, i16 (xOut p))
    (w : BlkWitness Ly Pb xIn xOut)
    (TB_prev TB_next : Table) (hTB_prev : FullBndTableSpec xIn TB_prev) (hTB_next : FullBndTableSpec xOut TB_next)
    (rnd : BlkRand)
    (bndCheckK : List Exec.Block.ZClaim → Tr → Except String Unit)
    (cr : Carry) (tFrame : Tr) (R : CoreRun)
    (hR : let ct := blkCoreTables P w TB_prev TB_next rnd
      coreProve H P (coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P ct tFrame) tFrame = .ok R)
    (hbc : bndCheckK (cr.pending ++ R.acc.claims.inp) R.t7 = .ok ())
    (hbad : let ct := blkCoreTables P w TB_prev TB_next rnd
      let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P ct tFrame
      blkAlphaBad Ly Pb ((coreB H P D tFrame).1, (coreG H P D tFrame).1, (coreA H P D tFrame).1) = false)
    (hgrpA : ∀ cl t, checkOpening H .a cl t = .ok () → (groupZclaims (cl.map toZClaim) 4577 14).length = 36)
    (hgrpH : ∀ cl t, checkOpening H .h cl t = .ok () → (groupZclaims (cl.map toZClaim) 4390 14).length = 9)
    (hgrpB : ∀ cl t, bndCheckK cl t = .ok () → (groupZclaims (cl.map toZClaim) 38 14).length = 2) :
    let ct := blkCoreTables P w TB_prev TB_next rnd
    let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P ct tFrame
    let bga := ((coreB H P D tFrame).1, (coreG H P D tFrame).1, (coreA H P D tFrame).1)
    let TH := ct.TH bga.1 bga.2.1 bga.2.2
    ((∀ s hist acc df ch0, (ct.slot.scalar s hist acc df ch0).Canon)
      ∧ (∀ s hist acc df ch0 rho, ∀ w' ∈ ct.slot.terms s hist acc df ch0 rho, w'.Canon)
      ∧ (∀ j, ∀ w' ∈ ct.TA.cols j, w'.Canon)
      ∧ (∀ j, ∀ w' ∈ TH.cols j, w'.Canon)
      ∧ (∀ j, ∀ w' ∈ TB_prev.cols j, w'.Canon)
      ∧ (∀ j, (ct.TA.cols j).length = ct.TA.rows.length)
      ∧ (∀ j, (TH.cols j).length = TH.rows.length)
      ∧ (∀ j, (TB_prev.cols j).length = TB_prev.rows.length)
      ∧ (groupZclaims (R.acc.claims.a.map toZClaim) ct.TA.rows.length 14).length = 36
      ∧ (groupZclaims ((R.acc.claims.h ++ [P.logupSumClaim]).map toZClaim) TH.rows.length 14).length = 9
      ∧ (groupZclaims ((cr.pending ++ R.acc.claims.inp).map toZClaim) TB_prev.rows.length 14).length = 2
      ∧ SlotsSum H P shdP_U ct.slot bga.1 bga.2.1 bga.2.2 23 [] 0 {} (coreT3 H P D tFrame)
      ∧ MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) ct.M 23
      ∧ (∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
          (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
            = mTrue (algebraMap GF shdP_K (rootFp 9).toGF)
                (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 23) (mA shdP_U ct.M 23) i)
      ∧ 4577 = ct.TA.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) ct.TA
      ∧ (∀ cl ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 14) 14 ct.TA.rows (toZClaim cl))
      ∧ 4390 = TH.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) TH
      ∧ (∀ cl ∈ R.acc.claims.h ++ [P.logupSumClaim], ClaimTrue shdP_U (2 ^ 14) 14 TH.rows (toZClaim cl))
      ∧ 38 = TB_prev.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) TB_prev
      ∧ (∀ cl ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 TB_prev.rows (toZClaim cl)))
    ∧ (∀ cl ∈ R.acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 TB_next.rows (toZClaim cl)) := by
  subst hP
  set P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
  intro ct D bga TH
  obtain ⟨hslotsP, -, hcA, hcH, -, -, -, -, -, -, -⟩ := coreProve_ok H P D tFrame R hR
  have hβ : bga.1.Canon := canon_challengeFp2Of _
  have hα : bga.2.2.Canon := canon_challengeFp2Of _
  have hinv0 : BlkAccInv P (blkCmData P rfl rfl (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next)
      (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut)
      (pubsR13L (Exec.Block.DefR13.cfgShieldR13 Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG)
      (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next (blkTM rnd) rnd bga 0 [] {} :=
    { recs_len := rfl
      recs_def := fun _ _ h => by cases h
      cs_len := rfl
      cs_canon := fun _ h => by cases h
      sc_len := rfl
      sc_canon := fun _ h => by cases h
      priv_ok := fun _ hj _ => by omega
      claims_a := fun _ h => by cases h
      claims_h := fun _ h => by cases h
      claims_inp := fun _ h => by cases h
      claims_out := fun _ h => by cases h
      fs_ok := fun _ h => by cases h }
  have hsl := shdP_blk_slots_ok H tag ioIn ioOut checkOpening hxIn hxOut w TB_prev TB_next hTB_prev hTB_next
    rnd bga hβ hα hbad 23 0 (by norm_num) [] {} (coreT3 H P D tFrame) hinv0
  have hlen23 : P.geom.slots.length = 23 := rfl
  rw [hlen23] at hslotsP
  have hinv23 := hsl.2 R.core.slots R.recs R.acc R.t4 hslotsP
  refine ⟨⟨blkSlotData_scalar_canon P w (blkTA w rnd) TB_prev TB_next rnd,
      blkSlotData_terms_canon P w (blkTA w rnd) TB_prev TB_next rnd,
      blkTA_cols_canon w rnd,
      blkTH_cols_canon w rnd bga,
      hTB_prev.cols_canon,
      blkTA_cols_len w rnd,
      blkTH_cols_len w rnd bga,
      fun j => (hTB_prev.cols_len j).trans hTB_prev.rows_len.symm,
      by rw [show ct.TA.rows.length = 4577 from blkTA_rows_len w rnd]; exact hgrpA R.acc.claims.a R.t5 hcA,
      by rw [show TH.rows.length = 4390 from blkTH_rows_len w rnd bga]; exact hgrpH (R.acc.claims.h ++ [P.logupSumClaim]) R.t6 hcH,
      by rw [hTB_prev.rows_len]; exact hgrpB (cr.pending ++ R.acc.claims.inp) R.t7 hbc,
      hsl.1,
      blkTM_honest rnd,
      ?_,
      (blkTA_rows_len w rnd).symm,
      blkTA_colsHonest w rnd,
      hinv23.claims_a,
      (blkTH_rows_len w rnd bga).symm,
      blkTH_colsHonest w rnd bga,
      ?_,
      hTB_prev.rows_len.symm,
      hTB_prev.cols_honest,
      hinv23.claims_inp⟩,
    hinv23.claims_out⟩
  · intro i
    have hmem := List.getElem_mem (l := R.acc.fs ++ R.acc.hostFs) (n := i.val) (by simpa using i.isLt)
    have hget : ((R.acc.fs ++ R.acc.hostFs).map toMF).get i
        = toMF ((R.acc.fs ++ R.acc.hostFs)[i.val]'(by simpa using i.isLt)) := by
      rw [List.get_eq_getElem, List.getElem_map]
    unfold mTrue wtOf
    rw [hget]
    exact hinv23.fs_ok _ hmem
  · intro cl hcl
    rcases List.mem_append.mp hcl with h1 | h2
    · exact hinv23.claims_h cl h1
    · rw [List.mem_singleton.mp h2]
      exact blk_logupSumClaim_true w rnd bga

end BlockArithMain

/-! ## 5. Guarded Block `SegComplete` Bridge & Top-Level `hsegBlk` Discharge (`k < 26`) -/

section TopLevelBlockComplete

open Classical in
/-- Guarded counterpart of `HonestShieldBlockBase.shdP_blk_segComplete` for `shdP_blkSegP_guarded`,
supplying `blkAlphaBad Ly Pb bga = false` directly to `hArith`. -/
theorem shdP_blk_segComplete_guarded {Γ Hdr Coins : Type} (tag : MTag)
    (check : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (adm : (shieldS0.Tok → ℕ) → Prop) (hOf : Γ → HIn → Dig)
    (stOf : Γ → (shieldS0.Tok → ℕ) → Coins → ClsStmt Hdr)
    (Pk : ℕ → BlockParams)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (k : ℕ) (hk : k < 26)
    (hgeom50 : (Pk k).geom = shdP_blkGeom50)
    (hPm : (Pk k).maskVerify = maskField tag 23)
    (hPp : (Pk k).pcsVerify = Exec.R13.pcsFieldR13 tag shdP_rowsOf)
    (hdA : (Pk k).aPath = 16) (hdH : (Pk k).hPath = 16) (hdM : (Pk k).maskPath = 12)
    (hpre : (Pk k).preChecks = .ok ())
    (W : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → (k' : ℕ) → ShdBlkTables Pk k')
    (hCheck : ∀ g x c, adm x → check (stOf g x c) k = .ok ())
    (hArith : ∀ g x c (cr : Carry) t R, adm x →
      let H := hOf g
      let st := stOf g x c
      let w := W H st x c k
      let bRoot := rootOf H tag 16 w.TB_next
      let tFrame := blockFrame (d12aBlockProf Pk (shdP_sgeom Hdr Pk) check shdP_segPaths digest
        (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38)) H st k bRoot t
      let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (Pk k) w.coreT tFrame
      let bga := ((coreB H (Pk k) D tFrame).1, (coreG H (Pk k) D tFrame).1, (coreA H (Pk k) D tFrame).1)
      let TH := w.coreT.TH bga.1 bga.2.1 bga.2.2
      coreProve H (Pk k) D tFrame = .ok R →
      bndCheck st k (cr.pending ++ R.acc.claims.inp) R.t7 = .ok () →
      blkAlphaBad Ly Pb bga = false →
      (∀ s hist acc df ch0, (w.coreT.slot.scalar s hist acc df ch0).Canon)
      ∧ (∀ s hist acc df ch0 rho, ∀ w' ∈ w.coreT.slot.terms s hist acc df ch0 rho, w'.Canon)
      ∧ (∀ j, ∀ w' ∈ w.coreT.TA.cols j, w'.Canon)
      ∧ (∀ j, ∀ w' ∈ TH.cols j, w'.Canon)
      ∧ (∀ j, ∀ w' ∈ w.TB_prev.cols j, w'.Canon)
      ∧ (∀ j, (w.coreT.TA.cols j).length = w.coreT.TA.rows.length)
      ∧ (∀ j, (TH.cols j).length = TH.rows.length)
      ∧ (∀ j, (w.TB_prev.cols j).length = w.TB_prev.rows.length)
      ∧ (groupZclaims (R.acc.claims.a.map toZClaim) w.coreT.TA.rows.length 14).length = 36
      ∧ (groupZclaims ((R.acc.claims.h ++ [(Pk k).logupSumClaim]).map toZClaim) TH.rows.length 14).length = 9
      ∧ (groupZclaims ((cr.pending ++ R.acc.claims.inp).map toZClaim) w.TB_prev.rows.length 14).length = 2
      ∧ SlotsSum H (Pk k) shdP_U w.coreT.slot bga.1 bga.2.1 bga.2.2 23 [] 0 {} (coreT3 H (Pk k) D tFrame)
      ∧ MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) w.coreT.M 23
      ∧ (∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
          (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
            = mTrue (algebraMap GF shdP_K (rootFp 9).toGF)
                (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 23) (mA shdP_U w.coreT.M 23) i)
      ∧ 4577 = w.coreT.TA.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) w.coreT.TA
      ∧ (∀ cl ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 14) 14 w.coreT.TA.rows (toZClaim cl))
      ∧ 4390 = TH.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) TH
      ∧ (∀ cl ∈ R.acc.claims.h ++ [(Pk k).logupSumClaim], ClaimTrue shdP_U (2 ^ 14) 14 TH.rows (toZClaim cl))
      ∧ 38 = w.TB_prev.rows.length
      ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) w.TB_prev
      ∧ (∀ cl ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 w.TB_prev.rows (toZClaim cl))) :
    SegComplete adm hOf stOf
      (shdP_blkSegP_guarded tag Pk (shdP_sgeom Hdr Pk) check shdP_segPaths digest
        (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38) Ly Pb W k)
      (blockSeg (d12aBlockProf Pk (shdP_sgeom Hdr Pk) check shdP_segPaths digest
        (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38)) k) := by
  let prof := d12aBlockProf Pk (shdP_sgeom Hdr Pk) check shdP_segPaths digest
    (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38)
  intro g x c bnd cr t enc cr' t' hx hrunG
  let H := hOf g
  let st := stOf g x c
  let w := W H st x c k
  let bRoot := rootOf H tag 16 w.TB_next
  let tFrame := blockFrame prof H st k bRoot t
  let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (Pk k) w.coreT tFrame
  let bga := ((coreB H (Pk k) D tFrame).1, (coreG H (Pk k) D tFrame).1, (coreA H (Pk k) D tFrame).1)
  let TH := w.coreT.TH bga.1 bga.2.1 bga.2.2
  obtain ⟨hbad, hrun⟩ := shdP_blkSegP_guarded_run_ok tag Pk (shdP_sgeom Hdr Pk) check shdP_segPaths digest
    (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38) Ly Pb W k H st x c bnd (posTag H t) cr t
    (enc, cr', t') hrunG
  dsimp only [shdP_blkSegP] at hrun
  split_ifs at hrun with hown
  obtain ⟨hcrRoot, hcrPend⟩ := of_decide_eq_true hown
  cases hR' : coreProve H (Pk k) D tFrame with
  | error _ => rw [hR'] at hrun; cases hrun
  | ok R =>
    rw [hR'] at hrun
    dsimp only at hrun
    cases hbc : bndCheck (stOf g x c) k (cr.pending ++ R.acc.claims.inp) R.t7 with
    | error _ => rw [hbc] at hrun; cases hrun
    | ok _ =>
      rw [hbc] at hrun
      dsimp only at hrun
      simp only [Except.ok.injEq, Prod.mk.injEq] at hrun
      obtain ⟨rfl, rfl, rfl⟩ := hrun
      have hbad' : blkAlphaBad Ly Pb bga = false :=
        (congrArg (blkAlphaBad Ly Pb)
          (bgaOf_core H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (Pk k) w.coreT tFrame)).symm.trans hbad
      obtain ⟨hSc, hTm, hcanA, hcanH, hcanB, hlenA, hlenH, hlenB,
        hgA, hgH, hgB, hslots, hMh, hMt, hrA, hcA, htA, hrH, hcH, htH, hrB, hcB, htB_inp⟩ :=
        hArith g x c cr t R hx hR' hbc hbad'
      obtain ⟨hs, -, -, -, -, -, -, -, hmo, hao, hho⟩ := coreProve_ok H (Pk k) D tFrame R hR'
      have hm1 : R.core.maskOpen = (bMask H tag shdP_U shdP_hbij w.coreT.M 23 (R.acc.fs ++ R.acc.hostFs) R.t4).1 :=
        congrArg Prod.fst hmo
      have ha1 : R.core.aOpen = (bOpen H tag Exec.R13.r13Prm 16 w.coreT.TA R.acc.claims.a R.t5).1 :=
        congrArg Prod.fst hao
      have hho' : (R.core.hOpen, R.t7) = bOpen H tag Exec.R13.r13Prm 16 TH (R.acc.claims.h ++ [(Pk k).logupSumClaim]) R.t6 := by
        dsimp only [D, coreDataAt] at hho; exact hho
      have hh1 : R.core.hOpen = (bOpen H tag Exec.R13.r13Prm 16 TH (R.acc.claims.h ++ [(Pk k).logupSumClaim]) R.t6).1 :=
        congrArg Prod.fst hho'
      let io := HonestOpen.bOpen H tag Exec.R13.r13Prm 16 w.TB_prev (cr.pending ++ R.acc.claims.inp) R.t7
      have hnn : Exec.R13.r13Prm.nn = 2 ^ 16 := by norm_num [Exec.R13.r13Prm, PcsPrm.nn]
      have hslen23 : (Pk k).geom.slots.length = 23 := by rw [hgeom50]; decide
      have hdeg : ∀ s, s < (Pk k).geom.slots.length → 1 ≤ slotD (Pk k) s ∧ slotD (Pk k) s < gP := by
        intro s hs'
        rw [hslen23] at hs'
        obtain ⟨h1, h5, -, -⟩ := Exec.Block.R13.shield_slot_facts s hs'
        change 1 ≤ ((Pk k).geom.slots.getD s (0, 0, 0)).2.2 ∧ ((Pk k).geom.slots.getD s (0, 0, 0)).2.2 < gP
        rw [hgeom50]
        exact ⟨h1, lt_of_le_of_lt h5 (by norm_num [gP])⟩
      have hslots' : SlotsSum H (Pk k) shdP_U w.coreT.slot bga.1 bga.2.1 bga.2.2
          (Pk k).geom.slots.length [] 0 {} (coreT3 H (Pk k) D tFrame) := by
        rw [hslen23]; exact hslots
      have hbv := shdP_blockVerify_of_tables_r13 H tag (Pk k) 23 shdP_rowsOf
        hPm hPp hdA hdH hdM w.coreT tFrame R hR' hdeg hpre hslots' hMh hMt hrA hcA htA hrH hcH htH
      have hsgEq : shdP_sgeom Hdr Pk st k = Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k + 1) 38 2 := by
        unfold shdP_sgeom; rw [hgeom50]
      obtain ⟨hgt, hdom, henc, hee, hcm, hcl, -, hceil⟩ := shdP_sgeom50_facts k hk
      obtain ⟨hslLen, hslCan, hslSh⟩ := slotsProve_shape_canon H (Pk k) shdP_U w.coreT.slot
        bga.1 bga.2.1 bga.2.2 hSc hTm (Pk k).geom.slots.length [] 0 {} (coreT3 H (Pk k) D tFrame)
        R.core.slots R.recs R.acc R.t4 hslots' hs
      have hnQ : 0 < Exec.R13.r13Prm.nQ := by norm_num [Exec.R13.r13Prm]
      have hcan : CoreCanon R.core := by
        refine ⟨hslCan, ?_, ?_, ?_⟩
        · rw [hm1]; exact bMask_canon H tag shdP_U shdP_hbij w.coreT.M 23 _ _
        · rw [ha1]; exact bOpen_canon H tag Exec.R13.r13Prm 16 hnn hnQ w.coreT.TA hcanA _ _
        · rw [hh1]; exact bOpen_canon H tag Exec.R13.r13Prm 16 hnn hnQ TH hcanH _ _
      have hmSh := bMask_shape H tag shdP_U shdP_hbij w.coreT.M 23 (R.acc.fs ++ R.acc.hostFs) R.t4
      have haSh := bOpen_shape H tag Exec.R13.r13Prm 16 hnn hnQ w.coreT.TA hlenA R.acc.claims.a R.t5
      have hhSh := bOpen_shape H tag Exec.R13.r13Prm 16 hnn hnQ TH hlenH (R.acc.claims.h ++ [(Pk k).logupSumClaim]) R.t6
      have hbSh := bOpen_shape H tag Exec.R13.r13Prm 16 hnn hnQ w.TB_prev hlenB (cr.pending ++ R.acc.claims.inp) R.t7
      have hsh : CoreShape (shdP_sgeom Hdr Pk st k).g R.core := by
        rw [hsgEq]
        refine ⟨by rw [hslLen, hslen23]; rfl, fun i p s t' hp hs' ht' =>
            hslSh i p s t' hp (by rw [Nat.zero_add, hgeom50]; exact hs') (by rw [Nat.zero_add, hgeom50]; exact ht'),
          ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
        · rw [hm1]; exact hmSh.1
        · rw [hm1]; exact hmSh.2.1
        · rw [hm1]; exact hmSh.2.2.1
        · rw [hm1]; exact hmSh.2.2.2
        · intro o ho
          simp only [List.mem_cons, List.not_mem_nil, or_false] at ho
          rcases ho with rfl | rfl
          · rw [ha1]
            exact ⟨haSh.2.2.1, haSh.2.1, haSh.2.2.2.1,
              fun col hcol => ⟨(haSh.2.2.2.2 col hcol).1, (haSh.2.2.2.2 col hcol).2.2⟩⟩
          · rw [hh1]
            exact ⟨hhSh.2.2.1, hhSh.2.1, hhSh.2.2.2.1,
              fun col hcol => ⟨(hhSh.2.2.2.2 col hcol).1, (hhSh.2.2.2.2 col hcol).2.2⟩⟩
        · rw [ha1, haSh.1, show Exec.R13.r13Prm.logCols = 14 from rfl, hgA]; rfl
        · rw [hh1, hhSh.1, show Exec.R13.r13Prm.logCols = 14 from rfl, hgH]; rfl
        · intro col hcol; rw [ha1] at hcol
          exact (haSh.2.2.2.2 col hcol).2.1.trans hrA.symm
        · intro col hcol; rw [hh1] at hcol
          exact (hhSh.2.2.2.2 col hcol).2.1.trans hrH.symm
      have hic : HidingCanon io.1 := bOpen_canon H tag Exec.R13.r13Prm 16 hnn hnQ w.TB_prev hcanB _ _
      have his : HidingShape (shdP_sgeom Hdr Pk st k).ed (shdP_sgeom Hdr Pk st k).incoming.1
          (shdP_sgeom Hdr Pk st k).incoming.2 io.1 := by
        rw [hsgEq]
        refine ⟨hbSh.1.trans hgB, hbSh.2.1, hbSh.2.2.1, hbSh.2.2.2.1, fun col hcol => ?_⟩
        obtain ⟨hj, hclen, hcp⟩ := hbSh.2.2.2.2 col hcol
        exact ⟨hj, hclen.trans hrB.symm, hcp⟩
      have hdec : decodeSegment (shdP_sgeom Hdr Pk st k) bnd (posTag H t)
            (encSeg bnd (shdP_sgeom Hdr Pk st k).l (shdP_sgeom Hdr Pk st k).k (posTag H t)
              ⟨some bRoot, R.core, io.1, none⟩ (posTag H io.2))
          = .ok (⟨some bRoot, R.core, io.1, none⟩, posTag H io.2) :=
        d12a_codec_of_enc (shdP_sgeom Hdr Pk st k) (by rw [hsgEq]; exact hgt)
          (by rw [hsgEq]; exact hdom) (by rw [hsgEq]; exact henc) (by rw [hsgEq]; exact hee)
          bnd bRoot R.core io.1 hcan hsh (by rw [hsgEq]; exact hcm) hic his (by rw [hsgEq]; exact hcl)
          (fun start e => encSeg_length (shdP_sgeom Hdr Pk st k) (by rw [hsgEq]; exact hgt) bnd start
            ⟨some bRoot, R.core, io.1, none⟩ e hsh (by rw [hsgEq, hcm]; rfl) his (by rw [hsgEq]; exact hcl) rfl)
          (by rw [hsgEq]; exact hceil) (posTag H t) (posTag H io.2)
      have hpaths : shdP_segPaths st ⟨some bRoot, R.core, io.1, none⟩ = .ok () :=
        shdP_segPaths_ok st _
          (by rw [ha1]; exact bOpen_pathsDepth H tag "A" Exec.R13.r13Prm 16 hnn hnQ w.coreT.TA _ _ 0)
          (by rw [hh1]; exact bOpen_pathsDepth H tag "H" Exec.R13.r13Prm 16 hnn hnQ TH _ _ 0)
          (by rw [hm1]; exact bMask_pathsDepth H tag shdP_U shdP_hbij "M" w.coreT.M 23 _ _ 0)
          (bOpen_pathsDepth H tag "B" Exec.R13.r13Prm 16 hnn hnQ w.TB_prev _ _ 0)
      have hcb : cbBndOpen tag 38 H st k cr.root (cr.pending ++ R.acc.claims.inp) io.1 R.t7 = .ok io.2 := by
        unfold cbBndOpen
        have htAll : ∀ cl ∈ cr.pending ++ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 w.TB_prev.rows (toZClaim cl) := by
          intro cl hcl
          rcases List.mem_append.mp hcl with h1 | h2
          · exact hcrPend cl h1
          · exact htB_inp cl h2
        rw [hcrRoot, hrB]
        exact pcsAt_of_prove H tag shdP_U shdP_hU 14 2 256 (by norm_num) (by norm_num) w.TB_prev
          (by simpa only [show (2 : ℕ) ^ 14 * 2 ^ 2 = 2 ^ 16 by norm_num] using hcB) _ htAll _
      dsimp only [blockSeg, d12aBlockProf]
      refine bind_ok_of (hCheck g x c hx) ?_
      refine bind_ok_of hdec ?_
      refine bind_ok_of hpaths ?_
      refine bind_ok_of (a := bRoot) rfl ?_
      refine bind_ok_of hbv ?_
      refine bind_ok_of hbc ?_
      refine bind_ok_of hcb ?_
      rfl

theorem shdP_Pk0_geom50 (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).geom = shdP_blkGeom50 := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]
  rfl

private theorem blockPublic_act0_cast {c₁ c₂ : BlockCal} (h : c₁ = c₂)
    (p : BlockPublic (c₁.over shieldS0)) (hact : p.act 0 2048 = 0) :
    (cast (congrArg (fun cal => BlockPublic (cal.over shieldS0)) h) p).act 0 2048 = 0 := by
  subst h; exact hact

/-- Cast `hAct0 : ∀ b ∈ Rp.blks, b.pub.act 0 2048 = 0` cleanly to block `k < 26`'s `shdP_blkPub`. -/
theorem shdP_blkPub_act0 (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hAct0 : ∀ b ∈ Rp.blks, b.pub.act 0 2048 = 0) (k : ℕ) (hk : k < 26) :
    (shdP_blkPub Rp hR k hk).act 0 2048 = 0 :=
  blockPublic_act0_cast (shdP_blk_cal_eq hR k hk) _ (hAct0 _ (List.getElem_mem _))

/-- Unified 27-table boundary sequence `TB_0, ..., TB_26` connecting Stage IN-C (`idx = 0`),
all 26 blocks (`idx = k → k + 1`), and Stage OUT-C (`idx = 26`). -/
noncomputable def shdP_bndTableAt (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (incRnd : IncRand) (blkRnd : Fin 26 → BlkRand)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) : Fin 27 → Table
  | ⟨0, _⟩ => shdP_incTB Rp x incRnd
  | ⟨k + 1, hk⟩ =>
      shdP_blkBndTable (shdP_blkState Rp hR hweights hinPub x hx ⟨k + 1, hk⟩)
        (shdP_blkState_i16 Rp hR hweights hinPub x hx ⟨k + 1, hk⟩) (blkRnd ⟨k, by omega⟩).bnd

/-- Every boundary table `shdP_bndTableAt ... idx` (`idx : Fin 27`) satisfies `FullBndTableSpec`
for the corresponding trajectory state `shdP_blkState ... idx`. -/
theorem shdP_bndTableAt_spec (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (incRnd : IncRand) (blkRnd : Fin 26 → BlkRand)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (idx : Fin 27) :
    FullBndTableSpec (shdP_blkState Rp hR hweights hinPub x hx idx)
      (shdP_bndTableAt Rp hR hweights hinPub incRnd blkRnd x hx idx) := by
  rcases idx with ⟨i, hi⟩
  cases i with
  | zero =>
    have h0 : shdP_blkState Rp hR hweights hinPub x hx ⟨0, hi⟩ = fun p => Rp.inp.emb (x p.1) p.2 :=
      funext (fun ⟨t, c⟩ => shdP_blkState_zero Rp hR hweights hinPub x hx t c)
    rw [h0]
    exact shdP_incTB_fullBndTableSpec Rp x incRnd
  | succ k =>
    exact shdP_blkBndTable_spec (shdP_blkState Rp hR hweights hinPub x hx ⟨k + 1, hi⟩)
      (shdP_blkState_i16 Rp hR hweights hinPub x hx ⟨k + 1, hi⟩) (blkRnd ⟨k, by omega⟩).bnd

/-- Block 25's outgoing boundary table `shdP_bndTableAt ... ⟨26, _⟩` satisfies Stage OUT-C's `BndTableSpec`! -/
theorem shdP_bndTableAt_last_outcSpec (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (hOut : Rp.out.Valid)
    (incRnd : IncRand) (blkRnd : Fin 26 → BlkRand)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) :
    BndTableSpec (outcWitness_of_adm Rp hOut x hx).y25 Rp.row
      (shdP_bndTableAt Rp hR hweights hinPub incRnd blkRnd x hx ⟨26, by omega⟩) := by
  have hspec := shdP_bndTableAt_spec Rp hR hweights hinPub incRnd blkRnd x hx ⟨26, by omega⟩
  rw [shdP_blkState_last Rp hR hweights hinPub hOut x hx] at hspec
  exact hspec.toBndTableSpec Rp.row

/-- Per-block honest `BlkWitness` extracted for block `k < 26` on any admissible input `x`. -/
noncomputable def shdP_blkWitnessAt (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (hAct0 : ∀ b ∈ Rp.blks, b.pub.act 0 2048 = 0)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (k : ℕ) (hk : k < 26) :
    BlkWitness (shdP_layer k hk) (shdP_blkPub Rp hR k hk)
      (shdP_blkState Rp hR hweights hinPub x hx ⟨k, by omega⟩)
      (shdP_blkState Rp hR hweights hinPub x hx ⟨k + 1, by omega⟩) :=
  blkWitness_of_spec (shdP_layer k hk) (shdP_layer_mem k hk) (shdP_blkPub Rp hR k hk)
    (shdP_blkPub_valid Rp hR hweights k hk) (shdP_blkPub_act0 Rp hR hAct0 k hk)
    (shdP_blkState Rp hR hweights hinPub x hx ⟨k, by omega⟩)
    (shdP_blkState Rp hR hweights hinPub x hx ⟨k + 1, by omega⟩)
    (shdP_blkState_i16 Rp hR hweights hinPub x hx ⟨k, by omega⟩)
    (shdP_blkState_step Rp hR hweights hinPub x hx k hk)

open Classical in
/-- Total `ShdBlkTables` builder across all 26 blocks (using `Classical.dec` with an empty fallback
outside admissible inputs / `k < 26`). -/
noncomputable def shdP_blkTables_total {Hdr Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (hAct0 : ∀ b ∈ Rp.blks, b.pub.act 0 2048 = 0)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand)
    (_H : HIn → Dig) (_st : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (c : Coins) (k : ℕ) :
    ShdBlkTables (shdP_Pk0 tag ioIn ioOut checkOpening Rp) k :=
  if h : (classifyModelP Rp).admissible x ∧ k < 26 then
    shdP_blkTables (shdP_Pk0 tag ioIn ioOut checkOpening Rp) k
      (shdP_blkWitnessAt Rp hR hweights hinPub hAct0 x h.1 k h.2)
      (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x h.1 ⟨k, Nat.lt_succ_of_lt h.2⟩)
      (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x h.1 ⟨k + 1, Nat.succ_lt_succ h.2⟩)
      (blkRndOf c ⟨k, h.2⟩)
  else
    let emptyT : Table := mkPcsTable 14 2 256 (by norm_num) [] (fun _ => zeroDig)
    { TB_prev := emptyT
      TB_next := emptyT
      coreT :=
        { TA := emptyT
          M := blkTM (blkRndOf c ⟨0, by norm_num⟩)
          TH := fun _ _ _ => emptyT
          slot := polySlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) shdP_U shdP_hbij
            (fun _ _ _ _ _ => Fp2.zero) (fun _ _ _ _ _ _ => 0) (fun _ _ _ _ _ _ => []) } }

/-- Total guarded honest block segment prover family (`ℕ → SegP (ClsStmt Hdr) (shieldS0.Tok → ℕ) Coins`),
ready to plug directly into `RunP.blk`. -/
noncomputable def shdP_blkSegP_run {Hdr Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (hAct0 : ∀ b ∈ Rp.blks, b.pub.act 0 2048 = 0)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand)
    (k : ℕ) : SegP (ClsStmt Hdr) (shieldS0.Tok → ℕ) Coins :=
  if hk : k < 26 then
    shdP_blkSegP_guarded tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp))
      (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38)
      (shdP_layer k hk) (shdP_blkPub Rp hR k hk)
      (shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0 incRndOf blkRndOf) k
  else
    ⟨fun _ _ _ _ _ _ _ _ => .error ()⟩

/-- **Carry-ownership preservation across block `k < 26`**: whenever `shdP_blkSegP_run ... k` succeeds
on an admissible input `x`, the outgoing carry `cr'` commits to `TB_{k+1}` and every claim in `cr'.pending`
is `ClaimTrue` on `TB_{k+1}.rows` (feeding directly into block `k + 1` or Stage OUT-C)! -/
theorem shdP_blkSegP_run_outClaims_true {Hdr Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (hAct0 : ∀ b ∈ Rp.blks, b.pub.act 0 2048 = 0)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand)
    (k : ℕ) (hk : k < 26)
    (H : HIn → Dig) (st : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr)
    (enc : Dig → List UInt8) (cr' : Carry) (t' : Tr)
    (hgrpA : ∀ cl t0, checkOpening H .a cl t0 = .ok () → (groupZclaims (cl.map toZClaim) 4577 14).length = 36)
    (hgrpH : ∀ cl t0, checkOpening H .h cl t0 = .ok () → (groupZclaims (cl.map toZClaim) 4390 14).length = 9)
    (hgrpB : ∀ cl t0, bndCheck st k cl t0 = .ok () → (groupZclaims (cl.map toZClaim) 38 14).length = 2)
    (hrun : (shdP_blkSegP_run tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0
        check0 digest bndCheck incRndOf blkRndOf k).run H st x c bnd start cr t = .ok (enc, cr', t')) :
    let TB_next := shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k + 1, by omega⟩
    cr'.root = rootOf H tag 16 TB_next
      ∧ ∀ cl ∈ cr'.pending, ClaimTrue shdP_U (2 ^ 14) 14 TB_next.rows (toZClaim cl) := by
  intro TB_next
  dsimp only [shdP_blkSegP_run] at hrun
  rw [dite_eq_left hk] at hrun
  obtain ⟨hbad, hrunU⟩ := shdP_blkSegP_guarded_run_ok tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
    (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) (vdChk check0) shdP_segPaths digest
    (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38) (shdP_layer k hk) (shdP_blkPub Rp hR k hk)
    (shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0 incRndOf blkRndOf)
    k H st x c bnd start cr t (enc, cr', t') hrun
  have hwtEq : shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0 incRndOf blkRndOf
        H st x c k
      = shdP_blkTables (shdP_Pk0 tag ioIn ioOut checkOpening Rp) k
          (shdP_blkWitnessAt Rp hR hweights hinPub hAct0 x hx k hk)
          (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, by omega⟩)
          TB_next (blkRndOf c ⟨k, hk⟩) := by
    unfold shdP_blkTables_total
    exact dite_eq_left ⟨hx, hk⟩
  dsimp only [shdP_blkSegP] at hrunU
  rw [hwtEq] at hbad hrunU
  set w_tab := shdP_blkTables (shdP_Pk0 tag ioIn ioOut checkOpening Rp) k
    (shdP_blkWitnessAt Rp hR hweights hinPub hAct0 x hx k hk)
    (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, by omega⟩)
    TB_next (blkRndOf c ⟨k, hk⟩)
  split at hrunU
  · set tFrame := blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
      (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp)) (vdChk check0) shdP_segPaths digest
      (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38)) H st k (rootOf H tag 16 w_tab.TB_next) t
    set D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23
      (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) w_tab.coreT tFrame
    cases hR' : coreProve H (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) D tFrame with
    | error _ => rw [hR'] at hrunU; cases hrunU
    | ok R =>
      rw [hR'] at hrunU
      dsimp only at hrunU
      cases hbc : bndCheck st k (cr.pending ++ R.acc.claims.inp) R.t7 with
      | error _ => rw [hbc] at hrunU; cases hrunU
      | ok _ =>
        rw [hbc] at hrunU
        dsimp only at hrunU
        simp only [Except.ok.injEq, Prod.mk.injEq] at hrunU
        obtain ⟨_, rfl, _⟩ := hrunU
        have hbad' := (congrArg (blkAlphaBad (shdP_layer k hk) (shdP_blkPub Rp hR k hk))
          (bgaOf_core H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23
            (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) w_tab.coreT tFrame)).symm.trans hbad
        have harith := shdP_blk_arith H tag ioIn ioOut checkOpening (shdP_layer k hk) (shdP_blkPub Rp hR k hk)
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
          (shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk)
          (shdP_blkState Rp hR hweights hinPub x hx ⟨k, by omega⟩)
          (shdP_blkState Rp hR hweights hinPub x hx ⟨k + 1, by omega⟩)
          (shdP_blkState_i16 Rp hR hweights hinPub x hx ⟨k, by omega⟩)
          (shdP_blkState_i16 Rp hR hweights hinPub x hx ⟨k + 1, by omega⟩)
          (shdP_blkWitnessAt Rp hR hweights hinPub hAct0 x hx k hk)
          (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, by omega⟩)
          TB_next
          (shdP_bndTableAt_spec Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, by omega⟩)
          (shdP_bndTableAt_spec Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k + 1, by omega⟩)
          (blkRndOf c ⟨k, hk⟩) (bndCheck st k) cr tFrame R hR' hbc hbad' hgrpA hgrpH hgrpB
        exact ⟨congrArg (rootOf H tag 16) (show w_tab.TB_next = TB_next from rfl), harith.2⟩
  · cases hrunU

/-- **Top-level Block `k` `SegComplete` theorem (generic `stOf`)**: discharges block `k < 26`
completeness for `shdP_blkSegP_run` against `shdP_blockProf` from `hR`, `hweights`, `hinPub`,
`hAct0`, `hCheck`, and opening group-count checks `(hgrpA, hgrpH, hgrpB)`. -/
theorem shdP_blk_segComplete_of_adm {Γ Hdr Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (hAct0 : ∀ b ∈ Rp.blks, b.pub.act 0 2048 = 0)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand)
    (hOf : Γ → HIn → Dig)
    (stOf : Γ → (shieldS0.Tok → ℕ) → Coins → ClsStmt Hdr)
    (k : ℕ) (hk : k < 26)
    (hCheck : ∀ g x c, (classifyModelP Rp).admissible x → vdChk check0 (stOf g x c) k = .ok ())
    (hgrpA : ∀ H cl t, checkOpening H .a cl t = .ok () → (groupZclaims (cl.map toZClaim) 4577 14).length = 36)
    (hgrpH : ∀ H cl t, checkOpening H .h cl t = .ok () → (groupZclaims (cl.map toZClaim) 4390 14).length = 9)
    (hgrpB : ∀ st cl t, bndCheck st k cl t = .ok () → (groupZclaims (cl.map toZClaim) 38 14).length = 2) :
    SegComplete (classifyModelP Rp).admissible hOf stOf
      (shdP_blkSegP_run tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0
        check0 digest bndCheck incRndOf blkRndOf k)
      (blockSeg (shdP_blockProf tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
        check0 shdP_segPaths digest bndCheck) k) := by
  have hsegEq : shdP_blkSegP_run tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0
        check0 digest bndCheck incRndOf blkRndOf k
      = shdP_blkSegP_guarded tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp))
          (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38)
          (shdP_layer k hk) (shdP_blkPub Rp hR k hk)
          (shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0 incRndOf blkRndOf) k := by
    unfold shdP_blkSegP_run
    exact dite_eq_left hk
  rw [hsegEq]
  refine shdP_blk_segComplete_guarded tag (vdChk check0) digest bndCheck
    (classifyModelP Rp).admissible hOf stOf (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
    (shdP_layer k hk) (shdP_blkPub Rp hR k hk) k hk
    (shdP_Pk0_geom50 tag ioIn ioOut checkOpening Rp hR k hk)
    (shdP_Pk0_maskVerify tag ioIn ioOut checkOpening Rp hR k hk)
    (shdP_Pk0_pcsVerify tag ioIn ioOut checkOpening Rp hR k hk)
    (shdP_Pk0_aPath tag ioIn ioOut checkOpening Rp hR k hk)
    (shdP_Pk0_hPath tag ioIn ioOut checkOpening Rp hR k hk)
    (shdP_Pk0_maskPath tag ioIn ioOut checkOpening Rp hR k hk)
    (shdP_Pk0_preChecks tag ioIn ioOut checkOpening Rp hR k hk)
    (shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0 incRndOf blkRndOf)
    hCheck ?_
  intro g x c cr t R hx
  dsimp only
  intro hR' hbc hbad
  have hwtEq : shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0 incRndOf blkRndOf
        (hOf g) (stOf g x c) x c k
      = shdP_blkTables (shdP_Pk0 tag ioIn ioOut checkOpening Rp) k
          (shdP_blkWitnessAt Rp hR hweights hinPub hAct0 x hx k hk)
          (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, by omega⟩)
          (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k + 1, by omega⟩)
          (blkRndOf c ⟨k, hk⟩) := by
    unfold shdP_blkTables_total
    exact dite_eq_left ⟨hx, hk⟩
  rw [hwtEq] at hR' hbad ⊢
  dsimp only [shdP_blkTables] at hR' hbad ⊢
  exact (shdP_blk_arith (hOf g) tag ioIn ioOut checkOpening (shdP_layer k hk) (shdP_blkPub Rp hR k hk)
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
    (shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk)
    (shdP_blkState Rp hR hweights hinPub x hx ⟨k, by omega⟩)
    (shdP_blkState Rp hR hweights hinPub x hx ⟨k + 1, by omega⟩)
    (shdP_blkState_i16 Rp hR hweights hinPub x hx ⟨k, by omega⟩)
    (shdP_blkState_i16 Rp hR hweights hinPub x hx ⟨k + 1, by omega⟩)
    (shdP_blkWitnessAt Rp hR hweights hinPub hAct0 x hx k hk)
    (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, by omega⟩)
    (shdP_bndTableAt Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k + 1, by omega⟩)
    (shdP_bndTableAt_spec Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k, by omega⟩)
    (shdP_bndTableAt_spec Rp hR hweights hinPub (incRndOf c) (blkRndOf c) x hx ⟨k + 1, by omega⟩)
    (blkRndOf c ⟨k, hk⟩) (bndCheck (stOf g x c) k) cr _ R hR' hbc hbad
    (hgrpA (hOf g)) (hgrpH (hOf g)) (hgrpB (stOf g x c))).1

/-- **Direct `hsegBlk` discharge for `RunShieldOpenShell.sshC_productionReadyL_epP_openShell`**:
matches the exact `shdP_runV ... .blk` signature for all 26 blocks `k < 26`! -/
theorem shdP_blk_segComplete_runV {Hdr Coins : Type}
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid)
    (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hAct0 : ∀ b ∈ Rp.blks, b.pub.act 0 2048 = 0)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
    (epBase : Coins → EpxSalt 6)
    (hPblk : ∀ k, k < 26 → P.blk k =
      shdP_blkSegP_run tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0
        check0 digest bndCheck incRndOf blkRndOf k)
    (hCheck0 : ∀ k, k < 26 → ∀ G x c, (classifyModelP Rp).admissible x →
      check0 (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base G x c) k = .ok ())
    (hgrpA : ∀ H cl t, checkOpening H .a cl t = .ok () → (groupZclaims (cl.map toZClaim) 4577 14).length = 36)
    (hgrpH : ∀ H cl t, checkOpening H .h cl t = .ok () → (groupZclaims (cl.map toZClaim) 4390 14).length = 9)
    (hgrpB : ∀ k, k < 26 → ∀ st cl t, bndCheck st k cl t = .ok () →
      (groupZclaims (cl.map toZClaim) 38 14).length = 2) :
    ∀ k, k < 26 →
      SegComplete (classifyModelP Rp).admissible liftH
        (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
          (shdP_honestIn (Hdr := Hdr) tag epBase).base)
        (P.blk k)
        (blockSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 shdP_segPaths digest bndCheck).blk k) := by
  intro k hk
  rw [hPblk k hk]
  exact shdP_blk_segComplete_of_adm tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0
    check0 digest bndCheck incRndOf blkRndOf liftH
    (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag epBase).base)
    k hk
    (fun G x c hx => shdP_vdChk_ok Rp hR hweights hinPub houtPub Lq P (shdP_cin Hdr tag)
      (le64_of_le20 hL20) (shdP_hr tag hL20) (shdP_honestIn (Hdr := Hdr) tag epBase).base
      check0 G x c k hx (hCheck0 k hk G x c hx))
    hgrpA hgrpH (hgrpB k hk)

/-- **Zero-extra-premise `hsegBlk` discharge** (post-L63 leg 20 `BlockPublic.Valid.act0`):
derives `hAct0` directly from `hweights : ∀ b ∈ Rp.blks, b.pub.Valid`. -/
theorem shdP_blk_segComplete_runV_valid {Hdr Coins : Type}
    (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hw : Hdr → ClsHdrW)
    (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid)
    (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
    (epBase : Coins → EpxSalt 6)
    (hPblk : ∀ k, k < 26 → P.blk k =
      shdP_blkSegP_run tag ioIn ioOut checkOpening Rp hR hweights hinPub (fun b hb => (hweights b hb).act0)
        check0 digest bndCheck incRndOf blkRndOf k)
    (hCheck0 : ∀ k, k < 26 → ∀ G x c, (classifyModelP Rp).admissible x →
      check0 (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag epBase).base G x c) k = .ok ())
    (hgrpA : ∀ H cl t, checkOpening H .a cl t = .ok () → (groupZclaims (cl.map toZClaim) 4577 14).length = 36)
    (hgrpH : ∀ H cl t, checkOpening H .h cl t = .ok () → (groupZclaims (cl.map toZClaim) 4390 14).length = 9)
    (hgrpB : ∀ k, k < 26 → ∀ st cl t, bndCheck st k cl t = .ok () →
      (groupZclaims (cl.map toZClaim) 38 14).length = 2) :
    ∀ k, k < 26 →
      SegComplete (classifyModelP Rp).admissible liftH
        (clsStmtOfP Rp Lq P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
          (shdP_honestIn (Hdr := Hdr) tag epBase).base)
        (P.blk k)
        (blockSeg (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut checkOpening Rp) check0 shdP_segPaths digest bndCheck).blk k) :=
  shdP_blk_segComplete_runV tag Lq hL20 key Rp hR hw preA preB check0 digest bndCheck ioIn ioOut
    checkOpening embDigest bInRow wDigest bOutRow hweights hinPub houtPub
    (fun b hb => (hweights b hb).act0) incRndOf blkRndOf P epBase hPblk hCheck0 hgrpA hgrpH hgrpB

/-! ### 5a. Concrete `checkOpening` & `bndCheck` group-count dischargers -/

/-- Concrete `checkOpeningExec` group-count discharge for block `A` (`36` groups) and `H` (`9` groups). -/
theorem shdP_blk_hgrpA_of_checkOpeningExec (H : HIn → Dig) (cl : List Exec.Block.ZClaim) (t : Tr)
    (h : checkOpeningExec H ⟨4577, List.range' 4283 292, none, 4575, 36⟩ 14 cl t = .ok ()) :
    (groupZclaims (cl.map toZClaim) 4577 14).length = 36 :=
  groupZclaims_length_of_checkOpeningExec H ⟨4577, List.range' 4283 292, none, 4575, 36⟩ 14 4577 cl t h

theorem shdP_blk_hgrpH_of_checkOpeningExec (H : HIn → Dig) (cl : List Exec.Block.ZClaim) (t : Tr)
    (h : checkOpeningExec H ⟨4390, List.range' 4282 106, some (4280, 4281), 4388, 9⟩ 14 cl t = .ok ()) :
    (groupZclaims (cl.map toZClaim) 4390 14).length = 9 :=
  groupZclaims_length_of_checkOpeningExec H ⟨4390, List.range' 4282 106, some (4280, 4281), 4388, 9⟩ 14 4390 cl t h

/-- Pure (transcript-independent) boundary opening check (`38` rows, `2` groups) for `bndCheck`. -/
def shdP_bndCheckPure (cl : List Exec.Block.ZClaim) : Except String Unit := do
  auditClaims cl (2 ^ 14) 38 [32, 33, 34, 35] none 36
  let gs ← openingGroupsAt cl 14
  if gs.length ≠ 2 then throw "boundary opening group count mismatch"
  else pure ()

theorem shdP_blk_hgrpB_of_pure (cl : List Exec.Block.ZClaim)
    (h : shdP_bndCheckPure cl = .ok ()) :
    (groupZclaims (cl.map toZClaim) 38 14).length = 2 := by
  unfold shdP_bndCheckPure at h
  cases ha : auditClaims cl (2 ^ 14) 38 [32, 33, 34, 35] none 36 with
  | error _ =>
    simp only [ha, Bind.bind, Except.bind] at h
    cases h
  | ok u =>
    cases u
    simp only [ha, Bind.bind, Except.bind] at h
    cases hg : openingGroupsAt cl 14 with
    | error _ =>
      simp only [hg] at h
      cases h
    | ok gs =>
      simp only [hg] at h
      by_cases hne : gs.length ≠ 2
      · rw [ite_eq_left hne] at h
        cases h
      · have hlen := openingGroupsAt_length_eq_groupZclaims cl 38 14 gs
          (auditClaims_parts_nonempty cl (2 ^ 14) 38 [32, 33, 34, 35] none 36 ha) hg
        omega

end TopLevelBlockComplete

end ZK60.HonestShield
