/-
D63 lane L63 (2026-11-16), part 9: **the claims part split by commitment; stage OUT-C's `A` and `H` claims PROVED**
(item (iii), step B).

* `StgClaimsAH`, `StgClaimsIO`, **`ssh_claimsAt_of_split`**: `StgClaimsAt` (all four commitments) from its `A`/`H` part
  and its IO part;
* **`ssh_AHAt`**: the `A`/`H` part at a stage from the run's extracted `A`, `H` matrices at their opening windows, when
  the run's stage reader there has the reading's `A`, `H` claims;
* **`ssh_run_AHO`**: on an accepted run outside `EvXR` with no doomed `opA` entrant (`¬ rtKA.Dm`), every `A` and `H`
  claim stage OUT-C's reader returns at its opening's window is true of the decoded extracted matrix (lane L54's
  `wr_ndA`, `wr_rkOpen_sem`; L45 / L48's `rx_parts_AHG`);
* **`ssh_AHAtO`**: `StgClaimsAH` at stage OUT-C on such a run (L45's `rs_accS_trace`: the stage model IS the code at
  OUT-C, so the reading's accumulator is the reader's, claims included).

Stage IN-C's claims are not treated here: finding L63-5 (§10 of the lane doc).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldTrueRun
import ZK60Formal.RunBndSem

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx incCtx)
open ZK60.Circuit (gP GF)

section Split

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The `A`/`H` claims part.** -/
def StgClaimsAH (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (csv : StgVw L → Block.Cm → Block.ZClaim → K) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ acc t', StageFS.stageSlots (liftH G) (Pof ch) m bgaOf core
        (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t') →
    ∀ k q, core.slots[k]? = some q →
      (∀ z ∈ acc.claims.a, csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q))) .a z = z.value.toK U)
      ∧ (∀ z ∈ acc.claims.h, csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q))) .h z = z.value.toK U)

/-- **The IO claims part** (the claims on the input endpoint / `B_in` / `B_out`, whose semantics `csIO` is free). -/
def StgClaimsIO (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (csv : StgVw L → Block.Cm → Block.ZClaim → K) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ acc t', StageFS.stageSlots (liftH G) (Pof ch) m bgaOf core
        (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t') →
    ∀ k q, core.slots[k]? = some q →
      (∀ z ∈ acc.claims.inp, csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q))) .inp z = z.value.toK U)
      ∧ (∀ z ∈ acc.claims.out, csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q))) .out z = z.value.toK U)

/-- **`StgClaimsAt` from its two parts.** -/
theorem ssh_claimsAt_of_split (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (csv : StgVw L → Block.Cm → Block.ZClaim → K) (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hAH : StgClaimsAH U key domain Pof m hdrLen bgaOf absOf csv G Lg τ)
    (hIO : StgClaimsIO U key domain Pof m hdrLen bgaOf absOf csv G Lg τ) :
    StgClaimsAt U key domain Pof m hdrLen bgaOf absOf csv G Lg τ := by
  intro hdr core ch rs hrd acc t' hacc k q hq cm c hc
  obtain ⟨hA, hH⟩ := hAH hdr core ch rs hrd acc t' hacc k q hq
  obtain ⟨hI, hO⟩ := hIO hdr core ch rs hrd acc t' hacc k q hq
  cases cm with
  | a => exact hA c hc
  | h => exact hH c hc
  | inp => exact hI c hc
  | out => exact hO c hc

end Split

section AH

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- **The `A`/`H` part from the run's extracted matrices at the opening windows** (`hrunA`, `hrunH`), when the run's stage
reader there has the reading's claims (`hlink`). -/
theorem ssh_AHAt (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (lc h Q e rA rH aOA aOH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (Racc : List (TItem × Dig) → Block.Acc)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hA : hdrLen < aOA) (hH : hdrLen + 4 + m < aOH)
    (hrunA : ∀ z ∈ (Racc (τ.take aOA)).claims.a,
      claimSem U rA lc Q (decodeRows (encGL (K := K) lc h Q) e (UxC tag L h64 h rA
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs L hL)) (Block.absAt (τ.take aOA) hdrLen) Lg)
        (Block.absAt (τ.take aOA) hdrLen))) z = z.value.toK U)
    (hrunH : ∀ z ∈ (Racc (τ.take aOH)).claims.h,
      claimSem U rH lc Q (decodeRows (encGL (K := K) lc h Q) e (UxC tag L h64 h rH
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs L hL)) (Block.absAt (τ.take aOH) (hdrLen + 4 + m)) Lg)
        (Block.absAt (τ.take aOH) (hdrLen + 4 + m)))) z = z.value.toK U)
    (hlink : ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
      ∀ acc t', StageFS.stageSlots (liftH G) (Pof ch) m bgaOf core
          (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t') →
        (Racc (τ.take aOA)).claims.a = acc.claims.a ∧ (Racc (τ.take aOH)).claims.h = acc.claims.h) :
    StgClaimsAH U key domain Pof m hdrLen bgaOf (Exec.Block.absOfC (chainEncB key domain hs L hL))
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) csIO) G Lg τ := by
  intro hdr core ch rs hrd acc t' hacc k q hq
  obtain ⟨la, lh⟩ := hlink hdr core ch rs hrd acc t' hacc
  obtain ⟨h1, -⟩ := stg_rd_slot key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd (hgt ch) k q hq
  rw [← h1]
  have hk1 : hdrLen < stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3) := by unfold stgDefPos; omega
  have hk2 : hdrLen + 4 + m < stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3) := by unfold stgDefPos; omega
  refine ⟨fun z hz => ?_, fun z hz => ?_⟩
  · rw [← la] at hz
    have hv := hrunA z hz
    rw [ssh_absAt_take τ aOA _ hA] at hv
    show claimSem U rA lc Q (decodeRows (encGL (K := K) lc h Q) e (UxC tag L h64 h rA
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs L hL))
          (Block.absAt (τ.take (stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3))) hdrLen) Lg)
        (Block.absAt (τ.take (stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3))) hdrLen))) z = _
    rw [ssh_absAt_take τ _ _ hk1]
    exact hv
  · rw [← lh] at hz
    have hv := hrunH z hz
    rw [ssh_absAt_take τ aOH _ hH] at hv
    show claimSem U rH lc Q (decodeRows (encGL (K := K) lc h Q) e (UxC tag L h64 h rH
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs L hL))
          (Block.absAt (τ.take (stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3))) (hdrLen + 4 + m)) Lg)
        (Block.absAt (τ.take (stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3))) (hdrLen + 4 + m)))) z = _
    rw [ssh_absAt_take τ _ _ hk2]
    exact hv

