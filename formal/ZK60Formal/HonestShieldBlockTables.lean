/-
D63 lane L68c, part 2b-ii (`HonestShieldBlockTables.lean`):
Part 2 of the 3-file Shieldstral T128 R13 block completeness lane
(`HonestShieldBlockWitness.lean` → `HonestShieldBlockTables.lean` → `HonestShieldBlockArith.lean`).

Constructs the concrete Shieldstral T128 R13 block prover tables `(TA, TH, TM, TB)` directly on
`RunShieldBlkInst.lean` (`mRows = 50`, `shdP_slotKind` `.host` on `{2, 14, 15, 16, 17, 18}`) and
`HonestShieldBlockWitness.lean`, and proves:
1. **`BlkRand`, `blkAlphaBad`, `blkHUVal`:**
   - Prover randomness bundle `BlkRand`, pole check `blkAlphaBad` with `blkAlpha_ne_fold` and
     `blkLk_denom_ne_zero_of_alphaBad`, and zero-sum blinding plane `blkHUVal` (`blkHUVal_sum_re/im`).
2. **Shieldstral R13 layout offsets:**
   - Exact closed-form `A` and `H` plane offsets (`aOff_shield`, `hOff_shield`, `aDataRows_shield`,
     `hDataRows_shield`) and row decoder `shdHRowDecode` (`shdHRowDecode_re/im`), uniform across all 26 layers.
3. **Concrete tables (`blkTA`, `blkTH`, `blkTM`, `blkTB`):**
   - `4577 × 16384` `A` table, `4390 × 16384` `H` table, `S = 23` (`50`-row) `M` table, `38 × 16384` `B` table,
     with `rows_len`, `cols_len`, `cols_canon`, `ColsHonest`, `MHonest`, and `FullBndTableSpec` theorems.
4. **`blkCmData`, `blkCs`, `blkSlotPolyK`, `blkSlotData`, `blkCoreTables`, `shdP_blkTables`, `shdP_blkSegP_guarded`:**
   - Full `CmData` bridge (`blkCmData_base`, `blkCs_eq_claimSem`), unmasked slot polynomial `blkSlotPolyK`
     (`blkSlotPolyK_vecK_eq`, `blkSlotPolyK_eq_irEval`, `blkSlotPolyK_eq_polyS`, `blkSlotPolyK_indDeg`),
     and `blkAlphaBad`-guarded segment prover `shdP_blkSegP_guarded`.
5. **Universal `planeZ` / `aPl` / `hPl` evaluation & `xtR = w.E`:**
   - `planeZ_subrow_eq`, `planeZ_single_eq`, `planeZ_pair_eq`, exact evaluators for all 107 `A` planes,
     `plL` sub-slices, all 53 `H` planes, `blk_xtR_eq_E`, and `blk_AlkR13_eq_blkLkTup`.
6. **Zero-vanishing theorems for `BlockR13StmtHosts.formAt_hostsR` and standalone slots:**
   - `host_pair_eq_zero`, `host_single_eq_zero`, `blk_xcTzcR/DzcR/QzcR/KvzcR/SzcR/FzcR_eq_zero`, `blk_xcR_eq_zero`,
     `blk_pwDzcR/FzcR_eq_zero`, `blk_pwcR_eq_zero`, `blk_cLzcR/wLzcR_eq_zero`, `blk_cTabR/wTabR_eq_zero`,
     `blk_hU_sum_eq_zero`, `blk_ioIn_eq`, `blk_ioOut_eq`.
7. **LogUp sum-claim truth:**
   - `blk_logupSumClaim_true` (on `w : BlkWitness`) and `blk_logupSumClaim_true_of_spec`
     (with explicit `hAct0 : Pb.act 0 2048 = 0`).
-/
import ZK60Formal.HonestShieldBlockWitness
import ZK60Formal.BlockDefinePoly
import ZK60Formal.BlockR13StmtHosts
import ZK60Formal.BlockR13LookRelSzc

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound ZK60.TokenRun ZK60.StageX
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldS0 shieldShape)
open ZK60.Circuit (gP GF tagW tagExp tagAct)
open ZK60.Block (BlockPublic blockSpec i16)
open ZK60.Layout.R13 (R13Data)
open ZK60.Exec.Block (BlockParams Hist SlotDef Acc Claims4 Cm CmData Tab SlotRec Seen Segment SegGeom
  tupK polyS polyS_indDeg tabsK_indDeg histSeen drSeen)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Block.Join (castB planeZ privZ baseR lkRels padPls lkRels_length)
open ZK60.Exec.Block.Join.W16 (aPl piB piB_alg hPl cstK)
open ZK60.Exec.Block.Join.W16.Tab (tabTupE foldWd toK_foldWd gateTabW tabPadIx)
open ZK60.Exec.Block.Join.R13H (CtR CwR CgR CjR CdR CfR nD nH nQ nK nS nHt nF
  splitD splitQ splitK splitS splitF splitHt splitD_append splitQ_append splitK_append
  splitS_append splitHt_append splitF_append geoShield ids_eq_shield
  plT plD plQ plK plS plH plF plL offR xtR tauLen mpadR xcR pwcR)
open ZK60.Exec.Block.Join.R13H.Look (Dm Sg SgIx PrIx TbIx AlkR13 TR13 lookCfg_shield domList
  domList_length domList_getD domAt hDoms_eq fh_eq lkLen bLk lkLe lkDe lkQe lkKe lkSe lkFe
  lkTupR lkAtR expTupR actTupR sgTupR logupSumR13 logupSumR13_planes fR PSpR fR_dom toK_negOneR
  sum_sg sum_dm getD_appL getD_appR getD_mapRange)
open ZK60.Exec.Slot.W16R2 (Dom)
open ZK60.Exec.Slot.Build.Lay (LkW)

/-! ## 1. `BlkRand`, `blkAlphaBad`, and `blkHUVal` -/

section BlockRandAndGuards

/-- Prover blinding randomness for one Shieldstral R13 block (`A = 4577`, `H = 4390`, `M`: `S = 23`, `B = 38`). -/
structure BlkRand where
  aMask : Fin 292 → Fin 16384 → GF
  aProx : Fin 2 → Fin 16384 → GF
  aPads : Fin 4577 → Fin 256 → Fp
  aSalts : ℕ → Dig
  hMask : Fin 106 → Fin 16384 → GF
  hProx : Fin 2 → Fin 16384 → GF
  hURaw : Fin 16384 → GF × GF
  hPads : Fin 4390 → Fin 256 → Fp
  hSalts : ℕ → Dig
  mA : Fin 23 → Fin 512 → Fp2
  mBRe : Fin 1024 → GF
  mBIm : Fin 1024 → GF
  mURe : Fin 1024 → GF
  mUIm : Fin 1024 → GF
  mSalts : ℕ → Dig
  bnd : BndRand

/-- Active entry count of `SC_TAB` table `k` (`256` on U8/EXP, `nG * 4096` on ACT). -/
def blkTabActiveLen (nG k : ℕ) : ℕ :=
  if k < 2 then 256 else nG * 4096

/-- Computable pole guard: `true` iff `α` hits any active folded `SC_TAB` entry `fold(β, γ, T_k[i])`. -/
def blkAlphaBad (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) (bga : Fp2 × Fp2 × Fp2) : Bool :=
  (List.range 3).any fun k =>
    (List.range (blkTabActiveLen Ly.nG k)).any fun i =>
      (bga.2.2.sub (foldWd bga.1 bga.2.1 (tabTupE Pb.exp Pb.act Ly.nG k i))).isZero

/-- When `blkAlphaBad Ly Pb bga = false` and `α` is canonical, every active table entry has `α - fold(β, γ, T) ≠ 0`. -/
theorem blkAlpha_ne_fold (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (j : TbIx) (hj : tabActive Ly.nG j) :
    bga.2.2.toK shdP_U - fold (bga.1.toK shdP_U) (bga.2.1.toK shdP_U) (TR13 Pb.exp Pb.act Ly.nG j) ≠ 0 := by
  intro hEq
  let u : Tup GF := tabTupE Pb.exp Pb.act Ly.nG j.1.val (msbIndex 14 j.2)
  have hcanF : (foldWd bga.1 bga.2.1 u).Canon := Fp2.canon_add _ _
  have hsub0 : (bga.2.2.sub (foldWd bga.1 bga.2.1 u)).toK shdP_U = 0 := by
    rw [Fp2.toK_sub shdP_U _ _ hα hcanF, toK_foldWd shdP_U shdP_hU]
    exact hEq
  have hsubZ : (bga.2.2.sub (foldWd bga.1 bga.2.1 u)).isZero = true :=
    (isZero_iff_toK shdP_U shdP_hU _ (Fp2.canon_sub _ _ hα hcanF)).mpr hsub0
  have hiLt : msbIndex 14 j.2 < blkTabActiveLen Ly.nG j.1.val := by
    unfold tabActive at hj
    unfold blkTabActiveLen
    by_cases h2 : j.1.val < 2
    · rw [ite_eq_left h2] at hj ⊢; exact hj
    · rw [ite_eq_right h2] at hj ⊢; exact hj
  have hanyInner : ((List.range (blkTabActiveLen Ly.nG j.1.val)).any fun i =>
      (bga.2.2.sub (foldWd bga.1 bga.2.1 (tabTupE Pb.exp Pb.act Ly.nG j.1.val i))).isZero) = true :=
    List.any_eq_true.mpr ⟨msbIndex 14 j.2, List.mem_range.mpr hiLt, hsubZ⟩
  have hany : blkAlphaBad Ly Pb bga = true :=
    List.any_eq_true.mpr ⟨j.1.val, List.mem_range.mpr j.1.isLt, hanyInner⟩
  rw [hany] at hbad
  cases hbad

/-- Non-pole propagation from `blkAlphaBad = false` to all `66,879,488` R13 lookups `l : BlkLkIx Ly`. -/
theorem blkLk_denom_ne_zero_of_alphaBad {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut)
    (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (l : BlkLkIx Ly) :
    bga.2.2.toK shdP_U - fold (bga.1.toK shdP_U) (bga.2.1.toK shdP_U) (tupK (blkLkTup w l)) ≠ 0 :=
  blkLk_denom_ne_zero w (bga.1.toK shdP_U) (bga.2.1.toK shdP_U) (bga.2.2.toK shdP_U)
    (blkAlpha_ne_fold Ly Pb bga hα hbad) l

/-- Zero-sum blinding helper `H_U` (`col = 0` set to `-∑_{j=1}^{16383} rnd.hURaw j`). -/
def blkHUVal (rnd : BlkRand) (col : Fin 16384) : GF × GF :=
  if col.val = 0 then
    (- ∑ j : Fin 16383, (rnd.hURaw ⟨j.val + 1, by omega⟩).1,
     - ∑ j : Fin 16383, (rnd.hURaw ⟨j.val + 1, by omega⟩).2)
  else
    rnd.hURaw col

theorem blkHUVal_sum_re (rnd : BlkRand) : ∑ col : Fin 16384, (blkHUVal rnd col).1 = 0 := by
  rw [Fin.sum_univ_succ]
  have h0 : (blkHUVal rnd 0).1 = - ∑ j : Fin 16383, (rnd.hURaw ⟨j.val + 1, by omega⟩).1 := by
    unfold blkHUVal; rw [ite_eq_left (show ((0 : Fin 16384) : ℕ) = 0 from rfl)]
  have hs : ∀ j : Fin 16383, (blkHUVal rnd j.succ).1 = (rnd.hURaw ⟨j.val + 1, by omega⟩).1 := fun j => by
    unfold blkHUVal
    rw [ite_eq_right (by rw [Fin.val_succ]; omega)]
    rfl
  simp_rw [hs]
  rw [h0, neg_add_cancel]

theorem blkHUVal_sum_im (rnd : BlkRand) : ∑ col : Fin 16384, (blkHUVal rnd col).2 = 0 := by
  rw [Fin.sum_univ_succ]
  have h0 : (blkHUVal rnd 0).2 = - ∑ j : Fin 16383, (rnd.hURaw ⟨j.val + 1, by omega⟩).2 := by
    unfold blkHUVal; rw [ite_eq_left (show ((0 : Fin 16384) : ℕ) = 0 from rfl)]
  have hs : ∀ j : Fin 16383, (blkHUVal rnd j.succ).2 = (rnd.hURaw ⟨j.val + 1, by omega⟩).2 := fun j => by
    unfold blkHUVal
    rw [ite_eq_right (by rw [Fin.val_succ]; omega)]
    rfl
  simp_rw [hs]
  rw [h0, neg_add_cancel]

end BlockRandAndGuards

/-! ## 2. Shieldstral R13 Layout Offsets (`aOff_shield`, `hOff_shield`, `shdHRowDecode`) -/

section ShieldLayoutOffsets

/-- Number of `2^14`-wide rows per plane of each domain at Shieldstral T128 R13. -/
def shdRowsOfDom : Dom → ℕ
  | .T => 1 | .Ht => 1 | .L => 1 | .D => 32 | .Q => 32 | .Kv => 8 | .S => 32 | .F => 128 | .Tab => 1

/-- First `A`-plane id of each domain at Shieldstral T128 R13 (`idsR13 true 2`). -/
def shdDomStart : Dom → ℕ
  | .T => 0 | .Ht => 4 | .L => 6 | .D => 8 | .Q => 47 | .Kv => 61 | .S => 75 | .F => 88 | .Tab => 104

/-- Exclusive upper bound of `A`-plane ids of each domain at Shieldstral T128 R13. -/
def shdDomEnd : Dom → ℕ
  | .T => 4 | .Ht => 6 | .L => 8 | .D => 47 | .Q => 61 | .Kv => 75 | .S => 88 | .F => 104 | .Tab => 107

/-- First row in `TA` of each domain at Shieldstral T128 R13. -/
def shdDomRow : Dom → ℕ
  | .T => 0 | .Ht => 4 | .L => 6 | .D => 8 | .Q => 1256 | .Kv => 1704 | .S => 1816 | .F => 2232 | .Tab => 4280

/-- Domain of `A`-plane id `q` at Shieldstral T128 R13. -/
def shdPlaneDom (q : ℕ) : Dom :=
  if q < 4 then .T else if q < 6 then .Ht else if q < 8 then .L else if q < 47 then .D
  else if q < 61 then .Q else if q < 75 then .Kv else if q < 88 then .S else if q < 104 then .F else .Tab

/-- First row in `TA` of `A`-plane `q`. -/
def shdARow (q : ℕ) : ℕ :=
  shdDomRow (shdPlaneDom q) + (q - shdDomStart (shdPlaneDom q)) * shdRowsOfDom (shdPlaneDom q)

theorem rowsOf_shield (Ly : ShieldLayer) (d : Dom) :
    Exec.Block.DefW16.rowsOf (Exec.Block.DefR13.cfgShieldR13 Ly) d = shdRowsOfDom d := by
  unfold Exec.Block.DefW16.rowsOf Exec.Block.DefR13.cfgShieldR13
  dsimp only
  cases d <;> decide

theorem domStart_shield (Ly : ShieldLayer) (d : Dom) :
    Exec.Block.DefR13.domStart (Exec.Block.DefR13.cfgShieldR13 Ly) d = shdDomStart d := by
  unfold Exec.Block.DefR13.domStart
  rw [ids_eq_shield Ly]
  cases d <;> rfl

theorem domEnd_shield (Ly : ShieldLayer) (d : Dom) :
    Exec.Block.DefR13.domEnd (Exec.Block.DefR13.cfgShieldR13 Ly) d = shdDomEnd d := by
  unfold Exec.Block.DefR13.domEnd
  rw [ids_eq_shield Ly]
  cases d <;> rfl

theorem domRow_shield (Ly : ShieldLayer) (d : Dom) :
    Exec.Block.DefR13.domRow (Exec.Block.DefR13.cfgShieldR13 Ly) d = shdDomRow d := by
  unfold Exec.Block.DefR13.domRow
  simp only [domEnd_shield, domStart_shield, rowsOf_shield]
  cases d <;> decide

theorem aDataRows_shield (Ly : ShieldLayer) :
    Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 Ly) = 4283 := by
  unfold Exec.Block.DefR13.aDataRows
  simp only [domEnd_shield, domStart_shield, rowsOf_shield]
  decide

theorem planeDom_shield (Ly : ShieldLayer) (q : ℕ) :
    Exec.Block.DefR13.planeDom (Exec.Block.DefR13.cfgShieldR13 Ly) q = shdPlaneDom q := by
  unfold Exec.Block.DefR13.planeDom Exec.Block.DefW16.allDoms shdPlaneDom
  simp only [domEnd_shield]
  by_cases h1 : q < 4
  · simp [shdDomEnd, h1]
  · by_cases h2 : q < 6
    · simp [shdDomEnd, h1, h2]
    · by_cases h3 : q < 8
      · simp [shdDomEnd, h1, h2, h3]
      · by_cases h4 : q < 47
        · simp [shdDomEnd, h1, h2, h3, h4]
        · by_cases h5 : q < 61
          · simp [shdDomEnd, h1, h2, h3, h4, h5]
          · by_cases h6 : q < 75
            · simp [shdDomEnd, h1, h2, h3, h4, h5, h6]
            · by_cases h7 : q < 88
              · simp [shdDomEnd, h1, h2, h3, h4, h5, h6, h7]
              · by_cases h8 : q < 104
                · simp [shdDomEnd, h1, h2, h3, h4, h5, h6, h7, h8]
                · by_cases h9 : q < 107 <;> simp [shdDomEnd, h1, h2, h3, h4, h5, h6, h7, h8, h9]

/-- Exact closed-form `A`-plane offset across all 107 planes of every Shieldstral R13 layer. -/
theorem aOff_shield (Ly : ShieldLayer) (q : ℕ) :
    Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) q = shdARow q * 2 ^ 14 := by
  unfold Exec.Block.DefR13.aOff shdARow
  rw [planeDom_shield, domRow_shield, domStart_shield, rowsOf_shield]
  rfl

/-- First row of the real half of `H` plane `hp` (`0..52`) in `TH`. -/
def shdHReRow (hp : ℕ) : ℕ :=
  if hp < 1 then 0
  else if hp < 18 then 2 + (hp - 1) * 64
  else if hp < 25 then 1090 + (hp - 18) * 64
  else if hp < 32 then 1538 + (hp - 25) * 16
  else if hp < 41 then 1650 + (hp - 32) * 64
  else if hp < 49 then 2226 + (hp - 41) * 256
  else if hp < 53 then 4274 + (hp - 49) * 2
  else 4282

/-- Number of rows in each half (real / imaginary) of `H` plane `hp`. -/
def shdHRowsHalf (hp : ℕ) : ℕ := shdRowsOfDom (domAt 1 hp)

/-- Log size of `H` plane `hp` (`14, 17, 19,` or `21`). -/
def shdHLog (hp : ℕ) : ℕ := Exec.Slot.R13.shShieldR13.logs (domAt 1 hp)

theorem shdHLog_ge14 (hp : ℕ) : 14 ≤ shdHLog hp := by
  unfold shdHLog domAt
  split_ifs <;> decide

theorem shdHRowsHalf_eq_pow (hp : ℕ) : shdHRowsHalf hp = 2 ^ (shdHLog hp - 14) := by
  unfold shdHRowsHalf shdHLog domAt
  split_ifs <;> decide

private theorem shdHReRow_sum (hp : ℕ) :
    (((domList 1).take hp).map fun d => 2 * shdRowsOfDom d).sum = shdHReRow hp := by
  by_cases h53 : hp < 53
  · have hall : ∀ i : Fin 53,
        (((domList 1).take i.val).map fun d => 2 * shdRowsOfDom d).sum = shdHReRow i.val := by decide +kernel
    exact hall ⟨hp, h53⟩
  · have htake : (domList 1).take hp = domList 1 :=
      List.take_of_length_le (by rw [domList_length]; omega)
    rw [htake]
    have hfull : ((domList 1).map fun d => 2 * shdRowsOfDom d).sum = 4282 := by decide +kernel
    rw [hfull]
    unfold shdHReRow
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega)]

theorem hDataRows_shield (Ly : ShieldLayer) :
    Exec.Block.DefR13.hDataRows (Exec.Block.DefR13.cfgShieldR13 Ly) = 4282 := by
  unfold Exec.Block.DefR13.hDataRows
  rw [hDoms_eq (lookCfg_shield Ly)]
  simp only [rowsOf_shield]
  decide +kernel

/-- Exact closed-form `H`-plane real/imaginary offsets across all 53 `H` planes of every Shieldstral layer. -/
theorem hOff_shield (Ly : ShieldLayer) (hp : ℕ) :
    Exec.Block.DefR13.hOff (Exec.Block.DefR13.cfgShieldR13 Ly) hp
      = (shdHReRow hp * 2 ^ 14, (shdHReRow hp + shdHRowsHalf hp) * 2 ^ 14) := by
  unfold Exec.Block.DefR13.hOff
  rw [hDoms_eq (lookCfg_shield Ly)]
  simp only [rowsOf_shield, domList_getD, shdHReRow_sum]
  rfl

/-- Decode any `TH` data row `r < 4282` into `(hp, isImag, dr)` where `dr < shdHRowsHalf hp`. -/
def shdHRowDecode (r : ℕ) : ℕ × Bool × ℕ :=
  if r < 2 then (0, decide (1 ≤ r), 0)
  else if r < 1090 then
    let off := r - 2
    (1 + off / 64, decide (32 ≤ off % 64), (off % 64) % 32)
  else if r < 1538 then
    let off := r - 1090
    (18 + off / 64, decide (32 ≤ off % 64), (off % 64) % 32)
  else if r < 1650 then
    let off := r - 1538
    (25 + off / 16, decide (8 ≤ off % 16), (off % 16) % 8)
  else if r < 2226 then
    let off := r - 1650
    (32 + off / 64, decide (32 ≤ off % 64), (off % 64) % 32)
  else if r < 4274 then
    let off := r - 2226
    (41 + off / 256, decide (128 ≤ off % 256), (off % 256) % 128)
  else
    let off := r - 4274
    (49 + off / 2, decide (1 ≤ off % 2), 0)

theorem shdHReRow_bounds (hp : ℕ) (hhp : hp < 53) :
    shdHReRow hp + 2 * shdHRowsHalf hp ≤ 4282 := by
  unfold shdHReRow shdHRowsHalf domAt
  rw [show (40 : ℕ) + 1 = 41 from rfl, show (48 : ℕ) + 1 = 49 from rfl]
  by_cases h1 : hp < 1
  · simp only [h1, ↓reduceIte, shdRowsOfDom]; omega
  · by_cases h2 : hp < 18
    · simp only [h1, h2, ↓reduceIte, shdRowsOfDom]; omega
    · by_cases h3 : hp < 25
      · simp only [h1, h2, h3, ↓reduceIte, shdRowsOfDom]; omega
      · by_cases h4 : hp < 32
        · simp only [h1, h2, h3, h4, ↓reduceIte, shdRowsOfDom]; omega
        · by_cases h5 : hp < 41
          · simp only [h1, h2, h3, h4, h5, ↓reduceIte, shdRowsOfDom]; omega
          · by_cases h6 : hp < 49
            · simp only [h1, h2, h3, h4, h5, h6, ↓reduceIte, shdRowsOfDom]; omega
            · simp only [h1, h2, h3, h4, h5, h6, hhp, ↓reduceIte, shdRowsOfDom]; omega

theorem shdHRowDecode_re (hp dr : ℕ) (hhp : hp < 53) (hdr : dr < shdHRowsHalf hp) :
    shdHReRow hp + dr < 4282 ∧ shdHRowDecode (shdHReRow hp + dr) = (hp, false, dr) := by
  have hbd : shdHReRow hp + dr < 4282 := by have := shdHReRow_bounds hp hhp; omega
  refine ⟨hbd, ?_⟩
  unfold shdHReRow
  unfold shdHRowsHalf domAt at hdr
  rw [show (40 : ℕ) + 1 = 41 from rfl, show (48 : ℕ) + 1 = 49 from rfl] at hdr
  unfold shdHRowDecode
  by_cases h1 : hp < 1
  · simp only [h1, ↓reduceIte, shdRowsOfDom] at hdr ⊢
    rw [ite_eq_left (by omega)]
    simp only [Prod.mk.injEq]
    exact ⟨by omega, decide_eq_false (by omega), by omega⟩
  · by_cases h2 : hp < 18
    · simp only [h1, h2, ↓reduceIte, shdRowsOfDom] at hdr ⊢
      rw [ite_eq_right (by omega), ite_eq_left (by omega)]
      simp only [Prod.mk.injEq]
      exact ⟨by omega, decide_eq_false (by omega), by omega⟩
    · by_cases h3 : hp < 25
      · simp only [h1, h2, h3, ↓reduceIte, shdRowsOfDom] at hdr ⊢
        rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
        simp only [Prod.mk.injEq]
        exact ⟨by omega, decide_eq_false (by omega), by omega⟩
      · by_cases h4 : hp < 32
        · simp only [h1, h2, h3, h4, ↓reduceIte, shdRowsOfDom] at hdr ⊢
          rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
          simp only [Prod.mk.injEq]
          exact ⟨by omega, decide_eq_false (by omega), by omega⟩
        · by_cases h5 : hp < 41
          · simp only [h1, h2, h3, h4, h5, ↓reduceIte, shdRowsOfDom] at hdr ⊢
            rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
              ite_eq_right (by omega), ite_eq_left (by omega)]
            simp only [Prod.mk.injEq]
            exact ⟨by omega, decide_eq_false (by omega), by omega⟩
          · by_cases h6 : hp < 49
            · simp only [h1, h2, h3, h4, h5, h6, ↓reduceIte, shdRowsOfDom] at hdr ⊢
              rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
                ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
              simp only [Prod.mk.injEq]
              exact ⟨by omega, decide_eq_false (by omega), by omega⟩
            · simp only [h1, h2, h3, h4, h5, h6, hhp, ↓reduceIte, shdRowsOfDom] at hdr ⊢
              rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
                ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega)]
              simp only [Prod.mk.injEq]
              exact ⟨by omega, decide_eq_false (by omega), by omega⟩

theorem shdHRowDecode_im (hp dr : ℕ) (hhp : hp < 53) (hdr : dr < shdHRowsHalf hp) :
    shdHReRow hp + shdHRowsHalf hp + dr < 4282
      ∧ shdHRowDecode (shdHReRow hp + shdHRowsHalf hp + dr) = (hp, true, dr) := by
  have hbd : shdHReRow hp + shdHRowsHalf hp + dr < 4282 := by have := shdHReRow_bounds hp hhp; omega
  refine ⟨hbd, ?_⟩
  unfold shdHReRow shdHRowsHalf domAt
  unfold shdHRowsHalf domAt at hdr
  rw [show (40 : ℕ) + 1 = 41 from rfl, show (48 : ℕ) + 1 = 49 from rfl] at hdr ⊢
  unfold shdHRowDecode
  by_cases h1 : hp < 1
  · simp only [h1, ↓reduceIte, shdRowsOfDom] at hdr ⊢
    rw [ite_eq_left (by omega)]
    simp only [Prod.mk.injEq]
    exact ⟨by omega, decide_eq_true (by omega), by omega⟩
  · by_cases h2 : hp < 18
    · simp only [h1, h2, ↓reduceIte, shdRowsOfDom] at hdr ⊢
      rw [ite_eq_right (by omega), ite_eq_left (by omega)]
      simp only [Prod.mk.injEq]
      exact ⟨by omega, decide_eq_true (by omega), by omega⟩
    · by_cases h3 : hp < 25
      · simp only [h1, h2, h3, ↓reduceIte, shdRowsOfDom] at hdr ⊢
        rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
        simp only [Prod.mk.injEq]
        exact ⟨by omega, decide_eq_true (by omega), by omega⟩
      · by_cases h4 : hp < 32
        · simp only [h1, h2, h3, h4, ↓reduceIte, shdRowsOfDom] at hdr ⊢
          rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
          simp only [Prod.mk.injEq]
          exact ⟨by omega, decide_eq_true (by omega), by omega⟩
        · by_cases h5 : hp < 41
          · simp only [h1, h2, h3, h4, h5, ↓reduceIte, shdRowsOfDom] at hdr ⊢
            rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
              ite_eq_right (by omega), ite_eq_left (by omega)]
            simp only [Prod.mk.injEq]
            exact ⟨by omega, decide_eq_true (by omega), by omega⟩
          · by_cases h6 : hp < 49
            · simp only [h1, h2, h3, h4, h5, h6, ↓reduceIte, shdRowsOfDom] at hdr ⊢
              rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
                ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
              simp only [Prod.mk.injEq]
              exact ⟨by omega, decide_eq_true (by omega), by omega⟩
            · simp only [h1, h2, h3, h4, h5, h6, hhp, ↓reduceIte, shdRowsOfDom] at hdr ⊢
              rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
                ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega)]
              simp only [Prod.mk.injEq]
              exact ⟨by omega, decide_eq_true (by omega), by omega⟩

