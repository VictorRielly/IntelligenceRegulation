/-
D63 lane L43 (2026-11-10), part 3: **`hal_opB` at the run's parse** (L39 §5 item 2; findings L39-3 and L34-1).

The first of the nine ordered cover premises: on an accepted run outside the extraction failure, the second half
(`opB`) of every regular opening of every part is alive at the end of the run's transcript. L28 proved it for a
block's `A` and `H` on the BLOCK's own chain (`opening_alt` with `pcs_subSt_of_acc`); L28's `OProf` does not reach the
closing opening `X` (finding L39-3). Here it is proved DIRECTLY at the run's wide parse `rtW pf.sqs`, for any opening
of any part (`A`, `H` and the closing `X`: the input endpoint, a boundary, `B_out`), so no carry from the block's parse
is needed:

* `rh_stpOK_vec`, **`rh_stpOK_pcs`**: the widths at an opening's two runs, read off the parse's `StpOK` at its window
  (what `rtTr_part` gives);
* **`rh_ctr_pcs`**: the counter after the batching run, the group vectors and `"pcs-prox"`;
* **`rh_opB_alive`**: an opening of `rkData` (`rkOpen`: claims read off the header, matrix extracted for the root at
  `ipos`) is alive at the end of ANY transcript that, from its window, runs the opening's steps on a transcript `tA`
  where the verifier's `PcsOk` holds (with the claims the reader returns, canonical vectors, and every opened column
  that verifies the extracted one): L28's `opening_alt` at the run's parse;
* `RhOpAcc`: those facts for one opening at its windows on the run's transcript (what an accepted part gives);
* **`rh_hal_opB`**: `hal_opB` in the top theorem's exact form (`(rtKB … D hD).Al n lg τ`) at `D := rkData …`, from
  `RhOpAcc` for the three openings of every part.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunKindsData

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## The widths and the counter at an opening -/

/-- The group vectors' absorbs pass the parse through. -/
theorem rh_stpOK_vec (W : UInt64 → ℕ) (c : UInt64) :
    ∀ (vs : List (List Fp2)) (X : List Stp), StpOK W c (vecStps vs ++ X) → StpOK W c X
  | [], _, h => h
  | _ :: vs, X, h => rh_stpOK_vec W c vs X h

/-- **The widths at an opening's two runs**: if the parse is the steps' from the opening's window on, its batching run
has width `w0 > 0` and its index run, after the group vectors and `"pcs-prox"`, width `m > 0`. -/
theorem rh_stpOK_pcs (W : UInt64 → ℕ) (c : UInt64) (w0 m : ℕ) (o : Block.OpeningZk) (rs : List Stp)
    (h : StpOK W c (pcsStps w0 m o ++ rs)) : W c = w0 ∧ 0 < w0 ∧ W (c + UInt64.ofNat w0) = m ∧ 0 < m := by
  have e : pcsStps w0 m o ++ rs = .sq w0 :: (vecStps o.groupVecs
      ++ (.ab Block.labPcsProx (o.proxVec.flatMap Fp2.toBytes) :: .sq m :: rs)) := by
    simp [pcsStps, pcsPre, List.append_assoc]
  rw [e] at h
  obtain ⟨h1, h2, h3⟩ := h
  have h4 := rh_stpOK_vec W _ o.groupVecs _ h3
  exact ⟨h1, h2, h4.1, h4.2.1⟩

/-- **The counter after the batching run, the group vectors and `"pcs-prox"`** is the window's plus `w0`. -/
theorem rh_ctr_pcs (H : HIn → Dig) (tA : Tr) (c w0 : ℕ) (o : Block.OpeningZk) (hc : tA.counter = UInt64.ofNat c) :
    ((runOps H (runOps H tA (List.replicate w0 Op.squeeze)) (stpsOps (vecStps o.groupVecs))).absorb H
      Block.labPcsProx (o.proxVec.flatMap Fp2.toBytes)).counter = UInt64.ofNat c + UInt64.ofNat w0 := by
  show (runOps H (runOps H tA (List.replicate w0 Op.squeeze)) (stpsOps (vecStps o.groupVecs))).counter = _
  have h1 := ctr_runOps H tA (List.replicate w0 Op.squeeze) c hc
  rw [sqN_replicate] at h1
  have h2 := ctr_runOps H _ (stpsOps (vecStps o.groupVecs)) (c + w0) h1
  rw [sqN_stpsOps, stpsSq_vecStps, Nat.add_zero] at h2
  rw [h2, u64_ofNat_add]

/-! ## `opB` alive at the run's parse -/

section OpB

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

