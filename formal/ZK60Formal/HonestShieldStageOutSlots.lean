/-
D63 lane L68c, part 1c-ii (`HonestShieldStageOutArith.lean`):
complete, zero-`sorry` Stage OUT-C slot arithmetic (`OUTC-00..07`), `OutcAccInv` induction
(including `.priv` slots `1, 3` and `.host` slots `2, 4` with 2-term `acc.hostFs` via `mTrue_terms_mdot`),
`shdP_outc_arith` (all 20 conjuncts of `HonestShieldStages.shdP_outc_segComplete`'s `hArith`),
and top-level **`shdP_outc_segComplete_of_adm`** discharging `hsegOut` of
`RunShieldOpenShell.sshC_productionReadyL_epP_openShell`!

Only at most `propext`, `Classical.choice`, `Quot.sound`; zero `sorry`s.
-/
import ZK60Formal.HonestShieldStageOutTables
import ZK60Formal.HonestShieldStageInArith

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

/-! ## 1. Common `define = .ok df` extractors & helpers for Stage OUT-C (`0..7`) -/

section StageOutSlotHelpers

theorem outcDefTZC_eq_of_ok (O : OutcPub) (G : OutcGeo)
    (dr : List Fp2) (hlen : dr.length = 7) (hcan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : outcDefTZC O G dr = .ok df) :
    let L := outcLay O G.bLogN
    let mu := (dr.drop 1).take 4
    let nu := dr.getD 5 Fp2.zero
    let zeta := dr.getD 6 Fp2.zero
    df = ⟨
      .eq (dr.take OutcPub.toLog) 0 :: (
        [.pub (supp 1 (2 ^ OutcPub.toLog)),
         .priv ⟨.a, [(L.aOff ocC_D, Fp2.one)], L.aLog.getD ocC_D 0,
           rhoC 0 (L.aLog.getD ocC_D 0), L.aMaskBase + 2 * (L.prefixA 2 + 0), 0⟩,
         .priv ⟨.a, [(L.aOff ocC_DSQ, Fp2.one)], L.aLog.getD ocC_DSQ 0,
           rhoC 0 (L.aLog.getD ocC_DSQ 0), L.aMaskBase + 2 * (L.prefixA 2 + 1), 0⟩]
        ++ ((List.range (3 * OutcPub.limbsIsqrt)).zipIdx 2).map (fun p =>
          Block.Tab.priv ⟨.a, [(L.aOff ocC_LIMB + 2 * p.1, Fp2.one)], OutcPub.toLog,
            rhoC 0 OutcPub.toLog, L.aMaskBase + 2 * (L.prefixA 2 + p.2), 0⟩)),
      tzcPoly mu nu zeta (kI O.ceps), [(1, nu)]⟩ := by
  let y : Fin 7 → shdP_K := vecK shdP_U 7 dr
  have hwords : stgWords shdP_U shdP_hbij y = dr :=
    stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 7 hlen
  have hne : ∀ i ∈ Z_range 7 1 6, y i ≠ 0 := by
    intro i hi hy0
    obtain ⟨msg, hmsg⟩ := outcDefTZC_err shdP_U shdP_hbij shdP_hU O G y ⟨i, hi, hy0⟩
    rw [hwords] at hmsg; rw [hmsg] at hdef; cases hdef
  have hok := outcDefTZC_ok shdP_U shdP_hbij shdP_hU O G rfl y hne
  dsimp only at hok; rw [hwords] at hok; rw [hok] at hdef
  exact (Except.ok.inj hdef).symm

theorem outcDefLZC_eq_of_ok (O : OutcPub) (G : OutcGeo) (hist : Hist) (hllo : O.llo = 12)
    (dr : List Fp2) (hlen : dr.length = 15) (hcan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : outcDefLZC O G hist dr = .ok df) :
    let L := outcLay O G.bLogN
    let mu := (dr.drop O.llo).take 2
    let nu := dr.getD (O.llo + 2) Fp2.zero
    let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
    let loN := 2 ^ O.llo
    df = ⟨[
      .eq (dr.take O.llo) 0,
      .pub (liveTab loN OutcPub.lamBase O.limbs),
      .pub (gTab loN OutcPub.lamBase O.limbs O.verdict),
      .pub (supp 1 loN),
      .priv ⟨.a, [(L.aOff ocC_LIMB, Fp2.one)], L.aLog.getD ocC_LIMB 0,
        rhoC 0 (L.aLog.getD ocC_LIMB 0), L.aMaskBase + 2 * (L.prefixA 4 + 0), 0⟩,
      .priv ⟨.h, [((L.hOff ocH_LO).1, Fp2.one), ((L.hOff ocH_LO).2, Block.fp2U)],
        L.hLog.getD ocH_LO 0, rhoC 0 (L.hLog.getD ocH_LO 0), L.hMaskBase + 2 * (L.prefixH 4 + 0), 0⟩
    ], lzcPoly mu nu hist.alpha gU8 ((kI O.verdict).add (kI O.c)), [(3, nu)]⟩ := by
  let y : Fin 15 → shdP_K := vecK shdP_U 15 dr
  have hwords : stgWords shdP_U shdP_hbij y = dr :=
    stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 15 hlen
  have hne : ∀ i ∈ Z_range 15 O.llo 3, y i ≠ 0 := by
    intro i hi hy0
    obtain ⟨msg, hmsg⟩ := outcDefLZC_err shdP_U shdP_hbij shdP_hU O G hist y ⟨i, hi, hy0⟩
    rw [hwords] at hmsg; rw [hmsg] at hdef; cases hdef
  have hok := outcDefLZC_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hne
  dsimp only at hok; rw [hwords] at hok; rw [hok] at hdef
  exact (Except.ok.inj hdef).symm

theorem outcDefDZC_eq_of_ok (O : OutcPub) (G : OutcGeo) (hist : Hist) (hldo : O.ldo = 12)
    (dr : List Fp2) (hlen : dr.length = 23) (hcan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : outcDefDZC O G hist dr = .ok df) :
    let L := outcLay O G.bLogN
    let mu := (dr.drop O.ldo).take 10
    let zeta := dr.getD (O.ldo + 10) Fp2.zero
    let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
    df = ⟨
      .eq (dr.take O.ldo) 0 :: (
        .pub (supp O.d (2 ^ O.ldo)) :: (
          ((List.range' ocC_X (ocC_MULT - ocC_X)).zipIdx 0).map (fun p =>
            Block.Tab.priv ⟨.a, [(L.aOff p.1, Fp2.one)], L.aLog.getD p.1 0,
              rhoC 0 (L.aLog.getD p.1 0), L.aMaskBase + 2 * (L.prefixA 5 + p.2), 0⟩)
          ++ [.priv ⟨.a, [(L.aOff ocC_D, Fp2.one)], L.aLog.getD ocC_D 0,
              fixedC (List.replicate OutcPub.toLog Fp2.zero),
              L.aMaskBase + 2 * (L.prefixA 5 + (0 + (List.range' ocC_X (ocC_MULT - ocC_X)).length)), 0⟩]
          ++ ((List.range 6).zipIdx 0).map (fun p =>
            let pl := ocH_D0 + p.1
            Block.Tab.priv ⟨.h, [((L.hOff pl).1, Fp2.one), ((L.hOff pl).2, Block.fp2U)],
              L.hLog.getD pl 0, rhoC 0 (L.hLog.getD pl 0),
              L.hMaskBase + 2 * (L.prefixH 5 + p.2), 0⟩))),
      dzcPoly mu zeta hist.alpha gU8 (kI (2 * O.g0 * O.cn)) (kI (2 ^ O.tn)) (kI (2 ^ (O.tn + 1))), []⟩ := by
  let y : Fin 23 → shdP_K := vecK shdP_U 23 dr
  have hwords : stgWords shdP_U shdP_hbij y = dr :=
    stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 23 hlen
  have hne : ∀ i ∈ Z_range 23 O.ldo 11, y i ≠ 0 := by
    intro i hi hy0
    obtain ⟨msg, hmsg⟩ := outcDefDZC_err shdP_U shdP_hbij shdP_hU O G hist y ⟨i, hi, hy0⟩
    rw [hwords] at hmsg; rw [hmsg] at hdef; cases hdef
  have hok := outcDefDZC_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hne
  dsimp only at hok; rw [hwords] at hok; rw [hok] at hdef
  exact (Except.ok.inj hdef).symm

theorem outcDefTAB_eq_of_ok (O : OutcPub) (G : OutcGeo) (hist : Hist) (hltab : O.ltab = 12)
    (dr : List Fp2) (hlen : dr.length = 15) (hcan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : outcDefTAB O G hist dr = .ok df) :
    let L := outcLay O G.bLogN
    let mu := (dr.drop O.ltab).take 2
    let zeta := dr.getD (O.ltab + 2) Fp2.zero
    let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
    df = ⟨[
      .eq (dr.take O.ltab) 0,
      .pub (supp OutcPub.u8Len (2 ^ O.ltab)),
      .pub (tvTab (2 ^ O.ltab) gU8),
      .priv ⟨.a, [(L.aOff ocC_MULT, Fp2.one)], L.aLog.getD ocC_MULT 0,
        rhoC 0 (L.aLog.getD ocC_MULT 0), L.aMaskBase + 2 * (L.prefixA 6 + 0), 0⟩,
      .priv ⟨.h, [((L.hOff ocH_GU8).1, Fp2.one), ((L.hOff ocH_GU8).2, Block.fp2U)],
        L.hLog.getD ocH_GU8 0, rhoC 0 (L.hLog.getD ocH_GU8 0), L.hMaskBase + 2 * (L.prefixH 6 + 0), 0⟩
    ], tabPoly mu zeta hist.alpha, []⟩ := by
  let y : Fin 15 → shdP_K := vecK shdP_U 15 dr
  have hwords : stgWords shdP_U shdP_hbij y = dr :=
    stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 15 hlen
  have hne : ∀ i ∈ Z_range 15 O.ltab 3, y i ≠ 0 := by
    intro i hi hy0
    obtain ⟨msg, hmsg⟩ := outcDefTAB_err shdP_U shdP_hbij shdP_hU O G hist y ⟨i, hi, hy0⟩
    rw [hwords] at hmsg; rw [hmsg] at hdef; cases hdef
  have hok := outcDefTAB_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hne
  dsimp only at hok; rw [hwords] at hok; rw [hok] at hdef
  exact (Except.ok.inj hdef).symm

/-- Helper: `Fp.fromI64 v` embedded into `shdP_K` equals `(v : shdP_K)` for `|v| < 2^64`. -/
theorem fp_fromI64_toK (v : ℤ) (h1 : -2 ^ 64 < v) (h2 : v < 2 ^ 64) :
    algebraMap GF shdP_K (Fp.fromI64 v).toGF = (v : shdP_K) := by
  rw [Fp.toGF_fromI64 v h1 h2, map_intCast]

/-- Helper: `outcLay` `aLog` for `p < 16` (`1` for `p < 2`, `12` for `2 ≤ p < 16`). -/
theorem shdP_outcLay_aLog (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (v p : ℕ) (hp : p < 16) :
    (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).aLog.getD p 0 = if p < 2 then 1 else 12 := by
  obtain ⟨hllo, hldo, hltab, _⟩ := shdP_outcPub_logs Rp wDigest
  have hllo' : (rcVerdict (shdP_outcPub Rp wDigest) v).llo = 12 := hllo
  have hldo' : (rcVerdict (shdP_outcPub Rp wDigest) v).ldo = 12 := hldo
  have hltab' : (rcVerdict (shdP_outcPub Rp wDigest) v).ltab = 12 := hltab
  have haLog : (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).aLog
      = [1, 1] ++ List.replicate 14 12 := by
    simp only [outcLay, OutcPub.toLog, hllo', hldo', hltab', List.replicate]
    rfl
  rw [haLog]
  interval_cases p <;> rfl

/-- Helper: `outcLay` `hLog` for `p < 9` is `12`. -/
theorem shdP_outcLay_hLog (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (v p : ℕ) (hp : p < 9) :
    (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hLog.getD p 0 = 12 := by
  obtain ⟨hllo, hldo, hltab, _⟩ := shdP_outcPub_logs Rp wDigest
  have hllo' : (rcVerdict (shdP_outcPub Rp wDigest) v).llo = 12 := hllo
  have hldo' : (rcVerdict (shdP_outcPub Rp wDigest) v).ldo = 12 := hldo
  have hltab' : (rcVerdict (shdP_outcPub Rp wDigest) v).ltab = 12 := hltab
  have hlt' : (rcVerdict (shdP_outcPub Rp wDigest) v).lt = 12 := rfl
  have hhLog : (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hLog = List.replicate 9 12 := by
    simp only [outcLay, hllo', hldo', hltab', hlt', List.replicate]
    rfl
  rw [hhLog, List.getD_eq_getElem?_getD, List.getElem?_replicate, ite_eq_left hp, Option.getD_some]

/-- Helper: `shdVo` slot shapes for `s < 8`. -/
theorem shdP_outc_slotShape (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v s : ℕ) :
    Exec.Block.slotShape (shdVo tag Rp wDigest bOutRow v).bp s =
      match s with
      | 0 => (12, 1, 2)
      | 1 => (12, 1, 4)
      | 2 => (1, 1, 3)
      | 3 => (12, 1, 2)
      | 4 => (12, 1, 4)
      | 5 => (12, 1, 5)
      | 6 => (12, 1, 3)
      | 7 => (12, 1, 2)
      | _ => (0, 0, 0) := by
  have hgs := (shdP_outcLay_nums Rp wDigest).2.2.2
  have hgs' : (shdVo tag Rp wDigest bOutRow v).bp.geom.slots
      = [(12, 1, 2), (12, 1, 4), (1, 1, 3), (12, 1, 2), (12, 1, 4), (12, 1, 5), (12, 1, 3), (12, 1, 2)] := hgs
  unfold Exec.Block.slotShape
  rw [hgs']
  match s with
  | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 => rfl
  | s + 8 =>
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none (by simp), Option.getD_none]
    rfl

/-- Helper: `atLog V.bp 14 = V.bp` for `V = shdVo ...` (since `endpointLogN = 14`). -/
theorem shdVo_atLog_14 (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ) :
    atLog (shdVo tag Rp wDigest bOutRow v).bp 14 = (shdVo tag Rp wDigest bOutRow v).bp := rfl

private theorem outc_rowLog_a (V : OutcV) (hlt : V.pub.lt = 12) :
    Block.rowLog V.bp .a = 12 := by
  show V.pub.lt = 12; exact hlt

private theorem outc_rowLog_h (V : OutcV) (hlt : V.pub.lt = 12) :
    Block.rowLog V.bp .h = 12 := by
  show V.pub.lt = 12; exact hlt

private theorem outc_rowLog_inp (V : OutcV) (hb : V.geo.bLogN = 14) :
    Block.rowLog V.bp .inp = 14 := by
  show V.geo.bLogN = 14; exact hb

/-- Helper: single-row `A` table (`log = 12`, `rhoC 0 12`, plane `p`, `2 ≤ p < 16`) has `IndDegLE 1`
and evaluates at `cptS 12 b` to `algebraMap GF shdP_K (shdP_outcTAData Rp w rnd ⟨p, _⟩ ⟨msbIndex 12 b, _⟩).toGF`. -/
theorem outc_tabA12_spec (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (TB : Table) (rnd : OutcRand) (gamma alpha : Fp2)
    (p mr : ℕ) (hp2 : 2 ≤ p) (hp16 : p < 16) :
    let V := shdVo tag Rp wDigest bOutRow v
    let P := V.bp
    let L := outcLay V.pub 14
    let cs := outcCs (shdP_outcTA Rp w rnd) (shdP_outcTH Rp w rnd gamma alpha) TB
    let tb := Tab.priv ⟨.a, [(L.aOff p, Fp2.one)], L.aLog.getD p 0, rhoC 0 (L.aLog.getD p 0), mr, 0⟩
    IndDegLE 1 (fun z : Fin 13 → shdP_K => stgTabK shdP_U shdP_hbij P cs 12 1 z tb)
    ∧ ∀ b : Fin 12 → Bool,
        stgTabK shdP_U shdP_hbij P cs 12 1 (fun i : Fin 13 => (bit (cptS 12 b i) : shdP_K)) tb
          = algebraMap GF shdP_K (shdP_outcTAData Rp w rnd ⟨p, by omega⟩ ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).toGF := by
  intro V P L cs tb
  have hlog : L.aLog.getD p 0 = 12 :=
    (shdP_outcLay_aLog Rp wDigest v p hp16).trans (ite_eq_right (by omega))
  have hoff : L.aOff p = p * 4096 := shdP_outcLay_aOff Rp wDigest v p hp16
  have hrowA : Block.rowLog P .a = 12 := outc_rowLog_a V rfl
  refine ⟨?_, fun b => ?_⟩
  · exact indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU P 76 12 0
      (tabMat 76 12 (shdP_outcTA Rp w rnd).rows) (N := 13) 12 1 rfl
      ⟨.a, [(L.aOff p, Fp2.one)], L.aLog.getD p 0, rhoC 0 (L.aLog.getD p 0), mr, 0⟩
      (by simp) (by rw [hlog, hrowA]; norm_num)
      (by simpa using varsOKb_fixed_rho_fixed [] [] 0 (L.aLog.getD p 0)
            (fun _ h => by cases h) (fun _ h => by cases h))
      (fun c hc _ hw => by obtain ⟨_, _, h⟩ := List.mem_map.mp hc; rw [hw] at h; cases h)
  · change Link.claimSem shdP_U 76 12 0 (tabMat 76 12 (shdP_outcTA Rp w rnd).rows) _ = _
    rw [claimSem_priv_cube_y0 P 76 12 (tabMat 76 12 (shdP_outcTA Rp w rnd).rows) 12 rfl b _
      (L.aOff p, Fp2.one) [] rfl (by rw [hlog, hrowA]; norm_num)
      (fun c hc _ hw => by obtain ⟨_, _, h⟩ := List.mem_map.mp hc; rw [hw] at h; cases h)]
    have hrhoLen : (rhoC 0 12).length = 12 := by simp [rhoC]
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, Fp2.toK_one, one_mul,
      hoff, hlog, hrhoLen]
    have hpt : ∀ a : Fin 12, Block.ptK shdP_U
        (Block.xrK 12 (fun i : Fin 13 => (bit (cptS 12 b i) : shdP_K)))
        (rhoC 0 12) a.val = (bit (b a) : shdP_K) := by
      intro a
      unfold Block.ptK
      simp only [rhoC, List.getElem?_map, List.getElem?_range' a.isLt, Option.map_some, Option.getD_some,
        Block.coordK, Nat.zero_add, one_mul]
      exact xrK_cptS (N := 13) 12 b a.val a.isLt (by norm_num)
    have hds := data_slice_single_row 76 12 p (by omega) (tabMat 76 12 (shdP_outcTA Rp w rnd).rows) b _ hpt
    rw [show p * 4096 = p * 2 ^ 12 by norm_num, hds,
      show (shdP_outcTA Rp w rnd).rows = mkRows 76 (2 ^ 12) 256 (shdP_outcTAData Rp w rnd) rnd.aPads from rfl]
    exact tabMat_mkRows 76 12 256 _ _ ⟨p, by omega⟩ ⟨msbIndex 12 b, by have := msbIndex_lt 12 b; omega⟩

/-- Helper: single-row `H` table (`log = 12`, `rhoC 0 12`, plane `p < 8`) has `IndDegLE 1`
and evaluates at `cptS 12 b` to `shdP_outcHValK Rp w gamma alpha ⟨p, _⟩ ⟨msbIndex 12 b, _⟩`. -/
theorem outc_tabH12_spec (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (TB : Table) (rnd : OutcRand) (gamma alpha : Fp2)
    (p mr : ℕ) (hp8 : p < 8) :
    let V := shdVo tag Rp wDigest bOutRow v
    let P := V.bp
    let L := outcLay V.pub 14
    let cs := outcCs (shdP_outcTA Rp w rnd) (shdP_outcTH Rp w rnd gamma alpha) TB
    let tb := Tab.priv ⟨.h, [((L.hOff p).1, Fp2.one), ((L.hOff p).2, Block.fp2U)],
      L.hLog.getD p 0, rhoC 0 (L.hLog.getD p 0), mr, 0⟩
    IndDegLE 1 (fun z : Fin 13 → shdP_K => stgTabK shdP_U shdP_hbij P cs 12 1 z tb)
    ∧ ∀ b : Fin 12 → Bool,
        stgTabK shdP_U shdP_hbij P cs 12 1 (fun i : Fin 13 => (bit (cptS 12 b i) : shdP_K)) tb
          = shdP_outcHValK Rp w gamma alpha ⟨p, hp8⟩ ⟨msbIndex 12 b, msbIndex_lt 12 b⟩ := by
  intro V P L cs tb
  have hlog : L.hLog.getD p 0 = 12 := shdP_outcLay_hLog Rp wDigest v p (by omega)
  have hoff : L.hOff p = (2 * p * 4096, (2 * p + 1) * 4096) := shdP_outcLay_hOff Rp wDigest v p (by omega)
  have hrowH : Block.rowLog P .h = 12 := outc_rowLog_h V rfl
  refine ⟨?_, fun b => ?_⟩
  · exact indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU P 38 12 0
      (tabMat 38 12 (shdP_outcTH Rp w rnd gamma alpha).rows) (N := 13) 12 1 rfl
      ⟨.h, [((L.hOff p).1, Fp2.one), ((L.hOff p).2, Block.fp2U)],
        L.hLog.getD p 0, rhoC 0 (L.hLog.getD p 0), mr, 0⟩
      (by simp) (by rw [hlog, hrowH]; norm_num)
      (by simpa using varsOKb_fixed_rho_fixed [] [] 0 (L.hLog.getD p 0)
            (fun _ h => by cases h) (fun _ h => by cases h))
      (fun c hc _ hw => by obtain ⟨_, _, h⟩ := List.mem_map.mp hc; rw [hw] at h; cases h)
  · change Link.claimSem shdP_U 38 12 0 (tabMat 38 12 (shdP_outcTH Rp w rnd gamma alpha).rows) _ = _
    rw [claimSem_priv_cube_y0 P 38 12 (tabMat 38 12 (shdP_outcTH Rp w rnd gamma alpha).rows) 12 rfl b _
      ((L.hOff p).1, Fp2.one) [((L.hOff p).2, Block.fp2U)] rfl (by rw [hlog, hrowH]; norm_num)
      (fun c hc _ hw => by obtain ⟨_, _, h⟩ := List.mem_map.mp hc; rw [hw] at h; cases h)]
    have hrhoLen : (rhoC 0 12).length = 12 := by simp [rhoC]
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
      hoff, hlog, hrhoLen]
    have hpt : ∀ a : Fin 12, Block.ptK shdP_U
        (Block.xrK 12 (fun i : Fin 13 => (bit (cptS 12 b i) : shdP_K)))
        (rhoC 0 12) a.val = (bit (b a) : shdP_K) := by
      intro a
      unfold Block.ptK
      simp only [rhoC, List.getElem?_map, List.getElem?_range' a.isLt, Option.map_some, Option.getD_some,
        Block.coordK, Nat.zero_add, one_mul]
      exact xrK_cptS (N := 13) 12 b a.val a.isLt (by norm_num)
    exact outc_h_plane_at Rp w rnd gamma alpha ⟨p, hp8⟩ b _ hpt

/-- Helper: `Fin 12 → Bool` sum reindexed via `msbIndex 12` to `Fin 4096`. -/
theorem sum_fin12_bool_eq {K : Type} [AddCommMonoid K] (f : Fin 4096 → K) :
    ∑ b : Fin 12 → Bool, f ⟨msbIndex 12 b, msbIndex_lt 12 b⟩ = ∑ col : Fin 4096, f col := by
  refine Finset.sum_bij (fun (b : Fin 12 → Bool) _ => (⟨msbIndex 12 b, msbIndex_lt 12 b⟩ : Fin 4096))
    (fun _ _ => Finset.mem_univ _)
    (fun b₁ _ b₂ _ h => by
      have hv : msbIndex 12 b₁ = msbIndex 12 b₂ := congrArg Fin.val h
      rw [← msbBits_msbIndex 12 b₁, ← msbBits_msbIndex 12 b₂, hv])
    (fun col _ => ⟨msbBits 12 col.val, Finset.mem_univ _,
      Fin.ext (msbIndex_msbBits 12 col.val (lt_of_lt_of_eq col.isLt (by norm_num)))⟩)
    (fun _ _ => rfl)

end StageOutSlotHelpers

/-! ## 2. Per-slot `IndDegLE` and `cubeSum` for all 8 slots `OUTC-00..07` -/

section StageOutSlotArith

variable (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hOut : Rp.out.Valid) (wDigest : Dig) (bOutRow : ℕ)
  {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (TB : Table) (hTB : BndTableSpec w.y25 Rp.row TB) (rnd : OutcRand)

include hTB in
/-- Slot 0 (`OUTC-00 IO-in`): `IndDegLE 2`, `cubeSum = 0`, `df.hosted = []`. -/
theorem outc_slot0_arith (gamma alpha : Fp2) (dr : List Fp2) (hdrCan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : outcDefIO (rcVerdict (shdP_outcPub Rp wDigest) w.v) (shdP_outcGeo bOutRow) dr = .ok df) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let P := V.bp
    let cs := outcCs (shdP_outcTA Rp w rnd) (shdP_outcTH Rp w rnd gamma alpha) TB
    IndDegLE 2 (slotPolyK P (fun _ => 14) cs 0 df)
      ∧ cubeSum (slotPolyK P (fun _ => 14) cs 0 df) = 0
      ∧ df.hosted = []
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P cs
  let O := V.pub; let L := outcLay O 14
  have hGb : V.geo.bLogN = 14 := rfl
  have hGbRow : V.geo.bOutRow = bOutRow := rfl
  have hdef' : outcDefIO V.pub V.geo dr = .ok df := hdef
  have hok := outcDefIO_ok V.pub V.geo dr
  dsimp only at hok; rw [hok] at hdef'
  have hdf := (Except.ok.inj hdef').symm
  have hdBits : O.dBits = 12 := (shdP_outcPub_logs Rp wDigest).2.2.2
  have hldo : O.ldo = 12 := (shdP_outcPub_logs Rp wDigest).2.1
  have hlift : O.lift = 0 := by unfold OutcPub.lift; omega
  have htBits : O.tBits = 7 := by unfold OutcPub.tBits; exact shdP_clog2_128
  have hbOutLog : O.bOutLog = 19 := by
    show Nat.log2 (128 * 4096) = 19
    rw [show (128 * 4096 : ℕ) = 2 ^ 19 by norm_num, Nat.log2_two_pow]
  have hsh0 : Exec.Block.slotShape P 0 = (12, 1, 2) := shdP_outc_slotShape tag Rp wDigest bOutRow w.v 0
  have hN0 : slotN P 0 = 13 := by unfold slotN; rw [hsh0]; rfl
  have hXlog : L.aLog.getD ocC_X 0 = 12 :=
    (shdP_outcLay_aLog Rp wDigest w.v ocC_X (by norm_num [ocC_X])).trans (ite_eq_right (by norm_num [ocC_X]))
  let tabs := [
    Tab.eq (dr.take O.dBits) 0,
    Tab.priv ⟨.a, [(L.aOff ocC_X, Fp2.one)], L.aLog.getD ocC_X 0,
      fixedC (List.replicate O.lift Fp2.zero) ++ rhoC 0 O.dBits,
      L.aMaskBase + 2 * (L.prefixA 0 + 0), 0⟩,
    Tab.priv ⟨.inp, [(0, Fp2.one)], O.bOutLog,
      fixedBits O.verdictRow O.tBits ++ rhoC 0 O.dBits, bOutRow, 0⟩]
  have htabs : df.tabs = tabs := by rw [hdf]; dsimp only [tabs, L, O]; rw [hGb, hGbRow]
  have hpolyEq : df.poly = ioPoly := by rw [hdf]
  have hfit : tabsFit 12 tabs := by
    intro t ht; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl
    · show 0 + (dr.take O.dBits).length ≤ 12; rw [hdBits, Nat.zero_add]; exact List.length_take_le _ _
    · trivial
    · trivial
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st he a ha; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl
    · cases he; exact hdrCan a (List.mem_of_mem_take ha)
    · cases he
    · cases he
  let g : ℕ → (Fin 13 → shdP_K) → shdP_K := fun j z =>
    (tabs.map (stgTabK shdP_U shdP_hbij P cs 12 1 z)).getD j 0
  have hpoly : ∀ z : Fin (slotN P 0) → shdP_K,
      slotPolyK P (fun _ => 14) cs 0 df z
        = g 0 (fun i => z (Fin.cast hN0.symm i)) * (g 1 (fun i => z (Fin.cast hN0.symm i)) - g 2 (fun i => z (Fin.cast hN0.symm i))) := by
    intro z
    unfold slotPolyK
    have hatP : atLog P 14 = P := shdVo_atLog_14 tag Rp wDigest bOutRow w.v
    have hsh1 : (Exec.Block.slotShape P 0).1 = 12 := by rw [hsh0]
    dsimp only; rw [hatP, hsh1, htabs]
    obtain ⟨vals, htv, hvcan, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU P cs 12 1 hN0 z tabs hfit hcan
    rw [htv]; dsimp only; rw [hpolyEq]
    have hvg : ∀ i, (vg vals i).toK shdP_U = g i (fun j => z (Fin.cast hN0.symm j)) := fun i => by
      rw [vg_toK_map, hvmap]
      simp only [g, List.getD_eq_getElem?_getD, List.getElem?_map]
      cases h : tabs[i]? with
      | none => rfl
      | some tb =>
        simp only [Option.map_some, Option.getD_some]
        exact stgTabK_cast hN0 z tb
    unfold ioPoly
    rw [Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_sub shdP_U _ _ (vg_canon hvcan 1) (vg_canon hvcan 2),
      hvg 0, hvg 1, hvg 2]
  have hg0 : IndDegLE 1 (g 0) :=
    indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl (stgTabK_eq_indDeg _ _)
  have hg1_spec := outc_tabA12_spec tag Rp wDigest bOutRow w.v w TB rnd gamma alpha ocC_X
    (L.aMaskBase + 2 * (L.prefixA 0 + 0)) (by norm_num [ocC_X]) (by norm_num [ocC_X])
  have hg1_eq : g 1 = fun z => stgTabK shdP_U shdP_hbij P cs 12 1 z
      (.priv ⟨.a, [(L.aOff ocC_X, Fp2.one)], L.aLog.getD ocC_X 0, rhoC 0 (L.aLog.getD ocC_X 0),
        L.aMaskBase + 2 * (L.prefixA 0 + 0), 0⟩) := by
    funext z
    dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl]
    simp only [hlift, hdBits, hXlog, List.replicate_zero, fixedC, List.map_nil, List.nil_append]
  have hg1 : IndDegLE 1 (g 1) := by rw [hg1_eq]; exact hg1_spec.1
  have hg2 : IndDegLE 1 (g 2) :=
    indDegLE_map_getD_priv tabs 2 _ rfl 38 14 0 (tabMat 38 14 TB.rows) (fun _ => rfl) rfl
      (by simp) (by rw [hbOutLog, outc_rowLog_inp V rfl]; norm_num)
      (by simpa using varsOKb_fixed_rho_fixed (fixedBits O.verdictRow O.tBits) [] 0 O.dBits
            (fun _ hc => coordVar_fixedBits hc) (fun _ h => by cases h))
      (fun c hc _ hw => by
        rcases List.mem_append.mp hc with h1 | h2
        · obtain ⟨_, _, hcb⟩ := List.mem_map.mp h1
          rw [hw] at hcb; injection hcb with hcb; rw [← hcb]
          split_ifs <;> [exact Fp2.canon_one; exact Fp2.canon_zero]
        · obtain ⟨_, _, h⟩ := List.mem_map.mp h2; rw [hw] at h; cases h)
  have hdeg13 : IndDegLE 2 (fun z : Fin 13 → shdP_K => g 0 z * (g 1 z - g 2 z)) :=
    IndDegLE.mul hg0 (IndDegLE.sub hg1 hg2)
  refine ⟨?_, ?_, by rw [hdf], fun vals => by rw [hdf]; exact Fp2.canon_mul _ _⟩
  · rw [funext hpoly]; exact indDegLE_cast hN0 (fun z : Fin 13 → shdP_K => g 0 z * (g 1 z - g 2 z)) hdeg13
  · rw [funext hpoly, cubeSum_cast hN0 (fun z : Fin 13 → shdP_K => g 0 z * (g 1 z - g 2 z))]
    rw [cubeSum_split_ext 12 _ (fun bv hbv => by
      have hs := selK_ext_true 12 bv hbv
      have h0 : g 0 (fun i => (bit (bv i) : shdP_K)) = 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl]
        exact stgTabK_eq_zero_of_selK hs _ _
      rw [h0, zero_mul])]
    refine Finset.sum_eq_zero (fun b _ => ?_)
    have h1 : g 1 (fun i => (bit (cptS 12 b i) : shdP_K))
        = if hc : msbIndex 12 b < 3072 then
            algebraMap GF shdP_K (Fp.fromI64 (w.y25 (Rp.row, ⟨msbIndex 12 b, hc⟩))).toGF
          else 0 := by
      rw [hg1_eq]; refine (hg1_spec.2 b).trans ?_
      dsimp only [ocC_X]; rw [shdP_outcTAData_3]
      by_cases hc : msbIndex 12 b < 3072
      · rw [dite_eq_left hc, dite_eq_left hc]
      · rw [dite_eq_right hc, dite_eq_right hc, fp_zero_toGF, map_zero]
    have h2 : g 2 (fun i => (bit (cptS 12 b i) : shdP_K))
        = if hc : msbIndex 12 b < 3072 then
            algebraMap GF shdP_K (Fp.fromI64 (w.y25 (Rp.row, ⟨msbIndex 12 b, hc⟩))).toGF
          else 0 := by
      let p2 : Block.Priv := ⟨.inp, [(0, Fp2.one)], O.bOutLog,
        fixedBits O.verdictRow O.tBits ++ rhoC 0 O.dBits, bOutRow, 0⟩
      dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 2 (.priv p2) rfl]
      have h0 := claimSem_priv_cube_y0 P 38 14 (tabMat 38 14 TB.rows) 12 rfl b p2
        (0, Fp2.one) [] rfl (by dsimp only [p2]; rw [hbOutLog, outc_rowLog_inp V rfl]; norm_num)
        (fun c hc _ hw => by
          rcases List.mem_append.mp hc with h1 | h2
          · obtain ⟨_, _, hcb⟩ := List.mem_map.mp h1
            rw [hw] at hcb; injection hcb with hcb; rw [← hcb]
            split_ifs <;> [exact Fp2.canon_one; exact Fp2.canon_zero]
          · obtain ⟨_, _, h⟩ := List.mem_map.mp h2; rw [hw] at h; cases h)
      refine h0.trans ?_
      have hlen19 : (fixedBits O.verdictRow 7 ++ rhoC 0 12).length = 19 := by
        simp [fixedBits, rhoC]
      simp only [p2, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, Fp2.toK_one, one_mul,
        hbOutLog, htBits, hdBits, hlen19]
      exact shdP_outcTB_verdictRow_at Rp hTB b _
        (fun a => by
          unfold Block.ptK
          rw [List.getElem?_append_left (by simp [fixedBits, a.isLt])]
          simp only [fixedBits, List.getElem?_map, List.getElem?_range a.isLt, Option.map_some, Option.getD_some,
            Block.coordK]
          show (if (Rp.row.val / 2 ^ (7 - 1 - a.val)) % 2 = 1 then Fp2.one else Fp2.zero).toK shdP_U = _
          unfold msbBits
          by_cases hb : (Rp.row.val / 2 ^ (7 - 1 - a.val)) % 2 = 1
          · rw [ite_eq_left hb, decide_eq_true hb, Fp2.toK_one]; rfl
          · rw [ite_eq_right hb, decide_eq_false hb, Fp2.toK_zero]; rfl)
        (fun a => by
          unfold Block.ptK
          rw [List.getElem?_append_right (by simp [fixedBits])]
          simp only [fixedBits, rhoC, List.length_map, List.length_range, Nat.add_sub_cancel_left,
            List.getElem?_map, List.getElem?_range' a.isLt, Option.map_some, Option.getD_some,
            Block.coordK, Nat.zero_add, one_mul]
          exact xrK_cptS (N := 13) 12 b a.val a.isLt (by norm_num))
    rw [h1, h2, sub_self, mul_zero]

/-- Slot 1 (`OUTC-01 SS`, `.priv`): `IndDegLE 4`, `cubeSum = outcPrivSum Rp w 1`, `df.hosted = []`. -/
theorem outc_slot1_arith (gamma alpha : Fp2)
    (df : SlotDef) (hdef : outcDefSS (rcVerdict (shdP_outcPub Rp wDigest) w.v) (shdP_outcGeo bOutRow) = .ok df) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let P := V.bp
    let cs := outcCs (shdP_outcTA Rp w rnd) (shdP_outcTH Rp w rnd gamma alpha) TB
    IndDegLE 4 (slotPolyK P (fun _ => 14) cs 1 df)
      ∧ cubeSum (slotPolyK P (fun _ => 14) cs 1 df) = outcPrivSum Rp w 1
      ∧ df.hosted = []
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P cs
  let O := V.pub; let L := outcLay O 14
  have hGb : V.geo.bLogN = 14 := rfl
  have hdef' : outcDefSS V.pub V.geo = .ok df := hdef
  have hok := outcDefSS_ok V.pub V.geo
  dsimp only at hok; rw [hok] at hdef'
  have hdf := (Except.ok.inj hdef').symm
  have hldo : O.ldo = 12 := (shdP_outcPub_logs Rp wDigest).2.1
  have hsh1 : Exec.Block.slotShape P 1 = (12, 1, 4) := shdP_outc_slotShape tag Rp wDigest bOutRow w.v 1
  have hN1 : slotN P 1 = 13 := by unfold slotN; rw [hsh1]; rfl
  let tabs := [
    Tab.pub (supp O.d (2 ^ O.ldo)),
    Tab.priv ⟨.a, [(L.aOff ocC_X, Fp2.one)], L.aLog.getD ocC_X 0,
      rhoC 0 (L.aLog.getD ocC_X 0), L.aMaskBase + 2 * (L.prefixA 1 + 0), 0⟩]
  have htabs : df.tabs = tabs := by rw [hdf]; dsimp only [tabs, L, O]; rw [hGb]
  have hpolyEq : df.poly = ssPoly := by rw [hdf]
  have hfit : tabsFit 12 tabs := by
    intro t ht; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl
    · show (supp O.d (2 ^ O.ldo)).length = 2 ^ 12; simp only [supp, List.length_map, List.length_range, hldo]
    · trivial
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st he; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl <;> cases he
  let g : ℕ → (Fin 13 → shdP_K) → shdP_K := fun j z =>
    (tabs.map (stgTabK shdP_U shdP_hbij P cs 12 1 z)).getD j 0
  have hpoly : ∀ z : Fin (slotN P 1) → shdP_K,
      slotPolyK P (fun _ => 14) cs 1 df z
        = (g 0 (fun i => z (Fin.cast hN1.symm i)) * g 1 (fun i => z (Fin.cast hN1.symm i))) * g 1 (fun i => z (Fin.cast hN1.symm i)) := by
    intro z
    unfold slotPolyK
    have hatP : atLog P 14 = P := shdVo_atLog_14 tag Rp wDigest bOutRow w.v
    have hs : (Exec.Block.slotShape P 1).1 = 12 := by rw [hsh1]
    dsimp only; rw [hatP, hs, htabs]
    obtain ⟨vals, htv, _, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU P cs 12 1 hN1 z tabs hfit hcan
    rw [htv]; dsimp only; rw [hpolyEq]
    have hvg : ∀ i, (vg vals i).toK shdP_U = g i (fun j => z (Fin.cast hN1.symm j)) := fun i => by
      rw [vg_toK_map, hvmap]
      simp only [g, List.getD_eq_getElem?_getD, List.getElem?_map]
      cases h : tabs[i]? with
      | none => rfl
      | some tb => simp only [Option.map_some, Option.getD_some]; exact stgTabK_cast hN1 z tb
    unfold ssPoly
    rw [Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU, hvg 0, hvg 1]
  have hg0 : IndDegLE 1 (g 0) :=
    indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl (stgTabK_pub_indDeg _)
  have hg1_spec := outc_tabA12_spec tag Rp wDigest bOutRow w.v w TB rnd gamma alpha ocC_X
    (L.aMaskBase + 2 * (L.prefixA 1 + 0)) (by norm_num [ocC_X]) (by norm_num [ocC_X])
  have hg1 : IndDegLE 1 (g 1) :=
    indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl hg1_spec.1
  have hdeg13 : IndDegLE 4 (fun z : Fin 13 → shdP_K => (g 0 z * g 1 z) * g 1 z) :=
    IndDegLE.mono (IndDegLE.mul (IndDegLE.mul hg0 hg1) hg1) (by norm_num)
  refine ⟨?_, ?_, by rw [hdf], fun vals => by rw [hdf]; exact Fp2.canon_mul _ _⟩
  · rw [funext hpoly]; exact indDegLE_cast hN1 (fun z : Fin 13 → shdP_K => (g 0 z * g 1 z) * g 1 z) hdeg13
  · rw [funext hpoly, cubeSum_cast hN1 (fun z : Fin 13 → shdP_K => (g 0 z * g 1 z) * g 1 z)]
    rw [cubeSum_split_ext 12 _ (fun bv hbv => by
      have hs := selK_ext_true 12 bv hbv
      have h0 : g 0 (fun i => (bit (bv i) : shdP_K)) = 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl]
        exact stgTabK_pub_zero_of_selK hs _
      rw [h0, zero_mul, zero_mul])]
    have hpt : ∀ b : Fin 12 → Bool,
        (g 0 (fun i => (bit (cptS 12 b i) : shdP_K)) * g 1 (fun i => (bit (cptS 12 b i) : shdP_K)))
          * g 1 (fun i => (bit (cptS 12 b i) : shdP_K))
        = if hc : msbIndex 12 b < 3072 then
            (w.y25 (Rp.row, ⟨msbIndex 12 b, hc⟩) : shdP_K) * (w.y25 (Rp.row, ⟨msbIndex 12 b, hc⟩) : shdP_K)
          else 0 := by
      intro b
      have h0 : g 0 (fun i => (bit (cptS 12 b i) : shdP_K))
          = if msbIndex 12 b < 3072 then 1 else 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl]
        rw [HonestShield.stgTabK_pub_cptS _ (by simp only [supp, List.length_map, List.length_range, hldo]) b]
        rw [show O.d = 3072 from rfl, hldo, show (2 : ℕ) ^ 12 = 4096 by norm_num]
        exact supp_getD_toK shdP_U 3072 4096 (msbIndex 12 b) (msbIndex_lt 12 b)
      have h1 : g 1 (fun i => (bit (cptS 12 b i) : shdP_K))
          = if hc : msbIndex 12 b < 3072 then (w.y25 (Rp.row, ⟨msbIndex 12 b, hc⟩) : shdP_K) else 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl]
        refine (hg1_spec.2 b).trans ?_
        dsimp only [ocC_X]; rw [shdP_outcTAData_3]
        by_cases hc : msbIndex 12 b < 3072
        · rw [dite_eq_left hc, dite_eq_left hc]
          have hxr := w.hxRow ⟨msbIndex 12 b, hc⟩
          have hlo : -(2 : ℤ) ^ 64 < w.y25 (Rp.row, ⟨msbIndex 12 b, hc⟩) := by
            have h1 : -(2 : ℤ) ^ 15 ≤ w.y25 (Rp.row, ⟨msbIndex 12 b, hc⟩) := hxr.1; omega
          have hhi : w.y25 (Rp.row, ⟨msbIndex 12 b, hc⟩) < (2 : ℤ) ^ 64 := by
            have h2 : w.y25 (Rp.row, ⟨msbIndex 12 b, hc⟩) ≤ (2 : ℤ) ^ 15 - 1 := hxr.2; omega
          exact fp_fromI64_toK _ hlo hhi
        · rw [dite_eq_right hc, dite_eq_right hc, fp_zero_toGF, map_zero]
      by_cases hc : msbIndex 12 b < 3072
      · rw [h0, h1, ite_eq_left hc, dite_eq_left hc, dite_eq_left hc, one_mul]
      · rw [h0, h1, ite_eq_right hc, dite_eq_right hc, dite_eq_right hc, zero_mul, zero_mul]
    rw [Finset.sum_congr rfl (fun b _ => hpt b)]
    rw [sum_fin12_bool_eq (fun col : Fin 4096 => if hc : col.val < 3072 then
      (w.y25 (Rp.row, ⟨col.val, hc⟩) : shdP_K) * (w.y25 (Rp.row, ⟨col.val, hc⟩) : shdP_K) else 0)]
    rw [← Finset.sum_filter_add_sum_filter_not Finset.univ (fun col : Fin 4096 => col.val < 3072)]
    have hzero : ∑ col ∈ Finset.univ.filter (fun col : Fin 4096 => ¬ col.val < 3072),
        (if hc : col.val < 3072 then (w.y25 (Rp.row, ⟨col.val, hc⟩) : shdP_K) * (w.y25 (Rp.row, ⟨col.val, hc⟩) : shdP_K) else 0) = 0 :=
      Finset.sum_eq_zero (fun col hcol => dite_eq_right (Finset.mem_filter.mp hcol).2)
    rw [hzero, add_zero]
    unfold outcPrivSum
    refine Finset.sum_bij (fun (col : Fin 4096) (hcol : col ∈ Finset.univ.filter _) =>
        (⟨col.val, (Finset.mem_filter.mp hcol).2⟩ : Fin 3072))
      (fun _ _ => Finset.mem_univ _)
      (fun a _ b _ h => Fin.ext (congrArg (Fin.val : Fin 3072 → ℕ) h))
      (fun i _ => ⟨⟨i.val, by have := i.isLt; omega⟩, Finset.mem_filter.mpr ⟨Finset.mem_univ _, i.isLt⟩, Fin.ext rfl⟩)
      (fun col hcol => dite_eq_left (Finset.mem_filter.mp hcol).2)

include hOut in
/-- Slot 2 (`OUTC-02 TZC`, `.host` of slot 1): `IndDegLE 3`, `cubeSum = ν * outcPrivSum Rp w 1`,
`df.hosted = [(1, dr.getD 5 Fp2.zero)]`. -/
theorem outc_slot2_arith (gamma alpha : Fp2) (dr : List Fp2) (hlen : dr.length = 7) (hdrCan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : outcDefTZC (rcVerdict (shdP_outcPub Rp wDigest) w.v) (shdP_outcGeo bOutRow) dr = .ok df) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let P := V.bp
    let cs := outcCs (shdP_outcTA Rp w rnd) (shdP_outcTH Rp w rnd gamma alpha) TB
    IndDegLE 3 (slotPolyK P (fun _ => 14) cs 2 df)
      ∧ cubeSum (slotPolyK P (fun _ => 14) cs 2 df) = (dr.getD 5 Fp2.zero).toK shdP_U * outcPrivSum Rp w 1
      ∧ df.hosted = [(1, dr.getD 5 Fp2.zero)]
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P cs
  have hdf := outcDefTZC_eq_of_ok V.pub V.geo dr hlen hdrCan df hdef
  dsimp only at hdf
  let O := V.pub; let L := outcLay O 14
  have hGb : V.geo.bLogN = 14 := rfl
  let mu := (dr.drop 1).take 4
  let nu := dr.getD 5 Fp2.zero
  let zeta := dr.getD 6 Fp2.zero
  have hsh2 : Exec.Block.slotShape P 2 = (1, 1, 3) := shdP_outc_slotShape tag Rp wDigest bOutRow w.v 2
  have hN2 : slotN P 2 = 2 := by unfold slotN; rw [hsh2]; rfl
  have hDlog : L.aLog.getD ocC_D 0 = 1 :=
    (shdP_outcLay_aLog Rp wDigest w.v ocC_D (by norm_num [ocC_D])).trans (ite_eq_left (by norm_num [ocC_D]))
  have hDsqlog : L.aLog.getD ocC_DSQ 0 = 1 :=
    (shdP_outcLay_aLog Rp wDigest w.v ocC_DSQ (by norm_num [ocC_DSQ])).trans (ite_eq_left (by norm_num [ocC_DSQ]))
  have hDoff : L.aOff ocC_D = 0 * 4096 := shdP_outcLay_aOff Rp wDigest w.v ocC_D (by norm_num [ocC_D])
  have hDsqoff : L.aOff ocC_DSQ = 1 * 4096 := shdP_outcLay_aOff Rp wDigest w.v ocC_DSQ (by norm_num [ocC_DSQ])
  have hLoff : L.aOff ocC_LIMB = 2 * 4096 := shdP_outcLay_aOff Rp wDigest w.v ocC_LIMB (by norm_num [ocC_LIMB])
  let tabs : List Tab :=
    .eq (dr.take OutcPub.toLog) 0 :: (
      [.pub (supp 1 (2 ^ OutcPub.toLog)),
       .priv ⟨.a, [(L.aOff ocC_D, Fp2.one)], L.aLog.getD ocC_D 0,
         rhoC 0 (L.aLog.getD ocC_D 0), L.aMaskBase + 2 * (L.prefixA 2 + 0), 0⟩,
       .priv ⟨.a, [(L.aOff ocC_DSQ, Fp2.one)], L.aLog.getD ocC_DSQ 0,
         rhoC 0 (L.aLog.getD ocC_DSQ 0), L.aMaskBase + 2 * (L.prefixA 2 + 1), 0⟩]
      ++ ((List.range (3 * OutcPub.limbsIsqrt)).zipIdx 2).map (fun p =>
        Block.Tab.priv ⟨.a, [(L.aOff ocC_LIMB + 2 * p.1, Fp2.one)], OutcPub.toLog,
          rhoC 0 OutcPub.toLog, L.aMaskBase + 2 * (L.prefixA 2 + p.2), 0⟩))
  have htabs : df.tabs = tabs := by rw [hdf]; dsimp only [tabs, L, O]; rw [hGb]
  have hpolyEq : df.poly = tzcPoly mu nu zeta (kI O.ceps) := by rw [hdf]
  have htabs_limb : ∀ (kk : ℕ) (hkk : kk < 9),
      tabs[4 + kk]? = some (.priv ⟨.a, [(L.aOff ocC_LIMB + 2 * kk, Fp2.one)], 1,
        rhoC 0 1, L.aMaskBase + 2 * (L.prefixA 2 + (2 + kk)), 0⟩) := by
    intro kk hkk
    interval_cases kk <;> rfl
  have hfit : tabsFit 1 tabs := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · show 0 + (dr.take 1).length ≤ 1; rw [Nat.zero_add]; exact List.length_take_le _ _
    · rcases List.mem_append.mp ht with ht1 | ht2
      · rcases List.mem_cons.mp ht1 with rfl | ht1
        · show (supp 1 2).length = 2; simp only [supp, List.length_map, List.length_range]
        · rcases List.mem_cons.mp ht1 with rfl | ht1
          · trivial
          · rcases List.mem_cons.mp ht1 with rfl | ht1
            · trivial
            · cases ht1
      · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht2; trivial
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st he a ha
    rcases List.mem_cons.mp ht with rfl | ht
    · cases he; exact hdrCan a (List.mem_of_mem_take ha)
    · rcases List.mem_append.mp ht with ht1 | ht2
      · rcases List.mem_cons.mp ht1 with rfl | ht1; · cases he
        rcases List.mem_cons.mp ht1 with rfl | ht1; · cases he
        rcases List.mem_cons.mp ht1 with rfl | ht1; · cases he
        cases ht1
      · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht2; cases he
  let g : ℕ → (Fin 2 → shdP_K) → shdP_K := fun j z =>
    (tabs.map (stgTabK shdP_U shdP_hbij P cs 1 1 z)).getD j 0
  have hpoly : ∀ z : Fin (slotN P 2) → shdP_K,
      slotPolyK P (fun _ => 14) cs 2 df z
        = let gz := fun i => g i (fun j => z (Fin.cast hN2.symm j))
          let dl := l3K gz 4; let a1 := l3K gz 7; let a2 := l3K gz 10
          let pad := (1 - gz 1) * (gz 2 + zeta.toK shdP_U * gz 3)
          let zc := ((((vg mu 0).toK shdP_U * (gz 3 - gz 2 * gz 2))
            + ((vg mu 1).toK shdP_U * (gz 2 - dl)))
            + ((vg mu 2).toK shdP_U * (((gz 2 + gz 2) - a1) - a2)))
            + ((vg mu 3).toK shdP_U * pad)
          (gz 0 * zc) + ((nu.toK shdP_U * gz 1) * ((gz 3 + a1) - (kI O.ceps).toK shdP_U)) := by
    intro z
    unfold slotPolyK
    have hatP : atLog P 14 = P := shdVo_atLog_14 tag Rp wDigest bOutRow w.v
    have hs : (Exec.Block.slotShape P 2).1 = 1 := by rw [hsh2]
    dsimp only; rw [hatP, hs, htabs]
    obtain ⟨vals, htv, hvcan, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU P cs 1 1 hN2 z tabs hfit hcan
    rw [htv]; dsimp only; rw [hpolyEq]
    have hvg : ∀ i, (vg vals i).toK shdP_U = g i (fun j => z (Fin.cast hN2.symm j)) := fun i => by
      rw [vg_toK_map, hvmap]
      simp only [g, List.getD_eq_getElem?_getD, List.getElem?_map]
      cases h : tabs[i]? with
      | none => rfl
      | some tb => simp only [Option.map_some, Option.getD_some]; exact stgTabK_cast hN2 z tb
    unfold tzcPoly
    rw [Fp2.toK_add shdP_U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
        Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
        Fp2.toK_add shdP_U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
        Fp2.toK_add shdP_U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
        Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_sub shdP_U _ _ (vg_canon hvcan 3) (Fp2.canon_mul _ _), Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_sub shdP_U _ _ (vg_canon hvcan 2) (l3W_canon _ _),
        Fp2.toK_sub shdP_U _ _ (Fp2.canon_sub _ _ (Fp2.canon_add _ _) (l3W_canon _ _)) (l3W_canon _ _),
        Fp2.toK_sub shdP_U _ _ (Fp2.canon_add _ _) (l3W_canon _ _),
        Fp2.toK_add shdP_U _ _ (vg_canon hvcan 2) (vg_canon hvcan 2),
        Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_sub shdP_U _ _ Fp2.canon_one (vg_canon hvcan 1), Fp2.toK_one,
        Fp2.toK_add shdP_U _ _ (vg_canon hvcan 2) (Fp2.canon_mul _ _), Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_sub shdP_U _ _ (Fp2.canon_add _ _) (kI_canon _),
        Fp2.toK_add shdP_U _ _ (vg_canon hvcan 3) (l3W_canon _ _),
        l3W_toK shdP_U vals hvcan 4, l3W_toK shdP_U vals hvcan 7, l3W_toK shdP_U vals hvcan 10]
    have hmapFn : (fun idx => (vals.map (Fp2.toK shdP_U)).getD idx 0)
        = fun i => g i (fun j => z (Fin.cast hN2.symm j)) :=
      funext (fun i => by rw [← vg_toK_map, hvg i])
    rw [hmapFn, hvg 0, hvg 1, hvg 2, hvg 3]
  -- Helper: every `g idx` has `IndDegLE 1`
  have hg_deg : ∀ idx, IndDegLE 1 (g idx) := by
    intro idx
    have hlen_tabs : tabs.length = 13 := by
      simp [tabs, OutcPub.limbsIsqrt]
    by_cases hlt : idx < 13
    · have hprivA : ∀ (off mr : ℕ), IndDegLE 1 (fun z : Fin 2 → shdP_K =>
          stgTabK shdP_U shdP_hbij P cs 1 1 z
            (.priv ⟨.a, [(off, Fp2.one)], 1, rhoC 0 1, mr, 0⟩)) := fun off mr =>
        indDegLE_claimSem_priv shdP_U shdP_hbij shdP_hU P 76 12 0
          (tabMat 76 12 (shdP_outcTA Rp w rnd).rows) (N := 2) 1 1 rfl
          ⟨.a, [(off, Fp2.one)], 1, rhoC 0 1, mr, 0⟩
          (by simp) (by rw [outc_rowLog_a V rfl]; norm_num)
          (by simpa using varsOKb_fixed_rho_fixed [] [] 0 1 (fun _ h => by cases h) (fun _ h => by cases h))
          (fun c hc _ hw => by obtain ⟨_, _, h⟩ := List.mem_map.mp hc; rw [hw] at h; cases h)
      by_cases h0 : idx = 0
      · subst h0
        exact indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 1 1) 0 _ rfl (stgTabK_eq_indDeg _ _)
      · by_cases h1 : idx = 1
        · subst h1
          exact indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 1 1) 1 _ rfl (stgTabK_pub_indDeg _)
        · by_cases h2 : idx = 2
          · subst h2
            refine indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 1 1) 2 _ rfl ?_
            rw [hDlog]; exact hprivA (L.aOff ocC_D) (L.aMaskBase + 2 * (L.prefixA 2 + 0))
          · by_cases h3 : idx = 3
            · subst h3
              refine indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 1 1) 3 _ rfl ?_
              rw [hDsqlog]; exact hprivA (L.aOff ocC_DSQ) (L.aMaskBase + 2 * (L.prefixA 2 + 1))
            · have hk := htabs_limb (idx - 4) (by omega)
              rw [show 4 + (idx - 4) = idx by omega] at hk
              exact indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 1 1) idx _ hk
                (hprivA (L.aOff ocC_LIMB + 2 * (idx - 4)) (L.aMaskBase + 2 * (L.prefixA 2 + (2 + (idx - 4)))))
    · have hzero : g idx = fun _ => 0 := by
        funext z
        dsimp only [g]
        rw [List.getD_eq_getElem?_getD,
          List.getElem?_eq_none (l := tabs.map (stgTabK shdP_U shdP_hbij P cs 1 1 z))
            (by rw [List.length_map, hlen_tabs]; omega)]
        rfl
      rw [hzero]; exact IndDegLE.const 0
  have hdeg2 : IndDegLE 3 (fun z : Fin 2 → shdP_K =>
      let gz := fun i => g i z
      let dl := l3K gz 4; let a1 := l3K gz 7; let a2 := l3K gz 10
      let pad := (1 - gz 1) * (gz 2 + zeta.toK shdP_U * gz 3)
      let zc := ((((vg mu 0).toK shdP_U * (gz 3 - gz 2 * gz 2))
        + ((vg mu 1).toK shdP_U * (gz 2 - dl)))
        + ((vg mu 2).toK shdP_U * (((gz 2 + gz 2) - a1) - a2)))
        + ((vg mu 3).toK shdP_U * pad)
      (gz 0 * zc) + ((nu.toK shdP_U * gz 1) * ((gz 3 + a1) - (kI O.ceps).toK shdP_U))) := by
    have hdl := indDegLE_l3K g hg_deg 4
    have ha1 := indDegLE_l3K g hg_deg 7
    have ha2 := indDegLE_l3K g hg_deg 10
    have hc0 : IndDegLE 2 (fun z => g 3 z - g 2 z * g 2 z) :=
      IndDegLE.sub (IndDegLE.mono (hg_deg 3) (by norm_num)) (IndDegLE.mul (hg_deg 2) (hg_deg 2))
    have hc1 : IndDegLE 2 (fun z => g 2 z - l3K (fun i => g i z) 4) :=
      IndDegLE.mono (IndDegLE.sub (hg_deg 2) hdl) (by norm_num)
    have hc2 : IndDegLE 2 (fun z => ((g 2 z + g 2 z) - l3K (fun i => g i z) 7) - l3K (fun i => g i z) 10) :=
      IndDegLE.mono (IndDegLE.sub (IndDegLE.sub (IndDegLE.add (hg_deg 2) (hg_deg 2)) ha1) ha2) (by norm_num)
    have hpad : IndDegLE 2 (fun z => (1 - g 1 z) * (g 2 z + zeta.toK shdP_U * g 3 z)) :=
      IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg_deg 1))
        (IndDegLE.add (hg_deg 2) (IndDegLE.cmul _ (hg_deg 3)))
    have hzc : IndDegLE 2 (fun z =>
        ((((vg mu 0).toK shdP_U * (g 3 z - g 2 z * g 2 z))
          + ((vg mu 1).toK shdP_U * (g 2 z - l3K (fun i => g i z) 4)))
          + ((vg mu 2).toK shdP_U * (((g 2 z + g 2 z) - l3K (fun i => g i z) 7) - l3K (fun i => g i z) 10)))
          + ((vg mu 3).toK shdP_U * ((1 - g 1 z) * (g 2 z + zeta.toK shdP_U * g 3 z)))) :=
      IndDegLE.add (IndDegLE.add (IndDegLE.add
        (IndDegLE.cmul _ hc0) (IndDegLE.cmul _ hc1)) (IndDegLE.cmul _ hc2)) (IndDegLE.cmul _ hpad)
    have hhost : IndDegLE 2 (fun z => (nu.toK shdP_U * g 1 z) * ((g 3 z + l3K (fun i => g i z) 7) - (kI O.ceps).toK shdP_U)) :=
      IndDegLE.mul (IndDegLE.cmul _ (hg_deg 1)) (IndDegLE.sub (IndDegLE.add (hg_deg 3) ha1) (IndDegLE.const _))
    exact IndDegLE.add (IndDegLE.mul (hg_deg 0) hzc) (IndDegLE.mono hhost (by norm_num))
  refine ⟨?_, ?_, by rw [hdf], fun vals => by rw [hdf]; exact Fp2.canon_add _ _⟩
  · rw [funext hpoly]
    exact indDegLE_cast hN2 (fun z : Fin 2 → shdP_K =>
      let gz := fun i => g i z
      let dl := l3K gz 4; let a1 := l3K gz 7; let a2 := l3K gz 10
      let pad := (1 - gz 1) * (gz 2 + zeta.toK shdP_U * gz 3)
      let zc := ((((vg mu 0).toK shdP_U * (gz 3 - gz 2 * gz 2))
        + ((vg mu 1).toK shdP_U * (gz 2 - dl)))
        + ((vg mu 2).toK shdP_U * (((gz 2 + gz 2) - a1) - a2)))
        + ((vg mu 3).toK shdP_U * pad)
      (gz 0 * zc) + ((nu.toK shdP_U * gz 1) * ((gz 3 + a1) - (kI O.ceps).toK shdP_U))) hdeg2
  · rw [funext hpoly, cubeSum_cast hN2 (fun z : Fin 2 → shdP_K =>
      let gz := fun i => g i z
      let dl := l3K gz 4; let a1 := l3K gz 7; let a2 := l3K gz 10
      let pad := (1 - gz 1) * (gz 2 + zeta.toK shdP_U * gz 3)
      let zc := ((((vg mu 0).toK shdP_U * (gz 3 - gz 2 * gz 2))
        + ((vg mu 1).toK shdP_U * (gz 2 - dl)))
        + ((vg mu 2).toK shdP_U * (((gz 2 + gz 2) - a1) - a2)))
        + ((vg mu 3).toK shdP_U * pad)
      (gz 0 * zc) + ((nu.toK shdP_U * gz 1) * ((gz 3 + a1) - (kI O.ceps).toK shdP_U)))]
    rw [cubeSum_split_ext 1 _ (fun bv hbv => by
      have hs := selK_ext_true 1 bv hbv
      have h0 : g 0 (fun i => (bit (bv i) : shdP_K)) = 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 1 1) 0 _ rfl]
        exact stgTabK_eq_zero_of_selK hs _ _
      have h1 : g 1 (fun i => (bit (bv i) : shdP_K)) = 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 1 1) 1 _ rfl]
        exact stgTabK_pub_zero_of_selK hs _
      dsimp only; rw [h0, h1]; ring)]
    -- Helper: evaluate narrow `log=1` `A` slice at `cptS 1 b`
    have hnar : ∀ (r0 c0 mr : ℕ) (hr0 : r0 < 76) (hc0 : c0 + 2 ≤ 4096) (b : Fin 1 → Bool),
        stgTabK shdP_U shdP_hbij P cs 1 1 (fun i : Fin 2 => (bit (cptS 1 b i) : shdP_K))
          (.priv ⟨.a, [(r0 * 4096 + c0, Fp2.one)], 1, rhoC 0 1, mr, 0⟩)
        = algebraMap GF shdP_K (shdP_outcTAData Rp w rnd ⟨r0, hr0⟩
            ⟨c0 + msbIndex 1 b, by have := msbIndex_lt 1 b; omega⟩).toGF := by
      intro r0 c0 mr hr0 hc0 b
      change Link.claimSem shdP_U 76 12 0 (tabMat 76 12 (shdP_outcTA Rp w rnd).rows) _ = _
      rw [claimSem_priv_cube_y0 P 76 12 (tabMat 76 12 (shdP_outcTA Rp w rnd).rows) 1 rfl b _
        (r0 * 4096 + c0, Fp2.one) [] rfl (by rw [outc_rowLog_a V rfl]; norm_num)
        (fun c hc _ hw => by obtain ⟨_, _, h⟩ := List.mem_map.mp hc; rw [hw] at h; cases h)]
      have hrho1Len : (rhoC 0 1).length = 1 := by simp [rhoC]
      simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, Fp2.toK_one, one_mul,
        hrho1Len]
      have hpt0 : Block.ptK shdP_U (Block.xrK 1 (fun i : Fin 2 => (bit (cptS 1 b i) : shdP_K)))
          (rhoC 0 1) 0 = (bit (b ⟨0, by norm_num⟩) : shdP_K) := by
        unfold Block.ptK
        simp only [rhoC, List.getElem?_map, List.getElem?_range' (by norm_num : 0 < 1 - 0),
          Option.map_some, Option.getD_some, Block.coordK, Nat.zero_add, one_mul]
        exact xrK_cptS (N := 2) 1 b 0 (by norm_num) (by norm_num)
      rw [data_slice_narrow1 76 r0 c0 hr0 hc0 (tabMat 76 12 (shdP_outcTA Rp w rnd).rows) b _ hpt0,
        show (shdP_outcTA Rp w rnd).rows = mkRows 76 (2 ^ 12) 256 (shdP_outcTAData Rp w rnd) rnd.aPads from rfl]
      exact tabMat_mkRows 76 12 256 _ _ ⟨r0, hr0⟩ ⟨c0 + msbIndex 1 b, by have := msbIndex_lt 1 b; omega⟩
    have hmb256 : (mbC 256 : shdP_K) = 256 := by
      rw [mbC_nat 256 (by norm_num), map_natCast, Nat.cast_ofNat]
    have hmb65536 : (mbC 65536 : shdP_K) = 65536 := by
      rw [mbC_nat 65536 (by norm_num), map_natCast, Nat.cast_ofNat]
    -- Evaluate sum over the 2 Boolean points `b : Fin 1 → Bool` (`msbIndex 1 b = 0` and `1`)
    have h2pts : ∀ b : Fin 1 → Bool,
        let gz := fun i => g i (fun j => (bit (cptS 1 b j) : shdP_K))
        let dl := l3K gz 4; let a1 := l3K gz 7; let a2 := l3K gz 10
        let pad := (1 - gz 1) * (gz 2 + zeta.toK shdP_U * gz 3)
        let zc := ((((vg mu 0).toK shdP_U * (gz 3 - gz 2 * gz 2))
          + ((vg mu 1).toK shdP_U * (gz 2 - dl)))
          + ((vg mu 2).toK shdP_U * (((gz 2 + gz 2) - a1) - a2)))
          + ((vg mu 3).toK shdP_U * pad)
        (gz 0 * zc) + ((nu.toK shdP_U * gz 1) * ((gz 3 + a1) - (kI O.ceps).toK shdP_U))
        = if b ⟨0, by norm_num⟩ = false then nu.toK shdP_U * outcPrivSum Rp w 1 else 0 := by
      intro b
      dsimp only
      have hu0 : g 1 (fun j => (bit (cptS 1 b j) : shdP_K))
          = if msbIndex 1 b = 0 then 1 else 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 1 1) 1 _ rfl]
        rw [HonestShield.stgTabK_pub_cptS _ (by simp [supp, OutcPub.toLog]) b]
        rw [show 2 ^ OutcPub.toLog = 2 by rfl,
          supp_getD_toK shdP_U 1 2 (msbIndex 1 b) (by have := msbIndex_lt 1 b; omega)]
        by_cases h0 : msbIndex 1 b = 0
        · rw [ite_eq_left (by omega), ite_eq_left h0]
        · rw [ite_eq_right (by omega), ite_eq_right h0]
      have hD : g 2 (fun j => (bit (cptS 1 b j) : shdP_K))
          = if msbIndex 1 b = 0 then (w.d : shdP_K) else 0 := by
        have h := hnar 0 0 (L.aMaskBase + 2 * (L.prefixA 2 + 0)) (by norm_num) (by norm_num) b
        have he : g 2 (fun j => (bit (cptS 1 b j) : shdP_K))
            = stgTabK shdP_U shdP_hbij P cs 1 1 (fun i : Fin 2 => (bit (cptS 1 b i) : shdP_K))
                (.priv ⟨.a, [(0 * 4096 + 0, Fp2.one)], 1, rhoC 0 1, L.aMaskBase + 2 * (L.prefixA 2 + 0), 0⟩) := by
          dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 1 1) 2 _ rfl, hDoff, hDlog, Nat.add_zero]
        rw [he, h, shdP_outcTAData_0]
        by_cases h0 : msbIndex 1 b = 0
        · rw [ite_eq_left (show (⟨0 + msbIndex 1 b, by have := msbIndex_lt 1 b; omega⟩ : Fin 4096).val = 0 by dsimp only; omega),
            ite_eq_left h0]
          exact fp_fromI64_toK w.d (by linarith [w.hd_lo]) (by linarith [w.hd_hi])
        · rw [ite_eq_right (show (⟨0 + msbIndex 1 b, by have := msbIndex_lt 1 b; omega⟩ : Fin 4096).val ≠ 0 by dsimp only; omega),
            ite_eq_right h0, fp_zero_toGF, map_zero]
      have hDsq : g 3 (fun j => (bit (cptS 1 b j) : shdP_K))
          = if msbIndex 1 b = 0 then (w.d * w.d : shdP_K) else 0 := by
        have h := hnar 1 0 (L.aMaskBase + 2 * (L.prefixA 2 + 1)) (by norm_num) (by norm_num) b
        have he : g 3 (fun j => (bit (cptS 1 b j) : shdP_K))
            = stgTabK shdP_U shdP_hbij P cs 1 1 (fun i : Fin 2 => (bit (cptS 1 b i) : shdP_K))
                (.priv ⟨.a, [(1 * 4096 + 0, Fp2.one)], 1, rhoC 0 1, L.aMaskBase + 2 * (L.prefixA 2 + 1), 0⟩) := by
          dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 1 1) 3 _ rfl, hDsqoff, hDsqlog, Nat.add_zero]
        rw [he, h, shdP_outcTAData_1]
        by_cases h0 : msbIndex 1 b = 0
        · rw [ite_eq_left (show (⟨0 + msbIndex 1 b, by have := msbIndex_lt 1 b; omega⟩ : Fin 4096).val = 0 by dsimp only; omega),
            ite_eq_left h0]
          have hsq0 : 0 ≤ w.d * w.d := mul_self_nonneg w.d
          have hsq : w.d * w.d < 2 ^ 48 := by
            have h1 : w.d * w.d ≤ w.d * 2 ^ 24 := mul_le_mul_of_nonneg_left (le_of_lt w.hd_hi) (by linarith [w.hd_lo])
            have h2 : w.d * 2 ^ 24 < 2 ^ 24 * 2 ^ 24 := mul_lt_mul_of_pos_right w.hd_hi (by norm_num)
            linarith
          rw [fp_fromI64_toK (w.d * w.d) (by linarith) (by linarith), Int.cast_mul]
        · rw [ite_eq_right (show (⟨0 + msbIndex 1 b, by have := msbIndex_lt 1 b; omega⟩ : Fin 4096).val ≠ 0 by dsimp only; omega),
            ite_eq_right h0, fp_zero_toGF, map_zero]
      have hlimb : ∀ (kk : ℕ) (hkk : kk < 9),
          g (4 + kk) (fun j => (bit (cptS 1 b j) : shdP_K))
          = ((loLook w ⟨2 * kk + msbIndex 1 b, by have := msbIndex_lt 1 b; omega⟩).val : shdP_K) := by
        intro kk hkk
        have h := hnar 2 (2 * kk) (L.aMaskBase + 2 * (L.prefixA 2 + (2 + kk))) (by norm_num) (by omega) b
        have he : g (4 + kk) (fun j => (bit (cptS 1 b j) : shdP_K))
            = stgTabK shdP_U shdP_hbij P cs 1 1 (fun i : Fin 2 => (bit (cptS 1 b i) : shdP_K))
                (.priv ⟨.a, [(2 * 4096 + 2 * kk, Fp2.one)], 1, rhoC 0 1,
                  L.aMaskBase + 2 * (L.prefixA 2 + (2 + kk)), 0⟩) := by
          dsimp only [g]
          rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 1 1) (4 + kk) _ (htabs_limb kk hkk), hLoff]
        rw [he, h, shdP_outcTAData_2, Fp.toGF_ofGF, map_natCast]
      cases hb : b ⟨0, by norm_num⟩ with
      | false =>
        have hm0 : msbIndex 1 b = 0 := by
          have : b = fun _ => false := by funext a; fin_cases a; exact hb
          rw [this]; exact msbIndex_toLog_false
        rw [hu0, hD, hDsq, hm0, ite_eq_left rfl, ite_eq_left rfl, ite_eq_left rfl]
        have hlimb0 : ∀ (kk : ℕ) (hkk : kk < 9),
            g (4 + kk) (fun j => (bit (cptS 1 b j) : shdP_K))
            = ((loLook w ⟨2 * kk + 0, by omega⟩).val : shdP_K) := by
          intro kk hkk
          exact (hlimb kk hkk).trans
            (congrArg (fun idx => ((loLook w idx).val : shdP_K)) (Fin.ext (by dsimp only; omega)))
        have hdl : l3K (fun i => g i (fun j => (bit (cptS 1 b j) : shdP_K))) 4 = (w.d : shdP_K) := by
          unfold l3K; dsimp only
          rw [show (4 : ℕ) = 4 + 0 by rfl, show 4 + 0 + 1 = 4 + 1 by rfl, show 4 + 0 + 2 = 4 + 2 by rfl,
            hlimb0 0 (by norm_num), hlimb0 1 (by norm_num), hlimb0 2 (by norm_num), hmb256, hmb65536]
          have h3 := sum_bytes_3 w.d.toNat (by have := w.hd_lo; have := w.hd_hi; omega)
          have hl0 : (loLook w ⟨2 * 0 + 0, by norm_num⟩).val = (byteOf 0 w.d.toNat).val := rfl
          have hl1 : (loLook w ⟨2 * 1 + 0, by norm_num⟩).val = (byteOf 1 w.d.toNat).val := rfl
          have hl2 : (loLook w ⟨2 * 2 + 0, by norm_num⟩).val = (byteOf 2 w.d.toNat).val := rfl
          rw [hl0, hl1, hl2]
          have hcast : ((byteOf 0 w.d.toNat).val : shdP_K) + ((byteOf 1 w.d.toNat).val : shdP_K) * 256
              + ((byteOf 2 w.d.toNat).val : shdP_K) * 65536 = (w.d.toNat : shdP_K) := by
            have := congrArg (Nat.cast (R := shdP_K)) h3; push_cast at this; exact this
          rw [hcast, ← Int.cast_natCast, Int.toNat_of_nonneg (by linarith [w.hd_lo])]
        have ha1 : l3K (fun i => g i (fun j => (bit (cptS 1 b j) : shdP_K))) 7 = (w.a1 : shdP_K) := by
          unfold l3K; dsimp only
          rw [show (7 : ℕ) = 4 + 3 by rfl, show 4 + 3 + 1 = 4 + 4 by rfl, show 4 + 3 + 2 = 4 + 5 by rfl,
            hlimb0 3 (by norm_num), hlimb0 4 (by norm_num), hlimb0 5 (by norm_num), hmb256, hmb65536]
          have h3 := sum_bytes_3 w.a1.toNat (by have := w.ha1_lo; have := w.ha1_hi; omega)
          have hl0 : (loLook w ⟨2 * 3 + 0, by norm_num⟩).val = (byteOf 0 w.a1.toNat).val := rfl
          have hl1 : (loLook w ⟨2 * 4 + 0, by norm_num⟩).val = (byteOf 1 w.a1.toNat).val := rfl
          have hl2 : (loLook w ⟨2 * 5 + 0, by norm_num⟩).val = (byteOf 2 w.a1.toNat).val := rfl
          rw [hl0, hl1, hl2]
          have hcast : ((byteOf 0 w.a1.toNat).val : shdP_K) + ((byteOf 1 w.a1.toNat).val : shdP_K) * 256
              + ((byteOf 2 w.a1.toNat).val : shdP_K) * 65536 = (w.a1.toNat : shdP_K) := by
            have := congrArg (Nat.cast (R := shdP_K)) h3; push_cast at this; exact this
          rw [hcast, ← Int.cast_natCast, Int.toNat_of_nonneg w.ha1_lo]
        have ha2 : l3K (fun i => g i (fun j => (bit (cptS 1 b j) : shdP_K))) 10 = (w.a2 : shdP_K) := by
          unfold l3K; dsimp only
          rw [show (10 : ℕ) = 4 + 6 by rfl, show 4 + 6 + 1 = 4 + 7 by rfl, show 4 + 6 + 2 = 4 + 8 by rfl,
            hlimb0 6 (by norm_num), hlimb0 7 (by norm_num), hlimb0 8 (by norm_num), hmb256, hmb65536]
          have h3 := sum_bytes_3 w.a2.toNat (by have := w.ha2_lo; have := w.ha2_hi; omega)
          have hl0 : (loLook w ⟨2 * 6 + 0, by norm_num⟩).val = (byteOf 0 w.a2.toNat).val := rfl
          have hl1 : (loLook w ⟨2 * 7 + 0, by norm_num⟩).val = (byteOf 1 w.a2.toNat).val := rfl
          have hl2 : (loLook w ⟨2 * 8 + 0, by norm_num⟩).val = (byteOf 2 w.a2.toNat).val := rfl
          rw [hl0, hl1, hl2]
          have hcast : ((byteOf 0 w.a2.toNat).val : shdP_K) + ((byteOf 1 w.a2.toNat).val : shdP_K) * 256
              + ((byteOf 2 w.a2.toNat).val : shdP_K) * 65536 = (w.a2.toNat : shdP_K) := by
            have := congrArg (Nat.cast (R := shdP_K)) h3; push_cast at this; exact this
          rw [hcast, ← Int.cast_natCast, Int.toNat_of_nonneg w.ha2_lo]
        have hceps : (kI O.ceps).toK shdP_U = (Rp.out.ceps : shdP_K) :=
          kI_int_toK shdP_U Rp.out.ceps (by linarith [hOut.cepsa]) (by linarith [hOut.cepsb])
        have ha12K : ((w.d : shdP_K) + (w.d : shdP_K)) - (w.a1 : shdP_K) - (w.a2 : shdP_K) = 0 := by
          have h : ((w.a1 + w.a2 : ℤ) : shdP_K) = ((2 * w.d : ℤ) : shdP_K) := by rw [w.ha12_eq]
          push_cast at h; linear_combination -h
        have hssK : ((w.d : shdP_K) * (w.d : shdP_K) + (w.a1 : shdP_K)) - (Rp.out.ceps : shdP_K) = outcPrivSum Rp w 1 := by
          have h : ((w.d * w.d + w.a1 : ℤ) : shdP_K) = ((Rp.out.ceps + ∑ i : Fin 3072, w.y25 (Rp.row, i) * w.y25 (Rp.row, i) : ℤ) : shdP_K) := by
            rw [w.hdsq_eq]
          push_cast at h; unfold outcPrivSum; linear_combination h
        rw [hdl, ha1, ha2, hceps, ha12K, hssK, ite_eq_left rfl]
        ring
      | true =>
        have hm1 : msbIndex 1 b = 1 := by
          have hb1 : b = msbBits 1 1 := by funext a; fin_cases a; exact hb
          rw [hb1, msbIndex_msbBits 1 1 (by norm_num)]
        rw [hu0, hD, hDsq, hm1, ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num)]
        have hlodd : ∀ (kk : ℕ) (hkk : kk < 9), (loLook w ⟨2 * kk + 1, by omega⟩).val = 0 := by
          intro kk hkk; unfold loLook; dsimp only
          rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega)]
        have hlimb1 : ∀ (kk : ℕ) (hkk : kk < 9),
            g (4 + kk) (fun j => (bit (cptS 1 b j) : shdP_K))
            = ((loLook w ⟨2 * kk + 1, by omega⟩).val : shdP_K) := by
          intro kk hkk
          exact (hlimb kk hkk).trans
            (congrArg (fun idx => ((loLook w idx).val : shdP_K)) (Fin.ext (by dsimp only; omega)))
        have hdl0 : l3K (fun i => g i (fun j => (bit (cptS 1 b j) : shdP_K))) 4 = 0 := by
          unfold l3K; dsimp only
          rw [show (4 : ℕ) = 4 + 0 by rfl, show 4 + 0 + 1 = 4 + 1 by rfl, show 4 + 0 + 2 = 4 + 2 by rfl,
            hlimb1 0 (by norm_num), hlimb1 1 (by norm_num), hlimb1 2 (by norm_num),
            hlodd 0 (by norm_num), hlodd 1 (by norm_num), hlodd 2 (by norm_num)]
          simp
        have ha10 : l3K (fun i => g i (fun j => (bit (cptS 1 b j) : shdP_K))) 7 = 0 := by
          unfold l3K; dsimp only
          rw [show (7 : ℕ) = 4 + 3 by rfl, show 4 + 3 + 1 = 4 + 4 by rfl, show 4 + 3 + 2 = 4 + 5 by rfl,
            hlimb1 3 (by norm_num), hlimb1 4 (by norm_num), hlimb1 5 (by norm_num),
            hlodd 3 (by norm_num), hlodd 4 (by norm_num), hlodd 5 (by norm_num)]
          simp
        have ha20 : l3K (fun i => g i (fun j => (bit (cptS 1 b j) : shdP_K))) 10 = 0 := by
          unfold l3K; dsimp only
          rw [show (10 : ℕ) = 4 + 6 by rfl, show 4 + 6 + 1 = 4 + 7 by rfl, show 4 + 6 + 2 = 4 + 8 by rfl,
            hlimb1 6 (by norm_num), hlimb1 7 (by norm_num), hlimb1 8 (by norm_num),
            hlodd 6 (by norm_num), hlodd 7 (by norm_num), hlodd 8 (by norm_num)]
          simp
        rw [hdl0, ha10, ha20, ite_eq_right (by decide)]
        ring
    rw [Finset.sum_congr rfl (fun b _ => h2pts b)]
    rw [Finset.sum_eq_single_of_mem (fun _ : Fin 1 => false) (Finset.mem_univ _)]
    · rw [ite_eq_left rfl]
    · intro b _ hne
      have ht : b ⟨0, by norm_num⟩ = true := by
        cases h : b ⟨0, by norm_num⟩
        · have hf : False := hne (by funext a; fin_cases a; exact h)
          cases hf
        · rfl
      rw [ht, ite_eq_right (by decide)]