end ShieldLayoutOffsets

/-! ## 3. Concrete Honest Block Tables (`blkTA`, `blkTH`, `blkTM`, `blkTB`) -/

section ConcreteBlockTables

/-- Base-field data entries of `TA` (`4577 × 16384`) for Shieldstral T128 R13. -/
noncomputable def blkTAData {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand) :
    Fin 4577 → Fin 16384 → Fp :=
  fun r col =>
    if r.val = 0 then
      if col.val < 128 then Fp.ofGF (w.E.dA (msbBits 7 col.val)) else Fp.zero
    else if r.val = 1 then
      if col.val < 128 then Fp.ofGF (w.E.dsqA (msbBits 7 col.val)) else Fp.zero
    else if r.val = 2 then
      if col.val < 128 then Fp.ofGF (w.E.dM (msbBits 7 col.val)) else Fp.zero
    else if r.val = 3 then
      if col.val < 128 then Fp.ofGF (w.E.dsqM (msbBits 7 col.val)) else Fp.zero
    else if r.val = 4 then
      if col.val < 4096 then Fp.ofGF (w.E.MX (splitHt (Exec.Block.DefR13.cfgShieldR13 Ly) (msbBits 12 col.val))) else Fp.zero
    else if r.val = 5 then
      if col.val < 4096 then Fp.ofGF (w.E.SUM (splitHt (Exec.Block.DefR13.cfgShieldR13 Ly) (msbBits 12 col.val))) else Fp.zero
    else if r.val = 6 then
      Fp.ofGF (w.limbA (msbBits 14 col.val))
    else if r.val = 7 then
      Fp.ofGF (w.limbM (msbBits 14 col.val))
    else if r.val < 1256 then
      let q := 8 + (r.val - 8) / 32
      let idx := ((r.val - 8) % 32) * 16384 + col.val
      Fp.ofGF (blkDomPlane w .D q (msbBits 19 idx))
    else if r.val < 1704 then
      let q := 47 + (r.val - 1256) / 32
      let idx := ((r.val - 1256) % 32) * 16384 + col.val
      Fp.ofGF (blkDomPlane w .Q q (msbBits 19 idx))
    else if r.val < 1816 then
      let q := 61 + (r.val - 1704) / 8
      let idx := ((r.val - 1704) % 8) * 16384 + col.val
      Fp.ofGF (blkDomPlane w .Kv q (msbBits 17 idx))
    else if r.val < 2232 then
      let q := 75 + (r.val - 1816) / 32
      let idx := ((r.val - 1816) % 32) * 16384 + col.val
      Fp.ofGF (blkDomPlane w .S q (msbBits 19 idx))
    else if r.val < 4280 then
      let q := 88 + (r.val - 2232) / 128
      let idx := ((r.val - 2232) % 128) * 16384 + col.val
      Fp.ofGF (blkDomPlane w .F q (msbBits 21 idx))
    else if r.val = 4280 then
      Fp.ofGF (blkMultU8 w col : GF)
    else if r.val = 4281 then
      Fp.ofGF (blkMultExp w col : GF)
    else if r.val = 4282 then
      Fp.ofGF (blkMultAct w col : GF)
    else if hm : r.val < 4575 then
      Fp.ofGF (rnd.aMask ⟨r.val - 4283, by omega⟩ col)
    else
      Fp.ofGF (rnd.aProx ⟨r.val - 4575, by omega⟩ col)

/-- Honest `TA` PCS table (`4577` rows, `logN = 14`, `lr = 2`, `q = 256`). -/
noncomputable def blkTA {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand) : Table :=
  mkPcsTable 14 2 256 (by norm_num) (mkRows 4577 16384 256 (blkTAData w rnd) rnd.aPads) rnd.aSalts

/-- LogUp inverse term `(α - fold(β, γ, tupK u))⁻¹` in `shdP_K`. -/
noncomputable def blkInvK (bga : Fp2 × Fp2 × Fp2) (u : Tup GF) : shdP_K :=
  (bga.2.2.toK shdP_U - fold (bga.1.toK shdP_U) (bga.2.1.toK shdP_U) (tupK u))⁻¹

/-- Field value of `H` plane `hp ∈ 0..52` at flat cube index `idx`. -/
noncomputable def blkHValK {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand)
    (bga : Fp2 × Fp2 × Fp2) (hp idx : ℕ) : shdP_K :=
  if hp < 1 then
    let b := msbBits 14 idx
    blkInvK bga (blkLkAtGF w .L 0 b) + blkInvK bga (blkLkAtGF w .L 1 b)
  else if hp < 18 then
    let j := hp - 1
    let b := msbBits 19 idx
    blkInvK bga (blkLkAtGF w .D (2 * j) b) + blkInvK bga (blkLkAtGF w .D (2 * j + 1) b)
  else if hp < 25 then
    let j := hp - 18
    let b := msbBits 19 idx
    blkInvK bga (blkLkAtGF w .Q (2 * j) b) + blkInvK bga (blkLkAtGF w .Q (2 * j + 1) b)
  else if hp < 32 then
    let j := hp - 25
    let b := msbBits 17 idx
    blkInvK bga (blkLkAtGF w .Kv (2 * j) b) + blkInvK bga (blkLkAtGF w .Kv (2 * j + 1) b)
  else if hp < 39 then
    let j := hp - 32
    let b := msbBits 19 idx
    blkInvK bga (blkLkAtGF w .S (2 * j) b) + blkInvK bga (blkLkAtGF w .S (2 * j + 1) b)
  else if hp = 39 then
    blkInvK bga (blkSgTupGF w .S (msbBits 19 idx))
  else if hp = 40 then
    blkInvK bga (blkSgTupGF w .Exp (msbBits 19 idx))
  else if hp < 48 then
    let j := hp - 41
    let b := msbBits 21 idx
    blkInvK bga (blkLkAtGF w .F (2 * j) b) + blkInvK bga (blkLkAtGF w .F (2 * j + 1) b)
  else if hp = 48 then
    blkInvK bga (blkSgTupGF w .Act (msbBits 21 idx))
  else if h52 : hp < 52 then
    (blkMult w (⟨hp - 49, by omega⟩, msbBits 14 idx) : shdP_K) * blkInvK bga (tabTupE Pb.exp Pb.act Ly.nG (hp - 49) idx)
  else if hp = 52 then
    let hu := blkHUVal rnd ⟨idx % 16384, Nat.mod_lt idx (by norm_num)⟩
    algebraMap GF shdP_K hu.1 + shdP_U * algebraMap GF shdP_K hu.2
  else 0

/-- Base-field data entries of `TH` (`4390 × 16384`) at LogUp challenges `bga = (β, γ, α)`. -/
noncomputable def blkTHData {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand)
    (bga : Fp2 × Fp2 × Fp2) : Fin 4390 → Fin 16384 → Fp :=
  fun r col =>
    if r.val < 4282 then
      let dec := shdHRowDecode r.val
      let v := ofK shdP_U shdP_hbij (blkHValK w rnd bga dec.1 (dec.2.2 * 16384 + col.val))
      if dec.2.1 then v.c1 else v.c0
    else if hm : r.val < 4388 then
      Fp.ofGF (rnd.hMask ⟨r.val - 4282, by omega⟩ col)
    else
      Fp.ofGF (rnd.hProx ⟨r.val - 4388, by omega⟩ col)

/-- Honest `TH` PCS table (`4390` rows, `logN = 14`, `lr = 2`, `q = 256`). -/
noncomputable def blkTH {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand)
    (bga : Fp2 × Fp2 × Fp2) : Table :=
  mkPcsTable 14 2 256 (by norm_num) (mkRows 4390 16384 256 (blkTHData w rnd bga) rnd.hPads) rnd.hSalts

/-- Honest `TM` mask table (`S = 23`, `50 = 2 * 23 + 4` rows) via shared `mkMTable`. -/
noncomputable def blkTM (rnd : BlkRand) : MTable :=
  mkMTable 23 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts

/-- Honest boundary table `TB` (`38` rows, `logN = 14`, `lr = 2`, `q = 256`). -/
noncomputable def blkTB (y : shieldS0.Pos → ℤ) (hy : ∀ p, i16 (y p)) (rnd : BlkRand) : Table :=
  shdP_blkBndTable y hy rnd.bnd

/-! ### Row-length, column-shape, canonicity, `ColsHonest`, `MHonest`, and `FullBndTableSpec` lemmas -/

theorem blkTA_rows_len {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand) :
    (blkTA w rnd).rows.length = 4577 := by
  unfold blkTA mkPcsTable; dsimp only
  exact mkRows_length 4577 16384 256 (blkTAData w rnd) rnd.aPads

theorem tabMat_blkTA {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand)
    (i : Fin 4577) (t : Fin (2 ^ 14 + 0)) :
    tabMat (K := shdP_K) 4577 14 (blkTA w rnd).rows i t =
      algebraMap GF shdP_K (blkTAData w rnd i ⟨t.val, by omega⟩).toGF := by
  unfold blkTA mkPcsTable; dsimp only
  exact tabMat_mkRows 4577 14 256 (blkTAData w rnd) rnd.aPads i t

theorem blkTA_cols_len {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand) (j : ℕ) :
    ((blkTA w rnd).cols j).length = (blkTA w rnd).rows.length :=
  mkPcsTable_cols_length 14 2 256 (by norm_num) _ _ j

theorem blkTA_cols_canon {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand) :
    ∀ j, ∀ x ∈ (blkTA w rnd).cols j, x.Canon :=
  mkPcsTable_cols_canon 14 2 256 (by norm_num) _ _

theorem blkTA_colsHonest {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand) :
    ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) (blkTA w rnd) := by
  have h := mkPcsTable_colsHonest shdP_U 14 2 256 (by norm_num)
    (mkRows 4577 16384 256 (blkTAData w rnd) rnd.aPads) rnd.aSalts
  rwa [show (2 : ℕ) ^ 14 * 2 ^ 2 = 2 ^ 16 by norm_num] at h

theorem blkTH_rows_len {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand)
    (bga : Fp2 × Fp2 × Fp2) :
    (blkTH w rnd bga).rows.length = 4390 := by
  unfold blkTH mkPcsTable; dsimp only
  exact mkRows_length 4390 16384 256 (blkTHData w rnd bga) rnd.hPads

theorem tabMat_blkTH {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand)
    (bga : Fp2 × Fp2 × Fp2) (i : Fin 4390) (t : Fin (2 ^ 14 + 0)) :
    tabMat (K := shdP_K) 4390 14 (blkTH w rnd bga).rows i t =
      algebraMap GF shdP_K (blkTHData w rnd bga i ⟨t.val, by omega⟩).toGF := by
  unfold blkTH mkPcsTable; dsimp only
  exact tabMat_mkRows 4390 14 256 (blkTHData w rnd bga) rnd.hPads i t

theorem blkTH_cols_len {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand)
    (bga : Fp2 × Fp2 × Fp2) (j : ℕ) :
    ((blkTH w rnd bga).cols j).length = (blkTH w rnd bga).rows.length :=
  mkPcsTable_cols_length 14 2 256 (by norm_num) _ _ j

theorem blkTH_cols_canon {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand)
    (bga : Fp2 × Fp2 × Fp2) :
    ∀ j, ∀ x ∈ (blkTH w rnd bga).cols j, x.Canon :=
  mkPcsTable_cols_canon 14 2 256 (by norm_num) _ _

theorem blkTH_colsHonest {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand)
    (bga : Fp2 × Fp2 × Fp2) :
    ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) (blkTH w rnd bga) := by
  have h := mkPcsTable_colsHonest shdP_U 14 2 256 (by norm_num)
    (mkRows 4390 16384 256 (blkTHData w rnd bga) rnd.hPads) rnd.hSalts
  rwa [show (2 : ℕ) ^ 14 * 2 ^ 2 = 2 ^ 16 by norm_num] at h

theorem blkTM_honest (rnd : BlkRand) :
    MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) (blkTM rnd) 23 :=
  mkMTable_honest 23 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts

theorem blkTB_spec (y : shieldS0.Pos → ℤ) (hy : ∀ p, i16 (y p)) (rnd : BlkRand) :
    FullBndTableSpec y (blkTB y hy rnd) :=
  shdP_blkBndTable_spec y hy rnd.bnd

theorem blkTB_rows_len (y : shieldS0.Pos → ℤ) (hy : ∀ p, i16 (y p)) (rnd : BlkRand) :
    (blkTB y hy rnd).rows.length = 38 :=
  (blkTB_spec y hy rnd).rows_len

theorem blkTB_cols_len (y : shieldS0.Pos → ℤ) (hy : ∀ p, i16 (y p)) (rnd : BlkRand) (j : ℕ) :
    ((blkTB y hy rnd).cols j).length = (blkTB y hy rnd).rows.length := by
  rw [(blkTB_spec y hy rnd).rows_len]
  exact (blkTB_spec y hy rnd).cols_len j

theorem blkTB_cols_canon (y : shieldS0.Pos → ℤ) (hy : ∀ p, i16 (y p)) (rnd : BlkRand) :
    ∀ j, ∀ x ∈ (blkTB y hy rnd).cols j, x.Canon :=
  (blkTB_spec y hy rnd).cols_canon

theorem blkTB_colsHonest (y : shieldS0.Pos → ℤ) (hy : ∀ p, i16 (y p)) (rnd : BlkRand) :
    ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) (blkTB y hy rnd) :=
  (blkTB_spec y hy rnd).cols_honest

end ConcreteBlockTables

/-! ## 4. `blkCmData`, `blkCs`, `blkSlotPolyK`, `blkSlotData`, `blkCoreTables`, `shdP_blkSegP_guarded` -/

section BlockSlotAndCmData

theorem blkRowLog_eq (P : BlockParams) (hlc : P.logCols = 14) (hep : P.endpointLogN = 14) (cm : Cm) :
    Block.rowLog P cm = 14 := by
  cases cm with
  | a | h => exact hlc
  | inp | out => exact hep

/-- `CmData shdP_K P` backed by the honest tables `(TA, TH, TB_prev, TB_next)` with `Q = 0`. -/
noncomputable def blkCmData (P : BlockParams) (hlc : P.logCols = 14) (hep : P.endpointLogN = 14)
    (TA TH TB_prev TB_next : Table) : CmData shdP_K P where
  rows := shdP_rowsOf
  Q := fun _ => 0
  X := fun cm =>
    match cm with
    | .a => fun i t => tabMat 4577 14 TA.rows i (Fin.cast (by rw [blkRowLog_eq P hlc hep .a]) t)
    | .h => fun i t => tabMat 4390 14 TH.rows i (Fin.cast (by rw [blkRowLog_eq P hlc hep .h]) t)
    | .inp => fun i t => tabMat 38 14 TB_prev.rows i (Fin.cast (by rw [blkRowLog_eq P hlc hep .inp]) t)
    | .out => fun i t => tabMat 38 14 TB_next.rows i (Fin.cast (by rw [blkRowLog_eq P hlc hep .out]) t)

/-- Every entry of `blkCmData`'s `A` matrix lies in the base field `GF`. -/
theorem blkCmData_base (P : BlockParams) (hlc : P.logCols = 14) (hep : P.endpointLogN = 14)
    (TA TH TB_prev TB_next : Table) (i : Fin ((blkCmData P hlc hep TA TH TB_prev TB_next).rows .a))
    (t : Fin (2 ^ Block.rowLog P .a + (blkCmData P hlc hep TA TH TB_prev TB_next).Q .a)) :
    (blkCmData P hlc hep TA TH TB_prev TB_next).X .a i t ∈ baseR shdP_K :=
  ⟨_, rfl⟩

/-- Four-commitment claim evaluator for a Shieldstral R13 block. -/
noncomputable def blkCs (TA TH TB_prev TB_next : Table) : Cm → Block.ZClaim → shdP_K
  | .a, z => Link.claimSem shdP_U 4577 14 0 (tabMat 4577 14 TA.rows) z
  | .h, z => Link.claimSem shdP_U 4390 14 0 (tabMat 4390 14 TH.rows) z
  | .inp, z => Link.claimSem shdP_U 38 14 0 (tabMat 38 14 TB_prev.rows) z
  | .out, z => Link.claimSem shdP_U 38 14 0 (tabMat 38 14 TB_next.rows) z

private theorem claimSem_lc_cast {K : Type} [Field K] [Algebra GF K] (U : K)
    {R lc₁ lc₂ : ℕ} (hlc : lc₁ = lc₂) (X : Fin R → Fin (2 ^ lc₂ + 0) → K) (z : Block.ZClaim) :
    Link.claimSem U R lc₁ 0 (fun i t => X i (Fin.cast (by rw [hlc]) t)) z
      = Link.claimSem U R lc₂ 0 X z := by
  subst hlc; rfl

theorem blkCs_eq_claimSem (P : BlockParams) (hlc : P.logCols = 14) (hep : P.endpointLogN = 14)
    (TA TH TB_prev TB_next : Table) (cm : Cm) (z : Block.ZClaim) :
    blkCs TA TH TB_prev TB_next cm z =
      Link.claimSem shdP_U ((blkCmData P hlc hep TA TH TB_prev TB_next).rows cm) (Block.rowLog P cm)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).Q cm)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).X cm) z := by
  cases cm <;> exact (claimSem_lc_cast shdP_U (blkRowLog_eq P hlc hep _) _ z).symm

/-- Unmasked extended slot polynomial in `shdP_K` for a block slot (no `atLog`). -/
noncomputable def blkSlotPolyK (P : BlockParams) (cs : Cm → Block.ZClaim → shdP_K)
    (s : ℕ) (df : SlotDef) (x : Fin (slotN P s) → shdP_K) : shdP_K :=
  let n := (Block.slotShape P s).1
  let rho := (stgWords shdP_U shdP_hbij x).take n
  let es := (stgWords shdP_U shdP_hbij x).drop n
  match Block.tabVals (Block.oneMinusProd es) rho (stgPrivVals shdP_U shdP_hbij P cs rho es df.tabs) df.tabs 0 with
  | .ok vals => (df.poly vals).toK shdP_U
  | .error _ => 0

/-- At canonical `rhoFull` of length `slotN P s`, `blkSlotPolyK` at `vecK rhoFull` agrees with `(df.poly vals).toK`. -/
theorem blkSlotPolyK_vecK_eq (P : BlockParams) (cs : Cm → Block.ZClaim → shdP_K)
    (s : ℕ) (df : SlotDef) (rhoFull vals : List Fp2)
    (hlen : rhoFull.length = slotN P s) (hcan : ∀ a ∈ rhoFull, a.Canon)
    (htab : Block.tabVals (Block.oneMinusProd (rhoFull.drop (Block.slotShape P s).1))
      (rhoFull.take (Block.slotShape P s).1)
      (stgPrivVals shdP_U shdP_hbij P cs
        (rhoFull.take (Block.slotShape P s).1) (rhoFull.drop (Block.slotShape P s).1) df.tabs)
      df.tabs 0 = .ok vals) :
    blkSlotPolyK P cs s df (vecK shdP_U (slotN P s) rhoFull) = (df.poly vals).toK shdP_U := by
  unfold blkSlotPolyK
  have hw : stgWords shdP_U shdP_hbij (vecK shdP_U (slotN P s) rhoFull) = rhoFull :=
    stgWords_toK shdP_U shdP_hbij shdP_hU rhoFull hcan (slotN P s) hlen
  dsimp only
  rw [hw, htab]

/-- Table length well-formedness ensuring `Block.tabVals` succeeds at every point of `Fin (slotN P s) → shdP_K`. -/
def TabsLenOk (n : ℕ) (tabs : List Tab) : Prop :=
  ∀ t ∈ tabs, (∀ pt st, t = .eq pt st → st + pt.length ≤ n) ∧ (∀ pv, t = .pub pv → pv.length = 2 ^ n)

private theorem tabVals_ok_of_tabsOk (sel : Fp2) (rho terms : List Fp2) :
    ∀ (tabs : List Tab) (k : ℕ), TabsLenOk rho.length tabs →
      ∃ vals, Block.tabVals sel rho terms tabs k = .ok vals
  | [], _, _ => ⟨[], rfl⟩
  | t :: ts, k, hok => by
    have ht := hok t List.mem_cons_self
    have hts : TabsLenOk rho.length ts := fun t' ht' => hok t' (List.mem_cons_of_mem _ ht')
    have h1 : ∃ v k', Block.tabVal sel rho terms t k = .ok (v, k') := by
      cases t with
      | eq pt st =>
        have hle := ht.1 pt st rfl
        have hlen : pt.length = ((rho.drop st).take pt.length).length := by
          rw [List.length_take, List.length_drop]; omega
        unfold Block.tabVal eqPoint
        dsimp only
        rw [ite_eq_left hle, ite_eq_left hlen]
        exact ⟨_, _, rfl⟩
      | pub pv =>
        have hlen := ht.2 pv rfl
        unfold Block.tabVal evalMleExt
        dsimp only
        rw [ite_eq_left hlen]
        exact ⟨_, _, rfl⟩
      | priv _ => exact ⟨_, _, rfl⟩
    obtain ⟨v, k', hv⟩ := h1
    obtain ⟨vs, hvs⟩ := tabVals_ok_of_tabsOk sel rho terms ts k' hts
    exact ⟨v :: vs, by simp only [Block.tabVals, hv, hvs]⟩

private theorem slotClaimList_stgPrivVals_true (P : BlockParams) (cs : Cm → Block.ZClaim → shdP_K)
    (hval : ∀ cm ps v₁ v₂, cs cm ⟨ps, v₁⟩ = cs cm ⟨ps, v₂⟩) (rho es : List Fp2) :
    ∀ (tabs : List Tab) (k : ℕ) (terms : List Fp2),
      (∀ j, terms.getD (k + j) Fp2.zero = (stgPrivVals shdP_U shdP_hbij P cs rho es tabs).getD j Fp2.zero) →
      ∀ q ∈ Block.slotClaimList P rho es terms tabs k, cs q.1 q.2 = q.2.value.toK shdP_U
  | [], _, _, _, _, hq => by cases hq
  | .eq _ _ :: ts, k, terms, ht, q, hq =>
    slotClaimList_stgPrivVals_true P cs hval rho es ts k terms ht q hq
  | .pub _ :: ts, k, terms, ht, q, hq =>
    slotClaimList_stgPrivVals_true P cs hval rho es ts k terms ht q hq
  | .priv p :: ts, k, terms, ht, q, hq => by
    simp only [Block.slotClaimList, List.mem_cons] at hq
    rcases hq with rfl | hmem
    · have ht0 : terms.getD k Fp2.zero = ofK shdP_U shdP_hbij
          (cs p.cm (Block.buildClaim P p (Block.claimPoint p rho) (Block.oneMinusProd es)
            (Block.maskCoef es p.extRound) Fp2.zero)) := by
        have e := ht 0; rw [Nat.add_zero] at e; exact e
      unfold Block.buildClaim; dsimp only
      rw [hval p.cm _ (terms.getD k Fp2.zero) Fp2.zero, ht0, toK_ofK shdP_U shdP_hbij]
      rfl
    · exact slotClaimList_stgPrivVals_true P cs hval rho es ts (k + 1) terms
        (fun j => by have e := ht (j + 1); rwa [show k + (j + 1) = k + 1 + j by omega] at e) q hmem

/-- **Exact IR bridge for `blkSlotPolyK`**: for any accepted `defineS` slot with `TabsLenOk`,
`blkSlotPolyK` agrees with the field-evaluated IR on `tabK` at every point `x : Fin (slotN P s) → shdP_K`. -/
theorem blkSlotPolyK_eq_irEval (P : BlockParams) (D : CmData shdP_K P) (cs : Cm → Block.ZClaim → shdP_K)
    (hcs : ∀ cm z, cs cm z = Link.claimSem shdP_U (D.rows cm) (Block.rowLog P cm) (D.Q cm) (D.X cm) z)
    (prog : List Block.SlotS) (pubs : Block.PubTabs)
    (hdef : P.define = Block.defineS prog pubs)
    (hprog : Block.progOKb (Block.rowLog P) prog P.geom.slots = true)
    (s : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef)
    (hdf : P.define s hist dr = .ok df) (hlen : TabsLenOk (Block.slotShape P s).1 df.tabs)
    (x : Fin (slotN P s) → shdP_K) :
    blkSlotPolyK P cs s df x =
      Slot.irEval (((prog.getD s Block.SlotS.empty).ir.map (Block.Sym.eval hist s dr)).map (Fp2.toK shdP_U))
        (df.tabs.map (Block.tabK shdP_U P D (Block.slotShape P s).1 (Block.slotShape P s).2.1 x)) := by
  let n := (Block.slotShape P s).1
  let e := (Block.slotShape P s).2.1
  let rho := (stgWords shdP_U shdP_hbij x).take n
  let es := (stgWords shdP_U shdP_hbij x).drop n
  have hrho : rho.length = n := by
    rw [List.length_take, stgWords_length]; exact Nat.min_eq_left (Nat.le_add_right n e)
  have hes : es.length = e := by
    rw [List.length_drop, stgWords_length]; show n + e - n = e; omega
  have hN : (rho ++ es).length ≤ slotN P s := by
    rw [List.length_append, hrho, hes]
  have hrc : ∀ a ∈ rho, a.Canon := fun a ha => stgWords_canon shdP_U shdP_hbij x a (List.mem_of_mem_take ha)
  have hec : ∀ a ∈ es, a.Canon := fun a ha => stgWords_canon shdP_U shdP_hbij x a (List.mem_of_mem_drop ha)
  rw [hdef] at hdf
  obtain ⟨hcan, rfl⟩ := Block.defineS_ok hdf
  obtain ⟨vals, hvals⟩ := tabVals_ok_of_tabsOk (Block.oneMinusProd es) rho
    (stgPrivVals shdP_U shdP_hbij P cs rho es _) _ 0 (by rwa [hrho])
  have hkk := Block.progOK_getD (Block.rowLog P) prog P.geom.slots hprog s
  unfold Block.slotOKb at hkk
  rw [Bool.and_eq_true] at hkk
  have hmem := List.all_eq_true.mp hkk.1
  have hok : ∀ t ∈ (prog.getD s Block.SlotS.empty).tabs.map
      (Block.TabS.eval (Block.Sym.eval hist s dr) (pubs s hist dr)), Block.TabOK P t := by
    intro t ht
    obtain ⟨ts, hts, rfl⟩ := List.mem_map.mp ht
    exact Block.tabOK_eval P _ _ ts (hmem ts hts)
  have hcn : ∀ t ∈ (prog.getD s Block.SlotS.empty).tabs.map
      (Block.TabS.eval (Block.Sym.eval hist s dr) (pubs s hist dr)), Block.TabCanon t := by
    intro t ht
    obtain ⟨ts, -, rfl⟩ := List.mem_map.mp ht
    exact Block.tabCanon_eval hcan _ ts
  have hvalIndep : ∀ cm ps v₁ v₂, cs cm ⟨ps, v₁⟩ = cs cm ⟨ps, v₂⟩ := fun cm ps v₁ v₂ => by
    rw [hcs, hcs]; rfl
  have htrue : ∀ q ∈ Block.slotClaimList P rho es
      (stgPrivVals shdP_U shdP_hbij P cs rho es
        ((prog.getD s Block.SlotS.empty).tabs.map (Block.TabS.eval (Block.Sym.eval hist s dr) (pubs s hist dr))))
      ((prog.getD s Block.SlotS.empty).tabs.map (Block.TabS.eval (Block.Sym.eval hist s dr) (pubs s hist dr))) 0,
      cs q.1 q.2 = q.2.value.toK shdP_U :=
    slotClaimList_stgPrivVals_true P cs hvalIndep rho es _ 0 _ (fun j => by rw [Nat.zero_add])
  have hT := Block.tabVals_toK (N := slotN P s) shdP_U shdP_hU P D cs hcs n e rho es _ hrho hes hN hrc hec _
    0 vals hok hcn hvals htrue
  rw [xOf_take_drop_stgWords shdP_U shdP_hbij n x] at hT
  have hirc : ((prog.getD s Block.SlotS.empty).ir.map (Block.Sym.eval hist s dr)).Canon :=
    Block.Ir.canon_map _ (fun sym => Block.Sym.eval_canon hcan sym) _
  unfold blkSlotPolyK
  dsimp only
  rw [hvals]
  dsimp only
  rw [Slot.toK_irEvalW shdP_U shdP_hU _ hirc vals, hT]