omit [Fintype K] [DecidableEq K] in
include hU in
/-- **AN OPENING'S SECOND HALF IS ALIVE AT THE RUN'S PARSE** (L28's `opening_alt`, second branch, at the run). The
transcript `τ` from the opening's window `aO` on is the trace of the opening's steps (`nC + rows` batching squeezes,
the group vectors, `"pcs-prox"`, `mI` index squeezes) on the transcript `tA`, then anything; the parse `W` is a step's
end at the window and agrees with those steps from the window's counter; the verifier's `PcsOk` holds on `tA` at
parameters with `log_cols 14`, `Q` queries and pads, codeword length `2^h`, a column evaluator meeting `ColEncSpec`,
on the claims `cl` the opening's reader returns at its window; the vectors are canonical; and every opened column that
verifies against the root is the column extracted for the root the header absorbs at `ipos`. Then the opening's
`opB` (at its windows `aO` and `aB`, group vectors at `vpos`) is alive at the end of `τ`. -/
theorem rh_opB_alive (W : UInt64 → ℕ) (g : RkGeo) (nC : ℕ) (clr : List (TItem × Dig) → List Block.ZClaim)
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
  have hnC : nMem (groupZclaims (cl.map toZClaim) g.rows 14) = nC := by
    unfold nMem
    rw [groupZclaims_count, List.length_map, hcnt]
  have htP' : (absorbVecs (liftH G) (toOZ zo).groupVecs (zkRhosAux (liftH G) g.rows
      (groupZclaims (cl.map toZClaim) g.rows 14) tA).2.2).absorbFp2 (liftH G) pcsProxLabel (toOZ zo).proxVec = tP := by
    rw [htP, zkRhosAux_tr', hnC, runOps_vecStps]
    rfl
  -- the opening's checks, with the numbers named
  obtain ⟨hpath, h3, hgl, h4, -, hcl, hco⟩ := pcsOk_named (liftH G) tag prm _ _ root g.rows 14 _ (toOZ zo) tA tH hok
    g.Q (2 ^ g.h) g.mI hqp hnQ hnn (by rw [← hnn]; exact hpow) hQ0 hm
  rw [htP'] at hco
  have hJ : ∀ k : Fin g.Q,
      ((idxCode g.h g.hQm (vecOf dg0 g.mI ((sqDs (liftH G) tP g.mI).map halves)) k : Fin (2 ^ g.h)) : ℕ)
        = (idxOf prm.nn g.Q (sqDs (liftH G) ((absorbVecs (liftH G) (toOZ zo).groupVecs
          (zkRhosAux (liftH G) g.rows (groupZclaims (cl.map toZClaim) g.rows 14) tA).2.2).absorbFp2 (liftH G)
            pcsProxLabel (toOZ zo).proxVec) g.mI)).getD k 0 := by
    intro k
    rw [htP', hnn]
    exact idxCode_sqDs g.h g.hQm (sqDs (liftH G) tP g.mI) (sqDs_length _ _ _) k
  have hcols : ∀ (k : Fin g.Q) (r : Fin g.rows),
      UxW tag Lq h64 key domain hs hL g.h g.ipos g.rows P pre r
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
    show algebraMap GF K ((((colX tag Lq h64 key domain hs hL g.h g.ipos P pre
      (idxCode g.h g.hQm (vecOf dg0 g.mI ((sqDs (liftH G) tP g.mI).map halves)) k)).map Subtype.val).getD []).getD r
        Fp.zero).toGF = _
    rw [← hk1]
    exact congrArg (fun o : Option (List Fp) => algebraMap GF K ((o.getD []).getD r Fp.zero).toGF) hx
  have hGA := pcsOk_groupsAccept' U hU (liftH G) tag prm (cosetPt (rootFp g.h)) ev 14 g.Q (2 ^ g.h) g.rows g.mI hlc
    hqp hnQ hm hpow hQ0 RW hspec root (cl.map toZClaim) (toOZ zo) tA tH hok (ptsG g.h) (fun _ => rfl)
    (idxCode g.h g.hQm (vecOf dg0 g.mI ((sqDs (liftH G) tP g.mI).map halves))) hJ
    (UxW tag Lq h64 key domain hs hL g.h g.ipos g.rows P pre) hcols nC hnC
  have hlr := lrCode_sqDs U hbij nC g.rows (sqDs (liftH G) tA (nC + g.rows)) (sqDs_length _ _ _)
  have hdec := proxDec_enc U zo.proxVec hcan.2.1 (2 ^ 14 + g.Q) h4
  have hcl' : (rkOpen U tag Lq h64 key domain hs hL g nC clr vpos).cl pre
      = oclOf U g.rows 14 g.Q nC (groupZclaims (cl.map toZClaim) g.rows 14) := by
    show oclOf U g.rows 14 g.Q nC (groupZclaims ((clr pre).map toZClaim) g.rows 14) = _
    rw [hrd]
  have hv : ∀ gg ∈ Set.range (oclOf U g.rows 14 g.Q nC (groupZclaims (cl.map toZClaim) g.rows 14)).grp,
      (fun (gg : ℕ) (_ : Fin nC → K) (_ : Fin g.rows → K) => vecK U (2 ^ 14 + g.Q) ((toOZ zo).groupVecs.getD gg [])) gg
        = (fun (gg : ℕ) (_ : Fin nC → K) (_ : Fin g.rows → K) => vRd U (2 ^ 14 + g.Q) vpos
          (pre ++ opTrace (liftH G) tA (List.replicate (nC + g.rows) Op.squeeze ++ stpsOps (vecStps zo.groupVecs)))
            gg) gg := by
    rintro gg ⟨p, rfl⟩
    have hgp : (oclOf U g.rows 14 g.Q nC (groupZclaims (cl.map toZClaim) g.rows 14)).grp p < zo.groupVecs.length :=
      lt_of_lt_of_eq (oclOf_grp_lt' U g.rows 14 g.Q nC _ hnC p) h3.symm
    funext _ _
    have hvt := vRd_trace U (liftH G) pre [] tA (nC + g.rows) zo.groupVecs _ hgp
      (hcan.1 _ (mem_of_getD_lt _ _ hgp _)) (2 ^ 14 + g.Q) (hgl _ hgp)
    rw [List.append_nil, hpl, ← hvpos] at hvt
    exact hvt.symm
  have hacc := groupsAccept_congr_v _ _ _ _ _ _ _ _ _ _ _ _ hv hGA
  rw [← hcl'] at hacc
  have hacc' : GroupsAccept (encG (K := K) g.h g.Q) (UxW tag Lq h64 key domain hs hL g.h g.ipos g.rows P pre)
      ((rkOpen U tag Lq h64 key domain hs hL g nC clr vpos).cl pre).rw
      ((rkOpen U tag Lq h64 key domain hs hL g nC clr vpos).cl pre).cw
      ((rkOpen U tag Lq h64 key domain hs hL g nC clr vpos).cl pre).grp
      ((rkOpen U tag Lq h64 key domain hs hL g nC clr vpos).cl pre).val
      (fun gg _ _ => vRd U (2 ^ 14 + g.Q) vpos
        (pre ++ opTrace (liftH G) tA (List.replicate (nC + g.rows) Op.squeeze ++ stpsOps (vecStps zo.groupVecs))) gg)
      (fun _ _ => vecK U (2 ^ 14 + g.Q) zo.proxVec)
      (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + g.rows) ≃ Fin nC ⊕ Fin g.rows)
        (vecOf dg0 (nC + g.rows) ((sqDs (liftH G) tA (nC + g.rows)).map halves))).1
      (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + g.rows) ≃ Fin nC ⊕ Fin g.rows)
        (vecOf dg0 (nC + g.rows) ((sqDs (liftH G) tA (nC + g.rows)).map halves))).2
      (idxCode g.h g.hQm (vecOf dg0 g.mI ((sqDs (liftH G) tP g.mI).map halves))) := by
    rw [hlr]
    exact hacc
  obtain ⟨-, -, s3⟩ := pcs_subSt_of_acc (liftH G) W (nC + g.rows) g.mI hw0 hm0 zo tA hW1' hW2 pre rest hpre
    (encG (K := K) g.h g.Q) g.e (rkOpen U tag Lq h64 key domain hs hL g nC clr vpos).cl
    (UxW tag Lq h64 key domain hs hL g.h g.ipos g.rows P)
    (vRd U (2 ^ 14 + g.Q) vpos) dg0
    (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + g.rows) ≃ Fin nC ⊕ Fin g.rows))
    (idxCode g.h g.hQm) (proxDec U (2 ^ 14 + g.Q))
    ((((Fintype.card (Fin (2 ^ g.h)) - (g.e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ g.h))) ^ g.Q * 1)
    (vecK U (2 ^ 14 + g.Q) zo.proxVec) hdec hacc'
  rw [hpl, ← haB, ← hch] at s3
  exact s3

/-- **One opening's acceptance facts on the run's transcript** (the premises of `rh_opB_alive`, with their witnesses):
from its window `aO` the transcript runs the opening's steps on `tA`, the parse agrees, the verifier's `PcsOk` holds
on the claims the opening's reader returns, the vectors are canonical, and every opened column that verifies against
the root is the extracted one. -/
structure RhOpW (W : UInt64 → ℕ) (g : RkGeo) (nC : ℕ) (clr : List (TItem × Dig) → List Block.ZClaim)
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
  hlc : prm.logCols = 14
  hqp : prm.qPad = g.Q
  hnQ : prm.nQ = g.Q
  hnn : prm.nn = 2 ^ g.h
  hpow : isPow2 prm.nn = true
  hQ0 : 0 < g.Q
  hm : (g.Q + 3) / 4 = g.mI
  hspec : ColEncSpec U (RW (K := K)) g.Q (cosetPt (rootFp g.h)) ev
  hok : PcsOk (liftH G) tag prm (cosetPt (rootFp g.h)) ev root g.rows 14 (cl.map toZClaim) (toOZ zo) tA tH
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
    (colX tag Lq h64 key domain hs hL g.h g.ipos P (τ.take aO)
      ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1).map Subtype.val
      = some ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1

omit [Fintype K] [DecidableEq K] in
include hU in
/-- `rh_opB_alive` from the witnesses. -/
theorem rh_opB_of (W : UInt64 → ℕ) (g : RkGeo) (nC : ℕ) (clr : List (TItem × Dig) → List Block.ZClaim)
    (aO aB vpos : ℕ) (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig))
    (w : RhOpW U tag Lq h64 key domain hs hL W g nC clr aO aB vpos P G τ) :
    subSt W ((rkOpen U tag Lq h64 key domain hs hL g nC clr vpos).opB U hbij W aO aB P) τ :=
  rh_opB_alive U hU hbij tag Lq h64 key domain hs hL W g nC clr aO aB vpos P G τ w.tA w.tH w.zo w.c w.rs w.hpl
    w.hdrop w.hpre w.hctr w.hst w.hvpos w.haB w.prm w.ev w.hlc w.hqp w.hnQ w.hnn w.hpow w.hQ0 w.hm w.hspec w.cl
    w.root w.hok w.hcnt w.hrd w.hcan w.hcolX

