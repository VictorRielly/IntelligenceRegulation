/-
D63 lane L52 (2026-11-10), part 1: **repair B's opening kind** (finding L51-1, repair B; L51 §5.2 items 1 to 3): an
opening of the run whose extracted matrix is read with L51's `colXM` (a root read OUT OF a longer absorbed message),
so that part `0`'s closing opening (the classifier's input token endpoint) can read the input root where the code's
header absorbs it: inside `expected-IO`, at transcript position `1` (L51's `ab_inAbs`).

* `ebUxW`, **`ebOpen`**: L43's `rkOpen` with the matrix `UxW` (L22's `colX`) replaced by the same matrix read with
  `colXM rd` (`rd` a reader of a root out of an absorbed message); **`ebOpen_cut`** (the matrix is a cut reader:
  L51's `colXM_cutEq`), **`ebOpen_valid`** (`RtOpen.Valid` when the geometry meets its conditions; at the endpoint
  geometry `ogEp` in `RunEpBInc.lean`);
* `RhOpWM`, **`eb_opB_alive`**, `eb_opB_of`: L43's `RhOpW` and `rh_opB_alive` for that opening (the acceptance facts
  with `hcolX` speaking of `colXM`; the proof is L43's with the matrix replaced: `pcs_subSt_of_acc` is generic in the
  matrix reader);
* `EbXW`: part `i`'s closing opening's acceptance facts under repair B: `RhOpWM` at part `0`, L43's `RhOpW` at the
  others;
* `ebOpX`, **`ebData`**: L43's `rkData` with part `0`'s closing opening of that kind (`ebOpen rd` at part `0`'s closing
  geometry), every other reader L43's; `ebData_opX_zero`, `ebData_opX_succ`, `ebData_same`, `ebData_opX_cl0`,
  `ebData_opX_cl_succ` (what the closing opening's claim reader returns), `ebData_opX_Ux`, **`ebData_valid`** (`hD` for `ebData` from the parts' numeric facts, as L43's
  `rkData_valid`);
* **`eb_hal_opB`**, **`eb_hal_M`**: `hal_opB` and `hal_M` in the top theorem's form at `D := ebData …` (L43's
  `rh_hal_opB`, `rh_hal_M` at `rkData`).

Nothing existing is changed: `rkOpen`, `rkData` and their lemmas stay as they are; this is a second kinds data beside
them. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunAbsX
import ZK60Formal.RunHalOpB
import ZK60Formal.RunHalM

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## The opening whose matrix is read under a reader -/

section Open

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **The matrix extracted for the root the header's message at `i` reads as under `rdx`** (L22's `UxW` with `colX`
replaced by L51's `colXM rdx`): row `r` at column `j`, depth `d`. -/
noncomputable def ebUxW (rdx : List UInt8 → Option Dig) (d i rows : ℕ) {N : ℕ} (log : List (QB Lq × Dig))
    (hdr : List (TItem × Dig)) : Fin rows → Fin N → K :=
  fun r j => algebraMap GF K ((((colXM tag Lq h64 key domain hs hL rdx d i log hdr j).map Subtype.val).getD []).getD r
    Fp.zero).toGF

/-- **AN OPENING OF THE RUN WHOSE MATRIX IS READ UNDER A READER** (repair B): L43's `rkOpen` (claims `oclOf` of the
claim list `clr` reads off the header, group vectors at `vpos`) with its matrix the one extracted for the root the
header's message at `g.ipos` reads as under `rdx`. -/
noncomputable def ebOpen (rdx : List UInt8 → Option Dig) (g : RkGeo) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim) (vpos : ℕ) : RtOpen K Lq where
  h := g.h
  lc := g.lc
  Q := g.Q
  e := g.e
  rows := g.rows
  nC := nC
  mI := g.mI
  hQm := g.hQm
  cl hdr := oclOf U g.rows g.lc g.Q nC (groupZclaims ((clr hdr).map toZClaim) g.rows g.lc)
  Ux P hdr := ebUxW tag Lq h64 key domain hs hL rdx g.h g.ipos g.rows P hdr
  vpos := vpos