/-- **`blkSlotPolyK` agrees with `Block.polyS`** at any trace view `sn : Seen` matching `(hist, dr)`. -/
theorem blkSlotPolyK_eq_polyS (P : BlockParams) (D : CmData shdP_K P) (cs : Cm → Block.ZClaim → shdP_K)
    (hcs : ∀ cm z, cs cm z = Link.claimSem shdP_U (D.rows cm) (Block.rowLog P cm) (D.Q cm) (D.X cm) z)
    (prog : List Block.SlotS) (pubs : Block.PubTabs)
    (hdef : P.define = Block.defineS prog pubs)
    (hprog : Block.progOKb (Block.rowLog P) prog P.geom.slots = true)
    (s : ℕ) (sn : Seen) (df : SlotDef)
    (hdf : P.define s (histSeen sn s) (drSeen sn s) = .ok df)
    (hlen : TabsLenOk (Block.slotShape P s).1 df.tabs)
    (x : Fin (slotN P s) → shdP_K) :
    blkSlotPolyK P cs s df x = polyS shdP_U P D prog pubs s sn x := by
  have h1 := blkSlotPolyK_eq_irEval P D cs hcs prog pubs hdef hprog s (histSeen sn s) (drSeen sn s) df hdf hlen x
  rw [hdef] at hdf
  obtain ⟨-, rfl⟩ := Block.defineS_ok hdf
  exact h1

/-- **Individual degree bound for `blkSlotPolyK`**: direct from `progOKb` without constructing `Seen`. -/
theorem blkSlotPolyK_indDeg (P : BlockParams) (D : CmData shdP_K P) (cs : Cm → Block.ZClaim → shdP_K)
    (hcs : ∀ cm z, cs cm z = Link.claimSem shdP_U (D.rows cm) (Block.rowLog P cm) (D.Q cm) (D.X cm) z)
    (prog : List Block.SlotS) (pubs : Block.PubTabs)
    (hdef : P.define = Block.defineS prog pubs)
    (hprog : Block.progOKb (Block.rowLog P) prog P.geom.slots = true)
    (s : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef)
    (hdf : P.define s hist dr = .ok df) (hlen : TabsLenOk (Block.slotShape P s).1 df.tabs) :
    IndDegLE (slotD P s) (blkSlotPolyK P cs s df) := by
  have heq : blkSlotPolyK P cs s df = fun x =>
      Slot.irEval (((prog.getD s Block.SlotS.empty).ir.map (Block.Sym.eval hist s dr)).map (Fp2.toK shdP_U))
        (df.tabs.map (Block.tabK shdP_U P D (Block.slotShape P s).1 (Block.slotShape P s).2.1 x)) :=
    funext (blkSlotPolyK_eq_irEval P D cs hcs prog pubs hdef hprog s hist dr df hdf hlen)
  rw [heq]
  rw [hdef] at hdf
  obtain ⟨-, rfl⟩ := Block.defineS_ok hdf
  have hk := Block.progOK_getD (Block.rowLog P) prog P.geom.slots hprog s
  unfold Block.slotOKb at hk
  rw [Bool.and_eq_true] at hk
  obtain ⟨htabs, hdeg⟩ := hk
  have hdeg' : Block.irDeg (prog.getD s Block.SlotS.empty).ir ≤ slotD P s := of_decide_eq_true hdeg
  have hmem := List.all_eq_true.mp htabs
  have hok : ∀ t ∈ (prog.getD s Block.SlotS.empty).tabs.map
      (Block.TabS.eval (Block.Sym.eval hist s dr) (pubs s hist dr)), Block.TabOK P t := by
    intro t ht
    obtain ⟨ts, hts, rfl⟩ := List.mem_map.mp ht
    exact Block.tabOK_eval P _ _ ts (hmem ts hts)
  have h := Block.irEval_indDeg
    (fun x : Fin (slotN P s) → shdP_K =>
      ((prog.getD s Block.SlotS.empty).tabs.map
        (Block.TabS.eval (Block.Sym.eval hist s dr) (pubs s hist dr))).map
        (Block.tabK shdP_U P D (Block.slotShape P s).1 (Block.slotShape P s).2.1 x))
    (tabsK_indDeg shdP_U P D _ _ _ hok)
    (((prog.getD s Block.SlotS.empty).ir.map (Block.Sym.eval hist s dr)).map (Fp2.toK shdP_U))
  rw [Block.irDeg_map, Block.irDeg_map] at h
  exact IndDegLE.mono h hdeg'

/-- Honest `SlotData` for one Shieldstral R13 block, handling `.standalone`, `.priv`, and `.host` uniformly. -/
noncomputable def blkSlotData {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (P : BlockParams) (w : BlkWitness Ly Pb xIn xOut)
    (TA TB_prev TB_next : Table) (rnd : BlkRand) : SlotData P :=
  let mRow := mRowKOf 23 rnd.mA
  let G : ℕ → shdP_K := fun s => cubeSum (Link.maskPoly mRow s (slotN P s) (slotD P s))
  polySlotData P shdP_U shdP_hbij
    (fun s hist acc df ch0 =>
      let TH := blkTH w rnd (hist.beta, hist.gamma, hist.alpha)
      let cs := blkCs TA TH TB_prev TB_next
      match P.kind s with
      | .standalone => ofK shdP_U shdP_hbij (ch0.toK shdP_U * G s)
      | .priv => ofK shdP_U shdP_hbij (cubeSum (blkSlotPolyK P cs s df) + ch0.toK shdP_U * G s)
      | .host =>
        ofK shdP_U shdP_hbij (ch0.toK shdP_U * G s
          - (df.hosted.map fun hk =>
              hk.2.toK shdP_U * (acc.cs.getD hk.1 Fp2.zero).toK shdP_U * G hk.1).sum))
    (fun s hist _ df ch0 x =>
      let TH := blkTH w rnd (hist.beta, hist.gamma, hist.alpha)
      blkSlotPolyK P (blkCs TA TH TB_prev TB_next) s df x
        + ch0.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) x)
    (fun s hist _ df _ rho =>
      let n := (Block.slotShape P s).1
      let TH := blkTH w rnd (hist.beta, hist.gamma, hist.alpha)
      stgPrivVals shdP_U shdP_hbij P (blkCs TA TH TB_prev TB_next) (rho.take n) (rho.drop n) df.tabs)

theorem blkSlotData_scalar_canon {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (P : BlockParams) (w : BlkWitness Ly Pb xIn xOut)
    (TA TB_prev TB_next : Table) (rnd : BlkRand) (s : ℕ) (hist : Hist) (acc : Acc) (df : SlotDef) (ch0 : Fp2) :
    ((blkSlotData P w TA TB_prev TB_next rnd).scalar s hist acc df ch0).Canon := by
  dsimp only [blkSlotData, polySlotData]
  cases P.kind s <;> exact ofK_canon shdP_U shdP_hbij _

theorem blkSlotData_terms_canon {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (P : BlockParams) (w : BlkWitness Ly Pb xIn xOut)
    (TA TB_prev TB_next : Table) (rnd : BlkRand) (s : ℕ) (hist : Hist) (acc : Acc) (df : SlotDef)
    (ch0 : Fp2) (rho : List Fp2) :
    ∀ v ∈ (blkSlotData P w TA TB_prev TB_next rnd).terms s hist acc df ch0 rho, v.Canon :=
  stgPrivVals_canon shdP_U shdP_hbij P _ _ _ df.tabs

theorem blkSlotData_terms_length {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (P : BlockParams) (w : BlkWitness Ly Pb xIn xOut)
    (TA TB_prev TB_next : Table) (rnd : BlkRand) (s : ℕ) (hist : Hist) (acc : Acc) (df : SlotDef)
    (ch0 : Fp2) (rho : List Fp2) :
    ((blkSlotData P w TA TB_prev TB_next rnd).terms s hist acc df ch0 rho).length
      = (df.tabs.filter Tab.isPriv).length :=
  stgPrivVals_length shdP_U shdP_hbij P _ _ _ df.tabs

/-- Honest `CoreTables` bundle for one Shieldstral R13 block. -/
noncomputable def blkCoreTables {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (P : BlockParams) (w : BlkWitness Ly Pb xIn xOut)
    (TB_prev TB_next : Table) (rnd : BlkRand) : CoreTables P where
  TA := blkTA w rnd
  M := blkTM rnd
  TH b g a := blkTH w rnd (b, g, a)
  slot := blkSlotData P w (blkTA w rnd) TB_prev TB_next rnd

/-- Honest `ShdBlkTables` bundle for block `k` plugging directly into `shdP_blkSegP` / `shdP_blk_segComplete`. -/
noncomputable def shdP_blkTables {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (Pk : ℕ → BlockParams) (k : ℕ)
    (w : BlkWitness Ly Pb xIn xOut) (TB_prev TB_next : Table) (rnd : BlkRand) :
    ShdBlkTables Pk k where
  TB_prev := TB_prev
  TB_next := TB_next
  coreT := blkCoreTables (Pk k) w TB_prev TB_next rnd

/-- `blkAlphaBad`-guarded block segment prover wrapping `shdP_blkSegP` without touching `HonestShieldBlockBase`. -/
noncomputable def shdP_blkSegP_guarded {St X Coins : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndCheck : St → ℕ → List Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (W : (HIn → Dig) → St → X → Coins → (k : ℕ) → ShdBlkTables Pk k)
    (k : ℕ) : SegP St X Coins where
  run H s x c bnd start cr t :=
    let w := W H s x c k
    let bRoot := rootOf H tag 16 w.TB_next
    let tFrame := blockFrame (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) H s k bRoot t
    let aRoot := rootOf H tag 16 w.coreT.TA
    let mRoot := rootOf H tag 12 (mTab 23 (cosetPt (rootFp 12)) w.coreT.M)
    if blkAlphaBad Ly Pb (bgaOf H (Pk k) aRoot mRoot tFrame) then .error ()
    else (shdP_blkSegP tag Pk sgeom check paths digest bRows bLogN bndCheck bndOpen W k).run H s x c bnd start cr t

/-- Extracting `blkAlphaBad = false` and underlying `shdP_blkSegP` acceptance from `shdP_blkSegP_guarded`. -/
theorem shdP_blkSegP_guarded_run_ok {St X Coins : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndCheck : St → ℕ → List Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (W : (HIn → Dig) → St → X → Coins → (k : ℕ) → ShdBlkTables Pk k)
    (k : ℕ) (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr)
    (res : (Dig → List UInt8) × Carry × Tr)
    (hrun : (shdP_blkSegP_guarded tag Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Ly Pb W k).run
      H s x c bnd start cr t = .ok res) :
    let w := W H s x c k
    let bRoot := rootOf H tag 16 w.TB_next
    let tFrame := blockFrame (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) H s k bRoot t
    let aRoot := rootOf H tag 16 w.coreT.TA
    let mRoot := rootOf H tag 12 (mTab 23 (cosetPt (rootFp 12)) w.coreT.M)
    blkAlphaBad Ly Pb (bgaOf H (Pk k) aRoot mRoot tFrame) = false
      ∧ (shdP_blkSegP tag Pk sgeom check paths digest bRows bLogN bndCheck bndOpen W k).run
          H s x c bnd start cr t = .ok res := by
  dsimp only [shdP_blkSegP_guarded] at hrun ⊢
  by_cases hbad : blkAlphaBad Ly Pb (bgaOf H (Pk k) (rootOf H tag 16 (W H s x c k).coreT.TA)
      (rootOf H tag 12 (mTab 23 (cosetPt (rootFp 12)) (W H s x c k).coreT.M))
      (blockFrame (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) H s k
        (rootOf H tag 16 (W H s x c k).TB_next) t)) = true
  · rw [ite_eq_left hbad] at hrun; cases hrun
  · rw [ite_eq_right hbad] at hrun; exact ⟨ff_of_not hbad, hrun⟩

end BlockSlotAndCmData

/-! ## 5. Universal `planeZ` / `aPl` / `hPl` Evaluators, `blk_xtR_eq_E`, and `blk_AlkR13_eq_blkLkTup` -/

section PlaneEvaluators

private theorem planeZ_lc_cast {R lc₁ lc₂ : ℕ} (hlc : lc₁ = lc₂)
    (X : Fin R → Fin (2 ^ lc₂ + 0) → shdP_K) (p : Block.Priv) (b : Fin p.log → Bool) :
    planeZ shdP_U lc₁ R 0 (fun i t => X i (Fin.cast (by rw [hlc]) t)) p b
      = planeZ shdP_U lc₂ R 0 X p b := by
  subst hlc; rfl

private theorem planeZ_blkCmData_a (P : BlockParams) (hlc : P.logCols = 14) (hep : P.endpointLogN = 14)
    (TA TH TB_prev TB_next : Table) (p : Block.Priv) (b : Fin p.log → Bool) :
    planeZ shdP_U (Block.rowLog P .a)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).rows .a)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).Q .a)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).X .a) p b
      = planeZ shdP_U 14 4577 0 (tabMat 4577 14 TA.rows) p b :=
  planeZ_lc_cast (blkRowLog_eq P hlc hep .a) (tabMat 4577 14 TA.rows) p b

private theorem planeZ_blkCmData_h (P : BlockParams) (hlc : P.logCols = 14) (hep : P.endpointLogN = 14)
    (TA TH TB_prev TB_next : Table) (p : Block.Priv) (b : Fin p.log → Bool) :
    planeZ shdP_U (Block.rowLog P .h)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).rows .h)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).Q .h)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).X .h) p b
      = planeZ shdP_U 14 4390 0 (tabMat 4390 14 TH.rows) p b :=
  planeZ_lc_cast (blkRowLog_eq P hlc hep .h) (tabMat 4390 14 TH.rows) p b

private theorem planeZ_blkCmData_inp (P : BlockParams) (hlc : P.logCols = 14) (hep : P.endpointLogN = 14)
    (TA TH TB_prev TB_next : Table) (p : Block.Priv) (b : Fin p.log → Bool) :
    planeZ shdP_U (Block.rowLog P .inp)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).rows .inp)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).Q .inp)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).X .inp) p b
      = planeZ shdP_U 14 38 0 (tabMat 38 14 TB_prev.rows) p b :=
  planeZ_lc_cast (blkRowLog_eq P hlc hep .inp) (tabMat 38 14 TB_prev.rows) p b

private theorem planeZ_blkCmData_out (P : BlockParams) (hlc : P.logCols = 14) (hep : P.endpointLogN = 14)
    (TA TH TB_prev TB_next : Table) (p : Block.Priv) (b : Fin p.log → Bool) :
    planeZ shdP_U (Block.rowLog P .out)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).rows .out)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).Q .out)
        ((blkCmData P hlc hep TA TH TB_prev TB_next).X .out) p b
      = planeZ shdP_U 14 38 0 (tabMat 38 14 TB_next.rows) p b :=
  planeZ_lc_cast (blkRowLog_eq P hlc hep .out) (tabMat 38 14 TB_next.rows) p b

theorem msbIndex_div_lt (logN log : ℕ) (b : Fin log → Bool) :
    msbIndex log b / 2 ^ logN < max 1 (2 ^ log / 2 ^ logN) := by
  by_cases hle : logN ≤ log
  · have hpow : 2 ^ log = 2 ^ (log - logN) * 2 ^ logN := by
      rw [← pow_add, show log - logN + logN = log by omega]
    have hdiv : 2 ^ log / 2 ^ logN = 2 ^ (log - logN) := by
      rw [hpow, Nat.mul_div_cancel _ (Nat.two_pow_pos logN)]
    have hlt : msbIndex log b / 2 ^ logN < 2 ^ (log - logN) :=
      Nat.div_lt_of_lt_mul (by rw [mul_comm, ← hpow]; exact msbIndex_lt log b)
    exact lt_of_lt_of_le hlt (hdiv ▸ le_max_right 1 _)
  · have hlt : msbIndex log b < 2 ^ logN :=
      lt_trans (msbIndex_lt log b) (Nat.pow_lt_pow_right (by norm_num) (by omega))
    rw [Nat.div_eq_of_lt hlt]
    exact lt_of_lt_of_le Nat.zero_lt_one (le_max_left 1 _)

/-- **Sub-row `planeZ` evaluator** (`log < logN`, `off = r0 * 2^logN + c0`, `c0 + 2^log ≤ 2^logN`):
covers `Dom::T`, `Dom::Ht`, and `plL` sub-slices uniformly. -/
theorem planeZ_subrow_eq (R logN r0 c0 log : ℕ) (cm : Cm) (hr0 : r0 < R)
    (hlog : log < logN) (hc0 : c0 + 2 ^ log ≤ 2 ^ logN)
    (X : Fin R → Fin (2 ^ logN + 0) → shdP_K) (b : Fin log → Bool) :
    planeZ shdP_U logN R 0 X ⟨cm, [(r0 * 2 ^ logN + c0, Fp2.one)], log, [], 0, 0⟩ b
      = X ⟨r0, hr0⟩ ⟨c0 + msbIndex log b, by have := msbIndex_lt log b; omega⟩ := by
  have hc0lt : c0 < 2 ^ logN := lt_of_lt_of_le (Nat.lt_add_of_pos_right (Nat.two_pow_pos log)) hc0
  have hdiv : (r0 * 2 ^ logN + c0) / 2 ^ logN = r0 := by
    rw [Nat.add_comm, Nat.add_mul_div_right _ _ (Nat.two_pow_pos logN), Nat.div_eq_of_lt hc0lt, Nat.zero_add]
  have hmod : (r0 * 2 ^ logN + c0) % 2 ^ logN = c0 := by
    rw [Nat.add_comm, Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt hc0lt]
  have hnotle : ¬ (logN ≤ log) := by omega
  let z : ℕ → shdP_K := fun a => if h : a < log then (bit (b ⟨a, h⟩) : shdP_K) else 0
  have hrow : ∀ i : Fin R, Block.partRowK logN (r0 * 2 ^ logN + c0) log z i.val = if i.val = r0 then 1 else 0 := by
    intro i; unfold Block.partRowK; rw [ite_eq_right hnotle, hdiv]
  have hcol : ∀ t : Fin (2 ^ logN + 0),
      Block.keyColK logN (r0 * 2 ^ logN + c0) log z t.val = if t.val = c0 + msbIndex log b then 1 else 0 := by
    intro t
    unfold Block.keyColK
    rw [ite_eq_right hnotle, hmod]
    by_cases hlt : c0 ≤ t.val ∧ t.val < c0 + 2 ^ log
    · rw [ite_eq_left hlt]
      have hfn : (fun a : Fin log => z a.val) = fun a : Fin log => (bit (b a) : shdP_K) :=
        funext fun a => dite_eq_left a.isLt
      rw [hfn, eqPoly_bit_bitsK log b (t.val - c0) (by omega)]
      by_cases heq : t.val = c0 + msbIndex log b
      · rw [ite_eq_left (by omega), ite_eq_left heq]
      · rw [ite_eq_right (by omega), ite_eq_right heq]
    · rw [ite_eq_right hlt]
      have hne : t.val ≠ c0 + msbIndex log b := by have := msbIndex_lt log b; omega
      rw [ite_eq_right hne]
  unfold planeZ privZ
  simp only [List.map_cons, List.map_nil, Block.claimK, List.sum_cons, List.sum_nil, add_zero, Fp2.toK_one, one_mul]
  rw [Finset.sum_eq_single_of_mem (⟨r0, hr0⟩ : Fin R) (Finset.mem_univ _)]
  · rw [hrow ⟨r0, hr0⟩, ite_eq_left rfl, one_mul]
    rw [Finset.sum_eq_single_of_mem (⟨c0 + msbIndex log b, by have := msbIndex_lt log b; omega⟩ : Fin (2 ^ logN + 0))
      (Finset.mem_univ _)]
    · rw [ite_eq_left (by have := msbIndex_lt log b; omega), hcol, ite_eq_left rfl, mul_one]
    · intro t _ hne
      have ht : t.val < 2 ^ logN := by have := t.isLt; omega
      rw [ite_eq_left ht, hcol, ite_eq_right (fun h => hne (Fin.ext h)), mul_zero]
  · intro i _ hne
    rw [hrow i, ite_eq_right (fun h => hne (Fin.ext h)), zero_mul]

/-- **Row-aligned `planeZ` evaluator** (works uniformly for ALL `log`, both `log < logN` and `logN ≤ log`!). -/
theorem planeZ_single_eq (R logN r0 log : ℕ) (cm : Cm)
    (hr : r0 + max 1 (2 ^ log / 2 ^ logN) ≤ R)
    (X : Fin R → Fin (2 ^ logN + 0) → shdP_K) (b : Fin log → Bool) :
    planeZ shdP_U logN R 0 X ⟨cm, [(r0 * 2 ^ logN, Fp2.one)], log, [], 0, 0⟩ b
      = X ⟨r0 + msbIndex log b / 2 ^ logN,
            lt_of_lt_of_le (Nat.add_lt_add_left (msbIndex_div_lt logN log b) r0) hr⟩
          ⟨msbIndex log b % 2 ^ logN, Nat.mod_lt _ (Nat.two_pow_pos logN)⟩ := by
  by_cases hle : logN ≤ log
  · have hdivR : r0 * 2 ^ logN / 2 ^ logN = r0 := Nat.mul_div_cancel r0 (Nat.two_pow_pos logN)
    let hi := log - logN
    let bHi : Fin hi → Bool := fun a => b ⟨a.val, by omega⟩
    let bLo : Fin logN → Bool := fun a => b ⟨hi + a.val, by omega⟩
    have hsplit : msbIndex log b = msbIndex hi bHi * 2 ^ logN + msbIndex logN bLo := by
      have h1 := msbIndex_split hi logN (castB (by omega : log = hi + logN) b)
      rw [Exec.Block.Join.R13H.Dzc.msbIndex_castB] at h1
      exact h1
    have hq : msbIndex log b / 2 ^ logN = msbIndex hi bHi := by
      rw [hsplit, Nat.add_comm, Nat.add_mul_div_right _ _ (Nat.two_pow_pos logN),
        Nat.div_eq_of_lt (msbIndex_lt logN bLo), Nat.zero_add]
    have hrm : msbIndex log b % 2 ^ logN = msbIndex logN bLo := by
      rw [hsplit, Nat.add_comm, Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt (msbIndex_lt logN bLo)]
    let z : ℕ → shdP_K := fun a => if h : a < log then (bit (b ⟨a, h⟩) : shdP_K) else 0
    have hrow : ∀ i : Fin R, Block.partRowK logN (r0 * 2 ^ logN) log z i.val
        = if i.val = r0 + msbIndex log b / 2 ^ logN then 1 else 0 := by
      intro i
      unfold Block.partRowK
      rw [ite_eq_left hle, hdivR]
      by_cases hlt : r0 ≤ i.val ∧ i.val < r0 + 2 ^ hi
      · rw [ite_eq_left hlt]
        have hfn : (fun a : Fin hi => z a.val) = fun a : Fin hi => (bit (bHi a) : shdP_K) :=
          funext fun a => dite_eq_left (by have := a.isLt; omega)
        rw [hfn, eqPoly_bit_bitsK hi bHi (i.val - r0) (by omega), hq]
        by_cases heq : i.val = r0 + msbIndex hi bHi
        · rw [ite_eq_left (by omega), ite_eq_left heq]
        · rw [ite_eq_right (by omega), ite_eq_right heq]
      · rw [ite_eq_right hlt]
        have hne : i.val ≠ r0 + msbIndex log b / 2 ^ logN := by
          rw [hq]; have := msbIndex_lt hi bHi; omega
        rw [ite_eq_right hne]
    have hcol : ∀ t : Fin (2 ^ logN + 0), Block.keyColK logN (r0 * 2 ^ logN) log z t.val
        = if t.val = msbIndex log b % 2 ^ logN then 1 else 0 := by
      intro t
      unfold Block.keyColK
      rw [ite_eq_left hle]
      have hfn : (fun a : Fin logN => z (hi + a.val)) = fun a : Fin logN => (bit (bLo a) : shdP_K) :=
        funext fun a => dite_eq_left (by have := a.isLt; omega)
      rw [hfn, eqPoly_bit_bitsK logN bLo t.val t.isLt, hrm]
    unfold planeZ privZ
    simp only [List.map_cons, List.map_nil, Block.claimK, List.sum_cons, List.sum_nil, add_zero, Fp2.toK_one, one_mul]
    rw [Finset.sum_eq_single_of_mem
      (⟨r0 + msbIndex log b / 2 ^ logN, lt_of_lt_of_le (Nat.add_lt_add_left (msbIndex_div_lt logN log b) r0) hr⟩ : Fin R)
      (Finset.mem_univ _)]
    · rw [hrow, ite_eq_left rfl, one_mul]
      rw [Finset.sum_eq_single_of_mem
        (⟨msbIndex log b % 2 ^ logN, Nat.mod_lt _ (Nat.two_pow_pos logN)⟩ : Fin (2 ^ logN + 0))
        (Finset.mem_univ _)]
      · rw [ite_eq_left (Nat.mod_lt _ (Nat.two_pow_pos logN)), hcol, ite_eq_left rfl, mul_one]
      · intro t _ hne
        have ht : t.val < 2 ^ logN := by have := t.isLt; omega
        rw [ite_eq_left ht, hcol, ite_eq_right (fun h => hne (Fin.ext h)), mul_zero]
    · intro i _ hne
      rw [hrow i, ite_eq_right (fun h => hne (Fin.ext h)), zero_mul]
  · have hlt : log < logN := by omega
    have hr0 : r0 < R := lt_of_lt_of_le (Nat.lt_add_of_pos_right (lt_of_lt_of_le Nat.zero_lt_one (le_max_left 1 _))) hr
    have hc0 : 0 + 2 ^ log ≤ 2 ^ logN := by
      rw [Nat.zero_add]; exact Nat.pow_le_pow_right (by norm_num) (by omega)
    have hsub := planeZ_subrow_eq R logN r0 0 log cm hr0 hlt hc0 X b
    rw [Nat.add_zero (r0 * 2 ^ logN)] at hsub
    have hbm : msbIndex log b < 2 ^ logN :=
      lt_trans (msbIndex_lt log b) (Nat.pow_lt_pow_right (by norm_num) hlt)
    rw [hsub]
    exact congrArg₂ X
      (Fin.ext (by dsimp only; rw [Nat.div_eq_of_lt hbm, Nat.add_zero]))
      (Fin.ext (by dsimp only; rw [Nat.zero_add, Nat.mod_eq_of_lt hbm]))

