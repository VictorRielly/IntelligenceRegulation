/-
D63 lane L63 (2026-11-17), part 42: **`hTrIIO` PROVED at the pinned IO semantics** (the handoff's plan item 2).

Stage IN-C's IO claims of the code's accumulator (`StgClaimsIOC`, over `rsAccInc`) are true of the view's IO semantics
`stgCsIOm … (epUxV …) (bxUxV …)` (part 40) on an accepted run outside the run's events with no doomed `opA` entrant:

* the `.inp` claims are among those part `0`'s closing opening (`ebOpen`, repair B) checks; with no doomed entrant at its
  window they are true of `decodeRows` of its unchecked matrix (L52's `eb_hopX0` for the acceptance facts, lane L46's
  `wr_ndA`, `ssh_ebOpen_sem`); that matrix read on any view below the stage's slot phase is `epUxV`'s
  (`epUxV_view`, `ebUxW_hdr`: the matrix depends on the header only through its message at position `1`);
* the `.out` claims (stage IN-C's claims on `B_in`) are pending on part `1`'s closing opening (`rkOpen` at
  `rkR13 (pXk 0).rows (off 0 + 2)`), which checks them (lane L55's `cb_hopX1_one`, `wr_rkOpen_sem`); its matrix on the
  view is `bxUxV`'s (`bxUxV_view`, `UxW_hdr`);
* the accumulator: the run's IN-C reader at both windows is `rsAccInc` at the slot phase's end (`rxAcc` at part `0`,
  `vdWin`).

* **`ssh_trIIO_run`**: the run lemma, for any kinds data `D` equal to `ebData` on a base whose closing geometries at
  parts `0` and `1` are the endpoint's and R13's (`hgX0`, `hnX0`, `hgX1`, `hnX1`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIOPin
import ZK60Formal.RunCloseBEnds
import ZK60Formal.RunEpBInc
import ZK60Formal.RunStgShieldClaimsRun

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx incCtx)
open ZK60.Circuit (gP GF)

section View

variable {K : Type} [Field K] [Algebra GF K] (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- **The unchecked matrix read from the log cut at the header's own message is the whole log's** (for every reader). -/
theorem ebUxW_cut_self (rd : List UInt8 → Option Dig) (d i rows N : ℕ) (Lg : List (QB L × Dig))
    (hdr : List (TItem × Dig)) :
    ebUxW (K := K) tag L h64 key domain hs hL rd d i rows (N := N)
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs L hL)) (Block.absAt hdr i) Lg) hdr
      = ebUxW (K := K) tag L h64 key domain hs hL rd d i rows (N := N) Lg hdr := by
  funext row j
  unfold ebUxW colXM
  rcases hx : Block.absAt hdr i with _ | x
  · rfl
  · rcases hr : rd x with _ | r
    · simp only [Option.bind_some, hr]
    · have hfg : ∀ y, Block.absOfC (chainEncB key domain hs L hL) y = some x
          → absMOf L key domain hs hL rd y = some r :=
        fun y hy => by rw [absMOf, hy, Option.bind_some, hr]
      simp only [Option.bind_some, hr, Block.cutO]
      rw [ab_cut_coarse _ _ x r hfg Lg]

/-- The unchecked matrix reads the header only through its message at the root's position. -/
theorem ebUxW_hdr (rd : List UInt8 → Option Dig) (d i rows N : ℕ) (Lg : List (QB L × Dig))
    (hdr hdr' : List (TItem × Dig)) (h : Block.absAt hdr i = Block.absAt hdr' i) :
    ebUxW (K := K) tag L h64 key domain hs hL rd d i rows (N := N) Lg hdr
      = ebUxW (K := K) tag L h64 key domain hs hL rd d i rows (N := N) Lg hdr' := by
  funext row j
  unfold ebUxW colXM
  rw [h]

/-- **`epUxV` on the view of a log at a header is the decoded unchecked matrix of that log at that header.** -/
theorem epUxV_view (R : ℕ) (Lg : List (QB L × Dig)) (hdr : List (TItem × Dig)) :
    epUxV (K := K) tag L h64 key domain hs hL R (stgVw (Exec.Block.absOfC (chainEncB key domain hs L hL)) Lg hdr)
      = decodeRows (encGL (K := K) 8 11 256) 768
          (ebUxW (K := K) tag L h64 key domain hs hL abRdIn 11 1 R (N := 2 ^ 11) Lg hdr) := by
  show decodeRows (encGL (K := K) 8 11 256) 768 (ebUxW (K := K) tag L h64 key domain hs hL abRdIn 11 1 R (N := 2 ^ 11)
      (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs L hL)) (Block.absAt hdr 1) Lg) hdr) = _
  rw [ebUxW_cut_self]

