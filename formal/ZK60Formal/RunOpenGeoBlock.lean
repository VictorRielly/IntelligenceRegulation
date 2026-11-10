/-
D63 lane L48 (2026-11-10), part 7: **the edited theorems at the block geometry are the old ones** (the brief's
exception: "keeping every existing theorem's statement true at the block geometry (2^14)").

Part 1 made the message width a field (`RtOpen.lc`, `RkGeo.lc`). The theorems whose statements carried the literal
`14` now carry the geometry's `lc`; their old statements are their instances at `lc = 14`, with L28's `RW` for
`RWL 14` (`RWL_14`):

* **`rh_opB_alive_14`**: L43's `rh_opB_alive` in its old form (`hlc : prm.logCols = 14`, `ColEncSpec … RW …`,
  `PcsOk … rows 14 …`) at any geometry with `g.lc = 14`;
* **`rkData_opA_cl_14`**, **`rkData_opH_cl_14`**, **`rkData_opX_cl_14`**: L43's readers' claims in their old form
  (`oclOf … 14 …`, `groupZclaims … 14`) at parts whose geometry has `lc = 14`;
* **`rkR13_lc`**: R13's run geometry has `lc = 14`, so every block part built with `rkR13` (L43, L45) is such a part.

Every other theorem of the edited files kept its statement text (`RtOpen.opA_rbr`, `RtOpen.opB_rbr`, `rkOpen_valid`,
`rh_opB_of`, `rh_hal_opB`, `rh_blk_opA`, …), or kept its name and statement with its proof routed through the general
form (`rs_inc_opA`, `rs_inc_opH`, `rs_outc_opA`, `rs_outc_opH`, `rx_inc_opA`, `rx_inc_opH`, `rx_outc_opA`,
`rx_outc_opH`, `rx_parts_AH`, `rx_parts_M`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunHalOpB

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-- **R13's run geometry has the block width `2^14`.** -/
theorem rkR13_lc (rows ipos : ℕ) : (rkR13 rows ipos).lc = 14 := rfl

section OpB14

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

omit [Fintype K] [DecidableEq K] in
include hU in
/-- **L43's `rh_opB_alive` in its old form** (`log_cols 14`, L28's `RW`), at any geometry with `g.lc = 14`. -/
theorem rh_opB_alive_14 (W : UInt64 → ℕ) (g : RkGeo) (hg14 : g.lc = 14) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim)
    (aO aB vpos : ℕ) (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig))
    (tA tH : Tr) (zo : Block.OpeningZk) (c : ℕ) (rs : List Stp)
    (hpl : (τ.take aO).length = aO)
    (hdrop : τ.drop aO = opTrace (liftH G) tA (stpsOps (pcsStps (nC + g.rows) g.mI zo ++ rs)))
    (hpre : tRem W (τ.take aO) = some 0) (hctr : tA.counter = UInt64.ofNat c)
    (hst : StpOK W (UInt64.ofNat c) (pcsStps (nC + g.rows) g.mI zo ++ rs))
    (hvpos : vpos = aO + (nC + g.rows)) (haB : aB = aO + (nC + g.rows + zo.groupVecs.length))
    (prm : PcsPrm) (ev : Fp → List (List Fp2) → List Fp2) (hlc : prm.logCols = 14)
    (hqp : prm.qPad = g.Q) (hnQ : prm.nQ = g.Q) (hnn : prm.nn = 2 ^ g.h) (hpow : isPow2 prm.nn = true)
    (hQ0 : 0 < g.Q) (hm : (g.Q + 3) / 4 = g.mI)
    (hspec : ColEncSpec U (RW (K := K)) g.Q (cosetPt (rootFp g.h)) ev)
    (cl : List Block.ZClaim) (root : Dig)
    (hok : PcsOk (liftH G) tag prm (cosetPt (rootFp g.h)) ev root g.rows 14 (cl.map toZClaim) (toOZ zo) tA tH)
    (hcnt : cl.length = nC) (hrd : clr (τ.take aO) = cl) (hcan : Block.HidingCanon zo)
    (hcolX : ∀ (k : ℕ), k < g.Q → k < zo.columns.length →
      ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2.length = g.h →
      verifyPath (liftH G) tag root ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1
        (saltLeaf (liftH G) tag (colDigest (liftH G) tag ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1)
          ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.1) ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2
        = true →
      ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1.length = g.rows →
      (colX tag Lq h64 key domain hs hL g.h g.ipos P (τ.take aO)
        ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1).map Subtype.val
        = some ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1) :
    subSt W ((rkOpen U tag Lq h64 key domain hs hL g nC clr vpos).opB U hbij W aO aB P) τ := by
  have hspec' : ColEncSpec U (RWL (K := K) g.lc) g.Q (cosetPt (rootFp g.h)) ev := by
    rw [hg14, RWL_14]
    exact hspec
  have hok' : PcsOk (liftH G) tag prm (cosetPt (rootFp g.h)) ev root g.rows g.lc (cl.map toZClaim) (toOZ zo)
      tA tH := by
    rw [hg14]
    exact hok
  exact rh_opB_alive U hU hbij tag Lq h64 key domain hs hL W g nC clr aO aB vpos P G τ tA tH zo c rs hpl hdrop hpre hctr
    hst hvpos haB prm ev (hlc.trans hg14.symm) hqp hnQ hnn hpow hQ0 hm hspec' cl root hok' hcnt hrd hcan hcolX

