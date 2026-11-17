/-
D63 lane L63 (2026-11-16), part 6: **the stages' "true" facts split, and two of the three parts PROVED** (item (ii):
`hTrI`, `hTrO`, `hHostO`).

L57's `StgTrueAt` asks three things at every reading of a stage and every slot window: the header reader reads the
reading's schedule; the accumulator's claims are true of the extracted data; `M`'s functionals (`acc.fs`) are true. The
code checks `M` on `acc.fs ++ acc.hostFs` (finding L63-1, `StgHostTrueAt`). Here:

* `StgReadAt`, `StgClaimsAt`, `StgMAt` (the corrected `M` part, `fs ++ hostFs`), **`ssh_trueAt_of_split`**,
  **`ssh_hostAt_of_M`**: the split, and `StgTrueAt` and `StgHostTrueAt` from its three parts;
* **`ssh_readI`**, **`ssh_readO`**: the reader part at both stages (IN-C's reader is constant; OUT-C's reads the verdict
  byte at position `6`, below every slot window, and lane L55's `vd_hW` gives it on an accepted run);
* `ssh_stage_take`, **`ssh_inc_link`**, **`ssh_outc_link`**: at every reading, the run's stage accumulator reader
  (`rsAccInc`, `rsAccS`, lane L45) on the transcript cut at the slot phase's end has the reading's functionals (IN-C
  through L29's `incSlots_model`, whose two accumulators agree on `fs` and `hostFs`);
* **`ssh_MAt`**: `StgMAt` from `M`'s functionals true of the run's extracted mask table at `M`'s window;
* **`ssh_run_M`**: on an accepted run outside the run's Merkle event `EvXR`, with no doomed `M` entrant (`¬ rtKM.Dm`),
  the stages' `M` functionals are true of the extracted mask tables (lane L54's `wr_ndM`, `wr_rkMask_sem` at parts `0`
  and `Lb + 1`; lanes L45 / L48's `rx_parts_MG`): no new bad event;
* **`ssh_MAtIO`**: `StgMAt` at both stages on such a run.

What stays a premise: `StgClaimsAt` (the claims' truth) at both stages, since the IO commitments' semantics `csIOI`,
`csIOO` are still free (lanes L55, L56).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldInst
import ZK60Formal.RunWireSem
import ZK60Formal.RunStageRdRun

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx incCtx)
open ZK60.Circuit (gP GF)

/-! ## The split -/

section Split

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The reader part**: at every reading and slot window, the header reader reads the reading's schedule. -/
def StgReadAt (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (Pv : StgVw L → List Fp2 → Block.BlockParams) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ k q, core.slots[k]? = some q →
      Pv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q))) ch = Pof ch

/-- **The claims part**: at every reading and slot window, the accumulator's claims are true of the data. -/
def StgClaimsAt (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (csv : StgVw L → Block.Cm → Block.ZClaim → K) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ acc t', StageFS.stageSlots (liftH G) (Pof ch) m bgaOf core
        (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t') →
    ∀ k q, core.slots[k]? = some q →
      Block.ClaimsTrue U (csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)))) acc.claims

/-- **The `M` part, corrected (finding L63-1)**: `M`'s functionals AND host functionals true at every slot window. -/
def StgMAt (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (msv : StgVw L → List (ℕ × List Fp2) → K) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ acc t', StageFS.stageSlots (liftH G) (Pof ch) m bgaOf core
        (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t') →
    ∀ k q, core.slots[k]? = some q →
      Block.MTrue U (msv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)))) (acc.fs ++ acc.hostFs)

