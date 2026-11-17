/-
D63 lane L63 (2026-11-17), part 44: **`hTrOIO` PROVED with `B_out`'s matrix pinned** (the handoff's plan item 3).

Stage OUT-C's IO semantics: `.inp` (`B_out`) on `bxUxV … Oout.pX.rows (off Lb + 2)`, the decoded matrix of part `Lb + 1`'s
closing opening (`rkOpen` at `rkR13 Oout.pX.rows (off Lb + 2)`, the opening `bndPlanes` reads for plane `Lb`); `.out` on a
free matrix `XE`.

* **`ssh_outc_out_nil`**: on an accepted run, stage OUT-C's code accumulator has NO `.out` claim: the stage verifier
  refuses one (`stage_out_c::verify`, StageVerifyExec.lean:372, "a claim on an output endpoint (there is none)"); the run's
  reader `rsAccS` at the slot phase's end is the accumulator the verifier checked (L45's `rs_accS_trace`, as in
  `rs_outc_run`, whose proof this copies, keeping the refusal it drops).
* **`ssh_trOIO_run`**: `StgClaimsIOCO` at the pinned `.inp` semantics, for every `XE`: the `.inp` claims are checked by part
  `Lb + 1`'s closing opening (L55's `cb_hopX1_last`, L46's `wr_ndA`, `wr_rkOpen_sem`); the `.out` half is vacuous.

Why `XE` stays free: the kinds data have no part after `Lb + 1` (the run has `Lb + 2` parts; `rtKA` ranges over them), so
no opening checks a claim on an output endpoint, and the code has no output endpoint to check: it refuses every such
claim. The `.out` half of `hTrOIO` therefore holds for every `XE` (PROVED), and `XE` is constrained by nothing.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldTrIIO

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

section Nil

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}

/-- **ON AN ACCEPTED RUN, STAGE OUT-C'S ACCUMULATOR HAS NO OUTPUT-ENDPOINT CLAIM**: the run's reader `rsAccS` at the slot
phase's end returns the accumulator the stage verifier checked, and the verifier refuses any `.out` claim. -/
theorem ssh_outc_out_nil (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (hσi : R.σs[i]? = some (rtOutcSeg outc outcG p))
    (hgeo : (outcG s.hdr).g = (outc s.hdr s.verdict).geom)
    (hgt : (outc s.hdr s.verdict).geom.slots.length = (outc s.hdr s.verdict).geom.terms.length)
    (hd : ∀ k, k < (outc s.hdr s.verdict).geom.slots.length →
      1 ≤ (Block.slotShape (outc s.hdr s.verdict).bp k).2.2) :
    (rsAccS (outc s.hdr s.verdict).bp 2 OutcV.bga (R.pf.off i + 2)
      ((R.tr G (s, segs)).take (R.pf.off i + p.pre))).claims.out = [] := by
  obtain ⟨cr, cr', t, t'', -, ht, hstep, hrdi⟩ := R.accept_part (liftH G) s segs hE i _ hσi
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  obtain ⟨seg, e, hdec, hver, -, -⟩ := (outSegExec_step_ok_iff outc outcG (liftH G) s _ _ cr t cr' t'').mp hstep
  obtain ⟨-, -, -, -, -, -, ch, recs, acc, t4, -, -, -, hs, -, -, hout, -⟩ :=
    (outcVerify_ok_iff (liftH G) (outc s.hdr s.verdict) cr.root cr.pending seg t t'').mp hver
  have hgt' : (outcG s.hdr).g.slots.length = (outcG s.hdr).g.terms.length := by
    rw [hgeo]
    exact hgt
  obtain ⟨hhdr, hshape0, -⟩ := rt_decodeStage_spec hgt' hdec
  obtain ⟨hcanC, -⟩ := rs_decodeStage_canon hgt' hdec
  have hshape : Block.CoreShape (outc s.hdr s.verdict).geom seg.core := by
    rw [hgeo] at hshape0
    exact hshape0
  have hof : rtStageOf (outcG s.hdr) (segs.getD i []) = some seg := rtStageOf_decode hhdr hdec
  have hrd : rtOutcRd outc outcG s (segs.getD i []) = rtOutcData (outc s.hdr s.verdict) seg := by
    simp only [rtOutcRd, hof]
  have hrdi' : (R.rd (s, segs)).2[i]? = some (rtOutcData (outc s.hdr s.verdict) seg) := by
    rw [hrdi]
    exact congrArg some hrd
  have hpi : R.pf.parts[i]? = some p := by
    show (R.σs.map (fun σ => σ.p))[i]? = some p
    rw [List.getElem?_map, hσi]
    rfl
  have hfr : (outc s.hdr s.verdict).frame (liftH G) t
      = runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
        ++ rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest) := by
    rw [runOps_append, ← ht]
    rfl
  rw [hfr] at hs
  have hpd : RtPartOk Lq p (rtOutcData (outc s.hdr s.verdict) seg) := rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi'
  obtain ⟨tk, -, -, -, -⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtOutcData (outc s.hdr s.verdict) seg) hpi hrdi' (opsStps (rtOutcData (outc s.hdr s.verdict) seg).pre) _ rfl
  rw [stpsOps_opsStps, hpd.1, stpsOps_append, stpsOps_opsStps] at tk
  have hlen : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hread := rs_accS_trace (liftH G) (outc s.hdr s.verdict).bp 2 OutcV.bga seg.core
    (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest)
    (Tr.newKeyed (liftH G) domain key) ch recs acc t4 hcanC.1 hshape.1 hd hs
  have hl2 : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest).length
        = R.pf.off i + 2 := by
    rw [List.length_append, hlen]
    rfl
  rw [hl2] at hread
  have hacc : rsAccS (outc s.hdr s.verdict).bp 2 OutcV.bga (R.pf.off i + 2)
      ((rtTr key domain Lq R.pf R.rd G (s, segs)).take (R.pf.off i + p.pre)) = acc := by
    rw [tk, ← hread]
    show rsAccS (outc s.hdr s.verdict).bp 2 OutcV.bga (R.pf.off i + 2)
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
          ++ (rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest
            ++ (StageFS.stageRootOps (outc s.hdr s.verdict).bp seg.core 2
              ++ Block.fullOps (outc s.hdr s.verdict).bp 0 seg.core.slots))))
      = _
    simp only [List.append_assoc]
  show (rsAccS (outc s.hdr s.verdict).bp 2 OutcV.bga (R.pf.off i + 2)
    ((rtTr key domain Lq R.pf R.rd G (s, segs)).take (R.pf.off i + p.pre))).claims.out = []
  rw [hacc]
  exact hout

