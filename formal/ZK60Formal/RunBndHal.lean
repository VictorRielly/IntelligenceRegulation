/-
D63 lane L56 (2026-11-10), part 2: **the slots' alive conclusion on the classify run for the new block schedule**
(lane L50's `ra_hal_sl`, re-proved for `blockSchedXB`; the repair of finding L54-1 at the run).

* `RaTermAtB`: lane L50's `RaTermAt` with the slot polynomial `F` also given the header's roots and cuts (`hdrX`) of
  the run's transcript before the block's roots: every root the run absorbed before the block, the block's input
  boundary root (in the previous part's frame) and its output boundary root (in its own frame) among them;
* `ra_blk_hdrX`: at a block's reading of the run, the header's roots and cuts of the run's transcript are those of the
  reading's header (the transcript extends the header's trace);
* **`ra_hal_slB`**: `hal_slots`'s conclusion `(rtKsl … D hD).Al n lg τ` on an accepted run, when every block part's
  slots are the new schedule `blockSchedXB (Pk k) (off (k + 1) + 5) absOf (F k)` with `RaTermAtB`, and the two stage
  parts' slots are alive (named: `hS0`, `hS1`). Lane L50's proof, with lane L56's `ra_blk_slots_aliveB`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunBndSched
import ZK60Formal.RunAliveHal

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape)

/-! ## The block-level fact at a block's reading of a transcript -/

section AtB

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Every slot's terminal identity at every reading of block `P` (at `hdrLen`) on the transcript `τ`, for the new
schedule**: whenever the block's slot phase accepted after a header `hdr` (`SlotsAcc`) and `τ` is the trace of the
block's operations followed by operations that fit, every slot's final value is the slot polynomial `F` (over the
tables extracted from the log `lg` at the core's roots, and the roots and cuts the header of `τ` shows) at its
point. -/
def RaTermAtB (U : K) (key : Option Dig) (domain : List UInt8) (P : Block.BlockParams) (hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8))
    (F : Block.Cuts3 L → Block.RootsO → Block.HdrX L → (j : ℕ) → Block.Seen →
      (Fin ((Block.slotShape P j).1 + (Block.slotShape P j).2.1) → K) → K)
    (G : QB L → Dig) (lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
    (T : List Op), Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc → (∀ op ∈ T, op.len ≤ L) →
    τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T) →
    ∀ j r, rs[j]? = some r → r.fin.toK U = F (Block.cuts3 absOf lg (Block.rootsOf core)) (Block.rootsOf core)
      (Block.hdrX absOf lg hdrLen τ) j (Block.seenOf bga rs j) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U)

/-- **At a block's reading of a transcript, the transcript's header data is the reading's header's.** -/
theorem ra_blk_hdrX (key : Option Dig) (domain : List UInt8) (P : Block.BlockParams) (hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8)) (G : QB L → Dig) (lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
    (T : List Op) (hsa : Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc)
    (htr : τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T)) :
    Block.hdrX absOf lg hdrLen τ = Block.hdrX absOf lg hdrLen (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) := by
  rw [htr]
  exact Block.hdrX_allOps absOf lg (liftH G) _ P hdr core T hdrLen hsa.1

end AtB

/-! ## `hal_slots`'s conclusion for the new schedule -/

section HalB

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {Hdr : Type} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq) (hL64 : Lq < 2 ^ 64)
  (Lb : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **`hal_slots`'s conclusion on the classify run, for the new block schedule.** On an accepted run, if every block
part's slots are the schedule over the extracted tables and the header's roots and cuts (`hslB`:
`blockSchedXB (Pk k) (off (k + 1) + 5) absOf (F k)`) and every block's slots meet their terminal identities at the
block's reading of the run (`hterm`, `RaTermAtB`), and the two stage parts' slots are alive (`hS0`, `hS1`), the slots'
kind is alive at the end of the run's transcript (lane L50's `ra_hal_sl`, with `ra_blk_slots_aliveB`). -/
theorem ra_hal_slB (hU : U ^ 2 = algebraMap GF K 7) (hL81 : 81 ≤ Lq)
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom) (absOf : QB Lq → Option (List UInt8))
    (F : (k : ℕ) → Block.Cuts3 Lq → Block.RootsO → Block.HdrX Lq → (j : ℕ) → Block.Seen →
      (Fin ((Block.slotShape (Pk k) j).1 + (Block.slotShape (Pk k) j).2.1) → K) → K)
    (hslB : ∀ k, k < Lb → D.sls (k + 1) = Block.blockSchedXB (Pk k) (R.pf.off (k + 1) + 5) absOf (F k))
    (n : ℕ) (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hterm : ∀ k, k < Lb → RaTermAtB U key domain (Pk k) (R.pf.off (k + 1) + 5) absOf (F k) G lg (R.tr G (s, segs)))
    (hS0 : allSt W1 (slotSubs U (slotsAt (D.sls 0) lg)) (R.tr G (s, segs)))
    (hS1 : allSt W1 (slotSubs U (slotsAt (D.sls (Lb + 1)) lg)) (R.tr G (s, segs))) :
    (rtKsl key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD).Al n lg (R.tr G (s, segs)) := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have h64' : Lq < 18446744073709551616 := by
    have h := hL64
    norm_num at h
    exact h
  have hgeomB : ∀ k j, j < (Pk k).geom.slots.length → 1 ≤ (Block.slotShape (Pk k) j).2.2
      ∧ (Block.slotShape (Pk k) j).2.2 < gP ∧ 56 + 16 * ((Block.slotShape (Pk k) j).2.2 + 1) ≤ Lq
      ∧ 55 + 16 * Block.slotTerms (Pk k) j ≤ Lq := by
    intro k j hj
    obtain ⟨h1, h2, h3⟩ := (bp k).hgeomL j hj
    refine ⟨h1, ?_, h2, h3⟩
    show (Block.slotShape (Pk k) j).2.2 < 18446744069414584321
    omega
  intro i _
  by_cases hi : i < R.pf.parts.length
  · rw [ra_ksl_cs key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD i hi]
    rcases i with _ | k
    · exact hS0
    · by_cases hk : k < Lb
      · obtain ⟨hdr, core, bga, rs, acc, T, hsa, hT, htr⟩ := ra_blk_acc Pk sgeom check paths digest bRows bLogN
          bndCheck bndOpen R hv G s segs hE (k + 1) k _
          (ra_blk_seg Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
            R cx0 pin pout bp wXk gXk mXk hσ k hk) (bp k) (hgeo k)
        have hterm' := hterm k hk hdr core bga rs acc T hsa hT htr
        rw [ra_blk_hdrX key domain (Pk k) _ absOf G lg _ hdr core bga rs acc T hsa htr] at hterm'
        rw [hslB k hk, htr]
        exact ra_blk_slots_aliveB U hU key domain hs hL hL64 hL81 (Pk k) _ absOf (F k) (hgeomB k) (bp k).hgt G lg hdr
          core bga rs acc hsa hterm' T hT
      · have hk' : k = Lb := by omega
        rw [hk']
        exact hS1
  · rw [ra_ksl_cs_out key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD i hi]
    intro j c hc
    simp at hc

end HalB

end ZK60.ProtocolClassify
