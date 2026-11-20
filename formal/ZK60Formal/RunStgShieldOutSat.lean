/-
D63 lane L63 (2026-11-20), L63 leg 15, part 97: **`OutCSat` at a non-doomed OUT-C reading** (the assembly lemma of
`hdoutC`, step 2 of HANDOFF_20261120_1.md section 7).

At an OUT-C reading whose drawing slots are alive (the first doom disjunct false) and whose LogUp state is alive at the
head (the second disjunct false), the defines of OUTC-00 (IO), OUTC-02 (TZC), OUTC-04 (LZC) and OUTC-05 (DZC) vanish
at every draw at `τ`'s view (`shd_outc_zero_rdA`), which gives OUTC-00's equation (`outc_io0_eq`), TZC's four facts
(`outc_tzc`), DZC's clauses at the live channels (`outc_dzc_cb`) and the margin (`outc_margin`); the LogUp state gives
`AllBytes` (`shd_outc_bytes_rd`); `shd_outC_of_parts` then gives `OutCSat` on `B_out`'s verdict row.

The public constants' `i64` ranges and `limbs ≤ 7` come from `P.Valid` (decision D5 of leg 14: at the top `P = Rp.out`
and `O.outPub : Rp.out.Valid`); `b ≤ 1` is a hypothesis (the accepted run's verdict check at the top).

* `outc_limbs_le7`, `outc_kN_bd`: the bounds from `OutCPublic.Valid`;
* **`shd_outc_sat_rd`**: `OutCSat P (fun i => B_out(row, msbBits 12 i)) b` at `τ`'s view.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutTzc

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.Out (OutCPublic OutCSat)

section Bounds

/-- `OutCPublic.Valid`'s `nowrap` gives `limbs ≤ 7`. -/
theorem outc_limbs_le7 {n : ℕ} (P : OutCPublic n) (hP : P.Valid) : P.limbs ≤ 7 := by
  by_contra h
  have h8 : 64 ≤ 8 * P.limbs := by omega
  have hp : (2 : ℤ) ^ 64 ≤ 2 ^ (8 * P.limbs) := pow_le_pow_right₀ (by norm_num) h8
  have hm : 0 ≤ ZK60.Out.marginMax n := by unfold ZK60.Out.marginMax; positivity
  have hw := hP.nowrap
  have hg : ((gP : ℕ) : ℤ) < 2 ^ 64 := by unfold gP; norm_num
  linarith

/-- The DZC norm constant `2·g0·Cn` is in the code's `i64` range. -/
theorem outc_kN_bd {n : ℕ} (P : OutCPublic n) (hP : P.Valid) :
    -2 ^ 64 < 2 * P.g0 * P.cn ∧ 2 * P.g0 * P.cn < 2 ^ 64 := by
  have hgc : P.g0 * P.cn ≤ 127 * 2 ^ 20 := mul_le_mul hP.g0b hP.cnb (by linarith [hP.cna]) (by norm_num)
  have hgc0 : 0 ≤ P.g0 * P.cn := mul_nonneg (by linarith [hP.g0a]) (by linarith [hP.cna])
  have e : 2 * P.g0 * P.cn = 2 * (P.g0 * P.cn) := by ring
  rw [e]
  constructor <;> linarith

end Bounds

section Sat

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) {Lq : ℕ}

