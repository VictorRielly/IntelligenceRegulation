/-
D63 lane L63 (2026-11-20), L63 leg 14, part 91: **OUTC-00 IO-in at every live point: the `A_out` plane `X` is
`B_out`'s verdict row** (item 2 of HANDOFF_20261119_3.md section 6, `RelIO` / `OutCFacts`' first conjunct; IN-C's slot
`0` (`ssh_inc0_Φ_tok`, RunStgShieldInX.lean) is the template).

OUTC-00 is `eq·(x − B_out)` (`outcDefIO_ok`): tables `[eq τ, A x at (0…0, ρ), In B_out at (verdict row bits, ρ)]`. At
the draws `y` = the bits of `c` (twelve of them, `d_bits = 12`, no lift) the define polynomial's only non-zero cube term
is `c`'s point with extension bit `0`: the value is `x(c) − B_out(row, c)`, where `B_out(row, c)` is the R13 plane reader
of `bxUxV` (the stage's `csIO` on `.inp`) at the point `msbBits 7 row ++ c` (the same reader as `bndPlanes`).

* `ptK_fixedBits_rho`: the `In` table's point at `(c, 0)` is the bits of `Fin.append (msbBits 7 r) c`;
* `outc_identIn`: the `In` table at `(c, 0)` is the plane reader at that point;
* `outc_identAx`: the `A x` table (lift `0`) at `(c, 0)` is `shdOutcA … ocC_X`;
* **`outc_io0_val`**: `stgΦB … 0` at the bits of `c` is `x(c) − B_out(row, c)`;
* **`outc_io0_eq`**: OUTC-00's define polynomial vanishing at every draw gives, at every `c`, `x(c) = B_out(row, c)`
  in `K`, and in the base field `stgPlB … ocC_X … c = piB (B_out(row, c))`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutDzcB
import ZK60Formal.RunStgShieldIODec
import ZK60Formal.RunStgShieldIOPin

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section IOPt

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The `In` table's point at `(c, 0)`**: the verdict row's seven bits, then `c`. -/
theorem ptK_fixedBits_rho {N : ℕ} (hN : 12 < N) (r : ℕ) (c : Fin 12 → Bool) (a : Fin 19) :
    Block.ptK U (Block.xrK 12 (fun i : Fin N => (bit (cptS 12 c i) : K))) (fixedBits r 7 ++ rhoC 0 12) a.val
      = bit (Fin.append (msbBits 7 r) c a) := by
  have hl : (fixedBits r 7).length = 7 := by simp [fixedBits]
  have ha := a.isLt
  unfold Block.ptK
  by_cases h7 : a.val < 7
  · have hr : Fin.append (msbBits 7 r) c a = msbBits 7 r ⟨a.val, h7⟩ := by
      have e := Fin.append_left (msbBits 7 r) c ⟨a.val, h7⟩
      rw [show (Fin.castAdd 12 ⟨a.val, h7⟩ : Fin (7 + 12)) = a from Fin.ext rfl] at e
      exact e
    rw [hr, List.getElem?_append_left (by rw [hl]; exact h7)]
    unfold fixedBits
    rw [List.getElem?_map, List.getElem?_range h7]
    simp only [Option.map_some, Option.getD_some, Block.coordK]
    unfold msbBits
    by_cases h : r / 2 ^ (7 - 1 - a.val) % 2 = 1
    · simp [h, bit, Fp2.toK_one]
    · simp [h, bit, Fp2.toK_zero]
  · have hr : Fin.append (msbBits 7 r) c a = c ⟨a.val - 7, by omega⟩ := by
      have e := Fin.append_right (msbBits 7 r) c ⟨a.val - 7, by omega⟩
      rw [show (Fin.natAdd 7 ⟨a.val - 7, by omega⟩ : Fin (7 + 12)) = a from Fin.ext (by simp; omega)] at e
      exact e
    rw [hr, List.getElem?_append_right (by rw [hl]; omega), hl]
    unfold rhoC
    rw [List.getElem?_map, List.getElem?_range' (by omega)]
    simp only [Option.map_some, Option.getD_some, Block.coordK, Nat.zero_add, one_mul]
    exact xrK_cptS (K := K) 12 c (a.val - 7) (by omega) hN

end IOPt

section IOVals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **The `In` table at `(c, 0)` is `B_out`'s R13 plane reader at `msbBits 7 r ++ c`.** -/
theorem outc_identIn (hU : U ^ 2 = algebraMap GF K 7) (P : Block.BlockParams) (hep : 0 < P.endpointLogN)
    (rA rH iA iH rX ipos : ℕ) (XO : StgVw Lq → Fin 0 → Fin (2 ^ 0 + 0) → K) (w : StgVw Lq)
    {N : ℕ} (hN : N = 13) (c : Fin 12 → Bool) (r mr : ℕ) :
    stgTabK U hbij P (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH
        (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w) 12 1
        (fun i : Fin N => (bit (cptS 12 c i) : K))
        (.priv ⟨.inp, [(0, Fp2.one)], 19, fixedBits r 7 ++ rhoC 0 12, mr, 0⟩)
      = Block.Join.planeZ U 14 rX 256 (bxUxV tag Lq h64 rX ipos w) ⟨.a, [(0, Fp2.one)], 19, [], 0, 0⟩
          (Fin.append (msbBits 7 r) c) := by
  have hNlt : 12 < N := by omega
  refine (stgTabK_priv_cptS U hbij hU P _ rX 14 256 (bxUxV tag Lq h64 rX ipos w) (by norm_num) 12 c hN _
    (by intro _; rfl) (List.cons_ne_nil _ _) (by norm_num) (by simp [fixedBits, rhoC]) (by exact hep)
    (by
      intro c' hc w' hw'
      rcases List.mem_append.mp hc with hc1 | hc2
      · unfold fixedBits at hc1
        obtain ⟨b, _, hcb⟩ := List.mem_map.mp hc1
        rw [hw'] at hcb
        injection hcb with hcb
        rw [← hcb]
        split_ifs
        · exact Fp2.canon_one
        · exact Fp2.canon_zero
      · simp [rhoC] at hc2
        obtain ⟨_, _, rfl⟩ := hc2
        cases hw')).trans ?_
  rw [privZ_mleF U P 14 rX 256 _ (by norm_num) _ (List.cons_ne_nil _ _) (by norm_num)]
  have hz : (fun a : Fin 19 => Block.ptK U (Block.xrK 12 (fun i : Fin N => (bit (cptS 12 c i) : K)))
        (fixedBits r 7 ++ rhoC 0 12) a.val)
      = fun a => (bit (Fin.append (msbBits 7 r) c a) : K) := by
    funext a
    exact ptK_fixedBits_rho U hNlt r c a
  show mleAt _ (fun a : Fin 19 => _) = _
  rw [hz, mleAt_bit]
  unfold Block.Join.planeZ Block.Join.privZ
  rfl

/-- **The `A x` table (lift `0`) at `(c, 0)` is `shdOutcA … ocC_X`.** -/
theorem outc_identAx (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (Vo : OutcV) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hldo : Vo.pub.ldo = 12)
    (hlc : 0 < Vo.bp.logCols) {N : ℕ} (hN : N = 13) (c : Fin 12 → Bool) (mr : ℕ) :
    stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12 1
        (fun i : Fin N => (bit (cptS 12 c i) : K))
        (.priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_X, Fp2.one)], (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_X 0,
          fixedC (List.replicate 0 Fp2.zero) ++ rhoC 0 12, mr, 0⟩)
      = shdOutcA U tag h64 O rA iA ocC_X w c := by
  have hlog : (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_X 0 = 12 := by rw [← hldo]; rfl
  have hc : fixedC (List.replicate 0 Fp2.zero) ++ rhoC 0 12 = rhoC 0 ((outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_X 0) := by
    rw [hlog]; rfl
  rw [hc]
  exact outc_identA U hbij tag h64 hU O Vo rA rH iA iH csIO w hGb hOL hlc hN c ocC_X mr hlog

end IOVals

section IOPhi

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **OUTC-00'S DEFINE POLYNOMIAL AT THE BITS OF `c`**: the `A_out` plane `X` at `c` minus `B_out`'s verdict row at
`c` (`d_bits = 12`, lift `0`, `t_bits = 7`, `B_out`'s log `19`). -/
theorem outc_io0_val (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (P0 : Block.BlockParams) (Vo : OutcV)
    (hP : StgSame P0 Vo.bp) (ch : List Fp2) (rA rH iA iH rX ipos : ℕ)
    (XO : StgVw Lq → Fin 0 → Fin (2 ^ 0 + 0) → K) (w : StgVw Lq)
    (hlt : Vo.pub.lt ≤ ogStage.lc)
    (hIO : StgCsIODeg U hbij Vo.bp.endpointLogN (OutcPrivIO Vo.pub)
      (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO))
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hldo : Vo.pub.ldo = 12)
    (hdB : Vo.pub.dBits = 12) (hlift : Vo.pub.lift = 0) (htB : Vo.pub.tBits = 7) (hbo : Vo.pub.bOutLog = 19)
    (hlc : 0 < Vo.bp.logCols) (c : Fin 12 → Bool) :
    stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH
        (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w) (OutcV.bga ch) [] 0
        (stgWords U hbij (fun a : Fin (P0.draws 0) => if h : a.val < 12 then (bit (c ⟨a.val, h⟩) : K) else 0))
      = shdOutcA U tag h64 O rA iA ocC_X w c
        - Block.Join.planeZ U 14 rX 256 (bxUxV tag Lq h64 rX ipos w) ⟨.a, [(0, Fp2.one)], 19, [], 0, 0⟩
          (Fin.append (msbBits 7 Vo.pub.verdictRow) c) := by
  set y : Fin (P0.draws 0) → K := fun a => if h : a.val < 12 then (bit (c ⟨a.val, h⟩) : K) else 0 with hy
  have hdraws : P0.draws 0 = 12 := by rw [hP.1]; exact hdB
  have hN : stgN P0 0 = 13 := by unfold stgN; rw [stg_slotShape hP]; show Vo.pub.dBits + 1 = 13; omega
  have hsh : Block.slotShape Vo.bp 0 = (12, 1, 2) := by
    rw [show Block.slotShape Vo.bp 0 = (Vo.pub.dBits, 1, 2) from rfl, hdB]
  -- the slot's tables
  let restTabs : List Block.Tab :=
    [.priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_X, Fp2.one)], (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_X 0,
        fixedC (List.replicate 0 Fp2.zero) ++ rhoC 0 12,
        (outcLay Vo.pub Vo.geo.bLogN).aMaskBase + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixA 0 + 0), 0⟩,
     .priv ⟨.inp, [(0, Fp2.one)], 19, fixedBits Vo.pub.verdictRow 7 ++ rhoC 0 12, Vo.geo.bOutRow, 0⟩]
  have hdef : Vo.bp.define 0 ⟨(OutcV.bga ch).1, (OutcV.bga ch).2.1, (OutcV.bga ch).2.2, []⟩ (stgWords U hbij y)
      = .ok ⟨.eq ((stgWords U hbij y).take 12) 0 :: restTabs, ioPoly, []⟩ := by
    have h := outcDefIO_ok Vo.pub Vo.geo (stgWords U hbij y)
    rw [hdB, hlift, htB, hbo] at h
    exact h
  have hok : ∀ t ∈ restTabs, TabPrivOK (OutcPrivIO Vo.pub) t := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · exact tabPrivOK_a_fixed_rho _ _ _ _ _ _
    rcases List.mem_cons.mp ht with rfl | ht
    · have e := tabPrivOK_outc_io0 Vo.pub Vo.geo.bOutRow
      rw [hbo, htB, hdB] at e
      exact e
    · exact absurd ht List.not_mem_nil
  have hcanT : ∀ t ∈ restTabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
    intro t ht pt s he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    rcases List.mem_cons.mp ht with rfl | ht; · cases he
    exact absurd ht List.not_mem_nil
  let polyK : (ℕ → K) → K := fun g => g 0 * (g 1 - g 2)
  have hpK : ∀ vals : List Fp2, (∀ a ∈ vals, a.Canon) →
      (ioPoly vals).toK U = polyK (fun idx => (vals.map (Fp2.toK U)).getD idx 0) := by
    intro vals hv
    show ((vg vals 0).mul ((vg vals 1).sub (vg vals 2))).toK U = _
    rw [Fp2.toK_mul U hU, Fp2.toK_sub U _ _ (vg_canon hv 1) (vg_canon hv 2), vg_toK_map, vg_toK_map, vg_toK_map]
  have hpDeg : ∀ g : ℕ → (Fin (stgN P0 0) → K) → K,
      (∀ idx, IndDegLE 1 (g idx)) → IndDegLE 2 (fun x => polyK (fun idx => g idx x)) := by
    intro g hg
    exact IndDegLE.mul (hg 0) (IndDegLE.sub (hg 1) (hg 2))
  have hfit : tabsFit 12 restTabs := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · trivial
    rcases List.mem_cons.mp ht with rfl | ht
    · trivial
    · exact absurd ht List.not_mem_nil
  have hev := stgΦB_sa_eval U hbij hU tag h64 P0 Vo.bp hP ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH
    (OutcPrivIO Vo.pub) (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w hlt hIO (OutcV.bga ch) [] 0 12 1 2 12 rfl (by omega) le_rfl rfl hsh restTabs ioPoly y
    hdef hok hcanT polyK hpK hpDeg
  rw [hev, ite_eq_left hfit]
  have hcube := cube_eqDraw_single (M := P0.draws 0) (N := stgN P0 0) 12 (by omega) hN y c
    (fun a ha => by
      show (if h : a < 12 then (bit (c ⟨a, h⟩) : K) else 0) = _
      rw [dite_eq_left ha])
    (fun x : Fin (stgN P0 0) → K =>
      (restTabs.map (stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w) 12 1 x)).getD 0 0 - (restTabs.map (stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w) 12 1 x)).getD 1 0)
  have hcs' : cubeSum (fun x : Fin (stgN P0 0) → K => polyK (fun idx => match idx with
      | 0 => eqDrawK 12 12 1 (by omega) y x
      | j + 1 => (restTabs.map (stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w) 12 1 x)).getD j 0))
      = cubeSum (fun x : Fin (stgN P0 0) → K => eqDrawK 12 12 1 (by omega) y x *
          ((restTabs.map (stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w) 12 1 x)).getD 0 0
            - (restTabs.map (stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w) 12 1 x)).getD 1 0)) := rfl
  rw [hcs', hcube]
  show stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w) 12 1 (fun i : Fin (stgN P0 0) => (bit (cptS 12 c i) : K))
      (.priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_X, Fp2.one)], (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_X 0,
        fixedC (List.replicate 0 Fp2.zero) ++ rhoC 0 12,
        (outcLay Vo.pub Vo.geo.bLogN).aMaskBase + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixA 0 + 0), 0⟩)
    - stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w) 12 1 (fun i : Fin (stgN P0 0) => (bit (cptS 12 c i) : K))
      (.priv ⟨.inp, [(0, Fp2.one)], 19, fixedBits Vo.pub.verdictRow 7 ++ rhoC 0 12, Vo.geo.bOutRow, 0⟩) = _
  rw [outc_identAx U hbij tag h64 hU O Vo rA rH iA iH (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w
    hGb hOL hldo hlc hN c _,
    outc_identIn U hbij tag h64 hU Vo.bp (by show 0 < Vo.geo.bLogN; omega) rA rH iA iH rX ipos XO w hN c _ _]

/-- **OUTC-00 AT EVERY POINT**: its define polynomial vanishing at every draw gives `x(c) = B_out(row, c)` in `K`, and
in the base field `stgPlB … ocC_X … c = piB (B_out(row, c))`. -/
theorem outc_io0_eq (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (P0 : Block.BlockParams) (Vo : OutcV)
    (hP : StgSame P0 Vo.bp) (ch : List Fp2) (rA rH iA iH rX ipos : ℕ)
    (XO : StgVw Lq → Fin 0 → Fin (2 ^ 0 + 0) → K) (w : StgVw Lq)
    (hlt : Vo.pub.lt ≤ ogStage.lc)
    (hIO : StgCsIODeg U hbij Vo.bp.endpointLogN (OutcPrivIO Vo.pub)
      (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO))
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hldo : Vo.pub.ldo = 12)
    (hdB : Vo.pub.dBits = 12) (hlift : Vo.pub.lift = 0) (htB : Vo.pub.tBits = 7) (hbo : Vo.pub.bOutLog = 19)
    (hlc : 0 < Vo.bp.logCols)
    (hzero : ∀ y : Fin (P0.draws 0) → K, stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e
      rA rH iA iH (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO) w) (OutcV.bga ch) [] 0
      (stgWords U hbij y) = 0)
    (c : Fin 12 → Bool) :
    algebraMap GF K (stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_X) 12 w c)
        = Block.Join.planeZ U 14 rX 256 (bxUxV tag Lq h64 rX ipos w) ⟨.a, [(0, Fp2.one)], 19, [], 0, 0⟩
          (Fin.append (msbBits 7 Vo.pub.verdictRow) c)
      ∧ stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_X) 12 w c
        = Exec.Block.Join.W16.piB K (Block.Join.planeZ U 14 rX 256 (bxUxV tag Lq h64 rX ipos w)
          ⟨.a, [(0, Fp2.one)], 19, [], 0, 0⟩ (Fin.append (msbBits 7 Vo.pub.verdictRow) c)) := by
  have h := hzero (fun a : Fin (P0.draws 0) => if h : a.val < 12 then (bit (c ⟨a.val, h⟩) : K) else 0)
  rw [outc_io0_val U hbij tag h64 hU O P0 Vo hP ch rA rH iA iH rX ipos XO w hlt hIO hGb hOL hldo hdB hlift htB hbo
    hlc c, shdOutcA_alg] at h
  have e := sub_eq_zero.mp h
  refine ⟨e, ?_⟩
  rw [← e, Exec.Block.Join.W16.piB_alg]

end IOPhi

end ZK60.ProtocolClassify