/-- **L57's `StgTrueAt` from its three parts.** -/
theorem ssh_trueAt_of_split (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (Pv : StgVw L → List Fp2 → Block.BlockParams) (csv : StgVw L → Block.Cm → Block.ZClaim → K)
    (msv : StgVw L → List (ℕ × List Fp2) → K) (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hR : StgReadAt key domain Pof m hdrLen bgaOf absOf Pv G Lg τ)
    (hC : StgClaimsAt U key domain Pof m hdrLen bgaOf absOf csv G Lg τ)
    (hM : StgMAt U key domain Pof m hdrLen bgaOf absOf msv G Lg τ) :
    StgTrueAt U key domain Pof m hdrLen bgaOf absOf Pv csv msv G Lg τ := by
  intro hdr core ch rs hrd acc t' hacc k q hq
  exact ⟨hR hdr core ch rs hrd k q hq, hC hdr core ch rs hrd acc t' hacc k q hq,
    fun mf hmf => hM hdr core ch rs hrd acc t' hacc k q hq mf (List.mem_append_left _ hmf)⟩

/-- **`StgHostTrueAt` (the premise `hHostO`) from the `M` part.** -/
theorem ssh_hostAt_of_M (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (msv : StgVw L → List (ℕ × List Fp2) → K) (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hM : StgMAt U key domain Pof m hdrLen bgaOf absOf msv G Lg τ) :
    StgHostTrueAt U key domain Pof m hdrLen bgaOf absOf msv G Lg τ :=
  fun hdr core ch rs hrd acc t' hacc k q hq mf hmf =>
    hM hdr core ch rs hrd acc t' hacc k q hq mf (List.mem_append_right _ hmf)

end Split

/-! ## The reader part -/

section Read

variable {L : ℕ}

/-- **Stage IN-C's reader reads the reading's schedule** (it is constant, `vdWin`). -/
theorem ssh_readI {Hdr : Type} (key : Option Dig) (domain : List UInt8) (inc : Hdr → IncV) (Vi : IncV)
    (hinc : ∀ hd, inc hd = Vi) (hd : Hdr) (m hdrLen n0 : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB L → Option (List UInt8)) (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) :
    StgReadAt key domain (fun ch => (inc hd).bp (incCtx (inc hd).pub ch)) m hdrLen bgaOf absOf
      (fun v ch => ((vdWin Vi) (v.2.take n0)).bp (incCtx ((vdWin Vi) (v.2.take n0)).pub ch)) G Lg τ := by
  intro hdr core ch rs _ k q _
  show Vi.bp (incCtx Vi.pub ch) = (inc hd).bp (incCtx (inc hd).pub ch)
  rw [hinc]

/-- **Stage OUT-C's reader reads the reading's schedule** when, on the transcript, it reads the statement's verifier
(`hW`, lane L55's `vd_hW`): it reads only the verdict byte at position `6`, below every slot window. -/
theorem ssh_readO (key : Option Dig) (domain : List UInt8) (F : ℕ → OutcV) (Pv0 : Block.BlockParams)
    (hdrLen n0 : ℕ) (absOf : QB L → Option (List UInt8)) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (τ : List (TItem × Dig)) (hW : (vdWout F (τ.take n0)).bp = Pv0)
    (hgt : Pv0.geom.slots.length = Pv0.geom.terms.length) :
    StgReadAt key domain (fun _ => Pv0) 2 hdrLen OutcV.bga absOf (fun v _ => ((vdWout F) (v.2.take n0)).bp) G Lg τ := by
  intro hdr core ch rs hrd k q hq
  obtain ⟨h1, -⟩ := stg_rd_slot key domain (fun _ => Pv0) 2 hdrLen OutcV.bga G τ hdr core ch rs hrd hgt k q hq
  rw [← h1]
  have e := vw_take absOf Lg 7 (stgDefPos Pv0 2 hdrLen k + (Pv0.draws k + 3)) (by unfold stgDefPos; omega)
    (fun v (_ : List Fp2) => ((vdWout F) (v.2.take n0)).bp) (vwLoc_vdWout F n0 7 (by norm_num)) τ
  have e2 := congrFun e ch
  simp only at e2 ⊢
  rw [e2]
  exact hW

end Read

/-! ## The run's stage accumulator reader at a reading -/

section Link

variable {L : ℕ}

/-- **At a reading, the transcript cut at the slot phase's end is the stage's trace.** -/
theorem ssh_stage_take (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (G : QB L → Dig) (τ : List (TItem × Dig)) (hdr : List Op)
    (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length) :
    τ.take (hdrLen + (7 + m) + shapeLen (Pof ch) 0 (Pof ch).geom.slots)
      = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 core.slots) := by
  obtain ⟨hhl, -, -, hsh, -, T, -, hτ⟩ := hrd
  have hr : ∀ (i : ℕ) (sp : Block.SlotProof) (s : ℕ × ℕ × ℕ), core.slots[i]? = some sp →
      (Pof ch).geom.slots[i]? = some s → sp.rounds.length = s.1 + s.2.1 := by
    intro i sp s h1 h2
    have hi : i < (Pof ch).geom.terms.length := by
      rw [← hgt]
      exact (List.getElem?_eq_some_iff.mp h2).1
    exact (hsh.2 i sp s _ h1 h2 (List.getElem?_eq_getElem hi)).1
  have hf := (full_shape (Pof ch) 0 core.slots (Pof ch).geom.slots hsh.1 hr).1
  have hlen : (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
      (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 core.slots)).length
      = hdrLen + (7 + m) + shapeLen (Pof ch) 0 (Pof ch).geom.slots := by
    rw [Block.opTrace_length, List.length_append, List.length_append, StageFS.stageRootOps_length,
      Link.fullOps_length, hf, hhl]
  rw [hτ, Block.opTrace_append]
  exact List.take_left' hlen

/-- **Stage IN-C: the run's accumulator reader at the slot phase's end has the reading's functionals** (L29's
`incSlots_model`: the code's `IncV.slots` and L15's model agree up to the claims; L45's `rs_accInc_trace`). -/
theorem ssh_inc_link (key : Option Dig) (domain : List UInt8) (V : IncV) (m hdrLen e : ℕ)
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
    (rsAccInc V hdrLen (τ.take e)).fs = acc.fs ∧ (rsAccInc V hdrLen (τ.take e)).hostFs = acc.hostFs := by
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
  obtain ⟨⟨recs, accr, t4⟩, hs, hf⟩ := (StageV.map_ok_iff _ _ _).mp hm2
  have hstr : StageV.accStrip accr = StageV.accStrip acc := congrArg (fun x => x.2.1) hf
  have hr := ZK60.ProtocolClassify.rs_accInc_trace (liftH G) V core hdr (Tr.newKeyed (liftH G) domain key) recs accr
    t4 (incCtx V.pub (V.headCh (liftH G) core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)).1) hcan.1
    hsh.1 hd hs
  rw [hhl] at hr
  rw [hr]
  exact ⟨congrArg (fun x => x.2.2.1) hstr, congrArg (fun x => x.2.2.2) hstr⟩

/-- **Stage OUT-C: the run's accumulator reader at the slot phase's end is the reading's accumulator** (L45's
`rs_accS_trace`). -/
theorem ssh_outc_link (key : Option Dig) (domain : List UInt8) (P : Block.BlockParams) (hdrLen e : ℕ)
    (G : QB L → Dig) (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core) (ch : List Fp2)
    (rs : List Block.SlotRec) (hrd : StgRd key domain L (fun _ => P) 2 hdrLen OutcV.bga G τ hdr core ch rs)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (hd : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2)
    (he : e = hdrLen + (7 + 2) + shapeLen P 0 P.geom.slots) (acc : Block.Acc) (t' : Tr)
    (hacc : StageFS.stageSlots (liftH G) P 2 OutcV.bga core
      (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t')) :
    rsAccS P 2 OutcV.bga hdrLen (τ.take e) = acc := by
  have htk := ssh_stage_take key domain (fun _ => P) 2 hdrLen OutcV.bga G τ hdr core ch rs hrd hgt
  obtain ⟨hhl, -, hcan, hsh, -, -⟩ := hrd
  have h2 : τ.take e = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
      (hdr ++ StageFS.stageRootOps P core 2 ++ Block.fullOps P 0 core.slots) := by
    rw [he]
    exact htk
  rw [h2, ← hhl]
  exact rs_accS_trace (liftH G) P 2 OutcV.bga core hdr _ ch rs acc t' hcan.1 hsh.1 hd hacc

end Link

/-! ## The `M` part from the run's extracted mask table -/

section MAt

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- **`StgMAt` from `M`'s functionals true of the run's extracted mask table at `M`'s window** (`hrun`), when the run's
stage reader there has the reading's functionals (`hlink`). -/
theorem ssh_MAt (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (S mpos aM : ℕ) (Racc : List (TItem × Dig) → Block.Acc)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hmpos : mpos = hdrLen + 3) (haM : mpos < aM)
    (hrun : ∀ mf ∈ (Racc (τ.take aM)).fs ++ (Racc (τ.take aM)).hostFs,
      msOfTab U S (rkColsM tag L h64 key domain hs hL mpos Lg (τ.take aM)) mf.terms = mf.value.toK U)
    (hlink : ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
      ∀ acc t', StageFS.stageSlots (liftH G) (Pof ch) m bgaOf core
          (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t') →
        (Racc (τ.take aM)).fs = acc.fs ∧ (Racc (τ.take aM)).hostFs = acc.hostFs) :
    StgMAt U key domain Pof m hdrLen bgaOf (Exec.Block.absOfC (chainEncB key domain hs L hL))
      (stgMsv U tag h64 S (hdrLen + 3)) G Lg τ := by
  intro hdr core ch rs hrd acc t' hacc k q hq mf hmf
  obtain ⟨hf, hh⟩ := hlink hdr core ch rs hrd acc t' hacc
  have hmf' : mf ∈ (Racc (τ.take aM)).fs ++ (Racc (τ.take aM)).hostFs := by rw [hf, hh]; exact hmf
  rw [← hrun mf hmf']
  obtain ⟨h1, -⟩ := stg_rd_slot key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd (hgt ch) k q hq
  rw [← h1]
  subst hmpos
  have hlt : hdrLen + 3 < stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3) := by
    unfold stgDefPos
    omega
  have hc : rkColsM tag L h64 key domain hs hL (hdrLen + 3) Lg (τ.take aM)
      = colsC tag L h64 (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs L hL))
          (Block.absAt (τ.take aM) (hdrLen + 3)) Lg) (Block.absAt (τ.take aM) (hdrLen + 3)) := by
    funext j
    rfl
  rw [hc, ssh_absAt_take τ aM _ haM]
  show msOfTab U S (colsC tag L h64 (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs L hL))
      (Block.absAt (τ.take (stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3))) (hdrLen + 3)) Lg)
      (Block.absAt (τ.take (stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3))) (hdrLen + 3))) mf.terms = _
  rw [ssh_absAt_take τ _ _ hlt]

