/-
D63 lane L34 (2026-11-09), part 6: **the schedule contracts of stage IN-C and stage OUT-C** (L29's executable stage
verifiers), and **the classify run's schedule** at L29's run verifier `classifyRunV` with D12a blocks.

A stage has the same schedule as a block: its frame, its head (`A`, `M`, the head's challenges, `H`: L15's
`stageRootOps`), its slots, then `M`, `A`, `H` and the commitment it closes (the input token endpoint for IN-C, `B_out`
for OUT-C). Here:

* `rt_stageHeader_ok`, `rt_rdCloses_ok`, **`rt_decodeStage_spec`**: what L29's `decodeStage` guarantees: the header's
  bytes (so the binding and start tag can be read off the segment), the core's counts (`CoreShape`), each closed
  commitment's group count; `rtStageOf`, **`rtStageOf_decode`**: a stage segment read off its bytes alone;
* `rt_part_of`: a part's contract from its pieces (the transcript at `M`'s window, the single phase's counts and fit,
  the tail); `rt_stagePre`: a stage's single phase has the shape's counts and fits;
* `rt_stSlotsLoop_tr`, **`rt_incSlots_tr`**, **`rt_outcSlots_tr`**: an accepted stage slot phase leaves the transcript
  at `runOps` of the head's and the slots' operations (IN-C: for ANY context, since the operations depend on the
  schedule's draws alone);
* `RtInc`, `rtIncSeg`, **`rtInc_holds`**: STAGE IN-C'S CONTRACT; `RtOutc`, `rtOutcSeg`, **`rtOutc_holds`**: STAGE
  OUT-C'S;
* `RtSeg.Holds.mono`; **`rtRunClassify`**: the classify run's schedule (`RtRun`) at `classifyRunV` with the executable
  stages and D12a blocks, from the run header's operations and the three kinds of contracts' premises. With it,
  `RtRun.acceptU` and `RtRun.acceptU_part` hold at `classifyProtocolUExec`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunTrParts

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV

/-! ## What `decodeStage` guarantees -/

/-- The stage segment's header, read: `magic ‖ binding ‖ u64 ‖ u64 ‖ start ‖ rest`. -/
theorem rt_stageHeader_ok {s : StageGeom} {bnd st : Dig} {bs rest : List UInt8} {u : Unit}
    (h : rdStageHeader s bnd st bs = .ok (u, rest)) :
    ∃ mg a b : List UInt8, mg.length = 8 ∧ a.length = 8 ∧ b.length = 8
      ∧ bs = mg ++ (bnd.toList ++ (a ++ (b ++ (st.toList ++ rest)))) := by
  obtain ⟨mg, m1, e1, e2⟩ := Block.Rd.bnd_ok h
  obtain ⟨f1, hl1⟩ := Block.rdBytes_ok e1
  obtain ⟨u1, m1', e3, e4⟩ := Block.Rd.bnd_ok e2
  obtain ⟨-, hm1⟩ := Block.Rd.guard_ok e3
  subst hm1
  obtain ⟨b, m2, e5, e6⟩ := Block.Rd.bnd_ok e4
  have f2 := Block.rdDig_ok e5
  obtain ⟨u2, m2', e7, e8⟩ := Block.Rd.bnd_ok e6
  obtain ⟨hb, hm2⟩ := Block.Rd.guard_ok e7
  subst hm2
  obtain ⟨l', m3, e9, e10⟩ := Block.Rd.bnd_ok e8
  obtain ⟨k', m4, e11, e12⟩ := Block.Rd.bnd_ok e10
  have f3 := Block.rdU64_ok e9
  have f4 := Block.rdU64_ok e11
  obtain ⟨u3, m4', e13, e14⟩ := Block.Rd.bnd_ok e12
  obtain ⟨-, hm4⟩ := Block.Rd.guard_ok e13
  subst hm4
  obtain ⟨st', m5, e15, e16⟩ := Block.Rd.bnd_ok e14
  have f5 := Block.rdDig_ok e15
  obtain ⟨hst, hm5⟩ := Block.Rd.guard_ok e16
  subst hm5
  refine ⟨mg, le64 l', le64 k', hl1, length_le64 _, length_le64 _, ?_⟩
  rw [f1, f2, not_not.mp hb, f3, f4, f5, not_not.mp hst]

/-- Each closed commitment's opening has its declared group count. -/
theorem rt_rdCloses_ok : ∀ (cs : List (Block.Dim × ℕ × ℕ)) (os : List Block.OpeningZk) (bs rest : List UInt8),
    rdCloses cs bs = .ok (os, rest) →
      List.Forall₂ (fun (c : Block.Dim × ℕ × ℕ) (o : Block.OpeningZk) => o.groupVecs.length = c.2.1) cs os
  | [], os, bs, rest, h => by
    have h' : Block.Rd.ret ([] : List Block.OpeningZk) bs = .ok (os, rest) := h
    obtain ⟨e1, -⟩ := Block.Rd.ret_ok h'
    rw [e1]
    exact List.Forall₂.nil
  | c :: cs, os, bs, rest, h => by
    have h' : Block.Rd.bnd (Block.rdHiding c.1 c.2.1 c.2.2)
        (fun o => Block.Rd.bnd (rdCloses cs) fun os => Block.Rd.ret (o :: os)) bs = .ok (os, rest) := h
    obtain ⟨o, m1, e1, e2⟩ := Block.Rd.bnd_ok h'
    obtain ⟨os', m2, e3, e4⟩ := Block.Rd.bnd_ok e2
    obtain ⟨e5, -⟩ := Block.Rd.ret_ok e4
    rw [e5]
    exact List.Forall₂.cons (Block.rdHiding_ok e1).2.2.1 (rt_rdCloses_ok cs os' m1 m2 e3)

/-- **What an accepted `decodeStage` guarantees**: the header's bytes carry the verifier's binding and start tag; the
core has the geometry's counts; each closed commitment's opening has its declared group count. -/
theorem rt_decodeStage_spec {s : StageGeom} (hgt : s.g.slots.length = s.g.terms.length) {bnd st : Dig}
    {bytes : List UInt8} {seg : StageSeg} {e : Dig} (h : decodeStage s bnd st bytes = .ok (seg, e)) :
    (∃ mg a b rest : List UInt8, mg.length = 8 ∧ a.length = 8 ∧ b.length = 8
        ∧ bytes = mg ++ (bnd.toList ++ (a ++ (b ++ (st.toList ++ rest)))))
      ∧ Block.CoreShape s.g seg.core
      ∧ List.Forall₂ (fun (c : Block.Dim × ℕ × ℕ) (o : Block.OpeningZk) => o.groupVecs.length = c.2.1) s.closes
        seg.closes := by
  unfold decodeStage at h
  split at h
  · cases h
  · split at h
    · cases h
    · rename_i r rest hr
      split at h
      · cases h
      · cases h
        unfold rdStageBody at hr
        obtain ⟨u, m1, e1, e2⟩ := Block.Rd.bnd_ok hr
        obtain ⟨br, m2, e3, e4⟩ := Block.Rd.bnd_ok e2
        obtain ⟨c, m3, e5, e6⟩ := Block.Rd.bnd_ok e4
        obtain ⟨cl, m4, e7, e8⟩ := Block.Rd.bnd_ok e6
        obtain ⟨e', m5, e9, e10⟩ := Block.Rd.bnd_ok e8
        obtain ⟨hce, -⟩ := Block.Rd.ret_ok e10
        cases hce
        obtain ⟨mg, a, b, hmg, ha, hb, hbytes⟩ := rt_stageHeader_ok e1
        exact ⟨⟨mg, a, b, m1, hmg, ha, hb, hbytes⟩, (Block.rdCore_ok hgt e5).2.2, rt_rdCloses_ok _ _ _ _ e7⟩

/-- **A stage segment read off its bytes alone**: decoded against the binding and start tag its own header carries. -/
def rtStageOf (g : StageGeom) (bytes : List UInt8) : Option StageSeg :=
  match decodeStage g (rtBnd bytes) (rtStart bytes) bytes with
  | .ok r => some r.1
  | .error _ => none

/-- **The reading is the verifier's decoding** whenever `decodeStage` accepts the bytes. -/
theorem rtStageOf_decode {g : StageGeom} {bnd st : Dig} {bytes : List UInt8} {seg : StageSeg} {e : Dig}
    (hh : ∃ mg a b rest : List UInt8, mg.length = 8 ∧ a.length = 8 ∧ b.length = 8
      ∧ bytes = mg ++ (bnd.toList ++ (a ++ (b ++ (st.toList ++ rest)))))
    (h : decodeStage g bnd st bytes = .ok (seg, e)) : rtStageOf g bytes = some seg := by
  obtain ⟨mg, a, b, rest, hmg, ha, hb, hbytes⟩ := hh
  have hr : rtBnd bytes = bnd ∧ rtStart bytes = st := by
    rw [hbytes]
    exact rt_hdr_read mg a b rest bnd st hmg ha hb
  simp only [rtStageOf, hr.1, hr.2, h]

theorem rt_closes_head (c : Block.Dim × ℕ × ℕ) (cls : List Block.OpeningZk) (d : Block.OpeningZk)
    (h : List.Forall₂ (fun (c : Block.Dim × ℕ × ℕ) (o : Block.OpeningZk) => o.groupVecs.length = c.2.1) [c] cls) :
    (cls.headD d).groupVecs.length = c.2.1 := by
  cases h with
  | cons hab _ => exact hab

/-! ## A part's contract from its pieces -/

/-- **A part's contract from its pieces**: the transcript at `M`'s window is `runOps` of the single phase's operations;
that phase has the profile's counts and fits; the openings have the profile's group counts; the tail moved the
transcript by its steps and fits. -/
theorem rt_part_of (Lq : ℕ) (H : HIn → Dig) (t tM t' : Tr) (p : RtPart) (d : RtData) (hpre : tM = runOps H t d.pre)
    (hlen : d.pre.length = p.pre) (hsq : sqN d.pre = p.preSq) (hfitpre : ∀ op ∈ d.pre, op.len ≤ Lq)
    (hgA : d.aO.groupVecs.length = p.gA) (hgH : d.hO.groupVecs.length = p.gH) (hgX : d.xO.groupVecs.length = p.gX)
    (htail : t' = runOps H tM (stpsOps (mStps p.S d.mo ++ (pcsStps p.wA p.mA d.aO
      ++ (pcsStps p.wH p.mH d.hO ++ pcsStps p.wX p.mX d.xO)))))
    (hfit : ∀ op ∈ stpsOps (mStps p.S d.mo ++ (pcsStps p.wA p.mA d.aO
      ++ (pcsStps p.wH p.mH d.hO ++ pcsStps p.wX p.mX d.xO))), op.len ≤ Lq) :
    t' = runOps H t (stpsOps (rtPartStps p d)) ∧ RtPartOk Lq p d := by
  refine ⟨?_, hlen, hsq, hgA, hgH, hgX, fun op hop => ?_⟩
  · rw [rtPartStps_ops, runOps_append, ← hpre]
    exact htail
  · rw [rtPartStps_ops] at hop
    rcases List.mem_append.mp hop with h | h
    · exact hfitpre op h
    · exact hfit op h

