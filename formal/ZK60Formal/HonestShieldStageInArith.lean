/-
D63 lane L68c, part 1b-ii (`HonestShieldStageInArith.lean`):
complete, zero-`sorry` Stage IN-C slot arithmetic (`INC-00..03`), `IncAccInv` induction,
`shdP_inc_arith` (all 20 conjuncts of `HonestShieldStages.shdP_inc_segComplete`'s `hArith`),
`shdP_inc_outClaims_true` (`ClaimTrue` on `TB_in` for Block 0), and top-level
**`shdP_inc_segComplete_of_adm`** discharging `hsegIn` of `RunShieldOpenShell.sshC_productionReadyL_epP_openShell`!

Only at most `propext`, `Classical.choice`, `Quot.sound`; zero `sorry`s.
-/
import ZK60Formal.HonestShieldStageInTables
import ZK60Formal.RunStgShieldIncZS

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound ZK60.TokenRun ZK60.StageX
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape
open ZK60.RunShape.Shield (shieldS0)
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (BlockParams SlotDef Hist SlotRec Acc Claims4 Cm Tab)

/-! ## 1. Common helpers for Stage IN-C slots (`0..3`) -/

section StageInSlotHelpers

/-- Split `cubeSum` on `Fin (n + 1) → Bool` into `y = false` (`cptS n b`) and `y = true`. -/
theorem cubeSum_split_ext {K : Type} [Field K] (n : ℕ) (F : (Fin (n + 1) → K) → K)
    (hy1 : ∀ w : Fin (n + 1) → Bool, w ⟨n, by omega⟩ = true → F (fun i => (bit (w i) : K)) = 0) :
    cubeSum F = ∑ b : Fin n → Bool, F (fun i => (bit (cptS n b i) : K)) := by
  unfold cubeSum
  rw [← Finset.sum_filter_add_sum_filter_not Finset.univ (fun w : Fin (n + 1) → Bool => w ⟨n, by omega⟩ = false)]
  have htrue : ∑ w ∈ Finset.univ.filter (fun w : Fin (n + 1) → Bool => ¬ w ⟨n, by omega⟩ = false),
      F (fun i => (bit (w i) : K)) = 0 := by
    refine Finset.sum_eq_zero (fun w hw => ?_)
    have hnf := (Finset.mem_filter.mp hw).2
    have ht : w ⟨n, by omega⟩ = true := by cases h : w ⟨n, by omega⟩ <;> simp_all
    exact hy1 w ht
  rw [htrue, add_zero]
  refine Finset.sum_bij (fun (w : Fin (n + 1) → Bool) (_ : w ∈ Finset.univ.filter _) =>
      (fun j : Fin n => w ⟨j.val, by omega⟩))
    (fun _ _ => Finset.mem_univ _)
    (fun w₁ hw₁ w₂ hw₂ h => by
      have hf1 := (Finset.mem_filter.mp hw₁).2
      have hf2 := (Finset.mem_filter.mp hw₂).2
      funext i
      by_cases hi : i.val < n
      · exact congrFun h ⟨i.val, hi⟩
      · have hin : i = ⟨n, by omega⟩ := Fin.ext (by have := i.isLt; omega)
        rw [hin, hf1, hf2])
    (fun b _ => ⟨cptS n b, Finset.mem_filter.mpr ⟨Finset.mem_univ _, by simp [cptS]⟩,
      by funext j; simp [cptS, j.isLt]⟩)
    (fun w hw => by
      have hf := (Finset.mem_filter.mp hw).2
      congr 1; funext i; congr 1
      unfold cptS
      by_cases hi : i.val < n
      · rw [dite_eq_left hi]
      · rw [dite_eq_right hi]
        have hin : i = ⟨n, by omega⟩ := Fin.ext (by have := i.isLt; omega)
        rw [hin, hf])

/-- At `w ⟨n, _⟩ = true`, `Block.selK n 1 (bitv w) = 0`. -/
theorem selK_ext_true {K : Type} [Field K] (n : ℕ) (w : Fin (n + 1) → Bool) (hw : w ⟨n, by omega⟩ = true) :
    Block.selK n 1 (fun i : Fin (n + 1) => (bit (w i) : K)) = 0 := by
  unfold Block.selK Block.yeK Block.xg
  rw [Finset.prod_range_one, Nat.add_zero, dite_eq_left (by omega)]
  dsimp only
  rw [hw]
  simp [bit]

/-- `stgTabK` on `.eq` or `.pub` vanishes whenever `selK n 1 x = 0`. -/
theorem stgTabK_eq_zero_of_selK {P : BlockParams} {cs : Cm → Block.ZClaim → shdP_K}
    {n : ℕ} {x : Fin (n + 1) → shdP_K} (hs : Block.selK n 1 x = 0) (pt : List Fp2) (st : ℕ) :
    stgTabK shdP_U shdP_hbij P cs n 1 x (.eq pt st) = 0 := by
  unfold stgTabK stgTabW
  dsimp only
  split_ifs
  · rw [hs, zero_mul]
  · rfl

theorem stgTabK_pub_zero_of_selK {P : BlockParams} {cs : Cm → Block.ZClaim → shdP_K}
    {n : ℕ} {x : Fin (n + 1) → shdP_K} (hs : Block.selK n 1 x = 0) (pv : List Fp2) :
    stgTabK shdP_U shdP_hbij P cs n 1 x (.pub pv) = 0 := by
  unfold stgTabK stgTabW
  dsimp only
  split_ifs
  · rw [hs, zero_mul]
  · rfl

/-- `stgTabK` on `.pub pv` at `cptS n b` evaluates directly to `(pv.getD (msbIndex n b) Fp2.zero).toK shdP_U`. -/
theorem stgTabK_pub_cptS {P : BlockParams} {cs : Cm → Block.ZClaim → shdP_K}
    {n : ℕ} (pv : List Fp2) (hpv : pv.length = 2 ^ n) (b : Fin n → Bool) :
    stgTabK shdP_U shdP_hbij P cs n 1 (fun i : Fin (n + 1) => (bit (cptS n b i) : shdP_K)) (.pub pv)
      = (pv.getD (msbIndex n b) Fp2.zero).toK shdP_U := by
  unfold stgTabK stgTabW
  dsimp only
  rw [ite_eq_left hpv, selK_cptS n b rfl, one_mul]
  have hx : (fun a : Fin n => Block.xrK n (fun i : Fin (n + 1) => (bit (cptS n b i) : shdP_K)) a.val)
      = fun a : Fin n => (bit (b a) : shdP_K) := by
    funext a
    exact xrK_cptS n b a.val a.isLt (by omega)
  rw [hx, mleAt_bitv]

/-- `stgTabK` on `.eq` has `IndDegLE 1` (for any domain width `N`). -/
theorem stgTabK_eq_indDeg {P : BlockParams} {cs : Cm → Block.ZClaim → shdP_K}
    {N n : ℕ} (pt : List Fp2) (st : ℕ) :
    IndDegLE 1 (fun x : Fin N → shdP_K => stgTabK shdP_U shdP_hbij P cs n 1 x (.eq pt st)) := by
  by_cases hle : st + pt.length ≤ n
  · have hfn : (fun x : Fin N → shdP_K => stgTabK shdP_U shdP_hbij P cs n 1 x (.eq pt st))
        = fun x => Block.selK n 1 x * eqPoly (fun a : Fin pt.length => (pt.getD a Fp2.zero).toK shdP_U)
            (fun a : Fin pt.length => Block.xrK n x (st + a)) := by
      funext x; unfold stgTabK stgTabW; exact ite_eq_left hle
    rw [hfn]
    exact Block.indDegLE_one_of_affAt (fun i => Block.affAt_eqTab shdP_U n 1 pt st i)
  · have hfn : (fun x : Fin N → shdP_K => stgTabK shdP_U shdP_hbij P cs n 1 x (.eq pt st))
        = fun _ => 0 := by
      funext x; unfold stgTabK stgTabW; exact ite_eq_right hle
    rw [hfn]
    exact IndDegLE.const 0

/-- `stgTabK` on `.pub` has `IndDegLE 1` (for any domain width `N`). -/
theorem stgTabK_pub_indDeg {P : BlockParams} {cs : Cm → Block.ZClaim → shdP_K}
    {N n : ℕ} (pv : List Fp2) :
    IndDegLE 1 (fun x : Fin N → shdP_K => stgTabK shdP_U shdP_hbij P cs n 1 x (.pub pv)) := by
  by_cases hlen : pv.length = 2 ^ n
  · have hfn : (fun x : Fin N → shdP_K => stgTabK shdP_U shdP_hbij P cs n 1 x (.pub pv))
        = fun x => Block.selK n 1 x * mleAt (fun b : Fin n → Bool => (pv.getD (msbIndex n b) Fp2.zero).toK shdP_U)
            (fun a : Fin n => Block.xrK n x a) := by
      funext x; unfold stgTabK stgTabW; exact ite_eq_left hlen
    rw [hfn]
    exact Block.indDegLE_one_of_affAt (fun i => Block.affAt_pubTab n 1 _ i)
  · have hfn : (fun x : Fin N → shdP_K => stgTabK shdP_U shdP_hbij P cs n 1 x (.pub pv))
        = fun _ => 0 := by
      funext x; unfold stgTabK stgTabW; exact ite_eq_right hlen
    rw [hfn]
    exact IndDegLE.const 0

/-- Helper: `incDefQZC` returning `.ok df` on canonical `dr` of length 17 equals `incDefQZC_ok`'s `df`. -/
theorem incDefQZC_eq_of_ok (I : IncPub) (G : IncGeo) (cx : IncCtx) (hti : I.tiLog = 12)
    (dr : List Fp2) (hlen : dr.length = 17) (hcan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : incDefQZC I G cx dr = .ok df) :
    let L := incLay I G.bLogN
    let tl := I.tiLog
    let sn := 2 ^ tl
    let b2 := cx.beta.mul cx.beta
    let mu := (dr.drop tl).take 4
    let zeta := (((dr.drop (tl + 4)).take 1).getD 0 Fp2.zero)
    df = ⟨[
      .eq (dr.take tl) 0,
      .pub (supp I.tokens sn),
      .pub (supp 1 sn),
      .pub ((List.range sn).map (fun t => if I.isTemplate t then Fp2.one else Fp2.zero)),
      .pub ((List.range sn).map (fun t => kI (I.kappa t))),
      .pub ((List.range sn).map (fun t => if I.ctlQ t then b2 else Fp2.zero)),
      .priv ⟨.a, [(L.aOff incA_TOK, Fp2.one)], L.aLog.getD incA_TOK 0,
        rhoC 0 (L.aLog.getD incA_TOK 0), L.aMaskBase + 2 * (L.prefixA 1 + 0), 0⟩,
      .priv ⟨.h, [((L.hOff incH_Q).1, Fp2.one), ((L.hOff incH_Q).2, Block.fp2U)],
        L.hLog.getD incH_Q 0, rhoC 0 (L.hLog.getD incH_Q 0), L.hMaskBase + 2 * (L.prefixH 1 + 0), 0⟩,
      .priv ⟨.out, [(0, Fp2.one)], I.bInLog, rhoC (tl - I.tBits) tl ++ fixedC cx.rEmb, G.bInRow, 0⟩
    ], (fun v =>
      let q := (((vg v 6).add (cx.beta.mul (vg v 8))).add (vg v 5)).add cx.gEmb
      let logup := ((vg v 7).mul (cx.alpha.sub q)).sub (vg v 1)
      let bosC := (vg v 2).mul ((vg v 6).sub (kI I.bos))
      let tmpl := (vg v 3).mul ((vg v 6).sub (vg v 4))
      let pad := (Fp2.one.sub (vg v 1)).mul ((vg v 6).add (zeta.mul (vg v 7)))
      (vg v 0).mul (((((vg mu 0).mul logup).add ((vg mu 1).mul bosC)).add ((vg mu 2).mul tmpl)).add
        ((vg mu 3).mul pad))), []⟩ := by
  let y : Fin 17 → shdP_K := vecK shdP_U 17 dr
  have hwords : stgWords shdP_U shdP_hbij y = dr :=
    stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 17 hlen
  have hne : ∀ i ∈ Z_range 17 I.tiLog 5, y i ≠ 0 := by
    intro i hi hy0
    obtain ⟨msg, hmsg⟩ := incDefQZC_err shdP_U shdP_hbij shdP_hU I G cx y ⟨i, hi, hy0⟩
    rw [hwords] at hmsg
    rw [hmsg] at hdef
    cases hdef
  have hok := incDefQZC_ok shdP_U shdP_hbij shdP_hU I G cx (by omega) y hne
  dsimp only at hok
  rw [hwords] at hok
  rw [hok] at hdef
  exact (Except.ok.inj hdef).symm

/-- Helper: `incDefTZC` returning `.ok df` on canonical `dr` of length 20 equals `incDefTZC_ok`'s `df`. -/
theorem incDefTZC_eq_of_ok (I : IncPub) (G : IncGeo) (cx : IncCtx) (hvoc : I.vocLog = 17)
    (dr : List Fp2) (hlen : dr.length = 20) (hcan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : incDefTZC I G cx dr = .ok df) :
    let L := incLay I G.bLogN
    let lv := I.vocLog
    let mu := (dr.drop lv).take 2
    let zeta := (((dr.drop (lv + 2)).take 1).getD 0 Fp2.zero)
    df = ⟨[
      .eq (dr.take lv) 0,
      .pub (supp I.v (2 ^ lv)),
      .pub cx.tauTab,
      .priv ⟨.a, [(L.aOff incA_MULT, Fp2.one)], L.aLog.getD incA_MULT 0,
        rhoC 0 (L.aLog.getD incA_MULT 0), L.aMaskBase + 2 * (L.prefixA 2 + 0), 0⟩,
      .priv ⟨.h, [((L.hOff incH_TAB).1, Fp2.one), ((L.hOff incH_TAB).2, Block.fp2U)],
        L.hLog.getD incH_TAB 0, rhoC 0 (L.hLog.getD incH_TAB 0), L.hMaskBase + 2 * (L.prefixH 2 + 0), 0⟩
    ], (fun v =>
      let rel := ((vg v 4).mul (cx.alpha.sub (vg v 2))).sub (vg v 3)
      let pad := (Fp2.one.sub (vg v 1)).mul ((vg v 3).add (zeta.mul (vg v 4)))
      (vg v 0).mul (((vg mu 0).mul rel).add ((vg mu 1).mul pad))), []⟩ := by
  let y : Fin 20 → shdP_K := vecK shdP_U 20 dr
  have hwords : stgWords shdP_U shdP_hbij y = dr :=
    stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 20 hlen
  have hne : ∀ i ∈ Z_range 20 I.vocLog 3, y i ≠ 0 := by
    intro i hi hy0
    obtain ⟨msg, hmsg⟩ := incDefTZC_err shdP_U shdP_hbij shdP_hU I G cx y ⟨i, hi, hy0⟩
    rw [hwords] at hmsg
    rw [hmsg] at hdef
    cases hdef
  have hok := incDefTZC_ok shdP_U shdP_hbij shdP_hU I G cx (by omega) y hne
  dsimp only at hok
  rw [hwords] at hok
  rw [hok] at hdef
  exact (Except.ok.inj hdef).symm

end StageInSlotHelpers

/-! ## 2. Per-slot `IndDegLE` and `cubeSum = 0` for `INC-00..03` -/

section StageInSlotArith

variable {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
  (hP : Rp.inp.Valid) (hV : Rp.inp.V = 131072) (embDigest : Dig) (bInRow : ℕ)
  (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
  (epR : EpxSalt 6) (rnd : IncRand)

/-- Slot 0 (`INC-00`): `IndDegLE 3` and `cubeSum (slotPolyK ...) = 0`. -/
theorem inc_slot0_arith (ch : List Fp2) (dr : List Fp2) (hdrCan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : incDefIO (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow) dr = .ok df) :
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    let elog := incElog V.pub 14
    let cs := incCs (shdP_incTA x rnd) (shdP_incTH Rp embDigest x rnd ch)
      (shdP_epTable (Hdr := Hdr) tag x epR) (shdP_incTB Rp x rnd)
    IndDegLE 3 (slotPolyK P elog cs 0 df)
      ∧ cubeSum (slotPolyK P elog cs 0 df) = 0
      ∧ df.hosted = []
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P elog cs
  have hok := incDefIO_ok V.pub V.geo dr
  dsimp only at hok
  rw [hok] at hdef
  have hdf := (Except.ok.inj hdef).symm
  subst hdf
  let I := V.pub
  let L := incLay I 14
  have hti : I.tiLog = 12 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).1
  have hep : I.inEpWords = 256 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.2.1
  have hlw : clog2 I.inEpWords = 8 := by rw [hep]; exact shdP_clog2_256
  have haOff0 : L.aOff incA_TOK = 0 := by simp [L, incLay, Lay.aOff, incA_TOK]
  have haLog0 : L.aLog.getD incA_TOK 0 = 12 := by simp [L, incLay, incA_TOK, hti]
  have hsh0 : Exec.Block.slotShape P 0 = (8, 1, 3) := by
    show (incLay I 14).geomSlots.getD 0 (0, 0, 0) = (8, 1, 3)
    simp [incLay, Lay.geomSlots, incSched, hlw]
  have hN0 : slotN P 0 = 9 := by unfold slotN; rw [hsh0]
  let Ps := atLog P (elog 0)
  have hrowA : Block.rowLog Ps .a = 12 := rfl
  have hrowIn : Block.rowLog Ps .inp = 8 := rfl
  -- Compute `slotPolyK` via `tabVals_stgTabK`
  let tabs := [
    Tab.eq (dr.take (clog2 I.inEpWords)) 0,
    Tab.pub (supp I.tokens I.inEpWords),
    Tab.priv ⟨.a, [(L.aOff incA_TOK, Fp2.one)], L.aLog.getD incA_TOK 0,
      fixedC (List.replicate (I.tiLog - clog2 I.inEpWords) Fp2.zero) ++ rhoC 0 (clog2 I.inEpWords),
      L.aMaskBase + 2 * (L.prefixA 0 + 0), 0⟩,
    Tab.priv ⟨.inp, [(0, Fp2.one)], clog2 I.inEpWords, rhoC 0 (clog2 I.inEpWords), V.geo.epDataRows, 0⟩]
  have hfit : tabsFit 8 tabs := by
    intro t ht
    simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl
    · show 0 + (dr.take (clog2 I.inEpWords)).length ≤ 8
      rw [hlw, Nat.zero_add]; exact List.length_take_le _ _
    · show (supp I.tokens I.inEpWords).length = 2 ^ 8
      simp [supp, hep]
    · trivial
    · trivial
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st heq a ha
    simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl
    · cases heq; exact hdrCan a (List.mem_of_mem_take ha)
    · cases heq
    · cases heq
    · cases heq
  let g : ℕ → (Fin (slotN P 0) → shdP_K) → shdP_K := fun j x =>
    (tabs.map (stgTabK shdP_U shdP_hbij Ps cs 8 1 x)).getD j 0
  have hpoly : ∀ x : Fin (slotN P 0) → shdP_K,
      slotPolyK P elog cs 0 ⟨tabs, (fun v => (vg v 0).mul ((vg v 3).sub ((vg v 1).mul (vg v 2)))), []⟩ x
        = g 0 x * (g 3 x - g 1 x * g 2 x) := by
    intro x
    unfold slotPolyK
    have hsh1 : (Exec.Block.slotShape P 0).1 = 8 := by rw [hsh0]
    dsimp only
    rw [hsh1]
    obtain ⟨vals, htv, hvcan, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU Ps cs 8 1 hN0 x tabs hfit hcan
    rw [htv]
    have hvg : ∀ i, (vg vals i).toK shdP_U = g i x := fun i => by
      rw [vg_toK_map, hvmap]
    rw [Fp2.toK_mul shdP_U shdP_hU,
      Fp2.toK_sub shdP_U _ _ (vg_canon hvcan 3) (Fp2.canon_mul _ _),
      Fp2.toK_mul shdP_U shdP_hU, hvg 0, hvg 1, hvg 2, hvg 3]
  have hfunEq : slotPolyK P elog cs 0 ⟨tabs, (fun v => (vg v 0).mul ((vg v 3).sub ((vg v 1).mul (vg v 2)))), []⟩
      = fun x => g 0 x * (g 3 x - g 1 x * g 2 x) := funext hpoly
  -- Individual degree ≤ 1 for all 4 tables `g 0 .. g 3`
  have hg0 : IndDegLE 1 (g 0) := stgTabK_eq_indDeg _ _
  have hg1 : IndDegLE 1 (g 1) := stgTabK_pub_indDeg _
  have hg2 : IndDegLE 1 (g 2) := by
    exact indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU Ps 41 12 0 (tabMat 41 12 (shdP_incTA x rnd).rows)
      (N := slotN P 0) 8 1 hN0
      ⟨.a, [(L.aOff incA_TOK, Fp2.one)], L.aLog.getD incA_TOK 0,
        fixedC (List.replicate (I.tiLog - clog2 I.inEpWords) Fp2.zero) ++ rhoC 0 (clog2 I.inEpWords),
        L.aMaskBase + 2 * (L.prefixA 0 + 0), 0⟩
      (by simp) (by rw [haLog0, hrowA]; norm_num)
      (by
        have := varsOKb_fixed_rho_fixed (fixedC (List.replicate (I.tiLog - clog2 I.inEpWords) Fp2.zero)) [] 0 (clog2 I.inEpWords)
          (by intro c hc; obtain ⟨_, -, rfl⟩ := List.mem_map.mp hc; rfl)
          (by intro c hc; cases hc)
        simpa using this)
      (by
        intro c hc w hw
        rcases List.mem_append.mp hc with h1 | h2
        · obtain ⟨_, hrep, hEq⟩ := List.mem_map.mp h1
          have h0 : _ = Fp2.zero := (List.mem_replicate.mp hrep).2
          rw [h0] at hEq
          rw [hw] at hEq; cases hEq; exact Fp2.canon_zero
        · obtain ⟨_, -, hEq⟩ := List.mem_map.mp h2
          rw [hw] at hEq; cases hEq)
  have hg3 : IndDegLE 1 (g 3) :=
    indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU Ps 6 8 0 (tabMat 6 8 (shdP_epTable (Hdr := Hdr) tag x epR).rows)
      (N := slotN P 0) 8 1 hN0
      ⟨.inp, [(0, Fp2.one)], clog2 I.inEpWords, rhoC 0 (clog2 I.inEpWords), V.geo.epDataRows, 0⟩
      (by simp) (by rw [hlw, hrowIn]; norm_num)
      (by
        have := varsOKb_fixed_rho_fixed [] [] 0 (clog2 I.inEpWords) (by intro _ h; cases h) (by intro _ h; cases h)
        simpa using this)
      (by
        intro c hc w hw
        obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc
        rw [hw] at hEq; cases hEq)
  refine ⟨?_, ?_, rfl, fun _ => Fp2.canon_mul _ _⟩
  · rw [hfunEq]
    have h12 : IndDegLE 2 (fun z => g 1 z * g 2 z) := IndDegLE.mul hg1 hg2
    have hdiff : IndDegLE 2 (fun z => g 3 z - g 1 z * g 2 z) := IndDegLE.sub (IndDegLE.mono hg3 (by norm_num)) h12
    exact IndDegLE.mul hg0 hdiff
  · rw [hfunEq]
    -- Cast `slotN P 0 = 8 + 1` to split `cubeSum`
    have hcast : ∀ (F : (Fin (slotN P 0) → shdP_K) → shdP_K),
        (∀ w : Fin (slotN P 0) → Bool, F (fun i => (bit (w i) : shdP_K)) = 0) → cubeSum F = 0 := by
      intro F hF
      unfold cubeSum
      exact Finset.sum_eq_zero (fun w _ => hF w)
    refine hcast _ (fun w => ?_)
    by_cases hw8 : w ⟨8, by omega⟩ = true
    · have hs0 : Block.selK 8 1 (fun i : Fin (slotN P 0) => (bit (w i) : shdP_K)) = 0 := by
        unfold Block.selK Block.yeK Block.xg
        rw [Finset.prod_range_one, Nat.add_zero, dite_eq_left (by omega)]
        dsimp only; rw [hw8]; simp [bit]
      have hg0z : g 0 (fun i => (bit (w i) : shdP_K)) = 0 := by
        show stgTabK shdP_U shdP_hbij Ps cs 8 1 (fun i => (bit (w i) : shdP_K)) _ = 0
        unfold stgTabK stgTabW; dsimp only; split_ifs; · rw [hs0, zero_mul]; · rfl
      rw [hg0z, zero_mul]
    · have hwf : w ⟨8, by omega⟩ = false := by cases h : w ⟨8, by omega⟩ <;> simp_all
      let b : Fin 8 → Bool := fun j => w ⟨j.val, by omega⟩
      have hwEq : w = cptS 8 b := by
        funext i
        unfold cptS
        by_cases hi : i.val < 8
        · rw [dite_eq_left hi]
        · rw [dite_eq_right hi]
          have hin : i = ⟨8, by omega⟩ := Fin.ext (by have := i.isLt; omega)
          rw [hin, hwf]
      rw [hwEq]
      -- Evaluate `g 1`, `g 2`, `g 3` at `cptS 8 b`: `g 3 - g 1 * g 2 = 0`!
      have hg1v : g 1 (fun i => (bit (cptS 8 b i) : shdP_K))
          = if msbIndex 8 b < 128 then 1 else 0 := by
        show stgTabK shdP_U shdP_hbij Ps cs 8 1 _ (.pub (supp I.tokens I.inEpWords)) = _
        have hlen : (supp I.tokens I.inEpWords).length = 2 ^ 8 := by simp [supp, hep]
        unfold stgTabK stgTabW
        dsimp only
        rw [ite_eq_left hlen, selK_cptS 8 b hN0, one_mul]
        have hxB : (fun a : Fin 8 => Block.xrK 8 (fun i : Fin (slotN P 0) => (bit (cptS 8 b i) : shdP_K)) a.val)
            = fun a : Fin 8 => (bit (b a) : shdP_K) := funext fun a => xrK_cptS 8 b a.val a.isLt (by omega)
        rw [hxB, mleAt_bitv]
        have hlt256 : msbIndex 8 b < 256 := msbIndex_lt 8 b
        exact supp_getD_toK shdP_U 128 256 (msbIndex 8 b) hlt256
      have hg2v : g 2 (fun i => (bit (cptS 8 b i) : shdP_K))
          = if h : msbIndex 8 b < 128 then (x ⟨msbIndex 8 b, h⟩ : shdP_K) else 0 := by
        let p2 : Block.Priv := ⟨.a, [(L.aOff incA_TOK, Fp2.one)], L.aLog.getD incA_TOK 0,
          fixedC (List.replicate (I.tiLog - clog2 I.inEpWords) Fp2.zero) ++ rhoC 0 (clog2 I.inEpWords),
          L.aMaskBase + 2 * (L.prefixA 0 + 0), 0⟩
        have h0 := claimSem_priv_cube_y0 Ps 41 12 (tabMat 41 12 (shdP_incTA x rnd).rows) 8 hN0 b p2
          (L.aOff incA_TOK, Fp2.one) [] rfl (by rw [haLog0, hrowA]; norm_num)
          (by
            intro c hc w hw
            rcases List.mem_append.mp hc with h1 | h2
            · obtain ⟨_, hrep, hEq⟩ := List.mem_map.mp h1
              rw [(List.mem_replicate.mp hrep).2] at hEq
              rw [hw] at hEq; cases hEq; exact Fp2.canon_zero
            · obtain ⟨_, -, hEq⟩ := List.mem_map.mp h2
              rw [hw] at hEq; cases hEq)
        change Link.claimSem shdP_U 41 12 0 (tabMat 41 12 (shdP_incTA x rnd).rows) _ = _
        rw [h0]
        simp only [p2, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
          Fp2.toK_one, one_mul, haOff0, haLog0, fixedC, rhoC, List.length_append, List.length_map,
          List.length_replicate, List.length_range', Nat.sub_zero, hti, hlw]
        let c12 : Fin 12 → Bool := fun i => if h : i.val < 4 then false else b ⟨i.val - 4, by omega⟩
        have hpt12 : ∀ a : Fin 12,
            Block.ptK shdP_U (Block.xrK 8 (fun i : Fin (slotN P 0) => (bit (cptS 8 b i) : shdP_K)))
              (fixedC (List.replicate (12 - 8) Fp2.zero) ++ rhoC 0 8) a.val = (bit (c12 a) : shdP_K) := by
          intro a
          unfold Block.ptK c12
          by_cases ha4 : a.val < 4
          · rw [dite_eq_left ha4]
            have hget : (fixedC (List.replicate 4 Fp2.zero) ++ rhoC 0 8).getD a.val (Block.Coord.fixed Fp2.zero)
                = Block.Coord.fixed Fp2.zero := by
              rw [List.getD_eq_getElem?_getD, List.getElem?_append_left (by simp [fixedC]; omega)]
              simp [fixedC, ha4]
            rw [show 12 - 8 = 4 by norm_num, hget]
            simp [Fp2.toK_zero, bit]
          · rw [dite_eq_right ha4]
            have hget : (fixedC (List.replicate 4 Fp2.zero) ++ rhoC 0 8).getD a.val (Block.Coord.fixed Fp2.zero)
                = Block.Coord.rho (a.val - 4) := by
              rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by simp [fixedC]; omega)]
              have hlt8 : a.val - 4 < 8 := by have := a.isLt; omega
              simp [fixedC, rhoC, List.getElem?_range' hlt8]
            rw [show 12 - 8 = 4 by norm_num, hget]
            exact xrK_cptS 8 b (a.val - 4) (by have := a.isLt; omega) (by omega)
        have hsl := data_slice_single_row 41 12 0 (by norm_num) (tabMat 41 12 (shdP_incTA x rnd).rows) c12 _ hpt12
        simp only [Nat.zero_mul] at hsl
        rw [show (12 - 8) + 8 = 12 by norm_num]
        rw [hsl]
        unfold shdP_incTA
        rw [tabMat_mkRows]
        unfold shdP_incTAData
        dsimp only
        rw [ite_eq_left rfl, msbIndex_pad4]
        by_cases h128 : msbIndex 8 b < 128
        · rw [dite_eq_left h128, dite_eq_left h128, Fp.toGF_ofGF, map_natCast]
        · rw [dite_eq_right h128, dite_eq_right h128]; simp [Fp.toGF, Fp.zero]
      have hg3v : g 3 (fun i => (bit (cptS 8 b i) : shdP_K))
          = if h : msbIndex 8 b < 128 then (x ⟨msbIndex 8 b, h⟩ : shdP_K) else 0 := by
        let p3 : Block.Priv := ⟨.inp, [(0, Fp2.one)], clog2 I.inEpWords, rhoC 0 (clog2 I.inEpWords), V.geo.epDataRows, 0⟩
        have h0 := claimSem_priv_cube_y0 Ps 6 8 (tabMat 6 8 (shdP_epTable (Hdr := Hdr) tag x epR).rows) 8 hN0 b p3
          (0, Fp2.one) [] rfl (by rw [hlw, hrowIn]; norm_num)
          (by intro c hc w hw; obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc; rw [hw] at hEq; cases hEq)
        change Link.claimSem shdP_U 6 8 0 (tabMat 6 8 (shdP_epTable (Hdr := Hdr) tag x epR).rows) _ = _
        rw [h0]
        simp only [p3, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
          Fp2.toK_one, one_mul, hlw, rhoC, List.length_map, List.length_range', Nat.sub_zero]
        have hpt8 : ∀ a : Fin 8,
            Block.ptK shdP_U (Block.xrK 8 (fun i : Fin (slotN P 0) => (bit (cptS 8 b i) : shdP_K)))
              (rhoC 0 8) a.val = (bit (b a) : shdP_K) := by
          intro a
          unfold Block.ptK
          have hget : (rhoC 0 8).getD a.val (Block.Coord.fixed Fp2.zero) = Block.Coord.rho a.val := by
            simp [rhoC, List.getD_eq_getElem?_getD, List.getElem?_range' a.isLt]
          rw [hget]
          exact xrK_cptS 8 b a.val a.isLt (by omega)
        have hsl := data_slice_single_row 6 8 0 (by norm_num) (tabMat 6 8 (shdP_epTable (Hdr := Hdr) tag x epR).rows) b _ hpt8
        simp only [Nat.zero_mul] at hsl
        rw [hsl]
        exact shdP_epTable_row0_val (Hdr := Hdr) tag x epR ⟨msbIndex 8 b, msbIndex_lt 8 b⟩
      rw [hg1v, hg2v, hg3v]
      by_cases h128 : msbIndex 8 b < 128
      · simp [h128]
      · simp [h128]

/-- Slot 1 (`INC-01`): `IndDegLE 4` and `cubeSum (slotPolyK ...) = 0`. -/
theorem inc_slot1_arith (ch : List Fp2) (hchLen : ch.length = 15) (hchCan : ∀ a ∈ ch, a.Canon)
    (hbad : incAlphaBad (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch) = false)
    (dr : List Fp2) (hdrLen : dr.length = 17) (hdrCan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : incDefQZC (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow)
      (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch) dr = .ok df) :
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    let elog := incElog V.pub 14
    let cs := incCs (shdP_incTA x rnd) (shdP_incTH Rp embDigest x rnd ch)
      (shdP_epTable (Hdr := Hdr) tag x epR) (shdP_incTB Rp x rnd)
    IndDegLE 4 (slotPolyK P elog cs 1 df)
      ∧ cubeSum (slotPolyK P elog cs 1 df) = 0
      ∧ df.hosted = []
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P elog cs
  obtain ⟨hxV, hxBos, hxT, -, hxCtl⟩ := inSpec_of_adm Rp hV x hx
  let I := V.pub
  let L := incLay I 14
  let cx := incCtx I ch
  have hti : I.tiLog = 12 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).1
  have hvoc : I.vocLog = 17 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.1
  have hlt : I.lt = 12 := rfl
  have htBits : I.tBits = 7 := by simp [I, IncPub.tBits, shdP_incPub, shdP_clog2_128]
  have hbInLog : I.bInLog = 19 := shdN_bIn tag Rp embDigest (embFoldL Rp.inp) bInRow
  have haOff0 : L.aOff incA_TOK = 0 := by simp [L, incLay, Lay.aOff, incA_TOK]
  have haLog0 : L.aLog.getD incA_TOK 0 = 12 := by simp [L, incLay, incA_TOK, hti]
  have hhOff0 : L.hOff incH_Q = (0, 4096) := by simp [L, incLay, Lay.hOff, Lay.hRowsL, Lay.n, rowsOf, incH_Q, hti, hvoc, hlt]
  have hhLog0 : L.hLog.getD incH_Q 0 = 12 := by simp [L, incLay, incH_Q, hti]
  have hdf := incDefQZC_eq_of_ok I V.geo cx hti dr hdrLen hdrCan df hdef
  subst hdf
  have hsh1 : Exec.Block.slotShape P 1 = (12, 1, 4) := by
    show (incLay I 14).geomSlots.getD 1 (0, 0, 0) = (12, 1, 4)
    simp [incLay, Lay.geomSlots, incSched, hti]
  have hN1 : slotN P 1 = 13 := by unfold slotN; rw [hsh1]
  let Ps := atLog P (elog 1)
  have hrowA : Block.rowLog Ps .a = 12 := rfl
  have hrowH : Block.rowLog Ps .h = 12 := rfl
  have hrowOut : Block.rowLog Ps .out = 14 := rfl
  let mu := (dr.drop I.tiLog).take 4
  let zeta := (((dr.drop (I.tiLog + 4)).take 1).getD 0 Fp2.zero)
  let tabs := [
    Tab.eq (dr.take I.tiLog) 0,
    Tab.pub (supp I.tokens (2 ^ I.tiLog)),
    Tab.pub (supp 1 (2 ^ I.tiLog)),
    Tab.pub ((List.range (2 ^ I.tiLog)).map (fun t => if I.isTemplate t then Fp2.one else Fp2.zero)),
    Tab.pub ((List.range (2 ^ I.tiLog)).map (fun t => kI (I.kappa t))),
    Tab.pub ((List.range (2 ^ I.tiLog)).map (fun t => if I.ctlQ t then cx.beta.mul cx.beta else Fp2.zero)),
    Tab.priv ⟨.a, [(L.aOff incA_TOK, Fp2.one)], L.aLog.getD incA_TOK 0,
      rhoC 0 (L.aLog.getD incA_TOK 0), L.aMaskBase + 2 * (L.prefixA 1 + 0), 0⟩,
    Tab.priv ⟨.h, [((L.hOff incH_Q).1, Fp2.one), ((L.hOff incH_Q).2, Block.fp2U)],
      L.hLog.getD incH_Q 0, rhoC 0 (L.hLog.getD incH_Q 0), L.hMaskBase + 2 * (L.prefixH 1 + 0), 0⟩,
    Tab.priv ⟨.out, [(0, Fp2.one)], I.bInLog, rhoC (I.tiLog - I.tBits) I.tiLog ++ fixedC cx.rEmb, V.geo.bInRow, 0⟩]
  have hfit : tabsFit 12 tabs := by
    intro t ht
    simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
    · show 0 + (dr.take I.tiLog).length ≤ 12; rw [hti, Nat.zero_add]; exact List.length_take_le _ _
    · show (supp I.tokens (2 ^ I.tiLog)).length = 2 ^ 12; simp [supp, hti]
    · show (supp 1 (2 ^ I.tiLog)).length = 2 ^ 12; simp [supp, hti]
    · show ((List.range (2 ^ I.tiLog)).map _).length = 2 ^ 12; simp [hti]
    · show ((List.range (2 ^ I.tiLog)).map _).length = 2 ^ 12; simp [hti]
    · show ((List.range (2 ^ I.tiLog)).map _).length = 2 ^ 12; simp [hti]
    · trivial
    · trivial
    · trivial
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st heq a ha
    simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
    · cases heq; exact hdrCan a (List.mem_of_mem_take ha)
    all_goals cases heq
  have halphaC : cx.alpha.Canon := Fp2.canon_getD hchCan 2
  have hgEmbC : cx.gEmb.Canon := Fp2.canon_mulBase _ _
  have hrEmbLen : cx.rEmb.length = 12 := by simp [cx, incCtx, hchLen]
  have hrEmbCan : ∀ a ∈ cx.rEmb, a.Canon := fun a ha => hchCan a (List.mem_of_mem_drop ha)
  let g : ℕ → (Fin (slotN P 1) → shdP_K) → shdP_K := fun j z =>
    (tabs.map (stgTabK shdP_U shdP_hbij Ps cs 12 1 z)).getD j 0
  have hpoly : ∀ z : Fin (slotN P 1) → shdP_K,
      slotPolyK P elog cs 1 ⟨tabs, _, []⟩ z
        = qzcPolyK shdP_U I cx ((vg mu 0).toK shdP_U) ((vg mu 1).toK shdP_U)
            ((vg mu 2).toK shdP_U) ((vg mu 3).toK shdP_U) (zeta.toK shdP_U) (fun j => g j z) := by
    intro z
    unfold slotPolyK
    have hsh1' : (Exec.Block.slotShape P 1).1 = 12 := by rw [hsh1]
    dsimp only
    rw [hsh1']
    obtain ⟨vals, htv, hvcan, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU Ps cs 12 1 hN1 z tabs hfit hcan
    rw [htv]
    have hvg : ∀ i, (vg vals i).toK shdP_U = g i z := fun i => by rw [vg_toK_map, hvmap]
    unfold qzcPolyK
    have hqC : ((((vg vals 6).add (cx.beta.mul (vg vals 8))).add (vg vals 5)).add cx.gEmb).Canon := Fp2.canon_add _ _
    rw [Fp2.toK_mul shdP_U shdP_hU,
      Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
      Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
      Fp2.toK_add shdP_U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
      Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU,
      Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU,
      Fp2.toK_sub shdP_U _ _ (Fp2.canon_mul _ _) (vg_canon hvcan 1),
      Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_sub shdP_U _ _ halphaC hqC,
      Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) hgEmbC,
      Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) (vg_canon hvcan 5),
      Fp2.toK_add shdP_U _ _ (vg_canon hvcan 6) (Fp2.canon_mul _ _),
      Fp2.toK_mul shdP_U shdP_hU,
      Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_sub shdP_U _ _ (vg_canon hvcan 6) (kI_canon _),
      Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_sub shdP_U _ _ (vg_canon hvcan 6) (vg_canon hvcan 4),
      Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_sub shdP_U _ _ Fp2.canon_one (vg_canon hvcan 1),
      Fp2.toK_add shdP_U _ _ (vg_canon hvcan 6) (Fp2.canon_mul _ _),
      Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_one,
      hvg 0, hvg 1, hvg 2, hvg 3, hvg 4, hvg 5, hvg 6, hvg 7, hvg 8]
  have hfunEq : slotPolyK P elog cs 1 ⟨tabs, _, []⟩
      = fun z => qzcPolyK shdP_U I cx ((vg mu 0).toK shdP_U) ((vg mu 1).toK shdP_U)
          ((vg mu 2).toK shdP_U) ((vg mu 3).toK shdP_U) (zeta.toK shdP_U) (fun j => g j z) := funext hpoly
  -- Individual degree ≤ 1 for all 9 tables
  have hg_deg : ∀ j, j < 9 → IndDegLE 1 (g j) := by
    intro j hj
    interval_cases j
    · exact stgTabK_eq_indDeg _ _
    · exact stgTabK_pub_indDeg _
    · exact stgTabK_pub_indDeg _
    · exact stgTabK_pub_indDeg _
    · exact stgTabK_pub_indDeg _
    · exact stgTabK_pub_indDeg _
    · exact indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU Ps 41 12 0 (tabMat 41 12 (shdP_incTA x rnd).rows)
        (N := slotN P 1) 12 1 hN1 _ (by simp) (by rw [haLog0, hrowA]; norm_num)
        (by
          have := varsOKb_fixed_rho_fixed [] [] 0 (L.aLog.getD incA_TOK 0) (by intro _ h; cases h) (by intro _ h; cases h)
          simpa using this)
        (by intro c hc w hw; obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc; rw [hw] at hEq; cases hEq)
    · exact indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU Ps 76 12 0 (tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows)
        (N := slotN P 1) 12 1 hN1 _ (by simp) (by rw [hhLog0, hrowH]; norm_num)
        (by
          have := varsOKb_fixed_rho_fixed [] [] 0 (L.hLog.getD incH_Q 0) (by intro _ h; cases h) (by intro _ h; cases h)
          simpa using this)
        (by intro c hc w hw; obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc; rw [hw] at hEq; cases hEq)
    · exact indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU Ps 38 14 0 (tabMat 38 14 (shdP_incTB Rp x rnd).rows)
        (N := slotN P 1) 12 1 hN1 _ (by simp) (by rw [hbInLog, hrowOut]; norm_num)
        (by
          have := varsOKb_fixed_rho_fixed [] (fixedC cx.rEmb) (I.tiLog - I.tBits) I.tiLog
            (by intro _ h; cases h) (by intro c hc; obtain ⟨_, -, rfl⟩ := List.mem_map.mp hc; rfl)
          simpa using this)
        (by
          intro c hc w hw
          rcases List.mem_append.mp hc with h1 | h2
          · obtain ⟨_, -, hEq⟩ := List.mem_map.mp h1; rw [hw] at hEq; cases hEq
          · obtain ⟨a, ha, hEq⟩ := List.mem_map.mp h2; rw [hw] at hEq; cases hEq; exact hrEmbCan w ha)
  refine ⟨?_, ?_, rfl, fun _ => Fp2.canon_mul _ _⟩
  · rw [hfunEq]
    unfold qzcPolyK
    have hd0 := hg_deg 0 (by omega); have hd1 := hg_deg 1 (by omega); have hd2 := hg_deg 2 (by omega)
    have hd3 := hg_deg 3 (by omega); have hd4 := hg_deg 4 (by omega); have hd5 := hg_deg 5 (by omega)
    have hd6 := hg_deg 6 (by omega); have hd7 := hg_deg 7 (by omega); have hd8 := hg_deg 8 (by omega)
    have hqD : IndDegLE 1 (fun z => (((g 6 z + cx.beta.toK shdP_U * g 8 z) + g 5 z) + cx.gEmb.toK shdP_U)) :=
      IndDegLE.add (IndDegLE.add (IndDegLE.add hd6 (IndDegLE.cmul _ hd8)) hd5) (IndDegLE.const _)
    have hluD : IndDegLE 2 (fun z => g 7 z * (cx.alpha.toK shdP_U - (((g 6 z + cx.beta.toK shdP_U * g 8 z) + g 5 z) + cx.gEmb.toK shdP_U)) - g 1 z) :=
      IndDegLE.sub (IndDegLE.mul hd7 (IndDegLE.sub (IndDegLE.const _) hqD)) (IndDegLE.mono hd1 (by norm_num))
    have hbosD : IndDegLE 2 (fun z => g 2 z * (g 6 z - (kI I.bos).toK shdP_U)) :=
      IndDegLE.mul hd2 (IndDegLE.sub hd6 (IndDegLE.const _))
    have htmpD : IndDegLE 2 (fun z => g 3 z * (g 6 z - g 4 z)) :=
      IndDegLE.mul hd3 (IndDegLE.sub hd6 hd4)
    have hpadD : IndDegLE 2 (fun z => (1 - g 1 z) * (g 6 z + zeta.toK shdP_U * g 7 z)) :=
      IndDegLE.mul (IndDegLE.sub (IndDegLE.const _) hd1) (IndDegLE.add hd6 (IndDegLE.cmul _ hd7))
    exact IndDegLE.mono (IndDegLE.mul hd0 (IndDegLE.add (IndDegLE.add (IndDegLE.add
      (IndDegLE.cmul _ hluD) (IndDegLE.cmul _ hbosD)) (IndDegLE.cmul _ htmpD)) (IndDegLE.cmul _ hpadD))) (by norm_num)
  · rw [hfunEq]
    unfold cubeSum
    refine Finset.sum_eq_zero (fun w _ => ?_)
    by_cases hw12 : w ⟨12, by omega⟩ = true
    · have hs0 : Block.selK 12 1 (fun i : Fin (slotN P 1) => (bit (w i) : shdP_K)) = 0 := by
        unfold Block.selK Block.yeK Block.xg
        rw [Finset.prod_range_one, Nat.add_zero, dite_eq_left (by omega)]
        dsimp only; rw [hw12]; simp [bit]
      have hg0z : g 0 (fun i => (bit (w i) : shdP_K)) = 0 := by
        show stgTabK shdP_U shdP_hbij Ps cs 12 1 _ _ = 0
        unfold stgTabK stgTabW; dsimp only; split_ifs; · rw [hs0, zero_mul]; · rfl
      unfold qzcPolyK; rw [hg0z, zero_mul]
    · have hwf : w ⟨12, by omega⟩ = false := by cases h : w ⟨12, by omega⟩ <;> simp_all
      let b : Fin 12 → Bool := fun j => w ⟨j.val, by omega⟩
      have hwEq : w = cptS 12 b := by
        funext i; unfold cptS
        by_cases hi : i.val < 12
        · rw [dite_eq_left hi]
        · rw [dite_eq_right hi]
          have hin : i = ⟨12, by omega⟩ := Fin.ext (by have := i.isLt; omega)
          rw [hin, hwf]
      rw [hwEq]
      let idx := msbIndex 12 b
      have hidxLt : idx < 4096 := msbIndex_lt 12 b
      -- Helper to evaluate any `.pub pv` (`pv.length = 4096`) at `cptS 12 b`
      have hpub : ∀ (pv : List Fp2), pv.length = 2 ^ 12 →
          stgTabK shdP_U shdP_hbij Ps cs 12 1 (fun i : Fin (slotN P 1) => (bit (cptS 12 b i) : shdP_K)) (.pub pv)
            = (pv.getD idx Fp2.zero).toK shdP_U := by
        intro pv hpv
        unfold stgTabK stgTabW; dsimp only
        rw [ite_eq_left hpv, selK_cptS 12 b hN1, one_mul]
        have hxB : (fun a : Fin 12 => Block.xrK 12 (fun i : Fin (slotN P 1) => (bit (cptS 12 b i) : shdP_K)) a.val)
            = fun a : Fin 12 => (bit (b a) : shdP_K) := funext fun a => xrK_cptS 12 b a.val a.isLt (by omega)
        rw [hxB, mleAt_bitv]
      have hg1 : g 1 (fun i => (bit (cptS 12 b i) : shdP_K)) = if idx < 128 then 1 else 0 := by
        show stgTabK shdP_U shdP_hbij Ps cs 12 1 _ (.pub (supp 128 (2 ^ I.tiLog))) = _
        rw [hpub _ (by simp [supp, hti]), hti]
        exact supp_getD_toK shdP_U 128 4096 idx hidxLt
      have hg2 : g 2 (fun i => (bit (cptS 12 b i) : shdP_K)) = if idx < 1 then 1 else 0 := by
        show stgTabK shdP_U shdP_hbij Ps cs 12 1 _ (.pub (supp 1 (2 ^ I.tiLog))) = _
        rw [hpub _ (by simp [supp, hti]), hti]
        exact supp_getD_toK shdP_U 1 4096 idx hidxLt
      have hg3 : g 3 (fun i => (bit (cptS 12 b i) : shdP_K)) = if I.isTemplate idx then 1 else 0 := by
        show stgTabK shdP_U shdP_hbij Ps cs 12 1 _ (.pub _) = _
        rw [hpub _ (by simp [hti]), rangeMap_getD (2 ^ I.tiLog) idx (by rw [hti]; exact hidxLt)]
        split_ifs <;> simp [Fp2.toK_one, Fp2.toK_zero]
      have hg4 : g 4 (fun i => (bit (cptS 12 b i) : shdP_K)) = (kI (I.kappa idx)).toK shdP_U := by
        show stgTabK shdP_U shdP_hbij Ps cs 12 1 _ (.pub _) = _
        rw [hpub _ (by simp [hti]), rangeMap_getD (2 ^ I.tiLog) idx (by rw [hti]; exact hidxLt)]
      have hg5 : g 5 (fun i => (bit (cptS 12 b i) : shdP_K))
          = if I.ctlQ idx then (cx.beta.mul cx.beta).toK shdP_U else 0 := by
        show stgTabK shdP_U shdP_hbij Ps cs 12 1 _ (.pub _) = _
        rw [hpub _ (by simp [hti]), rangeMap_getD (2 ^ I.tiLog) idx (by rw [hti]; exact hidxLt)]
        split_ifs <;> simp [Fp2.toK_zero]
      have hpt12 : ∀ a : Fin 12,
          Block.ptK shdP_U (Block.xrK 12 (fun i : Fin (slotN P 1) => (bit (cptS 12 b i) : shdP_K)))
            (rhoC 0 12) a.val = (bit (b a) : shdP_K) := by
        intro a; unfold Block.ptK
        have hget : (rhoC 0 12).getD a.val (Block.Coord.fixed Fp2.zero) = Block.Coord.rho a.val := by
          simp [rhoC, List.getD_eq_getElem?_getD, List.getElem?_range' a.isLt]
        rw [hget]; exact xrK_cptS 12 b a.val a.isLt (by omega)
      have hg6 : g 6 (fun i => (bit (cptS 12 b i) : shdP_K))
          = if h : idx < 128 then (x ⟨idx, h⟩ : shdP_K) else 0 := by
        let p6 : Block.Priv := ⟨.a, [(L.aOff incA_TOK, Fp2.one)], L.aLog.getD incA_TOK 0,
          rhoC 0 (L.aLog.getD incA_TOK 0), L.aMaskBase + 2 * (L.prefixA 1 + 0), 0⟩
        have h0 := claimSem_priv_cube_y0 Ps 41 12 (tabMat 41 12 (shdP_incTA x rnd).rows) 12 hN1 b p6
          (L.aOff incA_TOK, Fp2.one) [] rfl (by rw [haLog0, hrowA]; norm_num)
          (by intro c hc w hw; obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc; rw [hw] at hEq; cases hEq)
        change Link.claimSem shdP_U 41 12 0 (tabMat 41 12 (shdP_incTA x rnd).rows) _ = _
        rw [h0]
        simp only [p6, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
          Fp2.toK_one, one_mul, haOff0, haLog0, rhoC, List.length_map, List.length_range', Nat.sub_zero]
        have hsl := data_slice_single_row 41 12 0 (by norm_num) (tabMat 41 12 (shdP_incTA x rnd).rows) b _ hpt12
        simp only [Nat.zero_mul] at hsl
        rw [hsl]; unfold shdP_incTA; rw [tabMat_mkRows]; unfold shdP_incTAData; dsimp only
        rw [ite_eq_left rfl]
        by_cases h128 : idx < 128
        · rw [dite_eq_left h128, dite_eq_left h128, Fp.toGF_ofGF, map_natCast]
        · rw [dite_eq_right h128, dite_eq_right h128]; simp [Fp.toGF, Fp.zero]
      have hg7 : g 7 (fun i => (bit (cptS 12 b i) : shdP_K))
          = if h : idx < 128 then (cx.alpha.toK shdP_U - (cx.tauTab.getD (x ⟨idx, h⟩) Fp2.zero).toK shdP_U)⁻¹ else 0 := by
        let p7 : Block.Priv := ⟨.h, [((L.hOff incH_Q).1, Fp2.one), ((L.hOff incH_Q).2, Block.fp2U)],
          L.hLog.getD incH_Q 0, rhoC 0 (L.hLog.getD incH_Q 0), L.hMaskBase + 2 * (L.prefixH 1 + 0), 0⟩
        have h0 := claimSem_priv_cube_y0 Ps 76 12 (tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows) 12 hN1 b p7
          ((L.hOff incH_Q).1, Fp2.one) [((L.hOff incH_Q).2, Block.fp2U)] rfl (by rw [hhLog0, hrowH]; norm_num)
          (by intro c hc w hw; obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc; rw [hw] at hEq; cases hEq)
        change Link.claimSem shdP_U 76 12 0 (tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows) _ = _
        rw [h0]
        simp only [p7, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
          Fp2.toK_one, one_mul, Block.toK_fp2U, hhOff0, hhLog0, rhoC, List.length_map, List.length_range', Nat.sub_zero]
        -- Split sum over `row` into row 0 (`re`) + `U *` row 1 (`im`)
        have hsplit : ∀ row : Fin 76,
            (dataRowK 0 12 12 12 (Block.ptK shdP_U (Block.xrK 12 (fun i : Fin (slotN P 1) => (bit (cptS 12 b i) : shdP_K))) (rhoC 0 12)) row
              + shdP_U * dataRowK 4096 12 12 12 (Block.ptK shdP_U (Block.xrK 12 (fun i : Fin (slotN P 1) => (bit (cptS 12 b i) : shdP_K))) (rhoC 0 12)) row)
              * ∑ t : Fin (2 ^ 12 + 0), tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows row t
                  * dataKeyColK 0 12 12 12 (Block.ptK shdP_U (Block.xrK 12 (fun i : Fin (slotN P 1) => (bit (cptS 12 b i) : shdP_K))) (rhoC 0 12)) t
            = dataRowK (0 * 2 ^ 12) 12 12 12 _ row * (∑ t, _ * dataKeyColK (0 * 2 ^ 12) 12 12 12 _ t)
              + shdP_U * (dataRowK (1 * 2 ^ 12) 12 12 12 _ row * (∑ t, _ * dataKeyColK (1 * 2 ^ 12) 12 12 12 _ t)) := by
          intro row
          have hcolEq : dataKeyColK 0 12 12 12 (Block.ptK shdP_U (Block.xrK 12 (fun i : Fin (slotN P 1) => (bit (cptS 12 b i) : shdP_K))) (rhoC 0 12))
              = dataKeyColK (1 * 2 ^ 12) 12 12 12 (Block.ptK shdP_U (Block.xrK 12 (fun i : Fin (slotN P 1) => (bit (cptS 12 b i) : shdP_K))) (rhoC 0 12)) := by
            funext t; unfold dataKeyColK; simp
          simp only [Nat.zero_mul, one_mul, ← hcolEq]
          ring
        simp_rw [hsplit, Finset.sum_add_distrib, ← Finset.mul_sum]
        rw [data_slice_single_row 76 12 0 (by norm_num) _ b _ hpt12,
          data_slice_single_row 76 12 1 (by norm_num) _ b _ hpt12]
        unfold shdP_incTH
        rw [tabMat_mkRows, tabMat_mkRows]
        have hre : shdP_incTHData Rp embDigest x rnd ch ⟨0, by norm_num⟩ ⟨idx, hidxLt⟩
            = (ofK shdP_U shdP_hbij (if h : idx < 128 then (cx.alpha.toK shdP_U - (cx.tauTab.getD (x ⟨idx, h⟩) Fp2.zero).toK shdP_U)⁻¹ else 0)).c0 := rfl
        have him : shdP_incTHData Rp embDigest x rnd ch ⟨1, by norm_num⟩ ⟨idx, hidxLt⟩
            = (ofK shdP_U shdP_hbij (if h : idx < 128 then (cx.alpha.toK shdP_U - (cx.tauTab.getD (x ⟨idx, h⟩) Fp2.zero).toK shdP_U)⁻¹ else 0)).c1 := rfl
        rw [hre, him]
        exact toK_ofK shdP_U shdP_hbij _
      unfold qzcPolyK
      by_cases h128 : idx < 128
      · -- Active position `t = ⟨idx, h128⟩ < 128`: all 4 clauses vanish!
        let t : shieldS0.Tok := ⟨idx, h128⟩
        -- Evaluate `g 8` (B_in) at `(b[5..11], rEmb)`
        have hg8 : g 8 (fun i => (bit (cptS 12 b i) : shdP_K))
            = ((embFoldL Rp.inp cx.rEmb).getD (x t) Fp2.zero).toK shdP_U := by
          let p8 : Block.Priv := ⟨.out, [(0, Fp2.one)], I.bInLog, rhoC (I.tiLog - I.tBits) I.tiLog ++ fixedC cx.rEmb, V.geo.bInRow, 0⟩
          have h0 := claimSem_priv_cube_y0 Ps 38 14 (tabMat 38 14 (shdP_incTB Rp x rnd).rows) 12 hN1 b p8
            (0, Fp2.one) [] rfl (by rw [hbInLog, hrowOut]; norm_num)
            (by
              intro c hc w hw
              rcases List.mem_append.mp hc with h1 | h2
              · obtain ⟨_, -, hEq⟩ := List.mem_map.mp h1; rw [hw] at hEq; cases hEq
              · obtain ⟨a, ha, hEq⟩ := List.mem_map.mp h2; rw [hw] at hEq; cases hEq; exact hrEmbCan w ha)
          change Link.claimSem shdP_U 38 14 0 (tabMat 38 14 (shdP_incTB Rp x rnd).rows) _ = _
          rw [h0]
          simp only [p8, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
            Fp2.toK_one, one_mul, hbInLog, hti, htBits, rhoC, fixedC, List.length_append, List.length_map,
            List.length_range', hrEmbLen, show 12 - (12 - 7) + 12 = 19 by norm_num]
          have hlo : ∀ a : Fin 7,
              Block.ptK shdP_U (Block.xrK 12 (fun i : Fin (slotN P 1) => (bit (cptS 12 b i) : shdP_K)))
                (rhoC (12 - 7) 12 ++ fixedC cx.rEmb) a.val = (bit (msbBits 7 t.val a) : shdP_K) := by
            intro a; unfold Block.ptK
            have hget : (rhoC 5 12 ++ fixedC cx.rEmb).getD a.val (Block.Coord.fixed Fp2.zero)
                = Block.Coord.rho (5 + a.val) := by
              rw [List.getD_eq_getElem?_getD, List.getElem?_append_left (by simp [rhoC]; exact a.isLt)]
              simp [rhoC, List.getElem?_range' (show a.val < 12 - 5 from a.isLt)]
            rw [show 12 - 7 = 5 by norm_num, hget, xrK_cptS 12 b (5 + a.val) (by omega) (by omega)]
            have hlow := bits7_low b a
            have hmod : msbIndex 12 b % 128 = t.val := Nat.mod_eq_of_lt h128
            rw [hmod] at hlow
            rw [hlow]
          have hhi : ∀ a : Fin 12,
              Block.ptK shdP_U (Block.xrK 12 (fun i : Fin (slotN P 1) => (bit (cptS 12 b i) : shdP_K)))
                (rhoC (12 - 7) 12 ++ fixedC cx.rEmb) (7 + a.val) = (cx.rEmb.getD a.val Fp2.zero).toK shdP_U := by
            intro a; unfold Block.ptK
            have hget : (rhoC 5 12 ++ fixedC cx.rEmb).getD (7 + a.val) (Block.Coord.fixed Fp2.zero)
                = Block.Coord.fixed (cx.rEmb.getD a.val Fp2.zero) := by
              rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by simp [rhoC])]
              simp [rhoC, fixedC, List.getElem?_map, List.getElem?_eq_getElem (by rw [hrEmbLen]; exact a.isLt),
                List.getD_eq_getElem?_getD]
            rw [show 12 - 7 = 5 by norm_num, hget]
          exact shdP_incTB_eval_rEmb Rp hP hV x hxV rnd cx.rEmb hrEmbLen hrEmbCan t _ hlo hhi
        -- Show `q = τK (x t)`
        have hqEq : (((g 6 (fun i => (bit (cptS 12 b i) : shdP_K))
              + cx.beta.toK shdP_U * g 8 (fun i => (bit (cptS 12 b i) : shdP_K)))
              + g 5 (fun i => (bit (cptS 12 b i) : shdP_K))) + cx.gEmb.toK shdP_U)
            = (cx.tauTab.getD (x t) Fp2.zero).toK shdP_U := by
          have hxtLt : x t < 131072 := hxV t
          have htau : cx.tauTab.getD (x t) Fp2.zero
              = (((kI (x t)).add (cx.beta.mul ((embFoldL Rp.inp cx.rEmb).getD (x t) Fp2.zero))).add
                  (if I.ctl (x t) then cx.beta.mul cx.beta else Fp2.zero)).add cx.gEmb := by
            unfold cx incCtx tauTable
            dsimp only
            rw [rangeMap_getD (2 ^ I.vocLog) (x t) (by rw [hvoc]; exact hxtLt)]
            exact ite_eq_left hxtLt
          have hctlC : (if I.ctl (x t) then cx.beta.mul cx.beta else Fp2.zero).Canon := by
            split_ifs; · exact Fp2.canon_mul _ _; · exact Fp2.canon_zero
          rw [htau, Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) hgEmbC,
            Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) hctlC,
            Fp2.toK_add shdP_U _ _ (kI_canon _) (Fp2.canon_mul _ _),
            Fp2.toK_mul shdP_U shdP_hU,
            kI_nat_toK shdP_U (x t) (lt_trans hxtLt (by norm_num)),
            hg6, dite_eq_left h128, hg8, hg5, ← hxCtl embDigest (embFoldL Rp.inp) t]
          split_ifs <;> simp [Fp2.toK_zero]
        have hne0 : cx.alpha.toK shdP_U - (cx.tauTab.getD (x t) Fp2.zero).toK shdP_U ≠ 0 :=
          sub_ne_zero.mpr (incAlpha_ne_tauK Rp embDigest ch hchCan hbad (x t) (hxV t))
        have hlu0 : g 7 (fun i => (bit (cptS 12 b i) : shdP_K))
            * (cx.alpha.toK shdP_U - (((g 6 (fun i => (bit (cptS 12 b i) : shdP_K))
              + cx.beta.toK shdP_U * g 8 (fun i => (bit (cptS 12 b i) : shdP_K)))
              + g 5 (fun i => (bit (cptS 12 b i) : shdP_K))) + cx.gEmb.toK shdP_U))
            - g 1 (fun i => (bit (cptS 12 b i) : shdP_K)) = 0 := by
          rw [hqEq, hg7, dite_eq_left h128, hg1, ite_eq_left h128, inv_mul_cancel₀ hne0, sub_self]
        have hbos0 : g 2 (fun i => (bit (cptS 12 b i) : shdP_K))
            * (g 6 (fun i => (bit (cptS 12 b i) : shdP_K)) - (kI I.bos).toK shdP_U) = 0 := by
          rw [hg2, hg6, dite_eq_left h128]
          by_cases h0 : idx < 1
          · rw [ite_eq_left h0]
            have hbEq : x t = Rp.inp.bos := hxBos t (by show idx = 0; omega)
            have hbosLt : Rp.inp.bos < 2 ^ 63 := lt_trans hP.bos (by rw [hV]; norm_num)
            rw [hbEq, show I.bos = Rp.inp.bos from rfl, kI_nat_toK shdP_U _ hbosLt, sub_self, mul_zero]
          · rw [ite_eq_right h0, zero_mul]
        have htmp0 : g 3 (fun i => (bit (cptS 12 b i) : shdP_K))
            * (g 6 (fun i => (bit (cptS 12 b i) : shdP_K)) - g 4 (fun i => (bit (cptS 12 b i) : shdP_K))) = 0 := by
          rw [hg3, hg4, hg6, dite_eq_left h128]
          have hT : I.isTemplate idx = Rp.inp.isT t := by
            show (if h : idx < 128 then Rp.inp.isT ⟨idx, h⟩ else false) = Rp.inp.isT t
            exact dite_eq_left h128
          rw [hT]
          cases hTv : Rp.inp.isT t with
          | false => simp
          | true =>
            have hkap : I.kappa idx = Rp.inp.kap t := by
              show (if h : idx < 128 then Rp.inp.kap ⟨idx, h⟩ else 0) = Rp.inp.kap t
              exact dite_eq_left h128
            have hkapLt : Rp.inp.kap t < 2 ^ 63 := lt_trans (hP.kap t) (by rw [hV]; norm_num)
            rw [hkap, hxT t hTv, kI_nat_toK shdP_U _ hkapLt, sub_self, mul_zero]
        have hpad0 : (1 - g 1 (fun i => (bit (cptS 12 b i) : shdP_K)))
            * (g 6 (fun i => (bit (cptS 12 b i) : shdP_K))
              + zeta.toK shdP_U * g 7 (fun i => (bit (cptS 12 b i) : shdP_K))) = 0 := by
          rw [hg1, ite_eq_left h128, sub_self, zero_mul]
        rw [hlu0, hbos0, htmp0, hpad0]
        ring
      · -- Padding position `idx ≥ 128`: `g1 = g2 = g3 = g6 = g7 = 0`!
        have hnot1 : ¬ idx < 1 := by omega
        have hnotT : I.isTemplate idx = false := by
          show (if h : idx < 128 then Rp.inp.isT ⟨idx, h⟩ else false) = false
          exact dite_eq_right h128
        rw [hg1, hg2, hg3, hg6, hg7, ite_eq_right h128, ite_eq_right hnot1, hnotT,
          dite_eq_right h128, dite_eq_right h128]
        simp

/-- Slot 2 (`INC-02`): `IndDegLE 4` and `cubeSum (slotPolyK ...) = 0`. -/
theorem inc_slot2_arith (ch : List Fp2) (hchCan : ∀ a ∈ ch, a.Canon)
    (hbad : incAlphaBad (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch) = false)
    (dr : List Fp2) (hdrLen : dr.length = 20) (hdrCan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : incDefTZC (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow)
      (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch) dr = .ok df) :
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    let elog := incElog V.pub 14
    let cs := incCs (shdP_incTA x rnd) (shdP_incTH Rp embDigest x rnd ch)
      (shdP_epTable (Hdr := Hdr) tag x epR) (shdP_incTB Rp x rnd)
    IndDegLE 4 (slotPolyK P elog cs 2 df)
      ∧ cubeSum (slotPolyK P elog cs 2 df) = 0
      ∧ df.hosted = []
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P elog cs
  let I := V.pub
  let L := incLay I 14
  let cx := incCtx I ch
  have hti : I.tiLog = 12 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).1
  have hvoc : I.vocLog = 17 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.1
  have hlt : I.lt = 12 := rfl
  have haOff1 : L.aOff incA_MULT = 4096 := by simp [L, incLay, Lay.aOff, Lay.aRowsL, Lay.n, rowsOf, incA_MULT, hti, hvoc, hlt]
  have haLog1 : L.aLog.getD incA_MULT 0 = 17 := by simp [L, incLay, incA_MULT, hvoc]
  have hhOff1 : L.hOff incH_TAB = (8192, 139264) := by
    simp [L, incLay, Lay.hOff, Lay.hRowsL, Lay.n, rowsOf, incH_TAB, hti, hvoc, hlt]
  have hhLog1 : L.hLog.getD incH_TAB 0 = 17 := by simp [L, incLay, incH_TAB, hvoc]
  have hdf := incDefTZC_eq_of_ok I V.geo cx hvoc dr hdrLen hdrCan df hdef
  subst hdf
  have hsh2 : Exec.Block.slotShape P 2 = (17, 1, 4) := by
    show (incLay I 14).geomSlots.getD 2 (0, 0, 0) = (17, 1, 4)
    simp [incLay, Lay.geomSlots, incSched, hvoc]
  have hN2 : slotN P 2 = 18 := by unfold slotN; rw [hsh2]
  let Ps := atLog P (elog 2)
  have hrowA : Block.rowLog Ps .a = 12 := rfl
  have hrowH : Block.rowLog Ps .h = 12 := rfl
  let mu := (dr.drop I.vocLog).take 2
  let zeta := (((dr.drop (I.vocLog + 2)).take 1).getD 0 Fp2.zero)
  let tabs := [
    Tab.eq (dr.take I.vocLog) 0,
    Tab.pub (supp I.v (2 ^ I.vocLog)),
    Tab.pub cx.tauTab,
    Tab.priv ⟨.a, [(L.aOff incA_MULT, Fp2.one)], L.aLog.getD incA_MULT 0,
      rhoC 0 (L.aLog.getD incA_MULT 0), L.aMaskBase + 2 * (L.prefixA 2 + 0), 0⟩,
    Tab.priv ⟨.h, [((L.hOff incH_TAB).1, Fp2.one), ((L.hOff incH_TAB).2, Block.fp2U)],
      L.hLog.getD incH_TAB 0, rhoC 0 (L.hLog.getD incH_TAB 0), L.hMaskBase + 2 * (L.prefixH 2 + 0), 0⟩]
  have hfit : tabsFit 17 tabs := by
    intro t ht
    simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl | rfl
    · show 0 + (dr.take I.vocLog).length ≤ 17; rw [hvoc, Nat.zero_add]; exact List.length_take_le _ _
    · show (supp I.v (2 ^ I.vocLog)).length = 2 ^ 17; simp [supp, hvoc]
    · show cx.tauTab.length = 2 ^ 17; simp [cx, incCtx, tauTable, hvoc]
    · trivial
    · trivial
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st heq a ha
    simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl | rfl
    · cases heq; exact hdrCan a (List.mem_of_mem_take ha)
    all_goals cases heq
  have halphaC : cx.alpha.Canon := Fp2.canon_getD hchCan 2
  let g : ℕ → (Fin (slotN P 2) → shdP_K) → shdP_K := fun j z =>
    (tabs.map (stgTabK shdP_U shdP_hbij Ps cs 17 1 z)).getD j 0
  have hpoly : ∀ z : Fin (slotN P 2) → shdP_K,
      slotPolyK P elog cs 2 ⟨tabs, _, []⟩ z
        = g 0 z * ((vg mu 0).toK shdP_U * (g 4 z * (cx.alpha.toK shdP_U - g 2 z) - g 3 z)
            + (vg mu 1).toK shdP_U * ((1 - g 1 z) * (g 3 z + zeta.toK shdP_U * g 4 z))) := by
    intro z
    unfold slotPolyK
    have hsh2' : (Exec.Block.slotShape P 2).1 = 17 := by rw [hsh2]
    dsimp only; rw [hsh2']
    obtain ⟨vals, htv, hvcan, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU Ps cs 17 1 hN2 z tabs hfit hcan
    rw [htv]
    have hvg : ∀ i, (vg vals i).toK shdP_U = g i z := fun i => by rw [vg_toK_map, hvmap]
    rw [Fp2.toK_mul shdP_U shdP_hU,
      Fp2.toK_add shdP_U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
      Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU,
      Fp2.toK_sub shdP_U _ _ (Fp2.canon_mul _ _) (vg_canon hvcan 3),
      Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_sub shdP_U _ _ halphaC (vg_canon hvcan 2),
      Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_sub shdP_U _ _ Fp2.canon_one (vg_canon hvcan 1),
      Fp2.toK_add shdP_U _ _ (vg_canon hvcan 3) (Fp2.canon_mul _ _),
      Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_one,
      hvg 0, hvg 1, hvg 2, hvg 3, hvg 4]
  have hfunEq : slotPolyK P elog cs 2 ⟨tabs, _, []⟩
      = fun z => g 0 z * ((vg mu 0).toK shdP_U * (g 4 z * (cx.alpha.toK shdP_U - g 2 z) - g 3 z)
          + (vg mu 1).toK shdP_U * ((1 - g 1 z) * (g 3 z + zeta.toK shdP_U * g 4 z))) := funext hpoly
  have hg_deg : ∀ j, j < 5 → IndDegLE 1 (g j) := by
    intro j hj
    interval_cases j
    · exact stgTabK_eq_indDeg _ _
    · exact stgTabK_pub_indDeg _
    · exact stgTabK_pub_indDeg _
    · exact indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU Ps 41 12 0 (tabMat 41 12 (shdP_incTA x rnd).rows)
        (N := slotN P 2) 17 1 hN2 _ (by simp) (by rw [haLog1, hrowA]; norm_num)
        (by
          have := varsOKb_fixed_rho_fixed [] [] 0 (L.aLog.getD incA_MULT 0) (by intro _ h; cases h) (by intro _ h; cases h)
          simpa using this)
        (by intro c hc w hw; obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc; rw [hw] at hEq; cases hEq)
    · exact indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU Ps 76 12 0 (tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows)
        (N := slotN P 2) 17 1 hN2 _ (by simp) (by rw [hhLog1, hrowH]; norm_num)
        (by
          have := varsOKb_fixed_rho_fixed [] [] 0 (L.hLog.getD incH_TAB 0) (by intro _ h; cases h) (by intro _ h; cases h)
          simpa using this)
        (by intro c hc w hw; obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc; rw [hw] at hEq; cases hEq)
  refine ⟨?_, ?_, rfl, fun _ => Fp2.canon_mul _ _⟩
  · rw [hfunEq]
    have hd0 := hg_deg 0 (by omega); have hd1 := hg_deg 1 (by omega); have hd2 := hg_deg 2 (by omega)
    have hd3 := hg_deg 3 (by omega); have hd4 := hg_deg 4 (by omega)
    have hrel := IndDegLE.sub (IndDegLE.mul hd4 (IndDegLE.sub (IndDegLE.const _) hd2)) (IndDegLE.mono hd3 (by norm_num))
    have hpad := IndDegLE.mul (IndDegLE.sub (IndDegLE.const _) hd1) (IndDegLE.add hd3 (IndDegLE.cmul _ hd4))
    exact IndDegLE.mono (IndDegLE.mul hd0 (IndDegLE.add (IndDegLE.cmul _ hrel) (IndDegLE.cmul _ hpad))) (by norm_num)
  · rw [hfunEq]
    unfold cubeSum
    refine Finset.sum_eq_zero (fun w _ => ?_)
    by_cases hw17 : w ⟨17, by omega⟩ = true
    · have hs0 : Block.selK 17 1 (fun i : Fin (slotN P 2) => (bit (w i) : shdP_K)) = 0 := by
        unfold Block.selK Block.yeK Block.xg
        rw [Finset.prod_range_one, Nat.add_zero, dite_eq_left (by omega)]
        dsimp only; rw [hw17]; simp [bit]
      have hg0z : g 0 (fun i => (bit (w i) : shdP_K)) = 0 := by
        show stgTabK shdP_U shdP_hbij Ps cs 17 1 _ _ = 0
        unfold stgTabK stgTabW; dsimp only; split_ifs; · rw [hs0, zero_mul]; · rfl
      rw [hg0z, zero_mul]
    · have hwf : w ⟨17, by omega⟩ = false := by cases h : w ⟨17, by omega⟩ <;> simp_all
      let b : Fin 17 → Bool := fun j => w ⟨j.val, by omega⟩
      have hwEq : w = cptS 17 b := by
        funext i; unfold cptS
        by_cases hi : i.val < 17
        · rw [dite_eq_left hi]
        · rw [dite_eq_right hi]
          have hin : i = ⟨17, by omega⟩ := Fin.ext (by have := i.isLt; omega)
          rw [hin, hwf]
      rw [hwEq]
      let v := msbIndex 17 b
      have hvLt : v < 131072 := msbIndex_lt 17 b
      have hpub : ∀ (pv : List Fp2), pv.length = 2 ^ 17 →
          stgTabK shdP_U shdP_hbij Ps cs 17 1 (fun i : Fin (slotN P 2) => (bit (cptS 17 b i) : shdP_K)) (.pub pv)
            = (pv.getD v Fp2.zero).toK shdP_U := by
        intro pv hpv
        unfold stgTabK stgTabW; dsimp only
        rw [ite_eq_left hpv, selK_cptS 17 b hN2, one_mul]
        have hxB : (fun a : Fin 17 => Block.xrK 17 (fun i : Fin (slotN P 2) => (bit (cptS 17 b i) : shdP_K)) a.val)
            = fun a : Fin 17 => (bit (b a) : shdP_K) := funext fun a => xrK_cptS 17 b a.val a.isLt (by omega)
        rw [hxB, mleAt_bitv]
      have hg1 : g 1 (fun i => (bit (cptS 17 b i) : shdP_K)) = 1 := by
        show stgTabK shdP_U shdP_hbij Ps cs 17 1 _ (.pub (supp I.v (2 ^ I.vocLog))) = _
        rw [hpub _ (by simp [supp, hvoc]), hvoc]
        rw [supp_getD_toK shdP_U 131072 131072 v hvLt, ite_eq_left hvLt]
      have hg2 : g 2 (fun i => (bit (cptS 17 b i) : shdP_K)) = (cx.tauTab.getD v Fp2.zero).toK shdP_U := by
        show stgTabK shdP_U shdP_hbij Ps cs 17 1 _ (.pub cx.tauTab) = _
        exact hpub cx.tauTab (by simp [cx, incCtx, tauTable, hvoc])
      have hpt17 : ∀ a : Fin (5 + 12),
          Block.ptK shdP_U (Block.xrK 17 (fun i : Fin (slotN P 2) => (bit (cptS 17 b i) : shdP_K)))
            (rhoC 0 17) a.val = (bit (b a) : shdP_K) := by
        intro a; unfold Block.ptK
        have hget : (rhoC 0 17).getD a.val (Block.Coord.fixed Fp2.zero) = Block.Coord.rho a.val := by
          simp [rhoC, List.getD_eq_getElem?_getD, List.getElem?_range' a.isLt]
        rw [hget]; exact xrK_cptS 17 b a.val a.isLt (by omega)
      have hsplitV : msbIndex 5 (fun a : Fin 5 => b ⟨a.val, by omega⟩) * 4096
          + msbIndex 12 (fun a : Fin 12 => b ⟨5 + a.val, by omega⟩) = v :=
        (msbIndex_split 5 12 b).symm
      have hg3 : g 3 (fun i => (bit (cptS 17 b i) : shdP_K)) = (incMult x v : shdP_K) := by
        let p3 : Block.Priv := ⟨.a, [(L.aOff incA_MULT, Fp2.one)], L.aLog.getD incA_MULT 0,
          rhoC 0 (L.aLog.getD incA_MULT 0), L.aMaskBase + 2 * (L.prefixA 2 + 0), 0⟩
        have h0 := claimSem_priv_cube_y0 Ps 41 12 (tabMat 41 12 (shdP_incTA x rnd).rows) 17 hN2 b p3
          (L.aOff incA_MULT, Fp2.one) [] rfl (by rw [haLog1, hrowA]; norm_num)
          (by intro c hc w hw; obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc; rw [hw] at hEq; cases hEq)
        change Link.claimSem shdP_U 41 12 0 (tabMat 41 12 (shdP_incTA x rnd).rows) _ = _
        rw [h0]
        simp only [p3, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
          Fp2.toK_one, one_mul, haOff1, haLog1, rhoC, List.length_map, List.length_range', Nat.sub_zero]
        have hsl := data_slice_multi_row 41 12 5 1 (by norm_num) (by norm_num) (by norm_num)
          (tabMat 41 12 (shdP_incTA x rnd).rows) b _ hpt17
        simp only [one_mul] at hsl
        rw [hsl]; unfold shdP_incTA; rw [tabMat_mkRows]; unfold shdP_incTAData; dsimp only
        have hhiLt := msbIndex_lt 5 (fun a : Fin 5 => b ⟨a.val, by omega⟩)
        rw [ite_eq_right (by omega), ite_eq_left (by omega)]
        have hsub : 1 + msbIndex 5 (fun a : Fin 5 => b ⟨a.val, by omega⟩) - 1
            = msbIndex 5 (fun a : Fin 5 => b ⟨a.val, by omega⟩) := by omega
        rw [hsub, hsplitV, Fp.toGF_ofGF, map_natCast]
      have hg4 : g 4 (fun i => (bit (cptS 17 b i) : shdP_K))
          = (incMult x v : shdP_K) * (cx.alpha.toK shdP_U - (cx.tauTab.getD v Fp2.zero).toK shdP_U)⁻¹ := by
        let p4 : Block.Priv := ⟨.h, [((L.hOff incH_TAB).1, Fp2.one), ((L.hOff incH_TAB).2, Block.fp2U)],
          L.hLog.getD incH_TAB 0, rhoC 0 (L.hLog.getD incH_TAB 0), L.hMaskBase + 2 * (L.prefixH 2 + 0), 0⟩
        have h0 := claimSem_priv_cube_y0 Ps 76 12 (tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows) 17 hN2 b p4
          ((L.hOff incH_TAB).1, Fp2.one) [((L.hOff incH_TAB).2, Block.fp2U)] rfl (by rw [hhLog1, hrowH]; norm_num)
          (by intro c hc w hw; obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc; rw [hw] at hEq; cases hEq)
        change Link.claimSem shdP_U 76 12 0 (tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows) _ = _
        rw [h0]
        simp only [p4, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
          Fp2.toK_one, one_mul, Block.toK_fp2U, hhOff1, hhLog1, rhoC, List.length_map, List.length_range', Nat.sub_zero]
        have hcolEq : dataKeyColK 8192 17 12 17
              (Block.ptK shdP_U (Block.xrK 17 (fun i : Fin (slotN P 2) => (bit (cptS 17 b i) : shdP_K))) (rhoC 0 17))
            = dataKeyColK 139264 17 12 17
              (Block.ptK shdP_U (Block.xrK 17 (fun i : Fin (slotN P 2) => (bit (cptS 17 b i) : shdP_K))) (rhoC 0 17)) := by
          funext t; unfold dataKeyColK; simp
        have hsplit : ∀ row : Fin 76,
            (dataRowK 8192 17 12 17 _ row + shdP_U * dataRowK 139264 17 12 17 _ row)
              * ∑ t : Fin (2 ^ 12 + 0), tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows row t * dataKeyColK 8192 17 12 17 _ t
            = dataRowK (2 * 2 ^ 12) (5 + 12) 12 (5 + 12) _ row * (∑ t, _ * dataKeyColK (2 * 2 ^ 12) (5 + 12) 12 (5 + 12) _ t)
              + shdP_U * (dataRowK (34 * 2 ^ 12) (5 + 12) 12 (5 + 12) _ row * (∑ t, _ * dataKeyColK (34 * 2 ^ 12) (5 + 12) 12 (5 + 12) _ t)) := by
          intro row
          change (dataRowK 8192 17 12 17 _ row + shdP_U * dataRowK 139264 17 12 17 _ row) * _
            = dataRowK 8192 17 12 17 _ row * (∑ t, _ * dataKeyColK 8192 17 12 17 _ t)
              + shdP_U * (dataRowK 139264 17 12 17 _ row * (∑ t, _ * dataKeyColK 139264 17 12 17 _ t))
          rw [← hcolEq]; ring
        simp_rw [hsplit, Finset.sum_add_distrib, ← Finset.mul_sum]
        rw [data_slice_multi_row 76 12 5 2 (by norm_num) (by norm_num) (by norm_num) _ b _ hpt17,
          data_slice_multi_row 76 12 5 34 (by norm_num) (by norm_num) (by norm_num) _ b _ hpt17]
        unfold shdP_incTH
        rw [tabMat_mkRows, tabMat_mkRows]
        have hhiLt := msbIndex_lt 5 (fun a : Fin 5 => b ⟨a.val, by omega⟩)
        have hre : shdP_incTHData Rp embDigest x rnd ch ⟨2 + msbIndex 5 (fun a => b ⟨a.val, by omega⟩), by omega⟩
              ⟨msbIndex 12 (fun a => b ⟨5 + a.val, by omega⟩), msbIndex_lt 12 _⟩
            = (ofK shdP_U shdP_hbij ((incMult x v : shdP_K)
                * (cx.alpha.toK shdP_U - (cx.tauTab.getD v Fp2.zero).toK shdP_U)⁻¹)).c0 := by
          unfold shdP_incTHData; dsimp only
          rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
          have hsub : 2 + msbIndex 5 (fun a => b ⟨a.val, by omega⟩) - 2 = msbIndex 5 (fun a => b ⟨a.val, by omega⟩) := by omega
          rw [hsub, hsplitV]
        have him : shdP_incTHData Rp embDigest x rnd ch ⟨34 + msbIndex 5 (fun a => b ⟨a.val, by omega⟩), by omega⟩
              ⟨msbIndex 12 (fun a => b ⟨5 + a.val, by omega⟩), msbIndex_lt 12 _⟩
            = (ofK shdP_U shdP_hbij ((incMult x v : shdP_K)
                * (cx.alpha.toK shdP_U - (cx.tauTab.getD v Fp2.zero).toK shdP_U)⁻¹)).c1 := by
          unfold shdP_incTHData; dsimp only
          rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
          have hsub : 34 + msbIndex 5 (fun a => b ⟨a.val, by omega⟩) - 34 = msbIndex 5 (fun a => b ⟨a.val, by omega⟩) := by omega
          rw [hsub, hsplitV]
        rw [hre, him]
        exact toK_ofK shdP_U shdP_hbij _
      have hne0 : cx.alpha.toK shdP_U - (cx.tauTab.getD v Fp2.zero).toK shdP_U ≠ 0 :=
        sub_ne_zero.mpr (incAlpha_ne_tauK Rp embDigest ch hchCan hbad v hvLt)
      rw [hg1, hg2, hg3, hg4, mul_assoc, inv_mul_cancel₀ hne0, mul_one, sub_self, sub_self, mul_zero, zero_mul,
        mul_zero, add_zero, mul_zero]

/-- Slot 3 (`INC-03`): `IndDegLE 2` and `cubeSum (slotPolyK ...) = 0`. -/
theorem inc_slot3_arith (ch : List Fp2)
    (df : SlotDef) (hdef : incDefZS (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow) = .ok df) :
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    let elog := incElog V.pub 14
    let cs := incCs (shdP_incTA x rnd) (shdP_incTH Rp embDigest x rnd ch)
      (shdP_epTable (Hdr := Hdr) tag x epR) (shdP_incTB Rp x rnd)
    IndDegLE 2 (slotPolyK P elog cs 3 df)
      ∧ cubeSum (slotPolyK P elog cs 3 df) = 0
      ∧ df.hosted = []
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P elog cs
  let I := V.pub
  let L := incLay I 14
  have hti : I.tiLog = 12 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).1
  have hvoc : I.vocLog = 17 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.1
  have hlt : I.lt = 12 := rfl
  have hhOff2 : L.hOff incH_U = (270336, 274432) := by
    simp [L, incLay, Lay.hOff, Lay.hRowsL, Lay.n, rowsOf, incH_U, hti, hvoc, hlt]
  have hhLog2 : L.hLog.getD incH_U 0 = 12 := by simp [L, incLay, incH_U, hlt]
  have hok := incDefZS_ok I V.geo
  dsimp only at hok
  rw [hok] at hdef
  have hdf := (Except.ok.inj hdef).symm
  subst hdf
  have hsh3 : Exec.Block.slotShape P 3 = (12, 1, 2) := by
    show (incLay I 14).geomSlots.getD 3 (0, 0, 0) = (12, 1, 2)
    simp [incLay, Lay.geomSlots, incSched, hlt]
  have hN3 : slotN P 3 = 13 := by unfold slotN; rw [hsh3]
  let Ps := atLog P (elog 3)
  have hrowH : Block.rowLog Ps .h = 12 := rfl
  let tabs := [
    Tab.pub (List.replicate (2 ^ L.hLog.getD incH_U 0) Fp2.one),
    Tab.priv ⟨.h, [((L.hOff incH_U).1, Fp2.one), ((L.hOff incH_U).2, Block.fp2U)],
      L.hLog.getD incH_U 0, rhoC 0 (L.hLog.getD incH_U 0), L.hMaskBase + 2 * (L.prefixH 3 + 0), 0⟩]
  have hfit : tabsFit 12 tabs := by
    intro t ht
    simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl
    · show (List.replicate (2 ^ L.hLog.getD incH_U 0) Fp2.one).length = 2 ^ 12; simp [hhLog2]
    · trivial
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st heq
    simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl <;> cases heq
  let g : ℕ → (Fin (slotN P 3) → shdP_K) → shdP_K := fun j z =>
    (tabs.map (stgTabK shdP_U shdP_hbij Ps cs 12 1 z)).getD j 0
  have hpoly : ∀ z : Fin (slotN P 3) → shdP_K,
      slotPolyK P elog cs 3 ⟨tabs, (fun v => (vg v 0).mul (vg v 1)), []⟩ z = g 0 z * g 1 z := by
    intro z; unfold slotPolyK
    have hsh3' : (Exec.Block.slotShape P 3).1 = 12 := by rw [hsh3]
    dsimp only; rw [hsh3']
    obtain ⟨vals, htv, _, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU Ps cs 12 1 hN3 z tabs hfit hcan
    rw [htv, Fp2.toK_mul shdP_U shdP_hU, vg_toK_map, vg_toK_map, hvmap]
  have hfunEq : slotPolyK P elog cs 3 ⟨tabs, (fun v => (vg v 0).mul (vg v 1)), []⟩ = fun z => g 0 z * g 1 z :=
    funext hpoly
  have hg0 : IndDegLE 1 (g 0) := stgTabK_pub_indDeg _
  have hg1 : IndDegLE 1 (g 1) :=
    indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU Ps 76 12 0 (tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows)
      (N := slotN P 3) 12 1 hN3 _ (by simp) (by rw [hhLog2, hrowH]; norm_num)
      (by
        have := varsOKb_fixed_rho_fixed [] [] 0 (L.hLog.getD incH_U 0) (by intro _ h; cases h) (by intro _ h; cases h)
        simpa using this)
      (by intro c hc w hw; obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc; rw [hw] at hEq; cases hEq)
  refine ⟨by rw [hfunEq]; exact IndDegLE.mul hg0 hg1, ?_, rfl, fun _ => Fp2.canon_mul _ _⟩
  rw [hfunEq]
  -- Cast `slotN P 3` to `12 + 1` and split at `y = false`
  have hcube : cubeSum (fun z : Fin (slotN P 3) → shdP_K => g 0 z * g 1 z)
      = ∑ b : Fin 12 → Bool, g 0 (fun i => (bit (cptS 12 b i) : shdP_K))
          * g 1 (fun i => (bit (cptS 12 b i) : shdP_K)) := by
    unfold cubeSum
    rw [← Finset.sum_filter_add_sum_filter_not Finset.univ (fun w : Fin (slotN P 3) → Bool => w ⟨12, by omega⟩ = false)]
    have htrue : ∑ w ∈ Finset.univ.filter (fun w : Fin (slotN P 3) → Bool => ¬ w ⟨12, by omega⟩ = false),
        g 0 (fun i => (bit (w i) : shdP_K)) * g 1 (fun i => (bit (w i) : shdP_K)) = 0 := by
      refine Finset.sum_eq_zero (fun w hw => ?_)
      have hnf := (Finset.mem_filter.mp hw).2
      have ht : w ⟨12, by omega⟩ = true := by cases h : w ⟨12, by omega⟩ <;> simp_all
      have hs0 : Block.selK 12 1 (fun i : Fin (slotN P 3) => (bit (w i) : shdP_K)) = 0 := by
        unfold Block.selK Block.yeK Block.xg
        rw [Finset.prod_range_one, Nat.add_zero, dite_eq_left (by omega)]
        dsimp only; rw [ht]; simp [bit]
      have hg0z : g 0 (fun i => (bit (w i) : shdP_K)) = 0 := by
        show stgTabK shdP_U shdP_hbij Ps cs 12 1 _ _ = 0
        unfold stgTabK stgTabW; dsimp only; split_ifs; · rw [hs0, zero_mul]; · rfl
      rw [hg0z, zero_mul]
    rw [htrue, add_zero]
    refine Finset.sum_bij (fun (w : Fin (slotN P 3) → Bool) (_ : w ∈ Finset.univ.filter _) =>
        (fun j : Fin 12 => w ⟨j.val, by omega⟩))
      (fun _ _ => Finset.mem_univ _)
      (fun w₁ hw₁ w₂ hw₂ h => by
        have hf1 := (Finset.mem_filter.mp hw₁).2; have hf2 := (Finset.mem_filter.mp hw₂).2
        funext i
        by_cases hi : i.val < 12
        · exact congrFun h ⟨i.val, hi⟩
        · have hin : i = ⟨12, by omega⟩ := Fin.ext (by have := i.isLt; omega)
          rw [hin, hf1, hf2])
      (fun b _ => ⟨cptS 12 b, Finset.mem_filter.mpr ⟨Finset.mem_univ _, by simp [cptS]⟩,
        by funext j; simp [cptS, j.isLt]⟩)
      (fun w hw => by
        have hf := (Finset.mem_filter.mp hw).2
        congr 1 <;> congr 1 <;> funext i <;> congr 1 <;>
          (unfold cptS; by_cases hi : i.val < 12
           · rw [dite_eq_left hi]
           · rw [dite_eq_right hi]; have hin : i = ⟨12, by omega⟩ := Fin.ext (by have := i.isLt; omega); rw [hin, hf]))
  rw [hcube]
  have hterm : ∀ b : Fin 12 → Bool,
      g 0 (fun i => (bit (cptS 12 b i) : shdP_K)) * g 1 (fun i => (bit (cptS 12 b i) : shdP_K))
        = algebraMap GF shdP_K (shdP_incHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).1
          + shdP_U * algebraMap GF shdP_K (shdP_incHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).2 := by
    intro b
    have hg0v : g 0 (fun i => (bit (cptS 12 b i) : shdP_K)) = 1 := by
      show stgTabK shdP_U shdP_hbij Ps cs 12 1 _ (.pub _) = _
      unfold stgTabK stgTabW; dsimp only
      rw [ite_eq_left (by simp [hhLog2]), selK_cptS 12 b hN3, one_mul]
      have hxB : (fun a : Fin 12 => Block.xrK 12 (fun i : Fin (slotN P 3) => (bit (cptS 12 b i) : shdP_K)) a.val)
          = fun a : Fin 12 => (bit (b a) : shdP_K) := funext fun a => xrK_cptS 12 b a.val a.isLt (by omega)
      rw [hxB, mleAt_bitv, List.getD_eq_getElem?_getD,
        List.getElem?_replicate_of_lt (by rw [hhLog2]; exact msbIndex_lt 12 b), Option.getD_some, Fp2.toK_one]
    rw [hg0v, one_mul]
    let p1 : Block.Priv := ⟨.h, [((L.hOff incH_U).1, Fp2.one), ((L.hOff incH_U).2, Block.fp2U)],
      L.hLog.getD incH_U 0, rhoC 0 (L.hLog.getD incH_U 0), L.hMaskBase + 2 * (L.prefixH 3 + 0), 0⟩
    have h0 := claimSem_priv_cube_y0 Ps 76 12 (tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows) 12 hN3 b p1
      ((L.hOff incH_U).1, Fp2.one) [((L.hOff incH_U).2, Block.fp2U)] rfl (by rw [hhLog2, hrowH]; norm_num)
      (by intro c hc w hw; obtain ⟨_, -, hEq⟩ := List.mem_map.mp hc; rw [hw] at hEq; cases hEq)
    change Link.claimSem shdP_U 76 12 0 (tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows) _ = _
    rw [h0]
    simp only [p1, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
      Fp2.toK_one, one_mul, Block.toK_fp2U, hhOff2, hhLog2, rhoC, List.length_map, List.length_range', Nat.sub_zero]
    have hpt12 : ∀ a : Fin 12,
        Block.ptK shdP_U (Block.xrK 12 (fun i : Fin (slotN P 3) => (bit (cptS 12 b i) : shdP_K)))
          (rhoC 0 12) a.val = (bit (b a) : shdP_K) := by
      intro a; unfold Block.ptK
      have hget : (rhoC 0 12).getD a.val (Block.Coord.fixed Fp2.zero) = Block.Coord.rho a.val := by
        simp [rhoC, List.getD_eq_getElem?_getD, List.getElem?_range' a.isLt]
      rw [hget]; exact xrK_cptS 12 b a.val a.isLt (by omega)
    have hcolEq : dataKeyColK 270336 12 12 12
          (Block.ptK shdP_U (Block.xrK 12 (fun i : Fin (slotN P 3) => (bit (cptS 12 b i) : shdP_K))) (rhoC 0 12))
        = dataKeyColK 274432 12 12 12
          (Block.ptK shdP_U (Block.xrK 12 (fun i : Fin (slotN P 3) => (bit (cptS 12 b i) : shdP_K))) (rhoC 0 12)) := by
      funext t; unfold dataKeyColK; simp
    have hsplit : ∀ row : Fin 76,
        (dataRowK 270336 12 12 12 _ row + shdP_U * dataRowK 274432 12 12 12 _ row)
          * ∑ t : Fin (2 ^ 12 + 0), tabMat 76 12 (shdP_incTH Rp embDigest x rnd ch).rows row t * dataKeyColK 270336 12 12 12 _ t
        = dataRowK (66 * 2 ^ 12) 12 12 12 _ row * (∑ t, _ * dataKeyColK (66 * 2 ^ 12) 12 12 12 _ t)
          + shdP_U * (dataRowK (67 * 2 ^ 12) 12 12 12 _ row * (∑ t, _ * dataKeyColK (67 * 2 ^ 12) 12 12 12 _ t)) := by
      intro row
      change (dataRowK 270336 12 12 12 _ row + shdP_U * dataRowK 274432 12 12 12 _ row) * _
        = dataRowK 270336 12 12 12 _ row * (∑ t, _ * dataKeyColK 270336 12 12 12 _ t)
          + shdP_U * (dataRowK 274432 12 12 12 _ row * (∑ t, _ * dataKeyColK 274432 12 12 12 _ t))
      rw [← hcolEq]; ring
    simp_rw [hsplit, Finset.sum_add_distrib, ← Finset.mul_sum]
    rw [data_slice_single_row 76 12 66 (by norm_num) _ b _ hpt12,
      data_slice_single_row 76 12 67 (by norm_num) _ b _ hpt12]
    unfold shdP_incTH; rw [tabMat_mkRows, tabMat_mkRows]
    have h66 : shdP_incTHData Rp embDigest x rnd ch ⟨66, by norm_num⟩ ⟨msbIndex 12 b, msbIndex_lt 12 b⟩
        = Fp.ofGF (shdP_incHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).1 := rfl
    have h67 : shdP_incTHData Rp embDigest x rnd ch ⟨67, by norm_num⟩ ⟨msbIndex 12 b, msbIndex_lt 12 b⟩
        = Fp.ofGF (shdP_incHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).2 := rfl
    rw [h66, h67, Fp.toGF_ofGF, Fp.toGF_ofGF]
  simp_rw [hterm]
  let eBits : (Fin 12 → Bool) ≃ Fin 4096 :=
    { toFun := fun b => ⟨msbIndex 12 b, msbIndex_lt 12 b⟩
      invFun := fun col => msbBits 12 col.val
      left_inv := fun b => msbBits_msbIndex 12 b
      right_inv := fun col => Fin.ext (msbIndex_msbBits 12 col.val col.isLt) }
  have hre := Equiv.sum_comp eBits (fun col : Fin 4096 =>
    algebraMap GF shdP_K (shdP_incHUVal rnd col).1 + shdP_U * algebraMap GF shdP_K (shdP_incHUVal rnd col).2)
  change ∑ b : Fin 12 → Bool, (algebraMap GF shdP_K (shdP_incHUVal rnd (eBits b)).1
      + shdP_U * algebraMap GF shdP_K (shdP_incHUVal rnd (eBits b)).2) = 0
  rw [hre, Finset.sum_add_distrib, ← Finset.mul_sum, ← map_sum, ← map_sum,
    shdP_incHUVal_sum_re, shdP_incHUVal_sum_im, map_zero, mul_zero, add_zero]

end StageInSlotArith

/-! ## 3. `IncAccInv` induction, `shdP_inc_arith`, `shdP_inc_outClaims_true`, and `shdP_inc_segComplete_of_adm` -/

section StageInComplete

/-- Loop invariant carried across Stage IN-C slots `0, 1, 2, 3`:
`hostFs = []`, `ClaimTrue` on all 4 tables (`TA`, `TH`, `TE`, `TB_in`), and `mTrue` on all `M` functionals. -/
def IncAccInv (TA TH TE TB : Table) (M : MTable) (acc : Acc) : Prop :=
  acc.hostFs = []
  ∧ (∀ cl ∈ acc.claims.a,   ClaimTrue shdP_U (2 ^ 12) 12 TA.rows (toZClaim cl))
  ∧ (∀ cl ∈ acc.claims.h,   ClaimTrue shdP_U (2 ^ 12) 12 TH.rows (toZClaim cl))
  ∧ (∀ cl ∈ acc.claims.inp, ClaimTrue shdP_U (2 ^  8)  8 TE.rows (toZClaim cl))
  ∧ (∀ cl ∈ acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 TB.rows (toZClaim cl))
  ∧ (∀ mf ∈ acc.fs, mf.value.toK shdP_U =
      ∑ s' : Fin 4, ∑ j : Fin 512,
        fwt shdP_U (toMF mf) s' j
          * (mA shdP_U M 4 s').eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j))

/-- Single-slot induction step: proves `SlotSum` AND preserves `IncAccInv` across any slot `s < 4`. -/
theorem inc_slot_step {Hdr : Type} (H : HIn → Dig) (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (hP : Rp.inp.Valid) (hV : Rp.inp.V = 131072) (embDigest : Dig) (bInRow : ℕ)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (epR : EpxSalt 6) (rnd : IncRand) (ch : List Fp2) (hchLen : ch.length = 15) (hchCan : ∀ a ∈ ch, a.Canon)
    (hbad : incAlphaBad (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch) = false)
    (s : ℕ) (hs : s < 4) (hist : Hist) (acc : Acc) (t : Tr) :
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    let elog := incElog V.pub 14
    let TA := shdP_incTA x rnd
    let TH := shdP_incTH Rp embDigest x rnd ch
    let TE := shdP_epTable (Hdr := Hdr) tag x epR
    let TB := shdP_incTB Rp x rnd
    let D := shdP_incSlotData tag Rp embDigest bInRow ch TA TH TE TB rnd
    let Ps := atLog P (elog s)
    (∀ df, Ps.define s hist (t.challengeFp2Vec H (Ps.draws s)).1 = .ok df →
      SlotSum Ps shdP_U (sdAt D (elog s)) s hist acc df (slotC H Ps s t))
    ∧ (IncAccInv TA TH TE TB (shdP_incM rnd) acc →
        ∀ sp r acc' t', slotProve H Ps (sdAt D (elog s)) s hist acc t = .ok (sp, r, acc', t') →
          IncAccInv TA TH TE TB (shdP_incM rnd) acc') := by
  intro V P elog TA TH TE TB D Ps
  let cs := incCs TA TH TE TB
  let mRow := mRowKOf 4 rnd.mA
  have hti : V.pub.tiLog = 12 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).1
  have hvoc : V.pub.vocLog = 17 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.1
  have hep : V.pub.inEpWords = 256 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.2.1
  have hlw : clog2 V.pub.inEpWords = 8 := by rw [hep]; exact shdP_clog2_256
  have hlt : V.pub.lt = 12 := rfl
  -- Common bounds for slot `s < 4`
  obtain ⟨hd1, hd4, hN0, hN64, hNW⟩ : 1 ≤ slotD P s ∧ slotD P s ≤ 4 ∧ 0 < slotN P s ∧ slotN P s < 64
      ∧ slotN P s * slotD P s + 2 ≤ 512 := by
    have hsh : slotN P s = (match s with | 0 => 9 | 1 => 13 | 2 => 18 | _ => 13)
        ∧ slotD P s = (match s with | 0 => 3 | 1 => 4 | 2 => 4 | _ => 2) := by
      interval_cases s <;>
        (unfold slotN slotD Exec.Block.slotShape
         simp [P, IncV.bp, stageBP, IncV.geom, mGeom, IncV.lay, incLay, Lay.geomSlots, incSched, hlw, hti, hvoc, hlt])
    interval_cases s <;> omega
  -- Helper: from `Ps.define s hist dr = .ok df` with canonical `dr` of length `Ps.draws s`, extract `IndDegLE`, `cubeSum = 0`, `df.hosted = []`, `(df.poly vals).Canon`
  have hdefArith : ∀ (dr : List Fp2), dr.length = Ps.draws s → (∀ a ∈ dr, a.Canon) →
      ∀ df, Ps.define s hist dr = .ok df →
        IndDegLE (slotD P s) (slotPolyK P elog cs s df)
        ∧ cubeSum (slotPolyK P elog cs s df) = 0
        ∧ df.hosted = []
        ∧ ∀ vals, (df.poly vals).Canon := by
    intro dr hdrLen hdrCan df hdef
    interval_cases s
    · have hsh : slotD P 0 = 3 := by
        unfold slotD; show ((incLay V.pub 14).geomSlots.getD 0 (0, 0, 0)).2.2 = 3
        simp [incLay, Lay.geomSlots, incSched, hlw]
      rw [hsh]
      exact inc_slot0_arith (Hdr := Hdr) tag Rp embDigest bInRow x epR rnd ch dr hdrCan df hdef
    · have hsh : slotD P 1 = 4 := by
        unfold slotD; show ((incLay V.pub 14).geomSlots.getD 1 (0, 0, 0)).2.2 = 4
        simp [incLay, Lay.geomSlots, incSched, hti]
      have hdl : dr.length = 17 := by
        rw [hdrLen]; show incDraws V.pub 1 = 17; simp [incDraws, hti]
      rw [hsh]
      exact inc_slot1_arith (Hdr := Hdr) tag Rp hP hV embDigest bInRow x hx epR rnd ch hchLen hchCan hbad dr hdl hdrCan df hdef
    · have hsh : slotD P 2 = 4 := by
        unfold slotD; show ((incLay V.pub 14).geomSlots.getD 2 (0, 0, 0)).2.2 = 4
        simp [incLay, Lay.geomSlots, incSched, hvoc]
      have hdl : dr.length = 20 := by
        rw [hdrLen]; show incDraws V.pub 2 = 20; simp [incDraws, hvoc]
      rw [hsh]
      exact inc_slot2_arith (Hdr := Hdr) tag Rp embDigest bInRow x epR rnd ch hchCan hbad dr hdl hdrCan df hdef
    · have hsh : slotD P 3 = 2 := by
        unfold slotD; show ((incLay V.pub 14).geomSlots.getD 3 (0, 0, 0)).2.2 = 2
        simp [incLay, Lay.geomSlots, incSched, hlt]
      rw [hsh]
      exact inc_slot3_arith (Hdr := Hdr) tag Rp embDigest bInRow x epR rnd ch df hdef
  have hsum : ∀ df, Ps.define s hist (t.challengeFp2Vec H (Ps.draws s)).1 = .ok df →
      SlotSum Ps shdP_U (sdAt D (elog s)) s hist acc df (slotC H Ps s t) := by
    intro df hdef
    obtain ⟨hdeg0, hcube0, hhost0, _⟩ := hdefArith _ (chalVec_length H _ t) (chalVec_canon H _ t) df hdef
    -- `sdAt D (elog s)` is `polySlotData Ps ...` because `slotN Ps s = slotN P s` and `slotD Ps s = slotD P s` by `rfl`!
    refine slotSum_of_poly Ps shdP_U shdP_hbij _ _ _ s hist acc df (slotC H Ps s t) ?_ ?_ ?_
    · exact IndDegLE.add_smul hdeg0 (Link.maskPoly_indDeg mRow s (slotN P s) (slotD P s) hd1) _
    · intro claimed hcl
      rw [hhost0] at hcl
      simp only [Exec.Block.hostedSum, Except.ok.injEq] at hcl
      subst hcl
      refine ⟨ofK_canon shdP_U shdP_hbij _, ?_⟩
      rw [toK_ofK shdP_U shdP_hbij, cubeSum_add_smul, hcube0, zero_add]
    · intro rhoFull
      exact stgPrivVals_length shdP_U shdP_hbij Ps cs _ _ df.tabs
  refine ⟨hsum, fun hinv sp r acc' t' hprove => ?_⟩
  obtain ⟨hhostNil, hclA, hclH, hclE, hclB, hfsOk⟩ := hinv
  unfold slotProve at hprove
  split at hprove
  · cases hprove
  · rename_i df hdef
    split_ifs at hprove with hcZ _
    cases hchk : Exec.Block.slotDefChecks Ps s acc df with
    | error _ => simp [hchk] at hprove
    | ok _ =>
      cases hhost : Exec.Block.hostedSum acc.scalars (slotSP H Ps (sdAt D (elog s)) s hist acc t df).scalar df.hosted with
      | error _ => simp [hchk, hhost] at hprove
      | ok claimed =>
        cases htab : Block.tabVals
            (Block.oneMinusProd ((slotRho H Ps (sdAt D (elog s)) s hist acc t df).drop (Exec.Block.slotShape Ps s).1))
            ((slotRho H Ps (sdAt D (elog s)) s hist acc t df).take (Exec.Block.slotShape Ps s).1)
            (slotSP H Ps (sdAt D (elog s)) s hist acc t df).terms df.tabs 0 with
        | error _ => simp [hchk, hhost, htab] at hprove
        | ok vals =>
          simp only [hchk, hhost, htab, Except.ok.injEq, Prod.mk.injEq] at hprove
          obtain ⟨rfl, rfl, rfl, rfl⟩ := hprove
          obtain ⟨hdeg0, hcube0, hhost0, hpolyCan⟩ := hdefArith _ (chalVec_length H _ t) (chalVec_canon H _ t) df hdef
          have hkind : Ps.kind s = .standalone := by
            interval_cases s <;> rfl
          set c := slotC H Ps s t
          set sc := (sdAt D (elog s)).scalar s hist acc df c
          set rhoFull := slotRho H Ps (sdAt D (elog s)) s hist acc t df
          set fin := scFinalExec (slotSP H Ps (sdAt D (elog s)) s hist acc t df).rounds rhoFull claimed
          set gVal := (fin.sub (df.poly vals)).mul c.inv
          -- 1. Claims preservation via `HonestShieldMTable.slotClaims_claimTrue`
          let Q : Cm → Block.ZClaim → Prop
            | .a, cl => ClaimTrue shdP_U (2 ^ 12) 12 TA.rows (toZClaim cl)
            | .h, cl => ClaimTrue shdP_U (2 ^ 12) 12 TH.rows (toZClaim cl)
            | .inp, cl => ClaimTrue shdP_U (2 ^ 8) 8 TE.rows (toZClaim cl)
            | .out, cl => ClaimTrue shdP_U (2 ^ 14) 14 TB.rows (toZClaim cl)
          have hQ : ∀ (cm : Cm) (ps : List Block.ZPart) (v : Fp2), v.toK shdP_U = cs cm ⟨ps, Fp2.zero⟩ → Q cm ⟨ps, v⟩ := by
            intro cm ps v hv
            cases cm with
            | a => exact (claimTrue_iff_claimSem shdP_U 41 12 TA.rows (shdP_incTA_rows_len x rnd) ⟨ps, v⟩).mpr hv
            | h => exact (claimTrue_iff_claimSem shdP_U 76 12 TH.rows (shdP_incTH_rows_len Rp embDigest x rnd ch) ⟨ps, v⟩).mpr hv
            | inp => exact (claimTrue_iff_claimSem shdP_U 6 8 TE.rows (shdP_epTable_rows_length (Hdr := Hdr) tag x epR) ⟨ps, v⟩).mpr hv
            | out => exact (claimTrue_iff_claimSem shdP_U 38 14 TB.rows (shdP_incTB_rows_len Rp x rnd) ⟨ps, v⟩).mpr hv
          have hcl' := slotClaims_claimTrue Ps cs (rhoFull.take (Exec.Block.slotShape Ps s).1)
            (rhoFull.drop (Exec.Block.slotShape Ps s).1) df.tabs acc.claims Q hQ ⟨hclA, hclH, hclE, hclB⟩
          -- 2. `gVal.toK shdP_U = maskPoly mRow s (slotN P s) (slotD P s) (vecK rhoFull)` via `scVerify_honest` + `SlotW16Ir.terminal_iff`
          have hcCan : c.Canon := canon_challengeFp2Of _
          have hcNe : c ≠ Fp2.zero := fun h0 => hcZ (by rw [h0]; rfl)
          have hclEq : claimed = sc := by
            rw [hhost0] at hhost; exact (Except.ok.inj hhost).symm
          have hclCan : claimed.Canon := by rw [hclEq]; exact ofK_canon shdP_U shdP_hbij _
          have hclVal : claimed.toK shdP_U = cubeSum (fun z =>
              slotPolyK P elog cs s df z + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z) := by
            rw [hclEq, toK_ofK shdP_U shdP_hbij, cubeSum_add_smul, hcube0, zero_add]
          have hdegM : IndDegLE (slotD P s) (fun z =>
              slotPolyK P elog cs s df z + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z) :=
            IndDegLE.add_smul hdeg0 (Link.maskPoly_indDeg mRow s (slotN P s) (slotD P s) hd1) _
          obtain ⟨fin', hscV, hfin'Val, _⟩ := scVerify_honest shdP_U H shdP_hU hd1 (lt_of_le_of_lt hd4 (by norm_num [gP]))
            (slotN P s) (honestW shdP_U shdP_hbij (slotD P s) (slotN P s) _) _ hdegM
            (honestW_honest shdP_U shdP_hbij _ _ _) claimed hclCan hclVal (slotT4 H Ps s t sc)
          have hfinEq : fin' = fin := (scVerify_fin_eq H claimed (slotD P s) (slotN P s) hd1 _ _ fin' _ hscV).1
          have hrhoLen : rhoFull.length = slotN P s := by
            show (scChal H (scProve H (slotN P s) _ _).1 _).1.length = slotN P s
            rw [scChal_length, scProve_length]
          have hrhoCan : ∀ a ∈ rhoFull, a.Canon := scChal_canon H _ _
          have hfinToK : fin.toK shdP_U = (df.poly vals).toK shdP_U
              + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) (vecK shdP_U (slotN P s) rhoFull) := by
            rw [← hfinEq, hfin'Val]
            have hspEq := slotPolyK_vecK_eq P elog cs s df rhoFull vals hrhoLen hrhoCan htab
            change slotPolyK P elog cs s df (vecK shdP_U (slotN P s) rhoFull)
              + c.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) (vecK shdP_U (slotN P s) rhoFull) = _
            rw [hspEq]
          have hgValToK : gVal.toK shdP_U = Link.maskPoly mRow s (slotN P s) (slotD P s) (vecK shdP_U (slotN P s) rhoFull) :=
            (Slot.terminal_iff shdP_U shdP_hU fin (df.poly vals) c
              (canon_scFinalExec _ _ _ hclCan) (hpolyCan vals) hcCan hcNe _).mpr hfinToK
          -- 3. Assemble `IncAccInv` for `slotAcc Ps s acc df c sc gVal rhoFull terms`
          refine ⟨by simp [Exec.Block.slotAcc, hkind, hhostNil], hcl'.1, hcl'.2.1, hcl'.2.2.1, hcl'.2.2.2, ?_⟩
          intro mf hmf
          simp only [Exec.Block.slotAcc, hkind, List.mem_append, List.mem_cons, List.not_mem_nil, or_false] at hmf
          rcases hmf with (hold | rfl) | rfl
          · exact hfsOk mf hold
          · -- Sum functional `⟨[(s, sw)], sc⟩`
            rw [mTrue_singleton_mdot 4 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts s hs _ _,
              mTrue_sumWeights_eq 4 rnd.mA s (slotN P s) (slotD P s) hN0 hN64 hNW c]
            exact toK_ofK shdP_U shdP_hbij _
          · -- Eval functional `⟨[(s, evalWeights rhoFull d)], gVal⟩`
            rw [mTrue_singleton_mdot 4 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts s hs _ _,
              mTrue_evalWeights_eq 4 rnd.mA s (slotN P s) (slotD P s) hN0 rhoFull hrhoLen hNW]
            exact hgValToK

/-- Unroll `inc_slot_step` across all 4 slots `s = 0, 1, 2, 3`. -/
theorem shdP_inc_slots_ok {Hdr : Type} (H : HIn → Dig) (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (hP : Rp.inp.Valid) (hV : Rp.inp.V = 131072) (embDigest : Dig) (bInRow : ℕ)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (epR : EpxSalt 6) (rnd : IncRand) (ch : List Fp2) (hchLen : ch.length = 15) (hchCan : ∀ a ∈ ch, a.Canon)
    (hbad : incAlphaBad (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch) = false) :
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    let elog := incElog V.pub 14
    let TA := shdP_incTA x rnd
    let TH := shdP_incTH Rp embDigest x rnd ch
    let TE := shdP_epTable (Hdr := Hdr) tag x epR
    let TB := shdP_incTB Rp x rnd
    let D := shdP_incSlotData tag Rp embDigest bInRow ch TA TH TE TB rnd
    ∀ (m s : ℕ), s + m ≤ 4 →
      ∀ (recs : List SlotRec) (acc : Acc) (t : Tr),
        StSlotsSum H P elog shdP_U D Fp2.zero Fp2.zero Fp2.zero m recs s acc t
        ∧ (IncAccInv TA TH TE TB (shdP_incM rnd) acc →
            ∀ sps recs' acc' t', stSlotsProve H P elog D Fp2.zero Fp2.zero Fp2.zero m recs s acc t = .ok (sps, recs', acc', t') →
              IncAccInv TA TH TE TB (shdP_incM rnd) acc') := by
  intro V P elog TA TH TE TB D m
  induction m with
  | zero =>
    intro s _ recs acc t
    refine ⟨trivial, fun hinv sps recs' acc' t' h => ?_⟩
    simp only [stSlotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨_, _, rfl, _⟩ := h
    exact hinv
  | succ m' ih =>
    intro s hsm recs acc t
    have hstep := inc_slot_step (Hdr := Hdr) H tag Rp hP hV embDigest bInRow x hx epR rnd ch hchLen hchCan hbad
      s (by omega) (Exec.Block.histOf Fp2.zero Fp2.zero Fp2.zero recs) acc t
    refine ⟨⟨hstep.1, fun sp r acc₁ t₁ _ => (ih (s + 1) (by omega) (recs ++ [r]) acc₁ t₁).1⟩,
      fun hinv sps recs' acc' t' h => ?_⟩
    simp only [stSlotsProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨_, _, rfl, _⟩ := h
        exact (ih (s + 1) (by omega) (recs ++ [r]) acc₁ t₁).2 (hstep.2 hinv sp r acc₁ t₁ hsp) sps₁ recs₁ acc₂ t₂ hrest

/-- **Main Stage IN-C arithmetic theorem**: discharges ALL 20 conjuncts of `HonestShieldStages.shdP_inc_segComplete`'s
`hArith` AND proves `ClaimTrue` on `R.acc.claims.out` against `TB_in` (the carry invariant for Block 0)! -/
theorem shdP_inc_arith {Hdr : Type} (H : HIn → Dig) (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (hP : Rp.inp.Valid) (hV : Rp.inp.V = 131072) (embDigest : Dig) (bInRow : ℕ)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (epR : EpxSalt 6) (rnd : IncRand) (t : Tr) (R : IncRun)
    (hR : incProve H (shdVi tag Rp embDigest bInRow)
      (incDataAt H tag shdP_U shdP_hbij (shdVi tag Rp embDigest bInRow) 2 3 256 256
        (shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x epR rnd) t) t = .ok R) :
    let ct := shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x epR rnd
    ((∀ s hist acc df ch0, ((ct.slot R.ch).scalar s hist acc df ch0).Canon)
      ∧ (∀ s hist acc df ch0 rho, ∀ w ∈ (ct.slot R.ch).terms s hist acc df ch0 rho, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TA.cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ (ct.TH R.ch).cols j, w.Canon)
      ∧ (∀ j, ∀ w ∈ ct.TE.cols j, w.Canon)
      ∧ (∀ j, (ct.TA.cols j).length = ct.TA.rows.length)
      ∧ (∀ j, ((ct.TH R.ch).cols j).length = (ct.TH R.ch).rows.length)
      ∧ (∀ j, (ct.TE.cols j).length = ct.TE.rows.length)
      ∧ StSlotsSum H ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub R.ch))
          (incElog (shdVi tag Rp embDigest bInRow).pub 14) shdP_U (ct.slot R.ch) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} R.t3
      ∧ MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) ct.M 4
      ∧ (∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
          (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK shdP_U
            = mTrue (algebraMap GF shdP_K (rootFp 9).toGF) (wtOf shdP_U ((R.acc.fs ++ R.acc.hostFs).map toMF) 4)
                (mA shdP_U ct.M 4) i)
      ∧ 41 = ct.TA.rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) ct.TA
      ∧ (∀ cl ∈ R.acc.claims.a, ClaimTrue shdP_U (2 ^ 12) 12 ct.TA.rows (toZClaim cl))
      ∧ 76 = (ct.TH R.ch).rows.length
      ∧ ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2) (ct.TH R.ch)
      ∧ (∀ cl ∈ R.acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim],
          ClaimTrue shdP_U (2 ^ 12) 12 (ct.TH R.ch).rows (toZClaim cl))
      ∧ 6 = ct.TE.rows.length
      ∧ ColsHonest shdP_U (lagK 8 (by norm_num)) 256 (cosetPt (rootFp 11)) (2 ^ 8 * 2 ^ 3) ct.TE
      ∧ (∀ cl ∈ R.acc.claims.inp, ClaimTrue shdP_U (2 ^ 8) 8 ct.TE.rows (toZClaim cl)))
    ∧ (∀ cl ∈ R.acc.claims.out, ClaimTrue shdP_U (2 ^ 14) 14 (shdP_incTB Rp x rnd).rows (toZClaim cl)) := by
  intro ct
  obtain ⟨hxV, -, -, -, -⟩ := inSpec_of_adm Rp hV x hx
  obtain ⟨hbad, hch, -, hslotsP, -, -, -, -, -, -, -, -, -, -, -, -, -⟩ :=
    incProve_ok H (shdVi tag Rp embDigest bInRow) _ t R hR
  have hchLen : R.ch.length = 15 := by
    rw [hch]
    unfold incCh
    rw [chalVec_length]
    exact (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.2.2.2
  have hchCan : ∀ a ∈ R.ch, a.Canon := by
    rw [hch]
    exact chalVec_canon H _ _
  have hsl := shdP_inc_slots_ok (Hdr := Hdr) H tag Rp hP hV embDigest bInRow x hx epR rnd R.ch hchLen hchCan hbad
    4 0 (by norm_num) [] {} R.t3
  have hinv0 : IncAccInv (shdP_incTA x rnd) (shdP_incTH Rp embDigest x rnd R.ch)
      (shdP_epTable (Hdr := Hdr) tag x epR) (shdP_incTB Rp x rnd) (shdP_incM rnd) {} :=
    ⟨rfl, fun _ h => by cases h, fun _ h => by cases h, fun _ h => by cases h,
      fun _ h => by cases h, fun _ h => by cases h⟩
  obtain ⟨hhostNil, hclA, hclH, hclE, hclB, hfsOk⟩ := hsl.2 hinv0 R.seg.core.slots R.recs R.acc R.t4 hslotsP
  refine ⟨⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, hsl.1, ?_, ?_, ?_, ?_, hclA, ?_, ?_, ?_, ?_, ?_, hclE⟩, hclB⟩
  · intro _ _ _ _ _; exact ofK_canon shdP_U shdP_hbij _
  · intro _ _ _ _ _ _ w hw; exact stgPrivVals_canon shdP_U shdP_hbij _ _ _ _ _ w hw
  · exact mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _
  · exact mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _
  · exact shdP_epTable_cols_canon (Hdr := Hdr) tag x epR
  · exact mkPcsTable_cols_length 12 2 256 (by norm_num) _ _
  · exact mkPcsTable_cols_length 12 2 256 (by norm_num) _ _
  · exact shdP_epTable_cols_length (Hdr := Hdr) tag x epR
  · exact mkMTable_honest 4 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts
  · intro i
    have hmem : (R.acc.fs ++ R.acc.hostFs)[i.val]'(by simpa using i.isLt) ∈ R.acc.fs := by
      have hm := List.getElem_mem (l := R.acc.fs ++ R.acc.hostFs) (n := i.val) (by simpa using i.isLt)
      rwa [hhostNil, List.append_nil] at hm
    have hget : ((R.acc.fs ++ R.acc.hostFs).map toMF).get i
        = toMF ((R.acc.fs ++ R.acc.hostFs)[i.val]'(by simpa using i.isLt)) := by
      simp [List.get_eq_getElem]
    unfold mTrue wtOf
    rw [hget]
    exact hfsOk _ hmem
  · exact (shdP_incTA_rows_len x rnd).symm
  · exact shdP_incTA_colsHonest x rnd
  · exact (shdP_incTH_rows_len Rp embDigest x rnd R.ch).symm
  · exact shdP_incTH_colsHonest Rp embDigest x rnd R.ch
  · intro cl hcl
    rcases List.mem_append.mp hcl with h1 | h2
    · exact hclH cl h1
    · rw [List.mem_singleton.mp h2]
      exact shdP_inc_logupSumClaim_true tag Rp embDigest bInRow x hxV rnd R.ch
  · exact (shdP_epTable_rows_length (Hdr := Hdr) tag x epR).symm
  · exact shdP_epTable_colsHonest (Hdr := Hdr) tag x epR

/-- **Top-level Stage IN-C `SegComplete` theorem**: discharges `hsegIn` of `RunShieldOpenShell.sshC_productionReadyL_epP_openShell`
completely from `Rp.inp.Valid`, `Rp.inp.V = 131072`, and `(classifyModelP Rp).admissible x`! -/
theorem shdP_inc_segComplete_of_adm {Hdr Coins : Type} (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (Rp : ClassifyRunPublicP shieldS0) (hP : Rp.inp.Valid) (hV : Rp.inp.V = 131072)
    (embDigest : Dig) (bInRow : ℕ)
    (epBase : Coins → EpxSalt 6) (rndOf : Coins → IncRand)
    (stOf : (QB Lq → Dig) → (shieldS0.Tok → ℕ) → Coins → ClsStmt Hdr)
    (hInRoot : ∀ G x c, (classifyModelP Rp).admissible x →
      (stOf G x c).inRoot = honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr (Hdr := Hdr) tag hL20) G x (epBase c)) :
    SegComplete (classifyModelP Rp).admissible (fun G : QB Lq → Dig => liftH G) stOf
      (inSegP _ (shdP_incP tag Rp embDigest bInRow (fun H _ x c =>
        shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x (epBase c) (rndOf c))))
      (inSeg (incStageV (fun _ : Hdr => shdVi tag Rp embDigest bInRow) (fun _ => shdGi tag Rp embDigest bInRow))) :=
  shdP_inc_segComplete tag Rp embDigest bInRow (classifyModelP Rp).admissible
    (fun G : QB Lq → Dig => liftH G) stOf
    (fun H _ x c => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x (epBase c) (rndOf c))
    (fun G x c hx => by
      rw [hInRoot G x c hx]
      exact shdP_epTable_root (Hdr := Hdr) tag Lq hL20 G x (epBase c))
    (fun G x c t R hx hR =>
      (shdP_inc_arith (Hdr := Hdr) (liftH G) tag Rp hP hV embDigest bInRow x hx (epBase c) (rndOf c) t R hR).1)

end StageInComplete

end ZK60.HonestShield