end OpB

/-! ## `hal_opB` -/

section Hal

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
  (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **`opB`'s kind is alive** when, in every part of the run, the three openings' second halves are alive at their
windows (the parts past the profile's have none). -/
theorem rh_KB_al (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf) (n : ℕ)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length → ∀ x ∈ rtOps pf D i,
      subSt (rtW pf.sqs) (x.1.opB U hbij (rtW pf.sqs) x.2.1 x.2.2 lg) τ) :
    (rtKB key domain hs Lq hL pf rd hL64 hv U hbij D hD).Al n lg τ := by
  intro i _ k c hc
  by_cases hi : i < pf.parts.length
  · have hc' : ((rtOps pf D i).map (fun x => x.1.opB U hbij (rtW pf.sqs) x.2.1 x.2.2 lg))[k]? = some c := by
      simpa [rtKB, rtKind2, hi, RtKPart.ofOpB, RtKPart.ofMap] using hc
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp (List.mem_of_getElem? hc')
    exact h i hi x hx
  · simp [rtKB, rtKind2, hi, RtKPart.nil] at hc

variable (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ Lq)

include hU in
/-- **`hal_opB` AT THE KINDS DATA BUILT FROM THE VERIFIER'S READERS** (the first ordered cover premise, in the top
theorem's form `(rtKB … D hD).Al n lg τ`): if in every part of the run the three openings `A`, `H` and the closing
one meet their acceptance facts at their windows on the run's transcript (`RhOpW`: their `PcsOk` on the claims the
readers return, the extraction at their roots), every `opB` of every part is alive at the end. -/
theorem rh_hal_opB (ps : ℕ → RkPart K Lq) (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim)
    (eL : ℕ)
    (hD : (rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).Valid
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
        ∧ Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW pf.sqs) (ps i).gX (ps i).nX
          (fun hdr => rkPend acc i hdr ++ (acc i hdr).claims.inp)
          (pf.off i + (pf.part i).oX) (pf.off i + (pf.part i).oBX)
          (pf.off i + (pf.part i).oX + ((ps i).nX + (ps i).gX.rows)) lg G τ)) :
    (rtKB key domain hs Lq hL pf rd hL64 hv U hbij (rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL) hD).Al
      n lg τ := by
  refine rh_KB_al key domain hs Lq hL pf rd hL64 hv U hbij _ hD n lg τ (fun i hi x hx => ?_)
  obtain ⟨⟨wA⟩, ⟨wH⟩, ⟨wX⟩⟩ := h i hi
  simp only [rtOps, List.mem_cons, List.mem_nil_iff, or_false] at hx
  rcases hx with rfl | rfl | rfl
  · exact rh_opB_of U hU hbij tag Lq h64 key domain hs hL _ _ _ _ _ _ _ lg G τ wA
  · exact rh_opB_of U hU hbij tag Lq h64 key domain hs hL _ _ _ _ _ _ _ lg G τ wH
  · exact rh_opB_of U hU hbij tag Lq h64 key domain hs hL _ _ _ _ _ _ _ lg G τ wX

end Hal

end ZK60.ProtocolClassify
