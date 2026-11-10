/-
D63 lane L45 (2026-11-10), part 1: **the stages' accumulator readers** (finding L43-6), on the verifier's own accepting
trace, as lane L31's block reader is (`tAccRd_trace`).

L43's `rkData` takes one accumulator reader per part; the blocks' is L31's `tAccRd`. The two token stages run the same
slot step (`slotStep`) under a different head, so their readers are written here:

* stage OUT-C (`OutcV.verify`): lane L15's `stageSlots` (the head's `A`, `M`, `m` challenges, `H`, then L9's
  `slotsLoop`); its reader `rsAccS` reads the head with L15's `tRootS` and the slots with L31's `tAccLoop`;
  **`rs_accS_trace`**: on the verifier's own accepting trace it returns the verifier's accumulator;
* stage IN-C (`IncV.slots`): the head's `β, γ, α, r_emb`, then L29's `stSlotsLoop`, each slot at its own IO width
  (`atLog P (elog s)`), with the slots' `BlockParams` read from the head's challenges (`incCtx`); its loop reader
  `rsLoopE` (L31's `tAccLoop` with the slot's width), **`rs_stSlotsLoop_read`**; the stage's reader `rsAccInc`,
  **`rs_accInc_trace`**;
* helpers for the run (`RunStageRdRun.lean`): `rs_rdCloses_canon`, **`rs_decodeStage_canon`** (a decoded stage segment
  is canonical: lane L34's `rt_decodeStage_spec` exports only its shape), **`rs_absAt_opTrace`** (the bytes the trace
  of an operation list absorbs at a position).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunKindsDataBlk

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV

/-! ## Stage IN-C's slot loop, slot by slot at each slot's IO width -/

