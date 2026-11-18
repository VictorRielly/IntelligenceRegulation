/-
D63 lane L63 (2026-11-18), part 77: **part `Lb + 1`'s lists of `shdRkD` are stage OUT-C's** (a first piece of
`hLO_stg` and `hdoutC`, the OUT-C analogues of `shdRkD_r0_zero` / `shdRkD_sls_zero`, RunStgShieldIncNum.lean):

* **`shdRkD_r0_out`**: part `Lb + 1`'s first relation schedule is OUT-C's define draws (`sshΦO`, `sshDgO`);
* **`shdRkD_sls_out`**: its slots are OUT-C's slot schedule (`stgFstO`, `stgHostOut`);
* **`shdRkD_lu_out`**: its LogUp list is OUT-C's head LogUp run (`stgLkSqV 2 … ΛO`);
(all through `shdRkD_eq_ebData` and lane L66's `shd_hbL`, RunBlkPinsHd.lean, not edited);
* **`stg_outc_def_zero`**: no doomed `rtKR0` entrant ⇒ at every OUT-C reading each drawing slot's define polynomial
  vanishes at every draw (at the view before the draw).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncNum
import ZK60Formal.RunStgShieldIncRun

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)
open ZK60.RunShape (ClassifyRunPublicP)

section R0Out

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- **Part `Lb + 1`'s first relation schedule of `shdRkD` is stage OUT-C's define draws** (`shd_hbL`'s `hr0`). -/
theorem shdRkD_r0_out
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → Block.BlockParams)
    {blks : List (ZK60.RunShape.RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : Block.BlockParams)
    (csIOI csIOO : StgVw Lq → Block.Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop) :
    (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).r0 (Lb + 1)
      = stgDefsV P0out 2 (pf.off (Lb + 1) + 2) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (sshΦO U hbij tag h64 P0out F (pf.off (Lb + 1) + pout.pre) (pf.off (Lb + 1) + 2)
          ogStage.lc ogStage.h ogStage.Q ogStage.e Oout_rA Oout_rH csIOO) sshDgO := by
  rw [shdRkD_eq_ebData U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO]
  show (rxPs _ Lb _ _ _ (Lb + 1)).r0 = _
  rw [rxPs_out]
  exact (shd_hbL U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).hr0

/-- **Part `Lb + 1`'s slots of `shdRkD` are stage OUT-C's slot schedule** (`shd_hbL`'s `hsls`). -/
theorem shdRkD_sls_out
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → Block.BlockParams)
    {blks : List (ZK60.RunShape.RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : Block.BlockParams)
    (csIOI csIOO : StgVw Lq → Block.Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop) :
    (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).sls (Lb + 1)
      = stgSchedV P0out 2 (pf.off (Lb + 1) + 2) (stgHostOut P0out) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (stgFstO U hbij tag h64 P0out (vdWout F) (pf.off (Lb + 1) + pout.pre) (pf.off (Lb + 1) + 2)
          ogStage.lc ogStage.h ogStage.Q ogStage.e Oout_rA Oout_rH pout.S csIOO) := by
  rw [shdRkD_eq_ebData U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO]
  show (rxPs _ Lb _ _ _ (Lb + 1)).sls = _
  rw [rxPs_out]
  exact (shd_hbL U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).hsls


/-- **Part `Lb + 1`'s LogUp list of `shdRkD` is stage OUT-C's head LogUp run** (`shd_hbL`'s `hlu`). -/
theorem shdRkD_lu_out
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → Block.BlockParams)
    {blks : List (ZK60.RunShape.RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
    (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
    (pin pout : RtPart) (mIn kIn kOut : ℕ)
    (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
    (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
    (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
    (P0in P0out : Block.BlockParams)
    (csIOI csIOO : StgVw Lq → Block.Cm → Exec.Block.ZClaim → K)
    (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop) :
    (shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
      pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
      Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).lu (Lb + 1)
      = [stgLkSqV 2 (pf.off (Lb + 1) + 2) eO (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO] := by
  rw [shdRkD_eq_ebData U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO]
  show (rxPs _ Lb _ _ _ (Lb + 1)).lu = _
  rw [rxPs_out]
  exact (shd_hbL U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).hlu


end R0Out

section ZeroOut

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **NO DOOMED R0 ENTRANT: STAGE OUT-C'S DEFINE POLYNOMIAL AT A DRAWING SLOT VANISHES AT EVERY DRAW** at every
OUT-C reading (part `Lb + 1`, `m = 2`), at the view before the slot's draw (`stg_defAlive_of_notR0`,
`stg_def_zero_of_alive`; the OUT-C analogue of `stg_inc_def_zero` before its view transport). -/
theorem stg_outc_def_zero (n Lb : ℕ) (hi : Lb + 1 < pf.parts.length) (hin : Lb + 1 < n) (tag : MTag)
    (h64 : 64 ≤ Lq) (P0 : Block.BlockParams) (F : ℕ → OutcV) (b n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K)
    (hR : D.r0 (Lb + 1) = stgDefsV P0 2 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hno : ¬ (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq (fun _ => (F b).bp) 2 hdrLen OutcV.bga G τ hdr core ch rs)
    (hP : StgSame P0 (F b).bp) (hgt : (F b).bp.geom.slots.length = (F b).bp.geom.terms.length)
    (hgeom : ∀ k, k < (F b).bp.geom.slots.length → 1 ≤ (Block.slotShape (F b).bp k).2.2)
    (k : ℕ) (hk : k ∈ stgDrawing P0) :
    ∀ y, sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg
          (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (F b).bp core 2 ++ Block.fullOps (F b).bp 0 (core.slots.take k)))) k
        (ch, (rs.take k).map Block.SlotRec.draws) y = 0 := by
  have hal := stg_defAlive_of_notR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD n (Lb + 1) hi hin P0
    (fun _ => (F b).bp) 2 hdrLen OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
    (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO G lg τ hdr core ch rs hrd hP hgt hR hno k hk
  have hslen : core.slots.length = (F b).bp.geom.slots.length := hrd.2.2.2.1.1
  have hkl : k < core.slots.length := by
    rw [hslen, ← hP.2]
    exact List.mem_range.mp (List.mem_filter.mp hk).1
  exact stg_def_zero_of_alive key domain P0 (fun _ => (F b).bp) 2 hdrLen OutcV.bga
    (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO)
    sshDgO G lg τ hdr core ch rs hrd hP hgeom hgt k hkl.le hal

end ZeroOut

end ZK60.ProtocolClassify