include hOut in
/-- Slot 3 (`OUTC-03 PD`, `.priv`): `IndDegLE 2`, `cubeSum = outcPrivSum Rp w 3`, `df.hosted = []`. -/
theorem outc_slot3_arith (gamma alpha : Fp2)
    (df : SlotDef) (hdef : outcDefPD (rcVerdict (shdP_outcPub Rp wDigest) w.v) (shdP_outcGeo bOutRow) = .ok df) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let P := V.bp
    let cs := outcCs (shdP_outcTA Rp w rnd) (shdP_outcTH Rp w rnd gamma alpha) TB
    IndDegLE 2 (slotPolyK P (fun _ => 14) cs 3 df)
      ∧ cubeSum (slotPolyK P (fun _ => 14) cs 3 df) = outcPrivSum Rp w 3
      ∧ df.hosted = []
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P cs
  let O := V.pub; let L := outcLay O 14
  have hGb : V.geo.bLogN = 14 := rfl
  have hdef' : outcDefPD V.pub V.geo = .ok df := hdef
  have hok := outcDefPD_ok V.pub V.geo
  dsimp only at hok; rw [hok] at hdef'
  have hdf := (Except.ok.inj hdef').symm
  have hdBits : O.dBits = 12 := (shdP_outcPub_logs Rp wDigest).2.2.2
  have hldo : O.ldo = 12 := (shdP_outcPub_logs Rp wDigest).2.1
  have hlift : O.lift = 0 := by unfold OutcPub.lift; omega
  have hsh3 : Exec.Block.slotShape P 3 = (12, 1, 2) := shdP_outc_slotShape tag Rp wDigest bOutRow w.v 3
  have hN3 : slotN P 3 = 13 := by unfold slotN; rw [hsh3]; rfl
  have hYlog : L.aLog.getD ocC_Y 0 = 12 :=
    (shdP_outcLay_aLog Rp wDigest w.v ocC_Y (by norm_num [ocC_Y])).trans (ite_eq_right (by norm_num [ocC_Y]))
  let tabs := [
    Tab.priv ⟨.a, [(L.aOff ocC_Y, Fp2.one)], L.aLog.getD ocC_Y 0,
      fixedC (List.replicate O.lift Fp2.zero) ++ rhoC 0 O.dBits,
      L.aMaskBase + 2 * (L.prefixA 3 + 0), 0⟩,
    Tab.pub (wTab O.dPad (O.wDelta.take O.d))]
  have htabs : df.tabs = tabs := by rw [hdf]; dsimp only [tabs, L, O]; rw [hGb]
  have hpolyEq : df.poly = pdPoly := by rw [hdf]
  have hfit : tabsFit 12 tabs := by
    intro t ht; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl
    · trivial
    · show (wTab 4096 _).length = 2 ^ 12; simp only [wTab, List.length_map, List.length_range]; rfl
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st he; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl <;> cases he
  let g : ℕ → (Fin 13 → shdP_K) → shdP_K := fun j z =>
    (tabs.map (stgTabK shdP_U shdP_hbij P cs 12 1 z)).getD j 0
  have hpoly : ∀ z : Fin (slotN P 3) → shdP_K,
      slotPolyK P (fun _ => 14) cs 3 df z
        = g 0 (fun i => z (Fin.cast hN3.symm i)) * g 1 (fun i => z (Fin.cast hN3.symm i)) := by
    intro z
    unfold slotPolyK
    have hatP : atLog P 14 = P := shdVo_atLog_14 tag Rp wDigest bOutRow w.v
    have hs : (Exec.Block.slotShape P 3).1 = 12 := by rw [hsh3]
    dsimp only; rw [hatP, hs, htabs]
    obtain ⟨vals, htv, _, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU P cs 12 1 hN3 z tabs hfit hcan
    rw [htv]; dsimp only; rw [hpolyEq]
    have hvg : ∀ i, (vg vals i).toK shdP_U = g i (fun j => z (Fin.cast hN3.symm j)) := fun i => by
      rw [vg_toK_map, hvmap]
      simp only [g, List.getD_eq_getElem?_getD, List.getElem?_map]
      cases h : tabs[i]? with
      | none => rfl
      | some tb => simp only [Option.map_some, Option.getD_some]; exact stgTabK_cast hN3 z tb
    unfold pdPoly
    rw [Fp2.toK_mul shdP_U shdP_hU, hvg 0, hvg 1]
  have hg0_spec := outc_tabA12_spec tag Rp wDigest bOutRow w.v w TB rnd gamma alpha ocC_Y
    (L.aMaskBase + 2 * (L.prefixA 3 + 0)) (by norm_num [ocC_Y]) (by norm_num [ocC_Y])
  have hg0_eq : g 0 = fun z => stgTabK shdP_U shdP_hbij P cs 12 1 z
      (.priv ⟨.a, [(L.aOff ocC_Y, Fp2.one)], L.aLog.getD ocC_Y 0, rhoC 0 (L.aLog.getD ocC_Y 0),
        L.aMaskBase + 2 * (L.prefixA 3 + 0), 0⟩) := by
    funext z
    dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl]
    simp only [hlift, hdBits, hYlog, List.replicate_zero, fixedC, List.map_nil, List.nil_append]
  have hg0 : IndDegLE 1 (g 0) := by rw [hg0_eq]; exact hg0_spec.1
  have hg1 : IndDegLE 1 (g 1) :=
    indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl (stgTabK_pub_indDeg _)
  refine ⟨?_, ?_, by rw [hdf], fun vals => by rw [hdf]; exact Fp2.canon_mul _ _⟩
  · rw [funext hpoly]; exact indDegLE_cast hN3 (fun z : Fin 13 → shdP_K => g 0 z * g 1 z) (IndDegLE.mul hg0 hg1)
  · rw [funext hpoly, cubeSum_cast hN3 (fun z : Fin 13 → shdP_K => g 0 z * g 1 z)]
    rw [cubeSum_split_ext 12 _ (fun bv hbv => by
      have hs := selK_ext_true 12 bv hbv
      have h1 : g 1 (fun i => (bit (bv i) : shdP_K)) = 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl]
        exact stgTabK_pub_zero_of_selK hs _
      rw [h1, mul_zero])]
    have htake_eq : O.wDelta.take O.d = shdP_wDelta Rp.out.wΔ := by
      change (shdP_wDelta Rp.out.wΔ).take 3072 = shdP_wDelta Rp.out.wΔ
      exact List.take_of_length_le (by rw [shdP_wDelta_length])
    have hpt : ∀ b : Fin 12 → Bool,
        g 0 (fun i => (bit (cptS 12 b i) : shdP_K)) * g 1 (fun i => (bit (cptS 12 b i) : shdP_K))
        = if hc : msbIndex 12 b < 3072 then
            (w.q ⟨msbIndex 12 b, hc⟩ : shdP_K) * (Rp.out.wΔ ⟨msbIndex 12 b, hc⟩ : shdP_K)
          else 0 := by
      intro b
      have h0 : g 0 (fun i => (bit (cptS 12 b i) : shdP_K))
          = if hc : msbIndex 12 b < 3072 then (w.q ⟨msbIndex 12 b, hc⟩ : shdP_K) else 0 := by
        rw [hg0_eq]; refine (hg0_spec.2 b).trans ?_
        dsimp only [ocC_Y]; rw [shdP_outcTAData_6]
        by_cases hc : msbIndex 12 b < 3072
        · rw [dite_eq_left hc, dite_eq_left hc]
          exact fp_fromI64_toK _ (by linarith [w.hq_lo ⟨msbIndex 12 b, hc⟩]) (by linarith [w.hq_hi ⟨msbIndex 12 b, hc⟩])
        · rw [dite_eq_right hc, dite_eq_right hc, fp_zero_toGF, map_zero]
      have h1 : g 1 (fun i => (bit (cptS 12 b i) : shdP_K))
          = if hc : msbIndex 12 b < 3072 then (Rp.out.wΔ ⟨msbIndex 12 b, hc⟩ : shdP_K) else 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl]
        rw [HonestShield.stgTabK_pub_cptS _ (by show (wTab 4096 _).length = 2 ^ 12; simp only [wTab, List.length_map, List.length_range]; rfl) b,
          show O.dPad = 4096 from rfl, htake_eq]
        rw [wTab_getD_toK shdP_U 4096 (shdP_wDelta Rp.out.wΔ) (msbIndex 12 b) (msbIndex_lt 12 b)
          (fun hi => by
            rw [shdP_wDelta_length] at hi
            rw [shdP_wDelta_getD Rp.out.wΔ _ hi]
            have hw := abs_le.mp (hOut.w ⟨msbIndex 12 b, hi⟩)
            exact ⟨by linarith, by linarith⟩)]
        rw [shdP_wDelta_length]
        by_cases hc : msbIndex 12 b < 3072
        · rw [ite_eq_left hc, dite_eq_left hc, shdP_wDelta_getD Rp.out.wΔ _ hc]
        · rw [ite_eq_right hc, dite_eq_right hc]
      by_cases hc : msbIndex 12 b < 3072
      · rw [h0, h1, dite_eq_left hc, dite_eq_left hc, dite_eq_left hc]
      · rw [h0, h1, dite_eq_right hc, dite_eq_right hc, dite_eq_right hc, zero_mul]
    rw [Finset.sum_congr rfl (fun b _ => hpt b)]
    rw [sum_fin12_bool_eq (fun col : Fin 4096 => if hc : col.val < 3072 then
      (w.q ⟨col.val, hc⟩ : shdP_K) * (Rp.out.wΔ ⟨col.val, hc⟩ : shdP_K) else 0)]
    rw [← Finset.sum_filter_add_sum_filter_not Finset.univ (fun col : Fin 4096 => col.val < 3072)]
    have hzero : ∑ col ∈ Finset.univ.filter (fun col : Fin 4096 => ¬ col.val < 3072),
        (if hc : col.val < 3072 then (w.q ⟨col.val, hc⟩ : shdP_K) * (Rp.out.wΔ ⟨col.val, hc⟩ : shdP_K) else 0) = 0 :=
      Finset.sum_eq_zero (fun col hcol => dite_eq_right (Finset.mem_filter.mp hcol).2)
    rw [hzero, add_zero]
    unfold outcPrivSum
    refine Finset.sum_bij (fun (col : Fin 4096) (hcol : col ∈ Finset.univ.filter _) =>
        (⟨col.val, (Finset.mem_filter.mp hcol).2⟩ : Fin 3072))
      (fun _ _ => Finset.mem_univ _)
      (fun a _ b _ h => Fin.ext (congrArg (Fin.val : Fin 3072 → ℕ) h))
      (fun i _ => ⟨⟨i.val, by have := i.isLt; omega⟩, Finset.mem_filter.mpr ⟨Finset.mem_univ _, i.isLt⟩, Fin.ext rfl⟩)
      (fun col hcol => dite_eq_left (Finset.mem_filter.mp hcol).2)