/-- **Stage IN-C's slot-loop reader**: L31's `tAccLoop`, with slot `j` read and accumulated at its own IO width
(`atLog P (elog j)`, L29's `stSlotsLoop`). -/
def rsLoopE (P : Block.BlockParams) (elog : ℕ → ℕ) (b g a : Fp2) :
    List (List Fp2) → ℕ → ℕ → Block.Acc → Block.TRd Block.Acc
  | _, _, 0, acc => Block.TRd.ret acc
  | ds, j, m + 1, acc => Block.TRd.bnd (Block.tSlotFull (atLog P (elog j)) j) fun v =>
      rsLoopE P elog b g a (ds ++ [v.pre.1]) (j + 1) m (Block.accStep (atLog P (elog j)) ⟨b, g, a, ds⟩ j acc v)

/-- **An accepting stage IN-C slot loop's accumulator is the reader's**, on the loop's own trace (canonical slot
proofs, slot degrees at least `1`): L31's `slotsLoop_read`, slot by slot at the slot's IO width. -/
theorem rs_stSlotsLoop_read (H : HIn → Dig) (P : Block.BlockParams) (elog : ℕ → ℕ) (b g a : Fp2) :
    ∀ (sps : List Block.SlotProof) (recs : List Block.SlotRec) (j : ℕ) (acc : Block.Acc) (t : Tr)
      (recs' : List Block.SlotRec) (acc' : Block.Acc) (t' : Tr) (rest : List (TItem × Dig)),
      (∀ sp ∈ sps, Block.SlotCanon sp) →
      (∀ i, i < sps.length → 1 ≤ (Block.slotShape P (j + i)).2.2) →
      stSlotsLoop H P elog b g a recs j sps acc t = .ok (recs', acc', t') →
      rsLoopE P elog b g a (recs.map Block.SlotRec.draws) j sps.length acc
          (opTrace H t (Block.fullOps P j sps) ++ rest)
        = some (acc', rest)
  | [], recs, j, acc, t, recs', acc', t', rest, _, _, h => by
    simp only [stSlotsLoop, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, rfl, -⟩ := h
    rfl
  | sp0 :: sps, recs, j, acc, t, recs', acc', t', rest, hcan, hd1, h => by
    simp only [stSlotsLoop] at h
    split at h
    · cases h
    · rename_i r0 acc0 t0 hstep
      have hd0 : 1 ≤ (Block.slotShape (atLog P (elog j)) j).2.2 := by
        show 1 ≤ (Block.slotShape P j).2.2
        simpa using hd1 0 (by simp)
      obtain ⟨hlen0, hdr0, hacc0⟩ :=
        Block.slotStep_read H (atLog P (elog j)) j _ sp0 acc t r0 acc0 t0 (hcan sp0 List.mem_cons_self) hd0 hstep
      have hacc0' : Block.accStep (atLog P (elog j)) ⟨b, g, a, recs.map Block.SlotRec.draws⟩ j acc
          (Block.slotReadOf H (atLog P (elog j)) t j sp0) = acc0 := hacc0
      obtain ⟨df, -, -, hsv, ht0, -, -, -, -⟩ :=
        Block.slotStep_ok H (atLog P (elog j)) j _ sp0 acc t r0 acc0 t0 hstep
      have hpe : Block.slotPreOps (atLog P (elog j)) j sp0 = Block.slotPreOps P j sp0 := rfl
      have ht0' : t0 = runOps H t (Block.slotPreOps P j sp0 ++ scOps sp0.rounds ++ [Block.termOp sp0]) := by
        rw [ht0, Block.slot_after H (atLog P (elog j)) j sp0 t r0.claimed r0.fin (r0.rho ++ r0.es) hd0 hsv, hpe]
      have ih := rs_stSlotsLoop_read H P elog b g a sps (recs ++ [r0]) (j + 1) acc0 t0 recs' acc' t' rest
        (fun sp hsp => hcan sp (List.mem_cons_of_mem _ hsp))
        (fun i hi => by
          have := hd1 (i + 1) (by simp; omega)
          rwa [show j + (i + 1) = j + 1 + i by omega] at this) h
      have hsplit : opTrace H t (Block.fullOps P j (sp0 :: sps)) ++ rest
          = opTrace H t (Block.slotPreOps (atLog P (elog j)) j sp0 ++ scOps sp0.rounds ++ [Block.termOp sp0])
            ++ (opTrace H t0 (Block.fullOps P (j + 1) sps) ++ rest) := by
        rw [ht0', hpe]
        simp only [Block.fullOps, Block.opTrace_append, runOps_append, List.append_assoc]
      have e : recs.map Block.SlotRec.draws ++ [r0.draws] = (recs ++ [r0]).map Block.SlotRec.draws := by
        rw [List.map_append]
        rfl
      rw [List.length_cons, hsplit]
      show Block.TRd.bnd (Block.tSlotFull (atLog P (elog j)) j) (fun v => rsLoopE P elog b g a
        (recs.map Block.SlotRec.draws ++ [v.pre.1]) (j + 1) sps.length
        (Block.accStep (atLog P (elog j)) ⟨b, g, a, recs.map Block.SlotRec.draws⟩ j acc v)) _ = _
      rw [Block.TRd.bnd_def, Block.tSlotFull_trace H (atLog P (elog j)) j sp0 t _ hlen0]
      dsimp only
      rw [hacc0', hdr0, e]
      exact ih

/-! ## Stage IN-C's reader -/

/-- **Stage IN-C's accumulator reader**: the header (`hdrLen` entries), the `A` and `M` absorbs skipped, the head's
`3 + rBits` challenges (`β, γ, α, r_emb`: L15's `tRootS`), the `H` absorbs skipped; then every slot of the stage read at
its own IO width under the `BlockParams` of the head's challenges (`incCtx`), as `IncV.slots` runs them. -/
def rsAccInc (V : IncV) (hdrLen : ℕ) (τ : List (TItem × Dig)) : Block.Acc :=
  Block.accOfRd (Block.TRd.bnd (StageFS.tRootS hdrLen (incHeadDraws V.pub))
    (fun ch => rsLoopE (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN) Fp2.zero Fp2.zero Fp2.zero [] 0
      V.geom.slots.length {}) τ)

/-- **On stage IN-C's own accepting trace its reader returns the verifier's accumulator** (the stage's `hRd`): for a
core with canonical slots and the geometry's slot count, slot degrees at least `1` at every context, if `IncV.slots`
accepts after the header `hdr`, the reader of the trace of `hdr`, the head and the slots returns exactly the
accumulator `IncV.slots` returned (the head written at any context `cx0`: its operations do not read the context). -/
theorem rs_accInc_trace (H : HIn → Dig) (V : IncV) (core : Block.Core) (hdr : List Op) (t0 : Tr)
    (recs : List Block.SlotRec) (acc : Block.Acc) (t' : Tr) (cx0 : IncCtx)
    (hcan : ∀ sp ∈ core.slots, Block.SlotCanon sp) (hsh : core.slots.length = V.geom.slots.length)
    (hd : ∀ cx k, k < V.geom.slots.length → 1 ≤ (Block.slotShape (V.bp cx) k).2.2)
    (h : V.slots H core (runOps H t0 hdr) = .ok (recs, acc, t')) :
    rsAccInc V hdr.length (opTrace H t0 (hdr ++ StageFS.stageRootOps (V.bp cx0) core (incHeadDraws V.pub)
      ++ Block.fullOps (V.bp cx0) 0 core.slots)) = acc := by
  have h' : stSlotsLoop H (V.bp (incCtx V.pub (V.headCh H core (runOps H t0 hdr)).1)) (incElog V.pub V.geo.bLogN)
      Fp2.zero Fp2.zero Fp2.zero [] 0 core.slots {}
      (runOps H (runOps H t0 hdr) (StageFS.stageRootOps (V.bp cx0) core (incHeadDraws V.pub)))
      = .ok (recs, acc, t') := by
    rw [← rt_incSlotT H V core (runOps H t0 hdr) cx0]
    exact h
  have hrd := rs_stSlotsLoop_read H (V.bp (incCtx V.pub (V.headCh H core (runOps H t0 hdr)).1))
    (incElog V.pub V.geo.bLogN) Fp2.zero Fp2.zero Fp2.zero core.slots [] 0 {} _ recs acc t' [] hcan
    (fun i hi => by
      rw [Nat.zero_add]
      exact hd _ i (by rw [← hsh]; exact hi)) h'
  have hfo : Block.fullOps (V.bp (incCtx V.pub (V.headCh H core (runOps H t0 hdr)).1)) 0 core.slots
      = Block.fullOps (V.bp cx0) 0 core.slots := by
    rw [rt_fullOps, rt_fullOps, rt_incBp_draws, rt_incBp_draws]
  rw [List.append_nil, hfo, hsh] at hrd
  have hhead : (V.headCh H core (runOps H t0 hdr)).1
      = ((runOps H t0 (hdr ++ Block.rootOpsA (V.bp cx0) core)).challengeFp2Vec H (incHeadDraws V.pub)).1 := by
    rw [runOps_append]
    rfl
  have hs : opTrace H t0 (hdr ++ StageFS.stageRootOps (V.bp cx0) core (incHeadDraws V.pub)
      ++ Block.fullOps (V.bp cx0) 0 core.slots)
      = opTrace H t0 (hdr ++ StageFS.stageRootOps (V.bp cx0) core (incHeadDraws V.pub))
        ++ opTrace H (runOps H (runOps H t0 hdr) (StageFS.stageRootOps (V.bp cx0) core (incHeadDraws V.pub)))
          (Block.fullOps (V.bp cx0) 0 core.slots) := by
    rw [Block.opTrace_append, runOps_append]
  have hfinal : Block.TRd.bnd (StageFS.tRootS hdr.length (incHeadDraws V.pub))
      (fun ch => rsLoopE (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN) Fp2.zero Fp2.zero Fp2.zero [] 0
        V.geom.slots.length {})
      (opTrace H t0 (hdr ++ StageFS.stageRootOps (V.bp cx0) core (incHeadDraws V.pub)
        ++ Block.fullOps (V.bp cx0) 0 core.slots)) = some (acc, []) := by
    rw [hs, Block.TRd.bnd_def, StageFS.tRootS_trace H (V.bp cx0) core (incHeadDraws V.pub) hdr t0 _, ← hhead]
    exact hrd
  unfold rsAccInc
  rw [hfinal]
  rfl

/-! ## Stage OUT-C's reader (any stage of L15's model) -/

/-- **A token stage's accumulator reader** (L15's model: stage OUT-C at `m = 2`, `bgaOf := OutcV.bga`): the header,
the `A` and `M` absorbs skipped, the head's `m` challenges, the `H` absorbs skipped (`tRootS`), then L31's
`tAccLoop` with `define`'s history read from the challenges. -/
def rsAccS (P : Block.BlockParams) (m : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (hdrLen : ℕ)
    (τ : List (TItem × Dig)) : Block.Acc :=
  Block.accOfRd (Block.TRd.bnd (StageFS.tRootS hdrLen m)
    (fun ch => Block.tAccLoop P (bgaOf ch).1 (bgaOf ch).2.1 (bgaOf ch).2.2 [] 0 P.geom.slots.length {}) τ)

/-- **On a token stage's own accepting trace its reader returns the verifier's accumulator** (L15's `stageSlots`;
stage OUT-C's `hRd`): canonical slots, the geometry's slot count, slot degrees at least `1`. -/
theorem rs_accS_trace (H : HIn → Dig) (P : Block.BlockParams) (m : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (core : Block.Core) (hdr : List Op) (t0 : Tr) (ch : List Fp2) (recs : List Block.SlotRec) (acc : Block.Acc)
    (t' : Tr) (hcan : ∀ sp ∈ core.slots, Block.SlotCanon sp) (hsh : core.slots.length = P.geom.slots.length)
    (hd : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2)
    (h : StageFS.stageSlots H P m bgaOf core (runOps H t0 hdr) = .ok (ch, recs, acc, t')) :
    rsAccS P m bgaOf hdr.length (opTrace H t0 (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots))
      = acc := by
  rw [StageFS.stageSlots_eq] at h
  split at h
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, hres⟩ := h
    subst hres
    have hrd := Block.slotsLoop_read H P _ _ _ core.slots [] 0 {} _ recs acc t' [] hcan
      (fun i hi => by
        rw [Nat.zero_add]
        exact hd i (by rw [← hsh]; exact hi)) hloop
    rw [List.append_nil, hsh] at hrd
    have hs : opTrace H t0 (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots)
        = opTrace H t0 (hdr ++ StageFS.stageRootOps P core m)
          ++ opTrace H (runOps H (runOps H t0 hdr) (StageFS.stageRootOps P core m)) (Block.fullOps P 0 core.slots) := by
      rw [Block.opTrace_append, runOps_append]
    have hfinal : Block.TRd.bnd (StageFS.tRootS hdr.length m)
        (fun ch => Block.tAccLoop P (bgaOf ch).1 (bgaOf ch).2.1 (bgaOf ch).2.2 [] 0 P.geom.slots.length {})
        (opTrace H t0 (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots)) = some (acc, []) := by
      rw [hs, Block.TRd.bnd_def, StageFS.tRootS_trace H P core m hdr t0 _, runOps_append]
      exact hrd
    unfold rsAccS
    rw [hfinal]
    rfl
  · cases h

/-! ## Helpers for the run -/

/-- The closed commitments' openings a stage segment carries are canonical. -/
theorem rs_rdCloses_canon : ∀ (cs : List (Block.Dim × ℕ × ℕ)) (os : List Block.OpeningZk) (bs rest : List UInt8),
    rdCloses cs bs = .ok (os, rest) → ∀ o ∈ os, Block.HidingCanon o
  | [], os, bs, rest, h => by
    have h' : Block.Rd.ret ([] : List Block.OpeningZk) bs = .ok (os, rest) := h
    obtain ⟨e1, -⟩ := Block.Rd.ret_ok h'
    rw [e1]
    intro o ho
    simp at ho
  | c :: cs, os, bs, rest, h => by
    have h' : Block.Rd.bnd (Block.rdHiding c.1 c.2.1 c.2.2)
        (fun o => Block.Rd.bnd (rdCloses cs) fun os => Block.Rd.ret (o :: os)) bs = .ok (os, rest) := h
    obtain ⟨o, m1, e1, e2⟩ := Block.Rd.bnd_ok h'
    obtain ⟨os', m2, e3, e4⟩ := Block.Rd.bnd_ok e2
    obtain ⟨e5, -⟩ := Block.Rd.ret_ok e4
    rw [e5]
    intro o' ho'
    rcases List.mem_cons.mp ho' with rfl | ho'
    · exact (Block.rdHiding_ok e1).2.1
    · exact rs_rdCloses_canon cs os' m1 m2 e3 o' ho'

/-- **A decoded stage segment is canonical** (lane L34's `rt_decodeStage_spec` exports its header and shape; L9's
`rdCore_ok` gives the core's canonical words, `rdHiding_ok` each closed commitment's opening's). -/
theorem rs_decodeStage_canon {s : StageGeom} (hgt : s.g.slots.length = s.g.terms.length) {bnd st : Dig}
    {bytes : List UInt8} {seg : StageSeg} {e : Dig} (h : decodeStage s bnd st bytes = .ok (seg, e)) :
    Block.CoreCanon seg.core ∧ ∀ o ∈ seg.closes, Block.HidingCanon o := by
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
        exact ⟨(Block.rdCore_ok hgt e5).2.1, rs_rdCloses_canon _ _ _ _ e7⟩

/-- **The bytes the trace of an operation list absorbs at a position**: those of the operation there, if an absorb. -/
theorem rs_absAt_opTrace (H : HIn → Dig) : ∀ (t : Tr) (ops : List Op) (n : ℕ) (l x : List UInt8),
    ops[n]? = some (Op.absorb l x) → Block.absAt (opTrace H t ops) n = some x
  | _, [], _, _, _, h => by simp at h
  | t, .absorb l' x' :: ops, 0, l, x, h => by
    simp only [List.getElem?_cons_zero, Option.some.injEq, Op.absorb.injEq] at h
    obtain ⟨-, rfl⟩ := h
    rfl
  | _, .squeeze :: _, 0, _, _, h => by simp at h
  | t, .absorb l' x' :: ops, n + 1, l, x, h => by
    have ih := rs_absAt_opTrace H (t.absorb H l' x') ops n l x (by simpa using h)
    show Block.absAt ((TItem.absorb l' x', (t.absorb H l' x').state) :: opTrace H (t.absorb H l' x') ops) (n + 1)
      = some x
    unfold Block.absAt at ih ⊢
    rw [List.getElem?_cons_succ]
    exact ih
  | t, .squeeze :: ops, n + 1, l, x, h => by
    have ih := rs_absAt_opTrace H (t.squeeze H).2 ops n l x (by simpa using h)
    show Block.absAt ((TItem.squeeze t.counter, (t.squeeze H).1) :: opTrace H (t.squeeze H).2 ops) (n + 1) = some x
    unfold Block.absAt at ih ⊢
    rw [List.getElem?_cons_succ]
    exact ih

end ZK60.ProtocolClassify
