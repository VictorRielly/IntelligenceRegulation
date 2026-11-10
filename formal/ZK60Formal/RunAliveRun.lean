/-
D63 lane L50 (2026-11-10), part 4: **the classify run's transcript, read at a block part, is the block's verifier trace
followed by the rest of the run** (L43's `rk_blk_run`, carried to the whole slot phase), and the block's slots, define
draws and LogUp run alive at the END of the run's transcript.

* **`ra_blk_acc`**: on an accepted run (`classifyVerifyE` accepts), at a part `i` that is D12a block `k`: with the header
  `hdr` := the run's operations before the part followed by the block's five-absorb frame (`off i + 5` operations), the
  block's slot phase accepted on the code's transcript after `hdr` (`SlotsAcc` at `hdrLen = off i + 5`, the core the one
  the verifier decoded), and the run's transcript IS the trace of the block's operations (`allOps`) followed by the
  rest of the run's operations (each within `Lq` bytes);
* **`ra_blk_run_sl`**, **`ra_blk_run_def`**, **`ra_blk_run_lk`**: therefore L16's slots (`blockSchedX` at
  `off i + 5`), L21's define draws (`defSq` at `off i + 5`) and LogUp (`lkSq` at `off i + 5`) of block `k` are alive at
  the end of the run's transcript, given, at the block's reading of the run, each slot's terminal identity, each define
  draw's polynomial vanishing at the drawn challenges, and LogUp's helpers at `β, γ, α`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunAliveDef
import ZK60Formal.RunKindsDataBlk

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape)

section Run

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **THE RUN'S TRANSCRIPT AT A BLOCK PART IS THE BLOCK'S VERIFIER TRACE AND MORE.** On an accepted run, at a part `i`
that is D12a block `k`: the block's slot phase accepted after the header `hdr` (the run's operations before the part and
the block's frame; `off i + 5` of them), and the run's transcript is the code's trace of the block's operations followed
by the rest of the run's operations, each within `Lq` bytes. -/
theorem ra_blk_acc (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i k : ℕ) (p : RtPart)
    (hσi : R.σs[i]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k p))
    (bp : RtBlk Lq (Pk k)) (hgeo : ∀ s, (sgeom s k).g = (Pk k).geom) :
    ∃ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
      (T : List Op),
      Block.SlotsAcc key domain (Pk k) (R.pf.off i + 5) G (hdr, core) bga rs acc
      ∧ (∀ op ∈ T, op.len ≤ Lq)
      ∧ R.tr G (s, segs)
        = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps (Pk k) (hdr, core) ++ T) := by
  obtain ⟨cr, sg, root, ic, oc, t₂, t', bga, rs, acc, tM, tA, tH, -, hcan, -, hshape, hrdi, hpi, hroot, hbs, -⟩ :=
    rk_blk_run Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv G s segs hE i k p hσi bp hgeo
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hgd : sg.bRoot.getD zeroDig = root := by rw [hroot]; rfl
  have hfitAll := rtS_fit Lq R.pf R.rd (s, segs)
  have e1 := rtPre_facts Lq R.pf (R.rd (s, segs)) hgood i
  have e2 := rtPartsStps_drop R.pf.parts (R.rd (s, segs)).2 i p _ hpi hrdi
  obtain ⟨T, hops⟩ : ∃ T, stpsOps (rtS Lq R.pf R.rd (s, segs))
      = Block.allOps (Pk k) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
          ++ rtBlockFrame k (digest s k) root (bRows (k + 1)) (bLogN (k + 1)), sg.core) ++ T := by
    refine ⟨stpsOps (mStps p.S sg.core.maskOpen ++ (pcsStps p.wA p.mA sg.core.aOpen ++ (pcsStps p.wH p.mH
      sg.core.hOpen ++ pcsStps p.wX p.mX sg.inOpen)) ++ rtPartsStps (R.pf.parts.drop (i + 1))
        ((R.rd (s, segs)).2.drop (i + 1))), ?_⟩
    rw [rtS_good Lq R.pf R.rd (s, segs) hgood, e1.1, e2]
    simp only [rtPartStps, rtBlockData, stpsOps_append, stpsOps_opsStps, Block.allOps, hgd, List.append_assoc]
  refine ⟨stpsOps (rtPre R.pf (R.rd (s, segs)) i) ++ rtBlockFrame k (digest s k) root (bRows (k + 1)) (bLogN (k + 1)),
    sg.core, bga, rs, acc, T, ⟨?_, ?_, hcan, hshape, tM, ?_⟩, ?_, ?_⟩
  · show (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtBlockFrame k (digest s k) root (bRows (k + 1)) (bLogN (k + 1))).length = R.pf.off i + 5
    rw [List.length_append, e1.2.1]
    rfl
  · intro op hop
    exact hfitAll op (by rw [hops]; exact List.mem_append_left _ (List.mem_append_left _
      (List.mem_append_left _ hop)))
  · show Block.blockSlots (liftH G) (Pk k) sg.core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
      (stpsOps (rtPre R.pf (R.rd (s, segs)) i) ++ rtBlockFrame k (digest s k) root (bRows (k + 1)) (bLogN (k + 1))))
      = .ok (bga, rs, acc, tM)
    rw [runOps_append]
    exact hbs
  · intro op hop
    exact hfitAll op (by rw [hops]; exact List.mem_append_right _ hop)
  · show opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtS Lq R.pf R.rd (s, segs))) = _
    rw [hops]

end Run

end ZK60.ProtocolClassify
