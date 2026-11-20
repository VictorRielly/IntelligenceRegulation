/-
D63 lane L63 (2026-11-20), L63 leg 14, part 90: **OUTC-05 DZC's division clauses in the base field at a live
channel** (item 1 of HANDOFF_20261119_3.md section 6: `OutCFacts`' DZC conjunct, `dzcCB … = 0`, read off
`outc_dzc_clauses` through DZC's table values at `(c, 0)`).

* `outc_identDfix`: DZC's `A D` table at its fixed point (`To`'s entry `0`) is the `D` plane at `fun _ => false`;
* `outc_suppD`: DZC's `supp_d` table at `(c, 0)` is `1` at a live channel (`msbIndex 12 c < d`);
* `dzcPlN`: the twelve `Do` planes read at one cube point as a function on `ℕ`;
* **`outc_dzc_cb`**: at a live channel `c`, `dzcCB P Dt Dz j c = 0` for `j < 3`, where `Dt.pl p = stgPlB` of the
  `A_out` plane `ocC_X + p` at the view and `Dz` the `D` plane at `To`'s entry `0`, the norm constants `2·g0·Cn`,
  `2^tn`, `2^(tn+1)` in the code's `i64` range (`OutCPublic.Valid` gives them).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutDzcCl
import ZK60Formal.RunStgShieldOutDzcV

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.Out (OutCPublic)