end Nil

section Run

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (tag : MTag)
  {Hdr : Type} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (hL64 : Lq < 2 ^ 64)
  (Lb : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **`hTrOIO` ON AN ACCEPTED RUN** outside `EvXR` with no doomed `opA` entrant, `B_out`'s matrix pinned, any `XE`. -/
theorem ssh_trOIO_run
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (O : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (hOX : RkPcsR13 U tag O.pX) (hwXo : ∀ k, k + 1 = Lb → pout.wX = (bp k).nOut + O.nIn + O.pX.rows)
    (hfitXo : 8 * O.pX.rows ≤ Lq) (hLb1 : 0 < Lb) (hLb26 : Lb ≤ 26)
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV)
    (base : ℕ → RkPart K Lq) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH) (lsc : ℕ → Block.ZClaim) (eL : ℕ)
    (hgXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).gX = rkR13 O.pX.rows (R.pf.off (k + 1) + 2))
    (hnXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).nX = (bp k).nOut + O.nIn)
    (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn R.pf (rxPs base Lb din dblk dout)
      (rxAcc Win Wout Pk R.pf Lb) lsc eL)
    (n : ℕ) (hn : R.pf.parts.length ≤ n)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G)
      (A.run G).1 (A.run G).2 = .ok ())
    (hWout : Wout ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + pout.pre)) = outc (A.run G).1.hdr (A.run G).1.verdict)
    (hX : ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G
      ∨ exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G))
    (hA : ¬ (rtKA key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD).Dm n (A.runLog G).2 (R.tr G (A.run G)))
    (rE lcE Qe : ℕ) (XE : StgVw Lq → Fin rE → Fin (2 ^ lcE + Qe) → K) (lc h Q e rA rH iH : ℕ) :
    StgClaimsIOCO U key domain (outc (A.run G).1.hdr (A.run G).1.verdict).bp (R.pf.off (Lb + 1) + 2)
      (R.pf.off (Lb + 1) + pout.pre) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgCsv U tag h64 lc h Q e rA rH (R.pf.off (Lb + 1) + 2) iH
        (stgCsIOm U O.pX.rows 14 256 rE lcE Qe (bxUxV tag Lq h64 O.pX.rows (R.pf.off Lb + 2)) XE))
      G (A.runLog G).2 (R.tr G (A.run G)) := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hiL : Lb + 1 < R.pf.parts.length := by omega
  have hσo : R.σs[Lb + 1]? = some (rtOutcSeg outc outcG pout) := by
    rw [hσ]
    exact rx_getOut _ _ _ _
  have hσb : ∀ k, k < Lb → R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck
      bndOpen k (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows)
        (bp k).pH.m (wXk k) (gXk k) (mXk k))) := by
    intro k hk
    rw [hσ]
    exact rx_getBlk _ _ _ _ k hk
  have hpo : R.pf.part (Lb + 1) = pout := rx_part_of R (Lb + 1) _ hσo
  -- the acceptance facts of part `Lb + 1`'s closing opening (`B_out`)
  obtain ⟨wo⟩ := cb_hopX1_last U tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G
    (A.run G).1 (A.run G).2 hE Lb hLb1 hLb26 bp
    (fun k => rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows)
      (bp k).pH.m (wXk k) (gXk k) (mXk k))
    hσb (fun s k => hgeo k s) pout outc outcG O hσo Wout hWout hOX hwXo hfitXo base din dblk dout hgXo hnXo Win abRdIn
    incG A rfl (fun h' => hX (Or.inl h'))
  -- stage OUT-C's code accumulator has no `.out` claim
  have hnil := ssh_outc_out_nil R hv G (A.run G).1 (A.run G).2 hE (Lb + 1) pout outc outcG hσo (O.hgeo _ _)
    (O.hgt _ _) (fun k hk => (O.hgeomL _ _ k hk).1)
  -- no doomed `opA` entrant at the opening
  have ndAo := wr_ndA key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD n (A.runLog G).2 (R.tr G (A.run G)) hA
    (Lb + 1) hiL hn
  have ndo := ndAo _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self))
  subst hDe
  have hlen : ∀ (a : ℕ), ((R.tr G (A.run G)).take a).length = a → a ≤ (R.tr G (A.run G)).length := by
    intro a h'
    rw [List.length_take] at h'
    omega
  have so := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL (rxPs base Lb din dblk dout (Lb + 1)).gX
    (rxPs base Lb din dblk dout (Lb + 1)).nX
    (fun hdr => rkPend (rxAcc Win Wout Pk R.pf Lb) (Lb + 1) hdr ++ (rxAcc Win Wout Pk R.pf Lb (Lb + 1) hdr).claims.inp)
    _ (rtW R.pf.sqs) _ (A.runLog G).2 (R.tr G (A.run G)) ndo (hlen _ wo.hpl) wo.hpre
    (by have h' := wo.hcnt; rw [← wo.hrd] at h'; exact h')
  -- the opening's geometry
  have hgo' : (base (Lb + 1)).gX = rkR13 O.pX.rows (R.pf.off Lb + 2) := by
    obtain ⟨k, hk⟩ : ∃ k, k + 1 = Lb := ⟨Lb - 1, by omega⟩
    have h' := hgXo k hk
    rw [hk] at h'
    exact h'
  have hgo : (rxPs base Lb din dblk dout (Lb + 1)).gX = rkR13 O.pX.rows (R.pf.off Lb + 2) := by
    rw [rxPs_out]
    exact hgo'
  -- the windows
  have hoff : R.pf.off (Lb + 1) = R.pf.off Lb + (R.pf.part Lb).len := R.pf.off_succ Lb (by omega)
  have hleo : R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre ≤ R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oX := by
    simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hlto : R.pf.off Lb + 2 < R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oX := by
    rw [hoff]
    simp only [RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hlth : R.pf.off Lb + 2 < R.pf.off (Lb + 1) + 2 := by
    rw [hoff]
    simp only [RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  -- every reading, every slot window
  intro hdr core ch rs hrd k q hq
  have habs := (ssh_rd_absAt key domain _ 2 (R.pf.off (Lb + 1) + 2) _ G _ hdr core ch rs hrd (O.hgt _ _) k q hq
    (R.pf.off Lb + 2) hlth).trans (ssh_absAt_take (R.tr G (A.run G)) _ (R.pf.off Lb + 2) hlto).symm
  refine ⟨fun z hz => ?_, fun z hz => ?_⟩
  · -- `.inp` (`B_out`): checked by part `Lb + 1`'s closing opening
    have hz' : z ∈ rkPend (rxAcc Win Wout Pk R.pf Lb) (Lb + 1)
          ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oX))
        ++ (rxAcc Win Wout Pk R.pf Lb (Lb + 1)
          ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oX))).claims.inp := by
      apply List.mem_append_right
      rw [rxAcc_out]
      show z ∈ (rsAccS (Wout (((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oX)).take
          (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre))).bp 2 OutcV.bga (R.pf.off (Lb + 1) + 2)
        (((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oX)).take
          (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre))).claims.inp
      rw [List.take_take, min_eq_left hleo, hpo, hWout]
      exact hz
    have hv := so z hz'
    rw [wrOSem_rkR13 tag Lq h64 key domain hs hL U _ O.pX.rows (R.pf.off Lb + 2) hgo] at hv
    show claimSem U O.pX.rows 14 256 (bxUxV tag Lq h64 O.pX.rows (R.pf.off Lb + 2)
      (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 _)) z = _
    rw [bxUxV_view tag Lq h64 key domain hs hL, UxW_hdr (K := K) tag Lq h64 key domain hs hL 16 (R.pf.off Lb + 2)
      O.pX.rows (2 ^ 16) _ _ _ habs]
    exact hv
  · -- `.out`: the code's accumulator has none
    exfalso
    rw [hnil] at hz
    simp at hz

end Run

end ZK60.ProtocolClassify