end MAt

/-! ## On an accepted run: the stages' `M` functionals true, and `StgMAt` at both stages -/

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

/-- **THE STAGES' `M` FUNCTIONALS ARE TRUE OF THE RUN'S EXTRACTED MASK TABLES** on an accepted run outside `EvXR`, with
no doomed `M` entrant (the `M` openings' acceptance facts are L45 / L48's `rx_parts_MG`; lane L54's `wr_ndM`,
`wr_rkMask_sem`): at part `0` and part `Lb + 1`, every functional and host functional the run's stage reader returns at
`M`'s window. -/
theorem ssh_run_M
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
    (hLb : Lb ≤ 26) (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom) (gS : OGeo)
    (htI : I.tag = tag) (htO : O.tag = tag) (htB : ∀ k, (bp k).tag = tag)
    (hfIM : 8 * (2 * pin.S + 4) ≤ Lq) (hfOM : 8 * (2 * pout.S + 4) ≤ Lq) (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (lscIn lscOut : Block.ZClaim)
    (mIn kIn kOut : ℕ) (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn)
    (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
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
    (hM : ¬ (rtKM key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD).Dm n (A.runLog G).2 (R.tr G (A.run G))) :
    (∀ mf ∈ (rxAcc Win Wout Pk R.pf Lb 0 ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).pre))).fs
        ++ (rxAcc Win Wout Pk R.pf Lb 0 ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).pre))).hostFs,
      msOfTab U pin.S (rkColsM tag Lq h64 key domain hs hL (R.pf.off 0 + (5 + 3)) (A.runLog G).2
        ((R.tr G (A.run G)).take (R.pf.off 0 + (R.pf.part 0).pre))) mf.terms = mf.value.toK U)
    ∧ (∀ mf ∈ (rxAcc Win Wout Pk R.pf Lb (Lb + 1)
          ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre))).fs
        ++ (rxAcc Win Wout Pk R.pf Lb (Lb + 1)
          ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre))).hostFs,
      msOfTab U pout.S (rkColsM tag Lq h64 key domain hs hL (R.pf.off (Lb + 1) + (2 + 3)) (A.runLog G).2
        ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + (R.pf.part (Lb + 1)).pre))) mf.terms = mf.value.toK U) := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hlen : ∀ (a : ℕ), ((R.tr G (A.run G)).take a).length = a → a ≤ (R.tr G (A.run G)).length := by
    intro a h
    rw [List.length_take] at h
    omega
  have one : ∀ i, i < R.pf.parts.length →
      ∀ mf ∈ (rxAcc Win Wout Pk R.pf Lb i ((R.tr G (A.run G)).take (R.pf.off i + (R.pf.part i).pre))).fs
        ++ (rxAcc Win Wout Pk R.pf Lb i ((R.tr G (A.run G)).take (R.pf.off i + (R.pf.part i).pre))).hostFs,
      msOfTab U ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
          (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
          (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) i).S
        (rkColsM tag Lq h64 key domain hs hL ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
          (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
          (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) i).mpos (A.runLog G).2
          ((R.tr G (A.run G)).take (R.pf.off i + (R.pf.part i).pre))) mf.terms = mf.value.toK U := by
    intro i hi
    obtain ⟨oM⟩ := rx_parts_MG (tag := tag) (gS := gS) (h64 := h64) (hs := hs) (hL := hL) (Lb := Lb) (preA := preA)
      (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG) (Pk := Pk)
      (sgeom := sgeom) (check := check) (paths := paths) (digest := digest) (bRows := bRows) (bLogN := bLogN)
      (bndCheck := bndCheck) (bndOpen := bndOpen) (R := R) (hv := hv) (cx0 := cx0) (pin := pin) (pout := pout)
      (I := I) (O := O) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ) (hLb := hLb) (hgeo := hgeo)
      (Win := Win) (Wout := Wout) (mIn := mIn) (kIn := kIn) (kOut := kOut) (base := base) (acc := _) (hacc := rfl)
      (A := A) (G := G) (hE := hE) (hWin := hWin) (hWout := hWout) (hX := hX) (i := i) (hi := hi) (htI := htI)
      (htO := htO) (htB := htB) (hfIM := hfIM) (hfOM := hfOM) (hfBM := hfBM) (hkIn := hkIn) (hkOut := hkOut)
      (ps := _) (rIA := I.pA.rows) (rIH := I.pH.rows) (rOA := O.pA.rows) (rOH := O.pH.rows)
      (rBA := fun k => (bp k).pA.rows) (rBH := fun k => (bp k).pH.rows) (hps := rfl)
    have ndM := wr_ndM key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD n (A.runLog G).2 (R.tr G (A.run G)) hM i hi hn
    exact wr_rkMask_sem U hbij tag Lq h64 key domain hs hL _ _ _
      (fun hdr => (rxAcc Win Wout Pk R.pf Lb i hdr).fs ++ (rxAcc Win Wout Pk R.pf Lb i hdr).hostFs)
      (rtW R.pf.sqs) _ (A.runLog G).2 (R.tr G (A.run G)) ndM (hlen _ oM.hpl) oM.hpre
      (by have h := oM.hk; rw [← oM.hrd] at h; exact h)
  refine ⟨one 0 (by omega), ?_⟩
  have h1 := one (Lb + 1) (by omega)
  rw [rxPs_out] at h1
  exact h1

end Run

end ZK60.ProtocolClassify