private theorem toK_fp2U : Block.fp2U.toK shdP_U = shdP_U :=
  Block.toK_fp2U shdP_U

/-- **Two-slice `H`-plane evaluator** (`logN ≤ log`, real half at `reRow`, imaginary half at `imRow`). -/
theorem planeZ_pair_eq (R logN reRow imRow log : ℕ) (cm : Cm) (hle : logN ≤ log)
    (hre : reRow + max 1 (2 ^ log / 2 ^ logN) ≤ R)
    (him : imRow + max 1 (2 ^ log / 2 ^ logN) ≤ R)
    (X : Fin R → Fin (2 ^ logN + 0) → shdP_K) (b : Fin log → Bool) :
    planeZ shdP_U logN R 0 X ⟨cm, [(reRow * 2 ^ logN, Fp2.one), (imRow * 2 ^ logN, Block.fp2U)], log, [], 0, 0⟩ b
      = X ⟨reRow + msbIndex log b / 2 ^ logN,
            lt_of_lt_of_le (Nat.add_lt_add_left (msbIndex_div_lt logN log b) reRow) hre⟩
          ⟨msbIndex log b % 2 ^ logN, Nat.mod_lt _ (Nat.two_pow_pos logN)⟩
        + shdP_U * X ⟨imRow + msbIndex log b / 2 ^ logN,
            lt_of_lt_of_le (Nat.add_lt_add_left (msbIndex_div_lt logN log b) imRow) him⟩
          ⟨msbIndex log b % 2 ^ logN, Nat.mod_lt _ (Nat.two_pow_pos logN)⟩ := by
  have hkeyEq : ∀ (z : ℕ → shdP_K) (t : ℕ),
      Block.keyColK logN (reRow * 2 ^ logN) log z t = Block.keyColK logN (imRow * 2 ^ logN) log z t := by
    intro z t; unfold Block.keyColK; rw [ite_eq_left hle, ite_eq_left hle]
  have hsplit : planeZ shdP_U logN R 0 X
        ⟨cm, [(reRow * 2 ^ logN, Fp2.one), (imRow * 2 ^ logN, Block.fp2U)], log, [], 0, 0⟩ b
      = planeZ shdP_U logN R 0 X ⟨cm, [(reRow * 2 ^ logN, Fp2.one)], log, [], 0, 0⟩ b
        + shdP_U * planeZ shdP_U logN R 0 X ⟨cm, [(imRow * 2 ^ logN, Fp2.one)], log, [], 0, 0⟩ b := by
    unfold planeZ privZ
    simp only [List.map_cons, List.map_nil, Block.claimK, List.sum_cons, List.sum_nil, add_zero,
      Fp2.toK_one, toK_fp2U, one_mul]
    rw [Finset.mul_sum, ← Finset.sum_add_distrib]
    refine Finset.sum_congr rfl (fun i _ => ?_)
    have hinner : (∑ t : Fin (2 ^ logN + 0), X i t *
          if (t : ℕ) < 2 ^ logN then Block.keyColK logN (reRow * 2 ^ logN) log
            (fun a => if h : a < log then (bit (b ⟨a, h⟩) : shdP_K) else 0) t else 0)
        = (∑ t : Fin (2 ^ logN + 0), X i t *
          if (t : ℕ) < 2 ^ logN then Block.keyColK logN (imRow * 2 ^ logN) log
            (fun a => if h : a < log then (bit (b ⟨a, h⟩) : shdP_K) else 0) t else 0) :=
      Finset.sum_congr rfl (fun t _ => by rw [hkeyEq])
    rw [hinner]; ring
  rw [hsplit, planeZ_single_eq R logN reRow log cm hre X b, planeZ_single_eq R logN imRow log cm him X b]

/-! ### Exact `aPl` and `hPl` evaluators on `blkCmData` -/

section ConcretePlaneAccessors

variable {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
variable (P : BlockParams) (hlc : P.logCols = 14) (hep : P.endpointLogN = 14)
variable (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand) (bga : Fp2 × Fp2 × Fp2) (TB_prev TB_next : Table)

local notation "cS" => Exec.Block.DefR13.cfgShieldR13 Ly
local notation "DS" => blkCmData P hlc hep (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next

theorem blk_aPl_T0 (b : Fin 7 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 0) 7 b = algebraMap GF shdP_K (w.E.dA b) := by
  unfold aPl
  rw [aOff_shield, show shdARow 0 = 0 from rfl, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 0 7 .a (by norm_num) (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 7 b
  have hmod : msbIndex 7 b % 2 ^ 14 = msbIndex 7 b := by omega
  unfold blkTAData; dsimp only
  rw [ite_eq_left (by omega), ite_eq_left (by omega), Fp.toGF_ofGF]
  exact congrArg (fun f : Fin 7 → Bool => algebraMap GF shdP_K (w.E.dA f))
    ((congrArg (msbBits 7) hmod).trans (msbBits_msbIndex 7 b))

theorem blk_aPl_T1 (b : Fin 7 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 1) 7 b = algebraMap GF shdP_K (w.E.dsqA b) := by
  unfold aPl
  rw [aOff_shield, show shdARow 1 = 1 from rfl, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 1 7 .a (by norm_num) (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 7 b
  have hmod : msbIndex 7 b % 2 ^ 14 = msbIndex 7 b := by omega
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_left (by omega), ite_eq_left (by omega), Fp.toGF_ofGF]
  exact congrArg (fun f : Fin 7 → Bool => algebraMap GF shdP_K (w.E.dsqA f))
    ((congrArg (msbBits 7) hmod).trans (msbBits_msbIndex 7 b))

theorem blk_aPl_T2 (b : Fin 7 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 2) 7 b = algebraMap GF shdP_K (w.E.dM b) := by
  unfold aPl
  rw [aOff_shield, show shdARow 2 = 2 from rfl, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 2 7 .a (by norm_num) (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 7 b
  have hmod : msbIndex 7 b % 2 ^ 14 = msbIndex 7 b := by omega
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega), ite_eq_left (by omega), Fp.toGF_ofGF]
  exact congrArg (fun f : Fin 7 → Bool => algebraMap GF shdP_K (w.E.dM f))
    ((congrArg (msbBits 7) hmod).trans (msbBits_msbIndex 7 b))

theorem blk_aPl_T3 (b : Fin 7 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 3) 7 b = algebraMap GF shdP_K (w.E.dsqM b) := by
  unfold aPl
  rw [aOff_shield, show shdARow 3 = 3 from rfl, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 3 7 .a (by norm_num) (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 7 b
  have hmod : msbIndex 7 b % 2 ^ 14 = msbIndex 7 b := by omega
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega),
    ite_eq_left (by omega), Fp.toGF_ofGF]
  exact congrArg (fun f : Fin 7 → Bool => algebraMap GF shdP_K (w.E.dsqM f))
    ((congrArg (msbBits 7) hmod).trans (msbBits_msbIndex 7 b))

theorem blk_aPl_MX (b : Fin 12 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 4) 12 b = algebraMap GF shdP_K (w.E.MX (splitHt cS b)) := by
  unfold aPl
  rw [aOff_shield, show shdARow 4 = 4 from rfl, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 4 12 .a (by norm_num) (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 12 b
  have hmod : msbIndex 12 b % 2 ^ 14 = msbIndex 12 b := by omega
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_left (by omega), ite_eq_left (by omega), Fp.toGF_ofGF]
  exact congrArg (fun f : Fin 12 → Bool => algebraMap GF shdP_K (w.E.MX (splitHt cS f)))
    ((congrArg (msbBits 12) hmod).trans (msbBits_msbIndex 12 b))

theorem blk_aPl_SUM (b : Fin 12 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 5) 12 b = algebraMap GF shdP_K (w.E.SUM (splitHt cS b)) := by
  unfold aPl
  rw [aOff_shield, show shdARow 5 = 5 from rfl, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 5 12 .a (by norm_num) (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 12 b
  have hmod : msbIndex 12 b % 2 ^ 14 = msbIndex 12 b := by omega
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_left (by omega), ite_eq_left (by omega), Fp.toGF_ofGF]
  exact congrArg (fun f : Fin 12 → Bool => algebraMap GF shdP_K (w.E.SUM (splitHt cS f)))
    ((congrArg (msbBits 12) hmod).trans (msbBits_msbIndex 12 b))

theorem blk_aPl_limbA (b : Fin 14 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 6) 14 b = algebraMap GF shdP_K (w.limbA b) := by
  unfold aPl
  rw [aOff_shield, show shdARow 6 = 6 from rfl, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 6 14 .a (by norm_num) (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 14 b
  have hmod : msbIndex 14 b % 2 ^ 14 = msbIndex 14 b := by omega
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega), hmod, Fp.toGF_ofGF, msbBits_msbIndex 14 b]

theorem blk_aPl_limbM (b : Fin 14 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 7) 14 b = algebraMap GF shdP_K (w.limbM b) := by
  unfold aPl
  rw [aOff_shield, show shdARow 7 = 7 from rfl, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 7 14 .a (by norm_num) (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 14 b
  have hmod : msbIndex 14 b % 2 ^ 14 = msbIndex 14 b := by omega
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega),
    hmod, Fp.toGF_ofGF, msbBits_msbIndex 14 b]

theorem blk_aPl_plLA (i k : Fin 3) (t : Fin 7 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 6 + (3 * i.val + k.val) * 2 ^ 7) 7 t
      = algebraMap GF shdP_K (w.E.la i k t) := by
  have hi := i.isLt; have hk := k.isLt
  unfold aPl
  rw [aOff_shield, show shdARow 6 = 6 from rfl, show (2 : ℕ) ^ 7 = 128 by norm_num,
    planeZ_blkCmData_a,
    planeZ_subrow_eq 4577 14 6 ((3 * i.val + k.val) * 128) 7 .a (by norm_num) (by norm_num) (by omega)
      (tabMat 4577 14 (blkTA w rnd).rows) t,
    tabMat_blkTA]
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num),
    ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num),
    ite_eq_left rfl, Fp.toGF_ofGF, w.hLimbA i k t]

theorem blk_aPl_plLM (i k : Fin 3) (t : Fin 7 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 7 + (3 * i.val + k.val) * 2 ^ 7) 7 t
      = algebraMap GF shdP_K (w.E.lm i k t) := by
  have hi := i.isLt; have hk := k.isLt
  unfold aPl
  rw [aOff_shield, show shdARow 7 = 7 from rfl, show (2 : ℕ) ^ 7 = 128 by norm_num,
    planeZ_blkCmData_a,
    planeZ_subrow_eq 4577 14 7 ((3 * i.val + k.val) * 128) 7 .a (by norm_num) (by norm_num) (by omega)
      (tabMat 4577 14 (blkTA w rnd).rows) t,
    tabMat_blkTA]
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num),
    ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num),
    ite_eq_right (by norm_num), ite_eq_left rfl, Fp.toGF_ofGF, w.hLimbM i k t]

theorem blk_aPl_D (q : ℕ) (h1 : 8 ≤ q) (h2 : q < 47) (b : Fin 19 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) 19 b = algebraMap GF shdP_K (blkDomPlane w .D q b) := by
  have hrow : shdARow q = 8 + (q - 8) * 32 := by
    unfold shdARow shdPlaneDom
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left h2]
    rfl
  unfold aPl
  rw [aOff_shield, hrow, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 (8 + (q - 8) * 32) 19 .a (by show 8 + (q - 8) * 32 + 32 ≤ 4577; omega)
      (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 19 b
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_left (by omega), Fp.toGF_ofGF]
  have hq : 8 + (8 + (q - 8) * 32 + msbIndex 19 b / 2 ^ 14 - 8) / 32 = q := by omega
  have hidx : (8 + (q - 8) * 32 + msbIndex 19 b / 2 ^ 14 - 8) % 32 * 16384 + msbIndex 19 b % 2 ^ 14
      = msbIndex 19 b := by omega
  exact congrArg (algebraMap GF shdP_K)
    (congrArg₂ (blkDomPlane w .D) hq ((congrArg (msbBits 19) hidx).trans (msbBits_msbIndex 19 b)))

theorem blk_aPl_Q (q : ℕ) (h1 : 47 ≤ q) (h2 : q < 61) (b : Fin 19 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) 19 b = algebraMap GF shdP_K (blkDomPlane w .Q q b) := by
  have hrow : shdARow q = 1256 + (q - 47) * 32 := by
    unfold shdARow shdPlaneDom
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_left h2]
    rfl
  unfold aPl
  rw [aOff_shield, hrow, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 (1256 + (q - 47) * 32) 19 .a (by show 1256 + (q - 47) * 32 + 32 ≤ 4577; omega)
      (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 19 b
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_left (by omega), Fp.toGF_ofGF]
  have hq : 47 + (1256 + (q - 47) * 32 + msbIndex 19 b / 2 ^ 14 - 1256) / 32 = q := by omega
  have hidx : (1256 + (q - 47) * 32 + msbIndex 19 b / 2 ^ 14 - 1256) % 32 * 16384 + msbIndex 19 b % 2 ^ 14
      = msbIndex 19 b := by omega
  exact congrArg (algebraMap GF shdP_K)
    (congrArg₂ (blkDomPlane w .Q) hq ((congrArg (msbBits 19) hidx).trans (msbBits_msbIndex 19 b)))

theorem blk_aPl_Kv (q : ℕ) (h1 : 61 ≤ q) (h2 : q < 75) (b : Fin 17 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) 17 b = algebraMap GF shdP_K (blkDomPlane w .Kv q b) := by
  have hrow : shdARow q = 1704 + (q - 61) * 8 := by
    unfold shdARow shdPlaneDom
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left h2]
    rfl
  unfold aPl
  rw [aOff_shield, hrow, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 (1704 + (q - 61) * 8) 17 .a (by show 1704 + (q - 61) * 8 + 8 ≤ 4577; omega)
      (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 17 b
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega), Fp.toGF_ofGF]
  have hq : 61 + (1704 + (q - 61) * 8 + msbIndex 17 b / 2 ^ 14 - 1704) / 8 = q := by omega
  have hidx : (1704 + (q - 61) * 8 + msbIndex 17 b / 2 ^ 14 - 1704) % 8 * 16384 + msbIndex 17 b % 2 ^ 14
      = msbIndex 17 b := by omega
  exact congrArg (algebraMap GF shdP_K)
    (congrArg₂ (blkDomPlane w .Kv) hq ((congrArg (msbBits 17) hidx).trans (msbBits_msbIndex 17 b)))

theorem blk_aPl_S (q : ℕ) (h1 : 75 ≤ q) (h2 : q < 88) (b : Fin 19 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) 19 b = algebraMap GF shdP_K (blkDomPlane w .S q b) := by
  have hrow : shdARow q = 1816 + (q - 75) * 32 := by
    unfold shdARow shdPlaneDom
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left h2]
    rfl
  unfold aPl
  rw [aOff_shield, hrow, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 (1816 + (q - 75) * 32) 19 .a (by show 1816 + (q - 75) * 32 + 32 ≤ 4577; omega)
      (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 19 b
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega), Fp.toGF_ofGF]
  have hq : 75 + (1816 + (q - 75) * 32 + msbIndex 19 b / 2 ^ 14 - 1816) / 32 = q := by omega
  have hidx : (1816 + (q - 75) * 32 + msbIndex 19 b / 2 ^ 14 - 1816) % 32 * 16384 + msbIndex 19 b % 2 ^ 14
      = msbIndex 19 b := by omega
  exact congrArg (algebraMap GF shdP_K)
    (congrArg₂ (blkDomPlane w .S) hq ((congrArg (msbBits 19) hidx).trans (msbBits_msbIndex 19 b)))

theorem blk_aPl_F (q : ℕ) (h1 : 88 ≤ q) (h2 : q < 104) (b : Fin 21 → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) 21 b = algebraMap GF shdP_K (blkDomPlane w .F q b) := by
  have hrow : shdARow q = 2232 + (q - 88) * 128 := by
    unfold shdARow shdPlaneDom
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_left h2]
    rfl
  unfold aPl
  rw [aOff_shield, hrow, planeZ_blkCmData_a,
    planeZ_single_eq 4577 14 (2232 + (q - 88) * 128) 21 .a (by show 2232 + (q - 88) * 128 + 128 ≤ 4577; omega)
      (tabMat 4577 14 (blkTA w rnd).rows) b,
    tabMat_blkTA]
  have hb := msbIndex_lt 21 b
  unfold blkTAData; dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_left (by omega), Fp.toGF_ofGF]
  have hq : 88 + (2232 + (q - 88) * 128 + msbIndex 21 b / 2 ^ 14 - 2232) / 128 = q := by omega
  have hidx : (2232 + (q - 88) * 128 + msbIndex 21 b / 2 ^ 14 - 2232) % 128 * 16384 + msbIndex 21 b % 2 ^ 14
      = msbIndex 21 b := by omega
  exact congrArg (algebraMap GF shdP_K)
    (congrArg₂ (blkDomPlane w .F) hq ((congrArg (msbBits 21) hidx).trans (msbBits_msbIndex 21 b)))

theorem blk_multTabR_eq (k : Fin 3) (b : Fin 14 → Bool) :
    Exec.Block.Join.R13T.multTabR shdP_U cS P DS k.val b = (blkMult w (k, b) : shdP_K) := by
  unfold Exec.Block.Join.R13T.multTabR aPl
  rw [ids_eq_shield Ly, show (Exec.Block.DefR13.idsR13 true 2).t0 = 104 from rfl]
  have hb := msbIndex_lt 14 b
  have hmod : msbIndex 14 b % 2 ^ 14 = msbIndex 14 b := by omega
  rcases k with ⟨kv, hkv⟩
  dsimp only
  interval_cases kv
  · rw [show 104 + 0 = 104 from rfl, aOff_shield, show shdARow 104 = 4280 from rfl, planeZ_blkCmData_a,
      planeZ_single_eq 4577 14 4280 14 .a (by norm_num) (tabMat 4577 14 (blkTA w rnd).rows) b,
      tabMat_blkTA]
    unfold blkTAData; dsimp only
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_left (by omega), Fp.toGF_ofGF, map_natCast]
    unfold blkMultU8; dsimp only; rw [hmod, msbBits_msbIndex 14 b]
  · rw [show 104 + 1 = 105 from rfl, aOff_shield, show shdARow 105 = 4281 from rfl, planeZ_blkCmData_a,
      planeZ_single_eq 4577 14 4281 14 .a (by norm_num) (tabMat 4577 14 (blkTA w rnd).rows) b,
      tabMat_blkTA]
    unfold blkTAData; dsimp only
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega), Fp.toGF_ofGF, map_natCast]
    unfold blkMultExp; dsimp only; rw [hmod, msbBits_msbIndex 14 b]
  · rw [show 104 + 2 = 106 from rfl, aOff_shield, show shdARow 106 = 4282 from rfl, planeZ_blkCmData_a,
      planeZ_single_eq 4577 14 4282 14 .a (by norm_num) (tabMat 4577 14 (blkTA w rnd).rows) b,
      tabMat_blkTA]
    unfold blkTAData; dsimp only
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega),
      Fp.toGF_ofGF, map_natCast]
    unfold blkMultAct; dsimp only; rw [hmod, msbBits_msbIndex 14 b]

/-- Unified `A`-plane evaluator for all 6 lookup domains `d : Dm`. -/
theorem blk_aPl_dom (d : Dm) (q : ℕ) (h1 : shdDomStart d.dom ≤ q) (h2 : q < shdDomEnd d.dom)
    (b : Fin (d.log cS) → Bool) :
    aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) (d.log cS) b = algebraMap GF shdP_K (blkDomPlane w d q b) := by
  cases d with
  | L =>
    change 6 ≤ q at h1; change q < 8 at h2
    have hcases : q = 6 ∨ q = 7 := by omega
    rcases hcases with rfl | rfl
    · exact blk_aPl_limbA P hlc hep w rnd bga TB_prev TB_next b
    · exact blk_aPl_limbM P hlc hep w rnd bga TB_prev TB_next b
  | D => exact blk_aPl_D P hlc hep w rnd bga TB_prev TB_next q h1 h2 b
  | Q => exact blk_aPl_Q P hlc hep w rnd bga TB_prev TB_next q h1 h2 b
  | Kv => exact blk_aPl_Kv P hlc hep w rnd bga TB_prev TB_next q h1 h2 b
  | S => exact blk_aPl_S P hlc hep w rnd bga TB_prev TB_next q h1 h2 b
  | F => exact blk_aPl_F P hlc hep w rnd bga TB_prev TB_next q h1 h2 b

/-- **Universal `H`-plane evaluator** covering all 53 `H` planes (`hp < 53`), including `H_U` (`hp = 52`). -/
theorem blk_hPl_eq (hp : ℕ) (hhp : hp < 53) {log : ℕ} (hlog : log = shdHLog hp) (b : Fin log → Bool) :
    hPl shdP_U P DS (Exec.Block.DefR13.hOff cS hp).1 (Exec.Block.DefR13.hOff cS hp).2 log b
      = blkHValK w rnd bga hp (msbIndex log b) := by
  subst hlog
  have hge := shdHLog_ge14 hp
  have hpow : 2 ^ shdHLog hp / 2 ^ 14 = shdHRowsHalf hp := by
    rw [shdHRowsHalf_eq_pow]
    have hsplit : 2 ^ shdHLog hp = 2 ^ (shdHLog hp - 14) * 2 ^ 14 := by
      rw [← pow_add, show shdHLog hp - 14 + 14 = shdHLog hp by omega]
    rw [hsplit, Nat.mul_div_cancel _ (Nat.two_pow_pos 14)]
  have hpos : 1 ≤ shdHRowsHalf hp := by
    rw [shdHRowsHalf_eq_pow]; exact Nat.one_le_two_pow
  have hmax : max 1 (2 ^ shdHLog hp / 2 ^ 14) = shdHRowsHalf hp := by
    rw [hpow, max_eq_right hpos]
  have hbd := shdHReRow_bounds hp hhp
  have hre : shdHReRow hp + max 1 (2 ^ shdHLog hp / 2 ^ 14) ≤ 4390 := by omega
  have him : shdHReRow hp + shdHRowsHalf hp + max 1 (2 ^ shdHLog hp / 2 ^ 14) ≤ 4390 := by omega
  unfold hPl
  rw [hOff_shield, planeZ_blkCmData_h]
  dsimp only
  rw [planeZ_pair_eq 4390 14 (shdHReRow hp) (shdHReRow hp + shdHRowsHalf hp) (shdHLog hp) .h hge hre him
      (tabMat 4390 14 (blkTH w rnd bga).rows) b,
    tabMat_blkTH, tabMat_blkTH]
  have hdr : msbIndex (shdHLog hp) b / 2 ^ 14 < shdHRowsHalf hp := by
    have h := msbIndex_div_lt 14 (shdHLog hp) b; rwa [hmax] at h
  obtain ⟨hreLt, hreDec⟩ := shdHRowDecode_re hp (msbIndex (shdHLog hp) b / 2 ^ 14) hhp hdr
  obtain ⟨himLt, himDec⟩ := shdHRowDecode_im hp (msbIndex (shdHLog hp) b / 2 ^ 14) hhp hdr
  unfold blkTHData; dsimp only
  rw [ite_eq_left hreLt, ite_eq_left himLt, hreDec, himDec]
  dsimp only
  rw [ite_eq_right Bool.false_ne_true, ite_eq_left rfl]
  have hflat : msbIndex (shdHLog hp) b / 2 ^ 14 * 16384 + msbIndex (shdHLog hp) b % 2 ^ 14
      = msbIndex (shdHLog hp) b := by
    rw [show (2 : ℕ) ^ 14 = 16384 by norm_num, Nat.mul_comm, Nat.div_add_mod]
  rw [hflat]
  exact toK_ofK shdP_U shdP_hbij _

theorem blk_hPl_pair (d : Dm) (j : Fin (d.np 1)) (b : Fin (d.log cS) → Bool) :
    hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (d.fh 1 + j.val)).1
        (Exec.Block.DefR13.hOff cS (d.fh 1 + j.val)).2 (d.log cS) b
      = blkInvK bga (blkLkAtGF w d (2 * j.val) b) + blkInvK bga (blkLkAtGF w d (2 * j.val + 1) b) := by
  have hj := j.isLt
  cases d with
  | L =>
    have hj0 : j.val = 0 := by change j.val < 1 at hj; omega
    rw [blk_hPl_eq P hlc hep w rnd bga TB_prev TB_next (Dm.fh 1 .L + j.val) (by show 0 + j.val < 53; omega)
      (by unfold shdHLog domAt; rw [ite_eq_left (by show 0 + j.val < 1; omega)]; rfl) b]
    unfold blkHValK
    rw [ite_eq_left (by show 0 + j.val < 1; omega)]
    dsimp only
    have hb : msbBits 14 (msbIndex (Dm.log cS .L) b) = b := msbBits_msbIndex 14 b
    rw [hb, hj0, Nat.mul_zero, Nat.zero_add]
  | D =>
    change j.val < 17 at hj
    rw [blk_hPl_eq P hlc hep w rnd bga TB_prev TB_next (Dm.fh 1 .D + j.val) (by show 1 + j.val < 53; omega)
      (by unfold shdHLog domAt; rw [ite_eq_right (by show ¬ (1 + j.val < 1); omega),
            ite_eq_left (by show 1 + j.val < 18; omega)]; rfl) b]
    unfold blkHValK
    rw [ite_eq_right (by show ¬ (1 + j.val < 1); omega), ite_eq_left (by show 1 + j.val < 18; omega)]
    dsimp only
    have hb : msbBits 19 (msbIndex (Dm.log cS .D) b) = b := msbBits_msbIndex 19 b
    rw [hb, show Dm.fh 1 .D + j.val - 1 = j.val by show 1 + j.val - 1 = j.val; omega]
  | Q =>
    change j.val < 7 at hj
    rw [blk_hPl_eq P hlc hep w rnd bga TB_prev TB_next (Dm.fh 1 .Q + j.val) (by show 18 + j.val < 53; omega)
      (by unfold shdHLog domAt; rw [ite_eq_right (by show ¬ (18 + j.val < 1); omega),
            ite_eq_right (by show ¬ (18 + j.val < 18); omega),
            ite_eq_left (by show 18 + j.val < 25; omega)]; rfl) b]
    unfold blkHValK
    rw [ite_eq_right (by show ¬ (18 + j.val < 1); omega), ite_eq_right (by show ¬ (18 + j.val < 18); omega),
      ite_eq_left (by show 18 + j.val < 25; omega)]
    dsimp only
    have hb : msbBits 19 (msbIndex (Dm.log cS .Q) b) = b := msbBits_msbIndex 19 b
    rw [hb, show Dm.fh 1 .Q + j.val - 18 = j.val by show 18 + j.val - 18 = j.val; omega]
  | Kv =>
    change j.val < 7 at hj
    rw [blk_hPl_eq P hlc hep w rnd bga TB_prev TB_next (Dm.fh 1 .Kv + j.val) (by show 25 + j.val < 53; omega)
      (by unfold shdHLog domAt; rw [ite_eq_right (by show ¬ (25 + j.val < 1); omega),
            ite_eq_right (by show ¬ (25 + j.val < 18); omega),
            ite_eq_right (by show ¬ (25 + j.val < 25); omega),
            ite_eq_left (by show 25 + j.val < 32; omega)]; rfl) b]
    unfold blkHValK
    rw [ite_eq_right (by show ¬ (25 + j.val < 1); omega), ite_eq_right (by show ¬ (25 + j.val < 18); omega),
      ite_eq_right (by show ¬ (25 + j.val < 25); omega), ite_eq_left (by show 25 + j.val < 32; omega)]
    dsimp only
    have hb : msbBits 17 (msbIndex (Dm.log cS .Kv) b) = b := msbBits_msbIndex 17 b
    rw [hb, show Dm.fh 1 .Kv + j.val - 25 = j.val by show 25 + j.val - 25 = j.val; omega]
  | S =>
    change j.val < 7 at hj
    rw [blk_hPl_eq P hlc hep w rnd bga TB_prev TB_next (Dm.fh 1 .S + j.val) (by show 32 + j.val < 53; omega)
      (by unfold shdHLog domAt; rw [ite_eq_right (by show ¬ (32 + j.val < 1); omega),
            ite_eq_right (by show ¬ (32 + j.val < 18); omega),
            ite_eq_right (by show ¬ (32 + j.val < 25); omega),
            ite_eq_right (by show ¬ (32 + j.val < 32); omega),
            ite_eq_left (by show 32 + j.val < 40 + 1; omega)]; rfl) b]
    unfold blkHValK
    rw [ite_eq_right (by show ¬ (32 + j.val < 1); omega), ite_eq_right (by show ¬ (32 + j.val < 18); omega),
      ite_eq_right (by show ¬ (32 + j.val < 25); omega), ite_eq_right (by show ¬ (32 + j.val < 32); omega),
      ite_eq_left (by show 32 + j.val < 39; omega)]
    dsimp only
    have hb : msbBits 19 (msbIndex (Dm.log cS .S) b) = b := msbBits_msbIndex 19 b
    rw [hb, show Dm.fh 1 .S + j.val - 32 = j.val by show 32 + j.val - 32 = j.val; omega]
  | F =>
    change j.val < 7 at hj
    rw [blk_hPl_eq P hlc hep w rnd bga TB_prev TB_next (Dm.fh 1 .F + j.val) (by show 40 + 1 + j.val < 53; omega)
      (by unfold shdHLog domAt; rw [ite_eq_right (by show ¬ (40 + 1 + j.val < 1); omega),
            ite_eq_right (by show ¬ (40 + 1 + j.val < 18); omega),
            ite_eq_right (by show ¬ (40 + 1 + j.val < 25); omega),
            ite_eq_right (by show ¬ (40 + 1 + j.val < 32); omega),
            ite_eq_right (by show ¬ (40 + 1 + j.val < 40 + 1); omega),
            ite_eq_left (by show 40 + 1 + j.val < 48 + 1; omega)]; rfl) b]
    unfold blkHValK
    rw [ite_eq_right (by show ¬ (40 + 1 + j.val < 1); omega), ite_eq_right (by show ¬ (40 + 1 + j.val < 18); omega),
      ite_eq_right (by show ¬ (40 + 1 + j.val < 25); omega), ite_eq_right (by show ¬ (40 + 1 + j.val < 32); omega),
      ite_eq_right (by show ¬ (40 + 1 + j.val < 39); omega), ite_eq_right (by show ¬ (40 + 1 + j.val = 39); omega),
      ite_eq_right (by show ¬ (40 + 1 + j.val = 40); omega), ite_eq_left (by show 40 + 1 + j.val < 48; omega)]
    dsimp only
    have hb : msbBits 21 (msbIndex (Dm.log cS .F) b) = b := msbBits_msbIndex 21 b
    rw [hb, show Dm.fh 1 .F + j.val - 41 = j.val by show 40 + 1 + j.val - 41 = j.val; omega]