theorem rt_sqN_stageRoot (P : Block.BlockParams) (core : Block.Core) (m : ℕ) :
    sqN (StageFS.stageRootOps P core m) = m := by
  simp [StageFS.stageRootOps, Block.rootOpsA, Block.rootOpsH, Block.drawOps, sqN_append, sqN_replicate, sqN]

/-- **A stage's single phase** (a frame, the head, the slots) has the shape's counts, and fits `Lq ≥ 2^20`. -/
theorem rt_stagePre (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (P : Block.BlockParams) (core : Block.Core) (m : ℕ)
    (frame : List Op) (hsh : Block.CoreShape P.geom core) (hgt : P.geom.slots.length = P.geom.terms.length)
    (hgeomL : ∀ j, j < P.geom.slots.length → 56 + 16 * ((Block.slotShape P j).2.2 + 1) ≤ Lq
      ∧ 55 + 16 * Block.slotTerms P j ≤ Lq) (hframe : ∀ op ∈ frame, op.len ≤ Lq) :
    (frame ++ (StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots)).length
        = frame.length + (7 + m) + shapeLen P 0 P.geom.slots
      ∧ sqN (frame ++ (StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots))
        = sqN frame + m + shapeSq P 0 P.geom.slots
      ∧ ∀ op ∈ frame ++ (StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots), op.len ≤ Lq := by
  obtain ⟨hfl0, hfs0⟩ := slots_shape P ([], core) hsh hgt
  have hfl : fullLen P 0 core.slots = shapeLen P 0 P.geom.slots := hfl0
  have hfs : fullSq P 0 core.slots = shapeSq P 0 P.geom.slots := hfs0
  refine ⟨?_, ?_, fun op hop => ?_⟩
  · rw [List.length_append, List.length_append, StageFS.stageRootOps_length, fullOps_length, hfl]
    omega
  · rw [sqN_append, sqN_append, rt_sqN_stageRoot, fullOps_sq, hfs]
    omega
  · have hh : ∀ op' ∈ frame ++ StageFS.stageRootOps P core m, op'.len ≤ Lq := by
      intro op' hop'
      rcases List.mem_append.mp hop' with h | h
      · exact hframe op' h
      · exact StageFS.stageRootOps_len P core m Lq (by omega) op' h
    have hall := slots_fit P (frame ++ StageFS.stageRootOps P core m, core) Lq (by omega) hh hsh hgt hgeomL
    rcases List.mem_append.mp hop with h | h
    · exact hall op (List.mem_append_left _ (List.mem_append_left _ (List.mem_append_left _ h)))
    · rcases List.mem_append.mp h with h' | h'
      · exact hall op (List.mem_append_left _ (List.mem_append_left _ (List.mem_append_right _ h')))
      · exact hall op (List.mem_append_right _ h')

/-! ## The stages' slot phases -/

/-- The slots' operations depend on the schedule's draws alone. -/
def rtFullOps (draws : ℕ → ℕ) : ℕ → List Block.SlotProof → List Op
  | _, [] => []
  | j, sp :: sps =>
    (Block.drawOps (draws j) ++ [.absorb Block.labPbSlot (le64 (UInt64.ofNat j)), .squeeze,
      .absorb Block.labPbScalar ([sp.scalar].flatMap Fp2.toBytes)]) ++ scOps sp.rounds ++ [Block.termOp sp]
      ++ rtFullOps draws (j + 1) sps

theorem rt_fullOps (P : Block.BlockParams) : ∀ (j : ℕ) (sps : List Block.SlotProof),
    Block.fullOps P j sps = rtFullOps P.draws j sps
  | _, [] => rfl
  | j, sp :: sps => by
    show Block.slotPreOps P j sp ++ scOps sp.rounds ++ [Block.termOp sp] ++ Block.fullOps P (j + 1) sps = _
    rw [rt_fullOps P (j + 1) sps]
    rfl

/-- **An accepted stage slot loop leaves the transcript at `runOps` of the slots' operations** (L29's `stSlotsLoop`:
by `stSlotsLoop_strip` its transcript is L9's `slotsLoop`'s, and L22's `slotsLoop_tr`). -/
theorem rt_stSlotsLoop_tr (H : HIn → Dig) (P : Block.BlockParams) (elog : ℕ → ℕ) (b g a : Fp2)
    (sps : List Block.SlotProof) (recs : List Block.SlotRec) (acc : Block.Acc) (t t' : Tr)
    (h : stSlotsLoop H P elog b g a [] 0 sps {} t = .ok (recs, acc, t'))
    (hd : ∀ i, i < sps.length → 1 ≤ (Block.slotShape P i).2.2) : t' = runOps H t (Block.fullOps P 0 sps) := by
  have h1 := stSlotsLoop_strip H P elog b g a [] 0 sps {} ({} : Block.Acc).claims t
  have h2 : (fun x : List Block.SlotRec × Block.Acc × Tr => (x.1, accStrip x.2.1, x.2.2)) <$>
      Block.slotsLoop H P b g a [] 0 sps {} t = .ok (recs, accStrip acc, t') :=
    h1.symm.trans (congrArg (fun y : Except String (List Block.SlotRec × Block.Acc × Tr) =>
      (fun x : List Block.SlotRec × Block.Acc × Tr => (x.1, accStrip x.2.1, x.2.2)) <$> y) h)
  obtain ⟨⟨recs', acc', t''⟩, hl, hy⟩ := (StageV.map_ok_iff _ _ _).mp h2
  have ht : t'' = t' := congrArg (fun x : List Block.SlotRec × (List Fp2 × List Fp2 × List Block.MaskFunctional
    × List Block.MaskFunctional) × Tr => x.2.2) hy
  rw [← ht]
  exact slotsLoop_tr H P b g a sps [] 0 {} t recs' acc' t'' (fun i hi => by simpa using hd i hi) hl

/-- **Stage IN-C's accepted slot phase** (`IncV.slots`: `A`, `M`, the head's challenges, `H`, the four slots) leaves the
transcript at `runOps` of the head's and the slots' operations, written at ANY context `cx0` (the operations depend on
the context only through `define`, which the transcript's schedule does not read). -/
theorem rt_incSlots_tr (H : HIn → Dig) (V : IncV) (core : Block.Core) (t : Tr) (recs : List Block.SlotRec)
    (acc : Block.Acc) (t4 : Tr) (h : V.slots H core t = .ok (recs, acc, t4))
    (hd : ∀ cx i, i < core.slots.length → 1 ≤ (Block.slotShape (V.bp cx) i).2.2) (cx0 : IncCtx) :
    t4 = runOps H t (StageFS.stageRootOps (V.bp cx0) core (incHeadDraws V.pub)
      ++ Block.fullOps (V.bp cx0) 0 core.slots) := by
  have h1 : t4 = runOps H (V.slotT H core t)
      (Block.fullOps (V.bp (incCtx V.pub (V.headCh H core t).1)) 0 core.slots) :=
    rt_stSlotsLoop_tr H _ _ _ _ _ core.slots recs acc _ t4 h (hd _)
  have h2 : V.slotT H core t = runOps H t (StageFS.stageRootOps (V.bp cx0) core (incHeadDraws V.pub)) :=
    (StageFS.runOps_stageRootOps H (V.bp cx0) core (incHeadDraws V.pub) t).symm
  rw [h1, h2, rt_fullOps (V.bp (incCtx V.pub (V.headCh H core t).1)), rt_fullOps (V.bp cx0), runOps_append]
  rfl

/-- **Stage OUT-C's accepted slot phase** (L15's `stageSlots` with two head challenges) leaves the transcript at
`runOps` of the head's and the slots' operations. -/
theorem rt_outcSlots_tr (H : HIn → Dig) (V : OutcV) (core : Block.Core) (t : Tr) (ch : List Fp2)
    (recs : List Block.SlotRec) (acc : Block.Acc) (t4 : Tr)
    (h : StageFS.stageSlots H V.bp 2 OutcV.bga core t = .ok (ch, recs, acc, t4))
    (hd : ∀ i, i < core.slots.length → 1 ≤ (Block.slotShape V.bp i).2.2) :
    t4 = runOps H t (StageFS.stageRootOps V.bp core 2 ++ Block.fullOps V.bp 0 core.slots) := by
  rw [StageFS.stageSlots_eq] at h
  split at h
  · rename_i r hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, hr⟩ := h
    rw [hr] at hloop
    have h3 := slotsLoop_tr H V.bp _ _ _ core.slots [] 0 {} _ recs acc t4 (fun i hi => by simpa using hd i hi) hloop
    rw [h3, runOps_append]
  · cases h

/-! ## Stage IN-C -/

section Stages

variable {Hdr : Type}

/-- Stage IN-C's frame as operations: `pb-run-stage` (`0`), `pb-run-block` (the embedding's digest), `absorb_root("B")`
of `B_in`. -/
def rtIncFrame (dg root : Dig) (rows logN : ℕ) : List Op :=
  [.absorb labRunStage (le64 0), .absorb labRunBlock dg.toList, .absorb labB root.toList,
    .absorb Block.labRows (le64 (UInt64.ofNat rows)), .absorb Block.labLogCols (le64 (UInt64.ofNat logN))]

theorem rtIncFrame_fit (dg root : Dig) (rows logN Lq : ℕ) (hL : 2 ^ 20 ≤ Lq) :
    ∀ op ∈ rtIncFrame dg root rows logN, op.len ≤ Lq := by
  intro op hop
  simp only [rtIncFrame, List.mem_cons, List.mem_nil_iff, or_false] at hop
  rcases hop with rfl | rfl | rfl | rfl | rfl <;>
    simp only [Op.len, labRunStage, labRunBlock, labB, Block.labRows, Block.labLogCols, length_le64, List.length_cons,
      List.length_nil, List.Vector.toList_length] <;> omega

/-- **What the verifier absorbs in stage IN-C**, from its decoded segment (the single phase written at the context
`cx0`). -/
def rtIncData (V : IncV) (cx0 : IncCtx) (seg : StageSeg) : RtData :=
  ⟨rtIncFrame V.pub.embDigest (seg.bRoot.getD zeroDig) V.geo.bRows V.geo.bLogN
      ++ (StageFS.stageRootOps (V.bp cx0) seg.core (incHeadDraws V.pub) ++ Block.fullOps (V.bp cx0) 0 seg.core.slots),
    seg.core.maskOpen, seg.core.aOpen, seg.core.hOpen, seg.closes.headD IncV.ozk0⟩

/-- Stage IN-C's data read off the statement and the segment's bytes. -/
def rtIncRd (V : Hdr → IncV) (G : Hdr → StageGeom) (cx0 : IncCtx) (s : ClsStmt Hdr) (bytes : List UInt8) : RtData :=
  match rtStageOf (G s.hdr) bytes with
  | some seg => rtIncData (V s.hdr) cx0 seg
  | none => RtData.nil

/-- **Stage IN-C as a scheduled part.** -/
def rtIncSeg (V : Hdr → IncV) (G : Hdr → StageGeom) (cx0 : IncCtx) (p : RtPart) : RtSeg (ClsStmt Hdr) :=
  ⟨inSeg (incStageV V G), p, rtIncRd V G cx0⟩

/-- **What the schedule needs of stage IN-C's verifier** at the profile's counts `p`: `M`'s field and the three
openings accepting only when `PcsOk` holds; the segment's core geometry the verifier's; one closed commitment (the
input endpoint) of `p.gX` groups; the slots' geometry; the claims' counts on an accepted slot phase (`hcnt`); and the
stage's counts the profile's for every header (`hpre`, `hpsq`, `hgA`, `hgH`, and the widths). -/
structure RtInc (Lq : ℕ) (V : Hdr → IncV) (G : Hdr → StageGeom) (p : RtPart) where
  tag : MTag
  nA : ℕ
  nH : ℕ
  nIn : ℕ
  nOut : ℕ
  pA : RtPcs (fun (hd : Hdr) H root cl o t => (V hd).pcsVerify H .a root cl o t)
  pH : RtPcs (fun (hd : Hdr) H root cl o t => (V hd).pcsVerify H .h root cl o t)
  pX : RtPcs (fun (hd : Hdr) H root cl o t => (V hd).epVerify H root cl o t)
  hPm : ∀ hd, (V hd).maskVerify = maskField tag p.S
  hgeo : ∀ hd, (G hd).g = (V hd).geom
  hgt : ∀ hd, (V hd).geom.slots.length = (V hd).geom.terms.length
  hgeomL : ∀ hd cx j, j < (V hd).geom.slots.length → 1 ≤ (Block.slotShape ((V hd).bp cx) j).2.2
    ∧ 56 + 16 * ((Block.slotShape ((V hd).bp cx) j).2.2 + 1) ≤ Lq ∧ 55 + 16 * Block.slotTerms ((V hd).bp cx) j ≤ Lq
  hclose : ∀ hd, ∃ c, (G hd).closes = [c] ∧ c.2.1 = p.gX
  hcnt : ∀ (hd : Hdr) (H : HIn → Dig) (core : Block.Core) (t : Tr) (recs : List Block.SlotRec) (acc : Block.Acc)
    (t4 : Tr), (V hd).slots H core t = .ok (recs, acc, t4) →
      acc.claims.a.length = nA ∧ (acc.claims.h ++ [(V hd).lay.logupSumClaim]).length = nH
        ∧ acc.claims.inp.length = nIn ∧ acc.claims.out.length = nOut
  hpre : ∀ hd cx, 12 + incHeadDraws (V hd).pub + shapeLen ((V hd).bp cx) 0 (V hd).geom.slots = p.pre
  hpsq : ∀ hd cx, incHeadDraws (V hd).pub + shapeSq ((V hd).bp cx) 0 (V hd).geom.slots = p.preSq
  hgA : ∀ hd, (V hd).geom.aGroups = p.gA
  hgH : ∀ hd, (V hd).geom.hGroups = p.gH
  hwA : nA + pA.rows = p.wA
  hmA : pA.m = p.mA
  hwH : nH + pH.rows = p.wH
  hmH : pH.m = p.mH
  hwX : nIn + pX.rows = p.wX
  hmX : pX.m = p.mX

/-- **STAGE IN-C'S CONTRACT.** Whenever stage IN-C's framed step accepts, the transcript moved by exactly its steps
(the frame, `A`, `M`, the head's challenges, `H`, the slots, then `M`, `A`, `H` and the input endpoint's opening) on
the data read off the bytes; that data has the profile's counts and fits; and the carry handed on holds the `nOut`
claims left pending on `B_in`. -/
theorem rtInc_holds (V : Hdr → IncV) (G : Hdr → StageGeom) (cx0 : IncCtx) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (p : RtPart)
    (I : RtInc Lq V G p) :
    (rtIncSeg V G cx0 p).Holds Lq (fun _ => True) (fun cr => cr.pending.length = I.nOut) := by
  intro H s bnd bytes cr t cr' t' _ hstep
  obtain ⟨seg, e, broot, pending, hdec, hver, -, hcr⟩ :=
    (inSegExec_step_ok_iff V G H s bnd bytes cr t cr' t').mp hstep
  obtain ⟨-, -, -, -, -, hbr, recs, acc, t4, t5, t6, t7, hs, -, h5, -, h6, -, h7, -, h8, hpend⟩ :=
    (incVerify_ok_iff H (V s.hdr) s.inRoot seg t pending broot t').mp hver
  have hgt' : (G s.hdr).g.slots.length = (G s.hdr).g.terms.length := by
    rw [I.hgeo s.hdr]
    exact I.hgt s.hdr
  obtain ⟨hhdr, hshape0, hclz⟩ := rt_decodeStage_spec hgt' hdec
  have hshape : Block.CoreShape (V s.hdr).geom seg.core := by
    rw [I.hgeo s.hdr] at hshape0
    exact hshape0
  have hrd : rtIncRd V G cx0 s bytes = rtIncData (V s.hdr) cx0 seg := by
    simp only [rtIncRd, rtStageOf_decode hhdr hdec]
  obtain ⟨c, hc, hcg⟩ := I.hclose s.hdr
  have hgX : (seg.closes.headD IncV.ozk0).groupVecs.length = p.gX := by
    rw [hc] at hclz
    rw [rt_closes_head c seg.closes IncV.ozk0 hclz, hcg]
  have hd1 : ∀ cx i, i < seg.core.slots.length → 1 ≤ (Block.slotShape ((V s.hdr).bp cx) i).2.2 :=
    fun cx i hi => (I.hgeomL s.hdr cx i (by rw [← hshape.1]; exact hi)).1
  have ht4 := rt_incSlots_tr H (V s.hdr) seg.core _ recs acc t4 hs hd1 cx0
  obtain ⟨hcA, hcH, hcI, hcO⟩ := I.hcnt s.hdr H seg.core _ recs acc t4 hs
  rw [I.hPm s.hdr] at h5
  obtain ⟨etail, hfit⟩ := rt_tail Lq hL20 H I.tag p.S seg.core.maskRoot _ seg.core.maskOpen I.pA I.pH I.pX s.hdr s.hdr
    s.hdr seg.core.aRoot seg.core.hRoot s.inRoot acc.claims.a (acc.claims.h ++ [(V s.hdr).lay.logupSumClaim])
    acc.claims.inp seg.core.aOpen seg.core.hOpen (seg.closes.headD IncV.ozk0) I.nA I.nH I.nIn hcA hcH hcI t4 t5 t6 t7
    t' h5 h6 h7 h8
  rw [I.hwA, I.hmA, I.hwH, I.hmH, I.hwX, I.hmX] at etail hfit
  have hfr : (V s.hdr).frame H broot t = runOps H t (rtIncFrame (V s.hdr).pub.embDigest (seg.bRoot.getD zeroDig)
      (V s.hdr).geo.bRows (V s.hdr).geo.bLogN) := by
    rw [hbr]
    rfl
  obtain ⟨hl, hq, hf⟩ := rt_stagePre Lq hL20 ((V s.hdr).bp cx0) seg.core (incHeadDraws (V s.hdr).pub)
    (rtIncFrame (V s.hdr).pub.embDigest (seg.bRoot.getD zeroDig) (V s.hdr).geo.bRows (V s.hdr).geo.bLogN) hshape
    (I.hgt s.hdr) (fun j hj => (I.hgeomL s.hdr cx0 j hj).2)
    (rtIncFrame_fit (V s.hdr).pub.embDigest (seg.bRoot.getD zeroDig) (V s.hdr).geo.bRows (V s.hdr).geo.bLogN Lq hL20)
  have hpre : t4 = runOps H t (rtIncData (V s.hdr) cx0 seg).pre := by
    rw [ht4, hfr, ← runOps_append]
    rfl
  have hlen : (rtIncData (V s.hdr) cx0 seg).pre.length = p.pre := by
    rw [← I.hpre s.hdr cx0]
    show (rtIncFrame (V s.hdr).pub.embDigest (seg.bRoot.getD zeroDig) (V s.hdr).geo.bRows (V s.hdr).geo.bLogN
      ++ (StageFS.stageRootOps ((V s.hdr).bp cx0) seg.core (incHeadDraws (V s.hdr).pub)
        ++ Block.fullOps ((V s.hdr).bp cx0) 0 seg.core.slots)).length = _
    rw [hl]
    show 5 + (7 + incHeadDraws (V s.hdr).pub) + shapeLen ((V s.hdr).bp cx0) 0 (V s.hdr).geom.slots = _
    omega
  have hsq : sqN (rtIncData (V s.hdr) cx0 seg).pre = p.preSq := by
    rw [← I.hpsq s.hdr cx0]
    show sqN (rtIncFrame (V s.hdr).pub.embDigest (seg.bRoot.getD zeroDig) (V s.hdr).geo.bRows (V s.hdr).geo.bLogN
      ++ (StageFS.stageRootOps ((V s.hdr).bp cx0) seg.core (incHeadDraws (V s.hdr).pub)
        ++ Block.fullOps ((V s.hdr).bp cx0) 0 seg.core.slots)) = _
    rw [hq]
    show 0 + incHeadDraws (V s.hdr).pub + shapeSq ((V s.hdr).bp cx0) 0 (V s.hdr).geom.slots = _
    omega
  have hpo := rt_part_of Lq H t t4 t' p (rtIncData (V s.hdr) cx0 seg) hpre hlen hsq hf
    (hshape.2.2.2.2.2.2.2.1.trans (I.hgA s.hdr)) (hshape.2.2.2.2.2.2.2.2.1.trans (I.hgH s.hdr)) hgX etail hfit
  show t' = runOps H t (stpsOps (rtPartStps p (rtIncRd V G cx0 s bytes))) ∧ RtPartOk Lq p (rtIncRd V G cx0 s bytes)
    ∧ cr'.pending.length = I.nOut
  rw [hrd]
  refine ⟨hpo.1, hpo.2, ?_⟩
  rw [hcr]
  show pending.length = I.nOut
  rw [hpend]
  exact hcO

/-! ## Stage OUT-C -/

/-- Stage OUT-C's frame as operations: `pb-run-stage` (`L + 1`), `pb-run-block` (the margin vector's digest). -/
def rtOutcFrame (idx : ℕ) (dg : Dig) : List Op :=
  [.absorb labRunStage (le64 (UInt64.ofNat idx)), .absorb labRunBlock dg.toList]

theorem rtOutcFrame_fit (idx : ℕ) (dg : Dig) (Lq : ℕ) (hL : 2 ^ 20 ≤ Lq) :
    ∀ op ∈ rtOutcFrame idx dg, op.len ≤ Lq := by
  intro op hop
  simp only [rtOutcFrame, List.mem_cons, List.mem_nil_iff, or_false] at hop
  rcases hop with rfl | rfl <;>
    simp only [Op.len, labRunStage, labRunBlock, length_le64, List.length_cons, List.length_nil,
      List.Vector.toList_length] <;> omega

/-- **What the verifier absorbs in stage OUT-C**, from its decoded segment. -/
def rtOutcData (V : OutcV) (seg : StageSeg) : RtData :=
  ⟨rtOutcFrame V.stageIndex V.pub.wDigest
      ++ (StageFS.stageRootOps V.bp seg.core 2 ++ Block.fullOps V.bp 0 seg.core.slots),
    seg.core.maskOpen, seg.core.aOpen, seg.core.hOpen, seg.closes.headD IncV.ozk0⟩

/-- Stage OUT-C's data read off the statement and the segment's bytes. -/
def rtOutcRd (V : Hdr → ℕ → OutcV) (G : Hdr → StageGeom) (s : ClsStmt Hdr) (bytes : List UInt8) : RtData :=
  match rtStageOf (G s.hdr) bytes with
  | some seg => rtOutcData (V s.hdr s.verdict) seg
  | none => RtData.nil

/-- **Stage OUT-C as a scheduled part.** -/
def rtOutcSeg (V : Hdr → ℕ → OutcV) (G : Hdr → StageGeom) (p : RtPart) : RtSeg (ClsStmt Hdr) :=
  ⟨outSeg (outcStageV V G), p, rtOutcRd V G⟩

/-- **What the schedule needs of stage OUT-C's verifier** at the profile's counts `p`, for every header and verdict:
as `RtInc`, with `B_out`'s opening as the closing one and no outgoing claim. -/
structure RtOutc (Lq : ℕ) (V : Hdr → ℕ → OutcV) (G : Hdr → StageGeom) (p : RtPart) where
  tag : MTag
  nA : ℕ
  nH : ℕ
  nIn : ℕ
  pA : RtPcs (fun (i : Hdr × ℕ) H root cl o t => (V i.1 i.2).pcsVerify H .a root cl o t)
  pH : RtPcs (fun (i : Hdr × ℕ) H root cl o t => (V i.1 i.2).pcsVerify H .h root cl o t)
  pX : RtPcs (fun (i : Hdr × ℕ) H root cl o t => (V i.1 i.2).bVerify H root cl o t)
  hPm : ∀ hd v, (V hd v).maskVerify = maskField tag p.S
  hgeo : ∀ hd v, (G hd).g = (V hd v).geom
  hgt : ∀ hd v, (V hd v).geom.slots.length = (V hd v).geom.terms.length
  hgeomL : ∀ hd v j, j < (V hd v).geom.slots.length → 1 ≤ (Block.slotShape (V hd v).bp j).2.2
    ∧ 56 + 16 * ((Block.slotShape (V hd v).bp j).2.2 + 1) ≤ Lq ∧ 55 + 16 * Block.slotTerms (V hd v).bp j ≤ Lq
  hclose : ∀ hd, ∃ c, (G hd).closes = [c] ∧ c.2.1 = p.gX
  hcnt : ∀ (hd : Hdr) (v : ℕ) (H : HIn → Dig) (core : Block.Core) (t : Tr) (ch : List Fp2)
    (recs : List Block.SlotRec) (acc : Block.Acc) (t4 : Tr),
    StageFS.stageSlots H (V hd v).bp 2 OutcV.bga core t = .ok (ch, recs, acc, t4) →
      acc.claims.a.length = nA ∧ (acc.claims.h ++ [(V hd v).lay.logupSumClaim]).length = nH
        ∧ acc.claims.inp.length = nIn
  hpre : ∀ hd v, 11 + shapeLen (V hd v).bp 0 (V hd v).geom.slots = p.pre
  hpsq : ∀ hd v, 2 + shapeSq (V hd v).bp 0 (V hd v).geom.slots = p.preSq
  hgA : ∀ hd v, (V hd v).geom.aGroups = p.gA
  hgH : ∀ hd v, (V hd v).geom.hGroups = p.gH
  hwA : nA + pA.rows = p.wA
  hmA : pA.m = p.mA
  hwH : nH + pH.rows = p.wH
  hmH : pH.m = p.mH
  hmX : pX.m = p.mX

/-- **STAGE OUT-C'S CONTRACT.** Whenever stage OUT-C's framed step accepts from a carry with `pend` pending claims
(with `pend + nIn` claims and the rows making the profile's width `p.wX`), the transcript moved by exactly its steps
(the frame, `A`, `M`, `γ`, `α`, `H`, the slots, then `M`, `A`, `H` and `B_out`'s opening) on the data read off the
bytes, and that data has the profile's counts and fits. -/
theorem rtOutc_holds (V : Hdr → ℕ → OutcV) (G : Hdr → StageGeom) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (p : RtPart)
    (O : RtOutc Lq V G p) (pend : ℕ) (hwX : pend + O.nIn + O.pX.rows = p.wX) :
    (rtOutcSeg V G p).Holds Lq (fun cr => cr.pending.length = pend) (fun _ => True) := by
  intro H s bnd bytes cr t cr' t' hinv hstep
  obtain ⟨seg, e, hdec, hver, -, -⟩ := (outSegExec_step_ok_iff V G H s bnd bytes cr t cr' t').mp hstep
  obtain ⟨-, -, -, -, -, -, ch, recs, acc, t4, t5, t6, t7, hs, -, h5, -, -, h6, -, h7, -, h8⟩ :=
    (outcVerify_ok_iff H (V s.hdr s.verdict) cr.root cr.pending seg t t').mp hver
  have hgt' : (G s.hdr).g.slots.length = (G s.hdr).g.terms.length := by
    rw [O.hgeo s.hdr s.verdict]
    exact O.hgt s.hdr s.verdict
  obtain ⟨hhdr, hshape0, hclz⟩ := rt_decodeStage_spec hgt' hdec
  have hshape : Block.CoreShape (V s.hdr s.verdict).geom seg.core := by
    rw [O.hgeo s.hdr s.verdict] at hshape0
    exact hshape0
  have hrd : rtOutcRd V G s bytes = rtOutcData (V s.hdr s.verdict) seg := by
    simp only [rtOutcRd, rtStageOf_decode hhdr hdec]
  obtain ⟨c, hc, hcg⟩ := O.hclose s.hdr
  have hgX : (seg.closes.headD IncV.ozk0).groupVecs.length = p.gX := by
    rw [hc] at hclz
    rw [rt_closes_head c seg.closes IncV.ozk0 hclz, hcg]
  have hd1 : ∀ i, i < seg.core.slots.length → 1 ≤ (Block.slotShape (V s.hdr s.verdict).bp i).2.2 :=
    fun i hi => (O.hgeomL s.hdr s.verdict i (by rw [← hshape.1]; exact hi)).1
  have ht4 := rt_outcSlots_tr H (V s.hdr s.verdict) seg.core _ ch recs acc t4 hs hd1
  obtain ⟨hcA, hcH, hcI⟩ := O.hcnt s.hdr s.verdict H seg.core _ ch recs acc t4 hs
  rw [O.hPm s.hdr s.verdict] at h5
  have hinv' : cr.pending.length = pend := hinv
  have hcX : (cr.pending ++ acc.claims.inp).length = pend + O.nIn := by
    rw [List.length_append, hinv', hcI]
  obtain ⟨etail, hfit⟩ := rt_tail Lq hL20 H O.tag p.S seg.core.maskRoot _ seg.core.maskOpen O.pA O.pH O.pX
    (s.hdr, s.verdict) (s.hdr, s.verdict) (s.hdr, s.verdict) seg.core.aRoot seg.core.hRoot cr.root acc.claims.a
    (acc.claims.h ++ [(V s.hdr s.verdict).lay.logupSumClaim]) (cr.pending ++ acc.claims.inp) seg.core.aOpen
    seg.core.hOpen (seg.closes.headD IncV.ozk0) O.nA O.nH (pend + O.nIn) hcA hcH hcX t4 t5 t6 t7 t' h5 h6 h7 h8
  rw [O.hwA, O.hmA, O.hwH, O.hmH, hwX, O.hmX] at etail hfit
  obtain ⟨hl, hq, hf⟩ := rt_stagePre Lq hL20 (V s.hdr s.verdict).bp seg.core 2
    (rtOutcFrame (V s.hdr s.verdict).stageIndex (V s.hdr s.verdict).pub.wDigest) hshape (O.hgt s.hdr s.verdict)
    (fun j hj => (O.hgeomL s.hdr s.verdict j hj).2)
    (rtOutcFrame_fit (V s.hdr s.verdict).stageIndex (V s.hdr s.verdict).pub.wDigest Lq hL20)
  have hfr : (V s.hdr s.verdict).frame H t
      = runOps H t (rtOutcFrame (V s.hdr s.verdict).stageIndex (V s.hdr s.verdict).pub.wDigest) := rfl
  have hpre : t4 = runOps H t (rtOutcData (V s.hdr s.verdict) seg).pre := by
    rw [ht4, hfr, ← runOps_append]
    rfl
  have hlen : (rtOutcData (V s.hdr s.verdict) seg).pre.length = p.pre := by
    rw [← O.hpre s.hdr s.verdict]
    show (rtOutcFrame (V s.hdr s.verdict).stageIndex (V s.hdr s.verdict).pub.wDigest
      ++ (StageFS.stageRootOps (V s.hdr s.verdict).bp seg.core 2
        ++ Block.fullOps (V s.hdr s.verdict).bp 0 seg.core.slots)).length = _
    rw [hl]
    show 2 + (7 + 2) + shapeLen (V s.hdr s.verdict).bp 0 (V s.hdr s.verdict).geom.slots = _
    omega
  have hsq : sqN (rtOutcData (V s.hdr s.verdict) seg).pre = p.preSq := by
    rw [← O.hpsq s.hdr s.verdict]
    show sqN (rtOutcFrame (V s.hdr s.verdict).stageIndex (V s.hdr s.verdict).pub.wDigest
      ++ (StageFS.stageRootOps (V s.hdr s.verdict).bp seg.core 2
        ++ Block.fullOps (V s.hdr s.verdict).bp 0 seg.core.slots)) = _
    rw [hq]
    show 0 + 2 + shapeSq (V s.hdr s.verdict).bp 0 (V s.hdr s.verdict).geom.slots = _
    omega
  have hpo := rt_part_of Lq H t t4 t' p (rtOutcData (V s.hdr s.verdict) seg) hpre hlen hsq hf
    (hshape.2.2.2.2.2.2.2.1.trans (O.hgA s.hdr s.verdict)) (hshape.2.2.2.2.2.2.2.2.1.trans (O.hgH s.hdr s.verdict))
    hgX etail hfit
  show t' = runOps H t (stpsOps (rtPartStps p (rtOutcRd V G s bytes))) ∧ RtPartOk Lq p (rtOutcRd V G s bytes) ∧ True
  rw [hrd]
  exact ⟨hpo.1, hpo.2, trivial⟩

end Stages

/-! ## The classify run's schedule -/

/-- A contract with a weaker requirement on the carry in and a weaker promise on the carry out. -/
theorem RtSeg.Holds.mono {St : Type} {σ : RtSeg St} {Lq : ℕ} {I₁ I₁' I₂ I₂' : Carry → Prop}
    (h : σ.Holds Lq I₁ I₁') (hin : ∀ cr, I₂ cr → I₁ cr) (hout : ∀ cr, I₁' cr → I₂' cr) : σ.Holds Lq I₂ I₂' :=
  fun H s bnd bytes cr t cr' t' hi hstep =>
    ⟨(h H s bnd bytes cr t cr' t' (hin cr hi) hstep).1, (h H s bnd bytes cr t cr' t' (hin cr hi) hstep).2.1,
      hout cr' (h H s bnd bytes cr t cr' t' (hin cr hi) hstep).2.2⟩

section Classify

variable {Hdr : Type} (L : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **THE CLASSIFY RUN'S SCHEDULE** at L29's run verifier with the executable stages and D12a blocks
(`classifyRunV … (d12aBlockProf …) …`), on the keyed transcript of `domain`. From:
* the run header's operations `hdr` (`hstart`, `hhdr`);
* stage IN-C's premises (`I`), each block's (`bp k`, its boundary opening `pX k`, its segment geometry `hgeo`, `hgX`),
  stage OUT-C's (`O`);
* the pending claims' counts before each part (`pend`): `pend 1` those stage IN-C leaves on `B_in`, `pend (k + 2)`
  those block `k` leaves on its boundary.
The parts' profile counts are `pin`, `pblk k` (as the block's contract gives them) and `pout`. -/
noncomputable def rtRunClassify (key : Option Dig) (domain : List UInt8) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (hdr : ClsStmt Hdr → List Op) (hdrLen hdrSq : ℕ)
    (hstart : ∀ (H : HIn → Dig) (s : ClsStmt Hdr), start H s = runOps H (Tr.newKeyed H domain key) (hdr s))
    (hhdr : ∀ s : ClsStmt Hdr, preA s.hdr = .ok () → preB s.hdr = .ok () →
      (hdr s).length = hdrLen ∧ sqN (hdr s) = hdrSq ∧ ∀ op ∈ hdr s, op.len ≤ Lq)
    (cx0 : IncCtx) (pin pout : RtPart) (I : RtInc Lq inc incG pin) (O : RtOutc Lq outc outcG pout) (pend : ℕ → ℕ)
    (hI : I.nOut = pend 1) (bp : ∀ k, RtBlk Lq (Pk k))
    (pX : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t)) (gX : ℕ → ℕ)
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom) (hgX : ∀ k s, (sgeom s k).incoming.1 = gX k)
    (hbp : ∀ k, (bp k).nOut = pend (k + 2)) (hO : pend (L + 1) + O.nIn + O.pX.rows = pout.wX) :
    RtRun (classifyRunV L preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq :=
  rtRunOf (classifyRunV L preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq hdr hdrLen
    hdrSq hstart hhdr (rtIncSeg inc incG cx0 pin)
    (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
      (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
        (pend (k + 1) + (bp k).nIn + (pX k).rows) (gX k) (pX k).m))
    (rtOutcSeg outc outcG pout) rfl (fun _ => rfl) rfl
    (fun i cr => i = 0 ∨ L + 1 < i ∨ cr.pending.length = pend i) (Or.inl rfl)
    ((rtInc_holds inc incG cx0 Lq hL20 pin I).mono (fun _ _ => trivial)
      (fun _ h => Or.inr (Or.inr (h.trans hI))))
    (fun k hk => (rtBlock_holds Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k Lq hL20 (bp k) (pX k)
        (gX k) (pend (k + 1)) (hgeo k) (hgX k)).mono
      (fun _ h => by
        rcases h with h | h | h
        · omega
        · have hk' : k < L := hk
          omega
        · exact h)
      (fun _ h => Or.inr (Or.inr (h.trans (hbp k)))))
    ((rtOutc_holds outc outcG Lq hL20 pout O (pend (L + 1)) hO).mono
      (fun _ h => by
        rcases h with h | h | h
        · omega
        · omega
        · exact h)
      (fun _ _ => Or.inr (Or.inl (Nat.lt_succ_self _))))

end Classify

end ZK60.ProtocolClassify