/-- An R13 opening's extracted matrix reads the header only through its message at the root's position. -/
theorem UxW_hdr (d i rows N : ℕ) (Lg : List (QB L × Dig)) (hdr hdr' : List (TItem × Dig))
    (h : Block.absAt hdr i = Block.absAt hdr' i) :
    (Link.UxW tag L h64 key domain hs hL d i rows Lg hdr : Fin rows → Fin N → K)
      = Link.UxW tag L h64 key domain hs hL d i rows Lg hdr' := by
  rw [UxW_eq_cut, UxW_eq_cut, h]

/-- **`bxUxV` on the view of a log at a header is the decoded extracted matrix of that log at that header.** -/
theorem bxUxV_view (R ipos : ℕ) (Lg : List (QB L × Dig)) (hdr : List (TItem × Dig)) :
    bxUxV (K := K) tag L h64 R ipos (stgVw (Exec.Block.absOfC (chainEncB key domain hs L hL)) Lg hdr)
      = decodeRows (encGL (K := K) 14 16 256) 24448
          (Link.UxW tag L h64 key domain hs hL 16 ipos R (N := 2 ^ 16) Lg hdr) := by
  rw [UxW_eq_cut]
  rfl

/-- **Part `0`'s closing opening at the endpoint geometry: its claims' semantics** (`wrOSem`) in `epUxV`'s form. -/
theorem wrOSem_ebEp (U : K) (g : RkGeo) (R : ℕ) (hg : g = rkAt ogEp R 1) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim) (vpos : ℕ) (lg : List (QB L × Dig)) (hdr : List (TItem × Dig))
    (z : Block.ZClaim) :
    wrOSem U (ebOpen U tag L h64 key domain hs hL abRdIn g nC clr vpos) lg hdr z
      = claimSem U R 8 256 (decodeRows (encGL (K := K) 8 11 256) 768
          (ebUxW (K := K) tag L h64 key domain hs hL abRdIn 11 1 R (N := 2 ^ 11) lg hdr)) z := by
  subst hg
  rfl

/-- **An R13 closing opening: its claims' semantics** (`wrOSem`) in `bxUxV`'s form. -/
theorem wrOSem_rkR13 (U : K) (g : RkGeo) (R ipos : ℕ) (hg : g = rkR13 R ipos) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim) (vpos : ℕ) (lg : List (QB L × Dig)) (hdr : List (TItem × Dig))
    (z : Block.ZClaim) :
    wrOSem U (rkOpen U tag L h64 key domain hs hL g nC clr vpos) lg hdr z
      = claimSem U R 14 256 (decodeRows (encGL (K := K) 14 16 256) 24448
          (Link.UxW tag L h64 key domain hs hL 16 ipos R (N := 2 ^ 16) lg hdr)) z := by
  subst hg
  rfl

end View

section Rd

variable {L : ℕ}

/-- **At a reading, the header of slot `k`'s window shows what the run's transcript shows below the stage's head.** -/
theorem ssh_rd_absAt (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (G : QB L → Dig) (τ : List (TItem × Dig)) (hdr : List Op)
    (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length) (k : ℕ) (q : Block.SlotProof)
    (hq : core.slots[k]? = some q) (i : ℕ) (hi : i < hdrLen) :
    Block.absAt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps (Pof ch) core m
        ++ Block.fullOps (Pof ch) 0 (core.slots.take k) ++ Block.slotPreOps (Pof ch) k q)) i = Block.absAt τ i := by
  obtain ⟨h1, -⟩ := stg_rd_slot key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd hgt k q hq
  rw [← h1]
  exact ssh_absAt_take τ _ i (by unfold stgDefPos; omega)

