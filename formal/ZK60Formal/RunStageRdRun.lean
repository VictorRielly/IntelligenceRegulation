/-
D63 lane L45 (2026-11-10), part 2: **non-vacuity of `rkData` at the run's two stages: the stages' readers return what
the run verifier itself accumulated** (finding L43-6; L43's `rk_blk_run` for the blocks).

`rkData`'s readers see only the run's transcript. The stage readers (`RunStageRd.lean`) read it with the stage's
verifier data; L29's stage verifier families are indexed by the statement's header (`inc hd`) and, for stage OUT-C, by
the statement's PUBLIC verdict (`outc hd v`: OUT-C's `define` reads the verdict, `outcDefine`, so its functionals do).
So the readers here take the verifier as a function `W` of the transcript prefix, and the theorems ask that `W` read
off the run's transcript be the statement's verifier (`hW`): at the real IN-C (`fun _ => incVAt …`, constant) this is
`rfl`; at the real OUT-C it asks that the verdict be read off the run header (finding L45-1).

* `rkAccInc`, `rkAccOutc`: the stages' readers at their absolute positions on the run's transcript (after the frame:
  five absorbs for IN-C, two for OUT-C), on the header cut at the stage's single phase's end;
* **`rs_inc_run`**: on an accepted run, at a part `i` of the schedule that is stage IN-C (`rtIncSeg`): the segment read
  off the bytes alone (`rtStageOf`) is canonical, of the stage's shape, and is what the verifier decoded; the verifier
  ran IN-C's slot phase on the run's transcript before the part and the frame, accumulating `acc`, then checked `M`,
  `A`, `H` and the input endpoint on `acc`'s functionals and claims; and `rkAccInc` returns EXACTLY `acc` on every
  header that agrees with the run's transcript up to the slot phase's end;
* **`rs_outc_run`**: the same at stage OUT-C (`rtOutcSeg`), with `B_out` opened on the carry's pending claims followed by
  `acc.claims.inp`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStageRd

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX

/-! ## The stages' readers on the run's transcript -/

/-- **Stage IN-C's reader on the run's transcript**: `rsAccInc` of the verifier `W` reads off the header, from position
`a` (after the run's steps before the stage and the frame's five absorbs), on the header cut at `e` (the slot phase's
end). -/
def rkAccInc (W : List (TItem × Dig) → IncV) (a e : ℕ) (hdr : List (TItem × Dig)) : Block.Acc :=
  rsAccInc (W (hdr.take e)) a (hdr.take e)

/-- **Stage OUT-C's reader on the run's transcript**: `rsAccS` at the `BlockParams` of the verifier `W` reads off the
header, two head challenges, `define`'s history `(0, γ, α)`, from position `a` (after the frame's two absorbs). -/
def rkAccOutc (W : List (TItem × Dig) → OutcV) (a e : ℕ) (hdr : List (TItem × Dig)) : Block.Acc :=
  rsAccS (W (hdr.take e)).bp 2 OutcV.bga a (hdr.take e)

section Run

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}

