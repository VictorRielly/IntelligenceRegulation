/-
D63 lane L68c, part 1c-iii (`HonestShieldStageOutArith.lean`):
complete, zero-`sorry` Stage OUT-C slots `OUTC-05..07`, `OutcAccInv` induction
(including `.priv` slots `1, 3` and `.host` slots `2, 4` with 2-term `acc.hostFs` via `mTrue_terms_mdot`),
`shdP_outc_arith` (all 20 conjuncts of `HonestShieldStages.shdP_outc_segComplete`'s `hArith`),
and top-level **`shdP_outc_segComplete_of_adm`** discharging `hsegOut` of
`RunShieldOpenShell.sshC_productionReadyL_epP_openShell`!

Only at most `propext`, `Classical.choice`, `Quot.sound`; zero `sorry`s.
-/
import ZK60Formal.HonestShieldStageOutSlots

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
open ZK60.Out (OutCPublic margin sigOf)
open ZK60.Exec.Block (BlockParams SlotDef Hist SlotRec Acc Claims4 Cm Tab)

section StageOutSlotArith2

variable (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hOut : Rp.out.Valid) (wDigest : Dig) (bOutRow : ℕ)
  {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (TB : Table) (hTB : BndTableSpec w.y25 Rp.row TB) (rnd : OutcRand)

include hOut in
/-- Slot 5 (`OUTC-05 DZC`, `.standalone`): `IndDegLE 5`, `cubeSum = 0`, `df.hosted = []`. -/
theorem outc_slot5_arith (hist : Hist) (halphaCan : hist.alpha.Canon)
    (halphaNe : ∀ z : ℕ, z < 256 →
      hist.alpha.toK shdP_U ≠ (z : shdP_K) + (hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))).toK shdP_U)
    (dr : List Fp2) (hlen : dr.length = 23) (hdrCan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : outcDefDZC (rcVerdict (shdP_outcPub Rp wDigest) w.v) (shdP_outcGeo bOutRow) hist dr = .ok df) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let P := V.bp
    let cs := outcCs (shdP_outcTA Rp w rnd) (shdP_outcTH Rp w rnd hist.gamma hist.alpha) TB
    IndDegLE 5 (slotPolyK P (fun _ => 14) cs 5 df)
      ∧ cubeSum (slotPolyK P (fun _ => 14) cs 5 df) = 0
      ∧ df.hosted = []
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P cs
  let O := V.pub; let L := outcLay O 14
  have hGb : V.geo.bLogN = 14 := rfl
  have hldo : O.ldo = 12 := (shdP_outcPub_logs Rp wDigest).2.1
  have hdf := outcDefDZC_eq_of_ok O V.geo hist hldo dr hlen hdrCan df hdef
  dsimp only at hdf
  let mu := (dr.drop O.ldo).take 10
  let zeta := dr.getD (O.ldo + 10) Fp2.zero
  let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
  let kNum := kI (2 * O.g0 * O.cn)
  let kDv := kI (2 ^ O.tn)
  let kDen := kI (2 ^ (O.tn + 1))
  have hsh5 : Exec.Block.slotShape P 5 = (12, 1, 5) := shdP_outc_slotShape tag Rp wDigest bOutRow w.v 5
  have hN5 : slotN P 5 = 13 := by unfold slotN; rw [hsh5]; rfl
  have hDlog : L.aLog.getD ocC_D 0 = 1 :=
    (shdP_outcLay_aLog Rp wDigest w.v ocC_D (by norm_num [ocC_D])).trans (ite_eq_left (by norm_num [ocC_D]))
  have hDoff : L.aOff ocC_D = 0 * 4096 := shdP_outcLay_aOff Rp wDigest w.v ocC_D (by norm_num [ocC_D])
  let tabs : List Tab :=
    .eq (dr.take O.ldo) 0 :: (
      .pub (supp O.d (2 ^ O.ldo)) :: (
        ((List.range' ocC_X (ocC_MULT - ocC_X)).zipIdx 0).map (fun p =>
          Block.Tab.priv ⟨.a, [(L.aOff p.1, Fp2.one)], L.aLog.getD p.1 0,
            rhoC 0 (L.aLog.getD p.1 0), L.aMaskBase + 2 * (L.prefixA 5 + p.2), 0⟩)
        ++ [.priv ⟨.a, [(L.aOff ocC_D, Fp2.one)], L.aLog.getD ocC_D 0,
            fixedC (List.replicate OutcPub.toLog Fp2.zero),
            L.aMaskBase + 2 * (L.prefixA 5 + (0 + (List.range' ocC_X (ocC_MULT - ocC_X)).length)), 0⟩]
        ++ ((List.range 6).zipIdx 0).map (fun p =>
          Block.Tab.priv ⟨.h, [((L.hOff (ocH_D0 + p.1)).1, Fp2.one), ((L.hOff (ocH_D0 + p.1)).2, Block.fp2U)],
            L.hLog.getD (ocH_D0 + p.1) 0, rhoC 0 (L.hLog.getD (ocH_D0 + p.1) 0),
            L.hMaskBase + 2 * (L.prefixH 5 + p.2), 0⟩)))
  have htabs : df.tabs = tabs := by rw [hdf]; dsimp only [tabs, L]; rw [hGb]
  have hpolyEq : df.poly = dzcPoly mu zeta hist.alpha gU8 kNum kDv kDen := by rw [hdf]
  have hfit : tabsFit 12 tabs := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · show 0 + (dr.take O.ldo).length ≤ 12; rw [hldo, Nat.zero_add]; exact List.length_take_le _ _
    · rcases List.mem_cons.mp ht with rfl | ht
      · show (supp O.d (2 ^ O.ldo)).length = 2 ^ 12; simp only [supp, List.length_map, List.length_range, hldo]
      · rcases List.mem_append.mp ht with ht12 | ht3
        · rcases List.mem_append.mp ht12 with ht1 | ht2
          · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht1; trivial
          · rcases List.mem_cons.mp ht2 with rfl | ht2
            · trivial
            · cases ht2
        · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht3; trivial
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st he a ha
    rcases List.mem_cons.mp ht with rfl | ht
    · cases he; exact hdrCan a (List.mem_of_mem_take ha)
    · rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_append.mp ht with ht12 | ht3
      · rcases List.mem_append.mp ht12 with ht1 | ht2
        · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht1; cases he
        · rcases List.mem_cons.mp ht2 with rfl | ht2; · cases he
          cases ht2
      · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht3; cases he
  let g : ℕ → (Fin 13 → shdP_K) → shdP_K := fun j z =>
    (tabs.map (stgTabK shdP_U shdP_hbij P cs 12 1 z)).getD j 0
  have hpoly : ∀ z : Fin (slotN P 5) → shdP_K,
      slotPolyK P (fun _ => 14) cs 5 df z
        = let gz := fun i => g i (fun j => z (Fin.cast hN5.symm j))
          let rh := lbK gz 4
          let sg := lbK gz 8
          let kd := gz 14 * kDen.toK shdP_U
          let c0 := (((gz 2 * kNum.toK shdP_U) + (gz 14 * kDv.toK shdP_U)) - (kd * gz 5)) - rh
          let c1 := ((sg + rh) + 1) - kd
          let c2 := ((gz 2 + (kI 32768).toK shdP_U) - gz 3) - (gz 4 * mbC 256)
          let clauses := (((vg mu 0).toK shdP_U * c0) + ((vg mu 1).toK shdP_U * c1)) + ((vg mu 2).toK shdP_U * c2)
          let denAt := fun (l : ℕ × ℤ × ℤ) => denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) gz (2 + l.1) l.2.1 l.2.2
          let hsK := ∑ kk ∈ Finset.range 6,
            let d1 := denAt (dzcLks.getD (2 * kk) (0, 0, 0))
            let d2 := denAt (dzcLks.getD (2 * kk + 1) (0, 0, 0))
            (vg mu (3 + kk)).toK shdP_U * (((gz (15 + kk) * d1) * d2) - (d1 + d2))
          let padK := (1 - gz 1) * (∑ r ∈ Finset.range 12, gz (2 + r) * (zeta.toK shdP_U) ^ r)
          gz 0 * (((gz 1 * clauses) + hsK) + ((vg mu 9).toK shdP_U * padK)) := by
    intro z
    unfold slotPolyK
    have hatP : atLog P 14 = P := shdVo_atLog_14 tag Rp wDigest bOutRow w.v
    have hs : (Exec.Block.slotShape P 5).1 = 12 := by rw [hsh5]
    dsimp only; rw [hatP, hs, htabs]
    obtain ⟨vals, htv, hvcan, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU P cs 12 1 hN5 z tabs hfit hcan
    rw [htv]; dsimp only; rw [hpolyEq]
    have hvg : ∀ i, (vg vals i).toK shdP_U = g i (fun j => z (Fin.cast hN5.symm j)) := fun i => by
      rw [vg_toK_map, hvmap]
      simp only [g, List.getD_eq_getElem?_getD, List.getElem?_map]
      cases h : tabs[i]? with
      | none => rfl
      | some tb => simp only [Option.map_some, Option.getD_some]; exact stgTabK_cast hN5 z tb
    have hmapFn : (fun idx => (vals.map (Fp2.toK shdP_U)).getD idx 0)
        = fun i => g i (fun j => z (Fin.cast hN5.symm j)) :=
      funext (fun i => by rw [← vg_toK_map, hvg i])
    unfold dzcPoly
    dsimp only
    obtain ⟨_, hzeq⟩ := zfoldW_toK shdP_U shdP_hU vals zeta
    obtain ⟨hhsc, hhseq⟩ := foldl_range_add_toK shdP_U
      (fun kk =>
        (vg mu (3 + kk)).mul
          ((((vg vals (15 + kk)).mul
            (denW vals hist.alpha gU8 (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1)
              (dzcLks.getD (2 * kk) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk) (0, 0, 0)).2.2)).mul
            (denW vals hist.alpha gU8 (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1)
              (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2)).sub
          ((denW vals hist.alpha gU8 (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1)
              (dzcLks.getD (2 * kk) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk) (0, 0, 0)).2.2).add
            (denW vals hist.alpha gU8 (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1)
              (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2))))
      (fun _ => Fp2.canon_mul _ _) 6
    have hc0K : (((((vg vals 2).mul kNum).add ((vg vals 14).mul kDv)).sub (((vg vals 14).mul kDen).mul (vg vals 5))).sub (lbW vals 4)).toK shdP_U
        = (((g 2 (fun j => z (Fin.cast hN5.symm j)) * kNum.toK shdP_U)
            + (g 14 (fun j => z (Fin.cast hN5.symm j)) * kDv.toK shdP_U))
            - ((g 14 (fun j => z (Fin.cast hN5.symm j)) * kDen.toK shdP_U)
                * g 5 (fun j => z (Fin.cast hN5.symm j))))
            - lbK (fun i => g i (fun j => z (Fin.cast hN5.symm j))) 4 := by
      rw [Fp2.toK_sub shdP_U _ _ (Fp2.canon_sub _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _)) (lbW_canon _ _),
          Fp2.toK_sub shdP_U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add shdP_U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU,
          lbW_toK shdP_U vals 4, hmapFn, hvg 2, hvg 5, hvg 14]
    have hc1K : ((((lbW vals 8).add (lbW vals 4)).add Fp2.one).sub ((vg vals 14).mul kDen)).toK shdP_U
        = ((lbK (fun i => g i (fun j => z (Fin.cast hN5.symm j))) 8
            + lbK (fun i => g i (fun j => z (Fin.cast hN5.symm j))) 4) + 1)
            - (g 14 (fun j => z (Fin.cast hN5.symm j)) * kDen.toK shdP_U) := by
      rw [Fp2.toK_sub shdP_U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) Fp2.canon_one,
          Fp2.toK_add shdP_U _ _ (lbW_canon _ _) (lbW_canon _ _),
          Fp2.toK_one, Fp2.toK_mul shdP_U shdP_hU,
          lbW_toK shdP_U vals 8, lbW_toK shdP_U vals 4, hmapFn, hvg 14]
    have hc2K : ((((vg vals 2).add (kI 32768)).sub (vg vals 3)).sub (mb (vg vals 4) 256)).toK shdP_U
        = ((g 2 (fun j => z (Fin.cast hN5.symm j)) + (kI 32768).toK shdP_U)
            - g 3 (fun j => z (Fin.cast hN5.symm j)))
            - (g 4 (fun j => z (Fin.cast hN5.symm j)) * mbC 256) := by
      rw [Fp2.toK_sub shdP_U _ _ (Fp2.canon_sub _ _ (Fp2.canon_add _ _) (vg_canon hvcan 3)) (mb_canon _ _),
          Fp2.toK_sub shdP_U _ _ (Fp2.canon_add _ _) (vg_canon hvcan 3),
          Fp2.toK_add shdP_U _ _ (vg_canon hvcan 2) (kI_canon _),
          mb_toK, hvg 2, hvg 3, hvg 4]
    have hhsEq' : (∑ kk ∈ Finset.range 6,
        ((vg mu (3 + kk)).mul
          ((((vg vals (15 + kk)).mul
            (denW vals hist.alpha gU8 (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1)
              (dzcLks.getD (2 * kk) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk) (0, 0, 0)).2.2)).mul
            (denW vals hist.alpha gU8 (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1)
              (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2)).sub
          ((denW vals hist.alpha gU8 (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1)
              (dzcLks.getD (2 * kk) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk) (0, 0, 0)).2.2).add
            (denW vals hist.alpha gU8 (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1)
              (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2)))).toK shdP_U)
      = ∑ kk ∈ Finset.range 6,
        (vg mu (3 + kk)).toK shdP_U *
          (((g (15 + kk) (fun j => z (Fin.cast hN5.symm j)) *
            denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) (fun i => g i (fun j => z (Fin.cast hN5.symm j)))
              (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1) (dzcLks.getD (2 * kk) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk) (0, 0, 0)).2.2) *
            denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) (fun i => g i (fun j => z (Fin.cast hN5.symm j)))
              (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1) (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2) -
          (denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) (fun i => g i (fun j => z (Fin.cast hN5.symm j)))
              (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1) (dzcLks.getD (2 * kk) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk) (0, 0, 0)).2.2 +
            denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) (fun i => g i (fun j => z (Fin.cast hN5.symm j)))
              (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1) (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2)) := by
      refine Finset.sum_congr rfl (fun kk _ => ?_)
      rw [Fp2.toK_mul shdP_U shdP_hU,
          Fp2.toK_sub shdP_U _ _ (Fp2.canon_mul _ _) (Fp2.canon_add _ _),
          Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU,
          Fp2.toK_add shdP_U _ _ (denW_canon _ _ _ halphaCan _ _ _) (denW_canon _ _ _ halphaCan _ _ _),
          denW_toK shdP_U vals hist.alpha gU8 halphaCan (Fp2.canon_mulBase _ _),
          denW_toK shdP_U vals hist.alpha gU8 halphaCan (Fp2.canon_mulBase _ _),
          hmapFn, hvg (15 + kk)]
    have hzfEq' : (∑ j ∈ Finset.range 12, (vg vals (2 + j)).toK shdP_U * (zeta.toK shdP_U) ^ j)
        = ∑ r ∈ Finset.range 12, g (2 + r) (fun j => z (Fin.cast hN5.symm j)) * (zeta.toK shdP_U) ^ r :=
      Finset.sum_congr rfl (fun r _ => by rw [hvg (2 + r)])
    have hpadK : ((Fp2.one.sub (vg vals 1)).mul (zfoldW vals zeta)).toK shdP_U
        = (1 - g 1 (fun j => z (Fin.cast hN5.symm j)))
            * (∑ r ∈ Finset.range 12, g (2 + r) (fun j => z (Fin.cast hN5.symm j)) * (zeta.toK shdP_U) ^ r) := by
      rw [Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_sub shdP_U _ _ Fp2.canon_one (vg_canon hvcan 1), Fp2.toK_one,
          hzeq, hzfEq', hvg 1]
    rw [Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
        Fp2.toK_add shdP_U _ _ (Fp2.canon_mul _ _) hhsc,
        Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
        Fp2.toK_add shdP_U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
        Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_mul shdP_U shdP_hU,
        hc0K, hc1K, hc2K, hhseq, hhsEq', hpadK, hvg 0, hvg 1]
  -- Tab indexing lemmas (using `dzcRest_getD_plane` / `dzcRest_getD_helper`)
  have htabs_eq : tabs = .eq (dr.take O.ldo) 0 :: outcDzcRest O V.geo := by
    dsimp only [tabs, L, outcDzcRest]; rw [hGb]
  have hlen_tabs : tabs.length = 21 := by
    rw [htabs_eq, List.length_cons, outcDzcRest_length]
  have htabs_plane : ∀ (p : ℕ) (hp : p < 12),
      tabs[2 + p]? = some (.priv ⟨.a, [(L.aOff (ocC_X + p), Fp2.one)], L.aLog.getD (ocC_X + p) 0,
        rhoC 0 (L.aLog.getD (ocC_X + p) 0), L.aMaskBase + 2 * (L.prefixA 5 + p), 0⟩) := by
    intro p hp
    have hget := dzcRest_getD_plane O V.geo p hp
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by rw [outcDzcRest_length]; omega),
      Option.getD_some] at hget
    rw [htabs_eq, show 2 + p = (1 + p) + 1 by omega, List.getElem?_cons_succ,
      List.getElem?_eq_getElem (by rw [outcDzcRest_length]; omega), hget, hGb]
  have hg_plane : ∀ (p : ℕ) (hp : p < 12),
      g (2 + p) = fun z => stgTabK shdP_U shdP_hbij P cs 12 1 z
        (.priv ⟨.a, [(L.aOff (ocC_X + p), Fp2.one)], L.aLog.getD (ocC_X + p) 0,
          rhoC 0 (L.aLog.getD (ocC_X + p) 0), L.aMaskBase + 2 * (L.prefixA 5 + p), 0⟩) := by
    intro p hp; funext z
    exact map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) (2 + p) _ (htabs_plane p hp) z
  have htabs_helper : ∀ (kk : ℕ) (hk : kk < 6),
      tabs[15 + kk]? = some (.priv ⟨.h, [((L.hOff (ocH_D0 + kk)).1, Fp2.one), ((L.hOff (ocH_D0 + kk)).2, Block.fp2U)],
        L.hLog.getD (ocH_D0 + kk) 0, rhoC 0 (L.hLog.getD (ocH_D0 + kk) 0),
        L.hMaskBase + 2 * (L.prefixH 5 + kk), 0⟩) := by
    intro kk hk
    have hget := dzcRest_getD_helper O V.geo kk hk
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by rw [outcDzcRest_length]; omega),
      Option.getD_some] at hget
    rw [htabs_eq, show 15 + kk = (14 + kk) + 1 by omega, List.getElem?_cons_succ,
      List.getElem?_eq_getElem (by rw [outcDzcRest_length]; omega), hget, hGb]
  have hg_helper : ∀ (kk : ℕ) (hk : kk < 6),
      g (15 + kk) = fun z => stgTabK shdP_U shdP_hbij P cs 12 1 z
        (.priv ⟨.h, [((L.hOff (ocH_D0 + kk)).1, Fp2.one), ((L.hOff (ocH_D0 + kk)).2, Block.fp2U)],
          L.hLog.getD (ocH_D0 + kk) 0, rhoC 0 (L.hLog.getD (ocH_D0 + kk) 0),
          L.hMaskBase + 2 * (L.prefixH 5 + kk), 0⟩) := by
    intro kk hk; funext z
    exact map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) (15 + kk) _ (htabs_helper kk hk) z
  have htabs_14 : tabs[14]? = some (.priv ⟨.a, [(L.aOff ocC_D, Fp2.one)], L.aLog.getD ocC_D 0,
      fixedC (List.replicate OutcPub.toLog Fp2.zero),
      L.aMaskBase + 2 * (L.prefixA 5 + 12), 0⟩) := rfl
  have hg14_eq : g 14 = fun z => stgTabK shdP_U shdP_hbij P cs 12 1 z
      (.priv ⟨.a, [(L.aOff ocC_D, Fp2.one)], L.aLog.getD ocC_D 0,
        fixedC (List.replicate OutcPub.toLog Fp2.zero),
        L.aMaskBase + 2 * (L.prefixA 5 + 12), 0⟩) := by
    funext z
    exact map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 14 _ htabs_14 z
  have hg14_deg : IndDegLE 1 (g 14) := by
    rw [hg14_eq]
    exact indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU P 76 12 0
      (tabMat 76 12 (shdP_outcTA Rp w rnd).rows) (N := 13) 12 1 rfl
      ⟨.a, [(L.aOff ocC_D, Fp2.one)], L.aLog.getD ocC_D 0,
        fixedC (List.replicate OutcPub.toLog Fp2.zero), L.aMaskBase + 2 * (L.prefixA 5 + 12), 0⟩
      (by simp) (by rw [hDlog]; change min 1 12 ≤ 12; norm_num)
      (by dsimp only; rfl)
      (fun c hc _ hw => by
        obtain ⟨a, ha, hca⟩ := List.mem_map.mp hc
        rw [hw] at hca; injection hca with hca; subst hca
        rw [List.eq_of_mem_replicate ha]; exact Fp2.canon_zero)
  have hg_deg : ∀ idx, IndDegLE 1 (g idx) := by
    intro idx
    by_cases h0 : idx = 0
    · subst h0
      exact indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl (stgTabK_eq_indDeg _ _)
    · by_cases h1 : idx = 1
      · subst h1
        exact indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl (stgTabK_pub_indDeg _)
      · by_cases hp : idx < 14
        · have heq := hg_plane (idx - 2) (by omega)
          rw [show 2 + (idx - 2) = idx by omega] at heq
          rw [heq]
          exact (outc_tabA12_spec tag Rp wDigest bOutRow w.v w TB rnd hist.gamma hist.alpha
            (ocC_X + (idx - 2)) _ (by dsimp only [ocC_X]; omega) (by dsimp only [ocC_X]; omega)).1
        · by_cases h14 : idx = 14
          · subst h14; exact hg14_deg
          · by_cases hk : idx < 21
            · have heq := hg_helper (idx - 15) (by omega)
              rw [show 15 + (idx - 15) = idx by omega] at heq
              rw [heq]
              exact (outc_tabH12_spec tag Rp wDigest bOutRow w.v w TB rnd hist.gamma hist.alpha
                (ocH_D0 + (idx - 15)) _ (by dsimp only [ocH_D0]; omega)).1
            · have hzero : g idx = fun _ => 0 := by
                funext z
                dsimp only [g]
                rw [List.getD_eq_getElem?_getD,
                  List.getElem?_eq_none (l := tabs.map (stgTabK shdP_U shdP_hbij P cs 12 1 z))
                    (by rw [List.length_map, hlen_tabs]; omega),
                  Option.getD_none]
              rw [hzero]; exact IndDegLE.const 0
  have hdeg5 : IndDegLE 5 (fun z : Fin 13 → shdP_K =>
      let gz := fun i => g i z
      let rh := lbK gz 4; let sg := lbK gz 8; let kd := gz 14 * kDen.toK shdP_U
      let c0 := (((gz 2 * kNum.toK shdP_U) + (gz 14 * kDv.toK shdP_U)) - (kd * gz 5)) - rh
      let c1 := ((sg + rh) + 1) - kd
      let c2 := ((gz 2 + (kI 32768).toK shdP_U) - gz 3) - (gz 4 * mbC 256)
      let clauses := (((vg mu 0).toK shdP_U * c0) + ((vg mu 1).toK shdP_U * c1)) + ((vg mu 2).toK shdP_U * c2)
      let denAt := fun (l : ℕ × ℤ × ℤ) => denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) gz (2 + l.1) l.2.1 l.2.2
      let hsK := ∑ kk ∈ Finset.range 6,
        let d1 := denAt (dzcLks.getD (2 * kk) (0, 0, 0))
        let d2 := denAt (dzcLks.getD (2 * kk + 1) (0, 0, 0))
        (vg mu (3 + kk)).toK shdP_U * (((gz (15 + kk) * d1) * d2) - (d1 + d2))
      let padK := (1 - gz 1) * (∑ r ∈ Finset.range 12, gz (2 + r) * (zeta.toK shdP_U) ^ r)
      gz 0 * (((gz 1 * clauses) + hsK) + ((vg mu 9).toK shdP_U * padK))) := by
    have hrh := indDegLE_lbK g hg_deg 4
    have hsg := indDegLE_lbK g hg_deg 8
    have hkd : IndDegLE 1 (fun z => g 14 z * kDen.toK shdP_U) := IndDegLE_mulc (hg_deg 14) _
    have hc0 : IndDegLE 2 (fun z => (((g 2 z * kNum.toK shdP_U) + (g 14 z * kDv.toK shdP_U)) - ((g 14 z * kDen.toK shdP_U) * g 5 z)) - lbK (fun i => g i z) 4) :=
      IndDegLE.sub (IndDegLE.sub
        (IndDegLE.mono (IndDegLE.add (IndDegLE_mulc (hg_deg 2) _) (IndDegLE_mulc (hg_deg 14) _)) (by norm_num))
        (IndDegLE.mul hkd (hg_deg 5))) (IndDegLE.mono hrh (by norm_num))
    have hc1 : IndDegLE 2 (fun z => ((lbK (fun i => g i z) 8 + lbK (fun i => g i z) 4) + 1) - (g 14 z * kDen.toK shdP_U)) :=
      IndDegLE.mono (IndDegLE.sub (IndDegLE.add (IndDegLE.add hsg hrh) (IndDegLE.const 1)) hkd) (by norm_num)
    have hc2 : IndDegLE 2 (fun z => ((g 2 z + (kI 32768).toK shdP_U) - g 3 z) - (g 4 z * mbC 256)) :=
      IndDegLE.mono (IndDegLE.sub (IndDegLE.sub (IndDegLE.add (hg_deg 2) (IndDegLE.const _)) (hg_deg 3)) (IndDegLE_mulc (hg_deg 4) _)) (by norm_num)
    have hcl : IndDegLE 2 (fun z =>
        ((vg mu 0).toK shdP_U * (((g 2 z * kNum.toK shdP_U + g 14 z * kDv.toK shdP_U) - g 14 z * kDen.toK shdP_U * g 5 z) - lbK (fun i => g i z) 4)
        + (vg mu 1).toK shdP_U * ((lbK (fun i => g i z) 8 + lbK (fun i => g i z) 4 + 1) - g 14 z * kDen.toK shdP_U))
        + (vg mu 2).toK shdP_U * (((g 2 z + (kI 32768).toK shdP_U) - g 3 z) - g 4 z * mbC 256)) :=
      IndDegLE.add (IndDegLE.add (IndDegLE.cmul ((vg mu 0).toK shdP_U) hc0)
        (IndDegLE.cmul ((vg mu 1).toK shdP_U) hc1)) (IndDegLE.cmul ((vg mu 2).toK shdP_U) hc2)
    have hhs : IndDegLE 3 (fun z => ∑ kk ∈ Finset.range 6,
        let d1 := denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) (fun i => g i z)
          (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1) (dzcLks.getD (2 * kk) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk) (0, 0, 0)).2.2
        let d2 := denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) (fun i => g i z)
          (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1) (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2
        (vg mu (3 + kk)).toK shdP_U * (((g (15 + kk) z * d1) * d2) - (d1 + d2))) :=
      indDegLE_finset_sum (Finset.range 6) _ (fun kk _ =>
        let hd1 := indDegLE_denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) g hg_deg
          (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1) (dzcLks.getD (2 * kk) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk) (0, 0, 0)).2.2
        let hd2 := indDegLE_denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) g hg_deg
          (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1) (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2
        IndDegLE.cmul _ (IndDegLE.sub (IndDegLE.mul (IndDegLE.mul (hg_deg (15 + kk)) hd1) hd2)
          (IndDegLE.mono (IndDegLE.add hd1 hd2) (by norm_num))))
    have hzf : IndDegLE 1 (fun z => ∑ r ∈ Finset.range 12, g (2 + r) z * (zeta.toK shdP_U) ^ r) :=
      indDegLE_finset_sum (Finset.range 12) _ (fun r _ => IndDegLE_mulc (hg_deg (2 + r)) _)
    have hpad : IndDegLE 3 (fun z => (vg mu 9).toK shdP_U * ((1 - g 1 z) * (∑ r ∈ Finset.range 12, g (2 + r) z * (zeta.toK shdP_U) ^ r))) :=
      IndDegLE.mono (IndDegLE.cmul _ (IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg_deg 1)) hzf)) (by norm_num)
    exact IndDegLE.mono (IndDegLE.mul (hg_deg 0) (IndDegLE.add (IndDegLE.add (IndDegLE.mul (hg_deg 1) hcl) hhs) hpad)) (by norm_num)
  refine ⟨?_, ?_, by rw [hdf], fun vals => by rw [hdf]; exact Fp2.canon_mul _ _⟩
  · rw [funext hpoly]
    exact indDegLE_cast hN5 (fun z : Fin 13 → shdP_K =>
      let gz := fun i => g i z
      let rh := lbK gz 4; let sg := lbK gz 8; let kd := gz 14 * kDen.toK shdP_U
      let c0 := (((gz 2 * kNum.toK shdP_U) + (gz 14 * kDv.toK shdP_U)) - (kd * gz 5)) - rh
      let c1 := ((sg + rh) + 1) - kd
      let c2 := ((gz 2 + (kI 32768).toK shdP_U) - gz 3) - (gz 4 * mbC 256)
      let clauses := (((vg mu 0).toK shdP_U * c0) + ((vg mu 1).toK shdP_U * c1)) + ((vg mu 2).toK shdP_U * c2)
      let denAt := fun (l : ℕ × ℤ × ℤ) => denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) gz (2 + l.1) l.2.1 l.2.2
      let hsK := ∑ kk ∈ Finset.range 6,
        let d1 := denAt (dzcLks.getD (2 * kk) (0, 0, 0))
        let d2 := denAt (dzcLks.getD (2 * kk + 1) (0, 0, 0))
        (vg mu (3 + kk)).toK shdP_U * (((gz (15 + kk) * d1) * d2) - (d1 + d2))
      let padK := (1 - gz 1) * (∑ r ∈ Finset.range 12, gz (2 + r) * (zeta.toK shdP_U) ^ r)
      gz 0 * (((gz 1 * clauses) + hsK) + ((vg mu 9).toK shdP_U * padK))) hdeg5
  · rw [funext hpoly, cubeSum_cast hN5 (fun z : Fin 13 → shdP_K =>
      let gz := fun i => g i z
      let rh := lbK gz 4; let sg := lbK gz 8; let kd := gz 14 * kDen.toK shdP_U
      let c0 := (((gz 2 * kNum.toK shdP_U) + (gz 14 * kDv.toK shdP_U)) - (kd * gz 5)) - rh
      let c1 := ((sg + rh) + 1) - kd
      let c2 := ((gz 2 + (kI 32768).toK shdP_U) - gz 3) - (gz 4 * mbC 256)
      let clauses := (((vg mu 0).toK shdP_U * c0) + ((vg mu 1).toK shdP_U * c1)) + ((vg mu 2).toK shdP_U * c2)
      let denAt := fun (l : ℕ × ℤ × ℤ) => denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) gz (2 + l.1) l.2.1 l.2.2
      let hsK := ∑ kk ∈ Finset.range 6,
        let d1 := denAt (dzcLks.getD (2 * kk) (0, 0, 0))
        let d2 := denAt (dzcLks.getD (2 * kk + 1) (0, 0, 0))
        (vg mu (3 + kk)).toK shdP_U * (((gz (15 + kk) * d1) * d2) - (d1 + d2))
      let padK := (1 - gz 1) * (∑ r ∈ Finset.range 12, gz (2 + r) * (zeta.toK shdP_U) ^ r)
      gz 0 * (((gz 1 * clauses) + hsK) + ((vg mu 9).toK shdP_U * padK)))]
    rw [cubeSum_split_ext 12 _ (fun bv hbv => by
      have hs := selK_ext_true 12 bv hbv
      have h0 : g 0 (fun i => (bit (bv i) : shdP_K)) = 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl]
        exact stgTabK_eq_zero_of_selK hs _ _
      dsimp only; rw [h0, zero_mul])]
    refine Finset.sum_eq_zero (fun b _ => ?_)
    dsimp only
    set col : Fin 4096 := ⟨msbIndex 12 b, msbIndex_lt 12 b⟩
    have hsupp : g 1 (fun j => (bit (cptS 12 b j) : shdP_K)) = if col.val < 3072 then 1 else 0 := by
      dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl]
      rw [HonestShield.stgTabK_pub_cptS _ (by simp only [supp, List.length_map, List.length_range, hldo]) b]
      rw [show O.d = 3072 from rfl, hldo, show (2 : ℕ) ^ 12 = 4096 by norm_num]
      exact supp_getD_toK shdP_U 3072 4096 (msbIndex 12 b) (msbIndex_lt 12 b)
    have hD14 : g 14 (fun j => (bit (cptS 12 b j) : shdP_K)) = (w.d : shdP_K) := by
      rw [hg14_eq]
      change Link.claimSem shdP_U 76 12 0 (tabMat 76 12 (shdP_outcTA Rp w rnd).rows) _ = _
      rw [claimSem_priv_cube_y0 P 76 12 (tabMat 76 12 (shdP_outcTA Rp w rnd).rows) 12 rfl b _
        (L.aOff ocC_D, Fp2.one) [] rfl (by rw [hDlog]; change min 1 12 ≤ 12; norm_num)
        (fun c hc _ hw => by
          obtain ⟨a, ha, hca⟩ := List.mem_map.mp hc
          rw [hw] at hca; injection hca with hca; subst hca
          rw [List.eq_of_mem_replicate ha]; exact Fp2.canon_zero)]
      simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, Fp2.toK_one, one_mul,
        hDoff, hDlog, fixedC, OutcPub.toLog, List.replicate, List.length_cons, List.length_nil]
      have hpt0 : Block.ptK shdP_U (Block.xrK 12 (fun i : Fin 13 => (bit (cptS 12 b i) : shdP_K)))
          [Block.Coord.fixed Fp2.zero] 0 = (bit ((fun _ : Fin 1 => false) ⟨0, by norm_num⟩) : shdP_K) := by
        simp [Block.ptK, Block.coordK, Fp2.toK_zero, bit]
      have hnar := data_slice_narrow1 76 0 0 (by norm_num) (by norm_num) (tabMat 76 12 (shdP_outcTA Rp w rnd).rows)
        (fun _ => false) _ hpt0
      rw [Nat.add_zero] at hnar
      rw [hnar, show (shdP_outcTA Rp w rnd).rows = mkRows 76 (2 ^ 12) 256 (shdP_outcTAData Rp w rnd) rnd.aPads from rfl,
        tabMat_mkRows 76 12 256]
      have hm0 : msbIndex 1 (fun _ => false) = 0 := msbIndex_toLog_false
      rw [shdP_outcTAData_0]
      dsimp only
      rw [ite_eq_left (by rw [Nat.zero_add, hm0])]
      exact fp_fromI64_toK w.d (by linarith [w.hd_lo]) (by linarith [w.hd_hi])
    have hpl : ∀ (p : ℕ) (hp : p < 12),
        g (2 + p) (fun j => (bit (cptS 12 b j) : shdP_K))
        = algebraMap GF shdP_K (shdP_outcTAData Rp w rnd ⟨3 + p, by omega⟩ col).toGF := by
      intro p hp
      exact (congrFun (hg_plane p hp) _).trans
        ((outc_tabA12_spec tag Rp wDigest bOutRow w.v w TB rnd hist.gamma hist.alpha
          (ocC_X + p) _ (by dsimp only [ocC_X]; omega) (by dsimp only [ocC_X]; omega)).2 b)
    -- Key lookup evaluation: every `dzcLks[l]` denominator equals `α - (doLook w l col + gU8)`!
    have hden_eq : ∀ (l : Fin 12),
        let lk := dzcLks.getD l.val (0, 0, 0)
        denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U)
          (fun i => g i (fun j => (bit (cptS 12 b j) : shdP_K))) (2 + lk.1) lk.2.1 lk.2.2
        = hist.alpha.toK shdP_U - (((doLook w l col).val : shdP_K) + gU8.toK shdP_U) := by
      have hdzc : ∀ (k : ℕ), k < 12 → dzcLks.getD k (0, 0, 0) =
          match k with
          | 0 => (1, 1, 0) | 1 => (2, 1, 0) | 2 => (3, 1, 127) | 3 => (3, -1, 127)
          | 4 => (4, 1, 0) | 5 => (5, 1, 0) | 6 => (6, 1, 0) | 7 => (7, 1, 0)
          | 8 => (8, 1, 0) | 9 => (9, 1, 0) | 10 => (10, 1, 0) | _ => (11, 1, 0) := by
        intro k hk; interval_cases k <;> rfl
      intro ⟨lv, hlv⟩
      dsimp only
      rw [hdzc lv hlv]
      interval_cases lv
      all_goals simp only [denK]
      · -- lv = 0: plane 1 (`XL0`), coef 1, cst 0
        rw [hpl 1 (by norm_num), kI_int_toK shdP_U 0 (by norm_num) (by norm_num),
          fp_fromI64_toK 1 (by norm_num) (by norm_num),
          shdP_outcTAData_4, Fp.toGF_ofGF, map_natCast]
        push_cast; ring
      · -- lv = 1: plane 2 (`XL1`), coef 1, cst 0
        rw [hpl 2 (by norm_num), kI_int_toK shdP_U 0 (by norm_num) (by norm_num),
          fp_fromI64_toK 1 (by norm_num) (by norm_num),
          shdP_outcTAData_5, Fp.toGF_ofGF, map_natCast]
        push_cast; ring
      · -- lv = 2: plane 3 (`Y`), coef 1, cst 127
        rw [hpl 3 (by norm_num), kI_int_toK shdP_U 127 (by norm_num) (by norm_num),
          fp_fromI64_toK 1 (by norm_num) (by norm_num), shdP_outcTAData_6]
        by_cases hc : col.val < 3072
        · have hdo : (doLook w ⟨2, by norm_num⟩ col).val = (w.q ⟨col.val, hc⟩ + 127).toNat := by
            unfold doLook; rw [dite_eq_left hc]; rfl
          rw [dite_eq_left hc, hdo,
            fp_fromI64_toK (w.q ⟨col.val, hc⟩) (by linarith [w.hq_lo ⟨col.val, hc⟩]) (by linarith [w.hq_hi ⟨col.val, hc⟩])]
          have hnn : (0 : ℤ) ≤ w.q ⟨col.val, hc⟩ + 127 := by linarith [w.hq_lo ⟨col.val, hc⟩]
          have hnat : (((w.q ⟨col.val, hc⟩ + 127).toNat : ℕ) : shdP_K) = (w.q ⟨col.val, hc⟩ : shdP_K) + 127 := by
            rw [← Int.cast_natCast, Int.toNat_of_nonneg hnn]; push_cast; ring
          rw [hnat]; push_cast; ring
        · have hdo : (doLook w ⟨2, by norm_num⟩ col).val = 127 := by
            unfold doLook; rw [dite_eq_right hc, ite_eq_left (Or.inl rfl)]
          rw [dite_eq_right hc, hdo, fp_zero_toGF, map_zero]
          push_cast; ring
      · -- lv = 3: plane 3 (`Y`), coef -1, cst 127
        rw [hpl 3 (by norm_num), kI_int_toK shdP_U 127 (by norm_num) (by norm_num),
          fp_fromI64_toK (-1) (by norm_num) (by norm_num), shdP_outcTAData_6]
        by_cases hc : col.val < 3072
        · have hdo : (doLook w ⟨3, by norm_num⟩ col).val = (-w.q ⟨col.val, hc⟩ + 127).toNat := by
            unfold doLook; rw [dite_eq_left hc]; rfl
          rw [dite_eq_left hc, hdo,
            fp_fromI64_toK (w.q ⟨col.val, hc⟩) (by linarith [w.hq_lo ⟨col.val, hc⟩]) (by linarith [w.hq_hi ⟨col.val, hc⟩])]
          have hnn : (0 : ℤ) ≤ -w.q ⟨col.val, hc⟩ + 127 := by linarith [w.hq_hi ⟨col.val, hc⟩]
          have hnat : (((-w.q ⟨col.val, hc⟩ + 127).toNat : ℕ) : shdP_K) = -(w.q ⟨col.val, hc⟩ : shdP_K) + 127 := by
            rw [← Int.cast_natCast, Int.toNat_of_nonneg hnn]; push_cast; ring
          rw [hnat]; push_cast; ring
        · have hdo : (doLook w ⟨3, by norm_num⟩ col).val = 127 := by
            unfold doLook; rw [dite_eq_right hc, ite_eq_left (Or.inr rfl)]
          rw [dite_eq_right hc, hdo, fp_zero_toGF, map_zero]
          push_cast; ring
      all_goals
        -- lv = 4..11: planes 4..11 (`RHO0..3`, `SIG0..3`), coef 1, cst 0
        rw [hpl _ (by norm_num), kI_int_toK shdP_U 0 (by norm_num) (by norm_num),
          fp_fromI64_toK 1 (by norm_num) (by norm_num),
          shdP_outcTAData_do Rp w rnd _ (by norm_num) (by norm_num), Fp.toGF_ofGF, map_natCast]
        simp only [Nat.add_sub_cancel_left]
        push_cast; ring
    -- 1. All 6 pair helper terms vanish at EVERY `col : Fin 4096`!
    have hhs0 : (∑ kk ∈ Finset.range 6,
        let d1 := denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U)
          (fun i => g i (fun j => (bit (cptS 12 b j) : shdP_K)))
          (2 + (dzcLks.getD (2 * kk) (0, 0, 0)).1) (dzcLks.getD (2 * kk) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk) (0, 0, 0)).2.2
        let d2 := denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U)
          (fun i => g i (fun j => (bit (cptS 12 b j) : shdP_K)))
          (2 + (dzcLks.getD (2 * kk + 1) (0, 0, 0)).1) (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.1 (dzcLks.getD (2 * kk + 1) (0, 0, 0)).2.2
        (vg mu (3 + kk)).toK shdP_U * (((g (15 + kk) (fun j => (bit (cptS 12 b j) : shdP_K)) * d1) * d2) - (d1 + d2))) = 0 := by
      refine Finset.sum_eq_zero (fun kk hkk => ?_)
      have hk6 : kk < 6 := Finset.mem_range.mp hkk
      dsimp only
      have hh : g (15 + kk) (fun j => (bit (cptS 12 b j) : shdP_K))
          = (hist.alpha.toK shdP_U - (((doLook w ⟨2 * kk, by omega⟩ col).val : shdP_K) + gU8.toK shdP_U))⁻¹
            + (hist.alpha.toK shdP_U - (((doLook w ⟨2 * kk + 1, by omega⟩ col).val : shdP_K) + gU8.toK shdP_U))⁻¹ := by
        refine (congrFun (hg_helper kk hk6) _).trans
          (((outc_tabH12_spec tag Rp wDigest bOutRow w.v w TB rnd hist.gamma hist.alpha
            (ocH_D0 + kk) _ (by dsimp only [ocH_D0]; omega)).2 b).trans ?_)
        have hp : (⟨ocH_D0 + kk, by dsimp only [ocH_D0]; omega⟩ : Fin 8) = ⟨1 + kk, by omega⟩ := Fin.ext rfl
        rw [hp]
        unfold shdP_outcHValK; dsimp only
        have hne0 : ¬(1 + kk = 0) := by omega
        have hlt7 : 1 + kk < 7 := by omega
        rw [ite_eq_right hne0, dite_eq_left hlt7]
        have hl1 : (⟨2 * (1 + kk - 1), by omega⟩ : Fin 12) = ⟨2 * kk, by omega⟩ :=
          Fin.ext (by dsimp only; omega)
        have hl2 : (⟨2 * (1 + kk - 1) + 1, by omega⟩ : Fin 12) = ⟨2 * kk + 1, by omega⟩ :=
          Fin.ext (by dsimp only; omega)
        have hcg : ∀ {a b a' b' α gv : shdP_K}, a = a' → b = b' →
            (α - (a + gv))⁻¹ + (α - (b + gv))⁻¹ = (α - (a' + gv))⁻¹ + (α - (b' + gv))⁻¹ := by
          intro a b a' b' α gv ha hb; rw [ha, hb]
        exact hcg (congrArg (fun l : Fin 12 => ((doLook w l col).val : shdP_K)) hl1)
          (congrArg (fun l : Fin 12 => ((doLook w l col).val : shdP_K)) hl2)
      have hd1 := hden_eq ⟨2 * kk, by omega⟩
      have hd2 := hden_eq ⟨2 * kk + 1, by omega⟩
      dsimp only at hd1 hd2
      have hne1 : hist.alpha.toK shdP_U - (((doLook w ⟨2 * kk, by omega⟩ col).val : shdP_K) + gU8.toK shdP_U) ≠ 0 :=
        sub_ne_zero.mpr (halphaNe _ (doLook w ⟨2 * kk, by omega⟩ col).isLt)
      have hne2 : hist.alpha.toK shdP_U - (((doLook w ⟨2 * kk + 1, by omega⟩ col).val : shdP_K) + gU8.toK shdP_U) ≠ 0 :=
        sub_ne_zero.mpr (halphaNe _ (doLook w ⟨2 * kk + 1, by omega⟩ col).isLt)
      rw [hh, hd1, hd2]
      have hcancel : (((hist.alpha.toK shdP_U - (((doLook w ⟨2 * kk, by omega⟩ col).val : shdP_K) + gU8.toK shdP_U))⁻¹
            + (hist.alpha.toK shdP_U - (((doLook w ⟨2 * kk + 1, by omega⟩ col).val : shdP_K) + gU8.toK shdP_U))⁻¹)
            * (hist.alpha.toK shdP_U - (((doLook w ⟨2 * kk, by omega⟩ col).val : shdP_K) + gU8.toK shdP_U)))
            * (hist.alpha.toK shdP_U - (((doLook w ⟨2 * kk + 1, by omega⟩ col).val : shdP_K) + gU8.toK shdP_U))
          - ((hist.alpha.toK shdP_U - (((doLook w ⟨2 * kk, by omega⟩ col).val : shdP_K) + gU8.toK shdP_U))
            + (hist.alpha.toK shdP_U - (((doLook w ⟨2 * kk + 1, by omega⟩ col).val : shdP_K) + gU8.toK shdP_U))) = 0 := by
        field_simp [hne1, hne2]; ring
      rw [hcancel, mul_zero]
    rw [hhs0, add_zero]
    -- 2. Split on `col.val < 3072` (live clauses `c0 = c1 = c2 = 0`, `pad = 0`) vs `col.val ≥ 3072` (`supp = 0`, all 12 planes `0`)
    by_cases hc : col.val < 3072
    · rw [hsupp, ite_eq_left hc, sub_self, zero_mul, mul_zero, add_zero, one_mul]
      set i : Fin 3072 := ⟨col.val, hc⟩
      have hx_val : g 2 (fun j => (bit (cptS 12 b j) : shdP_K)) = (w.y25 (Rp.row, i) : shdP_K) := by
        rw [hpl 0 (by norm_num), shdP_outcTAData_3, dite_eq_left hc]
        have hxr := w.hxRow i
        have hlo : -(2 : ℤ) ^ 64 < w.y25 (Rp.row, i) := by
          have h1 : -(2 : ℤ) ^ 15 ≤ w.y25 (Rp.row, i) := hxr.1; omega
        have hhi : w.y25 (Rp.row, i) < (2 : ℤ) ^ 64 := by
          have h2 : w.y25 (Rp.row, i) ≤ (2 : ℤ) ^ 15 - 1 := hxr.2; omega
        exact fp_fromI64_toK (w.y25 (Rp.row, i)) hlo hhi
      have hy_val : g 5 (fun j => (bit (cptS 12 b j) : shdP_K)) = (w.q i : shdP_K) := by
        rw [hpl 3 (by norm_num), shdP_outcTAData_6, dite_eq_left hc]
        exact fp_fromI64_toK (w.q i) (by linarith [w.hq_lo i]) (by linarith [w.hq_hi i])
      have hxl0 : g 3 (fun j => (bit (cptS 12 b j) : shdP_K)) = ((byteOf 0 (w.y25 (Rp.row, i) + 32768).toNat).val : shdP_K) := by
        rw [hpl 1 (by norm_num), shdP_outcTAData_4, Fp.toGF_ofGF, map_natCast]; unfold doLook; rw [dite_eq_left hc]; rfl
      have hxl1 : g 4 (fun j => (bit (cptS 12 b j) : shdP_K)) = ((byteOf 1 (w.y25 (Rp.row, i) + 32768).toNat).val : shdP_K) := by
        rw [hpl 2 (by norm_num), shdP_outcTAData_5, Fp.toGF_ofGF, map_natCast]; unfold doLook; rw [dite_eq_left hc]; rfl
      have hrh : lbK (fun idx => g idx (fun j => (bit (cptS 12 b j) : shdP_K))) 4 = (w.r i : shdP_K) := by
        unfold lbK
        have hterm : ∀ kk ∈ Finset.range 4,
            g (2 + (4 + kk)) (fun j => (bit (cptS 12 b j) : shdP_K)) * mbC (2 ^ (8 * kk))
            = (((byteOf kk (w.r i).toNat).val * 2 ^ (8 * kk) : ℕ) : shdP_K) := by
          intro kk hkk
          have hkk4 : kk < 4 := Finset.mem_range.mp hkk
          have hmb : (mbC (2 ^ (8 * kk)) : shdP_K) = ((2 ^ (8 * kk) : ℕ) : shdP_K) := by
            rw [mbC_nat _ (by
              have : 8 * kk ≤ 24 := by omega
              calc 2 ^ (8 * kk) ≤ 2 ^ 24 := Nat.pow_le_pow_right (by norm_num) this
                _ < 2 ^ 32 := by norm_num), map_natCast]
          have hgval : g (2 + (4 + kk)) (fun j => (bit (cptS 12 b j) : shdP_K))
              = ((byteOf kk (w.r i).toNat).val : shdP_K) := by
            interval_cases kk
            all_goals
              rw [hpl _ (by norm_num), shdP_outcTAData_do Rp w rnd _ (by norm_num) (by norm_num),
                Fp.toGF_ofGF, map_natCast]
              unfold doLook; rw [dite_eq_left hc]; rfl
          rw [hmb, Nat.cast_mul, hgval]
        rw [Finset.sum_congr rfl hterm, ← Nat.cast_sum,
          sum_bytes_4 (w.r i).toNat (by have := w.hr_lo i; have := w.hr_hi i; omega),
          ← Int.cast_natCast, Int.toNat_of_nonneg (w.hr_lo i)]
      have hsg : lbK (fun idx => g idx (fun j => (bit (cptS 12 b j) : shdP_K))) 8 = (w.s i : shdP_K) := by
        unfold lbK
        have hterm : ∀ kk ∈ Finset.range 4,
            g (2 + (8 + kk)) (fun j => (bit (cptS 12 b j) : shdP_K)) * mbC (2 ^ (8 * kk))
            = (((byteOf kk (w.s i).toNat).val * 2 ^ (8 * kk) : ℕ) : shdP_K) := by
          intro kk hkk
          have hkk4 : kk < 4 := Finset.mem_range.mp hkk
          have hmb : (mbC (2 ^ (8 * kk)) : shdP_K) = ((2 ^ (8 * kk) : ℕ) : shdP_K) := by
            rw [mbC_nat _ (by
              have : 8 * kk ≤ 24 := by omega
              calc 2 ^ (8 * kk) ≤ 2 ^ 24 := Nat.pow_le_pow_right (by norm_num) this
                _ < 2 ^ 32 := by norm_num), map_natCast]
          have hgval : g (2 + (8 + kk)) (fun j => (bit (cptS 12 b j) : shdP_K))
              = ((byteOf kk (w.s i).toNat).val : shdP_K) := by
            interval_cases kk
            all_goals
              rw [hpl _ (by norm_num), shdP_outcTAData_do Rp w rnd _ (by norm_num) (by norm_num),
                Fp.toGF_ofGF, map_natCast]
              unfold doLook; rw [dite_eq_left hc]; rfl
          rw [hmb, Nat.cast_mul, hgval]
        rw [Finset.sum_congr rfl hterm, ← Nat.cast_sum,
          sum_bytes_4 (w.s i).toNat (by have := w.hs_lo i; have := w.hs_hi i; omega),
          ← Int.cast_natCast, Int.toNat_of_nonneg (w.hs_lo i)]
      have hkNum : kNum.toK shdP_U = ((2 * Rp.out.g0 * Rp.out.cn : ℤ) : shdP_K) := by
        have hbd := outc_kN_bd Rp.out hOut
        exact kI_int_toK shdP_U _ hbd.1 hbd.2
      have hkDv : kDv.toK shdP_U = ((2 ^ Rp.out.tn : ℤ) : shdP_K) := by
        have hle : (2 : ℤ) ^ Rp.out.tn ≤ 2 ^ 16 := pow_le_pow_right₀ (by norm_num) hOut.tn
        have hpos : (0 : ℤ) < 2 ^ Rp.out.tn := by positivity
        exact kI_int_toK shdP_U (2 ^ Rp.out.tn) (by linarith) (by linarith)
      have hkDen : kDen.toK shdP_U = ((2 ^ (Rp.out.tn + 1) : ℤ) : shdP_K) := by
        have hle : (2 : ℤ) ^ (Rp.out.tn + 1) ≤ 2 ^ 17 := pow_le_pow_right₀ (by norm_num) (by have := hOut.tn; omega)
        have hpos : (0 : ℤ) < 2 ^ (Rp.out.tn + 1) := by positivity
        exact kI_int_toK shdP_U (2 ^ (Rp.out.tn + 1)) (by linarith) (by linarith)
      have hc0_0 : (((g 2 (fun j => (bit (cptS 12 b j) : shdP_K)) * kNum.toK shdP_U)
          + (g 14 (fun j => (bit (cptS 12 b j) : shdP_K)) * kDv.toK shdP_U))
          - ((g 14 (fun j => (bit (cptS 12 b j) : shdP_K)) * kDen.toK shdP_U)
              * g 5 (fun j => (bit (cptS 12 b j) : shdP_K))))
          - lbK (fun idx => g idx (fun j => (bit (cptS 12 b j) : shdP_K))) 4 = 0 := by
        rw [hx_val, hy_val, hD14, hrh, hkNum, hkDv, hkDen]
        have h := congrArg (Int.cast (R := shdP_K)) (w.hc0 i)
        push_cast at h ⊢; exact h
      have hc1_0 : ((lbK (fun idx => g idx (fun j => (bit (cptS 12 b j) : shdP_K))) 8
          + lbK (fun idx => g idx (fun j => (bit (cptS 12 b j) : shdP_K))) 4) + 1)
          - (g 14 (fun j => (bit (cptS 12 b j) : shdP_K)) * kDen.toK shdP_U) = 0 := by
        rw [hsg, hrh, hD14, hkDen]
        have h := congrArg (Int.cast (R := shdP_K)) (w.hc1 i)
        push_cast at h ⊢; exact h
      have hc2_0 : ((g 2 (fun j => (bit (cptS 12 b j) : shdP_K)) + (kI 32768).toK shdP_U)
          - g 3 (fun j => (bit (cptS 12 b j) : shdP_K)))
          - (g 4 (fun j => (bit (cptS 12 b j) : shdP_K)) * mbC 256) = 0 := by
        rw [hx_val, hxl0, hxl1, kI_int_toK shdP_U 32768 (by norm_num) (by norm_num),
          mbC_nat 256 (by norm_num), map_natCast]
        have h2 := sum_bytes_eq 2 (w.y25 (Rp.row, i) + 32768).toNat (by
          have hxr : -(2 : ℤ) ^ 15 ≤ w.y25 (Rp.row, i) ∧ w.y25 (Rp.row, i) ≤ (2 : ℤ) ^ 15 - 1 := w.hxRow i
          omega)
        simp only [Finset.sum_range_succ, Finset.range_zero, Finset.sum_empty, zero_add] at h2
        have h2' : (byteOf 0 (w.y25 (Rp.row, i) + 32768).toNat).val
            + (byteOf 1 (w.y25 (Rp.row, i) + 32768).toNat).val * 256
            = (w.y25 (Rp.row, i) + 32768).toNat := by norm_num at h2; linarith
        have hcast : (((byteOf 0 (w.y25 (Rp.row, i) + 32768).toNat).val : shdP_K)
            + ((byteOf 1 (w.y25 (Rp.row, i) + 32768).toNat).val : shdP_K) * 256)
            = ((w.y25 (Rp.row, i) + 32768).toNat : shdP_K) := by
          have := congrArg (Nat.cast (R := shdP_K)) h2'
          push_cast at this; exact this
        have hnat : (((w.y25 (Rp.row, i) + 32768).toNat : ℕ) : shdP_K) = (w.y25 (Rp.row, i) : shdP_K) + 32768 := by
          rw [← Int.cast_natCast,
            Int.toNat_of_nonneg (by have h1 : -(2 : ℤ) ^ 15 ≤ w.y25 (Rp.row, i) := (w.hxRow i).1; omega)]
          push_cast; ring
        rw [hnat] at hcast
        linear_combination -hcast
      rw [hc0_0, hc1_0, hc2_0]; ring
    · -- Pad channels `col.val ≥ 3072`: `supp = 0` and all 12 `Do` planes are `0`
      rw [hsupp, ite_eq_right hc, zero_mul, zero_add]
      have hpad0 : ∑ r ∈ Finset.range 12, g (2 + r) (fun j => (bit (cptS 12 b j) : shdP_K)) * (zeta.toK shdP_U) ^ r = 0 := by
        refine Finset.sum_eq_zero (fun r hr => ?_)
        have hr12 : r < 12 := Finset.mem_range.mp hr
        have hzr : g (2 + r) (fun j => (bit (cptS 12 b j) : shdP_K)) = 0 := by
          rw [hpl r hr12]
          interval_cases r
          · rw [shdP_outcTAData_3, dite_eq_right hc, fp_zero_toGF, map_zero]
          · rw [shdP_outcTAData_4]; unfold doLook; dsimp only
            rw [dite_eq_right hc, ite_eq_right (by omega), Fp.toGF_ofGF,
              show (⟨0, by norm_num⟩ : Fin 256).val = 0 from rfl, Nat.cast_zero, map_zero]
          · rw [shdP_outcTAData_5]; unfold doLook; dsimp only
            rw [dite_eq_right hc, ite_eq_right (by omega), Fp.toGF_ofGF,
              show (⟨0, by norm_num⟩ : Fin 256).val = 0 from rfl, Nat.cast_zero, map_zero]
          · rw [shdP_outcTAData_6, dite_eq_right hc, fp_zero_toGF, map_zero]
          all_goals
            rw [shdP_outcTAData_do Rp w rnd _ (by norm_num) (by norm_num)]
            unfold doLook; dsimp only
            rw [dite_eq_right hc, ite_eq_right (by omega), Fp.toGF_ofGF,
              show (⟨0, by norm_num⟩ : Fin 256).val = 0 from rfl, Nat.cast_zero, map_zero]
        rw [hzr, zero_mul]
      rw [hpad0, mul_zero, mul_zero, mul_zero]