end Rd

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

/-- **`hTrIIO` ON AN ACCEPTED RUN** outside the run's events (`EvXR`, `exEvIn`) with no doomed `opA` entrant: every IO
claim of stage IN-C's code accumulator is true of the pinned IO semantics at every slot window of every reading. -/
theorem ssh_trIIO_run
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (hw : Hdr → ClsHdrW) (hR : ∀ s, R.hdr s = clsHdrOf hw s)
    (cx0 : IncCtx) (pin pout : RtPart) (I : RtInc Lq inc incG pin)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (hXep : RkPcsAt U tag ogEp I.pX) (hfitX : 8 * I.pX.rows ≤ Lq)
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (hXk : ∀ k, RkPcsR13 U tag (pXk k))
    (hwX0 : wXk 0 = I.nOut + (bp 0).nIn + (pXk 0).rows) (hmX0 : mXk 0 = (pXk 0).m)
    (hfitXk : ∀ k, 8 * (pXk k).rows ≤ Lq) (hLb1 : 0 < Lb)
    (Vi : IncV) (hinc : ∀ hd, inc hd = Vi) (Wout : List (TItem × Dig) → OutcV)
    (base : ℕ → RkPart K Lq) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH) (lsc : ℕ → Block.ZClaim) (eL : ℕ)
    (hgX0 : (base 0).gX = rkAt ogEp I.pX.rows 1) (hnX0 : (base 0).nX = I.nIn)
    (hgX1 : (base 1).gX = rkR13 (pXk 0).rows (R.pf.off 0 + 2)) (hnX1 : (base 1).nX = I.nOut + (bp 0).nIn)
    (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn R.pf (rxPs base Lb din dblk dout)
      (rxAcc (vdWin Vi) Wout Pk R.pf Lb) lsc eL)
    (n : ℕ) (hn : R.pf.parts.length ≤ n)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G)
      (A.run G).1 (A.run G).2 = .ok ())
    (hX : ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G
      ∨ exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G))
    (hA : ¬ (rtKA key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD).Dm n (A.runLog G).2 (R.tr G (A.run G)))
    (Rr mIn : ℕ) (hRr : I.pX.rows = Rr) (lc h Q e rA rH iH : ℕ) :
    StgClaimsIOC U key domain (inc (A.run G).1.hdr) mIn (R.pf.off 0 + 5) (R.pf.off 0 + pin.pre)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgCsv U tag h64 lc h Q e rA rH (R.pf.off 0 + 5) iH
        (stgCsIOm U Rr 8 256 (pXk 0).rows 14 256 (epUxV tag Lq h64 key domain hs hL Rr)
          (bxUxV tag Lq h64 (pXk 0).rows (R.pf.off 0 + 2))))
      G (A.runLog G).2 (R.tr G (A.run G)) := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hi0 : 0 < R.pf.parts.length := by omega
  have hi1 : 1 < R.pf.parts.length := by omega
  have hσ0 : R.σs[0]? = some (rtIncSeg inc incG cx0 pin) := by rw [hσ]; rfl
  have hσb : ∀ k, k < Lb → R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck
      bndOpen k (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows)
        (bp k).pH.m (wXk k) (gXk k) (mXk k))) := by
    intro k hk
    rw [hσ]
    exact rx_getBlk _ _ _ _ k hk
  have hp0 : R.pf.part 0 = pin := rx_part_of R 0 _ hσ0
  have hWin : vdWin Vi ((R.tr G (A.run G)).take (R.pf.off 0 + pin.pre)) = inc (A.run G).1.hdr := (hinc _).symm
  have hXM : ¬ EvXM tag Lq h64 key domain hs hL abRdIn 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) ebInRoots A G :=
    fun h' => hX (Or.inr (evXC_of_xm tag Lq h64 key domain hs hL abRdIn 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) ebInRoots A G h'))
  -- the acceptance facts of the closing openings at parts 0 and 1
  obtain ⟨w0⟩ := eb_hopX0 U tag h64 hs hL hw R hR hv G (A.run G).1 (A.run G).2 hE pin inc incG cx0 I hσ0 (vdWin Vi)
    Wout Pk Lb base din dblk dout hWin ogEp ogEp_ok (by decide) hXep hgX0 hnX0 outcG sgeom A rfl hXM hfitX
  obtain ⟨w1⟩ := cb_hopX1_one U tag h64 hs hL Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G
    (A.run G).1 (A.run G).2 hE Lb hLb1 pin inc incG cx0 I hσ0 (vdWin Vi) hWin bp
    (fun k => rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows)
      (bp k).pH.m (wXk k) (gXk k) (mXk k))
    hσb (fun s k => hgeo k s) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) pXk hXk
    hwX0 hmX0 hfitXk base din dblk dout hgX1 hnX1 Wout abRdIn outcG A rfl (fun h' => hX (Or.inl h'))
  -- no doomed `opA` entrant at the two closing openings
  have ndA0 := wr_ndA key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD n (A.runLog G).2 (R.tr G (A.run G)) hA 0
    hi0 hn
  have ndA1 := wr_ndA key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD n (A.runLog G).2 (R.tr G (A.run G)) hA 1
    hi1 hn
  have nd0 := ndA0 _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self))
  have nd1 := ndA1 _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self))
  subst hDe
  have hlen : ∀ (a : ℕ), ((R.tr G (A.run G)).take a).length = a → a ≤ (R.tr G (A.run G)).length := by
    intro a h'
    rw [List.length_take] at h'
    omega
  have s0 := ssh_ebOpen_sem U hbij tag Lq h64 key domain hs hL abRdIn (rxPs base Lb din dblk dout 0).gX
    (rxPs base Lb din dblk dout 0).nX
    (fun hdr => rkPend (rxAcc (vdWin Vi) Wout Pk R.pf Lb) 0 hdr ++ (rxAcc (vdWin Vi) Wout Pk R.pf Lb 0 hdr).claims.inp)
    _ (rtW R.pf.sqs) _ (A.runLog G).2 (R.tr G (A.run G)) nd0 (hlen _ w0.hpl) w0.hpre
    (by have h' := w0.hcnt; rw [← w0.hrd] at h'; exact h')
  have s1 := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL (rxPs base Lb din dblk dout 1).gX
    (rxPs base Lb din dblk dout 1).nX
    (fun hdr => rkPend (rxAcc (vdWin Vi) Wout Pk R.pf Lb) 1 hdr ++ (rxAcc (vdWin Vi) Wout Pk R.pf Lb 1 hdr).claims.inp)
    _ (rtW R.pf.sqs) _ (A.runLog G).2 (R.tr G (A.run G)) nd1 (hlen _ w1.hpl) w1.hpre
    (by have h' := w1.hcnt; rw [← w1.hrd] at h'; exact h')
  -- the two openings' geometries
  have hg0 : (rxPs base Lb din dblk dout 0).gX = rkAt ogEp Rr 1 := by
    show (base 0).gX = _
    rw [hgX0, hRr]
  have hP1 : rxPs base Lb din dblk dout 1 = rxSet (base 1) (dblk 0) := rxPs_blk _ _ _ _ _ 0 hLb1
  have hg1 : (rxPs base Lb din dblk dout 1).gX = rkR13 (pXk 0).rows (R.pf.off 0 + 2) := by
    rw [hP1]
    exact hgX1
  -- the windows
  have h01 : R.pf.off 1 = R.pf.off 0 + (R.pf.part 0).len := R.pf.off_succ 0 hi0
  have hle0 : R.pf.off 0 + (R.pf.part 0).pre ≤ R.pf.off 0 + (R.pf.part 0).oX := by
    simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hle1 : R.pf.off 0 + (R.pf.part 0).pre ≤ R.pf.off 1 + (R.pf.part 1).oX := by
    rw [h01]
    simp only [RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hlt0 : 1 < R.pf.off 0 + (R.pf.part 0).oX := by
    simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have hlt1 : R.pf.off 0 + 2 < R.pf.off 1 + (R.pf.part 1).oX := by
    rw [h01]
    simp only [RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  -- every reading, every slot window
  intro hdr core ch rs hrd k q hq
  have habs0 := (ssh_rd_absAt key domain _ mIn (R.pf.off 0 + 5) _ G _ hdr core ch rs hrd (I.hgt _) k q hq 1
    (by omega)).trans (ssh_absAt_take (R.tr G (A.run G)) _ 1 hlt0).symm
  have habs1 := (ssh_rd_absAt key domain _ mIn (R.pf.off 0 + 5) _ G _ hdr core ch rs hrd (I.hgt _) k q hq
    (R.pf.off 0 + 2) (by omega)).trans (ssh_absAt_take (R.tr G (A.run G)) _ (R.pf.off 0 + 2) hlt1).symm
  refine ⟨fun z hz => ?_, fun z hz => ?_⟩
  · -- `.inp`: checked by part 0's closing opening
    rw [hinc] at hz
    have hz0 : z ∈ rkPend (rxAcc (vdWin Vi) Wout Pk R.pf Lb) 0 ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oX))
        ++ (rxAcc (vdWin Vi) Wout Pk R.pf Lb 0
          ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oX))).claims.inp := by
      show z ∈ [] ++ (rsAccInc (vdWin Vi (((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oX)).take
          (R.pf.off 0 + (R.pf.part 0).pre))) (R.pf.off 0 + 5)
        (((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).oX)).take (R.pf.off 0 + (R.pf.part 0).pre))).claims.inp
      rw [List.take_take, min_eq_left hle0, hp0]
      exact List.mem_append_right _ hz
    have hv := s0 z hz0
    rw [wrOSem_ebEp tag Lq h64 key domain hs hL U _ Rr hg0] at hv
    show claimSem U Rr 8 256 (epUxV tag Lq h64 key domain hs hL Rr
      (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 _)) z = _
    rw [epUxV_view, ebUxW_hdr tag Lq h64 key domain hs hL abRdIn 11 1 Rr (2 ^ 11) _ _ _ habs0]
    exact hv
  · -- `.out`: stage IN-C's claims on `B_in`, pending on part 1's closing opening
    rw [hinc] at hz
    have hz1 : z ∈ rkPend (rxAcc (vdWin Vi) Wout Pk R.pf Lb) 1 ((R.tr G (A.run G)).take (R.pf.off 1 + (R.pf.part 1).oX))
        ++ (rxAcc (vdWin Vi) Wout Pk R.pf Lb 1
          ((R.tr G (A.run G)).take (R.pf.off 1 + (R.pf.part 1).oX))).claims.inp := by
      apply List.mem_append_left
      show z ∈ (rsAccInc (vdWin Vi (((R.tr G (A.run G)).take (R.pf.off 1 + (R.pf.part 1).oX)).take
          (R.pf.off 0 + (R.pf.part 0).pre))) (R.pf.off 0 + 5)
        (((R.tr G (A.run G)).take (R.pf.off 1 + (R.pf.part 1).oX)).take (R.pf.off 0 + (R.pf.part 0).pre))).claims.out
      rw [List.take_take, min_eq_left hle1, hp0]
      exact hz
    have hv := s1 z hz1
    rw [wrOSem_rkR13 tag Lq h64 key domain hs hL U _ (pXk 0).rows (R.pf.off 0 + 2) hg1] at hv
    show claimSem U (pXk 0).rows 14 256 (bxUxV tag Lq h64 (pXk 0).rows (R.pf.off 0 + 2)
      (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (A.runLog G).2 _)) z = _
    rw [bxUxV_view tag Lq h64 key domain hs hL, UxW_hdr tag Lq h64 key domain hs hL 16 (R.pf.off 0 + 2) _ (2 ^ 16) _ _ _
      habs1]
    exact hv

end Run

end ZK60.ProtocolClassify
