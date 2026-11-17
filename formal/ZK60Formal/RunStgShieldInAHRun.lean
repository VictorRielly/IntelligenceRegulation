/-
D63 lane L63 (2026-11-16), part 13: **stage IN-C's `A`/`H` claims part on an accepted run** (`ssh_AHAtI`; item (iv),
step A). Written by `results/zk60_lean_l63_20261116/l63_mk_inahrun.py` (the run lemma reuses `ssh_run_AHO`'s binders
and proof at part `0`).

* `ssh_inc_link_ah`: at every reading, the run's IN-C reader (`rsAccInc`, the CODE's accumulator) at the slot phase's end
  has the reading's (L15's model's) `A` and `H` claims (`ssh_inc_claims_ah`);
* `ssh_run_AHI`: on an accepted run outside `EvXR` with no doomed `opA` entrant, every `A` and `H` claim stage IN-C's reader
  returns at its opening window is true of the decoded extracted matrix;
* **`ssh_AHAtI`**: `StgClaimsAH` at stage IN-C on such a run.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldInAH

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx incCtx)
open ZK60.Circuit (gP GF)

section Link

variable {L : ℕ}

/-- **Stage IN-C: the run's (code's) accumulator reader at the slot phase's end has the reading's `A` and `H` claims.** -/
theorem ssh_inc_link_ah (key : Option Dig) (domain : List UInt8) (V : IncV) (m hdrLen e : ℕ)
    (hm : incHeadDraws V.pub = m) (G : QB L → Dig) (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core)
    (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain L (fun ch => V.bp (incCtx V.pub ch)) m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G
      τ hdr core ch rs)
    (hgt : V.geom.slots.length = V.geom.terms.length)
    (hd : ∀ cx k, k < V.geom.slots.length → 1 ≤ (Block.slotShape (V.bp cx) k).2.2)
    (he : ∀ cx, e = hdrLen + (7 + m) + shapeLen (V.bp cx) 0 V.geom.slots)
    (acc : Block.Acc) (t' : Tr)
    (hacc : StageFS.stageSlots (liftH G) (V.bp (incCtx V.pub ch)) m (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) core
      (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t')) :
    (rsAccInc V hdrLen (τ.take e)).claims.a = acc.claims.a ∧ (rsAccInc V hdrLen (τ.take e)).claims.h = acc.claims.h := by
  subst hm
  have htk := ssh_stage_take key domain (fun ch => V.bp (incCtx V.pub ch)) (incHeadDraws V.pub) hdrLen _ G τ hdr core
    ch rs hrd hgt
  obtain ⟨hhl, -, hcan, hsh, -, -⟩ := hrd
  have htk' : τ.take e = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
      (hdr ++ StageFS.stageRootOps (V.bp (incCtx V.pub ch)) core (incHeadDraws V.pub)
        ++ Block.fullOps (V.bp (incCtx V.pub ch)) 0 core.slots) := by
    rw [he (incCtx V.pub ch)]
    exact htk
  rw [htk']
  have hch : (V.headCh (liftH G) core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)).1 = ch := by
    have h := hacc
    unfold StageFS.stageSlots at h
    dsimp only at h
    split at h
    · simp only [Except.ok.injEq, Prod.mk.injEq] at h
      exact h.1
    · cases h
  subst hch
  have hm2 := StageV.incSlots_model (liftH G) V core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)
  rw [hacc] at hm2
  obtain ⟨⟨recs, accr, t4⟩, hs, -⟩ := (StageV.map_ok_iff _ _ _).mp hm2
  have hr := ZK60.ProtocolClassify.rs_accInc_trace (liftH G) V core hdr (Tr.newKeyed (liftH G) domain key) recs accr
    t4 (incCtx V.pub (V.headCh (liftH G) core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)).1) hcan.1
    hsh.1 hd hs
  rw [hhl] at hr
  rw [hr]
  exact StageV.ssh_inc_claims_ah (liftH G) V core _ recs accr t4 hs rs acc t' hacc

end Link

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

/-- **STAGE IN-C'S `A`/`H` CLAIMS ARE TRUE OF THE RUN'S EXTRACTED MATRICES** at their opening windows, on an accepted run
outside `EvXR` with no doomed `opA` entrant. -/
theorem ssh_run_AHI
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (I : RtInc Lq inc incG pin) (O : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hLb : Lb ≤ 26) (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (gS : OGeo) (hgS : gS.Ok) (hgSQ : gS.Q ≤ 256)
    (hIA : RkPcsAt U tag gS I.pA) (hIH : RkPcsAt U tag gS I.pH) (hOA : RkPcsAt U tag gS O.pA)
    (hOH : RkPcsAt U tag gS O.pH)
    (hBA : ∀ k, RkPcsR13 U tag (bp k).pA) (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (hfIA : 8 * I.pA.rows ≤ Lq) (hfIH : 8 * I.pH.rows ≤ Lq) (hfOA : 8 * O.pA.rows ≤ Lq) (hfOH : 8 * O.pH.rows ≤ Lq)
    (hfBA : ∀ k, 8 * (bp k).pA.rows ≤ Lq) (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (lscIn lscOut : Block.ZClaim)
    (mIn kIn kOut : ℕ) (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut) (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (base : ℕ → RkPart K Lq) (rdx : List UInt8 → Option Dig) (eL : ℕ)
    (hD : (ebData U tag Lq h64 key domain hs hL rdx R.pf
      (rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
        (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
        (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH))
      (rxAcc Win Wout Pk R.pf Lb) (rxLsc lscIn lscOut Pk Lb) eL).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (n : ℕ) (hn : R.pf.parts.length ≤ n)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G)
      (A.run G).1 (A.run G).2 = .ok ())
    (hWin : Win ((R.tr G (A.run G)).take (R.pf.off 0 + pin.pre)) = inc (A.run G).1.hdr)
    (hWout : Wout ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + pout.pre)) = outc (A.run G).1.hdr (A.run G).1.verdict)
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hA : ¬ (rtKA key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD).Dm n (A.runLog G).2 (R.tr G (A.run G))) :
    (∀ z ∈ (rxAcc Win Wout Pk R.pf Lb 0
        ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oA))).claims.a,
      claimSem U I.pA.rows gS.lc gS.Q (decodeRows (encGL (K := K) gS.lc gS.h gS.Q) gS.e (UxC tag Lq h64 gS.h I.pA.rows
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
          (Block.absAt ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oA)) (R.pf.off 0 + 5))
          (A.runLog G).2)
        (Block.absAt ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oA)) (R.pf.off 0 + 5))))
        z = z.value.toK U)
    ∧ (∀ z ∈ (rxAcc Win Wout Pk R.pf Lb 0
        ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oH))).claims.h,
      claimSem U I.pH.rows gS.lc gS.Q (decodeRows (encGL (K := K) gS.lc gS.h gS.Q) gS.e (UxC tag Lq h64 gS.h I.pH.rows
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
          (Block.absAt ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oH))
            (R.pf.off 0 + (5 + (4 + mIn)))) (A.runLog G).2)
        (Block.absAt ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oH))
          (R.pf.off 0 + (5 + (4 + mIn)))))) z = z.value.toK U) := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hi : 0 < R.pf.parts.length := by omega
  have hlen : ∀ (a : ℕ), ((R.tr G (A.run G)).take a).length = a → a ≤ (R.tr G (A.run G)).length := by
    intro a h
    rw [List.length_take] at h
    omega
  obtain ⟨⟨oA⟩, ⟨oH⟩⟩ := rx_parts_AHG (U := U) (gS := gS) (hgS := hgS) (hgSQ := hgSQ) (tag := tag) (h64 := h64)
    (hs := hs) (hL := hL) (Lb := Lb) (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG)
    (outc := outc) (outcG := outcG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
    (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (R := R) (hv := hv) (cx0 := cx0)
    (pin := pin) (pout := pout) (I := I) (O := O) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ)
    (hLb := hLb) (hgeo := hgeo) (Win := Win) (Wout := Wout) (mIn := mIn) (kIn := kIn) (kOut := kOut)
    (base := base) (acc := _) (hacc := rfl) (A := A) (G := G) (hE := hE) (hWin := hWin) (hWout := hWout)
    (hX := hX) (i := 0) (hi := hi) (hIA := hIA) (hIH := hIH) (hOA := hOA) (hOH := hOH) (hBA := hBA) (hBH := hBH)
    (hfIA := hfIA) (hfIH := hfIH) (hfOA := hfOA) (hfOH := hfOH) (hfBA := hfBA) (hfBH := hfBH) (lscIn := lscIn)
    (lscOut := lscOut) (hlscIn := hlscIn) (hlscOut := hlscOut) (hmIn := hmIn) (ps := _) (hps := rfl) (lsc := _)
    (hlsc := rfl)
  have ndA := wr_ndA key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD n (A.runLog G).2 (R.tr G (A.run G)) hA 0
    hi hn
  have sA := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) 0).gA
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) 0).nA
    (fun hdr => (rxAcc Win Wout Pk R.pf Lb 0 hdr).claims.a) _ (rtW R.pf.sqs) _ (A.runLog G).2 (R.tr G (A.run G))
    (ndA _ List.mem_cons_self) (hlen _ oA.hpl) oA.hpre (by have h := oA.hcnt; rw [← oA.hrd] at h; exact h)
  have sH := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) 0).gH
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) 0).nH
    (fun hdr => (rxAcc Win Wout Pk R.pf Lb 0 hdr).claims.h ++ [rxLsc lscIn lscOut Pk Lb 0]) _
    (rtW R.pf.sqs) _ (A.runLog G).2 (R.tr G (A.run G))
    (ndA _ (List.mem_cons_of_mem _ List.mem_cons_self)) (hlen _ oH.hpl) oH.hpre
    (by have h := oH.hcnt; rw [← oH.hrd] at h; exact h)
  refine ⟨fun z hz => ?_, fun z hz => ?_⟩
  · have hv := sA z hz
    simp only [wrOSem, rkOpen, UxW_eq_cut] at hv
    exact hv
  · have hv := sH z (List.mem_append_left _ hz)
    simp only [wrOSem, rkOpen, UxW_eq_cut] at hv
    exact hv