section DzcB

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **DZC's `A D` table at its fixed point is the `D` plane at `To`'s entry `0`.** -/
theorem outc_identDfix (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (Vo : OutcV) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14)
    (hlc : 0 < Vo.bp.logCols) {N : ℕ} (hN : N = 13) (c : Fin 12 → Bool) :
    ((outcDzcRest Vo.pub Vo.geo).map
        (stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1
          (fun i : Fin N => (bit (cptS 12 c i) : K)))).getD 13 0
      = stgPlK U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_D) 1 w
          (fun _ => false) := by
  rw [getD_map_lt (outcDzcRest Vo.pub Vo.geo) _ 13 (by rw [outcDzcRest_length]; omega) (.pub [])]
  have hT : (outcDzcRest Vo.pub Vo.geo).getD 13 (.pub [])
      = .priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_D, Fp2.one)], 1,
          fixedC (List.replicate OutcPub.toLog Fp2.zero),
          (outcLay Vo.pub Vo.geo.bLogN).aMaskBase
            + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixA 5 + (0 + (List.range' ocC_X (ocC_MULT - ocC_X)).length)),
          0⟩ := rfl
  rw [hT]
  refine (stgTabK_priv_cptS U hbij hU Vo.bp _ rA ogStage.lc ogStage.Q
    (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA w) (by decide) 12 c hN _ (by intro _; rfl)
    (List.cons_ne_nil _ _) (by norm_num) (by simp [fixedC, OutcPub.toLog]) (by exact hlc)
    (by
      intro c' hc w' hw'
      simp only [fixedC, List.mem_map, List.mem_replicate] at hc
      obtain ⟨a, ⟨-, rfl⟩, rfl⟩ := hc
      have he := Block.Coord.fixed.inj hw'
      subst he
      exact Fp2.canon_zero)).trans ?_
  rw [privZ_mleF U Vo.bp ogStage.lc rA ogStage.Q _ (by decide) _ (List.cons_ne_nil _ _) (by norm_num)]
  have hz : (fun a : Fin 1 => Block.ptK U (Block.xrK 12 (fun i : Fin N => (bit (cptS 12 c i) : K)))
        (fixedC (List.replicate OutcPub.toLog Fp2.zero)) a.val)
      = fun a => (bit ((fun _ : Fin 1 => false) a) : K) := by
    funext a
    have ha : a.val = 0 := by omega
    rw [ha]
    simp [Block.ptK, fixedC, OutcPub.toLog, Block.coordK, Fp2.toK_zero, bit]
  show mleAt _ (fun a : Fin 1 => _) = _
  rw [hz, mleAt_bit]
  have hs : (outcLay Vo.pub Vo.geo.bLogN).aOff ocC_D = (outcLay O 14).aOff ocC_D := by rw [hGb, hOL]
  unfold stgPlK Block.Join.planeZ Block.Join.privZ
  rw [hs]
  try rfl

/-- **DZC's `supp_d` table at `(c, 0)`** (`ldo = 12`). -/
theorem outc_suppD (Vo : OutcV) (cs : Block.Cm → Block.ZClaim → K) (hldo : Vo.pub.ldo = 12) {N : ℕ} (hN : N = 13)
    (c : Fin 12 → Bool) :
    ((outcDzcRest Vo.pub Vo.geo).map
        (stgTabK U hbij Vo.bp cs 12 1 (fun i : Fin N => (bit (cptS 12 c i) : K)))).getD 0 0
      = if msbIndex 12 c < Vo.pub.d then 1 else 0 := by
  rw [getD_map_lt (outcDzcRest Vo.pub Vo.geo) _ 0 (by rw [outcDzcRest_length]; omega) (.pub [])]
  show stgTabK U hbij Vo.bp cs 12 1 _ (.pub (supp Vo.pub.d (2 ^ Vo.pub.ldo))) = _
  have hidx : msbIndex 12 c < 2 ^ Vo.pub.ldo := by rw [hldo]; exact msbIndex_lt 12 c
  rw [stgTabK_pub_cptS U hbij Vo.bp cs 12 c hN _ (by simp [supp, hldo]), supp_getD_toK U _ _ _ hidx]

end DzcB

/-! ## The clauses in the base field -/

section DzcCB

/-- The twelve `Do` planes at one cube point, as a function on `ℕ` (`0` past `12`). -/
noncomputable def dzcPlN {n₀ nd nl nt : ℕ} (Dt : ZK60.StageX.OutCData n₀ nd 12 nl nt) (c : Fin 12 → Bool) (p : ℕ) : GF :=
  if h : p < 12 then Dt.pl ⟨p, h⟩ c else 0

theorem dzcPlN_pl {n₀ nd nl nt : ℕ} (Dt : ZK60.StageX.OutCData n₀ nd 12 nl nt) (c : Fin 12 → Bool) (q : Fin 12) :
    Dt.pl q c = dzcPlN Dt c q.val := by
  unfold dzcPlN
  rw [dite_eq_left q.isLt]

/-- `mbC r` is `r` (small `r`). -/
theorem mbC_nat {K : Type} [Field K] [Algebra GF K] (r : ℕ) (hr : r < 2 ^ 32) :
    (mbC r : K) = algebraMap GF K (r : GF) := by
  unfold mbC
  rw [Fp.new_toGF_ofNat _ (by unfold gP at *; omega)]

variable {K : Type} [Field K] [Algebra GF K]

/-- **The clause `j` on a reader with the planes, `supp = 1` and `D` is the embedded base-field clause.** -/
theorem dzcClG_eq_cb (U : K) {d n₀ nd nl nt : ℕ} (P : OutCPublic d) (Dt : ZK60.StageX.OutCData n₀ nd 12 nl nt)
    (Dz : GF) (c : Fin 12 → Bool) (g : ℕ → K)
    (hg : ∀ p, p < 12 → g (2 + p) = algebraMap GF K (dzcPlN Dt c p)) (h14 : g 14 = algebraMap GF K Dz)
    (hkN : -2 ^ 64 < 2 * P.g0 * P.cn ∧ 2 * P.g0 * P.cn < 2 ^ 64) (htn : P.tn ≤ 16) (j : Fin 3) :
    dzcClG U ((kI (2 * P.g0 * P.cn)).toK U) ((kI (2 ^ P.tn)).toK U) ((kI (2 ^ (P.tn + 1))).toK U) g j.val
      = algebraMap GF K (ZK60.StageX.dzcCB P Dt Dz j c) := by
  have hpow : ∀ m : ℕ, m ≤ 17 → (kI (2 ^ m)).toK U = algebraMap GF K ((2 : GF) ^ m) := by
    intro m hm
    have h2 : (2 : ℤ) ^ m ≤ 2 ^ 17 := pow_le_pow_right₀ (by norm_num) hm
    rw [kI_int_toK U _ (by have : (0 : ℤ) < 2 ^ m := by positivity
                           linarith) (by linarith), ← map_intCast (algebraMap GF K)]
    push_cast
    rfl
  have hN : (kI (2 * P.g0 * P.cn)).toK U = algebraMap GF K ((2 * P.g0 * P.cn : ℤ) : GF) := by
    rw [kI_int_toK U _ hkN.1 hkN.2, ← map_intCast (algebraMap GF K)]
  have hD : (kI (2 ^ P.tn)).toK U = algebraMap GF K ((2 : GF) ^ P.tn) := hpow _ (by omega)
  have hDen : (kI (2 ^ (P.tn + 1))).toK U = algebraMap GF K ((2 : GF) ^ (P.tn + 1)) := hpow _ (by omega)
  have hlb : ∀ p0, p0 + 3 < 12 → lbK g p0
      = algebraMap GF K (ZK60.StageX.limbSum (fun k : Fin 4 => dzcPlN Dt c (p0 + k.val))) := by
    intro p0 hp0
    unfold lbK ZK60.StageX.limbSum
    rw [map_sum, ← Fin.sum_univ_eq_sum_range]
    refine Finset.sum_congr rfl (fun k _ => ?_)
    have hk := k.isLt
    rw [hg (p0 + k.val) (by omega), mbC_nat (2 ^ (8 * k.val))
      (by
        have : 8 * k.val ≤ 24 := by omega
        calc 2 ^ (8 * k.val) ≤ 2 ^ 24 := Nat.pow_le_pow_right (by norm_num) this
          _ < 2 ^ 32 := by norm_num), map_mul, mul_comm]
    push_cast
    rfl
  have e4 : ZK60.StageX.limbSum (fun k : Fin 4 => Dt.pl ⟨4 + k.val, by omega⟩ c)
      = ZK60.StageX.limbSum (fun k : Fin 4 => dzcPlN Dt c (4 + k.val)) := by
    unfold ZK60.StageX.limbSum
    exact Finset.sum_congr rfl (fun k _ => by simp only [dzcPlN_pl])
  have e8 : ZK60.StageX.limbSum (fun k : Fin 4 => Dt.pl ⟨8 + k.val, by omega⟩ c)
      = ZK60.StageX.limbSum (fun k : Fin 4 => dzcPlN Dt c (8 + k.val)) := by
    unfold ZK60.StageX.limbSum
    exact Finset.sum_congr rfl (fun k _ => by simp only [dzcPlN_pl])
  have g2 := hg 0 (by norm_num)
  have g3 := hg 1 (by norm_num)
  have g4 := hg 2 (by norm_num)
  have g5 := hg 3 (by norm_num)
  have h32 : (kI 32768).toK U = algebraMap GF K (32768 : GF) := by
    rw [kI_int_toK U _ (by norm_num) (by norm_num), ← map_intCast (algebraMap GF K)]
    push_cast
    rfl
  have h256 : (mbC 256 : K) = algebraMap GF K ((2 : GF) ^ 8) := by
    rw [mbC_nat 256 (by norm_num)]
    norm_num
  have p0 : Dt.pl 0 c = dzcPlN Dt c 0 := dzcPlN_pl Dt c 0
  have p1 : Dt.pl 1 c = dzcPlN Dt c 1 := dzcPlN_pl Dt c 1
  have p2 : Dt.pl 2 c = dzcPlN Dt c 2 := dzcPlN_pl Dt c 2
  have p3 : Dt.pl 3 c = dzcPlN Dt c 3 := dzcPlN_pl Dt c 3
  fin_cases j
  · show dzcClG U _ _ _ g 0 = _
    unfold dzcClG ZK60.StageX.dzcCB
    simp only [↓reduceIte]
    rw [e4, hlb 4 (by norm_num), p0, p3, hN, hD, hDen, h14]
    simp only [Nat.add_zero] at g2 g5
    rw [show (2 + 3 : ℕ) = 5 by rfl] at g5
    rw [g2, g5]
    simp only [map_sub, map_add, map_mul]
  · show dzcClG U _ _ _ g 1 = _
    unfold dzcClG ZK60.StageX.dzcCB
    simp only [one_ne_zero, ↓reduceIte]
    rw [e4, e8, hlb 4 (by norm_num), hlb 8 (by norm_num), hDen, h14]
    simp only [map_sub, map_add, map_mul, map_one]
  · show dzcClG U _ _ _ g 2 = _
    unfold dzcClG ZK60.StageX.dzcCB
    have h20 : (2 : ℕ) ≠ 0 := by norm_num
    have h21 : (2 : ℕ) ≠ 1 := by norm_num
    simp only [Fin.isValue, h20, h21, ↓reduceIte]
    rw [p0, p1, p2, h32, h256]
    simp only [Nat.add_zero] at g2
    rw [show (2 + 1 : ℕ) = 3 by rfl] at g3
    rw [show (2 + 2 : ℕ) = 4 by rfl] at g4
    rw [g2, g3, g4]
    simp only [map_sub, map_add, map_mul]
    ring

end DzcCB

/-! ## The clauses at a live channel, from DZC's define polynomial -/

section DzcRun

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **OUTC-05 DZC'S DIVISION CLAUSES IN THE BASE FIELD AT A LIVE CHANNEL**, from its define polynomial vanishing at
every draw: `dzcCB P Dt Dz j c = 0` (`j < 3`, `msbIndex 12 c < d`), with `Dt`'s `Do` planes and `Dz` the `A_out`
planes at the view. -/
theorem outc_dzc_cb (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (P0 : Block.BlockParams) (Vo : OutcV)
    (hP : StgSame P0 Vo.bp) (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hlt : Vo.pub.lt ≤ ogStage.lc) (hd : List (List Fp2)) (hhd : hd.length = 5)
    (hzero : ∀ y : Fin (P0.draws 5) → K, stgΦB U hbij P0 Vo.bp
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
      (OutcV.bga ch) hd 5 (stgWords U hbij y) = 0)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hldo : Vo.pub.ldo = 12)
    (hlc : 0 < Vo.bp.logCols)
    {d n₀ nd nl nt : ℕ} (P : OutCPublic d) (hg0 : P.g0 = Vo.pub.g0) (hcn : P.cn = Vo.pub.cn)
    (htn : P.tn = Vo.pub.tn) (hkN : -2 ^ 64 < 2 * P.g0 * P.cn ∧ 2 * P.g0 * P.cn < 2 ^ 64) (htn16 : P.tn ≤ 16)
    (Dt : ZK60.StageX.OutCData n₀ nd 12 nl nt)
    (hpl : ∀ (p : Fin 12) (c : Fin 12 → Bool), Dt.pl p c = stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e
      rA iA ((outcLay O 14).aOff (ocC_X + p.val)) 12 w c)
    (Dz : GF) (hDz : Dz = stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_D) 1
      w (fun _ => false))
    (c : Fin 12 → Bool) (hc : msbIndex 12 c < Vo.pub.d) (j : Fin 3) :
    ZK60.StageX.dzcCB P Dt Dz j c = 0 := by
  have hN : stgN P0 5 = 13 := by unfold stgN; rw [stg_slotShape hP]; show Vo.pub.ldo + 1 = 13; omega
  have e := outc_dzc_clauses U hbij hU tag h64 P0 Vo hP ch hch ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH
    csIO w hlt hd hhd hzero 12 hldo c j.val j.isLt
  rw [outc_suppD U hbij Vo _ hldo hN c, ite_eq_left hc, one_mul, ← hg0, ← hcn, ← htn] at e
  set f := stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1
    (fun i : Fin (stgN P0 5) => (bit (cptS 12 c i) : K)) with hf
  have hg : ∀ p, p < 12 → (fun idx => ((outcDzcRest Vo.pub Vo.geo).map f).getD (idx - 1) 0) (2 + p)
      = algebraMap GF K (dzcPlN Dt c p) := by
    intro p hp
    show ((outcDzcRest Vo.pub Vo.geo).map f).getD (2 + p - 1) 0 = _
    rw [show 2 + p - 1 = 1 + p by omega,
      getD_map_lt (outcDzcRest Vo.pub Vo.geo) f (1 + p) (by rw [outcDzcRest_length]; omega) (.pub []),
      dzcRest_getD_plane Vo.pub Vo.geo p hp]
    rw [hf, outc_identA U hbij tag h64 hU O Vo rA rH iA iH csIO w hGb hOL hlc hN c (ocC_X + p) _
      (by rw [← hldo]; interval_cases p <;> rfl), shdOutcA_alg]
    unfold dzcPlN
    rw [dite_eq_left hp, hpl]
  have h14 : (fun idx => ((outcDzcRest Vo.pub Vo.geo).map f).getD (idx - 1) 0) 14 = algebraMap GF K Dz := by
    show ((outcDzcRest Vo.pub Vo.geo).map f).getD 13 0 = _
    rw [hf, outc_identDfix U hbij tag h64 hU O Vo rA rH iA iH csIO w hGb hOL hlc hN c, hDz]
    exact stgPlK_eq_alg U tag h64 _ _ _ _ _ _ _ _ ogStage_lc_le ogStage_h_le ogStage_radius w _
  rw [dzcClG_eq_cb U P Dt Dz c _ hg h14 hkN htn16 j] at e
  exact (algebraMap GF K).injective (e.trans (map_zero _).symm)

end DzcRun

end ZK60.ProtocolClassify