/-- Slot 6 (`OUTC-06 TAB`, `.standalone`): `IndDegLE 3`, `cubeSum = 0`, `df.hosted = []`. -/
theorem outc_slot6_arith (hist : Hist) (halphaCan : hist.alpha.Canon)
    (halphaNe : ∀ z : ℕ, z < 256 →
      hist.alpha.toK shdP_U ≠ (z : shdP_K) + (hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))).toK shdP_U)
    (dr : List Fp2) (hlen : dr.length = 15) (hdrCan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : outcDefTAB (rcVerdict (shdP_outcPub Rp wDigest) w.v) (shdP_outcGeo bOutRow) hist dr = .ok df) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let P := V.bp
    let cs := outcCs (shdP_outcTA Rp w rnd) (shdP_outcTH Rp w rnd hist.gamma hist.alpha) TB
    IndDegLE 3 (slotPolyK P (fun _ => 14) cs 6 df)
      ∧ cubeSum (slotPolyK P (fun _ => 14) cs 6 df) = 0
      ∧ df.hosted = []
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P cs
  let O := V.pub; let L := outcLay O 14
  have hGb : V.geo.bLogN = 14 := rfl
  have hltab : O.ltab = 12 := (shdP_outcPub_logs Rp wDigest).2.2.1
  have hdf := outcDefTAB_eq_of_ok O V.geo hist hltab dr hlen hdrCan df hdef
  dsimp only at hdf
  let mu := (dr.drop O.ltab).take 2
  let zeta := dr.getD (O.ltab + 2) Fp2.zero
  let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
  have hsh6 : Exec.Block.slotShape P 6 = (12, 1, 3) := shdP_outc_slotShape tag Rp wDigest bOutRow w.v 6
  have hN6 : slotN P 6 = 13 := by unfold slotN; rw [hsh6]; rfl
  let tabs : List Tab := [
    .eq (dr.take O.ltab) 0,
    .pub (supp OutcPub.u8Len (2 ^ O.ltab)),
    .pub (tvTab (2 ^ O.ltab) gU8),
    .priv ⟨.a, [(L.aOff ocC_MULT, Fp2.one)], L.aLog.getD ocC_MULT 0,
      rhoC 0 (L.aLog.getD ocC_MULT 0), L.aMaskBase + 2 * (L.prefixA 6 + 0), 0⟩,
    .priv ⟨.h, [((L.hOff ocH_GU8).1, Fp2.one), ((L.hOff ocH_GU8).2, Block.fp2U)],
      L.hLog.getD ocH_GU8 0, rhoC 0 (L.hLog.getD ocH_GU8 0), L.hMaskBase + 2 * (L.prefixH 6 + 0), 0⟩]
  have hfit : tabsFit 12 tabs := by
    intro t ht; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl | rfl
    · show 0 + (dr.take O.ltab).length ≤ 12; rw [hltab, Nat.zero_add]; exact List.length_take_le _ _
    · show (supp _ _).length = 2 ^ 12; simp only [supp, List.length_map, List.length_range, hltab]
    · show (tvTab _ _).length = 2 ^ 12; simp only [tvTab, List.length_map, List.length_range, hltab]
    · trivial
    · trivial
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st he a ha; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl | rfl
    · cases he; exact hdrCan a (List.mem_of_mem_take ha)
    all_goals cases he
  let g : ℕ → (Fin 13 → shdP_K) → shdP_K := fun j z =>
    (tabs.map (stgTabK shdP_U shdP_hbij P cs 12 1 z)).getD j 0
  have htabs : df.tabs = tabs := by rw [hdf]; dsimp only [tabs, L, gU8]; rw [hGb]
  have hpolyEq : df.poly = tabPoly mu zeta hist.alpha := by rw [hdf]
  have hpoly : ∀ z : Fin (slotN P 6) → shdP_K,
      slotPolyK P (fun _ => 14) cs 6 df z
        = let gz := fun i => g i (fun j => z (Fin.cast hN6.symm j))
          let rel := gz 4 * (hist.alpha.toK shdP_U - gz 2) - gz 3
          let pad := (1 - gz 1) * (gz 3 + zeta.toK shdP_U * gz 4)
          gz 0 * ((vg mu 0).toK shdP_U * rel + (vg mu 1).toK shdP_U * pad) := by
    intro z
    unfold slotPolyK
    have hatP : atLog P 14 = P := shdVo_atLog_14 tag Rp wDigest bOutRow w.v
    have hs : (Exec.Block.slotShape P 6).1 = 12 := by rw [hsh6]
    dsimp only; rw [hatP, hs, htabs]
    obtain ⟨vals, htv, hvcan, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU P cs 12 1 hN6 z tabs hfit hcan
    rw [htv]; dsimp only; rw [hpolyEq]
    have hvg : ∀ i, (vg vals i).toK shdP_U = g i (fun j => z (Fin.cast hN6.symm j)) := fun i => by
      rw [vg_toK_map, hvmap]
      simp only [g, List.getD_eq_getElem?_getD, List.getElem?_map]
      cases h : tabs[i]? with
      | none => rfl
      | some tb => simp only [Option.map_some, Option.getD_some]; exact stgTabK_cast hN6 z tb
    unfold tabPoly
    rw [Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_add shdP_U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
        Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_sub shdP_U _ _ (Fp2.canon_mul _ _) (vg_canon hvcan 3),
        Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_sub shdP_U _ _ halphaCan (vg_canon hvcan 2),
        Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_sub shdP_U _ _ Fp2.canon_one (vg_canon hvcan 1), Fp2.toK_one,
        Fp2.toK_add shdP_U _ _ (vg_canon hvcan 3) (Fp2.canon_mul _ _),
        Fp2.toK_mul shdP_U shdP_hU,
        hvg 0, hvg 1, hvg 2, hvg 3, hvg 4]
  have hg3_spec := outc_tabA12_spec tag Rp wDigest bOutRow w.v w TB rnd hist.gamma hist.alpha ocC_MULT
    (L.aMaskBase + 2 * (L.prefixA 6 + 0)) (by norm_num [ocC_MULT]) (by norm_num [ocC_MULT])
  have hg4_spec := outc_tabH12_spec tag Rp wDigest bOutRow w.v w TB rnd hist.gamma hist.alpha ocH_GU8
    (L.hMaskBase + 2 * (L.prefixH 6 + 0)) (by norm_num [ocH_GU8])
  have hg0 : IndDegLE 1 (g 0) :=
    indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl (stgTabK_eq_indDeg _ _)
  have hg1 : IndDegLE 1 (g 1) :=
    indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl (stgTabK_pub_indDeg _)
  have hg2 : IndDegLE 1 (g 2) :=
    indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 2 _ rfl (stgTabK_pub_indDeg _)
  have hg3 : IndDegLE 1 (g 3) :=
    indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 3 _ rfl hg3_spec.1
  have hg4 : IndDegLE 1 (g 4) :=
    indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 4 _ rfl hg4_spec.1
  have hdeg6 : IndDegLE 3 (fun z : Fin 13 → shdP_K =>
      g 0 z * ((vg mu 0).toK shdP_U * (g 4 z * (hist.alpha.toK shdP_U - g 2 z) - g 3 z)
        + (vg mu 1).toK shdP_U * ((1 - g 1 z) * (g 3 z + zeta.toK shdP_U * g 4 z)))) := by
    have hrel : IndDegLE 2 (fun z => g 4 z * (hist.alpha.toK shdP_U - g 2 z) - g 3 z) :=
      IndDegLE.sub (IndDegLE.mul hg4 (IndDegLE.sub (IndDegLE.const _) hg2)) (IndDegLE.mono hg3 (by norm_num))
    have hpad : IndDegLE 2 (fun z => (1 - g 1 z) * (g 3 z + zeta.toK shdP_U * g 4 z)) :=
      IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) hg1) (IndDegLE.add hg3 (IndDegLE.cmul _ hg4))
    exact IndDegLE.mul hg0 (IndDegLE.add (IndDegLE.cmul _ hrel) (IndDegLE.cmul _ hpad))
  refine ⟨?_, ?_, by rw [hdf], fun vals => by rw [hdf]; exact Fp2.canon_mul _ _⟩
  · rw [funext hpoly]
    exact indDegLE_cast hN6 (fun z : Fin 13 → shdP_K =>
      g 0 z * ((vg mu 0).toK shdP_U * (g 4 z * (hist.alpha.toK shdP_U - g 2 z) - g 3 z)
        + (vg mu 1).toK shdP_U * ((1 - g 1 z) * (g 3 z + zeta.toK shdP_U * g 4 z)))) hdeg6
  · rw [funext hpoly, cubeSum_cast hN6 (fun z : Fin 13 → shdP_K =>
      g 0 z * ((vg mu 0).toK shdP_U * (g 4 z * (hist.alpha.toK shdP_U - g 2 z) - g 3 z)
        + (vg mu 1).toK shdP_U * ((1 - g 1 z) * (g 3 z + zeta.toK shdP_U * g 4 z))))]
    rw [cubeSum_split_ext 12 _ (fun bv hbv => by
      have hs := selK_ext_true 12 bv hbv
      have h0 : g 0 (fun i => (bit (bv i) : shdP_K)) = 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl]
        exact stgTabK_eq_zero_of_selK hs _ _
      rw [h0, zero_mul])]
    refine Finset.sum_eq_zero (fun b _ => ?_)
    set col : Fin 4096 := ⟨msbIndex 12 b, msbIndex_lt 12 b⟩
    have h1 : g 1 (fun j => (bit (cptS 12 b j) : shdP_K)) = if col.val < 256 then 1 else 0 := by
      dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl,
        HonestShield.stgTabK_pub_cptS _ (by simp only [supp, List.length_map, List.length_range, hltab]) b,
        show OutcPub.u8Len = 256 from rfl, hltab, show (2 : ℕ) ^ 12 = 4096 by norm_num]
      exact supp_getD_toK shdP_U 256 4096 (msbIndex 12 b) (msbIndex_lt 12 b)
    have h2 : g 2 (fun j => (bit (cptS 12 b j) : shdP_K)) = ((col.val % 256 : ℕ) : shdP_K) + gU8.toK shdP_U := by
      dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 2 _ rfl,
        HonestShield.stgTabK_pub_cptS _ (by simp only [tvTab, List.length_map, List.length_range, hltab]) b]
      unfold tvTab; rw [rangeMap_getD (2 ^ O.ltab) (msbIndex 12 b) (by rw [hltab]; exact col.isLt)]
      change _ = ((msbIndex 12 b % 256 : ℕ) : shdP_K) + gU8.toK shdP_U
      rw [Fp2.toK_add shdP_U _ _ (kI_canon _) (Fp2.canon_mulBase _ _),
        kI_nat_toK shdP_U (msbIndex 12 b % 256) (by omega)]
    have h3 : g 3 (fun j => (bit (cptS 12 b j) : shdP_K))
        = if hc : col.val < 256 then (outcMult w ⟨col.val, hc⟩ : shdP_K) else 0 := by
      dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 3 _ rfl]
      refine (hg3_spec.2 b).trans ?_
      change algebraMap GF shdP_K (shdP_outcTAData Rp w rnd ⟨15, by norm_num⟩ col).toGF = _
      rw [shdP_outcTAData_15]
      by_cases hc : col.val < 256
      · rw [dite_eq_left hc, dite_eq_left hc, Fp.toGF_ofGF, map_natCast]
      · rw [dite_eq_right hc, dite_eq_right hc, fp_zero_toGF, map_zero]
    have h4 : g 4 (fun j => (bit (cptS 12 b j) : shdP_K))
        = if hc : col.val < 256 then
            (outcMult w ⟨col.val, hc⟩ : shdP_K) * (hist.alpha.toK shdP_U - ((col.val : shdP_K) + gU8.toK shdP_U))⁻¹
          else 0 := by
      dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 4 _ rfl]
      refine (hg4_spec.2 b).trans ?_
      unfold shdP_outcHValK; dsimp only [ocH_GU8]; rfl
    rw [h1, h2, h3, h4]
    by_cases hc : col.val < 256
    · rw [ite_eq_left hc, dite_eq_left hc, dite_eq_left hc, Nat.mod_eq_of_lt hc]
      have halg : ∀ (a v0 v1 z m d : shdP_K), d ≠ 0 →
          a * (v0 * (m * d⁻¹ * d - m) + v1 * ((1 - 1) * (m + z * (m * d⁻¹)))) = 0 := by
        intro a v0 v1 z m d hd
        rw [mul_assoc, inv_mul_cancel₀ hd, mul_one, sub_self, sub_self]; ring
      exact halg _ _ _ _ _ _ (sub_ne_zero.mpr (halphaNe col.val hc))
    · rw [ite_eq_right hc, dite_eq_right hc, dite_eq_right hc]
      have hpad : ∀ (a v0 v1 z d : shdP_K),
          a * (v0 * (0 * d - 0) + v1 * ((1 - 0) * (0 + z * 0))) = 0 := by
        intro a v0 v1 z d; ring
      exact hpad _ _ _ _ _