/-- **`OutCSat` AT A NON-DOOMED OUT-C READING**, at `τ`'s view, on `B_out`'s verdict row. -/
theorem shd_outc_sat_rd (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (absOf : QB Lq → Option (List UInt8)) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (P0 : Block.BlockParams)
    (F : ℕ → OutcV) (b n0 hdrLen rH e rX ipos : ℕ) (XO : StgVw Lq → Fin 0 → Fin (2 ^ 0 + 0) → K)
    (hIOl : VwLoc (hdrLen + (7 + 2)) (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO))
    (hIO : StgCsIODeg U hbij (F b).bp.endpointLogN (OutcPrivIO (F b).pub)
      (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO))
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq (fun _ => (F b).bp) 2 hdrLen OutcV.bga G τ hdr core ch rs)
    (hP : StgSame P0 (F b).bp) (hgt : (F b).bp.geom.slots.length = (F b).bp.geom.terms.length)
    (hgeom : ∀ k, k < (F b).bp.geom.slots.length → 1 ≤ (Block.slotShape (F b).bp k).2.2)
    (hsl : 7 ≤ P0.geom.slots.length) (hW : vdWout F (τ.take n0) = F b)
    (hGb : (F b).geo.bLogN = 14) (hOL : outcLay (F b).pub 14 = outcLay O 14)
    (hllo : (F b).pub.llo = 12) (hldo : (F b).pub.ldo = 12) (hdB : (F b).pub.dBits = 12)
    (hlift : (F b).pub.lift = 0) (htB : (F b).pub.tBits = 7) (hbo : (F b).pub.bOutLog = 19)
    (hdPad : (F b).pub.dPad = 4096) (hlt : (F b).pub.lt ≤ ogStage.lc) (hlc : 0 < (F b).bp.logCols)
    (hOlt : O.lt = 12)
    {d : ℕ} (P : OutCPublic d) (hPv : P.Valid) (hb : b ≤ 1) (hverd : (F b).pub.verdict = b)
    (hcc : (F b).pub.c = P.c) (hlim : (F b).pub.limbs = P.limbs) (hdd : (F b).pub.d = d) (hd4 : d ≤ 4096)
    (hwl : d ≤ (F b).pub.wDelta.length) (hwD : ∀ i : Fin d, (F b).pub.wDelta.getD i.val 0 = P.wΔ i)
    (hg0 : P.g0 = (F b).pub.g0) (hcn : P.cn = (F b).pub.cn) (htn : P.tn = (F b).pub.tn)
    (hceps : (F b).pub.ceps = P.ceps)
    (hal : ∀ k ∈ stgDrawing P0, (stgDefSqV P0 2 hdrLen absOf
      (sshΦO U hbij tag h64 P0 F n0 hdrLen ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH
        (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO)) sshDgO k).St lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (F b).bp core 2 ++ Block.fullOps (F b).bp 0 (core.slots.take k))) [])
    (hlk : (stgLkSqV 2 hdrLen e absOf (shd_ΛO U tag h64 O hdrLen)).St lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (F b).bp core)) []) :
    OutCSat P (fun i => (shdOutcData U tag h64 O hdrLen rX ipos (F b).pub.verdictRow (stgVw absOf lg τ)).bout
      (msbBits 12 i.val)) b := by
  obtain ⟨hch, -⟩ := stg_rd_chal key domain _ 2 hdrLen _ G τ hdr core ch rs hrd
  have hslen : core.slots.length = (F b).bp.geom.slots.length := hrd.2.2.2.1.1
  obtain ⟨acc, t', hacc⟩ := hrd.2.2.2.2.1
  have hrsl : rs.length = core.slots.length :=
    (ssh_rd_facts key domain _ 2 hdrLen _ G τ hdr core ch rs hrd hgt hgeom acc t' hacc).1
  have hrs7 : 7 ≤ rs.length := by rw [hrsl, hslen, ← hP.2]; exact hsl
  have hmem : ∀ k, k < 7 → 0 < P0.draws k → k ∈ stgDrawing P0 := fun k hk hdk =>
    List.mem_filter.mpr ⟨List.mem_range.mpr (by omega), by simpa using hdk⟩
  have hd0 : 0 < P0.draws 0 := by rw [hP.1]; show 0 < (F b).pub.dBits; omega
  have hd2 : 0 < P0.draws 2 := by
    have h7 : P0.draws 2 = 7 := by rw [hP.1]; rfl
    omega
  have hd4' : 0 < P0.draws 4 := by rw [hP.1]; show 0 < (F b).pub.llo + 2 + 1; omega
  have hd5 : 0 < P0.draws 5 := by rw [hP.1]; show 0 < (F b).pub.ldo + 10 + 1; omega
  have hlen : ∀ k, k ≤ 7 → ((rs.take k).map Block.SlotRec.draws).length = k := fun k hk => by
    rw [List.length_map, List.length_take]; omega
  set w := stgVw absOf lg τ with hw
  have hzk : ∀ k, k ∈ stgDrawing P0 → ∀ y : Fin (P0.draws k) → K,
      stgΦB U hbij P0 (F b).bp
        (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH hdrLen (hdrLen + 4 + 2)
          (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w)
        (OutcV.bga ch) ((rs.take k).map Block.SlotRec.draws) k (stgWords U hbij y) = 0 := fun k hk =>
    shd_outc_zero_rdA U hbij key domain absOf tag h64 P0 F b n0 hdrLen ogStage.lc ogStage.h ogStage.Q ogStage.e 76 rH
      _ hIOl G lg τ hdr core ch rs hrd hP hgt hgeom hW k hk (hal k hk)
  -- the bounds (decision D5)
  have hlim7 := outc_limbs_le7 P hPv
  have hkN := outc_kN_bd P hPv
  -- OUTC-00
  have hio : ∀ c, (shdOutcData U tag h64 O hdrLen rX ipos (F b).pub.verdictRow w).pl 0 c
      = (shdOutcData U tag h64 O hdrLen rX ipos (F b).pub.verdictRow w).bout c := fun c =>
    (outc_io0_eq U hbij tag h64 hU O P0 (F b) hP ch 76 rH hdrLen (hdrLen + 4 + 2) rX ipos XO w hlt hIO hGb hOL hldo
      hdB hlift htB hbo hlc (hzk 0 (hmem 0 (by norm_num) hd0)) c).2
  -- OUTC-02 TZC
  obtain ⟨t1, t2, t3, t4⟩ := outc_tzc U hbij tag h64 hU O P0 (F b) hP ch 76 rH hdrLen (hdrLen + 4 + 2) _ w hlt
    ((rs.take 2).map Block.SlotRec.draws) (hlen 2 (by norm_num)) (hzk 2 (hmem 2 (by norm_num) hd2)) hGb hOL hldo hlc
    hOlt P hceps hPv.cepsa hPv.cepsb hdd hd4
  -- OUTC-05 DZC
  have hdz : ∀ (i : Fin d) (j : Fin 3), dzcCB P (shdOutcData U tag h64 O hdrLen rX ipos (F b).pub.verdictRow w)
      ((shdOutcData U tag h64 O hdrLen rX ipos (F b).pub.verdictRow w).D (fun _ => false)) j (msbBits 12 i.val) = 0 :=
    fun i j => outc_dzc_cb U hbij tag h64 hU O P0 (F b) hP ch hch 76 rH hdrLen (hdrLen + 4 + 2) _ w hlt
      ((rs.take 5).map Block.SlotRec.draws) (hlen 5 (by norm_num)) (hzk 5 (hmem 5 (by norm_num) hd5)) hGb hOL hldo hlc
      P hg0 hcn htn hkN hPv.tn _ (fun _ _ => rfl) _ rfl (msbBits 12 i.val)
      (by rw [msbIndex_msbBits 12 i.val (lt_of_lt_of_le (by omega : i.val < 4096) (by norm_num)), hdd]; exact i.isLt) j
  -- OUTC-04 LZC: the margin
  have hmar := outc_margin U hbij tag h64 hU O P0 (F b) hP ch hch 76 rH hdrLen (hdrLen + 4 + 2) _ w hlt
    ((rs.take 4).map Block.SlotRec.draws) (hlen 4 (by norm_num)) (hzk 4 (hmem 4 (by norm_num) hd4')) hGb hOL hllo hldo
    hdB hlift hdPad hlc P b hb hverd hcc hPv.c hlim hlim7 hdd hd4 hwl hwD hPv.w
  -- the bytes
  have hB := shd_outc_bytes_rd U tag h64 key domain absOf O hdrLen e (fun _ => (F b).bp) OutcV.bga G lg τ hdr core ch
    rs hrd hlk
  exact shd_outC_of_parts U tag h64 O hdrLen rX ipos (F b).pub.verdictRow w P b hd4 (by omega) hio
    ⟨t1, t2, t3, t4⟩ hdz hmar hB

end Sat

end ZK60.ProtocolClassify