include hOut in
/-- Slot 4 (`OUTC-04 LZC`, `.host` of slot 3): `IndDegLE 4`, `cubeSum = ν * outcPrivSum Rp w 3`,
`df.hosted = [(3, dr.getD 14 Fp2.zero)]`. -/
theorem outc_slot4_arith (hist : Hist) (halphaCan : hist.alpha.Canon)
    (halphaNe : ∀ z : ℕ, z < 256 →
      hist.alpha.toK shdP_U ≠ (z : shdP_K) + (hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))).toK shdP_U)
    (dr : List Fp2) (hlen : dr.length = 15) (hdrCan : ∀ a ∈ dr, a.Canon)
    (df : SlotDef) (hdef : outcDefLZC (rcVerdict (shdP_outcPub Rp wDigest) w.v) (shdP_outcGeo bOutRow) hist dr = .ok df) :
    let V := shdVo tag Rp wDigest bOutRow w.v
    let P := V.bp
    let cs := outcCs (shdP_outcTA Rp w rnd) (shdP_outcTH Rp w rnd hist.gamma hist.alpha) TB
    IndDegLE 4 (slotPolyK P (fun _ => 14) cs 4 df)
      ∧ cubeSum (slotPolyK P (fun _ => 14) cs 4 df) = (dr.getD 14 Fp2.zero).toK shdP_U * outcPrivSum Rp w 3
      ∧ df.hosted = [(3, dr.getD 14 Fp2.zero)]
      ∧ ∀ vals, (df.poly vals).Canon := by
  intro V P cs
  let O := V.pub; let L := outcLay O 14
  have hGb : V.geo.bLogN = 14 := rfl
  have hllo : O.llo = 12 := (shdP_outcPub_logs Rp wDigest).1
  have hdf := outcDefLZC_eq_of_ok O V.geo hist hllo dr hlen hdrCan df hdef
  dsimp only at hdf
  let mu := (dr.drop O.llo).take 2
  let nu := dr.getD (O.llo + 2) Fp2.zero
  let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
  let kc := (kI O.verdict).add (kI O.c)
  have hnuEq : nu = dr.getD 14 Fp2.zero := by simp [nu, hllo]
  have hsh4 : Exec.Block.slotShape P 4 = (12, 1, 4) := shdP_outc_slotShape tag Rp wDigest bOutRow w.v 4
  have hN4 : slotN P 4 = 13 := by unfold slotN; rw [hsh4]; rfl
  let tabs : List Tab := [
    .eq (dr.take O.llo) 0,
    .pub (liveTab (2 ^ O.llo) OutcPub.lamBase O.limbs),
    .pub (gTab (2 ^ O.llo) OutcPub.lamBase O.limbs O.verdict),
    .pub (supp 1 (2 ^ O.llo)),
    .priv ⟨.a, [(L.aOff ocC_LIMB, Fp2.one)], L.aLog.getD ocC_LIMB 0,
      rhoC 0 (L.aLog.getD ocC_LIMB 0), L.aMaskBase + 2 * (L.prefixA 4 + 0), 0⟩,
    .priv ⟨.h, [((L.hOff ocH_LO).1, Fp2.one), ((L.hOff ocH_LO).2, Block.fp2U)],
      L.hLog.getD ocH_LO 0, rhoC 0 (L.hLog.getD ocH_LO 0), L.hMaskBase + 2 * (L.prefixH 4 + 0), 0⟩]
  have htabs : df.tabs = tabs := by rw [hdf]; dsimp only [tabs, L, O]; rw [hGb]
  have hpolyEq : df.poly = lzcPoly mu nu hist.alpha gU8 kc := by rw [hdf]
  have hfit : tabsFit 12 tabs := by
    intro t ht; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl | rfl | rfl
    · show 0 + (dr.take O.llo).length ≤ 12; rw [hllo, Nat.zero_add]; exact List.length_take_le _ _
    · show (liveTab _ _ _).length = 2 ^ 12; simp only [liveTab, List.length_map, List.length_range, hllo]
    · show (gTab _ _ _ _).length = 2 ^ 12; simp only [gTab, List.length_map, List.length_range, hllo]
    · show (supp 1 _).length = 2 ^ 12; simp only [supp, List.length_map, List.length_range, hllo]
    · trivial
    · trivial
  have hcan : ∀ t ∈ tabs, ∀ pt st, t = .eq pt st → ∀ a ∈ pt, a.Canon := by
    intro t ht pt st he a ha; simp only [tabs, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl | rfl | rfl
    · cases he; exact hdrCan a (List.mem_of_mem_take ha)
    all_goals cases he
  let g : ℕ → (Fin 13 → shdP_K) → shdP_K := fun j z =>
    (tabs.map (stgTabK shdP_U shdP_hbij P cs 12 1 z)).getD j 0
  have hpoly : ∀ z : Fin (slotN P 4) → shdP_K,
      slotPolyK P (fun _ => 14) cs 4 df z
        = let gz := fun i => g i (fun j => z (Fin.cast hN4.symm j))
          let helper := gz 5 * denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) gz 4 1 0 - 1
          let pad := (1 - gz 1) * gz 4
          let host := gz 2 * gz 4 + gz 3 * kc.toK shdP_U
          gz 0 * ((vg mu 0).toK shdP_U * helper + (vg mu 1).toK shdP_U * pad) + nu.toK shdP_U * host := by
    intro z
    unfold slotPolyK
    have hatP : atLog P 14 = P := shdVo_atLog_14 tag Rp wDigest bOutRow w.v
    have hs : (Exec.Block.slotShape P 4).1 = 12 := by rw [hsh4]
    dsimp only; rw [hatP, hs, htabs]
    obtain ⟨vals, htv, hvcan, hvmap⟩ := tabVals_stgTabK shdP_U shdP_hbij shdP_hU P cs 12 1 hN4 z tabs hfit hcan
    rw [htv]; dsimp only; rw [hpolyEq]
    have hvg : ∀ i, (vg vals i).toK shdP_U = g i (fun j => z (Fin.cast hN4.symm j)) := fun i => by
      rw [vg_toK_map, hvmap]
      simp only [g, List.getD_eq_getElem?_getD, List.getElem?_map]
      cases h : tabs[i]? with
      | none => rfl
      | some tb => simp only [Option.map_some, Option.getD_some]; exact stgTabK_cast hN4 z tb
    unfold lzcPoly
    rw [Fp2.toK_add shdP_U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
        Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_add shdP_U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
        Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_add shdP_U _ _ Fp2.canon_zero (Fp2.canon_mul _ _), Fp2.toK_zero, zero_add,
        Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_one, one_mul,
        Fp2.toK_sub shdP_U _ _ (Fp2.canon_mul _ _) Fp2.canon_one, Fp2.toK_one,
        Fp2.toK_mul shdP_U shdP_hU,
        denW_toK shdP_U vals hist.alpha gU8 halphaCan (Fp2.canon_mulBase _ _) 4 1 0,
        Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_sub shdP_U _ _ Fp2.canon_one (vg_canon hvcan 1), Fp2.toK_one,
        Fp2.toK_mul shdP_U shdP_hU,
        Fp2.toK_add shdP_U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
        Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_mul shdP_U shdP_hU]
    have hmapFn : (fun idx => (vals.map (Fp2.toK shdP_U)).getD idx 0)
        = fun i => g i (fun j => z (Fin.cast hN4.symm j)) :=
      funext (fun i => by rw [← vg_toK_map, hvg i])
    rw [hmapFn, hvg 0, hvg 1, hvg 2, hvg 3, hvg 4, hvg 5]
  have hg4_spec := outc_tabA12_spec tag Rp wDigest bOutRow w.v w TB rnd hist.gamma hist.alpha ocC_LIMB
    (L.aMaskBase + 2 * (L.prefixA 4 + 0)) (by norm_num [ocC_LIMB]) (by norm_num [ocC_LIMB])
  have hg5_spec := outc_tabH12_spec tag Rp wDigest bOutRow w.v w TB rnd hist.gamma hist.alpha ocH_LO
    (L.hMaskBase + 2 * (L.prefixH 4 + 0)) (by norm_num [ocH_LO])
  have hg_deg : ∀ idx, IndDegLE 1 (g idx) := by
    intro idx
    have hlen_tabs : tabs.length = 6 := rfl
    by_cases hlt : idx < 6
    · interval_cases idx
      · exact indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl (stgTabK_eq_indDeg _ _)
      · exact indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl (stgTabK_pub_indDeg _)
      · exact indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 2 _ rfl (stgTabK_pub_indDeg _)
      · exact indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 3 _ rfl (stgTabK_pub_indDeg _)
      · exact indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 4 _ rfl hg4_spec.1
      · exact indDegLE_map_getD tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 5 _ rfl hg5_spec.1
    · have hzero : g idx = fun _ => 0 := by
        funext z
        dsimp only [g]
        rw [List.getD_eq_getElem?_getD,
          List.getElem?_eq_none (l := tabs.map (stgTabK shdP_U shdP_hbij P cs 12 1 z))
            (by rw [List.length_map, hlen_tabs]; omega)]
        rfl
      rw [hzero]; exact IndDegLE.const 0
  have hdeg4 : IndDegLE 4 (fun z : Fin 13 → shdP_K =>
      let gz := fun i => g i z
      let helper := gz 5 * denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) gz 4 1 0 - 1
      let pad := (1 - gz 1) * gz 4
      let host := gz 2 * gz 4 + gz 3 * kc.toK shdP_U
      gz 0 * ((vg mu 0).toK shdP_U * helper + (vg mu 1).toK shdP_U * pad) + nu.toK shdP_U * host) := by
    have hden := indDegLE_denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) g hg_deg 4 1 0
    have hhlp : IndDegLE 2 (fun z => g 5 z * denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) (fun i => g i z) 4 1 0 - 1) :=
      IndDegLE.sub (IndDegLE.mul (hg_deg 5) hden) (IndDegLE.const 1)
    have hpad : IndDegLE 2 (fun z => (1 - g 1 z) * g 4 z) :=
      IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg_deg 1)) (hg_deg 4)
    have hhost : IndDegLE 2 (fun z => g 2 z * g 4 z + g 3 z * kc.toK shdP_U) :=
      IndDegLE.add (IndDegLE.mul (hg_deg 2) (hg_deg 4)) (IndDegLE.mono (IndDegLE_mulc (hg_deg 3) _) (by norm_num))
    exact IndDegLE.mono (IndDegLE.add
      (IndDegLE.mul (hg_deg 0) (IndDegLE.add (IndDegLE.cmul _ hhlp) (IndDegLE.cmul _ hpad)))
      (IndDegLE.mono (IndDegLE.cmul _ hhost) (by norm_num))) (by norm_num)
  refine ⟨?_, ?_, by rw [hdf]; dsimp only; rw [hllo], fun vals => by rw [hdf]; exact Fp2.canon_add _ _⟩
  · rw [funext hpoly]
    exact indDegLE_cast hN4 (fun z : Fin 13 → shdP_K =>
      let gz := fun i => g i z
      let helper := gz 5 * denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) gz 4 1 0 - 1
      let pad := (1 - gz 1) * gz 4
      let host := gz 2 * gz 4 + gz 3 * kc.toK shdP_U
      gz 0 * ((vg mu 0).toK shdP_U * helper + (vg mu 1).toK shdP_U * pad) + nu.toK shdP_U * host) hdeg4
  · rw [funext hpoly, cubeSum_cast hN4 (fun z : Fin 13 → shdP_K =>
      let gz := fun i => g i z
      let helper := gz 5 * denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) gz 4 1 0 - 1
      let pad := (1 - gz 1) * gz 4
      let host := gz 2 * gz 4 + gz 3 * kc.toK shdP_U
      gz 0 * ((vg mu 0).toK shdP_U * helper + (vg mu 1).toK shdP_U * pad) + nu.toK shdP_U * host)]
    rw [cubeSum_split_ext 12 _ (fun bv hbv => by
      have hs := selK_ext_true 12 bv hbv
      have h0 : g 0 (fun i => (bit (bv i) : shdP_K)) = 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 0 _ rfl]
        exact stgTabK_eq_zero_of_selK hs _ _
      have h2 : g 2 (fun i => (bit (bv i) : shdP_K)) = 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 2 _ rfl]
        exact stgTabK_pub_zero_of_selK hs _
      have h3 : g 3 (fun i => (bit (bv i) : shdP_K)) = 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 3 _ rfl]
        exact stgTabK_pub_zero_of_selK hs _
      dsimp only; rw [h0, h2, h3]; ring)]
    have hlim7 : Rp.out.limbs ≤ 7 := outc_limbs_le7 Rp.out hOut
    have hpt : ∀ b : Fin 12 → Bool,
        let gz := fun i => g i (fun j => (bit (cptS 12 b j) : shdP_K))
        let helper := gz 5 * denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U) gz 4 1 0 - 1
        let pad := (1 - gz 1) * gz 4
        let host := gz 2 * gz 4 + gz 3 * kc.toK shdP_U
        gz 0 * ((vg mu 0).toK shdP_U * helper + (vg mu 1).toK shdP_U * pad) + nu.toK shdP_U * host
        = nu.toK shdP_U * (gz 2 * gz 4 + gz 3 * kc.toK shdP_U) := by
      intro b
      dsimp only
      set col : Fin 4096 := ⟨msbIndex 12 b, msbIndex_lt 12 b⟩
      have h4 : g 4 (fun j => (bit (cptS 12 b j) : shdP_K)) = ((loLook w col).val : shdP_K) := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 4 _ rfl]
        refine (hg4_spec.2 b).trans ?_
        dsimp only [ocC_LIMB]; rw [shdP_outcTAData_2, Fp.toGF_ofGF, map_natCast]
      have h5 : g 5 (fun j => (bit (cptS 12 b j) : shdP_K))
          = (hist.alpha.toK shdP_U - (((loLook w col).val : shdP_K) + gU8.toK shdP_U))⁻¹ := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 5 _ rfl]
        exact hg5_spec.2 b
      have hden_eq : denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U)
          (fun i => g i (fun j => (bit (cptS 12 b j) : shdP_K))) 4 1 0
          = hist.alpha.toK shdP_U - (((loLook w col).val : shdP_K) + gU8.toK shdP_U) := by
        unfold denK; dsimp only
        rw [h4, kI_int_toK shdP_U 0 (by norm_num) (by norm_num),
          fp_fromI64_toK 1 (by norm_num) (by norm_num)]
        push_cast; ring
      have hhlp0 : g 5 (fun j => (bit (cptS 12 b j) : shdP_K))
          * denK shdP_U (hist.alpha.toK shdP_U) (gU8.toK shdP_U)
              (fun i => g i (fun j => (bit (cptS 12 b j) : shdP_K))) 4 1 0 - 1 = 0 := by
        rw [h5, hden_eq, inv_mul_cancel₀ (sub_ne_zero.mpr (halphaNe _ (loLook w col).isLt)), sub_self]
      have h1 : g 1 (fun j => (bit (cptS 12 b j) : shdP_K))
          = if (col.val % 2 = 0 ∧ col.val / 2 < 9) ∨ (32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs) then 1 else 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 1 _ rfl]
        rw [HonestShield.stgTabK_pub_cptS _ (by simp only [liveTab, List.length_map, List.length_range, hllo]) b]
        unfold liveTab; rw [rangeMap_getD (2 ^ O.llo) (msbIndex 12 b) (by rw [hllo]; exact msbIndex_lt 12 b)]
        dsimp only [col]
        rw [show OutcPub.lamBase = 32 from rfl, show O.limbs = Rp.out.limbs from rfl]
        by_cases hlive : (msbIndex 12 b % 2 = 0 ∧ msbIndex 12 b / 2 < 9) ∨ (32 ≤ msbIndex 12 b ∧ msbIndex 12 b < 32 + Rp.out.limbs)
        · rw [ite_eq_left hlive, ite_eq_left hlive, Fp2.toK_one]
        · rw [ite_eq_right hlive, ite_eq_right hlive, Fp2.toK_zero]
      have hpad0 : (1 - g 1 (fun j => (bit (cptS 12 b j) : shdP_K))) * g 4 (fun j => (bit (cptS 12 b j) : shdP_K)) = 0 := by
        rw [h1, h4]
        by_cases hlive : (col.val % 2 = 0 ∧ col.val / 2 < 9) ∨ (32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs)
        · rw [ite_eq_left hlive, sub_self, zero_mul]
        · rw [ite_eq_right hlive]
          have hlo0 : (loLook w col).val = 0 := by
            unfold loLook
            split_ifs with c1 c2 c3 c4
            · have hf : False := hlive (Or.inl ⟨c1.1, by omega⟩); cases hf
            · have hf : False := hlive (Or.inl ⟨c2.1, by omega⟩); cases hf
            · have hf : False := hlive (Or.inl ⟨c3.1, by omega⟩); cases hf
            · have hf : False := hlive (Or.inr c4); cases hf
            · rfl
          rw [hlo0]; simp
      rw [hhlp0, hpad0]; ring
    rw [Finset.sum_congr rfl (fun b _ => hpt b)]
    rw [← Finset.mul_sum, hnuEq]
    apply congrArg ((dr.getD 14 Fp2.zero).toK shdP_U * ·)
    -- Sum `g 2 * g 4 + g 3 * kc` over `Fin 12 → Bool` = `Δ = outcPrivSum Rp w 3`
    have hterm : ∀ b : Fin 12 → Bool,
        g 2 (fun j => (bit (cptS 12 b j) : shdP_K)) * g 4 (fun j => (bit (cptS 12 b j) : shdP_K))
          + g 3 (fun j => (bit (cptS 12 b j) : shdP_K)) * kc.toK shdP_U
        = (if 32 ≤ msbIndex 12 b ∧ msbIndex 12 b < 32 + Rp.out.limbs then
            algebraMap GF shdP_K (sigOf w.v * (2 : GF) ^ (8 * (msbIndex 12 b - 32)))
              * ((byteOf (msbIndex 12 b - 32) w.δ.toNat).val : shdP_K)
          else 0)
          + (if msbIndex 12 b = 0 then ((w.v : shdP_K) + (Rp.out.c : shdP_K)) else 0) := by
      intro b
      set col : Fin 4096 := ⟨msbIndex 12 b, msbIndex_lt 12 b⟩
      have h2 : g 2 (fun j => (bit (cptS 12 b j) : shdP_K))
          = if 32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs then
              algebraMap GF shdP_K (sigOf w.v * (2 : GF) ^ (8 * (col.val - 32)))
            else 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 2 _ rfl]
        rw [HonestShield.stgTabK_pub_cptS _ (by simp only [gTab, List.length_map, List.length_range, hllo]) b]
        exact gTab_getD_toK shdP_U shdP_hU (2 ^ O.llo) OutcPub.lamBase O.limbs O.verdict col.val
          (by rw [hllo]; exact col.isLt) hlim7
      have h3 : g 3 (fun j => (bit (cptS 12 b j) : shdP_K)) = if col.val = 0 then 1 else 0 := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 3 _ rfl]
        rw [HonestShield.stgTabK_pub_cptS _ (by simp only [supp, List.length_map, List.length_range, hllo]) b]
        rw [supp_getD_toK shdP_U 1 (2 ^ O.llo) (msbIndex 12 b) (by rw [hllo]; exact msbIndex_lt 12 b)]
        dsimp only [col]
        by_cases h0 : msbIndex 12 b = 0
        · rw [ite_eq_left (by omega), ite_eq_left h0]
        · rw [ite_eq_right (by omega), ite_eq_right h0]
      have h4 : g 4 (fun j => (bit (cptS 12 b j) : shdP_K)) = ((loLook w col).val : shdP_K) := by
        dsimp only [g]; rw [map_getD_eq tabs (stgTabK shdP_U shdP_hbij P cs 12 1) 4 _ rfl]
        refine (hg4_spec.2 b).trans ?_
        dsimp only [ocC_LIMB]; rw [shdP_outcTAData_2, Fp.toGF_ofGF, map_natCast]
      have hkc : kc.toK shdP_U = (w.v : shdP_K) + (Rp.out.c : shdP_K) := by
        have h := kc_toK shdP_U w.v Rp.out.c w.hv_le hOut.c
        rw [map_add, map_natCast, map_intCast] at h
        exact h
      rw [h2, h3, h4, hkc]
      refine congrArg₂ (· + ·) ?_ ?_
      · by_cases hm : 32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs
        · have hlo : loLook w col = byteOf (col.val - 32) w.δ.toNat := by
            unfold loLook
            rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left hm]
          rw [ite_eq_left hm, hlo]
          dsimp only [col] at hm ⊢
          rw [ite_eq_left hm]
        · rw [ite_eq_right hm, zero_mul]
          dsimp only [col] at hm ⊢
          rw [ite_eq_right hm]
      · dsimp only [col]
        by_cases h0 : msbIndex 12 b = 0
        · rw [ite_eq_left h0, ite_eq_left h0, one_mul]
        · rw [ite_eq_right h0, ite_eq_right h0, zero_mul]
    rw [Finset.sum_congr rfl (fun b _ => hterm b)]
    rw [Finset.sum_add_distrib,
      sum_fin12_bool_eq (fun col : Fin 4096 => if 32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs then
        algebraMap GF shdP_K (sigOf w.v * (2 : GF) ^ (8 * (col.val - 32)))
          * ((byteOf (col.val - 32) w.δ.toNat).val : shdP_K) else 0),
      sum_fin12_bool_eq (fun col : Fin 4096 => if col.val = 0 then ((w.v : shdP_K) + (Rp.out.c : shdP_K)) else 0)]
    have hsum_kc : (∑ col : Fin 4096, if col.val = 0 then ((w.v : shdP_K) + (Rp.out.c : shdP_K)) else 0)
        = (w.v : shdP_K) + (Rp.out.c : shdP_K) := by
      rw [Finset.sum_eq_single_of_mem (⟨0, by norm_num⟩ : Fin 4096) (Finset.mem_univ _)]
      · rw [ite_eq_left rfl]
      · intro col _ hne; exact ite_eq_right (fun h => hne (Fin.ext h))
    have hsum_δ : (∑ col : Fin 4096, if 32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs then
          algebraMap GF shdP_K (sigOf w.v * (2 : GF) ^ (8 * (col.val - 32)))
            * ((byteOf (col.val - 32) w.δ.toNat).val : shdP_K) else 0)
        = (if w.v = 1 then (1 : shdP_K) else -1) * (w.δ : shdP_K) := by
      rw [← Finset.sum_filter_add_sum_filter_not Finset.univ (fun col : Fin 4096 => 32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs)]
      have hzero : ∑ col ∈ Finset.univ.filter (fun col : Fin 4096 => ¬ (32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs)),
          (if 32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs then
            algebraMap GF shdP_K (sigOf w.v * (2 : GF) ^ (8 * (col.val - 32)))
              * ((byteOf (col.val - 32) w.δ.toNat).val : shdP_K) else (0 : shdP_K)) = 0 :=
        Finset.sum_eq_zero (fun col hcol => ite_eq_right (Finset.mem_filter.mp hcol).2)
      rw [hzero, add_zero]
      have hbij : ∑ col ∈ Finset.univ.filter (fun col : Fin 4096 => 32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs),
            (if 32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs then
              algebraMap GF shdP_K (sigOf w.v * (2 : GF) ^ (8 * (col.val - 32)))
                * ((byteOf (col.val - 32) w.δ.toNat).val : shdP_K) else 0)
          = ∑ k ∈ Finset.range Rp.out.limbs,
              (if w.v = 1 then (1 : shdP_K) else -1) * ((2 ^ (8 * k) * (byteOf k w.δ.toNat).val : ℕ) : shdP_K) := by
        refine Finset.sum_bij (fun (col : Fin 4096) _ => col.val - 32)
          (fun col hcol => Finset.mem_range.mpr (by have := (Finset.mem_filter.mp hcol).2; omega))
          (fun a ha b hb h => by
            have h1 := (Finset.mem_filter.mp ha).2; have h2 := (Finset.mem_filter.mp hb).2
            exact Fin.ext (by omega))
          (fun k hk => ⟨⟨32 + k, by have := Finset.mem_range.mp hk; omega⟩,
            Finset.mem_filter.mpr ⟨Finset.mem_univ _, by have := Finset.mem_range.mp hk; dsimp only; omega⟩,
            by dsimp only; omega⟩)
          (fun col hcol => by
            have h2 : algebraMap GF shdP_K (2 : GF) = (2 : shdP_K) := map_ofNat (algebraMap GF shdP_K) 2
            rw [ite_eq_left (Finset.mem_filter.mp hcol).2, map_mul, map_pow, h2]
            have hsig : algebraMap GF shdP_K (sigOf w.v) = if w.v = 1 then (1 : shdP_K) else -1 := by
              unfold sigOf; split_ifs <;> simp
            rw [hsig, Nat.cast_mul, Nat.cast_pow, Nat.cast_ofNat]; ring)
      rw [hbij, ← Finset.mul_sum, ← Nat.cast_sum]
      have hbytes := sum_bytes_eq Rp.out.limbs w.δ.toNat (by
        have h1 := w.hδ_lo; have h2 := w.hδ_hi
        have : (w.δ.toNat : ℤ) < 2 ^ (8 * Rp.out.limbs) := by rwa [Int.toNat_of_nonneg h1]
        exact_mod_cast this)
      rw [hbytes, ← Int.cast_natCast, Int.toNat_of_nonneg w.hδ_lo]
    rw [hsum_δ, hsum_kc]
    have hrel : (((if w.v = 1 then (1 : ℤ) else -1) * w.δ + ((w.v : ℤ) + Rp.out.c) : ℤ) : shdP_K)
        = (w.Δ : shdP_K) := by rw [w.hδ_rel]
    have hΔK : (w.Δ : shdP_K) = outcPrivSum Rp w 3 := by
      rw [w.hΔ]; unfold margin outcPrivSum; push_cast
      refine Finset.sum_congr rfl (fun i _ => mul_comm _ _)
    rw [← hΔK, ← hrel]
    split_ifs <;> push_cast <;> ring

end StageOutSlotArith

end ZK60.HonestShield