/-- **STAGE IN-C'S `A`/`H` CLAIMS PART ON AN ACCEPTED RUN** outside `EvXR`, no doomed `opA` entrant. -/
theorem ssh_AHAtI
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (I : RtInc Lq inc incG pin) (O : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hLb : Lb ≤ 26) (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (gS : OGeo) (hgS : gS.Ok) (hgSQ : gS.Q ≤ 256)
    (hIA : RkPcsAt U tag gS I.pA) (hIH : RkPcsAt U tag gS I.pH) (hOA : RkPcsAt U tag gS O.pA)
    (hOH : RkPcsAt U tag gS O.pH)
    (hBA : ∀ k, RkPcsR13 U tag (bp k).pA) (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (hfIA : 8 * I.pA.rows ≤ Lq) (hfIH : 8 * I.pH.rows ≤ Lq) (hfOA : 8 * O.pA.rows ≤ Lq) (hfOH : 8 * O.pH.rows ≤ Lq)
    (hfBA : ∀ k, 8 * (bp k).pA.rows ≤ Lq) (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (lscIn lscOut : Block.ZClaim)
    (mIn kIn kOut : ℕ) (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut) (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (base : ℕ → RkPart K Lq) (rdx : List UInt8 → Option Dig) (eL : ℕ)
    (hD : (ebData U tag Lq h64 key domain hs hL rdx R.pf
      (rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
        (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
        (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH))
      (rxAcc Win Wout Pk R.pf Lb) (rxLsc lscIn lscOut Pk Lb) eL).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (n : ℕ) (hn : R.pf.parts.length ≤ n)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G)
      (A.run G).1 (A.run G).2 = .ok ())
    (hWin : Win ((R.tr G (A.run G)).take (R.pf.off 0 + pin.pre)) = inc (A.run G).1.hdr)
    (hWout : Wout ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + pout.pre)) = outc (A.run G).1.hdr (A.run G).1.verdict)
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hA : ¬ (rtKA key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD).Dm n (A.runLog G).2 (R.tr G (A.run G)))
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) :
    StgClaimsAH U key domain (fun ch => (inc (A.run G).1.hdr).bp (incCtx (inc (A.run G).1.hdr).pub ch)) mIn
      (R.pf.off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgCsv U tag h64 gS.lc gS.h gS.Q gS.e I.pA.rows I.pH.rows (R.pf.off 0 + 5) (R.pf.off 0 + 5 + 4 + mIn) csIO) G
      (A.runLog G).2 (R.tr G (A.run G)) := by
  obtain ⟨hA', hH'⟩ := ssh_run_AHI (U := U) (hbij := hbij) (tag := tag) (h64 := h64) (hs := hs) (hL := hL)
    (hL64 := hL64) (Lb := Lb) (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG)
    (outc := outc) (outcG := outcG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
    (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (R := R) (hv := hv) (cx0 := cx0)
    (pin := pin) (pout := pout) (I := I) (O := O) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ)
    (hLb := hLb) (hgeo := hgeo) (gS := gS) (hgS := hgS) (hgSQ := hgSQ) (hIA := hIA) (hIH := hIH) (hOA := hOA)
    (hOH := hOH) (hBA := hBA) (hBH := hBH) (hfIA := hfIA) (hfIH := hfIH) (hfOA := hfOA) (hfOH := hfOH)
    (hfBA := hfBA) (hfBH := hfBH) (Win := Win) (Wout := Wout) (lscIn := lscIn) (lscOut := lscOut) (mIn := mIn)
    (kIn := kIn) (kOut := kOut) (hlscIn := hlscIn) (hlscOut := hlscOut) (hmIn := hmIn) (base := base) (rdx := rdx)
    (eL := eL) (hD := hD) (n := n) (hn := hn) (A := A) (G := G) (hE := hE) (hWin := hWin) (hWout := hWout)
    (hX := hX) (hA := hA)
  have hσ0 : R.σs[0]? = some (rtIncSeg inc incG cx0 pin) := by rw [hσ]; rfl
  have hp0 : R.pf.part 0 = pin := rx_part_of R 0 _ hσ0
  have hkey : ∀ a, R.pf.off 0 + (R.pf.part 0).pre ≤ a →
      ∀ hdr core ch rs, StgRd key domain Lq (fun ch => (inc (A.run G).1.hdr).bp (incCtx (inc (A.run G).1.hdr).pub ch))
        mIn (R.pf.off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G (R.tr G (A.run G)) hdr core ch rs →
      ∀ acc t', StageFS.stageSlots (liftH G) ((inc (A.run G).1.hdr).bp (incCtx (inc (A.run G).1.hdr).pub ch)) mIn
          (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) core
          (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t') →
        (rxAcc Win Wout Pk R.pf Lb 0 ((R.tr G (A.run G)).take a)).claims.a = acc.claims.a
          ∧ (rxAcc Win Wout Pk R.pf Lb 0 ((R.tr G (A.run G)).take a)).claims.h = acc.claims.h := by
    intro a ha hdr core ch rs hrd acc t' hacc
    have e1 : rxAcc Win Wout Pk R.pf Lb 0 ((R.tr G (A.run G)).take a)
        = rsAccInc (inc (A.run G).1.hdr) (R.pf.off 0 + 5) ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).pre)) := by
      show rsAccInc (Win (((R.tr G (A.run G)).take a).take (R.pf.off 0 + (R.pf.part 0).pre))) (R.pf.off 0 + 5)
          (((R.tr G (A.run G)).take a).take (R.pf.off 0 + (R.pf.part 0).pre)) = _
      rw [List.take_take, min_eq_left ha, hp0, hWin]
    rw [e1]
    exact ssh_inc_link_ah key domain (inc (A.run G).1.hdr) mIn (R.pf.off 0 + 5) _ (hmIn _) G _ hdr core ch rs hrd
      (I.hgt _) (fun cx k hk => (I.hgeomL _ cx k hk).1)
      (fun cx => by rw [hp0, ← I.hpre (A.run G).1.hdr cx, hmIn]; omega) acc t' hacc
  have wA : R.pf.off 0 + (R.pf.part 0).pre ≤ R.pf.off 0 + (R.pf.part 0).oA := by
    simp only [RtPart.oA]
    omega
  have wH : R.pf.off 0 + (R.pf.part 0).pre ≤ R.pf.off 0 + (R.pf.part 0).oH := by
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  refine ssh_AHAt U tag h64 key domain hs hL _ mIn (R.pf.off 0 + 5) _ gS.lc gS.h gS.Q gS.e I.pA.rows
    I.pH.rows (R.pf.off 0 + (R.pf.part 0).oA) (R.pf.off 0 + (R.pf.part 0).oH) csIO
    (rxAcc Win Wout Pk R.pf Lb 0) G (A.runLog G).2 (R.tr G (A.run G)) (fun _ => I.hgt _) ?_ ?_ hA' ?_ ?_
  · simp only [RtPart.oA]
    omega
  · have hpre0 := I.hpre (A.run G).1.hdr cx0
    rw [hmIn] at hpre0
    rw [hp0]
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  · rw [show R.pf.off 0 + 5 + 4 + mIn = R.pf.off 0 + (5 + (4 + mIn)) by omega]
    exact hH'
  · intro hdr core ch rs hrd acc t' hacc
    exact ⟨(hkey _ wA hdr core ch rs hrd acc t' hacc).1, (hkey _ wH hdr core ch rs hrd acc t' hacc).2⟩

end Run

end ZK60.ProtocolClassify