end AH

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

/-- **STAGE OUT-C'S `A`/`H` CLAIMS ARE TRUE OF THE RUN'S EXTRACTED MATRICES** at their opening windows, on an accepted run
outside `EvXR` with no doomed `opA` entrant. -/
theorem ssh_run_AHO
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
    (∀ z ∈ (rxAcc Win Wout Pk R.pf Lb (Lb + 1)
        ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oA))).claims.a,
      claimSem U O.pA.rows gS.lc gS.Q (decodeRows (encGL (K := K) gS.lc gS.h gS.Q) gS.e (UxC tag Lq h64 gS.h O.pA.rows
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
          (Block.absAt ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oA)) (R.pf.off (Lb + 1) + 2))
          (A.runLog G).2)
        (Block.absAt ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oA)) (R.pf.off (Lb + 1) + 2))))
        z = z.value.toK U)
    ∧ (∀ z ∈ (rxAcc Win Wout Pk R.pf Lb (Lb + 1)
        ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oH))).claims.h,
      claimSem U O.pH.rows gS.lc gS.Q (decodeRows (encGL (K := K) gS.lc gS.h gS.Q) gS.e (UxC tag Lq h64 gS.h O.pH.rows
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
          (Block.absAt ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oH))
            (R.pf.off (Lb + 1) + (2 + (4 + 2)))) (A.runLog G).2)
        (Block.absAt ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oH))
          (R.pf.off (Lb + 1) + (2 + (4 + 2)))))) z = z.value.toK U) := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hi : Lb + 1 < R.pf.parts.length := by omega
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
    (hX := hX) (i := Lb + 1) (hi := hi) (hIA := hIA) (hIH := hIH) (hOA := hOA) (hOH := hOH) (hBA := hBA) (hBH := hBH)
    (hfIA := hfIA) (hfIH := hfIH) (hfOA := hfOA) (hfOH := hfOH) (hfBA := hfBA) (hfBH := hfBH) (lscIn := lscIn)
    (lscOut := lscOut) (hlscIn := hlscIn) (hlscOut := hlscOut) (hmIn := hmIn) (ps := _) (hps := rfl) (lsc := _)
    (hlsc := rfl)
  have ndA := wr_ndA key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD n (A.runLog G).2 (R.tr G (A.run G)) hA (Lb + 1)
    hi hn
  have sA := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) (Lb + 1)).gA
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) (Lb + 1)).nA
    (fun hdr => (rxAcc Win Wout Pk R.pf Lb (Lb + 1) hdr).claims.a) _ (rtW R.pf.sqs) _ (A.runLog G).2 (R.tr G (A.run G))
    (ndA _ List.mem_cons_self) (hlen _ oA.hpl) oA.hpre (by have h := oA.hcnt; rw [← oA.hrd] at h; exact h)
  have sH := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) (Lb + 1)).gH
    ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
      (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
      (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) (Lb + 1)).nH
    (fun hdr => (rxAcc Win Wout Pk R.pf Lb (Lb + 1) hdr).claims.h ++ [rxLsc lscIn lscOut Pk Lb (Lb + 1)]) _
    (rtW R.pf.sqs) _ (A.runLog G).2 (R.tr G (A.run G))
    (ndA _ (List.mem_cons_of_mem _ List.mem_cons_self)) (hlen _ oH.hpl) oH.hpre
    (by have h := oH.hcnt; rw [← oH.hrd] at h; exact h)
  refine ⟨fun z hz => ?_, fun z hz => ?_⟩
  · have hv := sA z hz
    simp only [wrOSem, rkOpen, UxW_eq_cut] at hv
    rw [rxPs_out] at hv
    exact hv
  · have hv := sH z (List.mem_append_left _ hz)
    simp only [wrOSem, rkOpen, UxW_eq_cut] at hv
    rw [rxPs_out] at hv
    exact hv

end Run

end ZK60.ProtocolClassify