/-- **Its matrix is a cut reader** (L51's `colXM_cutEq`, for every reader). -/
theorem ebOpen_cut (rdx : List UInt8 → Option Dig) (g : RkGeo) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim) (vpos : ℕ) :
    CutReads (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos).Ux := by
  intro P P' hdr h
  funext r j
  show ebUxW tag Lq h64 key domain hs hL rdx g.h g.ipos g.rows P hdr r j
    = ebUxW tag Lq h64 key domain hs hL rdx g.h g.ipos g.rows P' hdr r j
  unfold ebUxW
  rw [colXM_cutEq tag Lq h64 key domain hs hL rdx g.h g.ipos hdr P P' h]

/-- **It meets `RtOpen.Valid`** when its geometry meets the conditions and its batching run is at most `2^61` wide
(L43's `rkOpen_valid` with L51's cut reading). -/
theorem ebOpen_valid (rdx : List UInt8 → Option Dig) (g : RkGeo) (hg : g.Ok) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim) (vpos : ℕ) (hw : nC + g.rows ≤ 2 ^ 61) :
    (ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) :=
  ⟨hg.hh, hg.hQ0, hg.he, hw, hg.hεB, ebOpen_cut U tag Lq h64 key domain hs hL rdx g nC clr vpos⟩

end Open

/-! ## Its second half alive at the run's parse -/

section OpB

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

