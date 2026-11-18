/-
D63 lane L63 (2026-11-18), part 64: **the registered stage IN-C's numbers at the concrete objects** (item 4b, step 2):
the hypotheses `shd_hLI_run` takes about the stage (`tiLog = 12`, `vocLog = 17`, `tBits = 7`, `bInLog = 19`,
`bLogN = 14`, `lt ≤ lc`, `0 < logCols`, the BOS and `κ` bounds from `Rp.inp.Valid`, `numSpecial`, `v` from
`Rp.inp.V = 131072`, `tokens`, `ctlQ`, the `A_in` rows `41`, the `B_in` rows `38`, the schedule's slot count and draws)
at `shdP_incV`, `shdP_incPub`, `shdP_P0in`, `shdP_Iin`, `cbBndPcs` (RunShieldInstP.lean, lane L67's, not edited), and
**`shdRkD_r0_zero`**, **`shdRkD_sls_zero`**: part `0`'s first relation schedule and slots of `shdRkD` are stage
IN-C's define draws and slot schedule (`shd_hb0`'s `hr0`, `hsls` through `shdRkD_eq_ebData`, both RunBlkPinsHd.lean,
lane L66's).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncAt

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)
open ZK60.RunShape (ClassifyRunPublicP)

section Num

variable (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (embFold : List Fp2 → List Fp2)
  (bInRow : ℕ)

theorem shdN_pub : (shdP_incV tag Rp embDigest embFold bInRow).pub = shdP_incPub Rp embDigest embFold := rfl

theorem shdN_ti : (shdP_incV tag Rp embDigest embFold bInRow).pub.tiLog = 12 :=
  (shdP_incPub_logs Rp embDigest embFold).1

theorem shdN_voc : (shdP_incV tag Rp embDigest embFold bInRow).pub.vocLog = 17 :=
  (shdP_incPub_logs Rp embDigest embFold).2.1

theorem shdN_tB : (shdP_incV tag Rp embDigest embFold bInRow).pub.tBits = 7 := by
  show clog2 128 = 7
  exact shdP_clog2_128

theorem shdN_bIn : (shdP_incV tag Rp embDigest embFold bInRow).pub.bInLog = 19 := by
  show Nat.log2 (128 * 4096) = 19
  rw [show 128 * 4096 = 2 ^ 19 by norm_num]
  exact Nat.log2_two_pow

theorem shdN_Gb : (shdP_incV tag Rp embDigest embFold bInRow).geo.bLogN = 14 := rfl

theorem shdN_lt : (shdP_incV tag Rp embDigest embFold bInRow).pub.lt ≤ ogStage.lc :=
  (shdP_hVi tag Rp embDigest embFold bInRow).1

theorem shdN_lc : ∀ cx, 0 < ((shdP_incV tag Rp embDigest embFold bInRow).bp cx).logCols := by
  intro cx
  show 0 < 12
  norm_num

theorem shdN_bos (hP : Rp.inp.Valid) : (shdP_incV tag Rp embDigest embFold bInRow).pub.bos < 2 ^ 63 := by
  show Rp.inp.bos < 2 ^ 63
  have h1 := hP.bos
  have h2 := hP.V2
  omega

theorem shdN_kap (hP : Rp.inp.Valid) : ∀ t, (shdP_incV tag Rp embDigest embFold bInRow).pub.kappa t < 2 ^ 63 := by
  intro t
  show (if h : t < 128 then Rp.inp.kap ⟨t, h⟩ else 0) < 2 ^ 63
  split_ifs with h
  · have h1 := hP.kap ⟨t, h⟩
    have h2 := hP.V2
    omega
  · norm_num

theorem shdN_ns : (shdP_incV tag Rp embDigest embFold bInRow).pub.numSpecial = Rp.inp.ns := rfl

theorem shdN_v (hV : Rp.inp.V = 131072) : (shdP_incV tag Rp embDigest embFold bInRow).pub.v = Rp.inp.V := by
  rw [hV]
  rfl

theorem shdN_tok : (shdP_incV tag Rp embDigest embFold bInRow).pub.tokens = 128 := rfl

theorem shdN_cq : ∀ t : shieldS0.Tok,
    (shdP_incV tag Rp embDigest embFold bInRow).pub.ctlQ t.val = decide (ctlPos Rp.inp t = 1) :=
  (shdP_incPub_lay Rp embDigest embFold).2.1

theorem shdN_rA {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) :
    (shdP_Iin (Hdr := Hdr) Lq hL20 tag Rp embDigest embFold bInRow).pA.rows = 41 := by
  change (incLay (shdP_incPub Rp embDigest embFold) 14).aRows = 41
  exact (shdP_incLay_nums Rp embDigest embFold).1

theorem shdN_rX {St : Type} : (cbBndPcs (St := St) tag 38 0).rows = 38 := rfl

theorem shdN_sl : 3 ≤ (shdP_P0in tag Rp embDigest embFold bInRow).geom.slots.length := by
  rw [shdP_P0in_slots tag Rp embDigest embFold bInRow]
  decide

theorem shdN_d1 : 0 < (shdP_P0in tag Rp embDigest embFold bInRow).draws 1 := by
  show 0 < incDraws (shdP_incPub Rp embDigest embFold) 1
  show 0 < (shdP_incPub Rp embDigest embFold).tiLog + 4 + 1
  omega

theorem shdN_d2 : 0 < (shdP_P0in tag Rp embDigest embFold bInRow).draws 2 := by
  show 0 < incDraws (shdP_incPub Rp embDigest embFold) 2
  show 0 < (shdP_incPub Rp embDigest embFold).vocLog + 2 + 1
  omega

theorem shdN_P {Hdr : Type} (hd : Hdr) : ∀ ch, StgSame (shdP_P0in tag Rp embDigest embFold bInRow)
    ((shdP_incV tag Rp embDigest embFold bInRow).bp (incCtx (shdP_incV tag Rp embDigest embFold bInRow).pub ch)) :=
  fun _ => shdP_hPin tag Rp embDigest embFold bInRow hd _

end Num

section R0

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- **Part `0`'s first relation schedule of `shdRkD` is stage IN-C's define draws** (`shd_hb0`'s `hr0`). -/
theorem shdRkD_r0_zero
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
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).r0 0
      = stgDefsV P0in mIn (pf.off 0 + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (sshΦIC U hbij tag h64 P0in Vi (pf.off 0 + pin.pre) (pf.off 0 + 5) mIn
          ogStage.lc ogStage.h ogStage.Q ogStage.e Iin_rA Iin_rH csIOI) sshDgI := by
  rw [shdRkD_eq_ebData U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO]
  exact (shd_hb0 U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).hr0

/-- **Part `0`'s slots of `shdRkD` are stage IN-C's slot schedule** (`shd_hb0`'s `hsls`). -/
theorem shdRkD_sls_zero
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
      bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).sls 0
      = stgSchedV P0in mIn (pf.off 0 + 5) stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (stgFstIC U hbij tag h64 P0in (vdWin Vi) (pf.off 0 + pin.pre) (pf.off 0 + 5) mIn
          ogStage.lc ogStage.h ogStage.Q ogStage.e Iin_rA Iin_rH pin.S csIOI) := by
  rw [shdRkD_eq_ebData U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO]
  exact (shd_hb0 U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO).hsls

end R0

end ZK60.ProtocolClassify