theorem blk_hPl_sg (s : Sg) (b : Fin (s.log cS) → Bool) :
    hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (s.hp 1)).1 (Exec.Block.DefR13.hOff cS (s.hp 1)).2 (s.log cS) b
      = blkInvK bga (blkSgTupGF w s b) := by
  cases s with
  | S =>
    rw [show Sg.hp 1 .S = 39 from rfl,
      blk_hPl_eq P hlc hep w rnd bga TB_prev TB_next 39 (by norm_num) (log := Sg.log cS .S) rfl b]
    unfold blkHValK
    rw [ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num),
      ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_left rfl]
    have hb : msbBits 19 (msbIndex (Sg.log cS .S) b) = b := msbBits_msbIndex 19 b
    rw [hb]
  | Exp =>
    rw [show Sg.hp 1 .Exp = 40 from rfl,
      blk_hPl_eq P hlc hep w rnd bga TB_prev TB_next 40 (by norm_num) (log := Sg.log cS .Exp) rfl b]
    unfold blkHValK
    rw [ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num),
      ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_left rfl]
    have hb : msbBits 19 (msbIndex (Sg.log cS .Exp) b) = b := msbBits_msbIndex 19 b
    rw [hb]
  | Act =>
    rw [show Sg.hp 1 .Act = 48 from rfl,
      blk_hPl_eq P hlc hep w rnd bga TB_prev TB_next 48 (by norm_num) (log := Sg.log cS .Act) rfl b]
    unfold blkHValK
    rw [ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num),
      ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num),
      ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_left rfl]
    have hb : msbBits 21 (msbIndex (Sg.log cS .Act) b) = b := msbBits_msbIndex 21 b
    rw [hb]

theorem blk_helpTabR_eq (k : Fin 3) (b : Fin 14 → Bool) :
    Exec.Block.Join.R13T.helpTabR shdP_U cS P DS k.val b
      = (blkMult w (k, b) : shdP_K) * blkInvK bga (tabTupE Pb.exp Pb.act Ly.nG k.val (msbIndex 14 b)) := by
  unfold Exec.Block.Join.R13T.helpTabR
  have hf8 : Exec.Block.DefR13.fh cS 8 = 49 := (fh_eq (lookCfg_shield Ly)).2.2.2.2.2.2.2.2.1
  rw [hf8]
  have hk := k.isLt
  rw [blk_hPl_eq P hlc hep w rnd bga TB_prev TB_next (49 + k.val) (by omega)
    (by unfold shdHLog domAt; rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
          ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega)]; rfl) b]
  unfold blkHValK
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    dite_eq_left (by omega), msbBits_msbIndex 14 b]
  rw [show (⟨49 + k.val - 49, by omega⟩ : Fin 3) = k from Fin.ext (by dsimp only; omega),
    show 49 + k.val - 49 = k.val by omega]

theorem blk_hPl_hU (b : Fin 14 → Bool) :
    hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (Exec.Block.DefR13.fh cS 10)).1
        (Exec.Block.DefR13.hOff cS (Exec.Block.DefR13.fh cS 10)).2 14 b
      = algebraMap GF shdP_K (blkHUVal rnd ⟨msbIndex 14 b, msbIndex_lt 14 b⟩).1
        + shdP_U * algebraMap GF shdP_K (blkHUVal rnd ⟨msbIndex 14 b, msbIndex_lt 14 b⟩).2 := by
  have hf10 : Exec.Block.DefR13.fh cS 10 = 52 := (fh_eq (lookCfg_shield Ly)).2.2.2.2.2.2.2.2.2
  rw [hf10, blk_hPl_eq P hlc hep w rnd bga TB_prev TB_next 52 (by norm_num) (log := 14) rfl b]
  unfold blkHValK
  rw [ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num),
    ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num),
    ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_right (by norm_num),
    dite_eq_right (by norm_num), ite_eq_left rfl]
  dsimp only
  have hm : (⟨msbIndex 14 b % 16384, Nat.mod_lt _ (by norm_num)⟩ : Fin 16384)
      = ⟨msbIndex 14 b, msbIndex_lt 14 b⟩ := Fin.ext (Nat.mod_eq_of_lt (msbIndex_lt 14 b))
  rw [hm]

/-! ### `blk_xtR_eq_E` (`xtR` recovers `w.E` verbatim) and `blk_AlkR13_eq_blkLkTup` -/

private theorem plD_blk (q : ℕ) (h1 : 8 ≤ q) (h2 : q < 47) (x : CtR cS × CwR cS) :
    plD shdP_U cS P DS (offR cS q) x = blkDomPlane w .D q (Fin.append x.1 x.2) := by
  unfold plD offR
  exact (congrArg (piB shdP_K) (blk_aPl_D P hlc hep w rnd bga TB_prev TB_next q h1 h2 (Fin.append x.1 x.2))).trans
    (piB_alg _)

private theorem plQ_blk (q : ℕ) (h1 : 47 ≤ q) (h2 : q < 61) (x : CtR cS × ((CgR cS × CjR cS) × CdR cS)) :
    plQ shdP_U cS P DS (offR cS q) x = blkDomPlane w .Q q (Fin.append x.1 (Fin.append (Fin.append x.2.1.1 x.2.1.2) x.2.2)) := by
  unfold plQ offR
  exact (congrArg (piB shdP_K)
    (blk_aPl_Q P hlc hep w rnd bga TB_prev TB_next q h1 h2
      (Fin.append x.1 (Fin.append (Fin.append x.2.1.1 x.2.1.2) x.2.2)))).trans (piB_alg _)

private theorem plK_blk (q : ℕ) (h1 : 61 ≤ q) (h2 : q < 75) (x : CtR cS × (CgR cS × CdR cS)) :
    Exec.Block.Join.R13H.plK shdP_U cS P DS (offR cS q) x = blkDomPlane w .Kv q (Fin.append x.1 (Fin.append x.2.1 x.2.2)) := by
  unfold Exec.Block.Join.R13H.plK offR
  exact (congrArg (piB shdP_K)
    (blk_aPl_Kv P hlc hep w rnd bga TB_prev TB_next q h1 h2
      (Fin.append x.1 (Fin.append x.2.1 x.2.2)))).trans (piB_alg _)

private theorem plS_blk (q : ℕ) (h1 : 75 ≤ q) (h2 : q < 88) (x : (CgR cS × CjR cS) × CtR cS × CtR cS) :
    plS shdP_U cS P DS (offR cS q) x = blkDomPlane w .S q (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2)) := by
  unfold plS offR
  exact (congrArg (piB shdP_K)
    (blk_aPl_S P hlc hep w rnd bga TB_prev TB_next q h1 h2
      (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2)))).trans (piB_alg _)

private theorem plF_blk (q : ℕ) (h1 : 88 ≤ q) (h2 : q < 104) (x : CtR cS × CfR cS) :
    plF shdP_U cS P DS (offR cS q) x = blkDomPlane w .F q (Fin.append x.1 x.2) := by
  unfold plF offR
  exact (congrArg (piB shdP_K) (blk_aPl_F P hlc hep w rnd bga TB_prev TB_next q h1 h2 (Fin.append x.1 x.2))).trans
    (piB_alg _)