omit [Fintype K] [DecidableEq K] in
include hU in
/-- **REPAIR B'S OPENING: ITS SECOND HALF IS ALIVE AT THE RUN'S PARSE** (L43's `rh_opB_alive` for `ebOpen`): as there,
with every opened column that verifies against the root the column `colXM rdx` extracts for the root the header's
message at `g.ipos` reads as. -/
theorem eb_opB_alive (rdx : List UInt8 → Option Dig) (W : UInt64 → ℕ) (g : RkGeo) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim)
    (aO aB vpos : ℕ) (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig))
    (tA tH : Tr) (zo : Block.OpeningZk) (c : ℕ) (rs : List Stp)
    (hpl : (τ.take aO).length = aO)
    (hdrop : τ.drop aO = opTrace (liftH G) tA (stpsOps (pcsStps (nC + g.rows) g.mI zo ++ rs)))
    (hpre : tRem W (τ.take aO) = some 0) (hctr : tA.counter = UInt64.ofNat c)
    (hst : StpOK W (UInt64.ofNat c) (pcsStps (nC + g.rows) g.mI zo ++ rs))
    (hvpos : vpos = aO + (nC + g.rows)) (haB : aB = aO + (nC + g.rows + zo.groupVecs.length))
    (prm : PcsPrm) (ev : Fp → List (List Fp2) → List Fp2) (hlc : prm.logCols = g.lc)
    (hqp : prm.qPad = g.Q) (hnQ : prm.nQ = g.Q) (hnn : prm.nn = 2 ^ g.h) (hpow : isPow2 prm.nn = true)
    (hQ0 : 0 < g.Q) (hm : (g.Q + 3) / 4 = g.mI)
    (hspec : ColEncSpec U (RWL (K := K) g.lc) g.Q (cosetPt (rootFp g.h)) ev)
    (cl : List Block.ZClaim) (root : Dig)
    (hok : PcsOk (liftH G) tag prm (cosetPt (rootFp g.h)) ev root g.rows g.lc (cl.map toZClaim) (toOZ zo) tA tH)
    (hcnt : cl.length = nC) (hrd : clr (τ.take aO) = cl) (hcan : Block.HidingCanon zo)
    (hcolX : ∀ (k : ℕ), k < g.Q → k < zo.columns.length →
      ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2.length = g.h →
      verifyPath (liftH G) tag root ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1
        (saltLeaf (liftH G) tag (colDigest (liftH G) tag ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1)
          ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.1) ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2
        = true →
      ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1.length = g.rows →
      (colXM tag Lq h64 key domain hs hL rdx g.h g.ipos P (τ.take aO)
        ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1).map Subtype.val
        = some ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1) :
    subSt W ((ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos).opB U hbij W aO aB P) τ := by
  set pre := τ.take aO with hpreDef
  obtain ⟨hW1, hw0, hW2', hm0⟩ := rh_stpOK_pcs W _ _ _ zo rs hst
  have hW1' : W tA.counter = nC + g.rows := by rw [hctr]; exact hW1
  set tP := (runOps (liftH G) (runOps (liftH G) tA (List.replicate (nC + g.rows) Op.squeeze))
    (stpsOps (vecStps zo.groupVecs))).absorb (liftH G) Block.labPcsProx (zo.proxVec.flatMap Fp2.toBytes) with htP
  have hW2 : W tP.counter = g.mI := by
    rw [htP, rh_ctr_pcs (liftH G) tA c (nC + g.rows) zo hctr]
    exact hW2'
  set rest := opTrace (liftH G) (runOps (liftH G) tA (stpsOps (pcsStps (nC + g.rows) g.mI zo))) (stpsOps rs) with hrest
  have hch : τ = pre ++ opTrace (liftH G) tA (stpsOps (pcsStps (nC + g.rows) g.mI zo)) ++ rest := by
    conv_lhs => rw [← List.take_append_drop aO τ]
    rw [hdrop, stpsOps_append, Block.opTrace_append, List.append_assoc]
  have hnC : nMem (groupZclaims (cl.map toZClaim) g.rows g.lc) = nC := by
    unfold nMem
    rw [groupZclaims_count, List.length_map, hcnt]
  have htP' : (absorbVecs (liftH G) (toOZ zo).groupVecs (zkRhosAux (liftH G) g.rows
      (groupZclaims (cl.map toZClaim) g.rows g.lc) tA).2.2).absorbFp2 (liftH G) pcsProxLabel (toOZ zo).proxVec = tP := by
    rw [htP, zkRhosAux_tr', hnC, runOps_vecStps]
    rfl
  obtain ⟨hpath, h3, hgl, h4, -, hcl, hco⟩ := pcsOk_named (liftH G) tag prm _ _ root g.rows g.lc _ (toOZ zo) tA tH hok
    g.Q (2 ^ g.h) g.mI hqp hnQ hnn (by rw [← hnn]; exact hpow) hQ0 hm
  rw [htP'] at hco
  have hJ : ∀ k : Fin g.Q,
      ((idxCode g.h g.hQm (vecOf dg0 g.mI ((sqDs (liftH G) tP g.mI).map halves)) k : Fin (2 ^ g.h)) : ℕ)
        = (idxOf prm.nn g.Q (sqDs (liftH G) ((absorbVecs (liftH G) (toOZ zo).groupVecs
          (zkRhosAux (liftH G) g.rows (groupZclaims (cl.map toZClaim) g.rows g.lc) tA).2.2).absorbFp2 (liftH G)
            pcsProxLabel (toOZ zo).proxVec) g.mI)).getD k 0 := by
    intro k
    rw [htP', hnn]
    exact idxCode_sqDs g.h g.hQm (sqDs (liftH G) tP g.mI) (sqDs_length _ _ _) k
  have hcols : ∀ (k : Fin g.Q) (r : Fin g.rows),
      ebUxW tag Lq h64 key domain hs hL rdx g.h g.ipos g.rows P pre r
          (idxCode g.h g.hQm (vecOf dg0 g.mI ((sqDs (liftH G) tP g.mI).map halves)) k)
        = algebraMap GF K ((((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1).getD r Fp.zero).toGF := by
    intro k r
    have hkl : (k : ℕ) < (toOZ zo).columns.length := by rw [hcl]; exact k.isLt
    have hkl' : (k : ℕ) < zo.columns.length := by
      have e : (toOZ zo).columns.length = zo.columns.length := List.length_map _
      rw [← e]; exact hkl
    have hc := hco k k.isLt
    have hk1 : ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1
        = ((idxCode g.h g.hQm (vecOf dg0 g.mI ((sqDs (liftH G) tP g.mI).map halves)) k : Fin (2 ^ g.h)) : ℕ) := by
      rw [hc.1]
      exact (idxCode_sqDs g.h g.hQm (sqDs (liftH G) tP g.mI) (sqDs_length _ _ _) k).symm
    have hp : ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2.length = g.h := by
      rw [hpath _ (mem_of_getD_lt _ _ hkl _), Nat.log2_two_pow]
    have hx := hcolX k k.isLt hkl' hp hc.2.2.1 hc.2.1
    show algebraMap GF K ((((colXM tag Lq h64 key domain hs hL rdx g.h g.ipos P pre
      (idxCode g.h g.hQm (vecOf dg0 g.mI ((sqDs (liftH G) tP g.mI).map halves)) k)).map Subtype.val).getD []).getD r
        Fp.zero).toGF = _
    rw [← hk1]
    exact congrArg (fun o : Option (List Fp) => algebraMap GF K ((o.getD []).getD r Fp.zero).toGF) hx
  have hGA := pcsOk_groupsAccept' U hU (liftH G) tag prm (cosetPt (rootFp g.h)) ev g.lc g.Q (2 ^ g.h) g.rows g.mI hlc
    hqp hnQ hm hpow hQ0 (RWL g.lc) hspec root (cl.map toZClaim) (toOZ zo) tA tH hok (ptsG g.h) (fun _ => rfl)
    (idxCode g.h g.hQm (vecOf dg0 g.mI ((sqDs (liftH G) tP g.mI).map halves))) hJ
    (ebUxW tag Lq h64 key domain hs hL rdx g.h g.ipos g.rows P pre) hcols nC hnC
  have hlr := lrCode_sqDs U hbij nC g.rows (sqDs (liftH G) tA (nC + g.rows)) (sqDs_length _ _ _)
  have hdec := proxDec_enc U zo.proxVec hcan.2.1 (2 ^ g.lc + g.Q) h4
  have hcl' : (ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos).cl pre
      = oclOf U g.rows g.lc g.Q nC (groupZclaims (cl.map toZClaim) g.rows g.lc) := by
    show oclOf U g.rows g.lc g.Q nC (groupZclaims ((clr pre).map toZClaim) g.rows g.lc) = _
    rw [hrd]
  have hv : ∀ gg ∈ Set.range (oclOf U g.rows g.lc g.Q nC (groupZclaims (cl.map toZClaim) g.rows g.lc)).grp,
      (fun (gg : ℕ) (_ : Fin nC → K) (_ : Fin g.rows → K) => vecK U (2 ^ g.lc + g.Q) ((toOZ zo).groupVecs.getD gg [])) gg
        = (fun (gg : ℕ) (_ : Fin nC → K) (_ : Fin g.rows → K) => vRd U (2 ^ g.lc + g.Q) vpos
          (pre ++ opTrace (liftH G) tA (List.replicate (nC + g.rows) Op.squeeze ++ stpsOps (vecStps zo.groupVecs)))
            gg) gg := by
    rintro gg ⟨p, rfl⟩
    have hgp : (oclOf U g.rows g.lc g.Q nC (groupZclaims (cl.map toZClaim) g.rows g.lc)).grp p < zo.groupVecs.length :=
      lt_of_lt_of_eq (oclOf_grp_lt' U g.rows g.lc g.Q nC _ hnC p) h3.symm
    funext _ _
    have hvt := vRd_trace U (liftH G) pre [] tA (nC + g.rows) zo.groupVecs _ hgp
      (hcan.1 _ (mem_of_getD_lt _ _ hgp _)) (2 ^ g.lc + g.Q) (hgl _ hgp)
    rw [List.append_nil, hpl, ← hvpos] at hvt
    exact hvt.symm
  have hacc := groupsAccept_congr_v _ _ _ _ _ _ _ _ _ _ _ _ hv hGA
  rw [← hcl'] at hacc
  have hacc' : GroupsAccept (encGL (K := K) g.lc g.h g.Q)
      (ebUxW tag Lq h64 key domain hs hL rdx g.h g.ipos g.rows P pre)
      ((ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos).cl pre).rw
      ((ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos).cl pre).cw
      ((ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos).cl pre).grp
      ((ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos).cl pre).val
      (fun gg _ _ => vRd U (2 ^ g.lc + g.Q) vpos
        (pre ++ opTrace (liftH G) tA (List.replicate (nC + g.rows) Op.squeeze ++ stpsOps (vecStps zo.groupVecs))) gg)
      (fun _ _ => vecK U (2 ^ g.lc + g.Q) zo.proxVec)
      (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + g.rows) ≃ Fin nC ⊕ Fin g.rows)
        (vecOf dg0 (nC + g.rows) ((sqDs (liftH G) tA (nC + g.rows)).map halves))).1
      (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + g.rows) ≃ Fin nC ⊕ Fin g.rows)
        (vecOf dg0 (nC + g.rows) ((sqDs (liftH G) tA (nC + g.rows)).map halves))).2
      (idxCode g.h g.hQm (vecOf dg0 g.mI ((sqDs (liftH G) tP g.mI).map halves))) := by
    rw [hlr]
    exact hacc
  obtain ⟨-, -, s3⟩ := pcs_subSt_of_acc (liftH G) W (nC + g.rows) g.mI hw0 hm0 zo tA hW1' hW2 pre rest hpre
    (encGL (K := K) g.lc g.h g.Q) g.e (ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos).cl
    (ebUxW tag Lq h64 key domain hs hL rdx g.h g.ipos g.rows P)
    (vRd U (2 ^ g.lc + g.Q) vpos) dg0
    (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + g.rows) ≃ Fin nC ⊕ Fin g.rows))
    (idxCode g.h g.hQm) (proxDec U (2 ^ g.lc + g.Q))
    ((((Fintype.card (Fin (2 ^ g.h)) - (g.e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ g.h))) ^ g.Q * 1)
    (vecK U (2 ^ g.lc + g.Q) zo.proxVec) hdec hacc'
  rw [hpl, ← haB, ← hch] at s3
  exact s3

/-- **Repair B's opening's acceptance facts on the run's transcript** (L43's `RhOpW` with `hcolX` speaking of
`colXM rdx`): from its window `aO` the transcript runs the opening's steps on `tA`, the parse agrees, the verifier's
`PcsOk` holds on the claims the opening's reader returns, the vectors are canonical, and every opened column that
verifies against the root is the column `colXM rdx` extracts. -/
structure RhOpWM (rdx : List UInt8 → Option Dig) (W : UInt64 → ℕ) (g : RkGeo) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim)
    (aO aB vpos : ℕ) (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig)) where
  tA : Tr
  tH : Tr
  zo : Block.OpeningZk
  c : ℕ
  rs : List Stp
  prm : PcsPrm
  ev : Fp → List (List Fp2) → List Fp2
  cl : List Block.ZClaim
  root : Dig
  hpl : (τ.take aO).length = aO
  hdrop : τ.drop aO = opTrace (liftH G) tA (stpsOps (pcsStps (nC + g.rows) g.mI zo ++ rs))
  hpre : tRem W (τ.take aO) = some 0
  hctr : tA.counter = UInt64.ofNat c
  hst : StpOK W (UInt64.ofNat c) (pcsStps (nC + g.rows) g.mI zo ++ rs)
  hvpos : vpos = aO + (nC + g.rows)
  haB : aB = aO + (nC + g.rows + zo.groupVecs.length)
  hlc : prm.logCols = g.lc
  hqp : prm.qPad = g.Q
  hnQ : prm.nQ = g.Q
  hnn : prm.nn = 2 ^ g.h
  hpow : isPow2 prm.nn = true
  hQ0 : 0 < g.Q
  hm : (g.Q + 3) / 4 = g.mI
  hspec : ColEncSpec U (RWL (K := K) g.lc) g.Q (cosetPt (rootFp g.h)) ev
  hok : PcsOk (liftH G) tag prm (cosetPt (rootFp g.h)) ev root g.rows g.lc (cl.map toZClaim) (toOZ zo) tA tH
  hcnt : cl.length = nC
  hrd : clr (τ.take aO) = cl
  hcan : Block.HidingCanon zo
  hcolX : ∀ (k : ℕ), k < g.Q → k < zo.columns.length →
    ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2.length = g.h →
    verifyPath (liftH G) tag root ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1
      (saltLeaf (liftH G) tag (colDigest (liftH G) tag ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1)
        ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.1) ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2
      = true →
    ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1.length = g.rows →
    (colXM tag Lq h64 key domain hs hL rdx g.h g.ipos P (τ.take aO)
      ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1).map Subtype.val
      = some ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1