/-- Slot 7 (`OUTC-07 ZS`, `.standalone`): `IndDegLE 2`, `cubeSum = 0`, `df.hosted = []`. -/
theorem outc_slot7_arith (gamma alpha : Fp2)
    (df : SlotDef) (hdef : outcDefZS (rcVerdict (shdP_outcPub Rp wDigest) w.v) (shdP_outcGeo bOutRow) = .ok df) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let P := V.bp
    let cs := outcCs (shdP_outcTA Rp w rnd) (shdP_outcTH Rp w rnd gamma alpha) TB
    IndDegLE 2 (slotPolyK P (fun _ => 14) cs 7 df)
      ∧ cubeSum (slotPolyK P (fun _ => 14) cs 7 df) = 0
      ∧ df.hosted = []
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P cs
  let O := V.pub; let L := outcLay O 14
  have hGb : V.geo.bLogN = 14 := rfl
  have hdef' : outcDefZS V.pub V.geo = .ok df := hdef
  have hok := outcDefZS_ok V.pub V.geo
  dsimp only at hok; rw [hok] at hdef'
  have hdf := (Except.ok.inj hdef').symm
  have hUlog : L.hLog.getD ocH_U 0 = 12 := shdP_outcLay_hLog Rp wDigest w.v ocH_U (by norm_num [ocH_U])
  have hUoff : L.hOff ocH_U = (16 * 4096, 17 * 4096) := shdP_outcLay_hOff Rp wDigest w.v ocH_U (by norm_num [ocH_U])
  have hsh7 : Exec.Block.slotShape P 7 = (12, 1, 2) := shdP_outc_slotShape tag Rp wDigest bOutRow w.v 7
  have hN7 : slotN P 7 = 13 := by unfold slotN; rw [hsh7]; rfl
  let p1 : Block.Priv := ⟨.h, [((L.hOff ocH_U).1, Fp2.one), ((L.hOff ocH_U).2, Block.fp2U)],
    L.hLog.getD ocH_U 0, rhoC 0 (L.hLog.getD ocH_U 0), L.hMaskBase + 2 * (L.prefixH 7 + 0), 0⟩
  let tabs : List Tab := [
    .pub (List.replicate (2 ^ L.hLog.getD ocH_U 0) Fp2.one),
    .priv p1]
  have htabs : df.tabs = tabs := by rw [hdf]; dsimp only [tabs, p1, L, O]; rw [hGb]
  have hpolyEq : df.poly = zsPoly := by rw [hdf]
  have hfit : tabsFit 12 tabs := by
    intro t ht; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl
    · show (List.replicate _ _).length = 2 ^ 12; rw [List.length_replicate, hUlog]
    · trivial
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st he; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl <;> cases he
  let g : ℕ → (Fin 13 → shdP_K) → shdP_K := fun j z =>
    (tabs.map (stgTabK shdP_U shdP_hbij P cs 12 1 z)).getD j 0
  have hpoly : ∀ z : Fin (slotN P 7) → shdP_K,
      slotPolyK P (fun _ => 14) cs 7 df z
        = g 0 (fun i => z (Fin.cast hN7.symm i)) * g 1 (fun i => z (Fin.cast hN7.symm i)) := by
    intro z
    unfold slotPolyK
    have hatP : atLog P 14 = P := shdVo_atLog_14 tag Rp wDigest bOutRow w.v
    have hs : (Exec.Block.slotShape P 7).1 = 12 := by rw [hsh7]
    dsimp only; rw [hatP, hs, htabs]
    obtain ⟨vals, htv, _, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU P cs 12 1 hN7 z tabs hfit hcan
    rw [htv]; dsimp only; rw [hpolyEq]
    have hvg : ∀ i, (vg vals i).toK shdP_U = g i (fun j => z (Fin.cast hN7.symm j)) := fun i => by
      rw [vg_toK_map, hvmap]
      simp only [g, List.getD_eq_getElem?_getD, List.getElem?_map]
      cases h : tabs[i]? with
      | none => rfl
      | some tb => simp only [Option.map_some, Option.getD_some]; exact stgTabK_cast hN7 z tb
    unfold zsPoly
    rw [Fp2.toK_mul shdP_U shdP_hU, hvg 0, hvg 1]
  have hg0 : IndDegLE 1 (g 0) := g0_pub_indDeg (List.replicate (2 ^ L.hLog.getD ocH_U 0) Fp2.one) _
  have hg1 : IndDegLE 1 (g 1) :=
    indDegLE_map_getD_priv tabs 1 p1 rfl 38 12 0
      (tabMat 38 12 (shdP_outcTH Rp w rnd gamma alpha).rows) (fun _ => rfl) rfl
      (by simp [p1]) (by dsimp only [p1]; rw [hUlog]; change min 12 12 ≤ 12; norm_num)
      (by dsimp only [p1]; simpa using varsOKb_fixed_rho_fixed [] [] 0 (L.hLog.getD ocH_U 0)
            (fun _ h => by cases h) (fun _ h => by cases h))
      (fun c hc _ hw => by dsimp only [p1] at hc; obtain ⟨_, _, h⟩ := List.mem_map.mp hc; rw [hw] at h; cases h)
  refine ⟨?_, ?_, by rw [hdf], fun vals => by rw [hdf]; exact Fp2.canon_mul _ _⟩
  · rw [funext hpoly]; exact indDegLE_cast hN7 (fun z : Fin 13 → shdP_K => g 0 z * g 1 z) (IndDegLE.mul hg0 hg1)
  · rw [funext hpoly, cubeSum_cast hN7 (fun z : Fin 13 → shdP_K => g 0 z * g 1 z)]
    rw [cubeSum_split_ext 12 _ (fun bv hbv => by
      have hs := selK_ext_true 12 bv hbv
      have h0 : g 0 (fun i => (bit (bv i) : shdP_K)) = 0 :=
        g0_pub_zero_of_selK hs (List.replicate (2 ^ L.hLog.getD ocH_U 0) Fp2.one) _
      rw [h0, zero_mul])]
    have hpt : ∀ b : Fin 12 → Bool,
        g 0 (fun j => (bit (cptS 12 b j) : shdP_K)) * g 1 (fun j => (bit (cptS 12 b j) : shdP_K))
        = algebraMap GF shdP_K (shdP_outcHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).1
          + shdP_U * algebraMap GF shdP_K (shdP_outcHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).2 := by
      intro b
      have h0 : g 0 (fun j => (bit (cptS 12 b j) : shdP_K)) = 1 := by
        dsimp only [g]
        rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 (.pub (List.replicate (2 ^ L.hLog.getD ocH_U 0) Fp2.one)) rfl,
          HonestShield.stgTabK_pub_cptS _ (by rw [List.length_replicate, hUlog]) b,
          List.getD_eq_getElem?_getD, List.getElem?_replicate,
          ite_eq_left (by rw [hUlog]; exact msbIndex_lt 12 b), Option.getD_some, Fp2.toK_one]
      have h1 : g 1 (fun j => (bit (cptS 12 b j) : shdP_K))
          = algebraMap GF shdP_K (shdP_outcHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).1
            + shdP_U * algebraMap GF shdP_K (shdP_outcHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).2 := by
        dsimp only [g]
        rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 (.priv p1) rfl]
        have hc := claimSem_priv_cube_y0 P 38 12 (tabMat 38 12 (shdP_outcTH Rp w rnd gamma alpha).rows) 12 rfl b p1
          ((L.hOff ocH_U).1, Fp2.one) [((L.hOff ocH_U).2, Block.fp2U)] rfl
          (by dsimp only [p1]; rw [hUlog]; change min 12 12 ≤ 12; norm_num)
          (fun c hc _ hw => by dsimp only [p1] at hc; obtain ⟨_, _, h⟩ := List.mem_map.mp hc; rw [hw] at h; cases h)
        exact hc.trans (by
          have hrho12Len : (rhoC 0 12).length = 12 := by simp [rhoC]
          simp only [p1, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
            hUoff, hUlog, hrho12Len]
          have hpt' : ∀ a : Fin 12, Block.ptK shdP_U
              (Block.xrK 12 (fun i : Fin 13 => (bit (cptS 12 b i) : shdP_K)))
              (rhoC 0 12) a.val = (bit (b a) : shdP_K) := by
            intro a; unfold Block.ptK
            simp only [rhoC, List.getElem?_map, List.getElem?_range' a.isLt, Option.map_some, Option.getD_some,
              Block.coordK, Nat.zero_add, one_mul]
            exact xrK_cptS (N := 13) 12 b a.val a.isLt (by norm_num)
          exact outc_h_u_at Rp rnd w gamma alpha b _ hpt')
      rw [h0, one_mul, h1]
    simp_rw [hpt]
    rw [sum_fin12_bool_eq (fun col : Fin 4096 =>
      algebraMap GF shdP_K (shdP_outcHUVal rnd col).1 + shdP_U * algebraMap GF shdP_K (shdP_outcHUVal rnd col).2),
      Finset.sum_add_distrib, ← Finset.mul_sum, ← map_sum, ← map_sum,
      shdP_outcHUVal_sum_re, shdP_outcHUVal_sum_im, map_zero, mul_zero, add_zero]

end StageOutSlotArith2

/-! ## 3. `OutcAccInv` induction, `shdP_outc_arith`, and `shdP_outc_segComplete_of_adm` -/

section StageOutComplete

/-- Invariant maintained across all 8 Stage OUT-C slots (`s = 0..8`), tracking:
- `.priv` scalars (`1` and `3`) with exact `S_h + c_h · G_h` so `.host` slots `2` and `4` cancel `c_h · G_h`,
- `mTrue` for EVERY functional in `acc.fs ++ acc.hostFs` (1-term and 2-term via `mTrue_terms_mdot`),
- `ClaimTrue` for EVERY claim in `acc.claims.a`, `acc.claims.h`, and `acc.claims.inp`. -/
def OutcAccInv (Rp : ClassifyRunPublicP shieldS0) {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x)
    (P : BlockParams) (TA TH TB : Table) (M : MTable) (rnd : OutcRand) (s : ℕ) (acc : Acc) : Prop :=
  acc.cs.length = s
  ∧ (∀ c ∈ acc.cs, c.Canon)
  ∧ acc.scalars.length = s
  ∧ (∀ sc ∈ acc.scalars, sc.Canon)
  ∧ (1 < s → (acc.scalars.getD 1 Fp2.zero).toK shdP_U
      = outcPrivSum Rp w 1
        + (acc.cs.getD 1 Fp2.zero).toK shdP_U * cubeSum (Link.maskPoly (mRowKOf 8 rnd.mA) 1 (slotN P 1) (slotD P 1)))
  ∧ (3 < s → (acc.scalars.getD 3 Fp2.zero).toK shdP_U
      = outcPrivSum Rp w 3
        + (acc.cs.getD 3 Fp2.zero).toK shdP_U * cubeSum (Link.maskPoly (mRowKOf 8 rnd.mA) 3 (slotN P 3) (slotD P 3)))
  ∧ (∀ cl ∈ acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 TA.rows (toZClaim cl))
  ∧ (∀ cl ∈ acc.claims.h, ClaimTrue shdP_U (2 ^ 12) 12 TH.rows (toZClaim cl))
  ∧ (∀ cl ∈ acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 TB.rows (toZClaim cl))
  ∧ ∀ mf ∈ acc.fs ++ acc.hostFs,
      (toMF mf).value.toK shdP_U
        = ∑ s' : Fin 8, ∑ j : Fin 512,
            fwt shdP_U (toMF mf) s' j
              * (mA shdP_U M 8 s').eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j)

/-- Single-slot step: `SlotSum` holds and `slotProve` preserves `OutcAccInv` (`s → s + 1`). -/
theorem outc_slot_step (H : HIn → Dig) (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (hOut : Rp.out.Valid) (wDigest : Dig) (bOutRow : ℕ)
    {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (TB : Table) (hTB : BndTableSpec w.y25 Rp.row TB)
    (rnd : OutcRand) (ch : List Fp2) (hchCan : ∀ a ∈ ch, a.Canon) (hbad : outcAlphaBad ch = false)
    (s : ℕ) (hs : s < 8) (recs : List SlotRec) (acc : Acc) (t : Tr) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let P := V.bp
    let TA := shdP_outcTA Rp w rnd
    let TH := shdP_outcTH Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero)
    let M := shdP_outcM rnd
    let D := shdP_outcSlotData tag Rp wDigest bOutRow w.v w TA TB rnd
    let hist := Exec.Block.histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 recs
    OutcAccInv Rp w P TA TH TB M rnd s acc →
      (∀ df, P.define s hist (t.challengeFp2Vec H (P.draws s)).1 = .ok df →
        SlotSum P shdP_U D s hist acc df (slotC H P s t))
      ∧ ∀ sp r acc' t', slotProve H P D s hist acc t = .ok (sp, r, acc', t') →
          OutcAccInv Rp w P TA TH TB M rnd (s + 1) acc' := by
  intro V P TA TH M D hist hinv
  obtain ⟨hcsLen, hcsCan, hscLen, hscCan, hpriv1, hpriv3, hclA, hclH, hclB, hfsOk⟩ := hinv
  let cs := outcCs TA TH TB
  let mRow := mRowKOf 8 rnd.mA
  let G : ℕ → shdP_K := fun k => cubeSum (Link.maskPoly mRow k (slotN P k) (slotD P k))
  have halphaCan : hist.alpha.Canon := Fp2.canon_getD hchCan 1
  have halphaNe : ∀ z : ℕ, z < 256 →
      hist.alpha.toK shdP_U ≠ (z : shdP_K) + (hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))).toK shdP_U :=
    fun z hz => outcAlpha_ne_u8K ch hchCan hbad z hz
  -- Per-slot numerical bounds
  have hN_bounds : ∀ k, k < 8 → 0 < slotN P k ∧ slotN P k < 64 ∧ 1 ≤ slotD P k ∧ slotD P k ≤ 5
      ∧ slotN P k * slotD P k + 2 ≤ 512 := by
    intro k hk
    have hsh := shdP_outc_slotShape tag Rp wDigest bOutRow w.v k
    unfold slotN slotD; rw [hsh]
    interval_cases k <;> norm_num
  obtain ⟨hNpos, hN64, hd1, hd5, hW512⟩ := hN_bounds s hs
  -- Unified per-slot arithmetic result for the active slot `s`
  have hdefArith : ∀ (dr : List Fp2), dr.length = P.draws s → (∀ a ∈ dr, a.Canon) →
      ∀ (df : SlotDef), P.define s hist dr = .ok df →
        IndDegLE (slotD P s) (slotPolyK P (fun _ => 14) cs s df)
        ∧ (∀ (sc : Fp2) (c : Fp2),
            sc = D.scalar s hist acc df c →
            ∀ claimed, Exec.Block.hostedSum acc.scalars sc df.hosted = .ok claimed →
              claimed.Canon
              ∧ claimed.toK shdP_U = cubeSum (fun z =>
                  slotPolyK P (fun _ => 14) cs s df z + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z))
        ∧ (∀ (c : Fp2),
            match P.kind s with
            | .standalone => (D.scalar s hist acc df c).toK shdP_U = c.toK shdP_U * G s
            | .priv => (D.scalar s hist acc df c).toK shdP_U = outcPrivSum Rp w s + c.toK shdP_U * G s
            | .host =>
                (∀ hk ∈ df.hosted, hk.1 < 8 ∧ hk.1 < s ∧ hk.2.Canon)
                ∧ (D.scalar s hist acc df c).toK shdP_U
                    = c.toK shdP_U * G s - (df.hosted.map fun hk =>
                        hk.2.toK shdP_U * (acc.cs.getD hk.1 Fp2.zero).toK shdP_U * G hk.1).sum)
        ∧ ∀ vals, (df.poly vals).Canon := by
    intro dr hdrLen hdrCan df hdef
    have hhost_ok_sa : ∀ (c : Fp2), P.kind s = .standalone → df.hosted = [] →
        cubeSum (slotPolyK P (fun _ => 14) cs s df) = 0 →
        ∀ claimed, Exec.Block.hostedSum acc.scalars (D.scalar s hist acc df c) df.hosted = .ok claimed →
          claimed.Canon ∧ claimed.toK shdP_U = cubeSum (fun z =>
            slotPolyK P (fun _ => 14) cs s df z + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z) := by
      intro c hk hh0 hcube claimed hcl
      rw [hh0] at hcl
      have heq : claimed = D.scalar s hist acc df c := (Except.ok.inj hcl).symm
      subst heq
      have hsc : D.scalar s hist acc df c = ofK shdP_U shdP_hbij (c.toK shdP_U * G s) := by
        dsimp only [D, shdP_outcSlotData, polySlotData]
        rw [show (shdVo tag Rp wDigest bOutRow w.v).bp.kind s = .standalone from hk]
      rw [hsc]
      refine ⟨ofK_canon shdP_U shdP_hbij _, ?_⟩
      rw [toK_ofK shdP_U shdP_hbij, cubeSum_add_smul, hcube, zero_add]
    have hhost_ok_priv : ∀ (c : Fp2), P.kind s = .priv → df.hosted = [] →
        cubeSum (slotPolyK P (fun _ => 14) cs s df) = outcPrivSum Rp w s →
        ∀ claimed, Exec.Block.hostedSum acc.scalars (D.scalar s hist acc df c) df.hosted = .ok claimed →
          claimed.Canon ∧ claimed.toK shdP_U = cubeSum (fun z =>
            slotPolyK P (fun _ => 14) cs s df z + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z) := by
      intro c hk hh0 hcube claimed hcl
      rw [hh0] at hcl
      have heq : claimed = D.scalar s hist acc df c := (Except.ok.inj hcl).symm
      subst heq
      have hsc : D.scalar s hist acc df c = ofK shdP_U shdP_hbij (outcPrivSum Rp w s + c.toK shdP_U * G s) := by
        dsimp only [D, shdP_outcSlotData, polySlotData]
        rw [show (shdVo tag Rp wDigest bOutRow w.v).bp.kind s = .priv from hk]
      rw [hsc]
      refine ⟨ofK_canon shdP_U shdP_hbij _, ?_⟩
      rw [toK_ofK shdP_U shdP_hbij, cubeSum_add_smul, hcube]
    interval_cases s
    · -- Slot 0 (`.standalone`)
      have hD : slotD P 0 = 2 := by
        unfold slotD; rw [show Exec.Block.slotShape P 0 = (12, 1, 2) from shdP_outc_slotShape tag Rp wDigest bOutRow w.v 0]
      obtain ⟨hd0, hc0, hh0, hp0⟩ := outc_slot0_arith tag Rp wDigest bOutRow w TB hTB rnd hist.gamma hist.alpha dr hdrCan df hdef
      refine ⟨by rw [hD]; exact hd0, fun sc c hsc claimed hcl => by subst hsc; exact hhost_ok_sa c rfl hh0 hc0 claimed hcl,
        by intro c; change (ofK shdP_U shdP_hbij _).toK shdP_U = _; exact toK_ofK shdP_U shdP_hbij _, hp0⟩
    · -- Slot 1 (`.priv`)
      have hD : slotD P 1 = 4 := by
        unfold slotD; rw [show Exec.Block.slotShape P 1 = (12, 1, 4) from shdP_outc_slotShape tag Rp wDigest bOutRow w.v 1]
      obtain ⟨hd1', hc1', hh1, hp1⟩ := outc_slot1_arith tag Rp wDigest bOutRow w TB rnd hist.gamma hist.alpha df hdef
      refine ⟨by rw [hD]; exact hd1', fun sc c hsc claimed hcl => by subst hsc; exact hhost_ok_priv c rfl hh1 hc1' claimed hcl,
        by intro c; change (ofK shdP_U shdP_hbij _).toK shdP_U = _; exact toK_ofK shdP_U shdP_hbij _, hp1⟩
    · -- Slot 2 (`.host` of slot 1)
      have hD : slotD P 2 = 3 := by
        unfold slotD; rw [show Exec.Block.slotShape P 2 = (1, 1, 3) from shdP_outc_slotShape tag Rp wDigest bOutRow w.v 2]
      have hdl : dr.length = 7 := by rw [hdrLen]; rfl
      obtain ⟨hd2, hc2, hh2, hp2⟩ := outc_slot2_arith tag Rp hOut wDigest bOutRow w TB rnd hist.gamma hist.alpha dr
        hdl hdrCan df hdef
      refine ⟨by rw [hD]; exact hd2, fun sc c hsc claimed hcl => ?_, fun c => ?_, hp2⟩
      · subst hsc
        rw [hh2] at hcl
        have hlt1 : 1 < acc.scalars.length := by omega
        change (if 1 < acc.scalars.length then Except.ok ((D.scalar 2 hist acc df c).add
            ((dr.getD 5 Fp2.zero).mul (acc.scalars.getD 1 Fp2.zero))) else _) = .ok claimed at hcl
        rw [ite_eq_left hlt1] at hcl
        have hclEq : claimed = (D.scalar 2 hist acc df c).add ((dr.getD 5 Fp2.zero).mul (acc.scalars.getD 1 Fp2.zero)) :=
          (Except.ok.inj hcl).symm
        rw [hclEq]
        have hscCan' : (D.scalar 2 hist acc df c).Canon := ofK_canon shdP_U shdP_hbij _
        refine ⟨Fp2.canon_add _ _, ?_⟩
        rw [Fp2.toK_add shdP_U _ _ hscCan' (Fp2.canon_mul _ _), Fp2.toK_mul shdP_U shdP_hU, hpriv1 (by norm_num)]
        have hscK : (D.scalar 2 hist acc df c).toK shdP_U
            = c.toK shdP_U * G 2 - (dr.getD 5 Fp2.zero).toK shdP_U * (acc.cs.getD 1 Fp2.zero).toK shdP_U * G 1 :=
          (toK_ofK shdP_U shdP_hbij _).trans (by
            change c.toK shdP_U * G 2 - (df.hosted.map fun hk =>
              hk.2.toK shdP_U * (acc.cs.getD hk.1 Fp2.zero).toK shdP_U * G hk.1).sum = _
            rw [hh2, List.map_singleton, List.sum_singleton])
        have hc2' : cubeSum (slotPolyK P (fun _ => 14) cs 2 df) = (dr.getD 5 Fp2.zero).toK shdP_U * outcPrivSum Rp w 1 := hc2
        rw [hscK, cubeSum_add_smul, hc2']; dsimp only [G, mRow]; ring
      · refine ⟨fun hk hhk => ?_, ?_⟩
        · rw [hh2, List.mem_singleton] at hhk; subst hhk
          exact ⟨by norm_num, by norm_num, Fp2.canon_getD hdrCan 5⟩
        · change (ofK shdP_U shdP_hbij _).toK shdP_U = _
          exact toK_ofK shdP_U shdP_hbij _
    · -- Slot 3 (`.priv`)
      have hD : slotD P 3 = 2 := by
        unfold slotD; rw [show Exec.Block.slotShape P 3 = (12, 1, 2) from shdP_outc_slotShape tag Rp wDigest bOutRow w.v 3]
      obtain ⟨hd3, hc3, hh3, hp3⟩ := outc_slot3_arith tag Rp hOut wDigest bOutRow w TB rnd hist.gamma hist.alpha df hdef
      refine ⟨by rw [hD]; exact hd3, fun sc c hsc claimed hcl => by subst hsc; exact hhost_ok_priv c rfl hh3 hc3 claimed hcl,
        by intro c; change (ofK shdP_U shdP_hbij _).toK shdP_U = _; exact toK_ofK shdP_U shdP_hbij _, hp3⟩
    · -- Slot 4 (`.host` of slot 3)
      have hD : slotD P 4 = 4 := by
        unfold slotD; rw [show Exec.Block.slotShape P 4 = (12, 1, 4) from shdP_outc_slotShape tag Rp wDigest bOutRow w.v 4]
      have hdl : dr.length = 15 := by
        rw [hdrLen]; show V.pub.llo + 2 + 1 = 15; have h : V.pub.llo = 12 := (shdP_outcPub_logs Rp wDigest).1; omega
      obtain ⟨hd4', hc4', hh4, hp4⟩ := outc_slot4_arith tag Rp hOut wDigest bOutRow w TB rnd hist halphaCan halphaNe dr
        hdl hdrCan df hdef
      refine ⟨by rw [hD]; exact hd4', fun sc c hsc claimed hcl => ?_, fun c => ?_, hp4⟩
      · subst hsc
        rw [hh4] at hcl
        have hlt3 : 3 < acc.scalars.length := by omega
        change (if 3 < acc.scalars.length then Except.ok ((D.scalar 4 hist acc df c).add
            ((dr.getD 14 Fp2.zero).mul (acc.scalars.getD 3 Fp2.zero))) else _) = .ok claimed at hcl
        rw [ite_eq_left hlt3] at hcl
        have hclEq : claimed = (D.scalar 4 hist acc df c).add ((dr.getD 14 Fp2.zero).mul (acc.scalars.getD 3 Fp2.zero)) :=
          (Except.ok.inj hcl).symm
        rw [hclEq]
        have hscCan' : (D.scalar 4 hist acc df c).Canon := ofK_canon shdP_U shdP_hbij _
        refine ⟨Fp2.canon_add _ _, ?_⟩
        rw [Fp2.toK_add shdP_U _ _ hscCan' (Fp2.canon_mul _ _), Fp2.toK_mul shdP_U shdP_hU, hpriv3 (by norm_num)]
        have hscK : (D.scalar 4 hist acc df c).toK shdP_U
            = c.toK shdP_U * G 4 - (dr.getD 14 Fp2.zero).toK shdP_U * (acc.cs.getD 3 Fp2.zero).toK shdP_U * G 3 :=
          (toK_ofK shdP_U shdP_hbij _).trans (by
            change c.toK shdP_U * G 4 - (df.hosted.map fun hk =>
              hk.2.toK shdP_U * (acc.cs.getD hk.1 Fp2.zero).toK shdP_U * G hk.1).sum = _
            rw [hh4, List.map_singleton, List.sum_singleton])
        have hc4'' : cubeSum (slotPolyK P (fun _ => 14) cs 4 df) = (dr.getD 14 Fp2.zero).toK shdP_U * outcPrivSum Rp w 3 := hc4'
        rw [hscK, cubeSum_add_smul, hc4'']; dsimp only [G, mRow]; ring
      · refine ⟨fun hk hhk => ?_, ?_⟩
        · rw [hh4, List.mem_singleton] at hhk; subst hhk
          exact ⟨by norm_num, by norm_num, Fp2.canon_getD hdrCan 14⟩
        · change (ofK shdP_U shdP_hbij _).toK shdP_U = _
          exact toK_ofK shdP_U shdP_hbij _
    · -- Slot 5 (`.standalone`)
      have hD : slotD P 5 = 5 := by
        unfold slotD; rw [show Exec.Block.slotShape P 5 = (12, 1, 5) from shdP_outc_slotShape tag Rp wDigest bOutRow w.v 5]
      have hdl : dr.length = 23 := by
        rw [hdrLen]; show V.pub.ldo + 10 + 1 = 23; have h : V.pub.ldo = 12 := (shdP_outcPub_logs Rp wDigest).2.1; omega
      obtain ⟨hd5', hc5', hh5, hp5⟩ := outc_slot5_arith tag Rp hOut wDigest bOutRow w TB rnd hist halphaCan halphaNe dr
        hdl hdrCan df hdef
      refine ⟨by rw [hD]; exact hd5', fun sc c hsc claimed hcl => by subst hsc; exact hhost_ok_sa c rfl hh5 hc5' claimed hcl,
        by intro c; change (ofK shdP_U shdP_hbij _).toK shdP_U = _; exact toK_ofK shdP_U shdP_hbij _, hp5⟩
    · -- Slot 6 (`.standalone`)
      have hD : slotD P 6 = 3 := by
        unfold slotD; rw [show Exec.Block.slotShape P 6 = (12, 1, 3) from shdP_outc_slotShape tag Rp wDigest bOutRow w.v 6]
      have hdl : dr.length = 15 := by
        rw [hdrLen]; show V.pub.ltab + 2 + 1 = 15; have h : V.pub.ltab = 12 := (shdP_outcPub_logs Rp wDigest).2.2.1; omega
      obtain ⟨hd6, hc6, hh6, hp6⟩ := outc_slot6_arith tag Rp wDigest bOutRow w TB rnd hist halphaCan halphaNe dr
        hdl hdrCan df hdef
      refine ⟨by rw [hD]; exact hd6, fun sc c hsc claimed hcl => by subst hsc; exact hhost_ok_sa c rfl hh6 hc6 claimed hcl,
        by intro c; change (ofK shdP_U shdP_hbij _).toK shdP_U = _; exact toK_ofK shdP_U shdP_hbij _, hp6⟩
    · -- Slot 7 (`.standalone`)
      have hD : slotD P 7 = 2 := by
        unfold slotD; rw [show Exec.Block.slotShape P 7 = (12, 1, 2) from shdP_outc_slotShape tag Rp wDigest bOutRow w.v 7]
      obtain ⟨hd7, hc7, hh7, hp7⟩ := outc_slot7_arith tag Rp wDigest bOutRow w TB rnd hist.gamma hist.alpha df hdef
      refine ⟨by rw [hD]; exact hd7, fun sc c hsc claimed hcl => by subst hsc; exact hhost_ok_sa c rfl hh7 hc7 claimed hcl,
        by intro c; change (ofK shdP_U shdP_hbij _).toK shdP_U = _; exact toK_ofK shdP_U shdP_hbij _, hp7⟩
  refine ⟨?_, ?_⟩
  · -- Part 1: `SlotSum H P shdP_U D s hist acc df (slotC H P s t)`
    intro df hdef
    obtain ⟨hdeg0, hclaimed, _, _⟩ := hdefArith _ (chalVec_length H _ t) (chalVec_canon H _ t) df hdef
    refine ⟨fun z => slotPolyK P (fun _ => 14) cs s df z
        + (slotC H P s t).toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z,
      IndDegLE.add_smul hdeg0 (Link.maskPoly_indDeg mRow s (slotN P s) (slotD P s) hd1) _,
      honestW_honest shdP_U shdP_hbij (slotD P s) (slotN P s) _,
      fun claimed hcl => hclaimed _ _ rfl claimed hcl,
      fun rho => stgPrivVals_length shdP_U shdP_hbij P cs _ _ df.tabs⟩
  · -- Part 2: `slotProve = .ok (sp, r, acc', t') → OutcAccInv ... (s + 1) acc'`
    intro sp r acc' t' hprove
    unfold slotProve at hprove
    split at hprove
    · cases hprove
    · rename_i df hdef
      split_ifs at hprove with hcZ _
      cases hchk : Exec.Block.slotDefChecks P s acc df with
      | error _ => simp [hchk] at hprove
      | ok _ =>
        cases hhost : Exec.Block.hostedSum acc.scalars (slotSP H P D s hist acc t df).scalar df.hosted with
        | error _ => simp [hchk, hhost] at hprove
        | ok claimed =>
          cases htab : Block.tabVals
              (Block.oneMinusProd ((slotRho H P D s hist acc t df).drop (Exec.Block.slotShape P s).1))
              ((slotRho H P D s hist acc t df).take (Exec.Block.slotShape P s).1)
              (slotSP H P D s hist acc t df).terms df.tabs 0 with
          | error _ => simp [hchk, hhost, htab] at hprove
          | ok vals =>
            simp only [hchk, hhost, htab, Except.ok.injEq, Prod.mk.injEq] at hprove
            obtain ⟨rfl, rfl, rfl, rfl⟩ := hprove
            obtain ⟨hdeg0, hclaimed, hscSpec, hpolyCan⟩ :=
              hdefArith _ (chalVec_length H _ t) (chalVec_canon H _ t) df hdef
            set c := slotC H P s t
            set sc := D.scalar s hist acc df c
            set rhoFull := slotRho H P D s hist acc t df
            set fin := scFinalExec (slotSP H P D s hist acc t df).rounds rhoFull claimed
            set gVal := (fin.sub (df.poly vals)).mul c.inv
            -- 1. Claims preservation via `slotClaims_claimTrue`
            let Q : Cm → Block.ZClaim → Prop
              | .a, cl => ClaimTrue shdP_U (2 ^ 12) 12 TA.rows (toZClaim cl)
              | .h, cl => ClaimTrue shdP_U (2 ^ 12) 12 TH.rows (toZClaim cl)
              | .inp, cl => ClaimTrue shdP_U (2 ^ 14) 14 TB.rows (toZClaim cl)
              | .out, _ => True
            have hQ : ∀ (cm : Cm) (ps : List Block.ZPart) (v' : Fp2), v'.toK shdP_U = cs cm ⟨ps, Fp2.zero⟩ → Q cm ⟨ps, v'⟩ := by
              intro cm ps v' hv'
              cases cm with
              | a => exact (claimTrue_iff_claimSem shdP_U 76 12 TA.rows (shdP_outcTA_rows_len Rp w rnd) ⟨ps, v'⟩).mpr hv'
              | h => exact (claimTrue_iff_claimSem shdP_U 38 12 TH.rows (shdP_outcTH_rows_len Rp w rnd _ _) ⟨ps, v'⟩).mpr hv'
              | inp => exact (claimTrue_iff_claimSem shdP_U 38 14 TB.rows hTB.rows_len ⟨ps, v'⟩).mpr hv'
              | out => trivial
            have hcl' := slotClaims_claimTrue P cs (rhoFull.take (Exec.Block.slotShape P s).1)
              (rhoFull.drop (Exec.Block.slotShape P s).1) df.tabs acc.claims Q hQ ⟨hclA, hclH, hclB, fun _ _ => trivial⟩
            -- 2. `gVal.toK shdP_U = maskPoly mRow s (slotN P s) (slotD P s) (vecK rhoFull)`
            have hcCan : c.Canon := canon_challengeFp2Of _
            have hcNe : c ≠ Fp2.zero := fun h0 => hcZ (by rw [h0]; rfl)
            obtain ⟨hclCan, hclVal⟩ := hclaimed sc c rfl claimed hhost
            have hdegM : IndDegLE (slotD P s) (fun z =>
                slotPolyK P (fun _ => 14) cs s df z + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z) :=
              IndDegLE.add_smul hdeg0 (Link.maskPoly_indDeg mRow s (slotN P s) (slotD P s) hd1) _
            obtain ⟨fin', hscV, hfin'Val, _⟩ := scVerify_honest shdP_U H shdP_hU hd1
              (lt_of_le_of_lt hd5 (by norm_num [gP])) (slotN P s)
              (honestW shdP_U shdP_hbij (slotD P s) (slotN P s) _) _ hdegM
              (honestW_honest shdP_U shdP_hbij _ _ _) claimed hclCan hclVal (slotT4 H P s t sc)
            have hfinEq : fin' = fin := (scVerify_fin_eq H claimed (slotD P s) (slotN P s) hd1 _ _ fin' _ hscV).1
            have hrhoLen : rhoFull.length = slotN P s := by
              show (scChal H (scProve H (slotN P s) _ _).1 _).1.length = slotN P s
              rw [scChal_length]
              exact scProve_length _ _ _ _
            have hrhoCan : ∀ a ∈ rhoFull, a.Canon := scChal_canon H _ _
            have hfinToK : fin.toK shdP_U = (df.poly vals).toK shdP_U
                + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) (vecK shdP_U (slotN P s) rhoFull) := by
              rw [← hfinEq, hfin'Val]
              have hspEq := slotPolyK_vecK_eq P (fun _ => 14) cs s df rhoFull vals hrhoLen hrhoCan htab
              change slotPolyK P (fun _ => 14) cs s df (vecK shdP_U (slotN P s) rhoFull)
                + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) (vecK shdP_U (slotN P s) rhoFull) = _
              rw [hspEq]
            have hgValToK : gVal.toK shdP_U = Link.maskPoly mRow s (slotN P s) (slotD P s) (vecK shdP_U (slotN P s) rhoFull) :=
              (Exec.Slot.terminal_iff shdP_U shdP_hU fin (df.poly vals) c
                (canon_scFinalExec _ _ _ hclCan) (hpolyCan vals) hcCan hcNe _).mpr hfinToK
            have hscNewCan : sc.Canon := by
              dsimp only [sc, D, shdP_outcSlotData, polySlotData]
              split <;> exact ofK_canon shdP_U shdP_hbij _
            -- 3. Assemble `OutcAccInv` at `s + 1`
            refine ⟨by simp [Exec.Block.slotAcc, hcsLen],
              fun c' hc' => by
                simp only [Exec.Block.slotAcc, List.mem_append, List.mem_singleton] at hc'
                rcases hc' with h1 | rfl
                · exact hcsCan c' h1
                · exact hcCan,
              by simp [Exec.Block.slotAcc, hscLen],
              fun sc' hsc' => by
                simp only [Exec.Block.slotAcc, List.mem_append, List.mem_singleton] at hsc'
                rcases hsc' with h1 | rfl
                · exact hscCan sc' h1
                · exact hscNewCan,
              ?_, ?_, hcl'.1, hcl'.2.1, hcl'.2.2.1, ?_⟩
            · -- `priv1` (`1 < s + 1`)
              intro h1s
              by_cases hlt : 1 < s
              · simp only [Exec.Block.slotAcc, List.getD_eq_getElem?_getD]
                rw [List.getElem?_append_left (by omega),
                  List.getElem?_append_left (by omega)]
                simp only [← List.getD_eq_getElem?_getD]
                exact hpriv1 hlt
              · have hs1 : s = 1 := by omega
                subst hs1
                simp only [Exec.Block.slotAcc, List.getD_eq_getElem?_getD]
                rw [List.getElem?_append_right (by omega), hscLen, Nat.sub_self,
                  List.getElem?_cons_zero, Option.getD_some,
                  List.getElem?_append_right (by omega), hcsLen, Nat.sub_self,
                  List.getElem?_cons_zero, Option.getD_some]
                exact hscSpec c
            · -- `priv3` (`3 < s + 1`)
              intro h3s
              by_cases hlt : 3 < s
              · simp only [Exec.Block.slotAcc, List.getD_eq_getElem?_getD]
                rw [List.getElem?_append_left (by omega),
                  List.getElem?_append_left (by omega)]
                simp only [← List.getD_eq_getElem?_getD]
                exact hpriv3 hlt
              · have hs3 : s = 3 := by omega
                subst hs3
                simp only [Exec.Block.slotAcc, List.getD_eq_getElem?_getD]
                rw [List.getElem?_append_right (by omega), hscLen, Nat.sub_self,
                  List.getElem?_cons_zero, Option.getD_some,
                  List.getElem?_append_right (by omega), hcsLen, Nat.sub_self,
                  List.getElem?_cons_zero, Option.getD_some]
                exact hscSpec c
            · -- `fsOk` for `(slotAcc ...).fs ++ (slotAcc ...).hostFs`
              intro mf hmf
              have heval_ok : (toMF ⟨[(s, Cfs.evalWeights rhoFull (slotD P s))], gVal⟩).value.toK shdP_U
                  = ∑ s' : Fin 8, ∑ j : Fin 512,
                      fwt shdP_U (toMF ⟨[(s, Cfs.evalWeights rhoFull (slotD P s))], gVal⟩) s' j
                        * (mA shdP_U M 8 s').eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j) := by
                unfold M shdP_outcM
                rw [mTrue_singleton_mdot 8 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts s hs _ _,
                  mTrue_evalWeights_eq 8 rnd.mA s (slotN P s) (slotD P s) hNpos rhoFull hrhoLen hW512]
                exact hgValToK
              have hscSpecC := hscSpec c
              cases hk : P.kind s with
              | standalone =>
                rw [hk] at hscSpecC
                simp only [Exec.Block.slotAcc, hk, List.mem_append, List.mem_singleton] at hmf
                rcases hmf with ((hold | rfl) | rfl) | hhostOld
                · exact hfsOk mf (List.mem_append_left _ hold)
                · unfold M shdP_outcM
                  rw [mTrue_singleton_mdot 8 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts s hs _ _]
                  exact hscSpecC.trans (mTrue_sumWeights_eq 8 rnd.mA s (slotN P s) (slotD P s) hNpos hN64 hW512 c).symm
                · exact heval_ok
                · exact hfsOk mf (List.mem_append_right _ hhostOld)
              | priv =>
                simp only [Exec.Block.slotAcc, hk, List.mem_append, List.mem_singleton] at hmf
                rcases hmf with (hold | rfl) | hhostOld
                · exact hfsOk mf (List.mem_append_left _ hold)
                · exact heval_ok
                · exact hfsOk mf (List.mem_append_right _ hhostOld)
              | host =>
                rw [hk] at hscSpecC
                obtain ⟨hhkLt, hscHostK⟩ := hscSpecC
                simp only [Exec.Block.slotAcc, hk, List.mem_append, List.mem_singleton] at hmf
                rcases hmf with (hold | rfl) | (hhostOld | rfl)
                · exact hfsOk mf (List.mem_append_left _ hold)
                · exact heval_ok
                · exact hfsOk mf (List.mem_append_right _ hhostOld)
                · -- New multi-term `.host` functional in `acc.hostFs` — discharged by `mTrue_terms_mdot`!
                  unfold M shdP_outcM
                  rw [mTrue_terms_mdot 8 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts _ _
                    (by
                      intro tm htm
                      rcases List.mem_cons.mp htm with rfl | htm
                      · exact hs
                      · obtain ⟨hk', hhk', rfl⟩ := List.mem_map.mp htm
                        exact (hhkLt hk' hhk').1)]
                  rw [List.map_cons, List.sum_cons, List.map_map]
                  have hhead : Block.mdot shdP_U (mRowKOf 8 rnd.mA) 512
                      (s, (Cfs.sumWeights ((Exec.Block.slotShape P s).1 + (Exec.Block.slotShape P s).2.1)
                        (Exec.Block.slotShape P s).2.2).map (fun w => w.mul c))
                      = c.toK shdP_U * G s :=
                    mTrue_sumWeights_eq 8 rnd.mA s (slotN P s) (slotD P s) hNpos hN64 hW512 c
                  have hmap : List.map (Block.mdot shdP_U (mRowKOf 8 rnd.mA) 512 ∘ fun hk' =>
                        (hk'.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk'.1).1 + (Exec.Block.slotShape P hk'.1).2.1)
                          (Exec.Block.slotShape P hk'.1).2.2).map (fun w => w.mul (hk'.2.mul (acc.cs.getD hk'.1 Fp2.zero)).neg))) df.hosted
                      = List.map (fun hk' => -(hk'.2.toK shdP_U * (acc.cs.getD hk'.1 Fp2.zero).toK shdP_U * G hk'.1)) df.hosted := by
                    refine List.map_congr_left (fun hk' hhk' => ?_)
                    obtain ⟨h8, _, _⟩ := hhkLt hk' hhk'
                    obtain ⟨hNpos', hN64', _, _, hW512'⟩ := hN_bounds hk'.1 h8
                    dsimp only [Function.comp_def]
                    rw [show (Exec.Block.slotShape P hk'.1).1 + (Exec.Block.slotShape P hk'.1).2.1 = slotN P hk'.1 from rfl,
                      show (Exec.Block.slotShape P hk'.1).2.2 = slotD P hk'.1 from rfl,
                      mTrue_sumWeights_eq 8 rnd.mA hk'.1 (slotN P hk'.1) (slotD P hk'.1) hNpos' hN64' hW512',
                      Fp2.toK_neg shdP_U _ (Fp2.canon_mul _ _), Fp2.toK_mul shdP_U shdP_hU]
                    dsimp only [G, mRow]; ring
                  rw [hhead, hmap]
                  have hsum_neg : ∀ (l : List (ℕ × Fp2)),
                      (l.map (fun hk' => -(hk'.2.toK shdP_U * (acc.cs.getD hk'.1 Fp2.zero).toK shdP_U * G hk'.1))).sum
                      = - (l.map (fun hk' => hk'.2.toK shdP_U * (acc.cs.getD hk'.1 Fp2.zero).toK shdP_U * G hk'.1)).sum := by
                    intro l; induction l with
                    | nil => simp
                    | cons a tl ih => simp only [List.map_cons, List.sum_cons, ih]; ring
                  rw [hsum_neg, ← sub_eq_add_neg]
                  exact hscHostK

/-- Unroll `outc_slot_step` across all 8 Stage OUT-C slots (`s = 0..8`). -/
theorem shdP_outc_slots_ok (H : HIn → Dig) (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (hOut : Rp.out.Valid) (wDigest : Dig) (bOutRow : ℕ)
    {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (TB : Table) (hTB : BndTableSpec w.y25 Rp.row TB)
    (rnd : OutcRand) (ch : List Fp2) (hchCan : ∀ a ∈ ch, a.Canon) (hbad : outcAlphaBad ch = false) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let P := V.bp
    let TA := shdP_outcTA Rp w rnd
    let TH := shdP_outcTH Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero)
    let M := shdP_outcM rnd
    let D := shdP_outcSlotData tag Rp wDigest bOutRow w.v w TA TB rnd
    ∀ (m s : ℕ), s + m ≤ 8 →
      ∀ (recs : List SlotRec) (acc : Acc) (t : Tr),
        OutcAccInv Rp w P TA TH TB M rnd s acc →
          SlotsSum H P shdP_U D (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 m recs s acc t
          ∧ ∀ sps recs' acc' t',
              slotsProve H P D (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 m recs s acc t = .ok (sps, recs', acc', t') →
              OutcAccInv Rp w P TA TH TB M rnd (s + m) acc' := by
  intro V P TA TH M D m
  induction m with
  | zero =>
    intro s _ recs acc t hinv
    refine ⟨trivial, fun sps recs' acc' t' h => ?_⟩
    simp only [slotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨_, _, rfl, _⟩ := h
    simpa only [Nat.add_zero] using hinv
  | succ m' ih =>
    intro s hsm recs acc t hinv
    have hstep := outc_slot_step H tag Rp hOut wDigest bOutRow w TB hTB rnd ch hchCan hbad
      s (by omega) recs acc t hinv
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
        obtain ⟨_, _, rfl, _⟩ := h
        have hres := (ih (s + 1) (by omega) (recs ++ [r]) acc₁ t₁ (hstep.2 sp r acc₁ t₁ hsp)).2 sps₁ recs₁ acc₂ t₂ hrest
        rwa [show s + 1 + m' = s + (m' + 1) by omega] at hres

/-- **Main Stage OUT-C arithmetic theorem**: discharges ALL 20 conjuncts of
`HonestShieldStages.shdP_outc_segComplete`'s `hArith` for any valid `TB` satisfying `BndTableSpec`! -/
theorem shdP_outc_arith (H : HIn → Dig) (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (hOut : Rp.out.Valid) (wDigest : Dig) (bOutRow : ℕ)
    {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (TB : Table) (hTB : BndTableSpec w.y25 Rp.row TB)
    (rnd : OutcRand) (cr : Carry) (t : Tr) (R : OutcRun)
    (hR : outcProve H (shdVo tag Rp wDigest bOutRow w.v)
      (shdP_outcDataAt tag Rp wDigest bOutRow H w.v (shdP_outcTables tag Rp wDigest bOutRow w.v w TB rnd) t) cr t = .ok R) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let ct := shdP_outcTables tag Rp wDigest bOutRow w.v w TB rnd
    (∀ s hist acc df ch0, (ct.slot.scalar s hist acc df ch0).Canon)
    ∧ (∀ s hist acc df ch0 rho, ∀ w' ∈ ct.slot.terms s hist acc df ch0 rho, w'.Canon)
    ∧ (∀ j, ∀ w' ∈ ct.TA.cols j, w'.Canon)
    ∧ (∀ j, ∀ w' ∈ (ct.TH R.ch).cols j, w'.Canon)
    ∧ (∀ j, ∀ w' ∈ ct.TB.cols j, w'.Canon)
    ∧ (∀ j, (ct.TA.cols j).length = ct.TA.rows.length)
    ∧ (∀ j, ((ct.TH R.ch).cols j).length = (ct.TH R.ch).rows.length)
    ∧ (∀ j, (ct.TB.cols j).length = ct.TB.rows.length)
    ∧ SlotsSum H V.bp shdP_U ct.slot (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 8 [] 0 {} R.t3
    ∧ MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) ct.M 8
    ∧ (∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
        (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
          = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 8)
              (mA shdP_U ct.M 8) i)
    ∧ 76 = ct.TA.rows.length
    ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) ct.TA
    ∧ (∀ cl ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 ct.TA.rows (toZClaim cl))
    ∧ 38 = (ct.TH R.ch).rows.length
    ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (ct.TH R.ch)
    ∧ (∀ cl ∈ R.acc.claims.h ++ [V.lay.logupSumClaim],
        ClaimTrue shdP_U (2 ^ 12) 12 (ct.TH R.ch).rows (toZClaim cl))
    ∧ 38 = ct.TB.rows.length
    ∧ ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 14 * 2 ^ 2) ct.TB
    ∧ (∀ cl ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 14) 14 ct.TB.rows (toZClaim cl)) := by
  intro V ct
  obtain ⟨-, hbad, hch, -, hslotsP, -, -, -, -, -, -, -, -, -, -, -, -, -, -⟩ :=
    outcProve_ok H V _ cr t R hR
  have hchCan : ∀ a ∈ R.ch, a.Canon := by
    rw [hch]; unfold outcCh; exact chalVec_canon H 2 _
  have hinv0 : OutcAccInv Rp w V.bp ct.TA (ct.TH R.ch) ct.TB ct.M rnd 0 {} :=
    ⟨rfl, fun _ h => (by cases h), rfl, fun _ h => (by cases h),
      fun h => (by omega), fun h => (by omega),
      fun _ h => (by cases h), fun _ h => (by cases h), fun _ h => (by cases h),
      fun _ h => (by cases h)⟩
  have hsl := shdP_outc_slots_ok H tag Rp hOut wDigest bOutRow w TB hTB rnd R.ch hchCan hbad
    8 0 (by norm_num) [] {} R.t3 hinv0
  obtain ⟨-, -, -, -, -, -, hclA, hclH, hclB, hfsOk⟩ := hsl.2 R.seg.core.slots R.recs R.acc R.t4 hslotsP
  refine ⟨?_, ?_, ?_, ?_, hTB.cols_canon, ?_, ?_, fun j => (hTB.cols_len j).trans hTB.rows_len.symm,
    hsl.1, ?_, ?_, ?_, ?_, hclA, ?_, ?_, ?_, hTB.rows_len.symm, hTB.cols_honest, hclB⟩
  · intro s hist acc df ch0
    dsimp only [ct, shdP_outcTables, shdP_outcSlotData, polySlotData]
    split <;> exact ofK_canon shdP_U shdP_hbij _
  · intro _ _ _ _ _ _ w' hw'; exact stgPrivVals_canon shdP_U shdP_hbij _ _ _ _ _ w' hw'
  · exact mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _
  · exact mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _
  · exact mkPcsTable_cols_length 12 2 256 (by norm_num) _ _
  · exact mkPcsTable_cols_length 12 2 256 (by norm_num) _ _
  · exact mkMTable_honest 8 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts
  · intro i
    have hmem := List.getElem_mem (l := R.acc.fs ++ R.acc.hostFs) (n := i.val) (by simpa using i.isLt)
    have hget : ((R.acc.fs ++ R.acc.hostFs).map toMF).get i
        = toMF ((R.acc.fs ++ R.acc.hostFs)[i.val]'(by simpa using i.isLt)) := by
      simp only [List.get_eq_getElem, List.getElem_map]
    unfold mTrue wtOf
    rw [hget]
    exact hfsOk _ hmem
  · exact (shdP_outcTA_rows_len Rp w rnd).symm
  · exact shdP_outcTA_colsHonest Rp w rnd
  · exact (shdP_outcTH_rows_len Rp w rnd _ _).symm
  · exact shdP_outcTH_colsHonest Rp w rnd _ _
  · intro cl hcl
    rcases List.mem_append.mp hcl with h1 | h2
    · exact hclH cl h1
    · rw [List.mem_singleton.mp h2]
      exact shdP_outc_logupSumClaim_true tag Rp wDigest bOutRow w.v w rnd R.ch

/-- Total wrapper `OutcTables` builder (using `Classical.dec` on `(classifyModelP Rp).admissible x`
with a fallback table for inadmissible inputs) so `shdP_outcP` accepts arbitrary `x`. -/
noncomputable def shdP_outcTables_total {Hdr Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (hOut : Rp.out.Valid) (wDigest : Dig) (bOutRow : ℕ)
    (TBOf : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → Table)
    (rndOf : Coins → OutcRand)
    (H : HIn → Dig) (s : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (c : Coins) :
    OutcTables (shdVo tag Rp wDigest bOutRow s.verdict) := by
  classical
  by_cases hx : (classifyModelP Rp).admissible x
  · exact shdP_outcTables tag Rp wDigest bOutRow s.verdict (outcWitness_of_adm Rp hOut x hx) (TBOf H s x c) (rndOf c)
  · exact
      { TA := mkPcsTable 12 2 256 (by norm_num) [] (fun _ => wDigest)
        M := shdP_outcM (rndOf c)
        TH := fun _ => mkPcsTable 12 2 256 (by norm_num) [] (fun _ => wDigest)
        TB := TBOf H s x c
        slot := polySlotData (shdVo tag Rp wDigest bOutRow s.verdict).bp shdP_U shdP_hbij
          (fun _ _ _ _ _ => Fp2.zero) (fun _ _ _ _ _ _ => 0) (fun _ _ _ _ _ _ => []) }

/-- **Top-level Stage OUT-C `SegComplete` theorem**: discharges `hsegOut` of
`RunShieldOpenShell.sshC_productionReadyL_epP_openShell` completely from `Rp.out.Valid`,
verdict consistency `hVerdict`, and Block 25's boundary table contract `hTB`! -/
theorem shdP_outc_segComplete_of_adm {Hdr Coins : Type} (tag : MTag) (Lq : ℕ)
    (Rp : ClassifyRunPublicP shieldS0) (hOut : Rp.out.Valid) (wDigest : Dig) (bOutRow : ℕ)
    (TBOf : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → Table)
    (rndOf : Coins → OutcRand)
    (stOf : (QB Lq → Dig) → (shieldS0.Tok → ℕ) → Coins → ClsStmt Hdr)
    (hVerdict : ∀ G x c, (classifyModelP Rp).admissible x →
      (stOf G x c).verdict = (classifySpecP Rp x).getD 0)
    (hTB : ∀ G x c (hx : (classifyModelP Rp).admissible x),
      BndTableSpec (outcWitness_of_adm Rp hOut x hx).y25 Rp.row (TBOf (liftH G) (stOf G x c) x c)) :
    SegComplete (classifyModelP Rp).admissible (fun G : QB Lq → Dig => liftH G) stOf
      (outSegP _ (shdP_outcP tag Rp wDigest bOutRow
        (shdP_outcTables_total tag Rp hOut wDigest bOutRow TBOf rndOf)))
      (outSeg (outcStageV (fun (_ : Hdr) v => shdVo tag Rp wDigest bOutRow v)
        (fun _ => shdGo tag Rp wDigest bOutRow))) := by
  refine shdP_outc_segComplete tag Rp wDigest bOutRow (classifyModelP Rp).admissible
    (fun G : QB Lq → Dig => liftH G) stOf
    (shdP_outcTables_total tag Rp hOut wDigest bOutRow TBOf rndOf) ?_
  intro G x c cr t R hx hR
  set w := outcWitness_of_adm Rp hOut x hx with hw_def
  have hv_eq : (stOf G x c).verdict = w.v := by
    rw [hVerdict G x c hx, w.hv_spec]; rfl
  have hct_eq : shdP_outcTables_total tag Rp hOut wDigest bOutRow TBOf rndOf (liftH G) (stOf G x c) x c
      = shdP_outcTables tag Rp wDigest bOutRow (stOf G x c).verdict w (TBOf (liftH G) (stOf G x c) x c) (rndOf c) := by
    unfold shdP_outcTables_total; exact dite_eq_left hx
  rw [hct_eq] at hR ⊢
  revert hR
  rw [hv_eq]
  intro hR
  exact shdP_outc_arith (liftH G) tag Rp hOut wDigest bOutRow w
    (TBOf (liftH G) (stOf G x c) x c) (hTB G x c hx) (rndOf c) cr t R hR

end StageOutComplete

end ZK60.HonestShield