/-- **AN ACCEPTED RUN, AT STAGE IN-C, AS THE RUN VERIFIER SAW IT** (non-vacuity of `rkData` at stage IN-C). -/
theorem rs_inc_run (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx)
    (hσi : R.σs[i]? = some (rtIncSeg inc incG cx0 p))
    (hgeo : (incG s.hdr).g = (inc s.hdr).geom)
    (hgt : (inc s.hdr).geom.slots.length = (inc s.hdr).geom.terms.length)
    (hd : ∀ cx k, k < (inc s.hdr).geom.slots.length → 1 ≤ (Block.slotShape ((inc s.hdr).bp cx) k).2.2)
    (W : List (TItem × Dig) → IncV) (hW : W ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) = inc s.hdr) :
    ∃ (seg : StageSeg) (root : Dig) (recs : List Block.SlotRec) (acc : Block.Acc) (t4 t5 t6 t7 t' : Tr),
      rtStageOf (incG s.hdr) (segs.getD i []) = some seg
      ∧ Block.CoreCanon seg.core ∧ Block.CoreShape (inc s.hdr).geom seg.core
      ∧ (∀ o ∈ seg.closes, Block.HidingCanon o)
      ∧ (R.rd (s, segs)).2[i]? = some (rtIncData (inc s.hdr) cx0 seg)
      ∧ R.pf.parts[i]? = some p
      ∧ seg.bRoot = some root
      ∧ (inc s.hdr).slots (liftH G) seg.core
          (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
            ++ rtIncFrame (inc s.hdr).pub.embDigest root (inc s.hdr).geo.bRows (inc s.hdr).geo.bLogN))
          = .ok (recs, acc, t4)
      ∧ (acc.fs ++ acc.hostFs).length = (inc s.hdr).lay.nFunctionals
      ∧ (inc s.hdr).maskVerify (liftH G) seg.core.maskRoot (acc.fs ++ acc.hostFs) seg.core.maskOpen t4 = .ok t5
      ∧ (inc s.hdr).pcsVerify (liftH G) .a seg.core.aRoot acc.claims.a seg.core.aOpen t5 = .ok t6
      ∧ (inc s.hdr).pcsVerify (liftH G) .h seg.core.hRoot (acc.claims.h ++ [(inc s.hdr).lay.logupSumClaim])
          seg.core.hOpen t6 = .ok t7
      ∧ (inc s.hdr).epVerify (liftH G) s.inRoot acc.claims.inp (seg.closes.headD IncV.ozk0) t7 = .ok t'
      ∧ ∀ hdr : List (TItem × Dig), hdr.take (R.pf.off i + p.pre) = (R.tr G (s, segs)).take (R.pf.off i + p.pre) →
          rkAccInc W (R.pf.off i + 5) (R.pf.off i + p.pre) hdr = acc := by
  obtain ⟨cr, cr', t, t'', -, ht, hstep, hrdi⟩ := R.accept_part (liftH G) s segs hE i _ hσi
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  obtain ⟨seg, e, broot, pending, hdec, hver, -, -⟩ :=
    (inSegExec_step_ok_iff inc incG (liftH G) s _ _ cr t cr' t'').mp hstep
  obtain ⟨-, -, -, -, -, hbr, recs, acc, t4, t5, t6, t7, hs, hnf, h5, -, h6, -, h7, -, h8, -⟩ :=
    (incVerify_ok_iff (liftH G) (inc s.hdr) s.inRoot seg t pending broot t'').mp hver
  have hgt' : (incG s.hdr).g.slots.length = (incG s.hdr).g.terms.length := by
    rw [hgeo]
    exact hgt
  obtain ⟨hhdr, hshape0, -⟩ := rt_decodeStage_spec hgt' hdec
  obtain ⟨hcanC, hcanX⟩ := rs_decodeStage_canon hgt' hdec
  have hshape : Block.CoreShape (inc s.hdr).geom seg.core := by
    rw [hgeo] at hshape0
    exact hshape0
  have hof : rtStageOf (incG s.hdr) (segs.getD i []) = some seg := rtStageOf_decode hhdr hdec
  have hrd : rtIncRd inc incG cx0 s (segs.getD i []) = rtIncData (inc s.hdr) cx0 seg := by
    simp only [rtIncRd, hof]
  have hrdi' : (R.rd (s, segs)).2[i]? = some (rtIncData (inc s.hdr) cx0 seg) := by
    rw [hrdi]
    exact congrArg some hrd
  have hpi : R.pf.parts[i]? = some p := by
    show (R.σs.map (fun σ => σ.p))[i]? = some p
    rw [List.getElem?_map, hσi]
    rfl
  have hgd : seg.bRoot.getD zeroDig = broot := by rw [hbr]; rfl
  have hfr : (inc s.hdr).frame (liftH G) broot t
      = runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
        ++ rtIncFrame (inc s.hdr).pub.embDigest broot (inc s.hdr).geo.bRows (inc s.hdr).geo.bLogN) := by
    rw [runOps_append, ← ht]
    rfl
  rw [hfr] at hs
  refine ⟨seg, broot, recs, acc, t4, t5, t6, t7, t'', hof, hcanC, hshape, hcanX, hrdi', hpi, hbr, hs, hnf, h5, h6, h7,
    h8, ?_⟩
  intro hdr hhdr'
  have hpd : RtPartOk Lq p (rtIncData (inc s.hdr) cx0 seg) := rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi'
  have hpre_eq : (rtIncData (inc s.hdr) cx0 seg).pre
      = rtIncFrame (inc s.hdr).pub.embDigest broot (inc s.hdr).geo.bRows (inc s.hdr).geo.bLogN
        ++ (StageFS.stageRootOps ((inc s.hdr).bp cx0) seg.core (incHeadDraws (inc s.hdr).pub)
          ++ Block.fullOps ((inc s.hdr).bp cx0) 0 seg.core.slots) := by
    show rtIncFrame (inc s.hdr).pub.embDigest (seg.bRoot.getD zeroDig) (inc s.hdr).geo.bRows (inc s.hdr).geo.bLogN
      ++ (StageFS.stageRootOps ((inc s.hdr).bp cx0) seg.core (incHeadDraws (inc s.hdr).pub)
        ++ Block.fullOps ((inc s.hdr).bp cx0) 0 seg.core.slots) = _
    rw [hgd]
  obtain ⟨tk, -, -, -, -⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtIncData (inc s.hdr) cx0 seg) hpi hrdi' (opsStps (rtIncData (inc s.hdr) cx0 seg).pre) _ rfl
  rw [stpsOps_opsStps, hpd.1, stpsOps_append, stpsOps_opsStps, hpre_eq] at tk
  have hlen : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hread := rs_accInc_trace (liftH G) (inc s.hdr) seg.core
    (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtIncFrame (inc s.hdr).pub.embDigest broot (inc s.hdr).geo.bRows (inc s.hdr).geo.bLogN)
    (Tr.newKeyed (liftH G) domain key) recs acc t4 cx0 hcanC.1 hshape.1 hd hs
  have hl5 : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtIncFrame (inc s.hdr).pub.embDigest broot (inc s.hdr).geo.bRows (inc s.hdr).geo.bLogN).length
        = R.pf.off i + 5 := by
    rw [List.length_append, hlen]
    rfl
  rw [hl5] at hread
  have hW' : W (hdr.take (R.pf.off i + p.pre)) = inc s.hdr := by
    rw [hhdr']
    exact hW
  unfold rkAccInc
  rw [hW', hhdr']
  show rsAccInc (inc s.hdr) (R.pf.off i + 5)
    ((rtTr key domain Lq R.pf R.rd G (s, segs)).take (R.pf.off i + p.pre)) = acc
  rw [tk, ← hread]
  simp only [List.append_assoc]

/-- **AN ACCEPTED RUN, AT STAGE OUT-C, AS THE RUN VERIFIER SAW IT** (non-vacuity of `rkData` at stage OUT-C): the
segment read off the bytes is canonical, of the stage's shape, and is what the verifier decoded; the verifier ran L15's
`stageSlots` on the run's transcript before the part and the frame, accumulating `acc`, checked `M`, `A`, `H` and
`B_out` (on the carry's pending claims followed by `acc.claims.inp`); `rkAccOutc` returns EXACTLY `acc`. -/
theorem rs_outc_run (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (hσi : R.σs[i]? = some (rtOutcSeg outc outcG p))
    (hgeo : (outcG s.hdr).g = (outc s.hdr s.verdict).geom)
    (hgt : (outc s.hdr s.verdict).geom.slots.length = (outc s.hdr s.verdict).geom.terms.length)
    (hd : ∀ k, k < (outc s.hdr s.verdict).geom.slots.length →
      1 ≤ (Block.slotShape (outc s.hdr s.verdict).bp k).2.2)
    (W : List (TItem × Dig) → OutcV)
    (hW : W ((R.tr G (s, segs)).take (R.pf.off i + p.pre)) = outc s.hdr s.verdict) :
    ∃ (cr : Carry) (seg : StageSeg) (ch : List Fp2) (recs : List Block.SlotRec) (acc : Block.Acc)
      (t4 t5 t6 t7 t' : Tr),
      R.Inv i cr
      ∧ rtStageOf (outcG s.hdr) (segs.getD i []) = some seg
      ∧ Block.CoreCanon seg.core ∧ Block.CoreShape (outc s.hdr s.verdict).geom seg.core
      ∧ (∀ o ∈ seg.closes, Block.HidingCanon o)
      ∧ (R.rd (s, segs)).2[i]? = some (rtOutcData (outc s.hdr s.verdict) seg)
      ∧ R.pf.parts[i]? = some p
      ∧ StageFS.stageSlots (liftH G) (outc s.hdr s.verdict).bp 2 OutcV.bga seg.core
          (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
            ++ rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest))
          = .ok (ch, recs, acc, t4)
      ∧ (acc.fs ++ acc.hostFs).length = (outc s.hdr s.verdict).lay.nFunctionals
      ∧ (outc s.hdr s.verdict).maskVerify (liftH G) seg.core.maskRoot (acc.fs ++ acc.hostFs) seg.core.maskOpen t4
          = .ok t5
      ∧ (outc s.hdr s.verdict).pcsVerify (liftH G) .a seg.core.aRoot acc.claims.a seg.core.aOpen t5 = .ok t6
      ∧ (outc s.hdr s.verdict).pcsVerify (liftH G) .h seg.core.hRoot
          (acc.claims.h ++ [(outc s.hdr s.verdict).lay.logupSumClaim]) seg.core.hOpen t6 = .ok t7
      ∧ (outc s.hdr s.verdict).bVerify (liftH G) cr.root (cr.pending ++ acc.claims.inp) (seg.closes.headD IncV.ozk0)
          t7 = .ok t'
      ∧ ∀ hdr : List (TItem × Dig), hdr.take (R.pf.off i + p.pre) = (R.tr G (s, segs)).take (R.pf.off i + p.pre) →
          rkAccOutc W (R.pf.off i + 2) (R.pf.off i + p.pre) hdr = acc := by
  obtain ⟨cr, cr', t, t'', hinv, ht, hstep, hrdi⟩ := R.accept_part (liftH G) s segs hE i _ hσi
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  obtain ⟨seg, e, hdec, hver, -, -⟩ := (outSegExec_step_ok_iff outc outcG (liftH G) s _ _ cr t cr' t'').mp hstep
  obtain ⟨-, -, -, -, -, -, ch, recs, acc, t4, t5, t6, t7, hs, hnf, h5, -, -, h6, -, h7, -, h8⟩ :=
    (outcVerify_ok_iff (liftH G) (outc s.hdr s.verdict) cr.root cr.pending seg t t'').mp hver
  have hgt' : (outcG s.hdr).g.slots.length = (outcG s.hdr).g.terms.length := by
    rw [hgeo]
    exact hgt
  obtain ⟨hhdr, hshape0, -⟩ := rt_decodeStage_spec hgt' hdec
  obtain ⟨hcanC, hcanX⟩ := rs_decodeStage_canon hgt' hdec
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
  refine ⟨cr, seg, ch, recs, acc, t4, t5, t6, t7, t'', hinv, hof, hcanC, hshape, hcanX, hrdi', hpi, hs, hnf, h5, h6, h7,
    h8, ?_⟩
  intro hdr hhdr'
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
  have hW' : W (hdr.take (R.pf.off i + p.pre)) = outc s.hdr s.verdict := by
    rw [hhdr']
    exact hW
  unfold rkAccOutc
  rw [hW', hhdr']
  show rsAccS (outc s.hdr s.verdict).bp 2 OutcV.bga (R.pf.off i + 2)
    ((rtTr key domain Lq R.pf R.rd G (s, segs)).take (R.pf.off i + p.pre)) = acc
  rw [tk, ← hread]
  show rsAccS (outc s.hdr s.verdict).bp 2 OutcV.bga (R.pf.off i + 2)
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
        ++ (rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest
          ++ (StageFS.stageRootOps (outc s.hdr s.verdict).bp seg.core 2
            ++ Block.fullOps (outc s.hdr s.verdict).bp 0 seg.core.slots))))
    = _
  simp only [List.append_assoc]

end Run

end ZK60.ProtocolClassify