end OpB14

section Data14

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (pf : RtProf) (ps : ℕ → RkPart K Lq) (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim)
  (eL : ℕ)

/-- The claims at width `2^l` are those at `2^14` when `l = 14` (heterogeneously: the types differ by the width). -/
theorem og_ocl_heq (rows l Q nC : ℕ) (cs : List ZClaim) (hl : l = 14) :
    HEq (oclOf U rows l Q nC (groupZclaims cs rows l)) (oclOf U rows 14 Q nC (groupZclaims cs rows 14)) := by
  subst hl
  rfl

/-- **L43's `rkData_opA_cl` in its old form** (`oclOf … 14 …`), at a part whose `A` geometry has `lc = 14`. -/
theorem rkData_opA_cl_14 (i : ℕ) (h14 : (ps i).gA.lc = 14) (hdr : List (TItem × Dig)) (a : Block.Acc)
    (h : acc i hdr = a) :
    HEq (((rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).opA i).cl hdr)
      (oclOf U (ps i).gA.rows 14 (ps i).gA.Q (ps i).nA (groupZclaims (a.claims.a.map toZClaim) (ps i).gA.rows 14)) :=
  HEq.trans (heq_of_eq (rkData_opA_cl U tag Lq h64 key domain hs hL pf ps acc lsc eL i hdr a h))
    (og_ocl_heq U _ _ _ _ _ h14)

/-- **L43's `rkData_opH_cl` in its old form**, at a part whose `H` geometry has `lc = 14`. -/
theorem rkData_opH_cl_14 (i : ℕ) (h14 : (ps i).gH.lc = 14) (hdr : List (TItem × Dig)) (a : Block.Acc)
    (h : acc i hdr = a) :
    HEq (((rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).opH i).cl hdr)
      (oclOf U (ps i).gH.rows 14 (ps i).gH.Q (ps i).nH
        (groupZclaims ((a.claims.h ++ [lsc i]).map toZClaim) (ps i).gH.rows 14)) :=
  HEq.trans (heq_of_eq (rkData_opH_cl U tag Lq h64 key domain hs hL pf ps acc lsc eL i hdr a h))
    (og_ocl_heq U _ _ _ _ _ h14)

/-- **L43's `rkData_opX_cl` in its old form**, at a part whose closing geometry has `lc = 14` (the blocks' boundaries;
part `0`'s, the input endpoint, has `lc = 8`). -/
theorem rkData_opX_cl_14 (i : ℕ) (h14 : (ps i).gX.lc = 14) (hdr : List (TItem × Dig)) (pend : List Block.ZClaim)
    (a : Block.Acc) (hp : rkPend acc i hdr = pend) (h : acc i hdr = a) :
    HEq (((rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).opX i).cl hdr)
      (oclOf U (ps i).gX.rows 14 (ps i).gX.Q (ps i).nX
        (groupZclaims ((pend ++ a.claims.inp).map toZClaim) (ps i).gX.rows 14)) :=
  HEq.trans (heq_of_eq (rkData_opX_cl U tag Lq h64 key domain hs hL pf ps acc lsc eL i hdr pend a hp h))
    (og_ocl_heq U _ _ _ _ _ h14)

end Data14

end ZK60.ProtocolClassify
