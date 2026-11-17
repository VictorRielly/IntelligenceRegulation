/-
D63 lane L63 (2026-11-16), part 10: **stage OUT-C's `A`/`H` claims part on an accepted run** (`ssh_AHAtO`).

On an accepted run outside `EvXR` with no doomed `opA` entrant, `StgClaimsAH` holds at stage OUT-C for the view's claims
semantics (`stgCsv`, any IO semantics `csIO`): the run's OUT-C reader at the `A` and `H` windows is the reading's
accumulator (L45's `rs_accS_trace`, through `ssh_outc_link`), and its `A`/`H` claims are true of the extracted matrices
(`ssh_run_AHO`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldClaims

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx incCtx)
open ZK60.Circuit (gP GF)

section Code

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Stage IN-C's IO claims part over the CODE's accumulator** (finding L63-5, the correct notion): L15's model
(`stageSlots` at one IO width) builds INC-00's input-endpoint claim at `B_in`'s row width, the code (and L29's `IncV.slots`,
`atLog` per slot) at the input endpoint's; the claims the code's openings check are those of the code's accumulator, read
on the run by L45's `rsAccInc` at the slot phase's end `e`. -/
def StgClaimsIOC (U : K) (key : Option Dig) (domain : List UInt8) (V : IncV) (m hdrLen e : ℕ)
    (absOf : QB L → Option (List UInt8)) (csv : StgVw L → Block.Cm → Block.ZClaim → K) (G : QB L → Dig)
    (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L (fun ch => V.bp (incCtx V.pub ch)) m hdrLen
      (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G τ hdr core ch rs →
    ∀ k q, core.slots[k]? = some q →
      (∀ z ∈ (rsAccInc V hdrLen (τ.take e)).claims.inp, csv (stgVw absOf Lg (opTrace (liftH G)
          (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps (V.bp (incCtx V.pub ch)) core m
            ++ Block.fullOps (V.bp (incCtx V.pub ch)) 0 (core.slots.take k)
            ++ Block.slotPreOps (V.bp (incCtx V.pub ch)) k q))) .inp z = z.value.toK U)
      ∧ (∀ z ∈ (rsAccInc V hdrLen (τ.take e)).claims.out, csv (stgVw absOf Lg (opTrace (liftH G)
          (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps (V.bp (incCtx V.pub ch)) core m
            ++ Block.fullOps (V.bp (incCtx V.pub ch)) 0 (core.slots.take k)
            ++ Block.slotPreOps (V.bp (incCtx V.pub ch)) k q))) .out z = z.value.toK U)

end Code

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

/-- **STAGE OUT-C'S `A`/`H` CLAIMS PART ON AN ACCEPTED RUN** outside `EvXR`, no doomed `opA` entrant. -/
theorem ssh_AHAtO
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
    StgClaimsAH U key domain (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 (R.pf.off (Lb + 1) + 2)
      OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgCsv U tag h64 gS.lc gS.h gS.Q gS.e O.pA.rows O.pH.rows (R.pf.off (Lb + 1) + 2) (R.pf.off (Lb + 1) + 2 + 4 + 2)
        csIO) G (A.runLog G).2 (R.tr G (A.run G)) := by
  obtain ⟨hA', hH'⟩ := ssh_run_AHO (U := U) (hbij := hbij) (tag := tag) (h64 := h64) (hs := hs) (hL := hL)
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
  have hσo : R.σs[Lb + 1]? = some (rtOutcSeg outc outcG pout) := by
    rw [hσ]
    exact rx_getOut _ _ _ _
  have hpo : R.pf.part (Lb + 1) = pout := rx_part_of R (Lb + 1) _ hσo
  have hg : (outc (A.run G).1.hdr (A.run G).1.verdict).bp.geom = (outc (A.run G).1.hdr (A.run G).1.verdict).geom := rfl
  have hpre := O.hpre (A.run G).1.hdr (A.run G).1.verdict
  have hkey : ∀ a, R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre ≤ a →
      ∀ hdr core ch rs, StgRd key domain Lq (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2
        (R.pf.off (Lb + 1) + 2) OutcV.bga G (R.tr G (A.run G)) hdr core ch rs →
      ∀ acc t', StageFS.stageSlots (liftH G) (outc (A.run G).1.hdr (A.run G).1.verdict).bp 2 OutcV.bga core
          (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t') →
        rxAcc Win Wout Pk R.pf Lb (Lb + 1) ((R.tr G (A.run G)).take a) = acc := by
    intro a ha hdr core ch rs hrd acc t' hacc
    rw [rxAcc_out]
    show rsAccS (Wout (((R.tr G (A.run G)).take a).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre))).bp 2 OutcV.bga
      (R.pf.off (Lb + 1) + 2) (((R.tr G (A.run G)).take a).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre)) = acc
    rw [List.take_take, min_eq_left ha, hpo, hWout]
    exact ssh_outc_link key domain _ (R.pf.off (Lb + 1) + 2) _ G _ hdr core ch rs hrd (O.hgt _ _)
      (fun k hk => (O.hgeomL _ _ k hk).1) (by rw [← hpre, hg]; omega) acc t' hacc
  have wA : R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre ≤ R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oA := by
    simp only [RtPart.oA]
    omega
  have wH : R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre ≤ R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oH := by
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  refine ssh_AHAt U tag h64 key domain hs hL _ 2 (R.pf.off (Lb + 1) + 2) OutcV.bga gS.lc gS.h gS.Q gS.e O.pA.rows
    O.pH.rows (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oA) (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).oH) csIO
    (rxAcc Win Wout Pk R.pf Lb (Lb + 1)) G (A.runLog G).2 (R.tr G (A.run G)) (fun _ => O.hgt _ _) ?_ ?_ hA' ?_ ?_
  · simp only [RtPart.oA]
    omega
  · simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  · rw [show R.pf.off (Lb + 1) + 2 + 4 + 2 = R.pf.off (Lb + 1) + (2 + (4 + 2)) by omega]
    exact hH'
  · intro hdr core ch rs hrd acc t' hacc
    rw [hkey _ wA hdr core ch rs hrd acc t' hacc, hkey _ wH hdr core ch rs hrd acc t' hacc]
    exact ⟨rfl, rfl⟩

end Run

end ZK60.ProtocolClassify