/-- **Exact witness extraction**: `xtR` read off `blkCmData` equals `w.E` verbatim on all 63 fields! -/
theorem blk_xtR_eq_E : xtR shdP_U cS P DS 1 = w.E := by
  conv_rhs =>
    rw [show w.E =
      { dA := w.E.dA, dsqA := w.E.dsqA, dM := w.E.dM, dsqM := w.E.dsqM, la := w.E.la, lm := w.E.lm,
        X := w.E.X, Y := w.E.Y, AO := w.E.AO, X1 := w.E.X1, YM := w.E.YM, Z := w.E.Z, X2 := w.E.X2,
        xl := w.E.xl, yl := w.E.yl, aol := w.E.aol, x1l := w.E.x1l, yml := w.E.yml, zl := w.E.zl, x2l := w.E.x2l,
        nr := w.E.nr, ns := w.E.ns, mr := w.E.mr, ms := w.E.ms, ral := w.E.ral, rdl := w.E.rdl,
        Q := w.E.Q, QR := w.E.QR, O := w.E.O, ql := w.E.ql, qrl := w.E.qrl, ol := w.E.ol,
        rql := w.E.rql, rqrl := w.E.rqrl, ro := w.E.ro,
        K := w.E.K, KR := w.E.KR, V := w.E.V, kl := w.E.kl, krl := w.E.krl, vl := w.E.vl,
        rkl := w.E.rkl, rkrl := w.E.rkrl, rvl := w.E.rvl,
        S8 := w.E.S8, ZSEL := w.E.ZSEL, E := w.E.E, PP := w.E.PP, rsl := w.E.rsl, pl := w.E.pl,
        sr := w.E.sr, sg := w.E.sg, MX := w.E.MX, SUM := w.E.SUM,
        G := w.E.G, A := w.E.A, U := w.E.U, H := w.E.H,
        rgl := w.E.rgl, ul := w.E.ul, ru := w.E.ru, hl := w.E.hl, rh := w.E.rh } from rfl]
  unfold xtR
  rw [R13Data.mk.injEq]
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_,
    ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_,
    ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · funext t; unfold plT offR; exact (congrArg (piB shdP_K) (blk_aPl_T0 P hlc hep w rnd bga TB_prev TB_next t)).trans (piB_alg _)
  · funext t; unfold plT offR; exact (congrArg (piB shdP_K) (blk_aPl_T1 P hlc hep w rnd bga TB_prev TB_next t)).trans (piB_alg _)
  · funext t; unfold plT offR; exact (congrArg (piB shdP_K) (blk_aPl_T2 P hlc hep w rnd bga TB_prev TB_next t)).trans (piB_alg _)
  · funext t; unfold plT offR; exact (congrArg (piB shdP_K) (blk_aPl_T3 P hlc hep w rnd bga TB_prev TB_next t)).trans (piB_alg _)
  · funext i k t; unfold plL offR; exact (congrArg (piB shdP_K) (blk_aPl_plLA P hlc hep w rnd bga TB_prev TB_next i k t)).trans (piB_alg _)
  · funext i k t; unfold plL offR; exact (congrArg (piB shdP_K) (blk_aPl_plLM P hlc hep w rnd bga TB_prev TB_next i k t)).trans (piB_alg _)
  · funext x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next 8 (by norm_num) (by norm_num)]; exact congrArg w.E.X (splitD_append cS x)
  · funext x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next 11 (by norm_num) (by norm_num)]; exact congrArg w.E.Y (splitD_append cS x)
  · funext x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next 20 (by norm_num) (by norm_num)]; exact congrArg w.E.AO (splitD_append cS x)
  · funext x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next 26 (by norm_num) (by norm_num)]; exact congrArg w.E.X1 (splitD_append cS x)
  · funext x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next 29 (by norm_num) (by norm_num)]; exact congrArg w.E.YM (splitD_append cS x)
  · funext x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next 38 (by norm_num) (by norm_num)]; exact congrArg w.E.Z (splitD_append cS x)
  · funext x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next 44 (by norm_num) (by norm_num)]; exact congrArg w.E.X2 (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (9 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.xl _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (12 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.yl _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (21 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.aol _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (27 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.x1l _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (30 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.yml _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (39 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.zl _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (45 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.x2l _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (14 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.nr _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (17 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.ns _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (32 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.mr _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (35 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.ms _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (23 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.ral _) (splitD_append cS x)
  · funext k x; rw [plD_blk P hlc hep w rnd bga TB_prev TB_next (41 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.rdl _) (splitD_append cS x)
  · funext x; rw [plQ_blk P hlc hep w rnd bga TB_prev TB_next 47 (by norm_num) (by norm_num)]; exact congrArg w.E.Q (splitQ_append cS x)
  · funext x; rw [plQ_blk P hlc hep w rnd bga TB_prev TB_next 52 (by norm_num) (by norm_num)]; exact congrArg w.E.QR (splitQ_append cS x)
  · funext x; rw [plQ_blk P hlc hep w rnd bga TB_prev TB_next 56 (by norm_num) (by norm_num)]; exact congrArg w.E.O (splitQ_append cS x)
  · funext k x; rw [plQ_blk P hlc hep w rnd bga TB_prev TB_next (48 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.ql _) (splitQ_append cS x)
  · funext k x; rw [plQ_blk P hlc hep w rnd bga TB_prev TB_next (53 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.qrl _) (splitQ_append cS x)
  · funext k x; rw [plQ_blk P hlc hep w rnd bga TB_prev TB_next (57 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.ol _) (splitQ_append cS x)
  · funext k x; rw [plQ_blk P hlc hep w rnd bga TB_prev TB_next (50 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.rql _) (splitQ_append cS x)
  · funext k x; rw [plQ_blk P hlc hep w rnd bga TB_prev TB_next (55 + k) (by omega) (by omega)]; fin_cases k; exact congrArg (w.E.rqrl _) (splitQ_append cS x)
  · funext k x; rw [plQ_blk P hlc hep w rnd bga TB_prev TB_next (59 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.ro _) (splitQ_append cS x)
  · funext x; rw [plK_blk P hlc hep w rnd bga TB_prev TB_next 61 (by norm_num) (by norm_num)]; exact congrArg w.E.K (splitK_append cS x)
  · funext x; rw [plK_blk P hlc hep w rnd bga TB_prev TB_next 71 (by norm_num) (by norm_num)]; exact congrArg w.E.KR (splitK_append cS x)
  · funext x; rw [plK_blk P hlc hep w rnd bga TB_prev TB_next 66 (by norm_num) (by norm_num)]; exact congrArg w.E.V (splitK_append cS x)
  · funext k x; rw [plK_blk P hlc hep w rnd bga TB_prev TB_next (62 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.kl _) (splitK_append cS x)
  · funext k x; rw [plK_blk P hlc hep w rnd bga TB_prev TB_next (72 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.krl _) (splitK_append cS x)
  · funext k x; rw [plK_blk P hlc hep w rnd bga TB_prev TB_next (67 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.vl _) (splitK_append cS x)
  · funext k x; rw [plK_blk P hlc hep w rnd bga TB_prev TB_next (64 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.rkl _) (splitK_append cS x)
  · funext k x; rw [plK_blk P hlc hep w rnd bga TB_prev TB_next (74 + k) (by omega) (by omega)]; fin_cases k; exact congrArg (w.E.rkrl _) (splitK_append cS x)
  · funext k x; rw [plK_blk P hlc hep w rnd bga TB_prev TB_next (69 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.rvl _) (splitK_append cS x)
  · funext x; rw [plS_blk P hlc hep w rnd bga TB_prev TB_next 75 (by norm_num) (by norm_num)]; exact congrArg w.E.S8 (splitS_append cS x)
  · funext x; rw [plS_blk P hlc hep w rnd bga TB_prev TB_next 79 (by norm_num) (by norm_num)]; exact congrArg w.E.ZSEL (splitS_append cS x)
  · funext x; rw [plS_blk P hlc hep w rnd bga TB_prev TB_next 80 (by norm_num) (by norm_num)]; exact congrArg w.E.E (splitS_append cS x)
  · funext x; rw [plS_blk P hlc hep w rnd bga TB_prev TB_next 81 (by norm_num) (by norm_num)]; exact congrArg w.E.PP (splitS_append cS x)
  · funext k x; rw [plS_blk P hlc hep w rnd bga TB_prev TB_next (76 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.rsl _) (splitS_append cS x)
  · funext k x; rw [plS_blk P hlc hep w rnd bga TB_prev TB_next (82 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.pl _) (splitS_append cS x)
  · funext k x; rw [plS_blk P hlc hep w rnd bga TB_prev TB_next (84 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.sr _) (splitS_append cS x)
  · funext k x; rw [plS_blk P hlc hep w rnd bga TB_prev TB_next (84 + (1 + 1) + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.sg _) (splitS_append cS x)
  · funext x; unfold plH offR
    exact ((congrArg (piB shdP_K)
      (blk_aPl_MX P hlc hep w rnd bga TB_prev TB_next (Fin.append (Fin.append x.1.1 x.1.2) x.2))).trans
      (piB_alg _)).trans (congrArg w.E.MX (splitHt_append cS x))
  · funext x; unfold plH offR
    exact ((congrArg (piB shdP_K)
      (blk_aPl_SUM P hlc hep w rnd bga TB_prev TB_next (Fin.append (Fin.append x.1.1 x.1.2) x.2))).trans
      (piB_alg _)).trans (congrArg w.E.SUM (splitHt_append cS x))
  · funext x; rw [plF_blk P hlc hep w rnd bga TB_prev TB_next (86 + 2 * 1) (by norm_num) (by norm_num)]; exact congrArg w.E.G (splitF_append cS x)
  · funext x; rw [plF_blk P hlc hep w rnd bga TB_prev TB_next (86 + 2 * 1 + 4) (by norm_num) (by norm_num)]; exact congrArg w.E.A (splitF_append cS x)
  · funext x; rw [plF_blk P hlc hep w rnd bga TB_prev TB_next (86 + 2 * 1 + 5) (by norm_num) (by norm_num)]; exact congrArg w.E.U (splitF_append cS x)
  · funext x; rw [plF_blk P hlc hep w rnd bga TB_prev TB_next (86 + 2 * 1 + 10) (by norm_num) (by norm_num)]; exact congrArg w.E.H (splitF_append cS x)
  · funext k x; rw [plF_blk P hlc hep w rnd bga TB_prev TB_next (86 + 2 * 1 + 1 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.rgl _) (splitF_append cS x)
  · funext k x; rw [plF_blk P hlc hep w rnd bga TB_prev TB_next (86 + 2 * 1 + 6 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.ul _) (splitF_append cS x)
  · funext k x; rw [plF_blk P hlc hep w rnd bga TB_prev TB_next (86 + 2 * 1 + 8 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.ru _) (splitF_append cS x)
  · funext k x; rw [plF_blk P hlc hep w rnd bga TB_prev TB_next (86 + 2 * 1 + 11 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.hl _) (splitF_append cS x)
  · funext k x; rw [plF_blk P hlc hep w rnd bga TB_prev TB_next (86 + 2 * 1 + 14 + k) (by omega) (by omega)]; fin_cases k <;> exact congrArg (w.E.rh _) (splitF_append cS x)

private theorem blk_lk_term_bounds (d : Dm) (l : LkW) (hl : l ∈ Exec.Block.DefR13.lookups cS d.dom)
    (t : ℕ × ℤ) (ht : t ∈ l.terms) : shdDomStart d.dom ≤ t.1 ∧ t.1 < shdDomEnd d.dom := by
  have hc := lookCfg_shield Ly
  cases d with
  | L =>
    rw [show Dm.L.dom = Dom.L from rfl, hc.lkL] at hl
    simp only [lkLe, bLk, List.mem_cons, List.not_mem_nil, or_false] at hl
    rcases hl with rfl | rfl <;> (simp only [List.mem_singleton] at ht; subst ht; decide)
  | D =>
    rw [show Dm.D.dom = Dom.D from rfl, hc.lkD] at hl
    obtain ⟨h1, h2⟩ := Exec.Block.Join.R13H.LookRel.planesD (cS).p l hl t ht
    change 8 ≤ t.1 ∧ t.1 < 47; omega
  | Q =>
    rw [show Dm.Q.dom = Dom.Q from rfl, hc.lkQ] at hl
    obtain ⟨h1, h2⟩ := Exec.Block.Join.R13H.LookRel.planesQ (cS).p l hl t ht
    change 47 ≤ t.1 ∧ t.1 < 61; omega
  | Kv =>
    rw [show Dm.Kv.dom = Dom.Kv from rfl, hc.lkK] at hl
    obtain ⟨h1, h2⟩ := Exec.Block.Join.R13H.LookRel.planesK (cS).p l hl t ht
    change 61 ≤ t.1 ∧ t.1 < 75; omega
  | S =>
    rw [show Dm.S.dom = Dom.S from rfl, hc.lkS] at hl
    obtain ⟨h1, h2⟩ := Exec.Block.Join.R13H.LookRel.planesS (cS).p 1 l hl t ht
    change 75 ≤ t.1 ∧ t.1 < 88; omega
  | F =>
    rw [show Dm.F.dom = Dom.F from rfl, hc.lkF] at hl
    obtain ⟨h1, h2⟩ := Exec.Block.Join.R13H.LookRel.planesF (cS).p 1 l hl t ht
    change 88 ≤ t.1 ∧ t.1 < 104; omega

/-- **Exact bridge `AlkR13 = tupK ∘ blkLkTup`** on `blkCmData`. -/
theorem blk_AlkR13_eq_blkLkTup (l : BlkLkIx Ly) :
    AlkR13 shdP_U cS P Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (geoShield Ly)
        (fun (_ : List (QB 0 × Dig)) => DS) [] l
      = tupK (blkLkTup w l) := by
  refine blkLkTup_eq_AlkR13 w P (fun (_ : List (QB 0 × Dig)) => DS) []
    (fun d i hi t ht b => ?_)
    (blk_aPl_MX P hlc hep w rnd bga TB_prev TB_next)
    (blk_aPl_S P hlc hep w rnd bga TB_prev TB_next 75 (by norm_num) (by norm_num))
    (blk_aPl_S P hlc hep w rnd bga TB_prev TB_next 80 (by norm_num) (by norm_num))
    (blk_aPl_F P hlc hep w rnd bga TB_prev TB_next 88 (by norm_num) (by norm_num))
    (blk_aPl_F P hlc hep w rnd bga TB_prev TB_next 92 (by norm_num) (by norm_num))
    l
  have hmem : (Exec.Block.DefR13.lookups cS d.dom).getD i ⟨[], 0, 0⟩ ∈ Exec.Block.DefR13.lookups cS d.dom := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi, Option.getD_some]
    exact List.getElem_mem hi
  obtain ⟨h1, h2⟩ := blk_lk_term_bounds d _ hmem t ht
  exact blk_aPl_dom P hlc hep w rnd bga TB_prev TB_next d t.1 h1 h2 b

theorem blk_lkAtR_eq (d : Dm) (i : ℕ) (hi : i < (Exec.Block.DefR13.lookups cS d.dom).length)
    (b : Fin (d.log cS) → Bool) :
    lkAtR shdP_U cS P DS d i b = tupK (blkLkAtGF w d i b) := by
  have hc := lookCfg_shield Ly
  have hlen := lkLen hc d
  by_cases hlt : i / 2 < d.np 1
  · by_cases heven : i % 2 = 0
    · have h := blk_AlkR13_eq_blkLkTup P hlc hep w rnd bga TB_prev TB_next (.inr (.inl ⟨d, ⟨i / 2, hlt⟩, b⟩))
      dsimp only [AlkR13, blkLkTup] at h
      rwa [show 2 * (i / 2) = i by omega] at h
    · have h := blk_AlkR13_eq_blkLkTup P hlc hep w rnd bga TB_prev TB_next (.inr (.inr ⟨d, ⟨i / 2, hlt⟩, b⟩))
      dsimp only [AlkR13, blkLkTup] at h
      rwa [show 2 * (i / 2) + 1 = i by omega] at h
  · cases d with
    | L | D | Q | Kv | F =>
      simp [Dm.np] at hlen hlt; omega
    | S =>
      have hiEq : i = 2 * Dm.np 1 .S := by simp [Dm.np] at hlen hlt ⊢; omega
      rw [hiEq]
      exact blk_AlkR13_eq_blkLkTup P hlc hep w rnd bga TB_prev TB_next (.inl ⟨.S, b⟩)

theorem blk_expTupR_eq (b : Fin 19 → Bool) :
    expTupR shdP_U cS P DS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (geoShield Ly) b
      = tupK (blkExpTupGF w b) :=
  blk_AlkR13_eq_blkLkTup P hlc hep w rnd bga TB_prev TB_next (.inl ⟨.Exp, b⟩)

theorem blk_actTupR_eq (b : Fin 21 → Bool) :
    actTupR shdP_U cS P DS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (geoShield Ly) b
      = tupK (blkActTupGF w b) :=
  blk_AlkR13_eq_blkLkTup P hlc hep w rnd bga TB_prev TB_next (.inl ⟨.Act, b⟩)

end ConcretePlaneAccessors

end PlaneEvaluators

/-! ## 6. Zero-Vanishing Theorems (`xcR`, `pwcR`, `SC_LZC`, `SC_TAB`, `SC_ZS`, `SC_IOIN`, `SC_IOOUT`) -/

section HostAndStandaloneVanishing

/-- Reverse of `Exec.Block.Join.W16.Look.host_pair`: if `HelperRel`'s pair equation holds, `lkRels` entry `j` vanishes. -/
theorem host_pair_eq_zero {K : Type} [Field K] [Algebra GF K] (U : K) (bga : Fp2 × Fp2 × Fp2)
    (hα : bga.2.2.Canon) (k : ℕ) (shaped : ℕ → ℕ) (L : List LkW) (v : List K) (pl : ℕ → K)
    (h0 : ℕ) (hp : K) (j : ℕ) (hj : 2 * j + 1 < L.length) (hB : ∀ l ∈ L, Exec.Block.Join.W16.Look.LkOK l)
    (hv : ∀ l ∈ L, ∀ t ∈ l.terms, v.getD (shaped t.1) 0 = pl t.1) (hh : v.getD (h0 + 0 + j) 0 = hp)
    (hpair : hp * ((bga.2.2.toK U - fold (bga.1.toK U) (bga.2.1.toK U)
          (Exec.Block.Join.W16.Look.lkTupP pl (L.getD (2 * j) ⟨[], 0, 0⟩)))
        * (bga.2.2.toK U - fold (bga.1.toK U) (bga.2.1.toK U)
          (Exec.Block.Join.W16.Look.lkTupP pl (L.getD (2 * j + 1) ⟨[], 0, 0⟩))))
      = (bga.2.2.toK U - fold (bga.1.toK U) (bga.2.1.toK U)
          (Exec.Block.Join.W16.Look.lkTupP pl (L.getD (2 * j) ⟨[], 0, 0⟩)))
        + (bga.2.2.toK U - fold (bga.1.toK U) (bga.2.1.toK U)
          (Exec.Block.Join.W16.Look.lkTupP pl (L.getD (2 * j + 1) ⟨[], 0, 0⟩)))) :
    (lkRels (cstK U) v h0 0 (Exec.Block.Join.W16.Look.lksAt U k shaped L bga)).getD j 0 = 0 := by
  have hlen : 2 * j + 1 < (Exec.Block.Join.W16.Look.lksAt U k shaped L bga).length := by
    unfold Exec.Block.Join.W16.Look.lksAt; simp only [List.length_map]; exact hj
  unfold Exec.Block.Join.W16.Look.lksAt at hlen ⊢
  rw [Exec.Block.Join.W16.Look.relLk_pair (cstK U) v h0
      (Exec.Slot.Build.LkD.map (Fp2.toK U)
        (Exec.Slot.Build.LkD.map (Block.Sym.eval (Block.histOf bga.1 bga.2.1 bga.2.2 []) k [])
          (Exec.Block.Join.W16.Look.lkSymW shaped ⟨[], 0, 0⟩)))
      j 0 _ hlen, Exec.Block.Join.W16.Look.lks_getD, Exec.Block.Join.W16.Look.lks_getD, hh]
  have hB1 := Exec.Block.Join.W16.Look.lkOK_getD L hB (2 * j)
  have hB2 := Exec.Block.Join.W16.Look.lkOK_getD L hB (2 * j + 1)
  rw [Exec.Block.Join.W16.Look.denV_lkSym U (Block.histOf bga.1 bga.2.1 bga.2.2 []) hα k [] shaped _
      hB1.1 hB1.2.1 hB1.2.2.1 hB1.2.2.2 v pl (Exec.Block.Join.W16.Look.terms_getD L _ hv (2 * j)),
    Exec.Block.Join.W16.Look.denV_lkSym U (Block.histOf bga.1 bga.2.1 bga.2.2 []) hα k [] shaped _
      hB2.1 hB2.2.1 hB2.2.2.1 hB2.2.2.2 v pl (Exec.Block.Join.W16.Look.terms_getD L _ hv (2 * j + 1)),
    (Exec.Slot.Compose.cstW_map_std U).one, (Exec.Slot.Compose.cstW_map_std U).negOne]
  dsimp only [Block.histOf]
  linear_combination hpair

/-- Reverse of `Exec.Block.Join.W16.Look.host_single`: if `HelperRel`'s single equation holds, `lkRels` entry `m` vanishes. -/
theorem host_single_eq_zero {K : Type} [Field K] [Algebra GF K] (U : K) (bga : Fp2 × Fp2 × Fp2)
    (hα : bga.2.2.Canon) (k : ℕ) (shaped : ℕ → ℕ) (L : List LkW) (v : List K) (pl : ℕ → K)
    (h0 : ℕ) (hp : K) (m : ℕ) (hm : L.length = 2 * m + 1) (hB : ∀ l ∈ L, Exec.Block.Join.W16.Look.LkOK l)
    (hv : ∀ l ∈ L, ∀ t ∈ l.terms, v.getD (shaped t.1) 0 = pl t.1) (hh : v.getD (h0 + 0 + m) 0 = hp)
    (hsingle : hp * (bga.2.2.toK U - fold (bga.1.toK U) (bga.2.1.toK U)
        (Exec.Block.Join.W16.Look.lkTupP pl (L.getD (2 * m) ⟨[], 0, 0⟩))) = 1) :
    (lkRels (cstK U) v h0 0 (Exec.Block.Join.W16.Look.lksAt U k shaped L bga)).getD m 0 = 0 := by
  have hlen : (Exec.Block.Join.W16.Look.lksAt U k shaped L bga).length = 2 * m + 1 := by
    unfold Exec.Block.Join.W16.Look.lksAt; simp only [List.length_map]; exact hm
  unfold Exec.Block.Join.W16.Look.lksAt at hlen ⊢
  rw [Exec.Block.Join.W16.Look.relLk_single (cstK U) v h0
      (Exec.Slot.Build.LkD.map (Fp2.toK U)
        (Exec.Slot.Build.LkD.map (Block.Sym.eval (Block.histOf bga.1 bga.2.1 bga.2.2 []) k [])
          (Exec.Block.Join.W16.Look.lkSymW shaped ⟨[], 0, 0⟩)))
      m 0 _ hlen, Exec.Block.Join.W16.Look.lks_getD, hh]
  have hB1 := Exec.Block.Join.W16.Look.lkOK_getD L hB (2 * m)
  rw [Exec.Block.Join.W16.Look.denV_lkSym U (Block.histOf bga.1 bga.2.1 bga.2.2 []) hα k [] shaped _
      hB1.1 hB1.2.1 hB1.2.2.1 hB1.2.2.2 v pl (Exec.Block.Join.W16.Look.terms_getD L _ hv (2 * m)),
    (Exec.Slot.Compose.cstW_map_std U).one, (Exec.Slot.Compose.cstW_map_std U).negOne]
  dsimp only [Block.histOf]
  linear_combination hsingle

private theorem pair_inv_eq {a b : shdP_K} (ha : a ≠ 0) (hb : b ≠ 0) :
    (a⁻¹ + b⁻¹) * (a * b) = a + b := by
  calc (a⁻¹ + b⁻¹) * (a * b) = (a⁻¹ * a) * b + a * (b⁻¹ * b) := by ring
    _ = 1 * b + a * 1 := by rw [inv_mul_cancel₀ ha, inv_mul_cancel₀ hb]
    _ = a + b := by ring

private theorem valsFR_getD_3 {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    (P : BlockParams) (D : CmData shdP_K P) (B : Layout.W16Pub (shieldShape Ly) Pb (shdP_bitLay Ly))
    (b : Fin ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) → Bool) :
    (Exec.Block.Join.R13H.Fzc.valsFR shdP_U (geoShield Ly) P D B b).getD 3 0
      = aPl shdP_U P D (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) (86 + 2 * 1))
          ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) b := rfl

private theorem valsFR_getD_7 {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    (P : BlockParams) (D : CmData shdP_K P) (B : Layout.W16Pub (shieldShape Ly) Pb (shdP_bitLay Ly))
    (b : Fin ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) → Bool) :
    (Exec.Block.Join.R13H.Fzc.valsFR shdP_U (geoShield Ly) P D B b).getD 7 0
      = aPl shdP_U P D (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) (86 + 2 * 1 + 4))
          ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) b := rfl

private theorem valsFR_getD_26 {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    (P : BlockParams) (D : CmData shdP_K P) (B : Layout.W16Pub (shieldShape Ly) Pb (shdP_bitLay Ly))
    (b : Fin ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) → Bool) :
    (Exec.Block.Join.R13H.Fzc.valsFR shdP_U (geoShield Ly) P D B b).getD 26 0
      = hPl shdP_U P D
          (Exec.Block.DefR13.hOff (Exec.Block.DefR13.cfgShieldR13 Ly)
            (Exec.Block.DefR13.fh (Exec.Block.DefR13.cfgShieldR13 Ly) 7)).1
          (Exec.Block.DefR13.hOff (Exec.Block.DefR13.cfgShieldR13 Ly)
            (Exec.Block.DefR13.fh (Exec.Block.DefR13.cfgShieldR13 Ly) 7)).2
          ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) b := rfl

private theorem valsFR_getD_27 {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    (P : BlockParams) (D : CmData shdP_K P) (B : Layout.W16Pub (shieldShape Ly) Pb (shdP_bitLay Ly))
    (b : Fin ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) → Bool) :
    (Exec.Block.Join.R13H.Fzc.valsFR shdP_U (geoShield Ly) P D B b).getD 27 0
      = algebraMap GF shdP_K (B.grpCol (splitF (Exec.Block.DefR13.cfgShieldR13 Ly)
          (castB (geoShield Ly).logF b))) := rfl

private theorem valsLR_planes (c : W16Cfg) (P : BlockParams) (D : CmData shdP_K P)
    (gL : (Fin 14 → Bool) → GF) (b : Fin 14 → Bool) :
    ∀ l ∈ Exec.Block.DefW16.lookupsN Exec.Block.DefW16.cfgRungW16 Exec.Block.Join.W16.Look.LkDom.L.dom,
      ∀ t ∈ l.terms,
        (Exec.Block.Join.R13H.Help.valsLR shdP_U c P D gL b).getD (Exec.Block.Join.W16.Lk.shapedL t.1) 0
          = aPl shdP_U P D (Exec.Block.DefR13.aOff c t.1) 14 b := fun l hl t ht => by
  rcases Exec.Block.Join.R13H.LookRel.planesL_W16 l hl t ht with h | h <;> rw [h] <;> rfl

private theorem valsLR_getD_3 (c : W16Cfg) (P : BlockParams) (D : CmData shdP_K P)
    (gL : (Fin 14 → Bool) → GF) (b : Fin 14 → Bool) :
    (Exec.Block.Join.R13H.Help.valsLR shdP_U c P D gL b).getD (3 + 0 + 0) 0
      = hPl shdP_U P D (Exec.Block.DefR13.hOff c 0).1 (Exec.Block.DefR13.hOff c 0).2 14 b := rfl

section ConcreteVanishing

variable {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
variable (P : BlockParams) (hlc : P.logCols = 14) (hep : P.endpointLogN = 14)
variable (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand) (bga : Fp2 × Fp2 × Fp2) (TB_prev TB_next : Table)

local notation "cS" => Exec.Block.DefR13.cfgShieldR13 Ly
local notation "DS" => blkCmData P hlc hep (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next

private theorem blk_pair_eq (d : Dm) (j : Fin (d.np 1)) (b : Fin (d.log cS) → Bool)
    (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (h1 : lkAtR shdP_U cS P DS d (2 * j.val) b = tupK (blkLkAtGF w d (2 * j.val) b))
    (h2 : lkAtR shdP_U cS P DS d (2 * j.val + 1) b = tupK (blkLkAtGF w d (2 * j.val + 1) b)) :
    hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (d.fh 1 + j.val)).1
        (Exec.Block.DefR13.hOff cS (d.fh 1 + j.val)).2 (d.log cS) b
      * ((bga.2.2.toK shdP_U - fold (bga.1.toK shdP_U) (bga.2.1.toK shdP_U)
            (Exec.Block.Join.W16.Look.lkTupP (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) (d.log cS) b)
              ((Exec.Block.DefR13.lookups cS d.dom).getD (2 * j.val) ⟨[], 0, 0⟩)))
        * (bga.2.2.toK shdP_U - fold (bga.1.toK shdP_U) (bga.2.1.toK shdP_U)
            (Exec.Block.Join.W16.Look.lkTupP (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) (d.log cS) b)
              ((Exec.Block.DefR13.lookups cS d.dom).getD (2 * j.val + 1) ⟨[], 0, 0⟩))))
      = (bga.2.2.toK shdP_U - fold (bga.1.toK shdP_U) (bga.2.1.toK shdP_U)
            (Exec.Block.Join.W16.Look.lkTupP (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) (d.log cS) b)
              ((Exec.Block.DefR13.lookups cS d.dom).getD (2 * j.val) ⟨[], 0, 0⟩)))
        + (bga.2.2.toK shdP_U - fold (bga.1.toK shdP_U) (bga.2.1.toK shdP_U)
            (Exec.Block.Join.W16.Look.lkTupP (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) (d.log cS) b)
              ((Exec.Block.DefR13.lookups cS d.dom).getD (2 * j.val + 1) ⟨[], 0, 0⟩))) := by
  have hl1 : Exec.Block.Join.W16.Look.lkTupP
        (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) (d.log cS) b)
        ((Exec.Block.DefR13.lookups cS d.dom).getD (2 * j.val) ⟨[], 0, 0⟩)
      = tupK (blkLkAtGF w d (2 * j.val) b) := h1
  have hl2 : Exec.Block.Join.W16.Look.lkTupP
        (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) (d.log cS) b)
        ((Exec.Block.DefR13.lookups cS d.dom).getD (2 * j.val + 1) ⟨[], 0, 0⟩)
      = tupK (blkLkAtGF w d (2 * j.val + 1) b) := h2
  rw [blk_hPl_pair P hlc hep w rnd bga TB_prev TB_next d j b, hl1, hl2]
  unfold blkInvK
  exact pair_inv_eq
    (blkLk_denom_ne_zero_of_alphaBad w bga hα hbad (.inr (.inl ⟨d, j, b⟩)))
    (blkLk_denom_ne_zero_of_alphaBad w bga hα hbad (.inr (.inr ⟨d, j, b⟩)))

theorem blk_xcTzcR_eq_zero (κ : ℕ) (b : Fin (tauLen cS 2) → Bool) :
    Exec.Block.Join.R13H.Tzc.xcTzcR (K := shdP_K) cS bga κ b = 0 := rfl

theorem blk_xcDzcR_eq_zero (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (κ : ℕ) (b : Fin (tauLen cS 14) → Bool) :
    Exec.Block.Join.R13H.Dzc.xcDzcR shdP_U (geoShield Ly) P DS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) bga κ b = 0 := by
  unfold Exec.Block.Join.R13H.Dzc.xcDzcR
  have hc := lookCfg_shield Ly
  have hr := Exec.Block.Join.R13H.LookRel.relCfg_shield Ly
  by_cases hj : κ - 13 < 17
  · let j : Fin (Dm.np 1 .D) := ⟨κ - 13, hj⟩
    have hjv : j.val = κ - 13 := rfl
    have h1 := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .D (2 * j.val)
      (by rw [lkLen hc .D, ite_eq_right (by decide)]; show 2 * j.val < 2 * 17 + 0; omega) b
    have h2 := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .D (2 * j.val + 1)
      (by rw [lkLen hc .D, ite_eq_right (by decide)]; show 2 * j.val + 1 < 2 * 17 + 0; omega) b
    exact host_pair_eq_zero shdP_U bga hα 14 Exec.Block.Join.R13H.Dzc.shD (Exec.Block.DefR13.lookups cS Dm.D.dom) _
      (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) ((cS).sh.logs .D) b) 46 _ j.val
      (by rw [lkLen hc .D, ite_eq_right (by decide)]; show 2 * j.val + 1 < 2 * 17 + 0; omega)
      (Exec.Block.Join.R13H.LookRel.lkOK_R hc hr .D)
      (Exec.Block.Join.R13H.LookRel.dzc_planesR shdP_U (geoShield Ly) P DS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) hc b)
      (Exec.Block.Join.R13H.LookRel.dzc_helpR shdP_U (geoShield Ly) P DS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) hc b j.val (by omega))
      (blk_pair_eq P hlc hep w rnd bga TB_prev TB_next .D j b hα hbad h1 h2)
  · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none]
    · rfl
    · rw [lkRels_length]
      unfold Exec.Block.Join.R13H.Dzc.lksXR Exec.Block.DefR13.lksS
      rw [List.length_map, List.length_map, List.length_map, hc.lkD,
        show (lkDe (cS).p).length = 34 from rfl]
      omega

theorem blk_xcQzcR_eq_zero (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (κ : ℕ) (b : Fin (tauLen cS 15) → Bool) :
    Exec.Block.Join.R13H.Qkv.xcQzcR shdP_U cS P DS bga κ b = 0 := by
  unfold Exec.Block.Join.R13H.Qkv.xcQzcR Exec.Block.Join.R13H.Qkv.xcZc
  have hc := lookCfg_shield Ly
  have hr := Exec.Block.Join.R13H.LookRel.relCfg_shield Ly
  by_cases h4 : κ < 4
  · interval_cases κ <;> rfl
  · by_cases h11 : κ < 11
    · let j : Fin (Dm.np 1 .Q) := ⟨κ - 4, by show κ - 4 < 7; omega⟩
      have hjv : j.val = κ - 4 := rfl
      have hκ : κ = 4 + j.val := by omega
      rw [hκ, Exec.Block.Join.R13H.LookRel.getD_cons4]
      have h1 := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .Q (2 * j.val)
        (by rw [lkLen hc .Q, ite_eq_right (by decide)]; show 2 * j.val < 2 * 7 + 0; omega) b
      have h2 := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .Q (2 * j.val + 1)
        (by rw [lkLen hc .Q, ite_eq_right (by decide)]; show 2 * j.val + 1 < 2 * 7 + 0; omega) b
      exact host_pair_eq_zero shdP_U bga hα 0 (fun p => 5 + (p - 47)) (Exec.Block.DefR13.lookups cS Dm.Q.dom) _
        (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) ((cS).sh.logs .Q) b) 20 _ j.val
        (by rw [lkLen hc .Q, ite_eq_right (by decide)]; show 2 * j.val + 1 < 2 * 7 + 0; omega)
        (Exec.Block.Join.R13H.LookRel.lkOK_R hc hr .Q)
        (Exec.Block.Join.R13H.LookRel.q_planesR shdP_U P DS hc b)
        (Exec.Block.Join.R13H.LookRel.q_helpR shdP_U P DS hc b j.val (by omega))
        (blk_pair_eq P hlc hep w rnd bga TB_prev TB_next .Q j b hα hbad h1 h2)
    · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none]
      · rfl
      · simp only [List.length_cons, lkRels_length, Exec.Block.Join.R13H.Qkv.lksF_length]
        rw [hc.lkQ, show (lkQe (cS).p).length = 14 from rfl]
        omega

theorem blk_xcKvzcR_eq_zero (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (κ : ℕ) (b : Fin (tauLen cS 16) → Bool) :
    Exec.Block.Join.R13H.Qkv.xcKvzcR shdP_U cS P DS bga κ b = 0 := by
  unfold Exec.Block.Join.R13H.Qkv.xcKvzcR Exec.Block.Join.R13H.Qkv.xcZc
  have hc := lookCfg_shield Ly
  have hr := Exec.Block.Join.R13H.LookRel.relCfg_shield Ly
  by_cases h4 : κ < 4
  · interval_cases κ <;> rfl
  · by_cases h11 : κ < 11
    · let j : Fin (Dm.np 1 .Kv) := ⟨κ - 4, by show κ - 4 < 7; omega⟩
      have hjv : j.val = κ - 4 := rfl
      have hκ : κ = 4 + j.val := by omega
      rw [hκ, Exec.Block.Join.R13H.LookRel.getD_cons4]
      have h1 := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .Kv (2 * j.val)
        (by rw [lkLen hc .Kv, ite_eq_right (by decide)]; show 2 * j.val < 2 * 7 + 0; omega) b
      have h2 := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .Kv (2 * j.val + 1)
        (by rw [lkLen hc .Kv, ite_eq_right (by decide)]; show 2 * j.val + 1 < 2 * 7 + 0; omega) b
      exact host_pair_eq_zero shdP_U bga hα 0 (fun p => 5 + (p - 61)) (Exec.Block.DefR13.lookups cS Dm.Kv.dom) _
        (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) ((cS).sh.logs .Kv) b) 20 _ j.val
        (by rw [lkLen hc .Kv, ite_eq_right (by decide)]; show 2 * j.val + 1 < 2 * 7 + 0; omega)
        (Exec.Block.Join.R13H.LookRel.lkOK_R hc hr .Kv)
        (Exec.Block.Join.R13H.LookRel.k_planesR shdP_U P DS hc b)
        (Exec.Block.Join.R13H.LookRel.k_helpR shdP_U P DS hc b j.val (by omega))
        (blk_pair_eq P hlc hep w rnd bga TB_prev TB_next .Kv j b hα hbad h1 h2)
    · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none]
      · rfl
      · simp only [List.length_cons, lkRels_length, Exec.Block.Join.R13H.Qkv.lksF_length]
        rw [hc.lkK, show (lkKe (cS).p).length = 14 from rfl]
        omega

theorem blk_xcSzcR_eq_zero (hβ : bga.1.Canon) (hα : bga.2.2.Canon)
    (hbad : blkAlphaBad Ly Pb bga = false) (κ : ℕ) (b : Fin (tauLen cS 17) → Bool) :
    Exec.Block.Join.R13H.Szc.xcSzcR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) bga κ b = 0 := by
  have hc := lookCfg_shield Ly
  have hr := Exec.Block.Join.R13H.LookRel.relCfg_shield Ly
  have hlenKR := Exec.Block.Join.R13H.LookRel.lenKR shdP_U hc bga
  have hlenR : (lkRels (cstK shdP_U) (Exec.Block.Join.R13H.Szc.valsR shdP_U (geoShield Ly) P DS
      (shdP_w16Pub Ly Pb) 0 0 0 b) (17 + 2 * 1) 0 (Exec.Block.Join.R13H.Szc.lksKR shdP_U cS bga)).length = 8 := by
    rw [lkRels_length, hlenKR]
  by_cases h5 : κ < 5
  · unfold Exec.Block.Join.R13H.Szc.xcSzcR
    rw [getD_appL _ _ _ _ (by rw [List.length_append, List.length_replicate]; omega),
      getD_appL _ _ _ _ (by rw [List.length_replicate]; exact h5),
      List.getD_eq_getElem?_getD, List.getElem?_replicate, ite_eq_left h5, Option.getD_some]
  · by_cases h12 : κ < 12
    · let j : Fin (Dm.np 1 .S) := ⟨κ - 5, by show κ - 5 < 7; omega⟩
      have hjv : j.val = κ - 5 := rfl
      rw [show κ = 5 + j.val by omega,
        Exec.Block.Join.R13H.LookRel.xcS_rel shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) hc bga b j.val (by omega)]
      have h1 := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .S (2 * j.val)
        (by rw [lkLen hc .S, ite_eq_left rfl]; show 2 * j.val < 2 * 7 + 1; omega) b
      have h2 := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .S (2 * j.val + 1)
        (by rw [lkLen hc .S, ite_eq_left rfl]; show 2 * j.val + 1 < 2 * 7 + 1; omega) b
      exact host_pair_eq_zero shdP_U bga hα 17 Exec.Block.Join.R13H.Szc.shapedR (Exec.Block.DefR13.lookups cS Dm.S.dom) _
        (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) ((cS).sh.logs .S) b) (17 + 2 * 1) _ j.val
        (by rw [lkLen hc .S, ite_eq_left rfl]; show 2 * j.val + 1 < 2 * 7 + 1; omega)
        (Exec.Block.Join.R13H.LookRel.lkOK_R hc hr .S)
        (Exec.Block.Join.R13H.LookRel.s_planesR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) hc b)
        (Exec.Block.Join.R13H.LookRel.s_helpR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) hc b j.val (by omega))
        (blk_pair_eq P hlc hep w rnd bga TB_prev TB_next .S j b hα hbad h1 h2)
    · by_cases h12eq : κ = 12
      · rw [h12eq, show (12 : ℕ) = 5 + 7 by norm_num,
          Exec.Block.Join.R13H.LookRel.xcS_rel shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) hc bga b 7 (by omega)]
        have hh := Exec.Block.Join.R13H.LookRel.s_helpR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) hc b 7 (by omega)
        rw [show Dm.fh 1 .S + 7 = Sg.hp 1 .S from rfl] at hh
        have h1 := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .S (2 * 7)
          (by rw [lkLen hc .S, ite_eq_left rfl]; decide) b
        have hne := blkLk_denom_ne_zero_of_alphaBad w bga hα hbad (.inl ⟨.S, b⟩)
        refine host_single_eq_zero shdP_U bga hα 17 Exec.Block.Join.R13H.Szc.shapedR (Exec.Block.DefR13.lookups cS Dm.S.dom) _
          (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) ((cS).sh.logs .S) b) (17 + 2 * 1) _ 7
          (by rw [lkLen hc .S, ite_eq_left rfl]; rfl)
          (Exec.Block.Join.R13H.LookRel.lkOK_R hc hr .S)
          (Exec.Block.Join.R13H.LookRel.s_planesR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) hc b)
          hh ?_
        have hl1 : Exec.Block.Join.W16.Look.lkTupP
              (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) ((cS).sh.logs .S) b)
              ((Exec.Block.DefR13.lookups cS Dm.S.dom).getD (2 * 7) ⟨[], 0, 0⟩)
            = tupK (blkLkAtGF w .S (2 * 7) b) := h1
        have hsg : hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (Sg.hp 1 .S)).1
              (Exec.Block.DefR13.hOff cS (Sg.hp 1 .S)).2 ((cS).sh.logs .S) b
            = blkInvK bga (blkSgTupGF w .S b) :=
          blk_hPl_sg P hlc hep w rnd bga TB_prev TB_next .S b
        refine (congrArg₂ (· * ·) hsg
          (congrArg (fun t => bga.2.2.toK shdP_U - fold (bga.1.toK shdP_U) (bga.2.1.toK shdP_U) t) hl1)).trans ?_
        unfold blkSgTupGF blkInvK
        exact inv_mul_cancel₀ hne
      · by_cases h13 : κ = 13
        · rw [h13]
          have hl : (List.replicate 5 (0 : shdP_K)
              ++ lkRels (cstK shdP_U) (Exec.Block.Join.R13H.Szc.valsR shdP_U (geoShield Ly) P DS
                (shdP_w16Pub Ly Pb) 0 0 0 b) (17 + 2 * 1) 0 (Exec.Block.Join.R13H.Szc.lksKR shdP_U cS bga)).length = 13 := by
            rw [List.length_append, List.length_replicate, hlenR]
          unfold Exec.Block.Join.R13H.Szc.xcSzcR
          rw [getD_appR _ _ _ _ (by rw [hl]), hl, Nat.sub_self, List.getD_cons_zero]
          have hamd : (Block.Sym.eval (Block.histOf bga.1 bga.2.1 bga.2.2 []) 17 [] (.sub .alpha (.gtag 129))).toK shdP_U
              = bga.2.2.toK shdP_U - bga.2.1.toK shdP_U * 129 := by
            show (Fp2.sub bga.2.2 (bga.2.1.mulBase (Fp.new (UInt64.ofNat 129)))).toK shdP_U = _
            rw [Fp2.toK_sub shdP_U _ _ hα (Fp2.canon_mulBase _ _), Fp2.toK_mulBase,
              Fp.new_toGF_ofNat 129 (by norm_num), map_natCast]
            norm_num
          have hnb : (Block.Sym.eval (Block.histOf bga.1 bga.2.1 bga.2.2 []) 17 [] (.neg .beta)).toK shdP_U
              = -bga.1.toK shdP_U := by
            show (Fp2.neg bga.1).toK shdP_U = _
            rw [Fp2.toK_neg shdP_U _ hβ]
          have hb1 : (cstK shdP_U).base (-127) = -127 := by
            rw [Exec.Block.Join.W16.cstK_base shdP_U (-127) (by norm_num) (by norm_num)]
            exact (map_intCast (algebraMap GF shdP_K) (-127)).trans (by norm_num)
          have hb2 : (cstK shdP_U).base 127 = 127 := by
            rw [Exec.Block.Join.W16.cstK_base shdP_U 127 (by norm_num) (by norm_num)]
            exact (map_intCast (algebraMap GF shdP_K) 127).trans (by norm_num)
          have e3 : (Exec.Block.Join.R13H.Szc.valsR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) 0 0 0 b).getD 3 0
              = algebraMap GF shdP_K ((shdP_w16Pub Ly Pb).mask (splitS cS (castB (geoShield Ly).logS b))) := rfl
          have e4 : (Exec.Block.Join.R13H.Szc.valsR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) 0 0 0 b).getD 4 0
              = aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 75) ((cS).sh.logs .S) b :=
            Exec.Block.Join.R13H.LookRel.s_restPl shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) b 0 (by omega)
          have e9 : (Exec.Block.Join.R13H.Szc.valsR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) 0 0 0 b).getD 9 0
              = aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 80) ((cS).sh.logs .S) b :=
            Exec.Block.Join.R13H.LookRel.s_restPl shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) b 5 (by omega)
          have emx : (Exec.Block.Join.R13H.Szc.valsR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) 0 0 0 b).getD (15 + 2 * 1) 0
              = aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 4) (nHt cS)
                  (Fin.append (Fin.append (splitS cS (castB (geoShield Ly).logS b)).1.1
                    (splitS cS (castB (geoShield Ly).logS b)).1.2) (splitS cS (castB (geoShield Ly).logS b)).2.1) := by
            have htail := Exec.Block.Join.R13H.LookRel.s_tail shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) b 0
            rw [List.getD_cons_zero] at htail
            have h1 := Exec.Block.Join.R13H.Szc.alg_plHt_R shdP_U (geoShield Ly) P DS
              (blkCmData_base P hlc hep (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next)
              (Exec.Block.DefR13.aOff cS 4) b
            unfold plH at h1
            rw [Exec.Block.Join.W16.aPl_alg shdP_U P DS (blkCmData_base P hlc hep (blkTA w rnd) (blkTH w rnd bga) TB_prev TB_next)] at h1
            exact htail.trans h1.symm
          have ehx : (Exec.Block.Join.R13H.Szc.valsR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) 0 0 0 b).getD (24 + 3 * 1) 0
              = hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (Sg.hp 1 .Exp)).1
                  (Exec.Block.DefR13.hOff cS (Sg.hp 1 .Exp)).2 (Sg.log cS .Exp) b := by
            have htail := Exec.Block.Join.R13H.LookRel.s_tail shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) b (7 + 1 + 1 + 1)
            refine htail.trans ?_
            simp only [List.getD_cons_succ]
            rw [getD_appR _ _ _ _ (by simp only [List.length_map, List.length_range]; omega)]
            simp only [List.length_map, List.length_range, Nat.sub_self, List.getD_cons_zero]
            rw [(fh_eq hc).2.2.2.2.2.1]; rfl
          have hsingle : hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (Sg.hp 1 .Exp)).1
                (Exec.Block.DefR13.hOff cS (Sg.hp 1 .Exp)).2 (Sg.log cS .Exp) b
              * (bga.2.2.toK shdP_U - fold (bga.1.toK shdP_U) (bga.2.1.toK shdP_U)
                  (expTupR shdP_U cS P DS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (geoShield Ly) b)) = 1 := by
            rw [blk_hPl_sg P hlc hep w rnd bga TB_prev TB_next .Exp b,
              blk_expTupR_eq P hlc hep w rnd bga TB_prev TB_next b]
            exact inv_mul_cancel₀ (blkLk_denom_ne_zero_of_alphaBad w bga hα hbad (.inl ⟨.Exp, b⟩))
          unfold Exec.Block.Join.R13H.Szc.r13SzcExp Exec.Block.Join.R13H.Szc.r13SzcDelta
          simp only [Exec.Block.Join.R13H.Szc.RSzR]
          rw [hamd, hnb, hb1, hb2, e3, e4, e9, emx, ehx]
          unfold expTupR fold at hsingle
          have ht : ((tagExp : ℕ) : shdP_K) = 129 := by norm_num
          rw [ht] at hsingle
          linear_combination hsingle
        · unfold Exec.Block.Join.R13H.Szc.xcSzcR
          rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none]
          · rfl
          · simp only [List.length_append, List.length_replicate, List.length_cons, List.length_nil, hlenR]
            omega