omit [Fintype K] [DecidableEq K] in
include hU in
/-- `eb_opB_alive` from the witnesses. -/
theorem eb_opB_of (rdx : List UInt8 → Option Dig) (W : UInt64 → ℕ) (g : RkGeo) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim)
    (aO aB vpos : ℕ) (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig))
    (w : RhOpWM U tag Lq h64 key domain hs hL rdx W g nC clr aO aB vpos P G τ) :
    subSt W ((ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos).opB U hbij W aO aB P) τ :=
  eb_opB_alive U hU hbij tag Lq h64 key domain hs hL rdx W g nC clr aO aB vpos P G τ w.tA w.tH w.zo w.c w.rs w.hpl
    w.hdrop w.hpre w.hctr w.hst w.hvpos w.haB w.prm w.ev w.hlc w.hqp w.hnQ w.hnn w.hpow w.hQ0 w.hm w.hspec w.cl
    w.root w.hok w.hcnt w.hrd w.hcan w.hcolX

/-- **Part `i`'s closing opening's acceptance facts under repair B**: `RhOpWM` (the matrix read under `rdx`) at part
`0`, L43's `RhOpW` at every other part. -/
def EbXW (rdx : List UInt8 → Option Dig) (i : ℕ) (W : UInt64 → ℕ) (g : RkGeo) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim)
    (aO aB vpos : ℕ) (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig)) : Prop :=
  match i with
  | 0 => Nonempty (RhOpWM U tag Lq h64 key domain hs hL rdx W g nC clr aO aB vpos P G τ)
  | _ + 1 => Nonempty (RhOpW U tag Lq h64 key domain hs hL W g nC clr aO aB vpos P G τ)