theorem blk_xcFzcR_eq_zero (hβ : bga.1.Canon) (hα : bga.2.2.Canon)
    (hbad : blkAlphaBad Ly Pb bga = false) (κ : ℕ) (b : Fin (tauLen cS 18) → Bool) :
    Exec.Block.Join.R13H.Fzc.xcFzcR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) bga κ b = 0 := by
  have hc := lookCfg_shield Ly
  have hr := Exec.Block.Join.R13H.LookRel.relCfg_shield Ly
  unfold Exec.Block.Join.R13H.Fzc.xcFzcR
  by_cases h3 : κ = 3
  · rw [ite_eq_left h3]
    have hamq : (Block.Sym.eval (Block.histOf bga.1 bga.2.1 bga.2.2 []) 18 [] Exec.Block.Join.W16.Fzc.amqS).toK shdP_U
        = bga.2.2.toK shdP_U - 2048 - bga.2.1.toK shdP_U * 134 := by
      show (Fp2.sub (Fp2.sub bga.2.2 (Fp2.fromBase (Fp.fromI64 2048)))
        (bga.2.1.mulBase (Fp.new (UInt64.ofNat 134)))).toK shdP_U = _
      rw [Fp2.toK_sub shdP_U _ _ (Fp2.canon_sub _ _ hα (Fp2.canon_fromBase _ (Exec.Block.Join.W16.Look.fromI64_canon _)))
          (Fp2.canon_mulBase _ _),
        Fp2.toK_sub shdP_U _ _ hα (Fp2.canon_fromBase _ (Exec.Block.Join.W16.Look.fromI64_canon _)), Fp2.toK_fromBase,
        Fp.toGF_fromI64 2048 (by norm_num) (by norm_num), Fp2.toK_mulBase,
        Fp.new_toGF_ofNat 134 (by norm_num), map_natCast, map_intCast]
      norm_num
    have hnb : (Block.Sym.eval (Block.histOf bga.1 bga.2.1 bga.2.2 []) 18 [] Exec.Block.Join.W16.Fzc.nbS).toK shdP_U
        = -bga.1.toK shdP_U := by
      show (Fp2.neg bga.1).toK shdP_U = _
      rw [Fp2.toK_neg shdP_U _ hβ]
    have hnb2 : (Block.Sym.eval (Block.histOf bga.1 bga.2.1 bga.2.2 []) 18 [] Exec.Block.Join.W16.Fzc.nb2S).toK shdP_U
        = -(bga.1.toK shdP_U * bga.1.toK shdP_U) := by
      show (Fp2.neg (Fp2.mul bga.1 bga.1)).toK shdP_U = _
      rw [Fp2.toK_neg shdP_U _ (Fp2.canon_mul _ _), Fp2.toK_mul shdP_U shdP_hU]
    have hf7 : Exec.Block.DefR13.fh cS 7 = 48 := (fh_eq hc).2.2.2.2.2.2.2.1
    have e26 : (Exec.Block.Join.R13H.Fzc.valsFR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) b).getD 26 0
        = hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (Sg.hp 1 .Act)).1
            (Exec.Block.DefR13.hOff cS (Sg.hp 1 .Act)).2 (Sg.log cS .Act) b := by
      have h0 := valsFR_getD_26 P DS (shdP_w16Pub Ly Pb) b
      rw [hf7] at h0
      exact h0
    have e3 := valsFR_getD_3 P DS (shdP_w16Pub Ly Pb) b
    have e7 := valsFR_getD_7 P DS (shdP_w16Pub Ly Pb) b
    have e27 := valsFR_getD_27 P DS (shdP_w16Pub Ly Pb) b
    have hsingle : hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (Sg.hp 1 .Act)).1
          (Exec.Block.DefR13.hOff cS (Sg.hp 1 .Act)).2 (Sg.log cS .Act) b
        * (bga.2.2.toK shdP_U - fold (bga.1.toK shdP_U) (bga.2.1.toK shdP_U)
            (actTupR shdP_U cS P DS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (geoShield Ly) b)) = 1 := by
      rw [blk_hPl_sg P hlc hep w rnd bga TB_prev TB_next .Act b,
        blk_actTupR_eq P hlc hep w rnd bga TB_prev TB_next b]
      exact inv_mul_cancel₀ (blkLk_denom_ne_zero_of_alphaBad w bga hα hbad (.inl ⟨.Act, b⟩))
    unfold Exec.Block.Join.R13H.Fzc.r13FzcAct
    simp only [Exec.Block.Join.R13H.Fzc.rrFR]
    rw [hamq, hnb, hnb2, e26, e3, e7, e27]
    unfold actTupR fold at hsingle
    have ht : ((tagAct : ℕ) : shdP_K) = 134 := by norm_num
    rw [ht] at hsingle
    linear_combination hsingle
  · rw [ite_eq_right h3]
    by_cases hj : κ - 4 < 7
    · let j : Fin (Dm.np 1 .F) := ⟨κ - 4, hj⟩
      have hjv : j.val = κ - 4 := rfl
      have h1 := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .F (2 * j.val)
        (by rw [lkLen hc .F, ite_eq_right (by decide)]; show 2 * j.val < 2 * 7 + 0; omega) b
      have h2 := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .F (2 * j.val + 1)
        (by rw [lkLen hc .F, ite_eq_right (by decide)]; show 2 * j.val + 1 < 2 * 7 + 0; omega) b
      exact host_pair_eq_zero shdP_U bga hα 18 (Exec.Block.Join.R13H.Fzc.shFR 1)
        (Exec.Block.DefR13.lookups cS Dm.F.dom) _
        (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) ((cS).sh.logs .F) b) 19 _ j.val
        (by rw [lkLen hc .F, ite_eq_right (by decide)]; show 2 * j.val + 1 < 2 * 7 + 0; omega)
        (Exec.Block.Join.R13H.LookRel.lkOK_R hc hr .F)
        (Exec.Block.Join.R13H.LookRel.f_planesR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) hc b)
        (Exec.Block.Join.R13H.LookRel.f_helpR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) hc b j.val (by omega))
        (blk_pair_eq P hlc hep w rnd bga TB_prev TB_next .F j b hα hbad h1 h2)
    · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none]
      · rfl
      · rw [lkRels_length]
        unfold Exec.Block.Join.R13H.Fzc.lksFR Exec.Block.DefR13.lksS
        rw [List.length_map, List.length_map, List.length_map, hc.lkF,
          show (lkFe (cS).p 1).length = 14 from rfl]
        omega

/-- **All 6 hosts' extra batch entries `xcR` vanish identically** on `blkCmData`. -/
theorem blk_xcR_eq_zero {L : ℕ} (Dof : Block.Cuts3 L → Block.RootsO → CmData shdP_K P)
    (cu : Block.Cuts3 L) (rt : Block.RootsO) (hD : Dof cu rt = DS)
    (hβ : bga.1.Canon) (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (k κ : ℕ) (b : Fin (tauLen cS k) → Bool) :
    xcR shdP_U (geoShield Ly) P Dof Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) k cu rt bga κ b = 0 := by
  match k, b with
  | 2, _ => rfl
  | 14, b =>
    show Exec.Block.Join.R13H.Dzc.xcDzcR shdP_U (geoShield Ly) P (Dof cu rt) Pb (shdP_bitLay Ly)
      (shdP_w16Pub Ly Pb) bga κ b = 0
    rw [hD]; exact blk_xcDzcR_eq_zero P hlc hep w rnd bga TB_prev TB_next hα hbad κ b
  | 15, b =>
    show Exec.Block.Join.R13H.Qkv.xcQzcR shdP_U cS P (Dof cu rt) bga κ b = 0
    rw [hD]; exact blk_xcQzcR_eq_zero P hlc hep w rnd bga TB_prev TB_next hα hbad κ b
  | 16, b =>
    show Exec.Block.Join.R13H.Qkv.xcKvzcR shdP_U cS P (Dof cu rt) bga κ b = 0
    rw [hD]; exact blk_xcKvzcR_eq_zero P hlc hep w rnd bga TB_prev TB_next hα hbad κ b
  | 17, b =>
    show Exec.Block.Join.R13H.Szc.xcSzcR shdP_U (geoShield Ly) P (Dof cu rt) (shdP_w16Pub Ly Pb) bga κ b = 0
    rw [hD]; exact blk_xcSzcR_eq_zero P hlc hep w rnd bga TB_prev TB_next hβ hα hbad κ b
  | 18, b =>
    show Exec.Block.Join.R13H.Fzc.xcFzcR shdP_U (geoShield Ly) P (Dof cu rt) (shdP_w16Pub Ly Pb) bga κ b = 0
    rw [hD]; exact blk_xcFzcR_eq_zero P hlc hep w rnd bga TB_prev TB_next hβ hα hbad κ b
  | 0, _ | 1, _ | 3, _ | 4, _ | 5, _ | 6, _ | 7, _ | 8, _ | 9, _ | 10, _ | 11, _ | 12, _ | 13, _ | _ + 19, _ => rfl

theorem blk_pwDzcR_eq_zero (j : ℕ) (b : Fin (tauLen cS 14) → Bool) :
    Exec.Block.Join.R13H.Dzc.pwDzcR shdP_U (geoShield Ly) P DS Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) j b = 0 := by
  unfold Exec.Block.Join.R13H.Dzc.pwDzcR Exec.Block.Join.R13H.Dzc.grpDz
  simp only [padPls, List.append_nil]
  by_cases hj : j < 39
  · rw [getD_mapRange _ 5 39 j 0 hj]
    have hg : (Exec.Block.Join.R13H.Dzc.valsXD shdP_U (geoShield Ly) P DS Pb (shdP_bitLay Ly)
        (shdP_w16Pub Ly Pb) b).getD 63 0
        = algebraMap GF shdP_K ((shdP_w16Pub Ly Pb).gD (splitD cS (castB (geoShield Ly).logD b))) := rfl
    rw [hg]
    by_cases hlt : msbIndex 12 (splitD cS (castB (geoShield Ly).logD b)).2 < 3072
    · have hg1 : (shdP_w16Pub Ly Pb).gD (splitD cS (castB (geoShield Ly).logD b)) = 1 :=
        let p := splitD cS (castB (geoShield Ly).logD b)
        (congrArg (shdP_w16Pub Ly Pb).gD
          (Prod.ext (emb_blkTokInv Ly p.1).symm (Exec.msbBits_msbIndex 12 p.2).symm :
            p = (shdP_bitLay Ly).dPos (blkTokInv p.1, ⟨msbIndex 12 p.2, hlt⟩))).trans
          ((shdP_w16Pub Ly Pb).gD_one _)
      rw [hg1, map_one, sub_self, zero_mul]
    · have hp : (Exec.Block.Join.R13H.Dzc.valsXD shdP_U (geoShield Ly) P DS Pb (shdP_bitLay Ly)
          (shdP_w16Pub Ly Pb) b).getD (5 + j) 0
          = aPl shdP_U P DS (Exec.Block.DefR13.aOff cS (8 + j)) 19 b := by
        generalize DS = D0
        interval_cases j <;> rfl
      rw [hp, blk_aPl_D P hlc hep w rnd bga TB_prev TB_next (8 + j) (by omega) (by omega) b,
        blkDomPlane_pad_D w (8 + j) b hlt, map_zero, mul_zero]
  · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none]
    · rfl
    · simp only [List.length_map, List.length_range']; omega

theorem blk_pwFzcR_eq_zero (j : ℕ) (b : Fin (tauLen cS 18) → Bool) :
    Exec.Block.Join.R13H.Fzc.pwFzcR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) j b = 0 := by
  unfold Exec.Block.Join.R13H.Fzc.pwFzcR Exec.Block.Join.R13H.Fzc.grpFR
  simp only [padPls, List.append_nil]
  by_cases hj : j < 16
  · have hget : ([3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18].map fun p =>
        (1 - (Exec.Block.Join.R13H.Fzc.valsFR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) b).getD 28 0)
          * (Exec.Block.Join.R13H.Fzc.valsFR shdP_U (geoShield Ly) P DS (shdP_w16Pub Ly Pb) b).getD p 0).getD j 0
        = (1 - algebraMap GF shdP_K ((shdP_w16Pub Ly Pb).gF (splitF cS (castB (geoShield Ly).logF b))))
          * aPl shdP_U P DS (Exec.Block.DefR13.aOff cS (88 + j)) 21 b := by
      generalize DS = D0
      interval_cases j <;> rfl
    rw [hget]
    by_cases hlt : msbIndex 14 (splitF cS (castB (geoShield Ly).logF b)).2 < 9216
    · have hg1 : (shdP_w16Pub Ly Pb).gF (splitF cS (castB (geoShield Ly).logF b)) = 1 :=
        let p := splitF cS (castB (geoShield Ly).logF b)
        (congrArg (shdP_w16Pub Ly Pb).gF
          (Prod.ext (emb_blkTokInv Ly p.1).symm (Exec.msbBits_msbIndex 14 p.2).symm :
            p = (shdP_bitLay Ly).fPos (blkTokInv p.1, ⟨msbIndex 14 p.2, hlt⟩))).trans
          ((shdP_w16Pub Ly Pb).gF_one _)
      rw [hg1, map_one, sub_self, zero_mul]
    · rw [blk_aPl_F P hlc hep w rnd bga TB_prev TB_next (88 + j) (by omega) (by omega) b,
        blkDomPlane_pad_F w (88 + j) b hlt, map_zero, mul_zero]
  · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none]
    · rfl
    · simp only [List.length_map, List.length_cons, List.length_nil]; omega

/-- **All host pad planes `pwcR` vanish identically** on `blkCmData`. -/
theorem blk_pwcR_eq_zero {L : ℕ} (Dof : Block.Cuts3 L → Block.RootsO → CmData shdP_K P)
    (cu : Block.Cuts3 L) (rt : Block.RootsO) (hD : Dof cu rt = DS)
    (k : ℕ) (j : Fin (mpadR k)) (b : Fin (tauLen cS k) → Bool) :
    pwcR shdP_U (geoShield Ly) P Dof Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) k cu rt j b = 0 := by
  match k, j, b with
  | 14, j, b =>
    show Exec.Block.Join.R13H.Dzc.pwDzcR shdP_U (geoShield Ly) P (Dof cu rt) Pb (shdP_bitLay Ly)
      (shdP_w16Pub Ly Pb) j b = 0
    rw [hD]; exact blk_pwDzcR_eq_zero P hlc hep w rnd bga TB_prev TB_next j b
  | 18, j, b =>
    show Exec.Block.Join.R13H.Fzc.pwFzcR shdP_U (geoShield Ly) P (Dof cu rt) (shdP_w16Pub Ly Pb) j b = 0
    rw [hD]; exact blk_pwFzcR_eq_zero P hlc hep w rnd bga TB_prev TB_next j b
  | 0, _, _ | 1, _, _ | 2, _, _ | 3, _, _ | 4, _, _ | 5, _, _ | 6, _, _ | 7, _, _ | 8, _, _ | 9, _, _
  | 10, _, _ | 11, _, _ | 12, _, _ | 13, _, _ | 15, _, _ | 16, _, _ | 17, _, _ | _ + 19, _, _ => rfl

/-- **Slot 3 (`SC_LZC`) helper relation `cLzcR` vanishes** on `blkCmData`. -/
theorem blk_cLzcR_eq_zero (gL : (Fin 14 → Bool) → GF) (hα : bga.2.2.Canon)
    (hbad : blkAlphaBad Ly Pb bga = false) (b : Fin 14 → Bool) :
    Exec.Block.Join.R13H.Help.cLzcR shdP_U cS P DS gL bga b = 0 := by
  unfold Exec.Block.Join.R13H.Help.cLzcR
  have hlen : (Exec.Block.Join.W16.Lk.lksLK shdP_U bga).length = 2 := by
    unfold Exec.Block.Join.W16.Lk.lksLK; simp only [List.length_map]; decide
  rw [Exec.Block.Join.W16.Look.logupSem_two _ _ _ _ _ hlen]
  simp only [(Exec.Slot.Compose.cstW_map_std shdP_U).one, one_mul]
  have h0 : Exec.Block.Join.W16.Look.lkTupP (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) 14 b)
      ((Exec.Block.DefW16.lookupsN Exec.Block.DefW16.cfgRungW16 Exec.Block.Join.W16.Look.LkDom.L.dom).getD 0 ⟨[], 0, 0⟩)
      = tupK (blkLkAtGF w .L 0 b) := by
    rw [Exec.Block.Join.R13H.LookRel.lkL_W16]
    have hl := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .L 0
      (by rw [show Dm.L.dom = Dom.L from rfl, (lookCfg_shield Ly).lkL]; decide) b
    unfold lkAtR lkTupR at hl
    rw [show Dm.L.dom = Dom.L from rfl, (lookCfg_shield Ly).lkL] at hl
    exact hl
  have h1 : Exec.Block.Join.W16.Look.lkTupP (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) 14 b)
      ((Exec.Block.DefW16.lookupsN Exec.Block.DefW16.cfgRungW16 Exec.Block.Join.W16.Look.LkDom.L.dom).getD 1 ⟨[], 0, 0⟩)
      = tupK (blkLkAtGF w .L 1 b) := by
    rw [Exec.Block.Join.R13H.LookRel.lkL_W16]
    have hl := blk_lkAtR_eq P hlc hep w rnd bga TB_prev TB_next .L 1
      (by rw [show Dm.L.dom = Dom.L from rfl, (lookCfg_shield Ly).lkL]; decide) b
    unfold lkAtR lkTupR at hl
    rw [show Dm.L.dom = Dom.L from rfl, (lookCfg_shield Ly).lkL] at hl
    exact hl
  have hne0 := blkLk_denom_ne_zero_of_alphaBad w bga hα hbad (.inr (.inl ⟨.L, ⟨0, by decide⟩, b⟩))
  have hne1 := blkLk_denom_ne_zero_of_alphaBad w bga hα hbad (.inr (.inr ⟨.L, ⟨0, by decide⟩, b⟩))
  refine host_pair_eq_zero shdP_U bga hα 3 Exec.Block.Join.W16.Lk.shapedL
    (Exec.Block.DefW16.lookupsN Exec.Block.DefW16.cfgRungW16 Exec.Block.Join.W16.Look.LkDom.L.dom)
    (Exec.Block.Join.R13H.Help.valsLR shdP_U cS P DS gL b)
    (fun q => aPl shdP_U P DS (Exec.Block.DefR13.aOff cS q) 14 b) 3
    (hPl shdP_U P DS (Exec.Block.DefR13.hOff cS 0).1 (Exec.Block.DefR13.hOff cS 0).2 14 b) 0
    (by rw [Exec.Block.Join.R13H.LookRel.lkL_W16]; decide)
    (Exec.Block.Join.W16.Look.lkOK_all .L)
    (valsLR_planes cS P DS gL b)
    (valsLR_getD_3 cS P DS gL b) ?_
  have hh : hPl shdP_U P DS (Exec.Block.DefR13.hOff cS 0).1 (Exec.Block.DefR13.hOff cS 0).2 14 b
      = blkInvK bga (blkLkAtGF w .L 0 b) + blkInvK bga (blkLkAtGF w .L 1 b) :=
    blk_hPl_pair P hlc hep w rnd bga TB_prev TB_next .L ⟨0, by decide⟩ b
  rw [Nat.mul_zero, Nat.zero_add, hh, h0, h1]
  unfold blkInvK
  exact pair_inv_eq hne0 hne1