end OpB

/-! ## The kinds data with part `0`'s closing opening of that kind -/

section Data

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **The closing openings under repair B**: part `0`'s is `ebOpen rdx` at part `0`'s closing geometry (its claims
L43's: nothing pending, then `claims.inp`), every other part's L43's `rkData` closing opening. -/
noncomputable def ebOpX (rdx : List UInt8 → Option Dig) (pf : RtProf) (ps : ℕ → RkPart K Lq)
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL : ℕ) : ℕ → RtOpen K Lq
  | 0 => ebOpen U tag Lq h64 key domain hs hL rdx (ps 0).gX (ps 0).nX
      (fun hdr => rkPend acc 0 hdr ++ (acc 0 hdr).claims.inp)
      (pf.off 0 + (pf.part 0).oX + ((ps 0).nX + (ps 0).gX.rows))
  | i + 1 => (rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).opX (i + 1)

/-- **THE RUN'S KINDS DATA UNDER REPAIR B**: L43's `rkData` with part `0`'s closing opening read under `rdx` (at the
code's header: `abRdIn`, the input root out of `expected-IO`, at position `1`). -/
noncomputable def ebData (rdx : List UInt8 → Option Dig) (pf : RtProf) (ps : ℕ → RkPart K Lq)
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL : ℕ) : RtKData K Lq :=
  { rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL with
    opX := ebOpX U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL }

variable (rdx : List UInt8 → Option Dig) (pf : RtProf) (ps : ℕ → RkPart K Lq)
  (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL : ℕ)

/-- Part `0`'s closing opening is repair B's. -/
theorem ebData_opX_zero : (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX 0
    = ebOpen U tag Lq h64 key domain hs hL rdx (ps 0).gX (ps 0).nX
      (fun hdr => rkPend acc 0 hdr ++ (acc 0 hdr).claims.inp)
      (pf.off 0 + (pf.part 0).oX + ((ps 0).nX + (ps 0).gX.rows)) := rfl

/-- Every other part's closing opening is L43's. -/
theorem ebData_opX_succ (i : ℕ) : (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX (i + 1)
    = (rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).opX (i + 1) := rfl

/-- Every other reader is L43's: `M`, `A`, `H`, the slots and the squeeze runs. -/
theorem ebData_same :
    (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).msk = (rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).msk
      ∧ (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opA
        = (rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).opA
      ∧ (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opH
        = (rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).opH
      ∧ (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).sls
        = (rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).sls :=
  ⟨rfl, rfl, rfl, rfl⟩

/-- **Part `0`'s closing commitment's claims** (L43's `rkData_opX_cl` at part `0`): nothing pending, then the part's
incoming claims. -/
theorem ebData_opX_cl0 (hdr : List (TItem × Dig)) (pend : List Block.ZClaim) (a : Block.Acc)
    (hp : rkPend acc 0 hdr = pend) (h : acc 0 hdr = a) :
    ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX 0).cl hdr
      = oclOf U (ps 0).gX.rows (ps 0).gX.lc (ps 0).gX.Q (ps 0).nX
          (groupZclaims ((pend ++ a.claims.inp).map toZClaim) (ps 0).gX.rows (ps 0).gX.lc) := by
  show oclOf U (ps 0).gX.rows (ps 0).gX.lc (ps 0).gX.Q (ps 0).nX
      (groupZclaims ((rkPend acc 0 hdr ++ (acc 0 hdr).claims.inp).map toZClaim) (ps 0).gX.rows (ps 0).gX.lc) = _
  rw [hp, h]

/-- **Every other part's closing commitment's claims** (L43's `rkData_opX_cl`): the previous part's outgoing claims,
then the part's incoming ones. -/
theorem ebData_opX_cl_succ (i : ℕ) (hdr : List (TItem × Dig)) (pend : List Block.ZClaim) (a : Block.Acc)
    (hp : rkPend acc (i + 1) hdr = pend) (h : acc (i + 1) hdr = a) :
    ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX (i + 1)).cl hdr
      = oclOf U (ps (i + 1)).gX.rows (ps (i + 1)).gX.lc (ps (i + 1)).gX.Q (ps (i + 1)).nX
          (groupZclaims ((pend ++ a.claims.inp).map toZClaim) (ps (i + 1)).gX.rows (ps (i + 1)).gX.lc) :=
  rkData_opX_cl U tag Lq h64 key domain hs hL pf ps acc lsc eL (i + 1) hdr pend a hp h

/-- **Part `0`'s closing opening's matrix is the one `colXM rdx` extracts** at part `0`'s closing geometry. -/
theorem ebData_opX_Ux (P : List (QB Lq × Dig)) (hdr : List (TItem × Dig)) :
    ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX 0).Ux P hdr
      = ebUxW tag Lq h64 key domain hs hL rdx (ps 0).gX.h (ps 0).gX.ipos (ps 0).gX.rows P hdr := rfl

end Data

section Valid

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
  (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

omit [DecidableEq K] in
/-- **`hD` FOR THE KINDS DATA UNDER REPAIR B** (L43's `rkData_valid`): on a valid profile, with `K` of `p²` elements,
every part meeting its numeric facts and LogUp's escape count at most `2^26`, `ebData …` meets `RtKData.Valid`. Part
`0`'s closing opening's cut reading is L51's (`colXM_cutEq`, through `ebOpen_cut`). -/
theorem ebData_valid (rdx : List UInt8 → Option Dig) (pf : RtProf) (hv : pf.Valid) (ps : ℕ → RkPart K Lq)
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL : ℕ) (hK : Fintype.card K = gP ^ 2)
    (hp : ∀ i, i < pf.parts.length → (ps i).Ok (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf eL i)
    (heL : eL ≤ 2 ^ 26) :
    (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf := by
  have h0 := rkData_valid U tag Lq h64 key domain hs hL pf hv ps acc lsc eL hK hp heL
  exact
    { hK := h0.hK
      slCut := h0.slCut
      slDeg := h0.slDeg
      slWin := h0.slWin
      mK := h0.mK
      mCut := h0.mCut
      mS := h0.mS
      opV := fun i hi => by
        rcases i with _ | i
        · refine ⟨(h0.opV 0 hi).1, (h0.opV 0 hi).2.1, ?_⟩
          have hw := (rk_w_le pf hv 0 hi).2.2
          rw [← (hp 0 hi).wX.1] at hw
          exact ebOpen_valid U tag Lq h64 key domain hs hL rdx _ (hp 0 hi).gX _ _ _ hw
        · exact h0.opV (i + 1) hi
      opW := fun i hi => by
        rcases i with _ | i
        · exact h0.opW 0 hi
        · exact h0.opW (i + 1) hi
      r0 := h0.r0
      r1 := h0.r1
      h0 := h0.h0
      h1 := h0.h1
      lu := h0.lu
      heL := h0.heL }

end Valid

/-! ## `hal_opB` and `hal_M` at the kinds data under repair B -/

section Hal

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
  (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ Lq)

include hU in
/-- **`hal_opB` AT THE KINDS DATA UNDER REPAIR B** (L43's `rh_hal_opB` at `ebData`): if in every part the openings `A`
and `H` meet `RhOpW` and the closing one meets `EbXW` (`RhOpWM` at part `0`, `RhOpW` elsewhere) at their windows on
the run's transcript, every `opB` of every part is alive at the end. -/
theorem eb_hal_opB (rdx : List UInt8 → Option Dig) (ps : ℕ → RkPart K Lq)
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL : ℕ)
    (hD : (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)
    (n : ℕ) (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length →
      Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW pf.sqs) (ps i).gA (ps i).nA (fun hdr => (acc i hdr).claims.a)
          (pf.off i + (pf.part i).oA) (pf.off i + (pf.part i).oBA)
          (pf.off i + (pf.part i).oA + ((ps i).nA + (ps i).gA.rows)) lg G τ)
        ∧ Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW pf.sqs) (ps i).gH (ps i).nH
          (fun hdr => (acc i hdr).claims.h ++ [lsc i])
          (pf.off i + (pf.part i).oH) (pf.off i + (pf.part i).oBH)
          (pf.off i + (pf.part i).oH + ((ps i).nH + (ps i).gH.rows)) lg G τ)
        ∧ (EbXW U tag Lq h64 key domain hs hL rdx i (rtW pf.sqs) (ps i).gX (ps i).nX
          (fun hdr => rkPend acc i hdr ++ (acc i hdr).claims.inp)
          (pf.off i + (pf.part i).oX) (pf.off i + (pf.part i).oBX)
          (pf.off i + (pf.part i).oX + ((ps i).nX + (ps i).gX.rows)) lg G τ)) :
    (rtKB key domain hs Lq hL pf rd hL64 hv U hbij (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL) hD).Al
      n lg τ := by
  refine rh_KB_al key domain hs Lq hL pf rd hL64 hv U hbij _ hD n lg τ (fun i hi x hx => ?_)
  obtain ⟨⟨wA⟩, ⟨wH⟩, hX⟩ := h i hi
  simp only [rtOps, List.mem_cons, List.mem_nil_iff, or_false] at hx
  rcases hx with rfl | rfl | rfl
  · exact rh_opB_of U hU hbij tag Lq h64 key domain hs hL _ _ _ _ _ _ _ lg G τ wA
  · exact rh_opB_of U hU hbij tag Lq h64 key domain hs hL _ _ _ _ _ _ _ lg G τ wH
  · rcases i with _ | i
    · obtain ⟨wX⟩ := hX
      exact eb_opB_of U hU hbij tag Lq h64 key domain hs hL rdx _ _ _ _ _ _ _ lg G τ wX
    · obtain ⟨wX⟩ := hX
      exact rh_opB_of U hU hbij tag Lq h64 key domain hs hL _ _ _ _ _ _ _ lg G τ wX

include hU in
/-- **`hal_M` AT THE KINDS DATA UNDER REPAIR B** (L43's `rh_hal_M`: `M`'s readers are L43's). -/
theorem eb_hal_M (rdx : List UInt8 → Option Dig) (ps : ℕ → RkPart K Lq)
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL : ℕ)
    (hD : (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)
    (n : ℕ) (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length →
      Nonempty (RhMW tag Lq h64 key domain hs hL (rtW pf.sqs) (ps i).S (ps i).k (ps i).mpos
        (fun hdr => (acc i hdr).fs ++ (acc i hdr).hostFs) (pf.off i + (pf.part i).pre) lg G τ)) :
    (rtKM key domain hs Lq hL pf rd hL64 hv U hbij (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL) hD).Al
      n lg τ := by
  refine rh_KM_al key domain hs Lq hL pf rd hL64 hv U hbij _ hD n lg τ (fun i hi => ?_)
  obtain ⟨w⟩ := h i hi
  exact rh_M_of U hU hbij tag Lq h64 key domain hs hL _ _ _ _ _ _ lg G τ w

end Hal

end ZK60.ProtocolClassify