/-- **Slot 3 (`SC_LZC`) pad planes `wLzcR` vanish** on `blkCmData`. -/
theorem blk_wLzcR_eq_zero (j : Fin 2) (b : Fin 14 → Bool) :
    Exec.Block.Join.R13H.Help.wLzcR shdP_U cS P DS (Exec.Block.Join.R13H.Pub.gateLS (cS).sh) j b = 0 := by
  unfold Exec.Block.Join.R13H.Help.wLzcR Exec.Block.Join.R13H.Pub.gateLS
  by_cases h9 : msbIndex 14 b / 128 < 9
  · have h9' : msbIndex ((cS).sh.logs .L) b / 2 ^ (cS).sh.lt < 9 := h9
    rw [ite_eq_left h9', map_one, sub_self, zero_mul]
  · rcases j with ⟨jv, hjv⟩
    dsimp only
    interval_cases jv
    · rw [ite_eq_left (rfl : (0 : ℕ) = 0), blk_aPl_limbA P hlc hep w rnd bga TB_prev TB_next b,
        w.hPadL.limbA b h9, map_zero, mul_zero]
    · rw [ite_eq_right (by norm_num : ¬ (1 : ℕ) = 0), blk_aPl_limbM P hlc hep w rnd bga TB_prev TB_next b,
        w.hPadL.limbM b h9, map_zero, mul_zero]

/-- **Slot 19 (`SC_TAB`) table relations `cTabR` vanish** on `blkCmData`. -/
theorem blk_cTabR_eq_zero (hα : bga.2.2.Canon) (hbad : blkAlphaBad Ly Pb bga = false)
    (k : Fin 3) (b : Fin 14 → Bool) :
    Exec.Block.Join.R13T.cTabR shdP_U cS P DS Pb.exp Pb.act Ly.nG bga k b = 0 := by
  unfold Exec.Block.Join.R13T.cTabR
  rw [blk_helpTabR_eq P hlc hep w rnd bga TB_prev TB_next k b,
    blk_multTabR_eq P hlc hep w rnd bga TB_prev TB_next k b]
  by_cases hact : tabActive Ly.nG (k, b)
  · have hne := blkAlpha_ne_fold Ly Pb bga hα hbad (k, b) hact
    unfold TR13 at hne; dsimp only at hne
    unfold blkInvK
    rw [mul_assoc, inv_mul_cancel₀ hne, mul_one, sub_self]
  · rw [blkMult_eq_zero_of_not_active w (k, b) hact, Nat.cast_zero, zero_mul, zero_mul, sub_self]

private theorem blk_wTabR_aux (isH : Bool) (k : Fin 3) (b : Fin 14 → Bool) :
    (1 - algebraMap GF shdP_K (gateTabW Ly.nG (if k.val < 2 then 0 else 1) b))
      * (if isH then Exec.Block.Join.R13T.helpTabR shdP_U cS P DS k.val b
         else Exec.Block.Join.R13T.multTabR shdP_U cS P DS k.val b) = 0 := by
  by_cases hact : tabActive Ly.nG (k, b)
  · have hg : gateTabW Ly.nG (if k.val < 2 then 0 else 1) b = 1 := by
      unfold tabActive at hact; dsimp only at hact
      unfold gateTabW
      by_cases h2 : k.val < 2
      · rw [ite_eq_left h2] at hact ⊢; rw [ite_eq_left rfl, ite_eq_left hact]
      · rw [ite_eq_right h2] at hact ⊢; rw [ite_eq_right (by norm_num), ite_eq_left rfl, ite_eq_left hact]
    rw [hg, map_one, sub_self, zero_mul]
  · cases isH
    · rw [ite_eq_right Bool.false_ne_true, blk_multTabR_eq P hlc hep w rnd bga TB_prev TB_next k b,
        blkMult_eq_zero_of_not_active w (k, b) hact, Nat.cast_zero, mul_zero]
    · rw [ite_eq_left rfl, blk_helpTabR_eq P hlc hep w rnd bga TB_prev TB_next k b,
        blkMult_eq_zero_of_not_active w (k, b) hact, Nat.cast_zero, zero_mul, mul_zero]

/-- **Slot 19 (`SC_TAB`) pad planes `wTabR` vanish** on `blkCmData`. -/
theorem blk_wTabR_eq_zero (j : Fin 6) (b : Fin 14 → Bool) :
    Exec.Block.Join.R13T.wTabR shdP_U cS P DS Ly.nG j b = 0 := by
  unfold Exec.Block.Join.R13T.wTabR
  rcases j with ⟨jv, hjv⟩
  dsimp only
  interval_cases jv
  · exact blk_wTabR_aux P hlc hep w rnd bga TB_prev TB_next false ⟨0, by norm_num⟩ b
  · exact blk_wTabR_aux P hlc hep w rnd bga TB_prev TB_next false ⟨1, by norm_num⟩ b
  · exact blk_wTabR_aux P hlc hep w rnd bga TB_prev TB_next true ⟨0, by norm_num⟩ b
  · exact blk_wTabR_aux P hlc hep w rnd bga TB_prev TB_next true ⟨1, by norm_num⟩ b
  · exact blk_wTabR_aux P hlc hep w rnd bga TB_prev TB_next false ⟨2, by norm_num⟩ b
  · exact blk_wTabR_aux P hlc hep w rnd bga TB_prev TB_next true ⟨2, by norm_num⟩ b

/-- **Slot 20 (`SC_ZS`) zero-sum blinding plane `H_U` sums to `0`** over the `2^14` cube. -/
theorem blk_hU_sum_eq_zero :
    ∑ b : Fin 14 → Bool,
      hPl shdP_U P DS (Exec.Block.DefR13.hOff cS (Exec.Block.DefR13.fh cS 10)).1
        (Exec.Block.DefR13.hOff cS (Exec.Block.DefR13.fh cS 10)).2 14 b = 0 := by
  simp_rw [blk_hPl_hU P hlc hep w rnd bga TB_prev TB_next]
  let e14 : (Fin 14 → Bool) ≃ Fin 16384 :=
    { toFun := fun b => ⟨msbIndex 14 b, msbIndex_lt 14 b⟩,
      invFun := fun idx => msbBits 14 idx.val,
      left_inv := fun b => msbBits_msbIndex 14 b,
      right_inv := fun idx => Fin.ext (msbIndex_msbBits 14 idx.val idx.isLt) }
  exact (Equiv.sum_comp e14 (fun col : Fin 16384 =>
      algebraMap GF shdP_K (blkHUVal rnd col).1 + shdP_U * algebraMap GF shdP_K (blkHUVal rnd col).2)).trans
    (by
      rw [Finset.sum_add_distrib, ← Finset.mul_sum, ← map_sum, ← map_sum,
        blkHUVal_sum_re rnd, blkHUVal_sum_im rnd, map_zero, mul_zero, add_zero])

private theorem blk_ioBnd_eq (cm : Cm) (y : shieldS0.Pos → ℤ) (TB : Table)
    (hTB : FullBndTableSpec y TB) (hy : ∀ p, i16 (y p)) (b : Fin 19 → Bool) :
    planeZ shdP_U 14 38 0 (tabMat 38 14 TB.rows) ⟨cm, [(0, Fp2.one)], 19, [], 0, 0⟩ b
      = algebraMap GF shdP_K (if h : msbIndex 12 (splitD cS b).2 < 3072
          then (y (blkTokInv (splitD cS b).1, ⟨msbIndex 12 (splitD cS b).2, h⟩) : GF) else 0) := by
  have hb := msbIndex_lt 19 b
  have hlhs := planeZ_single_eq 38 14 0 19 cm (by norm_num) (tabMat 38 14 TB.rows) b
  rw [Nat.zero_mul] at hlhs
  rw [hlhs]
  have hrLt : msbIndex 19 b / 2 ^ 14 < 32 := by omega
  have hcolLt : msbIndex 19 b % 2 ^ 14 < 16384 := by omega
  have hrEq : (⟨0 + msbIndex 19 b / 2 ^ 14, by omega⟩ : Fin 38) = ⟨msbIndex 19 b / 2 ^ 14, by omega⟩ :=
    Fin.ext (Nat.zero_add _)
  have htm := hTB.tabMat_at hy ⟨msbIndex 19 b / 2 ^ 14, hrLt⟩ ⟨msbIndex 19 b % 2 ^ 14, hcolLt⟩
  dsimp only at htm
  rw [hrEq, htm]
  have hflat : (msbIndex 19 b / 2 ^ 14) * 16384 + msbIndex 19 b % 2 ^ 14 = msbIndex 19 b := by
    rw [show (2 : ℕ) ^ 14 = 16384 by norm_num, Nat.mul_comm, Nat.div_add_mod]
  have hsplit := msbIndex_split 7 12 b
  have htok : (fun a : Fin 7 => b ⟨a.val, by omega⟩) = (splitD cS b).1 := rfl
  have hwid : (fun a : Fin 12 => b ⟨7 + a.val, by omega⟩) = (splitD cS b).2 := rfl
  rw [htok, hwid, show (2 : ℕ) ^ 12 = 4096 by norm_num] at hsplit
  have hwidLt : msbIndex 12 (splitD cS b).2 < 4096 := by
    have h := msbIndex_lt 12 (splitD cS b).2; omega
  have hdiv4 : msbIndex 19 b / 4096 = msbIndex 7 (splitD cS b).1 := by
    rw [hsplit, Nat.add_comm, Nat.add_mul_div_right _ _ (by norm_num), Nat.div_eq_of_lt hwidLt, Nat.zero_add]
  have hmod4 : msbIndex 19 b % 4096 = msbIndex 12 (splitD cS b).2 := by
    rw [hsplit, Nat.add_comm, Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt hwidLt]
  have hcond : ((msbIndex 19 b / 2 ^ 14) * 16384 + msbIndex 19 b % 2 ^ 14) % 4096
      = msbIndex 12 (splitD cS b).2 := by rw [hflat, hmod4]
  by_cases hc : msbIndex 12 (splitD cS b).2 < 3072
  · have hc' : ((msbIndex 19 b / 2 ^ 14) * 16384 + msbIndex 19 b % 2 ^ 14) % 4096 < 3072 := by
      rw [hcond]; exact hc
    rw [dite_eq_left hc', dite_eq_left hc]
    exact congrArg (fun p : shieldS0.Pos => algebraMap GF shdP_K (y p : GF))
      (Prod.ext (Fin.ext (by dsimp only [blkTokInv]; rw [hflat, hdiv4])) (Fin.ext hcond))
  · have hc' : ¬ ((msbIndex 19 b / 2 ^ 14) * 16384 + msbIndex 19 b % 2 ^ 14) % 4096 < 3072 := by
      rw [hcond]; exact hc
    rw [dite_eq_right hc', dite_eq_right hc, map_zero]

/-- **Slot 21 (`SC_IOIN`) input-boundary continuity**: `TB_prev` equals `A` plane `X` (`q = 8`) pointwise on `2^19`. -/
theorem blk_ioIn_eq (hTB : FullBndTableSpec xIn TB_prev) (hxIn : ∀ p, i16 (xIn p)) (b : Fin 19 → Bool) :
    planeZ shdP_U (Block.rowLog P .inp) ((DS).rows .inp) ((DS).Q .inp) ((DS).X .inp)
        ⟨.inp, [(0, Fp2.one)], 19, [], 0, 0⟩ b
      = aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 8) 19 b := by
  rw [planeZ_blkCmData_inp,
    blk_ioBnd_eq (Ly := Ly) .inp xIn TB_prev hTB hxIn b,
    blk_aPl_D P hlc hep w rnd bga TB_prev TB_next 8 (by norm_num) (by norm_num) b,
    show blkDomPlane w .D 8 b = w.E.X ((splitD cS b).1, (splitD cS b).2) from rfl,
    w.X_eq (splitD cS b).1 (splitD cS b).2]

/-- **Slot 22 (`SC_IOOUT`) output-boundary continuity**: `TB_next` equals `A` plane `X2` (`q = 44`) pointwise on `2^19`. -/
theorem blk_ioOut_eq (hTB : FullBndTableSpec xOut TB_next) (hxOut : ∀ p, i16 (xOut p)) (b : Fin 19 → Bool) :
    planeZ shdP_U (Block.rowLog P .out) ((DS).rows .out) ((DS).Q .out) ((DS).X .out)
        ⟨.out, [(0, Fp2.one)], 19, [], 0, 0⟩ b
      = aPl shdP_U P DS (Exec.Block.DefR13.aOff cS 44) 19 b := by
  rw [planeZ_blkCmData_out,
    blk_ioBnd_eq (Ly := Ly) .out xOut TB_next hTB hxOut b,
    blk_aPl_D P hlc hep w rnd bga TB_prev TB_next 44 (by norm_num) (by norm_num) b,
    show blkDomPlane w .D 44 b = w.E.X2 ((splitD cS b).1, (splitD cS b).2) from rfl,
    w.X2_eq (splitD cS b).1 (splitD cS b).2]

end ConcreteVanishing

end HostAndStandaloneVanishing

/-! ## 7. LogUp Sum-Claim Truth (`blk_logupSumClaim_true` & `blk_logupSumClaim_true_of_spec`) -/

section BlockLogUpSumClaim

private theorem logupSumR13_eq_sub (c : W16Cfg) (hc : Exec.Block.Join.R13H.Look.LookCfg c 1)
    (P : BlockParams) (D : CmData shdP_K P) (hln : Block.rowLog P .h = 14)
    (hzs : ∑ b : Fin 14 → Bool,
      hPl shdP_U P D (Exec.Block.DefR13.hOff c (Exec.Block.DefR13.fh c 10)).1
        (Exec.Block.DefR13.hOff c (Exec.Block.DefR13.fh c 10)).2 14 b = 0) :
    Link.claimSem shdP_U (D.rows .h) (Block.rowLog P .h) (D.Q .h) (D.X .h) (logupSumR13 c)
      = (∑ i : SgIx c,
            hPl shdP_U P D (Exec.Block.DefR13.hOff c (i.1.hp 1)).1
              (Exec.Block.DefR13.hOff c (i.1.hp 1)).2 (i.1.log c) i.2)
        + (∑ k : PrIx c 1,
            hPl shdP_U P D (Exec.Block.DefR13.hOff c (k.1.fh 1 + k.2.1)).1
              (Exec.Block.DefR13.hOff c (k.1.fh 1 + k.2.1)).2 (k.1.log c) k.2.2)
        - (∑ j : TbIx, Exec.Block.Join.R13T.helpTabR shdP_U c P D j.1 j.2) := by
  rw [logupSumR13_planes shdP_U shdP_hU hc P D hln]
  have hf8 : Exec.Block.DefR13.fh c 8 = 49 := (fh_eq hc).2.2.2.2.2.2.2.2.1
  have hf10 : Exec.Block.DefR13.fh c 10 = 52 := (fh_eq hc).2.2.2.2.2.2.2.2.2
  have c1 : ∑ x ∈ Finset.range (52 + 1), fR shdP_U c P D x
      = ∑ x ∈ Finset.range 52, fR shdP_U c P D x + fR shdP_U c P D 52 := Finset.sum_range_succ _ 52
  have c2 : ∑ x ∈ Finset.range 52, fR shdP_U c P D x
      = ∑ x ∈ Finset.range 49, fR shdP_U c P D x + ∑ x ∈ Finset.range 3, fR shdP_U c P D (49 + x) :=
    Finset.sum_range_add (fR shdP_U c P D) 49 3
  have c3 : ∑ x ∈ Finset.range 49, fR shdP_U c P D x
      = ∑ x ∈ Finset.range 48, fR shdP_U c P D x + fR shdP_U c P D 48 := Finset.sum_range_succ _ 48
  have c4 : ∑ x ∈ Finset.range 48, fR shdP_U c P D x
      = ∑ x ∈ Finset.range 41, fR shdP_U c P D x + ∑ x ∈ Finset.range 7, fR shdP_U c P D (41 + x) :=
    Finset.sum_range_add (fR shdP_U c P D) 41 7
  have c5 : ∑ x ∈ Finset.range 41, fR shdP_U c P D x
      = ∑ x ∈ Finset.range 40, fR shdP_U c P D x + fR shdP_U c P D 40 := Finset.sum_range_succ _ 40
  have c6 : ∑ x ∈ Finset.range 40, fR shdP_U c P D x
      = ∑ x ∈ Finset.range 39, fR shdP_U c P D x + fR shdP_U c P D 39 := Finset.sum_range_succ _ 39
  have c7 : ∑ x ∈ Finset.range 39, fR shdP_U c P D x
      = ∑ x ∈ Finset.range 32, fR shdP_U c P D x + ∑ x ∈ Finset.range 7, fR shdP_U c P D (32 + x) :=
    Finset.sum_range_add (fR shdP_U c P D) 32 7
  have c8 : ∑ x ∈ Finset.range 32, fR shdP_U c P D x
      = ∑ x ∈ Finset.range 25, fR shdP_U c P D x + ∑ x ∈ Finset.range 7, fR shdP_U c P D (25 + x) :=
    Finset.sum_range_add (fR shdP_U c P D) 25 7
  have c9 : ∑ x ∈ Finset.range 25, fR shdP_U c P D x
      = ∑ x ∈ Finset.range 18, fR shdP_U c P D x + ∑ x ∈ Finset.range 7, fR shdP_U c P D (18 + x) :=
    Finset.sum_range_add (fR shdP_U c P D) 18 7
  have c10 : ∑ x ∈ Finset.range 18, fR shdP_U c P D x
      = ∑ x ∈ Finset.range 1, fR shdP_U c P D x + ∑ x ∈ Finset.range 17, fR shdP_U c P D (1 + x) :=
    Finset.sum_range_add (fR shdP_U c P D) 1 17
  have dom : ∀ hp d, domAt 1 hp = d → ¬ (49 ≤ hp ∧ hp < 52) →
      fR shdP_U c P D hp = PSpR shdP_U c P D hp (c.sh.logs d) := fun hp d hd hs => by
    rw [fR_dom shdP_U hc P D hp d hd, ite_eq_right (by omega : ¬ (48 + 1 ≤ hp ∧ hp < 51 + 1)), one_mul]
  have bL : fR shdP_U c P D 0 = ∑ j ∈ Finset.range (Dm.np 1 .L), PSpR shdP_U c P D (Dm.fh 1 .L + j) (Dm.log c .L) := by
    rw [show Dm.np 1 .L = 1 from rfl, Finset.sum_range_one]
    exact dom 0 .L rfl (by omega)
  have bD : ∑ x ∈ Finset.range 17, fR shdP_U c P D (1 + x)
      = ∑ j ∈ Finset.range (Dm.np 1 .D), PSpR shdP_U c P D (Dm.fh 1 .D + j) (Dm.log c .D) :=
    Finset.sum_congr rfl (fun x hx => by
      have hx' : x < 17 := Finset.mem_range.mp hx
      exact dom _ .D (by unfold domAt; rw [ite_eq_right (by omega), ite_eq_left (by omega)]) (by omega))
  have bQ : ∑ x ∈ Finset.range 7, fR shdP_U c P D (18 + x)
      = ∑ j ∈ Finset.range (Dm.np 1 .Q), PSpR shdP_U c P D (Dm.fh 1 .Q + j) (Dm.log c .Q) :=
    Finset.sum_congr rfl (fun x hx => by
      have hx' : x < 7 := Finset.mem_range.mp hx
      exact dom _ .Q (by unfold domAt; rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]) (by omega))
  have bK : ∑ x ∈ Finset.range 7, fR shdP_U c P D (25 + x)
      = ∑ j ∈ Finset.range (Dm.np 1 .Kv), PSpR shdP_U c P D (Dm.fh 1 .Kv + j) (Dm.log c .Kv) :=
    Finset.sum_congr rfl (fun x hx => by
      have hx' : x < 7 := Finset.mem_range.mp hx
      exact dom _ .Kv (by unfold domAt; rw [ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_left (by omega)]) (by omega))
  have bS : ∑ x ∈ Finset.range 7, fR shdP_U c P D (32 + x)
      = ∑ j ∈ Finset.range (Dm.np 1 .S), PSpR shdP_U c P D (Dm.fh 1 .S + j) (Dm.log c .S) :=
    Finset.sum_congr rfl (fun x hx => by
      have hx' : x < 7 := Finset.mem_range.mp hx
      exact dom _ .S (by unfold domAt; rw [ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]) (by omega))
  have bF : ∑ x ∈ Finset.range 7, fR shdP_U c P D (41 + x)
      = ∑ j ∈ Finset.range (Dm.np 1 .F), PSpR shdP_U c P D (Dm.fh 1 .F + j) (Dm.log c .F) :=
    Finset.sum_congr rfl (fun x hx => by
      have hx' : x < 7 := Finset.mem_range.mp hx
      exact dom _ .F (by unfold domAt; rw [ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]) (by omega))
  have sS : fR shdP_U c P D 39 = PSpR shdP_U c P D (Sg.hp 1 .S) (Sg.log c .S) :=
    dom 39 .S rfl (by omega)
  have sE : fR shdP_U c P D 40 = PSpR shdP_U c P D (Sg.hp 1 .Exp) (Sg.log c .Exp) :=
    dom 40 .S rfl (by omega)
  have sA : fR shdP_U c P D 48 = PSpR shdP_U c P D (Sg.hp 1 .Act) (Sg.log c .Act) :=
    dom 48 .F rfl (by omega)
  have bT : ∑ x ∈ Finset.range 3, fR shdP_U c P D (49 + x)
      = - ∑ k ∈ Finset.range 3, PSpR shdP_U c P D (Exec.Block.DefR13.fh c 8 + k) 14 := by
    rw [← Finset.sum_neg_distrib]
    refine Finset.sum_congr rfl (fun x hx => ?_)
    have hx' : x < 3 := Finset.mem_range.mp hx
    have hd : domAt 1 (49 + x) = .Tab := by
      unfold domAt
      rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega)]
    rw [fR_dom shdP_U hc P D _ .Tab hd,
      ite_eq_left (by omega : 48 + 1 ≤ 49 + x ∧ 49 + x < 51 + 1), hc.logTab, hf8, neg_one_mul]
  have sU : fR shdP_U c P D 52 = 0 := by
    rw [dom 52 .Tab rfl (by omega), hc.logTab]
    unfold PSpR
    rw [← hf10]
    exact hzs
  have gS : ∑ i : SgIx c, hPl shdP_U P D (Exec.Block.DefR13.hOff c (i.1.hp 1)).1
        (Exec.Block.DefR13.hOff c (i.1.hp 1)).2 (i.1.log c) i.2
      = PSpR shdP_U c P D (Sg.hp 1 .S) (Sg.log c .S)
        + (PSpR shdP_U c P D (Sg.hp 1 .Exp) (Sg.log c .Exp)
          + PSpR shdP_U c P D (Sg.hp 1 .Act) (Sg.log c .Act)) := by
    rw [Fintype.sum_sigma, sum_sg]; rfl
  have gP : ∑ k : PrIx c 1, hPl shdP_U P D (Exec.Block.DefR13.hOff c (k.1.fh 1 + k.2.1)).1
        (Exec.Block.DefR13.hOff c (k.1.fh 1 + k.2.1)).2 (k.1.log c) k.2.2
      = ∑ d : Dm, ∑ j ∈ Finset.range (d.np 1), PSpR shdP_U c P D (d.fh 1 + j) (d.log c) := by
    rw [Fintype.sum_sigma]
    refine Fintype.sum_congr _ _ (fun d => ?_)
    rw [Fintype.sum_prod_type]
    exact Fin.sum_univ_eq_sum_range (fun j => PSpR shdP_U c P D (d.fh 1 + j) (d.log c)) (d.np 1)
  have gT : ∑ j : TbIx, Exec.Block.Join.R13T.helpTabR shdP_U c P D j.1 j.2
      = ∑ k ∈ Finset.range 3, PSpR shdP_U c P D (Exec.Block.DefR13.fh c 8 + k) 14 := by
    rw [Fintype.sum_prod_type]
    exact Fin.sum_univ_eq_sum_range (fun k => PSpR shdP_U c P D (Exec.Block.DefR13.fh c 8 + k) 14) 3
  rw [c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, Finset.sum_range_one,
    bL, bD, bQ, bK, bS, bF, sS, sE, sA, bT, sU, gS, gP, gT, sum_dm]
  ring

private theorem blk_logupSumClaim_true_aux {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (P0 : BlockParams) (hlc : P0.logCols = 14) (hep : P0.endpointLogN = 14)
    (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand) (bga : Fp2 × Fp2 × Fp2) :
    ClaimTrue shdP_U (2 ^ 14) 14 (blkTH w rnd bga).rows
      (toZClaim (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 Ly))) := by
  let D0 := blkCmData P0 hlc hep (blkTA w rnd) (blkTH w rnd bga) (blkTA w rnd) (blkTA w rnd)
  rw [claimTrue_iff_claimSem shdP_U 4390 14 (blkTH w rnd bga).rows (blkTH_rows_len w rnd bga),
    show (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 Ly)).value = Fp2.zero from rfl, Fp2.toK_zero,
    show Link.claimSem shdP_U 4390 14 0 (tabMat 4390 14 (blkTH w rnd bga).rows)
        (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 Ly))
      = blkCs (blkTA w rnd) (blkTH w rnd bga) (blkTA w rnd) (blkTA w rnd) .h
        (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 Ly)) from rfl,
    blkCs_eq_claimSem P0 hlc hep (blkTA w rnd) (blkTH w rnd bga) (blkTA w rnd) (blkTA w rnd) .h
      (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 Ly)),
    logupSumR13_eq_sub (Exec.Block.DefR13.cfgShieldR13 Ly) (lookCfg_shield Ly) P0 D0
      (blkRowLog_eq P0 hlc hep .h)
      (blk_hU_sum_eq_zero P0 hlc hep w rnd bga (blkTA w rnd) (blkTA w rnd))]
  have hS_val : (∑ i : SgIx (Exec.Block.DefR13.cfgShieldR13 Ly),
        hPl shdP_U P0 D0 (Exec.Block.DefR13.hOff (Exec.Block.DefR13.cfgShieldR13 Ly) (i.1.hp 1)).1
          (Exec.Block.DefR13.hOff (Exec.Block.DefR13.cfgShieldR13 Ly) (i.1.hp 1)).2
          (i.1.log (Exec.Block.DefR13.cfgShieldR13 Ly)) i.2)
      = ∑ i : SgIx (Exec.Block.DefR13.cfgShieldR13 Ly), blkInvK bga (blkSgTupGF w i.1 i.2) :=
    Fintype.sum_congr _ _ (fun i => blk_hPl_sg P0 hlc hep w rnd bga (blkTA w rnd) (blkTA w rnd) i.1 i.2)
  have hP_val : (∑ k : PrIx (Exec.Block.DefR13.cfgShieldR13 Ly) 1,
        hPl shdP_U P0 D0 (Exec.Block.DefR13.hOff (Exec.Block.DefR13.cfgShieldR13 Ly) (k.1.fh 1 + k.2.1)).1
          (Exec.Block.DefR13.hOff (Exec.Block.DefR13.cfgShieldR13 Ly) (k.1.fh 1 + k.2.1)).2
          (k.1.log (Exec.Block.DefR13.cfgShieldR13 Ly)) k.2.2)
      = (∑ k : PrIx (Exec.Block.DefR13.cfgShieldR13 Ly) 1, blkInvK bga (blkLkAtGF w k.1 (2 * k.2.1.val) k.2.2))
        + (∑ k : PrIx (Exec.Block.DefR13.cfgShieldR13 Ly) 1, blkInvK bga (blkLkAtGF w k.1 (2 * k.2.1.val + 1) k.2.2)) := by
    rw [← Finset.sum_add_distrib]
    exact Fintype.sum_congr _ _ (fun k => blk_hPl_pair P0 hlc hep w rnd bga (blkTA w rnd) (blkTA w rnd) k.1 k.2.1 k.2.2)
  have hT_val : (∑ j : TbIx, Exec.Block.Join.R13T.helpTabR shdP_U (Exec.Block.DefR13.cfgShieldR13 Ly) P0 D0 j.1 j.2)
      = ∑ j : TbIx, (blkMult w j : shdP_K) * blkInvK bga (tabTupE Pb.exp Pb.act Ly.nG j.1.val (msbIndex 14 j.2)) :=
    Fintype.sum_congr _ _ (fun j => blk_helpTabR_eq P0 hlc hep w rnd bga (blkTA w rnd) (blkTA w rnd) j.1 j.2)
  have hLk : (∑ i : SgIx (Exec.Block.DefR13.cfgShieldR13 Ly), blkInvK bga (blkSgTupGF w i.1 i.2))
        + ((∑ k : PrIx (Exec.Block.DefR13.cfgShieldR13 Ly) 1, blkInvK bga (blkLkAtGF w k.1 (2 * k.2.1.val) k.2.2))
          + (∑ k : PrIx (Exec.Block.DefR13.cfgShieldR13 Ly) 1, blkInvK bga (blkLkAtGF w k.1 (2 * k.2.1.val + 1) k.2.2)))
      = ∑ l : BlkLkIx Ly, blkInvK bga (blkLkTup w l) := by
    rw [Fintype.sum_sum_type, Fintype.sum_sum_type]
    refine congrArg₂ (· + ·)
      (Fintype.sum_congr _ _ fun ⟨_, _⟩ => rfl)
      (congrArg₂ (· + ·)
        (Fintype.sum_congr _ _ fun ⟨_, _, _⟩ => rfl)
        (Fintype.sum_congr _ _ fun ⟨_, _, _⟩ => rfl))
  have hfib : ∑ l : BlkLkIx Ly, blkInvK bga (blkLkTup w l)
      = ∑ j : TbIx, (blkMult w j : shdP_K) * blkInvK bga (tabTupE Pb.exp Pb.act Ly.nG j.1.val (msbIndex 14 j.2)) :=
    blkMult_sum_fiber_all w
      (fun q => (bga.2.2.toK shdP_U - fold (bga.1.toK shdP_U) (bga.2.1.toK shdP_U) q)⁻¹)
  rw [hS_val, hP_val, hT_val, hLk]
  exact (sub_eq_zero.mpr hfib).symm

/-- **Block `logupSumClaim` is `ClaimTrue` on `blkTH w rnd bga`** (for any `w : BlkWitness`,
which carries `w.hAct0 : Pb.act 0 2048 = 0`, and any `bga`). -/
theorem blk_logupSumClaim_true {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (rnd : BlkRand)
    (bga : Fp2 × Fp2 × Fp2) :
    ClaimTrue shdP_U (2 ^ 14) 14 (blkTH w rnd bga).rows
      (toZClaim (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 Ly))) :=
  blk_logupSumClaim_true_aux (shdP_blkParams MTag.legacy 0 0 (fun _ _ _ _ => .ok ()) Ly Pb) rfl rfl w rnd bga

/-- Explicit-`hAct0` specialization of `blk_logupSumClaim_true` directly from `blockSpec Pb xIn = some xOut`. -/
theorem blk_logupSumClaim_true_of_spec (Ly : ShieldLayer) (hLy : Ly ∈ shieldExport)
    (Pb : BlockPublic (shieldShape Ly)) (hPb : Pb.Valid) (hAct0 : Pb.act 0 2048 = 0)
    (xIn xOut : shieldS0.Pos → ℤ) (hxIn : ∀ p, i16 (xIn p)) (hspec : blockSpec Pb xIn = some xOut)
    (rnd : BlkRand) (bga : Fp2 × Fp2 × Fp2) :
    ClaimTrue shdP_U (2 ^ 14) 14
      (blkTH (blkWitness_of_spec Ly hLy Pb hPb hAct0 xIn xOut hxIn hspec) rnd bga).rows
      (toZClaim (logupSumR13 (Exec.Block.DefR13.cfgShieldR13 Ly))) :=
  blk_logupSumClaim_true (blkWitness_of_spec Ly hLy Pb hPb hAct0 xIn xOut hxIn hspec) rnd bga

end BlockLogUpSumClaim

end ZK60.HonestShield
